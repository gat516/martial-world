--!nocheck
-- Builder for ReplicatedStorage.Effects.NineTailFox: the Nine-Tailed Fox
-- boss's attack, hit, phase, scream, aura and death effects. Load through the
-- receiver, then build into staging (or the live Effects folder in a sandbox):
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/NineTailFox.luau")
--   require(m)  -- installs _G.buildNineTailFoxFX(effectsFolder)
-- Runtime: src/client/EnemyFX/NineTailFox.luau (cue -> template, placement).
--
-- Identity: foxfire. Authored azure with a white-hot core; the runtime tints
-- every bright layer by Phase (azure, violet, white-hot with a crimson edge).
-- Every bright shape sits on a slate base so it reads in daylight. Lances and
-- tail strikes are white-gold streaks (fixed), magic is phase foxfire, the
-- scream is pale blue-white. Sinuous shapes: flame tongues, petals, wisps and
-- crescents. No crown, halo or ring-over-head motif.
-- Every template is an invisible anchored Part (centre = pivot, -Z = facing).
-- Ground templates have their centre on the floor. `AuthoredSeconds` (holds)
-- and `AuthoredRadius` (ground shapes) tell the runtime how to refit them.
-- Emitters tagged `NoTint` keep their authored colour. Rate-based emitters
-- (aura, stuck glow, fire strip, tail glow) carry `BaseRate`.
-- Ribbon / Thread / Lane carry Trails and Beams the runtime drives by hand.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local AZ = Color3.fromRGB(120, 205, 255)
local AZMID = Color3.fromRGB(190, 232, 255)
local PALE = Color3.fromRGB(214, 238, 255)
local HOT = Color3.fromRGB(255, 236, 176)
local GOLD = Color3.fromRGB(255, 196, 90)
local SLATE = Color3.fromRGB(34, 42, 58)
local INK = Color3.fromRGB(16, 18, 28)
local DUST = Color3.fromRGB(176, 184, 196)

local TEX = {
	glint = id(84223532517124),
	dot = id(9841273544),
	ringThin = id(9841273159),
	ringThick = id(13322173171),
	ringSpiky = id(13052243772),
	ringDust = id(13052235894),
	arc = id(13366366767),
	claw = id(11636552631),
	line = id(7886908733),
	streaks = id(5699911427),
	crackHole = id(85474069372331),
	crackGlow = id(8172249266),
	mandala = id(107304921648525),
	sigil = id(16878097832),
	puff = id(14050360239),
	flame = id(13280154167),
	chips = id(425665059),
	ink = id(16132530029),
	petal = id(90111316485044),
	moon = id(1084963972), -- a crisp crescent moon
	wisp = id(15938018250), -- a long sinuous wisp stroke
	flameFlip = id(17703378809), -- white flame flipbook, 4x4
	spiritFlip = id(81332883799807), -- tall spirit flame flipbook, 2x2
	twinkle = id(102648375149008), -- four-point star twinkle flipbook, 4x4
}
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local GRID2 = Enum.ParticleFlipbookLayout.Grid2x2
local ONESHOT = Enum.ParticleFlipbookMode.OneShot

local FLAT = {
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
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
	-- Sizes are authored as diameters; a particle's Size is a half-width.
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

local fade = NS({ KP(0, 0), KP(0.55, 0.12), KP(1, 1) })
local pop = NS({ KP(0, 0), KP(1, 1) })
local function grow(a, b, c)
	if c then
		return NS({ KP(0, a), KP(0.5, b), KP(1, c) })
	end
	return NS({ KP(0, a), KP(1, b) })
end
local function ghostIn(a, b, c)
	-- fades in, holds, fades out
	return NS({ KP(0, 1), KP(a or 0.12, 0.2), KP(b or 0.8, 0.3), KP(c or 1, 1) })
end
local FIRE = CS({ CK(0, WHITE), CK(0.45, AZMID), CK(1, AZ) })
local NOTINT = { NoTint = true }

-- a rising column of foxfire light streaks
local function pillar(parent, name, size, speed, rate, life, tall)
	return em(parent, name, {
		Texture = TEX.line, Color = FIRE, LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3),
		Speed = R(speed * 0.7, speed), Rate = rate, Lifetime = life, Size = grow(tall, tall * 0.3),
		Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
	}, { EmitDuration = 1.2 })
end

function _G.buildNineTailFoxFX(effects)
	local old = effects:FindFirstChild("NineTailFox")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "NineTailFox"

	-- EyeGlint: at every windup, on each eye. A star pop, a held glow, a
	-- needle of foxfire rising off it.
	do
		local p = part(root, "EyeGlint", nil, { AuthoredSeconds = 0.6 })
		em(p, "Glint", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 5, Lifetime = R(0.22), Size = grow(0.6, 3.6, 0), Rotation = R(-8, 8), ZOffset = 2 })
		em(p, "Hold", { Texture = TEX.dot, Color = CS(AZ), LightEmission = 1, Lifetime = R(0.12, 0.2), Rate = 20, Size = grow(1, 0.5), Transparency = NS({ KP(0, 0.3), KP(1, 0.85) }), LockedToPart = true, ZOffset = 1.5 }, { EmitDuration = 0.6 })
		em(p, "Needle", { Texture = TEX.line, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, Speed = R(6, 10), Lifetime = R(0.3), Size = grow(3, 0.3), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 2 })
	end

	-- Aura (always on, clones are mounted by the runtime): low foxfire
	-- tongues and motes on each tail tip, a faint ground mist and rising
	-- twinkles round the paws. No disc under the fox.
	do
		local p = part(root, "AuraTail", Vector3.new(1, 1, 1))
		em(p, "Flames", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Rate = 5, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(1.5, 3.5), Lifetime = R(0.9, 1.5), Size = grow(2, 0.5), Transparency = NS({ KP(0, 0.5), KP(0.3, 0.35), KP(1, 1) }), Rotation = R(-15, 15), LockedToPart = false })
		em(p, "Motes", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, Rate = 3, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 1.4, 0), Lifetime = R(1.8, 3), Size = grow(0.45, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.8, 0.4), KP(1, 1) }) })
	end
	do
		local p = part(root, "AuraGround", Vector3.new(16, 0.2, 16))
		em(p, "Motes", { Texture = TEX.twinkle, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = CS(AZMID), LightEmission = 1, Rate = 2.5, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(1, 2.5), Lifetime = R(1.6, 2.6), Size = grow(0.8, 0.3), Transparency = NS({ KP(0, 1), KP(0.2, 0.15), KP(0.8, 0.4), KP(1, 1) }), LockedToPart = false })
		em(p, "Mist", { Texture = TEX.puff, Color = CS(PALE), Rate = 1.6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(0.6, 1.4), Lifetime = R(3, 4.5), Size = grow(5, 11), Transparency = NS({ KP(0, 1), KP(0.25, 0.82), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-8, 8), LockedToPart = false, ZOffset = 0.2 }, nil)
	end

	-- TailIgnite (a tail tip lighting up, the intro plays nine): flash, star,
	-- a burst of tongues, a closing ring.
	do
		local p = part(root, "TailIgnite", nil)
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.18), Size = grow(2, 7), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 4, Lifetime = R(0.3), Size = grow(1, 7, 0), ZOffset = 3 })
		em(p, "Tongues", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(5, 11), Lifetime = R(0.6, 1), Size = grow(2.6, 0.5), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(-20, 20) }, { EmitCount = 6 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Lifetime = R(0.4), Size = grow(7, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.15), KP(1, 0.5) }), ZOffset = 1 })
	end

	-- Sigil (ground, authored r9): the sigil's own shape in ink beneath it
	-- (never a filled disc), a turning foxfire sigil and
	-- mandala, an edge ring, petals lifting off it, a low mist.
	do
		local p = part(root, "Sigil", Vector3.new(18, 0.2, 18), { AuthoredRadius = 9, AuthoredSeconds = 2.4 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "Dark", with(FLAT, { Texture = TEX.sigil, Color = CS(INK), Lifetime = R(2.4), Size = grow(8.8, 18.4, 19.4), RotSpeed = R(36), Transparency = NS({ KP(0, 1), KP(0.15, 0.3), KP(0.8, 0.4), KP(1, 1) }), ZOffset = 0.1 }), NOTINT)
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(2.4), Size = grow(8, 17, 18), RotSpeed = R(36), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.8, 0.3), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(PALE), LightEmission = 1, Lifetime = R(2.4), Size = grow(6, 13, 14), RotSpeed = R(-24), Transparency = NS({ KP(0, 1), KP(0.2, 0.4), KP(0.8, 0.5), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(1), Size = grow(2, 19), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.2 }))
		em(g, "Petals", { Texture = TEX.petal, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(3, 8), Acceleration = Vector3.new(0, 2, 0), Lifetime = R(1.4, 2.2), Size = grow(1.6, 0.8), Rotation = R(0, 360), RotSpeed = R(-90, 90), Transparency = NS({ KP(0, 0.2), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 10 })
		em(g, "Mist", { Texture = TEX.puff, Color = CS(PALE), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(1, 3), Lifetime = R(2, 3), Size = grow(5, 12), Transparency = NS({ KP(0, 0.85), KP(0.3, 0.7), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 8 })
	end

	-- RoarWave (ground, centre of the fox): thin rings, a spiky ring and a
	-- dust ring racing out, one flash.
	do
		local p = part(root, "RoarWave", Vector3.new(0.4, 0.2, 0.4))
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(3, 44), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(PALE), LightEmission = 1, Lifetime = R(0.8), Size = grow(3, 34), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.08 })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.8), Size = grow(3, 40), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.16), Size = grow(6, 18), Transparency = pop, ZOffset = 3 })
	end

	-- Breath (fangDance tell, at the Mouth): foxfire drawn into the jaws, a
	-- glow over a slate base, a pale mist.
	do
		local p = part(root, "Breath", Vector3.new(6, 6, 6), { AuthoredSeconds = 0.65 })
		em(p, "Gather", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 36, Lifetime = R(0.3, 0.45), Speed = R(10, 16), Size = grow(0.6, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 0.65 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(0.65), Size = grow(0.6, 4), Transparency = NS({ KP(0, 0.7), KP(0.8, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.65), Size = grow(0.3, 2.8), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Mist", { Texture = TEX.puff, Color = CS(PALE), Rate = 12, Speed = R(2, 5), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Lifetime = R(0.6, 0.9), Size = grow(0.8, 3), Transparency = NS({ KP(0, 0.6), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 0.65 })
	end

	-- FangSnap (at the Mouth): upper and lower crescents slam shut on a slate
	-- base, a star and ink, sparks.
	do
		local p = part(root, "FangSnap", Vector3.new(0.4, 0.4, 0.4))
		local upper = att(p, "Upper", Vector3.new(0, 1.6, 0))
		local lower = att(p, "Lower", Vector3.new(0, -1.6, 0))
		local function crescent(a, flip)
			local base = { Texture = TEX.arc, Lifetime = R(0.22), Drag = 8, Speed = R(26), Rotation = R(flip and 180 or 0), EmissionDirection = flip and Enum.NormalId.Top or Enum.NormalId.Bottom }
			em(a, "Dark", with(base, { Color = CS(SLATE), Size = grow(5.5, 7.5), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 0.5 }), NOTINT)
			em(a, "Rim", with(base, { Color = FIRE, LightEmission = 1, Brightness = 2, Size = grow(4.6, 6.6), Transparency = NS({ KP(0, 0.05), KP(1, 1) }), ZOffset = 1 }))
			em(a, "Core", with(base, { Color = CS(WHITE), LightEmission = 1, Brightness = 3, Size = grow(3.4, 5.4), Transparency = fade, ZOffset = 1.5 }))
		end
		crescent(upper, false)
		crescent(lower, true)
		em(p, "Star", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 5, Lifetime = R(0.26), Size = grow(1, 9, 0), ZOffset = 3 })
	end

	-- Hit and HitHeavy (on the struck player): flash, star, a claw slash,
	-- rays, sparks, ink; heavy adds a ring and a dust puff.
	for _, spec in { { "Hit", 1, false }, { "HitHeavy", 1.6, true } } do
		local k = spec[2]
		local p = part(root, spec[1], Vector3.new(0.4, 0.4, 0.4))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.13), Size = grow(3 * k, 8 * k), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 5, Lifetime = R(0.24), Size = grow(1, 8 * k, 0), ZOffset = 3 })
		em(p, "Slash", { Texture = TEX.claw, Color = CS({ CK(0, WHITE), CK(1, AZMID) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.18), Rotation = R(-40, 40), Size = grow(4 * k, 7 * k), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }), ZOffset = 2 })
		em(p, "Ink", { Texture = TEX.ink, Color = CS(SLATE), Lifetime = R(0.35), Size = grow(3 * k, 6 * k), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }, NOTINT)
		em(p, "Rays", { Texture = TEX.line, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(26, 46), Lifetime = R(0.15, 0.25), Size = grow(3.5 * k, 0.8), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 8 })
		em(p, "Sparks", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(6, 18), Acceleration = Vector3.new(0, -14, 0), Lifetime = R(0.5, 1), Size = grow(0.35, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 8 })
		if spec[3] then
			em(p, "Ring", { Texture = TEX.ringSpiky, Color = FIRE, LightEmission = 1, Lifetime = R(0.3), Size = grow(2, 13), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
			em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(180, 180), Speed = R(5, 11), Drag = 3, Lifetime = R(0.5, 0.9), Size = grow(2, 5), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 4 })
		end
	end

	-- LanceHit (far end of a lance box, white-gold, never phase tinted): a big
	-- vertical star, spiky ring, long rays, gold embers, slate ink.
	do
		local p = part(root, "LanceHit", Vector3.new(0.4, 0.4, 0.4))
		local gold = CS({ CK(0, WHITE), CK(0.5, HOT), CK(1, GOLD) })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.14), Size = grow(4, 11), Transparency = pop, ZOffset = 3 }, NOTINT)
		em(p, "Star", { Texture = TEX.glint, Color = gold, LightEmission = 1, Brightness = 6, Lifetime = R(0.3), Size = grow(1, 13, 0), ZOffset = 3 }, NOTINT)
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = gold, LightEmission = 1, Lifetime = R(0.34), Size = grow(2, 15), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 }, NOTINT)
		em(p, "Ink", { Texture = TEX.ink, Color = CS(SLATE), Lifetime = R(0.4), Size = grow(4, 9), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }, NOTINT)
		em(p, "Rays", { Texture = TEX.line, Color = gold, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(40, 70), Lifetime = R(0.18, 0.3), Size = grow(5, 1), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 12 })
		em(p, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, GOLD) }), LightEmission = 1, SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Speed = R(8, 22), Acceleration = Vector3.new(0, -16, 0), Lifetime = R(0.7, 1.3), Size = grow(0.4, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 12 })
	end

	-- Burst (ground, authored r3: a foxfire bolt lands, a stuck tip plants):
	-- flash, flat ring, tongues, petals, embers, slate scorch.
	do
		local p = part(root, "Burst", Vector3.new(6, 0.2, 6), { AuthoredRadius = 3 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "Scorch", with(FLAT, { Texture = TEX.ink, Color = CS(INK), Lifetime = R(2.5), Size = grow(4, 8, 8), Transparency = NS({ KP(0, 0.2), KP(0.6, 0.4), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(0.35), Size = grow(1, 11), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(4, 9), Transparency = pop, ZOffset = 3 })
		em(g, "Tongues", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(8, 16), Lifetime = R(0.5, 0.9), Size = grow(3, 0.8), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(-25, 25) }, { EmitCount = 6 })
		em(g, "Petals", { Texture = TEX.petal, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(6, 14), Acceleration = Vector3.new(0, -8, 0), Lifetime = R(0.8, 1.4), Size = grow(1.4, 0.6), Rotation = R(0, 360), RotSpeed = R(-200, 200), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitCount = 6 })
		em(g, "Embers", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(4, 14), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(1, 1.8), Size = grow(0.35, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 10 })
	end

	-- TipCharge (a tail tip's tell): motes drawn in, a glow over slate, a
	-- closing ring, a star flash just before release.
	do
		local p = part(root, "TipCharge", Vector3.new(4, 4, 4), { AuthoredSeconds = 1 })
		em(p, "Gather", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 30, Lifetime = R(0.3, 0.5), Speed = R(8, 14), Size = grow(0.6, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 1 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1), Size = grow(0.5, 4), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(1), Size = grow(0.4, 3.4), Transparency = NS({ KP(0, 0.85), KP(0.85, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Lifetime = R(0.5), Size = grow(7, 0.8), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(1, 0.4) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.4 })
		em(p, "Pre", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 4, Lifetime = R(0.22), Size = grow(0.5, 5, 0), LockedToPart = true, ZOffset = 2 }, { EmitDelay = 0.8 })
	end

	-- TailFlare (scream tell, each lit tail): tongues lifting and a glow.
	do
		local p = part(root, "TailFlare", Vector3.new(2, 2, 2), { AuthoredSeconds = 1.4 })
		em(p, "Tongues", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Rate = 16, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(6, 12), Lifetime = R(0.7, 1.1), Size = grow(2.4, 0.6), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), Rotation = R(-20, 20) }, { EmitDuration = 1.4 })
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Lifetime = R(1.4), Size = grow(0.5, 4), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.2), KP(1, 1) }), LockedToPart = true })
	end

	-- TailGlow: emitters the runtime clones straight into a tail sleeve (a
	-- Box shape fills the sleeve): motes and a thin wisp along the whole tail.
	do
		local p = part(root, "TailGlow", Vector3.new(1, 1, 1))
		em(p, "Motes", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 26, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Lifetime = R(0.4, 0.7), Size = grow(0.7, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), LockedToPart = false })
		em(p, "Wisp", { Texture = TEX.flame, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 8, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(2, 4), Lifetime = R(0.5, 0.9), Size = grow(1.8, 0.4), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(-20, 20), LockedToPart = false })
	end

	-- Ribbon: a flying head the runtime moves along a path. Three Trails
	-- (slate base, wide glow, white core) and a head of glow, tongues and
	-- sparks. The runtime sets the Trail attachments' half-width and colours.
	do
		local p = part(root, "Ribbon", Vector3.new(0.3, 0.3, 0.3))
		local a0 = att(p, "A0", Vector3.new(0, 0.5, 0))
		local a1 = att(p, "A1", Vector3.new(0, -0.5, 0))
		local function trail(name, color, life, startT, width, emission)
			local t = Instance.new("Trail")
			t.Name = name
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = color
			t.LightEmission = emission
			t.LightInfluence = 0
			t.Lifetime = life
			t.MinLength = 0.05
			t.FaceCamera = true
			t.Enabled = false
			t.Transparency = NS({ KP(0, startT), KP(1, 1) })
			t.WidthScale = NS({ KP(0, width), KP(1, 0) })
			t.Parent = p
		end
		trail("Dark", CS(SLATE), 0.6, 0.45, 1.5, 0)
		trail("Wide", CS({ CK(0, AZMID), CK(1, AZ) }), 0.5, 0.35, 1.3, 1)
		trail("Core", CS({ CK(0, WHITE), CK(1, AZMID) }), 0.36, 0, 0.7, 1)
		em(p, "Head", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Rate = 30, Lifetime = R(0.12), Size = grow(1.6, 0.8), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 2 })
		em(p, "Tongues", { Texture = TEX.flame, Color = FIRE, LightEmission = 1, Rate = 24, Lifetime = R(0.25, 0.4), Size = grow(2.2, 0.3), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), Rotation = R(-30, 30), LockedToPart = false })
		em(p, "Sparks", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Rate = 20, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 7), Lifetime = R(0.3, 0.6), Size = grow(0.5, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), LockedToPart = false })
	end

	-- Bolt (foxfireVolley, a real projectile drawn by ProjectileView): a ball of
	-- foxfire the player has to read and dodge. A white-hot core over a slate
	-- halo, a turning star, flipbook flames streaming off it, sparks, and a
	-- comet tail of three Trails (slate, phase glow, white core) between A0 and
	-- A1 (the runtime sets their half-width). Its child part Shadow is moved
	-- onto the ground under the bolt so its distance reads.
	do
		local p = part(root, "Bolt", Vector3.new(0.4, 0.4, 0.4))
		local a0 = att(p, "A0", Vector3.new(0, 0.8, 0))
		local a1 = att(p, "A1", Vector3.new(0, -0.8, 0))
		for _, spec in { { "Dark", CS(SLATE), 0.4, 0.6, 1.5, 0 }, { "Wide", FIRE, 0.38, 0, 1.2, 1 }, { "Core", CS(WHITE), 0.24, 0, 0.45, 1 } } do
			local t = Instance.new("Trail")
			t.Name = spec[1]
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = spec[2]
			t.LightEmission = spec[6]
			t.LightInfluence = 0
			t.Lifetime = spec[3]
			t.MinLength = 0.05
			t.FaceCamera = true
			t.Enabled = false
			t.Transparency = NS({ KP(0, spec[4]), KP(1, 1) })
			t.WidthScale = NS({ KP(0, spec[5]), KP(1, 0) })
			t.Parent = p
		end
		em(p, "Halo", { Texture = TEX.dot, Color = CS(SLATE), Rate = 14, Lifetime = R(0.16), Size = grow(4.6, 4), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 3, Rate = 24, Lifetime = R(0.14), Size = grow(4.4, 3.4), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Core", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Rate = 24, Lifetime = R(0.12), Size = grow(1.8, 1.4), Transparency = NS({ KP(0, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 2.5 }, NOTINT)
		em(p, "Star", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 4, Rate = 5, Lifetime = R(0.3), Size = grow(3, 5, 2), Rotation = R(0, 360), RotSpeed = R(-180, 180), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 2 })
		em(p, "Flames", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Rate = 30, SpreadAngle = Vector2.new(30, 30), Speed = R(1, 3), Lifetime = R(0.25, 0.4), Size = grow(2.6, 0.6), Transparency = NS({ KP(0, 0.15), KP(1, 1) }), Rotation = R(-40, 40), LockedToPart = false, ZOffset = 1 })
		em(p, "Sparks", { Texture = TEX.twinkle, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Rate = 16, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 6), Lifetime = R(0.3, 0.6), Size = grow(0.9, 0.2), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), LockedToPart = false })
		local shadow = part(p, "Shadow", Vector3.new(0.4, 0.2, 0.4))
		em(shadow, "Shadow", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Rate = 10, Lifetime = R(0.18), Size = NS(3.2), Transparency = NS({ KP(0, 0.55), KP(1, 0.8) }), LockedToPart = true, ZOffset = 0.1 }), NOTINT)
		em(shadow, "Glow", with(FLAT, { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Rate = 10, Lifetime = R(0.18), Size = NS(3.6), Transparency = NS({ KP(0, 0.45), KP(1, 0.8) }), LockedToPart = true, ZOffset = 0.2 }))
	end

	-- Thread: two Beams (foxfire halo and white core) between its `A` and
	-- `End` attachments; the runtime moves End onto a second part.
	-- Lane: the same on the ground (a thin sigil line along a damage box).
	for _, name in { "Thread", "Lane" } do
		local p = part(root, name, Vector3.new(0.3, 0.3, 0.3))
		local a = att(p, "A")
		local e = att(p, "End")
		local flat = name == "Lane"
		local function beam(n, color, width, tr, emission)
			local b = Instance.new("Beam")
			b.Name = n
			b.Attachment0, b.Attachment1 = a, e
			b.Color = color
			b.LightEmission = emission
			b.LightInfluence = 0
			b.Width0, b.Width1 = width, width
			b.FaceCamera = not flat
			b.Segments = 1
			b.Transparency = NS(tr)
			b.Enabled = false
			b.Parent = p
		end
		beam("Dark", CS(SLATE), flat and 1.6 or 1.1, 0.5, 0)
		beam("Wide", CS({ CK(0, AZMID), CK(1, AZ) }), flat and 0.9 or 0.8, 0.35, 1)
		beam("Core", CS(WHITE), flat and 0.3 or 0.25, 0.05, 1)
	end

	-- Gather (authored r5, held 0.75): motes and pull lines drawn in, a glow
	-- over slate, ring closing; used for the pounce crouch, the leap and (big)
	-- the phase break.
	do
		local p = part(root, "Gather", Vector3.new(5, 5, 5), { AuthoredSeconds = 0.75, AuthoredRadius = 5 })
		em(p, "Motes", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 50, Lifetime = R(0.3, 0.5), Speed = R(14, 22), Size = grow(0.7, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 0.75 })
		em(p, "Pull", { Texture = TEX.line, Color = CS(PALE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 18, Lifetime = R(0.3, 0.45), Speed = R(26, 38), Size = grow(3.4, 0.5), Transparency = NS({ KP(0, 1), KP(0.3, 0.1), KP(1, 0.7) }) }, { EmitDuration = 0.75 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(0.75), Size = grow(1, 9), Transparency = NS({ KP(0, 0.8), KP(0.9, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.75), Size = grow(0.5, 6), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Lifetime = R(0.45), Size = grow(12, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(1, 0.5) }), LockedToPart = true, ZOffset = 1.2, Rate = 3 }, { EmitDuration = 0.75 })
	end

	-- Dust (ground, authored r3): a skidding / launching puff with streaks and
	-- a dust ring.
	do
		local p = part(root, "Dust", Vector3.new(6, 0.2, 6), { AuthoredRadius = 3 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Puff", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 120), Speed = R(8, 16), Drag = 4, Lifetime = R(0.6, 1), Size = grow(2, 6), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 6 })
		em(g, "Streaks", { Texture = TEX.streaks, Color = CS(PALE), LightEmission = 0.6, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(10, 40), Speed = R(18, 30), Lifetime = R(0.25, 0.4), Size = grow(4, 1), Transparency = NS({ KP(0, 0.3), KP(1, 1) }) }, { EmitCount = 5 })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(2, 11), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
	end

	-- Landing (ground, authored r6, the moon leap's touchdown; it carries the
	-- beat alone, with no stock disc under it): a crescent moon on its slate
	-- twin, foxfire tongues, slate dust ring, flat rings in two sizes, dust,
	-- petals thrown up, a flash.
	do
		local p = part(root, "Landing", Vector3.new(12, 0.2, 12), { AuthoredRadius = 6 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		-- the moon the leap is named for: a crescent printed on the ground on
		-- its slate twin, opening out, and foxfire tongues leaping off it
		em(g, "MoonDark", with(FLAT, { Texture = TEX.moon, Color = CS(SLATE), Lifetime = R(0.9), Size = grow(6, 15.5), Rotation = R(-90), Transparency = NS({ KP(0, 0.35), KP(0.6, 0.5), KP(1, 1) }), ZOffset = 0.3 }), NOTINT)
		em(g, "Moon", with(FLAT, { Texture = TEX.moon, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(5.5, 14.5), Rotation = R(-90), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 0.9 }))
		em(g, "Tongues", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(8, 14), Lifetime = R(0.5, 0.8), Size = grow(3, 0.8), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(-20, 20) }, { EmitCount = 7 })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.6), Size = grow(2, 20), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(0.4), Size = grow(1, 18), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(PALE), LightEmission = 1, Lifetime = R(0.45), Size = grow(1, 13), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.05 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(10, 18), Drag = 4, Lifetime = R(0.7, 1.1), Size = grow(2, 6), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "Petals", { Texture = TEX.petal, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55), Speed = R(8, 16), Acceleration = Vector3.new(0, -12, 0), Lifetime = R(0.8, 1.4), Size = grow(1.6, 0.7), Rotation = R(0, 360), RotSpeed = R(-180, 180), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitCount = 8 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = grow(4, 9), Transparency = pop, ZOffset = 3 })
	end

	-- PlungeImpact (ground, authored r4: a tail tip drives into the earth):
	-- flash, ring, dust, chips, a lit crack, tongues.
	do
		local p = part(root, "PlungeImpact", Vector3.new(8, 0.2, 8), { AuthoredRadius = 4 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(5, 9), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 10), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(4, 9), Transparency = pop, ZOffset = 3 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(8, 14), Drag = 4, Lifetime = R(0.6, 1), Size = grow(2, 5), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 6 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(14, 26), Acceleration = Vector3.new(0, -70, 0), Lifetime = R(0.6, 0.9), Size = grow(0.8, 0.6), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 7 })
		em(g, "Tongues", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 12), Lifetime = R(0.4, 0.7), Size = grow(2.4, 0.5), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(-20, 20) }, { EmitCount = 4 })
	end

	-- Eruption (ground, authored r3.5): the earth cracks on a slate base, a
	-- foxfire column and light streaks spike up, a ring and a dust ring race
	-- out, petals, chips and embers thrown.
	do
		local p = part(root, "Eruption", Vector3.new(7, 0.2, 7), { AuthoredRadius = 3.5 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INK), Lifetime = R(3), Size = grow(4, 9, 9.5), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(5, 9), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Column", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6), Speed = R(22, 36), Lifetime = R(0.55, 0.9), Size = grow(5, 2.6, 0.6), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.3), KP(1, 1) }), Rotation = R(-15, 15) }, { EmitCount = 14 })
		em(g, "Streaks", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3), Speed = R(36, 56), Lifetime = R(0.3, 0.5), Size = grow(12, 3), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitCount = 10 })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(0.35), Size = grow(1, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(2, 12), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
		em(g, "Petals", { Texture = TEX.petal, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(10, 20), Acceleration = Vector3.new(0, -14, 0), Lifetime = R(0.9, 1.5), Size = grow(1.8, 0.8), Rotation = R(0, 360), RotSpeed = R(-200, 200), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitCount = 9 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(16, 30), Acceleration = Vector3.new(0, -70, 0), Lifetime = R(0.6, 0.9), Size = grow(0.9, 0.7), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "Embers", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(4, 14), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(1, 1.8), Size = grow(0.4, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 12 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(5, 10), Transparency = pop, ZOffset = 3 })
	end

	-- StuckGlow (rate-based, mounted on a buried tail tip): a pulsing glow,
	-- tongues and embers, so the punish window is visible.
	do
		local p = part(root, "StuckGlow", Vector3.new(2, 2, 2))
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, Rate = 5, Lifetime = R(0.8), Size = grow(3.6, 1.4), Transparency = NS({ KP(0, 0.6), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Tongues", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Rate = 8, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(3, 7), Lifetime = R(0.6, 1), Size = grow(2.4, 0.5), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), Rotation = R(-20, 20), LockedToPart = false })
		em(p, "Embers", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, Rate = 10, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(3, 9), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(0.8, 1.4), Size = grow(0.4, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), LockedToPart = false })
	end

	-- FireStrip (rate-based; the runtime sizes the part to a trail box and
	-- scales the rates by its length): lit fissures and flipbook flames on a
	-- slate scorch.
	do
		local p = part(root, "FireStrip", Vector3.new(4, 1, 20))
		em(p, "Scorch", with(FLAT, { Texture = TEX.ink, Color = CS(INK), Rate = 0.25, Shape = Enum.ParticleEmitterShape.Box, Lifetime = R(2.5), Size = NS(5), Transparency = NS({ KP(0, 1), KP(0.2, 0.35), KP(0.8, 0.45), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(p, "Glow", with(FLAT, { Texture = TEX.crackGlow, Color = FIRE, LightEmission = 1, Brightness = 2, Rate = 0.3, Shape = Enum.ParticleEmitterShape.Box, Lifetime = R(1.2), Size = NS(5), Rotation = R(0, 360), Transparency = NS({ KP(0, 1), KP(0.2, 0.3), KP(1, 1) }), ZOffset = 0.5 }))
		em(p, "Flames", { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Rate = 1.2, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(3, 6), Lifetime = R(0.6, 1), Size = grow(3.2, 0.6), Transparency = NS({ KP(0, 0.25), KP(0.6, 0.4), KP(1, 1) }), Rotation = R(-20, 20), LockedToPart = false })
		em(p, "Embers", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, Rate = 0.5, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(3, 9), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(0.8, 1.5), Size = grow(0.4, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), LockedToPart = false })
	end

	-- ScreamTell (at the Throat, held 1.4): sound rings closing on the throat,
	-- pale mist drawn in, a glow on slate. Pale blue-white, never phase tinted.
	do
		local p = part(root, "ScreamTell", Vector3.new(8, 8, 8), { AuthoredSeconds = 1.4 })
		em(p, "RingsIn", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, PALE) }), LightEmission = 1, Brightness = 2, Rate = 3.5, Lifetime = R(0.7), Size = grow(16, 1.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(1, 0.5) }), LockedToPart = true, ZOffset = 1 }, { EmitDuration = 1.4, NoTint = true })
		em(p, "Pull", { Texture = TEX.puff, Color = CS(PALE), Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 26, Lifetime = R(0.5, 0.7), Speed = R(10, 16), Size = grow(2.2, 0.4), Transparency = NS({ KP(0, 1), KP(0.25, 0.55), KP(1, 0.9) }), Rotation = R(0, 360), LockedToPart = true }, { EmitDuration = 1.4, NoTint = true })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.4), Size = grow(1, 6), Transparency = NS({ KP(0, 0.8), KP(0.9, 0.45), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Glow", { Texture = TEX.dot, Color = CS(PALE), LightEmission = 1, Brightness = 3, Lifetime = R(1.4), Size = grow(0.5, 4.5), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, NOTINT)
	end

	-- ScreamWave (ground, authored r22): huge thin rings to the radius, a
	-- light pillar, a flash, a slate dust ring, motes and mist. Pale blue-white.
	do
		local p = part(root, "ScreamWave", Vector3.new(44, 0.2, 44), { AuthoredRadius = 22 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		local pale = CS({ CK(0, WHITE), CK(1, PALE) })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThin, Color = pale, LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(3, 46), Transparency = NS({ KP(0, 0.05), KP(0.8, 0.3), KP(1, 1) }), ZOffset = 1.5 }), NOTINT)
		em(g, "Ring2", with(FLAT, { Texture = TEX.ringThin, Color = pale, LightEmission = 1, Lifetime = R(1), Size = grow(3, 40), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.4 }), { EmitDelay = 0.15, NoTint = true })
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = pale, LightEmission = 1, Lifetime = R(0.7), Size = grow(3, 36), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.05, NoTint = true })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.9), Size = grow(3, 44), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
		em(g, "Pillar", { Texture = TEX.line, Color = pale, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3), Speed = R(50, 80), Rate = 20, Lifetime = R(0.7, 1.1), Size = grow(16, 4), Transparency = NS({ KP(0, 0.15), KP(1, 1) }) }, { EmitDuration = 0.8, NoTint = true })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(8, 26), Transparency = pop, ZOffset = 3 }, NOTINT)
		em(g, "Motes", { Texture = TEX.glint, Color = pale, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(6, 18), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(1.2, 2), Size = grow(0.9, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 18, NoTint = true })
		em(g, "Mist", { Texture = TEX.puff, Color = CS(PALE), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(4, 10), Drag = 2, Lifetime = R(1.2, 2), Size = grow(5, 14), Transparency = NS({ KP(0, 0.7), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 10 })
	end

	-- StunSting (on the stunned player): a blue-white flash, a star, a ring
	-- and ringing rings, small arcs. Pale blue-white.
	do
		local p = part(root, "StunSting", Vector3.new(0.4, 0.4, 0.4))
		local pale = CS({ CK(0, WHITE), CK(1, PALE) })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.16), Size = grow(4, 12), Transparency = pop, ZOffset = 3 }, NOTINT)
		em(p, "Star", { Texture = TEX.glint, Color = pale, LightEmission = 1, Brightness = 5, Lifetime = R(0.3), Size = grow(1, 9, 0), ZOffset = 3 }, NOTINT)
		em(p, "Ring", { Texture = TEX.ringThin, Color = pale, LightEmission = 1, Lifetime = R(0.4), Size = grow(2, 10), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 }, NOTINT)
		em(p, "Ringing", { Texture = TEX.ringThin, Color = pale, LightEmission = 1, Rate = 6, Lifetime = R(0.5), Size = grow(3, 9), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, { EmitDuration = 1.2, NoTint = true })
		em(p, "Arcs", { Texture = TEX.arc, Color = pale, LightEmission = 1, Lifetime = R(0.3), Size = grow(3, 6), Rotation = R(0, 360), SpreadAngle = Vector2.new(180, 180), Speed = R(2, 5), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitCount = 4, NoTint = true })
	end

	-- FallSigil (ground, authored r5, held 1): a circle's sigil brightening
	-- toward its own impact: the mandala in ink beneath itself, the turning
	-- mandala, rings closing in on the centre (the countdown) and an edge ring.
	-- No filled disc; ten of these can be live at once, so it stays lean.
	do
		local p = part(root, "FallSigil", Vector3.new(10, 0.2, 10), { AuthoredRadius = 5, AuthoredSeconds = 1 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Dark", with(FLAT, { Texture = TEX.mandala, Color = CS(INK), Lifetime = R(1), Size = grow(10.2, 10.2), RotSpeed = R(60), Transparency = NS({ KP(0, 1), KP(0.15, 0.3), KP(1, 0.4) }), ZOffset = 0.1 }), NOTINT)
		em(g, "Closing", with(FLAT, { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Brightness = 2, Rate = 5, Lifetime = R(0.45), Size = grow(10, 1.5), Transparency = NS({ KP(0, 1), KP(0.25, 0.2), KP(1, 0.6) }), LockedToPart = true, ZOffset = 0.6 }), { EmitDuration = 1 })
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(PALE), LightEmission = 1, Lifetime = R(1), Size = grow(9.5, 9.5), RotSpeed = R(60), Transparency = NS({ KP(0, 1), KP(0.2, 0.55), KP(0.9, 0.2), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Edge", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(1), Size = grow(10, 10), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.9, 0), KP(1, 1) }), ZOffset = 1 }))
	end

	-- TailPillar (on a raised tail tip, growing over its hold): white-violet
	-- light streaks climbing and a glow.
	do
		local p = part(root, "TailPillar", Vector3.new(1.4, 1.4, 1.4), { AuthoredSeconds = 1.8 })
		em(p, "Streaks", { Texture = TEX.line, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(2, 2), Speed = R(18, 30), Rate = 10, Lifetime = R(0.8, 1.2), Size = grow(8, 3), Transparency = NS({ KP(0, 0.7), KP(0.3, 0.2), KP(1, 1) }), LockedToPart = false }, { EmitDuration = 1.8 })
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(1.8), Size = grow(0.6, 5), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Core", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, Speed = R(30, 44), Rate = 6, Lifetime = R(0.5, 0.8), Size = grow(10, 3), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), LockedToPart = false }, { EmitDuration = 1.8 })
	end

	-- FallBurst (ground, authored r14: the final circle under the fox): flash,
	-- star, three flat rings, a pillar, a lit crack, dust, chips, embers.
	do
		local p = part(root, "FallBurst", Vector3.new(28, 0.2, 28), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INK), Lifetime = R(4), Size = grow(14, 28, 29), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(1.1), Size = grow(14, 28), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = FIRE, LightEmission = 1, Lifetime = R(0.5), Size = grow(2, 34), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.4 }))
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(PALE), LightEmission = 1, Lifetime = R(0.6), Size = grow(2, 30), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.08 })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.8), Size = grow(2, 36), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
		pillar(g, "Pillar", 0, 56, 22, R(0.8, 1.2), 18)
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 7, Lifetime = R(0.25), Size = grow(10, 40), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 6, Lifetime = R(0.45), Size = grow(3, 30, 0), ZOffset = 3 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(14, 26), Drag = 4, Lifetime = R(1, 1.6), Size = grow(4, 12), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(22, 44), Acceleration = Vector3.new(0, -80, 0), Lifetime = R(0.8, 1.3), Size = grow(1.3, 1), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(g, "Embers", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(8, 26), Acceleration = Vector3.new(0, -8, 0), Lifetime = R(1.2, 2.2), Size = grow(0.5, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 22 })
	end

	-- PhaseBurst (ground, authored r10): three shock rings, rays, a pillar, a
	-- flash, lotus petals thrown out, dust and embers. The Sigil plays with it.
	do
		local p = part(root, "PhaseBurst", Vector3.new(20, 0.2, 20), { AuthoredRadius = 10 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		for i, spec in { { 24, 0.55, 0 }, { 34, 0.7, 0.1 }, { 46, 0.9, 0.22 } } do
			em(g, "Ring" .. i, with(FLAT, { Texture = if i == 2 then TEX.ringSpiky else TEX.ringThin, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(spec[2]), Size = grow(2, spec[1]), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 - i * 0.1 }), { EmitDelay = spec[3] })
		end
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.8), Size = grow(2, 40), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }), NOTINT)
		pillar(g, "Pillar", 0, 48, 20, R(0.8, 1.2), 16)
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.22), Size = grow(8, 30), Transparency = pop, ZOffset = 3 })
		em(g, "Rays", { Texture = TEX.line, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, Speed = R(40, 80), Lifetime = R(0.3, 0.6), Size = grow(12, 2), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 16 })
		em(g, "Petals", { Texture = TEX.petal, Color = FIRE, LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(14, 30), Acceleration = Vector3.new(0, -10, 0), Lifetime = R(1.2, 2), Size = grow(2.2, 1), Rotation = R(0, 360), RotSpeed = R(-160, 160), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitCount = 16 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(12, 22), Drag = 4, Lifetime = R(0.9, 1.4), Size = grow(3, 10), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 10 })
		em(g, "Embers", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(8, 24), Acceleration = Vector3.new(0, 2, 0), Lifetime = R(1.2, 2.2), Size = grow(0.5, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 20 })
	end

	-- SpiritGlint (at the Core): the spirit core's flash and star with motes.
	-- Used (smaller) for stagger and for the death's last glint.
	do
		local p = part(root, "SpiritGlint", Vector3.new(0.6, 0.6, 0.6))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.3), Size = grow(6, 20), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 6, Lifetime = R(0.55), Size = grow(2, 18, 0), ZOffset = 3 })
		em(p, "Motes", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(6, 20), Drag = 2, Acceleration = Vector3.new(0, 5, 0), Lifetime = R(1, 1.8), Size = grow(0.8, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 14 })
	end

	-- RoarBreath (at the Mouth, -Z = where it looks): the roar itself, thrown
	-- forward. Sound rings racing out on slate twins, wisp strokes and streaks
	-- flying ahead, a breath of pale mist, a flash in the jaws. Plays for the
	-- intro roar, the scream and the phase break (replaces the old Neon copy
	-- of the fox's head).
	do
		local p = part(root, "RoarBreath", Vector3.new(0.6, 0.6, 0.6))
		local ring = { Texture = TEX.ringThin, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(4, 4), Speed = R(14, 42), Drag = 2.5, Lifetime = R(0.55, 0.7) }
		em(p, "RingsDark", with(ring, { Color = CS(SLATE), Size = grow(3, 17), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), ZOffset = 0.5 }), { EmitCount = 3, NoTint = true })
		em(p, "Rings", with(ring, { Color = FIRE, LightEmission = 1, Brightness = 2, Size = grow(2.6, 16), Transparency = NS({ KP(0, 0.05), KP(0.7, 0.4), KP(1, 1) }), ZOffset = 1 }), { EmitCount = 3 })
		em(p, "Wisps", { Texture = TEX.wisp, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(22, 22), Speed = R(22, 36), Drag = 2, Lifetime = R(0.5, 0.8), Size = grow(4, 8), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), ZOffset = 1.2 }, { EmitCount = 6 })
		em(p, "Streaks", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(28, 28), Speed = R(50, 80), Lifetime = R(0.2, 0.3), Size = grow(7, 1), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 10 })
		em(p, "Mist", { Texture = TEX.puff, Color = CS(PALE), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Speed = R(14, 24), Drag = 3, Lifetime = R(0.7, 1.1), Size = grow(2.5, 9), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-30, 30) }, { EmitCount = 6, NoTint = true })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(3, 8), Transparency = pop, ZOffset = 3 })
	end

	-- Kindle (ground, authored r6, held 2.2: the intro): foxfire wakes in the
	-- grass round the fox and climbs. Spirit-flame flipbook tongues, twinkles
	-- and thin light streaks rising out of the sigil's area.
	do
		local p = part(root, "Kindle", Vector3.new(12, 0.4, 12), { AuthoredRadius = 6, AuthoredSeconds = 2.2 })
		local box = { Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top }
		em(p, "Spirits", with(box, { Texture = TEX.spiritFlip, FlipbookLayout = GRID2, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Brightness = 2, Rate = 12, SpreadAngle = Vector2.new(8, 8), Speed = R(3, 6), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(0.9, 1.4), Size = grow(2.6, 3.4, 1.2), Transparency = NS({ KP(0, 1), KP(0.2, 0.25), KP(0.7, 0.4), KP(1, 1) }) }), { EmitDuration = 2.2 })
		em(p, "Twinkles", with(box, { Texture = TEX.twinkle, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = CS(AZMID), LightEmission = 1, Brightness = 2, Rate = 14, SpreadAngle = Vector2.new(20, 20), Speed = R(3, 9), Lifetime = R(1, 1.8), Size = grow(1, 0.3), Transparency = NS({ KP(0, 1), KP(0.15, 0.1), KP(1, 1) }) }), { EmitDuration = 2.2 })
		em(p, "Streaks", with(box, { Texture = TEX.line, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(3, 3), Rate = 6, Speed = R(18, 30), Lifetime = R(0.5, 0.8), Size = grow(6, 1.5), Transparency = NS({ KP(0, 0.6), KP(0.3, 0.2), KP(1, 1) }) }), { EmitDuration = 2.2 })
	end

	-- Dissolve (death, held 2.6, the box covers the fox's body): the body
	-- burns away into foxfire. Flipbook flames, motes drifting up, wisp
	-- strokes and twinkles leave every part of it (replaces the Neon ghost).
	do
		local p = part(root, "Dissolve", Vector3.new(7, 6, 15), { AuthoredSeconds = 2.6 })
		local box = { Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, LockedToPart = false }
		em(p, "Flames", with(box, { Texture = TEX.flameFlip, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = FIRE, LightEmission = 1, Brightness = 2, Rate = 20, SpreadAngle = Vector2.new(15, 15), Speed = R(3, 6), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(0.8, 1.3), Size = grow(3.4, 1), Transparency = NS({ KP(0, 0.3), KP(0.6, 0.45), KP(1, 1) }), Rotation = R(-20, 20) }), { EmitDuration = 2.6 })
		em(p, "Motes", with(box, { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, Rate = 22, SpreadAngle = Vector2.new(40, 40), Speed = R(2, 6), Acceleration = Vector3.new(0.8, 5, 0), Lifetime = R(1.4, 2.4), Size = grow(0.45, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }), { EmitDuration = 2.6 })
		em(p, "Wisps", with(box, { Texture = TEX.wisp, Color = FIRE, LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 4, SpreadAngle = Vector2.new(12, 12), Speed = R(6, 10), Lifetime = R(0.9, 1.4), Size = grow(3.5, 6), Transparency = NS({ KP(0, 1), KP(0.3, 0.35), KP(1, 1) }) }), { EmitDuration = 2.6 })
		em(p, "Twinkles", with(box, { Texture = TEX.twinkle, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = CS(PALE), LightEmission = 1, Brightness = 2, Rate = 8, SpreadAngle = Vector2.new(60, 60), Speed = R(2, 5), Lifetime = R(0.8, 1.4), Size = grow(1.1, 0.3), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }), { EmitDuration = 2.6 })
	end

	-- SoulRelease (death, where the nine streams meet over the fox): the
	-- spirit core breaks free. A ring opening on its slate twin, petals and
	-- twinkles drifting down. SpiritGlint plays with it.
	do
		local p = part(root, "SoulRelease", Vector3.new(0.6, 0.6, 0.6))
		em(p, "RingDark", { Texture = TEX.ringThin, Color = CS(SLATE), Lifetime = R(0.8), Size = grow(3, 26), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), ZOffset = 0.5 }, NOTINT)
		em(p, "Ring", { Texture = TEX.ringThin, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.8), Size = grow(2.5, 24), Transparency = NS({ KP(0, 0), KP(0.7, 0.4), KP(1, 1) }), ZOffset = 1 })
		em(p, "Petals", { Texture = TEX.petal, Color = FIRE, LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(6, 14), Drag = 1.5, Acceleration = Vector3.new(0, -3, 0), Lifetime = R(2, 3.2), Size = grow(1.4, 0.6), Rotation = R(0, 360), RotSpeed = R(-120, 120), Transparency = NS({ KP(0, 0.1), KP(0.8, 0.3), KP(1, 1) }) }, { EmitCount = 14 })
		em(p, "Twinkles", { Texture = TEX.twinkle, FlipbookLayout = GRID4, FlipbookMode = ONESHOT, Color = CS(PALE), LightEmission = 1, Brightness = 2, SpreadAngle = Vector2.new(180, 180), Speed = R(4, 16), Drag = 2, Acceleration = Vector3.new(0, -2, 0), Lifetime = R(1.2, 2.2), Size = grow(1.2, 0.3), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 18, NoTint = true })
	end

	root.Parent = effects
	return root
end
print("buildNineTailFoxFX installed")
return true
