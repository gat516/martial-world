--!nocheck
-- Builder for ReplicatedStorage.Effects.Dodge (not a technique, so no tiers and
-- no buildFromSpec). Load through the receiver, then build into staging:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/Dodge.luau")
--   require(m)  -- installs _G.buildDodgeFX(effectsFolder)
-- Runtime: CombatEffects.dashTrail / CombatEffects.perfectDodge.
--
-- Normal dodge, "a slip of qi": only a short pale-jade streak along the dash
-- path (two camera-facing Trails on the root), gone ~0.2 s after the dash
-- ends. No gust, no afterimages, nothing left behind.
--
-- Perfect dodge, "the blow cut only a shadow" (fires when the hit would have
-- landed):
--   Ghost (at the dash origin, where the blow lands): the code leaves a
--     gold-white afterimage of the body there; it holds solid ~0.12 s, then
--     swells slightly and dissolves (~0.55 s on screen). Here: a crisp white
--     4-point glint where the blow meets it, a soft gold flare, and gold qi
--     motes that lift off the dissolving body (aftermath, 0.5-0.8 s).
--   Streak: two Beams (white core, gold glow) from the ghost to the player,
--     thickening toward the player: the path you took, held 0.1 s then
--     thinned out by code (0.4 s).
--   Player: a bright glint and flare on the chest plus a few gold spark
--     streaks: "you, now". Code adds a gold Highlight rim and a short
--     desaturated time-slow grade.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local id = function(n)
	return "rbxassetid://" .. n
end

local JADE = Color3.fromRGB(120, 214, 230)
local JADE_CORE = Color3.fromRGB(236, 252, 255)
local GOLD = Color3.fromRGB(255, 212, 120)
local CORE = Color3.fromRGB(255, 248, 226)

local TEX = {
	streak = id(18244764764), -- soft tapered streak (fat end at the attachments)
	star4 = id(13271628051), -- crisp 4-point star
	glow = id(867619398), -- soft radial glow
	mote = id(8238126392), -- small soft dot
	spindle = id(7814053668), -- thin spark streak
}

local function anchor(name, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.CFrame = CFrame.new()
	p.Parent = parent
	return p
end

local function emitter(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	for k, v in props do
		e[k] = v
	end
	for k, v in attrs do
		e:SetAttribute(k, v)
	end
	e.Parent = parent
	return e
end

local function attach(parent, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

local function trail(parent, name, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Enabled = false
	t.FaceCamera = true
	t.LightInfluence = 0
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local function beam(parent, name, a0, a1, props)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.LightInfluence = 0
	b.Segments = 2
	for k, v in props do
		b[k] = v
	end
	b.Parent = parent
	return b
end

function _G.buildDodgeFX(effects)
	local old = effects:FindFirstChild("Dodge")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Dodge"

	-- Normal dodge: the streak. Code moves the attachments and trails into the
	-- HumanoidRootPart, enables the trails for the dash, then disables them.
	local streak = anchor("Streak", Vector3.new(0.2, 0.2, 0.2), root)
	local top = attach(streak, "StreakTop", Vector3.new(0, 0.8, 0))
	local bottom = attach(streak, "StreakBottom", Vector3.new(0, -0.6, 0))
	trail(streak, "Glow", top, bottom, {
		Texture = TEX.glow, -- soft across the width, tapered at both ends
		TextureMode = Enum.TextureMode.Stretch,
		Color = CS(JADE),
		LightEmission = 1,
		Lifetime = 0.2,
		MinLength = 0.05,
		Transparency = NS({ KP(0, 0), KP(0.5, 0.4), KP(1, 1) }),
		WidthScale = NS({ KP(0, 1), KP(1, 0.1) }),
	})
	trail(streak, "Core", top, bottom, {
		Color = CS(JADE_CORE),
		LightEmission = 0.8,
		Lifetime = 0.12,
		MinLength = 0.05,
		Transparency = NS({ KP(0, 0.05), KP(1, 1) }),
		WidthScale = NS({ KP(0, 0.3), KP(1, 0.05) }),
	})

	-- Perfect dodge
	local perfect = Instance.new("Model")
	perfect.Name = "Perfect"
	perfect.Parent = root

	-- Ghost: a body-sized box at the dash origin's root (code places it).
	local ghost = anchor("Ghost", Vector3.new(2.4, 4.6, 1.2), perfect)
	local chest = attach(ghost, "Chest", Vector3.new(0, 1, 0))
	emitter(chest, "Glint", {
		Texture = TEX.star4,
		Color = CS(Color3.new(1, 1, 1)),
		LightEmission = 1,
		Speed = R(0),
		Size = NS({ KP(0, 1.5), KP(0.25, 5.5), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(0.6, 0.1), KP(1, 1) }),
		Lifetime = R(0.26),
		Rotation = R(0, 45),
		ZOffset = 2,
	}, { EmitCount = 1 })
	emitter(chest, "Flare", {
		Texture = TEX.glow,
		Color = CS(GOLD),
		LightEmission = 0.8,
		Speed = R(0),
		Size = NS({ KP(0, 3), KP(0.3, 4.5), KP(1, 5) }),
		Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
		Lifetime = R(0.4),
		ZOffset = 1,
	}, { EmitCount = 1 })
	emitter(ghost, "Motes", {
		Texture = TEX.mote,
		Color = CS(GOLD, CORE),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Speed = R(2, 5),
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 2,
		Size = NS({ KP(0, 0.6), KP(0.4, 0.5), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(0.7, 0.1), KP(1, 1) }),
		Lifetime = R(0.5, 0.8),
		ZOffset = 1,
	}, { EmitCount = 18, EmitDelay = 0.1 })

	-- Player: placed at the live root when the perfect dodge lands.
	local player = anchor("Player", Vector3.new(0.4, 0.4, 0.4), perfect)
	emitter(player, "Glint", {
		Texture = TEX.star4,
		Color = CS(CORE),
		LightEmission = 1,
		Speed = R(0),
		Size = NS({ KP(0, 1.5), KP(0.2, 6), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(0.6, 0.1), KP(1, 1) }),
		Lifetime = R(0.24),
		Rotation = R(0),
		ZOffset = 3,
	}, { EmitCount = 1 })
	emitter(player, "Flare", {
		Texture = TEX.glow,
		Color = CS(GOLD),
		LightEmission = 0.7,
		Speed = R(0),
		Size = NS({ KP(0, 2), KP(0.25, 4), KP(1, 4.5) }),
		Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
		Lifetime = R(0.32),
		ZOffset = 2,
	}, { EmitCount = 1 })
	emitter(player, "Sparks", {
		Texture = TEX.spindle,
		Color = CS(CORE, GOLD),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(180, 180),
		Speed = R(18, 28),
		Drag = 6,
		Size = NS({ KP(0, 0.5), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(1, 0.6) }),
		Lifetime = R(0.18, 0.3),
		ZOffset = 2,
	}, { EmitCount = 10 })

	-- Streak: from the ghost to the player (code sets the two attachments'
	-- WorldPositions and thins the widths out).
	local path = anchor("Streak", Vector3.new(0.2, 0.2, 0.2), perfect)
	local from = attach(path, "From", Vector3.zero)
	local to = attach(path, "To", Vector3.new(0, 0, -6))
	-- Attachment0 is the player end: the texture's fat end sits at U = 0
	beam(path, "Glow", to, from, {
		Color = CS(GOLD),
		LightEmission = 0.7,
		Width0 = 1.8,
		Width1 = 0.3,
		Transparency = NS({ KP(0, 0.3), KP(0.4, 0.35), KP(1, 0.7) }),
		Texture = TEX.streak,
		TextureMode = Enum.TextureMode.Stretch,
		TextureLength = 1,
	})
	beam(path, "Core", from, to, {
		Color = CS(CORE),
		LightEmission = 1,
		Width0 = 0.15,
		Width1 = 0.7,
		Transparency = NS({ KP(0, 0.5), KP(1, 0) }),
	})

	root.Parent = effects
	return root
end

return "buildDodgeFX installed"
