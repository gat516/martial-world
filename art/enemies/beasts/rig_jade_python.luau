--!nocheck
-- Rigs ServerStorage._RosterBeasts.JadePython (build_jade_python.luau) with the shared
-- rig_core.luau. Run in Edit mode through execute_luau; re-runnable.
--
-- Joints (all frames identity in model space, rotation about X is pitch):
--   JointRoot   HRP -> Body (the ground segment under the neck)
--   JointNeck, JointNeck2..4   the strike S, Body -> Neck1 -> ... -> Neck4
--   JointHead   Neck4 -> Skull;  JointJaw  Skull -> Jaw
--   JointTail, JointTail2..7   Body -> Tail1 -> ... -> Tail7, the coil
-- Legacy names the current EnemyAnimator drives: JointHead and JointTail (the yaw wag
-- swings the whole coil a little; fine for a big snake). No JointLeg*.
-- HRP: covers the coil (player melee only hits the HRP), bottom 0.5 above the ground;
-- its 3-stud height makes EnemyAnimator's stride scale 1.5.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
return rig({
	target = "JadePython",
	hrpSize = Vector3.new(4.4, 3, 6),
	hrpPos = Vector3.new(0, 2, 1.6),
	barHeight = 6.8,
})
