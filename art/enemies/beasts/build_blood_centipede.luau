--!nocheck
-- Blood Centipede: a QC6 earth-blood demon centipede of the Ruined Borderlands that burrows
-- and erupts, kin to the blood cultivators (Blood Sect Cultist palette). Built from Studio
-- parts with the shared lib.luau helpers. Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterBeasts.BloodCentipede (body plus joint attributes), then run
-- rig_blood_centipede.luau on it.
--
-- Intent: a long, low armoured beast whose read at 40 studs is a sawtooth of overlapping
-- crimson shingles with a fringe of bone legs, led by a broad flat head and a pair of big
-- curved bone pincers (the hero shape: they open wide in the windup and slam shut). Threat,
-- not gore. The blood-red seams in the plate troughs, the eyes, the pincer strips and the
-- collar core are the Tells: dim at rest, they flare front to back in a windup.
--
-- Shape: ~15.5 studs nose to the rear spines, plates 1.8-2.4 tall (2.9 at the antenna tips),
-- 3.3 wide at the head shield, ~5.5 wide with the legs out. The chain is Skull (front) ->
-- Collar (the root plate) -> Seg1..12 -> Tail; the chain pivots are fixed by the pose module
-- (EnemyPoses/BloodCentipede.luau NODE table), so the plate pitch and pivots are not tunables.
-- Each plate is a shingle in its own tilted frame (origin at the plate's front-bottom centre,
-- +Z rearward): a wide wedge slab (dark crimson rim, thin in front, thick at the back) that
-- overhangs the next plate, a narrower, taller crimson cap wedge on it (the ridge), a black
-- belly block under it, and the SeamTell lying in the trough just behind the plate in front's
-- overhang. Legs are two pieces (dark femur, bone claw) on one joint at the hip under the slab.
-- Faces -Z, left is -X, ground Y=0.
--
-- Palette (4 + glow): BLACK belly and maw, DEEP crimson slabs, head capsule and femurs,
-- CRIMSON caps and head shield, BONE claws, pincers, spines and antenna tips; GLOW dim neon.

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("BloodCentipede")
local v, tell = B.v, B.tell

-- Tunables ---------------------------------------------------------------------------------
local SEGS = 12 -- fixed by the pose module
local PITCH = 0.8 -- z pitch of one body plate (fixed by the pose module)
local COLLAR_Z0, COLLAR_Z1 = -5.5, -4.3 -- the collar plate (fixed: JointRoot pivots at its middle)
local OVL = 0.28 -- how far each plate's slab overhangs the plate behind it
local TILT = 0.06 -- shingle tilt (rad): each plate's back edge rides up over the next plate
local FLOOR = 0.45 -- underside of the belly blocks
local W0, W1 = 3.1, 2.15 -- slab width, Seg1 to Seg12
local YB0, YB1 = 1.5, 1.15 -- slab underside at the plate front, Seg1 to Seg12
local T0, T1 = 0.46, 0.38 -- slab thickness at its back edge
local HC0, HC1 = 0.72, 0.56 -- cap height at its back edge (the ridge)
local CAP_W = 0.6 -- cap width as a share of the slab
local CAP_Z0 = 0.4 -- where the cap wedge starts behind the plate front (local z)
local BELLY_W = 0.72 -- belly width as a share of the slab
local SEAM_Z0, SEAM_Z1 = OVL + 0.02, OVL + 0.2 -- the trough strip, local z
local LEG_OUT = 0.85 -- knee outside the slab edge
local KNEE_UP = 0.3 -- knee above the slab underside, so each leg reads bent
local FOOT_OUT = 1.3 -- foot outside the slab edge
local FOOT_BACK = 0.45 -- feet trail the hip by this much (legs rake back)

local BLACK = Color3.fromHex("2A1014")
local DEEP = Color3.fromHex("3C0E12")
local CRIMSON = Color3.fromHex("A0242A")
local LEG = Color3.fromHex("6E1A1F") -- femurs and pincer bases: between DEEP and CRIMSON
local BONE = Color3.fromHex("D9CAA6")
local GLOW = Color3.fromHex("6A1A12") -- dim at rest; BeastKit.tell flares it to (255,120,96)

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- A tapering bone: a wedge whose point is at `tip` and whose full height h stands at `base`,
-- the height spanning toward `hint` (the convex side), `thick` across.
local function claw(seg, name, tip, base, h, thick, hint, color)
	local z = (base - tip).Unit
	local y = (hint - z * hint:Dot(z)).Unit
	local x = y:Cross(z)
	local cf = CFrame.fromMatrix((tip + base) / 2 + y * (h / 2), x, y, z)
	return B.add(seg, name, "WedgePart", v(thick, h, (base - tip).Magnitude), cf, color)
end

-- One shingle plate in its tilted frame. Returns the frame and the slab.
local function plate(seg, z0, len, w, yb, t, hc, slabName, capName)
	local F = CFrame.new(0, yb, z0) * CFrame.Angles(-TILT, 0, 0)
	local slab = B.add(seg, slabName, "WedgePart", v(w, t, len), F * CFrame.new(0, t / 2, len / 2), DEEP)
	local c0, c1 = CAP_Z0, len - 0.03
	B.add(seg, capName, "WedgePart", v(w * CAP_W, hc, c1 - c0), F * CFrame.new(0, hc / 2, (c0 + c1) / 2), CRIMSON)
	-- belly: from the floor up into the slab, overlapping the bellies either side
	local bTop = 0.07
	local bBot = FLOOR - yb
	local own = len - OVL -- this plate's own pitch; the belly reaches 0.12 under each neighbour
	B.add(seg, seg .. "Belly", "Part", v(w * BELLY_W, bTop - bBot, own + 0.24),
		F * CFrame.new(0, (bTop + bBot) / 2, own / 2), BLACK)
	return F, slab
end

-- The glowing strip lying on the slab slope in the trough (local z SEAM_Z0..SEAM_Z1).
local function seam(seg, name, F, len, w, t)
	local slope = math.atan(t / len)
	local zc = (SEAM_Z0 + SEAM_Z1) / 2
	local cf = F * CFrame.new(0, t * zc / len, zc) * CFrame.Angles(slope, 0, 0)
	return tell(B.add(seg, name, "Part", v(w * 0.84, 0.07, SEAM_Z1 - SEAM_Z0), cf, GLOW))
end

-- Head ---------------------------------------------------------------------------------------

-- Collar: the first, biggest plate; the root segment. CoreGlow is its trough strip, glowing
-- under the head shield's back edge.
do
	local len = COLLAR_Z1 - COLLAR_Z0 + OVL
	local F = plate("Collar", COLLAR_Z0, len, 3.25, 1.56, 0.5, 0.8, "Collar", "CollarCap")
	seam("Collar", "CoreGlow", F, len, 3.25, 0.5)
	B.joint("JointRoot", "HumanoidRootPart", "Collar", v(0, 1.3, (COLLAR_Z0 + COLLAR_Z1) / 2))
end

-- Skull: a dark head capsule under a broad, flat crimson shield (a wedge, thin at the nose,
-- thick at the back where it overhangs the collar), with a raised crest down its middle.
local SKULL_Z0 = -7.3 -- front of the capsule
local SHIELD_Z0, SHIELD_Z1 = -7.45, -5.22
do
	B.block("Skull", "Skull", v(2.6, 0.98, -5.3 - SKULL_Z0), v(0, 1.22, (SKULL_Z0 - 5.3) / 2), DEEP)
	local sl = SHIELD_Z1 - SHIELD_Z0
	local sb = 1.69 -- shield underside
	B.add("Skull", "SkullShield", "WedgePart", v(3.35, 0.72, sl), CFrame.new(0, sb + 0.36, (SHIELD_Z0 + SHIELD_Z1) / 2), CRIMSON)
	-- crest: a narrower ridge from mid-shield back, same rake, the head's highest line
	B.add("Skull", "SkullCrest", "WedgePart", v(1.25, 0.98, sl - 0.75),
		CFrame.new(0, sb + 0.49, SHIELD_Z1 - (sl - 0.75) / 2 - 0.02), CRIMSON)
	-- bone brow ridges over the eyes, raked back along the shield's slope
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		claw("Skull", "Brow" .. side, v(s * 1.62, 1.78, -7.45), v(s * 1.1, 2.08, -6.35), 0.26, 0.3, v(0, 1, 0), BONE)
	end
	B.block("Skull", "Maw", v(1.25, 0.36, 0.12), v(0, 1.12, SKULL_Z0 - 0.04), BLACK)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		-- eyes on the capsule front, wrapping the corner so they read in 3/4
		tell(B.add("Skull", "Eye" .. side, "Part", v(0.44, 0.24, 0.1),
			CFrame.new(s * 0.95, 1.46, SKULL_Z0 - 0.03) * CFrame.Angles(0, -s * 0.35, 0), GLOW))
	end
	B.joint("JointHead", "Collar", "Skull", v(0, 1.4, COLLAR_Z0 + 0.1))
end

-- Pincers (forcipules), the hero: a thick crimson base out of the capsule's lower front
-- corner, a bone shaft curving forward, and a bone hook turning in; tips rest ~0.55 apart.
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local seg = "Jaw" .. side
	local a = v(s * 1.0, 1.18, -6.95)
	local b = v(s * 1.8, 1.16, -7.95)
	local c = v(s * 1.55, 1.13, -8.85)
	local d = v(s * 0.55, 1.1, -9.25)
	B.limb(seg, seg, a, b, 0.7, 0.56, CRIMSON, 0.4)
	B.limb(seg, seg .. "Shaft", b, c, 0.54, 0.46, BONE, 0.34)
	claw(seg, seg .. "Hook", d, c, 0.56, 0.42, v(s * 0.3, 0, -1), BONE)
	-- tell strip along the top of the base, 0.035 proud
	local f = B.bone(a, b)
	tell(B.add(seg, "PincerTell" .. side, "Part", v(0.22, 0.07, 0.78), f * CFrame.new(0, 0.28, -0.05), GLOW))
	B.joint("JointJaw" .. side, "Skull", seg, a)
end

-- Antennae: whips from the shield's front, forward, up and out; dark base, bone tip.
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local seg = "Ant" .. side
	local a = v(s * 0.72, 1.84, -6.95)
	local b = v(s * 1.3, 2.5, -7.95)
	local c = v(s * 2.15, 2.82, -8.65)
	B.limb(seg, seg, a, b, 0.22, 0.22, DEEP, 0.12)
	B.limb(seg, seg .. "Tip", b, c, 0.16, 0.16, BONE, 0.1)
	B.joint("JointAnt" .. side, "Skull", seg, a)
end

-- Body plates ------------------------------------------------------------------------------

local function legs(i, zc, w, yb, seg)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local name = "Leg" .. side .. i
		-- the hip hangs under the slab rim, outboard of the belly, so a swinging femur stays
		-- clear of the neighbouring bellies and slabs
		local hip = v(s * (w / 2 - 0.12), yb - 0.1, zc)
		local inner = v(s * (w / 2 - 0.3), yb - 0.12, zc)
		local knee = v(s * (w / 2 + LEG_OUT), yb + KNEE_UP, zc + 0.06)
		local foot = v(s * (w / 2 + FOOT_OUT), 0.02, zc + FOOT_BACK)
		B.limb(name, name, inner, knee, 0.34, 0.32, CRIMSON, 0.26)
		claw(name, name .. "Claw", foot, knee, 0.38, 0.32, v(s, 0.3, 0), BONE)
		B.joint("Joint" .. name, seg, name, hip)
	end
end

local prev = "Collar"
for i = 1, SEGS do
	local t = (i - 1) / (SEGS - 1)
	local w, yb = lerp(W0, W1, t), lerp(YB0, YB1, t)
	local th, hc = lerp(T0, T1, t), lerp(HC0, HC1, t)
	local z0 = COLLAR_Z1 + (i - 1) * PITCH
	local len = PITCH + OVL
	local name = "Seg" .. i
	local F = plate(name, z0, len, w, yb, th, hc, name, name .. "Cap")
	seam(name, "SeamTell" .. i, F, len, w, th)
	B.joint("JointSeg" .. i, prev, name, v(0, 1.2, z0))
	legs(i, z0 + 0.42, w, yb, name)
	prev = name
end

-- Tail: a short tapering end plate and the two long rear spines (the last leg pair turned
-- into bone spikes), raked up and out.
do
	local z0 = COLLAR_Z1 + SEGS * PITCH
	local w, yb = W1 - 0.25, YB1 - 0.04
	plate("Tail", z0, 0.95, w, yb, T1 - 0.04, HC1 - 0.06, "Tail", "TailCap")
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local a = v(s * 0.5, 1.05, z0 + 0.4)
		local b = v(s * 1.1, 1.35, z0 + 1.4)
		B.limb("Tail", "Spine" .. side, a, b, 0.42, 0.42, CRIMSON, 0.3)
		claw("Tail", "SpineTip" .. side, v(s * 1.0, 2.05, z0 + 2.55), b, 0.5, 0.34, v(s, 0, 0), BONE)
	end
	B.joint("JointTail", prev, "Tail", v(0, 1.2, z0))
end

return B.finish()
