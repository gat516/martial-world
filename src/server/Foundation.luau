--!strict
-- Foundation (docs/systems/cultivation.md "Foundation grade"). What a player
-- experiences while at a stage builds the foundation of the breakthrough out of it,
-- as a percent of the stage's target (Pacing.Foundation): 100% is full, more goes
-- past it up to MAX_PERCENT, and every graded stage adds percent x BONUS_PER_PERCENT
-- to max health and power. The grade word (Unsteady, Steady, Solid, Deep) is flavour.
--
-- Experiences are keys earned once per profile (data.foundation.seen). Most carry the
-- pool they belong to, `@<band>`: the realm band's region (Herbs.Regions: InnerWilds
-- QC1-4, MiddleWilds QC5-9, OuterWilds QR1-5, DeepWilds QR6-FE3, FarReaches FE4-9),
-- so each band has its own fresh pool. A kill's band is the beast's own realm (a
-- variant's spawn realm); everything else uses the player's realm (the testbed has no
-- regions, and Deep Wilds and the Far Reaches aren't on the map yet).
--   Hunt      "hunt:<enemy>:<tier>@<band>"  first kill of a beast at a tier in a band
--   Boss      "boss:<enemy>@<band>"         first kill of a boss (counts double)
--   Home      "home:tier:<n>@<band>"        first harvest of a herb tier at or over the band's
--             "home:mut:<mutation>@<band>"  first harvest with a rare mutation (MUTATION_BONUS)
--             "home:book:<tier>"            a tier's Herbarium page completed (server Herbarium)
--   Dao       "dao:<class>:<level>"         a weapon Dao level reached
--   Discover  "discover:<cache id>"         a world cache or weapon rack claimed
--   World     "world:<event id>@<band>"     taking part in a world event
--             "world:treasure:<weather>@<band>"  claiming a heavenly treasure
--   Deed      Pacing.Foundation.DEEDS: once per stage (data.foundation.deeds, reset at
--             the breakthrough): Hunter, Gardener, Haul, Daring
-- A kill from a beast more than FIT_BELOW stages under the player earns nothing.
-- The weighted count this stage (data.foundation.count) against TARGET gives the
-- percent at the breakthrough (Cultivation.advance calls `seal`), stored by stage key
-- in data.foundation.grades (a number; old profiles' grade words read as LEGACY).
-- `temper` raises old percents later (the heart-demon trial, HeartDemon.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Spawns = require(ReplicatedStorage.Shared.Spawns)
local Regions = require(ReplicatedStorage.Shared.Regions)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Wilds = require(ReplicatedStorage.Shared.Config).Wilds
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local EventDefs = require(ReplicatedStorage.Shared.WorldEvents)
local PlayerData = require(script.Parent.PlayerData)

local Config = Pacing.Foundation
local DEEDS = Config.DEEDS
local ROMAN = { "I", "II", "III", "IV", "V" }

local Foundation = {}

export type Hint = { category: string, text: string }

-- Set by Cultivation: pushes the PlayerState snapshot after an experience.
Foundation.onChanged = nil :: ((Player) -> ())?

-- Running world events with no location (a wilds-wide surge): any kill while one
-- runs counts as taking part. Kept by WorldEvents.
Foundation.unlocated = {} :: { [string]: boolean }

-- The world's caches and racks (WorldCaches registers them): the Regions id each sits
-- in ("" for none: the testbed) and the stage index it needs, for the Discover hint.
local caches: { [string]: { region: string, need: number } } = {}

local function stageOf(data: PlayerData.Data): Realms.Stage
	return Realms.get(data.realm.major, data.realm.minor)
end

local function indexOf(data: PlayerData.Data): number
	return Realms.index(data.realm.major, data.realm.minor)
end

--[[ Bands ]]

-- The realm band (a Herbs.Regions entry) a stage index belongs to.
local function bandAt(at: number): Herbs.SeedRegion
	local band = Herbs.Regions[1]
	for _, r in Herbs.Regions do
		if at >= Realms.index(r.from[1], r.from[2]) then
			band = r
		end
	end
	return band
end
Foundation.bandAt = bandAt

local function bandOf(data: PlayerData.Data): Herbs.SeedRegion
	return bandAt(indexOf(data))
end

--[[ Percent and grade ]]

function Foundation.target(stage: Realms.Stage): number
	return Config.TARGET[stage.key] or Config.DEFAULT_TARGET
end

-- The percent `count` experiences make against `target`, 0..MAX_PERCENT.
function Foundation.percentFor(count: number, target: number): number
	local share = if target > 0 then count / target else 1
	return math.clamp(math.floor(share * 100 + 0.5), 0, Config.MAX_PERCENT)
end

-- The grade word for a percent.
function Foundation.gradeOf(percent: number): Pacing.FoundationGrade
	local grade: Pacing.FoundationGrade = Config.GRADES[1].name
	for _, g in Config.GRADES do
		if percent >= g.share * 100 then
			grade = g.name
		end
	end
	return grade
end

-- A stored stage value as a percent (profiles from before percents hold a grade word).
local function percentOf(value: any): number
	if type(value) == "number" then
		return value
	end
	return if type(value) == "string" then Config.LEGACY[value] or 0 else 0
end
Foundation.percentOf = percentOf

-- The percent the current stage would get if the player broke through now.
function Foundation.percent(data: PlayerData.Data): number
	return Foundation.percentFor(data.foundation.count, Foundation.target(stageOf(data)))
end

-- The grade word the current stage would get now.
function Foundation.pending(data: PlayerData.Data): Pacing.FoundationGrade
	return Foundation.gradeOf(Foundation.percent(data))
end

local function rank(grade: string): number
	for i, g in Config.GRADES do
		if g.name == grade then
			return i
		end
	end
	return 1
end
Foundation.rank = rank

local function label(percent: number): string
	return `{Foundation.gradeOf(percent)} ({percent}%)`
end

export type Tempered = { key: string, from: string, to: string, fromPercent: number, toPercent: number }

-- Raise up to `steps` old stages TEMPER_POINTS each, the lowest percent first (ties:
-- the earliest stage), never past TEMPER_MAX. The heart-demon trial calls it; the
-- caller refreshes stats. Returns what changed (`from`/`to` are "Solid (125%)" labels).
function Foundation.temper(data: PlayerData.Data, steps: number): { Tempered }
	local open = {}
	for key, value in data.foundation.grades do
		local stage = Realms.ByKey[key]
		local percent = percentOf(value)
		if stage and percent < Config.TEMPER_MAX then
			table.insert(open, { key = key, percent = percent, at = Realms.index(stage.major, stage.minor) })
		end
	end
	table.sort(open, function(a, b)
		if a.percent ~= b.percent then
			return a.percent < b.percent
		end
		return a.at < b.at
	end)
	local changed: { Tempered } = {}
	for i = 1, math.min(steps, #open) do
		local entry = open[i]
		local to = math.min(Config.TEMPER_MAX, entry.percent + Config.TEMPER_POINTS)
		table.insert(changed, { key = entry.key, from = label(entry.percent), to = label(to), fromPercent = entry.percent, toPercent = to })
		data.foundation.grades[entry.key] = to
	end
	return changed
end

-- Whether `grade` is below Steady (the unsteady toast, a harder tribulation).
function Foundation.unsteady(grade: string): boolean
	return rank(grade) < rank(Config.STEADY)
end

-- The summed bonus of every graded stage, as a multiplier (1 = none) on max
-- health and power.
function Foundation.multiplier(data: PlayerData.Data): number
	local total = 0
	for _, value in data.foundation.grades do
		total += percentOf(value) * Config.BONUS_PER_PERCENT
	end
	return 1 + total
end

-- A heaven-defier's tribulation strike damage multiplier, from the pending grade.
function Foundation.tribulationDamage(data: PlayerData.Data): number
	return Config.TRIBULATION_DAMAGE[Foundation.pending(data)] or 1
end

-- Settle the stage being left and start the next one's count and deeds. Called by
-- Cultivation.advance before the realm moves. Returns the grade word and percent.
function Foundation.seal(data: PlayerData.Data): (Pacing.FoundationGrade, number)
	local stage = stageOf(data)
	local percent = Foundation.percent(data)
	data.foundation.grades[stage.key] = percent
	data.foundation.count = 0
	data.foundation.warned = false
	data.foundation.deeds = { kills = {}, herbs = {}, done = {} }
	return Foundation.gradeOf(percent), percent
end

--[[ Earning ]]

local function changed(player: Player)
	if Foundation.onChanged then
		task.spawn(Foundation.onChanged, player)
	end
end

-- Record experience `key` of `category` if it's new. Returns whether it counted.
function Foundation.earn(player: Player, category: string, key: string): boolean
	local data = PlayerData.get(player)
	local weight = Config.WEIGHTS[category]
	if not (data and weight) or data.foundation.seen[key] then
		return false
	end
	data.foundation.seen[key] = true
	data.foundation.count += weight
	changed(player)
	return true
end

-- Finish deed `id` for this stage if it isn't yet.
local function deed(player: Player, data: PlayerData.Data, id: string)
	local done = data.foundation.deeds.done
	if done[id] then
		return
	end
	done[id] = true
	data.foundation.count += Config.WEIGHTS.Deed
	changed(player)
end

-- Hunter progress: kills counted, each beast at most perKind.
local function hunted(data: PlayerData.Data): number
	local n = 0
	for _, k in data.foundation.deeds.kills do
		n += math.min(k, DEEDS.Hunter.perKind)
	end
	return n
end

local function countKeys(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

--[[ Hooks the game calls ]]

function Foundation.kill(player: Player, def: Enemies.Def)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local here = indexOf(data)
	local at = Realms.index(def.realm[1], def.realm[2])
	if at >= here - Config.FIT_BELOW then
		local band = bandAt(at).id
		if def.boss then
			Foundation.earn(player, "Boss", `boss:{def.id}@{band}`)
		else
			Foundation.earn(player, "Hunt", `hunt:{def.id}:{def.tier or "adult"}@{band}`)
		end
	end
	local deeds = data.foundation.deeds
	if not def.boss and at >= here - DEEDS.Hunter.below and not deeds.done.Hunter then
		deeds.kills[def.id] = (deeds.kills[def.id] or 0) + 1
		if hunted(data) >= DEEDS.Hunter.kills then
			deed(player, data, "Hunter")
		end
	end
	if at >= here + DEEDS.Daring.above then
		deed(player, data, "Daring")
	end
	for id in Foundation.unlocated do
		Foundation.world(player, id)
	end
end

-- A harvest of herb `id` with its mutation ids (Garden.harvest).
function Foundation.harvest(player: Player, id: string, mutations: { string }?)
	local data = PlayerData.get(player)
	local herb = Herbs.Defs[id]
	if not (data and herb) then
		return
	end
	local band = bandOf(data)
	if herb.tier >= band.tier then
		Foundation.earn(player, "Home", `home:tier:{herb.tier}@{band.id}`)
	end
	for _, m in mutations or {} do
		local def = Herbs.Mutations[m]
		if def and def.bonus >= Config.MUTATION_BONUS then
			Foundation.earn(player, "Home", `home:mut:{m}@{band.id}`)
		end
	end
	local herbs = data.foundation.deeds.herbs
	herbs[id] = true
	if countKeys(herbs) >= DEEDS.Gardener.kinds then
		deed(player, data, "Gardener")
	end
end

-- A Store all that banked `rawQi` raw qi (Haul.storeAll).
function Foundation.stored(player: Player, rawQi: number)
	local data = PlayerData.get(player)
	if data and rawQi >= stageOf(data).dantian * DEEDS.Haul.share then
		deed(player, data, "Haul")
	end
end

function Foundation.dao(player: Player, class: string)
	local data = PlayerData.get(player)
	local entry = data and data.dao[class]
	if entry then
		Foundation.earn(player, "Dao", `dao:{class}:{entry.level}`)
	end
end

-- A cache or rack the map placed (WorldCaches), for the Discover hint.
function Foundation.registerCache(id: string, position: Vector3, need: string?)
	local region = Regions.at(position)
	local stage = need and Realms.ByKey[need]
	caches[id] = {
		region = if region then region.id else "",
		need = if stage then Realms.index(stage.major, stage.minor) else 0,
	}
end

function Foundation.discover(player: Player, cacheId: string)
	Foundation.earn(player, "Discover", `discover:{cacheId}`)
end

-- A world event taken part in (`<event id>`) or a treasure claimed
-- (`treasure:<weather>`), in the player's band.
function Foundation.world(player: Player, key: string)
	local data = PlayerData.get(player)
	if data then
		Foundation.earn(player, "World", `world:{key}@{bandOf(data).id}`)
	end
end

--[[ Open experiences, for the Self card ]]

local TIER_WORD = { young = "a young ", adult = "", elite = "an elite ", apex = "an apex " }

local function article(name: string): string
	return if string.find(name, "^[AEIOU]") then "an " else "a "
end

-- Beasts the player could meet in a stage-index range: every def at its own realm,
-- and with realm variants on, every ambient pack's range at the tier it gives.
local function candidates(lo: number, hi: number): { { def: Enemies.Def, at: number, tier: string } }
	local list = {}
	local function add(def: Enemies.Def?, at: number, tier: string)
		if def and at >= lo and at <= hi then
			table.insert(list, { def = def, at = at, tier = tier })
		end
	end
	for _, def in Enemies.Defs do
		add(def, Realms.index(def.realm[1], def.realm[2]), "adult")
	end
	if Wilds.VARIANTS then
		for _, packs in Spawns.Encounters do
			for _, pack in packs do
				local a = pack.realm and Realms.ByKey[pack.realm[1]]
				local b = pack.realm and Realms.ByKey[pack.realm[2]]
				if a and b then
					for i = math.max(lo, Realms.index(a.major, a.minor)), math.min(hi, Realms.index(b.major, b.minor)) do
						for id in pack.beasts do
							local def = Enemies.Defs[id]
							if def and not def.boss then
								add(def, i, Enemies.tierAt(def, Realms.Stages[i].key))
							end
						end
					end
				end
			end
		end
	end
	return list
end

-- The open deeds, with their progress, in DEED_ORDER.
local function deedHints(data: PlayerData.Data): { Hint }
	local deeds = data.foundation.deeds
	local list = {}
	for _, id in Config.DEED_ORDER do
		if not deeds.done[id] then
			local text, progress = nil, ""
			if id == "Hunter" then
				local d = DEEDS.Hunter
				text = `Slay {d.kills} beasts near your realm, no more than {d.perKind} of a kind,`
				progress = ` ({hunted(data)}/{d.kills})`
			elseif id == "Gardener" then
				text = `Harvest {DEEDS.Gardener.kinds} different herbs`
				progress = ` ({countKeys(deeds.herbs)}/{DEEDS.Gardener.kinds})`
			elseif id == "Haul" then
				text = "Bring home a nearly full dantian of raw qi and store it"
			elseif id == "Daring" then
				text = `Defeat a beast {DEEDS.Daring.above} stages above you`
			end
			if text then
				table.insert(list, { category = "Deed", text = `{text} this stage{progress}` })
			end
		end
	end
	return list
end

-- Up to Config.HINTS experiences the player hasn't earned, all from their own band
-- (or a beast within HINT_BELOW..HINT_ABOVE stages): beasts near their realm first,
-- a deed, home, Dao, discovery and the world, and a boss last, as the fast road.
-- Server-built for the PlayerState push.
function Foundation.hints(data: PlayerData.Data): { Hint }
	local seen = data.foundation.seen
	local here = indexOf(data)
	local band = bandAt(here)
	local hunts, bosses = {}, {}
	local listed: { [string]: boolean } = {}
	for _, c in candidates(math.max(1, here - Config.HINT_BELOW), here + Config.HINT_ABOVE) do
		local def = c.def
		local where = bandAt(c.at).id
		local key = if def.boss then `boss:{def.id}@{where}` else `hunt:{def.id}:{c.tier}@{where}`
		if not (seen[key] or listed[key]) then
			listed[key] = true
			local text = if def.boss
				then `The fast road: defeat the {def.name}`
				else `Slay {if c.tier == "adult" then article(def.name) else TIER_WORD[c.tier] or ""}{def.name}`
			table.insert(if def.boss then bosses else hunts, { at = c.at, hint = { category = if def.boss then "Boss" else "Hunt", text = text } })
		end
	end
	local function closest(a, b)
		local ga, gb = math.abs(a.at - here), math.abs(b.at - here)
		if ga ~= gb then
			return ga < gb
		end
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.hint.text < b.hint.text
	end
	table.sort(hunts, closest)
	table.sort(bosses, closest)

	local list: { Hint } = {}
	local function add(hint: Hint?)
		if hint and #list < Config.HINTS and not table.find(list, hint) then
			table.insert(list, hint)
		end
	end
	local deeds = deedHints(data)
	add(hunts[1] and hunts[1].hint)
	add(deeds[1])
	-- home: the band's herb tier not yet harvested here, else a rare mutation, else
	-- an open Herbarium page up to the band's tier
	local tierLeft = false
	for _, herb in Herbs.Defs do
		if herb.tier == band.tier then
			tierLeft = not seen[`home:tier:{band.tier}@{band.id}`]
			break
		end
	end
	if tierLeft then
		add({ category = "Home", text = `Harvest a tier {ROMAN[band.tier] or band.tier} herb` })
	else
		local best: string? = nil
		for id, m in Herbs.Mutations do
			if m.bonus >= Config.MUTATION_BONUS and not seen[`home:mut:{id}@{band.id}`] then
				if not best or m.bonus < Herbs.Mutations[best].bonus then
					best = id
				end
			end
		end
		if best then
			add({ category = "Home", text = `Harvest a {Herbs.Mutations[best].name} herb` })
		else
			for t = 1, math.min(band.tier, #ROMAN) do
				if not seen[`home:book:{t}`] then
					add({ category = "Home", text = `Complete the tier {ROMAN[t]} page of your Herbarium` })
					break
				end
			end
		end
	end
	add(hunts[2] and hunts[2].hint)
	-- Dao: the next level of the equipped weapon's class
	local class = WeaponDefs.classOf(data.weapons.equipped)
	local entry = data.dao[class]
	local level = if entry then entry.level else 0
	local classDef = WeaponDefs.Classes[class]
	if classDef and level < Pacing.Weapons.MAX_LEVEL then
		add({ category = "Dao", text = `Raise your {classDef.dao} to {level + 1}` })
	end
	-- Discover: only when an unclaimed cache the player can open lies in their band's
	-- region (or in no region: the testbed)
	local inBand, anywhere = false, false
	for id, c in caches do
		if not (seen[`discover:{id}`] or data.caches[id]) and c.need <= here then
			if c.region == band.id then
				inBand = true
			elseif c.region == "" then
				anywhere = true
			end
		end
	end
	if inBand then
		add({ category = "Discover", text = `Find a hidden cache in the {band.name}` })
	elseif anywhere then
		add({ category = "Discover", text = "Find a hidden cache or weapon rack" })
	end
	-- World: an event, else a heavenly treasure, not yet met in this band
	local eventLeft = false
	for id in EventDefs.Defs do
		if not seen[`world:{id}@{band.id}`] then
			eventLeft = true
		end
	end
	if eventLeft then
		add({ category = "World", text = "Take part in a world event" })
	else
		for id, w in Weather.Defs do
			if (w.treasures or 0) > 0 and not seen[`world:treasure:{id}@{band.id}`] then
				add({ category = "World", text = "Claim a heavenly treasure" })
				break
			end
		end
	end
	add(deeds[2])
	add(hunts[3] and hunts[3].hint)
	add(deeds[3])
	local boss = bosses[1] and bosses[1].hint
	add(boss)
	-- the fast road always shows when one is open: it replaces the last line
	if boss and not table.find(list, boss) and #list > 0 then
		list[#list] = boss
	end
	return list
end

-- The current stage's foundation, for the PlayerState push.
function Foundation.state(data: PlayerData.Data)
	local grades, percents = {}, {}
	for key, value in data.foundation.grades do
		local percent = percentOf(value)
		percents[key] = percent
		grades[key] = Foundation.gradeOf(percent)
	end
	local percent = Foundation.percent(data)
	return {
		count = data.foundation.count,
		target = Foundation.target(stageOf(data)),
		percent = percent,
		max = Config.MAX_PERCENT,
		grade = Foundation.gradeOf(percent),
		grades = grades,
		percents = percents,
		bonus = Foundation.multiplier(data) - 1,
		hints = Foundation.hints(data),
	}
end

return Foundation
