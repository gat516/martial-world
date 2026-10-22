--!nocheck
-- Brings the user's reference bodies (testbed Studio, workspace.Folder.Model) into
-- ServerStorage.Enemies as template-ready rigs: StoneTortoise_R -> StoneTortoiseB (1.76x),
-- ShadowManeWolf -> ShadowManeWolfB (1.63x), VenomSerpent -> VenomSerpentB (1.40x).
-- The look is untouched. This only: stands the feet on Y 0 with the pivot on the
-- HumanoidRootPart (identity rotation), grows the root to the body's bounds (recentred in
-- X/Z, JointRoot's C0 compensated), renames/adds Tell parts, adds the FX attachments,
-- re-aims the HealthBar 1 stud over the top, and makes every part unanchored/massless/
-- non-colliding. Run in a sandbox, in Edit mode, after the three source models have been
-- deserialised into ServerStorage._ModelerA (see the commit message for how they got there).
-- Input: ServerStorage._ModelerA.{StoneTortoise_R, ShadowManeWolf, VenomSerpent}.
-- Output: the three B templates in ServerStorage.Enemies; returns the joint/size report.

local SS = game:GetService("ServerStorage")
local SRC = SS._ModelerA
local DEST = SS.Enemies

local CFG = {
	StoneTortoise_R = { name = "StoneTortoiseB", scale = 1.76 },
	ShadowManeWolf = { name = "ShadowManeWolfB", scale = 1.63 },
	VenomSerpent = { name = "VenomSerpentB", scale = 1.40 },
}

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

local function tellBand(m, seg, name, onPart, size, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = onPart.CFrame * CFrame.new(offset)
	p.Material = Enum.Material.Neon
	p.Color = m.EyeL.Color
	p:SetAttribute("Segment", seg)
	p:SetAttribute("Tell", true)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = p, onPart
	w.Parent = p
	p.Parent = m
	return p
end

local report = {}
local function log(...)
	table.insert(report, string.format(...))
end

for srcName, cfg in CFG do
	local m = SRC[srcName]
	local hrp = m.HumanoidRootPart
	assert(m.PrimaryPart == hrp, "HRP is not the PrimaryPart")

	-- 1. ground: feet on Y 0, pivot on the root at (0, h, 0)
	local lo = bounds(visible(m))
	local h = hrp.Position.Y - lo.Y
	m:PivotTo(CFrame.new(0, h, 0) * m:GetPivot().Rotation)
	assert(hrp.CFrame.Rotation == CFrame.new().Rotation, "HRP rotated")

	-- 2. Tell parts
	if srcName == "StoneTortoise_R" then
		for _, p in visible(m) do
			if p:GetAttribute("Tell") and p.Name:match("^Seam") then
				p.Name = "SeamTell" .. p.Name:sub(5)
			elseif p:GetAttribute("Tell") and p.Name:match("^Crack") then
				p.Name = "SeamTell" .. p.Name
			end
		end
	elseif srcName == "ShadowManeWolf" then
		local manes = { m.Mane1, m.Mane, m.Mane3 }
		for i, w in manes do
			tellBand(m, "Mane", "ManeTell" .. i, w, Vector3.new(w.Size.X + 0.07, 0.16, w.Size.Z * 0.55), Vector3.new(0, 0.1, 0))
		end
		tellBand(m, "TailTip", "TailBrushTell", m.Brush, Vector3.new(m.Brush.Size.X + 0.07, 0.16, m.Brush.Size.Z * 0.5), Vector3.new(0, 0.1, 0))
	end
	for _, p in visible(m) do
		if p:GetAttribute("Tell") and p:GetAttribute("TellBase") == nil then
			p:SetAttribute("TellBase", p.Color)
		end
	end

	-- 3. FX attachments
	local function gb(seg)
		return bounds(group(m, seg))
	end
	if srcName == "StoneTortoise_R" then
		local _, jaw = joint(m, "JointJaw")
		local hl = gb("Head")
		attach(m.Head, "Mouth", Vector3.new(0, jaw.Y, hl.Z + 0.15))
		local sl, sh = gb("Shell")
		attach(m.Shell, "Core", (sl + sh) / 2)
		for _, f in { "FL", "FR", "BL", "BR" } do
			local p = m["Foot" .. f]
			attach(p, "Foot" .. f .. "_FX", Vector3.new(p.Position.X, 0, p.Position.Z))
		end
		local _, neck = joint(m, "JointNeck")
		attach(m.Shell, "NeckBase_FX", Vector3.new(0, neck.Y, sl.Z + 0.1))
	elseif srcName == "ShadowManeWolf" then
		local _, jaw = joint(m, "JointJaw")
		local kl = gb("Skull")
		attach(m.Skull, "Mouth", Vector3.new(0, jaw.Y, kl.Z + 0.15))
		local cl, ch = gb("Chest")
		attach(m.Chest, "Core", (cl + ch) / 2)
		for _, f in { "FL", "FR", "BL", "BR" } do
			local p = m["Paw" .. f]
			attach(p, "Paw" .. f .. "_FX", Vector3.new(p.Position.X, 0, p.Position.Z))
		end
		local ml, mh = bounds(group(m, "Mane", true))
		attach(m.Mane, "ManeTop_FX", Vector3.new(0, mh.Y, (ml.Z + mh.Z) / 2))
	else
		local _, jaw = joint(m, "JointJaw")
		local kl = gb("Skull")
		attach(m.Skull, "Mouth", Vector3.new(0, jaw.Y, kl.Z + 0.15))
		attach(m.VenomSacL, "SacL_FX", m.VenomSacL.Position)
		attach(m.VenomSacR, "SacR_FX", m.VenomSacR.Position)
		local _, p5 = joint(m, "JointTail5")
		local far, best = nil, -1
		for _, c in corners(m.Tail5) do
			if (c - p5).Magnitude > best then
				far, best = c, (c - p5).Magnitude
			end
		end
		attach(m.Tail5, "TailTip_FX", far)
	end

	-- 4. root: grow to the body's bounds, recentre in X/Z, keep Y (the root height)
	local vl, vh = bounds(visible(m))
	local old = hrp.CFrame
	local rootJ = joint(m, "JointRoot")
	assert(rootJ.Part0 == hrp)
	local c0World = old * rootJ.C0
	local new = CFrame.new((vl.X + vh.X) / 2, old.Y, (vl.Z + vh.Z) / 2)
	hrp.Size = Vector3.new(vh.X - vl.X, 2 * math.min(h, vh.Y - h), vh.Z - vl.Z) -- stays inside the body's height
	local saved = {}
	for _, p in visible(m) do
		saved[p] = p.CFrame
	end
	hrp.CFrame = new
	for p, cf in saved do
		p.CFrame = cf -- the body stays put; only the root moved
	end
	rootJ.C0 = new:ToObjectSpace(c0World)
	m.WorldPivot = new

	-- 5. part hygiene
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
	m:SetAttribute("Scale", cfg.scale)

	-- 6. health bar 1 stud over the (final) top
	local top = select(2, bounds(visible(m))).Y
	local hb = hrp.HealthBar
	hb.StudsOffset = Vector3.new(0, top - hrp.Position.Y + 1, 0)

	m.Name = cfg.name
	m.Parent = DEST
	log("%s: root %s at Y %.3f, top %.2f, parts %d", cfg.name, tostring(hrp.Size), hrp.Position.Y, top, #visible(m))
end
return table.concat(report, "\n")
