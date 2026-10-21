--!nocheck
-- Nine-Tail Fox Spirit: an elegant elite, cream-white and gold, with nine tails fanned
-- behind it like a crown and azure foxfire on its brow, eyes and tail tips (the tells).
-- Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterQuadrupeds.NineTailFox_R (body only), then run
-- rig_nine_tail_fox.luau. Model space: ground Y=0, faces -Z, left side is -X.
-- Each tail is two segments, Tail<i> and Tail<i>Tip (i = 1..9 from left to right), on
-- a shared TailRoot, so they can fan, sway and curl one by one.

local BASE = "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local P = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/parts_lib.luau?" .. os.clock()))()("NineTailFox_R")
local v, block, ball, limb, fin, tri, bevel, bevelZ, tell, add =
	P.v, P.block, P.ball, P.limb, P.fin, P.tri, P.bevel, P.bevelZ, P.tell, P.add

-- Tunables ------------------------------------------------------------------------------
local CREAM = Color3.fromHex("F1E9D8")
local CREAM_SH = Color3.fromHex("D3C6AA")
local GOLD = Color3.fromHex("DDA84A")
local GOLD_DK = Color3.fromHex("A97A31")
local DARK = Color3.fromHex("2E2630") -- nose, eyeliner, mouth line
local EAR_IN = Color3.fromHex("D98C9C")
local FOXFIRE = Color3.fromHex("7FC8FF") -- the tell
local TAIL_ROOT = Vector3.new(0, 3.55, 2.7)
local TAIL_SPREAD = 1.35 -- radians from the centre tail to the outer ones (rest fan)
local TAIL_BASE_LEN, TAIL_TIP_LEN = 1.6, 2.1

-- The tail fan: tail i's base direction, and its curl toward the tip.
local function tailDirs(i)
	local a = (i - 5) / 4 * TAIL_SPREAD
	-- odd tails lean further back, so the fan has depth instead of reading as one wall
	local base = Vector3.new(math.sin(a) * 0.9, math.cos(a) * 0.85, if i % 2 == 1 then 0.75 else 0.4).Unit
	local tip = (base + Vector3.new(math.sin(a) * 0.2, 0.5, 0.1)).Unit
	return base, tip
end
P.tailDirs = tailDirs

-- Chest and hips: slim, with a deep cream chest and a gold saddle down the back.
block("Chest", "Chest", v(1.6, 1.25, 2.4), v(0, 3.05, -0.5), CREAM)
block("Chest", "ChestTop", v(0.9, 0.4, 2.3), v(0, 3.85, -0.5), GOLD)
block("Chest", "ChestBelly", v(1.3, 0.35, 1.9), v(0, 2.35, -0.45), CREAM_SH)
for _, s in { -1, 1 } do
	bevel("Chest", "ChestShoulder" .. s, v(s * 0.6, 3.85, -0.5), 0.3, 0.4, 2.3, s, GOLD)
end
block("Hips", "Hips", v(1.4, 1.05, 1.9), v(0, 3.1, 1.55), CREAM)
block("Hips", "HipsTop", v(0.8, 0.35, 1.8), v(0, 3.8, 1.55), GOLD)
for _, s in { -1, 1 } do
	bevel("Hips", "HipsShoulder" .. s, v(s * 0.55, 3.8, 1.55), 0.3, 0.35, 1.8, s, GOLD)
end

-- Neck and ruff: a long neck held high, a white ruff flaring at its base.
limb("Neck", "Neck", v(0, 3.35, -1.4), v(0, 4.45, -2.4), 0.95, 1.0, CREAM, 0.4)
block("Neck", "Ruff", v(1.5, 1.3, 0.8), v(0, 3.25, -1.7), CREAM)
fin("Neck", "RuffBib", v(0, 2.75, -2.05), 0.5, 0.5, 0.9, CREAM, math.pi - 0.3)
for _, s in { -1, 1 } do
	fin("Neck", "BibTuft" .. s, v(s * 0.35, 2.75, -1.95), 0.4, 0.4, 0.3, CREAM, math.pi - 0.4, s * 0.3)
end

-- Head: a narrow wedge skull, long snout, cheek fur sweeping back, slanted sly eyes.
block("Skull", "Skull", v(1.25, 1.0, 1.15), v(0, 4.6, -2.85), CREAM)
add("Skull", "Brow", "WedgePart", v(1.05, 0.3, 0.6), CFrame.new(0, 5.25, -3.05), GOLD)
block("Skull", "Snout", v(0.55, 0.45, 1.2), v(0, 4.38, -3.95), CREAM)
add("Skull", "SnoutTop", "WedgePart", v(0.45, 0.3, 1.1), CFrame.new(0, 4.75, -3.6), GOLD)
block("Skull", "Nose", v(0.3, 0.22, 0.2), v(0, 4.5, -4.6), DARK)
tell(block("Skull", "BrowMark", v(0.2, 0.2, 0.06), v(0, 5.0, -3.44), FOXFIRE, CFrame.Angles(0, 0, math.pi / 4)))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- sly eyes: narrow, the outer corner swept up, lined dark
	block("Skull", "Liner" .. side, v(0.46, 0.16, 0.06), v(s * 0.33, 4.76, -3.44), DARK, CFrame.Angles(0, 0, s * 0.4))
	tell(block("Skull", "Eye" .. side, v(0.34, 0.08, 0.06), v(s * 0.33, 4.74, -3.47), FOXFIRE, CFrame.Angles(0, 0, s * 0.4)))
	-- the smile: a dark line up the snout side
	block("Skull", "Smile" .. side, v(0.04, 0.06, 0.7), v(s * 0.28, 4.2, -3.75), DARK, CFrame.Angles(-0.2, 0, 0))
	tri("Ear" .. side, "Ear" .. side, v(s * 0.42, 5.0, -2.7), 1.15, 0.7, 0.2, CREAM, CFrame.Angles(-0.12, 0, -s * 0.22))
	tri("Ear" .. side, "Ear" .. side .. "Inner", v(s * 0.42, 5.05, -2.82), 0.75, 0.42, 0.05, EAR_IN, CFrame.Angles(-0.12, 0, -s * 0.22))
end
block("Jaw", "Jaw", v(0.45, 0.2, 1.0), v(0, 4.08, -3.85), CREAM_SH)
block("Jaw", "Chin", v(0.7, 0.3, 0.5), v(0, 4.15, -3.25), CREAM_SH)

-- Legs: long and slender, gold stockings, dark paws ----------------------------------------
for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local x, z = s * 0.5, -1.25
	block("UpperLeg" .. f, "UpperLeg" .. f, v(0.5, 1.3, 0.6), v(x, 2.2, z), CREAM)
	ball("UpperLeg" .. f, "Shoulder" .. f, 0.68, v(x, 2.75, z), CREAM)
	block("LowerLeg" .. f, "LowerLeg" .. f, v(0.36, 1.25, 0.42), v(x, 0.95, z), GOLD)
	ball("LowerLeg" .. f, "Elbow" .. f, 0.44, v(x, 1.55, z), GOLD)
	block("Paw" .. f, "Paw" .. f, v(0.45, 0.3, 0.65), v(x, 0.15, z - 0.12), GOLD_DK)

	local b = if s < 0 then "BL" else "BR"
	x = s * 0.52
	local knee, hock, ankle = v(x, 1.6, 1.65), v(x, 0.7, 2.15), v(x, 0.25, 2.05)
	block("UpperLeg" .. b, "UpperLeg" .. b, v(0.65, 1.35, 0.85), v(x, 2.35, 1.9), CREAM)
	limb("LowerLeg" .. b, "LowerLeg" .. b, knee, hock, 0.36, 0.42, GOLD, 0.25)
	ball("LowerLeg" .. b, "Knee" .. b, 0.48, knee, CREAM)
	limb("Paw" .. b, "Paw" .. b, hock, ankle, 0.34, 0.38, GOLD, 0.15)
	ball("Paw" .. b, "Hock" .. b, 0.38, hock, GOLD)
	block("Paw" .. b, "Foot" .. b, v(0.45, 0.3, 0.65), v(x, 0.15, 1.88), GOLD_DK)
end

-- Nine tails: gold bases out of a shared root, fat cream brushes, foxfire tips ------------
block("TailRoot", "TailRoot", v(0.9, 0.8, 0.8), TAIL_ROOT + v(0, -0.05, -0.15), GOLD)
for i = 1, 9 do
	local d, dt = tailDirs(i)
	local a = TAIL_ROOT + d * 0.2
	local b = a + d * TAIL_BASE_LEN
	local c = b + dt * TAIL_TIP_LEN
	limb("Tail" .. i, "Tail" .. i, a, b, 0.42, 0.42, GOLD, 0.3)
	limb("Tail" .. i .. "Tip", "Tail" .. i .. "Tip", b, c, 0.62, 0.62, CREAM, 0.3)
	-- the foxfire tip: a flame wedge carrying on along the curl
	local cf = CFrame.lookAt(c, c + dt) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, 0.3, 0)
	tell(add("Tail" .. i .. "Tip", "Tail" .. i .. "Flame", "WedgePart", v(0.46, 0.75, 0.46), cf, FOXFIRE))
end

return P.place("_RosterQuadrupeds")
