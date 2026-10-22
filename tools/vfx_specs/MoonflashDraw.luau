--!nocheck
-- Moonflash Draw's templates (MoonflashDraw_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Runtime: src/client/TechniqueFX/MoonflashDraw.luau.
--
-- The move: Animations.Techniques.MoonflashDraw (1.0 s, Sword/jian, joint
-- HiltR), markers Hit 0.0667 / Hit Stop 0.2333 with Lunge start/end on the
-- same frames: the caster lunges def.lunge (14) studs during the active
-- window, and the line (def.length 18) runs from the cast's start. Sampled on katanadummy: the blade is drawn from the right hip
-- (tip behind-right at 0.07), sweeps flat round the right side (0.13), across
-- the front (0.19, tip 5.7 ahead) and out to the left (0.26), at chest height
-- (~3.6-4.7 studs off the ground), a ~240 deg one-handed iaido cut. Still
-- tail to 1.0.
--
-- The pitch ("the moon flashes after the sword is sheathed"):
--   Windup (0 -> Hit, ~0.07 s, part "Windup" on the right hand): a cold glint
--     on the hand as the blade leaves the scabbard.
--   Release (Hit, part "Hand"): a crescent-moon flash and star on the hand,
--     swirl air rings punched forward along the dash.
--   Travel (Hit -> end of dash, part "Front", runtime-driven along the path):
--     a horizontal crescent of moonlight Beams at chest height riding just
--     ahead of the caster (the drawn blade's arc, span = the hitbox width
--     plus slack), dragging a flat wake band exactly as wide as the hitbox,
--     and a bright streak Beam from the dash start to the front (part
--     "Streak"). A glowing slit is drawn on the ground behind it ("Cut").
--     II+ Neon afterimages of the body are left along the path.
--   Impact (each enemy as the front passes it, part "Impact"): a silver
--     impactStack (flash, spiky ring, sparks, standing torus, ground shock)
--     with a horizontal crescent cut through the body.
--   Sheathe (II+, part "Sheathe", a beat after the dash ends): every target
--     cut flashes again with a crossing crescent and a white standing ring,
--     and the path's slit flares; the real "after the draw" moment.
--   Finish (dash end, part "Finish", at the caster's feet): a crescent moon
--     mark on the ground and a ground torus, dust; III+ a Craters ring;
--     IV a big crescent moon rising behind, the light, impact frames.
--   Aftermath ("Cut" cools into the ink "Scar"; "Path" motes and cracks).
--
-- Tiers:
--   I   crescent (span 6) + wake, streak beam, release flash + 1 air ring,
--       impacts, finish mark + torus, slit and scar ~1 s.
--   II  span 6.5, an echo crescent, 1 afterimage, motes off the path,
--       impact swirl, the Sheathe flash on every target.
--   III span 7, 2 afterimages, 2 air rings, impact bubble and rock kicks,
--       path cracks, Craters ring at the finish, sheathe flare along the slit.
--   IV  span 8, gold-white core, 3 afterimages, 3 air rings, the one point
--       light riding the front, a rising crescent moon at the finish, impact
--       frames at the sheathe and a quake on the first impact.
--
-- Remade 2026-10-21 (weapon models and Hit windows): the jian is the blade.
--   Windup (0 -> Hit, 0.067 s): part "Charge" rides the model's Base -> Tip
--     (WeaponFX.charge): a dark beam under a cold bright one, motes and a glint
--     at the point, the blade catching the light as it clears the scabbard.
--   Release (Hit): the moon flash and air rings burst on the blade, 0.8 of the
--     way to the tip (not on the hand).
--   Dash (Hit -> Hit Stop + 0.06): part "Edge" rides Base -> Tip: a solid
--     moon ribbon (II+ a longer afterimage), the blade wreathed in a Glow beam
--     and shedding motes; the crescent front gets a dark ink crescent under it.
--     Impacts fire as the front passes each target, so they sit inside the
--     lunge window (Hit -> Hit Stop) on the clip's own Lunge markers.
--   Sheathe (a beat after the dash): "SheatheGlint" flares on the blade tip, a
--     cold star, a ring and a crescent flipbook, as the blade is put away;
--     each target cut flashes a crescent flipbook as well.
-- Authored along -Z at length 14, width 5, active 0.16 s.
local B = _G.vfxBlocks
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local MOON = Color3.fromRGB(165, 182, 255) -- the technique colour (suggested def.color)
local CORE = Color3.fromRGB(246, 248, 255)
local EDGE = Color3.fromRGB(98, 112, 246) -- the crescent's body, deeper than MOON
local GOLD_CORE = Color3.fromRGB(255, 242, 208) -- mastery core
local INK = Color3.fromRGB(28, 30, 62)
local PALETTE = {
	color = MOON, core = CORE,
	ringColor = Color3.fromRGB(226, 232, 255), swirlColor = Color3.fromRGB(176, 190, 255), groundColor = Color3.fromRGB(200, 212, 255),
}
local function pal(extra)
	local t = table.clone(PALETTE)
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

local A = {
	moon = id(1084963972), -- crisp crescent moon
	slash = id(7216852121), -- clean horizontal crescent
	layered = id(13366366767), -- layered crescent slashes
	mote = id(9841260273), -- glowing spindle mote
	crackSmall = id(97725700315217),
	star4 = id(13271628051),
	crescentFlip = id(13972642464), -- 4x4 flipbook: a thin crescent moon sweeping and fading (cold edge)
	ring = id(9841273159), -- clean thin ring
}
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local ONESHOT = Enum.ParticleFlipbookMode.OneShot

local SPAN = { 6, 6.5, 7, 8 }
local HEIGHT = 3.4 -- the blade's arc, chest height
local HAND_AT = O * CFrame.new(1.4, 3.4, -1.2) -- right hand at Hit; runtime puts it on the live hand
local FRONT_AT = O * CFrame.new(0, HEIGHT, -1.5)
local FINISH_AT = O * CFrame.new(0, 0.15, -14)

-- A horizontal crescent of Beams (two tapered halves, tips trailing back).
local function crescent(part, layer, span, depth, y, width, color, transparency, faceCamera, light)
	local function att(name, pos, axis)
		local a = Instance.new("Attachment")
		a.Name = layer .. name
		a.CFrame = CFrame.fromMatrix(pos, axis, Vector3.yAxis)
		a.Parent = part
		return a
	end
	local L = att("L", Vector3.new(-span / 2, y, depth), Vector3.new(0, 0, -1))
	local C = att("C", Vector3.new(0, y, 0), Vector3.new(1, 0, 0))
	local Rt = att("R", Vector3.new(span / 2, y, depth), Vector3.new(0, 0, 1))
	for i, pair in { { L, C, 0.04, width }, { C, Rt, width, 0.04 } } do
		local b = Instance.new("Beam")
		b.Name = layer .. (if i == 1 then "Left" else "Right")
		b.Attachment0, b.Attachment1 = pair[1], pair[2]
		b.Width0, b.Width1 = pair[3], pair[4]
		b.CurveSize0 = if i == 1 then depth * 0.9 else span * 0.28
		b.CurveSize1 = if i == 1 then span * 0.28 else depth * 0.9
		b.FaceCamera = faceCamera
		b.Color = CS(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Transparency = NS(transparency)
		b.Segments = 14
		b.Enabled = false
		b.Parent = part
	end
end

local function trail(parent, name, a0, a1, color, life, t0, faceCamera, light)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = CS(color)
	t.Transparency = NS({ KP(0, t0), KP(0.6, (1 + t0) / 2), KP(1, 1) })
	t.WidthScale = NS({ KP(0, 1), KP(1, 0.6) })
	t.Lifetime = life
	t.FaceCamera = faceCamera
	t.LightEmission, t.LightInfluence = light, 0
	t.MinLength = 0.05
	t.Enabled = false
	t.Parent = parent
	return t
end

-- The drawn blade's arc riding the dash front.
B.BLOCKS.mfdFront = function(root, tier, p)
	local span = SPAN[tier]
	local depth = span * 0.42
	local front = B.part(root, "Front", FRONT_AT, Vector3.new(span, 0.3, depth))
	for k, v in {
		Span = span, Height = HEIGHT, Pitch = 10, Roll = 8, -- leading edge up a little, right tip low: the cut runs right to left
		Lead = 1.6, -- studs ahead of the caster's root
		Echoes = ({ 0, 1, 1, 2 })[tier], EchoLag = 1.6, EchoScale = 0.85, -- echo crescents trail by studs
	} do
		front:SetAttribute(k, v)
	end
	local core = if tier >= 4 then GOLD_CORE else CORE
	-- dark under light: an ink crescent a hair under the bright ones, so the arc reads on grass at noon
	crescent(front, "Ink", span * 1.04, depth * 1.04, -0.04, span * 0.36, INK, 0.3, false, 0)
	crescent(front, "Edge", span, depth, 0, span * 0.3, EDGE, 0.05, false, 0.2)
	crescent(front, "Core", span * 0.94, depth * 0.9, 0.05, span * 0.14, core, 0, false, 0.45)
	crescent(front, "Glow", span * 1.1, depth * 1.1, 0.02, span * 0.42, MOON, 0.45, true, 0.35)
	-- the wake band between the tips (the hitbox's width) and a bright centre streak
	trail(front, "Wake", front.EdgeL, front.EdgeR, MOON, ({ 0.22, 0.26, 0.3, 0.36 })[tier], 0.45, false, 0.35)
	local s0 = B.attach(front, "StreakA", Vector3.new(0, 0.22, 0))
	local s1 = B.attach(front, "StreakB", Vector3.new(0, -0.22, 0))
	trail(front, "CoreStreak", s0, s1, core, ({ 0.14, 0.16, 0.2, 0.24 })[tier], 0.1, true, 0.6)
	local shed = B.emitter(front, "Shed", {
		Texture = A.mote, Color = CS(CORE, MOON),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70),
		Size = NS({ KP(0, 0.22), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.3, 0.5), Speed = R(2, 5), Drag = 3, LightEmission = 0.6, Rotation = R(0, 360),
		Rate = ({ 20, 30, 40, 50 })[tier],
	})
	shed:SetAttribute("Shed", true)
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = MOON
		light.Range = 16
		light.Brightness = 0
		light.Shadows = false
		light.Parent = front
	end
	return front
end

-- A straight streak of moonlight from the dash start to the front (the
-- runtime places A0 at the start and A1 at the front).
B.BLOCKS.mfdStreak = function(root, tier, p)
	local streak = B.part(root, "Streak", O * CFrame.new(0, HEIGHT, 0))
	local a0 = B.attach(streak, "A0", Vector3.zero)
	local a1 = B.attach(streak, "A1", Vector3.new(0, 0, -14))
	local function beam(name, width, color, transparency, light)
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = width * 0.35, width
		b.FaceCamera = true
		b.Color = CS(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Transparency = NS({ KP(0, 1), KP(0.25, transparency + (1 - transparency) * 0.4), KP(1, transparency) })
		b.Segments = 10
		b.Enabled = false
		b.Parent = streak
	end
	beam("Core", ({ 0.35, 0.4, 0.45, 0.55 })[tier], if tier >= 4 then GOLD_CORE else CORE, 0.05, 0.5)
	beam("Glow", ({ 1.6, 1.9, 2.2, 2.6 })[tier], MOON, 0.55, 0.35)
	streak:SetAttribute("Fade", ({ 0.3, 0.35, 0.4, 0.5 })[tier])
	return streak
end

-- The glowing slit on the ground and the ink scar it cools into.
B.BLOCKS.mfdCut = function(root, tier, p)
	local function strip(name, material, color, width, attrs, thick)
		local s = B.part(root, name, O * CFrame.new(0, 0.05, -7), Vector3.new(width, thick, 1))
		s.Material, s.Color = material, color
		for k, v in attrs do
			s:SetAttribute(k, v)
		end
		return s
	end
	strip("Cut", Enum.Material.Neon, Color3.fromRGB(170, 186, 255), ({ 0.22, 0.26, 0.3, 0.36 })[tier], {
		StartTransparency = 0.3, Fade = ({ 0.5, 0.6, 0.7, 0.85 })[tier], FadeColor = MOON,
	}, 0.1)
	strip("Scar", Enum.Material.SmoothPlastic, INK, ({ 0.5, 0.6, 0.7, 0.85 })[tier], {
		StartTransparency = 0.4, Fade = ({ 1.0, 1.2, 1.5, 1.9 })[tier], FadeDelay = 0.3,
	}, 0.06)
	return root:FindFirstChild("Cut")
end

B.BLOCKS.mfdPath = function(root, tier, p)
	local path = B.part(root, "Path", O * CFrame.new(0, 0.2, -7), Vector3.new(2.5, 0.2, 14))
	B.emitter(path, "Motes", {
		Texture = A.mote, Color = CS(CORE, MOON),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		Size = NS({ KP(0, 0.25), KP(0.5, 0.2), KP(1, 0) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(1, 1) }),
		Lifetime = R(0.7, 1.1), Speed = R(1.5, 3), Drag = 1, LightEmission = 0.5, Rotation = R(0, 360),
	}, { EmitCount = ({ 4, 8, 12, 16 })[tier], EmitDelay = 0.15 })
	if tier >= 3 then
		B.emitter(path, "Cracks", B.flat({
			Texture = A.crackSmall, Color = CS(INK), LightInfluence = 0.3,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Size = NS(1.2), Transparency = NS({ KP(0, 1), KP(0.05, 0.3), KP(0.6, 0.45), KP(1, 1) }),
			Lifetime = R(1.1, 1.4), Rotation = R(0, 360), ZOffset = -0.5,
		}), { EmitCount = ({ 0, 0, 3, 5 })[tier], EmitDelay = 0.1 })
	end
	return path
end

-- The draw on the hand: a crescent moon flash instead of a plain star.
B.BLOCKS.mfdDraw = function(root, tier, p)
	local hand = B.part(root, "Hand", HAND_AT)
	B.emitter(hand, "Moon", B.flat({
		Texture = A.moon, Color = CS(CORE, MOON),
		Size = NS({ KP(0, 1), KP(0.3, 2.6 + tier * 0.4), KP(1, 3.2 + tier * 0.45) }), Transparency = NS({ KP(0, 0.05), KP(0.5, 0.2), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.55, Rotation = R(80, 100), ZOffset = 1,
	}, Enum.NormalId.Top), { EmitCount = 1 })
	return hand
end

-- The windup glint: the blade catching the light as it leaves the scabbard.
B.BLOCKS.mfdGlint = function(root, tier, p)
	local w = B.part(root, "Windup", HAND_AT, Vector3.new(1.5, 1.5, 1.5))
	w:SetAttribute("AuthoredWindup", 0.07)
	B.emitter(w, "Glint", {
		Texture = A.star4, Color = CS(CORE),
		Size = NS({ KP(0, 0.2), KP(0.6, 1.4 + tier * 0.25), KP(1, 0.4) }), Transparency = NS({ KP(0, 0.4), KP(0.6, 0), KP(1, 0.3) }),
		Lifetime = R(0.1), LightEmission = 0.7, Rotation = R(-20, 20), LockedToPart = true, ZOffset = 1,
	}, { EmitCount = 1 })
	B.emitter(w, "Charge", {
		Texture = B.ASSETS.glow, Color = CS(MOON),
		Size = NS({ KP(0, 0.3), KP(1, 1.1 + tier * 0.15) }), Transparency = NS({ KP(0, 0.7), KP(1, 0.25) }),
		Lifetime = R(0.1), LightEmission = 0.5, LockedToPart = true,
	}, { EmitCount = 1 })
	return w
end

-- The horizontal crescent cut through each target.
B.BLOCKS.mfdSlash = function(root, tier, p)
	local part = root:FindFirstChild(p.part or "Impact")
	local body = part:FindFirstChild("Body")
	-- the moon's own edge sweeping through the body: a crescent flipbook
	B.emitter(body, (p.name or "Slash") .. "Flip", {
		Texture = A.crescentFlip, Color = CS(Color3.new(1, 1, 1)),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 2.4 + tier * 0.3), KP(1, 3.4 + tier * 0.4) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.15), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.5, Rotation = p.rotation or R(-8, 8), ZOffset = 3.2,
	}, { EmitCount = 1 })
	return B.emitter(body, p.name or "Slash", {
		Texture = p.texture or A.slash, Color = CS(CORE, MOON),
		Size = NS({ KP(0, 1), KP(0.25, 2.8 + tier * 0.45), KP(1, 3.4 + tier * 0.5) }), Transparency = NS({ KP(0, 0), KP(0.55, 0.15), KP(1, 1) }),
		Lifetime = R(p.life or 0.28), LightEmission = 0.55, Rotation = p.rotation or R(-8, 8), ZOffset = 3,
	}, { EmitCount = 1 })
end

B.BLOCKS.mfdImpact = function(root, tier, p)
	local wave = pal({ size = ({ 3.4, 4.2, 5.2, 6.2 })[tier], groundSize = ({ 3.6, 4.4, 5.4, 6.6 })[tier] })
	return B.impactStack(root, tier, { burst = pal(), wave = wave })
end

-- II+: the after-the-draw flash on each target cut (a crossing crescent, a
-- star, a white standing ring), IV impact frames on the first.
B.BLOCKS.mfdSheathe = function(root, tier, p)
	local part = B.part(root, "Sheathe", O * CFrame.new(0, 0.15, -6))
	local body = B.attach(part, "Body", Vector3.new(0, 2.2, 0))
	B.BLOCKS.mfdSlash(root, tier, { part = "Sheathe", name = "Cross", texture = A.layered, rotation = R(-40, -25), life = 0.34 })
	B.emitter(body, "Flash", {
		Texture = A.star4, Color = CS(CORE),
		Size = NS({ KP(0, 0.8), KP(0.3, 2.4 + tier * 0.35), KP(1, 0) }), Transparency = NS(0),
		Lifetime = R(0.16), LightEmission = 0.8, Rotation = R(-15, 15), ZOffset = 3,
	}, { EmitCount = 1 })
	B.emitter(body, "Motes", {
		Texture = A.mote, Color = CS(CORE, MOON), SpreadAngle = Vector2.new(180, 180),
		Size = NS({ KP(0, 0.3), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.4, 0.7), Speed = R(6, 12), Drag = 4, LightEmission = 0.6, Rotation = R(0, 360), ZOffset = 2,
	}, { EmitCount = ({ 0, 6, 9, 12 })[tier] })
	local d = ({ 0, 4.4, 5.4, 6.6 })[tier]
	B.meshWave(body, "SheatheRing", {
		mesh = B.ASSETS.torusMesh, color = CORE,
		fromSize = Vector3.new(1, 0.15, 1), toSize = Vector3.new(d, d * 0.12, d),
		rotation = Vector3.new(90, 0, 0), fromTransparency = 0.15, toTransparency = 1,
		duration = 0.34, style = "Quart",
	})
	if tier >= 4 then
		B.screenShake(root, tier, { parent = "Sheathe", name = "Frames", shake = false, framesName = "SheatheFrames", frames = true })
	end
	return part
end

-- The finish at the dash end, at the caster's feet.
B.BLOCKS.mfdFinish = function(root, tier, p)
	local fin = B.part(root, "Finish", FINISH_AT)
	B.emitter(fin, "Mark", B.flat({
		Texture = A.moon, Color = CS(MOON), LightInfluence = 0.2,
		Size = NS({ KP(0, 1.5), KP(0.15, 3 + tier * 0.4), KP(1, 3.4 + tier * 0.45) }), Transparency = NS({ KP(0, 0.1), KP(0.6, 0.35), KP(1, 1) }),
		Lifetime = R(0.9 + tier * 0.15), LightEmission = 0.35, Rotation = R(170, 190), ZOffset = 0.3,
	}), { EmitCount = 1 })
	B.emitter(fin, "Dust", {
		Texture = B.ASSETS.dust, Color = CS(B.COLORS.dust), LightInfluence = 0.5,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Size = NS({ KP(0, 0.7), KP(1, 1.8) }), Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
		Lifetime = R(0.35, 0.55), Speed = R(14, 20), Drag = 5, Rotation = R(0, 360),
	}, { EmitCount = 4 + tier })
	local gd = ({ 5, 6, 7.5, 9 })[tier]
	B.meshWave(fin, "FinishWave", {
		mesh = B.ASSETS.torusMesh, color = PALETTE.groundColor,
		fromSize = Vector3.new(1.2, 0.15, 1.2), toSize = Vector3.new(gd, gd * 0.1, gd),
		fromOffset = Vector3.new(0, 0.15, 0), toOffset = Vector3.new(0, 0.15, 0),
		fromTransparency = 0.3, toTransparency = 1, duration = 0.4, style = "Quart",
	})
	if tier >= 3 then
		B.craterRing(root, tier, { parent = "Finish", name = "Crater", attrs = {
			Count = ({ 0, 0, 6, 8 })[tier], Radius = ({ 0, 0, 2.6, 3.2 })[tier], Variance = 0.6, Duration = 0.12,
			Size = Vector3.new(0.9, 0.7, 0.8), Lifetime = R(1, 1.3), RaycastDistance = 8,
		} })
	end
	if tier >= 4 then
		-- a big crescent moon rising behind the caster as the blade is sheathed
		B.emitter(fin, "RisingMoon", B.flat({
			Texture = A.moon, Color = CS(GOLD_CORE, MOON),
			Size = NS({ KP(0, 2), KP(0.3, 5.5), KP(1, 6.2) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.25), KP(0.7, 0.35), KP(1, 1) }),
			Lifetime = R(1.1), LightEmission = 0.4, Rotation = R(-30), ZOffset = -1,
			Acceleration = Vector3.new(0, 1.2, 0),
		}, Enum.NormalId.Back), { EmitCount = 1, EmitDelay = 0.05 })
	end
	return fin
end

-- The real blade's edge: the runtime moves Edge's Trails, Glow beam and Motes
-- onto the held model's Base -> Tip for the dash.
B.BLOCKS.mfdEdge = function(root, tier, p)
	return _G.vfxSpecs.BladeKit.edge(root, tier, {
		color = MOON, core = if tier >= 4 then GOLD_CORE else CORE, tail = EDGE,
		trailLife = { 0.18, 0.22, 0.26, 0.32 }, glowWidth = { 0.6, 0.8, 1, 1.2 }, moteRate = { 10, 16, 22, 30 },
	})
end

-- The flare on the blade tip as it is put away (a beat after the dash).
B.BLOCKS.mfdSheatheGlint = function(root, tier, p)
	local g = B.part(root, "SheatheGlint", O * CFrame.new(0, HEIGHT, -4), Vector3.new(1, 1, 1))
	B.emitter(g, "Star", {
		Texture = A.star4, Color = CS(CORE),
		Size = NS({ KP(0, 0.5), KP(0.3, 2.8 + tier * 0.5), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }),
		Lifetime = R(0.38), LightEmission = 0.9, Rotation = R(-10, 10), ZOffset = 1,
	}, { EmitCount = 1 })
	B.emitter(g, "Halo", {
		Texture = A.ring, Color = CS(MOON),
		Size = NS({ KP(0, 0.4), KP(1, 2.6 + tier * 0.4) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.34), LightEmission = 0.6, ZOffset = 0.5,
	}, { EmitCount = 1 })
	B.emitter(g, "Crescent", {
		Texture = A.crescentFlip, Color = CS(Color3.new(1, 1, 1)),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 2), KP(1, 3.4 + tier * 0.4) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.4), LightEmission = 0.55, Rotation = R(-40, -20), ZOffset = 1.2,
	}, { EmitCount = 1 })
	B.emitter(g, "Motes", {
		Texture = A.mote, Color = CS(CORE, MOON), SpreadAngle = Vector2.new(180, 180),
		Size = NS({ KP(0, 0.28), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.4, 0.8), Speed = R(2, 6), Drag = 2, LightEmission = 0.6, Rotation = R(0, 360), Acceleration = Vector3.new(0, 1.5, 0),
	}, { EmitCount = 4 + tier * 2 })
	return g
end

B.BLOCKS.mfdShake = function(root, tier, p)
	return B.screenShake(root, tier, { parent = "Hand", magnitude = ({ 0.7, 1, 1.4, 1.8 })[tier] })
end

return {
	id = "MoonflashDraw",
	root = { attrs = { AuthoredActive = 0.16, AuthoredLength = 14, AuthoredWidth = 5 } },
	beats = {
		-- the blade catches the light as it clears the scabbard (along Base -> Tip)
		{ block = "bladeCharge", params = { color = MOON, core = CORE, ink = INK, width = 0.4 } },
		{ block = "mfdGlint" },
		-- the draw, on the blade
		{ block = "mfdDraw" },
		{ block = "releaseFlash", params = pal({ part = "Hand", at = HAND_AT, light = false }) },
		{ block = "airShockwave", params = pal({ part = "Hand", at = HAND_AT, color = PALETTE.ringColor }) },
		{ block = "mfdShake" },
		-- the dash: the arc riding the front, the streak, the slit
		{ block = "mfdEdge" },
		{ block = "mfdFront" },
		{ block = "mfdStreak" },
		{ block = "mfdCut" },
		{ block = "mfdPath" },
		-- each target as the front passes it, and again at the sheathe
		{ block = "mfdImpact" },
		{ block = "mfdSlash" },
		{ block = "mfdSheathe", from = 2 },
		{ block = "mfdSheatheGlint" },
		-- the dash end
		{ block = "mfdFinish" },
	},
}
