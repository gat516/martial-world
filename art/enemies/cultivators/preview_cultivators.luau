--!nocheck
-- Lines the cultivator roster up in Workspace._RosterPreviewCultivators on a plate
-- at (500, 400, 3000), with a Workspace.Rig clone for scale. Each model appears
-- at rest and, behind it, in its first attack's windup pose. Re-runnable.
-- Transform doesn't move parts in Edit mode, so poses are applied by forward
-- kinematics over every Motor6D (stock and extra): solve each part from its motor,
-- cut the motors, move the parts (their welded details follow, as the copy is in the
-- DataModel), measure each welded piece's drift, anchor. MODE "stress" also swings
-- every extra joint. With RUN = false (gsub) it returns { place, pose, POSES, STRESS }
-- for solo_cultivator.luau.

local AT = CFrame.new(500, 400, 3000)
local SPACING = 6
-- MODE: "both" (rest row plus a windup row behind it), "rest", "windup" or "stress"
-- (one row, every model in the stress pose: arms raised, a wide stride, a lean)
local MODE = "both"
local ORDER = { "RogueCultivator", "DemonicCultivator", "BloodSectCultist", "OuterSectDisciple", "SectElder" }

local ServerStorage = game:GetService("ServerStorage")
local st = ServerStorage:FindFirstChild("_RosterCultivators")

-- joint-space rotations (R6 motors): shoulders/hips Z = swing (right +fwd, left -fwd),
-- X = -out to the side; Neck/RootJoint X = +nod/lean forward, Z = turn.
local function arm(side, fwd, out, twist)
	local s = if side == "R" then 1 else -1
	return CFrame.Angles(-(out or 0), s * (twist or 0), s * fwd)
end
local POSES = {
	-- Rogue: Drawn Sword Rush, jian cocked back over the right shoulder, low lunge
	RogueCultivator = {
		RootJoint = CFrame.new(0, -0.25, 0) * CFrame.Angles(0.25, 0, -0.35),
		Neck = CFrame.Angles(-0.15, 0, 0.3),
		["Right Shoulder"] = arm("R", 2.4, 0.5, 0.4), ["Left Shoulder"] = arm("L", 0.9, -0.35),
		["Right Hip"] = arm("R", -0.5), ["Left Hip"] = arm("L", 0.7),
	},
	-- Demonic: Blood Palm, right palm drawn back at the hip, left claw forward
	DemonicCultivator = {
		RootJoint = CFrame.new(0, -0.3, 0) * CFrame.Angles(0.15, 0, 0.45),
		Neck = CFrame.Angles(0.1, 0, -0.4),
		["Right Shoulder"] = arm("R", -0.9, 0.35), ["Left Shoulder"] = arm("L", 1.4, 0.2),
		["Right Hip"] = arm("R", -0.45, 0.25), ["Left Hip"] = arm("L", 0.55, 0.15),
	},
	-- Cultist: Bloodletting Lunge, dagger raised overhead in both hands
	BloodSectCultist = {
		RootJoint = CFrame.Angles(-0.2, 0, 0),
		Neck = CFrame.Angles(-0.25, 0, 0),
		["Right Shoulder"] = arm("R", 2.9, -0.25), ["Left Shoulder"] = arm("L", 2.8, -0.35),
		["Right Hip"] = arm("R", 0.25), ["Left Hip"] = arm("L", -0.2),
	},
	-- Disciple: Spear Thrust, spear drawn back level, weight on the back leg
	OuterSectDisciple = {
		RootJoint = CFrame.new(0, -0.3, 0) * CFrame.Angles(0.1, 0, 0.6),
		Neck = CFrame.Angles(0, 0, -0.55),
		["Right Shoulder"] = arm("R", 1.3, 0.2, 0), ["Left Shoulder"] = arm("L", 1.45, -0.3),
		["Right Hip"] = arm("R", -0.55, 0.2), ["Left Hip"] = arm("L", 0.6, 0.1),
	},
	-- Elder: Heaven-Sealing Talisman Rain, whisk raised high, left palm up
	SectElder = {
		RootJoint = CFrame.Angles(-0.12, 0, 0),
		Neck = CFrame.Angles(-0.3, 0, 0),
		["Right Shoulder"] = arm("R", 2.7, 0.3), ["Left Shoulder"] = arm("L", 1.3, 0.6, 0.8),
		["Right Hip"] = arm("R", 0.1, 0.12), ["Left Hip"] = arm("L", 0, 0.12),
	},
}

local STRESS = {
	RootJoint = CFrame.Angles(0.2, 0, 0.25), Neck = CFrame.Angles(-0.3, 0, 0.3),
	["Right Shoulder"] = arm("R", 2.6, 0.4), ["Left Shoulder"] = arm("L", -0.9, 0.5),
	["Right Hip"] = arm("R", 0.8, 0.15), ["Left Hip"] = arm("L", -0.75, 0.15),
}
-- extra (animator) joints swing this much in the stress pose, so their pieces are
-- checked under motion too
local EXTRA_STRESS = CFrame.Angles(0.45, 0.2, 0.25)

-- Forward kinematics over every Motor6D (the stock six and the extra animator
-- joints): solve each Part1 from Part0 * C0 * pose * C1:Inverse(), parents first,
-- cut the motors and move each part (its welded pieces follow, as the model is in
-- the DataModel). Returns the max drift of any welded piece from its part.
local STOCK = { RootJoint = true, Neck = true, ["Left Shoulder"] = true, ["Right Shoulder"] = true,
	["Left Hip"] = true, ["Right Hip"] = true }
local function pose(model, p, extra)
	local motors, byPart1 = {}, {}
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(motors, m)
			byPart1[m.Part1] = m
		end
	end
	local target = { [model.HumanoidRootPart] = model.HumanoidRootPart.CFrame }
	local function solve(part)
		if target[part] then
			return target[part]
		end
		local m = byPart1[part]
		local t = p[m.Name] or (not STOCK[m.Name] and extra) or CFrame.identity
		target[part] = solve(m.Part0) * m.C0 * t * m.C1:Inverse()
		return target[part]
	end
	for _, m in motors do
		solve(m.Part1)
	end
	-- each welded piece's offset to its weld partner before the move
	local offsets = {}
	for _, w in model:GetDescendants() do
		if w:IsA("WeldConstraint") and w.Part0 and w.Part1 then
			offsets[w] = w.Part0.CFrame:ToObjectSpace(w.Part1.CFrame)
		end
	end
	for _, m in motors do
		m:Destroy()
	end
	for part, cf in target do
		part.CFrame = cf
	end
	local drift = 0
	for w, off in offsets do
		local now = w.Part0.CFrame:ToObjectSpace(w.Part1.CFrame)
		drift = math.max(drift, (now.Position - off.Position).Magnitude, (now.LookVector - off.LookVector).Magnitude)
	end
	return drift
end

-- Clone template `name` (or a model) into `parent` with its feet at `at`, posed
-- ("rest", "windup" or "stress"), anchored, joints stripped. Returns the copy and
-- the drift measured while posing.
local function place(template, at, mode, parent)
	if type(template) == "string" then
		template = st:FindFirstChild(template)
	end
	local copy = template:Clone()
	copy.Name = template.Name .. (mode == "rest" and "" or "_" .. mode)
	copy.Parent = parent
	local hrp = copy.HumanoidRootPart
	local want = (at * CFrame.new(0, 1.5 * hrp.Size.Y, 0)).Position
	copy:PivotTo(copy:GetPivot() + (want - hrp.Position))
	local drift = 0
	if mode == "windup" and POSES[template.Name] then
		drift = pose(copy, POSES[template.Name], nil)
	elseif mode == "stress" then
		drift = pose(copy, STRESS, EXTRA_STRESS)
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- every part is anchored, so joints and attachments only clutter the captures
	for _, d in copy:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") then
			d:Destroy()
		end
	end
	return copy, drift
end

local RUN = true
if not RUN then
	return { place = place, POSES = POSES, STRESS = STRESS, pose = pose }
end

local preview = workspace:FindFirstChild("_RosterPreviewCultivators")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_RosterPreviewCultivators"
preview:AddTag("EditorOnly") -- stripped at runtime
preview.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(44, 1, 24)
plate.CFrame = AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Material = Enum.Material.SmoothPlastic
plate.Parent = preview

local list = {}
for _, n in ORDER do
	local m = st and st:FindFirstChild(n)
	if m then
		table.insert(list, m)
	end
end
local scale = workspace.Rig:Clone()
for _, d in scale:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		d:Destroy()
	end
end
scale.Name = "PlayerScale"
table.insert(list, 1, scale)

local report = {}
for i, template in list do
	local x = (i - (#list + 1) / 2) * SPACING
	local rows = if MODE == "both" then { "rest", "windup" } else { MODE }
	for row, mode in rows do
		if mode == "windup" and not POSES[template.Name] then
			continue
		end
		local _, drift = place(template, AT * CFrame.new(x, 0, (row - 1) * 7), mode, preview)
		table.insert(report, string.format("%s %s drift %.4f", template.Name, mode, drift))
	end
end
return table.concat(report, "\n")
