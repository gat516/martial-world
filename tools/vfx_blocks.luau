--!nocheck
-- VFXBlocks: parametric template builders for technique effects, run in Edit
-- mode through execute_luau (bundled in tools/vfx_session.luau). They write
-- instances into a template Model built at the origin (pivot = the ground
-- point under the caster, facing -Z), so build into staging or a scratch
-- folder, never into ReplicatedStorage.Effects. Runtime placement and timing
-- stay in src/client (TechniqueVFX, CastFX); blocks only make the instances
-- and the attributes those read (Phase, AuthoredWindup, EmitCount, ...).
-- Values are seeded from what worked on Palm Strike; every block takes
-- (root, tier, p) where tier is 1-4 and p overrides any default.
--
-- Shared params: color (main tint), core (bright accent), plus per block:
--   groundShockwave  p.radius (9), p.echo (tier>=2), p.rays (tier>=2), p.dust
--       Part "Ground": a flat ring front (Size = radius over its life, Phase
--       "active" so it's fitted to Hit -> Hit Stop), an echo ring, centre rays
--       and a dust skirt kicked out along the ground. Circles and zones.
--   releaseFlash     p.part ("Palm"), p.at (CFrame), p.light (tier>=4)
--       The flash/glow/forward sparks where the limb lands, the tier IV light.
--   dropStreak       p.part ("Palm"), p.strike ("Strike"), p.strikeAt
--       A streak dropping from the release point and a splash + puff where it
--       lands (hand -> ground -> ring).
--   handGather       p.part ("Windup"), p.at, p.windup (0.38), p.wisps (tier>=2)
--       Qi motes and a charge glow that ride the striking limb through the
--       windup (LockedToPart), III+ a closing seal, II+ Spline wisps.
--   impactBurst      p.part ("Impact"), p.at
--       Per-target hit: star flash, glow puff, spiky ring, sparks (Body
--       attachment, ZOffset in front of the target), II+ dust, III+ shards,
--       IV a ground crack.
--   meshWave         (primitive) a 3D MeshWave model: torus/ball tweened From*
--       -> To* relative to its parent part (see the function). Shockwaves use
--       these so the main read is a physical part; particles are accents.
--   impactShockwave  p.part ("Impact"), p.size, p.lifetime, p.second (tier>=3)
--       The "it connected" punch: a Neon torus stood up facing back along the
--       blow (CastFX aims the Impact part's look along the hit) snapping out
--       in 0.15 -> 0.08 s by tier, a thinner second torus a beat later at
--       III+, and a short flat torus on the ground under the target.
--   airShockwave     p.part ("Palm"), p.count (1, 1, 2, 3 by tier), p.travel
--       Sonic-boom torus rings leaving the striking limb along the strike
--       direction, growing as they travel; a staggered train at high tiers.
--       For palm/kick releases and sword waves.
--   shockwaveShell   p.name ("Shell"), p.mesh, p.from/p.to (size), p.spin,
--       p.duration, p.startTransparency: a SimpleMeshVFX Start/End shell
--       (dome, sphere or swirl ring). Code sets Duration from the active window.
--   craterRing       p.parent ("Ground"), p.name ("RockRing"), p.shape
--       ("Ring"/"Cone"), p.radius, p.count: a Craters attachment (rocks that
--       erupt with a wave, or a cone kicked out at a target).
--   screenShake      p.parent, p.name ("Shake"), p.magnitude, p.preset,
--       p.falloff, p.frames: ScreenEffects CameraShake (and ImpactFrames) on
--       an empty attachment. Code adds CombatEffects.shake only when
--       TechniqueVFX.full is false.
--   (distortionWave was tried and dropped: an expanding ForceField shell
--   didn't read at all in captures, day or night.)
--   impactStack      p.flash/p.wave/p.burst/p.kick/p.quake overrides: one
--       tier-scaled "big hit" = impactBurst + impactShockwave + III+ Craters
--       cone + IV ScreenEffects quake.
--   emitter          p.part, p.partAt, p.name, p.props, p.attrs, p.flat,
--       p.dir: one emitter for a technique-specific piece (seals, halos...).
--
-- buildFromSpec(spec, parent) builds <Id>_T1..T4 from a spec table (see
-- tools/vfx_specs/): spec.root.attrs on each root, and spec.beats, a list of
-- { block, from?, to?, params?, phase?, attrs? } played in order for each tier
-- with from <= tier <= to. `phase` sets Phase on the beat's emitters, `attrs`
-- adds attributes to the beat's main instance.

local AssetService = game:GetService("AssetService")

local B = {}

local function id(n)
	return "rbxassetid://" .. n
end

-- Library picks that worked (see tools/vfx_library.json for more).
B.ASSETS = {
	glow = id(867619398), -- soft radial glow
	star12 = id(243728206), -- 12-point starburst
	star4 = id(13271628051), -- crisp 4-point star
	waveRing = id(12363693873), -- thick fuzzy ring (ground wave front)
	thinRing = id(9841273159), -- clean thin ring
	hitRing = id(13052235894), -- spiky anime impact ring
	rays = id(15773612675), -- radial sunburst
	spindle = id(7814053668), -- thin spindle streak (sparks, drops)
	dust = id(11037785287), -- soft dust puff
	crack = id(93520831389146), -- radial ground cracks
	crater = id(90713203428310), -- dark crater ring
	seal = id(83667248904000), -- rune circle
	ornate = id(13399941667), -- ornate halo circle
	shards = id(12402863766), -- shard spray
	swirlMesh = id(129778117978668), -- horizontal wind swirl ring mesh
	domeMesh = id(13567208057), -- low dome mesh
	rockMesh = id(17608108317), -- Inno stylized Rock_03 (Craters UseMesh)
	torusMesh = id(471124075), -- torus ring mesh (MeshSize 150 x 9.51 x 150; lies flat in XZ)
	swirlRingMesh = id(122217820569960), -- flat swirl ring (impact swirl)
}

B.COLORS = {
	gold = Color3.fromRGB(255, 210, 120),
	core = Color3.fromRGB(255, 244, 214),
	dust = Color3.fromRGB(226, 212, 186),
	crack = Color3.fromRGB(110, 88, 56),
	crater = Color3.fromRGB(70, 56, 40),
	ring = Color3.fromRGB(255, 240, 205), -- Neon torus rings (impact, air, ground wave)
	groundRing = Color3.fromRGB(255, 224, 150), -- the ground shock under a target
	swirl = Color3.fromRGB(255, 214, 130), -- impact swirl and bubble
}

local A, Cl = B.ASSETS, B.COLORS
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local O = CFrame.new()

local function pick(p, key, default)
	if p[key] == nil then
		return default
	end
	return p[key]
end

-- ---------------------------------------------------------------- primitives

-- A named part under `root`, created at `cf` (relative to the origin pivot)
-- the first time; later blocks asking for the same name share it.
function B.part(root, name, cf, size)
	local existing = root:FindFirstChild(name)
	if existing then
		return existing
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf or O
	p.Parent = root
	return p
end

function B.emitter(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	for k, v in props do
		e[k] = v
	end
	for k, v in attrs or {} do
		e:SetAttribute(k, v)
	end
	e.Parent = parent
	return e
end

-- A plane particle: flat on the ground (Top) or facing along `dir`.
function B.flat(props, dir)
	props.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	props.EmissionDirection = dir or Enum.NormalId.Top
	props.Speed = R(0.01)
	props.SpreadAngle = Vector2.zero
	return props
end

function B.attach(parent, name, pos, attrs, tag)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	for k, v in attrs or {} do
		a:SetAttribute(k, v)
	end
	if tag then
		a:AddTag(tag)
	end
	a.Parent = parent
	return a
end

local meshCache = {}
-- A Neon MeshPart at Transparency 1 (SimpleMeshVFX shows clones from
-- StartTransparency). MeshId isn't writable from scripts, hence the cache of
-- CreateMeshPartAsync results.
function B.mesh(meshId, parent, name, size, cf, color, material)
	local source = meshCache[meshId]
	if not source then
		source = AssetService:CreateMeshPartAsync(meshId)
		meshCache[meshId] = source
	end
	local m = source:Clone()
	m.Name = name
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
	m.Material = material or Enum.Material.Neon
	m.Color = color
	m.Transparency = 1
	if size then
		m.Size = size
	end
	m.CFrame = cf
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------- blocks

function B.groundShockwave(root, tier, p)
	local gold, core = pick(p, "color", Cl.gold), pick(p, "core", Cl.core)
	local radius = pick(p, "radius", 9)
	local ground = B.part(root, pick(p, "part", "Ground"), O * CFrame.new(0, 0.2, 0))
	local k = radius / 9
	B.emitter(ground, "WaveFront", B.flat({
		Texture = A.waveRing, Color = CS(gold),
		Size = NS({ KP(0, 1 * k), KP(0.3, 5 * k), KP(0.6, 7.6 * k), KP(1, radius) }),
		Transparency = NS({ KP(0, 0.1), KP(0.6, 0.35), KP(1, 1) }),
		Lifetime = R(pick(p, "lifetime", 0.3)), LightEmission = 0.35, Brightness = 1.4,
	}), { EmitCount = 1, Phase = "active" })
	if pick(p, "dust", true) then
		B.emitter(ground, "Dust", {
			Texture = A.dust, Color = CS(pick(p, "dustColor", Cl.dust)), LightInfluence = 0.5,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(5, 180),
			Size = NS({ KP(0, 0.9), KP(1, 2.2 + tier * 0.2) }), Transparency = NS({ KP(0, 0.3), KP(0.5, 0.5), KP(1, 1) }),
			Lifetime = R(0.45, 0.7), Speed = R(34 * k, 44 * k), Drag = 4,
			Rotation = R(0, 360), RotSpeed = R(-60, 60),
		}, { EmitCount = ({ 10, 12, 14, 16 })[tier] })
	end
	if pick(p, "echo", tier >= 2) then
		B.emitter(ground, "WaveEcho", B.flat({
			Texture = A.thinRing, Color = CS(core),
			Size = NS({ KP(0, 1 * k), KP(0.4, 6.5 * k), KP(1, 9.4 * k) }), Transparency = NS({ KP(0, 0.05), KP(1, 1) }),
			Lifetime = R(0.36), LightEmission = 0.5, Brightness = 1.6,
		}), { EmitCount = 1, EmitDelay = 0.07, Phase = "active" })
	end
	-- the 3D torus rolling out with the front (CombatEffects sets ToSize from
	-- def.radius). Not Phase "active": fitted to the 0.16 s window it was gone
	-- before anyone saw it; Quart Out still covers ~85% of the radius by Hit
	-- Stop, and the late fade lets it be seen
	if pick(p, "torus", true) then
		B.meshWave(ground, "GroundWave", {
			mesh = A.torusMesh, color = Cl.ring,
			fromSize = Vector3.new(1.5, 0.24, 1.5), toSize = Vector3.new(radius * 2, 1.82 * k, radius * 2),
			fromOffset = Vector3.new(0, 0.31, 0), toOffset = Vector3.new(0, 0.31, 0),
			fromTransparency = 0.45, toTransparency = 1, duration = 0.42, style = "Quart",
		})
	end
	if pick(p, "rays", tier >= 2) then
		B.emitter(ground, "Rays", B.flat({
			Texture = A.rays, Color = CS(gold),
			Size = NS({ KP(0, 1.5), KP(1, 6) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
			Lifetime = R(0.28), LightEmission = 0.5, Rotation = R(0, 360),
		}), { EmitCount = 1, Phase = "active" })
	end
	return ground
end

function B.releaseFlash(root, tier, p)
	local gold, core = pick(p, "color", Cl.gold), pick(p, "core", Cl.core)
	local part = B.part(root, pick(p, "part", "Palm"), pick(p, "at", O * CFrame.new(0, 3, -1.6)))
	B.emitter(part, "Flash", {
		Texture = A.star12, Color = CS(core),
		Size = NS({ KP(0, 0.3), KP(0.35, 1.2 + tier * 0.25), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 0.5) }),
		Lifetime = R(0.14), LightEmission = 0.6, Rotation = R(0, 360), ZOffset = 1,
	}, { EmitCount = 1 })
	B.emitter(part, "Glow", {
		Texture = A.glow, Color = CS(gold),
		Size = NS({ KP(0, 0.8), KP(1, 1.6 + tier * 0.3) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		Lifetime = R(0.22), LightEmission = 0.4,
	}, { EmitCount = 1 })
	if tier >= 2 then
		B.emitter(part, "Sparks", {
			Texture = A.spindle, Color = CS(core), Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 35),
			Size = NS({ KP(0, 0.22), KP(1, 0) }), Squash = NS({ KP(0, 2), KP(1, 1) }), Transparency = NS(0),
			Lifetime = R(0.15, 0.28), Speed = R(28, 42), Drag = 7, LightEmission = 0.6,
		}, { EmitCount = ({ 0, 6, 8, 10 })[tier] })
	end
	if pick(p, "light", tier >= 4) then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = gold
		light.Range = 22
		light.Brightness = 0 -- the caller flashes it and fades it out
		light.Shadows = false
		light.Parent = part
	end
	return part
end

function B.dropStreak(root, tier, p)
	local gold, core = pick(p, "color", Cl.gold), pick(p, "core", Cl.core)
	local part = B.part(root, pick(p, "part", "Palm"), O * CFrame.new(0, 3, -1.6))
	B.emitter(part, "Drop", {
		Texture = A.spindle, Color = CS(core, gold), Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(4, 4),
		Size = NS({ KP(0, 0.35 + tier * 0.08), KP(1, 0.15) }), Squash = NS(2.5), Transparency = NS({ KP(0, 0), KP(1, 0.4) }),
		Lifetime = R(0.06), Speed = R(45), LightEmission = 0.6, ZOffset = 1,
	}, { EmitCount = tier >= 3 and 2 or 1 })
	if tier >= 3 then
		B.emitter(part, "Column", {
			Texture = A.glow, Color = CS(gold), Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Bottom, Size = NS({ KP(0, 0.8), KP(1, 0.4) }), Squash = NS(3),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }), Lifetime = R(0.08), Speed = R(30), LightEmission = 0.4,
		}, { EmitCount = 1 })
	end
	local strike = B.part(root, pick(p, "strike", "Strike"), pick(p, "strikeAt", O * CFrame.new(0, 0.2, -1.5)))
	B.emitter(strike, "Splash", B.flat({
		Texture = A.hitRing, Color = CS(gold),
		Size = NS({ KP(0, 0.3), KP(1, 1.2 + tier * 0.3) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.15), LightEmission = 0.5, Rotation = R(0, 360), ZOffset = 0.5,
	}), { EmitCount = 1, EmitDelay = 0.04 })
	B.emitter(strike, "Puff", {
		Texture = A.dust, Color = CS(Cl.dust), LightInfluence = 0.5,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Size = NS({ KP(0, 0.5), KP(1, 1.3) }), Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
		Lifetime = R(0.3, 0.45), Speed = R(10, 14), Drag = 5, Rotation = R(0, 360),
	}, { EmitCount = 2 + tier, EmitDelay = 0.04 })
	return part
end

function B.handGather(root, tier, p)
	local gold, core = pick(p, "color", Cl.gold), pick(p, "core", Cl.core)
	local at = pick(p, "at", O * CFrame.new(0, 3, -1.2))
	local windup = B.part(root, pick(p, "part", "Windup"), at, Vector3.new(3, 3, 3))
	windup:SetAttribute("AuthoredWindup", pick(p, "windup", 0.38))
	B.emitter(windup, "Gather", {
		Texture = A.glow, Color = CS(gold),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = NS({ KP(0, 0.25), KP(1, 0.05) }), Transparency = NS({ KP(0, 1), KP(0.3, 0.2), KP(1, 0) }),
		Lifetime = R(0.3), Speed = R(7, 9), LightEmission = 0.6, LockedToPart = true,
	}, { EmitCount = ({ 5, 7, 9, 12 })[tier] })
	B.emitter(windup, "Charge", {
		Texture = A.glow, Color = CS(core),
		Size = NS({ KP(0, 0.1), KP(1, 0.7 + tier * 0.12) }), Transparency = NS({ KP(0, 0.8), KP(1, 0.2) }),
		Lifetime = R(0.34), LightEmission = 0.5, LockedToPart = true,
	}, { EmitCount = 1 })
	if tier >= 3 then
		B.emitter(windup, "SealIn", B.flat({
			Texture = A.seal, Color = CS(gold),
			Size = NS({ KP(0, 1.3), KP(1, 0.35) }), Transparency = NS({ KP(0, 1), KP(0.4, 0.3), KP(1, 0.1) }),
			Lifetime = R(0.34), RotSpeed = R(-180), LightEmission = 0.5, LockedToPart = true,
		}, Enum.NormalId.Front), { EmitCount = 1 })
	end
	if pick(p, "wisps", tier >= 2) then
		-- Spline wisps (Splines add-on): paths from around the body into the
		-- limb; CombatEffects moves this part with the hand and emits it itself
		local wisps = B.part(windup, "Wisps", at, Vector3.new(5, 3, 5))
		wisps:AddTag("SplineVFX")
		B.attach(wisps, "1", Vector3.new(0, 1.5, -1))
		B.attach(wisps, "End", Vector3.zero)
		for k2, v in {
			EmitCount = tier, Duration = R(0.34), Easing = NS({ KP(0, 0), KP(0.6, 0.35), KP(1, 1) }),
			Tension = R(-0.3), Variance = Vector3.new(1.5, 1.5, 1.5), SyncPosition = true, FacePath = true, PoolObject = false,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, -- start points: the part's volume
		} do
			wisps:SetAttribute(k2, v)
		end
		local wisp = B.part(wisps, "Wisp", at)
		local a0 = B.attach(wisp, "A0", Vector3.new(-0.12, 0, 0))
		local a1 = B.attach(wisp, "A1", Vector3.new(0.12, 0, 0))
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = CS(core, gold)
		trail.Transparency = NS({ KP(0, 0.1), KP(1, 1) })
		trail.WidthScale = NS({ KP(0, 1), KP(1, 0) })
		trail.Lifetime = 0.18
		trail.LightEmission = 0.6
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Parent = wisp
	end
	return windup
end

function B.impactBurst(root, tier, p)
	local gold, core = pick(p, "color", Cl.gold), pick(p, "core", Cl.core)
	local impact = B.part(root, pick(p, "part", "Impact"), pick(p, "at", O * CFrame.new(0, 0.15, -6)))
	local body = impact:FindFirstChild("Body") or B.attach(impact, "Body", Vector3.new(0, 2.2, 0))
	B.emitter(body, "Flash", {
		Texture = A.star4, Color = CS(core),
		Size = NS({ KP(0, 0.6), KP(0.3, 2 + tier * 0.35), KP(1, 0) }), Transparency = NS(0),
		Lifetime = R(0.12), LightEmission = 0.8, Rotation = R(-15, 15), ZOffset = 3,
	}, { EmitCount = 1 })
	B.emitter(body, "Puff", {
		Texture = A.glow, Color = CS(gold),
		Size = NS({ KP(0, 1.2), KP(1, 2.2 + tier * 0.25) }), Transparency = NS({ KP(0, 0.25), KP(1, 1) }),
		Lifetime = R(0.16), LightEmission = 0.5, ZOffset = 2.5,
	}, { EmitCount = 1 })
	B.emitter(body, "HitRing", {
		Texture = A.hitRing, Color = CS(gold),
		Size = NS({ KP(0, 0.5), KP(1, 2.2 + tier * 0.35) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.25), KP(1, 1) }),
		Lifetime = R(0.2), LightEmission = 0.45, Rotation = R(0, 360), ZOffset = 2.8,
	}, { EmitCount = 1 })
	B.emitter(body, "Sparks", {
		Texture = A.spindle, Color = CS(core), Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(180, 180),
		Size = NS({ KP(0, 0.25), KP(1, 0) }), Squash = NS({ KP(0, 2), KP(1, 1) }), Transparency = NS(0),
		Lifetime = R(0.15, 0.3), Speed = R(30, 45), Drag = 8, LightEmission = 0.6, ZOffset = 2,
	}, { EmitCount = ({ 6, 8, 10, 12 })[tier] })
	if tier >= 2 then
		B.emitter(impact, "Dust", {
			Texture = A.dust, Color = CS(Cl.dust), LightInfluence = 0.5,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(80, 80),
			Size = NS({ KP(0, 0.6), KP(1, 1.5) }), Transparency = NS({ KP(0, 0.45), KP(1, 1) }),
			Lifetime = R(0.4, 0.6), Speed = R(6, 10), Drag = 4, Rotation = R(0, 360), ZOffset = 1,
		}, { EmitCount = ({ 0, 3, 4, 5 })[tier] })
	end
	if tier >= 3 then
		B.emitter(body, "Shards", {
			Texture = A.shards, Color = CS(gold),
			Size = NS({ KP(0, 1), KP(1, 2.4) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
			Lifetime = R(0.16), LightEmission = 0.4, Rotation = R(0, 360), ZOffset = 2.6,
		}, { EmitCount = 1 })
	end
	if tier >= 4 then
		B.emitter(impact, "Crack", B.flat({
			Texture = A.crack, Color = CS(Cl.crack), LightInfluence = 0.3,
			Size = NS(1.8), Transparency = NS({ KP(0, 1), KP(0.05, 0.15), KP(0.6, 0.3), KP(1, 1) }),
			Lifetime = R(1.1), Rotation = R(0, 360), ZOffset = -0.5,
		}), { EmitCount = 1 })
	end
	return impact
end

-- A MeshWave (TechniqueVFX plays it, with or without the Game Module): a
-- Model with MeshWave = true and a child `Mesh` part (Transparency 1 in the
-- template, native mesh size, at the template origin), tweened at emit time
-- relative to its parent part/attachment from From* to To*. Only the given
-- attributes are set: fromSize/toSize, fromOffset/toOffset (Vector3, parent
-- space), rotation (Vector3 degrees; (90,0,0) stands a flat ring up facing
-- the parent's -Z), fromTransparency/toTransparency, duration, style (an
-- EasingStyle name), delay (EmitDelay), phase ("active" -> fit() retimes it).
-- p.mesh is a MeshId, or "Ball" for a sphere Part; p.material, p.color.
-- Shockwaves read as physical 3D parts this way; particles are accents.
function B.meshWave(parent, name, p)
	local wave = Instance.new("Model")
	wave.Name = name
	for k, v in {
		FromSize = p.fromSize, ToSize = p.toSize, FromOffset = p.fromOffset, ToOffset = p.toOffset,
		Rotation = p.rotation, FromTransparency = p.fromTransparency, ToTransparency = p.toTransparency,
		Duration = p.duration, Style = p.style, EmitDelay = p.delay, Phase = p.phase,
	} do
		wave:SetAttribute(k, v)
	end
	wave:SetAttribute("MeshWave", true)
	if p.mesh == "Ball" then
		local ball = Instance.new("Part")
		ball.Name = "Mesh"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
		ball.Material = p.material or Enum.Material.ForceField
		ball.Color = p.color or Cl.core
		ball.Transparency = 1
		ball.CFrame = O
		ball.Parent = wave
	else
		B.mesh(p.mesh or A.torusMesh, wave, "Mesh", nil, O, p.color or Cl.ring, p.material)
	end
	wave.Parent = parent
	return wave
end

-- Torus 471124075 is 150 x 9.51 x 150 (a round tube is Y = D * 0.0634);
-- impact rings use a ~2.4x fatter tube, ground shocks ~1.7x (thin tubes
-- were invisible at play speed; the boldest pass read heavy, this is 60% of it).
local RING_TUBE, GROUND_TUBE = 0.152, 0.105

function B.impactShockwave(root, tier, p)
	local impact = B.part(root, pick(p, "part", "Impact"), pick(p, "at", O * CFrame.new(0, 0.15, -6)))
	local body = impact:FindFirstChild("Body") or B.attach(impact, "Body", Vector3.new(0, 2.2, 0))
	local d = pick(p, "size", ({ 3.7, 4.7, 5.9, 7.4 })[tier]) -- ring diameter, studs
	-- the "it connected" ring, stood up facing back along the blow (CastFX aims
	-- the Impact part's look along the hit), bursting out and holding ~0.25 s
	local ring = B.meshWave(body, "ImpactRing", {
		mesh = A.torusMesh, color = pick(p, "ringColor", Cl.ring),
		fromSize = Vector3.new(0.8, 0.13, 0.8), toSize = Vector3.new(d, d * RING_TUBE, d),
		rotation = Vector3.new(90, 0, 0), fromTransparency = 0.35, toTransparency = 1,
		duration = pick(p, "duration", 0.26), style = "Quart",
	})
	if pick(p, "swirl", tier >= 2) then
		local sd = d * 1.33
		B.meshWave(body, "ImpactSwirl", {
			mesh = A.swirlRingMesh, color = pick(p, "swirlColor", Cl.swirl),
			fromSize = Vector3.new(1, 0.34, 1), toSize = Vector3.new(sd, 0.8, sd),
			rotation = Vector3.new(90, 0, 0), fromTransparency = 0.45, toTransparency = 1,
			duration = 0.32, style = "Quad", delay = 0.036,
		})
	end
	if pick(p, "bubble", tier >= 3) then
		local bd = d * ({ 1.1, 1.1, 1.1, 1.3 })[tier]
		B.meshWave(body, "ImpactBubble", {
			mesh = "Ball", material = Enum.Material.ForceField, color = pick(p, "swirlColor", Cl.swirl),
			fromSize = Vector3.new(0.6, 0.6, 0.6), toSize = Vector3.new(bd, bd, bd),
			fromTransparency = 0.3, toTransparency = 1, duration = 0.3, style = "Quad",
		})
	end
	-- a short flat torus on the ground under the target
	local gd = pick(p, "groundSize", ({ 4, 5, 6.4, 8 })[tier])
	B.meshWave(impact, "GroundShock", {
		mesh = A.torusMesh, color = pick(p, "groundColor", Cl.groundRing),
		fromSize = Vector3.new(1, 0.14, 1), toSize = Vector3.new(gd, gd * GROUND_TUBE, gd),
		fromOffset = Vector3.new(0, 0.13, 0), toOffset = Vector3.new(0, 0.13, 0),
		fromTransparency = 0.4, toTransparency = 1, duration = 0.34, style = "Quart",
	})
	return ring
end

function B.airShockwave(root, tier, p)
	local part = B.part(root, pick(p, "part", "Palm"), pick(p, "at", O * CFrame.new(0, 3, -1.6)))
	local count = pick(p, "count", ({ 1, 1, 2, 3 })[tier])
	local d = pick(p, "size", ({ 2.9, 3.6, 4.7, 6 })[tier]) -- first ring's final diameter
	local travel = pick(p, "travel", 4.4 + tier * 1.3) -- studs along the strike (-Z)
	local name = pick(p, "name", "AirRing")
	local first
	for i = 1, count do
		local k = 1 - (i - 1) * 0.12
		local wave = B.meshWave(part, if i == 1 then name else name .. i, {
			mesh = pick(p, "mesh", A.swirlMesh), color = pick(p, "color", Cl.ring),
			fromSize = Vector3.new(0.72, 0.24, 0.72), toSize = Vector3.new(d * k, 0.7, d * k),
			fromOffset = Vector3.new(0, 0, -0.3), toOffset = Vector3.new(0, 0, -travel * k),
			rotation = Vector3.new(90, 0, 0), fromTransparency = 0.35 + (i - 1) * 0.12, toTransparency = 1,
			duration = pick(p, "duration", 0.28), style = "Quad", delay = if i > 1 then (i - 1) * 0.054 else nil,
		})
		first = first or wave
	end
	return first
end

function B.shockwaveShell(root, tier, p)
	local shell = Instance.new("Model")
	shell.Name = pick(p, "name", "Shell")
	for k, v in {
		Duration = pick(p, "duration", 0.35), StartTransparency = pick(p, "startTransparency", 0.3),
		EndTransparency = 1, Part_TweenParams = pick(p, "tween", "Quad,Out"),
	} do
		shell:SetAttribute(k, v)
	end
	shell.Parent = root
	local meshId = pick(p, "mesh", A.swirlMesh)
	local spin = pick(p, "spin", 140)
	B.mesh(meshId, shell, "Start", pick(p, "from", Vector3.new(3, 0.7, 3)), O * CFrame.new(0, pick(p, "y0", 0.5), 0), pick(p, "startColor", Cl.gold), p.material)
	B.mesh(meshId, shell, "End", pick(p, "to", Vector3.new(19, 1.4, 19)), O * CFrame.new(0, pick(p, "y1", 0.7), 0) * CFrame.Angles(0, math.rad(spin), 0), pick(p, "endColor", Cl.core), p.material)
	return shell
end

function B.craterRing(root, tier, p)
	local parent = root:FindFirstChild(pick(p, "parent", "Ground")) or B.part(root, pick(p, "parent", "Ground"), O * CFrame.new(0, 0.2, 0))
	local cone = pick(p, "shape", "Ring") == "Cone"
	local attrs = if cone then {
		Shape = "Cone", ConeAngle = 80, Radius = 2.2, Fill = true, Variance = 0.5, Count = tier == 4 and 4 or 3, Duration = 0.04,
		EmissionStart = "Progressive", EmissionEnd = "Random",
		Size = Vector3.new(0.8, 0.6, 0.7), SizeScale = R(0.8, 1.2), SizeBias = 0.5,
		Lifetime = R(0.9, 1.2), SpawnTime = R(0.05, 0.08), DespawnTime = R(0.3, 0.4),
		AngleX = R(20, 45), AngleY = R(-30, 30), AngleZ = R(-15, 15),
		Collision = false, MatchGround = true, YOffset = 0.3, RaycastDistance = 8,
		UseMesh = true, MeshId = A.rockMesh,
	} else {
		Shape = "Ring", Fill = true, Radius = pick(p, "radius", 9), Variance = 1.2, Count = tier == 4 and 12 or 8, Duration = 0.3,
		EmissionStart = "Progressive", EmissionEnd = "Progressive",
		Size = Vector3.new(1.4, 1.0, 1.2), SizeScale = R(0.7, 1.2), SizeBias = 0.7,
		Lifetime = R(1.3, 1.7), SpawnTime = R(0.06, 0.1), DespawnTime = R(0.4, 0.6),
		AngleX = R(25, 50), AngleY = R(-20, 20), AngleZ = R(-10, 10),
		Collision = false, MatchGround = true, YOffset = 0.45, RaycastDistance = 12,
		UseMesh = true, MeshId = A.rockMesh,
	}
	for k, v in p.attrs or {} do
		attrs[k] = v
	end
	return B.attach(parent, pick(p, "name", if cone then "Kick" else "RockRing"), Vector3.zero, attrs, "CraterVFX")
end

function B.screenShake(root, tier, p)
	local parent = root:FindFirstChild(pick(p, "parent", "Palm")) or B.part(root, pick(p, "parent", "Palm"), O * CFrame.new(0, 3, -1.6))
	local attrs = {}
	if p.preset then
		attrs.CameraShake = p.preset .. (if p.falloff then "," .. p.falloff else "")
	elseif pick(p, "shake", true) then
		attrs.CameraShake = string.format("Custom,%s,%.1f,0.25,9,0.02", pick(p, "falloff", "25~90"), pick(p, "magnitude", ({ 1.2, 1.8, 2.6, 3.4 })[tier]))
	end
	local shake = B.attach(parent, pick(p, "name", "Shake"), nil, attrs)
	if p.frames then
		B.attach(parent, pick(p, "framesName", "Frames"), nil, { ImpactFrames = p.frames == true and "2,,60,40,0,0.5,0.045,0.045" or p.frames })
	end
	return shake
end

function B.impactStack(root, tier, p)
	B.impactBurst(root, tier, p.burst or p)
	if p.wave ~= false then
		B.impactShockwave(root, tier, p.wave or p)
	end
	if p.kick ~= false and tier >= 3 then
		B.craterRing(root, tier, { parent = "Impact", shape = "Cone", attrs = p.kick })
	end
	if p.quake ~= false and tier >= 4 then
		B.screenShake(root, tier, { parent = "Impact", name = "Quake", preset = "Explosion", falloff = "20~80" })
	end
	return root:FindFirstChild("Impact")
end

-- One emitter on a named part (created at p.partAt the first time).
function B.emitterBlock(root, tier, p)
	local part = B.part(root, p.part, p.partAt or O)
	local props = table.clone(p.props)
	if p.flat then
		B.flat(props, p.dir)
	end
	return B.emitter(part, p.name, props, p.attrs)
end

-- ---------------------------------------------------------------- specs

local BLOCKS = {
	groundShockwave = B.groundShockwave, releaseFlash = B.releaseFlash, dropStreak = B.dropStreak,
	handGather = B.handGather, impactBurst = B.impactBurst, impactShockwave = B.impactShockwave,
	airShockwave = B.airShockwave, shockwaveShell = B.shockwaveShell, craterRing = B.craterRing,
	screenShake = B.screenShake, impactStack = B.impactStack,
	emitter = B.emitterBlock,
}
B.BLOCKS = BLOCKS

local function setPhase(inst, phase)
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("ParticleEmitter") then
			d:SetAttribute("Phase", phase)
		end
	end
end

-- Builds <spec.id>_T<tier> for tier 1..4 (or spec.tiers) into `parent`,
-- replacing existing ones. Returns the built roots.
function B.buildFromSpec(spec, parent)
	local built = {}
	for tier = 1, spec.tiers or 4 do
		local name = spec.id .. "_T" .. tier
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local root = Instance.new("Model")
		root.Name = name
		for k, v in (spec.root and spec.root.attrs) or {} do
			root:SetAttribute(k, v)
		end
		for _, beat in spec.beats do
			if tier >= (beat.from or 1) and tier <= (beat.to or 4) then
				local fn = BLOCKS[beat.block]
				assert(fn, "unknown block " .. tostring(beat.block))
				local made = fn(root, tier, beat.params or {})
				if beat.phase and made then
					setPhase(made, beat.phase)
				end
				for k, v in beat.attrs or {} do
					made:SetAttribute(k, v)
				end
			end
		end
		root.WorldPivot = O
		root.Parent = parent
		table.insert(built, root)
	end
	return built
end

_G.vfxBlocks = B
return "vfxBlocks installed"
