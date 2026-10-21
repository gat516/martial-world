--!nocheck
-- The roster beasts' main-attack windup poses, by Motor6D name, shared by
-- preview_beasts.luau (FK preview) and drift_beasts.luau (engine pose test). These are
-- starting points for the animator, not final keys.
local A = CFrame.Angles
local POSES = {
	-- the spit: the column draws back and rises, hood flares wide, nose up, jaw open
	VenomSerpent = {
		JointNeck = A(0.12, 0, 0), JointNeck2 = A(0.22, 0, 0), JointNeck3 = A(0.1, 0, 0),
		JointHead = A(0.2, 0, 0), JointJaw = A(-0.7, 0, 0),
		JointHoodL = A(0, -0.4, 0.15), JointHoodR = A(0, 0.4, -0.15),
		JointTail = A(0, 0.25, 0), JointTail3 = A(0, -0.3, 0), JointTail5 = A(0.4, 0, 0),
	},
	-- the strike: the S-coil folds tighter and back, head cocked, jaw wide
	JadePython = {
		JointNeck = A(0.1, 0, 0), JointNeck2 = A(0.3, 0, 0), JointNeck3 = A(-0.15, 0, 0),
		JointNeck4 = A(-0.1, 0, 0), JointHead = A(0.25, 0, 0), JointJaw = A(-0.8, 0, 0),
		JointTail = A(0, 0.15, 0), JointTail4 = A(0, -0.2, 0), JointTail7 = A(0.5, 0, 0),
	},
	-- the dive rake: wings swept up and back, head down, talons thrown forward
	FlameRaven = {
		JointRoot = A(-0.25, 0, 0), JointNeck = A(-0.2, 0, 0), JointHead = A(-0.15, 0, 0), JointJaw = A(-0.5, 0, 0), JointCrest = A(-0.4, 0, 0),
		JointShoulderL = A(0.35, 0.45, -0.75), JointShoulderR = A(0.35, -0.45, 0.75),
		JointElbowL = A(0, 0.25, -0.3), JointElbowR = A(0, -0.25, 0.3),
		JointWristL = A(0, 0.2, -0.3), JointWristR = A(0, -0.2, 0.3),
		JointLegBL = A(0.9, 0, 0), JointLegBR = A(0.9, 0, 0),
		JointAnkleL = A(0.5, 0, 0), JointAnkleR = A(0.5, 0, 0),
		JointTail = A(-0.35, 0, 0),
	},
	-- the double-fist slam: rears up on its legs, both fists raised overhead
	ThunderApe = {
		JointRoot = A(0.45, 0, 0), JointSpine = A(0.25, 0, 0), JointHead = A(-0.35, 0, 0), JointJaw = A(-0.55, 0, 0),
		JointLegFL = A(2.0, 0, -0.2), JointLegFR = A(2.0, 0, 0.2),
		JointElbowFL = A(0.6, 0, 0), JointElbowFR = A(0.6, 0, 0),
		JointWristFL = A(0.3, 0, 0), JointWristFR = A(0.3, 0, 0),
		JointLegBL = A(-0.45, 0, 0), JointLegBR = A(-0.45, 0, 0),
		JointKneeBL = A(0.3, 0, 0), JointKneeBR = A(0.3, 0, 0),
		JointAnkleBL = A(0.15, 0, 0), JointAnkleBR = A(0.15, 0, 0),
	},
}
return POSES
