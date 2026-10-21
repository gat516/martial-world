--!nocheck
-- Builder for ReplicatedStorage.Effects.MethodAura: one aura per cultivation
-- method (art brief docs/systems/auras.md), drawn on a seated player
-- (Meditating + Method attributes) by src/client/MethodAura.luau.
-- Run through execute_luau in Edit mode (served by tools/receive_rbxmx.py,
-- after tools/vfx_blocks.luau so _G.vfxBlocks exists):
--   local m = Instance.new("ModuleScript"); m.Source = HttpService:GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/MethodAura.luau"); require(m)
--   _G.buildMethodAura(staging)   -- staging = vfxStage.begin(who)
--   _G.buildMethodAura(staging, { only = { "BlazingHeart" } })
-- It replaces staging.MethodAura; with `only`, just those methods' models,
-- leaving every other method (and any hand edits on it) untouched.
--
-- MethodAura (Folder; attributes Breath = seconds per breath, FadeIn, FadeOut)
--   <MethodId> (Model; Rhythm = "burst" for irregular bursts instead of the
--   breath, BreathAt = phase 0..1 of the breath beat, default 0.5 = the exhale)
--     Ground  parts relative to the ground under the player (pivot at the
--             origin, +Y up, -Z = the player's facing)
--     Body    parts with `Point` (a body point: Head, Crown, Mouth, Neck,
--             Chest, ChestL/R, Belly, SideL/R, Dantian, L/RShoulder, L/RElbow,
--             L/RHand, L/RHip, L/RKnee, L/RFoot, or Lap = between the hands);
--             the part's CFrame is its offset from that point (yaw-aligned)
--     Limbs   ParticleEmitters, `On` = body groups (Head, Torso, Arms, Hands,
--             Legs): cloned onto each of those body parts (R6 or R15)
--     Lines   Beams with `From`/`To` (body points, or the name of an
--             Attachment in Ground); `Segs` + `Jag` (studs) make a jagged
--             chain re-jagged on each burst; `Dots` (studs) puts a glow dot
--             at each end (`DotColor`, `DotImage`)
--     Shell*  parts copied round every body part, `Pad` studs larger (a
--             glowing skin: the outline/body glow); Highlights are avoided
--             because the map already uses hundreds (only 31 render)
--     Breath  emitted on each breath beat (or burst); its parts with `Point`
--             (and optional CFrame `Rel`) are moved to that body point first
--     Ignite  emitted when the player sits (once all the way down),
--             switches to this method or breaks through; Limbs emitters with
--             `Surge` = n also Emit(n) then
--     Punch   a recurring pulse (a lighter ignition) fired on the breath's beat
--             every `PunchEvery` (NumberRange, whole breaths) breaths, up to
--             `PunchJitter` seconds late, in place of that beat's Breath; that
--             breath's Swell is `PunchSwell` times larger; Limbs emitters with
--             `PunchSurge` = n Emit(n) then. Attributes on the method's Model.
-- Animation attributes on parts (and Lines where they make sense):
--   Pulse   NumberRange: transparency at breath peak..rest (template parts
--           stay at Transparency 1, so nothing shows unplayed)
--   Grow    NumberRange: size scale rest..peak (GrowIn = true: peak..rest)
--   Lift    studs moved up at the peak (negative settles down)
--   Spin    deg/s orbit about the aura's axis;  Turn  deg/s about its own Y
--   Bob     studs of slow sine drift;  Tumble deg/s;  Flicker 0..1 random dimming
--   Kick    extra opacity (and size) flashed on each breath beat and pulse
--   Rise    studs drifted up over RisePeriod seconds (default 6), fading in at
--           the bottom and out at the top, then again (a layer replaced)
--   Delay   seconds after the aura starts before it fades in (growth)
--   Hidden  keep the part invisible and breathe only its SurfaceGui image
-- Emitters: loop ones carry EmitDuration = -1 (the plugin's T shows them);
-- `Scaled` ones get the method grade's rate multiplier; `Breathe` ones run
-- faster on the inhale (true: the old 0.2..1.5 curve; a NumberRange lo..hi:
-- that rate multiplier at rest..peak; Limbs emitters may breathe too);
-- `Prime = n` emits n at once when the aura starts (slow ground loops show at
-- once); `Swell = k` scales the emitter's Size by 1 + k at the breath's
-- peak, kicks on the beat and grows with the ignition and pulses (Ground, Body
-- and Limbs emitters); `Drift = k` adds a slow size wander of +-k.
-- Colours are baked per method (no tinting).

local B = _G.vfxBlocks
assert(B, "load tools/vfx_blocks.luau (or vfx_session.luau) first")

local function id(n)
	return "rbxassetid://" .. n
end

local A = {
	glow = id(867619398),
	glowDot = id(9841273544),
	softRing = id(15611941586),
	thinRing = id(9841273159),
	wisp = id(9345352897),
	torus = id(471124075),
	swirlRing = id(129778117978668),
	swirlRing2 = id(73349240058321),
	star4 = id(13271628051),
	star12 = id(243728206),
	flame = id(265788038),
	spark = id(9841260273),
	bubble = id(249902641),
	leaf = id(17259245248),
	rocks = id(425665059),
	dust = id(11037785287),
	arcs = id(528280947),
	windStreak = id(426653646),
	puff = id(933102662),
	mist = id(1084987899),
	ice = id(18765221838),
	shards = id(12402863766),
	snow = id(94151281482069),
	rune = id(83667248904000),
}
_G.MethodAuraAssets = A

local NS, CS, KP, CK, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, ColorSequenceKeypoint.new, NumberRange.new
local V3 = Vector3.new
local rgb = Color3.fromRGB
local LOOP = -1 -- EmitDuration: enable and never disable
local up, front = Enum.NormalId.Top, Enum.NormalId.Front
local disc, box, sphere = Enum.ParticleEmitterShape.Disc, Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShape.Sphere
local surface, volume = Enum.ParticleEmitterShapeStyle.Surface, Enum.ParticleEmitterShapeStyle.Volume
local streak = Enum.ParticleOrientation.VelocityParallel

local function seq(...)
	local v, kps = { ... }, {}
	for i = 1, #v, 2 do
		table.insert(kps, KP(v[i], v[i + 1]))
	end
	return NS(kps)
end

local function rnd(lo, hi)
	local mid, env = (lo + hi) / 2, (hi - lo) / 2
	return NS({ KP(0, mid, env), KP(1, mid, env) })
end

local function cseq(...)
	local v, kps = { ... }, {}
	for i = 1, #v, 2 do
		table.insert(kps, CK(v[i], v[i + 1]))
	end
	return CS(kps)
end

local function attrs(inst, t)
	for k, v in t or {} do
		inst:SetAttribute(k, v)
	end
	return inst
end

local function model(name, parent, a)
	local m = Instance.new("Model")
	m.Name = name
	attrs(m, a)
	m.Parent = parent
	return m
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(name, parent, cf, size, a)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Material = Enum.Material.Neon
	p.Size = size or V3(0.2, 0.2, 0.2)
	p.CFrame = cf or CFrame.new()
	attrs(p, a)
	p.Parent = parent
	return p
end

local function ball(name, parent, d, cf, color, a)
	local p = part(name, parent, cf, V3(d, d, d), a)
	p.Shape = Enum.PartType.Ball
	p.Color = color
	return p
end

-- An ellipsoid: a Block with a Sphere SpecialMesh takes the part's size.
local function ellipsoid(name, parent, size, cf, color, a, material)
	local p = part(name, parent, cf, size, a)
	p.Material = material or Enum.Material.Neon
	p.Color = color
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	return p
end

local function mesh(meshId, parent, name, size, cf, color, a, material)
	local m = B.mesh(meshId, parent, name, size, cf, color, material)
	attrs(m, a)
	return m
end

-- torus 471124075 is 150 x 9.51 x 150; a round tube is Y = D * 0.0634
local function ring(d, fat)
	return V3(d, d * 0.0634 * (fat or 1), d)
end

-- A looping emitter (off in the template; the runtime and the plugin's T enable it).
local function loop(parent, name, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 1
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	e.Texture = A.glowDot
	for k, v in props do
		e[k] = v
	end
	attrs(e, { EmitDuration = LOOP })
	attrs(e, a)
	e.Parent = parent
	return e
end

-- A one-shot emitter (EmitCount n).
local function burst(parent, name, n, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	e.Texture = A.glowDot
	for k, v in props do
		e[k] = v
	end
	attrs(e, { EmitCount = n })
	attrs(e, a)
	e.Parent = parent
	return e
end

local function wave(parent, name, p)
	local w = B.meshWave(parent, name, p)
	w:SetAttribute("FadeStyle", p.fadeStyle or "Quad")
	return w
end

local function beam(parent, name, from, to, props, a)
	local b = Instance.new("Beam")
	b.Name = name
	b.FaceCamera = true
	b.Segments = 1
	b.LightInfluence = 0
	b.Enabled = false
	b.ZOffset = 0.6 -- drawn just in front of the limb it runs along
	for k, v in props do
		b[k] = v
	end
	attrs(b, { From = from, To = to })
	attrs(b, a)
	b.Parent = parent
	return b
end

-- A glowing skin: the runtime copies it round every body part (Pad studs
-- larger) and breathes its transparency. ForceField reads as a rim glow.
local function shell(parent, color, a, material, name)
	local p = part(name or "Shell", parent, CFrame.new(), V3(1, 1, 1), a)
	p.Material = material or Enum.Material.ForceField
	p.Color = color
	return p
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Enabled = false
	l.Parent = parent
	return l
end

-- A flat image on the ground: a hidden thin part with a SurfaceGui on top.
-- `d` is a diameter or a Vector3 size (X/Z used); `y` a height or a CFrame.
local function decalDisc(name, parent, d, y, image, color, a)
	local size = if typeof(d) == "Vector3" then V3(d.X, 0.05, d.Z) else V3(d, 0.05, d)
	local p = part(name, parent, if typeof(y) == "CFrame" then y else CFrame.new(0, y, 0), size, a)
	p:SetAttribute("Hidden", true)
	local gui = Instance.new("SurfaceGui")
	gui.Face = up
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = color
	img.ImageTransparency = 1
	img.Parent = gui
	return p
end

-- Points sit at the body (pivot is the ground; a seated R6 torso is ~1 up).
local function at(point, rel, name, parent, size, a)
	local p = part(name, parent, rel or CFrame.new(), size, a)
	p:SetAttribute("Point", point)
	return p
end

-- ---------------------------------------------------------------- Sect Breathing
-- The basics: the first breathing every disciple learns. Qi is drawn in on
-- the inhale and settles in the dantian on the exhale, over the sect's plain
-- taiji. Modest on purpose (the starter, ranked after named methods), but
-- every piece moves with the breath. Rebuilt 2026-10-21 from library
-- emissions. Back to front:
--   ground  a faint taiji turning slowly under you (its dark half is the
--           dark base), a soft jade halo breathing round it
--   body    a small jade dantian glow with a hot centre that swells with the
--           breath; motes drawn in to it from about a body-width on the
--           inhale; a faint qi vapour lifting off the head
--   breath  the exhale settles: a glint at the dantian, a soft ring breathing
--           out over the taiji, two or three motes rising off the belly
--   ignite  a jade flash and star at the dantian, a ring and a low puff of
--           qi over the ground, motes thrown up that drift back down
-- No light, no shell, no parts drawn.

local SECT_WHITE, SECT_JADE, SECT_DEEP = rgb(236, 255, 244), rgb(150, 235, 195), rgb(60, 170, 125)

local SB = {
	taiji = id(121707861781327), -- taiji (yin-yang), black and white
	soft = id(243660373), -- soft round glow
	dot = id(9841273544), -- small hard glow dot
	twinkle = id(102648375149008), -- 4x4 flipbook: a 4-point sparkle growing and shrinking
	star = id(13271102367), -- small 4-point star
	ring = id(15611866526), -- soft wobbly ring
	vapour = id(9345352897), -- curling wisp
	puff = id(933102662), -- soft cloud puff
}
_G.SectBreathingAssets = SB

local function sectBreathing(root)
	local m = model("SectBreathing", root)
	local grid4 = Enum.ParticleFlipbookLayout.Grid4x4

	-- ground: the taiji (its dark half reads on grass), a halo breathing round it
	local ground = model("Ground", m)
	decalDisc("Taiji", ground, 8, 0.13, SB.taiji, SECT_WHITE, {
		Pulse = R(0.4, 0.65), Turn = 8, Grow = R(0.97, 1.03), Kick = 0.35,
	})
	local floor = part("Floor", ground, CFrame.new(0, 0.1, 0), V3(0.1, 0.1, 0.1))
	loop(floor, "Halo", B.flat({
		Texture = SB.soft, Size = NS(3.6), Transparency = seq(0, 1, 0.3, 0.72, 0.7, 0.72, 1, 1), Color = CS(SECT_JADE),
		Lifetime = R(4), Rate = 0.5, Rotation = R(0, 360), LightEmission = 0.6, ZOffset = 0,
	}), { Prime = 2, Breathe = R(0.6, 1.4), Swell = 0.12, Drift = 0.05 })

	-- body: the dantian, motes drawn in, qi vapour off the head
	local body = model("Body", m)
	local dantian = at("Belly", CFrame.new(0, 0, -0.15), "Dantian", body)
	loop(dantian, "Glow", {
		Texture = SB.soft, Size = NS(0.55), Transparency = seq(0, 1, 0.3, 0.35, 0.7, 0.35, 1, 1), Color = CS(SECT_JADE),
		Lifetime = R(0.8), Rate = 3, LightEmission = 1, Brightness = 1.5, ZOffset = 1.2, LockedToPart = true,
	}, { Prime = 2, Swell = 0.55 })
	loop(dantian, "Hot", {
		Texture = SB.dot, Size = NS(0.11), Transparency = seq(0, 1, 0.3, 0.1, 1, 1), Color = CS(SECT_WHITE),
		Lifetime = R(0.5), Rate = 4, LightEmission = 1, Brightness = 2.5, ZOffset = 1.3, LockedToPart = true,
	}, { Prime = 2, Swell = 0.4 })
	local gather = at("Belly", CFrame.new(0, 0.1, 0), "Gather", body, V3(5.2, 3.8, 5.2))
	loop(gather, "Motes", {
		Texture = SB.dot, Shape = sphere, ShapeStyle = surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = seq(0, 0, 0.25, 0.06, 0.8, 0.05, 1, 0), Transparency = seq(0, 1, 0.3, 0.15, 1, 0.4),
		Color = cseq(0, SECT_JADE, 1, SECT_WHITE), Lifetime = R(1.15, 1.25), Speed = R(2.2), Rate = 3, LightEmission = 1,
		Brightness = 2, ZOffset = 0.5,
	}, { Scaled = true, Breathe = R(0.15, 1.6) })

	local limbs = folder("Limbs", m)
	loop(limbs, "Vapour", {
		Texture = SB.vapour, Shape = box, ShapeStyle = surface, EmissionDirection = up, Size = seq(0, 0.25, 1, 0.7),
		Transparency = seq(0, 1, 0.35, 0.75, 1, 1), Color = cseq(0, SECT_WHITE, 1, SECT_JADE), Lifetime = R(1.4, 1.8),
		Speed = R(0.6, 1), Acceleration = V3(0, 0.6, 0), Rotation = R(0, 360), RotSpeed = R(-30, 30), Rate = 0.8, LightEmission = 0.8,
	}, { On = "Head", Scaled = true, Breathe = R(0.5, 1.4), Surge = 3 })

	-- the exhale settles: a glint, a soft ring out over the taiji, motes rising
	local breath = model("Breath", m)
	local belly = at("Belly", CFrame.new(0, 0, -0.2), "Belly", breath)
	burst(belly, "Glint", 1, {
		Texture = SB.twinkle, FlipbookLayout = grid4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot, Size = NS(0.4),
		Transparency = NS(0), Color = CS(SECT_WHITE), Lifetime = R(0.6), LightEmission = 1, Brightness = 2, ZOffset = 1.5,
	})
	burst(belly, "Motes", 3, {
		Texture = SB.dot, Size = seq(0, 0, 0.2, 0.07, 1, 0), Transparency = seq(0, 0.2, 0.7, 0.35, 1, 1),
		Color = cseq(0, SECT_WHITE, 1, SECT_JADE), Lifetime = R(1.8, 2.4), Speed = R(0.8, 1.3), SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = up, LightEmission = 1, Brightness = 2, Drag = 0.4, ZOffset = 0.8,
	})
	local settle = part("Floor", breath, CFrame.new(0, 0.18, 0))
	burst(settle, "Ring", 1, B.flat({
		Texture = SB.ring, Size = seq(0, 2.4, 1, 3.6), Transparency = seq(0, 0.55, 0.4, 0.6, 1, 1), Color = CS(SECT_JADE),
		Lifetime = R(1.4), Rotation = R(0, 360), LightEmission = 0.8, Brightness = 1.5, ZOffset = 0.2,
	}))

	-- ignition: small and clean, a flash at the dantian and a breath out over the ground
	local ignite = model("Ignite", m)
	local core = at("Belly", CFrame.new(0, 0, -0.3), "Belly", ignite)
	burst(core, "Flash", 1, {
		Texture = SB.dot, Size = seq(0, 0.3, 0.15, 0.9, 1, 1.05), Transparency = seq(0, 0, 0.4, 0.45, 1, 1),
		Color = cseq(0, SECT_WHITE, 1, SECT_JADE), Lifetime = R(0.35), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(core, "Star", 1, {
		Texture = SB.star, Size = seq(0, 0.3, 0.25, 1.8, 1, 0), Transparency = NS(0), Color = CS(SECT_WHITE),
		Lifetime = R(0.4), Rotation = R(0, 15), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(core, "Motes", 12, {
		Texture = SB.dot, EmissionDirection = up, Size = seq(0, 0.09, 1, 0), Transparency = seq(0, 0, 0.7, 0.2, 1, 1),
		Color = cseq(0, SECT_WHITE, 1, SECT_JADE), Lifetime = R(1.2, 1.8), Speed = R(4, 6.5), Drag = 2.5,
		SpreadAngle = Vector2.new(55, 55), Acceleration = V3(0, -1.2, 0), LightEmission = 1, Brightness = 2.5, ZOffset = 1,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3.6, 0.1, 3.6))
	burst(base, "Ring", 1, B.flat({
		Texture = SB.ring, Size = seq(0, 1.8, 1, 4.2), Transparency = seq(0, 0.1, 0.5, 0.45, 1, 1), Color = CS(SECT_JADE),
		Lifetime = R(0.7), Rotation = R(0, 360), LightEmission = 1, Brightness = 2, ZOffset = 0.3,
	}))
	burst(base, "Puff", 7, {
		Texture = SB.puff, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 0.5, 1, 1.2), Transparency = seq(0, 0.6, 1, 1), Color = CS(SECT_WHITE), Lifetime = R(0.8, 1.1),
		Speed = R(4, 6), Drag = 3, Rotation = R(0, 360), LightEmission = 0.2, LightInfluence = 0.4,
	})
	return m
end

-- ---------------------------------------------------------------- Blazing Heart (Fire)
-- A heart that burns (Mortal: small, close, rich). Rebuilt 2026-10-21 from
-- layered library emissions (refs: docs/reference/vfx/fire_aura_smoke_outline,
-- fire_aura_swirl_ground; Sol's RNG Holy Aura). Back to front:
--   ground  scorch (dark base), heat pool, turning fire swirl, a hui-wen
--           (meander) sigil ring turning the other way, small flames on its rim
--   body    a flame mantle hugging the silhouette from behind (dark under
--           bright), a white-hot heart core with a twinkling glint and the one
--           light; flames licking off the arms and torso, a small crown of
--           licks on the head, black smoke curling off the flame tips, embers
--   breath  a heartbeat (lub-dub) at the chest, a ring pulsing out of the
--           sigil, the mantle flaring, a puff of embers
--   ignite  white flash and star at the heart, a starburst flare, flame jets
--           roaring up round the body, a fire ring burning out over the
--           ground, soot thrown low, an ember burst; limb flames surge

local FIRE_WHITE, FIRE_CORE, FIRE, FIRE_DEEP = rgb(255, 248, 225), rgb(255, 214, 120), rgb(255, 130, 50), rgb(215, 50, 20)
local SOOT = rgb(22, 10, 6)

local BH = {
	glow = id(867619398), -- soft round glow
	dot = id(9841273544), -- small hard glow dot
	star = id(13271628051), -- 4-point star
	chroma = id(16366023815), -- 4-point lens glint, chromatic edges
	twinkle = id(12156297119), -- 4x4 flipbook: star sparkle shrinking
	starburst = id(13580358178), -- 4x4 flipbook: jagged starburst ring breaking up
	mantle = id(81332883799807), -- 2x2 flipbook: a flame aura silhouette (spiky top, round base)
	flame = id(17703378809), -- 4x4 flipbook: white flame tongue, birth to death
	lick = id(7216854783), -- single curved flame tongue
	jet = id(12363830081), -- spiky upward flame jet
	spray = id(12363829856), -- spiky burst from the ground
	soot = id(109022205002579), -- 4x4 flipbook: black smoke curl
	swirl = id(14475273913), -- soft vortex swirl
	sigil = id(16511732405), -- hui-wen (Greek key) ring
	ring = id(12363693873), -- fuzzy ring
	burnRing = id(121552805259111), -- 2x2 flipbook: a ring of fire burning out
	ember = id(9841259562), -- comet streak
}
_G.BlazingHeartAssets = BH

local grid2, grid4 = Enum.ParticleFlipbookLayout.Grid2x2, Enum.ParticleFlipbookLayout.Grid4x4
local oneShot, loopFb = Enum.ParticleFlipbookMode.OneShot, Enum.ParticleFlipbookMode.Loop
local fireColor = cseq(0, FIRE_WHITE, 0.25, FIRE_CORE, 0.6, FIRE, 1, FIRE_DEEP)

local function blazingHeart(root)
	-- a pulse (the Punch model) every 1 or 2 breaths, on the beat, up to 0.6 s
	-- late; that breath swells 1.4x as far
	local m = model("BlazingHeart", root, { PunchEvery = R(1, 2), PunchJitter = 0.6, PunchSwell = 1.4 })

	-- ground: the figure's seat (within ~1 body-width)
	local ground = model("Ground", m)
	local floor = part("Floor", ground, CFrame.new(0, 0.12, 0), V3(3.4, 0.1, 3.4))
	loop(floor, "Scorch", B.flat({ -- dark base under everything bright
		Texture = BH.glow, Size = NS(3), Transparency = seq(0, 1, 0.2, 0.3, 0.8, 0.3, 1, 1), Color = CS(SOOT),
		Lifetime = R(4), Rate = 0.5, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Heat", B.flat({
		Texture = BH.glow, Size = NS(1.9), Transparency = seq(0, 1, 0.25, 0.45, 0.75, 0.45, 1, 1), Color = CS(FIRE),
		Lifetime = R(3), Rate = 0.67, Rotation = R(0, 360), LightEmission = 1, Brightness = 2, ZOffset = 0.05,
	}), { Prime = 2, Breathe = R(0.6, 1.6), Swell = 0.15, Drift = 0.06 })
	loop(floor, "Swirl", B.flat({
		Texture = BH.swirl, Size = seq(0, 1.7, 1, 2.3), Transparency = seq(0, 1, 0.3, 0.2, 0.7, 0.3, 1, 1),
		Color = cseq(0, FIRE_CORE, 0.5, FIRE, 1, FIRE_DEEP), Lifetime = R(2.4), Rate = 1, Rotation = R(0, 360),
		RotSpeed = R(70, 90), LightEmission = 1, Brightness = 4, ZOffset = 0.1,
	}), { Prime = 2, Breathe = R(0.6, 1.4), Swell = 0.12, Drift = 0.08 })
	-- the sigils are flat images (a turning particle would cross-fade out of
	-- step). Each moves its own way: turning, breathing in size (more into a
	-- pulse), flashing brighter on the heartbeat and the pulses (Kick), and
	-- the raised ones drifting up, fading at the top and starting again (Rise)
	decalDisc("Sigil", ground, 4.7, 0.16, BH.sigil, FIRE_CORE, {
		Pulse = R(0.05, 0.3), Turn = -14, Grow = R(0.95, 1.05), Kick = 0.6,
	})
	-- three raised sigils the user added by hand in Studio (2026-10-21), kept
	-- at their rough sizes and heights but centred and level on the body axis
	-- (their image and colour were lost, so they follow the ground sigil)
	decalDisc("Sigil2", ground, 9, CFrame.new(0, 1.89, 0), BH.sigil, FIRE_CORE, {
		Pulse = R(0.3, 0.6), Turn = 9, Grow = R(0.96, 1.05), Kick = 0.5, Rise = 0.6, RisePeriod = 7,
	})
	decalDisc("Sigil3", ground, 8.2, CFrame.new(0, 1.63, 0), BH.sigil, FIRE, {
		Pulse = R(0.35, 0.65), Turn = -6, Grow = R(0.94, 1.06), Kick = 0.5, Rise = 0.5, RisePeriod = 9,
	})
	decalDisc("Sigil4", ground, 6.6, CFrame.new(0, 2.66, 0), BH.sigil, FIRE_CORE, {
		Pulse = R(0.3, 0.6), Turn = 16, Grow = R(0.95, 1.07), Kick = 0.6, Rise = 0.4, RisePeriod = 6,
	})
	local rim = part("Rim", ground, CFrame.new(0, 0.15, 0), V3(3.6, 0.1, 3.6))
	loop(rim, "RimFlames", {
		Texture = BH.flame, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = surface, EmissionDirection = up, Size = seq(0, 0.25, 0.4, 0.42, 1, 0.12),
		Transparency = seq(0, 1, 0.15, 0.1, 0.8, 0.35, 1, 1), Color = fireColor, Lifetime = R(0.5, 0.7),
		Speed = R(0.6, 1.2), Acceleration = V3(0, 3, 0), Rotation = R(-10, 10), Rate = 9, LightEmission = 0.7,
		Brightness = 2, ZOffset = 0.3,
	}, { Scaled = true, Breathe = R(0.5, 1.5), Swell = 0.2, Drift = 0.1 })

	-- body: the heart and the mantle
	local body = model("Body", m)
	local core = at("Chest", CFrame.new(0, 0, -0.2), "Heart", body)
	light(core, FIRE, 9, 1.6)
	loop(core, "Glow", {
		Texture = BH.dot, Size = NS(0.55), Transparency = seq(0, 1, 0.3, 0.3, 1, 1), Color = cseq(0, FIRE_CORE, 1, FIRE),
		Lifetime = R(0.45), Rate = 6, LightEmission = 1, Brightness = 2, ZOffset = 1.5, LockedToPart = true,
	}, { Prime = 3, Swell = 0.5 })
	loop(core, "Hot", {
		Texture = BH.dot, Size = NS(0.2), Transparency = seq(0, 1, 0.3, 0, 1, 1), Color = CS(FIRE_WHITE),
		Lifetime = R(0.4), Rate = 6, LightEmission = 1, Brightness = 4, ZOffset = 1.6, LockedToPart = true,
	}, { Prime = 3, Swell = 0.3 })
	loop(core, "Glint", {
		Texture = BH.twinkle, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = NS(0.75),
		Transparency = NS(0), Color = CS(FIRE_WHITE), Lifetime = R(0.75), Rate = 0.9, Rotation = R(-15, 15),
		LightEmission = 1, Brightness = 3, ZOffset = 1.7, LockedToPart = true,
	})
	local mantle = at("Dantian", CFrame.new(0, 1.15, 0.4), "Mantle", body)
	loop(mantle, "MantleDark", { -- the dark under the bright flame outline
		Texture = BH.mantle, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(6, 8),
		FlipbookStartRandom = true, Size = NS(2.45), Transparency = seq(0, 1, 0.25, 0.45, 0.75, 0.45, 1, 1),
		Color = CS(SOOT), Lifetime = R(1.2), Rate = 2, LightEmission = 0, ZOffset = -0.6, LockedToPart = true,
	}, { Prime = 2, Swell = 0.08, Drift = 0.06 })
	loop(mantle, "Mantle", {
		Texture = BH.mantle, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(7, 10),
		FlipbookStartRandom = true, Size = seq(0, 2.1, 1, 2.3), Transparency = seq(0, 1, 0.25, 0.2, 0.7, 0.3, 1, 1),
		Color = cseq(0, FIRE_CORE, 0.4, FIRE, 1, FIRE_DEEP), Lifetime = R(0.9), Rate = 3, LightEmission = 0.7,
		Brightness = 2, ZOffset = -0.3, LockedToPart = true,
	}, { Prime = 2, Breathe = R(0.7, 1.4), Swell = 0.08, Drift = 0.06 })

	-- limbs: flames licking off the surface, a small crown, soot, embers
	local limbs = folder("Limbs", m)
	loop(limbs, "Flames", {
		Texture = BH.flame, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, ShapeStyle = surface,
		EmissionDirection = up, Size = seq(0, 0.42, 0.4, 0.62, 1, 0.25), Transparency = seq(0, 1, 0.12, 0.1, 0.75, 0.3, 1, 1),
		Color = fireColor, Lifetime = R(0.55, 0.75), Speed = R(0.5, 1.2), Acceleration = V3(0, 6, 0), Rotation = R(-10, 10),
		Rate = 8, LightEmission = 0.6, Brightness = 2, ZOffset = 0.4,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.7, 1.4), Surge = 10, PunchSurge = 3, Swell = 0.2, Drift = 0.1 })
	loop(limbs, "Crown", {
		Texture = BH.lick, Shape = box, ShapeStyle = surface, EmissionDirection = up, Size = seq(0, 0.22, 0.4, 0.4, 1, 0.1),
		Transparency = seq(0, 1, 0.15, 0.1, 1, 1), Color = fireColor, Lifetime = R(0.35, 0.5), Speed = R(1.5, 2.5),
		Rotation = R(-15, 15), Rate = 5, LightEmission = 0.7, Brightness = 2, ZOffset = 0.3,
	}, { On = "Head", Scaled = true, Breathe = R(0.6, 1.4), Surge = 6, PunchSurge = 2, Swell = 0.2, Drift = 0.1 })
	loop(limbs, "Soot", {
		Texture = BH.soot, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, ShapeStyle = surface,
		EmissionDirection = up, Size = seq(0, 0.3, 1, 0.75), Transparency = seq(0, 1, 0.2, 0.35, 1, 1), Color = CS(SOOT),
		Lifetime = R(0.9, 1.2), Speed = R(0.9, 1.5), Acceleration = V3(0, 0.6, 0), Rotation = R(0, 360), RotSpeed = R(-40, 40),
		Rate = 1.2, LightEmission = 0, LightInfluence = 0, ZOffset = 0.2,
	}, { On = "Arms,Head", Scaled = true })
	loop(limbs, "Embers", {
		Texture = BH.ember, Shape = box, ShapeStyle = volume, EmissionDirection = up, Orientation = streak,
		Size = seq(0, 0.09, 0.8, 0.07, 1, 0), Transparency = seq(0, 0, 0.5, 0.2, 0.55, 0.6, 0.6, 0.1, 1, 1),
		Color = cseq(0, FIRE_WHITE, 0.4, FIRE_CORE, 1, FIRE), Lifetime = R(1, 1.6), Speed = R(2.5, 4), Drag = 0.8,
		SpreadAngle = Vector2.new(30, 30), Acceleration = V3(0, 1.5, 0), Rate = 1.6, LightEmission = 1, Brightness = 3,
	}, { On = "Arms,Torso", Scaled = true, Surge = 8, PunchSurge = 4 })
	loop(limbs, "Ash", { -- dark flecks lifting off the burning body (ref fire_aura_smoke_outline)
		Texture = BH.dot, Shape = box, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.04, 0.07),
		Transparency = seq(0, 1, 0.15, 0.1, 0.8, 0.2, 1, 1), Color = CS(SOOT), Lifetime = R(0.9, 1.4), Speed = R(1, 2),
		SpreadAngle = Vector2.new(40, 40), Rotation = R(0, 360), Rate = 1.5, LightEmission = 0, ZOffset = 0.5,
	}, { On = "Torso,Arms", Scaled = true })

	-- the breath's beat: a heartbeat (lub-dub)
	local breath = model("Breath", m)
	local chest = at("Chest", nil, "Chest", breath)
	burst(chest, "Lub", 1, {
		Texture = BH.dot, Size = seq(0, 0.5, 0.3, 1, 1, 1.15), Transparency = seq(0, 0.2, 1, 1), Color = cseq(0, FIRE_WHITE, 1, FIRE),
		Lifetime = R(0.35), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	})
	burst(chest, "Dub", 1, {
		Texture = BH.dot, Size = seq(0, 0.4, 0.3, 0.8, 1, 0.9), Transparency = seq(0, 0.35, 1, 1), Color = cseq(0, FIRE_WHITE, 1, FIRE),
		Lifetime = R(0.3), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	}, { EmitDelay = 0.24 })
	burst(chest, "Glint", 1, {
		Texture = BH.star, Size = seq(0, 0.4, 0.3, 1.5, 1, 0), Transparency = NS(0), Color = CS(FIRE_WHITE),
		Lifetime = R(0.3), Rotation = R(0, 20), LightEmission = 1, Brightness = 3, ZOffset = 1.9,
	})
	burst(chest, "Sparks", 6, {
		Texture = BH.ember, Orientation = streak, EmissionDirection = up, Size = seq(0, 0.1, 1, 0), Transparency = NS(0),
		Color = cseq(0, FIRE_WHITE, 1, FIRE), Lifetime = R(0.5, 0.9), Speed = R(4, 7), Drag = 2, SpreadAngle = Vector2.new(60, 60),
		LightEmission = 1, Brightness = 3,
	})
	local back = at("Dantian", CFrame.new(0, 1.15, 0.45), "Back", breath)
	burst(back, "Flare", 1, {
		Texture = BH.mantle, FlipbookLayout = grid2, FlipbookMode = oneShot, Size = seq(0, 2, 0.3, 2.6, 1, 2.8),
		Transparency = seq(0, 0.15, 1, 1), Color = cseq(0, FIRE_CORE, 1, FIRE_DEEP), Lifetime = R(0.6), LightEmission = 0.9,
		Brightness = 2, ZOffset = -0.3,
	})
	local pulse = part("Floor", breath, CFrame.new(0, 0.2, 0))
	burst(pulse, "Pulse", 1, B.flat({
		Texture = BH.ring, Size = seq(0, 1.3, 1, 3.1), Transparency = seq(0, 0.35, 1, 1), Color = CS(FIRE),
		Lifetime = R(0.9), LightEmission = 1, Brightness = 2, ZOffset = 0.2,
	}))

	-- a pulse every few breaths: a lighter ignition (smaller flash, no
	-- chromatic star or soot, fewer jets and embers), so it stays alive
	-- without tiring the eye; limb flames surge too (PunchSurge)
	local pulseM = model("Punch", m)
	local pHeart = at("Chest", CFrame.new(0, 0, -0.3), "Chest", pulseM)
	burst(pHeart, "Flash", 1, {
		Texture = BH.dot, Size = seq(0, 0.5, 0.2, 1.3, 1, 1.5), Transparency = seq(0, 0.05, 0.4, 0.5, 1, 1),
		Color = cseq(0, FIRE_WHITE, 1, FIRE_CORE), Lifetime = R(0.35), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(pHeart, "Star", 1, {
		Texture = BH.star, Size = seq(0, 0.4, 0.25, 2.4, 1, 0), Transparency = NS(0), Color = CS(FIRE_WHITE),
		Lifetime = R(0.35), Rotation = R(0, 20), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(pHeart, "Burst", 1, {
		Texture = BH.starburst, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 1.6, 1, 2.3),
		Transparency = seq(0, 0.2, 0.7, 0.4, 1, 1), Color = cseq(0, FIRE_CORE, 1, FIRE), Lifetime = R(0.45), Rotation = R(0, 360),
		LightEmission = 1, Brightness = 2, ZOffset = 1.9,
	})
	burst(pHeart, "Embers", 12, {
		Texture = BH.ember, Orientation = streak, EmissionDirection = up, Size = seq(0, 0.12, 1, 0), Transparency = NS(0),
		Color = cseq(0, FIRE_WHITE, 0.5, FIRE_CORE, 1, FIRE), Lifetime = R(0.5, 0.9), Speed = R(8, 14), Drag = 4,
		SpreadAngle = Vector2.new(70, 70), Acceleration = V3(0, -3, 0), LightEmission = 1, Brightness = 3,
	})
	local pBase = part("Base", pulseM, CFrame.new(0, 0.2, 0), V3(2.8, 0.1, 2.8))
	burst(pBase, "Roar", 6, {
		Texture = BH.jet, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = seq(0, 0.6, 0.3, 1.2, 1, 0.4),
		Transparency = seq(0, 0.15, 0.6, 0.3, 1, 1), Color = fireColor, Lifetime = R(0.4, 0.6), Speed = R(5, 8),
		SpreadAngle = Vector2.new(8, 8), Rotation = R(-8, 8), LightEmission = 0.8, Brightness = 2, ZOffset = 0.6,
	})
	burst(pBase, "Fire", 5, {
		Texture = BH.flame, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = disc, ShapeStyle = volume,
		EmissionDirection = up, Size = seq(0, 0.7, 0.4, 1.1, 1, 0.4), Transparency = seq(0, 0.15, 0.7, 0.35, 1, 1),
		Color = fireColor, Lifetime = R(0.7, 0.9), Speed = R(2, 3.5), Acceleration = V3(0, 4, 0), Rotation = R(-10, 10),
		LightEmission = 0.7, Brightness = 2, ZOffset = 0.5,
	})
	burst(pBase, "Ring", 1, B.flat({
		Texture = BH.ring, Size = seq(0, 1, 1, 3.4), Transparency = seq(0, 0.15, 0.6, 0.5, 1, 1), Color = CS(FIRE_CORE),
		Lifetime = R(0.5), LightEmission = 1, Brightness = 2, ZOffset = 0.3,
	}))

	-- ignition: a short, punchy flare on and near the body
	local ignite = model("Ignite", m)
	local heart = at("Chest", CFrame.new(0, 0, -0.3), "Chest", ignite)
	burst(heart, "Flash", 1, {
		Texture = BH.dot, Size = seq(0, 0.6, 0.15, 1.8, 1, 2.1), Transparency = seq(0, 0, 0.4, 0.5, 1, 1), Color = cseq(0, FIRE_WHITE, 1, FIRE_CORE),
		Lifetime = R(0.4), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(heart, "Star", 1, {
		Texture = BH.chroma, Size = seq(0, 0.8, 0.25, 4.2, 1, 0), Transparency = NS(0), Color = CS(FIRE_WHITE),
		Lifetime = R(0.45), Rotation = R(0), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(heart, "Star45", 1, {
		Texture = BH.star, Size = seq(0, 0.4, 0.25, 2.2, 1, 0), Transparency = NS(0), Color = CS(FIRE_CORE),
		Lifetime = R(0.4), Rotation = R(45), LightEmission = 1, Brightness = 3, ZOffset = 2.05,
	})
	burst(heart, "Burst", 1, {
		Texture = BH.starburst, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 2.2, 1, 3.2),
		Transparency = seq(0, 0, 0.7, 0.2, 1, 1), Color = cseq(0, FIRE_CORE, 1, FIRE), Lifetime = R(0.55), Rotation = R(0, 360),
		LightEmission = 1, Brightness = 2, ZOffset = 1.9,
	})
	burst(heart, "Embers", 26, {
		Texture = BH.ember, Orientation = streak, EmissionDirection = up, Size = seq(0, 0.14, 1, 0), Transparency = NS(0),
		Color = cseq(0, FIRE_WHITE, 0.5, FIRE_CORE, 1, FIRE), Lifetime = R(0.6, 1.1), Speed = R(10, 18), Drag = 4,
		SpreadAngle = Vector2.new(80, 80), Acceleration = V3(0, -3, 0), LightEmission = 1, Brightness = 3,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3, 0.1, 3))
	burst(base, "Roar", 16, {
		Texture = BH.jet, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = seq(0, 0.7, 0.3, 1.5, 1, 0.5),
		Transparency = seq(0, 0.1, 0.6, 0.25, 1, 1), Color = fireColor, Lifetime = R(0.45, 0.65), Speed = R(6, 9),
		SpreadAngle = Vector2.new(8, 8), Rotation = R(-8, 8), LightEmission = 0.8, Brightness = 2, ZOffset = 0.6,
	})
	burst(base, "Fire", 10, {
		Texture = BH.flame, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = disc, ShapeStyle = volume,
		EmissionDirection = up, Size = seq(0, 0.9, 0.4, 1.3, 1, 0.5), Transparency = seq(0, 0.1, 0.7, 0.3, 1, 1),
		Color = fireColor, Lifetime = R(0.8, 1), Speed = R(2, 4), Acceleration = V3(0, 4, 0), Rotation = R(-10, 10),
		LightEmission = 0.7, Brightness = 2, ZOffset = 0.5,
	}, { EmitDelay = 0.05 })
	burst(base, "Spray", 1, {
		Texture = BH.spray, Size = seq(0, 1.2, 0.3, 2.6, 1, 2.8), Transparency = seq(0, 0, 0.5, 0.3, 1, 1),
		Color = cseq(0, FIRE_WHITE, 1, FIRE), Lifetime = R(0.35), LightEmission = 1, Brightness = 2, ZOffset = 0.7,
	})
	burst(base, "Ring", 1, B.flat({
		Texture = BH.ring, Size = seq(0, 1, 1, 4.2), Transparency = seq(0, 0, 0.6, 0.4, 1, 1), Color = CS(FIRE_CORE),
		Lifetime = R(0.5), LightEmission = 1, Brightness = 2, ZOffset = 0.3,
	}))
	burst(base, "BurnRing", 1, B.flat({
		Texture = BH.burnRing, FlipbookLayout = grid2, FlipbookMode = oneShot, Size = seq(0, 1.6, 1, 3.6),
		Transparency = seq(0, 0, 0.7, 0.2, 1, 1), Color = CS(rgb(255, 200, 150)), Lifetime = R(1), Rotation = R(0, 360),
		LightEmission = 0.6, Brightness = 2, ZOffset = 0.25,
	}))
	burst(base, "Soot", 8, {
		Texture = BH.soot, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, EmissionDirection = front,
		SpreadAngle = Vector2.new(5, 180), Size = seq(0, 0.6, 1, 1.5), Transparency = seq(0, 0.2, 1, 1), Color = CS(SOOT),
		Lifetime = R(0.8, 1.1), Speed = R(5, 8), Drag = 3, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	})
	return m
end

-- ---------------------------------------------------------------- Flowing Spring (Water)
-- Qi gathers like water into a still pool (Mortal: small, close). Rebuilt
-- 2026-10-21 from layered library emissions (ref: the water aura in
-- docs/reference/vfx/README.md; Sol's RNG). Back to front:
--   ground  a deep-blue pool (dark base), a watery surface sheet with soft
--           caustics, slow ripples crossing it, a swirl drawing in to the
--           seat, bubbles rising off it
--   body    a water ring turning round the figure from behind (on a darker
--           copy of itself), a pearl of water at the belly with a white-hot
--           heart and a glint (the one light), water curls lifting off the
--           arms and torso, droplets streaming in to the pearl on the inhale
--   breath  the exhale: a ripple and a breaking ring cross the pool, the
--           pearl glints, a few drops hop off the surface
--   punch   every 2 or 3 breaths a drop of qi falls from above into the
--           pool: a splash crown round the seat, a big ripple, the pearl
--           flashes, the curls surge
--   ignite  the pool springs up: a white flash at the pearl, water columns
--           and a splash crown round the body, a wave ring, drops thrown up

local WATER_WHITE, WATER_CORE, WATER, WATER_DEEP = rgb(235, 250, 255), rgb(165, 220, 255), rgb(75, 165, 255), rgb(25, 90, 210)
local WATER_INK = rgb(6, 22, 52)

local FS = {
	glow = id(6673021984), -- soft round glow
	core = id(13280146664), -- small hot glow
	glint = id(13271102367), -- small 4-point star
	pearl = id(15024914905), -- a ball of water (top-down puddle as a flat particle)
	caustics = id(5722422984), -- water caustics tile
	ripple = id(89560315838742), -- 4x4 flipbook: a wobbling water ring
	breakRing = id(89798462580462), -- 4x4 flipbook: a water ring breaking up
	swirl = id(6700006778), -- water swirl stroke
	arc = id(135596833550213), -- curved water stroke (an arc of a ring)
	curl = id(14191030010), -- 4x4 flipbook: a water curl
	wisp = id(12110213243), -- 4x4 flipbook: a water wisp lifting
	splash = id(14944433028), -- 4x4 flipbook: a splash bursting
	column = id(12800352943), -- 4x4 flipbook: a water column rising and breaking
	drop = id(7104844885), -- teardrop
	bubble = id(249902641), -- bubble
	streak = id(9841260008), -- soft streak
}
_G.FlowingSpringAssets = FS

local waterColor = cseq(0, WATER_WHITE, 0.4, WATER_CORE, 1, WATER)

local function flowingSpring(root)
	-- a drop falls into the pool every 2 or 3 breaths, on the beat
	local m = model("FlowingSpring", root, { PunchEvery = R(2, 3), PunchJitter = 0.4, PunchSwell = 1.3 })

	-- ground: the pool (within ~1 body-width)
	local ground = model("Ground", m)
	local floor = part("Floor", ground, CFrame.new(0, 0.12, 0), V3(0.1, 0.1, 0.1)) -- centred flats
	local pool = part("Pool", ground, CFrame.new(0, 0.15, 0), V3(3.6, 0.1, 3.6)) -- spread over the pool
	loop(floor, "Deep", B.flat({ -- the dark base: deep water under everything bright
		Texture = FS.pearl, Size = NS(2.6), Transparency = seq(0, 1, 0.25, 0.12, 0.75, 0.12, 1, 1), Color = CS(WATER_INK),
		Lifetime = R(5), Rate = 0.5, Rotation = R(0, 360), RotSpeed = R(-4, 4), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Surface", B.flat({
		Texture = FS.pearl, Size = NS(2.35), Transparency = seq(0, 1, 0.3, 0.5, 0.7, 0.5, 1, 1),
		Color = cseq(0, WATER_CORE, 1, WATER), Lifetime = R(5), Rate = 0.4, Rotation = R(0, 360), RotSpeed = R(-6, 6),
		LightEmission = 0.4, Brightness = 1.5, ZOffset = 0.05,
	}), { Prime = 2, Swell = 0.05, Drift = 0.04 })
	-- soft caustics in the pool: a round image, drifting round
	local caustics = decalDisc("Caustics", ground, 3.5, 0.17, FS.caustics, rgb(150, 230, 255), {
		Pulse = R(0.6, 0.76), Turn = 5, Grow = R(0.97, 1.03),
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = caustics:FindFirstChildWhichIsA("ImageLabel", true)
	loop(pool, "Ripples", B.flat({
		Texture = FS.ripple, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(8, 10),
		Size = seq(0, 0.2, 1, 0.75), Transparency = seq(0, 1, 0.2, 0.25, 0.7, 0.5, 1, 1), Color = CS(WATER_WHITE),
		Lifetime = R(1.8), Rate = 1.6, Rotation = R(0, 360), LightEmission = 0.6, Brightness = 2, ZOffset = 0.15,
	}), { Prime = 2, Breathe = R(0.6, 1.5) })
	loop(floor, "Swirl", B.flat({
		Texture = FS.swirl, Size = seq(0, 2.5, 1, 1.6), Transparency = seq(0, 1, 0.35, 0.45, 0.75, 0.5, 1, 1),
		Color = CS(WATER_CORE), Lifetime = R(3), Rate = 0.7, Rotation = R(0, 360), RotSpeed = R(-50, -40),
		LightEmission = 0.7, Brightness = 2, ZOffset = 0.1,
	}), { Prime = 2, Breathe = R(0.7, 1.3), Swell = 0.08, Drift = 0.05 })
	loop(pool, "Bubbles", {
		Texture = FS.bubble, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.05, 0.11),
		Transparency = seq(0, 1, 0.15, 0.2, 0.85, 0.3, 1, 1), Color = CS(WATER_WHITE), Lifetime = R(1.4, 2.2),
		Speed = R(0.6, 1.2), Acceleration = V3(0, 0.4, 0), SpreadAngle = Vector2.new(10, 10), Rate = 2.5, LightEmission = 0.3,
	}, { Scaled = true, Breathe = R(0.6, 1.4) })

	-- body: the pearl at the belly and the water ring round the figure
	local body = model("Body", m)
	local pearl = at("Belly", CFrame.new(0, 0.05, -0.25), "Pearl", body)
	light(pearl, WATER, 8, 1.3)
	loop(pearl, "Orb", {
		Texture = FS.pearl, Size = NS(0.42), Transparency = seq(0, 1, 0.3, 0.15, 0.7, 0.15, 1, 1),
		Color = cseq(0, WATER_CORE, 1, WATER), Lifetime = R(1.2), Rate = 2, Rotation = R(0, 360), RotSpeed = R(-30, 30),
		LightEmission = 0.6, Brightness = 2, ZOffset = 1.4, LockedToPart = true,
	}, { Prime = 2, Swell = 0.35 })
	loop(pearl, "Hot", {
		Texture = FS.core, Size = NS(0.3), Transparency = seq(0, 1, 0.3, 0.05, 1, 1), Color = CS(WATER_WHITE),
		Lifetime = R(0.5), Rate = 5, LightEmission = 1, Brightness = 3, ZOffset = 1.5, LockedToPart = true,
	}, { Prime = 2, Swell = 0.3 })
	loop(pearl, "Glint", {
		Texture = FS.glint, Size = seq(0, 0, 0.3, 0.55, 1, 0), Transparency = NS(0), Color = CS(WATER_WHITE),
		Lifetime = R(0.6), Rate = 0.7, Rotation = R(-10, 10), LightEmission = 1, Brightness = 3, ZOffset = 1.6, LockedToPart = true,
	})
	-- droplets drawn in from all round to the pearl, faster on the inhale
	local shell = at("Belly", CFrame.new(0, 0, -0.2), "Inflow", body, V3(4.2, 3.4, 4.2))
	loop(shell, "Inflow", {
		Texture = FS.streak, Shape = sphere, ShapeStyle = surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Orientation = streak, Size = seq(0, 0.05, 0.4, 0.13, 1, 0.03), Transparency = seq(0, 1, 0.3, 0.1, 0.85, 0.2, 1, 1),
		Color = cseq(0, WATER_CORE, 1, WATER_WHITE), Lifetime = R(0.7, 0.8), Speed = R(2.6), Rate = 6, LightEmission = 0.8,
		Brightness = 2,
	}, { Scaled = true, Breathe = R(0.3, 1.6) })
	-- a ring of water turning round the figure from behind, dark under bright
	local ringAt = at("Dantian", CFrame.new(0, 0.85, 0.45), "Ring", body)
	loop(ringAt, "RingDark", {
		Texture = FS.arc, Size = NS(2.15), Transparency = seq(0, 1, 0.25, 0.5, 0.75, 0.5, 1, 1), Color = CS(WATER_INK),
		Lifetime = R(1.8), Rate = 1.1, Rotation = R(0, 360), RotSpeed = R(-70, -55), LightEmission = 0, ZOffset = -0.7,
		LockedToPart = true,
	}, { Prime = 2, Swell = 0.06, Drift = 0.05 })
	loop(ringAt, "Ring", {
		Texture = FS.arc, Size = NS(1.95), Transparency = seq(0, 1, 0.25, 0.15, 0.75, 0.25, 1, 1),
		Color = cseq(0, WATER_WHITE, 1, WATER_CORE), Lifetime = R(1.6), Rate = 1.4, Rotation = R(0, 360), RotSpeed = R(-75, -60),
		LightEmission = 0.8, Brightness = 2, ZOffset = -0.4, LockedToPart = true,
	}, { Prime = 2, Breathe = R(0.7, 1.4), Swell = 0.06, Drift = 0.05 })

	-- limbs: water curls and wisps lifting off the surface
	local limbs = folder("Limbs", m)
	loop(limbs, "Curls", {
		Texture = FS.curl, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, ShapeStyle = surface,
		EmissionDirection = up, Size = seq(0, 0.35, 1, 0.6), Transparency = seq(0, 0.6, 0.2, 0.1, 0.8, 0.3, 1, 1),
		Color = cseq(0, WATER_WHITE, 0.5, WATER_CORE, 1, WATER), Lifetime = R(0.9, 1.1), Speed = R(0.4, 0.9),
		Acceleration = V3(0, 1.2, 0), Rotation = R(0, 360), RotSpeed = R(-40, 40), Rate = 2.2, LightEmission = 0.6,
		Brightness = 2, ZOffset = 0.4,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.6, 1.4), Surge = 5, PunchSurge = 2, Swell = 0.15, Drift = 0.08 })
	loop(limbs, "Wisps", {
		Texture = FS.wisp, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, ShapeStyle = surface,
		EmissionDirection = up, Size = seq(0, 0.3, 1, 0.5), Transparency = seq(0, 0.4, 0.2, 0.15, 1, 1),
		Color = cseq(0, WATER_WHITE, 1, WATER_CORE), Lifetime = R(0.7, 0.9), Speed = R(0.5, 0.9), Acceleration = V3(0, 0.6, 0),
		Rotation = R(-20, 20), Rate = 1.2, LightEmission = 0.5, Brightness = 2, ZOffset = 0.3,
	}, { On = "Arms", Scaled = true, Surge = 3 })

	-- the exhale: a ripple and a breaking ring across the pool, drops hop off it
	local breath = model("Breath", m)
	local bFloor = part("Floor", breath, CFrame.new(0, 0.2, 0), V3(2.6, 0.1, 2.6))
	burst(bFloor, "Ripple", 1, B.flat({
		Texture = FS.ripple, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(10),
		Size = seq(0, 0.6, 1, 2.1), Transparency = seq(0, 0.1, 0.6, 0.4, 1, 1), Color = CS(WATER_WHITE),
		Lifetime = R(1.4), LightEmission = 0.8, Brightness = 2, ZOffset = 0.2,
	}))
	burst(bFloor, "Break", 1, B.flat({
		Texture = FS.breakRing, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 0.9, 1, 1.9),
		Transparency = seq(0, 0.2, 1, 0.6), Color = CS(WATER_CORE), Lifetime = R(1), Rotation = R(0, 360),
		LightEmission = 0.7, Brightness = 2, ZOffset = 0.18,
	}), { EmitDelay = 0.25 })
	burst(bFloor, "Hop", 4, {
		Texture = FS.drop, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Orientation = streak,
		Size = rnd(0.06, 0.09), Transparency = seq(0, 0.1, 0.8, 0.2, 1, 1), Color = CS(WATER_WHITE), Lifetime = R(0.5, 0.7),
		Speed = R(3, 4.5), SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0, -14, 0), LightEmission = 0.6, Brightness = 2,
	})
	local bPearl = at("Belly", CFrame.new(0, 0.05, -0.3), "Pearl", breath)
	burst(bPearl, "Glint", 1, {
		Texture = FS.glint, Size = seq(0, 0.3, 0.3, 1.1, 1, 0), Transparency = NS(0), Color = CS(WATER_WHITE),
		Lifetime = R(0.35), Rotation = R(0, 15), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	})

	-- a pulse: a drop of qi falls from above into the pool
	local pulseM = model("Punch", m)
	local sky = part("Sky", pulseM, CFrame.new(0, 6.2, -0.9))
	burst(sky, "Drop", 1, {
		Texture = FS.drop, EmissionDirection = Enum.NormalId.Bottom, Orientation = streak, Size = seq(0, 0.16, 1, 0.24),
		Transparency = seq(0, 0.6, 0.3, 0, 1, 0), Color = CS(WATER_WHITE), Lifetime = R(0.36), Speed = R(16),
		LightEmission = 0.9, Brightness = 3, ZOffset = 1,
	})
	burst(sky, "Trail", 1, {
		Texture = FS.streak, EmissionDirection = Enum.NormalId.Bottom, Orientation = streak, Size = seq(0, 0.08, 1, 0.3),
		Transparency = seq(0, 1, 0.5, 0.2, 1, 1), Color = CS(WATER_CORE), Lifetime = R(0.36), Speed = R(15),
		LightEmission = 1, Brightness = 2,
	})
	local pBase = part("Base", pulseM, CFrame.new(0, 0.2, 0), V3(2.8, 0.1, 2.8))
	local land = { EmitDelay = 0.36 }
	burst(pBase, "Crown", 12, {
		Texture = FS.splash, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = disc,
		ShapeStyle = volume, ShapePartial = 0.8, EmissionDirection = up, Size = seq(0, 0.45, 1, 0.85), Transparency = seq(0, 0.05, 0.7, 0.2, 1, 1),
		Color = waterColor, Lifetime = R(0.55, 0.7), Speed = R(1.5, 2.5), Acceleration = V3(0, -3, 0), Rotation = R(-15, 15),
		LightEmission = 0.6, Brightness = 2, ZOffset = 0.6,
	}, land)
	burst(pBase, "Ripple", 1, B.flat({
		Texture = FS.ripple, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(12),
		Size = seq(0, 0.8, 1, 2.8), Transparency = seq(0, 0, 0.6, 0.35, 1, 1), Color = CS(WATER_WHITE),
		Lifetime = R(1.2), LightEmission = 0.9, Brightness = 2, ZOffset = 0.25,
	}), land)
	burst(pBase, "Drops", 8, {
		Texture = FS.drop, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Orientation = streak,
		Size = rnd(0.07, 0.11), Transparency = seq(0, 0, 0.8, 0.2, 1, 1), Color = CS(WATER_WHITE), Lifetime = R(0.6, 0.8),
		Speed = R(4.5, 6.5), SpreadAngle = Vector2.new(35, 35), Acceleration = V3(0, -16, 0), LightEmission = 0.6, Brightness = 2,
	}, land)
	local pPearl = at("Belly", CFrame.new(0, 0.05, -0.3), "Pearl", pulseM)
	burst(pPearl, "Flash", 1, {
		Texture = FS.core, Size = seq(0, 0.4, 0.25, 1, 1, 1.1), Transparency = seq(0, 0.05, 0.4, 0.5, 1, 1),
		Color = cseq(0, WATER_WHITE, 1, WATER_CORE), Lifetime = R(0.35), LightEmission = 1, Brightness = 3, ZOffset = 2,
	}, land)
	burst(pPearl, "Star", 1, {
		Texture = FS.glint, Size = seq(0, 0.3, 0.25, 1.7, 1, 0), Transparency = NS(0), Color = CS(WATER_WHITE),
		Lifetime = R(0.4), Rotation = R(0, 15), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	}, land)

	-- ignition: the pool springs up round the body
	local ignite = model("Ignite", m)
	local core = at("Belly", CFrame.new(0, 0.05, -0.3), "Pearl", ignite)
	burst(core, "Flash", 1, {
		Texture = FS.core, Size = seq(0, 0.6, 0.15, 1.6, 1, 1.9), Transparency = seq(0, 0, 0.4, 0.45, 1, 1),
		Color = cseq(0, WATER_WHITE, 1, WATER_CORE), Lifetime = R(0.45), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(core, "Star", 1, {
		Texture = FS.glint, Size = seq(0, 0.6, 0.25, 3.2, 1, 0), Transparency = NS(0), Color = CS(WATER_WHITE),
		Lifetime = R(0.5), Rotation = R(0, 10), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(core, "Orb", 1, {
		Texture = FS.pearl, Size = seq(0, 0.5, 0.3, 1.5, 1, 1.8), Transparency = seq(0, 0.1, 1, 1),
		Color = cseq(0, WATER_WHITE, 1, WATER_CORE), Lifetime = R(0.5), Rotation = R(0, 360), LightEmission = 0.7,
		Brightness = 2, ZOffset = 1.9,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3, 0.1, 3))
	burst(base, "Columns", 7, {
		Texture = FS.column, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = disc,
		ShapeStyle = volume, ShapePartial = 0.8, EmissionDirection = up, Size = seq(0, 0.7, 1, 1.1), Transparency = seq(0, 0, 0.7, 0.15, 1, 1),
		Color = waterColor, Lifetime = R(0.7, 0.9), Speed = R(1.5, 2.5), Rotation = R(-8, 8), LightEmission = 0.6,
		Brightness = 2, ZOffset = 0.6,
	})
	burst(base, "Crown", 10, {
		Texture = FS.splash, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = disc,
		ShapeStyle = volume, ShapePartial = 0.8, EmissionDirection = up, Size = seq(0, 0.5, 1, 0.95), Transparency = seq(0, 0, 0.7, 0.2, 1, 1),
		Color = waterColor, Lifetime = R(0.6, 0.8), Speed = R(2.5, 4), Acceleration = V3(0, -5, 0), Rotation = R(-15, 15),
		LightEmission = 0.6, Brightness = 2, ZOffset = 0.5,
	}, { EmitDelay = 0.05 })
	burst(base, "Wave", 1, B.flat({
		Texture = FS.ripple, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(14),
		Size = seq(0, 1, 1, 3.8), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = CS(WATER_WHITE),
		Lifetime = R(0.8), LightEmission = 0.9, Brightness = 2, ZOffset = 0.3,
	}))
	burst(base, "Break", 1, B.flat({
		Texture = FS.breakRing, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 1.4, 1, 3.1),
		Transparency = seq(0, 0, 1, 0.5), Color = CS(WATER_CORE), Lifetime = R(0.9), Rotation = R(0, 360),
		LightEmission = 0.7, Brightness = 2, ZOffset = 0.28,
	}), { EmitDelay = 0.1 })
	burst(base, "Drops", 18, {
		Texture = FS.drop, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Orientation = streak,
		Size = rnd(0.08, 0.13), Transparency = seq(0, 0, 0.8, 0.2, 1, 1), Color = CS(WATER_WHITE), Lifetime = R(0.7, 1),
		Speed = R(6, 9), SpreadAngle = Vector2.new(30, 30), Acceleration = V3(0, -20, 0), LightEmission = 0.6, Brightness = 2,
	})
	burst(base, "Deep", 1, B.flat({ -- the pool darkens under the burst
		Texture = FS.glow, Size = seq(0, 2, 1, 2.8), Transparency = seq(0, 0.2, 1, 1), Color = CS(WATER_INK),
		Lifetime = R(0.9), LightEmission = 0, ZOffset = 0.02,
	}))
	return m
end

-- ---------------------------------------------------------------- Evergreen Root (Wood)
-- An old tree, patient growth: meridian branches grow from the belly out
-- along the arms and legs, lighting over a few breaths; thin roots spread
-- on the ground; a few slow leaves (ref spirit_manifest_green, constellation).

local WOOD_CORE, WOOD, WOOD_DEEP = rgb(200, 255, 160), rgb(110, 225, 90), rgb(50, 140, 50)
local WOOD_DOT = rgb(235, 255, 150)

local function evergreen(root)
	local m = model("EverGreen", root)
	shell(m, rgb(120, 230, 90), { Pulse = R(0.84, 0.94), Pad = 0.2, Delay = 1 }, Enum.Material.Neon)

	local body = model("Body", m)
	ball("Seed", body, 0.38, CFrame.new(0, 0, -0.1), WOOD_DOT, { Point = "Belly", Pulse = R(0, 0.2), Grow = R(0.85, 1.15) })

	local lines = folder("Lines", m)
	local props = {
		Color = CS(WOOD_CORE), Width0 = 0.16, Width1 = 0.11, Brightness = 3, LightEmission = 0.3,
		Transparency = NS(0),
	}
	-- trunk first, then out to the shoulders and hips, then the limbs
	for _, l in {
		{ "Belly", "Chest", 0 }, { "Chest", "Neck", 2 }, { "Neck", "Head", 6 },
		{ "Chest", "LShoulder", 2.5 }, { "Chest", "RShoulder", 2.5 },
		{ "LShoulder", "LElbow", 5 }, { "RShoulder", "RElbow", 5 },
		{ "LElbow", "LHand", 7.5 }, { "RElbow", "RHand", 7.5 },
		{ "Belly", "LHip", 2.5 }, { "Belly", "RHip", 2.5 },
		{ "LHip", "LKnee", 5 }, { "RHip", "RKnee", 5 },
	} do
		beam(lines, l[1] .. "_" .. l[2], l[1], l[2], props, {
			Pulse = R(0, 0.3), Delay = l[3], Dots = 0.5, DotColor = WOOD_DOT,
		})
	end

	-- roots creeping out over the ground, two crooked segments each
	local ground = model("Ground", m)
	for i = 1, 6 do
		local yaw = math.rad((i - 1) * 60 + 20)
		local bend = math.rad(if i % 2 == 0 then 22 else -22)
		local dir = CFrame.Angles(0, yaw, 0)
		local a = dir * CFrame.new(0, 0.06, -1.6)
		part("Root" .. i .. "a", ground, a, V3(0.11, 0.05, 1.4), { Pulse = R(0.2, 0.5), Delay = 1 + i * 0.4 }).Color = WOOD
		local b = dir * CFrame.new(0, 0.06, -2.3) * CFrame.Angles(0, bend, 0) * CFrame.new(0, 0, -0.6)
		part("Root" .. i .. "b", ground, b, V3(0.07, 0.04, 1.2), { Pulse = R(0.3, 0.6), Delay = 3.5 + i * 0.4 }).Color = WOOD_DEEP
	end
	local canopy = part("Canopy", ground, CFrame.new(0, 5.5, 0), V3(5, 0.2, 5))
	loop(canopy, "Leaves", {
		Texture = A.leaf, Shape = box, EmissionDirection = Enum.NormalId.Bottom,
		Size = rnd(0.25, 0.38), Transparency = seq(0, 1, 0.12, 0, 0.85, 0.05, 1, 1),
		Color = cseq(0, WOOD_CORE, 1, WOOD), Lifetime = R(4, 5), Speed = R(0.8, 1.2), SpreadAngle = Vector2.new(25, 25),
		Acceleration = V3(0.25, -0.1, 0), Rotation = R(0, 360), RotSpeed = R(-90, 90), Rate = 0.8, LightEmission = 0.15,
	}, { Scaled = true })

	-- each breath: sap motes rising off the seed, a green ring breathing out
	local breath = model("Breath", m)
	local belly = at("Belly", nil, "Belly", breath)
	burst(belly, "Sap", 5, {
		Size = seq(0, 0, 0.2, 0.18, 1, 0), Transparency = seq(0, 0.1, 1, 1), Color = CS(WOOD_DOT),
		Lifetime = R(1.4, 2), Speed = R(1, 2), SpreadAngle = Vector2.new(60, 60), EmissionDirection = up,
		LightEmission = 0.5, Drag = 0.6, ZOffset = 0.8,
	})
	local floor = part("Floor", breath, CFrame.new(0, 0.12, 0))
	wave(floor, "Out", {
		mesh = A.torus, color = WOOD, fromSize = ring(3, 1.6), toSize = ring(6.6, 1),
		fromTransparency = 0.3, toTransparency = 1, duration = 1.6, style = "Sine",
	})

	-- ignition: a green ring bursts out of the ground, leaves whirl up
	local ignite = model("Ignite", m)
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(4, 0.2, 4))
	wave(base, "Sprout", {
		mesh = A.torus, color = WOOD, fromSize = ring(2, 3), toSize = ring(10, 1.3),
		fromTransparency = 0, toTransparency = 1, duration = 1, style = "Quint",
	})
	wave(base, "Rise", {
		mesh = A.swirlRing, color = WOOD_CORE, fromSize = V3(6, 1.4, 6), toSize = V3(2.4, 2.4, 2.4),
		toOffset = V3(0, 5, 0), fromTransparency = 0.1, toTransparency = 1, duration = 1.1, style = "Quad",
	})
	burst(base, "Leaves", 16, {
		Texture = A.leaf, Shape = disc, ShapeStyle = volume, EmissionDirection = up,
		Size = rnd(0.35, 0.55), Transparency = seq(0, 0, 0.8, 0.1, 1, 1), Color = cseq(0, WOOD_CORE, 1, WOOD),
		Lifetime = R(1.4, 2), Speed = R(5, 8), SpreadAngle = Vector2.new(35, 35), Drag = 1.2,
		Rotation = R(0, 360), RotSpeed = R(-200, 200), LightEmission = 0.15,
	})
	return m
end

-- ---------------------------------------------------------------- Iron Marrow (Metal)
-- Qi hammered into the bones (Mortal: small, close). Rebuilt 2026-10-21 from
-- layered library emissions (ref: docs/reference/auras/sunburst_diamond_core;
-- Sol's RNG). The rhythm is a forge: every exhale a hammer clang. Back to front:
--   ground  a black spiked iron ring (dark base, blades), an ornate gold ring
--           turning the other way inside it, a molten glow, a spiky gold
--           spark-splash flickering on the floor, metal filings lifting
--   body    a hard white-gold diamond between the hands (a small spinning
--           gem in support, a glow that swells, a white-hot dot, a long-armed
--           star, a dark iron halo behind it, the one light); gold bone lines
--           along the arms and spine with star glints at the joints; a cold
--           needle glint running over the limbs; forge sparks spitting off
--           the hands
--   breath  the clang: a spiky ring snaps out of the diamond with a star and
--           sparks, a thin ring runs over the floor, bones and rings flash
--   punch   every 2 or 3 breaths a heavier blow: gold rays fan out behind
--           the body, a big clang ring, a spiky ring over the ground, a spark
--           shower and filings thrown out
--   ignite  a white flash and star at the diamond, rays behind, two clang
--           rings (facing you and over the ground), a spark shower, a spiky
--           gold burst on the floor, shards thrown out; limb glints surge

local GOLD_WHITE, GOLD_CORE, GOLD, GOLD_DEEP = rgb(255, 250, 228), rgb(255, 222, 135), rgb(242, 172, 55), rgb(160, 88, 18)
local IRON, STEEL = rgb(22, 20, 24), rgb(210, 220, 238)

local IM = {
	glow = id(6673021984), -- soft round glow
	hot = id(13280146664), -- small hot glow
	star = id(8037777212), -- 4-point star with long arms
	needle = id(7814053668), -- vertical needle glint
	cross = id(271370648), -- X glint
	cracks = id(18457400581), -- 2x2 flipbook: sharp sparkle cracks
	spikeRing = id(110193486541760), -- black spiked ring with white edges
	ornate = id(13399941667), -- ornate filigree ring
	clang = id(13052235894), -- spiky ring burst
	splash = id(13964665265), -- spiky radial burst
	rays = id(15773612675), -- sunburst rays
	softRays = id(1598630577), -- soft sunburst rays
	thinRing = id(6250126210), -- thin ring sweep
	shards = id(140013412087432), -- 8x8 sheet of metal shards
	spark = id(9841260008), -- soft streak
}
_G.IronMarrowAssets = IM

local grid8 = Enum.ParticleFlipbookLayout.Grid8x8
local randomFb = Enum.ParticleFlipbookMode.Random
local goldColor = cseq(0, GOLD_WHITE, 0.35, GOLD_CORE, 1, GOLD)

local function ironMarrow(root)
	-- a heavier blow every 2 or 3 breaths, on the clang
	local m = model("IronMarrow", root, { PunchEvery = R(2, 3), PunchJitter = 0.3, PunchSwell = 1.3 })

	-- ground: the forge floor (within ~1 body-width)
	local ground = model("Ground", m)
	decalDisc("IronRing", ground, 5.6, 0.13, IM.spikeRing, rgb(225, 225, 235), {
		Pulse = R(0.04, 0.14), Turn = 7, Grow = R(0.98, 1.02),
	})
	decalDisc("GoldRing", ground, 4.5, 0.16, IM.ornate, GOLD_CORE, {
		Pulse = R(0.15, 0.45), Turn = -11, Grow = R(0.97, 1.04), Kick = 0.8,
	})
	local floor = part("Floor", ground, CFrame.new(0, 0.18, 0), V3(0.1, 0.1, 0.1)) -- centred flats
	loop(floor, "Molten", B.flat({
		Texture = IM.glow, Size = NS(2.5), Transparency = seq(0, 1, 0.3, 0.2, 0.7, 0.2, 1, 1), Color = cseq(0, GOLD, 1, GOLD_DEEP),
		Lifetime = R(3), Rate = 0.7, Rotation = R(0, 360), LightEmission = 1, Brightness = 2, ZOffset = 0.05,
	}), { Prime = 2, Breathe = R(0.6, 1.4), Swell = 0.1, Drift = 0.05 })
	local pool = part("Pool", ground, CFrame.new(0, 0.2, 0), V3(3.8, 0.1, 3.8))
	-- gold streaks rising round the seat, the forge's heat (more on the inhale)
	loop(pool, "Rise", {
		Texture = IM.needle, Shape = disc, ShapeStyle = volume, ShapePartial = 0.75, EmissionDirection = up,
		Size = seq(0, 0.45, 0.4, 1, 1, 0.6), Transparency = seq(0, 1, 0.25, 0.15, 1, 1), Color = goldColor,
		Lifetime = R(0.6, 0.9), Speed = R(2, 3.2), Rate = 9, LightEmission = 1, Brightness = 2, ZOffset = 0.2,
	}, { Scaled = true, Breathe = R(0.4, 1.6), Swell = 0.2, Drift = 0.1 })
	loop(pool, "Splash", B.flat({ -- spark-splashes popping on the forge floor
		Texture = IM.splash, Shape = disc, ShapeStyle = volume, ShapePartial = 0.55, Size = seq(0, 0.45, 1, 0.8),
		Transparency = seq(0, 0.6, 0.2, 0.1, 1, 1), Color = goldColor, Lifetime = R(0.35, 0.5), Rate = 4,
		Rotation = R(0, 360), LightEmission = 1, Brightness = 2.5, ZOffset = 0.12,
	}), { Scaled = true, Breathe = R(0.4, 1.6), Swell = 0.15 })
	loop(pool, "Filings", {
		Texture = IM.shards, FlipbookLayout = grid8, FlipbookMode = randomFb, Shape = disc, ShapeStyle = volume,
		EmissionDirection = up, Size = rnd(0.05, 0.09), Transparency = seq(0, 1, 0.15, 0.05, 0.8, 0.2, 1, 1),
		Color = cseq(0, STEEL, 1, GOLD_CORE), Lifetime = R(1.6, 2.4), Speed = R(0.4, 0.9), Acceleration = V3(0, 0.3, 0),
		Rotation = R(0, 360), RotSpeed = R(-200, 200), Rate = 3, LightEmission = 0.5, Brightness = 2,
	}, { Scaled = true, Breathe = R(0.4, 1.4) })

	-- body: the diamond between the hands
	local body = model("Body", m)
	local gem = part("Diamond", body, CFrame.new(0, 0.35, -0.15) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), V3(0.34, 0.34, 0.34), {
		Point = "Lap", Pulse = R(0.05, 0.2), Grow = R(0.92, 1.08), Turn = 80, Kick = 1,
	})
	gem.Color = rgb(255, 214, 120)
	local core = at("Lap", CFrame.new(0, 0.35, -0.2), "Core", body)
	light(core, GOLD, 8, 1.6)
	loop(core, "Halo", { -- the dark iron behind the bright gem
		Texture = IM.glow, Size = NS(0.75), Transparency = seq(0, 1, 0.3, 0.25, 0.7, 0.25, 1, 1), Color = CS(IRON),
		Lifetime = R(1), Rate = 3, LightEmission = 0, ZOffset = 1.2, LockedToPart = true,
	}, { Prime = 2 })
	loop(core, "Glow", {
		Texture = IM.glow, Size = NS(0.6), Transparency = seq(0, 1, 0.3, 0.2, 1, 1), Color = cseq(0, GOLD_CORE, 1, GOLD),
		Lifetime = R(0.5), Rate = 6, LightEmission = 1, Brightness = 2, ZOffset = 1.4, LockedToPart = true,
	}, { Prime = 3, Swell = 0.5 })
	loop(core, "Hot", {
		Texture = IM.hot, Size = NS(0.24), Transparency = seq(0, 1, 0.3, 0, 1, 1), Color = CS(GOLD_WHITE),
		Lifetime = R(0.4), Rate = 6, LightEmission = 1, Brightness = 4, ZOffset = 1.6, LockedToPart = true,
	}, { Prime = 3, Swell = 0.3 })
	loop(core, "Star", {
		Texture = IM.star, Size = seq(0, 0.5, 0.5, 0.8, 1, 0.5), Transparency = seq(0, 1, 0.3, 0, 0.7, 0, 1, 1),
		Color = CS(GOLD_WHITE), Lifetime = R(1.4), Rate = 1.2, Rotation = R(0, 90), RotSpeed = R(-25, 25),
		LightEmission = 1, Brightness = 3, ZOffset = 1.7, LockedToPart = true,
	}, { Prime = 1, Swell = 0.3 })

	-- a dim halo of rays behind the body on a dark iron disc (the diamond's
	-- sunburst, kept small at Mortal; it grows into a blade fan with grade)
	local halo = at("Dantian", CFrame.new(0, 1.45, 0.6), "Halo", body)
	loop(halo, "IronDisc", {
		Texture = IM.glow, Size = NS(2.4), Transparency = seq(0, 1, 0.3, 0.4, 0.7, 0.4, 1, 1), Color = CS(IRON),
		Lifetime = R(2), Rate = 1, LightEmission = 0, ZOffset = -0.8, LockedToPart = true,
	}, { Prime = 2 })
	loop(halo, "Rays", {
		Texture = IM.softRays, Size = NS(2.25), Transparency = seq(0, 1, 0.3, 0.15, 0.7, 0.15, 1, 1),
		Color = CS(GOLD), Lifetime = R(3), Rate = 0.7, Rotation = R(0, 360), RotSpeed = R(-12, 12),
		LightEmission = 1, Brightness = 2, ZOffset = -0.6, LockedToPart = true,
	}, { Prime = 2, Breathe = R(0.6, 1.4), Swell = 0.12, Drift = 0.05 })

	-- the marrow: gold bone lines along the arms and spine, glints at the joints
	local lines = folder("Lines", m)
	local bone = {
		Color = cseq(0, GOLD_CORE, 0.5, GOLD_WHITE, 1, GOLD_CORE), Width0 = 0.14, Width1 = 0.14, Brightness = 4,
		LightEmission = 1, Transparency = seq(0, 0.6, 0.15, 0, 0.85, 0, 1, 0.6),
	}
	for _, l in { { "LShoulder", "LElbow" }, { "LElbow", "LHand" }, { "RShoulder", "RElbow" }, { "RElbow", "RHand" }, { "Neck", "Belly" } } do
		beam(lines, l[1] .. "_" .. l[2], l[1], l[2], bone, {
			Pulse = R(0.35, 0.7), Kick = 1, Dots = 0.45, DotColor = GOLD_WHITE, DotImage = IM.star,
		})
	end

	-- limbs: a cold glint running over the steel, forge sparks off the hands
	local limbs = folder("Limbs", m)
	loop(limbs, "Glint", {
		Texture = IM.needle, Shape = box, ShapeStyle = surface, Size = seq(0, 0, 0.4, 0.42, 1, 0),
		Transparency = NS(0), Color = cseq(0, rgb(255, 255, 255), 1, STEEL), Lifetime = R(0.3), Rotation = R(-35, 35),
		Rate = 0.7, LightEmission = 1, Brightness = 3, ZOffset = 0.6,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.6, 1.6), Surge = 3, PunchSurge = 1 })
	loop(limbs, "Sheen", { -- the steel skin glowing from inside
		Texture = IM.glow, Shape = box, ShapeStyle = volume, Size = NS(0.6), Transparency = seq(0, 1, 0.4, 0.55, 1, 1),
		Color = CS(GOLD_CORE), Lifetime = R(0.8), Rate = 2, LightEmission = 1, Brightness = 1.5, ZOffset = 0.3,
		LockedToPart = true,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.5, 1.5) })
	loop(limbs, "Sparks", {
		Texture = IM.spark, Shape = box, ShapeStyle = volume, EmissionDirection = up, Orientation = streak,
		Size = seq(0, 0.07, 1, 0), Transparency = NS(0), Color = cseq(0, GOLD_WHITE, 0.5, GOLD_CORE, 1, GOLD),
		Lifetime = R(0.35, 0.55), Speed = R(3, 5), SpreadAngle = Vector2.new(70, 70), Acceleration = V3(0, -20, 0),
		Drag = 1, Rate = 1.4, LightEmission = 1, Brightness = 3,
	}, { On = "Hands", Scaled = true, Surge = 8, PunchSurge = 4 })

	-- the clang (each exhale)
	local breath = model("Breath", m)
	local lap = at("Lap", CFrame.new(0, 0.35, -0.25), "Lap", breath)
	burst(lap, "Clang", 1, {
		Texture = IM.clang, Size = seq(0, 0.3, 1, 1.5), Transparency = seq(0, 0, 0.6, 0.35, 1, 1), Color = goldColor,
		Lifetime = R(0.32), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	})
	burst(lap, "Star", 1, {
		Texture = IM.star, Size = seq(0, 0.4, 0.25, 1.6, 1, 0), Transparency = NS(0), Color = CS(GOLD_WHITE),
		Lifetime = R(0.28), Rotation = R(0, 20), LightEmission = 1, Brightness = 3, ZOffset = 1.9,
	})
	burst(lap, "Cracks", 1, {
		Texture = IM.cracks, FlipbookLayout = grid2, FlipbookMode = oneShot, Size = NS(0.7), Transparency = NS(0),
		Color = CS(GOLD_WHITE), Lifetime = R(0.25), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 1.85,
	})
	burst(lap, "Sparks", 10, {
		Texture = IM.spark, Orientation = streak, Size = seq(0, 0.15, 1, 0), Transparency = NS(0), Color = goldColor,
		Lifetime = R(0.35, 0.55), Speed = R(8, 13), Drag = 4, SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -12, 0),
		LightEmission = 1, Brightness = 3,
	})
	local bFloor = part("Floor", breath, CFrame.new(0, 0.22, 0), V3(0.1, 0.1, 0.1))
	burst(bFloor, "Ring", 1, B.flat({
		Texture = IM.thinRing, Size = seq(0, 1, 1, 2.6), Transparency = seq(0, 0.1, 0.6, 0.4, 1, 1), Color = CS(GOLD_CORE),
		Lifetime = R(0.5), Rotation = R(0, 360), LightEmission = 1, Brightness = 2, ZOffset = 0.2,
	}))

	-- a heavier blow every few breaths
	local pulseM = model("Punch", m)
	local back = at("Dantian", CFrame.new(0, 0.9, 0.5), "Back", pulseM)
	burst(back, "Rays", 1, {
		Texture = IM.rays, Size = seq(0, 1.2, 0.3, 2.3, 1, 2.6), Transparency = seq(0, 0.2, 0.5, 0.45, 1, 1),
		Color = cseq(0, GOLD_CORE, 1, GOLD), Lifetime = R(0.45), Rotation = R(0, 360), RotSpeed = R(-20, 20),
		LightEmission = 1, Brightness = 2, ZOffset = -0.5,
	})
	local pLap = at("Lap", CFrame.new(0, 0.35, -0.25), "Lap", pulseM)
	burst(pLap, "Clang", 1, {
		Texture = IM.clang, Size = seq(0, 0.4, 1, 2.2), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = goldColor,
		Lifetime = R(0.36), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	})
	burst(pLap, "Flash", 1, {
		Texture = IM.hot, Size = seq(0, 0.4, 0.2, 1.1, 1, 1.2), Transparency = seq(0, 0.05, 0.4, 0.5, 1, 1),
		Color = cseq(0, GOLD_WHITE, 1, GOLD_CORE), Lifetime = R(0.3), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(pLap, "Star", 1, {
		Texture = IM.star, Size = seq(0, 0.5, 0.25, 2.3, 1, 0), Transparency = NS(0), Color = CS(GOLD_WHITE),
		Lifetime = R(0.35), Rotation = R(0, 20), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(pLap, "Sparks", 18, {
		Texture = IM.spark, Orientation = streak, Size = seq(0, 0.18, 1, 0), Transparency = NS(0), Color = goldColor,
		Lifetime = R(0.4, 0.7), Speed = R(10, 16), Drag = 4, SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -14, 0),
		LightEmission = 1, Brightness = 3,
	})
	local pFloor = part("Floor", pulseM, CFrame.new(0, 0.22, 0), V3(0.1, 0.1, 0.1))
	burst(pFloor, "Clang", 1, B.flat({
		Texture = IM.clang, Size = seq(0, 0.9, 1, 2.8), Transparency = seq(0, 0, 0.6, 0.4, 1, 1), Color = goldColor,
		Lifetime = R(0.45), Rotation = R(0, 360), LightEmission = 1, Brightness = 2.5, ZOffset = 0.25,
	}))
	burst(pFloor, "Filings", 10, {
		Texture = IM.shards, FlipbookLayout = grid8, FlipbookMode = randomFb, Shape = box, EmissionDirection = front,
		SpreadAngle = Vector2.new(10, 180), Size = rnd(0.07, 0.11), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = cseq(0, STEEL, 1, GOLD_CORE), Lifetime = R(0.5, 0.7), Speed = R(5, 8), Drag = 3, Rotation = R(0, 360),
		RotSpeed = R(-300, 300), LightEmission = 0.5, Brightness = 2,
	})

	-- ignition: the first great blow
	local ignite = model("Ignite", m)
	local iBack = at("Dantian", CFrame.new(0, 0.9, 0.5), "Back", ignite)
	burst(iBack, "Rays", 1, {
		Texture = IM.rays, Size = seq(0, 1.6, 0.3, 3, 1, 3.3), Transparency = seq(0, 0.1, 0.5, 0.35, 1, 1),
		Color = cseq(0, GOLD_CORE, 1, GOLD), Lifetime = R(0.6), Rotation = R(0, 360), RotSpeed = R(-25, 25),
		LightEmission = 1, Brightness = 2, ZOffset = -0.5,
	})
	local iLap = at("Lap", CFrame.new(0, 0.35, -0.25), "Lap", ignite)
	burst(iLap, "Flash", 1, {
		Texture = IM.hot, Size = seq(0, 0.6, 0.15, 1.7, 1, 2), Transparency = seq(0, 0, 0.4, 0.45, 1, 1),
		Color = cseq(0, GOLD_WHITE, 1, GOLD_CORE), Lifetime = R(0.4), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(iLap, "Star", 1, {
		Texture = IM.star, Size = seq(0, 0.7, 0.25, 3.6, 1, 0), Transparency = NS(0), Color = CS(GOLD_WHITE),
		Lifetime = R(0.45), Rotation = R(0, 10), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(iLap, "Cross", 1, {
		Texture = IM.cross, Size = seq(0, 0.5, 0.25, 2.2, 1, 0), Transparency = NS(0), Color = CS(GOLD_CORE),
		Lifetime = R(0.4), Rotation = R(0), LightEmission = 1, Brightness = 3, ZOffset = 2.05,
	})
	burst(iLap, "Clang", 1, {
		Texture = IM.clang, Size = seq(0, 0.5, 1, 2.8), Transparency = seq(0, 0, 0.6, 0.25, 1, 1), Color = goldColor,
		Lifetime = R(0.45), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	})
	burst(iLap, "Sparks", 30, {
		Texture = IM.spark, Orientation = streak, Size = seq(0, 0.22, 1, 0), Transparency = NS(0), Color = goldColor,
		Lifetime = R(0.5, 0.9), Speed = R(12, 20), Drag = 4, SpreadAngle = Vector2.new(180, 180), Acceleration = V3(0, -16, 0),
		LightEmission = 1, Brightness = 3,
	})
	local iFloor = part("Floor", ignite, CFrame.new(0, 0.22, 0), V3(0.1, 0.1, 0.1))
	burst(iFloor, "Clang", 1, B.flat({
		Texture = IM.clang, Size = seq(0, 1.2, 1, 3.8), Transparency = seq(0, 0, 0.6, 0.35, 1, 1), Color = goldColor,
		Lifetime = R(0.55), Rotation = R(0, 360), LightEmission = 1, Brightness = 2.5, ZOffset = 0.25,
	}))
	burst(iFloor, "Splash", 1, B.flat({
		Texture = IM.splash, Size = seq(0, 1.4, 0.3, 2.6, 1, 2.8), Transparency = seq(0, 0, 0.5, 0.3, 1, 1), Color = goldColor,
		Lifetime = R(0.45), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 0.2,
	}))
	burst(iFloor, "Ring", 1, B.flat({
		Texture = IM.thinRing, Size = seq(0, 1.5, 1, 4.2), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = CS(GOLD_WHITE),
		Lifetime = R(0.6), Rotation = R(0, 360), LightEmission = 1, Brightness = 2, ZOffset = 0.22,
	}), { EmitDelay = 0.06 })
	burst(iFloor, "Shards", 14, {
		Texture = IM.shards, FlipbookLayout = grid8, FlipbookMode = randomFb, Shape = box, EmissionDirection = up,
		SpreadAngle = Vector2.new(60, 60), Size = rnd(0.1, 0.16), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = cseq(0, STEEL, 1, GOLD_CORE), Lifetime = R(0.7, 1), Speed = R(6, 10), Acceleration = V3(0, -22, 0),
		Rotation = R(0, 360), RotSpeed = R(-300, 300), LightEmission = 0.5, Brightness = 2,
	})
	return m
end

-- ---------------------------------------------------------------- Mountain Breath (Earth)
-- Deep and steady as stone: an amber core low in the belly, a carved stone
-- ring under you that settles a little with each breath, pebbles lifting
-- very slowly, dust.

local EARTH_CORE, EARTH, STONE = rgb(255, 196, 110), rgb(225, 150, 60), rgb(118, 98, 78)

local function mountainBreath(root)
	local m = model("MountainBreath", root)
	shell(m, rgb(225, 140, 60), { Pulse = R(0.86, 0.94), Pad = 0.2 }, Enum.Material.Neon)

	local body = model("Body", m)
	local core = ball("Core", body, 0.6, CFrame.new(0, 0, -0.4), EARTH_CORE, { Point = "Belly", Pulse = R(0.02, 0.25), Grow = R(0.9, 1.12) })
	light(core, EARTH, 9, 1.4)

	local ground = model("Ground", m)
	-- the stone ring: a heavy carved torus with a glowing rune circle inside
	local stone = mesh(A.torus, ground, "Stone", ring(6.4, 1.9), CFrame.new(0, 0.18, 0), STONE, {
		Pulse = R(0, 0), Lift = -0.14,
	}, Enum.Material.Slate)
	stone.Color = STONE
	decalDisc("Runes", ground, 6, 0.1, A.rune, rgb(255, 180, 80), { Pulse = R(0, 0.35), Lift = -0.1, Turn = 4 })
	mesh(A.torus, ground, "Glow", ring(5.7, 0.6), CFrame.new(0, 0.16, 0), rgb(235, 140, 50), { Pulse = R(0.3, 0.65), Lift = -0.1 })
	local rockColors = { rgb(140, 116, 88), rgb(120, 100, 76), rgb(160, 132, 96) }
	for i = 1, 5 do
		local yaw = math.rad((i - 1) * 72 + 15)
		local s = 0.3 + (i % 3) * 0.1
		ellipsoid("Pebble" .. i, ground, V3(s * 1.2, s * 0.8, s), CFrame.Angles(0, yaw, 0) * CFrame.new(2.4 + (i % 2) * 0.4, 0.6 + (i % 3) * 0.35, 0)
			* CFrame.Angles(i * 0.7, i * 1.3, i * 0.4), rockColors[(i % 3) + 1], {
			Pulse = R(0, 0), Bob = 0.12, Lift = 0.5, Tumble = 12, Spin = 5,
		}, Enum.Material.Slate)
	end
	local floor = part("Floor", ground, CFrame.new(0, 0.25, 0), V3(5.5, 0.2, 5.5))
	loop(floor, "Dust", B.flat({
		Texture = A.dust, Size = seq(0, 1.2, 1, 2.6), Transparency = seq(0, 1, 0.3, 0.75, 1, 1),
		Color = CS(rgb(205, 175, 130)), Lifetime = R(3), Rate = 0.5, Rotation = R(0, 360), RotSpeed = R(-15, 15),
		LightInfluence = 0.5,
	}), { Scaled = true })

	-- each breath settles: a dust ring and a slow amber pulse out of the stone
	local breath = model("Breath", m)
	local base = part("Base", breath, CFrame.new(0, 0.2, 0), V3(5, 0.2, 5))
	wave(base, "Settle", {
		mesh = A.torus, color = rgb(205, 115, 40), fromSize = ring(5.4, 1.4), toSize = ring(7.4, 0.8),
		fromTransparency = 0.2, toTransparency = 1, duration = 1.4, style = "Sine",
	})
	burst(base, "Dust", 6, {
		Texture = A.dust, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 0.6, 1, 1.6), Transparency = seq(0, 0.55, 1, 1), Color = CS(rgb(210, 180, 135)),
		Lifetime = R(1, 1.4), Speed = R(2, 3.5), Drag = 2, Rotation = R(0, 360), LightInfluence = 0.5,
	})

	-- ignition: the ground thumps, dust sprays out, grit jumps
	local ignite = model("Ignite", m)
	local slam = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(4, 0.2, 4))
	wave(slam, "Thump", {
		mesh = A.torus, color = rgb(205, 115, 40), fromSize = ring(3, 3), toSize = ring(11, 1.4),
		fromTransparency = 0, toTransparency = 1, duration = 0.9, style = "Quint",
	})
	burst(slam, "Dust", 14, {
		Texture = A.dust, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 1, 1, 2.6), Transparency = seq(0, 0.4, 1, 1), Color = CS(rgb(210, 180, 135)),
		Lifetime = R(0.9, 1.3), Speed = R(10, 16), Drag = 3, Rotation = R(0, 360), LightInfluence = 0.5,
	})
	burst(slam, "Grit", 10, {
		Texture = A.rocks, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.25, 0.4),
		Transparency = seq(0, 0, 0.8, 0, 1, 1), Lifetime = R(0.8, 1.1), Speed = R(6, 10), SpreadAngle = Vector2.new(30, 30),
		Acceleration = V3(0, -25, 0), Rotation = R(0, 360), RotSpeed = R(-150, 150), LightInfluence = 0.6,
	})
	return m
end

-- ---------------------------------------------------------------- Thunder Pulse (Lightning, rare)
-- Sudden bursts (Mortal: small, close). Rebuilt 2026-10-21 from layered
-- library emissions (ref docs/reference/auras/dark_lightning_cracks: a dark
-- body split by glowing violet cracks, arcs off the hands, smoke tendrils,
-- floating specks). The idle is dark and still; everything bright happens in
-- irregular bursts (Rhythm = "burst", 0.5 to 2.6 s apart). Back to front:
--   ground  a scorched rubble ring (dark base) round a lightning-crack web
--           that flashes on each burst, dark storm haze, an electric ring
--           crackling at the rim, small arcs crawling on the ground
--   body    jagged lightning cracks (a hard core over a violet glow) across
--           chest, belly and arms, re-jagged each burst; dark smoke tendrils
--           off the head, shoulders and arms; a violet charge glow and arcs
--           crackling on the skin;
--           ozone sparks; a dim violet node at the crack meeting point
--   burst   a crack flash at the chest (spark, radial arcs), bolts from both
--           hands to the ground with spark splashes where they land, a snap
--           ring and a crack flash on the ground, the skin crackles
--   ignite  a bolt strikes the crown, a chromatic flash, radial lightning at
--           the chest, arcs filling the space round the body, an electric
--           ring and a scorched crack web blasting over the ground, dark
--           smoke thrown low, sparks; the skin arcs surge

-- saturated violets: pastel violet goes white under LightEmission on a dark body
local BOLT_CORE, BOLT, BOLT_DEEP = rgb(245, 235, 255), rgb(165, 100, 255), rgb(115, 45, 240)
local STORM = rgb(18, 10, 32)

local TP = {
	dot = id(9841273544), -- small hard glow dot
	glow = id(867619398), -- soft round glow
	strip = id(7151777149), -- vertical lightning strip (beam texture, tiles along the beam)
	bolt = id(1277456789), -- big branching lightning bolt
	web = id(93520831389146), -- lightning-crack web (ground)
	rubble = id(96277359307961), -- jagged scorched rubble ring
	eRing = id(112496740337235), -- ring of crackling lightning
	radial = id(528280947), -- radial lightning branches
	spark = id(74576272746737), -- lightning spark splash with glow
	chroma = id(86693750436614), -- chromatic lightning spark
	crackle = id(7216850580), -- small electric crackle
	zig = id(117027323479014), -- tiny zigzag bolt
	arcs4 = id(11492870634), -- 4x4 flipbook: thin arcs flicking
	arcs2 = id(76973563852665), -- 2x2 sheet: four short thick bolts
	haze = id(112406986364431), -- 2x2 sheet: wispy smoke
}
_G.ThunderPulseAssets = TP

local boltColor = cseq(0, BOLT_CORE, 0.5, BOLT, 1, BOLT_DEEP)
local randomFb = Enum.ParticleFlipbookMode.Random

local function thunderPulse(root)
	local m = model("ThunderPulse", root, { Rhythm = "burst" })
	-- a faint dark tint over the body (support only: the smoke tendrils carry
	-- the dark body on their own)
	shell(m, STORM, { Pulse = R(0.62, 0.7), Pad = 0.06 }, Enum.Material.SmoothPlastic, "ShellDark")

	-- body: jagged lightning cracks. Each is two lines on the same points: a
	-- thin hard core, re-jagged on every burst, over a wide straight violet glow
	local lines = folder("Lines", m)
	local core = {
		Color = CS(BOLT_CORE), Width0 = 0.09, Width1 = 0.06, Brightness = 5, LightEmission = 1, Transparency = NS(0),
	}
	local glow = { -- a soft violet band (the glow texture stretched along the line)
		Texture = TP.glow, TextureMode = Enum.TextureMode.Stretch, TextureLength = 1,
		Color = cseq(0, BOLT, 1, BOLT_DEEP), Width0 = 1.1, Width1 = 0.8, Brightness = 6, LightEmission = 1,
		Transparency = NS(0), ZOffset = 0.5,
	}
	for _, l in {
		{ "ChestR", "Belly" }, { "Belly", "SideL" }, { "Chest", "ChestL" }, { "ChestL", "LShoulder" },
		{ "LShoulder", "LElbow" }, { "LElbow", "LHand" }, { "RShoulder", "RElbow" }, { "RElbow", "RHand" },
		{ "Neck", "ChestR" },
	} do
		local arm = string.find(l[2], "Elbow") or string.find(l[2], "Hand")
		beam(lines, l[1] .. "_" .. l[2], l[1], l[2], core, { Pulse = R(0, 0.5), Flicker = 0.35, Segs = if arm then 3 else 2, Jag = 0.12 })
		beam(lines, l[1] .. "_" .. l[2] .. "Glow", l[1], l[2], glow, { Pulse = R(0, 0.8), Flicker = 0.2 })
	end
	-- bolts from the hands to the ground, lit only on a burst
	local arc = {
		Color = CS(BOLT_CORE), Width0 = 0.14, Width1 = 0.1, Brightness = 6, LightEmission = 1, Transparency = NS(0), ZOffset = 0.3,
	}
	local arcGlow = { -- a crawling bolt texture round the hard core
		Texture = TP.strip, TextureMode = Enum.TextureMode.Stretch, TextureLength = 1, TextureSpeed = 4,
		Color = cseq(0, BOLT, 1, BOLT_DEEP), Width0 = 0.8, Width1 = 0.6, Brightness = 4, LightEmission = 1,
		Transparency = NS(0), ZOffset = 0.25,
	}
	for _, side in { "L", "R" } do
		beam(lines, "Bolt" .. side, side .. "Hand", "Arc" .. side, arc, { Pulse = R(0, 1), Segs = 4, Jag = 0.3 })
		beam(lines, "Bolt" .. side .. "Glow", side .. "Hand", "Arc" .. side, arcGlow, { Pulse = R(0, 1) })
	end

	-- ground: scorched ring, crack web, haze, electric rim, crawling arcs
	local ground = model("Ground", m)
	local anchors = part("Anchors", ground, CFrame.new(0, 0.1, 0))
	B.attach(anchors, "ArcL", V3(-1.9, 0, -1.2))
	B.attach(anchors, "ArcR", V3(1.9, 0, -1.2))
	decalDisc("Rubble", ground, 4.6, 0.13, TP.rubble, rgb(40, 26, 64), { Pulse = R(0.2, 0.3), Kick = 0.3 })
	decalDisc("Cracks", ground, 3.8, 0.15, TP.web, BOLT, { Pulse = R(0, 0.85), Flicker = 0.3, Kick = 0.8 })
	local floor = part("Floor", ground, CFrame.new(0, 0.18, 0), V3(3.6, 0.1, 3.6))
	loop(floor, "Haze", B.flat({ -- the dark storm pool under everything bright
		Texture = TP.glow, Size = NS(2.6), Transparency = seq(0, 1, 0.25, 0.35, 0.75, 0.35, 1, 1), Color = CS(STORM),
		Lifetime = R(4), Rate = 0.5, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Rim", B.flat({
		Texture = TP.eRing, Size = rnd(2.1, 2.3), Transparency = seq(0, 1, 0.1, 0.45, 0.5, 0.6, 1, 1), Color = boltColor,
		Lifetime = R(0.25, 0.4), Rate = 3, Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 0.1,
	}), { Breathe = R(0.4, 6), Swell = 0.15 })
	loop(floor, "GroundArcs", B.flat({
		Texture = TP.arcs4, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = randomFb,
		Shape = disc, ShapeStyle = volume, Size = rnd(0.35, 0.6), Transparency = seq(0, 0, 0.6, 0.2, 1, 1),
		Color = boltColor, Lifetime = R(0.12, 0.22), Rate = 4, Rotation = R(0, 360), LightEmission = 1, Brightness = 3,
		ZOffset = 0.15,
	}), { Scaled = true, Breathe = R(0.5, 5) })
	-- the node where the chest cracks meet: dim at rest, flaring on a burst
	local body = model("Body", m)
	local node = at("ChestR", CFrame.new(0, 0, -0.15), "Node", body)
	loop(node, "Node", {
		Texture = TP.dot, Size = NS(0.32), Transparency = seq(0, 1, 0.3, 0.25, 1, 1), Color = cseq(0, BOLT_CORE, 1, BOLT),
		Lifetime = R(0.3), Rate = 6, LightEmission = 1, Brightness = 3, ZOffset = 1.5, LockedToPart = true,
	}, { Prime = 2, Swell = 1.2, Drift = 0.15 })

	-- limbs: dark smoke tendrils, arcs crackling on the skin, ozone sparks
	local limbs = folder("Limbs", m)
	loop(limbs, "Tendrils", {
		Texture = TP.haze, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = randomFb,
		Shape = box, ShapeStyle = surface, EmissionDirection = up, Size = seq(0, 0.35, 1, 0.9),
		Transparency = seq(0, 1, 0.2, 0.25, 1, 1), Color = CS(STORM), Lifetime = R(1, 1.4), Speed = R(0.6, 1.2),
		Acceleration = V3(0, 0.8, 0), Rotation = R(0, 360), RotSpeed = R(-30, 30), Rate = 2, LightEmission = 0, ZOffset = 0.1,
	}, { On = "Arms,Torso,Head", Scaled = true })
	loop(limbs, "Charge", { -- a violet charge glow on the skin, flaring on a burst
		Texture = TP.glow, Shape = box, ShapeStyle = surface, Size = rnd(0.45, 0.6), Transparency = seq(0, 1, 0.3, 0.7, 1, 1),
		Color = cseq(0, BOLT, 1, BOLT_DEEP), Lifetime = R(0.5, 0.7), Rate = 3, LightEmission = 1, Brightness = 3,
		ZOffset = 0.4, LockedToPart = true,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.6, 3) })
	loop(limbs, "Arcs", {
		Texture = TP.arcs2, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = randomFb,
		Shape = box, ShapeStyle = surface, Size = rnd(0.22, 0.38), Transparency = seq(0, 0, 0.5, 0.15, 1, 1),
		Color = boltColor, Lifetime = R(0.08, 0.16), Rotation = R(0, 360), Rate = 1.5, LightEmission = 1, Brightness = 4,
		ZOffset = 0.7, LockedToPart = true,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.5, 10), Surge = 8 })
	loop(limbs, "Ozone", {
		Texture = TP.zig, Shape = box, ShapeStyle = surface, Size = rnd(0.07, 0.12), Transparency = seq(0, 0, 0.7, 0, 1, 1),
		Color = CS(BOLT_CORE), Lifetime = R(0.25, 0.5), Speed = R(1.5, 3), SpreadAngle = Vector2.new(180, 180),
		Rotation = R(0, 360), RotSpeed = R(-300, 300), Drag = 2, Rate = 1.2, LightEmission = 1, Brightness = 3,
		ZOffset = 0.5,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.6, 4), Surge = 6 })

	-- a burst: the cracks flash, bolts drop from the hands, the ground snaps
	local breath = model("Breath", m)
	local chest = at("ChestR", CFrame.new(0, 0, -0.3), "Chest", breath)
	burst(chest, "Flash", 1, {
		Texture = TP.dot, Size = seq(0, 0.4, 0.2, 0.9, 1, 1), Transparency = seq(0, 0.1, 1, 1), Color = cseq(0, BOLT_CORE, 1, BOLT),
		Lifetime = R(0.18), LightEmission = 1, Brightness = 4, ZOffset = 2,
	})
	burst(chest, "Spark", 1, {
		Texture = TP.spark, Size = seq(0, 0.6, 1, 0.9), Transparency = seq(0, 0, 0.6, 0.2, 1, 1), Color = CS(BOLT_CORE),
		Lifetime = R(0.16), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(chest, "Radial", 1, {
		Texture = TP.radial, Size = seq(0, 0.7, 1, 1.3), Transparency = seq(0, 0, 0.5, 0.3, 1, 1), Color = boltColor,
		Lifetime = R(0.14), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 1.9,
	})
	local snap = part("Floor", breath, CFrame.new(0, 0.2, 0))
	burst(snap, "Snap", 1, B.flat({
		Texture = TP.eRing, Size = seq(0, 0.9, 1, 2.7), Transparency = seq(0, 0, 0.6, 0.35, 1, 1), Color = boltColor,
		Lifetime = R(0.3), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 0.3,
	}))
	burst(snap, "Web", 1, B.flat({
		Texture = TP.web, Size = seq(0, 1.5, 1, 1.8), Transparency = seq(0, 0, 0.5, 0.4, 1, 1), Color = cseq(0, BOLT_CORE, 1, BOLT),
		Lifetime = R(0.35), Rotation = R(0, 360), LightEmission = 1, Brightness = 2, ZOffset = 0.25,
	}))
	for _, side in { -1, 1 } do
		local hit = part(if side < 0 then "HitL" else "HitR", breath, CFrame.new(1.9 * side, 0.2, -1.2))
		burst(hit, "Splash", 1, {
			Texture = TP.crackle, Size = seq(0, 0.4, 1, 0.7), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = cseq(0, BOLT_CORE, 1, BOLT),
			Lifetime = R(0.18), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 0.6,
		})
		burst(hit, "Sparks", 5, {
			Texture = TP.zig, Size = rnd(0.08, 0.14), Transparency = NS(0), Color = CS(BOLT_CORE), Lifetime = R(0.2, 0.35),
			Speed = R(5, 9), Drag = 5, EmissionDirection = up, SpreadAngle = Vector2.new(70, 70), Rotation = R(0, 360),
			RotSpeed = R(-400, 400), LightEmission = 1, Brightness = 3,
		})
	end

	-- ignition: a bolt strikes the crown and the storm wakes round the body
	local ignite = model("Ignite", m)
	local sky = at("Crown", CFrame.new(0, 2.6, 0), "Sky", ignite)
	burst(sky, "Strike", 1, {
		Texture = TP.bolt, Size = NS(2.8), Transparency = seq(0, 0, 0.3, 0.4, 0.4, 0, 0.6, 0.5, 1, 1),
		Color = cseq(0, BOLT_CORE, 1, BOLT), Lifetime = R(0.28), LightEmission = 1, Brightness = 5, ZOffset = 1,
	})
	burst(sky, "Strike2", 1, {
		Texture = TP.bolt, Size = NS(2.4), Transparency = seq(0, 0, 0.5, 0.5, 1, 1), Color = cseq(0, BOLT_CORE, 1, BOLT),
		Lifetime = R(0.18), Rotation = R(160, 200), LightEmission = 1, Brightness = 4, ZOffset = 0.9,
	}, { EmitDelay = 0.12 })
	local crown = at("Crown", nil, "Crown", ignite)
	burst(crown, "Flash", 1, {
		Texture = TP.dot, Size = seq(0, 0.6, 0.15, 1.8, 1, 2), Transparency = seq(0, 0, 0.5, 0.5, 1, 1), Color = cseq(0, BOLT_CORE, 1, BOLT),
		Lifetime = R(0.3), LightEmission = 1, Brightness = 4, ZOffset = 2,
	})
	burst(crown, "Chroma", 1, {
		Texture = TP.chroma, Size = seq(0, 1, 1, 1.8), Transparency = seq(0, 0, 0.6, 0.2, 1, 1), Color = CS(rgb(255, 255, 255)),
		Lifetime = R(0.25), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	local heart = at("Chest", CFrame.new(0, 0, -0.3), "Chest", ignite)
	burst(heart, "Radial", 1, {
		Texture = TP.radial, Size = seq(0, 1.4, 1, 2.6), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = boltColor,
		Lifetime = R(0.3), Rotation = R(0, 360), LightEmission = 1, Brightness = 4, ZOffset = 1.9,
	}, { EmitDelay = 0.06 })
	local field = part("Field", ignite, CFrame.new(0, 1.6, 0), V3(3.4, 3, 3.4))
	burst(field, "Arcs", 12, {
		Texture = TP.arcs2, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = randomFb,
		Shape = box, ShapeStyle = volume, Size = rnd(0.5, 0.9), Transparency = seq(0, 0, 0.6, 0.2, 1, 1), Color = boltColor,
		Lifetime = R(0.12, 0.3), Rotation = R(0, 360), LightEmission = 1, Brightness = 4, ZOffset = 0.8,
	}, { EmitDelay = 0.06 })
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3, 0.1, 3))
	burst(base, "Ring", 1, B.flat({
		Texture = TP.eRing, Size = seq(0, 1, 1, 4.2), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = boltColor,
		Lifetime = R(0.45), Rotation = R(0, 360), LightEmission = 1, Brightness = 4, ZOffset = 0.35,
	}), { EmitDelay = 0.06 })
	burst(base, "Web", 1, B.flat({
		Texture = TP.web, Size = seq(0, 2.2, 0.15, 2.6, 1, 2.7), Transparency = seq(0, 0, 0.4, 0.2, 1, 1),
		Color = cseq(0, BOLT_CORE, 1, BOLT), Lifetime = R(0.9), Rotation = R(0, 360), LightEmission = 1, Brightness = 3,
		ZOffset = 0.3,
	}), { EmitDelay = 0.06 })
	burst(base, "Scorch", 1, B.flat({ -- the dark under the web
		Texture = TP.rubble, Size = seq(0, 2.6, 1, 2.9), Transparency = seq(0, 0.1, 0.6, 0.3, 1, 1), Color = CS(STORM),
		Lifetime = R(1.4), Rotation = R(0, 360), LightEmission = 0, ZOffset = 0.2,
	}), { EmitDelay = 0.06 })
	burst(base, "Smoke", 8, {
		Texture = TP.haze, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = randomFb, Shape = box,
		EmissionDirection = front, SpreadAngle = Vector2.new(5, 180), Size = seq(0, 0.6, 1, 1.6),
		Transparency = seq(0, 0.15, 1, 1), Color = CS(STORM), Lifetime = R(0.8, 1.1), Speed = R(5, 8), Drag = 3,
		Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}, { EmitDelay = 0.06 })
	burst(base, "Sparks", 18, {
		Texture = TP.zig, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.1, 0.18),
		Transparency = NS(0), Color = CS(BOLT_CORE), Lifetime = R(0.3, 0.6), Speed = R(8, 14), Drag = 5,
		SpreadAngle = Vector2.new(60, 60), Rotation = R(0, 360), RotSpeed = R(-400, 400), LightEmission = 1, Brightness = 3,
	}, { EmitDelay = 0.06 })
	return m
end

-- ---------------------------------------------------------------- Drifting Cloud (Wind, rare)
-- Qi drifting in on the wind (Mortal: small, close). Rebuilt 2026-10-21 from
-- layered library emissions (no reference yet; roblox_seated_blue_wisps for
-- the wisps and the ground ring). You sit on a soft cloud; on each inhale the
-- wind spirals in to you and loosens on the exhale. Back to front:
--   ground  a cool shadow under the cloud (dark base), a curling cloud of
--           flipbook puffs you sit on over a grey-teal underside, low mist
--           drifting off it, a soft wind vortex and a three-armed wind seal
--           turning against each other (the seal tightens on the inhale)
--   body    swirl strokes spiralling in round the waist and chest (faster on
--           the inhale), wind curls drawn in from all round, rising wisps and
--           curls lifting off the arms, torso and head (robes and hair can't
--           lift), a calm mint glow at the dantian, motes drifting on the wind
--   breath  (the inhale's start) spiral rings sweep in to the body, a gust of
--           curls drawn in, a puff of cloud at the seat
--   ignite  a soft flash at the chest, the cloud bursts out in a ring of puffs,
--           a gust swirl spreading over the ground, wisps and curls thrown up,
--           motes scattered; the limb wisps surge

local WIND_CORE, WIND, WIND_DEEP = rgb(225, 255, 244), rgb(140, 230, 200), rgb(70, 160, 140)
local CLOUD, CLOUD_UNDER, CLOUD_SHADOW = rgb(250, 253, 252), rgb(170, 200, 200), rgb(40, 70, 72)

local DC = {
	glow = id(867619398), -- soft round glow
	dot = id(9841273544), -- small hard glow dot
	puff = id(130296526638889), -- 4x4 flipbook: a cloud puff curling and thinning
	fog = id(89816655384560), -- 4x4 flipbook: thin fog
	poof = id(12360899465), -- 4x4 flipbook: a puff bursting into a ring
	vortex = id(15249897265), -- soft radial wind swirl
	seal = id(12362658430), -- three-armed wind curl (triskelion)
	swirl = id(13276325263), -- wind swirl strokes
	swirl2 = id(14670080222), -- four-armed swirl strokes
	rings = id(18787656402), -- spiralling ring strokes
	curls = id(12094495797), -- 4x4 flipbook: small wind curls
	wisp = id(87957760009809), -- 4x4 flipbook: a rising wavy wisp
}
_G.DriftingCloudAssets = DC

local function driftingCloud(root)
	local m = model("DriftingCloud", root, { BreathAt = 0.05 }) -- the inhale's start

	-- ground: the cloud seat
	local ground = model("Ground", m)
	local floor = part("Floor", ground, CFrame.new(0, 0.12, 0), V3(3, 0.1, 3))
	loop(floor, "Shadow", B.flat({ -- the cool dark under the white cloud
		Texture = DC.glow, Size = NS(2.5), Transparency = seq(0, 1, 0.25, 0.45, 0.75, 0.45, 1, 1), Color = CS(CLOUD_SHADOW),
		Lifetime = R(4), Rate = 0.5, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Vortex", B.flat({
		Texture = DC.vortex, Size = seq(0, 2.2, 1, 1.7), Transparency = seq(0, 1, 0.3, 0.45, 0.7, 0.5, 1, 1),
		Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(3), Rate = 0.67, Rotation = R(0, 360), RotSpeed = R(-50, -40),
		LightEmission = 1, Brightness = 1.5, ZOffset = 0.05,
	}), { Prime = 2, Breathe = R(0.6, 1.4), Swell = -0.12, Drift = 0.05 })
	decalDisc("Seal", ground, 3.6, 0.16, DC.seal, WIND, { Pulse = R(0.25, 0.55), Turn = 30, Grow = R(0.9, 1.05), GrowIn = true, Kick = 0.4 })
	local seat = part("Seat", ground, CFrame.new(0, 0.6, 0), V3(3.8, 0.3, 3.8))
	loop(seat, "Under", { -- grey-teal underside so the white puffs have an edge on grass
		Texture = DC.puff, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = volume, EmissionDirection = up, Size = seq(0, 0.75, 0.4, 1.2, 1, 1.3),
		Transparency = seq(0, 1, 0.2, 0.35, 0.8, 0.5, 1, 1), Color = CS(CLOUD_UNDER), Lifetime = R(3, 3.6), Speed = R(0.05, 0.15),
		Rotation = R(0, 360), RotSpeed = R(-8, 8), Rate = 2, LightEmission = 0, ZOffset = 0.5,
	}, { Prime = 4, Scaled = true })
	loop(seat, "Cloud", {
		Texture = DC.puff, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = volume, EmissionDirection = up, Size = seq(0, 0.65, 0.4, 1.05, 1, 1.15),
		Transparency = seq(0, 1, 0.2, 0.1, 0.8, 0.3, 1, 1), Color = cseq(0, CLOUD, 1, WIND_CORE), Lifetime = R(2.6, 3.2),
		Speed = R(0.1, 0.25), Acceleration = V3(0, 0.05, 0), Rotation = R(0, 360), RotSpeed = R(-10, 10), Rate = 3,
		LightEmission = 0.15, Brightness = 1.4, ZOffset = 0.6, -- in front of the ground, so it doesn't clip flat
	}, { Prime = 5, Scaled = true, Breathe = R(0.8, 1.3), Swell = 0.1, Drift = 0.06 })
	loop(seat, "Mist", {
		Texture = DC.fog, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = loopFb, FlipbookFramerate = R(4, 6),
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = surface, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 0.8, 1, 1.6), Transparency = seq(0, 1, 0.3, 0.55, 1, 1), Color = CS(CLOUD), Lifetime = R(2.5, 3.5),
		Speed = R(0.4, 0.7), Drag = 0.4, Rotation = R(0, 360), Rate = 1, LightEmission = 0.1, ZOffset = 0,
	}, { Prime = 2, Scaled = true })

	-- body: the wind spiralling in, a calm glow, motes on the wind
	local body = model("Body", m)
	local waist = at("Dantian", CFrame.new(0, -0.2, 0), "Waist", body)
	loop(waist, "Spiral", B.flat({
		Texture = DC.swirl, Size = seq(0, 3.2, 1, 1.3), Transparency = seq(0, 1, 0.3, 0.15, 0.75, 0.3, 1, 1),
		Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(1.8), Rate = 0.9, Rotation = R(0, 360), RotSpeed = R(140, 170),
		LightEmission = 0.9, Brightness = 3, ZOffset = 0.4,
	}), { Prime = 1, Breathe = R(0.3, 1.7) })
	local chest = at("Chest", CFrame.new(0, 0.1, 0.5), "Upper", body)
	loop(chest, "Spiral", B.flat({
		Texture = DC.swirl2, Size = seq(0, 2.6, 1, 1.1), Transparency = seq(0, 1, 0.3, 0.25, 0.75, 0.4, 1, 1),
		Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(1.6), Rate = 0.8, Rotation = R(0, 360), RotSpeed = R(-180, -150),
		LightEmission = 0.9, Brightness = 3, ZOffset = 0.4,
	}), { Breathe = R(0.2, 1.8) })
	local core = at("Dantian", CFrame.new(0, 0, -0.55), "Core", body)
	loop(core, "Glow", {
		Texture = DC.glow, Size = NS(0.8), Transparency = seq(0, 1, 0.3, 0.55, 1, 1), Color = cseq(0, WIND_CORE, 1, WIND),
		Lifetime = R(0.8), Rate = 3, LightEmission = 1, Brightness = 2, ZOffset = 1.2, LockedToPart = true,
	}, { Prime = 2, Swell = 0.35, Drift = 0.08 })
	loop(core, "Dot", {
		Texture = DC.dot, Size = NS(0.16), Transparency = seq(0, 1, 0.3, 0.1, 1, 1), Color = CS(WIND_CORE),
		Lifetime = R(0.6), Rate = 4, LightEmission = 1, Brightness = 3, ZOffset = 1.3, LockedToPart = true,
	}, { Prime = 2, Swell = 0.4 })
	-- curls drawn in from a shell round the body to the waist
	local shellIn = at("Dantian", nil, "Inflow", body, V3(5.5, 4, 5.5))
	loop(shellIn, "Curls", {
		Texture = DC.curls, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = sphere, ShapeStyle = surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = seq(0, 0.25, 0.5, 0.4, 1, 0.2), Transparency = seq(0, 1, 0.25, 0.15, 0.8, 0.3, 1, 1),
		Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(0.9, 1.1), Speed = R(2.2, 2.6), Rotation = R(0, 360),
		RotSpeed = R(-90, 90), Rate = 3, LightEmission = 0.8, Brightness = 2, ZOffset = 0.3,
	}, { Scaled = true, Breathe = R(0.2, 1.8) })
	loop(shellIn, "Motes", {
		Texture = DC.dot, Shape = sphere, ShapeStyle = volume, Size = seq(0, 0, 0.2, 0.06, 0.8, 0.06, 1, 0),
		Transparency = seq(0, 0.2, 1, 0.6), Color = CS(WIND_CORE), Lifetime = R(2.5, 3.5), Speed = R(0.3, 0.6),
		Acceleration = V3(0.5, 0.4, 0), Rate = 1.5, LightEmission = 1, Brightness = 3,
	}, { Scaled = true })

	-- limbs: wisps and curls lifting off the body
	local limbs = folder("Limbs", m)
	loop(limbs, "Wisps", {
		Texture = DC.wisp, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = box, ShapeStyle = surface, EmissionDirection = up, Size = seq(0, 0.3, 0.5, 0.5, 1, 0.55),
		Transparency = seq(0, 1, 0.25, 0.45, 1, 1), Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(1, 1.4),
		Speed = R(0.8, 1.5), Acceleration = V3(0, 1.2, 0), Rotation = R(-15, 15), Rate = 1.6, LightEmission = 0.6,
		Brightness = 1.5, ZOffset = 0.3,
	}, { On = "Arms,Torso,Head", Scaled = true, Breathe = R(0.6, 1.4), Surge = 5 })
	loop(limbs, "Curls", {
		Texture = DC.curls, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = box, ShapeStyle = surface, EmissionDirection = up, Size = rnd(0.22, 0.32),
		Transparency = seq(0, 0.3, 0.7, 0.4, 1, 1), Color = CS(WIND_CORE), Lifetime = R(0.8, 1.1), Speed = R(1.2, 2),
		SpreadAngle = Vector2.new(50, 50), Acceleration = V3(0.8, 0.6, 0), Rotation = R(0, 360), Rate = 0.8,
		LightEmission = 0.7, Brightness = 2, ZOffset = 0.4,
	}, { On = "Arms,Head", Scaled = true, Surge = 4 })

	-- the inhale: spiral rings sweep in, curls drawn in, a puff at the seat
	local breath = model("Breath", m)
	local gather = at("Dantian", CFrame.new(0, -0.3, 0), "Gather", breath)
	burst(gather, "Rings", 1, B.flat({
		Texture = DC.rings, Size = seq(0, 3.4, 1, 0.8), Transparency = seq(0, 1, 0.25, 0.25, 0.8, 0.4, 1, 1),
		Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(1.8), Rotation = R(0, 360), RotSpeed = R(160),
		LightEmission = 0.9, Brightness = 2, ZOffset = 0.5,
	}))
	local around = at("Dantian", nil, "Around", breath, V3(7, 4, 7))
	burst(around, "Curls", 8, {
		Texture = DC.curls, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = sphere, ShapeStyle = surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = seq(0, 0.3, 0.5, 0.5, 1, 0.2), Transparency = seq(0, 1, 0.25, 0.1, 1, 1), Color = CS(WIND_CORE),
		Lifetime = R(1.1, 1.3), Speed = R(2.8, 3.2), Rotation = R(0, 360), RotSpeed = R(-90, 90), LightEmission = 0.8,
		Brightness = 2, ZOffset = 0.3,
	})
	local seatP = part("Seat", breath, CFrame.new(0, 0.4, 0), V3(2.4, 0.2, 2.4))
	burst(seatP, "Puff", 3, {
		Texture = DC.puff, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = volume, EmissionDirection = up, Size = seq(0, 0.7, 1, 1.2),
		Transparency = seq(0, 0.2, 1, 1), Color = CS(CLOUD), Lifetime = R(1.6, 2), Speed = R(0.3, 0.5),
		Rotation = R(0, 360), LightEmission = 0.15, Brightness = 1.4, ZOffset = 0.15,
	})

	-- ignition: the cloud bursts out on a gust
	local ignite = model("Ignite", m)
	local heart = at("Chest", CFrame.new(0, 0, -0.3), "Chest", ignite)
	burst(heart, "Flash", 1, {
		Texture = DC.glow, Size = seq(0, 0.6, 0.2, 1.5, 1, 1.7), Transparency = seq(0, 0.25, 0.4, 0.6, 1, 1),
		Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(0.4), LightEmission = 1, Brightness = 2, ZOffset = 2,
	})
	burst(heart, "Swirl", 1, {
		Texture = DC.swirl2, Size = seq(0, 0.6, 1, 2.6), Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = CS(WIND_CORE),
		Lifetime = R(0.5), Rotation = R(0, 360), RotSpeed = R(-360), LightEmission = 1, Brightness = 2.5, ZOffset = 2.1,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.3, 0), V3(2.6, 0.2, 2.6))
	burst(base, "Poof", 1, B.flat({
		Texture = DC.poof, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Size = seq(0, 1.6, 1, 4.4), Transparency = seq(0, 0, 0.7, 0.2, 1, 1), Color = CS(CLOUD), Lifetime = R(0.8),
		Rotation = R(0, 360), LightEmission = 0.2, Brightness = 1.5, ZOffset = 0.3,
	}))
	burst(base, "PoofDark", 1, B.flat({ -- the cool underside of the poof ring
		Texture = DC.poof, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Size = seq(0, 1.75, 1, 4.6), Transparency = seq(0, 0.3, 0.7, 0.5, 1, 1), Color = CS(CLOUD_SHADOW), Lifetime = R(0.8),
		Rotation = R(0, 360), LightEmission = 0, ZOffset = 0.2,
	}))
	burst(base, "Gust", 1, B.flat({
		Texture = DC.swirl, Size = seq(0, 1.2, 1, 4.6), Transparency = seq(0, 0, 0.6, 0.35, 1, 1), Color = cseq(0, WIND_CORE, 1, WIND),
		Lifetime = R(0.7), Rotation = R(0, 360), RotSpeed = R(-240), LightEmission = 1, Brightness = 2, ZOffset = 0.4,
	}))
	burst(base, "Puffs", 10, {
		Texture = DC.puff, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180), Size = seq(0, 0.7, 1, 1.4),
		Transparency = seq(0, 0, 0.6, 0.2, 1, 1), Color = CS(CLOUD), Lifetime = R(0.9, 1.2), Speed = R(7, 10), Drag = 4,
		Rotation = R(0, 360), LightEmission = 0.15, Brightness = 1.4, ZOffset = 0.2,
	})
	burst(base, "Updraft", 8, {
		Texture = DC.wisp, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = seq(0, 0.6, 1, 1),
		Transparency = seq(0, 0, 0.6, 0.3, 1, 1), Color = cseq(0, WIND_CORE, 1, WIND), Lifetime = R(0.6, 0.8),
		Speed = R(6, 9), Drag = 2, Rotation = R(-10, 10), LightEmission = 0.8, Brightness = 2, ZOffset = 0.5,
	})
	burst(base, "Curls", 12, {
		Texture = DC.curls, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = oneShot,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, SpreadAngle = Vector2.new(60, 60), Size = rnd(0.35, 0.5),
		Transparency = seq(0, 0, 0.7, 0.3, 1, 1), Color = CS(WIND_CORE), Lifetime = R(0.7, 1), Speed = R(6, 10), Drag = 3,
		Rotation = R(0, 360), RotSpeed = R(-200, 200), LightEmission = 0.8, Brightness = 2, ZOffset = 0.5,
	})
	burst(base, "Motes", 16, {
		Texture = DC.dot, Shape = disc, ShapeStyle = volume, EmissionDirection = up, SpreadAngle = Vector2.new(70, 70),
		Size = seq(0, 0.08, 1, 0), Transparency = NS(0), Color = CS(WIND_CORE), Lifetime = R(0.8, 1.3), Speed = R(5, 9),
		Drag = 2.5, LightEmission = 1, Brightness = 3,
	})
	return m
end

-- ---------------------------------------------------------------- Frost Lotus (Ice, rare)
-- Blooming cold and clear: a frost lotus on the ground that opens a petal
-- ring per breath, a rime outline, breath mist, a few flakes.

local ICE_CORE, ICE, ICE_DEEP = rgb(235, 250, 255), rgb(170, 225, 255), rgb(110, 180, 245)

local function frostLotus(root)
	local m = model("FrostLotus", root)
	shell(m, rgb(200, 240, 255), { Pulse = R(0.05, 0.4) })

	local ground = model("Ground", m)
	-- three petal rings, inner first, one more each breath
	for layer, p in {
		{ r = 1.75, tilt = 68, size = V3(0.95, 0.14, 1.7), n = 6, off = 0, color = ICE, delay = 0 },
		{ r = 2.35, tilt = 48, size = V3(1.15, 0.13, 2), n = 8, off = 22.5, color = ICE_DEEP, delay = 5 },
		{ r = 3, tilt = 26, size = V3(1.25, 0.12, 2.2), n = 10, off = 9, color = rgb(80, 150, 235), delay = 10 },
	} do
		for i = 1, p.n do
			local yaw = math.rad(p.off + (i - 1) * 360 / p.n)
			local cf = CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.1 + p.size.Z / 2 * math.sin(math.rad(p.tilt)), -p.r)
				* CFrame.Angles(math.rad(p.tilt), 0, 0)
			ellipsoid(("Petal%d_%d"):format(layer, i), ground, p.size, cf, p.color, {
				Pulse = R(0.1, 0.3), Delay = p.delay + (i - 1) * 0.08, Grow = R(0.95, 1.05),
			}, Enum.Material.Glass)
		end
	end
	local sky = part("Sky", ground, CFrame.new(0, 5.5, 0), V3(5.5, 0.2, 5.5))
	loop(sky, "Flakes", {
		Texture = A.glowDot, Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.08, 0.14),
		Transparency = seq(0, 1, 0.15, 0.1, 0.85, 0.2, 1, 1), Color = CS(ICE_CORE), Lifetime = R(4, 5),
		Speed = R(0.9, 1.3), SpreadAngle = Vector2.new(15, 15), Rate = 2.5, LightEmission = 0.4,
	}, { Scaled = true })
	loop(sky, "Crystals", {
		Texture = A.ice, Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.2, 0.32),
		Transparency = seq(0, 1, 0.15, 0, 0.85, 0.1, 1, 1), Color = CS(ICE_CORE), Lifetime = R(4, 5),
		Speed = R(0.9, 1.2), Rotation = R(0, 360), RotSpeed = R(-50, 50), Rate = 0.6, LightEmission = 0.2,
	}, { Scaled = true })

	-- each exhale: a mist of breath, a frost ring creeping out
	local breath = model("Breath", m)
	local mouth = at("Mouth", nil, "Mouth", breath)
	burst(mouth, "Mist", 4, {
		Texture = A.mist, EmissionDirection = front, Size = seq(0, 0.2, 1, 1), Transparency = seq(0, 0.45, 1, 1),
		Color = CS(ICE_CORE), Lifetime = R(1, 1.4), Speed = R(1, 1.6), SpreadAngle = Vector2.new(20, 20),
		Acceleration = V3(0, 0.3, 0), Drag = 1, Rotation = R(0, 360), LightEmission = 0.2,
	})
	local floor = part("Floor", breath, CFrame.new(0, 0.1, 0))
	wave(floor, "Frost", {
		mesh = A.torus, color = ICE_DEEP, fromSize = ring(2.6, 1.6), toSize = ring(7.2, 0.9),
		fromTransparency = 0.2, toTransparency = 1, duration = 1.8, style = "Sine",
	})

	-- ignition: a burst of frost, shards thrown up, a cold flash
	local ignite = model("Ignite", m)
	local base = part("Base", ignite, CFrame.new(0, 0.15, 0), V3(4, 0.2, 4))
	wave(base, "Freeze", {
		mesh = A.torus, color = ICE_DEEP, fromSize = ring(2, 2.6), toSize = ring(11, 1.2),
		fromTransparency = 0, toTransparency = 1, duration = 1, style = "Quint",
	})
	burst(base, "Shards", 16, {
		Texture = A.shards, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.35, 0.6),
		Transparency = seq(0, 0, 0.8, 0.2, 1, 1), Color = CS(ICE_CORE), Lifetime = R(0.8, 1.2), Speed = R(7, 11),
		SpreadAngle = Vector2.new(35, 35), Acceleration = V3(0, -20, 0), Rotation = R(0, 360), RotSpeed = R(-200, 200),
		LightEmission = 0.3,
	})
	local chest = at("Chest", nil, "Chest", ignite)
	burst(chest, "Flash", 1, {
		Texture = A.star4, Size = seq(0, 0.8, 0.3, 3.4, 1, 0), Transparency = NS(0), Color = CS(ICE_CORE),
		Lifetime = R(0.4), Rotation = R(0, 45), LightEmission = 0.5, ZOffset = 1,
	})
	return m
end

function _G.buildMethodAura(parent, opts)
	local only = opts and opts.only
	local old = parent:FindFirstChild("MethodAura")
	if old and not only then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MethodAura"
	attrs(root, { Breath = 5, FadeIn = 1.2, FadeOut = 1 })
	sectBreathing(root)
	blazingHeart(root)
	flowingSpring(root)
	evergreen(root)
	ironMarrow(root)
	mountainBreath(root)
	thunderPulse(root)
	driftingCloud(root)
	frostLotus(root)
	for _, d in root:GetDescendants() do
		if d:IsA("Model") then
			d.WorldPivot = CFrame.new()
		end
	end
	if only then
		assert(old, "no MethodAura in " .. parent:GetFullName() .. " to update; build it whole first")
		for _, id in only do
			local fresh = root:FindFirstChild(id)
			assert(fresh and fresh:IsA("Model"), "no method model " .. tostring(id))
			local prev = old:FindFirstChild(id)
			if prev then
				prev:Destroy()
			end
			fresh.Parent = old
		end
		for k, v in root:GetAttributes() do
			old:SetAttribute(k, v)
		end
		root:Destroy()
		return old
	end
	root.Parent = parent
	return root
end

return "buildMethodAura installed"
