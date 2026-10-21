--!nocheck
-- Builder for ReplicatedStorage.WorldFX (assets/WorldFX.rbxm): the sky-scale world
-- event kit drawn by src/client/WorldFX/*. Run through execute_luau in Edit mode
-- (served by tools/receive_rbxmx.py; tools/ensure_receiver.sh):
--   local m = Instance.new("ModuleScript"); m.Source = game:GetService("HttpService"):GetAsync(
--     "http://127.0.0.1:8766/worldfx_build.luau"); require(m)
--   local staging = _G.worldfxStage.begin()     -- ReplicatedStorage._StagingWorldFX
--   _G.worldfxBuild(staging, { only = { "LightPillar" } })  -- or nil for every piece
--   _G.worldfxStage.finish()                     -- export to tools/frag/WorldFX.rbxm, destroy staging
-- then copy tools/frag/WorldFX.rbxm to assets/WorldFX.rbxm (Rojo patches the live folder).
-- Pieces (each a Model, PrimaryPart nil, identity WorldPivot at its ground point):
--   Grade        ColorCorrectionEffect cloned into Lighting by SkyGrade (pulses)
--   LightPillar  ground-to-sky pillar: Core/Body/Haze/Flow beams, rising streaks and
--                motes, a glowing puncture ring where it crosses the cloud plane
--                (PlaneOffset 1: just above Kit.planeY), a landing burst
--   SkyRift      small sky crack (treasure omen): lips, glow, nebula void per segment,
--                glint, flicker, shards, a rain of light fanning down
--   Meteor       the falling treasure: head glow, halo, sparks, a long trail
--   SkyCircle    formation array (rings on a disc's underside, ImageLabel rotation)
--   GroundCircle ground sigil on an ink disc, core glow and light, motes, twinkles,
--                petals, a low mist bank
--   CloudRing    two layers of Cloud_WispArc clones tinted through SurfaceAppearance
-- Tint attributes ("core", "color", "accent", "dark") are painted by Kit.paint.
-- Asset ids are picked for these pieces from their own references
-- (docs/reference/vfx/README.md, world events), not carried over from other effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local function id(n)
	return "rbxassetid://" .. tostring(n)
end

local A = {
	band = id(2382169232), -- soft vertical band: bright centre, soft edges (beam body)
	bands = id(9841273413), -- soft streaky bands (flowing layer)
	sliver = id(11226108137), -- thin vertical sliver (streaks)
	dot = id(9841273544), -- hard dot (flash, motes)
	star = id(3060556198), -- 4-point star glint
	lens = id(14684195806), -- horizontal lens streak
	ringSoft = id(7216854285), -- soft round ring
	ringFine = id(12362706897), -- fine lined ring (shock)
	puff = id(258128463), -- cloud puff
	glowCol = id(9841273244), -- glow column (crack glow)
	nebula = id(167063256), -- violet nebula with stars (the rift's void)
	cracks = id(301851161), -- spidery cracks (edge flicker)
	starShape = id(13366348510), -- 4-point star shape (twinkles)
	inkDisc = id(13273851652), -- black disc with a light rim (dark base)
	meander = id(16511732405), -- Chinese key / meander ring
	hexArray = id(102790439571584), -- hexagram formation array
	glyphRing = id(129093523368188), -- ring of glyphs
	ornate = id(87153714607286), -- ornate circle (ground)
	runeCircle = id(16511726823), -- rune circle (ground)
	petals = id(125936833129232), -- petal sheet (flipbook grid)
}
_G.WorldFXAssets = A

local function noPhysics(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
end

local function attrs(inst, t)
	for k, v in t or {} do
		inst:SetAttribute(k, v)
	end
	return inst
end

local function set(inst, props)
	for k, v in props or {} do
		inst[k] = v
	end
	return inst
end

local function ns(...)
	local args = { ... }
	if #args == 1 then
		return NumberSequence.new(args[1])
	end
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end

-- a constant size with a random spread (ParticleEmitter.Size is a NumberSequence)
local function nsr(a, b)
	local mid, env = (a + b) / 2, (b - a) / 2
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, mid, env), NumberSequenceKeypoint.new(1, mid, env) })
end

local function part(name, parent, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	noPhysics(p)
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = cf or CFrame.new()
	p.Parent = parent
	return p
end

local function att(name, parent, pos, a)
	local x = Instance.new("Attachment")
	x.Name = name
	x.Position = pos or Vector3.zero
	attrs(x, a)
	x.Parent = parent
	return x
end

local function beam(name, a0, a1, props, a)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.LightInfluence = 0
	b.TextureMode = Enum.TextureMode.Stretch
	set(b, props)
	attrs(b, a)
	b.Parent = a0.Parent
	return b
end

local function emitter(name, parent, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.Enabled = false
	set(e, props)
	attrs(e, a)
	e.Parent = parent
	return e
end

local function model(name, parent, a)
	local m = Instance.new("Model")
	m.Name = name
	attrs(m, a)
	m.Parent = parent
	return m
end

local function finishModel(m)
	m.WorldPivot = CFrame.new() -- upright pivot at the ground point (PrimaryPart nil)
	return m
end

local Build = {}

function Build.Grade(root)
	local g = Instance.new("ColorCorrectionEffect")
	g.Name = "Grade"
	g.Enabled = false
	g.Parent = root
	return g
end

-- Authored for the large (anomaly) size; Kit/Pillar scales widths by the def's scale.
function Build.LightPillar(root)
	local m = model("LightPillar", root, { TopWorldY = 1400 })
	local shaft = part("Shaft", m)
	local bottom = att("Bottom", shaft, Vector3.new(0, 0.5, 0))
	local top = att("Top", shaft, Vector3.new(0, 1000, 0), { WorldY = 1400 })
	local fadeTop = ns(0, 0, 0.75, 0.05, 1, 1)
	-- far: a white-hot core, a coloured body and a wide haze (the far-read test:
	-- the core carries through haze, the colour needs the sky grade's clear-up)
	beam("Core", bottom, top, { Width0 = 8, Width1 = 8, Brightness = 6, LightEmission = 1, Texture = A.band, Transparency = fadeTop, ZOffset = 3 }, { Tint = "core" })
	-- the colour layers blend rather than add: additive violet on a bright sky
	-- washes to white at a distance (far-read test), alpha-blended violet keeps its hue
	beam("Body", bottom, top, { Width0 = 50, Width1 = 44, Brightness = 1.6, LightEmission = 0.15, Texture = A.band, Transparency = ns(0, 0, 0.7, 0.15, 1, 1), ZOffset = 2 }, { Tint = "color" })
	beam("Haze", bottom, top, { Width0 = 200, Width1 = 170, Brightness = 1.2, LightEmission = 0, Texture = A.band, Transparency = ns(0, 0.1, 0.6, 0.35, 1, 1), ZOffset = 1 }, { Tint = "accent" })
	-- mid: streaky light flowing up the body
	beam("Flow", bottom, top, {
		Width0 = 30, Width1 = 26, Brightness = 4, LightEmission = 1, Texture = A.bands,
		TextureMode = Enum.TextureMode.Wrap, TextureLength = 160, TextureSpeed = 0.35,
		Transparency = ns(0, 0.45, 0.6, 0.6, 1, 1), ZOffset = 2,
	}, { Tint = "core", TintMix = 0.5 })

	-- mid: streaks shooting up and motes rising round the foot (lower 400 studs)
	local rise = part("Rise", m, Vector3.new(16, 400, 16), CFrame.new(0, 200, 0))
	emitter("Streaks", rise, {
		Texture = A.sliver, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
		Speed = NumberRange.new(70, 120), Lifetime = NumberRange.new(2, 3), Rate = 10,
		Size = ns(0, 4, 0.5, 6, 1, 2), Transparency = ns(0, 1, 0.15, 0.1, 0.8, 0.3, 1, 1),
		LightEmission = 1, Brightness = 4, SpreadAngle = Vector2.new(2, 2),
	}, { Tint = "core", TintMix = 0.6, Layer = "mid" })
	emitter("Motes", rise, {
		Texture = A.dot, EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
		Speed = NumberRange.new(10, 26), Lifetime = NumberRange.new(4, 7), Rate = 14,
		Size = ns(0, 0.6, 0.5, 1.1, 1, 0), Transparency = ns(0, 1, 0.2, 0.1, 0.8, 0.2, 1, 1),
		LightEmission = 1, Brightness = 3, SpreadAngle = Vector2.new(25, 25),
		RotSpeed = NumberRange.new(-40, 40),
	}, { Tint = "accent", TintMix = 0.8, Layer = "mid" })

	-- far: where it pierces the cloud plane, a glowing ring and tinted billows
	local puncture = part("Puncture", m, Vector3.new(30, 0.2, 30), CFrame.new(0, 441, 0))
	attrs(puncture, { PlaneOffset = 1 }) -- placed just above the cloud plane's top (Kit.planeY)
	emitter("Ring", puncture, {
		Texture = A.ringSoft, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Shape = Enum.ParticleEmitterShape.Box,
		Lifetime = NumberRange.new(6), Rate = 0.6, Size = ns(0, 50, 1, 140),
		Transparency = ns(0, 1, 0.2, 0.2, 1, 1), LightEmission = 1, Brightness = 3,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8), ZOffset = 1,
	}, { Tint = "color", Layer = "far" })
	emitter("Billow", puncture, {
		Texture = A.puff, EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
		Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(70, 70),
		Lifetime = NumberRange.new(6, 9), Rate = 3, Size = ns(0, 18, 0.5, 40, 1, 55),
		Transparency = ns(0, 1, 0.25, 0.35, 0.7, 0.5, 1, 1), LightEmission = 0.4, Brightness = 2,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10),
	}, { Tint = "accent", TintMix = 0.55, Layer = "far" })

	-- close: the landing burst (played once by the drive beat)
	local landing = part("Landing", m, Vector3.new(4, 0.2, 4), CFrame.new(0, 0.3, 0))
	emitter("Flash", landing, {
		Texture = A.dot, Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0),
		Size = ns(0, 10, 0.3, 45, 1, 60), Transparency = ns(0, 0, 0.5, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, ZOffset = 4,
	}, { Tint = "core", EmitCount = 1 })
	emitter("Glint", landing, {
		Texture = A.star, Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0),
		Size = ns(0, 6, 0.2, 40, 1, 0), Transparency = ns(0, 0, 0.7, 0.2, 1, 1),
		LightEmission = 1, Brightness = 8, ZOffset = 5,
	}, { Tint = "core", EmitCount = 1 })
	emitter("Lens", landing, {
		Texture = A.lens, Lifetime = NumberRange.new(0.6), Speed = NumberRange.new(0),
		Size = ns(0, 10, 0.2, 70, 1, 20), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, ZOffset = 5,
	}, { Tint = "color", TintMix = 0.6, EmitCount = 1 })
	emitter("Shock", landing, {
		Texture = A.ringFine, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.9), Size = ns(0, 2, 1, 70), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 4,
	}, { Tint = "color", EmitCount = 1 })
	emitter("Rays", landing, {
		Texture = A.sliver, Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(90, 160), SpreadAngle = Vector2.new(85, 85),
		Lifetime = NumberRange.new(0.35, 0.6), Size = ns(0, 3, 1, 1), Transparency = ns(0, 0, 1, 1),
		LightEmission = 1, Brightness = 5, Drag = 4,
	}, { Tint = "core", TintMix = 0.7, EmitCount = 24 })
	return finishModel(m)
end

-- The heavenly treasure's small sky rift (authored along X, 150 long, centred on the
-- origin): per segment a white-hot lip, a coloured glow and a dark nebula void
-- behind, revealed from the middle outward (attribute Seg = distance from the centre
-- in segments); a glint at the eye, edge flicker, falling shards and the rain of
-- light that fans down (Celestial Rain reference).
local RIFT_POINTS = {
	Vector3.new(-75, 4, 1), Vector3.new(-52, -6, -2), Vector3.new(-30, 7, 2), Vector3.new(-12, -3, -1),
	Vector3.new(8, 5, 1), Vector3.new(27, -8, -2), Vector3.new(48, 3, 2), Vector3.new(75, -5, 0),
}
function Build.SkyRift(root)
	local m = model("SkyRift", root, { Length = 150 })
	local rift = part("Rift", m, Vector3.new(150, 16, 6))
	local atts = {}
	for i, p in RIFT_POINTS do
		atts[i] = att("P" .. i, rift, p)
	end
	local mid = (#RIFT_POINTS - 1) / 2
	for i = 1, #RIFT_POINTS - 1 do
		local a0, a1 = atts[i], atts[i + 1]
		local seg = math.abs((i - 0.5) - mid)
		beam("Void" .. i, a0, a1, { Width0 = 16, Width1 = 16, Brightness = 1, LightEmission = 0, Texture = A.nebula, Transparency = ns(0.15), ZOffset = 0 }, { Tint = "dark", TintMix = 0.6, Seg = seg, Role = "void" })
		beam("Glow" .. i, a0, a1, { Width0 = 14, Width1 = 14, Brightness = 5, LightEmission = 1, Texture = A.glowCol, Transparency = ns(0.1), ZOffset = 1 }, { Tint = "color", Seg = seg, Role = "glow" })
		beam("Lip" .. i, a0, a1, { Width0 = 3, Width1 = 3, Brightness = 10, LightEmission = 1, Texture = A.band, Transparency = ns(0), ZOffset = 2 }, { Tint = "core", Seg = seg, Role = "lip" })
	end
	local eye = att("Eye", rift, Vector3.zero)
	emitter("Glint", eye, {
		Texture = A.star, Lifetime = NumberRange.new(1.2), Speed = NumberRange.new(0),
		Size = ns(0, 4, 0.25, 50, 1, 0), Transparency = ns(0, 0, 0.7, 0.1, 1, 1),
		LightEmission = 1, Brightness = 10, ZOffset = 4, Rotation = NumberRange.new(0),
	}, { Tint = "core", EmitCount = 1 })
	emitter("Lens", eye, {
		Texture = A.lens, Lifetime = NumberRange.new(1.0), Speed = NumberRange.new(0),
		Size = ns(0, 10, 0.3, 120, 1, 30), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, ZOffset = 4,
	}, { Tint = "color", TintMix = 0.6, EmitCount = 1 })
	emitter("Flicker", rift, {
		Texture = A.cracks, Shape = Enum.ParticleEmitterShape.Box, Lifetime = NumberRange.new(0.12, 0.25),
		Speed = NumberRange.new(0), Rate = 6, Size = nsr(6, 14),
		Transparency = ns(0, 0, 1, 1), Rotation = NumberRange.new(0, 360), LightEmission = 1, Brightness = 6, ZOffset = 3,
	}, { Tint = "color", TintMix = 0.5, Layer = "mid" })
	emitter("Shards", rift, {
		Texture = A.sliver, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom,
		Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(10, 25), Acceleration = Vector3.new(0, -20, 0),
		Rate = 5, Size = nsr(1.5, 3), RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360),
		Transparency = ns(0, 0, 0.7, 0.2, 1, 1), LightEmission = 1, Brightness = 4, SpreadAngle = Vector2.new(30, 30),
	}, { Tint = "core", TintMix = 0.6, Layer = "mid" })
	emitter("Rain", rift, {
		Texture = A.sliver, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(140, 230), Acceleration = Vector3.new(0, -50, 0),
		Rate = 3, Size = ns(0, 3, 1, 1.5), SpreadAngle = Vector2.new(35, 35),
		Transparency = ns(0, 0, 0.8, 0.2, 1, 1), LightEmission = 1, Brightness = 5,
	}, { Tint = "color", TintMix = 0.7, EmitCount = 24, Layer = "mid" })
	return finishModel(m)
end

-- The falling treasure: a blazing head with a long trail (Celestial Rain's star
-- falling); TreasureFX moves the Head along its arc.
function Build.Meteor(root)
	local m = model("Meteor", root)
	local head = part("Head", m, Vector3.new(2, 2, 2))
	local t0 = att("T0", head, Vector3.new(-5, 0, 0))
	local t1 = att("T1", head, Vector3.new(5, 0, 0))
	local trail = Instance.new("Trail")
	trail.Name = "Tail"
	trail.Attachment0, trail.Attachment1 = t0, t1
	trail.FaceCamera = true
	trail.Lifetime = 1.4
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = 6
	trail.Texture = A.band
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.WidthScale = ns(0, 1, 1, 0.05)
	trail.Transparency = ns(0, 0, 0.6, 0.4, 1, 1)
	trail.MinLength = 0.5
	trail.Enabled = false
	attrs(trail, { Tint = "color", TintMix = 0.8 })
	trail.Parent = head
	local core = att("Core", head, Vector3.zero)
	emitter("Glow", core, {
		Texture = A.dot, Lifetime = NumberRange.new(0.25), Rate = 40, Speed = NumberRange.new(0),
		Size = nsr(9, 12), Transparency = ns(0, 0.1, 1, 1), LightEmission = 1, Brightness = 8,
		LockedToPart = true, ZOffset = 3,
	}, { Tint = "core" })
	emitter("Halo", core, {
		Texture = A.star, Lifetime = NumberRange.new(0.3), Rate = 12, Speed = NumberRange.new(0),
		Size = nsr(18, 26), Transparency = ns(0, 0.3, 1, 1), LightEmission = 1, Brightness = 6,
		LockedToPart = true, Rotation = NumberRange.new(0, 360), ZOffset = 3,
	}, { Tint = "color", TintMix = 0.6 })
	emitter("Sparks", core, {
		Texture = A.dot, Lifetime = NumberRange.new(0.8, 1.4), Rate = 50, Speed = NumberRange.new(4, 14),
		SpreadAngle = Vector2.new(180, 180), Size = ns(0, 0.9, 1, 0), Transparency = ns(0, 0, 1, 1),
		LightEmission = 1, Brightness = 5, Drag = 2,
	}, { Tint = "accent", TintMix = 0.8 })
	return finishModel(m)
end

local function ringImage(name, gui, image, scale, speed, transparency, tint, mix)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(scale, scale)
	img.Image = image
	img.ImageTransparency = transparency or 0
	attrs(img, { Speed = speed or 0, Tint = tint or "color", TintMix = mix or 1, Scale = scale })
	img.Parent = gui
	return img
end

local function surface(name, part, face, brightness)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1024, 1024)
	gui.LightInfluence = 0
	gui.Brightness = brightness or 3
	gui.ClipsDescendants = true
	gui.Parent = part
	return gui
end

-- Formation array overhead: rings turning against each other on the underside of
-- a flat disc (seen from below: the valley and the peaks). TreasureFX sets the disc
-- size (Radius attribute is the authored radius) and turns the ImageLabels by Speed.
function Build.SkyCircle(root)
	local m = model("SkyCircle", root, { Radius = 150 })
	local disc = part("Disc", m, Vector3.new(300, 0.2, 300))
	local gui = surface("Gui", disc, Enum.NormalId.Bottom, 3)
	ringImage("Dark", gui, A.inkDisc, 1, 0, 0.5, "dark", 1)
	ringImage("Ring1", gui, A.meander, 0.98, 5, 0, "color", 1)
	ringImage("Ring2", gui, A.hexArray, 0.72, -9, 0, "core", 0.6)
	ringImage("Ring3", gui, A.glyphRing, 0.5, 14, 0, "color", 0.8)
	ringImage("Star", gui, A.star, 0.25, -20, 0, "core", 0.3)
	return finishModel(m)
end

-- Where the treasure lands: a turning sigil on an ink disc (dark under light), a
-- glowing core for the treasure, motes, twinkles and petals.
function Build.GroundCircle(root)
	local m = model("GroundCircle", root, { Radius = 30 })
	local disc = part("Disc", m, Vector3.new(60, 0.2, 60), CFrame.new(0, 0.25, 0))
	local gui = surface("Gui", disc, Enum.NormalId.Top, 2.5)
	ringImage("Dark", gui, A.inkDisc, 1, 0, 0.3, "dark", 1)
	ringImage("Ring1", gui, A.ornate, 0.96, 4, 0, "color", 1)
	ringImage("Ring2", gui, A.runeCircle, 0.66, -7, 0, "core", 0.7)
	local field = part("Field", m, Vector3.new(56, 2, 56), CFrame.new(0, 1.5, 0))
	emitter("Motes", field, {
		Texture = A.dot, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(2, 6), Rate = 10,
		Size = ns(0, 0.3, 0.5, 0.7, 1, 0), Transparency = ns(0, 1, 0.2, 0.1, 0.8, 0.2, 1, 1),
		LightEmission = 1, Brightness = 4, SpreadAngle = Vector2.new(20, 20),
	}, { Tint = "accent", TintMix = 0.8, Layer = "close" })
	emitter("Twinkles", field, {
		Texture = A.starShape, Shape = Enum.ParticleEmitterShape.Box, Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(0.5, 2), Rate = 8, Size = ns(0, 0, 0.5, 1.2, 1, 0),
		Transparency = ns(0, 0, 1, 0.3), LightEmission = 1, Brightness = 6, Rotation = NumberRange.new(0, 90),
	}, { Tint = "core", Layer = "close" })
	emitter("Petals", field, {
		Texture = A.petals, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.Random,
		Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(1, 3), Acceleration = Vector3.new(0.5, 0.6, 0), Rate = 4,
		Size = nsr(0.5, 0.9), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
		Transparency = ns(0, 1, 0.15, 0.1, 0.85, 0.2, 1, 1), LightEmission = 0.3, Brightness = 2,
	}, { Tint = "color", TintMix = 0.5, Layer = "close" })
	local core = part("Core", m, Vector3.new(1, 1, 1), CFrame.new(0, 4, 0))
	emitter("Halo", core, {
		Texture = A.ringSoft, Lifetime = NumberRange.new(2.5), Rate = 1.2, Speed = NumberRange.new(0),
		Size = ns(0, 3, 1, 9), Transparency = ns(0, 1, 0.3, 0.3, 1, 1), LightEmission = 1, Brightness = 4,
		LockedToPart = true, ZOffset = 1,
	}, { Tint = "color", Layer = "close" })
	emitter("Flare", core, {
		Texture = A.star, Lifetime = NumberRange.new(1.6), Rate = 1.4, Speed = NumberRange.new(0),
		Size = ns(0, 2, 0.5, 6, 1, 2), Transparency = ns(0, 1, 0.3, 0.1, 1, 1), LightEmission = 1, Brightness = 8,
		LockedToPart = true, Rotation = NumberRange.new(-10, 10), ZOffset = 2,
	}, { Tint = "core", Layer = "close" })
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Range = 26
	light.Brightness = 0
	light.Shadows = false
	attrs(light, { Tint = "color", Brightness = 2.5 })
	light.Parent = core
	-- a low bank of mist hugging the circle (the Xianwu violet mist; dark tint
	-- underneath so it reads by day)
	local mist = part("Mist", m, Vector3.new(100, 4, 100), CFrame.new(0, 3, 0))
	emitter("Bank", mist, {
		Texture = A.puff, Shape = Enum.ParticleEmitterShape.Box, Lifetime = NumberRange.new(9, 13),
		Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 10), Rate = 3.5,
		Size = ns(0, 10, 0.4, 20, 1, 24), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, 6),
		Transparency = ns(0, 1, 0.3, 0.55, 0.7, 0.6, 1, 1), LightEmission = 0.25, Brightness = 1.5,
	}, { Tint = "accent", TintMix = 0.7, Layer = "close" })
	emitter("Under", mist, {
		Texture = A.puff, Shape = Enum.ParticleEmitterShape.Box, Lifetime = NumberRange.new(10, 14),
		Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 5), Rate = 1.5,
		Size = ns(0, 12, 0.5, 22, 1, 26), Rotation = NumberRange.new(0, 360),
		Transparency = ns(0, 1, 0.3, 0.75, 0.7, 0.8, 1, 1), LightEmission = 0, Brightness = 1,
	}, { Tint = "dark", Layer = "close" })
	return finishModel(m)
end

-- Two layers of the user's wisp arcs (ServerStorage.CloudKit.Cloud_WispArc, the
-- mesh of Map.Clouds.Wisps) circling the spot, tinted through a SurfaceAppearance
-- that keeps the cloud ramp texture, each with a puff of coloured mist.
local WISP = { size = Vector3.new(300.934, 32.023, 153.091), circle = Vector3.new(1.753, 0, -86.207), radius = 130 }
local function arc(parent, r, y, deg, roll)
	local s = r / WISP.radius
	local size = WISP.size * s
	local cc = WISP.circle * s
	local a = math.rad(deg)
	local p = game:GetService("ServerStorage").CloudKit.Cloud_WispArc:Clone()
	p.Name = "Arc"
	p.Size = size
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(roll or 0)) * CFrame.new(-cc)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Fabric
	p.Color = Color3.new(1, 1, 1)
	local sa = Instance.new("SurfaceAppearance")
	sa.ColorMap = p.TextureID
	sa.AlphaMode = Enum.AlphaMode.TintMask -- Color only tints through the alpha mask
	attrs(sa, { Tint = "color", TintMix = 0.55 })
	sa.Parent = p
	p.TextureID = ""
	local mistAt = att("Mist", p, cc + Vector3.new(0, 0, r))
	emitter("Puff", mistAt, {
		Texture = A.puff, Lifetime = NumberRange.new(6, 9), Rate = 0.5, Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 30), Size = ns(0, 14 * s * 1.6, 1, 26 * s * 1.6),
		Transparency = ns(0, 1, 0.3, 0.45, 1, 1), LightEmission = 0.5, Brightness = 2, Rotation = NumberRange.new(0, 360),
	}, { Tint = "accent", TintMix = 0.8, Layer = "mid" })
	p.Parent = parent
	return p
end
function Build.CloudRing(root)
	local m = model("CloudRing", root)
	local inner = model("Inner", m, { Speed = 9, Bob = 4, BobPeriod = 9, Phase = 0 })
	for i = 0, 2 do
		arc(inner, 70, 70, i * 120 + 10, 4)
	end
	local outer = model("Outer", m, { Speed = -6, Bob = 6, BobPeriod = 11, Phase = 2 })
	for i = 0, 2 do
		arc(outer, 100, 130, i * 120 + 70, -5)
	end
	return finishModel(m)
end

local ORDER = { "Grade", "LightPillar", "SkyRift", "Meteor", "SkyCircle", "GroundCircle", "CloudRing" }

_G.worldfxBuild = function(root, opts)
	opts = opts or {}
	local only = opts.only and {} or nil
	for _, n in opts.only or {} do
		only[n] = true
	end
	for _, name in ORDER do
		if not only or only[name] then
			local old = root:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			Build[name](root)
		end
	end
	return root
end

-- Staging (AGENTS.md "Studio instances"): never edit the Rojo-managed folder in place.
local Stage = {}
local NAME = "_StagingWorldFX"

function Stage.begin()
	assert(not ReplicatedStorage:FindFirstChild(NAME), "a _StagingWorldFX exists already: finish or destroy it first")
	local live = ReplicatedStorage:FindFirstChild("WorldFX")
	local staging
	if live then
		staging = live:Clone()
	else
		staging = Instance.new("Folder")
	end
	staging.Name = NAME
	staging.Parent = ReplicatedStorage
	return staging
end

function Stage.finish()
	local staging = ReplicatedStorage:FindFirstChild(NAME)
	assert(staging, "no staging copy")
	if not _G.exportRbxm then
		local m = Instance.new("ModuleScript")
		m.Source = HttpService:GetAsync("http://127.0.0.1:8766/export_rbxm.luau")
		require(m)
	end
	HttpService:PostAsync("http://127.0.0.1:8766/WorldFX.rbxm", _G.exportRbxm("ReplicatedStorage." .. NAME, "WorldFX"))
	staging:Destroy()
	return "exported tools/frag/WorldFX.rbxm; copy it to assets/WorldFX.rbxm"
end

-- After copying the file: does the live folder hold exactly one copy with these pieces?
function Stage.synced(names)
	local copies = 0
	for _, c in ReplicatedStorage:GetChildren() do
		if c.Name == "WorldFX" then
			copies += 1
		end
	end
	local live = ReplicatedStorage:FindFirstChild("WorldFX")
	local missing = {}
	for _, n in names or ORDER do
		if not (live and live:FindFirstChild(n)) then
			table.insert(missing, n)
		end
	end
	return copies, missing
end

_G.worldfxStage = Stage
return true
