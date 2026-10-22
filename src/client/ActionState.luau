--!strict
-- Shared local prediction read by combat, sprint, facing and auto-approach.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.ActionRules)

local Players = game:GetService("Players")

local ActionState = {
	current = Rules.new(),
	basicHeld = false,
	blocked = false,
	guarding = false, -- GuardController: the guard is up (predicted)
	facing = Vector3.zAxis,
}

function ActionState.phase(): string
	return Rules.phase(ActionState.current.action, workspace:GetServerTimeNow())
end

-- Crowd control on the local character (PlayerStun): "flinch" | "stagger" | "stun" | nil.
function ActionState.crowdKind(): string?
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local kind = humanoid and humanoid:GetAttribute("CCKind")
	local endsAt = humanoid and humanoid:GetAttribute("CCEnd")
	if type(kind) == "string" and type(endsAt) == "number" and workspace:GetServerTimeNow() < endsAt then
		return kind
	end
	return nil
end

-- Staggered or stunned: no attacking, dodging, casting, sprinting or jumping.
function ActionState.crowdLocked(): boolean
	local kind = ActionState.crowdKind()
	return kind == "stagger" or kind == "stun"
end

function ActionState.canSprint(): boolean
	return not ActionState.blocked and not ActionState.guarding and not ActionState.basicHeld and ActionState.phase() == "free" and not ActionState.crowdLocked()
end

function ActionState.locksFacing(): boolean
	local phase = ActionState.phase()
	return phase == "windup" or phase == "active"
end

function ActionState.canApproach(): boolean
	return not ActionState.blocked and not ActionState.guarding and ActionState.phase() == "free" and not ActionState.crowdLocked()
end

return ActionState
