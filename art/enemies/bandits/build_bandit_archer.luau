--!nocheck
-- Bandit Archer: the ranged grunt. Leather vest over a grey-green shirt, a red headband
-- with long tails and a black topknot, a quiver slung across the back and a tall
-- Studio-built recurve bow in the left hand (the silhouette: a tall arc and arrow tips
-- over the shoulder). Face bare but for a scarf pulled down around the neck.
-- Run in Edit mode through execute_luau; rebuilds ServerStorage._RosterBandits.BanditArcher.

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8767/"
local B = loadstring(HttpService:GetAsync(BASE .. "bandits/bandit_common.luau?" .. os.clock()))()
local v = B.v

-- Tunables ----------------------------------------------------------------------------
local NAME = "BanditArcher"
local BOW_LENGTH = 5.4 -- tip to tip
local BOW_BEND = 0.75 -- how far the tips sweep back toward the archer
local BOW_SIDE = -0.62 -- bow plane offset from the arm centre (outside the left arm)
local SKIN = Color3.fromHex("C08A62")
local SHIRT = Color3.fromHex("66735A")
local LEATHER = Color3.fromHex("6B4A2E")
local LEATHER_DK = Color3.fromHex("3F2C1D")
local TROUSER = Color3.fromHex("3B3833")
local RED = Color3.fromHex("A83A2C") -- headband, fletching, bow wraps
local WOOD = Color3.fromHex("4A3222")
local BONE = Color3.fromHex("E6DCC4")
local HAIR = Color3.fromHex("1C1A18")
local BRONZE = Color3.fromHex("A9843F")
local EYE = Color3.fromHex("FFB347") -- the tell

local ctx = B.new(NAME, SKIN, { torso = SHIRT, arms = SHIRT, legs = TROUSER })
local function block(seg, name, size, pos, color, rot, mat)
	return B.block(ctx, seg, name, size, pos, color, rot, mat)
end
local function fin(...)
	return B.fin(ctx, ...)
end
local DOWN = CFrame.Angles(0, 0, math.pi)

-- Torso: vest, belt, quiver strap -------------------------------------------------------
block("Torso", "Vest", v(2.1, 1.6, 1.1), v(0, 3.15, 0), LEATHER)
block("Torso", "VestOpening", v(0.34, 1.62, 0.06), v(0, 3.15, -0.56), SHIRT)
for i, y in { 3.6, 3.15, 2.7 } do
	block("Torso", "Lace" .. i, v(0.5, 0.07, 0.04), v(0, y, -0.6), LEATHER_DK, CFrame.Angles(0, 0, if i % 2 == 0 then 0.4 else -0.4))
end
for _, s in { -1, 1 } do
	B.bevel(ctx, "Torso", "VestShoulder" .. s, v(s * 0.8, 4.05, 0), 0.5, 0.25, 1.12, s, LEATHER)
end
block("Torso", "Belt", v(2.06, 0.32, 1.08), v(0, 2.2, 0), LEATHER_DK)
block("Torso", "Buckle", v(0.36, 0.28, 0.08), v(0, 2.2, -0.56), BRONZE)
-- the quiver strap runs from the right shoulder to the left hip
block("Torso", "Strap", v(0.26, 2.5, 0.06), v(0.05, 3.0, -0.6), LEATHER_DK, CFrame.Angles(0, 0, -0.62))
block("Torso", "StrapBack", v(0.26, 2.5, 0.06), v(0.05, 3.0, 0.6), LEATHER_DK, CFrame.Angles(0, 0, 0.62))
-- a short leather skirt over the thighs
block("Torso", "SkirtFront", v(1.0, 0.55, 0.08), v(-0.45, 1.8, -0.53), LEATHER)
block("Torso", "SkirtFront2", v(0.8, 0.45, 0.08), v(0.5, 1.82, -0.53), LEATHER)
block("Torso", "SkirtBack", v(2.0, 0.55, 0.08), v(0, 1.8, 0.53), LEATHER)

-- Quiver: slung diagonally across the back, arrows over the right shoulder ----------
local qa, qb = v(-0.55, 2.2, 0.82), v(0.55, 4.05, 0.82)
B.cyl(ctx, "Torso", "Quiver", qa, qb, 0.62, LEATHER)
B.cyl(ctx, "Torso", "QuiverRim", qb - (qb - qa).Unit * 0.12, qb + (qb - qa).Unit * 0.05, 0.72, LEATHER_DK)
B.cyl(ctx, "Torso", "QuiverBand", qa + (qb - qa) * 0.35, qa + (qb - qa) * 0.42, 0.68, RED)
B.cyl(ctx, "Torso", "QuiverCap", qa - (qb - qa).Unit * 0.05, qa + (qb - qa).Unit * 0.1, 0.7, LEATHER_DK)
local axis = (qb - qa).Unit
for i, off in { v(-0.12, 0, -0.08), v(0.12, 0, 0.06), v(0, 0, 0.14), v(0.06, 0, -0.16) } do
	local base = qb + off
	local tip = base + axis * (0.9 + i * 0.08)
	B.cyl(ctx, "Torso", "Arrow" .. i, base - axis * 0.3, tip, 0.08, WOOD)
	-- fletching: two red vanes crossing at the nock end
	local cf = CFrame.lookAt(tip - axis * 0.2, tip + axis)
	B.add(ctx, "Torso", "Fletch" .. i, "Part", v(0.26, 0.04, 0.4), cf, RED)
	B.add(ctx, "Torso", "FletchB" .. i, "Part", v(0.04, 0.26, 0.4), cf, RED)
end

-- Arms: leather bracers, fingerless wraps -----------------------------------------------
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	local x = s * 1.5
	block(arm, "Bracer", v(1.1, 0.75, 1.1), v(x, 2.55, 0), LEATHER)
	block(arm, "BracerStrap", v(1.12, 0.1, 1.12), v(x, 2.7, 0), LEATHER_DK)
	block(arm, "BracerStrap2", v(1.12, 0.1, 1.12), v(x, 2.4, 0), LEATHER_DK)
	block(arm, "Hand", v(1.02, 0.22, 1.02), v(x, 2.08, 0), SKIN)
	block(arm, "ShoulderSeam", v(1.06, 0.2, 1.06), v(x, 3.85, 0), LEATHER)
end

-- Legs: tall soft boots ----------------------------------------------------------------
for _, s in { -1, 1 } do
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	local x = s * 0.5
	block(leg, "Boot", v(1.08, 0.95, 1.08), v(x, 0.47, 0), LEATHER_DK)
	block(leg, "BootCuff", v(1.12, 0.18, 1.12), v(x, 0.98, 0), LEATHER)
	block(leg, "BootToe", v(1.04, 0.3, 0.3), v(x, 0.15, -0.66), LEATHER_DK)
end

-- Head: headband with tails, topknot, scarf, face --------------------------------------
block("Head", "HairCap", v(1.3, 0.42, 1.3), v(0, 4.98, 0.04), HAIR)
block("Head", "HairBack", v(1.3, 0.7, 0.24), v(0, 4.7, 0.56), HAIR)
for _, s in { -1, 1 } do
	block("Head", "Sideburn" .. s, v(0.12, 0.5, 0.35), v(s * 0.62, 4.6, 0.15), HAIR)
end
B.ball(ctx, "Head", "Topknot", 0.55, v(0, 5.38, 0.15), HAIR)
B.cyl(ctx, "Head", "TopknotTie", v(0, 5.12, 0.15), v(0, 5.2, 0.15), 0.4, RED)
block("Head", "Headband", v(1.36, 0.2, 1.36), v(0, 4.88, 0), RED)
fin("Head", "BandTail1", v(-0.1, 4.85, 0.68), 1.1, 0.3, 0.07, RED, math.pi - 0.5, 0.15)
fin("Head", "BandTail2", v(0.12, 4.85, 0.68), 0.9, 0.26, 0.07, RED, math.pi - 0.75, -0.2)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local eye = block("Head", "Eye" .. side, v(0.24, 0.12, 0.06), v(s * 0.26, 4.6, -0.615), EYE,
		CFrame.Angles(0, 0, s * 0.12), Enum.Material.Neon)
	eye:SetAttribute("Tell", true)
	block("Head", "Brow" .. side, v(0.34, 0.1, 0.08), v(s * 0.27, 4.76, -0.61), HAIR, CFrame.Angles(0, 0, s * 0.3))
end
block("Head", "Mouth", v(0.36, 0.06, 0.05), v(0, 4.2, -0.615), LEATHER_DK)
block("Head", "Stubble", v(0.9, 0.2, 0.06), v(0, 4.06, -0.6), Color3.fromHex("8C6447"))
-- the scarf pulled down around the neck
block("Torso", "Scarf", v(1.45, 0.38, 1.25), v(0, 4.02, 0), Color3.fromHex("4F5A44"))
fin("Torso", "ScarfTail", v(0.35, 3.95, -0.62), 0.7, 0.3, 0.08, Color3.fromHex("4F5A44"), math.pi + 0.15)

-- Bow: a chunky recurve in the left hand, in the arm's YZ plane (Z along the bow), so it
-- stands upright when the arm is raised to aim. Tips sweep back toward the archer (+Y).
local arm = ctx.model["Left Arm"]
local grip = arm.CFrame * CFrame.new(BOW_SIDE, -1.05, 0)
local function bowPoint(t) -- t in [-1, 1], 0 at the grip
	local z = t * BOW_LENGTH / 2
	local y = BOW_BEND * t * t
	-- recurve: the last fifth flicks forward again
	local a = math.abs(t)
	if a > 0.8 then
		y -= (a - 0.8) * 1.6
	end
	return (grip * CFrame.new(0, y, z)).Position
end
local N = 6
for side = -1, 1, 2 do
	for i = 1, N do
		local a = bowPoint(side * (i - 1) / N)
		local b = bowPoint(side * i / N)
		local thick = 0.32 - i * 0.025
		local p = B.limb(ctx, "Left Arm", "BowLimb" .. (if side < 0 then "F" else "B") .. i, a, b, 0.2, thick, WOOD, 0.08)
		-- keep each segment's width across the arm's X (the bow is flat side-on)
		p.CFrame = CFrame.lookAt((a + b) / 2, b, arm.CFrame.XVector:Cross(b - a).Unit)
	end
	local tip = bowPoint(side)
	B.ball(ctx, "Left Arm", "BowNock" .. (if side < 0 then "F" else "B"), 0.22, tip, BONE)
end
B.limb(ctx, "Left Arm", "BowGrip", bowPoint(-0.12), bowPoint(0.12), 0.28, 0.4, RED, 0)
B.limb(ctx, "Left Arm", "BowString", bowPoint(-1), bowPoint(1), 0.05, 0.05, BONE, 0)
-- the knuckles closing on the grip
block("Left Arm", "GripFist", v(0.55, 0.3, 0.42), (arm.CFrame * CFrame.new(-0.42, -1.05, 0)).Position, SKIN)

return B.finish(ctx, {
	barOffset = 3.9,
	attributes = { Roster = "Bandit", Role = "ranged", Placeholder = "BanditArcher: R6 rig, Studio-built bow; needs R6 AnimationTracks per AIState" },
})
