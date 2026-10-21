--!nocheck
-- Rigs ServerStorage._RosterQuadrupeds.NineTailFox_R (build_nine_tail_fox.luau) with
-- rig_lib.luau. Legacy names kept: JointHead, JointTail (now the root of the whole fan),
-- JointLeg*. Each tail i (1 = far left, 9 = far right) has JointTail<i> at its base and
-- JointTail<i>Tip at the curl; roll about Z fans it out, + pitch sweeps it back. Every
-- other joint is Joint<Part1> (RIGS.md has the tables and safe ranges).
-- HRP as the Spirit Wolf (2 x 2 x 4.4 at Y 2.6): a fox-sized body, wolf-sized ranges.

local BASE = "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local rig = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/rig_lib.luau?" .. os.clock()))()

-- keep in step with build_nine_tail_fox.luau
local TAIL_ROOT = Vector3.new(0, 3.55, 2.7)
local TAIL_SPREAD, TAIL_BASE_LEN = 1.35, 1.6
local function tailDir(i)
	local a = (i - 5) / 4 * TAIL_SPREAD
	return Vector3.new(math.sin(a) * 0.9, math.cos(a) * 0.85, if i % 2 == 1 then 0.75 else 0.4).Unit
end

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

local joints = {
	{ "JointRoot", "HumanoidRootPart", "Hips", v(0, 3.1, 1.2) },
	{ "JointChest", "Hips", "Chest", v(0, 3.1, 0.6) },
	{ "JointNeck", "Chest", "Neck", v(0, 3.35, -1.4) },
	{ "JointHead", "Neck", "Head", v(0, 4.5, -2.4) },
	{ "JointJaw", "Head", "Jaw", v(0, 4.2, -3.3) },
	{ "JointEarL", "Head", "EarL", v(-0.42, 5.0, -2.7) },
	{ "JointEarR", "Head", "EarR", v(0.42, 5.0, -2.7) },
	{ "JointTail", "Hips", "Tail", v(0, 3.5, 2.45) },
}
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local x = s * 0.5
	table.insert(joints, { "JointLegF" .. side, "Chest", "UpperLegF" .. side, v(x, 2.8, -1.25) })
	table.insert(joints, { "JointLowerLegF" .. side, "UpperLegF" .. side, "LowerLegF" .. side, v(x, 1.55, -1.25) })
	table.insert(joints, { "JointPawF" .. side, "LowerLegF" .. side, "PawF" .. side, v(x, 0.32, -1.25) })
	x = s * 0.52
	table.insert(joints, { "JointLegB" .. side, "Hips", "UpperLegB" .. side, v(x, 2.95, 1.85) })
	table.insert(joints, { "JointLowerLegB" .. side, "UpperLegB" .. side, "LowerLegB" .. side, v(x, 1.6, 1.65) })
	table.insert(joints, { "JointPawB" .. side, "LowerLegB" .. side, "PawB" .. side, v(x, 0.7, 2.15) })
end
for i = 1, 9 do
	local d = tailDir(i)
	local a = TAIL_ROOT + d * 0.2
	table.insert(joints, { "JointTail" .. i, "Tail", "Tail" .. i, a })
	table.insert(joints, { "JointTail" .. i .. "Tip", "Tail" .. i, "Tail" .. i .. "Tip", a + d * TAIL_BASE_LEN })
end

return rig({
	folder = "_RosterQuadrupeds",
	target = "NineTailFox_R",
	hrpSize = v(2, 2, 4.4),
	hrpPos = v(0, 2.6, 0),
	joints = joints,
})
