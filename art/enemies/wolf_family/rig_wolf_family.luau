--!nocheck
-- Rigs a wolf-family body (Elder Wolf King, Shadow-Mane Wolf): a scaled copy of
-- art/enemies/spirit_wolf/rig_wolf.luau. Same joint names, hierarchy and pivots as
-- the Spirit Wolf, times the body's SCALE, so the Spirit Wolf's poses and clips drive
-- every member of the family. Run in Edit mode through execute_luau with TARGET set;
-- it is re-runnable.
--
-- Input: ServerStorage._RosterWolves.<TARGET>, built by build_<name>.luau in the
-- Spirit Wolf's unit space times SCALE (Hips block at (0, 2.55, 1.9) * SCALE). Detail parts
-- carry a `Segment` attribute naming the segment they weld to.
-- Every joint frame has identity rotation in model space, so rotation about X is pitch
-- on every joint, as on the Spirit Wolf.

local TARGET = _G.WOLF_TARGET or "ElderWolfKing" -- or set _G.WOLF_TARGET before loading
local STAGING = "_RosterWolves"

-- Per body: SCALE matches its build script. The HRP, HipHeight and joint pivots are the
-- Spirit Wolf's times SCALE; at 2.4 that is exactly the old ElderWolfKing's HRP
-- (4.8 x 4.8 x 10.56 at Y 6.24, HipHeight 3.84), so its AI ranges still fit.
local PROFILES = {
	ElderWolfKing = { scale = 2.4 },
	ShadowManeWolf = { scale = 1.15 },
}

local ServerStorage = game:GetService("ServerStorage")

local profile = assert(PROFILES[TARGET], "no profile for " .. TARGET)
local S = profile.scale
local HIPS_CENTRE = Vector3.new(0, 2.55, 1.9) * S -- the Hips block centre (rig_wolf says 2.85; at 1x rounding hid it)
local HRP_SIZE = Vector3.new(2, 2, 4.4) * S
local HRP_POS = Vector3.new(0, 2.6, 0) * S -- EnemyService reads rootHeight from this Y
local HIP_HEIGHT = 1.6 * S
local BAR_CLEARANCE = 1.0 -- studs between the body's top and the health bar

-- { Motor6D, Part0, Part1, pivot (unit space) }: identical to rig_wolf.luau
local JOINTS = {
	{ "JointRoot", "HumanoidRootPart", "Hips", Vector3.new(0, 2.85, 1.6) },
	{ "JointSpine", "Hips", "Chest", Vector3.new(0, 3.0, 0.8) },
	{ "JointNeck", "Chest", "Neck", Vector3.new(0, 3.15, -1.75) },
	{ "JointHead", "Neck", "Skull", Vector3.new(0, 3.15, -2.85) },
	{ "JointJaw", "Skull", "Jaw", Vector3.new(0, 2.75, -3.4) },
	{ "JointEarL", "Skull", "EarL", Vector3.new(-0.45, 3.7, -3.15) },
	{ "JointEarR", "Skull", "EarR", Vector3.new(0.45, 3.7, -3.15) },
	{ "JointLegFL", "Chest", "UpperLegFL", Vector3.new(-0.7, 2.45, -1.3) },
	{ "JointElbowFL", "UpperLegFL", "LowerLegFL", Vector3.new(-0.72, 1.35, -1.25) },
	{ "JointWristFL", "LowerLegFL", "PawFL", Vector3.new(-0.72, 0.32, -1.35) },
	{ "JointLegFR", "Chest", "UpperLegFR", Vector3.new(0.7, 2.45, -1.3) },
	{ "JointElbowFR", "UpperLegFR", "LowerLegFR", Vector3.new(0.72, 1.35, -1.25) },
	{ "JointWristFR", "LowerLegFR", "PawFR", Vector3.new(0.72, 0.32, -1.35) },
	{ "JointLegBL", "Hips", "UpperLegBL", Vector3.new(-0.7, 2.5, 2.1) },
	{ "JointKneeBL", "UpperLegBL", "LowerLegBL", Vector3.new(-0.75, 1.35, 1.8) },
	{ "JointHockBL", "LowerLegBL", "PawBL", Vector3.new(-0.75, 0.62, 2.3) },
	{ "JointLegBR", "Hips", "UpperLegBR", Vector3.new(0.7, 2.5, 2.1) },
	{ "JointKneeBR", "UpperLegBR", "LowerLegBR", Vector3.new(0.75, 1.35, 1.8) },
	{ "JointHockBR", "LowerLegBR", "PawBR", Vector3.new(0.75, 0.62, 2.3) },
	{ "JointTail", "Hips", "TailBase", Vector3.new(0, 3.3, 2.75) },
	{ "JointTail2", "TailBase", "TailMid", Vector3.new(0, 3.25, 3.75) },
	{ "JointTail3", "TailMid", "TailTip", Vector3.new(0, 3.4, 4.85) },
}

local model = ServerStorage[STAGING]:FindFirstChild(TARGET)
assert(model, ("no ServerStorage.%s.%s"):format(STAGING, TARGET))

for _, d in model:GetDescendants() do
	if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") then
		d:Destroy()
	end
end
local oldRoot = model:FindFirstChild("HumanoidRootPart")
if oldRoot then
	oldRoot:Destroy()
end

local segments = {}
for _, j in JOINTS do
	local name = j[3]
	local found = {}
	for _, c in model:GetChildren() do
		if c.Name == name and c:IsA("BasePart") then
			table.insert(found, c)
		end
	end
	assert(#found == 1, ("%s: expected one part named %s, found %d"):format(TARGET, name, #found))
	segments[name] = found[1]
end
local offset = segments.Hips.Position - HIPS_CENTRE
offset = Vector3.new(math.round(offset.X), math.round(offset.Y), math.round(offset.Z))

for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = false
		d.CanCollide = false
		d.CanTouch = false
		d.CanQuery = false
		d.Massless = true
		d.CastShadow = true
	end
end

local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = HRP_SIZE
hrp.CFrame = CFrame.new(HRP_POS + offset)
hrp.Transparency = 1
hrp.CanCollide = true
hrp.TopSurface = Enum.SurfaceType.Smooth
hrp.BottomSurface = Enum.SurfaceType.Smooth
hrp.Parent = model
local bar = ServerStorage.Enemies.SpiritWolf.HumanoidRootPart.HealthBar:Clone()
-- sit the bar just over the tallest crest, measured from the HRP
local cf, size = model:GetBoundingBox()
local bodyTop = cf.Position.Y + size.Y / 2
bar.StudsOffset = Vector3.new(0, bodyTop - hrp.Position.Y + BAR_CLEARANCE, 0)
bar.Parent = hrp
segments.HumanoidRootPart = hrp

local welds = 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and not segments[d.Name] then
		local seg = d:GetAttribute("Segment")
		assert(seg and segments[seg], ("%s: %s has no valid Segment attribute"):format(TARGET, d:GetFullName()))
		local w = Instance.new("WeldConstraint")
		w.Name = d.Name
		w.Part0 = segments[seg]
		w.Part1 = d
		w.Parent = segments[seg]
		welds += 1
	end
end

for _, j in JOINTS do
	local p0, p1 = segments[j[2]], segments[j[3]]
	local pivot = CFrame.new(j[4] * S + offset)
	local m = Instance.new("Motor6D")
	m.Name = j[1]
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * pivot
	m.C1 = p1.CFrame:Inverse() * pivot
	m.Parent = p0
end

local hum = Instance.new("Humanoid")
hum.RigType = Enum.HumanoidRigType.R15
hum.HipHeight = HIP_HEIGHT
hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
hum.Parent = model
model.PrimaryPart = hrp
model.WorldPivot = CFrame.new(hrp.Position) -- identity rotation: never spawns on its side
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model:SetAttribute("Scale", S)

local parts, tells = 0, 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d:GetAttribute("Tell") then
			tells += 1
		end
	end
end
return ("%s rigged at %.2fx: %d parts (%d tells), %d joints, %d welds, bar +%.1f, offset %s"):format(
	TARGET, S, parts, tells, #JOINTS, welds, bar.StudsOffset.Y, tostring(offset))
