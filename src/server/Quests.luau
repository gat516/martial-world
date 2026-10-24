--!strict
-- Onboarding (the scripted first ten minutes) and the quest board.
--
-- Onboarding is a list of beats, one system each, kept by id (data.beats). Each
-- beat has a one-line elder line (beside the guide), a short conversation for
-- when the player talks to the elder (`talk`), a short objective, a condition checked every
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
-- open lesson shown this session, then the wall card (wallCard: Hunt, Refine,
-- Break through, Store) or the top quest board goal; the reward rides along
-- (`reward` in QuestState) for the client to show after it.
--
-- Guide (sent in QuestState as `guide`; the client resolves the names):
--   button  a HUD control by key: "Cultivate" (sit), "Circulate", "Breakthrough",
--           "Practice", "PracticeTechnique", "PracticeDao" (the Practice row's
--           tiles; the client points at Practice until that row is open),
--           "Method", "SpiritRoot" (seated tiles),
--           "Travel", "Attack", "Inventory", "Self",
--           "RootPill" (the Absorb button on the Spirit Root page; until that
--           page is open the client points at the SpiritRoot tile),
--           "Seclusion" (the Enter Seclusion row in the meditation panel; until
--           it is open, the Method tile, which reads Seclusion without a method),
--           "Build" (the Build tile)
--   to      with button "Travel": the destination gate id to point at in the menu
--   dim     grey out the rest of the HUD until that button is pressed
--   point   (no dim) a bobbing pointer and a callout beside the button
--   say     the callout's short line for this step
--   button  also "Slot1".."Slot9", the hotbar's slots (the Cast beat)
--   place   a world target to walk to: "TestingStone", "Elder", "QuestBoard",
--           "QiNode" (nearest), "Enemy" (nearest living), "Array" (nearest
--           array of any kind), "Array:<gate id>", "Garden" (nearest HerbPlot
--           on your own peak), "WeaponRack" (nearest), "MyPeak" (your own
--           peak's plateau; the testbed's way home). With button "Travel" +
--           `to` (out in the wilds, where the button is hidden), walk to the
--           array; once its menu is open, `to` points at the destination.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Gates = require(ReplicatedStorage.Shared.Gates)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Cultivation = require(script.Parent.Cultivation)
local Circulation = require(script.Parent.Circulation)
local Peaks = require(script.Parent.Peaks)
local Peak = require(ReplicatedStorage.Shared.Peak)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local CollectionService = game:GetService("CollectionService")
local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)
local DaoPacing = require(ReplicatedStorage.Shared.Pacing).DaoPractice

local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent
local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent
local REWARDS = Pacing.Quests

export type Guide = { button: string?, to: string?, dim: boolean?, place: string?, point: boolean?, say: string? }

-- What the elder says when the player talks to him (the dialogue screen,
-- docs/ui/dialogue.md): 2-4 short lines and the player's reply (the lit
-- response; "Farewell." is always offered too). One new idea, said plainly.
export type Talk = { lines: { string }, reply: string }

-- A rewarded objective. Beats and lessons are Quests with a few fields more;
-- a future quest system's defs use the same shape.
export type Quest = {
	id: string, -- also its key in data.quests and Pacing.Quests
	elder: string, -- the elder's one line when it begins (beside the guide)
	talk: Talk?, -- the conversation when the player talks to him during it
	objective: string, -- the objective line
	progress: ((PlayerData.Data) -> string)?, -- shown after the objective, e.g. "1/3"
	done: (Player, PlayerData.Data) -> boolean,
	reward: Pacing.QuestReward?,
	guide: ((Player, PlayerData.Data) -> Guide?)?,
}

type Beat = Quest & {
	travel: boolean?, -- the formation is taught from this beat on
	skip: (() -> boolean)?, -- passed over while true, unmarked and unpaid (its system isn't in this build)
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
-- there is none, so walk to the nearest array (its prompt opens the menu). The
-- testbed has no arrays (everything stands on one baseplate): walk to `walk`.
local function travelTo(player: Player, gate: string, dim: boolean?, walk: string?): Guide?
	if Config.TESTBED then
		return if walk then { place = walk } else nil
	end
	if inSect(player) then
		return { button = "Travel", to = gate, dim = dim }
	end
	return { button = "Travel", to = gate, place = "Array" }
end

-- Out to the wolves: ride to the Sect Gate (spotlit on sect ground), then the
-- nearest living beast. Anywhere in the wilds, and in the testbed, the beast.
local function huntGuide(player: Player, dim: boolean?): Guide?
	if Config.TESTBED or nearGate(player) or not inSect(player) then
		return { place = "Enemy" }
	end
	return travelTo(player, "SectGate", dim)
end

-- Where to refine: circulate here if you can, else the nearest qi node out in
-- the wilds (one sits beside the Sect Gate's wolves), or your own peak from the sect.
local function refineGuide(player: Player): Guide?
	if Circulation.atRefiningSpot(player) then
		return seatedTile(player, "Circulate")
	end
	if inSect(player) then
		return travelTo(player, "Peak", nil, "MyPeak")
	end
	return { place = "QiNode" }
end

-- Circulate until the bar is full, then break through. Too little raw qi for a
-- run: before the first breakthrough, meditate (passive cultivation fills the
-- rest); after, go out and hunt for it. Never nil after the first breakthrough,
-- so the objective line always has somewhere to point (QC3 -> QC4 included).
local function climbGuide(player: Player, data: PlayerData.Data): Guide?
	if barFull(data) then
		return seatedTile(player, "Breakthrough", true)
	end
	if not Circulation.enoughQi(data) then
		if not data.beats.Breakthrough then
			return if seated(player) then nil else { button = "Cultivate" }
		end
		return huntGuide(player)
	end
	return refineGuide(player)
end

-- A lesson's guide never dims the HUD.
local function undimmed(guide: Guide?): Guide?
	if guide and guide.dim then
		local copy = table.clone(guide)
		copy.dim = nil
		return copy
	end
	return guide
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

-- Within walking distance of a Hub piece ("TestingStone", "QuestBoard").
local function nearHub(player: Player, name: string): boolean
	local hub = workspace:FindFirstChild("Hub")
	local at, here = positionOf(hub and hub:FindFirstChild(name)), rootPosition(player)
	return at ~= nil and here ~= nil and (here - at).Magnitude < WALKABLE
end

-- Walk to a Hub piece when it's close, else ride to the Main Peak.
local function toHub(player: Player, name: string, dim: boolean?): Guide?
	if nearHub(player, name) then
		return { place = name }
	end
	return travelTo(player, "MainPeak", dim, name)
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

-- The hotbar slot ("Slot<n>") of the first technique on it, if any.
local function techniqueSlot(data: PlayerData.Data): string?
	for i, id in data.hotbar do
		if Hotbar.isTechnique(id) then
			return `Slot{i}`
		end
	end
	return nil
end

-- Any technique cast at least once (casting grants technique XP, Combat grantXp).
local function castAny(data: PlayerData.Data): boolean
	for _, owned in data.techniques.owned do
		if owned.level > 1 or owned.xp > 0 then
			return true
		end
	end
	return false
end

-- A world cache found (a manual or method left in the wilds), not a sect rack.
local function cacheFound(data: PlayerData.Data): boolean
	for id in data.caches do
		if string.sub(id, 1, 5) ~= "rack:" then
			return true
		end
	end
	return false
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

-- The haul (src/server/Haul.luau, docs/systems/haul.md): what you carry out in
-- the wilds can be lost if you fall, until you store it at a bank point (home,
-- the sect, any array). The Store beat is done once Haul reports a bank through
-- `Haul.onBanked` (branch store-all: a list of (player, ...) callbacks, this
-- codebase's usual hook, or a signal with :Connect / a BindableEvent). With no
-- Haul module or no onBanked, the beat counts as done and is skipped, so this
-- works before and after that branch lands. Hooked in Quests.start.
local haulHooked = false
local haulModule: any = nil -- Haul, once hooked (the wall card's Store reads Haul.unbanked)

local function hookHaul()
	local module = script.Parent:FindFirstChild("Haul")
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local ok, haul = pcall(require, module)
	if not ok or type(haul) ~= "table" then
		return
	end
	haulModule = haul
	local function banked(player: any)
		local data = typeof(player) == "Instance" and player:IsA("Player") and PlayerData.get(player)
		if data then
			data.lessons.HaulStored = true
		end
	end
	local signal = (haul :: any).onBanked
	if typeof(signal) == "Instance" and signal:IsA("BindableEvent") then
		signal.Event:Connect(banked)
		haulHooked = true
	elseif type(signal) == "table" and type(signal.Connect) == "function" then
		signal:Connect(banked)
		haulHooked = true
	elseif type(signal) == "table" then
		table.insert(signal, banked)
		haulHooked = true
	end
end

-- The first session (docs/systems/onboarding.md "The first session"): one new
-- mechanic per beat, combat right after the first breakthrough, the spirit root
-- and the travel menu's wider use only once the hook has landed (QC3).
Quests.Beats = {
	{
		id = "Circulate",
		reward = REWARDS.Circulate,
		elder = "Welcome home, disciple. Sit, and circulate your qi.",
		talk = {
			lines = {
				"Welcome home, disciple. This peak is yours now.",
				"Qi already stirs inside you. Sit, and circulate it.",
				"Guide it out of the maze. Slowly; qi does not like to be rushed.",
			},
			reply = "I will try, Elder.",
		},
		objective = "Circulate your qi",
		done = function(_, data)
			return data.stats.circulationRuns >= 1
		end,
		guide = function(player)
			return seatedTile(player, "Circulate", true)
		end,
	},
	{
		-- the first run always fills the bar (Config.Circulation.FIRST_RUN_FILLS_BAR)
		id = "Breakthrough",
		reward = REWARDS.Breakthrough,
		elder = "Good. Your qi is full. Break through!",
		talk = {
			lines = {
				"Good. Your meridians brim with qi.",
				"When your bar is full, sit and break through.",
			},
			reply = "I am ready.",
		},
		objective = "Break through",
		done = function(_, data)
			return data.stats.breakthroughs >= 1
		end,
		guide = climbGuide,
	},
	{
		-- the old Gate beat (a ride) is merged in: the Travel button is spotlit
		-- straight to the Sect Gate, then the path leads to a wolf
		id = "FirstKill",
		reward = REWARDS.FirstKill,
		elder = "Hunt the wolves past the Sect Gate. Dodge the red ground!",
		talk = {
			lines = {
				"That breakthrough drank nearly all your qi.",
				"Spirit wolves prowl past the Sect Gate. Their qi is yours to take.",
				"Strike them. When the ground glows red, dodge.",
			},
			reply = "I am going.",
		},
		objective = "Defeat a spirit wolf",
		done = function(_, data)
			return data.stats.kills >= 1
		end,
		travel = true,
		guide = function(player)
			return huntGuide(player, true)
		end,
	},
	{
		id = "Technique",
		reward = REWARDS.Technique,
		elder = "Every beast teaches you something. Defeat a few more for a manual.",
		talk = {
			lines = {
				"Every beast you slay teaches you something.",
				"Defeat a few more. A technique manual awaits the patient hunter.",
			},
			reply = "A few more, then.",
		},
		objective = "Defeat 3 wolves",
		progress = function(data)
			return `{math.min(data.stats.kills, 3)}/3`
		end,
		-- the 3-kill milestone's manual (Fire Seal, any weapon, Dao 0), earned
		done = function(_, data)
			return data.milestones["3"] == true
		end,
		guide = function(player)
			return huntGuide(player)
		end,
	},
	{
		id = "Cast",
		reward = REWARDS.Cast,
		elder = "Your first technique! It waits on your hotbar. Cast it!",
		talk = {
			lines = {
				"A manual, and already you have its art. It waits on your hotbar.",
				"Tap it at a wolf. Arts spend combat qi; it comes back fast.",
			},
			reply = "Let them see it.",
		},
		objective = "Cast your new art",
		done = function(_, data)
			return castAny(data)
		end,
		guide = function(_, data)
			local slot = techniqueSlot(data)
			if slot then
				return { button = slot, point = true, say = "Cast it at a wolf", place = "Enemy" } :: Guide
			end
			-- a full hotbar: put it on from the Inventory's Arts
			return { button = "Inventory", point = true, say = "Put your art on the hotbar" } :: Guide
		end,
	},
	{
		-- the haul (Haul.luau, haul-spill); skipped without it (hookHaul)
		id = "Store",
		reward = REWARDS.Store,
		elder = "Fall out here and you drop half. Store it at an array.",
		talk = {
			lines = {
				"What you carry in the wilds is not safe yet.",
				"Fall out there, and half of it spills where you lie.",
				"Store it at any teleport array, or at home. Then it is yours.",
			},
			reply = "I will store it.",
		},
		objective = "Store your haul",
		skip = function()
			return not haulHooked
		end,
		done = function(_, data)
			return data.lessons.HaulStored == true
		end,
		guide = function(player)
			if Config.TESTBED then
				return { place = "MyPeak" } :: Guide? -- the testbed banks only by the spawn pad
			end
			if inSect(player) then
				return nil -- already on safe ground: the Store all button is right there
			end
			return { place = "Array" }
		end,
	},
	{
		id = "Refine",
		reward = REWARDS.Refine,
		elder = "Raw qi is not yours yet. Circulate it at a qi node.",
		talk = {
			lines = {
				"Your dantian swells, but raw qi is not yet your own.",
				"Refine it: circulate at a glowing qi node, or on your peak.",
			},
			reply = "I will refine it.",
		},
		objective = "Refine your raw qi",
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
		elder = "That qi is yours now. Fill your bar and break through!",
		talk = {
			lines = {
				"Hunt, refine, break through. That is how a cultivator climbs.",
				"Fill your bar once more, and break through again.",
			},
			reply = "Again, then.",
		},
		objective = "Reach Qi Condensation 3",
		done = function(_, data)
			return stageIndex(data) >= 3
		end,
		guide = climbGuide,
	},
	{
		-- the spirit root and the formations, once the hook has landed; the
		-- reveal card asks once to favourite the game (RootReveal)
		id = "Root",
		reward = REWARDS.Root,
		elder = "Let us see your spirit root. Ride to the Main Peak.",
		talk = {
			lines = {
				"The teleport arrays carry disciples between the peaks.",
				"Ride one to the Main Peak and touch the Testing Stone.",
				"Let us see what root your qi grows from.",
			},
			reply = "To the Testing Stone.",
		},
		objective = "Touch the Testing Stone",
		done = function(_, data)
			return Roots.tested(data.root)
		end,
		guide = function(player)
			return toHub(player, "TestingStone", true)
		end,
	},
	{
		-- the QC3 -> QC4 stretch, the longest of the first session: the climb guide
		-- always points somewhere (home to refine, out to hunt, Break Through)
		id = "QC4",
		reward = REWARDS.QC4,
		elder = "A fine root! Hunt, refine and break through once more.",
		talk = {
			lines = {
				"Your root speeds every step you take from here.",
				"Hunt in the wilds, refine at home or a node, then break through.",
			},
			reply = "I will climb.",
		},
		objective = "Reach Qi Condensation 4",
		done = function(_, data)
			return stageIndex(data) >= 4
		end,
		guide = climbGuide,
	},
	{
		id = "FreePlay",
		elder = "Cultivate until you hit a wall. Break it, and come home stronger.",
		talk = {
			lines = {
				"The fourth stage already. Then hear the whole path once.",
				"Cultivate until you hit a wall. Go out and break it. Come home stronger.",
				"Every realm is that, again and again.",
			},
			reply = "I understand, Elder.",
		},
		objective = "",
		done = function()
			return false
		end,
	},
} :: { Beat }

local FREE_PLAY = #Quests.Beats

-- The second session (the Seclusion lesson): the stage each player joined this
-- session at, and whether they have sat down since a join at QC4 or later.
local joinStage: { [Player]: number } = {}
local satSinceJoin: { [Player]: boolean } = {}

-- The first seclusion waits for the second session (user, 2026-10-24): the first
-- sit after a join that began at QC4 or later, or QC5 for a player who never
-- rejoins. Home comes first (the seed is what it tends), unless QC5 is reached.
local function seclusionDue(player: Player, data: PlayerData.Data): boolean
	if not reached(data, "QC4") or data.seclusion.first then
		return false
	end
	if reached(data, "QC5") then
		return true
	end
	return (data.quests.Home == true or Config.TESTBED) and satSinceJoin[player] == true
end

-- One idea per chapter, each a live system (docs/systems/onboarding.md, "One idea
-- per chapter"): QC4 Home, the second session Seclusion, QC5 the Borderlands and
-- their rumours, QC6 Herbs, QC7 the Dao drill, QC9 the heart demon, QR1 the weapon
-- rack, QR2 building. Elder lines at most 12 words (the why), objectives at most 5
-- (the what), the detail in `talk`.
Quests.Lessons = {
	{
		-- first so no standing lesson hides it
		id = "RootPill",
		elder = "A root pill! Sit, open your Spirit Root, and absorb it.",
		talk = {
			lines = {
				"A root pill! A rare fortune: it tempers your very root.",
				"Sit in meditation, open your Spirit Root, and absorb it.",
			},
			reply = "I will absorb it.",
		},
		objective = "Absorb the root pill",
		reward = REWARDS.RootPill,
		-- not `early`, and never before QC5: a pill absorbed in the hook would
		-- change the root the Testing Stone just revealed (user, 2026-10-23: "pill
		-- eating made no sense during onboarding"). Pills are rare boss and treasure
		-- drops, so most players meet this long after the hook.
		persist = true,
		-- until the first pill is absorbed (data.lessons.RootPillUsed, set in check)
		when = function(_, data)
			return not data.lessons.RootPillUsed and reached(data, "QC5") and rootPillReady(data)
		end,
		open = function(_, data)
			return data.lessons.RootPillUsed == true or (reached(data, "QC5") and rootPillReady(data))
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
		-- QC4, the abode: the only idea of its chapter
		id = "Home",
		elder = "Your peak grows with you. Plant a seed in your garden.",
		talk = {
			lines = {
				"Your peak can grow with you.",
				"Plant a seed in your garden. Herbs feed your cultivation.",
				"They sell for Spirit Stones, too.",
			},
			reply = "I will plant one.",
		},
		objective = "Plant a seed",
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
			return travelTo(player, "Peak", nil, "MyPeak")
		end,
	},
	{
		-- the second session (seclusionDue): the AFK mode as a reward moment. The
		-- first seclusion ends by itself after Pacing.Seclusion FIRST_SECONDS with a
		-- generous card (Seclusion.luau), which is what `done` reads.
		id = "Seclusion",
		elder = "Rest now. Your peak works for you while you're away.",
		talk = {
			lines = {
				"A cultivator who never rests burns out.",
				"Sit on your own peak and enter seclusion.",
				"Your garden is tended and stones gather, even while you are away.",
			},
			reply = "I will try it.",
		},
		objective = "Enter seclusion at home",
		reward = REWARDS.Seclusion,
		when = seclusionDue,
		open = function(player, data)
			return reached(data, "QC4")
				and (data.seclusion.first == true or data.lessons.Seclusion == true or seclusionDue(player, data))
		end,
		done = function(_, data)
			return data.seclusion.first == true
		end,
		guide = function(player)
			if player:GetAttribute("Secluded") then
				return nil -- secluded: nothing to point at
			end
			if not onOwnPeak(player) then
				return travelTo(player, "Peak", nil, "MyPeak")
			end
			if seated(player) then
				return { button = "Seclusion", point = true, say = "Enter Seclusion" }
			end
			return { button = "Cultivate", point = true, say = "Sit in meditation" }
		end,
	},
	{
		-- QC5, the new region and its rumours as one idea: the Ruined Borderlands
		-- open (Regions MiddleWilds) and their hidden caches. No guide: finding it
		-- is the point. The sect board is pointed at from the talk.
		id = "Rumours",
		elder = "The Borderlands are open. Old manuals hide off their paths.",
		talk = {
			lines = {
				"The Ruined Borderlands are open to you now.",
				"Wanderers hid old manuals there. Look off the paths, behind the falls.",
				"The sect board on the Main Peak has daily tasks, too.",
			},
			reply = "I will search.",
		},
		objective = "Find a hidden cache",
		reward = REWARDS.Rumours,
		when = function(_, data)
			return reached(data, "QC5") and not cacheFound(data)
		end,
		open = function(_, data)
			return reached(data, "QC5")
		end,
		done = function(_, data)
			return cacheFound(data)
		end,
	},
	{
		-- QC6, herbs matter: the mini-wall, where one dantian no longer fills the bar
		id = "Herbs",
		elder = "Herbs are qi you can carry. Eat one when you run dry.",
		talk = {
			lines = {
				"Herbs are qi you can carry.",
				"Eat one from your pouch when your dantian runs dry.",
				"The Herbalist at the Spirit Market sells seeds to grow more.",
			},
			reply = "I will try one.",
		},
		objective = "Eat a herb",
		reward = REWARDS.Herbs,
		when = function(_, data)
			return reached(data, "QC6") and not data.lessons.HerbEaten
		end,
		open = function(_, data)
			return reached(data, "QC6")
		end,
		-- set when a herb is eaten (Inventory.use)
		done = function(_, data)
			return data.lessons.HerbEaten == true
		end,
		guide = function()
			return { button = "Inventory", point = true, say = "Eat a herb" }
		end,
	},
	{
		-- QC7 (Pacing.DaoPractice.FROM), the Dao drill: its own chapter's idea
		id = "DaoPractice",
		elder = "Practice your weapon's forms as you sit. Its Dao will deepen.",
		talk = {
			lines = {
				"Your body is ready for more than brawling.",
				"While you meditate, practice your weapon's forms.",
				"That is how its Dao deepens, and greater arts open.",
			},
			reply = "I will practice.",
		},
		objective = "Practice your weapon's Dao",
		reward = REWARDS.DaoPractice,
		when = function(_, data)
			return reached(data, DaoPacing.FROM) and data.daoPracticeReadyUnix == 0
		end,
		open = function(_, data)
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
		-- QC9, the heart-demon trial (HeartDemon.luau): offered from the seat once a
		-- session, and on Break Through at QC9. It replaces the old Wall lesson; the
		-- free-play objective line already says what the wall needs.
		id = "HeartDemon",
		elder = "Your heart demon stirs. Sit, and face it honestly.",
		talk = {
			lines = {
				"At the edge of a realm, your heart demon wakes.",
				"It asks how you climbed. Answer it truly.",
				"Facing it costs nothing, and it may temper your foundation.",
			},
			reply = "I will face it.",
		},
		objective = "Face your heart demon",
		reward = REWARDS.HeartDemon,
		when = function(_, data)
			return reached(data, "QC9") and not data.heartDemon.trials.QiCondensation
		end,
		open = function(_, data)
			return reached(data, "QC9")
		end,
		done = function(_, data)
			return data.heartDemon.trials.QiCondensation ~= nil
		end,
		guide = function(player, data)
			-- "Not now" snoozes the seat's offer; nothing to point at until it returns
			local declined = data.heartDemon.declined.QiCondensation
			if declined and os.time() - declined < Pacing.HeartDemon.OFFER_COOLDOWN then
				return nil
			end
			if seated(player) then
				return nil -- the seat offers it
			end
			return { button = "Cultivate", point = true, say = "Sit to face it" }
		end,
	},
	{
		id = "Bottleneck",
		elder = "Your art is stuck. Sit and spend stones to break it.",
		talk = {
			lines = {
				"Your technique has hit a bottleneck. Swinging harder will not break it.",
				"Sit and comprehend it. It costs Spirit Stones.",
				"Greater arts also need a deeper weapon Dao.",
			},
			reply = "I will sit with it.",
		},
		objective = "Break your art's bottleneck",
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
		-- QR1 (Pacing.DaoPractice.RACK_FROM), the second weapon
		id = "WeaponRack",
		elder = "One blade is not enough. Borrow another from the sect's rack.",
		talk = {
			lines = {
				"A cultivator need not keep to one blade.",
				"The rack on the Main Peak lends one weapon of every kind.",
			},
			reply = "I will choose one.",
		},
		objective = "Take a new weapon",
		reward = REWARDS.WeaponRack,
		when = function(_, data)
			return reached(data, DaoPacing.RACK_FROM) and weaponClasses(data) < 2
		end,
		open = function(_, data)
			return reached(data, DaoPacing.RACK_FROM)
		end,
		done = function(_, data)
			return weaponClasses(data) >= 2
		end,
		guide = function(player)
			if nearTagged(player, "WeaponRack") then
				return { place = "WeaponRack" }
			end
			return travelTo(player, "MainPeak", nil, "WeaponRack")
		end,
	},
	{
		-- QR2, building (Build.luau, Peaks): one piece placed. The peak score raises
		-- meditation on your peak (docs/systems/build.md "Peak score"), the abode lever
		-- for the QR slowdown.
		id = "Build",
		elder = "Build up your peak. A finer home makes meditation stronger.",
		talk = {
			lines = {
				"Your abode can do more than grow herbs.",
				"Place a piece on your peak. Every piece raises its score.",
				"A higher score makes your meditation there stronger.",
			},
			reply = "I will build.",
		},
		objective = "Place one build piece",
		reward = REWARDS.Build,
		when = function(_, data)
			return reached(data, "QR2") and data.stats.placed == 0
		end,
		open = function(_, data)
			return reached(data, "QR2")
		end,
		done = function(_, data)
			return data.stats.placed > 0
		end,
		guide = function(player)
			if onOwnPeak(player) then
				return { button = "Build", point = true, say = "Place one piece" }
			end
			return travelTo(player, "Peak", nil, "MyPeak")
		end,
	},
	{
		id = "Method",
		elder = "A true cultivation method! See it on your Self card.",
		talk = {
			lines = {
				"A true cultivation method! You can see it on your Self card.",
				"Should you find others, switch between them while you meditate.",
			},
			reply = "Thank you, Elder.",
		},
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
-- Still to write, one per chapter as each system lands (docs/roadmap.md section 2):
-- one lesson per QR third (QR4: the garden aura and build items against the
-- slowdown; a master, the Halls, rifts) and FE the depth (methods beyond Method
-- above, weapon refinement, treasures, pets), and the circulation games past the
-- Maze, one per breather. Each is a lesson here: an elder line, a talk, a rewarded
-- objective and a guide, gated by `reached(data, "<stage>")`.

-- The first beat not yet done (FreePlay once they all are), and its index.
local function current(data: PlayerData.Data): (Beat, number)
	for i = 1, FREE_PLAY - 1 do
		local beat = Quests.Beats[i]
		-- a skipped beat is passed over unmarked, so it's met once its system exists
		if not data.beats[beat.id] and not (beat.skip and beat.skip()) then
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
			detail = "He rules the far end of the wilds. A faster road, never required: his first defeat yields a technique manual.",
			progress = "0/1",
		})
	end
	for _, m in Pacing.Rewards.MILESTONES do
		if not data.milestones[tostring(m.kills)] then
			local reward = if m.manual then Techniques.Defs[m.manual].name else "nothing"
			table.insert(goals, {
				name = `Slay {m.kills} enemies`,
				detail = `Reward: {reward}.`,
				progress = `{data.stats.kills}/{m.kills}`,
			})
			break
		end
	end
	local owned = 0
	for _ in data.techniques.owned do
		owned += 1
	end
	if owned < #Techniques.Order then
		table.insert(goals, {
			name = "Learn every technique",
			detail = "Manuals come from kill milestones and the Elder Wolf King. Greater arts need a deeper weapon Dao to learn.",
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

-- "30 Spirit Stones, 65 raw qi" (nil for no reward).
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
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

-- Called with (player, questId) when a quest is claimed, for analytics (the
-- sect's dailies and chain steps call these too).
Quests.onClaimed = {} :: { (Player, string) -> () }

-- Set by Sect: the board's Read prompt opens the sect board (true) once the
-- player has reached it, else the goals list opens; and the objective line of the
-- sect quest the player tracks (free play only, before the open lessons).
Quests.openBoard = nil :: ((Player) -> boolean)?
Quests.trackedObjective = nil :: ((Player, PlayerData.Data) -> string?)?

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
		Analytics.stones(player, "source", stones, data.stones, "Onboarding", "Quest")
		effectRemote:FireClient(player, "stones", at, stones)
	end
	-- raw qi only fills the room left in the dantian
	local qi = math.min(rewardQi(reward, data), math.max(0, Cultivation.stage(data).dantian - data.rawQi))
	if qi > 0 then
		data.rawQi += qi
		Analytics.qi(player, "source", qi, data.rawQi, "Onboarding", "Quest")
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
	local gained = if #got > 0 then ` +{table.concat(got, ", ")}` else ""
	Cultivation.notify(player, `Objective complete: {quest.objective}!{gained}`)
	Cultivation.pushState(player)
end

-- Lessons whose objective is done while it applies get claimed.
local function claimLessons(player: Player, data: PlayerData.Data)
	for _, lesson in Quests.Lessons do
		if not data.quests[lesson.id] then
			local open = if lesson.open then lesson.open(player, data) else lesson.when(player, data)
			if open and lesson.done(player, data) then
				claim(player, data, lesson)
				Analytics.event(player, "Lesson", 1, lesson.id, "claimed")
			end
		end
	end
end

-- The first lesson whose objective applies and isn't claimed yet.
-- With `live`, only a lesson shown this session (or a `persist` one, ever): in a
-- later session an unclaimed lesson leaves the objective line to the wall card.
local function openLesson(player: Player, data: PlayerData.Data, live: { [string]: boolean }?): Lesson?
	for _, lesson in Quests.Lessons do
		local current = live == nil or live[lesson.id] or (lesson.persist and data.lessons[lesson.id])
		if current and not data.quests[lesson.id] then
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
local guidingNow: { [Player]: Lesson } = {} -- the lesson whose guide last showed (talk)
local freeSince: { [Player]: number } = {} -- os.clock() free play was first seen this session
local LESSON_DELAY = 20

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
	-- a new lesson's line waits LESSON_DELAY into free play, so it never lands on
	-- top of FreePlay's own line (Home is due the moment QC4 ends the beats)
	freeSince[player] = freeSince[player] or os.clock()
	local settled = os.clock() - (freeSince[player] :: number) >= LESSON_DELAY
	for _, lesson in (if settled then Quests.Lessons else {}) :: { Lesson } do
		if not data.lessons[lesson.id] and lesson.when(player, data) then
			data.lessons[lesson.id] = true
			shown[lesson.id] = true
			fresh = lesson
			Analytics.event(player, "Lesson", 1, lesson.id, "shown")
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
				Analytics.event(player, "Lesson", 1, lesson.id, "shown")
			end
			return fresh, lesson
		end
	end
	claimed[player] = nil
	return nil, nil
end

-- The wall card (docs/design-reviews/onboarding-lessons.md, rec 1): in free play,
-- with no lesson or tracked sect quest to show, the objective line says what to do
-- now, one verb per state, from the checks the guides use:
--   Break through   the bar is full (a heaven-defier at a major: Face the tribulation)
--   Store           an unbanked haul in the wilds below STORE_HEALTH (a fall spills it)
--   Hunt            too little raw qi for a run (Circulation.enoughQi): raw qi / a run's
--   Refine          raw qi waiting: cultivation / bar
-- nil at the last stage or a method's limit: the quest board's top goal instead.
local STORE_HEALTH = 0.5

local function haulAtRisk(player: Player): boolean
	if not haulModule or inSect(player) or onOwnPeak(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MaxHealth <= 0 or humanoid.Health / humanoid.MaxHealth >= STORE_HEALTH then
		return false
	end
	local haul = haulModule.unbanked(player)
	return haul.rawQi > 0
		or haul.stones > 0
		or next(haul.herbs) ~= nil
		or next(haul.items) ~= nil
		or next(haul.seeds) ~= nil
end

local function wallCard(player: Player, data: PlayerData.Data): string?
	local here = Realms.get(data.realm.major, data.realm.minor)
	local nextStage = Realms.after(here.major, here.minor)
	if not nextStage or Cultivation.methodLimit(data, nextStage) then
		return nil
	end
	if barFull(data) then
		if nextStage.major ~= here.major and Cultivation.heavenDefying(data) then
			return "Face the tribulation"
		end
		return "Break through"
	end
	if haulAtRisk(player) then
		return "Store your haul"
	end
	if not Circulation.enoughQi(data) then
		return `Hunt beasts ({math.floor(data.rawQi)}/{Circulation.qiForRun(data)})`
	end
	return `Refine your qi ({math.floor(data.cultivation)}/{Cultivation.stage(data).bar})`
end

local function push(player: Player, data: PlayerData.Data)
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
	guidingNow[player] = guiding
	-- the objective line: a guiding lesson's (while unclaimed), the current
	-- beat, the first open lesson shown this session, then the wall card (or the
	-- top quest board goal)
	local shown: Quest? = nil
	local tracked: string? = nil -- a sect quest the player tracks (Sect), in free play
	if guiding and not data.quests[guiding.id] then
		shown = guiding
	elseif beat.id ~= "FreePlay" then
		shown = beat
	else
		tracked = if Quests.trackedObjective then Quests.trackedObjective(player, data) else nil
		if not tracked then
			shown = openLesson(player, data, sessionLessons[player] or {})
		end
	end
	local objective = ""
	if shown then
		objective = objectiveOf(shown, data)
	elseif tracked then
		objective = tracked
	else
		-- free play's wall card, else (the last stage, a method's limit) the board's top goal
		local card = if beat.id == "FreePlay" then wallCard(player, data) else nil
		local top = if card then nil else Quests.goals(data)[1]
		objective = if card then card elseif top then `{top.name} ({top.progress})` else ""
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
		guide = guide,
		lesson = if lesson then { id = lesson.id, elder = lesson.elder } else nil,
	}
	-- only send when something visible changed
	local sendKey = `{payload.step}|{objective}|{reward or ""}|{#payload.goals}|{key(guide)}`
	if lastSent[player] ~= sendKey or lesson then
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
		-- the stage this session began at, and a sit since (the Seclusion lesson)
		joinStage[player] = joinStage[player] or stageIndex(data)
		if (joinStage[player] :: number) >= 4 and seated(player) then
			satSinceJoin[player] = true
		end
		advance(player, data)
		claimLessons(player, data)
		push(player, data)
	end
end

-- What the elder says when talked to: the current beat's conversation; in free
-- play the guiding (or first open) lesson's while unclaimed, the loop once
-- (FreePlay's talk, data.lessons.Loop), then the top quest board goal.
-- `board` offers the quest board as a response (free play).
-- A quest without its own conversation falls back on its elder line.
local function talkOf(quest: Quest): Talk
	return quest.talk or { lines = { quest.elder }, reply = "I understand, Elder." }
end

local function conversation(player: Player, data: PlayerData.Data): (Talk, boolean)
	local beat = current(data)
	if beat.id ~= "FreePlay" then
		return talkOf(beat), false
	end
	local guiding = guidingNow[player]
	local lesson = if guiding and not data.quests[guiding.id] then guiding else openLesson(player, data)
	if lesson then
		return talkOf(lesson), true
	end
	if not data.lessons.Loop then
		data.lessons.Loop = true
		return talkOf(beat), true
	end
	local top = Quests.goals(data)[1]
	if top then
		return { lines = { `Your next step: {top.name}.`, top.detail }, reply = "I will see to it." }, true
	end
	return { lines = { "Keep cultivating. The path is long, and you are on it." }, reply = "I will, Elder." }, true
end

-- The elder's Talk prompt: the client opens the dialogue screen (Onboarding).
function Quests.talk(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local talk, board = conversation(player, data)
	questRemote:FireClient(player, { talk = { lines = talk.lines, reply = talk.reply, board = board } })
end

function Quests.start()
	hookHaul()
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
			local data = PlayerData.get(player)
			if data then
				data.lessons.BoardRead = true -- read once (HeartDemon's lone-wolf question)
			end
			if not (Quests.openBoard and Quests.openBoard(player)) then
				questRemote:FireClient(player, { openBoard = true })
			end
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
	guidingNow[player] = nil
	freeSince[player] = nil
	joinStage[player] = nil
	satSinceJoin[player] = nil
end

return Quests
