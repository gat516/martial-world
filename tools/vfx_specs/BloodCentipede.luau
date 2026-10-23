--!nocheck
-- Builder for ReplicatedStorage.Effects.BloodCentipede: the Blood Centipede's
-- attack, burrow, hit and death effects (earth-blood: bone white and rust red).
-- Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/BloodCentipede.luau")
--   require(m)  -- installs _G.buildBloodCentipedeFX(effectsFolder)
-- Runtime: src/client/EnemyFX/BloodCentipede.luau. Record: docs/enemies/third-wave.md.
-- Invisible Part templates (-Z = facing / blow direction), ground ones centred
-- on the ground; a dark base under every bright layer.
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

local BONE = Color3.fromRGB(238, 230, 208)
local RUST = Color3.fromRGB(176, 56, 36)
local BLOOD = Color3.fromRGB(214, 40, 40)
local DARK = Color3.fromRGB(30, 16, 14)
local DIRT = Color3.fromRGB(122, 98, 74)
local C = { mid = BLOOD, rim = BONE, dark = DARK }

function _G.buildBloodCentipedeFX(effects)
	local old = effects:FindFirstChild("BloodCentipede")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "BloodCentipede"

	eyeGlint(root, "EyeGlint", BLOOD)

	-- CrescentSnap (pincerSnap strike, at the Mouth, -Z forward): a blood-red
	-- crescent on a dark base, white-hot core, flecks.
	do
		local p = anchor("CrescentSnap", Vector3.new(0.5, 0.5, 0.5), root)
		stack(p, "Fang", TEX.fang, C, { 4, 6 }, R(0.16), with(along, { Speed = R(14) }), { EmitCount = 1 })
		stack(p, "FangB", TEX.fang, C, { 3, 5 }, R(0.16), with(along, { Speed = R(14), Rotation = R(180) }), { EmitCount = 1 })
		sparkE(p, "Flecks", 6, BLOOD, R(8, 14), R(0.25, 0.4))
	end

	-- SweepArc (coilSweep strike, on the ground at the body, authored r12): a
	-- flat blood crescent sweeping out on a dark base and a fan of dust.
	do
		local p = anchor("SweepArc", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 12)
		emitter(p, "ArcDark", with(flat, {
			Texture = TEX.fang, Color = CS(DARK), Lifetime = R(0.45),
			Size = NS({ KP(0, 12), KP(1, 26) }), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), ZOffset = 0.5,
		}), { EmitCount = 1 })
		emitter(p, "Arc", with(flat, {
			Texture = TEX.fang, Color = CS({ CK(0, BONE), CK(1, RUST) }), LightEmission = 0.6, Lifetime = R(0.4),
			Size = NS({ KP(0, 10), KP(1, 24) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1,
		}), { EmitCount = 1 })
		puffE(p, "Dust", 8, DIRT, { 2, 5 }, R(0.6, 1), R(8, 14), { SpreadAngle = Vector2.new(80, 80), EmissionDirection = Enum.NormalId.Top })
	end

	-- BurrowMound (Burrowed, ongoing, on the ground at the body): loose dirt
	-- puffs and chips, a darker earth hump. Code stops it when it surfaces.
	do
		local p = anchor("BurrowMound", Vector3.new(3, 0.5, 8), root)
		emitter(p, "Hump", with(flat, {
			Texture = TEX.dot, Color = CS(DARK), Lifetime = R(1.2), Rate = 1.5,
			Size = NS({ KP(0, 5), KP(0.2, 8), KP(1, 7) }),
			Transparency = NS({ KP(0, 0.5), KP(0.7, 0.5), KP(1, 1) }), ZOffset = 0.3,
		}), { EmitDuration = 600 })
		emitter(p, "Dirt", {
			Texture = TEX.puff, Color = CS(DIRT), Lifetime = R(0.6, 1), Rate = 7, Speed = R(1, 3),
			SpreadAngle = Vector2.new(30, 30), Drag = 2, Rotation = R(0, 360),
			Size = NS({ KP(0, 1), KP(1, 3.4) }), Transparency = NS({ KP(0, 0.4), KP(0.5, 0.55), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 600 })
		emitter(p, "Chips", {
			Texture = TEX.chips, Color = CS(Color3.fromRGB(110, 92, 74)), Lifetime = R(0.5, 0.8), Rate = 4,
			Speed = R(4, 8), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -34, 0),
			Rotation = R(0, 360), RotSpeed = R(-200, 200), Size = NS({ KP(0, 0.3), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0), KP(0.8, 0), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 600 })
	end

	-- CrackStamp (stamped along the lane every ~0.14 s while burrowed, -Z along
	-- the travel): a dark crack with a rust glow in it, fading over ~1.2 s.
	do
		local p = anchor("CrackStamp", Vector3.new(1, 0.2, 1), root)
		emitter(p, "Crack", with(flat, {
			Texture = TEX.crack, Color = CS(DARK), Lifetime = R(1.4), Rotation = R(0, 360),
			Size = NS({ KP(0, 3.4), KP(0.1, 4.6), KP(1, 4.6) }),
			Transparency = NS({ KP(0, 0.1), KP(0.5, 0.25), KP(1, 1) }), ZOffset = 0.4,
		}), { EmitCount = 1 })
		emitter(p, "Glow", with(flat, {
			Texture = TEX.crack, Color = CS({ CK(0, BONE), CK(0.3, RUST), CK(1, DARK) }),
			LightEmission = 0.8, Lifetime = R(0.7), Rotation = R(0, 360),
			Size = NS({ KP(0, 3.4), KP(0.1, 4.6), KP(1, 4.6) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 0.8,
		}), { EmitCount = 1 })
		puffE(p, "Dust", 1, DIRT, { 1, 2.4 }, R(0.4, 0.7), R(1, 2.5), { EmissionDirection = Enum.NormalId.Top })
	end

	-- DiveBurst (burrowDive set-off, at the root): dust thrown up, chips.
	do
		local p = anchor("DiveBurst", Vector3.new(3, 0.5, 6), root)
		puffE(p, "Dust", 8, DIRT, { 2, 5.5 }, R(0.6, 1), R(5, 10), { SpreadAngle = Vector2.new(70, 70) })
		chipsE(p, "Chips", 10, { 8, 16 }, 0.4, Color3.fromRGB(110, 92, 74))
		ringE(p, "RingDark", DARK, { 2, 12 }, R(0.4), 0, { ZOffset = 0.5 })
	end

	-- Eruption (erupt strike, on the ground at the root, authored r6.5;
	-- Impact.ground adds shock/rocks/shake): a ground-break scar with rust light,
	-- a dust column, chips, a blood-red flash.
	do
		local p = anchor("Eruption", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 6.5)
		emitter(p, "Scar", with(flat, {
			Texture = TEX.crack, Color = CS(DARK), Lifetime = R(2.4), Rotation = R(0, 360),
			Size = NS({ KP(0, 5), KP(0.1, 13), KP(1, 13) }),
			Transparency = NS({ KP(0, 0), KP(0.7, 0.1), KP(1, 1) }), ZOffset = 0.5,
		}), { EmitCount = 1 })
		emitter(p, "Glow", with(flat, {
			Texture = TEX.crack, Color = CS({ CK(0, WHITE), CK(0.2, RUST), CK(1, RUST) }),
			LightEmission = 1, Lifetime = R(1.0), Rotation = R(0, 360),
			Size = NS({ KP(0, 5), KP(0.1, 13), KP(1, 13) }),
			Transparency = NS({ KP(0, 0.1), KP(0.4, 0.3), KP(1, 1) }), ZOffset = 1,
		}), { EmitCount = 1 })
		emitter(p, "Column", {
			Texture = TEX.puff, Color = CS({ CK(0, DIRT), CK(1, Color3.fromRGB(90, 76, 62)) }),
			Lifetime = R(0.8, 1.3), Speed = R(10, 20), SpreadAngle = Vector2.new(14, 14), Drag = 2,
			Rotation = R(0, 360), RotSpeed = R(-40, 40),
			Size = NS({ KP(0, 2.5), KP(0.5, 5), KP(1, 7) }),
			Transparency = NS({ KP(0, 0.25), KP(0.6, 0.5), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		}, { EmitCount = 9 })
		chipsE(p, "Chips", 16, { 14, 28 }, 0.6, Color3.fromRGB(110, 92, 74)).SpreadAngle = Vector2.new(40, 40)
		emitter(p, "Flash", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BLOOD) }), LightEmission = 1, Brightness = 3,
			Lifetime = R(0.15), Size = NS({ KP(0, 3), KP(0.4, 8), KP(1, 0) }), ZOffset = 3,
		})
		ringE(p, "Ring", RUST, { 2, 13 }, R(0.4), 1, { ZOffset = 1 })
	end

	-- BloodHit (hit, on the torso; -Z faces the centipede): a red splatter.
	do
		local p = anchor("BloodHit", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Splat", {
			Texture = TEX.ink, Color = CS({ CK(0, BLOOD), CK(1, RUST) }), Lifetime = R(0.4), Rotation = R(0, 360),
			Size = NS({ KP(0, 1.2), KP(0.3, 3.2), KP(1, 3.8) }),
			Transparency = NS({ KP(0, 0.1), KP(0.6, 0.3), KP(1, 1) }), ZOffset = 1,
		})
		sparkE(p, "Drops", 9, BLOOD, R(8, 15), R(0.3, 0.55), { Acceleration = Vector3.new(0, -35, 0), EmissionDirection = Enum.NormalId.Back })
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BLOOD) }), LightEmission = 1, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.8), KP(0.4, 2.2), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- StaggerFlash (at the Core).
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, BLOOD) }), LightEmission = 1, Brightness = 3,
			Lifetime = R(0.08), Size = NS({ KP(0, 1.5), KP(0.4, 4), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", BLOOD, 3, R(0.12))
	end

	-- Death (body-sized): dissolves to bone dust and red motes, a core glint.
	do
		local p = anchor("Death", Vector3.new(3, 2, 15), root)
		emitter(p, "Dust", {
			Texture = TEX.puff, Color = CS({ CK(0, BONE), CK(1, DIRT) }), Lifetime = R(0.9, 1.4), Rate = 22,
			Speed = R(1.5, 3.5), SpreadAngle = Vector2.new(30, 30), Drag = 1.5, Rotation = R(0, 360), RotSpeed = R(-30, 30),
			Size = NS({ KP(0, 1.4), KP(1, 4.4) }), Transparency = NS({ KP(0, 0.35), KP(0.5, 0.55), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, BLOOD), CK(1, RUST) }), LightEmission = 1,
			Lifetime = R(0.7, 1.2), Rate = 22, Speed = R(3, 6), Drag = 1, SpreadAngle = Vector2.new(25, 25),
			Size = NS({ KP(0, 0.24), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 0.7) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		local core = attach(p, "Core")
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, BLOOD) }), LightEmission = 1, Brightness = 4,
			Lifetime = R(0.4), Size = NS({ KP(0, 0), KP(0.3, 2.4), KP(1, 0) }), RotSpeed = R(90), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
