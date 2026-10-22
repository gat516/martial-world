--!nocheck
-- Jade Jiao (boss): a 70-stud jade-black serpent with a cobra hood, built from Studio parts
-- on the Jade Python's palette, bigger, with the Venom Serpent's hood, fangs and sac merged
-- in. Run in Edit mode through execute_luau (art server on :8767); it rebuilds
-- ServerStorage._RosterBeasts.JadeJiao (body plus joint attributes), then run
-- rig_jade_jiao.luau on it. The fight sheet and joint contract: RIGS.md "Jade Jiao".
--
-- Model space: ground Y=0, faces -Z, left is -X. The rest pose: the neck rears in an S
-- (head level at about 10 studs), the hood folds flat against the neck sides, the tail
-- lies straight back along +Z (18 segments, tip at z about 55). Every joint is a tube
-- segment (a cylinder) from its pivot to the next pivot, with a ball on its start pivot
-- (as wide as the parent's end) that hides the gap when the chain bends.
-- No crown, no halo: nothing stands over or rings the head.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("JadeJiao")
local v, tell = B.v, B.tell

-- Size: the build below is authored at 1.9x the roster Jade Python; K lifts it to the user's
-- reference size (Jade Python x3.17). Every part, attachment and joint pivot is scaled about
-- the model origin just before finish(), so all numbers below stay in contract units.
local K = 3.17 / 1.9
local ROSTER_SCALE = 3.17
local rawJoint = B.joint
B.joint = function(name, parentSeg, seg, pivot)
	rawJoint(name, parentSeg, seg, pivot * K)
end

-- Palette (Jade Python's, plus acid venom green) ---------------------------------------------
local BACK = Color3.fromHex("1E4D3F")
local BACK_HI = Color3.fromHex("2A6352")
local JADE = Color3.fromHex("5FBF8F")
local JADE_HI = Color3.fromHex("86D6A8")
local BELLY = Color3.fromHex("E3D7A0")
local HORN = Color3.fromHex("D9E4C4")
local DARK = Color3.fromHex("12261F")
local MOUTH = Color3.fromHex("7A3A3A")
local TONGUE = Color3.fromHex("B0303A")
local BONE = Color3.fromHex("EEE9DC")
local AMBER = Color3.fromHex("FFB13B") -- tell: eyes
local VEIN = Color3.fromHex("7DFFCF") -- tell: brow pearl, gems, seams
local VENOM = Color3.fromHex("9BFF4A") -- fang tips, throat sac, hood eye-spots

-- Tunables -----------------------------------------------------------------------------------
local NECK = { -- pivots P0..P5: JointNeck, Neck2..5, JointHead
	v(0, 1.9, -1.0), v(0, 4.3, -3.8), v(0, 6.6, -2.8), v(0, 8.6, -5.0), v(0, 9.6, -7.0), v(0, 10.0, -8.6) }
local NECK_W = { 3.8, 3.5, 3.2, 2.9, 2.6 }
local BODY_BACK = v(0, 1.9, 6.0) -- Tail1's pivot
local BODY_W = 3.8
local TAIL_LEN = { 3, 3, 3, 3, 3, 3, 2.8, 2.8, 2.8, 2.8, 2.8, 2.8, 2.5, 2.5, 2.5, 2.5, 2.2, 2.0 }
local TAIL_W0, TAIL_W1 = 3.6, 0.8 -- width of Tail1 and of Tail18
local HOOD_LEN, HOOD_H = 6.0, 5.4 -- panel size (studs along the neck, tall)
local SEAMS = { Neck2 = 1, Neck4 = 2, Body = 3, Tail2 = 4, Tail5 = 5, Tail8 = 6, Tail11 = 7, Tail14 = 8, Tail17 = 9 }

local function tellp(p)
	tell(p)
	p:SetAttribute("TellBase", p.Color)
	return p
end

local function hide(p, phase)
	p.Transparency = 1
	p:SetAttribute("PhaseReveal", phase)
	return p
end

local function attach(part, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = part.CFrame:PointToObjectSpace(worldPos)
	a.Parent = part
	return a
end

-- A round tube segment from a to b: a cylinder, a cream belly plate, then either a jade
-- scute or (on seam segments) a neon spine seam. Returns the primary part and its frame.
local function tube(seg, a, b, w, color, up, ball, ballW)
	local frame = B.bone(a, b, up)
	local len = (b - a).Magnitude
	local h = w * 0.95
	local core = B.add(seg, seg, "Part", v(len, h, w), frame * CFrame.Angles(0, math.pi / 2, 0), color)
	core.Shape = Enum.PartType.Cylinder
	B.on(frame, seg, seg .. "Belly", "Part", v(w * 0.5, h * 0.2, len * 0.96), CFrame.new(0, -h * 0.4, 0), BELLY)
	if ball then
		B.ball(seg, seg .. "Knuckle", ballW, a, color)
	end
	local seam = SEAMS[seg]
	if seam then
		tellp(B.on(frame, seg, "ScaleSeam" .. seam, "Part", v(0.24, 0.12, len * 0.8), CFrame.new(0, h / 2 - 0.02, 0), JADE))
	end
	return core, frame, h, len
end

local function scute(seg, frame, w, h, len, color, zoff)
	if SEAMS[seg] then
		return
	end
	B.on(frame, seg, seg .. "Scute", "WedgePart", v(w * 0.5, w * 0.2, len * 0.66),
		CFrame.new(0, h / 2 + w * 0.1 - 0.08, zoff or 0.05), color)
end

-- Body ---------------------------------------------------------------------------------------
local bodyA, bodyB = BODY_BACK, NECK[1]
local _, bf, bh, blen = tube("Body", bodyB, bodyA, BODY_W, BACK, nil, false)
-- tube() frames run a -> b; the body runs back to front, so flip the call: a = back? keep simple:
-- (a and b are interchangeable for a cylinder; the frame's local -Y stays down)
scute("Body", bf, BODY_W, bh, blen, JADE)
B.joint("JointRoot", "HumanoidRootPart", "Body", v(0, 1.9, 2.5))

-- Neck: five segments, Neck_i from NECK[i] to NECK[i+1] ------------------------------------
local BACK_UP = v(0, 0, 1) -- the rising neck's back faces +Z, its belly the prey
local prevSeg = "Body"
local neckFrames = {}
for i = 1, 5 do
	local a, b = NECK[i], NECK[i + 1]
	local w = NECK_W[i]
	local seg = "Neck" .. i
	local up = if (b - a).Unit.Y > 0.5 then BACK_UP else Vector3.yAxis
	local ballW = if i == 1 then BODY_W * 0.96 else NECK_W[i - 1] * 0.97
	local _, f, h, len = tube(seg, a, b, w, BACK, up, true, ballW)
	neckFrames[i] = { f, h, len }
	scute(seg, f, w, h, len, if i % 2 == 1 then JADE else JADE_HI, 0.5)
	B.joint(if i == 1 then "JointNeck" else "JointNeck" .. i, prevSeg, seg, a)
	prevSeg = seg
end
-- spirit-vein gems on the back of Neck2..4: windup tells
for i = 2, 4 do
	local f, h, len = table.unpack(neckFrames[i])
	tellp(B.on(f, "Neck" .. i, "VeinGem" .. i, "Part", v(0.5, 0.26, 0.8), CFrame.new(0, h / 2 + 0.02, -len * 0.28), VEIN))
end
-- phase 3 dorsal ridge: five fins, one per neck segment (hidden until the phase flips)
for i = 1, 5 do
	local f, h, len = table.unpack(neckFrames[i])
	local fin = B.add("Neck" .. i, "P3Fin" .. i, "WedgePart", v(0.3, 1.9 - 0.12 * i, len * 0.6),
		f * CFrame.new(0, h / 2 + (1.9 - 0.12 * i) / 2 - 0.1, 0), JADE_HI)
	hide(fin, 3)
end

-- Tail: 18 segments, straight back along +Z; pivots sit at half the width above the ground ---
local tailW = {}
for i = 1, 18 do
	tailW[i] = TAIL_W0 + (TAIL_W1 - TAIL_W0) * (i - 1) / 17
end
local TP = { BODY_BACK } -- TP[i] is Tail_i's pivot, TP[19] its tip
do
	local z = BODY_BACK.Z
	for i = 1, 18 do
		z += TAIL_LEN[i]
		local wn = if i < 18 then tailW[i + 1] else tailW[18] * 0.8
		TP[i + 1] = v(0, wn / 2 + 0.1, z)
	end
end
TP[1] = v(0, tailW[1] / 2 + 0.1, BODY_BACK.Z)
prevSeg = "Body"
local tailSegs = {}
for i = 1, 18 do
	local seg = "Tail" .. i
	local w = tailW[i]
	local ballW = (if i == 1 then BODY_W else tailW[i - 1]) * 0.97
	local _, f, h, len = tube(seg, TP[i], TP[i + 1], w, BACK, nil, true, ballW)
	scute(seg, f, w, h, len, if i % 2 == 1 then JADE_HI else JADE)
	B.joint(if i == 1 then "JointTail" else "JointTail" .. i, prevSeg, seg, TP[i])
	tailSegs[i] = { f, h, len, w }
	prevSeg = seg
end
-- tail tip: a jade gem on a short barb
do
	local tip = TP[19]
	local dir = (TP[19] - TP[18]).Unit
	B.add("Tail18", "TailBarb", "WedgePart", v(0.45, 0.45, 1.1), CFrame.lookAt(tip + dir * 0.3, tip + dir * 2), DARK)
	local gem = B.ball("Tail18", "TailTipGem", 1.0, tip + dir * 0.1, VEIN)
	tellp(gem)
end

-- Phase 2 cracks: glow fissures on the back (Body, Tail1..4) ---------------------------------
do
	local f, h = bf, bh
	local function crack(name, seg, frame, hh, x, z, yaw, len)
		local p = B.on(frame, seg, name, "Part", v(0.2, 0.08, len), CFrame.new(x, hh / 2 - 0.02, z) * CFrame.Angles(0, yaw, 0), VEIN)
		hide(p, 2)
	end
	crack("P2Crack1", "Body", bf, bh, -0.7, -0.8, 0.5, 2.2)
	crack("P2Crack2", "Body", bf, bh, 0.8, 1.2, -0.45, 2.4)
	local t = tailSegs
	crack("P2Crack3", "Tail1", t[1][1], t[1][2], -0.5, 0.2, 0.45, 2.0)
	crack("P2Crack4", "Tail2", t[2][1], t[2][2], 0.55, -0.3, -0.5, 1.9)
	crack("P2Crack5", "Tail3", t[3][1], t[3][2], -0.4, 0.4, 0.4, 1.8)
	crack("P2Crack6", "Tail4", t[4][1], t[4][2], 0.4, -0.2, -0.45, 1.7)
end

-- Hood: two panels hinged on Neck4's sides, folded flat against the neck at rest -----------
-- The panel extends back (+Z) from its hinge; a yaw about the hinge flares it outward:
-- -Y on L, +Y on R. Its outer face turns to face front as it flares and carries the eye-spot.
do
	local n4 = (NECK[4] + NECK[5]) / 2
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local seg = "Hood" .. side
		local hinge = v(s * (NECK_W[4] / 2 + 0.05), n4.Y, NECK[5].Z + 0.6)
		local f = CFrame.new(hinge)
		local cz = HOOD_LEN / 2
		B.on(f, seg, seg, "Part", v(0.25, 3.6, HOOD_LEN), CFrame.new(s * 0.125, 0, cz), BACK)
		B.on(f, seg, seg .. "Cap", "Part", v(0.25, 1.0, HOOD_LEN * 0.66), CFrame.new(s * 0.125, 2.3, cz + 0.4), BACK)
		B.on(f, seg, seg .. "Low", "Part", v(0.25, 0.9, HOOD_LEN * 0.66), CFrame.new(s * 0.125, -2.25, cz + 0.4), BACK)
		B.on(f, seg, seg .. "Face", "Part", v(0.06, HOOD_H - 0.8, HOOD_LEN - 0.9), CFrame.new(s * 0.28, 0, cz + 0.2), JADE)
		B.on(f, seg, seg .. "Rim", "Part", v(0.3, HOOD_H - 0.3, 0.3), CFrame.new(s * 0.14, 0, HOOD_LEN - 0.05), DARK)
		B.on(f, seg, seg .. "SpotRing", "Part", v(0.04, 2.3, 2.3), CFrame.new(s * 0.33, 0.2, cz + 0.4), DARK).Shape = Enum.PartType.Cylinder
		local spot = B.on(f, seg, "HoodSpot" .. side, "Part", v(0.05, 1.5, 1.5), CFrame.new(s * 0.375, 0.2, cz + 0.4), VENOM)
		spot.Shape = Enum.PartType.Cylinder
		tellp(spot)
		attach(spot, "Hood" .. side .. "_FX", spot.Position + v(s * 0.1, 0, 0))
		B.joint("JointHood" .. side, "Neck4", seg, hinge)
	end
end

-- Head -----------------------------------------------------------------------------------------
-- hf: the head frame at the pivot, a touch nose-down. -Z forward, skull 5.4 long, 4.4 wide.
local hf = CFrame.new(NECK[6]) * CFrame.Angles(-0.06, 0, 0)
B.on(hf, "Skull", "Skull", "Part", v(4.4, 3.0, 2.8), CFrame.new(0, 0.1, -0.4), BACK)
B.on(hf, "Skull", "CranTop", "Part", v(3.0, 0.5, 2.4), CFrame.new(0, 1.7, -0.3), BACK_HI)
B.on(hf, "Skull", "Snout", "Part", v(3.0, 2.0, 2.8), CFrame.new(0, -0.25, -2.8), BACK)
B.on(hf, "Skull", "SnoutTip", "Part", v(2.6, 1.6, 0.6), CFrame.new(0, -0.35, -4.1), BACK)
B.on(hf, "Skull", "SnoutTop", "Part", v(2.2, 0.4, 2.6), CFrame.new(0, 0.95, -2.8), BACK_HI)
B.on(hf, "Skull", "Lip", "Part", v(3.04, 0.2, 2.8), CFrame.new(0, -1.2, -2.8), BELLY)
B.on(hf, "Skull", "LipTip", "Part", v(2.64, 0.2, 0.6), CFrame.new(0, -1.2, -4.1), BELLY)
B.on(hf, "Skull", "LipBack", "Part", v(4.44, 0.2, 2.8), CFrame.new(0, -1.4, -0.4), BELLY)
-- pearl on the brow ridge
tellp(B.ball("Skull", "BrowPearl", 0.8, (hf * CFrame.new(0, 1.75, -1.5)).Position, VEIN))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- the step between cranium and snout carries the brows and the eyes: they wrap its corner
	B.on(hf, "Skull", "Brow" .. side, "Part", v(1.5, 0.45, 1.4), CFrame.new(s * 1.55, 1.15, -1.3) * CFrame.Angles(0, 0, s * 0.2), DARK)
	tellp(B.on(hf, "Skull", "Eye" .. side, "Part", v(0.75, 0.55, 0.06), CFrame.new(s * 1.78, 0.45, -1.83), AMBER))
	tellp(B.on(hf, "Skull", "EyeSide" .. side, "Part", v(0.06, 0.55, 0.65), CFrame.new(s * 2.23, 0.45, -1.5), AMBER))
	B.on(hf, "Skull", "Nostril" .. side, "Part", v(0.4, 0.25, 0.06), CFrame.new(s * 0.8, 0.15, -4.43), DARK)
	-- horn nubs: a big swept-back horn off the crown, a stub in front of it
	B.limb("Skull", "Horn" .. side, (hf * CFrame.new(s * 1.35, 1.2, 0.2)).Position,
		(hf * CFrame.new(s * 1.85, 2.5, 1.7)).Position, 1.0, 1.0, HORN, 0.25)
	B.limb("Skull", "HornTip" .. side, (hf * CFrame.new(s * 1.8, 2.4, 1.5)).Position,
		(hf * CFrame.new(s * 2.1, 3.3, 2.7)).Position, 0.55, 0.55, HORN, 0.2)
	B.limb("Skull", "HornNub" .. side, (hf * CFrame.new(s * 1.2, 1.4, -0.7)).Position,
		(hf * CFrame.new(s * 1.4, 2.1, -0.2)).Position, 0.55, 0.55, HORN, 0.1)
	for i, z in { -3.7, -2.9, -2.1 } do
		B.fin("Skull", "Tooth" .. side .. i, v(s * 1.2, -1.3, z), 0.5, 0.35, 0.22, BONE, math.pi, 0, hf)
	end
end
B.joint("JointHead", "Neck5", "Skull", NECK[6])

-- Fangs: each hinged at the root on the palate, folded back (pointing +Z) at rest.
-- +X swings the tip down and forward (about +1.6 down, +2.6 forward-down).
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local root = hf * CFrame.new(s * 0.95, -1.5, -3.55)
	local fl, fw, ft = 2.1, 0.5, 0.5
	-- a wedge: tall at -Z (the root), tapering to a point at +Z; flipped 180 about Y
	local fang = B.add("Skull", "Fang" .. side, "WedgePart", v(fw, ft, fl), root * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, -fl / 2 + 0 ), BONE)
	-- venom-green tip over the last 40 percent
	local tl = fl * 0.42
	local tipH = ft * 0.42
	local tip = B.add("Skull", "FangTip" .. side, "WedgePart", v(fw + 0.04, tipH + 0.04, tl + 0.02),
		root * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, -ft / 2 + (tipH + 0.04) / 2 - 0.01, -(fl - tl / 2)), VENOM)
	tellp(tip)
	attach(tip, "Fang" .. side .. "_FX", (root * CFrame.new(0, 0, fl - 0.1)).Position)
	B.joint("JointFang" .. side, "Skull", "Fang" .. side, root.Position)
end
-- the fang parts belong to their own segments, not the Skull
for _, c in B.model:GetChildren() do
	if c.Name == "FangL" or c.Name == "FangR" then
		c:SetAttribute("Segment", nil)
	elseif c.Name == "FangTipL" then
		c:SetAttribute("Segment", "FangL")
	elseif c.Name == "FangTipR" then
		c:SetAttribute("Segment", "FangR")
	end
end

-- Jaw ---------------------------------------------------------------------------------------
B.on(hf, "Jaw", "Jaw", "Part", v(3.0, 0.7, 4.6), CFrame.new(0, -2.05, -1.9), BELLY)
B.on(hf, "Jaw", "JawBack", "Part", v(4.2, 0.9, 1.5), CFrame.new(0, -2.05, -0.1), BELLY)
B.on(hf, "Jaw", "JawMouth", "Part", v(2.6, 0.06, 3.9), CFrame.new(0, -1.69, -2.2), MOUTH)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	for i, z in { -3.6, -2.7 } do
		B.fin("Jaw", "LowerTooth" .. side .. i, v(s * 1.3, -1.68, z), 0.38, 0.28, 0.2, BONE, 0, 0, hf)
	end
end
B.joint("JointJaw", "Skull", "Jaw", (hf * CFrame.new(0, -1.6, 0.5)).Position)
attach(B.model.Skull, "Mouth", (hf * CFrame.new(0, -1.5, -4.0)).Position)

-- Tongue and its fork, in the mouth on the jaw's floor -------------------------------------
do
	local root = hf * CFrame.new(0, -1.62, -0.4)
	B.on(root, "Tongue", "Tongue", "Part", v(0.55, 0.12, 3.0), CFrame.new(0, 0, -1.5), TONGUE)
	B.joint("JointTongue", "Jaw", "Tongue", root.Position)
	local tipRoot = root * CFrame.new(0, 0, -3.0)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		B.on(tipRoot * CFrame.Angles(0, s * 0.4, 0), "TongueTip" .. side, "TongueTip" .. side, "Part",
			v(0.22, 0.1, 0.7), CFrame.new(0, 0, -0.35), TONGUE)
		B.joint("JointTongueTip" .. side, "Tongue", "TongueTip" .. side, tipRoot.Position)
	end
end

-- Throat: a swollen venom sac under the neck-head junction, with a cream plate in front ----
do
	local sacPos = (hf * CFrame.new(0, -2.0, 0.9)).Position
	local sac = B.ball("Neck5", "ThroatSac", 2.4, sacPos, VENOM)
	tellp(sac)
	attach(sac, "Throat", sacPos + v(0, -0.2, -1.0))
	B.on(CFrame.new(sacPos) * CFrame.Angles(0.25, 0, 0), "Neck5", "ThroatPlate", "Part", v(1.5, 1.6, 0.25), CFrame.new(0, -0.1, -1.05), BELLY)
end

-- Whiskers: two links per side, swept back off the snout; long phase-3 strands hidden ------
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local p0 = (hf * CFrame.new(s * 1.55, -0.3, -3.6)).Position
	local p1 = (hf * CFrame.new(s * 2.7, -0.5, -2.4)).Position
	local p2 = (hf * CFrame.new(s * 3.5, -0.9, -0.3)).Position
	local p3 = (hf * CFrame.new(s * 4.6, -1.5, 2.4)).Position
	B.limb("Barbel" .. side .. "1", "Barbel" .. side .. "1", p0, p1, 0.3, 0.3, JADE_HI, 0.12)
	B.limb("Barbel" .. side .. "2", "Barbel" .. side .. "2", p1, p2, 0.22, 0.22, JADE_HI, 0.12)
	hide(B.limb("Barbel" .. side .. "2", "P3Barbel" .. side, p2, p3, 0.16, 0.16, JADE_HI, 0.1), 3)
	B.joint("JointBarbel" .. side .. "1", "Skull", "Barbel" .. side .. "1", p0)
	B.joint("JointBarbel" .. side .. "2", "Barbel" .. side .. "1", "Barbel" .. side .. "2", p1)
end
-- the whisker parts are their own segments, not Skull details
for _, c in B.model:GetChildren() do
	if c.Name:match("^Barbel[LR][12]$") then
		c:SetAttribute("Segment", nil)
	elseif c.Name == "P3BarbelL" then
		c:SetAttribute("Segment", "BarbelL2")
	elseif c.Name == "P3BarbelR" then
		c:SetAttribute("Segment", "BarbelR2")
	end
end

-- Hooks on the body ----------------------------------------------------------------------------
do
	local body = B.model.Body
	attach(body, "Core", v(0, 2.6, -0.4))
	attach(body, "Dive_FX", v(0, 0, -1.5))
	attach(body, "Ground_Body", v(0, 0, 2.5))
	attach(B.model.Tail18, "TailTip_FX", TP[19] + v(0, 0, 0.5))
	for _, i in { 4, 9, 14 } do
		local mid = (TP[i] + TP[i + 1]) / 2
		attach(B.model["Tail" .. i], "Ground_Tail" .. i, v(0, 0, mid.Z))
	end
	for _, i in { 3, 6, 9, 12 } do
		local mid = (TP[i] + TP[i + 1]) / 2
		attach(B.model["Tail" .. i], "Coil_Tail" .. i, v(0, mid.Y - tailW[i] * 0.45, mid.Z))
	end
end

for _, p in B.model:GetChildren() do
	p.Size = p.Size * K
	p.CFrame = p.CFrame.Rotation + p.Position * K
	for _, a in p:GetChildren() do
		if a:IsA("Attachment") then
			a.Position = a.Position * K
		end
	end
end
B.model:SetAttribute("Scale", ROSTER_SCALE)
return B.finish()
