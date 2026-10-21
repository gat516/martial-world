--!nocheck
-- Rigs ServerStorage._RosterQuadrupeds.StoneTortoise_R (build_stone_tortoise.luau) with
-- rig_lib.luau. Legacy names kept: JointHead, JointTail, JointLeg*. JointNeck retracts
-- the head: translate it along +Z (2.3 tucks it until the face peeks from the lip; RIGS.md).

local BASE = "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local rig = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/rig_lib.luau?" .. os.clock()))()

local function v(x, y, z)
	return Vector3.new(x, y, z)
end
local X, ZF, ZB = 2.75, -2.7, 2.8

local joints = {
	{ "JointRoot", "HumanoidRootPart", "Shell", v(0, 2.4, 0) },
	{ "JointNeck", "Shell", "Neck", v(0, 2.25, -3.3) },
	{ "JointHead", "Neck", "Head", v(0, 2.4, -4.9) },
	{ "JointJaw", "Head", "Jaw", v(0, 1.95, -4.95) },
	{ "JointTail", "Shell", "Tail", v(0, 1.7, 3.9) },
	{ "JointTailTip", "Tail", "TailTip", v(0, 1.25, 4.75) },
}
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	table.insert(joints, { "JointLegF" .. side, "Shell", "UpperLegF" .. side, v(s * (X - 0.15), 2.1, ZF) })
	table.insert(joints, { "JointFootF" .. side, "UpperLegF" .. side, "FootF" .. side, v(s * X, 0.75, ZF) })
	table.insert(joints, { "JointLegB" .. side, "Shell", "UpperLegB" .. side, v(s * (X - 0.15), 2.1, ZB) })
	table.insert(joints, { "JointFootB" .. side, "UpperLegB" .. side, "FootB" .. side, v(s * X, 0.75, ZB) })
end

return rig({
	folder = "_RosterQuadrupeds",
	target = "StoneTortoise_R",
	hrpSize = v(5, 2.4, 7),
	hrpPos = v(0, 2.4, 0),
	joints = joints,
})
