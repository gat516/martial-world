--!nocheck
-- Crescent Moon Sweep's templates (CrescentSweep_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Runtime: src/client/TechniqueFX/CrescentSweep.luau.
--
-- The move: Skill_CrescentSweep (1.383 s, Guandao, joint Hilt), markers Hit
-- 0.633 and Hit Stop 0.75; a circle of radius 11 round the caster. Sampled on
-- GreataxeRig: 0.05-0.2 the polearm is raised into the grip, by 0.3 it is
-- wound back low behind the left hip (blade tip ~0.6 off the ground, 8 studs
-- out). From Hit the blade whips round in one low spin: behind (0.66), the
-- right (0.69), the front (0.72) and the left (0.75), ~323 deg in 0.12 s,
-- tip 0.6-4.6 studs off the ground, ~8 studs out; follow-through to 0.8.
--
-- The pitch ("a jade crescent moon cut out of the air"):
--   Windup (0 -> Hit, part "Windup" on the right hand): jade motes gather
--     into the grip as the blade is raised and wound back (II+ Spline
--     wisps, III+ a closing seal).
--   Release (Hit, part "Tip"): a flash on the blade where the spin starts.
--   Sweep (Hit -> Hit Stop, part "Sweep", runtime-turned round the caster on
--     the sampled heading curve): the blade's path is a flat jade sheet (a
--     radial Trail from 2 studs out to the blade's reach) with a bright moon
--     edge (a thin Trail at the reach), so the spin leaves a glowing crescent
--     that closes into a disc and fades. A ground torus rolls out to the
--     radius and a wispy swirl ring spreads at knee height (3D MeshWaves),
--     dust is kicked outward. III+ a spinning SimpleMeshVFX swirl shell and a
--     Craters ring erupting with the wave.
--   Impact (each enemy as the blade's heading passes it, part "Impact"): a
--     jade impactStack plus a horizontal crescent cut through the body.
--   Aftermath: a jade-ink crescent scorched into the ground under the sweep,
--     II+ motes rising round the circle.
--   IV: a jade-gold moon (a standing Neon torus) rising behind the caster,
--     the one light on the sweep, impact frames at the release and an
--     Explosion quake on the first impact.
--
-- Tiers:
--   I   sheet + moon edge, ground torus, knee swirl, dust, impacts, scorch.
--   II  brighter wider sheet, a second inner edge, motes, impact swirl,
--       wave echo and rays.
--   III swirl shell, Craters ring, impact bubble and rock kicks, seal at
--       the windup.
--   IV  gold edge, moon rising behind, light, frames, quake.
--
-- Remade 2026-10-21 on the guandao and the Hit window:
--   Windup (0 -> Hit, 0.63 s): part "Charge" rides the whole pole (butt ->
--     blade, WeaponFX.charge full): a dark beam under a jade one, motes along
--     the shaft and a glint on the crescent blade as it is wound back.
--   Release (Hit): the flash on the blade where the spin starts gets the shared
--     flare (cross glint, star-burst flipbook over ink, sparks).
--   Sweep (Hit -> Hit Stop + follow-through): beside the sheet (now over a dark
--     ink sheet) the real blade's own ribbon, glow and motes ("Edge", riding
--     the model's Base -> Tip), and every enemy the heading passes gets the
--     moon crescent flipbook through the body. Impacts already fire as the
--     heading passes, inside Hit -> Hit Stop.
-- Authored at radius 11, active 0.117 s (Hit -> Hit Stop at speed 1).
local B = _G.vfxBlocks
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local JADE = Color3.fromRGB(110, 230, 160) -- the technique colour (suggested def.color)
local DEEP = Color3.fromRGB(40, 176, 120)
local CORE = Color3.fromRGB(236, 255, 242)
local GOLD = Color3.fromRGB(255, 232, 170)
local INK = Color3.fromRGB(22, 54, 42)
local PALETTE = {
	color = JADE, core = CORE,
	ringColor = Color3.fromRGB(212, 255, 228), swirlColor = Color3.fromRGB(120, 230, 170), groundColor = Color3.fromRGB(170, 245, 200),
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
	slash = id(7216852121),
	mote = id(9841260273),
	knotRing = id(93858335764593), -- key-fret (meander) ring
	crescentFlip = id(13972642464), -- 4x4 flipbook: a thin crescent moon sweeping and fading
}
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local ONESHOT = Enum.ParticleFlipbookMode.OneShot

local RADIUS = 11
local REACH = 8.6 -- the blade's reach round the caster (sampled ~8)
local HEIGHT = 1.5 -- the sweep's height off the ground (the tip runs 0.6-4.6)
local HAND_AT = O * CFrame.new(-0.4, 1.6, 3.2) -- the hands wound back behind the left hip
local TIP_AT = O * CFrame.new(-6.5, 0.8, 5) -- the blade tip at Hit (behind-left, low)

local function trail(parent, name, a0, a1, color, transparency, life, light, width)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = color
	t.Transparency = transparency
	t.WidthScale = width or NS(1)
	t.Lifetime = life
	t.FaceCamera = false
	t.LightEmission, t.LightInfluence = light, 0
	t.MinLength = 0.05
	t.Enabled = false
	t.Parent = parent
	return t
end

-- The sweep: a part at the caster's centre, turned by the runtime; its
-- attachments sit along -Z (the blade's heading) so the Trails between
-- them draw the swept sheet and the moon edge.
B.BLOCKS.csSweep = function(root, tier, p)
	local sweep = B.part(root, "Sweep", O * CFrame.new(0, HEIGHT, 0))
	for k, v in {
		StartHeading = -126, -- degrees from facing, + to the right (the blade behind-left at Hit)
		SweepDegrees = 323, -- turned by Hit Stop (the heading falls: behind, right, front, left)
		FollowDegrees = 30, FollowTime = 0.05, -- carried on past Hit Stop
		Reach = REACH, Height = HEIGHT, AuthoredRadius = RADIUS,
		Tilt = 6, -- degrees: the sheet rises toward the front of the spin
	} do
		sweep:SetAttribute(k, v)
	end
	local inner = B.attach(sweep, "Inner", Vector3.new(0, 0, -2))
	local outer = B.attach(sweep, "Outer", Vector3.new(0, 0.15, -REACH))
	local rim0 = B.attach(sweep, "Rim0", Vector3.new(0, 0.1, -REACH + 0.45))
	local rim1 = B.attach(sweep, "Rim1", Vector3.new(0, 0.2, -REACH - 0.25))
	local edge = if tier >= 4 then GOLD else CORE
	-- dark under light: an ink sheet the jade one lies on
	trail(sweep, "SheetInk", inner, outer, CS(INK), NS({ KP(0, 0.5), KP(0.6, 0.65), KP(1, 1) }),
		({ 0.28, 0.32, 0.34, 0.38 })[tier], 0)
	-- the sheet: transparent near the shaft, solid at the blade
	trail(sweep, "Sheet", inner, outer, CS(DEEP, JADE), NS({ KP(0, ({ 0.35, 0.28, 0.22, 0.18 })[tier]), KP(0.5, 0.6), KP(1, 1) }),
		({ 0.26, 0.3, 0.32, 0.36 })[tier], 0.3, NS({ KP(0, 1), KP(1, 1) }))
	-- the moon edge at the blade's reach
	trail(sweep, "Edge", rim0, rim1, CS(edge, JADE), NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }),
		({ 0.32, 0.36, 0.4, 0.46 })[tier], 0.5)
	if tier >= 2 then
		local mid0 = B.attach(sweep, "Mid0", Vector3.new(0, 0.05, -REACH * 0.62))
		local mid1 = B.attach(sweep, "Mid1", Vector3.new(0, 0.1, -REACH * 0.62 - 0.35))
		trail(sweep, "InnerEdge", mid0, mid1, CS(CORE, JADE), NS({ KP(0, 0.25), KP(0.6, 0.5), KP(1, 1) }), 0.24, 0.45)
	end
	-- motes thrown off the blade while it turns
	local shed = B.emitter(outer, "Shed", {
		Texture = A.mote, Color = CS(CORE, JADE), SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ KP(0, 0.25), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.3, 0.5), Speed = R(4, 8), Drag = 3, LightEmission = 0.6, Rotation = R(0, 360),
		Rate = ({ 60, 80, 100, 130 })[tier],
	})
	shed:SetAttribute("Shed", true)
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = JADE
		light.Range = 20
		light.Brightness = 0
		light.Shadows = false
		light.Parent = sweep
	end
	return sweep
end

-- The cut wind at knee height and the scorched crescent left behind.
B.BLOCKS.csGround = function(root, tier, p)
	local ground = root:FindFirstChild("Ground")
	local sd = RADIUS * 2 * 0.95
	B.meshWave(ground, "KneeSwirl", {
		mesh = id(73349240058321), color = PALETTE.swirlColor,
		fromSize = Vector3.new(4, 0.5, 4), toSize = Vector3.new(sd, 1.3, sd),
		fromOffset = Vector3.new(0, 1.2, 0), toOffset = Vector3.new(0, 1.6, 0),
		fromTransparency = 0.2, toTransparency = 1, duration = 0.45, style = "Quart",
	})
	B.emitter(ground, "Scorch", B.flat({
		Texture = A.moon, Color = CS(INK), LightInfluence = 0.3,
		Size = NS(REACH * 0.95), Transparency = NS({ KP(0, 1), KP(0.05, 0.35), KP(0.6, 0.5), KP(1, 1) }),
		Lifetime = R(1.1 + tier * 0.2), Rotation = R(0), ZOffset = -0.5,
	}), { EmitCount = 1, EmitDelay = 0.08 })
	B.emitter(ground, "MoonMark", B.flat({
		Texture = A.moon, Color = CS(CORE, JADE),
		Size = NS({ KP(0, REACH * 0.7), KP(1, REACH * 1.05) }), Transparency = NS({ KP(0, 0.2), KP(0.5, 0.45), KP(1, 1) }),
		Lifetime = R(0.5), LightEmission = 0.4, Rotation = R(0), ZOffset = 0.2,
	}), { EmitCount = 1, EmitDelay = 0.06 })
	if tier >= 2 then
		B.emitter(ground, "Motes", {
			Texture = A.mote, Color = CS(CORE, JADE),
			Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
			Size = NS({ KP(0, 0.3), KP(0.5, 0.22), KP(1, 0) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.15), KP(1, 1) }),
			Lifetime = R(0.8, 1.2), Speed = R(2, 4), Drag = 1, LightEmission = 0.5, Rotation = R(0, 360),
		}, { EmitCount = ({ 0, 10, 14, 18 })[tier], EmitDelay = 0.12 })
	end
	return ground
end

-- IV: a jade-gold moon rising behind the caster.
B.BLOCKS.csMoon = function(root, tier, p)
	local ground = root:FindFirstChild("Ground")
	local moon = B.meshWave(ground, "Moon", {
		mesh = B.ASSETS.torusMesh, color = GOLD,
		fromSize = Vector3.new(2, 0.3, 2), toSize = Vector3.new(7.5, 0.75, 7.5),
		fromOffset = Vector3.new(0, 3, 2.5), toOffset = Vector3.new(0, 6, 3.5),
		rotation = Vector3.new(90, 0, 0), fromTransparency = 0.05, toTransparency = 1,
		duration = 1.0, style = "Quint", delay = 0.05,
	})
	moon:SetAttribute("FadeStyle", "Quart")
	B.emitter(ground, "MoonGlow", B.flat({
		Texture = A.moon, Color = CS(GOLD, JADE),
		Size = NS({ KP(0, 2), KP(0.3, 4.2), KP(1, 4.6) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.3), KP(0.7, 0.45), KP(1, 1) }),
		Lifetime = R(0.9), LightEmission = 0.45, Rotation = R(-30), ZOffset = -1,
		Acceleration = Vector3.new(0, 3, 0),
	}, Enum.NormalId.Back), { EmitCount = 1, EmitDelay = 0.05 })
	return moon
end

B.BLOCKS.csTip = function(root, tier, p)
	local tip = B.part(root, "Tip", TIP_AT)
	B.emitter(tip, "Flash", {
		Texture = B.ASSETS.star4, Color = CS(CORE),
		Size = NS({ KP(0, 0.4), KP(0.35, 1.8 + tier * 0.3), KP(1, 0) }), Transparency = NS(0),
		Lifetime = R(0.14), LightEmission = 0.7, Rotation = R(-15, 15), ZOffset = 1,
	}, { EmitCount = 1 })
	B.emitter(tip, "Glow", {
		Texture = B.ASSETS.glow, Color = CS(JADE),
		Size = NS({ KP(0, 1), KP(1, 2.2 + tier * 0.3) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		Lifetime = R(0.22), LightEmission = 0.4,
	}, { EmitCount = 1 })
	B.screenShake(root, tier, { parent = "Tip", magnitude = ({ 1, 1.4, 1.9, 2.5 })[tier], frames = tier >= 4 })
	return tip
end

-- The real blade's edge: the runtime moves Edge's Trails, Glow and Motes onto
-- the held model's Base -> Tip for the spin.
B.BLOCKS.csEdge = function(root, tier, p)
	return _G.vfxSpecs.BladeKit.edge(root, tier, {
		color = JADE, core = if tier >= 4 then GOLD else CORE, tail = DEEP,
		trailLife = { 0.2, 0.24, 0.28, 0.34 }, glowWidth = { 0.7, 0.9, 1.1, 1.3 }, moteRate = { 12, 18, 24, 32 },
	})
end

B.BLOCKS.csSlash = function(root, tier, p)
	local body = root:FindFirstChild("Impact"):FindFirstChild("Body")
	B.emitter(body, "SlashFlip", {
		Texture = A.crescentFlip, Color = CS(Color3.fromRGB(205, 255, 225)),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 2.4 + tier * 0.3), KP(1, 3.4 + tier * 0.4) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.15), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.5, Rotation = R(-8, 8), ZOffset = 3.2,
	}, { EmitCount = 1 })
	return B.emitter(body, "Slash", {
		Texture = A.slash, Color = CS(CORE, JADE),
		Size = NS({ KP(0, 1), KP(0.25, 2.8 + tier * 0.45), KP(1, 3.4 + tier * 0.5) }), Transparency = NS({ KP(0, 0), KP(0.55, 0.15), KP(1, 1) }),
		Lifetime = R(0.28), LightEmission = 0.55, Rotation = R(-8, 8), ZOffset = 3,
	}, { EmitCount = 1 })
end

B.BLOCKS.csImpact = function(root, tier, p)
	local wave = pal({ size = ({ 3.8, 4.6, 5.8, 7 })[tier], groundSize = ({ 4, 5, 6.2, 7.6 })[tier] })
	return B.impactStack(root, tier, { burst = pal(), wave = wave })
end

return {
	id = "CrescentSweep",
	root = { attrs = { AuthoredActive = 0.117, AuthoredRadius = RADIUS } },
	beats = {
		{ block = "bladeCharge", params = { color = JADE, core = CORE, ink = INK, width = 0.6, full = true } },
		{ block = "csTip" },
		{ block = "bladeFlare", params = { part = "Tip", color = JADE, core = CORE, ink = INK } },
		{ block = "csEdge" },
		{ block = "csSweep" },
		{ block = "groundShockwave", params = pal({ radius = RADIUS, color = JADE }) },
		{ block = "csGround" },
		{ block = "shockwaveShell", from = 3, params = { name = "Shell", mesh = id(73349240058321), from = Vector3.new(4, 0.6, 4), to = Vector3.new(RADIUS * 2, 1.4, RADIUS * 2), spin = 260, duration = 0.4, startTransparency = 0.25, startColor = JADE, endColor = CORE, y0 = 1, y1 = 1.4 } },
		{ block = "craterRing", from = 3, params = { radius = RADIUS - 1.5 } },
		{ block = "csMoon", from = 4 },
		{ block = "csImpact" },
		{ block = "csSlash" },
	},
}
