--!strict
-- Elder Wolf King B: the wolf-family skeleton with a heavier four-beat stalk,
-- gallop, planted boss tells and two short, distinct forepaw attacks.
-- Same pose API as Wolf.luau; no instances or gameplay decisions live here.
--
-- UNIT SPACE: all pivots, root translations and paw targets are at Spirit Wolf
-- scale. EnemyAnimator applies 2.4 ONCE, after sampling. The King's larger soles
-- are described below in the same unit space (build_elder_wolf_king.luau).
--
-- Attack       Move        windup / active / pose recover    server recover
-- royalBite    RoyalBite     0.90 / 0.16 / 0.84                   1.00
-- kingsRush    KingsRush     1.00 / <=0.60 / 1.00                 1.00
-- crownfall    Crownfall     1.25 / 0.18 / 1.07                   1.25
-- pawSwipe     PawSwipe      0.45 / 0.12 / 0.63                   0.75
-- clawDown     ClawDown      0.55 / 0.12 / 0.73                   0.85
-- packCall     PackCall      1.20 / 0.10 / 0.90                   1.00
--
-- Stationary contact is the END of windup, when damage and strike VFX resolve.
-- Its active pose is follow-through at the beginning of the server's recover;
-- the pose recover uses the remainder. Rush samples its strides by elapsed
-- seconds, with the real DashSeconds passed as input.duration.
-- Stagger 0.28 and Death 0.60 retain the shared wolf timing and mirrored fall.
-- Mane and seal poses stay behind the body at contact, then swing through.

local Quadruped = require(script.Parent.Quadruped)
local Wolf = require(script.Parent.Wolf)

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Phase = Quadruped.Phase
type Leg = Quadruped.Leg
type Step = Quadruped.Step

local WolfKing = {}
local V = Vector3.new
local I, TAU = CFrame.identity, Quadruped.TAU
local A, R = Quadruped.A, Quadruped.R
local with, paws, smooth = Quadruped.with, Quadruped.paws, Quadruped.smooth
local ALL, HIND, NONE = Quadruped.ALL, Quadruped.HIND, Quadruped.NONE
local SUPPORT_RIGHT = { "FR", "BL", "BR" } -- the LEFT paw attacks
local SUPPORT_LEFT = { "FL", "BL", "BR" } -- the RIGHT paw attacks

WolfKing.JOINTS = table.clone(Wolf.JOINTS)
for _, name in { "JointManeL", "JointManeR", "JointSeal" } do
	table.insert(WolfKing.JOINTS, name)
end

-- Same pivots and bend directions as Wolf; use the shared planting/stepping
-- solver instead of copying its IK. The hind knees compress on NEGATIVE X.
local P = {
	JointRoot = V(0, 2.85, 1.6), JointSpine = V(0, 3.0, 0.8),
	JointLegFL = V(-0.7, 2.45, -1.3), JointElbowFL = V(-0.72, 1.35, -1.25), JointWristFL = V(-0.72, 0.32, -1.35),
	JointLegFR = V(0.7, 2.45, -1.3), JointElbowFR = V(0.72, 1.35, -1.25), JointWristFR = V(0.72, 0.32, -1.35),
	JointLegBL = V(-0.7, 2.5, 2.1), JointKneeBL = V(-0.75, 1.35, 1.8), JointHockBL = V(-0.75, 0.62, 2.3),
	JointLegBR = V(0.7, 2.5, 2.1), JointKneeBR = V(0.75, 1.35, 1.8), JointHockBR = V(0.75, 0.62, 2.3),
}
local LEGS: { [string]: Leg } = {
	FL = { upper = "JointLegFL", mid = "JointElbowFL", foot = "JointWristFL", base = "JointSpine", fold = -1, front = true, knee = -1 },
	FR = { upper = "JointLegFR", mid = "JointElbowFR", foot = "JointWristFR", base = "JointSpine", fold = -1, front = true, knee = -1 },
	BL = { upper = "JointLegBL", mid = "JointKneeBL", foot = "JointHockBL", base = "JointRoot", fold = -1, front = false, knee = 1 },
	BR = { upper = "JointLegBR", mid = "JointKneeBR", foot = "JointHockBR", base = "JointRoot", fold = -1, front = false, knee = 1 },
}
local rig = Quadruped.new({
	P = P, root = "JointRoot", spine = "JointSpine", legs = LEGS,
	sole = {
		front = { V(-0.375, -0.32, -0.99), V(0.375, -0.32, -0.99), V(-0.375, -0.32, 0.205), V(0.375, -0.32, 0.205) },
		hind = { V(-0.34, -0.62, -0.98), V(0.34, -0.62, -0.98), V(-0.34, -0.62, 0.075), V(0.34, -0.62, 0.075) },
	},
	curl = { front = -1.0, hind = -0.6 },
})

local function regalia(pose: Pose, spread: number, seal: number, pitch: number?): Pose
	return with(pose, {
		JointManeL = A(pitch or 0, 0, -spread),
		JointManeR = A(pitch or 0, 0, spread),
		JointSeal = A(seal),
	})
end

local BRACED = paws(-0.3, 0.2, 0.08, 0.08)
local COILED = paws(-0.3, 0.5, 0.08, 0.08)
local SKIDDED = paws(-0.45, 0.45, 0.15, 0.13)
local SPLAYED = paws(-0.3, 0.35, 0.22, 0.18)
local REARED = paws(0, 0.3, 0, 0.1)

-- The right claw tips touch the ClawDown circle, King-local (1.7, 0, -7).
-- Its toes extend 0.99 unit studs forward of the wrist. The solver levels the
-- wrist and plants it behind that point; this is not a scaled root translation.
local CLAW_CONTACT = paws(-0.25, 0.2, 0.04, 0.08)
CLAW_CONTACT.FR = V(1.7 / 2.4 - P.JointWristFR.X, 0, -7 / 2.4 + 0.99 - P.JointWristFR.Z)

local STAND: Pose = regalia({
	JointNeck = A(-0.08), JointHead = A(0.08), JointJaw = A(-0.02),
	JointEarL = A(0.08), JointEarR = A(0.08), JointCrest = A(-0.1),
	JointTail = A(0.12), JointTail2 = A(0.1), JointTail3 = A(0.08),
}, 0.1, 0)

-- The bite is a high, open-jaw tell; both forepaws remain planted. The mane
-- holds its flare through contact rather than snapping ahead of the skull.
local BITE_REAR = regalia(with(STAND, {
	JointRoot = R(0, 0.05, 0.15), JointSpine = A(-0.08),
	JointNeck = A(0.24), JointHead = A(0.12), JointJaw = A(-0.7),
	JointEarL = A(0.55), JointEarR = A(0.55), JointCrest = A(-0.4),
	JointTail = A(-0.35), JointTail2 = A(-0.1),
}), 0.35, -0.18, -0.08)
local BITE_CONTACT = regalia(with(STAND, {
	JointRoot = R(-0.12, -0.04, -0.12), JointSpine = A(0.05),
	JointNeck = A(-0.22), JointHead = A(-0.08), JointJaw = A(-0.02),
	JointEarL = A(0.45), JointEarR = A(0.45), JointCrest = A(-0.3),
	JointTail = A(-0.3), JointTail2 = A(-0.08),
}), 0.35, -0.18, -0.08)
local BITE_THROUGH = regalia(with(BITE_CONTACT, {
	JointRoot = R(-0.15, -0.06, -0.15),
	JointNeck = A(-0.28, -0.06), JointHead = A(0.02, -0.04),
}), 0.18, 0.2, 0.14)
local SPENT = regalia(with(STAND, {
	JointRoot = R(-0.15, 0.01), JointNeck = A(-0.22), JointHead = A(0.12),
	JointJaw = A(-0.12), JointEarL = A(0.5), JointEarR = A(0.5), JointCrest = A(0.18),
	JointTail = A(0.25), JointTail2 = A(0.18),
}), 0.06, -0.12, 0.12)

-- Rush: a low, still coil, then a hind-leg push. It never raises the jaw in
-- the bite's silhouette. The dash itself uses full-body, timed gallop strides.
local RUSH_LOAD = regalia(with(STAND, {
	JointRoot = R(-0.36, -0.04, 0.12), JointSpine = A(0.08),
	JointNeck = A(-0.25), JointHead = A(0.08), JointJaw = A(-0.18),
	JointEarL = A(0.6), JointEarR = A(0.6), JointCrest = A(-0.4),
	JointTail = A(-0.4), JointTail2 = A(-0.18), JointTail3 = A(0.12),
}), 0.3, 0.18, 0.08)
local RUSH_READY = with(RUSH_LOAD, {
	JointRoot = R(-0.38, -0.08, 0.06), JointSpine = A(0.1),
	JointNeck = A(-0.3), JointHead = A(0.1), JointTail = A(-0.48),
})
local RUSH_LAUNCH = regalia(with(RUSH_READY, {
	JointRoot = R(-0.18, 0.08, -0.04), JointSpine = A(0.03),
	JointLegFL = A(0.95, 0, -0.08), JointElbowFL = A(-0.8), JointWristFL = A(-0.2),
	JointLegFR = A(0.95, 0, 0.08), JointElbowFR = A(-0.8), JointWristFR = A(-0.2),
}), 0.25, 0.28, 0.2)
local RUSH_SKID = regalia(with(SPENT, {
	JointRoot = R(-0.25, 0.07, 0.1), JointSpine = A(-0.06),
	JointNeck = A(-0.12), JointHead = A(0.18), JointJaw = A(-0.2),
	JointCrest = A(0.1), JointTail = A(0.25),
}), 0.22, 0.28, 0.2)

-- Crownfall lifts BOTH shoulders and forepaws, with the hind paws planted.
-- The low, wide impact and held squat make the recovery an obvious opening.
local CROWN_RISE = regalia(with(STAND, {
	JointRoot = R(-0.12, 0.28, 0.18), JointSpine = A(-0.08),
	JointNeck = A(0.1), JointHead = A(0.1), JointJaw = A(-0.4),
	JointLegFL = A(1.1, 0.1, -0.12), JointElbowFL = A(0.85), JointWristFL = A(-1.7),
	JointLegFR = A(1.1, -0.1, 0.12), JointElbowFR = A(0.85), JointWristFR = A(-1.7),
	JointEarL = A(0.45), JointEarR = A(0.45), JointCrest = A(-0.5),
	JointTail = A(-0.45), JointTail2 = A(-0.15),
}), 0.42, -0.22, -0.08)
local CROWN_PEAK = regalia(with(CROWN_RISE, {
	JointRoot = R(-0.08, 0.32, 0.16), JointNeck = A(0.2), JointJaw = A(-0.6),
	JointLegFL = A(1.25, 0.1, -0.12), JointElbowFL = A(0.9), JointWristFL = A(-2.0),
	JointLegFR = A(1.25, -0.1, 0.12), JointElbowFR = A(0.9), JointWristFR = A(-2.0),
}), 0.5, -0.26, -0.1)
local CROWN_CONTACT = regalia(with(SPENT, {
	JointRoot = R(-0.38, -0.08, -0.06), JointSpine = A(0.05),
	JointNeck = A(-0.25), JointHead = A(0.15), JointJaw = A(-0.15),
	JointCrest = A(-0.25),
}), 0.48, -0.26, -0.1)
local CROWN_SETTLE = regalia(with(CROWN_CONTACT, {
	JointRoot = R(-0.28, -0.04), JointNeck = A(-0.18), JointHead = A(0.12),
	JointCrest = A(0.12),
}), 0.12, 0.25, 0.18)

-- PawSwipe: left shoulder rises and opens outward, then sweeps diagonally
-- inward. The right forepaw and both hind paws support the entire attack.
local SWIPE_LIFT = regalia(with(STAND, {
	JointRoot = R(-0.12, 0.02, 0.05, 0.05, -0.05), JointSpine = A(0, 0.08),
	JointNeck = A(-0.18, -0.08), JointHead = A(0.12, -0.05), JointJaw = A(-0.18),
	JointLegFL = A(0.9, 0.25, -0.18), JointElbowFL = A(0.65), JointWristFL = A(-1.0),
	JointEarL = A(0.35), JointEarR = A(0.35), JointCrest = A(-0.28),
	JointTail = A(-0.25, 0.1),
}), 0.25, -0.12, -0.05)
local SWIPE_PEAK = regalia(with(SWIPE_LIFT, {
	JointSpine = A(0, 0.1),
	JointLegFL = A(1.22, 0.38, -0.2), JointElbowFL = A(1.0), JointWristFL = A(-1.55),
}), 0.35, -0.2, -0.08)
local SWIPE_CONTACT = regalia(with(SWIPE_LIFT, {
	JointRoot = R(-0.12, -0.03, -0.08, -0.05, 0.03), JointSpine = A(0, -0.12),
	JointNeck = A(-0.15, 0.1), JointHead = A(0.1, 0.05),
	JointLegFL = A(1.0, -0.42, 0.1), JointElbowFL = A(0.25), JointWristFL = A(-0.7),
}), 0.35, -0.2, -0.08)
local SWIPE_THROUGH = regalia(with(SWIPE_CONTACT, {
	JointRoot = R(-0.16, -0.02, -0.04, -0.06, 0.04),
	JointLegFL = A(0.55, -0.5, 0.12), JointElbowFL = A(-0.2), JointWristFL = A(-0.35),
}), 0.16, 0.18, 0.12)

-- ClawDown: the RIGHT paw lifts above a lowered head, then drives straight
-- down. There is no torso sweep, so it cannot be mistaken for the left swipe.
local CLAW_LIFT = regalia(with(STAND, {
	JointRoot = R(-0.1, 0.03, 0.03, 0, 0.05), JointSpine = A(0.02),
	JointNeck = A(-0.3, 0.1), JointHead = A(0.06), JointJaw = A(-0.12),
	JointLegFR = A(0.95, -0.12, 0.1), JointElbowFR = A(0.8), JointWristFR = A(-1.2),
	JointEarL = A(0.4), JointEarR = A(0.4), JointCrest = A(-0.25),
	JointTail = A(-0.25, -0.1),
}), 0.25, -0.12, -0.05)
local CLAW_PEAK = regalia(with(CLAW_LIFT, {
	JointLegFR = A(1.18, -0.16, 0.1), JointElbowFR = A(1.1), JointWristFR = A(-1.7),
	JointNeck = A(-0.35, 0.12),
}), 0.3, -0.18, -0.08)
local CLAW_STRIKE = regalia(with(SPENT, {
	JointRoot = R(-0.16, -0.05, -0.14), JointSpine = A(0.03),
	JointNeck = A(-0.2, 0.06), JointHead = A(0.08), JointCrest = A(-0.22),
}), 0.3, -0.18, -0.08)
local CLAW_THROUGH = regalia(with(CLAW_STRIKE, {
	JointRoot = R(-0.22, -0.06, -0.14), JointNeck = A(-0.18),
	JointCrest = A(0.1),
}), 0.12, 0.22, 0.16)

-- PackCall stays tall on all four paws: a throat-up silhouette and a broad
-- silver mane. It does not reuse the crouched, two-paw Crownfall silhouette.
local CALL_RISE = regalia(with(STAND, {
	JointRoot = R(0, 0.02, 0.08), JointSpine = A(-0.06),
	JointNeck = A(0.35), JointHead = A(0.22), JointJaw = A(-0.65),
	JointEarL = A(0.15), JointEarR = A(0.15), JointCrest = A(-0.5),
	JointTail = A(-0.3), JointTail2 = A(-0.05), JointTail3 = A(0.15),
}), 0.48, -0.12, -0.08)
local CALL_PEAK = regalia(with(CALL_RISE, {
	JointNeck = A(0.42), JointHead = A(0.25), JointJaw = A(-0.78),
}), 0.55, -0.18, -0.1)
local CALL_AFTER = regalia(with(CALL_RISE, {
	JointNeck = A(0.28), JointHead = A(0.16), JointJaw = A(-0.5),
}), 0.5, 0.1, 0.04)

--------------------------------------------------------------------------------
-- Locomotion. A four-beat walk keeps three paws down for most of its cycle.
-- Stride rates account for the King's scale; sampling still returns unit poses.

local LEG = 2.3
local loops = {}

local function walkAmp(speed: number): number
	return math.clamp(0.12 + 0.035 * speed, 0.14, 0.42)
end

local function circleAmp(speed: number): number
	return math.clamp(0.05 + 0.014 * speed, 0.08, 0.16)
end

local function stalkStep(phase: number, amp: number): (number, number, number)
	local u = phase / TAU % 1
	if u < 0.72 then
		return amp * (1 - 2 * u / 0.72), 0, 1
	end
	local swing = (u - 0.72) / 0.28
	local lift = math.sin(math.pi * swing)
	return amp * (-1 + 2 * smooth(0, 1, swing)), lift, 1 - smooth(0, 0.3, lift)
end

function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 4.2 + seed)
	local look = 0.1 * math.sin(clock * 0.24 + seed)
	local slot = math.floor(clock / 6)
	local at = slot * 6 + Quadruped.hash(slot, seed) * 2
	local ear = Quadruped.bump(clock, at, at + 0.32)
	local pose = regalia(with(STAND, {
		JointRoot = R(0.012 * breath), JointSpine = A(0.012 * breath),
		JointNeck = A(-0.08 + 0.008 * breath, look), JointHead = A(0.08, look * 0.5),
		JointEarL = A(0.08 + 0.3 * ear), JointEarR = A(0.08 + 0.12 * ear),
		JointTail = A(0.12, 0.08 * math.sin(clock * 1.1)),
		JointTail2 = A(0.1, 0.06 * math.sin(clock * 1.1 - 0.6)),
		JointTail3 = A(0.08, 0.06 * math.sin(clock * 1.1 - 1.2)),
	}), 0.1 + 0.015 * math.sin(clock * TAU / 4.2 + seed - 0.5), 0.025 * math.sin(clock * 1.1 - 0.8))
	return rig.plant(pose)
end

function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	for tag, off in { BL = 0, FL = 0.25, BR = 0.5, FR = 0.75 } do
		local a, lift, w = stalkStep(phase - off * TAU, walkAmp(speed))
		rig.setLeg(pose, steps, tag, a, 0, lift, w, 0.28)
	end
	local bob = math.sin(phase * 4)
	pose.JointRoot = R(-0.035 + 0.018 * bob, 0.015 * math.sin(phase * 2), 0, 0, 0.025 * math.sin(phase))
	pose.JointSpine = A(0, 0.025 * math.sin(phase - 0.2))
	pose.JointNeck = A(-0.14 + 0.02 * bob)
	pose.JointHead = A(0.1 - 0.015 * bob)
	pose.JointEarL, pose.JointEarR = A(0.15), A(0.15)
	pose.JointCrest = A(-0.08)
	pose.JointTail = A(0.05, 0.08 * math.sin(phase - 0.4))
	pose.JointTail2 = A(0.08, 0.07 * math.sin(phase - 1.0))
	pose.JointTail3 = A(0.15, 0.06 * math.sin(phase - 1.6))
	pose = regalia(pose, 0.13 + 0.035 * math.sin(phase * 2 - 0.55), 0.065 * math.sin(phase * 2 - 0.9), 0.025 * math.sin(phase * 2 - 0.55))
	rig.stepLegs(pose, steps)
	return pose
end

local function gallop(phase: number, speed: number): Pose
	local g = math.clamp(speed / 16, 0.7, 1.1)
	local ampF, ampH = 0.68 * g, 0.58 * g
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	local fore, hind = 0, 0
	for tag, off in { FL = 0, FR = 0.1, BR = 0.5, BL = 0.6 } do
		local ph = phase - off * TAU
		local front = tag == "FL" or tag == "FR"
		local amp = if front then ampF else ampH
		local a, lift, w = Quadruped.legCycle(ph, amp)
		if not front and a > 0 then
			a *= 0.65 -- the reaching hind paws stay outside and behind the forepaws
		end
		w *= math.clamp((0.45 - math.abs(math.sin(ph))) * 4, 0, 1)
		local roll = if front then 0 else (if tag == "BL" then -0.22 else 0.22) * math.max(0, a / amp)
		rig.setLeg(pose, steps, tag, a, roll, lift, w, if front then 0.52 else 0.32)
		if front then fore += a / 2 else hind += a / 2 end
	end
	local s = math.clamp((hind - fore) / (ampF + ampH) * 2, -1, 1)
	pose.JointRoot = R(0.06 * math.max(0, s), -0.05 * s)
	pose.JointSpine = A(-0.08 * math.max(0, s) + 0.13 * math.max(0, -s))
	pose.JointNeck = A(-0.22 + 0.05 * s)
	pose.JointHead = A(0.14 - 0.03 * s)
	pose.JointJaw = A(-0.18)
	pose.JointEarL, pose.JointEarR = A(0.65), A(0.65)
	pose.JointCrest = A(0.12)
	pose.JointTail = A(-0.08 + 0.06 * s, 0.04 * math.sin(phase))
	pose.JointTail2 = A(0.05, 0.05 * math.sin(phase - 0.7))
	pose.JointTail3 = A(0.35, 0.05 * math.sin(phase - 1.4))
	pose = regalia(pose, 0.18 + 0.04 * math.sin(phase - 0.55), 0.12 * math.sin(phase - 0.9), 0.16 + 0.04 * math.sin(phase - 0.55))
	rig.stepLegs(pose, steps)
	return pose
end

function loops.run(phase: number, speed: number, _input: Input?): Pose
	return gallop(phase, speed)
end

function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local yaw = (input and input.targetYaw) or 0
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	for tag, off in { BL = 0, FL = 0.25, BR = 0.5, FR = 0.75 } do
		local a, lift, w = stalkStep(phase - off * TAU, circleAmp(speed))
		local out = if tag == "FL" or tag == "BL" then -0.08 else 0.08
		rig.setLeg(pose, steps, tag, 0.04 * math.sin(phase - off * TAU), out - dir * a, lift, w, 0.24)
	end
	local ny = math.clamp(yaw * 0.5, -0.3, 0.3)
	pose.JointRoot = R(-0.035, -0.02, 0, 0, 0.05 * dir)
	pose.JointSpine = A(0, 0, -0.02 * dir)
	pose.JointNeck = A(-0.18, ny)
	pose.JointHead = A(0.16, math.clamp(yaw - ny, -0.3, 0.3))
	pose.JointJaw = A(-0.08)
	pose.JointEarL, pose.JointEarR = A(0.25), A(0.25)
	pose.JointCrest = A(-0.18)
	pose.JointTail = A(0.05, 0.08 * dir)
	pose.JointTail2 = A(0.1, 0.04 * math.sin(phase - 0.6))
	pose.JointTail3 = A(0.14)
	pose = regalia(pose, 0.18, 0.055 * math.sin(phase - 0.8), 0.03)
	rig.stepLegs(pose, steps)
	return pose
end

local launchPlanted = rig.plant(table.clone(RUSH_LAUNCH), HIND, COILED)
local function rushStride(seconds: number): Pose
	-- Elapsed seconds keep a short, wall-stopped dash from cramming two whole
	-- strides into its shortened active phase. Blend out of the actual push pose.
	local running = gallop(seconds * TAU * 3.0, 18)
	local mix = smooth(0, 0.06, seconds)
	for _, name in WolfKing.JOINTS do
		running[name] = (launchPlanted[name] or I):Lerp(running[name] or I, mix)
	end
	return running
end

--------------------------------------------------------------------------------
-- Keyed attacks. The final contact key is held briefly before the phase ends,
-- so a render frame immediately before server resolution already shows impact.

local moves: { [string]: { [string]: Phase } } = {}

moves.RoyalBite = {
	windup = { duration = 0.9, keys = {
		{ t = 0, pose = STAND, plant = ALL },
		{ t = 0.24, pose = BITE_REAR, ease = "out", plant = ALL, reach = BRACED },
		{ t = 0.84, pose = BITE_REAR, plant = ALL, reach = BRACED },
		{ t = 0.98, pose = BITE_CONTACT, ease = "in", plant = ALL, reach = BRACED },
		{ t = 1, pose = BITE_CONTACT, plant = ALL, reach = BRACED },
	} },
	active = { duration = 0.16, keys = {
		{ t = 0, pose = BITE_CONTACT, plant = ALL, reach = BRACED },
		{ t = 0.65, pose = BITE_THROUGH, ease = "out", plant = ALL, reach = BRACED },
		{ t = 1, pose = BITE_THROUGH, plant = ALL, reach = BRACED },
	} },
	recover = { duration = 0.84, keys = {
		{ t = 0, pose = BITE_THROUGH, plant = ALL, reach = BRACED },
		{ t = 0.2, pose = SPENT, ease = "out", plant = ALL, reach = BRACED },
		{ t = 0.55, pose = SPENT, plant = ALL, reach = BRACED },
		{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
	} },
}

moves.KingsRush = {
	windup = { duration = 1.0, keys = {
		{ t = 0, pose = STAND, plant = ALL },
		{ t = 0.24, pose = RUSH_LOAD, ease = "out", plant = ALL, reach = COILED },
		{ t = 0.7, pose = RUSH_LOAD, plant = ALL, reach = COILED },
		{ t = 0.88, pose = RUSH_READY, ease = "inOut", plant = ALL, reach = COILED },
		{ t = 1, pose = RUSH_LAUNCH, ease = "in", plant = HIND, reach = COILED },
	} },
	active = {
		duration = 0.6,
		keys = { { t = 0, pose = {}, plant = NONE }, { t = 1, pose = {}, plant = NONE } },
		overlay = function(_, seconds, _) return rushStride(seconds) end,
	},
	recover = { duration = 1.0, keys = {
		{ t = 0, pose = RUSH_SKID, plant = ALL, reach = SKIDDED },
		{ t = 0.3, pose = RUSH_SKID, plant = ALL, reach = SKIDDED },
		{ t = 0.55, pose = SPENT, ease = "out", plant = ALL, reach = BRACED },
		{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
	} },
}

moves.Crownfall = {
	windup = { duration = 1.25, keys = {
		{ t = 0, pose = STAND, plant = ALL },
		{ t = 0.25, pose = RUSH_LOAD, ease = "out", plant = ALL, reach = COILED },
		{ t = 0.55, pose = CROWN_RISE, ease = "inOut", plant = HIND, reach = REARED },
		{ t = 0.84, pose = CROWN_PEAK, ease = "out", plant = HIND, reach = REARED },
		{ t = 0.98, pose = CROWN_CONTACT, ease = "in", plant = ALL, reach = SPLAYED },
		{ t = 1, pose = CROWN_CONTACT, plant = ALL, reach = SPLAYED },
	} },
	active = { duration = 0.18, keys = {
		{ t = 0, pose = CROWN_CONTACT, plant = ALL, reach = SPLAYED },
		{ t = 0.75, pose = CROWN_SETTLE, ease = "out", plant = ALL, reach = SPLAYED },
		{ t = 1, pose = CROWN_SETTLE, plant = ALL, reach = SPLAYED },
	} },
	recover = { duration = 1.07, keys = {
		{ t = 0, pose = CROWN_SETTLE, plant = ALL, reach = SPLAYED },
		{ t = 0.4, pose = CROWN_SETTLE, plant = ALL, reach = SPLAYED },
		{ t = 0.7, pose = SPENT, ease = "inOut", plant = ALL, reach = BRACED },
		{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
	} },
}

moves.PawSwipe = {
	windup = { duration = 0.45, keys = {
		{ t = 0, pose = STAND, plant = ALL },
		{ t = 0.2, pose = SWIPE_LIFT, ease = "out", plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 0.44, pose = SWIPE_PEAK, ease = "out", plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 0.8, pose = SWIPE_PEAK, plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 0.97, pose = SWIPE_CONTACT, ease = "in", plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 1, pose = SWIPE_CONTACT, plant = SUPPORT_RIGHT, reach = BRACED },
	} },
	active = { duration = 0.12, keys = {
		{ t = 0, pose = SWIPE_CONTACT, plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 0.85, pose = SWIPE_THROUGH, ease = "out", plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 1, pose = SWIPE_THROUGH, plant = SUPPORT_RIGHT, reach = BRACED },
	} },
	recover = { duration = 0.63, keys = {
		{ t = 0, pose = SWIPE_THROUGH, plant = SUPPORT_RIGHT, reach = BRACED },
		{ t = 0.36, pose = SPENT, ease = "out", plant = ALL, reach = BRACED },
		{ t = 0.62, pose = SPENT, plant = ALL, reach = BRACED },
		{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
	} },
}

moves.ClawDown = {
	windup = { duration = 0.55, keys = {
		{ t = 0, pose = STAND, plant = ALL },
		{ t = 0.18, pose = CLAW_LIFT, ease = "out", plant = SUPPORT_LEFT, reach = BRACED },
		{ t = 0.43, pose = CLAW_PEAK, ease = "out", plant = SUPPORT_LEFT, reach = BRACED },
		{ t = 0.81, pose = CLAW_PEAK, plant = SUPPORT_LEFT, reach = BRACED },
		{ t = 0.97, pose = CLAW_STRIKE, ease = "in", plant = ALL, reach = CLAW_CONTACT },
		{ t = 1, pose = CLAW_STRIKE, plant = ALL, reach = CLAW_CONTACT },
	} },
	active = { duration = 0.12, keys = {
		{ t = 0, pose = CLAW_STRIKE, plant = ALL, reach = CLAW_CONTACT },
		{ t = 0.8, pose = CLAW_THROUGH, ease = "out", plant = ALL, reach = CLAW_CONTACT },
		{ t = 1, pose = CLAW_THROUGH, plant = ALL, reach = CLAW_CONTACT },
	} },
	recover = { duration = 0.73, keys = {
		{ t = 0, pose = CLAW_THROUGH, plant = ALL, reach = CLAW_CONTACT },
		{ t = 0.22, pose = CLAW_THROUGH, plant = ALL, reach = CLAW_CONTACT },
		{ t = 0.6, pose = SPENT, ease = "inOut", plant = ALL, reach = BRACED },
		{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
	} },
}

moves.PackCall = {
	windup = {
		duration = 1.2,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.28, pose = CALL_RISE, ease = "out", plant = ALL, reach = BRACED },
			{ t = 0.55, pose = CALL_PEAK, ease = "inOut", plant = ALL, reach = BRACED },
			{ t = 1, pose = CALL_PEAK, plant = ALL, reach = BRACED },
		},
		overlay = function(u, seconds, _)
			local voice = 0.018 * math.sin(seconds * TAU * 9) * smooth(0.3, 0.5, u)
			return { JointJaw = A(voice), JointManeL = A(0, voice, 0), JointManeR = A(0, -voice, 0) }
		end,
	},
	active = { duration = 0.1, keys = {
		{ t = 0, pose = CALL_PEAK, plant = ALL, reach = BRACED },
		{ t = 1, pose = CALL_AFTER, ease = "out", plant = ALL, reach = BRACED },
	} },
	recover = { duration = 0.9, keys = {
		{ t = 0, pose = CALL_AFTER, plant = ALL, reach = BRACED },
		{ t = 0.25, pose = SPENT, ease = "out", plant = ALL, reach = BRACED },
		{ t = 0.55, pose = SPENT, plant = ALL, reach = BRACED },
		{ t = 1, pose = STAND, ease = "inOut", plant = ALL },
	} },
}

-- Reuse the shared flinch and mirrored fall, with the King's sole dimensions.
-- These tables are read only; King-specific secondary motion is added below.
moves.Stagger = Wolf.moves.Stagger
moves.Death = Wolf.moves.Death
local sampleKeyed = rig.sampler(moves, "WolfKing")

function WolfKing.sample(move: string, phase: string, u: number, input: Input?): Pose
	local pose = sampleKeyed(move, phase, u, input)
	u = math.clamp(u, 0, 1)
	if move == "Stagger" then
		local e = smooth(0, 0.28, u) * (1 - smooth(0.4, 1, u))
		local side = math.clamp((input and input.side) or 0, -1, 1)
		pose = regalia(pose, 0.1 + 0.2 * e, -0.22 * e, 0.12 * e)
		pose.JointManeL *= A(0, 0.08 * side * e)
		pose.JointManeR *= A(0, 0.08 * side * e)
	elseif move == "Death" then
		local e = smooth(0.25, 0.95, u)
		local side = if input and input.side and input.side < 0 then -1 else 1
		pose.JointManeL = A(0.22 * e, 0.1 * side * e, 0.18 * side * e)
		pose.JointManeR = A(0.22 * e, 0.1 * side * e, 0.18 * side * e)
		pose.JointSeal = A(-0.18 * e, 0, 0.35 * side * e)
	end
	return pose
end

function WolfKing.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	-- A stance sweeps +amp -> -amp over 72% of a cycle. Match that paw
	-- travel to the root speed; the shared trot's 50% stance rate would skate.
	if loop == "walk" then
		return TAU * speed * 0.72 / (2 * LEG * math.sin(walkAmp(speed))) / s
	elseif loop == "run" then
		return TAU * (1.6 + 0.045 * speed) / s
	elseif loop == "circle" then
		return TAU * math.min(speed * 0.72 / (2 * LEG * math.sin(circleAmp(speed))), 2.0) / s
	end
	return 1
end

WolfKing.moves = moves
WolfKing.durations = Quadruped.durations(moves)
WolfKing.loops = loops
WolfKing.scaled = Wolf.scaled
WolfKing.plant = rig.plant

return WolfKing
