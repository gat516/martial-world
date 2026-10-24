--!strict
-- Seclusion (docs/systems/seclusion.md): work on yourself with what you've gathered,
-- short and purposeful (owner, 2026-10-24). From the meditation seat on their own peak
-- a player enters seclusion (CultivationAction "seclusion"). While secluded they stay
-- seated, cultivation runs at the AFK rate (Cultivation.afkRate, the same as offline)
-- and nothing breaks through, circulates or drills. Seclusion's own, never stages and
-- never foundation experiences:
--   tempering: a herb or pill in Pacing.Tempering.POINTS used while secluded is
--     absorbed (Seclusion.absorb, through Inventory.use) and SETTLE_SECONDS later
--     mends the lowest old stage's foundation (Foundation.temper, up to 100%), one at
--     a time, PER_DAY / PER_WEEK; rising before it settles gives the item back
--   the garden tended: growing plants grow GROWTH faster (Garden's tick online,
--     Garden.advance for the offline part)
--   (the garden's own mutation roll, MUTATION_PER_HOUR, runs while the owner is online
--     on their own peak, secluded or not: Garden's tick)
--   fortuitous encounters: every FIND_SECONDS a small roll (FIND_CHANCE an hour on
--     average), so a short seclusion can find something too; nothing waits on a full
--     hour. A find (FINDS) is a herb or seed of the player's band (FIND_RARITY, leaning
--     rare), rarely a seed from the next band, a treasure or a tempering pill, told as
--     an encounter (ENCOUNTERS). Never stones, never root pills
-- Everything counts for at most MAX_HOURS of one seclusion. Logging out keeps it
-- going (data.seclusion.since stays set); the next login settles the time away
-- and ends it. Rising (Rise, a hit, drifting off the seat) ends it too. Ending it
-- shows the result card (Effect "reward", a Rewards card spec) once it lasted
-- CARD_MIN_MINUTES, or found or tempered something; a quiet short sit shows nothing.
-- The very first seclusion (the onboarding's Seclusion lesson, Quests.luau) ends
-- by itself after FIRST_SECONDS with a card about the garden and tempering (FIRST_*).
-- The heart-demon trial reads data.stats.secluded and data.stats.tempered (HeartDemon.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Realms = require(ReplicatedStorage.Shared.Realms)
local PlayerData = require(script.Parent.PlayerData)
local Cultivation = require(script.Parent.Cultivation)
local Meditation = require(script.Parent.Meditation)
local Garden = require(script.Parent.Garden)
local Inventory = require(script.Parent.Inventory)
local Foundation = require(script.Parent.Foundation)
local Analytics = require(script.Parent.Analytics)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local S = Pacing.Seclusion
local T = Pacing.Tempering
local MAX_SECONDS = S.MAX_HOURS * 3600
local FIND_ROLL = S.FIND_CHANCE * S.FIND_SECONDS / 3600 -- a find's chance per roll
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

-- The herbs a find picks from, by FIND_RARITY weight: the band's Herbs.Regions pools
-- and the herbs whose `region` it is, of the band's own tier (no wild, event or
-- deferred herbs). `beyond`: the next band's (past the last band, the band's own).
local function bandPool(data: PlayerData.Data, beyond: boolean): { [string]: number }
	local band = Herbs.band(data.realm.major, data.realm.minor)
	if beyond then
		for i, r in Herbs.Regions do
			if r == band then
				band = Herbs.Regions[i + 1] or band
				break
			end
		end
	end
	local pool = {}
	local function consider(id: string)
		local herb = Herbs.Defs[id]
		local w = herb and S.FIND_RARITY[herb.rarity] or 0
		if herb and w > 0 and not herb.deferred and herb.tier == band.tier and not herb.wild and not Pacing.Herbs.PRIZE[id] and Items.Defs[id] then
			pool[id] = w
		end
	end
	for id in band.seeds do
		consider(id)
	end
	for id in band.bossSeeds or {} do
		consider(id)
	end
	for _, id in Herbs.Order do
		if Herbs.Defs[id].region == band.id then
			consider(id)
		end
	end
	return pool
end

-- How a find is told (the fiction: a fortuitous encounter, never "you found loot").
-- {x} is the herb or item's name, with its article for herbs.
local ENCOUNTERS = {
	Herb = {
		"A wandering spirit bee led you to {x}.",
		"A white crane landed beside you and left {x}.",
		"The mist parted over a hidden ledge, and there grew {x}.",
		"A shy spirit fox nosed {x} into your lap.",
	},
	Seed = {
		"A wandering spirit bee led you to {x} seed.",
		"The wind carried {x} seed into your sleeve.",
		"A spirit squirrel buried {x} seed at your feet, then forgot it.",
	},
	FarSeed = {
		"A streak of starlight fell beside you and left {x} seed, from wilds far beyond these.",
		"An old wanderer crossed your peak, pressed {x} seed into your hand, and was gone.",
	},
	Item = {
		"A loose stone beneath your seat hid a hermit's cache. Inside: {x}.",
		"Heaven and earth answered your stillness with a gift: {x}.",
	},
}

local function tell(kind: string, name: string): string
	local lines = ENCOUNTERS[kind]
	return (string.gsub(lines[rng:NextInteger(1, #lines)], "{x}", name))
end

local function withArticle(name: string): string
	return (if string.find(name, "^[AEIOUaeiou]") then "an " else "a ") .. name
end

local function addSeeds(data: PlayerData.Data, id: string, n: number)
	data.seeds[id] = (data.seeds[id] or 0) + n
	local tally = data.seclusion.tally
	tally.seeds[id] = (tally.seeds[id] or 0) + n
end

-- An item into the bag: granted (with its feed row) online, straight into the save offline.
local function give(player: Player, data: PlayerData.Data, id: string, n: number, online: boolean)
	if online then
		Inventory.grant(player, id, n)
	else
		local bag = Items.bag(data, id)
		bag[id] = (bag[id] or 0) + n
	end
end

local function addItem(player: Player, data: PlayerData.Data, id: string, n: number, online: boolean)
	local tally = data.seclusion.tally
	tally.items[id] = (tally.items[id] or 0) + n
	give(player, data, id, n, online)
end

-- One find roll (every FIND_SECONDS): maybe a fortuitous encounter.
local function roll(player: Player, data: PlayerData.Data, online: boolean)
	if rng:NextNumber() >= FIND_ROLL then
		return
	end
	local what = pick(S.FINDS)
	local line: string? = nil
	if what == "Herb" then
		local id = pick(bandPool(data, false))
		if id then
			addItem(player, data, id, 1, online)
			line = tell("Herb", withArticle(Herbs.Defs[id].name))
		end
	elseif what == "Seed" or what == "FarSeed" then
		local id = pick(bandPool(data, what == "FarSeed"))
		if id then
			addSeeds(data, id, 1)
			line = tell(what, withArticle(Herbs.Defs[id].name))
		end
	elseif what and Items.Defs[what] then
		addItem(player, data, what, 1, online)
		line = tell("Item", Items.Defs[what].name)
	end
	if online and line then
		Cultivation.notify(player, line)
	end
end

--[[ Tempering ]]

local function utcDay(): number
	return os.time() // 86400
end

local function utcWeek(): number
	return (utcDay() + 3) // 7 -- weeks from Monday, like the sect's (1970-01-01 was a Thursday)
end

-- Items absorbed today and this week (the counters roll over by themselves).
local function absorbed(sec: PlayerData.Seclusion): (number, number)
	if sec.temperDay ~= utcDay() then
		sec.temperDay = utcDay()
		sec.temperDayN = 0
	end
	if sec.temperWeek ~= utcWeek() then
		sec.temperWeek = utcWeek()
		sec.temperWeekN = 0
	end
	return sec.temperDayN, sec.temperWeekN
end

local function stageName(key: string?): string
	local stage = key and Realms.ByKey[key]
	return if stage then stage.name else ""
end

-- Why a tempering item can't be absorbed right now (nil: it can).
function Seclusion.cantAbsorb(player: Player, data: PlayerData.Data, id: string): string?
	if not T.POINTS[id] then
		return "It can't temper anything."
	end
	if not live[player] then
		return "Absorb it in seclusion, on your own peak."
	end
	local sec = data.seclusion
	if sec.temper ~= "" then
		return "Let the last one settle first."
	end
	if not Foundation.nextTemper(data) then
		return if next(data.foundation.grades) == nil
			then "You have no old foundations to temper yet."
			else "Your old foundations are all whole. Past 100% is earned, not swallowed."
	end
	local today, week = absorbed(sec)
	if today >= T.PER_DAY then
		return "Your foundation has taken all it can today."
	elseif week >= T.PER_WEEK then
		return "Your foundation has taken all it can this week."
	end
	return nil
end

-- Absorb tempering item `id` (Inventory.use took it): it settles SETTLE_SECONDS on.
function Seclusion.absorb(player: Player, data: PlayerData.Data, id: string)
	local sec = data.seclusion
	absorbed(sec)
	sec.temperDayN += 1
	sec.temperWeekN += 1
	sec.temper = id
	sec.temperAt = sec.counted + T.SETTLE_SECONDS
	Cultivation.notify(player, `Its warmth sinks toward your {stageName(Foundation.nextTemper(data))} foundation. Stay a few minutes.`)
	Seclusion.publish(player, data)
end

-- The absorbed item settles: the lowest old stage is mended.
local function settle(player: Player, data: PlayerData.Data, online: boolean)
	local sec = data.seclusion
	local id = sec.temper
	sec.temper = ""
	sec.temperAt = 0
	local changed = Foundation.temper(data, 1, T.POINTS[id] or 0)
	local tally = data.seclusion.tally
	tally.tempered = tally.tempered or {}
	for _, t in changed do
		table.insert(tally.tempered :: any, t)
	end
	data.stats.tempered += #changed
	Analytics.event(player, "FoundationTempered", #changed, id)
	if online and changed[1] then
		local t = changed[1]
		Cultivation.notify(player, `Your {stageName(t.key)} foundation is mended: {t.fromPercent}% to {t.toPercent}%.`)
		Cultivation.applyStats(player, data)
		Cultivation.pushState(player)
	end
end

-- Rising before an absorbed item settles gives it back.
local function refund(player: Player, data: PlayerData.Data, online: boolean)
	local sec = data.seclusion
	if sec.temper == "" then
		return
	end
	give(player, data, sec.temper, 1, online)
	absorbed(sec)
	sec.temperDayN = math.max(0, sec.temperDayN - 1)
	sec.temperWeekN = math.max(0, sec.temperWeekN - 1)
	if online and Items.Defs[sec.temper] then
		Cultivation.notify(player, `You rose too soon; the {Items.Defs[sec.temper].name} is still whole.`)
	end
	sec.temper = ""
	sec.temperAt = 0
end

-- `seconds` more of seclusion that count (the caller caps them at MAX_SECONDS).
local function accrue(player: Player, data: PlayerData.Data, seconds: number, online: boolean)
	local sec = data.seclusion
	sec.counted += seconds
	data.stats.secluded += seconds
	while sec.rolled < math.floor(sec.counted / S.FIND_SECONDS) do
		sec.rolled += 1
		roll(player, data, online)
	end
	if sec.temper ~= "" and sec.counted >= sec.temperAt then
		settle(player, data, online)
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

-- What the secluded-state plaque shows (SeclusionView.luau): player attributes,
-- refreshed as the tally moves, cleared when it ends.
--   SeclusionSince      os.time() it began (the timer)
--   SeclusionTempering  the stage name being tempered ("" none), SeclusionTemperAt
--                       the os.time() it settles (0 none), SeclusionTempered the
--                       stages mended this seclusion
--   SeclusionFinds      finds and seeds so far
--   SeclusionTended     the garden was tended, SeclusionMutations plants that mutated
local ATTRS = { "SeclusionSince", "SeclusionTempering", "SeclusionTemperAt", "SeclusionTempered", "SeclusionFinds", "SeclusionTended", "SeclusionMutations" }
function Seclusion.publish(player: Player, data: PlayerData.Data)
	if not live[player] then
		return
	end
	local sec = data.seclusion
	local tally = sec.tally
	local finds = 0
	for _, n in tally.items do
		finds += n
	end
	for _, n in tally.seeds do
		finds += n
	end
	local tempering = sec.temper ~= ""
	player:SetAttribute("SeclusionSince", sec.since)
	player:SetAttribute("SeclusionTempering", if tempering then stageName(Foundation.nextTemper(data)) else "")
	player:SetAttribute("SeclusionTemperAt", if tempering then os.time() + math.max(0, math.ceil(sec.temperAt - sec.counted)) else 0)
	player:SetAttribute("SeclusionTempered", #(tally.tempered or {}))
	player:SetAttribute("SeclusionFinds", finds)
	player:SetAttribute("SeclusionTended", tally.growth > 0)
	player:SetAttribute("SeclusionMutations", tally.mutations)
end
local publish = Seclusion.publish

local function unpublish(player: Player)
	for _, name in ATTRS do
		player:SetAttribute(name, nil)
	end
end

-- The onboarding's first seclusion: its gifts, into the tally (the garden and tempering).
local function firstGifts(player: Player, data: PlayerData.Data, online: boolean)
	local tally = data.seclusion.tally
	data.seclusion.first = true
	for id, n in S.FIRST_SEEDS do
		addSeeds(data, id, n)
	end
	for id, n in S.FIRST_ITEMS do
		addItem(player, data, id, n, online)
	end
	local bar = Cultivation.stage(data).bar
	local room = math.max(0, bar - data.cultivation) -- never past the bar
	Cultivation.add(data, math.min(math.floor(bar * S.FIRST_BAR), room))
	tally.growth += Garden.advance(player, data, S.FIRST_GROWTH)
end

-- Close the books on this seclusion: an unsettled item back, first-time gifts, the card.
local function finish(player: Player, data: PlayerData.Data, delay: number, online: boolean)
	local sec = data.seclusion
	local tally = sec.tally
	refund(player, data, online)
	local first = not sec.first
	if first then
		firstGifts(player, data, online)
	end
	tally.cultivation = math.max(0, math.floor(data.cultivation - sec.start))

	local items = {}
	local found = false
	for id, n in tally.items do
		table.insert(items, { key = id, amount = n })
		found = true
	end
	for id, n in tally.seeds do
		table.insert(items, { key = `seed:{id}`, amount = n })
		found = true
	end
	-- the garden as a tile: its mutations, or just tended
	if tally.mutations > 0 then
		table.insert(items, { key = "mutation", amount = tally.mutations })
	elseif tally.growth > 0 then
		table.insert(items, { key = "garden", amount = 1 })
	end
	local tempered = tally.tempered or {}
	local stats: { any } = Foundation.temperStats(tempered)
	if tally.cultivation > 0 then
		table.insert(stats, { name = "Cultivation", from = sec.start // 1, to = data.cultivation // 1 })
	end
	local spent = os.time() - sec.since
	local spec = {
		tier = "card",
		kind = "seclusion",
		title = if first then "First Seclusion" else "Seclusion Ends",
		subtitle = `{duration(spent)} in seclusion`,
		items = items,
		stats = stats,
		flavour = if #tempered > 0
			then (if #tempered == 1 then "An old foundation is mended." else "Your old foundations are mended.")
			elseif first then "Next time, bring a herb or pill to temper an old foundation."
			elseif found then "Fortune found you in the stillness."
			else nil,
	}
	Analytics.event(player, "SeclusionEnded", math.floor(sec.counted / 60))
	sec.since = 0
	sec.counted = 0
	sec.online = 0
	sec.rolled = 0
	sec.start = 0
	sec.tally = PlayerData.newTally()
	-- the card only for a seclusion worth one: long enough, the first, or something
	-- found or tempered; a quick sit, say to check something, rises quietly
	if first or found or #tempered > 0 or spent >= S.CARD_MIN_MINUTES * 60 then
		task.delay(delay, function()
			if player.Parent then
				effectRemote:FireClient(player, "reward", spec)
			end
		end)
	end
end

-- Leave seclusion (rising, or the first one's timer): the player stays seated.
function Seclusion.leave(player: Player)
	local data = PlayerData.get(player)
	if not live[player] then
		return
	end
	if data and data.seclusion.since > 0 then
		finish(player, data, 0, true) -- while still live, so a refund lands in the bag with its row
	end
	live[player] = nil
	player:SetAttribute("Secluded", nil)
	unpublish(player)
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
	data.seclusion.temper = ""
	data.seclusion.temperAt = 0
	live[player] = true
	player:SetAttribute("Secluded", true)
	Analytics.event(player, "SeclusionEntered", 1, if data.seclusion.first then "again" else "first")
	publish(player, data)
	Cultivation.pushState(player)
	if data.seclusion.first then
		Cultivation.notify(player, "You close your eyes and shut out the world. Rise when you wish to return.")
	else
		Cultivation.notify(player, "You close your eyes and shut out the world. Absorb a herb or pill to temper an old foundation.")
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
	finish(player, data, CARD_DELAY, false)
end

function Seclusion.forget(player: Player)
	live[player] = nil -- data.seclusion.since stays set: it carries on offline
end

Cultivation.secluded = Seclusion.active
Cultivation.enterSeclusion = Seclusion.enter
Garden.secluded = Seclusion.active
Inventory.cantAbsorb = Seclusion.cantAbsorb
Inventory.absorb = Seclusion.absorb
Garden.onTended = function(player: Player, tended: number, mutations: number)
	local data = PlayerData.get(player)
	if data then
		data.seclusion.tally.growth += tended
		data.seclusion.tally.mutations += mutations
		publish(player, data)
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
					publish(player, data)
				elseif sec.temper ~= "" then
					settle(player, data, true) -- past MAX_HOURS: nothing more counts, so it settles now
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
