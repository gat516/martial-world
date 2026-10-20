--!strict
-- Closes the Spirit Market windows (the Herbalist, the build shop) once you walk
-- out of trading range of the stall: Build.MARKET_RANGE, the same range the
-- server checks every trade against.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Build

local player = Players.LocalPlayer

local CHECK_EVERY = 0.25 -- seconds

local MarketRange = {}

type Watch = { isOpen: () -> boolean, close: () -> () }

local watches: { Watch } = {}
local elapsed = 0

function MarketRange.near(): boolean
	local hub = workspace:FindFirstChild("Hub")
	local market = hub and hub:FindFirstChild("SpiritMarket") :: Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return market ~= nil and root ~= nil and (root.Position - market:GetPivot().Position).Magnitude <= Config.MARKET_RANGE
end

-- Call close() whenever isOpen() is true and you're out of range.
function MarketRange.watch(isOpen: () -> boolean, close: () -> ())
	table.insert(watches, { isOpen = isOpen, close = close })
	if #watches > 1 then
		return
	end
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		local near: boolean? = nil
		for _, w in watches do
			if w.isOpen() then
				if near == nil then
					near = MarketRange.near()
				end
				if not near then
					w.close()
				end
			end
		end
	end)
end

return MarketRange
