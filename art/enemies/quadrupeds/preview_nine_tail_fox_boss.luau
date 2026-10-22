--!nocheck
-- Posed preview of NineTailFoxB's tails, for captures. Run in Edit mode through execute_luau
-- after build + rig: set _G.FoxPreview = { at = Vector3, pose = "<name>" or pose function,
-- e = 0..1, name = folder name (default "_FoxPreview", so several can stand side by side) }
-- then loadstring this file. It clones the template into Workspace._FoxPreview
-- (anchored, EditorOnly, replaced on every run), poses every tail with the same formula the
-- pose module uses (base: yaw * pitch * roll; Mid/Tip/Whip: rotation * slide along ExtendAxis
-- by ExtendMax * e) and returns the clone. Poses: rest (the pose module's REST_T curls), fan,
-- swept, plunge (odd tails pitched down), or a function(i) -> { base, ext, mid, tip, whip }.
local cfg = _G.FoxPreview or {}
local template = game:GetService("ServerStorage")._RosterQuadrupeds.NineTailFoxB

local function curl(i, e, k)
	-- the pose module's default S curve (shp: curl 0.6), shrinking as the tail extends
	local t, lim, c = (i - 5) / 4, 1 - 0.45 * e, 0.6 * (k or 1)
	return CFrame.Angles(-0.07 * c * lim, 0, 0.05 * c * t * lim), CFrame.Angles(0.09 * c * lim, 0, -0.06 * c * t * lim),
		CFrame.Angles(-0.2 * c * lim, 0, 0.1 * c * t * lim)
end
local POSES = {
	rest = function(i, e)
		local a, b, c = curl(i, e)
		return { ext = e, base = CFrame.Angles(0.02 * (i % 2), 0, -(i - 5) / 4 * 0.3), mid = a, tip = b, whip = c }
	end,
	straight = function(i, e)
		return { ext = e }
	end,
	fan = function(i, e)
		local a, b, c = curl(i, e)
		return { ext = e, base = CFrame.Angles(0, 0, -(i - 5) / 4 * 0.55), mid = a, tip = b, whip = c }
	end,
	swept = function(i, e)
		local a, b, c = curl(i, e)
		return { ext = e, base = CFrame.Angles(0.5, 0, -(i - 5) / 4 * 0.3), mid = a, tip = b, whip = c }
	end,
	plunge = function(i, e)
		if i % 2 == 0 then
			return { ext = 0, base = CFrame.Angles(0, 0, -(i - 5) / 4 * 0.3) }
		end
		return { ext = e, base = CFrame.Angles(1.0, 0, -(i - 5) / 4 * 0.5) }
	end,
	bendBig = function(i, e)
		return { ext = e, mid = CFrame.Angles(0.3, 0, 0.3), tip = CFrame.Angles(-0.3, 0, -0.3), whip = CFrame.Angles(0.5, 0, 0.5) }
	end,
}

local folderName = cfg.name or "_FoxPreview"
local old = workspace:FindFirstChild(folderName)
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = folderName
folder:AddTag("EditorOnly")
local copy = template:Clone()
local at = cfg.at or Vector3.new(0, 0, 0)
copy:PivotTo(CFrame.new(at + Vector3.new(0, template.HumanoidRootPart.Position.Y, 0)))
copy.Parent = folder
local e = cfg.e or 0
local poseFn = if type(cfg.pose) == "function" then cfg.pose else POSES[cfg.pose or "rest"]
local spec = {}
for i = 1, 9 do
	spec[i] = poseFn(i, e)
end
local motors = {}
for _, m in copy:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
	end
end
local function transformFor(m)
	local i, kind = m.Name:match("^JointTail(%d)(%a*)$")
	if not i then
		return CFrame.identity
	end
	local s = spec[tonumber(i)]
	if kind == "" then
		return s.base or CFrame.identity
	end
	local rot = (kind == "Mid" and s.mid) or (kind == "Tip" and s.tip) or (kind == "Whip" and s.whip) or CFrame.identity
	return rot * CFrame.new(m:GetAttribute("ExtendAxis") * m:GetAttribute("ExtendMax") * (s.ext or 0))
end
local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
local pending = #motors
while pending > 0 do
	local before = pending
	for _, m in motors do
		if world[m.Part0] and not world[m.Part1] then
			world[m.Part1] = world[m.Part0] * m.C0 * transformFor(m) * m.C1:Inverse()
			pending -= 1
		end
	end
	assert(pending < before, "motor tree broken")
end
-- move each segment and carry its welded detail along
local rel = {}
for _, d in copy:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Segment") then
		local seg = copy:FindFirstChild(d:GetAttribute("Segment"))
		rel[d] = { seg, seg.CFrame:ToObjectSpace(d.CFrame) }
	end
end
for _, m in motors do
	m.Part1 = nil
end
for part, cf in world do
	part.CFrame = cf
end
for d, r in rel do
	d.CFrame = r[1].CFrame * r[2]
end
for _, d in copy:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
folder.Parent = workspace
return copy
