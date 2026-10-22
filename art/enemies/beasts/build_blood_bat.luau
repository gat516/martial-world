--!nocheck
-- Iron-Winged Blood Bat: a small hovering swarm bat built from Studio parts (lib.luau
-- helpers, Spirit Wolf B style). Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterBeasts.BloodBat (body plus joint attributes), then run
-- rig_blood_bat.luau on it.
--
-- Hovers like the Flame Raven: the body centre sits at Y 4.6 (player-head height), the
-- feet hang to Y 3.7, wings half spread (about 25 degrees up). Wingspan ~4.9, body ~1.5
-- long, ears to Y 6.2. Faces -Z, left is -X. ~46 parts, light for swarms.
-- Segments: Body, Skull, Jaw, EarL/R, WingL/R (shoulder + upper arm), WingL2/R2 (forearm
-- with the metal leading bone) and WingL3/R3 (the wingtip finger), LegL/R.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("BloodBat")
local v, tell = B.v, B.tell

-- Tunables -----------------------------------------------------------------------------------
local BODY_Y = 4.6 -- body centre height (the hover)
local SHOULDER = v(0.5, 4.75, -0.2) -- right-side wing points; the left mirrors x
local ELBOW = v(1.2, 5.1, -0.4)
local WRIST = v(2.0, 5.3, -0.65)
local TIP = v(2.45, 4.85, 0.1)
local MEMBRANE_DEPTH = { 1.2, 1.35, 1.5 } -- how far each membrane trails behind its bone

local FUR = Color3.fromHex("2A2226") -- dark furred body
local FUR_HI = Color3.fromHex("3E3338")
local BELLY = Color3.fromHex("4D3C40")
local IRON = Color3.fromHex("7C838E") -- metal-edged leading bones
local IRON_DK = Color3.fromHex("4B515B")
local MEMBRANE = Color3.fromHex("3A3F48") -- dark iron-grey wing skin
local EAR_IN = Color3.fromHex("6E2A32")
local BONE = Color3.fromHex("EEE9DC")
local BLOOD = Color3.fromHex("E0402A") -- tells: eyes, chest core, mouth, wing edges (saturated mid)

-- A thin membrane whose leading edge runs a->b and which trails `depth` toward +Z,
-- drooping `down` per stud back.
local function panel(seg, name, a, b, depth, color, down)
	local x = (b - a).Unit
	local back = v(0, -(down or 0), 1)
	local z = (back - x * back:Dot(x)).Unit
	local y = z:Cross(x)
	return B.add(seg, name, "Part", v((b - a).Magnitude, 0.07, depth),
		CFrame.fromMatrix((a + b) / 2 + z * depth / 2, x, y, z), color)
end

-- Body -------------------------------------------------------------------------------------

B.block("Body", "Body", v(1.1, 1.0, 1.5), v(0, BODY_Y, 0), FUR)
B.block("Body", "BodyTop", v(0.8, 0.3, 1.4), v(0, BODY_Y + 0.5, 0.05), FUR_HI)
B.block("Body", "Belly", v(0.9, 0.2, 1.3), v(0, BODY_Y - 0.5, 0.05), BELLY)
B.block("Body", "TailMembrane", v(0.8, 0.07, 0.7), v(0, BODY_Y - 0.3, 0.95), MEMBRANE)
tell(B.ball("Body", "ChestCore", 0.5, v(0, BODY_Y + 0.05, -0.78), BLOOD))
B.joint("JointRoot", "HumanoidRootPart", "Body", v(0, BODY_Y, 0))

-- Head -------------------------------------------------------------------------------------

local HY = BODY_Y + 0.35
B.block("Skull", "Skull", v(1.1, 0.8, 0.8), v(0, HY, -0.95), FUR)
B.block("Skull", "Nose", v(0.45, 0.3, 0.2), v(0, HY - 0.1, -1.42), FUR_HI)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- eyes on the front face, turned a little to the side so they read in 3/4
	tell(B.add("Skull", "Eye" .. side, "Part", v(0.3, 0.2, 0.08),
		CFrame.new(s * 0.36, HY + 0.12, -1.37) * CFrame.Angles(0, -s * 0.3, 0), BLOOD))
	B.add("Skull", "Brow" .. side, "Part", v(0.4, 0.12, 0.2),
		CFrame.new(s * 0.34, HY + 0.32, -1.36) * CFrame.Angles(0, 0, s * 0.3), IRON_DK)
	B.fin("Skull", "Fang" .. side, v(s * 0.3, HY - 0.4, -1.3), 0.3, 0.14, 0.1, BONE, math.pi, 0)
	-- the big ear: a triangle facing forward (two wedges), leaning out
	B.tri("Ear" .. side, "Ear" .. side, v(s * 0.38, HY + 0.35, -0.85), 1.0, 0.6, 0.1, FUR_HI,
		CFrame.Angles(0, 0, -s * 0.2))
	B.joint("JointEar" .. side, "Skull", "Ear" .. side, v(s * 0.38, HY + 0.35, -0.85))
end
B.joint("JointHead", "Body", "Skull", v(0, HY, -0.6))

-- jaw, hinged at the back; the mouth glow sits on top of it, inside the mouth
B.block("Jaw", "Jaw", v(0.9, 0.25, 0.7), v(0, HY - 0.5, -1.0), BELLY)
tell(B.block("Jaw", "MouthTell", v(0.55, 0.05, 0.45), v(0, HY - 0.36, -1.05), BLOOD))
B.joint("JointJaw", "Skull", "Jaw", v(0, HY - 0.45, -0.65))

-- Wings ------------------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local S, E, W, T = SHOULDER * v(s, 1, 1), ELBOW * v(s, 1, 1), WRIST * v(s, 1, 1), TIP * v(s, 1, 1)
	local w1, w2, w3 = "Wing" .. side, "Wing" .. side .. "2", "Wing" .. side .. "3"

	B.limb(w1, w1, S, E, 0.3, 0.26, IRON_DK, 0.2)
	panel(w1, w1 .. "Skin", S, E, MEMBRANE_DEPTH[1], MEMBRANE, 0.1)

	B.limb(w2, w2, E, W, 0.26, 0.24, IRON, 0.2)
	panel(w2, w2 .. "Skin", E, W, MEMBRANE_DEPTH[2], MEMBRANE, 0.15)
	-- the glowing leading edge: a thin strip on top of the metal bone, 0.03 proud
	local f = B.bone(E, W)
	tell(B.add(w2, "WingEdgeTell" .. side, "Part", v(0.1, 0.04, (W - E).Magnitude * 0.6),
		f * CFrame.new(0, 0.14, 0), BLOOD))

	B.limb(w3, w3, W, T, 0.2, 0.2, IRON, 0.2)
	panel(w3, w3 .. "Skin", W, T, MEMBRANE_DEPTH[3], MEMBRANE, 0.2)
	B.add(w3, "WingClaw" .. side, "WedgePart", v(0.14, 0.3, 0.35),
		CFrame.lookAt(T + v(s * 0.1, 0, -0.2), T + v(s * 0.1, 0, -1)), IRON_DK)

	B.joint("JointWing" .. side, "Body", w1, S)
	B.joint("JointWing" .. side .. "2", w1, w2, E)
	B.joint("JointWing" .. side .. "3", w2, w3, W)
end

-- Feet ---------------------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local hip, ankle = v(s * 0.3, BODY_Y - 0.4, 0.4), v(s * 0.3, BODY_Y - 0.85, 0.3)
	B.limb("Leg" .. side, "Leg" .. side, hip, ankle, 0.2, 0.2, FUR_HI, 0.12)
	B.block("Leg" .. side, "Foot" .. side, v(0.28, 0.12, 0.4), ankle + v(0, -0.03, -0.1), IRON_DK)
	B.joint("JointLeg" .. side, "Body", "Leg" .. side, hip)
end

return B.finish()
