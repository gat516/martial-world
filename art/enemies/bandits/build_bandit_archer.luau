--!nocheck
-- Bandit Archer: the ranged grunt. Leather vest over a grey-green shirt, a red headband
-- with long tails and a black topknot, a quiver slung across the back and a tall
-- Studio-built recurve bow in the left hand (the silhouette: a tall arc and arrow tips
-- over the shoulder). Face bare but for a scarf pulled down around the neck.
-- Run in Edit mode through execute_luau; rebuilds ServerStorage._RosterBandits.BanditArcher.
-- Keyable joints (RIGS.md): Bow (in the left hand), Nock (the string's draw point),
-- Quiver, BandTail1/2, ScarfTail, SkirtL/SkirtR.

local HttpService = game:GetService("HttpService")
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local B = loadstring(HttpService:GetAsync(BASE .. "bandits/bandit_common.luau?" .. os.clock()))()
local v = B.v

-- Tunables ----------------------------------------------------------------------------
local NAME = "BanditArcher"
local BOW_LENGTH = 5.4 -- tip to tip
local BOW_BEND = 0.75 -- how far the tips sweep back toward the archer
local BOW_SIDE = -0.62 -- bow plane offset from the arm centre (outside the left arm)
local BOW_TILT = 0.9 -- rest: the bow leans this far (radians) from upright, top tip forward
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
	B.bevel(ctx, "Torso", "VestShoulder" .. s, v(s * 0.78, 4.0, 0), 0.4, 0.22, 1.12, s, LEATHER) -- low and outboard: a turned head clears it
end
block("Torso", "Belt", v(2.06, 0.32, 1.08), v(0, 2.2, 0), LEATHER_DK)
block("Torso", "Buckle", v(0.36, 0.28, 0.08), v(0, 2.2, -0.56), BRONZE)
-- the quiver strap runs from the right shoulder to the left hip
block("Torso", "Strap", v(0.26, 2.5, 0.06), v(0.05, 3.0, -0.6), LEATHER_DK, CFrame.Angles(0, 0, -0.62))
block("Torso", "StrapBack", v(0.26, 2.5, 0.06), v(0.05, 3.0, 0.6), LEATHER_DK, CFrame.Angles(0, 0, -0.62)) -- same diagonal as the front: over the right shoulder
-- a short leather skirt over the thighs: one flap per leg (SkirtL/SkirtR joints at the hip,
-- riding the leg so a stride never pokes through), its back panel welded to it
local skirtL = block("Torso", "SkirtL", v(1.0, 0.55, 0.08), v(-0.5, 1.8, -0.53), LEATHER)
local skirtR = block("Torso", "SkirtR", v(0.8, 0.45, 0.08), v(0.5, 1.82, -0.53), LEATHER)
block("SkirtL", "SkirtBackL", v(1.0, 0.55, 0.08), v(-0.5, 1.8, 0.53), LEATHER)
block("SkirtR", "SkirtBackR", v(1.0, 0.55, 0.08), v(0.5, 1.8, 0.53), LEATHER)
B.joint(ctx, skirtL, "Left Leg", v(-0.5, 2, 0))
B.joint(ctx, skirtR, "Right Leg", v(0.5, 2, 0))

-- Quiver: slung diagonally across the back, arrows over the right shoulder ----------
local qa, qb = v(-0.7, 2.25, 0.82), v(0.75, 3.95, 0.82) -- shallow enough that the arrows clear a turned head
local quiver = B.cyl(ctx, "Torso", "Quiver", qa, qb, 0.62, LEATHER)
B.cyl(ctx, "Quiver", "QuiverRim", qb - (qb - qa).Unit * 0.12, qb + (qb - qa).Unit * 0.05, 0.72, LEATHER_DK)
B.cyl(ctx, "Quiver", "QuiverBand", qa + (qb - qa) * 0.35, qa + (qb - qa) * 0.42, 0.68, RED)
B.cyl(ctx, "Quiver", "QuiverCap", qa - (qb - qa).Unit * 0.05, qa + (qb - qa).Unit * 0.1, 0.7, LEATHER_DK)
local axis = (qb - qa).Unit
for i, off in { v(-0.12, 0, -0.08), v(0.12, 0, 0.06), v(0.02, 0, 0.14) } do -- three read as a sheaf
	local base = qb + off
	local tip = base + axis * (0.9 + i * 0.08)
	B.cyl(ctx, "Quiver", "Arrow" .. i, base - axis * 0.3, tip, 0.08, WOOD)
	-- fletching: two red vanes crossing at the nock end
	local cf = CFrame.lookAt(tip - axis * 0.2, tip + axis)
	B.add(ctx, "Quiver", "Fletch" .. i, "Part", v(0.26, 0.04, 0.4), cf, RED)
	B.add(ctx, "Quiver", "FletchB" .. i, "Part", v(0.04, 0.26, 0.4), cf, RED)
end
-- hinged where the strap crosses the middle of the back, so it can swing and bounce
B.joint(ctx, quiver, "Torso", v(0, 3.12, 0.5))

-- Arms: leather bracers, fingerless wraps -----------------------------------------------
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	local x = s * 1.5
	block(arm, "Bracer", v(1.1, 0.75, 1.1), v(x, 2.55, 0), LEATHER)
	block(arm, "BracerStrap", v(1.12, 0.1, 1.12), v(x, 2.7, 0), LEATHER_DK)
	block(arm, "Hand", v(1.02, 0.22, 1.02), v(x, 2.08, 0), SKIN)
	block(arm, "ShoulderSeam", v(1.06, 0.2, 1.06), v(x, 3.85, 0), LEATHER)
end

-- Legs: tall soft boots ----------------------------------------------------------------
for _, s in { -1, 1 } do
	local leg = if s < 0 then "Left Leg" else "Right Leg"
	local x = s * 0.5
	block(leg, "Boot", v(1.08, 0.94, 1.08), v(x, 0.47, 0), LEATHER_DK)
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
B.joint(ctx, B.ribbon(ctx, "Head", "BandTail1", v(-0.1, 4.85, 0.68), 1.1, 0.3, 0.07, RED, math.pi - 0.5, 0.15), "Head", v(-0.1, 4.85, 0.68))
B.joint(ctx, B.ribbon(ctx, "Head", "BandTail2", v(0.12, 4.85, 0.68), 0.9, 0.26, 0.07, RED, math.pi - 0.75, -0.2), "Head", v(0.12, 4.85, 0.68))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local eye = block("Head", "Eye" .. side, v(0.24, 0.12, 0.06), v(s * 0.26, 4.6, -0.615), EYE,
		CFrame.Angles(0, 0, s * 0.12), Enum.Material.Neon)
	eye:SetAttribute("Tell", true)
	block("Head", "Brow" .. side, v(0.34, 0.1, 0.08), v(s * 0.27, 4.76, -0.61), HAIR, CFrame.Angles(0, 0, s * 0.3))
end
block("Head", "Mouth", v(0.36, 0.06, 0.05), v(0, 4.2, -0.615), LEATHER_DK)
block("Head", "Stubble", v(0.9, 0.14, 0.06), v(0, 4.16, -0.6), Color3.fromHex("8C6447"))
-- the scarf pulled down around the neck
block("Torso", "Scarf", v(1.45, 0.32, 1.25), v(0, 3.97, 0), Color3.fromHex("4F5A44"))
B.joint(ctx, B.ribbon(ctx, "Torso", "ScarfTail", v(0.35, 3.95, -0.62), 0.7, 0.3, 0.08, Color3.fromHex("4F5A44"), math.pi + 0.15), "Torso", v(0.35, 3.95, -0.62))

-- Bow: a chunky recurve in the left hand. Built in a bow frame F at the grip: the bow runs
-- along F's Y (tips up and down), its tips sweep back toward the string side, F's +Z. At
-- rest F stands in the arm's YZ plane, leaning BOW_TILT with the top tip forward (upright
-- it would sink into the ground). The Bow joint pivots in the hand on F's axes; the Nock
-- joint (also on F's axes, +Z = draw toward the archer) carries the string's middle, and
-- the string is two Beams from the tips to the nock, so drawing it bends the string.
local arm = ctx.model["Left Arm"]
local F = arm.CFrame * CFrame.new(BOW_SIDE, -1.05, 0) * CFrame.Angles(-BOW_TILT, 0, 0) -- string side up and back
local function bowPoint(t) -- t in [-1, 1], 0 at the grip, +1 the top tip
	local y = t * BOW_LENGTH / 2
	local z = BOW_BEND * t * t
	-- recurve: the last fifth flicks forward again
	local a = math.abs(t)
	if a > 0.8 then
		z -= (a - 0.8) * 1.6
	end
	return (F * CFrame.new(0, y, z)).Position
end
local bow = B.limb(ctx, "Left Arm", "Bow", bowPoint(-0.12), bowPoint(0.12), 0.28, 0.4, RED, 0)
bow.CFrame = CFrame.lookAt(bow.Position, bowPoint(0.12), F.ZVector)
local N = 5 -- segments per limb
for side = -1, 1, 2 do
	for i = 1, N do
		local a = bowPoint(side * (i - 1) / N)
		local b = bowPoint(side * i / N)
		local thick = 0.32 - i * 0.025
		local p = B.limb(ctx, "Bow", "BowLimb" .. (if side > 0 then "T" else "B") .. i, a, b, 0.2, thick, WOOD, 0.08)
		-- the width across the bow plane's normal, the thickness in the plane
		p.CFrame = CFrame.lookAt((a + b) / 2, b, F.XVector:Cross(b - a).Unit)
	end
	B.ball(ctx, "Bow", "BowNock" .. (if side > 0 then "T" else "B"), 0.22, bowPoint(side), BONE)
end
-- the nock: an invisible carrier at the string's middle; the string is two beams
local nockPos = (bowPoint(-1) + bowPoint(1)) / 2
local nock = B.block(ctx, "Bow", "Nock", v(0.15, 0.15, 0.15), nockPos, BONE)
nock.Transparency = 1
local function att(parent, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = parent
	a.WorldPosition = pos
	return a
end
local tipT = att(bow, "StringTop", bowPoint(1))
local tipB = att(bow, "StringBottom", bowPoint(-1))
local mid = att(nock, "String", nockPos)
for name, pair in { StringUpper = { tipT, mid }, StringLower = { mid, tipB } } do
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0, beam.Attachment1 = pair[1], pair[2]
	beam.Width0, beam.Width1 = 0.06, 0.06
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = ColorSequence.new(BONE)
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.Texture = ""
	beam.Parent = bow
end
B.joint(ctx, bow, "Left Arm", F)
B.joint(ctx, nock, "Bow", F.Rotation + nockPos)
-- the knuckles closing on the grip
block("Left Arm", "GripFist", v(0.55, 0.3, 0.42), (arm.CFrame * CFrame.new(-0.42, -1.05, 0)).Position, SKIN)

return B.finish(ctx, {
	barOffset = 3.4,
	attributes = { Roster = "Bandit", Role = "ranged", Placeholder = "BanditArcher: R6 rig, Studio-built bow; needs R6 AnimationTracks per AIState" },
})
