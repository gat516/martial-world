--!nocheck
-- Builder for ReplicatedStorage.Effects.ElderWolfKing: the Elder Wolf King's
-- attack, hit, phase, roar, aura and death effects (boss, Qi Condensation 9).
-- Load through the receiver, then build into the Effects folder:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/ElderWolfKing.luau")
--   require(m)  -- installs _G.buildElderWolfKingFX(effectsFolder)
-- Runtime: src/client/EnemyFX/ElderWolfKing.luau (cue -> template, placement,
-- sounds). Sounds: SoundService.SFX.Enemies.ElderWolfKing.<Name>.
--
-- Rebuilt 2026-10-22 with the intent-first method (.claude/agents/vfx.md):
-- every layer is caused by the body doing the move, one hero per beat, starts
-- staggered behind their cause, assets found by searching for what the action
-- causes (air, dust, debris, light) rather than its name.
--
-- Palette: moon-silver qi (white core, #E2ECFA falloff, #96B2DE rim) over
-- ink and slate; the King's gold only in the eye/claw tells (the first frame
-- of every move); warm grey dust and slate debris for the ground. The
-- telegraph keeps the danger orange; nothing here redraws the danger area
-- (the old gold ground Marker and formation arrays were cut: they doubled
-- the telegraph and had no cause in the body).
--
-- INTENTS (what happens / what the player feels / gameplay job)
-- Royal Bite: the King draws breath, bares its fangs and snaps its jaws shut on
--   the space in front / a crunch you saw coming / telegraph + hit confirm.
-- Paw Swipe: a quick foreleg sweep raking the cone / a sharp check / short
--   telegraph (loud first frame) + hit confirm.
-- Claw Down: the right forepaw rises and is driven into the ground / a punch
--   into the floor / telegraph on the paw, impact on the circle.
-- Crownfall: the King rears and slams both forepaws down, its biggest blow /
--   dread, then weight / long readable gather, heavy impact.
-- King's Rush: the King coils on its hind legs and bursts forward through the
--   air / momentum / the coil warns, the trail shows the lane being run.
-- King's Leap: crouch, a launch, a whole-body landing / mass falling on you.
-- King's Rake: both forepaws rake across the arrival cone.
-- Engage roar: a blast of air and sound from the mouth / dread / the stagger.
-- Pack Call: the King howls to the sky to call its spirit wolves / the fight
--   escalating / the stun ring and a phase marker.
-- Death: the King's qi leaks from the body, then its spirit breaks free
--   upward / release, reward.
--
-- BEAT SHEET (ms from the cue; contact = windup end, server timings)
-- | Move | Anticipation | Peak | Follow-through / dissipation |
-- | every windup | 0-350 EyeGlint (gold glint on both eyes) | - | - |
-- | Royal Bite 900 | 100-750 breath drawn in, 0-900 maw glow swells, 650-900 fang glints | 900 jaws slam shut (hero), +30 air shock forward, +50 spray | to 1300 shock and spray fade |
-- | Paw Swipe 450 | 0-220 star on the paw (loud: short tell), 0-450 gold claws | 450 swoosh across the front (hero), +20 claw rake, +50 wind, +60 grit | to 900 |
-- | Claw Down 550 | 275-550 paw raised: star, gold claws | 550 lit gouge carved (hero), flash, +30 ground shock, +30 chips, +50 dust | lit gouge cools by 1450, carved gouge fades by 3550 |
-- | Crownfall 1250 | 0 rising charge sound; 100-1100 moon motes and air pulled into both forepaws, glow accelerating; 1000-1250 qi flames on the claws (dodge now) | 1250 ground shockwave ring (hero) on a slate ring, flash, crater, Craters rocks; +30 pebbles, +60 dust wall | +150 rumble; dust settles to 3500; crater fades by 7250 |
-- | King's Rush 1000 (+ dash <=600) | 300-1000 hind claws dig: dust and grit kicked back | take-off: dust burst behind, flat shock; dash: air rings peel off the muzzle (hero), speed lines, ink and moon ribbons, floor wake | stop: Skid dust from the forepaws |
-- | King's Leap 1100 (+700 flight) | crouch: hind claws dig (Coil), forepaws gather (CrownfallTell refit) | take-off as the rush; landing: dust cloud bursting round the body (hero), shock ring on slate, flash, Craters ring, pebbles | dust settles to 2500 |
-- | King's Rake 500 | both forepaws' tells | two swooshes, L then R +80 | - |
-- | Engage roar 1000 | 150-850 breath drawn in hard, maw glow | 1000 three sound rings leave the mouth (hero, +0/+80/+160), +40 air swirl, +50 wind lines, +120 dust shoved out along the ground | to 1600 |
-- | Pack Call 1200 | breath in, spirit motes rise in a ring round the King | 1200 sound rings rise skyward (hero), mane flames flare, +60 air shock over the stun radius with a dust skirt | aura stays flared 3 s |
-- | Hits | - | claw marks / jaws / star + ring on the struck player | 200-350 |
-- | Stagger | - | qi knocked out of the chest | 300 |
-- | Death | 0-850 qi leaks off the body as motes and guttering flames | 850 spirit column twists up (hero), spirit flames, flash, ground shock, dust | motes rise to ~3500 |
--
-- LAYER SHEET (role: cause -> asset and why)
-- EyeGlint   secondary: the King's intent on the first frame of every move -> star-twinkle flipbook 102648375149008 (4x4, opens and closes), lens streak 14684195806
-- BiteTell   secondary: breath drawn into the jaws -> air-swoosh flipbook 12094495797 (4x4) inward; core glow 9841273544 on an ink dot (core only); fang glints 102648375149008
-- BiteSnap   HERO: the jaws closing -> crescent 103025166028878 (it carries its own dark rim) top and bottom, on slate copies; secondary: air shoved forward -> swirl ring mesh 136611516099795; tertiary spray 12094495797; core flash 9841273544
-- SwipeTell  secondary: claws bared -> star-burst flipbook 13580358178, three-spike claw 11636552631 (round 1 replaced the faint three-line 7216852545) over an ink copy
-- SwipeSlash HERO: the foreleg sweeping the cone -> brushed crescent 109919844196737 sweeping across over a slate copy (round 1 cut the swoosh mesh 114284374487407: a radial pinwheel with no direction); secondary claw rake 11636552631; tertiary wind 12094495797, grit flipbook 12360899465 (4x4 dust puff opening into a ring)
-- ClawRaise  secondary: the lifted paw -> 13580358178, 11636552631 (+ ink)
-- ClawStrike HERO: three claws driven into the ground -> 11636552631 laid flat, carved (ink) with moon qi burning in it; secondary flash 13580358178, ground shock mesh 99300490107593; tertiary pebbles 7216855695, dust 12360899465
-- CrownfallTell secondary: qi gathered into the forepaws as the King rears -> twinkle 102648375149008 and air 12094495797 inward, glow 9841273544 on ink, spirit-flame flipbook 81332883799807 (2x2) on the claws in the last 250 ms
-- CrownfallImpact HERO: both forepaws hitting the ground -> swirl shock ring mesh 107535935776160 over a slate copy; secondary flash 13580358178, carved crater 90713203428310 with a lit crack 97725700315217 cooling, Craters rocks; tertiary pebbles 7216855695, dust wall 12360899465; environment settling smoke 17703378809 (4x4 rising smoke)
-- Coil       secondary: hind claws digging in to load the spring -> 12360899465 kicked back, pebbles 7216855695
-- Launch     HERO (take-off): hind legs driving off the ground -> dust burst 12360899465; secondary shock mesh 99300490107593; pebbles 7216855695
-- RushTrail  HERO (dash): the body tearing through the air -> thin ring 16878073342 peeling off the muzzle; speed lines 5699911427; ink and moon ribbons (Trails); wake dust 12360899465
-- Skid       secondary: paws ploughing the ground -> 12360899465, 7216855695
-- LeapImpact HERO: the whole body landing -> dust cloud 12360899465 bursting round it; secondary shock ring mesh 100253569158780 on a slate copy, flash 13580358178, Craters rocks; tertiary pebbles
-- RoarTell   secondary: breath drawn in -> 12094495797 inward; maw glow
-- RoarBlast  HERO: sound and air leaving the mouth -> three swirl ring meshes 136611516099795 travelling out; secondary air swirl 99001875893540 (facing the blast), wind lines 13546935092; environment RoarGround: dust shoved along the floor 12360899465
-- HowlTell / HowlGather  secondary: the pack's spirit drawn in -> 12094495797 inward, motes 102648375149008 rising in a ring
-- HowlBlast  HERO: the howl going skyward -> 136611516099795 rings on a raised axis; ManeFlare 81332883799807 (the aura flaring with the call); HowlGround shock 107535935776160 over the stun radius + dust skirt
-- HitClaw/HitBite/HitHeavy: the blow landing on a player -> 11636552631 / 103025166028878 / 13580358178 + ring mesh 136611516099795 + dust
-- Stagger    qi knocked out of the chest -> 12094495797 burst, 13580358178
-- DeathLeak  the King's qi leaving the dying body -> 102648375149008 motes, 81332883799807 guttering flames
-- DeathRelease HERO: the spirit breaking free -> twisting column mesh 112724324039362 rising; spirit flames 81332883799807; secondary flash 13580358178, ground shock 107535935776160; tertiary dust 12360899465, rising motes 102648375149008
-- AuraMane / AuraBreath  always on, light: spirit flames 81332883799807 off the mane, motes 102648375149008, embers below 70% health (dot), breath mist 11037785676
--
-- Every template is an invisible anchored Part (centre = pivot, -Z = facing
-- or blow direction). Ground templates have their centre on the floor and an
-- AuthoredRadius; held tells carry AuthoredSeconds. MeshWave models
-- (TechniqueVFX.playWaves) are the 3D shock rings; their sizes are studs and
-- the runtime scales them with the template. Particle Size here is a radius
-- (half-width), authored directly.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local AssetService = game:GetService("AssetService")
local function id(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local MOON = Color3.fromRGB(226, 236, 250)
local RIM = Color3.fromRGB(150, 178, 222)
local GOLD = Color3.fromRGB(255, 200, 96)
local INK = Color3.fromRGB(16, 18, 26)
local SLATE = Color3.fromRGB(40, 46, 60)
local DUST = Color3.fromRGB(128, 120, 108)

local TEX = {
	twinkle = id(102648375149008), -- 4x4 flipbook: a 4-point star opening and closing
	lensStreak = id(14684195806),
	airWisps = id(12094495797), -- 4x4 flipbook: small curved air swooshes
	dot = id(9841273544), -- cores only
	jaw = id(103025166028878), -- crescent with its own dark rim
	starBurst = id(13580358178), -- 4x4 flipbook: star burst opening and breaking up
	claw = id(11636552631), -- three bold spikes: claw gouges
	crescent = id(109919844196737), -- brushed crescent stroke
	dustPuff = id(12360899465), -- 4x4 flipbook: a puff opening into a ring, breaking up
	pebbles = id(7216855695),
	spiritFlame = id(81332883799807), -- 2x2 flipbook: spiky aura flame
	crater = id(90713203428310), -- carved crater ring, dark rim
	crackLit = id(97725700315217), -- white crack lines
	risingSmoke = id(17703378809), -- 4x4 flipbook: smoke column rising
	thinRing = id(16878073342), -- thin wobbly ring
	speedLines = id(5699911427),
	airSwirl = id(99001875893540),
	windLines = id(13546935092),
	mist = id(11037785676),
}
local MESH = {
	soundRing = id(136611516099795), -- swirl ring, 2.24 x 0.56 x 2.28
	shockSwirl = id(107535935776160), -- swirl ring, 2.29 x 0.48 x 2.45
	shockFlat = id(99300490107593), -- swirl ring, 2.29 x 0.48 x 2.40
	landRing = id(100253569158780), -- swirl ring, 2.39 x 0.48 x 2.43
	column = id(112724324039362), -- twisting column, 1.62 x 2.83 x 1.58
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
local function grid4(extra)
	return with({ FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot }, extra)
end
local function grid2(extra)
	return with({ FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.OneShot }, extra)
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

-- dust and debris: lit by the world, not glowing
local function earthy(props)
	return with({ LightEmission = 0, LightInfluence = 1 }, props)
end
-- dust puffs (the dustPuff flipbook starts as a small blob, so it is authored
-- big and holds its opacity, then breaks up)
local DUSTFADE = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) })

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
	m.Color = p.color or MOON
	m.Transparency = 1
	m.Parent = w
	w.Parent = parent
	return w
end

-- a screen shake through the plugin's ScreenEffects (its own attachment)
local function shake(parent, csv)
	local a = att(parent, "Shake")
	a:SetAttribute("CameraShake", csv)
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
local GOLDEN = CS({ CK(0, WHITE), CK(0.45, GOLD), CK(1, GOLD) })
local MOONLIT = CS({ CK(0, WHITE), CK(0.5, MOON), CK(1, RIM) })

function _G.buildElderWolfKingFX(effects)
	local old = effects:FindFirstChild("ElderWolfKing")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ElderWolfKing"

	-- EyeGlint (each eye, 0-350 of every windup): the King's intent.
	do
		local p = part(root, "EyeGlint", nil, { AuthoredSeconds = 0.6 })
		em(p, "Twinkle", grid4({ Texture = TEX.twinkle, Color = GOLDEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.35), Size = NS(1.1), ZOffset = 2 }))
		em(p, "Streak", { Texture = TEX.lensStreak, Color = GOLDEN, LightEmission = 1, Brightness = 3, Lifetime = R(0.28), Size = seq(0, 0.4, 0.3, 2.4, 1, 0), ZOffset = 1.8 })
	end

	-- BiteTell (the Mouth, 900): breath pulled into the jaws, the maw
	-- glowing harder toward the snap, fang glints in the last 250 ms.
	do
		local p = part(root, "BiteTell", Vector3.new(9, 9, 9), { AuthoredSeconds = 0.9 })
		em(p, "Inhale", grid4({ Texture = TEX.airWisps, Color = CS(MOON), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 16, Lifetime = R(0.3, 0.4), Speed = R(14, 20), Size = seq(0, 1.3, 1, 0.5), Transparency = seq(0, 1, 0.25, 0.35, 1, 1), Rotation = R(0, 360), LockedToPart = true }), { EmitDelay = 0.1, EmitDuration = 0.65 })
		em(p, "MawDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(0.9), Size = seq(0, 0.4, 1, 1.6), Transparency = seq(0, 0.85, 0.8, 0.45, 1, 1), LockedToPart = true, ZOffset = 0.5 })
		em(p, "MawGlow", { Texture = TEX.dot, Color = MOONLIT, LightEmission = 1, Brightness = 2, Lifetime = R(0.9), Size = seq(0, 0.15, 0.7, 0.45, 1, 1.1), Transparency = seq(0, 0.9, 0.7, 0.45, 0.95, 0.1, 1, 1), LockedToPart = true, ZOffset = 1 })
		for _, a in { att(p, "Top", Vector3.new(0, 1.3, -0.4)), att(p, "Bottom", Vector3.new(0, -1.3, -0.4)) } do
			em(a, "Fang", grid4({ Texture = TEX.twinkle, Color = GOLDEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.25), Size = NS(1.2), ZOffset = 2, LockedToPart = true }), { EmitDelay = 0.65 })
		end
	end

	-- BiteSnap (the Mouth, contact): the jaws slam shut (hero), the air in
	-- front is shoved out (+30), spray thrown forward (+50).
	do
		local p = part(root, "BiteSnap", Vector3.new(0.4, 0.4, 0.4))
		local jaw = { Texture = TEX.jaw, Lifetime = R(0.16), Speed = R(36), Drag = 14, Size = seq(0, 3.6, 1, 4.4) }
		for _, side in { { "Upper", 3.2, 180, Enum.NormalId.Bottom }, { "Lower", -3.2, 0, Enum.NormalId.Top } } do
			local a = att(p, side[1], Vector3.new(0, side[2], -0.6))
			em(a, side[1] .. "Dark", with(jaw, { Color = CS(SLATE), Rotation = R(side[3]), EmissionDirection = side[4], Size = seq(0, 4.2, 1, 5), Transparency = seq(0, 0.15, 0.6, 0.3, 1, 1), ZOffset = 0.5 }))
			em(a, side[1], with(jaw, { Color = MOONLIT, LightEmission = 0.9, Brightness = 2.5, Rotation = R(side[3]), EmissionDirection = side[4], Transparency = seq(0, 0, 0.55, 0.1, 1, 1), ZOffset = 1.5 }))
		end
		em(p, "Flash", { Texture = TEX.dot, Color = CS(WHITE), LightEmission = 1, Brightness = 5, Lifetime = R(0.07), Size = seq(0, 2, 1, 3.2), Transparency = POP, ZOffset = 3 })
		wave(p, "AirShock", MESH.soundRing, { from = Vector3.new(1.2, 0.3, 1.2), to = Vector3.new(9, 0.9, 9), fromOffset = Vector3.new(0, 0, -1), toOffset = Vector3.new(0, 0, -7), rotation = Vector3.new(90, 0, 0), fromT = 0.35, duration = 0.24, delay = 0.03 })
		em(p, "Spray", grid4({ Texture = TEX.airWisps, Color = CS(MOON), LightEmission = 0.7, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(35, 35), Speed = R(25, 40), Drag = 6, Lifetime = R(0.25, 0.35), Size = NS(1.2), Rotation = R(0, 360) }), { EmitCount = 6, EmitDelay = 0.05 })
		shake(p, "Custom,25~90,0.8,0.3,18,0.02,1;1;1,0.05;0.05;0.05")
	end

	-- SwipeTell (left forepaw, 450): the shortest tell, so the loudest at its
	-- first frame: a star on the paw, gold claws bared over ink.
	do
		local p = part(root, "SwipeTell", nil, { AuthoredSeconds = 0.45 })
		em(p, "Star", grid4({ Texture = TEX.starBurst, Color = GOLDEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.22), Size = NS(2.4), ZOffset = 3 }))
		em(p, "ClawsDark", { Texture = TEX.claw, Color = CS(INK), Lifetime = R(0.45), Size = seq(0, 2.4, 1, 3), Rotation = R(-20), Transparency = seq(0, 1, 0.15, 0.3, 0.85, 0.4, 1, 1), LockedToPart = true, ZOffset = 1 })
		em(p, "Claws", { Texture = TEX.claw, Color = GOLDEN, LightEmission = 1, Brightness = 2, Lifetime = R(0.45), Size = seq(0, 2.1, 1, 2.6), Rotation = R(-20), Transparency = seq(0, 1, 0.15, 0.05, 0.85, 0.15, 1, 1), LockedToPart = true, ZOffset = 2 })
	end

	-- SwipeSlash (in front of the chest, 3 up, facing): the foreleg sweeps the
	-- cone: a flat swoosh fans out (hero) over a slate copy, the claw rake
	-- crosses it (+20), wind shed off the arc (+50), grit off the floor (+60).
	do
		local p = part(root, "SwipeSlash", Vector3.new(0.4, 0.4, 0.4))
		local arc = { Texture = TEX.crescent, EmissionDirection = Enum.NormalId.Right, Speed = R(30), Drag = 7, Lifetime = R(0.22), Rotation = R(-70), RotSpeed = R(260) }
		em(p, "SweepDark", with(arc, { Color = CS(SLATE), Size = seq(0, 6.5, 1, 8.5), Transparency = seq(0, 0.15, 0.6, 0.3, 1, 1), ZOffset = 0.5 }))
		em(p, "Sweep", with(arc, { Color = MOONLIT, LightEmission = 1, Brightness = 2.5, Size = seq(0, 6, 1, 8), Transparency = seq(0, 0, 0.6, 0.1, 1, 1), ZOffset = 1.5 }))
		em(p, "ClawsDark", { Texture = TEX.claw, Color = CS(SLATE), EmissionDirection = Enum.NormalId.Right, Speed = R(30), Drag = 8, Lifetime = R(0.18), Size = seq(0, 3.6, 1, 4.2), Rotation = R(-60), Transparency = seq(0, 0.1, 0.6, 0.3, 1, 1), ZOffset = 1.8 }, { EmitDelay = 0.02 })
		em(p, "Claws", { Texture = TEX.claw, Color = MOONLIT, LightEmission = 1, Brightness = 2, EmissionDirection = Enum.NormalId.Right, Speed = R(30), Drag = 8, Lifetime = R(0.18), Size = seq(0, 3.2, 1, 3.8), Rotation = R(-60), Transparency = seq(0, 0, 0.6, 0.15, 1, 1), ZOffset = 2 }, { EmitDelay = 0.02 })
		em(p, "Wind", grid4({ Texture = TEX.airWisps, Color = CS(MOON), LightEmission = 0.6, EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(15, 30), Speed = R(30, 45), Drag = 5, Lifetime = R(0.3), Size = NS(1.5), Rotation = R(0, 360) }), { EmitCount = 6, EmitDelay = 0.05 })
		local g = att(p, "Ground", Vector3.new(0, -2.9, 0))
		em(g, "Grit", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(20, 20), Speed = R(6, 10), Drag = 3, Lifetime = R(0.5, 0.7), Size = seq(0, 2.6, 1, 4.2), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 3, EmitDelay = 0.06 })
	end

	-- ClawRaise (right forepaw, from 50% of the 550 windup): the lifted claws.
	do
		local p = part(root, "ClawRaise", nil, { AuthoredSeconds = 0.25 })
		em(p, "Star", grid4({ Texture = TEX.starBurst, Color = GOLDEN, LightEmission = 1, Brightness = 4, Lifetime = R(0.22), Size = NS(2.2), ZOffset = 3 }))
		em(p, "ClawsDark", { Texture = TEX.claw, Color = CS(INK), Lifetime = R(0.27), Size = seq(0, 2.6, 1, 3.2), Transparency = seq(0, 1, 0.2, 0.3, 0.85, 0.4, 1, 1), LockedToPart = true, ZOffset = 1 })
		em(p, "Claws", { Texture = TEX.claw, Color = GOLDEN, LightEmission = 1, Brightness = 2, Lifetime = R(0.27), Size = seq(0, 2.3, 1, 2.8), Transparency = seq(0, 1, 0.2, 0.05, 0.85, 0.15, 1, 1), LockedToPart = true, ZOffset = 2 })
	end

	-- ClawStrike (centre of the locked circle, authored r4.5): three claws
	-- carved into the ground with qi burning in the gouge (hero), flash, a
	-- ground shock (+30), pebbles (+30), dust (+50).
	do
		local p = part(root, "ClawStrike", Vector3.new(9, 0.2, 9), { AuthoredRadius = 4.5 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		em(g, "Gouge", with(FLAT, { Texture = TEX.claw, Color = CS(INK), Lifetime = R(3), Size = NS(4.6), Rotation = R(-35), Transparency = seq(0, 0.05, 0.6, 0.15, 1, 1), ZOffset = 0.2 }))
		em(g, "GougeLit", with(FLAT, { Texture = TEX.claw, Color = MOONLIT, LightEmission = 1, Brightness = 2.5, Lifetime = R(0.9), Size = NS(3.9), Rotation = R(-35), Transparency = seq(0, 0, 0.3, 0.1, 1, 1), ZOffset = 0.5 }))
		em(g, "Flash", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.15), Size = NS(3.6), ZOffset = 3 }))
		wave(g, "Shock", MESH.shockFlat, { from = Vector3.new(1.5, 0.3, 1.5), to = Vector3.new(12, 0.7, 12), fromOffset = Vector3.new(0, 0.1, 0), toOffset = Vector3.new(0, 0.1, 0), fromT = 0.5, duration = 0.3, delay = 0.03 })
		em(g, "Pebbles", earthy({ Texture = TEX.pebbles, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Speed = R(14, 24), Acceleration = Vector3.new(0, -70, 0), Lifetime = R(0.6, 0.9), Size = NS(0.6), RotSpeed = R(-300, 300), Rotation = R(0, 360) }), { EmitCount = 6, EmitDelay = 0.03 })
		em(g, "Dust", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, Speed = R(1, 3), Lifetime = R(0.6, 0.7), Size = seq(0, 4.8, 1, 7.4), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 2, EmitDelay = 0.05 })
		shake(p, "Custom,25~90,1.2,0.45,16,0.02,1;1;1,0.06;0.06;0.06")
	end

	-- CrownfallTell (each forepaw, 1250): the King rears and pulls qi and air
	-- into its claws; the glow accelerates; qi flames lick the claws in the
	-- last 250 ms (dodge now).
	do
		local p = part(root, "CrownfallTell", Vector3.new(10, 10, 10), { AuthoredSeconds = 1.25 })
		em(p, "Gather", grid4({ Texture = TEX.twinkle, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 18, Lifetime = R(0.35, 0.5), Speed = R(12, 18), Size = seq(0, 0.6, 1, 0.15), Transparency = seq(0, 1, 0.2, 0.1, 1, 0.6), LockedToPart = true }), { EmitDelay = 0.1, EmitDuration = 1.0 })
		em(p, "Pull", grid4({ Texture = TEX.airWisps, Color = CS(MOON), LightEmission = 0.5, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = 8, Lifetime = R(0.35, 0.45), Speed = R(14, 20), Size = seq(0, 1.5, 1, 0.6), Transparency = seq(0, 1, 0.3, 0.4, 1, 1), Rotation = R(0, 360), LockedToPart = true }), { EmitDelay = 0.3, EmitDuration = 0.8 })
		em(p, "GlowDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(1.25), Size = seq(0, 0.4, 1, 2.2), Transparency = seq(0, 0.9, 0.85, 0.45, 1, 1), LockedToPart = true, ZOffset = 0.5 })
		em(p, "Glow", { Texture = TEX.dot, Color = MOONLIT, LightEmission = 1, Brightness = 2, Lifetime = R(1.25), Size = seq(0, 0.15, 0.7, 0.5, 1, 1.5), Transparency = seq(0, 0.95, 0.7, 0.5, 0.95, 0.1, 1, 1), LockedToPart = true, ZOffset = 1 })
		em(p, "Flames", grid2({ Texture = TEX.spiritFlame, Color = MOONLIT, LightEmission = 1, Brightness = 1.5, EmissionDirection = Enum.NormalId.Top, Speed = R(3, 5), Lifetime = R(0.3), Size = seq(0, 1.2, 0.4, 2.6, 1, 2), Transparency = seq(0, 0.2, 1, 1), LockedToPart = true, ZOffset = 1.5 }), { EmitCount = 2, EmitDelay = 1.0 })
	end

	-- CrownfallImpact (centre of the locked circle, authored r13): both
	-- forepaws hit: the shockwave ring (hero) on a slate ring, a flash, the
	-- carved crater with its crack cooling, Craters rocks; pebbles (+30), the
	-- dust wall (+60); settling smoke (+250).
	do
		local p = part(root, "CrownfallImpact", Vector3.new(26, 0.2, 26), { AuthoredRadius = 13 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		wave(g, "ShockDark", MESH.shockSwirl, { from = Vector3.new(3.4, 1, 3.4), to = Vector3.new(29, 3.6, 29), fromOffset = Vector3.new(0, 0.05, 0), toOffset = Vector3.new(0, 0.05, 0), fromT = 0.25, duration = 0.44, material = Enum.Material.SmoothPlastic, color = SLATE })
		wave(g, "Shock", MESH.shockSwirl, { from = Vector3.new(3, 1.2, 3), to = Vector3.new(28, 4.2, 28), fromOffset = Vector3.new(0, 0.4, 0), toOffset = Vector3.new(0, 0.9, 0), rotation = Vector3.new(0, 40, 0), fromT = 0, duration = 0.42 })
		em(g, "Flash", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.18), Size = NS(8), ZOffset = 3 }))
		em(g, "Crater", with(FLAT, earthy({ Texture = TEX.crater, Color = CS(INK), LightInfluence = 0.4, Lifetime = R(6), Size = NS(8.5), Rotation = R(0, 360), Transparency = seq(0, 0.05, 0.65, 0.2, 1, 1), ZOffset = 0.2 })))
		em(g, "Crack", with(FLAT, { Texture = TEX.crackLit, Color = MOONLIT, LightEmission = 1, Brightness = 2, Lifetime = R(1.4), Size = NS(9.5), Rotation = R(0, 360), Transparency = seq(0, 0, 0.35, 0.15, 1, 1), ZOffset = 0.5 }))
		em(g, "Pebbles", earthy({ Texture = TEX.pebbles, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(24, 44), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.8, 1.2), Size = NS(0.9), RotSpeed = R(-400, 400), Rotation = R(0, 360) }), { EmitCount = 12, EmitDelay = 0.03 })
		em(g, "DustWall", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(26, 40), Drag = 4, Lifetime = R(0.9, 1.3), Size = seq(0, 4.0, 1, 8.0), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 14, EmitDelay = 0.06 })
		em(g, "Settle", grid4(earthy({ Texture = TEX.risingSmoke, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(1, 3), Lifetime = R(1.6, 2.2), Size = NS(5), Transparency = seq(0, 0.55, 1, 1), Rotation = R(-15, 15) })), { EmitCount = 5, EmitDelay = 0.25 })
		local rocks = att(p, "Rocks", Vector3.new(0, 0.5, 0))
		rocks:AddTag("CraterVFX")
		for k, v in {
			Shape = "Ring", Fill = true, EmissionStart = "Progressive", Radius = 10, Variance = 3, Duration = 0.3,
			Count = R(10, 14), Lifetime = R(1.4, 2.2), Size = Vector3.new(2.6, 1.4, 2), SizeScale = R(0.7, 1.4),
			Collision = false, MatchGround = true, YOffset = 0.45, AngleX = R(25, 50), SpawnTime = R(0.05, 0.25), DespawnTime = R(0.8, 1.1),
		} do
			rocks:SetAttribute(k, v)
		end
		shake(p, "Explosion,30~130,3,0.9,20,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- Coil (each hind paw on the floor, 1000): claws dig in to load the spring.
	do
		local p = part(root, "Coil", Vector3.new(1.5, 0.2, 1.5), { AuthoredSeconds = 1.0 })
		em(p, "Kick", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(30, 30), Rate = 6, Speed = R(6, 12), Drag = 3, Lifetime = R(0.5, 0.8), Size = seq(0, 1.9, 1, 3.5), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitDelay = 0.3, EmitDuration = 0.7 })
		em(p, "Grit", earthy({ Texture = TEX.pebbles, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(25, 25), Rate = 9, Speed = R(8, 14), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.4, 0.6), Size = NS(0.35), RotSpeed = R(-300, 300), Rotation = R(0, 360) }), { EmitDelay = 0.3, EmitDuration = 0.7 })
	end

	-- Launch (floor between the hind paws, facing the dash): the hind legs
	-- drive off: dust burst behind (hero), a flat shock, pebbles.
	do
		local p = part(root, "Launch", Vector3.new(4, 0.2, 2))
		em(p, "Burst", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(35, 20), Speed = R(6, 10), Drag = 3, Lifetime = R(0.55, 0.7), Size = seq(0, 4.8, 1, 8.0), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 3 })
		wave(p, "Shock", MESH.shockFlat, { from = Vector3.new(1, 0.3, 1), to = Vector3.new(10, 0.7, 10), fromOffset = Vector3.new(0, 0.15, 0), toOffset = Vector3.new(0, 0.15, 0), fromT = 0.35, duration = 0.28, delay = 0.02 })
		em(p, "Pebbles", earthy({ Texture = TEX.pebbles, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(30, 30), Speed = R(14, 24), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.5, 0.8), Size = NS(0.5), RotSpeed = R(-300, 300), Rotation = R(0, 360) }), { EmitCount = 8, EmitDelay = 0.02 })
	end

	-- RushTrail (follows the chest through the dash): air rings peel off the
	-- muzzle (hero), speed lines stream back, ink and moon ribbons trail the
	-- body, dust is kicked up off the floor (Wake, dropped to the floor by code).
	do
		local p = part(root, "RushTrail", Vector3.new(6, 6, 6))
		local front = att(p, "Front", Vector3.new(0, 0.6, -10.5))
		em(front, "BowRing", { Texture = TEX.thinRing, Color = CS(MOON), LightEmission = 0.8, Brightness = 1.5, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, Rate = 10, Speed = R(2), Lifetime = R(0.22), Size = seq(0, 2.5, 1, 6.5), Transparency = seq(0, 0.15, 1, 1), Rotation = R(0, 360) })
		em(p, "Lines", { Texture = TEX.speedLines, Color = CS(MOON), LightEmission = 1, Orientation = Enum.ParticleOrientation.VelocityParallel, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Back, Rate = 28, Speed = R(30, 50), Lifetime = R(0.15, 0.25), Size = seq(0, 1.6, 1, 0.5), Transparency = seq(0, 0.3, 1, 1) })
		local top = att(p, "TrailTop", Vector3.new(0, 2.6, 2))
		local bottom = att(p, "TrailBottom", Vector3.new(0, -2.2, 2))
		for _, t in { { "InkRibbon", INK, 0, 0.3 }, { "MoonRibbon", MOON, 1, 0.22 } } do
			local tr = Instance.new("Trail")
			tr.Name = t[1]
			tr.Attachment0, tr.Attachment1 = top, bottom
			tr.Enabled = false
			tr.Color = CS(t[2])
			tr.LightEmission = t[3]
			tr.LightInfluence = 1 - t[3]
			tr.Lifetime = t[4]
			tr.Transparency = if t[3] > 0 then seq(0, 0.55, 1, 1) else seq(0, 0.45, 1, 1)
			tr.WidthScale = seq(0, 1, 1, 0.3)
			tr.FaceCamera = true
			tr.Parent = p
		end
		local wake = att(p, "Wake", Vector3.new(0, -6, 2))
		em(wake, "Dust", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(25, 25), Rate = 16, Speed = R(4, 8), Drag = 2, Lifetime = R(0.6, 0.9), Size = seq(0, 3.2, 1, 5.6), Transparency = DUSTFADE, Rotation = R(0, 360) })))
	end

	-- Skid (one paw on the floor, facing the slide): dust and grit ploughed ahead.
	do
		local p = part(root, "Skid", Vector3.new(1.5, 0.2, 1.5))
		em(p, "Plough", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(25, 25), Speed = R(10, 18), Drag = 4, Lifetime = R(0.5, 0.75), Size = seq(0, 2.6, 1, 4.8), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 3 })
		em(p, "Grit", earthy({ Texture = TEX.pebbles, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Speed = R(14, 22), Acceleration = Vector3.new(0, -60, 0), Lifetime = R(0.4, 0.6), Size = NS(0.4), RotSpeed = R(-300, 300), Rotation = R(0, 360) }), { EmitCount = 4 })
	end

	-- LeapImpact (where the leap lands, authored r14): the whole body comes
	-- down: a dust cloud bursts round it (hero), a shock ring on slate, flash,
	-- Craters rocks; pebbles (+30). No crack: cracks are the paw slam's.
	do
		local p = part(root, "LeapImpact", Vector3.new(14, 0.2, 14), { AuthoredRadius = 14 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		em(g, "Cloud", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(8, 12), Drag = 3, Lifetime = R(0.8, 1), Size = seq(0, 8.0, 1, 12.8), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 4 })
		em(g, "Skirt", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(30, 46), Drag = 4, Lifetime = R(0.8, 1.1), Size = seq(0, 3.2, 1, 7.2), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 12, EmitDelay = 0.04 })
		wave(g, "ShockDark", MESH.landRing, { from = Vector3.new(4.4, 0.8, 4.4), to = Vector3.new(31, 2.6, 31), fromOffset = Vector3.new(0, 0.05, 0), toOffset = Vector3.new(0, 0.05, 0), fromT = 0.25, duration = 0.4, material = Enum.Material.SmoothPlastic, color = SLATE })
		wave(g, "Shock", MESH.landRing, { from = Vector3.new(4, 1, 4), to = Vector3.new(30, 3, 30), fromOffset = Vector3.new(0, 0.35, 0), toOffset = Vector3.new(0, 0.7, 0), fromT = 0.15, duration = 0.38 })
		em(g, "Flash", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.16), Size = NS(6), ZOffset = 3 }))
		em(g, "Pebbles", earthy({ Texture = TEX.pebbles, Color = CS(DUST), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(65, 65), Speed = R(20, 36), Acceleration = Vector3.new(0, -90, 0), Lifetime = R(0.7, 1.1), Size = NS(0.8), RotSpeed = R(-400, 400), Rotation = R(0, 360) }), { EmitCount = 10, EmitDelay = 0.03 })
		local rocks = att(p, "Rocks", Vector3.new(0, 0.5, 0))
		rocks:AddTag("CraterVFX")
		for k, v in {
			Shape = "Ring", Fill = true, EmissionStart = "Progressive", Radius = 9, Variance = 2.5, Duration = 0.25,
			Count = R(8, 10), Lifetime = R(1.2, 1.8), Size = Vector3.new(2.2, 1.2, 1.8), SizeScale = R(0.7, 1.3),
			Collision = false, MatchGround = true, YOffset = 0.45, AngleX = R(25, 50), SpawnTime = R(0.05, 0.2), DespawnTime = R(0.7, 1),
		} do
			rocks:SetAttribute(k, v)
		end
		shake(p, "Explosion,30~120,2.6,0.8,20,0.02,1;1;1,0.1;0.1;0.1")
	end

	-- RoarTell (the Mouth, 1000) and HowlTell (1200): breath pulled in hard
	-- through the jaws while the maw glows. The howl adds HowlGather (below).
	for _, t in { { "RoarTell", 1.0, 22 }, { "HowlTell", 1.2, 16 } } do
		local seconds = t[2]
		local p = part(root, t[1], Vector3.new(12, 12, 12), { AuthoredSeconds = seconds })
		em(p, "Inhale", grid4({ Texture = TEX.airWisps, Color = CS(MOON), LightEmission = 0.6, Shape = Enum.ParticleEmitterShape.Sphere, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Rate = t[3], Lifetime = R(0.35, 0.5), Speed = R(18, 26), Size = seq(0, 1.8, 1, 0.6), Transparency = seq(0, 1, 0.25, 0.35, 1, 1), Rotation = R(0, 360), LockedToPart = true }), { EmitDelay = 0.15 * seconds, EmitDuration = 0.7 * seconds })
		em(p, "MawDark", { Texture = TEX.dot, Color = CS(INK), Lifetime = R(seconds), Size = seq(0, 0.5, 1, 2), Transparency = seq(0, 0.85, 0.8, 0.45, 1, 1), LockedToPart = true, ZOffset = 0.5 })
		em(p, "MawGlow", { Texture = TEX.dot, Color = MOONLIT, LightEmission = 1, Brightness = 2, Lifetime = R(seconds), Size = seq(0, 0.2, 0.7, 0.55, 1, 1.4), Transparency = seq(0, 0.9, 0.7, 0.45, 0.95, 0.1, 1, 1), LockedToPart = true, ZOffset = 1 })
	end

	-- HowlGather (floor under the King, 1200, authored r10): the pack's spirit
	-- motes rise in a ring round the King through the call.
	do
		local p = part(root, "HowlGather", Vector3.new(20, 0.2, 20), { AuthoredSeconds = 1.2, AuthoredRadius = 10 })
		em(p, "Motes", grid4({ Texture = TEX.twinkle, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, EmissionDirection = Enum.NormalId.Top, Rate = 20, Speed = R(4, 8), Acceleration = Vector3.new(0, 3, 0), Lifetime = R(0.9, 1.2), Size = NS(0.6), Transparency = seq(0, 1, 0.2, 0.1, 1, 1) }), { EmitDuration = 1.1 })
	end

	-- RoarBlast (the Mouth, facing out): sound and air leave the jaws: three
	-- rings travel out (hero, +0/+80/+160) on a slate ring, an air swirl (+40),
	-- wind lines (+50). RoarGround plays under it (+120).
	-- HowlBlast is the same rings on an axis tilted 55 degrees up (the howl to
	-- the sky); its ground shock is HowlGround.
	for _, t in { { "RoarBlast", 0 }, { "HowlBlast", 55 } } do
		local p = part(root, t[1], Vector3.new(0.4, 0.4, 0.4))
		local axis = att(p, "Axis", CFrame.Angles(math.rad(t[2]), 0, 0))
		wave(axis, "RingDark", MESH.soundRing, { from = Vector3.new(2.2, 0.5, 2.2), to = Vector3.new(15, 1.1, 15), fromOffset = Vector3.new(0, 0, -1.2), toOffset = Vector3.new(0, 0, -16.5), rotation = Vector3.new(90, 0, 0), fromT = 0.3, duration = 0.42, material = Enum.Material.SmoothPlastic, color = SLATE })
		for i = 1, 3 do
			local k = 1 - (i - 1) * 0.12
			wave(axis, "Ring" .. i, MESH.soundRing, { from = Vector3.new(2, 0.5, 2), to = Vector3.new(14 * k, 1.2, 14 * k), fromOffset = Vector3.new(0, 0, -1), toOffset = Vector3.new(0, 0, -16 * k), rotation = Vector3.new(90, i * 40, 0), fromT = 0.1 + (i - 1) * 0.15, duration = 0.42, delay = if i > 1 then (i - 1) * 0.08 else nil })
		end
		em(axis, "Air", { Texture = TEX.airSwirl, Color = CS(MOON), LightEmission = 0.5, Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Front, Speed = R(18), Drag = 3, Lifetime = R(0.35), Size = seq(0, 3, 1, 9), Transparency = seq(0, 0.4, 1, 1), Rotation = R(0, 360), RotSpeed = R(-200, 200) }, { EmitCount = 2, EmitDelay = 0.04 })
		em(axis, "Wind", { Texture = TEX.windLines, Color = CS(MOON), LightEmission = 0.8, Orientation = Enum.ParticleOrientation.VelocityParallel, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(30, 30), Speed = R(40, 60), Lifetime = R(0.25, 0.35), Size = seq(0, 2, 1, 1), Transparency = seq(0, 0.2, 1, 1) }, { EmitCount = 10, EmitDelay = 0.05 })
		shake(p, if t[2] == 0 then "Custom,25~110,1.4,0.5,16,0.05,1;1;1,0.06;0.06;0.06" else "Custom,25~110,1.1,0.5,14,0.05,1;1;1,0.05;0.05;0.05")
	end

	-- RoarGround (the floor under the Mouth, facing out): the blast hits the
	-- ground and shoves dust out ahead (+120).
	do
		local p = part(root, "RoarGround", Vector3.new(4, 0.2, 4))
		em(p, "Shove", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(10, 70), Speed = R(26, 40), Drag = 3, Lifetime = R(0.9, 1.2), Size = seq(0, 4.0, 1, 8.0), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 12, EmitDelay = 0.12 })
	end

	-- HowlGround (floor under the King, authored r20 = the stun radius): the
	-- howl's air shock sweeps the ring and lifts a dust skirt (+60).
	do
		local p = part(root, "HowlGround", Vector3.new(40, 0.2, 40), { AuthoredRadius = 20 })
		local g = att(p, "Ground", Vector3.new(0, 0.12, 0))
		wave(g, "Shock", MESH.shockSwirl, { from = Vector3.new(4, 0.5, 4), to = Vector3.new(44, 1.4, 44), fromOffset = Vector3.new(0, 0.25, 0), toOffset = Vector3.new(0, 0.3, 0), fromT = 0.45, duration = 0.5, delay = 0.06 })
		em(g, "Skirt", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(30, 44), Drag = 3, Lifetime = R(0.9, 1.2), Size = seq(0, 3.2, 1, 7.2), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 14, EmitDelay = 0.08 })
	end

	-- ManeFlare (the Neck): the mane's spirit flames flare with the call.
	do
		local p = part(root, "ManeFlare", Vector3.new(5, 3, 5))
		em(p, "Flames", grid2({ Texture = TEX.spiritFlame, Color = MOONLIT, LightEmission = 1, Brightness = 1.5, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(4, 8), Lifetime = R(0.5, 0.65), Size = seq(0, 2, 0.3, 4.2, 1, 3), Transparency = seq(0, 0.2, 0.6, 0.4, 1, 1), Rotation = R(-15, 15) }), { EmitCount = 4 })
	end

	-- Hits (on the struck player, near side, -Z away from the King).
	do
		local p = part(root, "HitClaw", Vector3.new(0.3, 0.3, 0.3))
		em(p, "ClawsDark", { Texture = TEX.claw, Color = CS(SLATE), Lifetime = R(0.2), Size = seq(0, 3, 1, 3.6), Rotation = R(-35), Transparency = seq(0, 0.1, 1, 1), ZOffset = 2 })
		em(p, "Claws", { Texture = TEX.claw, Color = MOONLIT, LightEmission = 1, Brightness = 2, Lifetime = R(0.18), Size = seq(0, 2.6, 1, 3.2), Rotation = R(-35), Transparency = FADE, ZOffset = 3 })
		em(p, "Star", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.15), Size = NS(2.2), ZOffset = 3.5 }))
	end
	do
		local p = part(root, "HitBite", Vector3.new(0.3, 0.3, 0.3))
		for _, side in { { "Upper", 1.2, 180, Enum.NormalId.Bottom }, { "Lower", -1.2, 0, Enum.NormalId.Top } } do
			local a = att(p, side[1], Vector3.new(0, side[2], 0))
			em(a, side[1], { Texture = TEX.jaw, Color = MOONLIT, LightEmission = 0.9, Brightness = 2, Rotation = R(side[3]), EmissionDirection = side[4], Speed = R(12), Drag = 10, Lifetime = R(0.16), Size = seq(0, 1.8, 1, 2.2), Transparency = FADE, ZOffset = 3 })
		end
		em(p, "Star", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.15), Size = NS(2), ZOffset = 3.5 }))
	end
	do
		local p = part(root, "HitHeavy", Vector3.new(0.3, 0.3, 0.3))
		em(p, "Star", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 3, Lifetime = R(0.18), Size = NS(3.2), ZOffset = 3.5 }))
		wave(p, "Ring", MESH.soundRing, { from = Vector3.new(1, 0.3, 1), to = Vector3.new(6.5, 0.6, 6.5), toOffset = Vector3.new(0, 0, -1.5), rotation = Vector3.new(90, 0, 0), fromT = 0.3, duration = 0.22, delay = 0.02 })
		em(p, "Dust", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(40, 40), Speed = R(4, 8), Drag = 3, Lifetime = R(0.45, 0.6), Size = seq(0, 2.2, 1, 4.2), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 2, EmitDelay = 0.04 })
	end

	-- Stagger (the chest): qi knocked out of the body.
	do
		local p = part(root, "Stagger", Vector3.new(4, 4, 4))
		em(p, "Star", grid4({ Texture = TEX.starBurst, Color = MOONLIT, LightEmission = 1, Brightness = 2.5, Lifetime = R(0.18), Size = NS(3), ZOffset = 2 }))
		em(p, "Knocked", grid4({ Texture = TEX.airWisps, Color = CS(MOON), LightEmission = 0.7, Shape = Enum.ParticleEmitterShape.Sphere, Speed = R(14, 20), Drag = 6, Lifetime = R(0.3), Size = NS(1.4), Rotation = R(0, 360) }), { EmitCount = 8, EmitDelay = 0.03 })
	end

	-- DeathLeak (the chest, 0-850): the King's qi leaves the failing body.
	do
		local p = part(root, "DeathLeak", Vector3.new(7, 7, 18), { AuthoredSeconds = 0.85 })
		em(p, "Motes", grid4({ Texture = TEX.twinkle, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Rate = 26, Speed = R(2, 5), Acceleration = Vector3.new(0, 4, 0), Lifetime = R(1, 1.6), Size = NS(0.5), Transparency = seq(0, 1, 0.15, 0.1, 1, 1) }), { EmitDuration = 0.85 })
		em(p, "Gutter", grid2({ Texture = TEX.spiritFlame, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Rate = 6, Speed = R(3, 5), Lifetime = R(0.5, 0.7), Size = seq(0, 1.8, 1, 0.6), Transparency = seq(0, 0.35, 1, 1), Rotation = R(-15, 15) }), { EmitDuration = 0.8 })
	end

	-- DeathRelease (floor under the body, at 850): the spirit breaks free: a
	-- twisting column rises (hero) with spirit flames, a flash, a ground
	-- shock and dust; motes keep rising for about 3 s.
	do
		local p = part(root, "DeathRelease", Vector3.new(12, 0.2, 12))
		wave(p, "Column", MESH.column, { from = Vector3.new(2.5, 3, 2.5), to = Vector3.new(8, 28, 8), fromOffset = Vector3.new(0, 1.5, 0), toOffset = Vector3.new(0, 14, 0), fromT = 0.15, duration = 0.9, style = "Quart" })
		em(p, "Flames", grid2({ Texture = TEX.spiritFlame, Color = MOONLIT, LightEmission = 1, Brightness = 2, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(10, 16), Drag = 1, Lifetime = R(0.6, 0.8), Size = seq(0, 3, 0.4, 6, 1, 4), Transparency = seq(0, 0.15, 0.6, 0.35, 1, 1) }), { EmitCount = 4, EmitDelay = 0.03 })
		local mid = att(p, "Mid", Vector3.new(0, 4, 0))
		em(mid, "Flash", grid4({ Texture = TEX.starBurst, Color = CS(WHITE), LightEmission = 1, Brightness = 4, Lifetime = R(0.2), Size = NS(8), ZOffset = 3 }))
		wave(p, "Shock", MESH.shockSwirl, { from = Vector3.new(3, 0.5, 3), to = Vector3.new(26, 1.4, 26), fromOffset = Vector3.new(0, 0.25, 0), toOffset = Vector3.new(0, 0.3, 0), fromT = 0.2, duration = 0.4, delay = 0.04 })
		em(p, "Dust", grid4(earthy({ Texture = TEX.dustPuff, Color = CS(DUST), Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180), Speed = R(20, 32), Drag = 3, Lifetime = R(0.8, 1.1), Size = seq(0, 3.2, 1, 6.4), Transparency = DUSTFADE, Rotation = R(0, 360) })), { EmitCount = 10, EmitDelay = 0.06 })
		em(p, "Rising", grid4({ Texture = TEX.twinkle, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Speed = R(3, 8), Acceleration = Vector3.new(0, 2, 0), Lifetime = R(2.5, 3.5), Size = NS(0.55), Transparency = seq(0, 1, 0.1, 0.1, 0.8, 0.4, 1, 1) }), { EmitCount = 24, EmitDelay = 0.1 })
		shake(p, "Custom,25~150,1.8,0.7,14,0.05,1;1;1,0.08;0.08;0.08")
	end

	-- Aura (always on; the runtime clones each emitter into the body). Light:
	-- `BaseRate` is the rate at full health; code scales it as the King is hurt.
	do
		local p = part(root, "AuraMane", Vector3.new(4, 2, 4))
		em(p, "Flames", grid2({ Texture = TEX.spiritFlame, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top, Rate = 5, Speed = R(2, 4), Lifetime = R(0.8, 1.2), Size = seq(0, 1.4, 0.4, 1.8, 1, 0.8), Transparency = seq(0, 0.6, 0.35, 0.45, 1, 1), Rotation = R(-15, 15) }))
		em(p, "Motes", grid4({ Texture = TEX.twinkle, Color = MOONLIT, LightEmission = 1, Shape = Enum.ParticleEmitterShape.Box, Rate = 5, SpreadAngle = Vector2.new(180, 180), Speed = R(0.5, 2), Acceleration = Vector3.new(0, 1.2, 0), Lifetime = R(1.6, 2.4), Size = NS(0.35), Transparency = seq(0, 1, 0.2, 0.2, 0.8, 0.4, 1, 1) }))
		em(p, "Embers", { Texture = TEX.dot, Color = CS({ CK(0, WHITE), CK(1, GOLD) }), LightEmission = 1, Rate = 0, EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60), Speed = R(2, 6), Lifetime = R(0.8, 1.4), Size = seq(0, 0.15, 1, 0), Transparency = seq(0, 0.1, 1, 1) })
	end
	do
		local p = part(root, "AuraBreath", Vector3.new(0.4, 0.4, 0.4))
		em(p, "Mist", earthy({ Texture = TEX.mist, Color = CS(MOON), LightInfluence = 0.6, Rate = 3, EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(20, 20), Speed = R(2, 4), Drag = 1, Acceleration = Vector3.new(0, 0.8, 0), Lifetime = R(1.1, 1.6), Size = seq(0, 0.4, 1, 1.8), Transparency = seq(0, 0.75, 0.3, 0.6, 1, 1), Rotation = R(0, 360) }))
	end

	root.Parent = effects
	return root
end

return true
