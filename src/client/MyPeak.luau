--!strict
-- The local player's assigned peak (the server sets the Peak / PeakFrame attributes).

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local peaksFolder = workspace:WaitForChild("Map"):WaitForChild("Sect"):WaitForChild("SpiritPeaks")

local MyPeak = {}

function MyPeak.model(): Model?
	local name = player:GetAttribute("Peak")
	return if type(name) == "string" then peaksFolder:FindFirstChild(name) :: Model? else nil
end

function MyPeak.frame(): CFrame?
	local f = player:GetAttribute("PeakFrame")
	return if typeof(f) == "CFrame" then f else nil
end

function MyPeak.owns(peak: Instance?): boolean
	return peak ~= nil and peak:GetAttribute("Owner") == tostring(player.UserId)
end

return MyPeak
