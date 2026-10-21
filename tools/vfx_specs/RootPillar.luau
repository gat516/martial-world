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
--            ring, torus rings riding up the column). Crown: a glow at the top.
--   Rare     extra for Lightning/Wind/Ice: Ground shockwave (torus + swirl
--            ring + dust) and Sky (ball flash, horizontal sky ring, star) that
--            RootFX moves to the pillar's top.
--   Glimpse  the re-touch version: a brief glow, motes and a small ring.
--   Accents  one Part per element (Fire, Water, ...) with its own particle
--            motion and colours; RootFX clones the one it needs onto the base.
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

	-- 3D: a ground ring under the stone, and torus rings riding up the column
	wave(base, "GroundRing", {
		mesh = A.torus, color = WHITE, fromSize = ring(6, 2), toSize = ring(30, 1.4),
		fromTransparency = 0.05, toTransparency = 1, duration = 1.1, style = "Quint", fadeStyle = "Quad",
	}, "color")
	for i, d in { 0, 0.3, 0.6 } do
		wave(base, "RiseRing" .. i, {
			mesh = A.torus, color = WHITE, fromSize = ring(14, 2), toSize = ring(7, 2.6),
			fromOffset = V3(0, 1, 0), toOffset = V3(0, 70 - i * 10, 0),
			fromTransparency = 0.05, toTransparency = 1, duration = 1.5, style = "Quad", fadeStyle = "Quad", delay = d,
		}, "core")
	end

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

local function accents(root)
	local f = Instance.new("Folder")
	f.Name = "Accents"
	f.Parent = root
	local up = Enum.NormalId.Top
	local box = Enum.ParticleEmitterShape.Box
	local volume = Enum.ParticleEmitterShapeStyle.Volume

	-- a flat area on the stone, and a tall box along the column
	local function pad(name)
		return part(name, f, CFrame.new(0, 0.3, 0), V3(12, 0.2, 12))
	end
	local function column(parent, name, height)
		return part(name, parent, CFrame.new(0, height / 2, 0), V3(8, height, 8))
	end

	-- Fire: embers streaking up, flickering yellow -> orange -> red
	local fire = pad("Fire")
	emitter(fire, "Embers", {
		Texture = A.spark, Size = seq(0, 0.8, 0.6, 0.55, 1, 0), Transparency = seq(0, 0, 0.7, 0.1, 1, 1),
		Color = cseq(0, Color3.fromRGB(255, 236, 150), 0.4, Color3.fromRGB(255, 140, 50), 1, Color3.fromRGB(220, 60, 30)),
		Lifetime = R(1, 1.8), Speed = R(18, 34), SpreadAngle = Vector2.new(22, 22), EmissionDirection = up,
		Acceleration = V3(0, 6, 0), Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 16,
		LightEmission = 0.7, Shape = box, Drag = 0.6,
	}, { EmitDuration = 2, Scaled = true })

	-- Water: droplets thrown up and falling back, ripples on the stone
	local water = pad("Water")
	emitter(water, "Droplets", {
		Texture = A.bubble, Size = rnd(0.6, 1), Transparency = seq(0, 0.15, 0.8, 0.3, 1, 1),
		Color = CS(Color3.fromRGB(190, 225, 255)), Lifetime = R(1.2, 1.6), Speed = R(22, 32),
		SpreadAngle = Vector2.new(28, 28), EmissionDirection = up, Acceleration = V3(0, -38, 0),
		LightEmission = 0.3, Shape = box,
	}, { EmitCount = 22, Scaled = true })
	emitter(water, "Ripples", B.flat({
		Texture = A.thinRing, Size = seq(0, 1.5, 1, 13), Transparency = seq(0, 0.2, 1, 1),
		Color = CS(Color3.fromRGB(170, 215, 255)), Lifetime = R(1), Rate = 3, LightEmission = 0.3,
	}), { EmitDuration = 2 })

	-- Wood: leaves spiralling up the column
	local wood = pad("Wood")
	emitter(wood, "Leaves", {
		Texture = A.leaf, Size = rnd(1.1, 1.6), Transparency = seq(0, 0, 0.85, 0.1, 1, 1),
		Color = cseq(0, Color3.fromRGB(150, 225, 110), 1, Color3.fromRGB(80, 170, 70)),
		Lifetime = R(2, 2.8), Speed = R(8, 14), SpreadAngle = Vector2.new(50, 50), EmissionDirection = up,
		Acceleration = V3(0, 5, 0), Rotation = R(0, 360), RotSpeed = R(-160, 160), Rate = 9, Shape = box,
		LightEmission = 0.1,
	}, { EmitDuration = 2, Scaled = true })

	-- Metal: hard glints winking along the column, a spray of bright shards
	local metal = pad("Metal")
	local glints = column(metal, "Glints", 60)
	emitter(glints, "Glints", {
		Texture = A.star4, Size = seq(0, 0, 0.3, 3.2, 1, 0), Transparency = NS(0), Rotation = R(0, 45),
		Color = CS(Color3.fromRGB(255, 255, 255)), Lifetime = R(0.35, 0.5), Rate = 18, Shape = box,
		ShapeStyle = volume, LightEmission = 0.6,
	}, { EmitDuration = 2, Scaled = true })
	emitter(metal, "Shards", {
		Texture = A.shards, Size = seq(0, 2, 1, 1), Transparency = seq(0, 0, 0.7, 0.2, 1, 1),
		Color = CS(Color3.fromRGB(235, 238, 248)), Lifetime = R(0.6, 0.9), Speed = R(18, 28), Drag = 2,
		SpreadAngle = Vector2.new(70, 70), EmissionDirection = up, Rotation = R(0, 360), LightEmission = 0.3,
	}, { EmitCount = 8 })

	-- Earth: rock motes lifting slowly off the stone, a puff of dust
	local earth = pad("Earth")
	emitter(earth, "Rocks", {
		Texture = A.rocks, Size = rnd(1.4, 2.2), Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = R(2, 2.6), Speed = R(5, 11), SpreadAngle = Vector2.new(20, 20), EmissionDirection = up,
		Rotation = R(0, 360), RotSpeed = R(-50, 50), Drag = 0.3, Shape = box,
	}, { EmitCount = 14, Scaled = true })
	emitter(earth, "Dust", {
		Texture = A.dust, Size = seq(0, 1.5, 1, 4.5), Transparency = seq(0, 0.5, 1, 1),
		Color = CS(Color3.fromRGB(214, 180, 130)), Lifetime = R(0.9, 1.3), Speed = R(14, 22), Drag = 3,
		Shape = box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Rotation = R(0, 360),
	}, { EmitCount = 8 })

	-- Lightning: arcs crackling up and down the column
	local lightning = pad("Lightning")
	local arcs = column(lightning, "Arcs", 90)
	emitter(arcs, "Arcs", {
		Texture = A.arcs, Size = rnd(4, 7), Transparency = NS(0), Rotation = R(0, 360),
		Color = cseq(0, Color3.fromRGB(240, 230, 255), 1, Color3.fromRGB(190, 150, 255)),
		Lifetime = R(0.1, 0.2), Rate = 34, Shape = box, ShapeStyle = volume, LightEmission = 0.8,
	}, { EmitDuration = 2.4, Scaled = true })
	emitter(lightning, "Sparks", {
		Texture = A.spark, Size = seq(0, 0.45, 1, 0), Lifetime = R(0.3, 0.5), Speed = R(25, 40),
		Color = CS(Color3.fromRGB(225, 210, 255)), SpreadAngle = Vector2.new(80, 80), EmissionDirection = up,
		Orientation = Enum.ParticleOrientation.VelocityParallel, Drag = 3, LightEmission = 0.8,
	}, { EmitCount = 16 })

	-- Wind: swirl rings corkscrewing up, streaks whipping round the base
	local wind = pad("Wind")
	for i, d in { 0, 0.35, 0.7 } do
		wave(wind, "Swirl" .. i, {
			mesh = A.swirlRing, color = Color3.fromRGB(190, 245, 225), fromSize = V3(16, 3, 16), toSize = V3(8, 5, 8),
			fromOffset = V3(0, 1, 0), toOffset = V3(0, 55, 0), rotation = V3(0, i * 120, 0),
			fromTransparency = 0.2, toTransparency = 1, duration = 1.6, style = "Quad", fadeStyle = "Quad", delay = d,
		})
	end
	emitter(wind, "Streaks", B.flat({
		Texture = A.windStreak, Size = seq(0, 4, 1, 12), Transparency = seq(0, 0.3, 1, 1),
		Color = CS(Color3.fromRGB(200, 250, 230)), Lifetime = R(0.7), Rate = 4, LightEmission = 0.3,
		Rotation = R(0, 360), RotSpeed = R(-220, -160),
	}), { EmitDuration = 2 })

	-- Ice: frost crystals drifting up, cold glints
	local ice = pad("Ice")
	emitter(ice, "Crystals", {
		Texture = A.ice, Size = rnd(1.1, 1.8), Transparency = seq(0, 0, 0.8, 0.1, 1, 1),
		Color = CS(Color3.fromRGB(225, 245, 255)), Lifetime = R(1.8, 2.4), Speed = R(10, 18),
		SpreadAngle = Vector2.new(25, 25), EmissionDirection = up, Rotation = R(0, 360), RotSpeed = R(-60, 60),
		Drag = 0.5, Shape = box, LightEmission = 0.2,
	}, { EmitCount = 16, Scaled = true })
	local frost = column(ice, "Frost", 60)
	emitter(frost, "Glints", {
		Texture = A.star4, Size = seq(0, 0, 0.3, 2.6, 1, 0), Transparency = NS(0), Rotation = R(0, 45),
		Color = CS(Color3.fromRGB(215, 245, 255)), Lifetime = R(0.4, 0.6), Rate = 12, Shape = box,
		ShapeStyle = volume, LightEmission = 0.6,
	}, { EmitDuration = 2, Scaled = true })
	emitter(ice, "FrostRing", B.flat({
		Texture = A.softRing, Size = seq(0, 2, 1, 12), Transparency = seq(0, 0.25, 1, 1),
		Color = CS(Color3.fromRGB(215, 245, 255)), Lifetime = R(1.1), LightEmission = 0.3,
	}), { EmitCount = 1 })
	-- drawn in front of the translucent sheath they rise through
	for _, d in f:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.ZOffset = 4
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
