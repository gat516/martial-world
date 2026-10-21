--!nocheck
-- Builder for the stylized shallow-water kit in ServerStorage.WaterKit
-- (assets/WaterKit.rbxm). Run this file through execute_luau in Edit mode; it
-- installs _G.waterKit:
--   waterKit.build(parent)        (re)builds every template under `parent` (a
--                                 staging folder, never the mapped one)
--   waterKit.dress(part)          turns any Part/Union/MeshPart into stylized water:
--                                 colour, flags, the Top-face texture layers, the
--                                 StylizedWater tag and the glimmer emitter. Copies
--                                 them from ServerStorage.WaterKit.ShallowWater when
--                                 it exists, so tuning the template retunes this.
--   waterKit.rimAlong(parent, points, closed?, width?)
--                                 lays rim foam (beam segments) along world points
--                                 on the water surface. Walk them counter-clockwise
--                                 seen from above (the bank on the right); the foam
--                                 band sits on that side. Returns the Model.
--   waterKit.rimPart(water, width?, inset?)
--                                 rim foam round a block or cylinder water part's top.
--   waterKit.surfaceFX(root?)     builds the ripple/glint zones (Shared.WaterSurface)
--                                 on every StylizedWater part under `root` (default
--                                 workspace), so the surface moves in Edit mode too.
--                                 The client rebuilds them at load anyway; rerun
--                                 after resizing a pool to see it right in Studio.
--   waterKit.rockRipples(parent, position, radius)
--                                 rings spreading from a rock standing in the water
--                                 (`position` on the surface, `radius` the rock's).
-- Tune here and rebuild, then export the staging folder with
-- tools/export_rbxm.luau as "WaterKit" (binary keeps attributes and tags).
--
-- Animation is client-side (src/client/StylizedWater.luau): parts tagged
-- StylizedWater get their Texture offsets drifted from FlowU/FlowV (studs per
-- second) and SwayU/SwayV/SwayPeriod (a slow back-and-forth) attributes on each
-- Texture. Rim and foam beams move on the GPU (TextureSpeed), no script.

local CollectionService = game:GetService("CollectionService")

local A = {
	cells = "rbxassetid://76592296498785", -- art/water/water_cells.png
	glints = "rbxassetid://124829970437644", -- art/water/water_glints.png
	depth = "rbxassetid://100444933549751", -- art/water/water_depth.png
	edge = "rbxassetid://84012692093718", -- art/water/water_edge.png
	ring = "rbxassetid://117539117669068", -- art/water/foam_ring.png
	patch = "rbxassetid://126965882365539", -- art/water/foam_patch.png
	glint = "rbxassetid://13271628051", -- library 4-point star (sun glints)
}

local NS, NK = NumberSequence.new, NumberSequenceKeypoint.new
local CS = ColorSequence.new
local NR = NumberRange.new
local function hex(h)
	return Color3.fromHex(h)
end
local function seq(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, NK(p[1], p[2], p[3] or 0))
	end
	return NS(kps)
end

-- Palette: follows the library waterfalls (Blue Waterfall: azure #0099FF body,
-- #61D5FF / #A5F0FF light, white streaks) and the reference's bright cyan.
local C = {
	water = hex("20AAE0"), -- surface base
	deep = hex("156AB6"), -- depth blotches
	foam = hex("F2FCFF"), -- foam lines, rim, splash foam
	glint = hex("CFF6FF"), -- shimmer slivers
}
_G.WaterAssets, _G.WaterColors = A, C

local function noPhysics(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = false
end

local function texture(parent, name, props, attrs)
	local t = Instance.new("Texture")
	t.Name = name
	t.Face = props.Face or Enum.NormalId.Top
	for k, v in props do
		if k ~= "Face" then
			t[k] = v
		end
	end
	for k, v in attrs or {} do
		t:SetAttribute(k, v)
	end
	t.Parent = parent
	return t
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- The surface layers. `face` is the part's upward face (Top for a block, Right
-- for a cylinder stood on its X axis).
local function layers(p, face)
	-- big soft depth blotches, very slow: breaks the tiling at a large scale
	texture(p, "Depth", {
		Face = face,
		Texture = A.depth,
		Color3 = C.deep,
		Transparency = 0.75,
		StudsPerTileU = 70,
		StudsPerTileV = 70,
		ZIndex = 1,
	}, { FlowU = 0.12, FlowV = 0.05 })
	-- the cells and foam lines: the main read, drifting downstream
	texture(p, "Cells", {
		Face = face,
		Texture = A.cells,
		Color3 = C.foam,
		Transparency = 0,
		StudsPerTileU = 22,
		StudsPerTileV = 22,
		ZIndex = 2,
	}, { FlowU = 0.35, FlowV = 0.2, SwayU = 0.35, SwayV = 0.25, SwayPeriod = 7 })
	-- shimmer slivers sliding across the cells the other way
	texture(p, "Glints", {
		Face = face,
		Texture = A.glints,
		Color3 = C.glint,
		Transparency = 0.3,
		StudsPerTileU = 15,
		StudsPerTileV = 15,
		ZIndex = 3,
	}, { FlowU = -0.5, FlowV = 0.4, SwayU = 0.6, SwayV = 0.5, SwayPeriod = 5 })
end

-- Sun glints popping on the surface. StylizedWater.luau scales Rate by the
-- part's area (GlimmerPer100 per 100 square studs), so any size works.
local function glimmer(p, face)
	local e = emitter(p, "Glimmer", {
		Texture = A.glint,
		Color = CS(C.foam),
		Size = seq({ { 0, 0 }, { 0.35, 0.55, 0.15 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.15 }, { 1, 0.4 } }),
		Lifetime = NR(0.6, 1.1),
		Rate = 4,
		Speed = NR(0, 0),
		Rotation = NR(0, 90),
		RotSpeed = NR(-30, 30),
		EmissionDirection = face,
		Shape = Enum.ParticleEmitterShape.Box,
		LightInfluence = 0.4,
		LightEmission = 0.4,
		ZOffset = 0.2,
	})
	e:SetAttribute("GlimmerPer100", 0.6)
	return e
end

local function surface(p, face)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = C.water
	-- opaque on purpose: a translucent surface is depth-sorted against the foam,
	-- glints and splash particles by part centre and hides them (seen in Studio);
	-- wading feet simply vanish under the surface, like the reference
	p.Transparency = 0
	p.Reflectance = 0
	noPhysics(p)
	if p:IsA("BasePart") and p:IsA("PartOperation") then
		p.UsePartColor = true
	end
	layers(p, face)
	glimmer(p, face)
	CollectionService:AddTag(p, "StylizedWater")
	p:SetAttribute("WaterFace", face.Name)
end

local B = {}

-- A non-FaceCamera beam faces along its attachments' Axis (local X), so the
-- attachments point X up to lay the beam flat on the water in any direction.
-- (Identity attachments only lie flat for a beam running along X.)
local FLAT = CFrame.Angles(0, 0, math.pi / 2)

-- 1. ShallowWater: a block. Resize X/Z to the pool (Y is the thickness, keep it
-- thin; the top face is the surface). Players wade through it to the pool bed.
function B.ShallowWater()
	local p = Instance.new("Part")
	p.Name = "ShallowWater"
	p.Size = Vector3.new(32, 0.4, 24)
	surface(p, Enum.NormalId.Top)
	return p
end

-- 2. ShallowWaterRound: a cylinder stood up (its X axis points up, so the
-- surface is the Right face). Size.X is the thickness, Y = Z the diameter.
function B.ShallowWaterRound()
	local p = Instance.new("Part")
	p.Name = "ShallowWaterRound"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.4, 28, 28)
	p.CFrame = CFrame.Angles(0, 0, math.pi / 2)
	surface(p, Enum.NormalId.Right)
	return p
end

-- 3. RimFoam: one straight rim segment (16 studs) to copy along a shore by
-- hand; waterKit.rimAlong/rimPart lay whole rims. Move the two attachments
-- (A0, A1) onto the shoreline, just over the water, keeping their X axis up.
-- The foam band is on the right looking from A0 to A1 (swap them to flip).
local function rimBeams(holder, a0, a1, width)
	local foam = Instance.new("Beam")
	foam.Name = "Foam"
	foam.Attachment0, foam.Attachment1 = a0, a1
	foam.Texture = A.edge
	foam.TextureMode = Enum.TextureMode.Wrap
	foam.TextureLength = width * 3
	foam.TextureSpeed = 0.04
	foam.Color = CS(C.foam)
	foam.Transparency = NS(0)
	foam.Width0, foam.Width1 = width, width
	foam.FaceCamera = false
	foam.LightInfluence = 1
	foam.LightEmission = 0
	foam.Segments = 1
	foam.ZOffset = 0
	foam.Parent = holder
	-- a thinner second band that slides the other way: the edge laps
	local lap = foam:Clone()
	lap.Name = "Lap"
	lap.TextureLength = width * 2.2
	lap.TextureSpeed = -0.06
	lap.Transparency = NS(0.55)
	lap.Width0, lap.Width1 = width * 1.25, width * 1.25
	lap.ZOffset = 0.05
	lap.Parent = holder
	return foam, lap
end
_G.WaterRimBeams = rimBeams

function B.RimFoam()
	local p = Instance.new("Part")
	p.Name = "RimFoam"
	p.Size = Vector3.new(1, 0.2, 1)
	p.Transparency = 1
	noPhysics(p)
	local a0 = Instance.new("Attachment")
	a0.Name = "A0"
	a0.CFrame = CFrame.new(-8, 0.06, 0) * FLAT
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Name = "A1"
	a1.CFrame = CFrame.new(8, 0.06, 0) * FLAT
	a1.Parent = p
	rimBeams(p, a0, a1, 2.6)
	return p
end

-- 4. WaterfallFoam: churned foam where a fall lands, on the water surface (a
-- flat invisible volume; put its bottom on the surface). Pairs with
-- ServerStorage.AmbientFX.WaterfallSpray (spray puffs, splash, droplets) at the
-- same spot: map passes leave FX_FallSpray there.
function B.WaterfallFoam()
	local p = Instance.new("Part")
	p.Name = "WaterfallFoam"
	p.Size = Vector3.new(10, 0.2, 10)
	p.Transparency = 1
	noPhysics(p)
	local d = Instance.new("Decal")
	d.Name = "Patch"
	d.Face = Enum.NormalId.Top
	d.Texture = A.patch
	d.Color3 = C.foam
	d.Transparency = 0.05
	d.ZIndex = 2
	d.Parent = p
	emitter(p, "Churn", {
		Texture = A.patch,
		Color = CS(C.foam),
		Size = seq({ { 0, 1.2 }, { 0.3, 2.4, 0.3 }, { 1, 3.2, 0.4 } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.05 }, { 0.65, 0.2 }, { 1, 1 } }),
		Lifetime = NR(1.4, 2),
		Rate = 3,
		Speed = NR(0.01, 0.01),
		Rotation = NR(0, 360),
		RotSpeed = NR(-25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Shape = Enum.ParticleEmitterShape.Box,
		LightInfluence = 0.8,
		LightEmission = 0.1,
		ZOffset = 0.1,
	})
	emitter(p, "FoamRings", {
		Texture = A.ring,
		Color = CS(C.foam),
		Size = seq({ { 0, 1.5 }, { 1, 7.5 } }),
		-- fade late: the ring is solid for most of its spread
		Transparency = seq({ { 0, 1 }, { 0.08, 0.05 }, { 0.6, 0.25 }, { 1, 1 } }),
		Lifetime = NR(2, 2.6),
		Rate = 1.2,
		Speed = NR(0.01, 0.01),
		Rotation = NR(0, 360),
		RotSpeed = NR(-8, 8),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		LightInfluence = 0.8,
		LightEmission = 0.1,
		ZOffset = 0.05,
	})
	return p
end

-- 5. RockRipples: rings spreading from a rock or post standing in the water.
-- Put it on the surface at the rock's centre; waterKit.rockRipples sizes the
-- rings to the rock (authored for a rock of radius 2).
local function rockRippleSize(radius)
	return seq({ { 0, radius * 0.95 }, { 1, radius + 2.6 } })
end

function B.RockRipples()
	local p = Instance.new("Part")
	p.Name = "RockRipples"
	p.Size = Vector3.new(0.2, 0.1, 0.2)
	p.Transparency = 1
	noPhysics(p)
	p:SetAttribute("RockRadius", 2)
	emitter(p, "Ripples", {
		Texture = A.ring,
		Color = CS(C.foam),
		Size = rockRippleSize(2),
		Transparency = seq({ { 0, 1 }, { 0.1, 0.2 }, { 0.6, 0.5 }, { 1, 1 } }),
		Lifetime = NR(1.8, 2.4),
		Rate = 0.9,
		Speed = NR(0.01, 0.01),
		Rotation = NR(0, 360),
		RotSpeed = NR(-6, 6),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		LightInfluence = 0.8,
		LightEmission = 0.1,
		ZOffset = 0.05,
	})
	return p
end

local function build(parent)
	local order = { "ShallowWater", "ShallowWaterRound", "RimFoam", "WaterfallFoam", "RockRipples" }
	for _, name in order do
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		B[name]().Parent = parent
	end
	return order
end

-- The part's local face that points up. A union takes the rotation of its first
-- part, so a union started from an upright cylinder faces up with Right.
local function upFace(part)
	local best, bestDot = Enum.NormalId.Top, -2
	for _, n in Enum.NormalId:GetEnumItems() do
		local d = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n)).Y
		if d > bestDot then
			best, bestDot = n, d
		end
	end
	return best
end

-- Make any part (block, union, mesh) stylized water, from the template. `face`
-- defaults to whichever local face points up.
local function dress(part, face)
	face = face or upFace(part)
	local kit = game:GetService("ServerStorage"):FindFirstChild("WaterKit")
	local template = kit and kit:FindFirstChild("ShallowWater")
	for _, c in part:GetChildren() do
		if c:IsA("Texture") or (c:IsA("ParticleEmitter") and c.Name == "Glimmer") then
			c:Destroy()
		end
	end
	if not template then
		surface(part, face)
		return part
	end
	part.Material, part.Color, part.Transparency, part.Reflectance =
		template.Material, template.Color, template.Transparency, template.Reflectance
	noPhysics(part)
	if part:IsA("PartOperation") then
		part.UsePartColor = true
	end
	for _, c in template:GetChildren() do
		local copy = c:Clone()
		if copy:IsA("Texture") then
			copy.Face = face
		elseif copy:IsA("ParticleEmitter") then
			copy.EmissionDirection = face
		end
		copy.Parent = part
	end
	CollectionService:AddTag(part, "StylizedWater")
	part:SetAttribute("WaterFace", face.Name)
	return part
end

-- Rim foam along world points (just over the water surface).
local function rimAlong(parent, points, closed, width)
	width = width or 2.6
	local m = Instance.new("Model")
	m.Name = "RimFoam"
	local holder = Instance.new("Part")
	holder.Name = "Anchor"
	holder.Size = Vector3.new(1, 0.2, 1)
	holder.Transparency = 1
	noPhysics(holder)
	holder.CFrame = CFrame.new(points[1])
	holder.Parent = m
	local atts = {}
	for i, pt in points do
		local a = Instance.new("Attachment")
		a.Name = "P" .. i
		a.Parent = holder -- parent first: WorldCFrame is relative to the parent
		a.WorldCFrame = CFrame.new(pt) * FLAT
		atts[i] = a
	end
	local n = #atts
	for i = 1, (closed and n or n - 1) do
		rimBeams(holder, atts[i], atts[i % n + 1], width)
	end
	m.Parent = parent
	return m
end

-- Rim round a block or upright-cylinder water part, `inset` studs in from the edge.
local function rimPart(water, width, inset)
	width = width or 2.6
	inset = inset or width * 0.4
	local face = water:GetAttribute("WaterFace") or "Top"
	local cf, size = water.CFrame, water.Size
	local pts = {}
	if water.Shape == Enum.PartType.Cylinder then
		local top = cf * CFrame.new(size.X / 2 + 0.06, 0, 0)
		local r = size.Y / 2 - inset
		local segs = math.clamp(math.floor(2 * math.pi * r / 5), 10, 48)
		for i = 0, segs - 1 do
			local a = -i / segs * 2 * math.pi
			table.insert(pts, top.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
	else
		assert(face == "Top", "rimPart: blocks must face up")
		local hx, hz, y = size.X / 2 - inset, size.Z / 2 - inset, size.Y / 2 + 0.06
		for _, c in { { -hx, -hz }, { -hx, hz }, { hx, hz }, { hx, -hz } } do
			table.insert(pts, (cf * CFrame.new(c[1], y, c[2])).Position)
		end
	end
	return rimAlong(water.Parent, pts, true, width)
end

-- Fresh copy of ReplicatedStorage.Shared.WaterSurface (require caches the
-- first load in Edit mode, so a synced edit would otherwise go unseen).
local function surfaceModule()
	local src = game:GetService("ReplicatedStorage").Shared.WaterSurface
	return require(src:Clone())
end

local function surfaceFX(root)
	root = root or workspace
	local WS = surfaceModule()
	local n = 0
	for _, part in CollectionService:GetTagged("StylizedWater") do
		if part:IsA("BasePart") and part:IsDescendantOf(root) and WS.build(part) then
			n += 1
		end
	end
	return n
end

local function rockRipples(parent, position, radius)
	local kit = game:GetService("ServerStorage"):FindFirstChild("WaterKit")
	local p = (kit and kit:FindFirstChild("RockRipples") or B.RockRipples()):Clone()
	p.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0))
	p:SetAttribute("RockRadius", radius)
	p.Ripples.Size = rockRippleSize(radius)
	p.Parent = parent
	return p
end

_G.waterKit = { build = build, dress = dress, upFace = upFace, surfaceFX = surfaceFX, rockRipples = rockRipples, rimAlong = rimAlong, rimPart = rimPart, builders = B }
return "installed _G.waterKit"
