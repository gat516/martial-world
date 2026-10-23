--!nocheck
-- Jade Python (elite): a thick horned python with jade scale plates, built from Studio
-- parts like the Venom Serpent but bigger and on a longer chain. Run in Edit mode through
-- execute_luau; it rebuilds ServerStorage._RosterBeasts.JadePython (body plus joint
-- attributes), then run rig_jade_python.luau on it.
--
-- Shape: the body lies in a loose coil behind (Body -> Tail1-7 curling round to the
-- front left), and the front rises in a strike S (Neck1-4) holding the head level at
-- player-head height, ready to lunge. Horn nubs mark it as a serpent on its way to
-- becoming a jiao (a horned flood dragon).

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("JadePython")
local v, tell = B.v, B.tell

local BACK = Color3.fromHex("1E4D3F") -- deep jade body
local BACK_HI = Color3.fromHex("2A6352")
local JADE = Color3.fromHex("5FBF8F") -- scale plates
local JADE_HI = Color3.fromHex("86D6A8")
local BELLY = Color3.fromHex("E3D7A0") -- cream-gold belly
local HORN = Color3.fromHex("D9E4C4")
local DARK = Color3.fromHex("12261F")
local MOUTH = Color3.fromHex("7A3A3A")
local BONE = Color3.fromHex("EEE9DC")
local AMBER = Color3.fromHex("FFB13B") -- tell: eyes
local VEIN = Color3.fromHex("7DFFCF") -- tell: brow pearl and neck gems

local PAD = 0.7
local BACK_UP = v(0, 0, 1)

-- Spine points: N0 where the neck leaves the ground, N4 the head pivot, B1 the Body's back.
local NECK = { v(0, 1.05, -1.3), v(0, 2.3, -3.0), v(0, 3.5, -1.85), v(0, 4.35, -2.95), v(0, 4.6, -3.65) }
local NECK_W = { 1.85, 1.65, 1.5, 1.4 }
local B1 = v(1.9, 1.0, 0.4)
local TAIL = { v(2.7, 0.95, 2.4), v(1.7, 0.9, 4.3), v(-0.6, 0.82, 5.0), v(-2.6, 0.72, 4.0), v(-3.2, 0.6, 2.0),
	v(-2.7, 0.48, 0.0), v(-1.7, 0.36, -1.5) }
local TAIL_W = { 2.0, 1.85, 1.65, 1.45, 1.2, 0.95, 0.7 }

-- A jade scute on the back of a segment: a wedge shingle, slope forward.
local function scute(seg, frame, w, h, len, color)
	B.on(frame, seg, seg .. "Scute", "WedgePart", v(w * 0.62, 0.3, len * 0.62), CFrame.new(0, h / 2 + 0.12, 0.08), color)
	B.on(frame, seg, seg .. "ScuteBase", "Part", v(w * 0.66, 0.12, len * 0.7), CFrame.new(0, h / 2 + 0.02, 0.05), color)
end

-- A knuckle block filling the outside of a sharp bend at p, between bones a->p and p->b.
local function knuckle(seg, name, a, p, b, w, h, color, up)
	local dir = ((p - a).Unit + (b - p).Unit).Unit
	B.add(seg, name, "Part", v(w * 0.96, h * 0.96, w * 0.75), CFrame.lookAt(p, p + dir, up or Vector3.yAxis), color)
end

-- Body and coiled tail ---------------------------------------------------------------------

local _, f = B.tube("Body", B1, NECK[1], 2.1, 1.95, BACK, BELLY, PAD, nil, BACK_HI)
scute("Body", f, 2.1, 1.95, (NECK[1] - B1).Magnitude, JADE)
B.joint("JointRoot", "HumanoidRootPart", "Body", (B1 + NECK[1]) / 2)
local prev, prevSeg = B1, "Body"
for i, p in TAIL do
	local seg = "Tail" .. i
	local w = TAIL_W[i]
	local _, tf = B.tube(seg, prev, p, w, w * 0.92, BACK, BELLY, PAD, nil, BACK_HI)
	scute(seg, tf, w, w * 0.92, (p - prev).Magnitude, if i % 2 == 1 then JADE_HI else JADE)
	B.joint(if i == 1 then "JointTail" else "JointTail" .. i, prevSeg, seg, prev)
	prev, prevSeg = p, seg
end
local tipDir = (TAIL[7] - TAIL[6]).Unit
B.add("Tail7", "TailTip", "WedgePart", v(0.5, 0.45, 0.8), CFrame.lookAt(TAIL[7] + tipDir * 0.45, TAIL[7] + tipDir * 2), BACK)

-- Strike S neck ----------------------------------------------------------------------------

prevSeg = "Body"
for i = 1, 4 do
	local seg = "Neck" .. i
	local a, b = NECK[i], NECK[i + 1]
	local w = NECK_W[i]
	-- the rising bones keep their back to +Z; the last, nearly level one keeps it up
	local up = if (b - a).Unit.Y > 0.5 then BACK_UP else Vector3.yAxis
	local _, nf = B.tube(seg, a, b, w, w * 0.95, BACK, BELLY, PAD, up, BACK_HI, 0.62)
	if i < 4 then
		scute(seg, nf, w, w * 0.95, (b - a).Magnitude, if i % 2 == 1 then JADE else JADE_HI)
	end
	B.joint(if i == 1 then "JointNeck" else "JointNeck" .. i, prevSeg, seg, a)
	prevSeg = seg
end
knuckle("Neck2", "Neck2Knuckle", NECK[1], NECK[2], NECK[3], NECK_W[2], NECK_W[2] * 0.95, BACK, BACK_UP)
knuckle("Neck3", "Neck3Knuckle", NECK[2], NECK[3], NECK[4], NECK_W[3], NECK_W[3] * 0.95, BACK, BACK_UP)
-- spirit-vein gems along the neck's back: the windup tell
for i = 2, 3 do
	local a, b = NECK[i], NECK[i + 1]
	local nf = B.bone(a, b, BACK_UP)
	tell(B.on(nf, "Neck" .. i, "VeinGem" .. i, "Part", v(0.35, 0.18, 0.55), CFrame.new(0, NECK_W[i] * 0.475 + 0.17, 0), VEIN))
end

-- Head -------------------------------------------------------------------------------------

local hf = CFrame.new(0, 4.55, -4.7) * CFrame.Angles(-0.05, 0, 0)
-- a broad skull stepping down to a narrower snout: the step carries the brows and the
-- eyes, which wrap its corners so they read from the front and the side
B.on(hf, "Skull", "Skull", "Part", v(1.6, 0.8, 1.4), CFrame.new(0, 0.12, 0.4), BACK)
B.on(hf, "Skull", "Snout", "Part", v(1.2, 0.68, 0.95), CFrame.new(0, 0.06, -0.77), BACK)
B.on(hf, "Skull", "Jowls", "Part", v(1.95, 0.85, 1.0), CFrame.new(0, 0.05, 0.75), BACK)
B.on(hf, "Skull", "Crown", "Part", v(1.05, 0.2, 1.3), CFrame.new(0, 0.6, 0.35), JADE)
B.on(hf, "Skull", "SnoutTop", "WedgePart", v(0.95, 0.25, 0.7), CFrame.new(0, 0.52, -0.85), BACK_HI)
B.on(hf, "Skull", "Lip", "Part", v(1.22, 0.1, 0.95), CFrame.new(0, -0.31, -0.77), BELLY)
B.on(hf, "Skull", "LipBack", "Part", v(1.62, 0.1, 1.4), CFrame.new(0, -0.31, 0.4), BELLY)
tell(B.on(hf, "Skull", "BrowPearl", "Part", v(0.32, 0.22, 0.32), CFrame.new(0, 0.78, -0.05) * CFrame.Angles(0, math.pi / 4, 0), VEIN))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.on(hf, "Skull", "Brow" .. side, "Part", v(0.5, 0.2, 0.55), CFrame.new(s * 0.56, 0.6, -0.3) * CFrame.Angles(0, 0, s * 0.25), DARK)
	tell(B.on(hf, "Skull", "Eye" .. side, "Part", v(0.22, 0.2, 0.06), CFrame.new(s * 0.69, 0.34, -0.32), AMBER))
	tell(B.on(hf, "Skull", "EyeSide" .. side, "Part", v(0.06, 0.2, 0.3), CFrame.new(s * 0.81, 0.34, -0.15), AMBER))
	B.on(hf, "Skull", "Nostril" .. side, "Part", v(0.16, 0.1, 0.06), CFrame.new(s * 0.3, 0.22, -1.25), DARK)
	-- heat pits along the snout's lip
	for i, z in { -1.0, -0.72, -0.44 } do
		B.on(hf, "Skull", "Pit" .. side .. i, "Part", v(0.06, 0.14, 0.16), CFrame.new(s * 0.61, -0.12, z), DARK)
	end
	-- horn nubs: a big pair swept back off the crown, a small pair in front of them
	B.limb("Skull", "Horn" .. side, (hf * CFrame.new(s * 0.42, 0.6, 0.45)).Position,
		(hf * CFrame.new(s * 0.62, 1.05, 1.35)).Position, 0.34, 0.34, HORN, 0.2)
	B.limb("Skull", "HornNub" .. side, (hf * CFrame.new(s * 0.45, 0.55, -0.05)).Position,
		(hf * CFrame.new(s * 0.55, 0.85, 0.25)).Position, 0.22, 0.22, HORN, 0.1)
	for i, z in { -1.05, -0.75, -0.45 } do
		B.fin("Skull", "Tooth" .. side .. i, v(s * 0.47, -0.36, z), 0.22, 0.14, 0.1, BONE, math.pi, 0, hf)
	end
end

B.on(hf, "Jaw", "Jaw", "Part", v(1.15, 0.3, 1.0), CFrame.new(0, -0.53, -0.72), BELLY)
B.on(hf, "Jaw", "JawBack", "Part", v(1.5, 0.32, 1.15), CFrame.new(0, -0.54, 0.33), BELLY)
B.on(hf, "Jaw", "JawMouth", "Part", v(0.9, 0.06, 1.85), CFrame.new(0, -0.38, -0.25), MOUTH)
B.on(hf, "Jaw", "Throat", "Part", v(1.7, 0.3, 0.9), CFrame.new(0, -0.5, 0.75), BELLY) -- rides the jaw, so it opens with it
for _, s in { -1, 1 } do
	for i, z in { -0.95, -0.55 } do
		B.fin("Jaw", "LowerTooth" .. (if s < 0 then "L" else "R") .. i, v(s * 0.42, -0.4, z), 0.18, 0.12, 0.1, BONE, 0, 0, hf)
	end
end

B.joint("JointHead", "Neck4", "Skull", NECK[5])
B.joint("JointJaw", "Skull", "Jaw", (hf * CFrame.new(0, -0.45, 0.85)).Position)

return B.finish()
