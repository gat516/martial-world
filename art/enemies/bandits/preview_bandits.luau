--!nocheck
-- Lines up the bandit roster in Workspace._RosterPreviewBandits on a plate at PREVIEW_AT:
-- an R6 player for scale, then each bandit at rest and in its attack windup pose.
-- Poses by forward kinematics (Transform doesn't move parts in Edit mode): solve each
-- R6 part from its parent through C0 * pose * C1^-1, cut the motors, then move every
-- detail part with the segment it's welded to. Run in Edit mode; re-runnable.

local PREVIEW_AT = CFrame.new(400, 400, 3000)
local SPACING = 5
local ONLY = nil -- e.g. "MountainBandit" to preview one model
local MODE = "attack" -- "attack": rest + windup; "test": stride + arms raised (clipping check)

local ServerStorage = game:GetService("ServerStorage")

local A = CFrame.Angles
-- R6 joint conventions (pose is applied in the joint's frame):
--   Right Shoulder / Right Hip: A(0,0,+a) swings forward, A(-b,0,0) swings out.
--   Left Shoulder / Left Hip:   A(0,0,-a) swings forward, A(-b,0,0) swings out.
--   Neck / RootJoint:           A(+a,0,0) pitches forward (head down / lean in), A(0,0,y) yaws.
--   Hilt (weapon motor, arm frame): A(x,0,0) pitches the blade (+ up when the arm hangs).
local POSES = {
	MountainBandit = {
		rest = {
			["Right Shoulder"] = A(0, 0, 0.15), ["Left Shoulder"] = A(-0.08, 0, 0),
			Hilt = A(-0.9, 0, 0),
		},
		-- windup for the overhead chop: dao raised high behind the head, weight back
		windup = {
			RootJoint = A(-0.12, 0, 0.35), Neck = A(0.05, 0, -0.3),
			["Right Shoulder"] = A(-0.25, 0, 2.7), ["Left Shoulder"] = A(-0.2, 0, -0.9),
			["Right Hip"] = A(0, 0, -0.35), ["Left Hip"] = A(0, 0, -0.45),
			Hilt = A(0.5, 0, 0),
		},
	},
	BanditArcher = {
		rest = {
			["Left Shoulder"] = A(-0.05, 0, -0.35), ["Right Shoulder"] = A(-0.05, 0, 0),
		},
		-- full draw: bow arm straight at the target, string hand at the jaw, body side-on
		windup = {
			RootJoint = A(0, 0, 0.9), Neck = A(0, 0, -0.9),
			["Left Shoulder"] = A(0, -0.9, -1.57),
			["Right Shoulder"] = A(0, 0.9, 1.45),
			["Right Hip"] = A(0, 0, 0.25), ["Left Hip"] = A(0, 0, 0.2),
		},
	},
	BanditChief = {
		rest = {
			["Right Shoulder"] = A(-0.1, 0, 0.35), Hilt = A(1.2, 0, 0),
			["Left Shoulder"] = A(-0.15, 0, 0),
		},
		-- windup for the sweeping cleave: guandao drawn back low across the body
		windup = {
			RootJoint = A(0.15, 0, -0.6), Neck = A(-0.1, 0, 0.5),
			["Right Shoulder"] = A(-0.6, 0, 0.3), ["Left Shoulder"] = A(-0.2, 0, -1.3),
			["Right Hip"] = A(-0.3, 0, -0.3), ["Left Hip"] = A(0, 0, -0.5),
			Hilt = A(0.3, 0.6, 0),
		},
	},
}

-- joint-range test poses shared by every bandit
local TEST = {
	stride = {
		["Right Shoulder"] = A(0, 0, 0.9), ["Left Shoulder"] = A(0, 0, 0.9),
		["Right Hip"] = A(0, 0, -0.8), ["Left Hip"] = A(0, 0, -0.8),
		RootJoint = A(0.1, 0, 0),
	},
	raised = {
		["Right Shoulder"] = A(-0.3, 0, 3.0), ["Left Shoulder"] = A(-0.3, 0, -3.0),
		["Right Hip"] = A(-0.5, 0, 0.9), ["Left Hip"] = A(-0.5, 0, 0),
		Neck = A(-0.4, 0, 0.5),
	},
}

local preview = workspace:FindFirstChild("_RosterPreviewBandits")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_RosterPreviewBandits"
preview:AddTag("EditorOnly") -- stripped at runtime; every part in it is anchored
preview.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(44, 1, 20)
plate.CFrame = PREVIEW_AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Material = Enum.Material.SmoothPlastic
plate.Parent = preview

local function pose(copy, p)
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(motors, m)
		end
	end
	-- each non-motor part follows the segment it hangs off
	local follow = {}
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			local seg = part:GetAttribute("Segment")
			local owner = seg and (copy:FindFirstChild(seg) or copy:FindFirstChild(seg, true))
			if owner and owner ~= part then
				follow[part] = { owner, owner.CFrame:Inverse() * part.CFrame }
			end
		end
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (p[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree doesn't reach the root")
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
	for part, f in follow do
		part.CFrame = f[1].CFrame * f[2]
	end
end

local rows = { { workspace.Rig, nil, "Player" } }
for _, name in { "MountainBandit", "BanditArcher", "BanditChief" } do
	local m = ServerStorage._RosterBandits:FindFirstChild(name)
	if m and (not ONLY or ONLY == name) then
		local pair = if MODE == "test" then { "stride", "raised" } else { "rest", "windup" }
		for _, which in pair do
			table.insert(rows, { m, which, name .. "_" .. which })
		end
	end
end
local placed = {}
for i, row in rows do
	local template, which, label = row[1], row[2], row[3]
	local copy = template:Clone()
	copy.Name = label
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local x = (i - (#rows + 1) / 2) * SPACING
	local y = if which then template.HumanoidRootPart.Position.Y else 3
	copy.PrimaryPart = copy.HumanoidRootPart
	copy:PivotTo(PREVIEW_AT * CFrame.new(x, y, 0))
	copy.Parent = preview
	if which then
		pose(copy, TEST[which] or POSES[template.Name][which])
	else
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end
	table.insert(placed, label .. " @x" .. x)
end
return table.concat(placed, ", ")
