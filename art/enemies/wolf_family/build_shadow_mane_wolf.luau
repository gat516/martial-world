--!nocheck
-- Shadow-Mane Wolf: a Ruined Borderlands (Middle Wilds) wolf on the Spirit Wolf rig, from
-- Studio parts only. Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterWolves.ShadowManeWolf (body only), then run
-- art/enemies/wolf_family/rig_wolf_family.luau with TARGET = "ShadowManeWolf".
--
-- Authored in the Spirit Wolf's unit space (ground Y=0, faces -Z, left is -X, the
-- same segment centres and joint pivots as build_spirit_wolf_b.luau) and scaled
-- uniformly by SCALE as each part is made. It reads as its own beast, not a recolour:
-- near-black and lean, no dorsal crest of spikes but a long violet mane swept back from
-- the head over the shoulders, sabre fangs past the jaw, tall narrow ears, a bare
-- ridged back, a thin tail ending in a violet brush.
-- Detail parts carry a `Segment` attribute; tell parts (the eyes) also carry `Tell`.

local NAME = "ShadowManeWolf"
local SCALE = 1.15
local STAGING = "_RosterWolves"

local INK = Color3.fromHex("17161D") -- body
local INK_HI = Color3.fromHex("27242F")
local BELLY = Color3.fromHex("3B3647") -- underside, lower legs
local MANE = Color3.fromHex("5A3A8E") -- violet ink mane
local MANE_HI = Color3.fromHex("8257C2")
local BONE = Color3.fromHex("EDE6D6") -- fangs and claws
local DARK = Color3.fromHex("08080B") -- nose and lips
local MOUTH = Color3.fromHex("4A1E33")
local TELL = Color3.fromHex("A04BFF") -- the eyes (neon, flare on windup)

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

-- Hips: narrow, a bare back with low ridges -----------------

-- the hip blocks run 0.1 into the chest, so no slit of sky opens at the waist
block("Hips", "Hips", v(1.6, 1.1, 2.3), v(0, 2.55, 1.9), INK)
block("Hips", "HipsTop", v(0.85, 0.5, 2.3), v(0, 3.3, 1.9), INK_HI)
block("Hips", "HipsBelly", v(1.66, 0.4, 1.7), v(0, 2.2, 1.5), BELLY)
fin("Hips", "SpineRidge", v(0, 3.5, 1.6), 0.3, 0.5, 0.3, INK_HI, 1.0)
for _, s in { -1, 1 } do
	bevel("Hips", "HipsShoulder" .. s, v(s * 0.61, 3.3, 1.9), 0.38, 0.5, 2.3, s, INK)
end

-- Chest: lean, a deep narrow keel; the mane lies back over the withers -----------------

block("Chest", "Chest", v(1.85, 1.25, 2.7), v(0, 2.6, -0.5), INK)
block("Chest", "ChestTop", v(1.0, 0.6, 2.7), v(0, 3.5, -0.5), INK_HI)
block("Chest", "ChestBelly", v(1.9, 0.45, 2.1), v(0, 2.12, -0.5), BELLY)
block("Chest", "ChestBib", v(1.3, 1.2, 0.5), v(0, 2.5, -1.7), BELLY)
fin("Chest", "SpineRidgeChest", v(0, 3.78, 0.35), 0.3, 0.5, 0.3, INK_HI, 1.0)
-- the dorsal mane and its shoulder drapes are one segment (JointMane), primary part "Mane"
for i, c in { { -1.45, 1.15 }, { -0.9, 1.0 }, { -0.35, 0.75 } } do
	fin("Mane", if i == 2 then "Mane" else "Mane" .. i, v(0, 3.75, c[1]), c[2], 0.7, 0.35, if i == 2 then MANE_HI else MANE, 1.15)
end
for _, s in { -1, 1 } do
	bevel("Chest", "ChestShoulder" .. s, v(s * 0.71, 3.5, -0.5), 0.42, 0.6, 2.7, s, INK)
	-- strands draping back and down over each shoulder
	fin("Mane", "ManeDrape" .. s, v(s * 0.6, 3.65, -1.35), 1.05, 0.6, 0.25, MANE, 1.3, -s * 1.0)
	fin("Mane", "ManeDrapeB" .. s, v(s * 0.75, 3.3, -1.1), 0.85, 0.55, 0.22, MANE_HI, 1.45, -s * 1.45)
end

-- Neck: a mane collar and a ring of long strands swept back -----------------------------

block("Neck", "Neck", v(1.15, 1.2, 1.3), v(0, 3.05, -2.35), INK)
block("Neck", "NeckBib", v(0.95, 0.8, 0.9), v(0, 2.55, -2.45), BELLY)
block("Neck", "Ruff", v(1.9, 1.4, 0.8), v(0, 3.2, -1.95), MANE)
fin("Neck", "RuffTop", v(0, 3.85, -2.15), 1.3, 0.7, 0.4, MANE_HI, 1.05)
-- each side's strands are one segment (JointManeL/R), primary part = the second strand
for _, s in { -1, 1 } do
	local mane = if s < 0 then "ManeL" else "ManeR"
	for i, a in { 0.45, 1.05, 1.65, 2.25 } do
		fin(mane, if i == 2 then mane else mane .. "Strand" .. i, v(s * 0.85 * math.sin(a), 3.2 + 0.7 * math.cos(a), -2.05), 1.25 - i * 0.12, 0.6, 0.26,
			if i % 2 == 0 then MANE_HI else MANE, 1.0, -s * a)
	end
end

-- Head: long dark muzzle, sabre fangs, slanted violet eyes ------------------

block("Skull", "Skull", v(1.3, 1.15, 1.25), v(0, 3.15, -3.35), INK)
-- the muzzle a step lighter than the skull, so the face keeps its shape from the front
block("Skull", "Snout", v(0.78, 0.55, 1.45), v(0, 2.95, -4.4), BELLY)
add("Skull", "SnoutTop", "WedgePart", v(0.62, 0.28, 1.1), CFrame.new(0, 3.36, -4.35), INK)
block("Skull", "Nose", v(0.38, 0.28, 0.26), v(0, 3.08, -5.1), DARK)
block("Skull", "Lip", v(0.8, 0.08, 1.35), v(0, 2.68, -4.4), DARK)
block("Skull", "Cheeks", v(1.4, 0.5, 0.85), v(0, 2.8, -3.45), INK_HI)
fin("Forelock", "Forelock", v(0, 3.72, -3.1), 0.95, 0.6, 0.35, MANE, 1.2) -- its own joint, JointForelock
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	fin("Skull", "CheekTuft" .. side, v(s * 0.66, 2.85, -3.1), 0.6, 0.45, 0.22, MANE, 1.35, -s * 0.9)
	block("Skull", "Brow" .. side, v(0.42, 0.14, 0.3), v(s * 0.36, 3.44, -3.88), INK_HI, CFrame.Angles(0, 0, s * 0.35))
	tell(block("Skull", "Eye" .. side, v(0.3, 0.12, 0.26), v(s * 0.52, 3.3, -3.88), TELL, CFrame.Angles(0, 0, s * 0.35)))
	-- sabre fangs reach past the lower jaw
	fin("Skull", "Fang" .. side, v(s * 0.33, 2.66, -4.88), 0.55, 0.16, 0.12, BONE, math.pi)
end

block("Jaw", "Jaw", v(0.7, 0.28, 1.35), v(0, 2.55, -4.15), INK_HI)
block("Jaw", "JawMouth", v(0.56, 0.14, 1.2), v(0, 2.69, -4.15), MOUTH)
block("Jaw", "Chin", v(0.82, 0.32, 0.6), v(0, 2.6, -3.5), INK)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	fin("Jaw", "LowerFang" .. side, v(s * 0.26, 2.68, -4.7), 0.24, 0.12, 0.1, BONE)
end

for _, s in { -1, 1 } do
	local ear = if s < 0 then "EarL" else "EarR"
	local tilt = CFrame.Angles(0.35, 0, -s * 0.16)
	tri(ear, ear, v(s * 0.45, 3.66, -3.1), 1.05, 0.42, 0.2, INK, tilt)
	tri(ear, ear .. "Inner", v(s * 0.45, 3.7, -3.2), 0.65, 0.22, 0.05, MANE, tilt)
end

-- Legs: thin and long-looking ---------------

local function claws(seg, x, z)
	for i, dx in { -0.12, 0.12 } do
		add(seg, seg .. "Claw" .. i, "WedgePart", v(0.1, 0.17, 0.3), CFrame.new(x + dx, 0.085, z), BONE)
	end
end

for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local x = s * 0.68
	block("UpperLeg" .. f, "UpperLeg" .. f, v(0.6, 1.3, 0.7), v(x, 1.9, -1.3), INK)
	ball("UpperLeg" .. f, "Shoulder" .. f, 0.64, v(s * 0.62, 2.45, -1.3), INK)
	block("LowerLeg" .. f, "LowerLeg" .. f, v(0.38, 1.1, 0.42), v(x, 0.8, -1.3), BELLY)
	ball("LowerLeg" .. f, "Elbow" .. f, 0.46, v(x, 1.35, -1.25), BELLY)
	block("Paw" .. f, "Paw" .. f, v(0.55, 0.26, 0.8), v(x, 0.13, -1.58), BELLY)
	ball("Paw" .. f, "Wrist" .. f, 0.38, v(x, 0.3, -1.35), BELLY)
	claws("Paw" .. f, x, -2.05)

	local b = if s < 0 then "BL" else "BR"
	x = s * 0.72
	local knee, hock, ankle = v(x, 1.35, 1.8), v(x, 0.62, 2.3), v(x, 0.25, 2.2)
	-- the thigh block stops at the hip pivot under a rounded haunch (a cylinder on the
	-- pivot axis), so a swinging leg never flashes its block corners out of the hip side
	block("UpperLeg" .. b, "UpperLeg" .. b, v(0.75, 1.25, 0.95), v(x, 1.875, 2.1), INK)
	disc("UpperLeg" .. b, "Haunch" .. b, 1.0, 0.75, v(x, 2.5, 2.1), INK, "X")
	limb("LowerLeg" .. b, "LowerLeg" .. b, knee, hock, 0.38, 0.42, BELLY, 0.25)
	ball("LowerLeg" .. b, "Knee" .. b, 0.52, knee, INK)
	limb("Paw" .. b, "Paw" .. b, hock, ankle, 0.36, 0.38, BELLY, 0.15)
	ball("Paw" .. b, "Hock" .. b, 0.38, hock, BELLY)
	block("Paw" .. b, "Foot" .. b, v(0.52, 0.26, 0.75), v(x, 0.13, 1.95), BELLY)
	claws("Paw" .. b, x, 1.52)
end

-- Tail: thin and dark, ending in a violet brush -------------------------------------------

block("TailBase", "TailBase", v(0.5, 0.5, 1.1), v(0, 3.25, 3.25), INK)
block("TailMid", "TailMid", v(0.55, 0.55, 1.2), v(0, 3.3, 4.3), INK)
local tipA, tipB = v(0, 3.35, 4.85), v(0, 4.05, 5.5)
limb("TailTip", "TailTip", tipA, tipB, 0.45, 0.45, INK, 0.2)
fin("TailTip", "Brush", v(0, 3.95, 5.4), 0.85, 0.6, 0.4, MANE, 0.3)
fin("TailTip", "BrushUnder", v(0, 3.9, 5.45), 0.7, 0.55, 0.35, MANE_HI, 2.4)
for _, s in { -1, 1 } do
	fin("TailTip", "BrushSide" .. s, v(s * 0.12, 3.92, 5.35), 0.7, 0.5, 0.25, MANE_HI, 0.7, -s * 0.8)
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
