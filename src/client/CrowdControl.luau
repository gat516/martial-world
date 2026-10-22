--!strict
-- Draws player crowd control (PlayerStun, server) on every R6 character: a
-- flinch (quick recoil), a stagger (stumble back, catch balance, recover) and a
-- stun (dazed sway loop). Driven by the Humanoid's CCKind/CCStart/CCEnd
-- attributes, so observers see the same pose. Layered on the Motor6D joints
-- after Animator, like HerbAnimator: the layer is removed before the next
-- animation pass, so it never accumulates and rides over whatever track plays.
-- The local player also gets the stumble shove and a little camera shake; their
-- input is gated in ActionState/CombatController/Movement.
-- No dazed-stars effect: nothing in the VFX library fits yet (see combat.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Combat.CC
local CombatEffects = require(script.Parent.CombatEffects)

local CrowdControl = {}

type Layer = { motor: Motor6D, original: CFrame }
local layers: { [Model]: { Layer } } = {}
local seen: { [Model]: number } = {} -- character -> CCStart already reacted to
local STUMBLE_SECONDS = 0.25

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function deg(x: number): number
	return math.rad(x)
end

-- Joint offsets in torso axes (x right, y up, z back), degrees. Positive pitch
-- leans the top back, positive hip swings the leg forward, arm out is +z for
-- the right arm and -z for the left.
type Pose = { rootPitch: number, rootRoll: number, rootYaw: number, neckPitch: number, neckRoll: number, arm: number, armSwing: number, rightHip: number, leftHip: number }

local function pose(): Pose
	return { rootPitch = 0, rootRoll = 0, rootYaw = 0, neckPitch = 0, neckRoll = 0, arm = 0, armSwing = 0, rightHip = 0, leftHip = 0 }
end

local function flinch(t: number, d: number): Pose
	local e = smooth(t / 0.05) * (1 - smooth((t - 0.07) / math.max(0.05, d - 0.07)))
	local p = pose()
	p.rootPitch, p.rootRoll, p.neckPitch, p.arm = 12 * e, 4 * e, 9 * e, 24 * e
	p.rightHip, p.leftHip = -6 * e, 4 * e
	return p
end

-- keys: time share, rootPitch, rootRoll, neckPitch, arm, rightHip, leftHip
local STAGGER = {
	{ 0, 0, 0, 0, 0, 0, 0 },
	{ 0.2, 26, 5, 14, 55, -28, 10 }, -- thrown back, arms out, right foot reaching back
	{ 0.55, -14, -4, -8, 28, 18, -10 }, -- lurching forward, catching balance
	{ 1, 0, 0, 0, 0, 0, 0 },
}

local function stagger(t: number, d: number): Pose
	local p = math.clamp(t / d, 0, 1)
	local a, b = STAGGER[1], STAGGER[#STAGGER]
	for i = 1, #STAGGER - 1 do
		if p <= STAGGER[i + 1][1] then
			a, b = STAGGER[i], STAGGER[i + 1]
			break
		end
	end
	local k = smooth((p - a[1]) / (b[1] - a[1]))
	local function at(i: number): number
		return a[i] + (b[i] - a[i]) * k
	end
	local out = pose()
	out.rootPitch, out.rootRoll, out.neckPitch, out.arm, out.rightHip, out.leftHip = at(2), at(3), at(4), at(5), at(6), at(7)
	out.rootYaw = 8 * math.sin(p * math.pi) -- a twist as they stumble
	return out
end

local function stun(t: number, d: number): Pose
	local w = smooth(t / 0.12) * (1 - smooth((t - (d - 0.25)) / 0.25))
	local wave = t * math.pi * 2 * 0.9
	local out = pose()
	out.rootPitch = (-12 + 3 * math.cos(wave * 2)) * w
	out.rootRoll = 7 * math.sin(wave) * w
	out.rootYaw = 5 * math.sin(wave * 0.5) * w
	out.neckPitch = -18 * w
	out.neckRoll = 14 * math.sin(wave - 0.9) * w
	out.arm = (12 + 6 * math.sin(wave)) * w
	out.armSwing = 8 * math.sin(wave + 0.6) * w
	out.rightHip, out.leftHip = -7 * w, 7 * w
	return out
end

local function restore(list: { Layer })
	for _, layer in list do
		if layer.motor.Parent then
			layer.motor.Transform = layer.original
		end
	end
end

-- Offset `rotation` (torso axes) about the joint, on top of the current Transform.
local function push(list: { Layer }, motor: Motor6D?, rotation: CFrame)
	if not motor then
		return
	end
	table.insert(list, { motor = motor, original = motor.Transform })
	local base = motor.C0.Rotation
	motor.Transform = base:Inverse() * rotation * base * motor.Transform
end

local function joint(parent: Instance?, name: string): Motor6D?
	local motor = parent and parent:FindFirstChild(name)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function beforeAnimation()
	for character, list in layers do
		restore(list)
		layers[character] = nil
	end
end

local function stumble(character: Model, humanoid: Humanoid, startedAt: number, now: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or humanoid:GetAttribute("CCKind") ~= "stagger" or now - startedAt > STUMBLE_SECONDS then
		return
	end
	local from = humanoid:GetAttribute("CCFrom")
	local away = if typeof(from) == "Vector3" then (root.Position - from) * Vector3.new(1, 0, 1) else Vector3.zero
	if away.Magnitude < 0.1 then
		away = -root.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	local velocity = root.AssemblyLinearVelocity
	local shove = away.Unit * Config.STAGGER_PUSH * (1 - (now - startedAt) / STUMBLE_SECONDS)
	root.AssemblyLinearVelocity = Vector3.new(shove.X, velocity.Y, shove.Z)
end

local function animate()
	local now = workspace:GetServerTimeNow()
	local me = Players.LocalPlayer.Character
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local torso = character and character:FindFirstChild("Torso")
		local kind = humanoid and humanoid:GetAttribute("CCKind")
		local startedAt = humanoid and humanoid:GetAttribute("CCStart")
		local endsAt = humanoid and humanoid:GetAttribute("CCEnd")
		if not (character and humanoid and torso and type(kind) == "string" and type(startedAt) == "number" and type(endsAt) == "number")
			or now >= endsAt or humanoid.Health <= 0 then
			continue
		end
		if seen[character] ~= startedAt then
			seen[character] = startedAt
			if character == me then
				if kind == "stagger" then
					CombatEffects.shake(0.4)
				elseif kind == "stun" then
					CombatEffects.shake(0.3)
				end
			end
		end
		if character == me then
			stumble(character, humanoid, startedAt, now)
		end
		local t, d = now - startedAt, endsAt - startedAt
		local p = if kind == "stun" then stun(t, d) elseif kind == "stagger" then stagger(t, d) else flinch(t, d)
		local list: { Layer } = {}
		local rootJoint = joint(character:FindFirstChild("HumanoidRootPart"), "RootJoint")
		push(list, rootJoint, CFrame.Angles(deg(p.rootPitch), deg(p.rootYaw), deg(p.rootRoll)))
		push(list, joint(torso, "Neck"), CFrame.Angles(deg(p.neckPitch), 0, deg(p.neckRoll)))
		push(list, joint(torso, "Left Shoulder"), CFrame.Angles(deg(p.armSwing), 0, deg(-p.arm)))
		push(list, joint(torso, "Right Shoulder"), CFrame.Angles(deg(-p.armSwing), 0, deg(p.arm)))
		push(list, joint(torso, "Right Hip"), CFrame.Angles(deg(p.rightHip), 0, 0))
		push(list, joint(torso, "Left Hip"), CFrame.Angles(deg(p.leftHip), 0, 0))
		layers[character] = list
	end
end

function CrowdControl.init()
	RunService.PreAnimation:Connect(beforeAnimation)
	RunService.PreSimulation:Connect(animate)
end

return CrowdControl
