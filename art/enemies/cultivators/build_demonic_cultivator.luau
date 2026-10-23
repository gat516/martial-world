--!nocheck
-- Demonic Cultivator: a cultivator who fell to the demonic path, black robes trimmed
-- in crimson, a bone demon mask with glowing slit eyes, wild black hair, spiked
-- bone pauldrons and a skull at the belt. Fights bare-handed with blood palms.
-- Silhouette: spiked shoulders (the widest at shoulder height), ragged tails.
-- Run in Edit mode through execute_luau; rebuilds _RosterCultivators.DemonicCultivator.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/cultivators/") or "http://127.0.0.1:8767/cultivators/"
local L = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "lib.luau?" .. os.clock()))()
local v = L.v

-- Tunables ------------------------------------------------------------------------
local BLACK = Color3.fromHex("1C1A1F")
local BLACK_HI = Color3.fromHex("2E2A33")
local CRIMSON = Color3.fromHex("8C1420")
local BONE = Color3.fromHex("E4DCC8")
local BONE_SH = Color3.fromHex("B7AD96")
local SKIN = Color3.fromHex("B9A79E") -- ashen
local GLOW = Color3.fromHex("FF2A3A") -- tells: mask eyes, chest sigil, palm marks
local SPIKE_H = 0.75
-- ----------------------------------------------------------------------------------

local b = L.begin("DemonicCultivator", { skin = SKIN, torso = BLACK, legs = BLACK })
L.robe(b, { outer = BLACK, trim = CRIMSON, inner = CRIMSON, sash = CRIMSON, hipLen = 0.6, hem = 0.5,
	cuff = CRIMSON })
-- blood sigil on the chest, over the lapel cross
b.block("Torso", "TellSigil", v(0.32, 0.32, 0.05), v(-0.42, 3.35, -0.64), GLOW, CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
b.block("Torso", "SigilRing", v(0.46, 0.46, 0.04), v(-0.42, 3.35, -0.62), BLACK_HI, CFrame.Angles(0, 0, math.pi / 4))

-- ragged tails, split per leg so the legs swing free: two hanging fins on the back
-- of each leg's robe
-- of each leg's robe, pointed and hanging past the hem; each leg's pair is one
-- keyable joint (TailL / TailR) hinged at the top
for _, s in { -1, 1 } do
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	local side = if s < 0 then "L" else "R"
	local down = CFrame.Angles(0, 0, math.pi)
	local tail = b.tri(leg, "Tail" .. side, v(s * 0.3, 1.75, 0.69), 1.5, 0.5, 0.08, BLACK_HI, down)
	b.joint(tail, v(s * 0.5, 1.75, 0.69))
	b.ride(b.model:FindFirstChild("Tail" .. side .. "B"), tail)
	local tailB = b.tri(leg, "TailTip" .. side, v(s * 0.72, 1.75, 0.69), 1.25, 0.4, 0.08, CRIMSON, down)
	b.ride(tailB, tail)
	b.ride(b.model:FindFirstChild("TailTip" .. side .. "B"), tail)
end

-- bone pauldrons: a plate on each arm, three spikes raking up and out
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	b.block(arm, "Pauldron", v(1.3, 0.5, 1.3), v(s * 1.55, 3.95, 0), BONE)
	b.block(arm, "PauldronRim", v(1.36, 0.14, 1.36), v(s * 1.55, 3.68, 0), BONE_SH)
	for i, z in { -0.38, 0, 0.38 } do
		local h = SPIKE_H * (if i == 2 then 1.25 else 0.85)
		-- turned side-on (yaw) so the slope faces out, then raked out and up (pitch)
		b.fin(arm, "Spike" .. i, v(s * 1.7, 4.12, z), h, 0.42, 0.28, if i == 2 then BONE else BONE_SH, -0.55, 0, -s * math.pi / 2)
	end
	-- claw gauntlet: black wraps and bone talons over the hand
	b.block(arm, "Gauntlet", v(1.08, 0.36, 1.08), v(s * 1.5, 2.08, 0), BLACK_HI)
	for i, x in { -0.3, 0, 0.3 } do
		b.fin(arm, "Talon" .. i, v(s * 1.5 + x, 2.0, -0.42), 0.32, 0.14, 0.12, BONE, math.pi - 0.35)
	end
	b.block(arm, "TellPalm", v(0.5, 0.06, 0.5), v(s * 1.5, 1.98, 0), GLOW, nil, Enum.Material.Neon)
end

-- face: a bone demon mask over the upper face with glowing slits and short horns
L.accessory(b, "Pal Hair", { color = BLACK, scale = Vector3.new(1.12, 1.12, 1.12) })
b.block("Head", "Mask", v(1.12, 0.62, 0.14), v(0, 4.6, -0.6), BONE)
b.block("Head", "MaskBrow", v(1.16, 0.14, 0.18), v(0, 4.86, -0.6), BONE_SH)
b.tri("Head", "MaskNose", v(0, 4.28, -0.67), 0.38, 0.32, 0.06, BONE, CFrame.Angles(math.pi, 0, 0) * CFrame.new(0, -0.38, 0))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	b.block("Head", "TellEye" .. side, v(0.3, 0.1, 0.06), v(s * 0.25, 4.6, -0.68), GLOW,
		CFrame.Angles(0, 0, s * 0.3), Enum.Material.Neon)
	b.block("Head", "EyeHollow" .. side, v(0.38, 0.18, 0.04), v(s * 0.25, 4.6, -0.665), BLACK, CFrame.Angles(0, 0, s * 0.3))
	b.fin("Head", "Horn" .. side, v(s * 0.4, 4.9, -0.58), 0.55, 0.22, 0.16, BONE_SH, -0.35, -s * 0.45)
	b.block("Head", "MaskStrap" .. side, v(0.08, 0.12, 0.9), v(s * 0.6, 4.6, -0.12), BLACK_HI)
end
-- a snarl of a mouth under the mask
b.block("Head", "Mouth", v(0.36, 0.06, 0.14), v(0, 4.12, -0.58), Color3.fromHex("3A0A10"))

-- skull ornament at the belt, on a bone-bead cord
local sk = v(0.0, 2.18, -0.7)
b.ball("Torso", "Skull", 0.5, sk + v(0, 0.06, 0), BONE)
b.block("Torso", "SkullJaw", v(0.3, 0.16, 0.22), sk + v(0, -0.19, -0.05), BONE_SH)
for _, s in { -1, 1 } do
	b.block("Torso", "SkullSocket" .. s, v(0.12, 0.1, 0.04), sk + v(s * 0.1, 0.08, -0.24), BLACK)
	for i = 1, 2 do
		b.ball("Torso", "Bead" .. s .. i, 0.16, sk + v(s * (0.2 + i * 0.17), 0.13 + i * 0.02, 0.06), BONE_SH)
	end
end

return L.finish(b, { healthBarY = 2.9 })
