--!nocheck
-- Rigs ServerStorage._RosterQuadrupeds.StoneBoar_R (build_stone_boar.luau) with the
-- shared assembler rig_lib.luau. Legacy names kept: JointRoot, JointHead, JointTail,
-- JointLeg*; every other joint is Joint<Part1> (RIGS.md).
-- HRP kept from the old StoneBoar (3 x 2.4 x 5 at Y 2.8): its AI ranges are tuned to it.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local rig = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/rig_lib.luau?" .. os.clock()))()

local function v(x, y, z)
	return Vector3.new(x, y, z)
end
local F, ZF, B, ZB = 1.15, -1.35, 1.05, 2.15

return rig({
	folder = "_RosterQuadrupeds",
	target = "StoneBoar_R",
	hrpSize = v(3, 2.4, 5),
	hrpPos = v(0, 2.8, 0),
	joints = {
		{ "JointRoot", "HumanoidRootPart", "Hips", v(0, 3.3, 1.2) },
		{ "JointChest", "Hips", "Chest", v(0, 3.5, 1.0) },
		{ "JointNeck", "Chest", "Neck", v(0, 3.6, -2.0) },
		{ "JointHead", "Neck", "Head", v(0, 3.3, -2.9) },
		{ "JointJaw", "Head", "Jaw", v(0, 2.4, -3.9) },
		{ "JointEarL", "Head", "EarL", v(-0.85, 4.15, -3.05) },
		{ "JointEarR", "Head", "EarR", v(0.85, 4.15, -3.05) },
		{ "JointLegFL", "Chest", "UpperLegFL", v(-F, 2.9, ZF) },
		{ "JointLowerLegFL", "UpperLegFL", "LowerLegFL", v(-F, 1.55, ZF) },
		{ "JointHoofFL", "LowerLegFL", "HoofFL", v(-F, 0.5, ZF) },
		{ "JointLegFR", "Chest", "UpperLegFR", v(F, 2.9, ZF) },
		{ "JointLowerLegFR", "UpperLegFR", "LowerLegFR", v(F, 1.55, ZF) },
		{ "JointHoofFR", "LowerLegFR", "HoofFR", v(F, 0.5, ZF) },
		{ "JointLegBL", "Hips", "UpperLegBL", v(-B, 3.0, ZB) },
		{ "JointLowerLegBL", "UpperLegBL", "LowerLegBL", v(-B, 1.7, ZB + 0.1) },
		{ "JointHoofBL", "LowerLegBL", "HoofBL", v(-B, 0.5, ZB) },
		{ "JointLegBR", "Hips", "UpperLegBR", v(B, 3.0, ZB) },
		{ "JointLowerLegBR", "UpperLegBR", "LowerLegBR", v(B, 1.7, ZB + 0.1) },
		{ "JointHoofBR", "LowerLegBR", "HoofBR", v(B, 0.5, ZB) },
		{ "JointTail", "Hips", "Tail", v(0, 4.1, 3.15) },
		{ "JointTailTip", "Tail", "TailTip", v(0, 3.55, 3.7) },
	},
})
