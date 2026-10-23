--!nocheck
-- Builder for ReplicatedStorage.Effects.Guide, the onboarding guide's world
-- visuals, placed and played by src/client/Guide.luau (`place` guides).
-- Run through execute_luau in Edit mode (served by tools/receive_rbxmx.py):
--   local m = Instance.new("ModuleScript"); m.Source = HttpService:GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/Guide.luau"); require(m)
--   _G.buildGuide(parent)   -- replaces parent.Guide
--
-- Intent: the sect's qi shows a newcomer the way. A thin stream of jade qi
-- runs along the ground from the player's feet toward the target with a few
-- spirit motes drifting ahead on it; at the target a slow formation circle of
-- pale gold turns on the ground under a faint column of light that reads
-- from across the plaza; reaching it, the formation flares once and lets go
-- (gameplay job: telegraph "walk here", then confirm "you're here"). Calm:
-- nothing flashes the screen, nothing pulses loudly, motion is slow drift.
--
-- Layout:
--   Stream  Beam (template, flat on the ground: the attachments' Y axis is the
--           beam's width, so Guide.luau orients each one with Y sideways).
--           Hero of the path. A qi strand texture scrolling from Attachment0
--           (the player's end) to Attachment1 (TextureSpeed > 0 runs that way).
--           Guide.luau chains one copy per 4-stud ground segment and sets each
--           copy's Transparency (fade-in at the feet, fade-out at the end).
--           Segments must be > 1 or a per-copy Transparency ramp can't show.
--   Bed     the same shape wider, ink-slate and unlit, under the stream so it
--           reads on grass at noon (dark under light).
--   Drift   Attachment + Motes: spirit motes left behind by an attachment
--           Guide.luau runs along the path ahead of the player, on a loop.
--   Marker  Model, pivot = the ground point (identity rotation). Circle: a flat
--           carrier part (invisible, no query) whose SurfaceGui (Top) holds
--           Outer (rune ring with eight spokes, the hero) and Inner (a fret
--           ring, counter-turning); Guide.luau turns the two ImageLabels.
--           Column: a camera-facing Beam Base -> Top (Top raised to Height),
--           the far-distance read. Motes: a few rising from the circle.
--           Attribute Radius: the radius the circle was authored at.
--   Arrive  Model, pivot = the ground point. A one-shot flourish on arrival:
--           Seal (the formation flaring and lifting off, hero, frame 1),
--           Ring (a soft ring of light running out over the ground, +60 ms),
--           Motes (released upward, +120 ms). Emit attributes, so the plugin's
--           Emit button plays it. Attribute Radius as above; Guide.luau scales
--           Seal and Ring sizes by radius / Radius.

local HttpService = game:GetService("HttpService")

local function id(n)
	return "rbxassetid://" .. n
end

local A = {
	stream = id(16892453445), -- qi strands, drawn vertically (beam length)
	bed = id(16288356764), -- soft band, drawn vertically
	mote = id(6673021984), -- soft dot with a hot centre
	outer = id(101325137377720), -- rune ring with eight spokes
	inner = id(93858335764593), -- fret (meander) ring
	column = id(16288356764), -- soft band, for the light column
	ring = id(16878073342), -- soft ring of light with brighter arcs
}

local JADE = Color3.fromRGB(176, 255, 214)
local JADE_DEEP = Color3.fromRGB(70, 214, 160)
local GOLD = Color3.fromRGB(255, 226, 150)
local WARM = Color3.fromRGB(255, 244, 214)
local INK = Color3.fromRGB(18, 34, 30)

local RADIUS = 5 -- authored circle radius (studs)
local HEIGHT = 16 -- authored column height

local function seq(...)
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function cseq(...)
	local args = { ... }
	local keys = {}
	for i = 1, #args, 2 do
		table.insert(keys, ColorSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return ColorSequence.new(keys)
end

local function carrier(name, parent, cf, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function emitter(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	e.LockedToPart = false
	for k, v in props do
		e[k] = v
	end
	for k, v in attrs or {} do
		e:SetAttribute(k, v)
	end
	e.Parent = parent
	return e
end

local function flatBeam(name, parent, p)
	local b = Instance.new("Beam")
	b.Name = name
	b.FaceCamera = false
	b.Segments = 8
	b.CurveSize0 = 0
	b.CurveSize1 = 0
	b.TextureMode = Enum.TextureMode.Wrap
	b.Enabled = false
	for k, v in p do
		b[k] = v
	end
	b.Parent = parent
	return b
end

local function path(root)
	flatBeam("Stream", root, {
		Texture = A.stream,
		TextureLength = 4,
		TextureSpeed = 0.35,
		Width0 = 1.7,
		Width1 = 1.7,
		Color = cseq(0, JADE, 1, JADE),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 1.4,
		Transparency = NumberSequence.new(0.4),
		ZOffset = 0.1,
	})
	flatBeam("Bed", root, {
		Texture = A.bed,
		TextureLength = 4,
		TextureSpeed = 0,
		Width0 = 2.6,
		Width1 = 2.6,
		Color = ColorSequence.new(INK),
		LightEmission = 0,
		LightInfluence = 1,
		Transparency = NumberSequence.new(0.78),
		ZOffset = 0,
	})
	local drift = Instance.new("Attachment")
	drift.Name = "Drift"
	drift.Parent = root
	emitter(drift, "Motes", {
		Texture = A.mote,
		Rate = 9,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 1.2, 0),
		Drag = 1,
		Size = seq(0, 0.08, 0.25, 0.2, 1, 0),
		Transparency = seq(0, 1, 0.15, 0.1, 0.55, 0.35, 0.7, 0.1, 1, 1),
		Color = cseq(0, WARM, 1, JADE),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2,
		RotSpeed = NumberRange.new(-40, 40),
		ZOffset = 0.3,
	})
end

local function marker(root)
	local m = Instance.new("Model")
	m.Name = "Marker"
	m:SetAttribute("Radius", RADIUS)
	m:SetAttribute("Height", HEIGHT)
	m.Parent = root
	local circle = carrier("Circle", m, CFrame.new(0, 0.12, 0), Vector3.new(RADIUS * 2, 0.05, RADIUS * 2))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Formation"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 0
	gui.Brightness = 2.4
	gui.AlwaysOnTop = false
	gui.ZOffset = 0
	gui.ClipsDescendants = false
	gui.Parent = circle
	local function ring(name, image, scale, color, transparency)
		local img = Instance.new("ImageLabel")
		img.Name = name
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(scale, scale)
		img.Image = image
		img.ImageColor3 = color
		img.ImageTransparency = transparency
		img:SetAttribute("Transparency", transparency)
		img.Parent = gui
		return img
	end
	ring("Outer", A.outer, 1, GOLD, 0.15):SetAttribute("Spin", 8) -- degrees a second
	ring("Inner", A.inner, 0.56, JADE, 0.4):SetAttribute("Spin", -13)

	local base = Instance.new("Attachment")
	base.Name = "Base"
	base.Position = Vector3.new(0, 0.1, 0)
	base.Parent = circle
	local top = Instance.new("Attachment")
	top.Name = "Top"
	top.Position = Vector3.new(0, HEIGHT, 0)
	top.Parent = circle
	local column = Instance.new("Beam")
	column.Name = "Column"
	column.Attachment0 = base
	column.Attachment1 = top
	column.FaceCamera = true
	column.Segments = 10
	column.Texture = A.column
	column.TextureMode = Enum.TextureMode.Stretch
	column.TextureSpeed = 0
	column.Width0 = 2.6
	column.Width1 = 1.4
	column.Color = cseq(0, WARM, 1, GOLD)
	column.LightEmission = 1
	column.LightInfluence = 0
	column.Brightness = 1.2
	column.Transparency = seq(0, 0.55, 0.35, 0.72, 1, 1)
	column.Parent = circle

	emitter(circle, "Motes", {
		Texture = A.mote,
		Rate = 3.5,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(2.4, 3.4),
		Speed = NumberRange.new(1.4, 2.4),
		SpreadAngle = Vector2.new(8, 8),
		Drag = 0.4,
		Size = seq(0, 0.1, 0.2, 0.22, 1, 0.04),
		Transparency = seq(0, 1, 0.15, 0.15, 0.5, 0.45, 0.65, 0.15, 1, 1),
		Color = cseq(0, WARM, 1, GOLD),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2,
		ZOffset = 0.3,
	})
	m.WorldPivot = CFrame.identity
end

local function arrive(root)
	local m = Instance.new("Model")
	m.Name = "Arrive"
	m:SetAttribute("Radius", RADIUS)
	m.Parent = root
	local holder = carrier("Holder", m, CFrame.new(0, 0.2, 0), Vector3.new(0.2, 0.2, 0.2))
	local at = Instance.new("Attachment")
	at.Name = "At"
	at.Parent = holder
	-- a particle's Size is its half-width: Size = RADIUS covers the circle
	local r = RADIUS
	-- flat particles: velocity up, VelocityPerpendicular, almost no speed
	local flat = {
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01),
		SpreadAngle = Vector2.zero,
		LightEmission = 1,
		LightInfluence = 0,
	}
	local function with(t)
		local out = table.clone(flat)
		for k, v in t do
			out[k] = v
		end
		return out
	end
	-- hero: the formation flares on frame 1 (full size, brightest), lifts and lets go
	emitter(at, "Seal", with({
		Texture = A.outer,
		Lifetime = NumberRange.new(0.75),
		Size = seq(0, r * 1.0, 0.25, r * 1.1, 1, r * 1.25),
		Transparency = seq(0, 0.05, 0.12, 0.15, 0.5, 0.55, 1, 1),
		Color = cseq(0, WARM, 1, GOLD),
		Brightness = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(25),
		Speed = NumberRange.new(0.6),
		Drag = 2,
		ZOffset = 0.2,
	}), { EmitCount = 1 })
	-- secondary: a soft ring of light running out over the ground
	emitter(at, "Ring", with({
		Texture = A.ring,
		Lifetime = NumberRange.new(0.7),
		Size = seq(0, r * 1.35, 0.3, r * 2.3, 1, r * 2.8), -- the ring art fills ~70% of its image
		Transparency = seq(0, 0.2, 0.4, 0.45, 1, 1),
		Color = cseq(0, WARM, 1, JADE),
		Brightness = 2,
		Rotation = NumberRange.new(0, 360),
		ZOffset = 0.1,
	}), { EmitCount = 1, EmitDelay = 0.06 })
	-- tertiary: motes released upward off the formation's rim, shooting out and
	-- hanging (Rim is circle-sized: Guide.luau scales it with the radius)
	local rim = carrier("Rim", m, CFrame.new(0, 0.2, 0), Vector3.new(r * 2, 0.05, r * 2))
	emitter(rim, "Motes", {
		Texture = A.mote,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(7, 11),
		SpreadAngle = Vector2.new(35, 35),
		Drag = 3,
		Acceleration = Vector3.new(0, 0.6, 0),
		Size = seq(0, 0.2, 0.2, 0.28, 1, 0),
		Transparency = seq(0, 0, 0.5, 0.2, 0.8, 0.5, 1, 1),
		Color = cseq(0, WARM, 1, GOLD),
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2.5,
		ZOffset = 0.3,
	}, { EmitCount = 12, EmitDelay = 0.12 })
	m.WorldPivot = CFrame.identity
end

function _G.buildGuide(parent)
	local old = parent:FindFirstChild("Guide")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Guide"
	path(root)
	marker(root)
	arrive(root)
	root.Parent = parent
	return root
end

_G.GuideAssets = A
return HttpService -- (anything; the builder is installed on _G)
