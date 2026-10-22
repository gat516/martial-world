--!nocheck
-- Spear and Staff guard clips (R6 player, two-handed polearm): builds the KeyframeSequences
-- from pose specs, solving both hands onto the shaft, and checks every baked frame.
-- Run in a sandbox Studio (tools/sandbox.sh), Edit mode, through execute_luau:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8768/art/player/guard/polearm_guard.luau?" .. os.clock()))()
--   _G.PolearmGuard.build("Spear")   -> ServerStorage._PolearmGuard.Spear (4 KeyframeSequences) + a QA report
--   _G.PolearmGuard.verify("Spear")  -> plays each clip on the rig (Animator:StepAnimations) and compares
-- Export: tools/export_rbxm.luau (_G.exportRbxm) of the folder and of each sequence, see README.md.
--
-- How a pose is described (HRP space: x right, y up, -z the threat; HRP at the origin):
--   twist/lean/side/drop  the RootJoint: yaw (+ turns left), forward pitch, roll to the right, sink (studs)
--   yaw/pitch             the shaft's tip direction (+yaw to the left, +pitch up), from the right hand
--   hand                  where the right hand would like to be; it is pulled onto its reach sphere
--   d                     wanted distance from the right hand to the left hand along the shaft
--   hpitch/hyaw/hroll     the head in HRP space (0 = looking at the threat)
-- The right hand holds the weapon's grip (Hilt motor, C0 at the fist); the Hilt joint is keyed so
-- the shaft points along yaw/pitch (the M1 clips key HumanoidRootPart.Torso.Right Arm.Hilt the same
-- way). The left hand is solved onto the shaft line where the left arm reaches it. Arms are rigid
-- R6 blocks, so both hands stay 1.57 studs from their shoulders; arm roll turns the fist toward the
-- shaft (clamped), the Hilt rotation takes the rest.
-- Joints keyed: Torso (RootJoint), Head, Right Arm, Right Arm.Hilt, Left Arm. Legs unkeyed, so
-- the walk plays underneath. Keyframes are baked at <= 1/30 s between the authored keys so the
-- left hand stays on the shaft through every blend (joint slerp alone lets it slide off).

local ServerStorage = game:GetService("ServerStorage")
local KSP = game:GetService("KeyframeSequenceProvider")

local M = {}
_G.PolearmGuard = M

local RIG_NAME = "_PolearmGuardRig"
local BAKE_STEP = 1 / 30
local ROLL_MAX = math.rad(45)

-- weapon geometry along the shaft, from the grip (WeaponModels <Name>.Hilt attachments)
M.WEAP = {
	Spear = { model = "Spear", tip = 6.4, butt = 2.3, radius = 0.143 },
	Staff = { model = "Staff", tip = 3.3, butt = 2.8, radius = 0.18 },
}

---------------------------------------------------------------- rig
local function getRig()
	local rig = workspace:FindFirstChild(RIG_NAME)
	if rig then return rig end
	rig = game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	rig.Name = RIG_NAME
	for _, d in rig:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	rig:PivotTo(CFrame.new(0, 3, 40))
	rig.HumanoidRootPart.Anchored = true
	rig.Parent = workspace
	return rig
end
M.getRig = getRig

local rig = getRig()
local J = {}
for _, m in rig:GetDescendants() do
	if m:IsA("Motor6D") and m.Parent and m.Parent.Parent == rig then J[m.Name] = m end
end
local RS, LS, NK, RJ = J["Right Shoulder"], J["Left Shoulder"], J["Neck"], J["RootJoint"]
local HILT_C0 = CFrame.new(-0.086, -1.018, 0.001) -- art/weapons/place_weapons.luau HILT
local HILT_C1 = CFrame.new(0, 0, 2.026)
local LHAND = Vector3.new(0.086, -1.018, 0)
local vR = HILT_C0.Position - RS.C1.Position
local vL = LHAND - LS.C1.Position
local REACH = vR.Magnitude

---------------------------------------------------------------- solver
local function dirOf(yaw, pitch)
	return Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
end

local function rotBetween(a: Vector3, b: Vector3): CFrame
	a, b = a.Unit, b.Unit
	local c, d = a:Cross(b), a:Dot(b)
	if c.Magnitude < 1e-8 then
		if d > 0 then return CFrame.identity end
		local axis = a:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-3 then axis = a:Cross(Vector3.yAxis) end
		return CFrame.fromAxisAngle(axis.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(c.Unit, math.atan2(c.Magnitude, d))
end

local function signedAngle(a: Vector3, b: Vector3, axis: Vector3): number
	return math.atan2(a:Cross(b):Dot(axis), a:Dot(b))
end

local ROLL_K = 0.35 -- arm roll toward the shaft: ROLL_K * sin(2 * angle), smooth and never flips
-- the arm aimed along `aim`, rolled a little so the fist's grip axis turns toward D
local function armCF(torsoCF: CFrame, motor: Motor6D, vLocal: Vector3, aim: Vector3, D: Vector3)
	local pivot = (torsoCF * motor.C0).Position
	local Rrest = torsoCF.Rotation
	local R1 = rotBetween(Rrest:VectorToWorldSpace(vLocal), aim) * Rrest
	local g = R1:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local Dp = D - aim * D:Dot(aim)
	local phi = 0
	if Dp.Magnitude > 1e-4 then phi = ROLL_K * math.sin(2 * signedAngle(g, Dp, aim)) end
	local R = CFrame.fromAxisAngle(aim, phi) * R1
	return CFrame.new(pivot - R:VectorToWorldSpace(motor.C1.Position)) * R, phi
end

local function motorT(part0CF: CFrame, motor: Motor6D, part1CF: CFrame): CFrame
	return ((part0CF * motor.C0):Inverse() * part1CF * motor.C1).Rotation
end

local function torsoCF(s)
	return CFrame.new(0, -(s.drop or 0), 0) * CFrame.fromEulerAnglesYXZ(-(s.lean or 0), s.twist or 0, -(s.side or 0))
end

local function deg(x) return math.rad(x) end

-- Forward kinematics of one pose spec. Arms aim in torso space (ry/rp, ly/lp in degrees: yaw +
-- toward the character's left, pitch + up, 0/0 = straight forward); the shaft runs from the right
-- fist through the left fist, so the left hand is on it by construction and in-betweens stay on it.
function M.solve(s, wname: string)
	local W = M.WEAP[wname]
	local tor = torsoCF(s)
	local SR = (tor * RS.C0).Position
	local SL = (tor * LS.C0).Position
	local aR = tor:VectorToWorldSpace(dirOf(deg(s.ry), deg(s.rp)))
	local aL = tor:VectorToWorldSpace(dirOf(deg(s.ly), deg(s.lp)))
	local HR, HL = SR + aR * REACH, SL + aL * REACH
	local D = (HL - HR).Unit
	local armR, rollR = armCF(tor, RS, vR, aR, D)
	local armL, rollL = armCF(tor, LS, vL, aL, D)
	local hand = armR * HILT_C0
	local g = hand:VectorToWorldSpace(Vector3.new(0, 0, -1))
	-- the shaft's own spin is pinned to the world (hilt +Y kept up, plus `spin` degrees), so the
	-- blade, tassel and ribbon don't twist about the shaft as the arms move
	local Q = CFrame.lookAt(Vector3.zero, D, Vector3.yAxis) * CFrame.Angles(0, 0, math.rad(s.spin or 0))
	local Thilt = hand.Rotation:Inverse() * Q
	local headRot = CFrame.fromEulerAnglesYXZ(-(s.hpitch or 0), s.hyaw or 0, -(s.hroll or 0))
	local Tneck = (tor * NK.C0).Rotation:Inverse() * headRot * NK.C1.Rotation
	local leftHand = armL * LHAND
	local rel = leftHand - HR
	local along = rel:Dot(D)
	local function across(axis) return math.abs(90 - math.deg(math.acos(math.clamp(axis:Dot(D), -1, 1)))) end
	-- where the shaft passes the chest: closest point of the shaft line to the torso centre, torso space
	local c = tor.Position
	local near = HR + D * (c - HR):Dot(D)
	return {
		T = {
			Torso = motorT(CFrame.identity, RJ, tor),
			Head = Tneck,
			["Right Arm"] = motorT(tor, RS, armR),
			["Left Arm"] = motorT(tor, LS, armL),
			Hilt = Thilt,
		},
		torso = tor, head = tor * NK.C0 * Tneck * NK.C1:Inverse(), armR = armR, armL = armL, D = D,
		hilt = hand * Thilt * HILT_C1:Inverse(), -- the weapon's Hilt part, HRP space
		HR = HR, HL = leftHand, sep = along, lhOff = (rel - D * along).Magnitude, miss = 0,
		-- how far the shaft is from crossing each arm at a right angle (0 = across the fist)
		wristR = across(armR:VectorToWorldSpace(Vector3.new(0, -1, 0))),
		wristL = across(armL:VectorToWorldSpace(Vector3.new(0, -1, 0))),
		rollR = math.deg(rollR), rollL = math.deg(rollL),
		near = tor:PointToObjectSpace(near),
		yaw = math.deg(math.atan2(-D.X, -D.Z)), pitch = math.deg(math.asin(D.Y)),
		tip = HR + D * W.tip, butt = HR - D * W.butt, radius = W.radius,
	}
end

---------------------------------------------------------------- QA
local HEAD_SIZE = Vector3.new(1.2, 1.2, 1.2) -- the head mesh, not its 2x1x1 box
local LIMB = Vector3.new(1, 2, 1)
local TORSO = Vector3.new(2, 2, 1)
local HAND_FREE = 0.75 -- shaft samples this close to a hand pass through the fist, not the arm
local function depthIn(cf: CFrame, size: Vector3, p: Vector3, rad: number)
	local l = cf:PointToObjectSpace(p)
	local h = size / 2
	return math.min(h.X - math.abs(l.X), h.Y - math.abs(l.Y), h.Z - math.abs(l.Z)) + rad
end
-- legs at rest and swung +-0.6 rad (the walk's widest stride) about the hips
local function legCFs(tor: CFrame)
	local out = {}
	for _, n in { "Right Hip", "Left Hip" } do
		local m = J[n]
		for _, a in { 0, 0.6, -0.6 } do
			table.insert(out, tor * m.C0 * CFrame.Angles(0, 0, a) * m.C1:Inverse())
		end
	end
	return out
end
function M.check(P)
	local w = {}
	local function note(k, v) if v > (w[k] or -1e9) then w[k] = v end end
	local legs = legCFs(P.torso)
	local n = math.ceil((P.tip - P.butt).Magnitude / 0.1)
	for i = 0, n do
		local p = P.butt:Lerp(P.tip, i / n)
		note("head", depthIn(P.head, HEAD_SIZE, p, P.radius))
		note("torso", depthIn(P.torso, TORSO, p, P.radius))
		for _, lc in legs do note("legs", depthIn(lc, LIMB, p, P.radius)) end
		if (p - P.HL).Magnitude > HAND_FREE then note("armL", depthIn(P.armL, LIMB, p, P.radius)) end
		if (p - P.HR).Magnitude > HAND_FREE then note("armR", depthIn(P.armR, LIMB, p, P.radius)) end
	end
	-- the floor is 3 studs under the HRP (R6 hip height); keep both shaft ends 0.1 above it
	note("ground", -2.9 - math.min(P.tip.Y, P.butt.Y))
	for _, a in { P.armR, P.armL } do
		for x = -0.5, 0.5, 0.25 do for y = -1, 1, 0.25 do for z = -0.5, 0.5, 0.25 do
			note("armHead", depthIn(P.head, HEAD_SIZE, a * Vector3.new(x, y, z), 0))
		end end end
	end
	return w
end
local function v3(v) return string.format("(%.2f,%.2f,%.2f)", v.X, v.Y, v.Z) end
function M.fmt(P)
	local w = M.check(P)
	return string.format("shaft yaw %.0f pitch %.0f sep %.2f near %s wrist R%.0f L%.0f roll R%.0f L%.0f | HR %s HL %s tip %s butt %s | clip head %.2f torso %.2f legs %.2f armL %.2f armR %.2f armHead %.2f ground %.2f",
		P.yaw, P.pitch, P.sep, v3(P.near), P.wristR, P.wristL, P.rollR, P.rollL, v3(P.HR), v3(P.HL), v3(P.tip), v3(P.butt),
		w.head, w.torso, w.legs, w.armL, w.armR, w.armHead, w.ground)
end

---------------------------------------------------------------- pose search (authoring aid)
-- Grid over the four arm aims for one torso pose; scores the shaft direction against
-- target yaw/pitch (degrees, HRP space) and rejects clipping. Returns the best lines.
-- opts: { twist, lean, side, yaw, pitch, sepMin, sepMax, front (max torso-space z where the shaft
-- passes the chest, nil = any), step (deg), ref (spec to stay near), refW }
function M.search(wname: string, o)
	local step = o.step or 10
	local res = {}
	local base = { twist = o.twist or 0, lean = o.lean or 0, side = o.side or 0 }
	local tD = dirOf(math.rad(o.yaw), math.rad(o.pitch))
	local n = 0
	for ry = o.ryMin or -100, o.ryMax or 60, step do
		for rp = o.rpMin or -90, o.rpMax or 70, step do
			for ly = o.lyMin or -70, o.lyMax or 60, step do
				for lp = o.lpMin or -90, o.lpMax or 70, step do
					local s = { twist = base.twist, lean = base.lean, side = base.side, ry = ry, rp = rp, ly = ly, lp = lp }
					local P = M.solve(s, wname)
					n += 1
					if P.sep >= (o.sepMin or 1.0) and P.sep <= (o.sepMax or 2.6) and P.wristR < (o.wristMax or 50) and P.wristL < (o.wristMax or 50)
						and (o.front == nil or P.near.Z < o.front)
						and (o.midMax == nil or math.abs(P.torso:PointToObjectSpace((P.tip + P.butt) / 2).X) < o.midMax) then
						local ang = math.deg(math.acos(math.clamp(P.D:Dot(tD), -1, 1)))
						if ang < (o.angMax or 25) then
							local w = M.check(P)
							if w.head < -0.03 and w.torso < -0.03 and w.legs < (o.legsMax or -0.03) and w.armHead < 0 and w.ground < 0 and w.armL < 0.2 and w.armR < 0.2 then
								local score = ang + 0.1 * (P.wristR + P.wristL)
								if o.ref then
									score += (o.refW or 0.3) * (math.abs(ry - o.ref.ry) + math.abs(rp - o.ref.rp) + math.abs(ly - o.ref.ly) + math.abs(lp - o.ref.lp))
								end
								table.insert(res, { score = score, txt = string.format("ry %d rp %d ly %d lp %d (ang %.0f) :: %s", ry, rp, ly, lp, ang, M.fmt(P)) })
							end
						end
					end
				end
			end
			task.wait()
		end
	end
	table.sort(res, function(a, b) return a.score < b.score end)
	local out = { string.format("%d poses, %d clean", n, #res) }
	for i = 1, math.min(o.top or 8, #res) do table.insert(out, res[i].txt) end
	return table.concat(out, "\n")
end

---------------------------------------------------------------- specs
local FIELDS = { "twist", "lean", "side", "drop", "ry", "rp", "ly", "lp", "hpitch", "hyaw", "hroll", "spin" }
local function lerpSpec(a, b, u)
	local s = {}
	for _, f in FIELDS do s[f] = (a[f] or 0) + ((b[f] or 0) - (a[f] or 0)) * u end
	return s
end
local function ease(kind: string?, u: number)
	if kind == "in" then return u * u * u
	elseif kind == "out" then return 1 - (1 - u) ^ 3
	elseif kind == "linear" then return u
	end
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2 -- inout
end
local function with(base, over)
	local s = table.clone(base)
	for k, v in over do s[k] = v end
	return s
end
M.with = with

-- Each clip: { name, loop, priority, keys = { { t, spec, ease = segment easing after it, marker? } } }
M.CLIPS = {}

-- SPEAR: held sideways like a crossbar barring the threat: shaft level across the front of the
-- chest, hands wide (right hand on the grip near the butt, so the tip runs out to the left).
-- Parry = lan: the tip end dips, then circles up and beats the blow out and up to the left.
-- ParryAlt = na: the tip end rises, then rolls over and presses the blow down to the front-left
-- while the butt end comes up on the right.
do
	local HOLD = { twist = -0.05, lean = 0.06, ry = -5, rp = 10, ly = 10, lp = 18, hpitch = 0.05 }
	local BREATH = with(HOLD, { lean = 0.08, rp = 12, lp = 20, hpitch = 0.07 })
	local LAN_PRE = { twist = -0.08, lean = 0.06, ry = -5, rp = 0, ly = 10, lp = -15, hpitch = 0.05 }
	local LAN_C = { twist = 0.15, lean = 0.08, ry = 5, rp = -55, ly = -15, lp = 5, hpitch = 0.05, hyaw = 0.12 }
	local LAN_OVER = { twist = 0.18, lean = 0.08, ry = 5, rp = -56, ly = -17, lp = 8, hpitch = 0.05, hyaw = 0.14 }
	local NA_PRE = { twist = -0.02, lean = 0.06, ry = -5, rp = 10, ly = 15, lp = 35, hpitch = 0.05 }
	local NA_C = { twist = -0.3, lean = 0.1, ry = -5, rp = 25, ly = 5, lp = -5, hpitch = 0.12, hyaw = -0.1 }
	local NA_OVER = { twist = -0.33, lean = 0.1, ry = -5, rp = 27, ly = 5, lp = -9, hpitch = 0.14, hyaw = -0.12 }
	local IMP = { twist = -0.03, lean = -0.1, ry = -5, rp = -5, ly = 10, lp = 20, hpitch = -0.1, hroll = 0.05 }
	M.CLIPS.Spear = {
		{ name = "SpearGuardHold", loop = true, priority = Enum.AnimationPriority.Action, keys = {
			{ 0, HOLD }, { 0.8, BREATH }, { 1.6, HOLD },
		} },
		{ name = "SpearGuardParry", priority = Enum.AnimationPriority.Action2, keys = {
			{ 0, HOLD, ease = "in" }, { 0.035, LAN_PRE, ease = "linear" }, { 0.07, LAN_C, ease = "out", marker = "Contact" },
			{ 0.13, LAN_OVER }, { 0.36, HOLD },
		} },
		{ name = "SpearGuardParryAlt", priority = Enum.AnimationPriority.Action2, keys = {
			{ 0, HOLD, ease = "in" }, { 0.035, NA_PRE, ease = "linear" }, { 0.07, NA_C, ease = "out", marker = "Contact" },
			{ 0.13, NA_OVER }, { 0.36, HOLD },
		} },
		{ name = "SpearGuardImpact", priority = Enum.AnimationPriority.Action2, keys = {
			{ 0, HOLD, ease = "out" }, { 0.05, IMP, ease = "inout" }, { 0.25, HOLD },
		} },
	}
	M.HOLD_Spear = HOLD
end

-- STAFF: held mid-shaft, horizontal across the chest, arms out in front (head end to the left).
-- The deflect wheels the shaft in the frontal plane so one end whips up and strikes the blow aside:
-- Parry the left (head) end up, ParryAlt the right (butt) end up.
do
	local HOLD = { twist = -0.05, lean = 0.06, ry = 15, rp = 5, ly = 20, lp = 15, hpitch = 0.05 }
	local BREATH = with(HOLD, { lean = 0.08, rp = 7, lp = 17, hpitch = 0.07 })
	local L_PRE = { twist = 0.0, lean = 0.06, ry = 10, rp = -25, ly = 10, lp = 15, hpitch = 0.05 }
	local L_C = { twist = 0.15, lean = 0.08, ry = 20, rp = -35, ly = -20, lp = 15, hpitch = 0.05, hyaw = 0.12 }
	local L_OVER = { twist = 0.18, lean = 0.08, ry = 18, rp = -37, ly = -22, lp = 18, hpitch = 0.05, hyaw = 0.14 }
	local R_PRE = { twist = -0.12, lean = 0.06, ry = 10, rp = 0, ly = 20, lp = -35, hpitch = 0.05 }
	local R_C = { twist = -0.28, lean = 0.08, ry = 25, rp = 10, ly = 15, lp = -60, hpitch = 0.05, hyaw = -0.12 }
	local R_OVER = { twist = -0.3, lean = 0.08, ry = 25, rp = 14, ly = 15, lp = -61, hpitch = 0.05, hyaw = -0.14 }
	local IMP = { twist = -0.03, lean = -0.1, ry = 15, rp = -12, ly = 20, lp = -2, hpitch = -0.1, hroll = -0.05 }
	M.CLIPS.Staff = {
		{ name = "StaffGuardHold", loop = true, priority = Enum.AnimationPriority.Action, keys = {
			{ 0, HOLD }, { 0.8, BREATH }, { 1.6, HOLD },
		} },
		{ name = "StaffGuardParry", priority = Enum.AnimationPriority.Action2, keys = {
			{ 0, HOLD, ease = "in" }, { 0.035, L_PRE, ease = "linear" }, { 0.07, L_C, ease = "out", marker = "Contact" },
			{ 0.13, L_OVER }, { 0.36, HOLD },
		} },
		{ name = "StaffGuardParryAlt", priority = Enum.AnimationPriority.Action2, keys = {
			{ 0, HOLD, ease = "in" }, { 0.035, R_PRE, ease = "linear" }, { 0.07, R_C, ease = "out", marker = "Contact" },
			{ 0.13, R_OVER }, { 0.36, HOLD },
		} },
		{ name = "StaffGuardImpact", priority = Enum.AnimationPriority.Action2, keys = {
			{ 0, HOLD, ease = "out" }, { 0.05, IMP, ease = "inout" }, { 0.25, HOLD },
		} },
	}
	M.HOLD_Staff = HOLD
end

---------------------------------------------------------------- bake + build
-- every frame: { t, spec, marker? }; authored keys plus evenly spaced in-betweens (eased in spec space)
function M.bake(clip)
	local frames = {}
	local keys = clip.keys
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		local t0, t1 = a[1], b[1]
		local n = math.max(1, math.ceil((t1 - t0) / BAKE_STEP - 1e-6))
		if clip.loop then n = math.max(1, math.ceil((t1 - t0) / 0.2 - 1e-6)) end
		for k = 0, n - 1 do
			local u = k / n
			table.insert(frames, { t = t0 + (t1 - t0) * u, spec = lerpSpec(a[2], b[2], ease(a.ease, u)), marker = if k == 0 then a.marker else nil })
		end
	end
	local last = keys[#keys]
	table.insert(frames, { t = last[1], spec = last[2], marker = last.marker })
	return frames
end

local POSE_TREE = { -- part -> parent part, in the R6 motor tree
	{ "HumanoidRootPart", nil }, { "Torso", "HumanoidRootPart" }, { "Head", "Torso" },
	{ "Right Arm", "Torso" }, { "Hilt", "Right Arm" }, { "Left Arm", "Torso" },
}
local function makeKeyframe(t: number, T, marker: string?)
	local kf = Instance.new("Keyframe")
	kf.Time = t
	local poses = {}
	for _, e in POSE_TREE do
		local p = Instance.new("Pose")
		p.Name = e[1]
		p.CFrame = T[e[1]] or CFrame.identity
		p.Weight = if e[1] == "HumanoidRootPart" then 0 else 1
		p.EasingStyle = Enum.PoseEasingStyle.Linear
		p.EasingDirection = Enum.PoseEasingDirection.In
		p.Parent = if e[2] then poses[e[2]] else kf
		poses[e[1]] = p
	end
	if marker then
		local m = Instance.new("KeyframeMarker")
		m.Name = marker
		m.Parent = kf
	end
	return kf
end

function M.build(wname: string)
	local root = ServerStorage:FindFirstChild("_PolearmGuard")
	if not root then
		root = Instance.new("Folder")
		root.Name = "_PolearmGuard"
		root.Parent = ServerStorage
	end
	local old = root:FindFirstChild(wname)
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = wname
	local report = {}
	local worst = {}
	for _, clip in M.CLIPS[wname] do
		local ks = Instance.new("KeyframeSequence")
		ks.Name = clip.name
		ks.Loop = clip.loop == true
		ks.Priority = clip.priority
		local frames = M.bake(clip)
		local prev
		local line = {}
		local maxStep = 0
		for _, f in frames do
			local P = M.solve(f.spec, wname)
			local w = M.check(P)
			for k, v in w do if v > (worst[k] or -1e9) then worst[k] = v end end
			for _, k in { "lhOff", "wristR", "wristL" } do
				if P[k] > (worst[k] or -1e9) then worst[k] = P[k] end
			end
			if prev then
				for name, T in P.T do
					local _, ang = (prev.T[name]:Inverse() * T):ToAxisAngle()
					maxStep = math.max(maxStep, math.deg(math.abs(ang)))
				end
			end
			prev = P
			makeKeyframe(f.t, P.T, f.marker).Parent = ks
		end
		for _, k in clip.keys do
			table.insert(line, string.format("  t=%.3f%s %s", k[1], if k.marker then " [" .. k.marker .. "]" else "", M.fmt(M.solve(k[2], wname))))
		end
		table.insert(report, string.format("%s: %d keyframes, %.2f s, max joint step between frames %.0f deg", clip.name, #frames, frames[#frames].t, maxStep))
		table.insert(report, table.concat(line, "\n"))
		ks.Parent = folder
	end
	folder.Parent = root
	local ws = {}
	for k, v in worst do table.insert(ws, string.format("%s %.3f", k, v)) end
	table.sort(ws)
	table.insert(report, "worst over all baked frames: " .. table.concat(ws, ", "))
	return table.concat(report, "\n")
end

---------------------------------------------------------------- playback check
-- Plays each built sequence on the rig holding the class weapon and compares the Motor6D
-- Transforms (and the FK left hand to the shaft) against the solve at sampled times.
function M.verify(wname: string)
	local folder = ServerStorage._PolearmGuard[wname]
	local held = rig:FindFirstChild("HeldWeapon")
	if held then held:Destroy() end
	local w = ServerStorage.WeaponModels[M.WEAP[wname].model]:Clone()
	w.Name = "HeldWeapon"
	local joint = w.PrimaryPart:FindFirstChild("Hilt")
	w:PivotTo(rig["Right Arm"].CFrame * joint.C0 * joint.C1:Inverse() * w.PrimaryPart.PivotOffset)
	w.Parent = rig
	joint.Part0 = rig["Right Arm"]
	local animator = rig.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", rig.Humanoid)
	local motors = { Torso = RJ, Head = NK, ["Right Arm"] = RS, ["Left Arm"] = LS, Hilt = joint }
	local out = {}
	for _, ks in folder:GetChildren() do
		local id = KSP:RegisterKeyframeSequence(ks)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		local t0 = os.clock()
		while track.Length <= 0 and os.clock() - t0 < 5 do task.wait() end
		track:Play(0)
		track:AdjustSpeed(0)
		local clip
		for _, c in M.CLIPS[wname] do if c.name == ks.Name then clip = c end end
		local worstT, worstOff = 0, 0
		local len = track.Length
		for t = 0, len - 1e-3, 1 / 60 do
			track.TimePosition = t
			animator:StepAnimations(1e-3)
			-- FK from the played transforms
			local tor = CFrame.identity * RJ.C0 * RJ.Transform * RJ.C1:Inverse()
			local armR = tor * RS.C0 * RS.Transform * RS.C1:Inverse()
			local armL = tor * LS.C0 * LS.Transform * LS.C1:Inverse()
			local hand = armR * joint.C0 * joint.Transform
			local D = hand:VectorToWorldSpace(Vector3.new(0, 0, -1))
			local rel = armL * LHAND - hand.Position
			worstOff = math.max(worstOff, (rel - D * rel:Dot(D)).Magnitude)
		end
		-- authored keys: played transform vs solve
		for _, k in clip.keys do
			track.TimePosition = math.min(k[1], len - 1e-3)
			animator:StepAnimations(1e-3)
			local P = M.solve(k[2], wname)
			for name, m in motors do
				local _, ang = (m.Transform.Rotation:Inverse() * P.T[name]):ToAxisAngle()
				worstT = math.max(worstT, math.deg(math.abs(ang)))
			end
		end
		track:Stop(0)
		animator:StepAnimations(1e-3)
		table.insert(out, string.format("%s: length %.3f, loop %s, priority %s, markers %s | key pose error %.2f deg, left hand off shaft (every 1/60 s) max %.3f studs",
			ks.Name, len, tostring(ks.Loop), ks.Priority.Name, (function()
				local ms = {}
				for _, kf in ks:GetKeyframes() do
					for _, m in kf:GetMarkers() do table.insert(ms, string.format("%s@%.3f", m.Name, kf.Time)) end
				end
				return table.concat(ms, " ")
			end)(), worstT, worstOff))
	end
	return table.concat(out, "\n")
end

M.solveHold = function(wname) return M.solve(M["HOLD_" .. wname], wname) end
return "PolearmGuard loaded (reach " .. string.format("%.3f", REACH) .. ")"
