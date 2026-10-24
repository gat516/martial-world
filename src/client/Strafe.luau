--!strict
-- Strafe clips (ReplicatedStorage.Animations.Strafe.Left / .Right, user
-- 2026-10-24) while the local character walks sideways to where it faces.
-- That only happens while something holds the facing: lock-on, the guard's
-- facing, an action's facing (Humanoid.AutoRotate is off for all of them,
-- Movement), or the camera turning the body (shift lock, first person:
-- RotationType CameraRelative). With free movement the body turns to face the
-- way it walks, so sideways input never strafes and turning never flickers.
--
-- Layering: Movement priority, the same as the walk and Sprint's Run, played
-- over Animate's Core walk. It stops while running (the run owns that), in the
-- air, seated, or when the move is mostly forward or back (the walk plays).
-- WeaponAnimator pauses a weapon class's own walk while a strafe plays.
-- Attacks, casts, dodges and the guard play at Action priority and stay on top.
-- Tracks played by the owner replicate, so others see the strafe too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sprint = require(script.Parent.Sprint)

local player = Players.LocalPlayer
local gameSettings = UserSettings():GetService("UserGameSettings")

local BLEND = 0.2
local CLIP_SPEED = 16 -- studs/s the clips are keyed at (a normal walk)
local LATERAL = 0.6 -- sideways share of the move (in facing space) that counts as a strafe

local Strafe = {}

local humanoid: Humanoid? = nil
local tracks: { [string]: AnimationTrack } = {}
local side: string? = nil -- "Left" | "Right" while one plays

local function clear()
	for _, track in tracks do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(tracks)
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
	for _, name in { "Left", "Right" } do
		local animation = folder:FindFirstChild(name)
		if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
			local track = animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Movement
			track.Looped = true
			tracks[name] = track
		end
	end
	humanoid = h
end

-- The side being strafed to, or nil.
function Strafe.side(): string?
	return side
end

local function step()
	local h = humanoid
	local root = h and h.RootPart
	local want: string? = nil
	local speed = 0
	if h and root and h.Parent == player.Character and h.Health > 0 then
		speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local held = not h.AutoRotate or gameSettings.RotationType == Enum.RotationType.CameraRelative
		local grounded = h.FloorMaterial ~= Enum.Material.Air and not h.Sit
		local move = root.CFrame:VectorToObjectSpace(h.MoveDirection * Vector3.new(1, 0, 1))
		if held and grounded and speed > 1 and move.Magnitude > 0.1 and not Sprint.isRunning()
			and math.abs(move.X) / move.Magnitude >= LATERAL then
			want = if move.X > 0 then "Right" else "Left"
		end
	end
	if want and not tracks[want] then
		want = nil -- clip missing: leave the walk alone
	end
	for name, track in tracks do
		if name == want then
			if not track.IsPlaying then
				track:Play(BLEND)
			end
			track:AdjustSpeed(math.clamp(speed / CLIP_SPEED, 0.5, 1.5))
		elseif track.IsPlaying then
			track:Stop(BLEND)
		end
	end
	side = want
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
