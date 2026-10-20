--!strict
-- Hold Shift to run. Native movement-relative rotation turns smoothly, even in shift lock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Movement
local BuildMode = require(script.Parent.BuildMode)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local LockOn = require(script.Parent.LockOn)
local Meditation = require(script.Parent.Meditation)
local Menus = require(script.Parent.Menus)

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")
local remote = ReplicatedStorage.Remotes:WaitForChild("Sprint") :: RemoteEvent
local animation = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Run") :: Animation
local BLEND = 0.15

local Sprint = {}
local held: { [Enum.KeyCode]: boolean } = {}
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local track: AnimationTrack? = nil
local running = false
local movementFacing = false
local turningPausedUntil = 0

local function setMovementFacing(on: boolean)
	if movementFacing == on then
		return
	end
	movementFacing = on
	LockOn.setMovementFacing(on)
	if not on and humanoid then
		humanoid.AutoRotate = LockOn.target() == nil
	end
end

-- Give an attack or directional dash control of facing until its movement ends.
function Sprint.pauseTurning(seconds: number)
	turningPausedUntil = math.max(turningPausedUntil, os.clock() + seconds)
	setMovementFacing(false)
end

local function setRunning(on: boolean)
	if running == on then
		return
	end
	running = on
	if not on then
		setMovementFacing(false)
	end
	remote:FireServer(on)
	if not on and track then
		track:Stop(BLEND)
	end
end

local function onCharacter(character: Model)
	setRunning(false)
	if track then
		track:Destroy()
		track = nil
	end
	humanoid, root = nil, nil
	turningPausedUntil = 0
	local nextHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	local nextRoot = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = nextHumanoid:WaitForChild("Animator") :: Animator
	if character ~= player.Character then
		return
	end
	humanoid, root = nextHumanoid, nextRoot
	local runTrack = animator:LoadAnimation(animation)
	runTrack.Priority = Enum.AnimationPriority.Movement
	runTrack.Looped = true
	track = runTrack
end

local function step()
	local h, r, runTrack = humanoid, root, track
	if not h or not r or not runTrack then
		setRunning(false)
		return
	end
	local state = h:GetState()
	local movable = state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.Landed
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
	local direction = h.MoveDirection * Vector3.new(1, 0, 1)
	local on = next(held) ~= nil
		and h.Health > 0
		and r.Parent ~= nil
		and not h.Sit
		and movable
		and direction.Magnitude > 0.1
		and UserInputService:GetFocusedTextBox() == nil
		and not Menus.isOpen()
		and not BuildMode.isActive()
		and not Meditation.isActive()
		and not CirculationMinigame.isRunning()
	setRunning(on)
	setMovementFacing(on and os.clock() >= turningPausedUntil)
	if not on then
		return
	end

	local speed = (r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	if h.FloorMaterial ~= Enum.Material.Air and speed > 1 then
		if not runTrack.IsPlaying then
			runTrack:Play(BLEND)
		end
		runTrack:AdjustSpeed(math.clamp(speed / Config.RUN_ANIMATION_SPEED, 0.5, 2))
	elseif runTrack.IsPlaying then
		runTrack:Stop(BLEND) -- leave jumping/falling to the default character animator
	end
end

function Sprint.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift) then
			held[input.KeyCode] = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		held[input.KeyCode] = nil
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(held)
		setRunning(false)
	end)
	player.CharacterRemoving:Connect(function()
		table.clear(held)
		setRunning(false)
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	-- Decide before the camera/lock-on so they see who owns facing this frame.
	RunService:BindToRenderStep("SprintState", Enum.RenderPriority.Input.Value + 1, step)
	RunService:BindToRenderStep("SprintFacing", Enum.RenderPriority.Camera.Value + 4, function()
		local camera = workspace.CurrentCamera
		local firstPerson = camera ~= nil and (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5
		local freeCamera = UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
			and not firstPerson
			and LockOn.target() == nil
		-- Alt can change during a run. Use the current camera mode instead of restoring
		-- a saved CameraRelative value that would leave normal movement camera-facing.
		if movementFacing or freeCamera then
			gameSettings.RotationType = Enum.RotationType.MovementRelative
		end
		if movementFacing and humanoid then
			humanoid.AutoRotate = true
		end
	end)
end

return Sprint
