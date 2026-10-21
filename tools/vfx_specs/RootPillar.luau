--!nocheck
-- Builder for ReplicatedStorage.Effects.RootPillar, the spirit root reveal at
-- the Testing Stone, played by src/client/RootFX.luau (Effect "root").
-- Run through execute_luau in Edit mode (served by tools/receive_rbxmx.py,
-- after tools/vfx_session.luau so _G.vfxBlocks exists):
--   local m = Instance.new("ModuleScript"); m.Source = HttpService:GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/RootPillar.luau"); require(m)
--   _G.buildRootPillar(staging)   -- staging = vfxStage.begin(who)
-- It replaces staging.RootPillar.
--
-- Layout (pivot = PillarOrigin, the stone's top centre, +Y up; built at the origin):
--   Pillar   the shared column, recoloured per element: Column (Neon core) and
--            Sheath (wider, softer) cylinders that RootFX grows to `Height`,
--            a camera-facing Shaft beam (A0 -> A1, A1 raised with the column),
--            and Base emitters + MeshWaves (flash, glow, rising motes, a ground
--            ring). Crown: a glow at the top.
--   Rare     extra for Lightning/Wind/Ice (and any Heaven-grade root): Ground
--            shockwave (torus + swirl ring + dust) and Sky (ball flash,
--            horizontal sky ring, star) that RootFX moves to the pillar's top.
--   Glimpse  the re-touch version: a brief glow, motes and a small ring.
--   Accents  one Model per element (Fire, Water, ...): the element's own
--            reveal in its methods' aura language (MeshWaves, emitters, baked
--            colours); RootFX clones the one it needs onto the base, scales
--            it by grade, and moves `AtHeight` pieces up the column. See the
--            Accents section for the per-element pieces and model attributes.
-- Anything with `Tint` ("color", "core" or "deep") is recoloured from the
-- element's colour (core = mixed toward white, deep = more saturated). Root attributes: Height,
-- RareHeight, Width (column studs), Rise (seconds to full height), Hold, Fade.

local AssetService = game:GetService("AssetService")

local B = _G.vfxBlocks
assert(B, "load tools/vfx_session.luau first")

local function id(n)
	return "rbxassetid://" .. n
end

local A = {
	glow = id(867619398),
	glowDot = id(9841273544),
	star4 = id(13271628051),
	star12 = id(243728206),
	column = id(1191605952), -- soft band: the image's vertical runs along a beam
	thinRing = id(9841273159),
	softRing = id(15611941586),
	dust = id(11037785287),
	torus = id(471124075),
	swirlRing = id(129778117978668),
	-- accents
	spark = id(9841260273), -- ember / streak
	bubble = id(249902641),
	leaf = id(17259245248),
	shards = id(12402863766),
	rocks = id(425665059),
	arcs = id(528280947),
	arc = id(7216850580),
	windStreak = id(426653646),
	ice = id(18765221838),
	swirlRing2 = id(73349240058321),
	crownTall = id(4316118084), -- tall spike crown (flame)
	crownLow = id(489415286), -- low spike crown
	flame = id(265788038),
	puff = id(933102662),
	crack = id(93520831389146),
	rune = id(83667248904000),
}
_G.RootPillarAssets = A

local NS, CS, KP, CK, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, ColorSequenceKeypoint.new, NumberRange.new
local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)

local function seq(...)
	local v, kps = { ... }, {}
	for i = 1, #v, 2 do
		table.insert(kps, KP(v[i], v[i + 1]))
	end
	return NS(kps)
end

-- a constant size picked at random per particle in [lo, hi]
local function rnd(lo, hi)
	local mid, env = (lo + hi) / 2, (hi - lo) / 2
	return NS({ KP(0, mid, env), KP(1, mid, env) })
end

local function cseq(...)
	local v, kps = { ... }, {}
	for i = 1, #v, 2 do
		table.insert(kps, CK(v[i], v[i + 1]))
	end
	return CS(kps)
end

local function attrs(inst, t)
	for k, v in t or {} do
		inst:SetAttribute(k, v)
	end
	return inst
end

local function model(name, parent, a)
	local m = Instance.new("Model")
	m.Name = name
	attrs(m, a)
	m.Parent = parent
	return m
end

local function part(name, parent, cf, size, a)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size or V3(0.2, 0.2, 0.2)
	p.CFrame = cf or CFrame.new()
	attrs(p, a)
	p.Parent = parent
	return p
end

-- An emitter with sane defaults (off, no light influence, fixed facing).
local function emitter(parent, name, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	e.Texture = A.glow
	for k, v in props do
		e[k] = v
	end
	attrs(e, a)
	e.Parent = parent
	return e
end

-- A Neon cylinder standing on the origin (axis = world Y), at Transparency 1:
-- RootFX sets its height, width and transparency.
local function cylinder(name, parent, width, a)
	local p = part(name, parent, CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), V3(1, width, width), a)
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	return p
end

local function wave(parent, name, p, tint)
	local w = B.meshWave(parent, name, p)
	if p.fadeStyle then
		w:SetAttribute("FadeStyle", p.fadeStyle)
	end
	if tint then
		w.Mesh:SetAttribute("Tint", tint)
	end
	return w
end

-- torus 471124075 is 150 x 9.51 x 150; a round tube is Y = D * 0.0634
local function ring(d, fat)
	return V3(d, d * 0.0634 * (fat or 1.6), d)
end

-- ------------------------------------------------------------------ Pillar

local function pillar(root)
	local m = model("Pillar", root)
	cylinder("Column", m, 3.4, { Tint = "core", Fade = 0.05 })
	cylinder("Sheath", m, 9, { Tint = "deep", Fade = 0.6 })

	local base = part("Base", m, CFrame.new(0, 0.2, 0), V3(5, 0.2, 5))
	local a0 = Instance.new("Attachment")
	a0.Name = "A0"
	a0.Parent = base
	local a1 = Instance.new("Attachment")
	a1.Name = "A1"
	a1.Position = V3(0, 120, 0)
	a1.Parent = base
	local shaft = Instance.new("Beam")
	shaft.Name = "Shaft"
	shaft.Attachment0, shaft.Attachment1 = a0, a1
	shaft.Texture = A.column
	shaft.TextureMode = Enum.TextureMode.Stretch
	shaft.TextureLength = 1
	shaft.TextureSpeed = 0.6
	shaft.FaceCamera = true
	shaft.Segments = 1
	shaft.Width0, shaft.Width1 = 24, 16
	shaft.LightEmission = 0.4
	shaft.LightInfluence = 0
	shaft.Transparency = seq(0, 0.25, 0.75, 0.35, 1, 1)
	shaft.Enabled = false
	shaft:SetAttribute("Tint", "deep")
	shaft.Parent = base

	-- the release: a bright star and glow on the stone (lifted so the stone
	-- doesn't cut the sprites in half)
	local lift = Instance.new("Attachment")
	lift.Name = "Lift"
	lift.Position = V3(0, 3, 0)
	lift.Parent = base
	emitter(lift, "Flash", {
		Texture = A.star4, Size = seq(0, 2, 0.25, 11, 1, 6), Transparency = seq(0, 0, 0.6, 0.2, 1, 1),
		Lifetime = R(0.45), LightEmission = 0.6, ZOffset = 2, Rotation = R(0, 45),
	}, { EmitCount = 1, Tint = "core" })
	emitter(lift, "Glow", {
		Texture = A.glow, Size = seq(0, 5, 0.3, 11, 1, 13), Transparency = seq(0, 0.3, 0.5, 0.45, 1, 1),
		Lifetime = R(1.4), LightEmission = 0.35, ZOffset = 1,
	}, { EmitCount = 2, Tint = "color" })
	-- motes streaming up the column for ~2 s
	emitter(base, "Motes", {
		Texture = A.glowDot, Size = seq(0, 0.9, 0.7, 0.6, 1, 0), Transparency = seq(0, 0.1, 0.8, 0.2, 1, 1),
		Lifetime = R(1.6, 2.4), Speed = R(28, 48), SpreadAngle = Vector2.new(6, 6),
		EmissionDirection = Enum.NormalId.Top, Rate = 14, LightEmission = 0.6, Drag = 0.4,
	}, { EmitDuration = 2, Tint = "core", Scaled = true })

	-- 3D: a ground ring under the stone (the element's own pieces do the rest)
	wave(base, "GroundRing", {
		mesh = A.torus, color = WHITE, fromSize = ring(6, 2), toSize = ring(30, 1.4),
		fromTransparency = 0.05, toTransparency = 1, duration = 1.1, style = "Quint", fadeStyle = "Quad",
	}, "color")

	local crown = part("Crown", m, CFrame.new(0, 120, 0), V3(1, 1, 1))
	crown:SetAttribute("Top", true) -- RootFX keeps it at the column's top
	emitter(crown, "Glow", {
		Texture = A.glow, Size = seq(0, 8, 0.3, 20, 1, 22), Transparency = seq(0, 0.15, 0.6, 0.35, 1, 1),
		Lifetime = R(1.8), LightEmission = 0.5,
	}, { EmitCount = 2, EmitDelay = 0.35, Tint = "color" })
	emitter(crown, "Star", {
		Texture = A.star12, Size = seq(0, 3, 0.3, 14, 1, 8), Transparency = seq(0, 0.1, 1, 1),
		Lifetime = R(0.6), LightEmission = 0.5, Rotation = R(0, 360), RotSpeed = R(-40, 40),
	}, { EmitCount = 1, EmitDelay = 0.4, Tint = "core" })
	return m
end

-- ------------------------------------------------------------------ Rare

local function rare(root)
	local m = model("Rare", root)
	local ground = part("Ground", m, CFrame.new(0, 0.25, 0), V3(6, 0.2, 6))
	wave(ground, "Shockwave", {
		mesh = A.torus, color = WHITE, fromSize = ring(8, 2.2), toSize = ring(80, 1.3),
		fromTransparency = 0, toTransparency = 1, duration = 1.3, style = "Quint", fadeStyle = "Quad", delay = 0.15,
	}, "deep")
	wave(ground, "Swirl", {
		mesh = A.swirlRing, color = WHITE, fromSize = V3(10, 2, 10), toSize = V3(56, 6, 56),
		fromTransparency = 0.1, toTransparency = 1, duration = 1.1, style = "Quart", fadeStyle = "Quad", delay = 0.1,
	}, "color")
	emitter(ground, "Dust", {
		Texture = A.dust, Size = seq(0, 2, 1, 6), Transparency = seq(0, 0.45, 1, 1),
		Lifetime = R(0.8, 1.2), Speed = R(30, 45), Drag = 3, Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Rotation = R(0, 360),
		Color = CS(Color3.fromRGB(235, 228, 214)),
	}, { EmitCount = 14, EmitDelay = 0.1 })
	emitter(ground, "FlatRing", B.flat({
		Texture = A.softRing, Size = seq(0, 4, 1, 40), Transparency = seq(0, 0.2, 0.6, 0.5, 1, 1),
		Lifetime = R(0.9), LightEmission = 0.4,
	}), { EmitCount = 1, EmitDelay = 0.15, Tint = "color" })

	local sky = part("Sky", m, CFrame.new(0, 200, 0), V3(1, 1, 1))
	sky:SetAttribute("Top", true)
	sky:SetAttribute("EmitDelay", 0.45) -- when the column reaches the sky
	wave(sky, "Burst", {
		mesh = "Ball", material = Enum.Material.Neon, color = WHITE, fromSize = V3(6, 6, 6), toSize = V3(40, 40, 40),
		fromTransparency = 0.4, toTransparency = 1, duration = 0.7, style = "Quart", fadeStyle = "Quad",
	}, "deep")
	wave(sky, "SkyRing", {
		mesh = A.torus, color = WHITE, fromSize = ring(14, 2.2), toSize = ring(150, 1.3),
		fromTransparency = 0, toTransparency = 1, duration = 1.6, style = "Quint", fadeStyle = "Quad",
	}, "deep")
	emitter(sky, "Star", {
		Texture = A.star4, Size = seq(0, 6, 0.25, 40, 1, 20), Transparency = seq(0, 0, 0.5, 0.3, 1, 1),
		Lifetime = R(0.7), LightEmission = 0.5, Rotation = R(0, 45),
	}, { EmitCount = 1, Tint = "core" })
	emitter(sky, "Rays", {
		Texture = A.glow, Size = seq(0, 10, 0.3, 45, 1, 50), Transparency = seq(0, 0.4, 1, 1),
		Lifetime = R(1.2), LightEmission = 0.3,
	}, { EmitCount = 1, Tint = "color" })
	return m
end

-- ------------------------------------------------------------------ Glimpse

local function glimpse(root)
	local m = model("Glimpse", root)
	local base = part("Base", m, CFrame.new(0, 0.3, 0), V3(3, 0.2, 3))
	local lift = Instance.new("Attachment")
	lift.Name = "Lift"
	lift.Position = V3(0, 2, 0)
	lift.Parent = base
	emitter(lift, "Glow", {
		Texture = A.glow, Size = seq(0, 3, 0.3, 6.5, 1, 7.5), Transparency = seq(0, 0.25, 0.5, 0.4, 1, 1),
		Lifetime = R(1.1), LightEmission = 0.4, ZOffset = 1,
	}, { EmitCount = 2, Tint = "color" })
	emitter(base, "Motes", {
		Texture = A.glowDot, Size = seq(0, 0.5, 1, 0), Transparency = seq(0, 0.1, 1, 1),
		Lifetime = R(0.9, 1.3), Speed = R(5, 10), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top, LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Box,
	}, { EmitCount = 10, Tint = "core" })
	wave(base, "Ring", {
		mesh = A.torus, color = WHITE, fromSize = ring(3, 2), toSize = ring(11, 1.4),
		fromTransparency = 0.05, toTransparency = 1, duration = 0.8, style = "Quint", fadeStyle = "Quad",
	}, "color")
	wave(base, "Rise", {
		mesh = A.torus, color = WHITE, fromSize = ring(4, 2), toSize = ring(2, 2.4),
		fromOffset = V3(0, 0.5, 0), toOffset = V3(0, 9, 0),
		fromTransparency = 0.1, toTransparency = 1, duration = 0.8, style = "Quad", fadeStyle = "Quad",
	}, "core")
	return m
end

-- ------------------------------------------------------------------ Accents
-- One Model per element, in the visual language of its methods' auras
-- (docs/systems/auras.md). Colours are baked (no Tint). Pieces with
-- `AtHeight` are moved to that fraction of the column's height by RootFX;
-- a `Bolt` Beam and an `OnBolt` model (Lightning) are played per strike.
-- Model attributes: Flicker (column flicker 0..1), Bolts, BoltGap, SkyTint,
-- SkyBrightness (the rare/Heaven sky flash).

local rgb = Color3.fromRGB

-- A MeshWave whose Mesh is a plain part: "Cylinder", "Block", "Ball" or
-- "Ellipsoid" (a Block with a Sphere SpecialMesh), in `material`.
local function shapeWave(parent, name, shape, material, color, p)
	local w = Instance.new("Model")
	w.Name = name
	for k, v in {
		FromSize = p.fromSize, ToSize = p.toSize, FromOffset = p.fromOffset, ToOffset = p.toOffset,
		Rotation = p.rotation, FromTransparency = p.fromTransparency, ToTransparency = p.toTransparency,
		Duration = p.duration, Style = p.style, FadeStyle = p.fadeStyle or "Quad", EmitDelay = p.delay,
	} do
		w:SetAttribute(k, v)
	end
	w:SetAttribute("MeshWave", true)
	local m = Instance.new("Part")
	m.Name = "Mesh"
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
	m.Material = material
	m.Color = color
	m.Transparency = 1
	if shape == "Ellipsoid" then
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Sphere
		sm.Parent = m
	else
		m.Shape = Enum.PartType[shape]
	end
	m.Parent = w
	w.Parent = parent
	return w
end

local function holder(parent, name, cf)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = parent
	return a
end

local function accents(root)
	local f = Instance.new("Folder")
	f.Name = "Accents"
	f.Parent = root
	local up = Enum.NormalId.Top
	local box = Enum.ParticleEmitterShape.Box
	local volume = Enum.ParticleEmitterShapeStyle.Volume
	local neon, glass, slate = Enum.Material.Neon, Enum.Material.Glass, Enum.Material.Slate

	local function element(name, a)
		local m = model(name, f, a)
		return m, part("Base", m, CFrame.new(0, 0.3, 0), V3(12, 0.2, 12))
	end
	-- a tall box up the column (centred at `frac` of the height)
	local function along(parent, name, frac, height, width)
		return part(name, parent, CFrame.new(0, 0, 0), V3(width or 8, height, width or 8), { AtHeight = frac })
	end

	-- ---------------------------------------------------------------- Fire
	-- Blazing Heart: the heart beats twice on the stone, a crown of flame and
	-- fire tongues climb the column, a fire ring rolls out, embers.
	local FIRE_CORE, FIRE, FIRE_DEEP = rgb(255, 214, 120), rgb(255, 130, 50), rgb(220, 60, 25)
	local fireM, fire = element("Fire")
	for i, d in { 0, 0.42 } do
		shapeWave(fire, "Beat" .. i, "Ball", neon, FIRE_CORE, {
			fromSize = V3(2, 2, 2), toSize = V3(9 + i * 4, 9 + i * 4, 9 + i * 4), fromOffset = V3(0, 3, 0), toOffset = V3(0, 3, 0),
			fromTransparency = 0.05, toTransparency = 1, duration = 0.55, style = "Quart", delay = d,
		})
	end
	wave(fire, "Crown", {
		mesh = A.crownTall, color = FIRE, fromSize = V3(7, 2, 7), toSize = V3(16, 42, 16),
		fromOffset = V3(0, 1, 0), toOffset = V3(0, 21, 0), fromTransparency = 0.05, toTransparency = 1,
		duration = 1.7, style = "Quart", fadeStyle = "Quint", delay = 0.1,
	})
	wave(fire, "CrownLow", {
		mesh = A.crownLow, color = FIRE_DEEP, fromSize = V3(9, 1, 9), toSize = V3(22, 9, 22),
		fromOffset = V3(0, 0.5, 0), toOffset = V3(0, 4, 0), fromTransparency = 0, toTransparency = 1,
		duration = 1.4, style = "Quart", fadeStyle = "Quint",
	})
	wave(fire, "Ring", {
		mesh = A.torus, color = FIRE, fromSize = ring(8, 2.4), toSize = ring(40, 1.2),
		fromTransparency = 0, toTransparency = 1, duration = 1.3, style = "Quint",
	})
	local tongues = along(fireM, "Tongues", 0.25, 60, 9)
	emitter(tongues, "Tongues", {
		Texture = A.flame, Size = seq(0, 2, 0.3, 4.5, 1, 0.5), Transparency = seq(0, 0.4, 0.2, 0.05, 0.75, 0.3, 1, 1),
		Color = cseq(0, FIRE_CORE, 0.4, FIRE, 1, FIRE_DEEP), Lifetime = R(0.6, 0.9), Speed = R(14, 24),
		EmissionDirection = up, Acceleration = V3(0, 12, 0), Rotation = R(-10, 10), Rate = 26, Shape = box,
		ShapeStyle = volume, LightEmission = 0.3,
	}, { EmitDuration = 2, Scaled = true })
	emitter(fire, "Embers", {
		Texture = A.spark, Size = seq(0, 0.8, 0.6, 0.55, 1, 0), Transparency = seq(0, 0, 0.7, 0.1, 1, 1),
		Color = cseq(0, FIRE_CORE, 0.4, FIRE, 1, FIRE_DEEP),
		Lifetime = R(1, 1.8), Speed = R(18, 34), SpreadAngle = Vector2.new(22, 22), EmissionDirection = up,
		Acceleration = V3(0, 6, 0), Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 16,
		LightEmission = 0.7, Shape = box, Drag = 0.6,
	}, { EmitDuration = 2, Scaled = true })

	-- ---------------------------------------------------------------- Water
	-- Flowing Spring: a still pool spreads over the ground with ripples,
	-- rings spout up the column, droplets are drawn in and thrown up.
	local WATER_CORE, WATER = rgb(190, 232, 255), rgb(70, 150, 245)
	local waterM, water = element("Water")
	shapeWave(water, "Pool", "Cylinder", neon, WATER, {
		fromSize = V3(0.15, 6, 6), toSize = V3(0.15, 34, 34), rotation = V3(0, 0, 90),
		fromOffset = V3(0, -0.15, 0), toOffset = V3(0, -0.15, 0), fromTransparency = 0.3, toTransparency = 1,
		duration = 3, style = "Quart", fadeStyle = "Quint",
	})
	for i, d in { 0.2, 0.75, 1.3 } do
		wave(water, "Ripple" .. i, {
			mesh = A.torus, color = WATER_CORE, fromSize = ring(5, 1.8), toSize = ring(32, 0.8),
			fromTransparency = 0.05, toTransparency = 1, duration = 1.7, style = "Sine", delay = d,
		})
	end
	for i, d in { 0, 0.3, 0.6, 0.9 } do
		wave(water, "Spout" .. i, {
			mesh = A.torus, color = WATER, fromSize = ring(14, 2), toSize = ring(7, 2.6),
			fromOffset = V3(0, 1, 0), toOffset = V3(0, 75 - i * 10, 0),
			fromTransparency = 0.05, toTransparency = 1, duration = 1.5, style = "Quad", delay = d,
		})
	end
	local shell = part("Shell", waterM, CFrame.new(0, 8, 0), V3(40, 40, 40))
	emitter(shell, "Inflow", {
		Texture = A.spark, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = seq(0, 0.4, 0.5, 0.8, 1, 0.3), Transparency = seq(0, 1, 0.2, 0.1, 0.9, 0.2, 1, 1),
		Color = CS(WATER_CORE), Lifetime = R(0.65, 0.7), Speed = R(30), Rate = 45, LightEmission = 0.3,
	}, { EmitDuration = 1.8, Scaled = true })
	emitter(water, "Droplets", {
		Texture = A.bubble, Size = rnd(0.6, 1), Transparency = seq(0, 0.15, 0.8, 0.3, 1, 1),
		Color = CS(WATER_CORE), Lifetime = R(1.2, 1.6), Speed = R(22, 32),
		SpreadAngle = Vector2.new(28, 28), EmissionDirection = up, Acceleration = V3(0, -38, 0),
		LightEmission = 0.3, Shape = box,
	}, { EmitCount = 22, EmitDelay = 0.5, Scaled = true })

	-- ---------------------------------------------------------------- Wood
	-- Evergreen Root: roots grow out over the ground, branches sprout off
	-- the column, leaves spiral up and burst from the top.
	local WOOD_CORE, WOOD, WOOD_DEEP = rgb(200, 255, 160), rgb(100, 215, 80), rgb(50, 140, 50)
	local woodM, wood = element("Wood")
	for i = 1, 8 do
		local yaw = (i - 1) * 45 + 10
		local bend = if i % 2 == 0 then 28 else -28
		local h = holder(wood, "Root" .. i, CFrame.Angles(0, math.rad(yaw), 0))
		shapeWave(h, "Grow", "Block", neon, WOOD, {
			fromSize = V3(0.6, 0.3, 0.3), toSize = V3(0.7, 0.3, 9), fromOffset = V3(0, -0.1, -3), toOffset = V3(0, -0.1, -7.5),
			fromTransparency = 0.05, toTransparency = 1, duration = 3.2, style = "Quart", fadeStyle = "Quint",
		})
		local tip = holder(wood, "Tip" .. i, CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, 0, -11.8) * CFrame.Angles(0, math.rad(bend), 0))
		shapeWave(tip, "Grow", "Block", neon, WOOD_DEEP, {
			fromSize = V3(0.45, 0.25, 0.2), toSize = V3(0.45, 0.25, 6), fromOffset = V3(0, -0.1, 0), toOffset = V3(0, -0.1, -3),
			fromTransparency = 0.05, toTransparency = 1, duration = 2.8, style = "Quart", fadeStyle = "Quint", delay = 0.4,
		})
	end
	local tilt = math.rad(35)
	for i = 1, 6 do
		local frac = 0.08 + (i - 1) * 0.06
		local h = holder(wood, "Branch" .. i, CFrame.Angles(0, math.rad(i * 137), 0))
		h:SetAttribute("AtHeight", frac)
		local len = 18 - i * 1.5
		shapeWave(h, "Grow", "Block", neon, WOOD, {
			fromSize = V3(0.9, 0.9, 0.3), toSize = V3(1, 1, len), rotation = V3(35, 0, 0),
			fromOffset = V3(0, 0, -1.5), toOffset = V3(0, math.sin(tilt) * len / 2, -1.5 - math.cos(tilt) * len / 2),
			fromTransparency = 0.05, toTransparency = 1, duration = 2.6, style = "Quart", fadeStyle = "Quint",
			delay = 0.15 + i * 0.12,
		})
	end
	emitter(wood, "Leaves", {
		Texture = A.leaf, Size = rnd(1.1, 1.6), Transparency = seq(0, 0, 0.85, 0.1, 1, 1),
		Color = cseq(0, WOOD_CORE, 1, WOOD),
		Lifetime = R(2, 2.8), Speed = R(8, 14), SpreadAngle = Vector2.new(50, 50), EmissionDirection = up,
		Acceleration = V3(0, 5, 0), Rotation = R(0, 360), RotSpeed = R(-160, 160), Rate = 9, Shape = box,
		LightEmission = 0.1,
	}, { EmitDuration = 2, Scaled = true })
	local canopy = part("Canopy", woodM, CFrame.new(), V3(4, 1, 4), { AtHeight = 1 })
	emitter(canopy, "Burst", {
		Texture = A.leaf, Size = rnd(1.6, 2.4), Transparency = seq(0, 0, 0.8, 0.1, 1, 1),
		Color = cseq(0, WOOD_CORE, 1, WOOD), Lifetime = R(1.6, 2.4), Speed = R(18, 30), Drag = 1.5,
		SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -6, 0), Rotation = R(0, 360), RotSpeed = R(-200, 200),
		LightEmission = 0.1,
	}, { EmitCount = 34, EmitDelay = 0.45, Scaled = true })

	-- ---------------------------------------------------------------- Metal
	-- Iron Marrow: a gold gem flares on the stone, clang rings snap out up the
	-- column, shards and sparks, a gold sunburst at the top.
	local GOLD_CORE, GOLD = rgb(255, 246, 210), rgb(255, 196, 80)
	local metalM, metal = element("Metal")
	shapeWave(metal, "Gem", "Block", neon, GOLD, {
		fromSize = V3(1, 1, 1), toSize = V3(5, 5, 5), rotation = V3(45, 0, 35.26),
		fromOffset = V3(0, 4, 0), toOffset = V3(0, 5, 0), fromTransparency = 0, toTransparency = 1,
		duration = 1.8, style = "Back", fadeStyle = "Quint",
	})
	for i = 0, 4 do
		local h = holder(metal, "Clang" .. i, CFrame.new())
		h:SetAttribute("AtHeight", i * 0.12)
		wave(h, "Ring", {
			mesh = A.torus, color = if i % 2 == 0 then GOLD else GOLD_CORE, fromSize = ring(5, 1.6), toSize = ring(34 - i * 3, 0.7),
			fromTransparency = 0, toTransparency = 1, duration = 0.6, style = "Quint", delay = 0.15 + i * 0.18,
		})
	end
	local glints = along(metalM, "Glints", 0.25, 60)
	emitter(glints, "Glints", {
		Texture = A.star4, Size = seq(0, 0, 0.3, 3.2, 1, 0), Transparency = NS(0), Rotation = R(0, 45),
		Color = CS(GOLD_CORE), Lifetime = R(0.35, 0.5), Rate = 18, Shape = box,
		ShapeStyle = volume, LightEmission = 0.6,
	}, { EmitDuration = 2, Scaled = true })
	emitter(metal, "Shards", {
		Texture = A.shards, Size = seq(0, 2, 1, 1), Transparency = seq(0, 0, 0.7, 0.2, 1, 1),
		Color = CS(rgb(255, 236, 190)), Lifetime = R(0.6, 0.9), Speed = R(18, 28), Drag = 2,
		SpreadAngle = Vector2.new(70, 70), EmissionDirection = up, Rotation = R(0, 360), LightEmission = 0.3,
	}, { EmitCount = 10 })
	local sun = part("Sun", metalM, CFrame.new(), V3(1, 1, 1), { AtHeight = 1 })
	emitter(sun, "Sunburst", {
		Texture = A.star12, Size = seq(0, 4, 0.3, 26, 1, 30), Transparency = seq(0, 0.05, 0.6, 0.3, 1, 1),
		Color = CS(GOLD), Lifetime = R(1.4), Rotation = R(0, 360), RotSpeed = R(-20, 20), LightEmission = 0.4,
	}, { EmitCount = 1, EmitDelay = 0.45 })

	-- ---------------------------------------------------------------- Earth
	-- Mountain Breath: a carved stone ring rises out of the ground round the
	-- stone, a rune circle flashes amber, rocks lift, dust rolls out.
	local EARTH, STONE = rgb(225, 140, 50), rgb(118, 98, 78)
	local earthM, earth = element("Earth")
	wave(earth, "StoneRing", {
		mesh = A.torus, color = STONE, material = slate, fromSize = ring(17, 3.4), toSize = ring(17, 3.4),
		fromOffset = V3(0, -2.2, 0), toOffset = V3(0, 0.2, 0), fromTransparency = 0, toTransparency = 1,
		duration = 3.6, style = "Quint", fadeStyle = "Quint",
	})
	wave(earth, "Glow", {
		mesh = A.torus, color = EARTH, fromSize = ring(14.5, 1), toSize = ring(14.5, 1),
		fromOffset = V3(0, -1.5, 0), toOffset = V3(0, 0.25, 0), fromTransparency = 0.1, toTransparency = 1,
		duration = 3.4, style = "Quint", fadeStyle = "Quint",
	})
	emitter(earth, "Runes", B.flat({
		Texture = A.rune, Size = seq(0, 5, 0.2, 7.5, 1, 8), Transparency = seq(0, 1, 0.1, 0.05, 0.75, 0.3, 1, 1),
		Color = CS(rgb(255, 180, 80)), Lifetime = R(3), Rotation = R(0, 360), RotSpeed = R(12), LightEmission = 0.3, ZOffset = 0.2,
	}), { EmitCount = 1 })
	emitter(earth, "Rocks", {
		Texture = A.rocks, Size = rnd(1.4, 2.2), Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = R(2, 2.6), Speed = R(5, 11), SpreadAngle = Vector2.new(20, 20), EmissionDirection = up,
		Rotation = R(0, 360), RotSpeed = R(-50, 50), Drag = 0.3, Shape = box,
	}, { EmitCount = 14, Scaled = true })
	emitter(earth, "Dust", {
		Texture = A.dust, Size = seq(0, 1.5, 1, 4.5), Transparency = seq(0, 0.5, 1, 1),
		Color = CS(rgb(214, 180, 130)), Lifetime = R(0.9, 1.3), Speed = R(14, 22), Drag = 3,
		Shape = box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Rotation = R(0, 360),
	}, { EmitCount = 12 })

	-- ---------------------------------------------------------------- Lightning (rare)
	-- Thunder Pulse: jagged bolts strike down onto the stone in bursts, arcs
	-- crawl up the column, the stone scorches, the sky darkens violet.
	local BOLT_CORE, BOLT, BOLT_DEEP = rgb(245, 235, 255), rgb(190, 150, 255), rgb(120, 70, 230)
	local lightningM, lightning = element("Lightning", {
		Flicker = 0.4, Bolts = 5, BoltGap = 0.42, SkyTint = rgb(110, 70, 190), SkyBrightness = -0.04,
	})
	local bolt = Instance.new("Beam")
	bolt.Name = "Bolt"
	bolt.FaceCamera = true
	bolt.Segments = 1
	bolt.LightInfluence = 0
	bolt.LightEmission = 0.6
	bolt.Brightness = 5
	bolt.Color = cseq(0, BOLT_CORE, 1, BOLT)
	bolt.Width0, bolt.Width1 = 1.3, 1
	bolt.Transparency = NS(0)
	bolt.Enabled = false
	bolt.Parent = lightningM
	local onBolt = model("OnBolt", lightningM)
	local hit = part("Hit", onBolt, CFrame.new(0, 0.5, 0), V3(4, 0.2, 4))
	emitter(hit, "Flash", {
		Texture = A.star4, Size = seq(0, 3, 0.3, 14, 1, 0), Transparency = NS(0), Color = CS(BOLT_CORE),
		Lifetime = R(0.25), Rotation = R(0, 45), LightEmission = 0.6, ZOffset = 3,
	}, { EmitCount = 1 })
	wave(hit, "Snap", {
		mesh = A.torus, color = BOLT_DEEP, fromSize = ring(4, 2.4), toSize = ring(24, 1),
		fromTransparency = 0, toTransparency = 1, duration = 0.45, style = "Quint",
	})
	emitter(hit, "Sparks", {
		Texture = A.spark, Size = seq(0, 0.5, 1, 0), Lifetime = R(0.3, 0.5), Speed = R(25, 40),
		Color = CS(BOLT_CORE), SpreadAngle = Vector2.new(80, 80), EmissionDirection = up,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Drag = 3, LightEmission = 0.8,
	}, { EmitCount = 12 })
	local arcs = along(lightningM, "Arcs", 0.25, 90)
	emitter(arcs, "Arcs", {
		Texture = A.arcs, Size = rnd(4, 7), Transparency = NS(0), Rotation = R(0, 360),
		Color = cseq(0, BOLT_CORE, 1, BOLT),
		Lifetime = R(0.1, 0.2), Rate = 34, Shape = box, ShapeStyle = volume, LightEmission = 0.8,
	}, { EmitDuration = 2.4, Scaled = true })
	emitter(lightning, "Scorch", B.flat({
		Texture = A.crack, Size = seq(0, 6, 0.1, 11, 1, 12), Transparency = seq(0, 1, 0.05, 0.1, 0.7, 0.3, 1, 1),
		Color = CS(BOLT), Lifetime = R(3), Rotation = R(0, 360), LightEmission = 0.4, ZOffset = 0.2,
	}), { EmitCount = 1, EmitDelay = 0.3 })

	-- ---------------------------------------------------------------- Wind (rare)
	-- Drifting Cloud: a wide wind ring is drawn in to the stone, a vortex of
	-- rings corkscrews up the column, clouds spray out across the ground.
	local WIND_CORE, WIND, CLOUD = rgb(220, 255, 242), rgb(140, 230, 200), rgb(246, 252, 250)
	local windM, wind = element("Wind", { SkyTint = rgb(170, 245, 220) })
	wave(wind, "Gather", {
		mesh = A.swirlRing, color = WIND_CORE, fromSize = V3(80, 6, 80), toSize = V3(12, 3, 12),
		fromOffset = V3(0, 4, 0), toOffset = V3(0, 2, 0), fromTransparency = 0.25, toTransparency = 1,
		duration = 1.2, style = "Sine", fadeStyle = "Quart",
	})
	for i, d in { 0, 0.25, 0.5, 0.75, 1, 1.25 } do
		wave(wind, "Swirl" .. i, {
			mesh = if i % 2 == 0 then A.swirlRing2 else A.swirlRing, color = if i % 2 == 0 then WIND else WIND_CORE,
			fromSize = V3(18, 3, 18), toSize = V3(9, 5, 9),
			fromOffset = V3(0, 1, 0), toOffset = V3(0, 95 - i * 8, 0), rotation = V3(0, i * 60, 0),
			fromTransparency = 0.15, toTransparency = 1, duration = 1.7, style = "Quad", fadeStyle = "Quad", delay = 0.3 + d,
		})
	end
	emitter(wind, "Clouds", {
		Texture = A.puff, Size = seq(0, 4, 1, 9), Transparency = seq(0, 0.2, 1, 1), Color = CS(CLOUD),
		Lifetime = R(1.3, 1.8), Speed = R(25, 35), Drag = 2, Shape = box, EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(5, 180), Rotation = R(0, 360), LightInfluence = 0.3,
	}, { EmitCount = 18, EmitDelay = 0.3 })
	emitter(wind, "Streaks", B.flat({
		Texture = A.windStreak, Size = seq(0, 4, 1, 12), Transparency = seq(0, 0.3, 1, 1),
		Color = CS(rgb(200, 250, 230)), Lifetime = R(0.7), Rate = 4, LightEmission = 0.3,
		Rotation = R(0, 360), RotSpeed = R(-220, -160),
	}), { EmitDuration = 2 })

	-- ---------------------------------------------------------------- Ice (rare)
	-- Frost Lotus: a giant glass lotus blooms round the stone, ring by ring,
	-- a frost ring spreads, crystals rise and snow falls round it.
	local ICE_CORE, ICE, ICE_DEEP = rgb(235, 250, 255), rgb(150, 210, 255), rgb(90, 160, 240)
	local iceM, ice = element("Ice", { SkyTint = rgb(190, 235, 255) })
	for layer, p in {
		{ r = 4.5, tilt = 64, size = V3(5.2, 0.8, 9), n = 8, off = 0, color = ICE, delay = 0.2 },
		{ r = 7.8, tilt = 42, size = V3(6.2, 0.8, 11), n = 10, off = 18, color = ICE_DEEP, delay = 0.45 },
		{ r = 11.4, tilt = 20, size = V3(6.8, 0.7, 12.4), n = 12, off = 7, color = rgb(70, 135, 230), delay = 0.7 },
	} do
		for i = 1, p.n do
			local h = holder(ice, ("Petal%d_%d"):format(layer, i), CFrame.Angles(0, math.rad(p.off + (i - 1) * 360 / p.n), 0))
			local t = math.rad(p.tilt)
			local reach = V3(0, math.sin(t) * p.size.Z / 2, -(p.r + math.cos(t) * p.size.Z / 2))
			shapeWave(h, "Bloom", "Ellipsoid", glass, p.color, {
				fromSize = p.size * 0.15, toSize = p.size, rotation = V3(p.tilt, 0, 0),
				fromOffset = reach * 0.4, toOffset = reach, fromTransparency = 0.1, toTransparency = 1,
				duration = 3.4, style = "Back", fadeStyle = "Quint", delay = p.delay + (i - 1) * 0.02,
			})
		end
	end
	emitter(ice, "Crystals", {
		Texture = A.ice, Size = rnd(1.1, 1.8), Transparency = seq(0, 0, 0.8, 0.1, 1, 1),
		Color = CS(ICE_CORE), Lifetime = R(1.8, 2.4), Speed = R(10, 18),
		SpreadAngle = Vector2.new(25, 25), EmissionDirection = up, Rotation = R(0, 360), RotSpeed = R(-60, 60),
		Drag = 0.5, Shape = box, LightEmission = 0.2,
	}, { EmitCount = 16, Scaled = true })
	emitter(ice, "FrostRing", B.flat({
		Texture = A.softRing, Size = seq(0, 2, 1, 20), Transparency = seq(0, 0.25, 1, 1),
		Color = CS(rgb(200, 238, 255)), Lifetime = R(1.4), LightEmission = 0.3,
	}), { EmitCount = 1 })
	local snow = part("Snow", iceM, CFrame.new(), V3(44, 1, 44), { AtHeight = 0.15 })
	emitter(snow, "Snow", {
		Texture = A.glowDot, Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.25, 0.45),
		Transparency = seq(0, 1, 0.1, 0.1, 0.85, 0.2, 1, 1), Color = CS(ICE_CORE), Lifetime = R(2.5, 3.5),
		Speed = R(6, 9), SpreadAngle = Vector2.new(15, 15), Rate = 40, LightEmission = 0.4,
	}, { EmitDuration = 2.4, Scaled = true })

	-- drawn in front of the translucent sheath they rise through
	for _, d in f:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.ZOffset == 0 then
			d.ZOffset = 4
		end
	end
	for _, d in f:GetDescendants() do
		if d:IsA("Model") and not d:GetAttribute("MeshWave") then
			d.WorldPivot = CFrame.new()
		end
	end
	return f
end

function _G.buildRootPillar(parent)
	local old = parent:FindFirstChild("RootPillar")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "RootPillar"
	attrs(root, { Height = 120, RareHeight = 210, Width = 1, Rise = 0.45, Hold = 1.5, Fade = 1.1 })
	pillar(root)
	rare(root)
	glimpse(root)
	accents(root)
	root.Parent = parent
	return root
end

return "buildRootPillar installed"
