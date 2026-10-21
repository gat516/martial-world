--!nocheck
-- Sect Elder (boss): an elder of the rival sect, 1.2x a player, in layered white
-- and gold robes over jade, very wide sleeves, a tall gold crown on white hair, a
-- long white beard, a fly-whisk, a jade bi pendant and a fan of floating
-- talismans behind his back. Silhouette: the talisman fan and the crown.
-- Run in Edit mode through execute_luau; rebuilds _RosterCultivators.SectElder.

local BASE = "http://127.0.0.1:8767/cultivators/"
local L = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "lib.luau?" .. os.clock()))()
local v = L.v

-- Tunables ------------------------------------------------------------------------
local SCALE = 1.2
local WHITE = Color3.fromHex("F1ECE0")
local WHITE_SH = Color3.fromHex("D3CCBB")
local GOLD = Color3.fromHex("C9A23A")
local JADE = Color3.fromHex("3E8C6E")
local JADE_DK = Color3.fromHex("27604B")
local HAIR = Color3.fromHex("EDEDEA")
local LACQUER = Color3.fromHex("7A2A20")
local PAPER = Color3.fromHex("EAD17A")
local SKIN = Color3.fromHex("E6BE9A")
local GLOW_GOLD = Color3.fromHex("FFC94A") -- tells: talisman glyphs, crown gem
local GLOW_JADE = Color3.fromHex("5CFFB8") -- tell: pendant core
local TALISMANS = 5
local FAN_R = 2.3 -- fan radius behind the back
-- ----------------------------------------------------------------------------------

local b = L.begin("SectElder", { skin = SKIN, torso = WHITE, legs = WHITE_SH })
L.robe(b, { outer = WHITE, trim = GOLD, inner = JADE, sash = JADE_DK, hipLen = 0.7, hem = 0.18,
	sleeve = "wide", sleeveColor = WHITE, cuff = GOLD })

-- the outer layer: an open overcoat whose gold-edged fronts hang either side of the
-- chest, and per-leg coat tails at the back, longer than the robe
for _, s in { -1, 1 } do
	b.block("Torso", "CoatFront", v(0.42, 2.1, 0.08), v(s * 0.86, 3.0, -0.62), WHITE_SH)
	b.block("Torso", "CoatEdge", v(0.1, 2.1, 0.1), v(s * 0.62, 3.0, -0.63), GOLD)
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	b.block(leg, "CoatTail", v(1.0, 1.55, 0.1), v(s * 0.5, 0.98, 0.66), WHITE_SH)
	b.block(leg, "CoatTailHem", v(1.04, 0.16, 0.12), v(s * 0.5, 0.25, 0.66), GOLD)
end
b.block("Torso", "Mantle", v(2.3, 0.36, 1.3), v(0, 3.94, 0.02), WHITE_SH)
b.block("Torso", "MantleTrim", v(2.34, 0.1, 1.34), v(0, 3.74, 0.02), GOLD)

-- jade bi pendant on a gold cord below the sash
b.limb("Torso", "PendantCord", v(0, 2.22, -0.66), v(0, 1.72, -0.7), 0.05, 0.05, GOLD)
b.cyl("Torso", "Pendant", 0.5, 0.1, v(0, 1.55, -0.72), JADE, CFrame.Angles(math.pi / 2, 0, 0))
b.cyl("Torso", "TellJade", 0.18, 0.12, v(0, 1.55, -0.73), GLOW_JADE, CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Neon)
b.block("Torso", "PendantTassel", v(0.1, 0.4, 0.06), v(0, 1.12, -0.72), GOLD)

-- head: white hair in a high knot, a tall gold crown, a long white beard
L.face(b, { eye = Color3.fromHex("2A2A2A"), brow = HAIR, scowl = 0.35, eyeW = 0.22, eyeH = 0.1, eyeTilt = 0.1 })
L.accessory(b, "LavanderHair", { color = HAIR })
L.accessory(b, "WizardBeard", { color = HAIR })
local crown = v(0, 5.35, 0.05)
b.block("Head", "Crown", v(0.6, 0.62, 0.8), crown + v(0, 0.2, 0), GOLD)
b.block("Head", "CrownTop", v(0.86, 0.12, 1.0), crown + v(0, 0.56, 0), GOLD)
b.fin("Head", "CrownFin", crown + v(0, 0.62, 0.15), 0.55, 0.7, 0.14, GOLD, 0.25)
b.block("Head", "TellCrownGem", v(0.2, 0.2, 0.06), crown + v(0, 0.22, -0.42), GLOW_GOLD, CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
b.cyl("Head", "CrownPin", 0.1, 1.3, crown + v(0, 0.15, 0), JADE, CFrame.Angles(0, 0, math.pi / 2))

-- fly-whisk: a lacquered handle angled up out of the right sleeve, the white
-- horsehair falling over the forearm
local grip = v(1.5, 2.0, -0.35)
local top = v(1.5, 2.75, -1.05)
b.limb("Right Arm", "WhiskHandle", grip, top, 0.16, 0.16, LACQUER, 0.1)
b.ball("Right Arm", "WhiskCap", 0.26, top, GOLD)
for i, dx in { -0.12, 0, 0.12 } do
	b.limb("Right Arm", "WhiskHair" .. i, top + v(dx, 0, 0), v(1.5 + dx * 2.2, 1.35, -1.25 + math.abs(dx)), 0.14, 0.14, HAIR, 0.08)
end

-- floating talismans: a fan of papers behind the back, welded to the Torso (the one
-- deliberate float), each with a glowing glyph that flares on windup
for i = 1, TALISMANS do
	local a = (i - (TALISMANS + 1) / 2) * 0.36
	local at = v(math.sin(a) * FAN_R, 3.9 + math.cos(a) * FAN_R - FAN_R + 0.7, 1.15)
	local frame = CFrame.new(at) * CFrame.Angles(0, 0, -a)
	b.add("Torso", "Talisman" .. i, "Part", v(0.55, 1.15, 0.05), frame, PAPER)
	b.add("Torso", "TellTalisman" .. i, "Part", v(0.16, 0.75, 0.06), frame, GLOW_GOLD, Enum.Material.Neon)
end

return L.finish(b, { scale = SCALE, healthBarY = 4.4 })
