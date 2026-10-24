--!strict
-- Strafe clips (ReplicatedStorage.Animations.Strafe.Left / .Right / .Back, user
-- 2026-10-24) while the local character walks sideways, or backwards, under shift lock (the
-- mouse held at the centre, not first person). Only then (user, 2026-10-24):
-- without shift lock the body turns to face the way it walks, so there's nothing
-- to strafe, and turning off shift lock fades any strafe out.
--
-- Directions (user, 2026-10-24): W and W+A / W+D walk forward (the walk under
-- this); A or D alone strafes; S and S+A / S+D walk backwards (Back).
-- Blended, not switched: each clip's weight follows the move's angle to the
-- facing (LATERAL_*, BACK_*), smoothed at WEIGHT_RATE, over the walk underneath. Under shift lock the body turns toward the camera at
-- a rate (Movement), so as it comes round the move turns sideways and the strafe
-- eases in with it instead of snapping (husspotato7 reference).
--
-- Layering: Movement priority, the same as the walk and Sprint's Run, over
-- Animate's Core walk. It fades out while running (the run owns that), in the
-- air or seated. WeaponAnimator pauses a weapon class's own walk while a strafe
-- is mostly in. Attacks, casts, dodges and the guard play at Action priority and
-- stay on top. Tracks played by the owner replicate, so others see the strafe too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Sprint = require(script.Parent.Sprint)

local player = Players.LocalPlayer

local CLIP_SPEED = 16 -- studs/s the clips are keyed at (a normal walk)
local LATERAL_START = 0.87 -- sideways share of the move (in facing space) where a strafe starts to show (~60 deg)...
local LATERAL_FULL = 0.97 -- ...and where it's all strafe (~76 deg); a diagonal (0.71) never strafes
local BACK_START = 0.17 -- backward share where the back walk starts to show (~80 deg off forward)...
local BACK_FULL = 0.42 -- ...and where it's all back walk (~65 deg), so S+A / S+D are back walk

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local WEIGHT_RATE = 10 -- how fast a strafe's weight follows (per second, exponential)
local SHOWN = 0.5 -- a strafe counts as playing (Strafe.side) above this weight
local OFF = 0.01

local Strafe = {}

local humanoid: Humanoid? = nil
local tracks: { [string]: AnimationTrack } = {}
local weights: { [string]: number } = {}
local side: string? = nil -- "Left" | "Right" while one is mostly in

local function clear()
	for _, track in tracks do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(tracks)
	table.clear(weights)
	side = nil
end

local function onCharacter(character: Model)
	clear()
	humanoid = nil
	local h = character:WaitForChild("Humanoid") :: Humanoid
	local animator = h:WaitForChild("Animator") :: Animator
	local folder = (ReplicatedStorage:WaitForChild("Animations") :: Folder):FindFirstChild("Strafe")
	if player.Character ~= character or not folder then
		return
	end
	for _, name in { "Left", "Right", "Back" } do
		local animation = folder:FindFirstChild(name)
		if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Movement
			track.Looped = true
			tracks[name] = track
			weights[name] = 0
		end
	end
	humanoid = h
end

-- The direction being strafed ("Left" | "Right" | "Back", its clip mostly in), or nil.
function Strafe.side(): string?
	return side
end

local function shiftLocked(): boolean
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		return false
	end
	local camera = workspace.CurrentCamera
	return not (camera and (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5) -- first person
end

local function step(dt: number)
	local h = humanoid
	local root = h and h.RootPart
	local want: { [string]: number } = { Left = 0, Right = 0, Back = 0 }
	local speed = 0
	if h and root and h.Parent == player.Character and h.Health > 0 then
		speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local grounded = h.FloorMaterial ~= Enum.Material.Air and not h.Sit
		local move = root.CFrame:VectorToObjectSpace(h.MoveDirection * Vector3.new(1, 0, 1))
		if shiftLocked() and grounded and speed > 1 and move.Magnitude > 0.1 and not Sprint.isRunning() then
			-- Directions (user, 2026-10-24): A or D alone strafes; W+A / W+D keeps the
			-- forward walk and S+A / S+D the back walk. A side clip comes in only when
			-- the move is nearly square to the facing (diagonals are ~0.71 sideways)...
			local side = smooth((math.abs(move.X) / move.Magnitude - LATERAL_START) / (LATERAL_FULL - LATERAL_START))
			want[if move.X > 0 then "Right" else "Left"] = side
			-- ...and the back walk takes whatever backward move the side clip doesn't
			-- (+Z in facing space is backwards), so S and S+A / S+D are all back walk.
			local back = smooth((move.Z / move.Magnitude - BACK_START) / (BACK_FULL - BACK_START))
			want.Back = back * (1 - side)
		end
	end
	local alpha = 1 - math.exp(-WEIGHT_RATE * math.min(dt, 0.1))
	side = nil
	for name, track in tracks do
		local weight = weights[name] + (want[name] - weights[name]) * alpha
		if weight < OFF and want[name] == 0 then
			weight = 0
		end
		weights[name] = weight
		if weight > 0 then
			if not track.IsPlaying then
				track:Play(0, OFF)
			end
			track:AdjustWeight(weight, 0)
			track:AdjustSpeed(math.clamp(speed / CLIP_SPEED, 0.5, 1.5))
			if weight > SHOWN then
				side = name
			end
		elseif track.IsPlaying then
			track:Stop(0.1)
		end
	end
end

function Strafe.init()
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		humanoid = nil
		clear()
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.Heartbeat:Connect(step)
end

return Strafe
