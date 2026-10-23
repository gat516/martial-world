--!strict
-- Thunder Ape B (boss): the knuckle-walking storm ape. Same pose API as WolfKing.luau
-- (sample / moves / durations / loops / JOINTS / gaitRate / scaled / plant / VARIANTS),
-- plus .BEATS and .SCALE. No instances and no gameplay decisions live here.
--
-- UNIT SPACE: pivots, root translations and fist targets are at the roster Thunder Ape's
-- scale. EnemyAnimator applies SCALE (3.71, family.scale) ONCE, after sampling; the gait
-- loops divide speeds by ThunderApe.SCALE themselves. Fist and foot contacts are solved by
-- the shared planting solver (Quadruped.new): arms are "front legs" (shoulder, elbow,
-- wrist = the fist), legs the "hind" ones.
--
-- The timings live in TIMING below, one line per move (seconds, the def's values; the pose
-- recover of a stationary move is the server recover minus its active beat, which
-- EnemyAnimator plays first). Every key is a fraction of its phase, so a def change is a
-- one-line change here and the keys stretch with it.
-- Stationary contact is the END of the windup (the combo lands at about 0.80, 1.85 and 3.0 s).
-- Dash/flight moves sample the active phase by elapsed fraction of input.duration (the real
-- seconds). The boulder leaves the hand at BOULDER_RELEASE (1.25 s of a 1.70 s windup).

local Quadruped = require(script.Parent.Quadruped)

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Phase = Quadruped.Phase
type Leg = Quadruped.Leg
type Step = Quadruped.Step

local ThunderApe = {}
local V = Vector3.new
local I, TAU = CFrame.identity, Quadruped.TAU
local A, R = Quadruped.A, Quadruped.R
local with, paws, smooth, bump = Quadruped.with, Quadruped.paws, Quadruped.smooth, Quadruped.bump
local ALL, HIND, NONE = Quadruped.ALL, Quadruped.HIND, Quadruped.NONE
local FRONT = Quadruped.FRONT

local SCALE = 3.71
ThunderApe.SCALE = SCALE

-- { windup, active, pose recover } in seconds. Server recover in the comment.
local TIMING = {
	Challenge = { 2.40, 0.20, 0.60 }, -- 0.80
	ClubSwing = { 0.80, 0.12, 0.33 }, -- 0.45
	Backhand = { 0.60, 0.12, 0.33 }, -- 0.45
	ThunderPound = { 0.85, 0.18, 1.12 }, -- 1.30
	BodySlam = { 1.10, 0.62, 1.10 }, -- 1.10 (dash ~0.62)
	SkyfallSlam = { 1.20, 0.75, 1.10 }, -- 1.10 (flight)
	ThunderRush = { 1.20, 0.70, 0.90 }, -- 0.90 (dash ~0.7)
	Bound = { 0.45, 0.55, 0.35 }, -- 0.35 (flight: DashSeconds by BoundMode, over 0.80, flank 0.60, back 0.55, short 0.42)
	-- the arrivals (started the moment a rush or leap lands with the target in reach) and the
	-- skid-and-turn after a miss (a recover only; EnemyAnimator gives it the parent's recover)
	RushSwipe = { 0.40, 0.12, 0.78 }, -- 0.90
	SkyfallSweep = { 0.50, 0.12, 0.88 }, -- 1.00
	ThunderRushSkid = { 0, 0, 0.90 }, -- thunderRush's 0.90
	SkyfallSlamSkid = { 0, 0, 1.10 }, -- skyfallSlam's 1.10
	BoulderHurl = { 1.70, 0.12, 0.78 }, -- 0.90
	ThunderLance = { 1.40, 0.12, 0.78 }, -- 0.90
	ThunderRoar = { 1.30, 0.20, 0.80 }, -- 1.00
	PhaseRoar = { 1.60, 0.20, 1.00 }, -- 1.20
	StormCall = { 1.20, 0.15, 3.00 }, -- the bolts' length (input.duration)
	Judgment = { 1.60, 1.00, 1.80 }, -- 1.80 (flight)
	Stagger = { 0, 0.35, 0 },
	Death = { 0, 3.20, 0 },
}
ThunderApe.TIMING = TIMING
-- seconds into the BoulderHurl windup when the boulder leaves the right hand
local BOULDER_RELEASE = 1.25
ThunderApe.BOULDER_RELEASE = BOULDER_RELEASE

ThunderApe.JOINTS = {
	"JointRoot", "JointSpine", "JointHead", "JointJaw",
	"JointLegFL", "JointLegFR", "JointElbowFL", "JointElbowFR", "JointWristFL", "JointWristFR",
	"JointFingersFL", "JointFingersFR",
	"JointLegBL", "JointLegBR", "JointKneeBL", "JointKneeBR", "JointAnkleBL", "JointAnkleBR",
	"JointMane1", "JointMane2", "JointMane3", "JointBeard", "JointBrow",
}

-- the chest-beat moments, seconds into the windup, alternating left fist first
ThunderApe.BEATS = {
	Challenge = { 0.55, 1.15, 1.75 },
	ThunderRoar = { 0.45, 0.85 },
	PhaseRoar = { 0.4, 0.8, 1.2 },
}

local P = {
	JointRoot = V(0, 3.1, 1.3), JointSpine = V(0, 3.7, 0.6),
	JointLegFL = V(-2.0, 5.6, -0.8), JointElbowFL = V(-2.45, 3.4, -1.3), JointWristFL = V(-2.55, 1.25, -1.7),
	JointLegFR = V(2.0, 5.6, -0.8), JointElbowFR = V(2.45, 3.4, -1.3), JointWristFR = V(2.55, 1.25, -1.7),
	JointLegBL = V(-1.1, 2.9, 1.7), JointKneeBL = V(-1.4, 1.6, 0.9), JointAnkleBL = V(-1.4, 0.55, 1.7),
	JointLegBR = V(1.1, 2.9, 1.7), JointKneeBR = V(1.4, 1.6, 0.9), JointAnkleBR = V(1.4, 0.55, 1.7),
}
local LEGS: { [string]: Leg } = {
	FL = { upper = "JointLegFL", mid = "JointElbowFL", foot = "JointWristFL", base = "JointSpine", fold = 1, front = true, knee = -1 },
	FR = { upper = "JointLegFR", mid = "JointElbowFR", foot = "JointWristFR", base = "JointSpine", fold = 1, front = true, knee = -1 },
	BL = { upper = "JointLegBL", mid = "JointKneeBL", foot = "JointAnkleBL", base = "JointRoot", fold = -1, front = false, knee = 1 },
	BR = { upper = "JointLegBR", mid = "JointKneeBR", foot = "JointAnkleBR", base = "JointRoot", fold = -1, front = false, knee = 1 },
}
local rig = Quadruped.new({
	P = P, root = "JointRoot", spine = "JointSpine", legs = LEGS,
	sole = {
		-- the fist: hand block bottom plus the curled fingers' front edge, relative to the wrist
		front = { V(-0.78, -1.25, -0.825), V(0.78, -1.25, -0.825), V(-0.78, -1.25, 0.625), V(0.78, -1.25, 0.625), V(-0.78, -1.245, -1.0), V(0.78, -1.245, -1.0) },
		hind = { V(-0.55, -0.55, -1.1), V(0.55, -0.55, -1.1), V(-0.55, -0.55, 0.5), V(0.55, -0.55, 0.5) },
	},
	curl = { front = -0.2, hind = -0.5 },
})

--------------------------------------------------------------------------------
-- Pose builder. Arms are given in WORLD pitch (0 hangs down, + swings forward/up, pi is
-- straight overhead) so a rear-up does not drag them along: the torso pitch is
-- subtracted. L/R = { sh, out, yaw, el, wr, fi }: out spreads the arm away from the body.
-- root = { y, pitch, z, yaw, roll }, spine / head = { pitch, yaw, roll }, jaw = how far it
-- is open (rad), mane = { m1, m2, m3 } lean back, brow + lifts, beard + swings forward.

local function arm(spec: { number }?, torso: number, side: number): (CFrame, CFrame, CFrame, CFrame)
	local s = spec or {}
	local sh, out, yaw, el, wr, fi = s[1] or 0, s[2] or 0, s[3] or 0, s[4] or 0, s[5] or 0, s[6] or 0
	return A(sh - torso, yaw, side * out), A(el), A(wr), A(fi)
end

local function mk(o: any): Pose
	local r, sp, h, m = o.root or {}, o.spine or {}, o.head or {}, o.mane or {}
	local pose: Pose = {}
	pose.JointRoot = R(r[1] or 0, r[2] or 0, r[3] or 0, r[4] or 0, r[5] or 0)
	pose.JointSpine = A(sp[1] or 0, sp[2] or 0, sp[3] or 0)
	pose.JointHead = A(h[1] or 0, h[2] or 0, h[3] or 0)
	pose.JointJaw = A(-(o.jaw or 0))
	pose.JointBrow = A(o.brow or 0)
	-- the beard rides the jaw and the head: swing it forward as they open and drop so it clears the chest drum
	pose.JointBeard = A((o.beard or 0) + 0.6 * (o.jaw or 0) - 0.6 * math.min(0, h[1] or 0))
	pose.JointMane1, pose.JointMane2, pose.JointMane3 = A(m[1] or 0), A(m[2] or 0), A(m[3] or 0)
	local torso = (r[2] or 0) + (sp[1] or 0)
	pose.JointLegFL, pose.JointElbowFL, pose.JointWristFL, pose.JointFingersFL = arm(o.L, torso, -1)
	pose.JointLegFR, pose.JointElbowFR, pose.JointWristFR, pose.JointFingersFR = arm(o.R, torso, 1)
	for _, tag in { "BL", "BR" } do
		local s = o[tag]
		if s then
			pose["JointLeg" .. tag], pose["JointKnee" .. tag], pose["JointAnkle" .. tag] = A(s[1] or 0, 0, s[4] or 0), A(s[2] or 0), A(s[3] or 0)
		end
	end
	return pose
end

local function mix(a: Pose, b: Pose, t: number): Pose
	local out: Pose = {}
	for name, cf in a do
		out[name] = cf:Lerp(b[name] or I, t)
	end
	for name, cf in b do
		if not a[name] then
			out[name] = I:Lerp(cf, t)
		end
	end
	return out
end

local function mirror(pose: Pose): Pose
	return Quadruped.mirrorPose(pose)
end

--------------------------------------------------------------------------------
-- Gait. A limb is planted for its stance share of the cycle and slides back along the
-- ground at EXACTLY the ground speed (the solver puts the fist/foot at rest + reach);
-- the swing reaches past touchdown. The shoulder/hip angle of a swing's ends is read off
-- the solver itself (a lookup built once) so stance and swing meet without a jump.

local angleLut: { [string]: { number } } = {}
local LUT_MIN, LUT_STEP, LUT_N = -2.0, 0.1, 41
for tag, leg in LEGS do
	local t = {}
	for i = 0, LUT_N - 1 do
		local pose: Pose = {}
		rig.plantLegs(pose, Quadruped.plantOf({ tag }), false, { [tag] = V(0, 0, LUT_MIN + i * LUT_STEP) })
		t[i + 1] = Quadruped.pitchOf(pose[leg.upper])
	end
	angleLut[tag] = t
end
local function angleAt(tag: string, rz: number): number
	local t = angleLut[tag]
	local f = math.clamp((rz - LUT_MIN) / LUT_STEP, 0, LUT_N - 1.001)
	local i = math.floor(f)
	return t[i + 1] + (t[i + 2] - t[i + 1]) * (f - i)
end

local walkHalf = 0.7 -- unit studs each side of the rest spot a walking limb travels in stance
local WALK_STANCE = 0.72
local WALK_OFF = { BL = 0, FR = 0.25, BR = 0.5, FL = 0.75 } -- diagonal sequence, as primates walk
local RUN_STANCE = { BL = 0.31, BR = 0.31, FL = 0.3, FR = 0.3 }
local RUN_OFF = { BL = 0, BR = 0.1, FL = 0.5, FR = 0.6 }
ThunderApe.GALLOP = { OFFSETS = RUN_OFF, STANCE = RUN_STANCE }

local function runRate(speed: number): number
	return 1.0 + 0.02 * speed -- cycles per second (real, heavy bounds)
end

-- one limb at cycle position x of its own stance/swing; returns nothing, fills pose. ramp is
-- the limb's share of the body's weight: it eases in over the first part of the stance and out
-- over the last, so the root drop it asks for never jumps at a touchdown or a lift-off.
local RAMP = 0.35
local SWAP_TAG = { FL = "FR", FR = "FL", BL = "BR", BR = "BL" }
local function limb(pose: Pose, steps: { [string]: Step }, stance: { [string]: number }, reach: { [string]: Vector3 }, ramp: { [string]: number }, tag: string, x: number, st: number, half: number, bias: number, o: any)
	local front = LEGS[tag].front
	local out = if tag == "FL" or tag == "BL" then -1 else 1
	-- a sidestep mirrors its per-limb divisors when it goes the other way
	local div = o.div and o.div[if (o.lateral or 1) < 0 then SWAP_TAG[tag] else tag]
	if x < st then
		local s = x / st
		stance[tag] = 1
		ramp[tag] = smooth(0, RAMP, s) * (1 - smooth(1 - RAMP, 1, s))
		if o.lateral then
			-- circle: sidestep, the limb slides across the ground via its roll
			local roll = (o.lateral * half / div) * (2 * s - 1)
			reach[tag] = V(0, 0, bias)
			pose[LEGS[tag].upper] = A(0, 0, roll)
		else
			reach[tag] = V(out * 0.0, 0, bias + half * (2 * s - 1))
			pose[LEGS[tag].upper] = A(0, 0, out * (o.splay or 0.03) * -1)
		end
	else
		local s = (x - st) / (1 - st)
		local e = smooth(0, 1, s)
		-- a sidestep plants at the same z it lifted from: only the roll travels
		local zh = if o.lateral then 0 else half
		local a0, a1 = angleAt(tag, bias + zh), angleAt(tag, bias - zh)
		local a = a0 + (a1 - a0) * e + (o.over or 0.25) * math.abs(a1 - a0) * math.sin(math.pi * s) ^ 2
		local lift = math.sin(math.pi * math.min(1, s * 1.12)) ^ 0.8
		local roll = -out * (o.splay or 0.03) * (0.4 + 0.6 * lift)
		if o.lateral then
			roll = (o.lateral * half / div) * (1 - 2 * e)
		end
		rig.setLeg(pose, steps, tag, a, roll, lift, 0, (if front then o.clearF else o.clearH) or 0.4)
		-- where it lifted off and where it will land, for the hand-off in finishGait
		o.swing[tag] = { s = s, z0 = bias + zh, z1 = bias - zh }
	end
end

local function gait(cyc: number, speed: number, f: number, o: any): Pose
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	local stance: { [string]: number } = { FL = 0, FR = 0, BL = 0, BR = 0 }
	local reach: { [string]: Vector3 } = {}
	local ramp: { [string]: number } = {}
	o.swing = {}
	local u = speed / SCALE -- unit studs per second
	for tag, off in o.off do
		local st = o.stance[tag]
		local half = math.min(u * st / f / 2 * (if LEGS[tag].front then (o.kF or 1) else (o.kH or 1)), o.maxHalf or 1.2)
		limb(pose, steps, stance, reach, ramp, tag, (cyc - off) % 1, st, half, (if LEGS[tag].front then o.biasF else o.biasH) or 0, o)
	end
	return pose, steps, stance, reach, ramp, o.swing
end

-- A limb in stance never straightens past STRETCH of its length: near full extension a
-- two-joint solve is hypersensitive (a 0.05 unit rise of the shoulder swung a planted elbow
-- 0.25 rad in one frame of the gallop's bounce), so a limb the body has risen away from
-- unloads and lifts off the ground instead, like a fist rolling off at push-off.
local STRETCH = 0.985
local function finishGait(pose: Pose, steps: any, stance: any, reach: any, ramp: any, swing: any): Pose
	-- the root drops as far as the loaded limbs need, each weighted by its ramp, so the body
	-- settles onto a landing limb over a few frames instead of snapping onto it. air: skip the
	-- solver's floor clamp (stepLegs clears the swing legs itself; the clamp's re-solve could
	-- flip a nearly straight swing leg to its other branch for one frame)
	local drop = 0
	local short: { [string]: number } = {}
	for tag, w in ramp do
		short[tag] = rig.reachShort(pose, tag, reach[tag], STRETCH)
		drop = math.max(drop, short[tag] * w)
	end
	if drop > 0 then
		pose.JointRoot = CFrame.new(0, -drop, 0) * (pose.JointRoot or I)
	end
	-- what the drop didn't cover, the limb's spot rises by (the fist or foot leaves the ground)
	local function lifted(tag: string, z: Vector3, sh: number?): Vector3
		local s = sh or (rig.reachShort(pose, tag, z, STRETCH) + drop)
		return z + V(0, math.max(0, s - drop), 0)
	end
	for tag in ramp do
		reach[tag] = lifted(tag, reach[tag], short[tag])
	end
	rig.plantLegs(pose, stance, true, reach, true)
	rig.stepLegs(pose, steps)
	-- A swing leg hands off to the stance solve at both ends: just after lift-off it starts from
	-- the planted pose it left, and before touchdown it blends into the planted pose it lands
	-- in, solved on the body as it is now (a lookup table can't know the body's pitch and roll,
	-- and the difference popped 0.4-0.7 rad at every touchdown).
	for tag, sw in swing or {} do
		local leg = LEGS[tag]
		for _, e in { { 1 - smooth(0, 0.4, sw.s), sw.z0 }, { smooth(0.4, 1, sw.s), sw.z1 } } do
			if e[1] > 0.001 then
				local probe = table.clone(pose)
				rig.plantLegs(probe, Quadruped.plantOf({ tag }), true, { [tag] = lifted(tag, V(0, 0, e[2])) }, true)
				for _, j in { leg.upper, leg.mid, leg.foot } do
					pose[j] = (pose[j] or I):Lerp(probe[j] or I, e[1])
				end
			end
		end
	end
	return pose
end

-- the body, head, brow, mane and beard for a loop sample, given lagged waves
local function tufts(pose: Pose, c: number, lean: number, wave: number, lagf: (number) -> number)
	pose.JointMane1 = A(lean + wave * math.cos(lagf(0.5)))
	pose.JointMane2 = A(lean + 0.06 + wave * 1.2 * math.cos(lagf(0.6)))
	pose.JointMane3 = A(lean + 0.12 + wave * 1.4 * math.cos(lagf(0.7)))
end

local loops = {}

function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	-- heavy breath: a long inhale lifts the chest and shoulders, a quick release; the head, brow
	-- and beard settle after it, the manes after them
	local function breath(d: number): number
		local c = (clock - d) * TAU / 4.6 + seed
		return math.sin(c) + 0.25 * math.sin(2 * c - 0.6)
	end
	local b0, b1 = breath(0), breath(0.25)
	local shift = math.sin(clock * 0.27 + seed) -- weight drifts over the fists
	local sway = math.sin(clock * 0.19 + seed * 1.7)
	local look = 0.16 * math.sin(clock * 0.21 + seed) + 0.06 * math.sin(clock * 0.53 + seed * 2)
	local snort = bump(clock % 7.3, 4.8, 5.3) -- an occasional huff
	local grumble = bump(clock % 11.1, 8.0, 9.2)
	local pose = mk({
		root = { 0.0, -0.03 + 0.012 * b0, 0, 0.012 * shift, 0.03 * shift },
		spine = { 0.02 * b0, 0.02 * sway, -0.02 * shift },
		head = { -0.06 + 0.02 * breath(0.4) - 0.04 * snort, look, 0.03 * sway },
		jaw = 0.07 + 0.025 * math.max(0, breath(0.5)) + 0.16 * snort + 0.1 * grumble * math.abs(math.sin(clock * 9)),
		brow = -0.12 + 0.03 * breath(0.45) - 0.05 * grumble,
		beard = 0.05 + 0.04 * breath(0.65),
		mane = { 0.03 + 0.03 * breath(0.5), 0.05 + 0.035 * breath(0.7), 0.07 + 0.04 * breath(0.9) },
	})
	local fl, fr = 0.05 * shift, -0.05 * shift
	local reach = { FL = V(0, 0, fl), FR = V(0, 0, fr), BL = V(0, 0, 0.04 * sway), BR = V(0, 0, -0.04 * sway) }
	rig.plantLegs(pose, Quadruped.plantOf(ALL), false, reach)
	return pose
end

local WALK = { off = WALK_OFF, stance = { BL = WALK_STANCE, BR = WALK_STANCE, FL = WALK_STANCE, FR = WALK_STANCE }, biasF = 0.0, biasH = 0.0, clearF = 0.45, clearH = 0.3, splay = 0.04, over = 0.2 }

function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local cyc = phase / TAU % 1
	local pose, steps, stance, reach, ramp, swing = gait(cyc, speed, speed / SCALE * WALK_STANCE / (2 * walkHalf), WALK)
	local function lagf(d: number): number
		return TAU * (cyc - d)
	end
	-- the whole upper body rolls over the planted fist: heavy sway, the hump swinging against the hips
	local sw = math.sin(TAU * cyc)
	local dip = math.max(0, math.sin(TAU * 2 * cyc - 0.5))
	pose.JointRoot = R(0.0, -0.05 + 0.02 * math.sin(TAU * 2 * cyc), 0, 0.035 * sw, 0.05 * sw)
	pose.JointSpine = A(-0.03 + 0.03 * dip, -0.07 * sw, -0.05 * sw)
	pose.JointHead = A(-0.1 + 0.04 * math.cos(lagf(0.18) * 2), 0.07 * math.sin(lagf(0.12)), 0.03 * sw)
	pose.JointJaw = A(-0.08 - 0.04 * math.max(0, math.cos(lagf(0.3) * 2)))
	pose.JointBrow = A(-0.14 + 0.04 * math.cos(lagf(0.25) * 2))
	pose.JointBeard = A(0.02 + 0.1 * math.cos(lagf(0.35) * 2 + 1))
	tufts(pose, cyc, 0.06, 0.1, function(d) return lagf(d) * 2 end)
	pose.JointFingersFL = A(0.0)
	return finishGait(pose, steps, stance, reach, ramp, swing)
end

local CIRCLE = { off = WALK_OFF, stance = { BL = 0.62, BR = 0.62, FL = 0.62, FR = 0.62 }, biasF = 0.0, biasH = 0.0, clearF = 0.5, clearH = 0.35, over = 0.1, lateral = 1, maxHalf = 0.7, div = { FL = 2.8, FR = 3.6, BL = 2.4, BR = 2.5 } }
local CIRCLE_HALF = 0.55
local function circleRate(speed: number): number
	return speed / SCALE * 0.62 / (2 * CIRCLE_HALF)
end

function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local yaw = (input and input.targetYaw) or 0
	local cyc = phase / TAU % 1
	local cfg = table.clone(CIRCLE)
	cfg.lateral = dir
	local pose, steps, stance, reach, ramp, swing = gait(cyc, speed, circleRate(speed), cfg)
	local function lagf(d: number): number
		return TAU * (cyc - d)
	end
	local ny = math.clamp(yaw * 0.5, -0.35, 0.35)
	local sw = math.sin(TAU * cyc)
	pose.JointRoot = R(0.0, -0.1, 0, 0.03 * sw, 0.05 * dir + 0.025 * math.sin(TAU * 2 * cyc))
	pose.JointSpine = A(-0.02, ny * 0.5, -0.04 * dir)
	pose.JointHead = A(-0.1 + 0.03 * math.cos(lagf(0.2) * 2), math.clamp(yaw - ny * 0.5, -0.4, 0.4))
	pose.JointJaw = A(-0.14 - 0.04 * math.cos(lagf(0.3) * 2)) -- bared, watching
	pose.JointBrow = A(-0.2)
	pose.JointBeard = A(0.04 + 0.08 * math.cos(lagf(0.4) * 2))
	tufts(pose, cyc, 0.14, 0.09, function(d) return lagf(d) * 2 end)
	return finishGait(pose, steps, stance, reach, ramp, swing)
end

-- THE KNUCKLE-GALLOP. A rotary four-beat bound: hind left, hind right, arm left, arm right.
-- Between the hind push and the arms' reach there is a flight (nothing down), when the body
-- rises; the arms reach out past the shoulders and land with the fist ahead of them.
local function gallop(phase: number, speed: number, rate: number?): Pose
	local f = rate or runRate(speed)
	local cyc = phase / TAU % 1
	local cfg = { off = RUN_OFF, stance = RUN_STANCE, biasF = -0.1, biasH = 0.0, clearF = 0.7, clearH = 0.5, splay = 0.04, over = 0.35, maxHalf = 1.25, kF = 1.1 }
	local pose, steps, stance, reach, ramp, swing = gait(cyc, speed, f, cfg)
	local function lagf(d: number): number
		return TAU * (cyc - d)
	end
	local flight = math.max(0, math.cos(TAU * 2 * (cyc - 0.45))) ^ 1.5
	local drive = math.cos(TAU * (cyc - 0.2))
	local heave = math.cos(TAU * (cyc - 0.35))
	pose.JointRoot = R(0.22 * flight, 0.14 * flight - 0.07 * (1 - flight), 0, 0.05 * drive, 0.03 * math.sin(TAU * cyc))
	pose.JointSpine = A(-0.14 * heave, 0.04 * math.sin(TAU * cyc + 0.4), 0.03 * math.sin(TAU * cyc))
	-- everything loose trails the body, each a little later
	pose.JointHead = A(-0.14 + 0.1 * math.cos(lagf(0.4)), 0.04 * math.sin(lagf(0.15)))
	pose.JointJaw = A(-0.3 - 0.12 * math.max(0, math.cos(lagf(0.5))))
	pose.JointBrow = A(-0.24 + 0.06 * math.cos(lagf(0.45)))
	pose.JointBeard = A(0.08 + 0.12 * math.cos(lagf(0.55))) -- streams back, never into the chest drum
	tufts(pose, cyc, 0.4, 0.16, function(d) return lagf(d) * 2 end)
	return finishGait(pose, steps, stance, reach, ramp, swing)
end

function loops.run(phase: number, speed: number, _input: Input?): Pose
	return gallop(phase, speed)
end

function ThunderApe.gaitRate(loop: string, speed: number, _scale: number?): number
	if loop == "walk" then
		return TAU * speed / SCALE * WALK_STANCE / (2 * walkHalf)
	elseif loop == "run" then
		return TAU * runRate(speed)
	elseif loop == "circle" then
		return TAU * circleRate(speed)
	end
	return 1
end


--------------------------------------------------------------------------------
-- Keyed attacks. Helpers first.

local SUP_R = { "FL", "BL", "BR" } -- the RIGHT arm is free (attacking)
local SUP_L = { "FR", "BL", "BR" } -- the LEFT arm is free
local R_RDY = paws(-0.5, 0.3, 0.3, 0.25)
local R_LOW = paws(-1.0, 0.45, 0.3, 0.3)
local R_REAR = paws(0.0, 0.55, 0.3, 0.3)

-- A planted fist stays on the ground while the torso turns, so its target moves with the
-- shoulder (a twist of psi carries the left shoulder back by 2 sin psi + 2.1 (1 - cos psi)):
-- without it the arm overreaches and the solver drops the whole body.
local function support(pose: Pose, plant: { string }?, reach: any?): any
	if not plant then
		return reach
	end
	local _, ry = (pose.JointRoot or I):ToEulerAnglesXYZ()
	local _, sy = (pose.JointSpine or I):ToEulerAnglesXYZ()
	local psi = ry + sy * 0.7
	local out = {}
	for tag, v in (reach or {}) do
		out[tag] = v
	end
	for _, tag in plant do
		if tag == "FL" or tag == "FR" then
			local base = out[tag] or Vector3.zero
			local dz = if tag == "FL" then 2 * math.sin(psi) + 2.1 * (1 - math.cos(psi)) else -2 * math.sin(psi) + 2.1 * (1 - math.cos(psi))
			local dx = (if tag == "FL" then 2 else -2) * (1 - math.cos(psi)) - 2.1 * math.sin(psi)
			out[tag] = base + V(dx, 0, dz)
		end
	end
	return out
end

local function K(t: number, pose: Pose, plant: { string }?, reach: any?, ease: string?): any
	return { t = t, pose = pose, plant = plant, reach = support(pose, plant, reach), ease = ease }
end
local function ph(duration: number, keys: { any }, overlay: any?, air: boolean?): any
	return { duration = duration, keys = keys, overlay = overlay, air = air }
end
-- the reach spots raised by y (unit studs): a landing limb planted just before touchdown
local function lifted(reach: { [string]: Vector3 }, y: number, only: { string }?): { [string]: Vector3 }
	local out = {}
	for tag, v in reach do
		out[tag] = v
	end
	for _, tag in only or ALL do
		out[tag] = (out[tag] or Vector3.zero) + V(0, y, 0)
	end
	return out
end

local SWAP = { FL = "FR", FR = "FL", BL = "BR", BR = "BL" }
local function mirrorKeys(keys: { any }): { any }
	local out = {}
	for _, k in keys do
		local plant, reach
		if k.plant then
			plant = {}
			for _, tag in k.plant do
				table.insert(plant, SWAP[tag])
			end
		end
		if k.reach then
			reach = {}
			for tag, v in k.reach do
				reach[SWAP[tag]] = V(-v.X, v.Y, v.Z)
			end
		end
		table.insert(out, { t = k.t, pose = mirror(k.pose), plant = plant, reach = reach, ease = k.ease })
	end
	return out
end

-- a held pose trembles: u0..u1 window, amplitude in rad
local function tremble(u0: number, u1: number, amp: number, hz: number?)
	return function(u: number, secs: number, _): Pose
		local k = smooth(u0, u0 + (u1 - u0) * 0.25, u) * (1 - smooth(u0 + (u1 - u0) * 0.8, u1, u))
		local f = (hz or 9) * TAU
		return {
			JointRoot = R(-0.5 * amp * k * (0.5 + 0.5 * math.sin(secs * f * 0.8)), 0.4 * amp * k * math.sin(secs * f), 0, 0.5 * amp * k * math.sin(secs * f * 0.7 + 1), 0.4 * amp * k * math.sin(secs * f * 1.1 + 2)),
			JointSpine = A(0.3 * amp * k * math.sin(secs * f * 1.3 + 0.5), 0, 0.3 * amp * k * math.sin(secs * f * 0.9)),
			JointHead = A(0.5 * amp * k * math.sin(secs * f * 1.7), 0.4 * amp * k * math.sin(secs * f * 1.2 + 1)),
			JointJaw = A(-0.6 * amp * k * math.max(0, math.sin(secs * f * 1.5))),
		}
	end
end

local function chain(a: any?, b: any?): any?
	if not a then
		return b
	elseif not b then
		return a
	end
	return function(u: number, secs: number, input: any): Pose
		local out = a(u, secs, input)
		for j, cf in b(u, secs, input) do
			out[j] = (out[j] or I) * cf
		end
		return out
	end
end

-- One decelerating ("out") move split across a phase boundary: the head runs the first h of
-- `total` seconds (to x1 of the way), the tail the rest, on the same curve, so the speed carries
-- straight over the boundary instead of easing to a stop and starting again. Returns the two
-- ease names and x1 (mix the end pose by x1 for the boundary key).
local SPLIT_EASE: { [string]: (number) -> number } = {}
local function splitOut(h: number, total: number): (string, string, number)
	local s1 = math.clamp(h / total, 0.01, 0.99)
	local x1 = 1 - (1 - s1) ^ 2
	local name = string.format("split%.4f", s1)
	SPLIT_EASE[name .. "a"] = function(a)
		local t = a * s1
		return (1 - (1 - t) ^ 2) / x1
	end
	SPLIT_EASE[name .. "b"] = function(a)
		local t = s1 + a * (1 - s1)
		return ((1 - (1 - t) ^ 2) - x1) / (1 - x1)
	end
	return name .. "a", name .. "b", x1
end

--------------------------------------------------------------------------------
-- Base poses

local STAND = mk({ root = { 0, -0.03 }, head = { -0.06 }, jaw = 0.07, brow = -0.12, beard = 0.05, mane = { 0.04, 0.06, 0.08 } })
-- ready: low, fists wide, brow down
local RDY = mk({ root = { -0.3, -0.05 }, spine = { -0.04 }, head = { -0.12 }, jaw = 0.14, brow = -0.2, beard = 0.04, mane = { 0.1, 0.14, 0.18 } })

local moves: { [string]: { [string]: Phase } } = {}
local variants: { [string]: { [string]: { [string]: Phase } } } = {}

-- A skid-and-turn (a rush or leap that arrived with the target out of reach): the feet plant and
-- brake, the body swings round toward the target with the head leading and the hips last, one
-- arm steps across, then it settles. d = +1 turns right (the target on its right), -1 left; the
-- server turns the root over the phase, so the yaws here are only the lead over it.
local function skidTurn(dur: number, d: number, start: Pose, plant: { string }, reach: any, fz: number, hz: number, by: number, bp: number): Phase
	local brake = mk({ root = { by, bp, 0, -0.12 * d, -0.05 * d }, spine = { 0.04, -0.3 * d }, head = { 0.1, -0.42 * d }, jaw = 0.55, brow = -0.3, beard = 0.4, mane = { -0.25, -0.2, -0.15 } })
	local step = { 0.75, 0.15, -0.35 * d, 0.7, 0.1, 0.4 }
	local swing = mk({ root = { -0.6, 0.03, 0, -0.08 * d, 0.05 * d }, spine = { -0.02, -0.22 * d }, head = { -0.05, -0.22 * d }, jaw = 0.4, brow = -0.35, beard = 0.15, mane = { 0.15, 0.2, 0.25 }, L = if d > 0 then step else nil, R = if d < 0 then step else nil })
	local settle = mk({ root = { -0.45, -0.06, 0, -0.03 * d }, spine = { -0.03, -0.06 * d }, head = { -0.12, -0.08 * d }, jaw = 0.2, brow = -0.25, beard = 0.08, mane = { 0.08, 0.12, 0.16 } })
	local spot = paws(fz, hz, 0.4, 0.3)
	-- the limbs not planted at the start reach for raised spots first (a drawn-back fist aimed
	-- straight at the ground swung 1 stud through it)
	local planted: { [string]: boolean } = {}
	for _, tag in plant do
		planted[tag] = true
	end
	local free = {}
	for _, tag in ALL do
		if not planted[tag] then
			table.insert(free, tag)
		end
	end
	return ph(dur, {
		K(0, start, plant, reach),
		K(0.1, mix(start, brake, 0.4), ALL, lifted(spot, 0.7, free), "h1,0.8"),
		K(0.22, brake, ALL, spot, "h0.8,0"),
		K(0.5, swing, if d > 0 then SUP_L else SUP_R, spot, "inOut"),
		K(0.75, settle, ALL, spot, "inOut"),
		K(1, RDY, ALL, spot, "inOut"),
	})
end

--------------------------------------------------------------------------------
-- ClubSwing / Backhand / ThunderPound: the combo. Each ends on the ready pose the next
-- windup starts from. ClubSwing: right arm over the head, a diagonal sweep right to left;
-- Backhand is its mirror (left arm), from ClubSwing's end; ThunderPound starts from
-- Backhand's end.

-- (the loaded arm folded high: hanging back with the elbow at 1.0 the fist went 0.8 into the ground)
local CS_LOAD = mk({ root = { -0.5, -0.03, 0, -0.35 }, spine = { 0.05, -0.25 }, head = { -0.1, 0.2 }, jaw = 0.2, brow = -0.25, beard = 0.1, mane = { 0.15, 0.2, 0.25 }, R = { 0.35, 0.4, 0, 1.7, 0.3, 0.4 } })
local CS_RAISE = mk({ root = { -0.15, 0.0, 0, -0.6 }, spine = { 0.0, -0.3 }, head = { 0.2, 0.25 }, jaw = 0.5, brow = 0.12, beard = -0.15, mane = { 0.4, 0.45, 0.5 }, R = { 2.8, 0.45, 0, 0.5, -0.3, 0.9 } })
-- (the head stays up and the arm passes low and wide across the front: with the head down and the
-- arm across at chin height the forearm went 1.8 studs through the jaw and 2.6 through the beard)
local CS_CONTACT = mk({ root = { -0.45, -0.1, 0, 0.55 }, spine = { -0.1, 0.35 }, head = { 0.1, -0.3 }, jaw = 0.25, brow = -0.3, beard = 0.0, mane = { -0.05, 0.0, 0.05 }, R = { 0.6, 0.4, 0.55, 0.15, 0.2, 0 } })
local CS_THROUGH = mk({ root = { -0.5, -0.12, 0, 0.8 }, spine = { -0.15, 0.5 }, head = { -0.2, -0.4 }, jaw = 0.15, brow = -0.3, beard = 0.3, mane = { -0.15, -0.1, 0 }, R = { 0.6, -0.05, 1.1, 0.0, 0.2, 0 } })
-- chain-ready: on all four fists, still wound round to the left from the blow; the next blow's arm
-- lifts in its own windup (with the arm already raised here, a backhand or pound started from idle
-- popped 83 degrees in its first frame, and the two arms swapping plant in the club's 0.1 s recover
-- tail stepped 50)
local CHAIN_READY = mk({ root = { -0.4, -0.05, 0, 0.3 }, spine = { -0.05, 0.22 }, head = { -0.12, -0.15 }, jaw = 0.2, brow = -0.25, beard = 0.1, mane = { 0.05, 0.1, 0.15 } })

-- The blow carries through. Intent: the club drags the whole torso round after the hit, the arm
-- sweeps on past the target low across the body and only then slows (no dead stop after
-- contact), then the fist folds back and plants while the free arm lifts for the next blow.
-- Beats (club 0.80 windup, 0.12 active, 0.33 pose recover): load 0-0.16 s, the arm over the
-- head by 0.50 (the read), the swing down accelerating into contact at 0.80; one decelerating
-- sweep contact -> overshoot over 0.26 s spanning the active beat (`splitOut`), the forearm
-- folding as it slows; the fist swings back and reaches down to plant by 1.17 while the free
-- arm lifts, chain-ready at 1.25.
local CS_OVER = mk({ root = { -0.55, -0.13, 0, 0.7 }, spine = { -0.17, 0.5 }, head = { 0.2, -0.45 }, jaw = 0.15, brow = -0.3, beard = 0.0, mane = { -0.22, -0.16, -0.06 }, R = { 0.15, 0.5, 1.0, 0.85, 0.3, 0.2 } })
-- the forearm folds and the fist swings back above its plant spot before it reaches down: a
-- straight free arm blended toward a planted one swings through the ground
local CS_FOLD = mk({ root = { -0.46, -0.08, 0, 0.5 }, spine = { -0.1, 0.38 }, head = { -0.02, -0.28 }, jaw = 0.18, brow = -0.28, beard = 0.05, mane = { -0.1, -0.05, 0.02 }, R = { 0.0, 0.3, 0.45, 1.6, 0.1, 0.5 } })
-- the right fist reaching down to plant (raised a little) while the left lifts off for the next
-- blow (its authored elbow near the planted solve's bend: the solver takes the bend nearest the
-- authored one, and a blend from the folded 1.7 toward 0 crossed between its two bends)
local CS_PLANT = mk({ root = { -0.42, -0.07, 0, 0.42 }, spine = { -0.07, 0.3 }, head = { -0.14, -0.22 }, jaw = 0.2, brow = -0.25, beard = 0.15, mane = { 0.0, 0.05, 0.1 }, R = { -0.4, 0.2, 0, 1.1, -0.5, 0.4 } })
local CS_TOTAL = 0.2
local CS_HEAD, CS_TAIL, CS_X1 = splitOut(TIMING.ClubSwing[2], CS_TOTAL)
local function clubFollow(contact: Pose): ({ any }, { any })
	local mid = mix(contact, CS_OVER, CS_X1)
	return {
		K(0, contact, SUP_R, R_LOW),
		K(1, mid, SUP_R, R_LOW, CS_HEAD),
	}, {
		K(0, mid, SUP_R, R_LOW),
		K((CS_TOTAL - TIMING.ClubSwing[2]) / TIMING.ClubSwing[3], CS_OVER, SUP_R, R_LOW, CS_TAIL),
		-- the return swings through the fold without stopping and the fist comes down on its spot;
		-- the body has settled by the next windup
		K(0.56, CS_FOLD, SUP_R, R_LOW, "inOut"),
		K(0.88, CHAIN_READY, ALL, R_LOW, "inOut"),
		K(1, CHAIN_READY, ALL, R_LOW),
	}
end
local CS_ACTIVE, CS_RECOVER = clubFollow(CS_CONTACT)

moves.ClubSwing = {
	-- Intent: the weight rocks onto the left fist and the right one peels off the ground, the body
	-- winds right as the arm comes up over the head (the read, slowing near the top but never
	-- parked), then the hips lead the unwind and the club comes down across, fastest at contact.
	-- Beats (0.80 s): peel 0-0.11, coil by 0.26, overhead by 0.50, contact at 0.80.
	windup = ph(TIMING.ClubSwing[1], {
		K(0, RDY, ALL, R_RDY),
		K(0.14, mix(RDY, CS_LOAD, 0.35), ALL, lifted(R_LOW, 0.6, { "FR" }), "inOut"),
		K(0.32, CS_LOAD, SUP_R, R_LOW, "h1,0.5"),
		K(0.62, CS_RAISE, SUP_R, R_LOW, "h0.8,0.25"),
		K(1, CS_CONTACT, SUP_R, R_LOW, "h0.25,2"), -- still moving at contact (no held frame)
	}),
	active = ph(TIMING.ClubSwing[2], CS_ACTIVE),
	recover = ph(TIMING.ClubSwing[3], CS_RECOVER),
}
-- Backhand: the mirror, begun from the chain-ready pose
do
	moves.Backhand = {
		-- from the chain-ready crouch the left fist peels up as the body winds back left, over the
		-- head by 0.30 s, down across by 0.60
		windup = ph(TIMING.Backhand[1], mirrorKeys({
			K(0, mirror(CHAIN_READY), ALL, R_LOW),
			K(0.16, mix(mirror(CHAIN_READY), CS_LOAD, 0.4), ALL, lifted(R_LOW, 0.6, { "FR" }), "h0.6,1"),
			K(0.5, CS_RAISE, SUP_R, R_LOW, "h1,0.25"),
			K(1, CS_CONTACT, SUP_R, R_LOW, "h0.25,2"),
		})),
		active = ph(TIMING.Backhand[2], mirrorKeys(CS_ACTIVE)),
		recover = ph(TIMING.Backhand[3], mirrorKeys(CS_RECOVER)),
	}
end
local BACKHAND_END = mirror(CHAIN_READY) -- the pose Backhand's recover ends on

-- ThunderPound: both fists over the head, driven down together at 18 studs ahead.
local POUND_REACH = paws(-3.0, 0.55, 0.9, 0.3) -- fists land (unit) at wrist z -4.7
local PD_RISE = mk({ root = { -0.1, 0.95 }, spine = { 0.1 }, head = { 0.25 }, jaw = 0.5, brow = 0.15, beard = -0.1, mane = { 0.3, 0.35, 0.4 }, L = { 2.8, 0.35, 0, 0.3, -0.2, 0.7 }, R = { 2.8, 0.35, 0, 0.3, -0.2, 0.7 } })
local PD_PEAK = mk({ root = { 0.0, 1.1 }, spine = { 0.18 }, head = { 0.35 }, jaw = 0.7, brow = 0.2, beard = -0.2, mane = { 0.45, 0.5, 0.55 }, L = { 3.1, 0.3, 0, 0.45, -0.3, 0.9 }, R = { 3.1, 0.3, 0, 0.45, -0.3, 0.9 } })
-- (nose-down pitch -0.3 folded the planted elbows back and laid the elbow tufts 1.4 under the floor)
local PD_CONTACT = mk({ root = { -0.5, -0.27 }, spine = { -0.1 }, head = { -0.2 }, jaw = 0.1, brow = -0.35, beard = 0.2, mane = { -0.1, -0.05, 0.0 }, L = { 0, -0.4 }, R = { 0, -0.4 } })
local PD_DEEP = mk({ root = { -0.42, -0.25 }, spine = { -0.14 }, head = { -0.2 }, jaw = 0.05, brow = -0.4, beard = 0.3, mane = { -0.2, -0.15, -0.1 }, L = { 0, -0.4 }, R = { 0, -0.4 } })
local PD_LOW = mk({ root = { -0.45, -0.24 }, spine = { -0.1 }, head = { -0.2, 0, 0 }, jaw = 0.2, brow = -0.3, beard = 0.15, mane = { 0, 0.05, 0.1 }, L = { 0, 0.25 }, R = { 0, 0.25 } })
moves.ThunderPound = {
	windup = ph(TIMING.ThunderPound[1], {
		K(0, BACKHAND_END, ALL, R_LOW),
		K(0.35, PD_RISE, HIND, R_REAR, "h0.3,1"),
		K(0.55, PD_PEAK, HIND, R_REAR, "inOut"),
		K(1, PD_CONTACT, ALL, POUND_REACH, "in"),
	}, tremble(0.4, 0.62, 0.03)),
	active = ph(TIMING.ThunderPound[2], {
		K(0, PD_CONTACT, ALL, POUND_REACH),
		K(0.3, PD_DEEP, ALL, POUND_REACH, "out"),
		K(1, PD_LOW, ALL, POUND_REACH, "inOut"),
	}),
	recover = ph(TIMING.ThunderPound[3], {
		K(0, PD_LOW, ALL, POUND_REACH),
		K(0.2, PD_LOW, ALL, POUND_REACH),
		K(0.55, RDY, ALL, R_LOW, "inOut"),
		K(1, STAND, ALL, nil, "inOut"),
	}),
}

--------------------------------------------------------------------------------
-- BodySlam: rear up tall, lean back, then fall full length forward along the lane.

local BS_CROUCH = mk({ root = { -0.55, -0.03 }, spine = { -0.1 }, head = { -0.15 }, jaw = 0.3, brow = -0.3, beard = 0.1, mane = { 0.1, 0.15, 0.2 } })
local BS_TALL = mk({ root = { -0.1, 1.25 }, spine = { 0.25 }, head = { 0.4 }, jaw = 0.75, brow = 0.2, beard = -0.25, mane = { 0.5, 0.55, 0.6 }, L = { 2.2, 0.95, 0, 0.6, -0.1, 0.7 }, R = { 2.2, 0.95, 0, 0.6, -0.1, 0.7 } })
local BS_TIP = mk({ root = { -0.1, 1.35 }, spine = { 0.3 }, head = { 0.45 }, jaw = 0.85, brow = 0.25, beard = -0.3, mane = { 0.55, 0.6, 0.65 }, L = { 2.6, 0.8, 0, 0.4, -0.1, 0.8 }, R = { 2.6, 0.8, 0, 0.4, -0.1, 0.8 } })
-- (the hind legs fold as they leave the ground: hanging straight from the dropped hips they
-- went 1.3-2.2 studs under it through the fall and the prone slide)
local BS_FALL = mk({ root = { -0.4, -0.3, -0.2 }, spine = { -0.3 }, head = { 0.35 }, jaw = 0.4, brow = -0.2, beard = -0.1, mane = { -0.3, -0.2, -0.1 }, L = { 1.9, 0.3, 0, 0.1, 0.1, 0.4 }, R = { 1.9, 0.3, 0, 0.1, 0.1, 0.4 }, BL = { -0.3, -0.8, 0.4 }, BR = { -0.3, -0.8, 0.4 } })
-- (head lifted and the beard swung back: lying on the chest with the head at 0.3 the beard tip lay 1.2 under)
local BS_PRONE = mk({ root = { -0.56, -0.6, -0.4 }, spine = { -0.2 }, head = { 0.55 }, jaw = 0.4, brow = -0.15, beard = -0.35, mane = { -0.6, -0.5, -0.4 }, L = { 1.7, -0.2, 0, 0.0, 0.2, 0.3 }, R = { 1.7, -0.2, 0, 0.0, 0.2, 0.3 }, BL = { -0.7, -0.5, 0.5 }, BR = { -0.7, -0.5, 0.5 } })
local BS_SPLAT = mk({ root = { -0.58, -0.62, -0.4 }, spine = { -0.25 }, head = { 0.55 }, jaw = 0.45, brow = -0.1, beard = -0.35, mane = { -0.7, -0.6, -0.5 }, L = { 1.6, -0.15, 0, 0.0, 0.2, 0.5 }, R = { 1.6, -0.15, 0, 0.0, 0.2, 0.5 }, BL = { -0.75, -0.55, 0.5 }, BR = { -0.75, -0.55, 0.5 } })
local BS_FWD = paws(-4.9, 0, 0.3, 0) -- fists lie flat out in front of the shoulders (closer in, the elbows bent DOWN into the floor)
-- pushing up off the fists, the legs drawn in under the hips before they plant
local BS_PUSH = mk({ root = { -0.2, -0.4 }, spine = { -0.1 }, head = { 0.1 }, jaw = 0.4, brow = -0.2, beard = 0.3, mane = { 0.0, 0.1, 0.15 }, BL = { -0.1, -0.9, 0.5 }, BR = { -0.1, -0.9, 0.5 } })
moves.BodySlam = {
	windup = ph(TIMING.BodySlam[1], {
		K(0, RDY, ALL, R_RDY),
		K(0.2, BS_CROUCH, ALL, R_LOW, "out"),
		K(0.62, BS_TALL, HIND, R_REAR, "inOut"),
		K(0.88, BS_TIP, HIND, R_REAR, "out"),
		K(1, BS_TIP, HIND, R_REAR),
	}, tremble(0.5, 0.95, 0.03)),
	active = ph(TIMING.BodySlam[2], {
		K(0, BS_TIP, HIND, R_REAR),
		-- the feet push off and come up (planted, raised) before they fold: swung straight from the
		-- planted pose they dug 0.7 into the floor as the body tipped
		K(0.18, mix(BS_TIP, BS_FALL, 0.25), HIND, lifted(R_REAR, 0.6, HIND), "h0.5,1"),
		K(0.5, BS_FALL, NONE, nil, "h1,1.4"),
		K(0.82, BS_PRONE, FRONT, lifted(BS_FWD, 0.9, FRONT), "in"), -- the fists reach for the ground
		K(1, BS_SPLAT, FRONT, BS_FWD, "out"),
	}, nil, true),
	recover = ph(TIMING.BodySlam[3], {
		K(0, BS_SPLAT, FRONT, BS_FWD),
		K(0.25, BS_SPLAT, FRONT, BS_FWD),
		K(0.65, BS_PUSH, FRONT, paws(-1.5, 0, 0.3, 0), "inOut"),
		K(1, RDY, ALL, R_LOW, "inOut"),
	}, nil, true),
}

--------------------------------------------------------------------------------
-- SkyfallSlam and Judgment: deep crouch, a quiver, a spring, fists overhead at the apex,
-- landing on both fists with the knees absorbing.

local function leap(crouchY: number, apexArms: number, landReach: any, landY: number?)
	local crouch = mk({ root = { crouchY, -0.03 }, spine = { -0.12 }, head = { -0.2 }, jaw = 0.25, brow = -0.35, beard = 0.15, mane = { 0.1, 0.15, 0.2 } })
	local coil = mk({ root = { crouchY - 0.2, -0.06 }, spine = { -0.16 }, head = { -0.25 }, jaw = 0.3, brow = -0.4, beard = 0.2, mane = { 0.0, 0.05, 0.1 } })
	local spring = mk({ root = { 0.2, 0.2 }, spine = { 0.18 }, head = { 0.2 }, jaw = 0.7, brow = 0.1, beard = -0.2, mane = { 0.4, 0.45, 0.5 }, L = { apexArms - 1.0, 0.3, 0, 0.1, 0.0, 0.7 }, R = { apexArms - 1.0, 0.3, 0, 0.1, 0.0, 0.7 }, BL = { 0.3, 0.1, 0 }, BR = { 0.3, 0.1, 0 } })
	local apex = mk({ root = { 0.5, 0.35 }, spine = { 0.25 }, head = { 0.3 }, jaw = 0.9, brow = 0.2, beard = -0.35, mane = { 0.5, 0.55, 0.6 }, L = { apexArms, 0.25, 0, 0.35, -0.2, 0.9 }, R = { apexArms, 0.25, 0, 0.35, -0.2, 0.9 }, BL = { 0.5, -0.5, 0.3 }, BR = { 0.5, -0.5, 0.3 } })
	-- (the arms already reach down for the ground: forward at 1.3 they swung 1.6 rad in 0.1 s to plant)
	local drop = mk({ root = { 0.3, -0.5 }, spine = { -0.2 }, head = { -0.2 }, jaw = 0.3, brow = -0.4, beard = 0.3, mane = { -0.1, 0.0, 0.1 }, L = { 0.45, 0.25, 0, 0.35, 0.0, 0.3 }, R = { 0.45, 0.25, 0, 0.35, 0.0, 0.3 }, BL = { 0.5, -0.5, 0.2 }, BR = { 0.5, -0.5, 0.2 } })
	local land = mk({ root = { landY or -1.1, -0.1 }, spine = { -0.2 }, head = { -0.2 }, jaw = 0.1, brow = -0.45, beard = 0.4, mane = { -0.25, -0.2, -0.1 } })
	-- the contact itself, the legs still long: the body compresses into `land` after it
	local touch = mk({ root = { -0.45, -0.12 }, spine = { -0.16 }, head = { 0.05 }, jaw = 0.2, brow = -0.4, beard = 0.2, mane = { 0.1, 0.15, 0.2 } })
	-- the first frames after contact, already sinking (the flight ends on this, so the server's last
	-- arc frames and the hand-off see the limbs planted)
	local sink = mix(touch, land, 0.25)
	local settle = mk({ root = { -0.8, -0.08 }, spine = { -0.12 }, head = { -0.18 }, jaw = 0.25, brow = -0.35, beard = 0.2, mane = { 0.0, 0.05, 0.1 }, L = { 0, 0.3 }, R = { 0, 0.3 } })
	return { crouch = crouch, coil = coil, spring = spring, apex = apex, drop = drop, land = land, settle = settle, touch = touch, sink = sink }
end

do
	local s = leap(-0.85, 3.0, nil, -1.0)
	-- the hind feet land forward under the hips: further back the thighs sank 0.6 studs in the crouch
	local reach = paws(-1.2, 0.2, 0.5, 0.3)
	local LOWH = paws(-1.0, 0.15, 0.3, 0.3)
	moves.SkyfallSlam = {
		windup = ph(TIMING.SkyfallSlam[1], {
			K(0, RDY, ALL, R_RDY),
			K(0.35, s.crouch, ALL, LOWH, "inOut"),
			K(0.78, s.coil, ALL, LOWH, "inOut"),
			K(1, s.spring, HIND, R_REAR, "h0.4,1.4"),
		}, tremble(0.4, 0.85, 0.035, 11)),
		active = ph(TIMING.SkyfallSlam[2], {
			K(0, s.spring, HIND, R_REAR),
			K(0.1, mix(s.spring, s.apex, 0.25), NONE, nil, "out"),
			K(0.45, s.apex, NONE, nil, "out"),
			K(0.78, s.drop, NONE, nil, "inOut"),
			-- touchdown on long legs, still coming down (no held contact frame) ...
			K(0.93, s.touch, ALL, reach, "h0.5,1.2"),
			K(1, s.sink, ALL, reach, "h1.2,1"),
		}, nil, true),
		-- ... then the whole body compresses through the knees and fists (the land dip), settles
		-- and rises. Intent: 30 studs of ape coming down; the floor takes it.
		recover = ph(TIMING.SkyfallSlam[3], {
			K(0, s.sink, ALL, reach),
			K(0.13, s.land, ALL, reach, "h1.6,0"),
			K(0.3, s.land, ALL, reach, "inOut"),
			K(0.6, s.settle, ALL, reach, "inOut"),
			K(1, RDY, ALL, R_LOW, "inOut"),
		}),
	}
	-- (a shallower landing crouch: at -1.1 the planted forearms' elbow tufts lay 1.3 under the floor)
	local j = leap(-0.9, 3.1, nil, -0.85)
	local jreach = paws(-1.3, 0.2, 0.5, 0.3)
	moves.Judgment = {
		windup = ph(TIMING.Judgment[1], {
			K(0, RDY, ALL, R_RDY),
			K(0.2, j.crouch, ALL, LOWH, "inOut"),
			K(0.72, mix(j.crouch, j.coil, 0.7), ALL, LOWH, "inOut"),
			K(0.88, j.coil, ALL, LOWH, "inOut"),
			K(1, j.spring, HIND, R_REAR, "h0.3,1.4"),
		}, chain(tremble(0.3, 0.93, 0.05, 8), function(u: number, secs: number, _): Pose
			-- a quiver that builds into shaking before the spring
			local k = smooth(0.62, 0.9, u) * (1 - smooth(0.93, 0.97, u))
			local f = secs * TAU * 14
			return { JointRoot = R(-0.05 * k * math.abs(math.sin(f * 0.5)), 0.03 * k * math.sin(f), 0, 0.04 * k * math.sin(f * 0.7), 0.05 * k * math.sin(f * 1.3)), JointHead = A(0.06 * k * math.sin(f * 1.1)) }
		end)),
		active = ph(TIMING.Judgment[2], {
			K(0, j.spring, HIND, R_REAR),
			K(0.08, mix(j.spring, j.apex, 0.2), NONE, nil, "out"),
			K(0.5, j.apex, NONE, nil, "out"),
			K(0.8, j.drop, NONE, nil, "inOut"),
			K(0.94, j.touch, ALL, jreach, "h0.5,1.2"),
			K(1, j.sink, ALL, jreach, "h1.2,1"),
		}, nil, true),
		recover = ph(TIMING.Judgment[3], {
			K(0, j.sink, ALL, jreach),
			K(0.08, j.land, ALL, jreach, "h1.6,0"),
			K(0.7, mix(j.land, j.settle, 0.2), ALL, jreach, "inOut"),
			K(0.9, j.settle, ALL, jreach, "inOut"),
			K(1, RDY, ALL, R_LOW, "inOut"),
		}),
	}

	-- SkyfallSweep (the arrival when the target is still in reach): a backhand from the landing
	-- crouch. The right arm comes up across the body (twisted left), then sweeps out flat to the
	-- right at belly height; the fist steps back down in the recover.
	local sload = mk({ root = { -0.75, -0.08, 0, 0.4 }, spine = { -0.08, 0.35 }, head = { 0.12, 0.1 }, jaw = 0.4, brow = -0.45, beard = 0.3, mane = { 0.05, 0.1, 0.15 }, R = { 0.6, 0.05, 0.75, 1.0, 0.2, 0.3 } })
	local scontact = mk({ root = { -0.85, -0.15, 0, -0.4 }, spine = { -0.05, -0.5 }, head = { 0.12, 0.2 }, jaw = 0.55, brow = -0.4, beard = 0.15, mane = { 0.2, 0.25, 0.3 }, R = { 0.95, 1.15, -0.5, 0.1, -0.1, 0 } })
	local sthrough = mk({ root = { -0.85, -0.18, 0, -0.5 }, spine = { -0.08, -0.65 }, head = { 0.18, 0.3 }, jaw = 0.35, brow = -0.35, beard = 0.3, mane = { 0.3, 0.35, 0.4 }, R = { 0.8, 1.4, -0.95, 0.05, -0.1, 0.1 } })
	local sdown = mk({ root = { -0.75, -0.1, 0, -0.3 }, spine = { -0.06, -0.25 }, head = { -0.1, 0.15 }, jaw = 0.3, brow = -0.3, beard = 0.2, mane = { 0.1, 0.15, 0.2 }, R = { 0.95, 0.8, -0.4, 1.0, 0.1, 0.4 } })
	local slift = mix(s.land, sload, 0.25)
	slift.JointLegFR, slift.JointElbowFR, slift.JointWristFR = A(0.8, 0.2, 0), A(1.3), A(0.3) -- elbow folded: the fist clears the ground
	local SS_HEAD, SS_TAIL, SS_X1 = splitOut(TIMING.SkyfallSweep[2], 0.26)
	local ssMid = mix(scontact, sthrough, SS_X1)
	moves.SkyfallSweep = {
		windup = ph(TIMING.SkyfallSweep[1], {
			K(0, s.sink, ALL, reach),
			K(0.2, slift, ALL, lifted(reach, 0.4, { "FR" }), "h1.4,0.4"), -- the body compresses, the fist lifts off before the twist
			K(0.5, sload, SUP_R, reach, "out"),
			K(1, scontact, SUP_R, reach, "h0.3,1.5"),
		}),
		active = ph(TIMING.SkyfallSweep[2], {
			K(0, scontact, SUP_R, reach),
			K(1, ssMid, SUP_R, reach, SS_HEAD),
		}),
		recover = ph(TIMING.SkyfallSweep[3], {
			K(0, ssMid, SUP_R, reach),
			K((0.26 - TIMING.SkyfallSweep[2]) / TIMING.SkyfallSweep[3], sthrough, SUP_R, reach, SS_TAIL),
			K(0.4, sdown, SUP_R, reach, "inOut"),
			K(0.6, mix(sdown, RDY, 0.5), ALL, reach, "in"), -- the fist steps down
			K(1, RDY, ALL, reach, "inOut"),
		}),
	}
	-- the miss: rise out of the landing crouch and turn to find the target
	moves.SkyfallSlamSkid = { recover = skidTurn(TIMING.SkyfallSlamSkid[3], 1, s.sink, ALL, reach, -1.2, 0.2, -0.95, 0.0) }
	variants.SkyfallSlamSkid = { A = moves.SkyfallSlamSkid, L = { recover = skidTurn(TIMING.SkyfallSlamSkid[3], -1, s.sink, ALL, reach, -1.2, 0.2, -0.95, 0.0) } }
end

--------------------------------------------------------------------------------
-- ThunderRush and Bound, the rush's arrival (RushSwipe) and its skid-and-turn after a miss.
-- Landings: the limbs that land are planted (solved) a moment BEFORE touchdown with their spots
-- raised (`lifted`), so the free-to-planted switch blends over the descent instead of popping
-- in the last frames, and the body compresses after contact, in the recover.

do
	local hunker = mk({ root = { -0.88, -0.04 }, spine = { -0.2 }, head = { -0.2 }, jaw = 0.25, brow = -0.45, beard = 0.15, mane = { 0.1, 0.15, 0.2 } })
	local ready = mk({ root = { -0.92, -0.05, 0.1 }, spine = { -0.22 }, head = { -0.2 }, jaw = 0.3, brow = -0.5, beard = 0.1, mane = { 0.2, 0.25, 0.3 } })
	local launch = mk({ root = { -0.7, -0.05 }, spine = { -0.1 }, head = { -0.2 }, jaw = 0.4, brow = -0.4, beard = 0, mane = { 0.4, 0.45, 0.5 } })
	local RW = paws(-1.3, 0.6, 0.4, 0.3)
	local from = rig.plant(table.clone(launch), HIND, RW)
	-- the last strides: the right arm draws back and out, the left fist and both feet brace, the
	-- body twists right and sinks while the head stays on the target. RushSwipe and the skid start
	-- from this pose.
	local RUSH_END = mk({ root = { -0.85, -0.1, 0, -0.35 }, spine = { -0.12, -0.25 }, head = { 0.05, 0.4 }, jaw = 0.55, brow = -0.45, beard = 0.3, mane = { 0.5, 0.55, 0.6 }, R = { 0.8, 1.35, -0.9, 0.5, 0.0, 0.8 } })
	local SW = paws(-1.1, -0.05, 0.45, 0.3)
	local braced = rig.plant(table.clone(RUSH_END), SUP_R, support(RUSH_END, SUP_R, SW))
	local function rush(u: number, secs: number, _i: any): Pose
		-- averaged over three frames: at 95 studs/s a fist's touchdown pops an elbow in one frame
		local c, d = secs * TAU * 3.2, TAU * 3.2 / 60
		local a0, a1, a2 = gallop(c - d, 95, 3.2), gallop(c, 95, 3.2), gallop(c + d, 95, 3.2)
		local running: Pose = {}
		for name, cf in a1 do
			running[name] = (a0[name] or cf):Lerp(a2[name] or cf, 0.5):Lerp(cf, 1 / 3)
		end
		local m = smooth(0, 0.16, secs)
		local draw, e = smooth(0.42, 0.8, u), smooth(0.6, 1, u)
		for _, name in ThunderApe.JOINTS do
			local g = (from[name] or I):Lerp(running[name] or I, m)
			local w = if string.sub(name, -2) == "FR" then math.max(draw, e) else e
			running[name] = g:Lerp(braced[name] or I, w)
		end
		-- the joint blend from the stride into the brace (and from the launch into the stride) swings
		-- a limb through the ground (a fist 0.9, a foot 0.8 under): bend its middle joint to stay on it
		for _, tag in ALL do
			local leg = LEGS[tag]
			if rig.soleY(running, leg) < -0.005 then
				local hand = running[leg.foot]
				rig.solveLeg(running, leg, 1)
				if leg.front then
					running[leg.foot] = hand -- (a foot levels flat; a fist keeps its angle)
				end
			end
		end
		return running
	end
	local rushWindup = ph(TIMING.ThunderRush[1], {
		K(0, RDY, ALL, R_RDY),
		K(0.3, hunker, ALL, RW, "out"),
		K(0.82, ready, ALL, RW, "inOut"),
		K(1, launch, HIND, RW, "in"),
	}, tremble(0.3, 0.9, 0.035, 13))
	local rushActive = ph(TIMING.ThunderRush[2], { K(0, {}, NONE, nil), K(1, {}, NONE, nil) }, rush, true)
	-- no follow-up (nothing sent on arrival): the same skid-and-turn as a miss
	moves.ThunderRush = { windup = rushWindup, active = rushActive, recover = skidTurn(TIMING.ThunderRush[3], 1, RUSH_END, SUP_R, SW, -1.0, -0.05, -0.8, 0.14) }
	variants.ThunderRush = { A = moves.ThunderRush, L = { windup = rushWindup, active = rushActive, recover = skidTurn(TIMING.ThunderRush[3], -1, RUSH_END, SUP_R, SW, -1.0, -0.05, -0.8, 0.14) } }
	moves.ThunderRushSkid = { recover = skidTurn(TIMING.ThunderRushSkid[3], 1, RUSH_END, SUP_R, SW, -1.0, -0.05, -0.8, 0.14) }
	variants.ThunderRushSkid = { A = moves.ThunderRushSkid, L = { recover = skidTurn(TIMING.ThunderRushSkid[3], -1, RUSH_END, SUP_R, SW, -1.0, -0.05, -0.8, 0.14) } }

	-- RushSwipe: the run carries into the blow. From the braced last stride the arm winds further
	-- back and the hips sink, then the whole body unwinds into a flat sweep right to left at belly
	-- height (under the beard). The fist steps back down in the recover.
	local cock = mk({ root = { -0.95, -0.12, 0, -0.55 }, spine = { -0.05, -0.4 }, head = { 0.05, 0.5 }, jaw = 0.65, brow = -0.5, beard = 0.2, mane = { 0.35, 0.4, 0.45 }, R = { 0.75, 1.45, -1.1, 0.3, 0.0, 0.9 } })
	local contact = mk({ root = { -0.85, -0.2, 0, 0.4 }, spine = { -0.05, 0.5 }, head = { 0.15, -0.15 }, jaw = 0.35, brow = -0.4, beard = 0.15, mane = { -0.05, 0, 0.05 }, R = { 0.95, 0.8, 0.9, 0.0, 0.2, 0 } })
	local through = mk({ root = { -0.85, -0.25, 0, 0.55 }, spine = { -0.1, 0.65 }, head = { 0.22, -0.2 }, jaw = 0.25, brow = -0.35, beard = 0.3, mane = { -0.15, -0.1, 0 }, R = { 0.65, 0.5, 1.2, 0, 0.2, 0 } })
	local down = mk({ root = { -0.7, -0.12, 0, 0.35 }, spine = { -0.08, 0.3 }, head = { -0.1, -0.15 }, jaw = 0.3, brow = -0.3, beard = 0.2, mane = { 0.0, 0.05, 0.1 }, R = { 0.95, 0.45, 0.4, 1.0, 0.1, 0.4 } })
	-- (the swing lands AT the windup's end and its speed carries into one decelerating sweep: a
	-- held contact frame and a sharp "in" put the fist at 771 studs/s)
	local RS_HEAD, RS_TAIL, RS_X1 = splitOut(TIMING.RushSwipe[2], 0.24)
	local rsMid = mix(contact, through, RS_X1)
	moves.RushSwipe = {
		windup = ph(TIMING.RushSwipe[1], {
			K(0, RUSH_END, SUP_R, SW),
			K(0.42, cock, SUP_R, SW, "out"),
			K(1, contact, SUP_R, SW, "h0.3,1.5"),
		}),
		active = ph(TIMING.RushSwipe[2], {
			K(0, contact, SUP_R, SW),
			K(1, rsMid, SUP_R, SW, RS_HEAD),
		}),
		recover = ph(TIMING.RushSwipe[3], {
			K(0, rsMid, SUP_R, SW),
			K((0.24 - TIMING.RushSwipe[2]) / TIMING.RushSwipe[3], through, SUP_R, SW, RS_TAIL),
			K(0.4, down, SUP_R, SW, "inOut"),
			K(0.6, mix(down, RDY, 0.5), ALL, SW, "in"), -- the right fist steps down
			K(1, RDY, ALL, SW, "inOut"),
		}),
	}

	-- Bound, by the server's BoundMode (input.mode): every mode crouches, springs, hangs at the
	-- apex and lands planted-then-compressed. The lateral lean (toward the travel, after loading
	-- the far side) and the head-leading twist come from motionLayer (velocity and turn rate), so
	-- the twist of `over` happens in the air while the server turns the root.
	local BW = paws(-0.6, 0.35, 0.35, 0.3) -- the landing spots, near the ready stance (no slide after)
	local function hop(o: any): { [string]: Phase }
		local w = ph(TIMING.Bound[1], o.windup)
		w.lean = "windup"
		local a = ph(TIMING.Bound[2], o.active, nil, true)
		a.lean = "active"
		a.lead = 1.6
		local r = ph(TIMING.Bound[3], o.recover)
		return { windup = w, active = a, recover = r }
	end
	local crouch = mk({ root = { -0.8, -0.03 }, spine = { -0.14 }, head = { -0.12 }, jaw = 0.25, brow = -0.35, beard = 0.1, mane = { 0.1, 0.15, 0.2 } })
	local push = mk({ root = { -0.6, 0.04 }, spine = { -0.08 }, head = { -0.05 }, jaw = 0.4, brow = -0.3, beard = 0.0, mane = { 0.2, 0.25, 0.3 } })
	local flight = mk({ root = { 0.1, -0.2 }, spine = { -0.06 }, head = { 0.1 }, jaw = 0.45, brow = -0.2, beard = -0.3, mane = { 0.6, 0.65, 0.7 }, L = { 1.5, 0.35, 0, 0.3, 0.1, 0.4 }, R = { 1.5, 0.35, 0, 0.3, 0.1, 0.4 }, BL = { 0.6, -0.6, 0.2 }, BR = { 0.6, -0.6, 0.2 } })
	local hang = mk({ root = { 0.15, -0.12 }, spine = { -0.02 }, head = { 0.0 }, jaw = 0.5, brow = -0.15, beard = -0.2, mane = { 0.5, 0.55, 0.6 }, L = { 1.3, 0.55, 0, 0.45, 0.1, 0.5 }, R = { 1.3, 0.55, 0, 0.45, 0.1, 0.5 }, BL = { 0.7, -0.75, 0.2 }, BR = { 0.7, -0.75, 0.2 } })
	-- reaching for the ground just before touchdown, and the contact itself (the legs still long)
	-- (low enough that the planted knees stay bent: a nearly straight planted leg crosses 0 and the
	-- solver flips branch for a frame)
	local reachDown = mk({ root = { -0.3, -0.08 }, spine = { -0.05 }, head = { -0.02 }, jaw = 0.4, brow = -0.25, beard = -0.1, mane = { 0.4, 0.45, 0.5 }, BL = { 0.1, -0.45, 0.3 }, BR = { 0.1, -0.45, 0.3 } })
	local touch = mk({ root = { -0.35, -0.05 }, spine = { -0.1 }, head = { -0.1 }, jaw = 0.3, brow = -0.35, beard = 0.1, mane = { 0.2, 0.25, 0.3 } })
	local compress = mk({ root = { -0.95, -0.05 }, spine = { -0.2 }, head = { -0.22 }, jaw = 0.2, brow = -0.4, beard = 0.35, mane = { -0.2, -0.15, -0.1 } })
	local landing = {
		recover = {
			K(0, touch, ALL, BW),
			K(0.4, compress, ALL, BW, "out"),
			K(1, RDY, ALL, BW, "inOut"),
		},
	}
	-- flank: a side hop, lower arc, the body leaning into the travel
	local flank = hop({
		windup = {
			K(0, RDY, ALL, R_RDY),
			K(0.75, crouch, ALL, BW, "out"),
			K(1, push, ALL, BW, "in"),
		},
		active = {
			K(0, push, ALL, BW),
			K(0.14, mix(push, flight, 0.5), NONE, nil, "out"),
			K(0.42, flight, NONE, nil, "inOut"),
			K(0.62, hang, NONE, nil, "inOut"),
			K(0.85, reachDown, ALL, lifted(BW, 0.45), "inOut"),
			K(1, touch, ALL, BW, "in"),
		},
		recover = landing.recover,
	})
	-- over: the highest arc, past the player. A counter-rise, the deepest crouch, the arms flung up
	-- at the spring, a tuck and a long hang at the apex (the server turns the root to face back),
	-- then the legs reach for the ground.
	local overLook = mk({ root = { -0.2, 0.02 }, spine = { 0.02 }, head = { 0.15 }, jaw = 0.3, brow = -0.2, beard = 0.0, mane = { 0.15, 0.2, 0.25 } })
	local overCrouch = mk({ root = { -1.0, -0.04 }, spine = { -0.18 }, head = { 0.0 }, jaw = 0.35, brow = -0.45, beard = 0.15, mane = { 0.05, 0.1, 0.15 } })
	local overSpring = mk({ root = { -0.75, 0.12 }, spine = { 0.0 }, head = { 0.1 }, jaw = 0.55, brow = -0.2, beard = -0.1, mane = { 0.3, 0.35, 0.4 }, L = { 0.9, 0.3, 0, 0.6, 0, 0.5 }, R = { 0.9, 0.3, 0, 0.6, 0, 0.5 } })
	local overLaunch = mk({ root = { 0.2, 0.3 }, spine = { 0.15 }, head = { 0.25 }, jaw = 0.75, brow = 0.1, beard = -0.3, mane = { 0.55, 0.6, 0.65 }, L = { 2.4, 0.5, 0, 0.4, -0.1, 0.7 }, R = { 2.4, 0.5, 0, 0.4, -0.1, 0.7 }, BL = { -0.5, 0.3, 0.5 }, BR = { -0.5, 0.3, 0.5 } })
	local overTuck = mk({ root = { 0.35, 0.05 }, spine = { -0.1 }, head = { 0.05 }, jaw = 0.6, brow = -0.1, beard = -0.25, mane = { 0.45, 0.5, 0.55 }, L = { 1.2, 1.05, 0, 0.5, 0, 0.5 }, R = { 1.2, 1.05, 0, 0.5, 0, 0.5 }, BL = { 0.65, -0.8, 0.4 }, BR = { 0.65, -0.8, 0.4 } })
	local overHang = mk({ root = { 0.2, -0.08 }, spine = { -0.12 }, head = { -0.1 }, jaw = 0.55, brow = -0.25, beard = -0.15, mane = { 0.35, 0.4, 0.45 }, L = { 0.95, 0.75, 0, 0.45, 0, 0.6 }, R = { 0.95, 0.75, 0, 0.45, 0, 0.6 }, BL = { 0.4, -0.5, 0.3 }, BR = { 0.4, -0.5, 0.3 } })
	local over = hop({
		windup = {
			K(0, RDY, ALL, R_RDY),
			K(0.2, overLook, ALL, BW, "inOut"),
			K(0.7, overCrouch, ALL, BW, "inOut"),
			K(1, overSpring, HIND, BW, "in"),
		},
		active = {
			K(0, overSpring, HIND, BW),
			K(0.15, overLaunch, NONE, nil, "out"),
			K(0.38, overTuck, NONE, nil, "inOut"),
			K(0.6, overHang, NONE, nil, "inOut"),
			K(0.82, reachDown, ALL, lifted(BW, 0.5), "inOut"),
			K(1, touch, ALL, BW, "in"),
		},
		recover = landing.recover,
	})
	-- back: a retreat hop away from the player, shoved off the knuckles. The weight rocks onto the
	-- fists, the arms drive the body back and up, the feet reach for the ground first and the
	-- fists land with them.
	local backLoad = mk({ root = { -0.7, -0.1 }, spine = { -0.16 }, head = { 0.05 }, jaw = 0.35, brow = -0.4, beard = 0.1, mane = { 0.1, 0.15, 0.2 } })
	local backShove = mk({ root = { -0.45, 0.12 }, spine = { 0.06 }, head = { 0.1 }, jaw = 0.5, brow = -0.3, beard = 0.0, mane = { -0.05, 0.0, 0.05 } })
	local backOff = mk({ root = { -0.15, 0.3 }, spine = { 0.1 }, head = { 0.05 }, jaw = 0.5, brow = -0.3, beard = 0.1, mane = { -0.2, -0.15, -0.1 }, L = { 0.6, 0.3, 0, 0.1, 0.2, 0.4 }, R = { 0.6, 0.3, 0, 0.1, 0.2, 0.4 }, BL = { -0.1, 0.2, 0.1 }, BR = { -0.1, 0.2, 0.1 } })
	local backFloat = mk({ root = { 0.0, 0.3 }, spine = { 0.15 }, head = { 0.0 }, jaw = 0.45, brow = -0.3, beard = 0.05, mane = { -0.1, -0.05, 0.0 }, L = { 0.9, 0.5, 0, 0.4, 0, 0.5 }, R = { 0.9, 0.5, 0, 0.4, 0, 0.5 }, BL = { -0.2, 0.3, 0.2 }, BR = { -0.2, 0.3, 0.2 } })
	local backReach = mk({ root = { -0.1, 0.26 }, spine = { 0.1 }, head = { -0.02 }, jaw = 0.4, brow = -0.3, beard = 0.1, mane = { 0.05, 0.1, 0.15 }, L = { 1.0, 0.4, 0, 0.6, 0, 0.5 }, R = { 1.0, 0.4, 0, 0.6, 0, 0.5 } })
	local backTouch = mk({ root = { -0.35, 0.2 }, spine = { 0.05 }, head = { -0.05 }, jaw = 0.35, brow = -0.35, beard = 0.15, mane = { 0.1, 0.15, 0.2 }, L = { 1.0, 0.4, 0, 0.8, 0, 0.5 }, R = { 1.0, 0.4, 0, 0.8, 0, 0.5 } })
	local BK = paws(-0.9, 0.4, 0.35, 0.3)
	local back = hop({
		windup = {
			K(0, RDY, ALL, R_RDY),
			K(0.55, backLoad, ALL, BK, "inOut"),
			K(1, backShove, ALL, BK, "in"),
		},
		active = {
			K(0, backShove, ALL, BK),
			K(0.14, backOff, NONE, nil, "h1.2,1"), -- (the "out" ease's double-speed start kicked a knee 46 degrees)
			K(0.5, backFloat, NONE, nil, "inOut"),
			K(0.82, backReach, HIND, lifted(BW, 0.4, HIND), "inOut"),
			-- feet and fists land together: with the fists still reaching (raised 0.15-0.9) the
			-- planted elbow flipped to its other bend in the recover's first frames (50-85 degrees)
			K(1, backTouch, ALL, BW, "in"),
		},
		recover = {
			K(0, backTouch, ALL, BW),
			K(0.5, compress, ALL, BW, "inOut"),
			K(1, RDY, ALL, BW, "inOut"),
		},
	})
	-- short: a quick small hop
	local shortCrouch = mk({ root = { -0.6, -0.03 }, spine = { -0.1 }, head = { -0.12 }, jaw = 0.25, brow = -0.35, beard = 0.1, mane = { 0.1, 0.15, 0.2 } })
	local shortFlight = mk({ root = { 0.0, -0.12 }, spine = { -0.05 }, head = { 0.05 }, jaw = 0.4, brow = -0.25, beard = -0.15, mane = { 0.45, 0.5, 0.55 }, L = { 1.0, 0.3, 0, 0.4, 0.1, 0.4 }, R = { 1.0, 0.3, 0, 0.4, 0.1, 0.4 }, BL = { 0.4, -0.5, 0.2 }, BR = { 0.4, -0.5, 0.2 } })
	local short = hop({
		windup = {
			K(0, RDY, ALL, R_RDY),
			K(0.7, shortCrouch, ALL, BW, "out"),
			K(1, push, ALL, BW, "in"),
		},
		active = {
			K(0, push, ALL, BW),
			K(0.18, mix(push, shortFlight, 0.5), NONE, nil, "out"),
			K(0.5, shortFlight, NONE, nil, "inOut"),
			K(0.8, reachDown, ALL, lifted(BW, 0.35), "inOut"),
			K(1, touch, ALL, BW, "in"),
		},
		recover = landing.recover,
	})
	moves.Bound = flank
	variants.Bound = { flank = flank, over = over, back = back, short = short }
end

--------------------------------------------------------------------------------
-- BoulderHurl (1.70 s windup, keyed in seconds of it): 0-0.6 rip the rock out of the ground
-- (reach, dig in and strain, then a heave back onto the legs), 0.6-1.0 lift it overhead (the
-- big two-armed silhouette), 1.0-1.25 rear back on the right arm and hold, 1.25 release (the
-- right fist at the server's spawn point, root + (7, 14, -2) studs: solved against the rig,
-- within about 2 studs), then the follow-through while it flies.

do
	local w = TIMING.BoulderHurl[1]
	local function at(sec: number): number
		return math.clamp(sec / w, 0, 1)
	end
	local reach = mk({ root = { -0.55, -0.12 }, spine = { -0.2 }, head = { -0.3 }, jaw = 0.25, brow = -0.35, beard = 0.15, mane = { 0.1, 0.15, 0.2 } })
	local dig = mk({ root = { -0.8, -0.05 }, spine = { -0.28 }, head = { -0.25 }, jaw = 0.4, brow = -0.5, beard = 0.2, mane = { 0.05, 0.1, 0.15 }, L = { 0, 0, 0, 0, 0, 0.8 }, R = { 0, 0, 0, 0, 0, 0.8 } })
	local strain = mk({ root = { -0.82, 0.05 }, spine = { -0.2 }, head = { -0.15 }, jaw = 0.6, brow = -0.5, beard = 0.25, mane = { 0.15, 0.2, 0.25 }, L = { 0, 0, 0, 0, 0, 0.9 }, R = { 0, 0, 0, 0, 0, 0.9 } })
	-- the rip: thrown back onto the legs, the rock torn up to the belly in both hands
	local heave = mk({ root = { -0.5, 0.45 }, spine = { 0.1 }, head = { 0.15 }, jaw = 0.85, brow = 0.0, beard = 0.0, mane = { 0.45, 0.5, 0.55 }, L = { 1.2, 0.3, 0.35, 1.3, 0.3, 0.7 }, R = { 1.2, 0.3, 0.35, 1.3, 0.3, 0.7 } })
	local chest = mk({ root = { -0.35, 0.65 }, spine = { 0.12 }, head = { 0.2 }, jaw = 0.6, brow = 0.05, beard = -0.05, mane = { 0.35, 0.4, 0.45 }, L = { 2.0, 0.3, 0.3, 1.1, 0.0, 0.7 }, R = { 2.0, 0.3, 0.3, 1.1, 0.0, 0.7 } })
	-- overhead: both arms up, the rock between the fists, chest out
	local over = mk({ root = { -0.1, 0.9 }, spine = { 0.15 }, head = { 0.35 }, jaw = 0.7, brow = 0.2, beard = -0.25, mane = { 0.55, 0.6, 0.65 }, L = { 3.05, 0.35, 0, 0.45, -0.35, 0.8 }, R = { 3.05, 0.35, 0, 0.45, -0.35, 0.8 } })
	-- rear back: the right arm cocked behind the head, the left pointing at the target
	local cock = mk({ root = { -0.2, 1.0, 0, -0.25 }, spine = { 0.3, -0.1 }, head = { 0.25, 0.25 }, jaw = 0.55, brow = -0.15, beard = -0.2, mane = { 0.6, 0.65, 0.7 }, L = { 1.9, 0.35, 0.25, 0.25, 0, 0.6 }, R = { 3.5, 0.5, 0, 1.4, -0.4, 0.9 } })
	local cock2 = mk({ root = { -0.3, 1.05, 0, -0.3 }, spine = { 0.34, -0.12 }, head = { 0.22, 0.3 }, jaw = 0.5, brow = -0.25, beard = -0.2, mane = { 0.65, 0.7, 0.75 }, L = { 1.85, 0.35, 0.25, 0.3, 0, 0.6 }, R = { 3.55, 0.5, 0, 1.5, -0.45, 0.9 } })
	-- (the body commits WITH the throw: leaning back at 0.5 here, the arm threw and the torso only
	-- came forward 400 ms later - the critic's "arm throws, body flops after")
	local release = mk({ root = { -0.6, 0.02, 0, 0.15 }, spine = { -0.05, 0.12 }, head = { 0.25 }, jaw = 0.8, brow = 0.1, beard = 0.2, mane = { 0.3, 0.35, 0.4 }, L = { 1.6, 0.4, 0.2, 0.3, 0, 0.6 }, R = { 2.2, 0.14, -0.13, 1.9, 1.0, 0.3 } }) -- (arm re-aimed so the fist is 2.7 studs from the server's spawn point)
	-- watching it fly: the head lifts to follow the arc
	-- (head up and the arm wider: across under the chin the forearm went 0.9 into the beard and jaw)
	local hold = mk({ root = { -0.48, -0.04, 0, 0.5 }, spine = { -0.18, 0.2 }, head = { 0.28, -0.15 }, jaw = 0.45, brow = -0.25, beard = 0.1, mane = { -0.05, 0.05, 0.1 }, L = { 0.8, 0.45, 0, 0.2, 0, 0.5 }, R = { 0.8, 0.15, 0.4, 0.0, 0.4, 0.9 } })
	local hold2 = mk({ root = { -0.45, -0.04, 0, 0.48 }, spine = { -0.15, 0.18 }, head = { 0.2, -0.12 }, jaw = 0.35, brow = -0.3, beard = 0.1, mane = { 0.0, 0.05, 0.1 }, L = { 0.8, 0.45, 0, 0.2, 0, 0.5 }, R = { 0.75, 0.15, 0.4, 0.1, 0.3, 0.7 } })
	local ground = paws(-1.9, 0.5, 0.15, 0.3) -- both fists close together, far ahead: the rock's spot
	-- Intent: dig both fists into the earth and strain (the tremble), rip the rock up onto the legs,
	-- hoist it overhead (the big read), wind it behind the head on the right arm and whip it out at
	-- 1.25 s, the whole body following it down and round to the left. One continuous lift from the
	-- rip to the overhead (each key hands its speed on), a slow wind at the top, the fastest beat
	-- the throw, then one long decelerating follow-through (the fist never parks inside the windup).
	moves.BoulderHurl = {
		windup = ph(w, {
			K(0, RDY, ALL, R_RDY),
			-- the fists peel up and travel to the rock aimed at raised spots (planted, lifted), so their
			-- path is the spots' path and they come down on it decelerating
			K(at(0.1), mix(RDY, reach, 0.4), ALL, lifted(R_RDY, 0.6, FRONT), "inOut"),
			K(at(0.25), reach, ALL, lifted(ground, 0.8, FRONT), "h1,0.7"),
			K(at(0.37), dig, ALL, ground, "h0.7,0"),
			K(at(0.45), strain, ALL, ground, "inOut"),
			K(at(0.62), heave, HIND, R_REAR, "h0.3,0.5"),
			K(at(0.8), chest, HIND, R_REAR, "h2,0.8"),
			K(at(0.9), over, HIND, R_REAR, "h0.8,0.25"),
			K(at(1.0), cock, HIND, R_REAR, "h0.25,0.4"),
			K(at(1.06), cock2, HIND, R_REAR, "h0.4,0.6"),
			-- the whole body throws: hips, chest and arm come forward through the release together
			K(at(BOULDER_RELEASE), release, HIND, R_REAR, "h0.8,1.2"),
			K(1, hold, SUP_R, R_LOW, "h1.8,0"),
		}, chain(tremble(at(0.3), at(0.5), 0.04, 12), tremble(at(0.95), at(1.08), 0.03, 10))),
		active = ph(TIMING.BoulderHurl[2], {
			K(0, hold, SUP_R, R_LOW),
			K(1, hold2, SUP_R, R_LOW, "inOut"),
		}),
		recover = ph(TIMING.BoulderHurl[3], {
			K(0, hold2, SUP_R, R_LOW),
			K(0.25, hold2, SUP_R, R_LOW),
			-- the throwing arm folds before it steps down (straight, it swung through the ground)
			K(0.5, mk({ root = { -0.45, -0.06, 0, 0.25 }, spine = { -0.1, 0.1 }, head = { -0.05 }, jaw = 0.3, brow = -0.25, beard = 0.2, mane = { 0.05, 0.1, 0.15 }, R = { 0.15, 0.25, 0.2, 1.6, 0.2, 0.4 } }), SUP_R, R_LOW, "inOut"),
			K(0.78, RDY, ALL, R_LOW, "inOut"),
			K(1, STAND, ALL, nil, "inOut"),
		}),
	}
end

--------------------------------------------------------------------------------
-- ThunderLance: right arm straight overhead, fist open, leaning back, then a javelin throw
-- straight forward along the lane at the end of the windup.

do
	local rise = mk({ root = { -0.2, 0.7 }, spine = { 0.1 }, head = { 0.15 }, jaw = 0.4, brow = 0.0, beard = -0.1, mane = { 0.25, 0.3, 0.35 }, L = { 1.2, 0.5, 0, 0.5, 0, 0.5 }, R = { 2.7, 0.15, 0, 0.1, -0.1, 0.9 } })
	local held = mk({ root = { -0.1, 0.95 }, spine = { 0.3 }, head = { 0.35 }, jaw = 0.7, brow = 0.2, beard = -0.3, mane = { 0.5, 0.55, 0.6 }, L = { 1.5, 0.45, 0, 0.3, 0, 0.5 }, R = { 3.1, 0.1, 0, 0.1, -0.15, 1.0 } })
	local cock = mk({ root = { -0.05, 1.05 }, spine = { 0.38 }, head = { 0.4 }, jaw = 0.8, brow = 0.25, beard = -0.4, mane = { 0.6, 0.65, 0.7 }, L = { 1.6, 0.4, 0, 0.3, 0, 0.5 }, R = { 3.5, 0.1, 0, 1.0, -0.3, 1.0 } })
	local throw = mk({ root = { -0.5, -0.05 }, spine = { -0.1 }, head = { -0.1 }, jaw = 0.8, brow = -0.15, beard = 0.3, mane = { 0.1, 0.15, 0.2 }, L = { 0.9, 0.5, 0, 0.3, 0, 0.5 }, R = { 1.75, 0.0, 0, 0.0, 0.0, 1.2 } })
	local after = mk({ root = { -0.65, -0.1 }, spine = { -0.2 }, head = { -0.2 }, jaw = 0.5, brow = -0.3, beard = 0.4, mane = { -0.1, 0, 0.05 }, L = { 0.7, 0.5, 0, 0.3, 0, 0.5 }, R = { 1.2, 0.0, 0, 0.0, 0.3, 1.2 } })
	-- Intent: rear back onto the legs with the right arm straight up, the bolt gathering in the open
	-- fist (the long hold, trembling and drawing slowly further back, never parked), wind it behind
	-- the head, then hurl it straight down the lane: the hips lead the body down onto the left fist
	-- and the arm whips through last, fastest at the release, and carries on down after it.
	-- Beats (1.40 s): rise 0-0.42, the hold 0.42-1.09 (the telegraph's read), wind 1.09-1.23,
	-- throw 1.23-1.40.
	local held2 = mix(held, cock, 0.35)
	local after2 = mix(after, RDY, 0.3)
	moves.ThunderLance = {
		windup = ph(TIMING.ThunderLance[1], {
			K(0, RDY, ALL, R_RDY),
			K(0.3, rise, HIND, R_REAR, "out"),
			K(0.45, held, HIND, R_REAR, "h1,0.3"),
			K(0.78, held2, HIND, R_REAR, "h0.4,0.4"),
			K(0.88, cock, HIND, R_REAR, "h0.6,0.4"),
			K(1, throw, SUP_R, R_LOW, "h0.4,1.6"),
		}, tremble(0.4, 0.86, 0.03, 10)),
		active = ph(TIMING.ThunderLance[2], {
			K(0, throw, SUP_R, R_LOW),
			K(1, after, SUP_R, R_LOW, "h1.4,0.5"),
		}),
		recover = ph(TIMING.ThunderLance[3], {
			K(0, after, SUP_R, R_LOW),
			K(0.3, after2, SUP_R, R_LOW, "h0.6,0.2"),
			K(0.65, RDY, ALL, R_LOW, "inOut"),
			K(1, STAND, ALL, nil, "inOut"),
		}),
	}
end

--------------------------------------------------------------------------------
-- The roars: Challenge, ThunderRoar, PhaseRoar. The ape rears onto its legs and beats its
-- chest; each beat is a fist raised, then driven onto the chest plate (ChestBeatL/R_FX) at
-- exactly the beat time (ThunderApe.BEATS), then a rebound. After the last beat the head
-- goes back, the chest swells and the jaw opens to the release.
-- BEAT_ARM is the left arm (world pitch, out, yaw, elbow, wrist, fingers) that puts the fist
-- on the left plate with the torso below (solved offline against the rig).

local BEAT_PITCH, BEAT_SPINE = 1.05, 0.1
-- upper arm along the torso (0.19 behind its line), out 1.22, yaw -0.48, elbow 1.83, wrist 1.15:
-- the arm solved against the rig with the head at +0.1 that lands the fist on the plate without
-- clipping the jaw or skull (the old out 0.06 / yaw -0.8 / wrist 1.65 arm went 2.5 studs into them,
-- and its wrist snapped 64 degrees in a frame at each beat). Torso-relative, so any rear-up.
local function hitArm(pitch: number, spine: number): { number }
	return { pitch + spine + 0.19, 1.22, -0.48, 1.83, 1.15, 0.0 }
end
local BEAT_ARM = hitArm(BEAT_PITCH, BEAT_SPINE - 0.04)
local function rarm(l: { number }): { number }
	return { l[1], l[2], -l[3], l[4], l[5], l[6] }
end
local ARM_UP = { 2.5, 0.95, 0, 0.7, -0.2, 0.5 }
local ARM_OUT = { 1.9, 0.9, 0, 0.25, 0.0, 0.5 }
local ARM_WIDE = { 1.75, 1.3, 0, 0.1, 0.1, 1.0 }

local function body(pitch: number, dip: number, spineA: number, headA: number, jaw: number, L: { number }, R: { number }, swell: number?): Pose
	local sw = swell or 0
	return mk({
		root = { -0.1 + dip, pitch }, spine = { spineA }, head = { headA }, jaw = jaw,
		brow = 0.1 + 0.2 * sw, beard = -0.1 - 0.35 * sw, mane = { 0.3 + 0.3 * sw, 0.35 + 0.3 * sw, 0.4 + 0.3 * sw }, L = L, R = R,
	})
end

local function roarKeys(dur: number, beats: { { any } }, riseT: number, archT: number, pitch: number, holdT: number?): { any }
	local keys = { K(0, RDY, ALL, R_RDY) }
	local function add(sec: number, pose: Pose, ease: string?)
		table.insert(keys, K(math.clamp(sec / dur, 0, 1), pose, HIND, R_REAR, ease))
	end
	add(riseT, body(pitch - 0.1, 0, BEAT_SPINE, 0.1, 0.4, ARM_OUT, rarm(ARM_OUT)), "out")
	local prev = riseT
	for _, b in beats do
		local t, kind = b[1], b[2]
		local upT = math.max(prev + 0.03, t - 0.17)
		local L, R = ARM_OUT, rarm(ARM_OUT)
		local Lu, Ru = ARM_OUT, rarm(ARM_OUT)
		local Lh, Rh = ARM_OUT, rarm(ARM_OUT)
		if kind == "L" or kind == "B" then
			Lu, Lh = ARM_UP, BEAT_ARM
		end
		if kind == "R" or kind == "B" then
			Ru, Rh = rarm(ARM_UP), rarm(BEAT_ARM)
		end
		add(upT, body(pitch, 0, BEAT_SPINE, 0.2, 0.55, Lu, Ru), "inOut")
		-- (keyed at 0.0: the skull trails its keys, so it still sits near the solve's +0.1 at the beat;
		-- keyed at +0.1 it trailed the raised head and the brow met the fist)
		add(t, body(BEAT_PITCH, -0.12, BEAT_SPINE - 0.04, 0.0, 0.4, Lh, Rh, 0.0), "in")
		-- rebound: the chest rocks and the fist bounces off
		local Lr, Rr = L, R
		if kind == "L" or kind == "B" then
			Lr = { BEAT_ARM[1] + 0.5, BEAT_ARM[2] + 0.4, BEAT_ARM[3], BEAT_ARM[4] - 0.2, BEAT_ARM[5], 0.3 }
		end
		if kind == "R" or kind == "B" then
			Rr = rarm({ BEAT_ARM[1] + 0.5, BEAT_ARM[2] + 0.4, BEAT_ARM[3], BEAT_ARM[4] - 0.2, BEAT_ARM[5], 0.3 })
		end
		add(t + 0.13, body(pitch + 0.05, 0.02, BEAT_SPINE + 0.06, 0.15, 0.55, Lr, Rr, 0.15), "inOut")
		prev = t + 0.13
	end
	add(math.max(archT, prev + 0.12), body(pitch + 0.05, 0, 0.3, 0.45, 0.8, ARM_OUT, rarm(ARM_OUT), 0.6), "inOut")
	-- the chest keeps swelling into the release (a slow drift on the hold, never parked)
	add(math.max(dur * 0.9, math.max(archT, prev + 0.12) + 0.08), body(pitch + 0.13, 0.04, 0.4, 0.6, 1.0, ARM_WIDE, rarm(ARM_WIDE), 0.9), "h1,0.3")
	add(dur, body(pitch + 0.15, 0.05, 0.42, 0.65, 1.05, ARM_WIDE, rarm(ARM_WIDE), 1.0), "h0.4,0.5")
	return keys
end

local function roarMove(dur: number, beats: { { any } }, riseT: number, archT: number, pitch: number, active: number, recover: number)
	local final = body(pitch + 0.15, 0.05, 0.42, 0.65, 1.05, ARM_WIDE, rarm(ARM_WIDE), 1.0)
	local final2 = body(pitch + 0.1, 0.02, 0.38, 0.55, 0.9, ARM_WIDE, rarm(ARM_WIDE), 0.7)
	return {
		windup = ph(dur, roarKeys(dur, beats, riseT, archT, pitch), function(u: number, secs: number, _): Pose
			-- between beats the body breathes and rocks on the legs; the roar shudders the jaw
			local roarK = smooth(archT / dur, 0.97, u)
			local f = secs * TAU
			return {
				JointRoot = R(0, 0.02 * math.sin(f * 1.3) * (1 - roarK), 0, 0.03 * math.sin(f * 0.9), 0.025 * math.sin(f * 1.1 + 1)),
				JointJaw = A(-0.08 * roarK * math.abs(math.sin(f * 7))),
				JointHead = A(0.03 * roarK * math.sin(f * 8)),
			}
		end),
		active = ph(active, { K(0, final, HIND, R_REAR), K(1, final2, HIND, R_REAR, "out") }, tremble(0, 1, 0.025, 12)),
		recover = ph(recover, {
			K(0, final2, HIND, R_REAR),
			K(0.25, final2, HIND, R_REAR),
			K(0.5, mix(final2, mk({ root = { -0.15, 0.3 }, spine = { 0.05 }, head = { 0.0 }, jaw = 0.3, brow = -0.1, beard = 0.0, mane = { 0.2, 0.25, 0.3 }, L = { 0.4, 0.5, 0, 0.3, 0, 0.3 }, R = { 0.4, 0.5, 0, 0.3, 0, 0.3 } }), 0.85), HIND, R_REAR, "inOut"),
			K(0.72, RDY, ALL, R_LOW, "inOut"),
			K(1, STAND, ALL, nil, "inOut"),
		}),
	}
end
moves.Challenge = roarMove(TIMING.Challenge[1], { { 0.55, "L" }, { 1.15, "R" }, { 1.75, "B" } }, 0.3, 2.0, 1.1, TIMING.Challenge[2], TIMING.Challenge[3])
moves.ThunderRoar = roarMove(TIMING.ThunderRoar[1], { { 0.45, "L" }, { 0.85, "R" } }, 0.22, 1.1, 1.05, TIMING.ThunderRoar[2], TIMING.ThunderRoar[3])
moves.PhaseRoar = roarMove(TIMING.PhaseRoar[1], { { 0.4, "L" }, { 0.8, "R" }, { 1.2, "B" } }, 0.18, 1.46, 1.2, TIMING.PhaseRoar[2], TIMING.PhaseRoar[3])

--------------------------------------------------------------------------------
-- StormCall: both arms rise to the sky, the channel pose held through 0.85 of the long
-- recover (fingers flexing, chest heaving, a slight tremble), then eased out.

local function channelPose(pitch: number, arms: number, out: number, spineA: number, fi: number): Pose
	return mk({ root = { -0.05, pitch }, spine = { spineA }, head = { 0.35 }, jaw = 0.8, brow = 0.2, beard = -0.35, mane = { 0.55, 0.6, 0.65 },
		L = { arms, out, 0, 0.15, -0.2, fi }, R = { arms, out, 0, 0.15, -0.2, fi } })
end
local function stormMove(chan: Pose, rise: Pose, coil: Pose, pump: any?): { [string]: Phase }
	return {
		windup = ph(TIMING.StormCall[1], {
			K(0, RDY, ALL, R_RDY),
			K(0.3, coil, ALL, R_LOW, "inOut"),
			K(0.7, rise, HIND, R_REAR, "inOut"),
			K(1, chan, HIND, R_REAR, "out"),
		}, tremble(0.7, 1.0, 0.02)),
		active = ph(TIMING.StormCall[2], { K(0, chan, HIND, R_REAR), K(1, chan, HIND, R_REAR) }, tremble(0, 1, 0.02, 12)),
		recover = ph(TIMING.StormCall[3], {
			K(0, chan, HIND, R_REAR),
			K(0.85, chan, HIND, R_REAR),
			K(0.95, mix(chan, RDY, 0.8), HIND, R_LOW, "inOut"),
			K(1, STAND, ALL, nil, "inOut"),
		}, function(u: number, secs: number, _): Pose
			local k = smooth(0.0, 0.08, u) * (1 - smooth(0.82, 0.95, u))
			local f = secs * TAU
			local pump_ = if pump then pump(secs, k) else {}
			local out: Pose = {
				-- fingers flex open and shut, the chest heaves, the whole body trembles
				JointFingersFL = A(0.35 * k * math.sin(f * 1.3)), JointFingersFR = A(0.35 * k * math.sin(f * 1.3 + 1.5)),
				JointSpine = A(0.07 * k * math.sin(f * 0.55)),
				JointHead = A(0.06 * k * math.sin(f * 0.4 + 1), 0.08 * k * math.sin(f * 0.3)),
				JointJaw = A(-0.1 * k * math.max(0, math.sin(f * 0.7))),
				JointRoot = R(0, 0.012 * k * math.sin(f * 4.5), 0, 0.015 * k * math.sin(f * 3.7), 0.015 * k * math.sin(f * 5.1)),
				JointLegFL = A(0.04 * k * math.sin(f * 1.1), 0, 0.05 * k * math.sin(f * 0.8)),
				JointLegFR = A(0.04 * k * math.sin(f * 1.1 + 2), 0, -0.05 * k * math.sin(f * 0.8 + 1)),
			}
			for j, cf in pump_ do
				out[j] = (out[j] or I) * cf
			end
			return out
		end),
	}
end

do
	local chanA = channelPose(0.95, 3.0, 0.5, 0.25, 1.0)
	local riseA = channelPose(0.55, 1.9, 0.7, 0.1, 0.6)
	local coilA = mk({ root = { -0.55, -0.2 }, spine = { -0.15 }, head = { -0.2 }, jaw = 0.3, brow = -0.35, beard = 0.15, mane = { 0.1, 0.15, 0.2 }, L = { -0.3, 0.5 }, R = { -0.3, 0.5 } })
	moves.StormCall = stormMove(chanA, riseA, coilA)
	variants.StormCall = { A = moves.StormCall }
	-- B: the arms pump the sky alternately
	local chanB = channelPose(0.9, 2.9, 0.3, 0.22, 0.2)
	variants.StormCall.B = stormMove(chanB, channelPose(0.5, 1.8, 0.5, 0.1, 0.2), coilA, function(secs: number, k: number): Pose
		local p = 0.45 * k * math.sin(secs * TAU * 0.9)
		return { JointLegFL = A(p, 0, 0), JointLegFR = A(-p, 0, 0), JointElbowFL = A(0.4 * k * math.max(0, math.sin(secs * TAU * 0.9))), JointElbowFR = A(0.4 * k * math.max(0, -math.sin(secs * TAU * 0.9))) }
	end)
	-- C: wide V, fists clenched, leaning far back, hard tremble
	local chanC = mk({ root = { -0.2, 0.75 }, spine = { 0.4 }, head = { 0.55 }, jaw = 0.95, brow = 0.25, beard = -0.45, mane = { 0.65, 0.7, 0.75 }, L = { 2.7, 1.25, 0, 0.1, -0.3, 0.0 }, R = { 2.7, 1.25, 0, 0.1, -0.3, 0.0 } })
	variants.StormCall.C = stormMove(chanC, channelPose(0.45, 1.6, 0.9, 0.2, 0.1), coilA, function(secs: number, k: number): Pose
		local t = 0.03 * k * math.sin(secs * 31)
		return { JointRoot = R(-0.015 * k, t), JointSpine = A(t * 0.7), JointElbowFL = A(t), JointElbowFR = A(-t) }
	end)
end

--------------------------------------------------------------------------------
-- Stagger (weight 9: a shoulder drop, a rock back) and Death.

do
	local hit = mk({ root = { -0.4, 0.4, 0, 0.3, 0.18 }, spine = { 0.2, 0.2 }, head = { 0.35, 0.5 }, jaw = 0.6, brow = 0.25, beard = -0.3, mane = { 0.5, 0.55, 0.6 }, R = { 0.6, 0.9, 0, 0.9, 0, 0.5 } })
	local rock = mk({ root = { -0.5, 0.45, 0, 0.25, 0.14 }, spine = { 0.15, 0.15 }, head = { 0.2, 0.35 }, jaw = 0.4, brow = 0.0, beard = -0.1, mane = { 0.4, 0.45, 0.5 }, R = { 0.35, 0.7, 0, 0.6, 0, 0.3 } })
	local back = mk({ root = { -0.5, 0.0, 0, 0.1, 0.08 }, spine = { 0.0, 0.1 }, head = { -0.1, 0.15 }, jaw = 0.2, brow = -0.25, beard = 0.1, mane = { 0.1, 0.15, 0.2 } })
	moves.Stagger = { active = ph(TIMING.Stagger[2], {
		K(0, RDY, ALL, R_RDY),
		K(0.18, hit, SUP_R, R_REAR, "out"),
		K(0.5, rock, SUP_R, R_REAR, "inOut"),
		K(1, back, ALL, R_LOW, "inOut"),
	}) }
	moves.Stagger.active.mirror = true
end

do
	local hit = mk({ root = { -0.2, 0.5, 0, 0.0, 0.15 }, spine = { 0.25 }, head = { 0.45, 0.2 }, jaw = 0.8, brow = 0.3, beard = -0.4, mane = { 0.6, 0.65, 0.7 }, L = { 0.9, 0.9, 0, 0.5, 0, 0.5 }, R = { 0.9, 0.9, 0, 0.5, 0, 0.5 } })
	local stand = mk({ root = { -0.1, 0.9, 0, 0.12, 0.08 }, spine = { 0.1 }, head = { 0.15, 0.25 }, jaw = 0.35, brow = -0.05, beard = 0.0, mane = { 0.2, 0.25, 0.3 }, L = { 0.35, 0.5, 0, 0.3, 0, 0.2 }, R = { 0.3, 0.55, 0, 0.35, 0, 0.2 } })
	local sway = mk({ root = { -0.15, 0.95, 0, -0.14, -0.1 }, spine = { 0.12, -0.1 }, head = { 0.05, -0.3 }, jaw = 0.4, brow = -0.1, beard = 0.05, mane = { 0.15, 0.2, 0.25 }, L = { 0.4, 0.55, 0, 0.3, 0, 0.2 }, R = { 0.3, 0.45, 0, 0.4, 0, 0.2 } })
	local beat = body(1.1, -0.05, 0.3, 0.5, 1.0, hitArm(1.1, 0.3), rarm(hitArm(1.1, 0.3)), 0.8)
	local beatUp = body(1.15, 0.0, 0.2, 0.3, 0.9, ARM_UP, rarm(ARM_UP), 0.5)
	local overload = body(1.2, 0.05, 0.42, 0.7, 1.1, ARM_WIDE, rarm(ARM_WIDE), 1.0)
	-- (sagging to its knees: at -1.4 the planted shins went 3.4 studs into the ground)
	local sag = mk({ root = { -1.0, 0.6, 0, 0.0, 0.1 }, spine = { -0.1 }, head = { -0.1, 0.1 }, jaw = 0.4, brow = -0.2, beard = 0.2, mane = { 0.0, 0.05, 0.1 }, L = { 0.5, 0.5, 0, 0.5, 0, 0.1 }, R = { 0.5, 0.5, 0, 0.5, 0, 0.1 }, BL = { 0.2, -1.0, 0.3 }, BR = { 0.2, -1.0, 0.3 } })
	local fall = mk({ root = { -0.6, -0.5, -0.2, 0.0, 0.1 }, spine = { -0.3 }, head = { 0.2 }, jaw = 0.3, brow = -0.2, beard = 0.4, mane = { -0.2, -0.1, 0 }, L = { 1.7, 0.4, 0, 0.1, 0.1, 0.2 }, R = { 1.5, 0.5, 0, 0.15, 0.1, 0.2 }, BL = { 0.1, -1.1, 0.3 }, BR = { 0.1, -1.1, 0.3 } })
	local prone = mk({ root = { -1.05, -0.6, -0.3, 0.0, 0.1 }, spine = { -0.2 }, head = { 0.3, 0.3 }, jaw = 0.3, brow = -0.1, beard = 0.5, mane = { -0.6, -0.5, -0.4 }, L = { 1.7, 1.0, 0, 0.0, 0.2, 0.2 }, R = { 1.6, 1.1, 0, 0.0, 0.2, 0.2 }, BL = { -0.7, 0, 0.3 }, BR = { -0.7, 0, 0.3 } })
	local rest = mk({ root = { -1.08, -0.62, -0.3, 0.0, 0.1 }, spine = { -0.24 }, head = { 0.28, 0.35 }, jaw = 0.25, brow = -0.05, beard = 0.7, mane = { -0.7, -0.6, -0.5 }, L = { 1.7, 1.1, 0, 0.0, 0.2, 0.1 }, R = { 1.6, 1.2, 0, 0.0, 0.2, 0.1 }, BL = { -0.75, 0, 0.3 }, BR = { -0.75, 0, 0.3 } })
	moves.Death = { active = ph(TIMING.Death[2], {
		K(0, RDY, ALL, R_RDY),
		K(0.035, hit, HIND, R_REAR, "out"),
		K(0.15, stand, HIND, R_REAR, "inOut"),
		K(0.25, sway, HIND, R_REAR, "inOut"),
		K(0.34, beatUp, HIND, R_REAR, "inOut"),
		K(0.375, beat, HIND, R_REAR, "in"),
		K(0.43, overload, HIND, R_REAR, "h1.2,0.2"),
		K(0.5, overload, HIND, R_REAR, "h0.3,0"),
		K(0.6, sag, HIND, R_REAR, "inOut"),
		K(0.76, fall, NONE, nil, "in"),
		K(0.86, prone, NONE, nil, "in"),
		K(0.92, rest, NONE, nil, "out"),
		K(1, rest, NONE, nil),
	}, function(u: number, secs: number, _): Pose
		local sw = smooth(0.12, 0.3, u) * (1 - smooth(0.3, 0.34, u)) + smooth(0.5, 0.58, u) * (1 - smooth(0.58, 0.64, u))
		local flare = smooth(0.4, 0.43, u) * (1 - smooth(0.5, 0.55, u))
		return {
			JointRoot = R(0, 0.03 * sw * math.sin(secs * 5), 0, 0.05 * sw * math.sin(secs * 3.3), 0.05 * sw * math.sin(secs * 4)),
			JointHead = A(0.05 * sw * math.sin(secs * 4)),
			JointSpine = A(0.04 * flare * math.sin(secs * 30)),
			JointJaw = A(-0.08 * flare * math.abs(math.sin(secs * 22))),
		}
	end, true) }
end

--------------------------------------------------------------------------------
-- Variants. Every move has A (the default) and, where it helps readability, B and C with the
-- identical phase durations (the defs own the timing). ThunderApe.VARIANT picks one per move;
-- setVariant / setAll switch. Contact stays at the END of the windup in every variant.

for name, m in moves do
	if not variants[name] then
		variants[name] = { A = m }
	end
end

-- ClubSwing B "Low hook": a long crouch, the arm wound wide and low, a flat sweep at belly height.
-- C "Spin": a full-body corkscrew, the arm trailing, then whipped through.
do
	local loadB = mk({ root = { -0.8, -0.15, 0, -0.5 }, spine = { 0.0, -0.4 }, head = { -0.15, 0.35 }, jaw = 0.25, brow = -0.35, beard = 0.1, mane = { 0.15, 0.2, 0.25 }, R = { 0.2, 1.2, -0.5, 0.2, 0, 0.5 } })
	local windB = mk({ root = { -0.9, -0.1, 0, -0.9 }, spine = { 0.0, -0.55 }, head = { -0.2, 0.55 }, jaw = 0.4, brow = -0.4, beard = 0.2, mane = { 0.3, 0.35, 0.4 }, R = { 0.7, 1.45, -1.0, 0.1, 0, 0.8 } })
	local contactB = mk({ root = { -0.8, -0.2, 0, 0.6 }, spine = { -0.05, 0.4 }, head = { -0.2, -0.35 }, jaw = 0.3, brow = -0.35, beard = 0.15, mane = { -0.05, 0, 0.05 }, R = { 0.95, 0.5, 0.9, 0.0, 0.2, 0 } })
	local throughB = mk({ root = { -0.85, -0.25, 0, 0.9 }, spine = { -0.1, 0.55 }, head = { -0.2, -0.45 }, jaw = 0.2, brow = -0.35, beard = 0.3, mane = { -0.15, -0.1, 0 }, R = { 0.7, 0.2, 1.2, 0, 0.2, 0 } })
	variants.ClubSwing.B = {
		windup = ph(TIMING.ClubSwing[1], { K(0, RDY, ALL, R_RDY), K(0.25, loadB, SUP_R, R_LOW, "out"), K(0.6, windB, SUP_R, R_LOW, "inOut"), K(0.97, contactB, SUP_R, R_LOW, "in"), K(1, contactB, SUP_R, R_LOW) }),
		active = ph(TIMING.ClubSwing[2], { K(0, contactB, SUP_R, R_LOW), K(0.7, throughB, SUP_R, R_LOW, "out"), K(1, throughB, SUP_R, R_LOW) }),
		recover = ph(TIMING.ClubSwing[3], { K(0, throughB, SUP_R, R_LOW), K(0.7, CHAIN_READY, ALL, R_LOW, "inOut"), K(1, CHAIN_READY, ALL, R_LOW) }),
	}
	local windC = mk({ root = { -0.4, -0.05, 0, -1.1 }, spine = { 0.05, -0.5 }, head = { 0.0, 0.6 }, jaw = 0.5, brow = -0.2, beard = 0.0, mane = { 0.35, 0.4, 0.45 }, R = { 2.2, 0.7, -0.4, 0.3, -0.2, 0.8 } })
	local midC = mk({ root = { -0.5, -0.1, 0, -0.2 }, spine = { 0.0, -0.1 }, head = { -0.1, 0.1 }, jaw = 0.3, brow = -0.3, beard = 0.2, mane = { 0.0, 0.05, 0.1 }, R = { 1.8, 0.4, 0.2, 0.2, 0, 0.6 } })
	variants.ClubSwing.C = {
		windup = ph(TIMING.ClubSwing[1], { K(0, RDY, ALL, R_RDY), K(0.45, windC, SUP_R, R_REAR, "inOut"), K(0.75, midC, SUP_R, R_LOW, "in"), K(0.97, CS_CONTACT, SUP_R, R_LOW, "in"), K(1, CS_CONTACT, SUP_R, R_LOW) }),
		active = moves.ClubSwing.active,
		recover = moves.ClubSwing.recover,
	}
end

-- ThunderPound B "Rear-and-drop": the tallest rear-up with a hang at the top, then a long drop.
-- C "Spring-slam": a quick crouch, the ape springs up off its legs with fists high and comes down.
do
	local pk = mk({ root = { 0.1, 1.3 }, spine = { 0.25 }, head = { 0.45 }, jaw = 0.85, brow = 0.25, beard = -0.3, mane = { 0.55, 0.6, 0.65 }, L = { 3.2, 0.3, 0, 0.5, -0.35, 1.0 }, R = { 3.2, 0.3, 0, 0.5, -0.35, 1.0 } })
	variants.ThunderPound.B = {
		windup = ph(TIMING.ThunderPound[1], { K(0, BACKHAND_END, ALL, R_LOW), K(0.4, PD_PEAK, HIND, R_REAR, "h0.3,1"), K(0.7, pk, HIND, R_REAR, "inOut"), K(1, PD_CONTACT, ALL, POUND_REACH, "in") }, tremble(0.5, 0.7, 0.04)),
		active = moves.ThunderPound.active,
		recover = moves.ThunderPound.recover,
	}
	local sq = mk({ root = { -1.0, -0.3 }, spine = { -0.1 }, head = { -0.2 }, jaw = 0.3, brow = -0.35, beard = 0.15, mane = { 0.1, 0.15, 0.2 } })
	local up = mk({ root = { 0.6, 0.55 }, spine = { 0.2 }, head = { 0.3 }, jaw = 0.8, brow = 0.2, beard = -0.3, mane = { 0.5, 0.55, 0.6 }, L = { 3.1, 0.3, 0, 0.3, -0.2, 1.0 }, R = { 3.1, 0.3, 0, 0.3, -0.2, 1.0 }, BL = { 0.3, -0.1, 0.1 }, BR = { 0.3, -0.1, 0.1 } })
	variants.ThunderPound.C = {
		windup = ph(TIMING.ThunderPound[1], { K(0, BACKHAND_END, ALL, R_LOW), K(0.25, sq, ALL, R_LOW, "inOut"), K(0.62, up, NONE, nil, "out"), K(1, PD_CONTACT, ALL, POUND_REACH, "in") }, nil, false),
		active = moves.ThunderPound.active,
		recover = moves.ThunderPound.recover,
	}
end

-- BodySlam B "Lunge": shorter rear, a hip drop and a chest-first lunge. C "Double beat": a
-- chest beat at the top before the fall.
do
	local lungeUp = mk({ root = { -0.2, 0.95 }, spine = { 0.15 }, head = { 0.3 }, jaw = 0.6, brow = 0.1, beard = -0.2, mane = { 0.4, 0.45, 0.5 }, L = { 1.8, 0.9, 0, 0.5, -0.1, 0.6 }, R = { 1.8, 0.9, 0, 0.5, -0.1, 0.6 } })
	variants.BodySlam.B = {
		windup = ph(TIMING.BodySlam[1], { K(0, RDY, ALL, R_RDY), K(0.3, BS_CROUCH, ALL, R_LOW, "inOut"), K(0.8, lungeUp, HIND, R_REAR, "inOut"), K(1, lungeUp, HIND, R_REAR) }, tremble(0.5, 0.95, 0.03)),
		active = ph(TIMING.BodySlam[2], { K(0, lungeUp, HIND, R_REAR), K(0.45, BS_FALL, NONE, nil, "in"), K(0.82, BS_PRONE, FRONT, lifted(BS_FWD, 0.9, FRONT), "in"), K(1, BS_SPLAT, FRONT, BS_FWD, "out") }, nil, true),
		recover = moves.BodySlam.recover,
	}
	local top = body(1.25, 0, 0.2, 0.4, 0.8, hitArm(1.25, 0.2), rarm(hitArm(1.25, 0.2)), 0.5)
	variants.BodySlam.C = {
		windup = ph(TIMING.BodySlam[1], { K(0, RDY, ALL, R_RDY), K(0.2, BS_CROUCH, ALL, R_LOW, "inOut"), K(0.5, BS_TALL, HIND, R_REAR, "inOut"), K(0.7, top, HIND, R_REAR, "in"), K(0.88, BS_TIP, HIND, R_REAR, "out"), K(1, BS_TIP, HIND, R_REAR) }, tremble(0.5, 0.95, 0.03)),
		active = moves.BodySlam.active,
		recover = moves.BodySlam.recover,
	}
end

-- SkyfallSlam B "Bound-and-pound": a short crouch, sprung with a twist. C "Coil": a long
-- low coil with both fists dug in, shaking.
do
	local s = leap(-0.85, 3.0, nil)
	local reach = paws(-1.6, 0.4, 0.5, 0.3)
	local twist = mix(s.crouch, mk({ root = { -0.95, -0.2, 0, 0.35 }, spine = { -0.1, 0.25 }, head = { -0.2, -0.2 }, jaw = 0.3, brow = -0.4, mane = { 0.1, 0.15, 0.2 } }), 0.8)
	variants.SkyfallSlam.B = {
		windup = ph(TIMING.SkyfallSlam[1], { K(0, RDY, ALL, R_RDY), K(0.3, s.crouch, ALL, paws(-1.0, 0.15, 0.3, 0.3), "out"), K(0.8, twist, ALL, paws(-1.0, 0.15, 0.3, 0.3), "inOut"), K(1, s.spring, HIND, R_REAR, "in") }, tremble(0.4, 0.85, 0.03, 11)),
		active = moves.SkyfallSlam.active,
		recover = moves.SkyfallSlam.recover,
	}
	local dig = paws(-1.0, 0.15, 0.5, 0.3)
	variants.SkyfallSlam.C = {
		-- (the coil keeps sinking through the hold instead of parking, and the spring arrives at its
		-- release speed rather than the "in" ease's double: the fists flung up at 628 studs/s)
		windup = ph(TIMING.SkyfallSlam[1], { K(0, RDY, ALL, R_RDY), K(0.25, mix(s.crouch, s.coil, 0.6), ALL, dig, "h1,0.3"), K(0.82, s.coil, ALL, dig, "h0.3,0.3"), K(1, s.spring, HIND, R_REAR, "h0.4,1.4") }, tremble(0.3, 0.88, 0.05, 14)),
		active = moves.SkyfallSlam.active,
		recover = moves.SkyfallSlam.recover,
	}
	local _ = reach
end

ThunderApe.VARIANTS = variants
ThunderApe.VARIANT = { ClubSwing = "A", ThunderPound = "B", BodySlam = "C", SkyfallSlam = "C", StormCall = "A", Bound = "flank" }
function ThunderApe.setVariant(move: string, v: string)
	assert(variants[move] and variants[move][v], "no variant " .. move .. "." .. v)
	ThunderApe.VARIANT[move] = v
end
function ThunderApe.setAll(v: string)
	for move, list in variants do
		if list[v] then
			ThunderApe.VARIANT[move] = v
		end
	end
end

--------------------------------------------------------------------------------
-- Weight: a held windup breathes and trembles (the keys above), a crunch of anticipation
-- loads just before contact, and every impact dips the body and rebounds (applied before
-- planting, so the legs compress with it). Pound, Skyfall and Judgment hardest.

local DIP = { RushSwipe = 0.15, SkyfallSweep = 0.12, ThunderRushSkid = 0.1, SkyfallSlamSkid = 0.06, ClubSwing = 0.12, Backhand = 0.12, ThunderPound = 0.4, BodySlam = 0.15, SkyfallSlam = 0.35, Judgment = 0.5, ThunderLance = 0.1, BoulderHurl = 0.15, ThunderRush = 0.12, Bound = 0.12, Stagger = 0.1, ThunderRoar = 0.08, PhaseRoar = 0.1, Challenge = 0.05, StormCall = 0.05 }
local LOAD = { RushSwipe = 0.08, SkyfallSweep = 0.08, ClubSwing = 0.1, Backhand = 0.1, ThunderPound = 0.12, ThunderLance = 0.06 }
local function weightOverlay(move: string, phase: string)
	return function(u: number, secs: number, _): Pose
		if phase == "windup" then
			local crunch = bump(u, 0.8, 0.99) * (LOAD[move] or 0)
			return crunch > 0 and { JointRoot = R(-crunch, -crunch * 0.3) } or {}
		end
		local k = DIP[move] or 0
		if k == 0 or move == "Death" then
			return {}
		end
		local tc = secs + (if phase == "recover" and ThunderApe.durations[move] and not ({ BodySlam = 1, SkyfallSlam = 1, Judgment = 1, ThunderRush = 1, Bound = 1, StormCall = 1 })[move] then (ThunderApe.durations[move].active or 0) else 0)
		if phase == "active" and ({ BodySlam = 1, ThunderRush = 1, Bound = 1, SkyfallSlam = 1, Judgment = 1 })[move] then
			return {}
		end
		if phase == "recover" and ({ SkyfallSlam = 1, Judgment = 1, BodySlam = 1 })[move] then
			tc = secs -- the landing is the start of the recover
		end
		local dip = k * math.exp(-4 * tc) * math.max(0, math.sin(tc * TAU * 1.8))
		return { JointRoot = R(-dip, -dip * 0.6) }
	end
end
local wrapped: { [any]: boolean } = {}
for move, list in variants do
	for _, phases in list do
		for name, phase in phases do
			if not wrapped[phase] and phase.keys then
				wrapped[phase] = true
				local extra, old = weightOverlay(move, name), phase.overlay
				phase.overlay = function(u, secs, input)
					local out = if old then old(u, secs, input) else {}
					for j, cf in extra(u, secs, input) do
						out[j] = (out[j] or I) * cf
					end
					return out
				end
			end
		end
	end
end

ThunderApe.moves = moves
ThunderApe.durations = Quadruped.durations(moves)

--------------------------------------------------------------------------------
-- Sampling with OVERLAPPING ACTION. Brow, head, jaw, beard and the three mane tufts follow
-- the body late, each by its own lag (so the head leads, the tufts trail, the beard drags);
-- free forearms, fists and fingers whip behind the shoulder. The lag fades to zero at every
-- phase boundary so poses stay continuous and contact is never late. After a hit they ring
-- down (SETTLE).

local function phaseOf(move: string, phase: string, pick: string?): Phase
	local v = variants[move]
	local set = v and v[pick or ThunderApe.VARIANT[move] or "A"]
	local p = if set then set[phase] else nil
	if not p then
		local m = moves[move]
		p = m and m[phase]
	end
	assert(p, ("ThunderApe.sample: no %s.%s"):format(move, phase))
	return p :: Phase
end

local LAG_SEC = 0.09
local LAGS = {
	JointBrow = 0.6, JointJaw = 1.3, JointMane1 = 1.4, JointMane2 = 1.9, JointMane3 = 2.5, JointBeard = 2.2,
}
local ARM_LAGS = { Elbow = 0.6, Wrist = 1.2, Fingers = 1.9 }
local SETTLE = { RushSwipe = 0.9, SkyfallSweep = 0.9, ThunderRushSkid = 0.8, SkyfallSlamSkid = 0.6, ClubSwing = 0.9, Backhand = 0.9, ThunderPound = 1.6, BodySlam = 0.8, SkyfallSlam = 1.4, Judgment = 1.9, ThunderRush = 1.0, Bound = 0.8, BoulderHurl = 1.0, ThunderLance = 1.0, ThunderRoar = 0.6, PhaseRoar = 0.8, Challenge = 0.4, StormCall = 0.4, Stagger = 1.4 }
local NOLAG = { ThunderRush = { active = true } }
-- windups whose arms must land on their marks mid-phase (the chest beats, the boulder release):
-- no arm whip there
local EXACT_ARMS = { Challenge = true, ThunderRoar = true, PhaseRoar = true, BoulderHurl = true, SkyfallSweep = true }
-- (SkyfallSweep: its arm leaves the ground in the windup, and the whip read the planted wrist
-- for 0.1 s after, then snapped)

-- Easing. inOut is a sine here (peak speed 1.6x the mean) instead of the shared cubic
-- (3x): a 30-stud body that parks on every key and then dashes between them reads as
-- stiff and twitchy at once.
local EASE: { [string]: (number) -> number } = table.clone(Quadruped.EASE)
EASE.inOut = function(a)
	return 0.5 - 0.5 * math.cos(math.pi * a)
end
EASE.cubic = Quadruped.EASE.inOut -- the old snap, for strikes that want it
for name, f in SPLIT_EASE do
	EASE[name] = f
end
-- "h<m0>,<m1>": a cubic Hermite with the given start and end slopes (1 = the segment's mean
-- speed), so a key can hand its speed on to the next segment instead of parking on it
-- ("h0,0.4" eases in from rest and arrives still moving; "h0.4,0" leaves moving and parks)
setmetatable(EASE, { __index = function(t: any, name: string)
	local m0s, m1s = string.match(name, "^h([%d%.%-]+),([%d%.%-]+)$")
	if not m0s then
		return nil
	end
	local m0, m1 = tonumber(m0s) :: number, tonumber(m1s) :: number
	local f = function(a: number): number
		local a2, a3 = a * a, a * a * a
		return (a3 - 2 * a2 + a) * m0 + (-2 * a3 + 3 * a2) + (a3 - a2) * m1
	end
	rawset(t, name, f)
	return f
end })
local plantOf = Quadruped.plantOf

-- Turning and travel, from EnemyAnimator's motion input (before planting, so the legs follow):
-- * the head leads a turn of the root and the hips trail it (input.yawRate, rad/s, + to its left):
--   during a windup the server turns the root toward the landing, in the air it finishes the
--   twist (phase.lead scales it up there), in a skid it swings the body round.
-- * a hop leans: the windup loads the far side (input.boundSide, the server's BoundSide when it
--   sends one), the flight leans into the travel (input.vel in the root's frame) and straightens
--   before touchdown.
local function motionLayer(pose: Pose, p: any, u: number, input: any)
	local rate = input.yawRate
	if type(rate) == "number" and rate ~= 0 then
		local k = math.clamp(rate * 0.12, -0.4, 0.4) * (p.lead or 0.6)
		if p.mirror and (input.side or 1) < 0 then
			k = -k -- the pose is mirrored after planting
		end
		pose.JointSpine = (pose.JointSpine or I) * A(0, 0.55 * k, 0)
		pose.JointRoot = (pose.JointRoot or I) * A(0, -0.2 * k, 0)
		pose.JointHead = (pose.JointHead or I) * A(0, 0.6 * k, 0)
	end
	local lean = p.lean
	if lean then
		local s0 = if type(input.boundSide) == "number" then math.clamp(input.boundSide, -1, 1) else 0
		local v = input.vel
		local sv = if typeof(v) == "Vector3" and v.Magnitude > 4 then math.clamp(1.6 * v.X / v.Magnitude, -1, 1) else s0
		local roll
		if lean == "windup" then
			roll = 0.12 * s0 * smooth(0.25, 0.95, u)
		else
			local e = smooth(0, 0.3, u)
			roll = 0.12 * s0 * (1 - e) - 0.24 * sv * e * (1 - smooth(0.7, 1, u))
		end
		pose.JointRoot = (pose.JointRoot or I) * A(0, 0, roll)
		pose.JointSpine = (pose.JointSpine or I) * A(0, 0, 0.4 * roll)
	end
end

-- the blended key pose at u (overlay applied, not planted, not mirrored) and its key pair
local function blendKeys(p: Phase, u: number, input: Input): (Pose, any, any, number)
	local keys = p.keys
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
	if p.overlay then
		local secs = u * (input.duration or p.duration)
		for name, cf in p.overlay(u, secs, input) do
			pose[name] = (pose[name] or I) * cf
		end
	end
	motionLayer(pose, p, u, input)
	return pose, a, b, alpha
end

-- The keyed pose (unplanted) `back` seconds before u, reaching back into the phases before it:
-- the family plays one attack's windup, active and recover straight on (`seamless`), so a lag
-- read across a phase boundary is continuous instead of fading to nothing at every release.
local PREV_PHASE = { active = "windup", recover = "active" }
local PHASE_IX = { windup = 1, active = 2, recover = 3 }
local function phaseOpt(move: string, phase: string, pick: string?): Phase?
	local v = variants[move]
	local set = v and v[pick or ThunderApe.VARIANT[move] or "A"]
	local p = if set then set[phase] else nil
	if not p then
		local m = moves[move]
		p = m and m[phase]
	end
	return p
end
local function keyedBack(move: string, phase: string, u: number, input: Input, pick: string?, back: number): Pose
	local p = phaseOpt(move, phase, pick) :: Phase
	local dur = (input :: any).duration or p.duration
	local t = u * dur - back
	local name = phase
	while t < 0 do
		local prev = PREV_PHASE[name]
		local pp = if prev then phaseOpt(move, prev, pick) else nil
		local pd = if pp and prev then ((TIMING[move] and TIMING[move][PHASE_IX[prev]]) or pp.duration) else 0
		if not pp or not prev or pd <= 0 then
			t = 0
			break
		end
		name, p, dur = prev, pp, pd
		t += pd
	end
	local x = table.clone(input :: any)
	x.duration = dur
	return (blendKeys(p, math.clamp(t / dur, 0, 1), x))
end

local NEXT_PHASE = { windup = "active", active = "recover" }
local function keyedAhead(move: string, phase: string, u: number, input: Input, pick: string?, ahead: number): Pose
	local p = phaseOpt(move, phase, pick) :: Phase
	local dur = (input :: any).duration or p.duration
	local t = u * dur + ahead
	local name = phase
	while t > dur do
		local nxt = NEXT_PHASE[name]
		local np = if nxt then phaseOpt(move, nxt, pick) else nil
		local nd = if np and nxt then ((TIMING[move] and TIMING[move][PHASE_IX[nxt]]) or np.duration) else 0
		if not np or nd <= 0 then
			t = dur
			break
		end
		t -= dur
		name, p, dur = nxt :: string, np, nd
	end
	local x = table.clone(input :: any)
	x.duration = dur
	return (blendKeys(p, math.clamp(t / dur, 0, 1), x))
end

-- OVERLAP of the body chain: the hips LEAD and the skull TRAILS the chest. The chest keeps the
-- keys' world aim exactly (so the arms on it, planted or striking, land on their keys); the root
-- turns to where the keys will have it OVERLAP[1] s later (the spine takes up the difference), and
-- the skull points where the keys had it OVERLAP[2] s ago. Before planting, so the hind legs solve
-- under the leading hips. (A lagged CHEST was tried first: at a slam or a throw it left the
-- shoulders so high that the planted fists dragged the hips 8 studs down or flipped an elbow.)
local OVERLAP = { 0.05, 0.1 }
-- moves whose hips lead less: a bound's shove off nearly straight hind legs (a hip already turned
-- to the flight pushed a planted knee through straight, 54 degrees in a frame)
local LEAD_SCALE = { Bound = 0 }
local HEAD_CAP = 1.4 -- rad, soft: the most the skull trails its keyed aim (at 0.6-1.0 a slam or a throw saturated it and the skull peaked with the chest)
local function capped(onTime: CFrame, lagged: CFrame, cap: number): CFrame
	local axis, ang = (onTime:Inverse() * lagged):ToAxisAngle()
	-- (near zero ToAxisAngle can hand back a NaN axis: one NaN skull pose in the rush)
	if math.abs(ang) < 1e-4 or axis.X ~= axis.X or ang ~= ang then
		return lagged
	end
	return onTime * CFrame.fromAxisAngle(axis, cap * math.tanh(ang / cap))
end
-- how far the trailing skull hangs pitched down below its keys (rad), for the beard (secondary)
local headDrop = 0
local function overlap(pose: Pose, ahead: Pose, back: Pose)
	local root = pose.JointRoot or I
	local chest = root.Rotation * (pose.JointSpine or I)
	local lead = (ahead.JointRoot or I).Rotation
	pose.JointRoot = CFrame.new(root.Position) * lead
	pose.JointSpine = lead:Inverse() * chest
	local skull = capped(chest * (pose.JointHead or I), (back.JointRoot or I).Rotation * (back.JointSpine or I) * (back.JointHead or I), HEAD_CAP)
	local head = chest:Inverse() * skull
	-- (a guard: a NaN skull aim turned up in StormCall C's recover; keep the keyed head then)
	local probe = head.X + head.XVector.X + head.YVector.Y + head.ZVector.Z
	headDrop = 0
	if probe == probe then
		local dx = ((pose.JointHead or I):Inverse() * head):ToEulerAnglesXYZ()
		headDrop = math.max(0, -dx)
		pose.JointHead = head
	end
end

-- plantLegs re-solves a planted limb's middle joint onto the ground, so a raised spot (`lifted`)
-- only aimed it. Lift those limbs to their spot's height: a landing limb reaches for the ground
-- above it, then meets it.
local function liftPlanted(pose: Pose, plant: { [string]: number }, reach: { [string]: Vector3 })
	for tag, w in plant do
		local r = reach[tag]
		if w > 0.001 and r and r.Y > 0.001 then
			rig.solveLeg(pose, LEGS[tag], w, r.Y, if LEGS[tag].front then -0.2 * r.Y else -0.3 * r.Y)
		end
	end
end

-- Keyed sampling with a smoother plant blend than Quadruped.samplePhase: that one blends the
-- plant WEIGHTS, and a two-joint solve at a half weight overshoots (an elbow flips through 1.5 rad
-- in a frame when a free arm lands). Here each leg is planted or free per key; across a key pair
-- where that differs, both ends are solved with their own plants and the SOLVED poses are blended.
-- a key's pose with its own limbs planted on its own spots (no overlay, no motion), cached per key
local solvedCache: { [any]: Pose } = setmetatable({}, { __mode = "k" }) :: any
local function solvedKey(k: any): Pose
	local c = solvedCache[k]
	if c then
		return c
	end
	local q = table.clone(k.pose)
	local plant = plantOf(k.plant)
	local reach = {}
	for _, tag in ALL do
		reach[tag] = (k.reach and k.reach[tag]) or Vector3.zero
	end
	rig.plantLegs(q, plant, true, reach)
	liftPlanted(q, plant, reach)
	solvedCache[k] = q
	return q
end

local function plantedSample(p: Phase, u: number, input: Input, lags: { Pose }?): (Pose, { [string]: number }, { [string]: number })
	local pose, a, b, alpha = blendKeys(p, u, input)
	if lags then
		overlap(pose, lags[1], lags[2])
	end
	-- the chest never stops breathing, even in a held pose (before planting, so the fists stay put)
	local clock = os.clock()
	pose.JointSpine = (pose.JointSpine or I) * A(0.018 * math.sin(clock * 1.35), 0.01 * math.sin(clock * 0.6), 0)
	local pa, pb = plantOf(a.plant), plantOf(b.plant)
	local reach, weights, same, changing = {}, {}, true, {}
	for _, tag in ALL do
		local ra = (a.reach and a.reach[tag]) or Vector3.zero
		local rb = (b.reach and b.reach[tag]) or Vector3.zero
		reach[tag] = ra:Lerp(rb, alpha)
		weights[tag] = pa[tag] + (pb[tag] - pa[tag]) * alpha
		if pa[tag] ~= pb[tag] then
			same = false
		end
		if pb[tag] > pa[tag] then
			changing[tag] = alpha -- reaching down to plant: how far along
		end
	end
	local out: Pose
	if same then
		out = pose
		rig.plantLegs(out, pa, p.air, reach)
		liftPlanted(out, pa, reach)
	else
		-- Each end's root drop counts a limb planted at both ends in full, and a limb planted at
		-- one end only by how near that end is: an arm that is about to lift (or still reaching
		-- for the ground) no longer drags the whole body down. A rear-up from all fours dropped the
		-- root for the planted arms of the pitched torso, and the blend sank the thighs 2.8 studs.
		local function solveEnd(q: Pose, mine: { [string]: number }, other: { [string]: number }, keep: number, keepArms: number)
			local drop = 0
			for _, tag in ALL do
				if mine[tag] > 0 then
					local k = if other[tag] > 0 then 1 elseif LEGS[tag].front then keepArms else keep
					drop = math.max(drop, rig.reachShort(q, tag, reach[tag]) * k)
				end
			end
			if drop > 0 then
				q.JointRoot = CFrame.new(0, -drop, 0) * (q.JointRoot or I)
			end
			-- no floor clamp here: at either end it re-solved a free arm passing near the ground
			-- onto another bend, and the blend between the ends dipped the fist 2.8 studs under
			rig.plantLegs(q, mine, true, reach, true)
			liftPlanted(q, mine, reach)
		end
		local x, y = table.clone(pose), pose
		-- (an arm lifting off stops holding the body up fast: weighted 1 - alpha, the arms of a
		-- torso rearing up off all fours kept the hips dropped and sank the thighs 1.6 studs)
		solveEnd(x, pa, pb, 1 - alpha, (1 - alpha) ^ 3)
		solveEnd(y, pb, pa, alpha, alpha)
		-- A limb landing (or lifting off) is solved against the body as it is NOW, and a body still
		-- reared up or pitched away puts that solve on the other bend (an elbow at -0.8 that snapped
		-- to +0.4 in a frame as the body came down, 70 degrees). Far from its planted end it takes the
		-- limb's solve at its own key instead (planted there, so on the right bend), and hands over to
		-- the live solve over the rest of the way (over the last 40% only, a short plant stepped 51).
		for _, tag in FRONT do -- (the arms: a hind leg handed over this way flipped a knee 91 degrees)
			if pa[tag] ~= pb[tag] then
				local landing = pb[tag] > pa[tag]
				local k = if landing then b else a
				local live = if landing then y else x
				local s = if landing then smooth(0.25, 1, alpha) else 1 - smooth(0, 0.75, alpha)
				if s < 0.999 then
					local solved = solvedKey(k)
					local leg = LEGS[tag]
					for _, j in { leg.upper, leg.mid, leg.foot } do
						live[j] = (solved[j] or I):Lerp(live[j] or I, s)
					end
				end
			end
		end
		out = {}
		for name, cf in x do
			out[name] = cf:Lerp(y[name] or I, alpha)
		end
		for name, cf in y do
			if not x[name] then
				out[name] = I:Lerp(cf, alpha)
			end
		end
		-- the blended root and the blended leg angles don't agree: re-plant the limbs planted at
		-- both ends onto their spots. No floor clamp on the limbs changing (its foot levelling
		-- snapped a wrist 88 degrees in a frame): a free arm blended toward a planted one swings
		-- through the ground unless it is folded first (see the combo's recover).
		local common = {}
		for _, tag in ALL do
			common[tag] = if pa[tag] > 0 and pb[tag] > 0 then 1 else 0
		end
		rig.plantLegs(out, common, true, reach)
		liftPlanted(out, common, reach)
		-- a limb changing plant that would dip under the ground bends its middle joint to stay on it
		-- (the hand or foot keeps its blended angle: the solver's levelling snapped a wrist 88). The
		-- solve takes the bend nearest the authored one, which the key-solve handover above keeps
		-- on the planted side. (Pulling the limb toward its live planted solve instead jumped the
		-- shoulder 50 degrees the frame a fast fist reached the ground.) Not in the air: there it
		-- re-solved a hind leg lifting off nearly straight onto its other bend (a knee 91 degrees).
		if not p.air then
			for _, tag in ALL do
				local leg = LEGS[tag]
				if pa[tag] ~= pb[tag] and rig.soleY(out, leg) < -0.005 then
					local hand = out[leg.foot] or I
					rig.solveLeg(out, leg, 1)
					-- (levelled by how near the planted end is: a tilted fist kept its corners 0.6 under)
					local near = if pb[tag] > pa[tag] then alpha else 1 - alpha
					out[leg.foot] = hand:Lerp(out[leg.foot] or I, near * near)
				end
			end
		end
	end
	if p.mirror and (input.side or 1) < 0 then
		out = mirror(out)
		weights = { FL = weights.FR, FR = weights.FL, BL = weights.BR, BR = weights.BL }
		changing = { FL = changing.FR, FR = changing.FL, BL = changing.BR, BR = changing.BL }
	end
	return out, weights, changing
end

local function secondary(pose: Pose, move: string, phase: string, u: number, input: Input, p: Phase, plant: any, changing: any, pick: string?, tail: number)
	local dur = input.duration or p.duration
	local secs = u * dur
	if NOLAG[move] and NOLAG[move][phase] then
		return
	end
	local fade = if move == "Death" then smooth(0, 0.1, u) else smooth(0, 0.2, u) * (1 - smooth(0.8, 1, u))
	if tail > 0.01 then
		local cache: { [number]: Pose } = {}
		local function at(k: number): Pose
			local c = cache[k]
			if not c then
				c = keyedBack(move, phase, u, input, pick, LAG_SEC * k * tail)
				if p.mirror and (input.side or 1) < 0 then
					c = mirror(c)
				end
				cache[k] = c
			end
			return c
		end
		for name, k in LAGS do
			local lag = at(k)
			pose[name] = lag[name] or pose[name]
		end
		-- free forearms, fists and fingers whip behind the shoulder, read off the PLANTED pose a
		-- moment ago and weighted by how free the arm is (both continuous, so no frame jumps)
		if fade > 0.01 and not (phase == "windup" and EXACT_ARMS[move]) then
			local armCache: { [number]: Pose } = {}
			for _, side in { "L", "R" } do
				local tag = "F" .. side
				-- cubed: an arm reaching down to plant drops the lag early (half planted, half a
				-- lag read 0.17 s back straightened its elbow through the ground)
				-- and it fades out early while the arm reaches down to plant (between two keys)
				local free = (1 - (plant[tag] or 0)) ^ 3 * (1 - smooth(0, 0.35, changing[tag] or 0))
				if free > 0.001 then
					for part, k in ARM_LAGS do
						local lag = armCache[k]
						if not lag then
							-- a few frames, never most of a short phase (0.17 s back in the combo's
							-- 0.33 s recover held the forearm straight while the shoulder swung back)
							lag = (plantedSample(p, math.clamp(u - math.min(LAG_SEC * k, 0.25 * dur) * fade / dur, 0, 1), input))
							armCache[k] = lag
						end
						local name = "Joint" .. part .. tag
						if lag[name] and pose[name] then
							pose[name] = pose[name]:Lerp(lag[name], free)
						end
					end
				end
			end
		end
	end
	-- a skull trailing pitched down below its keys swings the beard forward with it, clear of the
	-- chest drum (mk does this for the keyed head; the trailing head put the beard 2 studs in)
	if headDrop > 0 then
		pose.JointBeard = (pose.JointBeard or I) * A(1.0 * headDrop)
	end
	local amp = SETTLE[move]
	if amp and phase ~= "windup" then
		local tc = secs + (if phase == "recover" and ThunderApe.durations[move] and not ({ SkyfallSlam = 1, Judgment = 1, BodySlam = 1, StormCall = 1, Bound = 1 })[move] then (ThunderApe.durations[move].active or 0) else 0)
		local function ring(delay: number, hz: number): number
			local t = math.max(0, tc - delay)
			return math.sin(t * TAU * hz) * math.exp(-3.2 * t) * amp
		end
		pose.JointHead = (pose.JointHead or I) * A(-0.1 * ring(0.1, 2.6), 0.04 * ring(0.12, 2.0)) -- (late: the head dips after the body, not with it)
		pose.JointJaw = (pose.JointJaw or I) * A(-0.12 * math.max(0, ring(0.05, 3.2)))
		pose.JointBrow = (pose.JointBrow or I) * A(0.1 * ring(0.04, 3.0))
		pose.JointBeard = (pose.JointBeard or I) * A(0.3 * ring(0.08, 2.4))
		pose.JointMane1 = (pose.JointMane1 or I) * A(0.18 * ring(0.06, 2.6))
		pose.JointMane2 = (pose.JointMane2 or I) * A(0.22 * ring(0.1, 2.4))
		pose.JointMane3 = (pose.JointMane3 or I) * A(0.26 * ring(0.14, 2.2))
	end
	-- held windups also shake the tufts and beard a little
	if phase == "windup" then
		local held = smooth(0.3, 0.5, u) * (1 - smooth(0.92, 1, u))
		if held > 0 then
			pose.JointMane2 = (pose.JointMane2 or I) * A(0.035 * held * math.sin(secs * 7.3))
			pose.JointMane3 = (pose.JointMane3 or I) * A(0.045 * held * math.sin(secs * 6.1 + 1))
			pose.JointBeard = (pose.JointBeard or I) * A(0.05 * held * math.sin(secs * 5.3 + 2))
		end
	end
	-- and nothing is ever frozen: the tufts stir, the beard sways, the brow twitches and the
	-- head drifts on the wall clock (continuous across every phase and move)
	if move ~= "Death" or u < 0.85 then
		local c = os.clock()
		pose.JointMane1 = (pose.JointMane1 or I) * A(0.035 * math.sin(c * 1.9), 0, 0.03 * math.sin(c * 1.3 + 0.5))
		pose.JointMane2 = (pose.JointMane2 or I) * A(0.045 * math.sin(c * 1.7 + 0.8), 0, 0.035 * math.sin(c * 1.1 + 1.4))
		pose.JointMane3 = (pose.JointMane3 or I) * A(0.055 * math.sin(c * 1.5 + 1.6), 0, 0.04 * math.sin(c * 0.9 + 2.2))
		pose.JointBeard = (pose.JointBeard or I) * A(0.04 * math.sin(c * 1.2 + 0.3), 0, 0.03 * math.sin(c * 0.8))
		pose.JointBrow = (pose.JointBrow or I) * A(0.025 * math.sin(c * 0.7) * math.sin(c * 2.3))
		pose.JointHead = (pose.JointHead or I) * A(0.012 * math.sin(c * 0.9 + 1), 0.02 * math.sin(c * 0.45), 0)
	end
end

-- moves picked by the server's BoundMode, and moves whose turn follows the target's side
local MODED = { Bound = true }
local SIDED = { ThunderRush = true, ThunderRushSkid = true, SkyfallSlamSkid = true }

function ThunderApe.sample(move: string, phase: string, u: number, input: Input?): Pose
	local inp: Input = input or {}
	u = math.clamp(u, 0, 1)
	local x = inp :: any
	local pick: string? = nil
	if MODED[move] and type(x.mode) == "string" and variants[move][x.mode] then
		pick = x.mode
	elseif SIDED[move] and (x.side or 1) < 0 and variants[move].L then
		pick = "L"
	end
	local p = phaseOf(move, phase, pick)
	-- the lags fade out over the end of the last phase, into the hand-off to idle
	local last = phase == "recover" or (phase == "active" and phaseOpt(move, "recover", pick) == nil)
	local tail = if last then 1 - smooth(0.6, 0.9, u) else 1
	-- the hips' lead also eases in over a windup's first 0.12 s: a chained windup starts from the
	-- held last frame of the blow before, and a lead read straight into the next key popped there
	local lead = (if phase == "windup" then smooth(0, 0.12, u * ((inp :: any).duration or 1)) else 1) * (LEAD_SCALE[move] or 1)
	-- (not over a cyclic overlay like the rush's gallop: a hip turned to the stride 0.05 s ahead put
	-- the planted feet 0.8 under the floor)
	local lags = if NOLAG[move] and NOLAG[move][phase] then nil else { keyedAhead(move, phase, u, inp, pick, OVERLAP[1] * tail * lead), keyedBack(move, phase, u, inp, pick, OVERLAP[2] * tail) }
	headDrop = 0
	local pose, plant, changing = plantedSample(p, u, inp, lags)
	secondary(pose, move, phase, u, inp, p, plant, changing, pick, tail)
	return pose
end

ThunderApe.loops = loops
ThunderApe.GAITS = { run = { off = RUN_OFF, stance = RUN_STANCE }, walk = { off = WALK_OFF, stance = WALK.stance }, circle = { off = WALK_OFF, stance = CIRCLE.stance } }
ThunderApe.plant = rig.plant
ThunderApe.rig = rig
ThunderApe.mk = mk
function ThunderApe.scaled(pose: Pose, scale: number): Pose
	return Quadruped.scaled(pose, scale)
end

return ThunderApe
