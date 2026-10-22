--!strict
-- Procedural pose tables for the Flame Raven (Enemies.FlameRavenB, 1.0x; art/enemies/beasts/
-- RIGS.md "FlameRavenB"). Same FORMAT and API as Wolf.luau (read its header); the shared wing
-- stroke is in Flap.luau, the notes in art/enemies/beasts/poses_flame_raven.md.
--
-- EnemyAnimator FAMILIES registration (needs the request in the .md: motion/loop smoothing):
--   FAMILIES.FlameRavenB = {
--       poses = FlameRaven, scale = 1, runFrom = 12, keyedBlend = 0.08, deathSeconds = 1.5,
--       staggerSeconds = 0.3,
--       moves = { talonDive = "TalonDive", talonRake = "TalonRake", emberFan = "EmberFan",
--                 windGust = "WindGust", hop = "Hop", talonDiveSkid = "TalonDiveSkid" },
--   }
--
-- RIG: faces -Z, hover pivot (the HRP centre, Y 5); 16 joints. JointRoot is the body (pivot
-- at the body centre): translate Y = the dives, climbs and the perch, +X pitch tips the nose
-- UP, +Z rolls the top toward the bird's left. Wings: JointShoulder/Elbow/Wrist L/R, roll Z
-- lifts (L up = -Z, R up = +Z), a sweep BACK is +Y on L and -Y on R (the brief had it
-- reversed: measured). JointNeck/JointHead: +X tips up, Y turns left, JointJaw -X opens,
-- JointCrest +X lays it flat (-X stands it up), JointTail +X drops the fan, JointLegBL/BR +X
-- swings the leg forward, JointAnkleL/R +X curls the talons forward.
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt: the telegraph, tell flare and
-- sound start with the first frame of each windup)
--   TalonDive   windup 0.8  a 0.1 s gather (the wings cocked up), then 3 power strokes climb
--                           2.5 studs, the last one folds the wings UP and BACK (V 1.3 rad,
--                           swept 0.5) and the body hangs at the apex, head down, talons
--                           forward, a trembling held beat from 0.5 s (the tell flare)
--               active 0.55 the stoop: wings fold back flat against the body, a steep drop,
--                           flattening into a swoop; the last 0.15 s flares (wings forward,
--                           nose up, talons wide, beak open) for the arrival
--               recover 1.2 THE PERCH (the damage window; the SERVER drops the root 1.5 for it,
--                           so no drop is keyed here, only the droop): wings half open and
--                           drooping, head hanging, panting; the last 0.3 s a gathering
--                           power stroke lifts it back to hover
--   TalonRake   windup 0.35 from the arrival flare: talons cocked back, wings thrown up, beak
--                           wide
--               active 0.12 the talons thrust forward and curl, a hard down-stroke
--               recover 1.0 (0.88 after the active) follow-through, then the same perch
--   TalonDiveSkid recover 1.2 (LEAD) the miss: an air-brake flare, then the head snaps round
--                           to the live targetYaw and leads, the body banks into the turn
--                           with hard strokes, back to hover (it rises 0.5-0.9 while it turns: the
--                           server's perch drop is still on the root during this recover)
--   EmberFan    windup 1.0  coil low (0.2), then the wings sweep overhead in one big stroke
--                           and the chest rears, crest standing, beak wide; held and
--                           trembling from 0.7
--               active 0.1  flick 1: the wings plunge, the head snaps forward
--               recover 0.9 (0.8 after the active) flicks 2 and 3 at +0.05 and +0.2 s (the
--                           barrage's 0.15 / 0.3 s delays), then it settles to hover
--   WindGust    windup 0.5  rises on a back-swept cock, nose up
--               active 0.1  one huge forward down-stroke (the gust)
--               recover 0.7 (0.6 after the active) a second strong stroke, settling
--   Hop         active 0.3 (air) a back-flap: two quick strokes, nose up
--   Stagger     active 0.28 thrown back, wings flung up (input.side tilts it)
--   Death       active 1.4, then hold u = 1: wings flung up, a flailing spiral, a belly-down
--               impact on the ground with the wings spread flat
-- LOOPS: idle (a hover flap with a bob, ~2.4 Hz), walk (leaning in, faster), run (deep
--   strokes, swept), circle (banked into the strafe).
--
-- API (as Wolf.luau): FlameRaven.sample(move, phase, u, input?) -> Pose,
--   FlameRaven.loops.idle(clock, speed, input?) / walk(phase, speed, input?) / run / circle,
--   .gaitRate(loop, speed, scale?), .scaled(pose, scale), .plant(pose) (a no-op: fliers
--   have no feet to plant), .moves, .durations, .JOINTS, .LEAD.
-- input: duration, side (stagger/death: +1 hit from its right), targetYaw (skid), dir
--   (circle: +1 strafes left), seed.

local Quadruped = require(script.Parent.Quadruped)
local Flap = require(script.Parent.Flap)

local FlameRaven = {}

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Style = Flap.Style

local I = CFrame.identity
local V = Vector3.new
local A = CFrame.Angles
local C = Flap.curve
local wave = Flap.wave
local smooth = Quadruped.smooth
local bump = Quadruped.bump

FlameRaven.JOINTS = {
	"JointRoot", "JointNeck", "JointHead", "JointJaw", "JointCrest", "JointTail",
	"JointShoulderL", "JointElbowL", "JointWristL", "JointShoulderR", "JointElbowR", "JointWristR",
	"JointLegBL", "JointLegBR", "JointAnkleL", "JointAnkleR",
}
local NAMES = {
	L = { "JointShoulderL", "JointElbowL", "JointWristL" },
	R = { "JointShoulderR", "JointElbowR", "JointWristR" },
}

local A0 = 0.36 -- the rest elevation of a straight wing

------------------------------------------------------------------------------------
-- Wing styles (elevations in radians above horizontal; see Flap.luau)

local HOVER: Style = {
	A0 = A0, top = 0.95, bottom = -0.6, amp = 1, lag = 0.85, d = 0.4, k2 = 1.15, k3 = 1.3,
	yaw = { 0, 0, 0 }, yawAmp = { 0.2, 0.12, 0.08 }, bend = { 0, 0, 0 },
}
local RUN: Style = {
	A0 = A0, top = 0.85, bottom = -0.75, amp = 1, lag = 0.9, d = 0.38, k2 = 1.2, k3 = 1.4,
	yaw = { 0.25, 0.2, 0.15 }, yawAmp = { 0.3, 0.2, 0.12 }, bend = { 0, 0, 0 },
}
local COCK: Style = { -- wings cocked up and back (the dive windup's end)
	A0 = A0, top = 1.3, bottom = -0.5, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { 0.5, 0.4, 0.25 }, yawAmp = { 0.2, 0.15, 0.1 }, bend = { 0, 0, 0.1 },
}
local FOLD: Style = { -- folded back flat against the body for the stoop
	A0 = A0, top = 0.3, bottom = -0.5, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { 0.8, 0.65, 0.4 }, yawAmp = { 0, 0, 0 }, bend = { 0, -0.1, -0.25 },
}
local FLARE: Style = { -- the arrival air-brake: wings out in front, tips up
	A0 = A0, top = 1.0, bottom = -0.5, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { -0.35, -0.25, -0.1 }, yawAmp = { 0, 0, 0 }, bend = { 0, 0.15, 0.3 },
}
local DROOP: Style = { -- the perch: half open, drooping, a labored slow beat
	A0 = A0, top = 0.1, bottom = -0.45, amp = 0.35, lag = 1.3, d = 0.45, k2 = 1.5, k3 = 2.0,
	yaw = { 0.15, 0.1, 0.05 }, yawAmp = { 0.05, 0.03, 0 }, bend = { 0, -0.1, -0.2 },
}
local OVERHEAD: Style = {
	A0 = A0, top = 1.5, bottom = -0.5, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { 0.05, 0, -0.1 }, yawAmp = { 0, 0, 0 }, bend = { 0, -0.25, 0.2 },
}
local LOW: Style = { -- wings drawn low and in for the coil
	A0 = A0, top = -0.35, bottom = -0.8, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { -0.2, -0.1, 0 }, yawAmp = { 0, 0, 0 }, bend = { 0, 0, 0 },
}
local GUST_COCK: Style = {
	A0 = A0, top = 1.5, bottom = -0.9, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { 0.7, 0.6, 0.4 }, yawAmp = { 0.25, 0.2, 0.1 }, bend = { 0, 0, 0.1 },
}
local POWER: Style = { -- a full power stroke, swept forward at the bottom
	A0 = A0, top = 1.5, bottom = -0.9, amp = 1, lag = 0.9, d = 0.4, k2 = 1.2, k3 = 1.4,
	yaw = { 0.1, 0, 0 }, yawAmp = { 0.6, 0.35, 0.2 }, bend = { 0, 0, 0 },
}
local DEAD_WINGS: Style = { -- spread flat on the ground
	A0 = A0, top = -0.12, bottom = -0.3, amp = 0, lag = 0.9, k2 = 1.2, k3 = 1.4,
	yaw = { 0.1, 0.2, 0.25 }, yawAmp = { 0, 0, 0 }, bend = { 0, -0.08, -0.15 },
}

local function wings(pose: Pose, style: Style, theta: number, styleR: Style?, thetaR: number?)
	Flap.write(pose, Flap.cycle(theta, style, styleR, thetaR), NAMES)
end

local function times(arr: { number }, k: number): { number }
	return { arr[1] * k, arr[2] * k, arr[3] * k }
end

-- add `extra` (a pose of CFrames) on top of `pose`
local function add(pose: Pose, extra: Pose)
	for name, cf in extra do
		pose[name] = (pose[name] or I) * cf
	end
end

------------------------------------------------------------------------------------
-- Body poses (numbers in studs / radians)

local function B(o: { [string]: number }): Pose
	local g = function(k: string): number
		return o[k] or 0
	end
	local legs, toes = g("legs"), g("toes")
	return {
		JointRoot = CFrame.new(g("x"), g("y"), g("z")) * A(g("pitch"), g("yaw"), g("roll")),
		JointNeck = A(g("neck"), g("neckYaw"), g("neckRoll")),
		JointHead = A(g("head"), g("headYaw"), g("headRoll")),
		JointJaw = A(g("jaw"), 0, 0),
		JointCrest = A(g("crest"), 0, 0),
		JointTail = A(g("tail"), g("tailYaw"), g("tailRoll")),
		JointLegBL = A(legs + g("legL"), 0, 0),
		JointLegBR = A(legs + g("legR"), 0, 0),
		JointAnkleL = A(toes, 0, 0),
		JointAnkleR = A(toes, 0, 0),
	}
end

-- The hovering flier at flap angle theta: a bob that follows the stroke, a gaze held level,
-- the tail fan fluttering a beat behind the wings, the legs trailing.
local function hover(theta: number, o: { [string]: number }): Pose
	local lift = -wave(theta - 1.2) -- the body rises just after the down-stroke
	local amp = o.bob or 1
	local pitch = (o.lean or 0) + 0.05 * -wave(theta - 0.6) * amp
	local tailFlutter = -wave(theta - 2.3)
	local pose = B({
		y = 0.2 * lift * amp + (o.y or 0),
		pitch = pitch,
		roll = o.bank or 0,
		neck = -pitch * 0.4 + (o.neck or 0),
		head = -pitch * 0.6 + (o.head or 0),
		neckYaw = o.neckYaw or 0,
		headYaw = o.headYaw or 0,
		jaw = o.jaw or 0,
		crest = -0.15 + 0.15 * wave(theta - 3) + (o.crest or 0),
		tail = 0.12 + 0.22 * tailFlutter * amp + (o.tail or 0),
		tailRoll = 0.14 * math.sin(theta * 0.5 + 0.7),
		tailYaw = 0.12 * math.sin(theta * 0.5 + 2.0) + (o.tailYaw or 0),
		legs = -0.2 + 0.12 * wave(theta - 2.0) + (o.legs or 0),
		toes = 0.25 + (o.toes or 0),
	})
	return pose
end

local function hoverPose(theta: number, style: Style, o: { [string]: number }): Pose
	local pose = hover(theta, o)
	wings(pose, style, theta)
	return pose
end

------------------------------------------------------------------------------------
-- Loops

local function gaze(clock: number, seed: number): (number, number)
	local look = Flap.noise(clock * 0.6, seed) * 0.35
	return look * 0.5, look * 0.6
end

local loops = {}

function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local theta = clock * 15 + seed
	local ny, hy = gaze(clock, seed)
	local pose = hoverPose(theta, HOVER, { neckYaw = ny, headYaw = hy, bob = 1 })
	-- now and then the beak parts
	pose.JointJaw = A(-0.25 * smooth(0.55, 0.9, math.sin(clock * 0.8 + seed)), 0, 0)
	return pose
end

function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local lean = -0.1 - 0.012 * speed
	return hoverPose(phase, HOVER, { lean = lean, bob = 1.2, legs = 0.1 })
end

function loops.run(phase: number, speed: number, _input: Input?): Pose
	local lean = -0.22 - 0.01 * math.min(speed, 20)
	return hoverPose(phase, RUN, { lean = lean, bob = 1.3, legs = 0.35, toes = 0.2, tail = 0.15 })
end

function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = (input and input.dir) or 1
	local ty = math.clamp((input and input.targetYaw) or 0, -0.9, 0.9)
	local lean = -0.1 - 0.01 * speed
	return hoverPose(phase, RUN, { lean = lean, bank = 0.3 * dir, neckYaw = ty * 0.4, headYaw = ty * 0.4, bob = 1.2, legs = 0.2 })
end

FlameRaven.loops = loops

function FlameRaven.gaitRate(loop: string, speed: number, _scale: number?): number
	if loop == "walk" then
		return 16 + 0.4 * speed
	elseif loop == "run" then
		return 20 + 0.25 * speed
	end
	return 18
end

------------------------------------------------------------------------------------
-- Moves

local moves: { [string]: { [string]: Quadruped.Phase } } = {}

local function key(t: number, pose: Pose, ease: string?): Quadruped.Key
	return { t = t, pose = pose, ease = ease }
end

-- a held beat's tremble on the body and wings
local function tremble(pose: Pose, t: number, k: number)
	if k <= 0 then
		return
	end
	add(pose, {
		JointRoot = CFrame.new(0, 0.05 * k * math.sin(t * 61), 0) * A(0.025 * k * math.sin(t * 47), 0, 0.03 * k * math.sin(t * 53)),
		JointTail = A(0.1 * k * math.sin(t * 39), 0, 0.08 * k * math.sin(t * 33)),
		JointHead = A(0, 0.03 * k * math.sin(t * 57), 0),
	})
end

-- ---- TalonDive --------------------------------------------------------------

local DIVE_END = B({ y = 2.5, pitch = -0.15, neck = -0.3, head = -0.55, jaw = -0.25, crest = 0.5, legs = 0.95, toes = 0.6, tail = -0.3 })
local STOOP = B({ y = 2.0, pitch = -0.7, neck = 0.2, head = 0.45, jaw = -0.2, crest = 0.7, legs = 1.0, toes = 0.6, tail = -0.1 })
local SWOOP = B({ y = 0.4, pitch = -0.28, neck = 0.1, head = 0.2, jaw = -0.2, crest = 0.7, legs = 1.15, toes = 0.7, tail = 0.05 })
local ARRIVE = B({ y = 0, pitch = 0.5, neck = 0.2, head = 0.3, jaw = -0.7, crest = -0.3, legs = 1.35, toes = 0.9, tail = 0.8 })

moves.TalonDive = {
	windup = {
		duration = 0.8,
		keys = {
			key(0, B({})),
			key(0.13, B({ y = -0.3, pitch = -0.08, neck = -0.1, legs = 0.2, toes = 0.2, tail = -0.3, crest = 0.1 }), "out"), -- the gather dip
			key(0.62, B({ y = 2.6, pitch = 0.32, neck = 0.1, head = -0.1, legs = -0.3, toes = 0.3, crest = 0.3, tail = 0.35, jaw = -0.1 }), "inOut"), -- the climb
			key(0.82, B({ y = 2.55, pitch = 0.05, neck = -0.25, head = -0.5, legs = 0.6, toes = 0.5, crest = 0.5, tail = -0.1, jaw = -0.2 }), "inOut"), -- the hang
			key(1, DIVE_END, "inOut"),
		},
		overlay = function(u, _secs, _input)
			local t = u * 0.8
			local style = Flap.mix(HOVER, COCK, 1)
			style.top = C({ { 0, 1.0 }, { 0.5, 0.95 }, { 0.62, 1.3 }, { 0.8, 1.32 } }, t) + 0.05 * math.sin(t * 60) * smooth(0.62, 0.72, t)
			style.bottom = -0.5
			style.amp = C({ { 0, 0 }, { 0.1, 0 }, { 0.18, 1 }, { 0.46, 1 }, { 0.62, 0 }, { 0.8, 0 } }, t)
			style.yaw = times({ 0.5, 0.4, 0.25 }, C({ { 0, 0.2 }, { 0.5, 0.3 }, { 0.68, 1 } }, t))
			local theta = Flap.phaseAt({ { 0, 0 }, { 0.1, 0 }, { 0.14, 22 }, { 0.46, 24 }, { 0.62, 8 }, { 0.8, 0 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			tremble(pose, t, smooth(0.55, 0.75, u))
			return pose
		end,
	},
	active = {
		duration = 0.55,
		keys = {
			key(0, DIVE_END),
			key(0.12, STOOP, "in"),
			key(0.55, SWOOP, "inOut"),
			key(0.8, B({ y = -0.1, pitch = -0.12, neck = 0.1, head = 0.2, jaw = -0.3, crest = 0.5, legs = 1.2, toes = 0.7 }), "inOut"),
			key(1, ARRIVE, "out"),
		},
		overlay = function(u, _secs, _input)
			local t = u * 0.55
			local fold = smooth(0, 0.1, t)
			local flare = smooth(0.4, 0.52, t)
			local style = Flap.mix(Flap.mix(COCK, FOLD, fold), FLARE, flare)
			style.top += 0.04 * math.sin(t * 70) * (1 - flare)
			local pose: Pose = {}
			wings(pose, style, 0)
			return pose
		end,
	},
	recover = nil :: any,
}

-- The perch: sink, droop, pant, then the gathering stroke. `entry` is the pose it starts from.
local PERCH = B({ y = 0, pitch = 0.18, neck = -0.35, head = -0.75, jaw = -0.12, crest = 0.5, legs = 0.35, toes = 0.3, tail = 0.55 })
local function perchOverlay(u: number, _secs: number, _input: Input, D: number): Pose
	local t = u * D
	local pose: Pose = {}
	local rise = smooth(0.72, 0.98, u)
	local style = Flap.mix(DROOP, HOVER, rise)
	style.amp = (if u < 0.72 then 0.3 + 0.1 * math.sin(t * 6) else 0.3 + 0.7 * rise)
	local theta = Flap.phaseAt({ { 0, 3 }, { 0.72 * D, 5.5 }, { D, 24 } }, t)
	-- the flare from the arrival eases into the droop over the first 0.2 s
	local drop = smooth(0, 0.18, u)
	local s2 = Flap.mix(FLARE, style, drop)
	wings(pose, s2, theta)
	-- panting: the breath heaves the chest and opens the beak; the labored rise of the wings
	local breath = math.sin(t * 17)
	local still = (1 - rise) * smooth(0.12, 0.3, u)
	add(pose, {
		JointRoot = CFrame.new(0, 0.07 * breath * still, 0) * A(0.04 * breath * still, 0, 0.03 * math.sin(t * 5) * still),
		JointJaw = A(-0.22 * (0.5 + 0.5 * breath) * still, 0, 0),
		JointTail = A(0.06 * breath * still, 0, 0),
		JointHead = A(-0.05 * math.sin(t * 7) * still, 0, 0),
	})
	return pose
end

local function perchKeys(entry: Pose, sink: number): { Quadruped.Key }
	return {
		key(0, entry),
		key(sink, PERCH, "out"),
		key(0.72, B({ y = 0, pitch = 0.2, neck = -0.4, head = -0.8, jaw = -0.12, crest = 0.5, legs = 0.35, toes = 0.3, tail = 0.55 }), "linear"),
		key(0.86, B({ y = 0.3, pitch = 0.3, neck = 0.1, head = 0, jaw = -0.3, crest = 0.2, legs = -0.1, toes = 0.2, tail = 0.5 }), "inOut"),
		key(1, B({ y = 0, pitch = 0.04, legs = -0.1, toes = 0.25, tail = 0.15, crest = -0.1 }), "out"),
	}
end

moves.TalonDive.recover = {
	duration = 1.2,
	keys = perchKeys(ARRIVE, 0.17),
	overlay = function(u, secs, input)
		return perchOverlay(u, secs, input, 1.2)
	end,
}

-- ---- TalonRake --------------------------------------------------------------

local RAKE_COCK = B({ y = 0.3, pitch = 0.5, neck = 0.15, head = 0.3, jaw = -0.85, crest = -0.4, legs = -0.55, toes = -0.3, tail = 0.9 })
local RAKE_HIT = B({ y = -0.45, pitch = -0.12, neck = -0.2, head = -0.35, jaw = -0.15, crest = 0.5, legs = 1.4, toes = 1.0, tail = 0.2 })

moves.TalonRake = {
	windup = {
		duration = 0.35,
		keys = { key(0, ARRIVE), key(0.55, RAKE_COCK, "out"), key(1, B({ y = 0.4, pitch = 0.58, neck = 0.15, head = 0.3, jaw = -0.9, crest = -0.45, legs = -0.7, toes = -0.4, tail = 0.95 }), "inOut") },
		overlay = function(u, _secs, _input)
			local t = u * 0.35
			local style = Flap.mix(FLARE, COCK, smooth(0, 0.5, u))
			style.top = style.top + 0.05 * math.sin(t * 70) * u
			local pose: Pose = {}
			wings(pose, style, 0)
			return pose
		end,
	},
	active = {
		duration = 0.12,
		keys = { key(0, B({ y = 0.4, pitch = 0.58, neck = 0.15, head = 0.3, jaw = -0.9, crest = -0.45, legs = -0.7, toes = -0.4, tail = 0.95 })), key(0.5, RAKE_HIT, "in"), key(1, B({ y = -0.45, pitch = -0.1, neck = -0.2, head = -0.3, jaw = -0.1, crest = 0.5, legs = 1.45, toes = 1.05, tail = 0.15 }), "out") },
		overlay = function(u, _secs, _input)
			local style = Flap.mix(COCK, POWER, 1)
			style.amp = 1
			-- a single down-stroke from the cocked top to the bottom over the whole phase
			local pose: Pose = {}
			wings(pose, style, 2.51 * smooth(0, 0.9, u))
			return pose
		end,
	},
	recover = {
		duration = 0.88,
		keys = {
			key(0, B({ y = -0.45, pitch = -0.1, neck = -0.2, head = -0.3, jaw = -0.1, crest = 0.5, legs = 1.45, toes = 1.05, tail = 0.15 })),
			key(0.2, B({ y = -0.3, pitch = 0.3, neck = -0.1, head = -0.2, jaw = -0.3, crest = 0.3, legs = 1.0, toes = 0.6, tail = 0.5 }), "out"),
			key(0.32, PERCH, "inOut"),
			key(0.72, B({ y = 0, pitch = 0.2, neck = -0.4, head = -0.8, jaw = -0.12, crest = 0.5, legs = 0.35, toes = 0.3, tail = 0.55 }), "linear"),
			key(0.86, B({ y = 0.3, pitch = 0.3, neck = 0.1, head = 0, jaw = -0.3, crest = 0.2, legs = -0.1, toes = 0.2, tail = 0.5 }), "inOut"),
			key(1, B({ y = 0, pitch = 0.04, legs = -0.1, toes = 0.25, tail = 0.15, crest = -0.1 }), "out"),
		},
		overlay = function(u, secs, input)
			-- the wings follow through (the down-stroke's bottom) then droop like the dive's perch
			local pose = perchOverlay(u, secs, input, 0.88)
			local through = 1 - smooth(0, 0.3, u)
			if through > 0 then
				local follow = Flap.mix(POWER, DROOP, 1 - through)
				follow.amp = 1
				local w: Pose = {}
				wings(w, follow, 2.51 + 0.5 * (1 - through))
				for name, cf in w do
					pose[name] = (pose[name] or I):Lerp(cf, through)
				end
			end
			return pose
		end,
	},
}

-- ---- TalonDiveSkid (LEAD: head and body follow the live yaw to the target) ----

local function skidOverlay(u: number, _secs: number, input: Input): Pose
	local D = 1.2
	local t = u * D
	local ty = math.clamp(input.targetYaw or ((input.side or 1) * -1.0), -1.4, 1.4)
	local lead = smooth(0.04, 0.2, u) * (1 - smooth(0.6, 1, u))
	local headFirst = smooth(0.04, 0.16, u) * (1 - smooth(0.5, 0.85, u))
	local pose: Pose = {}
	-- the air-brake flare, then hard turning strokes
	local brake = 1 - smooth(0.15, 0.3, u)
	local style = Flap.mix(HOVER, POWER, smooth(0.25, 0.4, u) * (1 - smooth(0.7, 0.95, u)))
	local s2 = Flap.mix(style, FLARE, brake)
	local theta = Flap.phaseAt({ { 0, 0 }, { 0.3 * D, 0 }, { 0.4 * D, 26 }, { 0.75 * D, 22 }, { D, 16 } }, t)
	wings(pose, s2, theta)
	add(pose, {
		JointNeck = A(0, ty * 0.35 * headFirst, 0),
		JointHead = A(0, ty * 0.45 * headFirst, 0),
		JointRoot = A(0, ty * 0.25 * lead, math.clamp(ty, -1, 1) * 0.45 * bump(u, 0.15, 0.95)),
		JointTail = A(0, -ty * 0.3 * lead, 0),
	})
	return pose
end

moves.TalonDiveSkid = {
	recover = {
		duration = 1.2,
		keys = {
			key(0, ARRIVE),
			key(0.14, B({ y = 0.5, pitch = 0.75, neck = 0.2, head = 0.25, jaw = -0.6, crest = -0.4, legs = 1.3, toes = 0.9, tail = 1.0 }), "out"), -- the brake
			key(0.45, B({ y = 0.9, pitch = 0.15, neck = 0, head = -0.05, jaw = -0.35, crest = 0, legs = 0.6, toes = 0.4, tail = 0.6 }), "inOut"),
			key(0.75, B({ y = 0.5, pitch = -0.05, legs = 0.1, toes = 0.3, tail = 0.3, jaw = -0.15 }), "inOut"),
			key(1, B({ y = 0, pitch = 0.04, legs = -0.1, toes = 0.25, tail = 0.15, crest = -0.1 }), "inOut"),
		},
		overlay = skidOverlay,
	},
}
FlameRaven.LEAD = { TalonDiveSkid = true }

-- ---- EmberFan ---------------------------------------------------------------

local FAN_COIL = B({ y = -0.45, pitch = -0.2, neck = -0.2, head = -0.3, jaw = -0.15, crest = -0.4, legs = 0.3, toes = 0.4, tail = -0.3 })
local FAN_REAR = B({ y = 1.0, pitch = 0.6, neck = 0.3, head = 0.4, jaw = -0.85, crest = -0.75, legs = -0.4, toes = 0.2, tail = 0.55 })

moves.EmberFan = {
	windup = {
		duration = 1.0,
		keys = {
			key(0, B({})),
			key(0.22, FAN_COIL, "out"),
			key(0.58, FAN_REAR, "inOut"),
			key(0.7, B({ y = 1.05, pitch = 0.62, neck = 0.3, head = 0.42, jaw = -0.9, crest = -0.8, legs = -0.4, toes = 0.2, tail = 0.6 }), "out"),
			key(1, B({ y = 1.1, pitch = 0.64, neck = 0.3, head = 0.42, jaw = -0.9, crest = -0.8, legs = -0.4, toes = 0.2, tail = 0.6 }), "linear"),
		},
		overlay = function(u, _secs, _input)
			local t = u
			local pose: Pose = {}
			local sweep = smooth(0.2, 0.56, u)
			local style = Flap.mix(Flap.mix(HOVER, LOW, smooth(0, 0.2, u)), OVERHEAD, sweep)
			style.amp = 0
			style.top = Flap.curve({ { 0, 0.95 }, { 0.2, -0.35 }, { 0.58, 1.55 }, { 1, 1.6 } }, u) + 0.05 * math.sin(t * 60) * smooth(0.7, 0.8, u)
			wings(pose, style, 0)
			tremble(pose, t, smooth(0.68, 0.8, u))
			return pose
		end,
	},
	active = {
		duration = 0.1,
		keys = {
			key(0, B({ y = 1.1, pitch = 0.64, neck = 0.3, head = 0.42, jaw = -0.9, crest = -0.8, legs = -0.4, toes = 0.2, tail = 0.6 })),
			key(1, B({ y = 0.45, pitch = -0.12, neck = -0.1, head = -0.2, jaw = -0.2, crest = -0.5, legs = 0.3, toes = 0.4, tail = 0.9 }), "in"),
		},
		overlay = function(u, _secs, _input)
			local style = Flap.mix(OVERHEAD, POWER, 1)
			style.amp = 1
			style.top = 1.55
			style.bottom = -0.8
			local pose: Pose = {}
			wings(pose, style, 2.51 * smooth(0, 1, u))
			return pose
		end,
	},
	recover = {
		duration = 0.8,
		keys = {
			key(0, B({ y = 0.45, pitch = -0.12, neck = -0.1, head = -0.2, jaw = -0.2, crest = -0.5, legs = 0.3, toes = 0.4, tail = 0.9 })),
			key(0.1, B({ y = 0.75, pitch = 0.2, neck = 0.1, head = 0.1, jaw = -0.45, crest = -0.6, legs = 0.1, toes = 0.3, tail = 0.5 }), "out"),
			key(0.3, B({ y = 0.6, pitch = 0.1, neck = 0, head = 0, jaw = -0.3, crest = -0.4, legs = 0, toes = 0.3, tail = 0.5 }), "inOut"),
			key(1, B({ y = 0, pitch = 0.04, legs = -0.1, toes = 0.25, tail = 0.15, crest = -0.1 }), "inOut"),
		},
		overlay = function(u, _secs, _input)
			local D = 0.8
			local t = u * D
			local style = Flap.mix(POWER, HOVER, smooth(0.4, 0.95, u))
			style.top = 1.55 + (0.95 - 1.55) * smooth(0.2, 0.7, u)
			-- stroke 2 starts at 0.05 s and stroke 3 at 0.2 s (one every 0.15 s), from the bottom of flick 1
			local theta = 2.51 + Flap.phaseAt({ { 0, 41.9 }, { 0.3, 41.9 }, { 0.5, 15 }, { D, 15 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			-- each flick snaps the tail fan and jerks the head
			local f = bump((t % 0.15) / 0.15, 0, 1) * (1 - smooth(0.3, 0.45, t))
			add(pose, { JointTail = A(0.3 * f, 0, 0), JointHead = A(-0.15 * f, 0, 0), JointRoot = CFrame.new(0, 0.12 * f, 0) })
			return pose
		end,
	},
}

-- ---- WindGust ---------------------------------------------------------------

local GUST_UP = B({ y = 0.7, pitch = 0.6, neck = 0.2, head = 0.35, jaw = -0.7, crest = -0.4, legs = -0.3, toes = 0.2, tail = 0.5 })

moves.WindGust = {
	windup = {
		duration = 0.5,
		keys = {
			key(0, B({})),
			key(0.15, B({ y = -0.15, pitch = 0.1, legs = 0.1, crest = -0.2, tail = -0.1 }), "out"),
			key(0.7, GUST_UP, "inOut"),
			key(1, B({ y = 0.8, pitch = 0.66, neck = 0.2, head = 0.38, jaw = -0.75, crest = -0.45, legs = -0.35, toes = 0.2, tail = 0.55 }), "out"),
		},
		overlay = function(u, _secs, _input)
			local style = Flap.mix(HOVER, GUST_COCK, smooth(0.12, 0.7, u))
			style.amp = 0
			style.top = C({ { 0, 0.95 }, { 0.15, 0.7 }, { 0.7, 1.5 }, { 1, 1.52 } }, u) + 0.04 * math.sin(u * 40) * smooth(0.7, 0.9, u)
			local pose: Pose = {}
			wings(pose, style, 0)
			return pose
		end,
	},
	active = {
		duration = 0.1,
		keys = {
			key(0, B({ y = 0.8, pitch = 0.66, neck = 0.2, head = 0.38, jaw = -0.75, crest = -0.45, legs = -0.35, toes = 0.2, tail = 0.55 })),
			key(1, B({ y = 0.2, pitch = -0.2, neck = -0.2, head = -0.2, jaw = -0.4, crest = -0.7, legs = 0.4, toes = 0.4, tail = 0.8 }), "in"),
		},
		overlay = function(u, _secs, _input)
			local pose: Pose = {}
			wings(pose, POWER, 2.51 * smooth(0, 1, u))
			return pose
		end,
	},
	recover = {
		duration = 0.6,
		keys = {
			key(0, B({ y = 0.2, pitch = -0.2, neck = -0.2, head = -0.2, jaw = -0.4, crest = -0.7, legs = 0.4, toes = 0.4, tail = 0.8 })),
			key(0.25, B({ y = 0.6, pitch = 0.15, neck = 0, head = 0, jaw = -0.2, crest = -0.4, legs = 0, toes = 0.3, tail = 0.4 }), "out"),
			key(1, B({ y = 0, pitch = 0.04, legs = -0.1, toes = 0.25, tail = 0.15, crest = -0.1 }), "inOut"),
		},
		overlay = function(u, _secs, _input)
			local D = 0.6
			local t = u * D
			local style = Flap.mix(POWER, HOVER, smooth(0.3, 0.9, u))
			local theta = 2.51 + Flap.phaseAt({ { 0, 28 }, { 0.3, 24 }, { D, 15 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			return pose
		end,
	},
}

-- ---- Hop (a back-flap away) -------------------------------------------------

moves.Hop = {
	active = {
		duration = 0.3,
		air = true,
		keys = {
			key(0, B({})),
			key(0.2, B({ y = -0.15, pitch = 0.4, neck = -0.1, head = -0.2, legs = 0.5, toes = 0.4, tail = 0.5, jaw = -0.2 }), "out"),
			key(0.55, B({ y = 0.45, pitch = 0.45, neck = 0, head = 0.1, legs = 0.2, toes = 0.3, tail = 0.7, jaw = -0.3 }), "inOut"),
			key(1, B({ y = 0.15, pitch = 0.12, legs = -0.05, toes = 0.25, tail = 0.3 }), "inOut"),
		},
		overlay = function(u, _secs, _input)
			local style = Flap.mix(POWER, HOVER, 0.15)
			style.yawAmp = { 0.5, 0.3, 0.15 }
			local pose: Pose = {}
			wings(pose, style, 41.9 * u * 0.3)
			return pose
		end,
	},
}

-- ---- Stagger and Death ------------------------------------------------------

moves.Stagger = {
	active = {
		duration = 0.28,
		keys = {
			key(0, B({})),
			key(0.25, B({ y = -0.25, pitch = 0.62, roll = 0.0, neck = 0.35, head = 0.5, jaw = -0.55, crest = 0.3, legs = 0.9, toes = 0.6, tail = 0.9 }), "out"),
			key(0.6, B({ y = -0.35, pitch = 0.45, neck = 0.2, head = 0.3, jaw = -0.4, crest = 0.1, legs = 0.6, toes = 0.4, tail = 0.7 }), "inOut"),
			key(1, B({ y = -0.05, pitch = 0.12, legs = 0.1, toes = 0.3, tail = 0.3 }), "inOut"),
		},
		overlay = function(u, _secs, input)
			local side = input.side or 1
			local e = smooth(0, 0.25, u) * (1 - smooth(0.6, 1, u) * 0.8)
			-- the wing nearer the hit is flung up hardest; the body rolls and the head turns away
			local near = Flap.mix(HOVER, GUST_COCK, 1)
			near.amp = 0
			near.top = 0.95 + 0.7 * e
			local far = Flap.mix(HOVER, GUST_COCK, 1)
			far.amp = 0
			far.top = 0.95 + 0.25 * e
			local pose: Pose = {}
			if side >= 0 then
				wings(pose, far, 0, near, 0) -- the hit came from its right: the right wing (second) is nearer
			else
				wings(pose, near, 0, far, 0)
			end
			add(pose, {
				JointRoot = A(0, -side * 0.2 * e, side * -0.4 * e),
				JointHead = A(0, -side * 0.45 * e, 0),
			})
			return pose
		end,
	},
}

local DEAD_FLAIL = B({ y = -0.3, pitch = 0.75, neck = 0.4, head = 0.55, jaw = -0.7, crest = 0.3, legs = 1.0, toes = 0.7, tail = 0.9 })
moves.Death = {
	active = {
		duration = 1.4,
		keys = {
			key(0, B({})),
			key(0.12, DEAD_FLAIL, "out"),
			key(0.3, B({ y = -0.5, pitch = 0.5, roll = 0.6, neck = 0.2, head = 0.3, jaw = -0.6, legs = 0.8, toes = 0.6, tail = 0.8 }), "inOut"),
			key(0.62, B({ y = -2.0, pitch = -0.6, roll = 1.0, neck = -0.3, head = -0.5, jaw = -0.3, legs = 0.4, toes = 0.2, tail = 0.4 }), "in"),
			key(0.78, B({ y = -3.05, pitch = 0.05, roll = 0.12, neck = -0.5, head = -0.6, jaw = -0.2, legs = -0.5, toes = -0.3, tail = 0.5 }), "in"),
			key(0.86, B({ y = -2.8, pitch = 0.12, roll = 0.1, neck = -0.5, head = -0.55, jaw = -0.25, legs = -0.5, toes = -0.3, tail = 0.45 }), "out"),
			key(1, B({ y = -3.05, pitch = 0.05, roll = 0.12, neck = -0.55, head = -0.6, jaw = -0.15, legs = -0.5, toes = -0.3, tail = 0.5 }), "in"),
		},
		overlay = function(u, secs, input)
			local t = secs
			local flail = (1 - smooth(0.55, 0.75, u)) * smooth(0, 0.1, u)
			local limp = smooth(0.55, 0.85, u)
			local style = Flap.mix(Flap.mix(HOVER, GUST_COCK, smooth(0, 0.12, u)), DEAD_WINGS, limp)
			style.amp = 0.9 * flail
			style.bottom = -0.2
			local theta = Flap.phaseAt({ { 0, 30 }, { 1.4, 12 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			return pose
		end,
	},
}

FlameRaven.moves = moves
FlameRaven.durations = Quadruped.durations(moves)

------------------------------------------------------------------------------------
-- API

function FlameRaven.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = moves[move]
	local p = m and m[phase]
	assert(p, ("FlameRaven.sample: no %s.%s"):format(move, phase))
	local pose = Quadruped.samplePhase(p, u, input or {})
	-- Death rolls onto the side away from the kill: the keys roll toward +Z (its left)
	if move == "Death" and input and (input.side or 1) < 0 then
		local r = pose.JointRoot
		if r then
			local x, y, z = r:ToEulerAnglesXYZ()
			pose.JointRoot = CFrame.new(r.Position) * A(x, -y, -z)
		end
	end
	return pose
end

function FlameRaven.scaled(pose: Pose, _scale: number): Pose
	return pose
end

function FlameRaven.plant(pose: Pose): Pose
	return pose
end

return FlameRaven
