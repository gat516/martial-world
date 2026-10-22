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
-- kingLeap     KingLeap      1.10 / dash 0.70 (air, arc 16) / 1.00  (lands at the end of the dash)
-- kingRake     KingRake      0.50 / 0.14 / 0.76                   0.90 (windup opens on the landing)
-- kingLeapSkid KingLeapSkid  recover 1.00 (the leap's recover)    (mirror; head leads input.targetYaw)
-- kingsRushSkid KingsRushSkid recover 1.00 (the rush's recover)   (mirror; head leads input.targetYaw)
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
	JointLegFL = A(0.95, 0, -0.3), JointElbowFL = A(-0.8), JointWristFL = A(-0.2),
	JointLegFR = A(0.95, 0, 0.3), JointElbowFR = A(-0.8), JointWristFR = A(-0.2),
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
	JointLegFL = A(1.1, 0.1, -0.5), JointElbowFL = A(0.85), JointWristFL = A(-1.7),
	JointLegFR = A(1.1, -0.1, 0.5), JointElbowFR = A(0.85), JointWristFR = A(-1.7),
	JointEarL = A(0.45), JointEarR = A(0.45), JointCrest = A(-0.5),
	JointTail = A(-0.45), JointTail2 = A(-0.15),
}), 0.42, -0.22, -0.08)
local CROWN_PEAK = regalia(with(CROWN_RISE, {
	JointRoot = R(-0.08, 0.32, 0.16), JointNeck = A(0.2), JointJaw = A(-0.6),
	JointLegFL = A(1.25, 0.1, -0.55), JointElbowFL = A(0.9), JointWristFL = A(-2.0),
	JointLegFR = A(1.25, -0.1, 0.55), JointElbowFR = A(0.9), JointWristFR = A(-2.0),
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
	JointLegFL = A(0.9, 0.25, -0.5), JointElbowFL = A(0.65), JointWristFL = A(-1.0),
	JointEarL = A(0.35), JointEarR = A(0.35), JointCrest = A(-0.28),
	JointTail = A(-0.25, 0.1),
}), 0.25, -0.12, -0.05)
local SWIPE_PEAK = regalia(with(SWIPE_LIFT, {
	JointSpine = A(0, 0.1),
	JointLegFL = A(1.22, 0.45, -0.6), JointElbowFL = A(1.0), JointWristFL = A(-1.55),
}), 0.35, -0.2, -0.08)
local SWIPE_CONTACT = regalia(with(SWIPE_LIFT, {
	JointRoot = R(-0.12, -0.03, -0.08, -0.05, 0.03), JointSpine = A(0, -0.12),
	JointNeck = A(-0.15, 0.1), JointHead = A(0.1, 0.05),
	JointLegFL = A(1.0, -0.25, -0.25), JointElbowFL = A(0.25), JointWristFL = A(-0.7),
}), 0.35, -0.2, -0.08)
local SWIPE_THROUGH = regalia(with(SWIPE_CONTACT, {
	JointRoot = R(-0.16, -0.02, -0.04, -0.06, 0.04),
	JointLegFL = A(0.55, -0.3, -0.1), JointElbowFL = A(-0.2), JointWristFL = A(-0.35),
}), 0.16, 0.18, 0.12)

-- ClawDown: the RIGHT paw lifts above a lowered head, then drives straight
-- down. There is no torso sweep, so it cannot be mistaken for the left swipe.
local CLAW_LIFT = regalia(with(STAND, {
	JointRoot = R(-0.1, 0.03, 0.03, 0, 0.05), JointSpine = A(0.02),
	JointNeck = A(-0.3, 0.1), JointHead = A(0.06), JointJaw = A(-0.12),
	JointLegFR = A(0.95, -0.1, 0.5), JointElbowFR = A(0.8), JointWristFR = A(-1.2),
	JointEarL = A(0.4), JointEarR = A(0.4), JointCrest = A(-0.25),
	JointTail = A(-0.25, -0.1),
}), 0.25, -0.12, -0.05)
local CLAW_PEAK = regalia(with(CLAW_LIFT, {
	JointLegFR = A(1.18, -0.1, 0.6), JointElbowFR = A(1.1), JointWristFR = A(-1.7),
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
	-- the chest rises first, then the head and tail follow it
	local chest = math.sin(clock * TAU / 4.2 + seed - 0.35)
	local look = 0.12 * math.sin(clock * 0.24 + seed) + 0.05 * math.sin(clock * 0.61 + seed * 2)
	local lookLate = 0.12 * math.sin(clock * 0.24 + seed - 0.7) + 0.05 * math.sin(clock * 0.61 + seed * 2 - 0.9)
	local slot = math.floor(clock / 6)
	local at = slot * 6 + Quadruped.hash(slot, seed) * 2
	local ear = Quadruped.bump(clock, at, at + 0.32)
	local slot2 = math.floor(clock / 4.5)
	local at2 = slot2 * 4.5 + Quadruped.hash(slot2, seed + 3) * 2.5
	local earR = Quadruped.bump(clock, at2, at2 + 0.28)
	local flick = Quadruped.bump(clock, at + 1.2, at + 2.0) * math.sin((clock - at) * 18)
	-- weight drifts side to side over the planted paws
	local shift = math.sin(clock * 0.31 + seed)
	local pose = regalia(with(STAND, {
		JointRoot = R(-0.01 + 0.014 * breath, 0.006 * breath, 0, 0.01 * shift, 0.025 * shift),
		JointSpine = A(0.014 * chest, 0.012 * math.sin(clock * 0.5 + seed), -0.012 * shift),
		JointNeck = A(-0.08 + 0.012 * chest, look),
		JointHead = A(0.08 + 0.012 * math.sin(clock * 0.9 + seed), lookLate * 0.7),
		JointJaw = A(-0.02 - 0.01 * math.max(0, math.sin(clock * 0.37 + seed))),
		JointEarL = A(0.08 + 0.3 * ear), JointEarR = A(0.08 + 0.25 * earR),
		JointTail = A(0.12 + 0.02 * breath, 0.1 * math.sin(clock * 0.9) + 0.12 * flick),
		JointTail2 = A(0.1, 0.08 * math.sin(clock * 0.9 - 0.7) + 0.16 * flick),
		JointTail3 = A(0.08, 0.08 * math.sin(clock * 0.9 - 1.4) + 0.2 * flick),
	}), 0.1 + 0.02 * math.sin(clock * TAU / 4.2 + seed - 0.9), 0.03 * math.sin(clock * 1.1 - 0.8))
	local sway = 0.04 * shift
	return rig.plant(pose, ALL, { FL = V(0, 0, 0.02 * shift), FR = V(0, 0, -0.02 * shift), BL = V(sway * 0.4, 0, 0), BR = V(sway * 0.4, 0, 0) })
end

function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	for tag, off in { BL = 0, FL = 0.25, BR = 0.5, FR = 0.75 } do
		local a, lift, w = stalkStep(phase - off * TAU, walkAmp(speed))
		rig.setLeg(pose, steps, tag, a, 0, lift, w, 0.28)
	end
	local bob = math.sin(phase * 4)
	-- a footfall dips the chest (the forepaws land at phase 0.25 and 0.75), a hind
	-- footfall dips the hips; shoulders and hips sway against each other
	local chestDip = math.max(0, math.sin(phase * 2 - 0.5)) * 0.03
	pose.JointRoot = R(-0.04 + 0.022 * bob, 0.015 * math.sin(phase * 2) + 0.01 * chestDip, 0, 0.03 * math.sin(phase - 0.3), 0.04 * math.sin(phase))
	pose.JointSpine = A(chestDip - 0.01, 0.045 * math.sin(phase - 0.2), -0.035 * math.sin(phase))
	pose.JointNeck = A(0.06 + 0.03 * math.sin(phase * 4 - 0.9), 0.05 * math.sin(phase - 0.9)) -- regal: head held high
	pose.JointHead = A(0.0 - 0.025 * math.sin(phase * 4 - 1.7), 0.04 * math.sin(phase - 1.5))
	pose.JointJaw = A(-0.03 - 0.015 * math.sin(phase * 4 - 2.2))
	pose.JointEarL, pose.JointEarR = A(0.15 + 0.05 * math.sin(phase * 4 - 2)), A(0.15 + 0.05 * math.sin(phase * 4 - 2.6))
	pose.JointCrest = A(-0.08 + 0.03 * math.sin(phase * 4 - 1.2))
	pose.JointTail = A(0.05 + 0.03 * math.sin(phase * 4 - 1.1), 0.12 * math.sin(phase - 0.4))
	pose.JointTail2 = A(0.08 + 0.04 * math.sin(phase * 4 - 1.8), 0.1 * math.sin(phase - 1.0))
	pose.JointTail3 = A(0.15 + 0.04 * math.sin(phase * 4 - 2.5), 0.09 * math.sin(phase - 1.6))
	pose = regalia(pose, 0.13 + 0.035 * math.sin(phase * 2 - 0.55), 0.065 * math.sin(phase * 2 - 0.9), 0.025 * math.sin(phase * 2 - 0.55))
	rig.stepLegs(pose, steps)
	return pose
end

-- THE BOUNDING GALLOP. A rotary four-beat gallop (hind left, hind right, fore left,
-- fore right) at a real cycle rate: gallopRate(speed) cycles/s, not scaled by the
-- body (heavy animals turn their legs over slowly and cover ground per bound).
-- Each paw is down for STANCE of the cycle and, while down, slides back along the
-- ground at EXACTLY the ground speed: its shoulder/hip angle sweeps +-a with a the
-- angle whose reach covers speed * stance time (so there is no skating). Between
-- stances there is a short flight (all four paws up) where the body rises. Speeds
-- are real studs/s; the poses are in unit space (divide by the 2.4 scale).
local STANCE = 0.32
local OFFSETS = { BL = 0, BR = 0.1, FL = 0.5, FR = 0.6 }
local LEG_EFF = 2.2 -- effective hip-to-paw reach in unit studs at the bend we plant with
local GAIT_K = 1.0 -- calibrates stance sweep against measured skating

WolfKing.GALLOP = { STANCE = STANCE, OFFSETS = OFFSETS }

local function gallopRate(speed: number): number
	return 0.9 + 0.014 * speed -- cycles per second
end

local function gallop(phase: number, speed: number, rate: number?): Pose
	local f = rate or gallopRate(speed)
	local half = GAIT_K * (speed / 2.4) * (STANCE / f) / 2 -- unit studs each side of the hip
	local aHalf = math.asin(math.clamp(half / LEG_EFF, 0, 0.8))
	local LEGS = rig.LEGS
	local cyc = phase / TAU % 1
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	local stance: { [string]: number } = { FL = 0, FR = 0, BL = 0, BR = 0 }
	local reach: { [string]: Vector3 } = {}
	for tag, off in OFFSETS do
		local front = tag == "FL" or tag == "FR"
		local x = (cyc - off) % 1
		local out = if tag == "BL" or tag == "FL" then -1 else 1
		if x < STANCE then
			-- stance: the paw is PLANTED and slides back at exactly the ground speed
			-- (reach is in model space, +Z back), touching down ahead of the hip
			local s = x / STANCE
			stance[tag] = 1
			reach[tag] = Vector3.new(out * 0.04, 0, half * (2 * s - 1) - 0.05)
			pose[LEGS[tag].upper] = A(0, 0, out * (if front then 0.04 else 0.14))
		else
			-- swing: lift off, reach out ahead of the touchdown, pull back to land
			local s = (x - STANCE) / (1 - STANCE)
			local e = smooth(0, 1, s)
			local a = -aHalf + 2 * aHalf * e + (if front then 0.3 else 0.2) * aHalf * math.sin(math.pi * s) ^ 2
			local lift = math.sin(math.pi * math.min(1, s * 1.15)) ^ 0.8
			rig.setLeg(pose, steps, tag, a, out * (if front then 0.04 else 0.16) * (0.4 + 0.6 * lift), lift, 0, if front then 0.42 else 0.26)
		end
	end
	-- flight rises the body, stance settles it; the nose lifts as the hind legs drive
	local flight = math.max(0, math.cos(TAU * 2 * (cyc - 0.46))) ^ 1.5
	local drive = math.cos(TAU * (cyc - 0.2))
	local heave = math.cos(TAU * (cyc - 0.35))
	pose.JointRoot = R(0.1 * flight - 0.05 * (1 - flight), 0.07 * drive, 0, 0.02 * math.sin(TAU * cyc), 0.025 * math.sin(TAU * cyc * 2))
	pose.JointSpine = A(-0.1 * heave, 0.03 * math.sin(TAU * cyc + 0.4), 0.025 * math.sin(TAU * cyc))
	-- the head, ears, mane, seal and tail trail the body, each a little later
	local function lag(d: number): number
		return TAU * (cyc - d)
	end
	pose.JointNeck = A(-0.18 + 0.1 * math.cos(lag(0.38)), 0.03 * math.sin(lag(0.15)))
	pose.JointHead = A(0.12 + 0.08 * math.cos(lag(0.45)), 0.03 * math.sin(lag(0.2)))
	pose.JointJaw = A(-0.2 - 0.08 * math.max(0, math.cos(lag(0.5))))
	pose.JointEarL, pose.JointEarR = A(0.65 + 0.12 * math.cos(lag(0.5))), A(0.65 + 0.12 * math.cos(lag(0.56)))
	pose.JointCrest = A(0.12 + 0.06 * math.cos(lag(0.5)))
	pose.JointTail = A(-0.08 + 0.12 * math.cos(lag(0.42)), 0.08 * math.sin(TAU * cyc * 0.5))
	pose.JointTail2 = A(0.05 + 0.14 * math.cos(lag(0.5)), 0.09 * math.sin(TAU * cyc * 0.5 - 0.7))
	pose.JointTail3 = A(0.35 + 0.16 * math.cos(lag(0.58)), 0.1 * math.sin(TAU * cyc * 0.5 - 1.4))
	pose = regalia(pose, 0.18 + 0.05 * math.cos(lag(0.5)), 0.14 * math.sin(lag(0.55)), 0.16 + 0.05 * math.cos(lag(0.5)))
	rig.plantLegs(pose, stance, false, reach)
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
	local running = gallop(seconds * TAU * 2.2, 50, 2.2)
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
local function ph(duration: number, keys: { any }, overlay: any?): Phase
	return { duration = duration, keys = keys, overlay = overlay }
end
local function hold(t: number, pose: Pose, plant: { string }, reach: any?, ease: string?): any
	return { t = t, pose = pose, plant = plant, reach = reach, ease = ease }
end

moves.Stagger = Wolf.moves.Stagger

-- Death: a long, weighty collapse (DEATH_SECONDS 2.6 for this family, see
-- EnemyAnimator). Keys come from the Spirit Wolf's fall (hit, mid-roll, overshoot,
-- rest) stretched out: a thrown-back hit held as the burst key (u 0.12-0.3), a
-- reeling sway while the legs give, then the roll, a bounce and the rest.
do
	local k = Wolf.moves.Death.active.keys
	local hit, mid, over, rest = k[2], k[3], k[4], k[5]
	-- the King's thicker flank rests 0.43 studs lower than the wolf's: lift the fall
	local function lift(pose: Pose, y: number): Pose
		return with(pose, { JointRoot = CFrame.new(0, y, 0) * (pose.JointRoot or I) })
	end
	mid = { pose = lift(mid.pose, 0.06) }
	over = { pose = lift(over.pose, 0.18) }
	rest = { pose = lift(rest.pose, 0.18) }
	moves.Death = { active = {
		duration = 2.6, mirror = true,
		keys = {
			{ t = 0, pose = STAND, plant = ALL },
			{ t = 0.1, pose = hit.pose, ease = "out", plant = ALL, reach = hit.reach },
			{ t = 0.3, pose = hit.pose, plant = ALL, reach = hit.reach },
			{ t = 0.62, pose = mid.pose, ease = "inOut" },
			{ t = 0.84, pose = over.pose, ease = "in" },
			{ t = 0.92, pose = rest.pose, ease = "out" },
			{ t = 1, pose = rest.pose },
		},
		overlay = function(u, secs, _)
			local sway = smooth(0.1, 0.3, u) * (1 - smooth(0.3, 0.6, u))
			return { JointRoot = R(0, 0, 0, 0.04 * sway * math.sin(secs * 5), 0.05 * sway * math.sin(secs * 3.3)),
				JointHead = A(0.06 * sway * math.sin(secs * 4)) }
		end,
	} }
end

-- Roar: an aggro / intimidation pose for the engage moment. EnemyAnimator has no
-- hook for it yet (no attribute names this beat), so it is authored but unplayed.
-- windup 1.0 (rear up, jaw wide: hold u 0.45-1 for the effect), active 0.1, recover 0.8.
do
	local rise = regalia(with(STAND, {
		JointRoot = R(-0.1, 0.28, 0.08), JointSpine = A(-0.12), JointNeck = A(0.45), JointHead = A(0.28), JointJaw = A(-0.85),
		JointLegFL = A(0.45, 0, -0.1), JointElbowFL = A(0.55), JointWristFL = A(-1.0),
		JointLegFR = A(0.55, 0, 0.1), JointElbowFR = A(0.6), JointWristFR = A(-1.1),
		JointEarL = A(0.5), JointEarR = A(0.5), JointCrest = A(-0.55), JointTail = A(-0.4), JointTail2 = A(-0.1),
	}), 0.6, -0.2, -0.1)
	moves.Roar = {
		windup = ph(1.0, { hold(0, STAND, ALL), hold(0.2, with(STAND, { JointNeck = A(-0.2), JointRoot = R(-0.12, -0.05) }), ALL, BRACED, "inOut"), hold(0.5, rise, HIND, REARED, "out"), hold(1, rise, HIND, REARED) }),
		active = ph(0.1, { hold(0, rise, HIND, REARED), hold(1, rise, HIND, REARED) }),
		recover = ph(0.8, { hold(0, rise, HIND, REARED), hold(0.45, SPENT, ALL, BRACED, "inOut"), hold(1, STAND, ALL, nil, "inOut") }),
	}
end

--------------------------------------------------------------------------------
-- KING'S LEAP, its follow-up rake and the skids (boss feel pass, 2026-10-22).
-- kingLeap (leap): a low coiled crouch (the server turns the root to the landing over
-- the windup), an explosive take-off, the body stretched long at the apex with the
-- forepaws reaching, then the paws reach down and touch. The slam resolves at
-- touchdown (end of the dash). On arrival the server starts kingRake (its windup opens
-- with the landing compression, then the left paw cocks wide and rakes across) or, when
-- the target is out of reach, the recover kingLeapSkid (land, brace, head leads the turn,
-- hind end swings out, short scrabble). kingsRushSkid is the same turn out of the rush.
-- No pose rotates the root: the server owns the yaw, the head and chest lead it through
-- the live input.targetYaw (EnemyAnimator passes it for every move in WolfKing.LEAD).

local LEAP_COIL = paws(-0.12, 0.6, 0.12, 0.12)
local LANDED = paws(-0.45, 0.35, 0.24, 0.2) -- splayed wide where the forepaws touched
local LEAP_SET = regalia(with(STAND, {
	JointRoot = R(-0.28, -0.08, 0.1), JointSpine = A(0.1),
	JointNeck = A(-0.3), JointHead = A(0.22), JointJaw = A(-0.12),
	JointEarL = A(0.2), JointEarR = A(0.2), JointCrest = A(-0.3),
	JointTail = A(0.3), JointTail2 = A(0.12), JointTail3 = A(0.1),
}), 0.2, 0.15, 0.1)
local LEAP_GATHER = regalia(with(LEAP_SET, {
	JointRoot = R(-0.4, -0.06, 0.14), JointSpine = A(0.03),
	JointNeck = A(-0.34), JointHead = A(0.3), JointJaw = A(-0.25),
	JointCrest = A(-0.35), JointTail = A(0.42), JointTail2 = A(0.2), JointTail3 = A(0.15),
}), 0.25, 0.2, 0.12)
-- the hind legs drive, still on the ground; the forelegs fold up off it
local LEAP_DRIVE = regalia(with(LEAP_GATHER, {
	JointRoot = R(0.05, 0.28, -0.05), JointSpine = A(-0.04),
	JointNeck = A(0.05), JointHead = A(0.1), JointJaw = A(-0.35),
	JointLegFL = A(0.7, 0, -0.25), JointElbowFL = A(-0.6), JointWristFL = A(-0.2),
	JointLegFR = A(0.7, 0, 0.25), JointElbowFR = A(-0.6), JointWristFR = A(-0.2),
	JointCrest = A(-0.1), JointTail = A(0.15), JointTail2 = A(0.05), JointTail3 = A(0.1),
}), 0.35, 0.32, -0.2)
-- off the ground: hind legs thrown out straight behind, forelegs tucked
local LEAP_OFF = regalia(with(LEAP_DRIVE, {
	JointRoot = R(0.3, 0.22), JointSpine = A(-0.06),
	JointNeck = A(0.08),
	JointLegFL = A(0.8, 0, -0.42), JointElbowFL = A(-0.4), JointWristFL = A(0.1),
	JointLegFR = A(0.8, 0, 0.42), JointElbowFR = A(-0.4), JointWristFR = A(0.1),
	JointLegBL = A(-1.0, 0, -0.06), JointKneeBL = A(-0.3), JointHockBL = A(-0.4),
	JointLegBR = A(-0.95, 0, 0.06), JointKneeBR = A(-0.3), JointHockBR = A(-0.4),
	JointTail = A(0.05), JointTail2 = A(-0.05), JointTail3 = A(0.15),
}), 0.5, 0.4, -0.3)
-- the apex: stretched long and level, forepaws reaching, jaw open, mane streaming back
local LEAP_APEX = regalia(with(LEAP_OFF, {
	JointRoot = R(0.3, 0.02), JointSpine = A(-0.08),
	JointNeck = A(0.1), JointHead = A(0.02), JointJaw = A(-0.55),
	JointEarL = A(0.3), JointEarR = A(0.3), JointCrest = A(-0.05),
	JointLegFL = A(0.95, 0, -0.3), JointElbowFL = A(0.2), JointWristFL = A(-0.3), -- with the manes flared wide, clear
	JointLegFR = A(0.92, 0, 0.3), JointElbowFR = A(0.2), JointWristFR = A(-0.3),
	JointLegBL = A(-1.0, 0, -0.06), JointKneeBL = A(-0.3), JointHockBL = A(-0.4),
	JointLegBR = A(-0.95, 0, 0.06), JointKneeBR = A(-0.3), JointHockBR = A(-0.4),
	JointTail = A(-0.05), JointTail2 = A(-0.05), JointTail3 = A(0.1),
}), 0.5, 0.35, -0.3)
-- the hang: the same stretch, the hind legs starting to come through
local LEAP_HANG = regalia(with(LEAP_APEX, {
	JointRoot = R(0.3, -0.04), JointNeck = A(0.1), JointHead = A(0.06), JointJaw = A(-0.6),
	JointLegFL = A(0.92, 0, -0.3), JointLegFR = A(0.9, 0, 0.3),
	JointLegBL = A(-0.8, 0, -0.06), JointKneeBL = A(-0.2), JointLegBR = A(-0.78, 0, 0.06), JointKneeBR = A(-0.2),
}), 0.5, 0.25, -0.3)
-- falling: nose down, head up on the target, forepaws reaching down, claws out, hind
-- legs under the body for the landing, tail up for balance, mane flaring forward
local LEAP_FALL = regalia(with(LEAP_HANG, {
	JointRoot = R(0.3, -0.24), JointSpine = A(0.02),
	JointNeck = A(0.12), JointHead = A(0.22), JointJaw = A(-0.75),
	JointCrest = A(-0.15), JointEarL = A(0.25), JointEarR = A(0.25),
	JointLegFL = A(0.72, 0, -0.1), JointElbowFL = A(0.1), JointWristFL = A(0.35),
	JointLegFR = A(0.72, 0, 0.1), JointElbowFR = A(0.1), JointWristFR = A(0.35),
	JointLegBL = A(0.25, 0, -0.06), JointKneeBL = A(-0.55), JointHockBL = A(0.25),
	JointLegBR = A(0.25, 0, 0.06), JointKneeBR = A(-0.55), JointHockBR = A(0.25),
	JointTail = A(-0.4), JointTail2 = A(-0.1), JointTail3 = A(0.2),
}), 0.25, -0.2, 0.05)
-- touchdown: the forepaws take the ground first (planted, so they meet Y 0 whatever
-- the arc is doing at the very end of the dash)
local LEAP_TOUCH = regalia(with(LEAP_FALL, {
	JointRoot = R(0.15, -0.1), JointNeck = A(-0.05), JointHead = A(0.25),
	JointLegBL = A(0.25, 0, -0.06), JointKneeBL = A(-0.4), JointHockBL = A(0.2),
	JointLegBR = A(0.25, 0, 0.06), JointKneeBR = A(-0.4), JointHockBR = A(0.2),
}), 0.3, -0.3, 0.05)
-- the landing compression: chest dropped onto bent forelegs, spine flexed, head held up
-- on the target, jaw open; mane and seal fling forward, the tail whips up
local LAND_CRUSH = regalia(with(STAND, {
	JointRoot = R(-0.4, -0.1, -0.05), JointSpine = A(0.12),
	JointNeck = A(-0.3), JointHead = A(0.3), JointJaw = A(-0.5),
	JointEarL = A(0.2), JointEarR = A(0.2), JointCrest = A(0),
	JointTail = A(-0.3), JointTail2 = A(0.15), JointTail3 = A(0.3),
}), 0.3, -0.35, 0.05)
local LAND_HOLD = regalia(with(LAND_CRUSH, {
	JointRoot = R(-0.34, -0.07, -0.03), JointNeck = A(-0.25), JointJaw = A(-0.35),
	JointTail = A(0.1), JointTail2 = A(0.15),
}), 0.25, 0.25, 0.1)

-- KingRake: up out of the crouch onto the right forepaw, the left paw cocked high and
-- wide with the chest twisted away (the 120-degree arc's start), then raked across.
local RAKE_COCK = regalia(with(LAND_HOLD, {
	JointRoot = R(-0.2, 0.05, 0.05, 0.04, -0.05), JointSpine = A(0, 0.26),
	JointNeck = A(-0.18, 0.2), JointHead = A(0.14, 0.05), JointJaw = A(-0.45),
	JointLegFL = A(1.28, 0.6, -0.7), JointElbowFL = A(1.05), JointWristFL = A(-1.6),
	JointEarL = A(0.25), JointEarR = A(0.25), JointCrest = A(-0.3),
	JointTail = A(-0.3, 0.15), JointTail2 = A(-0.05),
}), 0.6, -0.22, -0.3)
local RAKE_CONTACT = regalia(with(RAKE_COCK, {
	JointRoot = R(-0.16, -0.04, -0.1, -0.03, 0.04), JointSpine = A(0, -0.22),
	JointNeck = A(-0.2, -0.12), JointHead = A(0.08, -0.05), JointJaw = A(-0.3),
	JointLegFL = A(1.0, -0.25, -0.25), JointElbowFL = A(0.25), JointWristFL = A(-0.7),
	JointTail = A(-0.25, -0.2),
}), 0.6, -0.2, -0.3)
local RAKE_THROUGH = regalia(with(RAKE_CONTACT, {
	JointRoot = R(-0.2, -0.04, -0.06, -0.04, 0.05), JointSpine = A(0, -0.3),
	JointNeck = A(-0.24, -0.18), JointHead = A(0.05, -0.08),
	JointLegFL = A(0.5, -0.32, -0.1), JointElbowFL = A(-0.2), JointWristFL = A(-0.35),
	JointTail = A(-0.1, -0.3),
}), 0.4, 0.2, -0.1)
local RAKE_BRACE = paws(-0.35, 0.3, 0.14, 0.16)

-- Skids (authored for the target on the King's RIGHT; mirror plays the left): the
-- forepaws brace far ahead with the chest reared back against the slide, the hind end
-- swings out to the outside of the turn and scrabbles (one hind paw, the other, then
-- the inside forepaw steps round), and the body squares up as the server's yaw lands.
local SKID_BRAKE = regalia(with(SPENT, {
	JointRoot = R(-0.32, 0.1, 0.1, -0.03, -0.05), JointSpine = A(0.04),
	JointNeck = A(-0.05), JointHead = A(0.16), JointJaw = A(-0.35),
	JointEarL = A(0.3), JointEarR = A(0.3), JointCrest = A(0.1),
	JointTail = A(0.05, -0.45), JointTail2 = A(0.05, -0.3), JointTail3 = A(0.25, -0.2),
}), 0.4, 0.3, 0.1)
local SKID_SCRAB = regalia(with(SKID_BRAKE, {
	JointRoot = R(-0.28, 0.06, 0.06, -0.02, -0.06),
	JointLegBL = A(0.3, 0, -0.1), JointKneeBL = A(-1.2), JointHockBL = A(0.6), -- the King's big hind paw needs this fold to clear
	JointTail = A(0.1, -0.35), JointTail2 = A(0.05, -0.35),
}), 0.36, 0.2, 0.08)
local SKID_SCRAB2 = regalia(with(SKID_SCRAB, {
	JointRoot = R(-0.24, 0.04, 0.04, -0.01, -0.05),
	JointLegBR = A(0.3, 0, -0.1), JointKneeBR = A(-1.2), JointHockBR = A(0.6), -- the King's big hind paw needs this fold to clear
	JointTail = A(0.1, -0.2), JointTail2 = A(0.08, -0.25),
}), 0.3, 0.1, 0.06)
local SKID_STEP = regalia(with(SPENT, {
	JointRoot = R(-0.18, 0.02, 0, 0, -0.03), JointNeck = A(-0.12), JointHead = A(0.14), JointJaw = A(-0.2),
	JointLegFR = A(0.6, 0, 0.25), JointElbowFR = A(-1.1), JointWristFR = A(0.4),
	JointTail = A(0.15, -0.1),
}), 0.22, 0.05, 0.05)
local SKID_BRAKED = { FL = V(-0.05, 0, -0.5), FR = V(0.12, 0, -0.45), BL = V(-0.38, 0, 0.45), BR = V(-0.18, 0, 0.5) }
local SKID_SCRABBED = { FL = V(-0.04, 0, -0.42), FR = V(0.1, 0, -0.4), BL = V(-0.2, 0, 0.3), BR = V(-0.24, 0, 0.36) }
local SKID_SQUARED = { FL = V(-0.04, 0, -0.3), FR = V(0.12, 0, -0.25), BL = V(-0.12, 0, 0.22), BR = V(-0.1, 0, 0.2) }

-- the head leads a turn: chest, neck and head toward the target (live yaw, + left),
-- by `env`; manes swing out against the turn. `sign` -1 in the skids' authored
-- (target on the right) frame, which mirror flips, or the signed yaw (follow-ups).
local function leadOverlay(env: (number) -> number, signed: boolean)
	return function(u: number, _secs: number, input: Input): Pose
		local yaw = input.targetYaw
		local e = env(u)
		if yaw == nil then
			yaw = if signed then 0 else -1.3
		end
		local turn = if signed then math.clamp(yaw, -1.4, 1.4) else -math.min(math.abs(yaw), 1.4)
		local f = turn / 1.4 * e
		-- measured (qa_wolf_king_poses): a bigger neck or head share swings the inside
		-- mane into the crest and the inside ear into the mane, so the inside mane flares
		-- out, the crest lies flat and the head rolls away from the turn
		return {
			JointSpine = A(0, 0.22 * f), JointNeck = A(0, 0.3 * f), JointHead = A(0, 0.2 * f, -0.2 * f),
			JointManeL = A(0, 0, -0.5 * math.max(0, f)), JointManeR = A(0, 0, 0.5 * math.max(0, -f)),
			JointCrest = A(0.35 * math.abs(f)),
			JointTail = A(0, 0.2 * f), JointTail2 = A(0, 0.15 * f),
		}
	end
end

local function skidKeys(entry: { any }, brakeAt: number): { any }
	local keys = table.clone(entry)
	local s = (1 - brakeAt) / 0.88 -- the authored skid fills [brakeAt, 1]
	local function at(x: number): number
		return brakeAt + (x - 0.12) * s
	end
	table.insert(keys, hold(brakeAt, SKID_BRAKE, ALL, SKID_BRAKED, "out"))
	table.insert(keys, hold(at(0.3), SKID_SCRAB, { "FL", "FR", "BR" }, SKID_BRAKED, "inOut"))
	table.insert(keys, hold(at(0.44), SKID_SCRAB2, { "FL", "FR", "BL" }, SKID_SCRABBED, "inOut"))
	table.insert(keys, hold(at(0.6), SKID_STEP, { "FL", "BL", "BR" }, SKID_SCRABBED, "inOut"))
	table.insert(keys, hold(at(0.76), SPENT, ALL, SKID_SQUARED, "inOut"))
	table.insert(keys, hold(1, STAND, ALL, nil, "inOut"))
	return keys
end
local skidLead = leadOverlay(function(u) return smooth(0, 0.14, u) * (1 - smooth(0.7, 1, u)) end, false)

moves.KingLeap = {
	windup = ph(1.1, {
		hold(0, STAND, ALL), hold(0.2, LEAP_SET, ALL, LEAP_COIL, "out"),
		hold(0.62, LEAP_GATHER, ALL, LEAP_COIL, "inOut"), hold(1, LEAP_GATHER, ALL, LEAP_COIL),
	}, function(u, secs, _)
		-- the held coil trembles and the tail tip twitches; a last hip shimmy before launch
		local held = smooth(0.55, 0.65, u)
		local shimmy = Quadruped.bump(u, 0.78, 0.96) * math.sin(secs * TAU * 6)
		local tr = 0.012 * held * math.sin(secs * TAU * 11)
		return {
			JointRoot = R(tr, 0, 0, 0.03 * shimmy), JointSpine = A(0, -0.04 * shimmy),
			JointTail3 = A(0, 0.25 * held * math.sin(secs * TAU * 2.5)),
		}
	end),
	active = { duration = 0.7, air = true, keys = {
		hold(0, LEAP_GATHER, ALL, LEAP_COIL),
		hold(0.1, LEAP_DRIVE, HIND, LEAP_COIL, "out"),
		hold(0.2, LEAP_OFF, NONE, nil, "out"),
		hold(0.44, LEAP_APEX, NONE, nil, "out"),
		hold(0.62, LEAP_HANG, NONE, nil, "inOut"),
		hold(0.86, LEAP_FALL, NONE, nil, "inOut"),
		hold(1, LEAP_TOUCH, Quadruped.FRONT, paws(-0.6, 0.2, 0.2, 0.1), "in"),
	} },
	recover = ph(1.0, {
		hold(0, LEAP_TOUCH, Quadruped.FRONT, paws(-0.6, 0.2, 0.2, 0.1)),
		hold(0.08, LAND_CRUSH, ALL, LANDED, "out"), hold(0.3, LAND_HOLD, ALL, LANDED, "out"),
		hold(0.62, SPENT, ALL, BRACED, "inOut"), hold(1, STAND, ALL, nil, "inOut"),
	}),
}

moves.KingRake = {
	-- landing absorbed by u 0.16, held to 0.34 (eyes on the target, the head leading any
	-- turn the server makes), cocked by 0.68, held, raked at 0.97 (contact = end of windup)
	windup = ph(0.5, {
		hold(0, LEAP_TOUCH, ALL, LANDED),
		hold(0.16, LAND_CRUSH, ALL, LANDED, "out"), hold(0.34, LAND_HOLD, ALL, LANDED, "out"),
		hold(0.68, RAKE_COCK, SUPPORT_RIGHT, RAKE_BRACE, "out"), hold(0.86, RAKE_COCK, SUPPORT_RIGHT, RAKE_BRACE),
		hold(0.97, RAKE_CONTACT, SUPPORT_RIGHT, RAKE_BRACE, "in"), hold(1, RAKE_CONTACT, SUPPORT_RIGHT, RAKE_BRACE),
	}, leadOverlay(function(u) return smooth(0, 0.12, u) * (1 - smooth(0.55, 0.8, u)) end, true)),
	active = ph(0.14, {
		hold(0, RAKE_CONTACT, SUPPORT_RIGHT, RAKE_BRACE), hold(0.8, RAKE_THROUGH, SUPPORT_RIGHT, RAKE_BRACE, "out"),
		hold(1, RAKE_THROUGH, SUPPORT_RIGHT, RAKE_BRACE),
	}),
	recover = ph(0.9, {
		hold(0, RAKE_THROUGH, SUPPORT_RIGHT, RAKE_BRACE), hold(0.32, SPENT, ALL, BRACED, "out"),
		hold(0.6, SPENT, ALL, BRACED), hold(1, STAND, ALL, nil, "inOut"),
	}),
}

moves.KingLeapSkid = {
	recover = { duration = 1.0, mirror = true, overlay = skidLead, keys = skidKeys({
		hold(0, LEAP_TOUCH, Quadruped.FRONT, paws(-0.6, 0.2, 0.2, 0.1)),
		hold(0.08, LAND_CRUSH, ALL, LANDED, "out"),
	}, 0.22) },
}
moves.KingsRushSkid = {
	recover = { duration = 1.0, mirror = true, overlay = skidLead, keys = skidKeys({
		hold(0, RUSH_SKID, ALL, SKIDDED),
	}, 0.12) },
}

WolfKing.LEAD = { KingRake = true, KingLeapSkid = true, KingsRushSkid = true }

--------------------------------------------------------------------------------
-- VARIANTS. Every attack has 2-3 authored shapes with identical phase durations
-- (the defs own the timing): "A" is the original pass above, "B" and "C" are
-- alternates for comparison. Switch with WolfKing.VARIANT.<Move> = "B", or
-- WolfKing.setVariant("ClawDown", "C"), or WolfKing.setAll("B"). Default "A".
-- Contact stays at the END of windup in every variant.

local variants: { [string]: { [string]: { [string]: Phase } } } = {}
for _, name in { "RoyalBite", "KingsRush", "Crownfall", "PawSwipe", "ClawDown", "PackCall" } do
	variants[name] = { A = moves[name] }
end

-- RoyalBite B "Hammer": sit back on the haunches, jaw wide, then drop the whole
-- forebody onto the target with the forepaws reaching.
do
	local rear = regalia(with(BITE_REAR, {
		JointRoot = R(-0.05, 0.12, 0.1), JointSpine = A(-0.1), JointNeck = A(0.3), JointHead = A(0.2), JointJaw = A(-0.78),
	}), 0.45, -0.22, -0.1)
	local drop = regalia(with(BITE_CONTACT, {
		JointRoot = R(-0.1, -0.1, -0.1), JointSpine = A(0.08), JointNeck = A(-0.34), JointHead = A(-0.1),
	}), 0.4, -0.2, -0.08)
	local thru = regalia(with(drop, { JointRoot = R(-0.12, -0.12, -0.12), JointNeck = A(-0.34, -0.05) }), 0.18, 0.2, 0.14)
	local sit, lunge = paws(-0.05, 0.3, 0.08, 0.1), paws(-0.3, 0.2, 0.1, 0.1)
	variants.RoyalBite.B = {
		windup = ph(0.9, {
			hold(0, STAND, ALL), hold(0.4, rear, ALL, sit, "inOut"), hold(0.88, rear, ALL, sit),
			hold(0.985, drop, ALL, lunge, "in"), hold(1, drop, ALL, lunge),
		}),
		active = ph(0.16, { hold(0, drop, ALL, lunge), hold(0.7, thru, ALL, lunge, "out"), hold(1, thru, ALL, lunge) }),
		recover = ph(0.84, { hold(0, thru, ALL, lunge), hold(0.3, SPENT, ALL, BRACED, "out"), hold(0.6, SPENT, ALL, BRACED), hold(1, STAND, ALL, nil, "inOut") }),
	}
	-- C "Snap": head cocked to the left and held, then whipped across to the right.
	local cock = regalia(with(BITE_REAR, { JointRoot = R(0, 0.05, 0.1), JointNeck = A(0.2, 0.35), JointHead = A(0.12, 0.25), JointSpine = A(-0.05, 0.12) }), 0.38, -0.18, -0.08)
	local whip = regalia(with(BITE_CONTACT, { JointRoot = R(-0.12, -0.04, -0.12), JointNeck = A(-0.2, -0.35), JointHead = A(-0.05, -0.2), JointSpine = A(0.05, -0.12) }), 0.35, -0.18, -0.08)
	local whipThru = regalia(with(whip, { JointNeck = A(-0.26, -0.42), JointHead = A(0.02, -0.25) }), 0.18, 0.2, 0.14)
	variants.RoyalBite.C = {
		windup = ph(0.9, {
			hold(0, STAND, ALL), hold(0.3, cock, ALL, BRACED, "out"), hold(0.7, cock, ALL, BRACED, "inOut"),
			hold(0.9, with(cock, { JointJaw = A(-0.8) }), ALL, BRACED, "inOut"), hold(0.985, whip, ALL, BRACED, "in"), hold(1, whip, ALL, BRACED),
		}),
		active = ph(0.16, { hold(0, whip, ALL, BRACED), hold(0.6, whipThru, ALL, BRACED, "out"), hold(1, whipThru, ALL, BRACED) }),
		recover = ph(0.84, { hold(0, whipThru, ALL, BRACED), hold(0.25, SPENT, ALL, BRACED, "out"), hold(0.55, SPENT, ALL, BRACED), hold(1, STAND, ALL, nil, "inOut") }),
	}
end

-- PawSwipe B "Wide backhand": the left paw winds up high and far out, the body rolls
-- away from it, then the whole torso whips through. C "Stamp-cock": a quick lift,
-- a trembling held cock, then a late snap.
do
	local lift = regalia(with(SWIPE_LIFT, { JointRoot = R(-0.12, 0.04, 0.05, 0.03, -0.04), JointLegFL = A(1.05, 0.5, -0.6), JointSpine = A(0, 0.2) }), 0.3, -0.12, -0.05)
	local peak = regalia(with(lift, { JointRoot = R(-0.12, 0.05, 0.05, 0.04, -0.05), JointLegFL = A(1.3, 0.6, -0.7), JointElbowFL = A(1.05), JointWristFL = A(-1.6), JointSpine = A(0, 0.28), JointNeck = A(-0.16, 0.18) }), 0.38, -0.2, -0.08)
	local contact = regalia(with(SWIPE_CONTACT, { JointRoot = R(-0.12, -0.02, -0.1, -0.03, 0.04), JointSpine = A(0, -0.22), JointLegFL = A(1.0, -0.25, -0.25) }), 0.35, -0.2, -0.08)
	local thru = regalia(with(SWIPE_THROUGH, { JointRoot = R(-0.14, -0.02, -0.06, -0.04, 0.05), JointSpine = A(0, -0.26), JointLegFL = A(0.5, -0.3, -0.1) }), 0.16, 0.18, 0.12)
	variants.PawSwipe.B = {
		windup = ph(0.45, {
			hold(0, STAND, ALL), hold(0.4, lift, SUPPORT_RIGHT, BRACED, "inOut"), hold(0.72, peak, SUPPORT_RIGHT, BRACED, "out"),
			hold(0.97, contact, SUPPORT_RIGHT, BRACED, "in"), hold(1, contact, SUPPORT_RIGHT, BRACED),
		}),
		active = ph(0.12, { hold(0, contact, SUPPORT_RIGHT, BRACED), hold(0.8, thru, SUPPORT_RIGHT, BRACED, "out"), hold(1, thru, SUPPORT_RIGHT, BRACED) }),
		recover = ph(0.63, { hold(0, thru, SUPPORT_RIGHT, BRACED), hold(0.4, SPENT, ALL, BRACED, "out"), hold(0.65, SPENT, ALL, BRACED), hold(1, STAND, ALL, nil, "inOut") }),
	}
	local quick = regalia(with(SWIPE_LIFT, { JointLegFL = A(1.1, 0.3, -0.2), JointElbowFL = A(0.8), JointWristFL = A(-1.3) }), 0.3, -0.12, -0.05)
	variants.PawSwipe.C = {
		windup = ph(0.45, {
			hold(0, STAND, ALL), hold(0.14, quick, SUPPORT_RIGHT, BRACED, "out"), hold(0.2, SWIPE_PEAK, SUPPORT_RIGHT, BRACED, "out"),
			hold(0.9, SWIPE_PEAK, SUPPORT_RIGHT, BRACED), hold(0.99, SWIPE_CONTACT, SUPPORT_RIGHT, BRACED, "in"), hold(1, SWIPE_CONTACT, SUPPORT_RIGHT, BRACED),
		}, function(u, secs, _)
			local tr = 0.02 * math.sin(secs * TAU * 12) * smooth(0.25, 0.4, u) * (1 - smooth(0.85, 0.95, u))
			return { JointLegFL = A(tr, 0, tr), JointRoot = R(0, tr) }
		end),
		active = moves.PawSwipe.active,
		recover = moves.PawSwipe.recover,
	}
end

-- ClawDown B "Rear and chop": shoulders rise, head high, paw goes very high, then
-- the whole forebody chops down. C "Hook": the paw draws back behind the shoulder
-- (anticipation), then swings through an arc into the strike.
do
	local lift = regalia(with(CLAW_LIFT, { JointRoot = R(-0.08, 0.12, 0.03, 0, 0.05), JointNeck = A(0.05, 0.1), JointHead = A(0.1), JointLegFR = A(1.1, -0.1, 0.55), JointElbowFR = A(0.9), JointWristFR = A(-1.5) }), 0.28, -0.12, -0.05)
	local peak = regalia(with(lift, { JointRoot = R(-0.1, 0.18, 0.03, 0, 0.06), JointNeck = A(0.12, 0.12), JointLegFR = A(1.3, -0.1, 0.65), JointElbowFR = A(1.15), JointWristFR = A(-1.9) }), 0.34, -0.18, -0.08)
	variants.ClawDown.B = {
		windup = ph(0.55, {
			hold(0, STAND, ALL), hold(0.3, lift, SUPPORT_LEFT, BRACED, "inOut"), hold(0.6, peak, SUPPORT_LEFT, BRACED, "out"),
			hold(0.84, peak, SUPPORT_LEFT, BRACED), hold(0.97, CLAW_STRIKE, ALL, CLAW_CONTACT, "in"), hold(1, CLAW_STRIKE, ALL, CLAW_CONTACT),
		}),
		active = moves.ClawDown.active,
		recover = moves.ClawDown.recover,
	}
	local draw = regalia(with(CLAW_LIFT, { JointRoot = R(-0.12, -0.02, 0.03, 0.03, 0.04), JointLegFR = A(0.2, -0.1, 0.3), JointElbowFR = A(0.2), JointWristFR = A(-0.4), JointNeck = A(-0.28, 0.12) }), 0.25, -0.1, -0.05)
	local arc = regalia(with(CLAW_PEAK, { JointRoot = R(-0.1, 0.02, 0.03, -0.02, 0.04), JointLegFR = A(1.2, -0.1, 0.6) }), 0.3, -0.18, -0.08)
	variants.ClawDown.C = {
		windup = ph(0.55, {
			hold(0, STAND, ALL), hold(0.3, draw, SUPPORT_LEFT, BRACED, "inOut"), hold(0.5, draw, SUPPORT_LEFT, BRACED),
			hold(0.78, arc, SUPPORT_LEFT, BRACED, "out"), hold(0.97, CLAW_STRIKE, ALL, CLAW_CONTACT, "in"), hold(1, CLAW_STRIKE, ALL, CLAW_CONTACT),
		}),
		active = moves.ClawDown.active,
		recover = moves.ClawDown.recover,
	}
end

-- Crownfall B "Rear-up": a tall rise on the hind legs, forepaws tucked, then a
-- crashing drop. C "Slow coil": a long squat, a late rise and a fast slam.
do
	local up = regalia(with(CROWN_PEAK, { JointRoot = R(-0.1, 0.4, 0.1, 0.05), JointSpine = A(-0.2), JointNeck = A(0.1), JointHead = A(0.18), JointLegFL = A(1.0, 0.1, -0.55), JointElbowFL = A(1.2), JointWristFL = A(-2.0), JointLegFR = A(1.0, -0.1, 0.55), JointElbowFR = A(1.2), JointWristFR = A(-2.0) }), 0.55, -0.26, -0.12)
	local mid = regalia(with(up, { JointRoot = R(-0.06, 0.25, 0.14, 0.05), JointLegFL = A(1.1, 0.1, -0.5), JointLegFR = A(1.1, -0.1, 0.5) }), 0.48, -0.22, -0.08)
	variants.Crownfall.B = {
		windup = ph(1.25, {
			hold(0, STAND, ALL), hold(0.22, RUSH_LOAD, ALL, COILED, "out"), hold(0.45, mid, HIND, REARED, "inOut"), hold(0.78, up, HIND, REARED, "out"),
			hold(0.88, up, HIND, REARED), hold(0.985, CROWN_CONTACT, ALL, SPLAYED, "in"), hold(1, CROWN_CONTACT, ALL, SPLAYED),
		}),
		active = moves.Crownfall.active,
		recover = moves.Crownfall.recover,
	}
	local squat = regalia(with(RUSH_LOAD, { JointRoot = R(-0.3, -0.18, 0.06), JointNeck = A(-0.3), JointJaw = A(-0.3) }), 0.4, 0.1, 0.05)
	variants.Crownfall.C = {
		windup = ph(1.25, {
			hold(0, STAND, ALL), hold(0.35, squat, ALL, COILED, "inOut"), hold(0.62, squat, ALL, COILED),
			hold(0.82, CROWN_PEAK, HIND, REARED, "out"), hold(0.985, CROWN_CONTACT, ALL, SPLAYED, "in"), hold(1, CROWN_CONTACT, ALL, SPLAYED),
		}, function(u, secs, _)
			local tr = 0.025 * math.sin(secs * TAU * 8) * smooth(0.3, 0.4, u) * (1 - smooth(0.55, 0.62, u))
			return { JointRoot = R(0, tr) }
		end),
		active = moves.Crownfall.active,
		recover = moves.Crownfall.recover,
	}
end

-- KingsRush B "Pawing": scrapes the ground with alternating forepaws, then launches.
-- C "Head-low": lowers the head between the shoulders and trembles.
do
	local function paw(u: number, secs: number, _): Pose
		local k = smooth(0.2, 0.3, u) * (1 - smooth(0.75, 0.85, u))
		local a = 0.35 * k * math.max(0, math.sin(secs * TAU * 2.2))
		local b = 0.35 * k * math.max(0, -math.sin(secs * TAU * 2.2))
		return { JointLegFL = A(a), JointLegFR = A(b) }
	end
	variants.KingsRush.B = {
		windup = ph(1.0, {
			hold(0, STAND, ALL), hold(0.24, RUSH_LOAD, ALL, COILED, "out"), hold(0.8, RUSH_LOAD, ALL, COILED),
			hold(0.92, RUSH_READY, ALL, COILED, "inOut"), hold(1, RUSH_LAUNCH, HIND, COILED, "in"),
		}, paw),
		active = moves.KingsRush.active,
		recover = moves.KingsRush.recover,
	}
	local low = regalia(with(RUSH_LOAD, { JointNeck = A(-0.5), JointHead = A(0.3), JointJaw = A(-0.3), JointRoot = R(-0.42, -0.1, 0.1) }), 0.3, 0.2, 0.08)
	variants.KingsRush.C = {
		windup = ph(1.0, {
			hold(0, STAND, ALL), hold(0.3, low, ALL, COILED, "inOut"), hold(0.85, low, ALL, COILED),
			hold(0.94, RUSH_READY, ALL, COILED, "inOut"), hold(1, RUSH_LAUNCH, HIND, COILED, "in"),
		}, function(u, secs, _)
			local tr = 0.03 * math.sin(secs * TAU * 10) * smooth(0.3, 0.45, u) * (1 - smooth(0.8, 0.9, u))
			return { JointRoot = R(0, 0, 0, tr), JointNeck = A(0, tr) }
		end),
		active = moves.KingsRush.active,
		recover = moves.KingsRush.recover,
	}
end

-- PackCall B "Rear howl": forepaws lift, body sits back, head thrown up. C "Pulsed
-- howl": three throat pulses, jaw working.
do
	local rise = regalia(with(CALL_PEAK, { JointRoot = R(-0.14, 0.3, 0.1), JointSpine = A(-0.14), JointNeck = A(0.45), JointHead = A(0.3), JointLegFL = A(0.5, 0, -0.1), JointElbowFL = A(0.6), JointWristFL = A(-1.1), JointLegFR = A(0.5, 0, 0.1), JointElbowFR = A(0.6), JointWristFR = A(-1.1) }), 0.55, -0.18, -0.1)
	variants.PackCall.B = {
		windup = ph(1.2, { hold(0, STAND, ALL), hold(0.4, rise, HIND, REARED, "inOut"), hold(1, rise, HIND, REARED) }),
		active = ph(0.1, { hold(0, rise, HIND, REARED), hold(1, CALL_AFTER, ALL, BRACED, "out") }),
		recover = moves.PackCall.recover,
	}
	variants.PackCall.C = {
		windup = ph(1.2, { hold(0, STAND, ALL), hold(0.25, CALL_RISE, ALL, BRACED, "out"), hold(0.45, CALL_PEAK, ALL, BRACED, "inOut"), hold(1, CALL_PEAK, ALL, BRACED) },
			function(u, secs, _)
				local p = math.max(0, math.sin(secs * TAU * 1.25)) * smooth(0.3, 0.45, u)
				return { JointNeck = A(0.07 * p), JointJaw = A(-0.15 * p), JointManeL = A(0, 0, -0.1 * p), JointManeR = A(0, 0, 0.1 * p) }
			end),
		active = moves.PackCall.active,
		recover = moves.PackCall.recover,
	}
end

WolfKing.VARIANTS = variants
-- defaults: the boss-tier big windups (B) on the three big attacks and the howl
WolfKing.VARIANT = { RoyalBite = "B", KingsRush = "B", Crownfall = "B", PawSwipe = "A", ClawDown = "A", PackCall = "B" }
function WolfKing.setVariant(move: string, v: string)
	assert(variants[move] and variants[move][v], "no variant " .. move .. "." .. v)
	WolfKing.VARIANT[move] = v
end
function WolfKing.setAll(v: string)
	for move, list in variants do
		if list[v] then
			WolfKing.VARIANT[move] = v
		end
	end
end

-- Root weight (before planting, so the legs compress with it): a held windup
-- breathes and trembles, a crunch of anticipation loads just before contact, and
-- every impact dips the body and rebounds (Crownfall and the Rush skid hardest).
local DIP = { RoyalBite = 0.07, PawSwipe = 0.05, ClawDown = 0.08, Crownfall = 0.16, KingsRush = 0.1, PackCall = 0.03 }
local LOAD = { RoyalBite = 0.08, PawSwipe = 0.05, ClawDown = 0.07, Crownfall = 0.1, KingsRush = 0.0, PackCall = 0.0 }
local function weightOverlay(move: string, phase: string)
	return function(u: number, secs: number, _): Pose
		if phase == "windup" then
			local held = smooth(0.3, 0.5, u) * (1 - smooth(0.9, 1, u))
			local crunch = Quadruped.bump(u, 0.78, 0.99) * (LOAD[move] or 0)
			local y = -0.012 * held * (0.5 + 0.5 * math.sin(secs * 7)) - crunch
			return { JointRoot = R(y, 0.008 * held * math.sin(secs * 9 + 1) - crunch * 0.4, 0, 0.006 * held * math.sin(secs * 5.3), 0.008 * held * math.sin(secs * 4.1)) }
		end
		local tc = secs + (if phase == "recover" and move ~= "KingsRush" then (WolfKing.durations[move].active or 0) else 0)
		local k = DIP[move] or 0
		if phase == "active" and move == "KingsRush" then
			k = 0
		end
		local dip = k * math.exp(-4 * tc) * math.max(0, math.sin(tc * TAU * 2.0))
		return { JointRoot = R(-dip, -dip * 0.6) }
	end
end
local wrapped: { [any]: boolean } = {}
for move, list in variants do
	for _, phases in list do
		for name, phase in phases do
			if not wrapped[phase] then
				wrapped[phase] = true
				local extra, old = weightOverlay(move, name), phase.overlay
				phase.overlay = function(u, secs, input)
					local out = if old then old(u, secs, input) else {}
					local add = extra(u, secs, input)
					for j, cf in add do
						out[j] = (out[j] or I) * cf
					end
					return out
				end
			end
		end
	end
end

local samplers: { [string]: { [string]: any } } = {}
for move, list in variants do
	samplers[move] = {}
	for v, phases in list do
		samplers[move][v] = rig.sampler({ [move] = phases }, "WolfKing")
	end
end
local sampleStock = rig.sampler(moves, "WolfKing")
local function sampleKeyed(move: string, phase: string, u: number, input: Input?): Pose
	local list = samplers[move]
	if list then
		return list[WolfKing.VARIANT[move]](move, phase, u, input)
	end
	return sampleStock(move, phase, u, input)
end

-- OVERLAPPING ACTION. The head, jaw, ears, tail chain, manes and seal follow the
-- body late, each by its own lag (so the neck leads, the head trails, the tail
-- whips last), and ring down after a hit. The lag fades to zero at every phase
-- boundary so poses stay continuous, and contact is never late.
local LAG_SEC = 0.075
local LAGS = {
	JointNeck = 0.5, JointHead = 1, JointJaw = 1.3, JointEarL = 1.6, JointEarR = 2.1, JointCrest = 1.2,
	JointTail = 0.8, JointTail2 = 1.6, JointTail3 = 2.4, JointManeL = 1.4, JointManeR = 1.9, JointSeal = 2.6,
}
local SETTLE = { Roar = 0.4, RoyalBite = 1, PawSwipe = 0.8, ClawDown = 1, Crownfall = 1.5, KingsRush = 0.8, Stagger = 1.3, PackCall = 0.3,
	KingLeap = 1.5, KingRake = 1, KingLeapSkid = 1.2, KingsRushSkid = 0.8 }
-- moves whose WINDUP opens on an impact (the rake starts at the leap's touchdown) ring too
local SETTLE_WINDUP = { KingRake = 1.4 }

local function secondary(pose: Pose, move: string, phase: string, u: number, input: Input?)
	local dur = (input and input.duration) or WolfKing.durations[move][phase] or 0.5
	local secs = u * dur
	local fade = if move == "Death" then smooth(0, 0.2, u) else smooth(0, 0.2, u) * (1 - smooth(0.8, 1, u))
	if move == "KingsRush" and phase == "active" then
		return
	end
	if fade > 0.01 then
		local lagged = sampleKeyed(move, phase, math.clamp(u - LAG_SEC * fade / dur, 0, 1), input)
		for name, k in LAGS do
			local lag = sampleKeyed(move, phase, math.clamp(u - LAG_SEC * k * fade / dur, 0, 1), input)
			pose[name] = lag[name] or lagged[name] or pose[name]
		end
	end
	local held = if phase == "windup" then smooth(0.3, 0.5, u) * (1 - smooth(0.92, 1, u)) else 0
	if held > 0 then
		pose.JointNeck = (pose.JointNeck or I) * A(0, 0.012 * held * math.sin(secs * 6.1))
		pose.JointHead = (pose.JointHead or I) * A(0.015 * held * math.sin(secs * 8.3 + 1))
		pose.JointTail = (pose.JointTail or I) * A(0, 0.035 * held * math.sin(secs * 3.1))
		pose.JointTail2 = (pose.JointTail2 or I) * A(0, 0.04 * held * math.sin(secs * 3.1 - 0.7))
		pose.JointEarL = (pose.JointEarL or I) * A(0.05 * held * math.sin(secs * 11))
		pose.JointEarR = (pose.JointEarR or I) * A(0.05 * held * math.sin(secs * 9.3 + 2))
		pose.JointManeL = (pose.JointManeL or I) * A(0, 0, 0.03 * held * math.sin(secs * 4.4))
		pose.JointManeR = (pose.JointManeR or I) * A(0, 0, -0.03 * held * math.sin(secs * 3.7 + 1))
	end
	-- the raised paw sweeps through its own side's mane blades: fold that mane in
	-- while the paw is up (windup after 0.15, through the follow-through, eased out
	-- over the recover)
	local up = if phase == "windup" then smooth(0.1, 0.35, u) elseif phase == "active" then 1 else 1 - smooth(0, 0.5, u)
	if move == "PawSwipe" or move == "Crownfall" then
		pose.JointManeL = (pose.JointManeL or I):Lerp(A(0, 0, 0.1), up)
	end
	if move == "ClawDown" or move == "Crownfall" then
		pose.JointManeR = (pose.JointManeR or I):Lerp(A(0, 0, -0.1), up)
	end
	local amp = if phase == "windup" then SETTLE_WINDUP[move] else SETTLE[move]
	if amp then
		local tc = secs + (if phase == "recover" and move ~= "KingsRush" then (WolfKing.durations[move].active or 0) else 0)
		local function ring(delay: number, hz: number): number
			local t = math.max(0, tc - delay)
			return math.sin(t * TAU * hz) * math.exp(-4.5 * t) * amp
		end
		pose.JointNeck = (pose.JointNeck or I) * A(-0.09 * ring(0.02, 3.0), 0.04 * ring(0.05, 2.3))
		pose.JointHead = (pose.JointHead or I) * A(-0.15 * ring(0.05, 3.2))
		pose.JointJaw = (pose.JointJaw or I) * A(-0.1 * math.max(0, ring(0.06, 3.5)))
		pose.JointTail = (pose.JointTail or I) * A(0.18 * ring(0.08, 2.6), 0.14 * ring(0.1, 1.9))
		pose.JointTail2 = (pose.JointTail2 or I) * A(0.2 * ring(0.14, 2.6), -0.18 * ring(0.16, 1.9))
		pose.JointTail3 = (pose.JointTail3 or I) * A(0.22 * ring(0.2, 2.6), 0.22 * ring(0.22, 1.9))
		pose.JointEarL = (pose.JointEarL or I) * A(0.3 * ring(0.08, 4.2))
		pose.JointEarR = (pose.JointEarR or I) * A(0.3 * ring(0.12, 3.8))
		pose.JointManeL = (pose.JointManeL or I) * A(0, 0, 0.14 * ring(0.1, 2.9))
		pose.JointManeR = (pose.JointManeR or I) * A(0, 0, -0.12 * ring(0.15, 2.5))
		pose.JointSeal = (pose.JointSeal or I) * A(0.2 * ring(0.18, 2.4))
	end
end

function WolfKing.sample(move: string, phase: string, u: number, input: Input?): Pose
	local pose = sampleKeyed(move, phase, u, input)
	u = math.clamp(u, 0, 1)
	secondary(pose, move, phase, u, input)
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
		return TAU * gallopRate(speed) -- real cycles/s (heavy bounds), not body-scaled
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
