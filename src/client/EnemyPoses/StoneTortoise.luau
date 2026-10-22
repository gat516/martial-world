--!strict
-- Procedural pose tables for the Stone Tortoise (StoneTortoise_R, Enemies.StoneTortoiseB at
-- Scale 1.76; see art/enemies/quadrupeds/RIGS.md). Same FORMAT and API as Wolf.luau (read
-- its header). UNIT SPACE: the poses are authored on the 1x rig; EnemyAnimator applies the
-- 1.76 scale once with StoneTortoise.scaled (every joint translation times the scale) and
-- gaitRate takes the real scale.
--
-- RIG: faces -Z, its left is -X. 14 joints. JointRoot is the shell (translate and rotate it;
-- pivot (0, 2.4, 0)). JointNeck RETRACTS BY TRANSLATION along Z: +2.3 is the full tuck, +0.6
-- half in, -0.4 stretched out (past +2.3 the face sinks behind the rim; keep head yaw 0
-- while tucked). Legs are single columns (JointLeg*, hip at y 2.1) with an ankle (JointFoot*,
-- y 0.75). +X pitch swings a leg forward, tips the head up, drops the tail; the jaw opens
-- on -X. +Y turns to its left; +Z rolls its top toward its left (the right side goes up).
--
-- PLANTING is this module's own solver (the legs have no middle joint, so the two-joint
-- Quadruped.plant cannot be used; Quadruped.samplePhase / easing / mirroring are shared).
-- A planted foot is held at its rest spot plus the key's reach (x, y = lift, z; studs, model
-- space): the leg swings from the hip toward it, stays world-upright where it can, slides
-- along its own axis (JointLeg translation: the leg draws up into the shell as the shell
-- drops, and out as it rises) for the rest, and the ankle levels the foot. So author the
-- shell, neck, head and tail; the planted legs follow. A leg that is not planted is posed
-- by hand, and is planted where it is if it would dip below the ground.
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt, where the telegraph, tell flare
-- and sound start). Move-name map for EnemyAnimator FAMILIES (def.attack -> module move):
--   neckSnap -> NeckSnap, quakeStomp -> QuakeStomp, shellGuard -> ShellGuard,
--   shellSnap -> ShellSnap (Stagger and Death as for every family)
--   NeckSnap    windup 0.7: 0-0.4 s the neck pulls half in (z 0 -> +0.6), head cocked, jaw
--                 open; 0.4-0.7 a held beat, the head quivering.
--               active 0.12: the neck shoots out to -0.4 and the jaw snaps shut.
--               recover 0.9: a slow pull back with a head shake.
--   QuakeStomp  windup 1.2: a small preload sink (0.15 s), the slow rise to the user's
--                 StoneTortoise_R_Windup pose (root +0.55, pitched +0.32; hind legs
--                 planted, fore legs hanging) by 0.9 s, a held beat to 1.12 s with a
--                 tremble, then the plunge: the last 0.08 s falls to the impact, so
--                 the active phase (and the strike cue) STARTS at the impact.
--               active 0.15: the impact, the shell compressing and rebounding.
--               recover 1.4: a heavy settle, the shell rocking (damped), the neck out.
--   ShellGuard  windup 0.5: the neck and legs tuck in, the shell drops to the ground.
--               active (the hold; give input.duration = the hold's seconds, 2.0): hunkered,
--                 tiny breathing; input.hitAt = seconds since the last hit that landed
--                 during the hold (nil or negative: none) shakes and resettles the shell.
--               recover 0.5: it pokes back out and stands (when no ShellSnap follows).
--   ShellSnap   windup 0.35 (from the tuck: the legs push the shell up, the neck coils to
--                 +1.0), active 0.1 (the neck shoots to -0.45, jaw snaps),
--               recover 1.0 (a heavy sway back to standing).
--   Stagger     active 0.35 (the head tucks, the shell is knocked back; input.side tips it).
--   Death       active 1.2, then hold u = 1 (the legs fold, the shell settles to the ground,
--                 the head droops out).
-- LOOPS: idle (breath, a slow head sway, now and then the neck draws in); walk (a diagonal
--   lumber up to ~3.5 studs/s, a visible weight shift: the shell leans and rocks over the
--   stance legs, dips with each footfall, the head bobs twice a cycle, the tail swishes);
--   run (a quicker lumber, ~6 studs/s, neck stretched); NO circling, but loops.turn /
--   loops.circle is the TURN IN PLACE: play it (loop "circle", speed ~1) while the body
--   yaws slowly: the feet shuffle round in short diagonal steps (stance feet slide against
--   the turn, swing feet step with it), the shell rocking; dir = +1 turns left.
--
-- API (as Wolf.luau)
--   StoneTortoise.sample(move, phase, u, input?) -> Pose
--   StoneTortoise.loops.idle(clock, speed, input?) / walk(phase, speed) / run(phase, speed) /
--     turn(phase, speed, input?) / circle (= turn)
--   StoneTortoise.gaitRate(loop, speed, scale?), .scaled(pose, scale), .plant(pose, legs?, reach?)
--   StoneTortoise.moves, .durations, .JOINTS
-- input: duration, side, seed, dir (as Quadruped.Input) and hitAt (above).

local Quadruped = require(script.Parent.Quadruped)

local StoneTortoise = {}

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input & { hitAt: number? }
type Phase = Quadruped.Phase

local TAU = Quadruped.TAU
local I = CFrame.identity
local A = Quadruped.A
local EASE, bump, smooth, with, hash = Quadruped.EASE, Quadruped.bump, Quadruped.smooth, Quadruped.with, Quadruped.hash
local ALL = Quadruped.ALL
local V = Vector3.new

StoneTortoise.JOINTS = {
	"JointRoot", "JointNeck", "JointHead", "JointJaw", "JointTail", "JointTailTip",
	"JointLegFL", "JointFootFL", "JointLegFR", "JointFootFR",
	"JointLegBL", "JointFootBL", "JointLegBR", "JointFootBR",
}

------------------------------------------------------------------------------------
-- Skeleton (ground at Y 0; from art/enemies/quadrupeds/rig_stone_tortoise.luau)

local ROOT = V(0, 2.4, 0)
local HIP = { FL = V(-2.6, 2.1, -2.7), FR = V(2.6, 2.1, -2.7), BL = V(-2.6, 2.1, 2.8), BR = V(2.6, 2.1, 2.8) }
local ANKLE = { FL = V(-2.75, 0.75, -2.7), FR = V(2.75, 0.75, -2.7), BL = V(-2.75, 0.75, 2.8), BR = V(2.75, 0.75, 2.8) }
local LEGJ = { FL = "JointLegFL", FR = "JointLegFR", BL = "JointLegBL", BR = "JointLegBR" }
local FOOTJ = { FL = "JointFootFL", FR = "JointFootFR", BL = "JointFootBL", BR = "JointFootBR" }
local SIDE = { FL = -1, FR = 1, BL = -1, BR = 1 }

-- the foot's lowest corners (the sole and the claw tips), from the ankle pivot
local function soleOf(tag: string): { Vector3 }
	local s = SIDE[tag]
	local out = {}
	for _, dx in { -0.875, 0.975 } do
		for _, dz in { -1.025, 0.825 } do
			table.insert(out, V(s * 0.05 + dx * s, -0.75, dz))
		end
	end
	for _, dx in { -0.55, 0, 0.55 } do
		table.insert(out, V(s * 0.05 + dx, -0.75, -1.4))
	end
	return out
end
local SOLE = { FL = soleOf("FL"), FR = soleOf("FR"), BL = soleOf("BL"), BR = soleOf("BR") }

local function hipBase(pose: Pose, tag: string): CFrame
	return CFrame.new(ROOT) * (pose.JointRoot or I) * CFrame.new(HIP[tag] - ROOT)
end

local function ankleFrame(pose: Pose, tag: string): CFrame
	return hipBase(pose, tag) * (pose[LEGJ[tag]] or I) * CFrame.new(ANKLE[tag] - HIP[tag])
end

local function soleY(pose: Pose, tag: string): number
	local f = ankleFrame(pose, tag) * (pose[FOOTJ[tag]] or I)
	local lo = math.huge
	for _, v in SOLE[tag] do
		lo = math.min(lo, (f * v).Y)
	end
	return lo
end

-- Solves one leg so its ankle sits at target (model space) with the foot level, and
-- blends it into the pose by w. flex tips the toes up (+) after levelling.
local function solveLeg(pose: Pose, tag: string, target: Vector3, w: number, flex: number?)
	local B = hipBase(pose, tag)
	local Hw = B.Position
	local v0 = ANKLE[tag] - HIP[tag]
	local L = V(0, v0.Y, 0).Magnitude
	local Rb = B.Rotation
	local a, r = 0, 0
	local e = Vector3.zero
	for _ = 1, 5 do
		local Rw = CFrame.Angles(a, 0, 0) * CFrame.Angles(0, 0, r)
		e = (target - Hw) - Rw * v0
		a = math.clamp(a - e.Z / (L * math.max(math.cos(a), 0.3)), -0.9, 0.9)
		r = math.clamp(r + e.X / L, -0.7, 0.7)
	end
	local Rw = CFrame.Angles(a, 0, 0) * CFrame.Angles(0, 0, r)
	e = (target - Hw) - Rw * v0
	local t = Rb:Inverse() * e
	local upper = CFrame.new(t) * (Rb:Inverse() * Rw)
	local foot = Rw:Inverse() * CFrame.Angles(flex or 0, 0, 0)
	pose[LEGJ[tag]] = (pose[LEGJ[tag]] or I):Lerp(upper, w)
	pose[FOOTJ[tag]] = (pose[FOOTJ[tag]] or I):Lerp(foot, w)
end

-- plant: weights per leg (Quadruped.plantOf), reach: offsets from the rest ankle spot.
local function plantLegs(pose: Pose, plant: Quadruped.Plant, reach: { [string]: Vector3 }?, flex: { [string]: number }?)
	for tag, w in plant do
		if w > 0.001 then
			local target = ANKLE[tag] + ((reach and reach[tag]) or Vector3.zero)
			solveLeg(pose, tag, target, w, flex and flex[tag])
		end
	end
	for tag in LEGJ do
		if (plant[tag] or 0) < 0.999 then
			local lo = soleY(pose, tag)
			if lo < -0.005 then
				local at = ankleFrame(pose, tag).Position
				solveLeg(pose, tag, at - V(0, lo, 0), 1)
			end
		end
	end
end

local moves: { [string]: { [string]: Phase } } = {}

StoneTortoise.moves = moves
function StoneTortoise.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = moves[move]
	local p = m and m[phase]
	assert(p, ("StoneTortoise.sample: no %s.%s"):format(move, phase))
	local pose, plant, reach = Quadruped.samplePhase(p, u, input or {})
	plantLegs(pose, plant, reach)
	return pose
end

function StoneTortoise.plant(pose: Pose, legs: { string }?, reach: { [string]: Vector3 }?): Pose
	plantLegs(pose, Quadruped.plantOf(legs or ALL), reach)
	return pose
end

------------------------------------------------------------------------------------
-- Poses

-- the shell: x, y, z in studs, then pitch (+ front up), yaw, roll
local function RT(x: number, y: number, z: number, pitch: number?, yaw: number?, roll: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(pitch or 0, yaw or 0, roll or 0)
end
local function NK(z: number, pitch: number?, yaw: number?, roll: number?): CFrame
	return CFrame.new(0, 0, z) * CFrame.Angles(pitch or 0, yaw or 0, roll or 0)
end
local function reachAll(x: number, y: number, z: number): { [string]: Vector3 }
	return { FL = V(-x, y, z), FR = V(x, y, z), BL = V(-x, y, z), BR = V(x, y, z) }
end
local FRONT, HIND = Quadruped.FRONT, Quadruped.HIND

local STAND: Pose = { JointTail = A(0.12) }

-- NeckSnap -----------------------------------------------------------------------
local SNAP_LOAD: Pose = {
	JointRoot = RT(0, -0.03, 0.12, 0.05),
	JointNeck = NK(0.6, 0.14, 0.1, 0.22),
	JointHead = A(0.1, 0.12, 0.2),
	JointJaw = A(-0.55),
	JointTail = A(-0.12), JointTailTip = A(-0.1),
}
local SNAP_COIL: Pose = with(SNAP_LOAD, {
	JointRoot = RT(0, -0.05, 0.2, 0.07),
	JointNeck = NK(0.66, 0.18, 0.1, 0.24),
	JointJaw = A(-0.62),
	JointTail = A(-0.2),
})
local SNAP_REACH: Pose = {
	JointRoot = RT(0, 0, -0.3, -0.06),
	JointNeck = NK(-0.4, 0),
	JointHead = A(-0.03),
	JointJaw = A(-0.5),
	JointTail = A(0.1),
}
local SNAP_BITE: Pose = with(SNAP_REACH, { JointJaw = A(-0.03), JointHead = A(-0.1) })

moves.NeckSnap = {
	windup = {
		duration = 0.7,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.57, pose = SNAP_LOAD, ease = "inOut", plant = ALL },
			{ t = 1, pose = SNAP_COIL, ease = "linear", plant = ALL },
		},
		overlay = function(u, secs)
			local k = smooth(0.62, 0.8, u)
			return {
				JointHead = A(0, 0.03 * k * math.sin(TAU * 9 * secs), 0.02 * k * math.sin(TAU * 11 * secs)),
				JointRoot = A(0, 0, 0.006 * k * math.sin(TAU * 13 * secs)),
			}
		end,
	},
	active = {
		duration = 0.12,
		keys = {
			{ t = 0, pose = SNAP_COIL, plant = ALL },
			{ t = 0.5, pose = SNAP_REACH, ease = "out", plant = ALL },
			{ t = 1, pose = SNAP_BITE, ease = "in", plant = ALL },
		},
	},
	recover = {
		duration = 0.9,
		keys = {
			{ t = 0, pose = SNAP_BITE, plant = ALL },
			{ t = 0.12, pose = SNAP_BITE, plant = ALL },
			{ t = 0.85, pose = with(STAND, { JointNeck = NK(0.05, 0.03) }), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- the head shake while the neck draws back
		overlay = function(u, secs)
			local f = (1 - u) ^ 1.5 * smooth(0.1, 0.25, u)
			local s = math.sin(TAU * 2.2 * secs)
			return { JointNeck = A(0, 0.18 * s * f), JointHead = A(0, 0.22 * s * f, 0.1 * s * f), JointJaw = A(-0.1 * math.max(0, s) * f) }
		end,
	},
}

-- QuakeStomp -----------------------------------------------------------------------
local PRELOAD: Pose = {
	JointRoot = RT(0, -0.14, 0.05, -0.03),
	JointNeck = NK(0.15, -0.05),
	JointHead = A(0.05),
	JointTail = A(-0.1),
}
-- the user's StoneTortoise_R_Windup: shell +0.55 and pitched +0.32, fore legs hanging, hind
-- legs planted (solved), tail up, head level and jaw open
local RISEN: Pose = {
	JointRoot = RT(0, 0.55, 0, 0.32),
	JointNeck = NK(0.5, 0.15),
	JointHead = A(-0.35),
	JointJaw = A(-0.36),
	JointTail = A(-0.32), JointTailTip = A(-0.1),
	JointLegFL = A(0.25), JointFootFL = A(-0.6),
	JointLegFR = A(0.25), JointFootFR = A(-0.6),
}
local MIDRISE: Pose = {
	JointRoot = RT(0, 0.2, 0, 0.12),
	JointNeck = NK(0.3, 0.06),
	JointHead = A(-0.14),
	JointJaw = A(-0.2),
	JointTail = A(-0.18), JointTailTip = A(-0.05),
	JointLegFL = A(0.1), JointFootFL = A(-0.2),
	JointLegFR = A(0.1), JointFootFR = A(-0.2),
}
local PEAK: Pose = with(RISEN, {
	JointRoot = RT(0, 0.6, 0, 0.35),
	JointNeck = NK(0.55, 0.17),
	JointJaw = A(-0.36),
	JointTail = A(-0.36),
	JointLegFL = A(0.3), JointFootFL = A(-0.65),
	JointLegFR = A(0.3), JointFootFR = A(-0.65),
})
-- the impact: the front lands, the shell dips over the legs, the head thrown down
local IMPACT: Pose = {
	JointRoot = RT(0, -0.22, 0, -0.07),
	JointNeck = NK(0.35, -0.12),
	JointHead = A(-0.14),
	JointJaw = A(-0.05),
	JointTail = A(0.25), JointTailTip = A(0.12),
}
local REBOUND: Pose = with(IMPACT, {
	JointRoot = RT(0, -0.06, 0.05, 0.03),
	JointNeck = NK(0.25, 0),
	JointHead = A(0.04),
})
-- hind feet dig back as the shell rises
local DIG_L = { BL = V(0, 0, 0.18), BR = V(0, 0, 0.05) }
local DIG_R = { BL = V(0, 0, 0.06), BR = V(0, 0, 0.2) }

moves.QuakeStomp = {
	windup = {
		duration = 1.2,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.12, pose = PRELOAD, ease = "out", plant = ALL },
			{ t = 0.3, pose = MIDRISE, ease = "inOut", plant = HIND, reach = DIG_L },
			{ t = 0.72, pose = RISEN, ease = "inOut", plant = HIND, reach = DIG_R },
			{ t = 0.92, pose = PEAK, ease = "out", plant = HIND, reach = DIG_R },
			{ t = 1, pose = IMPACT, ease = "in", plant = ALL },
		},
		overlay = function(u, secs)
			-- the strain: a tremble through the held beat, none in the plunge
			local k = smooth(0.7, 0.8, u) * (1 - smooth(0.93, 0.97, u))
			return {
				JointRoot = A(0, 0.006 * k * math.sin(TAU * 11 * secs), 0.012 * k * math.sin(TAU * 15 * secs)),
				JointHead = A(0.02 * k * math.sin(TAU * 9 * secs)),
				JointLegFL = A(0.05 * k * math.sin(TAU * 7 * secs)),
				JointLegFR = A(0.05 * k * math.sin(TAU * 7 * secs + 1.5)),
			}
		end,
	},
	active = {
		duration = 0.15,
		keys = {
			{ t = 0, pose = IMPACT, plant = ALL },
			{ t = 0.4, pose = with(IMPACT, { JointRoot = RT(0, -0.26, 0, -0.08), JointHead = A(-0.1) }), ease = "out", plant = ALL },
			{ t = 1, pose = REBOUND, ease = "inOut", plant = ALL },
		},
	},
	recover = {
		duration = 1.4,
		keys = {
			{ t = 0, pose = REBOUND, plant = ALL },
			{ t = 0.3, pose = with(STAND, { JointNeck = NK(0.2, 0.02), JointRoot = RT(0, -0.05, 0, 0.0) }), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- the shell rocking: damped pitch and roll, the tail following a beat behind
		overlay = function(u, secs)
			local d = math.exp(-secs * 2.6)
			local pitch = math.sin(TAU * 1.5 * secs) * 0.055 * d
			local roll = math.sin(TAU * 1.1 * secs + 0.8) * 0.04 * d
			return {
				JointRoot = CFrame.new(0, 0.02 * math.sin(TAU * 3 * secs) * d, 0) * A(pitch, 0, roll),
				JointNeck = A(-pitch * 0.5),
				JointTail = A(math.sin(TAU * 1.5 * secs - 0.8) * 0.12 * d),
			}
		end,
	},
}

-- ShellGuard / ShellSnap -----------------------------------------------------------
-- tucked: the neck all the way in, the shell on the ground, the feet drawn up into the rim
local TUCK: Pose = {
	JointRoot = RT(0, -0.7, 0),
	JointNeck = NK(2.3),
	JointHead = A(0.05),
	JointJaw = A(0),
	JointTail = A(-0.3), JointTailTip = A(-0.1),
}
local TUCK_REACH = reachAll(-0.2, 0.9, 0)
local TUCK_BRACE: Pose = with(TUCK, { JointRoot = RT(0, -0.78, 0, 0.0) })

moves.ShellGuard = {
	windup = {
		duration = 0.5,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			-- a half beat of rearing up before it slams down
			{ t = 0.25, pose = with(STAND, { JointRoot = RT(0, 0.12, 0, 0.03), JointNeck = NK(-0.15, 0.1), JointHead = A(0.1) }), ease = "out", plant = ALL },
			{ t = 0.7, pose = TUCK_BRACE, ease = "in", plant = ALL, reach = TUCK_REACH },
			{ t = 1, pose = TUCK, ease = "out", plant = ALL, reach = TUCK_REACH },
		},
	},
	active = {
		duration = 2.0,
		keys = {
			{ t = 0, pose = TUCK, plant = ALL, reach = TUCK_REACH },
			{ t = 1, pose = TUCK, plant = ALL, reach = TUCK_REACH },
		},
		overlay = function(_, secs, input)
			local b = math.sin(TAU * secs / 1.7)
			local out: Pose = {
				JointRoot = CFrame.new(0, 0.018 * b, 0) * A(0.004 * b),
				JointNeck = CFrame.new(0, 0, 0.04 * b),
			}
			local age = (input :: Input).hitAt
			if age and age >= 0 and age < 0.7 then
				-- a hit: the shell jolts down and shudders, then resettles
				local d = math.exp(-age * 7)
				local sh = math.sin(TAU * 17 * age) * d
				out.JointRoot = CFrame.new(0.05 * sh, -0.09 * d, 0.03 * d) * A(0.03 * sh, 0.025 * sh, 0.04 * math.sin(TAU * 11 * age) * d)
				out.JointNeck = CFrame.new(0, 0, 0.12 * d)
				out.JointTail = A(0.1 * sh)
			end
			return out
		end,
	},
	recover = {
		duration = 0.5,
		keys = {
			{ t = 0, pose = TUCK, plant = ALL, reach = TUCK_REACH },
			{ t = 0.4, pose = with(TUCK, { JointRoot = RT(0, -0.35, 0), JointNeck = NK(1.2, 0.04) }), ease = "inOut", plant = ALL, reach = reachAll(-0.1, 0.35, 0) },
			{ t = 1, pose = STAND, ease = "out", plant = ALL },
		},
	},
}

moves.ShellSnap = {
	windup = {
		duration = 0.35,
		keys = {
			{ t = 0, pose = TUCK, plant = ALL, reach = TUCK_REACH },
			-- the legs push the shell up, the neck coils out to half way
			{ t = 0.55, pose = {
				JointRoot = RT(0, -0.12, 0.1, 0.05),
				JointNeck = NK(1.0, 0.12, 0.08, 0.18),
				JointHead = A(0.1, 0.1, 0.18),
				JointJaw = A(-0.15),
				JointTail = A(-0.1),
			}, ease = "out", plant = ALL, reach = reachAll(0, 0.1, 0) },
			{ t = 1, pose = {
				JointRoot = RT(0, -0.1, 0.16, 0.06),
				JointNeck = NK(0.95, 0.14, 0.08, 0.2),
				JointHead = A(0.1, 0.1, 0.2),
				JointJaw = A(-0.2),
				JointTail = A(-0.05),
			}, ease = "inOut", plant = ALL, reach = reachAll(0, 0.05, 0) },
		},
	},
	active = {
		duration = 0.1,
		keys = {
			{ t = 0, pose = with(SNAP_COIL, { JointRoot = RT(0, -0.1, 0.16, 0.06), JointNeck = NK(0.95, 0.14, 0.08, 0.2), JointJaw = A(-0.2), JointHead = A(0.1, 0.1, 0.2), JointTail = A(-0.05) }), plant = ALL, reach = reachAll(0, 0.05, 0) },
			{ t = 0.6, pose = with(SNAP_REACH, { JointNeck = NK(-0.45, 0), JointRoot = RT(0, 0.02, -0.35, -0.07) }), ease = "out", plant = ALL },
			{ t = 1, pose = with(SNAP_BITE, { JointNeck = NK(-0.45, -0.02), JointRoot = RT(0, 0.02, -0.35, -0.07) }), ease = "in", plant = ALL },
		},
	},
	recover = {
		duration = 1.0,
		keys = {
			{ t = 0, pose = with(SNAP_BITE, { JointNeck = NK(-0.45, -0.02), JointRoot = RT(0, 0.02, -0.35, -0.07) }), plant = ALL },
			{ t = 0.15, pose = with(SNAP_BITE, { JointNeck = NK(-0.45, -0.02), JointRoot = RT(0, 0.02, -0.35, -0.07) }), plant = ALL },
			{ t = 0.75, pose = with(STAND, { JointNeck = NK(0.08, 0.02) }), ease = "inOut", plant = ALL },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		-- the sway back to standing: the shell rolls side to side and settles
		overlay = function(u, secs)
			local d = (1 - smooth(0.2, 1, u))
			local s = math.sin(TAU * 1.3 * secs)
			return {
				JointRoot = CFrame.new(0.14 * s * d, 0, 0) * A(0, 0.05 * s * d, -0.05 * s * d),
				JointHead = A(0, 0.1 * s * d),
				JointTail = A(0, 0.25 * s * d),
			}
		end,
	},
}

-- Stagger / Death -----------------------------------------------------------------
local HIT: Pose = {
	JointRoot = RT(0, -0.08, 0.28, 0.07),
	JointNeck = NK(1.3, 0.1),
	JointHead = A(0.12),
	JointJaw = A(-0.3),
	JointTail = A(-0.2), JointTailTip = A(-0.1),
}
local HIT_REACH = reachAll(0.1, 0, 0.1)

moves.Stagger = {
	active = {
		duration = 0.35,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.22, pose = HIT, ease = "out", plant = ALL, reach = HIT_REACH },
			{ t = 0.5, pose = HIT, plant = ALL, reach = HIT_REACH },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, _, input)
			local side = math.clamp(input.side or 0, -1, 1)
			local e = if u < 0.22 then EASE.out(u / 0.22) else 1 - EASE.inOut((u - 0.22) / 0.78)
			return { JointRoot = A(0, 0.05 * side * e, 0.05 * side * e), JointHead = A(0, 0.1 * side * e) }
		end,
	},
}

local DEAD: Pose = {
	JointRoot = RT(0, -0.77, 0.05, 0.0),
	JointNeck = NK(-0.2, -0.03),
	JointHead = A(-0.04),
	JointJaw = A(-0.18),
	JointTail = A(-0.1), JointTailTip = A(-0.05),
}
local DEAD_REACH = reachAll(-0.25, 0.9, 0)
moves.Death = {
	active = {
		duration = 1.2,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.15, pose = HIT, ease = "out", plant = ALL, reach = HIT_REACH },
			-- the legs give out: the shell comes down hard, overshoots and settles
			{ t = 0.5, pose = with(DEAD, { JointRoot = RT(0, -0.78, 0.08, 0.02), JointNeck = NK(0.5, -0.05), JointHead = A(0.05) }), ease = "in", plant = ALL, reach = DEAD_REACH },
			{ t = 0.62, pose = with(DEAD, { JointRoot = RT(0, -0.74, 0.05, -0.01) }), ease = "out", plant = ALL, reach = DEAD_REACH },
			{ t = 0.85, pose = DEAD, ease = "inOut", plant = ALL, reach = DEAD_REACH },
			{ t = 1, pose = DEAD, ease = "inOut", plant = ALL, reach = DEAD_REACH },
		},
	},
}

StoneTortoise.durations = Quadruped.durations(moves)

------------------------------------------------------------------------------------
-- Loops

local loops = {}

local function pose_apply(pose: Pose, plant: Quadruped.Plant, reach: { [string]: Vector3 }, flex: { [string]: number }?): Pose
	plantLegs(pose, plant, reach, flex)
	return pose
end
local PLANT_ALL = Quadruped.plantOf(ALL)

-- breath, a slow head sway, the neck stretching out and drawing in now and then
function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 3.4)
	local slot = math.floor(clock / 9)
	local st = slot * 9 + 1 + hash(slot, seed) * 4
	local draw = 0
	if hash(slot + 0.3, seed) < 0.5 then
		draw = smooth(st, st + 0.8, clock) * (1 - smooth(st + 1.6, st + 3.2, clock))
	end
	local look = math.sin(clock * 0.27 + seed) * 0.2 + math.sin(clock * 0.11 + seed * 2) * 0.12
	local yawk = look * (1 - draw)
	local pose: Pose = {
		JointRoot = RT(0, 0.03 * breath, 0, 0.008 * breath, 0.012 * math.sin(clock * 0.27 + seed), 0.006 * math.sin(clock * 0.5)),
		JointNeck = NK(0.12 + 0.2 * math.sin(clock * 0.43 + seed) + 0.45 * draw + 0.05 * breath, 0.03 * breath, yawk * 0.5),
		JointHead = A(0.02 + 0.04 * math.sin(clock * 0.6), yawk * 0.5, 0.03 * math.sin(clock * 0.2)),
		JointJaw = A(-0.04 - 0.04 * math.max(0, math.sin(clock * 0.9 + seed * 3)) ^ 6),
		JointTail = A(0.12 + 0.03 * breath, 0.2 * math.sin(clock * 0.55 + 1)),
		JointTailTip = A(0.06, 0.25 * math.sin(clock * 0.55 + 0.4)),
	}
	return pose_apply(pose, PLANT_ALL, {})
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- one diagonal-pair gait. S: half stride (studs), beta: stance fraction of the cycle (>0.5:
-- never fewer than two feet down), lift: swing height. turn: feet also slide round the body.
local function gait(phase: number, S: number, beta: number, lift: number, outward: number, turn: number): (Quadruped.Plant, { [string]: Vector3 }, { [string]: number }, number, number)
	local reach, flex = {}, {}
	local cA = (phase / TAU) % 1
	for tag, off in { FL = 0, BR = 0, FR = 0.5, BL = 0.5 } do
		local c = (cA + off) % 1
		local z, y, fx, out = 0, 0, 0, 0
		local f -- -1 start of stance .. +1 end
		if c < beta then
			f = -1 + 2 * (c / beta)
			z = S * f
		else
			local s = (c - beta) / (1 - beta)
			f = 1 - 2 * smoothstep(s)
			z = S * f
			y = lift * math.sin(math.pi * s) ^ 0.8
			fx = 0.28 * math.sin(math.pi * s)
			out = outward * (if tag == "BL" or tag == "BR" then 1.5 else 1) * math.sin(math.pi * s) ^ 0.7
		end
		local x = SIDE[tag] * out -- the swing foot steps out clear of the belly
		if turn ~= 0 then
			-- round the body: the foot is rotated about the shell's centre by phi (stance: against the turn)
			local phi = -turn * 0.13 * f
			local rest = ANKLE[tag]
			x = rest.Z * phi
			z = z - rest.X * phi
		end
		-- a lifted foot never steps inward (it would go up into the belly): out only
		local outSigned = SIDE[tag] * x
		local k = math.clamp(y / 0.15, 0, 1)
		x = SIDE[tag] * (outSigned + (math.max(outSigned, 0) - outSigned) * k)
		reach[tag] = V(x, y, z)
		flex[tag] = fx
	end
	local center = (1 + beta) / 2
	local sw = math.cos(TAU * (cA - center))
	return PLANT_ALL, reach, flex, sw, cA
end

local function lumber(phase: number, speed: number, S: number, beta: number, lift: number, outward: number, sway: number, input: Input?, stretch: number): Pose
	local plant, reach, flex, sw = gait(phase, S, beta, lift, outward, 0)
	local pose: Pose = {}
	local dip = 0.5 + 0.5 * math.cos(2 * phase)
	pose.JointRoot = RT(
		0.22 * sway * sw,
		-0.03 - 0.07 * sway * dip,
		0.04 * math.sin(2 * phase),
		0.02 * math.sin(2 * phase + 0.5) * sway,
		0.04 * sway * sw,
		-0.06 * sway * sw
	)
	local bob = math.sin(2 * phase + 0.6)
	pose.JointNeck = NK(0.1 - stretch + 0.26 * sway * bob, 0.05 * sway * bob, 0.1 * sway * math.sin(phase + 0.4))
	pose.JointHead = A(-0.05 * sway * bob + 0.02, -0.08 * sway * math.sin(phase + 0.4), 0.05 * sway * math.sin(phase))
	pose.JointJaw = A(-0.04)
	pose.JointTail = A(0.12 + 0.05 * sway * bob, 0.28 * math.sin(phase - 0.9))
	pose.JointTailTip = A(0.05, 0.32 * math.sin(phase - 1.7))
	return pose_apply(pose, plant, reach, flex)
end

function loops.walk(phase: number, speed: number, input: Input?): Pose
	return lumber(phase, speed, 0.75, 0.7, 0.38, 0.55, 1, input, 0)
end

function loops.run(phase: number, speed: number, input: Input?): Pose
	return lumber(phase, speed, 0.95, 0.58, 0.45, 0.6, 1.25, input, 0.35)
end

-- the turn in place: the feet shuffle round (stance feet slide against the turn), the shell
-- rocking and the head leading the way
function loops.turn(phase: number, _speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local plant, reach, flex, sw = gait(phase, 0.5, 0.72, 0.24, 0.7, dir)
	local pose: Pose = {}
	pose.JointRoot = RT(0.14 * sw, -0.04, 0, 0, 0.035 * dir * sw, -0.045 * sw)
	local bob = math.sin(2 * phase + 0.6)
	pose.JointNeck = NK(0.05 + 0.15 * bob, 0.03 * bob, 0.14 * dir)
	pose.JointHead = A(0.0, 0.16 * dir, 0.04 * sw)
	pose.JointJaw = A(-0.04)
	pose.JointTail = A(0.12, -0.3 * dir + 0.15 * math.sin(phase))
	pose.JointTailTip = A(0.05, -0.2 * dir)
	return pose_apply(pose, plant, reach, flex)
end
loops.circle = loops.turn

StoneTortoise.loops = loops

-- radians per second of the loop phase so the planted feet do not skate. scale is the body's
-- (the pose is 1x): speed is the real studs/s. A foot slides back 2 S over its stance, which is
-- beta of the cycle.
function StoneTortoise.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	local us = math.max(speed, 0.2) / s
	if loop == "walk" then
		return TAU * 0.7 * us / (2 * 0.75)
	elseif loop == "run" then
		return TAU * 0.58 * us / (2 * 0.95)
	elseif loop == "turn" or loop == "circle" then
		return TAU * 0.62 -- fixed shuffle rate: one cycle every 1.6 s
	end
	return 1 -- idle: pass the clock in seconds as its phase
end

-- every joint translation (the shell's rise, the neck's slide, the legs' draw) times the scale
function StoneTortoise.scaled(pose: Pose, scale: number): Pose
	if scale ~= 1 then
		for name, cf in pose do
			pose[name] = cf - cf.Position + cf.Position * scale
		end
	end
	return pose
end

return StoneTortoise
