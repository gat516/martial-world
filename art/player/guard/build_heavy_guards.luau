--!nocheck
-- Builds the heavy two-hander guard clips (Greatsword, Guandao) as R6 KeyframeSequences
-- and checks every key and in-between numerically. Run in a sandbox Studio, Edit mode,
-- through execute_luau. Needs an R6 rig at workspace.GuardRig (stock joints; e.g.
-- Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), R6)) and
-- ServerStorage.WeaponModels (Rojo-built from assets/WeaponModels.rbxm).
--
-- Poses are authored in torso space (+X right, +Y up, -Z forward) instead of raw joint
-- angles: a torso lean/turn, a head pitch/turn, where the right hand grips and which way
-- the weapon points, and where the off hand goes (a point, or a segment on the weapon it
-- slides along until it is in reach). R6 arms are one rigid block, so each arm is aimed
-- from its shoulder pivot at the hand target; the right arm's twist is picked to keep
-- the wrist (the Hilt/HiltR key) as straight as possible. The weapon is angled through
-- its Hilt/HiltR Motor6D (Right Arm > HiltR / Hilt), like the Greatsword M1 clips, with
-- the grip anchor held on the fist. Keyed: Torso (small lean/turn), Head, Right Arm,
-- Left Arm, HiltR/Hilt. Legs are unkeyed, so walking plays underneath.
--
-- Output: ServerStorage._HeavyGuards.<Class> (a Folder of four KeyframeSequences named
-- <Class>GuardHold / GuardParry / GuardParryAlt / GuardImpact) and a QA report string:
--   grip   right grip anchor to the fist (should be 0)
--   off    off hand to its target (reach error)
--   pen    deepest point of a weapon part or arm inside the head or torso box
--   play   the clip played through Animator vs the authored Transform (paths keyable)

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ServerStorage = game:GetService("ServerStorage")

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local rigTemplate = workspace:FindFirstChild("GuardRig")
assert(rigTemplate, "workspace.GuardRig (R6) missing")

local WEAPON = {
	Greatsword = { model = "Greatsword", joint = "HiltR" },
	Guandao = { model = "Guandao", joint = "Hilt" },
}

-- stock R6 joint frames
local M = {}
for _, m in rigTemplate:GetDescendants() do
	if m:IsA("Motor6D") then
		M[m.Name] = { C0 = m.C0, C1 = m.C1 }
	end
end

local SHOULDER = {
	R = { motor = "Right Shoulder", pivotT = V(1, 0.5, 0), pivotA = V(-0.5, 0.5, 0) },
	L = { motor = "Left Shoulder", pivotT = V(-1, 0.5, 0), pivotA = V(0.5, 0.5, 0), hand = V(0, -1, 0) },
}

local function rotAngle(cf)
	local _, a = cf:ToAxisAngle()
	return math.abs(a)
end

-- rotation taking unit a onto unit b
local function between(a, b)
	local c = a:Cross(b)
	local d = math.clamp(a:Dot(b), -1, 1)
	if c.Magnitude < 1e-6 then
		if d > 0 then
			return CFrame.identity
		end
		local perp = if math.abs(a.X) < 0.9 then V(1, 0, 0) else V(0, 1, 0)
		return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(c.Unit, math.acos(d))
end

-- how deep an arm frame (torso space) sinks into the torso and the rest-pose head,
-- sampling its lower 70% (the shoulder end always overlaps on R6)
local TORSO_HALF, HEAD_C, HEAD_HALF = V(1, 1, 0.5), V(0, 1.5, 0), V(0.65, 0.65, 0.65)
local function armSink(A)
	local deepest = 0
	for i = 0, 3 do
		for j = 0, 4 do
			for k = 0, 3 do
				local p = A * V(i / 3 - 0.5, -1 + 1.4 * j / 4, k / 3 - 0.5)
				local d = math.min(TORSO_HALF.X - math.abs(p.X), TORSO_HALF.Y - math.abs(p.Y), TORSO_HALF.Z - math.abs(p.Z))
				local h = p - HEAD_C
				local dh = math.min(HEAD_HALF.X - math.abs(h.X), HEAD_HALF.Y - math.abs(h.Y), HEAD_HALF.Z - math.abs(h.Z))
				deepest = math.max(deepest, d, dh)
			end
		end
	end
	return deepest
end

-- arm frame in torso space aimed so its hand point is on the line pivot -> target.
-- The twist keeps the block out of the torso and head first, then follows score(Q)
-- (higher is better).
local function aimArm(s, handA, target, score)
	local v = handA - s.pivotA
	local L = v.Magnitude
	local d = (target - s.pivotT)
	local err = d.Magnitude - L
	d = d.Unit
	local q0 = between(v.Unit, d)
	local best, bestScore = nil, -math.huge
	for i = 0, 143 do
		local q = CFrame.fromAxisAngle(d, i / 144 * 2 * math.pi) * q0
		local sc = score(q) - 8 * armSink(CF(s.pivotT) * q * CF(-s.pivotA))
		if sc > bestScore then
			best, bestScore = q, sc
		end
	end
	local A = CF(s.pivotT) * best * CF(-s.pivotA)
	return A, A * handA, err
end

-- weapon rotation from where its tip points (hilt -Z) and where its hilt +Y faces
local function weaponRot(point, up)
	local z = -point.Unit
	local y = (up - z * up:Dot(z)).Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end

local function solve(class, spec, wm)
	local w = WEAPON[class]
	local hm = wm[w.joint]
	local hC0, hC1 = hm.C0, hm.C1
	local g = wm.grip -- hilt-local grip anchor
	local handR = hC0 * hC1:Inverse() * g -- the fist, in Right Arm space
	local T = {}

	-- torso in HRP space, head in torso space
	local tq = spec.torso or {}
	local D = CF(0, tq.drop or 0, 0) * ANG(0, tq.yaw or 0, 0) * ANG(-(tq.pitch or 0), 0, 0) * ANG(0, 0, tq.roll or 0)
	T.Torso = M.RootJoint.C0:Inverse() * D * M.RootJoint.C1
	local hq = spec.head or {}
	local Hd = CF(0, 1, 0) * ANG(0, hq.yaw or 0, 0) * ANG(-(hq.pitch or 0), 0, 0) * ANG(0, 0, hq.roll or 0) * CF(0, 0.5, 0)
	T.Head = M.Neck.C0:Inverse() * Hd * M.Neck.C1

	-- right arm + weapon
	-- flat: which way the blade's flat faces (hilt +X); it sets up = -point x flat
	local up = spec.up or (-spec.point.Unit):Cross(spec.flat)
	local Rw = weaponRot(spec.point, up)
	local A, hand = aimArm(SHOULDER.R, handR, spec.grip, function(q)
		return -rotAngle(q:Inverse() * Rw)
	end)
	local Hdes = CF(hand) * Rw * CF(-g)
	T["Right Arm"] = M["Right Shoulder"].C0:Inverse() * A * M["Right Shoulder"].C1
	T[w.joint] = hC0:Inverse() * A:Inverse() * Hdes * hC1

	-- off hand: a point, or a segment in hilt space it slides along
	local off = spec.off
	local target
	if off.seg then
		local a, b = Hdes * off.seg[1], Hdes * off.seg[2]
		local s = SHOULDER.L
		local L = (s.hand - s.pivotA).Magnitude
		local bestS, bestScore = 0, math.huge
		for i = 0, 200 do
			local f = i / 200
			local p = a:Lerp(b, f)
			local sc = math.max(math.abs((p - s.pivotT).Magnitude - L) - 0.05, 0) * 20 + math.abs(f - (off.pref or 0.5))
			if sc < bestScore then
				bestS, bestScore = f, sc
			end
		end
		target = a:Lerp(b, bestS)
	else
		target = off.point
	end
	local face = off.face or V(0, 0, -1)
	local AL, handL, errL = aimArm(SHOULDER.L, SHOULDER.L.hand, target, function(q)
		return (q * V(0, 0, -1)):Dot(face)
	end)
	T["Left Arm"] = M["Left Shoulder"].C0:Inverse() * AL * M["Left Shoulder"].C1
	return T, { offErr = errL, hilt = Hdes }
end

-- KeyframeSequence: HumanoidRootPart (weight 0) > Torso > Head, Right Arm > joint, Left Arm
local function buildKS(name, class, keys, loop, priority, markers)
	local joint = WEAPON[class].joint
	local ks = Instance.new("KeyframeSequence")
	ks.Name = name
	ks.Loop = loop
	ks.Priority = priority
	for _, k in keys do
		local kf = Instance.new("Keyframe")
		kf.Time = k.t
		local function pose(n, parent, cf)
			local p = Instance.new("Pose")
			p.Name = n
			p.CFrame = cf
			p.Weight = 1
			p.EasingStyle = k.style or Enum.PoseEasingStyle.Cubic
			p.EasingDirection = k.dir or Enum.PoseEasingDirection.InOut
			p.Parent = parent
			return p
		end
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.Weight = 0
		root.Parent = kf
		local torso = pose("Torso", root, k.T.Torso)
		pose("Head", torso, k.T.Head)
		local ra = pose("Right Arm", torso, k.T["Right Arm"])
		pose(joint, ra, k.T[joint])
		pose("Left Arm", torso, k.T["Left Arm"])
		for mname, mt in markers or {} do
			if math.abs(mt - k.t) < 1e-4 then
				local m = Instance.new("KeyframeMarker")
				m.Name = mname
				m.Value = ""
				m.Parent = kf
			end
		end
		kf.Parent = ks
	end
	return ks
end

---------------------------------------------------------------------------------------------
-- Poses (torso space). grip: right fist target; point: where the tip goes; up: hilt +Y
-- (the blade's back edge; -Y is the cutting edge); off: off-hand target.

local function lerpV(a, b, f)
	return a + (b - a) * f
end

-- Greatsword: blade near vertical in front of the torso, flat to the threat, right fist
-- low on the grip, left fist braced on the back of the flat at chest height.
local GS_FLAT = {
	seg = { V(-0.2, 0.353, -0.9), V(-0.2, 0.353, -3.2) }, -- along the blade's back face (hilt -X side)
	pref = 0.35,
	face = V(0, 0, -1),
}
-- the off hand slides down to the grip below the right fist for the two-handed beat
local GS_POMMEL = { seg = { V(0.135, 0.353, 0.6), V(0.135, 0.353, 1.4) }, pref = 0.2, face = V(1, 0, -1).Unit }
local GS = {}
GS.hold = {
	torso = { pitch = 0.1, yaw = 0.12 },
	head = { pitch = 0.08, yaw = -0.1 },
	grip = V(0.6, -0.5, -1.2),
	point = V(-0.55, 0.85, -0.12),
	flat = V(0, 0, -1),
	off = { seg = GS_FLAT.seg, pref = 0.3 },
}
GS.inhale = {
	torso = { pitch = 0.07, yaw = 0.12 },
	head = { pitch = 0.05, yaw = -0.1 },
	grip = V(0.6, -0.43, -1.2),
	point = V(-0.55, 0.86, -0.09),
	flat = V(0, 0, -1),
	off = { seg = GS_FLAT.seg, pref = 0.3 },
}
-- parry right: cock the tip further in, then beat the flat out to the right with both
-- hands on the grip
GS.cockR = {
	torso = { pitch = 0.12, yaw = 0.24 },
	head = { pitch = 0.1, yaw = -0.16 },
	grip = V(0.5, -0.45, -1.15),
	point = V(-0.75, 0.7, -0.05),
	flat = V(0, 0, -1),
	off = { seg = GS_FLAT.seg, pref = 0.3 },
}
GS.beatR = {
	torso = { pitch = 0.14, yaw = -0.3 },
	head = { pitch = 0.1, yaw = 0.1 },
	grip = V(0.3, -0.3, -1.4),
	point = V(0.9, 0.85, -0.5),
	flat = V(1, 0, -0.6),
	off = GS_POMMEL,
}
GS.followR = {
	torso = { pitch = 0.15, yaw = -0.36 },
	head = { pitch = 0.1, yaw = 0.14 },
	grip = V(0.4, -0.35, -1.38),
	point = V(1.2, 0.7, -0.45),
	flat = V(1, 0, -0.5),
	off = GS_POMMEL,
}
-- parry left: the tip cocks upright, then the flat beats across to the left, the off
-- hand shoving on it
GS.cockL = {
	torso = { pitch = 0.12, yaw = 0.04 },
	head = { pitch = 0.08, yaw = -0.06 },
	grip = V(0.6, -0.45, -1.25),
	point = V(-0.42, 0.9, -0.12),
	flat = V(0, 0, -1),
	off = { seg = GS_FLAT.seg, pref = 0.3 },
}
GS.beatL = {
	torso = { pitch = 0.14, yaw = 0.42 },
	head = { pitch = 0.1, yaw = -0.3 },
	grip = V(0.3, -0.3, -1.4),
	point = V(-1.2, 0.75, -0.5),
	flat = V(-1, 0, -0.7),
	off = { seg = GS_FLAT.seg, pref = 0.25 },
}
GS.followL = {
	torso = { pitch = 0.15, yaw = 0.48 },
	head = { pitch = 0.1, yaw = -0.34 },
	grip = V(0.2, -0.35, -1.35),
	point = V(-1.35, 0.6, -0.45),
	flat = V(-1, 0, -0.6),
	off = { seg = GS_FLAT.seg, pref = 0.25 },
}
-- impact: the flat is driven back toward the chest, the body rocks back on it
GS.shove = {
	torso = { pitch = -0.08, yaw = 0.16 },
	head = { pitch = 0.26, yaw = -0.1 },
	grip = V(0.6, -0.6, -0.95),
	point = V(-0.55, 0.85, 0.05),
	flat = V(0, 0, -1),
	off = { seg = GS_FLAT.seg, pref = 0.3 },
}
GS.rebound = {
	torso = { pitch = 0.14, yaw = 0.12 },
	head = { pitch = 0.1, yaw = -0.1 },
	grip = V(0.6, -0.5, -1.28),
	point = V(-0.55, 0.85, -0.17),
	flat = V(0, 0, -1),
	off = { seg = GS_FLAT.seg, pref = 0.3 },
}

-- Guandao: haft crosswise in front of the chest, blade end high on the right, butt low
-- left, the crescent's flat to the front (edge up) so it reads face-on; the off hand slides on the haft below the grip.
local GD_HAFT = { seg = { V(0, 0, 2.9), V(0, 0, 5.1) }, pref = 0.4, face = V(0, 0, -1) }
local GD = {}
GD.hold = {
	torso = { pitch = 0.08, yaw = 0.1 },
	head = { pitch = 0.1, yaw = -0.1 },
	grip = V(0.85, 0.6, -1.4),
	point = V(0.85, 0.45, -0.2),
	up = V(0, -1, 0.35),
	off = GD_HAFT,
}
GD.inhale = {
	torso = { pitch = 0.05, yaw = 0.1 },
	head = { pitch = 0.08, yaw = -0.1 },
	grip = V(0.85, 0.68, -1.4),
	point = V(0.85, 0.5, -0.2),
	up = V(0, -1, 0.35),
	off = GD_HAFT,
}
-- parry right: the upper haft and blade heel sweep the blow out to the right
GD.cockR = {
	torso = { pitch = 0.1, yaw = 0.24 },
	head = { pitch = 0.1, yaw = -0.16 },
	grip = V(0.75, 0.5, -0.95),
	point = V(0.85, 0.55, 0.05),
	up = V(0, -1, 0.35),
	off = GD_HAFT,
}
GD.sweepR = {
	torso = { pitch = 0.12, yaw = -0.34 },
	head = { pitch = 0.06, yaw = 0.14 },
	grip = V(1.05, 0.55, -1.5),
	point = V(0.9, 0.55, -0.35),
	up = V(0.3, -1, 0.4),
	off = { seg = GD_HAFT.seg, pref = 0.3 },
}
GD.followR = {
	torso = { pitch = 0.13, yaw = -0.4 },
	head = { pitch = 0.06, yaw = 0.18 },
	grip = V(1.15, 0.5, -1.45),
	point = V(0.9, 0.5, -0.3),
	up = V(0.3, -1, 0.4),
	off = { seg = GD_HAFT.seg, pref = 0.3 },
}
-- parry left: the butt end sweeps forward and out to the left
GD.cockL = {
	torso = { pitch = 0.1, yaw = -0.08 },
	head = { pitch = 0.1, yaw = -0.04 },
	grip = V(0.95, 0.6, -1.35),
	point = V(0.85, 0.35, -0.35),
	up = V(0, -1, 0.35),
	off = GD_HAFT,
}
GD.sweepL = {
	torso = { pitch = 0.12, yaw = 0.42 },
	head = { pitch = 0.06, yaw = -0.3 },
	grip = V(0.6, 0.5, -0.7),
	point = V(0.95, 0.3, 0.25),
	up = V(0, -1, 0.45),
	off = { seg = GD_HAFT.seg, pref = 0.6, face = V(-1, 0, -1).Unit },
}
GD.followL = {
	torso = { pitch = 0.13, yaw = 0.48 },
	head = { pitch = 0.06, yaw = -0.34 },
	grip = V(0.55, 0.45, -0.65),
	point = V(0.95, 0.3, 0.35),
	up = V(0, -1, 0.45),
	off = { seg = GD_HAFT.seg, pref = 0.6, face = V(-1, 0, -1).Unit },
}
GD.shove = {
	torso = { pitch = -0.08, yaw = 0.12 },
	head = { pitch = 0.2, yaw = -0.1 },
	grip = V(0.85, 0.45, -0.9),
	point = V(0.85, 0.5, -0.1),
	up = V(0, -1, 0.35),
	off = GD_HAFT,
}
GD.rebound = {
	torso = { pitch = 0.12, yaw = 0.1 },
	head = { pitch = 0.12, yaw = -0.1 },
	grip = V(0.85, 0.6, -1.45),
	point = V(0.85, 0.42, -0.25),
	up = V(0, -1, 0.35),
	off = GD_HAFT,
}

local SPECS = { Greatsword = GS, Guandao = GD }

local OUT = Enum.PoseEasingDirection.Out
local IN = Enum.PoseEasingDirection.In
local INOUT = Enum.PoseEasingDirection.InOut
local CUBIC = Enum.PoseEasingStyle.Cubic
local LINEAR = Enum.PoseEasingStyle.Linear

-- timing: { t, poseName, style, dir } (style/dir shape the move FROM this key)
local CLIPS = {
	GuardHold = { loop = true, priority = Enum.AnimationPriority.Action, keys = {
		{ 0, "hold", CUBIC, INOUT }, { 0.8, "inhale", CUBIC, INOUT }, { 1.6, "hold", CUBIC, INOUT },
	} },
	GuardParry = { loop = false, priority = Enum.AnimationPriority.Action2, markers = { Contact = 0.08 }, keys = {
		{ 0, "hold", CUBIC, OUT }, { 0.035, "cockR", CUBIC, IN }, { 0.08, "beatR", CUBIC, OUT },
		{ 0.15, "followR", CUBIC, INOUT }, { 0.28, "rebound", CUBIC, INOUT }, { 0.4, "hold", CUBIC, INOUT },
	} },
	GuardParryAlt = { loop = false, priority = Enum.AnimationPriority.Action2, markers = { Contact = 0.08 }, keys = {
		{ 0, "hold", CUBIC, OUT }, { 0.035, "cockL", CUBIC, IN }, { 0.08, "beatL", CUBIC, OUT },
		{ 0.15, "followL", CUBIC, INOUT }, { 0.28, "rebound", CUBIC, INOUT }, { 0.4, "hold", CUBIC, INOUT },
	} },
	GuardImpact = { loop = false, priority = Enum.AnimationPriority.Action2, keys = {
		{ 0, "hold", LINEAR, OUT }, { 0.04, "shove", CUBIC, OUT }, { 0.13, "rebound", CUBIC, INOUT },
		{ 0.25, "hold", CUBIC, INOUT },
	} },
}
local CLIP_ORDER = { "GuardHold", "GuardParry", "GuardParryAlt", "GuardImpact" }
-- Guandao names its parry keys sweep*, the Greatsword beat*
local ALIAS = { Guandao = { beatR = "sweepR", beatL = "sweepL" } }

---------------------------------------------------------------------------------------------
-- QA helpers

local function penetration(part, box, y0, y1)
	-- deepest sample of `part`'s box inside `box` (a part), in studs; y0..y1 limits the
	-- samples to a share of the part's height (0 bottom, 1 top)
	local deepest = 0
	local s = part.Size
	local half = box.Size / 2
	y0, y1 = y0 or 0, y1 or 1
	for i = 0, 4 do
		for j = 0, 4 do
			for k = 0, 4 do
				local fy = y0 + (y1 - y0) * j / 4
				local p = part.CFrame * V((i / 4 - 0.5) * s.X, (fy - 0.5) * s.Y, (k / 4 - 0.5) * s.Z)
				local l = box.CFrame:PointToObjectSpace(p)
				local d = math.min(half.X - math.abs(l.X), half.Y - math.abs(l.Y), half.Z - math.abs(l.Z))
				if d > deepest then
					deepest = d
				end
			end
		end
	end
	return deepest
end

local FLOOR = 0 -- set from the rig's feet in makeRig
local function makeRig(class, scratch)
	local rig = rigTemplate:Clone()
	rig.Name = "QA_" .. class
	for _, d in rig:GetChildren() do
		if d:IsA("LocalScript") or d:IsA("Script") then
			d:Destroy()
		end
	end
	rig.Parent = scratch
	rig:PivotTo(CF(0, 3, 0))
	rig.HumanoidRootPart.Anchored = true
	FLOOR = (rig["Left Leg"].CFrame * V(0, -1, 0)).Y
	local wpn = ServerStorage.WeaponModels[WEAPON[class].model]:Clone()
	local motor = wpn.PrimaryPart:FindFirstChildOfClass("Motor6D")
	-- equip order from Weapons.apply: place the hilt, parent, then connect
	local arm = rig["Right Arm"]
	wpn:PivotTo(arm.CFrame * motor.C0 * motor.C1:Inverse() * wpn.PrimaryPart.PivotOffset)
	wpn.Name = "HeldWeapon"
	wpn.Parent = rig
	motor.Part0 = arm
	local base = {}
	for _, m in rig:GetDescendants() do
		if m:IsA("Motor6D") then
			base[m] = m.C0
		end
	end
	return rig, wpn, base
end

local function applyPose(rig, base, T)
	for m, c0 in base do
		local t = T[m.Part1.Name]
		m.C0 = if t then c0 * t else c0
	end
end

local function lerpPose(a, b, f)
	local r = {}
	for k, v in a do
		r[k] = v:Lerp(b[k], f)
	end
	return r
end

local function qaPose(rig, wpn, base, T, class)
	applyPose(rig, base, T)
	local head, torso = rig.Head, rig.Torso
	-- head box at the visible head size
	local headBox = { CFrame = head.CFrame, Size = V(1.3, 1.3, 1.3) }
	local torsoBox = { CFrame = torso.CFrame, Size = torso.Size }
	local worst, what = 0, ""
	-- arms: only their lower 70% (R6 arm tops always swing into the torso at the shoulder)
	local function check(part, label, y1)
		for _, b in { { headBox, "head" }, { torsoBox, "torso" } } do
			local d = penetration(part, b[1], 0, y1)
			if d > worst then
				worst, what = d, label .. ">" .. b[2]
			end
		end
	end
	for _, p in wpn:GetDescendants() do
		if p:IsA("BasePart") and p ~= wpn.PrimaryPart then
			check(p, p.Name)
		end
	end
	check(rig["Left Arm"], "LArm", 0.7)
	check(rig["Right Arm"], "RArm", 0.7)
	-- the off hand against the blade (Greatsword brace): how far the fist sinks into it
	local blade = wpn:FindFirstChild(class .. "Blade", true)
	local fistIn = if blade then penetration(rig["Left Arm"], blade, 0, 0.3) else 0
	-- grip and arm-vs-arm
	local gripAtt = wpn.PrimaryPart:FindFirstChild("grip")
	local fist = rig["Right Arm"].CFrame * (WEAPON[class].joint == "HiltR" and V(0, -1, 0) or V(-0.086, -1.018, 0))
	local gripErr = (gripAtt.WorldPosition - fist).Magnitude
	local arms = math.max(penetration(rig["Left Arm"], rig["Right Arm"], 0, 0.7), 0)
	-- off hand distance to the weapon axis (how well it holds on)
	local offHand = rig["Left Arm"].CFrame * V(0, -1, 0)
	local tip = wpn.PrimaryPart:FindFirstChild("tip").WorldPosition
	local tail = if class == "Greatsword" then wpn.PrimaryPart.guard.WorldPosition else wpn.PrimaryPart.butt.WorldPosition
	local ax = (tip - tail).Unit
	local rel = offHand - tail
	local offAxis = (rel - ax * rel:Dot(ax)).Magnitude
	-- lowest weapon point (it must stay above the floor at Y 0: the rig stands at 3)
	local low = math.huge
	for _, p in wpn:GetDescendants() do
		if p:IsA("BasePart") and p ~= wpn.PrimaryPart then
			for _, c in { V(1, 1, 1), V(-1, 1, 1), V(1, -1, 1), V(-1, -1, 1), V(1, 1, -1), V(-1, 1, -1), V(1, -1, -1), V(-1, -1, -1) } do
				low = math.min(low, (p.CFrame * (p.Size / 2 * c)).Y)
			end
		end
	end
	return { pen = worst, penWhat = what, grip = gripErr, arms = arms, offAxis = offAxis, low = low - FLOOR, fistIn = fistIn }
end

---------------------------------------------------------------------------------------------

local old = ServerStorage:FindFirstChild("_HeavyGuards")
if old then
	old:Destroy()
end
local outFolder = Instance.new("Folder")
outFolder.Name = "_HeavyGuards"
outFolder.Parent = ServerStorage
local scratch = Instance.new("Folder")
scratch.Name = "_HeavyGuardQA"
scratch.Parent = workspace

local report = {}
for _, class in { "Greatsword", "Guandao" } do
	local spec = SPECS[class]
	local wm = {}
	local tmpl = ServerStorage.WeaponModels[WEAPON[class].model]
	local jm = tmpl.PrimaryPart:FindFirstChildOfClass("Motor6D")
	wm[WEAPON[class].joint] = { C0 = jm.C0, C1 = jm.C1 }
	wm.grip = tmpl.PrimaryPart.grip.Position
	local solved, info = {}, {}
	for name, s in spec do
		solved[name], info[name] = solve(class, s, wm)
	end
	local folder = Instance.new("Folder")
	folder.Name = class
	folder.Parent = outFolder
	local rig, wpn, base = makeRig(class, scratch)
	table.insert(report, "== " .. class)
	for name, i in info do
		applyPose(rig, base, solved[name])
		local hb = { CFrame = rig.Head.CFrame, Size = V(1.3, 1.3, 1.3) }
		local wpnHead, wpnTorso = 0, 0
		for _, p in wpn:GetDescendants() do
			if p:IsA("BasePart") and p ~= wpn.PrimaryPart then
				wpnHead = math.max(wpnHead, penetration(p, hb))
				wpnTorso = math.max(wpnTorso, penetration(p, rig.Torso))
			end
		end
		local tc = rig.Torso.CFrame
		local function tl(pos) local q = tc:PointToObjectSpace(pos) return string.format("(%.1f,%.1f,%.1f)", q.X, q.Y, q.Z) end
		local function td(dir) local q = tc:VectorToObjectSpace(dir) return string.format("(%.1f,%.1f,%.1f)", q.X, q.Y, q.Z) end
		local hp = wpn.PrimaryPart
		local tailName = if class == "Greatsword" then "tassel_mount" else "butt"
		local hrp = rig.HumanoidRootPart.CFrame
		local function hl(pos) local q = hrp:PointToObjectSpace(pos) return string.format("(%.1f,%.1f,%.1f)", q.X, q.Y, q.Z) end
		table.insert(report, string.format("    %-8s tip %s tail %s (HRP space tip %s) flat %s edge %s Lhand %s", name, tl(hp.tip.WorldPosition),
			tl(hp[tailName].WorldPosition), hl(hp.tip.WorldPosition), td(hp.CFrame.XVector), td(-hp.CFrame.YVector), tl(rig["Left Arm"].CFrame * V(0, -1, 0))))
		table.insert(report, string.format("  pose %-8s offErr %+.2f  L>torso %.2f R>torso %.2f L>R %.2f L>head %.2f wpn>head %.2f wpn>torso %.2f",
			name, i.offErr, penetration(rig["Left Arm"], rig.Torso, 0, 0.7), penetration(rig["Right Arm"], rig.Torso, 0, 0.7),
			penetration(rig["Left Arm"], rig["Right Arm"], 0, 0.7), penetration(rig["Left Arm"], hb, 0, 1), wpnHead, wpnTorso))
	end
	for _, clipName in CLIP_ORDER do
		local c = CLIPS[clipName]
		local keys = {}
		for _, k in c.keys do
			local pn = (ALIAS[class] and ALIAS[class][k[2]]) or k[2]
			assert(solved[pn], class .. ": no pose " .. pn)
			table.insert(keys, { t = k[1], T = solved[pn], style = k[3], dir = k[4], pose = pn })
		end
		local ks = buildKS(class .. clipName, class, keys, c.loop, c.priority, c.markers)
		ks.Parent = folder
		-- numeric QA over keys and in-betweens
		local worst = { pen = 0, grip = 0, arms = 0, offAxis = 0, low = math.huge, fistIn = 0 }
		local worstAt = {}
		for i = 1, #keys do
			local nxt = keys[i + 1]
			for _, f in (if nxt then { 0, 0.25, 0.5, 0.75 } else { 0 }) do
				local T = if nxt then lerpPose(keys[i].T, nxt.T, f) else keys[i].T
				local q = qaPose(rig, wpn, base, T, class)
				local at = string.format("%.3f", keys[i].t + (if nxt then (nxt.t - keys[i].t) * f else 0))
				if q.pen > worst.pen then worst.pen = q.pen; worstAt.pen = at .. " " .. q.penWhat end
				if q.grip > worst.grip then worst.grip = q.grip end
				if q.arms > worst.arms then worst.arms = q.arms; worstAt.arms = at end
				if q.offAxis > worst.offAxis then worst.offAxis = q.offAxis; worstAt.off = at end
				if q.low < worst.low then worst.low = q.low end
				if q.fistIn > worst.fistIn then worst.fistIn = q.fistIn end
			end
		end
		table.insert(report, string.format("  %s len %.2f: pen %.3f (%s) grip %.4f arms %.3f (%s) offAxis %.2f (%s) fistInBlade %.2f weapon above floor %.2f",
			clipName, keys[#keys].t, worst.pen, worstAt.pen or "-", worst.grip, worst.arms, worstAt.arms or "-",
			worst.offAxis, worstAt.off or "-", worst.fistIn, worst.low))
	end
	applyPose(rig, base, {})
	-- playback through the Animator: the authored Transforms must arrive on every joint
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", rig.Humanoid)
	for _, ks in folder:GetChildren() do
		local id = KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		local t0 = os.clock()
		while track.Length <= 0 and os.clock() - t0 < 5 do
			task.wait()
		end
		track:Play(0)
		local keyframes = ks:GetKeyframes()
		table.sort(keyframes, function(a, b) return a.Time < b.Time end)
		local mid = keyframes[math.ceil(#keyframes / 2)]
		animator:StepAnimations(mid.Time + 1e-3)
		local worstDiff, n = 0, 0
		for _, m in rig:GetDescendants() do
			if m:IsA("Motor6D") then
				local pose = mid:FindFirstChild(m.Part1.Name, true)
				if pose and pose.Weight > 0 then
					n += 1
					local diff = (m.Transform.Position - pose.CFrame.Position).Magnitude + rotAngle(m.Transform:Inverse() * pose.CFrame)
					worstDiff = math.max(worstDiff, diff)
				end
			end
		end
		local length = track.Length
		track:Stop(0)
		track:Destroy()
		table.insert(report, string.format("  play %s @%.3f: %d joints, worst diff %.3f, length %.2f", ks.Name, mid.Time, n, worstDiff, length))
	end
end
scratch:Destroy()
return table.concat(report, "\n")
