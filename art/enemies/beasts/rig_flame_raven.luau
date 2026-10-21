--!nocheck
-- Rigs ServerStorage._RosterBeasts.FlameRaven (build_flame_raven.luau) with the shared
-- rig_core.luau. Run in Edit mode through execute_luau; re-runnable.
--
-- Joints (all frames identity in model space, rotation about X is pitch, about Z roll):
--   JointRoot   HRP -> Body (pivot at the body's centre: a hover bob or dive tilt)
--   JointNeck   Body -> Neck;  JointHead  Neck -> Skull;  JointJaw  Skull -> Jaw (lower beak)
--   JointShoulderL/R  Body -> UpperWing;  JointElbowL/R  -> ForeWing;  JointWristL/R  -> WingTip
--     (a flap is roll about Z at the shoulder, -roll on L / +roll on R lifts the wing)
--   JointTail   Body -> Tail (the fan)
--   JointLegBL/BR  Body -> LegL/R (hips);  JointAnkleL/R  Leg -> Talon
-- Legacy names the current EnemyAnimator drives: JointHead, JointTail, and the legs as
-- JointLegBL/BR (their pitch swing paddles a little while moving; the dash pose swings
-- them forward, which reads as talons out for the dive). The wings take no legacy name:
-- a pitch swing would row them, so they hold their spread until the animator learns a
-- flap (roll at the shoulders).
-- Hover: HRP 3 tall centred at Y 5, so its bottom (HipHeight) is 3.5: the Humanoid
-- holds the body at player-head height with the talons hanging to Y 3.3, and a grounded
-- player's melee box (root Y 3, 5 tall, plus slack) overlaps the HRP.

local BASE = "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
return rig({
	target = "FlameRaven",
	hrpSize = Vector3.new(2.4, 3, 3),
	hrpPos = Vector3.new(0, 5, 0),
	barHeight = 9,
})
