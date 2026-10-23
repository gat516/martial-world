--!nocheck
-- Builder for ReplicatedStorage.Effects.ShadowManeWolf: the new Shadow Mane
-- Wolf's (body ShadowManeWolfB) attack, hit and death effects. Load through
-- the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/ShadowManeWolf.luau")
--   require(m)  -- installs _G.buildShadowManeWolfFX(effectsFolder)
-- Runtime: src/client/EnemyFX/ShadowManeWolf.luau. Record: docs/enemies/second-wave.md.
--
-- Ink-black smoke with hot violet (#8A5CFF) and a white-violet flare. Black
-- smoke is the dark base; violet is the bright layer on it (never the Spirit
-- Wolf's pale blue, never gold). A pack beast: 2 to 5 layers a beat, short.
-- Templates are invisible Parts (-Z = facing / blow direction); ground ones
-- sit centred on the ground.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local id = function(n)
	return "rbxassetid://" .. n
end
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(176, 170, 156)

-- library ids shared with the other enemy builders (SpiritWolf / StoneBoar)
local TEX = {
	glint = id(84223532517124), -- crisp 4-point star glint
	dot = id(9841273544), -- hard round glow
	mote = id(8238126392), -- small soft dot
	fang = id(7216852121), -- thin bright crescent arc
	claw = id(11636552631), -- three parallel tapered streaks
	ring = id(16878073342), -- thin bright ring
	dustRing = id(13052235894), -- ring of spiky dust
	puff = id(14050360239), -- soft cloud puff
	breath = id(15753663130), -- soft wisp
	line = id(7886908733), -- thin line streak
	streak = id(18244764764), -- soft tapered streak
	crack = id(7994630128), -- dark branching cracks
	chips = id(425665059), -- rock chips
	ink = id(16132530029), -- black ink splash
}

local function anchor(name, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Massless = true
	p.Transparency = 1
	p.Size = size
	p.CFrame = CFrame.new()
	p.Parent = parent
	return p
end

local function attach(parent, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	a.Parent = parent
	return a
end

local function emitter(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	for k, v in props do
		e[k] = v
	end
	for k, v in attrs or { EmitCount = 1 } do
		e:SetAttribute(k, v)
	end
	e.Parent = parent
	return e
end

local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
end

local fadeLate = NS({ KP(0, 0), KP(0.6, 0.1), KP(1, 1) })
local fadeOut = NS({ KP(0, 0.15), KP(1, 1) })
local flat = { -- lies on the ground, facing up
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
	Speed = R(0.01),
}
local along = { -- stretched along its travel (-Z of the template)
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	EmissionDirection = Enum.NormalId.Front,
}

-- A bright shape on a dark base: slate copy under, colour, white-hot core.
-- tex, sizes {a,b}, life, base props. Returns nothing; emitters are named
-- <name>Dark / <name> / <name>Core.
local function stack(parent, name, tex, colors, size, life, base, attrs)
	local b = with({ Texture = tex, Lifetime = life }, base or {})
	emitter(parent, name .. "Dark", with(b, {
		Color = CS(colors.dark),
		LightEmission = 0,
		Size = NS({ KP(0, size[1] * 1.15), KP(1, size[2] * 1.2) }),
		Transparency = NS({ KP(0, 0.3), KP(0.6, 0.4), KP(1, 1) }),
		ZOffset = 0.5,
	}), attrs)
	emitter(parent, name, with(b, {
		Color = CS({ CK(0, colors.mid), CK(1, colors.rim) }),
		LightEmission = 0.7,
		Size = NS({ KP(0, size[1]), KP(1, size[2]) }),
		Transparency = fadeLate,
		ZOffset = 1,
	}), attrs)
	emitter(parent, name .. "Core", with(b, {
		Color = CS({ CK(0, WHITE), CK(1, colors.mid) }),
		LightEmission = 1,
		Brightness = 2,
		Size = NS({ KP(0, size[1] * 0.55), KP(1, size[2] * 0.5) }),
		Transparency = fadeLate,
		ZOffset = 1.5,
	}), attrs)
end

-- The windup eye/brow star: a pop, then the held glow (code sets Hold's EmitDuration).
local function eyeGlint(root, name, color)
	local p = anchor(name, Vector3.new(0.2, 0.2, 0.2), root)
	emitter(p, "Glint", {
		Texture = TEX.glint,
		Color = CS({ CK(0, WHITE), CK(0.5, color), CK(1, color) }),
		LightEmission = 1, Brightness = 4,
		Lifetime = R(0.16),
		Size = NS({ KP(0, 0.3), KP(0.3, 1.6), KP(1, 0) }),
		Rotation = R(-10, 10), ZOffset = 2,
	})
	emitter(p, "Hold", {
		Texture = TEX.dot, Color = CS(color), LightEmission = 1,
		Lifetime = R(0.12, 0.18), Rate = 18,
		Size = NS({ KP(0, 0.34), KP(1, 0.22) }),
		Transparency = NS({ KP(0, 0.35), KP(1, 0.8) }),
		LockedToPart = true, ZOffset = 1.5,
	}, { EmitDuration = 0.45 })
	return p
end

local function chipsE(parent, name, count, speed, size, color)
	return emitter(parent, name, {
		Texture = TEX.chips, Color = CS(color or Color3.fromRGB(120, 108, 92)),
		Lifetime = R(0.5, 0.9), Speed = R(speed[1], speed[2]),
		SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, -40, 0),
		Rotation = R(0, 360), RotSpeed = R(-300, 300),
		Size = NS({ KP(0, size), KP(1, size * 0.7) }),
		Transparency = NS({ KP(0, 0), KP(0.7, 0), KP(1, 1) }),
		EmissionDirection = Enum.NormalId.Top,
	}, { EmitCount = count })
end

local function puffE(parent, name, count, color, size, life, speed, extra)
	return emitter(parent, name, with({
		Texture = TEX.puff, Color = CS(color), Lifetime = life,
		Speed = speed, SpreadAngle = Vector2.new(60, 60), Drag = 3,
		Rotation = R(0, 360), RotSpeed = R(-40, 40),
		Size = NS({ KP(0, size[1]), KP(1, size[2]) }),
		Transparency = NS({ KP(0, 0.3), KP(0.5, 0.55), KP(1, 1) }),
		EmissionDirection = Enum.NormalId.Top,
	}, extra or {}), { EmitCount = count })
end

local function ringE(parent, name, color, size, life, light, extra)
	return emitter(parent, name, with({
		Texture = TEX.ring, Color = CS(color), LightEmission = light or 1,
		Lifetime = life, Size = NS({ KP(0, size[1]), KP(1, size[2]) }),
		Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
	}, with(flat, extra or {})))
end

local function sparkE(parent, name, count, color, speed, life, extra)
	return emitter(parent, name, with({
		Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, color) }),
		LightEmission = 1, Lifetime = life, Speed = speed,
		SpreadAngle = Vector2.new(70, 70), Drag = 4,
		Size = NS({ KP(0, 0.28), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		EmissionDirection = Enum.NormalId.Front,
	}, extra or {}), { EmitCount = count })
end

local function starE(parent, name, color, size, life, delay)
	return emitter(parent, name, {
		Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, color) }),
		LightEmission = 1, Brightness = 4, Lifetime = life,
		Size = NS({ KP(0, 0), KP(0.3, size), KP(1, 0) }),
		Rotation = R(0, 45), ZOffset = 3,
	}, { EmitCount = 1, EmitDelay = delay or 0 })
end

local VIOLET = Color3.fromRGB(138, 92, 255)
local FLARE = Color3.fromRGB(214, 196, 255)
local INK = Color3.fromRGB(16, 11, 24)
local SMOKE = Color3.fromRGB(34, 26, 48)
local C = { mid = VIOLET, rim = FLARE, dark = INK }

local function smokeE(parent, name, rate, size, life, speed, extra, attrs)
	return emitter(parent, name, with({
		Texture = TEX.puff, Color = CS({ CK(0, SMOKE), CK(1, INK) }),
		Lifetime = life, Rate = rate, Speed = speed, Drag = 2,
		SpreadAngle = Vector2.new(30, 30),
		Rotation = R(0, 360), RotSpeed = R(-40, 40),
		Size = NS({ KP(0, size[1]), KP(1, size[2]) }),
		Transparency = NS({ KP(0, 0.25), KP(0.5, 0.45), KP(1, 1) }),
		EmissionDirection = Enum.NormalId.Top,
	}, extra or {}), attrs)
end

function _G.buildShadowManeWolfFX(effects)
	local old = effects:FindFirstChild("ShadowManeWolf")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ShadowManeWolf"

	-- EyeGlint (each eye, every windup): a violet star, held glow.
	eyeGlint(root, "EyeGlint", VIOLET)

	-- Gather (shadowStep windup, at the Core): ink wisps and violet motes drawn
	-- into the chest, a glow building.
	do
		local p = anchor("Gather", Vector3.new(0.5, 0.5, 0.5), root)
		smokeE(p, "Wisps", 16, { 2.4, 0.8 }, R(0.4, 0.55), R(-7, -5), { Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(0, 0), Texture = TEX.breath, Transparency = NS({ KP(0, 1), KP(0.4, 0.3), KP(1, 0.8) }) }, { EmitDuration = 0.65 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }),
			LightEmission = 1, Lifetime = R(0.3, 0.45), Rate = 22, Speed = R(-9, -6),
			Shape = Enum.ParticleEmitterShape.Sphere,
			Size = NS({ KP(0, 0.3), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.4), KP(0.6, 0), KP(1, 1) }),
		}, { EmitDuration = 0.65 })
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }),
			LightEmission = 1, Lifetime = R(0.7), Size = NS({ KP(0, 0.4), KP(0.8, 3), KP(1, 3.4) }),
			Transparency = NS({ KP(0, 0.7), KP(0.8, 0.35), KP(1, 1) }), LockedToPart = true, ZOffset = 1,
		}, { EmitCount = 1 })
	end

	-- StepTrail (shadowStep dash, rides the Chest): a smoke-streak trail. Rate
	-- emitters; code sets EmitDuration to the dash. PawSmoke is the same, thinner.
	do
		local p = anchor("StepTrail", Vector3.new(1.2, 1.2, 1.2), root)
		smokeE(p, "Smoke", 34, { 2.4, 5 }, R(0.5, 0.8), R(0.5, 2), { SpreadAngle = Vector2.new(25, 25) }, { EmitDuration = 0.45 })
		emitter(p, "Streak", {
			Texture = TEX.streak, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }),
			LightEmission = 1, Lifetime = R(0.25, 0.35), Rate = 24,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Speed = R(0.5), SpreadAngle = Vector2.new(0, 0),
			Size = NS({ KP(0, 1.6), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0.15), KP(1, 1) }), ZOffset = 1,
		}, { EmitDuration = 0.45 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS(VIOLET), LightEmission = 1,
			Lifetime = R(0.4, 0.7), Rate = 14, Speed = R(1, 3), SpreadAngle = Vector2.new(60, 60),
			Size = NS({ KP(0, 0.24), KP(1, 0) }), Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
		}, { EmitDuration = 0.45 })
		local q = anchor("PawSmoke", Vector3.new(0.5, 0.5, 0.5), root)
		smokeE(q, "Smoke", 14, { 1, 2.4 }, R(0.4, 0.6), R(0.5, 1.5), nil, { EmitDuration = 0.45 })
	end

	-- Takeoff (shadowStep take-off, centred between the hind paws on the ground):
	-- ink dust thrown out and a flat violet ring.
	do
		local p = anchor("Takeoff", Vector3.new(2, 0.3, 2), root)
		smokeE(p, "Ink", 0, { 1.4, 4.4 }, R(0.5, 0.9), R(4, 8), { SpreadAngle = Vector2.new(70, 70) }, { EmitCount = 6 })
		ringE(p, "RingDark", INK, { 1.5, 8 }, R(0.4), 0, { ZOffset = 0.5 })
		ringE(p, "Ring", VIOLET, { 1.2, 7 }, R(0.35), 1, { ZOffset = 1 })
		chipsE(p, "Grit", 6, { 6, 12 }, 0.3, Color3.fromRGB(70, 60, 80))
	end

	-- Arrive (the dash ends, on the ground ahead of the Core): an ink puff and
	-- a violet pop; the skid dust is Impact.skid.
	do
		local p = anchor("Arrive", Vector3.new(2, 0.3, 2), root)
		smokeE(p, "Puff", 0, { 2, 5.5 }, R(0.6, 1), R(3, 7), { SpreadAngle = Vector2.new(70, 70) }, { EmitCount = 6 })
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, VIOLET) }),
			LightEmission = 1, Brightness = 2, Lifetime = R(0.15),
			Size = NS({ KP(0, 1), KP(0.4, 3.4), KP(1, 0) }), ZOffset = 3,
		})
		sparkE(p, "Motes", 6, VIOLET, R(3, 7), R(0.4, 0.7), { EmissionDirection = Enum.NormalId.Top })
	end

	-- ClawGlint (shadowRake / maneRend windup, at the raised front paw): a
	-- violet star on ink.
	do
		local p = anchor("ClawGlint", Vector3.new(0.3, 0.3, 0.3), root)
		emitter(p, "Dark", {
			Texture = TEX.dot, Color = CS(INK), Lifetime = R(0.45),
			Size = NS({ KP(0, 0.8), KP(0.3, 2.2), KP(1, 1.4) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }), ZOffset = 0.5,
		})
		starE(p, "Star", VIOLET, 2.4, R(0.4))
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS(VIOLET), LightEmission = 1, Lifetime = R(0.45),
			Size = NS({ KP(0, 0.5), KP(0.3, 1.4), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 1,
		})
	end

	-- ManeFlare (maneRend windup flicker / maneLash windup, at ManeTop_FX; code
	-- scales the lash): violet tendrils reaching up, ink wisps, motes.
	do
		local p = anchor("ManeFlare", Vector3.new(1, 1, 1), root)
		stack(p, "Tendril", TEX.streak, C, { 1.6, 4 }, R(0.45, 0.7), {
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Top, Speed = R(3, 6), SpreadAngle = Vector2.new(40, 40),
			Rate = 12, Acceleration = Vector3.new(0, 4, 0),
		}, { EmitDuration = 0.7 })
		smokeE(p, "Wisps", 10, { 1.2, 3 }, R(0.5, 0.8), R(1.5, 3), nil, { EmitDuration = 0.7 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }),
			LightEmission = 1, Lifetime = R(0.5, 0.9), Rate = 16, Speed = R(2, 5),
			SpreadAngle = Vector2.new(50, 50),
			Size = NS({ KP(0, 0.26), KP(1, 0) }), Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.7 })
	end

	-- ClawSweep (maneRend strike, x2, at the paw's reach, -Z forward; the second
	-- is rolled by code to mirror): a wide claw arc, ink under, a flash.
	do
		local p = anchor("ClawSweep", Vector3.new(0.5, 0.5, 0.5), root)
		stack(p, "Claw", TEX.claw, C, { 5, 7 }, R(0.2), with(along, { Speed = R(18), Rotation = R(-8, 8) }), { EmitCount = 1 })
		stack(p, "Arc", TEX.fang, C, { 4.5, 6.5 }, R(0.16), with(along, { Speed = R(14) }), { EmitCount = 1 })
		sparkE(p, "Motes", 6, VIOLET, R(8, 14), R(0.25, 0.4))
	end

	-- ClawRake (shadowRake / maneRend hit, on the torso; -Z faces the wolf):
	-- three ink-violet streaks across, a glint, motes.
	do
		local p = anchor("ClawRake", Vector3.new(0.4, 0.4, 0.4), root)
		stack(p, "Claw", TEX.claw, C, { 3.4, 4.4 }, R(0.22), { Rotation = R(-25, 25), ZOffset = 1 }, { EmitCount = 1 })
		starE(p, "Star", FLARE, 2, R(0.16))
		sparkE(p, "Motes", 8, VIOLET, R(8, 15), R(0.3, 0.5), { EmissionDirection = Enum.NormalId.Back })
	end

	-- LashRing (maneLash strike, ground at the wolf, authored r8; Impact.ground
	-- adds shock/dust in violet-ink): a mane-whip ring and ink smoke.
	do
		local p = anchor("LashRing", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 8)
		ringE(p, "RingDark", INK, { 3, 17 }, R(0.6), 0, { ZOffset = 0.5 })
		ringE(p, "Ring", VIOLET, { 2.5, 16 }, R(0.5), 1, { ZOffset = 1 })
		ringE(p, "RingCore", FLARE, { 2, 15 }, R(0.3), 1, { ZOffset = 1.5 })
		smokeE(p, "Smoke", 0, { 2.5, 6 }, R(0.7, 1.1), R(8, 14), { SpreadAngle = Vector2.new(80, 80) }, { EmitCount = 8 })
		sparkE(p, "Motes", 10, VIOLET, R(6, 14), R(0.4, 0.7), { EmissionDirection = Enum.NormalId.Top })
	end

	-- LashHit (maneLash hit, on the torso): an ink splash with violet sparks.
	do
		local p = anchor("LashHit", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Ink", {
			Texture = TEX.ink, Color = CS(INK), Lifetime = R(0.4),
			Size = NS({ KP(0, 1.4), KP(0.3, 3.4), KP(1, 4) }),
			Transparency = NS({ KP(0, 0.1), KP(0.6, 0.3), KP(1, 1) }),
			Rotation = R(0, 360), ZOffset = 1,
		})
		sparkE(p, "Sparks", 9, VIOLET, R(8, 15), R(0.3, 0.5), { EmissionDirection = Enum.NormalId.Back })
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, VIOLET) }),
			LightEmission = 1, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.8), KP(0.4, 2.4), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- HopSmoke (hop, between the hind paws): a smoke puff and a shadow smear
	-- (a dark streak along the retreat; code aims -Z along the motion).
	do
		local p = anchor("HopSmoke", Vector3.new(2, 0.4, 2), root)
		smokeE(p, "Puff", 0, { 1.6, 4.6 }, R(0.5, 0.9), R(3, 6), { SpreadAngle = Vector2.new(70, 70) }, { EmitCount = 5 })
		emitter(p, "Smear", with(along, {
			Texture = TEX.streak, Color = CS({ CK(0, SMOKE), CK(1, INK) }), Lifetime = R(0.35),
			Speed = R(8), Size = NS({ KP(0, 3), KP(1, 5) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
		}), { EmitCount = 2 })
		emitter(p, "Violet", with(along, {
			Texture = TEX.streak, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }), LightEmission = 1,
			Lifetime = R(0.25), Speed = R(8), Size = NS({ KP(0, 1.6), KP(1, 3) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 1,
		}), { EmitCount = 1 })
	end

	-- StaggerFlash (at the Core): a violet pop and star.
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, VIOLET) }),
			LightEmission = 1, Brightness = 3, Lifetime = R(0.1),
			Size = NS({ KP(0, 1), KP(0.4, 3), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", FLARE, 2.2, R(0.12))
	end

	-- Death (at the Core, body-sized): the shadow dissolves upward as ink smoke
	-- and violet motes, ends on a flare-white core glint.
	do
		local p = anchor("Death", Vector3.new(5, 3, 14), root)
		smokeE(p, "Smoke", 24, { 1.8, 5 }, R(0.9, 1.4), R(2.5, 5), { Shape = Enum.ParticleEmitterShape.Box, SpreadAngle = Vector2.new(20, 20) }, { EmitDuration = 0.9 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }),
			LightEmission = 1, Lifetime = R(0.7, 1.2), Rate = 24, Speed = R(3, 6), Drag = 1,
			SpreadAngle = Vector2.new(20, 20), Shape = Enum.ParticleEmitterShape.Box,
			Size = NS({ KP(0, 0.24), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 0.7) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		local core = attach(p, "Core")
		emitter(core, "Glow", {
			Texture = TEX.dot, Color = CS({ CK(0, FLARE), CK(1, VIOLET) }), LightEmission = 1,
			Lifetime = R(0.5), Size = NS({ KP(0, 0.4), KP(0.3, 2), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }), ZOffset = 2,
		}, { EmitCount = 1, EmitDelay = 0.1 })
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, FLARE) }),
			LightEmission = 1, Brightness = 4, Lifetime = R(0.4),
			Size = NS({ KP(0, 0), KP(0.3, 2.2), KP(1, 0) }), RotSpeed = R(90), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
