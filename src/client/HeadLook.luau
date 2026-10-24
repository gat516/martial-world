--!strict
-- Heads that follow where each player looks (pattern from the husspotato7
-- reference, user 2026-10-24), layered onto the neck's C0 so every animation
-- keeps playing underneath (the Animator owns Transform, not C0).
--   Your own head follows your camera: locked tight onto it while shift lock
--   holds the mouse (the body is turning to catch up, Movement), eased otherwise.
--   Past sideways it keeps looking, then eases back to the front as the camera
--   comes round behind you (150-180 degrees), so it never flips sides.
--   Your look goes to the server (Look remote, at most SEND_RATE a second and only
--   when it moved), which puts it on your character as Look = Vector2(pitch, yaw);
--   every other client eases your head toward it, within MAX_DISTANCE of its camera.
-- The rest offset follows the body's scale (a Titan Frame body is scaled after
-- spawn and Model:ScaleTo scales the neck), so a stale offset can't sink the head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HerbAnimator = require(script.Parent.HerbAnimator)

local player = Players.LocalPlayer

local MAX_YAW = math.rad(100) -- left / right
local MAX_PITCH = math.rad(55) -- up / down
local FORWARD_BLEND_START = math.rad(150) -- looking further round than this eases back to the front
local SHARPNESS = 10 -- your own head, free camera
local LOCKED_SHARPNESS = 40 -- your own head under shift lock: all but locked onto the camera
local OTHERS_SHARPNESS = 12 -- other players' heads toward their sent look
local SEND_RATE = 5 -- looks sent a second, at most
local SEND_MIN_CHANGE = 0.04 -- radians it must move before it's sent again
local MAX_DISTANCE = 160 -- other players' heads further than this from your camera aren't animated

local HeadLook = {}

type Rig = { neck: Motor6D, rest: CFrame, scale: number, body: Model, yaw: number, pitch: number }

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local sentPitch, sentYaw, sentAt = 0, 0, 0
local lookRemote: RemoteEvent? = nil

local function rigOf(character: Model): Rig?
	local rig = rigs[character]
	if rig and rig.neck.Parent then
		return rig
	end
	local head = character:FindFirstChild("Head")
	local joint = character:FindFirstChild("Neck", true)
	if not (head and joint and joint:IsA("Motor6D") and joint.Part1 == head) then
		return nil
	end
	rig = { neck = joint, rest = joint.C0, scale = character:GetScale(), body = character, yaw = 0, pitch = 0 }
	rigs[character] = rig
	return rig
end

local function pose(rig: Rig)
	-- in torso axes before the rig's joint orientation, so R6 and R15 agree
	local scale = rig.body:GetScale() / rig.scale
	rig.neck.C0 = CFrame.new(rig.rest.Position * scale) * CFrame.Angles(rig.pitch, rig.yaw, 0) * rig.rest.Rotation
end

local function ease(rig: Rig, pitch: number, yaw: number, sharpness: number, dt: number)
	local alpha = 1 - math.exp(-sharpness * dt)
	rig.yaw += (yaw - rig.yaw) * alpha
	rig.pitch += (pitch - rig.pitch) * alpha
	pose(rig)
end

-- Your own target: the camera, relative to the torso.
local function myTarget(h: Humanoid, torso: BasePart): (number, number)
	local camera = workspace.CurrentCamera
	if not (camera and camera.CameraSubject == h and h.Health > 0 and not HerbAnimator.isEating()) then
		return 0, 0
	end
	local look = torso.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local cameraYaw = math.atan2(-look.X, -look.Z)
	-- keep looking sideways past 90 degrees, then fade forward over 150-180, which
	-- also avoids flipping sides when the yaw wraps at 180
	local blend = math.clamp((math.pi - math.abs(cameraYaw)) / (math.pi - FORWARD_BLEND_START), 0, 1)
	local weight = blend * blend * (3 - 2 * blend)
	return math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -MAX_PITCH, MAX_PITCH) * weight,
		math.clamp(cameraYaw, -MAX_YAW, MAX_YAW) * weight
end

local function send(pitch: number, yaw: number)
	local now = os.clock()
	if not lookRemote or now - sentAt < 1 / SEND_RATE then
		return
	end
	if math.abs(pitch - sentPitch) < SEND_MIN_CHANGE and math.abs(yaw - sentYaw) < SEND_MIN_CHANGE then
		return
	end
	sentPitch, sentYaw, sentAt = pitch, yaw, now
	lookRemote:FireServer(pitch, yaw)
end

-- Your own head, after the camera and the body's turn this frame, so it lines up with what you see.
local function stepMine(dt: number)
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	local rig = character and rigOf(character)
	local torso = rig and rig.neck.Part0
	if not (h and rig and torso) then
		return
	end
	local pitch, yaw = myTarget(h, torso)
	local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	ease(rig, pitch, yaw, if locked then LOCKED_SHARPNESS else SHARPNESS, dt)
	send(pitch, yaw)
end

-- Everyone else's heads, from their Look attribute.
local function stepOthers(dt: number)
	local camera = workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else Vector3.zero
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if other ~= player and character then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local h = character:FindFirstChildOfClass("Humanoid")
			if root and h and (root.Position - from).Magnitude <= MAX_DISTANCE then
				local rig = rigOf(character)
				if rig then
					local look = character:GetAttribute("Look")
					local alive = h.Health > 0
					local pitch = if typeof(look) == "Vector2" and alive then look.X else 0
					local yaw = if typeof(look) == "Vector2" and alive then look.Y else 0
					ease(rig, pitch, yaw, OTHERS_SHARPNESS, math.min(dt, 0.1))
				end
			end
		end
	end
end

function HeadLook.init()
	lookRemote = (ReplicatedStorage:WaitForChild("Remotes") :: Folder):FindFirstChild("Look") :: RemoteEvent?
	player.CharacterAdded:Connect(function()
		sentPitch, sentYaw, sentAt = 0, 0, 0
	end)
	RunService:BindToRenderStep("HeadLook", Enum.RenderPriority.Camera.Value + 5, stepMine)
	RunService.RenderStepped:Connect(stepOthers)
end

return HeadLook
