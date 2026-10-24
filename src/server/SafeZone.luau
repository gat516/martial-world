--!strict
-- Safe zones (docs/systems/party.md#safe-zones): the sect's grounds (Gates.inSect:
-- the plaza and the paths between) and every spirit peak, yours or one you're
-- visiting. The one definition of "safe ground": Haul banks there (plus on any
-- teleport array, Haul.safeAt), and the People tile shows only there. The server
-- keeps the player attribute `InSafeZone` current (CHECK_SECONDS) for the client.
-- The testbed has no sect: only the ring around the spawn pad, where the TestPeak
-- sits, counts (Pacing.SafeZone TESTBED_RADIUS).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gates = require(ReplicatedStorage.Shared.Gates)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Tuning = require(ReplicatedStorage.Shared.Pacing).SafeZone

local CHECK_SECONDS = 0.5

local SafeZone = {}

local function testbedHome(): Vector3
	local arena = workspace:FindFirstChild("Arena")
	local pad = arena and arena:FindFirstChild("SpawnPad")
	return if pad and pad:IsA("BasePart") then pad.Position else Vector3.new(0, 649.1, 40)
end

-- The spirit peak whose build area holds `position`, or nil.
function SafeZone.peakAt(position: Vector3): Model?
	local map = workspace:FindFirstChild("Map")
	local sect = map and map:FindFirstChild("Sect")
	local folder = sect and sect:FindFirstChild("SpiritPeaks")
	if not folder then
		return nil
	end
	for _, peak in folder:GetChildren() do
		if peak:IsA("Model") and peak:FindFirstChild("Plateau") then
			local here = Peak.frame(peak):PointToObjectSpace(position)
			if Peak.inBounds(here, Peak.radius(peak)) then
				return peak
			end
		end
	end
	return nil
end

-- Whether `position` is in a safe zone.
function SafeZone.at(position: Vector3): boolean
	if Config.TESTBED then
		local home = testbedHome()
		return Vector2.new(position.X - home.X, position.Z - home.Z).Magnitude <= Tuning.TESTBED_RADIUS
	end
	return Gates.inSect(position) or SafeZone.peakAt(position) ~= nil
end

-- Whether the player's character stands in a safe zone.
function SafeZone.contains(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and SafeZone.at(root.Position)
end

function SafeZone.start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local inside = SafeZone.contains(player)
				if player:GetAttribute("InSafeZone") ~= inside then
					player:SetAttribute("InSafeZone", inside)
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return SafeZone
