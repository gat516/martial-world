--!strict
-- Shared local prediction read by combat, sprint, facing and auto-approach.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.ActionRules)

local ActionState = {
	current = Rules.new(),
	basicHeld = false,
	blocked = false,
	facing = Vector3.zAxis,
}

function ActionState.phase(): string
	return Rules.phase(ActionState.current.action, workspace:GetServerTimeNow())
end

function ActionState.canSprint(): boolean
	return not ActionState.blocked and not ActionState.basicHeld and ActionState.phase() == "free"
end

function ActionState.locksFacing(): boolean
	local phase = ActionState.phase()
	return phase == "windup" or phase == "active"
end

function ActionState.canApproach(): boolean
	return not ActionState.blocked and ActionState.phase() == "free"
end

return ActionState
