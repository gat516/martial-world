--!nocheck
-- Outer Sect Disciple: a rival sect's outer disciple in a clean white and blue
-- uniform, the sect's sword-cloud emblem on chest and back, a silver guan on the
-- topknot with blue ribbons, and a spear. Silhouette: the tall spear and the
-- ribbons; colour: the only white-and-blue figure in the roster.
-- Run in Edit mode through execute_luau; rebuilds _RosterCultivators.OuterSectDisciple.

local BASE = "http://127.0.0.1:8767/cultivators/"
local L = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "lib.luau?" .. os.clock()))()
local v = L.v

-- Tunables ------------------------------------------------------------------------
local WHITE = Color3.fromHex("ECEEF0")
local WHITE_SH = Color3.fromHex("C9CED6")
local BLUE = Color3.fromHex("2D5DA6")
local BLUE_DK = Color3.fromHex("1E3A6B")
local SILVER = Color3.fromHex("B9C2CC")
local HAIR = Color3.fromHex("1D1C22")
local SKIN = Color3.fromHex("EBC29C")
local GLOW = Color3.fromHex("6FC8FF") -- tell: the emblem's core
-- ----------------------------------------------------------------------------------

local b = L.begin("OuterSectDisciple", { skin = SKIN, torso = WHITE, legs = BLUE_DK })
L.robe(b, { outer = WHITE, trim = BLUE, inner = WHITE_SH, sash = BLUE, hipLen = 0.65, hem = 0.6,
	sleeveColor = WHITE, cuff = BLUE })
-- sash knot tails at the left hip
for i, x in { -0.55, -0.32 } do
	b.block("Torso", "SashTail" .. i, v(0.18, 0.6, 0.06), v(x, 1.85, -0.68), BLUE_DK, CFrame.Angles(0, 0, 0.08 * i))
end
-- blue leg wraps above the boots
for _, s in { -1, 1 } do
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	b.block(leg, "Wrap", v(1.06, 0.22, 1.06), v(s * 0.5, 0.36, 0), WHITE_SH)
end

-- sect emblem: a blue disc with a white sword over a cloud, front and back
local function emblem(z, dir, tell)
	b.cyl("Torso", "Emblem" .. (tell and "" or "Back"), 0.72, 0.05, v(0.38, 3.3, z), BLUE, CFrame.Angles(math.pi / 2, 0, 0))
	b.block("Torso", "EmblemSword" .. (tell and "" or "Back"), v(0.08, 0.5, 0.05), v(0.38, 3.33, z + dir * 0.02), WHITE)
	b.block("Torso", "EmblemCloud" .. (tell and "" or "Back"), v(0.4, 0.1, 0.05), v(0.38, 3.15, z + dir * 0.02), WHITE)
	if tell then
		b.block("Torso", "TellEmblem", v(0.12, 0.12, 0.05), v(0.38, 3.46, z + dir * 0.03), GLOW,
			CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
	end
end
emblem(-0.6, -1, true)
b.cyl("Torso", "EmblemBackDisc", 1.1, 0.05, v(0, 3.3, 0.6), BLUE, CFrame.Angles(math.pi / 2, 0, 0))
b.block("Torso", "EmblemBackSword", v(0.12, 0.8, 0.05), v(0, 3.35, 0.62), WHITE)
b.block("Torso", "EmblemBackCloud", v(0.62, 0.14, 0.05), v(0, 3.05, 0.62), WHITE)

-- face and hair: neat black hair with a topknot, a silver guan on the knot, blue
-- ribbons streaming behind
L.face(b, { eye = Color3.fromHex("1A1A20"), brow = HAIR, scowl = 0.18, eyeW = 0.2, eyeH = 0.14, eyeTilt = 0.05 })
L.accessory(b, "Kate Hair", { color = HAIR })
local knot = v(0, 5.5, 0.64) -- on the bun at the back of the crown
b.block("Head", "Guan", v(0.52, 0.42, 0.66), knot + v(0, 0.08, 0), SILVER)
b.block("Head", "GuanBand", v(0.56, 0.12, 0.7), knot + v(0, -0.06, 0), BLUE)
b.cyl("Head", "GuanPin", 0.08, 1.0, knot + v(0, 0.12, 0), SILVER, CFrame.Angles(0, 0, math.pi / 2))
for _, s in { -1, 1 } do
	b.block("Head", "Ribbon" .. s, v(0.14, 1.0, 0.04), v(s * 0.12, 4.75, 0.66), BLUE, CFrame.Angles(0.25, 0, s * 0.12))
end
b.block("Head", "Headband", v(1.28, 0.12, 1.28), v(0, 4.92, 0), BLUE)

L.weapon(b, "Spear", "Hilt")
return L.finish(b, { healthBarY = 3.3 })
