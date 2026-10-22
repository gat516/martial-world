--!nocheck
-- Builder for ReplicatedStorage.Effects.ThunderApe: the Thunder Ape boss's
-- attack, hit, phase, roar, aura and death effects (boss, Foundation 1).
-- Load through the receiver, then build into the Effects folder (or a clone):
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/ThunderApe.luau")
--   require(m)  -- installs _G.buildThunderApeFX(effectsFolder)
-- Runtime: src/client/EnemyFX/ThunderApe.luau (cue -> template, placement,
-- sounds). Sounds: SoundService.SFX.Enemies.ThunderApe.<Name>.
--
-- Rebuilt 2026-10-22 with the intent-first method (.claude/agents/vfx.md):
-- every layer is caused by the body doing the move, one hero per beat, starts
-- staggered behind their cause, assets found by searching the library for
-- what each move causes (lightning, air, dust, debris, light, cracks) rather
-- than its name. The old set (58 templates) drew a ground sigil under the
-- leaps (it redrew the telegraph), a lit crack under the roar (a roar is air,
-- not an impact), an always-on ground formation, and layered the shared Impact
-- kit over its own impacts; all of that was cut.
--
-- Palette: storm blue-white (white-hot core, #B8F0FF rim, #5BD8FF falloff)
-- over an indigo #1B2547 or slate copy so it reads in daylight; violet only in
-- phase 3 (runtime tint); dust and rock are lit earth tones, never glowing.
-- The telegraph keeps the danger colour; nothing here redraws a danger area.
--
-- INTENTS (what happens / what the player feels / gameplay job)
-- Club swing, backhand, rush swipe, skyfall sweep: the ape hauls a charged fist
--   back and sweeps it through the cone; the air in its path is smeared aside
--   and the knuckles' lightning cracks along the arc / a heavy swat you saw
--   coming / tell on the fist + hit confirm.
-- Thunder Pound: both fists rise, load with lightning and hammer the ground;
--   the ground breaks and the lightning discharges into the cracks / weight /
--   the chain's big hit. Pound wave (phase 2+): the shock rolls on through the
--   ground as a ring of heaving earth / a second thing to jump.
-- Body Slam: the ape rears and throws its whole weight down the lane, belly
--   first / mass coming at you / lane telegraph + impact.
-- Skyfall Slam: crouch, spring high, come down fists first on where you stood
--   / dread from above / circle telegraph + impact.
-- Judgment (phase 3): the ape leaps into the storm and the sky answers with a
--   bolt that rides it down / the fight's biggest moment / long tell + stun.
-- Thunder Rush: drops to all fours, digs in, charges the lane like a storm
--   front / momentum / the coil warns, the bow wave shows the charge.
-- Bound: a hop: feet push off and land / repositioning, no threat read.
-- Boulder Hurl: tears a boulder out of the ground, charges it, throws it /
--   a slow readable throw / projectile + splash.
-- Thunder Lance (phase 2+): forges a javelin of lightning in the fist and
--   hurls it down the lane / a sharp, fast threat / lane + projectile.
-- Roars (thunderRoar, phaseRoar, challenge): chest beats thump air off the
--   chest, a huge breath is drawn, then a blast of air, sound and lightning
--   leaves the mouth and the air shoves dust out along the floor / dread,
--   get back / the stagger radius. No ground crack: a roar hits nothing.
-- Storm Call: arms raised, the ape's lightning climbs into the sky and the
--   storm answers with bolts on where you stand / keep moving / each bolt's
--   own circle (server) + the strike.
-- Phase change: the storm in the body surges out / escalation.
-- Hits: the blow (lightning or weight) landing on the player.
-- Death: the storm in the ape breaks loose, leaking faster and faster, then
--   the last of it leaps back up into the sky / release, reward.
--
-- BEAT SHEET (ms from the windup cue; contact = windup end, def timings)
-- | Move | Anticipation | Peak (hero first) | Follow-through / dissipation |
-- | big windups | 0-350 EyeGlint on both eyes | - | - |
-- | Club 800 / backhand 600 / rushSwipe 400 / skyfallSweep 500 | 0-W KnuckleCharge on the swinging fist: arcs crawl, last 25% denser, glint at 80% | W SwingArc: smeared crescent across the cone on slate (hero); +40 arcs flung off the arc; +60 grit where the knuckles graze; FistTrail rides the fist 0-300 through the follow-through | to 400 |
-- | Pound 850 | 0-850 KnuckleCharge on both fists | 850 PoundImpact: shock ring on slate (hero), flash; +30 lit cracks over the carved crater, arcs in the cracks, heaved rock; +40 chunks; +60 dust wall | +250 settling dust to 2600; lit cracks cool by 1300; crater fades by 4500 |
-- | Pound wave (+450) | 0-450 the front travels r15 -> r34: heaved shard ring, crackle and dust on it | 450 PoundWaveEnd: dust and arcs burst off the ring | to 1200 |
-- | Body Slam 1100 (+dash ~550) | 0-1100 ChestCharge (arcs gather on the chest) | dash: BowWave (air rings peel off the chest), SpeedShed arcs; land: BellyImpact dust cloud bursting out (hero), shock ring on slate, flash, chunks | +250 settle to 2500 |
-- | Skyfall 1200 (+750 flight) | 600-1200 Coil at the hind feet; KnuckleCharge both fists | take-off Launch; flight LimbTrails; landing SkyfallImpact: blade shock ring on slate (hero), flash, crater + lit cracks, ground forks, heaved rock, chunks, dust wall | settle to 2600 |
-- | Judgment 1600 (+1000 flight) | 0-2600 JudgeCloud gathers over the landing, arcs in it from 50%; BodyCrackle; sky dims | take-off: a bolt strikes the ape (BoltHit); landing: the cloud's bolt rides it down (code beam) + JudgmentImpact discharge ring (hero), spike flare, shock on slate, crater, lit cracks, forks, chunks, dust wall | settle to 3000 |
-- | Rush 1200 (+dash <=700) | 480-1200 Coil at fists and feet | take-off Launch; dash BowWave (hero), SpeedShed, LimbTrails; stop Skid at both fists | - |
-- | Bound 450 | - | Launch at 0.5x take-off, again on landing | - |
-- | Boulder 1700 | 0-600 BoulderRip (cracks, plume, chunks); 600-1250 rock rides the fist shedding grit; 1000-1250 BoulderCharge arcs | 1250 throw; flight dust trail + shadow; impact BoulderImpact: rock shatters (hero), dust burst, flash, shock on slate, crater | to 2500 |
-- | Lance 1400 | 0-1400 LanceForm: arcs drawn into the fist, the javelin grows from 300, glint at 1250 | 1400 LanceFlash at the fist; flight LanceBolt (hero) + ScorchSpots; end BoltStrike | - |
-- | thunderRoar 1300 / phaseRoar 1600 / challenge 2400 | ChestBeat at each beat (0.45/0.85; 0.4/0.8/1.2; 0.55/1.15/1.75); last 450 Inhale at the mouth + BodyCrackle | W RoarBlast: sound cone from the mouth on indigo (hero), +0/+80/+160 sound rings, +40 arcs; +120 RoarGround dust shoved out to the stun radius | to 900; phaseRoar +200..+500 storm bolts round it |
-- | Storm Call 1200 | 0-1200 StormRaise arcs climbing off the back, KnuckleCharge; sky dims | 1200 a bolt leaves the back for the sky (code beam) | bolts: BoltGather cloud 0-900 (arcs from 55%), 900 BoltStrike (code beam hero, flash, discharge, scorch, sparks, dust) |
-- | Phase | - | PhaseSurge: arcs burst out of the body (hero), flash, discharge, air ring | aura rebuilt |
-- | Hits | - | HitStorm / HitHeavy on the struck player; StunArcs 0-1000 after judgment | 300 |
-- | Stagger | - | StaggerPop: arcs knocked out of the chest, flash | 250 |
-- | Death 3200 | 0-3000 DeathLeak arcs over the body, ramping; code bolts lance out | 3050 DeathRelease: twister rises from the body (hero) with a bolt to the sky, flash, discharge, rising arcs; DeathGround shock + dust | to 4200 |
--
-- LAYER SHEET (role: cause -> asset and why)
-- EyeGlint     secondary: intent on the first frame of a big move -> 4-point star 13908198788
-- KnuckleCharge secondary: lightning gathering in the fist -> crackle-arc flipbook 11492870634 (4x4, arcs appearing and dying) over an indigo core; star 13908198788 for "now"
-- SwingArc     HERO: the fist sweeping the air -> heavy smeared crescent 88807999398470 on a slate copy; secondary arcs 76973563852665 (2x2 bold arcs, random frame); environment grit: dust flipbook 11989899750
-- FistTrail    secondary: the charged fist carrying through -> Trail with the electric strip 10528782340 over an indigo trail
-- PoundImpact  HERO: shock ring mesh 129778117978668 on slate; secondary flash flipbook 12156297119 (4x4 star shrinking), crater 11705672210 + carved cracks 7994630128, lit cracks 301851161 (radial lightning cracks), crack arcs 11492870634, heaved rock mesh 89195313060285; tertiary rock chunks flipbook 126533699507957 (4x4 tumbling rock), dust wall 11989899750; environment settle 71869624437521 (4x4 puff breaking up)
-- PoundWave    HERO: the travelling front -> ragged shard ring mesh 1726537151 (Slate), crackling ring 7150933366, dust ring 16505105356; End: dust 11989899750 and arcs 76973563852665 off the ring surface
-- ChestCharge  secondary: lightning gathering on the chest -> 11492870634 + indigo core
-- BowWave      HERO (dash): air shoved ahead of the body -> soft air ring 15611866526 facing the run, air streaks flipbook 15107683952 streaming back
-- SpeedShed    tertiary: lightning shed where the body passed -> 76973563852665
-- BellyImpact  HERO: the belly landing -> dust cloud 11989899750 bursting out; secondary swirl shock ring mesh 73349240058321 on slate, flash 12156297119, chunks 126533699507957; environment settle 71869624437521
-- Coil / Launch / Skid  secondary: feet and fists digging, pushing off, ploughing -> dust 11989899750, chunks 126533699507957, swirl ring mesh 73349240058321 (Launch)
-- LimbTrail    tertiary: limbs streaking through the air -> Trail 10528782340 over indigo
-- SkyfallImpact HERO: blade shock ring mesh 122007796695786 on slate; secondary flash, crater 11705672210 + cracks 7994630128 + lit 301851161, ground forks 914595092 (forked bolt laid flat), heaved rock 89195313060285; tertiary chunks, dust wall; environment settle
-- JudgeCloud   secondary: the storm gathering over the landing -> cloud flipbook 14050526759 (2x2 puffs) in indigo, arcs 11492870634 in it
-- BoltHit      secondary: the bolt striking the ape at take-off -> flash 12156297119, discharge 528280947 (spider burst of arcs)
-- JudgmentImpact HERO: the bolt's discharge ring -> crackling ring 7150933366 over a dust ring 16505105356, spike flare mesh 102470267627424 rising; secondary blade shock mesh on slate, flash, crater, cracks, forks 914595092; tertiary chunks, dust wall; environment settle
-- BoulderRip   secondary: the floor torn open -> cracks 7994630128, dust plume 11989899750, chunks 126533699507957
-- BoulderRock / BoulderSkin  the rock (stone mesh 17608108317, from the old set) shedding grit (chunks, dust) and a dust Trail in flight
-- BoulderCharge secondary: the ape charging the rock -> 76973563852665, star 13908198788
-- BoulderShadow environment: the rock's shadow on the floor -> dot 9841273544 (a soft dark disc, cores/shadows only)
-- BoulderImpact HERO: the rock shattering -> chunks 126533699507957 thrown out; secondary dust burst 11989899750, flash, discharge 7216850580 (the rock's charge), shock ring mesh 73349240058321 on slate, crater 11705672210
-- LanceForm    secondary: lightning drawn into the fist, a javelin growing -> 11492870634 inward, electric strip 10528782340, star 13908198788
-- LanceBolt    HERO (flight): the javelin -> Beams (indigo, glow, electric strip core 10528782340), Trails, shed arcs 76973563852665
-- LanceFlash   secondary: the throw / the end -> flash 12156297119, discharge 528280947
-- ScorchSpot   environment: the bolt burning the floor it passes low over -> scorch 7216852679 dark
-- ChestBeat    secondary: a fist hitting the chest -> swirl ring mesh 73349240058321 thumped forward, zigzag sparks flipbook 12517923720, flash
-- Inhale       secondary: breath drawn into the mouth -> air streaks 15107683952 inward, air ring 15611866526 shrinking
-- BodyCrackle  secondary: lightning building over the body -> 11492870634 on the torso box
-- RoarBlast    HERO: sound and air leaving the mouth -> swirling funnel mesh 71849885439764 opening forward over an indigo copy; secondary wobbly sound rings 90387581951997; tertiary arcs 76973563852665
-- RoarGround   environment: the blast shoving air along the floor -> dust ring 16505105356, dust 11989899750 radial
-- StormRaise   secondary: lightning climbing off the back into the sky -> 11492870634 upward
-- BoltGather   secondary: the strike's cloud -> 14050526759 indigo puffs, arcs 11492870634 from 55%
-- BoltStrike   HERO: code bolt (Bolt template: indigo edge, glow, electric strip core 10528782340); secondary flash 12156297119, discharge 528280947 flat; environment scorch 7216852679, tertiary zigzag sparks 12517923720, dust 11989899750
-- PhaseSurge   HERO: the storm surging out of the body -> 76973563852665 burst, discharge 528280947, flash, swirl ring mesh 73349240058321
-- HitStorm / HitHeavy / StunArcs: the blow on the player -> 528280947, 12156297119, 12517923720 (+ dust and chunks for heavy); 11492870634 crawling for the stun
-- StaggerPop   qi knocked out of the chest -> 76973563852665, 12156297119
-- DeathLeak    the storm leaking from the body -> 11492870634, 76973563852665 (rates ramped by code)
-- DeathRelease HERO: the storm leaving upward -> twister mesh 117701979506507 rising; secondary flash, discharge 528280947, rising arcs 11492870634; DeathGround: shock ring mesh 73349240058321 on slate, dust 11989899750
-- Aura (always on, light): AuraForearm arcs 11492870634; AuraCloud indigo wisps 14050526759 on the shoulders and back; AuraArcs (phase 2+) 76973563852665 on fists and shoulders
--
-- Every template is an invisible anchored Part (centre = pivot, -Z = facing
-- or blow direction). Ground templates have their centre on the floor and an
-- AuthoredRadius; held tells carry AuthoredSeconds. MeshWave models
-- (TechniqueVFX.playWaves) are the 3D shocks; their sizes are studs and the
-- runtime scales them with the template. Particle Size is a radius.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local AssetService = game:GetService("AssetService")
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local BRIGHT = Color3.fromRGB(91, 216, 255)
local RIM = Color3.fromRGB(184, 240, 255)
local INDIGO = Color3.fromRGB(27, 37, 71)
local SLATE = Color3.fromRGB(46, 52, 66)
local DUST = Color3.fromRGB(128, 120, 108)
local ROCK = Color3.fromRGB(104, 98, 92)
local SCORCH = Color3.fromRGB(24, 22, 28)

local TEX = {
	arcs = id(11492870634), -- 4x4 flipbook: crackling arcs appearing and dying
	arcsBold = id(76973563852665), -- 2x2 bold arcs (random frame)
	fork = id(914595092), -- one forked bolt
	discharge = id(528280947), -- spider burst of arcs
	plasma = id(7216850580), -- electric burst
	zigzag = id(12517923720), -- 4x4: a zigzag spark breaking up
	flash = id(12156297119), -- 4x4: a star flash shrinking away
	glint = id(13908198788), -- 4-point star
	smear = id(88807999398470), -- heavy smeared crescent
	streaks = id(15107683952), -- 4x4 air streaks
	dust = id(11989899750), -- 4x4: a dust burst breaking up
	settle = id(71869624437521), -- 4x4: a puff breaking into shreds
	chunks = id(130042646554310), -- 2x2: four rock chunks
	cloud = id(14050526759), -- 2x2 cloud puffs
	crater = id(11705672210),
	crackDark = id(7994630128),
	crackLit = id(301851161), -- radial lightning cracks
	scorch = id(7216852679),
	soundRing = id(90387581951997), -- thin wobbly ring
	elecRing = id(7150933366), -- crackling ring
	airRing = id(15611866526), -- soft air ring
	dustRing = id(16505105356), -- dust donut
	strip = id(10528782340), -- vertical electric strip (beams, trails)
	dot = id(9841273544), -- cores and the shadow only
}
local MESH = {
	roarCone = id(71849885439764), -- ragged swirling funnel, 3.4 x 3.0 x 3.2 (opens along +Y)
	shockNotch = id(129778117978668), -- thick notched ring, 2.4 x 0.56 x 2.5
	shardRing = id(1726537151), -- ragged shard ring (flat)
	swirlRing = id(73349240058321), -- swirl ring, 2.4 x 0.48 x 2.3
	bladeRing = id(122007796695786), -- blade-edged ring, 2.4 x 0.48 x 2.1
	rupture = id(89195313060285), -- flat spiky splash of earth, 1.1 x 0.3 x 1.1
	spikeFlare = id(102470267627424), -- upward spiky flare, 2.5 x 2.5 x 2.4
	twister = id(117701979506507), -- twisting funnel, 2 x 2 x 2
}

local STORM = CS({ CK(0, WHITE), CK(0.35, RIM), CK(1, BRIGHT) })
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
local function grid4(extra)
	return with({ FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot }, extra)
end
local function grid2(extra)
	return with({ FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Random }, extra)
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
local DUSTFADE = seq(0, 0.15, 0.5, 0.3, 1, 1)
local FLICK = seq(0, 0, 0.2, 0.4, 0.35, 0, 0.6, 0.5, 1, 1)

local function part(root, name, size, attrs)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Transparency = 1
	p.Size = size or Vector3.new(0.4, 0.4, 0.4)
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
	if typeof(pos) == "CFrame" then
		a.CFrame = pos
	else
		a.Position = pos or Vector3.zero
	end
	a.Parent = parent
	return a
end

-- Size is a radius, authored directly.
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
	for k, v in attrs or { EmitCount = 1 } do
		e:SetAttribute(k, v)
	end
	if e.Rate > 0 then
		e:SetAttribute("BaseRate", e.Rate)
	end
	e.Parent = parent
	return e
end
local function earthy(props)
	return with({ LightEmission = 0, LightInfluence = 1 }, props)
end
-- rock chunks: one of four rock frames per particle (2x2, held), tumbling
local function rocks(extra)
	return earthy(with({ Texture = TEX.chunks, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Random, FlipbookFramerate = R(0, 0), Color = CS(Color3.fromRGB(200, 192, 184)) }, extra))
end
-- a camera-facing puff sitting on the floor is cut in half by it: dust and
-- smoke are emitted from `h` studs up (an attachment beside `parent`)
local function lift(parent, h)
	local holder = if parent:IsA("Attachment") then parent.Parent else parent
	local base = if parent:IsA("Attachment") then parent.Position else Vector3.zero
	return att(holder, "Lift", base + Vector3.new(0, h, 0))
end

local meshCache = {}
-- A 3D shock: a library mesh tweened From -> To (TechniqueVFX.playWaves).
local function wave(parent, name, meshId, p)
	local w = Instance.new("Model")
	w.Name = name
	w:SetAttribute("MeshWave", true)
	for k, v in {
		FromSize = p.from, ToSize = p.to, FromOffset = p.fromOffset, ToOffset = p.toOffset,
		Rotation = p.rotation, FromTransparency = p.fromT or 0.2, ToTransparency = 1,
		Duration = p.duration or 0.3, Style = p.style or "Quart", FadeStyle = p.fade, EmitDelay = p.delay,
	} do
		w:SetAttribute(k, v)
	end
	local source = meshCache[meshId]
	if not source then
		source = AssetService:CreateMeshPartAsync(meshId)
		meshCache[meshId] = source
	end
	local m = source:Clone()
	m.Name = "Mesh"
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
	m.Material = p.material or Enum.Material.Neon
	m.Color = p.color or RIM
	m.Transparency = 1
	m.Parent = w
	w.Parent = parent
	return w
end
-- a dark copy under a bright mesh wave, slightly larger
local function darkWave(parent, name, meshId, p)
	return wave(parent, name, meshId, with(p, {
		from = p.from * 1.04, to = p.to * 1.04, material = Enum.Material.SmoothPlastic, color = p.dark or SLATE, fromT = p.darkT or 0.1,
		fromOffset = (p.fromOffset or Vector3.zero) - Vector3.new(0, 0.1, 0), toOffset = (p.toOffset or Vector3.zero) - Vector3.new(0, 0.1, 0),
	}))
end

-- a screen shake through the plugin's ScreenEffects (its own attachment)
local function shake(parent, csv)
	local a = att(parent, "Shake")
	a:SetAttribute("CameraShake", csv)
end

local function trailPair(parent, name, half, life, widthScale)
	local top = att(parent, name .. "Top", Vector3.new(0, half, 0))
	local bottom = att(parent, name .. "Bottom", Vector3.new(0, -half, 0))
	local dark = Instance.new("Trail")
	dark.Name = name .. "Dark"
	dark.Attachment0, dark.Attachment1 = top, bottom
	dark.Color = CS(INDIGO)
	dark.LightEmission = 0
	dark.Transparency = seq(0, 0.35, 1, 1)
	dark.Lifetime = life * 0.8
	dark.WidthScale = widthScale or seq(0, 1, 1, 0.3)
	dark.FaceCamera = true
	dark.Enabled = false
	dark.Parent = parent
	local bright = Instance.new("Trail")
	bright.Name = name .. "Bright"
	bright.Attachment0, bright.Attachment1 = top, bottom
	bright.Texture = TEX.strip
	bright.TextureMode = Enum.TextureMode.Stretch
	bright.Color = STORM
	bright.LightEmission = 1
	bright.Brightness = 3
	bright.Transparency = seq(0, 0, 1, 1)
	bright.Lifetime = life
	bright.WidthScale = widthScale or seq(0, 0.8, 1, 0.2)
	bright.FaceCamera = true
	bright.Enabled = false
	bright.Parent = parent
end

-- the pieces several templates share (each a function of its own numbers)
local function flash(parent, name, size, delay, life)
	-- the sheet opens on a round burst: kept small and short so it reads as
	-- one white-hot frame, not a blob
	return em(parent, name, grid4({ Texture = TEX.flash, Color = STORM, LightEmission = 1, Brightness = 2, Lifetime = R(life or 0.2), Size = NS(size * 0.65), Transparency = seq(0, 0.1, 1, 0.4), ZOffset = 3 }), { EmitCount = 1, EmitDelay = delay })
end
local function chunks(parent, count, speed, size, delay)
	return em(parent, "Chunks", rocks({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = speed, Acceleration = Vector3.new(0, -110, 0), Lifetime = R(0.8, 1.2), Size = size, Rotation = R(0, 360), RotSpeed = R(-200, 200) }), { EmitCount = count, EmitDelay = delay })
end
-- dust thrown out flat along the floor (a point emitter fanning 360 degrees)
local function dustWall(parent, name, count, speed, size, delay, life)
	return em(lift(parent, size.Keypoints[1].Value * 0.8 + 0.6), name, grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(8, 180), Speed = speed, Drag = 4, Lifetime = life or R(0.9, 1.3), Size = size, Transparency = DUSTFADE, Rotation = R(0, 360), RotSpeed = R(-30, 30) })), { EmitCount = count, EmitDelay = delay })
end
local function settle(parent, count, size, delay)
	return em(lift(parent, size.Keypoints[1].Value * 0.6), "Settle", grid4(earthy({ Texture = TEX.settle, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Sphere, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(2, 5), Drag = 1, Lifetime = R(1.8, 2.4), Size = size, Transparency = seq(0, 0.45, 0.4, 0.55, 1, 1), Rotation = R(0, 360), RotSpeed = R(-15, 15) })), { EmitCount = count, EmitDelay = delay })
end
-- a carved crater with dark cracks, and the lightning burning in the cracks
local function crater(parent, size, litSize, life, delay)
	em(parent, "Crater", with(FLAT, earthy({ Texture = TEX.crater, Color = CS(WHITE), Lifetime = R(life), Size = NS(size), Rotation = R(0, 360), Transparency = seq(0, 0, 0.8, 0, 1, 1), ZOffset = 0.1 })))
	em(parent, "CracksDark", with(FLAT, earthy({ Texture = TEX.crackDark, Color = CS(SCORCH), Lifetime = R(life), Size = NS(litSize), Rotation = R(0, 360), Transparency = seq(0, 0.05, 0.8, 0.1, 1, 1), ZOffset = 0.2 })))
	em(parent, "CracksLit", with(FLAT, { Texture = TEX.crackLit, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(1.3), Size = NS(litSize * 0.95), Rotation = R(0, 360), Transparency = seq(0, 0, 0.25, 0.15, 1, 1), ZOffset = 0.3 }), { EmitCount = 1, EmitDelay = delay or 0.03 })
end
local function shockRing(parent, meshId, radius, delay, duration)
	local from = Vector3.new(radius * 0.25, 1.5, radius * 0.25)
	local to = Vector3.new(radius * 2, 3.5, radius * 2)
	darkWave(parent, "ShockDark", meshId, { from = from, to = to, fromOffset = Vector3.new(0, 0.4, 0), toOffset = Vector3.new(0, 0.8, 0), duration = duration or 0.32, delay = delay, fade = "Quint" })
	wave(parent, "Shock", meshId, { from = from, to = to * 0.97, fromOffset = Vector3.new(0, 0.6, 0), toOffset = Vector3.new(0, 1, 0), duration = duration or 0.32, delay = delay, fromT = 0.15, fade = "Quint" })
end
local function rupture(parent, radius, delay)
	wave(parent, "Rupture", MESH.rupture, { from = Vector3.new(radius * 0.4, 1, radius * 0.4), to = Vector3.new(radius * 1.7, radius * 0.55, radius * 1.7), duration = 0.4, delay = delay, fromT = 0, material = Enum.Material.Slate, color = ROCK, fade = "Quint" })
end

function _G.buildThunderApeFX(effects)
	local old = effects:FindFirstChild("ThunderApe")
	-- the boulder's stone mesh is kept from the previous build (a MeshPart)
	local keptRock = old and old:FindFirstChild("BoulderRock")
	if keptRock then
		keptRock = keptRock:Clone()
	end
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ThunderApe"

	-- EyeGlint (each eye, 0-350 of a big windup): the ape's intent.
	do
		local p = part(root, "EyeGlint", nil, { AuthoredSeconds = 0.5 })
		em(p, "Glint", { Texture = TEX.glint, Color = STORM, LightEmission = 1, Brightness = 4, Lifetime = R(0.35), Size = seq(0, 0, 0.15, 2.2, 1, 0), Rotation = R(-10, 10), LockedToPart = true, ZOffset = 3 })
	end

	-- KnuckleCharge (a fist, through the windup): lightning gathering in it.
	do
		local p = part(root, "KnuckleCharge", Vector3.new(3, 3, 3), { AuthoredSeconds = 0.8 })
		em(p, "Core", { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(0.8), Size = seq(0, 1.5, 1, 3.2), Transparency = seq(0, 0.9, 0.8, 0.35, 1, 1), LockedToPart = true, ZOffset = 0.5 })
		local arcs = grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Sphere, Lifetime = R(0.2, 0.28), Size = NS(2.6), Rotation = R(0, 360), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Arcs", with(arcs, { Rate = 7 }), { EmitDuration = 0.8 })
		em(p, "ArcsLate", with(arcs, { Rate = 18, Size = NS(3.2) }), { EmitDelay = 0.55, EmitDuration = 0.25 })
		em(p, "Glint", { Texture = TEX.glint, Color = STORM, LightEmission = 1, Brightness = 4, Lifetime = R(0.2), Size = seq(0, 0, 0.2, 4, 1, 0), LockedToPart = true, ZOffset = 3 }, { EmitCount = 1, EmitDelay = 0.64 })
	end

	-- SwingArc (at fist height ahead of the chest, facing the blow): the fist
	-- sweeping the cone. R = the right fist sweeping right to left.
	for _, side in { { "SwingArcR", 1 }, { "SwingArcL", -1 } } do
		local p = part(root, side[1], Vector3.new(22, 2, 10))
		local d = side[2]
		local arc = { Texture = TEX.smear, EmissionDirection = Enum.NormalId.Top, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = R(0.01), Lifetime = R(0.3), Rotation = R(d > 0 and 200 or -20), RotSpeed = R(d * 300) }
		local a = att(p, "Arc", Vector3.new(0, 0, 0))
		em(a, "SmearDark", with(arc, { Color = CS(SLATE), Size = seq(0, 14, 1, 18), Transparency = seq(0, 0.15, 0.55, 0.35, 1, 1), ZOffset = 0.5 }))
		em(a, "Smear", with(arc, { Color = STORM, LightEmission = 0.9, Brightness = 2.5, Size = seq(0, 13, 1, 17), Transparency = seq(0, 0, 0.55, 0.15, 1, 1), ZOffset = 1.5 }))
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(8, 16), Drag = 6, Lifetime = R(0.16, 0.24), Size = NS(3.2), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 }), { EmitCount = 5, EmitDelay = 0.04 })
		local g = att(p, "Ground", Vector3.new(0, -4.3, 0))
		em(g, "Grit", grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), EmissionDirection = Enum.NormalId.Left, SpreadAngle = Vector2.new(20, 25), Speed = R(10, 16), Drag = 3, Lifetime = R(0.6, 0.8), Size = seq(0, 2.5, 1, 5), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 4, EmitDelay = 0.06 })
		if d < 0 then
			g:FindFirstChild("Grit").EmissionDirection = Enum.NormalId.Right
		end
		shake(p, "Custom,30~100,0.7,0.25,16,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- LimbTrail (a fist or foot, while it carries through or flies): the
	-- charged limb streaking through the air (also the swing's follow-through).
	do
		local p = part(root, "LimbTrail", Vector3.new(1, 1, 1))
		trailPair(p, "Trail", 1.4, 0.2)
	end

	-- PoundImpact (centre of the locked circle, r15): both fists hammer the
	-- ground: shock ring on slate (hero), flash, crater with lightning in the
	-- cracks, heaved rock, chunks, dust wall, settling dust.
	do
		local p = part(root, "PoundImpact", Vector3.new(1, 1, 1), { AuthoredRadius = 15 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		shockRing(p, MESH.shockNotch, 15, 0, 0.32)
		flash(att(p, "Up", Vector3.new(0, 3, 0)), "Flash", 7, 0, 0.16)
		crater(g, 10, 14, 4.5, 0.03)
		em(g, "CrackArcs", grid4(with(FLAT, { Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 26, Lifetime = R(0.18, 0.26), Size = NS(3.2), Rotation = R(0, 360), ZOffset = 0.4 })), { EmitDelay = 0.03, EmitDuration = 0.55 })
		rupture(p, 15, 0.03)
		chunks(g, 12, R(30, 48), NS(2), 0.04)
		dustWall(g, "DustWall", 14, R(42, 56), seq(0, 3, 1, 7.5), 0.06)
		settle(g, 6, seq(0, 6, 1, 10), 0.25)
		shake(p, "Custom,30~120,2.2,0.5,14,0.02,1;1;1,0.15;0.15;0.15")
	end

	-- PoundWave (the pound's centre, r34, over the 0.45 s before the ring
	-- hits): the shock travelling out through the ground; PoundWaveEnd at the hit.
	do
		local p = part(root, "PoundWave", Vector3.new(1, 1, 1), { AuthoredRadius = 34, AuthoredSeconds = 0.45 })
		wave(p, "Front", MESH.shardRing, { from = Vector3.new(30, 2.5, 30), to = Vector3.new(68, 5, 68), fromOffset = Vector3.new(0, 0.4, 0), toOffset = Vector3.new(0, 0.6, 0), duration = 0.45, style = "Linear", fromT = 0.05, material = Enum.Material.Slate, color = ROCK, fade = "Quint" })
		em(p, "Crackle", with(FLAT, { Texture = TEX.elecRing, Color = STORM, LightEmission = 1, Brightness = 2.5, Lifetime = R(0.45), Size = seq(0, 15, 1, 34), Rotation = R(0, 360), RotSpeed = R(-40, 40), Transparency = seq(0, 0.5, 0.85, 0.1, 1, 1), ZOffset = 1 }))
		em(p, "DustFront", with(FLAT, earthy({ Texture = TEX.dustRing, Color = CS(DUST), Lifetime = R(0.5), Size = seq(0, 16, 1, 36), Rotation = R(0, 360), Transparency = seq(0, 0.55, 0.85, 0.25, 1, 1), ZOffset = 0.5 })))
	end
	do
		local p = part(root, "PoundWaveEnd", Vector3.new(68, 1, 68), { AuthoredRadius = 34 })
		local ring = { Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward }
		em(p, "Dust", grid4(earthy(with(ring, { Texture = TEX.dust, Color = CS(DUST), Speed = R(6, 12), Drag = 3, Acceleration = Vector3.new(0, 8, 0), Lifetime = R(0.8, 1.1), Size = seq(0, 3, 1, 6.5), Transparency = DUSTFADE, Rotation = R(0, 360) }))), { EmitCount = 16 })
		em(p, "Arcs", grid2(with(ring, { Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Speed = R(2, 5), Lifetime = R(0.16, 0.24), Size = NS(3.6), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 })), { EmitCount = 10 })
		shake(p, "Custom,10~80,1.0,0.3,14,0.02,1;1;1,0.08;0.08;0.08")
	end

	-- ChestCharge (Core, body slam windup): lightning gathering on the chest.
	do
		local p = part(root, "ChestCharge", Vector3.new(8, 8, 3), { AuthoredSeconds = 1.1 })
		em(p, "Core", { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(1.1), Size = seq(0, 3, 1, 7), Transparency = seq(0, 0.9, 0.8, 0.4, 1, 1), LockedToPart = true, ZOffset = 0.5 })
		local arcs = grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, Lifetime = R(0.2, 0.28), Size = NS(3.4), Rotation = R(0, 360), LockedToPart = true, ZOffset = 1.5 })
		em(p, "Arcs", with(arcs, { Rate = 8 }), { EmitDuration = 1.1 })
		em(p, "ArcsLate", with(arcs, { Rate = 22, Size = NS(4.2) }), { EmitDelay = 0.8, EmitDuration = 0.3 })
	end

	-- BowWave (Chest, while dashing): air shoved ahead of the body.
	do
		local p = part(root, "BowWave", Vector3.new(10, 10, 2))
		local a = att(p, "Front", Vector3.new(0, -2, -8))
		em(a, "AirRing", { Texture = TEX.airRing, Color = CS(RIM), LightEmission = 0.4, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, Speed = R(2), Rate = 9, Lifetime = R(0.3), Size = seq(0, 5, 1, 11), Transparency = seq(0, 0.45, 1, 1), Rotation = R(0, 360), ZOffset = 1 }, {})
		em(p, "Streaks", grid4({ Texture = TEX.streaks, Color = CS(RIM), LightEmission = 0.6, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Back, Speed = R(30, 40), Rate = 22, Lifetime = R(0.2, 0.3), Size = NS(2.6), Transparency = seq(0, 0.3, 1, 1) }), {})
	end

	-- SpeedShed (the torso box, while dashing or flying): lightning shed where
	-- the body passed.
	do
		local p = part(root, "SpeedShed", Vector3.new(10, 10, 10))
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, Rate = 12, Lifetime = R(0.12, 0.2), Size = NS(3.4), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 1 }), {})
	end

	-- BellyImpact (floor under the chest, r16): the belly landing: a dust
	-- cloud bursting out (hero), shock ring on slate, flash, chunks, settle.
	do
		local p = part(root, "BellyImpact", Vector3.new(1, 1, 1), { AuthoredRadius = 16 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		dustWall(g, "DustCloud", 18, R(32, 46), seq(0, 5, 1, 11), 0, R(1.1, 1.5))
		shockRing(p, MESH.swirlRing, 17, 0.02, 0.3)
		flash(att(p, "Up", Vector3.new(0, 3, 0)), "Flash", 8, 0, 0.16)
		chunks(g, 8, R(26, 38), NS(1.8), 0.04)
		settle(g, 6, seq(0, 7, 1, 11), 0.25)
		shake(p, "Custom,30~120,2.0,0.5,12,0.02,1;1;1,0.15;0.15;0.15")
	end

	-- Coil (each digging fist or foot, last part of a charge/leap windup).
	do
		local p = part(root, "Coil", Vector3.new(1, 1, 1), { AuthoredSeconds = 0.6 })
		em(att(p, "Lift", Vector3.new(0, 1.4, 0)), "Dust", grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(25, 25), Speed = R(6, 10), Drag = 3, Rate = 9, Lifetime = R(0.5, 0.7), Size = seq(0, 1.5, 1, 3.5), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitDuration = 0.6 })
		em(p, "Grit", rocks({ EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(30, 30), Speed = R(10, 16), Acceleration = Vector3.new(0, -80, 0), Rate = 5, Lifetime = R(0.5, 0.7), Size = NS(0.6), RotSpeed = R(-200, 200) }), { EmitDuration = 0.6 })
	end

	-- Launch (a foot at take-off, or a landing hop): the push off the ground.
	do
		local p = part(root, "Launch", Vector3.new(1, 1, 1))
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		dustWall(g, "Dust", 8, R(16, 24), seq(0, 2.5, 1, 5.5), 0, R(0.7, 1))
		wave(p, "Ring", MESH.swirlRing, { from = Vector3.new(3, 1, 3), to = Vector3.new(16, 2, 16), fromOffset = Vector3.new(0, 0.3, 0), toOffset = Vector3.new(0, 0.6, 0), duration = 0.25, fromT = 0.5, material = Enum.Material.SmoothPlastic, color = DUST, fade = "Quint" })
		chunks(g, 4, R(16, 24), NS(0.9), 0.02)
	end

	-- Skid (each fist as a charge stops): the fists ploughing the ground.
	do
		local p = part(root, "Skid", Vector3.new(1, 1, 1))
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		em(lift(g, 2), "Plough", grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(15, 35), Speed = R(18, 28), Drag = 5, Lifetime = R(0.7, 1), Size = seq(0, 2.5, 1, 6), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 7 })
		em(g, "Chunks", rocks({ EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Speed = R(20, 30), Acceleration = Vector3.new(0, -100, 0), Lifetime = R(0.6, 0.9), Size = NS(0.9), RotSpeed = R(-200, 200) }), { EmitCount = 5, EmitDelay = 0.02 })
	end

	-- SkyfallImpact (centre of the leap circle, r20): the ape lands fists
	-- first: blade shock ring on slate (hero), flash, crater and lit cracks,
	-- the fists' lightning forking along the ground, heaved rock, chunks, dust.
	do
		local p = part(root, "SkyfallImpact", Vector3.new(1, 1, 1), { AuthoredRadius = 20 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		shockRing(p, MESH.bladeRing, 20, 0, 0.34)
		flash(att(p, "Up", Vector3.new(0, 4, 0)), "Flash", 9, 0, 0.18)
		crater(g, 12, 18, 4.5, 0.03)
		em(g, "Forks", with(FLAT, { Texture = TEX.fork, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.18, 0.26), Size = NS(8.5), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 0.5 }), { EmitCount = 6, EmitDelay = 0.03 })
		rupture(p, 20, 0.03)
		chunks(g, 14, R(34, 52), NS(2.2), 0.04)
		dustWall(g, "DustWall", 16, R(50, 66), seq(0, 3.5, 1, 9), 0.06)
		settle(g, 7, seq(0, 7, 1, 12), 0.25)
		shake(p, "Custom,40~150,2.8,0.6,12,0.02,1;1;1,0.2;0.2;0.2")
	end

	-- JudgeCloud (52 studs over the landing, windup + flight): the storm the
	-- ape calls gathering where it will land.
	do
		local p = part(root, "JudgeCloud", Vector3.new(36, 6, 36), { AuthoredSeconds = 2.6 })
		em(p, "Cloud", { Texture = TEX.cloud, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = CS(INDIGO), LightEmission = 0, LightInfluence = 0.3, Shape = Enum.ParticleEmitterShape.Box, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = R(1, 3), Rate = 6, Lifetime = R(2, 2.6), Size = seq(0, 8, 1, 14), Transparency = seq(0, 1, 0.3, 0.2, 0.8, 0.3, 1, 1), Rotation = R(0, 360), RotSpeed = R(-10, 10) }, { EmitDuration = 2.6 })
		em(p, "Arcs", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, Rate = 7, Lifetime = R(0.2, 0.28), Size = NS(7), Rotation = R(0, 360), ZOffset = 1 }), { EmitDelay = 1.3, EmitDuration = 1.3 })
	end

	-- BoltHit (chest, at the judgment take-off): the bolt striking the ape.
	do
		local p = part(root, "BoltHit", Vector3.new(1, 1, 1))
		flash(p, "Flash", 12, 0, 0.2)
		em(p, "Discharge", { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.22), Size = seq(0, 8, 1, 14), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 })
	end

	-- JudgmentImpact (centre of the leap circle, r28): the bolt's discharge
	-- ring (hero) and spike flare, the landing's shock, crater, cracks, forks.
	do
		local p = part(root, "JudgmentImpact", Vector3.new(1, 1, 1), { AuthoredRadius = 28 })
		local g = att(p, "Ground", Vector3.new(0, 0.25, 0))
		em(g, "RingDark", with(FLAT, earthy({ Texture = TEX.dustRing, Color = CS(SLATE), Lifetime = R(0.45), Size = seq(0, 5, 1, 30), Transparency = seq(0, 0.2, 0.7, 0.35, 1, 1), ZOffset = 0.6 })))
		em(g, "Ring", with(FLAT, { Texture = TEX.elecRing, Color = STORM, LightEmission = 1, Brightness = 4, Lifetime = R(0.42), Size = seq(0, 4, 1, 28), Rotation = R(0, 360), RotSpeed = R(-60, 60), Transparency = seq(0, 0, 0.7, 0.15, 1, 1), ZOffset = 0.8 }))
		wave(p, "Flare", MESH.spikeFlare, { from = Vector3.new(5, 4, 5), to = Vector3.new(16, 34, 16), fromOffset = Vector3.new(0, 2, 0), toOffset = Vector3.new(0, 16, 0), duration = 0.32, fromT = 0.5, color = RIM, fade = "Quad" })
		shockRing(p, MESH.bladeRing, 28, 0.03, 0.38)
		flash(att(p, "Up", Vector3.new(0, 5, 0)), "Flash", 12, 0, 0.2)
		crater(g, 15, 24, 5, 0.04)
		em(g, "Forks", with(FLAT, { Texture = TEX.fork, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.2, 0.3), Size = NS(12), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 0.5 }), { EmitCount = 8, EmitDelay = 0.04 })
		chunks(g, 16, R(36, 56), NS(2.4), 0.05)
		dustWall(g, "DustWall", 18, R(64, 82), seq(0, 4, 1, 11), 0.07)
		settle(g, 8, seq(0, 8, 1, 14), 0.3)
		shake(p, "Custom,60~200,3.4,0.8,10,0.02,1;1;1,0.25;0.25;0.25")
	end

	-- BoulderRip (floor at the right fist, 0-600 of the throw windup): the
	-- floor torn open as the rock comes out.
	do
		local p = part(root, "BoulderRip", Vector3.new(6, 1, 6), { AuthoredSeconds = 0.6 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		em(g, "Cracks", with(FLAT, earthy({ Texture = TEX.crackDark, Color = CS(SCORCH), Lifetime = R(3), Size = NS(9), Rotation = R(0, 360), Transparency = seq(0, 0.05, 0.8, 0.1, 1, 1), ZOffset = 0.2 })))
		em(lift(g, 2.2), "Plume", grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Speed = R(8, 14), Drag = 2, Rate = 12, Lifetime = R(0.8, 1.1), Size = seq(0, 3, 1, 6), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitDuration = 0.6 })
		em(p, "Chunks", rocks({ Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Speed = R(16, 24), Acceleration = Vector3.new(0, -100, 0), Rate = 12, Lifetime = R(0.6, 0.9), Size = NS(1), RotSpeed = R(-200, 200) }), { EmitDuration = 0.6 })
	end

	-- BoulderRock (the boulder itself, a stone mesh about 10 studs across).
	do
		local rock = keptRock
		if not rock then
			local ok, made = pcall(function()
				return AssetService:CreateMeshPartAsync("rbxassetid://17608108317")
			end)
			rock = if ok then made else Instance.new("Part")
		end
		rock.Name = "BoulderRock"
		rock.Anchored, rock.CanCollide, rock.CanQuery, rock.CanTouch, rock.CastShadow, rock.Massless = true, false, false, false, true, true
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(86, 82, 78)
		rock.Size = Vector3.new(10, 8.5, 9.5)
		rock.Transparency = 0
		rock:ClearAllChildren()
		rock.Parent = root
	end

	-- BoulderSkin (rides the rock from the rip to the impact): grit falling off
	-- it; the dust Trail is switched on by code at the throw.
	do
		local p = part(root, "BoulderSkin", Vector3.new(9, 9, 9))
		em(p, "Grit", rocks({ Shape = Enum.ParticleEmitterShape.Sphere, Speed = R(1, 4), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -60, 0), Rate = 6, Lifetime = R(0.5, 0.8), Size = NS(0.5), RotSpeed = R(-200, 200) }), {})
		em(p, "Dust", grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Sphere, Speed = R(0, 2), Rate = 5, Lifetime = R(0.6, 0.9), Size = seq(0, 2, 1, 4), Transparency = seq(0, 0.5, 1, 1), Rotation = R(0, 360) })), {})
		local top = att(p, "TrailTop", Vector3.new(0, 3.5, 0))
		local bottom = att(p, "TrailBottom", Vector3.new(0, -3.5, 0))
		local t = Instance.new("Trail")
		t.Name = "DustTrail"
		t.Attachment0, t.Attachment1 = top, bottom
		t.Color = CS(DUST)
		t.LightEmission = 0
		t.LightInfluence = 1
		t.Transparency = seq(0, 0.45, 1, 1)
		t.Lifetime = 0.3
		t.WidthScale = seq(0, 1, 1, 0.2)
		t.FaceCamera = true
		t.Enabled = false
		t.Parent = p
	end

	-- BoulderCharge (the rock, the last 0.25 s before the throw): the ape
	-- charging it with lightning.
	do
		local p = part(root, "BoulderCharge", Vector3.new(10, 9, 10), { AuthoredSeconds = 0.25 })
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 30, Lifetime = R(0.12, 0.2), Size = NS(4), Rotation = R(0, 360), Transparency = FLICK, LockedToPart = true, ZOffset = 2 }), { EmitDuration = 0.25 })
		em(p, "Glint", { Texture = TEX.glint, Color = STORM, LightEmission = 1, Brightness = 4, Lifetime = R(0.2), Size = seq(0, 0, 0.25, 7, 1, 0), LockedToPart = true, ZOffset = 3 }, { EmitCount = 1, EmitDelay = 0.15 })
	end

	-- BoulderShadow (the floor under the flying rock; the runtime sizes it).
	do
		local p = part(root, "BoulderShadow", Vector3.new(4, 0.2, 4))
		em(p, "Shade", with(FLAT, earthy({ Texture = TEX.dot, Color = CS(SCORCH), LightInfluence = 0, Rate = 30, Lifetime = R(0.06), Size = NS(5), Transparency = NS(0.6), LockedToPart = true })), {})
	end

	-- BoulderImpact (where the rock ends, r10): the rock shatters (hero), a
	-- dust burst, its charge discharges, a shock on slate, a crater.
	do
		local p = part(root, "BoulderImpact", Vector3.new(1, 1, 1), { AuthoredRadius = 10 })
		local g = att(p, "Ground", Vector3.new(0, 1.5, 0))
		em(g, "Shatter", rocks({ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Speed = R(30, 50), Acceleration = Vector3.new(0, -120, 0), Lifetime = R(0.8, 1.2), Size = NS(2.1), Rotation = R(0, 360), RotSpeed = R(-260, 260) }), { EmitCount = 16 })
		dustWall(g, "DustBurst", 10, R(18, 28), seq(0, 3.5, 1, 7.5), 0.03)
		flash(att(p, "Up", Vector3.new(0, 3, 0)), "Flash", 8, 0, 0.18)
		em(p, "Discharge", { Texture = TEX.plasma, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.16), Size = seq(0, 5, 1, 8), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 }, { EmitCount = 1, EmitDelay = 0.02 })
		shockRing(p, MESH.swirlRing, 11, 0.02, 0.28)
		em(att(p, "Floor", Vector3.new(0, 0.2, 0)), "Crater", with(FLAT, earthy({ Texture = TEX.crater, Color = CS(WHITE), Lifetime = R(3.5), Size = NS(6), Rotation = R(0, 360), Transparency = seq(0, 0, 0.8, 0, 1, 1), ZOffset = 0.1 })))
		settle(g, 4, seq(0, 5, 1, 8), 0.25)
		shake(p, "Custom,20~90,1.4,0.4,14,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- LanceForm (the right fist, 1.4 s): lightning drawn into the fist, the
	-- javelin growing along the throw, a glint just before it leaves.
	do
		local p = part(root, "LanceForm", Vector3.new(16, 16, 16), { AuthoredSeconds = 1.4 })
		em(p, "Drawn", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = R(14, 22), Rate = 12, Lifetime = R(0.35, 0.45), Size = NS(2.2), Rotation = R(0, 360), LockedToPart = true, ZOffset = 1 }), { EmitDuration = 1.3 })
		em(p, "Core", { Texture = TEX.dot, Color = CS(INDIGO), Lifetime = R(1.4), Size = seq(0, 1.5, 1, 4), Transparency = seq(0, 0.9, 0.8, 0.35, 1, 1), LockedToPart = true, ZOffset = 0.5 })
		local a = att(p, "Javelin", Vector3.new(0, 0, -3))
		em(a, "Javelin", { Texture = TEX.strip, Color = STORM, LightEmission = 1, Brightness = 3, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, Speed = R(0.01), Lifetime = R(1.1), Size = seq(0, 0.5, 0.6, 4, 1, 6.5), Transparency = seq(0, 0.6, 0.6, 0.15, 0.95, 0, 1, 1), LockedToPart = true, ZOffset = 2 }, { EmitCount = 1, EmitDelay = 0.3 })
		em(p, "Glint", { Texture = TEX.glint, Color = STORM, LightEmission = 1, Brightness = 4, Lifetime = R(0.2), Size = seq(0, 0, 0.25, 6, 1, 0), LockedToPart = true, ZOffset = 3 }, { EmitCount = 1, EmitDelay = 1.22 })
	end

	-- LanceBolt (flies with the projectile, -Z = travel): the javelin.
	do
		local p = part(root, "LanceBolt", Vector3.new(1, 1, 1))
		local head = att(p, "Head", CFrame.new(0, 0, -5) * CFrame.Angles(0, 0, math.pi / 2))
		local tail = att(p, "Tail", CFrame.new(0, 0, 9) * CFrame.Angles(0, 0, math.pi / 2))
		for _, b in { { "Dark", INDIGO, 0, 3.2, "", 0.3 }, { "Glow", BRIGHT, 1, 2.6, "", 0.45 }, { "Core", WHITE, 1, 2.2, TEX.strip, 0 } } do
			local beam = Instance.new("Beam")
			beam.Name = b[1]
			beam.Attachment0, beam.Attachment1 = head, tail
			beam.Color = CS(b[2])
			beam.LightEmission = b[3]
			beam.Width0, beam.Width1 = b[4], b[4] * 0.4
			beam.Texture = b[5]
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.Transparency = NS(b[6])
			beam.FaceCamera = true
			beam.Brightness = 3
			beam.Enabled = false
			beam.Parent = p
		end
		trailPair(p, "Trail", 1.6, 0.25)
		em(head, "Head", grid4({ Texture = TEX.flash, Color = STORM, LightEmission = 1, Brightness = 4, Rate = 20, Lifetime = R(0.1), Size = NS(3), LockedToPart = true, ZOffset = 3 }), {})
		em(p, "Shed", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Sphere, Rate = 30, Lifetime = R(0.12, 0.18), Size = NS(2.6), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 1 }), {})
	end

	-- LanceFlash (the fist at the throw, the lance's end): flash and discharge.
	do
		local p = part(root, "LanceFlash", Vector3.new(1, 1, 1))
		flash(p, "Flash", 7, 0, 0.18)
		em(p, "Discharge", { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.2), Size = seq(0, 5, 1, 9), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 })
	end

	-- ScorchSpot (floor under the low-flying lance): the floor burnt.
	do
		local p = part(root, "ScorchSpot", Vector3.new(1, 1, 1))
		em(att(p, "Ground", Vector3.new(0, 0.15, 0)), "Scorch", with(FLAT, earthy({ Texture = TEX.scorch, Color = CS(SCORCH), Lifetime = R(2.4), Size = NS(3), Rotation = R(0, 360), Transparency = seq(0, 0.2, 0.7, 0.3, 1, 1) })))
	end

	-- ChestBeat (ChestBeatL/R): a fist hitting the chest: air thumped
	-- forward, sparks knocked off, a flash.
	do
		local p = part(root, "ChestBeat", Vector3.new(1, 1, 1))
		wave(p, "Thump", MESH.swirlRing, { from = Vector3.new(2, 0.6, 2), to = Vector3.new(11, 1.2, 11), fromOffset = Vector3.new(0, 0, -1), toOffset = Vector3.new(0, 0, -5), rotation = Vector3.new(90, 0, 0), duration = 0.22, fromT = 0.45, fade = "Quint" })
		flash(p, "Flash", 3, 0, 0.12)
		em(p, "Sparks", grid4({ Texture = TEX.zigzag, Color = STORM, LightEmission = 1, Brightness = 3, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(60, 60), Speed = R(20, 30), Drag = 4, Lifetime = R(0.2, 0.3), Size = NS(1.4), Rotation = R(0, 360), ZOffset = 2 }), { EmitCount = 6, EmitDelay = 0.02 })
	end

	-- Inhale (the Mouth, the last 0.45 s of a roar windup): air drawn in.
	do
		local p = part(root, "Inhale", Vector3.new(18, 18, 18), { AuthoredSeconds = 0.45 })
		em(p, "Air", grid4({ Texture = TEX.streaks, Color = CS(RIM), LightEmission = 0.5, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Speed = R(28, 38), Rate = 30, Lifetime = R(0.25, 0.3), Size = NS(2.2), Transparency = seq(0, 1, 0.3, 0.35, 1, 1), LockedToPart = true }), { EmitDuration = 0.4 })
		local a = att(p, "Mouth", Vector3.new(0, 0, -1))
		em(a, "Ring", { Texture = TEX.airRing, Color = CS(RIM), LightEmission = 0.4, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, Speed = R(0.01), Lifetime = R(0.45), Size = seq(0, 9, 1, 1), Transparency = seq(0, 1, 0.4, 0.4, 1, 0.8), LockedToPart = true })
	end

	-- BodyCrackle (the torso, a windup's last part): lightning building over
	-- the body.
	do
		local p = part(root, "BodyCrackle", Vector3.new(14, 10, 10), { AuthoredSeconds = 0.6 })
		em(p, "Arcs", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 18, Lifetime = R(0.18, 0.26), Size = NS(3.6), Rotation = R(0, 360), LockedToPart = true, ZOffset = 1 }), { EmitDuration = 0.6 })
	end

	-- RoarBlast (the Mouth, -Z = the blast, tipped a little down): the sound
	-- cone opens forward out of the mouth over an indigo copy (hero), sound
	-- rings travel out +0/+80/+160, arcs flung out +40.
	do
		local p = part(root, "RoarBlast", Vector3.new(1, 1, 1))
		local cone = { from = Vector3.new(3, 3, 3), to = Vector3.new(24, 26, 24), fromOffset = Vector3.new(0, 0, -2), toOffset = Vector3.new(0, 0, -15), rotation = Vector3.new(-90, 0, 0), duration = 0.45, fade = "Quint" }
		-- air, not a solid: a ForceField shimmer over a faint indigo copy
		wave(p, "ConeDark", MESH.roarCone, with(cone, { from = cone.from * 1.06, to = cone.to * 1.06, material = Enum.Material.SmoothPlastic, color = INDIGO, fromT = 0.72 }))
		wave(p, "Cone", MESH.roarCone, with(cone, { fromT = 0, color = RIM, material = Enum.Material.ForceField }))
		for i, delay in { 0, 0.08, 0.16 } do
			local a = att(p, "Ring" .. i, Vector3.zero)
			em(a, "Sound", { Texture = TEX.soundRing, Color = CS(RIM), LightEmission = 0.7, Brightness = 2, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, Speed = R(46), Drag = 2, Lifetime = R(0.55), Size = seq(0, 3, 1, 16), Rotation = R(0, 360), Transparency = seq(0, 0.1, 0.6, 0.35, 1, 1), ZOffset = 2 }, { EmitCount = 1, EmitDelay = delay })
		end
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 35), Speed = R(34, 48), Drag = 4, Lifetime = R(0.18, 0.26), Size = NS(4), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2.5 }), { EmitCount = 8, EmitDelay = 0.04 })
		shake(p, "Custom,40~160,1.8,0.6,10,0.04,1;1;1,0.12;0.12;0.12")
	end

	-- RoarGround (the floor under the mouth, r42 = the stun radius): the
	-- blast shoving air along the ground, kicking dust out to the radius.
	do
		local p = part(root, "RoarGround", Vector3.new(1, 1, 1), { AuthoredRadius = 42 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		em(g, "DustRing", with(FLAT, earthy({ Texture = TEX.dustRing, Color = CS(Color3.fromRGB(96, 90, 82)), Lifetime = R(0.6), Size = seq(0, 6, 1, 42), Rotation = R(0, 360), Transparency = seq(0, 0.15, 0.7, 0.45, 1, 1), ZOffset = 0.5 })), { EmitCount = 1, EmitDelay = 0.12 })
		local dust = dustWall(g, "Dust", 18, R(95, 115), seq(0, 3, 1, 8), 0.12, R(0.75, 0.95))
		dust.Drag = 2.5
	end

	-- StormRaise (BackTop, storm call windup): lightning climbing off the back
	-- into the sky.
	do
		local p = part(root, "StormRaise", Vector3.new(10, 4, 8), { AuthoredSeconds = 1.2 })
		em(p, "Arcs", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(14, 24), Rate = 12, Lifetime = R(0.25, 0.35), Size = NS(3.4), Rotation = R(0, 360), ZOffset = 1 }), { EmitDuration = 1.2 })
	end

	-- BoltGather (30 studs over a bolt's point, its 0.9 s warning): the
	-- strike's cloud, flickering from 55%.
	do
		local p = part(root, "BoltGather", Vector3.new(10, 2, 10), { AuthoredSeconds = 0.9 })
		em(p, "Cloud", { Texture = TEX.cloud, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = CS(INDIGO), LightEmission = 0, LightInfluence = 0.3, Shape = Enum.ParticleEmitterShape.Box, Speed = R(0.5, 1.5), Rate = 5, Lifetime = R(0.9, 1.1), Size = seq(0, 4, 1, 7), Transparency = seq(0, 1, 0.3, 0.25, 0.8, 0.35, 1, 1), Rotation = R(0, 360) }, { EmitDuration = 0.7 })
		em(p, "Flicker", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, Rate = 9, Lifetime = R(0.15, 0.22), Size = NS(3.5), Rotation = R(0, 360), ZOffset = 1 }), { EmitDelay = 0.5, EmitDuration = 0.4 })
	end

	-- BoltStrike (floor where a bolt lands, r8; the bolt beam is code):
	-- flash, a discharge spreading on the floor, scorch, sparks, dust.
	do
		local p = part(root, "BoltStrike", Vector3.new(1, 1, 1), { AuthoredRadius = 8 })
		local g = att(p, "Ground", Vector3.new(0, 0.2, 0))
		flash(att(p, "Up", Vector3.new(0, 2, 0)), "Flash", 7, 0, 0.16)
		em(g, "Discharge", with(FLAT, { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.25), Size = seq(0, 6, 1, 9), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 0.5 }))
		em(g, "Scorch", with(FLAT, earthy({ Texture = TEX.scorch, Color = CS(SCORCH), Lifetime = R(3), Size = NS(5), Rotation = R(0, 360), Transparency = seq(0, 0.1, 0.75, 0.25, 1, 1), ZOffset = 0.2 })))
		em(g, "Sparks", grid4({ Texture = TEX.zigzag, Color = STORM, LightEmission = 1, Brightness = 3, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(22, 34), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.25, 0.35), Size = NS(1.3), Rotation = R(0, 360), ZOffset = 1 }), { EmitCount = 7, EmitDelay = 0.03 })
		dustWall(g, "Dust", 5, R(12, 18), seq(0, 2, 1, 4.5), 0.05, R(0.6, 0.8))
		shake(p, "Custom,10~70,0.9,0.25,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- Bolt (beam pieces for the code bolts: an indigo edge, a glow, the
	-- electric strip core).
	do
		local p = part(root, "Bolt", Vector3.new(1, 1, 1))
		local a, b = att(p, "Arc", Vector3.zero), att(p, "B", Vector3.new(0, 5, 0))
		for _, spec in { { "Dark", INDIGO, 0, "" }, { "Glow", BRIGHT, 1, "" }, { "Core", WHITE, 1, TEX.strip } } do
			local beam = Instance.new("Beam")
			beam.Name = spec[1]
			beam.Attachment0, beam.Attachment1 = a, b
			beam.Color = CS(spec[2])
			beam.LightEmission = spec[3]
			beam.Texture = spec[4]
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.FaceCamera = true
			beam.Brightness = 3
			beam.Enabled = false
			beam.Parent = p
		end
	end

	-- PhaseSurge (Core): the storm in the body surging out.
	do
		local p = part(root, "PhaseSurge", Vector3.new(16, 16, 16))
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, Speed = R(18, 28), Drag = 3, Lifetime = R(0.2, 0.3), Size = NS(6), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 }), { EmitCount = 14 })
		em(p, "Discharge", { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.22), Size = seq(0, 10, 1, 18), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2.5 }, { EmitCount = 1, EmitDelay = 0.02 })
		flash(p, "Flash", 14, 0, 0.22)
		wave(p, "Air", MESH.swirlRing, { from = Vector3.new(10, 2, 10), to = Vector3.new(60, 4, 60), duration = 0.42, fromT = 0.65, delay = 0.03, fade = "Quint" })
		shake(p, "Custom,40~160,1.6,0.5,12,0.03,1;1;1,0.1;0.1;0.1")
	end

	-- HitStorm / HitHeavy (the struck player's near side): the blow landing.
	do
		local p = part(root, "HitStorm", Vector3.new(1, 1, 1))
		em(p, "Discharge", { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.18), Size = seq(0, 2.5, 1, 4.5), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 3 })
		flash(p, "Flash", 2.6, 0, 0.14)
		em(p, "Sparks", grid4({ Texture = TEX.zigzag, Color = STORM, LightEmission = 1, Brightness = 3, EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(60, 60), Speed = R(16, 26), Drag = 4, Lifetime = R(0.18, 0.26), Size = NS(0.9), Rotation = R(0, 360), ZOffset = 3 }), { EmitCount = 5, EmitDelay = 0.02 })
	end
	do
		local p = part(root, "HitHeavy", Vector3.new(1, 1, 1))
		em(p, "Discharge", { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.2), Size = seq(0, 3.5, 1, 6), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 3 })
		flash(p, "Flash", 3.6, 0, 0.16)
		em(p, "Dust", grid4(earthy({ Texture = TEX.dust, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(50, 50), Speed = R(10, 16), Drag = 4, Lifetime = R(0.5, 0.7), Size = seq(0, 1.5, 1, 3.5), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 4, EmitDelay = 0.03 })
		em(p, "Chunks", rocks({ EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(50, 50), Speed = R(18, 26), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.5, 0.7), Size = NS(0.5), RotSpeed = R(-200, 200) }), { EmitCount = 4, EmitDelay = 0.02 })
	end
	do
		local p = part(root, "StunArcs", Vector3.new(3, 5, 2), { AuthoredSeconds = 1.0 })
		em(p, "Arcs", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, Rate = 12, Lifetime = R(0.16, 0.22), Size = NS(1.4), Rotation = R(0, 360), LockedToPart = true, ZOffset = 3 }), { EmitDuration = 1.0 })
	end

	-- StaggerPop (Core): qi knocked out of the chest.
	do
		local p = part(root, "StaggerPop", Vector3.new(6, 6, 3))
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(60, 60), Speed = R(18, 26), Drag = 4, Lifetime = R(0.18, 0.26), Size = NS(3.4), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2 }), { EmitCount = 7 })
		flash(p, "Flash", 6, 0, 0.14)
	end

	-- DeathLeak (the body box, 3 s; rates ramped by code): the storm leaking.
	do
		local p = part(root, "DeathLeak", Vector3.new(12, 14, 12), { AuthoredSeconds = 3.0 })
		em(p, "Arcs", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 8, Lifetime = R(0.2, 0.28), Size = NS(3.6), Rotation = R(0, 360), ZOffset = 1 }), { EmitDuration = 3.0 })
		em(p, "Bold", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 3, Lifetime = R(0.14, 0.2), Size = NS(5), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 1.5 }), { EmitDuration = 3.0 })
	end

	-- DeathRelease (the chest, at 3.05 s): the last of the storm leaving
	-- upward: the twister rises (hero), flash, discharge, arcs rising.
	do
		local p = part(root, "DeathRelease", Vector3.new(10, 6, 10))
		wave(p, "Twister", MESH.twister, { from = Vector3.new(8, 10, 8), to = Vector3.new(22, 70, 22), fromOffset = Vector3.new(0, 2, 0), toOffset = Vector3.new(0, 34, 0), duration = 0.9, style = "Quint", fromT = 0, color = RIM, material = Enum.Material.ForceField, fade = "Quad" })
		flash(p, "Flash", 20, 0, 0.26)
		em(p, "Discharge", { Texture = TEX.discharge, Color = STORM, LightEmission = 1, Brightness = 3, Lifetime = R(0.28), Size = seq(0, 12, 1, 22), Rotation = R(0, 360), Transparency = FLICK, ZOffset = 2.5 }, { EmitCount = 1, EmitDelay = 0.02 })
		em(p, "Rising", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15), Speed = R(25, 45), Drag = 1, Lifetime = R(0.5, 0.9), Size = NS(4), Rotation = R(0, 360), ZOffset = 1 }), { EmitCount = 14, EmitDelay = 0.05 })
		shake(p, "Custom,40~180,1.8,0.7,10,0.03,1;1;1,0.12;0.12;0.12")
	end
	do
		local p = part(root, "DeathGround", Vector3.new(1, 1, 1), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.3, 0))
		shockRing(p, MESH.swirlRing, 14, 0.04, 0.4)
		dustWall(g, "Dust", 12, R(26, 36), seq(0, 3.5, 1, 8), 0.06)
	end

	-- Aura (mounted on the body, always on, light): arcs crawling on the
	-- forearms, storm wisps hanging on the shoulders and back; phase 2+ adds
	-- bold arcs on the fists and shoulders.
	do
		local p = part(root, "AuraForearm", Vector3.new(1, 1, 1))
		em(p, "Arcs", grid4({ Texture = TEX.arcs, Color = STORM, LightEmission = 1, Brightness = 2.5, Shape = Enum.ParticleEmitterShape.Sphere, Rate = 1.4, Lifetime = R(0.2, 0.26), Size = NS(1.8), Rotation = R(0, 360), LockedToPart = true, ZOffset = 1 }), {})
	end
	do
		local p = part(root, "AuraCloud", Vector3.new(1, 1, 1))
		em(p, "Wisp", { Texture = TEX.cloud, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Color = CS(INDIGO), LightEmission = 0, LightInfluence = 0.4, Shape = Enum.ParticleEmitterShape.Sphere, EmissionDirection = Enum.NormalId.Top, Speed = R(1, 2.5), Rate = 0.8, Lifetime = R(2, 2.8), Size = seq(0, 2, 1, 4.5), Transparency = seq(0, 1, 0.25, 0.55, 1, 1), Rotation = R(0, 360), RotSpeed = R(-12, 12) }, {})
	end
	do
		local p = part(root, "AuraArcs", Vector3.new(1, 1, 1))
		em(p, "Arcs", grid2({ Texture = TEX.arcsBold, Color = STORM, LightEmission = 1, Brightness = 3, Shape = Enum.ParticleEmitterShape.Sphere, Rate = 2, Lifetime = R(0.1, 0.16), Size = NS(2.2), Rotation = R(0, 360), Transparency = FLICK, LockedToPart = true, ZOffset = 1.5 }), {})
	end

	root.Parent = effects
	return root
end

return true
