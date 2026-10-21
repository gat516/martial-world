--!nocheck
-- Lightning Talisman's templates (LightningTalisman_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Runtime: src/client/TechniqueFX/LightningTalisman.luau.
--
-- The shot (Fists.2: Hit 0.35, Hit Stop 0.433 of 0.70 s, played at 1.4x for
-- the 0.25 s cast windup, so the active window is only 0.06 s; damage lands on
-- the whole chain at Hit, and the bolts play on through recovery as a short
-- visual stagger). Sampled: the LEFT hand reaches back past the right
-- shoulder and is out in front-left, (-1.5, 3.8, -2.4) from the ground under
-- the root, at Hit, then follows through across the body.
--
-- I (levels 1-3), "the paper calls the bolt"
--   Windup (cast start -> Hit, caster only): violet motes gather into the
--   left hand, a gold thunder glyph (雷) brightens in the palm, small arcs
--   crackle round it.
--   Release (Hit): a violet-white star flash on the live left hand; the
--   talisman card (a real yellow paper part, red thunder glyph on both faces,
--   a Neon violet rim, a crackling trail, shed sparks) leaves the hand
--   tumbling end over end on a low arc to a point 3 studs above the first
--   target (0.08-0.22 s by distance).
--   Strike: the card flares (star flash, falling ash) and burns away in place
--   over 0.32 s while a jagged bolt slams down from it into the target. Bolts
--   are Beams with real width (a white core and a wide deep-violet glow per
--   segment) on a jittered attachment chain that re-rolls ("flickers") 3
--   times, snaps in, holds solid and thins out late: on screen 0.30 s.
--   Hops: every HopDelay (0.12 s) a bolt leaps from the last target to the
--   next in `chain` order, bowing up over the bodies (high near side to high
--   near side) so the jump reads.
--   Impact on every target: star flash, violet hit ring, sparks, the stood-up
--   Neon impact torus facing the bolt (0.26 s) and a violet ground shock
--   torus (0.34 s), plus crackling arcs flickering over the body (~0.4 s).
--   Finale (the last target): the impact one tier up, an electric ring, a
--   radial lightning splash on the ground (0.4 s), a camera shake.
--   Fizzle (no target): the card flies to max range (24) on a slight dip, or
--   stops at the wall or ground it meets, bursts (flash, impact torus, ground
--   shock, swirl at II+, radial splash, paper embers, crackle) and earths a
--   short bolt into the ground under it.
-- II (4-6), "the seal answers"
--   + one fork per bolt, sparks and an air ring off the release hand, a
--     scorch mark (1.6 s) under every target, a turning rune seal (1.2 s)
--     under the first target, impact swirl rings, LightningBeams sparks.
-- III (7-9), "twin strands"
--   + a double strand on every bolt, seals under every target, impact
--     bubbles, a closing seal on the palm in the windup, and a Craters rock
--     ring erupting at the finale.
-- IV (10), "heaven's answer"
--   + two forks per bolt, and the sky strike: a tall forked bolt from 55
--     studs up through the card into the first target, a violet Neon pillar
--     flash (0.4 s), a wide ground torus (0.5 s), a sunburst, the move's one
--     PointLight (flashed and faded over 0.45 s) and an Explosion quake; the
--     finale adds a swirl shell.
--
-- Game Module: with it, each bolt's main core is the LightningBeams add-on
-- (Neon cylinder bolt, pulse 1/12 s, sparks II+) from the Bolt part's Arc
-- attachment; the glow, second strand and forks stay Beams, and the shakes
-- are ScreenEffects. Without it everything is Beams and CombatEffects.shake.
--
-- Root attributes (read by the runtime): HopDelay, Strands, Forks, BoltWidth,
-- BoltLife, Segments, Jitter, Flickers, CardSpeed, SealTargets, SkyStrike.
-- Parts: Windup (CombatEffects.windup), Hand (release), Card, Bolt (Beam
-- looks + Arc), Impact, Finale, Fizzle, Sky (IV).
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local B = _G.vfxBlocks
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local VIOLET = Color3.fromRGB(200, 180, 255) -- def.color
local CORE = Color3.fromRGB(246, 242, 255)
local DEEP = Color3.fromRGB(150, 120, 255)
local PAPER = Color3.fromRGB(240, 208, 126)
local INK = Color3.fromRGB(176, 28, 34)
local SCORCH = Color3.fromRGB(46, 34, 66)
local EMBER = Color3.fromRGB(255, 190, 110)

local LT = {
	glyph = id(132774975653552), -- white "thunder" meander glyph (talisman ink)
	arc = id(882168791), -- single jagged arc, transparent
	arc2 = id(6127835958), -- bright forked arc
	elecRing = id(112496740337235), -- ring of lightning
	radial = id(301851161), -- radial lightning splash
	seal = id(129093523368188), -- rune glyph ring
}

local COLORS = {
	color = VIOLET, core = CORE, ringColor = Color3.fromRGB(176, 146, 255),
	groundColor = Color3.fromRGB(156, 122, 255), swirlColor = Color3.fromRGB(140, 110, 250),
}
local function merged(extra)
	local t = table.clone(COLORS)
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

-- crackling arcs flickering over a body (one emit; the Transparency wave is
-- the flicker, the random Rotation/Size makes each arc different)
local function crackle(parent, tier, count, size)
	return B.emitter(parent, "Crackle", {
		Texture = LT.arc, Color = CS(Color3.fromRGB(226, 216, 255), DEEP), LightEmission = 0.55,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NS({ KP(0, size * 0.6), KP(0.2, size), KP(1, size * 0.8) }),
		Transparency = NS({ KP(0, 0), KP(0.15, 0.7), KP(0.25, 0), KP(0.4, 0.8), KP(0.5, 0.05), KP(0.7, 0.9), KP(0.8, 0.2), KP(1, 1) }),
		Lifetime = R(0.3, 0.45), Rotation = R(0, 360), ZOffset = 2.4,
	}, { EmitCount = count })
end

-- ---------------------------------------------------------------- custom blocks

-- The talisman card: paper part, glyph decals, violet rim, trail and sparks.
-- Everything starts hidden/disabled; the runtime shows it for the flight.
local function card(root, tier, p)
	local c = B.part(root, "Card", O * CFrame.new(-1.5, 3.8, -2.4), Vector3.new(1, 1.7, 0.05))
	c.Material = Enum.Material.SmoothPlastic
	c.Color = PAPER
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local d = Instance.new("Decal")
		d.Name = face.Name
		d.Face = face
		d.Texture = LT.glyph
		d.Color3 = INK
		d.Transparency = 1
		d.Parent = c
	end
	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Anchored, rim.CanCollide, rim.CanQuery, rim.CanTouch, rim.CastShadow = true, false, false, false, false
	rim.Material = Enum.Material.Neon
	rim.Color = VIOLET
	rim.Size = Vector3.new(1.18, 1.88, 0.03)
	rim.Transparency = 1
	rim.CFrame = c.CFrame
	rim.Parent = c
	local a0 = B.attach(c, "TrailTop", Vector3.new(0, 0.75, 0))
	local a1 = B.attach(c, "TrailBottom", Vector3.new(0, -0.75, 0))
	local trail = Instance.new("Trail")
	trail.Name = "Trail"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = CS(CORE, DEEP)
	trail.Transparency = NS({ KP(0, 0.15), KP(1, 1) })
	trail.WidthScale = NS({ KP(0, 1), KP(1, 0.2) })
	trail.Lifetime = 0.12 + tier * 0.02
	trail.LightEmission = 0.6
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = c
	-- sparks shed while it flies (Rate, enabled by the runtime during flight)
	local sparks = B.emitter(c, "Sparks", {
		Texture = B.ASSETS.spindle, Color = CS(CORE, VIOLET), Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0.18), KP(1, 0) }), Squash = NS(2),
		Lifetime = R(0.1, 0.18), Speed = R(6, 12), Drag = 6, LightEmission = 0.6,
	})
	sparks.Rate = ({ 30, 40, 50, 60 })[tier]
	local glow = B.emitter(c, "Aura", {
		Texture = B.ASSETS.glow, Color = CS(VIOLET), LightEmission = 0.5,
		Size = NS({ KP(0, 1.1), KP(1, 0.6) }), Transparency = NS({ KP(0, 0.45), KP(1, 1) }),
		Lifetime = R(0.12), LockedToPart = true,
	})
	glow.Rate = 30
	-- the flare when the card calls the strike (the runtime emits it once)
	B.emitter(c, "Flare", {
		Texture = B.ASSETS.star4, Color = CS(CORE), LightEmission = 0.8,
		Size = NS({ KP(0, 0.5), KP(0.3, 2.2 + tier * 0.4), KP(1, 0) }), Transparency = NS(0),
		Lifetime = R(0.18), Rotation = R(-20, 20), ZOffset = 1.5,
	}, { EmitCount = 1 })
	B.emitter(c, "Ash", {
		Texture = B.ASSETS.spindle, Color = CS(EMBER, INK), LightEmission = 0.3,
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -6, 0),
		Size = NS({ KP(0, 0.14), KP(1, 0.04) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.3), KP(1, 1) }),
		Lifetime = R(0.4, 0.7), Speed = R(2, 5), Drag = 2, Rotation = R(0, 360), RotSpeed = R(-200, 200),
	}, { EmitCount = 4 + tier })
	return c
end

-- The bolt look: Beam templates the runtime clones onto each jittered segment
-- (Core: thin white-violet, Glow: wide soft violet), plus the LightningBeams
-- Arc. Unattached here.
local function bolt(root, tier, p)
	local holder = B.part(root, "Bolt", O)
	local function beam(name, props)
		local b = Instance.new("Beam")
		b.Name = name
		b.Segments = 1
		b.FaceCamera = true
		b.LightInfluence = 0
		b.Enabled = false
		for k, v in props do
			b[k] = v
		end
		b.Parent = holder
		return b
	end
	beam("Core", {
		Color = CS(CORE), LightEmission = 0.8, Brightness = 1, Transparency = NS(0),
		Width0 = 1, Width1 = 1, -- the runtime sets widths from BoltWidth
	})
	beam("Glow", {
		Texture = B.ASSETS.glow, TextureMode = Enum.TextureMode.Stretch, TextureLength = 1,
		Color = CS(DEEP), LightEmission = 0.45, Transparency = NS(0.25), Width0 = 1, Width1 = 1,
	})
	-- LightningBeams add-on (Game Module only): an attachment with a "B"
	-- endpoint child draws a pulse-driven bolt of Neon cylinders from it to B.
	-- The runtime clones Arc per strike, sets B, emits it and then skips its
	-- own Core strand (the Glow beams and the second strand still draw).
	local arc = B.attach(holder, "Arc", Vector3.zero, {
		Duration = ({ 0.3, 0.33, 0.36, 0.4 })[tier], Thickness = ({ 0.3, 0.36, 0.42, 0.5 })[tier],
		PartCount = ({ 10, 12, 12, 14 })[tier], PulseSpeed = 12, FadeLength = 0.25, Frequency = 1.2, Speed = 6,
		Radius = R(0, ({ 0.8, 0.9, 1, 1.2 })[tier]), ThicknessMultiplier = R(0.4, 1),
		Color = CORE, MaxSparkCount = ({ 0, 2, 3, 4 })[tier], SparkDistance = R(1, 2.5),
	})
	B.attach(arc, "B", Vector3.new(0, -4, 0))
	return holder
end

-- One target hit: flash, hit ring, sparks, the 3D impact torus and ground
-- shock (swirl/bubble by tier), crackling arcs on the body, II+ scorch and a
-- rune seal (the runtime limits seals to SealTargets).
local function impact(root, tier, p)
	local name = p.part or "Impact"
	local t = p.tier or tier
	local part = B.impactBurst(root, t, merged({ part = name }))
	B.impactShockwave(root, t, merged({ part = name, size = p.size, groundSize = p.groundSize }))
	local body = part:FindFirstChild("Body")
	crackle(body, t, p.crackles or ({ 3, 4, 5, 6 })[t], p.crackleSize or (1.1 + t * 0.15))
	if t >= 2 and p.scorch ~= false then
		B.emitter(part, "Scorch", B.flat({
			Texture = B.ASSETS.crack, Color = CS(SCORCH), LightInfluence = 0.4,
			Size = NS(1.2 + t * 0.35), Transparency = NS({ KP(0, 1), KP(0.04, 0.15), KP(0.6, 0.3), KP(1, 1) }),
			Lifetime = R(1.6), Rotation = R(0, 360), ZOffset = 0.05,
		}), { EmitCount = 1 })
	end
	if t >= 2 and p.seal ~= false then
		B.emitter(part, "Seal", B.flat({
			Texture = LT.seal, Color = CS(VIOLET), LightEmission = 0.45,
			Size = NS({ KP(0, 0.8), KP(0.2, 2.4 + t * 0.3), KP(1, 2.8 + t * 0.3) }), Transparency = NS({ KP(0, 0.15), KP(0.55, 0.3), KP(1, 1) }),
			Lifetime = R(1.2), RotSpeed = R(90), Rotation = R(0, 360), ZOffset = 0.2,
		}), { EmitCount = 1 })
	end
	return part
end

-- The last strike: the impact one tier up plus an electric ring, a radial
-- splash on the ground, a camera shake, III+ a rock ring, IV a swirl shell.
local function finale(root, tier, p)
	local t = math.min(tier + 1, 4)
	local part = impact(root, tier, { part = "Finale", tier = t, size = ({ 4.8, 5.9, 7.2, 8.6 })[tier], groundSize = ({ 5.5, 6.8, 8.4, 10 })[tier], crackles = ({ 5, 6, 7, 8 })[tier] })
	local body = part:FindFirstChild("Body")
	B.emitter(body, "ElecRing", {
		Texture = LT.elecRing, Color = CS(CORE, VIOLET), LightEmission = 0.7,
		Size = NS({ KP(0, 0.6), KP(0.35, 3 + tier * 0.5), KP(1, 3.6 + tier * 0.6) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }),
		Lifetime = R(0.36), Rotation = R(0, 360), RotSpeed = R(-90, 90), ZOffset = 3,
	}, { EmitCount = 1 })
	B.emitter(part, "Splash", B.flat({
		Texture = LT.radial, Color = CS(VIOLET), LightEmission = 0.6,
		Size = NS({ KP(0, 1), KP(0.25, 3 + tier * 0.6), KP(1, 3.4 + tier * 0.7) }), Transparency = NS({ KP(0, 0), KP(0.5, 0.35), KP(1, 1) }),
		Lifetime = R(0.4), Rotation = R(0, 360), ZOffset = 0.3,
	}), { EmitCount = 1 })
	B.screenShake(root, tier, { parent = "Finale", name = "Shake", magnitude = ({ 1, 1.4, 2, 2.6 })[tier], falloff = "20~70" })
	if tier >= 3 then
		B.craterRing(root, tier, {
			parent = "Finale", name = "RockRing", radius = 2.8,
			attrs = { Count = tier == 4 and 8 or 6, Duration = 0.12, Variance = 0.6, Size = Vector3.new(1, 0.8, 0.9), Lifetime = R(0.9, 1.2), RaycastDistance = 8 },
		})
	end
	if tier >= 4 then
		B.meshWave(part, "Shell", {
			mesh = B.ASSETS.swirlMesh, color = CORE,
			fromSize = Vector3.new(2, 0.6, 2), toSize = Vector3.new(11, 1.4, 11),
			fromOffset = Vector3.new(0, 0.5, 0), toOffset = Vector3.new(0, 0.9, 0),
			fromTransparency = 0.35, toTransparency = 1, duration = 0.4, style = "Quart",
		})
	end
	return part
end

-- No target: the card bursts where it ends and earths a bolt into the ground.
local function fizzle(root, tier, p)
	local part = B.impactBurst(root, tier, merged({ part = "Fizzle" }))
	B.impactShockwave(root, tier, merged({ part = "Fizzle", size = ({ 3.6, 4.4, 5.2, 6.2 })[tier], groundSize = ({ 4.6, 5.6, 6.8, 8 })[tier], swirl = tier >= 2, bubble = tier >= 3 }))
	B.emitter(part:FindFirstChild("Body"), "Embers", {
		Texture = B.ASSETS.spindle, Color = CS(Color3.fromRGB(255, 236, 190), EMBER), LightEmission = 0.5,
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -14, 0),
		Size = NS({ KP(0, 0.16), KP(1, 0.05) }), Squash = NS(1.2), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.5, 0.8), Speed = R(6, 12), Drag = 2, Rotation = R(0, 360), RotSpeed = R(-200, 200), ZOffset = 2,
	}, { EmitCount = 6 + tier * 2 })
	crackle(part:FindFirstChild("Body"), tier, 2 + tier, 1)
	B.emitter(part, "Splash", B.flat({
		Texture = LT.radial, Color = CS(VIOLET), LightEmission = 0.6,
		Size = NS({ KP(0, 0.8), KP(0.25, 2.4 + tier * 0.5), KP(1, 2.8 + tier * 0.6) }), Transparency = NS({ KP(0, 0), KP(0.5, 0.35), KP(1, 1) }),
		Lifetime = R(0.4), Rotation = R(0, 360), ZOffset = 0.3,
	}), { EmitCount = 1 })
	return part
end

-- IV: the sky strike on the first target (the runtime draws the tall bolt).
local function sky(root, tier, p)
	local part = B.part(root, "Sky", O * CFrame.new(0, 0.2, -6))
	local pillar = Instance.new("Model")
	pillar.Name = "Pillar"
	for k, v in {
		MeshWave = true, FromSize = Vector3.new(60, 1.3, 1.3), ToSize = Vector3.new(60, 0.1, 0.1),
		FromOffset = Vector3.new(0, 30, 0), ToOffset = Vector3.new(0, 30, 0), Rotation = Vector3.new(0, 0, 90),
		FromTransparency = 0.3, ToTransparency = 1, Duration = 0.4, Style = "Quad", FadeStyle = "Quart",
	} do
		pillar:SetAttribute(k, v)
	end
	local cyl = Instance.new("Part")
	cyl.Name = "Mesh"
	cyl.Shape = Enum.PartType.Cylinder
	cyl.Anchored, cyl.CanCollide, cyl.CanQuery, cyl.CanTouch, cyl.CastShadow = true, false, false, false, false
	cyl.Material = Enum.Material.Neon
	cyl.Color = Color3.fromRGB(196, 172, 255)
	cyl.Transparency = 1
	cyl.Parent = pillar
	pillar.Parent = part
	B.meshWave(part, "SkyWave", {
		mesh = B.ASSETS.torusMesh, color = COLORS.ringColor,
		fromSize = Vector3.new(2, 0.3, 2), toSize = Vector3.new(16, 1.5, 16),
		fromOffset = Vector3.new(0, 0.3, 0), toOffset = Vector3.new(0, 0.3, 0),
		fromTransparency = 0.3, toTransparency = 1, duration = 0.5, style = "Quart",
	})
	B.emitter(part, "Rays", B.flat({
		Texture = B.ASSETS.rays, Color = CS(VIOLET), LightEmission = 0.5,
		Size = NS({ KP(0, 2), KP(1, 8) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.4), Rotation = R(0, 360),
	}), { EmitCount = 1 })
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = VIOLET
	light.Range = 26
	light.Brightness = 0 -- the runtime flashes it and fades it out
	light.Shadows = false
	light.Parent = part
	B.screenShake(root, tier, { parent = "Sky", name = "Quake", preset = "Explosion", falloff = "20~80" })
	return part
end

-- the glyph brightening in the palm during the windup
local function glyph(root, tier, p)
	local windup = root:FindFirstChild("Windup")
	return B.emitter(windup, "Glyph", B.flat({
		Texture = LT.glyph, Color = CS(PAPER), LightEmission = 0.5,
		Size = NS({ KP(0, 0.2), KP(1, 0.55 + tier * 0.05) }), Transparency = NS({ KP(0, 1), KP(0.5, 0.4), KP(1, 0) }),
		Lifetime = R(0.25), LockedToPart = true, ZOffset = 1,
	}, Enum.NormalId.Front), { EmitCount = 1 })
end

-- crackling sparks around the hand during the windup
local function handArcs(root, tier, p)
	local windup = root:FindFirstChild("Windup")
	return crackle(windup, tier, ({ 2, 3, 3, 4 })[tier], 0.7)
end

for name, fn in { card = card, bolt = bolt, impact = impact, finale = finale, fizzle = fizzle, sky = sky, glyph = glyph, handArcs = handArcs } do
	B.BLOCKS["LightningTalisman." .. name] = fn
end

local function per(list)
	return list
end

local spec
spec = {
	id = "LightningTalisman",
	root = { attrs = { AuthoredWindup = 0.25 } },
	tierAttrs = {
		HopDelay = per({ 0.12, 0.11, 0.1, 0.09 }),
		Strands = per({ 1, 1, 2, 2 }),
		Forks = per({ 0, 1, 1, 2 }),
		BoltWidth = per({ 0.42, 0.46, 0.5, 0.56 }),
		BoltLife = per({ 0.3, 0.33, 0.36, 0.4 }),
		Segments = per({ 5, 6, 6, 7 }),
		Jitter = per({ 0.9, 1, 1.1, 1.25 }),
		Flickers = per({ 3, 3, 3, 4 }),
		CardSpeed = per({ 110, 115, 120, 125 }),
		SealTargets = per({ 0, 1, 9, 9 }),
		SkyStrike = per({ false, false, false, true }),
	},
	beats = {
		-- windup: qi sparks and the glyph gather into the left hand
		{ block = "handGather", params = { color = VIOLET, core = CORE, windup = 0.25 } },
		{ block = "LightningTalisman.glyph" },
		{ block = "LightningTalisman.handArcs" },
		-- release off the left hand
		{ block = "releaseFlash", params = { part = "Hand", at = O * CFrame.new(-1.5, 3.8, -2.4), color = VIOLET, core = CORE, light = false } },
		{ block = "airShockwave", from = 2, params = { part = "Hand", count = 1, color = COLORS.ringColor } },
		-- the card and the bolt look
		{ block = "LightningTalisman.card" },
		{ block = "LightningTalisman.bolt" },
		-- per-target impact, the finale on the last, the fizzle when nothing is hit
		{ block = "LightningTalisman.impact" },
		{ block = "LightningTalisman.finale" },
		{ block = "LightningTalisman.fizzle" },
		-- IV: the sky strike
		{ block = "LightningTalisman.sky", from = 4 },
	},
}

-- buildFromSpec plus the per-tier tuning attributes on each root:
-- _G.vfxSpecs.LightningTalisman.build(parent)
function spec.build(parent)
	local built = B.buildFromSpec(spec, parent)
	for tier, root in built do
		for k, list in spec.tierAttrs do
			root:SetAttribute(k, list[tier])
		end
	end
	return built
end

return spec
