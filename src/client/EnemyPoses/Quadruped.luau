--!strict
-- Shared maths for the four-legged pose modules in EnemyPoses/ (Boar; Wolf.luau still
-- carries its own identical copy, see the note below): easing,
-- key sampling, mirroring, and the leg planting (two-joint IK, root drop, floor clamp,
-- gait stepping). Pure maths, no instances. The pose FORMAT is documented in Wolf.luau.
--
-- Quadruped.new(spec) builds a rig's solver from its skeleton:
--   spec.P       { [MotorName] = Vector3 }: each joint's pivot at rest, model space,
--                ground at Y 0 (the root, the spine and every leg joint)
--   spec.root    the body root motor ("JointRoot")
--   spec.spine   the spine motor the fore legs hang from ("JointSpine", "JointChest")
--   spec.legs    { FL/FR/BL/BR = Leg }:
--                  upper, mid, foot  the leg's three motors (hip, middle, paw or hoof)
--                  base   the motor the leg hangs from (spec.root or spec.spine)
--                  fold   the sign of the middle joint's natural bend from rest
--                  front  true on the fore legs (picks the sole and the swing curl)
--                  knee   which side of the upper-to-foot line the middle joint sits on
--                         (-1 behind it, +1 in front of it, -Z), so a two-joint solve
--                         never flips the leg
--   spec.sole    { front = { Vector3 }, hind = { Vector3 } }: the lowest corners of
--                each foot, relative to its pivot at rest (the floor check)
--   spec.curl    { front = number, hind = number }: the foot's pitch at full swing
--                lift (negative tips the toe down)
--   spec.lift    the middle joint's bend at full swing lift (times fold), default 0.3
-- Wolf.luau can switch to this with no change in output (checked bit for bit over every
-- move and loop), but wolf_family/qa_wolf_poses.luau requires a parentless clone of Wolf,
-- which can't see a sibling module: switch both together.
-- It returns { P, LEGS, plantOf, samplePhase, plantLegs (noDrop: the caller set the drop),
-- reachShort, solveLeg, setLeg, stepLegs, sampler(moves, name), plant }. The free helpers are on Quadruped itself.

local Quadruped = {}

export type Pose = { [string]: CFrame }
export type Input = {
	duration: number?,
	side: number?,
	targetYaw: number?,
	dir: number?,
	seed: number?,
}
export type Plant = { [string]: number }
export type Key = { t: number, pose: Pose, ease: string?, plant: { string }?, reach: { [string]: Vector3 }? }
export type Phase = {
	duration: number,
	keys: { Key },
	overlay: ((u: number, secs: number, input: Input) -> Pose)?,
	mirror: boolean?,
	air: boolean?,
}
export type Leg = { upper: string, mid: string, foot: string, base: string, fold: number, front: boolean, knee: number }
export type Step = { stance: number, clear: number, flex: number }

local I = CFrame.identity
local TAU = math.pi * 2
Quadruped.TAU = TAU

local ALL = { "FL", "FR", "BL", "BR" }
local NONE = {}
Quadruped.ALL = ALL
Quadruped.FRONT = { "FL", "FR" }
Quadruped.HIND = { "BL", "BR" }
Quadruped.NONE = NONE

local function A(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(x, y or 0, z or 0)
end
Quadruped.A = A

-- the root: a translation in studs (y down/up, z back/forward), then pitch, yaw, roll
function Quadruped.R(y: number, pitch: number?, z: number?, yaw: number?, roll: number?): CFrame
	return CFrame.new(0, y, z or 0) * CFrame.Angles(pitch or 0, yaw or 0, roll or 0)
end

local function pitchOf(cf: CFrame?): number
	if not cf then
		return 0
	end
	local x = cf:ToEulerAnglesXYZ()
	return x
end
Quadruped.pitchOf = pitchOf

local function wrap(a: number): number
	return (a + math.pi) % TAU - math.pi
end

local function ang(v: Vector3): number
	return math.atan2(v.Z, v.Y)
end

-- the paw pivot's height as a function of the middle joint's pitch m:
-- K + Pc cos m + Qs sin m
local function coeffs(mb: CFrame, d: Vector3): (number, number, number)
	local _, _, _, _, _, _, r10, r11, r12 = mb:GetComponents()
	return mb.Y + r10 * d.X, r11 * d.Y + r12 * d.Z, r12 * d.Y - r11 * d.Z
end

------------------------------------------------------------------------------------
-- Mirroring

local function mirrorCF(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end
Quadruped.mirrorCF = mirrorCF

local function mirrorName(name: string): string
	local last = string.sub(name, -1)
	if last == "L" then
		return string.sub(name, 1, -2) .. "R"
	elseif last == "R" then
		return string.sub(name, 1, -2) .. "L"
	end
	return name
end

local function mirrorPose(pose: Pose): Pose
	local out = {}
	for name, cf in pose do
		out[mirrorName(name)] = mirrorCF(cf)
	end
	return out
end
Quadruped.mirrorPose = mirrorPose

------------------------------------------------------------------------------------
-- Easing and small helpers

local EASE: { [string]: (number) -> number } = {
	linear = function(a)
		return a
	end,
	["in"] = function(a)
		return a * a
	end,
	out = function(a)
		return 1 - (1 - a) * (1 - a)
	end,
	inOut = function(a)
		return if a < 0.5 then 4 * a * a * a else 1 - (-2 * a + 2) ^ 3 / 2
	end,
	outBack = function(a)
		local c = 1.6
		return 1 + (c + 1) * (a - 1) ^ 3 + c * (a - 1) ^ 2
	end,
	step = function(a)
		return if a >= 1 then 1 else 0
	end,
}
Quadruped.EASE = EASE

-- 0 outside [a, b], a smooth hump (sin) inside
function Quadruped.bump(x: number, a: number, b: number): number
	if x <= a or x >= b then
		return 0
	end
	return math.sin(math.pi * (x - a) / (b - a))
end

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
Quadruped.smooth = smooth

function Quadruped.with(base: Pose, changes: Pose): Pose
	local out = table.clone(base)
	for k, v in changes do
		out[k] = v
	end
	return out
end

function Quadruped.hash(n: number, seed: number): number
	local x = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- planted foot offsets from their rest spots (studs, model space: -Z forward, -X the
-- beast's left): fore z, hind z, fore spread, hind spread
function Quadruped.paws(fz: number, hz: number, fx: number?, hx: number?): { [string]: Vector3 }
	local V = Vector3.new
	return { FL = V(-(fx or 0), 0, fz), FR = V(fx or 0, 0, fz), BL = V(-(hx or 0), 0, hz), BR = V(hx or 0, 0, hz) }
end

local function plantOf(list: { string }?): Plant
	local out = { FL = 0, FR = 0, BL = 0, BR = 0 }
	for _, tag in list or NONE do
		out[tag] = 1
	end
	return out
end
Quadruped.plantOf = plantOf

-- One leg's swing for a gait: its pitch, lift (0 in stance, up to 1 mid swing) and
-- plant weight. Swing is while the angle rises (the foot moving forward).
function Quadruped.legCycle(phase: number, amp: number): (number, number, number)
	local a = amp * math.sin(phase)
	local lift = math.max(0, math.cos(phase))
	return a, lift, 1 - smooth(0, 0.25, lift)
end

-- Samples a keyed phase at u: the blended pose (overlay applied, mirrored if asked),
-- the plant weights and the reach offsets.
function Quadruped.samplePhase(phase: Phase, u: number, input: Input): (Pose, Plant, { [string]: Vector3 })
	local keys = phase.keys
	u = math.clamp(u, 0, 1)
	local a, b = keys[1], keys[1]
	for i = 2, #keys do
		a, b = keys[i - 1], keys[i]
		if u <= b.t then
			break
		end
		a = b
	end
	local alpha = 1
	if b ~= a and b.t > a.t then
		alpha = EASE[b.ease or "linear"](math.clamp((u - a.t) / (b.t - a.t), 0, 1))
	end
	local pose: Pose = {}
	for name, cf in a.pose do
		pose[name] = cf:Lerp(b.pose[name] or I, alpha)
	end
	for name, cf in b.pose do
		if not a.pose[name] then
			pose[name] = I:Lerp(cf, alpha)
		end
	end
	local pa, pb = plantOf(a.plant), plantOf(b.plant)
	local plant = {}
	for tag, w in pa do
		plant[tag] = w + (pb[tag] - w) * alpha
	end
	local reach = {}
	for _, tag in ALL do
		local ra = (a.reach and a.reach[tag]) or Vector3.zero
		local rb = (b.reach and b.reach[tag]) or Vector3.zero
		reach[tag] = ra:Lerp(rb, alpha)
	end
	if phase.overlay then
		local secs = u * (input.duration or phase.duration)
		for name, cf in phase.overlay(u, secs, input) do
			pose[name] = (pose[name] or I) * cf
		end
	end
	if phase.mirror and (input.side or 1) < 0 then
		pose = mirrorPose(pose)
		plant = { FL = plant.FR, FR = plant.FL, BL = plant.BR, BR = plant.BL }
		local m = Vector3.new(-1, 1, 1)
		reach = { FL = reach.FR * m, FR = reach.FL * m, BL = reach.BR * m, BR = reach.BL * m }
	end
	return pose, plant, reach
end

-- JointRoot translation times scale (the bigger bodies of one skeleton)
function Quadruped.scaled(pose: Pose, scale: number, root: string?): Pose
	local name = root or "JointRoot"
	local cf = pose[name]
	if cf and scale ~= 1 then
		pose[name] = cf - cf.Position + cf.Position * scale
	end
	return pose
end

-- the designed phase lengths, seconds
function Quadruped.durations(moves: { [string]: { [string]: Phase } }): { [string]: { [string]: number } }
	local out = {}
	for name, phases in moves do
		out[name] = {}
		for phase, p in phases do
			out[name][phase] = p.duration
		end
	end
	return out
end

------------------------------------------------------------------------------------
-- A rig's leg solver

export type Spec = {
	P: { [string]: Vector3 },
	root: string,
	spine: string,
	legs: { [string]: Leg },
	sole: { front: { Vector3 }, hind: { Vector3 } },
	curl: { front: number, hind: number },
	lift: number?,
}

function Quadruped.new(spec: Spec)
	local P, LEGS, SOLE = spec.P, spec.legs, spec.sole
	local ROOT, SPINE = spec.root, spec.spine
	local LIFT = spec.lift or 0.3

	-- the frame a leg's upper joint turns in, before its own Transform
	local function upperBase(pose: Pose, leg: Leg): CFrame
		local root = CFrame.new(P[ROOT]) * (pose[ROOT] or I)
		local base = root
		if leg.base == SPINE then
			base = root * CFrame.new(P[SPINE] - P[ROOT]) * (pose[SPINE] or I)
		end
		return base * CFrame.new(P[leg.upper] - P[leg.base])
	end

	-- the frame a leg's middle joint turns in, before its own Transform
	local function midBase(pose: Pose, leg: Leg): CFrame
		return upperBase(pose, leg) * (pose[leg.upper] or I) * CFrame.new(P[leg.mid] - P[leg.upper])
	end

	-- how far the root must drop for a planted leg to reach its foot spot (the leg never
	-- stretches past its rest length)
	local function reachShort(pose: Pose, leg: Leg, target: Vector3, stretch: number?): number
		local s = upperBase(pose, leg).Position
		local lmax = (P[leg.foot] - P[leg.upper]).Magnitude * (stretch or 1)
		local dx, dz = target.X - s.X, target.Z - s.Z
		local h2 = dx * dx + dz * dz
		local v = s.Y - target.Y
		if h2 >= lmax * lmax then
			return math.max(0, v)
		end
		return math.max(0, v - math.sqrt(lmax * lmax - h2))
	end

	-- Two-joint solve in the leg's own plane: turns the upper and middle joints so the
	-- foot pivot lands on target (model space), blended by w. Authored roll is kept.
	local function reachLeg(pose: Pose, leg: Leg, target: Vector3, w: number)
		local t = upperBase(pose, leg):PointToObjectSpace(target)
		local u, d = P[leg.mid] - P[leg.upper], P[leg.foot] - P[leg.mid]
		local l1, l2 = math.sqrt(u.Y * u.Y + u.Z * u.Z), math.sqrt(d.Y * d.Y + d.Z * d.Z)
		local lmax = (P[leg.foot] - P[leg.upper]).Magnitude
		local dist = math.clamp(math.sqrt(t.Y * t.Y + t.Z * t.Z), math.abs(l1 - l2) + 1e-3, math.min(l1 + l2, lmax) - 1e-4)
		local phi = math.atan2(t.Z, t.Y)
		local alpha = math.acos(math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1))
		-- the leg points down, so +alpha puts the middle joint forward (-Z) of the line
		local upperDir = phi + alpha * leg.knee
		local ky, kz = l1 * math.cos(upperDir), l1 * math.sin(upperDir)
		local lowerDir = math.atan2(t.Z - kz, t.Y - ky)
		local upper = wrap(upperDir - ang(u))
		local mid = wrap(lowerDir - ang(d) - upper)
		local cu = pose[leg.upper] or I
		local ax, ay, az = cu:ToEulerAnglesXYZ()
		pose[leg.upper] = A(ax + (upper - ax) * w, ay, az)
		local am = pitchOf(pose[leg.mid])
		pose[leg.mid] = A(am + (mid - am) * w)
	end

	-- Bends one leg's middle joint so its foot pivot sits clear studs above its rest
	-- height and levels the foot (then tips it by flex), blended by w. Of the two bends
	-- that reach, it takes the one nearest the authored angle, never one bent against the
	-- authored sign (or, unauthored, against the leg's natural fold), so a solve can't
	-- flip sides.
	local function solveLeg(pose: Pose, leg: Leg, w: number, clear: number?, flex: number?)
		local d = P[leg.foot] - P[leg.mid]
		local mb = midBase(pose, leg)
		local K, Pc, Qs = coeffs(mb, d)
		local len = math.sqrt(Pc * Pc + Qs * Qs)
		local c = math.clamp((P[leg.foot].Y + (clear or 0) - K) / len, -1, 1)
		local th, ac = math.atan2(Qs, Pc), math.acos(c)
		local authored = pitchOf(pose[leg.mid])
		local sign = if math.abs(authored) > 0.1 then math.sign(authored) else leg.fold
		local function cost(m: number): number
			return math.abs(m - authored) + (if m * sign < -0.15 then 2 else 0)
		end
		local m1, m2 = wrap(th + ac), wrap(th - ac)
		local solved = if cost(m1) <= cost(m2) then m1 else m2
		local m = authored + (solved - authored) * w
		pose[leg.mid] = A(m)
		-- level the foot: no pitch, then no roll, in model space
		local fb = mb * A(m) * CFrame.new(d)
		local _, _, _, _, _, _, _, r11, r12 = fb:GetComponents()
		local f = math.atan2(r12, r11)
		local _, _, _, _, _, _, s10, s11 = (fb * A(f)):GetComponents()
		local g = math.atan2(-s10, s11)
		pose[leg.foot] = (pose[leg.foot] or I):Lerp(A(f) * A(0, 0, g) * A(flex or 0), w)
	end

	-- the lowest point of a leg's sole, as posed
	local function soleY(pose: Pose, leg: Leg): number
		local foot = midBase(pose, leg) * (pose[leg.mid] or I) * CFrame.new(P[leg.foot] - P[leg.mid]) * (pose[leg.foot] or I)
		local lo = math.huge
		for _, v in (if leg.front then SOLE.front else SOLE.hind) do
			lo = math.min(lo, (foot * v).Y)
		end
		return lo
	end

	-- Solves the planted legs onto the ground: each planted foot goes to its rest spot
	-- plus reach[tag] (studs, model space), the root dropping if a leg can't reach it.
	-- Then, unless the body is in the air (air: the client lifts it), any other foot that
	-- would dip below the ground is planted where it is. Mutates pose.
	-- noDrop: the root stays where it is and a leg that can't reach its spot straightens
	-- toward it (the caller has already set a drop, e.g. one eased over a touchdown)
	local function plantLegs(pose: Pose, plant: Plant, air: boolean?, reach: { [string]: Vector3 }?, noDrop: boolean?)
		local targets = {}
		local drop = 0
		for tag, w in plant do
			if w > 0.001 then
				local leg = LEGS[tag]
				targets[tag] = P[leg.foot] + ((reach and reach[tag]) or Vector3.zero)
				if not noDrop then
					drop = math.max(drop, reachShort(pose, leg, targets[tag]) * w)
				end
			end
		end
		if drop > 0 then
			pose[ROOT] = CFrame.new(0, -drop, 0) * (pose[ROOT] or I)
		end
		for tag, target in targets do
			local leg, w = LEGS[tag], plant[tag]
			reachLeg(pose, leg, target, w)
			solveLeg(pose, leg, w)
		end
		if not air then
			for tag, leg in LEGS do
				if (plant[tag] or 0) < 0.999 and soleY(pose, leg) < -0.005 then
					solveLeg(pose, leg, 1)
				end
			end
		end
	end

	-- Sets a gait leg's upper joint; every gait leg is then solved by stepLegs: the
	-- stance legs onto the ground (they also set the root's drop), the swing legs to
	-- clear studs over it with the foot curled.
	local function setLeg(pose: Pose, steps: { [string]: Step }, tag: string, a: number, roll: number, lift: number, w: number, clear: number)
		local leg = LEGS[tag]
		pose[leg.upper] = A(a, 0, roll)
		pose[leg.mid] = A(leg.fold * LIFT * lift) -- swinging, bend the natural way
		steps[tag] = { stance = w, clear = clear * lift, flex = (if leg.front then spec.curl.front else spec.curl.hind) * clear * lift }
	end

	local function stepLegs(pose: Pose, steps: { [string]: Step })
		local drop = 0
		for tag, st in steps do
			local leg = LEGS[tag]
			local d = P[leg.foot] - P[leg.mid]
			local K, Pc, Qs = coeffs(midBase(pose, leg), d)
			local short = (K - math.sqrt(Pc * Pc + Qs * Qs)) - P[leg.foot].Y
			if short > 0 then
				drop = math.max(drop, short * st.stance)
			end
		end
		if drop > 0 then
			pose[ROOT] = CFrame.new(0, -drop, 0) * (pose[ROOT] or I)
		end
		for tag, st in steps do
			solveLeg(pose, LEGS[tag], 1, st.clear, st.flex)
		end
	end

	-- module.sample for a moves table
	local function sampler(moves: { [string]: { [string]: Phase } }, name: string)
		return function(move: string, phase: string, u: number, input: Input?): Pose
			local m = moves[move]
			local p = m and m[phase]
			assert(p, ("%s.sample: no %s.%s"):format(name, move, phase))
			local pose, plant, reach = Quadruped.samplePhase(p, u, input or {})
			plantLegs(pose, plant, p.air, reach)
			return pose
		end
	end

	-- plants the listed legs (default all four) of a hand-made pose onto the ground
	local function plant(pose: Pose, legs: { string }?, reach: { [string]: Vector3 }?): Pose
		plantLegs(pose, plantOf(legs or ALL), false, reach)
		return pose
	end

	return {
		P = P,
		LEGS = LEGS,
		plantLegs = plantLegs,
		-- how far the root must drop for leg `tag` to reach its rest spot plus offset, with the
		-- leg stretched to `stretch` (default 1) of its full length
		reachShort = function(pose: Pose, tag: string, offset: Vector3?, stretch: number?): number
			local leg = LEGS[tag]
			return reachShort(pose, leg, P[leg.foot] + (offset or Vector3.zero), stretch)
		end,
		solveLeg = solveLeg,
		soleY = soleY,
		setLeg = setLeg,
		stepLegs = stepLegs,
		sampler = sampler,
		plant = plant,
	}
end

return Quadruped
