--!strict
-- Procedural pose tables for the Frost Spider (Enemies.FrostSpider, 30 joints, scale 1; rig
-- table in art/enemies/beasts/RIGS.md "Frost Spider", notes in art/enemies/beasts/poses_frost_spider.md).
-- Same API as Wolf.luau (sample(move, phase, u, input?) -> Pose, loops, gaitRate, scaled, plant,
-- moves, durations, JOINTS); the legs are this module's own 8-leg solver (Quadruped.plant is
-- four-legged), the shared easing and helpers come from Quadruped.
--
-- FAMILIES registration (EnemyAnimator; Template "FrostSpider"):
--   FAMILIES.FrostSpider = {
--       poses = FrostSpider, scale = 1, runFrom = 9, keyedBlend = 0.08, deathSeconds = 1.3,
--       staggerSeconds = 0.35,
--       moves = { webShot = "WebShot", frostFang = "FrostFang", hop = "Hop", frostFangSkid = "FrostFangSkid" },
--   }
-- (Hop is the skitter back; frostFangSkid is optional: the skid after a missed lunge. A hop
-- plays its `active` for the real flight time: pack.hop.seconds / DashSeconds.)
--
-- RIG: faces -Z, left is -X, ground Y 0. JointRoot (pivot (0, 2.3, -0.5)) carries the body: a
-- translation in studs and a pitch (+ front up), yaw, roll. JointAbdomen: pitch NEGATIVE lifts the
-- tip (web aim, 0 to -0.7 holds the pedicel; +0.35 is the dip). JointFangL/R: pitch + folds back
-- (0..0.9), roll spreads (L negative, R positive = open), yaw spreads the tips apart too (L +).
-- JointPedipalpL/R: pitch, yaw. Legs: every one of the eight is a hip (JointLeg<L|R><1..4>), a knee
-- and a foot, solved by two-bone IK from where the ankle should be; the foot joint counter-rotates
-- so the sole stays level. So a pose key authors the body, abdomen, fangs and palps and WHERE THE
-- ANKLES GO; the legs follow:
--   plant  the planted legs (a list of tags L1..L4 R1..R4; ALL = every leg). A planted foot is held
--          at its rest spot plus `reach` in WORLD space (it stays on the ground as the body moves);
--   reach  { [tag] = Vector3 } studs from the rest ankle; the y is the lift of a planted foot;
--   free   a leg not in plant is placed by `reach` in BODY space (rearing legs, curled legs)
--   flex   { [tag] = radians } toes up (+) after levelling
-- The lowest foot point never sinks: a leg that would dip is planted where it is.
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt: the telegraph, tell flare and sound start
-- on the first frame, so every windup starts moving at u = 0):
--   WebShot    windup 0.9: 0-0.16 s a crouch (the abdomen dips, the legs coil); to 0.5 s the front
--                legs rise and the abdomen climbs to -0.7 with the hind legs braced; a held beat to
--                0.9 s, the abdomen quivering (this is where the Spinneret glows).
--              active 0.22: the abdomen thrusts down +0.32, the body lurches forward, then it springs
--                back (play it at the start of recover: AnimSeconds = the active, the rest of the
--                recover settles a damped abdomen bounce).
--              recover 0.7 (incl. the active's 0.22).
--   FrostFang  windup 0.7: 0-0.14 s a coil, to 0.5 s it rears onto the hind six... four legs
--                (pitch +0.55, the front four legs up and open, fangs spreading), a held beat to 0.7 s
--                at the peak, the fangs wide and the front legs quivering.
--              active 0.3 (the lunge, up to 10 studs): the body falls forward, the front legs rake
--                inward, the fangs hold open; at 0.8-0.95 they SNAP shut (the hit lands at the end).
--              recover 0.9: the bite held and worried (a fast head shake), then the legs let go and it
--                settles; FrostFangSkid recover: a braking slide, the front legs planted ahead, the
--                body pitched up, the abdomen swinging round.
--   Hop        active (the skitter back 10 studs; length = the flight time): the legs run a fast
--                backward gait (about 4.5 steps per second), the body low and pitched up a touch, the
--                fangs half open, the abdomen flicking.
--   Stagger    active 0.35: recoil, the front legs flung up, the fangs spread, input.side tilts it.
--   Death      active 1.2 then hold u = 1: the legs buckle out, the body sinks, the legs curl in over
--                the back, a last twitch.
-- LOOPS: idle (breath, leg-tip tapping, the front legs feeling the air, abdomen sway, palp twitches),
--   walk / run (a tetrapod gait: L1 R2 L3 R4 against R1 L2 R3 L4, feet planted, a body bob twice a
--   cycle, the abdomen counter-swinging), circle (the side scuttle; input.dir = +1 scuttles to the
--   beast's left, -X; the leading legs reach, the trailing legs draw in).
--
-- API (as Wolf.luau)
--   FrostSpider.sample(move, phase, u, input?) -> Pose
--   FrostSpider.loops.idle(clock, speed, input?) / walk(phase, speed) / run(phase, speed) / circle(phase, speed, input?)
--   FrostSpider.gaitRate(loop, speed, scale?), .scaled(pose, scale), .plant(pose, legs?, reach?)
--   FrostSpider.moves, .durations, .JOINTS

local Quadruped = require(script.Parent.Quadruped)

local FrostSpider = {}

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Reach = { [string]: Vector3 }

local TAU = Quadruped.TAU
local I = CFrame.identity
local V = Vector3.new
local A = Quadruped.A
local EASE, smooth, with, hash = Quadruped.EASE, Quadruped.smooth, Quadruped.with, Quadruped.hash

local LEGS = { "L1", "L2", "L3", "L4", "R1", "R2", "R3", "R4" }
local ALL = LEGS
local NONE: { string } = {}
local FRONT2 = { "L1", "R1" }
local REST6 = { "L3", "L4", "R3", "R4" }
local WALKERS6 = { "L2", "L3", "L4", "R2", "R3", "R4" }
local GROUP_A = { L1 = true, R2 = true, L3 = true, R4 = true }

FrostSpider.JOINTS = {
	"JointRoot", "JointAbdomen", "JointFangL", "JointFangR", "JointPedipalpL", "JointPedipalpR",
}
for _, tag in LEGS do
	table.insert(FrostSpider.JOINTS, "JointLeg" .. tag)
	table.insert(FrostSpider.JOINTS, "JointKnee" .. tag)
	table.insert(FrostSpider.JOINTS, "JointFoot" .. tag)
end

------------------------------------------------------------------------------------
-- Skeleton (ground at Y 0; from art/enemies/beasts/rig_frost_spider.luau)

local ROOT = V(0, 2.3, -0.5)
local HIPZ = { -1.9, -1.0, -0.1, 0.7 }
local LEAN = { -0.9, -0.35, 0.35, 1.0 }
local SOLE = 1.19 -- the foot's lowest point below its ankle pivot
local H0: Reach, K0: Reach, A0: Reach, SIDE: { [string]: number } = {}, {}, {}, {}
for _, tag in LEGS do
	local s = if string.sub(tag, 1, 1) == "L" then -1 else 1
	local n = tonumber(string.sub(tag, 2)) :: number
	SIDE[tag] = s
	H0[tag] = V(s * 1.3, 2.3, HIPZ[n])
	K0[tag] = V(s * 3.0, 3.5, HIPZ[n] + LEAN[n] * 0.9)
	A0[tag] = V(s * 4.3, 1.2, HIPZ[n] + LEAN[n] * 1.8)
end
FrostSpider.HIP, FrostSpider.KNEE, FrostSpider.ANKLE = H0, K0, A0

local function arc(a: Vector3, b: Vector3): CFrame
	local c = a:Cross(b)
	local m = c.Magnitude
	if m < 1e-6 then
		return I
	end
	return CFrame.fromAxisAngle(c / m, math.atan2(m, a:Dot(b)))
end

-- the body frame: rest-space coordinates of the body (model space + ROOT offset trick)
local function bodyFrame(pose: Pose): CFrame
	return CFrame.new(ROOT) * (pose.JointRoot or I)
end
local function toWorld(bf: CFrame, p: Vector3): Vector3
	return bf:PointToWorldSpace(p - ROOT)
end

-- forward kinematics of one leg in rest-space body coordinates
local function legPoints(pose: Pose, tag: string): (Vector3, Vector3, Vector3)
	local Th = (pose["JointLeg" .. tag] or I).Rotation
	local Tk = (pose["JointKnee" .. tag] or I).Rotation
	local h, k0, a0 = H0[tag], K0[tag], A0[tag]
	local k = h + Th * (k0 - h)
	local a = k + (Th * Tk) * (a0 - k0)
	return h, k, a
end
FrostSpider.legPoints = legPoints

-- places the ankle at target (rest-space body coordinates), level foot, blended in by w
local function solveLocal(pose: Pose, tag: string, target: Vector3, w: number, flex: number?)
	local h, k0, a0 = H0[tag], K0[tag], A0[tag]
	local q, r = k0 - h, a0 - k0
	local l1, l2 = q.Magnitude, r.Magnitude
	local v = target - h
	local dist = math.clamp(v.Magnitude, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.02)
	local d = v.Unit
	local along = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
	local high = math.sqrt(math.max(l1 * l1 - along * along, 0))
	local perp = q - d * q:Dot(d)
	local pole = if perp.Magnitude > 1e-4 then perp.Unit else V(0, 1, 0)
	local knee = h + d * along + pole * high
	local ankle = h + d * dist
	local Rh = arc(q, knee - h)
	local Rtot = arc(Rh * r, ankle - knee) * Rh
	local upper = Rh
	local lower = Rh:Inverse() * Rtot
	-- level in the world: undo the leg chain and the body's own pitch/roll/yaw
	local foot = Rtot:Inverse() * (pose.JointRoot or I).Rotation:Inverse() * CFrame.Angles(flex or 0, 0, 0)
	local jl, jk, jf = "JointLeg" .. tag, "JointKnee" .. tag, "JointFoot" .. tag
	pose[jl] = (pose[jl] or I):Lerp(upper, w)
	pose[jk] = (pose[jk] or I):Lerp(lower, w)
	pose[jf] = (pose[jf] or I):Lerp(foot, w)
end

-- the world (model space) height of a leg's sole
local function soleY(pose: Pose, tag: string): number
	local _, _, a = legPoints(pose, tag)
	return toWorld(bodyFrame(pose), a).Y - SOLE
end

-- plant: weights per leg, reach: offsets from the rest ankle (world for planted weight, body for
-- the rest), flex: toes. Writes the 24 leg joints into the pose.
local function plantLegs(pose: Pose, plant: Quadruped.Plant, reach: Reach?, flex: { [string]: number }?)
	local bf = bodyFrame(pose)
	for _, tag in LEGS do
		local off = (reach and reach[tag]) or Vector3.zero
		local w = plant[tag] or 0
		local rest = A0[tag]
		local free = rest + off
		-- planted: the offset is in world space; body-local coordinates of that world point
		local planted = bf:PointToObjectSpace(rest + off) + ROOT
		local target = free:Lerp(planted, w)
		solveLocal(pose, tag, target, 1, flex and flex[tag])
	end
	-- never below the floor: a leg that dips plants where it is
	for _, tag in LEGS do
		local lo = soleY(pose, tag)
		if lo < -0.005 then
			local _, _, a = legPoints(pose, tag)
			local wa = toWorld(bf, a)
			local fixed = bf:PointToObjectSpace(wa - V(0, lo, 0)) + ROOT
			solveLocal(pose, tag, fixed, 1, flex and flex[tag])
		end
	end
end

local function plantOf(list: { string }?): Quadruped.Plant
	local out = {}
	for _, tag in LEGS do
		out[tag] = 0
	end
	for _, tag in list or NONE do
		out[tag] = 1
	end
	return out
end

------------------------------------------------------------------------------------
-- Keyed sampling (the Quadruped format with eight legs)

type Key = {
	t: number,
	pose: Pose,
	ease: string?,
	plant: { string }?,
	reach: Reach?,
	flex: { [string]: number }?,
}
type Phase = {
	duration: number,
	keys: { Key },
	overlay: ((u: number, secs: number, input: Input) -> Pose)?,
	-- legs: replaces the keys' plant and reach (a gait): returns plant, reach, flex
	legs: ((u: number, secs: number, input: Input) -> (Quadruped.Plant, Reach, { [string]: number }?))?,
	-- extra: added to the keys' reach (tremble, taps)
	extra: ((u: number, secs: number, input: Input) -> Reach)?,
	air: boolean?,
}

local function sampleKeys(p: Phase, u: number, input: Input): (Pose, Quadruped.Plant, Reach, { [string]: number })
	local keys = p.keys
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
	local plant, reach, flex = {}, {}, {}
	for _, tag in LEGS do
		plant[tag] = pa[tag] + (pb[tag] - pa[tag]) * alpha
		local ra = (a.reach and a.reach[tag]) or Vector3.zero
		local rb = (b.reach and b.reach[tag]) or Vector3.zero
		reach[tag] = ra:Lerp(rb, alpha)
		local fa = (a.flex and a.flex[tag]) or 0
		local fb = (b.flex and b.flex[tag]) or 0
		flex[tag] = fa + (fb - fa) * alpha
	end
	local secs = u * (input.duration or p.duration)
	if p.legs then
		local lp, lr, lf = p.legs(u, secs, input)
		plant, reach = lp, lr
		if lf then
			flex = lf
		end
	end
	if p.extra then
		for tag, v in p.extra(u, secs, input) do
			reach[tag] = (reach[tag] or Vector3.zero) + v
		end
	end
	if p.overlay then
		for name, cf in p.overlay(u, secs, input) do
			pose[name] = (pose[name] or I) * cf
		end
	end
	return pose, plant, reach, flex
end

local moves: { [string]: { [string]: Phase } } = {}
FrostSpider.moves = moves

function FrostSpider.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = moves[move]
	local p = m and m[phase]
	assert(p, ("FrostSpider.sample: no %s.%s"):format(move, phase))
	local pose, plant, reach, flex = sampleKeys(p, u, input or {})
	plantLegs(pose, plant, reach, flex)
	return pose
end

-- plants the legs of an already-built pose (the body joints) on the ground
function FrostSpider.plant(pose: Pose, legs: { string }?, reach: Reach?): Pose
	plantLegs(pose, plantOf(legs or ALL), reach, nil)
	return pose
end

------------------------------------------------------------------------------------
-- Pose helpers

-- the body: y, pitch (+ front up), z, yaw, roll
local R = Quadruped.R
-- fangs: spread (roll out + yaw out), fold (pitch +); L is negative roll, R positive
local function fangs(spread: number, fold: number?): Pose
	local f = fold or 0
	return {
		JointFangL = A(f, spread * 0.55, -spread),
		JointFangR = A(f, -spread * 0.55, spread),
	}
end
local function palps(pitch: number, spread: number?): Pose
	local s = spread or 0
	return { JointPedipalpL = A(pitch, s), JointPedipalpR = A(pitch, -s) }
end
local function merge(...: Pose): Pose
	local out = {}
	for _, p in { ... } do
		for k, v in p do
			out[k] = v
		end
	end
	return out
end
local function mirrorReach(r: Reach): Reach
	local out = {}
	for tag, v in r do
		local flip = if string.sub(tag, 1, 1) == "L" then "R" else "L"
		out[flip .. string.sub(tag, 2)] = V(-v.X, v.Y, v.Z)
	end
	return out
end
-- a reach table for the L legs, mirrored to the R legs
local function pairs8(left: Reach): Reach
	local out = table.clone(left)
	for tag, v in mirrorReach(left) do
		out[tag] = v
	end
	return out
end

local STAND: Pose = {}

------------------------------------------------------------------------------------
-- WebShot: the abdomen climbs and holds, then thrusts

local WEB_DIP = merge({ JointRoot = R(-0.36, -0.07, 0.05), JointAbdomen = A(0.2) }, fangs(0.12, 0.25), palps(0.2, 0.15))
local WEB_RISE = merge(
	{ JointRoot = R(-0.08, -0.13, 0.12), JointAbdomen = A(-0.62) },
	fangs(0.2, 0.1), palps(-0.25, 0.3)
)
local WEB_HOLD = merge(
	{ JointRoot = R(-0.16, -0.17, 0.18, 0, 0), JointAbdomen = A(-0.64) },
	fangs(0.28, 0), palps(-0.35, 0.4)
)
local WEB_LEGS_RISE = pairs8({
	-- the front pair lifts and opens, the second pair half lifts
	L1 = V(-0.7, 1.2, 0.0), L2 = V(-0.35, 0.5, 0.0),
})
local WEB_LEGS_HOLD = pairs8({
	L1 = V(-1.0, 1.7, 0.2), L2 = V(-0.5, 0.7, 0.1),
	L3 = V(-0.6, 0, 0.35), L4 = V(-0.3, 0, 0.4),
})
local WEB_COIL_REACH = pairs8({ L1 = V(0.4, 0, 0.35), L2 = V(0.2, 0, 0.2), L3 = V(0, 0, -0.1), L4 = V(0, 0, -0.2) })
local WEB_THRUST = merge(
	{ JointRoot = R(-0.3, 0.05, -0.38), JointAbdomen = A(0.34) },
	fangs(0.1, 0.3), palps(0.15, 0.1)
)
local WEB_SPRING = merge(
	{ JointRoot = R(-0.12, 0.0, -0.1), JointAbdomen = A(-0.16) },
	fangs(0.1, 0.1), palps(0.0, 0.1)
)

moves.WebShot = {
	windup = {
		duration = 0.9,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.17, pose = WEB_DIP, ease = "out", plant = ALL, reach = WEB_COIL_REACH },
			{ t = 0.55, pose = WEB_RISE, ease = "inOut", plant = WALKERS6, reach = WEB_LEGS_RISE },
			{ t = 0.78, pose = WEB_HOLD, ease = "inOut", plant = WALKERS6, reach = WEB_LEGS_HOLD },
			{ t = 1, pose = merge(WEB_HOLD, { JointRoot = R(-0.2, -0.18, 0.2) }), ease = "linear", plant = WALKERS6, reach = WEB_LEGS_HOLD },
		},
		overlay = function(u, secs)
			local k = smooth(0.5, 0.72, u)
			return {
				JointAbdomen = A(0.04 * k * math.sin(TAU * 13 * secs), 0.03 * k * math.sin(TAU * 9 * secs), 0),
				JointPedipalpL = A(0.12 * k * math.sin(TAU * 10 * secs)),
				JointPedipalpR = A(0.12 * k * math.sin(TAU * 10 * secs + 1.7)),
			}
		end,
		extra = function(u, secs)
			-- the raised front legs tremble
			local k = smooth(0.55, 0.8, u)
			local t = 0.09 * k * math.sin(TAU * 11 * secs)
			return { L1 = V(0, t, 0), R1 = V(0, -t, 0) }
		end,
	},
	active = {
		duration = 0.22,
		keys = {
			{ t = 0, pose = merge(WEB_HOLD, { JointRoot = R(-0.2, -0.18, 0.2) }), plant = WALKERS6, reach = WEB_LEGS_HOLD },
			{ t = 0.4, pose = WEB_THRUST, ease = "in", plant = ALL, reach = pairs8({ L1 = V(0.2, 0, -0.55), L2 = V(0.1, 0, -0.3), L3 = V(0, 0, 0), L4 = V(0, 0, 0.1) }) },
			{ t = 1, pose = WEB_SPRING, ease = "out", plant = ALL, reach = pairs8({ L1 = V(0.1, 0, -0.2), L2 = V(0, 0, -0.1) }) },
		},
	},
	recover = {
		duration = 0.7,
		keys = {
			{ t = 0, pose = WEB_SPRING, plant = ALL, reach = pairs8({ L1 = V(0.1, 0, -0.2), L2 = V(0, 0, -0.1) }) },
			{ t = 0.5, pose = merge({ JointRoot = R(-0.04, 0.02, 0.03) }, fangs(0.04), palps(0.05, 0.05)), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- the abdomen bounces to rest (damped)
		overlay = function(u, secs)
			local f = (1 - smooth(0.15, 0.95, u)) * 0.14
			return { JointAbdomen = A(f * math.sin(TAU * 4.2 * secs) - 0.04 * (1 - u) ^ 2) }
		end,
	},
}

------------------------------------------------------------------------------------
-- FrostFang: rears up, fangs spreading, then the lunge and the bite

local FANG_COIL = merge(
	{ JointRoot = R(-0.4, -0.1, 0.0), JointAbdomen = A(0.2) },
	fangs(0.1, 0.3), palps(0.25, 0.1)
)
local FANG_COIL_REACH = pairs8({ L1 = V(0.3, 0, 0.5), L2 = V(0.15, 0, 0.3), L3 = V(0, 0, 0.1), L4 = V(0, 0, -0.1) })
local FANG_REAR = merge(
	{ JointRoot = R(0.42, 0.42, 0.55), JointAbdomen = A(-0.25) },
	fangs(0.5, -0.1), palps(-0.3, 0.45)
)
local FANG_REAR_REACH = pairs8({
	L1 = V(-1.1, 2.9, -1.0), L2 = V(-0.9, 2.0, -0.7),
	L3 = V(0, 0, 0.3), L4 = V(0, 0, 0.1),
})
local FANG_PEAK = merge(
	{ JointRoot = R(0.5, 0.62, 0.78), JointAbdomen = A(-0.4) },
	fangs(0.68, -0.18), palps(-0.4, 0.6)
)
local FANG_PEAK_REACH = pairs8({
	L1 = V(-1.5, 3.4, -1.3), L2 = V(-1.2, 2.5, -0.9),
	L3 = V(0, 0, 0.4), L4 = V(0, 0, 0.15),
})
local FANG_LEGS_REAR = REST6
local FANG_LUNGE_REACH = pairs8({
	L1 = V(0.6, 0.2, -1.8), L2 = V(0.3, 0.2, -1.2),
	L3 = V(0, 0, 0.3), L4 = V(0, 0, 0.4),
})
local FANG_STRIKE = merge(
	{ JointRoot = R(-0.12, -0.14, -0.6), JointAbdomen = A(-0.1) },
	fangs(0.62, -0.25), palps(-0.1, 0.5)
)
local FANG_BITE = merge(
	{ JointRoot = R(-0.2, -0.2, -0.65), JointAbdomen = A(0.0) },
	fangs(-0.06, -0.25), palps(0.15, -0.1)
)

moves.FrostFang = {
	windup = {
		duration = 0.7,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = FANG_COIL, ease = "out", plant = ALL, reach = FANG_COIL_REACH },
			{ t = 0.72, pose = FANG_REAR, ease = "inOut", plant = REST6, reach = FANG_REAR_REACH },
			{ t = 1, pose = FANG_PEAK, ease = "out", plant = REST6, reach = FANG_PEAK_REACH },
		},
		overlay = function(u, secs)
			local k = smooth(0.72, 0.9, u)
			return {
				JointRoot = A(0, 0.015 * k * math.sin(TAU * 12 * secs), 0.012 * k * math.sin(TAU * 8 * secs)),
				JointFangL = A(0, 0, 0.05 * k * math.sin(TAU * 15 * secs)),
				JointFangR = A(0, 0, -0.05 * k * math.sin(TAU * 15 * secs)),
			}
		end,
		extra = function(u, secs)
			local k = smooth(0.7, 0.9, u)
			local t = 0.12 * k * math.sin(TAU * 10 * secs)
			return { L1 = V(0, t, 0), R1 = V(0, -t, 0), L2 = V(0, -t * 0.5, 0), R2 = V(0, t * 0.5, 0) }
		end,
	},
	active = {
		duration = 0.3,
		keys = {
			{ t = 0, pose = FANG_PEAK, plant = REST6, reach = FANG_PEAK_REACH },
			{ t = 0.2, pose = FANG_STRIKE, ease = "in", plant = REST6, reach = FANG_LUNGE_REACH },
			{ t = 0.78, pose = FANG_STRIKE, ease = "linear", plant = REST6, reach = FANG_LUNGE_REACH },
			{ t = 0.92, pose = FANG_BITE, ease = "in", plant = REST6, reach = pairs8({
				L1 = V(0.9, 0.1, -2.0), L2 = V(0.5, 0.1, -1.3), L3 = V(0, 0, 0.3), L4 = V(0, 0, 0.4),
			}) },
			{ t = 1, pose = FANG_BITE, plant = REST6, reach = pairs8({
				L1 = V(0.9, 0.1, -2.0), L2 = V(0.5, 0.1, -1.3), L3 = V(0, 0, 0.3), L4 = V(0, 0, 0.4),
			}) },
		},
		-- the rear legs scramble through the lunge
		extra = function(u, secs)
			local k = smooth(0.1, 0.3, u) * (1 - smooth(0.85, 1, u))
			local s = math.sin(TAU * 7 * secs)
			return {
				L3 = V(0, 0.25 * k * math.max(0, s), 0.45 * k * s),
				R3 = V(0, 0.25 * k * math.max(0, -s), -0.45 * k * s),
				L4 = V(0, 0.25 * k * math.max(0, -s), -0.45 * k * s),
				R4 = V(0, 0.25 * k * math.max(0, s), 0.45 * k * s),
			}
		end,
	},
	recover = {
		duration = 0.9,
		keys = {
			{ t = 0, pose = FANG_BITE, plant = REST6, reach = pairs8({
				L1 = V(0.9, 0.1, -2.0), L2 = V(0.5, 0.1, -1.3), L3 = V(0, 0, 0.3), L4 = V(0, 0, 0.4),
			}) },
			{ t = 0.22, pose = merge(FANG_BITE, { JointRoot = R(-0.22, -0.14, -0.6) }), plant = REST6, reach = pairs8({
				L1 = V(0.9, 0.1, -1.9), L2 = V(0.5, 0.1, -1.2), L3 = V(0, 0, 0.3), L4 = V(0, 0, 0.4),
			}) },
			{ t = 0.5, pose = merge({ JointRoot = R(-0.1, 0.05, -0.2), JointAbdomen = A(-0.08) }, fangs(0.12, 0.15), palps(0, 0.1)), ease = "inOut", plant = ALL, reach = pairs8({ L1 = V(0.3, 0, -0.8), L2 = V(0.1, 0, -0.4), L3 = V(0, 0, 0.1) }) },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- worrying the prey: a fast shake of the body and the jaws chomping, dying away
		overlay = function(u, secs)
			local f = (1 - smooth(0.12, 0.42, u))
			local s = math.sin(TAU * 8 * secs)
			local c = math.max(0, math.sin(TAU * 5 * secs))
			return {
				JointRoot = A(0, 0.16 * f * s, 0.05 * f * s),
				JointFangL = A(0, 0, -0.18 * f * c),
				JointFangR = A(0, 0, 0.18 * f * c),
			}
		end,
	},
}

-- FrostFangSkid: a missed lunge ends in a braking slide
local SKID_POSE = merge(
	{ JointRoot = R(-0.15, 0.22, 0.25), JointAbdomen = A(-0.3) },
	fangs(0.4, -0.12), palps(-0.2, 0.4)
)
local SKID_REACH = pairs8({ L1 = V(0.9, 0.15, -1.2), L2 = V(0.6, 0, -0.6), L3 = V(0, 0, -0.2), L4 = V(0, 0, 0.1) })
moves.FrostFangSkid = {
	recover = {
		duration = 0.9,
		keys = {
			{ t = 0, pose = FANG_STRIKE, plant = ALL, reach = FANG_LUNGE_REACH },
			{ t = 0.16, pose = SKID_POSE, ease = "out", plant = ALL, reach = SKID_REACH },
			{ t = 0.45, pose = merge(SKID_POSE, { JointRoot = R(-0.1, 0.12, 0.05, 0.28), JointAbdomen = A(-0.1) }), ease = "inOut", plant = ALL, reach = pairs8({ L1 = V(0.5, 0, -0.5), L2 = V(0.3, 0, -0.2) }) },
			{ t = 0.75, pose = merge({ JointRoot = R(-0.05, 0.03, 0, 0.1) }, fangs(0.06), palps(0.05)), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
	},
}

------------------------------------------------------------------------------------
-- Gait helper shared by the loops and the Hop

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local STRIDE = { 1, 1, 1, 1 } -- uniform, so every stance foot slides at the same ground speed (no skating)

-- One tetrapod step cycle: c = the cycle (turns), beta = stance fraction, S = half stride (studs),
-- lift = swing height, mode "fwd" (dirSign +1 forward body travel, -1 backward) or "side" (dirSign +1
-- toward the beast's left); amp scales everything (a ramp in and out).
local function gait(c0: number, S: number, beta: number, lift: number, mode: string, dirSign: number, amp: number): (Quadruped.Plant, Reach, { [string]: number })
	local reach, flex = {}, {}
	for _, tag in LEGS do
		local n = tonumber(string.sub(tag, 2)) :: number
		local c = (c0 + (if GROUP_A[tag] then 0 else 0.5)) % 1
		local f, y, out = 0, 0, 0
		if c < beta then
			f = -1 + 2 * (c / beta)
		else
			local s = (c - beta) / (1 - beta)
			f = 1 - 2 * smoothstep(s)
			y = lift * math.sin(math.pi * s) ^ 0.65
			out = math.sin(math.pi * s)
		end
		local Ss = S * STRIDE[n] * amp
		local x, z = 0, 0
		if mode == "fwd" then
			z = Ss * f * dirSign -- forward travel: the stance foot slides back (+z)
			x = SIDE[tag] * (0.22 * out * amp + (if n % 2 == 0 then 0.32 * amp else -0.12 * amp))
		else
			-- the side scuttle: legs on the leading side reach, the trailing side draws in
			local lead = (SIDE[tag] == -dirSign)
			x = dirSign * Ss * 1.05 * f + SIDE[tag] * 0.25 * out * amp
			if lead then
				x += -dirSign * 0.0
			end
			z = 0.12 * Ss * f * (if n <= 2 then -1 else 1) -- the crab sweep: front legs a touch forward
		end
		reach[tag] = V(x, y * amp, z)
		flex[tag] = 0.35 * out * amp
	end
	return plantOf(ALL), reach, flex
end

------------------------------------------------------------------------------------
-- Hop: the skitter back

moves.Hop = {
	active = {
		duration = 0.45,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.12, pose = merge({ JointRoot = R(-0.3, 0.12, 0.1) }, fangs(0.16, 0.0), palps(-0.1, 0.2)), ease = "out", plant = ALL },
			{ t = 0.85, pose = merge({ JointRoot = R(-0.26, 0.1, 0.1) }, fangs(0.14, 0.0), palps(-0.1, 0.2)), ease = "linear", plant = ALL },
			{ t = 1, pose = merge({ JointRoot = R(-0.06, 0.02, 0) }, fangs(0.04), palps(0, 0.05)), ease = "inOut", plant = ALL },
		},
		legs = function(u, secs, input)
			local amp = smooth(0, 0.1, u) * (1 - smooth(0.88, 1, u)) + 0.001
			return gait(secs * 4.6, 0.8, 0.5, 0.7, "fwd", -1, amp)
		end,
		overlay = function(u, secs)
			local k = smooth(0.08, 0.2, u) * (1 - smooth(0.85, 1, u))
			return {
				JointAbdomen = A(-0.1 * k + 0.1 * k * math.sin(TAU * 9 * secs)),
				JointRoot = A(0.03 * k * math.sin(TAU * 9.2 * secs), 0.03 * k * math.sin(TAU * 4.6 * secs), 0.025 * k * math.sin(TAU * 4.6 * secs)),
			}
		end,
		air = true,
	},
}

------------------------------------------------------------------------------------
-- Stagger and Death

local HIT_REACH = pairs8({
	L1 = V(-0.9, 1.9, 0.5), L2 = V(-0.6, 1.0, 0.3),
	L3 = V(0, 0, 0.2), L4 = V(0, 0, 0.1),
})
local HIT: Pose = merge(
	{ JointRoot = R(0.0, 0.26, 0.4), JointAbdomen = A(-0.4) },
	fangs(0.55, -0.1), palps(-0.4, 0.5)
)
moves.Stagger = {
	active = {
		duration = 0.35,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = HIT, ease = "out", plant = REST6, reach = HIT_REACH },
			{ t = 0.5, pose = HIT, plant = REST6, reach = HIT_REACH },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, secs, input)
			local side = math.clamp(input.side or 0, -1, 1)
			local e = if u < 0.2 then EASE.out(u / 0.2) else 1 - EASE.inOut((u - 0.2) / 0.8)
			return {
				JointRoot = A(0, 0.1 * side * e, 0.08 * side * e),
				JointAbdomen = A(0, 0.08 * side * e, 0),
			}
		end,
	},
}

-- the legs curl in over the back: ankles go up first (clear of the body and of each other), then
-- in to a point above it, all in BODY space. stage 0 = rest, 1 = straight up, 2 = curled
local function curlReach(stage: number): Reach
	local out = {}
	for _, tag in LEGS do
		local n = tonumber(string.sub(tag, 2)) :: number
		local odd = n % 2 -- alternate legs curl higher and tighter, so neighbours do not tangle
		local up = A0[tag] + V(SIDE[tag] * 0.3, 2.6, 0)
		local curled = V(SIDE[tag] * (1.3 + 0.8 * (1 - odd)), 4.0 + 0.9 * (1 - odd), HIPZ[n] + LEAN[n] * 0.5)
		local target
		if stage <= 1 then
			target = A0[tag]:Lerp(up, stage)
		else
			target = up:Lerp(curled, stage - 1)
		end
		out[tag] = target - A0[tag]
	end
	return out
end
local BUCKLE_REACH = pairs8({
	L1 = V(-0.9, 0.0, -0.5), L2 = V(-1.1, 0, -0.1), L3 = V(-1.1, 0, 0.2), L4 = V(-0.9, 0, 0.6),
})
local DEAD_BODY = merge({ JointRoot = R(-0.85, 0.0, 0.05, 0, 0.06), JointAbdomen = A(-0.1) }, fangs(0.3, 0.55), palps(0.4, 0.3))
moves.Death = {
	active = {
		duration = 1.2,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.12, pose = HIT, ease = "out", plant = REST6, reach = HIT_REACH },
			-- the legs give out: the feet slide out, the body drops
			{ t = 0.38, pose = merge({ JointRoot = R(-0.5, -0.05, 0.05, 0, 0.05), JointAbdomen = A(0.15) }, fangs(0.4, 0.2), palps(0.1, 0.3)), ease = "in", plant = ALL, reach = BUCKLE_REACH },
			-- hits the ground, bounces a little
			{ t = 0.52, pose = merge({ JointRoot = R(-0.8, 0.04, 0.04, 0, 0.07), JointAbdomen = A(0.0) }, fangs(0.3, 0.4), palps(0.3, 0.3)), ease = "in", plant = ALL, reach = BUCKLE_REACH },
			{ t = 0.62, pose = merge({ JointRoot = R(-0.76, 0.0, 0.04, 0, 0.06), JointAbdomen = A(-0.05) }, fangs(0.3, 0.45), palps(0.3, 0.3)), ease = "out", plant = NONE, reach = curlReach(1) },
			{ t = 0.84, pose = DEAD_BODY, ease = "inOut", plant = NONE, reach = curlReach(1.55) },
			{ t = 0.97, pose = DEAD_BODY, ease = "inOut", plant = NONE, reach = curlReach(2) },
			{ t = 1, pose = DEAD_BODY, plant = NONE, reach = curlReach(2) },
		},
		extra = function(u, secs)
			-- the last twitch, dying away
			local k = smooth(0.5, 0.65, u) * (1 - smooth(0.7, 1, u))
			local s = 0.18 * k * math.sin(TAU * 9 * secs)
			return { L2 = V(0, s, 0), R3 = V(0, -s, 0), L4 = V(0, s * 0.8, 0), R1 = V(0, s * 0.6, 0) }
		end,
	},
}

FrostSpider.durations = Quadruped.durations(moves :: any)

------------------------------------------------------------------------------------
-- Loops

local loops = {}

local function finish(pose: Pose, plant: Quadruped.Plant, reach: Reach, flex: { [string]: number }?): Pose
	plantLegs(pose, plant, reach, flex)
	return pose
end

-- breath, leg-tip taps, the front legs feeling the air, a slow abdomen sway, palp twitches
function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 2.6)
	local reach: Reach = {}
	-- a tapping leg every ~1.7 s: two quick taps
	local slot = math.floor(clock / 1.7)
	local t0 = clock - slot * 1.7
	local who = LEGS[1 + math.floor(hash(slot, seed) * 8) % 8]
	if t0 > 0.2 and t0 < 0.85 then
		local k = math.max(0, math.sin((t0 - 0.2) / 0.65 * TAU * 1.5))
		reach[who] = V(0, 0.42 * k * k, 0)
	end
	-- the front pair feels the air
	for _, tag in FRONT2 do
		local s = SIDE[tag]
		local ph = clock * 0.9 + (if s < 0 then 0 else 2.1) + seed
		reach[tag] = (reach[tag] or Vector3.zero) + V(s * 0.12 * math.sin(ph * 1.3), 0.08 + 0.18 * math.max(0, math.sin(ph)), -0.14 * math.sin(ph * 0.8))
	end
	local twitch = math.max(0, math.sin(clock * 1.9 + seed * 3)) ^ 12
	local shift = math.sin(clock * 0.31 + seed)
	local pose: Pose = {
		JointRoot = R(0.025 * breath - 0.03, 0.01 * breath + 0.012 * shift, 0.012 * shift, 0.03 * shift, 0.012 * math.sin(clock * 0.43 + seed)),
		JointAbdomen = A(-0.03 * breath - 0.02 + 0.02 * math.sin(clock * 0.8), 0.05 * math.sin(clock * 0.37 + 1), 0.02 * math.sin(clock * 0.6)),
		JointPedipalpL = A(0.12 * twitch + 0.03 * math.sin(clock * 1.7), 0.06 * math.sin(clock * 1.1 + 1)),
		JointPedipalpR = A(0.12 * twitch * math.sin(clock * 3.1) ^ 2 + 0.03 * math.sin(clock * 1.5), -0.06 * math.sin(clock * 1.3)),
		JointFangL = A(0.05 * twitch + 0.02 * math.sin(clock * 2.3), 0, -0.04 - 0.03 * math.sin(clock * 0.9)),
		JointFangR = A(0.05 * twitch + 0.02 * math.sin(clock * 2.1), 0, 0.04 + 0.03 * math.sin(clock * 0.9 + 1)),
	}
	return finish(pose, plantOf(ALL), reach, nil)
end

local WALK = { S = 0.74, beta = 0.55, lift = 0.7 }
local RUN = { S = 0.86, beta = 0.5, lift = 0.85 }

local function skitter(phase: number, cfg: any, crouch: number, lean: number, input: Input?): Pose
	local plant, reach, flex = gait(phase / TAU, cfg.S, cfg.beta, cfg.lift, "fwd", 1, 1)
	local bob = math.cos(2 * phase)
	local pose: Pose = {
		JointRoot = R(
			-crouch + 0.06 * bob,
			-lean + 0.03 * math.sin(2 * phase + 0.7),
			0.05 * math.sin(2 * phase),
			0.05 * math.sin(2 * phase + 0.4),
			0.035 * math.sin(phase)
		),
		JointAbdomen = A(-0.04 + 0.07 * math.sin(4 * phase + 0.5), 0.12 * math.sin(2 * phase + 1.1), 0.03 * math.sin(2 * phase)),
		JointPedipalpL = A(0.18 * math.sin(4 * phase), 0.08 * math.sin(2 * phase)),
		JointPedipalpR = A(0.18 * math.sin(4 * phase + 1.9), -0.08 * math.sin(2 * phase)),
		JointFangL = A(0, 0, -0.06 - 0.04 * math.sin(2 * phase)),
		JointFangR = A(0, 0, 0.06 + 0.04 * math.sin(2 * phase + 1)),
	}
	return finish(pose, plant, reach, flex)
end

function loops.walk(phase: number, speed: number, input: Input?): Pose
	return skitter(phase, WALK, 0.1, 0.0, input)
end

function loops.run(phase: number, speed: number, input: Input?): Pose
	return skitter(phase, RUN, 0.22, 0.05, input)
end

-- the side scuttle: dir +1 to the beast's left (-X)
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local plant, reach, flex = gait(phase / TAU, 0.8, 0.55, 0.75, "side", dir, 1)
	local bob = math.cos(2 * phase)
	local pose: Pose = {
		JointRoot = R(-0.14 + 0.05 * bob, 0.0, 0, -0.06 * dir * math.sin(phase), 0.05 * dir + 0.03 * dir * math.sin(2 * phase)),
		JointAbdomen = A(-0.06 + 0.05 * math.sin(4 * phase), 0.1 * math.sin(2 * phase + 1.1) - 0.05 * dir, 0.04 * dir),
		JointPedipalpL = A(0.12 * math.sin(4 * phase), 0.1),
		JointPedipalpR = A(0.12 * math.sin(4 * phase + 1.9), -0.1),
		JointFangL = A(0, 0, -0.08),
		JointFangR = A(0, 0, 0.08),
	}
	return finish(pose, plant, reach, flex)
end
FrostSpider.loops = loops

-- radians per second of the loop phase so the planted feet do not skate: a foot slides back 2 S
-- over its stance, beta of the cycle
function FrostSpider.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	local us = math.max(speed, 0.2) / s
	if loop == "walk" then
		return TAU * us * WALK.beta / (2 * WALK.S)
	elseif loop == "run" then
		return TAU * us * RUN.beta / (2 * RUN.S)
	elseif loop == "circle" then
		return TAU * us * 0.55 / (2 * 0.8 * 1.05)
	end
	return 1 -- idle: pass the clock in seconds as its phase
end

-- every joint translation (the root's rise and drop) times the scale
function FrostSpider.scaled(pose: Pose, scale: number): Pose
	if scale ~= 1 then
		for name, cf in pose do
			pose[name] = cf - cf.Position + cf.Position * scale
		end
	end
	return pose
end

return FrostSpider
