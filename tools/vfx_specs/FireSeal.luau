--!nocheck
-- Fire Seal's templates (FireSeal_T1..T4). Build with FireSeal.build(parent)
-- (not plain vfxBlocks.buildFromSpec: this spec adds its own blocks in
-- `blocks`, which build() resolves before the shared ones). Runtime:
-- src/client/TechniqueFX/FireSeal.luau.
--
-- Gameplay: kind "zone", centre 8 studs ahead of the caster (def.offset),
-- radius 8, a damage tick every 0.5 s for 4 s (8 ticks, the first at
-- release). Fists.4 at 0.7x (windup 0.5 s, active 0.214 s, recovery 0.2 s);
-- the left hand strikes. Authored at radius 8, active 0.214 s; the template
-- pivot is the ground under the caster facing -Z, the zone centre at (0,0,-8).
--
-- THE SHOT, tier by tier
--
-- I (levels 1-3), "a seal of embers"
--   Windup (0.5 s, caster only): orange motes spiral into the left palm, a
--   coal-red charge glow swells on it.
--   Release (Hit): an orange star flash and glow on the palm; the seal leaves
--   the hand as a projectile: a Neon fire core with a burning trail and a
--   spinning ring around it, diving to the zone centre in ~0.24 s.
--   Landing: a fire-tinted impactStack on the ground at the centre (star
--   flash, puff, spiky ring, ember sparks, the stood-up 3D impact ring and a
--   ground shock torus), and a fat Neon torus (LandWave) rolls out from the
--   centre to the zone edge in 0.45 s, solid at first and fading late.
--   Hold (to 4 s): a raised Neon Rim torus at exactly radius 8 marks the
--   zone; the rune circle glyph turns slowly on the ground inside it (kept
--   translucent so enemy telegraphs stay readable); stylised flame tongues
--   lick up around the rim; embers drift up from the disc.
--   Each 0.5 s tick: a PulseRing torus sweeps centre -> rim (0.38 s), the rim
--   flares bright, and every enemy inside gets a burn hit (flame flare,
--   embers, a small upright impact ring and a ground ring) + a red flash.
--   End (4 s): the hold fades over 0.35 s while a terminal burst pops: a
--   torus out past the rim, a puff of embers and a ring of flames.
-- II (4-6), "the seal turns"
--   + Spline qi wisps in the windup, sparks off the release, impact dust.
--   + a swirl ring (InnerSeal, radius ~6) spins clockwise inside the rim.
--   + pulses flare a ring of flame tongues from the rim; burn hits get an
--     upright ring that is bigger and a little fuller.
-- III (7-9), "the wall of flame"
--   + a closing seal on the palm in the windup; the landing kicks a Craters
--     rock ring and leaves a scorch; a small ScreenEffects shake.
--   + a second, counter-rotating seal (CounterSeal swirl ring and a second
--     rune glyph) spins the other way.
--   + an edge FlameWall: a crown of Neon flame spikes stands on the rim and
--     flickers, with taller tongues; each pulse throws up a PulseCrown of
--     spikes; burn hits raise a flame tongue under the target.
-- IV (10), "the pillar"
--   + at landing a flame Pillar (a twisted spike column ~22 studs tall)
--     erupts from the centre with a column of fire, and the one light of the
--     move (a PointLight on the Zone) flashes, then glows low under the seal.
--   + the finale: a big torus, a flat star of spikes, an erupting spike crown,
--     a ring of flames and an Explosion shake as the seal breaks.
--
-- Parts (runtime contract, see TechniqueFX/FireSeal.luau):
--   Windup   handGather, played at cast start by CombatEffects.windup.
--   Palm     the release flash + the Bolt/BoltRing MeshWaves (Phase "active";
--            runtime aims ToOffset at the zone centre).
--   Land     the landing impact at the centre (runtime sets its EmitDelay to
--            the bolt's flight time).
--   Zone     sustained: enabled from landing to def.seconds (EmitDuration 4
--            for the plugin's T button). Children MeshParts Rim, InnerSeal,
--            CounterSeal, FlameWall are driven (fade, spin, flicker) by code.
--            Glyph emitters live on Land (one long particle each).
--   Pulse    one tick's pulse, cloned per tick.
--   Impact   one burn hit (Body attachment), cloned per target per tick.
--   Finale   the terminal burst at def.seconds.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local V = Vector3.new
local id = function(n)
	return "rbxassetid://" .. n
end

local FIRE = Color3.fromRGB(255, 128, 54) -- def.color is (255,120,60)
local CORE = Color3.fromRGB(255, 224, 150)
local EMBER = Color3.fromRGB(255, 176, 80)
local DEEP = Color3.fromRGB(232, 70, 36)
local RIM = Color3.fromRGB(255, 120, 48)
local SCORCH = Color3.fromRGB(60, 36, 26)
-- Neon blooms toward yellow-white, so 3D parts use deeper tones than particles
local N_RIM = Color3.fromRGB(235, 62, 18)
local N_FIRE = Color3.fromRGB(255, 88, 26)
local N_CORE = Color3.fromRGB(255, 150, 62)
local N_DEEP = Color3.fromRGB(196, 34, 16)

local A = {
	flame = id(265788038), -- stylised white flame silhouette (tinted)
	flames4 = id(78723566587645), -- 4x4 cartoon fire flipbook (baked orange)
	rune = id(83667248904000), -- rune circle
	runeSwirl = id(129093523368188), -- swirl of runes
	glow = id(867619398),
	star12 = id(243728206),
	spindle = id(7814053668),
	crater = id(90713203428310),
	torus = id(471124075), -- 150 x 9.51 x 150
	swirlRing = id(122217820569960),
	swirlRing2 = id(73349240058321),
	crownTall = id(4316118084), -- tall spike crown
	crownLow = id(489415286), -- low spike crown
	spikeStar = id(89195313060285), -- flat star of spikes
	spikeBurst = id(111460667532043), -- erupting spike cluster
	column = id(112724324039362), -- tall twisted column
}

local CENTRE = CFrame.new(0, 0.2, -8)
local RADIUS = 8
local TUBE = 0.0634 -- torus Y per stud of diameter for a round tube

local FIREPAL = { color = FIRE, core = CORE }

local function B()
	return _G.vfxBlocks
end

local function wave(parent, name, p, fadeStyle)
	local w = B().meshWave(parent, name, p)
	w:SetAttribute("FadeStyle", fadeStyle or "Quint")
	return w
end

local function emitter(parent, name, props, attrs)
	return B().emitter(parent, name, props, attrs)
end

local function flat(props, dir)
	return B().flat(props, dir)
end

local function flameTongues(rate, size, life)
	return {
		Texture = A.flame, Color = CS({ ColorSequenceKeypoint.new(0, EMBER), ColorSequenceKeypoint.new(0.3, FIRE), ColorSequenceKeypoint.new(1, DEEP) }),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, ShapePartial = 1,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6),
		Size = NS({ KP(0, size * 0.5), KP(0.3, size), KP(1, size * 0.2) }),
		Transparency = NS({ KP(0, 0.5), KP(0.2, 0.05), KP(0.75, 0.2), KP(1, 1) }),
		Lifetime = R(life * 0.8, life), Speed = R(2.5, 4.5), Acceleration = V(0, 3, 0),
		Rate = rate, LightEmission = 0.2, LightInfluence = 0.15, Rotation = R(-8, 8), ZOffset = 0.3,
	}
end

local blocks = {}

-- the release flash on the palm + the seal thrown as a projectile
function blocks.throw(root, tier, p)
	local palm = B().releaseFlash(root, tier, { color = FIRE, core = CORE, light = false })
	local d = ({ 1.1, 1.25, 1.4, 1.6 })[tier]
	local bolt = wave(palm, "Bolt", {
		mesh = "Ball", material = Enum.Material.Neon, color = N_CORE,
		fromSize = V(0.5, 0.5, 0.5), toSize = V(d, d, d),
		fromOffset = V(0, 0, -0.4), toOffset = V(0, -2.8, -6.4), -- runtime aims it at the zone centre
		fromTransparency = 0, toTransparency = 0.15, duration = 0.24, style = "Sine", phase = "active",
	}, "Quint")
	-- a burning trail behind the core (the clone moves, so the trail draws)
	local mesh = bolt:FindFirstChild("Mesh")
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "T0", "T1"
	a0.Position, a1.Position = V(0, 0.35, 0), V(0, -0.35, 0)
	a0.Parent, a1.Parent = mesh, mesh
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = CS(CORE, DEEP)
	trail.Transparency = NS({ KP(0, 0.05), KP(1, 1) })
	trail.WidthScale = NS({ KP(0, 1), KP(1, 0.2) })
	trail.Lifetime = 0.22
	trail.LightEmission = 0.5
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = mesh
	-- the seal itself: a ring spinning around the core on the way down
	local rd = ({ 1.8, 2.1, 2.4, 2.8 })[tier]
	wave(palm, "BoltRing", {
		mesh = A.torus, color = N_FIRE,
		fromSize = V(0.6, 0.12, 0.6), toSize = V(rd, rd * 0.12, rd),
		fromOffset = V(0, 0, -0.4), toOffset = V(0, -2.8, -6.4),
		rotation = V(90, 0, 0), fromTransparency = 0.1, toTransparency = 0.3, duration = 0.24, style = "Sine", phase = "active",
	}, "Quint")
	return palm
end

-- where the seal lands: an impactStack on the ground + the LandWave to the rim
-- + (III+) rocks and a scorch, (IV) the flame pillar and its fire column
function blocks.landing(root, tier, p)
	local land = B().part(root, "Land", CENTRE)
	B().impactBurst(root, tier, { part = "Land", color = FIRE, core = CORE })
	B().impactShockwave(root, tier, {
		part = "Land", ringColor = N_CORE, swirlColor = N_FIRE, groundColor = N_FIRE,
		size = ({ 4.2, 5.2, 6.4, 8 })[tier], groundSize = ({ 5, 6, 7.5, 9 })[tier], bubble = tier >= 4,
	})
	local body = land:FindFirstChild("Body")
	body.Position = V(0, 1.2, 0)
	wave(land, "LandWave", {
		mesh = A.torus, color = N_FIRE,
		fromSize = V(2, 2 * TUBE * 1.6, 2), toSize = V(RADIUS * 2 + 1, 1.25, RADIUS * 2 + 1),
		fromOffset = V(0, 0.35, 0), toOffset = V(0, 0.35, 0),
		fromTransparency = 0.05, toTransparency = 1, duration = 0.45, style = "Quart",
	})
	-- the glyph(s): one long particle each; runtime stretches Lifetime to the zone
	emitter(land, "Glyph", flat({
		Texture = A.rune, Color = CS(FIRE),
		Size = NS({ KP(0, 2), KP(0.06, RADIUS * 0.98), KP(1, RADIUS * 0.98) }),
		Transparency = NS({ KP(0, 1), KP(0.04, 0.35), KP(0.9, 0.45), KP(1, 1) }),
		Lifetime = R(3.86), LightEmission = 0.3, Brightness = 1.2, RotSpeed = R(14), Rotation = R(0, 360), ZOffset = -0.2,
	}), { EmitCount = 1 })
	if tier >= 3 then
		emitter(land, "Glyph2", flat({
			Texture = A.runeSwirl, Color = CS(EMBER),
			Size = NS({ KP(0, 1), KP(0.06, RADIUS * 0.62), KP(1, RADIUS * 0.62) }),
			Transparency = NS({ KP(0, 1), KP(0.05, 0.4), KP(0.9, 0.5), KP(1, 1) }),
			Lifetime = R(3.86), LightEmission = 0.35, RotSpeed = R(-32), Rotation = R(0, 360), ZOffset = -0.1,
		}), { EmitCount = 1 })
	end
	-- a ring of flames thrown out along the ground as it lands
	emitter(land, "FlameBurst", {
		Texture = A.flames4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = CS(Color3.new(1, 1, 1)), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Shape = Enum.ParticleEmitterShape.Box,
		Size = NS({ KP(0, 0.8), KP(0.4, 1.8 + tier * 0.2), KP(1, 0.6) }), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.3), KP(1, 1) }),
		Lifetime = R(0.4, 0.55), Speed = R(16, 22), Drag = 4, LightEmission = 0.3, ZOffset = 0.5,
	}, { EmitCount = ({ 8, 10, 12, 14 })[tier] })
	if tier >= 3 then
		B().craterRing(root, tier, { parent = "Land", radius = 3.2, attrs = { Count = tier == 4 and 9 or 6, Duration = 0.12, Variance = 0.8, Size = V(1.1, 0.8, 1) } })
		emitter(land, "Scorch", flat({
			Texture = A.crater, Color = CS(SCORCH), LightInfluence = 0.4,
			Size = NS(tier == 4 and 3.6 or 2.8), Transparency = NS({ KP(0, 1), KP(0.03, 0.15), KP(0.8, 0.3), KP(1, 1) }),
			Lifetime = R(3.8), Rotation = R(0, 360), ZOffset = -0.4,
		}), { EmitCount = 1 })
		B().screenShake(root, tier, { parent = "Land", magnitude = ({ 0, 0, 1.6, 2.2 })[tier], falloff = "20~70" })
	end
	if tier >= 4 then
		wave(land, "Pillar", {
			mesh = A.column, color = N_FIRE,
			fromSize = V(2.5, 3, 2.5), toSize = V(6, 22, 6),
			fromOffset = V(0, 1.5, 0), toOffset = V(0, 11, 0),
			fromTransparency = 0.1, toTransparency = 1, duration = 0.7, style = "Quart",
		})
		wave(land, "PillarCore", {
			mesh = A.crownTall, color = N_CORE,
			fromSize = V(3, 1, 3), toSize = V(4.5, 14, 4.5),
			fromOffset = V(0, 0.5, 0), toOffset = V(0, 7, 0),
			fromTransparency = 0.2, toTransparency = 1, duration = 0.55, style = "Quart",
		})
		emitter(land, "Column", {
			Texture = A.flames4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = CS(Color3.new(1, 1, 1)), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8),
			Shape = Enum.ParticleEmitterShape.Disc,
			Size = NS({ KP(0, 1.5), KP(0.5, 2.6), KP(1, 1) }), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.35), KP(1, 1) }),
			Lifetime = R(0.5, 0.7), Speed = R(26, 36), Drag = 2, LightEmission = 0.3, ZOffset = 0.5,
		}, { EmitCount = 14 })
	end
	return land
end

-- the sustained zone: rim, seals, flame wall (MeshParts driven by code) and
-- the enabled emitters (flame tongues, embers)
function blocks.zone(root, tier, p)
	local zone = B().part(root, "Zone", CENTRE, V(RADIUS * 2, 0.2, RADIUS * 2))
	zone:SetAttribute("EmitDuration", 4)
	-- 3D: the raised rim at exactly the gameplay radius (tube centre on it)
	local rim = B().mesh(A.torus, zone, "Rim", V(RADIUS * 2, 0.8, RADIUS * 2), CENTRE * CFrame.new(0, 0.25, 0), N_RIM)
	rim:SetAttribute("Show", 0.15)
	if tier >= 2 then
		local s = B().mesh(A.swirlRing, zone, "InnerSeal", V(12.5, 0.9, 12.5), CENTRE * CFrame.new(0, 0.3, 0), N_FIRE)
		s:SetAttribute("Show", 0.3)
		s:SetAttribute("Spin", 50)
	end
	if tier >= 3 then
		local s = B().mesh(A.swirlRing2, zone, "CounterSeal", V(8, 0.8, 8), CENTRE * CFrame.new(0, 0.35, 0), N_CORE)
		s:SetAttribute("Show", 0.35)
		s:SetAttribute("Spin", -80)
		local h = tier >= 4 and 4 or 3.2
		local w = B().mesh(A.crownTall, zone, "FlameWall", V(RADIUS * 2 + 0.6, h, RADIUS * 2 + 0.6), CENTRE * CFrame.new(0, h / 2 - 0.1, 0), N_DEEP)
		w:SetAttribute("Show", 0.5)
		w:SetAttribute("Spin", 12)
		w:SetAttribute("Flicker", 0.18)
	end
	-- the rim's flame tongues: a Disc emitter's surface is its edge
	emitter(zone, "RimFlames", flameTongues(({ 12, 14, 16, 20 })[tier], 1.5 + tier * 0.15, 0.65))
	emitter(zone, "Embers", {
		Texture = A.spindle, Color = CS(CORE, EMBER), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		Size = NS({ KP(0, 0.14), KP(1, 0) }), Squash = NS(1.5), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(1, 1.5), Speed = R(3, 6), Acceleration = V(0, 2, 0), Rate = ({ 4, 6, 8, 10 })[tier],
		LightEmission = 0.7, RotSpeed = R(-30, 30),
	})
	if tier >= 3 then
		local wall = flameTongues(tier >= 4 and 18 or 14, 1.8 + (tier - 3) * 0.4, 0.55)
		wall.Size = NS({ KP(0, 0.6), KP(0.3, 2 + (tier - 3) * 0.4), KP(1, 0.4) })
		wall.Speed = R(5, 8)
		emitter(zone, "WallFlames", wall)
	end
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = FIRE
		light.Range = 20
		light.Brightness = 0 -- runtime flashes it at landing and the finale, glows low between
		light.Shadows = false
		light.Parent = zone
	end
	return zone
end

-- one tick: a torus sweeping centre -> rim, II+ a flare of flame tongues on
-- the rim, III+ a crown of spikes thrown up at the edge
function blocks.pulse(root, tier, p)
	local pulse = B().part(root, "Pulse", CENTRE)
	wave(pulse, "PulseRing", {
		mesh = A.torus, color = N_CORE,
		fromSize = V(2, 0.2, 2), toSize = V(RADIUS * 2, 0.8 + tier * 0.1, RADIUS * 2),
		fromOffset = V(0, 0.3, 0), toOffset = V(0, 0.3, 0),
		fromTransparency = 0.2, toTransparency = 1, duration = 0.38, style = "Quad",
	})
	if tier >= 2 then
		local flare = flameTongues(0, 1.4 + tier * 0.15, 0.4)
		flare.Speed = R(6, 9)
		emitter(pulse, "Flare", flare, { EmitCount = ({ 0, 8, 10, 12 })[tier] })
		pulse.Size = V(RADIUS * 2, 0.2, RADIUS * 2)
	end
	if tier >= 3 then
		wave(pulse, "PulseCrown", {
			mesh = A.crownLow, color = N_FIRE,
			fromSize = V(RADIUS * 2, 0.4, RADIUS * 2), toSize = V(RADIUS * 2 + 1, tier >= 4 and 3.6 or 2.8, RADIUS * 2 + 1),
			fromOffset = V(0, 0.2, 0), toOffset = V(0, tier >= 4 and 1.8 or 1.4, 0),
			fromTransparency = 0.25, toTransparency = 1, duration = 0.36, style = "Quart",
			delay = 0.12,
		})
	end
	return pulse
end

-- one burn hit on a target inside the zone, per tick: based on impactShockwave
function blocks.burn(root, tier, p)
	local impact = B().part(root, "Impact", CFrame.new(0, 0.15, -6))
	local body = B().attach(impact, "Body", V(0, 2.2, 0))
	emitter(body, "Flare", {
		Texture = A.flames4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = CS(Color3.new(1, 1, 1)), Size = NS({ KP(0, 1), KP(0.4, 1.8 + tier * 0.3), KP(1, 1.2) }),
		Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }), Lifetime = R(0.4), LightEmission = 0.3,
		Rotation = R(-10, 10), ZOffset = 2.5,
	}, { EmitCount = 1 })
	emitter(body, "Embers", {
		Texture = A.spindle, Color = CS(CORE, EMBER), Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top,
		Size = NS({ KP(0, 0.2), KP(1, 0) }), Squash = NS({ KP(0, 2), KP(1, 1) }), Transparency = NS(0),
		Lifetime = R(0.3, 0.5), Speed = R(12, 20), Drag = 5, Acceleration = V(0, 4, 0), LightEmission = 0.7, ZOffset = 2,
	}, { EmitCount = ({ 4, 5, 6, 8 })[tier] })
	B().impactShockwave(root, tier, {
		part = "Impact", ringColor = N_CORE, swirlColor = N_FIRE, groundColor = N_FIRE,
		size = ({ 2.6, 3.2, 3.8, 4.4 })[tier], groundSize = ({ 3.4, 4, 4.6, 5.2 })[tier],
		swirl = false, bubble = false, duration = 0.3,
	})
	if tier >= 3 then
		wave(impact, "Tongue", {
			mesh = A.crownTall, color = N_FIRE,
			fromSize = V(1.6, 0.4, 1.6), toSize = V(2.6, tier >= 4 and 4 or 3, 2.6),
			fromOffset = V(0, 0.2, 0), toOffset = V(0, tier >= 4 and 2 or 1.5, 0),
			fromTransparency = 0.2, toTransparency = 1, duration = 0.34, style = "Quart",
		})
	end
	return impact
end

-- the terminal burst as the seal breaks at def.seconds, all tiers, scaled
function blocks.finale(root, tier, p)
	local fin = B().part(root, "Finale", CENTRE, V(RADIUS * 2, 0.2, RADIUS * 2))
	wave(fin, "BreakRing", {
		mesh = A.torus, color = N_CORE,
		fromSize = V(RADIUS * 2, 0.8, RADIUS * 2), toSize = V(RADIUS * 2 + 4 + tier * 1.5, 1.2 + tier * 0.15, RADIUS * 2 + 4 + tier * 1.5),
		fromOffset = V(0, 0.35, 0), toOffset = V(0, 0.5, 0),
		fromTransparency = 0.1, toTransparency = 1, duration = 0.45 + tier * 0.03, style = "Quart",
	})
	emitter(fin, "Puff", {
		Texture = A.flame, Color = CS({ ColorSequenceKeypoint.new(0, CORE), ColorSequenceKeypoint.new(0.4, FIRE), ColorSequenceKeypoint.new(1, DEEP) }),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
		Size = NS({ KP(0, 0.8), KP(0.3, 1.6 + tier * 0.3), KP(1, 0.3) }), Transparency = NS({ KP(0, 0.2), KP(0.7, 0.3), KP(1, 1) }),
		Lifetime = R(0.45, 0.6), Speed = R(7, 11), LightEmission = 0.45,
	}, { EmitCount = ({ 10, 12, 16, 20 })[tier] })
	emitter(fin, "Embers", {
		Texture = A.spindle, Color = CS(CORE, EMBER), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
		Size = NS({ KP(0, 0.22), KP(1, 0) }), Squash = NS(2), Transparency = NS(0),
		Lifetime = R(0.5, 0.9), Speed = R(12, 22), Drag = 3, LightEmission = 0.7,
	}, { EmitCount = ({ 8, 10, 14, 18 })[tier] })
	emitter(fin, "Flash", flat({
		Texture = A.glow, Color = CS(FIRE), Size = NS({ KP(0, RADIUS * 0.6), KP(1, RADIUS * 1.2) }),
		Transparency = NS({ KP(0, 0.4), KP(1, 1) }), Lifetime = R(0.3), LightEmission = 0.4,
	}), { EmitCount = 1 })
	if tier >= 3 then
		wave(fin, "BreakCrown", {
			mesh = A.crownLow, color = N_FIRE,
			fromSize = V(RADIUS * 2, 1, RADIUS * 2), toSize = V(RADIUS * 2 + 3, tier >= 4 and 6 or 4, RADIUS * 2 + 3),
			fromOffset = V(0, 0.4, 0), toOffset = V(0, tier >= 4 and 3 or 2, 0),
			fromTransparency = 0.15, toTransparency = 1, duration = 0.5, style = "Quart",
		})
	end
	if tier >= 4 then
		wave(fin, "SpikeStar", {
			mesh = A.spikeStar, color = N_CORE,
			fromSize = V(4, 1, 4), toSize = V(20, 5, 20),
			fromOffset = V(0, 0.4, 0), toOffset = V(0, 1.2, 0),
			fromTransparency = 0.15, toTransparency = 1, duration = 0.5, style = "Quart",
		})
		wave(fin, "Eruption", {
			mesh = A.spikeBurst, color = N_FIRE,
			fromSize = V(3, 2, 3), toSize = V(9, 9, 9),
			fromOffset = V(0, 0.5, 0), toOffset = V(0, 3.5, 0),
			fromTransparency = 0.1, toTransparency = 1, duration = 0.55, style = "Quart",
		})
		B().screenShake(root, tier, { parent = "Finale", name = "Quake", preset = "Explosion", falloff = "20~80" })
	end
	return fin
end

local spec = {
	id = "FireSeal",
	root = { attrs = { AuthoredActive = 0.214, AuthoredRadius = RADIUS, AuthoredSeconds = 4 } },
	blocks = blocks,
	beats = {
		{ block = "handGather", params = { color = FIRE, core = CORE, windup = 0.5 } },
		{ block = "throw" },
		{ block = "bladeFlare", params = { part = "Palm", color = FIRE, core = CORE, ink = Color3.fromRGB(44, 20, 12) } },
		{ block = "landing" },
		{ block = "zone" },
		{ block = "pulse" },
		{ block = "burn" },
		{ block = "finale" },
	},
}

-- buildFromSpec with this spec's own blocks (spec.blocks before the shared
-- ones). Returns the built roots.
function spec.build(parent)
	local B0 = _G.vfxBlocks
	local built = {}
	for tier = 1, 4 do
		local name = spec.id .. "_T" .. tier
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local root = Instance.new("Model")
		root.Name = name
		for k, v in spec.root.attrs do
			root:SetAttribute(k, v)
		end
		for _, beat in spec.beats do
			if tier >= (beat.from or 1) and tier <= (beat.to or 4) then
				local fn = blocks[beat.block] or B0.BLOCKS[beat.block]
				assert(fn, "unknown block " .. tostring(beat.block))
				fn(root, tier, beat.params or {})
			end
		end
		root.WorldPivot = CFrame.new()
		root.Parent = parent
		table.insert(built, root)
	end
	return built
end

return spec
