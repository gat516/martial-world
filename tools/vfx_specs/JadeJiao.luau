--!nocheck
-- Builder for ReplicatedStorage.Effects.JadeJiao: the Jade Jiao boss's attack,
-- hit, phase, burrow and death effects (rebuilt 2026-10-22 with the
-- intent-first method, .claude/agents/vfx.md). Load through the receiver, then
-- build into the live Effects folder in a sandbox:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/JadeJiao.luau")
--   require(m)  -- installs _G.buildJadeJiaoFX(effectsFolder)
-- Runtime: src/client/EnemyFX/JadeJiao.luau (cue -> template, placement,
-- sounds). The fight sheet and this pass's record: docs/systems/enemies.md
-- "Jade Jiao".
--
-- Identity: venom. Acid venom-green (9BFF4A) with white-hot centres for the
-- venom; soil, dust and slate for the earth the serpent drives through; pale
-- spirit-jade only where its qi leaves the body (ascension, death). Every
-- bright shape sits on a slate twin of its own shape. The body is the hero's
-- carrier: tells are the body's own Tell parts (handler), effects come off the
-- named hooks (Mouth, Core, TailTip_FX, Dive_FX...).
--
-- The rule of this pass: every layer is caused by the body doing the move,
-- one hero per peak, starts staggered behind their cause (EmitDelay), one
-- peak. Cut from the first pass, and why:
--   - Marker / MarkerLite / GroundMark (amber circles and arrays on every
--     slam, coil, pool and rain drop): they redrew the telegraph's danger
--     area (docs/systems/telegraphs.md);
--   - GroundGather (mist drawn in over the ground before slams, dives, molt):
--     nothing in the ground gathers before a blow lands;
--   - the aura's always-on ground mandala and sigil (no always-on ground
--     circles for beasts);
--   - the shared Impact kit stacked on every slam, sweep, emerge and pool
--     (two impacts on one frame) and its projectile core on the bolts;
--   - HissBurst on the emergence, PhaseFlare on the surfacing head, the
--     SpitRelease on the fang bite, HoodFlare particles (the hood's own Tell
--     parts already light), the skyward "spirit stream" on every phase and the
--     rain (a stream with no cause), the death's white-out, rays and pillar
--     (three peaks), the 40 neon segments of the coil ring (the body is the
--     ring) and its ground pulses;
--   - shakes on the small beats (bites, spit, bolt splats, rain drops).
--
-- Beat sheets (ms from the cue; windups from the attack table; contact is the
-- end of the windup, R):
--   every windup: 0-250 EyeFlare (the eye catches the light as it fixes on its
--     prey); the Tell parts (eyes, hood spots, fang tips, throat, tail gem)
--     brighten across the windup in code.
--   emerge (2200, buried): 0-2200 EmergeBuild (cracks spreading out over the
--     body, tremor dust puffs from 0 and faster from 1300, pebbles hopping from
--     900, venom fumes seeping through the cracks from 1300). R: EmergeBurst:
--     +0 flash, +0 earth crown heaving up (hero) with venom bursting inside
--     it, +0 the hole, +30 clods and Craters rocks, +60 dust shoved out, +80
--     dust cloud, +120 venom mist billowing out of the hole (to 1700).
--   erupt (850): the same, EmergeBuild refit to 850 and scaled to the circle.
--   mireDive (800): the head dives into the earth at the dash: DiveBurst (+0
--     a crown of soil splashing round the head (hero), the hole, +20 clods,
--     +60 dust); RidgeFX sprays soil off the travelling ridge until `land`.
--   venomFang / fangFlurry (750 / 900, strikes at +400/+1000): VenomWell (venom
--     beading on the fangs and dripping, the glisten swelling) through the
--     windup. Each bite (FangSnap): +0 the jaws closing (two ragged crescents
--     on slate twins, hero), +0 a white flash, +30 venom flung off the fangs.
--   tailSweep (800): the tail winds left and high, holds and trembles at
--     400-450 (TailTell: dust shaken off the tip, the gem glints), then lashes
--     round the right side: TailLash trails ride the tip from 450 to R+150.
--     R: TailImpact under the tip, facing the lash: +0 contact flash, +0 a wall
--     of dust kicked along the lash (hero), +20 clods, +40 a slate shock ring,
--     +80 dust cloud.
--   tailShove (700): coil 0-550 (TailTell), whip 550-700 (TailLash). R:
--     ShoveBlast at the tip, facing outward: +0 flash, +0 a torn air front
--     rushing out on its slate twin (hero: the shove that throws you 36
--     studs), +20 speed lines, +30 dust shoved out.
--   pillarSlam (1000): the head rears, venom drooling (VenomWell). R:
--     SlamImpact: +0 flash, +0 a crown of earth thrown up round the head
--     (hero), +0 the crater (held 2400: the head stays buried), +20 venom
--     spat off the jaws, +40 slate shock ring and Craters rocks, +60 dust
--     shoved out, +100 dust cloud. R+860: RipFree (clods and dust as the head
--     tears out of the ground).
--   venomLance / venomSpray / venomPools / venomRain windups: SpitGather
--     (venom pumped up into the mouth: the core swells on slate, drool, a fume
--     curling out of the lips in the last 40%). Release (the bolt's start):
--     SpitRelease (+0 a jet of venom out of the mouth on its slate twin (hero),
--     +0 flash, +40 mist). Flight: VenomBolt (a writhing venom glob on a
--     slate halo, a white-hot core, drips, a slate and a venom trail, a shadow
--     on the ground). End: BoltSplat (+0 flash, +0 the splash rising on its
--     slate twin (hero), +30 drops, +80 a fume) and GroundSplat on the floor
--     (the splat on its slate twin). Pools: the glob lands into PoolDisc (the
--     puddle on slate, bubbles popping, fumes; 7000, the hazard itself).
--     Rain: SpitRelease aimed at the sky; each drop is a VenomBolt falling
--     into BoltSplat + GroundSplat.
--   jiaoCoil (1500, hold 3000): the scale seams glow down the body (code).
--     CoilAt: CoilSlam (the body slapping down round the circle: dust rising
--     off the rim (hero), clods). Hold: the seams pulse faster and faster
--     toward the squeeze (code); the door's edges breathe venom (CoilGate).
--     Squeeze: CoilSqueeze (+0 a torn air ring collapsing inward, dust shoved
--     in off the rim (hero), +0 a crush flash at the centre, +60 venom forced
--     up). Break: CoilBreak (scales and dust flung out off the rim).
--   dreadHiss (1100): HissTell (air drawn into the mouth, the last 60%). R:
--     HissWave at the mouth (+0 a torn sound ring racing out to r30 on its
--     slate twin (hero), +120 a second ring, +60 the venom breath), +80
--     HissDust (dust shoved off the ground under the head).
--   molt (1600) / phase 2: ShedSkin (old scales peeling off five body hooks
--     through the windup); the phase cue sheds them all at once: ShedBurst on
--     every hook and the Core (hero), P2 cracks reveal (code).
--   ascension (2000) / phase 3: QiGather (jade qi drawn into the chest, the
--     core swelling on slate); the phase cue: AscendSurge (+0 flash, +0 a
--     twisting jade column rising off the chest (hero) over a slate puff,
--     +40 motes streaming up), fins and whiskers reveal (code).
--   hits (near side of the torso): HitFang (flash, venom spatter on slate),
--     HitTail (soft burst, dust), HitHeavy (flash, slate shock ring, dust),
--     HitVenom (a splat on slate, a fume).
--   stagger: StaggerFlare at the Core (scale chips knocked off, a flash).
--   death (the body fades over 1000): DeathBleed on every hook (venom-jade
--     fumes and motes leaving the body, 0-1000); 1000: SpiritRise where the
--     Core was (+0 flash, +0 a twisting jade spirit column rising (hero) over
--     a slate puff, +30 the spirit swirl, +60 motes).
--
-- Library picks (searched fresh for this effect from what each move causes:
-- earth, dust, debris, liquid, splash, mist, air, sound, scales, spirit;
-- 2026-10-22). Images unless marked; flipbooks are sprite sheets.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local AssetService = game:GetService("AssetService")
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local VENOM = Color3.fromRGB(155, 255, 74)
local VHOT = Color3.fromRGB(226, 255, 182)
local VDEEP = Color3.fromRGB(60, 150, 44)
local JADE = Color3.fromRGB(168, 255, 216)
local GOLD = Color3.fromRGB(255, 190, 70)
local HOT = Color3.fromRGB(255, 236, 176)
local SLATE = Color3.fromRGB(28, 42, 36)
local INK = Color3.fromRGB(12, 18, 14)
local DUST = Color3.fromRGB(168, 152, 126)
local SOIL = Color3.fromRGB(92, 72, 50)
local SOILDK = Color3.fromRGB(58, 46, 34)

local TEX = {
	-- cores, shadows and motes only (generic by design)
	dot = id(9841273544),
	-- the eye catching the light: a diamond glint
	glint = id(11201546023),
	-- contact: a sharp star burst
	star = id(16357973363),
	-- a blunt contact: a soft spiky burst
	softStar = id(14197758636),
	-- the jaws: a ragged crescent (two of them, closing)
	jaw = id(112905728569682),
	-- venom flung or spraying: wet goo blobs (2x2 variants)
	goo = id(107688167838598),
	-- a jet of venom out of the mouth: liquid swooshes (2x2 variants)
	jet = id(130951935230565),
	-- a splash rising off a landing: liquid splash crowns (2x2 variants)
	splash = id(84740227921523),
	-- the splat on the ground and the pool: a liquid splatter
	splat = id(243457340),
	-- the flying glob: a writhing green orb with a dark rim
	glob = id(12362864010),
	-- a bubble rising out of the pool
	bubble = id(12363673327),
	-- breath, venom mist curling: a curling smoke wisp
	curl = id(9345352897),
	-- dust kicked sideways by a lash
	lowDust = id(116349652487671),
	-- the hole the serpent leaves: a crater with rubble
	hole = id(109477912447315),
	-- the ground breaking as it heaves: a dark crack ring
	heave = id(96277359307961),
	-- the slam's crater: a dark broken ring
	crater = id(127029400731687),
	-- dirt thrown flat round a slam
	dirtStar = id(84847629229771),
	-- old scales peeling off: a veined scale
	scale = id(17259245248),
	-- scale chips knocked off: a dark diamond shard
	shard = id(84898751486491),
	-- the spirit leaving: a spirit swirl
	swirl = id(11192758174),
	-- speed lines of the shove: a thin line strip
	line = id(9149045341),
	-- the lash's trail: a ragged-edge strip
	lash = id(6671348341),
	-- flipbooks (8x8 / 4x4 sheets)
	soilPuff = id(11509655546), -- 8x8: a tan dust puff bursting and thinning
	fume = id(73401626133942), -- 8x8: wispy smoke curling (venom mist)
	rise = id(9470659899), -- 8x8 on black (additive only): a wisp rising
	fog = id(89816655384560), -- 4x4: a rolling dust cloud
	-- clods and rocks thrown up (a scatter of rocks)
	rocks = id(394144370),
	-- aura and mound (kept from the first pass; not part of this rework)
	puff = id(14050360239),
	flame = id(13280154167),
	auraGlint = id(84223532517124),
	crackGlow = id(8172249266),
}
local MESH = {
	earthCrown = 111460667532043, -- jagged rocks bursting up: the emergence
	spikeCrown = 4316118084, -- a crown of spikes: earth thrown up round a slam
	lowCrown = 489415286, -- a low crown: soil splashing round the dive
	shockA = 87503547436500, -- a torn flat ring: ground shocks
	airFront = 107819007023719, -- a torn ring: the shove's air front
	soundRing = 113725566783994, -- a torn ring: the hiss
	squeezeRing = 121387125059545, -- a torn ring: air forced in by the squeeze
	twister = 94223676940948, -- a twister: the ascension's qi column
	spirit = 95104854417012, -- a twisting column: the spirit leaving at death
}
local GRID8 = Enum.ParticleFlipbookLayout.Grid8x8
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local GRID2 = Enum.ParticleFlipbookLayout.Grid2x2
local ONESHOT = Enum.ParticleFlipbookMode.OneShot
local LOOP = Enum.ParticleFlipbookMode.Loop

local FLAT = {
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
	Speed = R(0.01),
}
-- ground-hugging radial spray (dust shoved outward)
local RADIAL = {
	Shape = Enum.ParticleEmitterShape.Box,
	EmissionDirection = Enum.NormalId.Front,
	SpreadAngle = Vector2.new(5, 180),
}
-- off the rim of a Disc-shaped part (the coil)
local RIM = {
	Shape = Enum.ParticleEmitterShape.Disc,
	ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
}
local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
end
local function flip8(props)
	return with({ FlipbookLayout = GRID8, FlipbookMode = ONESHOT }, props)
end
local function flip4(props)
	return with({ FlipbookLayout = GRID4, FlipbookMode = ONESHOT }, props)
end
-- one random variant per particle off a sheet of variants
local function variant(layout, props)
	return with({ FlipbookLayout = layout, FlipbookMode = LOOP, FlipbookFramerate = R(0.01), FlipbookStartRandom = true }, props)
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

-- Sizes are authored as diameters; a particle's Size is a half-width.
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

local meshCache = {}
-- A 3D shock: a library mesh tweened From -> To by TechniqueVFX's mesh waves.
-- `dark` makes the slate twin (NoTint, SmoothPlastic); `material` overrides.
local function wave(parent, name, meshId, p)
	local w = Instance.new("Model")
	w.Name = name
	w:SetAttribute("MeshWave", true)
	for k, v in {
		FromSize = p.from, ToSize = p.to, FromOffset = p.fromOffset, ToOffset = p.toOffset,
		Rotation = p.rotation, FromTransparency = p.fromT or 0.15, ToTransparency = 1,
		Duration = p.duration or 0.3, Style = p.style or "Quart", FadeStyle = p.fade, EmitDelay = p.delay,
	} do
		w:SetAttribute(k, v)
	end
	if p.dark or p.noTint then
		w:SetAttribute("NoTint", true)
	end
	local source = meshCache[meshId]
	if not source then
		source = AssetService:CreateMeshPartAsync(id(meshId))
		meshCache[meshId] = source
	end
	local m = source:Clone()
	m.Name = "Mesh"
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
	m.Material = p.material or (if p.dark then Enum.Material.SmoothPlastic else Enum.Material.Neon)
	m.Color = p.color or (if p.dark then SLATE else VENOM)
	m.Transparency = 1
	m.Parent = w
	w.Parent = parent
	return w
end

local function seq(...)
	local keys = {}
	local args = { ... }
	for i = 1, #args, 2 do
		table.insert(keys, KP(args[i], args[i + 1]))
	end
	return NS(keys)
end
local POP = seq(0, 0, 1, 1)
local FADE = seq(0, 0, 0.6, 0.15, 1, 1)
local THIN = seq(0, 0.3, 0.6, 0.5, 1, 1)
local VEN = CS({ CK(0, WHITE), CK(0.35, VHOT), CK(1, VENOM) })
local NOTINT = { EmitCount = 1, NoTint = true }
local function n(count, delay, extra)
	local t = { EmitCount = count, EmitDelay = delay }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

local function shake(parent, csv)
	local a = att(parent, "Shake")
	a:SetAttribute("CameraShake", csv)
end

local function craters(parent, radius, count, size, delay)
	local rocks = att(parent, "Rocks", Vector3.new(0, 0.5, 0))
	rocks:AddTag("CraterVFX")
	for k, v in {
		Shape = "Ring", Fill = true, EmissionStart = "Progressive", Radius = radius * 0.8, Variance = radius * 0.2, Duration = 0.3,
		Count = R(count, count + 4), Lifetime = R(1.4, 2.2), Size = Vector3.new(size * 1.6, size * 0.9, size * 1.2), SizeScale = R(0.7, 1.4),
		Collision = false, MatchGround = true, YOffset = 0.45, AngleX = R(25, 50), SpawnTime = R(0.05, 0.25), DespawnTime = R(0.8, 1.1),
		EmitDelay = delay,
	} do
		rocks:SetAttribute(k, v)
	end
end

-- soil dust (the earth's own colour; lit by the world)
local function soilDust(props)
	-- the sheet is tan already: a grey multiply keeps it earthy, not orange
	-- and each puff fills about half its cell, so sizes are drawn 1.7x
	local t = flip8(with({ Texture = TEX.soilPuff, Color = CS(Color3.fromRGB(175, 170, 160)), LightEmission = 0, LightInfluence = 1, Rotation = R(0, 360) }, props))
	local keys = {}
	for _, k in t.Size.Keypoints do
		table.insert(keys, KP(k.Time, k.Value * 1.7, k.Envelope * 1.7))
	end
	t.Size = NS(keys)
	return t
end
local function clods(props)
	return with({ Texture = TEX.rocks, Color = CS(Color3.fromRGB(150, 130, 105)), LightEmission = 0, LightInfluence = 1, Acceleration = Vector3.new(0, -80, 0), Rotation = R(0, 360), RotSpeed = R(-200, 200) }, props)
end
local function cloud(props)
	return flip4(with({ Texture = TEX.fog, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Rotation = R(0, 360), RotSpeed = R(-10, 10) }, props))
end

function _G.buildJadeJiaoFX(effects)
	local old = effects:FindFirstChild("JadeJiao")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "JadeJiao"

	---------------------------------------------------------------- tells

	-- EyeFlare (each eye, 0-250 of every windup; the tail gem readying the
	-- coil): the eye catches the light as it fixes on its prey. 1 layer.
	do
		local p = part(root, "EyeFlare")
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(0.4, HOT), CK(1, GOLD) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.25), Size = seq(0, 0.6, 0.3, 4, 1, 0), Rotation = R(-6, 6), ZOffset = 2 })
	end

	-- VenomWell (the Mouth, fang and slam windups; authored 750): venom beads
	-- on the fangs and drips off. 2 layers: drips (0-750), the glisten
	-- swelling (core).
	do
		local p = part(root, "VenomWell", Vector3.new(2.4, 1, 1), { AuthoredSeconds = 0.75 })
		em(p, "Drips", variant(GRID2, { Texture = TEX.goo, Color = VEN, LightEmission = 0.6, Rate = 7, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(10, 10), Speed = R(1, 3), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.45, 0.6), Size = seq(0, 0.9, 1, 0.5), Transparency = seq(0, 0.1, 1, 0.6) }), { EmitDuration = 0.75 })
		em(p, "Glisten", { Texture = TEX.dot, Color = VEN, LightEmission = 1, Brightness = 2, Lifetime = R(0.75), Size = seq(0, 0.3, 1, 2), Transparency = seq(0, 0.9, 0.85, 0.3, 1, 1), LockedToPart = true, ZOffset = 1 })
	end

	-- SpitGather (the Mouth, spit and rain windups; authored 700): venom
	-- pumped up the throat into the mouth. 4 layers: the core swelling on its
	-- slate twin (hero), drool (0-700), a fume curling out of the lips (last
	-- 40%).
	do
		local p = part(root, "SpitGather", Vector3.new(2, 1, 1), { AuthoredSeconds = 0.7 })
		em(p, "CoreDark", { Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(0.7), Size = seq(0, 0.6, 1, 4), Transparency = seq(0, 0.8, 0.85, 0.35, 1, 1), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Core", { Texture = TEX.dot, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.7), Size = seq(0, 0.4, 0.85, 2.6, 1, 3), Transparency = seq(0, 0.8, 0.85, 0.05, 1, 0.7), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Drool", variant(GRID2, { Texture = TEX.goo, Color = VEN, LightEmission = 0.6, Rate = 6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom, Speed = R(1, 2), Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.5, 0.65), Size = seq(0, 1, 1, 0.5), Transparency = seq(0, 0.1, 1, 0.7) }), { EmitDuration = 0.7 })
		em(p, "Fume", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.3, Rate = 9, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(2, 4), Lifetime = R(0.5, 0.7), Size = seq(0, 1.5, 1, 4), Transparency = seq(0, 0.35, 1, 1) }), { EmitDelay = 0.42, EmitDuration = 0.28 })
	end

	-- TailTell (the tail tip, sweep and shove windups; authored 800): the tip
	-- tenses at the top of the wind-up and trembles. 2 layers at 400: dust
	-- shaken off, the gem's glint.
	do
		local p = part(root, "TailTell", Vector3.new(2, 1, 2), { AuthoredSeconds = 0.8 })
		em(p, "Shake", soilDust({ Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40), Speed = R(2, 5), Acceleration = Vector3.new(0, -20, 0), Lifetime = R(0.6, 0.8), Size = seq(0, 1.6, 1, 3.2), Transparency = THIN }), n(5, 0.4, { NoTint = true }))
		em(p, "Glint", { Texture = TEX.glint, Color = CS({ CK(0, WHITE), CK(1, VHOT) }), LightEmission = 1, Brightness = 3, Lifetime = R(0.2), Size = seq(0, 0.5, 0.3, 3, 1, 0), ZOffset = 2 }, n(1, 0.4))
	end

	-- TailLash (rides the tail tip from the lash's start to contact + 150):
	-- the lash's path in the air. Trails: a slate base and a venom edge (the
	-- runtime sets the half-width).
	do
		local p = part(root, "TailLash", Vector3.new(0.3, 0.3, 0.3))
		local a0 = att(p, "A0", Vector3.new(0, 1, 0))
		local a1 = att(p, "A1", Vector3.new(0, -1, 0))
		for _, spec in {
			{ "Dark", "", CS(SLATE), 0.32, 0.35, 1.6, 0 },
			{ "Edge", TEX.lash, CS({ CK(0, VHOT), CK(1, VENOM) }), 0.24, 0.1, 1.1, 0.8 },
		} do
			local t = Instance.new("Trail")
			t.Name = spec[1]
			t.Attachment0, t.Attachment1 = a0, a1
			t.Texture = spec[2]
			t.TextureMode = Enum.TextureMode.Stretch
			t.Color = spec[3]
			t.LightEmission = spec[7]
			t.LightInfluence = 0
			t.Lifetime = spec[4]
			t.MinLength = 0.05
			t.FaceCamera = true
			t.Enabled = false
			t.Transparency = NS({ KP(0, spec[5]), KP(1, 1) })
			t.WidthScale = NS({ KP(0, spec[6]), KP(1, 0.2) })
			t.Parent = p
		end
	end

	-- HissTell (the Mouth, the dread hiss; authored 1100): air drawn into the
	-- jaws in the last 60%. 1 layer.
	do
		local p = part(root, "HissTell", Vector3.new(9, 9, 9), { AuthoredSeconds = 1.1 })
		em(p, "Inhale", { Texture = TEX.curl, Color = CS(VHOT), LightEmission = 0.4, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 16, Speed = R(14, 18), Lifetime = R(0.28, 0.34), Size = seq(0, 2.6, 1, 0.6), Transparency = seq(0, 1, 0.3, 0.45, 1, 1), Rotation = R(0, 360), LockedToPart = true }, { EmitDelay = 0.44, EmitDuration = 0.66 })
	end

	-- ShedSkin (five body hooks, the molt's windup; authored 1600): the old
	-- skin peeling off in scales. 1 layer.
	do
		local p = part(root, "ShedSkin", Vector3.new(4, 3, 4), { AuthoredSeconds = 1.6 })
		em(p, "Flakes", { Texture = TEX.scale, Color = CS({ CK(0, VHOT), CK(1, VDEEP) }), LightEmission = 0.3, LightInfluence = 0.5, Rate = 6, Shape = Enum.ParticleEmitterShape.Box, SpreadAngle = Vector2.new(70, 70), Speed = R(1, 3), Drag = 1, Acceleration = Vector3.new(0, -4, 0), Lifetime = R(1, 1.5), Size = NS(1.1), Transparency = seq(0, 1, 0.15, 0.15, 0.8, 0.3, 1, 1), Rotation = R(0, 360), RotSpeed = R(-90, 90) }, { EmitDuration = 1.6 })
	end

	-- QiGather (the Core, the ascension's windup; authored 2000): jade qi
	-- drawn up the body into the chest. 3 layers: wisps streaming in, the
	-- core swelling on its slate twin (hero).
	do
		local p = part(root, "QiGather", Vector3.new(16, 16, 16), { AuthoredSeconds = 2 })
		em(p, "Wisps", { Texture = TEX.curl, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 0.8, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 12, Speed = R(18, 24), Lifetime = R(0.36, 0.44), Size = seq(0, 3.4, 1, 0.8), Transparency = seq(0, 1, 0.3, 0.3, 1, 0.9), Rotation = R(0, 360), LockedToPart = true }, { EmitDuration = 2, NoTint = true })
		em(p, "CoreDark", { Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(2), Size = seq(0, 1, 1, 7), Transparency = seq(0, 0.9, 0.85, 0.4, 1, 1), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Core", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 3, Lifetime = R(2), Size = seq(0, 0.5, 0.85, 4, 1, 4.6), Transparency = seq(0, 0.9, 0.85, 0.1, 1, 0.8), LockedToPart = true, ZOffset = 1.5 }, NOTINT)
	end

	---------------------------------------------------------------- the earth

	-- EmergeBuild (the ground over the buried body; authored 2200, r10): the
	-- ground heaving before it breaks. 5 layers: the cracks spreading out
	-- (0-2200, accelerating), tremor dust (0-2200, faster from 1300),
	-- pebbles hopping (900-2200), venom fumes seeping through (1300-2200).
	do
		local p = part(root, "EmergeBuild", Vector3.new(20, 0.2, 20), { AuthoredSeconds = 2.2, AuthoredRadius = 10 })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "Cracks", with(FLAT, { Texture = TEX.heave, Color = CS(INK), LightInfluence = 0.4, Lifetime = R(2.2), Size = seq(0, 3, 0.6, 9, 1, 24), Transparency = seq(0, 0.6, 0.5, 0.15, 0.95, 0, 1, 1), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(p, "Tremor", soilDust({ Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Rate = 4, Speed = R(2, 5), Lifetime = R(0.7, 1), Size = seq(0, 2, 1, 5), Transparency = THIN }), { EmitDuration = 2.2, NoTint = true })
		em(p, "TremorLate", soilDust({ Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Rate = 14, Speed = R(3, 8), Lifetime = R(0.6, 0.9), Size = seq(0, 2.4, 1, 6), Transparency = THIN }), { EmitDelay = 1.3, EmitDuration = 0.9, NoTint = true })
		em(p, "Pebbles", clods({ Rate = 10, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(8, 14), Lifetime = R(0.4, 0.55), Size = NS(0.9) }), { EmitDelay = 0.9, EmitDuration = 1.3, NoTint = true })
		em(p, "Seep", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.4, Rate = 7, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(3, 6), Lifetime = R(0.8, 1.1), Size = seq(0, 2.5, 1, 5), Transparency = seq(0, 0.3, 1, 1) }), { EmitDelay = 1.3, EmitDuration = 0.9 })
	end

	-- EmergeBurst (the ground, at contact; authored r10): the serpent breaks
	-- out of the earth. 6 layers + 2 waves + rocks: +0 flash, +0 the earth
	-- crown heaving up (hero) with venom bursting inside it, +0 the hole,
	-- +30 clods and rocks, +60 dust shoved out, +80 dust cloud, +120 venom mist
	-- billowing out of the hole.
	do
		local p = part(root, "EmergeBurst", Vector3.new(20, 0.2, 20), { AuthoredRadius = 10 })
		local up = att(p, "Up", Vector3.new(0, 4, 0))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(up, "Flash", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = seq(0, 6, 1, 20), Transparency = POP, ZOffset = 3 })
		wave(p, "Crown", MESH.earthCrown, { dark = true, color = SOIL, from = Vector3.new(8, 3, 8), to = Vector3.new(24, 14, 24), fromOffset = Vector3.new(0, -2, 0), toOffset = Vector3.new(0, 1, 0), fromT = 0, duration = 0.55, style = "Quint", fade = "Quint" })
		wave(p, "Venom", MESH.earthCrown, { material = Enum.Material.ForceField, from = Vector3.new(6, 3, 6), to = Vector3.new(18, 12, 18), fromOffset = Vector3.new(0, -2, 0), toOffset = Vector3.new(0, 1, 0), fromT = 0.3, duration = 0.4, style = "Quint", rotation = Vector3.new(0, 25, 0) })
		em(g, "Hole", with(FLAT, { Texture = TEX.hole, Color = CS(SOILDK), LightInfluence = 0.5, Lifetime = R(3), Size = seq(0, 16, 1, 17), Transparency = seq(0, 0.05, 0.7, 0.2, 1, 1), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(up, "Clods", clods({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(26, 40), Drag = 1.5, Lifetime = R(0.8, 1.1), Size = NS(3) }), n(10, 0.03, { NoTint = true }))
		craters(g, 10, 10, 2.6, 0.03)
		em(g, "DustRing", soilDust(with(RADIAL, { Speed = R(36, 48), Drag = 3.5, Lifetime = R(0.9, 1.2), Size = seq(0, 6, 1, 14), Transparency = THIN })), n(18, 0.06, { NoTint = true }))
		em(up, "Cloud", cloud({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(6, 12), Drag = 1.5, Lifetime = R(1.6, 2.2), Size = seq(0, 14, 1, 26), Transparency = seq(0, 0.1, 0.5, 0.3, 1, 1) }), n(6, 0.08, { NoTint = true }))
		em(g, "Mist", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.3, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 10), Drag = 1, Lifetime = R(1.3, 1.6), Size = seq(0, 6, 1, 14), Transparency = seq(0, 0.3, 1, 1), Rotation = R(0, 360) }), n(8, 0.12))
		shake(p, "Explosion,30~140,3.2,0.9,18,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- DiveBurst (Dive_FX, the dash; authored r6): the head dives into the
	-- earth. 3 layers + 1 wave: +0 a crown of soil splashing round it (hero),
	-- +0 the hole, +20 clods, +60 dust.
	do
		local p = part(root, "DiveBurst", Vector3.new(12, 0.2, 12), { AuthoredRadius = 6 })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		local up = att(p, "Up", Vector3.new(0, 2, 0))
		wave(p, "Crown", MESH.lowCrown, { dark = true, color = SOIL, from = Vector3.new(4, 1.5, 4), to = Vector3.new(14, 6, 14), fromT = 0, duration = 0.4, style = "Quint", fade = "Quint" })
		em(g, "Hole", with(FLAT, { Texture = TEX.hole, Color = CS(SOILDK), LightInfluence = 0.5, Lifetime = R(1.4), Size = NS(10), Transparency = seq(0, 0.05, 0.6, 0.2, 1, 1), Rotation = R(0, 360), ZOffset = 0.2 }), NOTINT)
		em(up, "Clods", clods({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(25, 40), Lifetime = R(0.7, 1), Size = NS(1.6) }), n(10, 0.02, { NoTint = true }))
		em(up, "Dust", cloud({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(5, 9), Drag = 1.5, Lifetime = R(1.1, 1.5), Size = seq(0, 6, 1, 13), Transparency = seq(0, 0.35, 1, 1) }), n(4, 0.06, { NoTint = true }))
	end

	-- RidgeFX (the head of the moving ridge, -Z = travel): soil thrown up off
	-- the front of the ridge. 2 layers.
	do
		local p = part(root, "RidgeFX", Vector3.new(4, 1, 2))
		em(p, "Spray", soilDust({ Rate = 16, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(6, 12), Acceleration = Vector3.new(0, -20, 0), Lifetime = R(0.5, 0.8), Size = seq(0, 2.4, 1, 5), Transparency = THIN }), { NoTint = true })
		em(p, "Clods", clods({ Rate = 7, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(12, 20), Lifetime = R(0.5, 0.7), Size = NS(1.1) }), { NoTint = true })
	end

	-- SlamImpact (the circle at (0,0,-27); authored r9): the head driven into
	-- the ground. 6 layers + 2 waves + rocks: +0 flash, +0 a crown of earth
	-- thrown up round the head (hero), +0 the crater (held: the head stays
	-- buried), +0 dirt thrown flat, +20 venom spat off the jaws, +40 slate
	-- shock ring and rocks, +60 dust shoved out, +100 dust cloud.
	do
		local p = part(root, "SlamImpact", Vector3.new(18, 0.2, 18), { AuthoredRadius = 9 })
		local up = att(p, "Up", Vector3.new(0, 3, 0))
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(up, "Flash", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = seq(0, 5, 1, 16), Transparency = POP, ZOffset = 3 })
		wave(p, "Crown", MESH.spikeCrown, { dark = true, color = SOIL, from = Vector3.new(7, 3, 7), to = Vector3.new(22, 12, 22), fromT = 0, duration = 0.5, style = "Quint", fade = "Quint" })
		wave(p, "Crown2", MESH.spikeCrown, { dark = true, color = SOILDK, from = Vector3.new(6, 2.5, 6), to = Vector3.new(19, 9, 19), rotation = Vector3.new(0, 22, 0), fromT = 0, duration = 0.45, style = "Quint", fade = "Quint", delay = 0.02 })
		em(g, "Crater", with(FLAT, { Texture = TEX.crater, Color = CS(INK), LightInfluence = 0.4, Lifetime = R(2.4), Size = seq(0, 15, 0.1, 20, 1, 20.5), Transparency = seq(0, 0, 0.75, 0.15, 1, 1), Rotation = R(0, 360), ZOffset = 0.3 }), NOTINT)
		em(g, "Dirt", with(FLAT, { Texture = TEX.dirtStar, Color = CS(SOIL), LightInfluence = 1, Lifetime = R(1.6), Size = seq(0, 8, 0.15, 20, 1, 21), Transparency = seq(0, 0.1, 0.6, 0.3, 1, 1), Rotation = R(0, 360), ZOffset = 0.1 }), NOTINT)
		em(up, "Venom", variant(GRID2, { Texture = TEX.goo, Color = VEN, LightEmission = 0.6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(18, 30), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.6, 0.9), Size = seq(0, 1.4, 1, 0.8), Transparency = seq(0, 0, 0.8, 0.2, 1, 1) }), n(10, 0.02))
		wave(p, "Shock", MESH.shockA, { dark = true, from = Vector3.new(6, 1, 6), to = Vector3.new(36, 2.4, 36), fromOffset = Vector3.new(0, 0.3, 0), toOffset = Vector3.new(0, 0.3, 0), fromT = 0.2, duration = 0.42, delay = 0.04 })
		craters(g, 9, 8, 2.2, 0.04)
		em(g, "DustRing", soilDust(with(RADIAL, { Speed = R(34, 44), Drag = 3.5, Lifetime = R(0.8, 1.1), Size = seq(0, 5, 1, 12), Transparency = THIN })), n(16, 0.06, { NoTint = true }))
		em(up, "Cloud", cloud({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(5, 9), Drag = 1.5, Lifetime = R(1.4, 1.8), Size = seq(0, 8, 1, 16), Transparency = seq(0, 0.4, 1, 1) }), n(5, 0.1, { NoTint = true }))
		shake(p, "Explosion,25~110,2.6,0.6,20,0.02,1;1;1,0.08;0.08;0.08")
	end

	-- RipFree (the slam point, 860 into the recover): the head tears out of
	-- the ground. 2 layers: clods thrown up, a dust puff.
	do
		local p = part(root, "RipFree", Vector3.new(4, 0.2, 4))
		local up = att(p, "Up", Vector3.new(0, 1.5, 0))
		em(up, "Clods", clods({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(25, 40), Lifetime = R(0.7, 1), Size = NS(1.6) }), n(9, 0, { NoTint = true }))
		em(up, "Dust", cloud({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(4, 8), Drag = 1.5, Lifetime = R(1, 1.4), Size = seq(0, 5, 1, 11), Transparency = seq(0, 0.4, 1, 1) }), n(3, 0.04, { NoTint = true }))
	end

	-- TailImpact (the ground under the tail tip at contact, -Z = the lash's
	-- motion; authored r6): the lash slapping the ground. 4 layers + 1 wave:
	-- +0 flash, +0 a wall of dust kicked along the lash (hero), +20 clods,
	-- +40 slate shock ring, +80 dust cloud.
	do
		local p = part(root, "TailImpact", Vector3.new(12, 0.2, 12), { AuthoredRadius = 6 })
		local up = att(p, "Up", Vector3.new(0, 2, 0))
		local g = att(p, "Ground", Vector3.new(0, 0.6, 0))
		em(up, "Flash", { Texture = TEX.softStar, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.1), Size = seq(0, 4, 1, 10), Transparency = POP, ZOffset = 3 })
		em(g, "Wall", { Texture = TEX.lowDust, Color = CS(DUST), LightInfluence = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(8, 55), Speed = R(28, 42), Drag = 4, Lifetime = R(0.7, 1), Size = seq(0, 5, 1, 12), Transparency = seq(0, 0.1, 0.5, 0.3, 1, 1), Rotation = R(-10, 10) }, n(12, 0, { NoTint = true }))
		em(up, "Clods", clods({ EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 35), Speed = R(20, 34), Lifetime = R(0.6, 0.9), Size = NS(1.4) }), n(8, 0.02, { NoTint = true }))
		wave(p, "Shock", MESH.shockA, { dark = true, from = Vector3.new(3, 0.8, 3), to = Vector3.new(18, 1.8, 18), fromOffset = Vector3.new(0, 0.3, 0), toOffset = Vector3.new(0, 0.3, 0), fromT = 0.25, duration = 0.32, delay = 0.04 })
		em(up, "Cloud", cloud({ EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(8, 14), Drag = 2, Lifetime = R(1.1, 1.5), Size = seq(0, 6, 1, 13), Transparency = seq(0, 0.4, 1, 1) }), n(4, 0.08, { NoTint = true }))
	end

	-- ShoveBlast (the tail tip at contact, -Z = outward): the whip's air
	-- shove that throws a player 36 studs. 3 layers + 2 waves: +0 flash, +0 a
	-- torn air front rushing out on its slate twin (hero), +20 speed lines,
	-- +30 dust shoved out.
	do
		local p = part(root, "ShoveBlast", Vector3.new(4, 4, 4))
		em(p, "Flash", { Texture = TEX.softStar, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.1), Size = seq(0, 4, 1, 11), Transparency = POP, ZOffset = 3 })
		wave(p, "FrontDark", MESH.airFront, { dark = true, from = Vector3.new(4, 1.2, 4), to = Vector3.new(20, 4, 20), fromOffset = Vector3.new(0, 0, -1), toOffset = Vector3.new(0, 0, -16), rotation = Vector3.new(90, 0, 0), fromT = 0.4, duration = 0.34 })
		wave(p, "Front", MESH.airFront, { from = Vector3.new(3.6, 1, 3.6), to = Vector3.new(18, 3.4, 18), fromOffset = Vector3.new(0, 0, -1), toOffset = Vector3.new(0, 0, -16), rotation = Vector3.new(90, 0, 0), fromT = 0.15, duration = 0.32 })
		em(p, "Lines", { Texture = TEX.line, Color = CS(VHOT), LightEmission = 1, Brightness = 1.5, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(22, 22), Speed = R(70, 95), Drag = 4, Lifetime = R(0.22, 0.3), Size = seq(0, 4, 1, 0.6), Transparency = seq(0, 0.2, 1, 1) }, n(7, 0.02))
		em(p, "Dust", soilDust({ EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 20), Speed = R(34, 46), Drag = 3.5, Lifetime = R(0.7, 1), Size = seq(0, 4, 1, 10), Transparency = THIN }), n(10, 0.03, { NoTint = true }))
	end

	---------------------------------------------------------------- the bite

	-- FangSnap (the Mouth, -Z = the bite; each bite): the jaws slam shut. 6
	-- layers: +0 the upper and lower jaw crescents closing on their slate
	-- twins (hero), +0 flash, +30 venom flung off the fangs.
	do
		local p = part(root, "FangSnap", Vector3.new(0.4, 0.4, 0.4))
		local u = att(p, "Upper", Vector3.new(0, 3, -1.5))
		local d = att(p, "Lower", Vector3.new(0, -3, -1.5))
		local jaw = { Texture = TEX.jaw, Lifetime = R(0.15), Speed = R(16), Drag = 8 }
		em(u, "UpperDark", with(jaw, { Color = CS(SLATE), EmissionDirection = Enum.NormalId.Bottom, Rotation = R(0), Size = seq(0, 12, 1, 8), Transparency = seq(0, 0.05, 0.6, 0.2, 1, 1), ZOffset = 0.5 }), NOTINT)
		em(u, "Upper", with(jaw, { Color = VEN, LightEmission = 0.9, Brightness = 2, EmissionDirection = Enum.NormalId.Bottom, Rotation = R(0), Size = seq(0, 10, 1, 6.6), Transparency = seq(0, 0, 0.6, 0.1, 1, 1), ZOffset = 1.5 }))
		em(d, "LowerDark", with(jaw, { Color = CS(SLATE), EmissionDirection = Enum.NormalId.Top, Rotation = R(180), Size = seq(0, 12, 1, 8), Transparency = seq(0, 0.05, 0.6, 0.2, 1, 1), ZOffset = 0.5 }), NOTINT)
		em(d, "Lower", with(jaw, { Color = VEN, LightEmission = 0.9, Brightness = 2, EmissionDirection = Enum.NormalId.Top, Rotation = R(180), Size = seq(0, 10, 1, 6.6), Transparency = seq(0, 0, 0.6, 0.1, 1, 1), ZOffset = 1.5 }))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.06), Size = seq(0, 2.4, 1, 3.4), Transparency = POP, ZOffset = 3 })
		em(p, "Spray", variant(GRID2, { Texture = TEX.goo, Color = VEN, LightEmission = 0.6, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Speed = R(30, 45), Drag = 3, Acceleration = Vector3.new(0, -30, 0), Lifetime = R(0.4, 0.6), Size = seq(0, 2, 1, 1), Transparency = seq(0, 0, 0.8, 0.2, 1, 1) }), n(10, 0.03))
	end

	---------------------------------------------------------------- venom

	-- SpitRelease (the Mouth, -Z = the shot; the rain aims it at the sky): a
	-- jet of venom out of the jaws. 4 layers: +0 the jet on its slate twin
	-- (hero), +0 flash, +40 mist at the lips.
	do
		local p = part(root, "SpitRelease", Vector3.new(0.4, 0.4, 0.4))
		local jet = { Texture = TEX.jet, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(12, 12), Speed = R(50, 70), Drag = 4, Lifetime = R(0.3, 0.38) }
		em(p, "JetDark", variant(GRID2, with(jet, { Color = CS(SLATE), Size = seq(0, 3.8, 1, 7), Transparency = seq(0, 0.2, 1, 1), ZOffset = 0.5 })), n(4, 0, { NoTint = true }))
		em(p, "Jet", variant(GRID2, with(jet, { Color = VEN, LightEmission = 0.7, Brightness = 1.5, Size = seq(0, 3.2, 1, 6), Transparency = seq(0, 0, 0.6, 0.2, 1, 1), ZOffset = 1.5 })), n(5, 0))
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.06), Size = seq(0, 2.6, 1, 3.6), Transparency = POP, ZOffset = 3 })
		em(p, "Mist", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.25, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 10), Drag = 2, Lifetime = R(0.8, 1), Size = seq(0, 2.4, 1, 6), Transparency = seq(0, 0.35, 1, 1) }), n(4, 0.04))
	end

	-- VenomBolt (a real projectile in flight, the pool lobs and rain drops;
	-- authored as a 3-stud glob): a writhing glob the player reads and dodges.
	-- Hero: the glob on a slate halo with a white-hot core; drips; a slate and
	-- a venom trail (A0/A1 set by the runtime); a Shadow part on the ground.
	do
		local p = part(root, "VenomBolt", Vector3.new(0.4, 0.4, 0.4))
		local a0 = att(p, "A0", Vector3.new(0, 0.8, 0))
		local a1 = att(p, "A1", Vector3.new(0, -0.8, 0))
		for _, spec in { { "Dark", CS(SLATE), 0.34, 0.45, 1.6, 0 }, { "Wide", CS({ CK(0, VHOT), CK(1, VENOM) }), 0.26, 0.15, 1.1, 0.8 } } do
			local t = Instance.new("Trail")
			t.Name = spec[1]
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = spec[2]
			t.LightEmission = spec[6]
			t.LightInfluence = 0
			t.Lifetime = spec[3]
			t.MinLength = 0.05
			t.FaceCamera = true
			t.Enabled = false
			t.Transparency = NS({ KP(0, spec[4]), KP(1, 1) })
			t.WidthScale = NS({ KP(0, spec[5]), KP(1, 0) })
			t.Parent = p
		end
		em(p, "Halo", { Texture = TEX.dot, Color = CS(SLATE), Rate = 14, Lifetime = R(0.16), Size = seq(0, 4.6, 1, 4.2), Transparency = seq(0, 0.45, 1, 1), LockedToPart = true, ZOffset = 0.5 }, { NoTint = true })
		em(p, "Glob", { Texture = TEX.glob, Color = CS(WHITE), LightEmission = 0.6, Brightness = 1.6, Rate = 12, Lifetime = R(0.18), Size = seq(0, 3.6, 1, 3.2), Transparency = seq(0, 0.05, 1, 1), Rotation = R(0, 360), RotSpeed = R(-220, 220), LockedToPart = true, ZOffset = 1.2 }, { NoTint = true })
		em(p, "Core", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Rate = 18, Lifetime = R(0.1), Size = seq(0, 1.3, 1, 1), Transparency = POP, LockedToPart = true, ZOffset = 2 }, { NoTint = true })
		em(p, "Drips", variant(GRID2, { Texture = TEX.goo, Color = VEN, LightEmission = 0.5, Rate = 10, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, -40, 0), Lifetime = R(0.4, 0.55), Size = seq(0, 0.9, 1, 0.4), Transparency = seq(0, 0.1, 1, 0.8) }))
		local shadow = part(p, "Shadow", Vector3.new(0.4, 0.2, 0.4))
		em(shadow, "Shadow", with(FLAT, { Texture = TEX.dot, Color = CS(INK), Rate = 10, Lifetime = R(0.2), Size = NS(3.4), Transparency = seq(0, 0.5, 1, 0.8), LockedToPart = true, ZOffset = 0.1 }), { NoTint = true })
	end

	-- BoltSplat (where a glob ends; authored for a 3-stud glob): the venom
	-- bursting. 5 layers: +0 flash, +0 the splash rising on its slate twin
	-- (hero), +30 drops flung, +80 a fume.
	do
		local p = part(root, "BoltSplat", Vector3.new(0.4, 0.4, 0.4))
		local up = att(p, "Up", Vector3.new(0, 1.2, 0))
		em(up, "Flash", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.1), Size = seq(0, 2, 1, 6), Transparency = POP, ZOffset = 3 })
		local burst = { Texture = TEX.splash, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(6, 10), Drag = 5, Lifetime = R(0.3, 0.36), Rotation = R(-20, 20) }
		em(p, "BurstDark", variant(GRID2, with(burst, { Color = CS(SLATE), Size = seq(0, 3.6, 1, 6.6), Transparency = seq(0, 0.2, 0.6, 0.35, 1, 1), ZOffset = 0.5 })), n(3, 0, { NoTint = true }))
		em(p, "Burst", variant(GRID2, with(burst, { Color = VEN, LightEmission = 0.7, Brightness = 1.5, Size = seq(0, 3, 1, 5.8), Transparency = seq(0, 0, 0.6, 0.15, 1, 1), ZOffset = 1.5 })), n(4, 0))
		em(up, "Drops", variant(GRID2, { Texture = TEX.goo, Color = VEN, LightEmission = 0.6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(14, 22), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.5, 0.75), Size = seq(0, 1, 1, 0.5), Transparency = seq(0, 0, 0.8, 0.2, 1, 1) }), n(8, 0.03))
		em(up, "Fume", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.3, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(2, 4), Lifetime = R(1, 1.3), Size = seq(0, 2.5, 1, 5), Transparency = seq(0, 0.3, 1, 1) }), n(3, 0.08))
	end

	-- GroundSplat (the floor under a splat; authored r3): the venom stain on
	-- its slate twin. 2 layers (one rotation, set by the runtime).
	do
		local p = part(root, "GroundSplat", Vector3.new(6, 0.2, 6), { AuthoredRadius = 3 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "SplatDark", with(FLAT, { Texture = TEX.splat, Color = CS(SLATE), Lifetime = R(1.6), Size = seq(0, 6.5, 0.1, 12.6, 1, 13), Transparency = seq(0, 0.1, 0.6, 0.3, 1, 1), ZOffset = 0.2 }), NOTINT)
		em(g, "Splat", with(FLAT, { Texture = TEX.splat, Color = CS(VENOM), LightEmission = 0.6, Lifetime = R(1.4), Size = seq(0, 5.4, 0.1, 10.8, 1, 11.2), Transparency = seq(0, 0.1, 0.6, 0.3, 1, 1), ZOffset = 0.4 }))
	end

	-- PoolDisc (where a pool glob lands; authored r7, 7 s): the poison pool
	-- itself (the hazard). 4 layers: the puddle on its slate twin (hero, one
	-- rotation set by the runtime; the splat fills about half its texture, so
	-- it is drawn twice the pool), bubbles popping, a thin fume.
	do
		local p = part(root, "PoolDisc", Vector3.new(14, 0.2, 14), { AuthoredRadius = 7, AuthoredSeconds = 7 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "PoolDark", with(FLAT, { Texture = TEX.splat, Color = CS(SLATE), Lifetime = R(7), Size = seq(0, 16, 0.03, 31, 1, 32), Transparency = seq(0, 0.1, 0.85, 0.2, 1, 1), ZOffset = 0.2 }), NOTINT)
		em(g, "Pool", with(FLAT, { Texture = TEX.splat, Color = CS(VENOM), LightEmission = 0.45, Lifetime = R(7), Size = seq(0, 14, 0.03, 28, 1, 29), Transparency = seq(0, 0.2, 0.85, 0.3, 1, 1), ZOffset = 0.4 }))
		em(p, "Bubbles", { Texture = TEX.bubble, Color = VEN, LightEmission = 0.6, Rate = 4, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(0.3, 0.8), Lifetime = R(0.6, 1), Size = seq(0, 0.3, 0.85, 1.4, 1, 1.8), Transparency = seq(0, 0.3, 0.85, 0.3, 1, 1), ZOffset = 0.6 }, { EmitDuration = 6.6 })
		em(p, "Fume", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.25, Rate = 1.5, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(1, 2), Lifetime = R(1.8, 2.4), Size = seq(0, 3, 1, 6), Transparency = seq(0, 0.45, 1, 1) }), { EmitDuration = 6.4 })
	end

	---------------------------------------------------------------- the coil

	-- CoilSlam (the coil's centre at CoilAt; authored r12, the ring radius):
	-- the body slapping down round the circle. 2 layers off the rim: dust
	-- rising (hero), clods.
	do
		local p = part(root, "CoilSlam", Vector3.new(24, 0.2, 24), { AuthoredRadius = 12 })
		em(p, "Dust", soilDust(with(RIM, { EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(5, 11), Drag = 1.5, Lifetime = R(0.9, 1.3), Size = seq(0, 5, 1, 11), Transparency = THIN })), n(30, 0, { NoTint = true }))
		em(p, "Clods", clods(with(RIM, { EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(16, 26), Lifetime = R(0.6, 0.9), Size = NS(1.4) })), n(12, 0.02, { NoTint = true }))
	end

	-- CoilSqueeze (the centre; authored r12): the coil crushing in. 3 layers +
	-- 1 wave: +0 a torn air ring collapsing on the centre, dust shoved in off
	-- the rim (hero), +0 a crush flash at the centre, +60 venom forced up.
	do
		local p = part(root, "CoilSqueeze", Vector3.new(24, 0.2, 24), { AuthoredRadius = 12 })
		local up = att(p, "Up", Vector3.new(0, 3, 0))
		wave(p, "Collapse", MESH.squeezeRing, { dark = true, from = Vector3.new(26, 3, 26), to = Vector3.new(4, 1.5, 4), fromOffset = Vector3.new(0, 1.5, 0), toOffset = Vector3.new(0, 2, 0), fromT = 0.35, duration = 0.32, style = "Quad" })
		em(p, "Dust", soilDust(with(RIM, { ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(5, 5), Speed = R(18, 22), Lifetime = R(0.55, 0.65), Size = seq(0, 6, 1, 3), Transparency = seq(0, 0.25, 0.7, 0.45, 1, 1) })), n(26, 0, { NoTint = true }))
		em(up, "Crush", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.12), Size = seq(0, 3, 1, 12), Transparency = POP, ZOffset = 3 }, n(1, 0.25))
		em(up, "Gush", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.3, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(8, 14), Drag = 1, Lifetime = R(1, 1.3), Size = seq(0, 4, 1, 10), Transparency = seq(0, 0.3, 1, 1) }), n(6, 0.3))
		shake(p, "Custom,20~80,1.4,0.4,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- CoilBreak (the centre; authored r12): the ring forced open, the coil
	-- recoiling. 2 layers off the rim: scales flung out (hero), dust.
	do
		local p = part(root, "CoilBreak", Vector3.new(24, 0.2, 24), { AuthoredRadius = 12 })
		em(p, "Scales", with(RIM, { Texture = TEX.scale, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 0.5, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(18, 28), Drag = 1, Acceleration = Vector3.new(0, -40, 0), Lifetime = R(0.8, 1.2), Size = NS(1.4), Transparency = seq(0, 0, 0.7, 0.2, 1, 1), Rotation = R(0, 360), RotSpeed = R(-300, 300) }), n(20, 0))
		em(p, "Dust", soilDust(with(RIM, { ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(14, 20), Drag = 3, Lifetime = R(0.8, 1.1), Size = seq(0, 4, 1, 9), Transparency = THIN })), n(16, 0.03, { NoTint = true }))
	end

	-- CoilGate (each edge of the door left open in the ring, through the
	-- hold): venom breathing off the coil's open ends, so the way out reads.
	-- 2 layers: a rising wisp, a low glow on the floor.
	do
		local p = part(root, "CoilGate", Vector3.new(3, 1, 3))
		em(p, "Wisp", flip8({ Texture = TEX.rise, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Rate = 6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8), Speed = R(4, 7), Lifetime = R(0.9, 1.2), Size = seq(0, 2.4, 1, 4.4), Transparency = seq(0, 0.25, 1, 1) }), { NoTint = true })
		em(p, "Glow", with(FLAT, { Texture = TEX.dot, Color = CS(JADE), LightEmission = 1, Rate = 3, Lifetime = R(0.6), Size = NS(4), Transparency = seq(0, 1, 0.3, 0.55, 0.7, 0.55, 1, 1), LockedToPart = true, ZOffset = 0.3 }), { NoTint = true })
	end

	---------------------------------------------------------------- the hiss

	-- HissWave (the Mouth, level with the head): the hiss radiating all round.
	-- 1 layer + 3 waves: +0 a torn sound ring racing out to r30 on its slate
	-- twin (hero), +120 a second ring, +60 venom breath out of the jaws.
	do
		local p = part(root, "HissWave", Vector3.new(0.4, 0.4, 0.4))
		wave(p, "RingDark", MESH.soundRing, { dark = true, from = Vector3.new(5, 1.2, 5), to = Vector3.new(62, 3, 62), fromT = 0.4, duration = 0.5 })
		wave(p, "Ring", MESH.soundRing, { from = Vector3.new(4.6, 1, 4.6), to = Vector3.new(58, 2.6, 58), fromT = 0.3, duration = 0.46 })
		wave(p, "Ring2", MESH.soundRing, { material = Enum.Material.ForceField, from = Vector3.new(4, 1, 4), to = Vector3.new(66, 2.4, 66), fromT = 0.5, duration = 0.55, delay = 0.12, rotation = Vector3.new(0, 40, 0) })
		em(p, "Breath", { Texture = TEX.curl, Color = CS(VENOM), LightEmission = 0.25, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(22, 22), Speed = R(30, 40), Drag = 3, Lifetime = R(0.9, 1.2), Size = seq(0, 4, 1, 12), Transparency = seq(0, 0.45, 1, 1), Rotation = R(0, 360), RotSpeed = R(-30, 30) }, n(5, 0.06))
		shake(p, "Custom,20~90,1.2,0.4,14,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- HissDust (the ground under the head; authored r30): dust shoved off the
	-- ground by the hiss. 1 layer at +80.
	do
		local p = part(root, "HissDust", Vector3.new(4, 0.2, 4), { AuthoredRadius = 30 })
		em(p, "Dust", soilDust(with(RADIAL, { Speed = R(40, 52), Drag = 1.7, Lifetime = R(0.9, 1.2), Size = seq(0, 4, 1, 10), Transparency = THIN })), n(18, 0.08, { NoTint = true }))
	end

	---------------------------------------------------------------- phases

	-- ShedBurst (each body hook and the Core, the molt's phase step): the old
	-- skin sloughs off all at once. 2 layers: scales burst off (hero), a
	-- dull dust of old skin.
	do
		local p = part(root, "ShedBurst", Vector3.new(4, 3, 4))
		em(p, "Scales", { Texture = TEX.scale, Color = CS({ CK(0, VHOT), CK(1, VDEEP) }), LightEmission = 0.4, LightInfluence = 0.5, Shape = Enum.ParticleEmitterShape.Box, SpreadAngle = Vector2.new(180, 180), Speed = R(10, 18), Drag = 2, Acceleration = Vector3.new(0, -14, 0), Lifetime = R(1, 1.5), Size = NS(1.3), Transparency = seq(0, 0, 0.8, 0.3, 1, 1), Rotation = R(0, 360), RotSpeed = R(-200, 200) }, n(10, 0))
		em(p, "Dust", cloud({ Color = CS(Color3.fromRGB(120, 140, 100)), Shape = Enum.ParticleEmitterShape.Box, SpreadAngle = Vector2.new(180, 180), Speed = R(3, 6), Drag = 1.5, Lifetime = R(1.2, 1.6), Size = seq(0, 4, 1, 9), Transparency = seq(0, 0.45, 1, 1) }), n(3, 0.05, { NoTint = true }))
	end

	-- AscendSurge (the Core, the ascension's phase step): the jiao's qi
	-- surging up out of the body as it ascends. 3 layers + 1 wave: +0 flash,
	-- +0 a twisting jade column rising (hero, ForceField: moving air, not a
	-- solid) over a slate puff, +40 motes streaming up.
	do
		local p = part(root, "AscendSurge", Vector3.new(4, 4, 4))
		em(p, "Flash", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.14), Size = seq(0, 4, 1, 16), Transparency = POP, ZOffset = 3 }, NOTINT)
		em(p, "Dark", flip8({ Texture = TEX.fume, Color = CS(SLATE), SpreadAngle = Vector2.new(180, 180), Speed = R(4, 8), Drag = 2, Lifetime = R(0.9, 1.2), Size = seq(0, 9, 1, 18), Transparency = seq(0, 0.1, 1, 1) }), n(6, 0, { NoTint = true }))
		wave(p, "Glow", MESH.twister, { noTint = true, color = JADE, from = Vector3.new(4, 7, 4), to = Vector3.new(10, 40, 10), fromOffset = Vector3.new(0, 2, 0), toOffset = Vector3.new(0, 20, 0), rotation = Vector3.new(0, 60, 0), fromT = 0.6, duration = 0.9, style = "Quint", fade = "Quad" })
		wave(p, "Column", MESH.twister, { noTint = true, color = JADE, material = Enum.Material.ForceField, from = Vector3.new(6, 8, 6), to = Vector3.new(15, 44, 15), fromOffset = Vector3.new(0, 2, 0), toOffset = Vector3.new(0, 22, 0), fromT = 0, duration = 0.95, style = "Quint", fade = "Quad" })
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(25, 45), Drag = 1.5, Lifetime = R(0.9, 1.4), Size = seq(0, 0.8, 1, 0), Transparency = seq(0, 0, 0.7, 0.2, 1, 1) }, n(20, 0.04, { NoTint = true }))
		shake(p, "Custom,25~120,1.8,0.6,14,0.02,1;1;1,0.06;0.06;0.06")
	end

	---------------------------------------------------------------- hits

	local function hit(name, build)
		local p = part(root, name, Vector3.new(0.4, 0.4, 0.4))
		build(p)
	end
	-- the fangs puncture: flash, venom spatter on its slate twin
	hit("HitFang", function(p)
		em(p, "Flash", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.08), Size = seq(0, 1.5, 1, 5), Transparency = POP, ZOffset = 3 })
		local spat = { Texture = TEX.splash, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(8, 14), Drag = 6, Lifetime = R(0.25, 0.3), Rotation = R(0, 360) }
		em(p, "SpatterDark", variant(GRID2, with(spat, { Color = CS(SLATE), Size = seq(0, 2.4, 1, 4.4), Transparency = seq(0, 0.2, 1, 1), ZOffset = 0.5 })), n(2, 0, { NoTint = true }))
		em(p, "Spatter", variant(GRID2, with(spat, { Color = VEN, LightEmission = 0.7, Size = seq(0, 2, 1, 3.8), Transparency = seq(0, 0, 0.6, 0.15, 1, 1), ZOffset = 1.5 })), n(3, 0))
	end)
	-- the tail's blunt blow: a soft burst, a puff of dust
	hit("HitTail", function(p)
		em(p, "Flash", { Texture = TEX.softStar, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.1), Size = seq(0, 2, 1, 7), Transparency = POP, ZOffset = 3 })
		em(p, "Dust", cloud({ SpreadAngle = Vector2.new(180, 180), Speed = R(5, 9), Drag = 3, Lifetime = R(0.6, 0.9), Size = seq(0, 2.4, 1, 6), Transparency = seq(0, 0.4, 1, 1) }), n(3, 0.03, { NoTint = true }))
	end)
	-- the slam, erupt, coil: a heavy contact, a slate shock ring, dust
	hit("HitHeavy", function(p)
		em(p, "Flash", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.1), Size = seq(0, 2, 1, 8), Transparency = POP, ZOffset = 3 })
		wave(p, "Shock", MESH.shockA, { dark = true, from = Vector3.new(2, 0.6, 2), to = Vector3.new(11, 1.2, 11), rotation = Vector3.new(90, 0, 0), fromT = 0.25, duration = 0.25, delay = 0.02 })
		em(p, "Dust", cloud({ SpreadAngle = Vector2.new(180, 180), Speed = R(6, 10), Drag = 3, Lifetime = R(0.6, 0.9), Size = seq(0, 2.6, 1, 6.4), Transparency = seq(0, 0.4, 1, 1) }), n(4, 0.04, { NoTint = true }))
	end)
	-- a venom glob bursting on the body: the splat on its slate twin, a fume
	hit("HitVenom", function(p)
		em(p, "SplatDark", { Texture = TEX.splat, Color = CS(SLATE), Lifetime = R(0.28), Size = seq(0, 1.6, 1, 5.2), Transparency = seq(0, 0.2, 1, 1), Rotation = R(0, 360), ZOffset = 0.5 }, NOTINT)
		em(p, "Splat", { Texture = TEX.splat, Color = VEN, LightEmission = 0.7, Lifetime = R(0.25), Size = seq(0, 1.3, 1, 4.6), Transparency = seq(0, 0, 0.6, 0.15, 1, 1), Rotation = R(0, 360), ZOffset = 1.5 })
		em(p, "Fume", flip8({ Texture = TEX.fume, Color = CS(VENOM), LightEmission = 0.3, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(2, 4), Lifetime = R(0.8, 1.1), Size = seq(0, 2, 1, 4), Transparency = seq(0, 0.35, 1, 1) }), n(2, 0.06))
	end)

	-- StaggerFlare (the Core): a player's blow knocking scales loose. 2
	-- layers: +0 flash, +0 scale chips flying.
	do
		local p = part(root, "StaggerFlare", Vector3.new(3, 3, 3))
		em(p, "Flash", { Texture = TEX.star, Color = VEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.1), Size = seq(0, 2, 1, 8), Transparency = POP, ZOffset = 3 })
		em(p, "Chips", { Texture = TEX.shard, Color = CS(Color3.fromRGB(120, 160, 110)), LightInfluence = 0.6, SpreadAngle = Vector2.new(180, 180), Speed = R(12, 20), Acceleration = Vector3.new(0, -50, 0), Lifetime = R(0.6, 0.9), Size = NS(1), Rotation = R(0, 360), RotSpeed = R(-400, 400), Transparency = seq(0, 0, 0.8, 0.2, 1, 1) }, n(7, 0, { NoTint = true }))
	end

	---------------------------------------------------------------- death

	-- DeathBleed (every body hook, 0-1000 while the body fades): venom and
	-- qi leaving the body. 2 layers: fumes rising, motes drifting up.
	do
		local p = part(root, "DeathBleed", Vector3.new(4, 3, 4), { AuthoredSeconds = 1 })
		em(p, "Seep", flip8({ Texture = TEX.rise, Color = CS({ CK(0, JADE), CK(1, VENOM) }), LightEmission = 1, Rate = 8, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(4, 8), Lifetime = R(0.8, 1.2), Size = seq(0, 2.4, 1, 5.5), Transparency = seq(0, 0.3, 1, 1) }), { EmitDuration = 1, NoTint = true })
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Rate = 10, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(6, 12), Lifetime = R(0.8, 1.2), Size = seq(0, 0.6, 1, 0), Transparency = seq(0, 0, 0.7, 0.2, 1, 1) }, { EmitDelay = 0.3, EmitDuration = 0.7, NoTint = true })
	end

	-- SpiritRise (where the Core was, 1000 after death): the jiao's spirit
	-- leaving. 4 layers + 1 wave: +0 flash, +0 a twisting jade column rising
	-- (hero) over a slate puff, +30 the spirit swirl blooming, +60 motes.
	do
		local p = part(root, "SpiritRise", Vector3.new(4, 4, 4))
		em(p, "Flash", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 4, Lifetime = R(0.16), Size = seq(0, 5, 1, 20), Transparency = POP, ZOffset = 3 }, NOTINT)
		em(p, "Dark", flip8({ Texture = TEX.fume, Color = CS(SLATE), SpreadAngle = Vector2.new(180, 180), Speed = R(4, 8), Drag = 2, Lifetime = R(1, 1.3), Size = seq(0, 7, 1, 15), Transparency = seq(0, 0.35, 1, 1) }), n(5, 0, { NoTint = true }))
		wave(p, "Glow", MESH.spirit, { noTint = true, color = JADE, from = Vector3.new(4, 7, 4), to = Vector3.new(11, 50, 11), fromOffset = Vector3.new(0, 2, 0), toOffset = Vector3.new(0, 25, 0), rotation = Vector3.new(0, 60, 0), fromT = 0.6, duration = 1.4, style = "Quint", fade = "Quad" })
		wave(p, "Column", MESH.spirit, { noTint = true, color = JADE, material = Enum.Material.ForceField, from = Vector3.new(6, 8, 6), to = Vector3.new(16, 56, 16), fromOffset = Vector3.new(0, 2, 0), toOffset = Vector3.new(0, 28, 0), fromT = 0, duration = 1.5, style = "Quint", fade = "Quad" })
		em(p, "Swirl", { Texture = TEX.swirl, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = seq(0, 4, 0.4, 18, 1, 22), Transparency = seq(0, 0.1, 0.6, 0.3, 1, 1), Rotation = R(0, 360), RotSpeed = R(120), ZOffset = 2 }, n(1, 0.03, { NoTint = true }))
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(14, 30), Drag = 1, Lifetime = R(1.4, 2.2), Size = seq(0, 0.9, 1, 0), Transparency = seq(0, 0, 0.7, 0.2, 1, 1) }, n(24, 0.06, { NoTint = true }))
		shake(p, "Custom,25~150,1.6,0.8,12,0.02,1;1;1,0.06;0.06;0.06")
	end

	---------------------------------------------------------------- aura

	-- Aura (always on; the runtime clones each emitter onto the body). Kept
	-- from the first pass, minus its ground mandala and sigil (no always-on
	-- ground circles). `BaseRate` is the rate at full health; code scales it
	-- up as the Jiao is hurt.
	do
		local p = part(root, "AuraBody", Vector3.new(3, 3, 3))
		em(p, "Mist", { Texture = TEX.puff, Color = CS(VDEEP), LightEmission = 0.2, Rate = 3, Shape = Enum.ParticleEmitterShape.Sphere, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(1, 3), Acceleration = Vector3.new(0, 1, 0), Lifetime = R(1.6, 2.4), Size = seq(0, 3, 1, 9), Transparency = seq(0, 0.8, 0.3, 0.65, 1, 1), Rotation = R(0, 360) })
		em(p, "Motes", { Texture = TEX.dot, Color = CS({ CK(0, VHOT), CK(1, VENOM) }), LightEmission = 1, Rate = 3, Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 1.4, 0), Lifetime = R(2, 3.2), Size = seq(0, 0.6, 1, 0), Transparency = seq(0, 1, 0.2, 0.2, 0.8, 0.4, 1, 1) })
		-- phase 3: pale spirit-jade
		em(p, "JadeWisp", { Texture = TEX.flame, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Rate = 0, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(2, 5), Lifetime = R(0.9, 1.5), Size = seq(0, 2.6, 1, 0.8), Transparency = seq(0, 0.55, 0.3, 0.4, 1, 1), Rotation = R(-15, 15) })
		em(p, "JadeMotes", { Texture = TEX.auraGlint, Color = CS({ CK(0, WHITE), CK(1, JADE) }), LightEmission = 1, Rate = 0, Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 2, 0), Lifetime = R(2, 3), Size = seq(0, 0.9, 1, 0), Transparency = seq(0, 1, 0.2, 0.2, 0.8, 0.4, 1, 1) })
	end
	do
		local p = part(root, "AuraBreath", Vector3.new(0.4, 0.4, 0.4))
		em(p, "Mist", { Texture = TEX.puff, Color = CS(VENOM), LightEmission = 0.2, Rate = 3, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(20, 20), Speed = R(2, 4), Drag = 1, Acceleration = Vector3.new(0, -0.8, 0), Lifetime = R(1.1, 1.7), Size = seq(0, 1.2, 1, 4.4), Transparency = seq(0, 0.75, 0.3, 0.6, 1, 1), Rotation = R(0, 360) })
	end
	-- Mound (idle while Burrowed): a dust leak and green glints on the earth
	-- over the sunk body (the dome itself is a code-built soil ball).
	do
		local p = part(root, "MoundFX", Vector3.new(8, 1, 8))
		em(p, "Leak", { Texture = TEX.puff, Color = CS(DUST), Rate = 2.4, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(1.5, 3.5), Lifetime = R(1.6, 2.6), Size = seq(0, 2, 1, 7), Transparency = seq(0, 0.6, 0.4, 0.6, 1, 1), Rotation = R(0, 360) })
		em(p, "Glints", { Texture = TEX.auraGlint, Color = CS({ CK(0, WHITE), CK(1, VENOM) }), LightEmission = 1, Rate = 0.9, Shape = Enum.ParticleEmitterShape.Sphere, Lifetime = R(0.6, 1.0), Size = seq(0, 0.4, 0.5, 3.2, 1, 0), Transparency = seq(0, 0.2, 1, 1), ZOffset = 2 })
		em(p, "Seep", with(FLAT, { Texture = TEX.crackGlow, Color = CS(VENOM), LightEmission = 1, Rate = 0.6, Lifetime = R(2.2), Size = NS(10), Transparency = seq(0, 1, 0.3, 0.55, 0.7, 0.6, 1, 1), Rotation = R(0, 360), ZOffset = 0.5 }))
	end

	root.Parent = effects
	return root
end
print("buildJadeJiaoFX installed")
return true
