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
local Meditation = require(script.Parent.Meditation)
local Sprint = require(script.Parent.Sprint)

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")
local Movement = {}
local lastHumanoid: Humanoid?
local jumpWasEnabled: boolean? = nil

-- Shift lock turning (rates per second, exponential): moving, the body comes
-- round fast; standing, a beat behind the head. Past HEAD_LIMIT the body is
-- dragged with the camera, so the head never twists further than it can.
local BODY_TURN = 14
local STAND_TURN = 9
local HEAD_LIMIT = math.rad(95)
-- the forward share of the move (along the camera) past which the body faces the way
-- it walks instead of the camera: cos 60 deg, so W diagonals (0.71) face the move and
-- A / D alone (0) strafe; it matches Strafe's LATERAL_START (sin 60 = 0.87)
local FACE_MOVE_FORWARD = 0.5

local function yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end

-- the signed yaw from the root's facing to `look`, -pi..pi (nil if `look` is vertical)
local function yawGap(root: BasePart, look: Vector3): number?
	if Vector3.new(look.X, 0, look.Z).Magnitude < 0.01 then
		return nil
	end
	return (yawOf(look) - yawOf(root.CFrame.LookVector) + math.pi) % (2 * math.pi) - math.pi
end

local function turnToward(root: BasePart, look: Vector3, rate: number, dt: number)
	local gap = yawGap(root, look)
	if not gap or math.abs(gap) < 1e-3 then
		return
	end
	local yaw = yawOf(root.CFrame.LookVector) + gap * (1 - math.exp(-rate * math.min(dt, 0.1)))
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
end

local function dragWithin(root: BasePart, look: Vector3, limit: number)
	local gap = yawGap(root, look)
	if not gap or math.abs(gap) <= limit then
		return
	end
	local yaw = yawOf(root.CFrame.LookVector) + gap - math.sign(gap) * limit
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
end

local function step(dt: number)
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
	local crowd = humanoid:GetAttribute("CCMove")
	local crowdLocked = ActionState.crowdLocked()
	humanoid.WalkSpeed = (base + (if running then Config.Movement.RUN_BONUS else 0)) * multiplier
		* (if ActionState.crowdKind() and type(crowd) == "number" then crowd else 1)
		* (if type(humanoid:GetAttribute("SlowMove")) == "number" then humanoid:GetAttribute("SlowMove") :: number else 1)
	local committed = phase == "windup" or phase == "active" or crowdLocked
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
	elseif crowdLocked then
		humanoid.AutoRotate = false -- reeling: no steering
	elseif Meditation.isActive() then
		-- seated: keep the facing you sat down with, even in shift lock
		humanoid.AutoRotate = false
	elseif locked and not running then
		humanoid.AutoRotate = false
		local offset = (locked:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + offset)
		end
	elseif ActionState.guardFacing and not running then
		-- guarding: face the beast coming at you, not the way you walk (GuardController)
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + ActionState.guardFacing)
	else
		local camera = workspace.CurrentCamera
		local firstPerson = camera ~= nil and (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5
		local shoulderLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and not firstPerson
		if shoulderLock and not running and camera then
			-- Shift lock: the body turns toward the camera at a rate instead of
			-- snapping onto it (husspotato7, user 2026-10-24), so strafing eases in
			-- as the body comes round; the head is already on the camera (HeadLook).
			humanoid.AutoRotate = false
			gameSettings.RotationType = Enum.RotationType.MovementRelative
			local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
			local moving = move.Magnitude > 0.1
			-- Walking forward or forward-diagonal (W, W+A, W+D), the body faces the way
			-- it walks (user, 2026-10-24); straight sideways (A, D: strafe) and
			-- backwards (S, S+A, S+D: back walk) it keeps facing the camera.
			local face = camera.CFrame.LookVector
			local ahead = Vector3.new(face.X, 0, face.Z)
			if moving and ahead.Magnitude > 0.01 and move.Unit:Dot(ahead.Unit) > FACE_MOVE_FORWARD then
				face = move
			end
			turnToward(root, face, if moving then BODY_TURN else STAND_TURN, dt)
			dragWithin(root, camera.CFrame.LookVector, HEAD_LIMIT)
		else
			humanoid.AutoRotate = true
			gameSettings.RotationType = if firstPerson and not running
				then Enum.RotationType.CameraRelative else Enum.RotationType.MovementRelative
		end
	end
end

function Movement.init()
	RunService:BindToRenderStep("CharacterMovement", Enum.RenderPriority.Camera.Value + 4, step)
end

return Movement
