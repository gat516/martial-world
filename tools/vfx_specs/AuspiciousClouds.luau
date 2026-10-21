--!nocheck
-- Builder for ReplicatedStorage.Effects.AuspiciousClouds, the world event
-- "Auspicious Clouds" (and its varieties) drawn by src/client/WorldEventFX.luau.
-- Run through execute_luau in Edit mode (served by tools/receive_rbxmx.py):
--   local m = Instance.new("ModuleScript"); m.Source = HttpService:GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/AuspiciousClouds.luau"); require(m)
--   _G.buildAuspiciousClouds(staging)   -- staging = vfxStage.begin(who)
-- It replaces staging.AuspiciousClouds. Needs ServerStorage.CloudKit
-- (Cloud_WispArc, Cloud_Puff) and ServerStorage.WeaponModels.Jian.
--
-- Layout (pivot = ground point at the eye, +Y up; built at the origin):
--   Vortex / Mist / Spiral   one Model per cloud pattern (def.look.pattern)
--   Ring                     glowing ground ring, AuthoredRadius on the root
--   Column                   light column + qi helix (layer) rising through
--                            the cloud plane
--   Whirl                    a slow whirlpool of wisps on the cloud plane
--                            (Absolute: Y is world Y, not ground-relative)
--   Eye                      seal around the relic, unseal burst (Core), glow
--   Relics.Manual / .Sword   the server's claimable relic (ClaimPrompt)
-- Every Model with a `Speed` attribute is a turning layer (deg/s about the eye
-- axis): Bob/BobPeriod (studs/s), Ripple/RipplePeriod (radial pulse), Phase
-- (rad), Order (0 = arrives first .. 1 = last), Condense (false: stays put
-- when the clouds pour into the relic), Absolute (world Y).
-- Parts carry `Fade` (their resting Transparency, faded by the client);
-- anything with `Tint` ("color" / "accent", optional `TintMix` 0..1) is
-- recoloured from the def's look.

local ServerStorage = game:GetService("ServerStorage")
local AssetService = game:GetService("AssetService")

local A = {
	glow = "rbxassetid://867619398",
	glow2 = "rbxassetid://9841273544",
	star = "rbxassetid://13271628051",
	spark = "rbxassetid://13271102367",
	mist = "rbxassetid://1084987899",
	swirl = "rbxassetid://14670080222",
	ringSoft = "rbxassetid://15611941586",
	shards = "rbxassetid://12402863766",
	column = "rbxassetid://1191605952", -- soft solid band (the image's vertical runs along a beam)
	chain = "rbxassetid://17405360386",
	seal = "rbxassetid://83667248904000",
	sunburst = "rbxassetid://15773612675",
	torus = "rbxassetid://471124075",
}
_G.CloudAssets = A

local WISP = { size = Vector3.new(300.934, 32.023, 153.091), circle = Vector3.new(1.753, 0, -86.207), radius = 130 }
local WHITE = Color3.new(1, 1, 1)

local meshCache = _G.CloudMeshCache or {}
_G.CloudMeshCache = meshCache

local function noPhysics(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	if p:IsA("MeshPart") or p:IsA("PartOperation") then
		p.CollisionFidelity = Enum.CollisionFidelity.Box
	end
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

local function model(name, parent, a)
	local m = Instance.new("Model")
	m.Name = name
	attrs(m, a)
	m.Parent = parent
	return m
end

-- an invisible anchor part (emitters, attachments)
local function anchor(name, parent, cf, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size or Vector3.new(1, 1, 1)
	p.Transparency = 1
	p.CFrame = cf
	noPhysics(p)
	p.Parent = parent
	return p
end

local function att(name, parent, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	a.Parent = parent
	return a
end

local function seq(...)
	local pts = { ... }
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function emitter(name, parent, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.LightInfluence = 0
	e.Rate = 0
	set(e, props)
	attrs(e, a)
	e.Parent = parent
	return e
end

local function beam(name, parent, a0, a1, props, a)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.Enabled = false
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	set(b, props)
	attrs(b, a)
	b.Parent = parent
	return b
end

local function meshPart(id, name, parent, size, cf, color, material, transparency, a)
	local src = meshCache[id]
	if not src then
		src = AssetService:CreateMeshPartAsync(id)
		meshCache[id] = src
	end
	local m = src:Clone()
	m.Name = name
	m.Size, m.CFrame, m.Color = size, cf, color
	m.Material = material or Enum.Material.Neon
	m.Transparency = transparency or 0
	noPhysics(m)
	attrs(m, a)
	m:SetAttribute("Fade", m.Transparency)
	m.Parent = parent
	return m
end

-- a ring torus of radius r (outer edge) lying flat, tube thickness h
local function torus(name, parent, r, h, cf, transparency, tint)
	return meshPart(A.torus, name, parent, Vector3.new(r * 2, h, r * 2), cf, WHITE, Enum.Material.Neon, transparency, { Tint = tint or "accent", TintMix = 0.75 })
end

-- a crescent wisp centred on the eye axis at radius r, its bottom at y, the
-- arc's middle facing `deg`; roll tilts it along its length (a screw turn)
local function wisp(parent, r, y, deg, roll, yScale, transparency)
	local s = r / WISP.radius
	local size = Vector3.new(WISP.size.X * s, WISP.size.Y * s * (yScale or 1), WISP.size.Z * s)
	local cc = Vector3.new(WISP.circle.X * s, 0, WISP.circle.Z * s)
	local a = math.rad(deg)
	local yaw = math.atan2(math.cos(a), math.sin(a))
	local p = ServerStorage.CloudKit.Cloud_WispArc:Clone()
	p.Name = "Wisp"
	p.Size = size
	p.CFrame = CFrame.new(0, y + size.Y / 2, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(roll or 0)) * CFrame.new(-cc)
	p.Color = WHITE
	p.Transparency = transparency or 0
	noPhysics(p)
	attrs(p, { Fade = p.Transparency, Tint = "color" })
	p.Parent = parent
	return p
end

local function puff(parent, r, y, deg, scale, transparency)
	local p = ServerStorage.CloudKit.Cloud_Puff:Clone()
	p.Name = "Puff"
	p.Size = p.Size * scale
	local a = math.rad(deg)
	p.CFrame = CFrame.new(math.sin(a) * r, y + p.Size.Y / 2, -math.cos(a) * r) * CFrame.Angles(0, a * 1.7, 0)
	p.Color = WHITE
	p.Transparency = transparency or 0
	noPhysics(p)
	attrs(p, { Fade = p.Transparency, Tint = "color" })
	p.Parent = parent
	return p
end

-- a vertical cylinder emission volume (Cylinder shapes run along the part's X)
local function column(name, parent, y, height, radius)
	return anchor(name, parent, CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(height, radius * 2, radius * 2))
end

-- inward-spiralling motes and mist: emitted on the cylinder's wall, flying to
-- its axis, locked to the (turning) part so they curl in
local function inwardQi(part, radius, motes, mist)
	emitter("InwardMotes", part, {
		Texture = A.glow, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = NumberRange.new(radius / 6), Lifetime = NumberRange.new(5, 6),
		Rate = motes, LockedToPart = true, LightEmission = 0.5, Size = seq(0, 0, 0.2, 0.7, 1, 0.1),
		Transparency = seq(0, 1, 0.2, 0.15, 1, 1),
	}, { Tint = "accent" })
	if mist > 0 then
		emitter("InwardMist", part, {
			Texture = A.mist, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = NumberRange.new(radius / 8), Lifetime = NumberRange.new(6, 7),
			Rate = mist, LockedToPart = true, Size = seq(0, 5, 1, 10), Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-12, 12), Transparency = seq(0, 1, 0.3, 0.7, 1, 1),
		}, { Tint = "color", TintMix = 0.6 })
	end
	emitter("Sparkles", part, {
		Texture = A.spark, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Speed = NumberRange.new(0.5, 1), Lifetime = NumberRange.new(1.5, 2.5), Rate = 3, LightEmission = 0.6,
		Size = seq(0, 0, 0.5, 0.9, 1, 0), Rotation = NumberRange.new(0, 90),
	}, { Tint = "accent", TintMix = 0.5 })
end

-- patterns ------------------------------------------------------------------

-- Vortex: a coiling funnel, six layers widening upward, alternating directions.
local function vortex(root)
	local p = model("Vortex", root, { AuthoredRadius = 36 })
	-- the lowest layer floats over head height so the ring and relic stay in view
	local layers = { -- y, r, n, speed, roll, yScale
		{ 16, 44, 3, 12, 10, 0.6 },
		{ 40, 54, 2, -9, -12, 0.7 },
		{ 68, 68, 2, 7, 12, 0.75 },
		{ 100, 84, 3, -6, -12, 0.8 },
		{ 134, 102, 2, 5, 12, 0.85 },
		{ 166, 122, 3, -4, -10, 0.9 },
	}
	for i, l in layers do
		local m = model("L" .. i, p, {
			Speed = l[4], Bob = 1 + i * 0.4, BobPeriod = 7 + i, Phase = i * 1.3, Order = 1 - (i - 1) / (#layers - 1),
		})
		for k = 0, l[3] - 1 do
			wisp(m, l[2], l[1], k * 360 / l[3] + i * 37, l[5], l[6])
		end
		if i == #layers then
			for k = 0, 2 do
				puff(m, l[2] * 0.95, l[1] + 4, k * 120 + 60, 0.55)
			end
		end
		if i == 1 then
			inwardQi(column("Qi", m, 18, 32, 40), 40, 6, 1.5)
		end
	end
	return p
end

-- Mist: low, wide concentric rings of wisps hugging the ground, rippling out,
-- with violet mist drifting along the grass.
local function mist(root)
	local p = model("Mist", root, { AuthoredRadius = 44 })
	local layers = { -- y, r, n, speed, roll, yScale
		{ 0.5, 22, 2, 6, 2, 0.5 },
		{ 1, 38, 3, -5, -2, 0.45 },
		{ 1.5, 56, 3, 4, 2, 0.5 },
		{ 2, 76, 3, -3, -2, 0.6 },
		{ 3, 98, 3, 2, 2, 0.7 },
	}
	for i, l in layers do
		local m = model("L" .. i, p, {
			Speed = l[4], Bob = 0.4, BobPeriod = 9, Ripple = 3 + i * 0.6, RipplePeriod = 7, Phase = -i * 0.9,
			Order = (i - 1) / (#layers - 1),
		})
		for k = 0, l[3] - 1 do
			wisp(m, l[2], l[1], k * 360 / l[3] + i * 53, l[5], l[6], 0.2)
		end
		if i == 1 then
			local fx = anchor("Drift", m, CFrame.new(0, 1, 0), Vector3.new(10, 1, 10))
			emitter("GroundMist", fx, {
				Texture = A.mist, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front,
				SpreadAngle = Vector2.new(5, 180), Speed = NumberRange.new(5, 8), Drag = 0.25, Lifetime = NumberRange.new(8, 10),
				Rate = 2.5, Size = seq(0, 6, 1, 14), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8),
				Transparency = seq(0, 1, 0.25, 0.6, 1, 1),
			}, { Tint = "accent", TintMix = 0.55 })
			local c = att("Ripple", fx, Vector3.new(0, -0.3, 0))
			emitter("RippleRing", c, {
				Texture = A.ringSoft, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(6),
				Rate = 0.35, Size = seq(0, 6, 1, 70), Transparency = seq(0, 1, 0.15, 0.55, 1, 1), LightEmission = 0.3,
			}, { Tint = "accent" })
			emitter("Motes", anchor("MoteVolume", m, CFrame.new(0, 4, 0), Vector3.new(80, 6, 80)), {
				Texture = A.glow, Shape = Enum.ParticleEmitterShape.Box, Speed = NumberRange.new(0.3, 1),
				SpreadAngle = Vector2.new(180, 180), Lifetime = NumberRange.new(3, 5), Rate = 5, LightEmission = 0.5,
				Size = seq(0, 0, 0.3, 0.5, 1, 0), Acceleration = Vector3.new(0, 0.6, 0),
			}, { Tint = "accent" })
		end
	end
	return p
end

-- Spiral: a rising double helix of wisps climbing into a crown of clouds with
-- a radiant halo.
local function spiral(root)
	local p = model("Spiral", root, { AuthoredRadius = 30 })
	local helix = model("Helix", p, { Speed = 14, Bob = 1, BobPeriod = 8, Order = 0.6 })
	for strand = 0, 1 do
		for i = 0, 5 do
			wisp(helix, 18 + i * 2.4, 16 + i * 24, i * 65 + strand * 180, 16, 1.6)
		end
	end
	inwardQi(column("Qi", helix, 18, 30, 30), 30, 4, 0)
	local rise = column("Rise", helix, 70, 140, 16)
	emitter("RisingMotes", rise, {
		Texture = A.spark, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Speed = NumberRange.new(0.1), Acceleration = Vector3.new(0, 8, 0), Lifetime = NumberRange.new(4, 6), Rate = 6,
		LightEmission = 0.6, Size = seq(0, 0, 0.3, 0.9, 1, 0), Rotation = NumberRange.new(0, 90),
	}, { Tint = "accent" })
	local crown = model("Crown", p, { Speed = -5, Bob = 2, BobPeriod = 10, Phase = 1, Order = 0 })
	for k = 0, 3 do
		wisp(crown, 56, 150, k * 90 + 20, k % 2 == 0 and 5 or -5, 1)
	end
	for k = 0, 2 do
		puff(crown, 58, 146, k * 120, 0.6)
	end
	torus("Halo", crown, 40, 1.6, CFrame.new(0, 164, 0), 0.35)
	local sun = anchor("Radiance", crown, CFrame.new(0, 164, 0))
	emitter("Sunburst", sun, {
		Texture = A.sunburst, Speed = NumberRange.new(0), Lifetime = NumberRange.new(6), Rate = 0.35, LightEmission = 0.4,
		Size = seq(0, 26, 1, 34), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-4, 4),
		Transparency = seq(0, 1, 0.3, 0.6, 1, 1),
	}, { Tint = "accent" })
	return p
end

-- shared pieces ---------------------------------------------------------------

local function ring(root)
	local m = model("Ring", root)
	torus("RingBand", m, 36, 0.8, CFrame.new(0, 0.4, 0), 0.4).Name = "RingBand"
	local fx = column("RingFX", m, 0.4, 0.4, 36)
	emitter("RingMotes", fx, {
		Texture = A.glow, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Speed = NumberRange.new(0.2), Acceleration = Vector3.new(0, 2.5, 0), Lifetime = NumberRange.new(2.5, 3.5), Rate = 6,
		LightEmission = 0.5, Size = seq(0, 0, 0.3, 0.45, 1, 0),
	}, { Tint = "accent", Scale = true })
	local c = att("Centre", anchor("RingCentre", m, CFrame.new(0, 0.3, 0)))
	emitter("RingPulse", c, {
		Texture = A.ringSoft, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(4),
		Rate = 0.3, Size = seq(0, 33, 1, 38), Transparency = seq(0, 1, 0.3, 0.55, 1, 1), LightEmission = 0.4,
	}, { Tint = "accent", Scale = true })
end

-- the light column, ground to just over the cloud plane (its Top attachment
-- sits at world Y WorldY). Beams are culled with their attachments' part, so
-- the part above the plane is its own piece in Whirl (Sky).
local function columnPiece(root)
	local m = model("Column", root)
	local base = anchor("Shaft", m, CFrame.new(0, 0, 0))
	local a0, a1 = att("Base", base, Vector3.new(0, 2, 0)), att("Top", base, Vector3.new(0, 446, 0))
	a1:SetAttribute("WorldY", 446)
	beam("Glow", base, a0, a1, {
		Texture = A.glow, TextureSpeed = 0.25, TextureLength = 1, TextureMode = Enum.TextureMode.Stretch,
		Width0 = 22, Width1 = 30, LightEmission = 0, Transparency = seq(0, 1, 0.04, 0.3, 1, 0.3),
	}, { Tint = "accent" }) -- not additive: it has to show against the white cloud plane
	beam("Core", base, a0, a1, {
		Texture = A.column, TextureSpeed = 0.5, TextureLength = 1, TextureMode = Enum.TextureMode.Stretch,
		Width0 = 6, Width1 = 8, LightEmission = 0.5, Transparency = seq(0, 1, 0.04, 0.15, 1, 0.15),
	}, { Tint = "color" })
	-- the qi helix: one strand of 16 points, 30 studs and 45 degrees apart
	local helix = model("Helix", m, { Speed = 40, Condense = false, Order = 0 })
	local hp = anchor("HelixPoints", helix, CFrame.new(0, 0, 0))
	local prev
	for i = 0, 14 do
		local a = math.rad(i * 45)
		local pt = att("H" .. i, hp, Vector3.new(math.cos(a) * 7, 4 + i * 30, math.sin(a) * 7))
		if prev then
			beam("Strand" .. i, hp, prev, pt, {
				Width0 = 1.6, Width1 = 1.6, LightEmission = 0.6, Transparency = seq(0, 0.35, 1, 0.35), Texture = "",
			}, { Tint = "accent" })
		end
		prev = pt
	end
end

local function whirl(root)
	local m = model("Whirl", root, { Speed = 5, Absolute = true, Condense = false, Order = 0, Bob = 0.5, BobPeriod = 11 })
	-- arcs half sunk in the cloud plane (top Y 440), spiralling out
	for i, l in { { 60, 0 }, { 90, 100 }, { 125, 210 }, { 160, 300 } } do
		wisp(m, l[1], 434 + i * 0.5, l[2], 3, 0.6)
	end
	torus("WhirlRing", m, 46, 1.2, CFrame.new(0, 440.6, 0), 0.3)
	-- the column above the plane, seen from the peaks: a Neon pillar in a glow
	local pillar = Instance.new("Part")
	pillar.Name, pillar.Shape, pillar.Material = "SkyPillar", Enum.PartType.Cylinder, Enum.Material.Neon
	pillar.Size = Vector3.new(170, 9, 9)
	pillar.CFrame = CFrame.new(0, 440 + 85, 0) * CFrame.Angles(0, 0, math.pi / 2)
	pillar.Transparency = 0.35
	noPhysics(pillar)
	attrs(pillar, { Fade = 0.35, Tint = "accent", TintMix = 0.7 })
	pillar.Parent = m
	local sky = anchor("Sky", m, CFrame.new(0, 438, 0))
	local s0, s1 = att("SkyBase", sky), att("SkyTop", sky, Vector3.new(0, 200, 0))
	beam("SkyGlow", sky, s0, s1, {
		Texture = A.glow, TextureLength = 1, TextureMode = Enum.TextureMode.Stretch,
		Width0 = 30, Width1 = 48, LightEmission = 0, Transparency = seq(0, 0.3, 0.75, 0.4, 1, 1),
	}, { Tint = "accent" })
	local fx = anchor("WhirlFX", m, CFrame.new(0, 441, 0))
	emitter("WhirlSwirl", att("Swirl", fx), {
		Texture = A.swirl, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(10),
		Rate = 0.3, Size = seq(0, 120, 1, 150), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, -4),
		Transparency = seq(0, 1, 0.3, 0.55, 0.7, 0.6, 1, 1),
	}, { Tint = "accent" })
end

-- the seal around the relic, its unseal burst and the relic's glow; the Eye
-- part sits at the relic's core height (the relic model's CoreHeight)
local function eye(root)
	local m = model("Eye", root)
	local e = anchor("Eye", m, CFrame.new(0, 5, 0))
	local core = att("Core", e)
	emitter("Flash", core, {
		Texture = A.star, Speed = NumberRange.new(0), Lifetime = NumberRange.new(0.6), LightEmission = 0.7,
		Size = seq(0, 2, 0.2, 16, 1, 0), Rotation = NumberRange.new(0, 45), ZOffset = 2,
	}, { Tint = "accent", TintMix = 0.6, EmitCount = 1 })
	emitter("Sparks", core, {
		Texture = A.spark, Speed = NumberRange.new(24, 40), Drag = 3, Lifetime = NumberRange.new(1, 1.6), LightEmission = 0.6,
		SpreadAngle = Vector2.new(180, 180), Size = seq(0, 0.9, 1, 0), Rotation = NumberRange.new(0, 90),
	}, { Tint = "accent", EmitCount = 30 })
	emitter("Shards", core, {
		Texture = A.shards, Speed = NumberRange.new(16, 26), Drag = 1.5, Lifetime = NumberRange.new(1.2, 1.8),
		Acceleration = Vector3.new(0, -24, 0), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.4,
		Size = seq(0, 0.8, 1, 0.2), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
	}, { Tint = "accent", EmitCount = 16 })
	emitter("Puff", core, {
		Texture = A.mist, Speed = NumberRange.new(8, 12), Drag = 2, Lifetime = NumberRange.new(2.2, 3),
		SpreadAngle = Vector2.new(180, 180), Size = seq(0, 4, 1, 10), Rotation = NumberRange.new(0, 360),
		Transparency = seq(0, 0.3, 1, 1),
	}, { Tint = "color", EmitCount = 8 })
	-- 3D unseal: a flat torus racing out and a Neon shell (MeshWave, TechniqueVFX)
	local wave = model("UnsealWave", core, {
		MeshWave = true, FromSize = Vector3.new(6, 0.8, 6), ToSize = Vector3.new(64, 2.4, 64), FromTransparency = 0.05,
		ToTransparency = 1, Duration = 0.9, Style = "Quart", FadeStyle = "Quad",
	})
	torus("Mesh", wave, 3, 0.8, CFrame.new(0, 5, 0), 1)
	local shell = model("UnsealShell", core, {
		MeshWave = true, FromSize = Vector3.new(3, 3, 3), ToSize = Vector3.new(22, 22, 22), FromTransparency = 0.6,
		ToTransparency = 1, Duration = 0.7, Style = "Quart", FadeStyle = "Quad",
	})
	local ball = Instance.new("Part")
	ball.Name, ball.Shape, ball.Material, ball.Size, ball.Transparency = "Mesh", Enum.PartType.Ball, Enum.Material.Neon, Vector3.new(3, 3, 3), 1
	ball.CFrame = CFrame.new(0, 5, 0)
	noPhysics(ball)
	attrs(ball, { Tint = "accent" })
	ball.Parent = shell

	-- glow: faint while sealed, bright once unsealed (the client switches)
	local g = att("Glow", e)
	emitter("Faint", g, {
		Texture = A.glow2, Speed = NumberRange.new(0), Lifetime = NumberRange.new(1.5), Rate = 2, LightEmission = 0.4,
		Size = seq(0, 3, 1, 3.5), Transparency = seq(0, 1, 0.4, 0.7, 1, 1),
	}, { Tint = "accent" })
	emitter("Bright", g, {
		Texture = A.glow, Speed = NumberRange.new(0), Lifetime = NumberRange.new(1.2), Rate = 4, LightEmission = 0.6,
		Size = seq(0, 5, 1, 6.5), Transparency = seq(0, 1, 0.3, 0.45, 1, 1),
	}, { Tint = "accent", TintMix = 0.7, Unsealed = true })
	emitter("Rise", g, {
		Texture = A.spark, SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(2, 4),
		Lifetime = NumberRange.new(1.5, 2.5), Rate = 5, LightEmission = 0.6, Size = seq(0, 0, 0.3, 0.5, 1, 0),
	}, { Tint = "accent", Unsealed = true })
	local light = Instance.new("PointLight")
	light.Name, light.Brightness, light.Range, light.Shadows, light.Enabled = "Light", 0, 14, false, true
	light:SetAttribute("Tint", "accent")
	light:SetAttribute("Brightness", 1.6)
	light.Parent = g

	-- the seal: two tilted talisman rings turning round the relic, a seal
	-- circle on the ground and four chains of light; shatters on unseal
	local seal = model("Seal", m, { Speed = 30, Condense = false, Order = 0.3 })
	torus("SealRingA", seal, 3.6, 0.22, CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(62), 0, 0), 0.2)
	torus("SealRingB", seal, 3.9, 0.22, CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(-62)), 0.2)
	local hub = anchor("Chains", seal, CFrame.new(0, 0, 0))
	local top = att("Hub", hub, Vector3.new(0, 5, 0))
	for k = 0, 3 do
		local a = math.rad(k * 90 + 45)
		local foot = att("Foot" .. k, hub, Vector3.new(math.cos(a) * 7, 0.4, math.sin(a) * 7))
		beam("Chain" .. k, hub, top, foot, {
			Texture = A.chain, TextureMode = Enum.TextureMode.Wrap, TextureLength = 1.2, TextureSpeed = 0.4,
			Width0 = 1.1, Width1 = 1.1, LightEmission = 0.5, Transparency = seq(0, 0.5, 0.5, 0.15, 1, 0.4),
		}, { Tint = "accent" })
	end
	local circle = att("Circle", anchor("SealCircle", seal, CFrame.new(0, 0.35, 0)))
	emitter("SealCircle", circle, {
		Texture = A.seal, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01), Lifetime = NumberRange.new(3), Rate = 0.7, LightEmission = 0.4,
		Size = seq(0, 7.5, 1, 8), Transparency = seq(0, 1, 0.3, 0.45, 0.7, 0.45, 1, 1), RotSpeed = NumberRange.new(10),
	}, { Tint = "accent" })
end

-- relics (server-cloned, claimable) ------------------------------------------------

local function relicPart(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	noPhysics(p)
	p.Parent = parent
	return p
end

local function claim(relic, holder, height)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClaimPrompt"
	prompt.Enabled = false
	prompt.ActionText = "Claim"
	prompt.ObjectText = "Relic"
	prompt.HoldDuration = 2
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 246, 220)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 20)
	label.Text = "Sealed relic"
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 18
	limit.Parent = label
	label.Parent = gui
	gui.Parent = holder
end

local function relics(root)
	local folder = Instance.new("Folder")
	folder.Name = "Relics"
	folder.Parent = root

	-- a cultivation manual: a silk scroll on a jade rod, half unrolled, hovering
	local manual = model("Manual", folder, { CoreHeight = 5 })
	local y = 5
	local silk = Color3.fromRGB(238, 226, 196)
	local jade = Color3.fromRGB(112, 214, 170)
	local gold = Color3.fromRGB(226, 182, 92)
	local body = relicPart(manual, "Scroll", Vector3.new(3.2, 0.9, 0.9), CFrame.new(0, y + 0.9, 0) * CFrame.Angles(0, 0, 0), silk, Enum.Material.Fabric, Enum.PartType.Cylinder)
	relicPart(manual, "Rod", Vector3.new(4, 0.34, 0.34), CFrame.new(0, y + 0.9, 0), jade, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.15
	for s = -1, 1, 2 do
		relicPart(manual, "Knob", Vector3.new(0.5, 0.5, 0.5), CFrame.new(s * 2.05, y + 0.9, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
	end
	relicPart(manual, "Silk", Vector3.new(0.3, 0.96, 0.96), CFrame.new(0.9, y + 0.9, 0), Color3.fromRGB(196, 52, 48), Enum.Material.Fabric, Enum.PartType.Cylinder)
	-- the unrolled sheet hanging below, a little turned toward the viewer
	relicPart(manual, "Sheet", Vector3.new(3, 2.2, 0.06), CFrame.new(0, y - 0.4, 0.15) * CFrame.Angles(math.rad(-8), 0, 0), silk, Enum.Material.Fabric)
	relicPart(manual, "Rule", Vector3.new(2.6, 0.08, 0.07), CFrame.new(0, y - 1.45, 0.3) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(60, 50, 40), Enum.Material.SmoothPlastic)
	relicPart(manual, "Weight", Vector3.new(3.2, 0.22, 0.22), CFrame.new(0, y - 1.55, 0.32), jade, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.15
	claim(manual, body, 3.2)
	local glow = att("RelicGlow", body)
	emitter("Aura", glow, {
		Texture = A.glow2, Speed = NumberRange.new(0), Lifetime = NumberRange.new(2), Rate = 1.5, LightEmission = 0.3,
		Size = seq(0, 3.5, 1, 4), Transparency = seq(0, 1, 0.4, 0.75, 1, 1), Color = ColorSequence.new(Color3.fromRGB(190, 255, 220)),
		Enabled = true,
	})
	manual.WorldPivot = CFrame.new(0, 0, 0)

	-- an ancient jian, point down, hovering
	local sword = model("Sword", folder, { CoreHeight = 6 })
	local jian = ServerStorage.WeaponModels.Jian
	local scale = 2
	local pivot = jian:GetPivot()
	-- turn it so the blade points straight down, whichever way the Jian model
	-- holds it (grip -> blade centre becomes -Y)
	local blade = jian:FindFirstChild("JianBlade", true) or jian:FindFirstChild("Handle", true)
	local grip = jian:FindFirstChild("JianGrip", true)
	local turn = CFrame.Angles(math.pi, 0, 0)
	if blade and grip then
		local d = pivot:VectorToObjectSpace(blade.Position - grip.Position).Unit
		local down = Vector3.new(0, -1, 0)
		local axis = d:Cross(down)
		local angle = math.acos(math.clamp(d:Dot(down), -1, 1))
		turn = if axis.Magnitude > 1e-4 then CFrame.fromAxisAngle(axis.Unit, angle) elseif d.Y > 0 then CFrame.Angles(math.pi, 0, 0) else CFrame.identity
	end
	local handle
	for _, d in jian:GetDescendants() do
		if d:IsA("BasePart") then
			local c = d:Clone()
			c:ClearAllChildren()
			local rel = pivot:ToObjectSpace(d.CFrame)
			c.Size = d.Size * scale
			c.CFrame = turn * CFrame.new(rel.Position * scale) * rel.Rotation
			noPhysics(c)
			c.Parent = sword
			-- the blade carries the prompt and the glow (Handle on older Jian builds)
			if d.Name == "JianBlade" or d.Name == "Handle" or not handle then
				handle = c
			end
		end
	end
	-- centre the whole sword at y 6.5, whatever the Jian's current parts are
	sword.WorldPivot = CFrame.new()
	local box = sword:GetBoundingBox()
	local shift = Vector3.new(-box.Position.X, 6.5 - box.Position.Y, -box.Position.Z)
	for _, c in sword:GetChildren() do
		c.CFrame += shift
	end
	claim(sword, handle, 6.5)
	emitter("Aura", att("RelicGlow", handle), {
		Texture = A.glow2, Speed = NumberRange.new(0), Lifetime = NumberRange.new(2), Rate = 1.5, LightEmission = 0.3,
		Size = seq(0, 4, 1, 4.5), Transparency = seq(0, 1, 0.4, 0.75, 1, 1), Color = ColorSequence.new(Color3.fromRGB(255, 226, 160)),
		Enabled = true,
	})
	sword.WorldPivot = CFrame.new(0, 0, 0)
end

_G.buildAuspiciousClouds = function(parent)
	local old = parent:FindFirstChild("AuspiciousClouds")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "AuspiciousClouds"
	attrs(root, { AuthoredRadius = 36, PlaneTop = 440 })
	vortex(root)
	mist(root)
	spiral(root)
	ring(root)
	columnPiece(root)
	whirl(root)
	eye(root)
	relics(root)
	root.WorldPivot = CFrame.new()
	root.Parent = parent
	local parts, emitters, beams = 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("ParticleEmitter") then
			emitters += 1
		elseif d:IsA("Beam") then
			beams += 1
		end
	end
	return string.format("built AuspiciousClouds: %d parts, %d emitters, %d beams", parts, emitters, beams)
end

return true
