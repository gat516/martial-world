--!strict
-- Cultivation methods (shared defs: Methods.luau, Pacing.Methods; design:
-- docs/character/method.md). Everyone uses Sect Breathing until Foundation,
-- where they are given a random starter for their root (on the breakthrough,
-- or on joining if they're already there). More come from world caches
-- (`Method` attribute) and admin; the elder's task and explore sources are to do.
-- Switching between owned methods is free while meditating
-- (CultivationAction "method", id).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MethodDefs = require(ReplicatedStorage.Shared.Methods)
local Pacing = require(ReplicatedStorage.Shared.Pacing).Methods
local Realms = require(ReplicatedStorage.Shared.Realms)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local rng = Random.new()

local Methods = {}

-- Called with (player, methodId) when a method is gained, for analytics.
Methods.onGained = {} :: { (Player, string) -> () }

-- Give a method. The first real one becomes active. Effect "method"
-- (methodId, active) lets the client show it.
function Methods.grant(player: Player, id: string): boolean
	local data = PlayerData.get(player)
	local def = MethodDefs.Defs[id]
	if not (data and def) or id == MethodDefs.BASIC or data.methods.owned[id] then
		return false
	end
	data.methods.owned[id] = true
	local active = data.methods.active == ""
	if active then
		data.methods.active = id
	end
	effectRemote:FireClient(player, "method", id, active)
	for _, fn in Methods.onGained do
		task.spawn(fn, player, id)
	end
	Cultivation.pushState(player)
	return true
end

local function reachedGivenAt(data: PlayerData.Data): boolean
	local first = Realms.get(Pacing.GIVEN_AT, 1)
	return first ~= nil and Realms.index(data.realm.major, data.realm.minor) >= Realms.index(first.major, first.minor)
end

-- Give a random starter for the player's root once they've reached Foundation
-- and still use Sect Breathing. Safe to call any time.
function Methods.giveStarter(player: Player)
	local data = PlayerData.get(player)
	if not (data and data.methods.active == "" and reachedGivenAt(data)) then
		return
	end
	local options = MethodDefs.starters(data.root.element)
	local def = options[rng:NextInteger(1, #options)]
	if Methods.grant(player, def.id) then
		Cultivation.notify(
			player,
			`Elder Qingyun: "The sect's breathing can take you no further. Cultivate the {def.name} from now on."`
		)
	end
end

-- CultivationAction "method": make an owned method active (while meditating).
function Methods.switch(player: Player, id: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	if type(id) ~= "string" or not data.methods.owned[id] then
		return false, "You don't know that method"
	end
	if data.methods.active == id then
		return true, nil
	end
	if not (Cultivation.meditation and Cultivation.meditation(player)) then
		return false, "Sit and meditate to change your method"
	end
	data.methods.active = id
	Cultivation.notify(player, `You now cultivate the {MethodDefs.Defs[id].name}.`)
	Cultivation.pushState(player)
	return true, nil
end

return Methods
