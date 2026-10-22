--!nocheck
-- Brings the user's reference Flame Raven (testbed workspace.Folder.Model.FlameRaven, 1.0x) into
-- ServerStorage.Enemies as FlameRavenB. The look is untouched and no Tell bands are added (the
-- source already has EyeL/R, Crest and 8 primary-tip tells). HOVER convention (same as the old
-- roster Raven and the Blood Bat): the pivot is the HumanoidRootPart centre at Y 5.0, the root is
-- 3 tall so its bottom is 3.5 (Humanoid.HipHeight 3.5), and the talons hang to Y 3.25. The root is
-- sized to the body (head to tail, no wings), not the 15 stud wingspan.
-- Input: ServerStorage._ModelerA.FlameRaven. Output: ServerStorage.Enemies.FlameRavenB.
local SS = game:GetService("ServerStorage")
local SRC = SS._ModelerA
local DEST = SS.Enemies


local function corners(p)
	local out, s = {}, p.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(out, (p.CFrame * CFrame.new(x * s.X, y * s.Y, z * s.Z)).Position)
			end
		end
	end
	return out
end

local function bounds(parts)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		for _, c in corners(p) do
			lo, hi = lo:Min(c), hi:Max(c)
		end
	end
	return lo, hi
end

local function visible(m)
	local t = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			table.insert(t, p)
		end
	end
	return t
end

-- All parts of a segment: the segment part itself plus details tagged Segment=<name>.
local function group(m, seg, includeTells)
	local t = {}
	for _, p in visible(m) do
		if (p.Name == seg or p:GetAttribute("Segment") == seg) and (includeTells or not p:GetAttribute("Tell")) then
			table.insert(t, p)
		end
	end
	return t
end

local function joint(m, name)
	for _, j in m:GetDescendants() do
		if j:IsA("Motor6D") and j.Name == name then
			return j, (j.Part0.CFrame * j.C0).Position
		end
	end
	error("missing joint " .. name)
end

local function attach(part, name, pos)
	assert(part, "no part for attachment " .. name)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = CFrame.new(pos)
end


local HOVER_Y = 5.0
local ROOT_W = 4.4 -- body width the hitbox covers (wings excluded)
local WING = { UpperWingL = 1, UpperWingR = 1, ForeWingL = 1, ForeWingR = 1, WingTipL = 1, WingTipR = 1 }

local m = SRC.FlameRaven
local hrp = m.HumanoidRootPart
assert(m.PrimaryPart == hrp, "HRP is not the PrimaryPart")
m:PivotTo(CFrame.new(0, HOVER_Y, 0) * m:GetPivot().Rotation)
assert(hrp.CFrame.Rotation == CFrame.new().Rotation, "HRP rotated")

for _, p in visible(m) do
	if p:GetAttribute("Tell") and p:GetAttribute("TellBase") == nil then
		p:SetAttribute("TellBase", p.Color)
	end
end

local function segOf(p)
	return p:GetAttribute("Segment") or p.Name
end
local function wingGroup(seg)
	local t = {}
	for _, p in visible(m) do
		if segOf(p) == seg then
			table.insert(t, p)
		end
	end
	return t
end

-- attachments
local _, jaw = joint(m, "JointJaw")
local headParts = {}
for _, p in visible(m) do
	if (segOf(p) == "Skull" or segOf(p) == "Jaw") and not p:GetAttribute("Tell") then
		table.insert(headParts, p)
	end
end
local hl = bounds(headParts)
attach(m.Skull, "Mouth", Vector3.new(0, jaw.Y, hl.Z + 0.1))
local bl, bh = bounds(group(m, "Body"))
attach(m.Body, "Core", (bl + bh) / 2 + Vector3.new(0, 0, -0.3))
for _, side in { "L", "R" } do
	local tl, th = bounds(wingGroup("WingTip" .. side))
	local x = if side == "L" then tl.X else th.X
	attach(m["WingTip" .. side], "WingTip" .. side .. "_FX", Vector3.new(x, (tl.Y + th.Y) / 2, (tl.Z + th.Z) / 2))
end
local talons = {}
for _, p in visible(m) do
	if segOf(p):match("^Talon") then
		table.insert(talons, p)
	end
end
local tll, tlh = bounds(talons)
attach(m.Body, "Talons_FX", Vector3.new(0, tll.Y, (tll.Z + tlh.Z) / 2))
local cl, ch = bounds(group(m, "Crest", true))
attach(m.Crest, "Crest_FX", Vector3.new(0, ch.Y, (cl.Z + ch.Z) / 2))

-- root: body-sized, Y stays (centre 5.0, size 3: bottom 3.5)
local bodyParts = {}
for _, p in visible(m) do
	if not WING[segOf(p)] then
		table.insert(bodyParts, p)
	end
end
local vl, vh = bounds(bodyParts)
local rootJ = joint(m, "JointRoot")
assert(rootJ.Part0 == hrp)
local old = hrp.CFrame
local c0World = old * rootJ.C0
local new = CFrame.new(0, old.Y, (vl.Z + vh.Z) / 2)
local saved = {}
for _, p in visible(m) do
	saved[p] = p.CFrame
end
hrp.Size = Vector3.new(ROOT_W, 3, vh.Z - vl.Z)
hrp.CFrame = new
for p, cf in saved do
	p.CFrame = cf
end
rootJ.C0 = new:ToObjectSpace(c0World)
m.WorldPivot = new

for _, p in m:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = false
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless = true
	end
end
hrp.Transparency = 1
m.PrimaryPart = hrp
m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
m.Humanoid.HipHeight = hrp.Position.Y - hrp.Size.Y / 2 -- 3.5: the Humanoid holds the hover
local top = select(2, bounds(visible(m))).Y
hrp.HealthBar.StudsOffset = Vector3.new(0, top - hrp.Position.Y + 1, 0)
m.Name = "FlameRavenB"
m.Parent = DEST
return string.format("FlameRavenB: root %s at Y %.2f, hip %.2f, top %.2f, parts %d", tostring(hrp.Size), hrp.Position.Y, m.Humanoid.HipHeight, top, #visible(m))
