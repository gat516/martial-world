--!nocheck
-- Builder for ReplicatedStorage.Effects.JadeJiao: the Jade Jiao boss's attack,
-- hit, phase, aura, burrow and death effects. Load through the receiver, then
-- build into staging:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/JadeJiao.luau")
--   require(m)  -- installs _G.buildJadeJiaoFX(effectsFolder)
-- Runtime: src/client/EnemyFX/JadeJiao.luau (cue -> template, placement).
--
-- Identity: acid venom-green (9BFF4A) with white-hot centres is the element;
-- amber-gold is only ever a warning tell (gold means react); pale spirit-jade
-- (A8FFD8) is the phase 3 aura and ghost motes; a slate/ink copy sits under
-- every bright shape so it reads on daylight grass. No crown, halo or ring
-- over the head. Sized for the 1.668x body (about 115 long, 23 tall).
-- Every template is an invisible anchored Part (centre = pivot, -Z = facing
-- or blow direction). Ground templates have their centre on the floor.
-- `AuthoredSeconds` (windup holds) and `AuthoredRadius` (ground shapes) let
-- the runtime refit them to the live windup and locked circle.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local VENOM = Color3.fromRGB(155, 255, 74)
local VHOT = Color3.fromRGB(226, 255, 182)
local VDEEP = Color3.fromRGB(60, 150, 44)
local JADE = Color3.fromRGB(168, 255, 216)
local GOLD = Color3.fromRGB(255, 190, 70)
local HOT = Color3.fromRGB(255, 236, 176)
local INK = Color3.fromRGB(10, 18, 14)
local SLATE = Color3.fromRGB(28, 42, 36)
local DUST = Color3.fromRGB(150, 138, 116)
local SOIL = Color3.fromRGB(92, 72, 50)

local TEX = {
	glint = id(84223532517124),
	dot = id(9841273544),
	mote = id(8238126392),
	ringThin = id(9841273159),
	ringThick = id(13322173171),
	ringSpiky = id(13052243772),
	ringDust = id(13052235894),
	arc = id(13366366767),
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
	ink = id(16132530029), -- splash/ink blot, used as the venom splat
	swirl = id(10352554571),
}

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

-- dark base, rim and white-hot core of one shape
local function stack(parent, name, base, size, rimColor, coreColor, darkColor)
	em(parent, name .. "Dark", with(base, {
		Color = CS(darkColor or SLATE),
		Size = size(1.15),
		Transparency = NS({ KP(0, 0.2), KP(0.6, 0.35), KP(1, 1) }),
		ZOffset = 0.5,
	}))
	em(parent, name .. "Rim", with(base, {
		Color = CS(rimColor or VENOM),
		LightEmission = 0.8,
		Size = size(1.0),
		Transparency = NS({ KP(0, 0.1), KP(0.6, 0.25), KP(1, 1) }),
		ZOffset = 1,
	}))
	em(parent, name .. "Core", with(base, {
		Color = CS({ CK(0, WHITE), CK(1, coreColor or VHOT) }),
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

-- flat ring on the ground: expanding (a -> b), white-hot to `color`
local function gring(g, name, tex, color, life, a, b, extra)
	local attrs
	if extra and extra.EmitDelay then
		attrs = { EmitCount = 1, EmitDelay = extra.EmitDelay }
		extra = table.clone(extra)
		extra.EmitDelay = nil
	end
	return em(g, name, with(FLAT, with({
		Texture = tex,
		Color = CS({ CK(0, WHITE), CK(1, color) }),
		LightEmission = 1,
		Lifetime = R(life),
		Size = grow(a, b),
		Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		ZOffset = 1,
	}, extra or {})), attrs)
end

local function dustRing(g, life, a, b, color)
	return em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(color or SLATE), Lifetime = R(life), Size = grow(a, b), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
end

local function wall(g, name, count, speed, size, color, life)
	return em(g, name, { Texture = TEX.puff, Color = CS(color or DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(speed * 0.6, speed), Drag = 4, Lifetime = R(life * 0.7, life), Size = grow(size * 0.35, size), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = count })
end

local function chips(g, name, tex, color, count, speed, size, spread)
	return em(g, name, { Texture = tex, Color = CS(color), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(spread or 55, spread or 55), Speed = R(speed * 0.55, speed), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.8, 1.3), Size = grow(size, size * 0.8), RotSpeed = R(-400, 400), Rotation = R(0, 360) }, { EmitCount = count })
end

-- the long-lived dark scorch/crack decal that fades (several seconds)
local function scorch(g, r, life)
	em(g, "ScorchInk", with(FLAT, { Texture = TEX.ink, Color = CS(INK), Lifetime = R(life), Size = grow(r * 0.7, r * 1.6, r * 1.7), Transparency = NS({ KP(0, 0.25), KP(0.6, 0.35), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.1 }))
	em(g, "ScorchCracks", with(FLAT, { Texture = TEX.crackDark, Color = CS(INK), Lifetime = R(life), Size = grow(r, r * 2, r * 2.1), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
end

local function litCrack(g, r, life, delay)
	return em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, VENOM), CK(1, VDEEP) }), LightEmission = 1, Brightness = 2, Lifetime = R(life), Size = grow(r * 0.9, r * 1.9), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }), delay and { EmitCount = 1, EmitDelay = delay } or nil)
end

local function flashStar(p, flash, star, color)
	em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.15), Size = grow(flash * 0.4, flash), Transparency = pop, ZOffset = 3 })
	em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, color or VENOM) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.28), Size = grow(star * 0.1, star, 0), ZOffset = 3 })
end

local function rays(p, count, speed, size, color, dir, spread)
	return em(p, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, color or VENOM) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = dir or Enum.NormalId.Front, SpreadAngle = Vector2.new(spread or 40, spread or 40), Speed = R(speed * 0.6, speed), Lifetime = R(0.25, 0.45), Size = grow(size, size * 0.2), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = count })
end

local function drops(p, name, count, speed, spread, dir, color)
	return em(p, name, { Texture = TEX.dot, Color = CS({ CK(0, VHOT), CK(1, color or VENOM) }), LightEmission = 1, EmissionDirection = dir or Enum.NormalId.Top, SpreadAngle = Vector2.new(spread or 60, spread or 60), Speed = R(speed * 0.4, speed), Acceleration = Vector3.new(0, -45, 0), Lifetime = R(0.5, 1.0), Size = grow(0.7, 0.3), Transparency = NS({ KP(0, 0), KP(0.8, 0.1), KP(1, 1) }) }, { EmitCount = count })
end

local function splat(p, size, life, color, delay)
	return em(p, "Splat", with(FLAT, { Texture = TEX.ink, Color = CS(color or VENOM), LightEmission = 0.7, Lifetime = R(life or 1.4), Size = grow(size * 0.5, size, size * 1.05), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.6 }), delay and { EmitCount = 1, EmitDelay = delay } or nil)
end

-- a held glow over an ink base, swelling to `size` over the template's seconds
local function swell(p, name, color, life, size, bright)
	em(p, name .. "Dark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(life), Size = grow(size * 0.1, size * 0.8), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.45), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
	em(p, name, { Texture = TEX.dot, Color = CS({ CK(0, color), CK(1, HOT) }), LightEmission = 1, Brightness = bright or 3, Lifetime = R(life), Size = grow(size * 0.06, size * 0.5), Transparency = NS({ KP(0, 0.9), KP(0.85, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
end

local function gather(p, color, life, rate, speed, size, glintColor)
	em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, color), CK(1, glintColor or VHOT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = rate, Lifetime = R(0.35, 0.55), Speed = R(speed * 0.7, speed), Size = grow(size, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = life })
	em(p, "Pull", { Texture = TEX.line, Color = CS(color), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = rate * 0.4, Lifetime = R(0.3, 0.45), Speed = R(speed * 1.4, speed * 1.9), Size = grow(size * 5, 0.5), Transparency = NS({ KP(0, 1), KP(0.3, 0.2), KP(1, 0.8) }) }, { EmitDuration = life * 0.95, EmitDelay = life * 0.1 })
end

-- Marker: the circle's radius drawn in amber over the stock fill (refit by code)
local function marker(root, name, authoredSeconds, authoredRadius, full)
	local p = part(root, name, Vector3.new(authoredRadius * 2, 0.2, authoredRadius * 2), { AuthoredSeconds = authoredSeconds, AuthoredRadius = authoredRadius })
	local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
	local life = R(authoredSeconds)
	local d = authoredRadius * 2
	em(g, "EdgeDark", with(FLAT, { Texture = TEX.ringThick, Color = CS(INK), Lifetime = life, Size = grow(d * 1.06, d * 1.06), Transparency = NS({ KP(0, 1), KP(0.08, 0.35), KP(0.92, 0.35), KP(1, 1) }), ZOffset = 0.2 }))
	em(g, "Edge", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, GOLD), CK(0.8, GOLD), CK(1, WHITE) }), LightEmission = 1, Brightness = 2, Lifetime = life, Size = grow(d, d), Transparency = NS({ KP(0, 1), KP(0.08, 0.1), KP(0.7, 0.2), KP(0.85, 0), KP(0.92, 0.3), KP(1, 1) }), ZOffset = 1 }))
	em(g, "Fill", with(FLAT, { Texture = TEX.dot, Color = CS(GOLD), LightEmission = 0.8, Lifetime = life, Size = grow(d * 0.04, d * 0.96), Transparency = NS({ KP(0, 0.8), KP(1, 0.55) }), ZOffset = 0.5 }))
	em(g, "Closing", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = life, Size = grow(d * 1.7, d), Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1.4 }))
	if full then
		em(g, "Array", with(FLAT, { Texture = TEX.mandala, Color = CS(HOT), LightEmission = 1, Lifetime = life, Size = grow(d * 0.85, d * 0.85), RotSpeed = R(35), Rotation = R(0), Transparency = NS({ KP(0, 1), KP(0.1, 0.55), KP(0.85, 0.5), KP(1, 1) }), ZOffset = 0.8 }))
		em(p, "EdgeSparks", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(3, 9), Rate = 36, Lifetime = R(0.4, 0.7), Size = grow(0.55, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = authoredSeconds })
	end
	return p
end

local function craters(p, radius, count, size)
	local rocks = att(p, "Rocks", Vector3.new(0, 0.5, 0))
	rocks:AddTag("CraterVFX")
	for k, v in {
		Shape = "Ring", Fill = true, EmissionStart = "Progressive", Radius = radius * 0.8, Variance = radius * 0.2, Duration = 0.3,
		Count = R(count, count + 4), Lifetime = R(1.4, 2.2), Size = Vector3.new(size * 1.6, size * 0.9, size * 1.2), SizeScale = R(0.7, 1.4),
		Collision = false, MatchGround = true, YOffset = 0.45, AngleX = R(25, 50), SpawnTime = R(0.05, 0.25), DespawnTime = R(0.8, 1.1),
	} do
		rocks:SetAttribute(k, v)
	end
end

function _G.buildJadeJiaoFX(effects)
	local old = effects:FindFirstChild("JadeJiao")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "JadeJiao"

	---------------------------------------------------------------- tells

	-- EyeFlare: on both eyes at every windup, and on the tail gem. A hot amber
	-- star pop, a held glow, a needle rising off the eye.
	do
		local p = part(root, "EyeFlare", nil, { AuthoredSeconds = 0.6 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.4, HOT), CK(1, GOLD) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.22), Size = grow(0.6, 4.2, 0), Rotation = R(-8, 8), ZOffset = 2 })
		em(p, "Pop", { Texture = TEX.dot, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.28), Size = grow(2, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.5 })
		em(p, "Hold", { Texture = TEX.dot, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.12, 0.2), Rate = 20, Size = grow(1.2, 0.6), Transparency = NS({ KP(0, 0.3), KP(1, 0.85) }), LockedToPart = true, ZOffset = 1.5 }, { EmitDuration = 0.6 })
		em(p, "Needle", { Texture = TEX.line, Color = CS(HOT), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, Speed = R(6, 10), Lifetime = R(0.25), Size = grow(3.4, 0.3), Transparency = NS({ KP(0, 0) , KP(1, 1) }) }, { EmitCount = 2 })
	end

	-- HoodFlare: the hood eye-spots burn green while the hood unfurls.
	do
		local p = part(root, "HoodFlare", nil, { AuthoredSeconds = 0.8 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.3), Size = grow(0.6, 5, 0), ZOffset = 2 })
		em(p, "Pop", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, Lifetime = R(0.3), Size = grow(2.4, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.5 })
		em(p, "Hold", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, Lifetime = R(0.14, 0.22), Rate = 18, Size = grow(1.6, 0.8), Transparency = NS({ KP(0, 0.3), KP(1, 0.85) }), LockedToPart = true, ZOffset = 1.5 }, { EmitDuration = 0.8 })
	end

	-- FangTell (venomFang 0.75 and the flurry, at the Mouth): breath drawn into
	-- the muzzle as green motes, two rings closing, a swelling glow over ink,
	-- a fang glint top and bottom just before the snap, a drip.
	do
		local p = part(root, "FangTell", Vector3.new(9, 9, 9), { AuthoredSeconds = 0.75 })
		gather(p, VENOM, 0.75, 46, 22, 0.8)
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Brightness = 2, Lifetime = R(0.75), Size = grow(11, 1), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(HOT), LightEmission = 1, Lifetime = R(0.45), Size = grow(7, 0.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.4) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 0.3 })
		swell(p, "Glow", VENOM, 0.75, 7)
		local top = att(p, "Top", Vector3.new(0, 2.4, 0))
		local bot = att(p, "Bottom", Vector3.new(0, -2.4, 0))
		for _, a in { top, bot } do
			em(a, "Fang", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.26), Size = grow(0.4, 4.4, 0), Rotation = R(a == top and 0 or 90), ZOffset = 2, LockedToPart = true }, { EmitDelay = 0.5 })
		end
		em(p, "Mist", { Texture = TEX.puff, Color = CS(VDEEP), Rate = 14, Speed = R(3, 7), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Lifetime = R(0.6, 0.9), Size = grow(1.4, 4.2), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 0.75 })
		em(p, "Drip", { Texture = TEX.dot, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, Rate = 12, EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(12, 12), Speed = R(1, 4), Acceleration = Vector3.new(0, -40, 0), Lifetime = R(0.4, 0.7), Size = grow(0.6, 0.3), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitDuration = 0.75 })
	end

	-- FangSnap (contact at the Mouth): upper and lower fang crescents slam
	-- shut, white flash and star, spiky ring, a poison splash of drops, ink.
	do
		local p = part(root, "FangSnap", Vector3.new(0.4, 0.4, 0.4))
		local upper = att(p, "Upper", Vector3.new(0, 3.4, 0))
		local lower = att(p, "Lower", Vector3.new(0, -3.4, 0))
		local crescent = { Texture = TEX.arc, Lifetime = R(0.2), Drag = 8, Speed = R(36) }
		stack(upper, "Upper", with(crescent, { Rotation = R(0), EmissionDirection = Enum.NormalId.Bottom }), scaled(6.5, 9.5))
		stack(lower, "Lower", with(crescent, { Rotation = R(180), EmissionDirection = Enum.NormalId.Top }), scaled(6.5, 9.5))
		flashStar(p, 15, 14)
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(3, 22), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
		rays(p, 14, 70, 7, VHOT, Enum.NormalId.Front, 40)
		em(p, "Ink", { Texture = TEX.ink, Color = CS(SLATE), Lifetime = R(0.4), Size = grow(7, 12), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		drops(p, "Splash", 18, 26, 60, Enum.NormalId.Front)
		em(p, "Fume", { Texture = TEX.puff, Color = CS(VDEEP), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(50, 50), Speed = R(6, 12), Drag = 3, Lifetime = R(0.8, 1.3), Size = grow(3, 8), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 6 })
		shake(p, "Custom,25~95,0.9,0.35,18,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- TailTell (tailSweep 0.8, at the tail tip): a glint, an amber ring
	-- closing on the tip, sparks.
	do
		local p = part(root, "TailTell", nil, { AuthoredSeconds = 0.8 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.5, HOT), CK(1, GOLD) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.35), Size = grow(0.6, 7, 0), ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.8), Size = grow(11, 1), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.9, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1.5 })
		swell(p, "Glow", GOLD, 0.8, 7)
		em(p, "Sparks", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, Rate = 34, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 8), Lifetime = R(0.2, 0.35), Size = grow(0.45, 0), LockedToPart = true }, { EmitDuration = 0.8 })
	end

	-- TailWhip: a trail on the tail tip during the sweep (continuous; code
	-- enables it, follows the tip and disables it).
	do
		local p = part(root, "TailWhip", Vector3.new(2, 2, 2))
		local top = att(p, "Top", Vector3.new(0, 3.2, 0))
		local mid = att(p, "Mid", Vector3.new(0, 0.6, 0))
		local bottom = att(p, "Bottom", Vector3.new(0, -3.2, 0))
		trail(p, "Dark", top, bottom, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS(INK), Lifetime = 0.45, MinLength = 0.05, Transparency = NS({ KP(0, 0.25), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.3) }) })
		trail(p, "Bright", top, mid, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(0.4, VHOT), CK(1, VENOM) }), LightEmission = 1, Brightness = 2, Lifetime = 0.45, MinLength = 0.05, Transparency = NS({ KP(0, 0), KP(0.6, 0.35), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.2) }) })
		em(p, "Wind", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Rate = 26, Speed = R(10, 22), SpreadAngle = Vector2.new(180, 180), Lifetime = R(0.18, 0.28), Size = grow(8, 1), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
		em(p, "Spray", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, Rate = 16, SpreadAngle = Vector2.new(180, 180), Speed = R(4, 12), Lifetime = R(0.3, 0.5), Size = grow(0.7, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
	end

	-- Marker (amber circle at the locked spot; authored r13, 1.0 s): used for
	-- the sweep, slam, erupt and coil circles. MarkerLite (r4.5, 0.9 s) for the
	-- pool and rain circles keeps each cheap.
	marker(root, "Marker", 1.0, 13, true)
	marker(root, "MarkerLite", 0.9, 4.5, false)

	-- GroundGather (slam, dive: dust and motes drawn in on the ground
	-- under the snake, authored r8, 1.0 s)
	do
		local p = part(root, "GroundGather", Vector3.new(16, 0.2, 16), { AuthoredSeconds = 1.0, AuthoredRadius = 8 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		em(g, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.0), Size = grow(3, 17), Transparency = NS({ KP(0, 1), KP(0.15, 0.45), KP(0.9, 0.55), KP(1, 1) }), ZOffset = 0.2 }))
		em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, EmissionDirection = Enum.NormalId.Top, Rate = 26, Speed = R(8, 14), Lifetime = R(0.5, 0.8), Size = grow(2.6, 1), Transparency = NS({ KP(0, 0.7), KP(0.3, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 1.0 })
		em(p, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, VENOM), CK(1, VHOT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, EmissionDirection = Enum.NormalId.Top, Rate = 22, Speed = R(6, 12), Lifetime = R(0.5, 0.8), Size = grow(0.7, 0), Transparency = NS({ KP(0, 0.6), KP(0.3, 0.1), KP(1, 0.6) }) }, { EmitDuration = 1.0 })
		gring(g, "Closing", TEX.ringThin, GOLD, 1.0, 20, 6, { Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1.2 })
	end

	-- SlamTell (pillarSlam 1.0, at the head): a gold glow swelling over ink,
	-- motes drawn in, a closing ring. The head rises in the pose; this is
	-- the heat gathering at the skull.
	do
		local p = part(root, "SlamTell", Vector3.new(12, 12, 12), { AuthoredSeconds = 1.0 })
		gather(p, GOLD, 1.0, 50, 20, 0.9, HOT)
		swell(p, "Glow", GOLD, 1.0, 12, 4)
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.9), Size = grow(16, 1.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.1 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.5), Size = grow(10, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.3) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 0.5 })
	end

	-- SweepImpact (tailSweep contact, centre of the locked circle, authored
	-- r13): huge wind crescents spinning across the whole circle, a dust
	-- ring and wall, a venom ring, chips and grit.
	do
		local p = part(root, "SweepImpact", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13 })
		local g = att(p, "Ground", Vector3.new(0, 1.6, 0))
		local arc = { Texture = TEX.arc, Lifetime = R(0.42), RotSpeed = R(560, 600), Rotation = R(0, 360) }
		em(g, "ArcDark", with(FLAT, with(arc, { Color = CS(SLATE), Size = grow(28, 31), Transparency = NS({ KP(0, 0.3), KP(0.6, 0.45), KP(1, 1) }), ZOffset = 0.5 })))
		em(g, "ArcRim", with(FLAT, with(arc, { Texture = TEX.arcSoft, Color = CS(VENOM), LightEmission = 1, Size = grow(26, 29), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1 })))
		em(g, "ArcCore", with(FLAT, with(arc, { Color = CS({ CK(0, WHITE), CK(1, VHOT) }), LightEmission = 1, Brightness = 3, Size = grow(24, 27), Transparency = NS({ KP(0, 0), KP(0.6, 0.25), KP(1, 1) }), ZOffset = 1.5 })))
		em(g, "ArcEcho", with(FLAT, with(arc, { Color = CS(VHOT), LightEmission = 1, RotSpeed = R(420, 460), Size = grow(20, 24), Lifetime = R(0.5), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.8 })), { EmitCount = 1, EmitDelay = 0.05 })
		gring(g, "Ring", TEX.ringThick, VENOM, 0.4, 2, 26, { Brightness = 2, ZOffset = 1.5 })
		dustRing(g, 0.7, 4, 30)
		wall(g, "Wall", 22, 36, 9, DUST, 1.3)
		em(g, "Wind", { Texture = TEX.streaks, Color = CS(VHOT), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, Speed = R(20, 40), SpreadAngle = Vector2.new(5, 5), Lifetime = R(0.3, 0.45), Size = grow(6, 4), Transparency = NS({ KP(0, 0.3), KP(1, 1) }) }, { EmitCount = 16 })
		chips(g, "Chips", TEX.chips, DUST, 12, 30, 1.2, 70)
		em(g, "Grit", { Texture = TEX.mote, Color = CS(SOIL), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Speed = R(14, 30), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.4, 0.7), Size = NS(0.35) }, { EmitCount = 16 })
		shake(p, "Custom,25~100,1.2,0.5,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- SlamImpact (pillarSlam contact, the locked circle, authored r6.5): the
	-- head's impact crater: flash and star, three rings, dust wall, chips and
	-- chunks, rays, a lit venom crack under a scorch that stays about 6 s.
	do
		local p = part(root, "SlamImpact", Vector3.new(13, 0.2, 13), { AuthoredRadius = 6.5 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		scorch(g, 13, 6)
		em(g, "CrackLines", with(FLAT, { Texture = TEX.crackLines, Color = CS(SLATE), Lifetime = R(6), Size = grow(9, 18, 19), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.3 }))
		litCrack(g, 13, 1.6)
		gring(g, "Ring", TEX.ringThick, VENOM, 0.4, 1, 20, { Brightness = 2, ZOffset = 1.5 })
		gring(g, "RingSpiky", TEX.ringSpiky, VENOM, 0.55, 2, 22, { Rotation = R(0, 360), ZOffset = 1.2 })
		gring(g, "RingThin", TEX.ringThin, WHITE, 0.8, 2, 28, { ZOffset = 1.8, EmitDelay = 0.08 })
		dustRing(g, 0.6, 3, 22)
		wall(g, "Wall", 24, 34, 8, DUST, 1.3)
		chips(g, "Chips", TEX.chips, DUST, 16, 46, 1.3, 60)
		chips(g, "Chunks", TEX.rock, SLATE, 8, 38, 1.8, 55)
		rays(p, 14, 90, 11, VENOM, Enum.NormalId.Top, 22)
		g = att(p, "Flare", Vector3.new(0, 0.5, 0))
		flashStar(g, 22, 16)
		em(g, "Splat", with(FLAT, { Texture = TEX.ink, Color = CS(VENOM), LightEmission = 0.7, Lifetime = R(2.2), Size = grow(6, 13, 14), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.35), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.6 }))
		em(g, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(4, 16), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(1.5, 2.6), Size = grow(0.45, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 18 })
		em(g, "Smoke", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Speed = R(2, 7), Drag = 1.5, Lifetime = R(2, 3.2), Size = grow(4, 12), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-20, 20) }, { EmitCount = 8, EmitDelay = 0.1 })
		craters(p, 6.5, 10, 2.2)
		shake(p, "Explosion,30~120,2.8,0.9,20,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- GroundMark (small ground hit, authored r4.5): flurry cone marks and the
	-- pool lobs. A ring, a lit crack, a little splat, dust and chips.
	do
		local p = part(root, "GroundMark", Vector3.new(9, 0.2, 9), { AuthoredRadius = 4.5 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INK), Lifetime = R(3), Size = grow(4, 8, 8.5), Transparency = NS({ KP(0, 0.1), KP(0.1, 0.1), KP(0.7, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		litCrack(g, 8, 0.8)
		gring(g, "Ring", TEX.ringThick, VENOM, 0.3, 1, 11)
		dustRing(g, 0.45, 2, 11)
		splat(g, 6, 1.4)
		wall(g, "Dust", 7, 14, 4.5, DUST, 0.9)
		chips(g, "Chips", TEX.chips, DUST, 6, 22, 0.8, 50)
		g = att(p, "Flare", Vector3.new(0, 0.4, 0))
		flashStar(g, 8, 6)
	end

	---------------------------------------------------------------- burrow

	-- DiveBurst (mireDive, at Dive_FX as the body sinks, authored r6): a burst
	-- of soil and a hole collapsing: the dark hole shrinks shut under a ring
	-- of dust, soil chunks fall back, green glints leak out.
	do
		local p = part(root, "DiveBurst", Vector3.new(12, 0.2, 12), { AuthoredRadius = 6 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "HoleDark", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.0), Size = grow(13, 11, 1), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.1), KP(1, 1) }), ZOffset = 0.3 }))
		em(g, "HoleCracks", with(FLAT, { Texture = TEX.crackHole, Color = CS(SOIL), Lifetime = R(2.4), Size = grow(8, 16, 17), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		litCrack(g, 12, 0.9)
		gring(g, "Ring", TEX.ringThick, VENOM, 0.35, 2, 17)
		dustRing(g, 0.6, 3, 22, SOIL)
		wall(g, "Dust", 18, 26, 8, DUST, 1.1)
		chips(g, "Soil", TEX.rock, SOIL, 10, 30, 1.8, 40)
		chips(g, "Chips", TEX.chips, SOIL, 12, 26, 1.1, 50)
		em(g, "Glints", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(6, 16), Acceleration = Vector3.new(0, -10, 0), Lifetime = R(0.5, 1.0), Size = grow(1, 0), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 10 })
		shake(p, "Custom,25~90,0.9,0.45,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- RidgeFX (the moving earth ridge's head: code drives it along the dive
	-- line): dust thrown up, grit, a venom crack glow flickering on the earth.
	do
		local p = part(root, "RidgeFX", Vector3.new(3, 1, 3))
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Rate = 22, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(3, 8), Drag = 2, Lifetime = R(0.7, 1.2), Size = grow(3, 8), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) })
		em(g, "Grit", { Texture = TEX.mote, Color = CS(SOIL), Rate = 20, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(8, 16), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.4, 0.7), Size = NS(0.4) })
		em(g, "Crack", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, VENOM), CK(1, VDEEP) }), LightEmission = 1, Brightness = 2, Rate = 5, Lifetime = R(0.7), Size = grow(5, 9), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Glints", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Rate = 4, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(2, 6), Lifetime = R(0.3, 0.5), Size = grow(1.2, 0), Transparency = NS({ KP(0, 0), KP(1, 1) }) })
	end

	-- EmergeBuild (emerge 2.2 s and erupt 0.85 s, on the ground; authored r14):
	-- tremors and cracks building: an ink pool, dust rumbling, small rings
	-- shivering out, cracks spreading late, motes rising, an amber ring
	-- closing on the spot.
	do
		local p = part(root, "EmergeBuild", Vector3.new(28, 0.2, 28), { AuthoredSeconds = 2.2, AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = R(2.2), Size = grow(4, 28), Transparency = NS({ KP(0, 1), KP(0.2, 0.5), KP(0.9, 0.5), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INK), Lifetime = R(1.2), Size = grow(6, 30, 31), Transparency = NS({ KP(0, 0.4), KP(0.2, 0.15), KP(1, 0.1) }), Rotation = R(0, 360), ZOffset = 0.3 }), { EmitCount = 1, EmitDelay = 1.0 })
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, VDEEP), CK(0.7, VENOM), CK(1, WHITE) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.2), Size = grow(5, 26), Transparency = NS({ KP(0, 1), KP(0.25, 0.4), KP(1, 0) }), Rotation = R(0, 360), ZOffset = 0.5 }), { EmitCount = 1, EmitDelay = 1.0 })
		em(g, "Tremor", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Rate = 3, Lifetime = R(0.7), Size = grow(2, 12), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), ZOffset = 0.4 }), { EmitDuration = 2.2 })
		em(g, "Pulse", with(FLAT, { Texture = TEX.ringThin, Color = CS(VENOM), LightEmission = 1, Rate = 1.6, Lifetime = R(0.8), Size = grow(3, 14), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), ZOffset = 1 }), { EmitDuration = 2.2, EmitDelay = 0.8 })
		gring(g, "Closing", TEX.ringThin, GOLD, 2.2, 42, 14, { Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1.2 })
		em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Cylinder, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Rate = 16, Speed = R(2, 6), Lifetime = R(0.8, 1.4), Size = grow(3, 9), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 2.2, EmitDelay = 0.3 })
		em(p, "Pebbles", { Texture = TEX.chips, Color = CS(SOIL), Shape = Enum.ParticleEmitterShape.Cylinder, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Rate = 4, Speed = R(5, 11), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.5, 0.8), Size = grow(0.8, 0.6), RotSpeed = R(-200, 200) }, { EmitDuration = 2.2, EmitDelay = 0.6 })
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, VENOM), CK(1, VHOT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, EmissionDirection = Enum.NormalId.Top, Rate = 12, Speed = R(2, 6), Lifetime = R(1, 1.6), Size = grow(0.6, 0), Transparency = NS({ KP(0, 0.4), KP(1, 1) }) }, { EmitDuration = 2.0, EmitDelay = 0.8 })
	end

	-- EmergeBurst (emerge and erupt contact, authored r14): the biggest effect
	-- of the fight with the death. Dust column, rocks, three rings, a green
	-- flash and star, rays, a lit crack under a long scorch, Craters rocks.
	do
		local p = part(root, "EmergeBurst", Vector3.new(28, 0.2, 28), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		scorch(g, 28, 6)
		em(g, "CrackLines", with(FLAT, { Texture = TEX.crackLines, Color = CS(SLATE), Lifetime = R(6), Size = grow(20, 40, 42), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.3 }))
		litCrack(g, 28, 1.8)
		gring(g, "Ring", TEX.ringThick, VENOM, 0.45, 1, 40, { Brightness = 2, ZOffset = 1.5 })
		gring(g, "RingSpiky", TEX.ringSpiky, VENOM, 0.6, 2, 44, { Rotation = R(0, 360), ZOffset = 1.2 })
		gring(g, "RingThin", TEX.ringThin, WHITE, 0.9, 2, 56, { ZOffset = 1.8, EmitDelay = 0.1 })
		dustRing(g, 0.7, 4, 42, SOIL)
		wall(g, "Wall", 30, 44, 14, DUST, 1.5)
		-- the column: big dust puffs shot straight up
		em(g, "Column", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8), Speed = R(30, 60), Drag = 1.5, Lifetime = R(1.0, 1.7), Size = grow(7, 18), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 22 })
		em(g, "Beam", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3), Speed = R(50, 80), Lifetime = R(0.4, 0.7), Size = grow(9, 3), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitCount = 8 })
		chips(g, "Chips", TEX.chips, DUST, 22, 60, 1.6, 55)
		chips(g, "Rocks", TEX.rock, SLATE, 12, 50, 2.4, 50)
		rays(p, 20, 120, 16, VENOM, Enum.NormalId.Top, 25)
		local f = att(p, "Flare", Vector3.new(0, 1, 0))
		flashStar(f, 40, 28)
		em(f, "Splat", with(FLAT, { Texture = TEX.ink, Color = CS(VENOM), LightEmission = 0.7, Lifetime = R(2.4), Size = grow(12, 26, 28), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.35), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.6 }))
		em(f, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(6, 24), Acceleration = Vector3.new(0, 5, 0), Lifetime = R(1.6, 3), Size = grow(0.9, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 24 })
		em(f, "Smoke", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Speed = R(3, 9), Drag = 1.5, Lifetime = R(2.4, 3.6), Size = grow(8, 22), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-20, 20) }, { EmitCount = 10, EmitDelay = 0.1 })
		craters(p, 14, 14, 3.4)
		shake(p, "Explosion,30~140,3.6,1.0,20,0.02,1;1;1,0.1;0.1;0.1")
	end

	---------------------------------------------------------------- spit

	-- SpitGather (venomLance 0.7, venomSpray 1.0, venomPools 1.0, venomRain
	-- gather when tinted jade; at the Mouth): sparks drawn in, a swelling
	-- glow over ink, a white core, an amber ring closing.
	do
		local p = part(root, "SpitGather", Vector3.new(8, 8, 8), { AuthoredSeconds = 0.7 })
		gather(p, VENOM, 0.7, 42, 20, 0.7)
		swell(p, "Glow", VENOM, 0.7, 7)
		em(p, "Core", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VHOT) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.7), Size = grow(0.3, 3.4), Transparency = NS({ KP(0, 0.9), KP(0.85, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 2 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.7), Size = grow(9, 0.8), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
	end

	-- SpitRelease (each bolt leaving the Mouth): a short flash and a ring.
	do
		local p = part(root, "SpitRelease", Vector3.new(0.4, 0.4, 0.4))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(3, 9), Transparency = pop, ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Lifetime = R(0.25), Size = grow(1, 9), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
		drops(p, "Drops", 8, 22, 40, Enum.NormalId.Front)
	end

	-- VenomBolt (projectile, continuous: code drives it): a white-hot core on
	-- a green glow over ink, a particle trail, drips and sparks.
	do
		local p = part(root, "VenomBolt", Vector3.new(2, 2, 2))
		local top = att(p, "Top", Vector3.new(0, 1.0, 0))
		local bottom = att(p, "Bottom", Vector3.new(0, -1.0, 0))
		trail(p, "Streak", top, bottom, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(0.3, VENOM), CK(1, VDEEP) }), LightEmission = 1, Brightness = 2, Lifetime = 0.35, MinLength = 0.05, Transparency = NS({ KP(0, 0.1), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.1) }) })
		em(p, "Ink", { Texture = TEX.dot, Color = CS(INK), Rate = 14, Lifetime = R(0.4), Size = grow(3, 6), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, Brightness = 2, Rate = 40, Lifetime = R(0.12, 0.18), Size = grow(4.5, 3), Transparency = NS({ KP(0, 0.2), KP(1, 0.7) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Core", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Rate = 40, Lifetime = R(0.12, 0.18), Size = grow(2.4, 1.8), Transparency = NS({ KP(0, 0), KP(1, 0.5) }), LockedToPart = true, ZOffset = 2 })
		em(p, "Trail", { Texture = TEX.dot, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, Rate = 40, SpreadAngle = Vector2.new(25, 25), Speed = R(1, 4), Lifetime = R(0.3, 0.5), Size = grow(2.4, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
		em(p, "Drips", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, Rate = 14, SpreadAngle = Vector2.new(40, 40), Speed = R(1, 5), Acceleration = Vector3.new(0, -45, 0), Lifetime = R(0.4, 0.8), Size = grow(0.7, 0.3), Transparency = NS({ KP(0, 0), KP(1, 1) }) })
	end

	-- BoltImpact (end of a bolt lane, or on the player it caught): a splat,
	-- a flash, acid sparks. Short.
	do
		local p = part(root, "BoltImpact", Vector3.new(0.4, 0.4, 0.4))
		flashStar(p, 11, 8)
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
		em(p, "Splat", { Texture = TEX.ink, Color = CS(VENOM), LightEmission = 0.7, Lifetime = R(0.5), Size = grow(3, 9), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1 })
		drops(p, "Drops", 14, 26, 90, Enum.NormalId.Top)
		em(p, "Fume", { Texture = TEX.puff, Color = CS(VDEEP), SpreadAngle = Vector2.new(180, 180), Speed = R(3, 8), Drag = 3, Lifetime = R(0.6, 1.0), Size = grow(2, 6), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 4 })
	end

	-- PoolSplash (a glob lands): a ring, a splat, a crown of drops.
	do
		local p = part(root, "PoolSplash", Vector3.new(9, 0.2, 9), { AuthoredRadius = 4.5 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		gring(g, "Ring", TEX.ringThick, VENOM, 0.35, 1, 14)
		splat(g, 9, 1.0)
		drops(g, "Crown", 16, 22, 35, Enum.NormalId.Top)
		em(g, "Fume", { Texture = TEX.puff, Color = CS(VDEEP), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(3, 8), Drag = 2, Lifetime = R(0.8, 1.3), Size = grow(2, 7), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
		flashStar(att(p, "Flare", Vector3.new(0, 0.6, 0)), 8, 7)
	end

	-- PoolDisc (venomPools hazard, lasts 7 s then fades; authored r4.5): an
	-- acid disc, unmistakably hazardous: a bright rim and a shimmering inner
	-- ring over an ink base, bubbles popping, fumes and motes rising.
	do
		local p = part(root, "PoolDisc", Vector3.new(9, 0.2, 9), { AuthoredRadius = 4.5, AuthoredSeconds = 7 })
		local g = att(p, "Ground", Vector3.new(0, 0.18, 0))
		local life = R(7.2)
		local d = 9.4
		em(g, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = life, Size = NS({ KP(0, d * 0.4), KP(0.03, d * 1.2), KP(1, d * 1.2) }), Transparency = NS({ KP(0, 0.4), KP(0.04, 0.25), KP(0.85, 0.3), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Fill", with(FLAT, { Texture = TEX.dot, Color = CS({ CK(0, VENOM), CK(1, VDEEP) }), LightEmission = 0.9, Lifetime = life, Size = NS({ KP(0, d * 0.3), KP(0.03, d), KP(1, d) }), Transparency = NS({ KP(0, 0.5), KP(0.04, 0.3), KP(0.85, 0.4), KP(1, 1) }), ZOffset = 0.5 }))
		em(g, "Rim", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(0.1, VENOM), CK(1, VENOM) }), LightEmission = 1, Brightness = 2, Lifetime = life, Size = NS({ KP(0, d * 0.4), KP(0.03, d * 1.05), KP(1, d * 1.05) }), Transparency = NS({ KP(0, 0.3), KP(0.05, 0.05), KP(0.85, 0.15), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Shimmer", with(FLAT, { Texture = TEX.ringThin, Color = CS(VHOT), LightEmission = 1, Rate = 0.9, Lifetime = R(1.4), Size = grow(d * 0.3, d * 0.95), Transparency = NS({ KP(0, 0.6), KP(0.5, 0.4), KP(1, 1) }), ZOffset = 1.2 }), { EmitDuration = 6.6 })
		em(g, "Bubbles", { Texture = TEX.ringThin, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, Rate = 12, Speed = R(0.6, 2.2), Lifetime = R(0.5, 0.9), Size = grow(0.5, 1.5), Transparency = NS({ KP(0, 0.2), KP(0.8, 0.2), KP(1, 1) }) }, { EmitDuration = 6.6 })
		em(g, "Fume", { Texture = TEX.puff, Color = CS(VDEEP), Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Rate = 4, Speed = R(1.5, 3.5), Lifetime = R(1.6, 2.4), Size = grow(1.6, 5), Transparency = NS({ KP(0, 0.6), KP(0.3, 0.55), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 6.4 })
		em(g, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, Rate = 5, Speed = R(2, 5), Lifetime = R(1, 1.6), Size = grow(0.6, 0), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitDuration = 6.4 })
	end

	-- RainGather (venomRain 2.0, at the Mouth): a pale-jade glow column
	-- gathering over ink, jade motes drawn in, jade rays starting to stand
	-- up, two amber rings closing.
	do
		local p = part(root, "RainGather", Vector3.new(14, 14, 14), { AuthoredSeconds = 2.0 })
		gather(p, JADE, 2.0, 60, 24, 1.0, WHITE)
		swell(p, "Glow", JADE, 2.0, 16, 4)
		em(p, "Column", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3), Speed = R(20, 40), Rate = 8, Lifetime = R(0.7, 1.1), Size = grow(18, 3), Transparency = NS({ KP(0, 0.5), KP(1, 1) }) }, { EmitDuration = 1.4, EmitDelay = 0.6 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Lifetime = R(1.5), Size = grow(22, 2), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.2 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(WHITE), Lifetime = R(0.9), LightEmission = 1, Size = grow(14, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.3) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 1.0 })
	end

	-- RainRelease (venomRain release, at the Mouth, facing up by code): a
	-- stream skyward, rays, a flash.
	do
		local p = part(root, "RainRelease", Vector3.new(0.4, 0.4, 0.4))
		flashStar(p, 18, 16, JADE)
		em(p, "Stream", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(6, 6), Speed = R(80, 140), Rate = 40, Lifetime = R(0.6, 1.0), Size = grow(20, 4), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 0.8 })
		em(p, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Speed = R(30, 70), Rate = 30, Lifetime = R(1, 1.8), Size = grow(1.2, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 0.8 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Lifetime = R(0.5), Size = grow(3, 26), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
	end

	-- RainDrop (a venom drop falling to its circle; code drops it from high):
	-- a bright head, a streak, a trail. Kept light: nine of them in 3 s.
	do
		local p = part(root, "RainDrop", Vector3.new(1.4, 1.4, 1.4))
		em(p, "Glow", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, Brightness = 2, Rate = 30, Lifetime = R(0.1), Size = grow(3.6, 2.4), Transparency = NS({ KP(0, 0.2), KP(1, 0.8) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Core", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Rate = 30, Lifetime = R(0.1), Size = grow(1.8, 1.3), Transparency = NS({ KP(0, 0), KP(1, 0.5) }), LockedToPart = true, ZOffset = 2 })
		em(p, "Streak", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, Rate = 24, Speed = R(8, 14), SpreadAngle = Vector2.new(4, 4), Lifetime = R(0.25), Size = grow(7, 1), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
	end

	-- RainSplash (a drop lands, authored r4.5): ring, splat, a few drops, a
	-- fume puff. Light.
	do
		local p = part(root, "RainSplash", Vector3.new(9, 0.2, 9), { AuthoredRadius = 4.5 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		gring(g, "Ring", TEX.ringThick, VENOM, 0.3, 1, 11)
		splat(g, 7, 1.2)
		drops(g, "Crown", 8, 18, 30, Enum.NormalId.Top)
		em(g, "Fume", { Texture = TEX.puff, Color = CS(VDEEP), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(3, 7), Drag = 2, Lifetime = R(0.8, 1.2), Size = grow(2, 6), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 3 })
		flashStar(att(p, "Flare", Vector3.new(0, 0.6, 0)), 6, 5)
	end

	---------------------------------------------------------------- coil

	-- CoilForm (jiaoCoil contact, at CoilCenter, authored r13.3): the ring
	-- closes: flash, a jade ring and a spiky ring running out, dust ring and
	-- wall, chips, a star, a long ink pool under the ring.
	do
		local p = part(root, "CoilForm", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13.3 })
		local g = att(p, "Ground", Vector3.new(0, 0.15, 0))
		em(g, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.2), Size = grow(20, 30, 31), Transparency = NS({ KP(0, 0.3), KP(0.5, 0.45), KP(1, 1) }), ZOffset = 0.2 }))
		gring(g, "Ring", TEX.ringThick, JADE, 0.45, 8, 30, { Brightness = 2, ZOffset = 1.5 })
		gring(g, "RingSpiky", TEX.ringSpiky, VENOM, 0.6, 8, 32, { Rotation = R(0, 360), ZOffset = 1.2 })
		dustRing(g, 0.7, 8, 34)
		wall(g, "Wall", 20, 30, 9, DUST, 1.3)
		chips(g, "Chips", TEX.chips, DUST, 12, 34, 1.3, 60)
		g = att(p, "Flare", Vector3.new(0, 1, 0))
		flashStar(g, 20, 18, JADE)
		shake(p, "Custom,25~100,1.0,0.5,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- CoilPulse (a tightening pulse on the held ring, authored r13.3): a thin
	-- jade ring closing toward the centre.
	do
		local p = part(root, "CoilPulse", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13.3 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		gring(g, "Ring", TEX.ringThin, JADE, 0.55, 29, 20, { Transparency = NS({ KP(0, 0.5), KP(0.6, 0.2), KP(1, 1) }) })
		em(g, "Glow", with(FLAT, { Texture = TEX.ringThick, Color = CS(JADE), LightEmission = 1, Lifetime = R(0.55), Size = grow(29, 20), Transparency = NS({ KP(0, 0.8), KP(0.6, 0.55), KP(1, 1) }), ZOffset = 0.8 }))
	end

	-- CoilSqueeze (the hard contraction, authored r13.3): a ring closing hard
	-- to the centre with a flash, dust punched in then out, a shake.
	do
		local p = part(root, "CoilSqueeze", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13.3 })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		gring(g, "Closing", TEX.ringThick, VENOM, 0.3, 30, 4, { Brightness = 3, Transparency = NS({ KP(0, 0.1), KP(0.8, 0.1), KP(1, 1) }), ZOffset = 1.6 })
		gring(g, "ClosingThin", TEX.ringThin, WHITE, 0.4, 36, 6, { ZOffset = 1.8 })
		dustRing(g, 0.5, 26, 6)
		wall(g, "Dust", 18, 22, 7, DUST, 1.0)
		em(g, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(30, 60), Lifetime = R(0.25, 0.4), Size = grow(8, 1), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 20 })
		flashStar(att(p, "Flare", Vector3.new(0, 1.2, 0)), 24, 14, JADE)
		shake(p, "Custom,25~100,1.4,0.5,18,0.02,1;1;1,0.07;0.07;0.07")
	end

	-- CoilBreak (the ring shatters, authored r13.3): jade shards fly outward,
	-- a flash, a ring, rays, motes drifting up.
	do
		local p = part(root, "CoilBreak", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13.3 })
		local g = att(p, "Ground", Vector3.new(0, 0.6, 0))
		em(g, "Shards", { Texture = TEX.chips, Color = CS({ CK(0, JADE), CK(1, VDEEP) }), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(10, 34), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.8, 1.4), Size = grow(1.8, 1), RotSpeed = R(-400, 400), Rotation = R(0, 360) }, { EmitCount = 36 })
		gring(g, "Ring", TEX.ringThick, JADE, 0.5, 10, 36, { Brightness = 2 })
		dustRing(g, 0.7, 10, 34)
		rays(g, 22, 80, 10, JADE, Enum.NormalId.Top, 35)
		em(g, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, EmissionDirection = Enum.NormalId.Top, Speed = R(3, 9), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(1.2, 2.2), Size = grow(0.9, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 30 })
		flashStar(att(p, "Flare", Vector3.new(0, 1.2, 0)), 22, 16, JADE)
		shake(p, "Explosion,30~110,1.8,0.7,18,0.02,1;1;1,0.08;0.08;0.08")
	end

	-- CoilGate (one door post, standing at each edge of the gap): a jade
	-- light ray rising from the ground and rising motes. Code adds it at both
	-- gap edges and holds it for the whole hold.
	do
		local p = part(root, "CoilGate", Vector3.new(3, 1, 3))
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		em(g, "Base", with(FLAT, { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 2, Rate = 3, Lifetime = R(0.9), Size = grow(2, 7), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Ray", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(1, 1), Speed = R(18, 30), Rate = 7, Lifetime = R(0.7, 1.0), Size = grow(12, 6), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
		em(g, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Disc, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8), Speed = R(3, 9), Rate = 8, Lifetime = R(1.2, 2), Size = grow(0.8, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
	end

	---------------------------------------------------------------- hiss, phase

	-- RoarTell (dreadHiss 1.1, molt 1.6, ascension 2.0, at the Mouth): rings
	-- of sound leave the maw, a swelling glow, mist, motes drawn in then
	-- thrown out. Code tints it jade for the ascension.
	do
		local p = part(root, "RoarTell", Vector3.new(10, 10, 10), { AuthoredSeconds = 1.2 })
		em(p, "Waves", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Brightness = 2, Rate = 4, Lifetime = R(0.55), Size = grow(3, 20), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 }, { EmitDuration = 1.2, EmitDelay = 0.1 })
		em(p, "Arcs", { Texture = TEX.arc, Color = CS(VHOT), LightEmission = 1, Rate = 3, EmissionDirection = Enum.NormalId.Front, Speed = R(28), Drag = 3, Rotation = R(0), Lifetime = R(0.5), Size = grow(7, 16), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 0.8 }, { EmitDuration = 1.2, EmitDelay = 0.1 })
		swell(p, "Glow", VENOM, 1.2, 9)
		em(p, "Mist", { Texture = TEX.puff, Color = CS(VDEEP), Rate = 24, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(6, 14), Drag = 1.5, Lifetime = R(0.9, 1.4), Size = grow(2.4, 8), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 1.2 })
		em(p, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Rate = 22, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = R(12, 18), Lifetime = R(0.4, 0.6), Size = grow(0.7, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 1.2 })
	end

	-- HissBurst (dreadHiss contact, on the ground at the snake, authored
	-- r14): a pulsing, widening ring of green mist and a flat pressure wave.
	do
		local p = part(root, "HissBurst", Vector3.new(28, 0.2, 28), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.9, 0))
		for i = 0, 2 do
			local d = i * 0.22
			em(g, "MistRing" .. i, { Texture = TEX.puff, Color = CS(VENOM), LightEmission = 0.3, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4), Speed = R(22, 34), Drag = 1.8, Lifetime = R(0.8, 1.2), Size = grow(5, 12), Transparency = NS({ KP(0, 0.55), KP(0.5, 0.6), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 22, EmitDelay = d })
		end
		gring(g, "Pressure", TEX.ringThick, WHITE, 0.5, 4, 32, { Brightness = 1.5, ZOffset = 1.5 })
		gring(g, "PressureThin", TEX.ringThin, VENOM, 0.8, 6, 40, { ZOffset = 1.8, EmitDelay = 0.12 })
		dustRing(g, 0.8, 6, 34, VDEEP)
		em(g, "Base", with(FLAT, { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 0.5, Lifetime = R(1.2), Size = grow(6, 26, 28), Transparency = NS({ KP(0, 0.55), KP(0.5, 0.7), KP(1, 1) }), ZOffset = 0.3 }))
		shake(p, "Custom,25~100,1.4,0.6,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- ShedSkin (molt and ascension; mounted on several body parts): scale
	-- flakes shed and drifting off, motes rising, a thin mist.
	do
		local p = part(root, "ShedSkin", Vector3.new(3, 3, 3), { AuthoredSeconds = 1.6 })
		em(p, "Flakes", { Texture = TEX.chips, Color = CS({ CK(0, JADE), CK(1, VDEEP) }), LightEmission = 0.4, Shape = Enum.ParticleEmitterShape.Sphere, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(120, 120), Rate = 14, Speed = R(2, 7), Acceleration = Vector3.new(0, -6, 0), Drag = 1, Lifetime = R(1.0, 1.8), Size = grow(1.2, 0.8), RotSpeed = R(-200, 200), Rotation = R(0, 360), Transparency = NS({ KP(0, 0), KP(0.8, 0.1), KP(1, 1) }) }, { EmitDuration = 1.6 })
		em(p, "Motes", { Texture = TEX.dot, Color = CS(JADE), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, Rate = 8, Speed = R(1, 3), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(1.2, 2), Size = grow(0.5, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitDuration = 1.6 })
	end

	-- PhaseBurst (the `phase` cue, floor under the snake, authored r14): the
	-- fight escalates. A venom-jade sigil blooms and spins out under an ink
	-- disc, three shock rings, a pillar of light rays, motes spiralling up,
	-- a flash. The ascension boosts the counts in code.
	do
		local p = part(root, "PhaseBurst", Vector3.new(28, 0.2, 28), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "SigilDark", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.8), Size = grow(12, 46, 50), Transparency = NS({ KP(0, 0.3), KP(0.5, 0.45), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(0.5, VENOM), CK(1, JADE) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.8), Size = grow(12, 44, 50), RotSpeed = R(90), Transparency = NS({ KP(0, 0.1), KP(0.55, 0.25), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(WHITE), LightEmission = 1, Lifetime = R(1.5), Size = grow(8, 38, 42), RotSpeed = R(-70), Transparency = NS({ KP(0, 0.1), KP(0.55, 0.3), KP(1, 1) }), ZOffset = 0.8 }))
		gring(g, "Ring", TEX.ringThick, VENOM, 0.5, 2, 56, { Brightness = 2, ZOffset = 1.5 })
		gring(g, "Ring2", TEX.ringSpiky, JADE, 0.65, 4, 62, { Rotation = R(0, 360), ZOffset = 1.2, EmitDelay = 0.1 })
		gring(g, "Ring3", TEX.ringThin, WHITE, 0.95, 4, 76, { ZOffset = 1.8, EmitDelay = 0.22 })
		em(g, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8), Speed = R(90, 150), Lifetime = R(0.5, 0.8), Size = grow(26, 6), Transparency = NS({ KP(0, 0), KP(1, 1) }), Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume }, { EmitCount = 26 })
		em(g, "Pillar", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3), Speed = R(30, 50), Lifetime = R(0.5, 0.8), Size = grow(9, 3), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitCount = 12 })
		em(g, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, Speed = R(6, 16), Lifetime = R(1.2, 2.2), Size = grow(1.0, 0), Acceleration = Vector3.new(0, 6, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 30 })
		flashStar(att(p, "Flare", Vector3.new(0, 2, 0)), 34, 20, JADE)
		wall(g, "Dust", 14, 24, 11, DUST, 1.3)
		shake(p, "Explosion,30~140,3.0,0.9,18,0.02,1;1;1,0.08;0.08;0.08")
	end

	-- PhaseFlare (the `phase` cue on the chest; stagger at half strength):
	-- a green-jade burst out of the body, a flash, a ring, motes.
	do
		local p = part(root, "PhaseFlare", Vector3.new(8, 8, 8))
		em(p, "Flames", { Texture = TEX.flameBurst, Color = CS({ CK(0, WHITE), CK(0.5, VENOM), CK(1, JADE) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Speed = R(10, 22), Drag = 2, Lifetime = R(0.5, 0.9), Size = grow(5, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(10, 28), Transparency = pop, ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(3, 34), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.35), Size = grow(3, 22, 0), ZOffset = 3 })
		em(p, "Motes", { Texture = TEX.dot, Color = CS(JADE), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(8, 20), Drag = 1.5, Acceleration = Vector3.new(0, 5, 0), Lifetime = R(1, 1.8), Size = grow(0.6, 0) }, { EmitCount = 24 })
	end

	---------------------------------------------------------------- hits

	-- Hits (on the struck player, near side, facing the snake): short, a
	-- green poison splat plus the attack's own mark.
	local function hit(name, build)
		local p = part(root, name, Vector3.new(0.3, 0.3, 0.3))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(2.5, 6), Transparency = pop, ZOffset = 3 })
		em(p, "Splat", { Texture = TEX.ink, Color = CS(VENOM), LightEmission = 0.7, Lifetime = R(0.5), Size = grow(2.5, 7), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 })
		drops(p, "Drops", 12, 20, 80, Enum.NormalId.Front)
		em(p, "Ink", { Texture = TEX.ink, Color = CS(SLATE), Lifetime = R(0.3), Size = grow(3, 5), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		build(p)
	end
	hit("HitFang", function(p)
		em(p, "FangU", { Texture = TEX.arc, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Rotation = R(0), EmissionDirection = Enum.NormalId.Bottom, Speed = R(10), Lifetime = R(0.2), Size = grow(3.5, 5), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 2 })
		em(p, "FangD", { Texture = TEX.arc, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Rotation = R(180), EmissionDirection = Enum.NormalId.Top, Speed = R(10), Lifetime = R(0.2), Size = grow(3.5, 5), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 2 })
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS(VENOM), LightEmission = 1, Lifetime = R(0.25), Size = grow(1, 8), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 })
	end)
	hit("HitTail", function(p)
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, VHOT) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		rays(p, 10, 55, 5, VHOT, nil, 180)
		em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(180, 180), Speed = R(6, 14), Drag = 3, Lifetime = R(0.5, 0.9), Size = grow(2, 5), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
	end)
	hit("HitHeavy", function(p)
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 13), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "RingSpiky", { Texture = TEX.ringSpiky, Color = CS(VHOT), LightEmission = 1, Lifetime = R(0.4), Size = grow(1, 15), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 })
		rays(p, 12, 60, 5, VHOT, nil, 180)
		em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(180, 180), Speed = R(6, 14), Drag = 3, Lifetime = R(0.5, 0.9), Size = grow(2, 5), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
	end)
	hit("HitVenom", function(p)
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 9), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "Fume", { Texture = TEX.puff, Color = CS(VDEEP), SpreadAngle = Vector2.new(180, 180), Speed = R(2, 6), Drag = 2, Lifetime = R(0.6, 1.0), Size = grow(1.6, 4.4), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 3 })
	end)

	---------------------------------------------------------------- aura

	-- Aura parts (always on; the runtime clones each emitter into the body):
	-- kept light. `BaseRate` is the rate at full health; code scales it up as
	-- the Jiao is hurt. AuraGround is the slowly turning mandala array under
	-- the root.
	do
		local p = part(root, "AuraGround", Vector3.new(34, 0.2, 34))
		em(p, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Rate = 0.3, Lifetime = R(3.4), Size = NS(40), Transparency = NS({ KP(0, 1), KP(0.2, 0.6), KP(0.8, 0.6), KP(1, 1) }), LockedToPart = true, ZOffset = 0.1 }))
		em(p, "Array", with(FLAT, { Texture = TEX.mandala, Color = CS(VENOM), LightEmission = 0.8, Rate = 0.3, Lifetime = R(3.4), Size = NS(36), RotSpeed = R(12), Transparency = NS({ KP(0, 1), KP(0.2, 0.62), KP(0.8, 0.62), KP(1, 1) }), LockedToPart = true, ZOffset = 0.4 }))
		em(p, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS(VHOT), LightEmission = 1, Rate = 0.3, Lifetime = R(3.4), Size = NS(24), RotSpeed = R(-18), Transparency = NS({ KP(0, 1), KP(0.2, 0.7), KP(0.8, 0.7), KP(1, 1) }), LockedToPart = true, ZOffset = 0.6 }))
	end
	do
		local p = part(root, "AuraBody", Vector3.new(3, 3, 3))
		em(p, "Mist", { Texture = TEX.puff, Color = CS(VDEEP), LightEmission = 0.2, Rate = 3, Shape = Enum.ParticleEmitterShape.Sphere, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(1, 3), Acceleration = Vector3.new(0, 1, 0), Lifetime = R(1.6, 2.4), Size = grow(3, 9), Transparency = NS({ KP(0, 0.8), KP(0.3, 0.65), KP(1, 1) }), Rotation = R(0, 360) })
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, Rate = 3, Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 1.4, 0), Lifetime = R(2, 3.2), Size = grow(0.6, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.8, 0.4), KP(1, 1) }) })
		-- phase 3: pale spirit-jade
		em(p, "JadeWisp", { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Rate = 0, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(2, 5), Lifetime = R(0.9, 1.5), Size = grow(2.6, 0.8), Transparency = NS({ KP(0, 0.55), KP(0.3, 0.4), KP(1, 1) }), Rotation = R(-15, 15) })
		em(p, "JadeMotes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Rate = 0, Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 2, 0), Lifetime = R(2, 3), Size = grow(0.9, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.8, 0.4), KP(1, 1) }) })
	end
	do
		local p = part(root, "AuraBreath", Vector3.new(0.4, 0.4, 0.4))
		em(p, "Mist", { Texture = TEX.puff, Color = CS(VENOM), LightEmission = 0.2, Rate = 3, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(20, 20), Speed = R(2, 4), Drag = 1, Acceleration = Vector3.new(0, -0.8, 0), Lifetime = R(1.1, 1.7), Size = grow(1.2, 4.4), Transparency = NS({ KP(0, 0.75), KP(0.3, 0.6), KP(1, 1) }), Rotation = R(0, 360) })
	end

	-- Mound (idle while Burrowed, at Dive_FX): a few green glints on the
	-- earth and a dust leak. The mound itself is a code-built soil dome.
	do
		local p = part(root, "MoundFX", Vector3.new(8, 1, 8))
		em(p, "Leak", { Texture = TEX.puff, Color = CS(DUST), Rate = 2.4, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(1.5, 3.5), Lifetime = R(1.6, 2.6), Size = grow(2, 7), Transparency = NS({ KP(0, 0.6), KP(0.4, 0.6), KP(1, 1) }), Rotation = R(0, 360) })
		em(p, "Glints", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Rate = 0.9, Shape = Enum.ParticleEmitterShape.Sphere, Lifetime = R(0.6, 1.0), Size = grow(0.4, 3.2, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 2 })
		em(p, "Seep", with(FLAT, { Texture = TEX.crackGlow, Color = CS(VENOM), LightEmission = 1, Rate = 0.6, Lifetime = R(2.2), Size = NS(10), Transparency = NS({ KP(0, 1), KP(0.3, 0.55), KP(0.7, 0.6), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
	end

	---------------------------------------------------------------- death

	-- Death, in three pieces the runtime sequences with a rising ghost jiao:
	-- DeathBuild (collapsing gather), DeathBurst (the white-out and venom
	-- splash), DeathSpirit (the pillar of motes and petals on the floor).
	do
		local p = part(root, "DeathBuild", Vector3.new(24, 24, 24), { AuthoredSeconds = 0.9 })
		gather(p, JADE, 0.9, 70, 30, 1.2, WHITE)
		swell(p, "Glow", JADE, 0.9, 18, 4)
		em(p, "Cracks", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Rate = 14, Lifetime = R(0.12, 0.2), Size = grow(0.8, 7, 0), Rotation = R(0, 180), SpreadAngle = Vector2.new(180, 180), Speed = R(0, 0), ZOffset = 2 }, { EmitDuration = 0.9 })
	end
	do
		local p = part(root, "DeathBurst", Vector3.new(0.6, 0.6, 0.6))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 8, Lifetime = R(0.35), Size = grow(24, 80), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), ZOffset = 4 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.55), Size = grow(8, 64, 0), ZOffset = 4 })
		em(p, "Splat", { Texture = TEX.ink, Color = CS(VENOM), LightEmission = 0.8, Lifetime = R(0.9), Size = grow(14, 50), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.7), Size = grow(6, 80), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "RingSpiky", { Texture = TEX.ringSpiky, Color = CS(VENOM), LightEmission = 1, Lifetime = R(0.8), Size = grow(6, 90), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 }, { EmitCount = 1, EmitDelay = 0.1 })
		rays(p, 30, 150, 26, JADE, nil, 180)
		drops(p, "Venom", 40, 60, 180, nil)
		em(p, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(14, 50), Drag = 2, Acceleration = Vector3.new(0, 6, 0), Lifetime = R(1.4, 2.6), Size = grow(1.4, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 40 })
		em(p, "Smoke", { Texture = TEX.puff, Color = CS(VDEEP), SpreadAngle = Vector2.new(180, 180), Speed = R(10, 24), Drag = 3, Lifetime = R(1.6, 2.6), Size = grow(10, 30), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 10 })
		shake(p, "Explosion,30~150,3.8,1.2,20,0.02,1;1;1,0.1;0.1;0.1")
	end
	do
		local p = part(root, "DeathSpirit", Vector3.new(30, 0.2, 30), { AuthoredRadius = 15 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 2, Lifetime = R(3.4), Size = grow(16, 40, 48), RotSpeed = R(40), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Pillar", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4), Speed = R(40, 80), Rate = 20, Lifetime = R(0.9, 1.4), Size = grow(26, 6), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitDuration = 2.6 })
		em(g, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, Speed = R(6, 16), Rate = 18, Lifetime = R(2, 3.4), Size = grow(1.0, 0), Acceleration = Vector3.new(0, 4, 0), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.2), KP(1, 1) }) }, { EmitDuration = 3.2 })
		gring(g, "Ring", TEX.ringThin, WHITE, 1.2, 4, 80, { ZOffset = 1.4, EmitDelay = 0.2 })
		wall(g, "Smoke", 14, 14, 18, VDEEP, 2.4)
		em(g, "Petals", { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(1, 4), Acceleration = Vector3.new(0, 2.5, 0), Rate = 10, Lifetime = R(3, 5), Size = grow(1.0, 0.2), RotSpeed = R(-60, 60), Rotation = R(0, 360), Transparency = NS({ KP(0, 1), KP(0.2, 0.3), KP(0.8, 0.5), KP(1, 1) }) }, { EmitDuration = 4.0 })
		em(g, "Venom", { Texture = TEX.dot, Color = CS(VENOM), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(5, 20), Acceleration = Vector3.new(0, -30, 0), Rate = 8, Lifetime = R(0.6, 1.2), Size = grow(0.8, 0.3) }, { EmitDuration = 2.0 })
	end

	root.Parent = effects
	return root
end
print("buildJadeJiaoFX installed")
return true
