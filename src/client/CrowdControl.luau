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
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
-- The per-limb fields add on top (pitch: + swings the limb forward; roll: + moves
-- the hand or foot to the right), for poses where the two sides differ.
type Pose = {
	rootPitch: number, rootRoll: number, rootYaw: number,
	neckPitch: number, neckRoll: number, neckYaw: number,
	arm: number, armSwing: number, rightHip: number, leftHip: number,
	lArmPitch: number, rArmPitch: number, lArmRoll: number, rArmRoll: number, lHipRoll: number, rHipRoll: number,
}

local function pose(): Pose
	return {
		rootPitch = 0, rootRoll = 0, rootYaw = 0,
		neckPitch = 0, neckRoll = 0, neckYaw = 0,
		arm = 0, armSwing = 0, rightHip = 0, leftHip = 0,
		lArmPitch = 0, rArmPitch = 0, lArmRoll = 0, rArmRoll = 0, lHipRoll = 0, rHipRoll = 0,
	}
end

local function flinch(t: number, d: number): Pose
	local e = smooth(t / 0.05) * (1 - smooth((t - 0.07) / math.max(0.05, d - 0.07)))
	local p = pose()
	-- a hard snap: torso back, head whipped, arms jolted out and back, knees give
	local whip = math.sin(math.clamp(t / 0.12, 0, 1) * math.pi) * (1 - smooth(t / d))
	p.rootPitch, p.rootRoll, p.rootYaw = 24 * e, 7 * e, 5 * e
	p.neckPitch, p.neckRoll = 22 * e + 12 * whip, 8 * whip
	p.arm, p.armSwing = 46 * e, 20 * e
	p.rightHip, p.leftHip = -12 * e, 8 * e
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

-- Struck senseless: a hard snap back with the arms flung out, a slump, then a
-- punch-drunk loop. The head lolls round in circles, the hunched body drifts on
-- its feet and every 1.6 s nearly topples (alternating sides), catching itself
-- with a step and a flung arm. The arms hang limp and swing a beat behind the
-- body; the legs counter the body's lean so the feet stay under it. The last
-- 0.35 s shakes it off and straightens up.
local function stun(t: number, d: number): Pose
	local out = pose()
	local hit = math.sin(math.clamp(t / 0.22, 0, 1) * math.pi) -- 0 -> 1 -> 0 over the snap
	local daze = smooth((t - 0.1) / 0.35) * (1 - smooth((t - (d - 0.35)) / 0.35))
	local loll = t * math.pi * 2 * 0.75
	local drift = t * math.pi * 2 * 0.38
	local cycle = t / 1.6
	local side = if math.floor(cycle) % 2 == 0 then 1 else -1 -- 1: tips left
	local lurch = math.max(0, math.sin((cycle % 1) * math.pi * 2)) ^ 4 * daze

	local hunch = (-14 + 4 * math.cos(drift)) * daze
	local sway = 7 * math.sin(drift) * daze + 11 * side * lurch
	out.rootPitch = 22 * hit + hunch
	out.rootRoll = sway
	out.rootYaw = 8 * hit + 6 * math.sin(drift * 0.5) * daze

	out.neckPitch = 30 * hit + (-28 + 10 * math.sin(loll)) * daze
	out.neckRoll = 20 * math.cos(loll) * daze
	out.neckYaw = 12 * math.sin(loll * 0.5 + 0.7) * daze
	local off = math.clamp((t - (d - 0.35)) / 0.35, 0, 1)
	if d > 0.8 then
		out.neckYaw += 22 * math.sin(off * math.pi * 6) * math.sin(off * math.pi) -- shaking it off
	end

	-- limp arms hang plumb, a beat behind the body's drift; flung out on the hit
	-- and to catch a near-fall
	local lag = drift - 1.1
	out.arm = 55 * hit
	out.lArmPitch = -hunch * 0.85 + 10 * math.sin(lag) * daze
	out.rArmPitch = -hunch * 0.85 + 10 * math.sin(lag - 0.5) * daze
	out.lArmRoll = -sway * 0.85 - 6 * daze - 28 * lurch
	out.rArmRoll = -sway * 0.85 + 6 * daze + 28 * lurch

	-- feet stay under the body, a wide unsteady stance; the falling side steps out
	out.rightHip = -out.rootPitch * 0.85 + (if side < 0 then 10 * lurch else 0)
	out.leftHip = -out.rootPitch * 0.85 + (if side > 0 then 10 * lurch else 0)
	out.lHipRoll = -sway * 0.85 - 5 * daze - (if side > 0 then 14 * lurch else 0)
	out.rHipRoll = -sway * 0.85 + 5 * daze + (if side < 0 then 14 * lurch else 0)
	return out
end

-- A white pulse on the whole character: reads at a glance, local and observed.
local function pulse(character: Model, strength: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 1 - strength
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	TweenService:Create(highlight, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.3)
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
			pulse(character, if kind == "flinch" then 0.7 else 0.55)
			if character == me then
				if kind == "flinch" then
					CombatEffects.shake(0.3)
				elseif kind == "stagger" then
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
		push(list, joint(torso, "Neck"), CFrame.Angles(deg(p.neckPitch), deg(p.neckYaw), deg(p.neckRoll)))
		push(list, joint(torso, "Left Shoulder"), CFrame.Angles(deg(p.armSwing + p.lArmPitch), 0, deg(-p.arm + p.lArmRoll)))
		push(list, joint(torso, "Right Shoulder"), CFrame.Angles(deg(-p.armSwing + p.rArmPitch), 0, deg(p.arm + p.rArmRoll)))
		push(list, joint(torso, "Right Hip"), CFrame.Angles(deg(p.rightHip), 0, deg(p.rHipRoll)))
		push(list, joint(torso, "Left Hip"), CFrame.Angles(deg(p.leftHip), 0, deg(p.lHipRoll)))
		layers[character] = list
	end
end

function CrowdControl.init()
	RunService.PreAnimation:Connect(beforeAnimation)
	RunService.PreSimulation:Connect(animate)
end

return CrowdControl
