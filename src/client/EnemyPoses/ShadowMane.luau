--!strict
-- Shadow Mane Wolf B: the wolf-family skeleton (26 motors, see art/enemies/wolf_family/RIGS.md)
-- as a low, quick flanker. Same pose API as Wolf.luau (sample / loops / gaitRate / scaled /
-- plant / moves / durations / JOINTS); no instances and no gameplay decisions live here.
--
-- UNIT SPACE: pivots, root translations and paw offsets are in studs at the unscaled body (the
-- template's studs / 1.63: hip 2.82, wrist 0.37). EnemyAnimator applies 1.63 ONCE after
-- sampling (`scaled`, the root translation only). Rotations are scale-free. Poses are authored
-- in body-fractions (about studs / 1.63 / 1.63 for translations); R() and paws() multiply the
-- authored numbers by K = 1.63 into unit studs.
--
-- Move names for the EnemyAnimator FAMILIES entry (ShadowManeWolfB, scale 1.63, runFrom 8,
-- keyedBlend 0.06, deathSeconds 0.7). Attack name -> move; windup / active / pose recover:
--   shadowStep      ShadowStep      0.70 / 0.30 (the dash, ~14 studs) / 0.90
--   shadowRake      ShadowRake      0.40 / 0.10 / 0.90   mirror (side), LEAD: opens on the arrival
--   shadowStepSkid  ShadowStepSkid  recover 0.90          mirror, LEAD (head leads input.targetYaw)
--   maneRend        ManeRend        0.60 / 0.12 / 1.00   mirror; LEFT rake at the end of windup,
--                                   RIGHT rake 0.35 s later = recover u 0.23 (contact), then settles
--   maneLash        ManeLash        0.80 / 0.15 / 1.10
--   hop             Hop             active 0.30 (air; the fade back)
--   Stagger 0.28 (snaps in by u 0.2), Death 0.70 then hold u = 1 (mirror, side = killer side).
-- Loops: idle (low prowl), walk (a stalk that firms into a trot above ~5 studs/s), run (a flat
-- rotary gallop, faster legs than the King), circle (a wide crab-trot, ~7 studs/s).
-- Contact is the END of every windup (damage and strike VFX resolve there); the active pose is
-- the follow-through. The held beat of every windup is u 0.5-0.9 with eyes on the target.
-- input.targetYaw / input.side feed the LEAD overlay (ShadowRake, ShadowStepSkid).
--
-- SECONDARY MOTION. The mane (JointMane), the neck strands (JointManeL/R), the forelock, ears,
-- jaw and the three tail links follow the body late, each by its own tier of lag (`secondary`),
-- and ring down after every strike. The lag fades to zero at each phase boundary, so poses stay
-- continuous and contact is never late.
-- Fur axes: JointMane -X lifts it, +X streams it back; ManeL -Z flares up and out, ManeR +Z;
-- JointForelock -X lifts it.

local Quadruped = require(script.Parent.Quadruped)
local Wolf = require(script.Parent.Wolf)

export type Pose = Quadruped.Pose
export type Input = Quadruped.Input
type Phase = Quadruped.Phase
type Leg = Quadruped.Leg
type Step = Quadruped.Step

local ShadowMane = {}
ShadowMane.SCALE = 1.63

local V = Vector3.new
local I, TAU = CFrame.identity, Quadruped.TAU
local A = Quadruped.A
local K = 1.63 -- unit space is the pivots in studs at the Spirit Wolf size; poses were authored in body-fractions
local function R(y: number, pitch: number?, z: number?, yaw: number?, roll: number?): CFrame
	return Quadruped.R(y * K, pitch, (z or 0) * K, yaw, roll)
end
local function paws(fz: number, hz: number, fx: number?, hx: number?)
	return Quadruped.paws(fz * K, hz * K, (fx or 0) * K, (hx or 0) * K)
end
local with, smooth, bump = Quadruped.with, Quadruped.smooth, Quadruped.bump
local ALL, HIND, FRONT, NONE = Quadruped.ALL, Quadruped.HIND, Quadruped.FRONT, Quadruped.NONE
local SUPPORT_RIGHT = { "FR", "BL", "BR" } -- the LEFT paw attacks
local SUPPORT_LEFT = { "FL", "BL", "BR" } -- the RIGHT paw attacks

ShadowMane.JOINTS = {}
for _, name in Wolf.JOINTS do
	if name ~= "JointCrest" then
		table.insert(ShadowMane.JOINTS, name)
	end
end
for _, name in { "JointMane", "JointManeL", "JointManeR", "JointForelock" } do
	table.insert(ShadowMane.JOINTS, name)
end

-- The body's own pivots (the template, unit space = studs / 1.63). Its legs are the wolf's
-- shape but shorter and set further forward.
local P = {
	JointRoot = V(0, 3.278, 1.84), JointSpine = V(0, 3.451, 0.919),
	JointLegFL = V(-0.805, 2.818, -1.495), JointElbowFL = V(-0.828, 1.552, -1.438), JointWristFL = V(-0.828, 0.368, -1.552),
	JointLegFR = V(0.805, 2.818, -1.495), JointElbowFR = V(0.828, 1.552, -1.438), JointWristFR = V(0.828, 0.368, -1.552),
	JointLegBL = V(-0.805, 2.875, 2.416), JointKneeBL = V(-0.862, 1.552, 2.07), JointHockBL = V(-0.862, 0.712, 2.645),
	JointLegBR = V(0.805, 2.875, 2.416), JointKneeBR = V(0.862, 1.552, 2.07), JointHockBR = V(0.862, 0.712, 2.645),
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
		-- measured on the template's paw geometry (claws included): the toes run about a unit
		-- ahead of the wrist and hock pivots
		front = { V(-0.32, -0.367, -0.976), V(0.32, -0.367, -0.976), V(-0.32, -0.367, 0.195), V(0.32, -0.367, 0.195) },
		hind = { V(-0.3, -0.712, -1.068), V(0.3, -0.712, -1.068), V(-0.3, -0.712, 0.029), V(0.3, -0.712, 0.029) },
	},
	curl = { front = -1.0, hind = -0.6 },
})
ShadowMane.rig = rig

-- fur: the mane, the neck strands' spread (and fore-aft pitch), the forelock, a side sway
local function fur(pose: Pose, mane: number, spread: number, fore: number, pitch: number?, sway: number?): Pose
	-- strands laid forward or down swing into the shoulders and forelock: keep them at least this far back
	local p, s = math.max(pitch or 0, 0.3), sway or 0
	return with(pose, {
		JointMane = A(mane, s * 0.5),
		JointManeL = A(p, s, -spread), JointManeR = A(p, s, spread),
		JointForelock = A(fore, s * 0.4),
	})
end

--------------------------------------------------------------------------------
-- Poses. STAND is the low prowl: shoulders slung, the head carried below the withers with
-- the eyes up, the mane laid along the back, the tail brush trailing.

local COIL = paws(-0.25, 0.5, 0.05, 0.06) -- fore paws ahead, hind paws back: the legs open
local LOW = paws(-0.12, 0.3, 0.03, 0.04)
local BRACED = paws(-0.3, 0.2, 0.08, 0.08)
local SKIDDED = paws(-0.45, 0.4, 0.14, 0.12)
local SPLAYED = paws(-0.3, 0.25, 0.2, 0.16)

local STAND: Pose = fur({
	JointRoot = R(-0.12, -0.03), JointSpine = A(0.03),
	JointNeck = A(-0.24), JointHead = A(0.18), JointJaw = A(-0.03),
	JointEarL = A(0.25), JointEarR = A(0.25),
	JointTail = A(0.1), JointTail2 = A(0.08), JointTail3 = A(0.1),
}, 0.15, 0.06, 0.12, 0.05)

local SPENT: Pose = fur(with(STAND, {
	JointRoot = R(-0.2, -0.06), JointNeck = A(-0.3), JointHead = A(0.14), JointJaw = A(-0.14),
	JointEarL = A(0.4), JointEarR = A(0.4), JointTail = A(0.2), JointTail2 = A(0.15),
}), 0.1, 0.02, 0.08, 0.1)

-- SHADOW STEP. The user's windup is the hold: root -0.45 studs (-0.276 unit), spine +0.08,
-- neck -0.3, head +0.25, jaw -0.3, ears +0.5, tail -0.25 / -0.15 / +0.2. The legs are solved
-- (planted), so the haunches load by the same compression. The mane is laid flat on top of it.
local SS_DIP: Pose = fur(with(STAND, {
	JointRoot = R(-0.22, -0.05), JointSpine = A(0.05), JointNeck = A(-0.3), JointHead = A(0.2), JointJaw = A(-0.12),
	JointEarL = A(0.4), JointEarR = A(0.4), JointTail = A(0.02), JointTail2 = A(0.0), JointTail3 = A(0.1),
}), 0.3, 0.0, 0.2, 0.1)
local SS_LOAD: Pose = fur(with(STAND, {
	JointRoot = R(-0.3, 0), JointSpine = A(0.08), JointNeck = A(-0.3), JointHead = A(0.25), JointJaw = A(-0.3),
	JointEarL = A(0.5), JointEarR = A(0.5), JointTail = A(-0.25), JointTail2 = A(-0.15), JointTail3 = A(0.2),
}), 0.45, -0.05, 0.25, 0.15)
local SS_SPRING: Pose = fur(with(SS_LOAD, {
	JointRoot = R(-0.36, -0.07, 0.1), JointSpine = A(0.1), JointNeck = A(-0.36), JointHead = A(0.3), JointJaw = A(-0.4),
	JointEarL = A(0.5), JointEarR = A(0.5), JointTail = A(-0.35), JointTail2 = A(-0.2),
}), 0.6, -0.08, 0.35, 0.25)
local SS_PUSH: Pose = fur(with(SS_SPRING, {
	JointRoot = R(-0.14, 0.1, 0.1), JointSpine = A(-0.04), JointNeck = A(-0.12), JointHead = A(0.12), JointJaw = A(-0.4),
	JointLegFL = A(0.75, 0, -0.1), JointElbowFL = A(0.55), JointWristFL = A(-0.3),
	JointLegFR = A(0.75, 0, 0.1), JointElbowFR = A(0.55), JointWristFR = A(-0.3),
	JointTail = A(-0.15), JointTail2 = A(-0.05),
}), 0.8, 0.3, 0.6, 0.45)
local SS_STRETCH: Pose = fur(with(SS_PUSH, {
	JointRoot = R(-0.02, 0.02), JointSpine = A(-0.06), JointNeck = A(-0.1), JointHead = A(0.04), JointJaw = A(-0.5),
	JointEarL = A(0.5), JointEarR = A(0.5),
	JointLegFL = A(0.7, 0, -0.14), JointElbowFL = A(-0.15), JointWristFL = A(-0.1),
	JointLegFR = A(0.68, 0, 0.14), JointElbowFR = A(-0.15), JointWristFR = A(-0.1),
	JointLegBL = A(-0.3, 0, -0.06), JointKneeBL = A(-0.9), JointHockBL = A(0.5),
	JointLegBR = A(-0.28, 0, 0.06), JointKneeBR = A(-0.9), JointHockBR = A(0.5),
	JointTail = A(-0.2), JointTail2 = A(-0.05), JointTail3 = A(0.05),
}), 1.0, 0.5, 0.9, 0.65)
local SS_TUCK: Pose = fur(with(SS_STRETCH, {
	JointRoot = R(-0.04, 0.0), JointSpine = A(0.06), JointJaw = A(-0.4),
	JointLegFL = A(0.4, 0, -0.1), JointElbowFL = A(-0.9), JointWristFL = A(0.3),
	JointLegFR = A(0.38, 0, 0.1), JointElbowFR = A(-0.9), JointWristFR = A(0.3),
	JointLegBL = A(0.0, 0, -0.06), JointKneeBL = A(-0.8), JointHockBL = A(0.5),
	JointLegBR = A(0.0, 0, 0.06), JointKneeBR = A(-0.8), JointHockBR = A(0.5),
}), 0.9, 0.4, 0.8, 0.5)
-- arriving: the forepaws reach down and ahead, the chest low, head up on the prey, the mane
-- still carrying forward
local SS_REACH: Pose = fur(with(SS_TUCK, {
	JointRoot = R(-0.16, 0.04), JointSpine = A(0.08), JointNeck = A(-0.28), JointHead = A(0.26), JointJaw = A(-0.45),
	JointLegFL = A(0.35, 0, -0.12), JointElbowFL = A(0.6), JointWristFL = A(-0.3),
	JointLegFR = A(0.35, 0, 0.12), JointElbowFR = A(0.6), JointWristFR = A(-0.3),
	JointLegBL = A(0.05, 0, -0.06), JointKneeBL = A(-0.8), JointHockBL = A(0.45),
	JointLegBR = A(0.05, 0, 0.06), JointKneeBR = A(-0.8), JointHockBR = A(0.45),
	JointTail = A(-0.3), JointTail2 = A(-0.1),
}), 0.35, 0.25, 0.4, 0.2)

-- SHADOW RAKE. The landing compresses onto the forepaws, the head locked on the target; the
-- chest then turns away and the left paw cocks wide, and rakes across with the mane thrown
-- forward over it. Turn during the anticipation, never after landing.
local RK_LAND: Pose = fur(with(STAND, {
	JointRoot = R(-0.34, -0.1, -0.02), JointSpine = A(0.1), JointNeck = A(-0.3), JointHead = A(0.28), JointJaw = A(-0.4),
	JointEarL = A(0.5), JointEarR = A(0.5), JointTail = A(-0.3), JointTail2 = A(0.05), JointTail3 = A(0.25),
}), 0.1, 0.2, 0.25, 0.1)
local RK_HOLD: Pose = fur(with(RK_LAND, {
	JointRoot = R(-0.3, -0.08), JointNeck = A(-0.26), JointJaw = A(-0.3), JointTail = A(0.05),
}), 0.2, 0.15, 0.2, 0.1)
local RK_COCK: Pose = fur(with(RK_HOLD, {
	JointRoot = R(-0.2, 0.05, 0.05, 0.04, -0.05), JointSpine = A(0, 0.26),
	JointNeck = A(-0.2, 0.2), JointHead = A(0.16, 0.05), JointJaw = A(-0.45),
	JointLegFL = A(1.2, 0.55, -0.65), JointElbowFL = A(0.95), JointWristFL = A(-1.5),
	JointTail = A(-0.3, 0.15), JointTail2 = A(-0.05),
}), -0.35, 0.28, -0.3, 0.3)
local RK_CONTACT: Pose = fur(with(RK_COCK, {
	JointRoot = R(-0.16, -0.04, -0.1, -0.03, 0.04), JointSpine = A(0, -0.22),
	JointNeck = A(-0.22, -0.12), JointHead = A(0.1, -0.05), JointJaw = A(-0.3),
	JointLegFL = A(0.98, -0.25, -0.25), JointElbowFL = A(0.25), JointWristFL = A(-0.7),
	JointTail = A(-0.25, -0.2),
}), -0.45, 0.25, -0.4, 0.3)
local RK_THROUGH: Pose = fur(with(RK_CONTACT, {
	JointRoot = R(-0.2, -0.05, -0.06, -0.04, 0.05), JointSpine = A(0, -0.3),
	JointNeck = A(-0.26, -0.18), JointHead = A(0.06, -0.08),
	JointLegFL = A(0.7, -0.32, -0.1), JointElbowFL = A(0.15), JointWristFL = A(-0.4),
	JointTail = A(-0.1, -0.3),
}), 0.1, 0.15, 0.0, 0.15)
local RK_BRACE = paws(-0.3, 0.25, 0.06, 0.12)

-- MANE REND: two rakes, left then right. The first paw rears with the mane lifted (the chest
-- rises on the planted hind end), strikes at the end of the windup; the weight swaps onto it
-- as the second paw is already up; the second strikes 0.35 s after the first.
local RD_LIFT: Pose = fur(with(STAND, {
	JointRoot = R(-0.2, 0.04, 0.04, 0.02, -0.04), JointSpine = A(0, 0.1),
	JointNeck = A(-0.2, -0.06), JointHead = A(0.14, -0.05), JointJaw = A(-0.2),
	JointLegFL = A(0.9, 0.25, -0.5), JointElbowFL = A(0.55), JointWristFL = A(-1.0),
	JointEarL = A(0.4), JointEarR = A(0.4), JointTail = A(-0.2, 0.1),
}), -0.3, 0.2, -0.15, 0.3)
local RD_PEAK: Pose = fur(with(RD_LIFT, {
	JointRoot = R(-0.2, 0.12, 0.08, 0.04, -0.05), JointSpine = A(-0.05, 0.14), JointNeck = A(-0.1, 0.1), JointHead = A(0.2),
	JointLegFL = A(1.22, 0.45, -0.6), JointElbowFL = A(0.95), JointWristFL = A(-1.5),
	JointTail = A(-0.3, 0.1),
}), -0.65, 0.28, -0.35, 0.3)
local RD_L_CONTACT: Pose = fur(with(RD_PEAK, {
	JointRoot = R(-0.18, -0.02, -0.08, -0.04, 0.05), JointSpine = A(0.04, -0.14),
	JointNeck = A(-0.2, 0.1), JointHead = A(0.1, 0.06), JointJaw = A(-0.3),
	JointLegFL = A(1.0, -0.25, -0.25), JointElbowFL = A(0.25), JointWristFL = A(-0.7),
}), -0.5, 0.25, -0.4, 0.3)
local RD_L_THROUGH: Pose = fur(with(RD_L_CONTACT, {
	JointRoot = R(-0.22, -0.04, -0.06, -0.05, 0.06), JointSpine = A(0.04, -0.2),
	JointLegFL = A(0.55, -0.3, -0.1), JointElbowFL = A(-0.2), JointWristFL = A(-0.35),
}), 0.0, 0.25, 0.0, 0.1)
-- the second paw, authored as the mirror of the first
local RD_R_COCK: Pose = Quadruped.mirrorPose(fur(with(RD_PEAK, {
	JointRoot = R(-0.24, 0.0, 0.0, -0.02, 0.04), JointSpine = A(0, 0.16),
	JointLegFL = A(1.1, 0.4, -0.5), JointElbowFL = A(0.8), JointWristFL = A(-1.3),
}), -0.5, 0.5, -0.3, -0.1))
local RD_R_CONTACT: Pose = Quadruped.mirrorPose(RD_L_CONTACT)
local RD_R_THROUGH: Pose = Quadruped.mirrorPose(RD_L_THROUGH)

-- MANE LASH: the front rises (the planted hind paws and forepaws stay put), the neck arches
-- and the whole mane opens wide and high; a held beat; a wind-back to the left; then the body
-- twists right and the mane whips round with it; the recover is a wave through the fur.
local LS_REAR: Pose = fur(with(STAND, {
	JointRoot = R(-0.12, 0.1, 0.06), JointSpine = A(-0.08), JointNeck = A(0.0), JointHead = A(0.14), JointJaw = A(-0.3),
	JointEarL = A(0.45), JointEarR = A(0.45), JointTail = A(-0.2), JointTail2 = A(-0.05), JointTail3 = A(0.15),
}), -0.45, 0.6, -0.4, -0.05)
local LS_PEAK: Pose = fur(with(LS_REAR, {
	JointRoot = R(-0.1, 0.15, 0.1), JointSpine = A(-0.14), JointNeck = A(0.12), JointHead = A(0.2), JointJaw = A(-0.55),
	JointTail = A(-0.35), JointTail2 = A(-0.1),
}), -0.85, 1.0, -0.7, -0.15)
local LS_WIND: Pose = fur(with(LS_PEAK, {
	JointRoot = R(-0.14, 0.12, 0.08, 0.1, 0.06), JointSpine = A(-0.1, 0.34), JointNeck = A(0.06, 0.28), JointHead = A(0.16, 0.12),
	JointTail = A(-0.3, -0.25),
	JointLegFL = A(-0.05), JointElbowFL = A(0.85), JointWristFL = A(-0.3),
	JointLegFR = A(-0.05), JointElbowFR = A(0.85), JointWristFR = A(-0.3),
}), -0.85, 1.05, -0.7, -0.2, 0.3)
local LS_WHIP: Pose = fur(with(LS_PEAK, {
	JointRoot = R(-0.22, 0.02, -0.04, -0.12, -0.06), JointSpine = A(0, -0.42), JointNeck = A(-0.12, -0.3), JointHead = A(0.1, -0.15),
	JointJaw = A(-0.4), JointTail = A(-0.2, 0.3), JointTail2 = A(-0.05, 0.3),
	JointLegFL = A(-0.05), JointElbowFL = A(0.85), JointWristFL = A(-0.3),
	JointLegFR = A(-0.05), JointElbowFR = A(0.85), JointWristFR = A(-0.3),
}), -0.2, 0.6, -0.2, 0.55, -0.5)
local LS_THROUGH: Pose = fur(with(LS_WHIP, {
	JointRoot = R(-0.24, 0.0, -0.05, -0.16, -0.04), JointSpine = A(0.02, -0.5), JointNeck = A(-0.18, -0.34),
	JointTail = A(-0.1, 0.45), JointTail2 = A(0, 0.4),
}), 0.35, 0.3, 0.2, 0.6, -0.75)
local LS_SETTLE: Pose = fur(with(SPENT, { JointSpine = A(0, -0.12), JointNeck = A(-0.28, -0.1) }), 0.1, 0.1, 0.05, 0.2)

-- HOP (the fade back): a low backward bound with the head on the target and the mane trailing
-- forward (it lags the body's travel).
local HP_CROUCH: Pose = fur(with(STAND, {
	JointRoot = R(-0.3, 0.03, 0.05), JointSpine = A(0.06), JointNeck = A(-0.26), JointHead = A(0.22), JointJaw = A(-0.2),
	JointEarL = A(0.5), JointEarR = A(0.5), JointTail = A(-0.1), JointTail2 = A(0.0),
}), 0.35, 0.05, 0.2, 0.1)
local HP_PUSH: Pose = fur(with(HP_CROUCH, {
	JointRoot = R(-0.16, 0.14, 0.05),
	JointLegFL = A(0.55, 0, -0.1), JointElbowFL = A(0.45), JointWristFL = A(-0.3),
	JointLegFR = A(0.55, 0, 0.1), JointElbowFR = A(0.45), JointWristFR = A(-0.3),
	JointLegBL = A(-0.3, 0, -0.04), JointKneeBL = A(-0.25), JointHockBL = A(0.2),
	JointLegBR = A(-0.3, 0, 0.04), JointKneeBR = A(-0.25), JointHockBR = A(0.2),
	JointTail = A(-0.3),
}), -0.3, 0.3, -0.25, -0.1)
local HP_HANG: Pose = fur(with(HP_PUSH, {
	JointRoot = R(-0.18, 0.1), JointSpine = A(0.03),
	JointLegFL = A(0.55, 0, -0.1), JointElbowFL = A(-0.9), JointWristFL = A(0.2),
	JointLegFR = A(0.55, 0, 0.1), JointElbowFR = A(-0.9), JointWristFR = A(0.2),
	JointLegBL = A(0.2, 0, -0.04), JointKneeBL = A(-0.8), JointHockBL = A(0.4),
	JointLegBR = A(0.2, 0, 0.04), JointKneeBR = A(-0.8), JointHockBR = A(0.4),
	JointJaw = A(-0.35), JointTail = A(-0.2),
}), -0.55, 0.5, -0.5, -0.2)
local HP_REACH: Pose = fur(with(HP_HANG, {
	JointRoot = R(-0.2, 0.0),
	JointLegFL = A(0.3, 0, -0.1), JointElbowFL = A(-0.3), JointWristFL = A(0.1),
	JointLegFR = A(0.3, 0, 0.1), JointElbowFR = A(-0.3), JointWristFR = A(0.1),
	JointLegBL = A(-0.45, 0, -0.04), JointKneeBL = A(-0.3), JointHockBL = A(0.2),
	JointLegBR = A(-0.45, 0, 0.04), JointKneeBR = A(-0.3), JointHockBR = A(0.2),
}), 0.3, 0.2, 0.1, 0.1)
local HP_LAND: Pose = fur(with(HP_CROUCH, { JointRoot = R(-0.32, -0.04, 0.05), JointJaw = A(-0.15) }), 0.1, 0.2, 0.1, 0.1)

-- Stagger and death: head thrown up, the mane bristling in fright, the legs braced.
local HIT: Pose = fur(with(STAND, {
	JointRoot = R(-0.06, 0.05, 0.14), JointSpine = A(0.08),
	JointNeck = A(0.14), JointHead = A(0.28), JointJaw = A(-0.45),
	JointEarL = A(0.5), JointEarR = A(0.5),
	JointTail = A(0.4), JointTail2 = A(0.2), JointTail3 = A(0.1),
}), -0.55, 0.7, -0.5, -0.1)
local THROWN = paws(-0.3, 0.25, 0.06, 0.06)

-- on its left side (the killer on its right): rolled +Z about the hips and dropped so the flank
-- rests on the ground; the head and the upper (right) legs flop to the left.
local DEAD_ROLL = 1.4
local function dead(roll: number): Pose
	return fur({
		JointRoot = CFrame.new(-0.65, -0.95, 0) * A(0, 0, roll),
		JointSpine = A(0.05, 0.05),
		JointNeck = A(-0.15, 0.3), JointHead = A(-0.1, 0.15), JointJaw = A(-0.3),
		JointEarL = A(0.4), JointEarR = A(0.4, 0, -0.2),
		JointLegFL = A(0.35, 0, 0.1), JointElbowFL = A(-0.35), JointWristFL = A(-0.3),
		JointLegFR = A(-0.05, 0, -0.25), JointElbowFR = A(-0.25), JointWristFR = A(-0.3),
		JointLegBL = A(-0.25, 0, 0.1), JointKneeBL = A(0.35), JointHockBL = A(-0.3),
		JointLegBR = A(-0.15, 0, -0.2), JointKneeBR = A(0.25), JointHockBR = A(-0.3),
		JointTail = A(0.2, -0.3), JointTail2 = A(0.1, -0.2), JointTail3 = A(0.3, -0.1),
	}, 0.55, 0.5, 0.45, 0.2, 0.2)
end

--------------------------------------------------------------------------------
-- Locomotion

local LEG = 2.3 -- effective hip-to-paw reach (unit studs) at the bend the gaits plant with
local loops = {}

local function walkAmp(speed: number): number
	return math.clamp(0.14 + 0.04 * speed, 0.16, 0.42)
end
local function circleAmp(speed: number): number
	return math.clamp(0.07 + 0.02 * speed, 0.1, 0.24)
end
-- the stalk (four-beat) firms into a trot as the speed climbs
local function trotMix(speed: number): number
	return smooth(3.5, 7, speed)
end
local function stanceOf(speed: number): number
	return 0.74 - 0.18 * trotMix(speed)
end

-- amp * (1 -> -1) over the stance share, then a lifted swing back
local function stride(phase: number, amp: number, stance: number): (number, number, number)
	local u = phase / TAU % 1
	if u < stance then
		return amp * (1 - 2 * u / stance), 0, 1
	end
	local swing = (u - stance) / (1 - stance)
	local lift = math.sin(math.pi * swing)
	return amp * (-1 + 2 * smooth(0, 1, swing)), lift, 1 - smooth(0, 0.3, lift)
end

local function offsets(m: number): { [string]: number }
	return { BL = 0.5 * m, FL = 0.25 * (1 - m), BR = 0.5 * (1 - m), FR = 0.75 - 0.25 * m }
end

function loops.idle(clock: number, _speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local breath = math.sin(clock * TAU / 3.2 + seed)
	local chest = math.sin(clock * TAU / 3.2 + seed - 0.4)
	-- it scans: the head sweeps, then the neck follows, the mane after both
	local look = 0.2 * math.sin(clock * 0.5 + seed) + 0.07 * math.sin(clock * 1.3 + seed * 2)
	local lookLate = 0.2 * math.sin(clock * 0.5 + seed - 0.8) + 0.07 * math.sin(clock * 1.3 + seed * 2 - 1.0)
	local slot = math.floor(clock / 4.5)
	local at = slot * 4.5 + Quadruped.hash(slot, seed) * 2
	local ear = bump(clock, at, at + 0.26)
	local slot2 = math.floor(clock / 3.4)
	local at2 = slot2 * 3.4 + Quadruped.hash(slot2, seed + 3) * 1.8
	local earR = bump(clock, at2, at2 + 0.24)
	local flick = bump(clock, at + 1.0, at + 1.7) * math.sin((clock - at) * 20)
	-- the stalker's creep: the weight rolls shoulder to shoulder, and now and then it sinks lower
	local shift = math.sin(clock * 0.62 + seed)
	local slotC = math.floor(clock / 7)
	local atC = slotC * 7 + Quadruped.hash(slotC, seed + 5) * 3
	local sink = bump(clock, atC, atC + 1.6)
	local pose = fur(with(STAND, {
		JointRoot = R(-0.12 - 0.07 * sink + 0.012 * breath, -0.03 - 0.03 * sink, 0, 0.012 * shift, 0.03 * shift),
		JointSpine = A(0.03 + 0.016 * chest, 0.016 * math.sin(clock * 0.5 + seed), -0.014 * shift),
		JointNeck = A(-0.24 - 0.05 * sink + 0.012 * chest, look),
		JointHead = A(0.18 + 0.05 * sink + 0.014 * math.sin(clock * 0.9 + seed), lookLate * 0.8),
		JointJaw = A(-0.03 - 0.012 * math.max(0, math.sin(clock * 0.37 + seed))),
		JointEarL = A(0.25 + 0.3 * ear), JointEarR = A(0.25 + 0.3 * earR),
		JointTail = A(0.1 + 0.03 * breath, 0.14 * math.sin(clock * 1.1) + 0.12 * flick),
		JointTail2 = A(0.08, 0.1 * math.sin(clock * 1.1 - 0.7) + 0.16 * flick),
		JointTail3 = A(0.1 + 0.04 * math.sin(clock * 1.1 - 1.2), 0.1 * math.sin(clock * 1.1 - 1.4) + 0.2 * flick),
	}), 0.15 + 0.03 * math.sin(clock * TAU / 3.2 + seed - 1.0) + 0.06 * sink, 0.06 + 0.02 * math.sin(clock * 0.9 - 0.8), 0.12 + 0.04 * math.sin(clock * 1.2 - 1.6),
		0.05 + 0.02 * math.sin(clock * 0.9 - 1.0), 0.07 * math.sin(clock * 0.62 + seed - 1.0))
	local s = 0.05 * shift
	return rig.plant(pose, ALL, { FL = V(0, 0, 0.05 * shift), FR = V(0, 0, -0.05 * shift), BL = V(s, 0, 0), BR = V(s, 0, 0) })
end

function loops.walk(phase: number, speed: number, _input: Input?): Pose
	local m = trotMix(speed)
	local stance = stanceOf(speed)
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	for tag, off in offsets(m) do
		local a, lift, w = stride(phase - off * TAU, walkAmp(speed), stance)
		rig.setLeg(pose, steps, tag, a, 0, lift, w, 0.16 + 0.06 * m)
	end
	local bob = math.sin(phase * (2 + 2 * m))
	-- shoulders roll against the hips, the head stays low and level, eyes forward
	local dip = math.max(0, math.sin(phase * 2 - 0.5)) * 0.03 * (1 - m)
	pose.JointRoot = R(-0.18 + 0.02 * bob, -0.04 + 0.01 * bob, 0, 0.04 * math.sin(phase - 0.3), 0.05 * math.sin(phase))
	pose.JointSpine = A(dip + 0.02, 0.07 * math.sin(phase - 0.2), -0.045 * math.sin(phase))
	pose.JointNeck = A(-0.26 + 0.03 * math.sin(phase * 4 - 0.9), 0.07 * math.sin(phase - 0.9))
	pose.JointHead = A(0.2 - 0.03 * math.sin(phase * 4 - 1.7), 0.05 * math.sin(phase - 1.5))
	pose.JointJaw = A(-0.04 - 0.015 * math.sin(phase * 4 - 2.2))
	pose.JointEarL, pose.JointEarR = A(0.3 + 0.05 * math.sin(phase * 4 - 2)), A(0.3 + 0.05 * math.sin(phase * 4 - 2.6))
	pose.JointTail = A(0.1 + 0.03 * math.sin(phase * 4 - 1.1), 0.16 * math.sin(phase - 0.4))
	pose.JointTail2 = A(0.1 + 0.04 * math.sin(phase * 4 - 1.8), 0.14 * math.sin(phase - 1.0))
	pose.JointTail3 = A(0.14 + 0.04 * math.sin(phase * 4 - 2.5), 0.12 * math.sin(phase - 1.6))
	-- the fur drags a beat behind the shoulders
	pose = fur(pose, 0.2 + 0.07 * math.sin(phase * 2 - 1.1), 0.07 + 0.03 * math.sin(phase * 2 - 1.5),
		0.14 + 0.07 * math.sin(phase * 2 - 2.1), 0.05 + 0.04 * math.sin(phase * 2 - 1.8), 0.06 * math.sin(phase - 1.2))
	rig.stepLegs(pose, steps)
	return pose
end

-- THE FLAT GALLOP. A rotary four-beat gallop (hind left, hind right, fore left, fore right),
-- low and long. Each paw is down for STANCE of the cycle and slides back at EXACTLY the
-- ground speed; between stances a short flight. Cycles per second climb with speed, so the
-- legs turn over faster than the King's. Speeds are real studs/s (unit = /1.63).
local STANCE = 0.34
local OFFSETS = { BL = 0, BR = 0.1, FL = 0.5, FR = 0.6 }
local LEG_EFF = 2.1
ShadowMane.GALLOP = { STANCE = STANCE, OFFSETS = OFFSETS }

local function gallopRate(speed: number): number
	return 1.5 + 0.03 * speed
end

local function gallop(phase: number, speed: number, rate: number?): Pose
	local f = rate or gallopRate(speed)
	local half = (speed / ShadowMane.SCALE) * (STANCE / f) / 2
	local aHalf = math.asin(math.clamp(half / LEG_EFF, 0, 0.8))
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
			local s = x / STANCE
			stance[tag] = 1
			reach[tag] = V(out * 0.065, 0, half * (2 * s - 1) - 0.08)
			pose[LEGS[tag].upper] = A(0, 0, out * (if front then 0.04 else 0.12))
		else
			local s = (x - STANCE) / (1 - STANCE)
			local e = smooth(0, 1, s)
			local a = -aHalf + 2 * aHalf * e + (if front then 0.3 else 0.2) * aHalf * math.sin(math.pi * s) ^ 2
			local lift = math.sin(math.pi * math.min(1, s * 1.15)) ^ 0.8
			rig.setLeg(pose, steps, tag, a, out * (if front then 0.04 else 0.14) * (0.4 + 0.6 * lift), lift, 0, if front then 0.28 else 0.2)
		end
	end
	local flight = math.max(0, math.cos(TAU * 2 * (cyc - 0.46))) ^ 1.5
	local drive = math.cos(TAU * (cyc - 0.2))
	local heave = math.cos(TAU * (cyc - 0.35))
	pose.JointRoot = R(-0.2 + 0.08 * flight - 0.04 * (1 - flight), -0.02 + 0.09 * flight - 0.04 * (1 - flight), 0, 0.06 * drive, 0.025 * math.sin(TAU * cyc))
	pose.JointSpine = A(-0.12 * heave, 0.03 * math.sin(TAU * cyc + 0.4), 0.025 * math.sin(TAU * cyc))
	local function lag(d: number): number
		return TAU * (cyc - d)
	end
	pose.JointNeck = A(-0.26 + 0.1 * math.cos(lag(0.38)), 0.03 * math.sin(lag(0.15)))
	pose.JointHead = A(0.14 + 0.08 * math.cos(lag(0.45)), 0.03 * math.sin(lag(0.2)))
	pose.JointJaw = A(-0.22 - 0.08 * math.max(0, math.cos(lag(0.5))))
	pose.JointEarL, pose.JointEarR = A(0.5 + 0.1 * math.cos(lag(0.5))), A(0.8 + 0.1 * math.cos(lag(0.56)))
	pose.JointTail = A(-0.2 + 0.12 * math.cos(lag(0.42)), 0.08 * math.sin(TAU * cyc * 0.5))
	pose.JointTail2 = A(-0.05 + 0.14 * math.cos(lag(0.5)), 0.09 * math.sin(TAU * cyc * 0.5 - 0.7))
	pose.JointTail3 = A(0.05 + 0.16 * math.cos(lag(0.58)), 0.1 * math.sin(TAU * cyc * 0.5 - 1.4))
	-- the mane streams back flat and ripples a beat behind each bound
	pose = fur(pose, 0.85 + 0.12 * math.cos(lag(0.5)), 0.45 + 0.1 * math.cos(lag(0.55)), 0.75 + 0.12 * math.cos(lag(0.62)),
		0.6 + 0.08 * math.cos(lag(0.5)), 0.05 * math.sin(lag(0.6)))
	rig.plantLegs(pose, stance, false, reach)
	rig.stepLegs(pose, steps)
	return pose
end

function loops.run(phase: number, speed: number, _input: Input?): Pose
	return gallop(phase, speed)
end

-- The crab-trot: a diagonal trot to the side, the forelegs and hindlegs crossing, the head
-- and neck turned on the target.
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local dir = if input and input.dir and input.dir < 0 then -1 else 1
	local yaw = (input and input.targetYaw) or 0
	local pose: Pose = {}
	local steps: { [string]: Step } = {}
	for tag, off in offsets(1) do
		local a, lift, w = stride(phase - off * TAU, circleAmp(speed), 0.58)
		local out = if tag == "FL" or tag == "BL" then -0.08 else 0.08
		rig.setLeg(pose, steps, tag, 0.05 * math.sin(phase - off * TAU), out - dir * a, lift, w, 0.2)
	end
	local ny = math.clamp(yaw * 0.5, -0.3, 0.3)
	pose.JointRoot = R(-0.2 + 0.015 * math.sin(phase * 4), -0.04, 0, 0, 0.06 * dir)
	pose.JointSpine = A(0, 0, -0.03 * dir)
	pose.JointNeck = A(-0.25, ny)
	pose.JointHead = A(0.2, math.clamp(yaw - ny, -0.3, 0.3))
	pose.JointJaw = A(-0.08)
	pose.JointEarL, pose.JointEarR = A(0.4), A(0.4)
	pose.JointTail = A(0.05, 0.12 * dir)
	pose.JointTail2 = A(0.1, 0.06 * math.sin(phase - 0.6))
	pose.JointTail3 = A(0.14)
	pose = fur(pose, 0.3, 0.12 + 0.04 * math.sin(phase * 2 - 0.8), 0.2, 0.1, 0.12 * dir + 0.05 * math.sin(phase * 2 - 1.2))
	rig.stepLegs(pose, steps)
	return pose
end

--------------------------------------------------------------------------------
-- Keyed attacks. The last windup key is the contact, held to the end of the phase.

local moves: { [string]: { [string]: Phase } } = {}

local function ph(duration: number, keys: { any }, overlay: any?, extra: any?): Phase
	local out: Phase = { duration = duration, keys = keys, overlay = overlay }
	if extra then
		for k, v in extra do
			(out :: any)[k] = v
		end
	end
	return out
end
local function hold(t: number, pose: Pose, plant: { string }, reach: any?, ease: string?): any
	return { t = t, pose = pose, plant = plant, reach = reach, ease = ease }
end

-- the held beat shivers: the haunches tremble, the tail tip twitches, the eyes stay on the target
local function shiver(from: number, to: number, hz: number, amount: number)
	return function(u: number, secs: number, _): Pose
		local e = smooth(from, from + 0.08, u) * (1 - smooth(to - 0.06, to, u))
		local tr = amount * e * math.sin(secs * TAU * hz)
		return {
			JointRoot = R(0.35 * tr, 0, 0, 0.6 * tr, 0.5 * tr),
			JointTail3 = A(0, 6 * tr),
			JointEarL = A(0.5 * tr), JointEarR = A(-2 * tr),
		}
	end
end

moves.ShadowStep = {
	windup = ph(0.7, {
		hold(0, STAND, ALL),
		hold(0.2, SS_DIP, ALL, LOW, "out"),
		hold(0.5, SS_LOAD, ALL, COIL, "inOut"),
		hold(0.88, SS_LOAD, ALL, COIL),
		hold(0.97, SS_SPRING, ALL, COIL, "in"),
		hold(1, SS_SPRING, ALL, COIL),
	}, shiver(0.5, 0.9, 9, 0.014)),
	active = ph(0.3, {
		hold(0, SS_SPRING, ALL, COIL),
		hold(0.14, SS_PUSH, HIND, COIL, "out"),
		hold(0.4, SS_STRETCH, NONE, nil, "out"),
		hold(0.72, SS_TUCK, NONE, nil, "inOut"),
		hold(1, SS_REACH, NONE, nil, "inOut"),
	}, nil, { air = true }), -- authored to skim just above the ground; no clamp, so no branch flips
	recover = ph(0.9, {
		hold(0, SS_REACH, NONE),
		hold(0.14, RK_LAND, ALL, SPLAYED, "out"),
		hold(0.45, SPENT, ALL, BRACED, "inOut"),
		hold(0.7, SPENT, ALL, BRACED),
		hold(1, STAND, ALL, nil, "inOut"),
	}),
}

moves.ShadowRake = {
	-- the arrival: absorbed by u 0.16, the head locked on, then the chest turns away and the
	-- left paw cocks by 0.66 (held), and rakes at 0.97
	windup = ph(0.4, {
		hold(0, SS_REACH, ALL, SPLAYED),
		hold(0.16, RK_LAND, ALL, SPLAYED, "out"),
		hold(0.34, RK_HOLD, ALL, SPLAYED, "out"),
		hold(0.66, RK_COCK, SUPPORT_RIGHT, RK_BRACE, "out"),
		hold(0.86, RK_COCK, SUPPORT_RIGHT, RK_BRACE),
		hold(0.97, RK_CONTACT, SUPPORT_RIGHT, RK_BRACE, "in"),
		hold(1, RK_CONTACT, SUPPORT_RIGHT, RK_BRACE),
	}, nil, { mirror = true }),
	active = ph(0.1, {
		hold(0, RK_CONTACT, SUPPORT_RIGHT, RK_BRACE),
		hold(0.8, RK_THROUGH, SUPPORT_RIGHT, RK_BRACE, "out"),
		hold(1, RK_THROUGH, SUPPORT_RIGHT, RK_BRACE),
	}, nil, { mirror = true }),
	recover = ph(0.9, {
		hold(0, RK_THROUGH, SUPPORT_RIGHT, RK_BRACE),
		hold(0.3, SPENT, ALL, BRACED, "out"),
		hold(0.6, SPENT, ALL, BRACED),
		hold(1, STAND, ALL, nil, "inOut"),
	}, nil, { mirror = true }),
}

moves.ManeRend = {
	windup = ph(0.6, {
		hold(0, STAND, ALL),
		hold(0.22, RD_LIFT, SUPPORT_RIGHT, BRACED, "out"),
		hold(0.5, RD_PEAK, SUPPORT_RIGHT, BRACED, "out"),
		hold(0.88, RD_PEAK, SUPPORT_RIGHT, BRACED),
		hold(0.97, RD_L_CONTACT, SUPPORT_RIGHT, BRACED, "in"),
		hold(1, RD_L_CONTACT, SUPPORT_RIGHT, BRACED),
	}, shiver(0.5, 0.88, 11, 0.01), { mirror = true }),
	-- the second paw is already rising as the first finishes; the weight swaps onto the first
	active = ph(0.12, {
		hold(0, RD_L_CONTACT, SUPPORT_RIGHT, BRACED),
		hold(0.55, RD_L_THROUGH, SUPPORT_RIGHT, BRACED, "out"),
		hold(1, RD_R_COCK, SUPPORT_LEFT, BRACED, "inOut"),
	}, nil, { mirror = true }),
	-- right rake contact at u 0.23 (0.35 s after the first), then the weight settles
	recover = ph(1.0, {
		hold(0, RD_R_COCK, SUPPORT_LEFT, BRACED),
		hold(0.2, RD_R_COCK, SUPPORT_LEFT, BRACED, "out"),
		hold(0.23, RD_R_CONTACT, SUPPORT_LEFT, BRACED, "in"),
		hold(0.31, RD_R_THROUGH, SUPPORT_LEFT, BRACED, "out"),
		hold(0.52, SPENT, ALL, BRACED, "inOut"),
		hold(0.72, SPENT, ALL, BRACED),
		hold(1, STAND, ALL, nil, "inOut"),
	}, nil, { mirror = true }),
}

moves.ManeLash = {
	windup = ph(0.8, {
		hold(0, STAND, ALL),
		hold(0.3, LS_REAR, ALL, BRACED, "out"),
		hold(0.55, LS_PEAK, ALL, BRACED, "inOut"),
		hold(0.88, LS_PEAK, ALL, BRACED),
		hold(0.985, LS_WIND, HIND, BRACED, "inOut"),
		hold(1, LS_WIND, HIND, BRACED),
	}, function(u: number, secs: number, _): Pose
		-- the open mane breathes and flutters on the held beat
		local held = smooth(0.45, 0.6, u) * (1 - smooth(0.9, 1, u))
		local f = held * math.sin(secs * TAU * 3.2)
		return { JointManeL = A(0.04 * f, 0.08 * f, -0.1 * f), JointManeR = A(0.04 * f, -0.08 * f, 0.1 * f), JointMane = A(0.06 * f) }
	end),
	active = ph(0.15, {
		hold(0, LS_WIND, HIND, BRACED),
		hold(0.5, LS_WHIP, HIND, BRACED, "in"),
		hold(1, LS_THROUGH, HIND, BRACED, "out"),
	}),
	recover = ph(1.1, {
		hold(0, LS_THROUGH, HIND, BRACED),
		hold(0.28, LS_SETTLE, ALL, BRACED, "out"),
		hold(0.62, SPENT, ALL, BRACED, "inOut"),
		hold(1, STAND, ALL, nil, "inOut"),
	}, function(_: number, secs: number, _): Pose
		-- the settle runs down the fur as a wave: neck strands, then the mane, then the forelock
		local function w(delay: number, hz: number): number
			local t = math.max(0, secs - delay)
			return math.sin(t * TAU * hz) * math.exp(-3.2 * t)
		end
		return {
			JointManeL = A(0.12 * w(0.02, 2.4), 0.3 * w(0.02, 2.4), -0.2 * w(0.06, 2.4)),
			JointManeR = A(0.12 * w(0.06, 2.4), 0.3 * w(0.06, 2.4), 0.2 * w(0.1, 2.4)),
			JointMane = A(0.18 * w(0.1, 2.2), 0.2 * w(0.1, 2.2)),
			JointForelock = A(0.3 * w(0.16, 2.6)),
			JointTail = A(0, 0.2 * w(0.12, 2.0)), JointTail2 = A(0, 0.25 * w(0.18, 2.0)), JointTail3 = A(0, 0.3 * w(0.24, 2.0)),
		}
	end),
}

-- the fade back: a low backward bound, the head held on the target
moves.Hop = {
	active = ph(0.3, {
		hold(0, STAND, ALL),
		hold(0.12, HP_CROUCH, ALL, LOW, "out"),
		hold(0.3, HP_PUSH, NONE, nil, "out"),
		hold(0.58, HP_HANG, NONE, nil, "inOut"),
		hold(0.86, HP_REACH, NONE, nil, "inOut"),
		hold(1, HP_LAND, ALL, LOW, "out"),
	}, nil, { air = true }),
}

-- snaps in by u 0.2, eases out; the head is thrown away from the hit by input.side
moves.Stagger = {
	active = ph(0.28, {
		hold(0, STAND, ALL),
		hold(0.2, HIT, ALL, THROWN, "out"),
		hold(0.45, with(HIT, { JointJaw = A(-0.3) }), ALL, THROWN),
		hold(1, STAND, ALL, nil, "inOut"),
	}, function(u: number, _, input: Input): Pose
		local side = math.clamp(input.side or 0, -1, 1)
		local e = if u < 0.2 then Quadruped.EASE.out(u / 0.2) else 1 - Quadruped.EASE.inOut((u - 0.2) / 0.8)
		return {
			JointNeck = A(0, 0.15 * side * e), JointHead = A(0, 0.2 * side * e, 0.1 * side * e), JointSpine = A(0, 0, 0.05 * side * e),
			JointMane = A(0, 0.2 * side * e), JointManeL = A(0, 0.25 * side * e), JointManeR = A(0, 0.25 * side * e),
		}
	end),
}

-- a hit, then it rolls onto its side away from the killer, legs limp, the mane draping. Holds at
-- u = 1 until the fade.
moves.Death = {
	active = ph(0.7, {
		hold(0, STAND, ALL),
		hold(0.2, HIT, ALL, THROWN, "out"),
		hold(0.6, with(dead(DEAD_ROLL * 0.45), { JointRoot = CFrame.new(-0.3, 0.12, 0) * A(0, 0, DEAD_ROLL * 0.45) }), NONE, nil, "in"),
		hold(0.88, dead(DEAD_ROLL + 0.08), NONE, nil, "in"),
		hold(1, dead(DEAD_ROLL), NONE, nil, "out"),
	}, nil, { mirror = true }),
}

-- Skids (authored for the target on the wolf's RIGHT; mirror plays the left). The head snaps
-- round and leads (the overlay turns chest, neck and head to the live input.targetYaw); the
-- forepaws brace ahead with the chest low and the mane thrown forward; the hind end slides out
-- to the outside of the turn and scrabbles; then it squares up in the prowl. No pose turns the
-- root: the server owns the yaw.
local SK_BRAKE: Pose = fur(with(SPENT, {
	JointRoot = R(-0.34, 0.06, 0.1, -0.03, -0.05), JointSpine = A(0.04),
	JointNeck = A(-0.12), JointHead = A(0.2), JointJaw = A(-0.4),
	JointEarL = A(0.5), JointEarR = A(0.5),
	JointTail = A(0.05, -0.45), JointTail2 = A(0.05, -0.3), JointTail3 = A(0.25, -0.2),
}), -0.4, 0.5, -0.4, -0.2)
local SK_SCRAB: Pose = fur(with(SK_BRAKE, {
	JointRoot = R(-0.3, 0.04, 0.06, -0.02, -0.06),
	JointLegBL = A(0.4, 0, -0.1), JointKneeBL = A(-1.15), JointHockBL = A(0.55),
	JointTail = A(0.1, -0.35), JointTail2 = A(0.05, -0.35),
}), -0.2, 0.4, -0.2, -0.1)
local SK_SCRAB2: Pose = fur(with(SK_SCRAB, {
	JointRoot = R(-0.28, 0.03, 0.04, -0.01, -0.05),
	JointLegBR = A(0.4, 0, 0.1), JointKneeBR = A(-1.15), JointHockBR = A(0.55),
	JointTail = A(0.1, -0.2), JointTail2 = A(0.08, -0.25),
}), 0.0, 0.3, 0.0, 0.0)
local SK_STEP: Pose = fur(with(SPENT, {
	JointRoot = R(-0.24, 0.02, 0, 0, -0.03), JointNeck = A(-0.2), JointHead = A(0.16), JointJaw = A(-0.2),
	JointLegFR = A(0.55, 0, 0.2), JointElbowFR = A(-1.0), JointWristFR = A(0.35),
	JointTail = A(0.15, -0.1),
}), 0.1, 0.1, 0.05, 0.1)
local SK_BRAKED = { FL = V(-0.082, 0, -0.815), FR = V(0.196, 0, -0.733), BL = V(-0.554, 0, 0.652), BR = V(-0.261, 0, 0.733) }
local SK_SCRABBED = { FL = V(-0.065, 0, -0.685), FR = V(0.163, 0, -0.652), BL = V(-0.293, 0, 0.456), BR = V(-0.359, 0, 0.522) }
local SK_SQUARED = { FL = V(-0.065, 0, -0.489), FR = V(0.196, 0, -0.407), BL = V(-0.163, 0, 0.326), BR = V(-0.163, 0, 0.293) }

-- the head leads a turn: chest, neck and head toward the target (live yaw, + left) by env; the
-- mane swings out against the turn. `signed` follows the signed yaw (the rake's arrival);
-- otherwise the skid's authored frame (target on the right, mirror flips).
local function leadOverlay(env: (number) -> number, signed: boolean)
	return function(u: number, _secs: number, input: Input): Pose
		local yaw = input.targetYaw
		local e = env(u)
		if yaw == nil then
			yaw = if signed then 0 else -1.3
		end
		local turn = if signed then math.clamp(yaw, -1.4, 1.4) else -math.min(math.abs(yaw), 1.4)
		local f = turn / 1.4 * e
		return {
			JointSpine = A(0, 0.22 * f), JointNeck = A(0, 0.3 * f), JointHead = A(0, 0.2 * f, -0.2 * f),
			JointManeL = A(0, 0, -0.4 * math.max(0, f)), JointManeR = A(0, 0, 0.4 * math.max(0, -f)),
			JointMane = A(0, -0.3 * f),
			JointTail = A(0, 0.2 * f), JointTail2 = A(0, 0.15 * f),
		}
	end
end
local skidLead = leadOverlay(function(u) return smooth(0, 0.14, u) * (1 - smooth(0.7, 1, u)) end, false)
local rakeLead = leadOverlay(function(u) return smooth(0, 0.12, u) * (1 - smooth(0.55, 0.8, u)) end, true)
moves.ShadowRake.windup.overlay = rakeLead

moves.ShadowStepSkid = {
	recover = ph(0.9, {
		hold(0, SS_REACH, NONE),
		hold(0.08, SK_BRAKE, ALL, SK_BRAKED, "out"),
		hold(0.28, SK_SCRAB, { "FL", "FR", "BR" }, SK_BRAKED, "inOut"),
		hold(0.42, SK_SCRAB2, { "FL", "FR", "BL" }, SK_SCRABBED, "inOut"),
		hold(0.58, SK_STEP, { "FL", "BL", "BR" }, SK_SCRABBED, "inOut"),
		hold(0.76, SPENT, ALL, SK_SQUARED, "inOut"),
		hold(1, STAND, ALL, nil, "inOut"),
	}, skidLead, { mirror = true }),
}

ShadowMane.LEAD = { ShadowRake = true, ShadowStepSkid = true }

--------------------------------------------------------------------------------
-- OVERLAPPING ACTION. The neck, head, jaw, ears, fur and tail links follow the body late, each
-- tier by its own lag (neck/head/tail first, then jaw/ears/neck strands, the mane, the forelock
-- last). The lag fades to zero at every phase boundary so poses stay continuous, and contact is
-- never late. The lagged poses sample the key table only (no planting: none of these joints
-- depend on it).
local LAG_SEC = 0.1
local TIERS = { 0.5, 1.1, 1.8, 2.6 }
local TIER_OF = {
	JointNeck = 1, JointHead = 1, JointTail = 1,
	JointJaw = 2, JointEarL = 2, JointManeL = 2, JointTail2 = 2,
	JointEarR = 3, JointMane = 3, JointManeR = 3, JointTail3 = 3,
	JointForelock = 4,
}
-- how hard each move rings after its contact (1 = a King strike)
local SETTLE = { ShadowRake = 1, ShadowStep = 0.7, ShadowStepSkid = 1, ManeRend = 0.9, ManeLash = 0.6, Hop = 0.8, Stagger = 1.3 }
local SETTLE_WINDUP = { ShadowRake = 1.1 }

local function secondary(pose: Pose, move: string, phase: string, u: number, input: Input?)
	local def = moves[move][phase]
	local dur = (input and input.duration) or def.duration
	local secs = u * dur
	local fade = if move == "Death" then smooth(0, 0.2, u) else smooth(0, 0.2, u) * (1 - smooth(0.8, 1, u))
	if fade > 0.01 then
		local inp: Input = input or {}
		for tier, k in TIERS do
			local lagged = Quadruped.samplePhase(def, math.clamp(u - LAG_SEC * k * fade / dur, 0, 1), inp)
			for name, t in TIER_OF do
				if t == tier then
					pose[name] = lagged[name] or pose[name]
				end
			end
		end
	end
	-- the held windup breathes: the head sways a hair, the tail brush twitches
	local held = if phase == "windup" then smooth(0.3, 0.5, u) * (1 - smooth(0.92, 1, u)) else 0
	if held > 0 then
		pose.JointNeck = (pose.JointNeck or I) * A(0, 0.014 * held * math.sin(secs * 6.1))
		pose.JointHead = (pose.JointHead or I) * A(0.015 * held * math.sin(secs * 8.3 + 1))
		pose.JointTail = (pose.JointTail or I) * A(0, 0.04 * held * math.sin(secs * 3.1))
		pose.JointTail2 = (pose.JointTail2 or I) * A(0, 0.05 * held * math.sin(secs * 3.1 - 0.7))
		pose.JointTail3 = (pose.JointTail3 or I) * A(0, 0.07 * held * math.sin(secs * 3.1 - 1.4))
		pose.JointMane = (pose.JointMane or I) * A(0.03 * held * math.sin(secs * 4.4))
		pose.JointManeL = (pose.JointManeL or I) * A(0, 0.03 * held * math.sin(secs * 4.1), 0.03 * held * math.sin(secs * 4.4))
		pose.JointManeR = (pose.JointManeR or I) * A(0, 0.03 * held * math.sin(secs * 3.7 + 1), -0.03 * held * math.sin(secs * 3.7 + 1))
		pose.JointForelock = (pose.JointForelock or I) * A(0.05 * held * math.sin(secs * 5.3))
	end
	-- the raised paw sweeps through its own side's neck strands: sweep that side's strands back and
	-- out of the way while the paw is up (measured clean; folding them down made it worse)
	if move == "ShadowRake" or move == "ManeRend" then
		local left, right = 0, 0
		if move == "ShadowRake" then
			left = if phase == "windup" then smooth(0.1, 0.35, u) elseif phase == "active" then 1 else 1 - smooth(0, 0.5, u)
		elseif phase == "windup" then
			left = smooth(0.1, 0.35, u)
		elseif phase == "active" then
			left, right = 1 - 0.7 * u, u
		else
			right = 1 - smooth(0.2, 0.55, u)
		end
		if input and (input.side or 1) < 0 then
			left, right = right, left
		end
		pose.JointManeL = (pose.JointManeL or I):Lerp(A(0.8, 0, -0.3), left)
		pose.JointManeR = (pose.JointManeR or I):Lerp(A(0.8, 0, 0.3), right)
	end
	local amp = if phase == "windup" then SETTLE_WINDUP[move] else SETTLE[move]
	if amp then
		local tc = secs + (if phase == "recover" then (ShadowMane.durations[move].active or 0) else 0)
		local function ring(delay: number, hz: number): number
			local t = math.max(0, tc - delay)
			return math.sin(t * TAU * hz) * math.exp(-4.2 * t) * amp
		end
		pose.JointNeck = (pose.JointNeck or I) * A(-0.08 * ring(0.02, 3.2), 0.04 * ring(0.05, 2.4))
		pose.JointHead = (pose.JointHead or I) * A(-0.14 * ring(0.05, 3.4))
		pose.JointJaw = (pose.JointJaw or I) * A(-0.1 * math.max(0, ring(0.06, 3.6)))
		pose.JointTail = (pose.JointTail or I) * A(0.18 * ring(0.08, 2.8), 0.14 * ring(0.1, 2.0))
		pose.JointTail2 = (pose.JointTail2 or I) * A(0.2 * ring(0.14, 2.8), -0.18 * ring(0.16, 2.0))
		pose.JointTail3 = (pose.JointTail3 or I) * A(0.22 * ring(0.2, 2.8), 0.22 * ring(0.22, 2.0))
		pose.JointEarL = (pose.JointEarL or I) * A(0.3 * ring(0.08, 4.4))
		pose.JointEarR = (pose.JointEarR or I) * A(0.3 * ring(0.12, 4.0))
		pose.JointMane = (pose.JointMane or I) * A(0.3 * ring(0.08, 2.6), 0.12 * ring(0.1, 2.0))
		pose.JointManeL = (pose.JointManeL or I) * A(0.1 * ring(0.1, 3.0), 0.2 * ring(0.12, 2.4), 0.16 * ring(0.1, 3.0))
		pose.JointManeR = (pose.JointManeR or I) * A(0.1 * ring(0.15, 3.0), -0.2 * ring(0.17, 2.4), -0.14 * ring(0.15, 2.8))
		pose.JointForelock = (pose.JointForelock or I) * A(0.4 * ring(0.2, 3.2))
	end
end

local sampleKeyed = rig.sampler(moves, "ShadowMane")

function ShadowMane.sample(move: string, phase: string, u: number, input: Input?): Pose
	local pose = sampleKeyed(move, phase, u, input)
	u = math.clamp(u, 0, 1)
	secondary(pose, move, phase, u, input)
	if move == "Death" then
		-- the mane lets go and drapes on the ground as it falls
		local e = smooth(0.25, 0.95, u)
		local side = if input and input.side and input.side < 0 then -1 else 1
		pose.JointMane = A(0.3 * e, 0.1 * side * e, 0.12 * side * e)
		pose.JointManeL = A(0.22 * e, 0.1 * side * e, 0.4 * e)
		pose.JointManeR = A(0.22 * e, 0.1 * side * e, -0.4 * e)
	end
	return pose
end

function ShadowMane.gaitRate(loop: string, speed: number, scale: number?): number
	local s = scale or 1
	-- a stance sweeps +amp -> -amp over its share of the cycle: match the paw travel to the
	-- root speed so the planted paws don't skate
	if loop == "walk" then
		-- measured (forward kinematics of the stance paw pivots): the bent stance legs sweep their
		-- paws 0.83 (1.5 studs/s) to 0.67 (5+) of the nominal stride, so the cycle runs faster
		local sweep = math.clamp(0.9 - 0.06 * speed, 0.67, 0.85)
		return TAU * speed * stanceOf(speed) / (2 * LEG * math.sin(walkAmp(speed))) / s / sweep
	elseif loop == "run" then
		return TAU * gallopRate(speed) -- real cycles/s, not body-scaled
	elseif loop == "circle" then
		return TAU * math.min(speed * 0.58 / (2 * LEG * math.sin(circleAmp(speed))), 3.2) / s
	end
	return 1
end

ShadowMane.moves = moves
ShadowMane.durations = Quadruped.durations(moves)
ShadowMane.loops = loops
ShadowMane.scaled = Wolf.scaled
ShadowMane.plant = rig.plant

return ShadowMane
