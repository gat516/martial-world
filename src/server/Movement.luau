--!strict
-- Stat changes and actions feed the same speed calculation. Updating a herb
-- buff must not restore running speed in the middle of a rooted cast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Movement = {}

function Movement.apply(humanoid: Humanoid)
	local base = humanoid:GetAttribute("BaseWalkSpeed") or Config.Cultivation.BASE_WALKSPEED
	local multiplier = humanoid:GetAttribute("ActionMoveMultiplier") or 1
	local running = humanoid:GetAttribute("Running") and not humanoid:GetAttribute("ActionBusy") and not humanoid:GetAttribute("CCLock")
	local crowdControl = humanoid:GetAttribute("CCMove") or 1 -- flinch, stagger, stun (PlayerStun)
	humanoid.WalkSpeed = (base + (if running then Config.Movement.RUN_BONUS else 0)) * multiplier * crowdControl
end

function Movement.action(humanoid: Humanoid, multiplier: number, busy: boolean)
	if humanoid:GetAttribute("ActionMoveMultiplier") ~= multiplier then
		humanoid:SetAttribute("ActionMoveMultiplier", multiplier)
	end
	if humanoid:GetAttribute("ActionBusy") ~= busy then
		humanoid:SetAttribute("ActionBusy", busy)
	end
	if busy and humanoid:GetAttribute("Running") then
		humanoid:SetAttribute("Running", false)
	end
	Movement.apply(humanoid)
end

return Movement
