--!nocheck
-- Rigs ServerStorage._RosterBeasts.ThunderApeB at 3.71x (build_thunder_ape.luau) with the shared
-- rig_core.luau. Run in Edit mode through execute_luau; re-runnable.
--
-- Joints (all frames identity in model space, rotation about X is pitch):
--   JointRoot   HRP -> Hips (pivot at the hips: rearing up turns about it)
--   JointSpine  Hips -> Chest;  JointHead  Chest -> Skull;  JointJaw  Skull -> Jaw
--   JointLegFL/FR    Chest -> UpperArmFL/FR (shoulders)
--   JointElbowFL/FR  UpperArm -> ForeArm;  JointWristFL/FR  ForeArm -> Hand (the fist)
--   JointMane1/2/3   Chest -> Mane1/2/3 (back crest tufts);  JointBrow  Skull -> Brow
--   JointBeard       Jaw -> Beard
--   JointLegBL/BR    Hips -> ThighBL/BR;  JointKneeBL/BR  -> Shin;  JointAnkleBL/BR  -> Foot
-- Legacy names the current EnemyAnimator drives: the arms are its front legs and the
-- legs its back legs (JointLeg*), so the trot gait reads as a knuckle-walk; JointHead.
-- No tail. The wolf's naming (Elbow, Wrist, Knee) is kept so per-type pose tables carry
-- over; the hind joint is Ankle rather than Hock.
-- HRP: 4 tall, so EnemyAnimator strides it at scale 2 (a slow heavy gait); bottom 1.2.

local BASE = "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
local SCALE = 3.71 -- build_thunder_ape.luau's SCALE
local model = game:GetService("ServerStorage")._RosterBeasts.ThunderApeB
local cf, size = model:GetBoundingBox()
local out = rig({
	target = "ThunderApeB",
	hrpSize = Vector3.new(4, 4, 4.4) * SCALE,
	hrpPos = Vector3.new(0, 3.2, 0) * SCALE,
	barHeight = cf.Position.Y + size.Y / 2 + 1, -- 1 stud over the built model's top
})
model:SetAttribute("Scale", SCALE) -- as the Elder Wolf King carries it
return out
