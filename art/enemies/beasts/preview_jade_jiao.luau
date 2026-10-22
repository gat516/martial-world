--!nocheck
-- Jade Jiao previews: ServerStorage._RosterBeasts.JadeJiao posed by FK on a plate at
-- (300, 400, 3200) in Workspace._JiaoPreview (anchored, tagged EditorOnly): rest, a coil
-- curl (Tail1..12 yaw by seglen/8 each, radius 8), and sunk (JointRoot y -6). Also the
-- coil check: reports every pair of non-adjacent tail segments whose parts overlap at the
-- curl. Run in Edit mode through execute_luau; re-runnable. Returns the report.

local ServerStorage = game:GetService("ServerStorage")
local AT = CFrame.new(300, 400, 3200)
local template = ServerStorage._RosterBeasts.JadeJiao
local K = 3.17 / 1.9
local TAIL_LEN = { 3, 3, 3, 3, 3, 3, 2.8, 2.8, 2.8, 2.8, 2.8, 2.8 }

local old = workspace:FindFirstChild("_JiaoPreview")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "_JiaoPreview"
folder:AddTag("EditorOnly")
folder.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(180, 1, 80)
plate.CFrame = AT * CFrame.new(0, -0.5, 20)
plate.Color = Color3.fromHex("6E7F5A")
plate.Parent = folder

local function fk(copy, pose)
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") then
			table.insert(motors, m)
		end
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree doesn't reach the root")
	end
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
end

local function place(label, x, pose)
	local c = template:Clone()
	c.Name = label
	c.Parent = folder
	c:PivotTo(AT * CFrame.new(x, template.HumanoidRootPart.Position.Y, 0))
	fk(c, pose)
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = true
		end
	end
	return c
end

local coil = {}
for i = 1, 12 do
	coil[if i == 1 then "JointTail" else "JointTail" .. i] = CFrame.Angles(0, TAIL_LEN[i] / 8, 0)
end
local rest = place("Rest", 0, {})
local curl = place("Coil", 70, coil)
place("Sunk", -70, { JointRoot = CFrame.new(0, -6 * K, 0) })

-- coil check: overlaps between non-adjacent tail segments (and the body)
local segOf = {}
for _, d in curl:GetDescendants() do
	if d:IsA("BasePart") then
		segOf[d] = d:GetAttribute("Segment") or d.Name
	end
end
local function idx(seg)
	if seg == "Body" then
		return 0
	end
	return tonumber(seg:match("^Tail(%d+)$"))
end
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { curl }
local pairsHit = {}
for part, seg in segOf do
	local i = idx(seg)
	if i and i <= 12 then
		for _, o in workspace:GetPartsInPart(part, params) do
			local j = idx(segOf[o] or "")
			if j and j <= 12 and math.abs(i - j) >= 2 then
				local k = math.min(i, j) .. "-" .. math.max(i, j)
				pairsHit[k] = (pairsHit[k] or 0) + 1
			end
		end
	end
end
local out = {}
for k, n in pairsHit do
	table.insert(out, k .. " x" .. n)
end
table.sort(out)
return "coil overlaps (non-adjacent): " .. (if #out == 0 then "none" else table.concat(out, ", "))
