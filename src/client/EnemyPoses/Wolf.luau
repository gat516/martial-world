--!strict
-- Procedural pose tables for the wolf family (Spirit Wolf B, Elder Wolf King,
-- Shadow-Mane Wolf: one skeleton, see art/enemies/wolf_family/RIGS.md). Pure data and
-- maths, no instances: it returns Motor6D.Transform values by motor name, and the
-- caller (EnemyAnimator) sets them. This file's format is the fixed format for every
-- beast's pose module in EnemyPoses/.
--
-- FORMAT
--   A Pose is { [MotorName] = CFrame }: the joint's Transform. A joint left out is at
--   rest (identity). Every joint frame is identity in model space: the wolf faces -Z,
--   its left is -X. +X pitch tips the front up (a leg swings forward, the head lifts,
--   the tail tip drops, the ears pin back, the crest lies flat); the jaw opens on -X.
--   +Y turns to the wolf's left. +Z rolls its top toward its left.
--   Translations (JointRoot only) are in studs at Spirit Wolf scale: Wolf.scaled()
--   multiplies them for the bigger bodies (King 2.4, Shadow-Mane 1.15).
--
--   Wolf.moves[Move][Phase] is a Phase:
--     duration  the designed length in seconds (Enemies.luau's numbers win; pass the
--               real one as input.duration so overlays keep their speed in seconds)
--     keys      { { t = 0..1 of the phase, pose = Pose, ease = "out", plant = ALL,
--                   reach = { FL = Vector3 } } }
--               ease is the curve INTO this key from the previous one (linear, in,
--               out, inOut, outBack, step). plant lists the legs ("FL", "FR", "BL",
--               "BR") that are on the ground at this key; weights blend between keys.
--               reach moves a planted paw off its rest spot (studs, model space, -Z
--               forward); it blends between keys too.
--     overlay   optional function(u, secs, input) -> Pose, multiplied on top of the
--               keyed pose (shakes, wiggles, panting: things too fast to key).
--     mirror    true: input.side < 0 plays the move mirrored (left <-> right).
--     air       true: the client lifts the body (hop, leap flight), so paws may pass
--               below the standing ground line and aren't floor-clamped.
--   Wolf.loops[name](phase, speed, input) -> Pose for idle, walk, run and circle.
--   Phase names are windup / active / recover for every move: AIState "windup" ->
--   windup, "dash" (or the attack's resolve) -> active, "recover" -> recover.
--   Wolf.durations[Move][Phase] lists the designed seconds; Wolf.JOINTS the motors.
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt, where the telegraph, tell
-- flare and sound start)
--   Howl          windup 0.8 (sit back, throat up, jaw wide; standing again by 0.8)
--   FangSnap      windup 0.45, active 0.1, recover 0.5
--   MoonPounce    windup 0.7, active 0.3 (the dash), recover 0.9
--   MoonfallLeap  windup 1.0, active 0.45 (flight, air), recover 1.1 (land)
--   Hop           active 0.25 (air)
--   PounceSkid    recover 0.9 (the pounce overshot: brace, head leads, hind swings out; mirror)
--   LeapSkid      recover 1.1 (the leap missed: land, then the same skid-and-turn; mirror)
--   Stagger       active 0.28 (0.2-0.36 works: it snaps in by u 0.2)
--   Death         active 0.6, then hold u = 1 until the fade (mirror)
-- LOOPS: idle; walk (trot) up to 8 studs/s; run (gallop) from about 11 to 18+;
--   circle (crab-trot sideways, ~8 studs/s).
--
-- PLANTING. A planted paw stays on its rest spot (plus the key's reach): the leg's
-- upper and middle joints are solved for it (two-joint IK in the leg's plane, the
-- elbow kept behind the shoulder-paw line and the stifle in front of the hip-paw line)
-- and its paw joint levels the paw, so it rests flat on Y = 0 whatever the root and
-- spine do. If a planted leg can't reach its spot without stretching past its rest
-- length, the whole root drops until it can. So: author the root, spine, head and
-- tail; the planted legs follow. Authored angles on a planted leg only matter while
-- its plant weight blends in or out. Outside the air phases, a paw that isn't planted
-- but would dip below the ground is planted where it is (its middle joint bends).
-- The gait loops plant differently: they swing the upper legs from the gait cycle and
-- solve only the middle joint (stance paws on the ground, swing paws lifted clear).
--
-- API (all return a fresh table the caller may keep)
--   Wolf.sample(move, phase, u, input?) -> Pose        u = 0..1 of the phase, clamped
--   Wolf.loops.idle(clock, speed, input?) -> Pose      clock = seconds (os.clock())
--   Wolf.loops.walk(phase, speed, input?) -> Pose      phase in radians
--   Wolf.loops.run(phase, speed, input?) -> Pose
--   Wolf.loops.circle(phase, speed, input?) -> Pose    input.dir, input.targetYaw
--   Wolf.gaitRate(loop, speed, scale?) -> radians/s    advance phase by this * dt
--   Wolf.scaled(pose, scale) -> Pose                   JointRoot translation * scale
--   Wolf.plant(pose, legs?, reach?) -> Pose            plants a hand-made pose's legs
-- input fields (all optional):
--   duration   the phase's real length in seconds (default: the phase's duration)
--   side       Stagger: +1 hit came from the wolf's right, -1 from its left, 0 front
--              (the head is thrown away from it). Death: +1 killer on its right, so
--              it rolls onto its left side; -1 the mirror.
--   targetYaw  Circle: yaw from the body's facing to the target, radians, + = target
--              to the wolf's left. The head and neck turn to it (0.7 at most).
--   dir        Circle: +1 sidestepping to the wolf's left, -1 to its right.
--   seed       Idle: any number per wolf, so ear flicks and sniffs don't sync up.

local Wolf = {}

export type Pose = { [string]: CFrame }
export type Input = {
	duration: number?,
	side: number?,
	targetYaw: number?,
	dir: number?,
	seed: number?,
}
type Plant = { [string]: number }
export type Key = { t: number, pose: Pose, ease: string?, plant: { string }?, reach: { [string]: Vector3 }? }
export type Phase = {
	duration: number,
	keys: { Key },
	overlay: ((u: number, secs: number, input: Input) -> Pose)?,
	mirror: boolean?,
	air: boolean?,
}

local I = CFrame.identity
local TAU = math.pi * 2

local function A(x: number, y: number?, z: number?): CFrame
	return CFrame.Angles(x, y or 0, z or 0)
end
-- the root: a translation in studs (y down/up, z back/forward), then pitch, yaw, roll
local function R(y: number, pitch: number?, z: number?, yaw: number?, roll: number?): CFrame
	return CFrame.new(0, y, z or 0) * CFrame.Angles(pitch or 0, yaw or 0, roll or 0)
end

-- Every motor the three wolves share (JointCrest is on the Spirit Wolf and the King
-- only; a joint a body lacks is just skipped by the caller).
Wolf.JOINTS = {
	"JointRoot", "JointSpine", "JointNeck", "JointHead", "JointJaw", "JointEarL", "JointEarR",
	"JointLegFL", "JointElbowFL", "JointWristFL", "JointLegFR", "JointElbowFR", "JointWristFR",
	"JointLegBL", "JointKneeBL", "JointHockBL", "JointLegBR", "JointKneeBR", "JointHockBR",
	"JointTail", "JointTail2", "JointTail3", "JointCrest",
}

local ALL = { "FL", "FR", "BL", "BR" }
local FRONT = { "FL", "FR" }
local HIND = { "BL", "BR" }
local NONE = {}

------------------------------------------------------------------------------------
-- Skeleton (Spirit Wolf scale, ground at Y 0; from spirit_wolf/rig_wolf.luau)

local P = {
	JointRoot = Vector3.new(0, 2.85, 1.6),
	JointSpine = Vector3.new(0, 3.0, 0.8),
	JointLegFL = Vector3.new(-0.7, 2.45, -1.3),
	JointElbowFL = Vector3.new(-0.72, 1.35, -1.25),
	JointWristFL = Vector3.new(-0.72, 0.32, -1.35),
	JointLegFR = Vector3.new(0.7, 2.45, -1.3),
	JointElbowFR = Vector3.new(0.72, 1.35, -1.25),
	JointWristFR = Vector3.new(0.72, 0.32, -1.35),
	JointLegBL = Vector3.new(-0.7, 2.5, 2.1),
	JointKneeBL = Vector3.new(-0.75, 1.35, 1.8),
	JointHockBL = Vector3.new(-0.75, 0.62, 2.3),
	JointLegBR = Vector3.new(0.7, 2.5, 2.1),
	JointKneeBR = Vector3.new(0.75, 1.35, 1.8),
	JointHockBR = Vector3.new(0.75, 0.62, 2.3),
}

-- fold: the sign of the middle joint's natural bend from rest (the elbow folds the
-- forearm back on -X; the hind shin slants back, so the knee closes on -X too).
-- knee: which side of the hip-to-paw line the middle joint sits on (-1 behind it, the
-- elbow; +1 in front of it, the stifle), so a two-joint solve never flips the leg.
type Leg = { upper: string, mid: string, foot: string, base: string, fold: number, front: boolean, knee: number }
local LEGS: { [string]: Leg } = {
	FL = { upper = "JointLegFL", mid = "JointElbowFL", foot = "JointWristFL", base = "JointSpine", fold = -1, front = true, knee = -1 },
	FR = { upper = "JointLegFR", mid = "JointElbowFR", foot = "JointWristFR", base = "JointSpine", fold = -1, front = true, knee = -1 },
	BL = { upper = "JointLegBL", mid = "JointKneeBL", foot = "JointHockBL", base = "JointRoot", fold = -1, front = false, knee = 1 },
	BR = { upper = "JointLegBR", mid = "JointKneeBR", foot = "JointHockBR", base = "JointRoot", fold = -1, front = false, knee = 1 },
}

local function pitchOf(cf: CFrame?): number
	if not cf then
		return 0
	end
	local x = cf:ToEulerAnglesXYZ()
	return x
end

local function wrap(a: number): number
	return (a + math.pi) % TAU - math.pi
end

-- the frame a leg's middle joint turns in, before its own Transform
local function midBase(pose: Pose, leg: Leg): CFrame
	local root = CFrame.new(P.JointRoot) * (pose.JointRoot or I)
	local base = root
	if leg.base == "JointSpine" then
		base = root * CFrame.new(P.JointSpine - P.JointRoot) * (pose.JointSpine or I)
	end
	local upper = base * CFrame.new(P[leg.upper] - P[leg.base]) * (pose[leg.upper] or I)
	return upper * CFrame.new(P[leg.mid] - P[leg.upper])
end

-- the paw pivot's height as a function of the middle joint's pitch m:
-- K + Pc cos m + Qs sin m
local function coeffs(mb: CFrame, d: Vector3): (number, number, number)
	local _, _, _, _, _, _, r10, r11, r12 = mb:GetComponents()
	return mb.Y + r10 * d.X, r11 * d.Y + r12 * d.Z, r12 * d.Y - r11 * d.Z
end

-- the frame a leg's upper joint turns in, before its own Transform
local function upperBase(pose: Pose, leg: Leg): CFrame
	local root = CFrame.new(P.JointRoot) * (pose.JointRoot or I)
	local base = root
	if leg.base == "JointSpine" then
		base = root * CFrame.new(P.JointSpine - P.JointRoot) * (pose.JointSpine or I)
	end
	return base * CFrame.new(P[leg.upper] - P[leg.base])
end

local function ang(v: Vector3): number
	return math.atan2(v.Z, v.Y)
end

-- how far the root must drop for a planted leg to reach its paw spot (the leg never
-- stretches past its rest length)
local function reachShort(pose: Pose, leg: Leg, target: Vector3): number
	local s = upperBase(pose, leg).Position
	local lmax = (P[leg.foot] - P[leg.upper]).Magnitude
	local dx, dz = target.X - s.X, target.Z - s.Z
	local h2 = dx * dx + dz * dz
	local v = s.Y - target.Y
	if h2 >= lmax * lmax then
		return math.max(0, v)
	end
	return math.max(0, v - math.sqrt(lmax * lmax - h2))
end

-- Two-joint solve in the leg's own plane: turns the upper and middle joints so the
-- paw pivot lands on target (model space), blended by w. Authored roll is kept.
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

-- the lowest corners of each paw, relative to its pivot at rest (for the floor check)
local SOLE = {
	front = {
		Vector3.new(-0.32, -0.32, -0.89), Vector3.new(0.32, -0.32, -0.89),
		Vector3.new(-0.32, -0.32, 0.18), Vector3.new(0.32, -0.32, 0.18),
	},
	hind = {
		Vector3.new(-0.3, -0.62, -0.75), Vector3.new(0.3, -0.62, -0.75),
		Vector3.new(-0.3, -0.62, 0.05), Vector3.new(0.3, -0.62, 0.05),
	},
}

-- Bends one leg's middle joint so its paw pivot sits clear studs above its rest height
-- and levels the paw (then tips it by flex), blended by w. Of the two bends that reach,
-- it takes the one nearest the authored angle, never one bent against the authored
-- sign (or, unauthored, against the leg's natural fold), so a solve can't flip sides.
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
	-- level the paw: no pitch, then no roll, in model space
	local fb = mb * A(m) * CFrame.new(d)
	local _, _, _, _, _, _, _, r11, r12 = fb:GetComponents()
	local f = math.atan2(r12, r11)
	local _, _, _, _, _, _, s10, s11 = (fb * A(f)):GetComponents()
	local g = math.atan2(-s10, s11)
	pose[leg.foot] = (pose[leg.foot] or I):Lerp(A(f) * A(0, 0, g) * A(flex or 0), w)
end

-- the lowest point of a leg's paw sole, as posed
local function soleY(pose: Pose, leg: Leg): number
	local paw = midBase(pose, leg) * (pose[leg.mid] or I) * CFrame.new(P[leg.foot] - P[leg.mid]) * (pose[leg.foot] or I)
	local lo = math.huge
	for _, v in (if leg.front then SOLE.front else SOLE.hind) do
		lo = math.min(lo, (paw * v).Y)
	end
	return lo
end

-- Solves the planted legs onto the ground (see PLANTING above): each planted paw goes
-- to its rest spot plus reach[tag] (studs, model space), the root dropping if a leg
-- can't reach it. Then, unless the body is in the air (air: the client lifts it), any
-- other paw that would dip below the ground is planted where it is. Mutates pose.
local function plantLegs(pose: Pose, plant: Plant, air: boolean?, reach: { [string]: Vector3 }?)
	local targets = {}
	local drop = 0
	for tag, w in plant do
		if w > 0.001 then
			local leg = LEGS[tag]
			targets[tag] = P[leg.foot] + ((reach and reach[tag]) or Vector3.zero)
			drop = math.max(drop, reachShort(pose, leg, targets[tag]) * w)
		end
	end
	if drop > 0 then
		pose.JointRoot = CFrame.new(0, -drop, 0) * (pose.JointRoot or I)
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

local function mirrorCF(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

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

------------------------------------------------------------------------------------
-- Easing and sampling

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

local function bump(x: number, a: number, b: number): number
	-- 0 outside [a, b], a smooth hump (sin) inside
	if x <= a or x >= b then
		return 0
	end
	return math.sin(math.pi * (x - a) / (b - a))
end

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function with(base: Pose, changes: Pose): Pose
	local out = table.clone(base)
	for k, v in changes do
		out[k] = v
	end
	return out
end

local function plantOf(list: { string }?): Plant
	local out = { FL = 0, FR = 0, BL = 0, BR = 0 }
	for _, tag in list or NONE do
		out[tag] = 1
	end
	return out
end

local function samplePhase(phase: Phase, u: number, input: Input): (Pose, Plant, { [string]: Vector3 })
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

------------------------------------------------------------------------------------
-- Poses shared between moves

local STAND: Pose = {}

-- planted paw offsets from their rest spots (studs, model space: -Z forward, -X the
-- wolf's left)
local V = Vector3.new
local function paws(fz: number, hz: number, fx: number?, hx: number?): { [string]: Vector3 }
	return { FL = V(-(fx or 0), 0, fz), FR = V(fx or 0, 0, fz), BL = V(-(hx or 0), 0, hz), BR = V(hx or 0, 0, hz) }
end
local BRACED = paws(-0.3, 0) -- forepaws planted ahead
local CROUCHED = paws(-0.3, 0.4) -- forepaws ahead, hind paws back: the legs open, not jammed
local COILED = paws(-0.3, 0.6)
local SKIDDED = paws(-0.5, 0.5)
local SPLAYED = paws(-0.3, 0, 0.3, 0.25) -- landing: paws wide
local THROWN = paws(-0.3, 0.25) -- a hit: skidded wide fore and aft
-- standing, ears forward and alert, crest half laid
local ALERT: Pose = { JointEarL = A(-0.1), JointEarR = A(-0.1), JointCrest = A(0.05) }

-- Fang Snap: rear back with the jaw wide, forelegs braced, then snap forward and down
local SNAP_REAR: Pose = {
	JointRoot = R(0, 0.05, 0.15),
	JointSpine = A(-0.1),
	JointNeck = A(0.25),
	JointHead = A(0.15),
	JointJaw = A(-0.5),
	JointEarL = A(0.45),
	JointEarR = A(0.45),
	JointCrest = A(-0.25),
	JointLegFL = A(0.3), JointElbowFL = A(-0.15),
	JointLegFR = A(0.3), JointElbowFR = A(-0.15),
	JointLegBL = A(-0.15), JointKneeBL = A(0.35),
	JointLegBR = A(-0.15), JointKneeBR = A(0.35),
	JointTail = A(-0.35), JointTail2 = A(-0.1),
}
local SNAP_WIDE = with(SNAP_REAR, { JointJaw = A(-0.7), JointNeck = A(0.28) })
local SNAP_BITE: Pose = {
	-- the root lunges 0.3 forward; the upper legs give back 0.14 so the paws stay put
	JointRoot = R(0, -0.06, -0.15),
	JointSpine = A(0.02),
	JointNeck = A(-0.3),
	JointHead = A(-0.15),
	JointJaw = I,
	JointEarL = A(0.3),
	JointEarR = A(0.3),
	JointCrest = A(-0.25),
	JointLegFL = A(0.16), JointElbowFL = A(-0.15),
	JointLegFR = A(0.16), JointElbowFR = A(-0.15),
	JointLegBL = A(-0.29), JointKneeBL = A(0.35),
	JointLegBR = A(-0.29), JointKneeBR = A(0.35),
	JointTail = A(-0.3), JointTail2 = A(-0.1),
}

-- Moon Pounce
local POUNCE_CROUCH: Pose = {
	JointRoot = R(-0.5, -0.1),
	JointSpine = A(0.15),
	JointNeck = A(-0.3),
	JointHead = A(0.25),
	JointJaw = A(-0.1),
	JointEarL = A(0.7),
	JointEarR = A(0.7),
	JointCrest = A(-0.3),
	JointLegFL = A(-0.35), JointElbowFL = A(0.6),
	JointLegFR = A(-0.35), JointElbowFR = A(0.6),
	JointLegBL = A(-0.3), JointKneeBL = A(0.45),
	JointLegBR = A(-0.3), JointKneeBR = A(0.45),
	-- straight back and stiff: the upturned tip flattened out
	JointTail = A(-0.05), JointTail3 = A(0.45),
}
local POUNCE_COIL = with(POUNCE_CROUCH, {
	JointRoot = R(-0.55, -0.12, 0.15),
	JointLegBL = A(-0.45), JointKneeBL = A(0.6),
	JointLegBR = A(-0.45), JointKneeBR = A(0.6),
	JointEarL = A(0.75), JointEarR = A(0.75),
	JointCrest = A(-0.32),
})
local POUNCE_LAUNCH: Pose = {
	JointRoot = R(0.2, 0.12),
	JointSpine = A(-0.05),
	JointNeck = A(-0.1),
	JointHead = A(0.1),
	JointJaw = A(-0.4),
	JointEarL = A(0.75), JointEarR = A(0.75),
	JointCrest = A(-0.3),
	JointLegFL = A(1.0), JointElbowFL = A(0.15), JointWristFL = A(-0.2),
	JointLegFR = A(0.95), JointElbowFR = A(0.15), JointWristFR = A(-0.2),
	JointLegBL = A(-0.9), JointKneeBL = A(-0.25), JointHockBL = A(-0.35),
	JointLegBR = A(-0.85), JointKneeBR = A(-0.25), JointHockBR = A(-0.35),
	JointTail = A(0.05), JointTail3 = A(0.45),
}
local POUNCE_STRETCH: Pose = {
	JointRoot = R(0.3, 0.08),
	JointSpine = A(-0.12),
	JointNeck = A(-0.15),
	JointHead = A(0.1),
	JointJaw = A(-0.6),
	JointEarL = A(0.75), JointEarR = A(0.75),
	JointCrest = A(-0.3),
	JointLegFL = A(1.05, 0, -0.08), JointElbowFL = A(0.2), JointWristFL = A(-0.3),
	JointLegFR = A(1.0, 0, 0.08), JointElbowFR = A(0.2), JointWristFR = A(-0.3),
	JointLegBL = A(-1.0), JointKneeBL = A(-0.3), JointHockBL = A(-0.4),
	JointLegBR = A(-0.95), JointKneeBR = A(-0.3), JointHockBR = A(-0.4),
	JointTail = A(0.1), JointTail2 = A(-0.05), JointTail3 = A(0.5),
}
local POUNCE_REACH = with(POUNCE_STRETCH, {
	JointRoot = R(0.2, 0),
	JointLegFL = A(0.95, 0, -0.06), JointLegFR = A(0.9, 0, 0.06),
	JointLegBL = A(-0.8), JointLegBR = A(-0.75),
})
local POUNCE_SHUT = with(POUNCE_STRETCH, {
	JointRoot = R(0.1, -0.03),
	JointJaw = I,
	JointLegFL = A(0.8), JointElbowFL = A(0.1), JointWristFL = A(-0.1),
	JointLegFR = A(0.75), JointElbowFR = A(0.1), JointWristFR = A(-0.1),
	JointLegBL = A(-0.6), JointKneeBL = A(-0.1), JointHockBL = A(-0.2),
	JointLegBR = A(-0.55), JointKneeBR = A(-0.1), JointHockBR = A(-0.2),
})
local POUNCE_SKID: Pose = {
	JointRoot = R(0, 0.12, 0.1),
	JointSpine = A(0.05),
	JointNeck = A(0.1),
	JointHead = A(0.05),
	JointJaw = A(-0.15),
	JointEarL = A(0.35), JointEarR = A(0.35),
	JointCrest = A(0.05),
	JointLegFL = A(0.4), JointElbowFL = A(-0.1),
	JointLegFR = A(0.4), JointElbowFR = A(-0.1),
	JointLegBL = A(0.5), JointKneeBL = A(0.5),
	JointLegBR = A(0.5), JointKneeBR = A(0.5),
	JointTail = A(0.3), JointTail2 = A(0.15),
}
-- spent: head low, ears drooped back, crest flat, tail low. Reads as an opening.
local TIRED: Pose = {
	JointRoot = R(-0.05, -0.04),
	JointSpine = A(0.04),
	JointNeck = A(-0.3),
	JointHead = A(0.1),
	JointJaw = A(-0.2),
	JointEarL = A(0.45, 0, 0.15), JointEarR = A(0.45, 0, -0.15),
	JointCrest = A(0.1),
	JointLegFL = A(0.05), JointElbowFL = A(-0.05),
	JointLegFR = A(0.05), JointElbowFR = A(-0.05),
	JointLegBL = A(-0.05), JointKneeBL = A(0.1),
	JointLegBR = A(-0.05), JointKneeBR = A(0.1),
	JointTail = A(0.45), JointTail2 = A(0.2), JointTail3 = A(0.2),
}

-- Moonfall Leap
local LEAP_REAR: Pose = {
	JointRoot = R(0, 0.35),
	JointSpine = A(0.05),
	JointNeck = A(0.15),
	JointHead = A(0.25),
	JointEarL = A(0.15), JointEarR = A(0.15),
	JointCrest = A(-0.2),
	JointLegFL = A(0.6), JointElbowFL = A(-0.9), JointWristFL = A(-0.4),
	JointLegFR = A(0.55), JointElbowFR = A(-0.85), JointWristFR = A(-0.4),
	JointLegBL = A(0.2), JointKneeBL = A(0.4),
	JointLegBR = A(0.2), JointKneeBR = A(0.4),
	JointTail = A(0.1), JointTail2 = A(0.05),
}
local LEAP_CROUCH: Pose = {
	JointRoot = R(-0.6, -0.06, 0.1),
	JointSpine = A(0.12),
	JointNeck = A(-0.25),
	JointHead = A(0.3),
	JointJaw = A(-0.15),
	JointEarL = A(0.7), JointEarR = A(0.7),
	JointCrest = A(-0.35),
	JointLegFL = A(-0.4), JointElbowFL = A(0.7),
	JointLegFR = A(-0.4), JointElbowFR = A(0.7),
	JointLegBL = A(-0.45), JointKneeBL = A(0.7),
	JointLegBR = A(-0.45), JointKneeBR = A(0.7),
	JointTail = A(0.45), JointTail2 = A(0.2), JointTail3 = A(0.1),
}
local LEAP_COILED = with(LEAP_CROUCH, { JointRoot = R(-0.62, -0.06, 0.12) })
-- push-off: the hind legs drive (still on the ground), the front already lifting
local LEAP_PUSH: Pose = {
	JointRoot = R(0.3, 0.25),
	JointSpine = A(0.05),
	JointNeck = A(0),
	JointHead = A(0.1),
	JointJaw = A(-0.2),
	JointEarL = A(0.7), JointEarR = A(0.7),
	JointCrest = A(-0.35),
	JointLegFL = A(0.7), JointElbowFL = A(-0.6), JointWristFL = A(-0.3),
	JointLegFR = A(0.65), JointElbowFR = A(-0.6), JointWristFR = A(-0.3),
	JointLegBL = A(-0.55), JointKneeBL = A(0.2),
	JointLegBR = A(-0.55), JointKneeBR = A(0.2),
	JointTail = A(0.2), JointTail2 = A(0.1),
}
local LEAP_UP: Pose = {
	JointRoot = R(0.2, 0.3),
	JointSpine = A(0.08),
	JointNeck = A(0.05),
	JointJaw = A(-0.3),
	JointEarL = A(0.65), JointEarR = A(0.65),
	JointCrest = A(-0.3),
	JointLegFL = A(1.0), JointElbowFL = A(-0.2), JointWristFL = A(-0.2),
	JointLegFR = A(0.95), JointElbowFR = A(-0.2), JointWristFR = A(-0.2),
	JointLegBL = A(-1.0), JointKneeBL = A(-0.3), JointHockBL = A(-0.4),
	JointLegBR = A(-0.95), JointKneeBR = A(-0.3), JointHockBR = A(-0.4),
	JointTail = A(0.15), JointTail2 = A(0.05), JointTail3 = A(0.4),
}
local LEAP_DOWN: Pose = {
	JointRoot = R(0.9, -0.3),
	JointSpine = A(-0.05),
	JointNeck = A(-0.1),
	JointJaw = A(-0.55),
	JointEarL = A(0.6), JointEarR = A(0.6),
	JointCrest = A(-0.35),
	-- forelegs reach down and forward, paws tipped up: claws out
	JointLegFL = A(0.75, 0, -0.08), JointElbowFL = A(0.1), JointWristFL = A(0.35),
	JointLegFR = A(0.75, 0, 0.08), JointElbowFR = A(0.1), JointWristFR = A(0.35),
	JointLegBL = A(0), JointKneeBL = A(0.4), JointHockBL = A(-0.2),
	JointLegBR = A(0), JointKneeBR = A(0.4), JointHockBR = A(-0.2),
	JointTail = A(-0.3), JointTail2 = A(-0.1), JointTail3 = A(0.2),
}
local LAND_SQUASH: Pose = {
	JointRoot = R(-0.4, -0.05),
	JointSpine = A(0.08),
	JointNeck = A(-0.35),
	JointHead = A(0.25),
	JointJaw = A(-0.3),
	JointEarL = A(0.7), JointEarR = A(0.7),
	JointCrest = A(-0.25),
	JointLegFL = A(-0.2, 0, -0.25), JointElbowFL = A(0.5),
	JointLegFR = A(-0.2, 0, 0.25), JointElbowFR = A(0.5),
	JointLegBL = A(-0.2, 0, -0.2), JointKneeBL = A(0.5),
	JointLegBR = A(-0.2, 0, 0.2), JointKneeBR = A(0.5),
	JointTail = A(0.3), JointTail2 = A(0.1),
}
local LAND_HOLD = with(LAND_SQUASH, { JointRoot = R(-0.35, -0.04) })
local LAND_RISE: Pose = {
	JointRoot = R(-0.15, -0.02),
	JointSpine = A(-0.03),
	JointNeck = A(-0.2),
	JointHead = A(0.15),
	JointJaw = A(-0.15),
	JointEarL = A(0.3), JointEarR = A(0.3),
	JointLegFL = A(0.12, 0, -0.12), JointElbowFL = A(-0.25),
	JointLegFR = A(0.12, 0, 0.12), JointElbowFR = A(-0.25),
	JointLegBL = A(-0.1, 0, -0.1), JointKneeBL = A(0.25),
	JointLegBR = A(-0.1, 0, 0.1), JointKneeBR = A(0.25),
	JointTail = A(0.2), JointTail2 = A(0.05),
}
local LAND_SETTLE: Pose = {
	JointRoot = R(-0.03),
	JointNeck = A(-0.05),
	JointHead = A(0.05),
	JointEarL = A(0.15), JointEarR = A(0.15),
	JointCrest = A(0.05),
	JointElbowFL = A(-0.05), JointElbowFR = A(-0.05),
	JointKneeBL = A(0.05), JointKneeBR = A(0.05),
	JointTail = A(0.1),
}

-- Hop
local HOP_PUSH: Pose = {
	JointRoot = R(-0.05, 0.05),
	JointNeck = A(-0.05),
	JointLegFL = A(-0.3), JointWristFL = A(0.35),
	JointLegFR = A(-0.3), JointWristFR = A(0.35),
	JointLegBL = A(-0.35), JointKneeBL = A(-0.1), JointHockBL = A(0.35),
	JointLegBR = A(-0.35), JointKneeBR = A(-0.1), JointHockBR = A(0.35),
	JointTail = A(-0.1),
}
local HOP_TUCK: Pose = {
	JointLegFL = A(0.7), JointElbowFL = A(-1.2), JointWristFL = A(0.2),
	JointLegFR = A(0.7), JointElbowFR = A(-1.2), JointWristFR = A(0.2),
	JointLegBL = A(0.35), JointKneeBL = A(0.8), JointHockBL = A(-0.5),
	JointLegBR = A(0.35), JointKneeBR = A(0.8), JointHockBR = A(-0.5),
	JointTail = A(0.1),
}
local HOP_REACH: Pose = {
	JointLegFL = A(0.15), JointElbowFL = A(-0.2),
	JointLegFR = A(0.15), JointElbowFR = A(-0.2),
	JointLegBL = A(-0.05), JointKneeBL = A(0.2), JointHockBL = A(-0.1),
	JointLegBR = A(-0.05), JointKneeBR = A(0.2), JointHockBR = A(-0.1),
}

-- Stagger and death: head thrown up, yelp, legs splayed and braced
local HIT: Pose = {
	JointRoot = R(0, 0.04, 0.15),
	JointSpine = A(0.08),
	JointNeck = A(0.2),
	JointHead = A(0.25),
	JointJaw = A(-0.4),
	JointEarL = A(0.75), JointEarR = A(0.75),
	JointCrest = A(0.15),
	JointLegFL = A(0.45), JointElbowFL = A(-0.1),
	JointLegFR = A(0.45), JointElbowFR = A(-0.1),
	JointLegBL = A(-0.35), JointKneeBL = A(0.2),
	JointLegBR = A(-0.35), JointKneeBR = A(0.2),
	JointTail = A(0.45), JointTail2 = A(0.2),
}
-- on its left side (the killer on its right): rolled +Z about the hips, dropped so the
-- flank rests on the ground. Ground-ward in the body's frame is its left (-X): the head
-- and the upper (right) legs flop that way (+Y on the neck, -Z on the right legs), the
-- tail to the left is -Y.
local DEAD_ROLL = 1.4
local function dead(roll: number): Pose
	return {
		JointRoot = CFrame.new(-0.55, -0.95, 0) * A(0, 0, roll),
		JointSpine = A(0.05, 0.05),
		JointNeck = A(-0.15, 0.3),
		JointHead = A(-0.1, 0.15),
		JointJaw = A(-0.3),
		JointEarL = A(0.4), JointEarR = A(0.4, 0, -0.2),
		JointCrest = A(0.2),
		JointLegFL = A(0.35, 0, 0.1), JointElbowFL = A(-0.35), JointWristFL = A(-0.3),
		JointLegFR = A(-0.05, 0, -0.25), JointElbowFR = A(-0.25), JointWristFR = A(-0.3),
		JointLegBL = A(-0.25, 0, 0.1), JointKneeBL = A(0.35), JointHockBL = A(-0.3),
		JointLegBR = A(-0.15, 0, -0.2), JointKneeBR = A(0.25), JointHockBR = A(-0.3),
		JointTail = A(0.2, -0.3), JointTail2 = A(0.1, -0.2), JointTail3 = A(0.3, -0.1),
	}
end

------------------------------------------------------------------------------------
-- Moves

local moves: { [string]: { [string]: Phase } } = {}

-- The pack call (a summon's windup). 0-0.25 sits back on its haunches (the front stays
-- planted, so the root drops and the hind knees fold), throat up, jaw wide; holds to
-- 0.65; stands by 0.8.
local HOWL_SIT: Pose = {
	JointRoot = R(0, 0.15, 0.25),
	JointSpine = A(0.05),
	JointNeck = A(0.35),
	JointHead = A(0.3),
	JointJaw = A(-0.6),
	JointEarL = A(0.5), JointEarR = A(0.5),
	JointCrest = A(-0.15),
	JointLegFL = A(0.05), JointElbowFL = A(-0.05),
	JointLegFR = A(0.05), JointElbowFR = A(-0.05),
	JointLegBL = A(0.5), JointKneeBL = A(0.6),
	JointLegBR = A(0.5), JointKneeBR = A(0.6),
	JointTail = A(0.35), JointTail2 = A(0.15),
}
moves.Howl = {
	windup = {
		duration = 0.8,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.31, pose = HOWL_SIT, ease = "out", plant = ALL, reach = paws(0, 0.45) },
			{ t = 0.81, pose = with(HOWL_SIT, { JointNeck = A(0.38), JointHead = A(0.32) }), plant = ALL, reach = paws(0, 0.45) },
			{ t = 1, pose = ALERT, ease = "inOut", plant = ALL },
		},
		-- the howl's waver in the throat
		overlay = function(u, secs)
			local e = bump(u, 0.25, 0.85)
			return { JointHead = A(0.03 * math.sin(secs * TAU * 6) * e), JointJaw = A(-0.05 * math.sin(secs * TAU * 3) * e) }
		end,
	},
}

moves.FangSnap = {
	-- 0-0.3 rears back, jaw wide by 0.35, forelegs braced, crest up. Telegraph, tell
	-- flare and sound start at u = 0.
	windup = {
		duration = 0.45,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.667, pose = SNAP_REAR, ease = "out", plant = ALL, reach = BRACED },
			{ t = 0.778, pose = SNAP_WIDE, ease = "out", plant = ALL, reach = BRACED },
			{ t = 1, pose = SNAP_WIDE, plant = ALL, reach = BRACED },
		},
	},
	-- the snap: forward and down, jaw shut by 0.05 s
	active = {
		duration = 0.1,
		keys = {
			{ t = 0, pose = SNAP_WIDE, plant = ALL, reach = BRACED },
			{ t = 0.5, pose = SNAP_BITE, ease = "out", plant = ALL, reach = BRACED },
			{ t = 1, pose = SNAP_BITE, plant = ALL, reach = BRACED },
		},
	},
	-- worries the bite: head shake +-0.25 yaw, 2 cycles, settled by 0.4 s
	recover = {
		duration = 0.5,
		keys = {
			{ t = 0, pose = SNAP_BITE, plant = ALL, reach = BRACED },
			{ t = 0.8, pose = ALERT, ease = "inOut", plant = ALL },
			{ t = 1, pose = ALERT, plant = ALL },
		},
		overlay = function(_, secs)
			if secs >= 0.4 then
				return {}
			end
			local s = math.sin(TAU * 2 * secs / 0.4) * (1 - secs / 0.4) ^ 0.5
			return { JointNeck = A(0, 0.1 * s), JointHead = A(0, 0.15 * s, -0.1 * s) }
		end,
	},
}

moves.MoonPounce = {
	-- 0-0.15 drops into the crouch (ears pinned, crest up, head low, tail stiff),
	-- 0.15-0.6 coils the hind legs with a hip wiggle, 0.6-0.7 dead still.
	windup = {
		duration = 0.7,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.214, pose = POUNCE_CROUCH, ease = "out", plant = ALL, reach = CROUCHED },
			{ t = 0.857, pose = POUNCE_COIL, ease = "inOut", plant = ALL, reach = COILED },
			{ t = 1, pose = POUNCE_COIL, plant = ALL, reach = COILED },
		},
		overlay = function(_, secs)
			local e = smooth(0.15, 0.22, secs) * (1 - smooth(0.52, 0.6, secs))
			local w = math.sin(TAU * 8 * secs) * e
			-- the hips swing, the chest holds still on the target
			return { JointRoot = A(0, 0.05 * w), JointSpine = A(0, -0.05 * w), JointTail = A(0, 0.08 * w) }
		end,
	},
	-- full stretch, jaw open by 0.15 s, shut at 0.3
	active = {
		duration = 0.3,
		keys = {
			{ t = 0, pose = POUNCE_COIL, plant = ALL, reach = COILED },
			{ t = 0.25, pose = POUNCE_LAUNCH, ease = "out" },
			{ t = 0.5, pose = POUNCE_STRETCH, ease = "out" },
			{ t = 0.85, pose = POUNCE_REACH },
			{ t = 1, pose = POUNCE_SHUT, ease = "in" },
		},
	},
	-- skid with the forelegs braced, a head shake, then stands spent and panting
	recover = {
		duration = 0.9,
		keys = {
			{ t = 0, pose = POUNCE_SHUT },
			{ t = 0.111, pose = POUNCE_SKID, ease = "out", plant = ALL, reach = SKIDDED },
			{ t = 0.333, pose = with(POUNCE_SKID, { JointRoot = R(0, 0.1, 0.15) }), plant = ALL, reach = SKIDDED },
			{ t = 0.667, pose = TIRED, ease = "inOut", plant = ALL },
			{ t = 1, pose = TIRED, plant = ALL },
		},
		overlay = function(_, secs)
			local shake = bump(secs, 0.3, 0.6)
			local s = math.sin(TAU * 8 * (secs - 0.3)) * shake
			local pant = smooth(0.55, 0.65, secs) * math.sin(TAU * 5 * secs)
			return {
				JointNeck = A(0, 0.1 * s, 0.12 * s),
				JointHead = A(0, 0.08 * s, 0.3 * s),
				JointEarL = A(0, 0, -0.25 * s),
				JointEarR = A(0, 0, -0.25 * s),
				JointJaw = A(0.05 * pant),
				JointSpine = A(0.02 * pant),
			}
		end,
	},
}

moves.MoonfallLeap = {
	-- 0-0.4 rears up with a yip, 0.4-1.0 drops into the deepest crouch (crest fully
	-- up, tail low) and trembles
	windup = {
		duration = 1.0,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.4, pose = LEAP_REAR, ease = "inOut", plant = HIND, reach = paws(0, 0.3) },
			{ t = 0.6, pose = LEAP_CROUCH, ease = "inOut", plant = ALL, reach = COILED },
			{ t = 1, pose = LEAP_COILED, plant = ALL, reach = COILED },
		},
		overlay = function(u, secs)
			local yip = bump(secs, 0.12, 0.45)
			local tremble = smooth(0.6, 0.7, u) * math.sin(TAU * 11 * secs)
			return { JointJaw = A(-0.5 * yip), JointSpine = A(0, 0.015 * tremble), JointTail3 = A(0, 0.1 * tremble) }
		end,
	},
	-- 0-0.2 s stretches upward, then reaches down and forward, claws out. The client
	-- arcs the body; this only poses it.
	active = {
		duration = 0.45,
		air = true,
		keys = {
			{ t = 0, pose = LEAP_COILED, plant = ALL, reach = COILED },
			{ t = 0.15, pose = LEAP_PUSH, ease = "out", plant = HIND, reach = COILED },
			{ t = 0.444, pose = LEAP_UP, ease = "out" },
			{ t = 1, pose = LEAP_DOWN, ease = "inOut" },
		},
	},
	-- lands splayed and squashed, holds to 0.3, shakes it off by 0.7, stands by 1.1
	recover = {
		duration = 1.1,
		keys = {
			{ t = 0, pose = LEAP_DOWN },
			{ t = 0.08, pose = LAND_SQUASH, ease = "out", plant = ALL, reach = SPLAYED },
			{ t = 0.27, pose = LAND_HOLD, ease = "out", plant = ALL, reach = SPLAYED },
			{ t = 0.45, pose = LAND_RISE, ease = "inOut", plant = ALL, reach = paws(-0.15, 0, 0.15, 0.12) },
			{ t = 0.64, pose = LAND_SETTLE, ease = "inOut", plant = ALL },
			{ t = 1, pose = ALERT, ease = "inOut", plant = ALL },
		},
		overlay = function(_, secs)
			local e = bump(secs, 0.3, 0.7)
			local function s(lag: number)
				return math.sin(TAU * 6 * (secs - 0.3) - lag) * e
			end
			return {
				JointRoot = A(0, 0, -0.04 * s(0)),
				JointSpine = A(0, 0, 0.12 * s(0)),
				JointNeck = A(0, 0, 0.15 * s(0.5)),
				JointHead = A(0, 0, 0.2 * s(1)),
				JointEarL = A(0, 0, -0.2 * s(1.4)),
				JointEarR = A(0, 0, -0.2 * s(1.4)),
				JointTail = A(0, 0.3 * s(1.5)),
				JointTail2 = A(0, 0.2 * s(2)),
			}
		end,
	},
}

-- a short reposition jump: push, tuck, reach, land. The head holds on the target.
moves.Hop = {
	active = {
		duration = 0.25,
		air = true,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.15, pose = HOP_PUSH, ease = "out" },
			{ t = 0.5, pose = HOP_TUCK, ease = "inOut" },
			{ t = 0.85, pose = HOP_REACH, ease = "inOut" },
			{ t = 1, pose = STAND, ease = "out", plant = ALL },
		},
	},
}

-- snaps in within 0.06 s (u 0.2 of 0.28 s), eases out. The head turns away from the
-- hit by input.side.
moves.Stagger = {
	active = {
		duration = 0.28,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = HIT, ease = "out", plant = ALL, reach = THROWN },
			{ t = 0.45, pose = with(HIT, { JointJaw = A(-0.3) }), plant = ALL, reach = THROWN },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, _, input)
			local side = math.clamp(input.side or 0, -1, 1)
			local e = if u < 0.2 then EASE.out(u / 0.2) else 1 - EASE.inOut((u - 0.2) / 0.8)
			return {
				JointNeck = A(0, 0.15 * side * e),
				JointHead = A(0, 0.2 * side * e, 0.1 * side * e),
				JointSpine = A(0, 0, 0.05 * side * e),
			}
		end,
	},
}

-- 0-0.15 the stagger, 0.15-0.6 rolls onto its side away from the killer, legs limp,
-- head down, jaw slack. Holds at u = 1 until the fade.
moves.Death = {
	active = {
		duration = 0.6,
		mirror = true,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.25, pose = HIT, ease = "out", plant = ALL, reach = THROWN },
			{ t = 0.6, pose = with(dead(DEAD_ROLL * 0.45), { JointRoot = CFrame.new(-0.2, -0.2, 0) * A(0, 0, DEAD_ROLL * 0.45) }), ease = "in" },
			{ t = 0.88, pose = dead(DEAD_ROLL + 0.08), ease = "in" },
			{ t = 1, pose = dead(DEAD_ROLL), ease = "out" },
		},
	},
}

-- Skids: the pounce or leap overshot (the server's `<attack>Skid` recover, timed by the
-- attack's recover). Authored for the target on the wolf's RIGHT; mirror plays the left.
-- The head snaps round at once and leads (the overlay turns the chest, neck and head
-- toward the live input.targetYaw, so they unwind as the server's yaw catches up), the
-- forepaws brace far ahead with the chest reared back against the slide, the hind end
-- swings out to the outside of the turn and scrabbles (one hind paw, the other, then the
-- inside forepaw steps round), and it squares up, alert. No pose turns the root.
local SKID_BRAKE: Pose = {
	JointRoot = R(-0.28, 0.1, 0.1, -0.03, -0.06),
	JointSpine = A(0.04),
	JointNeck = A(0.02),
	JointHead = A(0.15),
	JointJaw = A(-0.35),
	JointEarL = A(0.6), JointEarR = A(0.6),
	JointCrest = A(-0.25),
	JointTail = A(0.1, -0.45), JointTail2 = A(0.05, -0.3), JointTail3 = A(0.25, -0.2),
}
local SKID_SCRAB = with(SKID_BRAKE, {
	JointRoot = R(-0.24, 0.06, 0.06, -0.02, -0.07),
	JointLegBL = A(-0.35, 0, -0.1), JointKneeBL = A(-1.0), JointHockBL = A(0.5),
	JointTail = A(0.1, -0.35), JointTail2 = A(0.05, -0.35),
})
local SKID_SCRAB2 = with(SKID_SCRAB, {
	JointRoot = R(-0.2, 0.04, 0.04, -0.01, -0.05),
	JointLegBR = A(-0.35, 0, -0.1), JointKneeBR = A(-1.0), JointHockBR = A(0.5),
	JointTail = A(0.1, -0.2), JointTail2 = A(0.08, -0.25),
})
local SKID_STEP = with(TIRED, {
	JointRoot = R(-0.14, 0.02, 0, 0, -0.03), JointHead = A(0.12), JointJaw = A(-0.25),
	JointEarL = A(0.25), JointEarR = A(0.25),
	JointLegFR = A(0.6, 0, 0.2), JointElbowFR = A(-1.1), JointWristFR = A(0.4),
	JointTail = A(0.25, -0.1),
})
local SKID_BRAKED = { FL = V(-0.05, 0, -0.5), FR = V(0.12, 0, -0.45), BL = V(-0.38, 0, 0.45), BR = V(-0.18, 0, 0.5) }
local SKID_SCRABBED = { FL = V(-0.04, 0, -0.42), FR = V(0.1, 0, -0.4), BL = V(-0.2, 0, 0.3), BR = V(-0.24, 0, 0.36) }
local SKID_SQUARED = { FL = V(-0.04, 0, -0.3), FR = V(0.12, 0, -0.25), BL = V(-0.12, 0, 0.22), BR = V(-0.1, 0, 0.2) }

-- the turn lead in the authored (target on the right) frame: negative yaw turns right
local function skidLead(u: number, _secs: number, input: Input): Pose
	local e = smooth(0, 0.14, u) * (1 - smooth(0.7, 1, u))
	local yaw = input.targetYaw or -1.3
	local f = -math.min(math.abs(yaw), 1.4) / 1.4 * e
	return {
		JointSpine = A(0, 0.2 * f), JointNeck = A(0, 0.35 * f, 0.04 * f), JointHead = A(0, 0.3 * f, 0.06 * f),
		JointTail = A(0, 0.2 * f), JointTail2 = A(0, 0.15 * f),
	}
end

local function skid(entry: { Key }, brakeAt: number): Phase
	local keys = table.clone(entry)
	local s = (1 - brakeAt) / 0.88 -- the skid's own keys fill [brakeAt, 1]
	local function at(x: number): number
		return brakeAt + (x - 0.12) * s
	end
	for _, k in {
		{ t = brakeAt, pose = SKID_BRAKE, ease = "out", plant = ALL, reach = SKID_BRAKED },
		{ t = at(0.3), pose = SKID_SCRAB, ease = "inOut", plant = { "FL", "FR", "BR" }, reach = SKID_BRAKED },
		{ t = at(0.44), pose = SKID_SCRAB2, ease = "inOut", plant = { "FL", "FR", "BL" }, reach = SKID_SCRABBED },
		{ t = at(0.6), pose = SKID_STEP, ease = "inOut", plant = { "FL", "BL", "BR" }, reach = SKID_SCRABBED },
		{ t = at(0.76), pose = TIRED, ease = "inOut", plant = ALL, reach = SKID_SQUARED },
		{ t = 1, pose = ALERT, ease = "inOut", plant = ALL },
	} :: { Key } do
		table.insert(keys, k)
	end
	return { duration = 1.0, mirror = true, overlay = skidLead, keys = keys }
end

-- PounceSkid: out of the pounce's airborne stretch (recover 0.9)
moves.PounceSkid = { recover = skid({ { t = 0, pose = POUNCE_SHUT } }, 0.1) }
moves.PounceSkid.recover.duration = 0.9
-- LeapSkid: lands squashed first, then skids round (recover 1.1)
moves.LeapSkid = { recover = skid({
	{ t = 0, pose = LEAP_DOWN },
	{ t = 0.07, pose = LAND_SQUASH, ease = "out", plant = ALL, reach = SPLAYED },
}, 0.2) }
moves.LeapSkid.recover.duration = 1.1

-- moves that read input.targetYaw (EnemyAnimator passes it, and the side, for these)
Wolf.LEAD = { PounceSkid = true, LeapSkid = true }

Wolf.moves = moves

function Wolf.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = moves[move]
	local p = m and m[phase]
	assert(p, ("Wolf.sample: no %s.%s"):format(move, phase))
	local pose, plant, reach = samplePhase(p, u, input or {})
	plantLegs(pose, plant, p.air, reach)
	return pose
end

-- Plants the listed legs (default all four) of a hand-made pose onto the ground, as
-- the keyed moves do. For overlay tables and authoring tools.
function Wolf.plant(pose: Pose, legs: { string }?, reach: { [string]: Vector3 }?): Pose
	plantLegs(pose, plantOf(legs or ALL), false, reach)
	return pose
end

------------------------------------------------------------------------------------
-- Loops

local LEG = 2.3 -- shoulder or hip to the ground, studs

local function walkAmp(speed: number): number
	return math.clamp(0.12 + 0.04 * speed, 0.15, 0.45)
end
local function circleAmp(speed: number): number
	return math.clamp(0.06 + 0.018 * speed, 0.08, 0.2)
end

-- One leg's swing for a gait: its pitch, lift (0 in stance, up to 1 mid swing) and
-- plant weight. Swing is while the angle rises (the paw moving forward).
local function legCycle(phase: number, amp: number): (number, number, number)
	local a = amp * math.sin(phase)
	local lift = math.max(0, math.cos(phase))
	return a, lift, 1 - smooth(0, 0.25, lift)
end

type Step = { stance: number, clear: number, flex: number }

-- Sets a gait leg's upper joint; every gait leg is then solved: the stance legs onto
-- the ground (they also set the root's drop), the swing legs to clear studs over it
-- with the paw curled by flex.
local function setLeg(pose: Pose, steps: { [string]: Step }, tag: string, a: number, roll: number, lift: number, w: number, clear: number)
	local leg = LEGS[tag]
	pose[leg.upper] = A(a, 0, roll)
	pose[leg.mid] = A(leg.fold * 0.3 * lift) -- swinging, bend the natural way
	steps[tag] = { stance = w, clear = clear * lift, flex = (if leg.front then -1.0 else -0.6) * clear * lift }
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
		pose.JointRoot = CFrame.new(0, -drop, 0) * (pose.JointRoot or I)
	end
	for tag, st in steps do
		solveLeg(pose, LEGS[tag], 1, st.clear, st.flex)
	end
end

local loops = {}

local function hash(n: number, seed: number): number
	local x = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- breathing, a slow look around, an ear flick every 3-6 s, a lazy wag, and now and
-- then a 1 s sniff at the ground
function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 3.2)
	-- ear flicks: one per 4.5 s slot, somewhere in its first 1.5 s
	local slot = math.floor(clock / 4.5)
	local at = slot * 4.5 + hash(slot, seed) * 1.5
	local flick = bump(clock, at, at + 0.3)
	local which = hash(slot + 0.5, seed)
	local fl = if which < 0.6 then flick else 0
	local fr = if which > 0.4 then flick else 0
	-- sniff: 45% of 11 s slots
	local sslot = math.floor(clock / 11)
	local sniff = 0
	if hash(sslot + 0.25, seed) < 0.45 then
		local st = sslot * 11 + 1 + hash(sslot + 0.75, seed) * 8
		sniff = smooth(st, st + 0.25, clock) * (1 - smooth(st + 0.75, st + 1, clock))
	end
	local look = math.sin(clock * 0.37 + seed) * 0.12 * (1 - sniff)
	local wag = clock * 2.4
	local pose: Pose = {
		JointRoot = R(0.015 * breath),
		JointSpine = A(0.02 * breath),
		JointNeck = A(-0.04 + 0.01 * breath - 0.3 * sniff, look * 0.6),
		JointHead = A(0.04 + 0.05 * sniff + 0.03 * math.sin(clock * 25) * sniff, look * 0.4),
		JointEarL = A(-0.05 + 0.55 * fl, 0, 0.2 * fl),
		JointEarR = A(-0.05 + 0.55 * fr, 0, -0.2 * fr),
		JointCrest = A(0.05),
		JointTail = A(0.15, 0.22 * math.sin(wag)),
		JointTail2 = A(0.05, 0.15 * math.sin(wag - 0.7)),
		JointTail3 = A(0, 0.15 * math.sin(wag - 1.4)),
	}
	local plant = plantOf(ALL)
	plantLegs(pose, plant)
	return pose
end

-- trot: diagonal pairs (FL+BR, FR+BL), head bob, tail mid
function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local amp = walkAmp(speed)
	local tuck = math.clamp(amp / 0.4, 0.5, 1.1)
	local pose: Pose = {}
	local steps = {}
	for tag, off in { FL = 0, BR = 0, FR = math.pi, BL = math.pi } do
		local a, lift, w = legCycle(phase + off, amp)
		setLeg(pose, steps, tag, a, 0, lift, w, 0.35 * tuck)
	end
	local bob = math.sin(phase * 2 + 0.6)
	pose.JointRoot = R(0, 0.02 * math.sin(phase * 2), 0, 0, 0.03 * math.sin(phase))
	pose.JointSpine = A(0, 0.04 * math.sin(phase))
	pose.JointNeck = A(-0.08 + 0.04 * bob)
	pose.JointHead = A(0.06 - 0.03 * bob)
	pose.JointEarL = A(0.05 + 0.05 * bob)
	pose.JointEarR = A(0.05 + 0.05 * bob)
	pose.JointCrest = A(0.05)
	pose.JointTail = A(0.1, 0.12 * math.sin(phase - 0.5))
	pose.JointTail2 = A(0.05, 0.1 * math.sin(phase - 1.1))
	pose.JointTail3 = A(0, 0.1 * math.sin(phase - 1.6))
	stepLegs(pose, steps)
	return pose
end

-- rotary gallop: FL, FR 0.1 later, BR half a cycle behind FL, BL 0.1 after it. The
-- spine flexes +-0.15 (arched gathered, flat stretched), ears back, tail streaming.
function loops.run(phase: number, speed: number, _input: Input?): Pose
	local g = math.clamp(speed / 18, 0.6, 1.15)
	local ampF, ampH = 0.65 * g, 0.6 * g
	local pose: Pose = {}
	local steps = {}
	local fore, hind = 0, 0
	for tag, cyc in { FL = 0, FR = 0.1, BR = 0.5, BL = 0.6 } do
		local ph = phase - cyc * TAU
		local front = tag == "FL" or tag == "FR"
		local amp = if front then ampF else ampH
		local a, lift, w = legCycle(ph, amp)
		if not front and a > 0 then
			a *= 0.65 -- the hind legs reach forward less than they drive back: clear of the belly
		end
		-- planted only around mid-stance: a gallop's contact is short
		w *= math.clamp((0.45 - math.abs(math.sin(ph))) * 4, 0, 1)
		-- the hind paws pass outside the fore paws when they reach under the chest
		local roll = if front then 0 else (if tag == "BL" then -0.22 else 0.22) * math.max(0, a / amp)
		setLeg(pose, steps, tag, a, roll, lift, w, if front then 0.55 else 0.3)
		if front then
			fore += a / 2
		else
			hind += a / 2
		end
	end
	-- s > 0 gathered (hind under, fore back), s < 0 stretched. The arch is 0.1 (the
	-- brief's 0.15 brings the chest down onto the reaching hind shins)
	local s = math.clamp((hind - fore) / (ampF + ampH) * 2, -1, 1)
	pose.JointRoot = R(0.1 * math.max(0, s), -0.06 * s)
	pose.JointSpine = A(-0.1 * math.max(0, s) + 0.15 * math.max(0, -s))
	pose.JointNeck = A(-0.15 + 0.08 * s)
	pose.JointHead = A(0.12 - 0.06 * s)
	pose.JointJaw = A(-0.15)
	pose.JointEarL = A(0.55)
	pose.JointEarR = A(0.55)
	pose.JointCrest = A(0.12)
	pose.JointTail = A(-0.05 + 0.08 * s, 0.05 * math.sin(phase))
	pose.JointTail2 = A(0.05, 0.06 * math.sin(phase - 0.8))
	pose.JointTail3 = A(0.45, 0.06 * math.sin(phase - 1.6))
	stepLegs(pose, steps)
	return pose
end

-- crab-trot sideways around the target: the legs step out to the side in diagonal
-- pairs, the body leans 0.08 into the motion, head low and turned to the target,
-- crest half up, a snarl
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local ty = (input and input.targetYaw) or 0
	local amp = circleAmp(speed)
	local pose: Pose = {}
	local steps = {}
	for tag, off in { FL = 0, BR = 0, FR = math.pi, BL = math.pi } do
		local ph = phase + off
		local _, lift, w = legCycle(ph, amp)
		-- +Z on a leg swings its paw to the wolf's right; swing toward the motion,
		-- around a stance a little wider than standing so the paws don't cross
		local out = if tag == "FL" or tag == "BL" then -0.06 else 0.06
		setLeg(pose, steps, tag, 0.08 * math.sin(ph), out - dir * amp * math.sin(ph), lift, w, 0.3)
	end
	local neckYaw = math.clamp(ty * 0.5, -0.35, 0.35)
	local headYaw = math.clamp(ty - neckYaw, -0.35, 0.35)
	pose.JointRoot = R(0, -0.03, 0, 0, 0.08 * dir)
	pose.JointSpine = A(0, 0, -0.03 * dir)
	pose.JointNeck = A(-0.2, neckYaw)
	pose.JointHead = A(0.2 + 0.02 * math.sin(phase * 2), headYaw)
	pose.JointJaw = A(-0.1)
	pose.JointEarL = A(0.25)
	pose.JointEarR = A(0.25)
	pose.JointCrest = A(-0.15)
	pose.JointTail = A(0.15, 0.1 * dir)
	pose.JointTail2 = A(0.1, 0.05 * math.sin(phase))
	pose.JointTail3 = A(0.1)
	stepLegs(pose, steps)
	return pose
end

Wolf.loops = loops

-- How fast to advance a loop's phase (radians per second) so the planted paws don't
-- skate. scale is the body's size (King 2.4): bigger strides, slower cycles.
function Wolf.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	if loop == "walk" then
		return TAU * speed / (4 * LEG * math.sin(walkAmp(speed))) / s
	elseif loop == "run" then
		return TAU * (1.4 + 0.055 * speed) / s
	elseif loop == "circle" then
		return TAU * math.min(speed / (4 * LEG * math.sin(circleAmp(speed))), 2.6) / s
	end
	return 1 -- idle: pass the clock in seconds as its phase
end

function Wolf.scaled(pose: Pose, scale: number): Pose
	local root = pose.JointRoot
	if root and scale ~= 1 then
		pose.JointRoot = root - root.Position + root.Position * scale
	end
	return pose
end

-- the designed phase lengths, seconds (Enemies.luau's windup/recover override them)
Wolf.durations = {}
for name, phases in moves do
	Wolf.durations[name] = {}
	for phase, p in phases do
		Wolf.durations[name][phase] = p.duration
	end
end

return Wolf
