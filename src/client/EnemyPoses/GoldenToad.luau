--!strict
-- Procedural pose tables for the Golden Toad (Enemies.GoldenToad, 1x, 16 joints; see
-- art/enemies/beasts/RIGS.md "Golden Toad" and art/enemies/beasts/poses_golden_toad.md for
-- the notes). Same FORMAT and API as Wolf.luau (read its header). Real studs (Scale 1).
--
-- FAMILIES line for EnemyAnimator (the designer registers it):
--   FAMILIES.GoldenToad = { poses = GoldenToad, scale = 1, runFrom = 5,
--     moves = { tongueLash = "TongueLash", gulp = "Gulp", bogCroak = "BogCroak",
--               miasmaLob = "MiasmaLob", hop = "Hop" } }
--   (Hop's active is `air`: the client lifts the body; the module adds no arc to it. The
--   run loop is a hop chain and DOES carry its own JointRoot arc, 0.9 studs.)
--
-- RIG: faces -Z, its left is -X. Every joint frame is identity in model space. +X pitch
-- tips the front up (a head lifts, the thigh swings its knee forward); the jaw opens on +X
-- (0 to 0.9); the lids drop on +X. JointTongue and JointSac are TRANSLATION only: the
-- tongue stub rests inside the mouth and slides along -Z up to 14 studs (open the jaw
-- first); the sac slides (0, -0.5, -0.6) when swollen. Three legs: one centred front leg
-- (JointLegF + JointFootF) and two folded hind legs (thigh forward, shin back, foot).
-- Move keys use plant tags "FL" (the one front leg), "BL", "BR"; no move is mirrored.
--
-- PLANTING: the hind legs use the shared Quadruped solver (two-joint IK, root drop,
-- floor clamp); the front leg its own (a single column: it swings from the hip toward
-- the foot spot and slides along its axis for the rest). A planted foot sits on its rest
-- spot + reach. A foot that is not planted but would sink is planted where it is.
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt)
--   TongueLash  windup 0.7: 0-0.15 gathers (a squat, the head dips), 0.15-0.5 the head
--                 lifts, the jaw opens and the sac swells out; 0.5-0.7 a held beat with
--                 the sac trembling. active 0.15: JointTongue z 0 -> -14 over 0.1 s (u
--                 0.67), held; the head thrusts, the haunches push. recover 0.9: the
--                 tongue recoils in 0.3 s, the jaw snaps shut (the gulp), the sac
--                 pulses as it swallows, the head and body settle.
--   Gulp        windup 0.35 (head reared back, jaw wide), active 0.1 (a lunging snap),
--                 recover 0.8 (chewing, a swallow, the settle).
--   BogCroak    windup 1.0: crouch, the sac inflates in heaves to its widest, head up,
--                 lids lifted; held to 1.0. active 0.1: the croak (head thrust, the sac
--                 crushes, the back jiggles). recover 0.8: decaying throat pulses.
--   MiasmaLob   windup 1.0: a deep crouch, retching heaves, then the head rears back with
--                 the jaw wide (0.4-0.57); the GOB LEAVES THE MOUTH AT u = 0.6 s (the head
--                 snaps forward and up), 0.8-1.0 follow-through. active 0.1, recover 0.8.
--   Hop         active 0.35 (air, the backslide): push off, tuck, reach for the ground.
--               recover 0.3 (not in the def; the landing compress and back jiggle).
--   Stagger     active 0.3 (input.side tips it)
--   Death       active 1.0, then hold u = 1 (the toad sags flat, tongue lolling out)
-- LOOPS: idle (a squat, sac breathing, blinks, throat flutter); walk (a three-point
--   shuffle, one leg at a time: front, left hind, right hind; the weight shifts and the
--   head bobs) up to ~4 studs/s; run (a hop chain, ~7 studs/s); circle = walk's shuffle
--   sideways is NOT provided (the def has no circle); loops.circle aliases walk.
--
-- API (as Wolf.luau)
--   GoldenToad.sample(move, phase, u, input?) -> Pose
--   GoldenToad.loops.idle(clock, speed, input?) / walk(phase, speed) / run(phase, speed) /
--     circle (= walk)
--   GoldenToad.gaitRate(loop, speed, scale?), .scaled(pose, scale), .plant(pose, legs?, reach?)
--   GoldenToad.moves, .durations, .JOINTS

local Quadruped = require(script.Parent.Quadruped)

local GoldenToad = {}

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Phase = Quadruped.Phase

local TAU = Quadruped.TAU
local I = CFrame.identity
local A = Quadruped.A
local EASE, bump, smooth, with, hash = Quadruped.EASE, Quadruped.bump, Quadruped.smooth, Quadruped.with, Quadruped.hash
local V = Vector3.new

GoldenToad.JOINTS = {
	"JointRoot", "JointBack", "JointHead", "JointJaw", "JointTongue", "JointSac", "JointEyeL", "JointEyeR",
	"JointLegF", "JointFootF", "JointLegBL", "JointLowerLegBL", "JointFootBL", "JointLegBR", "JointLowerLegBR", "JointFootBR",
}

------------------------------------------------------------------------------------
-- Skeleton (ground at Y 0; from art/enemies/beasts/rig_golden_toad.luau)

local ROOTP = V(0, 2.5, 0.8)
local HIPS = { BL = V(-1.7, 2.4, 2.3), BR = V(1.7, 2.4, 2.3) }
local KNEES = { BL = V(-2.2, 1.5, 0.7), BR = V(2.2, 1.5, 0.7) }
local ANKLES = { BL = V(-2.3, 0.72, 3.5), BR = V(2.3, 0.72, 3.5) }
local THIGHJ = { BL = "JointLegBL", BR = "JointLegBR" }
local SHINJ = { BL = "JointLowerLegBL", BR = "JointLowerLegBR" }
local HFOOTJ = { BL = "JointFootBL", BR = "JointFootBR" }
local P = { JointRoot = ROOTP }
local HSOLE = { V(-0.9, -0.72, -1.8), V(0.9, -0.72, -1.8), V(-0.9, -0.72, 0.8), V(0.9, -0.72, 0.8), V(-0.85, -0.72, -2.35), V(0.85, -0.72, -2.35), V(0, -0.72, -2.35) }

local function wrap(a: number): number
	return (a + math.pi) % TAU - math.pi
end
local function ang(v: Vector3): number
	return math.atan2(v.Z, v.Y)
end

local function hipBase(pose: Pose, tag: string): CFrame
	return CFrame.new(ROOTP) * (pose.JointRoot or I) * CFrame.new(HIPS[tag] - ROOTP)
end
local function hindSoleY(pose: Pose, tag: string): number
	local f = hipBase(pose, tag) * (pose[THIGHJ[tag]] or I) * CFrame.new(KNEES[tag] - HIPS[tag]) * (pose[SHINJ[tag]] or I)
		* CFrame.new(ANKLES[tag] - KNEES[tag]) * (pose[HFOOTJ[tag]] or I)
	local lo = math.huge
	for _, v in HSOLE do
		lo = math.min(lo, (f * v).Y)
	end
	return lo
end
local function hindAnkle(pose: Pose, tag: string): Vector3
	return (hipBase(pose, tag) * (pose[THIGHJ[tag]] or I) * CFrame.new(KNEES[tag] - HIPS[tag]) * (pose[SHINJ[tag]] or I) * CFrame.new(ANKLES[tag] - KNEES[tag])).Position
end

-- Two-bone solve in the leg's plane (thigh to knee to ankle; the knee kept in front of the
-- hip-ankle line, -Z), then the foot levelled (flex tips the toes up), blended in by w.
local function solveHind(pose: Pose, tag: string, target: Vector3, w: number, flex: number?, recheck: number?)
	local B = hipBase(pose, tag)
	local t = B:PointToObjectSpace(target)
	local u, d = KNEES[tag] - HIPS[tag], ANKLES[tag] - KNEES[tag]
	local l1, l2 = math.sqrt(u.Y * u.Y + u.Z * u.Z), math.sqrt(d.Y * d.Y + d.Z * d.Z)
	local dist = math.clamp(math.sqrt(t.Y * t.Y + t.Z * t.Z), math.abs(l1 - l2) + 1e-3, (l1 + l2) * 0.985)
	local phi = math.atan2(t.Z, t.Y)
	local alpha = math.acos(math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1))
	local upperDir = phi + alpha
	local ky, kz = l1 * math.cos(upperDir), l1 * math.sin(upperDir)
	local lowerDir = math.atan2(t.Z - kz, t.Y - ky)
	local thigh = wrap(upperDir - ang(u))
	local shin = wrap(lowerDir - ang(d) - thigh)
	local kneeFrame = B * CFrame.Angles(thigh, 0, 0) * CFrame.new(u) * CFrame.Angles(shin, 0, 0)
	local foot = kneeFrame.Rotation:Inverse() * CFrame.Angles(flex or 0, 0, 0)
	pose[THIGHJ[tag]] = (pose[THIGHJ[tag]] or I):Lerp(CFrame.Angles(thigh, 0, 0), w)
	pose[SHINJ[tag]] = (pose[SHINJ[tag]] or I):Lerp(CFrame.Angles(shin, 0, 0), w)
	pose[HFOOTJ[tag]] = (pose[HFOOTJ[tag]] or I):Lerp(foot, w)
	-- the knee ball (r 0.95), the haunch (r 1.25) and the shin's ends must clear the ground
	if w > 0.99 and (recheck or 0) < 3 then
		local th = B * (pose[THIGHJ[tag]] or I)
		local kf = th * CFrame.new(u) * (pose[SHINJ[tag]] or I)
		local low = math.min((th * CFrame.new(u)).Y - 0.95, B.Y - 1.25, (kf * CFrame.new(d)).Y - 0.65)
		for _, sx in { -0.7, 0.7 } do
			for _, sy in { -0.65, 0.65 } do
				low = math.min(low, (kf * V(sx, sy, 0)).Y, (kf * CFrame.new(d) * V(sx, sy, 0)).Y)
			end
		end
		if low < -0.005 then
			solveHind(pose, tag, target - V(0, low, 0), w, flex, (recheck or 0) + 1)
		end
	end
end

-- the front leg: hip, ankle, sole
local FHIP, FANKLE = V(0, 2.3, -0.8), V(0, 0.75, -1.0)
local FSOLE = { V(-1.2, -0.75, -1.6), V(1.2, -0.75, -1.6), V(-1.2, -0.75, 0.6), V(1.2, -0.75, 0.6), V(-1.0, -0.75, -2.2), V(0, -0.75, -2.2), V(1.0, -0.75, -2.2) }

local function fHipBase(pose: Pose): CFrame
	return CFrame.new(P.JointRoot) * (pose.JointRoot or I) * CFrame.new(FHIP - P.JointRoot)
end
local function fAnkleFrame(pose: Pose): CFrame
	return fHipBase(pose) * (pose.JointLegF or I) * CFrame.new(FANKLE - FHIP)
end
local function fSoleY(pose: Pose): number
	local f = fAnkleFrame(pose) * (pose.JointFootF or I)
	local lo = math.huge
	for _, v in FSOLE do
		lo = math.min(lo, (f * v).Y)
	end
	return lo
end

-- the front leg onto target (model space), foot level (+ flex tips the toes up), blended by w
local function solveFront(pose: Pose, target: Vector3, w: number, flex: number?, recheck: number?)
	local B = fHipBase(pose)
	local Hw = B.Position
	local v0 = FANKLE - FHIP
	local L = V(0, v0.Y, v0.Z).Magnitude
	local Rb = B.Rotation
	local a, r = 0, 0
	local e = Vector3.zero
	for _ = 1, 5 do
		local Rw = CFrame.Angles(a, 0, 0) * CFrame.Angles(0, 0, r)
		e = (target - Hw) - Rw * v0
		a = math.clamp(a - e.Z / (L * math.max(math.cos(a), 0.3)), -0.3, 0.3)
		r = math.clamp(r + e.X / L, -0.3, 0.3)
	end
	local Rw = CFrame.Angles(a, 0, 0) * CFrame.Angles(0, 0, r)
	e = (target - Hw) - Rw * v0
	local upper = CFrame.new(Rb:Inverse() * e) * (Rb:Inverse() * Rw)
	local foot = Rw:Inverse() * CFrame.Angles(flex or 0, 0, 0)
	pose.JointLegF = (pose.JointLegF or I):Lerp(upper, w)
	pose.JointFootF = (pose.JointFootF or I):Lerp(foot, w)
	-- the knee ball (r 0.75 at the ankle + 0.05) must clear the ground when the column tilts
	if w > 0.99 and (recheck or 0) < 3 then
		-- the column's bottom face (1.6 square) and the knee ball (r 0.75) must clear the ground
		local fr = fAnkleFrame(pose)
		local low = fr.Y - 0.8
		low = math.min(low, (fr * V(0, 0.05, 0)).Y - 0.75)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				low = math.min(low, (fr * V(sx * 0.8, 0, sz * 0.8)).Y)
			end
		end
		if low < -0.005 then
			solveFront(pose, target - V(0, low, 0), w, flex, (recheck or 0) + 1)
		end
	end
end

-- plant: weights { FL = front, BL, BR }, reach: offsets (x, lift, z) from the rest foot spots
local function plantAll(pose: Pose, plant: Quadruped.Plant, _air: boolean?, reach: { [string]: Vector3 }?, flex: { [string]: number }?)
	for _, tag in { "BL", "BR" } do
		local w = plant[tag] or 0
		if w > 0.001 then
			solveHind(pose, tag, ANKLES[tag] + ((reach and reach[tag]) or Vector3.zero), w, flex and flex[tag])
		end
	end
	local w = plant.FL or 0
	if w > 0.001 then
		solveFront(pose, FANKLE + ((reach and reach.FL) or Vector3.zero), w, flex and flex.FL)
	end
	-- the floor: any foot (planted, blending or hanging) that would dip below the ground is planted
	-- where it is. Airborne poses are lifted by the client, so this only keeps the soles off the
	-- standing line.
	for _, tag in { "BL", "BR" } do
		for _ = 1, 3 do
			local low = hindSoleY(pose, tag)
			if low >= -0.005 then
				break
			end
			solveHind(pose, tag, hindAnkle(pose, tag) - V(0, low, 0), 1)
		end
	end
	if fSoleY(pose) < -0.005 then
		solveFront(pose, fAnkleFrame(pose).Position - V(0, fSoleY(pose), 0), 1)
	end
end

local ALL = { "FL", "BL", "BR" }
local moves: { [string]: { [string]: Phase } } = {}
GoldenToad.moves = moves

function GoldenToad.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = moves[move]
	local p = m and m[phase]
	assert(p, ("GoldenToad.sample: no %s.%s"):format(move, phase))
	local pose, plant, reach = Quadruped.samplePhase(p, u, input or {})
	plantAll(pose, plant, p.air, reach)
	return pose
end

function GoldenToad.plant(pose: Pose, legs: { string }?, reach: { [string]: Vector3 }?): Pose
	plantAll(pose, Quadruped.plantOf(legs or ALL), false, reach)
	return pose
end

------------------------------------------------------------------------------------
-- Poses

local function RT(x: number, y: number, z: number, pitch: number?, yaw: number?, roll: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(pitch or 0, yaw or 0, roll or 0)
end
local function T(z: number): CFrame -- JointTongue
	return CFrame.new(0, 0, z)
end
local function SAC(s: number): CFrame -- JointSac, s = 1 the swollen slide
	return CFrame.new(0, -0.5 * s, -0.6 * s)
end
local function LIDS(p: number): Pose
	return { JointEyeL = A(p), JointEyeR = A(p) }
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

local STAND: Pose = {}

-- a damped back jiggle, for landings and thumps
local function jiggle(secs: number, amp: number, decay: number): Pose
	local d = math.exp(-secs * decay)
	return {
		JointBack = A(amp * 0.7 * math.sin(TAU * 4 * secs) * d, 0, amp * math.sin(TAU * 3 * secs + 0.6) * d),
	}
end

-- TongueLash ----------------------------------------------------------------------
local LUNGE = { BL = V(0, 0, -0.3), BR = V(0, 0, -0.3) } -- the hind feet shuffle forward under the lunge
local LASH_GATHER: Pose = merge({
	JointRoot = RT(0, -0.4, 0.15, -0.06),
	JointHead = A(-0.08),
	JointJaw = A(0.08),
	JointBack = A(-0.04),
}, LIDS(0))
local LASH_AIM: Pose = merge({
	JointRoot = RT(0, -0.5, 0.2, 0.1),
	JointHead = A(0.35),
	JointJaw = A(0.75),
	JointSac = SAC(1),
	JointBack = A(-0.07),
}, LIDS(-0.25))
local LASH_HELD: Pose = with(LASH_AIM, {
	JointRoot = RT(0, -0.55, 0.25, 0.12),
	JointHead = A(0.4),
	JointJaw = A(0.8),
	JointSac = SAC(1.0),
})
local LASH_FIRE: Pose = merge({
	JointRoot = RT(0, -0.3, -0.35, 0.15),
	JointHead = A(0.28),
	JointJaw = A(0.9),
	JointSac = SAC(0.3),
	JointTongue = T(-14),
	JointBack = A(0.05),
}, LIDS(-0.3))

moves.TongueLash = {
	windup = {
		duration = 0.7,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = LASH_GATHER, ease = "out", plant = ALL },
			{ t = 0.7, pose = LASH_AIM, ease = "inOut", plant = ALL },
			{ t = 1, pose = LASH_HELD, ease = "linear", plant = ALL },
		},
		overlay = function(u, secs)
			local k = smooth(0.7, 0.8, u)
			local s = math.sin(TAU * 12 * secs)
			return {
				JointSac = CFrame.new(0, -0.05 * k * s, -0.04 * k * s),
				JointHead = A(0.012 * k * s),
				JointBack = A(0.02 * k * math.sin(TAU * 9 * secs)),
			}
		end,
	},
	active = {
		duration = 0.15,
		keys = {
			{ t = 0, pose = LASH_HELD, plant = ALL },
			{ t = 0.67, pose = LASH_FIRE, ease = "out", plant = ALL, reach = LUNGE },
			{ t = 1, pose = with(LASH_FIRE, { JointRoot = RT(0, -0.28, -0.4, 0.14) }), plant = ALL, reach = LUNGE },
		},
	},
	recover = {
		duration = 0.9,
		keys = {
			{ t = 0, pose = with(LASH_FIRE, { JointRoot = RT(0, -0.28, -0.4, 0.14) }), plant = ALL },
			-- the tongue is back by 0.33 (0.3 s); the jaw snaps shut as it arrives
			{ t = 0.33, pose = merge({ JointRoot = RT(0, -0.3, -0.1, 0.1), JointHead = A(0.25), JointJaw = A(0.8), JointSac = SAC(0.5), JointBack = A(0.0) }, LIDS(-0.1)), ease = "in", plant = ALL },
			{ t = 0.4, pose = merge({ JointRoot = RT(0, -0.3, -0.1, 0.1), JointHead = A(0.2), JointJaw = A(0.0), JointSac = SAC(0.45) }, LIDS(0.3)), ease = "out", plant = ALL },
			{ t = 0.75, pose = merge({ JointRoot = RT(0, -0.12, 0, 0.0), JointHead = A(0.0), JointSac = SAC(0.05) }, LIDS(0)), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, secs)
			local out = jiggle(math.max(secs - 0.33, 0), 0.1 * smooth(0.3, 0.36, u), 5)
			-- the swallow: two throat pulses after the snap
			local sw = bump(secs, 0.4, 0.55) + 0.6 * bump(secs, 0.55, 0.7)
			out.JointSac = CFrame.new(0, -0.18 * sw, -0.14 * sw)
			out.JointHead = A(-0.08 * sw)
			-- the tongue: back in 0.3 s, quick at first
			return out
		end,
	},
}
-- the tongue's recoil is keyed on the recover's first keys through this overlay-free table:
-- extra key list below patches JointTongue into those keys
do
	local rk = moves.TongueLash.recover.keys
	rk[1].pose = with(rk[1].pose, { JointTongue = T(-14) })
	rk[1].reach = LUNGE
	rk[2].pose = with(rk[2].pose, { JointTongue = T(0) })
end

-- Gulp ----------------------------------------------------------------------------
local GULP_REAR: Pose = merge({
	JointRoot = RT(0, -0.3, 0.2, 0.1),
	JointHead = A(0.42),
	JointJaw = A(0.85),
	JointSac = SAC(0.4),
	JointBack = A(-0.06),
}, LIDS(-0.2))
local GULP_REACH = { BL = V(0, 0, -0.55), BR = V(0, 0, -0.55) }
local GULP_BITE: Pose = merge({
	JointRoot = RT(0, -0.2, -0.6, -0.06),
	JointHead = A(-0.12),
	JointJaw = A(0.06),
	JointSac = SAC(0.1),
	JointBack = A(0.06),
}, LIDS(0.2))

moves.Gulp = {
	windup = {
		duration = 0.35,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.6, pose = GULP_REAR, ease = "out", plant = ALL },
			{ t = 1, pose = with(GULP_REAR, { JointHead = A(0.5), JointJaw = A(0.9), JointRoot = RT(0, -0.34, 0.25, 0.12) }), plant = ALL },
		},
	},
	active = {
		duration = 0.1,
		keys = {
			{ t = 0, pose = with(GULP_REAR, { JointHead = A(0.5), JointJaw = A(0.9), JointRoot = RT(0, -0.34, 0.25, 0.12) }), plant = ALL },
			{ t = 0.7, pose = GULP_BITE, ease = "in", plant = ALL, reach = GULP_REACH },
			{ t = 1, pose = GULP_BITE, plant = ALL, reach = GULP_REACH },
		},
	},
	recover = {
		duration = 0.8,
		keys = {
			{ t = 0, pose = GULP_BITE, plant = ALL, reach = GULP_REACH },
			{ t = 0.3, pose = merge({ JointRoot = RT(0, -0.2, -0.3, 0), JointHead = A(0.05), JointSac = SAC(0.35) }, LIDS(0.1)), ease = "out", plant = ALL, reach = { BL = V(0, 0, -0.3), BR = V(0, 0, -0.3) } },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, secs)
			local chew = smooth(0.05, 0.15, u) * (1 - smooth(0.4, 0.55, u))
			local sw = bump(secs, 0.35, 0.6)
			local out = jiggle(secs, 0.1, 5)
			out.JointJaw = A(0.2 * chew * (0.5 + 0.5 * math.sin(TAU * 5 * secs)))
			out.JointSac = CFrame.new(0, -0.2 * sw, -0.15 * sw)
			out.JointHead = A(-0.07 * sw)
			return out
		end,
	},
}

-- BogCroak ------------------------------------------------------------------------
local CROAK_LOW: Pose = merge({
	JointRoot = RT(0, -0.35, 0.1, 0.05),
	JointHead = A(0.1),
	JointJaw = A(0.1),
	JointSac = SAC(0.2),
}, LIDS(-0.1))
local CROAK_FULL: Pose = merge({
	JointRoot = RT(0, -0.22, 0.2, 0.16),
	JointHead = A(0.38),
	JointJaw = A(0.55),
	JointSac = SAC(0.9),
	JointBack = A(-0.08),
}, LIDS(-0.35))
local CROAK_SHOUT: Pose = merge({
	JointRoot = RT(0, -0.1, -0.1, 0.22),
	JointHead = A(0.5),
	JointJaw = A(0.9),
	JointSac = CFrame.new(0, -0.15, -0.2),
	JointBack = A(0.1),
}, LIDS(-0.4))

moves.BogCroak = {
	windup = {
		duration = 1.0,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.25, pose = CROAK_LOW, ease = "out", plant = ALL },
			{ t = 0.85, pose = CROAK_FULL, ease = "inOut", plant = ALL },
			{ t = 1, pose = with(CROAK_FULL, { JointRoot = RT(0, -0.2, 0.2, 0.18), JointSac = SAC(1.0), JointHead = A(0.42) }), plant = ALL },
		},
		-- the heaves while it fills, the strain at the top
		overlay = function(u, secs)
			local fill = smooth(0.25, 0.4, u) * (1 - smooth(0.85, 0.9, u))
			local h = math.max(0, math.sin(TAU * 2.6 * secs))
			local strain = smooth(0.85, 0.95, u)
			local s = math.sin(TAU * 13 * secs)
			return {
				JointSac = CFrame.new(0, -0.1 * fill * h - 0.03 * strain * s, -0.1 * fill * h),
				JointRoot = CFrame.new(0, 0.05 * fill * h, 0) * A(0, 0, 0.01 * strain * s),
				JointBack = A(0.03 * fill * h, 0, 0.02 * strain * math.sin(TAU * 9 * secs)),
			}
		end,
	},
	active = {
		duration = 0.1,
		keys = {
			{ t = 0, pose = with(CROAK_FULL, { JointRoot = RT(0, -0.2, 0.2, 0.18), JointSac = SAC(1.0), JointHead = A(0.42) }), plant = ALL },
			{ t = 0.5, pose = CROAK_SHOUT, ease = "out", plant = ALL },
			{ t = 1, pose = with(CROAK_SHOUT, { JointSac = CFrame.new(0, -0.3, -0.35), JointHead = A(0.46) }), plant = ALL },
		},
		overlay = function(_, secs)
			return { JointBack = A(0.08 * math.sin(TAU * 14 * secs), 0, 0.06 * math.sin(TAU * 11 * secs)) }
		end,
	},
	recover = {
		duration = 0.8,
		keys = {
			{ t = 0, pose = with(CROAK_SHOUT, { JointSac = CFrame.new(0, -0.3, -0.35), JointHead = A(0.46) }), plant = ALL },
			{ t = 0.35, pose = merge({ JointRoot = RT(0, -0.35, 0.1, 0.05), JointHead = A(0.15), JointJaw = A(0.3), JointSac = SAC(0.35) }, LIDS(-0.1)), ease = "out", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- throat pulses, dying away; the back still wobbling
		overlay = function(u, secs)
			local d = math.exp(-secs * 3.5)
			local p = math.max(0, math.sin(TAU * 3.2 * secs)) * d
			local out = jiggle(secs, 0.12, 4)
			out.JointSac = CFrame.new(0, -0.25 * p, -0.2 * p)
			return out
		end,
	},
}

-- MiasmaLob -----------------------------------------------------------------------
local LOB_DEEP: Pose = merge({
	JointRoot = RT(0, -0.42, 0.2, 0.04),
	JointHead = A(-0.12),
	JointJaw = A(0.2),
	JointSac = SAC(0.5),
	JointBack = A(0.05),
}, LIDS(0.1))
local LOB_SWELL: Pose = merge({
	JointRoot = RT(0, -0.4, 0.3, 0.1),
	JointHead = A(-0.05),
	JointJaw = A(0.3),
	JointSac = SAC(0.95),
	JointBack = A(-0.04),
}, LIDS(-0.1))
local LOB_REAR: Pose = merge({
	JointRoot = RT(0, -0.4, 0.4, 0.2),
	JointHead = A(0.5),
	JointJaw = A(0.9),
	JointSac = SAC(1.0),
	JointBack = A(-0.1),
}, LIDS(-0.4))
local LOB_REACH = { BL = V(0, 0, -0.5), BR = V(0, 0, -0.5) }
local LOB_FLING: Pose = merge({
	JointRoot = RT(0, -0.1, -0.5, 0.12),
	JointHead = A(0.12),
	JointJaw = A(0.9),
	JointSac = SAC(0.1),
	JointBack = A(0.1),
}, LIDS(-0.3))

moves.MiasmaLob = {
	windup = {
		duration = 1.0,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.18, pose = LOB_DEEP, ease = "out", plant = ALL },
			{ t = 0.4, pose = LOB_SWELL, ease = "inOut", plant = ALL },
			-- the head rears back (0.4-0.57 s), then the throw at 0.6 s
			{ t = 0.57, pose = LOB_REAR, ease = "inOut", plant = ALL },
			{ t = 0.6, pose = LOB_REAR, plant = ALL },
			{ t = 0.67, pose = LOB_FLING, ease = "in", plant = ALL, reach = LOB_REACH },
			{ t = 1, pose = with(LOB_FLING, { JointRoot = RT(0, -0.15, -0.35, 0.1), JointHead = A(0.05), JointSac = SAC(0.0) }), ease = "out", plant = ALL, reach = LOB_REACH },
		},
		-- retching heaves while it swells
		overlay = function(u, secs)
			local r = smooth(0.18, 0.25, u) * (1 - smooth(0.38, 0.45, u))
			local h = math.max(0, math.sin(TAU * 3.0 * secs))
			return {
				JointSac = CFrame.new(0, -0.15 * r * h, -0.12 * r * h),
				JointRoot = CFrame.new(0, 0.06 * r * h, 0) * A(0.03 * r * h),
				JointHead = A(0.06 * r * h),
				JointJaw = A(0.12 * r * h),
				JointBack = A(0.04 * r * h, 0, 0.03 * r * math.sin(TAU * 5 * secs)),
			}
		end,
	},
	active = {
		duration = 0.1,
		keys = {
			{ t = 0, pose = with(LOB_FLING, { JointRoot = RT(0, -0.15, -0.35, 0.1), JointHead = A(0.05), JointSac = SAC(0.0) }), plant = ALL, reach = LOB_REACH },
			{ t = 1, pose = merge({ JointRoot = RT(0, -0.2, -0.2, 0.05), JointHead = A(0.0), JointJaw = A(0.5), JointSac = SAC(0.0) }, LIDS(0)), ease = "out", plant = ALL, reach = LOB_REACH },
		},
	},
	recover = {
		duration = 0.8,
		keys = {
			{ t = 0, pose = merge({ JointRoot = RT(0, -0.2, -0.2, 0.05), JointHead = A(0.0), JointJaw = A(0.5), JointSac = SAC(0.0) }, LIDS(0)), plant = ALL, reach = LOB_REACH },
			{ t = 0.4, pose = merge({ JointRoot = RT(0, -0.15, -0.05, 0.0), JointJaw = A(0.15) }, LIDS(0.1)), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- drool: the jaw wobbles shut
		overlay = function(u, secs)
			local out = jiggle(secs, 0.1, 5)
			out.JointJaw = A(0.06 * math.sin(TAU * 4 * secs) * (1 - u))
			return out
		end,
	},
}

-- Hop (the backslide) -------------------------------------------------------------
local HOP_LOAD: Pose = merge({
	JointRoot = RT(0, -0.5, 0.2, 0.12),
	JointHead = A(0.1),
	JointJaw = A(0.1),
	JointBack = A(-0.05),
	JointLegF = A(0.3), JointFootF = A(-0.3),
}, LIDS(0))
local HOP_PUSH: Pose = merge({
	JointRoot = RT(0, 0.25, 0.25, 0.28),
	JointHead = A(0.18),
	JointJaw = A(0.2),
	JointLegBL = A(-0.55, 0, 0.05), JointLowerLegBL = A(0.5), JointFootBL = A(0.35),
	JointLegBR = A(-0.55, 0, -0.05), JointLowerLegBR = A(0.5), JointFootBR = A(0.35),
	JointLegF = A(0.35), JointFootF = A(-0.35),
	JointBack = A(0.04),
}, LIDS(-0.15))
local HOP_TUCK: Pose = merge({
	JointRoot = RT(0, 0.45, 0.1, 0.22),
	JointHead = A(0.12),
	JointJaw = A(0.1),
	JointLegBL = A(0.18, 0, 0.1), JointLowerLegBL = A(-0.3), JointFootBL = A(0.1),
	JointLegBR = A(0.18, 0, -0.1), JointLowerLegBR = A(-0.3), JointFootBR = A(0.1),
	JointLegF = A(0.5), JointFootF = A(-0.5),
	JointBack = A(0.0),
}, LIDS(-0.1))
local HOP_REACH: Pose = merge({
	JointRoot = RT(0, 0.2, 0.0, 0.1),
	JointHead = A(0.05),
	JointLegBL = A(0.05), JointLowerLegBL = A(-0.1), JointFootBL = A(0.1),
	JointLegBR = A(0.05), JointLowerLegBR = A(-0.1), JointFootBR = A(0.1),
	JointLegF = A(-0.15), JointFootF = A(0.12),
	JointBack = A(-0.03),
}, LIDS(0))

moves.Hop = {
	active = {
		duration = 0.35,
		air = true,
		keys = {
			{ t = 0, pose = HOP_LOAD, plant = ALL },
			{ t = 0.22, pose = HOP_PUSH, ease = "in", plant = { "BL", "BR" } },
			{ t = 0.4, pose = HOP_TUCK, ease = "out", plant = {} },
			{ t = 0.85, pose = HOP_REACH, ease = "inOut", plant = {} },
			{ t = 1, pose = with(HOP_REACH, { JointRoot = RT(0, -0.3, 0.05, 0.0), JointBack = A(0.05) }), ease = "in", plant = ALL },
		},
	},
	recover = {
		duration = 0.3,
		keys = {
			{ t = 0, pose = with(HOP_REACH, { JointRoot = RT(0, -0.3, 0.05, 0.0), JointBack = A(0.05) }), plant = ALL },
			{ t = 0.4, pose = merge({ JointRoot = RT(0, -0.55, 0.1, -0.04), JointHead = A(-0.08), JointBack = A(0.05) }, LIDS(0.1)), ease = "out", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(_, secs)
			return jiggle(secs, 0.14, 5)
		end,
	},
}

-- Stagger / Death -----------------------------------------------------------------
local HIT: Pose = merge({
	JointRoot = RT(0, -0.3, 0.4, 0.14),
	JointHead = A(0.35),
	JointJaw = A(0.5),
	JointSac = SAC(0.6),
	JointBack = A(-0.1),
}, LIDS(0.5))
local HITR = { BL = V(0, 0, -0.35), BR = V(0, 0, -0.35) }
moves.Stagger = {
	active = {
		duration = 0.3,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = HIT, ease = "out", plant = ALL, reach = HITR },
			{ t = 0.5, pose = HIT, plant = ALL, reach = HITR },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, secs, input)
			local side = math.clamp(input.side or 0, -1, 1)
			local e = if u < 0.2 then EASE.out(u / 0.2) else 1 - EASE.inOut((u - 0.2) / 0.8)
			local out = jiggle(secs, 0.12, 4)
			out.JointRoot = A(0, 0.05 * side * e, 0.06 * side * e)
			out.JointHead = A(0, 0.12 * side * e)
			return out
		end,
	},
}

local DEAD: Pose = merge({
	JointRoot = RT(0, -0.75, 0.2, 0.02),
	JointHead = A(-0.12),
	JointJaw = A(0.55),
	JointTongue = T(-2.4),
	JointSac = SAC(0.1),
	JointBack = A(0.08),
	JointLegF = A(0.2), JointFootF = A(-0.2),
	JointLegBL = A(0.1, 0, -0.15), JointLowerLegBL = A(-0.3),
	JointLegBR = A(0.1, 0, 0.15), JointLowerLegBR = A(-0.3),
}, LIDS(0.9))
local DREACH = { BL = V(0, 0.15, -0.5), BR = V(0, 0.15, -0.5) }
moves.Death = {
	active = {
		duration = 1.0,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.15, pose = HIT, ease = "out", plant = ALL, reach = HITR },
			-- the legs give out; it flops down and lies there
			{ t = 0.5, pose = with(DEAD, { JointRoot = RT(0, -0.8, 0.2, 0.05), JointTongue = T(-1.0), JointHead = A(0.2) }), ease = "in", plant = ALL, reach = DREACH },
			{ t = 0.65, pose = with(DEAD, { JointRoot = RT(0, -0.76, 0.2, 0.0) }), ease = "out", plant = ALL, reach = DREACH },
			{ t = 1, pose = DEAD, ease = "inOut", plant = ALL, reach = DREACH },
		},
		overlay = function(u, secs)
			return jiggle(math.max(secs - 0.5, 0), 0.2 * smooth(0.45, 0.5, u), 4)
		end,
	},
}

GoldenToad.durations = Quadruped.durations(moves)

------------------------------------------------------------------------------------
-- Loops

local loops = {}
local PLANT_ALL = Quadruped.plantOf(ALL)

local function blinkOf(clock: number, seed: number): number
	local slot = math.floor(clock / 3.4)
	local at = slot * 3.4 + 0.5 + hash(slot, seed) * 2.2
	local b = bump(clock, at, at + 0.22)
	-- sometimes a double blink
	if hash(slot + 0.5, seed) < 0.25 then
		b = math.max(b, bump(clock, at + 0.3, at + 0.52))
	end
	return b
end

-- a squat: the sac breathes, the throat flutters, blinks, the head sways and now and then it
-- shifts its weight
function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 2.6)
	local flutter = math.sin(clock * TAU * 2.2) * (0.5 + 0.5 * math.sin(clock * 0.7 + seed))
	local look = math.sin(clock * 0.31 + seed) * 0.25
	-- a rare shift: the root rolls to one side and back
	local slot = math.floor(clock / 8)
	local st = slot * 8 + 1 + hash(slot, seed) * 4
	local shift = bump(clock, st, st + 1.4) * (if hash(slot + 0.3, seed) < 0.5 then 1 else 0)
	local pose: Pose = {
		JointRoot = RT(0.18 * shift, -0.12 + 0.05 * breath, 0.02, 0.008 * breath, 0, -0.03 * shift),
		JointBack = A(0.012 * breath, 0, 0.01 * math.sin(clock * 0.5)),
		JointHead = A(0.03 + 0.02 * breath, look * 0.5, 0.03 * math.sin(clock * 0.23)),
		JointJaw = A(0.03 + 0.03 * math.max(0, flutter)),
		JointSac = CFrame.new(0, -0.12 * (0.5 + 0.5 * breath) - 0.03 * flutter, -0.1 * (0.5 + 0.5 * breath)),
	}
	local bl = blinkOf(clock, seed)
	pose.JointEyeL = A(0.9 * bl)
	pose.JointEyeR = A(0.9 * bl)
	plantAll(pose, PLANT_ALL, false, {})
	return pose
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- the walk: one leg moves at a time (front, left hind, right hind); each foot slides back
-- over 2/3 of the cycle and steps forward in 1/3. The shell... the body leans away from
-- the stepping leg, dips as it lands, and the head bobs forward on the front step.
function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local S = 1.0
	local beta = 2 / 3
	local cA = (phase / TAU) % 1
	local reach: { [string]: Vector3 } = {}
	local flex: { [string]: number } = {}
	local swing = { FL = 0, BL = 0, BR = 0 }
	for tag, off in { FL = 0, BL = 1 / 3, BR = 2 / 3 } do
		local c = (cA + off) % 1
		local z, y, out = 0, 0, 0
		if c < beta then
			z = S * (-1 + 2 * (c / beta))
		else
			local s = (c - beta) / (1 - beta)
			z = S * (1 - 2 * smoothstep(s))
			y = (if tag == "FL" then 0.32 else 0.38) * math.sin(math.pi * s) ^ 0.8
			out = (if tag == "FL" then 0.25 else 0.5) * math.sin(math.pi * s)
			swing[tag] = math.sin(math.pi * s)
		end
		local side = if tag == "BL" then -1 elseif tag == "BR" then 1 else 0
		-- the hind feet stay forward of their rest spots: sliding back lowers the knee into the ground
		reach[tag] = V(side * out, y, z + (if side ~= 0 then -0.8 else 0.35))
		flex[tag] = 0 -- toes up would put the toe tips into the belly and the sac
	end
	-- the weight goes onto the legs that are down: away from the stepping side
	local lean = swing.BL - swing.BR -- + when the left hind steps
	local pose: Pose = {}
	pose.JointRoot = RT(
		0.3 * lean,
		-0.2 - 0.08 * swing.FL - 0.06 * (swing.BL + swing.BR),
		0.1 * swing.FL,
		0.05 * swing.FL - 0.03 * (swing.BL + swing.BR),
		0.05 * lean,
		0.07 * lean
	)
	pose.JointBack = A(0.04 * swing.FL, 0, -0.05 * lean)
	local bob = swing.FL
	pose.JointHead = A(0.04 - 0.1 * bob + 0.03 * math.sin(phase * 3 + 1), 0.08 * lean, 0.04 * lean)
	pose.JointJaw = A(0.04)
	pose.JointSac = SAC(0.1 + 0.15 * bob)
	plantAll(pose, PLANT_ALL, false, reach, flex)
	return pose
end

-- the run: a chain of hops. A cycle: the feet down and sliding back (a thrust at the end),
-- then airborne on a 0.9-stud arc with the legs tucked, reaching for the ground, landing
-- with a compression.
local RUN_STANCE = 0.4
function loops.run(phase: number, _speed: number, _input: Input?): Pose
	local c = (phase / TAU) % 1
	local a = 0.9 -- foot slide half-range
	local pose: Pose = {}
	local plant = { FL = 0, BL = 0, BR = 0 }
	local reach: { [string]: Vector3 } = {}
	local air = 0
	if c < RUN_STANCE then
		local k = c / RUN_STANCE
		-- the feet slide back; compress on landing, push at the end
		local z = a * (-1 + 2 * k)
		reach = { FL = V(0, 0, z), BL = V(0, 0, z), BR = V(0, 0, z) }
		local press = math.sin(math.pi * math.min(k * 2, 1)) * (1 - smooth(0.5, 0.9, k))
		local push = smooth(0.55, 1, k)
		pose.JointRoot = RT(0, -0.5 * press + 0.3 * push, -0.15 * press, 0.12 * push - 0.06 * press)
		pose.JointHead = A(0.05 + 0.25 * push - 0.1 * press)
		pose.JointJaw = A(0.04 + 0.18 * push)
		pose.JointBack = A(-0.08 * push + 0.07 * press)
		local w = 1 - smooth(0.82, 1, k)
		plant = { FL = w, BL = w, BR = w }
	else
		local k = (c - RUN_STANCE) / (1 - RUN_STANCE)
		air = math.sin(math.pi * k)
		local tuck = 0.6 * smooth(0, 0.35, k) * (1 - smooth(0.6, 0.95, k))
		local reachK = smooth(0.6, 1, k)
		pose.JointRoot = RT(0, 0.9 * air + 0.0, -0.1, 0.15 - 0.3 * reachK)
		pose.JointHead = A(0.2 - 0.25 * reachK)
		pose.JointJaw = A(0.1)
		pose.JointBack = A(0.05 * tuck - 0.04 * reachK)
		local hindExt = smooth(0, 0.2, k) * (1 - smooth(0.2, 0.4, k))
		pose.JointLegBL = A(-0.55 * hindExt + 0.3 * tuck + 0.05 * reachK, 0, 0.08 * tuck)
		pose.JointLegBR = A(-0.55 * hindExt + 0.3 * tuck + 0.05 * reachK, 0, -0.08 * tuck)
		pose.JointLowerLegBL = A(0.5 * hindExt - 0.5 * tuck - 0.1 * reachK)
		pose.JointLowerLegBR = A(0.5 * hindExt - 0.5 * tuck - 0.1 * reachK)
		pose.JointFootBL = A(0.3 * hindExt + 0.2 * tuck)
		pose.JointFootBR = A(0.3 * hindExt + 0.2 * tuck)
		pose.JointLegF = A(0.5 * tuck - 0.4 * reachK)
		pose.JointFootF = A(-0.5 * tuck + 0.35 * reachK)
		-- landing: the feet are planted from late in the descent (see below)
		local w = smooth(0.9, 1, k)
		plant = { FL = w, BL = w, BR = w }
		reach = { FL = V(0, 0, -a), BL = V(0, 0, -a), BR = V(0, 0, -a) }
	end
	pose.JointSac = SAC(0.2)
	plantAll(pose, plant, false, reach)
	return pose
end

loops.circle = loops.walk
GoldenToad.loops = loops

-- radians per second of the loop phase so the planted feet do not skate. The walk's feet
-- slide back 2 S = 2.0 studs over 2/3 of the cycle; the run's over 0.4 of it (1.8 studs).
function GoldenToad.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	local v = math.max(speed, 0.2) / s
	if loop == "walk" or loop == "circle" then
		return TAU * (2 / 3) * v / 2.0
	elseif loop == "run" then
		return TAU * RUN_STANCE * v / 1.8
	end
	return 1
end

function GoldenToad.scaled(pose: Pose, scale: number): Pose
	if scale ~= 1 then
		for name, cf in pose do
			pose[name] = cf - cf.Position + cf.Position * scale
		end
	end
	return pose
end

return GoldenToad
