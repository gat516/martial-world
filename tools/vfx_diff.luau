--!nocheck
-- Structural diff of effect templates, for refactors that must not change what
-- plays (e.g. rebuilding templates from a spec). Run through execute_luau; it
-- installs _G.vfxDiff:
--   local snap = vfxDiff.snapshot(root)       -- { [path] = "Class|prop=value|...|@attr=...|#tag" }
--   vfxDiff.compare(snapA, snapB) -> string   -- "no differences", or one line per difference
-- Paths are names from the root (siblings with the same name get #2, #3...).
-- Every property that changes how an effect looks or times is compared; part
-- placement is relative to the root's pivot, rounded to 1/1000 stud.

local Diff = {}

local PROPS = {
	ParticleEmitter = {
		"Texture", "Color", "Size", "Transparency", "Lifetime", "Speed", "SpreadAngle", "Rotation", "RotSpeed",
		"Acceleration", "Drag", "LightEmission", "LightInfluence", "Brightness", "ZOffset", "Orientation",
		"EmissionDirection", "Shape", "ShapeInOut", "ShapeStyle", "ShapePartial", "Squash", "FlipbookLayout",
		"FlipbookMode", "FlipbookFramerate", "LockedToPart", "Rate", "Enabled", "TimeScale", "VelocityInheritance",
	},
	Trail = { "Color", "Transparency", "WidthScale", "Lifetime", "LightEmission", "LightInfluence", "FaceCamera", "Texture", "Enabled", "MinLength" },
	Beam = { "Color", "Transparency", "Width0", "Width1", "CurveSize0", "CurveSize1", "Texture", "TextureSpeed", "LightEmission", "FaceCamera", "Segments" },
	PointLight = { "Color", "Range", "Brightness", "Shadows", "Enabled" },
	Attachment = { "Position", "Orientation" },
	BasePart = { "Size", "Transparency", "Color", "Material", "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow" },
	MeshPart = { "MeshId", "TextureID" },
	Part = { "Shape" },
}

local function fmt(v)
	local t = typeof(v)
	if t == "number" then
		return string.format("%.4g", v)
	elseif t == "Vector3" then
		return string.format("%.3f,%.3f,%.3f", v.X, v.Y, v.Z)
	elseif t == "CFrame" then
		local x, y, z = v:ToEulerAnglesXYZ()
		return string.format("%.3f,%.3f,%.3f/%.3f,%.3f,%.3f", v.X, v.Y, v.Z, x, y, z)
	elseif t == "Instance" then
		return v.Name
	end
	return tostring(v)
end

local function describe(inst, root)
	local parts = { inst.ClassName }
	local lists = {}
	for class, props in PROPS do
		if inst:IsA(class) then
			table.insert(lists, props)
		end
	end
	for _, props in lists do
		for _, p in props do
			local ok, v = pcall(function()
				return inst[p]
			end)
			if ok then
				table.insert(parts, p .. "=" .. fmt(v))
			end
		end
	end
	if inst:IsA("BasePart") then
		table.insert(parts, "at=" .. fmt(root:GetPivot():ToObjectSpace(inst.CFrame)))
	end
	if inst:IsA("Trail") or inst:IsA("Beam") then
		table.insert(parts, "A0=" .. fmt(inst.Attachment0) .. " A1=" .. fmt(inst.Attachment1))
	end
	local attrs = {}
	for k, v in inst:GetAttributes() do
		table.insert(attrs, "@" .. k .. "=" .. fmt(v))
	end
	table.sort(attrs)
	for _, a in attrs do
		table.insert(parts, a)
	end
	local tags = inst:GetTags()
	table.sort(tags)
	for _, t in tags do
		table.insert(parts, "#" .. t)
	end
	return table.concat(parts, "|")
end

function Diff.snapshot(root)
	local snap = {}
	local function walk(inst, path)
		snap[path] = describe(inst, root)
		local seen = {}
		for _, child in inst:GetChildren() do
			seen[child.Name] = (seen[child.Name] or 0) + 1
			local key = child.Name .. (if seen[child.Name] > 1 then "#" .. seen[child.Name] else "")
			walk(child, path .. "/" .. key)
		end
	end
	walk(root, root.Name)
	snap[root.Name] = describe(root, root) .. "|pivot"
	return snap
end

-- Splits "A|b=1|c=2" and reports only the fields that differ.
local function fieldDiff(a, b)
	local fa, fb = {}, {}
	for f in string.gmatch(a, "[^|]+") do
		fa[f:match("^([^=]+)") or f] = f
	end
	for f in string.gmatch(b, "[^|]+") do
		fb[f:match("^([^=]+)") or f] = f
	end
	local out = {}
	for k, v in fa do
		if fb[k] ~= v then
			table.insert(out, v .. " -> " .. tostring(fb[k]))
		end
	end
	for k, v in fb do
		if fa[k] == nil then
			table.insert(out, "(none) -> " .. v)
		end
	end
	table.sort(out)
	return table.concat(out, "; ")
end

function Diff.compare(a, b)
	local out = {}
	for path, desc in a do
		if b[path] == nil then
			table.insert(out, "- " .. path)
		elseif b[path] ~= desc then
			table.insert(out, "~ " .. path .. ": " .. fieldDiff(desc, b[path]))
		end
	end
	for path in b do
		if a[path] == nil then
			table.insert(out, "+ " .. path)
		end
	end
	table.sort(out)
	return if #out == 0 then "no differences" else table.concat(out, "\n")
end

_G.vfxDiff = Diff
return "vfxDiff installed"
