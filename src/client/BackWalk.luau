--!strict
-- The back walk (ReplicatedStorage.Animations.BackWalk, 104669778380585, user
-- 2026-10-24) while the local character walks backwards under shift lock (the
-- mouse held at the centre, not first person). Under shift lock the body turns to
-- face the way it moves (Movement): forward, sideways and the W diagonals face the
-- move and use the walk; S and the S diagonals turn their back to the move, and
-- this plays, so the legs always run along the move. No strafes (user, 2026-10-24).
-- Without shift lock the body faces the way it walks, so this never plays, and
-- turning shift lock off fades it out.
--
-- Blended, not switched: its weight follows how far the move points behind the
-- body (none below BACK_START, full from BACK_FULL), smoothed at WEIGHT_RATE, over
-- Animate's walk underneath, so the body turning round eases it in and out.
-- Movement priority, the same as the walk and Sprint's Run; out while running, in
-- the air or seated. WeaponAnimator pauses a weapon class's own walk while it's
-- mostly in. Actions (Action priority) stay on top. The owner's tracks replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Sprint = require(script.Parent.Sprint)

local player = Players.LocalPlayer

local CLIP_SPEED = 16 -- studs/s the clip is keyed at (a normal walk)
local BACK_START = 0.3 -- share of the move pointing behind the body where it starts to show...
local BACK_FULL = 0.7 -- ...and where it's all back walk
local WEIGHT_RATE = 10 -- how fast its weight follows (per second, exponential)
local SHOWN = 0.5 -- counts as playing (BackWalk.active) above this weight
local OFF = 0.01

local BackWalk = {}

local humanoid: Humanoid? = nil
local track: AnimationTrack? = nil
local weight = 0

local function clear()
	if track then
		track:Stop(0)
		track:Destroy()
	end
	track = nil
	weight = 0
end

local function onCharacter(character: Model)
	clear()
	humanoid = nil
	local h = character:WaitForChild("Humanoid") :: Humanoid
	local animator = h:WaitForChild("Animator") :: Animator
	local animation = (ReplicatedStorage:WaitForChild("Animations") :: Folder):FindFirstChild("BackWalk")
	if player.Character ~= character or not (animation and animation:IsA("Animation") and animation.AnimationId ~= "") then
		return
	end
	local t = animator:LoadAnimation(animation)
	t.Priority = Enum.AnimationPriority.Movement
	t.Looped = true
	track = t
	humanoid = h
end

-- Whether the back walk is mostly in.
function BackWalk.active(): boolean
	return weight > SHOWN
end

local function shiftLocked(): boolean
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		return false
	end
	local camera = workspace.CurrentCamera
	return not (camera and (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5) -- first person
end

local function step(dt: number)
	local h, t = humanoid, track
	local root = h and h.RootPart
	if not (h and t and root) then
		return
	end
	local want, speed = 0, 0
	if h.Parent == player.Character and h.Health > 0 then
		speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local grounded = h.FloorMaterial ~= Enum.Material.Air and not h.Sit
		local move = root.CFrame:VectorToObjectSpace(h.MoveDirection * Vector3.new(1, 0, 1))
		if shiftLocked() and grounded and speed > 1 and move.Magnitude > 0.1 and not Sprint.isRunning() then
			-- +Z in facing space is behind the body
			local x = math.clamp((move.Z / move.Magnitude - BACK_START) / (BACK_FULL - BACK_START), 0, 1)
			want = x * x * (3 - 2 * x)
		end
	end
	weight += (want - weight) * (1 - math.exp(-WEIGHT_RATE * math.min(dt, 0.1)))
	if weight < OFF and want == 0 then
		weight = 0
	end
	if weight > 0 then
		if not t.IsPlaying then
			t:Play(0, OFF)
		end
		t:AdjustWeight(weight, 0)
		t:AdjustSpeed(math.clamp(speed / CLIP_SPEED, 0.5, 1.5))
	elseif t.IsPlaying then
		t:Stop(0.1)
	end
end

function BackWalk.init()
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

return BackWalk
