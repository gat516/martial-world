--!nocheck
-- Iron-Winged Blood Bat: a small hovering swarm bat built from Studio parts (lib.luau
-- helpers, Spirit Wolf B style). Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterBeasts.BloodBat (body plus joint attributes), then run
-- rig_blood_bat.luau on it.
--
-- Intent: a nervous little blood-drinker that comes in fours, dives, bites and shrieks.
-- Seen from 40 studs it must read as a BAT before anything else, so the hero is the wing:
-- iron finger bones fanning from a high wrist, dark crimson skin between them, and a
-- sawtooth (scalloped) trailing edge. Second read: the big ears with crimson insides over
-- a pug face with two bone fangs. The furred body is small and quiet (black-red with a
-- lighter rust mantle, muzzle, cheeks and chest for value contrast); the glow (eyes, chest core,
-- mouth, wing edge) stays dim at rest and only flares as a tell.
--
-- Hovers like the Flame Raven: the body centre sits at Y 4.6 (player-head height), the
-- feet hang to Y 3.7, wings half spread (arms rising to the wrist, the hand drooping, the
-- classic bat "M" from the front). Wingspan ~5.85, body ~1.3 long, ears to Y 6.35. Faces -Z,
-- left is -X. 47 parts (48 with the HRP), light for swarms.
-- Segments: Body, Skull, Jaw, EarL/R, WingL/R (shoulder + upper arm and its skin), WingL2/R2
-- (forearm: the iron leading bone, its skin, the thumb claw, the edge tell) and WingL3/R3 (the
-- hand: three finger bones and two skin panels), LegL/R.
--
-- Every joint pivot is the old body's, so EnemyPoses/BloodBat.luau drives it unchanged. The
-- skins rest at elevations (tilt from flat in the body frame) +0.50 / +0.30 (arm skins,
-- outer edge up) and -0.70 (both hand skins, outer edge down), all at or past the old
-- +0.45 / +0.25 / -0.61, so the flap's floor/ceil limits still keep them >= 0.3 from flat.
-- The arm skins billow slightly UP toward the trailing edge (SKIN_DROOP < 0): the usual
-- camera sits above and in front of a bat, and a skin drooping back goes edge-on to it.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("BloodBat")
local v, tell = B.v, B.tell

-- Tunables -----------------------------------------------------------------------------------
local BODY_Y = 4.6 -- body centre height (the hover)
local SHOULDER = v(0.5, 4.75, -0.2) -- right-side wing points; the left mirrors x
local ELBOW = v(1.2, 5.1, -0.4)
local WRIST = v(2.0, 5.3, -0.65)
local ARM_DEPTH = 1.15 -- how far the upper-arm skin trails behind its bone
local FORE_DEPTH = 1.35 -- how far the forearm skin trails (its far corner is the 5th finger's tip)
local SKIN_DROOP = -0.12 -- how much the arm skins drop per stud back: negative billows them up a
-- little, so the usual camera (above and in front) sees their tops instead of their edges
local HAND_DROOP = 0.68 -- how steeply the hand's plane slopes down outward (rad)
local FINGER = { 1.15, 1.55 } -- lengths of the leading (3rd) and middle (4th) finger
local FAN = { 1.5, 0.85 } -- angle of the 3rd and 4th finger out from the 5th (rad)
local MEMBRANE_T = 0.06 -- skin thickness

local FUR = Color3.fromHex("2A1517") -- black-red fur (back, head, legs)
local FUR_HI = Color3.fromHex("7A3B36") -- rust fur: mantle, muzzle, jaw, cheeks, chest
local MEMBRANE = Color3.fromHex("6E161E") -- thin dark crimson wing skin
local EAR_IN = Color3.fromHex("8E2229")
local IRON = Color3.fromHex("5E6470") -- the iron finger bones
local IRON_HI = Color3.fromHex("8F96A3") -- claws
local BONE = Color3.fromHex("E8DEC8") -- fangs
local GLOW = Color3.fromHex("9E1824") -- tells, dim at rest (BeastKit flares them on windup)
local EYE = Color3.fromHex("C2202C")

-- A thin rectangular skin whose leading edge runs a->b and which trails `depth` toward +Z,
-- drooping `down` per stud back. Returns the part and its back direction.
local function panel(seg, name, a, b, depth, color, down)
	local x = (b - a).Unit
	local back = v(0, -(down or 0), 1)
	local z = (back - x * back:Dot(x)).Unit
	local y = z:Cross(x)
	local p = B.add(seg, name, "Part", v((b - a).Magnitude, MEMBRANE_T, depth),
		CFrame.fromMatrix((a + b) / 2 + z * depth / 2, x, y, z), color)
	return p, z
end

-- A right-triangle skin (one WedgePart, thin along its X): the right angle at p, legs to a
-- and to b. Its normal is the part's RightVector.
local function rtri(seg, name, p, a, b, color)
	local z = (p - a).Unit
	local yRaw = b - p
	local y = (yRaw - z * yRaw:Dot(z)).Unit
	local x = y:Cross(z)
	local h, d = yRaw:Dot(y), (p - a).Magnitude
	return B.add(seg, name, "WedgePart", v(MEMBRANE_T, h, d),
		CFrame.fromMatrix(p + y * h / 2 - z * d / 2, x, y, z), color)
end

-- Body -------------------------------------------------------------------------------------

B.block("Body", "Body", v(1.0, 0.9, 1.3), v(0, BODY_Y + 0.02, 0.05), FUR)
-- the rust fur mantle over the shoulders, tall at the neck and sloping off to the back
B.add("Body", "Mantle", "WedgePart", v(0.8, 0.34, 0.75), CFrame.new(0, BODY_Y + 0.58, -0.22) * CFrame.Angles(0, math.pi, 0), FUR_HI)
-- the rust chest bib: tall under the chin, tapering back under the belly; the core sits in it
B.add("Body", "Chest", "WedgePart", v(0.84, 0.5, 0.95), CFrame.new(0, BODY_Y - 0.4, -0.12) * CFrame.Angles(math.pi, 0, 0), FUR_HI)
-- the tail skin between the legs, sloping down behind
B.add("Body", "TailMembrane", "Part", v(0.75, MEMBRANE_T, 0.6),
	CFrame.new(0, BODY_Y - 0.27, 0.85) * CFrame.Angles(0.45, 0, 0), MEMBRANE)
tell(B.ball("Body", "ChestCore", 0.38, v(0, BODY_Y - 0.3, -0.58), GLOW))
B.joint("JointRoot", "HumanoidRootPart", "Body", v(0, BODY_Y, 0))

-- Head -------------------------------------------------------------------------------------

local HY = BODY_Y + 0.35 -- the head joint height (unchanged)
B.block("Skull", "Skull", v(1.0, 0.74, 0.7), v(0, HY + 0.03, -0.92), FUR)
-- the pug snout: short, wide, lighter than the head
B.block("Skull", "Snout", v(0.56, 0.32, 0.24), v(0, HY - 0.17, -1.37), FUR_HI)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- slanted eyes on the front face, turned a little to the side so they read in 3/4
	tell(B.add("Skull", "Eye" .. side, "Part", v(0.25, 0.15, 0.06),
		CFrame.new(s * 0.27, HY + 0.13, -1.28) * CFrame.Angles(0, -s * 0.3, s * 0.25), EYE))
	-- a rust cheek tuft sticking out and down behind each jaw corner: widens the face
	B.fin("Skull", "Cheek" .. side, v(s * 0.42, HY - 0.12, -1.0), 0.38, 0.38, 0.14, FUR_HI, 0.3, -s * 2.0)
	-- two bone fangs over the lower lip
	B.fin("Skull", "Fang" .. side, v(s * 0.16, HY - 0.29, -1.44), 0.33, 0.13, 0.11, BONE, math.pi, 0)
	-- the big ear: a forward-facing triangle (two wedges) leaning out, with a crimson inside
	local earBase = v(s * 0.38, HY + 0.35, -0.85)
	local tilt = CFrame.Angles(0.05, -s * 0.22, -s * 0.18)
	local ear = "Ear" .. side
	B.tri(ear, ear, earBase, 1.0, 0.56, 0.1, FUR, tilt)
	local frame = CFrame.new(earBase) * tilt
	B.add(ear, "EarIn" .. side, "WedgePart", v(0.04, 0.72, 0.23),
		frame * CFrame.new(s * 0.115, 0.46, -0.065) * CFrame.Angles(0, -s * math.pi / 2, 0), EAR_IN)
	B.joint("JointEar" .. side, "Skull", ear, earBase)
end
B.joint("JointHead", "Body", "Skull", v(0, HY, -0.6))

-- jaw, hinged at the back; the mouth glow sits on top of it, hidden until it opens
B.block("Jaw", "Jaw", v(0.5, 0.17, 0.67), v(0, HY - 0.395, -1.08), FUR_HI)
tell(B.block("Jaw", "MouthTell", v(0.34, 0.04, 0.42), v(0, HY - 0.32, -1.12), GLOW))
B.joint("JointJaw", "Skull", "Jaw", v(0, HY - 0.45, -0.65))

-- Wings ------------------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local m = v(s, 1, 1)
	local S, E, W = SHOULDER * m, ELBOW * m, WRIST * m
	local w1, w2, w3 = "Wing" .. side, "Wing" .. side .. "2", "Wing" .. side .. "3"

	-- upper arm: the shoulder bone and the inner skin back to the flank
	B.limb(w1, w1, S, E, 0.26, 0.22, IRON, 0.2)
	panel(w1, w1 .. "Skin", S, E + (E - S).Unit * 0.08, ARM_DEPTH, MEMBRANE, SKIN_DROOP)

	-- forearm: the long iron leading bone, its skin (a right triangle back from the elbow;
	-- its far corner is the 5th finger's tip), the glowing edge and the thumb claw
	B.limb(w2, w2, E, W, 0.22, 0.2, IRON, 0.2)
	local x2 = (W - E).Unit
	local back = v(0, -SKIN_DROOP, 1)
	back = (back - x2 * back:Dot(x2)).Unit
	local q = E + back * FORE_DEPTH -- the 5th finger's tip
	rtri(w2, w2 .. "Skin", E, W, q, MEMBRANE)
	tell(B.add(w2, "WingEdgeTell" .. side, "Part", v(0.09, 0.04, (W - E).Magnitude * 0.7),
		B.bone(E, W) * CFrame.new(0, 0.115, 0), GLOW))
	B.add(w2, "WingClaw" .. side, "WedgePart", v(0.1, 0.32, 0.16),
		CFrame.new(W + v(s * 0.04, 0.12, -0.04)) * CFrame.Angles(-0.7, 0, -s * 0.35) * CFrame.new(0, 0.1, 0), IRON_HI)

	-- the hand: three iron fingers fan from the wrist in one plane, drooping outward. The 5th
	-- runs back to the forearm skin's corner; the 4th and the leading 3rd fan out from it.
	local u5 = (q - W).Unit
	local out = v(s * math.cos(HAND_DROOP), -math.sin(HAND_DROOP), 0)
	local side5 = (out - u5 * out:Dot(u5)).Unit
	local function finger(i)
		return W + (u5 * math.cos(FAN[i]) + side5 * math.sin(FAN[i])) * FINGER[i]
	end
	local t3, t4 = finger(1), finger(2)
	B.limb(w3, w3, W, t3, 0.15, 0.13, IRON, 0.12)
	B.limb(w3, w3 .. "Finger4", W, t4, 0.13, 0.12, IRON, 0.1)
	B.limb(w3, w3 .. "Finger5", W, q, 0.12, 0.11, IRON, 0.06)
	-- the skins: each a right triangle from a finger's tip in to the next finger (the foot of
	-- the perpendicular), so the trailing edge cuts in between the tips: the scallops
	local u4 = (t4 - W).Unit
	rtri(w3, w3 .. "Skin", W + u4 * (t3 - W):Dot(u4), W, t3, MEMBRANE)
	rtri(w3, w3 .. "Skin2", W + u5 * (t4 - W):Dot(u5), W, t4, MEMBRANE)

	B.joint("JointWing" .. side, "Body", w1, S)
	B.joint("JointWing" .. side .. "2", w1, w2, E)
	B.joint("JointWing" .. side .. "3", w2, w3, W)
end

-- Feet ---------------------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local hip, ankle = v(s * 0.3, BODY_Y - 0.4, 0.4), v(s * 0.32, BODY_Y - 0.78, 0.55)
	B.limb("Leg" .. side, "Leg" .. side, hip, ankle, 0.18, 0.18, FUR, 0.12)
	-- a hooked iron claw, tapering forward
	B.add("Leg" .. side, "Foot" .. side, "WedgePart", v(0.24, 0.16, 0.34),
		CFrame.new(ankle + v(0, -0.06, -0.1)), IRON_HI)
	B.joint("JointLeg" .. side, "Body", "Leg" .. side, hip)
end

return B.finish()
