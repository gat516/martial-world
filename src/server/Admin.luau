--!strict
-- Admin tools behind the PC admin dashboard (AdminPanel.luau): force weather
-- and world events, give items, seeds and Spirit Stones, spawn beasts, and tend
-- the garden instantly. Admins are the game's creator, the ids in Config.Admin.USER_IDS, and
-- anyone in a Studio playtest. They're marked with the Admin attribute so the
-- client shows the dashboard; the server re-checks every request.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Weather = require(ReplicatedStorage.Shared.Weather)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Cultivation = require(script.Parent.Cultivation)
local Inventory = require(script.Parent.Inventory)
local EnemyService = require(script.Parent.EnemyService)
local WeatherService = require(script.Parent.WeatherService)
local Garden = require(script.Parent.Garden)
local WorldEvents = require(script.Parent.WorldEvents)

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
		for i = 1, count do
			local a = (i / count) * math.pi * 2
			local at = (root.CFrame * CFrame.new(math.cos(a) * 4, 0, -14 + math.sin(a) * 4)).Position
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
	fillQi = function(player, data)
		data.rawQi = Cultivation.stage(data).dantian
		Cultivation.pushState(player)
		return true, "Dantian filled"
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
