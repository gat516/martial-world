--!nocheck
-- Bandit Chief (elite): a former border officer turned warlord. Built at R6 size, then
-- scaled by SCALE. Iron lamellar over a blood-red coat, a bronze chest mirror, layered
-- pauldrons, a shaggy fur mantle, a horned iron helm with a red plume, a scarred bearded
-- face and a guandao (the silhouette: broad, horned, with a long pole).
-- Run in Edit mode through execute_luau; rebuilds ServerStorage._RosterBandits.BanditChief.
-- Keyable joints (RIGS.md): Hilt (guandao), Cape1 > Cape2, Plume, SkirtL/SkirtR.

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
block("Torso", "Cuirass", v(2.06, 1.45, 1.14), v(0, 3.2, 0), IRON)
for i, y in { 3.75, 3.35, 2.95, 2.6 } do
	block("Torso", "Lamellar" .. i, v(2.1, 0.07, 1.18), v(0, y, 0), IRON_DK)
end
B.cyl(ctx, "Torso", "ChestMirror", v(0, 3.3, -0.58), v(0, 3.3, -0.7), 0.85, BRONZE)
B.cyl(ctx, "Torso", "ChestMirrorBoss", v(0, 3.3, -0.66), v(0, 3.3, -0.74), 0.35, IRON_DK)
block("Torso", "Belt", v(2.12, 0.4, 1.2), v(0, 2.3, 0), Color3.fromHex("2A201A"))
block("Torso", "BeltPlaque", v(0.6, 0.48, 0.1), v(0, 2.3, -0.62), BRONZE)
block("Torso", "BeltPlaqueFace", v(0.3, 0.16, 0.06), v(0, 2.32, -0.68), IRON_DK)
-- coat skirt and iron tassets over the thighs: one half per leg (SkirtL/SkirtR joints at
-- the hip, riding the leg so a stride never pokes through), its tassets welded to it
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	local half = block("Torso", "Skirt" .. side, v(1.03, 0.7, 1.1), v(s * 0.515, 1.75, 0), COAT)
	block(half.Name, "Tasset" .. side, v(0.95, 0.75, 0.1), v(s * 0.5, 1.72, -0.6), IRON, CFrame.Angles(-0.08, 0, 0))
	block(half.Name, "TassetTrim" .. side, v(0.95, 0.08, 0.12), v(s * 0.5, 1.37, -0.63), BRONZE, CFrame.Angles(-0.08, 0, 0))
	block(half.Name, "TassetSide" .. side, v(0.1, 0.75, 0.9), v(s * 1.08, 1.75, 0), IRON)
	block(half.Name, "TassetBack" .. side, v(1.0, 0.75, 0.1), v(s * 0.5, 1.72, 0.6), IRON, CFrame.Angles(0.08, 0, 0))
	B.joint(ctx, half, leg, v(s * 0.5, 2, 0))
end
B.tri(ctx, "Torso", "Tabard", v(0, 1.4, -0.58), 0.55, 0.55, 0.06, COAT_DK, DOWN)

-- Fur mantle: a shaggy collar round the neck and a short cape down the back ---------
block("Torso", "MantleBack", v(1.8, 0.75, 0.75), v(0, 4.05, 0.38), FUR)
block("Torso", "MantleFront", v(1.8, 0.36, 0.5), v(0, 3.84, -0.42), FUR) -- proud of the cuirass so the fur reads
-- the cape in two jointed panels down the back (Cape1 from the mantle, Cape2 below it)
local cape1 = block("Torso", "Cape1", v(2.0, 0.94, 0.22), v(0, 3.43, 0.7), FUR)
local cape2 = block("Torso", "Cape2", v(2.0, 0.86, 0.22), v(0, 2.64, 0.7), FUR)
for i = 1, 6 do
	local x = -0.825 + (i - 1) * 0.33
	B.tri(ctx, "Cape2", "CapeTuft" .. i, v(x, 2.21, 0.7), 0.3 + (i % 2) * 0.2, 0.38, 0.2, if i % 2 == 0 then FUR else FUR_LT, DOWN)
end
B.joint(ctx, cape1, "Torso", v(0, 3.9, 0.7))
B.joint(ctx, cape2, "Cape1", v(0, 3.05, 0.7))
for _, s in { -1, 1 } do
	-- tufts bristling up and out over the shoulders: the mantle widens the silhouette
	for i, z in { -0.35, 0.05, 0.45 } do
		-- they ride the arm (fur over the pauldron), so a raised arm carries them instead of
		-- driving its pauldrons through them; the mantle itself stays inside |x| < 1
		fin(if s < 0 then "Left Arm" else "Right Arm", "MantleTuft" .. s .. i, v(s * (1.24 + i * 0.04), 4.22, z), -- outboard of x 1.2: overhead they still clear the torso
			0.55 + i * 0.05, 0.45, 0.3, FUR, 0.3, -s * (0.5 + i * 0.1))
	end
	fin("Torso", "MantleFrontTuft" .. s, v(s * 0.8, 3.75, -0.6), 0.4, 0.35, 0.25, FUR, math.pi + 0.3, s * 0.2)
end

-- Arms: layered pauldrons and iron bracers ----------------------------------------------
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	local x = s * 1.5
	block(arm, "Pauldron1", v(1.25, 0.32, 1.35), v(x + s * 0.13, 4.02, 0), IRON, CFrame.Angles(0, 0, -s * 0.3))
	block(arm, "Pauldron2", v(1.2, 0.3, 1.3), v(x + s * 0.23, 3.72, 0), IRON, CFrame.Angles(0, 0, -s * 0.45))
	block(arm, "PauldronTrim", v(1.22, 0.07, 1.32), v(x + s * 0.32, 3.55, 0), BRONZE, CFrame.Angles(0, 0, -s * 0.45))
	block(arm, "Bracer", v(1.08, 0.8, 1.12), v(x, 2.55, 0), IRON)
	block(arm, "BracerTrim", v(1.1, 0.08, 1.14), v(x, 2.95, 0), BRONZE)
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
local plume = B.cyl(ctx, "Head", "Plume", v(0, 5.45, 0), v(0, 5.75, 0), 0.18, BRONZE)
B.joint(ctx, plume, "Head", v(0, 5.45, 0))
for i, a in { 0, 1.3, 2.6, 3.9, 5.2 } do
	fin("Plume", "PlumeFeather" .. i, v(0, 5.7, 0), 0.75, 0.35, 0.12, if i % 2 == 0 then COAT else Color3.fromHex("9C2B2B"), 0.55, 0, a)
end
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- the horns: two-stage curve sweeping up and out from the brow band
	fin("Head", "Horn" .. side, v(s * 0.62, 4.95, 0.05), 0.75, 0.32, 0.26, BRONZE, 0, -s * 0.85)
	fin("Head", "HornTip" .. side, v(s * 1.15, 5.45, 0.05), 0.55, 0.22, 0.2, BRONZE, 0, -s * 0.2)
	block("Head", "CheekGuard" .. side, v(0.12, 0.6, 0.6), v(s * 0.7, 4.45, -0.08), IRON, CFrame.Angles(0, 0, s * 0.12))
	local eye = block("Head", "Eye" .. side, v(0.24, 0.11, 0.06), v(s * 0.26, 4.58, -0.615), EYE,
		CFrame.Angles(0, 0, s * 0.18), Enum.Material.Neon)
	eye:SetAttribute("Tell", true)
	block("Head", "Brow" .. side, v(0.42, 0.15, 0.1), v(s * 0.27, 4.74, -0.6), HAIR, CFrame.Angles(0, 0, s * 0.4))
	block("Head", "Moustache" .. side, v(0.4, 0.1, 0.08), v(s * 0.2, 4.28, -0.62), HAIR, CFrame.Angles(0, 0, -s * 0.35))
end
block("Head", "Beard", v(1.05, 0.4, 0.34), v(0, 4.05, -0.56), HAIR)
B.tri(ctx, "Head", "BeardPoint", v(0, 3.86, -0.72), 0.38, 0.7, 0.22, HAIR, DOWN) -- proud of the chest so a turned head clears it
block("Head", "Mouth", v(0.3, 0.05, 0.05), v(0, 4.18, -0.62), Color3.fromHex("3A1E18"))
-- a scar slashing over the left eye, and one across the right cheek
block("Head", "ScarEye", v(0.07, 0.6, 0.05), v(-0.27, 4.62, -0.63), SCAR, CFrame.Angles(0, 0, 0.3))
block("Head", "ScarCheek", v(0.3, 0.06, 0.05), v(0.38, 4.38, -0.62), SCAR, CFrame.Angles(0, 0, -0.5))

B.weapon(ctx, WEAPON, "Right Arm")

return B.finish(ctx, {
	scale = SCALE,
	barOffset = 4.0,
	attributes = { Roster = "Bandit", Role = "elite", Placeholder = "BanditChief: R6 rig scaled 1.28, Studio-built armour; needs R6 AnimationTracks per AIState" },
})
