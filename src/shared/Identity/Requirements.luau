--!strict
-- Unlock conditions for races, variants and traits (Requires lists in
-- Availability.luau and Traits/). Each kind is one checker below; a new kind is
-- one new entry. Checkers read the player's saved profile (PlayerData.Data), so
-- the server is the only one that decides. An unknown kind, or a malformed
-- condition, counts as not met.

local Realms = require(script.Parent.Parent.Realms)

export type Condition = { Kind: string, [string]: any }

local Requirements = {}

-- position of a realm stage in Realms.Stages, by key ("QC5") or by { major, minor }
local function stageIndex(key: any, realm: any): number?
	for i, stage in Realms.Stages do
		if (key and stage.key == key) or (realm and stage.major == realm.major and stage.minor == realm.minor) then
			return i
		end
	end
	return nil
end

local function count(n: any): number
	return if type(n) == "number" then n else 0
end

Requirements.Kinds = {
	-- { Kind = "Realm", AtLeast = "QC5" }
	Realm = function(data: any, c: Condition): boolean
		local need, have = stageIndex(c.AtLeast, nil), stageIndex(nil, data.realm)
		return need ~= nil and have ~= nil and have >= need
	end,
	-- { Kind = "Kills", AtLeast = 100 }
	Kills = function(data: any, c: Condition): boolean
		return count(data.stats and data.stats.kills) >= count(c.AtLeast)
	end,
	-- { Kind = "BossKills", AtLeast = 5 }
	BossKills = function(data: any, c: Condition): boolean
		return count(data.stats and data.stats.bossKills) >= count(c.AtLeast)
	end,
	-- { Kind = "Breakthroughs", AtLeast = 3 }
	Breakthroughs = function(data: any, c: Condition): boolean
		return count(data.stats and data.stats.breakthroughs) >= count(c.AtLeast)
	end,
	-- { Kind = "Quest", Id = "..." }: a rewarded objective already claimed
	Quest = function(data: any, c: Condition): boolean
		return type(c.Id) == "string" and data.quests ~= nil and data.quests[c.Id] == true
	end,
	-- { Kind = "Item", Id = "...", Count = 1 }: holding it (not consumed)
	Item = function(data: any, c: Condition): boolean
		local id = c.Id
		if type(id) ~= "string" then
			return false
		end
		local held = count(data.items and data.items[id]) + count(data.herbs and data.herbs[id])
		return held >= math.max(count(c.Count), 1)
	end,
	-- { Kind = "Trait", Id = "..." }: owning another trait
	Trait = function(data: any, c: Condition): boolean
		return data.identity ~= nil and data.identity.traits[c.Id] ~= nil
	end,
	-- { Kind = "Race", Id = "BeastFolk" } / { Kind = "Variant", Id = "BeastFolk.Wolf" }
	Race = function(data: any, c: Condition): boolean
		return data.identity ~= nil and data.identity.race == c.Id
	end,
	Variant = function(data: any, c: Condition): boolean
		local identity = data.identity
		return identity ~= nil and `{identity.race}.{identity.variant}` == c.Id
	end,
	-- { Kind = "Bloodline", Id = "AzureDragon" }: bloodlines aren't built yet
	-- (docs/character/bloodline.md); reads data.bloodline.id once they are.
	Bloodline = function(data: any, c: Condition): boolean
		return type(data.bloodline) == "table" and data.bloodline.id == c.Id
	end,
} :: { [string]: (any, Condition) -> boolean }

-- Whether every condition holds (an empty or missing list always does).
function Requirements.met(data: any, list: { Condition }?): boolean
	if list == nil then
		return true
	end
	for _, c in list do
		local check = type(c) == "table" and Requirements.Kinds[c.Kind]
		if not check or not check(data, c) then
			return false
		end
	end
	return true
end

-- "Reach QC5, 100 kills" for screens and the admin panel.
function Requirements.describe(list: { Condition }?): string
	if not list or #list == 0 then
		return "None"
	end
	local parts = {}
	for _, c in list do
		local kind = type(c) == "table" and c.Kind or "?"
		local detail = c.AtLeast or c.Id or ""
		table.insert(parts, if c.Count then `{kind} {detail} x{c.Count}` else `{kind} {detail}`)
	end
	return table.concat(parts, ", ")
end

return Requirements
