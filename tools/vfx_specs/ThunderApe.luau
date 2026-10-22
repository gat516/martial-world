--!nocheck
-- Builder for ReplicatedStorage.Effects.ThunderApe: the Thunder Ape boss's
-- attack, hit, phase, roar, aura and death effects. Load through the receiver,
-- then build into the Effects folder (or a staging copy):
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/ThunderApe.luau")
--   require(m)  -- installs _G.buildThunderApeFX(effectsFolder)
-- Runtime: src/client/EnemyFX/ThunderApe.luau (cue -> template, placement).
--
-- Identity: storm blue-white on slate. Core white-hot, bright 5BD8FF, rim
-- B8F0FF, a dark indigo 1B2547 copy under every bright shape for daylight, a
-- violet accent (8F7BFF) for phase 3 only. No gold, and nothing circles or
-- floats over the head: storm-cloud wisps sit on the back and shoulders.
-- The body is 3.71x (about 28 studs tall), so every effect is authored large.
--
-- Every template is an invisible anchored Part (centre = pivot, -Z = facing or
-- blow direction). Ground templates have their centre on the floor.
-- `AuthoredSeconds` (windup holds) and `AuthoredRadius` (ground shapes) tell
-- the runtime how to refit and scale them. `BaseRate` marks aura emitters.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local BRIGHT = Color3.fromRGB(91, 216, 255)
local RIM = Color3.fromRGB(184, 240, 255)
local INDIGO = Color3.fromRGB(27, 37, 71)
local VIOLET = Color3.fromRGB(143, 123, 255)
local DUST = Color3.fromRGB(122, 130, 144)
local SLATE = Color3.fromRGB(62, 68, 80)

local TEX = {
	glint = id(84223532517124),
	dot = id(9841273544),
	mote = id(8238126392),
	ringThin = id(9841273159),
	ringThick = id(13322173171),
	ringSpiky = id(13052243772),
	ringDust = id(13052235894),
	arc = id(13366366767), -- crescent
	arcSoft = id(1266209505),
	line = id(7886908733),
	streaks = id(5699911427),
	streak = id(18244764764),
	crackHole = id(85474069372331),
	crackDark = id(86726095803553),
	crackLines = id(7994630128),
	crackGlow = id(8172249266),
	mandala = id(107304921648525),
	sigil = id(16878097832),
	puff = id(14050360239),
	wisp = id(15753663130),
	flame = id(13280154167),
	flameBurst = id(250186345),
	chips = id(425665059),
	rock = id(626588936),
	ink = id(16132530029),
	-- lightning (verified on the Lightning Talisman)
	zig = id(882168791), -- single jagged arc
	fork = id(6127835958), -- bright forked arc
	elecRing = id(112496740337235), -- ring of lightning
	radial = id(301851161), -- radial lightning splash (ground arcs)
}

local FLAT = {
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
	Speed = R(0.01),
}
-- a vertical plane facing out of the emitter's front (-Z): a ring on a chest
local FACE = {
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Front,
	Speed = R(0.01),
}
local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
end

local function part(root, name, size, attrs)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new()
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = root
	return p
end

local function att(parent, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	a.Parent = parent
	return a
end

-- Sizes below are authored as diameters; a particle's Size is a half-width, so
-- halve them once here.
local function em(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	for k, v in props do
		e[k] = v
	end
	local half = {}
	for _, key in e.Size.Keypoints do
		table.insert(half, KP(key.Time, key.Value / 2, key.Envelope / 2))
	end
	e.Size = NS(half)
	for k, v in attrs or { EmitCount = 1 } do
		e:SetAttribute(k, v)
	end
	if e.Rate > 0 then
		e:SetAttribute("BaseRate", e.Rate)
	end
	e.Parent = parent
	return e
end

local function trail(parent, name, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Enabled = false
	t.LightInfluence = 0
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local fade = NS({ KP(0, 0), KP(0.55, 0.12), KP(1, 1) })
local pop = NS({ KP(0, 0), KP(1, 1) })
local function grow(a, b, c)
	if c then
		return NS({ KP(0, a), KP(0.5, b), KP(1, c) })
	end
	return NS({ KP(0, a), KP(1, b) })
end
local function scaled(a, b, c)
	return function(k)
		return grow(a * k, b * k, c and c * k)
	end
end
local function flicker()
	return NS({ KP(0, 0), KP(0.2, 0.7), KP(0.3, 0), KP(0.5, 0.8), KP(0.6, 0.05), KP(0.8, 0.9), KP(1, 1) })
end

-- dark indigo base, bright rim and white-hot core of one shape
local function stack(parent, name, base, size, rimColor, coreColor, darkColor)
	em(parent, name .. "Dark", with(base, {
		Color = CS(darkColor or INDIGO),
		Size = size(1.15),
		Transparency = NS({ KP(0, 0.2), KP(0.6, 0.35), KP(1, 1) }),
		ZOffset = 0.5,
	}))
	em(parent, name .. "Rim", with(base, {
		Color = CS(rimColor or BRIGHT),
		LightEmission = 0.8,
		Size = size(1.0),
		Transparency = NS({ KP(0, 0.1), KP(0.6, 0.25), KP(1, 1) }),
		ZOffset = 1,
	}))
	em(parent, name .. "Core", with(base, {
		Color = CS({ CK(0, WHITE), CK(1, coreColor or RIM) }),
		LightEmission = 1,
		Brightness = 3,
		Size = size(0.82),
		Transparency = fade,
		ZOffset = 1.5,
	}))
end

local function shake(parent, csv)
	local a = att(parent, "Shake")
	a:SetAttribute("CameraShake", csv)
end

local function craters(p, offset, radius, count, extra)
	local rocks = att(p, "Rocks", offset)
	rocks:AddTag("CraterVFX")
	local attrs = {
		Shape = "Ring", Fill = true, EmissionStart = "Progressive", Radius = radius, Variance = radius * 0.25, Duration = 0.3,
		Count = R(count, count + 4), Lifetime = R(1.4, 2.2), Size = Vector3.new(3.4, 1.8, 2.6), SizeScale = R(0.7, 1.4),
		Collision = false, MatchGround = true, YOffset = 0.5, AngleX = R(25, 50), SpawnTime = R(0.05, 0.25), DespawnTime = R(0.8, 1.1),
	}
	for k, v in extra or {} do
		attrs[k] = v
	end
	for k, v in attrs do
		rocks:SetAttribute(k, v)
	end
end

-- the scorch under a strike: dark decals that outlast the flash
local function scorch(g, life, a, b)
	em(g, "ScorchInk", with(FLAT, { Texture = TEX.ink, Color = CS(INDIGO), Lifetime = R(life), Size = grow(a * 0.5, a, a * 1.04), Transparency = NS({ KP(0, 0.25), KP(0.6, 0.35), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.1 }))
	em(g, "ScorchCracks", with(FLAT, { Texture = TEX.crackDark, Color = CS(INDIGO), Lifetime = R(life), Size = grow(b * 0.55, b, b * 1.04), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
	em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, BRIGHT), CK(1, INDIGO) }), LightEmission = 1, Brightness = 2, Lifetime = R(math.min(life, 1.4)), Size = grow(b * 0.6, b), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
end

function _G.buildThunderApeFX(effects)
	local old = effects:FindFirstChild("ThunderApe")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ThunderApe"

	----------------------------------------------------------------------
	-- Windup tells (follow a body part)
	----------------------------------------------------------------------

	-- EyeFlare (each eye, every windup): a cyan star, a held glow, a needle.
	do
		local p = part(root, "EyeFlare", nil, { AuthoredSeconds = 0.6 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.4, RIM), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.22), Size = grow(0.8, 7, 0), Rotation = R(-8, 8), ZOffset = 2 })
		em(p, "Pop", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.28), Size = grow(3, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.5 })
		em(p, "Hold", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.12, 0.2), Rate = 20, Size = grow(1.8, 1), Transparency = NS({ KP(0, 0.3), KP(1, 0.85) }), LockedToPart = true, ZOffset = 1.5 }, { EmitDuration = 0.6 })
		em(p, "Needle", { Texture = TEX.line, Color = CS(RIM), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, Speed = R(10, 16), Lifetime = R(0.25), Size = grow(5, 0.4), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 2 })
	end

	-- FistCharge (windup on a knuckle, 1.0 s authored, refit): a glow swells
	-- over an indigo base, motes and lines are drawn in, two rings close, arcs
	-- crackle on the fist, a star pops when it is ready.
	do
		local p = part(root, "FistCharge", Vector3.new(8, 8, 8), { AuthoredSeconds = 1.0 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(1.0), Size = grow(1, 10), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 3, Lifetime = R(1.0), Size = grow(0.5, 6.5), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 34, Lifetime = R(0.3, 0.45), Speed = R(14, 22), Size = grow(1.0, 0.1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 1.0 })
		em(p, "Pull", { Texture = TEX.line, Color = CS(RIM), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 14, Lifetime = R(0.3, 0.45), Speed = R(26, 34), Size = grow(5, 0.6), Transparency = NS({ KP(0, 1), KP(0.3, 0.2), KP(1, 0.8) }) }, { EmitDuration = 0.9, EmitDelay = 0.1 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.9), Size = grow(14, 1.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.1 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.5), Size = grow(9, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.3) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 0.5 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 12, Lifetime = R(0.12, 0.2), Size = grow(5, 4), Rotation = R(0, 360), Transparency = flicker(), LockedToPart = true, ZOffset = 2 }, { EmitDuration = 1.0 })
		em(p, "Ready", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.25), Size = grow(1, 10, 0), ZOffset = 3, LockedToPart = true }, { EmitDelay = 0.8 })
	end

	-- SnapFlare (the short windups): a big star the instant the move begins.
	do
		local p = part(root, "SnapFlare", nil, { AuthoredSeconds = 0.3 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.5, RIM), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.3), Size = grow(1, 12, 0), Rotation = R(-10, 10), ZOffset = 3, LockedToPart = true })
		em(p, "Pop", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.14), Size = grow(5, 12), Transparency = pop, ZOffset = 2, LockedToPart = true })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.3), Size = grow(14, 2), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(1, 0.2) }), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, Lifetime = R(0.15), Size = grow(6, 5), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 4 })
	end

	-- SigilFlare (the chest drum, facing out, windup hold 1.0 s authored): a
	-- turning sigil on an indigo disc, a glow, a ring, a flash at the end.
	do
		local p = part(root, "SigilFlare", Vector3.new(14, 14, 2), { AuthoredSeconds = 1.0 })
		em(p, "Under", with(FACE, { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(1.0), Size = grow(3, 16), Transparency = NS({ KP(0, 1), KP(0.15, 0.4), KP(0.9, 0.5), KP(1, 1) }), LockedToPart = true, ZOffset = 0.2 }))
		em(p, "Sigil", with(FACE, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.0), Size = grow(8, 14), RotSpeed = R(60), Rotation = R(0, 0), Transparency = NS({ KP(0, 1), KP(0.12, 0.15), KP(0.85, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 0.6 }))
		em(p, "Mandala", with(FACE, { Texture = TEX.mandala, Color = CS(RIM), LightEmission = 1, Lifetime = R(1.0), Size = grow(6, 10), RotSpeed = R(-50), Transparency = NS({ KP(0, 1), KP(0.12, 0.5), KP(0.85, 0.5), KP(1, 1) }), LockedToPart = true, ZOffset = 0.8 }))
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 3, Lifetime = R(1.0), Size = grow(0.5, 8), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.15), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Ring", with(FACE, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.5), Size = grow(2, 20), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.4 }), { EmitDelay = 0.85 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.16), Size = grow(6, 18), Transparency = pop, ZOffset = 3 }, { EmitDelay = 0.85 })
	end

	----------------------------------------------------------------------
	-- Beats and roars
	----------------------------------------------------------------------

	-- BeatPulse (a chest beat, on ChestBeatL/R_FX facing out): a ring pulse, a
	-- thunderclap flash, a star, crackling arcs, sparks and fur dust.
	do
		local p = part(root, "BeatPulse", Vector3.new(2, 2, 2))
		em(p, "Ring", with(FACE, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.4), Size = grow(2, 26), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(p, "RingSpiky", with(FACE, { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.5), Size = grow(2, 32), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.06 })
		em(p, "Clap", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.12), Size = grow(6, 20), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.28), Size = grow(2, 16, 0), ZOffset = 3 })
		em(p, "Arcs", with(FACE, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(6, 22), Transparency = NS({ KP(0, 0), KP(0.5, 0.4), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1 }))
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(70, 70), Speed = R(16, 34), Acceleration = Vector3.new(0, -20, 0), Lifetime = R(0.4, 0.8), Size = grow(0.6, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 14 })
		em(p, "Fur", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Front, Speed = R(8, 16), Drag = 3, Lifetime = R(0.7, 1.1), Size = grow(3, 9), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
		shake(p, "Custom,30~110,0.7,0.35,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- RoarShock (the roar release, at the Mouth, facing the roar, authored r20):
	-- the roar is thrown forward, not around the head: shock rings fly out of
	-- the muzzle and widen as they go, a cone of wind lines and forked arcs, a
	-- gust of storm cloud. On the floor (the Ground attachment, dropped to the
	-- floor by code) a shock ring runs out to the stun radius over an indigo
	-- copy, a dust wall is shoved outward, ground arcs and chips. Nothing stays
	-- on the floor once it has passed: no disc.
	do
		local p = part(root, "RoarShock", Vector3.new(1, 1, 1), { AuthoredRadius = 20 })
		local fly = { Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, Speed = R(70), Drag = 2.2 }
		em(p, "WaveDark", with(fly, { Texture = TEX.ringThick, Color = CS(INDIGO), Lifetime = R(0.55), Size = grow(6, 40), Transparency = NS({ KP(0, 0.35), KP(0.6, 0.5), KP(1, 1) }), ZOffset = 0.5 }), { EmitCount = 1 })
		em(p, "Wave", with(fly, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.55), Size = grow(5, 36), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1 }), { EmitCount = 1 })
		em(p, "Wave2", with(fly, { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Speed = R(58), Lifetime = R(0.6), Size = grow(4, 34), Rotation = R(0, 360), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.35), KP(1, 1) }), ZOffset = 1.1 }), { EmitDelay = 0.12 })
		em(p, "Wave3", with(fly, { Texture = TEX.elecRing, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Speed = R(48), Lifetime = R(0.6), Size = grow(3, 30), RotSpeed = R(-140, 140), Rotation = R(0, 360), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1.2 }), { EmitDelay = 0.24 })
		em(p, "Breath", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(22, 8), Speed = R(90, 150), Drag = 1.5, Lifetime = R(0.3, 0.5), Size = grow(20, 4), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }) }, { EmitCount = 20 })
		em(p, "Forks", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 20), Speed = R(40, 80), Drag = 2.5, Lifetime = R(0.18, 0.3), Size = grow(10, 16), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 7 })
		em(p, "Gust", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(26, 18), Speed = R(40, 70), Drag = 2.5, Lifetime = R(0.9, 1.4), Size = grow(5, 18), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-40, 40) }, { EmitCount = 12 })
		em(p, "GustDark", { Texture = TEX.puff, Color = CS(INDIGO), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(18, 12), Speed = R(30, 55), Drag = 2.5, Lifetime = R(0.8, 1.2), Size = grow(5, 15), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360), ZOffset = -0.5 }, { EmitCount = 7 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(5, 16), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.3), Size = grow(2, 18, 0), ZOffset = 3 })
		local g = att(p, "Ground", Vector3.new(0, -20, 0))
		em(g, "FloorDark", with(FLAT, { Texture = TEX.ringThick, Color = CS(INDIGO), Lifetime = R(0.6), Size = grow(3, 42), Transparency = NS({ KP(0, 0.25), KP(0.7, 0.45), KP(1, 1) }), ZOffset = 0.3 }))
		em(g, "Floor", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.6), Size = grow(2, 40), Transparency = NS({ KP(0, 0.05), KP(0.7, 0.25), KP(1, 1) }), ZOffset = 1 }))
		em(g, "FloorCrackle", with(FLAT, { Texture = TEX.elecRing, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Lifetime = R(0.6), Size = grow(2, 39), RotSpeed = R(-120, 120), Rotation = R(0, 360), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1.2 }), { EmitDelay = 0.05 })
		em(g, "FloorArcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.45), Size = grow(10, 30), Transparency = NS({ KP(0, 0.1), KP(0.3, 0.6), KP(0.5, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "FloorDust", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.75), Size = grow(3, 40), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(36, 52), Drag = 1.6, Lifetime = R(0.9, 1.3), Size = grow(4, 12), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 22 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(20, 40), Acceleration = Vector3.new(0, -70, 0), Lifetime = R(0.6, 1.0), Size = grow(1.5, 1.0), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 10 })
		shake(p, "Custom,30~120,0.9,0.5,14,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- RoarGather (roar windups, on the floor under the ape, authored r20 over
	-- 1.3 s, refit): the storm draws in before the roar: dust and wind lines
	-- dragged in along the ground from the stun radius, sparks lifting, a lit
	-- crack spreading under the feet, ground arcs crackling faster.
	do
		local p = part(root, "RoarGather", Vector3.new(40, 0.4, 40), { AuthoredRadius = 20, AuthoredSeconds = 1.3 })
		local edge = { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, EmissionDirection = Enum.NormalId.Top }
		em(p, "InDust", with(edge, { Texture = TEX.puff, Color = CS(DUST), Rate = 32, Speed = R(16, 22), Lifetime = R(0.8, 1.0), Size = grow(6, 11, 3), Transparency = NS({ KP(0, 1), KP(0.3, 0.45), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-60, 60) }), { EmitDuration = 1.2 })
		em(p, "InLines", with(edge, { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Brightness = 2, Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 22, Speed = R(30, 40), Lifetime = R(0.4, 0.55), Size = grow(14, 3), Transparency = NS({ KP(0, 1), KP(0.25, 0.2), KP(1, 0.9) }) }), { EmitDuration = 1.2 })
		local g = att(p, "Ground", Vector3.new(0, 0.05, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INDIGO), Lifetime = R(1.6), Size = grow(4, 16, 17), Transparency = NS({ KP(0, 0.4), KP(0.7, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, BRIGHT), CK(1, INDIGO) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.3), Size = grow(3, 15), Transparency = NS({ KP(0, 0.9), KP(0.8, 0.15), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Rate = 7, Lifetime = R(0.12, 0.2), Size = grow(10, 16), Transparency = flicker(), Rotation = R(0, 360), ZOffset = 1 }), { EmitDuration = 1.3 })
		em(g, "Lift", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(4, 10), Rate = 14, Lifetime = R(0.6, 1.0), Size = grow(0.7, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 1.3 })
	end

	-- BeatGround (each chest beat thumps the floor under the ape): a dust ring,
	-- a short bright ring over an indigo one, grit hopping.
	do
		local p = part(root, "BeatGround", Vector3.new(4, 0.2, 4))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "RingDark", with(FLAT, { Texture = TEX.ringThick, Color = CS(INDIGO), Lifetime = R(0.4), Size = grow(4, 30), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), ZOffset = 0.3 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(3, 28), Transparency = NS({ KP(0, 0.15), KP(1, 1) }), ZOffset = 1 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(3, 26), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Grit", { Texture = TEX.chips, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(8, 16), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.35, 0.55), Size = grow(1.0, 0.7), RotSpeed = R(-300, 300) }, { EmitCount = 6 })
	end

	----------------------------------------------------------------------
	-- Arm attacks
	----------------------------------------------------------------------

	-- Crescent (the club swing and the backhand): a crescent of storm sweeping
	-- the cone, a forked arc inside it, wind, sparks, a slate smear.
	local function crescent(name, dir, rot)
		local p = part(root, name, Vector3.new(1, 1, 1))
		local sweep = att(p, "Sweep")
		local arc = { Texture = TEX.arc, Lifetime = R(0.24), EmissionDirection = dir, Speed = R(56), Drag = 7, Rotation = R(rot) }
		stack(sweep, "Arc", arc, scaled(15, 22, 24), BRIGHT, RIM)
		em(sweep, "Echo", { Texture = TEX.arcSoft, Color = CS(RIM), LightEmission = 1, EmissionDirection = dir, Speed = R(44), Drag = 6, Rotation = R(rot), Lifetime = R(0.32), Size = grow(18, 28), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.8 }, { EmitDelay = 0.04 })
		em(sweep, "Bolt", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, EmissionDirection = dir, Speed = R(40), Drag = 6, Rotation = R(rot - 10, rot + 10), Lifetime = R(0.22), Size = grow(12, 18), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }), ZOffset = 2 })
		em(sweep, "Wind", { Texture = TEX.streaks, Color = CS(RIM), LightEmission = 0.6, EmissionDirection = dir, SpreadAngle = Vector2.new(8, 25), Speed = R(60, 90), Lifetime = R(0.25, 0.35), Size = grow(10, 8), Rotation = R(90), Transparency = NS({ KP(0, 0.3), KP(1, 1) }) }, { EmitCount = 6 })
		em(sweep, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = dir, SpreadAngle = Vector2.new(35, 35), Speed = R(26, 50), Acceleration = Vector3.new(0, -24, 0), Lifetime = R(0.3, 0.6), Size = grow(0.7, 0) }, { EmitCount = 14 })
		em(sweep, "Smear", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = dir, Speed = R(10, 18), Drag = 4, Lifetime = R(0.5, 0.8), Size = grow(4, 11), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = grow(6, 14), Transparency = pop })
		shake(p, "Custom,25~80,0.35,0.25,16,0.02,1;1;1,0.05;0.05;0.05")
		return p
	end
	crescent("CrescentR", Enum.NormalId.Left, -25) -- the right fist sweeps right to left
	crescent("CrescentL", Enum.NormalId.Right, 25) -- mirrored

	-- StrikeBurst (club and backhand contact, on the cone): flash, star, spiky
	-- ring, rays, sparks, arcs, an ink blot, smoke.
	do
		local p = part(root, "StrikeBurst", Vector3.new(1, 1, 1))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.14), Size = grow(7, 18), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.26), Size = grow(2, 16, 0), ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(3, 22), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
		em(p, "Rays", { Texture = TEX.line, Color = CS(RIM), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(50, 90), Lifetime = R(0.2, 0.3), Size = grow(8, 1.5), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 14 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.2), Size = grow(8, 12), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 5 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(16, 40), Acceleration = Vector3.new(0, -26, 0), Lifetime = R(0.4, 0.9), Size = grow(0.7, 0) }, { EmitCount = 16 })
		em(p, "Ink", { Texture = TEX.ink, Color = CS(INDIGO), Lifetime = R(0.4), Size = grow(8, 14), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		em(p, "Smoke", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(70, 70), Speed = R(8, 16), Drag = 3, Lifetime = R(0.8, 1.2), Size = grow(4, 11), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 6 })
	end

	-- PoundFist (thunderPound, under each fist, ground): a lit crack under a
	-- dark one (0.8 s), a slate dust ring, forked ground arcs out to ~8 studs,
	-- chips, dust, flash, star, embers; Craters rocks.
	do
		local p = part(root, "PoundFist", Vector3.new(12, 0.2, 12), { AuthoredRadius = 4 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INDIGO), Lifetime = R(3), Size = grow(6, 12, 12.5), Transparency = NS({ KP(0, 0.1), KP(0.1, 0.1), KP(0.7, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, BRIGHT), CK(1, INDIGO) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.8), Size = grow(6, 12), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "ForkArcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.5), Size = grow(8, 17), Transparency = NS({ KP(0, 0), KP(0.3, 0.6), KP(0.45, 0.05), KP(0.7, 0.7), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(2, 18), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 10), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(14, 24), Drag = 4, Lifetime = R(0.7, 1.1), Size = grow(3, 9), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55), Speed = R(24, 44), Acceleration = Vector3.new(0, -80, 0), Lifetime = R(0.7, 1.1), Size = grow(1.6, 1.2), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 10 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(6, 14), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.24), Size = grow(1, 11, 0), ZOffset = 3 })
		em(g, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(6, 20), Acceleration = Vector3.new(0, -16, 0), Lifetime = R(0.5, 1.0), Size = grow(0.6, 0) }, { EmitCount = 10 })
		craters(p, Vector3.new(0, 0.5, 0), 4, 5)
		shake(p, "Custom,25~70,0.5,0.4,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- PoundRing (thunderPound, the area itself, authored r8): the lightning ring
	-- that is exactly the telegraph: thick, spiky and thin rings out to r8, a
	-- ring of crackling arcs, a dust wall, flash, embers.
	do
		local p = part(root, "PoundRing", Vector3.new(16, 0.2, 16), { AuthoredRadius = 8 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.4), Size = grow(1, 16), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.5), Size = grow(2, 16), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }))
		em(g, "Crackle", with(FLAT, { Texture = TEX.elecRing, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.45), Size = grow(2, 16), RotSpeed = R(120), Rotation = R(0, 360), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1.8 }))
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.5), Size = grow(8, 16), Transparency = NS({ KP(0, 0.2), KP(0.3, 0.6), KP(0.45, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.6), Size = grow(3, 17), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(18, 30), Drag = 4, Lifetime = R(0.8, 1.2), Size = grow(3, 8), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 16 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.16), Size = grow(8, 20), Transparency = pop, ZOffset = 3 })
		scorch(g, 3, 12, 16)
		craters(p, Vector3.new(0, 0.5, 0), 7, 10)
		shake(p, "Custom,25~75,0.9,0.45,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- PoundWave (poundWave, authored r16 over 0.45 s): a second ring that
	-- travels out to r16 with a crackling front, forked arcs on the ground,
	-- dust. PoundWaveEnd is the small burst when it arrives.
	do
		local p = part(root, "PoundWave", Vector3.new(32, 0.2, 32), { AuthoredRadius = 16, AuthoredSeconds = 0.45 })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Under", with(FLAT, { Texture = TEX.ringThick, Color = CS(INDIGO), Lifetime = R(0.45), Size = grow(4, 34), Transparency = NS({ KP(0, 0.3), KP(0.8, 0.4), KP(1, 1) }), ZOffset = 0.3 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.45), Size = grow(4, 32), Transparency = NS({ KP(0, 0.1), KP(0.8, 0.15), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "Front", with(FLAT, { Texture = TEX.elecRing, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Lifetime = R(0.45), Size = grow(4, 32), RotSpeed = R(-160, 160), Rotation = R(0, 360), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }), ZOffset = 1.8 }))
		em(g, "Thin", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.45), Size = grow(2, 30), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.2 }), { EmitDelay = 0.06 })
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.45), Size = grow(14, 34), Transparency = NS({ KP(0, 0.2), KP(0.3, 0.6), KP(0.5, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(3, 33), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(34, 50), Drag = 3, Lifetime = R(0.7, 1.0), Size = grow(3, 8), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		shake(p, "Custom,25~80,0.6,0.4,16,0.02,1;1;1,0.05;0.05;0.05")
		local e = part(root, "PoundWaveEnd", Vector3.new(1, 1, 1))
		em(e, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.14), Size = grow(5, 14), Transparency = pop, ZOffset = 3 })
		em(e, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.24), Size = grow(1, 10, 0), ZOffset = 3 })
		em(e, "Ring", with(FLAT, { Texture = TEX.ringThin, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.3), Size = grow(2, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(e, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(8, 22), Acceleration = Vector3.new(0, -22, 0), Lifetime = R(0.4, 0.8), Size = grow(0.6, 0) }, { EmitCount = 10 })
	end

	----------------------------------------------------------------------
	-- Body slam, rush, leaps
	----------------------------------------------------------------------

	-- BodyTrail (the dash, follows the chest): an indigo band and a white-blue
	-- band under the chest, wind lines, a glow, crackling arcs; the Wake
	-- attachment is dropped to the floor by code for dust and grit.
	do
		local p = part(root, "BodyTrail", Vector3.new(2, 2, 2))
		local top = att(p, "Top", Vector3.new(0, 8, 0))
		local mid = att(p, "Mid", Vector3.new(0, 2, 0))
		local bottom = att(p, "Bottom", Vector3.new(0, -8, 0))
		local wake = att(p, "Wake", Vector3.new(0, -14, 0))
		trail(p, "Dark", top, bottom, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS(INDIGO), Lifetime = 0.4, MinLength = 0.05, Transparency = NS({ KP(0, 0.2), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.3) }) })
		trail(p, "Bright", top, mid, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(0.4, RIM), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = 0.4, MinLength = 0.05, Transparency = NS({ KP(0, 0), KP(0.6, 0.35), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.2) }) })
		em(p, "Wind", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, Rate = 26, Speed = R(30, 50), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(15, 15), Lifetime = R(0.2, 0.3), Size = grow(14, 2), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 0.7 })
		em(p, "Aura", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, Rate = 12, Lifetime = R(0.3, 0.4), Size = grow(16, 6), Transparency = NS({ KP(0, 0.65), KP(1, 1) }), ZOffset = 0.5 }, { EmitDuration = 0.7 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Rate = 10, Lifetime = R(0.15, 0.25), Size = grow(9, 7), Rotation = R(0, 360), Transparency = flicker(), Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, ZOffset = 2 }, { EmitDuration = 0.7 })
		em(wake, "Dust", { Texture = TEX.puff, Color = CS(DUST), Rate = 20, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(50, 40), Speed = R(8, 18), Drag = 3, Lifetime = R(0.6, 1.0), Size = grow(5, 14), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 0.7 })
		em(wake, "Grit", { Texture = TEX.mote, Color = CS(SLATE), Rate = 14, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(40, 30), Speed = R(14, 26), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.3, 0.5), Size = NS(0.5) }, { EmitDuration = 0.7 })
	end

	-- LimbTrail (a fist or a foot during a rush): a dark and a bright ribbon
	-- and a few sparks.
	do
		local p = part(root, "LimbTrail", Vector3.new(1, 1, 1))
		local a = att(p, "A", Vector3.new(0, 2, 0))
		local b = att(p, "B", Vector3.new(0, -2, 0))
		trail(p, "Dark", a, b, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS(INDIGO), Lifetime = 0.3, MinLength = 0.05, Transparency = NS({ KP(0, 0.3), KP(1, 1) }), WidthScale = NS({ KP(0, 1.2), KP(1, 0.3) }) })
		trail(p, "Bright", a, b, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = 0.3, MinLength = 0.05, Transparency = NS({ KP(0, 0), KP(0.6, 0.4), KP(1, 1) }), WidthScale = NS({ KP(0, 0.8), KP(1, 0.1) }) })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS(RIM), LightEmission = 1, Rate = 14, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 8), Lifetime = R(0.2, 0.4), Size = grow(0.7, 0) }, { EmitDuration = 0.7 })
	end

	-- SpeedShed (rushes and leaps, a box over the torso that follows it): the
	-- body sheds storm as it moves: sparks, forked arcs and indigo cloud left
	-- hanging where it passed, so the path reads as a wake of lightning. Code
	-- sizes the box to the body.
	do
		local p = part(root, "SpeedShed", Vector3.new(12, 16, 12))
		local box = { Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, SpreadAngle = Vector2.new(180, 180) }
		em(p, "Sparks", with(box, { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.4, RIM), CK(1, BRIGHT) }), LightEmission = 1, Rate = 70, Speed = R(0, 3), Lifetime = R(0.35, 0.6), Size = grow(0.9, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }), { EmitDuration = 0.8 })
		em(p, "Arcs", with(box, { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 26, Speed = R(0), Lifetime = R(0.14, 0.26), Size = grow(7, 9), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }), { EmitDuration = 0.8 })
		em(p, "Cloud", with(box, { Texture = TEX.puff, Color = CS(INDIGO), Rate = 18, Speed = R(0, 2), Lifetime = R(0.45, 0.7), Size = grow(6, 11), Rotation = R(0, 360), RotSpeed = R(-40, 40), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), ZOffset = -0.5 }), { EmitDuration = 0.8 })
		em(p, "Glints", with(box, { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Rate = 8, Speed = R(0), Lifetime = R(0.2), Size = grow(1, 6, 0), ZOffset = 3 }), { EmitDuration = 0.8 })
	end

	-- Takeoff (a leap or dash starts, under a foot, ground): a flat ring, a dust
	-- ring, a blast of dust, chips, speed lines, flash, sparks.
	do
		local p = part(root, "Takeoff", Vector3.new(8, 0.2, 8))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(2, 22), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(2, 20), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Blast", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(16, 28), Drag = 3, Lifetime = R(0.7, 1.1), Size = grow(4, 12), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 40), Speed = R(18, 34), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.5, 0.8), Size = grow(1.4, 0.9), RotSpeed = R(-300, 300) }, { EmitCount = 6 })
		em(g, "Lines", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(50, 80), Lifetime = R(0.2, 0.3), Size = grow(9, 2), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 10 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(5, 13), Transparency = pop, ZOffset = 3 })
		em(g, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(10, 26), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.3, 0.6), Size = grow(0.6, 0) }, { EmitCount = 8 })
		shake(p, "Custom,25~70,0.4,0.3,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- RushSkid (the rush ends, between the fists): a flat ring, dust thrown
	-- ahead, grit, sparks and a short spray of arcs.
	do
		local p = part(root, "RushSkid", Vector3.new(8, 0.2, 4))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.35), Size = grow(2, 24), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 20), Speed = R(18, 34), Drag = 4, Lifetime = R(0.7, 1.1), Size = grow(4, 13), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 10 })
		em(g, "Grit", { Texture = TEX.mote, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 25), Speed = R(16, 30), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.35, 0.5), Size = NS(0.5) }, { EmitCount = 12 })
		em(g, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(50, 40), Speed = R(16, 36), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.3, 0.6), Size = grow(0.6, 0) }, { EmitCount = 10 })
		em(g, "Spray", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(45, 25), Speed = R(26, 46), Drag = 5, Lifetime = R(0.2, 0.3), Size = grow(8, 10), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 6 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = grow(5, 12), Transparency = pop, ZOffset = 3 })
		shake(p, "Custom,25~70,0.4,0.3,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- BellyWave (the body slam lands, under the chest): a wall of dust and a
	-- crackling wave thrown forward down the lane, a ring, chips, flash, star.
	do
		local p = part(root, "BellyWave", Vector3.new(10, 0.2, 10))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(6, 60), Speed = R(30, 54), Drag = 3, Lifetime = R(0.9, 1.4), Size = grow(5, 15), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 18 })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(2, 28), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.55), Size = grow(3, 26), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.5), Size = grow(10, 28), Transparency = NS({ KP(0, 0.2), KP(0.3, 0.6), KP(0.5, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(26, 48), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.7, 1.1), Size = grow(1.6, 1.2), RotSpeed = R(-300, 300) }, { EmitCount = 12 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.16), Size = grow(8, 20), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.28), Size = grow(2, 14, 0), ZOffset = 3 })
		shake(p, "Custom,25~90,1.0,0.45,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- SkySigil (skyfall, judgment and the lane: a storm-cloud sigil on the
	-- ground at the locked circle, authored r10 over 1.65 s, refit by code): the
	-- radius ring over an indigo disc, a fill that rises toward contact, a
	-- turning array, a ring closing from outside, crackling arcs, edge sparks.
	do
		local p = part(root, "SkySigil", Vector3.new(20, 0.2, 20), { AuthoredSeconds = 1.65, AuthoredRadius = 10 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		local life = R(1.65)
		em(g, "EdgeDark", with(FLAT, { Texture = TEX.ringThick, Color = CS(INDIGO), Lifetime = life, Size = grow(21, 21), Transparency = NS({ KP(0, 1), KP(0.08, 0.35), KP(0.92, 0.35), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Edge", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, BRIGHT), CK(0.8, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 2, Lifetime = life, Size = grow(20, 20), Transparency = NS({ KP(0, 1), KP(0.08, 0.1), KP(0.7, 0.2), KP(0.85, 0), KP(0.92, 0.3), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Fill", with(FLAT, { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 0.8, Lifetime = life, Size = grow(1, 19), Transparency = NS({ KP(0, 0.8), KP(1, 0.55) }), ZOffset = 0.5 }))
		em(g, "Array", with(FLAT, { Texture = TEX.sigil, Color = CS(RIM), LightEmission = 1, Lifetime = life, Size = grow(17, 17), RotSpeed = R(40), Transparency = NS({ KP(0, 1), KP(0.1, 0.5), KP(0.85, 0.45), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(WHITE), LightEmission = 1, Lifetime = life, Size = grow(11, 11), RotSpeed = R(-55), Transparency = NS({ KP(0, 1), KP(0.1, 0.6), KP(0.85, 0.55), KP(1, 1) }), ZOffset = 0.9 }))
		em(g, "Closing", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = life, Size = grow(34, 20), Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1.4 }))
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS(BRIGHT), LightEmission = 1, Rate = 5, Lifetime = R(0.2, 0.3), Size = grow(14, 18), Transparency = flicker(), Rotation = R(0, 360), ZOffset = 1.1 }), { EmitDuration = 1.65 })
		em(p, "EdgeSparks", { Texture = TEX.dot, Color = CS(RIM), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(3, 10), Rate = 30, Lifetime = R(0.4, 0.7), Size = grow(0.7, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 1.65 })
	end

	-- BoltWarn (stormBolt ground warning, authored r4 over 0.9 s): a crackling
	-- sigil with a steady ring and closing ring, flickering arcs.
	do
		local p = part(root, "BoltWarn", Vector3.new(8, 0.2, 8), { AuthoredSeconds = 0.9, AuthoredRadius = 4 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		local life = R(0.9)
		em(g, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = life, Size = grow(4, 9), Transparency = NS({ KP(0, 1), KP(0.1, 0.4), KP(0.9, 0.5), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Fill", with(FLAT, { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 0.8, Lifetime = life, Size = grow(1, 8), Transparency = NS({ KP(0, 0.8), KP(1, 0.5) }), ZOffset = 0.5 }))
		em(g, "Edge", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 2, Lifetime = life, Size = grow(8.5, 8.5), Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.85, 0.05), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS(RIM), LightEmission = 1, Lifetime = life, Size = grow(7, 7), RotSpeed = R(90), Transparency = NS({ KP(0, 1), KP(0.1, 0.4), KP(0.85, 0.35), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Closing", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = life, Size = grow(16, 8), Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1.4 }))
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS(WHITE), LightEmission = 1, Rate = 9, Lifetime = R(0.12, 0.2), Size = grow(7, 9), Transparency = flicker(), Rotation = R(0, 360), ZOffset = 1.1 }), { EmitDuration = 0.9 })
	end

	-- BoltStrike (stormBolt and visual bolts, at the ground, authored r4): the
	-- column itself is drawn by code beams; this is the ground end: a white
	-- flash, star, ring, lit crack and a scorch that stays 3 s, sparks, dust.
	do
		local p = part(root, "BoltStrike", Vector3.new(8, 0.2, 8), { AuthoredRadius = 4 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.18), Size = grow(8, 22), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.3), Size = grow(2, 16, 0), ZOffset = 3 })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(1, 10), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(7, 14), Transparency = NS({ KP(0, 0), KP(0.4, 0.5), KP(0.55, 0.05), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		scorch(g, 3, 8, 11)
		em(g, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55), Speed = R(14, 34), Acceleration = Vector3.new(0, -40, 0), Lifetime = R(0.4, 0.9), Size = grow(0.7, 0) }, { EmitCount = 14 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(10, 18), Drag = 4, Lifetime = R(0.6, 1.0), Size = grow(2, 7), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 6 })
		shake(p, "Custom,25~60,0.35,0.3,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- ScorchSpot (a spot of the lance's scorch line): a small scorch only.
	do
		local p = part(root, "ScorchSpot", Vector3.new(6, 0.2, 6))
		local g = att(p, "Ground", Vector3.new(0, 0.18, 0))
		scorch(g, 3, 7, 8)
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = grow(3, 8), Transparency = pop, ZOffset = 3 })
		em(g, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(8, 20), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.3, 0.7), Size = grow(0.5, 0) }, { EmitCount = 5 })
	end

	-- PillarImpact (skyfall and judgment landings, authored r10): a lightning
	-- pillar's ground end: white flash and star, three rings, a column of
	-- upward rays and a thick glow core, a dust wall, rocks and chips, a lit
	-- crack under a scorch that stays 3 s, Craters rocks, smoke, sparks.
	do
		local p = part(root, "PillarImpact", Vector3.new(20, 0.2, 20), { AuthoredRadius = 10 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		scorch(g, 3, 20, 26)
		em(g, "CrackLines", with(FLAT, { Texture = TEX.crackLines, Color = CS(SLATE), Lifetime = R(3), Size = grow(12, 26, 27), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.3 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.4), Size = grow(1, 40), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.55), Size = grow(2, 44), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }))
		em(g, "RingThin", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.8), Size = grow(2, 52), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.8 }), { EmitDelay = 0.08 })
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.5), Size = grow(14, 38), Transparency = NS({ KP(0, 0.1), KP(0.3, 0.6), KP(0.5, 0.05), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.6), Size = grow(3, 38), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(28, 48), Drag = 4, Lifetime = R(0.9, 1.4), Size = grow(5, 14), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 24 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(34, 66), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.8, 1.3), Size = grow(2, 1.5), RotSpeed = R(-400, 400), Rotation = R(0, 360) }, { EmitCount = 16 })
		em(g, "Chunks", { Texture = TEX.rock, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55), Speed = R(26, 52), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.8, 1.2), Size = grow(2.6, 2), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6), Speed = R(90, 150), Lifetime = R(0.35, 0.6), Size = grow(26, 6), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 18 })
		em(g, "Column", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(2, 2), Speed = R(60, 100), Lifetime = R(0.3, 0.5), Size = grow(9, 3), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitCount = 12 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 7, Lifetime = R(0.2), Size = grow(14, 40), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.34), Size = grow(3, 30, 0), ZOffset = 3 })
		em(g, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(8, 30), Acceleration = Vector3.new(0, 6, 0), Lifetime = R(1.2, 2.4), Size = grow(0.8, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 22 })
		em(g, "Smoke", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Speed = R(3, 9), Drag = 1.5, Lifetime = R(2, 3.2), Size = grow(6, 18), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-20, 20) }, { EmitCount = 9, EmitDelay = 0.1 })
		craters(p, Vector3.new(0, 0.5, 0), 11, 12)
		shake(p, "Explosion,30~150,2.4,0.9,20,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- Bolt (the beam look the runtime clones onto jittered segments for every
	-- bolt: Dark = indigo under, Glow = wide cyan, Core = thin white-hot), plus
	-- the LightningBeams add-on arc (Game Module only; code sets B).
	do
		local holder = part(root, "Bolt", Vector3.new(1, 1, 1))
		local function beam(name, props)
			local b = Instance.new("Beam")
			b.Name = name
			b.Segments = 1
			b.FaceCamera = true
			b.LightInfluence = 0
			b.Enabled = false
			for k, v in props do
				b[k] = v
			end
			b.Parent = holder
		end
		beam("Dark", { Color = CS(INDIGO), Transparency = NS(0.15), Width0 = 1, Width1 = 1 })
		beam("Glow", { Texture = TEX.dot, TextureMode = Enum.TextureMode.Stretch, TextureLength = 1, Color = CS(BRIGHT), LightEmission = 0.8, Brightness = 1.5, Transparency = NS(0.2), Width0 = 1, Width1 = 1 })
		beam("Core", { Color = CS(WHITE), LightEmission = 1, Brightness = 3, Transparency = NS(0), Width0 = 1, Width1 = 1 })
		local arc = att(holder, "Arc", Vector3.zero)
		for k, v in {
			Duration = 0.35, Thickness = 0.6, PartCount = 12, PulseSpeed = 12, FadeLength = 0.25, Frequency = 1.2, Speed = 6,
			Radius = R(0, 2), ThicknessMultiplier = R(0.4, 1), Color = RIM, MaxSparkCount = 3, SparkDistance = R(2, 5),
		} do
			arc:SetAttribute(k, v)
		end
		att(arc, "B", Vector3.new(0, -10, 0))
	end

	----------------------------------------------------------------------
	-- Boulder, lance
	----------------------------------------------------------------------

	-- BoulderRip (boulderHurl start, under the right fist, ground): chips and
	-- chunks tear up with dust, a crack, blue sparks drawn into the fist.
	do
		local p = part(root, "BoulderRip", Vector3.new(10, 0.2, 10), { AuthoredSeconds = 0.6 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INDIGO), Lifetime = R(2), Size = grow(6, 12, 12.5), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, BRIGHT), CK(1, INDIGO) }), LightEmission = 1, Lifetime = R(0.6), Size = grow(6, 12), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(14, 30), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.6, 1.0), Size = grow(1.6, 1.2), RotSpeed = R(-300, 300) }, { EmitCount = 10 })
		em(g, "Chunks", { Texture = TEX.rock, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(14, 28), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.8, 1.2), Size = grow(3, 2.2), RotSpeed = R(-200, 200) }, { EmitCount = 8 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(12, 22), Drag = 3, Lifetime = R(0.9, 1.4), Size = grow(4, 12), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 16 })
		em(g, "DustUp", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(10, 20), Drag = 2.5, Lifetime = R(0.9, 1.3), Size = grow(4, 11), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.6), Size = grow(3, 22), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), ZOffset = 0.4 }))
		local gather = att(p, "Gather", Vector3.new(0, 6, 0))
		em(gather, "Sparks", { Texture = TEX.glint, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 30, Lifetime = R(0.3, 0.45), Speed = R(14, 24), Size = grow(1.0, 0.1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }) }, { EmitDuration = 0.6 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.14), Size = grow(5, 12), Transparency = pop, ZOffset = 3 })
	end

	-- BoulderRock (the boulder itself, a stone mesh about 10 studs across:
	-- support for the skin, trail and charge, which carry the look).
	do
		local ok, rock = pcall(function()
			return game:GetService("AssetService"):CreateMeshPartAsync("rbxassetid://17608108317")
		end)
		if not ok then
			rock = Instance.new("Part")
			rock.Shape = Enum.PartType.Ball
		end
		rock.Name = "BoulderRock"
		rock.Anchored, rock.CanCollide, rock.CanQuery, rock.CanTouch, rock.CastShadow, rock.Massless = true, false, false, false, true, true
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(78, 84, 98)
		rock.Size = Vector3.new(10, 8.5, 9.5)
		rock.Transparency = 0
		rock.Parent = root
	end

	-- BoulderSkin (rides the boulder from the rip to the impact): crackling cyan
	-- arcs on its surface, a glow over an indigo base, shed chips and sparks;
	-- the Trail pair (dark under bright) is switched on by code at the throw.
	do
		local p = part(root, "BoulderSkin", Vector3.new(9, 9, 9))
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INDIGO), Rate = 8, Lifetime = R(0.25), Size = grow(15, 15), Transparency = NS({ KP(0, 0.75), KP(1, 1) }), LockedToPart = true, ZOffset = -1 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 10, Lifetime = R(0.25), Size = grow(18, 15), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 28, Lifetime = R(0.12, 0.2), Size = grow(10, 9), Rotation = R(0, 360), Transparency = flicker(), LockedToPart = true, ZOffset = 2 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 30, Lifetime = R(0.3, 0.5), Size = grow(1.2, 0), Speed = R(0, 3), SpreadAngle = Vector2.new(180, 180), Transparency = NS({ KP(0, 0), KP(1, 1) }) })
		em(p, "Chips", { Texture = TEX.chips, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Sphere, Rate = 10, Speed = R(2, 8), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -40, 0), Lifetime = R(0.4, 0.7), Size = grow(1.4, 0.8), RotSpeed = R(-300, 300) })
		local top = att(p, "TrailTop", Vector3.new(0, 4.5, 0))
		local bottom = att(p, "TrailBottom", Vector3.new(0, -4.5, 0))
		trail(p, "TrailDark", top, bottom, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS(INDIGO), Lifetime = 0.35, MinLength = 0.05, Transparency = NS({ KP(0, 0.25), KP(1, 1) }), WidthScale = NS({ KP(0, 1.3), KP(1, 0.3) }) })
		trail(p, "TrailBright", top, bottom, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(0.25, RIM), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 4, Lifetime = 0.4, MinLength = 0.05, Transparency = NS({ KP(0, 0), KP(0.6, 0.35), KP(1, 1) }), WidthScale = NS({ KP(0, 0.9), KP(1, 0.1) }) })
	end

	-- BoulderCharge (the hold overhead before the throw, 0.25 s authored, on
	-- the rock): the stone goes white-hot with lightning: big forked arcs and
	-- glints all over it, a ring closing on it, a star at the throw.
	do
		local p = part(root, "BoulderCharge", Vector3.new(10, 10, 10), { AuthoredSeconds = 0.25 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.3), Size = grow(8, 20), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.3), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Forks", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Rate = 40, Speed = R(4, 10), Lifetime = R(0.1, 0.18), Size = grow(10, 14), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2.5 }, { EmitDuration = 0.25 })
		em(p, "Glints", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 20, Lifetime = R(0.15), Size = grow(1, 7, 0), ZOffset = 3, LockedToPart = true }, { EmitDuration = 0.25 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.25), Size = grow(26, 10), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0) }), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Ready", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.3), Size = grow(2, 24, 0), ZOffset = 3, LockedToPart = true }, { EmitDelay = 0.22 })
	end

	-- Shadow (boulder, on the ground at the circle): a slate blot that swells
	-- as the rock comes down.
	do
		local p = part(root, "Shadow", Vector3.new(10, 0.2, 10), { AuthoredSeconds = 0.4, AuthoredRadius = 5 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Blot", with(FLAT, { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(0.4), Size = grow(2, 9), Transparency = NS({ KP(0, 0.7), KP(1, 0.3) }), ZOffset = 0.2 }))
		em(g, "Edge", with(FLAT, { Texture = TEX.ringThin, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.4), Size = grow(11, 10.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.3), KP(1, 0.1) }), ZOffset = 1 }))
	end

	-- BoulderImpact (authored r5): dust burst, stone chips and chunks, a lit
	-- crack with radial arcs, a small scorch, flash, star, ring.
	do
		local p = part(root, "BoulderImpact", Vector3.new(10, 0.2, 10), { AuthoredRadius = 5 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		scorch(g, 3, 9, 12)
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(8, 16), Transparency = NS({ KP(0, 0), KP(0.4, 0.5), KP(0.55, 0.05), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(1, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(18, 30), Drag = 3, Lifetime = R(0.9, 1.4), Size = grow(4, 11), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 18 })
		em(g, "Plume", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(14, 26), Drag = 2.5, Lifetime = R(1.0, 1.5), Size = grow(4, 10), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-30, 30) }, { EmitCount = 8 })
		em(g, "Shock", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.45), Size = grow(2, 13), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.6 }), { EmitDelay = 0.04 })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.6), Size = grow(2, 12), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(24, 46), Acceleration = Vector3.new(0, -80, 0), Lifetime = R(0.7, 1.1), Size = grow(1.8, 1.2), RotSpeed = R(-400, 400) }, { EmitCount = 12 })
		em(g, "Chunks", { Texture = TEX.rock, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55), Speed = R(18, 36), Acceleration = Vector3.new(0, -80, 0), Lifetime = R(0.7, 1.0), Size = grow(2.6, 2), RotSpeed = R(-300, 300) }, { EmitCount = 5 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(7, 16), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.26), Size = grow(2, 13, 0), ZOffset = 3 })
		craters(p, Vector3.new(0, 0.5, 0), 5, 7)
		shake(p, "Custom,25~60,0.6,0.35,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- LanceForm (thunderLance windup on the right fist, 1.0 s, facing the
	-- lane): a javelin of lightning forms: a bright core streak, spiralling
	-- arcs, a growing flare, a swelling glow, motes drawn in, a closing ring.
	do
		local p = part(root, "LanceForm", Vector3.new(6, 6, 6), { AuthoredSeconds = 1.0 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(1.0), Size = grow(1, 11), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 3, Lifetime = R(1.0), Size = grow(0.5, 8), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.15), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Spear", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Brightness = 3, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, Speed = R(2), Rate = 10, Lifetime = R(0.22), Size = grow(8, 22), Transparency = NS({ KP(0, 0.6), KP(0.3, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 2 }, { EmitDuration = 1.0 })
		em(p, "Spiral", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 16, Lifetime = R(0.12, 0.22), Size = grow(7, 6), Rotation = R(0, 360), RotSpeed = R(-400, 400), Transparency = flicker(), LockedToPart = true, ZOffset = 2.2 }, { EmitDuration = 1.0 })
		em(p, "Flare", { Texture = TEX.glint, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 4, Lifetime = R(1.0), Size = grow(0.5, 14), Transparency = NS({ KP(0, 0.9), KP(0.85, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 3 })
		em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 30, Lifetime = R(0.3, 0.45), Speed = R(14, 22), Size = grow(1.0, 0.1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 1.0 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.9), Size = grow(16, 2), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.1 })
	end

	-- LanceBolt (the thunderLance projectile, flying along -Z): a javelin of
	-- lightning about 22 studs long: a jagged white core beam over a wide cyan
	-- glow and an indigo shadow beam, a white-hot head with a star, a crossed
	-- trail pair (dark under bright, reads from any side), arcs and sparks
	-- shed behind it so the path stays lit for a moment.
	do
		local p = part(root, "LanceBolt", Vector3.new(2, 2, 2))
		local head = att(p, "Head", Vector3.new(0, 0, -4))
		local tail = att(p, "Tail", Vector3.new(0, 0, 18))
		local function beam(name, props)
			local bm = Instance.new("Beam")
			bm.Name = name
			bm.Attachment0, bm.Attachment1 = tail, head
			bm.FaceCamera = true
			bm.Segments = 1
			bm.LightInfluence = 0
			bm.Enabled = false
			for k, v in props do
				bm[k] = v
			end
			bm.Parent = p
		end
		beam("Dark", { Color = CS(INDIGO), Transparency = NS({ KP(0, 1), KP(0.3, 0.35), KP(0.9, 0.25), KP(1, 0.6) }), Width0 = 4, Width1 = 2.5, ZOffset = 0 })
		beam("Glow", { Texture = TEX.dot, TextureMode = Enum.TextureMode.Stretch, Color = CS(BRIGHT), LightEmission = 1, Brightness = 2, Transparency = NS({ KP(0, 1), KP(0.3, 0.35), KP(1, 0.15) }), Width0 = 6, Width1 = 4, ZOffset = 0.5 })
		beam("Core", { Texture = TEX.zig, TextureMode = Enum.TextureMode.Stretch, TextureSpeed = 4, Color = CS({ CK(0, RIM), CK(1, WHITE) }), LightEmission = 1, Brightness = 4, Transparency = NS({ KP(0, 0.7), KP(0.4, 0.05), KP(1, 0) }), Width0 = 4, Width1 = 2.5, ZOffset = 1 })
		local up, down = att(p, "TrailUp", Vector3.new(0, 1.6, 0)), att(p, "TrailDown", Vector3.new(0, -1.6, 0))
		local left, right = att(p, "TrailL", Vector3.new(-1.6, 0, 0)), att(p, "TrailR", Vector3.new(1.6, 0, 0))
		for _, pair in { { up, down, "V" }, { left, right, "H" } } do
			trail(p, "Dark" .. pair[3], pair[1], pair[2], { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS(INDIGO), Lifetime = 0.3, MinLength = 0.05, Transparency = NS({ KP(0, 0.3), KP(1, 1) }), WidthScale = NS({ KP(0, 1.4), KP(1, 0.2) }) })
			trail(p, "Bright" .. pair[3], pair[1], pair[2], { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(0.4, RIM), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 3, Lifetime = 0.25, MinLength = 0.05, Transparency = NS({ KP(0, 0), KP(0.6, 0.4), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.1) }) })
		end
		em(head, "HeadGlow", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 4, Rate = 40, Lifetime = R(0.08, 0.12), Size = grow(9, 6), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 2 })
		em(head, "HeadStar", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Rate = 14, Lifetime = R(0.12), Size = grow(4, 12, 0), Rotation = R(0, 360), LockedToPart = true, ZOffset = 3 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Box, Rate = 40, Lifetime = R(0.12, 0.22), Size = grow(6, 8), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, Rate = 60, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 8), Lifetime = R(0.3, 0.5), Size = grow(0.9, 0), Transparency = NS({ KP(0, 0), KP(1, 1) }) })
	end

	-- BoulderShadow (follows under the thrown rock, on the floor): an indigo
	-- blot with a cyan rim; code resizes it as the rock comes down.
	do
		local p = part(root, "BoulderShadow", Vector3.new(4, 0.2, 4))
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "Blot", with(FLAT, { Texture = TEX.dot, Color = CS(INDIGO), Rate = 40, Lifetime = R(0.08), Size = NS(8), Transparency = NS(0.35), LockedToPart = true, ZOffset = 0.2 }))
		em(g, "Rim", with(FLAT, { Texture = TEX.ringThin, Color = CS(BRIGHT), LightEmission = 1, Rate = 40, Lifetime = R(0.08), Size = NS(9), Transparency = NS(0.3), LockedToPart = true, ZOffset = 0.5 }))
	end

	-- LanceFlash (thunderLance strike, at each end of the bolt): a white flash,
	-- a star and a ring. The bolt itself is code beams.
	do
		local p = part(root, "LanceFlash", Vector3.new(1, 1, 1))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.12), Size = grow(6, 16), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.32), Size = grow(2, 24, 0), ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(2, 20), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(16, 40), Acceleration = Vector3.new(0, -24, 0), Lifetime = R(0.4, 0.9), Size = grow(0.7, 0) }, { EmitCount = 14 })
		shake(p, "Custom,30~100,0.9,0.4,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	----------------------------------------------------------------------
	-- Storm call, judgment, phases
	----------------------------------------------------------------------

	-- StormGather (stormCall windup, at the BackTop, 1.2 s): a storm cloud
	-- builds on the hump: indigo and slate puffs, wisps, a glow and arcs inside.
	do
		local p = part(root, "StormGather", Vector3.new(8, 4, 8), { AuthoredSeconds = 1.2 })
		em(p, "CloudDark", { Texture = TEX.puff, Color = CS(INDIGO), Rate = 14, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(3, 8), Drag = 1, Lifetime = R(1.0, 1.5), Size = grow(7, 20), Transparency = NS({ KP(0, 0.7), KP(0.3, 0.3), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-30, 30) }, { EmitDuration = 1.2 })
		em(p, "CloudSlate", { Texture = TEX.puff, Color = CS(SLATE), Rate = 8, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(2, 6), Drag = 1, Lifetime = R(1.0, 1.5), Size = grow(5, 16), Transparency = NS({ KP(0, 0.8), KP(0.3, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 1.2 })
		em(p, "Wisps", { Texture = TEX.wisp, Color = CS(DUST), Rate = 6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 12), Lifetime = R(0.9, 1.3), Size = grow(5, 12), Transparency = NS({ KP(0, 0.6), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 1.2 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.2), Size = grow(1, 14), Transparency = NS({ KP(0, 0.9), KP(0.85, 0.5), KP(1, 1) }), ZOffset = 1 })
		em(p, "Arcs", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 9, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Lifetime = R(0.12, 0.22), Size = grow(10, 8), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitDuration = 1.2 })
	end

	-- JudgeCloud (judgment windup, a dark cloud above the ape, 1.6 s): a mass
	-- of indigo and slate cloud, a dim glow inside, forked flickers, lightning
	-- glints. It is a cloud, not a ring or crown.
	do
		local p = part(root, "JudgeCloud", Vector3.new(40, 6, 40), { AuthoredSeconds = 1.6 })
		em(p, "Dark", { Texture = TEX.puff, Color = CS(INDIGO), Shape = Enum.ParticleEmitterShape.Box, Rate = 18, Lifetime = R(1.2, 1.8), Size = grow(14, 28), Transparency = NS({ KP(0, 1), KP(0.25, 0.35), KP(0.8, 0.45), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-15, 15), ZOffset = 0.3 }, { EmitDuration = 1.6 })
		em(p, "Slate", { Texture = TEX.puff, Color = CS(SLATE), Shape = Enum.ParticleEmitterShape.Box, Rate = 10, Lifetime = R(1.2, 1.8), Size = grow(10, 22), Transparency = NS({ KP(0, 1), KP(0.3, 0.5), KP(0.8, 0.6), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.6 }, { EmitDuration = 1.6 })
		em(p, "Inner", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, Rate = 3, Lifetime = R(0.8, 1.2), Size = grow(18, 26), Transparency = NS({ KP(0, 1), KP(0.3, 0.8), KP(1, 1) }), ZOffset = 1 }, { EmitDuration = 1.6 })
		em(p, "Forks", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Box, Rate = 5, Lifetime = R(0.12, 0.22), Size = grow(18, 14), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitDuration = 1.6 })
		em(p, "Glints", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Shape = Enum.ParticleEmitterShape.Box, Rate = 1.5, Lifetime = R(0.25), Size = grow(8, 20, 0), ZOffset = 3 }, { EmitDuration = 1.6 })
	end

	-- BoltHit (a bolt strikes the ape, judgment take-off; also an arrival flare):
	-- a white flash, a star, two rings, rays, sparks.
	do
		local p = part(root, "BoltHit", Vector3.new(1, 1, 1))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 8, Lifetime = R(0.25), Size = grow(14, 44), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), ZOffset = 4 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.4), Size = grow(4, 34, 0), ZOffset = 4 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(3, 38), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "RingSpiky", { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.55), Size = grow(3, 46), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 }, { EmitDelay = 0.08 })
		em(p, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(60, 110), Lifetime = R(0.3, 0.55), Size = grow(16, 3), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 22 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(14, 40), Drag = 2, Acceleration = Vector3.new(0, -16, 0), Lifetime = R(0.8, 1.6), Size = grow(0.8, 0) }, { EmitCount = 24 })
		shake(p, "Explosion,30~140,2.0,0.7,18,0.02,1;1;1,0.08;0.08;0.08")
	end

	-- PhaseBurst (phaseRoar release on the floor, authored r14): a storm
	-- sigil blooms and spins out over an indigo disc, three shock rings, a
	-- pillar of rays, motes spiralling up, dust, flash. PhaseArrival is the
	-- body flare when the phase begins (tinted violet in phase 3 by code).
	do
		local p = part(root, "PhaseBurst", Vector3.new(28, 0.2, 28), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "SigilDark", with(FLAT, { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(1.6), Size = grow(6, 28, 30), Transparency = NS({ KP(0, 0.3), KP(0.5, 0.45), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(0.5, BRIGHT), CK(1, RIM) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.6), Size = grow(6, 28, 32), RotSpeed = R(90), Transparency = NS({ KP(0, 0.1), KP(0.55, 0.25), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(WHITE), LightEmission = 1, Lifetime = R(1.4), Size = grow(4, 24, 26), RotSpeed = R(-70), Transparency = NS({ KP(0, 0.1), KP(0.55, 0.3), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.45), Size = grow(1, 30), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "Ring2", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.6), Size = grow(2, 32), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.1 })
		em(g, "Ring3", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.9), Size = grow(2, 40), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.8 }), { EmitDelay = 0.22 })
		em(g, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.5), Size = grow(14, 30), Transparency = NS({ KP(0, 0.1), KP(0.3, 0.6), KP(0.5, 0.05), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.9 }))
		em(g, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(70, 120), Lifetime = R(0.5, 0.8), Size = grow(18, 4), Transparency = NS({ KP(0, 0), KP(1, 1) }), Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume }, { EmitCount = 22 })
		em(g, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, Speed = R(6, 14), Lifetime = R(1.2, 2), Size = grow(1.2, 0), Acceleration = Vector3.new(0, 6, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 26 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(10, 30), Transparency = pop, ZOffset = 3 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(14, 26), Drag = 3, Lifetime = R(0.9, 1.4), Size = grow(4, 12), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		shake(p, "Explosion,30~150,2.0,0.9,18,0.02,1;1;1,0.08;0.08;0.08")
		local a = part(root, "PhaseArrival", Vector3.new(8, 8, 8))
		em(a, "Flames", { Texture = TEX.flameBurst, Color = CS({ CK(0, WHITE), CK(0.5, BRIGHT), CK(1, RIM) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Speed = R(10, 22), Drag = 2, Lifetime = R(0.5, 0.9), Size = grow(6, 16), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(a, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(12, 34), Transparency = pop, ZOffset = 3 })
		em(a, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(4, 40), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(a, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.35), Size = grow(3, 28, 0), ZOffset = 3 })
		em(a, "Motes", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(8, 22), Drag = 1.5, Acceleration = Vector3.new(0, 5, 0), Lifetime = R(1, 1.8), Size = grow(0.9, 0) }, { EmitCount = 24 })
	end

	-- Hits (on the struck player, near side, facing the ape): short and bright.
	local function hit(name, build)
		local p = part(root, name, Vector3.new(0.3, 0.3, 0.3))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(3, 8), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.22), Size = grow(1, 7, 0), ZOffset = 3 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Front, Speed = R(14, 32), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.3, 0.6), Size = grow(0.4, 0) }, { EmitCount = 14 })
		em(p, "Ink", { Texture = TEX.ink, Color = CS(INDIGO), Lifetime = R(0.3), Size = grow(4, 6.5), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.2), Size = grow(4, 6), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 3 })
		build(p)
	end
	hit("HitStorm", function(p)
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS(BRIGHT), LightEmission = 1, Lifetime = R(0.22), Size = grow(1, 8), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 })
	end)
	hit("HitHeavy", function(p)
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 14), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "Elec", { Texture = TEX.elecRing, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.34), Size = grow(2, 13), Rotation = R(0, 360), RotSpeed = R(-120, 120), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1.8 })
		em(p, "Rays", { Texture = TEX.line, Color = CS(RIM), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(40, 70), Lifetime = R(0.15, 0.25), Size = grow(6, 1), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 12 })
		em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(180, 180), Speed = R(6, 14), Drag = 3, Lifetime = R(0.5, 0.9), Size = grow(2.5, 6), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
	end)

	-- StunFlash (judgment hit): a big flash and star, a ring, a spin of arcs.
	do
		local p = part(root, "StunFlash", Vector3.new(0.3, 0.3, 0.3))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(6, 16), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.4), Size = grow(2, 14, 0), ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(2, 18), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "Arcs", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.25), Size = grow(7, 9), Rotation = R(0, 360), RotSpeed = R(-300, 300), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 6 })
	end

	-- StaggerPop (the ape is staggered, at Core): a pop, a star, a ring, motes.
	do
		local p = part(root, "StaggerPop", Vector3.new(4, 4, 4))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.16), Size = grow(8, 22), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.32), Size = grow(2, 22, 0), ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(3, 26), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "Arcs", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Lifetime = R(0.2), Size = grow(8, 12), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitCount = 5 })
		em(p, "Motes", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(6, 16), Drag = 1.5, Lifetime = R(0.6, 1.1), Size = grow(0.7, 0) }, { EmitCount = 12 })
	end

	----------------------------------------------------------------------
	-- Aura (always on; the runtime mounts each emitter into the body)
	----------------------------------------------------------------------

	-- AuraForearm (P1+): faint sparks on the forearm and knuckle bolts.
	do
		local p = part(root, "AuraForearm", Vector3.new(2, 2, 2))
		em(p, "Arcs", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Rate = 3, Lifetime = R(0.12, 0.2), Size = grow(5, 4), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, Rate = 4, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 7), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(0.4, 0.8), Size = grow(0.6, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
	end
	-- AuraArcs (P2+): bigger arcs on the fists and shoulders (code adds the
	-- jumping beams between them).
	do
		local p = part(root, "AuraArcs", Vector3.new(2, 2, 2))
		em(p, "Arcs", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 3, Lifetime = R(0.14, 0.24), Size = grow(9, 7), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS(BRIGHT), LightEmission = 1, Rate = 3, Lifetime = R(0.5, 0.8), Size = grow(5, 2), Transparency = NS({ KP(0, 0.7), KP(1, 1) }), LockedToPart = true })
	end
	-- AuraSigil (P2+, on the chest facing out): a steadily burning sigil.
	do
		local p = part(root, "AuraSigil", Vector3.new(2, 2, 2))
		em(p, "Under", with(FACE, { Texture = TEX.dot, Color = CS(INDIGO), Rate = 0.6, Lifetime = R(3), Size = NS(15), Transparency = NS({ KP(0, 1), KP(0.2, 0.65), KP(0.8, 0.65), KP(1, 1) }), LockedToPart = true, ZOffset = 0.1 }))
		em(p, "Sigil", with(FACE, { Texture = TEX.sigil, Color = CS(BRIGHT), LightEmission = 1, Brightness = 1.5, Rate = 0.6, Lifetime = R(3), Size = NS(12), RotSpeed = R(25), Transparency = NS({ KP(0, 1), KP(0.2, 0.45), KP(0.8, 0.45), KP(1, 1) }), LockedToPart = true, ZOffset = 0.4 }))
		em(p, "Glint", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Rate = 0.8, Lifetime = R(0.5), Size = grow(1, 7, 0), LockedToPart = true, ZOffset = 1 })
	end
	-- AuraGround (P2+): the floor answers the storm under the ape: a faint
	-- turning formation (lines only, no filled disc), ground arcs that crackle
	-- now and then, low slate mist creeping out.
	do
		local p = part(root, "AuraGround", Vector3.new(34, 0.2, 34))
		em(p, "Array", with(FLAT, { Texture = TEX.mandala, Color = CS(RIM), LightEmission = 0.8, Rate = 0.35, Lifetime = R(3), Size = NS(30), RotSpeed = R(12), Transparency = NS({ KP(0, 1), KP(0.2, 0.75), KP(0.8, 0.75), KP(1, 1) }), LockedToPart = true, ZOffset = 0.4 }))
		em(p, "Arcs", with(FLAT, { Texture = TEX.radial, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Rate = 1.2, Lifetime = R(0.15, 0.25), Size = grow(8, 14), Transparency = flicker(), Rotation = R(0, 360), ZOffset = 1 }))
		em(p, "Mist", { Texture = TEX.puff, Color = CS(SLATE), Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Rate = 2, Speed = R(1, 3), Lifetime = R(2.5, 3.5), Size = grow(5, 10), Rotation = R(0, 360), RotSpeed = R(-15, 15), Transparency = NS({ KP(0, 1), KP(0.3, 0.75), KP(1, 1) }) })
	end
	-- AuraCloud (shoulders and back, P1+): slow storm-cloud wisps.
	do
		local p = part(root, "AuraCloud", Vector3.new(2, 2, 2))
		em(p, "Puff", { Texture = TEX.puff, Color = CS(INDIGO), Rate = 2.2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(1.5, 4), Drag = 0.5, Lifetime = R(2.2, 3.2), Size = grow(5, 12), Transparency = NS({ KP(0, 1), KP(0.2, 0.55), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-20, 20) })
		em(p, "Wisp", { Texture = TEX.wisp, Color = CS(DUST), Rate = 1.6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(2, 5), Lifetime = R(1.6, 2.4), Size = grow(4, 9), Transparency = NS({ KP(0, 1), KP(0.25, 0.6), KP(1, 1) }), Rotation = R(0, 360) })
	end
	-- AuraBack (P3, on the BackTop): lightning streams up off the hump.
	do
		local p = part(root, "AuraBack", Vector3.new(4, 2, 4))
		em(p, "Streams", { Texture = TEX.zig, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 5, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(14, 24), Lifetime = R(0.25, 0.4), Size = grow(8, 12), Rotation = R(-20, 20), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 2 })
		em(p, "Lines", { Texture = TEX.line, Color = CS(RIM), LightEmission = 1, Rate = 6, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Speed = R(30, 50), Lifetime = R(0.3, 0.5), Size = grow(9, 1), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
		em(p, "Violet", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(0.4, VIOLET), CK(1, VIOLET) }), LightEmission = 1, Rate = 1.6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(6, 14), Lifetime = R(0.2, 0.35), Size = grow(10, 8), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 })
	end
	-- AuraMotes (P3, on the chest): fur motes lift off the body.
	do
		local p = part(root, "AuraMotes", Vector3.new(6, 6, 6))
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, RIM), CK(1, BRIGHT) }), LightEmission = 1, Rate = 7, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Speed = R(1, 3), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(2, 3.2), Size = grow(0.7, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.8, 0.4), KP(1, 1) }) })
		em(p, "Fur", { Texture = TEX.mote, Color = CS(DUST), Rate = 5, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Speed = R(1, 2.5), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(2, 3), Size = grow(0.8, 0.2), Transparency = NS({ KP(0, 1), KP(0.2, 0.5), KP(0.8, 0.6), KP(1, 1) }) })
		em(p, "Violet", { Texture = TEX.dot, Color = CS(VIOLET), LightEmission = 1, Rate = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Speed = R(1, 2), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(2, 3), Size = grow(0.6, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.8, 0.4), KP(1, 1) }) })
	end
	-- AuraEye (P3, on each eye): the white-hot glint.
	do
		local p = part(root, "AuraEye", Vector3.new(1, 1, 1))
		em(p, "Glint", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Rate = 2.5, Lifetime = R(0.5), Size = grow(1, 8, 0), LockedToPart = true, ZOffset = 2 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Rate = 4, Lifetime = R(0.4), Size = grow(3, 2), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), LockedToPart = true })
	end

	----------------------------------------------------------------------
	-- Death (sequenced by the runtime over 3.2 s)
	----------------------------------------------------------------------

	-- DeathBuild: the sigil overloads: a collapsing gather, a glow that grows
	-- to white, arcs thrown outward, cracks of light. 3.0 s authored.
	do
		local p = part(root, "DeathBuild", Vector3.new(16, 16, 16), { AuthoredSeconds = 3.0 })
		em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 40, Lifetime = R(0.4, 0.6), Speed = R(18, 30), Size = grow(1.2, 0.1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 3.0 })
		em(p, "Pull", { Texture = TEX.line, Color = CS(RIM), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 18, Lifetime = R(0.3, 0.45), Speed = R(34, 48), Size = grow(7, 0.8), Transparency = NS({ KP(0, 1), KP(0.3, 0.1), KP(1, 0.7) }) }, { EmitDuration = 3.0 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(3.0), Size = grow(2, 20), Transparency = NS({ KP(0, 0.8), KP(0.9, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, BRIGHT), CK(1, WHITE) }), LightEmission = 1, Brightness = 4, Lifetime = R(3.0), Size = grow(1, 18), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Cracks", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Rate = 14, Lifetime = R(0.12, 0.2), Size = grow(1, 9, 0), Rotation = R(0, 180), SpreadAngle = Vector2.new(180, 180), Speed = R(0, 0), ZOffset = 2 }, { EmitDuration = 3.0 })
		em(p, "Arcs", { Texture = TEX.fork, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Rate = 8, Speed = R(10, 24), Lifetime = R(0.15, 0.25), Size = grow(10, 14), Rotation = R(0, 360), Transparency = flicker(), ZOffset = 2 }, { EmitDuration = 3.0 })
	end
	-- DeathBurst: the final white flash, a shock ring, storm-cloud puffs, rays,
	-- a spirit-core glint that lingers, motes.
	do
		local p = part(root, "DeathBurst", Vector3.new(1, 1, 1))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 8, Lifetime = R(0.35), Size = grow(24, 80), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), ZOffset = 4 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.55), Size = grow(6, 60, 0), ZOffset = 4 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.7), Size = grow(6, 90), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "RingSpiky", { Texture = TEX.ringSpiky, Color = CS(RIM), LightEmission = 1, Lifetime = R(0.8), Size = grow(6, 100), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 }, { EmitDelay = 0.1 })
		em(p, "InkSplash", { Texture = TEX.ink, Color = CS(INDIGO), Lifetime = R(0.8), Size = grow(16, 46), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		em(p, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(80, 140), Lifetime = R(0.4, 0.7), Size = grow(24, 4), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 28 })
		em(p, "Clouds", { Texture = TEX.puff, Color = CS(SLATE), SpreadAngle = Vector2.new(180, 180), Speed = R(14, 30), Drag = 3, Lifetime = R(1.6, 2.6), Size = grow(10, 30), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 12 })
		em(p, "CloudsDark", { Texture = TEX.puff, Color = CS(INDIGO), SpreadAngle = Vector2.new(180, 180), Speed = R(8, 20), Drag = 3, Lifetime = R(1.6, 2.6), Size = grow(8, 24), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360), ZOffset = -0.5 }, { EmitCount = 8 })
		em(p, "Core", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Brightness = 5, Lifetime = R(2.0), Size = NS({ KP(0, 2), KP(0.2, 16), KP(1, 4) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }), ZOffset = 4 }, { EmitDelay = 0.2 })
		em(p, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(14, 44), Drag = 2, Acceleration = Vector3.new(0, 7, 0), Lifetime = R(1.4, 2.4), Size = grow(1.4, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 40 })
		shake(p, "Explosion,30~170,3.4,1.2,20,0.02,1;1;1,0.1;0.1;0.1")
	end
	-- DeathSpirit: the sigil releases on the floor, a column of rays and a slow
	-- rise of motes.
	do
		local p = part(root, "DeathSpirit", Vector3.new(20, 0.2, 20), { AuthoredRadius = 10 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Lifetime = R(3.2), Size = grow(10, 28, 32), RotSpeed = R(40), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Pillar", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4), Speed = R(40, 80), Rate = 14, Lifetime = R(0.9, 1.4), Size = grow(24, 6), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitDuration = 2.4 })
		em(g, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, Speed = R(5, 14), Rate = 14, Lifetime = R(2, 3.4), Size = grow(1.2, 0), Acceleration = Vector3.new(0, 4, 0), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.2), KP(1, 1) }) }, { EmitDuration = 3.0 })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(1.1), Size = grow(2, 60), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.4 }), { EmitDelay = 0.2 })
		em(g, "Smoke", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(10, 18), Drag = 3, Lifetime = R(1.4, 2.4), Size = grow(6, 18), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(g, "Motes", { Texture = TEX.dot, Color = CS(RIM), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(1, 4), Acceleration = Vector3.new(0, 2.5, 0), Rate = 10, Lifetime = R(3, 5), Size = grow(0.7, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.3), KP(0.8, 0.5), KP(1, 1) }) }, { EmitDuration = 4.0 })
	end

	-- DeathSoul (death, a box over the whole body, sized by code, 3.0 s
	-- authored): the storm spirit leaves the body: white-blue wisps and lines
	-- stream up out of the whole silhouette over indigo smoke, slow at first,
	-- then a torrent just before the burst.
	do
		local p = part(root, "DeathSoul", Vector3.new(16, 24, 16), { AuthoredSeconds = 3.0 })
		local box = { Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top }
		em(p, "Smoke", with(box, { Texture = TEX.puff, Color = CS(INDIGO), Rate = 10, SpreadAngle = Vector2.new(25, 25), Speed = R(4, 9), Lifetime = R(1.2, 1.8), Size = grow(5, 12), Rotation = R(0, 360), RotSpeed = R(-30, 30), Transparency = NS({ KP(0, 1), KP(0.25, 0.5), KP(1, 1) }), ZOffset = -0.5 }), { EmitDuration = 3.0 })
		em(p, "Wisps", with(box, { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(0.35, RIM), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 22, SpreadAngle = Vector2.new(10, 10), Speed = R(12, 22), Acceleration = Vector3.new(0, 8, 0), Lifetime = R(0.6, 0.95), Size = NS({ KP(0, 3), KP(0.3, 7), KP(1, 2) }), Rotation = R(-10, 10), Transparency = NS({ KP(0, 1), KP(0.15, 0.3), KP(0.7, 0.45), KP(1, 1) }), ZOffset = 1 }), { EmitDuration = 3.0 })
		em(p, "Lines", with(box, { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, RIM) }), LightEmission = 1, Brightness = 2, Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 18, SpreadAngle = Vector2.new(6, 6), Speed = R(30, 55), Lifetime = R(0.4, 0.7), Size = grow(16, 3), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }), { EmitDuration = 3.0, EmitDelay = 0.8 })
		em(p, "Motes", with(box, { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BRIGHT) }), LightEmission = 1, Brightness = 2, Rate = 16, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 14), Acceleration = Vector3.new(0, 6, 0), Lifetime = R(1, 1.8), Size = grow(1.2, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }), { EmitDuration = 3.0 })
	end

	root.Parent = effects
	return root
end
print("buildThunderApeFX installed")
return true
