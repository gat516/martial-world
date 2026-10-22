--!nocheck
-- Builder for ReplicatedStorage.Effects.FrostSpider: the Frost Spider's attack,
-- web, slow, hit and death effects (ice white-blue on slate). Load through the receiver:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/FrostSpider.luau")
--   require(m)  -- installs _G.buildFrostSpiderFX(effectsFolder)
-- Runtime: src/client/EnemyFX/FrostSpider.luau. Record: docs/systems/enemies.md.
-- Invisible Part templates (-Z = facing / blow direction), ground ones centred
-- on the ground; a slate base under every bright layer, and the web patch has
-- a bright edge ring so it reads without relying on colour.
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

local ICE = Color3.fromRGB(170, 222, 255)
local DEEP = Color3.fromRGB(90, 150, 222)
local PALEW = Color3.fromRGB(236, 247, 255)
local SLATE = Color3.fromRGB(32, 42, 58)
local C = { mid = DEEP, rim = PALEW, dark = SLATE }

function _G.buildFrostSpiderFX(effects)
	local old = effects:FindFirstChild("FrostSpider")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "FrostSpider"

	-- EyeGlint (each of the six eyes, windup): an ice star, a short held glow.
	do
		local p = anchor("EyeGlint", Vector3.new(0.2, 0.2, 0.2), root)
		emitter(p, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.5, ICE), CK(1, ICE) }), LightEmission = 1, Brightness = 4,
			Lifetime = R(0.16), Size = NS({ KP(0, 0.2), KP(0.3, 1.1), KP(1, 0) }), ZOffset = 2,
		})
		emitter(p, "Hold", {
			Texture = TEX.dot, Color = CS(ICE), LightEmission = 1, Lifetime = R(0.12, 0.18), Rate = 10,
			Size = NS({ KP(0, 0.26), KP(1, 0.18) }), Transparency = NS({ KP(0, 0.35), KP(1, 0.8) }),
			LockedToPart = true, ZOffset = 1.5,
		}, { EmitDuration = 0.45 })
	end

	-- FangGlint (windup, on each fang): an ice star on slate and a drip of chill.
	do
		local p = anchor("FangGlint", Vector3.new(0.3, 0.3, 0.3), root)
		emitter(p, "Dark", {
			Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(0.5), Size = NS({ KP(0, 0.6), KP(0.3, 1.6), KP(1, 1.1) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }), ZOffset = 0.5,
		})
		starE(p, "Star", ICE, 2.2, R(0.4))
		emitter(p, "Chill", {
			Texture = TEX.mote, Color = CS(PALEW), LightEmission = 1, Lifetime = R(0.5, 0.8), Rate = 8,
			Speed = R(0.5, 1.5), Acceleration = Vector3.new(0, -6, 0), Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
		}, { EmitDuration = 0.7 })
	end

	-- SpinneretGlow (webShot windup, at the Spinneret): a glow that builds and
	-- frost motes drifting off.
	do
		local p = anchor("SpinneretGlow", Vector3.new(0.5, 0.5, 0.5), root)
		emitter(p, "Glow", {
			Texture = TEX.dot, Color = CS({ CK(0, PALEW), CK(1, DEEP) }), LightEmission = 1, Lifetime = R(0.4, 0.55), Rate = 8,
			Size = NS({ KP(0, 0.8), KP(0.5, 2.4), KP(1, 1.4) }), Transparency = NS({ KP(0, 0.5), KP(0.5, 0.35), KP(1, 1) }),
			LockedToPart = true, ZOffset = 1,
		}, { EmitDuration = 0.9 })
		emitter(p, "Motes", {
			Texture = TEX.mote, Color = CS(PALEW), LightEmission = 1, Lifetime = R(0.6, 1), Rate = 10,
			Speed = R(0.8, 2), SpreadAngle = Vector2.new(35, 35), Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }), EmissionDirection = Enum.NormalId.Back,
		}, { EmitDuration = 0.9 })
	end

	-- WebBeam (the web thread, Spinneret -> the landing): a slate base and a thin
	-- bright thread.
	do
		local p = anchor("WebBeam", Vector3.new(0.2, 0.2, 0.2), root)
		beamE(p, "Dark", { Color = CS(SLATE), Width0 = 0.5, Width1 = 0.5, Transparency = NS(0.25), LightEmission = 0 })
		beamE(p, "Core", { Color = CS({ CK(0, PALEW), CK(1, ICE) }), Width0 = 0.25, Width1 = 0.25, Transparency = NS(0), LightEmission = 1, ZOffset = 1 })
	end

	-- WebPatch (webShot landing, authored r5, ~4 s; code refits to the patch's
	-- length and radius): a slate base disc, a pale silk disc, a bright edge ring
	-- with a dark outer ring (reads without colour), a few strands across, frost
	-- glints twinkling for the duration.
	do
		local p = anchor("WebPatch", Vector3.new(1, 1, 1), root)
		p:SetAttribute("AuthoredRadius", 5)
		emitter(p, "Base", with(flat, {
			Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(4.2),
			Size = NS({ KP(0, 4), KP(0.04, 10.4), KP(1, 10.4) }), Transparency = NS({ KP(0, 0.4), KP(0.8, 0.45), KP(1, 1) }), ZOffset = 0.2,
		}), { EmitCount = 1 })
		emitter(p, "Silk", with(flat, {
			Texture = TEX.dot, Color = CS({ CK(0, PALEW), CK(1, ICE) }), LightEmission = 0.4, Lifetime = R(4.1),
			Size = NS({ KP(0, 3), KP(0.04, 9.2), KP(1, 9.2) }), Transparency = NS({ KP(0, 0.7), KP(0.8, 0.72), KP(1, 1) }), ZOffset = 0.4,
		}), { EmitCount = 1 })
		emitter(p, "EdgeDark", with(flat, {
			Texture = TEX.ring, Color = CS(SLATE), Lifetime = R(4.2),
			Size = NS({ KP(0, 4), KP(0.04, 11.4), KP(1, 11.4) }), Transparency = NS({ KP(0, 0.1), KP(0.8, 0.15), KP(1, 1) }), ZOffset = 0.6,
		}), { EmitCount = 1 })
		emitter(p, "Edge", with(flat, {
			Texture = TEX.ring, Color = CS(PALEW), LightEmission = 1, Lifetime = R(4.1),
			Size = NS({ KP(0, 3.4), KP(0.04, 10.2), KP(1, 10.2) }), Transparency = NS({ KP(0, 0.05), KP(0.8, 0.2), KP(1, 1) }), ZOffset = 1,
		}), { EmitCount = 1 })
		emitter(p, "Strands", with(flat, {
			Texture = TEX.claw, Color = CS(PALEW), LightEmission = 0.8, Lifetime = R(4.1), Rotation = R(0, 360),
			Size = NS({ KP(0, 3), KP(0.04, 8.4), KP(1, 8.4) }), Transparency = NS({ KP(0, 0.4), KP(0.8, 0.5), KP(1, 1) }), ZOffset = 0.8,
		}), { EmitCount = 2 })
		emitter(p, "Glints", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, ICE) }), LightEmission = 1, Lifetime = R(0.4, 0.7), Rate = 4,
			Size = NS({ KP(0, 0), KP(0.4, 0.9), KP(1, 0) }), Rotation = R(0, 90),
			Shape = Enum.ParticleEmitterShape.Disc, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			EmissionDirection = Enum.NormalId.Top, ZOffset = 2,
		}, { EmitDuration = 4.0 })
	end

	-- WebSplat (webShot landing burst, with Impact.explode): frost puffs and shards.
	do
		local p = anchor("WebSplat", Vector3.new(1, 1, 1), root)
		puffE(p, "Frost", 6, PALEW, { 1.5, 4.4 }, R(0.5, 0.8), R(5, 10), { LightEmission = 0.4, SpreadAngle = Vector2.new(70, 70) })
		chipsE(p, "Shards", 10, { 8, 16 }, 0.4, ICE).SpreadAngle = Vector2.new(60, 60)
		starE(p, "Glint", ICE, 3, R(0.3))
	end

	-- FangFrost (frostFang strike, at the Mouth, -Z forward): two ice crescents
	-- on slate, shards.
	do
		local p = anchor("FangFrost", Vector3.new(0.5, 0.5, 0.5), root)
		stack(p, "Fang", TEX.fang, C, { 3.4, 5.4 }, R(0.16), with(along, { Speed = R(14) }), { EmitCount = 1 })
		stack(p, "FangB", TEX.fang, C, { 3, 5 }, R(0.16), with(along, { Speed = R(14), Rotation = R(180) }), { EmitCount = 1 })
		chipsE(p, "Shards", 6, { 8, 14 }, 0.3, ICE).EmissionDirection = Enum.NormalId.Front
	end

	-- FrostHit (frostFang hit, on the torso; -Z faces the spider): ice crystals
	-- bursting out, stars, a pop, a puff of frost.
	do
		local p = anchor("FrostHit", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, ICE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.1),
			Size = NS({ KP(0, 0.8), KP(0.4, 2.6), KP(1, 0) }), ZOffset = 3,
		})
		chipsE(p, "Crystals", 9, { 8, 15 }, 0.45, ICE).EmissionDirection = Enum.NormalId.Back
		emitter(p, "Stars", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, ICE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.3, 0.5),
			Speed = R(3, 7), SpreadAngle = Vector2.new(60, 60), Size = NS({ KP(0, 0), KP(0.3, 1.2), KP(1, 0) }),
			Rotation = R(0, 90), EmissionDirection = Enum.NormalId.Back, ZOffset = 2,
		}, { EmitCount = 4 })
		puffE(p, "Frost", 3, PALEW, { 1, 2.4 }, R(0.4, 0.6), R(3, 6), { LightEmission = 0.4, EmissionDirection = Enum.NormalId.Back })
	end

	-- FootFrost (the slowed player's feet; EmitDuration = the slow): a frosty ring
	-- on slate under the foot and chill motes.
	do
		local p = anchor("FootFrost", Vector3.new(1.2, 0.3, 1.2), root)
		emitter(p, "Base", with(flat, {
			Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(0.5), Rate = 2.5,
			Size = NS({ KP(0, 1.8), KP(1, 2.2) }), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), LockedToPart = true, ZOffset = 0.2,
		}), { EmitDuration = 1.5 })
		emitter(p, "Rime", with(flat, {
			Texture = TEX.ring, Color = CS({ CK(0, PALEW), CK(1, ICE) }), LightEmission = 0.8, Lifetime = R(0.5), Rate = 2.5,
			Size = NS({ KP(0, 1.5), KP(1, 2) }), Transparency = NS({ KP(0, 0.15), KP(1, 1) }), LockedToPart = true, ZOffset = 1,
		}), { EmitDuration = 1.5 })
		emitter(p, "Chill", {
			Texture = TEX.mote, Color = CS(PALEW), LightEmission = 1, Lifetime = R(0.5, 0.8), Rate = 6,
			Speed = R(0.5, 1.5), SpreadAngle = Vector2.new(20, 20), Size = NS({ KP(0, 0.18), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }), EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 1.5 })
	end

	-- SkitterPuff (hop, at the feet): frost dust and a ring.
	do
		local p = anchor("SkitterPuff", Vector3.new(3, 0.4, 3), root)
		puffE(p, "Dust", 5, PALEW, { 1.5, 4 }, R(0.5, 0.8), R(3, 6), { LightEmission = 0.3, EmissionDirection = Enum.NormalId.Top })
		ringE(p, "RingDark", SLATE, { 1.5, 8 }, R(0.35), 0, { ZOffset = 0.5 })
		ringE(p, "Ring", ICE, { 1.2, 7.5 }, R(0.3), 1, { ZOffset = 1 })
	end

	-- StaggerFlash (at the Core).
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, ICE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.08),
			Size = NS({ KP(0, 1.5), KP(0.4, 4), KP(1, 0) }), ZOffset = 3,
		})
		starE(p, "Star", ICE, 3, R(0.12))
	end

	-- Death (body-sized): it shatters: a white flash, ice shards bursting out, a
	-- frost mist, a core glint.
	do
		local p = anchor("Death", Vector3.new(6, 3, 7), root)
		chipsE(p, "Shards", 26, { 8, 22 }, 0.6, ICE).SpreadAngle = Vector2.new(70, 70)
		emitter(p, "Mist", {
			Texture = TEX.puff, Color = CS({ CK(0, PALEW), CK(1, DEEP) }), LightEmission = 0.3, Lifetime = R(0.9, 1.4), Rate = 14,
			Speed = R(1, 3), SpreadAngle = Vector2.new(30, 30), Drag = 1.5, Rotation = R(0, 360),
			Size = NS({ KP(0, 1.6), KP(1, 4.6) }), Transparency = NS({ KP(0, 0.4), KP(0.5, 0.6), KP(1, 1) }),
			Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		}, { EmitDuration = 0.8 })
		local core = attach(p, "Core")
		emitter(core, "Flash", {
			Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, ICE) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.3),
			Size = NS({ KP(0, 2), KP(0.3, 9), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2,
		}, { EmitCount = 1 })
		emitter(core, "Glint", {
			Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, ICE) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.5),
			Size = NS({ KP(0, 0), KP(0.3, 3), KP(1, 0) }), RotSpeed = R(60), ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
