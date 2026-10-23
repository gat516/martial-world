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
-- landed). Intent: the blow lands where you were and finds only afterimages;
-- you are already gone. Feel: slick, untouchable, a reward. Job: confirm the
-- perfect dodge (and its cooldown refund). Hero: a trail of 3-5 gold Neon
-- afterimages along the dash, drawn by code (CombatEffects.perfectDodge) from
-- poses sampled during the dash; the one at the start is solid and lingers
-- longest, each one nearer the player starts fainter and fades sooner.
-- Beats (t = the "perfect" event, when the blow lands):
--   0 ms     the start ghost's glint (the blade meeting nothing), ghosts up
--   30 ms    the push-off ring at the start ghost's feet; wisps of cut air
--   60 ms    "you, now": a smaller glint and a few sparks on the player
--   100-900  gold motes lift off the start ghost as it dissolves
--   ~650 ms  the last ghost gone
-- Layers here:
--   Ghost (at the dash origin, code places it): Glint (4-point twinkle
--     flipbook, white), Wisps (curling wind flipbook, the air the blow cut),
--     Ring (soft thin ring flat at the feet, the push-off), Motes (gold, lift
--     off the dissolving ghost).
--   Player: a small 4-point glint and a few gold spark streaks.
-- (The old gold Beam streak from the ghost to the player was cut: the
-- afterimage trail draws the path now.)
-- Code adds the afterimages, a gold Highlight rim and a short desaturated
-- time-slow grade, and turns the rest of the dash streak gold.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local id = function(n)
	return "rbxassetid://" .. n
end

local JADE = Color3.fromRGB(120, 214, 230)
local JADE_CORE = Color3.fromRGB(236, 252, 255)
local GOLD = Color3.fromRGB(255, 212, 120)
local CORE = Color3.fromRGB(255, 248, 226)

local TEX = {
	star4 = id(13271628051), -- crisp 4-point star
	glow = id(867619398), -- soft radial glow
	mote = id(8238126392), -- small soft dot
	twinkle = id(102648375149008), -- 4-point star twinkle flipbook (4x4, 9 frames)
	wisps = id(12094495797), -- curling wind wisps flipbook (4x4)
	ringSoft = id(72490407109476), -- soft thin ring
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
		Texture = TEX.twinkle,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = CS(Color3.new(1, 1, 1)),
		LightEmission = 1,
		Brightness = 1.5,
		Speed = R(0),
		Size = NS({ KP(0, 3), KP(1, 3.4) }),
		Transparency = NS(0),
		Lifetime = R(0.42), -- 9 of 16 frames drawn: ~0.24 s on screen
		Rotation = R(-15, 15),
		ZOffset = 3,
	}, { EmitCount = 1 })
	emitter(chest, "Wisps", {
		Texture = TEX.wisps,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = CS(CORE, GOLD),
		LightEmission = 0.8,
		Speed = R(0),
		Size = NS({ KP(0, 2.6), KP(1, 3.4) }),
		Transparency = NS({ KP(0, 0.15), KP(0.7, 0.3), KP(1, 1) }),
		Lifetime = R(0.45),
		Rotation = R(0, 360),
		ZOffset = 1,
	}, { EmitCount = 2, EmitDelay = 0.03 })
	local feet = attach(ghost, "Feet", Vector3.new(0, -2.65, 0))
	emitter(feet, "Ring", {
		Texture = TEX.ringSoft,
		Color = CS(CORE, GOLD),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Speed = R(0.01),
		Size = NS({ KP(0, 0.6), KP(0.3, 3.4), KP(1, 4.4) }),
		Transparency = NS({ KP(0, 0.25), KP(0.5, 0.55), KP(1, 1) }),
		Lifetime = R(0.4),
		ZOffset = 0,
	}, { EmitCount = 1, EmitDelay = 0.03 })
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
		Size = NS({ KP(0, 0.5), KP(0.4, 0.4), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(0.7, 0.1), KP(1, 1) }),
		Lifetime = R(0.5, 0.8),
		ZOffset = 1,
	}, { EmitCount = 12, EmitDelay = 0.12 })

	-- Player: placed at the live root when the perfect dodge lands.
	local player = anchor("Player", Vector3.new(0.4, 0.4, 0.4), perfect)
	emitter(player, "Glint", {
		Texture = TEX.star4,
		Color = CS(CORE),
		LightEmission = 1,
		Speed = R(0),
		Size = NS({ KP(0, 1), KP(0.25, 3.4), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(0.6, 0.15), KP(1, 1) }),
		Lifetime = R(0.22),
		Rotation = R(0),
		ZOffset = 3,
	}, { EmitCount = 1, EmitDelay = 0.06 })
	emitter(player, "Sparks", {
		Texture = TEX.spindle,
		Color = CS(CORE, GOLD),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(180, 180),
		Speed = R(16, 24),
		Drag = 6,
		Size = NS({ KP(0, 0.45), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(1, 0.6) }),
		Lifetime = R(0.16, 0.26),
		ZOffset = 2,
	}, { EmitCount = 6, EmitDelay = 0.06 })

	root.Parent = effects
	return root
end

return "buildDodgeFX installed"
