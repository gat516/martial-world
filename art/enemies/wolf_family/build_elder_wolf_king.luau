--!nocheck
-- Elder Wolf King (boss): the Spirit Wolf B body plan rebuilt as the Inner Wilds'
-- old pack lord, from Studio parts only. Run in Edit mode through execute_luau; it
-- rebuilds ServerStorage._RosterWolves.ElderWolfKing (body only), then run
-- art/enemies/wolf_family/rig_wolf_family.luau with TARGET = "ElderWolfKing".
--
-- Authored in the Spirit Wolf's unit space (ground Y=0, faces -Z, left is -X, the
-- same segment boxes and joint pivots as build_spirit_wolf_b.luau) and scaled
-- uniformly by SCALE about the ground origin as each part is made, so rig_wolf's
-- pivots times SCALE land on the right joints. Detail parts carry a `Segment`
-- attribute; tell parts (eyes, brow mark, collar jade and seal) also carry `Tell`.

local NAME = "ElderWolfKing"
local SCALE = 2.4 -- matches the old ElderWolfKing's HRP (4.8 x 4.8 x 10.56 at Y 6.24)
local STAGING = "_RosterWolves"

local SLATE = Color3.fromHex("252C3A") -- body
local SLATE_HI = Color3.fromHex("3A4659")
local SILVER = Color3.fromHex("E4E9EE") -- mane, crest, tail tip
local SILVER_SH = Color3.fromHex("A9B3BE") -- belly, lower legs, muzzle
local BONE = Color3.fromHex("F2EDE0") -- claws and teeth
local DARK = Color3.fromHex("15171C") -- nose and lips
local MOUTH = Color3.fromHex("5E2430")
local SCAR = Color3.fromHex("C9A3A0")
local IRON = Color3.fromHex("3B3F46") -- the collar
local JADE = Color3.fromHex("3E9C7E") -- collar inlay (not neon)
local TELL = Color3.fromHex("FFC85A") -- eyes and brow mark (neon, flare on windup)

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local model = Instance.new("Model")
model.Name = NAME

local function add(seg, name, class, size, cf, color)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size * SCALE
	p.CFrame = CFrame.new(cf.Position * SCALE) * cf.Rotation
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if name ~= seg then
		p:SetAttribute("Segment", seg)
	end
	p.Parent = model
	return p
end

local function tell(p)
	p.Material = Enum.Material.Neon
	p:SetAttribute("Tell", true)
	return p
end

local function block(seg, name, size, pos, color, rot)
	return add(seg, name, "Part", size, CFrame.new(pos) * (rot or CFrame.identity), color)
end

local function ball(seg, name, d, pos, color)
	local p = add(seg, name, "Part", Vector3.new(d, d, d), CFrame.new(pos), color)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A cylinder of diameter d and length len, its axis along `axis` ("X" or "Z").
local function disc(seg, name, d, len, pos, color, axis)
	local rot = if axis == "Z" then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
	local p = add(seg, name, "Part", Vector3.new(len, d, d), CFrame.new(pos) * rot, color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A block from a to b (Z along the bone), w wide and d deep, padded past both ends.
local function limb(seg, name, a, b, w, d, color, pad)
	local dir = (b - a).Unit
	local up = if math.abs(dir.Y) > 0.7 then Vector3.new(0, 0, -1) else Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	return add(seg, name, "Part", Vector3.new(w, d, (b - a).Magnitude + (pad or 0)), cf, color)
end

-- A wedge fin rising h from base: vertical face at the back, slope at the front, so the
-- tip sweeps back. pitch leans it back (+) or flips it down (~pi); roll + tilts it to -X.
local function fin(seg, name, base, h, depth, thick, color, pitch, roll)
	local cf = CFrame.new(base) * CFrame.Angles(pitch or 0, 0, roll or 0) * CFrame.new(0, h / 2, 0)
	return add(seg, name, "WedgePart", Vector3.new(thick, h, depth), cf, color)
end

-- An isosceles triangle (two wedges back to back) facing forward, h tall and w wide.
local function tri(seg, name, base, h, w, thick, color, tilt)
	local frame = CFrame.new(base) * (tilt or CFrame.identity)
	local a = add(seg, name, "WedgePart", Vector3.new(thick, h, w / 2),
		frame * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
	add(seg, name .. "B", "WedgePart", Vector3.new(thick, h, w / 2),
		frame * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
	return a
end

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

-- A sloped shoulder along Z: vertical face toward the midline, slope out to side s.
local function bevel(seg, name, pos, w, h, len, s, color)
	return add(seg, name, "WedgePart", v(len, h, w), CFrame.new(pos) * CFrame.Angles(0, -s * math.pi / 2, 0), color)
end

-- Hips --------------------------------------------------------------------------------
-- Lower than the chest, so the back slopes down from a humped, maned shoulder.

block("Hips", "Hips", v(2.0, 1.1, 1.8), v(0, 2.55, 1.9), SLATE)
block("Hips", "HipsTop", v(1.1, 0.6, 1.8), v(0, 3.4, 1.9), SLATE)
block("Hips", "HipsBelly", v(2.06, 0.5, 1.3), v(0, 2.25, 1.7), SILVER_SH)
fin("Hips", "HipsCrest1", v(0, 3.6, 1.3), 0.75, 0.8, 0.5, SILVER, 0.8)
fin("Hips", "HipsCrest2", v(0, 3.6, 2.05), 0.55, 0.7, 0.45, SILVER_SH, 0.9)
for _, s in { -1, 1 } do
	bevel("Hips", "HipsShoulder" .. s, v(s * 0.775, 3.4, 1.9), 0.45, 0.6, 1.8, s, SLATE)
end

-- Chest: heavier and higher than the Spirit Wolf's, a hump of shoulder ----------------

block("Chest", "Chest", v(2.6, 1.4, 2.8), v(0, 2.6, -0.5), SLATE)
block("Chest", "ChestTop", v(1.5, 0.95, 2.8), v(0, 3.65, -0.5), SLATE)
block("Chest", "ChestBelly", v(2.66, 0.55, 2.3), v(0, 2.12, -0.45), SILVER_SH)
block("Chest", "ChestBib", v(2.0, 1.5, 0.6), v(0, 2.45, -1.75), SILVER_SH)
-- the crest: six silver blades from the withers back to the hips, the tallest first
for i, c in {
	{ -1.35, 1.35, 1.0, 0.55 }, { -0.75, 1.45, 1.0, 0.62 }, { -0.1, 1.3, 0.95, 0.7 },
	{ 0.5, 1.05, 0.9, 0.78 }, { 1.0, 0.8, 0.8, 0.85 },
} do
	fin("Chest", "Crest" .. i, v(0, 4.05, c[1]), c[2], c[3], 0.6, if i % 2 == 0 then SILVER_SH else SILVER, c[4])
end
for _, s in { -1, 1 } do
	bevel("Chest", "ChestShoulder" .. s, v(s * 1.05, 3.65, -0.5), 0.6, 0.95, 2.8, s, SLATE)
	-- two side rows of crest spikes flaring out over the shoulders
	fin("Chest", "CrestSide" .. s, v(s * 0.65, 3.95, -1.15), 0.95, 0.85, 0.45, SILVER, 0.6, -s * 0.55)
	fin("Chest", "CrestSideB" .. s, v(s * 0.65, 3.9, -0.35), 0.8, 0.8, 0.4, SILVER_SH, 0.7, -s * 0.6)
	fin("Chest", "CrestSideC" .. s, v(s * 0.6, 3.85, 0.4), 0.6, 0.75, 0.4, SILVER, 0.8, -s * 0.65)
	-- jagged slate/silver line along the flank
	for i, z in { -1.2, -0.35, 0.5 } do
		fin("Chest", "Flank" .. s .. i, v(s * 1.28, 2.5, z), 0.6, 0.7, 0.25, SLATE, 2.75, -s * 0.15)
	end
end

-- Neck, mane and collar ------------------------------------------------------------------

block("Neck", "Neck", v(1.4, 1.35, 1.3), v(0, 3.05, -2.35), SLATE)
block("Neck", "NeckBib", v(1.2, 0.9, 1.0), v(0, 2.55, -2.45), SILVER_SH)
-- the silver mane: a collar block under rows of blades swept back, fanning from up-and-back
-- over the withers to down-and-back over the chest, so it reads as a lion's ruff side-on
block("Neck", "Ruff", v(2.0, 1.7, 0.9), v(0, 3.2, -1.95), SILVER_SH)
fin("Neck", "RuffTop", v(0, 4.0, -2.15), 1.05, 0.9, 0.7, SILVER, 0.75)
for _, s in { -1, 1 } do
	for i, row in { { 3.85, 0.95, 1.05 }, { 3.35, 1.3, 1.1 }, { 2.85, 1.65, 1.0 }, { 2.45, 1.85, 0.6 } } do
		fin("Neck", "Mane" .. s .. i, v(s * 0.95, row[1], -2.15), row[3], 0.9, 0.35,
			if i % 2 == 0 then SILVER_SH else SILVER, row[2], -s * 0.6)
	end
	fin("Neck", "BibTuft" .. s, v(s * 0.4, 2.1, -2.6), 0.5, 0.45, 0.3, SILVER, math.pi - 0.4, s * 0.3)
end
-- iron collar in front of the mane, with jade inlays and a hanging jade seal
block("Neck", "CollarTop", v(1.7, 0.28, 0.4), v(0, 3.82, -2.6), IRON)
block("Neck", "CollarBottom", v(1.7, 0.28, 0.4), v(0, 2.28, -2.6), IRON)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	block("Neck", "CollarSide" .. side, v(0.28, 1.82, 0.4), v(s * 0.85, 3.05, -2.6), IRON)
	tell(disc("Neck", "CollarJade" .. side, 0.42, 0.12, v(s * 1.02, 3.05, -2.6), JADE, "X"))
end
disc("Neck", "SealRing", 0.62, 0.12, v(0, 1.95, -2.7), IRON, "Z")
tell(disc("Neck", "Seal", 0.42, 0.16, v(0, 1.95, -2.7), JADE, "Z"))

-- Head: scarred muzzle, swept head crest, a brow mark ------------------------------------

block("Skull", "Skull", v(1.75, 1.45, 1.4), v(0, 3.2, -3.4), SLATE)
block("Skull", "Snout", v(1.0, 0.7, 1.3), v(0, 2.95, -4.45), SILVER_SH)
add("Skull", "SnoutTop", "WedgePart", v(0.84, 0.3, 0.95), CFrame.new(0, 3.45, -4.4), SLATE_HI)
block("Skull", "Nose", v(0.4, 0.26, 0.3), v(0, 3.16, -5.1), DARK)
block("Skull", "Lip", v(1.02, 0.08, 1.2), v(0, 2.62, -4.45), DARK)
block("Skull", "Cheeks", v(1.95, 0.65, 0.95), v(0, 2.8, -3.5), SILVER)
tell(block("Skull", "MarkBrow", v(0.22, 0.22, 0.05), v(0, 3.7, -4.11), TELL, CFrame.Angles(0, 0, math.pi / 4)))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	fin("Skull", "CheekTuft" .. side, v(s * 0.9, 2.85, -3.2), 0.55, 0.5, 0.28, SILVER, 1.45, -s * 0.45)
	-- head crest: two blades swept back over the skull, between the ears
	fin("Skull", "HeadCrest" .. side, v(s * 0.25, 3.85, -3.55), 0.95, 0.7, 0.3, SILVER, 1.15, -s * 0.15)
	block("Skull", "Brow" .. side, v(0.55, 0.17, 0.34), v(s * 0.6, 3.58, -4.04), SLATE_HI, CFrame.Angles(0, 0, s * 0.26))
	-- the eyes wrap the skull corner, so they glow side-on as well as from the front
	tell(block("Skull", "Eye" .. side, v(0.3, 0.16, 0.3), v(s * 0.75, 3.4, -4.0), TELL, CFrame.Angles(0, 0, s * 0.26)))
	fin("Skull", "Fang" .. side, v(s * 0.42, 2.62, -4.95), 0.38, 0.17, 0.13, BONE, math.pi)
	fin("Skull", "Tooth" .. side, v(s * 0.42, 2.62, -4.5), 0.16, 0.15, 0.1, BONE, math.pi)
end
-- three claw scars across the left of the muzzle, and one through the left eye
for i = 1, 3 do
	block("Skull", "ScarMuzzle" .. i, v(0.04, 0.55, 0.07), v(-0.505, 2.98, -4.1 - i * 0.22), SCAR, CFrame.Angles(-0.55, 0, 0))
end
block("Skull", "ScarEyeTop", v(0.07, 0.3, 0.04), v(-0.7, 3.72, -4.22), SCAR, CFrame.Angles(0, 0, -0.3))
block("Skull", "ScarEyeLow", v(0.07, 0.35, 0.04), v(-0.56, 3.14, -4.11), SCAR, CFrame.Angles(0, 0, -0.3))

block("Jaw", "Jaw", v(0.9, 0.34, 1.3), v(0, 2.5, -4.2), SILVER_SH)
block("Jaw", "JawMouth", v(0.72, 0.15, 1.15), v(0, 2.66, -4.2), MOUTH)
block("Jaw", "Chin", v(1.05, 0.4, 0.6), v(0, 2.55, -3.5), SILVER)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	fin("Jaw", "LowerFang" .. side, v(s * 0.33, 2.64, -4.7), 0.26, 0.13, 0.11, BONE)
end

for _, s in { -1, 1 } do
	local ear = if s < 0 then "EarL" else "EarR"
	local tilt = CFrame.Angles(0.3, 0, -s * 0.3)
	tri(ear, ear, v(s * 0.55, 3.8, -3.1), 0.9, 0.52, 0.22, SLATE, tilt)
	tri(ear, ear .. "Inner", v(s * 0.55, 3.84, -3.22), 0.52, 0.28, 0.05, MOUTH, tilt)
end

-- Legs: thick forelegs with a heavy shoulder ball standing out of the chest --------------

local function claws(seg, x, z)
	for i, dx in { -0.22, 0, 0.22 } do
		add(seg, seg .. "Claw" .. i, "WedgePart", v(0.11, 0.2, 0.32), CFrame.new(x + dx, 0.1, z), BONE)
	end
end

for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local x = s * 0.72
	block("UpperLeg" .. f, "UpperLeg" .. f, v(0.85, 1.35, 0.9), v(x, 1.9, -1.3), SLATE)
	-- a heavy shoulder pad standing proud of the chest, swinging with the leg
	block("UpperLeg" .. f, "Shoulder" .. f, v(0.45, 1.1, 1.15), v(s * 1.3, 2.45, -1.3), SLATE_HI)
	fin("UpperLeg" .. f, "ShoulderTuft" .. f, v(s * 1.4, 2.3, -1.0), 0.6, 0.6, 0.3, SLATE, 2.3, -s * 0.2)
	fin("UpperLeg" .. f, "ElbowTuft" .. f, v(s * 0.8, 1.5, -0.9), 0.55, 0.45, 0.45, SILVER_SH, 2.2)
	block("LowerLeg" .. f, "LowerLeg" .. f, v(0.65, 1.1, 0.7), v(x, 0.8, -1.3), SILVER_SH)
	ball("LowerLeg" .. f, "Elbow" .. f, 0.75, v(x, 1.35, -1.25), SILVER_SH)
	block("Paw" .. f, "Paw" .. f, v(0.75, 0.32, 0.95), v(x, 0.16, -1.62), SILVER_SH)
	ball("Paw" .. f, "Wrist" .. f, 0.62, v(x, 0.34, -1.35), SILVER_SH)
	claws("Paw" .. f, x, -2.18)

	local b = if s < 0 then "BL" else "BR"
	x = s * 0.75
	local knee, hock, ankle = v(x, 1.35, 1.8), v(x, 0.62, 2.3), v(x, 0.25, 2.2)
	block("UpperLeg" .. b, "UpperLeg" .. b, v(0.95, 1.45, 1.05), v(x, 1.95, 2.0), SLATE)
	fin("UpperLeg" .. b, "ThighTuft" .. b, v(s * 0.85, 1.5, 2.45), 0.5, 0.5, 0.45, SLATE_HI, 2.3)
	limb("LowerLeg" .. b, "LowerLeg" .. b, knee, hock, 0.58, 0.62, SILVER_SH, 0.25)
	ball("LowerLeg" .. b, "Knee" .. b, 0.7, knee, SLATE)
	limb("Paw" .. b, "Paw" .. b, hock, ankle, 0.55, 0.58, SILVER_SH, 0.15)
	ball("Paw" .. b, "Hock" .. b, 0.58, hock, SILVER_SH)
	fin("Paw" .. b, "HockTuft" .. b, v(x, 0.75, 2.52), 0.4, 0.35, 0.3, SILVER, 2.2)
	block("Paw" .. b, "Foot" .. b, v(0.68, 0.32, 0.85), v(x, 0.16, 1.95), SILVER_SH)
	claws("Paw" .. b, x, 1.48)
end

-- Tail: slate root, a big silver brush ----------------------------------------------------

block("TailBase", "TailBase", v(0.75, 0.75, 1.1), v(0, 3.25, 3.25), SLATE)
fin("TailBase", "TailBaseFin", v(0, 3.5, 3.0), 0.5, 0.65, 0.45, SILVER_SH, 0.9)
block("TailMid", "TailMid", v(0.9, 0.9, 1.2), v(0, 3.3, 4.3), SLATE)
block("TailMid", "TailMidUnder", v(0.7, 0.4, 1.1), v(0, 2.95, 4.3), SILVER_SH)
fin("TailMid", "TailMidFin", v(0, 3.65, 4.1), 0.55, 0.65, 0.5, SILVER, 1.0)
for _, s in { -1, 1 } do
	fin("TailMid", "TailMidSide" .. s, v(s * 0.4, 3.5, 4.45), 0.5, 0.6, 0.35, SILVER_SH, 1.0, -s * 0.6)
end
local tipA, tipB = v(0, 3.35, 4.85), v(0, 4.3, 5.7)
limb("TailTip", "TailTip", tipA, tipB, 0.75, 0.75, SILVER, 0.25)
fin("TailTip", "TailTipFin", v(0, 4.2, 5.6), 0.65, 0.7, 0.5, SILVER, 0.3)
for _, s in { -1, 1 } do
	fin("TailTip", "TailTipSide" .. s, v(s * 0.25, 4.05, 5.5), 0.6, 0.6, 0.35, SILVER, 0.4, -s * 0.65)
end

-- Place ----------------------------------------------------------------------------------

local recording = ChangeHistoryService:TryBeginRecording("Build " .. NAME)
local staging = ServerStorage:FindFirstChild(STAGING)
if not staging then
	staging = Instance.new("Folder")
	staging.Name = STAGING
	staging.Parent = ServerStorage
end
local old = staging:FindFirstChild(NAME)
if old then
	old:Destroy()
end
model.Parent = staging
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return ("%s body: %d parts"):format(NAME, #model:GetChildren())
