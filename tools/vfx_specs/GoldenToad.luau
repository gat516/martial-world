--!nocheck
-- Builder for ReplicatedStorage.Effects.GoldenToad: the Golden Toad's attack,
-- hit and death effects (water-venom: gold and bog teal). Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/GoldenToad.luau")
--   require(m)  -- installs _G.buildGoldenToadFX(effectsFolder)
-- Runtime: src/client/EnemyFX/GoldenToad.luau. Record: docs/systems/enemies.md.
-- Invisible Part templates (-Z = facing / blow direction), ground ones centred
-- on the ground; a dark base under every bright layer; Emit attributes on emitters.
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

local GOLD = Color3.fromRGB(255, 214, 90)
local PALE = Color3.fromRGB(255, 244, 190)
local TEAL = Color3.fromRGB(70, 196, 172)
local DARK = Color3.fromRGB(20, 38, 34)
local MUD = Color3.fromRGB(104, 82, 52)
local TONGUE = Color3.fromRGB(226, 112, 112)
local C = { mid = TEAL, rim = GOLD, dark = DARK }

function _G.buildGoldenToadFX(effects)
	local old = effects:FindFirstChild("GoldenToad")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "GoldenToad"

	eyeGlint(root, "EyeGlint", TEAL)

	-- SacGlow (windup, on the sac): a gold glow that swells, motes rising off it.
	do
		local p = anchor("SacGlow", Vector3.new(1.5, 1.5, 1.5), root)
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS({ CK(0, PALE), CK(0.4, GOLD), CK(1, TEAL) }),
			LightEmission = 1, Lifetime = R(0.4, 0.55), Rate = 8,
			Size = NS({ KP(0, 1.2), KP(0.5, 3), KP(1, 2) }),
			Transparency = NS({ KP(0, 0.55), KP(0.5, 0.35), KP(1, 1) }),
			LockedToPart = true, ZOffset = 1,
		}, { EmitDuration = 1.0 })
		emitter(p, "Motes", {
			Texture = TEX.mote, Color = CS({ CK(0, PALE), CK(1, GOLD) }), LightEmission = 1,
			Lifetime = R(0.6, 1), Rate = 10, Speed = R(1, 2.5), SpreadAngle = Vector2.new(30, 30),
			Size = NS({ KP(0, 0.24), KP(1, 0) }), Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Sphere, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 1.0 })
	end

	-- MouthMist (windup, at the Mouth): bog-teal mist curling out of the jaws.
	do
		local p = anchor("MouthMist", Vector3.new(0.5, 0.5, 0.5), root)
		emitter(p, "Mist", {
			Texture = TEX.breath, Color = CS({ CK(0, TEAL), CK(1, DARK) }),
			LightEmission = 0.3, Lifetime = R(0.7, 1), Rate = 8,
			Speed = R(1, 2), SpreadAngle = Vector2.new(30, 30),
			Rotation = R(0, 360), RotSpeed = R(-25, 25),
			Size = NS({ KP(0, 1), KP(0.5, 2.4), KP(1, 3) }),
			Transparency = NS({ KP(0, 1), KP(0.3, 0.55), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Front,
		}, { EmitDuration = 0.7 })
	end

	-- TongueBeam (tongueLash, held ~0.2 s between Mouth and TongueTip; also the
	-- snare tether, thinner): a slate base beam, the pink tongue, a pale highlight.
	do
		local p = anchor("TongueBeam", Vector3.new(0.2, 0.2, 0.2), root)
		beamE(p, "Dark", { Color = CS(DARK), Width0 = 1.1, Width1 = 1.1, Transparency = NS(0.25), LightEmission = 0, ZOffset = 0 })
		beamE(p, "Core", { Color = CS({ CK(0, TONGUE), CK(1, Color3.fromRGB(240, 150, 140)) }), Width0 = 0.8, Width1 = 0.8, Transparency = NS(0), LightEmission = 0.2, ZOffset = 1 })
		beamE(p, "Shine", { Color = CS(PALE), Width0 = 0.25, Width1 = 0.25, Transparency = NS(0.2), LightEmission = 1, ZOffset = 2 })
	end
	do
		local p = anchor("TetherBeam", Vector3.new(0.2, 0.2, 0.2), root)
		beamE(p, "Dark", { Color = CS(DARK), Width0 = 0.7, Width1 = 0.7, Transparency = NS(0.3), LightEmission = 0 })
		beamE(p, "Core", { Color = CS({ CK(0, TEAL), CK(1, GOLD) }), Width0 = 0.4, Width1 = 0.4, Transparency = NS(0.1), LightEmission = 0.8, ZOffset = 1, Texture = TEX.line, TextureMode = Enum.TextureMode.Stretch })
	end

	-- TongueTipPop (the tongue's tip, tongueLash strike): a slimy gold pop.
	do
		local p = anchor("TipPop", Vector3.new(0.3, 0.3, 0.3), root)
		sparkE(p, "Drops", 6, TEAL, R(5, 10), R(0.25, 0.4), { Acceleration = Vector3.new(0, -25, 0) })
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, GOLD) }),
			LightEmission = 1, Lifetime = R(0.12), Size = NS({ KP(0, 0.6), KP(0.4, 1.8), KP(1, 0) }), ZOffset = 2,
		})
	end

	-- MudSplash (tongueLash / gulp hit, on the torso; -Z faces the toad).
	do
		local p = anchor("MudSplash", Vector3.new(0.4, 0.4, 0.4), root)
		puffE(p, "Mud", 5, MUD, { 1, 2.6 }, R(0.35, 0.55), R(5, 9), { EmissionDirection = Enum.NormalId.Back })
		emitter(p, "Clots", {
			Texture = TEX.ink, Color = CS(MUD), Lifetime = R(0.3), Rotation = R(0, 360),
			Size = NS({ KP(0, 1.2), KP(0.4, 3), KP(1, 3.4) }),
			Transparency = NS({ KP(0, 0.15), KP(0.6, 0.35), KP(1, 1) }), ZOffset = 1,
		})
		sparkE(p, "Drops", 8, TEAL, R(8, 14), R(0.3, 0.5), { Acceleration = Vector3.new(0, -30, 0), EmissionDirection = Enum.NormalId.Back })
	end

	-- CroakRings (bogCroak, at the sac): three sound rings and a puff.
	do
		local p = anchor("CroakRings", Vector3.new(0.5, 0.5, 0.5), root)
		for i = 1, 3 do
			local e = emitter(p, "Dark" .. i, {
				Texture = TEX.ring, Color = CS(DARK), Lifetime = R(0.5),
				Size = NS({ KP(0, 1), KP(1, 6 + i * 3) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.5,
			}, { EmitCount = 1, EmitDelay = (i - 1) * 0.14 })
			emitter(p, "Ring" .. i, {
				Texture = TEX.ring, Color = CS({ CK(0, PALE), CK(1, GOLD) }), LightEmission = 1, Lifetime = R(0.5),
				Size = NS({ KP(0, 0.8), KP(1, 5.5 + i * 3) }), Transparency = NS({ KP(0, 0.15), KP(1, 1) }), ZOffset = 1,
			}, { EmitCount = 1, EmitDelay = (i - 1) * 0.14 })
		end
	end

	-- BogPuddle (miasmaLob landing, authored r4; patch lasts ~3 s): a dark pool,
	-- a teal scum, bubbles popping, a rim ring. Impact.explode adds the splash.
	do
		local p = anchor("BogPuddle", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 4)
		emitter(p, "PoolDark", with(flat, {
			Texture = TEX.dot, Color = CS(DARK), Lifetime = R(3.2),
			Size = NS({ KP(0, 2), KP(0.08, 8.4), KP(1, 8.4) }),
			Transparency = NS({ KP(0, 0.4), KP(0.8, 0.4), KP(1, 1) }), ZOffset = 0.2,
		}), { EmitCount = 1 })
		emitter(p, "Scum", with(flat, {
			Texture = TEX.dot, Color = CS({ CK(0, TEAL), CK(1, GOLD) }), LightEmission = 0.3, Lifetime = R(3.1),
			Size = NS({ KP(0, 1.5), KP(0.08, 6.4), KP(1, 6) }),
			Transparency = NS({ KP(0, 0.6), KP(0.8, 0.6), KP(1, 1) }), ZOffset = 0.4,
		}), { EmitCount = 1 })
		ringE(p, "Rim", GOLD, { 2, 8.6 }, R(0.5), 1, { ZOffset = 1 }).Lifetime = R(0.5)
		emitter(p, "Bubbles", {
			Texture = TEX.ring, Color = CS({ CK(0, PALE), CK(1, TEAL) }), LightEmission = 0.7,
			Lifetime = R(0.4, 0.8), Rate = 7, Speed = R(0.6, 1.6), SpreadAngle = Vector2.new(20, 20),
			Size = NS({ KP(0, 0.2), KP(0.8, 0.8), KP(1, 0.9) }),
			Transparency = NS({ KP(0, 0.2), KP(0.85, 0.3), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Disc, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 3.0 })
	end

	-- HopDust (hop, at the feet): mud-coloured dust and a quick teal ring.
	do
		local p = anchor("HopDust", Vector3.new(3, 0.4, 3), root)
		puffE(p, "Dust", 6, MUD, { 1.5, 4 }, R(0.5, 0.8), R(3, 6), { EmissionDirection = Enum.NormalId.Top })
		ringE(p, "RingDark", DARK, { 1.5, 7 }, R(0.35), 0, { ZOffset = 0.5 })
		ringE(p, "Ring", TEAL, { 1.2, 6.5 }, R(0.3), 1, { ZOffset = 1 })
	end

	-- StaggerFlash (at the Core).
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, GOLD) }),
			LightEmission = 1, Brightness = 3, Lifetime = R(0.08),
			Size = NS({ KP(0, 1.5), KP(0.4, 4), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", GOLD, 3, R(0.12))
	end

	-- Death (at the Core, body-sized): gold motes and bog mist, a core glint.
	do
		local p = anchor("Death", Vector3.new(5, 3, 8), root)
		emitter(p, "Mist", {
			Texture = TEX.puff, Color = CS({ CK(0, TEAL), CK(1, DARK) }), LightEmission = 0.2,
			Lifetime = R(0.9, 1.4), Rate = 12, Speed = R(1.5, 3), SpreadAngle = Vector2.new(25, 25), Drag = 1.5,
			Rotation = R(0, 360), RotSpeed = R(-30, 30), Size = NS({ KP(0, 1.8), KP(1, 5) }),
			Transparency = NS({ KP(0, 0.4), KP(0.5, 0.6), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, PALE), CK(1, GOLD) }), LightEmission = 1,
			Lifetime = R(0.7, 1.2), Rate = 20, Speed = R(3, 5), Drag = 1, SpreadAngle = Vector2.new(20, 20),
			Size = NS({ KP(0, 0.24), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 0.7) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		local core = attach(p, "Core")
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 4,
			Lifetime = R(0.4), Size = NS({ KP(0, 0), KP(0.3, 2.4), KP(1, 0) }), RotSpeed = R(90), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
