--!strict
-- Heads that follow where each player looks (pattern from the husspotato7
-- reference, user 2026-10-24), layered onto the neck's C0 so every animation
-- keeps playing underneath (the Animator owns Transform, not C0).
--   Your own head (user, 2026-10-24, "option 3": Huss's rules, natural limits):
--   under shift lock (or first person) it follows the camera closely, within
--   MAX_YAW / MAX_PITCH; with a free camera it eases forward and only glances
--   toward the camera (GLANCE_*), so walking doesn't swing it round; while the
--   guard, an attack or cast, or a lock-on holds the body's facing, it looks
--   where the body faces (at the beast), not at the camera.
--   Past sideways it eases back to the front as the camera comes round behind
--   you (150-180 degrees), so it never flips sides.
--   Your look goes to the server (Look remote, at most SEND_RATE a second and only
--   when it moved), which puts it on your character as Look = Vector2(pitch, yaw);
--   every other client eases your head toward it, within MAX_DISTANCE of its camera.
-- The rest offset follows the body's scale (a Titan Frame body is scaled after
-- spawn and Model:ScaleTo scales the neck), so a stale offset can't sink the head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ActionState = require(script.Parent.ActionState)
local HerbAnimator = require(script.Parent.HerbAnimator)
local LockOn = require(script.Parent.LockOn)

local player = Players.LocalPlayer

local MAX_YAW = math.rad(70) -- shift lock: left / right...
local MAX_PITCH = math.rad(30) -- ...and up / down (natural limits; user, 2026-10-24)
local GLANCE_YAW = math.rad(30) -- free camera: only a glance toward it...
local GLANCE_PITCH = math.rad(10) -- ...so walking doesn't swing the head round
local FORWARD_BLEND_START = math.rad(150) -- looking further round than this eases back to the front
local SHARPNESS = 6 -- your own head, free camera or held facing: eases
local LOCKED_SHARPNESS = 30 -- your own head under shift lock: close behind the camera
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
-- Whether the camera aims for the body (shift lock or first person): then the
-- head follows it to the full limits; otherwise it only glances.
local function aiming(camera: Camera): boolean
	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		or (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5
end

-- Something else owns where the body faces (the guard turns it to the beast,
-- an attack or cast, a lock-on): the head looks where the body does.
local function facingHeld(h: Humanoid): boolean
	return ActionState.guardFacing ~= nil or ActionState.guarding or h:GetAttribute("Guarding") == true
		or ActionState.locksFacing() or LockOn.target() ~= nil
end

-- Your own target, relative to the torso, and whether it's an aimed look.
local function myTarget(h: Humanoid, torso: BasePart): (number, number, boolean)
	local camera = workspace.CurrentCamera
	if not (camera and camera.CameraSubject == h and h.Health > 0 and not HerbAnimator.isEating()) then
		return 0, 0, false
	end
	if facingHeld(h) then
		return 0, 0, false
	end
	local look = torso.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local cameraYaw = math.atan2(-look.X, -look.Z)
	-- keep looking sideways past 90 degrees, then fade forward over 150-180, which
	-- also avoids flipping sides when the yaw wraps at 180
	local blend = math.clamp((math.pi - math.abs(cameraYaw)) / (math.pi - FORWARD_BLEND_START), 0, 1)
	local weight = blend * blend * (3 - 2 * blend)
	local aimed = aiming(camera)
	local maxYaw, maxPitch = if aimed then MAX_YAW else GLANCE_YAW, if aimed then MAX_PITCH else GLANCE_PITCH
	return math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -maxPitch, maxPitch) * weight,
		math.clamp(cameraYaw, -maxYaw, maxYaw) * weight, aimed
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
	local pitch, yaw, aimed = myTarget(h, torso)
	ease(rig, pitch, yaw, if aimed then LOCKED_SHARPNESS else SHARPNESS, dt)
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
