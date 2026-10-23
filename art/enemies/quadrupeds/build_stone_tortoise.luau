--!nocheck
-- Stone-Shell Tortoise: a slow tank beast that carries a mossy crag on its back, jade
-- qi glowing in the shell's seams (the tells). Run in Edit mode through execute_luau; it
-- rebuilds ServerStorage._RosterQuadrupeds.StoneTortoise_R (body only), then run
-- rig_stone_tortoise.luau. Model space: ground Y=0, faces -Z, left side is -X.
-- The head and neck retract: JointNeck slides back along +Z (up to 2.3, see RIGS.md) and the
-- neck disappears under the shell's front lip.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local P = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/parts_lib.luau?" .. os.clock()))()("StoneTortoise_R")
local v, block, ball, limb, fin, spike, bevel, bevelZ, tell, add =
	P.v, P.block, P.ball, P.limb, P.fin, P.spike, P.bevel, P.bevelZ, P.tell, P.add

-- Tunables ------------------------------------------------------------------------------
local SHELL = Color3.fromHex("756C5D")
local SHELL_HI = Color3.fromHex("8E8473")
local RIM = Color3.fromHex("524A40")
local ROCK = Color3.fromHex("807A6F")
local MOSS = Color3.fromHex("5E8236")
local MOSS_HI = Color3.fromHex("7FA449")
local BELLY = Color3.fromHex("BCA77B")
local SKIN = Color3.fromHex("7E8566")
local SKIN_SH = Color3.fromHex("5D634B")
local BEAK = Color3.fromHex("3A352E")
local CLAW = Color3.fromHex("D9D0B8")
local JADE = Color3.fromHex("2EE884") -- jade qi tell
local LEG_X, LEG_ZF, LEG_ZB = 2.75, -2.7, 2.8

-- Shell: three stepped, bevelled layers so the dome reads round, a dark rim, the belly
-- plate under it, and a jade seam glowing on the ledge between the first two layers.
block("Shell", "Shell", v(6.0, 1.5, 7.2), v(0, 3.0, 0), SHELL)
block("Shell", "Rim", v(6.9, 0.9, 8.3), v(0, 1.85, 0), RIM)
block("Shell", "Belly", v(5.4, 0.6, 6.8), v(0, 1.15, 0), BELLY)
block("Shell", "Dome", v(4.8, 1.2, 6.0), v(0, 4.35, 0), SHELL_HI)
block("Shell", "Cap", v(3.2, 0.7, 4.0), v(0, 5.3, 0.1), SHELL)
for _, s in { -1, 1 } do
	bevel("Shell", "ShellSide" .. s, v(s * 3.25, 3.0, 0), 0.5, 1.5, 7.2, s, SHELL)
	bevel("Shell", "DomeSide" .. s, v(s * 2.6, 4.35, 0), 0.4, 1.2, 6.0, s, SHELL_HI)
	bevel("Shell", "CapSide" .. s, v(s * 1.85, 5.3, 0.1), 0.5, 0.7, 4.0, s, SHELL)
	bevelZ("Shell", "ShellEnd" .. s, v(0, 3.0, s * 3.85), 6.0, 1.5, 0.5, s, SHELL)
	bevelZ("Shell", "DomeEnd" .. s, v(0, 4.35, s * 3.2), 4.8, 1.2, 0.4, s, SHELL_HI)
	bevelZ("Shell", "CapEnd" .. s, v(0, 5.3, 0.1 + s * 2.25), 3.2, 0.7, 0.5, s, SHELL)
	-- marginal scutes: the rim's scalloped lip, tipped down
	for i, z in { -3.0, -1.0, 1.0, 3.0 } do
		block("Shell", "Scute" .. s .. i, v(0.5, 0.7, 1.75), v(s * 3.45, 1.75, z), RIM, CFrame.Angles(0, 0, s * 0.25))
	end
	-- the jade seam, and cracks branching down the lower slope
	tell(block("Shell", "Seam" .. s, v(0.14, 0.1, 6.4), v(s * 2.9, 3.78, 0), JADE))
	for i, z in { -1.6, 1.9 } do
		tell(block("Shell", "Crack" .. s .. i, v(0.1, 1.1, 0.14), v(s * 3.3, 3.05, z), JADE, CFrame.Angles(0.35 * i - 0.5, 0, s * 0.32)))
	end
end
tell(block("Shell", "SeamFront", v(4.7, 0.1, 0.14), v(0, 3.78, -3.45), JADE))
tell(block("Shell", "SeamBack", v(4.7, 0.1, 0.14), v(0, 3.78, 3.45), JADE))
tell(block("Shell", "CrackCap", v(0.14, 0.08, 2.6), v(0.3, 5.66, -0.3), JADE, CFrame.Angles(0, 0.35, 0)))

-- The crag on its back: three tilted rocks with moss on their tops, moss on the cap,
-- and a moss beard hanging over the front lip.
block("Shell", "Crag1", v(1.8, 2.3, 1.6), v(0.55, 6.4, 0.8), ROCK, CFrame.Angles(0.2, 0.5, -0.22))
block("Shell", "Crag2", v(1.3, 1.6, 1.3), v(-0.85, 6.05, -0.55), ROCK, CFrame.Angles(-0.18, 0.3, 0.2))
block("Shell", "Crag3", v(1.0, 0.9, 1.1), v(-0.5, 5.85, 1.7), ROCK, CFrame.Angles(0.1, -0.4, 0.15))
block("Shell", "CragMoss1", v(1.5, 0.3, 1.3), v(0.7, 7.52, 1.05), MOSS_HI, CFrame.Angles(0.2, 0.5, -0.22))
block("Shell", "CragMoss2", v(1.1, 0.3, 1.1), v(-0.95, 6.85, -0.7), MOSS, CFrame.Angles(-0.18, 0.3, 0.2))
block("Shell", "CapMoss", v(3.3, 0.3, 2.4), v(0, 5.7, -0.7), MOSS, CFrame.Angles(0.06, 0, 0))
-- moss lying flat on the dome's top ledge, tucked under the cap and lipping just past
-- the dome edge (tilted slabs here read as cards stuck on the slope)
block("Shell", "DomeMossL", v(1.2, 0.22, 2.4), v(-1.85, 5.02, 1.3), MOSS_HI)
block("Shell", "DomeMossR", v(1.1, 0.22, 2.0), v(1.9, 5.02, -1.5), MOSS)
block("Shell", "Crag4", v(1.0, 1.0, 0.9), v(1.25, 5.9, -0.95), ROCK, CFrame.Angles(-0.15, 0.8, -0.2))

-- Neck and head: a thick wrinkled neck, a blunt skull with a hooked beak, heavy stone
-- brows over slanted jade eyes, and a jade mark on the brow.
block("Neck", "Neck", v(1.4, 1.3, 2.0), v(0, 2.25, -4.1), SKIN)
block("Neck", "NeckFold", v(1.6, 1.45, 0.4), v(0, 2.28, -4.65), SKIN_SH)
block("Neck", "NeckUnder", v(1.1, 0.4, 1.6), v(0, 1.6, -4.3), BELLY)

block("Head", "Head", v(1.9, 1.55, 1.85), v(0, 2.65, -5.65), SKIN)
bevelZ("Head", "HeadBrow", v(0, 3.62, -5.95), 1.8, 0.4, 0.9, -1, SKIN_SH)
block("Head", "HeadPlate", v(1.4, 0.25, 0.75), v(0, 3.5, -5.12), SHELL_HI) -- behind the brow wedge, not through it
block("Head", "Beak", v(1.4, 0.7, 0.5), v(0, 2.3, -6.75), BEAK)
add("Head", "BeakHook", "WedgePart", v(1.0, 0.45, 0.45), CFrame.new(0, 1.88, -6.85) * CFrame.Angles(math.pi, 0, 0), BEAK)
tell(block("Head", "BrowMark", v(0.2, 0.2, 0.08), v(0, 3.3, -6.6), JADE, CFrame.Angles(0, 0, math.pi / 4)))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- heavy stone brows over slanted eyes on the front corners, so it glares head-on
	block("Head", "Brow" .. side, v(0.7, 0.3, 0.5), v(s * 0.6, 3.28, -6.45), SHELL_HI, CFrame.Angles(0, 0, s * 0.3))
	tell(block("Head", "Eye" .. side, v(0.42, 0.14, 0.08), v(s * 0.58, 3.02, -6.6), JADE, CFrame.Angles(0, 0, s * 0.3)))
end
block("Jaw", "Jaw", v(1.6, 0.45, 1.6), v(0, 1.72, -5.65), SKIN_SH)
block("Jaw", "JawBeak", v(1.2, 0.4, 0.45), v(0, 1.78, -6.55), BEAK)

-- Legs: stumpy elephant columns with scale plates and three blunt claws.
local function foot(seg, x, z, claws)
	block(seg, seg, v(1.85, 0.75, 1.85), v(x, 0.375, z), SKIN_SH)
	for i, dx in claws do
		add(seg, seg .. "Claw" .. i, "WedgePart", v(0.35, 0.35, 0.4), CFrame.new(x + dx, 0.18, z - 1.1), CLAW)
	end
end
for _, s in { -1, 1 } do
	for _, e in { { "F", LEG_ZF }, { "B", LEG_ZB } } do
		local leg = e[1] .. (if s < 0 then "L" else "R")
		local x, z = s * LEG_X, e[2]
		block("UpperLeg" .. leg, "UpperLeg" .. leg, v(1.55, 1.6, 1.55), v(x, 1.5, z), SKIN)
		-- the front scale and three claws only on the forelegs: on the hind legs the shell
		-- hides them, so the hind feet carry two claws and no front scale
		if e[1] == "F" then
			fin("UpperLeg" .. leg, "LegScale" .. leg, v(x, 1.0, z - 0.8), 0.9, 0.4, 1.0, SHELL_HI, -0.25)
		end
		block("UpperLeg" .. leg, "LegScaleOut" .. leg, v(0.3, 0.7, 0.9), v(x + s * 0.8, 1.45, z), SHELL_HI)
		foot("Foot" .. leg, x + s * 0.05, z - 0.1, if e[1] == "F" then { -0.55, 0, 0.55 } else { -0.4, 0.4 })
	end
end

-- Tail: a short blunt cone.
limb("Tail", "Tail", v(0, 1.7, 3.9), v(0, 1.25, 4.8), 0.7, 0.6, SKIN_SH, 0.1)
spike("TailTip", "TailTip", v(0, 1.25, 4.75), v(0, 1.0, 5.3), 0.45, SKIN_SH)

return P.place("_RosterQuadrupeds")
