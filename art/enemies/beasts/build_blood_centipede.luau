--!nocheck
-- Blood Centipede: a low grave-dweller built from Studio parts (lib.luau helpers, Spirit
-- Wolf B style). Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterBeasts.BloodCentipede (body plus joint attributes), then run
-- rig_blood_centipede.luau on it.
--
-- Shape: ~15 studs nose to cerci, plates ~2 tall (3 to the antenna tips), 2.7 wide before
-- the legs. The line is Skull (front) -> Collar (the root segment) -> Seg1..12 -> Tail.
-- Bone-white plates with a dull red skirt edge, a neon red SeamTell strip across each
-- plate's front, a red CoreGlow in the collar seam, two pincers and two antennae.
-- Every plate carries a pair of single-part legs (LegL<i>/LegR<i>) so the animator can
-- ripple them. Faces -Z, left is -X, ground Y=0.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("BloodCentipede")
local v, tell = B.v, B.tell

-- Tunables ---------------------------------------------------------------------------------
local SEGS = 12
local SEG_LEN = 0.8 -- z pitch of one body plate
local PAD = 0.1 -- plates overlap their neighbour by this much (no sky slits side-on)
local FLOOR = 0.45 -- underside of the plates
local W0, W1 = 2.7, 1.9 -- plate width, first to last segment
local H0, H1 = 1.95, 1.35 -- plate height (from FLOOR), first to last
local LEG_OUT = 1.35 -- how far a foot lands outside the plate edge
local LEG_W = 0.34
local COLLAR_Z0, COLLAR_Z1 = -5.5, -4.3 -- the collar plate (the root segment)
local SKULL_Z0 = -7.4 -- front of the skull

local BONE = Color3.fromHex("EEE9DC")
local BONE2 = Color3.fromHex("DDD5C0") -- alternate plate shade
local RED = Color3.fromHex("8E2B2B") -- dull red edging, legs, pincers
local DARKRED = Color3.fromHex("5A1B1D")
local BLOOD = Color3.fromHex("E0402A") -- tells: seams, eyes, pincer marks, core (saturated mid)

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Head ---------------------------------------------------------------------------------------

-- Collar: the first, taller plate. It is the root segment.
local cw, ch = W0 + 0.1, H0 + 0.15
local cz = (COLLAR_Z0 + COLLAR_Z1) / 2
local clen = COLLAR_Z1 - COLLAR_Z0 + PAD
B.block("Collar", "Collar", v(cw, ch - 0.3, clen), v(0, FLOOR + (ch - 0.3) / 2, cz), BONE)
B.block("Collar", "CollarTop", v(cw * 0.7, 0.3, clen), v(0, FLOOR + ch - 0.15, cz), BONE)
B.block("Collar", "CollarSkirt", v(cw + 0.3, 0.5, clen - 0.1), v(0, FLOOR + 0.2, cz), RED)
B.joint("JointRoot", "HumanoidRootPart", "Collar", v(0, 1.3, (COLLAR_Z0 + COLLAR_Z1) / 2))
-- the red core glimpsed in the collar seam, half sunk into the plates
tell(B.ball("Collar", "CoreGlow", 0.8, v(0, FLOOR + ch - 0.05, COLLAR_Z1 + 0.02), BLOOD))

-- Skull
local sz = (SKULL_Z0 + COLLAR_Z0 + PAD) / 2
local slen = COLLAR_Z0 + PAD - SKULL_Z0
B.block("Skull", "Skull", v(2.4, 1.5, slen), v(0, 1.4, sz), BONE)
B.block("Skull", "SkullCrown", v(1.5, 0.3, slen - 0.4), v(0, 2.25, sz + 0.1), BONE2)
B.block("Skull", "SkullBrow", v(2.5, 0.28, 0.7), v(0, 2.0, SKULL_Z0 + 0.45), RED)
B.block("Skull", "SkullChin", v(2.5, 0.4, slen - 0.2), v(0, 0.78, sz + 0.1), RED)
B.block("Skull", "Maw", v(1.2, 0.5, 0.14), v(0, 1.0, SKULL_Z0 - 0.03), DARKRED)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- eyes on the front face, wrapping the corner a little so they read in 3/4
	tell(B.add("Skull", "Eye" .. side, "Part", v(0.4, 0.3, 0.1),
		CFrame.new(s * 0.78, 1.65, SKULL_Z0 - 0.03) * CFrame.Angles(0, -s * 0.3, 0), BLOOD))
end
B.joint("JointHead", "Collar", "Skull", v(0, 1.4, COLLAR_Z0 + 0.1))

-- Pincers: hinged at the lower front corners, sweeping forward and in
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local seg = "Jaw" .. side
	local a = v(s * 0.95, 1.0, SKULL_Z0 + 0.3)
	local b = v(s * 0.85, 1.0, SKULL_Z0 - 0.75)
	local c = v(s * 0.3, 1.0, SKULL_Z0 - 1.25)
	B.limb(seg, seg, a, b, 0.55, 0.6, RED, 0.2)
	B.limb(seg, seg .. "Tip", b, c, 0.4, 0.45, BONE, 0.2)
	tell(B.add(seg, "PincerTell" .. side, "Part", v(0.3, 0.06, 0.5),
		CFrame.new(s * 0.85, 1.33, SKULL_Z0 - 0.4), BLOOD))
	B.joint("JointJaw" .. side, "Skull", seg, a)
end

-- Antennae: thin whips from the brow, forward and out
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local seg = "Ant" .. side
	local a = v(s * 0.7, 2.2, SKULL_Z0 + 0.5)
	local b = v(s * 1.2, 2.75, SKULL_Z0 - 0.7)
	local c = v(s * 1.9, 2.9, SKULL_Z0 - 1.6)
	B.limb(seg, seg, a, b, 0.22, 0.22, RED, 0.1)
	B.limb(seg, seg .. "Tip", b, c, 0.16, 0.16, BONE, 0.1)
	B.joint("JointAnt" .. side, "Skull", seg, a)
end

-- Body plates ------------------------------------------------------------------------------

local function legs(i, zc, w, parentSeg)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local name = "Leg" .. side .. i
		local a = v(s * (w / 2 + 0.1), 0.95, zc)
		local b = v(s * (w / 2 + LEG_OUT), 0.12, zc + 0.15)
		B.limb(name, name, a, b, LEG_W, LEG_W, if i % 2 == 0 then RED else DARKRED, 0.12)
		B.joint("Joint" .. name, parentSeg, name, a)
	end
end

local prev = "Collar"
for i = 1, SEGS do
	local t = (i - 1) / (SEGS - 1)
	local w, h = lerp(W0, W1, t), lerp(H0, H1, t)
	local z0 = COLLAR_Z1 + (i - 1) * SEG_LEN
	local zc = z0 + SEG_LEN / 2
	local len = SEG_LEN + PAD
	local name = "Seg" .. i
	local shade = if i % 2 == 1 then BONE else BONE2
	B.block(name, name, v(w, h - 0.3, len), v(0, FLOOR + (h - 0.3) / 2, zc), shade)
	B.block(name, name .. "Top", v(w * 0.7, 0.3, len), v(0, FLOOR + h - 0.15, zc), BONE)
	B.block(name, name .. "Skirt", v(w + 0.3, 0.5, SEG_LEN - 0.05), v(0, FLOOR + 0.2, zc), RED)
	-- seam strip across the top at the plate's front edge, 0.03 proud
	tell(B.block(name, "SeamTell" .. i, v(w * 0.7 + 0.02, 0.06, 0.16), v(0, FLOOR + h + 0.03, z0 + 0.12), BLOOD))
	B.joint("JointSeg" .. i, prev, name, v(0, 1.2, z0))
	legs(i, zc, w, name)
	prev = name
end

-- Tail: the final plate with two cerci
do
	local z0 = COLLAR_Z1 + SEGS * SEG_LEN
	local w, h = W1 - 0.3, H1 - 0.15
	local zc, len = z0 + 0.55, 1.1 + PAD
	B.block("Tail", "Tail", v(w, h - 0.3, len), v(0, FLOOR + (h - 0.3) / 2, zc), BONE2)
	B.block("Tail", "TailTop", v(w * 0.7, 0.3, len), v(0, FLOOR + h - 0.15, zc), BONE)
	B.block("Tail", "TailSkirt", v(w + 0.3, 0.5, 1.05), v(0, FLOOR + 0.2, zc), RED)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local a = v(s * 0.35, 0.95, z0 + 0.8)
		local b = v(s * 0.8, 0.8, z0 + 2.0)
		B.limb("Tail", "Cercus" .. side, a, b, 0.32, 0.32, RED, 0.12)
		B.limb("Tail", "CercusTip" .. side, b, v(s * 0.55, 0.75, z0 + 2.6), 0.2, 0.2, BONE, 0.1)
	end
	B.joint("JointTail", prev, "Tail", v(0, 1.2, z0))
end

return B.finish()
