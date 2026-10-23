--!nocheck
-- Jade Jiao previews: ServerStorage._RosterBeasts.JadeJiao posed by FK on a plate at
-- (300, 400, 3200) in Workspace._JiaoPreview (anchored, tagged EditorOnly), next to the
-- user's reference snake (jade_python_ref.rbxm.b64) for side-by-side captures:
--   Ref    the reference as serialized, x -45
--   Rest   the template at rest, x 0
--   Strike stress pose: hood flared, fangs out, jaw open, tongue out, barbels shown, x 45
--   Sunk   JointRoot y -2 x S (the body under the ground), x 90
--   Ring   Body fixed, Tail1..18 laid on one constant-curvature curve of radius RING_R, x 150
-- and the coil check: for each radius in RADII, lays the tail on that curve and reports the
-- non-adjacent segment pairs (Body = 0, Tail1..18) whose parts overlap.
-- Run in Edit mode through execute_luau; re-runnable. Returns the report.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local AT = CFrame.new(300, 400, 3200)
local RING_R = 8
local RADII = { 6, 7, 8, 9, 10, 11, 12 }
local template = ServerStorage._RosterBeasts.JadeJiao
local S = template:GetAttribute("Scale")

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
plate.Size = Vector3.new(280, 1, 90)
plate.CFrame = AT * CFrame.new(50, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Parent = folder

-- the reference, decoded from the base64 next to the build
do
	local raw = HttpService:GetAsync(BASE .. "jade_python_ref.rbxm.b64?" .. os.clock())
	local map = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do
		map[string.byte(alphabet, i)] = i - 1
	end
	local s = raw:gsub("[^%w%+/=]", "")
	local n = #s // 4 * 3 - select(2, s:gsub("=", ""))
	local b = buffer.create(n)
	local o = 0
	for i = 1, #s, 4 do
		local a1, c, d, e = string.byte(s, i, i + 3)
		local val = map[a1] * 262144 + map[c] * 4096 + (map[d] or 0) * 64 + (map[e] or 0)
		for k = 2, 0, -1 do
			if o < n then
				buffer.writeu8(b, o, bit32.band(bit32.rshift(val, k * 8), 255))
				o += 1
			end
		end
	end
	local ref = SerializationService:DeserializeInstancesAsync(b)[1]
	ref.Name = "Ref"
	for _, d in ref:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- the reference's origin (ground, roster origin) onto the plate
	ref.PrimaryPart = ref.HumanoidRootPart -- identity rotation
	ref:PivotTo(AT * CFrame.new(-45, 2 * S, 1.6 * S))
	ref.Parent = folder
end

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
	c:PivotTo(AT * CFrame.new(x, template.HumanoidRootPart.Position.Y, template.HumanoidRootPart.Position.Z))
	-- FK by hand on anchored parts: drop the welds, move segments, then carry each detail
	-- with its segment
	local segOf, before = {}, {}
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = true
			if d:GetAttribute("Segment") then
				segOf[d] = c:FindFirstChild(d:GetAttribute("Segment"))
				before[d] = segOf[d].CFrame:ToObjectSpace(d.CFrame)
			end
		elseif d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	fk(c, pose)
	for d, seg in segOf do
		d.CFrame = seg.CFrame * before[d]
	end
	return c
end

-- tail rest headings from the joint pivots (bone directions)
local pivot = {}
for _, d in template:GetChildren() do
	if d:IsA("BasePart") and d:GetAttribute("JointPivot") then
		pivot[d.Name] = d:GetAttribute("JointPivot")
	end
end
local tailLen, heading = {}, {}
local tipEnd = (template.TailTipGem.CFrame * CFrame.new(0, 0, -template.TailTipGem.Size.Z / 2)).Position
for i = 1, 18 do
	local a = pivot["Tail" .. i]
	local b = if i < 18 then pivot["Tail" .. (i + 1)] else tipEnd
	local d = b - a
	tailLen[i] = Vector3.new(d.X, 0, d.Z).Magnitude
	heading[i] = math.atan2(-d.X, -d.Z)
end
local function ringPose(R)
	local pose = {}
	local prevOff = 0
	local theta = heading[1]
	for i = 1, 18 do
		if i > 1 then
			theta += (tailLen[i - 1] + tailLen[i]) / 2 / R
		end
		local off = theta - heading[i]
		pose[if i == 1 then "JointTail" else "JointTail" .. i] = CFrame.Angles(0, off - prevOff, 0)
		prevOff = off
	end
	return pose
end

local rad = 1
place("Rest", 0, {})
place("Strike", 45, {
	JointHoodL = CFrame.Angles(0, -1.2, 0),
	JointHoodR = CFrame.Angles(0, 1.2, 0),
	JointFangL = CFrame.Angles(1.45, 0, 0),
	JointFangR = CFrame.Angles(1.45, 0, 0),
	JointJaw = CFrame.Angles(-0.7, 0, 0),
	JointTongue = CFrame.Angles(-0.15, 0, 0),
	JointBarbelL1 = CFrame.Angles(0, -0.3 * rad, 0),
	JointBarbelR1 = CFrame.Angles(0, 0.3 * rad, 0),
})
for _, d in folder.Strike:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("PhaseReveal") then
		d.Transparency = 0.05
	end
end
place("Sunk", 90, { JointRoot = CFrame.new(0, -2 * S, 0) })
place("Ring", 150, ringPose(RING_R))

-- coil check
local function idx(seg)
	if seg == "Body" then
		return 0
	end
	return tonumber(seg:match("^Tail(%d+)$"))
end
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local function overlapsAt(pose)
	local c = place("Check", 230, pose)
	params.FilterDescendantsInstances = { c }
	local segOf = {}
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			segOf[d] = d:GetAttribute("Segment") or d.Name
		end
	end
	local hits = {}
	for p, seg in segOf do
		local i = idx(seg)
		if i then
			for _, o in workspace:GetPartsInPart(p, params) do
				local j = idx(segOf[o] or "")
				if j and math.abs(i - j) >= 2 then
					hits[math.min(i, j) .. "-" .. math.max(i, j)] = true
				end
			end
		end
	end
	c:Destroy()
	task.wait()
	return hits
end
-- pairs that already touch at rest (a scute or the reference's padded tube ends reaching
-- past a short neighbour) are the reference's own geometry; report only new contacts
local restHits = overlapsAt({})
local base = {}
for k in restHits do
	table.insert(base, k)
end
table.sort(base)
local out = { "touching at rest (reference geometry): " .. (if #base == 0 then "none" else table.concat(base, " ")) }
for _, R in RADII do
	local list = {}
	for k in overlapsAt(ringPose(R)) do
		if not restHits[k] then
			table.insert(list, k)
		end
	end
	table.sort(list)
	table.insert(out, ("R %d: %s"):format(R, if #list == 0 then "none" else table.concat(list, " ")))
end
local total = 0
for i = 1, 18 do
	total += tailLen[i]
end
return ("tail centreline %.2f studs (ground plan)\n"):format(total) .. table.concat(out, "\n")
