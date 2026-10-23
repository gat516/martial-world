--!strict
-- The one reader of the identity config (Races, Variants/, Traits/,
-- Availability): lookups, availability, eligibility, roll pools and stat
-- modifiers, shared by server and client so both read the rules the same way
-- (docs/systems/identity.md). The server decides; the client only displays.
-- Nothing here changes a profile; src/server/Traits.luau and
-- CharacterIdentity.luau do.
--
-- A character's identity lives in its slot profile (PlayerData `identity`); the
-- race and variant are a copy of the slot position's fate (Slots.luau):
--   race     race id ("" until the slot is played)
--   variant  variant id within the race ("" when the race has none)
--   traits   { [traitId]: { src: string, t: number, force: boolean? } }
--            src "innate" | "unlock" | "grant" | "admin"; force = an admin gave it
--            past its Access, for testing (it stays active only while forced)

local Availability = require(script.Parent.Availability)
local Races = require(script.Parent.Races)
local Requirements = require(script.Parent.Requirements)

export type Identity = {
	race: string,
	variant: string,
	traits: { [string]: { src: string, t: number, force: boolean? } },
}

local Registry = {}

-- The stat modifier kinds a race, variant or trait may set. They're the spirit
-- root perk kinds (Shared.Roots), read at the same places (Cultivation, Combat,
-- Garden) through Registry.stat:
--   health    share added to max health        walk   studs/s added to walk speed
--   jump      share added to jump height        strike share added to M1 damage
--   guard     share cut from damage taken       technique share added to technique damage
--   growth    share added to herb growth speed   regen  share of max health healed per second out of combat
--   size      share added to body size (0.15 = 15% larger), applied by the server's
--             Traits.applySize with Model:ScaleTo; hitboxes and reach don't grow with it
Registry.MODIFIERS = {
	health = true, walk = true, jump = true, strike = true,
	guard = true, technique = true, growth = true, regen = true, size = true,
}
Registry.STATUSES = { Released = true, Hidden = true, Disabled = true }
Registry.ACQUIRE = { Roll = true, Select = true, Unlock = true }
Registry.OBTAIN = { Innate = true, Unlock = true, Grant = true }

Registry.Races = Races

-- Variant tables by race id, and every trait by id (with its category).
Registry.Variants = {} :: { [string]: { [string]: any } }
Registry.Traits = {} :: { [string]: any }
Registry.Categories = {} :: { string }

for raceId, race in Races do
	if race.Variants then
		local module = script.Parent.Variants:FindFirstChild(race.Variants)
		if module and module:IsA("ModuleScript") then
			Registry.Variants[raceId] = require(module) :: any
		else
			warn(`Identity: race {raceId} names variants "{race.Variants}" but Variants/{race.Variants} is missing`)
		end
	end
end
for _, module in script.Parent.Traits:GetChildren() do
	if module:IsA("ModuleScript") then
		table.insert(Registry.Categories, module.Name)
		for id, def in require(module) :: any do
			if Registry.Traits[id] then
				warn(`Identity: trait {id} is defined twice (in {Registry.Traits[id].Category} and {module.Name}); keeping the first`)
			else
				def.Category = module.Name
				Registry.Traits[id] = def
			end
		end
	end
end
table.sort(Registry.Categories)

--[[ Availability ]]

local HIDDEN: Availability.Entry = { Status = "Hidden" }
local RELEASED: Availability.Entry = { Status = "Released" }

function Registry.raceEntry(raceId: string): Availability.Entry
	return Availability.Races[raceId] or HIDDEN
end

function Registry.variantEntry(raceId: string, variantId: string): Availability.Entry
	local list = Availability.Variants[raceId]
	return list and list[variantId] or HIDDEN
end

function Registry.traitEntry(traitId: string): Availability.Entry
	return Availability.Traits[traitId] or RELEASED
end

-- Whether an availability entry is obtained by `method` ("Roll", "Select", "Unlock").
function Registry.acquires(entry: Availability.Entry, method: string): boolean
	local acquire = entry.Acquire
	if type(acquire) == "string" then
		return acquire == method
	elseif type(acquire) == "table" then
		return table.find(acquire, method) ~= nil
	end
	return false
end

function Registry.released(entry: Availability.Entry): boolean
	return entry.Status == "Released"
end

function Registry.disabled(entry: Availability.Entry): boolean
	return entry.Status == "Disabled"
end

--[[ Lookups ]]

function Registry.race(raceId: any): any
	return if type(raceId) == "string" then Races[raceId] else nil
end

function Registry.variant(raceId: any, variantId: any): any
	local list = type(raceId) == "string" and Registry.Variants[raceId]
	return if list and type(variantId) == "string" then list[variantId] else nil
end

function Registry.hasVariants(raceId: string): boolean
	return Registry.Variants[raceId] ~= nil
end

function Registry.trait(traitId: any): any
	return if type(traitId) == "string" then Registry.Traits[traitId] else nil
end

-- "Beast Folk (Wolf)" / "Human"
function Registry.label(raceId: string, variantId: string?): string
	local race = Races[raceId]
	if not race then
		return "Unknown"
	end
	local variant = Registry.variant(raceId, variantId)
	return if variant then `{race.DisplayName} ({variant.DisplayName})` else race.DisplayName
end

--[[ Pools ]]

local variantPool: (string, string) -> { [string]: any }

-- Races (or a race's variants) a normal player can get by `method`: released ones
-- whose Acquire includes it. A rolled race with variants needs at least one
-- variant that can be rolled, since a roll always lands on a variant. { [id]: def }
function Registry.racePool(method: string): { [string]: any }
	local pool = {}
	for id, race in Races do
		local entry = Registry.raceEntry(id)
		local landable = method ~= "Roll" or not Registry.Variants[id] or next(variantPool(id, "Roll")) ~= nil
		if Registry.released(entry) and Registry.acquires(entry, method) and landable then
			pool[id] = race
		end
	end
	return pool
end

function variantPool(raceId: string, method: string): { [string]: any }
	local pool = {}
	for id, variant in Registry.Variants[raceId] or {} do
		local entry = Registry.variantEntry(raceId, id)
		if Registry.released(entry) and Registry.acquires(entry, method) then
			pool[id] = variant
		end
	end
	return pool
end
Registry.variantPool = variantPool

-- Races or variants a player may pick right now (Select, or Unlock with Requires met).
function Registry.choosableRaces(data: any): { [string]: any }
	local pool = Registry.racePool("Select")
	for id, race in Registry.racePool("Unlock") do
		if Requirements.met(data, Registry.raceEntry(id).Requires) then
			pool[id] = race
		end
	end
	return pool
end

function Registry.choosableVariants(raceId: string, data: any): { [string]: any }
	local pool = Registry.variantPool(raceId, "Select")
	for id, variant in Registry.variantPool(raceId, "Unlock") do
		if Requirements.met(data, Registry.variantEntry(raceId, id).Requires) then
			pool[id] = variant
		end
	end
	return pool
end

--[[ Traits ]]

local function listed(list: any, value: string): boolean
	return type(list) == "table" and table.find(list, value) ~= nil
end

-- Whether a trait's Access lets this identity own it. `bloodline` is the
-- player's bloodline id, once bloodlines exist.
function Registry.accessible(traitId: string, identity: Identity, bloodline: string?): boolean
	local def = Registry.Traits[traitId]
	if not def then
		return false
	end
	local access = def.Access
	if access == "Everyone" then
		return true
	elseif type(access) ~= "table" then
		return false
	end
	return listed(access.Races, identity.race)
		or (identity.variant ~= "" and listed(access.Variants, `{identity.race}.{identity.variant}`))
		or (bloodline ~= nil and listed(access.Bloodlines, bloodline))
end

-- "Everyone", "Beast Folk (Wolf) only", "Wolf, Tiger", "Human, Azure Dragon bloodline"
function Registry.accessLabel(traitId: string): string
	local def = Registry.Traits[traitId]
	local access = def and def.Access
	if access == "Everyone" then
		return "Everyone"
	elseif type(access) ~= "table" then
		return "Nobody"
	end
	local names = {}
	for _, raceId in access.Races or {} do
		table.insert(names, if Races[raceId] then Races[raceId].DisplayName else raceId)
	end
	for _, key in access.Variants or {} do
		local raceId, variantId = string.match(key, "^([^.]+)%.(.+)$")
		local variant = Registry.variant(raceId, variantId)
		table.insert(names, if variant then `{Registry.label(raceId :: string, variantId)}` else key)
	end
	for _, bloodline in access.Bloodlines or {} do
		table.insert(names, `{bloodline} bloodline`)
	end
	local text = table.concat(names, ", ")
	return if #names == 1 then `{text} only` else text
end

-- The innate trait ids of a race and its variant.
function Registry.innate(raceId: string, variantId: string): { string }
	local ids = {}
	local race = Races[raceId]
	local variant = Registry.variant(raceId, variantId)
	for _, source in { race, variant } do
		for _, id in (source and source.InnateTraits) or {} do
			if not table.find(ids, id) then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

-- Every trait open to this race and variant (its trait pool), released or not.
function Registry.traitPool(raceId: string, variantId: string): { string }
	local identity = { race = raceId, variant = variantId, traits = {} }
	local ids = Registry.innate(raceId, variantId)
	for id in Registry.Traits do
		if not table.find(ids, id) and Registry.accessible(id, identity, nil) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Whether an owned trait does anything right now: defined, not Disabled, and
-- open to the owner (or forced by an admin).
function Registry.active(data: any, traitId: string): boolean
	local identity = data.identity :: Identity?
	local owned = identity and identity.traits[traitId]
	if not owned or not Registry.Traits[traitId] then
		return false
	end
	if Registry.disabled(Registry.traitEntry(traitId)) then
		return false
	end
	local bloodline = type(data.bloodline) == "table" and data.bloodline.id or nil
	return owned.force == true or Registry.accessible(traitId, identity :: Identity, bloodline)
end

-- The first owned trait that `traitId` can't be held with, if any.
function Registry.conflict(identity: Identity, traitId: string): string?
	local def = Registry.Traits[traitId]
	for other in identity.traits do
		local otherDef = Registry.Traits[other]
		if other ~= traitId and (listed(def and def.Excludes, other) or listed(otherDef and otherDef.Excludes, traitId)) then
			return other
		end
	end
	return nil
end

--[[ Stats ]]

-- The sum of every modifier of `kind` the profile's race, variant and active
-- traits give (0 without an identity). Disabled races and variants give nothing.
function Registry.stat(data: any, kind: string): number
	local identity = data and data.identity :: Identity?
	if not identity or identity.race == "" then
		return 0
	end
	local total = 0
	local race = Races[identity.race]
	if race and not Registry.disabled(Registry.raceEntry(identity.race)) then
		total += (race.Modifiers and race.Modifiers[kind]) or 0
		local variant = Registry.variant(identity.race, identity.variant)
		if variant and not Registry.disabled(Registry.variantEntry(identity.race, identity.variant)) then
			total += (variant.Modifiers and variant.Modifiers[kind]) or 0
		end
	end
	for id in identity.traits do
		if Registry.active(data, id) then
			local def = Registry.Traits[id]
			total += (def.Modifiers and def.Modifiers[kind]) or 0
		end
	end
	return total
end

--[[ Cosmetics ]]

-- Accessories the character wears for who they are (fox ears and tail from the
-- fox trait): every `Cosmetics` id on the race, the variant and each active trait.
-- Ids name accessories in ReplicatedStorage.Cosmetics (assets/Cosmetics/); the
-- server's Traits.applyBody puts them on and takes them off. { [id]: true }
function Registry.cosmetics(data: any): { [string]: boolean }
	local set = {}
	local identity = data and data.identity :: Identity?
	if not identity or identity.race == "" then
		return set
	end
	local race = Races[identity.race]
	if race and not Registry.disabled(Registry.raceEntry(identity.race)) then
		for _, id in race.Cosmetics or {} do
			set[id] = true
		end
		local variant = Registry.variant(identity.race, identity.variant)
		if variant and not Registry.disabled(Registry.variantEntry(identity.race, identity.variant)) then
			for _, id in variant.Cosmetics or {} do
				set[id] = true
			end
		end
	end
	for id in identity.traits do
		if Registry.active(data, id) then
			for _, cosmetic in Registry.Traits[id].Cosmetics or {} do
				set[cosmetic] = true
			end
		end
	end
	return set
end

-- A fresh character of this race and variant, holding only its innate traits,
-- shaped like a profile so `cosmetics` and `stat` read it (the creator preview,
-- before the slot is played).
function Registry.fresh(raceId: string, variantId: string): { identity: Identity }
	local traits = {}
	for _, id in Registry.innate(raceId, variantId) do
		traits[id] = { src = "innate", t = 0 }
	end
	return { identity = { race = raceId, variant = variantId, traits = traits } }
end

--[[ Config check ]]

-- Every problem in the config, as readable lines (also warned once at load, so a
-- typo shows in the output instead of failing quietly).
function Registry.problems(): { string }
	local out = {}
	local function check(where: string, modifiers: any, innate: any)
		for kind in modifiers or {} do
			if not Registry.MODIFIERS[kind] then
				table.insert(out, `{where}: unknown modifier "{kind}"`)
			end
		end
		for _, id in innate or {} do
			if not Registry.Traits[id] then
				table.insert(out, `{where}: innate trait {id} isn't defined in Traits/`)
			end
		end
	end
	local function entry(where: string, e: any)
		if not Registry.STATUSES[e.Status] then
			table.insert(out, `{where}: unknown Status "{e.Status}"`)
		end
		local acquire = if type(e.Acquire) == "string" then { e.Acquire } else e.Acquire or {}
		for _, method in acquire do
			if not Registry.ACQUIRE[method] then
				table.insert(out, `{where}: unknown Acquire "{method}"`)
			end
		end
		for _, c in e.Requires or {} do
			if type(c) ~= "table" or not Requirements.Kinds[c.Kind] then
				table.insert(out, `{where}: unknown requirement kind "{type(c) == "table" and c.Kind or c}"`)
			end
		end
	end
	for id, race in Races do
		check(`race {id}`, race.Modifiers, race.InnateTraits)
		for variantId, variant in Registry.Variants[id] or {} do
			check(`variant {id}.{variantId}`, variant.Modifiers, variant.InnateTraits)
		end
	end
	for id, e in Availability.Races do
		if not Races[id] then
			table.insert(out, `Availability.Races.{id}: no such race`)
		end
		entry(`Availability.Races.{id}`, e)
	end
	for raceId, list in Availability.Variants do
		for id, e in list do
			if not Registry.variant(raceId, id) then
				table.insert(out, `Availability.Variants.{raceId}.{id}: no such variant`)
			end
			entry(`Availability.Variants.{raceId}.{id}`, e)
		end
	end
	for id, e in Availability.Traits do
		if not Registry.Traits[id] then
			table.insert(out, `Availability.Traits.{id}: no such trait`)
		end
		entry(`Availability.Traits.{id}`, e)
	end
	for id, def in Registry.Traits do
		check(`trait {id}`, def.Modifiers, nil)
		if not Registry.OBTAIN[def.Obtain] then
			table.insert(out, `trait {id}: unknown Obtain "{def.Obtain}"`)
		end
		local access = def.Access
		if access ~= "Everyone" and type(access) ~= "table" then
			table.insert(out, `trait {id}: Access must be "Everyone" or a table`)
		elseif type(access) == "table" then
			for _, raceId in access.Races or {} do
				if not Races[raceId] then
					table.insert(out, `trait {id}: Access names unknown race {raceId}`)
				end
			end
			for _, key in access.Variants or {} do
				local raceId, variantId = string.match(key, "^([^.]+)%.(.+)$")
				if not Registry.variant(raceId, variantId) then
					table.insert(out, `trait {id}: Access names unknown variant {key} (use "Race.Variant")`)
				end
			end
		end
		for _, other in def.Excludes or {} do
			if not Registry.Traits[other] then
				table.insert(out, `trait {id}: Excludes unknown trait {other}`)
			end
		end
		for _, c in def.Requires or {} do
			if type(c) ~= "table" or not Requirements.Kinds[c.Kind] then
				table.insert(out, `trait {id}: unknown requirement kind`)
			end
		end
	end
	-- innate traits should be open to who gets them
	for raceId in Races do
		for variantId in Registry.Variants[raceId] or { [""] = true } do
			local identity = { race = raceId, variant = variantId, traits = {} }
			for _, traitId in Registry.innate(raceId, variantId) do
				if Registry.Traits[traitId] and not Registry.accessible(traitId, identity, nil) then
					table.insert(out, `trait {traitId} is innate to {Registry.label(raceId, variantId)} but its Access leaves them out`)
				end
			end
		end
	end
	if next(Registry.racePool("Roll")) == nil then
		table.insert(out, "no race is Released with Acquire Roll: new players can't be given one")
	end
	return out
end

for _, line in Registry.problems() do
	warn(`Identity config: {line}`)
end

return Registry
