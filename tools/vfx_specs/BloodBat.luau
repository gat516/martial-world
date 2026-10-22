--!nocheck
-- Builder for ReplicatedStorage.Effects.BloodBat: the Iron-Winged Blood Bat's
-- attack, hit and death effects (crimson blood and pale wind). Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/BloodBat.luau")
--   require(m)  -- installs _G.buildBloodBatFX(effectsFolder)
-- Runtime: src/client/EnemyFX/BloodBat.luau. Record: docs/systems/enemies.md.
-- A swarm of 3 to 4, so EVERY beat is 1 to 3 emitters, short; the only heavy
-- moment is the single shrieker's rings (Impact.roar). Invisible Part templates.
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

local CRIMSON = Color3.fromRGB(206, 30, 54)
local PALE = Color3.fromRGB(216, 230, 242)
local DARK = Color3.fromRGB(26, 10, 16)
local IRON = Color3.fromRGB(96, 98, 108)

function _G.buildBloodBatFX(effects)
	local old = effects:FindFirstChild("BloodBat")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "BloodBat"

	-- EyeGlint (a star and the held glow; the swarm's only windup particles).
	eyeGlint(root, "EyeGlint", CRIMSON)

	-- DiveStreak (bloodDive, rides the Core for the dive): a dark smear and a
	-- crimson streak (2 emitters).
	do
		local p = anchor("DiveStreak", Vector3.new(0.6, 0.6, 0.6), root)
		emitter(p, "Dark", with(along, {
			Texture = TEX.streak, Color = CS(DARK), Lifetime = R(0.3), Rate = 14, Speed = R(0.5),
			Size = NS({ KP(0, 2.4), KP(1, 0.4) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.5,
		}), { EmitDuration = 0.5 })
		emitter(p, "Streak", with(along, {
			Texture = TEX.streak, Color = CS({ CK(0, PALE), CK(1, CRIMSON) }), LightEmission = 1, Lifetime = R(0.25), Rate = 14, Speed = R(0.5),
			Size = NS({ KP(0, 1.5), KP(1, 0.2) }), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1,
		}), { EmitDuration = 0.5 })
	end

	-- LeechMote (leech: starts on the target, code flies it to the bat's Core over
	-- ~0.5 s): one trail of crimson motes (1 emitter).
	do
		local p = anchor("LeechMote", Vector3.new(0.3, 0.3, 0.3), root)
		emitter(p, "Motes", {
			Texture = TEX.dot, Color = CS({ CK(0, PALE), CK(0.3, CRIMSON), CK(1, DARK) }), LightEmission = 1, Lifetime = R(0.3, 0.45), Rate = 36,
			Speed = R(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
			Size = NS({ KP(0, 0.3), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		}, { EmitDuration = 0.6 })
	end

	-- ChestFlash (leech arrival, at the Core): a crimson pop and a star.
	do
		local p = anchor("ChestFlash", Vector3.new(0.3, 0.3, 0.3), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, CRIMSON) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.18),
			Size = NS({ KP(0, 0.6), KP(0.4, 2.2), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", CRIMSON, 1.8, R(0.2))
	end

	-- BiteHit (hit, on the torso): a pop, drops, a splat (3 emitters).
	do
		local p = anchor("BiteHit", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, CRIMSON) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.6), KP(0.4, 1.8), KP(1, 0) }), ZOffset = 3,
		})
		sparkE(p, "Drops", 5, CRIMSON, R(6, 12), R(0.3, 0.5), { Acceleration = Vector3.new(0, -30, 0), EmissionDirection = Enum.NormalId.Back })
		emitter(p, "Splat", {
			Texture = TEX.ink, Color = CS(CRIMSON), Lifetime = R(0.3), Rotation = R(0, 360),
			Size = NS({ KP(0, 0.8), KP(0.3, 2), KP(1, 2.4) }), Transparency = NS({ KP(0, 0.15), KP(1, 1) }), ZOffset = 1,
		})
	end

	-- HopPuff (hop, at the body): a pale wind puff and a streak (2 emitters).
	do
		local p = anchor("HopPuff", Vector3.new(1, 1, 1), root)
		puffE(p, "Puff", 3, PALE, { 0.8, 2.4 }, R(0.3, 0.5), R(2, 5), { SpreadAngle = Vector2.new(70, 70) })
		emitter(p, "Streak", with(along, {
			Texture = TEX.streak, Color = CS({ CK(0, PALE), CK(1, CRIMSON) }), LightEmission = 0.8, Lifetime = R(0.25), Speed = R(6),
			Size = NS({ KP(0, 1.6), KP(1, 2.4) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		}), { EmitCount = 1 })
	end

	-- StaggerFlash (1 emitter).
	do
		local p = anchor("StaggerFlash", Vector3.new(0.3, 0.3, 0.3), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, CRIMSON) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.08),
			Size = NS({ KP(0, 1), KP(0.4, 2.8), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- Death (2 emitters): iron feathers dropping, a puff of blood mist.
	do
		local p = anchor("Death", Vector3.new(2.6, 1.5, 2.6), root)
		emitter(p, "Feathers", {
			Texture = TEX.chips, Color = CS(IRON), Lifetime = R(0.6, 1), Speed = R(2, 6), SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -14, 0), Rotation = R(0, 360), RotSpeed = R(-300, 300),
			Size = NS({ KP(0, 0.4), KP(1, 0.3) }), Transparency = NS({ KP(0, 0), KP(0.8, 0), KP(1, 1) }),
		}, { EmitCount = 8 })
		puffE(p, "Mist", 4, CRIMSON, { 1.5, 4 }, R(0.7, 1.1), R(1, 3), { LightEmission = 0.2, SpreadAngle = Vector2.new(40, 40) })
	end

	root.Parent = effects
	return root
end

return true
