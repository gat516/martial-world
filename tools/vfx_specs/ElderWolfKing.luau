--!nocheck
-- Builder for ReplicatedStorage.Effects.ElderWolfKing: the Elder Wolf King's
-- own attack, hit, phase, roar, aura and death effects (boss tier; the wolf
-- and boar templates are no longer used by it). Load through the receiver,
-- then build into staging:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/ElderWolfKing.luau")
--   require(m)  -- installs _G.buildElderWolfKingFX(effectsFolder)
-- Runtime: src/client/EnemyFX/ElderWolfKing.luau (cue -> template, placement).
--
-- Identity: moon-silver qi on ink-slate, gold for every warning tell (so a
-- gold flare always means "react"), pale spirit-cyan for the spirit
-- flourishes, a little jade only on the collar seal. No crown or halo motif.
-- The runtime never clones the King's body (no ghost/afterimage copies).
-- Every template is an invisible anchored Part (centre = pivot, -Z = facing
-- or blow direction). Ground templates have their centre on the floor.
-- `AuthoredSeconds` (windup holds) and `AuthoredRadius` (ground shapes) tell
-- the runtime how to refit and scale them. Heavy bursts are one-shot and
-- short; the aura is rate-based and light (`BaseRate` attribute = authored
-- rate, scaled by health in code).
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local MOON = Color3.fromRGB(226, 236, 250)
local SPIRIT = Color3.fromRGB(150, 200, 238)
local GOLD = Color3.fromRGB(255, 190, 70)
local HOT = Color3.fromRGB(255, 236, 176)
local EMBER = Color3.fromRGB(255, 130, 48)
local INK = Color3.fromRGB(16, 18, 26)
local SLATE = Color3.fromRGB(37, 44, 58)
local DUST = Color3.fromRGB(150, 152, 156)

local TEX = {
	glint = id(84223532517124),
	dot = id(9841273544),
	mote = id(8238126392),
	ringThin = id(9841273159),
	ringThick = id(13322173171),
	ringSpiky = id(13052243772),
	ringDust = id(13052235894),
	arc = id(13366366767),
	arcSoft = id(1266209505),
	claw = id(11636552631),
	line = id(7886908733),
	streaks = id(5699911427),
	streak = id(18244764764),
	crackHole = id(85474069372331),
	crackDark = id(86726095803553),
	crackLines = id(7994630128),
	crackGlow = id(8172249266),
	mandala = id(107304921648525),
	sigil = id(16878097832),
	puff = id(14050360239),
	wisp = id(15753663130),
	flame = id(13280154167),
	flameBurst = id(250186345),
	chips = id(425665059),
	rock = id(626588936),
	ink = id(16132530029),
	swirl = id(10352554571),
}

local FLAT = {
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
	Speed = R(0.01),
}
local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
end

local function part(root, name, size, attrs)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new()
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = root
	return p
end

local function att(parent, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	a.Parent = parent
	return a
end

local function em(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	for k, v in props do
		e[k] = v
	end
	-- Sizes below are authored as diameters (the width a ring covers); a
	-- particle's Size is a half-width, so halve them once here.
	local half = {}
	for _, key in e.Size.Keypoints do
		table.insert(half, KP(key.Time, key.Value / 2, key.Envelope / 2))
	end
	e.Size = NS(half)
	for k, v in attrs or { EmitCount = 1 } do
		e:SetAttribute(k, v)
	end
	if e.Rate > 0 then
		e:SetAttribute("BaseRate", e.Rate)
	end
	e.Parent = parent
	return e
end

local function trail(parent, name, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Enabled = false
	t.LightInfluence = 0
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local fade = NS({ KP(0, 0), KP(0.55, 0.12), KP(1, 1) })
local pop = NS({ KP(0, 0), KP(1, 1) })
local function hold(inT, outT)
	return NS({ KP(0, 1), KP(inT, 0.15), KP(outT, 0.15), KP(1, 1) })
end
local function grow(a, b, c)
	if c then
		return NS({ KP(0, a), KP(0.5, b), KP(1, c) })
	end
	return NS({ KP(0, a), KP(1, b) })
end

-- dark base, rim and white-hot core of one shape (the reference's recipe)
local function stack(parent, name, base, size, rimColor, coreColor, darkColor)
	em(parent, name .. "Dark", with(base, {
		Color = CS(darkColor or SLATE),
		Size = size(1.15),
		Transparency = NS({ KP(0, 0.2), KP(0.6, 0.35), KP(1, 1) }),
		ZOffset = 0.5,
	}))
	em(parent, name .. "Rim", with(base, {
		Color = CS(rimColor or GOLD),
		LightEmission = 0.8,
		Size = size(1.0),
		Transparency = NS({ KP(0, 0.1), KP(0.6, 0.25), KP(1, 1) }),
		ZOffset = 1,
	}))
	em(parent, name .. "Core", with(base, {
		Color = CS({ CK(0, WHITE), CK(1, coreColor or HOT) }),
		LightEmission = 1,
		Brightness = 3,
		Size = size(0.82),
		Transparency = fade,
		ZOffset = 1.5,
	}))
end
local function scaled(a, b, c)
	return function(k)
		return grow(a * k, b * k, c and c * k)
	end
end

-- a screen shake through the plugin's ScreenEffects (its own attachment)
local function shake(parent, csv)
	local a = att(parent, "Shake")
	a:SetAttribute("CameraShake", csv)
end

function _G.buildElderWolfKingFX(effects)
	local old = effects:FindFirstChild("ElderWolfKing")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ElderWolfKing"

	-- BrowFlare: on each eye at every windup. A gold star pop, a held glow,
	-- a thin gold needle rising off the eye. Reads the instant a move starts.
	do
		local p = part(root, "BrowFlare", nil, { AuthoredSeconds = 0.6 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.4, HOT), CK(1, GOLD) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.2), Size = grow(0.4, 2.6, 0), Rotation = R(-8, 8), ZOffset = 2 })
		em(p, "Pop", { Texture = TEX.dot, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.26), Size = grow(1.2, 0), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.5 })
		em(p, "Hold", { Texture = TEX.dot, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.12, 0.2), Rate = 20, Size = grow(0.7, 0.4), Transparency = NS({ KP(0, 0.3), KP(1, 0.85) }), LockedToPart = true, ZOffset = 1.5 }, { EmitDuration = 0.6 })
		em(p, "Needle", { Texture = TEX.line, Color = CS(HOT), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, Speed = R(5, 8), Lifetime = R(0.25), Size = grow(2.2, 0.2), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 2 })
	end

	-- BiteTell (windup 0.90, at the Mouth): the jaws' breath is drawn in as
	-- gold motes, two rings close on the maw, a glow swells over an ink base,
	-- and a fang glint flashes top and bottom just before the snap.
	do
		local p = part(root, "BiteTell", Vector3.new(7, 7, 7), { AuthoredSeconds = 0.9 })
		em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, GOLD), CK(1, HOT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 40, Lifetime = R(0.3, 0.45), Speed = R(14, 20), Size = grow(0.55, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 0.9 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(7, 0.6), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(HOT), LightEmission = 1, Lifetime = R(0.5), Size = grow(5, 0.3), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.4) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 0.4 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(0.9), Size = grow(0.6, 3.4), Transparency = NS({ KP(0, 0.7), KP(0.8, 0.35), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, GOLD), CK(1, HOT) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.9), Size = grow(0.3, 2.2), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1.5 })
		local top = att(p, "Top", Vector3.new(0, 1.8, 0))
		local bot = att(p, "Bottom", Vector3.new(0, -1.8, 0))
		for _, a in { top, bot } do
			em(a, "Fang", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.28), Size = grow(0.3, 3, 0), Rotation = R(a == top and 0 or 90), ZOffset = 2, LockedToPart = true }, { EmitDelay = 0.62 })
		end
		em(p, "Mist", { Texture = TEX.puff, Color = CS(MOON), Rate = 14, Speed = R(3, 6), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Lifetime = R(0.6, 0.9), Size = grow(0.8, 2.6), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 0.9 })
	end

	-- BiteSnap (contact, at the Mouth): upper and lower fang crescents slam
	-- shut, white flash and star, spiky ring, spray, ink, embers and smoke.
	do
		local p = part(root, "BiteSnap", Vector3.new(0.4, 0.4, 0.4))
		local upper = att(p, "Upper", Vector3.new(0, 2.4, 0))
		local lower = att(p, "Lower", Vector3.new(0, -2.4, 0))
		local crescent = { Texture = TEX.arc, Lifetime = R(0.2), Drag = 8, Speed = R(30) }
		stack(upper, "Upper", with(crescent, { Rotation = R(0), EmissionDirection = Enum.NormalId.Bottom }), scaled(4.5, 6.5))
		stack(lower, "Lower", with(crescent, { Rotation = R(180), EmissionDirection = Enum.NormalId.Top }), scaled(4.5, 6.5))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.14), Size = grow(5, 12), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.26), Size = grow(1, 11, 0), ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(2, 16), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 2 })
		em(p, "Rays", { Texture = TEX.line, Color = CS(HOT), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(40, 65), Lifetime = R(0.2, 0.3), Size = grow(5, 1), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 14 })
		em(p, "Ink", { Texture = TEX.ink, Color = CS(SLATE), Lifetime = R(0.4), Size = grow(5, 9), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		em(p, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, EMBER) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(60, 60), Speed = R(8, 22), Acceleration = Vector3.new(0, -14, 0), Lifetime = R(0.7, 1.4), Size = grow(0.35, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 14 })
		em(p, "Smoke", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(50, 50), Speed = R(6, 12), Drag = 3, Lifetime = R(0.8, 1.3), Size = grow(2.4, 7), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 7 })
		shake(p, "Custom,25~95,0.9,0.35,18,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- SwipeTell (left paw, windup 0.45): the shortest tell, so it is the
	-- loudest at its start: a big gold star on the paw the moment the move
	-- begins, three claw streaks drawn above it, a ring closing on the paw.
	do
		local p = part(root, "SwipeTell", nil, { AuthoredSeconds = 0.45 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.5, HOT), CK(1, GOLD) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.3), Size = grow(0.6, 5.5, 0), Rotation = R(-10, 10), ZOffset = 3 })
		em(p, "Claws", { Texture = TEX.claw, Color = CS(GOLD), LightEmission = 1, Brightness = 2, Rotation = R(-35), Lifetime = R(0.45), Size = grow(2.2, 4), Transparency = NS({ KP(0, 1), KP(0.15, 0.1), KP(0.85, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 2 })
		em(p, "ClawsDark", { Texture = TEX.claw, Color = CS(INK), Rotation = R(-35), Lifetime = R(0.45), Size = grow(2.6, 4.6), Transparency = NS({ KP(0, 1), KP(0.15, 0.4), KP(0.85, 0.5), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.45), Size = grow(6, 0.6), Transparency = NS({ KP(0, 1), KP(0.1, 0.2), KP(0.9, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, Rate = 36, SpreadAngle = Vector2.new(180, 180), Speed = R(2, 7), Lifetime = R(0.2, 0.35), Size = grow(0.3, 0), LockedToPart = true }, { EmitDuration = 0.45 })
	end

	-- SwipeSlash (contact, at the left paw, facing-aligned): a wide claw arc
	-- sweeping across the cone (three crescents of descending size), three
	-- claw streaks, wind lines, sparks and a slate smear.
	do
		local p = part(root, "SwipeSlash", Vector3.new(0.4, 0.4, 0.4))
		local sweep = att(p, "Sweep")
		local arc = { Texture = TEX.arc, Lifetime = R(0.22), EmissionDirection = Enum.NormalId.Right, Speed = R(46), Drag = 7, Rotation = R(-25) }
		stack(sweep, "Arc", arc, scaled(7, 11, 12), GOLD, HOT)
		em(sweep, "Echo", { Texture = TEX.arcSoft, Color = CS(MOON), LightEmission = 1, EmissionDirection = Enum.NormalId.Right, Speed = R(36), Drag = 6, Rotation = R(-25), Lifetime = R(0.3), Size = grow(9, 15), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.8 }, { EmitDelay = 0.04 })
		em(sweep, "Claws", { Texture = TEX.claw, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Right, Speed = R(30), Drag = 5, Rotation = R(-40), Lifetime = R(0.2), Size = grow(7, 10), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }), ZOffset = 2 })
		em(sweep, "Wind", { Texture = TEX.streaks, Color = CS(MOON), LightEmission = 0.6, EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(8, 25), Speed = R(50, 70), Lifetime = R(0.25, 0.35), Size = grow(5, 4), Rotation = R(90), Transparency = NS({ KP(0, 0.3), KP(1, 1) }) }, { EmitCount = 6 })
		em(sweep, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, GOLD) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(35, 35), Speed = R(20, 40), Acceleration = Vector3.new(0, -20, 0), Lifetime = R(0.3, 0.6), Size = grow(0.35, 0) }, { EmitCount = 14 })
		em(sweep, "Smear", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Right, Speed = R(8, 14), Drag = 4, Lifetime = R(0.5, 0.8), Size = grow(2, 5), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = grow(3, 7), Transparency = pop })
	end

	-- ClawRaise (right paw, 55% through the 0.55 windup): the lifted claw
	-- glints, three gold streaks stand over it.
	do
		local p = part(root, "ClawRaise", nil, { AuthoredSeconds = 0.25 })
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.5, HOT), CK(1, GOLD) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.28), Size = grow(0.6, 6, 0), ZOffset = 3 })
		em(p, "Claws", { Texture = TEX.claw, Color = CS(GOLD), LightEmission = 1, Brightness = 2, Rotation = R(0), Lifetime = R(0.3), Size = grow(2.5, 4.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(0.8, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 2 })
		em(p, "ClawsDark", { Texture = TEX.claw, Color = CS(INK), Lifetime = R(0.3), Size = grow(3, 5), Transparency = NS({ KP(0, 1), KP(0.2, 0.4), KP(0.8, 0.5), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Rise", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, Rate = 40, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(5, 10), Lifetime = R(0.25, 0.4), Size = grow(0.3, 0), LockedToPart = false }, { EmitDuration = 0.25 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.28), Size = grow(5, 0.5), Transparency = NS({ KP(0, 0.7), KP(1, 0.1) }), LockedToPart = true })
	end

	-- ClawStrike (contact, centre of the locked circle, authored r4.5): three
	-- claws fall, the ground splits with a lit crack, a ring and dust punch
	-- out, rock chips jump, embers linger.
	do
		local p = part(root, "ClawStrike", Vector3.new(9, 0.2, 9), { AuthoredRadius = 4.5 })
		local high = att(p, "High", Vector3.new(0, 7, 0))
		em(high, "RakeDark", { Texture = TEX.claw, Color = CS(INK), EmissionDirection = Enum.NormalId.Bottom, Speed = R(55), Lifetime = R(0.13), Size = grow(8, 9), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 })
		em(high, "RakeCore", { Texture = TEX.claw, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Brightness = 3, EmissionDirection = Enum.NormalId.Bottom, Speed = R(55), Lifetime = R(0.13), Size = grow(6.5, 8), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 2 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		em(g, "CrackDark", with(FLAT, { Texture = TEX.crackHole, Color = CS(INK), Lifetime = R(3.5), Size = grow(5, 10, 10.5), Transparency = NS({ KP(0, 0.1), KP(0.1, 0.1), KP(0.7, 0.3), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, GOLD), CK(1, EMBER) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = grow(6, 10.5), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 14), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.45), Size = grow(2, 13), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(10, 18), Drag = 4, Lifetime = R(0.7, 1.1), Size = grow(2, 5.5), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 10 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(16, 30), Acceleration = Vector3.new(0, -70, 0), Lifetime = R(0.6, 0.9), Size = grow(0.9, 0.7), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 9 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(5, 10), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.24), Size = grow(1, 8, 0), ZOffset = 3 })
		em(g, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, EMBER) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(3, 12), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(1, 1.8), Size = grow(0.3, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 10 })
		shake(p, "Custom,25~90,1.4,0.5,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- Marker (slam windup, centred on the locked circle; authored r13 and the
	-- 1.25 s windup, refit by code): the radius drawn in gold over the stock
	-- fill: boundary ring, ink under it, a disc that fills toward contact, a
	-- turning formation array, a ring closing from outside, edge sparks.
	do
		local p = part(root, "Marker", Vector3.new(26, 0.2, 26), { AuthoredSeconds = 1.25, AuthoredRadius = 13 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		local life = R(1.25)
		em(g, "EdgeDark", with(FLAT, { Texture = TEX.ringThick, Color = CS(INK), Lifetime = life, Size = grow(27.5, 27.5), Transparency = NS({ KP(0, 1), KP(0.08, 0.35), KP(0.92, 0.35), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Edge", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, GOLD), CK(0.8, GOLD), CK(1, WHITE) }), LightEmission = 1, Brightness = 2, Lifetime = life, Size = grow(26, 26), Transparency = NS({ KP(0, 1), KP(0.08, 0.1), KP(0.7, 0.2), KP(0.85, 0), KP(0.92, 0.3), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Fill", with(FLAT, { Texture = TEX.dot, Color = CS(GOLD), LightEmission = 0.8, Lifetime = life, Size = grow(1, 25), Transparency = NS({ KP(0, 0.8), KP(1, 0.55) }), ZOffset = 0.5 }))
		em(g, "Array", with(FLAT, { Texture = TEX.mandala, Color = CS(HOT), LightEmission = 1, Lifetime = life, Size = grow(22, 22), RotSpeed = R(35), Rotation = R(0), Transparency = NS({ KP(0, 1), KP(0.1, 0.55), KP(0.85, 0.5), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Closing", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = life, Size = grow(44, 26), Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1.4 }))
		em(p, "EdgeSparks", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(3, 9), Rate = 36, Lifetime = R(0.4, 0.7), Size = grow(0.45, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 1.25 })
	end

	-- SlamTell (Crownfall windup, chest, 1.25 s): the body gathers: motes
	-- drawn inward, a spirit glow swelling over ink, mane flames licking up,
	-- two rings closing, embers rising.
	do
		local p = part(root, "SlamTell", Vector3.new(13, 13, 13), { AuthoredSeconds = 1.25 })
		em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, SPIRIT), CK(1, WHITE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 44, Lifetime = R(0.4, 0.6), Speed = R(14, 22), Size = grow(0.7, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 1.25 })
		em(p, "Pull", { Texture = TEX.line, Color = CS(MOON), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 18, Lifetime = R(0.3, 0.45), Speed = R(26, 34), Size = grow(3.5, 0.5), Transparency = NS({ KP(0, 1), KP(0.3, 0.2), KP(1, 0.8) }) }, { EmitDuration = 1.1, EmitDelay = 0.15 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.25), Size = grow(1, 11), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.45), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, SPIRIT), CK(1, WHITE) }), LightEmission = 1, Brightness = 3, Lifetime = R(1.25), Size = grow(0.5, 7), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Flames", { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Rate = 14, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(5, 9), Lifetime = R(0.5, 0.8), Size = grow(2.4, 0.8), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), Rotation = R(-15, 15) }, { EmitDuration = 1.2, EmitDelay = 0.2 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS(GOLD), LightEmission = 1, Lifetime = R(1.0), Size = grow(16, 1.5), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.9, 0), KP(1, 1) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.2 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.6), Size = grow(11, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.3) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 0.65 })
	end

	-- RushCharge (King's Rush windup, chest, 1.00 s): the same gather made
	-- longer and lower: motes and speed lines pulled in, a swelling core and
	-- two closing rings, so the rush reads different from the slam.
	do
		local p = part(root, "RushCharge", Vector3.new(11, 11, 11), { AuthoredSeconds = 1.0 })
		em(p, "Pull", { Texture = TEX.line, Color = CS(MOON), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 26, Lifetime = R(0.28, 0.4), Speed = R(28, 40), Size = grow(4, 0.5), Transparency = NS({ KP(0, 1), KP(0.3, 0.1), KP(1, 0.7) }) }, { EmitDuration = 1.0 })
		em(p, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, GOLD), CK(1, HOT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 26, Lifetime = R(0.3, 0.5), Speed = R(14, 20), Size = grow(0.5, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }) }, { EmitDuration = 1.0 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.0), Size = grow(1, 8), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.5), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, GOLD), CK(1, HOT) }), LightEmission = 1, Brightness = 3, Lifetime = R(1.0), Size = grow(0.5, 5), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.15), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.7), Size = grow(13, 1), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(1, 0.1) }), LockedToPart = true, ZOffset = 1 }, { EmitDelay = 0.1 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.45), Size = grow(9, 0.8), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.3) }), LockedToPart = true, ZOffset = 1.2 }, { EmitDelay = 0.5 })
	end

	-- GroundArray (rush windup and pack call, on the floor under the King,
	-- authored r7): a formation array turning on an ink disc, a closing ring
	-- and rising motes at its edge. Rush uses it gold, the call spirit-cyan.
	do
		local p = part(root, "GroundArray", Vector3.new(14, 0.2, 14), { AuthoredSeconds = 1.0, AuthoredRadius = 7 })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		local life = R(1.0)
		em(g, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = life, Size = grow(2, 14), Transparency = NS({ KP(0, 1), KP(0.15, 0.4), KP(0.9, 0.5), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Array", with(FLAT, { Texture = TEX.sigil, Color = CS(GOLD), LightEmission = 1, Brightness = 2, Lifetime = life, Size = grow(12, 14), RotSpeed = R(70), Rotation = R(0), Transparency = NS({ KP(0, 1), KP(0.12, 0.15), KP(0.85, 0.2), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(HOT), LightEmission = 1, Lifetime = life, Size = grow(9, 9), RotSpeed = R(-60), Transparency = NS({ KP(0, 1), KP(0.12, 0.5), KP(0.85, 0.5), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Closing", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = life, Size = grow(20, 8), Transparency = NS({ KP(0, 1), KP(0.1, 0.1), KP(0.95, 0), KP(1, 1) }), ZOffset = 1 }))
		em(p, "Motes", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, Speed = R(3, 8), Rate = 26, Lifetime = R(0.5, 0.9), Size = grow(0.4, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 1.0 })
	end

	-- RushLaunch (take-off, floor between the hind paws, facing the dash): a
	-- ring and a blast of dust behind, a fan of speed lines forward, flash.
	do
		local p = part(root, "RushLaunch", Vector3.new(4, 0.2, 2), { })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Lifetime = R(0.35), Size = grow(2, 20), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }))
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.5), Size = grow(2, 18), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Blast", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(35, 25), Speed = R(18, 32), Drag = 3, Lifetime = R(0.7, 1.1), Size = grow(2.5, 8), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 12 })
		em(g, "Lines", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(20, 14), Speed = R(60, 90), Lifetime = R(0.18, 0.3), Size = grow(8, 2), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 16 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(50, 40), Speed = R(14, 28), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.5, 0.8), Size = grow(0.8, 0.5), RotSpeed = R(-300, 300) }, { EmitCount = 8 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.14), Size = grow(5, 12), Transparency = pop, ZOffset = 3 })
		shake(p, "Custom,25~85,0.8,0.4,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- RushTrail (the dash, follows the chest): an ink band and a moon-white
	-- band trailing the body, wind lines shed backward, a spirit glow,
	-- flame wisps and floor dust from the `Wake` attachment (code drops it to
	-- the floor).
	do
		local p = part(root, "RushTrail", Vector3.new(2, 2, 2))
		local top = att(p, "Top", Vector3.new(0, 4.2, 0))
		local mid = att(p, "Mid", Vector3.new(0, 1.2, 0))
		local bottom = att(p, "Bottom", Vector3.new(0, -3.4, 0))
		local wake = att(p, "Wake", Vector3.new(0, -6, 0))
		trail(p, "Dark", top, bottom, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS(INK), Lifetime = 0.35, MinLength = 0.05, Transparency = NS({ KP(0, 0.25), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.3) }) })
		trail(p, "Bright", top, mid, { Texture = TEX.streak, TextureMode = Enum.TextureMode.Stretch, Color = CS({ CK(0, WHITE), CK(0.4, MOON), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, Lifetime = 0.35, MinLength = 0.05, Transparency = NS({ KP(0, 0), KP(0.6, 0.35), KP(1, 1) }), WidthScale = NS({ KP(0, 1), KP(1, 0.2) }) })
		em(p, "Wind", { Texture = TEX.line, Color = CS(WHITE), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, Rate = 30, Speed = R(25, 40), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(15, 15), Lifetime = R(0.18, 0.28), Size = grow(7, 1), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) }, { EmitDuration = 0.6 })
		em(p, "Aura", { Texture = TEX.dot, Color = CS(SPIRIT), LightEmission = 1, Rate = 16, Lifetime = R(0.3, 0.4), Size = grow(8, 3), Transparency = NS({ KP(0, 0.65), KP(1, 1) }), ZOffset = 0.5 }, { EmitDuration = 0.6 })
		em(p, "Flames", { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Rate = 14, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 12), Lifetime = R(0.3, 0.5), Size = grow(3, 0.8), Transparency = NS({ KP(0, 0.3), KP(1, 1) }) }, { EmitDuration = 0.6 })
		em(wake, "Dust", { Texture = TEX.puff, Color = CS(DUST), Rate = 22, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(50, 40), Speed = R(6, 14), Drag = 3, Lifetime = R(0.6, 1.0), Size = grow(2, 6), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 0.6 })
		em(wake, "Grit", { Texture = TEX.mote, Color = CS(SLATE), Rate = 16, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(40, 30), Speed = R(10, 18), Acceleration = Vector3.new(0, -40, 0), Lifetime = R(0.3, 0.5), Size = NS(0.25) }, { EmitDuration = 0.6 })
	end

	-- RushSkid (the stop, floor between the forepaws): dust thrown ahead, a
	-- flat ring, grit and sparks.
	do
		local p = part(root, "RushSkid", Vector3.new(4, 0.2, 2))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS(MOON), LightEmission = 1, Lifetime = R(0.35), Size = grow(2, 15), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 }))
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 20), Speed = R(14, 26), Drag = 4, Lifetime = R(0.7, 1.1), Size = grow(2.5, 8), Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 10 })
		em(g, "Grit", { Texture = TEX.mote, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 25), Speed = R(14, 26), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.35, 0.5), Size = NS(0.3) }, { EmitCount = 12 })
		em(g, "Sparks", { Texture = TEX.dot, Color = CS(HOT), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(50, 40), Speed = R(14, 30), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.3, 0.6), Size = grow(0.3, 0) }, { EmitCount = 10 })
	end

	-- SlamImpact (Crownfall contact, centre of the locked circle, authored
	-- r13): the loudest ground effect in the fight. White flash and star,
	-- three rings (thick, spiky, thin), a dust wall, rock chunks and chips,
	-- light rays, a lit crack under a scorch that stays several seconds and
	-- fades, Craters rocks, embers and settling smoke, a ScreenEffects quake.
	do
		local p = part(root, "SlamImpact", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		-- the scorch: a long-lived dark decal that fades
		em(g, "ScorchInk", with(FLAT, { Texture = TEX.ink, Color = CS(INK), Lifetime = R(6), Size = grow(8, 20, 21), Transparency = NS({ KP(0, 0.25), KP(0.6, 0.35), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.1 }))
		em(g, "ScorchCracks", with(FLAT, { Texture = TEX.crackDark, Color = CS(INK), Lifetime = R(6), Size = grow(14, 25, 26), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.2 }))
		em(g, "CrackLines", with(FLAT, { Texture = TEX.crackLines, Color = CS(SLATE), Lifetime = R(6), Size = grow(10, 28, 29), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.3 }))
		em(g, "CrackLit", with(FLAT, { Texture = TEX.crackGlow, Color = CS({ CK(0, WHITE), CK(0.3, GOLD), CK(1, EMBER) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.6), Size = grow(12, 24), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.4), Size = grow(1, 30), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "RingSpiky", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.55), Size = grow(2, 32), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }))
		em(g, "RingThin", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.8), Size = grow(2, 40), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.8 }), { EmitDelay = 0.08 })
		em(g, "DustRing", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.6), Size = grow(3, 30), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		em(g, "Wall", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(24, 40), Drag = 4, Lifetime = R(0.9, 1.4), Size = grow(3, 9), Transparency = NS({ KP(0, 0.35), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 26 })
		em(g, "Chips", { Texture = TEX.chips, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(28, 55), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.8, 1.3), Size = grow(1.3, 1), RotSpeed = R(-400, 400), Rotation = R(0, 360) }, { EmitCount = 18 })
		em(g, "Chunks", { Texture = TEX.rock, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(55, 55), Speed = R(22, 44), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.8, 1.2), Size = grow(1.5, 1.2), RotSpeed = R(-300, 300), Rotation = R(0, 360) }, { EmitCount = 8 })
		em(g, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(22, 22), Speed = R(60, 100), Lifetime = R(0.3, 0.5), Size = grow(12, 3), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 16 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.16), Size = grow(10, 26), Transparency = pop, ZOffset = 3 })
		em(g, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.3), Size = grow(2, 18, 0), ZOffset = 3 })
		em(g, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, EMBER) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(75, 75), Speed = R(4, 18), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(1.5, 3), Size = grow(0.4, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }) }, { EmitCount = 22 })
		em(g, "Smoke", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80), Speed = R(2, 7), Drag = 1.5, Lifetime = R(2, 3.2), Size = grow(4, 12), Transparency = NS({ KP(0, 0.55), KP(1, 1) }), Rotation = R(0, 360), RotSpeed = R(-20, 20) }, { EmitCount = 10, EmitDelay = 0.1 })
		-- Craters add-on: rocks erupt in a ring with the wave
		local rocks = att(p, "Rocks", Vector3.new(0, 0.5, 0))
		rocks:AddTag("CraterVFX")
		for k, v in {
			Shape = "Ring", Fill = true, EmissionStart = "Progressive", Radius = 11, Variance = 3, Duration = 0.3,
			Count = R(12, 16), Lifetime = R(1.4, 2.2), Size = Vector3.new(2.6, 1.4, 2), SizeScale = R(0.7, 1.4),
			Collision = false, MatchGround = true, YOffset = 0.45, AngleX = R(25, 50), SpawnTime = R(0.05, 0.25), DespawnTime = R(0.8, 1.1),
		} do
			rocks:SetAttribute(k, v)
		end
		shake(p, "Explosion,30~130,3.2,0.9,20,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- HowlTell (Pack Call windup, at the Mouth, 1.20 s): rings of sound leave
	-- the muzzle, a swelling spirit glow, mist, a rush of spirit motes drawn
	-- in then thrown up.
	do
		local p = part(root, "HowlTell", Vector3.new(8, 8, 8), { AuthoredSeconds = 1.2 })
		em(p, "Waves", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, Rate = 4, Lifetime = R(0.55), Size = grow(2, 14), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 }, { EmitDuration = 1.2, EmitDelay = 0.1 })
		em(p, "Arcs", { Texture = TEX.arc, Color = CS(MOON), LightEmission = 1, Rate = 3, EmissionDirection = Enum.NormalId.Front, Speed = R(24), Drag = 3, Rotation = R(0), Lifetime = R(0.5), Size = grow(5, 12), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 0.8 }, { EmitDuration = 1.2, EmitDelay = 0.1 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.2), Size = grow(1, 6), Transparency = NS({ KP(0, 0.8), KP(0.85, 0.45), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, SPIRIT), CK(1, WHITE) }), LightEmission = 1, Brightness = 3, Lifetime = R(1.2), Size = grow(0.5, 4.5), Transparency = NS({ KP(0, 0.9), KP(0.85, 0.2), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Mist", { Texture = TEX.puff, Color = CS(MOON), Rate = 24, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(5, 11), Drag = 1.5, Lifetime = R(0.9, 1.4), Size = grow(1.5, 5), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitDuration = 1.2 })
		em(p, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Rate = 22, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = R(10, 16), Lifetime = R(0.4, 0.6), Size = grow(0.5, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 1.2 })
	end

	-- PhaseBurst (Pack Call release, floor under the King, authored r14): the
	-- fight escalates. A spirit sigil blooms and spins out, three shock
	-- rings, a pillar of light rays, spirit motes spiralling up, dust and
	-- embers. Code scales EmitCounts for the second call.
	do
		local p = part(root, "PhaseBurst", Vector3.new(28, 0.2, 28), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "SigilDark", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.6), Size = grow(6, 26, 28), Transparency = NS({ KP(0, 0.3), KP(0.5, 0.45), KP(1, 1) }), ZOffset = 0.2 }))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(0.5, SPIRIT), CK(1, MOON) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.6), Size = grow(6, 26, 30), RotSpeed = R(90), Transparency = NS({ KP(0, 0.1), KP(0.55, 0.25), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Mandala", with(FLAT, { Texture = TEX.mandala, Color = CS(WHITE), LightEmission = 1, Lifetime = R(1.4), Size = grow(4, 22, 24), RotSpeed = R(-70), Transparency = NS({ KP(0, 0.1), KP(0.55, 0.3), KP(1, 1) }), ZOffset = 0.8 }))
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.45), Size = grow(1, 34), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1.5 }))
		em(g, "Ring2", with(FLAT, { Texture = TEX.ringSpiky, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.6), Size = grow(2, 36), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.2 }), { EmitDelay = 0.1 })
		em(g, "Ring3", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(0.9), Size = grow(2, 46), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.8 }), { EmitDelay = 0.22 })
		em(g, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(70, 120), Lifetime = R(0.5, 0.8), Size = grow(16, 4), Transparency = NS({ KP(0, 0), KP(1, 1) }), Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume }, { EmitCount = 24 })
		em(g, "Pillar", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(3, 3), Speed = R(25, 40), Lifetime = R(0.5, 0.8), Size = grow(5, 2), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitCount = 10 })
		em(g, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, Speed = R(6, 14), Lifetime = R(1.2, 2), Size = grow(0.8, 0), Acceleration = Vector3.new(0, 6, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 30 })
		em(g, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(8, 24), Transparency = pop, ZOffset = 3 })
		em(g, "Dust", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(14, 26), Drag = 3, Lifetime = R(0.9, 1.4), Size = grow(3, 9), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 16 })
		shake(p, "Explosion,30~130,2.4,0.9,18,0.02,1;1;1,0.08;0.08;0.08")
	end

	-- PhaseFlare (Pack Call release, on the chest): a spirit-flame burst out
	-- of the mane and body, a flash and a ring, the aura flaring.
	do
		local p = part(root, "PhaseFlare", Vector3.new(6, 6, 6))
		em(p, "Flames", { Texture = TEX.flameBurst, Color = CS({ CK(0, WHITE), CK(0.5, SPIRIT), CK(1, MOON) }), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Speed = R(8, 18), Drag = 2, Lifetime = R(0.5, 0.9), Size = grow(3, 8), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.2), Size = grow(8, 20), Transparency = pop, ZOffset = 3 })
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Lifetime = R(0.4), Size = grow(2, 24), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.35), Size = grow(2, 16, 0), ZOffset = 3 })
		em(p, "Motes", { Texture = TEX.dot, Color = CS(SPIRIT), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(6, 16), Drag = 1.5, Acceleration = Vector3.new(0, 5, 0), Lifetime = R(1, 1.8), Size = grow(0.45, 0) }, { EmitCount = 24 })
	end

	-- Roar (aggro, at the Mouth, facing out): an arena entrance. Three
	-- sound rings, a blast of mist and dust forward, a flat ring on the floor,
	-- flash, sparks.
	do
		local p = part(root, "Roar", Vector3.new(0.4, 0.4, 0.4))
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.5), Size = grow(2, 20), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 1 }, { EmitCount = 1 })
		em(p, "Ring2", { Texture = TEX.ringThin, Color = CS(MOON), LightEmission = 1, Lifetime = R(0.6), Size = grow(2, 26), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 }, { EmitDelay = 0.18 })
		em(p, "Ring3", { Texture = TEX.ringSpiky, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.6), Size = grow(2, 30), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1 }, { EmitDelay = 0.34 })
		em(p, "Blast", { Texture = TEX.puff, Color = CS(MOON), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Speed = R(26, 46), Drag = 3, Lifetime = R(0.9, 1.4), Size = grow(2, 9), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 16 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.15), Size = grow(4, 12), Transparency = pop, ZOffset = 3 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, SPIRIT) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(50, 50), Speed = R(14, 34), Acceleration = Vector3.new(0, -8, 0), Lifetime = R(0.5, 1.0), Size = grow(0.4, 0) }, { EmitCount = 18 })
		local g = att(p, "Ground", Vector3.new(0, -7, 0))
		em(g, "Floor", with(FLAT, { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Lifetime = R(0.5), Size = grow(2, 26), Transparency = NS({ KP(0, 0.15), KP(1, 1) }), ZOffset = 1 }))
		em(g, "FloorDust", with(FLAT, { Texture = TEX.ringDust, Color = CS(SLATE), Lifetime = R(0.7), Size = grow(2, 24), Transparency = NS({ KP(0, 0.3), KP(1, 1) }), ZOffset = 0.4 }))
		shake(p, "Custom,30~110,1.2,0.6,14,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- Hits (on the struck player, near side, facing the King): one stack per
	-- blow family, short and bright.
	local function hit(name, build)
		local p = part(root, name, Vector3.new(0.3, 0.3, 0.3))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.12), Size = grow(2.5, 6), Transparency = pop, ZOffset = 3 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Brightness = 5, Lifetime = R(0.22), Size = grow(0.8, 5.5, 0), ZOffset = 3 })
		em(p, "Sparks", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, GOLD) }), LightEmission = 1, SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Front, Speed = R(14, 32), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.3, 0.6), Size = grow(0.28, 0) }, { EmitCount = 14 })
		em(p, "Ink", { Texture = TEX.ink, Color = CS(SLATE), Lifetime = R(0.3), Size = grow(3, 5), Transparency = NS({ KP(0, 0.25), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		build(p)
	end
	hit("HitClaw", function(p)
		em(p, "Rake", { Texture = TEX.claw, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Brightness = 3, Rotation = R(-35), Lifetime = R(0.18), Size = grow(5.5, 7), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 2 })
		em(p, "RakeDark", { Texture = TEX.claw, Color = CS(INK), Rotation = R(-35), Lifetime = R(0.2), Size = grow(6, 7.5), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1 })
	end)
	hit("HitBite", function(p)
		em(p, "FangU", { Texture = TEX.arc, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Rotation = R(0), EmissionDirection = Enum.NormalId.Bottom, Speed = R(10), Lifetime = R(0.18), Size = grow(3.5, 4.5), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 2 })
		em(p, "FangD", { Texture = TEX.arc, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Rotation = R(180), EmissionDirection = Enum.NormalId.Top, Speed = R(10), Lifetime = R(0.18), Size = grow(3.5, 4.5), Transparency = NS({ KP(0, 0), KP(1, 1) }), ZOffset = 2 })
		em(p, "Ring", { Texture = TEX.ringSpiky, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.25), Size = grow(1, 8), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 })
	end)
	hit("HitHeavy", function(p)
		em(p, "Ring", { Texture = TEX.ringThick, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Lifetime = R(0.3), Size = grow(1, 12), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "RingSpiky", { Texture = TEX.ringSpiky, Color = CS(MOON), LightEmission = 1, Lifetime = R(0.4), Size = grow(1, 14), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 })
		em(p, "Rays", { Texture = TEX.line, Color = CS(HOT), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(40, 70), Lifetime = R(0.15, 0.25), Size = grow(5, 1), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 12 })
		em(p, "Dust", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(180, 180), Speed = R(6, 14), Drag = 3, Lifetime = R(0.5, 0.9), Size = grow(2, 5), Transparency = NS({ KP(0, 0.45), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 5 })
	end)

	-- Aura parts (always on; the runtime clones each emitter into the body).
	-- AuraGround is no longer mounted (it read as a pale circle under the
	-- King, user 2026-10-21); drop it on the next rebuild of this set.
	-- kept light. `BaseRate` is the rate at full health; code scales it up
	-- and shifts the colour as the King is hurt.
	do
		local p = part(root, "AuraGround", Vector3.new(14, 0.2, 14))
		em(p, "Under", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Rate = 0.35, Lifetime = R(3), Size = NS(15), Transparency = NS({ KP(0, 1), KP(0.2, 0.6), KP(0.8, 0.6), KP(1, 1) }), LockedToPart = true, ZOffset = 0.1 }))
		em(p, "Array", with(FLAT, { Texture = TEX.mandala, Color = CS(MOON), LightEmission = 0.8, Rate = 0.35, Lifetime = R(3), Size = NS(14), RotSpeed = R(14), Transparency = NS({ KP(0, 1), KP(0.2, 0.62), KP(0.8, 0.62), KP(1, 1) }), LockedToPart = true, ZOffset = 0.4 }))
	end
	do
		local p = part(root, "AuraMane", Vector3.new(2, 2, 2))
		em(p, "Flames", { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(1, MOON) }), LightEmission = 1, Rate = 7, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(2, 5), Lifetime = R(0.9, 1.4), Size = grow(2.2, 0.6), Transparency = NS({ KP(0, 0.55), KP(0.3, 0.4), KP(1, 1) }), Rotation = R(-15, 15), LockedToPart = false })
		em(p, "Motes", { Texture = TEX.dot, Color = CS(SPIRIT), LightEmission = 1, Rate = 6, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 1.2, 0), Lifetime = R(2, 3.2), Size = grow(0.4, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.2), KP(0.8, 0.4), KP(1, 1) }) })
		em(p, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, GOLD) }), LightEmission = 1, Rate = 0, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(2, 6), Lifetime = R(0.8, 1.4), Size = grow(0.3, 0), Transparency = NS({ KP(0, 0.1), KP(1, 1) }) })
	end
	do
		local p = part(root, "AuraBreath", Vector3.new(0.4, 0.4, 0.4))
		em(p, "Mist", { Texture = TEX.puff, Color = CS(MOON), Rate = 3.5, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(20, 20), Speed = R(2, 4), Drag = 1, Acceleration = Vector3.new(0, 0.8, 0), Lifetime = R(1.1, 1.7), Size = grow(0.8, 3.6), Transparency = NS({ KP(0, 0.7), KP(0.3, 0.55), KP(1, 1) }), Rotation = R(0, 360) })
	end

	-- Death, in pieces the runtime sequences (with spirit motes rising):
	-- DeathBuild (collapsing gather), DeathBurst (the final burst),
	-- DeathSpirit (the release column and lingering motes).
	do
		local p = part(root, "DeathBuild", Vector3.new(14, 14, 14), { AuthoredSeconds = 0.9 })
		em(p, "Gather", { Texture = TEX.glint, Color = CS({ CK(0, SPIRIT), CK(1, WHITE) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 55, Lifetime = R(0.4, 0.6), Speed = R(16, 24), Size = grow(0.8, 0.05), Transparency = NS({ KP(0, 1), KP(0.2, 0.1), KP(1, 0.5) }), LockedToPart = true }, { EmitDuration = 0.9 })
		em(p, "Pull", { Texture = TEX.line, Color = CS(MOON), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 20, Lifetime = R(0.3, 0.45), Speed = R(30, 42), Size = grow(4, 0.5), Transparency = NS({ KP(0, 1), KP(0.3, 0.1), KP(1, 0.7) }) }, { EmitDuration = 0.9 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(0.9), Size = grow(1, 10), Transparency = NS({ KP(0, 0.8), KP(0.9, 0.4), KP(1, 1) }), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = CS({ CK(0, SPIRIT), CK(1, WHITE) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.9), Size = grow(0.5, 8), Transparency = NS({ KP(0, 0.9), KP(0.9, 0.1), KP(1, 1) }), LockedToPart = true, ZOffset = 1 })
		em(p, "Cracks", { Texture = TEX.glint, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Rate = 14, Lifetime = R(0.12, 0.2), Size = grow(0.5, 4.5, 0), Rotation = R(0, 180), SpreadAngle = Vector2.new(180, 180), Speed = R(0, 0), ZOffset = 2 }, { EmitDuration = 0.9 })
	end
	do
		local p = part(root, "DeathBurst", Vector3.new(0.6, 0.6, 0.6))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 8, Lifetime = R(0.3), Size = grow(14, 44), Transparency = NS({ KP(0, 0), KP(0.4, 0.2), KP(1, 1) }), ZOffset = 4 })
		em(p, "Star", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 6, Lifetime = R(0.5), Size = grow(4, 34, 0), ZOffset = 4 })
		em(p, "InkSplash", { Texture = TEX.ink, Color = CS(INK), Lifetime = R(0.7), Size = grow(8, 26), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 0.5 })
		em(p, "Ring", { Texture = TEX.ringThin, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.6), Size = grow(3, 40), Transparency = NS({ KP(0, 0.1), KP(1, 1) }), ZOffset = 2 })
		em(p, "RingSpiky", { Texture = TEX.ringSpiky, Color = CS(GOLD), LightEmission = 1, Lifetime = R(0.7), Size = grow(3, 46), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), Rotation = R(0, 360), ZOffset = 1.5 }, { EmitDelay = 0.1 })
		em(p, "Rays", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, SpreadAngle = Vector2.new(180, 180), Speed = R(60, 110), Lifetime = R(0.4, 0.7), Size = grow(14, 3), Transparency = NS({ KP(0, 0), KP(1, 1) }) }, { EmitCount = 26 })
		em(p, "Motes", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(10, 34), Drag = 2, Acceleration = Vector3.new(0, 6, 0), Lifetime = R(1.2, 2.2), Size = grow(0.9, 0), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }) }, { EmitCount = 40 })
		em(p, "Smoke", { Texture = TEX.puff, Color = CS(DUST), SpreadAngle = Vector2.new(180, 180), Speed = R(8, 18), Drag = 3, Lifetime = R(1.4, 2.2), Size = grow(5, 16), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 12 })
		em(p, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, HOT), CK(1, EMBER) }), LightEmission = 1, SpreadAngle = Vector2.new(180, 180), Speed = R(10, 30), Acceleration = Vector3.new(0, -16, 0), Lifetime = R(1, 2), Size = grow(0.45, 0) }, { EmitCount = 24 })
		shake(p, "Explosion,30~140,3.4,1.1,20,0.02,1;1;1,0.1;0.1;0.1")
	end
	do
		local p = part(root, "DeathSpirit", Vector3.new(16, 0.2, 16), { AuthoredRadius = 8 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Sigil", with(FLAT, { Texture = TEX.sigil, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Brightness = 2, Lifetime = R(3.2), Size = grow(8, 22, 26), RotSpeed = R(40), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }), ZOffset = 0.6 }))
		em(g, "Pillar", { Texture = TEX.line, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(4, 4), Speed = R(30, 60), Rate = 18, Lifetime = R(0.9, 1.4), Size = grow(14, 4), Transparency = NS({ KP(0, 0.2), KP(1, 1) }) }, { EmitDuration = 2.4 })
		em(g, "Spirits", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, SPIRIT) }), LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, Speed = R(5, 14), Rate = 16, Lifetime = R(2, 3.4), Size = grow(0.8, 0), Acceleration = Vector3.new(0, 4, 0), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.2), KP(1, 1) }) }, { EmitDuration = 3.0 })
		em(g, "Ring", with(FLAT, { Texture = TEX.ringThin, Color = CS(WHITE), LightEmission = 1, Lifetime = R(1.1), Size = grow(2, 40), Transparency = NS({ KP(0, 0.2), KP(1, 1) }), ZOffset = 1.4 }), { EmitDelay = 0.2 })
		em(g, "Smoke", { Texture = TEX.puff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(8, 14), Drag = 3, Lifetime = R(1.4, 2.4), Size = grow(4, 12), Transparency = NS({ KP(0, 0.5), KP(1, 1) }), Rotation = R(0, 360) }, { EmitCount = 14 })
		em(g, "Petals", { Texture = TEX.dot, Color = CS(MOON), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(1, 4), Acceleration = Vector3.new(0, 2.5, 0), Rate = 10, Lifetime = R(3, 5), Size = grow(0.35, 0), Transparency = NS({ KP(0, 1), KP(0.2, 0.3), KP(0.8, 0.5), KP(1, 1) }) }, { EmitDuration = 4.0 })
	end

	root.Parent = effects
	return root
end
print("buildElderWolfKingFX installed")
return true
