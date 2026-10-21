--!nocheck
-- Rigs ServerStorage._RosterBeasts.VenomSerpent (build_venom_serpent.luau) with the
-- shared rig_core.luau. Run in Edit mode through execute_luau; re-runnable.
--
-- Joints (all frames identity in model space, rotation about X is pitch):
--   JointRoot   HRP -> Body (the ground segment under the neck)
--   JointNeck, JointNeck2, JointNeck3   the rearing column, Body -> Neck1 -> Neck2 -> Neck3
--   JointHead   Neck3 -> Skull;  JointJaw  Skull -> Jaw
--   JointHoodL/R   Neck3 -> HoodL/R, hinged at the inner edge (yaw flares the hood)
--   JointTail, JointTail2..5   Body -> Tail1 -> ... -> Tail5
-- Legacy names the current EnemyAnimator drives: JointHead (pitch: idle bob, windup
-- head down, stagger head up) and JointTail (pitch plus a yaw wag that sways the whole
-- tail). No JointLeg*: a serpent has none, so the gait swing does nothing.
-- HRP: the old serpent's footprint grown to the new body's mid (player melee only hits
-- the HRP, all other parts are CanQuery false), bottom 0.5 above the ground.

local BASE = "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
return rig({
	target = "VenomSerpent",
	hrpSize = Vector3.new(2.6, 2.4, 4),
	hrpPos = Vector3.new(0, 1.7, 0.2),
	barHeight = 6,
})
