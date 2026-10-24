--!strict
-- Seclusion (docs/systems/seclusion.md), the AFK mode. From the meditation seat on
-- their own peak a player enters seclusion (CultivationAction "seclusion"). While
-- secluded they stay seated, cultivation runs at the AFK rate (Cultivation.afkRate,
-- the same as offline) and nothing breaks through, circulates or drills. Seclusion
-- pays its own rewards instead (Pacing.Seclusion), never stages and never
-- foundation experiences:
--   a slow Spirit Stone trickle (STONES_PER_HOUR by major, plus the streak bonus)
--   the garden tended: growing plants grow GROWTH faster (Garden's tick online,
--     Garden.advance for the offline part)
--   online only: the garden's own mutation roll (Garden's tick, MUTATION_PER_HOUR)
--   each full hour, a RARE_CHANCE of a treasure or a seed of the next herb tier
--   the streak: consecutive days with a seclusion of STREAK_MIN_HOURS or more
-- Everything counts for at most MAX_HOURS of one seclusion. Logging out keeps it
-- going (data.seclusion.since stays set); the next login settles the time away
-- and ends it. Rising (Rise, a hit, drifting off the seat) ends it too. Ending it
-- shows the result card (Effect "reward", a Rewards card spec).
-- The very first seclusion (the onboarding's Seclusion lesson, Quests.luau) ends
-- by itself after FIRST_SECONDS with a generous card (FIRST_*).
-- The heart-demon trial reads data.stats.secluded (HeartDemon.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)
local Meditation = require(script.Parent.Meditation)
local Garden = require(script.Parent.Garden)
local Inventory = require(script.Parent.Inventory)
local Analytics = require(script.Parent.Analytics)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local S = Pacing.Seclusion
local MAX_SECONDS = S.MAX_HOURS * 3600
local CARD_DELAY = 8 -- seconds after a login before the card shows (the HUD is up by then)

local Seclusion = {}

local live: { [Player]: boolean } = {} -- secluded and online right now
local rng = Random.new()

function Seclusion.active(player: Player): boolean
	return live[player] == true
end

local function pick(pool: { [string]: number }): string?
	local total = 0
	for _, w in pool do
		total += w
	end
	local roll = rng:NextNumber() * total
	for id, w in pool do
		roll -= w
		if roll <= 0 then
			return id
		end
	end
	return nil
end

-- A seed of the player's major's next herb tier (no wild-only or event herbs).
local function rareSeed(data: PlayerData.Data): string?
	local tier = S.SEED_TIER[data.realm.major] or 2
	local pool = {}
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		if herb.tier == tier and not herb.wild and not Pacing.Herbs.PRIZE[id] then
			table.insert(pool, id)
		end
	end
	return if #pool > 0 then pool[rng:NextInteger(1, #pool)] else nil
end

local function addSeeds(data: PlayerData.Data, id: string, n: number)
	data.seeds[id] = (data.seeds[id] or 0) + n
	local tally = data.seclusion.tally
	tally.seeds[id] = (tally.seeds[id] or 0) + n
end

-- One hourly roll: maybe a rare find.
local function roll(player: Player, data: PlayerData.Data, online: boolean)
	if rng:NextNumber() >= S.RARE_CHANCE then
		return
	end
	local what = pick(S.RARE)
	local tally = data.seclusion.tally
	if what == "Seed" then
		local id = rareSeed(data)
		if id then
			addSeeds(data, id, 1)
			if online then
				Cultivation.notify(player, `In the stillness, a {Herbs.Defs[id].name} seed drifts to your feet.`)
			end
		end
	elseif what and Items.Defs[what] then
		tally.items[what] = (tally.items[what] or 0) + 1
		if online then
			Inventory.grant(player, what, 1)
			Cultivation.notify(player, `In the stillness, you find a {Items.Defs[what].name}.`)
		else
			local bag = Items.bag(data, what)
			bag[what] = (bag[what] or 0) + 1
		end
	end
end

-- `seconds` more of seclusion that count (the caller caps them at MAX_SECONDS).
local function accrue(player: Player, data: PlayerData.Data, seconds: number, online: boolean)
	local sec = data.seclusion
	local tally = sec.tally
	sec.counted += seconds
	data.stats.secluded += seconds
	tally.frac += seconds * (S.STONES_PER_HOUR[data.realm.major] or 0) / 3600
	local whole = math.floor(tally.frac)
	if whole > 0 then
		tally.frac -= whole
		tally.stones += whole
		data.stones += whole
	end
	while sec.rolled < math.floor(sec.counted / 3600) do
		sec.rolled += 1
		roll(player, data, online)
	end
end

local function duration(seconds: number): string
	if seconds < 90 then
		return "a minute"
	elseif seconds < 3600 then
		return `{math.floor(seconds / 60 + 0.5)} minutes`
	elseif seconds < 5400 then
		return "an hour"
	end
	return `{math.floor(seconds / 3600 + 0.5)} hours`
end

-- The onboarding's first seclusion: its generous extras, into the tally.
local function firstGifts(player: Player, data: PlayerData.Data)
	local tally = data.seclusion.tally
	data.seclusion.first = true
	data.stones += S.FIRST_STONES
	tally.stones += S.FIRST_STONES
	for id, n in S.FIRST_SEEDS do
		addSeeds(data, id, n)
	end
	local bar = Cultivation.stage(data).bar
	local room = math.max(0, bar - data.cultivation) -- never past the bar
	Cultivation.add(data, math.min(math.floor(bar * S.FIRST_BAR), room))
	tally.growth += Garden.advance(player, data, S.FIRST_GROWTH)
end

-- Close the books on this seclusion: streak, first-time gifts, the card.
local function finish(player: Player, data: PlayerData.Data, delay: number)
	local sec = data.seclusion
	local tally = sec.tally
	local streakBefore = sec.streak
	if sec.counted >= S.STREAK_MIN_HOURS * 3600 then
		local today = os.time() // 86400
		if sec.streakDay ~= today then
			sec.streak = if sec.streakDay == today - 1 then sec.streak + 1 else 1
			sec.streakDay = today
		end
	end
	local streakDays = math.min(math.max(sec.streak - 1, 0), S.STREAK_MAX)
	local bonus = if sec.counted >= S.STREAK_MIN_HOURS * 3600 then math.floor(tally.stones * S.STREAK_BONUS * streakDays) else 0
	if bonus > 0 then
		data.stones += bonus
		tally.stones += bonus
	end
	local first = not sec.first
	if first then
		firstGifts(player, data)
	end
	tally.cultivation = math.max(0, math.floor(data.cultivation - sec.start))

	local items = {}
	if tally.stones > 0 then
		table.insert(items, { key = "stones", amount = tally.stones })
	end
	for id, n in tally.items do
		table.insert(items, { key = id, amount = n })
	end
	for id, n in tally.seeds do
		table.insert(items, { key = `seed:{id}`, amount = n })
	end
	local stats = {}
	if tally.cultivation > 0 then
		table.insert(stats, { name = "Cultivation", from = sec.start // 1, to = data.cultivation // 1 })
	end
	if sec.streak > 1 or streakBefore > 1 then
		table.insert(stats, { name = "Seclusion streak", from = `{streakBefore} days`, to = `{sec.streak} days` })
	end
	local garden = ""
	if tally.mutations > 0 then
		garden = ` Your garden was tended, and {tally.mutations} {if tally.mutations == 1 then "plant" else "plants"} took a mutation.`
	elseif tally.growth > 0 then
		garden = " Your garden was tended."
	end
	local spent = os.time() - sec.since
	local spec = {
		tier = "card",
		kind = "milestone",
		title = if first then "First Seclusion" else "Seclusion Ends",
		subtitle = `{duration(spent)} in seclusion`,
		items = items,
		stats = stats,
		unlock = if bonus > 0 then `Streak bonus: +{bonus} Spirit Stones` else nil,
		flavour = `You spent {duration(spent)} in seclusion.{garden}`,
	}
	Analytics.event(player, "SeclusionEnded", math.floor(sec.counted / 60))
	sec.since = 0
	sec.counted = 0
	sec.online = 0
	sec.rolled = 0
	sec.start = 0
	sec.tally = PlayerData.newTally()
	task.delay(delay, function()
		if player.Parent then
			effectRemote:FireClient(player, "reward", spec)
		end
	end)
end

-- Leave seclusion (rising, or the first one's timer): the player stays seated.
function Seclusion.leave(player: Player)
	local data = PlayerData.get(player)
	if not live[player] then
		return
	end
	live[player] = nil
	player:SetAttribute("Secluded", nil)
	if data and data.seclusion.since > 0 then
		finish(player, data, 0)
	end
	Cultivation.markActive(player)
	Cultivation.pushState(player)
end

-- Enter seclusion: seated, on your own peak.
function Seclusion.enter(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	if live[player] then
		return false, "You are already in seclusion."
	end
	local spot = Meditation.spot(player)
	if not (spot and spot.own) then
		return false, "Seclusion begins seated on your own peak."
	end
	if Cultivation.deviated(player) then
		return false, "Your qi is in turmoil. Let it settle first."
	end
	data.seclusion.since = os.time()
	data.seclusion.counted = 0
	data.seclusion.online = 0
	data.seclusion.rolled = 0
	data.seclusion.start = data.cultivation
	data.seclusion.tally = PlayerData.newTally()
	live[player] = true
	player:SetAttribute("Secluded", true)
	Cultivation.pushState(player)
	if data.seclusion.first then
		Cultivation.notify(player, "You close your eyes and shut out the world. Rise when you wish to return.")
	else
		Cultivation.notify(player, "You close your eyes and shut out the world. Stay a while.")
	end
	return true, nil
end

-- On login (after Cultivation.claimLogin, before Garden.apply): a seclusion left
-- running at logout settles the time away (no mutations offline) and ends.
function Seclusion.resume(player: Player, data: PlayerData.Data)
	local sec = data.seclusion
	if sec.since <= 0 then
		return
	end
	local away = math.max(0, os.time() - math.max(data.lastLogoutUnix, sec.since))
	local step = math.min(away, math.max(0, MAX_SECONDS - sec.counted))
	if step > 0 then
		accrue(player, data, step, false)
		if Garden.advance(player, data, step * S.GROWTH) > 0 then
			sec.tally.growth += 1
		end
	end
	finish(player, data, CARD_DELAY)
end

function Seclusion.forget(player: Player)
	live[player] = nil -- data.seclusion.since stays set: it carries on offline
end

Cultivation.secluded = Seclusion.active
Cultivation.enterSeclusion = Seclusion.enter
Garden.secluded = Seclusion.active
Garden.onTended = function(player: Player, tended: number, mutations: number)
	local data = PlayerData.get(player)
	if data then
		data.seclusion.tally.growth += tended
		data.seclusion.tally.mutations += mutations
	end
end

task.spawn(function()
	while true do
		local dt = task.wait(1)
		for player in live do
			local data = PlayerData.get(player)
			local spot = Meditation.spot(player)
			if not data or player.Parent == nil then
				live[player] = nil
			elseif not (spot and spot.own) then
				Seclusion.leave(player) -- rose, was hit, or drifted off the seat
			else
				local sec = data.seclusion
				sec.online += dt
				local step = math.min(dt, math.max(0, MAX_SECONDS - sec.counted))
				if step > 0 then
					accrue(player, data, step, true)
				end
				if not sec.first and sec.online >= S.FIRST_SECONDS then
					Seclusion.leave(player)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(Seclusion.forget)

return Seclusion
