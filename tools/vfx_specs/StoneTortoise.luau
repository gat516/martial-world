--!nocheck
-- Builder for ReplicatedStorage.Effects.StoneTortoise: the new Stone Tortoise's
-- (body StoneTortoiseB) attack, hit and death effects. Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/StoneTortoise.luau")
--   require(m)  -- installs _G.buildStoneTortoiseFX(effectsFolder)
-- Runtime: src/client/EnemyFX/StoneTortoise.luau. Record: docs/systems/enemies.md.
--
-- Jade seams (#5FD6A0) over umber and stone grey; guard is cold white-blue.
-- Heavy and slow: chips, dust and cracks do the work. Templates are invisible
-- Parts (-Z = blow direction); ground ones sit centred on the ground.
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

local JADE = Color3.fromRGB(95, 214, 160)
local PALE = Color3.fromRGB(190, 245, 215)
local COLD = Color3.fromRGB(190, 225, 255)
local DARK = Color3.fromRGB(38, 36, 34)
local UMBER = Color3.fromRGB(128, 104, 82)
local ROCK = Color3.fromRGB(120, 112, 100)
local C = { mid = JADE, rim = PALE, dark = DARK }

function _G.buildStoneTortoiseFX(effects)
	local old = effects:FindFirstChild("StoneTortoise")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "StoneTortoise"

	-- EyeGlint (each eye and the BrowMark, every windup): jade star, held glow.
	eyeGlint(root, "EyeGlint", JADE)

	-- Breath (neckSnap windup, at the Mouth): a pale-jade wisp, motes drawn in.
	do
		local p = anchor("Breath", Vector3.new(0.5, 0.5, 0.5), root)
		emitter(p, "Wisp", {
			Texture = TEX.breath, Color = CS({ CK(0, PALE), CK(1, JADE) }),
			LightEmission = 0.5, Lifetime = R(0.6, 0.9), Rate = 9,
			Speed = R(1, 2.2), SpreadAngle = Vector2.new(25, 25),
			Rotation = R(0, 360), RotSpeed = R(-25, 25),
			Size = NS({ KP(0, 0.8), KP(0.5, 2), KP(1, 2.6) }),
			Transparency = NS({ KP(0, 1), KP(0.3, 0.55), KP(1, 1) }),
			EmissionDirection = Enum.NormalId.Front,
		}, { EmitDuration = 0.7 })
		emitter(p, "Motes", {
			Texture = TEX.mote, Color = CS(PALE), LightEmission = 1,
			Lifetime = R(0.35, 0.5), Rate = 14, Speed = R(-5, -3),
			Shape = Enum.ParticleEmitterShape.Sphere,
			Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.5), KP(0.6, 0.1), KP(1, 1) }),
		}, { EmitDuration = 0.7 })
	end

	-- SnapBurst (neckSnap / shellSnap strike, at the Mouth, -Z forward): a
	-- stone-chip burst, a brief jade streak along the neck, a dust puff.
	do
		local p = anchor("SnapBurst", Vector3.new(0.5, 0.5, 0.5), root)
		stack(p, "Streak", TEX.streak, C, { 2.2, 5 }, R(0.2), with(along, { Speed = R(26) }), { EmitCount = 2 })
		chipsE(p, "Chips", 8, { 14, 26 }, 0.5, ROCK).EmissionDirection = Enum.NormalId.Front
		puffE(p, "Dust", 4, UMBER, { 1.2, 3 }, R(0.5, 0.8), R(4, 8), { EmissionDirection = Enum.NormalId.Front })
	end

	-- ShellDust (quakeStomp windup, at the Core): dust sheds off the shell and
	-- pebbles drop from it.
	do
		local p = anchor("ShellDust", Vector3.new(7, 1, 9), root)
		emitter(p, "Dust", {
			Texture = TEX.puff, Color = CS(UMBER), Lifetime = R(0.7, 1.1), Rate = 12,
			Speed = R(0.5, 1.5), Acceleration = Vector3.new(0, -3, 0), Drag = 1,
			Rotation = R(0, 360), RotSpeed = R(-30, 30),
			Size = NS({ KP(0, 0.8), KP(1, 2.6) }),
			Transparency = NS({ KP(0, 0.5), KP(0.4, 0.55), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom,
		}, { EmitDuration = 1.0 })
		emitter(p, "Pebbles", {
			Texture = TEX.chips, Color = CS(ROCK), Lifetime = R(0.6, 0.9), Rate = 8,
			Speed = R(0, 2), Acceleration = Vector3.new(0, -30, 0),
			Rotation = R(0, 360), RotSpeed = R(-200, 200),
			Size = NS({ KP(0, 0.28), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0), KP(0.8, 0), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom,
		}, { EmitDuration = 1.0 })
	end

	-- FootPebbles (each foot, quakeStomp windup; ground point): pebbles lift and
	-- dust curls up; on the hind feet code adds a digging scuff.
	do
		local p = anchor("FootPebbles", Vector3.new(2.4, 0.3, 2.4), root)
		emitter(p, "Lift", {
			Texture = TEX.chips, Color = CS(ROCK), Lifetime = R(0.5, 0.8), Rate = 10,
			Speed = R(3, 6), SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, -14, 0),
			Rotation = R(0, 360), RotSpeed = R(-200, 200),
			Size = NS({ KP(0, 0.3), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0), KP(0.8, 0), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		emitter(p, "Dust", {
			Texture = TEX.puff, Color = CS(UMBER), Lifetime = R(0.6, 0.9), Rate = 7,
			Speed = R(1, 2.5), Drag = 2, SpreadAngle = Vector2.new(60, 60),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 0.8), KP(1, 2.4) }),
			Transparency = NS({ KP(0, 0.5), KP(0.4, 0.6), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
	end

	-- QuakeCrack (quakeStomp drop, on the ground at the foot centre, authored r9;
	-- Impact.ground adds shock/dust/rocks): a cracked scar with jade light in it
	-- that fades, a flat spiky dust ring, a chip burst and a flash.
	do
		local p = anchor("QuakeCrack", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 9)
		emitter(p, "Scar", with(flat, {
			Texture = TEX.crack, Color = CS(DARK), Lifetime = R(2.2),
			Size = NS({ KP(0, 6), KP(0.1, 17), KP(1, 17) }),
			Transparency = NS({ KP(0, 0), KP(0.7, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5,
		}), { EmitCount = 1 })
		emitter(p, "Glow", with(flat, {
			Texture = TEX.crack, Color = CS({ CK(0, WHITE), CK(0.2, JADE), CK(1, JADE) }),
			LightEmission = 1, Brightness = 2, Lifetime = R(1.1),
			Size = NS({ KP(0, 6), KP(0.1, 17), KP(1, 17) }),
			Transparency = NS({ KP(0, 0.1), KP(0.4, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1,
		}), { EmitCount = 1 })
		emitter(p, "DustRing", with(flat, {
			Texture = TEX.dustRing, Color = CS(UMBER), Lifetime = R(0.9),
			Size = NS({ KP(0, 3), KP(0.3, 14), KP(1, 19) }),
			Transparency = NS({ KP(0, 0.3), KP(0.5, 0.55), KP(1, 1) }),
		}), { EmitCount = 1 })
		chipsE(p, "Chips", 18, { 16, 32 }, 0.7, ROCK).SpreadAngle = Vector2.new(60, 60)
		emitter(p, "Flash", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }),
			LightEmission = 1, Brightness = 3, Lifetime = R(0.15),
			Size = NS({ KP(0, 3), KP(0.4, 9), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- HitJade (quakeStomp hit, on the target's torso; -Z faces the beast): dust
	-- and jade sparks.
	do
		local p = anchor("HitJade", Vector3.new(0.4, 0.4, 0.4), root)
		puffE(p, "Dust", 5, UMBER, { 1.2, 3 }, R(0.4, 0.7), R(5, 9), { EmissionDirection = Enum.NormalId.Back })
		sparkE(p, "Sparks", 10, JADE, R(10, 18), R(0.3, 0.55), { Acceleration = Vector3.new(0, -25, 0), EmissionDirection = Enum.NormalId.Back })
		starE(p, "Star", PALE, 1.8, R(0.15))
	end

	-- HitChips (neckSnap hit): chips and a dust burst on the target.
	do
		local p = anchor("HitChips", Vector3.new(0.4, 0.4, 0.4), root)
		chipsE(p, "Chips", 9, { 10, 20 }, 0.4, ROCK).EmissionDirection = Enum.NormalId.Back
		puffE(p, "Dust", 4, UMBER, { 1, 2.6 }, R(0.4, 0.7), R(4, 8), { EmissionDirection = Enum.NormalId.Back })
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }),
			LightEmission = 1, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.8), KP(0.4, 2.2), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- GuardSheen (shellGuard hold, at the Core, 2 s): a faint cold stone sheen
	-- on the shell: a slow breathing glow and drifting motes.
	do
		local p = anchor("GuardSheen", Vector3.new(7, 2, 9), root)
		emitter(p, "Sheen", {
			Texture = TEX.dot, Color = CS(COLD), LightEmission = 0.8, Lifetime = R(0.9),
			Rate = 3, Size = NS({ KP(0, 5), KP(0.5, 8), KP(1, 6) }),
			Transparency = NS({ KP(0, 1), KP(0.4, 0.88), KP(1, 1) }),
			LockedToPart = true, ZOffset = 0,
		}, { EmitDuration = 2.0 })
		emitter(p, "Motes", {
			Texture = TEX.mote, Color = CS(COLD), LightEmission = 1, Lifetime = R(0.7, 1.1),
			Rate = 8, Speed = R(0.6, 1.4), SpreadAngle = Vector2.new(15, 15),
			Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.4), KP(0.6, 0.3), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 2.0 })
	end

	-- GuardSpark (a player's hit during the hold, at the struck spot on the
	-- shell): cold sparks and a star, the damage-reduction read.
	do
		local p = anchor("GuardSpark", Vector3.new(0.4, 0.4, 0.4), root)
		sparkE(p, "Sparks", 12, COLD, R(12, 22), R(0.25, 0.45), { Acceleration = Vector3.new(0, -30, 0) })
		starE(p, "Star", COLD, 2.6, R(0.18))
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, COLD) }),
			LightEmission = 1, Brightness = 2, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.8), KP(0.4, 2.4), KP(1, 0) }), ZOffset = 3,
		})
		ringE(p, "Ring", COLD, { 0.5, 3.2 }, R(0.22), 1, { Orientation = Enum.ParticleOrientation.FacingCamera })
	end

	-- GuardRelease (the hold ends, at the Core): a dust puff and a cold ring.
	do
		local p = anchor("GuardRelease", Vector3.new(3, 0.5, 3), root)
		puffE(p, "Dust", 7, UMBER, { 2, 5 }, R(0.6, 1), R(4, 8), { EmissionDirection = Enum.NormalId.Top })
		ringE(p, "Ring", COLD, { 3, 13 }, R(0.4), 1)
	end

	-- StaggerChips (stagger, at the Core): chips fly off, a pop, a little dust.
	do
		local p = anchor("StaggerChips", Vector3.new(0.5, 0.5, 0.5), root)
		chipsE(p, "Chips", 10, { 8, 16 }, 0.45, ROCK)
		puffE(p, "Dust", 3, UMBER, { 1.5, 3.5 }, R(0.5, 0.8), R(2, 5))
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }),
			LightEmission = 1, Brightness = 2, Lifetime = R(0.1),
			Size = NS({ KP(0, 1), KP(0.4, 3), KP(1, 0) }), ZOffset = 3,
		})
	end

	-- Death (at the Core, body-sized): the shell cracks (a jade flash then a
	-- fading glow), dust crumbles, chips fall, a core glint.
	do
		local p = anchor("Death", Vector3.new(7, 2, 9), root)
		emitter(p, "Crumble", {
			Texture = TEX.puff, Color = CS({ CK(0, UMBER), CK(1, ROCK) }),
			Lifetime = R(0.9, 1.4), Rate = 22, Speed = R(1, 3), Drag = 1.5,
			SpreadAngle = Vector2.new(40, 40), Rotation = R(0, 360), RotSpeed = R(-30, 30),
			Size = NS({ KP(0, 1.4), KP(1, 4.5) }),
			Transparency = NS({ KP(0, 0.4), KP(0.5, 0.55), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.9 })
		emitter(p, "Chips", {
			Texture = TEX.chips, Color = CS(ROCK), Lifetime = R(0.6, 1), Rate = 18,
			Speed = R(4, 10), SpreadAngle = Vector2.new(50, 50), Acceleration = Vector3.new(0, -35, 0),
			Rotation = R(0, 360), RotSpeed = R(-250, 250),
			Size = NS({ KP(0, 0.5), KP(1, 0.35) }),
			Transparency = NS({ KP(0, 0), KP(0.8, 0), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.5 })
		local core = attach(p, "Core")
		emitter(core, "Flash", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(0.3, JADE), CK(1, JADE) }),
			LightEmission = 1, Brightness = 3, Lifetime = R(0.7),
			Size = NS({ KP(0, 2), KP(0.3, 8), KP(1, 3) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 2,
		}, { EmitCount = 1 })
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, PALE) }),
			LightEmission = 1, Brightness = 4, Lifetime = R(0.5),
			Size = NS({ KP(0, 0), KP(0.3, 3), KP(1, 0) }), RotSpeed = R(60), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.15 })
	end

	root.Parent = effects
	return root
end

return true
