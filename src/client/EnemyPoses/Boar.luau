--!strict
-- Procedural pose tables for the Stone Boar (StoneBoar_R / Enemies.StoneBoarB, see
-- art/enemies/quadrupeds/RIGS.md). Same FORMAT and API as Wolf.luau (read its header);
-- the leg planting is the shared Quadruped.luau. Pure data and maths, no instances.
--
-- RIG: faces -Z, its left is -X. +X pitch swings a leg forward, lifts the head and
-- drops the tail; the jaw opens on -X, the ears pin back on -X. +Y turns to its left,
-- +Z rolls its top toward its left. The fore legs hang from JointChest, the hind legs
-- from JointRoot. The tusks ride the Head, so the neck and head aim them. JointRoot
-- translations are in studs at 1x.
-- The legs bend like a hoofed animal's: the fore middle joint (JointLowerLegF*) juts
-- forward as it folds (the shank goes back, - pitch), the hind one (JointLowerLegB*, the
-- hock) juts back (the shank comes forward, + pitch).
--
-- MOVES (designed seconds; u = 0 is the AIState's StateAt, where the telegraph, tell
-- flare and sound start)
--   Charge   windup 1.0: 0-0.15 drops (head and neck -0.3, ears pinned, haunches
--            loaded, root -0.3); the fore-left hoof paws the ground at 0.15-0.35 and
--            0.5-0.7, planting between; 0.85-1.0 still, leaning in.
--            active 0.55: a heavy bound, two strides, head low, tusks forward, tail up.
--            recover 0.7: 0-0.3 skids on braced fore legs, root pitched back; 0.3-0.7
--            tosses the head with a snort and stands.
--   Gore     windup 0.6: the head dips and cocks to its right, fore legs braced, root
--            -0.2, jaw a little open.
--            active 0.15: the hook, up and across to its left, the chest rising.
--            recover 0.65: a head shake, then settles. (EnemyAnimator holds active's
--            end for the first 0.15 s of the AI's recover, then plays this.)
--   Stagger  active 0.28 (input.side: the head is thrown away from the hit)
--   Death    active 0.6, then hold u = 1 until the fade (mirror; input.side +1 = the
--            killer on its right, so it rolls onto its left side)
-- LOOPS: idle (breathing, ear flicks, a snort or a nod now and then); walk (a heavy
--   trot) up to ~6 studs/s; run (a gallop) about 10-14; circle (a side-pace, ~5).
--
-- API (as Wolf.luau)
--   Boar.sample(move, phase, u, input?) -> Pose
--   Boar.loops.idle(clock, speed, input?) / walk(phase, speed) / run(phase, speed) /
--   circle(phase, speed, input?)  (input.dir, input.targetYaw)
--   Boar.gaitRate(loop, speed, scale?), Boar.scaled(pose, scale), Boar.plant(pose, legs?, reach?)
--   Boar.moves, Boar.durations, Boar.JOINTS

local Quadruped = require(script.Parent.Quadruped)

local Boar = {}

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Phase = Quadruped.Phase
type Leg = Quadruped.Leg

local TAU = Quadruped.TAU
local I = CFrame.identity
local A, R = Quadruped.A, Quadruped.R
local EASE, bump, smooth, with, paws, hash = Quadruped.EASE, Quadruped.bump, Quadruped.smooth, Quadruped.with, Quadruped.paws, Quadruped.hash
local ALL, HIND = Quadruped.ALL, Quadruped.HIND

Boar.JOINTS = {
	"JointRoot", "JointChest", "JointNeck", "JointHead", "JointJaw", "JointEarL", "JointEarR",
	"JointLegFL", "JointLowerLegFL", "JointHoofFL", "JointLegFR", "JointLowerLegFR", "JointHoofFR",
	"JointLegBL", "JointLowerLegBL", "JointHoofBL", "JointLegBR", "JointLowerLegBR", "JointHoofBR",
	"JointTail", "JointTailTip",
}

------------------------------------------------------------------------------------
-- Skeleton (ground at Y 0; from art/enemies/quadrupeds/rig_stone_boar.luau)

local V = Vector3.new
local P = {
	JointRoot = V(0, 3.3, 1.2),
	JointChest = V(0, 3.5, 1.0),
	JointLegFL = V(-1.15, 2.9, -1.35),
	JointLowerLegFL = V(-1.15, 1.55, -1.35),
	JointHoofFL = V(-1.15, 0.5, -1.35),
	JointLegFR = V(1.15, 2.9, -1.35),
	JointLowerLegFR = V(1.15, 1.55, -1.35),
	JointHoofFR = V(1.15, 0.5, -1.35),
	JointLegBL = V(-1.05, 3.0, 2.15),
	JointLowerLegBL = V(-1.05, 1.7, 2.25),
	JointHoofBL = V(-1.05, 0.5, 2.15),
	JointLegBR = V(1.05, 3.0, 2.15),
	JointLowerLegBR = V(1.05, 1.7, 2.25),
	JointHoofBR = V(1.05, 0.5, 2.15),
}

local LEGS: { [string]: Leg } = {
	FL = { upper = "JointLegFL", mid = "JointLowerLegFL", foot = "JointHoofFL", base = "JointChest", fold = -1, front = true, knee = 1 },
	FR = { upper = "JointLegFR", mid = "JointLowerLegFR", foot = "JointHoofFR", base = "JointChest", fold = -1, front = true, knee = 1 },
	BL = { upper = "JointLegBL", mid = "JointLowerLegBL", foot = "JointHoofBL", base = "JointRoot", fold = 1, front = false, knee = -1 },
	BR = { upper = "JointLegBR", mid = "JointLowerLegBR", foot = "JointHoofBR", base = "JointRoot", fold = 1, front = false, knee = -1 },
}

-- the hoof's sole (the block 0.9 x 0.5 x 1.0 and its toe wedge), from the hoof pivot
local HOOF_SOLE = {
	V(-0.45, -0.5, -0.5), V(0.45, -0.5, -0.5), V(-0.45, -0.5, 0.5), V(0.45, -0.5, 0.5),
	V(-0.41, -0.5, -0.795), V(0.41, -0.5, -0.795),
}

local rig = Quadruped.new({
	P = P,
	root = "JointRoot",
	spine = "JointChest",
	legs = LEGS,
	sole = { front = HOOF_SOLE, hind = HOOF_SOLE },
	curl = { front = -0.6, hind = -0.4 },
	lift = 0.35,
})
local plantLegs, setLeg, stepLegs = rig.plantLegs, rig.setLeg, rig.stepLegs

------------------------------------------------------------------------------------
-- Poses

-- the neck slid forward (studs) and pitched: the head is big and sits right over the
-- fore legs, so pitching it down without the slide swings the jowl into the elbows and
-- the brow into the chest (the neck overlaps the chest by 0.55 at rest: no gap opens)
local function NK(out: number, pitch: number, yaw: number?, roll: number?, up: number?): CFrame
	return CFrame.new(0, up or 0, -out) * A(pitch, yaw, roll)
end

local STAND: Pose = {}
local ALERT: Pose = { JointEarL = A(-0.1), JointEarR = A(-0.1) }

local BRACED = paws(-0.2, 0) -- fore hooves planted ahead (the gore)
local SKIDDED = paws(-0.4, -0.2)
local THROWN = paws(-0.15, 0.15)

-- Charge windup: head down, ears pinned, haunches loaded (the rear sinks, the root
-- shifts back)
local CHARGE_LOAD: Pose = {
	JointRoot = R(-0.3, 0.06, 0.15),
	JointNeck = NK(0.3, -0.1),
	JointHead = A(-0.2),
	JointJaw = A(-0.05),
	JointEarL = A(-0.55), JointEarR = A(-0.55),
	JointTail = A(-0.35), JointTailTip = A(-0.2),
}
-- the pawing hoof, lifted and curled back. Less forward than the RIGS hint (LegFL +1.0):
-- past ~0.65 the shank reaches the low jowl. The head comes up a touch with each scrape.
local PAW_UP = with(CHARGE_LOAD, {
	JointLegFL = A(0.6), JointLowerLegFL = A(-1.3), JointHoofFL = A(0.5),
	JointNeck = NK(0.45, 0.05), JointHead = A(-0.25),
})
local PAW_DOWN = with(CHARGE_LOAD, {
	JointLegFL = A(0.3), JointLowerLegFL = A(-0.5),
	JointNeck = NK(0.4, -0.05), JointHead = A(-0.22),
})
-- the tension peak: leaning in over the fore legs, tail stiff
local CHARGE_SET: Pose = with(CHARGE_LOAD, {
	JointRoot = R(-0.3, 0.05, -0.05),
	JointChest = A(-0.02),
	JointNeck = NK(0.35, -0.1),
	JointHead = A(-0.22),
	JointTail = A(-0.45), JointTailTip = A(-0.25),
})
local FL_FWD = { FL = V(0, 0, -0.35) }
local FL_BACK = { FL = V(0, 0, 0.2) }

-- the bound: stretched (fore legs reaching, hind driving, all feet clear) and gathered
-- (hind feet landing under the belly, fore legs tucked)
local BOUND_STRETCH: Pose = {
	JointRoot = R(-0.1, -0.03),
	JointChest = A(-0.04),
	JointNeck = NK(0.35, 0),
	JointHead = A(-0.12),
	JointJaw = A(-0.1),
	JointEarL = A(-0.55), JointEarR = A(-0.55),
	JointLegFL = A(0.55), JointLowerLegFL = A(-0.5), JointHoofFL = A(-0.1),
	JointLegFR = A(0.5), JointLowerLegFR = A(-0.5), JointHoofFR = A(-0.1),
	JointLegBL = A(-0.55), JointLowerLegBL = A(0.2), JointHoofBL = A(0.3),
	JointLegBR = A(-0.5), JointLowerLegBR = A(0.2), JointHoofBR = A(0.3),
	JointTail = A(-0.65), JointTailTip = A(-0.35),
}
local BOUND_GATHER: Pose = {
	JointRoot = R(0.05, 0.05),
	JointChest = A(0.06),
	JointNeck = NK(0.35, -0.14),
	JointHead = A(-0.1),
	JointJaw = A(-0.1),
	JointEarL = A(-0.55), JointEarR = A(-0.55),
	JointLegFL = A(-0.45), JointLowerLegFL = A(-0.9), JointHoofFL = A(-0.3),
	JointLegFR = A(-0.4), JointLowerLegFR = A(-0.85), JointHoofFR = A(-0.3),
	JointLegBL = A(0.55), JointLowerLegBL = A(0.2),
	JointLegBR = A(0.5), JointLowerLegBR = A(0.2),
	JointTail = A(-0.55), JointTailTip = A(-0.4),
}
local GATHERED = paws(0, -0.7)

-- the skid: fore legs braced far forward, the root pitched back (front up)
local SKID: Pose = {
	JointRoot = R(0, 0.06, 0.15),
	JointChest = A(0.03),
	JointNeck = NK(0.1, 0.05),
	JointHead = A(0.05),
	JointJaw = A(-0.15),
	JointEarL = A(-0.4), JointEarR = A(-0.4),
	JointTail = A(-0.2), JointTailTip = A(0.1),
}

-- Gore: dipped and cocked to its right (yaw -, roll -), fore legs braced
local GORE_COCK: Pose = {
	JointRoot = R(-0.2, 0.05, 0.12, -0.04),
	JointChest = A(-0.02, -0.06),
	JointNeck = NK(0.45, -0.15, -0.15, -0.1),
	JointHead = A(-0.2, -0.15, -0.1),
	JointJaw = A(-0.15),
	JointEarL = A(-0.45), JointEarR = A(-0.45),
	JointTail = A(-0.3), JointTailTip = A(-0.1),
}
-- the hook: up and across to its left, the chest rising, a lunge forward
local GORE_HOOK: Pose = {
	JointRoot = R(0, 0.03, -0.1, 0.05),
	JointChest = A(0.06, 0.08),
	JointNeck = NK(0.4, 0.1, 0.2, 0.08, 0.1),
	JointHead = A(0.4, 0.2, 0.08),
	JointJaw = A(-0.3),
	JointEarL = A(-0.45), JointEarR = A(-0.45),
	JointTail = A(-0.4), JointTailTip = A(-0.2),
}

-- a hit: head thrown up, root knocked back, legs braced wide
local HIT: Pose = {
	JointRoot = R(0, 0.04, 0.15),
	JointChest = A(0.03),
	JointNeck = NK(0.25, 0.12),
	JointHead = A(0.15),
	JointJaw = A(-0.35),
	JointEarL = A(-0.5), JointEarR = A(-0.5),
	JointTail = A(-0.3), JointTailTip = A(-0.2),
}

-- Death: the fore knees buckle, then it tips over onto its left side (the killer on its
-- right), rolling about the ground line under its left hooves so nothing passes through
-- the ground. The roll is keyed densely (deathKey) so the root follows the arc.
local BUCKLE_ROOT = R(-0.25, -0.02)
local BUCKLE: Pose = {
	JointRoot = BUCKLE_ROOT,
	JointChest = A(-0.04),
	JointNeck = NK(0.4, 0.03, 0.1),
	JointHead = A(-0.05),
	JointJaw = A(-0.3),
	JointEarL = A(-0.2), JointEarR = A(-0.2),
	JointTail = A(0.3),
}
-- lying on its left side: legs out stiff, jaw slack. The head lies flat on its side (no
-- ground-ward yaw: the head is long, 0.1 rad of yaw already sinks it 0.3)
local DEAD: Pose = {
	JointChest = A(0, 0.04),
	JointNeck = NK(0.2, -0.1),
	JointHead = A(-0.1),
	JointJaw = A(-0.35),
	JointEarL = A(-0.1), JointEarR = A(-0.3),
	JointLegFL = A(0.3, 0, 0.1), JointLowerLegFL = A(-0.3), JointHoofFL = A(-0.3),
	JointLegFR = A(-0.1, 0, -0.15), JointLowerLegFR = A(-0.2), JointHoofFR = A(-0.2),
	JointLegBL = A(-0.3, 0, 0.1), JointLowerLegBL = A(0.3), JointHoofBL = A(-0.3),
	JointLegBR = A(-0.15, 0, -0.15), JointLowerLegBR = A(0.2), JointHoofBR = A(-0.2),
	JointTail = A(0.4, -0.3), JointTailTip = A(0.2),
}
local DEAD_ROLL = 1.45
local DEAD_DROP = 0.06 -- extra drop at the full roll so the flank meets the ground
local TIP = V(-1.6, 0, 0) -- the ground line under the left hooves' outer edge
local ROOT_AT = CFrame.new(P.JointRoot)

-- JointRoot for the body rolled +Z by theta about TIP, on top of base
local function rolled(theta: number, base: CFrame): CFrame
	local m = CFrame.new(TIP) * A(0, 0, theta) * CFrame.new(-TIP)
	return ROOT_AT:Inverse() * m * ROOT_AT * base
end

local function deathKey(t: number, theta: number, ease: string?): Quadruped.Key
	local w = math.clamp(theta / DEAD_ROLL, 0, 1)
	local pose: Pose = {}
	for name, cf in BUCKLE do
		pose[name] = cf:Lerp(DEAD[name] or I, w)
	end
	for name, cf in DEAD do
		if not pose[name] then
			pose[name] = I:Lerp(cf, w)
		end
	end
	pose.JointRoot = CFrame.new(0, -DEAD_DROP * w, 0) * rolled(theta, BUCKLE_ROOT)
	return { t = t, pose = pose, ease = ease }
end

------------------------------------------------------------------------------------
-- Moves

local moves: { [string]: { [string]: Phase } } = {}

moves.Charge = {
	windup = {
		duration = 1.0,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.15, pose = CHARGE_LOAD, ease = "out", plant = ALL },
			-- first scrape: up, down forward, dragged back
			{ t = 0.25, pose = PAW_UP, ease = "out", plant = { "FR", "BL", "BR" } },
			{ t = 0.3, pose = PAW_DOWN, ease = "in", plant = ALL, reach = FL_FWD },
			{ t = 0.35, pose = CHARGE_LOAD, ease = "out", plant = ALL, reach = FL_BACK },
			{ t = 0.5, pose = CHARGE_LOAD, ease = "inOut", plant = ALL },
			-- second scrape
			{ t = 0.6, pose = PAW_UP, ease = "out", plant = { "FR", "BL", "BR" } },
			{ t = 0.65, pose = PAW_DOWN, ease = "in", plant = ALL, reach = FL_FWD },
			{ t = 0.7, pose = CHARGE_LOAD, ease = "out", plant = ALL, reach = FL_BACK },
			{ t = 0.85, pose = CHARGE_SET, ease = "inOut", plant = ALL },
			{ t = 1, pose = CHARGE_SET, plant = ALL },
		},
		-- a snort with each scrape (jaw and head jerk), a tremble at the peak
		overlay = function(u, secs)
			local snort = bump(u, 0.27, 0.4) + bump(u, 0.62, 0.75)
			local tremble = smooth(0.85, 0.9, u) * math.sin(TAU * 12 * secs)
			return {
				JointJaw = A(-0.12 * snort),
				JointHead = A(0.05 * snort),
				JointChest = A(0, 0.012 * tremble),
				JointTailTip = A(0, 0.15 * tremble),
			}
		end,
	},
	-- two bounding strides: stretch, gather, stretch, gather
	active = {
		duration = 0.55,
		keys = {
			{ t = 0, pose = CHARGE_SET, plant = ALL },
			{ t = 0.2, pose = BOUND_STRETCH, ease = "out" },
			{ t = 0.45, pose = BOUND_GATHER, ease = "inOut", plant = HIND, reach = GATHERED },
			{ t = 0.7, pose = BOUND_STRETCH, ease = "inOut" },
			{ t = 0.95, pose = BOUND_GATHER, ease = "inOut", plant = HIND, reach = GATHERED },
			{ t = 1, pose = BOUND_GATHER, plant = HIND, reach = GATHERED },
		},
	},
	recover = {
		duration = 0.7,
		keys = {
			{ t = 0, pose = BOUND_GATHER, plant = HIND, reach = GATHERED },
			{ t = 0.14, pose = SKID, ease = "out", plant = ALL, reach = SKIDDED },
			{ t = 0.43, pose = with(SKID, { JointRoot = R(0, 0.05, 0.12) }), plant = ALL, reach = SKIDDED },
			{ t = 0.75, pose = ALERT, ease = "inOut", plant = ALL },
			{ t = 1, pose = ALERT, plant = ALL },
		},
		-- the head toss and snort, 0.3-0.6 s
		overlay = function(_, secs)
			local toss = bump(secs, 0.3, 0.6)
			local shake = math.sin(TAU * 5 * (secs - 0.3)) * toss
			return {
				JointNeck = A(0.2 * toss, 0.06 * shake),
				JointHead = A(0.15 * toss, 0.08 * shake, 0.12 * shake),
				JointJaw = A(-0.25 * bump(secs, 0.35, 0.55)),
				JointEarL = A(0, 0, -0.2 * shake),
				JointEarR = A(0, 0, -0.2 * shake),
			}
		end,
	},
}

moves.Gore = {
	windup = {
		duration = 0.6,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.5, pose = GORE_COCK, ease = "out", plant = ALL, reach = BRACED },
			{ t = 1, pose = with(GORE_COCK, { JointNeck = NK(0.47, -0.16, -0.16, -0.1), JointHead = A(-0.22, -0.16, -0.12) }), ease = "inOut", plant = ALL, reach = BRACED },
		},
		overlay = function(u, secs)
			local tremble = smooth(0.5, 0.6, u) * math.sin(TAU * 12 * secs)
			return { JointNeck = A(0, 0.015 * tremble), JointTailTip = A(0, 0.15 * tremble) }
		end,
	},
	-- the hook lands by 0.1 s and holds
	active = {
		duration = 0.15,
		keys = {
			{ t = 0, pose = GORE_COCK, plant = ALL, reach = BRACED },
			{ t = 0.67, pose = GORE_HOOK, ease = "out", plant = ALL, reach = BRACED },
			{ t = 1, pose = GORE_HOOK, plant = ALL, reach = BRACED },
		},
	},
	-- a head shake (0-0.35 s), then settles by 0.55
	recover = {
		duration = 0.65,
		keys = {
			{ t = 0, pose = GORE_HOOK, plant = ALL, reach = BRACED },
			{ t = 0.3, pose = with(GORE_HOOK, { JointNeck = NK(0.2, 0.05, 0.05), JointHead = A(0.1, 0.05), JointChest = A(0.04) }), ease = "out", plant = ALL, reach = BRACED },
			{ t = 0.85, pose = ALERT, ease = "inOut", plant = ALL },
			{ t = 1, pose = ALERT, plant = ALL },
		},
		overlay = function(_, secs)
			if secs >= 0.4 then
				return {}
			end
			local s = math.sin(TAU * 2 * secs / 0.4) * (1 - secs / 0.4) ^ 0.5
			return {
				JointNeck = A(0, 0.12 * s),
				JointHead = A(0, 0.12 * s, 0.15 * s),
				JointEarL = A(0, 0, -0.2 * s),
				JointEarR = A(0, 0, -0.2 * s),
			}
		end,
	},
}

moves.Stagger = {
	active = {
		duration = 0.28,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = HIT, ease = "out", plant = ALL, reach = THROWN },
			{ t = 0.45, pose = with(HIT, { JointJaw = A(-0.25) }), plant = ALL, reach = THROWN },
			{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
		},
		overlay = function(u, _, input)
			local side = math.clamp(input.side or 0, -1, 1)
			local e = if u < 0.2 then EASE.out(u / 0.2) else 1 - EASE.inOut((u - 0.2) / 0.8)
			return {
				JointNeck = A(0, 0.15 * side * e),
				JointHead = A(0, 0.2 * side * e, 0.12 * side * e),
				JointChest = A(0, 0, 0.05 * side * e),
			}
		end,
	},
}

moves.Death = {
	active = {
		duration = 0.6,
		mirror = true,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.2, pose = HIT, ease = "out", plant = ALL, reach = THROWN },
			{ t = 0.4, pose = BUCKLE, ease = "inOut", plant = ALL },
			-- tipping over, faster and faster
			deathKey(0.47, 0.1, "in"),
			deathKey(0.54, 0.3),
			deathKey(0.61, 0.58),
			deathKey(0.68, 0.9),
			deathKey(0.75, 1.22),
			deathKey(0.82, DEAD_ROLL),
			-- impact: rocks back a little (rolling past flat would sink the chest)
			deathKey(0.9, DEAD_ROLL - 0.07, "out"),
			deathKey(1, DEAD_ROLL, "inOut"),
		},
	},
}

Boar.moves = moves
Boar.sample = rig.sampler(moves, "Boar")
Boar.plant = rig.plant

------------------------------------------------------------------------------------
-- Loops

local LEG = 2.9 -- shoulder or hip to the ground, studs

local function walkAmp(speed: number): number
	return math.clamp(0.1 + 0.045 * speed, 0.14, 0.38)
end
local function circleAmp(speed: number): number
	return math.clamp(0.06 + 0.02 * speed, 0.08, 0.18)
end

local loops = {}

-- breathing (the chest heaves), ear flicks, a snort every so often, and now and then a
-- nod at the ground
function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 2.8)
	local slot = math.floor(clock / 4)
	local at = slot * 4 + hash(slot, seed) * 1.5
	local flick = bump(clock, at, at + 0.25)
	local which = hash(slot + 0.5, seed)
	local fl = if which < 0.6 then flick else 0
	local fr = if which > 0.4 then flick else 0
	-- snort: half of the 6 s slots, a quick head jerk with the jaw
	local nslot = math.floor(clock / 6)
	local snort = 0
	if hash(nslot + 0.25, seed) < 0.5 then
		local st = nslot * 6 + 1 + hash(nslot + 0.75, seed) * 4
		snort = bump(clock, st, st + 0.3)
	end
	-- nod: rooting at the ground, 40% of 10 s slots
	local rslot = math.floor(clock / 10)
	local nod = 0
	if hash(rslot + 0.4, seed) < 0.4 then
		local st = rslot * 10 + 1 + hash(rslot + 0.9, seed) * 7
		nod = smooth(st, st + 0.35, clock) * (1 - smooth(st + 1.1, st + 1.5, clock))
	end
	local look = math.sin(clock * 0.31 + seed) * 0.1 * (1 - nod)
	local pose: Pose = {
		JointRoot = R(0.02 * breath),
		JointChest = A(0.02 * breath),
		JointNeck = A(-0.03 + 0.01 * breath - 0.2 * nod, look * 0.6),
		JointHead = A(0.02 + 0.08 * snort - 0.1 * nod + 0.04 * math.sin(clock * 20) * nod, look * 0.4),
		JointJaw = A(-0.12 * snort),
		JointEarL = A(-0.1 - 0.4 * fl, 0, 0.25 * fl),
		JointEarR = A(-0.1 - 0.4 * fr, 0, -0.25 * fr),
		JointTail = A(0.2, 0.25 * math.sin(clock * 3.1)),
		JointTailTip = A(0.1, 0.2 * math.sin(clock * 3.1 - 0.8)),
	}
	plantLegs(pose, Quadruped.plantOf(ALL))
	return pose
end

-- a heavy trot: diagonal pairs (FL+BR, FR+BL), the big head bobbing, tail swishing
function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local amp = walkAmp(speed)
	local tuck = math.clamp(amp / 0.35, 0.5, 1.1)
	local pose: Pose = {}
	local steps = {}
	for tag, off in { FL = 0, BR = 0, FR = math.pi, BL = math.pi } do
		local a, lift, w = Quadruped.legCycle(phase + off, amp)
		setLeg(pose, steps, tag, a, 0, lift, w, 0.35 * tuck)
	end
	local bob = math.sin(phase * 2 + 0.6)
	pose.JointRoot = R(0.03 * math.sin(phase * 2), 0, 0, 0, 0.035 * math.sin(phase))
	pose.JointChest = A(0, 0.04 * math.sin(phase))
	pose.JointNeck = NK(0.25, -0.04 + 0.04 * bob)
	pose.JointHead = A(0.0 - 0.03 * bob)
	pose.JointEarL = A(-0.1 + 0.06 * bob)
	pose.JointEarR = A(-0.1 + 0.06 * bob)
	pose.JointTail = A(0.15, 0.2 * math.sin(phase - 0.5))
	pose.JointTailTip = A(0.05, 0.2 * math.sin(phase - 1.2))
	stepLegs(pose, steps)
	return pose
end

-- a heavy rotary gallop: FL, FR 0.1 later, BR half a cycle behind FL, BL 0.1 after it.
-- Head low, ears back, tail up.
function loops.run(phase: number, speed: number, _input: Input?): Pose
	local g = math.clamp(speed / 14, 0.6, 1.1)
	local ampF, ampH = 0.5 * g, 0.5 * g
	local pose: Pose = {}
	local steps = {}
	local fore, hind = 0, 0
	for tag, cyc in { FL = 0, FR = 0.1, BR = 0.5, BL = 0.6 } do
		local ph = phase - cyc * TAU
		local front = tag == "FL" or tag == "FR"
		local amp = if front then ampF else ampH
		local a, lift, w = Quadruped.legCycle(ph, amp)
		if not front and a > 0 then
			a *= 0.7 -- the hind legs reach forward less than they drive back: clear of the belly
		end
		w *= math.clamp((0.45 - math.abs(math.sin(ph))) * 4, 0, 1)
		setLeg(pose, steps, tag, a, 0, lift, w, if front then 0.5 else 0.35)
		if front then
			fore += a / 2
		else
			hind += a / 2
		end
	end
	-- s > 0 gathered (hind under, fore back), s < 0 stretched
	local s = math.clamp((hind - fore) / (ampF + ampH) * 2, -1, 1)
	pose.JointRoot = R(0.08 * math.max(0, s), -0.05 * s)
	pose.JointChest = A(-0.06 * math.max(0, s) + 0.08 * math.max(0, -s))
	pose.JointNeck = NK(0.3, -0.04 + 0.06 * s)
	pose.JointHead = A(-0.1 - 0.05 * s)
	pose.JointJaw = A(-0.1)
	pose.JointEarL = A(-0.5)
	pose.JointEarR = A(-0.5)
	pose.JointTail = A(-0.5 + 0.1 * s, 0.05 * math.sin(phase))
	pose.JointTailTip = A(-0.2, 0.08 * math.sin(phase - 0.8))
	stepLegs(pose, steps)
	return pose
end

-- a heavy side-pace at charging distance: the legs step out to the side in diagonal
-- pairs, the body leans into the motion, head low and turned to the target
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local ty = (input and input.targetYaw) or 0
	local amp = circleAmp(speed)
	local pose: Pose = {}
	local steps = {}
	for tag, off in { FL = 0, BR = 0, FR = math.pi, BL = math.pi } do
		local ph = phase + off
		local _, lift, w = Quadruped.legCycle(ph, amp)
		local out = if tag == "FL" or tag == "BL" then -0.05 else 0.05
		setLeg(pose, steps, tag, 0.06 * math.sin(ph), out - dir * amp * math.sin(ph), lift, w, 0.3)
	end
	local neckYaw = math.clamp(ty * 0.5, -0.4, 0.4)
	local headYaw = math.clamp(ty - neckYaw, -0.4, 0.4)
	pose.JointRoot = R(-0.05, 0.02, 0, 0, 0.06 * dir)
	pose.JointChest = A(0, 0, -0.03 * dir)
	-- a turned head swings its back corner into the chest: slide the neck out further
	pose.JointNeck = NK(0.3 + 0.32 * math.abs(neckYaw + headYaw), -0.07, neckYaw)
	pose.JointHead = A(-0.08 + 0.03 * math.sin(phase * 2), headYaw)
	pose.JointJaw = A(-0.05)
	pose.JointEarL = A(-0.35)
	pose.JointEarR = A(-0.35)
	pose.JointTail = A(-0.1, 0.15 * dir)
	pose.JointTailTip = A(0.05, 0.1 * math.sin(phase))
	stepLegs(pose, steps)
	return pose
end

Boar.loops = loops

-- How fast to advance a loop's phase (radians per second) so the planted hooves don't
-- skate. scale is the body's size: bigger strides, slower cycles.
function Boar.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	if loop == "walk" then
		return TAU * speed / (4 * LEG * math.sin(walkAmp(speed))) / s
	elseif loop == "run" then
		return TAU * (1.2 + 0.05 * speed) / s
	elseif loop == "circle" then
		return TAU * math.min(speed / (4 * LEG * math.sin(circleAmp(speed))), 2.2) / s
	end
	return 1 -- idle: pass the clock in seconds as its phase
end

-- every joint translation (the root's drop, the neck's slide) times the body's scale
function Boar.scaled(pose: Pose, scale: number): Pose
	if scale ~= 1 then
		for name, cf in pose do
			pose[name] = cf - cf.Position + cf.Position * scale
		end
	end
	return pose
end

-- the designed phase lengths, seconds (Enemies.luau's windup/recover override them)
Boar.durations = Quadruped.durations(moves)

return Boar
