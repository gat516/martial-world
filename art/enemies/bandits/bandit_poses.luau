--!nocheck
-- Shared pose tables for the bandit roster, used by preview_bandits.luau (captures) and
-- qa_bandits.luau (drift, clipping and keyframe tests). Each pose maps a Motor6D name to
-- the rotation applied in that joint's frame (what an animator keys). Conventions: RIGS.md.
local A = CFrame.Angles
local P = {}

-- R6 joint conventions (stock, pose applied in the joint's frame):
--   Right Shoulder / Right Hip: A(0,0,+a) swings forward, A(-b,0,0) swings out.
--   Left Shoulder / Left Hip:   A(0,0,-a) swings forward, A(-b,0,0) swings out.
--   Neck / RootJoint:           A(+a,0,0) pitches forward (head down / lean in), A(0,0,y) yaws.
--   Hilt (weapon motor, arm frame): A(x,0,0) pitches the blade (+ up when the arm hangs).
-- Extra joints (identity frames in model space): A(+a,0,0) swings a hanging piece forward.
P.POSES = {
	MountainBandit = {
		rest = {
			["Right Shoulder"] = A(0, 0, 0.15), ["Left Shoulder"] = A(-0.08, 0, 0),
			Hilt = A(-0.9, 0, 0),
		},
		-- windup for the overhead chop: dao raised high behind the head, weight back
		windup = {
			RootJoint = A(-0.12, 0, 0.35), Neck = A(0.05, 0, -0.3),
			["Right Shoulder"] = A(-0.25, 0, 2.7), ["Left Shoulder"] = A(-0.2, 0, -0.9),
			["Right Hip"] = A(0, 0, -0.35), ["Left Hip"] = A(0, 0, -0.45),
			Hilt = A(0.5, 0, 0),
			SashTail1 = A(-0.25, 0, 0.1), SashTail2 = A(-0.3, 0, -0.1),
			WrapTail1 = A(-0.3, 0, 0), WrapTail2 = A(-0.35, 0, 0),
			Hat = A(-0.1, 0, 0.05),
		},
	},
	BanditArcher = {
		rest = {
			["Left Shoulder"] = A(-0.05, 0, -0.35), ["Right Shoulder"] = A(-0.05, 0, 0),
			Bow = A(-0.35, 0, 0),
		},
		-- full draw, side-on: the body turns 1.4 left so the left shoulder leads, both
		-- straight arms point at the target (-Z), the left arm twisted half a turn about its
		-- own axis so the bow sits inboard of the fist, in line with the drawing hand. Bow
		-- stands the bow upright with the string toward the archer (solved with P.solveAim,
		-- then written out), Nock pulls the string's middle back to the right hand.
		windup = {
			RootJoint = A(0, 0, -1.4), Neck = A(0, 0, 1.26),
			["Left Shoulder"] = A(0, 1.4, -1.57) * A(0, math.pi, 0),
			["Right Shoulder"] = A(0, 1.4, 1.57),
			["Right Hip"] = A(0, 0, 0.25), ["Left Hip"] = A(0, 0, 0.2),
			Bow = A(-0.672, 0, math.pi),
			Nock = CFrame.new(-0.28, 0, 1.59),
			Quiver = A(0, 0, 0.1), BandTail1 = A(-0.3, 0, 0), BandTail2 = A(-0.25, 0, 0),
		},
	},
	BanditChief = {
		rest = {
			["Right Shoulder"] = A(-0.1, 0, 0.35), Hilt = A(1.2, 0, 0),
			["Left Shoulder"] = A(-0.15, 0, 0),
		},
		-- windup for the sweeping cleave: guandao drawn back low across the body
		windup = {
			RootJoint = A(0.15, 0, -0.6), Neck = A(-0.1, 0, 0.5),
			["Right Shoulder"] = A(-0.35, 0, 0.45), ["Left Shoulder"] = A(-0.2, 0, -1.3), -- past ~0.4 out the pauldron reaches the helm
			["Right Hip"] = A(-0.3, 0, -0.3), ["Left Hip"] = A(0, 0, -0.5),
			Hilt = A(0.3, 0.6, 0),
			Cape1 = A(-0.25, 0, 0.1), Cape2 = A(-0.2, 0, 0), Plume = A(-0.2, 0, -0.1),
		},
	},
}

-- joint-range stress poses shared by every bandit
P.TEST = {
	stride = {
		["Right Shoulder"] = A(0, 0, 0.9), ["Left Shoulder"] = A(0, 0, 0.9),
		["Right Hip"] = A(0, 0, -1.0), ["Left Hip"] = A(0, 0, -1.0),
		RootJoint = A(0.1, 0, 0),
	},
	raised = {
		-- overhead, +X tips an arm OUT (the hanging-arm "out" sign flips once it's raised)
		["Right Shoulder"] = A(0.3, 0, 3.0), ["Left Shoulder"] = A(0.3, 0, -3.0),
		["Right Hip"] = A(-0.5, 0, 0.9), ["Left Hip"] = A(-0.5, 0, 0),
		Neck = A(-0.4, 0, 0.5), RootJoint = A(-0.15, 0, 0.2),
	},
}

-- The Archer's aim: the Bow pose that stands the bow upright in the posed left hand with
-- the string toward the archer. world maps each part to its posed world CFrame.
function P.solveAim(motor, world)
	local jointWorld = world[motor.Part0] * motor.C0
	local back = world[motor.Part0].UpVector * Vector3.new(1, 0, 1) -- hand toward shoulder
	back = if back.Magnitude > 1e-3 then back.Unit else Vector3.zAxis
	local up = Vector3.yAxis
	local want = CFrame.fromMatrix(jointWorld.Position, up:Cross(back), up, back)
	return jointWorld:Inverse() * want
end

return P
