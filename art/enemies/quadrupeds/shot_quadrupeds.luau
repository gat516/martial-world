--!nocheck
-- Capture stage for the quadruped QA: puts ONE posed copy of a roster model on its own
-- plate at SHOT_AT (in Workspace._RosterPreviewQuadrupeds._Shot, EditorOnly, anchored),
-- with an R6 player for scale beside it, and returns camera spots for the standard views.
-- Set MODEL and POSE (nil = rest, or WINDUP / STRETCH / CROUCH) with a gsub first.

local MODEL = "StoneBoar_R"
local POSE = nil
local SHOT_AT = CFrame.new(320, 400, 3100)

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local POSES = loadstring(HttpService:GetAsync("http://127.0.0.1:8767/quadrupeds/poses_quadrupeds.luau?" .. os.clock()))()

local preview = workspace:FindFirstChild("_RosterPreviewQuadrupeds")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "_RosterPreviewQuadrupeds"
	preview:AddTag("EditorOnly")
	preview.Parent = workspace
end
local old = preview:FindFirstChild("_Shot")
if old then
	old:Destroy()
end
local shot = Instance.new("Folder")
shot.Name = "_Shot"
shot.Parent = preview
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(40, 1, 40)
plate.CFrame = SHOT_AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Material = Enum.Material.SmoothPlastic
plate.Parent = shot

local template = ServerStorage._RosterQuadrupeds[MODEL]
local copy = template:Clone()
copy:PivotTo(SHOT_AT * CFrame.new(0, template.HumanoidRootPart.Position.Y, 0))
copy.HumanoidRootPart.Anchored = true
copy.Parent = shot
local pose = POSE and POSES[POSE][MODEL] or {}
local motors = {}
for _, m in copy:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
	end
end
local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
local pending = #motors
while pending > 0 do
	for _, m in motors do
		if world[m.Part0] and not world[m.Part1] then
			world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
			pending -= 1
		end
	end
end
for _, m in motors do
	m.Part1 = nil
end
for part, cf in world do
	part.CFrame = cf
end
for _, d in copy:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
local player = workspace:FindFirstChild("Rig")
if player then
	local p = player:Clone()
	for _, d in p:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- stand it on the plate by its lowest visible part (its bounding box reaches lower
	-- than the feet, so a box-based lift left it floating)
	local bottom = math.huge
	for _, d in p:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			bottom = math.min(bottom, d.Position.Y - d.Size.Y / 2)
		end
	end
	local lift = p:GetPivot().Position.Y - bottom
	p:PivotTo(SHOT_AT * CFrame.new(-9, lift, 9))
	p.Parent = shot
end
local c = SHOT_AT.Position
return HttpService:JSONEncode({ centre = { c.X, c.Y, c.Z } })
