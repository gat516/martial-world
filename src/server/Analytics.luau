--!strict
-- Wraps Roblox AnalyticsService: the onboarding funnel, realm progression, the
-- economy and the custom events the playtest is judged on (docs/systems/data.md,
-- "What we track"). Every call is pcall'd; analytics must never break gameplay.
--
-- Limits (Roblox): 120 + 20 x CCU requests a minute per server, at most 100
-- custom event names with 3 fields each, 10 funnels. Economy events are summed
-- per player and kind and sent every ECONOMY_FLUSH seconds (and on leaving), so
-- a kill streak costs one request, not one per kill.
--
-- Onboarding funnel (FUNNEL_NAMES below; renumbered 2026-10-24 when the front
-- door became one screen, and 2026-10-23 before that, so compare funnels across
-- those dates with care):
--   1 Joined, 2 Creator opened (the first-character page), 3 Enter World,
--   4 First sit, 5.. one step per onboarding beat (Quests.Beats position +
--   BEAT_OFFSET): 5 First circulation ... 14 QC4.
-- Steps 1-4 are logged only for a new player (no slot with any progress) and
-- once a session; a new account skips the slot screen, so it has no step.
-- Slots off (the live game): 2-3 never fire, so the funnel goes 1 -> 4.
-- TimeToEnterWorld (custom event): seconds from join to Enter World for a new
-- player, field 1 how the name was chosen (Kept, Rolled, Typed).
--
-- Realm progression (path "Realm", level = Realms stage index, name = stage
-- name): Start when a player enters a stage (stage 1 on their first join),
-- Complete when they break out of it, Fail when a tribulation guarding it beats
-- them. In the Creator Dashboard's Progression view, the drop between a level's
-- starts and completes is the stage's dropoff; tune it in Pacing.Adjust.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Analytics = {}

local ECONOMY_FLUSH = 120 -- seconds between economy sends per player

local FUNNEL_NAMES = {
	"Joined",
	"Creator opened",
	"Enter World",
	"First sit",
	-- the beats, in Quests.Beats order (inserting a beat shifts the steps after it)
	"First circulation",
	"First breakthrough",
	"First kill",
	"First technique earned",
	"First technique cast",
	"Haul stored",
	"Refined qi",
	"QC3",
	"Root tested",
	"QC4",
}
Analytics.BEAT_OFFSET = 4 -- funnel step of beat i = i + BEAT_OFFSET

-- the front-door steps, by name (Analytics.front)
local FRONT: { [string]: number } = {
	Joined = 1,
	CreatorOpened = 2,
	EnterWorld = 3,
	FirstSit = 4,
}

local newPlayers: { [Player]: { [number]: boolean } } = {} -- new this session: front steps logged
local joinedAt: { [Player]: number } = {} -- os.clock() of a new player's join

local function funnel(player: Player, step: number)
	local name = FUNNEL_NAMES[step]
	if not name then
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
	if not ok then
		warn(`Analytics: funnel {step} failed: {err}`)
	end
end

-- The beat at Quests.Beats position `index` was completed.
function Analytics.beat(player: Player, index: number)
	funnel(player, index + Analytics.BEAT_OFFSET)
end

-- A new player (no slot with progress): the front-door steps count for them.
function Analytics.markNew(player: Player)
	newPlayers[player] = newPlayers[player] or {}
	joinedAt[player] = joinedAt[player] or os.clock()
end

function Analytics.isNew(player: Player): boolean
	return newPlayers[player] ~= nil
end

-- A front-door step (FRONT names): once a session, new players only.
function Analytics.front(player: Player, name: string)
	local logged = newPlayers[player]
	local step = FRONT[name]
	if not (logged and step) or logged[step] then
		return
	end
	logged[step] = true
	funnel(player, step)
end

-- A new player entered the world: the Enter World step and how long the front
-- door took (TimeToEnterWorld, field: how the name was chosen).
function Analytics.enteredWorld(player: Player, nameSource: string)
	local first = newPlayers[player] ~= nil and not newPlayers[player][FRONT.EnterWorld]
	Analytics.front(player, "EnterWorld")
	local at = joinedAt[player]
	if first and at then
		Analytics.event(player, "TimeToEnterWorld", math.floor(os.clock() - at + 0.5), nameSource)
	end
end

-- status: "start" | "complete" | "fail"
function Analytics.progression(player: Player, status: string, level: number, levelName: string)
	local ok, err = pcall(function()
		if status == "start" then
			AnalyticsService:LogProgressionStartEvent(player, "Realm", level, levelName)
		elseif status == "complete" then
			AnalyticsService:LogProgressionCompleteEvent(player, "Realm", level, levelName)
		elseif status == "fail" then
			AnalyticsService:LogProgressionFailEvent(player, "Realm", level, levelName)
		end
	end)
	if not ok then
		warn(`Analytics: progression {status} {level} failed: {err}`)
	end
end

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

-- A custom event: a value and up to three string fields.
function Analytics.event(player: Player, name: string, value: number, field: string?, field2: string?, field3: string?)
	local ok, err = pcall(function()
		if field then
			local fields = { [FIELD_KEYS[1]] = field }
			if field2 then
				fields[FIELD_KEYS[2]] = field2
			end
			if field3 then
				fields[FIELD_KEYS[3]] = field3
			end
			AnalyticsService:LogCustomEvent(player, name, value, fields)
		else
			AnalyticsService:LogCustomEvent(player, name, value)
		end
	end)
	if not ok then
		warn(`Analytics: {name} failed: {err}`)
	end
end

-- Seconds since the slot's first join (data.firstJoinUnix; 0 = joined before
-- it was recorded, so nothing is sent). TimeToFirstKill, TimeToQC2, TimeToQC4.
function Analytics.timeTo(player: Player, name: string, firstJoinUnix: number)
	if firstJoinUnix and firstJoinUnix > 0 then
		Analytics.event(player, name, os.time() - firstJoinUnix)
	end
end

--[[ Economy ]]

-- currency: "SpiritStones" | "RawQi" | "Contribution".
-- transaction: an Enum.AnalyticsEconomyTransactionType name ("Gameplay", "Shop",
-- "TimedReward", "Onboarding", ...). sku: what it was for ("Kill", "Pavilion", ...).
type Pending = { flow: string, currency: string, transaction: string, sku: string, amount: number, balance: number }
local economy: { [Player]: { [string]: Pending } } = {}

local function flush(player: Player)
	local bucket = economy[player]
	if not bucket then
		return
	end
	economy[player] = nil
	for _, p in bucket do
		local ok, err = pcall(function()
			local flow = if p.flow == "source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
			AnalyticsService:LogEconomyEvent(player, flow, p.currency, p.amount, p.balance, p.transaction, p.sku)
		end)
		if not ok then
			warn(`Analytics: economy {p.currency} {p.sku} failed: {err}`)
		end
	end
end

-- flow "source" | "sink"; amount > 0; balance = the currency after this change.
function Analytics.economy(player: Player, flow: string, currency: string, amount: number, balance: number, transaction: string, sku: string)
	amount = math.floor(amount + 0.5)
	if amount <= 0 or player.Parent == nil then
		return
	end
	local bucket = economy[player]
	if not bucket then
		bucket = {}
		economy[player] = bucket
	end
	local key = `{flow}|{currency}|{transaction}|{sku}`
	local p = bucket[key]
	if p then
		p.amount += amount
		p.balance = math.floor(balance)
	else
		bucket[key] = { flow = flow, currency = currency, transaction = transaction, sku = sku, amount = amount, balance = math.floor(balance) }
	end
end

-- shorthands for the two tracked currencies
function Analytics.stones(player: Player, flow: string, amount: number, balance: number, transaction: string, sku: string)
	Analytics.economy(player, flow, "SpiritStones", amount, balance, transaction, sku)
end

function Analytics.qi(player: Player, flow: string, amount: number, balance: number, transaction: string, sku: string)
	Analytics.economy(player, flow, "RawQi", amount, balance, transaction, sku)
end

task.spawn(function()
	while true do
		task.wait(ECONOMY_FLUSH)
		for player in economy do
			flush(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	flush(player)
	newPlayers[player] = nil
	joinedAt[player] = nil
end)

return Analytics
