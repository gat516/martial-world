--!strict
-- The sect MVP (docs/systems/sect.md; screens docs/ui/sect-board.md; tuning
-- Pacing.Sect): rank and contribution, the board's dailies, one chapter chain and
-- the Pavilion. Contribution is soft (roadmap 3b): the board only offers, nothing
-- counts down or nags, and ignoring it costs nothing.
--   Rank       Outer -> Inner -> Core Disciple. A promotion needs its realm and
--              contribution EARNED (all time), and is offered as a notice on the
--              board; claiming it opens the rank card (SectRank.rankUp on the client).
--   Dailies    OFFERED kinds rolled at 00:00 UTC (like the daily login), at most
--              COMBAT_MAX of them combat, the rest peaceful. Taking one starts it
--              (counters are read from when it was taken); a done one is claimed at
--              the board for contribution (WEEK_CAP a week) and Spirit Stones by major.
--   Chain      "Ash Past the Gorge" (Ruined Borderlands, QC5-QC9): one step at a
--              time, each from its stage; a combat step always has a peaceful path
--              beside it, and either finishes the step. Each claim sends the quest
--              card; the last ends at the Broken Pagoda (or the Elder Wolf King).
--   Pavilion   seed packets by tier, a spirit ring slot per major, copies of the
--              kill-milestone manuals, root pill fragments (a few of each a week,
--              Tuning.FRAGMENTS). Never qi, never whole root pills.
-- From QC5 (Pacing.Sect.OPENS; the testbed at any realm) the board's Read prompt
-- opens the sect board (Quests.openBoard); before that it opens the goals list.
-- Client: src/client/SectView.luau, through QuestState { sect = view, open = bool }
-- and { sectRankUp = ... }; actions come in on CultivationAction ("sect", op, arg):
--   "take" kind | "claim" kind | "promote" | "buy" stockId | "track" questId ("" = none)

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Regions = require(ReplicatedStorage.Shared.Regions)
local RootDefs = require(ReplicatedStorage.Shared.Roots)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)
local Foundation = require(script.Parent.Foundation)
local Progression = require(script.Parent.Progression)
local Inventory = require(script.Parent.Inventory)
local Quests = require(script.Parent.Quests)
local Analytics = require(script.Parent.Analytics)

local Tuning = Pacing.Sect
local questRemote = ReplicatedStorage.Remotes.QuestState :: RemoteEvent
local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local Sect = {}

type Task = PlayerData.SectTask

--[[ Realm and rank ]]

local function stageIndex(data: PlayerData.Data): number
	return Realms.index(data.realm.major, data.realm.minor)
end

local function reached(data: PlayerData.Data, key: string?): boolean
	local stage = key and Realms.ByKey[key]
	return stage == nil or stageIndex(data) >= Realms.index(stage.major, stage.minor)
end

local function stageName(key: string): string
	local stage = Realms.ByKey[key]
	return if stage then stage.name else key
end

-- The board's dailies and the chain are open (QC5; the testbed at any realm).
local function opened(data: PlayerData.Data): boolean
	return Config.TESTBED or reached(data, Tuning.OPENS)
end

local function rankIndex(id: string): number
	for i, r in Tuning.RANKS do
		if r.id == id then
			return i
		end
	end
	return 1
end

local function rankName(id: string): string
	return Tuning.RANKS[rankIndex(id)].name
end

local function nextRank(data: PlayerData.Data)
	return Tuning.RANKS[rankIndex(data.sect.rank) + 1]
end

local function promotable(data: PlayerData.Data): boolean
	local r = nextRank(data)
	return r ~= nil and reached(data, r.realm) and data.sect.earned >= (r.earned or 0)
end

--[[ Counters a task reads (from when it was taken) ]]

local function cachesFound(data: PlayerData.Data): number
	local n = 0
	for id in data.caches do
		if string.sub(id, 1, 5) ~= "rack:" then
			n += 1
		end
	end
	return n
end

-- A world manual cache this player hasn't claimed (so a cache task can be done).
local function cacheLeft(data: PlayerData.Data): boolean
	for _, anchor in CollectionService:GetTagged("ManualCache") do
		local id = anchor:GetAttribute("Cache")
		if type(id) == "string" and id ~= "" and not data.caches[id] then
			return true
		end
	end
	return false
end

-- Banked herbs of a tier, cheapest first (what a herb errand hands over).
local function herbsOfTier(data: PlayerData.Data, tier: number): ({ string }, number)
	local ids, total = {}, 0
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		if herb and herb.tier == tier and (data.herbs[id] or 0) > 0 then
			table.insert(ids, id)
			total += data.herbs[id]
		end
	end
	table.sort(ids, function(a, b)
		return (Herbs.Defs[a].sellPrice or 0) < (Herbs.Defs[b].sellPrice or 0)
	end)
	return ids, total
end

local function takeHerbs(data: PlayerData.Data, tier: number, n: number): boolean
	local ids, total = herbsOfTier(data, tier)
	if total < n then
		return false
	end
	for _, id in ids do
		local give = math.min(n, data.herbs[id])
		data.herbs[id] -= give
		if data.herbs[id] <= 0 then
			data.herbs[id] = nil
		end
		n -= give
		if n <= 0 then
			break
		end
	end
	return true
end

-- Counter kinds, shared by dailies and chain paths:
--   counter  a running total; progress = now - base
--   held     what's held now (herbs; handed over on claim)
--   (neither) progress is pushed by a hook (kills) or the place check
type Counter = {
	counter: ((PlayerData.Data) -> number)?,
	held: ((PlayerData.Data, number) -> number)?,
}
local COUNTERS: { [string]: Counter } = {
	gather = { counter = function(d)
		return d.stats.gathered
	end },
	seclusion = { counter = function(d)
		return d.stats.secluded
	end },
	store = { counter = function(d)
		return d.stats.stored
	end },
	harvest = { counter = function(d)
		return d.stats.harvests
	end },
	cache = { counter = cachesFound },
	elites = { counter = function(d)
		return d.stats.elites + d.stats.apexes
	end },
	herbs = { held = function(d, tier)
		local _, total = herbsOfTier(d, tier)
		return total
	end },
}

local function newTask(data: PlayerData.Data, kind: string, goal: number, tier: number?): Task
	local c = COUNTERS[kind]
	return { goal = goal, base = if c and c.counter then c.counter(data) else 0, progress = 0, tier = tier }
end

local function progressOf(data: PlayerData.Data, kind: string, t: Task): number
	local c = COUNTERS[kind]
	local n = t.progress
	if c and c.held then
		n = c.held(data, t.tier or 1)
	elseif c and c.counter then
		n = c.counter(data) - t.base
	end
	return math.clamp(n, 0, t.goal)
end

--[[ The daily pool ]]

-- Order on the board and in the roll; `scale` divides progress for display
-- (seclusion counts seconds, shown in minutes).
local KIND_ORDER = { "hunt", "herbs", "gather", "seclusion", "store", "harvest", "cache" }
type Kind = {
	title: string,
	glyph: string,
	scale: number?,
	text: (goal: number, tier: number?) -> string, -- the objective
	body: (goal: number, tier: number?) -> string, -- the notice's line
	available: ((PlayerData.Data) -> boolean)?,
}
local function numeral(tier: number?): string
	return Herbs.TierNumerals[tier or 1] or "I"
end
local KINDS: { [string]: Kind } = {
	hunt = {
		title = "Thin the beasts",
		glyph = "fight",
		text = function(goal)
			return `Slay {goal} beasts near your realm`
		end,
		body = function(goal)
			return `The wilds press on the sect's roads. Slay {goal} beasts of your strength.`
		end,
	},
	herbs = {
		title = "Herbs for the alchemy hall",
		glyph = "give",
		text = function(goal, tier)
			return `Bring {goal} tier {numeral(tier)} herbs to the board`
		end,
		body = function(goal, tier)
			return `The alchemy hall is short of herbs. Bring {goal} of tier {numeral(tier)}.`
		end,
	},
	gather = {
		title = "Draw from the qi veins",
		glyph = "qi",
		text = function(goal)
			return `Gather qi at {goal} nodes in the wilds`
		end,
		body = function(goal)
			return `The veins in the wilds overflow. Gather at {goal} qi nodes.`
		end,
	},
	seclusion = {
		title = "Close the door",
		glyph = "bow",
		scale = 60,
		text = function(goal)
			return `Spend {goal // 60} minutes in seclusion on your peak`
		end,
		body = function(goal)
			return `Shut yourself away for {goal // 3600} hour on your peak. The sect values patience.`
		end,
	},
	store = {
		title = "Bring it home",
		glyph = "chest",
		text = function()
			return "Store a haul at home, the sect or an array"
		end,
		body = function()
			return "Carry a haul out of the wilds and store all of it safely."
		end,
	},
	harvest = {
		title = "Tend the spirit beds",
		glyph = "harvest",
		text = function(goal)
			return `Harvest {goal} plants on your peak`
		end,
		body = function(goal)
			return `A disciple's garden feeds the sect. Harvest {goal} plants.`
		end,
	},
	cache = {
		title = "A rumour of a cache",
		glyph = "chest",
		text = function()
			return "Find a manual cache in the wilds"
		end,
		body = function()
			return "Old disciples hid their manuals in the wilds. Find one."
		end,
		available = cacheLeft,
	},
}

local function goalOf(data: PlayerData.Data, kind: string): number
	local def = Tuning.DAILIES[kind]
	return if def.goal then def.goal[data.realm.major] or 1 else 1
end

local function shuffle(list: { string })
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Today's offer: COMBAT_MAX combat kinds at most (each with COMBAT_CHANCE), the
-- rest peaceful, so a gardener always has a full board.
local function roll(data: PlayerData.Data): { string }
	local combat, peaceful = {}, {}
	for _, kind in KIND_ORDER do
		local def, k = Tuning.DAILIES[kind], KINDS[kind]
		if def and k and (not k.available or k.available(data)) then
			table.insert(if def.combat then combat else peaceful, kind)
		end
	end
	shuffle(combat)
	shuffle(peaceful)
	local picked = {}
	for i = 1, math.min(Tuning.COMBAT_MAX, #combat) do
		if math.random() < Tuning.COMBAT_CHANCE then
			table.insert(picked, combat[i])
		end
	end
	for _, kind in peaceful do
		if #picked >= Tuning.OFFERED then
			break
		end
		table.insert(picked, kind)
	end
	table.sort(picked, function(a, b)
		return (table.find(KIND_ORDER, a) or 0) < (table.find(KIND_ORDER, b) or 0)
	end)
	return picked
end

-- A new day rolls a new offer (unfinished dailies lapse, no penalty); a new week
-- resets the week's earnings against the cap.
local function refresh(data: PlayerData.Data)
	local sect = data.sect
	local day = os.time() // 86400
	if sect.day ~= day then
		sect.day = day
		sect.offered = roll(data)
		sect.taken = {}
		if string.sub(sect.tracked, 1, 6) == "daily:" then
			sect.tracked = ""
		end
	end
	local week = (day + 3) // 7 -- weeks from Monday (1970-01-01 was a Thursday)
	if sect.weekId ~= week then
		sect.weekId = week
		sect.week = 0
		sect.weekBought = {}
	end
end

--[[ The chapter chain: Ash Past the Gorge (Ruined Borderlands, QC5-QC9) ]]

-- A path: kind (a COUNTERS kind, or "beasts" / "boss" from kills, "place" /
-- "region" from where the player stands), its goal and line.
type Path = {
	kind: string,
	goal: number,
	text: string,
	combat: boolean?,
	tier: number?,
	place: string?, -- PLACES key
	region: string?, -- Regions id
	boss: string?, -- enemy id
	from: string?, -- "beasts": the least beast realm that counts
}
type Step = { from: string, title: string, place: string, body: string, description: string, paths: { Path }, after: string }

local CHAIN = {
	id = "Borderlands",
	name = "Ash Past the Gorge",
	giver = "Elder Qingyun",
	steps = {
		{
			from = "QC5",
			title = "Smoke past the gorge",
			place = "Ruined Borderlands",
			body = "Scouts saw smoke past the border river. Go and look.",
			description = "Smoke has risen past the border river for three nights. The villages there are dead, yet something is still burning them. Cross the stone bridge into the Ruined Borderlands and see it with your own eyes.",
			paths = { { kind = "region", region = "MiddleWilds", goal = 1, text = "Cross into the Ruined Borderlands" } },
			after = "The road beyond is not safe. Come back to the board at Qi Condensation 6.",
		},
		{
			from = "QC6",
			title = "Ash on the road",
			place = "Ashen Hollow",
			body = "Clear the border road, or heal those it hurt.",
			description = "The road through Ashen Hollow is thick with beasts that have eaten cultivators. The wounded at the border wall need herbs as much as the road needs clearing. Either serves the sect.",
			paths = {
				{ kind = "beasts", from = "QC5", goal = 6, combat = true, text = "Slay beasts of the Borderlands" },
				{ kind = "herbs", tier = 1, goal = 6, text = "Or bring 6 tier I herbs for the wounded" },
			},
			after = "Survivors speak of lamps in the marsh. Return at Qi Condensation 7.",
		},
		{
			from = "QC7",
			title = "The drowned shrine",
			place = "Drowned Shrine",
			body = "A shrine in the marsh still keeps its lamps lit. Find it.",
			description = "Half sunk in the marsh stands a shrine whose ghost lanterns never go out. Whoever lights them may know what burned the villages. Find the Drowned Shrine.",
			paths = { { kind = "place", place = "DrownedShrine", goal = 1, text = "Find the Drowned Shrine" } },
			after = "The lamps were lit for the dead. Their graves are restless. Return at Qi Condensation 8.",
		},
		{
			from = "QC8",
			title = "What the dead left",
			place = "Cultivators' Graves",
			body = "The graves hum with old qi, and strong beasts come to feed.",
			description = "The cultivators buried at the border left their qi in the ground, and the strongest beasts come to feed on it. Drive the strongest off, or draw the qi from the veins before they take it.",
			paths = {
				{ kind = "elites", goal = 2, combat = true, text = "Slay elite beasts" },
				{ kind = "gather", goal = 4, text = "Or gather qi at 4 nodes" },
			},
			after = "The smoke always came from one place: the Broken Pagoda. Return at Qi Condensation 9.",
		},
		{
			from = "QC9",
			title = "The Broken Pagoda",
			place = "Broken Pagoda",
			body = "The fires began at the pagoda. Climb its mound.",
			description = "The fires began at the Broken Pagoda, behind the Fallen Outpost where the Elder Wolf King keeps his court. Climb its mound and see what the sect lost there. The King is a faster road, never a required one.",
			paths = {
				{ kind = "place", place = "BrokenPagoda", goal = 1, text = "Climb to the Broken Pagoda" },
				{ kind = "boss", boss = "ElderWolfKing", goal = 1, combat = true, text = "Or slay the Elder Wolf King (optional)" },
			},
			after = "The pagoda's embers are cold. The Borderlands will remember the disciple who came.",
		},
	} :: { Step },
}

-- Chain places: a named model under Workspace.Map (the Borderlands POIs), else
-- the flat point the map doc gives (docs/map/wilds.md, after the +220/+700 move).
local PLACES: { [string]: Vector3 } = {
	DrownedShrine = Vector3.new(396, 0, 1658),
	BrokenPagoda = Vector3.new(220, 0, 1872),
}
local placeAt: { [string]: Vector3 } = {}

local function placePosition(name: string): Vector3?
	local at = placeAt[name]
	if at then
		return at
	end
	local map = workspace:FindFirstChild("Map")
	local found = map and map:FindFirstChild(name, true)
	if found and found:IsA("PVInstance") then
		at = (found :: PVInstance):GetPivot().Position
	else
		at = PLACES[name]
	end
	if at then
		placeAt[name] = at
	end
	return at
end

local function currentStep(data: PlayerData.Data): Step?
	return CHAIN.steps[data.sect.chain + 1]
end

-- The step can be taken: the board is open and its stage reached (the testbed
-- ignores the stage, so the whole chain can be walked there).
local function stepOpen(data: PlayerData.Data, step: Step): boolean
	return opened(data) and (Config.TESTBED or reached(data, step.from))
end

local function stepDone(data: PlayerData.Data, step: Step): number?
	local record = data.sect.step
	if not record then
		return nil
	end
	for i, path in step.paths do
		local t = record[tostring(i)]
		if t and progressOf(data, path.kind, t) >= t.goal then
			return i
		end
	end
	return nil
end

--[[ Granting ]]

local function feed(player: Player, key: string, amount: number)
	if amount > 0 then
		effectRemote:FireClient(player, "reward", { tier = "feed", key = key, amount = amount })
	end
end

local function earn(data: PlayerData.Data, amount: number)
	data.sect.contribution += amount
	data.sect.earned += amount
	data.stats.contribution += amount
end

local function claimed(player: Player, id: string)
	for _, fn in Quests.onClaimed do
		task.spawn(fn, player, id)
	end
end

--[[ The view the client draws ]]

local function stoneShare(data: PlayerData.Data, share: number): number
	return math.floor((Tuning.DAILY_STONES[data.realm.major] or 0) * share + 0.5)
end

local function dailyState(data: PlayerData.Data, kind: string): (string, number, Task?)
	local t = data.sect.taken[kind]
	if not t then
		return "offered", 0, nil
	end
	if t.claimed then
		return "claimed", t.goal, t
	end
	local p = progressOf(data, kind, t)
	return if p >= t.goal then "done" else "taken", p, t
end

local function stepView(data: PlayerData.Data, step: Step)
	local record = data.sect.step
	local best, bestGoal, bestShare, bestText = 0, step.paths[1].goal, -1, step.paths[1].text
	local objectives = {}
	for i, path in step.paths do
		local t = record and record[tostring(i)]
		local p = if t then progressOf(data, path.kind, t) else 0
		if p / path.goal > bestShare then
			best, bestGoal, bestShare, bestText = p, path.goal, p / path.goal, path.text
		end
		table.insert(objectives, { text = path.text, progress = if path.goal > 1 then p else nil, goal = if path.goal > 1 then path.goal else nil, done = p >= path.goal })
	end
	local state = if not record then "offered" elseif stepDone(data, step) then "done" else "taken"
	return state, best, bestGoal, objectives, bestText
end

local function stockList(data: PlayerData.Data)
	local list = {}
	local mine = rankIndex(data.sect.rank)
	local purse = data.sect.contribution
	local function add(id: string, name: string, detail: string, cost: number, why: string?)
		if not why and purse < cost then
			why = "Not enough contribution"
		end
		table.insert(list, { id = id, name = name, detail = detail, cost = cost, why = why })
	end
	for _, s in Tuning.SEEDS do
		local need = rankIndex(s.rank)
		add(`seeds:{s.tier}`, `Tier {numeral(s.tier)} seed packet`, `{s.seeds} seeds of one tier {numeral(s.tier)} herb, chosen by the Pavilion.`, s.cost,
			if mine < need then `{rankName(s.rank)} and up` else nil)
	end
	local major = data.realm.major
	local ringCost = Tuning.RING_SLOT[major]
	if ringCost then
		add("ring", "Spirit ring slot", "One more stack your spirit ring keeps safe in the wilds, for this major realm.", ringCost,
			if (data.sect.ring[major] or 0) > 0 then "Bought for this realm" else nil)
	end
	for _, id in Tuning.MANUAL_ORDER do
		local def = Techniques.Defs[id]
		local cost = Tuning.MANUALS[id]
		if def and cost and not data.techniques.owned[id] and not data.techniques.manuals[id] then
			add(`manual:{id}`, `{def.name} manual`, "A copy of an art the sect teaches every disciple.", cost)
		end
	end
	-- root pill fragments, a few a week (Tuning.FRAGMENTS; the week resets with the dailies')
	local per = Pacing.Roots.FRAGMENTS.PER_PILL
	for _, pill in Pacing.Roots.FRAGMENTS.PILLS do
		local f = Tuning.FRAGMENTS[pill]
		local item = Items.Defs[pill]
		if f and item then
			local left = f.week - (data.sect.weekBought[pill] or 0)
			local have = RootDefs.fragments(data.root, pill)
			add(`fragment:{pill}`, RootDefs.FragmentNames[pill],
				`{per} fuse into a {item.name} (you hold {have}/{per}). {math.max(0, left)} left this week.`, f.cost,
				if left <= 0 then "Sold out this week" elseif not RootDefs.tested(data.root) then "Have your root tested first" else nil)
		end
	end
	return list
end

local function view(data: PlayerData.Data)
	local sect = data.sect
	local tasks, quests = {}, {}
	if promotable(data) then
		local r = nextRank(data)
		table.insert(tasks, { id = "promotion", kind = "promotion", glyph = "bow", title = `Promotion: {r.name}`,
			body = "The elders will raise you in rank. Claim it here.", state = "done" })
	end
	if opened(data) then
		local step = currentStep(data)
		if step and stepOpen(data, step) then
			local state, p, goal, objectives = stepView(data, step)
			local pay = if sect.chain + 1 == #CHAIN.steps then Tuning.CHAIN_FINAL else Tuning.CHAIN
			table.insert(tasks, { id = "chain", kind = "chapter", glyph = "quest", title = step.title, body = step.body,
				reward = pay.contribution, progress = p, goal = if goal > 1 then goal else nil, state = state })
			if state ~= "offered" then
				table.insert(quests, { id = "chain", kind = "chapter", name = step.title, giver = CHAIN.giver,
					place = step.place, description = step.description,
					status = if state == "done" then "Done: claim it at the sect board" else nil,
					objectives = objectives,
					rewards = { { kind = "contribution", amount = pay.contribution }, { kind = "stones", amount = pay.stones } } })
			end
		end
		for _, kind in sect.offered do
			local k, def = KINDS[kind], Tuning.DAILIES[kind]
			if k and def then
				local state, p, t = dailyState(data, kind)
				local goal = if t then t.goal else goalOf(data, kind)
				local tier = if t then t.tier else Tuning.HERB_TIER[data.realm.major]
				local scale = k.scale or 1
				table.insert(tasks, { id = kind, kind = "daily", glyph = k.glyph, title = k.title, body = k.body(goal, tier),
					reward = def.contribution, progress = p // scale, goal = if goal > 1 then goal // scale else nil, state = state })
				if state == "taken" or state == "done" then
					table.insert(quests, { id = `daily:{kind}`, kind = "daily", name = k.title, giver = "The sect board",
						place = "Main Peak", description = k.body(goal, tier),
						status = if state == "done" then "Done: claim it at the sect board" else nil,
						objectives = { { text = k.text(goal, tier), progress = if goal > 1 then p // scale else nil, goal = if goal > 1 then goal // scale else nil, done = state == "done" } },
						rewards = { { kind = "contribution", amount = def.contribution }, { kind = "stones", amount = stoneShare(data, def.stones) } } })
				end
			end
		end
		table.insert(tasks, { id = "pavilion", kind = "pavilion", glyph = "chest", title = "The Pavilion",
			body = "Spend contribution on seeds, arts, a ring slot and root pill fragments.", state = "taken" })
	end
	-- the rank road, in the log only (soft: the board shows the promotion once it's met)
	local r = nextRank(data)
	if r then
		table.insert(quests, { id = "rank", kind = "other", name = `Rise to {r.name}`, giver = CHAIN.giver, place = "The sect",
			description = `The sect raises a disciple who has grown in realm and served it. Contribution spent at the Pavilion still counts.`,
			objectives = {
				{ text = `Reach {stageName(r.realm or "")}`, done = reached(data, r.realm) },
				{ text = "Contribution earned", progress = math.min(sect.earned, r.earned or 0), goal = r.earned, done = sect.earned >= (r.earned or 0) },
			},
			rewards = { { kind = "stones", amount = r.stones or 0 } } })
	end
	return {
		status = { rank = sect.rank, contribution = sect.contribution, week = sect.week, weekCap = Tuning.WEEK_CAP },
		tasks = tasks,
		quests = quests,
		tracked = sect.tracked,
		stock = stockList(data),
	}
end

local lastSent: { [Player]: string } = {}

function Sect.push(player: Player, open: boolean?)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	refresh(data)
	local v = view(data)
	local key = HttpService:JSONEncode(v)
	if open or lastSent[player] ~= key then
		lastSent[player] = key
		questRemote:FireClient(player, { sect = v, open = open == true })
	end
end

--[[ Actions ]]

local function take(player: Player, data: PlayerData.Data, id: any): (boolean, string?)
	if not opened(data) then
		return false, `The sect's tasks open at {stageName(Tuning.OPENS)}.`
	end
	if id == "chain" then
		local step = currentStep(data)
		if not (step and stepOpen(data, step)) or data.sect.step then
			return false, nil
		end
		local record = {}
		for i, path in step.paths do
			local t = newTask(data, path.kind, path.goal, path.tier)
			-- the testbed has no map: a place to reach is reached at once
			if Config.TESTBED and (path.kind == "place" or path.kind == "region") then
				t.progress = t.goal
			end
			record[tostring(i)] = t
		end
		data.sect.step = record
		Analytics.event(player, "SectTask", 1, "taken", "chain")
		Cultivation.notify(player, `Quest taken: {step.title}.`)
		return true, nil
	end
	if type(id) ~= "string" or not table.find(data.sect.offered, id) or data.sect.taken[id] then
		return false, nil
	end
	local tier = if id == "herbs" then Tuning.HERB_TIER[data.realm.major] or 1 else nil
	data.sect.taken[id] = newTask(data, id, goalOf(data, id), tier)
	Analytics.event(player, "SectTask", 1, "taken", id)
	Cultivation.notify(player, `Task taken: {KINDS[id].title}.`)
	return true, nil
end

local function claimDaily(player: Player, data: PlayerData.Data, kind: string): (boolean, string?)
	local state, _, t = dailyState(data, kind)
	if state ~= "done" or not t then
		return false, nil
	end
	if kind == "herbs" and not takeHerbs(data, t.tier or 1, t.goal) then
		return false, "You no longer hold enough of those herbs."
	end
	t.claimed = true
	local def = Tuning.DAILIES[kind]
	local room = math.max(0, Tuning.WEEK_CAP - data.sect.week)
	local gained = math.min(def.contribution, room)
	data.sect.week += gained
	earn(data, gained)
	local stones = stoneShare(data, def.stones)
	data.stones += stones
	data.stats.dailies += 1
	Analytics.event(player, "SectTask", 1, "claimed", kind)
	Analytics.stones(player, "source", stones, data.stones, "Gameplay", "SectDaily")
	Analytics.economy(player, "source", "Contribution", gained, data.sect.contribution, "Gameplay", "SectDaily")
	if data.sect.tracked == `daily:{kind}` then
		data.sect.tracked = ""
	end
	feed(player, "contribution", gained)
	feed(player, "stones", stones)
	local capped = if gained < def.contribution then " (this week's contribution is full)" else ""
	Cultivation.notify(player, `Task done: {KINDS[kind].title}. +{gained} contribution, +{stones} Spirit Stones{capped}`)
	claimed(player, `Daily:{kind}`)
	return true, nil
end

local function claimStep(player: Player, data: PlayerData.Data): (boolean, string?)
	local step = currentStep(data)
	local done = step and stepDone(data, step)
	if not (step and done) then
		return false, nil
	end
	-- prefer a path that hands nothing over (herbs are only taken when they're the way it was done)
	local record = data.sect.step :: { [string]: Task }
	local path = step.paths[done]
	for i, p in step.paths do
		local t = record[tostring(i)]
		if p.kind ~= "herbs" and t and progressOf(data, p.kind, t) >= t.goal then
			path = p
			break
		end
	end
	if path.kind == "herbs" and not takeHerbs(data, path.tier or 1, path.goal) then
		return false, "You no longer hold enough of those herbs."
	end
	local index = data.sect.chain + 1
	local last = index == #CHAIN.steps
	local pay = if last then Tuning.CHAIN_FINAL else Tuning.CHAIN
	data.sect.chain = index
	data.sect.step = nil
	if data.sect.tracked == "chain" then
		data.sect.tracked = ""
	end
	earn(data, pay.contribution)
	data.stones += pay.stones
	Analytics.event(player, "SectTask", 1, "claimed", "chain")
	Analytics.stones(player, "source", pay.stones, data.stones, "Gameplay", "SectChain")
	Analytics.economy(player, "source", "Contribution", pay.contribution, data.sect.contribution, "Gameplay", "SectChain")
	effectRemote:FireClient(player, "reward", {
		tier = "card",
		kind = "quest",
		title = "Quest Complete",
		subtitle = step.title,
		items = { { key = "contribution", amount = pay.contribution }, { key = "stones", amount = pay.stones } },
		unlock = if last then `{CHAIN.name} is complete` else nil,
		flavour = step.after,
	})
	if last then
		Foundation.world(player, `sect:chain:{CHAIN.id}`) -- a foundation experience (docs/systems/foundation.md)
	end
	claimed(player, `Chain:{CHAIN.id}:{index}`)
	return true, nil
end

local function promote(player: Player, data: PlayerData.Data): (boolean, string?)
	if not promotable(data) then
		return false, nil
	end
	local r = nextRank(data)
	data.sect.rank = r.id
	data.stones += r.stones or 0
	Analytics.stones(player, "source", r.stones or 0, data.stones, "Gameplay", "SectRank")
	player:SetAttribute("SectRank", r.id)
	Foundation.world(player, `sect:rank:{r.id}`) -- a first rank-up is a foundation experience
	questRemote:FireClient(player, { sectRankUp = {
		rank = r.id,
		line = if r.id == "Core" then "The inner peaks are open to you." else "The sect knows your name now.",
		items = { { key = "stones", amount = r.stones or 0 } },
	} })
	claimed(player, `Rank:{r.id}`)
	return true, nil
end

local function buy(player: Player, data: PlayerData.Data, id: any): (boolean, string?)
	if type(id) ~= "string" then
		return false, nil
	end
	for _, s in stockList(data) do
		if s.id == id then
			if s.why then
				return false, s.why
			end
			if string.sub(id, 1, 6) == "seeds:" then
				local tier = tonumber(string.sub(id, 7)) or 1
				local packet
				for _, p in Tuning.SEEDS do
					if p.tier == tier then
						packet = p
					end
				end
				local pool = {}
				for _, herbId in Herbs.Order do
					local herb = Herbs.Defs[herbId]
					if herb and herb.tier == tier and herb.seedCost then
						table.insert(pool, herbId)
					end
				end
				if #pool == 0 then -- nothing of this tier is sold: any herb of it
					for _, herbId in Herbs.Order do
						if Herbs.Defs[herbId] and Herbs.Defs[herbId].tier == tier then
							table.insert(pool, herbId)
						end
					end
				end
				if not packet or #pool == 0 then
					return false, "The Pavilion has none of those today."
				end
				local herbId = pool[math.random(1, #pool)]
				data.seeds[herbId] = (data.seeds[herbId] or 0) + packet.seeds
				Cultivation.notify(player, `The Pavilion gives you {packet.seeds} {Herbs.Defs[herbId].name} seeds.`)
			elseif id == "ring" then
				data.sect.ring[data.realm.major] = 1
				Cultivation.notify(player, "Your spirit ring keeps one more stack safe.")
			elseif string.sub(id, 1, 7) == "manual:" then
				Progression.grantManual(player, string.sub(id, 8))
			elseif string.sub(id, 1, 9) == "fragment:" then
				local pill = string.sub(id, 10)
				data.sect.weekBought[pill] = (data.sect.weekBought[pill] or 0) + 1
				Inventory.fragment(player, pill, 1)
			else
				return false, nil
			end
			data.sect.contribution -= s.cost
			data.sect.bought[id] = (data.sect.bought[id] or 0) + 1
			Analytics.economy(player, "sink", "Contribution", s.cost, data.sect.contribution, "Shop", "Pavilion")
			Cultivation.pushState(player)
			return true, nil
		end
	end
	return false, nil
end

local function track(data: PlayerData.Data, id: any): (boolean, string?)
	if id == "" or id == nil then
		data.sect.tracked = ""
		return true, nil
	end
	if id == "chain" and data.sect.step then
		data.sect.tracked = id
		return true, nil
	end
	if type(id) == "string" and string.sub(id, 1, 6) == "daily:" then
		local t = data.sect.taken[string.sub(id, 7)]
		if t and not t.claimed then
			data.sect.tracked = id
			return true, nil
		end
	end
	return false, nil
end

-- CultivationAction ("sect", op, arg), routed here by Main.
function Sect.handle(player: Player, op: any, arg: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	refresh(data)
	local ok, message
	if op == "take" then
		ok, message = take(player, data, arg)
	elseif op == "claim" then
		if arg == "chain" then
			ok, message = claimStep(player, data)
		elseif type(arg) == "string" then
			ok, message = claimDaily(player, data, arg)
		end
	elseif op == "promote" then
		ok, message = promote(player, data)
	elseif op == "buy" then
		ok, message = buy(player, data, arg)
	elseif op == "track" then
		ok, message = track(data, arg)
	end
	if message then
		Cultivation.notify(player, message)
	end
	Sect.push(player)
	Quests.check(player)
	return ok == true, message
end

--[[ Hooks ]]

-- EnemyService.onKill: hunts (beasts near the player's realm; realm variants carry
-- their spawn's realm) and the chain's kill paths.
function Sect.onKill(player: Player, def: Enemies.Def, _model: Model?)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local beast = Realms.index(def.realm[1], def.realm[2])
	local hunt = data.sect.taken.hunt
	if hunt and not hunt.claimed and beast >= stageIndex(data) - Tuning.HUNT_BELOW then
		hunt.progress = math.min(hunt.goal, hunt.progress + 1)
	end
	local step, record = currentStep(data), data.sect.step
	if step and record then
		for i, path in step.paths do
			local t = record[tostring(i)]
			if t and path.kind == "beasts" and beast >= Realms.index(Realms.ByKey[path.from or "QC1"].major, Realms.ByKey[path.from or "QC1"].minor) then
				t.progress = math.min(t.goal, t.progress + 1)
			elseif t and path.kind == "boss" and def.id == path.boss then
				t.progress = t.goal
			end
		end
	end
end

-- Place and region paths: where the player stands now.
local function checkPlaces(player: Player, data: PlayerData.Data)
	local step, record = currentStep(data), data.sect.step
	if not (step and record) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pos = root.Position
	for i, path in step.paths do
		local t = record[tostring(i)]
		if t and t.progress < t.goal then
			if path.kind == "region" then
				local region = Regions.at(pos)
				if region and region.id == path.region then
					t.progress = t.goal
				end
			elseif path.kind == "place" and path.place then
				local at = placePosition(path.place)
				if at and Vector2.new(pos.X - at.X, pos.Z - at.Z).Magnitude <= Tuning.PLACE_RADIUS then
					t.progress = t.goal
				end
			end
		end
	end
end

-- The HUD objective line for a tracked sect quest (Quests.trackedObjective).
local function trackedObjective(_player: Player, data: PlayerData.Data): string?
	local id = data.sect.tracked
	if id == "chain" then
		local step = currentStep(data)
		if step and data.sect.step then
			if stepDone(data, step) then
				return `{step.title}: claim it at the sect board`
			end
			local _, p, goal, _, text = stepView(data, step)
			text = (string.gsub(text, "^Or ", ""))
			return if goal > 1 then `{text} ({p}/{goal})` else text
		end
	elseif string.sub(id, 1, 6) == "daily:" then
		local kind = string.sub(id, 7)
		local k = KINDS[kind]
		local state, p, t = dailyState(data, kind)
		if k and t and state ~= "claimed" then
			if state == "done" then
				return `{k.title}: claim it at the sect board`
			end
			local scale = k.scale or 1
			return if t.goal > 1 then `{k.text(t.goal, t.tier)} ({p // scale}/{t.goal // scale})` else k.text(t.goal, t.tier)
		end
	end
	return nil
end

function Sect.start()
	Quests.trackedObjective = trackedObjective
	Quests.openBoard = function(player: Player): boolean
		local data = PlayerData.get(player)
		if not (data and opened(data)) then
			return false
		end
		Sect.push(player, true)
		return true
	end
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("SectRank", "Outer")
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					local data = PlayerData.get(player)
					if data then
						if player:GetAttribute("SectRank") ~= data.sect.rank then
							player:SetAttribute("SectRank", data.sect.rank)
						end
						checkPlaces(player, data)
						Sect.push(player)
					end
				end)
				if not ok then
					warn(`Sect: {err}`)
				end
			end
		end
	end)
end

function Sect.forget(player: Player)
	lastSent[player] = nil
end

return Sect
