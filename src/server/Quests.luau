--!strict
-- Onboarding (the scripted first ten minutes) and the quest board.
--
-- Onboarding is a list of beats, one system each, kept by id (data.beats). Each
-- beat has a one-line elder line, a short objective, a condition checked every
-- second, and a guide: what the client should point at right now (a button to
-- spotlight, maybe dimming the rest of the HUD, or a place to walk to). Players
-- already past a beat skip straight through. After the last beat the objective
-- shows the top quest board goal instead.
--
-- Lessons teach the systems a player meets later (first bottleneck, Practice
-- Dao, a method, a root pill): when one's condition first holds, the elder says
-- its line once (data.lessons) and its guide shows for the rest of that session
-- while the condition holds. They never dim the HUD.
--
-- Guide (sent in QuestState as `guide`; the client resolves the names):
--   button  a HUD control by key: "Cultivate" (sit), "Circulate", "Breakthrough",
--           "Practice", "PracticeTechnique", "PracticeDao" (the Practice row's
--           tiles; the client points at Practice until that row is open),
--           "Method", "SpiritRoot" (seated tiles),
--           "Travel", "Attack", "Inventory", "Self"
--   to      with button "Travel": the destination gate id to point at in the menu
--   dim     grey out the rest of the HUD until that button is pressed
--   place   a world target to walk to: "TestingStone", "Elder", "QuestBoard",
--           "QiNode" (nearest), "Enemy" (nearest), "Array:<gate id>",
--           "Garden" (nearest HerbPlot on your own peak), "WeaponRack" (nearest)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Cultivation = require(script.Parent.Cultivation)
local Circulation = require(script.Parent.Circulation)
local Peaks = require(script.Parent.Peaks)
local Peak = require(ReplicatedStorage.Shared.Peak)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local CollectionService = game:GetService("CollectionService")
local PlayerData = require(script.Parent.PlayerData)
local DaoPacing = require(ReplicatedStorage.Shared.Pacing).DaoPractice

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent

export type Guide = { button: string?, to: string?, dim: boolean?, place: string? }

type Beat = {
	id: string,
	elder: string,
	objective: string,
	done: (Player, PlayerData.Data) -> boolean,
	guide: ((Player, PlayerData.Data) -> Guide?)?,
	travel: boolean?, -- the formation is taught from this beat on
}

type Lesson = {
	id: string,
	elder: string,
	when: (Player, PlayerData.Data) -> boolean,
	guide: ((Player, PlayerData.Data) -> Guide?)?,
}

local function stageIndex(data: PlayerData.Data): number
	return Realms.index(data.realm.major, data.realm.minor)
end

local function slotted(data: PlayerData.Data): number
	return Hotbar.techniqueCount(data.hotbar)
end

local function nearGate(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local gate = Config.Travel.SECT_GATE
	-- at the gate, or anywhere past it in the wilds
	return (root.Position - gate).Magnitude < 120 or (root.Position.Z > gate.Z and root.Position.Y < 100)
end

local function seated(player: Player): boolean
	return Cultivation.meditation ~= nil and Cultivation.meditation(player) ~= nil
end

local function barFull(data: PlayerData.Data): boolean
	return data.cultivation >= Cultivation.stage(data).bar
end

-- Sit first (the Cultivate tile), then the seated tile.
local function seatedTile(player: Player, tile: string, dim: boolean?): Guide
	if seated(player) then
		return { button = tile, dim = dim }
	end
	return { button = "Cultivate", dim = dim }
end

-- Circulate until the bar is full, then break through.
local function climbGuide(player: Player, data: PlayerData.Data): Guide?
	if barFull(data) then
		return seatedTile(player, "Breakthrough", true)
	end
	if data.rawQi <= 0 then
		return { place = "QiNode" }
	end
	if Circulation.atRefiningSpot(player) then
		return seatedTile(player, "Circulate")
	end
	return { button = "Travel", to = "Peak" }
end

local function rootPosition(player: Player): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function positionOf(thing: Instance?): Vector3?
	if thing and thing:IsA("Model") then
		return thing:GetPivot().Position
	elseif thing and thing:IsA("BasePart") then
		return thing.Position
	end
	return nil
end

-- Close enough to walk to (the same peak), rather than travel to.
local WALKABLE = 250

local function nearTestingStone(player: Player): boolean
	local hub = workspace:FindFirstChild("Hub")
	local at, here = positionOf(hub and hub:FindFirstChild("TestingStone")), rootPosition(player)
	return at ~= nil and here ~= nil and (here - at).Magnitude < WALKABLE
end

local function nearTagged(player: Player, tag: string): boolean
	local here = rootPosition(player)
	if not here then
		return false
	end
	for _, thing in CollectionService:GetTagged(tag) do
		local at = positionOf(thing)
		if at and thing:IsDescendantOf(workspace) and (here - at).Magnitude < WALKABLE then
			return true
		end
	end
	return false
end

local function onOwnPeak(player: Player): boolean
	local peak, here = Peaks.ownedBy(player), rootPosition(player)
	if not (peak and here) then
		return false
	end
	local offset = Peak.frame(peak):PointToObjectSpace(here)
	return Vector2.new(offset.X, offset.Z).Magnitude < 120 and math.abs(offset.Y) < 80
end

local function plantedAny(data: PlayerData.Data): boolean
	for _, plants in data.peak.plots do
		if type(plants) == "table" and #plants > 0 then
			return true
		end
	end
	return false
end

-- Weapon classes the player owns a weapon of (Fist, bare hands, doesn't count).
local function weaponClasses(data: PlayerData.Data): number
	local classes = {}
	for id, count in data.weapons.owned do
		if count > 0 then
			classes[WeaponDefs.classOf(id)] = true
		end
	end
	local n = 0
	for class in classes do
		if class ~= "Fist" then
			n += 1
		end
	end
	return n
end

local function reached(data: PlayerData.Data, key: string): boolean
	local stage = Realms.ByKey[key]
	return stage ~= nil and stageIndex(data) >= Realms.index(stage.major, stage.minor)
end

local function bottlenecked(data: PlayerData.Data): boolean
	for _, owned in data.techniques.owned do
		if Techniques.bottleneck(owned.level) and owned.xp >= Techniques.xpToNext(owned.level) then
			return true
		end
	end
	return false
end

local Quests = {}

-- Called with (player, beatIndex, beatId) when a beat is completed, for analytics.
Quests.onBeat = {} :: { (Player, number, string) -> () }

Quests.Beats = {
	{
		id = "Circulate",
		elder = "Welcome home, disciple. This peak is yours. Circulate the qi already stirring in your dantian.",
		objective = "Tap Cultivate, then Circulate, and guide your qi out of the maze",
		done = function(_, data)
			return data.stats.circulationRuns >= 1
		end,
		guide = function(player)
			return seatedTile(player, "Circulate", true)
		end,
	},
	{
		id = "Breakthrough",
		elder = "Good. Your meridians brim with qi. Sit in meditation and break through!",
		objective = "Fill your realm bar, then meditate and tap Break Through",
		done = function(_, data)
			return data.stats.breakthroughs >= 1
		end,
		guide = climbGuide,
	},
	{
		id = "Root",
		elder = "Qi flows in you now. Ride the teleport formation to the Main Peak and lay your hand on the Testing Stone. Let us see your spirit root.",
		objective = "Travel to the Main Peak and touch the Testing Stone",
		done = function(_, data)
			return Roots.tested(data.root)
		end,
		travel = true,
		guide = function(player)
			if nearTestingStone(player) then
				return { place = "TestingStone" }
			end
			return { button = "Travel", to = "MainPeak", dim = true }
		end,
	},
	{
		id = "Gate",
		elder = "Your dantian is spent. Spirit wolves prowl just past the Sect Gate. Go, and take their qi!",
		objective = "Tap Travel, then Sect Gate",
		done = function(player, _)
			return nearGate(player)
		end,
		guide = function()
			return { button = "Travel", to = "SectGate", dim = true }
		end,
	},
	{
		id = "FirstKill",
		elder = "Spirit wolves prowl beyond the gate. Strike them, and dodge when the ground glows red.",
		objective = "Defeat a spirit wolf",
		done = function(_, data)
			return data.stats.kills >= 1
		end,
		guide = function()
			return { place = "Enemy" }
		end,
	},
	{
		id = "Technique",
		elder = "Every beast you slay teaches you something. Defeat a few more; a technique manual awaits.",
		objective = "Defeat 3 enemies to earn a technique manual",
		done = function(_, data)
			return slotted(data) >= 2
		end,
		guide = function()
			return { place = "Enemy" }
		end,
	},
	{
		id = "Refine",
		elder = "Your dantian swells. Refine that qi at a glowing qi node, or back on your peak.",
		objective = "Circulate at a qi node or on your peak",
		done = function(_, data)
			return data.stats.circulationRuns >= (data.onboardingMark or 0) + 1
		end,
		guide = function(player)
			if Circulation.atRefiningSpot(player) then
				return seatedTile(player, "Circulate")
			end
			return { place = "QiNode" }
		end,
	},
	{
		id = "QC3",
		elder = "First kills grant insight. You will need it to reach Foundation. Now break through again.",
		objective = "Reach Qi Condensation 3",
		done = function(_, data)
			return stageIndex(data) >= 3
		end,
		guide = climbGuide,
	},
	{
		id = "FreePlay",
		elder = "You walk the path on your own now. The quest board on the main peak holds your next goals.",
		objective = "",
		done = function()
			return false
		end,
	},
} :: { Beat }

local FREE_PLAY = #Quests.Beats

Quests.Lessons = {
	{
		id = "Home",
		elder = "Your peak can grow with you. Plant a seed in your garden; herbs feed your cultivation and sell for Spirit Stones.",
		when = function(_, data)
			return reached(data, "QC4") and not plantedAny(data)
		end,
		guide = function(player)
			if onOwnPeak(player) then
				return { place = "Garden" }
			end
			return { button = "Travel", to = "Peak" }
		end,
	},
	{
		id = "Bottleneck",
		elder = "Your technique has hit a bottleneck. Sit in meditation and comprehend it; insight opens the way.",
		when = function(_, data)
			return bottlenecked(data)
		end,
		guide = function(player)
			return seatedTile(player, "PracticeTechnique")
		end,
	},
	{
		id = "WeaponRack",
		elder = "A cultivator need not keep to one blade. The sect's weapon rack on the Main Peak lends each disciple one weapon of every kind.",
		when = function(_, data)
			return reached(data, DaoPacing.FROM) and weaponClasses(data) < 2
		end,
		guide = function(player)
			if nearTagged(player, "WeaponRack") then
				return { place = "WeaponRack" }
			end
			return { button = "Travel", to = "MainPeak" }
		end,
	},
	{
		id = "DaoPractice",
		elder = "Your body is ready for more than brawling. While you meditate, practice your weapon's forms to deepen its Dao.",
		when = function(_, data)
			return reached(data, DaoPacing.FROM)
		end,
		guide = function(player)
			return seatedTile(player, "PracticeDao")
		end,
	},
	{
		id = "Method",
		elder = "A true cultivation method! See it on your Self card. Should you find others, switch between them while you meditate.",
		when = function(_, data)
			return data.methods.active ~= ""
		end,
		guide = function()
			return { button = "Self" }
		end,
	},
	{
		id = "RootPill",
		elder = "That pill can temper your very root. Absorb it while you meditate, from the Spirit Root page.",
		when = function(_, data)
			return (data.items.MarrowWashingPill or 0) > 0 or (data.items.RootRebirthPill or 0) > 0
		end,
		guide = function(player)
			return seatedTile(player, "SpiritRoot")
		end,
	},
} :: { Lesson }

-- The first beat not yet done (FreePlay once they all are), and its index.
local function current(data: PlayerData.Data): (Beat, number)
	for i = 1, FREE_PLAY - 1 do
		local beat = Quests.Beats[i]
		if not data.beats[beat.id] then
			return beat, i
		end
	end
	return Quests.Beats[FREE_PLAY], FREE_PLAY
end

-- The teleport formation unlocks when the elder sends you to the Testing Stone.
function Quests.travelUnlocked(data: PlayerData.Data): boolean
	local _, index = current(data)
	for i = 1, index do
		if Quests.Beats[i].travel then
			return true
		end
	end
	return false
end

-- The quest board: what to aim for next, most pressing first.
export type Goal = { name: string, detail: string, progress: string }
function Quests.goals(data: PlayerData.Data): { Goal }
	local goals: { Goal } = {}
	local stage = Realms.get(data.realm.major, data.realm.minor)
	local nextStage = Realms.after(stage.major, stage.minor)
	if nextStage then
		local major = nextStage.major ~= stage.major
		if data.insightEarned < stage.insight then
			table.insert(goals, {
				name = "Gather insight",
				detail = `Insight from first kills, the Elder Wolf King and kill milestones opens the way to {nextStage.name}.`,
				progress = `{data.insightEarned}/{stage.insight}`,
			})
		end
		if Cultivation.methodLimit(data, nextStage) then
			table.insert(goals, {
				name = "Seek a stronger method",
				detail = `Your cultivation method can't take you to {nextStage.name}. Ask Elder Qingyun, or search the world for a better one.`,
				progress = "0/1",
			})
		end
		table.insert(goals, {
			name = if major then `Face the tribulation: {nextStage.name}` else `Break through to {nextStage.name}`,
			detail = if major
				then `Fill your bar, then survive {if stage.tribulation then stage.tribulation.seconds else 30} seconds of heavenly lightning on the main peak.`
				else "Circulate raw qi from the wilds to fill your realm bar.",
			progress = `{math.floor(data.cultivation)}/{stage.bar}`,
		})
	end
	if not Roots.tested(data.root) then
		table.insert(goals, 1, {
			name = "Have your root tested",
			detail = "Lay your hand on the Testing Stone on the Main Peak to learn your spirit root.",
			progress = "0/1",
		})
	end
	if data.stats.bossKills == 0 then
		table.insert(goals, {
			name = "Slay the Elder Wolf King",
			detail = "He rules the far end of the wilds. His first defeat yields a technique manual and insight.",
			progress = "0/1",
		})
	end
	for _, m in Pacing.Rewards.MILESTONES do
		if not data.milestones[tostring(m.kills)] then
			local reward = if m.manual then Techniques.Defs[m.manual].name else "insight"
			table.insert(goals, {
				name = `Slay {m.kills} enemies`,
				detail = `Reward: {reward}{if m.insight and m.manual then " and insight" else ""}.`,
				progress = `{data.stats.kills}/{m.kills}`,
			})
			break
		end
	end
	for id, def in Enemies.Defs do
		if not def.boss and not data.firstKills[id] then
			table.insert(goals, {
				name = `First {def.name}`,
				detail = "The first kill of each kind of beast grants insight.",
				progress = "0/1",
			})
		end
	end
	local owned = 0
	for _ in data.techniques.owned do
		owned += 1
	end
	if owned < #Techniques.Order then
		table.insert(goals, {
			name = "Learn every technique",
			detail = "Manuals come from kill milestones and the Elder Wolf King.",
			progress = `{owned}/{#Techniques.Order}`,
		})
	end
	return goals
end

local lastSent: { [Player]: string } = {}
local sessionLessons: { [Player]: { [string]: boolean } } = {} -- lessons shown this session

local function key(guide: Guide?): string
	if not guide then
		return ""
	end
	return `{guide.button or ""}/{guide.to or ""}/{guide.dim == true}/{guide.place or ""}`
end

-- In free play: say the first lesson whose moment has come (once ever), and
-- guide toward the first one shown this session that still applies.
local function lessons(player: Player, data: PlayerData.Data): (Lesson?, Guide?)
	local shown = sessionLessons[player] or {}
	sessionLessons[player] = shown
	local fresh: Lesson? = nil
	for _, lesson in Quests.Lessons do
		if not data.lessons[lesson.id] and lesson.when(player, data) then
			data.lessons[lesson.id] = true
			shown[lesson.id] = true
			fresh = lesson
			break
		end
	end
	for _, lesson in Quests.Lessons do
		if shown[lesson.id] and lesson.guide and lesson.when(player, data) then
			return fresh, lesson.guide(player, data)
		end
	end
	return fresh, nil
end

local function push(player: Player, data: PlayerData.Data, repeatElder: boolean?)
	local beat, index = current(data)
	local objective = beat.objective
	local guide: Guide? = if beat.guide then beat.guide(player, data) else nil
	local lesson: Lesson? = nil
	if beat.id == "FreePlay" then
		local top = Quests.goals(data)[1]
		objective = if top then `{top.name} ({top.progress})` else ""
		lesson, guide = lessons(player, data)
	end
	local payload = {
		step = index - 1,
		beat = beat.id,
		elder = beat.elder,
		objective = objective,
		travel = Quests.travelUnlocked(data),
		goals = Quests.goals(data),
		repeatElder = repeatElder,
		guide = guide,
		lesson = if lesson then { id = lesson.id, elder = lesson.elder } else nil,
	}
	-- only send when something visible changed
	local sendKey = `{payload.step}|{objective}|{#payload.goals}|{key(guide)}`
	if lastSent[player] ~= sendKey or repeatElder or lesson then
		lastSent[player] = sendKey
		questRemote:FireClient(player, payload)
	end
end

local function advance(player: Player, data: PlayerData.Data)
	-- skip every beat already met (repeat players go straight through)
	while true do
		local beat, index = current(data)
		if index >= FREE_PLAY or not beat.done(player, data) then
			break
		end
		data.beats[beat.id] = true
		data.onboardingMark = data.stats.circulationRuns
		for _, fn in Quests.onBeat do
			task.spawn(fn, player, index, beat.id)
		end
	end
end

function Quests.check(player: Player)
	local data = PlayerData.get(player)
	if data then
		advance(player, data)
		push(player, data)
	end
end

-- The elder repeats your current beat's line, or the top goal in free play.
function Quests.talk(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local beat = current(data)
	if beat.id == "FreePlay" then
		local top = Quests.goals(data)[1]
		Cultivation.notify(player, if top then `Elder Qingyun: "{top.detail}"` else `Elder Qingyun: "Keep cultivating."`)
	else
		push(player, data, true)
	end
end

function Quests.start()
	local hub = workspace:WaitForChild("Hub")
	local elder = hub:WaitForChild("Elder")
	local talk = elder:FindFirstChild("TalkPrompt", true) :: ProximityPrompt?
	if talk then
		talk.Triggered:Connect(Quests.talk)
	end
	local board = hub:WaitForChild("QuestBoard")
	local read = board:FindFirstChild("ReadPrompt", true) :: ProximityPrompt?
	if read then
		read.Triggered:Connect(function(player)
			questRemote:FireClient(player, { openBoard = true })
		end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Quests.check, player)
				if not ok then
					warn(`Quests: {err}`)
				end
			end
		end
	end)
end

function Quests.forget(player: Player)
	lastSent[player] = nil
	sessionLessons[player] = nil
end

return Quests
