--!nocheck
-- Builds the per-class player guard clips (Fist, Sword, Saber): Hold, Parry,
-- ParryAlt and Impact KeyframeSequences for the stock R6 rig, the weapon angled
-- by its own Hilt/HiltR joint (Right Arm > Hilt), and checks every key pose by
-- forward kinematics. Run it in a sandbox Studio (tools/sandbox.sh): load the
-- source into a ModuleScript and require it; it returns
--   build()        -> { [class] = { Hold = ks, Parry = ks, ParryAlt = ks, Impact = ks } }
--                     (also parented under ServerStorage._GuardClips for export)
--   qa(clips)      -> text report: per key pose, blade/arm clearance to head and
--                     torso, wrist angle, left-hand reach error, loop/return checks
--   play(clips)    -> plays each clip on a parented rig through Animator and
--                     compares the stepped Motor6D transforms with the keys
--
-- Poses are written in Torso space (+X the character's right, +Y up, -Z
-- forward) as targets: where the right hand goes, which way the blade points,
-- where the left hand goes (or "on the blade" for the saber's spine brace).
-- The script turns them into joint rotations through the rig's real C0/C1, so
-- the clips open in Moon Animator and the Animation Editor as ordinary keys on
-- Torso, Head, Right Arm, Left Arm and the weapon joint (legs unkeyed, so the
-- walk plays underneath).

local M = {}

local V = Vector3.new
local function unit(v) return v.Unit end

-- weapon facts, from ServerStorage.WeaponModels (art/weapons/place_weapons.luau)
-- edge: the cutting edge's direction in the hilt part's space; length: hand to tip
local WEAPON = {
	Sword = { model = "Jian", joint = "HiltR", edge = V(0, 1, 0), spine = nil },
	Saber = { model = "Dadao", joint = "Hilt", edge = V(0, -1, 0), spine = V(0, 1, 0) },
}

----------------------------------------------------------------------------
-- pose specs
----------------------------------------------------------------------------
-- torso / head = { pitch (forward +), turn (left +), roll (left shoulder down +) }
-- r = right hand target, b = blade direction, roll = extra edge roll about the blade
-- l = left hand target, or lBlade = distance along the blade from the right hand
--   (saber: the left palm on the spine there)
-- rf / lf = which way the arm's front face (thumb side) points, bare hands only

local P = {}

P.Sword = {
	-- raised guard: hand forward at the right chest, the blade slanting up and to the left
	-- across the front of the face (tip past the centreline, about head-top height),
	-- left sword-finger at the right wrist
	hold = {
		torso = { 0.08, 0.12, 0 }, head = { 0.12, -0.1, 0 },
		r = V(0.95, 0.9, -1.4), b = V(-0.6, 0.75, -0.25),
		l = V(0.1, 0.35, -1.35), lf = V(1, 0, 0),
	},
	-- Parry: the raised blade snaps over to the right (wrist flick), edge driving the blow out
	parry = {
		{ t = 0.07, torso = { 0.09, -0.08, 0 }, head = { 0.12, 0.06, 0 },
			r = V(1.15, 1.0, -1.4), b = V(0.55, 0.8, -0.25), l = V(-0.1, 0.35, -1.3), lf = V(1, 0, 0), ease = "out" },
		{ t = 0.15, torso = { 0.08, -0.22, 0 }, head = { 0.12, 0.18, 0 },
			r = V(1.25, 0.9, -1.25), b = V(0.9, 0.35, -0.25), l = V(-0.2, 0.3, -1.25), lf = V(1, 0, 0) },
		{ t = 0.24, torso = { 0.08, 0.02, 0 }, head = { 0.12, -0.02, 0 },
			r = V(1.05, 0.95, -1.4), b = V(0.1, 0.95, -0.3), l = V(0.05, 0.35, -1.32), lf = V(1, 0, 0) },
	},
	-- ParryAlt: the blade beats down and out to the left, flat sweeping the blow aside
	parryAlt = {
		{ t = 0.07, torso = { 0.09, 0.3, 0 }, head = { 0.12, -0.24, 0 },
			r = V(0.6, 1.0, -1.5), b = V(-0.9, 0.3, -0.3), l = V(-1.3, 0.25, -0.75), lf = V(0, 0, -1), ease = "out" },
		{ t = 0.15, torso = { 0.1, 0.4, 0 }, head = { 0.12, -0.32, 0 },
			r = V(0.5, 0.85, -1.5), b = V(-0.85, -0.3, -0.1), l = V(-1.6, 0.2, -0.45), lf = V(0, 0, -1) },
		{ t = 0.24, torso = { 0.09, 0.2, 0 }, head = { 0.12, -0.16, 0 },
			r = V(0.8, 0.9, -1.45), b = V(-0.45, 0.7, -0.5), l = V(-0.2, 0.32, -1.3), lf = V(1, 0, 0) },
	},
	-- Impact: the hit shoves the raised blade back toward the body, the body gives a little
	impact = {
		{ t = 0.05, torso = { -0.05, 0.16, 0 }, head = { 0.0, -0.12, 0 },
			r = V(0.95, 1.0, -1.2), b = V(-0.6, 0.78, -0.08), l = V(0.12, 0.4, -1.25), lf = V(1, 0, 0), ease = "out" },
		{ t = 0.13, torso = { 0.1, 0.11, 0 }, head = { 0.14, -0.09, 0 },
			r = V(0.95, 0.88, -1.45), b = V(-0.6, 0.74, -0.3), l = V(0.1, 0.34, -1.36), lf = V(1, 0, 0) },
	},
	length = { parry = 0.34, parryAlt = 0.34, impact = 0.25 },
	contact = 0.07,
}

P.Saber = {
	-- spine-braced block: blade diagonal up-left across the front, edge out, left palm on the back
	hold = {
		torso = { 0.1, 0.1, 0 }, head = { 0.12, -0.1, 0 },
		r = V(0.35, 0.7, -1.45), b = V(-0.88, 0.45, -0.15),
		lBlade = 1.5,
	},
	-- Parry: heavy beat-aside to the right, both hands driving, left lets go at the end
	parry = {
		{ t = 0.08, torso = { 0.12, -0.2, 0 }, head = { 0.12, 0.14, 0 },
			r = V(0.75, 0.95, -1.45), b = V(0.15, 0.95, -0.27), l = V(0.0, 0.45, -1.35), lf = V(1, 0, 0), ease = "out" },
		{ t = 0.18, torso = { 0.12, -0.42, 0 }, head = { 0.12, 0.32, 0 },
			r = V(1.25, 0.85, -1.35), b = V(0.86, 0.32, -0.4), l = V(-1.55, 0.25, 0.9), lf = V(0, 0, -1) },
		{ t = 0.28, torso = { 0.11, -0.12, 0 }, head = { 0.12, 0.08, 0 },
			r = V(0.5, 0.85, -1.45), b = V(-0.6, 0.7, -0.3), l = V(-0.6, 0.9, -1.4), lf = V(1, 0, 0) },
	},
	-- ParryAlt: heavy beat down and to the left, the left palm pressing the spine
	parryAlt = {
		{ t = 0.08, torso = { 0.15, 0.3, 0 }, head = { 0.12, -0.24, 0 },
			r = V(0.15, 0.55, -1.45), b = V(-0.85, -0.2, -0.45), lBlade = 1.25, ease = "out" },
		{ t = 0.18, torso = { 0.2, 0.46, 0 }, head = { 0.1, -0.36, 0 },
			r = V(0.1, 0.4, -1.45), b = V(-0.62, -0.55, -0.05), lBlade = 1.25 },
		{ t = 0.28, torso = { 0.13, 0.2, 0 }, head = { 0.12, -0.17, 0 },
			r = V(0.25, 0.65, -1.45), b = V(-0.9, 0.22, -0.3), lBlade = 1.3 },
	},
	impact = {
		{ t = 0.06, torso = { -0.05, 0.16, 0 }, head = { 0.02, -0.14, 0 },
			r = V(0.42, 0.78, -1.25), b = V(-0.9, 0.42, -0.05), lBlade = 1.55, ease = "out" },
		{ t = 0.14, torso = { 0.12, 0.09, 0 }, head = { 0.14, -0.09, 0 },
			r = V(0.35, 0.68, -1.45), b = V(-0.88, 0.46, -0.2), lBlade = 1.5 },
	},
	length = { parry = 0.4, parryAlt = 0.4, impact = 0.25 },
	contact = 0.08,
}

-- Fist: a boxing guard, both fists up by the chin, elbows in, chin down, a light bounce
P.Fist = {
	holdLength = 0.8, bounce = 1.6,
	hold = {
		torso = { 0.12, -0.12, 0 }, head = { 0.2, 0.1, 0 },
		r = V(0.62, 1.32, -1.2), rf = V(0, 1, 0),
		l = V(-0.6, 1.38, -1.32), lf = V(0, 1, 0),
	},
	-- Parry: the right glove swats the blow across, in front of the face, and snaps back
	parry = {
		{ t = 0.07, torso = { 0.12, 0.2, 0 }, head = { 0.12, -0.1, -0.08 },
			r = V(0.3, 0.95, -1.45), rf = V(-1, 0.3, 0), l = V(-0.65, 1.32, -1.25), lf = V(0, 1, 0), ease = "out" },
		{ t = 0.14, torso = { 0.12, 0.28, 0 }, head = { 0.12, -0.16, -0.1 },
			r = V(0.1, 0.8, -1.4), rf = V(-1, 0.2, 0), l = V(-0.65, 1.3, -1.25), lf = V(0, 1, 0) },
		{ t = 0.23, torso = { 0.12, -0.08, 0 }, head = { 0.2, 0.07, 0 },
			r = V(0.55, 1.3, -1.3), rf = V(0, 1, 0), l = V(-0.62, 1.36, -1.3), lf = V(0, 1, 0) },
	},
	-- ParryAlt: the left glove swats it across the other way
	parryAlt = {
		{ t = 0.07, torso = { 0.12, -0.36, 0 }, head = { 0.12, 0.24, 0.08 },
			l = V(-0.3, 0.98, -1.48), lf = V(1, 0.3, 0), r = V(0.65, 1.28, -1.15), rf = V(0, 1, 0), ease = "out" },
		{ t = 0.14, torso = { 0.12, -0.44, 0 }, head = { 0.12, 0.3, 0.1 },
			l = V(-0.1, 0.82, -1.42), lf = V(1, 0.2, 0), r = V(0.65, 1.28, -1.15), rf = V(0, 1, 0) },
		{ t = 0.23, torso = { 0.12, -0.16, 0 }, head = { 0.2, 0.13, 0 },
			l = V(-0.5, 1.36, -1.38), lf = V(0, 1, 0), r = V(0.63, 1.3, -1.18), rf = V(0, 1, 0) },
	},
	-- Impact: the gloves are driven back toward the face, the body rocks back
	impact = {
		{ t = 0.05, torso = { -0.04, -0.12, 0 }, head = { 0.1, 0.1, 0 },
			r = V(0.62, 1.42, -1.0), rf = V(0, 1, 0), l = V(-0.6, 1.46, -1.08), lf = V(0, 1, 0), ease = "out" },
		{ t = 0.13, torso = { 0.15, -0.12, 0 }, head = { 0.22, 0.1, 0 },
			r = V(0.62, 1.3, -1.25), rf = V(0, 1, 0), l = V(-0.6, 1.36, -1.37), lf = V(0, 1, 0) },
	},
	length = { parry = 0.3, parryAlt = 0.3, impact = 0.25 },
	contact = 0.07,
}

M.Poses = P
M.HOLD_LENGTH = 2.0 -- breathing loop (a class's holdLength overrides it)

----------------------------------------------------------------------------
-- rig
----------------------------------------------------------------------------
local rigCache = {}

-- a stock R6 rig in Workspace with the class weapon attached the way
-- server/Weapons.luau does it (place, parent, then connect Part0)
function M.rig(class)
	if rigCache[class] and rigCache[class].Parent then return rigCache[class] end
	local folder = workspace:FindFirstChild("_GuardClipRigs")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_GuardClipRigs"
		folder.Parent = workspace
		game:GetService("CollectionService"):AddTag(folder, "EditorOnly")
	end
	local desc = Instance.new("HumanoidDescription")
	local rig = game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	rig.Name = "GuardRig_" .. class
	for _, d in rig:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	rig.HumanoidRootPart.Anchored = true
	rig:PivotTo(CFrame.new(({ Fist = 0, Sword = 8, Saber = 16 })[class] + 200, 3, 200))
	rig.Parent = folder
	local w = WEAPON[class]
	if w then
		local model = game.ServerStorage.WeaponModels[w.model]:Clone()
		model.Name = "HeldWeapon"
		local hilt = model.PrimaryPart
		local joint = hilt[w.joint]
		local arm = rig["Right Arm"]
		model:PivotTo(arm.CFrame * joint.C0 * joint.C1:Inverse() * hilt.PivotOffset)
		model.Parent = rig
		joint.Part0 = arm
	end
	rigCache[class] = rig
	return rig
end

local function motors(rig)
	local t = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then t[d.Part1.Name] = d end
	end
	return t
end
M.motors = motors

local function rot(cf) return cf - cf.Position end

-- joint Transform that gives Part1 the rotation `want` relative to Part0 (pure rotation,
-- so the pivot stays put)
local function transformFor(motor, want)
	return rot(motor.C0):Inverse() * want * rot(motor.C1)
end

local function frame(dirA, hintA)
	-- orthonormal frame whose first axis is dirA and second is hintA made perpendicular
	local a1 = dirA.Unit
	local a2 = (hintA - a1 * hintA:Dot(a1))
	if a2.Magnitude < 1e-4 then a2 = math.abs(a1.Y) < 0.9 and V(0, 1, 0) or V(1, 0, 0); a2 = (a2 - a1 * a2:Dot(a1)) end
	a2 = a2.Unit
	local a3 = a1:Cross(a2)
	return CFrame.fromMatrix(Vector3.zero, a1, a2, a3)
end

-- rotation taking arm-space vector v (pivot -> hand) onto torso direction w, with the
-- arm's front face (-Z) turned toward `front`
local function aim(v, w, front)
	local A = frame(v, V(0, 0, -1))
	local B = frame(w, front)
	return B * A:Inverse()
end

local function eul(e)
	-- pitch forward +, turn left +, roll (left shoulder down) +
	return CFrame.Angles(0, e[2], 0) * CFrame.Angles(-e[1], 0, 0) * CFrame.Angles(0, 0, e[3] or 0)
end

-- solve one pose spec into { [Part1 name] = Transform } plus diagnostics
function M.solve(class, spec)
	local rig = M.rig(class)
	local mot = motors(rig)
	local out, diag = {}, {}
	local w = WEAPON[class]

	out.Torso = transformFor(mot.Torso, eul(spec.torso))
	out.Head = transformFor(mot.Head, eul(spec.head))

	-- right arm
	local rs = mot["Right Arm"]
	local hilt = w and mot[w.joint]
	local handArm = hilt and hilt.C0.Position or V(0, -1, 0) -- grip point in arm space
	local pivotT, pivotA = rs.C0.Position, rs.C1.Position
	local vArm = handArm - pivotA
	local front = spec.b or spec.rf or V(0, 0, -1)
	local R = aim(vArm, spec.r - pivotT, front)
	out["Right Arm"] = transformFor(rs, R)
	local handT = pivotT + R * vArm
	diag.rReach = (spec.r - handT).Magnitude

	-- weapon joint: blade along b, edge kept where the natural grip puts it, plus roll
	local Rh
	if w then
		local b = spec.b.Unit
		local edgeNatural = R * w.edge
		local e = (edgeNatural - b * edgeNatural:Dot(b)).Unit
		if spec.roll then e = (CFrame.fromAxisAngle(b, spec.roll) * e) end
		-- hilt part axes: -Z = blade, edge = w.edge (±Y)
		local zAxis = -b
		local yAxis = if w.edge.Y > 0 then e else -e
		local xAxis = yAxis:Cross(zAxis)
		Rh = CFrame.fromMatrix(Vector3.zero, xAxis, yAxis, zAxis)
		local local_ = R:Inverse() * Rh
		out[w.joint] = transformFor(hilt, local_)
		local _, ang = (rot(hilt.C0):Inverse() * local_ * rot(hilt.C1)):ToAxisAngle()
		diag.wrist = math.deg(ang)
	end

	-- left arm
	local ls = mot["Left Arm"]
	local lpT, lpA = ls.C0.Position, ls.C1.Position
	local lvArm = V(0, -1, 0) - lpA
	local lTarget, lFront = spec.l, spec.lf or V(0, 0, -1)
	if spec.lBlade then
		-- saber: the palm on the spine, lBlade studs along the blade from the grip
		local b = spec.b.Unit
		local spineDir = Rh * w.spine
		lTarget = handT + b * spec.lBlade + spineDir * 0.55
		lFront = b
	end
	local L = aim(lvArm, lTarget - lpT, lFront)
	out["Left Arm"] = transformFor(ls, L)
	diag.lReach = (lTarget - (lpT + L * lvArm)).Magnitude
	return out, diag
end

----------------------------------------------------------------------------
-- forward kinematics and clearance
----------------------------------------------------------------------------
-- part CFrames in HumanoidRootPart space for a set of transforms
function M.fk(class, tf)
	local rig = M.rig(class)
	local mot = motors(rig)
	local cf = { HumanoidRootPart = CFrame.identity }
	local order = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
	local w = WEAPON[class]
	if w then table.insert(order, w.joint) end
	for _, name in order do
		local m = mot[name]
		local p0 = cf[m.Part0.Name]
		cf[name] = p0 * m.C0 * (tf[name] or CFrame.identity) * m.C1:Inverse()
	end
	return cf
end

-- signed distance from point p to an oriented box (negative inside)
local function boxDist(p, cf, size)
	local q = cf:PointToObjectSpace(p)
	local h = size / 2
	local d = V(math.abs(q.X) - h.X, math.abs(q.Y) - h.Y, math.abs(q.Z) - h.Z)
	local outside = V(math.max(d.X, 0), math.max(d.Y, 0), math.max(d.Z, 0)).Magnitude
	local inside = math.min(math.max(d.X, d.Y, d.Z), 0)
	return outside + inside
end

local HEAD_SIZE = V(1.25, 1.25, 1.25) -- the R6 head mesh, not its 2x1x1 part box
local TORSO_SIZE = V(2, 2, 1)

-- clearance report for one pose
function M.clearance(class, tf)
	local rig = M.rig(class)
	local cf = M.fk(class, tf)
	local res = {}
	local function segMin(a, b, radius, boxCf, size)
		local best = math.huge
		for i = 0, 20 do
			local p = a:Lerp(b, i / 20)
			best = math.min(best, boxDist(p, boxCf, size) - radius)
		end
		return best
	end
	local w = WEAPON[class]
	if w then
		local held = rig.HeldWeapon
		local hilt = held.PrimaryPart
		local hcf = cf[w.joint]
		local tip = hcf * hilt.Tip.Position
		local base = hcf * hilt.Base.Position
		local bladeRadius = 0.12
		res.bladeHead = segMin(base, tip, bladeRadius, cf.Head, HEAD_SIZE)
		res.bladeTorso = segMin(base, tip, bladeRadius, cf.Torso, TORSO_SIZE)
		res.bladeLArm = segMin(base, tip, bladeRadius, cf["Left Arm"], V(1, 2, 1))
		res.tipY = tip.Y
		res.tip = (cf.Torso:PointToObjectSpace(tip))
	end
	-- arms against the head and torso: points over each arm's lower box (its whole
	-- cross-section), against the head as the round R6 head (cylinder r 0.62) and
	-- the torso box. Negative = how deep the arm's surface sinks in.
	local function headDist(p)
		local q = cf.Head:PointToObjectSpace(p)
		local radial = math.sqrt(q.X * q.X + q.Z * q.Z) - 0.62
		local vertical = math.abs(q.Y) - 0.6
		if radial > 0 and vertical > 0 then return math.sqrt(radial * radial + vertical * vertical) end
		return math.max(radial, vertical)
	end
	for _, arm in { "Right Arm", "Left Arm" } do
		local hBest, tBest = math.huge, math.huge
		for yi = 0, 7 do
			local y = -0.3 - 0.7 * yi / 7
			for _, x in { -0.5, 0, 0.5 } do
				for _, z in { -0.5, 0, 0.5 } do
					local p = cf[arm] * V(x, y, z)
					hBest = math.min(hBest, headDist(p))
					if y <= -0.6 then tBest = math.min(tBest, boxDist(p, cf.Torso, TORSO_SIZE)) end
				end
			end
		end
		res[arm .. "Head"] = hBest
		res[arm .. "Torso"] = tBest
	end
	-- the two arms against each other (crossed wrists): deepest left-arm point in the right arm
	local deep = math.huge
	for yi = 0, 7 do
		for _, x in { -0.5, 0, 0.5 } do
			for _, z in { -0.5, 0, 0.5 } do
				deep = math.min(deep, boxDist(cf["Left Arm"] * V(x, -0.3 - 0.7 * yi / 7, z), cf["Right Arm"], V(1, 2, 1)))
			end
		end
	end
	res.ArmArm = deep
	return res, cf
end

----------------------------------------------------------------------------
-- keyframe sequences
----------------------------------------------------------------------------
local EASE = {
	out = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.Out },
	inout = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut },
	linear = { Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In },
}

local function keyframe(class, time, tf, ease, marker)
	local w = WEAPON[class]
	local kf = Instance.new("Keyframe")
	kf.Time = time
	local function pose(name, parent, weight)
		local p = Instance.new("Pose")
		p.Name = name
		p.CFrame = tf[name] or CFrame.identity
		p.Weight = weight
		local e = EASE[ease or "inout"]
		p.EasingStyle, p.EasingDirection = e[1], e[2]
		p.Parent = parent
		return p
	end
	local root = pose("HumanoidRootPart", kf, 0)
	local torso = pose("Torso", root, 1)
	pose("Head", torso, 1)
	local ra = pose("Right Arm", torso, 1)
	pose("Left Arm", torso, 1)
	if w then pose(w.joint, ra, 1) end
	if marker then
		local m = Instance.new("KeyframeMarker")
		m.Name = marker
		m.Value = ""
		m.Parent = kf
	end
	return kf
end

-- breathing: the hold pose with the chest lifted a touch and the guard risen
local function breathe(spec, k)
	local s = table.clone(spec)
	s.torso = { spec.torso[1] - 0.025 * k, spec.torso[2], spec.torso[3] }
	s.head = { spec.head[1] + 0.02 * k, spec.head[2], spec.head[3] }
	s.r = spec.r + V(0, 0.05 * k, 0)
	if spec.b then s.b = (spec.b + V(0, 0.04 * k, 0)) end
	if spec.l then s.l = spec.l + V(0, 0.04 * k, 0) end
	return s
end

local function merged(hold, key)
	local s = table.clone(key)
	for k, v in hold do if s[k] == nil and k ~= "lBlade" and k ~= "l" then s[k] = v end end
	-- the left hand: an explicit key wins, else the hold's
	if key.l == nil and key.lBlade == nil then s.l, s.lBlade, s.lf = hold.l, hold.lBlade, hold.lf end
	if key.r == nil then s.r, s.b, s.rf = hold.r, hold.b, hold.rf end
	return s
end

M.CLIP_NAMES = { Hold = "GuardHold", Parry = "GuardParry", ParryAlt = "GuardParryAlt", Impact = "GuardImpact" }

function M.build()
	local store = game.ServerStorage:FindFirstChild("_GuardClips")
	if store then store:Destroy() end
	store = Instance.new("Folder")
	store.Name = "_GuardClips"
	store.Parent = game.ServerStorage
	local clips, diags = {}, {}
	for _, class in { "Fist", "Sword", "Saber" } do
		local spec = P[class]
		local folder = Instance.new("Folder")
		folder.Name = class
		folder.Parent = store
		clips[class] = {}
		diags[class] = {}
		local holdTf, holdDiag = M.solve(class, spec.hold)

		-- Hold: loop, Action
		local ks = Instance.new("KeyframeSequence")
		ks.Name = class .. "GuardHold"
		ks.Loop = true
		ks.Priority = Enum.AnimationPriority.Action
		local holdLength = spec.holdLength or M.HOLD_LENGTH
		keyframe(class, 0, holdTf, "inout").Parent = ks
		local midTf, midDiag = M.solve(class, breathe(spec.hold, spec.bounce or 1))
		keyframe(class, holdLength / 2, midTf, "inout").Parent = ks
		keyframe(class, holdLength, holdTf, "inout").Parent = ks
		ks.Parent = folder
		clips[class].Hold = ks
		diags[class].Hold = { { t = 0, tf = holdTf, d = holdDiag }, { t = holdLength / 2, tf = midTf, d = midDiag } }

		for clipKey, specKey in { Parry = "parry", ParryAlt = "parryAlt", Impact = "impact" } do
			local k = Instance.new("KeyframeSequence")
			k.Name = class .. M.CLIP_NAMES[clipKey]
			k.Loop = false
			k.Priority = Enum.AnimationPriority.Action2
			local list = { { t = 0, tf = holdTf, d = holdDiag } }
			local firstEase = if clipKey == "Impact" then "out" else "linear"
			keyframe(class, 0, holdTf, firstEase).Parent = k
			for _, key in spec[specKey] do
				local s = merged(spec.hold, key)
				local tf, d = M.solve(class, s)
				local marker = (clipKey ~= "Impact" and math.abs(key.t - spec.contact) < 1e-6) and "Contact" or nil
				keyframe(class, key.t, tf, key.ease or "inout", marker).Parent = k
				table.insert(list, { t = key.t, tf = tf, d = d })
			end
			local len = spec.length[specKey]
			keyframe(class, len, holdTf, "inout").Parent = k
			table.insert(list, { t = len, tf = holdTf, d = holdDiag })
			k.Parent = folder
			clips[class][clipKey] = k
			diags[class][clipKey] = list
		end
	end
	M.lastDiags = diags
	return clips, diags
end

function M.qa()
	local lines = {}
	local worst = {}
	for _, class in { "Fist", "Sword", "Saber" } do
		for _, clip in { "Hold", "Parry", "ParryAlt", "Impact" } do
			for _, e in M.lastDiags[class][clip] do
				local c = M.clearance(class, e.tf)
				local parts = { string.format("%s %s t=%.2f", class, clip, e.t) }
				if e.d.wrist then table.insert(parts, string.format("wrist=%.0f", e.d.wrist)) end
				table.insert(parts, string.format("rReach=%.2f lReach=%.2f", e.d.rReach, e.d.lReach))
				for _, k in { "bladeHead", "bladeTorso", "bladeLArm", "Right ArmHead", "Left ArmHead", "Right ArmTorso", "Left ArmTorso", "ArmArm" } do
					if c[k] then table.insert(parts, string.format("%s=%.2f", k:gsub(" ", ""), c[k])) end
				end
				if c.tip then table.insert(parts, string.format("tip=(%.1f,%.1f,%.1f)", c.tip.X, c.tip.Y, c.tip.Z)) end
				table.insert(lines, table.concat(parts, " "))
			end
		end
	end
	return table.concat(lines, "\n")
end

-- play each clip on its rig through the Animator and compare the stepped transforms
-- with the key poses at the key times
function M.play(clips)
	local KSP = game:GetService("KeyframeSequenceProvider")
	local lines = {}
	for class, set in clips do
		local rig = M.rig(class)
		local animator = rig.Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", rig.Humanoid)
		local mot = motors(rig)
		for name, ks in set do
			local id = KSP:RegisterKeyframeSequence(ks)
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local track = animator:LoadAnimation(anim)
			local t0 = os.clock()
			while track.Length <= 0 and os.clock() - t0 < 5 do task.wait() end
			local worstErr, worstJoint, worstT = 0, "", 0
			for _, kf in ks:GetKeyframes() do
				track:Play(0, 1, 0)
				track.TimePosition = math.min(kf.Time, track.Length - 1e-3)
				animator:StepAnimations(1e-3)
				for _, pose in kf:GetDescendants() do
					if pose:IsA("Pose") and pose.Weight > 0 and mot[pose.Name] then
						local got = mot[pose.Name].Transform
						local _, a = (got:Inverse() * pose.CFrame):ToAxisAngle()
						if math.abs(a) > worstErr then worstErr, worstJoint, worstT = math.abs(a), pose.Name, kf.Time end
					end
				end
				track:Stop(0)
				animator:StepAnimations(1e-3)
			end
			local markers = {}
			for _, kf in ks:GetKeyframes() do
				for _, m in kf:GetMarkers() do table.insert(markers, string.format("%s@%.2f", m.Name, kf.Time)) end
			end
			table.insert(lines, string.format("%s %s len=%.2f loop=%s pri=%s markers=[%s] maxKeyErr=%.3f rad (%s @%.2f)",
				class, ks.Name, track.Length, tostring(ks.Loop), ks.Priority.Name, table.concat(markers, ","), worstErr, worstJoint, worstT))
			track:Destroy()
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n")
end

function M.cleanup()
	local f = workspace:FindFirstChild("_GuardClipRigs")
	if f then f:Destroy() end
	rigCache = {}
end

return M
