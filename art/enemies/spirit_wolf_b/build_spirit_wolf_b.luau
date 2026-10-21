--!nocheck
-- Spirit Wolf, variant B: the body built only from Studio parts, to compare against
-- the Blender variant A (art/enemies/spirit_wolf/). Run in Edit mode through
-- execute_luau; it rebuilds ServerStorage._StagingEnemies.SpiritWolf_B (body only),
-- then run art/enemies/spirit_wolf/rig_wolf.luau on it for the shared rig.
--
-- Model space: ground Y=0, the wolf faces -Z, its left side is -X. Each segment's
-- primary part carries the segment name and fills the spec box from the design
-- sheet; detail parts carry a `Segment` attribute for rig_wolf to weld them by.

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SLATE = Color3.fromHex("2F3B50")
local SLATE_HI = Color3.fromHex("46566E")
local CREAM = Color3.fromHex("C8C1B0")
local CREAM_SH = Color3.fromHex("9E978A")
local BONE = Color3.fromHex("EEE9DC") -- claws and teeth
local DARK = Color3.fromHex("1B1E25") -- nose and lips
local MOUTH = Color3.fromHex("6B2A33") -- mouth and ear inside
local EYE = Color3.fromHex("FF2B2B")

local model = Instance.new("Model")
model.Name = "SpiritWolf_B"

local function add(seg, name, class, size, cf, color)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cf
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

-- A sloped shoulder along Z: a wedge whose vertical face is toward the midline and
-- whose slope faces out to side s, w wide, h tall and len long, centred at pos.
local function bevel(seg, name, pos, w, h, len, s, color)
	return add(seg, name, "WedgePart", v(len, h, w), CFrame.new(pos) * CFrame.Angles(0, -s * math.pi / 2, 0), color)
end

-- Hips and chest ----------------------------------------------------------------------
-- Each torso box is a lower block, a narrower top block and sloped shoulders, so the
-- back reads round rather than as a crate; cream plates cover the lower flanks.

-- the hip blocks run 0.1 into the chest, so no slit of sky opens at the waist
block("Hips", "Hips", v(1.9, 1.1, 2.2), v(0, 2.55, 1.9), SLATE)
block("Hips", "HipsTop", v(1.0, 0.6, 2.2), v(0, 3.4, 1.9), SLATE)
block("Hips", "HipsBelly", v(1.96, 0.5, 1.7), v(0, 2.25, 1.55), CREAM)
fin("Hips", "HipsCrest1", v(0, 3.6, 1.35), 0.6, 0.75, 0.5, SLATE_HI, 0.8)

block("Chest", "Chest", v(2.2, 1.3, 2.8), v(0, 2.55, -0.5), SLATE)
block("Chest", "ChestTop", v(1.2, 0.7, 2.8), v(0, 3.55, -0.5), SLATE)
block("Chest", "ChestBelly", v(2.26, 0.55, 2.3), v(0, 2.15, -0.45), CREAM)
block("Chest", "ChestBib", v(1.7, 1.4, 0.6), v(0, 2.45, -1.75), CREAM)
-- the crest: the tallest spikes peak above the shoulders and sweep back to the hips
-- the crest is its own segment (JointCrest), so an animator can bristle it on a windup
fin("Crest", "Crest1", v(0, 3.85, -1.3), 0.85, 0.95, 0.6, SLATE, 0.65)
fin("Crest", "Crest", v(0, 3.85, -0.6), 0.8, 0.9, 0.55, SLATE_HI, 0.7)
fin("Crest", "Crest3", v(0, 3.85, 0.1), 0.7, 0.85, 0.5, SLATE, 0.75)
fin("Crest", "Crest4", v(0, 3.8, 0.75), 0.55, 0.8, 0.45, SLATE_HI, 0.8)
for _, s in { -1, 1 } do
	bevel("Chest", "ChestShoulder" .. s, v(s * 0.85, 3.55, -0.5), 0.5, 0.7, 2.8, s, SLATE)
	bevel("Hips", "HipsShoulder" .. s, v(s * 0.725, 3.4, 1.9), 0.45, 0.6, 2.2, s, SLATE)
	fin("Crest", "CrestSide" .. s, v(s * 0.5, 3.75, -1.1), 0.6, 0.8, 0.45, SLATE_HI, 0.6, -s * 0.5)
	-- the jagged slate/cream line along the flank: tufts hanging down and back
	for i, z in { -1.25, -0.25, 0.75 } do
		fin("Chest", "Flank" .. s .. i, v(s * 1.08, 2.55, z), 0.55, 0.6, 0.25, SLATE, 2.75, -s * 0.15)
	end
end

-- Neck, ruff and head -----------------------------------------------------------------

block("Neck", "Neck", v(1.3, 1.3, 1.3), v(0, 3.05, -2.35), SLATE)
block("Neck", "NeckBib", v(1.1, 0.9, 1.0), v(0, 2.55, -2.45), CREAM)
-- the ruff collar covers the chest/neck and neck/skull seams
block("Neck", "Ruff", v(2.4, 1.6, 0.9), v(0, 3.1, -1.95), SLATE)
fin("Neck", "RuffTop", v(0, 3.85, -2.05), 0.55, 0.8, 0.6, SLATE_HI, 0.6)
for _, s in { -1, 1 } do
	fin("Neck", "RuffSide" .. s, v(s * 1.1, 3.25, -1.95), 0.55, 0.7, 0.35, SLATE, 0.4, -s * 1.2)
	fin("Neck", "RuffLow" .. s, v(s * 1.0, 2.55, -2.0), 0.5, 0.6, 0.35, SLATE, 0.5, -s * 2.2)
	fin("Neck", "BibTuft" .. s, v(s * 0.35, 2.15, -2.6), 0.4, 0.4, 0.3, CREAM, math.pi - 0.4, s * 0.3)
end

block("Skull", "Skull", v(1.45, 1.25, 1.3), v(0, 3.15, -3.35), SLATE)
block("Skull", "Snout", v(0.85, 0.6, 1.2), v(0, 2.95, -4.3), CREAM)
add("Skull", "SnoutTop", "WedgePart", v(0.7, 0.3, 0.9), CFrame.new(0, 3.4, -4.25), SLATE_HI)
block("Skull", "Nose", v(0.42, 0.3, 0.28), v(0, 3.1, -4.86), DARK)
block("Skull", "Lip", v(0.87, 0.08, 1.1), v(0, 2.66, -4.3), DARK)
block("Skull", "Cheeks", v(1.6, 0.55, 0.9), v(0, 2.8, -3.45), CREAM)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- cheek fur flaring back and out
	fin("Skull", "CheekTuft" .. side, v(s * 0.75, 2.8, -3.1), 0.6, 0.5, 0.3, CREAM, 1.25, -s * 0.75)
	-- scowl: brow and eye slant with the inner corner down
	block("Skull", "Brow" .. side, v(0.45, 0.15, 0.3), v(s * 0.38, 3.45, -3.95), SLATE, CFrame.Angles(0, 0, s * 0.26))
	local eye = block("Skull", "Eye" .. side, v(0.3, 0.14, 0.08), v(s * 0.38, 3.3, -4.03), EYE, CFrame.Angles(0, 0, s * 0.26))
	eye.Material = Enum.Material.Neon
	-- upper fang and teeth, pointing down
	fin("Skull", "Fang" .. side, v(s * 0.36, 2.66, -4.75), 0.26, 0.15, 0.12, BONE, math.pi)
	fin("Skull", "Tooth" .. side, v(s * 0.36, 2.66, -4.3), 0.14, 0.14, 0.1, BONE, math.pi)
end

block("Jaw", "Jaw", v(0.75, 0.3, 1.15), v(0, 2.55, -4.05), CREAM)
block("Jaw", "JawMouth", v(0.6, 0.15, 1.0), v(0, 2.7, -4.05), MOUTH)
block("Jaw", "Chin", v(0.9, 0.35, 0.6), v(0, 2.6, -3.45), CREAM_SH)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	fin("Jaw", "LowerFang" .. side, v(s * 0.27, 2.68, -4.5), 0.2, 0.12, 0.1, BONE)
end

for _, s in { -1, 1 } do
	local ear = if s < 0 then "EarL" else "EarR"
	local tilt = CFrame.Angles(0.15, 0, -s * 0.26)
	tri(ear, ear, v(s * 0.5, 3.66, -3.1), 0.8, 0.5, 0.22, SLATE, tilt)
	tri(ear, ear .. "Inner", v(s * 0.5, 3.7, -3.22), 0.5, 0.28, 0.05, MOUTH, tilt)
end

-- Legs ---------------------------------------------------------------------------------

local function claws(seg, x, z)
	for i, dx in { -0.2, 0, 0.2 } do
		add(seg, seg .. "Claw" .. i, "WedgePart", v(0.1, 0.18, 0.28), CFrame.new(x + dx, 0.09, z), BONE)
	end
end

for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local x = s * 0.72
	block("UpperLeg" .. f, "UpperLeg" .. f, v(0.7, 1.3, 0.8), v(x, 1.9, -1.3), SLATE)
	ball("UpperLeg" .. f, "Shoulder" .. f, 0.8, v(s * 0.7, 2.45, -1.3), SLATE)
	fin("UpperLeg" .. f, "ElbowTuft" .. f, v(s * 0.74, 1.5, -0.95), 0.45, 0.4, 0.4, SLATE, 2.2)
	block("LowerLeg" .. f, "LowerLeg" .. f, v(0.45, 1.1, 0.5), v(x, 0.8, -1.3), CREAM)
	ball("LowerLeg" .. f, "Elbow" .. f, 0.55, v(x, 1.35, -1.25), CREAM)
	block("Paw" .. f, "Paw" .. f, v(0.65, 0.3, 0.85), v(x, 0.15, -1.6), CREAM)
	ball("Paw" .. f, "Wrist" .. f, 0.45, v(x, 0.32, -1.35), CREAM)
	claws("Paw" .. f, x, -2.1)

	local b = if s < 0 then "BL" else "BR"
	x = s * 0.75
	local knee, hock, ankle = v(x, 1.35, 1.8), v(x, 0.62, 2.3), v(x, 0.25, 2.2)
	-- the thigh block stops at the hip pivot under a rounded haunch (a cylinder on the
	-- pivot axis), so a swinging leg never flashes its block corners out of the hip side
	block("UpperLeg" .. b, "UpperLeg" .. b, v(0.85, 1.25, 1.0), v(x, 1.875, 2.1), SLATE)
	disc("UpperLeg" .. b, "Haunch" .. b, 1.1, 0.85, v(x, 2.5, 2.1), SLATE, "X")
	fin("UpperLeg" .. b, "ThighTuft" .. b, v(s * 0.78, 1.5, 2.4), 0.45, 0.45, 0.4, SLATE, 2.3)
	limb("LowerLeg" .. b, "LowerLeg" .. b, knee, hock, 0.45, 0.5, CREAM, 0.25)
	ball("LowerLeg" .. b, "Knee" .. b, 0.6, knee, SLATE)
	limb("Paw" .. b, "Paw" .. b, hock, ankle, 0.42, 0.45, CREAM, 0.15)
	ball("Paw" .. b, "Hock" .. b, 0.45, hock, CREAM)
	block("Paw" .. b, "Foot" .. b, v(0.6, 0.3, 0.8), v(x, 0.15, 1.95), CREAM)
	claws("Paw" .. b, x, 1.5)
end

-- Tail ---------------------------------------------------------------------------------

block("TailBase", "TailBase", v(0.7, 0.7, 1.1), v(0, 3.25, 3.25), SLATE)
fin("TailBase", "TailBaseFin", v(0, 3.5, 3.0), 0.4, 0.6, 0.45, SLATE_HI, 0.9)
block("TailMid", "TailMid", v(0.8, 0.8, 1.2), v(0, 3.3, 4.3), SLATE)
block("TailMid", "TailMidUnder", v(0.6, 0.35, 1.1), v(0, 2.98, 4.3), CREAM)
fin("TailMid", "TailMidFin", v(0, 3.6, 4.1), 0.45, 0.6, 0.5, SLATE, 1.0)
local tipA, tipB = v(0, 3.35, 4.85), v(0, 4.25, 5.6)
limb("TailTip", "TailTip", tipA, tipB, 0.6, 0.6, SLATE, 0.2)
limb("TailTip", "TailTipUnder", tipA + v(0, -0.1, 0.18), tipB + v(0, -0.1, 0.18), 0.45, 0.35, CREAM, 0)
fin("TailTip", "TailTipFin", v(0, 4.15, 5.5), 0.5, 0.6, 0.45, SLATE, 0.3)
for _, s in { -1, 1 } do
	fin("TailTip", "TailTipSide" .. s, v(s * 0.2, 4.0, 5.45), 0.45, 0.5, 0.3, SLATE_HI, 0.4, -s * 0.6)
end

-- Place --------------------------------------------------------------------------------

local recording = ChangeHistoryService:TryBeginRecording("Build SpiritWolf_B")
local staging = ServerStorage:FindFirstChild("_StagingEnemies")
if not staging then
	staging = Instance.new("Folder")
	staging.Name = "_StagingEnemies"
	staging.Parent = ServerStorage
end
local old = staging:FindFirstChild("SpiritWolf_B")
if old then
	old:Destroy()
end
model.Parent = staging
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return ("SpiritWolf_B body: %d parts"):format(#model:GetChildren())
