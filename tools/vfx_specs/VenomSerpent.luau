--!nocheck
-- Builder for ReplicatedStorage.Effects.VenomSerpent: the new Venom Serpent's
-- (body VenomSerpentB) attack, hit and death effects. Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/VenomSerpent.luau")
--   require(m)  -- installs _G.buildVenomSerpentFX(effectsFolder)
-- Runtime: src/client/EnemyFX/VenomSerpent.luau. Record: docs/systems/enemies.md.
--
-- Venom: sickly jade-green and yellow-green with a white-hot centre, a dark
-- green-slate copy under each bright shape so it reads on grass at noon. A
-- pack beast, so every beat is 2 to 5 layers and short. Templates are
-- invisible Parts (-Z = facing / blow direction); ground ones sit centred on
-- the ground. Emit attributes are on the emitters (plugin R/T plays them).
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

local MID = Color3.fromRGB(140, 225, 80)
local RIM = Color3.fromRGB(205, 240, 90)
local DARK = Color3.fromRGB(26, 42, 30)
local C = { mid = MID, rim = RIM, dark = DARK }
local MIST = Color3.fromRGB(110, 170, 80)

function _G.buildVenomSerpentFX(effects)
	local old = effects:FindFirstChild("VenomSerpent")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "VenomSerpent"

	-- EyeGlint (each eye, hoodStrike/venomSpit windups): green-yellow star, held glow.
	eyeGlint(root, "EyeGlint", RIM)

	-- SacSwell (on each venom sac, spit windup): a glow that builds, a haze, drips.
	do
		local p = anchor("SacSwell", Vector3.new(0.6, 0.6, 0.6), root)
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, RIM), CK(1, MID) }),
			LightEmission = 1, Lifetime = R(0.3, 0.45), Rate = 10,
			Size = NS({ KP(0, 0.5), KP(0.5, 1.5), KP(1, 0.8) }),
			Transparency = NS({ KP(0, 0.5), KP(0.5, 0.35), KP(1, 1) }),
			LockedToPart = true, ZOffset = 1,
		}, { EmitDuration = 1.0 })
		emitter(p, "Drip", {
			Texture = TEX.mote, Color = CS({ CK(0, RIM), CK(1, MID) }),
			LightEmission = 0.8, Lifetime = R(0.4, 0.6), Rate = 6,
			Speed = R(0.5, 1.5), Acceleration = Vector3.new(0, -26, 0),
			SpreadAngle = Vector2.new(25, 25),
			Size = NS({ KP(0, 0.22), KP(1, 0.1) }),
			Transparency = NS({ KP(0, 0.1), KP(1, 0.8) }),
			EmissionDirection = Enum.NormalId.Bottom,
		}, { EmitDuration = 1.0 })
	end

	-- MouthDrip (spit windup, at the Mouth): venom strings off the fangs, mist gathers.
	do
		local p = anchor("MouthDrip", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Drip", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, RIM), CK(1, MID) }),
			LightEmission = 1, Lifetime = R(0.35, 0.55), Rate = 14,
			Speed = R(0.5, 1.5), Acceleration = Vector3.new(0, -30, 0),
			SpreadAngle = Vector2.new(20, 20),
			Size = NS({ KP(0, 0.26), KP(1, 0.1) }),
			Transparency = NS({ KP(0, 0), KP(1, 0.8) }),
			EmissionDirection = Enum.NormalId.Bottom,
		}, { EmitDuration = 1.0 })
		emitter(p, "Mist", {
			Texture = TEX.breath, Color = CS({ CK(0, MIST), CK(1, MID) }),
			LightEmission = 0.4, Lifetime = R(0.7, 1.0), Rate = 8,
			Speed = R(0.8, 1.6), SpreadAngle = Vector2.new(35, 35),
			Rotation = R(0, 360), RotSpeed = R(-30, 30),
			Size = NS({ KP(0, 1), KP(0.5, 2.2), KP(1, 2.8) }),
			Transparency = NS({ KP(0, 1), KP(0.3, 0.6), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Front,
		}, { EmitDuration = 1.0 })
	end

	-- HoodGlint (on each hood spot, hoodStrike windup): a star and a dot on slate.
	do
		local p = anchor("HoodGlint", Vector3.new(0.3, 0.3, 0.3), root)
		emitter(p, "Dark", {
			Texture = TEX.dot, Color = CS(DARK), Lifetime = R(0.5),
			Size = NS({ KP(0, 0.8), KP(0.3, 2.4), KP(1, 1.6) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }), ZOffset = 0.5,
		})
		emitter(p, "Star", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, RIM) }),
			LightEmission = 1, Brightness = 4, Lifetime = R(0.4),
			Size = NS({ KP(0, 0.2), KP(0.3, 2.2), KP(1, 0) }),
			Rotation = R(-15, 15), ZOffset = 2,
		})
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS(MID), LightEmission = 1, Lifetime = R(0.5),
			Size = NS({ KP(0, 0.5), KP(0.3, 1.4), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 1,
		})
	end

	-- SpitSplash (venomSpit landing, on shape.center, authored r5.5): a splash
	-- thrown up, droplets, a flat ring on slate. Impact.explode adds burst/shock.
	do
		local p = anchor("SpitSplash", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 5.5)
		puffE(p, "Splash", 8, MID, { 1.5, 4.5 }, R(0.5, 0.8), R(7, 13), { LightEmission = 0.5, Acceleration = Vector3.new(0, -14, 0) })
		emitter(p, "Drops", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, RIM), CK(1, MID) }),
			LightEmission = 1, Lifetime = R(0.5, 0.9), Speed = R(10, 20),
			SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -60, 0),
			Size = NS({ KP(0, 0.4), KP(1, 0.15) }),
			Transparency = NS({ KP(0, 0), KP(0.8, 0.2), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitCount = 14 })
		ringE(p, "RingDark", DARK, { 2, 11 }, R(0.5), 0, { ZOffset = 0.5 }):SetAttribute("EmitCount", 1)
		ringE(p, "Ring", RIM, { 1.6, 10 }, R(0.45), 1, { ZOffset = 1 }):SetAttribute("EmitCount", 1)
		emitter(p, "Pool", with(flat, {
			Texture = TEX.dot, Color = CS({ CK(0, MID), CK(1, DARK) }),
			LightEmission = 0.3, Lifetime = R(1.4),
			Size = NS({ KP(0, 3), KP(0.2, 9), KP(1, 8) }),
			Transparency = NS({ KP(0, 0.45), KP(0.7, 0.55), KP(1, 1) }),
		}), { EmitCount = 1 })
		starE(p, "Glint", RIM, 3, R(0.3))
	end

	-- Streak (hoodStrike strike/dash, at the Mouth, -Z = forward): a short venom streak.
	do
		local p = anchor("Streak", Vector3.new(0.4, 0.4, 0.4), root)
		stack(p, "S", TEX.streak, C, { 2.4, 4.5 }, R(0.2), with(along, { Speed = R(30) }), { EmitCount = 2 })
		sparkE(p, "Drops", 6, MID, R(8, 16), R(0.25, 0.4), { Acceleration = Vector3.new(0, -20, 0) })
	end

	-- HitSplash (hoodStrike / venomSpit hit, on the torso; -Z faces the snake):
	-- a green splash, droplets, a poison-bubble burst and a pop.
	do
		local p = anchor("HitSplash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, RIM) }),
			LightEmission = 1, Brightness = 3, Lifetime = R(0.1),
			Size = NS({ KP(0, 1), KP(0.4, 2.8), KP(1, 0) }), ZOffset = 3,
		})
		puffE(p, "Splash", 5, MID, { 1, 2.6 }, R(0.35, 0.55), R(5, 9), { LightEmission = 0.6, EmissionDirection = Enum.NormalId.Back })
		sparkE(p, "Drops", 10, MID, R(8, 16), R(0.35, 0.6), { Acceleration = Vector3.new(0, -35, 0), EmissionDirection = Enum.NormalId.Back })
		emitter(p, "Bubbles", {
			Texture = TEX.ring, Color = CS({ CK(0, RIM), CK(1, MID) }),
			LightEmission = 0.8, Lifetime = R(0.5, 0.9), Speed = R(2, 5),
			SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 7, 0),
			Size = NS({ KP(0, 0.15), KP(0.7, 0.6), KP(1, 0.7) }),
			Transparency = NS({ KP(0, 0.1), KP(0.8, 0.3), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitCount = 8 })
	end

	-- HopDust (hop backslide, at the body's belly): a dust puff and a venom-green smear.
	do
		local p = anchor("HopDust", Vector3.new(2, 0.4, 2), root)
		puffE(p, "Dust", 5, DUST, { 1.2, 3.4 }, R(0.5, 0.8), R(3, 6), { EmissionDirection = Enum.NormalId.Top })
		stack(p, "Smear", TEX.streak, C, { 3, 5 }, R(0.3), with(along, { Speed = R(10) }), { EmitCount = 2 })
	end

	-- TailGlint (tailSnap windup/strike, at TailTip_FX): a star and a ring.
	do
		local p = anchor("TailGlint", Vector3.new(0.3, 0.3, 0.3), root)
		starE(p, "Star", RIM, 2.6, R(0.35))
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS(MID), LightEmission = 1, Lifetime = R(0.25),
			Size = NS({ KP(0, 0.6), KP(0.3, 1.6), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		})
		sparkE(p, "Sparks", 5, MID, R(5, 9), R(0.25, 0.4))
	end

	-- StaggerFlash (at the Core): a white-green pop and star.
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, RIM) }),
			LightEmission = 1, Brightness = 3, Lifetime = R(0.08),
			Size = NS({ KP(0, 1), KP(0.4, 3), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", RIM, 2.2, R(0.12))
	end

	-- Death (at the Core, body-sized): venom mist rising off the body, motes,
	-- a yellow-white core glint.
	do
		local p = anchor("Death", Vector3.new(2, 1.5, 6), root)
		emitter(p, "Mist", {
			Texture = TEX.puff, Color = CS({ CK(0, MIST), CK(1, DARK) }),
			LightEmission = 0.2, Lifetime = R(0.9, 1.4), Rate = 14,
			Speed = R(1.5, 3), SpreadAngle = Vector2.new(25, 25), Drag = 1.5,
			Rotation = R(0, 360), RotSpeed = R(-30, 30),
			Size = NS({ KP(0, 1.5), KP(1, 4.5) }),
			Transparency = NS({ KP(0, 0.4), KP(0.5, 0.6), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, RIM) }),
			LightEmission = 1, Lifetime = R(0.6, 1), Rate = 16,
			Speed = R(3, 5), Drag = 1, SpreadAngle = Vector2.new(20, 20),
			Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.1), KP(1, 0.7) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.8 })
		local core = attach(p, "Core")
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, RIM) }),
			LightEmission = 1, Brightness = 4, Lifetime = R(0.4),
			Size = NS({ KP(0, 0), KP(0.3, 2), KP(1, 0) }), RotSpeed = R(90), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
