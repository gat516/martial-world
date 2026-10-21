--!nocheck
-- Blood Sect Cultist: a pack fanatic of the Blood Sect in a hooded red robe, the
-- face lost in shadow but for two red points, a wavy ritual dagger in hand and
-- yellow talismans hanging from the belt. Silhouette: the pointed hood.
-- Run in Edit mode through execute_luau; rebuilds _RosterCultivators.BloodSectCultist.

local BASE = "http://127.0.0.1:8767/cultivators/"
local L = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "lib.luau?" .. os.clock()))()
local v = L.v

-- Tunables ------------------------------------------------------------------------
local RED = Color3.fromHex("9A1C1E")
local RED_SH = Color3.fromHex("6E1216")
local MAROON = Color3.fromHex("3E0C10")
local SHADOW = Color3.fromHex("140B0C")
local LEATHER = Color3.fromHex("3A2A22")
local PAPER = Color3.fromHex("E6C35A")
local INK = Color3.fromHex("5A0C0E")
local STEEL = Color3.fromHex("A9A9B0")
local SKIN = Color3.fromHex("D2A98A")
local GLOW = Color3.fromHex("FF3030") -- tells: eyes, dagger edge, forehead sigil
local HOOD_PEAK = 0.95
-- ----------------------------------------------------------------------------------

local b = L.begin("BloodSectCultist", { skin = SKIN, torso = RED, legs = MAROON })
L.robe(b, { outer = RED, trim = MAROON, inner = MAROON, sash = LEATHER, hipLen = 0.7, hem = 0.45,
	sleeveColor = RED, cuff = MAROON })

-- hood: a cowl round the head, a peak raked back, a shadowed opening at the front
-- and a short capelet over the shoulders
b.block("Head", "Hood", v(1.5, 1.4, 1.45), v(0, 4.6, 0.06), RED)
b.bevel("Head", "HoodSlopeL", v(-0.55, 5.4, 0.06), 0.4, 0.3, 1.45, -1, RED)
b.bevel("Head", "HoodSlopeR", v(0.55, 5.4, 0.06), 0.4, 0.3, 1.45, 1, RED)
b.block("Head", "HoodTop", v(0.7, 0.3, 1.45), v(0, 5.4, 0.06), RED)
b.joint(b.fin("Head", "HoodPeak", v(0, 5.5, 0.2), HOOD_PEAK, 1.0, 0.62, RED_SH, 0.55), v(0, 5.5, 0.2))
b.block("Head", "HoodRim", v(1.2, 1.18, 0.12), v(0, 4.52, -0.69), MAROON)
b.block("Head", "HoodShadow", v(0.96, 0.96, 0.06), v(0, 4.48, -0.74), SHADOW)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	b.block("Head", "TellEye" .. side, v(0.14, 0.09, 0.05), v(s * 0.2, 4.55, -0.78), GLOW,
		CFrame.Angles(0, 0, s * 0.25), Enum.Material.Neon)
end
b.block("Head", "TellSigil", v(0.18, 0.18, 0.05), v(0, 5.0, -0.765), GLOW, CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
b.block("Torso", "Capelet", v(2.3, 0.5, 1.36), v(0, 3.9, 0.02), RED_SH)
b.joint(b.block("Torso", "CapeletDrape", v(1.5, 0.9, 0.12), v(0, 3.5, 0.66), RED_SH), v(0, 3.95, 0.66))

-- talismans: yellow papers with red script hanging off the front and back of the
-- belt, short enough to stay clear of the leg swing
local function talisman(name, at, tilt)
	-- each is a keyable joint hinged where it's tucked into the belt; the ink rides it
	local frame = CFrame.new(at) * CFrame.Angles(0, 0, tilt)
	local paper = b.add("Torso", name, "Part", v(0.26, 0.6, 0.04), frame * CFrame.new(0, -0.3, 0), PAPER)
	b.joint(paper, at)
	local face = if at.Z < 0 then -1 else 1
	b.ride(b.add("Torso", name .. "Ink", "Part", v(0.05, 0.34, 0.02), frame * CFrame.new(0, -0.3, face * 0.025), INK), paper)
end
for i, x in { -0.72, -0.4, 0.45 } do
	talisman("Talisman" .. i, v(x, 2.15, -0.64), (i - 2) * 0.08)
end
talisman("TalismanBack", v(0.5, 2.15, 0.64), -0.05)

-- ritual dagger: a wavy kris blade held point-forward in the right hand
local hand = v(1.5, 2.05, 0)
-- keyable: joint Dagger, pivot at the grip in the fist; every blade piece rides it
local dagger = b.block("Right Arm", "Dagger", v(0.2, 0.2, 0.62), hand + v(0, 0, -0.18), LEATHER)
b.joint(dagger, hand + v(0, 0, -0.1))
b.ride(b.block("Right Arm", "DaggerGuard", v(0.5, 0.16, 0.14), hand + v(0, 0, -0.55), MAROON), dagger)
b.ride(b.ball("Right Arm", "DaggerPommel", 0.24, hand + v(0, 0, 0.18), MAROON), dagger)
for i = 1, 3 do
	local z = -0.72 - (i - 1) * 0.32
	b.ride(b.block("Right Arm", "DaggerBlade" .. i, v(0.07, 0.22, 0.38), hand + v(0, 0, z), STEEL,
		CFrame.Angles(0, (if i % 2 == 0 then 1 else -1) * 0.22, 0)), dagger)
end
b.ride(b.add("Right Arm", "DaggerTip", "WedgePart", v(0.07, 0.2, 0.36), CFrame.new(hand + v(0, 0, -1.58)) * CFrame.Angles(math.pi / 2, 0, 0), STEEL), dagger)
b.ride(b.block("Right Arm", "TellBladeEdge", v(0.08, 0.04, 0.9), hand + v(0, -0.12, -1.05), GLOW, nil, Enum.Material.Neon), dagger)

return L.finish(b, { healthBarY = 3.7 })
