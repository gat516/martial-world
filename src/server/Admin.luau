--!strict
-- Admin tools behind the PC admin dashboard (AdminPanel.luau): force weather
-- and world events, give items, seeds, weapons and Spirit Stones, set technique
-- and Dao levels, set or reroll the spirit root, spawn beasts, and tend
-- the garden instantly, and manage any player's race, variant and traits. Admins are the game's creator, the ids in Config.Admin.USER_IDS, and
-- anyone in a Studio playtest. They're marked with the Admin attribute so the
-- client shows the dashboard; the server re-checks every request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local Weather = require(ReplicatedStorage.Shared.Weather)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Cultivation = require(script.Parent.Cultivation)
local Inventory = require(script.Parent.Inventory)
local EnemyService = require(script.Parent.EnemyService)
local WeatherService = require(script.Parent.WeatherService)
local Garden = require(script.Parent.Garden)
local WorldEvents = require(script.Parent.WorldEvents)
local Weapons = require(script.Parent.Weapons)
local Roots = require(script.Parent.Roots)
local RootDefs = require(ReplicatedStorage.Shared.Roots)
local Methods = require(script.Parent.Methods)
local MethodDefs = require(ReplicatedStorage.Shared.Methods)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Traits = require(script.Parent.Traits)

local MAX_COUNT = 999
local MAX_SPAWN = 10

local Admin = {}

function Admin.isAdmin(player: Player): boolean
	return RunService:IsStudio() or player.UserId == game.CreatorId or table.find(Config.Admin.USER_IDS, player.UserId) ~= nil
end

function Admin.mark(player: Player)
	player:SetAttribute("Admin", Admin.isAdmin(player) or nil)
end

local function amount(n: any, max: number): number?
	return if type(n) == "number" and n == n // 1 and n >= 1 and n <= max then n else nil
end

-- The player an admin action is for: a UserId, a name, a unique name prefix, or
-- nil for the admin themself.
local function targetOf(admin: Player, who: any): (Player?, string?)
	if who == nil or who == "" then
		return admin, nil
	elseif type(who) == "number" then
		local found = Players:GetPlayerByUserId(who)
		return found, if found then nil else "Player not in this server"
	elseif type(who) ~= "string" then
		return nil, "Bad player"
	end
	local query = string.lower(who)
	local matches = {}
	for _, p in Players:GetPlayers() do
		local name, display = string.lower(p.Name), string.lower(p.DisplayName)
		if name == query or display == query then
			return p, nil
		elseif string.sub(name, 1, #query) == query or string.sub(display, 1, #query) == query then
			table.insert(matches, p)
		end
	end
	if #matches == 1 then
		return matches[1], nil
	end
	return nil, if #matches == 0 then `No player matches "{who}"` else `"{who}" matches {#matches} players`
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local actions: { [string]: (Player, PlayerData.Data, ...any) -> (boolean, string?) } = {
	weather = function(_, _, id)
		local def = type(id) == "string" and Weather.Defs[id]
		if not def then
			return false, "Unknown weather"
		end
		local range = def.minutes
		WeatherService.set(def, 60 * (range[1] + math.random() * (range[2] - range[1])))
		return true, `Weather: {id}`
	end,
	give = function(player, _, id, n)
		local count = amount(n, MAX_COUNT)
		if not (type(id) == "string" and Items.Defs[id] and count) then
			return false, "Unknown item or count"
		end
		Inventory.grant(player, id, count)
		return true, `Gave {count} {Items.Defs[id].name}`
	end,
	seeds = function(player, data, id, n)
		local count = amount(n, MAX_COUNT)
		if not (type(id) == "string" and Herbs.Defs[id] and count) then
			return false, "Unknown seed or count"
		end
		data.seeds[id] = (data.seeds[id] or 0) + count
		Cultivation.pushState(player)
		return true, `Gave {count} {Herbs.Defs[id].name} seeds`
	end,
	stones = function(player, data, n)
		local count = amount(n, 1e6)
		if not count then
			return false, "Bad amount"
		end
		data.stones += count
		Cultivation.pushState(player)
		return true, `Gave {count} Spirit Stones`
	end,
	-- sets a technique's level (learning it if needed), for testing its tiers
	techniqueLevel = function(player, data, id, n)
		local level = amount(n, Techniques.MAX_LEVEL)
		local def = type(id) == "string" and Techniques.Defs[id]
		if not (def and level) then
			return false, `Unknown technique, or level isn't 1-{Techniques.MAX_LEVEL}`
		end
		data.techniques.owned[id] = { level = level, xp = 0 }
		data.techniques.manuals[id] = nil
		Cultivation.pushState(player)
		return true, `{def.name} is now level {level}`
	end,
	weapon = function(player, _, id)
		local def = type(id) == "string" and WeaponDefs.Defs[id]
		if not def then
			return false, "Unknown weapon"
		end
		Weapons.grant(player, id)
		return true, `Gave {def.name}`
	end,
	-- gives a cultivation method (the first becomes active), or with no id
	-- clears them all back to Sect Breathing
	method = function(player, data, id)
		if id == nil or id == "" then
			data.methods = { owned = {}, active = "" }
			Cultivation.pushState(player)
			return true, "Back to Sect Breathing"
		end
		local def = type(id) == "string" and MethodDefs.Defs[id]
		if not def then
			return false, "Unknown method"
		end
		if not Methods.grant(player, id) then
			return false, `Already known: {def.name}`
		end
		return true, `Gave {def.name}`
	end,
	allWeapons = function(player, data)
		for _, id in WeaponDefs.Order do
			if (data.weapons.owned[id] or 0) <= 0 then
				Weapons.grant(player, id, true)
			end
		end
		return true, "Gave every weapon"
	end,
	-- sets a class's Dao comprehension level (0 to max)
	daoLevel = function(player, data, class, n)
		local def = type(class) == "string" and WeaponDefs.Classes[class]
		local level = if type(n) == "number" and n == n // 1 and n >= 0 and n <= WeaponDefs.MAX_LEVEL then n else nil
		if not (def and level) then
			return false, `Unknown class, or level isn't 0-{WeaponDefs.MAX_LEVEL}`
		end
		data.dao[class] = { level = level, xp = 0 }
		for _, fn in Weapons.onLevelUp do -- kept manuals that now have their Dao are learned
			fn(player, class)
		end
		Cultivation.pushState(player)
		return true, `{def.dao} is now {level}`
	end,
	buildItems = function(player, data, n)
		local count = amount(n, MAX_COUNT)
		if not count then
			return false, "Bad amount"
		end
		for _, id in BuildItems.Order do
			data.decor[id] = (data.decor[id] or 0) + count
		end
		Cultivation.pushState(player)
		return true, `Gave {count} of every build item`
	end,
	spawn = function(player, _, id, n)
		local count = amount(n, MAX_SPAWN)
		local root = rootOf(player)
		if not (type(id) == "string" and Enemies.Defs[id] and count and root) then
			return false, "Unknown beast or count"
		end
		-- right in front of the player, just clear of the body however big it is
		-- (the Thunder Ape is ~30 studs tall)
		local def = Enemies.Defs[id]
		local template = ServerStorage.Enemies:FindFirstChild(def.body or id)
		local size = if template and template:IsA("Model") then template:GetExtentsSize() else Vector3.zero
		local ahead = math.max(14, math.max(size.X, size.Z) / 2 + 6)
		for i = 1, count do
			local a = (i / count) * math.pi * 2
			local at = (root.CFrame * CFrame.new(math.cos(a) * 4, 0, -ahead + math.sin(a) * 4)).Position
			EnemyService.spawn(id, at)
		end
		return true, `Spawned {count} {Enemies.Defs[id].name}`
	end,
	growAll = function(player)
		return true, `{Garden.growAll(player)} plants are ready`
	end,
	mutateAll = function(player, _, id)
		if not (type(id) == "string" and Herbs.Mutations[id]) then
			return false, "Unknown mutation"
		end
		return true, `{Garden.mutateAll(player, id)} plants turned {Herbs.Mutations[id].name}`
	end,
	wild = function(player, _, id)
		local peak = Peaks.ownedBy(player)
		if not (type(id) == "string" and Herbs.Defs[id] and peak) then
			return false, "Unknown herb, or you have no peak"
		end
		Garden.sproutWild(peak, { id }, Config.Garden.WILD_PER_PEAK)
		return true, `Wild {Herbs.Defs[id].name} sprouted on your peak`
	end,
	event = function(_, _, id)
		if type(id) ~= "string" then
			return false, "Unknown event"
		end
		local ok, reason = WorldEvents.start(id)
		return ok, if ok then `Started {id}` else reason
	end,
	stopEvents = function()
		WorldEvents.stopAll()
		return true, "Stopped every world event"
	end,
	-- set the spirit root's element ("" = untested again), or with no id reroll it
	root = function(player, data, id)
		if id ~= nil and not (id == "" or (type(id) == "string" and RootDefs.Elements[id])) then
			return false, "Unknown element"
		end
		RootDefs.switch(data.root, if id == nil then RootDefs.roll(Random.new()) else id)
		Roots.publish(player, data)
		Cultivation.applyStats(player, data)
		Cultivation.pushState(player)
		return true, if data.root.element == "" then "Root untested" else `Root: {data.root.element}`
	end,
	rootGrade = function(player)
		local ok, reason = Roots.raiseGrade(player)
		return ok, if ok then "Root grade raised" else reason
	end,
	-- jump to a realm stage by key ("QC9", "FE1"), qi untouched and tribulation cooldown cleared
	realm = function(player, data, key)
		local stage = type(key) == "string" and Realms.ByKey[key]
		if not stage then
			return false, "Unknown stage"
		end
		data.realm = { major = stage.major, minor = stage.minor }
		data.tribulationReadyUnix = 0
		Cultivation.applyStats(player, data)
		Cultivation.pushState(player)
		Traits.check(player) -- realm-gated traits unlock as if broken through
		return true, `Realm: {key}`
	end,
	-- face the current stage's heavenly tribulation now
	tribulation = function(player)
		local start = Cultivation.startTribulation
		if not start then
			return false, "Tribulation not loaded"
		end
		return start(player)
	end,
	fillQi = function(player, data)
		data.rawQi = Cultivation.stage(data).dantian
		Cultivation.pushState(player)
		return true, "Dantian filled"
	end,

	-- Trait management (docs/systems/identity.md). Each takes a target: a UserId
	-- or a name (exact, else the only name or display name starting with it; nil
	-- = yourself). Grants and race changes go through Traits, the same code
	-- normal play uses, so admin tests can't drift from the real rules.
	traitInfo = function(player, _, who)
		local target, why = targetOf(player, who)
		if not target then
			return false, why
		end
		local info = Traits.describe(target)
		return info ~= nil, info or "Player not loaded"
	end,
	traitGrant = function(player, _, who, id, force)
		local target, why = targetOf(player, who)
		if not target then
			return false, why
		end
		return Traits.adminGrant(target, id, force)
	end,
	traitRemove = function(player, _, who, id)
		local target, why = targetOf(player, who)
		if not target then
			return false, why
		end
		return Traits.adminRemove(target, id)
	end,
	-- race id and variant id ("" or nil = land on one)
	traitSetRace = function(player, _, who, raceId, variantId)
		local target, why = targetOf(player, who)
		if not target then
			return false, why
		end
		return Traits.adminSetRace(target, raceId, variantId)
	end,
	-- re-run innate and unlock checks now
	traitSync = function(player, _, who)
		local target, why = targetOf(player, who)
		if not target then
			return false, why
		end
		Traits.check(target)
		return true, `Synced {target.Name}'s traits`
	end,
}

function Admin.handle(player: Player, action: any, ...: any): (boolean, string?)
	if not Admin.isAdmin(player) then
		return false, "Not allowed"
	end
	local data = PlayerData.get(player)
	local fn = type(action) == "string" and actions[action]
	if not (data and fn) then
		return false, "Unknown action"
	end
	return fn(player, data, ...)
end

return Admin
