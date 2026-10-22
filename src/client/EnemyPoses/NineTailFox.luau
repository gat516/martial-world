--!strict
-- Nine-Tailed Fox boss (NineTailFoxB, built at SCALE 2.13): poses for the gaits, the
-- fifteen moves and the rest pose, on the shared Quadruped planting solver. Same pose API
-- as WolfKing.luau; no instances or gameplay decisions live here.
--
-- UNIT SPACE: pivots, root translations, paw targets and tail extension are at the old
-- roster fox's scale; EnemyAnimator applies the model's Scale (2.13) ONCE through
-- NineTailFox.scaled, which multiplies the JointRoot translation AND the tail slides.
--
-- Move            windup / active / pose recover   (server recover = active + pose recover)
-- Intro            2.2 / 0.2 / 0.8     howl-like opener, no damage
-- FangDance        0.65 / 0.12 / 1.08  snaps at release +0, +0.4, +0.8
-- TailSweep        0.9 / 0.25 / 0.85
-- TailLance        0.6 / 0.1 / 0.7
-- LanceFan         0.95 / 0.1 / 1.0    (P3 recover is longer: the pose holds its end)
-- TailSnare        0.85 / 0.1 / 0.8
-- RendingPounce    0.75 / dash 0.40 / 1.0  (active sampled by elapsed seconds vs input.duration)
-- FoxfireVolley    1.1 / 0.1 / 0.9
-- RootfireEruption 1.5 / 0.1 / 1.5
-- MoonLeap         0.4 / flight 0.6 / 0.4
-- MournfulScream   1.4 / 0.3 / 1.3
-- NineTailFall     1.8 / 0.1 / 1.9
-- VeilBreak        1.6 / 0.2 / 0.8
-- Stagger 0.28, Death 3.2 (both mirrored by input.side)
--
-- Contact is the END of windup (plus each barrage part's delay). Tails are keyed in
-- seconds from the windup start (s; release at s = windup) and sampled with a travelling
-- lag, so they never freeze; an extension attack drives its own tails from the parts'
-- delays (input.parts, else the table defaults below).
--
-- TAILS (RIGS.md, NineTailFoxB): Transform = rotation * CFrame.new(ExtendAxis * ExtendMax * e),
-- e a fraction 0..1. Base pitch -0.25..+0.5 and fan roll up to -t*0.55 are the tested range;
-- bends stay about 0.1 / 0.1 / 0.22 at full extension. Bigger base angles are used in
-- the windups and plunges and are covered by qa_quadruped_poses (clip / gap checks).

local Quadruped = require(script.Parent.Quadruped)

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input & { stage: number?, parts: { { tail: number, delay: number?, ext: number? } }? }
type Phase = Quadruped.Phase
type Leg = Quadruped.Leg
type Step = Quadruped.Step

local NineTailFox = {}
local V = Vector3.new
local I, TAU = CFrame.identity, Quadruped.TAU
local A, R = Quadruped.A, Quadruped.R
local with, paws, smooth, bump = Quadruped.with, Quadruped.paws, Quadruped.smooth, Quadruped.bump
local ALL, HIND, FRONT, NONE = Quadruped.ALL, Quadruped.HIND, Quadruped.FRONT, Quadruped.NONE
local clamp, sin, cos, abs = math.clamp, math.sin, math.cos, math.abs

local SCALE = 2.13
local BUILD = 2.4 -- the scale the tables below were measured at (final studs / BUILD = unit studs)
local function F(x: number, y: number, z: number): Vector3
	return V(x / BUILD, y / BUILD, z / BUILD)
end

------------------------------------------------------------------------------------
-- Skeleton (unit space; RIGS.md pivots / 2.13 equal these)

local P = {
	JointRoot = F(0, 6.5, 2.2), JointChest = F(0, 6.5, 1.0), JointTail = F(0, 7.7, 4.8),
	JointLegFL = F(-1.1, 6.3, -3.0), JointLowerLegFL = F(-1.1, 3.7, -3.0), JointPawFL = F(-1.1, 0.8, -3.0),
	JointLegFR = F(1.1, 6.3, -3.0), JointLowerLegFR = F(1.1, 3.7, -3.0), JointPawFR = F(1.1, 0.8, -3.0),
	JointLegBL = F(-1.15, 6.8, 3.8), JointLowerLegBL = F(-1.15, 3.7, 3.4), JointPawBL = F(-1.15, 1.6, 4.5),
	JointLegBR = F(1.15, 6.8, 3.8), JointLowerLegBR = F(1.15, 3.7, 3.4), JointPawBR = F(1.15, 1.6, 4.5),
}
local LEGS: { [string]: Leg } = {
	FL = { upper = "JointLegFL", mid = "JointLowerLegFL", foot = "JointPawFL", base = "JointChest", fold = -1, front = true, knee = 1 },
	FR = { upper = "JointLegFR", mid = "JointLowerLegFR", foot = "JointPawFR", base = "JointChest", fold = -1, front = true, knee = 1 },
	BL = { upper = "JointLegBL", mid = "JointLowerLegBL", foot = "JointPawBL", base = "JointRoot", fold = -1, front = false, knee = 1 },
	BR = { upper = "JointLegBR", mid = "JointLowerLegBR", foot = "JointPawBR", base = "JointRoot", fold = -1, front = false, knee = 1 },
}
local rig = Quadruped.new({
	P = P, root = "JointRoot", spine = "JointChest", legs = LEGS,
	sole = {
		front = { F(-0.55, -0.8, -1.1), F(0.55, -0.8, -1.1), F(-0.55, -0.8, 0.5), F(0.55, -0.8, 0.5) },
		hind = { F(-0.55, -1.6, -1.3), F(0.55, -1.6, -1.3), F(-0.55, -1.6, 0.3), F(0.55, -1.6, 0.3) },
	},
	curl = { front = -0.8, hind = -0.5 },
	lift = 0.3,
})

------------------------------------------------------------------------------------
-- Tails: layout in unit studs (nine_tail_fox_boss_tails.luau, final studs / BUILD)

local TL = { root = F(0, 8.1, 5.8), spread = 1.15, len = { 7.0, 8.0, 8.0, 8.5 }, ovl = { 0.85, 0.85, 0.95 }, full = 0.3 }
local DIR: { Vector3 } = {}
for i = 1, 9 do
	local a = (i - 5) / 4 * TL.spread
	DIR[i] = V(sin(a) * 1.05, cos(a) * 0.85 + 0.15, if i % 2 == 1 then 0.7 else 0.35).Unit
end
local LAY = {}
do
	local L, O = TL.len, TL.ovl
	LAY.baseE = L[1]
	local midS = L[1] - O[1] * L[2]
	LAY.midE = midS + L[2]
	local tipS = LAY.midE - O[2] * L[3]
	LAY.tipE = tipS + L[3]
	local whipS = LAY.tipE - O[3] * L[4]
	LAY.whipE = whipS + L[4]
	LAY.extMid = (L[1] - TL.full * L[2] - midS) / BUILD
	LAY.extTip = (LAY.midE - TL.full * L[3] - tipS) / BUILD
	LAY.extWhip = (LAY.tipE - TL.full * L[4] - whipS) / BUILD
	for _, k in { "baseE", "midE", "tipE", "whipE" } do
		LAY[k] = LAY[k] / BUILD
	end
end
local EXT = { LAY.extMid, LAY.extTip, LAY.extWhip }
-- per tail (defaults above; NineTailFox.configure(model) replaces them from the rig's own
-- ExtendAxis / ExtendMax attributes and pivots, in unit studs, so a rebuilt tail needs no edit here)
local aimCache: { [string]: Q } = {}
local EXTI: { { number } } = {}
local LAYI: { { [string]: number } } = {}
for i = 1, 9 do
	EXTI[i] = table.clone(EXT)
	LAYI[i] = { baseE = LAY.baseE, midE = LAY.midE, tipE = LAY.tipE, whipE = LAY.whipE }
end

type Q = { p: number, w: number, r: number, a: number, b: number, c: number, la: number, lb: number, lc: number, e: number }
type Shape = (i: number, ctx: any) -> Q
local QKEYS = { "p", "w", "r", "a", "b", "c", "la", "lb", "lc", "e" }
local function zeroQ(): Q
	return { p = 0, w = 0, r = 0, a = 0, b = 0, c = 0, la = 0, lb = 0, lc = 0, e = 0 }
end
local function lerpQ(x: Q, y: Q, k: number): Q
	local o: any = {}
	for _, key in QKEYS do
		o[key] = (x :: any)[key] + ((y :: any)[key] - (x :: any)[key]) * k
	end
	return o
end

-- the rebuilt tails hide the lance inside the brush at low extension: keep the whip's bend small
-- until the tail has grown out (pitch 0.12 / roll 0.06 below e = 0.3, easing out to 0.47 / 0.31)
local function whipBend(q: Q): (number, number)
	local k = clamp((q.e - 0.3) / 0.4, 0, 1)
	return clamp(q.c, -(0.12 + 0.35 * k), 0.12 + 0.35 * k), clamp(q.lc, -(0.06 + 0.25 * k), 0.06 + 0.25 * k)
end

-- the tail's joints from its parameters: yaw sweep * pitch * fan roll on the base,
-- then (rotation * slide) on each telescoping joint
local function tailJoints(out: Pose, i: number, q: Q)
	local d = DIR[i]
	local n = "JointTail" .. i
	out[n] = CFrame.Angles(0, q.w, 0) * CFrame.Angles(q.p, 0, q.r)
	local e = clamp(q.e, 0, 1)
	local x = EXTI[i]
	out[n .. "Mid"] = CFrame.Angles(q.a, 0, q.la) * CFrame.new(d * (e * x[1]))
	out[n .. "Tip"] = CFrame.Angles(q.b, 0, q.lb) * CFrame.new(d * (e * x[2]))
	local wc, wl = whipBend(q)
	out[n .. "Whip"] = CFrame.Angles(wc, 0, wl) * CFrame.new(d * (e * x[3]))
end

-- Per tail rig data in unit model space (ground Y 0, the model at the origin): the joint pivots
-- { base, mid, tip, whip, flame centre } and, per segment, its visible parts as boxes in the
-- segment's rest joint frame ({ offset CFrame, half size }). Defaults lie along DIR; configure()
-- reads the real ones from the template.
local PIV: { { Vector3 } } = {}
local BOX: { { { { any } } } } = {}
for i = 1, 9 do
	local d, L = DIR[i], LAYI[i]
	PIV[i] = { TL.root, TL.root + d * L.baseE, TL.root + d * L.midE, TL.root + d * L.tipE, TL.root + d * L.whipE }
	BOX[i] = { {}, {}, {}, { { CFrame.new(d * (L.whipE - L.tipE)), V(0.3, 0.3, 0.3) } } }
end

-- forward kinematics of one tail (unit space, model frame): the four joint frames after their
-- Transforms, for the pose's root and hub. Used to plant the plunging tails, by the floor guard
-- and by the QA.
local function hubW(pose: Pose): CFrame
	return CFrame.new(P.JointRoot) * (pose.JointRoot or I) * CFrame.new(P.JointTail - P.JointRoot) * (pose.JointTail or I)
end
local function tailRootW(pose: Pose): CFrame
	return hubW(pose) * CFrame.new(TL.root - P.JointTail)
end
local function tailFrames(i: number, pose: Pose, q: Q): (CFrame, CFrame, CFrame, CFrame)
	local d, pv, x = DIR[i], PIV[i], EXTI[i]
	local e = clamp(q.e, 0, 1)
	local f0 = hubW(pose) * CFrame.new(pv[1] - P.JointTail) * CFrame.Angles(0, q.w, 0) * CFrame.Angles(q.p, 0, q.r)
	local f1 = f0 * CFrame.new(pv[2] - pv[1]) * CFrame.Angles(q.a, 0, q.la) * CFrame.new(d * (e * x[1]))
	local f2 = f1 * CFrame.new(pv[3] - pv[2]) * CFrame.Angles(q.b, 0, q.lb) * CFrame.new(d * (e * x[2]))
	local wc, wl = whipBend(q)
	local f3 = f2 * CFrame.new(pv[4] - pv[3]) * CFrame.Angles(wc, 0, wl) * CFrame.new(d * (e * x[3]))
	return f0, f1, f2, f3
end
local function tailEnd(i: number, pose: Pose, q: Q): Vector3
	local _, _, _, f3 = tailFrames(i, pose, q)
	return f3 * (PIV[i][5] - PIV[i][4])
end
-- the lowest point of any part of tail i (unit studs above the ground)
local function tailLow(i: number, pose: Pose, q: Q): number
	local fs = { tailFrames(i, pose, q) }
	local lo = math.huge
	for k = 1, 4 do
		local f = fs[k]
		for _, b in BOX[i][k] do
			local cf, h = f * b[1], b[2]
			local y = cf.Y - (abs(cf.RightVector.Y) * h.X + abs(cf.UpVector.Y) * h.Y + abs(cf.LookVector.Y) * h.Z)
			if y < lo then
				lo = y
			end
		end
	end
	return lo
end
-- The head guard. The head sits right over the fore legs, so a head dipped low, a forebody
-- pitched down or fore legs folded up under a rear (plus the follow-through's overshoot) can
-- push the muzzle, jaw or ruff into the forearms. After the legs are planted, the guard tests
-- the head side (Neck, Head, Jaw) against the fore legs with the rig's real boxes and, if they
-- meet, lifts the neck and head by the least amount that clears them. configure() reads the
-- boxes; without it the guard is off.
type Box = { any } -- { offset CFrame in the segment's joint frame, half size, bounding radius }
local BODY: { piv: { [string]: Vector3 }, parent: { [string]: string? }, boxes: { [string]: { Box } } } = { piv = {}, parent = {}, boxes = {} }
local GUARD_HEAD = { "JointNeck", "JointHead", "JointJaw" }
local GUARD_LEGS = { "JointLegFL", "JointLowerLegFL", "JointPawFL", "JointLegFR", "JointLowerLegFR", "JointPawFR" }
local guardOn = false

local function bodyFrames(pose: Pose, names: { string }, out: { [string]: CFrame })
	local function frame(name: string): CFrame
		local f = out[name]
		if f then
			return f
		end
		local parent = BODY.parent[name]
		if parent then
			f = frame(parent) * CFrame.new(BODY.piv[name] - BODY.piv[parent]) * (pose[name] or I)
		else
			f = CFrame.new(BODY.piv[name]) * (pose[name] or I)
		end
		out[name] = f
		return f
	end
	for _, n in names do
		frame(n)
	end
end

-- oriented box overlap depth (positive = overlapping by that much), as the QA measures it
local function boxDepth(ca: CFrame, ea: Vector3, cb: CFrame, eb: Vector3): number
	local axA = { ca.RightVector, ca.UpVector, ca.LookVector }
	local axB = { cb.RightVector, cb.UpVector, cb.LookVector }
	local d = cb.Position - ca.Position
	local best = math.huge
	local function test(ax: Vector3)
		local ra = abs(axA[1]:Dot(ax)) * ea.X + abs(axA[2]:Dot(ax)) * ea.Y + abs(axA[3]:Dot(ax)) * ea.Z
		local rb = abs(axB[1]:Dot(ax)) * eb.X + abs(axB[2]:Dot(ax)) * eb.Y + abs(axB[3]:Dot(ax)) * eb.Z
		best = math.min(best, ra + rb - abs(d:Dot(ax)))
	end
	for a = 1, 3 do
		test(axA[a])
		test(axB[a])
		if best < 0 then
			return best
		end
	end
	for a = 1, 3 do
		for b = 1, 3 do
			local c = axA[a]:Cross(axB[b])
			if c.Magnitude > 1e-4 then
				test(c.Unit)
				if best < 0 then
					return best
				end
			end
		end
	end
	return best
end

-- the deepest overlap between the head side and the fore legs (unit studs)
local function headPen(pose: Pose, legFrames: { [string]: CFrame }): number
	local fr = table.clone(legFrames)
	for _, n in GUARD_HEAD do
		fr[n] = nil
	end
	bodyFrames(pose, GUARD_HEAD, fr)
	local worst = -math.huge
	local legBoxes = {}
	for _, ln in GUARD_LEGS do
		for _, b in BODY.boxes[ln] or {} do
			table.insert(legBoxes, { fr[ln] * b[1], b[2], b[3], b })
		end
	end
	for _, hn in GUARD_HEAD do
		for _, hb in BODY.boxes[hn] or {} do
			local hc = fr[hn] * hb[1]
			for _, lb in legBoxes do
				-- pairs that already touch at rest (the ruff over the shoulders) are not clips
				if not (hb[4] and hb[4][lb[4]]) and (hc.Position - lb[1].Position).Magnitude < hb[3] + lb[3] then
					local dd = boxDepth(hc, hb[2], lb[1], lb[2])
					if dd > worst then
						worst = dd
					end
				end
			end
		end
	end
	return worst
end

local GUARD_SLACK = 0.02
local function guardHead(pose: Pose)
	if not guardOn then
		return
	end
	local legFrames: { [string]: CFrame } = {}
	bodyFrames(pose, GUARD_LEGS, legFrames)
	if headPen(pose, legFrames) <= GUARD_SLACK then
		return
	end
	local neck0, head0 = pose.JointNeck or I, pose.JointHead or I
	local function at(k: number): number
		pose.JointNeck = A(0.55 * k) * neck0
		pose.JointHead = head0 * A(0.45 * k)
		return headPen(pose, legFrames)
	end
	local lo, hi = 0, 1
	if at(hi) > GUARD_SLACK then
		-- can't clear it by lifting: take the lift that leaves the least overlap
		local best, bestK = math.huge, 0
		for k = 0, 1, 0.125 do
			local p = at(k)
			if p < best then
				best, bestK = p, k
			end
		end
		at(bestK)
		return
	end
	for _ = 1, 7 do
		local mid = (lo + hi) / 2
		if at(mid) > GUARD_SLACK then
			lo = mid
		else
			hi = mid
		end
	end
	at(hi)
end
NineTailFox.guardHead = guardHead
NineTailFox.headPen = function(pose: Pose): number
	local fr = {}
	bodyFrames(pose, GUARD_LEGS, fr)
	return headPen(pose, fr)
end
function NineTailFox.setGuard(on: boolean)
	guardOn = on and BODY.piv.JointNeck ~= nil
end

local function readBody(motors: { [string]: Motor6D }, segParts: { [string]: { BasePart } }, origin: Vector3, sc: number)
	local byPart1: { [BasePart]: string } = {}
	for name, m in motors do
		if not string.find(name, "^JointTail%d") and m.Part1 then
			byPart1[m.Part1 :: BasePart] = name
		end
	end
	for name, m in motors do
		if not string.find(name, "^JointTail%d") and m.Part0 and m.Part1 then
			local pw = (m.Part0 :: BasePart).CFrame:PointToWorldSpace(m.C0.Position)
			BODY.piv[name] = (pw - origin) / sc
			BODY.parent[name] = byPart1[m.Part0 :: BasePart]
			local list = {}
			local frame = CFrame.new(pw)
			for _, part in segParts[(m.Part1 :: BasePart).Name] or {} do
				local s = part.Size
				if math.min(s.X, s.Y, s.Z) >= 0.3 then -- eyes, liners and marks don't collide
					local off = frame:ToObjectSpace(part.CFrame)
					table.insert(list, { off - off.Position + off.Position / sc, s / (2 * sc), s.Magnitude / (2 * sc) })
				end
			end
			BODY.boxes[name] = list
		end
	end
	guardOn = BODY.piv.JointNeck ~= nil and BODY.piv.JointLegFL ~= nil
	if guardOn then
		-- mark the head/leg box pairs that overlap at rest
		local fr = {}
		bodyFrames({}, GUARD_LEGS, fr)
		bodyFrames({}, GUARD_HEAD, fr)
		for _, hn in GUARD_HEAD do
			for _, hb in BODY.boxes[hn] or {} do
				hb[4] = {}
				for _, ln in GUARD_LEGS do
					for _, lb in BODY.boxes[ln] or {} do
						if boxDepth(fr[hn] * hb[1], hb[2], fr[ln] * lb[1], lb[2]) > 0 then
							hb[4][lb] = true
						end
					end
				end
			end
		end
	end
end

-- Reads the tails from a rig (any Instance holding the Motor6Ds): ExtendAxis / ExtendMax on each
-- Mid, Tip and Whip motor, pivots from the motors' rest positions, the flame centre from the
-- TailTip<i>_FX attachment and every visible tail part's box. Call once with the model template
-- (unposed) before sampling; `scale` is the model's Scale attribute. Without it the built-in 2.13
-- layout is used.
function NineTailFox.configure(model: Instance, scale: number?)
	local sc = scale or (model:GetAttribute("Scale") :: number?) or SCALE
	local motors: { [string]: Motor6D } = {}
	local segParts: { [string]: { BasePart } } = {}
	local hrp: BasePart? = nil
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") then
			motors[m.Name] = m
		elseif m:IsA("BasePart") then
			if m.Name == "HumanoidRootPart" then
				hrp = m
			elseif m.Transparency < 1 then
				local seg = (m:GetAttribute("Segment") :: string?) or m.Name
				segParts[seg] = segParts[seg] or {}
				table.insert(segParts[seg], m)
			end
		end
	end
	if not hrp then
		return
	end
	-- the model's origin: under the HRP on the ground (the HRP rests 2.6 unit studs up)
	local origin = (hrp :: BasePart).Position - V(0, 2.6 * sc, 0)
	local function pivot(m: Motor6D): Vector3
		return (m.Part0 :: BasePart).CFrame:PointToWorldSpace(m.C0.Position)
	end
	for i = 1, 9 do
		local base, mid, tip, whip = motors["JointTail" .. i], motors["JointTail" .. i .. "Mid"], motors["JointTail" .. i .. "Tip"], motors["JointTail" .. i .. "Whip"]
		if base and mid and tip and whip then
			local axis = mid:GetAttribute("ExtendAxis") :: Vector3?
			if axis then
				DIR[i] = axis.Unit
			end
			EXTI[i] = {
				((mid:GetAttribute("ExtendMax") :: number?) or EXT[1] * sc) / sc,
				((tip:GetAttribute("ExtendMax") :: number?) or EXT[2] * sc) / sc,
				((whip:GetAttribute("ExtendMax") :: number?) or EXT[3] * sc) / sc,
			}
			local pw: { Vector3 } = {}
			for k, m in { base, mid, tip, whip } do
				pw[k] = pivot(m)
			end
			local att = model:FindFirstChild("TailTip" .. i .. "_FX", true) :: Attachment?
			pw[5] = if att then att.WorldPosition else pw[4] + DIR[i] * (LAYI[i].whipE - LAYI[i].tipE) * sc
			local p0, d = pw[1], DIR[i]
			LAYI[i] = { baseE = (pw[2] - p0):Dot(d) / sc, midE = (pw[3] - p0):Dot(d) / sc, tipE = (pw[4] - p0):Dot(d) / sc, whipE = (pw[5] - p0):Dot(d) / sc }
			for k = 1, 5 do
				PIV[i][k] = (pw[k] - origin) / sc
			end
			for k, m in { base, mid, tip, whip } do
				local list = {}
				local frame = CFrame.new(pw[k])
				for _, part in segParts[(m.Part1 :: BasePart).Name] or {} do
					local off = frame:ToObjectSpace(part.CFrame)
					table.insert(list, { off - off.Position + off.Position / sc, part.Size / (2 * sc) })
				end
				BOX[i][k] = list
			end
		end
	end
	readBody(motors, segParts, origin, sc)
	table.clear(aimCache)
end
NineTailFox.tailEnd = tailEnd
NineTailFox.tailLow = tailLow
NineTailFox.TAIL_DIR = DIR

local JOINTS: { string } = {
	"JointRoot", "JointChest", "JointNeck", "JointHead", "JointJaw", "JointEarL", "JointEarR",
	"JointLegFL", "JointLowerLegFL", "JointPawFL", "JointLegFR", "JointLowerLegFR", "JointPawFR",
	"JointLegBL", "JointLowerLegBL", "JointPawBL", "JointLegBR", "JointLowerLegBR", "JointPawBR",
	"JointTail",
}
for i = 1, 9 do
	for _, suffix in { "", "Mid", "Tip", "Whip" } do
		table.insert(JOINTS, "JointTail" .. i .. suffix)
	end
end
NineTailFox.JOINTS = JOINTS

-- Tail shape: fan roll -t*fan (widened per stage), base pitch (lift + outer + odd extras),
-- yaw sweep, an S curve within the tested bends, extension. Stateless.
local function shp(o: { [string]: any }): Shape
	return function(i, ctx)
		local t = (i - 5) / 4
		local widen = 1 + 0.12 * (((ctx and ctx.stage) or 1) - 1)
		local curl, hook = o.curl or 0.6, o.hook or 0
		local e = (if type(o.e) == "function" then o.e(i, ctx) else o.e) or 0
		local lim = 1 - 0.45 * e
		local q: any = {
			p = (o.lift or 0) + (o.out or 0) * abs(t) + (o.odd or 0) * (i % 2) + (o.fn and o.fn(i, ctx) or 0),
			w = (o.yaw or 0) + (o.spread or 0) * t,
			r = -t * (o.fan or 0.3) * widen + (o.roll or 0),
			a = (-0.07 * curl + 0.05 * hook) * lim,
			b = (0.09 * curl + 0.06 * hook) * lim,
			c = (-0.2 * curl + 0.1 * hook) * lim,
			la = 0.05 * curl * t * lim, lb = -0.06 * curl * t * lim, lc = 0.1 * curl * t * lim,
			e = e,
		}
		return q
	end
end
local REST_T = shp({ fan = 0.3, lift = 0, odd = 0.02 })

------------------------------------------------------------------------------------
-- Body pose vocabulary

local function B(o: { [string]: any }): Pose
	local p: Pose = {
		JointRoot = R(o.y or 0, o.pitch or 0, o.z or 0, o.yaw or 0, o.roll or 0),
		JointChest = A(o.ch or 0, o.chy or 0, o.chr or 0),
		JointNeck = A(o.n or 0.06, o.ny or 0, o.nr or 0),
		JointHead = A(o.h or -0.1, o.hy or 0, o.hr or 0.1),
		JointJaw = A(o.j or -0.03),
		JointEarL = A(o.e or 0.1, 0, (o.ef or 0.2) + (o.el or 0)),
		JointEarR = A(o.e or 0.1, 0, -(o.ef or 0.2) - (o.er or 0)),
		JointTail = A((o.t or 0.04) - 1.0 * math.max(0, o.pitch or 0), o.ty or 0), -- a rear lifts the tail hub with it
	}
	if o.legs then
		for k, v in o.legs do
			p[k] = v
		end
	end
	return p
end
-- leg shorthands: upper pitch/roll, lower bend (negative folds the paw back and up), paw pitch
local function FL(a: number, lb: number?, pw: number?, roll: number?): Pose
	return { JointLegFL = A(a, 0, roll or 0), JointLowerLegFL = A(lb or 0), JointPawFL = A(pw or 0) }
end
local function FRr(a: number, lb: number?, pw: number?, roll: number?): Pose
	return { JointLegFR = A(a, 0, roll or 0), JointLowerLegFR = A(lb or 0), JointPawFR = A(pw or 0) }
end
local function BLg(a: number, lb: number?, pw: number?, roll: number?): Pose
	return { JointLegBL = A(a, 0, roll or 0), JointLowerLegBL = A(lb or 0), JointPawBL = A(pw or 0) }
end
local function BRg(a: number, lb: number?, pw: number?, roll: number?): Pose
	return { JointLegBR = A(a, 0, roll or 0), JointLowerLegBR = A(lb or 0), JointPawBR = A(pw or 0) }
end
local function merge(...: Pose): Pose
	local out: Pose = {}
	for _, p in { ... } do
		for k, v in p do
			out[k] = v
		end
	end
	return out
end
-- apply B() overrides on top of a base pose by rebuilding the options
local function over(base: Pose, o: { [string]: any }): Pose
	return with(base, B(o))
end

local STAND = B({})
local REACH0 = paws(0, 0)
local WIDE = paws(0, 0.1, 0.12, 0.14)

-- Curled: asleep, lying on its belly, head on the forepaws, tails wrapped round the flank
local function curledTails(i: number, _ctx: any): Q
	-- folded forward over the back like a blanket (tails lying on the floor would sink)
	local t = (i - 5) / 4
	local q = zeroQ()
	q.p = -1.55 - 0.06 * (i % 2)
	q.r = -t * 0.3
	q.a, q.b, q.c = -0.06, -0.08, -0.12
	return q
end
local CUR_O: { [string]: any } = { y = -1.78, pitch = -0.05, ch = 0.06, n = -0.3, h = -0.3, hr = 0.28, ny = 0.95, hy = 0.4, chy = 0.3, j = 0, e = 0.62, ef = 0.12, t = 0.5, ty = 0.3,
	legs = merge(FL(1.25, 0, -0.1, 0.12), FRr(1.2, 0, -0.1, -0.12), BLg(0.45, -1.5, 0.6, -0.85), BRg(0.35, -1.5, 0.6, 0.85)) }
local function curOver(o: { [string]: any }?): Pose
	local t = table.clone(CUR_O)
	for k, v in o or {} do
		t[k] = v
	end
	return rig.plant(B(t), NONE) -- floor clamp only: the legs are hand folded
end
local CURLED: Pose = curOver()
do
	for i = 1, 9 do
		tailJoints(CURLED, i, curledTails(i, nil))
	end
end
NineTailFox.Curled = CURLED
NineTailFox.CURLED_TAIL = curledTails

------------------------------------------------------------------------------------
-- Locomotion. Stance paws are planted and slide back at EXACTLY the ground speed (their
-- reach is solved by the shared IK); swing paws arc forward to touch down ahead. The
-- gait rate follows the speed, so paw travel always matches the root: no skating.

type Gait = { stance: number, offsets: { [string]: number }, rate: (number) -> number, legEff: number, bias: number, over: number, clearF: number, clearB: number }
local WALK: Gait = {
	stance = 0.72, offsets = { BL = 0, FL = 0.25, BR = 0.5, FR = 0.75 },
	rate = function(s) return clamp(1.1 + 0.14 * s, 1.2, 2.4) end,
	legEff = 2.3, bias = 0.0, over = 0.15, clearF = 0.34, clearB = 0.28,
}
local RUN: Gait = {
	stance = 0.3, offsets = { BL = 0, BR = 0.1, FL = 0.5, FR = 0.6 },
	rate = function(s) return clamp(0.75 + 0.052 * s, 0.9, 2.1) end,
	legEff = 2.3, bias = 0.04, over = 0.3, clearF = 0.46, clearB = 0.3,
}

local CIRC: Gait = table.clone(WALK)
CIRC.rate = function(s) return clamp(0.8 + 0.3 * s, 1.2, 3) end
CIRC.legEff = 2.3

local function legCycle(pose: Pose, swing: { [string]: any }, stance: { [string]: number }, reach: { [string]: Vector3 }, phase: number, speed: number, g: Gait, lat: number?)
	local half = (speed / SCALE) * (g.stance / g.rate(speed)) / 2 -- unit studs each side of the hip
	local cyc = phase / TAU % 1
	for tag, off in g.offsets do
		local front = tag == "FL" or tag == "FR"
		local x = (cyc - off) % 1
		local out = if tag == "BL" or tag == "FL" then -1 else 1
		local roll = if lat then 0 else out * (if front then 0.03 else 0.08)
		if x < g.stance then
			local s = x / g.stance
			stance[tag] = 1
			reach[tag] = if lat then V(lat * half * (2 * s - 1), 0, 0) else V(out * 0.03, 0, half * (2 * s - 1) - g.bias)
			pose[LEGS[tag].upper] = A(0, 0, roll)
		else
			-- swing: the paw is IK-placed too (so touchdown and lift-off meet the stance exactly), then
			-- lifted clear by bending the lower leg
			local s = (x - g.stance) / (1 - g.stance)
			local e = smooth(0, 1, s)
			local hump = math.sin(math.pi * s) ^ 2
			local lift = math.sin(math.pi * math.min(1, s * 1.15)) ^ 0.8
			local target = if lat then V(lat * half * (1 - 2 * e), 0, 0) else V(out * 0.03, 0, half * (1 - 2 * e) - g.bias - g.over * 0.5 * half * hump)
			pose[LEGS[tag].upper] = A(0, 0, roll)
			swing[tag] = { target = target, clear = (if front then g.clearF else g.clearB) * lift, flex = (if front then -0.8 else -0.5) * (if front then g.clearF else g.clearB) * lift }
		end
	end
end

-- plants the stance paws, then each swing paw (IK onto its arc, then lifted)
local function applyLegs(pose: Pose, swing: { [string]: any }, stance: { [string]: number }, reach: { [string]: Vector3 })
	rig.plantLegs(pose, stance, false, reach)
	for tag, sw in swing do
		rig.plantLegs(pose, { [tag] = 1 }, false, { [tag] = sw.target })
		rig.solveLeg(pose, LEGS[tag], 1, sw.clear, sw.flex)
	end
	guardHead(pose)
end

-- tails driven by a travelling wave: base pitch/roll and the small bends each lag the last
local function tailsWave(pose: Pose, shape: Shape, ctx: any, ph: number, spatial: number, ampP: number, ampR: number, ampW: number?)
	for i = 1, 9 do
		local q = shape(i, ctx)
		local f = ph - spatial * (i - 1)
		q.p += ampP * sin(f)
		q.r += ampR * sin(f + 1.1)
		q.w += (ampW or 0) * sin(f + 0.5)
		q.a += 0.05 * sin(f - 0.6)
		q.b += 0.06 * sin(f - 1.1)
		q.c += 0.11 * sin(f - 1.6)
		q.la += 0.06 * sin(f - 0.2)
		q.lb += 0.07 * sin(f - 0.7)
		q.lc += 0.12 * sin(f - 1.2)
		tailJoints(pose, i, q)
	end
end

local loops: { [string]: (number, number, Input?) -> Pose } = {}

function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = sin(clock * TAU / 4.4 + seed)
	local chest = sin(clock * TAU / 4.4 + seed - 0.4)
	local look = 0.16 * sin(clock * 0.27 + seed) + 0.06 * sin(clock * 0.71 + seed * 2)
	local lookLate = 0.16 * sin(clock * 0.27 + seed - 0.8) + 0.06 * sin(clock * 0.71 + seed * 2 - 1.0)
	local slot = math.floor(clock / 5)
	local at = slot * 5 + Quadruped.hash(slot, seed) * 2
	local ear = bump(clock, at, at + 0.3)
	local slot2 = math.floor(clock / 3.6)
	local at2 = slot2 * 3.6 + Quadruped.hash(slot2, seed + 3) * 2
	local earR = bump(clock, at2, at2 + 0.26)
	local shift = sin(clock * 0.33 + seed)
	-- the head sits low and tilted, curious, and slowly swaps the side it tilts to
	local tilt = 0.14 * sin(clock * 0.19 + seed * 1.7) + 0.06
	local pose = B({
		y = -0.01 + 0.014 * breath, yaw = 0.01 * shift, roll = 0.025 * shift,
		ch = 0.014 * chest, chy = 0.014 * sin(clock * 0.5 + seed), chr = -0.012 * shift,
		n = 0.04 + 0.014 * chest, ny = look, h = -0.14 + 0.014 * sin(clock * 0.9 + seed), hy = lookLate * 0.7, hr = tilt,
		j = -0.03 - 0.012 * math.max(0, sin(clock * 0.37 + seed)),
		e = 0.08 + 0.3 * ear, e2 = 0.08 + 0.26 * earR,
		t = 0.04 + 0.02 * breath, ty = 0.06 * sin(clock * 0.8),
	})
	pose.JointEarR = A(0.08 + 0.26 * earR, 0, -0.2)
	local fan = 0.3 + 0.05 * sin(clock * 0.55 + seed) + 0.03 * breath
	tailsWave(pose, shp({ fan = fan, lift = 0.02 * breath }), nil, clock * 1.5 + seed, 0.5, 0.1, 0.07, 0.04)
	local sway = 0.04 * shift
	return rig.plant(pose, ALL, { FL = V(0, 0, 0.02 * shift), FR = V(0, 0, -0.02 * shift), BL = V(sway * 0.4, 0, 0), BR = V(sway * 0.4, 0, 0) })
end

function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local pose: Pose = {}
	local steps: { [string]: any } = {}
	local stance: { [string]: number } = { FL = 0, FR = 0, BL = 0, BR = 0 }
	local reach: { [string]: Vector3 } = {}
	legCycle(pose, steps, stance, reach, phase, speed, WALK)
	local bob = sin(phase * 4)
	local chestDip = math.max(0, sin(phase * 2 - 0.5)) * 0.03
	-- a long glide: hips and shoulders swing against each other, the head carried low and tilted
	pose.JointRoot = R(-0.26 + 0.02 * bob, 0.012 * sin(phase * 2), 0, 0.04 * sin(phase - 0.3), 0.045 * sin(phase))
	pose.JointChest = A(chestDip - 0.01, 0.06 * sin(phase - 0.2), -0.04 * sin(phase))
	pose.JointNeck = A(0.0 + 0.03 * sin(phase * 4 - 0.9), 0.06 * sin(phase - 0.9))
	pose.JointHead = A(-0.16 - 0.025 * sin(phase * 4 - 1.7), 0.05 * sin(phase - 1.5), 0.1 + 0.05 * sin(phase * 0.5))
	pose.JointJaw = A(-0.03 - 0.015 * sin(phase * 4 - 2.2))
	pose.JointEarL, pose.JointEarR = A(0.15 + 0.05 * sin(phase * 4 - 2), 0, 0.2), A(0.15 + 0.05 * sin(phase * 4 - 2.6), 0, -0.2)
	pose.JointTail = A(0.08 + 0.03 * sin(phase * 4 - 1.1), 0.1 * sin(phase - 0.4))
	tailsWave(pose, shp({ fan = 0.3, lift = 0.1 }), nil, phase - 0.4, 0.5, 0.13, 0.09, 0.05)
	applyLegs(pose, steps, stance, reach)
	return pose
end

local function runPose(phase: number, speed: number, g: Gait): Pose
	local pose: Pose = {}
	local steps: { [string]: any } = {}
	local stance: { [string]: number } = { FL = 0, FR = 0, BL = 0, BR = 0 }
	local reach: { [string]: Vector3 } = {}
	legCycle(pose, steps, stance, reach, phase, speed, g)
	local cyc = phase / TAU % 1
	local flight = math.max(0, cos(TAU * 2 * (cyc - 0.46))) ^ 1.5
	local drive = cos(TAU * (cyc - 0.2))
	local heave = cos(TAU * (cyc - 0.35))
	local function lag(d: number): number
		return TAU * (cyc - d)
	end
	-- a long, low, flowing lope: the spine stretches and gathers, the head stays low
	pose.JointRoot = R(-0.3 + 0.12 * flight, 0.07 * drive - 0.03, 0, 0.02 * sin(TAU * cyc), 0.025 * sin(TAU * cyc * 2))
	pose.JointChest = A(-0.12 * heave, 0.03 * sin(TAU * cyc + 0.4), 0.025 * sin(TAU * cyc))
	pose.JointNeck = A(-0.2 + 0.1 * cos(lag(0.38)), 0.03 * sin(lag(0.15)))
	pose.JointHead = A(0.0 + 0.07 * cos(lag(0.45)), 0.03 * sin(lag(0.2)), 0.05)
	pose.JointJaw = A(-0.07 - 0.05 * math.max(0, cos(lag(0.5))))
	pose.JointEarL, pose.JointEarR = A(0.6 + 0.12 * cos(lag(0.5)), 0, 0.1), A(0.6 + 0.12 * cos(lag(0.56)), 0, -0.1)
	pose.JointTail = A(0.1 + 0.08 * cos(lag(0.42)), 0.06 * sin(TAU * cyc * 0.5))
	-- the tails stream behind in a long wave
	tailsWave(pose, shp({ fan = 0.16, lift = 0.32, out = 0.06, curl = 0.3 }), nil, TAU * cyc - 0.9, 0.55, 0.12, 0.08, 0.07)
	applyLegs(pose, steps, stance, reach)
	return pose
end
function loops.run(phase: number, speed: number, _input: Input?): Pose
	return runPose(phase, speed, RUN)
end

-- sidestepping while keeping the head on the target: stance paws slide sideways at the
-- ground speed (reach X), swing paws cross over
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local yaw = (input and input.targetYaw) or 0
	local pose: Pose = {}
	local steps: { [string]: any } = {}
	local stance: { [string]: number } = { FL = 0, FR = 0, BL = 0, BR = 0 }
	local reach: { [string]: Vector3 } = {}
	legCycle(pose, steps, stance, reach, phase, speed, CIRC, dir)
	local ny = clamp(yaw * 0.5, -0.4, 0.4)
	pose.JointRoot = R(-0.3, -0.02, 0, 0, 0.05 * dir)
	pose.JointChest = A(0, 0, -0.03 * dir)
	pose.JointNeck = A(0.0, ny)
	pose.JointHead = A(-0.14, clamp(yaw - ny, -0.4, 0.4), 0.12 * dir)
	pose.JointJaw = A(-0.04)
	pose.JointEarL, pose.JointEarR = A(0.2, 0, 0.2), A(0.2, 0, -0.2)
	pose.JointTail = A(0.06, 0.1 * dir)
	tailsWave(pose, shp({ fan = 0.32, lift = 0.04, yaw = -0.05 * dir }), nil, phase * 2, 0.5, 0.12, 0.09, 0.06)
	applyLegs(pose, steps, stance, reach)
	return pose
end

function NineTailFox.gaitRate(loop: string, speed: number, _scale: number?): number
	-- the rate is in real cycles/s (the swing and stance are laid out against SCALE), not
	-- divided again by the body scale
	if loop == "walk" then
		return TAU * WALK.rate(speed)
	elseif loop == "circle" then
		return TAU * CIRC.rate(speed)
	elseif loop == "run" then
		return TAU * RUN.rate(speed)
	end
	return 1
end
NineTailFox.GAIT = { WALK = WALK, RUN = RUN }

------------------------------------------------------------------------------------
-- Tail aiming. A tail's lance direction is solved, not guessed: elevation from the base
-- pitch (closed form for a tail with no roll), azimuth from the yaw sweep. az is radians
-- left of straight ahead (+ = the fox's left), el radians above horizontal.

local EASE = Quadruped.EASE
local function aimQ(i: number, az: number, el: number, e: number, hook: number?): Q
	local key = string.format("%d|%.3f|%.3f", i, az, el)
	local base = aimCache[key]
	if not base then
		local d = DIR[i]
		local phi = math.atan2(d.Z, d.Y)
		local p = -math.acos(clamp(sin(el), -1, 1)) - phi
		-- the azimuth of the end direction with no yaw, then the sweep that turns it onto az
		local v = CFrame.Angles(p, 0, 0) * d
		local az0 = math.atan2(-v.X, -v.Z)
		local w = (az - az0 + math.pi) % TAU - math.pi
		base = zeroQ()
		base.p, base.w = p, w
		aimCache[key] = base
	end
	local q = table.clone(base)
	q.e = e
	local h = hook or 0
	q.a, q.b, q.c = 0.05 * h, 0.06 * h, 0.1 * h
	return q
end
local function aimShape(azf: (number, any) -> number, el: number, e: number, hook: number?): Shape
	return function(i, ctx)
		return aimQ(i, azf(i, ctx), el, e, hook)
	end
end
NineTailFox.aimQ = aimQ

-- bisection on base pitch (roll 0) for the lance end to touch height tipY in this pose
local function groundQ(i: number, pose: Pose, az: number, e: number, tipY: number, keep: Q?): Q
	local q = zeroQ()
	q.e = e
	if keep then
		q.r, q.a, q.b, q.c, q.la, q.lb, q.lc = keep.r, keep.a, keep.b, keep.c, keep.la, keep.lb, keep.lc
	end
	local function y(p: number): number
		q.p = p
		return tailEnd(i, pose, q).Y
	end
	-- pitch for the lance end to reach tipY at the current yaw (end height falls as the pitch rises)
	local function solveP()
		local lo, hi = -0.6, 2.9
		if y(hi) > tipY then
			return hi
		elseif y(lo) < tipY then
			return lo
		end
		for _ = 1, 16 do
			local mid = (lo + hi) / 2
			if y(mid) > tipY then
				lo = mid
			else
				hi = mid
			end
		end
		return (lo + hi) / 2
	end
	-- the yaw turns about the (body-tilted) tail root: iterate pitch and yaw onto the height and azimuth
	local rootPos = tailRootW(pose).Position
	q.w = az - (math.atan2(-DIR[i].X, -DIR[i].Z)) -- a first guess
	for _ = 1, 4 do
		q.p = solveP()
		local w = q.w
		q.w = 0
		local v = tailEnd(i, pose, q) - rootPos
		q.w = (az - math.atan2(-v.X, -v.Z) + math.pi) % TAU - math.pi
		if abs(q.w - w) < 1e-3 then
			break
		end
	end
	q.p = solveP()
	return q
end
NineTailFox.groundQ = groundQ

------------------------------------------------------------------------------------
-- The move machinery

type TailSpec = {
	keys: { { any } }, -- { s, Shape, ease? }
	lag: number?, -- seconds each tail trails the previous (fades out through the recover)
	lagFn: ((number) -> number)?, -- explicit lag per tail instead
	wave: number?, -- amplitude of the always-on travelling wave
	atk: ((number, number, any) -> (number, Q?))?, -- tail i at s -> weight, params it blends toward
	ground: ((number, number, any) -> (number, number, number, number))?, -- -> weight, az, e, tipY
	floorSafe: Shape?, -- what a floor-clipping tail eases toward (default the rest shape)
	floor: number?, -- a tail whose lance end would dip under this height (unit studs) is eased toward its rest shape until it clears
}
type Variant = { windup: Phase, active: Phase, recover: Phase, tail: TailSpec, total: number }

local variants: { [string]: { [string]: Variant } } = {}
local moves: { [string]: { [string]: Phase } } = {}
local DUR: { [string]: { number } } = {}

-- a phase from keys given in SECONDS: { sec, pose, plant?, reach?, ease? }
local function ph(dur: number, keys: { { any } }, o: { [string]: any }?): Phase
	local out: { any } = {}
	local first = keys[1]
	if first[1] > 0 then
		table.insert(out, { t = 0, pose = first[2], plant = first[3] or ALL, reach = first[4] })
	end
	for _, k in keys do
		table.insert(out, { t = clamp(k[1] / dur, 0, 1), pose = k[2], plant = k[3] or ALL, reach = k[4], ease = k[5] })
	end
	local last = keys[#keys]
	if last[1] < dur then
		table.insert(out, { t = 1, pose = last[2], plant = last[3] or ALL, reach = last[4] })
	end
	return { duration = dur, keys = out, overlay = o and o.overlay, mirror = o and o.mirror, air = o and o.air }
end
local function K(sec: number, pose: Pose, plant: { string }?, reach: any?, ease: string?): { any }
	return { sec, pose, plant, reach, ease }
end

local function register(name: string, v: string, W: number, Act: number, Rec: number, windup: Phase, active: Phase, recover: Phase, tail: TailSpec)
	variants[name] = variants[name] or {}
	if tail.floor == nil and name ~= "MoonLeap" then
		tail.floor = 0.03 -- no tail part ever dips under the floor (the flip is lifted by the server, so it is exempt)
	end
	variants[name][v] = { windup = windup, active = active, recover = recover, tail = tail, total = W + Act + Rec }
	DUR[name] = { W, Act, Rec }
end

-- tail keys
local function TK(s: number, shape: Shape, ease: string?): { any }
	return { s, shape, ease }
end

-- default barrage parts by move and stage (the server's `input.parts` win)
type PartDef = { tail: number, delay: number, ext: number }
local function lanes(stage: number): (number, { number })
	return if stage >= 2 then 40 else 22, if stage >= 2 then { 1, 3, 5, 7, 9 } else { 3, 5, 7 }
end
local function defaultParts(move: string, stage: number): { PartDef }
	local out: { PartDef } = {}
	if move == "TailLance" or move == "TailSnare" then
		out[1] = { tail = 5, delay = 0, ext = 0.2 }
	elseif move == "LanceFan" then
		local _, tails = lanes(stage)
		for k, t in tails do
			table.insert(out, { tail = t, delay = (k - 1) * 0.18, ext = 0.2 })
		end
		if stage >= 3 then
			local n = #tails
			for k = n, 1, -1 do
				table.insert(out, { tail = tails[k], delay = n * 0.18 + 0.1 + (n - k) * 0.18, ext = 0.2 })
			end
		end
	elseif move == "NineTailFall" then
		for i = 1, 9 do
			table.insert(out, { tail = i, delay = 0.2 * (i - 1), ext = 0.2 })
		end
	end
	return out
end
local function partsOf(ctx: any, i: number): { PartDef }
	local list = ctx.parts or defaultParts(ctx.move, ctx.stage or 1)
	local out = {}
	for _, p in list do
		if p.tail == i then
			table.insert(out, { tail = i, delay = p.delay or 0, ext = p.ext or 0.2 })
		end
	end
	return out
end

local function snapUp(x: number): number
	x = clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- an extension attack's tail: coil from c0 to c1, then at each part's time extend fast
-- (ending on the hit), hold, then retract smoothly and hand back to the keyed shape
local function lanceAtk(W: number, o: { coil: Shape, aim: Shape, c0: number, c1: number, hold: number, ret: number }): (number, number, any) -> (number, Q?)
	return function(i: number, s: number, ctx: any)
		local parts = partsOf(ctx, i)
		if #parts == 0 then
			return 0, nil
		end
		local pulse, lastHold = 0, 0
		for _, p in parts do
			local t0 = W + p.delay
			local k = snapUp((s - (t0 - p.ext)) / p.ext) * (1 - smooth(t0 + o.hold, t0 + o.hold + o.ret, s))
			pulse = math.max(pulse, k)
			lastHold = math.max(lastHold, t0 + o.hold)
		end
		local w = smooth(o.c0, o.c1, s) * (1 - smooth(lastHold + o.ret * 0.5, lastHold + o.ret * 1.5, s))
		return w, lerpQ(o.coil(i, ctx), o.aim(i, ctx), pulse)
	end
end

------------------------------------------------------------------------------------
-- Sampling

local VARIANT: { [string]: string } = {}

local WAVE_HZ = 4.2
local function buildTails(pose: Pose, v: Variant, s: number, ctx: any, mirror: boolean)
	local spec = v.tail
	local W = DUR[ctx.move][1]
	local fade = if v.total <= W + DUR[ctx.move][2] + 0.001 then 1 else 1 - smooth(W + DUR[ctx.move][2], v.total, s)
	local keys = spec.keys
	local wave = spec.wave or 1
	local qs: { Q } = {}
	for n = 1, 9 do
		local i = if mirror then 10 - n else n
		local aw, aq = 0, nil
		if spec.atk then
			aw, aq = spec.atk(i, s, ctx)
		end
		local lag = ((if spec.lagFn then spec.lagFn(i) else (spec.lag or 0.03) * (i - 1)) * fade) * (1 - aw)
		local sl = s - lag
		local q = zeroQ()
		local function at(ss: number): Q
			if ss <= keys[1][1] then
				return keys[1][2](i, ctx)
			end
			local nk = #keys
			if ss >= keys[nk][1] then
				return keys[nk][2](i, ctx)
			end
			for k = 2, nk do
				if ss <= keys[k][1] then
					local a, b = keys[k - 1], keys[k]
					local alpha = EASE[b[3] or "inOut"]((ss - a[1]) / (b[1] - a[1]))
					return lerpQ(a[2](i, ctx), b[2](i, ctx), alpha)
				end
			end
			return keys[nk][2](i, ctx)
		end
		q = at(sl)
		local q1, q2, q3 = at(sl - 0.05), at(sl - 0.1), at(sl - 0.15)
		q.a, q.la, q.b, q.lb, q.c, q.lc = q1.a, q1.la, q2.b, q2.lb, q3.c, q3.lc
		if aq then
			q = lerpQ(q, aq, aw)
		end
		-- the always-on travelling wave, quieter on a tail that is doing something
		local f = s * WAVE_HZ - 0.6 * (i - 1)
		local k = wave * (1 - 0.8 * aw)
		q.p += 0.05 * k * sin(f)
		q.r += 0.04 * k * sin(f + 1.1)
		q.a += 0.04 * k * sin(f - 0.5)
		q.b += 0.05 * k * sin(f - 1.0)
		q.c += 0.09 * k * sin(f - 1.5)
		q.la += 0.05 * k * sin(f - 0.1)
		q.lb += 0.06 * k * sin(f - 0.6)
		q.lc += 0.1 * k * sin(f - 1.1)
		qs[n] = q
	end
	-- plunges: after the legs have set the root, solve the pitch that puts the lance end on the ground
	local solved: { [number]: boolean } = {}
	if spec.ground then
		for n = 1, 9 do
			local i = if mirror then 10 - n else n
			local gw, az, e, tipY = spec.ground(i, s, ctx)
			if gw > 0.001 then
				-- solved on the (already mirrored) body with the real tail n: the azimuth mirrors, the shape doesn't
				if mirror then
					az = -az
				end
				-- the lance end travels from where the keys hold it down to the floor along its own
				-- height (never swinging through the floor on the way), extension and azimuth blending too
				local qk = qs[n]
				if mirror then
					qk = table.clone(qk)
					qk.w, qk.r, qk.la, qk.lb, qk.lc = -qk.w, -qk.r, -qk.la, -qk.lb, -qk.lc
				end
				local endK = tailEnd(n, pose, qk)
				local v = endK - tailRootW(pose).Position
				local azK = math.atan2(-v.X, -v.Z)
				local gk = gw * gw * (3 - 2 * gw)
				local azE = azK + ((az - azK + math.pi) % TAU - math.pi) * gk
				local keep = 1 - gk
				local kq = zeroQ()
				kq.r, kq.a, kq.b, kq.c, kq.la, kq.lb, kq.lc = qk.r * keep, qk.a * keep, qk.b * keep, qk.c * keep, qk.la * keep, qk.lb * keep, qk.lc * keep
				qs[n] = groundQ(n, pose, azE, qk.e + (e - qk.e) * gk, endK.Y + (tipY - endK.Y) * gk, kq)
				solved[n] = true
			end
		end
	end
	for n = 1, 9 do
		local q = qs[n]
		if mirror and not solved[n] then
			q = table.clone(q)
			q.w, q.r, q.la, q.lb, q.lc = -q.w, -q.r, -q.la, -q.lb, -q.lc
		end
		-- the floor guard: a plunging tail keeps only its lance end off the floor (the flame stabs in);
		-- every other tail keeps all of its parts above it
		local low = if solved[n] then function(qq: Q): number return tailEnd(n, pose, qq).Y end else function(qq: Q): number return tailLow(n, pose, qq) end
		if spec.floor and low(q) < spec.floor then
			local safe = (spec.floorSafe or REST_T)(n, ctx)
			local lo, hi = 0, 1
			local floorY = spec.floor
			for _ = 1, 10 do
				local mid = (lo + hi) / 2
				if low(lerpQ(q, safe, mid)) < floorY then
					lo = mid
				else
					hi = mid
				end
			end
			q = lerpQ(q, safe, hi)
		end
		tailJoints(pose, n, q)
	end
end

-- Follow-through. The body's upper joints ride a damped spring behind their keys: a joint that
-- has been moving lags, overshoots the key it arrives at and rings back, so every key lands
-- with weight and settles instead of stopping dead. Stateless: the keyed pose (overlays left
-- out, so trembles stay crisp) is sampled at earlier times on a fixed grid (continuous across
-- phase boundaries) and weighted by each joint's spring impulse response. The result is added
-- on top of the full pose as a correction, scaled by the joint's gain.
-- The correction saturates at `cap` radians (and cap / 3 unit studs of slide), so a snap
-- from a full rear to a slam still lags and rings without folding the neck through the legs.
--   joint = { delay s, natural Hz, damping ratio, gain, cap }
local SPRING: { [string]: { number } } = {
	JointRoot = { 0, 1.9, 0.42, 0.6, 0.07 },
	JointChest = { 0.015, 2.1, 0.38, 0.85, 0.1 },
	JointNeck = { 0.025, 2.2, 0.34, 0.85, 0.14 },
	JointHead = { 0.045, 2.4, 0.3, 0.9, 0.16 },
	JointJaw = { 0.02, 3.2, 0.4, 0.5, 0.12 },
	JointEarL = { 0.1, 3.0, 0.2, 1, 0.35 },
	JointEarR = { 0.13, 2.8, 0.2, 1, 0.35 },
	JointTail = { 0.05, 1.5, 0.3, 1, 0.2 },
}
local TAP_DT, TAPS = 0.05, 10
local SPRING_W: { [string]: { number } } = {}
for name, s in SPRING do
	local w, sum = {}, 0
	local om, z = TAU * s[2], s[3]
	local od = om * math.sqrt(1 - z * z)
	for k = 0, TAPS do
		local t = k * TAP_DT - s[1]
		local h = if t > 0 then math.exp(-z * om * t) * sin(od * t) else 0
		w[k] = h
		sum += h
	end
	for k = 0, TAPS do
		w[k] /= sum
	end
	SPRING_W[name] = w
end
local PHASES = { "windup", "active", "recover" }
local bare: { [any]: Phase } = {}
-- the keyed pose `back` seconds before secs into phaseName, walking back across phases
local function keyedAt(v: Variant, move: string, phaseName: string, secs: number, curDur: number, input: any): Pose
	local idx = table.find(PHASES, phaseName) :: number
	local pi, sec, dur = idx, secs, curDur
	while sec < 0 and pi > 1 and (v :: any)[PHASES[pi - 1]] do
		pi -= 1
		dur = DUR[move][pi]
		sec += dur
	end
	local phase: Phase = (v :: any)[PHASES[pi]]
	if (phase :: any).keepOverlay and pi < idx then
		-- an overlay-driven phase (the pounce's bounding) is too costly to resample: hold the
		-- start of the next phase instead
		pi += 1
		phase, sec, dur = (v :: any)[PHASES[pi]], 0, if pi == idx then curDur else DUR[move][pi]
	end
	do
		local b = bare[phase]
		if not b then
			b = table.clone(phase) :: any
			b.overlay = nil
			bare[phase] = b :: any
		end
		phase = b :: any
	end
	return (Quadruped.samplePhase(phase, clamp(sec / dur, 0, 1), if pi == idx then input else { side = input.side, stage = input.stage }))
end
local function followThrough(pose: Pose, v: Variant, move: string, phaseName: string, secs: number, dur: number, input: any)
	if ((v :: any)[phaseName] :: any).keepOverlay then
		return
	end
	local grid: { Pose } = {}
	for k = 0, TAPS do
		grid[k] = keyedAt(v, move, phaseName, secs - k * TAP_DT, dur, input)
	end
	local now = grid[0]
	for name, w in SPRING_W do
		local x = now[name] or I
		local xr = x.Rotation:Inverse()
		local rv, dp = Vector3.zero, Vector3.zero
		for k = 1, TAPS do
			if w[k] ~= 0 then
				local xk = grid[k][name] or I
				local axis, angle = (xr * xk.Rotation):ToAxisAngle()
				if angle > 1e-6 then
					rv += axis * (angle * w[k])
				end
				dp += (xk.Position - x.Position) * w[k]
			end
		end
		local g, cap = SPRING[name][4], SPRING[name][5]
		local mag = rv.Magnitude * g
		local cf = pose[name] or I
		if mag > 1e-6 then
			cf = cf * CFrame.fromAxisAngle(rv.Unit, cap * math.tanh(mag / cap))
		end
		dp *= g
		local slide = dp.Magnitude
		if slide > 1e-6 then
			dp = dp.Unit * (cap / 3) * math.tanh(slide * 3 / cap)
		end
		pose[name] = cf + dp
	end
end

local lifeHook: any
local function sampleMove(move: string, phaseName: string, u: number, input: Input?): Pose
	local list = variants[move]
	assert(list, "NineTailFox.sample: no move " .. move)
	local v = list[VARIANT[move]]
	local phase: Phase = (v :: any)[phaseName]
	assert(phase, ("NineTailFox.sample: no %s.%s"):format(move, phaseName))
	local inp: any = input or {}
	u = clamp(u, 0, 1)
	local dur = inp.duration or phase.duration
	local secs = u * dur
	local pose, plant, reach = Quadruped.samplePhase(phase, u, inp)
	followThrough(pose, v, move, phaseName, secs, dur, inp)
	if lifeHook then
		lifeHook(move, phaseName, u, secs, pose)
	end
	rig.plantLegs(pose, plant, phase.air, reach)
	guardHead(pose)
	-- tails: s = seconds from the windup start, release at s = windup
	local W, Act = DUR[move][1], DUR[move][2]
	local s = if phaseName == "windup" then W - (1 - u) * dur elseif phaseName == "active" then W + secs else W + Act + secs
	local ctx = { stage = inp.stage or 1, parts = inp.parts, move = move }
	buildTails(pose, v, s, ctx, phase.mirror == true and (inp.side or 1) < 0)
	return pose
end

------------------------------------------------------------------------------------
-- Reach presets (studs, model space, -Z forward) and tail shapes shared by the moves

local BRACE = paws(-0.12, 0.08, 0.05, 0.06)
local LOWR = paws(-0.4, 0.32, 0.1, 0.12)
local REARR = paws(0.1, -0.05, 0.05, 0.08)
local SPLAY = paws(-0.3, 0.3, 0.3, 0.2)

local T_REST = shp({ fan = 0.3, odd = 0.02 })
local T_LOW = shp({ fan = 0.45, lift = 0.28, out = 0.05, curl = 0.3 })
local T_RAISE = shp({ fan = 0.5, lift = -0.35 })
local T_UP = shp({ fan = 0.55, lift = -0.61, e = 1 })
local T_UPH = shp({ fan = 0.55, lift = -0.61, e = 0.5 })
local T_STREAM = shp({ fan = 0.12, lift = 0.45, curl = 0.3 })
local T_FLARE = shp({ fan = 0.55, lift = -0.25, e = 0.15 })
local function azLane(max: number): (number, any) -> number
	return function(i, _)
		return -(i - 5) / 4 * max
	end
end

-- small "life" on every move: a held windup trembles and breathes, each release dips the
-- body and rebounds (ringing down), so no pose is ever dead still
local TREM = { Intro = 0.004, FangDance = 0.012, TailSweep = 0.01, TailLance = 0.012, LanceFan = 0.012, TailSnare = 0.012, RendingPounce = 0.016,
	FoxfireVolley = 0.01, RootfireEruption = 0.012, MoonLeap = 0.012, MournfulScream = 0.02, NineTailFall = 0.012, VeilBreak = 0.014 }
local DIP = { FangDance = 0.05, TailSweep = 0.06, TailLance = 0.07, LanceFan = 0.05, TailSnare = 0.06, FoxfireVolley = 0.05, RootfireEruption = 0.08,
	MournfulScream = 0.03, VeilBreak = 0.1, RendingPounce = 0.0 }
local function lifeOverlay(move: string, phaseName: string, u: number, secs: number, pose: Pose)
	local W, Act = DUR[move][1], DUR[move][2]
	local root = pose.JointRoot or I
	if phaseName == "windup" then
		local held = smooth(0.3, 0.5, u) * (1 - smooth(0.92, 1, u))
		local k = (TREM[move] or 0.01) * held
		pose.JointRoot = root * R(-k * (0.5 + 0.5 * sin(secs * 7)), 0.5 * k * sin(secs * 9 + 1), 0, 0.5 * k * sin(secs * 5.3), 0.6 * k * sin(secs * 4.1))
		pose.JointNeck = (pose.JointNeck or I) * A(0, 0.02 * held * sin(secs * 6.1))
		pose.JointHead = (pose.JointHead or I) * A(0.02 * held * sin(secs * 8.3 + 1), 0, 0.02 * held * sin(secs * 5.1))
		pose.JointEarL = (pose.JointEarL or I) * A(0.06 * held * sin(secs * 11))
		pose.JointEarR = (pose.JointEarR or I) * A(0.06 * held * sin(secs * 9.3 + 2))
	else
		local tc = secs + (if phaseName == "recover" then Act else 0)
		local dip = (DIP[move] or 0) * math.exp(-4 * tc) * math.max(0, sin(tc * TAU * 2))
		pose.JointRoot = root * R(-dip, -dip * 0.6)
	end
end

lifeHook = lifeOverlay

------------------------------------------------------------------------------------
-- INTRO 2.2 / 0.2 / 0.8: from the curled sleep, rise, stretch, arch, throw the head back;
-- the tails unfurl one by one (0.2 s apart) and fan. Hold u 0.85-1 of the windup.
do
	local W, Act, Rec = 2.2, 0.2, 0.8
	local sleepy = curOver({ n = -0.3, h = -0.35, j = -0.05, y = -1.74, ch = 0.08 })
	local sit = B({ y = -1.05, pitch = 0.1, ch = 0.12, n = 0.15, h = -0.08, hr = 0.14, e = 0.15, t = 0.3, legs = merge(FL(0.15, 0, 0), FRr(0.15, 0, 0), BLg(0.5, -1.5, 0.6, -0.85), BRg(0.4, -1.5, 0.6, 0.85)) })
	local sitR = paws(-0.35, -0.6, 0.12, 0.25)
	local stretch = B({ y = -0.25, pitch = -0.2, ch = -0.1, n = 0.0, h = 0.0, j = -0.75, e = 0.3, t = 0.7, hr = 0 })
	local stretchR = paws(-0.75, 0.2, 0.5, 0.12)
	local arch = B({ y = -0.12, pitch = 0.2, ch = -0.22, n = 0.35, h = 0.2, j = -0.5, e = 0.45, t = 0.45 })
	local peak = B({ y = -0.04, pitch = 0.38, ch = 0.14, n = 0.52, h = 0.3, hr = 0, j = -0.85, e = 0.5, ef = 0.3, t = -0.2, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
	local peakR = paws(0.0, -0.1, 0.06, 0.1)
	local after = with(peak, { JointNeck = A(0.4), JointHead = A(0.18), JointJaw = A(-0.5) })
	local tailKeys = {
		TK(0, curledTails :: any), TK(0.1, curledTails :: any),
		TK(0.55, shp({ fan = 0.5, lift = -0.3, e = 0.35 })), TK(W + Act, shp({ fan = 0.55, lift = -0.4, e = 0.45 })),
		TK(W + Act + Rec, T_REST),
	}
	register("Intro", "A", W, Act, Rec,
		ph(W, { K(0, CURLED, NONE), K(0.45, sleepy, NONE, nil, "inOut"), K(0.85, sit, NONE, nil, "inOut"), K(1.25, stretch, ALL, stretchR, "inOut"),
			K(1.65, arch, ALL, paws(-0.4, 0.1, 0.1, 0.12), "inOut"), K(1.95, peak, HIND, peakR, "out"), K(W, peak, HIND, peakR) }),
		ph(Act, { K(0, peak, HIND, peakR), K(Act, after, HIND, peakR, "out") }),
		ph(Rec, { K(0, after, HIND, peakR), K(0.4, with(STAND, {}), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
		{ keys = tailKeys, lag = 0.2 })
	-- B "Rise on the hind legs": uncurls, crouches, then rises tall on the hind legs for the howl
	local tall = B({ y = -0.05, pitch = 0.78, ch = 0.15, n = 0.55, h = 0.3, hr = 0, j = -0.9, e = 0.55, ef = 0.3, t = -0.2, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
	local crouch = B({ y = -0.75, pitch = -0.05, ch = -0.1, n = -0.2, h = -0.12, e = 0.4, t = 0.5 })
	register("Intro", "B", W, Act, Rec,
		ph(W, { K(0, CURLED, NONE), K(0.5, sleepy, NONE, nil, "inOut"), K(1.0, sit, NONE, nil, "inOut"), K(1.45, crouch, ALL, LOWR, "inOut"),
			K(1.95, tall, HIND, REARR, "out"), K(W, tall, HIND, REARR) }),
		ph(Act, { K(0, tall, HIND, REARR), K(Act, with(tall, { JointNeck = A(0.45) }), HIND, REARR, "out") }),
		ph(Rec, { K(0, tall, HIND, REARR), K(0.4, crouch, ALL, LOWR, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
		{ keys = tailKeys, lag = 0.2 })
end

------------------------------------------------------------------------------------
-- FANGDANCE 0.65 / 0.12 / 1.08: rock back on the haunches, head weaving; three snaps
-- (release +0, +0.4, +0.8), each with a small forebody step and a tail flick; the last biggest.
do
	local W, Act, Rec = 0.65, 0.12, 1.08
	local function build(v: string, rockO: { [string]: any }, snapO: { [string]: any }, weave: number, lunge: number)
		local rock = B(rockO)
		local rockR = paws(0.05, 0.05, 0.06, 0.1)
		local open = B(merge(rockO, { n = 0.2, h = 0.1, j = -0.85, e = 0.5 }) :: any)
				local function strike(amp: number, left: boolean): (Pose, any)
			local o = merge(snapO, { y = (snapO.y or -0.25) - 0.04 * amp, n = -0.28 - 0.1 * amp, h = -0.14 - 0.05 * amp, ny = (if left then 0.12 else -0.12) * amp, j = -0.03 }) :: any
			local reach = if left then { FL = V(0, 0, -0.3 * lunge * amp), FR = V(0, 0, 0.05), BL = V(0, 0, 0.08), BR = V(0, 0, 0.08) } else { FL = V(0, 0, 0.05), FR = V(0, 0, -0.3 * lunge * amp), BL = V(0, 0, 0.08), BR = V(0, 0, 0.08) }
			return B(o), reach
		end
		local s1, r1 = strike(0.8, true)
		local s2, r2 = strike(1.0, false)
		local s3, r3 = strike(1.5, true)
		local thru1 = with(s1, { JointNeck = A(-0.38), JointHead = A(-0.1), JointJaw = A(-0.25) })
		local thru2 = with(s2, { JointNeck = A(-0.4), JointHead = A(-0.1), JointJaw = A(-0.25) })
		local thru3 = with(s3, { JointNeck = A(-0.5), JointHead = A(-0.14), JointJaw = A(-0.3), JointChest = A(-0.12) })
		local tl = {
			TK(0, T_REST), TK(0.3, T_LOW),
		}
		for k, t0 in { W, W + 0.4, W + 0.8 } do
			local amp = if k == 3 then 1.5 else 1
			table.insert(tl, TK(t0 - 0.12, T_LOW))
			table.insert(tl, TK(t0 + 0.02, shp({ fan = 0.5 + 0.08 * amp, lift = -0.28 * amp, curl = 0.6, hook = -1 }), "out"))
			table.insert(tl, TK(t0 + 0.22, T_LOW))
		end
		table.insert(tl, TK(W + Act + Rec, T_REST))
		register("FangDance", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.3, rock, ALL, rockR, "inOut"), K(0.5, rock, ALL, rockR), K(0.58, open, ALL, rockR, "inOut"), K(W - 0.02, with(s1, {}), ALL, r1, "in"), K(W, s1, ALL, r1) }, { overlay = function(u: number, secs: number, _: any): Pose
				local k = smooth(0.1, 0.3, u) * (1 - smooth(0.78, 0.9, u))
				return { JointNeck = A(0, weave * k * sin(secs * 11)), JointHead = A(0.03 * k * sin(secs * 13 + 1), weave * 0.5 * k * sin(secs * 11 - 0.6), 0.12 * k * sin(secs * 11 - 1.2)) }
			end }),
			ph(Act, { K(0, s1, ALL, r1), K(Act, thru1, ALL, r1, "out") }),
			ph(Rec, { K(0, thru1, ALL, r1), K(0.14, rock, ALL, rockR, "inOut"), K(0.22, open, ALL, rockR, "inOut"), K(0.28, s2, ALL, r2, "in"), K(0.4, thru2, ALL, r2, "out"),
				K(0.52, rock, ALL, rockR, "inOut"), K(0.6, open, ALL, rockR, "inOut"), K(0.68, s3, ALL, r3, "in"), K(0.8, thru3, ALL, r3, "out"), K(0.95, with(STAND, { JointRoot = R(-0.15) }), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }, nil),
			{ keys = tl, lag = 0.03 })
	end
	build("A", { y = -0.28, pitch = 0.28, ch = 0.1, n = 0.12, h = 0.02, t = 0.4, e = 0.4 }, { y = -0.25, pitch = -0.1, ch = -0.08, t = 0.3, e = 0.45 }, 0.3, 1.0)
	-- B "Low weave": a lower, stalking crouch, the whole body lunging forward on each snap
	build("B", { y = -0.38, pitch = 0.1, ch = 0.0, n = 0.05, h = -0.12, t = 0.3, e = 0.55 }, { y = -0.36, pitch = -0.14, ch = -0.1, t = 0.2, e = 0.55 }, 0.45, 1.2)
end

------------------------------------------------------------------------------------
-- TAILSWEEP 0.9 / 0.25 / 0.85: the hips pivot and the forebody turns away; tails 2, 5, 8
-- fan back, then lengthen to full extension while sweeping across the front through 200
-- degrees (the cone). Elevation keeps the sleeves over the head.
do
	local W, Act, Rec = 0.9, 0.25, 0.85
	local EL = math.rad(22)
	local function sweepAtk(a0: { number }, a1: { number }, stagger: number, delays: { number }?)
		return function(i: number, s: number, _ctx: any): (number, Q?)
			local k = if i == 2 then 1 elseif i == 5 then 2 elseif i == 8 then 3 else 0
			if k == 0 then
				return 0, nil
			end
			local t = s - stagger * (k - 1)
			local prog = smooth(W - 0.08, W + Act - 0.02, t)
			prog = prog * prog * (3 - 2 * prog) -- stays low then whips
			local az = math.rad(a0[k] + (a1[k] - a0[k]) * prog)
			local pre = smooth(0.15, 0.55, s)
			local e = smooth(W - 0.02, W + 0.14, t) * (1 - smooth(W + Act + 0.1, W + Act + 0.6, s))
			local w = pre * (1 - smooth(W + Act + 0.25, W + Act + 0.7, s))
			local el = EL + 0.12 * (1 - smooth(0.2, 0.6, s)) -- cocked a little higher while it winds
			return w, aimQ(i, az, el, e, -0.3 * (1 - e))
		end
	end
	local function build(v: string, wy: number, cy: number, a0: { number }, a1: { number }, stagger: number, extra: { [string]: any })
		local turn = B({ y = -0.3, yaw = 0.3 * wy, roll = -0.04 * wy, ch = 0.02, chy = -0.5 * wy, n = 0.04, ny = 0.42 * wy, h = -0.1, hy = 0.15 * wy, e = 0.45, t = 0.3, ty = -0.2 * wy })
		local cocked = B({ y = -0.36, yaw = 0.38 * wy, roll = -0.05 * wy, ch = 0.0, chy = -0.62 * wy, n = 0.04, ny = 0.5 * wy, h = -0.1, hy = 0.2 * wy, e = 0.5, t = 0.35, ty = -0.3 * wy })
		local whip = B({ y = -0.3, yaw = -0.32 * wy, roll = 0.05 * wy, ch = -0.04, chy = 0.3 * wy, n = 0.0, ny = -0.2 * wy, h = -0.14, hy = -0.1 * wy, e = 0.55, t = 0.2, ty = 0.3 * wy })
		local through = B({ y = -0.26, yaw = -0.45 * wy, roll = 0.06 * wy, ch = -0.04, chy = 0.42 * wy, n = 0.02, ny = -0.3 * wy, h = -0.14, hy = -0.14 * wy, e = 0.55, t = 0.15, ty = 0.4 * wy })
		local reach = paws(-0.1, 0.1, 0.12, 0.14)
		local tl = {
			TK(0, T_REST), TK(0.4, shp({ fan = 0.5, lift = 0.25, out = 0.06 })), TK(W + Act, shp({ fan = 0.35, lift = 0.15 })), TK(W + Act + Rec, T_REST),
		}
		register("TailSweep", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.35, turn, ALL, reach, "inOut"), K(0.7, cocked, ALL, reach, "inOut"), K(0.82, cocked, ALL, reach), K(0.97, whip, ALL, reach, "in"), K(W, whip, ALL, reach) }),
			ph(Act, { K(0, whip, ALL, reach), K(Act, through, ALL, reach, "out") }),
			ph(Rec, { K(0, through, ALL, reach), K(0.3, through, ALL, reach), K(0.6, with(STAND, { JointRoot = R(-0.14) }), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.02, atk = sweepAtk(a0, a1, stagger) })
	end
	-- A: left to right (hips turn right)... B: the mirror. C: a scissor: the outer tails cross to the middle
	build("A", 1, 1, { 118, 112, 106 }, { -92, -98, -104 }, 0.04, {})
	build("B", -1, -1, { -118, -112, -106 }, { 92, 98, 104 }, 0.04, {})
	build("C", 1, 1, { 120, -110, -120 }, { -10, 100, 10 }, 0.06, {})
end

------------------------------------------------------------------------------------
-- TAILLANCE 0.6 / 0.1 / 0.7: tail 5 coils tight (tip aimed at the target), the forebody
-- dips and the head tracks; at contact it extends fully along the facing line (about 0.2 s,
-- ending on the hit) and retracts smoothly. The other tails flare.
do
	local W, Act, Rec = 0.6, 0.1, 0.7
	local function build(v: string, coilEl: number, coilHook: number, laneEl: number, dip: number, bodyO: { [string]: any })
		local coil: Shape = function(i, _) return aimQ(i, 0, math.rad(coilEl), 0, coilHook) end
		local aim: Shape = function(i, _) return aimQ(i, 0, math.rad(laneEl), 1, 0) end
		local load = B(merge({ y = -0.3 * dip, ch = -0.18 * dip, n = -0.1, h = -0.15, ny = 0, e = 0.5, t = 0.3 }, bodyO) :: any)
		local strike = B(merge({ y = -0.22 * dip, ch = -0.28 * dip, n = -0.22, h = -0.1, e = 0.55, t = 0.2 }, bodyO) :: any)
		local reach = paws(-0.2 * dip, 0.15, 0.08, 0.1)
		local tl = { TK(0, T_REST), TK(0.3, T_FLARE), TK(W, shp({ fan = 0.6, lift = -0.3, e = 0.1 })), TK(W + Act + 0.3, T_FLARE), TK(W + Act + Rec, T_REST) }
		register("TailLance", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.25, load, ALL, reach, "out"), K(0.5, load, ALL, reach), K(W - 0.02, strike, ALL, reach, "in"), K(W, strike, ALL, reach) }),
			ph(Act, { K(0, strike, ALL, reach), K(Act, strike, ALL, reach) }),
			ph(Rec, { K(0, strike, ALL, reach), K(0.3, with(load, { JointRoot = R(-0.1) }), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.03, atk = lanceAtk(W, { coil = coil, aim = aim, c0 = 0.08, c1 = 0.4, hold = 0.12, ret = 0.45 }) })
	end
	build("A", 62, -1.5, 22, 1, {})
	-- B: the tail rears tall and straight like a scorpion's, the body low and coiled
	build("B", 84, -0.5, 18, 1.5, { pitch = 0.05, e = 0.6 })
end

------------------------------------------------------------------------------------
-- LANCEFAN 0.95 / 0.1 / 1.0: the tails coil and fan; each lance extends in sequence at its
-- part's time (0.18 s apart); phase 3 returns on a second set.
do
	local W, Act, Rec = 0.95, 0.1, 1.0
	local function build(v: string, coilK: number, coilEl: number, laneEl: number, bodyO: { [string]: any }, cross: number)
		local function laneAz(i: number, ctx: any): number
			local max = math.rad(((ctx and ctx.stage) or 1) >= 2 and 40 or 22)
			return -(i - 5) / 4 * (if ((ctx and ctx.stage) or 1) >= 2 then 1 else 2) * max
		end
		local coil: Shape = function(i, ctx) return aimQ(i, laneAz(i, ctx) * coilK, math.rad(coilEl), 0, -1.2) end
		local aim: Shape = function(i, ctx) return aimQ(i, laneAz(i, ctx) * cross, math.rad(laneEl), 1, 0) end
		local load = B(merge({ y = -0.35, ch = -0.12, n = 0.0, h = -0.12, e = 0.5, t = 0.35 }, bodyO) :: any)
		local strike = B(merge({ y = -0.25, ch = -0.2, n = -0.14, h = -0.1, e = 0.55, t = 0.2 }, bodyO) :: any)
		local sweep = with(strike, { JointRoot = R(-0.22, 0, 0, 0.06) })
		local reach = paws(-0.25, 0.2, 0.1, 0.12)
		local tl = {
			TK(0, T_REST), TK(0.45, shp({ fan = 0.55, lift = -0.3, e = 0.12 })), TK(W + Act + 0.5, shp({ fan = 0.5, lift = -0.2, e = 0.1 })), TK(W + Act + Rec, T_REST),
		}
		register("LanceFan", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.4, load, ALL, reach, "out"), K(0.8, load, ALL, reach), K(W - 0.02, strike, ALL, reach, "in"), K(W, strike, ALL, reach) }),
			ph(Act, { K(0, strike, ALL, reach), K(Act, sweep, ALL, reach, "out") }),
			-- the pose holds the lunge long enough for the (later) lances of the second set, then comes back
			ph(Rec, { K(0, sweep, ALL, reach), K(0.55, with(strike, { JointRoot = R(-0.22, 0, 0, -0.06) }), ALL, reach, "inOut"), K(0.8, with(load, { JointRoot = R(-0.12) }), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.02, atk = lanceAtk(W, { coil = coil, aim = aim, c0 = 0.1, c1 = 0.55, hold = 0.12, ret = 0.4 }) })
	end
	build("A", 0.5, 62, 16, {}, 1)
	-- B: tall tight spirals, flat lances, the forebody rears slightly
	build("B", 0.3, 80, 12, { pitch = 0.12, ch = 0.05, n = 0.05 }, 1)
	-- C: the tails coil outward and the lances converge across the middle before fanning
	build("C", 1.8, 50, 18, { y = -0.4 }, -0.4)
end

------------------------------------------------------------------------------------
-- TAILSNARE 0.85 / 0.1 / 0.8: one tail coils and rears; at contact it extends, then reels
-- back over 0.45 s with the fox leaning back, hauling a line; it ends braced and ready to
-- bite (the follow-up is FangDance).
do
	local W, Act, Rec = 0.85, 0.1, 0.8
	local function build(v: string, coilAz: number, coilEl: number)
		local coil: Shape = function(i, _) return aimQ(i, math.rad(coilAz), math.rad(coilEl), 0, -1.4) end
		local aim: Shape = function(i, _) return aimQ(i, 0, math.rad(20), 1, 0) end
		local rear = B({ y = -0.15, pitch = 0.2, ch = 0.12, n = 0.18, h = 0.04, e = 0.45, t = 0.4, legs = merge(FL(-0.2, -0.3, 0), FRr(-0.2, -0.3, 0)) })
		local strike = B({ y = -0.28, pitch = -0.1, ch = -0.18, n = -0.2, h = -0.1, e = 0.5, t = 0.2 })
		local haul = B({ y = -0.3, pitch = 0.22, ch = 0.0, n = 0.1, h = -0.06, e = 0.45, t = 0.5 })
		local braced = B({ y = -0.4, pitch = 0.1, ch = -0.08, n = -0.1, h = -0.14, j = -0.3, e = 0.55, t = 0.3 })
		local reach = paws(-0.3, 0.3, 0.1, 0.12)
		local haulR = paws(0.1, 0.35, 0.1, 0.14)
		local tl = { TK(0, T_REST), TK(0.4, shp({ fan = 0.5, lift = -0.2, e = 0.1 })), TK(W + Act + 0.5, T_FLARE), TK(W + Act + Rec, T_REST) }
		register("TailSnare", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.4, rear, ALL, REARR, "out"), K(0.7, rear, ALL, REARR), K(W - 0.02, strike, ALL, reach, "in"), K(W, strike, ALL, reach) }),
			ph(Act, { K(0, strike, ALL, reach), K(Act, strike, ALL, reach) }),
			ph(Rec, { K(0, strike, ALL, reach), K(0.12, strike, ALL, reach), K(0.4, haul, ALL, haulR, "inOut"), K(0.55, braced, ALL, BRACE, "out"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.03, atk = lanceAtk(W, { coil = coil, aim = aim, c0 = 0.1, c1 = 0.5, hold = 0.06, ret = 0.45 }) })
	end
	build("A", 0, 70)
	-- B: the tail coils to the side and whips across to the front
	build("B", 55, 38)
end

------------------------------------------------------------------------------------
-- RENDINGPOUNCE 0.75 / dash (input.duration, 0.55 at 55/s) / 1.0: a deep crouch, tails
-- swept back and ears flat, a haunch wiggle; then a long, low bounding spring (strides
-- sampled by elapsed seconds, so a shortened dash stays clean) ending in a claw rake.
do
	local W, Act, Rec = 0.75, 0.4, 1.0
	local function build(v: string, rate: number, speed: number, double: boolean, roll: number, crouchY: number)
		local G = table.clone(RUN)
		G.rate = function(_) return rate end
		local coil = B({ y = crouchY, pitch = -0.16, ch = -0.1, n = 0.0, h = -0.1, hr = 0.06, j = -0.2, e = 0.72, ef = 0.05, t = 0.6, ty = 0 })
		local coilR = paws(-0.5, 0.45, 0.14, 0.14)
		local load = B({ y = crouchY - 0.06, pitch = -0.22, ch = -0.14, n = 0.0, h = -0.12, hr = 0, j = -0.3, e = 0.8, ef = 0.03, t = 0.7 })
		local loadR = paws(-0.55, 0.55, 0.12, 0.14)
		local launch = B({ y = crouchY + 0.2, pitch = -0.22, ch = -0.14, n = -0.05, h = -0.12, hr = 0, j = -0.5, e = 0.8, ef = 0.03, t = 0.7, legs = merge(FL(0.85, -0.7, -0.3), FRr(0.85, -0.7, -0.3)) })
		local launchR = paws(-0.2, 0.7, 0.1, 0.14)
		local launchP = rig.plant(table.clone(launch), HIND, launchR)
		local function stride(secs: number, dur: number): Pose
			local running = runPose(secs * TAU * rate, speed, G)
			local mix = smooth(0, 0.07, secs)
			for _, name in JOINTS do
				if not string.find(name, "^JointTail%d") then
					running[name] = (launchP[name] or I):Lerp(running[name] or I, mix)
				end
			end
			-- the rake: both forepaws (or the left alone) rise, then rake down and through
			local up = smooth(dur - 0.3, dur - 0.14, secs)
			local down = smooth(dur - 0.14, dur - 0.02, secs)
			local rake = up
			if rake > 0 then
				local raised = { A(1.0, 0, 0.1), A(-0.95), A(-0.4) }
				local struck = { A(0.15, 0, -0.1), A(-0.2), A(-0.15) }
				for k, side in { "FL", "FR" } do
					local lift = if double or side == "FL" then 1 else 0.35
					local o = LEGS[side]
					local sgn = if side == "FL" then 1 else -1
					local r, s2 = raised, struck
					local jn = { o.upper, o.mid, o.foot }
					for n = 1, 3 do
						local target = r[n]:Lerp(s2[n], down)
						if n == 1 then
							target = target * A(0, 0, sgn * roll * (1 - down))
						end
						running[jn[n]] = (running[jn[n]] or I):Lerp(target, rake * lift)
					end
				end
				running.JointChest = (running.JointChest or I) * A(0.18 * up - 0.3 * down)
				running.JointNeck = (running.JointNeck or I) * A(-0.2 * down)
				running.JointJaw = A(-0.7 * up * (1 - down))
			end
			return running
		end
		local tl = { TK(0, T_REST), TK(0.3, T_STREAM), TK(W, shp({ fan = 0.1, lift = 0.5, curl = 0.2 })), TK(W + 0.5, shp({ fan = 0.2, lift = 0.3, curl = 0.4 })), TK(W + Act + 0.2, shp({ fan = 0.4, lift = -0.1 })), TK(W + Act + Rec, T_REST) }
		local skid = B({ y = -0.5, pitch = 0.12, ch = 0.0, n = -0.05, h = -0.14, j = -0.3, e = 0.6, t = 0.4 })
		local skidR = paws(-0.5, 0.35, 0.18, 0.15)
		register("RendingPounce", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.3, coil, ALL, coilR, "inOut"), K(0.6, load, ALL, loadR, "inOut"), K(W - 0.04, load, ALL, loadR), K(W, launch, HIND, launchR, "in") }, { overlay = function(u: number, secs: number, _: any): Pose
				local k = smooth(0.35, 0.5, u) * (1 - smooth(0.9, 1, u))
				return { JointRoot = R(0, 0, 0, 0.07 * k * sin(secs * 22), 0.05 * k * sin(secs * 22 + 1.2)), JointTail = A(0, 0.2 * k * sin(secs * 22 + 0.8)) }
			end }),
			{ duration = Act, keepOverlay = true, keys = { { t = 0, pose = {}, plant = NONE }, { t = 1, pose = {}, plant = NONE } }, overlay = function(_u: number, secs: number, input: any): Pose
				return stride(secs, input.duration or Act)
			end },
			ph(Rec, { K(0, skid, HIND, skidR), K(0.2, skid, ALL, skidR, "out"), K(0.55, with(skid, { JointRoot = R(-0.25) }), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.03 })
	end
	build("A", 3.0, 55, true, 0.0, -0.42)
	build("B", 2.6, 55, true, 0.0, -0.5) -- a longer, flatter bound, a deeper coil
	build("C", 3.0, 55, false, 0.35, -0.4) -- one big overhead strike with the body rolled into it
end

------------------------------------------------------------------------------------
-- FOXFIREVOLLEY 1.1 / 0.1 / 0.9: rear the forebody; the tails spread wide and each tip
-- arches forward, outer tails first and inwards; the contact is a fan thrust (stage 3:
-- wider, with a second thrust 0.7 s later).
do
	local W, Act, Rec = 1.1, 0.1, 0.9
	local function volleyAtk(archAt: number, el: number, thrustEl: number)
		return function(i: number, s: number, ctx: any): (number, Q?)
			local stage = (ctx and ctx.stage) or 1
			local spread = math.rad(if stage >= 3 then 44 else 32)
			local rank = 4 - abs(i - 5) -- outer tails (rank 0) first
			local ti = archAt + rank * 0.08
			local arch = smooth(ti, ti + 0.3, s)
			local az = -(i - 5) / 4 * spread
			local up = shp({ fan = 0.55, lift = -0.61, e = 0.3 })(i, ctx)
			local aimA = aimQ(i, az, math.rad(el), 0.55, -1)
			local thrust = aimQ(i, az * 1.2, math.rad(thrustEl), 1, 0)
			local q = lerpQ(up, aimA, arch)
			local t1 = snapUp((s - (W - 0.16)) / 0.16)
			local back = smooth(W + 0.14, W + 0.5, s)
			local pulse = t1 * (1 - back)
			if stage >= 3 then
				pulse = math.max(pulse, snapUp((s - (W + 0.54)) / 0.16) * (1 - smooth(W + 0.88, W + 1.2, s)))
			end
			q = lerpQ(q, thrust, pulse)
			local w = smooth(0.25, 0.5, s) * (1 - smooth(W + Act + (if stage >= 3 then 0.75 else 0.35), W + Act + (if stage >= 3 then 1.1 else 0.7), s))
			return w, q
		end
	end
	local function build(v: string, bodyO: { [string]: any }, thrustO: { [string]: any }, archAt: number, el: number)
		local rear = B(bodyO)
		local rearR = paws(0.05, -0.02, 0.06, 0.1)
		local thrust = B(thrustO)
		local thrustR = paws(-0.3, 0.25, 0.1, 0.12)
		local dipP = with(thrust, { JointRoot = R(-0.2, -0.05) })
		register("FoxfireVolley", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.3, with(rear, { JointRoot = R(-0.3, 0) }), ALL, LOWR, "inOut"), K(0.65, rear, HIND, rearR, "out"), K(0.98, rear, HIND, rearR), K(W - 0.02, thrust, ALL, thrustR, "in"), K(W, thrust, ALL, thrustR) }),
			ph(Act, { K(0, thrust, ALL, thrustR), K(Act, dipP, ALL, thrustR, "out") }),
			ph(Rec, { K(0, dipP, ALL, thrustR), K(0.3, with(rear, { JointRoot = R(-0.1) }), ALL, BRACE, "inOut"), K(0.55, with(STAND, { JointRoot = R(-0.1) }), ALL, BRACE, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = { TK(0, T_REST), TK(0.4, T_UPH), TK(W + Act + Rec, T_REST) }, lag = 0.02, atk = volleyAtk(archAt, el, 14) })
	end
	build("A", { pitch = 0.5, y = -0.05, ch = 0.15, n = 0.3, h = 0.12, j = -0.4, e = 0.5, t = 0.4, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) },
		{ pitch = -0.05, y = -0.28, ch = -0.2, n = -0.15, h = -0.12, j = -0.5, e = 0.55, t = 0.2 }, 0.5, 40)
	-- B: a crouching peacock, head high, the chest thrust forward
	build("B", { y = -0.4, pitch = 0.05, ch = 0.2, n = 0.3, h = 0.15, j = -0.2, e = 0.3, t = 0.4 },
		{ y = -0.45, pitch = -0.1, ch = -0.1, n = -0.05, h = -0.12, j = -0.5, e = 0.55, t = 0.2 }, 0.45, 55)
	-- C: the fox sways side to side, building, then thrusts
	build("C", { y = -0.2, pitch = 0.3, roll = 0.1, ch = 0.1, chr = -0.1, n = 0.2, h = 0.05, j = -0.3, e = 0.4, t = 0.3 },
		{ y = -0.3, pitch = -0.1, ch = -0.15, n = -0.1, h = -0.1, j = -0.5, e = 0.55, t = 0.2 }, 0.55, 30)
end

------------------------------------------------------------------------------------
-- ROOTFIREERUPTION 1.5 / 0.1 / 1.5: rear on the hind legs the first half, then drop forward
-- as tails 1, 3, 5, 7, 9 arch over, extend and plunge: at about 60% of the windup their lance
-- ends touch the ground (solved against the posed body). They stay planted the first 0.8 s of the
-- recover while the body strains, then it pulls free and they retract.
do
	local W, Act, Rec = 1.5, 0.1, 1.5
	local AZ = { [1] = 80, [3] = 55, [5] = 40, [7] = -55, [9] = -80 }
	local function build(v: string, plungeAt: number, ePlunge: number, archEl: number, seq: string)
		local plungeAz = function(i: number): number
			return math.rad(AZ[i] or 0)
		end
		local atk = function(i: number, s: number, ctx: any): (number, Q?)
			if i % 2 == 0 then
				return 0, nil
			end
			local arch = smooth(0.4, 0.85, s)
			local q = lerpQ(T_RAISE(i, ctx), aimQ(i, plungeAz(i), math.rad(archEl), 0.45, -1), arch)
			return smooth(0.3, 0.5, s) * (1 - smooth(W + Act + 0.9, W + Act + 1.2, s)), q
		end
		local ground = function(i: number, s: number, _ctx: any): (number, number, number, number)
			if i % 2 == 0 then
				return 0, 0, 0, 0
			end
			local w = smooth(plungeAt - 0.12, plungeAt + 0.06, s) * (1 - smooth(W + Act + 0.8, W + Act + 1.25, s))
			return w, plungeAz(i), ePlunge, 0.3
		end
		local rear = B({ y = -0.05, pitch = 0.72, ch = 0.14, n = 0.4, h = 0.2, hr = 0, j = -0.5, e = 0.5, t = -0.2, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
		local coil = B({ y = -0.55, pitch = 0.0, ch = -0.12, n = -0.1, h = -0.1, e = 0.5, t = 0.4 })
		local drive = B({ y = -0.3, pitch = -0.12, ch = -0.18, n = -0.25, h = -0.12, j = -0.25, e = 0.6, t = 0.2 })
		local strain = B({ y = -0.3, pitch = -0.14, ch = -0.1, n = -0.12, h = -0.1, j = -0.3, e = 0.62, t = 0.15 })
		local free = B({ y = -0.2, pitch = 0.22, ch = 0.12, n = 0.2, h = 0.05, j = -0.35, e = 0.4, t = 0.4 })
		local wide = paws(-0.35, 0.3, 0.28, 0.2)
		local first = if seq == "stomp" then coil else rear
		local tl = { TK(0, T_REST), TK(0.3, T_RAISE), TK(plungeAt, T_UPH), TK(W + Act + 1.0, T_FLARE), TK(W + Act + Rec, T_REST) }
		register("RootfireEruption", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.3, coil, ALL, LOWR, "inOut"), K(0.7, first, HIND, REARR, "out"), K(0.85, first, HIND, REARR), K(1.1, drive, ALL, wide, "in"), K(1.5, strain, ALL, wide, "out") }, { overlay = function(u: number, secs: number, _: any): Pose
				local k = smooth(0.62, 0.72, u)
				return { JointRoot = R(0, 0, 0, 0.012 * k * sin(secs * 18)), JointChest = A(0.02 * k * sin(secs * 21)) }
			end }),
			ph(Act, { K(0, strain, ALL, wide), K(Act, strain, ALL, wide) }),
			ph(Rec, { K(0, strain, ALL, wide), K(0.7, with(strain, { JointRoot = R(-0.32, -0.12) }), ALL, wide, "inOut"), K(0.82, free, ALL, BRACE, "in"), K(1.1, with(free, { JointRoot = R(-0.15, 0.05) }), ALL, BRACE, "out"), K(Rec, STAND, ALL, nil, "inOut") }, { overlay = function(u: number, secs: number, _: any): Pose
				-- the body strains against the held tails: a slow, heavy tremble
				local k = smooth(0, 0.1, u) * (1 - smooth(0.46, 0.55, u))
				return { JointRoot = R(0.012 * k * sin(secs * 9), 0.02 * k * sin(secs * 13), 0, 0.02 * k * sin(secs * 7)), JointNeck = A(0.03 * k * sin(secs * 11)) }
			end }),
			{ keys = tl, lag = 0.02, atk = atk, ground = ground })
	end
	build("A", 0.9, 0.55, 58, "rear")
	build("B", 0.95, 0.5, 66, "stomp") -- a low coil instead of the rear, a harder drive
	build("C", 0.86, 0.6, 50, "rear")
end

------------------------------------------------------------------------------------
-- MOONLEAP 0.4 / flight 0.6 / 0.4: a deep crouch with the tails thrown forward; a
-- backflip-like arc (the server lifts the body; the flip turns about the body's middle) with
-- the tails streaming out and then curling; the landing is absorbed on all four paws, facing
-- the target.
do
	local W, Act, Rec = 0.4, 0.6, 0.4
	local CENTRE = V(0, 0.15, -0.55) -- the flip's pivot, relative to the root pivot
	local function build(v: string, turns: number, startAt: number, tuck: number)
		local crouch = B({ y = -0.5, pitch = -0.12, ch = -0.12, n = 0.0, h = -0.12, j = -0.2, e = 0.6, t = 0.5, legs = {} })
		local crouchR = paws(-0.45, 0.4, 0.12, 0.14)
		local spring = B({ y = -0.4, pitch = 0.1, ch = -0.1, n = 0.0, h = -0.1, j = -0.3, e = 0.7, t = 0.4 })
		local spring2 = rig.plant(table.clone(spring), HIND, paws(0, 0.8, 0.1, 0.14))
		local function tuckPose(k: number): Pose
			return B({ y = 0, ch = 0, n = -0.1, h = -0.1, j = -0.2, e = 0.7, t = 0.3,
				legs = merge(FL(0.9 * k, -1.5 * k, -0.4 * k), FRr(0.9 * k, -1.5 * k, -0.4 * k), BLg(0.5 * k, -1.2 * k, 0.2 * k), BRg(0.5 * k, -1.2 * k, 0.2 * k)) })
		end
		local extend = B({ y = 0, ch = 0, n = 0.05, h = -0.05, j = -0.3, e = 0.65, t = 0.3,
			legs = merge(FL(0.6, -0.4, -0.2), FRr(0.6, -0.4, -0.2), BLg(-0.9, -0.3, 0.3), BRg(-0.9, -0.3, 0.3)) })
		local land = B({ y = 0, pitch = 0, ch = -0.05, n = -0.1, h = -0.1, j = -0.15, e = 0.6, t = 0.3,
			legs = merge(FL(0.45, -0.3, -0.2), FRr(0.45, -0.3, -0.2), BLg(-0.35, -0.2, 0.2), BRg(-0.35, -0.2, 0.2)) })
		local absorb = B({ y = -0.45, pitch = 0.0, ch = -0.1, n = 0.0, h = -0.14, j = -0.1, e = 0.5, t = 0.3 })
		local absorbR = paws(-0.25, 0.3, 0.12, 0.14)
		local flightKeys = {
			K(0, extend, NONE), K(0.12, extend, NONE, nil, "out"), K(0.28, tuckPose(tuck), NONE, nil, "inOut"), K(0.72, tuckPose(tuck), NONE),
			K(0.93, land, NONE, nil, "inOut"), K(Act, land, ALL, nil, "linear"),
		}
		local flight = ph(Act, flightKeys, { air = true, overlay = function(u: number, _s: number, _: any): Pose
			local th = TAU * turns * smooth(startAt, 0.92, u)
			local c = CENTRE
			local y = c.Y - (c.Y * cos(th) - c.Z * sin(th))
			local z = c.Z - (c.Y * sin(th) + c.Z * cos(th))
			return { JointRoot = R(y, th, z) }
		end })
		-- tails thrown forward for the crouch; fully flared as it leaves the ground, then snapped short and tight
		-- for the inversion (a 20-stud tail swinging round the body would sweep through the floor), flared
		-- again for the landing
		local tl = {
			TK(0, T_REST), TK(0.15, aimShape(azLane(30 * math.pi / 180), math.rad(38), 0.25)),
			TK(W + 0.02, shp({ fan = 0.5, lift = -0.3, e = 0.9, curl = 0.3 })), TK(W + 0.06, shp({ fan = 0.5, lift = -0.25, e = 1, curl = 0.3 })),
			TK(W + 0.15, shp({ fan = 0.3, lift = -0.1, e = 0.1, hook = -1 }), "in"), TK(W + 0.5, shp({ fan = 0.25, lift = -0.05, e = 0.08, hook = -1 })),
			TK(W + 0.58, shp({ fan = 0.4, lift = 0.0, e = 0.3 })),
			TK(W + Act + 0.1, T_FLARE), TK(W + Act + Rec, T_REST),
		}
		register("MoonLeap", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.2, crouch, ALL, crouchR, "inOut"), K(0.34, crouch, ALL, crouchR), K(W, spring2, HIND, paws(0, 0.8, 0.1, 0.14), "in") }),
			flight,
			ph(Rec, { K(0, land, ALL, nil), K(0.1, absorb, ALL, absorbR, "out"), K(0.26, with(absorb, { JointRoot = R(-0.4) }), ALL, absorbR, "inOut"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.004 })
	end
	build("A", 1, 0.18, 1.0)
	build("B", 1, 0.3, 0.7) -- a later, tighter-timed flip (rises first, then rolls fast), a looser tuck
end

------------------------------------------------------------------------------------
-- MOURNFULSCREAM 1.4 / 0.3 / 1.3: rear up, head thrown back, jaw wide, ears pinned, the
-- tails flared straight up and extended; hold u 0.5-1; it shudders into the active phase;
-- the recover slumps and pants.
do
	local W, Act, Rec = 1.4, 0.3, 1.3
	local function build(v: string, tallY: number, pitch: number, headBack: number, wail: boolean)
		local dip = B({ y = -0.45, pitch = -0.05, ch = -0.2, n = -0.3, h = -0.1, e = 0.5, t = 0.3 })
		local rear = B({ y = tallY, pitch = pitch, ch = 0.16, n = headBack, h = headBack * 0.5, hr = 0, j = -1.0, e = 0.85, ef = 0.02, t = 0.6, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
		local rearR = paws(0.12, -0.05, 0.06, 0.1)
		local slump = B({ y = -0.36, pitch = -0.06, ch = -0.12, n = -0.2, h = -0.16, j = -0.2, e = 0.45, t = 0.3 })
		local slumpR = paws(-0.25, 0.3, 0.2, 0.18)
		local after = with(rear, { JointJaw = A(-0.8), JointRoot = R(-0.05, pitch - 0.05) })
		local shudder = function(u: number, secs: number, _: any): Pose
			local k = smooth(0.55, 0.8, u)
			return { JointRoot = R(0.012 * k * sin(secs * 31), 0, 0, 0.02 * k * sin(secs * 27), 0.025 * k * sin(secs * 23 + 1)), JointChest = A(0.03 * k * sin(secs * 29)),
				JointHead = A(0.02 * k * sin(secs * 33), 0, 0), JointJaw = A(0.08 * k * sin(secs * 17) - (if wail then 0.05 * k else 0)) }
		end
		local pant = function(u: number, secs: number, _: any): Pose
			local k = 1 - smooth(0.5, 0.95, u)
			local b = sin(secs * TAU * 2.4) * k
			return { JointChest = A(0.06 * b), JointJaw = A(-0.1 * math.max(0, b)), JointNeck = A(0.04 * b) }
		end
		local tl = { TK(0, T_REST), TK(0.5, T_UPH), TK(0.9, T_UP), TK(W + Act, T_UP), TK(W + Act + 0.6, shp({ fan = 0.35, lift = 0.1, e = 0.2 })), TK(W + Act + Rec, T_REST) }
		register("MournfulScream", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.4, dip, ALL, LOWR, "inOut"), K(0.8, rear, HIND, rearR, "out"), K(W, rear, HIND, rearR) }, { overlay = shudder }),
			ph(Act, { K(0, rear, HIND, rearR), K(Act, after, HIND, rearR, "out") }, { overlay = function(u, secs, i) return shudder(1, secs, i) end }),
			ph(Rec, { K(0, after, HIND, rearR), K(0.4, slump, ALL, slumpR, "inOut"), K(0.9, slump, ALL, slumpR), K(Rec, STAND, ALL, nil, "inOut") }, { overlay = pant }),
			{ keys = tl, lag = 0.03, wave = 2.2 })
	end
	build("A", -0.05, 0.85, 0.62, false)
	build("B", -0.2, 0.62, 0.5, true) -- a lower, wailing rear, jaw working
end

------------------------------------------------------------------------------------
-- NINETAILFALL 1.8 / 0.1 / 1.9: rear fully; all nine tails extend high into a wide fan
-- overhead and hold; then each slams down in order (0.2 s apart), the body dropping with each
-- hit; the recover heaves. The lance ends are solved onto the ground around the fox.
do
	local W, Act, Rec = 1.8, 0.1, 1.9
	local AZ = { 88, 74, 62, 50, 38, -50, -62, -74, -88 } -- tails 1..9, left positive; the middle tail leans left
	local function build(v: string, stepDrop: number, fanWide: number, ePlunge: number, dropOrder: string)
		local function hitTime(i: number, ctx: any): number
			local parts = ctx and ctx.parts
			if parts then
				for _, p in parts do
					if p.tail == i then
						return W + (p.delay or 0)
					end
				end
			end
			return W + 0.2 * (i - 1) * (if dropOrder == "rev" then -1 else 1) + (if dropOrder == "rev" then 1.6 else 0)
		end
		local ground = function(i: number, s: number, ctx: any): (number, number, number, number)
			local t = hitTime(i, ctx)
			local w = smooth(t - 0.28, t - 0.02, s) * (1 - smooth(W + Act + 1.15 + 0.05 * (i - 1), W + Act + 1.5 + 0.05 * (i - 1), s))
			return w, math.rad(AZ[i]), ePlunge, 0.3
		end
		local up = shp({ fan = fanWide, lift = -0.61, e = 1 })
		local rear = B({ y = -0.05, pitch = 0.85, ch = 0.16, n = 0.45, h = 0.2, hr = 0, j = -0.5, e = 0.55, ef = 0.25, t = -0.2, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
		local coil = B({ y = -0.5, pitch = 0, ch = -0.12, n = -0.1, h = -0.1, e = 0.5, t = 0.4 })
		local rearR = paws(0.1, -0.05, 0.06, 0.1)
		local slam1 = B({ y = -0.12, pitch = 0.62, ch = 0.12, n = 0.3, h = 0.1, j = -0.4, e = 0.6, t = -0.2, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
		local mid = B({ y = -0.15, pitch = 0.3, ch = 0.0, n = 0.1, h = -0.05, j = -0.35, e = 0.6, t = 0.4 })
		local low = B({ y = -0.3, pitch = -0.05, ch = -0.1, n = -0.15, h = -0.12, j = -0.3, e = 0.6, t = 0.3 })
		local lowR = paws(-0.3, 0.35, 0.3, 0.2)
		local heave = function(u: number, secs: number, _: any): Pose
			local k = smooth(0.5, 0.75, u) * (1 - smooth(0.85, 1, u))
			local b = sin(secs * TAU * 1.3) * k
			return { JointChest = A(0.07 * b), JointRoot = R(0.03 * b), JointNeck = A(-0.05 * b) }
		end
		local slams = function(u: number, secs: number, phaseName: string): Pose
			-- each hit drops the body a little and rings
			local out = 0
			local tr = if phaseName == "active" then secs else Act + secs
			for i = 1, 9 do
				local t = 0.2 * (i - 1) + 0.04
				out += stepDrop * smooth(t - 0.04, t + 0.08, tr) + 0.04 * math.exp(-9 * math.max(0, tr - t)) * sin(math.max(0, tr - t) * TAU * 3) * (if tr > t then 1 else 0)
			end
			return { JointRoot = R(-out, -out * 0.7) }
		end
		register("NineTailFall", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.4, coil, ALL, LOWR, "inOut"), K(0.95, rear, HIND, rearR, "out"), K(W, rear, HIND, rearR) }, { overlay = function(u: number, secs: number, _: any): Pose
				local k = smooth(0.6, 0.8, u)
				return { JointRoot = R(0, 0.015 * k * sin(secs * 13)), JointNeck = A(0.03 * k * sin(secs * 9)) }
			end }),
			ph(Act, { K(0, rear, HIND, rearR), K(Act, slam1, HIND, rearR, "out") }, { overlay = function(u, secs, _) return slams(u, secs, "active") end }),
			ph(Rec, { K(0, slam1, HIND, rearR), K(0.5, mid, HIND, rearR, "inOut"), K(0.95, mid, ALL, paws(-0.1, 0.1, 0.12, 0.12), "inOut"), K(1.45, low, ALL, lowR, "inOut"), K(1.7, low, ALL, lowR), K(Rec, STAND, ALL, nil, "inOut") }, { overlay = function(u: number, secs: number, i: any)
				local a = slams(u, secs, "recover")
				local b = heave(u, secs, i)
				a.JointRoot = a.JointRoot * b.JointRoot
				a.JointChest = b.JointChest
				a.JointNeck = b.JointNeck
				return a
			end }),
			{ keys = { TK(0, T_REST), TK(0.5, T_UPH), TK(1.15, up), TK(W + Act + 1.7, shp({ fan = 0.5, lift = 0.1, e = 0.2 })), TK(W + Act + Rec, T_REST) }, lag = 0.02, ground = ground })
	end
	build("A", 0.03, 0.55, 0.62, "fwd")
	build("B", 0.04, 0.5, 0.55, "fwd") -- harder drops, a narrower fan
	build("C", 0.025, 0.55, 0.7, "fwd") -- longer plunges
end

------------------------------------------------------------------------------------
-- VEILBREAK 1.6 / 0.2 / 0.8: rear, head back, the tails flare outward in a ring, then burst
-- wide on contact as the forepaws slam down.
do
	local W, Act, Rec = 1.6, 0.2, 0.8
	local function build(v: string, slam: boolean, riseY: number, pitch: number)
		local dip = B({ y = -0.5, ch = -0.2, n = -0.25, h = -0.1, e = 0.5, t = 0.3 })
		local rear = B({ y = riseY, pitch = pitch, ch = 0.18, n = 0.55, h = 0.3, hr = 0, j = -0.9, e = 0.7, ef = 0.15, t = 0.55, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
		local rearR = paws(0.1, -0.05, 0.06, 0.1)
		local burst = if slam then B({ y = -0.32, pitch = -0.1, ch = -0.12, n = -0.14, h = -0.1, j = -0.6, e = 0.6, t = 0.2 })
			else B({ y = riseY, pitch = pitch + 0.1, ch = 0.25, n = 0.7, h = 0.35, hr = 0, j = -1.0, e = 0.5, ef = 0.3, t = 0.2, legs = merge(FL(0.45, -1.4, 0.2), FRr(0.45, -1.4, 0.2)) })
		local burstR = if slam then paws(-0.35, 0.3, 0.3, 0.2) else rearR
		local bp = if slam then ALL else HIND
		local settle = B({ y = -0.25, pitch = 0.0, ch = -0.06, n = -0.05, h = -0.12, j = -0.2, e = 0.5, t = 0.35 })
		-- the tails: raised in a ring, then a burst outward
		local ring = function(i: number, ctx: any): Q
			local t = (i - 5) / 4
			local q = shp({ fan = 0.5, lift = -0.4, out = 0.12, e = 0.25 })(i, ctx)
			q.w = t * 0.0
			return q
		end
		local burstT = shp({ fan = 0.55, lift = -0.3, out = 0.2, e = 1 })
		local tl = { TK(0, T_REST), TK(0.7, ring), TK(1.3, T_UPH), TK(W - 0.04, T_UPH), TK(W + 0.12, burstT, "out"), TK(W + Act + 0.3, shp({ fan = 0.55, lift = -0.1, e = 0.8 })), TK(W + Act + Rec, T_REST) }
		register("VeilBreak", v, W, Act, Rec,
			ph(W, { K(0, STAND, ALL), K(0.5, dip, ALL, LOWR, "inOut"), K(1.0, rear, HIND, rearR, "out"), K(1.45, rear, HIND, rearR), K(W - 0.03, burst, bp, burstR, "in"), K(W, burst, bp, burstR) }, { overlay = function(u: number, secs: number, _: any): Pose
				local k = smooth(0.7, 0.9, u) * (1 - smooth(0.95, 1, u))
				return { JointRoot = R(0.01 * k * sin(secs * 20)), JointHead = A(0.03 * k * sin(secs * 17)) }
			end }),
			ph(Act, { K(0, burst, bp, burstR), K(Act, burst, bp, burstR) }),
			ph(Rec, { K(0, burst, bp, burstR), K(0.3, settle, ALL, BRACE, "out"), K(Rec, STAND, ALL, nil, "inOut") }),
			{ keys = tl, lag = 0.03, wave = 1.5 })
	end
	build("A", true, -0.05, 0.75)
	build("B", false, -0.1, 0.5) -- arches back and bursts without the slam
end

------------------------------------------------------------------------------------
-- STAGGER 0.28 (single phase): recoil with the tails fanned out. Mirrored by input.side.
do
	local rec = B({ y = -0.15, pitch = 0.16, ch = 0.2, n = 0.35, h = 0.22, hr = 0, j = -0.55, e = 0.8, ef = 0.05, t = 0.5, legs = merge(FL(0.25, -0.2, 0), FRr(0.25, -0.2, 0)) })
	local rec2 = B({ y = -0.22, pitch = 0.1, ch = 0.12, n = 0.25, h = 0.12, j = -0.4, e = 0.7, t = 0.4 })
	local reach = paws(-0.25, 0.2, 0.25, 0.2)
	local win: Phase = ph(0.28, { K(0, STAND, ALL), K(0.05, rec, ALL, reach, "out"), K(0.14, rec, ALL, reach), K(0.28, rec2, ALL, reach, "inOut") }, { overlay = function(u: number, secs: number, input: any): Pose
		local side = clamp(input.side or 0, -1, 1)
		local e = smooth(0, 0.2, u)
		return { JointNeck = A(0, -0.25 * side * e), JointHead = A(0, 0, -0.12 * side * e), JointRoot = R(0, 0, 0, 0, 0.06 * side * e * sin(secs * 30)) }
	end })
	register("Stagger", "A", 0, 0.28, 0, ph(0.28, { K(0, STAND, ALL) }), win, ph(0.28, { K(0, STAND, ALL) }), { keys = { TK(0, T_REST), TK(0.06, shp({ fan = 0.55, lift = -0.1, e = 0.25, hook = 1 }), "out"), TK(0.28, shp({ fan = 0.5, lift = 0.0, e = 0.15 })) }, lag = 0.02, wave = 2 })
	DUR.Stagger = { 0, 0.28, 0 }
	variants.Stagger.A.windup = nil :: any
	variants.Stagger.A.recover = nil :: any
end

------------------------------------------------------------------------------------
-- DEATH 3.2 (single phase, mirrored): thrown back, a staggering sway as the legs give, a fall
-- onto the side and a long settle; the tails droop in order 1..9 as the flames gutter, the
-- last going limp last.
do
	local hit = B({ y = 0.0, pitch = 0.3, ch = 0.22, n = 0.45, h = 0.25, hr = 0, j = -0.7, e = 0.85, ef = 0.05, t = 0.0, legs = merge(FL(0.4, -0.2, 0), FRr(0.4, -0.2, 0)) })
	local hitR = paws(-0.35, 0.3, 0.25, 0.2)
	local sag = B({ y = -0.85, pitch = 0.05, ch = -0.1, n = -0.2, h = -0.2, roll = 0.14, j = -0.25, e = 0.55, t = 0.0 })
	local sag2 = B({ y = -1.05, pitch = 0.0, ch = -0.12, n = -0.3, h = -0.25, roll = -0.2, j = -0.2, e = 0.5, t = 0.0 })
	local sagR = paws(-0.2, 0.3, 0.35, 0.3)
	local limp = merge(FL(0.5, -0.9, -0.2), FRr(0.15, -0.6, -0.1), BLg(0.5, -0.8, 0.1), BRg(0.1, -0.5, 0.1))
	local fall = B({ y = -1.5, pitch = 0.0, roll = 1.45, ch = 0.0, chr = 0.06, n = -0.2, nr = 0.2, h = -0.2, hr = 0.2, j = -0.3, e = 0.35, t = 0.0, legs = limp })
	local bounce = B({ y = -1.62, pitch = 0.0, roll = 1.38, ch = 0.0, n = -0.15, h = -0.15, hr = 0.2, j = -0.35, e = 0.4, t = 0.0, legs = limp })
	local rest = B({ y = -1.7, pitch = 0.0, roll = 1.5, ch = 0.0, n = -0.25, h = -0.25, hr = 0.15, j = -0.1, e = 0.3, t = 0.0, legs = merge(FL(0.4, -0.7, -0.2), FRr(0.2, -0.4, -0.1), BLg(0.4, -0.7, 0.1), BRg(0.1, -0.4, 0.1)) })
	local win: Phase = ph(3.2, { K(0, STAND, ALL), K(0.12, hit, ALL, hitR, "out"), K(0.5, hit, ALL, hitR), K(1.1, sag, ALL, sagR, "inOut"), K(1.5, sag2, ALL, sagR, "inOut"),
		K(1.95, fall, NONE, nil, "in"), K(2.15, bounce, NONE, nil, "out"), K(2.5, rest, NONE, nil, "inOut"), K(3.2, rest, NONE) },
		{ mirror = true, overlay = function(u: number, secs: number, _: any): Pose
			local k = smooth(0.12, 0.4, u / 1) * (1 - smooth(0.4, 0.62, u))
			return { JointRoot = R(0, 0, 0, 0.05 * k * sin(secs * 5), 0.05 * k * sin(secs * 3.3)), JointHead = A(0.06 * k * sin(secs * 4)) }
		end })
	-- the tails droop in order, 0.25 s apart, the flames guttering
	local droop = function(i: number, _): Q
		local q = shp({ fan = 0.5, lift = 0.5, curl = 0.2, hook = 1 })(i, nil)
		return q
	end
	register("Death", "A", 0, 3.2, 0, ph(3.2, { K(0, STAND, ALL) }), win, ph(3.2, { K(0, STAND, ALL) }),
		{ keys = { TK(0, T_REST), TK(0.15, shp({ fan = 0.55, lift = -0.2, e = 0.3 }), "out"), TK(0.9, T_LOW), TK(1.8, droop), TK(2.6, shp({ fan = -0.5, lift = 0.2, e = 0.3, hook = 1 })), TK(3.2, shp({ fan = -0.75, lift = 0.2, e = 0.3, hook = 1.5 })) }, lagFn = function(i) return 0.3 * (i - 1) end, wave = 0.6, floor = 0.15, floorSafe = shp({ fan = -1.15, lift = 0.1, e = 0.0 }) })
	DUR.Death = { 0, 3.2, 0 }
	variants.Death.A.windup = nil :: any
	variants.Death.A.recover = nil :: any
end

------------------------------------------------------------------------------------
-- Variants and API

NineTailFox.VARIANTS = variants
local DEFAULT: { [string]: string } = {
	Intro = "A", FangDance = "A", TailSweep = "A", TailLance = "A", LanceFan = "A", TailSnare = "A", RendingPounce = "A",
	FoxfireVolley = "A", RootfireEruption = "A", MoonLeap = "A", MournfulScream = "A", NineTailFall = "A", VeilBreak = "A", Stagger = "A", Death = "A",
}
for k, v in DEFAULT do
	VARIANT[k] = v
end
NineTailFox.VARIANT = VARIANT
function NineTailFox.setVariant(move: string, v: string)
	assert(variants[move] and variants[move][v], "no variant " .. move .. "." .. v)
	VARIANT[move] = v
end
function NineTailFox.setAll(v: string)
	for move, list in variants do
		if list[v] then
			VARIANT[move] = v
		end
	end
end

for name, list in variants do
	local stock = list.A
	moves[name] = { windup = stock.windup, active = stock.active, recover = stock.recover }
end
NineTailFox.moves = moves
NineTailFox.durations = Quadruped.durations(moves)
NineTailFox.loops = loops
NineTailFox.DEFAULT_PARTS = defaultParts

function NineTailFox.sample(move: string, phase: string, u: number, input: Input?): Pose
	return sampleMove(move, phase, u, input)
end

-- translations scale with the body: the root's, and every telescoping tail slide
function NineTailFox.scaled(pose: Pose, scale: number): Pose
	if scale == 1 then
		return pose
	end
	local cf = pose.JointRoot
	if cf then
		pose.JointRoot = cf - cf.Position + cf.Position * scale
	end
	for i = 1, 9 do
		for _, suffix in { "Mid", "Tip", "Whip" } do
			local name = "JointTail" .. i .. suffix
			local c = pose[name]
			if c then
				pose[name] = c - c.Position + c.Position * scale
			end
		end
	end
	return pose
end
NineTailFox.plant = rig.plant
NineTailFox.rig = rig

return NineTailFox
