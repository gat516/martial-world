--!nocheck
-- Bandit Chief (elite): a former border officer turned warlord. Built at R6 size, then
-- scaled by SCALE. Iron lamellar over a blood-red coat, a bronze chest mirror, layered
-- pauldrons, a shaggy fur mantle, a horned iron helm with a red plume, a scarred bearded
-- face and a guandao (the silhouette: broad, horned, with a long pole).
-- Run in Edit mode through execute_luau; rebuilds ServerStorage._RosterBandits.BanditChief.

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8767/"
local B = loadstring(HttpService:GetAsync(BASE .. "bandits/bandit_common.luau?" .. os.clock()))()
local v = B.v

-- Tunables ----------------------------------------------------------------------------
local NAME = "BanditChief"
local SCALE = 1.28
local WEAPON = "Guandao" -- or "Dadao" for a heavy single-hand variant
local SKIN = Color3.fromHex("B07A55")
local COAT = Color3.fromHex("7A2222")
local COAT_DK = Color3.fromHex("521616")
local IRON = Color3.fromHex("4A4F57")
local IRON_DK = Color3.fromHex("33363C")
local BRONZE = Color3.fromHex("B08A42")
local FUR = Color3.fromHex("8A6A48")
local FUR_LT = Color3.fromHex("C2A57E")
local TROUSER = Color3.fromHex("2E2B2A")
local HAIR = Color3.fromHex("2A2522") -- beard, brows
local SCAR = Color3.fromHex("D7A189")
local EYE = Color3.fromHex("FF3B2B") -- the tell

local ctx = B.new(NAME, SKIN, { torso = COAT, arms = COAT, legs = TROUSER })
local function block(seg, name, size, pos, color, rot, mat)
	return B.block(ctx, seg, name, size, pos, color, rot, mat)
end
local function fin(...)
	return B.fin(ctx, ...)
end
local DOWN = CFrame.Angles(0, 0, math.pi)

-- Torso: lamellar, chest mirror, belt, tassets ------------------------------------------
block("Torso", "Cuirass", v(2.12, 1.45, 1.14), v(0, 3.2, 0), IRON)
for i, y in { 3.75, 3.35, 2.95, 2.6 } do
	block("Torso", "Lamellar" .. i, v(2.16, 0.07, 1.18), v(0, y, 0), IRON_DK)
end
B.cyl(ctx, "Torso", "ChestMirror", v(0, 3.3, -0.58), v(0, 3.3, -0.7), 0.85, BRONZE)
B.cyl(ctx, "Torso", "ChestMirrorBoss", v(0, 3.3, -0.66), v(0, 3.3, -0.74), 0.35, IRON_DK)
block("Torso", "Belt", v(2.18, 0.4, 1.2), v(0, 2.3, 0), Color3.fromHex("2A201A"))
block("Torso", "BeltPlaque", v(0.6, 0.48, 0.1), v(0, 2.3, -0.62), BRONZE)
block("Torso", "BeltPlaqueFace", v(0.3, 0.16, 0.06), v(0, 2.32, -0.68), IRON_DK)
-- coat skirt and iron tassets over the thighs
block("Torso", "CoatSkirt", v(2.06, 0.7, 1.1), v(0, 1.75, 0), COAT)
for _, s in { -1, 1 } do
	block("Torso", "Tasset" .. s, v(0.95, 0.75, 0.1), v(s * 0.5, 1.72, -0.6), IRON, CFrame.Angles(-0.08, 0, 0))
	block("Torso", "TassetTrim" .. s, v(0.95, 0.08, 0.12), v(s * 0.5, 1.37, -0.63), BRONZE, CFrame.Angles(-0.08, 0, 0))
	block("Torso", "TassetSide" .. s, v(0.1, 0.75, 0.9), v(s * 1.08, 1.75, 0), IRON)
end
block("Torso", "TassetBack", v(1.9, 0.75, 0.1), v(0, 1.72, 0.6), IRON, CFrame.Angles(0.08, 0, 0))
B.tri(ctx, "Torso", "Tabard", v(0, 1.4, -0.58), 0.55, 0.55, 0.06, COAT_DK, DOWN)

-- Fur mantle: a shaggy collar round the neck and a short cape down the back ---------
block("Torso", "MantleBack", v(2.5, 0.75, 0.75), v(0, 4.05, 0.38), FUR)
block("Torso", "MantleFront", v(2.2, 0.4, 0.4), v(0, 3.88, -0.38), FUR)
block("Torso", "Cape", v(2.3, 1.7, 0.22), v(0, 3.05, 0.7), FUR)
for i = 1, 6 do
	local x = -1.05 + (i - 1) * 0.42
	B.tri(ctx, "Torso", "CapeTuft" .. i, v(x, 2.21, 0.7), 0.3 + (i % 2) * 0.2, 0.46, 0.2, if i % 2 == 0 then FUR else FUR_LT, DOWN)
end
for _, s in { -1, 1 } do
	-- tufts bristling up and out over the shoulders: the mantle widens the silhouette
	for i, z in { -0.35, 0.05, 0.45 } do
		fin("Torso", "MantleTuft" .. s .. i, v(s * (1.0 + i * 0.05), 4.25, z), 0.55 + i * 0.05, 0.45, 0.3,
			if i == 2 then FUR_LT else FUR, 0.3, -s * (0.9 + i * 0.1))
	end
	fin("Torso", "MantleFrontTuft" .. s, v(s * 0.8, 3.75, -0.55), 0.4, 0.35, 0.25, FUR_LT, math.pi + 0.3, s * 0.2)
end

-- Arms: layered pauldrons and iron bracers ----------------------------------------------
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	local x = s * 1.5
	block(arm, "Pauldron1", v(1.35, 0.32, 1.35), v(x + s * 0.08, 4.02, 0), IRON, CFrame.Angles(0, 0, -s * 0.3))
	block(arm, "Pauldron2", v(1.3, 0.3, 1.3), v(x + s * 0.18, 3.72, 0), IRON, CFrame.Angles(0, 0, -s * 0.45))
	block(arm, "PauldronTrim", v(1.32, 0.07, 1.32), v(x + s * 0.27, 3.55, 0), BRONZE, CFrame.Angles(0, 0, -s * 0.45))
	block(arm, "Bracer", v(1.12, 0.8, 1.12), v(x, 2.55, 0), IRON)
	block(arm, "BracerTrim", v(1.14, 0.08, 1.14), v(x, 2.95, 0), BRONZE)
	block(arm, "Hand", v(1.02, 0.18, 1.02), v(x, 2.07, 0), SKIN)
end

-- Legs: greaves and heavy boots --------------------------------------------------------
for _, s in { -1, 1 } do
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	local x = s * 0.5
	block(leg, "Greave", v(1.1, 0.75, 1.1), v(x, 0.75, 0), IRON)
	block(leg, "GreaveKnee", v(0.7, 0.3, 0.12), v(x, 1.15, -0.56), BRONZE)
	block(leg, "Boot", v(1.12, 0.38, 1.25), v(x, 0.19, -0.06), Color3.fromHex("2A201A"))
end

-- Head: horned helm, plume, cheek guards, beard, scar ----------------------------------
block("Head", "HelmBowl", v(1.38, 0.5, 1.38), v(0, 5.0, 0), IRON)
block("Head", "HelmCrown", v(1.0, 0.25, 1.0), v(0, 5.35, 0), IRON)
block("Head", "HelmBrow", v(1.44, 0.2, 1.44), v(0, 4.82, 0), BRONZE)
fin("Head", "HelmBrowPeak", v(0, 4.78, -0.72), 0.3, 0.12, 0.5, BRONZE, math.pi)
B.cyl(ctx, "Head", "PlumeStem", v(0, 5.45, 0), v(0, 5.75, 0), 0.18, BRONZE)
for i, a in { 0, 1.3, 2.6, 3.9, 5.2 } do
	fin("Head", "Plume" .. i, v(0, 5.7, 0), 0.75, 0.35, 0.12, if i % 2 == 0 then COAT else Color3.fromHex("9C2B2B"), 0.55, 0, a)
end
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- the horns: two-stage curve sweeping up and out from the brow band
	fin("Head", "Horn" .. side, v(s * 0.62, 4.95, 0.05), 0.75, 0.32, 0.26, BRONZE, 0, -s * 0.85)
	fin("Head", "HornTip" .. side, v(s * 1.15, 5.45, 0.05), 0.55, 0.22, 0.2, BRONZE, 0, -s * 0.2)
	block("Head", "CheekGuard" .. side, v(0.12, 0.6, 0.85), v(s * 0.7, 4.45, 0.05), IRON, CFrame.Angles(0, 0, s * 0.12))
	local eye = block("Head", "Eye" .. side, v(0.24, 0.11, 0.06), v(s * 0.26, 4.58, -0.615), EYE,
		CFrame.Angles(0, 0, s * 0.18), Enum.Material.Neon)
	eye:SetAttribute("Tell", true)
	block("Head", "Brow" .. side, v(0.42, 0.15, 0.1), v(s * 0.27, 4.74, -0.6), HAIR, CFrame.Angles(0, 0, s * 0.4))
	block("Head", "Moustache" .. side, v(0.4, 0.1, 0.08), v(s * 0.2, 4.28, -0.62), HAIR, CFrame.Angles(0, 0, -s * 0.35))
end
block("Head", "Beard", v(1.05, 0.4, 0.34), v(0, 4.05, -0.56), HAIR)
B.tri(ctx, "Head", "BeardPoint", v(0, 3.86, -0.6), 0.45, 0.7, 0.25, HAIR, DOWN)
block("Head", "Mouth", v(0.3, 0.05, 0.05), v(0, 4.18, -0.62), Color3.fromHex("3A1E18"))
-- a scar slashing over the left eye, and one across the right cheek
block("Head", "ScarEye", v(0.07, 0.6, 0.05), v(-0.27, 4.62, -0.63), SCAR, CFrame.Angles(0, 0, 0.3))
block("Head", "ScarCheek", v(0.3, 0.06, 0.05), v(0.38, 4.38, -0.62), SCAR, CFrame.Angles(0, 0, -0.5))

B.weapon(ctx, WEAPON, "Right Arm")

return B.finish(ctx, {
	scale = SCALE,
	barOffset = 4.2,
	attributes = { Roster = "Bandit", Role = "elite", Placeholder = "BanditChief: R6 rig scaled 1.28, Studio-built armour; needs R6 AnimationTracks per AIState" },
})
