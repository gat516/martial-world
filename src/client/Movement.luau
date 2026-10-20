--!strict
-- The only local writer of character speed, jump permission and facing.
-- Camera lock remains independent of the action that owns character facing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.ActionRules)
local ActionState = require(script.Parent.ActionState)
local LockOn = require(script.Parent.LockOn)
local Sprint = require(script.Parent.Sprint)

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")
local Movement = {}
local lastHumanoid: Humanoid?
local jumpWasEnabled: boolean? = nil

local function step()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	if lastHumanoid ~= humanoid then
		lastHumanoid, jumpWasEnabled = humanoid, nil
	end
	local action = ActionState.current.action
	local now = workspace:GetServerTimeNow()
	local multiplier = Rules.movement(action, now)
	local phase = Rules.phase(action, now)
	local running = Sprint.isRunning() and ActionState.canSprint()
	local base = humanoid:GetAttribute("BaseWalkSpeed") or Config.Cultivation.BASE_WALKSPEED
	humanoid.WalkSpeed = (base + (if running then Config.Movement.RUN_BONUS else 0)) * multiplier
	local committed = phase == "windup" or phase == "active"
	if committed then
		if jumpWasEnabled == nil then
			jumpWasEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		humanoid.Jump = false
	elseif jumpWasEnabled ~= nil then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, jumpWasEnabled)
		jumpWasEnabled = nil
	end
	-- Rooted casts remove residual horizontal momentum without anchoring the rig
	-- or cancelling gravity. Dodge motion is driven separately by its impulses.
	if multiplier == 0 and action and action.kind ~= "dodge" then
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	end
	local locked = LockOn.target()
	if ActionState.locksFacing() then
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + ActionState.facing)
	elseif locked and not running then
		humanoid.AutoRotate = false
		local offset = (locked:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + offset)
		end
	else
		humanoid.AutoRotate = true
		local camera = workspace.CurrentCamera
		local firstPerson = camera ~= nil and (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5
		local freeCamera = UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter and not firstPerson
		gameSettings.RotationType = if running or freeCamera
			then Enum.RotationType.MovementRelative else Enum.RotationType.CameraRelative
	end
end

function Movement.init()
	RunService:BindToRenderStep("CharacterMovement", Enum.RenderPriority.Camera.Value + 4, step)
end

return Movement
