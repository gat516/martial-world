--!nocheck
-- Rigs a Spirit Wolf body: the shared assembler for both bodies, variant A (Blender
-- segment meshes, build_spirit_wolf.py) and variant B (Studio parts,
-- spirit_wolf_b/build_spirit_wolf_b.luau). Both rigs come out identical, so one
-- pose table and one set of Animation Editor clips drive either body. Run in Edit
-- mode through execute_luau with TARGET set; it is re-runnable.
--
-- Input: a model in ServerStorage._StagingEnemies holding one part per segment, named
-- as in JOINTS below, with its Hips at (0, 2.55, 1.9) plus any whole-stud offset (A sits
-- 15 studs over in +X). Detail parts carry a `Segment` attribute naming the segment
-- they weld to; EyeL and EyeR default to Skull.
-- Model space: ground Y=0, the wolf faces -Z, its left side is -X. Every joint frame
-- has identity rotation in model space, so rotation about X is pitch on every joint.
-- The legacy names (JointHead, JointTail, JointLeg*) keep their old meaning, so the
-- current EnemyAnimator drives the new rig unchanged.

local TARGET = "SpiritWolf_B"

local ServerStorage = game:GetService("ServerStorage")

local HIPS_CENTRE = Vector3.new(0, 2.55, 1.9) -- where build_spirit_wolf_b puts the Hips block
local HRP_SIZE = Vector3.new(2, 2, 4.4) -- kept from the old wolf: AI ranges are tuned to it
local HRP_POS = Vector3.new(0, 2.6, 0) -- EnemyService reads rootHeight from this Y
local HIP_HEIGHT = 1.6

-- { Motor6D, Part0, Part1, pivot }
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
-- Extra animator joints per body, named Joint<Part1>. Variant A has none.
local EXTRAS = {
	SpiritWolf_B = {
		{ "JointCrest", "Chest", "Crest", Vector3.new(0, 3.8, -0.3) }, -- the dorsal crest, to bristle on a windup
	},
}
for _, j in EXTRAS[TARGET] or {} do
	table.insert(JOINTS, j)
end

local model = ServerStorage._StagingEnemies:FindFirstChild(TARGET)
assert(model, "no ServerStorage._StagingEnemies." .. TARGET)

-- Strip any earlier rig so this re-runs cleanly.
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
segments.Hips = model:FindFirstChild("Hips")
assert(segments.Hips, TARGET .. ": no Hips")
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
local healthBar = ServerStorage.Enemies.SpiritWolf.HumanoidRootPart.HealthBar:Clone()
-- seat it about a stud over the built body's top (computed, so a body change can't bury it)
local top = -math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d ~= hrp then
		local cf, h = d.CFrame, d.Size / 2
		top = math.max(top, cf.Y + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.RightVector.Y) * h.X + math.abs(cf.LookVector.Y) * h.Z)
	end
end
healthBar.StudsOffset = Vector3.new(0, top + 1 - hrp.Position.Y, 0)
healthBar.Parent = hrp
segments.HumanoidRootPart = hrp

local welds = 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and not segments[d.Name] then
		local seg = d:GetAttribute("Segment")
			or if d.Name == "EyeL" or d.Name == "EyeR" then "Skull" else nil
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
	local pivot = CFrame.new(j[4] + offset)
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
Instance.new("Animator").Parent = hum -- Moon Animator and the Animation Editor play through it
hum.Parent = model
model.PrimaryPart = hrp -- EnemyService pivots on the HRP at its template height
model.WorldPivot = CFrame.new(hrp.Position) -- identity rotation: never spawns on its side
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local parts = 0
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return ("%s rigged: %d parts, %d joints, %d welds, offset %s"):format(TARGET, parts, #JOINTS, welds, tostring(offset))
