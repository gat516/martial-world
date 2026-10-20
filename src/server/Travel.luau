--!strict
-- Teleport formations: from anywhere to your own peak, the main peak plaza or the
-- sect gate. Blocked for a few seconds after taking damage, so it can't be used
-- to escape a fight mid-attack.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(script.Parent.Combat)
local Peaks = require(script.Parent.Peaks)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)

local lastTravel: { [Player]: number } = {}

local Travel = {}

local function destination(player: Player, where: any): CFrame?
	if where == "Peak" then
		local peak = Peaks.ownedBy(player)
		return peak and Peaks.homeCFrame(peak)
	elseif where == "MainPeak" then
		return CFrame.new(Config.Travel.MAIN_PEAK)
	elseif where == "SectGate" then
		local at = Config.Travel.SECT_GATE
		return CFrame.lookAt(at, at + Vector3.zAxis)
	end
	return nil
end

function Travel.go(player: Player, where: any): (boolean, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid and humanoid.Health > 0) then
		return false, "You can't travel right now"
	end
	local data = PlayerData.get(player)
	if data and not Quests.travelUnlocked(data) then
		return false, "The elder hasn't taught you the teleport formation yet."
	end
	if humanoid:GetAttribute("ActionBusy") or Combat.inCombat(player) then
		return false, "You can't form the array mid-fight."
	end
	local now = os.clock()
	if now - (lastTravel[player] or -math.huge) < Config.Travel.COOLDOWN then
		return false, "The formation is still recharging."
	end
	local target = destination(player, where)
	if not target then
		return false, "Unknown destination"
	end
	lastTravel[player] = now
	character:PivotTo(target)
	return true, nil
end

function Travel.forget(player: Player)
	lastTravel[player] = nil
end

return Travel
