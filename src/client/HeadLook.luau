--!strict
-- Local camera look, layered onto the neck without changing body movement.
-- Looking back toward the character returns the head to its forward pose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local MAX_YAW = math.rad(65)
local MAX_PITCH = math.rad(25)
local SHARPNESS = 10

local HeadLook = {}
local humanoid: Humanoid? = nil
local neck: Motor6D? = nil
local baseC0: CFrame? = nil
local yaw, pitch = 0, 0

local function clear()
	if neck and neck.Parent and baseC0 then
		neck.C0 = baseC0
	end
	humanoid, neck, baseC0 = nil, nil, nil
	yaw, pitch = 0, 0
end

local function onCharacter(character: Model)
	clear()
	local nextHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart
	character:WaitForChild("HumanoidRootPart")
	if character ~= player.Character then
		return
	end
	local joint = character:FindFirstChild("Neck", true)
	if not joint or not joint:IsA("Motor6D") or joint.Part1 ~= head then
		return
	end
	humanoid, neck, baseC0 = nextHumanoid, joint, joint.C0
end

local function step(dt: number)
	local joint, rest, h = neck, baseC0, humanoid
	local torso = joint and joint.Part0
	if not joint or not joint.Parent or not rest or not torso or not h then
		return
	end
	local targetYaw, targetPitch = 0, 0
	local camera = workspace.CurrentCamera
	if camera and camera.CameraSubject == h and h.Health > 0 then
		local look = torso.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
		-- A camera looking into the character's face must not twist the head backward.
		if look.Z < 0 then
			targetYaw = math.clamp(math.atan2(-look.X, -look.Z), -MAX_YAW, MAX_YAW)
			targetPitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -MAX_PITCH, MAX_PITCH)
		end
	end
	local alpha = 1 - math.exp(-SHARPNESS * dt)
	yaw += (targetYaw - yaw) * alpha
	pitch += (targetPitch - pitch) * alpha
	-- Apply in torso axes before the rig's joint orientation, so R6 and R15 agree.
	-- Animator still owns Transform and can keep playing the run's head motion.
	joint.C0 = CFrame.new(rest.Position) * CFrame.Angles(pitch, yaw, 0) * rest.Rotation
end

function HeadLook.init()
	player.CharacterRemoving:Connect(clear)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("HeadLook", Enum.RenderPriority.Camera.Value + 5, step)
end

return HeadLook
