--!nocheck
-- Builder for ReplicatedStorage.Effects.NineTailFox: the Nine-Tailed Fox
-- boss's attack, hit, phase and death effects (rebuilt 2026-10-22 with the
-- intent-first method, .claude/agents/vfx.md). Load through the receiver, then
-- build into the live Effects folder in a sandbox:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/NineTailFox.luau")
--   require(m)  -- installs _G.buildNineTailFoxFX(effectsFolder)
-- Runtime: src/client/EnemyFX/NineTailFox.luau (cue -> template, placement,
-- sounds). The fight sheet and this pass's record: docs/enemies/nine-tailed-fox.md
-- "Nine-Tailed Fox".
--
-- Identity: foxfire, a spirit flame that burns cold. Authored azure with a
-- white-hot core; the runtime re-tints every bright layer (LightEmission > 0.3,
-- and Neon mesh waves) by Phase: azure, violet, white-hot with a crimson edge.
-- `NoTint` keeps a layer's own colour (slate bases, the pale scream, dust).
-- Every bright hero sits on a slate twin of its own shape (never a disc).
--
-- The rule of this pass: every layer is caused by the body doing the move,
-- one hero per peak, starts staggered behind their cause (EmitDelay), one
-- peak. What was cut and why:
--   - ground sigils under the intro, the phase break and each Nine-Tail Fall
--     circle (Sigil, FallSigil) and the lit Lane line along lance boxes: they
--     redrew the telegraph's job in a second colour (docs/systems/telegraphs.md);
--   - Kindle (flames out of the ground at the intro): nothing in the ground lit;
--   - the moon printed on the ground at the leap landing: a landing is weight
--     hitting the floor, so it is dust and a shock; the moon is the flip's arc;
--   - the second peak of the phase break (a star burst over the fox 0.85 s
--     after the release) and the roar thrown forward with the scream (a
--     scream radiates all round, it is not aimed);
--   - the shared Impact kit stacked on top of every eruption and bolt (two
--     impacts on one frame): each impact here is its own stack.
--
-- Beat sheets (ms from the cue; windups come from the attack table, the
-- release is the end of the windup, R = release):
--   intro (2200 windup): 250-2000 nine tails catch fire one by one (each a
--     TailIgnite, the flame catching), 1600-2200 breath drawn into the jaws
--     (RoarTell). R: the howl. +0 flash and the air front (RoarBreath hero),
--     +50 first sound ring, +80 dust shoved off the ground under the head
--     (RoarWave), +140 second ring, +80..1300 the breath mist thins.
--   fangDance (650 windup, bites at R+0/400/800): windup foxfire licks in the
--     jaws (Breath). Each bite: +0 the jaws close (two crescents shutting,
--     hero), +20 the bite's reach flies 12 studs down the cone, +50 embers.
--   tailSweep (900): tips 2/5/8 gather (TipCharge, motes in, ring closing in
--     the last third), foxfire runs down the tails (TailGlow). R: three
--     brushed ribbons ride the live tips (hero), dust at the arc's ends at
--     +140/+280.
--   tailLance / lanceFan (600 / 950): TipCharge on the tail; at hit - ext the
--     lance beam leaves the live tip led by a ribbon head (hero of the
--     travel); at the hit (LanceHit): +0 contact star, +20 earth splash on
--     its slate twin (hero), +30 chips, +50 glowing scar, +60 dust.
--   tailSnare (850): TipCharge; at hit - ext a wavy whip beam lashes out; the
--     `snare` cue coils a ribbon round the torso tethered to the tip.
--   rendingPounce (750): the hind paws dig in (Dust at 40%). Dash: take-off
--     dust, the white-gold streak riding the chest (hero). Land: skid dust.
--   foxfireVolley (1100): tips flare outside in (TipCharge). Bolts are real
--     projectiles: a turning striped foxfire orb on a slate halo (hero),
--     flame tongues and a comet tail, a shadow on the ground. Burst: +0 flash,
--     +0 burst opening into a broken ring (hero) on its slate twin, +30 shock
--     ring, +40 tongues, +60 scar, +120 smoke.
--   rootfireEruption (1500): tails glow (TailGlow) to 900; at 900 five tails
--     drive into the ground (PlungeImpact: star, splash crown, chips, dust,
--     scar that stays while they are buried); fissure ribbons crawl under the
--     ground to the circles, arriving at their hit; each circle erupts
--     (Eruption: +0 flash, +0 flame spikes rising out of the ground on their
--     slate twin (hero), +30 flame column, +50 scar, +80 embers, +150 smoke
--     plume). The heart also bursts (Burst).
--   moonLeap (400): hind paws dig in (Dust). Flight: the moon-crescent streak
--     on the chest (hero), the burning tails' trail (FireStrip) lights along
--     the flight and flares on each damage tick. Land: shock ring, dust ring
--     (hero), debris, tongues of the tails slapping down.
--   mournfulScream (1400): breath drawn into the throat (ScreamTell), lit
--     tails swell (TailFlare). R: +0 two sound rings racing out at head
--     height to r30 on a slate twin (hero), +20 speed lines, +40 the ground
--     shock ring under it, +100 dust shoved out; stars over the stunned.
--   nineTailFall (1800, P3): each tail rises and its flame swells (TailRise)
--     until its plunge; each circle: PlungeImpact under the tip, +70 Eruption.
--     Final (R+1900): FallBurst (+0 flash, burst and shock ring on slate twins
--     (hero), +30 flame spikes, +40 chips, +50 column, +60 scar, +80 dust,
--     +200 smoke).
--   veilBreak (1600): foxfire is drawn into the chest (Gather: wisps in, a
--     core swelling on slate, the orb forming in the last 500). R: +0 flash and
--     the veil shell bursting out of the chest (PhaseBurst hero), +20 streaks,
--     +60 the shell hits the ground (PhaseRing), +90 dust; follow-through:
--     shreds of the veil spiral up and fade (ribbons, runtime) and the new
--     phase's tails re-ignite 80 ms apart.
--   hit: flame burst (Hit) or rend crescent on slate (HitHeavy) on the near
--     side of the torso, contact star, embers +30.
--   death: tails gutter 1..9 200 ms apart, each sending a stream up (runtime
--     ribbons) while the body burns away (Dissolve, 2.6 s); the streams meet
--     at 2700: SoulRelease (spirit swirl bloom hero, glint, ring, twinkles
--     drifting down).
--
-- Library picks (searched fresh for this effect, by what each move causes;
-- 2026-10-22). Images unless marked; flipbooks are sprite sheets (Grid4x4).
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local AssetService = game:GetService("AssetService")
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local AZ = Color3.fromRGB(120, 205, 255)
local AZMID = Color3.fromRGB(190, 232, 255)
local PALE = Color3.fromRGB(214, 238, 255)
local HOT = Color3.fromRGB(255, 236, 176)
local GOLD = Color3.fromRGB(255, 196, 90)
local SLATE = Color3.fromRGB(34, 42, 58)
local INK = Color3.fromRGB(16, 18, 28)
local DUST = Color3.fromRGB(176, 184, 196)

local TEX = {
	-- cores and sparkles only (generic by design)
	dot = id(9841273544),
	-- flame catching / tongues: a stylised flame burst that breaks up (4x4)
	flameBurst = id(11568138775),
	-- foxfire running down a tail, heat off a swollen flame: wavy wisps (4x4)
	heatWisps = id(87957760009809),
	-- air drawn in / pushed out: small wisp strokes (4x4)
	airWisps = id(12094495797),
	-- contact: a star burst that breaks apart (4x4)
	contactStar = id(13580358178),
	-- explosion: a burst opening into a broken ring (4x4)
	burstRing = id(12360899465),
	-- a turning ball of foxfire: a striped sphere (4x4)
	orb = id(14451121834),
	-- smoke rising after fire (4x4)
	smoke = id(14200879082),
	-- dust shoved off the ground: puff breaking up (sheet, 4x4)
	dust = id(13826565206),
	-- earth thrown up by a spear or a tail (2x2 variants)
	splash = id(104431684789902),
	-- debris chips (8x8 variants)
	chips = id(140013412087432),
	-- dirt kicked upward by a paw or a landing
	kick = id(14050019657),
	-- a glowing scar left in the ground
	scar = id(92861858089952),
	-- the jaws: two crescents closing
	jaws = id(13463732785),
	-- a bite's reach, a rend: a thick brushed crescent
	crescent = id(109919844196737),
	-- speed lines of air or light: a thin bright line strip
	line = id(14050932611),
	-- a beam's glow: a soft fading strip
	strip = id(2443461141),
	-- a whip's body: a wavy strip
	whip = id(1177196540),
	-- breath and mist
	mist = id(1525327413),
	-- a rising smoke plume (eruptions)
	plume = id(9841282820),
	-- the scream's ground shock: a spiky ring
	spikyRing = id(85827484380910),
	-- the eyes and the struck core: a sharp four-point glint
	glint = id(243728206),
	-- stun stars
	star = id(7216853770),
	-- the spirit leaving the body: a spirit swirl
	spirit = id(14475273913),
	-- aura (unchanged from the first pass; not part of this rework)
	auraFlame = id(17703378809),
	twinkle = id(102648375149008),
	auraMist = id(14050360239),
}
local MESH = {
	soundRing = 113793875136271, -- a torn wind ring (flat in XZ): sound and air fronts
	screamRing = 99300490107593, -- a wider torn wind ring: the scream
	blastBowl = 114192967647602, -- a spiked bowl (opens +Y): the air front off the jaws
	spikes = 102470267627424, -- a fan of spikes (opens +Y): flame bursting out of the ground
	bigSpikes = 109653656002288, -- a wider spike fan: the final fall
	splashCrown = 89195313060285, -- a flat spiky splash: a tail driving into the ground
	shock = 1726537151, -- a flat shockwave ring: weight landing, a blast's ground ring
	veil = 102891032619654, -- a swirled sphere shell: the veil bursting off the fox
}
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local GRID2 = Enum.ParticleFlipbookLayout.Grid2x2
local GRID8 = Enum.ParticleFlipbookLayout.Grid8x8
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
local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
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
-- A 3D shock: a library mesh tweened From -> To by TechniqueVFX.playWaves.
-- Neon meshes are re-tinted by phase; `dark` makes the slate twin (NoTint).
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
	m.Material = if p.dark then Enum.Material.SmoothPlastic else Enum.Material.Neon
	m.Color = p.color or (if p.dark then SLATE else AZ)
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
local LATE = seq(0, 0.1, 0.5, 0.2, 1, 1)
local FIRE = CS({ CK(0, WHITE), CK(0.45, AZMID), CK(1, AZ) })
local NOTINT = { EmitCount = 1, NoTint = true }
local function n(count, delay, extra)
	local t = { EmitCount = count, EmitDelay = delay }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

function _G.buildNineTailFoxFX(effects)
	local old = effects:FindFirstChild("NineTailFox")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "NineTailFox"

	-- EyeGlint (each eye, 0-600 of every windup): the fox fixes on its prey.
	-- 2 layers: the glint (hero, 0-250), a held glow (core).
	do
		local p = part(root, "EyeGlint", nil, { AuthoredSeconds = 0.6 })
		em(p, "Glint", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 4, Lifetime = R(0.25), Size = seq(0, 0.6, 0.3, 3.6, 1, 0), Rotation = R(-8, 8), ZOffset = 2 })
		em(p, "Hold", { Texture = TEX.dot, Color = CS(AZ), LightEmission = 1, Lifetime = R(0.12, 0.2), Rate = 16, Size = seq(0, 1, 1, 0.5), Transparency = seq(0, 0.3, 1, 0.85), LockedToPart = true, ZOffset = 1.5 }, { EmitDuration = 0.6 })
	end

	-- Aura (always on; mounted by the runtime): unchanged from the first pass.
	do
		local p = part(root, "AuraTail", Vector3.new(1, 1, 1))
		em(p, "Flames", flip4({ Texture = TEX.auraFlame, Color = FIRE, LightEmission = 1, Rate = 5, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(1.5, 3.5), Lifetime = R(0.9, 1.5), Size = seq(0, 2, 1, 0.5), Transparency = seq(0, 0.5, 0.3, 0.35, 1, 1), Rotation = R(-15, 15) }))
		em(p, "Motes", { Texture = TEX.dot, Color = CS(AZMID), LightEmission = 1, Rate = 3, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 1.4, 0), Lifetime = R(1.8, 3), Size = seq(0, 0.45, 1, 0), Transparency = seq(0, 1, 0.2, 0.2, 0.8, 0.4, 1, 1) })
	end
	do
		local p = part(root, "AuraGround", Vector3.new(16, 0.2, 16))
		em(p, "Motes", flip4({ Texture = TEX.twinkle, Color = CS(AZMID), LightEmission = 1, Rate = 2.5, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(1, 2.5), Lifetime = R(1.6, 2.6), Size = seq(0, 0.8, 1, 0.3), Transparency = seq(0, 1, 0.2, 0.15, 0.8, 0.4, 1, 1) }))
		em(p, "Mist", { Texture = TEX.auraMist, Color = CS(PALE), Rate = 1.6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(0.6, 1.4), Lifetime = R(3, 4.5), Size = seq(0, 5, 1, 11), Transparency = seq(0, 1, 0.25, 0.82, 1, 1), Rotation = R(0, 360), RotSpeed = R(-8, 8), ZOffset = 0.2 })
	end

	-- TipCharge (a tail tip, held to its strike; authored 600): foxfire drawn
	-- into the flame from the air round it. 4 layers: wisps streaming in
	-- (0-600), the core swelling on its slate twin (hero), a ring closing in
	-- the last third (400-600: "it fires now").
	do
		local p = part(root, "TipCharge", Vector3.new(7, 7, 7), { AuthoredSeconds = 0.6 })
		em(p, "Draw", flip4({ Texture = TEX.airWisps, Color = FIRE, LightEmission = 1, Brightness = 1.5, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 18, Speed = R(10, 14), Lifetime = R(0.3, 0.36), Size = seq(0, 1.6, 1, 0.5), Transparency = seq(0, 1, 0.3, 0.2, 1, 0.8), Rotation = R(0, 360), LockedToPart = true }), { EmitDuration = 0.6 })
		em(p, "CoreDark", { Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(0.6), Size = seq(0, 0.8, 1, 3.2), Transparency = seq(0, 0.8, 0.8, 0.45, 1, 1), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Core", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.6), Size = seq(0, 0.5, 0.85, 2.2, 1, 2.6), Transparency = seq(0, 0.7, 0.85, 0.05, 1, 0.6), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Close", { Texture = TEX.spikyRing, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.2), Size = seq(0, 6, 1, 0.8), Transparency = seq(0, 1, 0.3, 0.2, 1, 0.4), LockedToPart = true, ZOffset = 1 }, { EmitCount = 1, EmitDelay = 0.4 })
	end

	-- TailIgnite (a tail's flame catching: the intro lights nine in turn, the
	-- phase break re-lights the new phase's tails, the volley's bolts leave
	-- one, the death gutters one). 3 layers: +0 a white flash (core), +0 the
	-- flame bursting up (hero), +40 embers.
	do
		local p = part(root, "TailIgnite")
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.08), Size = seq(0, 2.4, 1, 4), Transparency = POP, ZOffset = 3 })
		em(p, "Catch", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 2.5, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(3, 6), Drag = 3, Lifetime = R(0.45, 0.55), Size = seq(0, 3.2, 1, 4), Transparency = FADE, Rotation = R(-15, 15), ZOffset = 2 }), n(2, 0))
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(6, 12), Drag = 2, Acceleration = Vector3.new(0, 3, 0), Lifetime = R(0.5, 0.8), Size = seq(0, 0.4, 1, 0), Transparency = FADE }, n(5, 0.04))
	end

	-- TailGlow (mounted on a tail's sleeves for a windup): foxfire running
	-- down the tail into its tip. 1 layer.
	do
		local p = part(root, "TailGlow", Vector3.new(1, 1, 1))
		em(p, "Wisps", flip4({ Texture = TEX.heatWisps, Color = FIRE, LightEmission = 1, Rate = 9, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(1, 2.5), Lifetime = R(0.4, 0.55), Size = seq(0, 1.6, 1, 0.8), Transparency = seq(0, 0.6, 0.3, 0.3, 1, 1) }))
	end

	-- RoarTell (the Mouth, the intro's last 600): breath pulled into the
	-- jaws, the maw glowing up. 2 layers.
	do
		local p = part(root, "RoarTell", Vector3.new(8, 8, 8), { AuthoredSeconds = 0.6 })
		em(p, "Inhale", flip4({ Texture = TEX.airWisps, Color = CS(PALE), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 22, Speed = R(14, 20), Lifetime = R(0.3, 0.38), Size = seq(0, 1.8, 1, 0.6), Transparency = seq(0, 1, 0.3, 0.3, 1, 1), Rotation = R(0, 360), LockedToPart = true }), { EmitDuration = 0.6, NoTint = true })
		em(p, "Maw", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.6), Size = seq(0, 0.3, 1, 2.2), Transparency = seq(0, 0.9, 0.9, 0.2, 1, 1), LockedToPart = true, ZOffset = 1 })
	end

	-- RoarBreath (the Mouth, facing -Z; the intro's howl): a blast of air and
	-- sound out of the jaws. 6 layers: +0 flash, +0 the air front (spiked
	-- bowl opening forward, hero), +50 first sound ring on its slate twin,
	-- +30 speed lines, +140 second ring, +80 breath mist (the tail, to 1300).
	do
		local p = part(root, "RoarBreath")
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.08), Size = seq(0, 3, 1, 5), Transparency = POP, ZOffset = 3 })
		wave(p, "Front", MESH.blastBowl, { from = Vector3.new(2, 2, 2), to = Vector3.new(12, 13, 12), fromOffset = Vector3.new(0, 0, -1), toOffset = Vector3.new(0, 0, -11), rotation = Vector3.new(-90, 0, 0), fromT = 0.1, duration = 0.3 })
		wave(p, "RingDark", MESH.soundRing, { dark = true, from = Vector3.new(3.4, 0.7, 3.4), to = Vector3.new(18, 2.4, 18), fromOffset = Vector3.new(0, 0, -1.5), toOffset = Vector3.new(0, 0, -16), rotation = Vector3.new(90, 0, 0), fromT = 0.45, duration = 0.4, delay = 0.05 })
		wave(p, "Ring", MESH.soundRing, { from = Vector3.new(3, 0.6, 3), to = Vector3.new(16, 2, 16), fromOffset = Vector3.new(0, 0, -1.5), toOffset = Vector3.new(0, 0, -16), rotation = Vector3.new(90, 0, 0), fromT = 0.2, duration = 0.38, delay = 0.05 })
		wave(p, "Ring2", MESH.soundRing, { from = Vector3.new(3, 0.6, 3), to = Vector3.new(22, 2, 22), fromOffset = Vector3.new(0, 0, -1.5), toOffset = Vector3.new(0, 0, -24), rotation = Vector3.new(90, 0, 0), fromT = 0.45, duration = 0.45, delay = 0.14 })
		em(p, "Lines", { Texture = TEX.line, Color = CS(PALE), LightEmission = 1, Brightness = 1.5, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(18, 18), Speed = R(70, 95), Drag = 4, Lifetime = R(0.22, 0.3), Size = seq(0, 4, 1, 0.6), Transparency = seq(0, 0.3, 1, 1) }, n(7, 0.03, { NoTint = true }))
		em(p, "Breath", { Texture = TEX.mist, Color = CS(PALE), LightEmission = 0.25, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Speed = R(22, 30), Drag = 3, Lifetime = R(0.9, 1.3), Size = seq(0, 4, 1, 12), Transparency = seq(0, 0.55, 1, 1), Rotation = R(0, 360), RotSpeed = R(-30, 30) }, n(6, 0.08, { NoTint = true }))
	end

	-- RoarWave (the ground under the head, authored r10): the howl's air
	-- shoving dust off the ground. 2 layers: +80 dust (earthy), +100 wisps.
	do
		local p = part(root, "RoarWave", Vector3.new(2, 0.2, 2), { AuthoredRadius = 10 })
		em(p, "Dust", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(18, 26), Drag = 3, Lifetime = R(0.8, 1.1), Size = seq(0, 3, 1, 7), Transparency = seq(0, 0.25, 0.5, 0.35, 1, 1), Rotation = R(0, 360) })), n(14, 0.08, { NoTint = true }))
		em(p, "Wisps", flip4(with(RADIAL, { Texture = TEX.airWisps, Color = CS(PALE), LightEmission = 0.6, Speed = R(26, 34), Drag = 4, Lifetime = R(0.35, 0.5), Size = seq(0, 2.4, 1, 1.2), Transparency = FADE, Rotation = R(0, 360) })), n(8, 0.1, { NoTint = true }))
	end

	-- Breath (the Mouth, the fang dance's 650 windup): foxfire licking in the
	-- jaws. 2 layers.
	do
		local p = part(root, "Breath", Vector3.new(1.5, 1.5, 1.5), { AuthoredSeconds = 0.65 })
		em(p, "Lick", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.5, Rate = 14, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(2, 4), Lifetime = R(0.28, 0.35), Size = seq(0, 1.4, 1, 0.5), Transparency = FADE, Rotation = R(-25, 25) }), { EmitDuration = 0.65 })
		em(p, "Glow", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.65), Size = seq(0, 0.6, 1, 2), Transparency = seq(0, 0.85, 0.9, 0.3, 1, 1), LockedToPart = true, ZOffset = 1 })
	end

	-- FangSnap (the Mouth, facing the cone; each of three bites): the jaws
	-- slam shut and the bite reaches down the cone. 6 layers: +0 the jaws
	-- closing on their slate twin (hero), +0 flash, +20 the reach crescent on
	-- its slate twin flying ~12 studs, +50 embers.
	do
		local p = part(root, "FangSnap", Vector3.new(0.4, 0.4, 0.4))
		em(p, "JawsDark", { Texture = TEX.jaws, Color = CS(SLATE), Lifetime = R(0.16), Size = seq(0, 6.2, 1, 2.8), Transparency = seq(0, 0.15, 0.6, 0.3, 1, 1), ZOffset = 0.5 }, NOTINT)
		em(p, "Jaws", { Texture = TEX.jaws, Color = FIRE, LightEmission = 0.8, Brightness = 1.4, Lifetime = R(0.15), Size = seq(0, 5.4, 1, 2.2), Transparency = seq(0, 0, 0.6, 0.1, 1, 1), ZOffset = 1.5 })
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.05), Size = seq(0, 1.6, 1, 2.4), Transparency = POP, ZOffset = 3 })
		local reach = { Texture = TEX.crescent, EmissionDirection = Enum.NormalId.Front, Speed = R(75), Drag = 6, Lifetime = R(0.22), Rotation = R(90) }
		em(p, "ReachDark", with(reach, { Color = CS(SLATE), Size = seq(0, 6.5, 1, 10.5), Transparency = seq(0, 0.25, 1, 1), ZOffset = 0.4 }), n(1, 0.02, { NoTint = true }))
		em(p, "Reach", with(reach, { Color = FIRE, LightEmission = 1, Brightness = 2.5, Size = seq(0, 5.5, 1, 9), Transparency = seq(0, 0, 0.7, 0.3, 1, 1), ZOffset = 1.2 }), n(1, 0.02))
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Speed = R(18, 30), Drag = 4, Lifetime = R(0.3, 0.5), Size = seq(0, 0.45, 1, 0), Transparency = FADE }, n(6, 0.05))
	end

	-- Ribbon: a flying head the runtime moves along a path (tail sweeps,
	-- the lance head, fissures, the dash streak, the veil's shreds, the death
	-- streams). Trails: slate base, glow strip, bright core line; a small
	-- flame head. The runtime sets the trail half-width and colours.
	do
		local p = part(root, "Ribbon", Vector3.new(0.3, 0.3, 0.3))
		local a0 = att(p, "A0", Vector3.new(0, 0.5, 0))
		local a1 = att(p, "A1", Vector3.new(0, -0.5, 0))
		local function trail(name, texture, color, life, startT, width, emission)
			local t = Instance.new("Trail")
			t.Name = name
			t.Attachment0, t.Attachment1 = a0, a1
			t.Texture = texture
			t.TextureMode = Enum.TextureMode.Stretch
			t.Color = color
			t.LightEmission = emission
			t.LightInfluence = 0
			t.Lifetime = life
			t.MinLength = 0.05
			t.FaceCamera = true
			t.Enabled = false
			t.Transparency = NS({ KP(0, startT), KP(1, 1) })
			t.WidthScale = NS({ KP(0, width), KP(1, 0) })
			t.Parent = p
		end
		trail("Dark", TEX.strip, CS(SLATE), 0.6, 0.4, 1.5, 0)
		trail("Wide", TEX.strip, CS({ CK(0, AZMID), CK(1, AZ) }), 0.5, 0.2, 1.3, 1)
		trail("Core", TEX.line, CS({ CK(0, WHITE), CK(1, AZMID) }), 0.36, 0, 0.7, 1)
		em(p, "Head", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Rate = 30, Lifetime = R(0.12), Size = seq(0, 1.6, 1, 0.8), Transparency = POP, LockedToPart = true, ZOffset = 2 }, { NoTint = true })
		em(p, "Tongues", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Rate = 20, Lifetime = R(0.25, 0.35), Size = seq(0, 2, 1, 0.6), Transparency = FADE, Rotation = R(-30, 30) }))
	end

	-- Bolt (foxfireVolley, a real projectile drawn by ProjectileView): a
	-- turning ball of foxfire the player reads and dodges. Hero: the striped
	-- orb (turning flipbook) on a slate halo with a white-hot core; flame
	-- tongues and a comet tail (slate, glow, core trails, A0/A1 set by the
	-- runtime); its Shadow part rides the ground under it.
	do
		local p = part(root, "Bolt", Vector3.new(0.4, 0.4, 0.4))
		local a0 = att(p, "A0", Vector3.new(0, 0.8, 0))
		local a1 = att(p, "A1", Vector3.new(0, -0.8, 0))
		for _, spec in { { "Dark", TEX.strip, CS(SLATE), 0.4, 0.5, 1.5, 0 }, { "Wide", TEX.strip, FIRE, 0.36, 0, 1.2, 1 }, { "Core", TEX.line, CS(WHITE), 0.22, 0, 0.45, 1 } } do
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
			t.WidthScale = NS({ KP(0, spec[6]), KP(1, 0) })
			t.Parent = p
		end
		em(p, "Halo", { Texture = TEX.dot, Color = CS(SLATE), Rate = 14, Lifetime = R(0.16), Size = seq(0, 4.4, 1, 4), Transparency = seq(0, 0.5, 1, 1), LockedToPart = true, ZOffset = 0.5 }, { NoTint = true })
		em(p, "Orb", flip4({ Texture = TEX.orb, FlipbookMode = LOOP, FlipbookFramerate = R(24), Color = FIRE, LightEmission = 0.85, Brightness = 1.4, Rate = 10, Lifetime = R(0.2), Size = seq(0, 3.4, 1, 3), Transparency = seq(0, 0.1, 1, 1), Rotation = R(0, 360), RotSpeed = R(-200, 200), LockedToPart = true, ZOffset = 1.5 }))
		em(p, "Core", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Rate = 20, Lifetime = R(0.12), Size = seq(0, 1.5, 1, 1.1), Transparency = POP, LockedToPart = true, ZOffset = 2.5 }, { NoTint = true })
		em(p, "Tongues", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Rate = 24, SpreadAngle = Vector2.new(25, 25), Speed = R(1, 2.5), Lifetime = R(0.26, 0.36), Size = seq(0, 2.4, 1, 0.6), Transparency = FADE, Rotation = R(-40, 40), ZOffset = 1 }))
		local shadow = part(p, "Shadow", Vector3.new(0.4, 0.2, 0.4))
		em(shadow, "Shadow", with(FLAT, { Texture = TEX.mist, Color = CS(INK), Rate = 10, Lifetime = R(0.2), Size = NS(3.4), Transparency = seq(0, 0.45, 1, 0.8), Rotation = R(0, 360), LockedToPart = true, ZOffset = 0.1 }), { NoTint = true })
	end

	-- Thread (the lance, the snare's whip, the tether): Beams between `A`
	-- and `End` (the runtime moves End onto a second part). Slate base, glow
	-- strip, bright core line; `Whip` is the snare's wavy body.
	do
		local p = part(root, "Thread", Vector3.new(0.3, 0.3, 0.3))
		local a = att(p, "A")
		local e = att(p, "End")
		local function beam(name, texture, color, width, tr, emission, speed)
			local b = Instance.new("Beam")
			b.Name = name
			b.Attachment0, b.Attachment1 = a, e
			b.Texture = texture
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureSpeed = speed or 0
			b.Color = color
			b.LightEmission = emission
			b.LightInfluence = 0
			b.Width0, b.Width1 = width, width
			b.FaceCamera = true
			b.Segments = 1
			b.Transparency = NS(tr)
			b.Enabled = false
			b.Parent = p
		end
		-- plain glow (the strip's fade would dim the spear's business end)
		beam("Dark", "", CS(SLATE), 1.3, 0.45, 0)
		beam("Wide", "", CS({ CK(0, AZMID), CK(1, AZ) }), 0.9, 0.3, 1)
		beam("Core", TEX.line, CS(WHITE), 0.45, 0, 1)
	end
	do
		local p = part(root, "Whip", Vector3.new(0.3, 0.3, 0.3))
		local a = att(p, "A")
		local e = att(p, "End")
		for _, spec in { { "Dark", CS(SLATE), 1.6, 0.4, 0 }, { "Wide", CS({ CK(0, WHITE), CK(1, PALE) }), 1.3, 0, 1 } } do
			local b = Instance.new("Beam")
			b.Name = spec[1]
			b.Attachment0, b.Attachment1 = a, e
			b.Texture = TEX.whip
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 6
			b.TextureSpeed = 2.5
			b.Color = spec[2]
			b.LightEmission = spec[5]
			b.LightInfluence = 0
			b.Width0, b.Width1 = spec[3], spec[3]
			b.FaceCamera = true
			b.Segments = 1
			b.Transparency = NS(spec[4])
			b.Enabled = false
			b.Parent = p
		end
	end

	-- LanceHit (the lane's far end, on the ground): the tail spears the
	-- earth. 7 layers: +0 contact star, +20 earth splash on its slate twin
	-- (hero), +30 chips, +50 glowing scar (to 1400), +60 dust.
	do
		local p = part(root, "LanceHit", Vector3.new(1, 0.2, 1))
		em(att(p, "Air", Vector3.new(0, 1.2, 0)), "Star", flip4({ Texture = TEX.contactStar, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.3), Size = NS(7), ZOffset = 3 }))
		local splash = { Texture = TEX.splash, EmissionDirection = Enum.NormalId.Top, Speed = R(0.01), Lifetime = R(0.32), ZOffset = 1 }
		em(p, "SplashDark", variant(GRID2, with(splash, { Color = CS(SLATE), Size = seq(0, 2.5, 0.25, 10, 1, 11), Transparency = seq(0, 0.1, 0.6, 0.25, 1, 1), ZOffset = 0.6 })), n(1, 0.02, { NoTint = true }))
		em(p, "Splash", variant(GRID2, with(splash, { Color = FIRE, LightEmission = 1, Brightness = 1.6, Size = seq(0, 2, 0.25, 8.4, 1, 9), Transparency = seq(0, 0, 0.6, 0.2, 1, 1) })), n(1, 0.02))
		em(p, "Chips", variant(GRID8, { Texture = TEX.chips, Color = CS(SLATE), LightInfluence = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(14, 22), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.6, 0.9), Size = NS(0.9), Rotation = R(0, 360), RotSpeed = R(-300, 300), Transparency = seq(0, 0, 0.8, 0, 1, 1) }), n(8, 0.03, { NoTint = true }))
		em(p, "Scar", with(FLAT, { Texture = TEX.scar, Color = CS(AZ), LightEmission = 0.7, Brightness = 0.7, Lifetime = R(1.4), Size = NS(5), Rotation = R(0, 360), Transparency = seq(0, 0.1, 0.4, 0.3, 1, 1), ZOffset = 0.2 }), n(1, 0.05))
		em(p, "Dust", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(8, 14), Drag = 3, Lifetime = R(0.8, 1), Size = seq(0, 2.5, 1, 5), Transparency = seq(0, 0.3, 1, 1), Rotation = R(0, 360) })), n(6, 0.06, { NoTint = true }))
	end

	-- Dust (paws digging in, take-offs, skids; authored r1, scaled to the
	-- radius): dirt shoved off the ground. 2 layers: +0 puffs, +30 a kick.
	do
		local p = part(root, "Dust", Vector3.new(1, 0.2, 1), { AuthoredRadius = 1 })
		em(p, "Puff", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(3, 5), Drag = 3, Lifetime = R(0.7, 1), Size = seq(0, 0.8, 1, 1.6), Transparency = seq(0, 0.3, 1, 1), Rotation = R(0, 360) })), n(7, 0, { NoTint = true }))
		em(p, "Kick", { Texture = TEX.kick, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, EmissionDirection = Enum.NormalId.Top, Speed = R(0.01), Lifetime = R(0.45), Size = seq(0, 0.6, 1, 1.5), Transparency = seq(0, 0.2, 1, 1) }, n(2, 0.03, { NoTint = true }))
	end

	-- Burst (a foxfire bolt landing, the eruption's heart; authored r3):
	-- 7 layers: +0 flash, +0 the burst opening into a broken ring on its slate
	-- twin (hero), +30 shock ring, +40 tongues, +60 scar, +120 smoke.
	do
		local p = part(root, "Burst", Vector3.new(1, 0.2, 1), { AuthoredRadius = 3 })
		local air = att(p, "Air", Vector3.new(0, 1.8, 0))
		em(air, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.07), Size = seq(0, 3, 1, 4.5), Transparency = POP, ZOffset = 3 })
		em(air, "BurstDark", flip4({ Texture = TEX.burstRing, Color = CS(SLATE), Lifetime = R(0.5), Size = seq(0, 6, 1, 8.5), Transparency = seq(0, 0.2, 1, 0.6), Rotation = R(0, 360), ZOffset = 0.8 }), NOTINT)
		em(air, "Burst", flip4({ Texture = TEX.burstRing, Color = FIRE, LightEmission = 0.9, Brightness = 1.6, Lifetime = R(0.45), Size = seq(0, 5, 1, 7.5), Transparency = seq(0, 0, 1, 0.4), Rotation = R(0, 360), ZOffset = 1.5 }))
		wave(p, "Shock", MESH.shock, { from = Vector3.new(1, 0.25, 1), to = Vector3.new(9, 0.7, 9), fromOffset = Vector3.new(0, 0.2, 0), toOffset = Vector3.new(0, 0.2, 0), fromT = 0.2, duration = 0.3, delay = 0.03 })
		em(p, "Tongues", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.5, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(8, 14), Drag = 3, Lifetime = R(0.4, 0.55), Size = seq(0, 2.6, 1, 1.4), Transparency = FADE, Rotation = R(-20, 20) }), n(5, 0.04))
		em(p, "Scar", with(FLAT, { Texture = TEX.scar, Color = CS(AZ), LightEmission = 0.7, Brightness = 0.7, Lifetime = R(1.6), Size = NS(5.5), Rotation = R(0, 360), Transparency = seq(0, 0.15, 0.4, 0.35, 1, 1), ZOffset = 0.2 }), n(1, 0.06))
		em(p, "Smoke", flip4({ Texture = TEX.smoke, Color = CS(SLATE), LightEmission = 0, LightInfluence = 0.6, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(2, 4), Lifetime = R(1, 1.3), Size = seq(0, 3, 1, 6), Transparency = seq(0, 0.4, 1, 1), Rotation = R(0, 360) }), n(3, 0.12, { NoTint = true }))
	end

	-- PlungeImpact (a tail tip driving into the ground; authored r3.5):
	-- 6 layers: +0 contact star, +10 the splash crown on its slate twin
	-- (hero), +20 chips, +40 scar (held to 2000, the tail is buried), +50 dust.
	do
		local p = part(root, "PlungeImpact", Vector3.new(1, 0.2, 1), { AuthoredRadius = 3.5 })
		em(att(p, "Air", Vector3.new(0, 1.2, 0)), "Star", flip4({ Texture = TEX.contactStar, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.28), Size = NS(6), ZOffset = 3 }))
		wave(p, "CrownDark", MESH.splashCrown, { dark = true, from = Vector3.new(1.4, 0.6, 1.4), to = Vector3.new(8, 3, 8), fromT = 0.2, duration = 0.28, delay = 0.01 })
		wave(p, "Crown", MESH.splashCrown, { from = Vector3.new(1.2, 0.5, 1.2), to = Vector3.new(7, 2.6, 7), fromOffset = Vector3.new(0, 0.1, 0), toOffset = Vector3.new(0, 0.1, 0), fromT = 0.05, duration = 0.26, delay = 0.01 })
		em(p, "Chips", variant(GRID8, { Texture = TEX.chips, Color = CS(SLATE), LightInfluence = 1, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(14, 24), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.6, 0.9), Size = NS(0.9), Rotation = R(0, 360), RotSpeed = R(-300, 300) }), n(8, 0.02, { NoTint = true }))
		em(p, "Scar", with(FLAT, { Texture = TEX.scar, Color = CS(AZ), LightEmission = 0.7, Brightness = 0.7, Lifetime = R(1.3), Size = NS(5), Rotation = R(0, 360), Transparency = seq(0, 0.2, 0.6, 0.35, 1, 1), ZOffset = 0.2 }), n(1, 0.04))
		em(p, "Dust", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(8, 14), Drag = 3, Lifetime = R(0.8, 1.1), Size = seq(0, 2.5, 1, 5.5), Transparency = seq(0, 0.3, 1, 1), Rotation = R(0, 360) })), n(8, 0.05, { NoTint = true }))
	end

	-- Eruption (a circle of rootfire, authored r3.5): fire bursting out of
	-- the ground. 7 layers: +0 flash, +0 flame spikes rising on their slate
	-- twin (hero), +30 flame column, +50 scar, +80 embers, +150 smoke plume.
	do
		local p = part(root, "Eruption", Vector3.new(1, 0.2, 1), { AuthoredRadius = 3.5 })
		em(att(p, "Air", Vector3.new(0, 1.5, 0)), "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.08), Size = seq(0, 3, 1, 5), Transparency = POP, ZOffset = 3 })
		wave(p, "SpikesDark", MESH.spikes, { dark = true, from = Vector3.new(2.4, 1, 2.4), to = Vector3.new(8, 12.5, 8), fromOffset = Vector3.new(0, 0.5, 0), toOffset = Vector3.new(0, 6, 0), fromT = 0.3, duration = 0.36 })
		wave(p, "Spikes", MESH.spikes, { from = Vector3.new(2, 1, 2), to = Vector3.new(7, 12, 7), fromOffset = Vector3.new(0, 0.5, 0), toOffset = Vector3.new(0, 6.2, 0), fromT = 0.05, duration = 0.35 })
		em(p, "Column", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.2, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Speed = R(18, 30), Drag = 2.5, Lifetime = R(0.5, 0.7), Size = seq(0, 4, 0.5, 5, 1, 1.5), Transparency = LATE, Rotation = R(-20, 20), ZOffset = 1.5 }), n(7, 0.03))
		em(p, "Scar", with(FLAT, { Texture = TEX.scar, Color = CS(AZ), LightEmission = 0.7, Brightness = 0.7, Lifetime = R(1), Size = NS(6.5), Rotation = R(0, 360), Transparency = seq(0, 0.2, 0.4, 0.4, 1, 1), ZOffset = 0.2 }), n(1, 0.05))
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(20, 35), Drag = 1.5, Acceleration = Vector3.new(0, -20, 0), Lifetime = R(0.7, 1.1), Size = seq(0, 0.45, 1, 0), Transparency = FADE }, n(10, 0.08))
		em(p, "Plume", { Texture = TEX.plume, Color = CS(SLATE), LightEmission = 0, LightInfluence = 0.6, EmissionDirection = Enum.NormalId.Top, Speed = R(5, 7), Lifetime = R(1.1, 1.3), Size = seq(0, 7, 1, 11), Transparency = seq(0, 0.45, 1, 1) }, n(2, 0.15, { NoTint = true }))
	end

	-- StuckGlow (each buried tail through the punish window): foxfire
	-- smouldering where the tail went in. 2 layers.
	do
		local p = part(root, "StuckGlow", Vector3.new(1, 1, 1))
		em(p, "Smoulder", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Rate = 9, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(1.5, 3), Lifetime = R(0.4, 0.6), Size = seq(0, 1.8, 1, 0.6), Transparency = FADE, Rotation = R(-20, 20) }))
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Rate = 6, SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, Speed = R(3, 6), Lifetime = R(0.5, 0.8), Size = seq(0, 0.35, 1, 0), Transparency = FADE })
	end

	-- FireStrip (the moon leap's burning trail; Box sized per segment by the
	-- runtime, BaseRate per stud of length): the burning tails scorched the
	-- ground. 3 layers: flame tongues, a slate scorch, embers.
	do
		local p = part(root, "FireStrip", Vector3.new(4, 1, 7))
		em(p, "Flames", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.5, Rate = 1.6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(2, 5), Lifetime = R(0.6, 0.9), Size = seq(0, 2.6, 1, 0.8), Transparency = FADE, Rotation = R(-15, 15) }))
		em(p, "Scorch", with(FLAT, { Texture = TEX.scar, Color = CS(SLATE), Rate = 0.35, Shape = Enum.ParticleEmitterShape.Box, Lifetime = R(2.2, 2.8), Size = NS(4.5), Rotation = R(0, 360), Transparency = seq(0, 1, 0.15, 0.35, 1, 1), ZOffset = 0.1 }), { NoTint = true })
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Rate = 1.2, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Speed = R(4, 8), Lifetime = R(0.6, 1), Size = seq(0, 0.35, 1, 0), Transparency = FADE })
	end

	-- Landing (the moon leap's touch-down between the forepaws; authored r6):
	-- weight hitting the floor. 5 layers: +0 flash, +0 shock ring, +20 dust
	-- ring (hero), +40 dirt kicked up, +60 the tails' tongues slapping down.
	do
		local p = part(root, "Landing", Vector3.new(1, 0.2, 1), { AuthoredRadius = 6 })
		em(att(p, "Air", Vector3.new(0, 1.5, 0)), "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.07), Size = seq(0, 3, 1, 4.5), Transparency = POP, ZOffset = 3 })
		wave(p, "Shock", MESH.shock, { from = Vector3.new(1.5, 0.3, 1.5), to = Vector3.new(14, 0.9, 14), fromOffset = Vector3.new(0, 0.2, 0), toOffset = Vector3.new(0, 0.2, 0), fromT = 0.25, duration = 0.32 })
		em(p, "DustRing", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(16, 24), Drag = 3, Lifetime = R(1, 1.3), Size = seq(0, 4, 1, 8.5), Transparency = seq(0, 0.2, 0.5, 0.3, 1, 1), Rotation = R(0, 360) })), n(16, 0.02, { NoTint = true }))
		em(p, "Kick", { Texture = TEX.kick, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(0.01), Lifetime = R(0.5), Size = seq(0, 2, 1, 5), Transparency = seq(0, 0.2, 1, 1) }, n(4, 0.04, { NoTint = true }))
		em(p, "Tongues", flip4(with(RADIAL, { Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.5, Speed = R(10, 16), Drag = 3, Lifetime = R(0.4, 0.55), Size = seq(0, 2.6, 1, 1.2), Transparency = FADE, Rotation = R(-20, 20) })), n(6, 0.06))
	end

	-- ScreamTell (the Throat, 1400): breath pulled in, the throat glowing up.
	-- 2 layers.
	do
		local p = part(root, "ScreamTell", Vector3.new(10, 10, 10), { AuthoredSeconds = 1.4 })
		em(p, "Inhale", flip4({ Texture = TEX.airWisps, Color = CS(PALE), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 20, Speed = R(16, 22), Lifetime = R(0.35, 0.45), Size = seq(0, 2, 1, 0.6), Transparency = seq(0, 1, 0.3, 0.3, 1, 1), Rotation = R(0, 360), LockedToPart = true }), { EmitDuration = 1.4, NoTint = true })
		em(p, "Throat", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, PALE) }), LightEmission = 1, Brightness = 2, Lifetime = R(1.4), Size = seq(0, 0.5, 1, 3), Transparency = seq(0, 0.9, 0.9, 0.15, 1, 1), LockedToPart = true, ZOffset = 1 }, NOTINT)
	end

	-- TailFlare (each lit tail through the scream's windup): its flame
	-- swells. 1 layer.
	do
		local p = part(root, "TailFlare", nil, { AuthoredSeconds = 1.4 })
		em(p, "Swell", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.5, Rate = 8, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(3, 6), Lifetime = R(0.4, 0.55), Size = seq(0, 2.8, 1, 1), Transparency = FADE, Rotation = R(-15, 15) }), { EmitDuration = 1.4 })
	end

	-- ScreamWave (the ground under the fox, authored r30): the scream radiates
	-- out at head height. All pale (NoTint). 6 layers: +0 the sound ring on
	-- its slate twin racing to r30 (hero), +20 speed lines, +40 the spiky
	-- shock on the ground beneath it, +100 dust shoved out, +120 second ring.
	do
		local p = part(root, "ScreamWave", Vector3.new(2, 0.2, 2), { AuthoredRadius = 30 })
		local pale = Color3.fromRGB(226, 240, 255)
		wave(p, "RingDark", MESH.screamRing, { dark = true, from = Vector3.new(5, 1.4, 5), to = Vector3.new(64, 5, 64), fromOffset = Vector3.new(0, 6, 0), toOffset = Vector3.new(0, 4, 0), fromT = 0.45, duration = 0.5 })
		wave(p, "Ring", MESH.screamRing, { noTint = true, color = pale, from = Vector3.new(4, 1.2, 4), to = Vector3.new(60, 4, 60), fromOffset = Vector3.new(0, 6, 0), toOffset = Vector3.new(0, 4, 0), fromT = 0.1, duration = 0.48 })
		wave(p, "Ring2", MESH.screamRing, { noTint = true, color = pale, from = Vector3.new(4, 1, 4), to = Vector3.new(52, 3, 52), fromOffset = Vector3.new(0, 4, 0), toOffset = Vector3.new(0, 2.5, 0), fromT = 0.45, duration = 0.5, delay = 0.12 })
		em(p, "Lines", { Texture = TEX.line, Color = CS(PALE), LightEmission = 1, Brightness = 2, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(80, 100), Drag = 3, Lifetime = R(0.3, 0.4), Size = seq(0, 7, 1, 1), Transparency = seq(0, 0.1, 1, 1) }, n(16, 0.02, { NoTint = true }))
		em(p, "Shock", with(FLAT, { Texture = TEX.spikyRing, Color = CS(PALE), LightEmission = 1, Brightness = 1.5, Lifetime = R(0.45), Size = seq(0, 4, 1, 60), Transparency = seq(0, 0.1, 0.6, 0.4, 1, 1), ZOffset = 0.3 }), n(1, 0.04, { NoTint = true }))
		em(p, "Dust", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(40, 55), Drag = 2.5, Lifetime = R(0.8, 1.1), Size = seq(0, 3.5, 1, 8), Transparency = seq(0, 0.3, 1, 1), Rotation = R(0, 360) })), n(18, 0.1, { NoTint = true }))
	end

	-- StunSting (the stunned local character): stars wheeling over the head
	-- and a small spiky pop. 2 layers.
	do
		local p = part(root, "StunSting", Vector3.new(3, 0.4, 3))
		em(p, "Pop", { Texture = TEX.spikyRing, Color = CS(PALE), LightEmission = 1, Brightness = 2, Lifetime = R(0.25), Size = seq(0, 1, 1, 6), Transparency = seq(0, 0, 1, 1), ZOffset = 2 }, NOTINT)
		local a = att(p, "Head", Vector3.new(0, 3.2, 0))
		em(a, "Stars", { Texture = TEX.star, Color = CS(PALE), LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, SpreadAngle = Vector2.new(0, 0), EmissionDirection = Enum.NormalId.Top, Speed = R(0.01), Lifetime = R(1.1), Size = seq(0, 0, 0.15, 1.3, 0.85, 1.1, 1, 0), RotSpeed = R(-120, 120), LockedToPart = true, ZOffset = 2 }, n(5, 0.04, { NoTint = true }))
	end

	-- TailRise (each tail through Nine-Tail Fall's windup, to its plunge):
	-- the raised tail draws foxfire in and its flame swells. 2 layers.
	do
		local p = part(root, "TailRise", Vector3.new(6, 6, 6), { AuthoredSeconds = 1.6 })
		em(p, "Draw", flip4({ Texture = TEX.airWisps, Color = FIRE, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 12, Speed = R(10, 14), Lifetime = R(0.3, 0.4), Size = seq(0, 1.5, 1, 0.5), Transparency = seq(0, 1, 0.3, 0.25, 1, 0.9), Rotation = R(0, 360), LockedToPart = true }), { EmitDuration = 1.6 })
		em(p, "Swell", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 2, Rate = 10, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Speed = R(3, 6), Lifetime = R(0.4, 0.5), Size = seq(0, 3.2, 1, 1), Transparency = FADE, Rotation = R(-15, 15) }), { EmitDuration = 1.6 })
	end

	-- FallBurst (Nine-Tail Fall's final circle under the fox, authored r20):
	-- every tail slams down at once. 11 layers: +0 flash, +0 burst and shock
	-- ring on their slate twins (hero), +30 flame spikes, +40 chips, +50 flame
	-- column, +60 scar, +80 dust ring, +200 smoke.
	do
		local p = part(root, "FallBurst", Vector3.new(4, 0.2, 4), { AuthoredRadius = 20 })
		-- camera-facing sprites ride above the floor, or the ground cuts them in half
		local air = att(p, "Air", Vector3.new(0, 7, 0))
		em(air, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.1), Size = seq(0, 18, 1, 26), Transparency = POP, ZOffset = 3 })
		em(air, "BurstDark", flip4({ Texture = TEX.burstRing, Color = CS(SLATE), Lifetime = R(0.65), Size = seq(0, 34, 1, 44), Transparency = seq(0, 0.2, 1, 0.6), Rotation = R(0, 360), ZOffset = 0.8 }), NOTINT)
		em(air, "Burst", flip4({ Texture = TEX.burstRing, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.6), Size = seq(0, 30, 1, 40), Transparency = seq(0, 0, 1, 0.4), Rotation = R(0, 360), ZOffset = 1.5 }))
		wave(p, "ShockDark", MESH.shock, { dark = true, from = Vector3.new(2.5, 0.6, 2.5), to = Vector3.new(44, 2.4, 44), fromOffset = Vector3.new(0, 0.15, 0), toOffset = Vector3.new(0, 0.15, 0), fromT = 0.4, duration = 0.45 })
		wave(p, "Shock", MESH.shock, { from = Vector3.new(2, 0.5, 2), to = Vector3.new(42, 2, 42), fromOffset = Vector3.new(0, 0.3, 0), toOffset = Vector3.new(0, 0.3, 0), fromT = 0.1, duration = 0.45 })
		wave(p, "Spikes", MESH.bigSpikes, { from = Vector3.new(4, 2, 4), to = Vector3.new(18, 16, 18), fromOffset = Vector3.new(0, 1, 0), toOffset = Vector3.new(0, 8, 0), fromT = 0.05, duration = 0.4, delay = 0.03 })
		em(p, "Chips", variant(GRID8, { Texture = TEX.chips, Color = CS(SLATE), LightInfluence = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45), Speed = R(22, 36), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.8, 1.2), Size = NS(1.4), Rotation = R(0, 360), RotSpeed = R(-300, 300) }), n(16, 0.04, { NoTint = true }))
		em(p, "Column", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(24, 40), Drag = 2.5, Lifetime = R(0.6, 0.8), Size = seq(0, 7, 0.5, 9, 1, 2), Transparency = FADE, Rotation = R(-20, 20), ZOffset = 1.5 }), n(16, 0.05))
		em(p, "Scar", with(FLAT, { Texture = TEX.scar, Color = CS(AZ), LightEmission = 0.7, Brightness = 0.7, Lifetime = R(2.5), Size = NS(26), Rotation = R(0, 360), Transparency = seq(0, 0.1, 0.4, 0.3, 1, 1), ZOffset = 0.2 }), n(1, 0.06))
		em(p, "DustRing", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(34, 48), Drag = 2.5, Lifetime = R(1.2, 1.6), Size = seq(0, 6, 1, 14), Transparency = seq(0, 0.25, 0.5, 0.35, 1, 1), Rotation = R(0, 360) })), n(22, 0.08, { NoTint = true }))
		em(p, "Smoke", flip4({ Texture = TEX.smoke, Color = CS(SLATE), LightEmission = 0, LightInfluence = 0.6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(3, 6), Lifetime = R(1.6, 2.1), Size = seq(0, 8, 1, 16), Transparency = seq(0, 0.45, 1, 1), Rotation = R(0, 360) }), n(5, 0.2, { NoTint = true }))
	end

	-- Gather (the Core, the phase break's 1600; authored r5): the fox draws
	-- foxfire into its chest to tear its veil. 4 layers: wisps streaming in
	-- (0-1600), the core swelling on its slate twin, the orb forming in the
	-- last 500.
	do
		local p = part(root, "Gather", Vector3.new(5, 5, 5), { AuthoredSeconds = 1.6, AuthoredRadius = 5 })
		em(p, "Draw", flip4({ Texture = TEX.airWisps, Color = FIRE, LightEmission = 1, Brightness = 1.5, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 26, Speed = R(10, 14), Lifetime = R(0.4, 0.48), Size = seq(0, 2.2, 1, 0.6), Transparency = seq(0, 1, 0.3, 0.2, 1, 0.8), Rotation = R(0, 360), LockedToPart = true }), { EmitDuration = 1.6 })
		em(p, "CoreDark", { Texture = TEX.dot, Color = CS(SLATE), Lifetime = R(1.6), Size = seq(0, 1, 1, 6), Transparency = seq(0, 0.85, 0.85, 0.4, 1, 1), LockedToPart = true, ZOffset = 0.5 }, NOTINT)
		em(p, "Core", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(1.6), Size = seq(0, 0.6, 0.85, 3.6, 1, 4.2), Transparency = seq(0, 0.8, 0.85, 0.05, 1, 0.5), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Orb", flip4({ Texture = TEX.orb, FlipbookMode = LOOP, FlipbookFramerate = R(20), Color = FIRE, LightEmission = 1, Brightness = 2, Lifetime = R(0.5), Size = seq(0, 1.5, 1, 4.5), Transparency = seq(0, 0.8, 0.7, 0.1, 1, 0.3), RotSpeed = R(-150, 150), LockedToPart = true, ZOffset = 2 }), n(1, 1.1))
	end

	-- PhaseBurst (the Core at the phase break's release; scaled by the shape
	-- radius / 10): the veil bursts off the fox. 5 layers: +0 flash, +0 the
	-- veil shell on its slate twin (hero), +20 streaks out.
	do
		local p = part(root, "PhaseBurst")
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 6, Lifetime = R(0.09), Size = seq(0, 6, 1, 10), Transparency = POP, ZOffset = 3 })
		wave(p, "VeilDark", MESH.veil, { dark = true, from = Vector3.new(3.4, 2.6, 3.4), to = Vector3.new(28, 21, 28), fromT = 0.45, duration = 0.42 })
		wave(p, "Veil", MESH.veil, { from = Vector3.new(3, 2.2, 3), to = Vector3.new(26, 19, 26), fromT = 0.05, duration = 0.4 })
		em(p, "Streaks", { Texture = TEX.line, Color = FIRE, LightEmission = 1, Brightness = 2, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(180, 180), Speed = R(70, 95), Drag = 4, Lifetime = R(0.3, 0.4), Size = seq(0, 7, 1, 1), Transparency = seq(0, 0.1, 1, 1) }, n(18, 0.02))
		em(p, "Twinkles", flip4({ Texture = TEX.twinkle, Color = FIRE, LightEmission = 1, Brightness = 2, SpreadAngle = Vector2.new(180, 180), Speed = R(14, 24), Drag = 3, Lifetime = R(0.8, 1.2), Size = NS(1.2) }), n(10, 0.08))
	end

	-- PhaseRing (the ground at the phase break; authored r10): the veil hits
	-- the ground. 2 layers: +60 shock ring, +90 dust.
	do
		local p = part(root, "PhaseRing", Vector3.new(2, 0.2, 2), { AuthoredRadius = 10 })
		wave(p, "Shock", MESH.shock, { from = Vector3.new(2, 0.4, 2), to = Vector3.new(21, 1.2, 21), fromOffset = Vector3.new(0, 0.2, 0), toOffset = Vector3.new(0, 0.2, 0), fromT = 0.2, duration = 0.4, delay = 0.06 })
		em(p, "Dust", flip4(with(RADIAL, { Texture = TEX.dust, Color = CS(DUST), LightEmission = 0, LightInfluence = 1, Speed = R(22, 30), Drag = 3, Lifetime = R(0.9, 1.2), Size = seq(0, 3.5, 1, 8), Transparency = seq(0, 0.3, 1, 1), Rotation = R(0, 360) })), n(16, 0.09, { NoTint = true }))
	end

	-- SpiritGlint (the Core when staggered): the fox's qi knocked loose.
	-- 2 layers: +0 glint, +30 embers.
	do
		local p = part(root, "SpiritGlint")
		em(p, "Glint", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 4, Lifetime = R(0.3), Size = seq(0, 1, 0.3, 7, 1, 0), Rotation = R(-10, 10), ZOffset = 3 })
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, SpreadAngle = Vector2.new(180, 180), Speed = R(8, 16), Drag = 3, Lifetime = R(0.5, 0.8), Size = seq(0, 0.45, 1, 0), Transparency = FADE }, n(8, 0.03))
	end

	-- SoulRelease (where the death streams meet): the fox's spirit leaving.
	-- 4 layers: +0 spirit swirl bloom (hero), +0 glint, +40 ring, +100
	-- twinkles drifting down (to ~3000).
	do
		local p = part(root, "SoulRelease")
		em(p, "Bloom", { Texture = TEX.spirit, Color = FIRE, LightEmission = 0.8, Brightness = 1.4, Lifetime = R(0.9), Size = seq(0, 4, 0.3, 14, 1, 17), Transparency = seq(0, 0, 0.5, 0.2, 1, 1), Rotation = R(0, 360), RotSpeed = R(90, 140), ZOffset = 2 })
		em(p, "Glint", { Texture = TEX.glint, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.3), Size = seq(0, 2, 0.25, 8, 1, 0), ZOffset = 3 })
		wave(p, "Ring", MESH.soundRing, { from = Vector3.new(2, 0.4, 2), to = Vector3.new(24, 1.6, 24), fromT = 0.2, duration = 0.5, delay = 0.04 })
		em(p, "Twinkles", flip4({ Texture = TEX.twinkle, Color = FIRE, LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Sphere, SpreadAngle = Vector2.new(180, 180), Speed = R(4, 9), Drag = 1.5, Acceleration = Vector3.new(0, -2, 0), Lifetime = R(2, 3), Size = NS(1.1) }), n(14, 0.1))
	end

	-- Dissolve (the body over the death; Box over the body): it burns away.
	-- 3 layers: flames rising off it, slate ash, motes.
	do
		local p = part(root, "Dissolve", Vector3.new(10, 8, 18))
		em(p, "Flames", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 1.5, Rate = 18, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(3, 6), Lifetime = R(0.6, 0.9), Size = seq(0, 2.8, 1, 0.8), Transparency = FADE, Rotation = R(-20, 20) }), { EmitDuration = 2.6 })
		em(p, "Ash", { Texture = TEX.chips, FlipbookLayout = GRID8, FlipbookMode = LOOP, FlipbookFramerate = R(0.01), FlipbookStartRandom = true, Color = CS(SLATE), LightInfluence = 1, Rate = 12, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Speed = R(2, 5), Acceleration = Vector3.new(0, 1.5, 0), Lifetime = R(1.2, 1.8), Size = NS(0.5), Rotation = R(0, 360), RotSpeed = R(-120, 120), Transparency = seq(0, 0, 0.7, 0.2, 1, 1) }, { EmitDuration = 2.6, NoTint = true })
		em(p, "Motes", flip4({ Texture = TEX.twinkle, Color = FIRE, LightEmission = 1, Rate = 6, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(3, 6), Lifetime = R(1, 1.6), Size = NS(0.9) }), { EmitDuration = 2.6 })
	end

	-- Hit (a foxfire blow on the player, near side of the torso): 3 layers:
	-- +0 contact star, +0 flame burst (hero), +30 embers.
	do
		local p = part(root, "Hit")
		em(p, "Star", flip4({ Texture = TEX.contactStar, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.22), Size = NS(4), ZOffset = 3 }))
		em(p, "Burst", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Front, Speed = R(3), Drag = 4, Lifetime = R(0.3), Size = seq(0, 3.6, 1, 4.4), Transparency = FADE, Rotation = R(0, 360), ZOffset = 2 }))
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(40, 40), Speed = R(12, 20), Drag = 3, Lifetime = R(0.3, 0.5), Size = seq(0, 0.4, 1, 0), Transparency = FADE }, n(6, 0.03))
	end

	-- HitHeavy (a sweep, pounce, eruption or bolt on the player): 5 layers:
	-- +0 contact star, +0 the rend crescent on its slate twin (hero), +20
	-- flame burst, +30 embers.
	do
		local p = part(root, "HitHeavy")
		em(p, "Star", flip4({ Texture = TEX.contactStar, Color = FIRE, LightEmission = 1, Brightness = 3, Lifetime = R(0.26), Size = NS(6), ZOffset = 3 }))
		em(p, "RendDark", { Texture = TEX.crescent, Color = CS(SLATE), Lifetime = R(0.2), Size = seq(0, 6.5, 1, 8), Rotation = R(-40, 40), Transparency = seq(0, 0.2, 1, 1), ZOffset = 0.5 }, NOTINT)
		em(p, "Rend", { Texture = TEX.crescent, Color = FIRE, LightEmission = 1, Brightness = 2.5, Lifetime = R(0.18), Size = seq(0, 5.5, 1, 7), Rotation = R(-40, 40), Transparency = seq(0, 0, 0.6, 0.15, 1, 1), ZOffset = 1.5 })
		em(p, "Burst", flip4({ Texture = TEX.flameBurst, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Back, Speed = R(4), Drag = 4, Lifetime = R(0.35), Size = seq(0, 4.4, 1, 5.4), Transparency = FADE, Rotation = R(0, 360), ZOffset = 2 }), n(1, 0.02))
		em(p, "Embers", { Texture = TEX.dot, Color = FIRE, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(45, 45), Speed = R(14, 24), Drag = 3, Lifetime = R(0.35, 0.55), Size = seq(0, 0.45, 1, 0), Transparency = FADE }, n(10, 0.03))
	end

	root.Parent = effects
	return root
end

return true
