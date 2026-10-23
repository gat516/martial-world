--!nocheck
-- Builder for ReplicatedStorage.Effects.FlameRaven: the Flame Raven's attack,
-- hit and death effects (fire red, gold, soot black). Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/FlameRaven.luau")
--   require(m)  -- installs _G.buildFlameRavenFX(effectsFolder)
-- Runtime: src/client/EnemyFX/FlameRaven.luau. Record: docs/enemies/third-wave.md.
-- Invisible Part templates (-Z = facing / blow direction), ground ones centred
-- on the ground; soot-black base under every bright layer.
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

-- A Beam template child (attachments are assigned by code at play time).
local function beamE(parent, name, props)
	local b = Instance.new("Beam")
	b.Name = name
	b.Enabled = false
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 8
	for k, v in props do
		b[k] = v
	end
	b.Parent = parent
	return b
end

local FIRE = Color3.fromRGB(255, 112, 30)
local GOLD = Color3.fromRGB(255, 206, 84)
local RED = Color3.fromRGB(214, 44, 22)
local SOOT = Color3.fromRGB(26, 16, 14)
local ASH = Color3.fromRGB(86, 80, 78)
local C = { mid = FIRE, rim = GOLD, dark = SOOT }

function _G.buildFlameRavenFX(effects)
	local old = effects:FindFirstChild("FlameRaven")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "FlameRaven"

	eyeGlint(root, "EyeGlint", GOLD)

	-- TipFlare (windup, on each wing tip and the crest): a flame glow on soot,
	-- sparks lifting off it. Code sets the EmitDuration.
	do
		local p = anchor("TipFlare", Vector3.new(0.5, 0.5, 0.5), root)
		emitter(p, "Dark", {
			Texture = TEX.dot, Color = CS(SOOT), Lifetime = R(0.3, 0.4), Rate = 6,
			Size = NS({ KP(0, 1.4), KP(1, 2) }), Transparency = NS({ KP(0, 0.55), KP(1, 1) }),
			LockedToPart = true, ZOffset = 0.5,
		}, { EmitDuration = 0.8 })
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS({ CK(0, GOLD), CK(1, FIRE) }), LightEmission = 1, Lifetime = R(0.3, 0.4), Rate = 7,
			Size = NS({ KP(0, 0.8), KP(0.5, 1.8), KP(1, 1) }), Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			LockedToPart = true, ZOffset = 1,
		}, { EmitDuration = 0.8 })
		emitter(p, "Sparks", {
			Texture = TEX.dot, Color = CS({ CK(0, GOLD), CK(1, RED) }), LightEmission = 1, Lifetime = R(0.4, 0.7), Rate = 8,
			Speed = R(2, 4), SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0, 4, 0),
			Size = NS({ KP(0, 0.2), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.8 })
	end

	-- EmberTrail (talonDive, on each wing tip, EmitDuration = the dive): embers
	-- streaming back, a flame puff and soot smoke.
	do
		local p = anchor("EmberTrail", Vector3.new(0.6, 0.6, 0.6), root)
		emitter(p, "Smoke", {
			Texture = TEX.puff, Color = CS({ CK(0, SOOT), CK(1, ASH) }), Lifetime = R(0.5, 0.8), Rate = 12,
			Speed = R(0.5, 1.5), SpreadAngle = Vector2.new(20, 20), Rotation = R(0, 360),
			Size = NS({ KP(0, 0.8), KP(1, 2.6) }), Transparency = NS({ KP(0, 0.4), KP(0.5, 0.55), KP(1, 1) }),
		}, { EmitDuration = 0.6 })
		emitter(p, "Flame", {
			Texture = TEX.puff, Color = CS({ CK(0, GOLD), CK(0.4, FIRE), CK(1, RED) }), LightEmission = 1, Lifetime = R(0.25, 0.4), Rate = 18,
			Size = NS({ KP(0, 1.1), KP(1, 0.2) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
			Rotation = R(0, 360), ZOffset = 1,
		}, { EmitDuration = 0.6 })
		emitter(p, "Embers", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, GOLD), CK(1, RED) }), LightEmission = 1, Lifetime = R(0.5, 0.9), Rate = 14,
			Speed = R(1, 4), SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, 3, 0),
			Size = NS({ KP(0, 0.22), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		}, { EmitDuration = 0.6 })
	end

	-- FlameSlash (talonRake strike, at Talons_FX, -Z forward): a three-claw flame
	-- slash on soot, sparks, a glint.
	do
		local p = anchor("FlameSlash", Vector3.new(0.5, 0.5, 0.5), root)
		stack(p, "Claw", TEX.claw, C, { 5, 7 }, R(0.22), with(along, { Speed = R(16), Rotation = R(-10, 10) }), { EmitCount = 1 })
		sparkE(p, "Sparks", 8, FIRE, R(8, 16), R(0.3, 0.5), { Acceleration = Vector3.new(0, -10, 0) })
		starE(p, "Star", GOLD, 2.6, R(0.18))
	end

	-- EmberBurst (an ember circle landing, on the ground, authored r3.5;
	-- Impact.explode adds burst/shock): a scorch ring on soot, a flame column,
	-- sparks and a flash.
	do
		local p = anchor("EmberBurst", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 3.5)
		emitter(p, "Scorch", with(flat, {
			Texture = TEX.dot, Color = CS(SOOT), Lifetime = R(1.6),
			Size = NS({ KP(0, 2), KP(0.1, 7), KP(1, 7) }), Transparency = NS({ KP(0, 0.3), KP(0.6, 0.4), KP(1, 1) }), ZOffset = 0.2,
		}), { EmitCount = 1 })
		ringE(p, "RingDark", SOOT, { 1.5, 8 }, R(0.4), 0, { ZOffset = 0.5 })
		ringE(p, "Ring", FIRE, { 1.2, 7.5 }, R(0.35), 1, { ZOffset = 1 })
		emitter(p, "Flame", {
			Texture = TEX.puff, Color = CS({ CK(0, WHITE), CK(0.3, GOLD), CK(0.7, FIRE), CK(1, RED) }), LightEmission = 1,
			Lifetime = R(0.4, 0.6), Speed = R(6, 12), SpreadAngle = Vector2.new(12, 12), Rotation = R(0, 360),
			Size = NS({ KP(0, 1.8), KP(0.5, 2.6), KP(1, 0.4) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitCount = 5 })
		sparkE(p, "Sparks", 12, GOLD, R(8, 16), R(0.4, 0.7), { Acceleration = Vector3.new(0, -20, 0), EmissionDirection = Enum.NormalId.Top })
		emitter(p, "Flash", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, FIRE) }), LightEmission = 1, Brightness = 3,
			Lifetime = R(0.12), Size = NS({ KP(0, 2), KP(0.4, 6), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- GustBlast (windGust strike, at the Mouth, -Z forward): wind streaks flying
	-- out, a fan of dust and soot, sparks.
	do
		local p = anchor("GustBlast", Vector3.new(0.6, 0.6, 0.6), root)
		stack(p, "Wind", TEX.line, C, { 1.6, 5 }, R(0.3), with(along, { Speed = R(28, 40), SpreadAngle = Vector2.new(30, 30) }), { EmitCount = 6 })
		puffE(p, "Dust", 7, Color3.fromRGB(150, 140, 126), { 2, 6 }, R(0.5, 0.9), R(14, 24), { SpreadAngle = Vector2.new(32, 32), EmissionDirection = Enum.NormalId.Front })
		sparkE(p, "Sparks", 10, FIRE, R(14, 26), R(0.3, 0.55), { SpreadAngle = Vector2.new(30, 30), EmissionDirection = Enum.NormalId.Front })
	end

	-- WingPuff (hop, under the body): a downdraft puff.
	do
		local p = anchor("WingPuff", Vector3.new(3, 0.4, 3), root)
		puffE(p, "Dust", 5, Color3.fromRGB(150, 140, 126), { 1.5, 4 }, R(0.5, 0.8), R(4, 8), { SpreadAngle = Vector2.new(80, 80) })
		sparkE(p, "Embers", 5, FIRE, R(3, 7), R(0.4, 0.7), { EmissionDirection = Enum.NormalId.Top })
	end

	-- HitFlame (hit, on the torso; -Z faces the raven): sparks, flame, a pop.
	do
		local p = anchor("HitFlame", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, FIRE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.8), KP(0.4, 2.6), KP(1, 0) }), ZOffset = 3,
		})
		puffE(p, "Flame", 4, FIRE, { 1, 2.4 }, R(0.3, 0.45), R(4, 8), { LightEmission = 1, EmissionDirection = Enum.NormalId.Back })
		sparkE(p, "Sparks", 9, GOLD, R(8, 16), R(0.3, 0.55), { Acceleration = Vector3.new(0, -25, 0), EmissionDirection = Enum.NormalId.Back })
	end

	-- StaggerFlash (at the Core).
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, FIRE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.08),
			Size = NS({ KP(0, 1.5), KP(0.4, 4), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", GOLD, 3, R(0.12))
	end

	-- Death (body-sized, wing-wide): the feathers burn to ash: grey ash drifting
	-- down, embers rising, a core glint.
	do
		local p = anchor("Death", Vector3.new(14, 3, 7), root)
		emitter(p, "Ash", {
			Texture = TEX.puff, Color = CS({ CK(0, SOOT), CK(1, ASH) }), Lifetime = R(1, 1.6), Rate = 20,
			Speed = R(0.5, 2), Acceleration = Vector3.new(0, -1.5, 0), SpreadAngle = Vector2.new(60, 60), Rotation = R(0, 360), RotSpeed = R(-40, 40),
			Size = NS({ KP(0, 1), KP(1, 3) }), Transparency = NS({ KP(0, 0.35), KP(0.5, 0.5), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		emitter(p, "Embers", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, GOLD), CK(1, RED) }), LightEmission = 1, Lifetime = R(0.7, 1.3), Rate = 26,
			Speed = R(2, 5), Drag = 1, SpreadAngle = Vector2.new(25, 25), Size = NS({ KP(0, 0.26), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.1), KP(1, 0.7) }), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		local core = attach(p, "Core")
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 4,
			Lifetime = R(0.4), Size = NS({ KP(0, 0), KP(0.3, 2.6), KP(1, 0) }), RotSpeed = R(90), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
