--!strict
-- Stat changes and actions feed the same speed calculation. Updating a herb
-- buff must not restore running speed in the middle of a rooted cast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Movement = {}

function Movement.apply(humanoid: Humanoid)
	local base = humanoid:GetAttribute("BaseWalkSpeed") or Config.Cultivation.BASE_WALKSPEED
	local multiplier = humanoid:GetAttribute("ActionMoveMultiplier") or 1
	-- no run bonus while guarding (Guard.luau keeps Guarding in step with the guard): the slow (Config.Combat.GUARD.MOVE)
	-- can't be sprinted around, whatever the client says about running
	local running = humanoid:GetAttribute("Running") and not humanoid:GetAttribute("ActionBusy") and not humanoid:GetAttribute("CCLock")
		and not humanoid:GetAttribute("Guarding")
	local crowdControl = humanoid:GetAttribute("CCMove") or 1 -- flinch, stagger, stun (PlayerStun)
	local slow = humanoid:GetAttribute("SlowMove") or 1 -- chill and webs (PlayerSlow)
	local speed = (base + (if running then Config.Movement.RUN_BONUS else 0)) * multiplier * crowdControl * slow
	if humanoid:GetAttribute("Guarding") then
		speed = math.min(speed, Config.Combat.GUARD.WALKSPEED) -- blocking walks slowly (stuns and slows can go lower)
	end
	humanoid.WalkSpeed = speed
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
