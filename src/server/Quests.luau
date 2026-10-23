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
-- while the condition holds (`persist`: in later sessions too). They never dim
-- the HUD; `point` in their guide adds a pointer and a callout line instead.
-- Lessons fire in free play, except `early` ones, which may also step in
-- during the onboarding beats, between steps (see earlyLesson).
--
-- Every beat and lesson is also a rewarded objective, a Quest: id, elder line,
-- objective, done, reward (Pacing.Quests) and guide. This is the one def format
-- a later quest system (a log, givers, chains, dailies) should load as well.
-- Claimed state is kept by quest id in data.quests, never by position; a quest
-- is claimed once, server-side, the moment it's done while it applies (a beat:
-- when it's passed; a lesson: while `open` holds), and claim() marks it before
-- granting so it can't pay twice. The objective line shows, in order: a
-- guiding lesson's unclaimed objective, the current beat, the first unclaimed
-- open lesson, then the top quest board goal; the reward rides along
-- (`reward` in QuestState) for the client to show after it.
--
-- Guide (sent in QuestState as `guide`; the client resolves the names):
--   button  a HUD control by key: "Cultivate" (sit), "Circulate", "Breakthrough",
--           "Practice", "PracticeTechnique", "PracticeDao" (the Practice row's
--           tiles; the client points at Practice until that row is open),
--           "Method", "SpiritRoot" (seated tiles),
--           "Travel", "Attack", "Inventory", "Self",
--           "RootPill" (the Absorb button on the Spirit Root page; until that
--           page is open the client points at the SpiritRoot tile)
--   to      with button "Travel": the destination gate id to point at in the menu
--   dim     grey out the rest of the HUD until that button is pressed
--   point   (no dim) a bobbing pointer and a callout beside the button
--   say     the callout's short line for this step
--   place   a world target to walk to: "TestingStone", "Elder", "QuestBoard",
--           "QiNode" (nearest), "Enemy" (nearest living), "Array" (nearest
--           array of any kind), "Array:<gate id>", "Garden" (nearest HerbPlot
--           on your own peak), "WeaponRack" (nearest). With button "Travel" +
--           `to` (out in the wilds, where the button is hidden), walk to the
--           array; once its menu is open, `to` points at the destination.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Gates = require(ReplicatedStorage.Shared.Gates)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Cultivation = require(script.Parent.Cultivation)
local Circulation = require(script.Parent.Circulation)
local Peaks = require(script.Parent.Peaks)
local Peak = require(ReplicatedStorage.Shared.Peak)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local CollectionService = game:GetService("CollectionService")
local PlayerData = require(script.Parent.PlayerData)
local DaoPacing = require(ReplicatedStorage.Shared.Pacing).DaoPractice
local Progression = require(script.Parent.Progression)

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent
local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent
local REWARDS = Pacing.Quests

export type Guide = { button: string?, to: string?, dim: boolean?, place: string?, point: boolean?, say: string? }

-- A rewarded objective. Beats and lessons are Quests with a few fields more;
-- a future quest system's defs use the same shape.
export type Quest = {
	id: string, -- also its key in data.quests and Pacing.Quests
	elder: string, -- the elder's one line when it begins
	objective: string, -- the objective line
	progress: ((PlayerData.Data) -> string)?, -- shown after the objective, e.g. "1/3"
	done: (Player, PlayerData.Data) -> boolean,
	reward: Pacing.QuestReward?,
	guide: ((Player, PlayerData.Data) -> Guide?)?,
}

type Beat = Quest & {
	travel: boolean?, -- the formation is taught from this beat on
}

type Lesson = Quest & {
	when: (Player, PlayerData.Data) -> boolean, -- says the elder line and shows the guide
	open: ((Player, PlayerData.Data) -> boolean)?, -- the objective applies (shown, claimable); default `when`
	early: boolean?, -- may step in during the onboarding beats (earlyLesson)
	persist: boolean?, -- its guide comes back every session while `when` holds
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

local function rootPosition(player: Player): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- On the sect's safe ground, where the Travel button shows.
local function inSect(player: Player): boolean
	local here = rootPosition(player)
	return here ~= nil and Gates.inSect(here)
end

-- Travel to a sect array: the Travel button on sect ground; out in the wilds
-- there is none, so walk to the nearest array (its prompt opens the menu).
local function travelTo(player: Player, gate: string, dim: boolean?): Guide
	if inSect(player) then
		return { button = "Travel", to = gate, dim = dim }
	end
	return { button = "Travel", to = gate, place = "Array" }
end

-- Where to refine: circulate here if you can, else the nearest qi node out in
-- the wilds, or your own peak from the sect.
local function refineGuide(player: Player): Guide
	if Circulation.atRefiningSpot(player) then
		return seatedTile(player, "Circulate")
	end
	if inSect(player) then
		return travelTo(player, "Peak")
	end
	return { place = "QiNode" }
end

-- Circulate until the bar is full, then break through. Too little raw qi for a
-- run: before travel is taught, meditate (passive cultivation fills the rest);
-- after, go out and gather it.
local function climbGuide(player: Player, data: PlayerData.Data): Guide?
	if barFull(data) then
		return seatedTile(player, "Breakthrough", true)
	end
	if not Circulation.enoughQi(data) then
		if not data.beats.Breakthrough then
			return if seated(player) then nil else { button = "Cultivate" }
		end
		if inSect(player) then
			return travelTo(player, "SectGate")
		end
		return { place = "QiNode" }
	end
	return refineGuide(player)
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

-- A technique comprehended past its first bottleneck.
local function comprehended(data: PlayerData.Data): boolean
	for _, owned in data.techniques.owned do
		if owned.level > Techniques.VISUAL_TIERS[1] then
			return true
		end
	end
	return false
end

-- Root pills held, and whether one can be absorbed right now (a Marrow
-- Washing Pill does nothing to a root at its purest; a reforming root must be
-- settled before another pill).
local ROOT_PILLS = { "MarrowWashingPill", "RootRebirthPill" }

local function rootPills(data: PlayerData.Data): number
	local n = 0
	for _, id in ROOT_PILLS do
		n += data.items[id] or 0
	end
	return n
end

local function rootPillReady(data: PlayerData.Data): boolean
	if not Roots.tested(data.root) or data.root.pending ~= "" then
		return false
	end
	return (data.items.RootRebirthPill or 0) > 0
		or ((data.items.MarrowWashingPill or 0) > 0 and Roots.nextGrade(data.root.grade) ~= nil)
end

local Quests = {}

-- Called with (player, beatIndex, beatId) when a beat is completed, for analytics.
Quests.onBeat = {} :: { (Player, number, string) -> () }

Quests.Beats = {
	{
		id = "Circulate",
		reward = REWARDS.Circulate,
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
		reward = REWARDS.Breakthrough,
		elder = "Good. Your meridians brim with qi. Sit in meditation and break through!",
		objective = "Fill your realm bar, then meditate and tap Break Through",
		done = function(_, data)
			return data.stats.breakthroughs >= 1
		end,
		guide = climbGuide,
	},
	{
		id = "Root",
		reward = REWARDS.Root,
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
		reward = REWARDS.Gate,
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
		reward = REWARDS.FirstKill,
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
		reward = REWARDS.Technique,
		elder = "Every beast you slay teaches you something. Defeat a few more; a technique manual awaits.",
		objective = "Defeat 3 enemies to earn a technique manual",
		progress = function(data)
			return `{math.min(data.stats.kills, 3)}/3`
		end,
		-- the 3-kill milestone's manual, earned; not "two on the hotbar", which a
		-- full hotbar or an unslotted starter technique kept from ever holding
		done = function(_, data)
			return data.milestones["3"] == true or slotted(data) >= 2
		end,
		guide = function()
			return { place = "Enemy" }
		end,
	},
	{
		id = "Refine",
		reward = REWARDS.Refine,
		elder = "Your dantian swells. Refine that qi at a glowing qi node, or back on your peak.",
		objective = "Circulate at a qi node or on your peak",
		-- a bar already full (passive cultivation while hunting) can't take a
		-- run, so it moves on to QC3, which breaks through
		done = function(_, data)
			return data.stats.circulationRuns >= (data.onboardingMark or 0) + 1 or barFull(data)
		end,
		guide = function(player)
			return refineGuide(player)
		end,
	},
	{
		id = "QC3",
		reward = REWARDS.QC3,
		elder = "First kills grant insight. You will need it to reach Qi Refining. Now break through again.",
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
		-- first so no standing lesson (DaoPractice holds for good) hides it
		id = "RootPill",
		elder = "A root pill! It can temper your very root. Sit in meditation, open your Spirit Root and absorb it.",
		objective = "Meditate, open Spirit Root and absorb the pill",
		reward = REWARDS.RootPill,
		-- not `early`: a pill absorbed mid-tutorial would purify the root the Testing
		-- Stone just revealed; it waits for free play
		persist = true,
		-- until the first pill is absorbed (data.lessons.RootPillUsed, set in check)
		when = function(_, data)
			return not data.lessons.RootPillUsed and rootPillReady(data)
		end,
		open = function(_, data)
			return data.lessons.RootPillUsed == true or rootPillReady(data)
		end,
		done = function(_, data)
			return data.lessons.RootPillUsed == true
		end,
		guide = function(player)
			if seated(player) then
				return { button = "RootPill", point = true, say = "Open your Spirit Root" }
			end
			return { button = "Cultivate", point = true, say = "Sit in meditation" }
		end,
	},
	{
		id = "Home",
		elder = "Your peak can grow with you. Plant a seed in your garden; herbs feed your cultivation and sell for Spirit Stones.",
		objective = "Plant a seed in your garden",
		reward = REWARDS.Home,
		when = function(_, data)
			return reached(data, "QC4") and not plantedAny(data)
		end,
		open = function(_, data)
			return reached(data, "QC4")
		end,
		done = function(_, data)
			return plantedAny(data)
		end,
		guide = function(player)
			if onOwnPeak(player) then
				return { place = "Garden" }
			end
			return travelTo(player, "Peak")
		end,
	},
	{
		id = "Bottleneck",
		elder = "Your technique has hit a bottleneck. Sit in meditation and comprehend it; insight opens the way.",
		objective = "Meditate and comprehend your technique",
		reward = REWARDS.Bottleneck,
		when = function(_, data)
			return bottlenecked(data)
		end,
		open = function(_, data)
			return bottlenecked(data) or comprehended(data)
		end,
		done = function(_, data)
			return comprehended(data)
		end,
		guide = function(player)
			return seatedTile(player, "PracticeTechnique")
		end,
	},
	{
		id = "WeaponRack",
		elder = "A cultivator need not keep to one blade. The sect's weapon rack on the Main Peak lends each disciple one weapon of every kind.",
		objective = "Take a new kind of weapon from the Main Peak rack",
		reward = REWARDS.WeaponRack,
		when = function(_, data)
			return reached(data, DaoPacing.FROM) and weaponClasses(data) < 2
		end,
		open = function(_, data)
			return reached(data, DaoPacing.FROM)
		end,
		done = function(_, data)
			return weaponClasses(data) >= 2
		end,
		guide = function(player)
			if nearTagged(player, "WeaponRack") then
				return { place = "WeaponRack" }
			end
			return travelTo(player, "MainPeak")
		end,
	},
	{
		id = "DaoPractice",
		elder = "Your body is ready for more than brawling. While you meditate, practice your weapon's forms to deepen its Dao.",
		objective = "Meditate and practice your weapon's Dao",
		reward = REWARDS.DaoPractice,
		when = function(_, data)
			return reached(data, DaoPacing.FROM)
		end,
		-- a finished drill sets the saved cooldown
		done = function(_, data)
			return data.daoPracticeReadyUnix > 0
		end,
		guide = function(player)
			return seatedTile(player, "PracticeDao")
		end,
	},
	{
		id = "Method",
		elder = "A true cultivation method! See it on your Self card. Should you find others, switch between them while you meditate.",
		objective = "Gain a cultivation method",
		reward = REWARDS.Method,
		when = function(_, data)
			return data.methods.active ~= ""
		end,
		done = function(_, data)
			return data.methods.active ~= ""
		end,
		guide = function()
			return { button = "Self" }
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
		local defier = Cultivation.heavenDefying(data)
		if data.insightEarned < stage.insight then
			table.insert(goals, {
				name = "Gather insight",
				detail = `Insight from first kills, kill milestones and bosses (an optional, faster road) opens the way to {nextStage.name}.`,
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
			name = if major and defier then `Face the tribulation: {nextStage.name}` else `Break through to {nextStage.name}`,
			detail = if major and defier
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
			name = "Slay the Elder Wolf King (optional)",
			detail = "He rules the far end of the wilds. A faster road, never required: his first defeat yields a technique manual and insight.",
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

-- Rewards ----------------------------------------------------------------------

-- Raw qi a reward's qiShare is worth at the player's stage (before the room cap).
local function rewardQi(reward: Pacing.QuestReward, data: PlayerData.Data): number
	return if reward.qiShare then math.floor(Cultivation.stage(data).dantian * reward.qiShare + 0.5) else 0
end

-- "30 Spirit Stones, 65 raw qi, 1 insight" (nil for no reward).
function Quests.rewardText(reward: Pacing.QuestReward?, data: PlayerData.Data): string?
	if not reward then
		return nil
	end
	local parts = {}
	if (reward.stones or 0) > 0 then
		table.insert(parts, `{reward.stones} Spirit Stones`)
	end
	local qi = rewardQi(reward, data)
	if qi > 0 then
		table.insert(parts, `{qi} raw qi`)
	end
	if (reward.insight or 0) > 0 then
		table.insert(parts, `{reward.insight} insight`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

-- Called with (player, questId) when a quest is claimed, for analytics.
Quests.onClaimed = {} :: { (Player, string) -> () }

-- Claim a done quest once: mark it first (so nothing can pay twice), then
-- grant its reward and say so.
local function claim(player: Player, data: PlayerData.Data, quest: Quest)
	if data.quests[quest.id] then
		return
	end
	data.quests[quest.id] = true
	for _, fn in Quests.onClaimed do
		task.spawn(fn, player, quest.id)
	end
	local reward = quest.reward
	if not reward then
		return
	end
	local at = rootPosition(player) or Vector3.zero
	local stones = reward.stones or 0
	if stones > 0 then
		data.stones += stones
		effectRemote:FireClient(player, "stones", at, stones)
	end
	-- raw qi only fills the room left in the dantian
	local qi = math.min(rewardQi(reward, data), math.max(0, Cultivation.stage(data).dantian - data.rawQi))
	if qi > 0 then
		data.rawQi += qi
		effectRemote:FireClient(player, "qi", at + Vector3.new(0, 3, 0), qi)
	end
	-- what actually landed, for the toast
	local got = {}
	if stones > 0 then
		table.insert(got, `{stones} Spirit Stones`)
	end
	if qi > 0 then
		table.insert(got, `{qi} raw qi`)
	end
	if (reward.insight or 0) > 0 then
		table.insert(got, `{reward.insight} insight`)
	end
	local gained = if #got > 0 then ` +{table.concat(got, ", ")}` else ""
	Cultivation.notify(player, `Objective complete: {quest.objective}!{gained}`)
	if (reward.insight or 0) > 0 then
		Progression.grantInsight(player, reward.insight :: number, quest.objective)
	end
	Cultivation.pushState(player)
end

-- Lessons whose objective is done while it applies get claimed.
local function claimLessons(player: Player, data: PlayerData.Data)
	for _, lesson in Quests.Lessons do
		if not data.quests[lesson.id] then
			local open = if lesson.open then lesson.open(player, data) else lesson.when(player, data)
			if open and lesson.done(player, data) then
				claim(player, data, lesson)
			end
		end
	end
end

-- The first lesson whose objective applies and isn't claimed yet.
local function openLesson(player: Player, data: PlayerData.Data): Lesson?
	for _, lesson in Quests.Lessons do
		if not data.quests[lesson.id] then
			local open = if lesson.open then lesson.open(player, data) else lesson.when(player, data)
			if open then
				return lesson
			end
		end
	end
	return nil
end

local function objectiveOf(quest: Quest, data: PlayerData.Data): string
	return if quest.progress then `{quest.objective} ({quest.progress(data)})` else quest.objective
end

local lastSent: { [Player]: string } = {}
local sessionLessons: { [Player]: { [string]: boolean } } = {} -- lessons shown this session
local claimed: { [Player]: string } = {} -- the early lesson holding the guide during the beats
local pillsHeld: { [Player]: number } = {}

local function key(guide: Guide?): string
	if not guide then
		return ""
	end
	return `{guide.button or ""}/{guide.to or ""}/{guide.dim == true}/{guide.place or ""}/{guide.point == true}/{guide.say or ""}`
end

-- In free play: say the first lesson whose moment has come (once ever), and
-- guide toward the first one shown this session (or `persist`, ever) that
-- still applies. Returns the fresh lesson, the guide and the guiding lesson.
local function lessons(player: Player, data: PlayerData.Data): (Lesson?, Guide?, Lesson?)
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
		local live = shown[lesson.id] or (lesson.persist and data.lessons[lesson.id])
		if live and lesson.guide and lesson.when(player, data) then
			return fresh, lesson.guide(player, data), lesson
		end
	end
	return fresh, nil, nil
end

-- During the onboarding beats, an `early` lesson may take the guide, but only
-- between steps: on the sect's safe ground (no fights there), while the beat's
-- own guide isn't a spotlight (dim: the hook steps, a full bar's Break Through)
-- and, to take it, while the player isn't sitting (a seat is usually a beat's
-- step under way). Once it holds the guide it keeps it, seated or not, until
-- one of the first two stops holding or its condition ends; then the beat
-- resumes. Its elder line comes the first time it takes the guide.
local function earlyLesson(player: Player, data: PlayerData.Data, beatGuide: Guide?): (Lesson?, Lesson?)
	local allowed = inSect(player) and not (beatGuide and beatGuide.dim)
	for _, lesson in Quests.Lessons do
		if lesson.early and allowed and lesson.when(player, data) and (claimed[player] == lesson.id or not seated(player)) then
			claimed[player] = lesson.id
			local fresh: Lesson? = nil
			if not data.lessons[lesson.id] then
				data.lessons[lesson.id] = true
				fresh = lesson
			end
			return fresh, lesson
		end
	end
	claimed[player] = nil
	return nil, nil
end

local function push(player: Player, data: PlayerData.Data, repeatElder: boolean?)
	local beat, index = current(data)
	local guide: Guide? = if beat.guide then beat.guide(player, data) else nil
	local lesson: Lesson? = nil -- a lesson saying its line now
	local guiding: Lesson? = nil -- the lesson whose guide shows
	if beat.id == "FreePlay" then
		lesson, guide, guiding = lessons(player, data)
	else
		lesson, guiding = earlyLesson(player, data, guide)
		if guiding and guiding.guide then
			guide = guiding.guide(player, data)
		end
	end
	-- the objective line: a guiding lesson's (while unclaimed), the current
	-- beat, the first open lesson, then the top quest board goal
	local shown: Quest? = nil
	if guiding and not data.quests[guiding.id] then
		shown = guiding
	elseif beat.id ~= "FreePlay" then
		shown = beat
	else
		shown = openLesson(player, data)
	end
	local objective = ""
	if shown then
		objective = objectiveOf(shown, data)
	else
		local top = Quests.goals(data)[1]
		objective = if top then `{top.name} ({top.progress})` else ""
	end
	local reward = if shown and not data.quests[shown.id] then Quests.rewardText(shown.reward, data) else nil
	local payload = {
		step = index - 1,
		beat = beat.id,
		elder = beat.elder,
		objective = objective,
		reward = reward, -- shown after the objective ("Reward: ...")
		travel = Quests.travelUnlocked(data),
		goals = Quests.goals(data),
		repeatElder = repeatElder,
		guide = guide,
		lesson = if lesson then { id = lesson.id, elder = lesson.elder } else nil,
	}
	-- only send when something visible changed
	local sendKey = `{payload.step}|{objective}|{reward or ""}|{#payload.goals}|{key(guide)}`
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
		claim(player, data, beat)
		for _, fn in Quests.onBeat do
			task.spawn(fn, player, index, beat.id)
		end
	end
end

-- A root pill absorbed (held count dropped) after the RootPill lesson: that
-- lesson is learned and its guide stops for good.
local function notePills(player: Player, data: PlayerData.Data)
	local held = rootPills(data)
	local before = pillsHeld[player]
	pillsHeld[player] = held
	if before and held < before and data.lessons.RootPill then
		data.lessons.RootPillUsed = true
	end
end

function Quests.check(player: Player)
	local data = PlayerData.get(player)
	if data then
		notePills(player, data)
		advance(player, data)
		claimLessons(player, data)
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
	claimed[player] = nil
	pillsHeld[player] = nil
end

return Quests
