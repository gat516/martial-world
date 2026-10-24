--!strict
-- Foundation grades (docs/systems/cultivation.md "Foundation grade"). What a player
-- experiences while at a stage grades the breakthrough out of it: Cracked, Steady,
-- Solid or Deep. Experiences are one-time keys, once ever per profile
-- (data.foundation.seen), by category:
--   Hunt      "hunt:<enemy>"         first kill of a beast type
--   Boss      "boss:<enemy>"         first kill of a boss (counts double)
--   Home      "home:tier:<n>"        first harvest of a herb tier
--             "home:mut:<mutation>"  first harvest with a rare mutation (Pacing MUTATION_BONUS)
--             "home:book:<tier>"     a tier's Herbarium page completed (server Herbarium)
--   Dao       "dao:<class>:<level>"  a weapon Dao level reached
--   Discover  "discover:<cache id>"  a world cache or weapon rack claimed
--   World     "world:<event id>"     taking part in a world event
--             "world:treasure:<weather>"  claiming a heavenly treasure
-- The weighted count this stage (data.foundation.count) against Pacing.Foundation
-- TARGET picks the grade at the breakthrough (Cultivation.advance calls `seal`),
-- stored by stage key in data.foundation.grades; the count then resets. Every
-- graded stage's BONUS sums into one multiplier on max health and power.
-- `temper` raises old grades later (the heart-demon trial, HeartDemon.luau).
-- The pools are global today, so they run thin past QC; per-region pools come with
-- the regions (roadmap).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local EventDefs = require(ReplicatedStorage.Shared.WorldEvents)
local PlayerData = require(script.Parent.PlayerData)

local Config = Pacing.Foundation
local ROMAN = { "I", "II", "III", "IV", "V" }

local Foundation = {}

export type Hint = { category: string, text: string }

-- Set by Cultivation: pushes the PlayerState snapshot after an experience.
Foundation.onChanged = nil :: ((Player) -> ())?

-- Running world events with no location (a wilds-wide surge): any kill while one
-- runs counts as taking part. Kept by WorldEvents.
Foundation.unlocated = {} :: { [string]: boolean }

local function stageOf(data: PlayerData.Data): Realms.Stage
	return Realms.get(data.realm.major, data.realm.minor)
end

function Foundation.target(stage: Realms.Stage): number
	return Config.TARGET[stage.key] or Config.DEFAULT_TARGET
end

-- The grade `count` experiences make against `target`.
function Foundation.gradeFor(count: number, target: number): Pacing.FoundationGrade
	local share = if target > 0 then count / target else 1
	local grade: Pacing.FoundationGrade = Config.GRADES[1].name
	for _, g in Config.GRADES do
		if share >= g.share then
			grade = g.name
		end
	end
	return grade
end

-- The grade the current stage would get if the player broke through now.
function Foundation.pending(data: PlayerData.Data): Pacing.FoundationGrade
	return Foundation.gradeFor(data.foundation.count, Foundation.target(stageOf(data)))
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

export type Tempered = { key: string, from: string, to: string }

-- Raise up to `steps` old grades one step each, the lowest first (ties: the
-- earliest stage), never past the top grade. The heart-demon trial calls it
-- (later seclusion too); the caller refreshes stats. Returns what changed.
function Foundation.temper(data: PlayerData.Data, steps: number): { Tempered }
	local open = {}
	for key, grade in data.foundation.grades do
		local stage = Realms.ByKey[key]
		if stage and rank(grade) < #Config.GRADES then
			table.insert(open, { key = key, rank = rank(grade), at = Realms.index(stage.major, stage.minor) })
		end
	end
	table.sort(open, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.at < b.at
	end)
	local changed: { Tempered } = {}
	for i = 1, math.min(steps, #open) do
		local entry = open[i]
		local to = Config.GRADES[entry.rank + 1].name
		table.insert(changed, { key = entry.key, from = data.foundation.grades[entry.key], to = to })
		data.foundation.grades[entry.key] = to
	end
	return changed
end

-- Whether `grade` is below Solid (the unsteady toast, a harder tribulation).
function Foundation.unsteady(grade: string): boolean
	return rank(grade) < rank(Config.SOLID)
end

-- The summed bonus of every graded stage, as a multiplier (1 = none) on max
-- health and power.
function Foundation.multiplier(data: PlayerData.Data): number
	local total = 0
	for _, grade in data.foundation.grades do
		total += Config.BONUS[grade] or 0
	end
	return 1 + total
end

-- A heaven-defier's tribulation strike damage multiplier, from the pending grade.
function Foundation.tribulationDamage(data: PlayerData.Data): number
	return Config.TRIBULATION_DAMAGE[Foundation.pending(data)] or 1
end

-- Grade the stage being left and start the next one's count. Called by
-- Cultivation.advance before the realm moves. Returns the grade.
function Foundation.seal(data: PlayerData.Data): Pacing.FoundationGrade
	local stage = stageOf(data)
	local grade = Foundation.pending(data)
	data.foundation.grades[stage.key] = grade
	data.foundation.count = 0
	data.foundation.warned = false
	return grade
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
	if Foundation.onChanged then
		task.spawn(Foundation.onChanged, player)
	end
	return true
end

--[[ Hooks the game calls ]]

function Foundation.kill(player: Player, def: Enemies.Def)
	if def.boss then
		Foundation.earn(player, "Boss", `boss:{def.id}`)
	else
		Foundation.earn(player, "Hunt", `hunt:{def.id}`)
	end
	for id in Foundation.unlocated do
		Foundation.earn(player, "World", `world:{id}`)
	end
end

function Foundation.harvest(player: Player, herb: Herbs.Herb, mutations: { string }?)
	Foundation.earn(player, "Home", `home:tier:{herb.tier}`)
	for _, id in mutations or {} do
		local m = Herbs.Mutations[id]
		if m and m.bonus >= Config.MUTATION_BONUS then
			Foundation.earn(player, "Home", `home:mut:{id}`)
		end
	end
end

function Foundation.dao(player: Player, class: string)
	local data = PlayerData.get(player)
	local entry = data and data.dao[class]
	if entry then
		Foundation.earn(player, "Dao", `dao:{class}:{entry.level}`)
	end
end

function Foundation.discover(player: Player, cacheId: string)
	Foundation.earn(player, "Discover", `discover:{cacheId}`)
end

function Foundation.world(player: Player, key: string)
	Foundation.earn(player, "World", `world:{key}`)
end

--[[ Open experiences, for the Self card ]]

local function sortedEnemies(): { Enemies.Def }
	local list = {}
	for _, def in Enemies.Defs do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		local ia, ib = Realms.index(a.realm[1], a.realm[2]), Realms.index(b.realm[1], b.realm[2])
		if ia ~= ib then
			return ia < ib
		end
		return a.name < b.name
	end)
	return list
end

-- Up to Config.HINTS experiences the player hasn't earned that fit their stage:
-- beasts near their realm first, then home, Dao, discovery and the world, and a
-- boss last, as the fast road. Server-built for the PlayerState push.
function Foundation.hints(data: PlayerData.Data): { Hint }
	local seen = data.foundation.seen
	local here = Realms.index(data.realm.major, data.realm.minor)
	local hunts, bosses = {}, {}
	for _, def in sortedEnemies() do
		local at = Realms.index(def.realm[1], def.realm[2])
		if at >= here - Config.HINT_BELOW and at <= here + Config.HINT_ABOVE then
			if def.boss and not seen[`boss:{def.id}`] then
				table.insert(bosses, { category = "Boss", text = `The fast road: defeat the {def.name}` })
			elseif not def.boss and not seen[`hunt:{def.id}`] then
				table.insert(hunts, { category = "Hunt", text = `Slay a {def.name} for the first time` })
			end
		end
	end
	local list: { Hint } = {}
	local function add(hint: Hint?)
		if hint and #list < Config.HINTS then
			table.insert(list, hint)
		end
	end
	add(hunts[1])
	add(hunts[2])
	-- home: the lowest herb tier not yet harvested, else a rare mutation
	local tier = math.huge
	for _, herb in Herbs.Defs do
		if herb.tier < tier and not seen[`home:tier:{herb.tier}`] then
			tier = herb.tier
		end
	end
	if tier ~= math.huge then
		add({ category = "Home", text = `Harvest a tier {ROMAN[tier] or tier} herb` })
	else
		local best: string? = nil
		for id, m in Herbs.Mutations do
			if m.bonus >= Config.MUTATION_BONUS and not seen[`home:mut:{id}`] then
				if not best or m.bonus < Herbs.Mutations[best].bonus then
					best = id
				end
			end
		end
		if best then
			add({ category = "Home", text = `Harvest a {Herbs.Mutations[best].name} herb` })
		else
			-- the lowest Herbarium page not yet complete
			for t = 1, #ROMAN do
				if not seen[`home:book:{t}`] then
					add({ category = "Home", text = `Complete the tier {ROMAN[t]} page of your Herbarium` })
					break
				end
			end
		end
	end
	-- Dao: the next level of the equipped weapon's class
	local class = WeaponDefs.classOf(data.weapons.equipped)
	local entry = data.dao[class]
	local level = if entry then entry.level else 0
	local classDef = WeaponDefs.Classes[class]
	if classDef and level < Pacing.Weapons.MAX_LEVEL then
		add({ category = "Dao", text = `Raise your {classDef.dao} to {level + 1}` })
	end
	add({ category = "Discover", text = "Find a hidden cache or weapon rack in the wilds" })
	local eventLeft = false
	for id in EventDefs.Defs do
		if not seen[`world:{id}`] then
			eventLeft = true
		end
	end
	if eventLeft then
		add({ category = "World", text = "Take part in a world event" })
	end
	add(hunts[3])
	add(bosses[1])
	-- the fast road always shows when one is open: it replaces the last line
	if bosses[1] and not table.find(list, bosses[1]) and #list > 0 then
		list[#list] = bosses[1]
	end
	return list
end

-- The current stage's foundation, for the PlayerState push.
function Foundation.state(data: PlayerData.Data)
	return {
		count = data.foundation.count,
		target = Foundation.target(stageOf(data)),
		grade = Foundation.pending(data),
		grades = data.foundation.grades,
		bonus = Foundation.multiplier(data) - 1,
		hints = Foundation.hints(data),
	}
end

return Foundation
