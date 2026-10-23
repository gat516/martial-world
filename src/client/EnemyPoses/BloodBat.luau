--!strict
-- Procedural pose tables for the Iron-Winged Blood Bat (Enemies.BloodBat, 1.0x; art/enemies/
-- beasts/rigs/blood-bat.md ("Blood Bat"). Same FORMAT and API as Wolf.luau (read its header); the shared
-- wing stroke is in Flap.luau, the notes in art/enemies/beasts/poses_blood_bat.md.
--
-- EnemyAnimator FAMILIES registration (needs the request in the .md: motion/loop smoothing):
--   FAMILIES.BloodBat = {
--       poses = BloodBat, scale = 1, runFrom = 14, keyedBlend = 0.06, deathSeconds = 1.2,
--       staggerSeconds = 0.25,
--       moves = { bloodDive = "BloodDive", sonicShriek = "SonicShriek", hop = "Hop",
--                 bloodDiveSkid = "BloodDiveSkid" },
--   }
--
-- RIG: faces -Z, hover pivot (the HRP centre, Y 4.6); 13 joints. JointRoot is the body (pivot
-- at its centre): translate Y = climbs, dives, bobs; +X pitch tips the nose UP; +Z rolls the
-- top toward the bat's left. Wings: JointWingL/R (shoulder), 2 (elbow), 3 (finger); roll Z
-- lifts (L up = -Z, R up = +Z); a sweep BACK is +Y on L and -Y on R (measured; the brief and
-- RIGS.md had it reversed). JointHead +X tips up, JointJaw -X opens (the MouthTell inside),
-- JointEarL/R: +X pins them back, roll Z flares (L +Z out, R -Z out), JointLegL/R +X swings
-- the feet forward. The membranes are thin sheets: every wing segment keeps an elevation of
-- 0.3 rad or more (Flap style `floor`) so they never go edge-on to a level camera.
--
-- THE BAT IS TWITCHY: the head, ears and the whole body jump to new angles several times a
-- second (Flap.twitch), the beak chitters, the wings beat at ~7 Hz.
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt: the telegraph, tell flare and
-- sound start with the first frame of each windup)
--   BloodDive   windup 0.6  a 0.09 s dip, then a fast climb 1.3 studs on hard strokes, the
--                           wings snapping back at the top (0.4 s), nose over, beak bared,
--                           the body shivering harder (the tell flare) until the drop
--               active 0.47 the stoop: wings folded back along the flanks, nose down, a
--                           shaking fall; the last 0.12 s flares (wings forward, claws and
--                           jaw wide) for the bite
--               recover 0.8 the leech (0.5 s): clamped on, the head shaking, the beak
--                           chewing, the chest pulsing, shallow fast wings; then a power
--                           stroke and nose up to flap away (the Hop follows)
--   BloodDiveSkid recover 0.8 (LEAD) the miss: brake flare, the head whips round to the live
--                           targetYaw and leads, the body banks round with hard strokes
--   SonicShriek windup 1.0  a 0.2 s breath in (wings drawn in, coiled), then the rear: head
--                           back, beak wide, ears flared, wings thrown wide, the whole body
--                           vibrating harder until 1.0
--               active 0.1  the shriek: head snaps up, jaw to the stop, a violent shake
--               recover 0.8 (0.7 after the active) jaw shuts, a dizzy wobble, the wings
--                           resume with hard strokes
--   Hop         active 0.25 (air) a flap-away: two quick strokes, nose up
--   Stagger     active 0.25 thrown back, tumbling wings (input.side tilts it)
--   Death       active 1.2, then hold u = 1: wings flung, a flailing tumble, belly-down
--               on the ground with the wings spread
-- LOOPS: idle (hover flap, twitching), walk, run (leaning in, deep fast strokes), circle
--   (banked). All wing strokes need a fast enough joint smoothing in EnemyAnimator (request).
--
-- API (as Wolf.luau): BloodBat.sample(move, phase, u, input?) -> Pose,
--   BloodBat.loops.idle(clock, speed, input?) / walk(phase, speed, input?) / run / circle,
--   .gaitRate(loop, speed, scale?), .scaled(pose, scale), .plant(pose) (a no-op),
--   .moves, .durations, .JOINTS, .LEAD.

local Quadruped = require(script.Parent.Quadruped)
local Flap = require(script.Parent.Flap)

local BloodBat = {}

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Style = Flap.Style

local I = CFrame.identity
local A = CFrame.Angles
local C = Flap.curve
local wave = Flap.wave
local twitch = Flap.twitch
local smooth = Quadruped.smooth
local bump = Quadruped.bump

BloodBat.JOINTS = {
	"JointRoot", "JointHead", "JointJaw", "JointEarL", "JointEarR",
	"JointWingL", "JointWingL2", "JointWingL3", "JointWingR", "JointWingR2", "JointWingR3",
	"JointLegL", "JointLegR",
}
local NAMES = {
	L = { "JointWingL", "JointWingL2", "JointWingL3" },
	R = { "JointWingR", "JointWingR2", "JointWingR3" },
}

local A0 = 0.436 -- the rest elevation (25 degrees)
-- Per-joint limits for the membranes (measured in Studio): the three skins rest at signed
-- elevations +0.45, +0.25 and -0.61 (the finger skin slopes DOWN), so a skin keeps |elev| >= 0.3
-- with the shoulder >= 0.3, the elbow >= 0.5 and the finger <= 0.74.
local FLOOR = { 0.34, 0.54, 0.2 }
local CEIL = { 9, 9, 0.74 }

------------------------------------------------------------------------------------
-- Wing styles (see Flap.luau). Every live style keeps floor = 0.3.

local HOVER: Style = {
	A0 = A0, top = 1.05, bottom = 0.3, amp = 1, lag = 0.8, d = 0.4, k2 = 1.2, k3 = 1.5, floor = FLOOR, ceil = CEIL,
	yaw = { 0, 0, 0 }, yawAmp = { 0.35, 0.25, 0.15 }, bend = { 0, 0, 0 },
}
local RUN: Style = {
	A0 = A0, top = 1.1, bottom = 0.3, amp = 1, lag = 0.85, d = 0.38, k2 = 1.25, k3 = 1.6, floor = FLOOR, ceil = CEIL,
	yaw = { 0.3, 0.25, 0.2 }, yawAmp = { 0.4, 0.3, 0.2 }, bend = { 0, 0, 0 },
}
local COCK: Style = { -- snapped up and back at the top of the climb
	A0 = A0, top = 1.2, bottom = 0.3, amp = 0, lag = 0.8, floor = FLOOR, ceil = CEIL,
	yaw = { 0.8, 0.7, 0.5 }, yawAmp = { 0, 0, 0 }, bend = { 0, 0, 0.1 },
}
local FOLD: Style = { -- folded back along the flanks for the stoop
	A0 = A0, top = 0.5, bottom = 0.3, amp = 0, lag = 0.8, floor = FLOOR, ceil = CEIL,
	yaw = { 0.8, 0.7, 0.5 }, yawAmp = { 0, 0, 0 }, bend = { 0, -0.05, -0.1 },
}
local FLARE: Style = { -- spread in front to brake and bite
	A0 = A0, top = 0.95, bottom = 0.3, amp = 0, lag = 0.8, floor = FLOOR, ceil = CEIL,
	yaw = { -0.4, -0.3, -0.2 }, yawAmp = { 0, 0, 0 }, bend = { 0, 0.1, 0.2 },
}
local SPREAD: Style = { -- thrown wide for the shriek
	A0 = A0, top = 1.3, bottom = 0.3, amp = 0, lag = 0.8, floor = FLOOR, ceil = CEIL,
	yaw = { -0.15, -0.1, 0 }, yawAmp = { 0, 0, 0 }, bend = { 0, 0.1, 0.2 },
}
local DRAWN: Style = { -- drawn in, lowered, for the breath before the shriek
	A0 = A0, top = 0.5, bottom = 0.3, amp = 0, lag = 0.8, floor = FLOOR, ceil = CEIL,
	yaw = { 0.5, 0.4, 0.3 }, yawAmp = { 0, 0, 0 }, bend = { 0, -0.1, -0.15 },
}
local POWER: Style = {
	A0 = A0, top = 1.3, bottom = 0.3, amp = 1, lag = 0.9, d = 0.4, k2 = 1.25, k3 = 1.6, floor = FLOOR, ceil = CEIL,
	yaw = { 0.1, 0, 0 }, yawAmp = { 0.6, 0.4, 0.25 }, bend = { 0, 0, 0 },
}
local DEAD_WINGS: Style = { -- spread flat on the ground (no floor: it is dead)
	A0 = A0, top = -0.05, bottom = -0.2, amp = 0, lag = 0.8, floor = -10, ceil = 9,
	yaw = { 0.1, 0.2, 0.3 }, yawAmp = { 0, 0, 0 }, bend = { 0, -0.05, -0.1 },
}

local function wings(pose: Pose, style: Style, theta: number, styleR: Style?, thetaR: number?)
	Flap.write(pose, Flap.cycle(theta, style, styleR, thetaR), NAMES)
end

local function add(pose: Pose, extra: Pose)
	for name, cf in extra do
		pose[name] = (pose[name] or I) * cf
	end
end

------------------------------------------------------------------------------------
-- Body

local function B(o: { [string]: number }): Pose
	local g = function(k: string): number
		return o[k] or 0
	end
	local out = g("out")
	return {
		JointRoot = CFrame.new(g("x"), g("y"), g("z")) * A(g("pitch"), g("yaw"), g("roll")),
		JointHead = A(g("head"), g("headYaw"), g("headRoll")),
		JointJaw = A(g("jaw"), 0, 0),
		JointEarL = A(g("ear"), 0, out),
		JointEarR = A(g("ear"), 0, -out),
		JointLegL = A(g("legs"), 0, 0),
		JointLegR = A(g("legs"), 0, 0),
	}
end

-- the nervous bat: head, ears and body jump to new angles; k scales it
local function nerves(t: number, seed: number, k: number): Pose
	return {
		JointHead = A(0.22 * twitch(t, 5, seed, 0.18) * k, 0.55 * twitch(t, 4.3, seed + 1, 0.2) * k, 0.2 * twitch(t, 6, seed + 2, 0.2) * k),
		JointEarL = A(0.25 * twitch(t, 9, seed + 3, 0.15) * k, 0, 0.3 * twitch(t, 7, seed + 4, 0.15) * k),
		JointEarR = A(0.25 * twitch(t, 8.3, seed + 5, 0.15) * k, 0, -0.3 * twitch(t, 7.4, seed + 6, 0.15) * k),
		JointRoot = CFrame.new(0.12 * twitch(t, 3.1, seed + 7, 0.25) * k, 0, 0) * A(0, 0.08 * twitch(t, 3.7, seed + 8, 0.2) * k, 0.07 * twitch(t, 4.9, seed + 9, 0.2) * k),
		JointJaw = A(-0.1 * math.max(0, twitch(t, 11, seed + 10, 0.1)) * k, 0, 0),
	}
end

-- a violent whole-body shake (tell flares, the shriek)
local function shake(pose: Pose, t: number, k: number)
	if k <= 0 then
		return
	end
	add(pose, {
		JointRoot = CFrame.new(0.07 * k * math.sin(t * 91), 0.07 * k * math.sin(t * 77), 0) * A(0.05 * k * math.sin(t * 83), 0.06 * k * math.sin(t * 71), 0.08 * k * math.sin(t * 97)),
		JointHead = A(0.06 * k * math.sin(t * 89), 0.08 * k * math.sin(t * 79), 0),
		JointEarL = A(0.15 * k * math.sin(t * 101), 0, 0.15 * k * math.sin(t * 87)),
		JointEarR = A(0.15 * k * math.sin(t * 93), 0, -0.15 * k * math.sin(t * 85)),
	})
end

local function hover(theta: number, o: { [string]: number }): Pose
	local lift = -wave(theta - 1.0)
	local pitch = (o.lean or 0) + 0.08 * -wave(theta - 0.5)
	local pose = B({
		y = 0.1 * lift,
		pitch = pitch,
		roll = o.bank or 0,
		head = -pitch * 0.6 + (o.head or 0),
		legs = -0.35 + 0.15 * wave(theta - 2.0) + (o.legs or 0),
		ear = 0.15 + 0.12 * wave(theta - 2.5) + (o.ear or 0),
		jaw = o.jaw or 0,
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

local loops = {}

function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local theta = clock * 46 + seed
	local pose = hoverPose(theta, HOVER, {})
	add(pose, nerves(clock, seed, 1))
	return pose
end

function loops.walk(phase: number, speed: number, input: Input?): Pose
	local pose = hoverPose(phase, HOVER, { lean = -0.12 - 0.01 * speed })
	add(pose, nerves(os.clock(), (input and input.seed) or 0, 0.6))
	return pose
end

function loops.run(phase: number, speed: number, input: Input?): Pose
	local pose = hoverPose(phase, RUN, { lean = -0.3 - 0.008 * math.min(speed, 20), legs = 0.3 })
	add(pose, nerves(os.clock(), (input and input.seed) or 0, 0.35))
	return pose
end

function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = (input and input.dir) or 1
	local ty = math.clamp((input and input.targetYaw) or 0, -0.9, 0.9)
	local pose = hoverPose(phase, RUN, { lean = -0.12 - 0.008 * speed, bank = 0.35 * dir })
	add(pose, nerves(os.clock(), (input and input.seed) or 0, 0.5))
	add(pose, { JointHead = A(0, ty * 0.5, 0) })
	return pose
end

BloodBat.loops = loops

function BloodBat.gaitRate(loop: string, speed: number, _scale: number?): number
	if loop == "walk" then
		return 46 + 0.6 * speed
	elseif loop == "run" then
		return 52 + 0.3 * speed
	end
	return 50
end

------------------------------------------------------------------------------------
-- Moves

local moves: { [string]: { [string]: Quadruped.Phase } } = {}

local function key(t: number, pose: Pose, ease: string?): Quadruped.Key
	return { t = t, pose = pose, ease = ease }
end

local REST = B({ legs = -0.35, ear = 0.15 })
local HOVER_END = B({ y = 0, pitch = 0.04, legs = -0.35, ear = 0.2 })

-- ---- BloodDive --------------------------------------------------------------

local DIVE_APEX = B({ y = 1.35, pitch = -0.4, head = -0.45, jaw = -0.55, legs = 0.55, ear = 0.7, out = -0.1 })
local STOOP = B({ y = 0.9, pitch = -0.95, head = 0.55, jaw = -0.5, legs = 0.7, ear = 0.05, out = 0.3 })
local BITE = B({ y = 0, pitch = 0.45, head = 0.2, jaw = -0.95, legs = 1.1, ear = 0.0, out = 0.4 })

moves.BloodDive = {
	windup = {
		duration = 0.6,
		keys = {
			key(0, REST),
			key(0.15, B({ y = -0.25, pitch = -0.12, head = -0.1, legs = 0.2, ear = 0.4 }), "out"),
			key(0.62, B({ y = 1.3, pitch = 0.5, head = 0.1, jaw = -0.2, legs = -0.1, ear = 0.4, out = 0.3 }), "inOut"),
			key(1, DIVE_APEX, "inOut"),
		},
		overlay = function(u, _secs, _input)
			local t = u * 0.6
			local style = Flap.mix(POWER, COCK, smooth(0.62, 0.78, u))
			style.amp = C({ { 0, 0 }, { 0.12, 0 }, { 0.2, 1 }, { 0.58, 1 }, { 0.72, 0 }, { 1, 0 } }, u)
			local theta = Flap.phaseAt({ { 0, 0 }, { 0.07, 0 }, { 0.1, 62 }, { 0.4, 66 }, { 0.5, 20 }, { 0.6, 0 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			shake(pose, t, smooth(0.45, 0.9, u))
			return pose
		end,
	},
	active = {
		duration = 0.47,
		keys = {
			key(0, DIVE_APEX),
			key(0.2, STOOP, "in"),
			key(0.75, B({ y = 0.25, pitch = -0.7, head = 0.45, jaw = -0.5, legs = 0.8, ear = 0.05, out = 0.3 }), "linear"),
			key(1, BITE, "out"),
		},
		overlay = function(u, _secs, _input)
			local t = u * 0.47
			local fold = smooth(0, 0.12, u)
			local flare = smooth(0.74, 0.92, u)
			local style = Flap.mix(Flap.mix(COCK, FOLD, fold), FLARE, flare)
			local pose: Pose = {}
			wings(pose, style, 0)
			shake(pose, t, 0.5 * (1 - flare))
			return pose
		end,
	},
}

-- the leech: clamped on and gorging, then the push off
moves.BloodDive.recover = {
	duration = 0.8,
	keys = {
		key(0, BITE),
		key(0.1, B({ y = -0.1, pitch = 0.1, head = -0.15, jaw = -0.5, legs = 0.9, ear = 0.05, out = 0.3 }), "out"),
		key(0.6, B({ y = -0.05, pitch = 0.05, head = -0.15, jaw = -0.3, legs = 0.8, ear = 0.05, out = 0.3 }), "linear"),
		key(0.78, B({ y = -0.3, pitch = 0.5, head = 0.3, jaw = -0.1, legs = 0.3, ear = 0.05, out = 0.3 }), "inOut"),
		key(1, B({ y = 0.4, pitch = 0.45, head = 0.15, legs = -0.1, ear = 0.2 }), "out"),
	},
	overlay = function(u, secs, _input)
		local D = 0.8
		local t = u * D
		local pose: Pose = {}
		local gorge = smooth(0.05, 0.12, u) * (1 - smooth(0.58, 0.64, u))
		local push = smooth(0.62, 0.8, u)
		local style = Flap.mix(Flap.mix(FLARE, HOVER, smooth(0, 0.15, u)), POWER, push)
		style.amp = (0.4 + 0.6 * push)
		local theta = Flap.phaseAt({ { 0, 30 }, { 0.5, 50 }, { D, 62 } }, t)
		wings(pose, style, theta)
		-- the bite shakes the head (fast), the beak chews, the chest pulses
		add(pose, {
			JointHead = A(0.12 * math.sin(t * 40) * gorge, 0.4 * math.sin(t * 31) * gorge, 0.2 * math.sin(t * 37) * gorge),
			JointJaw = A(-0.35 * (0.5 + 0.5 * math.sin(t * 36)) * gorge, 0, 0),
			JointRoot = CFrame.new(0, 0.1 * math.sin(t * 22) * gorge, 0) * A(0, 0.1 * math.sin(t * 29) * gorge, 0.08 * math.sin(t * 34) * gorge),
		})
		return pose
	end,
}

-- ---- BloodDiveSkid (LEAD) ---------------------------------------------------

moves.BloodDiveSkid = {
	recover = {
		duration = 0.8,
		keys = {
			key(0, BITE),
			key(0.14, B({ y = -0.1, pitch = 0.8, head = 0.25, jaw = -0.7, legs = 1.0, ear = 0.4, out = 0.2 }), "out"),
			key(0.45, B({ y = 0.2, pitch = 0.2, head = 0, jaw = -0.3, legs = 0.4, ear = 0.3 }), "inOut"),
			key(0.8, B({ y = 0.1, pitch = 0, legs = 0, ear = 0.2 }), "inOut"),
			key(1, HOVER_END, "inOut"),
		},
		overlay = function(u, _secs, input)
			local D = 0.8
			local t = u * D
			local ty = math.clamp(input.targetYaw or ((input.side or 1) * -1.0), -1.4, 1.4)
			local lead = smooth(0.04, 0.2, u) * (1 - smooth(0.6, 1, u))
			local headFirst = smooth(0.03, 0.12, u) * (1 - smooth(0.45, 0.8, u))
			local brake = 1 - smooth(0.15, 0.28, u)
			local style = Flap.mix(Flap.mix(HOVER, POWER, smooth(0.22, 0.35, u) * (1 - smooth(0.7, 0.95, u))), FLARE, brake)
			local theta = Flap.phaseAt({ { 0, 0 }, { 0.2 * D, 0 }, { 0.3 * D, 66 }, { D, 50 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			add(pose, {
				JointHead = A(0, ty * 0.8 * headFirst, 0),
				JointRoot = A(0, ty * 0.3 * lead, math.clamp(ty, -1, 1) * 0.5 * bump(u, 0.12, 0.95)),
			})
			return pose
		end,
	},
}
BloodBat.LEAD = { BloodDiveSkid = true }

-- ---- SonicShriek ------------------------------------------------------------

local SHRIEK_REAR = B({ y = 0.45, pitch = 0.55, head = 0.6, jaw = -0.95, legs = 0.3, ear = -0.15, out = 0.6 })
local SHRIEK_HOLD = B({ y = 0.5, pitch = 0.6, head = 0.65, jaw = -1.0, legs = 0.3, ear = -0.15, out = 0.7 })

moves.SonicShriek = {
	windup = {
		duration = 1.0,
		keys = {
			key(0, REST),
			key(0.2, B({ y = -0.2, pitch = -0.25, head = -0.25, jaw = -0.1, legs = 0.3, ear = 0.5 }), "out"), -- the breath in
			key(0.56, SHRIEK_REAR, "inOut"),
			key(1, SHRIEK_HOLD, "out"),
		},
		overlay = function(u, _secs, _input)
			local t = u
			local style = Flap.mix(Flap.mix(HOVER, DRAWN, smooth(0, 0.2, u)), SPREAD, smooth(0.25, 0.56, u))
			style.amp = (1 - smooth(0, 0.2, u)) * 1
			local theta = 46 * t
			local pose: Pose = {}
			wings(pose, style, theta)
			shake(pose, t, smooth(0.45, 1.0, u) ^ 1.5 * 1.4)
			return pose
		end,
	},
	active = {
		duration = 0.1,
		keys = {
			key(0, SHRIEK_HOLD),
			key(0.4, B({ y = 0.55, pitch = 0.75, head = 0.8, jaw = -1.05, legs = 0.35, ear = -0.2, out = 0.8 }), "out"),
			key(1, B({ y = 0.5, pitch = 0.5, head = 0.45, jaw = -1.0, legs = 0.3, ear = -0.15, out = 0.7 }), "inOut"),
		},
		overlay = function(u, secs, _input)
			local pose: Pose = {}
			wings(pose, SPREAD, 0)
			shake(pose, secs, 1.6)
			return pose
		end,
	},
	recover = {
		duration = 0.7,
		keys = {
			key(0, B({ y = 0.5, pitch = 0.5, head = 0.45, jaw = -1.0, legs = 0.3, ear = -0.15, out = 0.7 })),
			key(0.2, B({ y = 0.2, pitch = 0.1, head = -0.1, jaw = -0.1, legs = 0.1, ear = 0.05, out = 0.3 }), "out"),
			key(0.5, B({ y = 0.05, pitch = 0, head = 0.05, legs = -0.2, ear = 0.2 }), "inOut"),
			key(1, HOVER_END, "inOut"),
		},
		overlay = function(u, secs, _input)
			local D = 0.7
			local t = u * D
			local style = Flap.mix(SPREAD, HOVER, smooth(0.15, 0.6, u))
			style.amp = smooth(0.0, 0.25, u)
			local theta = Flap.phaseAt({ { 0, 40 }, { 0.3, 60 }, { D, 46 } }, t)
			local pose: Pose = {}
			wings(pose, style, theta)
			-- still ringing: a dizzy wobble that dies away
			local ring = (1 - smooth(0, 0.8, u))
			add(pose, {
				JointHead = A(0.1 * math.sin(secs * 33) * ring, 0.25 * math.sin(secs * 23) * ring, 0.15 * math.sin(secs * 29) * ring),
				JointRoot = A(0, 0, 0.1 * math.sin(secs * 41) * ring),
			})
			return pose
		end,
	},
}

-- ---- Hop (flap away) --------------------------------------------------------

moves.Hop = {
	active = {
		duration = 0.25,
		air = true,
		keys = {
			key(0, REST),
			key(0.2, B({ y = -0.12, pitch = 0.45, head = -0.2, legs = 0.4, ear = 0.5 }), "out"),
			key(0.55, B({ y = 0.4, pitch = 0.5, head = 0.1, legs = 0.2, ear = 0.4 }), "inOut"),
			key(1, B({ y = 0.15, pitch = 0.15, legs = -0.1, ear = 0.2 }), "inOut"),
		},
		overlay = function(u, _secs, _input)
			local pose: Pose = {}
			wings(pose, POWER, 50.3 * u * 0.25)
			return pose
		end,
	},
}

-- ---- Stagger and Death ------------------------------------------------------

moves.Stagger = {
	active = {
		duration = 0.25,
		keys = {
			key(0, REST),
			key(0.25, B({ y = -0.2, pitch = 0.7, head = 0.5, jaw = -0.6, legs = 0.9, ear = 0.8 }), "out"),
			key(0.6, B({ y = -0.3, pitch = 0.5, head = 0.3, jaw = -0.4, legs = 0.6, ear = 0.6 }), "inOut"),
			key(1, B({ y = -0.05, pitch = 0.12, legs = 0.1, ear = 0.3 }), "inOut"),
		},
		overlay = function(u, secs, input)
			local side = input.side or 1
			local e = smooth(0, 0.25, u) * (1 - smooth(0.6, 1, u) * 0.8)
			local near = Flap.mix(HOVER, COCK, 1)
			near.amp = 0
			near.top = 1.0 + 0.6 * e
			local far = Flap.mix(HOVER, COCK, 1)
			far.amp = 0
			far.top = 1.0 + 0.1 * e
			local pose: Pose = {}
			if side >= 0 then
				wings(pose, far, 0, near, 0)
			else
				wings(pose, near, 0, far, 0)
			end
			add(pose, {
				JointRoot = A(0, -side * 0.3 * e, -side * 0.6 * e),
				JointHead = A(0, -side * 0.5 * e, 0.3 * math.sin(secs * 60) * e),
			})
			return pose
		end,
	},
}

moves.Death = {
	active = {
		duration = 1.2,
		keys = {
			key(0, REST),
			key(0.1, B({ y = -0.2, pitch = 0.8, head = 0.6, jaw = -0.8, legs = 1.0, ear = 0.9 }), "out"),
			key(0.35, B({ y = -1.0, pitch = 0.3, roll = 0.9, head = 0.3, jaw = -0.6, legs = 0.8, ear = 0.7 }), "inOut"),
			key(0.65, B({ y = -2.6, pitch = -0.7, roll = 1.6, head = -0.4, jaw = -0.3, legs = 0.5, ear = 0.7 }), "in"),
			key(0.8, B({ y = -3.55, pitch = 0.05, roll = 0.1, head = -0.5, jaw = -0.2, legs = 1.2, ear = 0.8 }), "in"),
			key(0.88, B({ y = -3.3, pitch = 0.1, roll = 0.1, head = -0.45, jaw = -0.25, legs = 1.2, ear = 0.8 }), "out"),
			key(1, B({ y = -3.55, pitch = 0.05, roll = 0.1, head = -0.55, jaw = -0.15, legs = 1.2, ear = 0.85 }), "in"),
		},
		overlay = function(u, secs, _input)
			local flail = (1 - smooth(0.55, 0.78, u)) * smooth(0, 0.08, u)
			local limp = smooth(0.6, 0.85, u)
			local style = Flap.mix(Flap.mix(HOVER, COCK, smooth(0, 0.1, u)), DEAD_WINGS, limp)
			style.amp = 0.9 * flail
			style.floor = if limp > 0.05 then -10 else FLOOR
			style.ceil = if limp > 0.05 then 9 else CEIL
			local theta = Flap.phaseAt({ { 0, 60 }, { 1.2, 20 } }, secs)
			local pose: Pose = {}
			wings(pose, style, theta)
			return pose
		end,
	},
}

BloodBat.moves = moves
BloodBat.durations = Quadruped.durations(moves)

------------------------------------------------------------------------------------
-- API

function BloodBat.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = moves[move]
	local p = m and m[phase]
	assert(p, ("BloodBat.sample: no %s.%s"):format(move, phase))
	local pose = Quadruped.samplePhase(p, u, input or {})
	-- a kill from its left rolls the corpse the other way (the keys roll toward +Z)
	if move == "Death" and input and (input.side or 1) < 0 then
		local r = pose.JointRoot
		if r then
			local x, y, z = r:ToEulerAnglesXYZ()
			pose.JointRoot = CFrame.new(r.Position) * A(x, -y, -z)
		end
	end
	return pose
end

function BloodBat.scaled(pose: Pose, _scale: number): Pose
	return pose
end

function BloodBat.plant(pose: Pose): Pose
	return pose
end

return BloodBat
