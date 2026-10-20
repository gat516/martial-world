--!strict
-- Server entry: peak assignment, profile load/save, and remote wiring.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Cultivation = require(script.Parent.Cultivation)
local Garden = require(script.Parent.Garden)
local Build = require(script.Parent.Build)

local remotes = ReplicatedStorage.Remotes

-- Peak spawn pads are disabled so nobody spawns on someone else's peak;
-- move each character home ourselves instead.
local function sendHome(player: Player, character: Model)
	local peak = Peaks.ownedBy(player)
	local pad = peak and peak:FindFirstChild("SpawnLocation") :: BasePart?
	if pad then
		character:PivotTo(pad.CFrame + Vector3.new(0, Config.Spawn.HEIGHT, 0))
	end
end

local function onPlayerAdded(player: Player)
	local peak = Peaks.assign(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(sendHome, player, character)
	end)
	if player.Character then
		task.defer(sendHome, player, player.Character)
	end
	Cultivation.watch(player)

	local data = PlayerData.load(player)
	if player.Parent == nil then
		PlayerData.release(player)
		Peaks.release(player)
		return
	end
	if peak then
		Peaks.applyLayout(player, data)
		Garden.apply(player, data)
	else
		warn(`No free peak for {player.Name}; all peaks are taken`)
	end
	Cultivation.pushState(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
	Peaks.release(player)
	Build.forget(player)
end)

local function guarded(fn: (Player, ...any) -> (boolean, string?))
	return function(player: Player, ...): (boolean, string?)
		local ok, success, message = pcall(fn, player, ...)
		if not ok then
			warn(`Remote error for {player.Name}: {success}`)
			return false, "Something went wrong"
		end
		return success, message
	end
end

(remotes.BuildAction :: RemoteFunction).OnServerInvoke = guarded(Build.handle);

(remotes.GardenAction :: RemoteFunction).OnServerInvoke = guarded(function(player, action, plotId, herbId)
	if action == "plant" then
		return Garden.plant(player, plotId, herbId)
	elseif action == "harvest" then
		return Garden.harvest(player, plotId)
	end
	return false, "Unknown action"
end);

(remotes.InventoryAction :: RemoteFunction).OnServerInvoke = guarded(function(player, action, herbId)
	if action == "eat" and type(herbId) == "string" then
		return Cultivation.eat(player, herbId)
	end
	return false, "Unknown action"
end)
