--!nocheck
-- Mountain Bandit: the pack grunt. Ragged hemp tunic, rust sash, a wide conical straw
-- hat (the silhouette: a flat disc over a thin body), a red face wrap and a dao.
-- Run in Edit mode through execute_luau; rebuilds ServerStorage._RosterBandits.MountainBandit.
-- Needs _Gear.ConicalHat (cleaned Creator Store hat, see the roster report).

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8767/"
local B = loadstring(HttpService:GetAsync(BASE .. "bandits/bandit_common.luau?" .. os.clock()))()
local v = B.v

-- Tunables ----------------------------------------------------------------------------
local NAME = "MountainBandit"
local WEAPON = "Dadao" -- or "Staff" for a club variant
local HAT_SCALE = 1.55 -- the conical hat is the grunt's silhouette; keep it wide
local SKIN = Color3.fromHex("C99068")
local HEMP = Color3.fromHex("B89B6A") -- tunic
local HEMP_SH = Color3.fromHex("8E744C") -- collar, patches, hem
local TROUSER = Color3.fromHex("4E3E2E")
local WRAP = Color3.fromHex("D6CBAE") -- wrist and shin bindings
local RUST = Color3.fromHex("9C3B2A") -- sash and face wrap
local DARK = Color3.fromHex("221C18") -- brows, sandals, hair
local STRAW = Color3.fromHex("D2B46C")
local EYE = Color3.fromHex("FFB347") -- the tell: eyes flare on windup

local ctx = B.new(NAME, SKIN, { torso = HEMP, arms = SKIN, legs = TROUSER })
local function block(seg, name, size, pos, color, rot, mat)
	return B.block(ctx, seg, name, size, pos, color, rot, mat)
end
local DOWN = CFrame.Angles(0, 0, math.pi) -- tri pointing down
local function fin(...)
	return B.fin(ctx, ...)
end

-- Torso: crossed collar, sash, ragged hem ----------------------------------------------
-- the right panel crosses over the left (jiaoling), a darker band running shoulder to hip
block("Torso", "CollarL", v(0.32, 1.7, 0.08), v(-0.28, 3.25, -0.53), HEMP_SH, CFrame.Angles(0, 0, -0.55))
block("Torso", "CollarR", v(0.32, 1.9, 0.08), v(0.22, 3.2, -0.535), HEMP_SH, CFrame.Angles(0, 0, 0.5))
block("Torso", "CollarBack", v(1.3, 0.3, 0.08), v(0, 3.85, 0.53), HEMP_SH)
block("Torso", "Patch", v(0.45, 0.4, 0.06), v(-0.55, 2.75, 0.53), HEMP_SH, CFrame.Angles(0, 0, 0.2))
block("Torso", "Sash", v(2.1, 0.42, 1.12), v(0, 2.2, 0), RUST)
block("Torso", "SashKnot", v(0.4, 0.4, 0.3), v(0.6, 2.2, -0.62), RUST)
fin("Torso", "SashTail1", v(0.55, 2.05, -0.62), 0.75, 0.32, 0.08, RUST, math.pi + 0.1, 0.1)
fin("Torso", "SashTail2", v(0.78, 2.05, -0.6), 0.6, 0.28, 0.08, RUST, math.pi - 0.1, -0.15)
-- the tunic skirt over the thighs, torn into teeth
block("Torso", "SkirtFront", v(2.04, 0.45, 0.1), v(0, 1.8, -0.52), HEMP)
block("Torso", "SkirtBack", v(2.04, 0.45, 0.1), v(0, 1.8, 0.52), HEMP)
for i, x in { -0.75, -0.25, 0.25, 0.75 } do
	local h = if i % 2 == 0 then 0.4 else 0.28
	B.tri(ctx, "Torso", "HemF" .. i, v(x, 1.58, -0.52), h, 0.5, 0.1, HEMP, DOWN)
	B.tri(ctx, "Torso", "HemB" .. i, v(x, 1.58, 0.52), 0.68 - h, 0.5, 0.1, HEMP, DOWN)
end

-- Arms: ragged short sleeves, bare forearms, wrist wraps --------------------------------
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	local x = s * 1.5
	block(arm, "Sleeve", v(1.1, 0.75, 1.1), v(x, 3.62, 0), HEMP)
	B.tri(ctx, arm, "SleeveTear", v(x, 3.25, -0.55), 0.25, 0.6, 0.08, HEMP, DOWN)
	block(arm, "WristWrap", v(1.06, 0.45, 1.06), v(x, 2.5, 0), WRAP)
	block(arm, "WristWrap2", v(1.08, 0.12, 1.08), v(x, 2.75, 0), WRAP, CFrame.Angles(0, 0, s * 0.12))
end

-- Legs: shin bindings and straw sandals ------------------------------------------------
for _, s in { -1, 1 } do
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	local x = s * 0.5
	block(leg, "ShinWrap", v(1.06, 0.55, 1.06), v(x, 0.65, 0), WRAP)
	block(leg, "ShinWrapBand", v(1.08, 0.1, 1.08), v(x, 0.95, 0), WRAP, CFrame.Angles(0.15, 0, 0))
	block(leg, "Sandal", v(1.04, 0.28, 1.2), v(x, 0.14, -0.08), DARK)
	block(leg, "SandalToe", v(0.9, 0.18, 0.3), v(x, 0.09, -0.72), STRAW)
end

-- Head: face wrap, eyes, brows, a hank of hair under the hat ---------------------------
block("Head", "FaceWrap", v(1.32, 0.55, 1.32), v(0, 4.18, 0), RUST)
block("Head", "FaceWrapNose", v(0.5, 0.25, 0.12), v(0, 4.42, -0.66), RUST, CFrame.Angles(-0.3, 0, 0))
fin("Head", "WrapTail1", v(-0.15, 4.3, 0.66), 0.7, 0.3, 0.08, RUST, math.pi - 0.6, 0.2)
fin("Head", "WrapTail2", v(0.15, 4.25, 0.66), 0.55, 0.26, 0.08, RUST, math.pi - 0.9, -0.2)
for _, s in { -1, 1 } do
	local eye = block("Head", "Eye" .. (if s < 0 then "L" else "R"), v(0.26, 0.1, 0.06), v(s * 0.27, 4.62, -0.615),
		EYE, CFrame.Angles(0, 0, s * 0.15), Enum.Material.Neon)
	eye:SetAttribute("Tell", true)
	block("Head", "Brow" .. (if s < 0 then "L" else "R"), v(0.38, 0.12, 0.1), v(s * 0.27, 4.8, -0.6), DARK,
		CFrame.Angles(0, 0, s * 0.35))
end
block("Head", "HairBack", v(1.28, 0.5, 0.25), v(0, 4.75, 0.55), DARK)
fin("Head", "HairTuft", v(0, 4.55, 0.62), 0.4, 0.3, 0.3, DARK, math.pi - 0.3)

B.accessory(ctx, "ConicalHat", "Head", "HatAttachment", CFrame.new(0, 0.1, 0) * CFrame.Angles(0.08, 0, 0), STRAW)
local hat = ctx.model.ConicalHat.Handle
hat.SpecialMesh.Scale = Vector3.one * HAT_SCALE
-- chin cord so the hat reads as tied on
block("Head", "HatCord", v(0.06, 0.6, 0.06), v(-0.62, 4.45, -0.1), DARK, CFrame.Angles(0, 0, -0.1))

B.weapon(ctx, WEAPON, "Right Arm")

return B.finish(ctx, {
	barOffset = 3.6,
	attributes = { Roster = "Bandit", Role = "pack", Placeholder = "MountainBandit: R6 rig, Studio-built dress; needs R6 AnimationTracks per AIState" },
})
