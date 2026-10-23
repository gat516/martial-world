--!nocheck
-- Venom Serpent: a hooded cobra built from Studio parts, rebuilding the old coil-of-balls
-- VenomSerpent in the Spirit Wolf B style. Run in Edit mode through execute_luau; it
-- rebuilds ServerStorage._RosterBeasts.VenomSerpent (body plus joint attributes), then
-- run rig_venom_serpent.luau on it.
--
-- Shape: the back two thirds lie on the ground in an S-curve, the front third rears up
-- into a hooded neck with the head held level at player-head height. The spine is one
-- chain of tube segments: Body (the root) -> Neck1-3 -> Skull -> Jaw forward and
-- Body -> Tail1-5 back, with the two hood halves hinged on Neck3.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("VenomSerpent")
local v, tell = B.v, B.tell

local DEEP = Color3.fromHex("23402B") -- back
local MOSS = Color3.fromHex("3A6B3C") -- back bands
local DARK = Color3.fromHex("15221A") -- dorsal stripe, brows, lips
local BELLY = Color3.fromHex("C8DC6A") -- venom-green belly and hood face
local MOUTH = Color3.fromHex("7A2E3A")
local TONGUE = Color3.fromHex("B0303A")
local BONE = Color3.fromHex("EEE9DC")
local VENOM = Color3.fromHex("8CFF3A") -- tells: eyes, venom sacs, hood eye-spots

-- Spine points: N0 is where the neck leaves the ground, B1 the Body's back end.
local N0, N1, N2, N3 = v(0, 0.65, -0.4), v(0, 1.75, -1.2), v(0, 2.95, -1.55), v(0, 4.05, -1.6)
local B1 = v(0.9, 0.62, 0.9)
local TAIL = { v(0.8, 0.58, 2.5), v(-0.4, 0.52, 3.6), v(-1.3, 0.45, 5.0), v(-0.7, 0.36, 6.4), v(0.6, 0.27, 7.1) }
local TAIL_W = { 1.25, 1.1, 0.95, 0.75, 0.55 }
local PAD = 0.55
local BACK_UP = v(0, 0, 1) -- the rearing neck's back faces +Z, its belly faces the prey

-- Body and tail on the ground -------------------------------------------------------------

B.tube("Body", B1, N0, 1.3, 1.2, DEEP, BELLY, PAD, nil, DARK)
B.joint("JointRoot", "HumanoidRootPart", "Body", (B1 + N0) / 2)
local prev, prevSeg = B1, "Body"
for i, p in TAIL do
	local seg = "Tail" .. i
	B.tube(seg, prev, p, TAIL_W[i], TAIL_W[i] * 0.9, if i % 2 == 1 then MOSS else DEEP, BELLY, PAD, nil, DARK)
	B.joint(if i == 1 then "JointTail" else "JointTail" .. i, prevSeg, seg, prev)
	prev, prevSeg = p, seg
end
-- a dark barb at the tip
local tipDir = (TAIL[5] - TAIL[4]).Unit
B.add("Tail5", "TailBarb", "WedgePart", v(0.3, 0.3, 0.6),
	CFrame.lookAt(TAIL[5] + tipDir * 0.35, TAIL[5] + tipDir * 2), DARK)

-- Rearing neck and hood -------------------------------------------------------------------

B.tube("Neck1", N0, N1, 1.25, 1.15, MOSS, BELLY, PAD, BACK_UP, DARK, 0.6)
B.joint("JointNeck", "Body", "Neck1", N0)
B.tube("Neck2", N1, N2, 1.12, 1.05, DEEP, BELLY, PAD, BACK_UP, DARK, 0.6)
B.joint("JointNeck2", "Neck1", "Neck2", N1)
B.tube("Neck3", N2, N3, 1.0, 0.95, MOSS, BELLY, PAD, BACK_UP, DARK, 0.6)
B.joint("JointNeck3", "Neck2", "Neck3", N2)

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local seg = "Hood" .. side
	local hinge = v(s * 0.35, 3.45, -1.5)
	-- the plate's frame: centred out from the hinge, outer edge swept back a little
	local f = CFrame.new(hinge) * CFrame.Angles(0, -s * 0.28, 0) * CFrame.new(s * 0.72, 0, 0)
	B.on(f, seg, seg, "Part", v(1.45, 2.3, 0.2), CFrame.identity, DEEP)
	B.on(f, seg, seg .. "Cap", "Part", v(1.0, 0.4, 0.2), CFrame.new(-s * 0.2, 1.35, 0), DEEP)
	B.on(f, seg, seg .. "Low", "Part", v(0.85, 0.7, 0.2), CFrame.new(-s * 0.3, -1.45, 0), DEEP)
	B.on(f, seg, seg .. "Face", "Part", v(1.2, 2.2, 0.06), CFrame.new(-s * 0.06, 0.05, -0.12), MOSS)
	B.on(f, seg, seg .. "Rim", "Part", v(0.14, 2.3, 0.08), CFrame.new(s * 0.68, 0, -0.12), DARK)
	tell(B.on(f, seg, "HoodSpot" .. side, "Part", v(0.42, 0.55, 0.05), CFrame.new(s * 0.08, 0.5, -0.17), VENOM))
	B.on(f, seg, seg .. "SpotRing", "Part", v(0.66, 0.8, 0.04), CFrame.new(s * 0.08, 0.5, -0.155), DARK)
	B.on(f, seg, seg .. "Bar", "Part", v(0.9, 0.14, 0.04), CFrame.new(-s * 0.06, -0.45, -0.155), DARK)
	B.joint("JointHood" .. side, "Neck3", seg, hinge)
end

-- Head -------------------------------------------------------------------------------------
-- Built in the head frame hf: level, nose a touch down, -Z forward.

local hf = CFrame.new(0, 4.3, -2.4) * CFrame.Angles(-0.08, 0, 0)
B.on(hf, "Skull", "Skull", "Part", v(1.2, 0.6, 1.6), CFrame.new(0, 0.1, -0.05), DEEP)
B.on(hf, "Skull", "Jowls", "Part", v(1.45, 0.62, 0.75), CFrame.new(0, 0.05, 0.5), DEEP)
B.on(hf, "Skull", "Crown", "Part", v(0.7, 0.16, 1.4), CFrame.new(0, 0.46, 0.05), DARK)
B.on(hf, "Skull", "SnoutTop", "WedgePart", v(0.95, 0.25, 0.6), CFrame.new(0, 0.52, -0.55), MOSS)
B.on(hf, "Skull", "Lip", "Part", v(1.22, 0.08, 1.6), CFrame.new(0, -0.22, -0.05), DARK)
B.on(hf, "Skull", "Chin", "Part", v(1.3, 0.25, 0.7), CFrame.new(0, -0.32, 0.5), BELLY)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.on(hf, "Skull", "Brow" .. side, "Part", v(0.42, 0.16, 0.5), CFrame.new(s * 0.42, 0.45, -0.35) * CFrame.Angles(0, 0, s * 0.3), DARK)
	tell(B.on(hf, "Skull", "Eye" .. side, "Part", v(0.12, 0.16, 0.32), CFrame.new(s * 0.6, 0.28, -0.35) * CFrame.Angles(0, -s * 0.25, s * 0.3), VENOM))
	-- venom sacs bulging at the jowls: the spit tell
	local sac = B.add("Skull", "VenomSac" .. side, "Part", v(0.5, 0.5, 0.5), hf * CFrame.new(s * 0.68, -0.05, 0.45), VENOM)
	sac.Shape = Enum.PartType.Ball
	tell(sac)
	B.on(hf, "Skull", "Nostril" .. side, "Part", v(0.1, 0.08, 0.06), CFrame.new(s * 0.2, 0.3, -0.86), DARK)
	B.fin("Skull", "Fang" .. side, v(s * 0.32, -0.24, -0.62), 0.45, 0.16, 0.12, BONE, math.pi, 0, hf)
end

-- jaw: hinged at the back of the head
B.on(hf, "Jaw", "Jaw", "Part", v(1.05, 0.22, 1.45), CFrame.new(0, -0.39, -0.12), BELLY)
B.on(hf, "Jaw", "JawMouth", "Part", v(0.85, 0.06, 1.25), CFrame.new(0, -0.26, -0.12), MOUTH)
B.on(hf, "Jaw", "Tongue", "Part", v(0.1, 0.05, 0.75), CFrame.new(0, -0.24, -0.9), TONGUE)
B.on(hf, "Jaw", "TongueForkL", "Part", v(0.06, 0.05, 0.25), CFrame.new(-0.06, -0.24, -1.33) * CFrame.Angles(0, 0.45, 0), TONGUE)
B.on(hf, "Jaw", "TongueForkR", "Part", v(0.06, 0.05, 0.25), CFrame.new(0.06, -0.24, -1.33) * CFrame.Angles(0, -0.45, 0), TONGUE)

B.joint("JointHead", "Neck3", "Skull", N3)
B.joint("JointJaw", "Skull", "Jaw", (hf * CFrame.new(0, -0.3, 0.55)).Position)

return B.finish()
