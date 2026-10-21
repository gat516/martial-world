--!nocheck
-- Stone Boar, rebuilt from Studio parts in the Spirit Wolf B style: a front-heavy
-- charger with stone hide plates, big up-curving tusks, a bristle crest and amber
-- earth-qi cracks (the tells). Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterQuadrupeds.StoneBoar_R (body only), then run rig_stone_boar.luau.
-- Model space: ground Y=0, faces -Z, left side is -X. Old StoneBoar HRP kept: 3 x 2.4 x 5
-- at Y 2.8 (rig_stone_boar.luau).

local BASE = "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local P = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/parts_lib.luau?" .. os.clock()))()("StoneBoar_R")
local v, block, ball, limb, fin, spike, tri, bevel, bevelZ, tell, add =
	P.v, P.block, P.ball, P.limb, P.fin, P.spike, P.tri, P.bevel, P.bevelZ, P.tell, P.add

-- Tunables ------------------------------------------------------------------------------
local HIDE = Color3.fromHex("7E5D45") -- warm umber hide
local HIDE_SH = Color3.fromHex("5E4535")
local STONE = Color3.fromHex("8F8B80") -- hide plates
local STONE_HI = Color3.fromHex("ABA598")
local BRISTLE = Color3.fromHex("231C18")
local BONE = Color3.fromHex("ECE3CC") -- tusks
local HOOF = Color3.fromHex("2E2925")
local SNOUT = Color3.fromHex("8C6A5C")
local CRACK = Color3.fromHex("FF8A2B") -- earth-qi tell
local LEG_X_F, LEG_Z_F = 1.15, -1.35
local LEG_X_B, LEG_Z_B = 1.05, 2.15

-- Chest (the hump) and hips ----------------------------------------------------------------
-- The chest is the big front mass; the back slopes down to small hips, so the silhouette
-- is a wedge pointing at whatever it charges.
block("Chest", "Chest", v(3.2, 2.6, 3.4), v(0, 3.4, -0.6), HIDE)
block("Chest", "ChestTop", v(2.2, 0.8, 3.2), v(0, 5.05, -0.6), HIDE)
for _, s in { -1, 1 } do
	bevel("Chest", "ChestShoulder" .. s, v(s * 1.35, 5.05, -0.6), 0.5, 0.8, 3.2, s, HIDE)
end
block("Hips", "Hips", v(2.8, 2.2, 2.3), v(0, 3.3, 2.0), HIDE)
block("Hips", "HipsTop", v(1.8, 0.6, 2.1), v(0, 4.65, 1.9), HIDE)
bevelZ("Hips", "HipsRump", v(0, 3.85, 3.4), 2.6, 1.1, 0.6, 1, HIDE)

-- Stone plates: overlapping slabs on the back, tipped forward so each lip overhangs the
-- next, and two flank shields per side. Amber cracks run through the shoulder shields.
local plates = {
	{ "Chest", v(2.9, 0.55, 1.5), v(0, 5.55, -1.55), -0.12 },
	{ "Chest", v(3.0, 0.55, 1.5), v(0, 5.6, -0.35), -0.08 },
	{ "Chest", v(2.7, 0.5, 1.3), v(0, 5.4, 0.8), 0.06 },
	{ "Hips", v(2.4, 0.5, 1.3), v(0, 5.0, 1.75), 0.14 },
	{ "Hips", v(2.0, 0.45, 1.1), v(0, 4.65, 2.8), 0.3 },
}
for i, p in plates do
	block(p[1], "Plate" .. i, p[2], p[3], if i % 2 == 0 then STONE_HI else STONE, CFrame.Angles(p[4], 0, 0))
end
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	block("Chest", "Shield" .. side .. "1", v(0.35, 1.7, 1.6), v(s * 1.62, 4.3, -1.35), STONE, CFrame.Angles(0, 0, -s * 0.22))
	block("Chest", "Shield" .. side .. "2", v(0.35, 1.5, 1.5), v(s * 1.55, 4.25, 0.05), STONE_HI, CFrame.Angles(0, 0, -s * 0.2))
	block("Hips", "Shield" .. side .. "3", v(0.3, 1.2, 1.3), v(s * 1.42, 4.0, 1.75), STONE, CFrame.Angles(0, 0, -s * 0.2))
	-- the tell: a forked crack across the shoulder shield
	tell(block("Chest", "Crack" .. side .. "1", v(0.08, 1.0, 0.14), v(s * 1.79, 4.3, -1.45), CRACK, CFrame.Angles(0.5, 0, -s * 0.22)))
	tell(block("Chest", "Crack" .. side .. "2", v(0.08, 0.55, 0.12), v(s * 1.82, 4.55, -1.05), CRACK, CFrame.Angles(-0.6, 0, -s * 0.22)))
end
tell(block("Chest", "CrackBack", v(0.16, 0.08, 2.4), v(0, 5.86, -0.9), CRACK))

-- Bristle crest: black spikes bursting from the seams between the plates, tallest over
-- the hump, running from the shoulders to the rump (a nape spike read head-on as a black
-- chimney over the brow, so it went).
local crest = {
	{ "Chest", v(0, 5.75, -1.95), 1.05, 0.5 },
	{ "Chest", v(0, 5.85, -0.95), 1.15, 0.55 },
	{ "Chest", v(0, 5.8, 0.2), 0.95, 0.6 },
	{ "Hips", v(0, 5.2, 1.2), 0.75, 0.7 },
	{ "Hips", v(0, 4.85, 2.3), 0.55, 0.8 },
}
for i, c in crest do
	fin(c[1], "Bristle" .. i, c[2], c[3], 0.8, 0.35, BRISTLE, c[4])
end

-- Neck, head, snout and tusks ---------------------------------------------------------------
block("Neck", "Neck", v(2.3, 1.75, 1.3), v(0, 3.4, -2.4), HIDE)
block("Neck", "NeckJowl", v(2.0, 0.8, 1.1), v(0, 2.45, -2.55), HIDE_SH)

block("Head", "Head", v(2.3, 2.0, 1.9), v(0, 3.25, -3.6), HIDE)
bevelZ("Head", "Forehead", v(0, 4.5, -3.75), 1.9, 0.5, 1.2, -1, HIDE)
block("Head", "BrowPlate", v(2.0, 0.45, 1.1), v(0, 4.15, -4.0), STONE, CFrame.Angles(0.35, 0, 0))
block("Head", "Snout", v(1.6, 1.25, 1.6), v(0, 2.9, -5.05), HIDE)
add("Head", "SnoutTop", "WedgePart", v(1.3, 0.45, 1.3), CFrame.new(0, 3.75, -5.0), HIDE_SH)
local disc = add("Head", "NosePad", "Part", v(0.3, 1.0, 1.0), CFrame.new(0, 2.92, -5.9) * CFrame.Angles(0, math.pi / 2, 0), SNOUT)
disc.Shape = Enum.PartType.Cylinder
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	block("Head", "Nostril" .. side, v(0.14, 0.22, 0.06), v(s * 0.22, 2.92, -6.06), HOOF)
	-- small, deep-set eyes under the heavy brow, slanted down to the snout
	tell(block("Head", "Eye" .. side, v(0.32, 0.16, 0.08), v(s * 0.72, 3.7, -4.52), CRACK, CFrame.Angles(0, 0, s * 0.3)))
	block("Head", "Brow" .. side, v(0.6, 0.22, 0.4), v(s * 0.68, 3.88, -4.45), STONE_HI, CFrame.Angles(0, 0, s * 0.3))
	-- tusks: a thick base out of the snout side, curving up and out to a point
	local a, b, c, d = v(s * 0.7, 2.5, -5.1), v(s * 1.0, 2.7, -5.75), v(s * 1.2, 3.3, -6.05), v(s * 1.15, 4.05, -5.85)
	-- (widths step down evenly and the pads only just cover each bend, so the three pieces
	-- read as one curved tusk instead of a pile of shards)
	limb("Head", "TuskBase" .. side, a, b, 0.48, 0.48, BONE, 0.16)
	limb("Head", "TuskMid" .. side, b, c, 0.42, 0.42, BONE, 0.14)
	spike("Head", "Tusk" .. side, c, d, 0.4, BONE)
	-- ears: small, stiff, angled back
	tri("Ear" .. side, "Ear" .. side, v(s * 0.85, 4.15, -3.05), 0.75, 0.6, 0.2, HIDE_SH, CFrame.Angles(-0.5, 0, -s * 0.5))
end

block("Jaw", "Jaw", v(1.4, 0.45, 1.6), v(0, 2.1, -4.75), HIDE_SH)
block("Jaw", "JawMouth", v(1.1, 0.12, 1.2), v(0, 2.34, -4.8), Color3.fromHex("5A2A2A"))
for _, s in { -1, 1 } do
	fin("Jaw", "LowerTusk" .. (if s < 0 then "L" else "R"), v(s * 0.5, 2.3, -5.35), 0.35, 0.18, 0.14, BONE)
end

-- Legs: short, thick columns with split hooves -----------------------------------------------
local function hoof(seg, x, z, color)
	block(seg, seg, v(0.9, 0.5, 1.0), v(x, 0.25, z), color)
	-- one toe wedge across the front (the split pair cost 4 parts and read only up close)
	add(seg, seg .. "Toe", "WedgePart", v(0.82, 0.4, 0.35), CFrame.new(x, 0.2, z - 0.62), HOOF)
end
for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local x, z = s * LEG_X_F, LEG_Z_F
	block("UpperLeg" .. f, "UpperLeg" .. f, v(1.05, 1.5, 1.15), v(x, 2.25, z), HIDE)
	ball("UpperLeg" .. f, "Shoulder" .. f, 1.08, v(x, 2.9, z), HIDE) -- just proud of the leg, not a knob
	block("LowerLeg" .. f, "LowerLeg" .. f, v(0.75, 1.15, 0.8), v(x, 1.05, z), HIDE_SH)
	ball("LowerLeg" .. f, "Elbow" .. f, 0.85, v(x, 1.55, z), HIDE_SH)
	hoof("Hoof" .. f, x, z, HOOF)

	local b = if s < 0 then "BL" else "BR"
	x, z = s * LEG_X_B, LEG_Z_B
	block("UpperLeg" .. b, "UpperLeg" .. b, v(1.1, 1.5, 1.35), v(x, 2.4, z + 0.05), HIDE)
	ball("UpperLeg" .. b, "Haunch" .. b, 1.18, v(x, 3.0, z), HIDE)
	limb("LowerLeg" .. b, "LowerLeg" .. b, v(x, 1.7, z + 0.15), v(x, 0.55, z + 0.05), 0.72, 0.78, HIDE_SH, 0.3)
	ball("LowerLeg" .. b, "Knee" .. b, 0.85, v(x, 1.7, z + 0.1), HIDE_SH)
	hoof("Hoof" .. b, x, z, HOOF)
end

-- Tail: a short whip with a bristle tuft ----------------------------------------------------
limb("Tail", "Tail", v(0, 4.1, 3.15), v(0, 3.55, 3.7), 0.3, 0.3, HIDE_SH, 0.15)
limb("TailTip", "TailTip", v(0, 3.55, 3.7), v(0, 2.9, 3.85), 0.22, 0.22, HIDE_SH, 0.1)
fin("TailTip", "TailTuft", v(0, 3.0, 3.85), 0.5, 0.35, 0.3, BRISTLE, math.pi - 0.2)

return P.place("_RosterQuadrupeds")
