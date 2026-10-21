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
-- An old tree, patient growth (Mortal: small, close, rich). Rebuilt
-- 2026-10-21 from layered library emissions: the motion is upward and slow,
-- things sprouting and unfurling; the aura fills in over the first breaths
-- (roots and branches light trunk-first) and every few breaths it blooms.
-- Back to front:
--   ground  a dark moss pool (dark base) with a living green glow on it, a
--           circle of linked rings (growth rings) turning slowly inside a
--           jade ring of flourishes turning the other way, five glowing roots
--           creeping out (flat beams, lit one after another), shoots
--           springing up round the seat, jade motes hovering like fireflies,
--           a few leaves falling from just above the head
--   body    a seed of green qi at the belly (crackling glow, hard dot, a
--           sparkle cluster, the one light); a green glow behind the body on
--           a dark copy; leaves budding off the shoulders and back (a dark
--           layer under a lit one: the tree's first crown); vine meridians growing
--           from the belly out along the arms and legs with budding glints
--           at the joints; a green qi glow hugging the torso and arms, small
--           shoots sprouting on the arms, leaves curling off the shoulders
--   breath  the seed pulses with a glint, sap motes rise, a thin ring breathes
--           out over the ground, a few leaves skitter out low
--   bloom   every 3 or 4 breaths: shoots spring up in a ring, a green ring
--           bursts open, leaves whirl up, the seed flashes
--   ignite  a jade flash and star at the seed, a sparkle burst, vines lashing
--           up out of the ground round the body, shoots erupting, a dark spore
--           puff under a bright bursting ring and a shockwave, leaves whirling
--           up the body; limb leaves and shoots surge

local JADE_WHITE, JADE, LEAF, LEAF_DEEP = rgb(232, 255, 214), rgb(140, 235, 110), rgb(80, 190, 70), rgb(32, 115, 45)
local BUD, MOSS = rgb(222, 245, 120), rgb(10, 30, 14)

local ER = {
	moss = id(12362864669), -- soft green blob with a dark rim (tinted near-black: the moss base)
	verdure = id(12362866115), -- crackling green energy with a dark crust
	rings = id(139744345977881), -- an ornate circle of linked rings (growth rings)
	tendrils = id(100708312805540), -- a thin ring with curling flourishes
	strand = id(15938018250), -- a white twisting strand, vertical (roots, meridian vines, lashing vines)
	sprout = id(126101557256096), -- 4x4 flipbook: a shoot springing up and wilting
	leafA = id(125936833129232), -- 4x4 flipbook: a leaf tumbling
	leafB = id(90111316485044), -- 4x4 flipbook: a leaf tumbling (other cut)
	bloom = id(90585684660600), -- 4x4 flipbook: a green ring bursting open
	sparkles = id(115317702570755), -- 4x4 flipbook: a cluster of sparkles
	star = id(669133414), -- thin 4-point star
	dot = id(13280146664), -- soft round dot
	mote = id(8238126392), -- tiny hard glow
	ring = id(16878174995), -- thin double ring
}
_G.EvergreenAssets = ER

local function evergreen(root)
	local grid4 = Enum.ParticleFlipbookLayout.Grid4x4
	local oneShot, loopFb = Enum.ParticleFlipbookMode.OneShot, Enum.ParticleFlipbookMode.Loop
	local leafColor = cseq(0, BUD, 0.5, JADE, 1, LEAF)
	local shootColor = cseq(0, JADE_WHITE, 0.4, JADE, 1, LEAF)
	-- a bloom (the Punch model) every 3 or 4 breaths, up to 0.8 s late
	local m = model("EverGreen", root, { PunchEvery = R(3, 4), PunchJitter = 0.8, PunchSwell = 1.3 })

	-- ground: the seat (within ~1 body-width)
	local ground = model("Ground", m)
	local floor = part("Floor", ground, CFrame.new(0, 0.04, 0), V3(1, 0.05, 1))
	local under = part("Under", ground, CFrame.new(0, 0.01, 0), V3(0.6, 0.02, 0.6))
	loop(under, "Moss", B.flat({ -- the dark base under everything bright
		Texture = ER.verdure, Size = NS(2.8), Transparency = seq(0, 1, 0.2, 0.3, 0.8, 0.3, 1, 1), Color = CS(MOSS),
		Lifetime = R(5), Rate = 0.4, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Verdure", B.flat({
		Texture = ER.verdure, Size = NS(1.9), Transparency = seq(0, 1, 0.25, 0.35, 0.75, 0.35, 1, 1),
		Color = cseq(0, JADE_WHITE, 0.5, JADE, 1, LEAF), Lifetime = R(3.5), Rate = 0.6, Rotation = R(0, 360),
		RotSpeed = R(-12, 12), LightEmission = 1, Brightness = 4, ZOffset = 1, -- over the moss (small ZOffsets lose the sort)
	}), { Prime = 2, Breathe = R(0.6, 1.5), Swell = 0.15, Drift = 0.06 })
	-- the sigils are flat images (steadier than turning particles)
	decalDisc("Rings", ground, 3.9, 0.27, ER.rings, JADE, {
		Pulse = R(0, 0.25), Turn = 6, Grow = R(0.96, 1.05), Kick = 0.5,
	})
	decalDisc("Tendrils", ground, 5.2, 0.22, ER.tendrils, JADE, {
		Pulse = R(0, 0.3), Turn = -9, Grow = R(0.96, 1.05), Kick = 0.7,
	})
	-- roots: two-segment glowing tendrils lying flat (attachment X up),
	-- creeping out one after another over the first breaths
	local anchors = part("Anchors", ground, CFrame.new(0, 0.3, 0))
	local flatX = CFrame.Angles(0, 0, math.pi / 2)
	local lines = folder("Lines", m)
	local rootProps = {
		Texture = ER.strand, TextureMode = Enum.TextureMode.Stretch, FaceCamera = false, Color = cseq(0, JADE_WHITE, 0.4, JADE, 1, LEAF),
		Width0 = 0.7, Width1 = 0.4, LightEmission = 1, Brightness = 5, Transparency = NS(0), ZOffset = 0.02,
	}
	for i = 1, 5 do
		local yaw = math.rad((i - 1) * 72 + 20 + (i % 2) * 14)
		local side = if i % 2 == 0 then 1 else -1
		local function p(r, lateral)
			return (CFrame.Angles(0, yaw, 0) * CFrame.new(lateral, 0, -r)).Position
		end
		local a0 = B.attach(anchors, "RootA" .. i, p(0.8, 0))
		local a1 = B.attach(anchors, "RootB" .. i, p(1.95, 0.38 * side))
		local a2 = B.attach(anchors, "RootC" .. i, p(3.05, -0.15 * side))
		for _, a in { a0, a1, a2 } do
			a.CFrame = CFrame.new(a.Position) * flatX
		end
		local d = 0.6 + (i - 1) * 0.5
		beam(lines, "Root" .. i .. "a", "RootA" .. i, "RootB" .. i, rootProps, { Pulse = R(0.05, 0.4), Delay = d, Kick = 0.6 })
		beam(lines, "Root" .. i .. "b", "RootB" .. i, "RootC" .. i, rootProps, { Pulse = R(0.1, 0.5), Delay = d + 2.5, Kick = 0.6 })
	end
	local bed = part("Bed", ground, CFrame.new(0, 0.5, 0), V3(4.6, 0.1, 4.6))
	loop(bed, "Shoots", {
		Texture = ER.sprout, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.36, 0.52), Transparency = seq(0, 0.1, 0.8, 0.2, 1, 1),
		Color = shootColor, Lifetime = R(1.4, 1.8), Speed = R(0), Rotation = R(-8, 8), Rate = 3, LightEmission = 0.8,
		Brightness = 3, ZOffset = 0.3,
	}, { Scaled = true, Breathe = R(0.5, 1.5), Swell = 0.15, Drift = 0.08 })
	local air = part("Air", ground, CFrame.new(0, 1.7, 0), V3(4.4, 2.8, 4.4))
	loop(air, "Fireflies", {
		Texture = ER.mote, Shape = box, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.06, 0.1),
		Transparency = seq(0, 1, 0.2, 0.1, 0.35, 0.5, 0.5, 0, 0.7, 0.45, 0.85, 0.1, 1, 1), Color = cseq(0, JADE_WHITE, 1, BUD),
		Lifetime = R(2.6, 3.4), Speed = R(0.2, 0.5), SpreadAngle = Vector2.new(60, 60), Drag = 0.4,
		Acceleration = V3(0, 0.15, 0), Rate = 2.4, LightEmission = 1, Brightness = 3, ZOffset = 0.4,
	}, { Scaled = true, Breathe = R(0.6, 1.4), Prime = 4 })
	local canopy = part("Canopy", ground, CFrame.new(0, 5.4, 0), V3(4, 0.2, 4))
	loop(canopy, "Leaves", {
		Texture = ER.leafA, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(5, 9), FlipbookStartRandom = true,
		Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.16, 0.24),
		Transparency = seq(0, 1, 0.1, 0, 0.85, 0.05, 1, 1), Color = leafColor, Lifetime = R(5, 6), Speed = R(0.6, 0.9),
		SpreadAngle = Vector2.new(20, 20), Acceleration = V3(0.25, -0.05, 0), Rotation = R(0, 360), RotSpeed = R(-40, 40),
		Rate = 0.6, LightEmission = 0.25, Brightness = 1.5,
	}, { Scaled = true, Prime = 2 })

	-- body: the seed of green qi at the belly
	local body = model("Body", m)
	local seed = at("Belly", CFrame.new(0, 0, -0.12), "Seed", body)
	light(seed, LEAF, 8, 1.3)
	loop(seed, "Glow", {
		Texture = ER.verdure, Size = NS(0.6), Transparency = seq(0, 1, 0.3, 0.15, 0.7, 0.15, 1, 1),
		Color = cseq(0, JADE_WHITE, 0.5, JADE, 1, LEAF), Lifetime = R(0.9), Rate = 3, Rotation = R(0, 360), RotSpeed = R(-30, 30),
		LightEmission = 1, Brightness = 2.5, ZOffset = 1.4, LockedToPart = true,
	}, { Prime = 3, Swell = 0.4 })
	loop(seed, "Hot", {
		Texture = ER.dot, Size = NS(0.2), Transparency = seq(0, 1, 0.3, 0, 1, 1), Color = CS(JADE_WHITE),
		Lifetime = R(0.4), Rate = 6, LightEmission = 1, Brightness = 4, ZOffset = 1.5, LockedToPart = true,
	}, { Prime = 3, Swell = 0.3 })
	loop(seed, "Sparkle", {
		Texture = ER.sparkles, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = NS(0.55), Transparency = NS(0),
		Color = CS(JADE_WHITE), Lifetime = R(1.1), Rate = 0.6, Rotation = R(-20, 20), LightEmission = 1, Brightness = 3,
		ZOffset = 1.6, LockedToPart = true,
	})

	-- a green glow behind the body on a darker copy of itself, so the
	-- silhouette reads lit from behind in daylight
	local back = at("Dantian", CFrame.new(0, 0.9, 0.45), "Back", body)
	loop(back, "Shade", {
		Texture = ER.moss, Size = NS(1.9), Transparency = seq(0, 1, 0.3, 0.45, 0.7, 0.45, 1, 1), Color = CS(MOSS),
		Lifetime = R(2), Rate = 1, Rotation = R(0, 360), LightEmission = 0, ZOffset = -0.8, LockedToPart = true,
	}, { Prime = 2, Swell = 0.06, Drift = 0.05 })
	loop(back, "Aura", {
		Texture = ER.verdure, Size = NS(1.7), Transparency = seq(0, 1, 0.3, 0.1, 0.7, 0.1, 1, 1),
		Color = cseq(0, JADE_WHITE, 0.5, JADE, 1, LEAF), Lifetime = R(1.6), Rate = 1.4, Rotation = R(0, 360), RotSpeed = R(-15, 15),
		LightEmission = 1, Brightness = 3, ZOffset = -0.5, LockedToPart = true,
	}, { Prime = 2, Breathe = R(0.7, 1.4), Swell = 0.1, Drift = 0.06 })

	-- leaves budding from the shoulders and back, a dark layer under a lit
	-- one: a tree's first crown (it spreads into a canopy at higher grades)
	local crown = at("Neck", CFrame.new(0, 0.45, 0.5), "Crown", body, V3(2.6, 1.3, 0.5))
	loop(crown, "FoliageDark", {
		Texture = ER.leafA, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(2, 4), FlipbookStartRandom = true,
		Shape = box, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.32, 0.44), Transparency = seq(0, 1, 0.2, 0.05, 0.8, 0.05, 1, 1),
		Color = CS(LEAF_DEEP), Lifetime = R(1.8, 2.4), Speed = R(0.2, 0.4), Drag = 0.5, Rotation = R(0, 360), RotSpeed = R(-20, 20),
		Rate = 5, LightEmission = 0, ZOffset = -0.4, LockedToPart = true,
	}, { Prime = 3, Scaled = true, Swell = 0.12, Drift = 0.06 })
	loop(crown, "Foliage", {
		Texture = ER.leafB, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(2, 4), FlipbookStartRandom = true,
		Shape = box, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.24, 0.34), Transparency = seq(0, 1, 0.2, 0, 0.8, 0, 1, 1),
		Color = cseq(0, JADE_WHITE, 0.4, BUD, 1, JADE), Lifetime = R(1.6, 2.2), Speed = R(0.3, 0.5), Drag = 0.5, Rotation = R(0, 360),
		RotSpeed = R(-30, 30), Rate = 4.5, LightEmission = 0.8, Brightness = 3, ZOffset = -0.3, LockedToPart = true,
	}, { Prime = 3, Scaled = true, Breathe = R(0.7, 1.4), Swell = 0.12, Drift = 0.06 })

	-- vine meridians, trunk first, then the shoulders and hips, then
	-- the limbs (~2 breaths to grow), budding glints at the joints
	local vine = {
		Texture = ER.strand, TextureMode = Enum.TextureMode.Wrap, TextureLength = 1.3, TextureSpeed = 0.35,
		Color = cseq(0, JADE_WHITE, 1, JADE), Width0 = 0.55, Width1 = 0.4, Brightness = 4, LightEmission = 1,
		Transparency = NS(0),
	}
	for _, l in {
		{ "Belly", "Chest", 0 }, { "Chest", "Neck", 1.5 },
		{ "Chest", "LShoulder", 2.5 }, { "Chest", "RShoulder", 2.5 },
		{ "LShoulder", "LElbow", 4.5 }, { "RShoulder", "RElbow", 4.5 },
		{ "LElbow", "LHand", 6.5 }, { "RElbow", "RHand", 6.5 },
		{ "Belly", "LHip", 2 }, { "Belly", "RHip", 2 },
		{ "LHip", "LKnee", 4 }, { "RHip", "RKnee", 4 },
	} do
		beam(lines, l[1] .. "_" .. l[2], l[1], l[2], vine, {
			Pulse = R(0.05, 0.35), Delay = l[3], Kick = 0.5, Dots = 0.42, DotColor = BUD, DotImage = ER.star,
		})
	end

	-- limbs: green qi hugging the body, shoots on the arms, leaves curling off
	local limbs = folder("Limbs", m)
	loop(limbs, "Qi", {
		Texture = ER.verdure, Shape = box, ShapeStyle = volume, Size = rnd(0.45, 0.6),
		Transparency = seq(0, 1, 0.3, 0.45, 0.7, 0.45, 1, 1), Color = cseq(0, JADE, 1, LEAF), Lifetime = R(1.2, 1.5),
		Rotation = R(0, 360), RotSpeed = R(-20, 20), Rate = 1.4, LightEmission = 1, Brightness = 1.5, ZOffset = -0.2,
		LockedToPart = true,
	}, { On = "Torso,Arms", Scaled = true, Breathe = R(0.7, 1.3), Swell = 0.15, Drift = 0.06 })
	loop(limbs, "Shoots", {
		Texture = ER.sprout, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, ShapeStyle = surface,
		EmissionDirection = up, Size = rnd(0.2, 0.28), Transparency = seq(0, 0.1, 0.8, 0.2, 1, 1), Color = shootColor,
		Lifetime = R(1.2, 1.5), Rotation = R(-20, 20), Rate = 1, LightEmission = 0.7, Brightness = 2, ZOffset = 0.5,
		LockedToPart = true,
	}, { On = "Arms", Scaled = true, Breathe = R(0.5, 1.5), Surge = 4, PunchSurge = 2 })
	loop(limbs, "Leaves", {
		Texture = ER.leafB, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(6, 10), FlipbookStartRandom = true,
		Shape = box, ShapeStyle = surface, EmissionDirection = up, Size = rnd(0.13, 0.19),
		Transparency = seq(0, 1, 0.1, 0, 0.8, 0.1, 1, 1), Color = leafColor, Lifetime = R(2, 2.6), Speed = R(0.6, 1),
		SpreadAngle = Vector2.new(50, 50), Drag = 0.8, Acceleration = V3(0.2, -0.35, 0), Rotation = R(0, 360),
		RotSpeed = R(-60, 60), Rate = 0.7, LightEmission = 0.3, Brightness = 1.5, ZOffset = 0.4,
	}, { On = "Arms,Torso", Scaled = true, Surge = 4, PunchSurge = 2 })

	-- each breath: the seed pulses, sap rises, a ring breathes out
	local breath = model("Breath", m)
	local belly = at("Belly", CFrame.new(0, 0, -0.15), "Belly", breath)
	burst(belly, "Pulse", 1, {
		Texture = ER.dot, Size = seq(0, 0.35, 0.35, 0.8, 1, 0.9), Transparency = seq(0, 0.3, 1, 1),
		Color = cseq(0, JADE_WHITE, 1, JADE), Lifetime = R(0.7), LightEmission = 1, Brightness = 3, ZOffset = 1.8,
	})
	burst(belly, "Glint", 1, {
		Texture = ER.star, Size = seq(0, 0.3, 0.4, 1.1, 1, 0), Transparency = NS(0), Color = CS(JADE_WHITE),
		Lifetime = R(0.6), Rotation = R(-10, 10), LightEmission = 1, Brightness = 3, ZOffset = 1.9,
	})
	burst(belly, "Sap", 5, {
		Texture = ER.mote, Size = seq(0, 0, 0.2, 0.1, 1, 0), Transparency = seq(0, 0.1, 1, 1), Color = cseq(0, JADE_WHITE, 1, BUD),
		Lifetime = R(1.4, 2), Speed = R(1, 2), SpreadAngle = Vector2.new(50, 50), EmissionDirection = up,
		LightEmission = 1, Brightness = 3, Drag = 0.8, ZOffset = 0.8,
	})
	local floorB = part("Floor", breath, CFrame.new(0, 0.2, 0), V3(1.6, 0.1, 1.6))
	burst(floorB, "Ring", 1, B.flat({
		Texture = ER.ring, Size = seq(0, 1.4, 1, 3.4), Transparency = seq(0, 0.45, 0.6, 0.6, 1, 1), Color = CS(JADE),
		Lifetime = R(1.6), LightEmission = 1, Brightness = 2, ZOffset = 0.2,
	}))
	burst(floorB, "Skitter", 3, {
		Texture = ER.leafA, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(8, 12), FlipbookStartRandom = true,
		Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180), Size = rnd(0.14, 0.2),
		Transparency = seq(0, 0, 0.8, 0.2, 1, 1), Color = leafColor, Lifetime = R(1.2, 1.6), Speed = R(1.5, 2.5), Drag = 1.5,
		Rotation = R(0, 360), RotSpeed = R(-120, 120), LightEmission = 0.3, Brightness = 1.5,
	})

	-- a bloom every few breaths: a lighter ignition
	local bloomM = model("Punch", m)
	local pSeed = at("Belly", CFrame.new(0, 0, -0.2), "Belly", bloomM)
	burst(pSeed, "Flash", 1, {
		Texture = ER.dot, Size = seq(0, 0.4, 0.25, 1.1, 1, 1.3), Transparency = seq(0, 0.1, 0.5, 0.5, 1, 1),
		Color = cseq(0, JADE_WHITE, 1, JADE), Lifetime = R(0.5), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(pSeed, "Sparkle", 1, {
		Texture = ER.sparkles, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = NS(1.2), Transparency = NS(0),
		Color = CS(JADE_WHITE), Lifetime = R(0.8), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	local pBed = part("Bed", bloomM, CFrame.new(0, 0.55, 0), V3(4.2, 0.1, 4.2))
	burst(pBed, "Shoots", 8, {
		Texture = ER.sprout, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = surface, EmissionDirection = up, Size = rnd(0.4, 0.55), Transparency = seq(0, 0, 0.8, 0.15, 1, 1),
		Color = shootColor, Lifetime = R(1.1, 1.4), Rotation = R(-10, 10), LightEmission = 0.7, Brightness = 2, ZOffset = 0.4,
	})
	burst(pBed, "Whirl", 7, {
		Texture = ER.leafB, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(8, 12), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.16, 0.24), Transparency = seq(0, 0, 0.8, 0.1, 1, 1),
		Color = leafColor, Lifetime = R(1.4, 1.9), Speed = R(3, 5), SpreadAngle = Vector2.new(30, 30), Drag = 1.5,
		Rotation = R(0, 360), RotSpeed = R(-160, 160), LightEmission = 0.3, Brightness = 1.5,
	})
	local pFloor = part("Floor", bloomM, CFrame.new(0, 0.22, 0))
	burst(pFloor, "Bloom", 1, B.flat({
		Texture = ER.bloom, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 2, 1, 2.8),
		Transparency = NS(0), Color = CS(rgb(220, 255, 200)), Lifetime = R(0.8), Rotation = R(0, 360), LightEmission = 0.8,
		Brightness = 2, ZOffset = 0.25,
	}))

	-- ignition: a short, punchy burst of growth on and near the body
	local ignite = model("Ignite", m)
	local iSeed = at("Belly", CFrame.new(0, 0, -0.25), "Belly", ignite)
	burst(iSeed, "Flash", 1, {
		Texture = ER.dot, Size = seq(0, 0.6, 0.15, 1.7, 1, 2), Transparency = seq(0, 0, 0.4, 0.5, 1, 1),
		Color = cseq(0, JADE_WHITE, 1, JADE), Lifetime = R(0.45), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(iSeed, "Star", 1, {
		Texture = ER.star, Size = seq(0, 0.6, 0.25, 3.4, 1, 0), Transparency = NS(0), Color = CS(JADE_WHITE),
		Lifetime = R(0.5), Rotation = R(0), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(iSeed, "Sparkle", 1, {
		Texture = ER.sparkles, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = NS(1.8), Transparency = NS(0),
		Color = CS(JADE_WHITE), Lifetime = R(0.9), Rotation = R(0, 360), LightEmission = 1, Brightness = 3, ZOffset = 2.05,
	})
	burst(iSeed, "Motes", 18, {
		Texture = ER.mote, Size = seq(0, 0.12, 1, 0), Transparency = NS(0), Color = cseq(0, JADE_WHITE, 1, BUD),
		Lifetime = R(0.8, 1.3), Speed = R(6, 10), Drag = 4, SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
		Brightness = 3, ZOffset = 1,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3.8, 0.1, 3.8))
	burst(base, "Spores", 1, B.flat({ -- dark under the bright burst
		Texture = ER.moss, Size = seq(0, 1.4, 0.3, 3.2, 1, 3.6), Transparency = seq(0, 0.1, 0.7, 0.3, 1, 1), Color = CS(MOSS),
		Lifetime = R(1.1), Rotation = R(0, 360), LightEmission = 0, ZOffset = 0.15,
	}))
	burst(base, "Bloom", 1, B.flat({
		Texture = ER.bloom, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 2.4, 1, 3.6),
		Transparency = NS(0), Color = CS(rgb(225, 255, 205)), Lifetime = R(0.85), Rotation = R(0, 360), LightEmission = 0.9,
		Brightness = 2, ZOffset = 0.3,
	}))
	burst(base, "Ring", 1, B.flat({
		Texture = ER.ring, Size = seq(0, 1, 1, 5), Transparency = seq(0, 0, 0.6, 0.4, 1, 1), Color = CS(JADE_WHITE),
		Lifetime = R(0.55), LightEmission = 1, Brightness = 2, ZOffset = 0.35,
	}))
	burst(base, "Lash", 9, { -- vines lashing up out of the ground round the body
		Texture = ER.strand, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = surface, EmissionDirection = up,
		Orientation = streak, Size = seq(0, 0.35, 0.4, 0.5, 1, 0.15), Transparency = seq(0, 0, 0.6, 0.2, 1, 1),
		Color = cseq(0, JADE_WHITE, 1, JADE), Lifetime = R(0.45, 0.6), Speed = R(8, 11), Drag = 4,
		SpreadAngle = Vector2.new(10, 10), LightEmission = 0.7, Brightness = 2, ZOffset = 0.5,
	})
	burst(base, "Shoots", 12, {
		Texture = ER.sprout, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = disc, ShapeStyle = volume,
		EmissionDirection = up, Size = rnd(0.45, 0.7), Transparency = seq(0, 0, 0.8, 0.15, 1, 1), Color = shootColor,
		Lifetime = R(1, 1.3), Speed = R(0.5, 1), Rotation = R(-10, 10), LightEmission = 0.7, Brightness = 2, ZOffset = 0.45,
	}, { EmitDelay = 0.05 })
	burst(base, "Whirl", 16, {
		Texture = ER.leafB, FlipbookLayout = grid4, FlipbookMode = loopFb, FlipbookFramerate = R(10, 14), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.2, 0.3), Transparency = seq(0, 0, 0.8, 0.1, 1, 1),
		Color = leafColor, Lifetime = R(1.4, 2), Speed = R(5, 8), SpreadAngle = Vector2.new(35, 35), Drag = 1.6,
		Rotation = R(0, 360), RotSpeed = R(-220, 220), LightEmission = 0.3, Brightness = 1.5,
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
-- Deep, steady as stone (Mortal: small, close, rich). Rebuilt 2026-10-21 from
-- layered library emissions: the motion is heavy and downward, things settle,
-- sift and sink; only the stones lift, slowly, on the inhale. Earth is
-- square: a dark square-in-circle seal under a bright four-fold seal.
-- Back to front:
--   ground  dry cracked earth (dark base) with amber veins glowing through
--           the cracks, a dark square-in-circle seal turning very slowly under
--           a bright amber four-fold seal turning the other way, both sinking a
--           little on each exhale; stones orbiting slowly round you, lifting
--           on the inhale and settling on the exhale; gold dust hanging in
--           the air; a low dust haze creeping out along the ground
--   body    a low earth core in the belly (amber crusted glow, hard dot, a
--           level horizon glint, the one light); amber earth qi clinging to
--           the torso and legs; gold sand sifting down off the arms and torso
--           with dark grit flecks
--   breath  the settle: a dust ring rolls out low, puffs of dust, a few
--           pebbles hop, the core swells; the seals and stones sink
--   tremor  every 3 or 4 breaths: amber cracks flash across the ground, a
--           bigger dust ring and spray, grit jumps, the core flashes
--   ignite  the ground thumps: a dark crater under amber cracks flashing out,
--           rubble crumbling, a dust ring and a low dust spray, rocks thrown
--           up, stone shards jutting round the seat, a flash and a wide level
--           glint at the belly, gold dust bursting up and raining back

local AMBER_WHITE, AMBER, OCHRE, UMBER = rgb(255, 240, 205), rgb(255, 182, 84), rgb(212, 132, 48), rgb(120, 72, 32)
local STONE, SLATE, DUSTY = rgb(150, 136, 118), rgb(78, 70, 62), rgb(198, 172, 132)

local MB = {
	earth = id(86726095803553), -- dry cracked earth, dark
	veins = id(1380079888), -- a net of cracks (glows amber through the dry earth)
	seal = id(223123319), -- black lines: a square inside a circle, rune band
	ward = id(133746306498771), -- a bold four-fold square seal
	core = id(12362862883), -- amber energy with a dark crust
	haze = id(12362866404), -- orange crusted energy, softer
	glow = id(6673021984), -- soft round glow
	dot = id(8242018934), -- small hard dot
	lens = id(1847258023), -- a level lens streak
	stones = id(82603403775997), -- 2x2: white rock chunks (tintable)
	rocks = id(130042646554310), -- 2x2: grey-brown rocks (natural colour)
	shard = id(281633012), -- a stone shard
	dustRing = id(13556798897), -- a ring of dust
	dust = id(11037784926), -- a soft dust puff
	cracks = id(125427453566131), -- radial cracks
	crater = id(109477912447315), -- a dark cracked crater
	rubble = id(116852757864858), -- 4x4 flipbook: cracked ground crumbling
}
_G.MountainBreathAssets = MB

local function mountainBreath(root)
	local grid2, grid4 = Enum.ParticleFlipbookLayout.Grid2x2, Enum.ParticleFlipbookLayout.Grid4x4
	local oneShot, loopFb = Enum.ParticleFlipbookMode.OneShot, Enum.ParticleFlipbookMode.Loop
	-- a tremor (the Punch model) every 3 or 4 breaths, up to 0.5 s late
	local m = model("MountainBreath", root, { PunchEvery = R(3, 4), PunchJitter = 0.5, PunchSwell = 1.3 })

	-- ground: the seat (within ~1 body-width)
	local ground = model("Ground", m)
	local floor = part("Floor", ground, CFrame.new(0, 0.04, 0), V3(1, 0.05, 1))
	local under = part("Under", ground, CFrame.new(0, 0.01, 0), V3(0.6, 0.02, 0.6))
	loop(under, "Bedrock", B.flat({ -- the dark base under everything bright
		Texture = MB.earth, Size = NS(2.9), Transparency = seq(0, 1, 0.2, 0.05, 0.8, 0.05, 1, 1), Color = CS(rgb(150, 125, 100)),
		Lifetime = R(6), Rate = 0.34, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Veins", B.flat({
		Texture = MB.veins, Size = NS(2.3), Transparency = seq(0, 1, 0.25, 0.3, 0.75, 0.3, 1, 1),
		Color = cseq(0, AMBER_WHITE, 0.4, AMBER, 1, OCHRE), Lifetime = R(4), Rate = 0.5, Rotation = R(0, 360),
		LightEmission = 1, Brightness = 2, ZOffset = 1, -- over the bedrock (small ZOffsets lose the sort)
	}), { Prime = 2, Breathe = R(0.5, 1.5), Swell = 0.06, Drift = 0.04 })
	-- the seals are flat images; they sink a little at the breath's peak (Lift)
	decalDisc("Seal", ground, 5.8, 0.22, MB.seal, rgb(255, 255, 255), {
		Pulse = R(0.1, 0.25), Turn = 2.5, Lift = -0.05,
	})
	decalDisc("Ward", ground, 4.4, 0.27, MB.ward, AMBER, {
		Pulse = R(0.05, 0.4), Turn = -4, Lift = -0.05, Grow = R(0.98, 1.03), GrowIn = true, Kick = 0.8,
	})
	-- stones orbiting slowly: emitters locked to anchors that circle the seat
	-- (Spin) and lift on the inhale (Lift); each holds a few stones
	for i, o in {
		{ r = 2.5, y = 1.1, yaw = 0, spin = 11, size = 0.34 },
		{ r = 2.7, y = 1.9, yaw = 130, spin = 9, size = 0.28 },
		{ r = 2.3, y = 0.75, yaw = 245, spin = 13, size = 0.38 },
	} do
		local anchor = part("Orbit" .. i, ground, CFrame.Angles(0, math.rad(o.yaw), 0) * CFrame.new(0, o.y, -o.r), V3(1.2, 0.5, 1.2), {
			Spin = o.spin, Lift = 0.35, Bob = 0.06,
		})
		loop(anchor, "Stones", {
			Texture = MB.stones, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(0), FlipbookStartRandom = true,
			Shape = box, ShapeStyle = volume, Size = rnd(o.size * 0.7, o.size * 1.2), Transparency = seq(0, 1, 0.15, 0, 0.85, 0, 1, 1),
			Color = cseq(0, STONE, 1, SLATE), Lifetime = R(6, 7), Rate = 0.6, Rotation = R(0, 360), RotSpeed = R(-25, 25),
			LightEmission = 0, ZOffset = 0.2, LockedToPart = true,
		}, { Prime = 3 })
		loop(anchor, "Glint", { -- a spirit stone among them, lit from inside
			Texture = MB.shard, Shape = box, ShapeStyle = volume, Size = rnd(0.18, 0.24),
			Transparency = seq(0, 1, 0.2, 0.1, 0.8, 0.1, 1, 1), Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(6),
			Rate = 0.17, Rotation = R(0, 360), RotSpeed = R(-30, 30), LightEmission = 0.6, Brightness = 2, ZOffset = 0.25,
			LockedToPart = true,
		}, { Prime = 1 })
	end
	local air = part("Air", ground, CFrame.new(0, 1.5, 0), V3(4.6, 2.6, 4.6))
	loop(air, "GoldDust", {
		Texture = MB.dot, Shape = box, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.04, 0.065),
		Transparency = seq(0, 1, 0.2, 0.1, 0.8, 0.2, 1, 1), Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(3, 4),
		Speed = R(0.1, 0.3), SpreadAngle = Vector2.new(40, 40), Drag = 0.6, Acceleration = V3(0, -0.12, 0), Rate = 3,
		LightEmission = 1, Brightness = 3, ZOffset = 0.3,
	}, { Scaled = true, Breathe = R(0.6, 1.3), Prime = 5 })
	local haze = part("Haze", ground, CFrame.new(0, 0.3, 0), V3(3.4, 0.2, 3.4))
	loop(haze, "Dust", {
		Texture = MB.dust, Shape = box, ShapeStyle = volume, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 0.4, 1, 0.9), Transparency = seq(0, 1, 0.3, 0.72, 0.7, 0.8, 1, 1), Color = CS(DUSTY), Lifetime = R(2.6, 3.2),
		Speed = R(0.3, 0.6), Drag = 0.3, Rotation = R(0, 360), RotSpeed = R(-15, 15), Rate = 1, LightEmission = 0,
		LightInfluence = 0.6,
	}, { Scaled = true, Prime = 2 })

	-- body: the low earth core
	local body = model("Body", m)
	local core = at("Belly", CFrame.new(0, -0.18, -0.12), "Core", body)
	light(core, OCHRE, 8, 1.4)
	loop(core, "Earth", {
		Texture = MB.core, Size = NS(0.62), Transparency = seq(0, 1, 0.3, 0.1, 0.7, 0.1, 1, 1), Color = CS(AMBER_WHITE),
		Lifetime = R(1.3), Rate = 2.4, Rotation = R(0, 360), RotSpeed = R(-12, 12), LightEmission = 1, Brightness = 2,
		ZOffset = 1.4, LockedToPart = true,
	}, { Prime = 3, Swell = 0.35 })
	loop(core, "Hot", {
		Texture = MB.dot, Size = NS(0.16), Transparency = seq(0, 1, 0.3, 0, 1, 1), Color = CS(AMBER_WHITE),
		Lifetime = R(0.4), Rate = 6, LightEmission = 1, Brightness = 4, ZOffset = 1.5, LockedToPart = true,
	}, { Prime = 3, Swell = 0.25 })
	loop(core, "Horizon", { -- a level glint: steady as the horizon
		Texture = MB.lens, Size = seq(0, 0.6, 0.5, 1, 1, 0.7), Transparency = seq(0, 1, 0.4, 0.2, 1, 1), Color = CS(AMBER_WHITE),
		Lifetime = R(1.6), Rate = 0.6, LightEmission = 1, Brightness = 3, ZOffset = 1.55, LockedToPart = true,
	}, { Prime = 1 })

	-- a squat amber glow behind the lower body on a dark umber copy of
	-- itself: a low, broad shape (a hill, not a flame) that breathes slowly
	local seat = at("Dantian", CFrame.new(0, 0.2, 0.55), "Seat", body)
	loop(seat, "Shade", {
		Texture = MB.haze, Size = NS(2), Transparency = seq(0, 1, 0.3, 0.2, 0.7, 0.2, 1, 1), Color = CS(rgb(40, 26, 14)),
		Lifetime = R(2.4), Rate = 0.9, Rotation = R(-20, 20), LightEmission = 0, ZOffset = -0.8, LockedToPart = true,
	}, { Prime = 2, Swell = 0.06, Drift = 0.04 })
	loop(seat, "Glow", {
		Texture = MB.core, Size = NS(1.6), Transparency = seq(0, 1, 0.3, 0.1, 0.7, 0.1, 1, 1), Color = CS(rgb(255, 225, 175)),
		Lifetime = R(2.2), Rate = 1.2, Rotation = R(0, 360), RotSpeed = R(-8, 8), LightEmission = 1, Brightness = 3,
		ZOffset = -0.5, LockedToPart = true,
	}, { Prime = 2, Breathe = R(0.7, 1.3), Swell = 0.1, Drift = 0.04 })

	-- limbs: earth qi clinging low, gold sand sifting down, dark grit
	local limbs = folder("Limbs", m)
	loop(limbs, "Qi", {
		Texture = MB.haze, Shape = box, ShapeStyle = volume, Size = rnd(0.5, 0.65),
		Transparency = seq(0, 1, 0.3, 0.3, 0.7, 0.3, 1, 1), Color = CS(rgb(255, 225, 185)), Lifetime = R(1.4, 1.8),
		Rotation = R(0, 360), RotSpeed = R(-10, 10), Rate = 1.4, LightEmission = 1, Brightness = 2.5, ZOffset = -0.25,
		LockedToPart = true,
	}, { On = "Torso,Legs", Scaled = true, Breathe = R(0.7, 1.3), Swell = 0.12, Drift = 0.05 })
	loop(limbs, "Sand", {
		Texture = MB.dot, Shape = box, ShapeStyle = surface, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.05, 0.075),
		Transparency = seq(0, 0, 0.8, 0.1, 1, 1), Color = cseq(0, AMBER_WHITE, 1, OCHRE), Lifetime = R(0.6, 0.9),
		Speed = R(0.2, 0.5), SpreadAngle = Vector2.new(20, 20), Acceleration = V3(0, -7, 0), Rate = 5, LightEmission = 1,
		Brightness = 2.5, ZOffset = 0.4,
	}, { On = "Arms,Torso", Scaled = true, Breathe = R(0.6, 1.4), Surge = 10, PunchSurge = 5 })
	loop(limbs, "Grit", {
		Texture = MB.stones, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = box, ShapeStyle = surface, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.045, 0.07),
		Transparency = seq(0, 0, 0.8, 0.1, 1, 1), Color = CS(SLATE), Lifetime = R(0.7, 1), Speed = R(0.1, 0.3),
		Acceleration = V3(0, -8, 0), Rotation = R(0, 360), RotSpeed = R(-90, 90), Rate = 0.8, LightEmission = 0, ZOffset = 0.35,
	}, { On = "Arms,Torso", Scaled = true, Surge = 4, PunchSurge = 2 })

	-- each breath settles: a low dust ring, puffs, a few pebbles hop, the core swells
	local breath = model("Breath", m)
	local belly = at("Belly", CFrame.new(0, -0.18, -0.18), "Belly", breath)
	burst(belly, "Swell", 1, {
		Texture = MB.glow, Size = seq(0, 0.5, 0.5, 1.1, 1, 1.2), Transparency = seq(0, 0.4, 1, 1), Color = cseq(0, AMBER_WHITE, 1, AMBER),
		Lifetime = R(0.9), LightEmission = 1, Brightness = 2, ZOffset = 1.8,
	})
	local floorB = part("Floor", breath, CFrame.new(0, 0.18, 0), V3(2.4, 0.1, 2.4))
	burst(floorB, "DustRing", 1, B.flat({
		Texture = MB.dustRing, Size = seq(0, 1.6, 1, 3.3), Transparency = seq(0, 0.45, 0.5, 0.6, 1, 1), Color = CS(DUSTY),
		Lifetime = R(1.4), Rotation = R(0, 360), LightEmission = 0, LightInfluence = 0.5, ZOffset = 0.2,
	}))
	burst(floorB, "Puffs", 4, {
		Texture = MB.dust, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180), Size = seq(0, 0.35, 1, 0.9),
		Transparency = seq(0, 0.55, 1, 1), Color = CS(DUSTY), Lifetime = R(0.9, 1.3), Speed = R(1.5, 2.5), Drag = 2,
		Rotation = R(0, 360), LightEmission = 0, LightInfluence = 0.5,
	})
	burst(floorB, "Hop", 3, {
		Texture = MB.rocks, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = box, EmissionDirection = up, Size = rnd(0.07, 0.11), Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = R(0.45, 0.6), Speed = R(2.5, 3.5), SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0, -22, 0),
		Rotation = R(0, 360), RotSpeed = R(-200, 200), LightEmission = 0, LightInfluence = 0.6,
	})

	-- a tremor every few breaths: a lighter ignition
	local tremor = model("Punch", m)
	local pCore = at("Belly", CFrame.new(0, -0.18, -0.25), "Belly", tremor)
	burst(pCore, "Flash", 1, {
		Texture = MB.dot, Size = seq(0, 0.3, 0.2, 0.9, 1, 1), Transparency = seq(0, 0.05, 0.5, 0.5, 1, 1),
		Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(0.45), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(pCore, "Horizon", 1, {
		Texture = MB.lens, Size = seq(0, 0.6, 0.25, 2.2, 1, 0), Transparency = NS(0), Color = CS(AMBER_WHITE),
		Lifetime = R(0.5), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	local pFloor = part("Floor", tremor, CFrame.new(0, 0.2, 0), V3(2.6, 0.1, 2.6))
	burst(pFloor, "Cracks", 1, B.flat({
		Texture = MB.cracks, Size = seq(0, 2, 0.2, 2.7, 1, 2.8), Transparency = seq(0, 0, 0.5, 0.4, 1, 1),
		Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(0.9), Rotation = R(0, 360), LightEmission = 1, Brightness = 2.5,
		ZOffset = 0.25,
	}))
	burst(pFloor, "DustRing", 1, B.flat({
		Texture = MB.dustRing, Size = seq(0, 1.6, 1, 3.8), Transparency = seq(0, 0.3, 0.5, 0.5, 1, 1), Color = CS(DUSTY),
		Lifetime = R(1.2), Rotation = R(0, 360), LightEmission = 0, LightInfluence = 0.5, ZOffset = 0.2,
	}))
	burst(pFloor, "Spray", 6, {
		Texture = MB.dust, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180), Size = seq(0, 0.5, 1, 1.3),
		Transparency = seq(0, 0.45, 1, 1), Color = CS(DUSTY), Lifetime = R(0.8, 1.1), Speed = R(4, 6), Drag = 3,
		Rotation = R(0, 360), LightEmission = 0, LightInfluence = 0.5,
	})
	burst(pFloor, "Grit", 6, {
		Texture = MB.rocks, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = box, EmissionDirection = up, Size = rnd(0.08, 0.13), Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = R(0.5, 0.7), Speed = R(3.5, 5), SpreadAngle = Vector2.new(30, 30), Acceleration = V3(0, -24, 0),
		Rotation = R(0, 360), RotSpeed = R(-220, 220), LightEmission = 0, LightInfluence = 0.6,
	})

	-- ignition: the ground thumps, short and heavy, on and near the body
	local ignite = model("Ignite", m)
	local iCore = at("Belly", CFrame.new(0, -0.18, -0.3), "Belly", ignite)
	burst(iCore, "Flash", 1, {
		Texture = MB.dot, Size = seq(0, 0.5, 0.15, 1.5, 1, 1.7), Transparency = seq(0, 0, 0.4, 0.5, 1, 1),
		Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(0.45), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(iCore, "Horizon", 1, {
		Texture = MB.lens, Size = seq(0, 1, 0.2, 4.2, 1, 0), Transparency = NS(0), Color = CS(AMBER_WHITE),
		Lifetime = R(0.6), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(iCore, "GoldDust", 20, {
		Texture = MB.dot, EmissionDirection = up, Size = rnd(0.05, 0.09), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(1, 1.5), Speed = R(5, 8), SpreadAngle = Vector2.new(60, 60),
		Drag = 2, Acceleration = V3(0, -6, 0), LightEmission = 1, Brightness = 3, ZOffset = 1,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3.2, 0.1, 3.2))
	burst(base, "Crater", 1, B.flat({ -- dark under the bright cracks
		Texture = MB.crater, Size = seq(0, 2.2, 0.1, 2.6, 1, 2.6), Transparency = seq(0, 0, 0.7, 0.1, 1, 1),
		Color = CS(rgb(120, 100, 85)), Lifetime = R(1.3), Rotation = R(0, 360), LightEmission = 0, ZOffset = 0.15,
	}))
	burst(base, "Cracks", 1, B.flat({
		Texture = MB.cracks, Size = seq(0, 1.6, 0.12, 3.2, 1, 3.3), Transparency = seq(0, 0, 0.6, 0.35, 1, 1),
		Color = cseq(0, AMBER_WHITE, 1, AMBER), Lifetime = R(1.1), Rotation = R(0, 360), LightEmission = 1, Brightness = 3,
		ZOffset = 0.25,
	}))
	burst(base, "Rubble", 1, B.flat({
		Texture = MB.rubble, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = NS(2.1), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = CS(rgb(230, 200, 160)), Lifetime = R(1), Rotation = R(0, 360), LightEmission = 0.4, Brightness = 1.5, ZOffset = 0.2,
	}))
	burst(base, "DustRing", 1, B.flat({
		Texture = MB.dustRing, Size = seq(0, 1.6, 1, 5), Transparency = seq(0, 0.1, 0.5, 0.4, 1, 1), Color = CS(DUSTY),
		Lifetime = R(1.1), Rotation = R(0, 360), LightEmission = 0, LightInfluence = 0.5, ZOffset = 0.3,
	}))
	burst(base, "Spray", 12, {
		Texture = MB.dust, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180), Size = seq(0, 0.6, 1, 1.8),
		Transparency = seq(0, 0.3, 1, 1), Color = CS(DUSTY), Lifetime = R(0.9, 1.3), Speed = R(8, 12), Drag = 3.5,
		Rotation = R(0, 360), LightEmission = 0, LightInfluence = 0.5,
	})
	burst(base, "Rocks", 12, {
		Texture = MB.rocks, FlipbookLayout = grid2, FlipbookMode = loopFb, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.12, 0.22), Transparency = seq(0, 0, 0.85, 0, 1, 1),
		Lifetime = R(0.7, 1), Speed = R(6, 9), SpreadAngle = Vector2.new(35, 35), Acceleration = V3(0, -30, 0),
		Rotation = R(0, 360), RotSpeed = R(-250, 250), LightEmission = 0, LightInfluence = 0.6,
	})
	local rim = part("Rim", ignite, CFrame.new(0, 0.45, 0), V3(4.6, 0.1, 4.6))
	burst(rim, "Shards", 8, { -- stone shards jutting up round the seat, then sinking
		Texture = MB.shard, Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0, 0.12, 0.5, 0.75, 0.45, 1, 0), Transparency = seq(0, 0, 0.8, 0, 1, 1),
		Color = cseq(0, STONE, 1, UMBER), Lifetime = R(1, 1.2), Speed = R(0.3, 0.6), Rotation = R(-15, 15), LightEmission = 0,
		LightInfluence = 0.5, ZOffset = 0.3,
	}, { EmitDelay = 0.04 })
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
-- Blooming cold and clear (Mortal: small, close). Rebuilt 2026-10-21 from
-- layered library emissions; no light, no shell. The lotus is the frost on
-- the ground opening round the seat, one petal ring more each breath, and cold
-- pouring off the body. Back to front:
--   ground  a deep-blue cracked-ice disc (the dark base) with pale frost
--           creeping out over it; a glass lotus of leaf-veined petals (flat
--           library images, two faces each) in three rings that open one per
--           breath and turn slowly; ice crystals growing and melting round
--           the rim; frost petals lifting off it; diamond dust falling
--   body    a cold bud between the hands (a deep halo, a white-hot dot, a
--           twinkling glint); frost glints twinkling on the skin; cold vapour
--           pouring off the arms and sinking to the ground
--   breath  the exhale: breath mist from the mouth, a frost ring breaking out
--           over the ground, the petals and bud glinting, a few petals lifting
--   punch   every 2 or 3 breaths the lotus blooms: a frost flash over the
--           ice, a crown of ice springing up and melting, crystals and petals
--           thrown up, a star at the bud; the skin glints and vapour surge
--   ignite  a cold white flash and star at the bud, a crown of ice spikes
--           bursting up round the body, frost slamming out over the ground,
--           glass shards and petals thrown up, a low cold puff

local ICE_WHITE, ICE_CORE, ICE, ICE_DEEP = rgb(240, 251, 255), rgb(200, 238, 255), rgb(140, 205, 255), rgb(70, 140, 235)
local ICE_INK = rgb(12, 34, 74)

local FL = {
	crackedIce = id(16924487116), -- a cracked ice disc
	frostRing = id(12360899465), -- 4x4 flipbook: a frost splat breaking into a ring
	crystals = id(10762252968), -- 8x8 flipbook: an ice crystal cluster growing
	petal = id(17259245248), -- a veined leaf (the lotus petal)
	petals = id(90111316485044), -- 4x4 sheet: loose petals
	halo = id(243660373), -- soft round glow
	dot = id(9841273544), -- small hard glow dot
	twinkle = id(102648375149008), -- 4x4 flipbook: a 4-point sparkle
	dust = id(106007718683349), -- 8x8 flipbook: tiny twinkling glints
	star = id(13271102367), -- small 4-point star
	chroma = id(16366023815), -- 4-point lens glint, chromatic edges
	vapour = id(9345352897), -- curling wisp
	mist = id(1084987899), -- soft mist puff
	puff = id(933102662), -- cloud puff
	shards = id(122615286116832), -- 2x2 sheet: glass shards
	crown = id(4316118084), -- mesh: a crown of ice spikes
	lotusCrown = id(489415286), -- mesh: a crown of petal points
}
_G.FrostLotusAssets = FL

-- One lotus petal: a hidden flat part with the petal image on both faces,
-- tilted up `tilt` degrees, its base `r` studs out, at yaw `yaw`.
local function petal(name, parent, yaw, r, tilt, w, l, color, a)
	local t = math.rad(tilt)
	local cf = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, 0.14 + l / 2 * math.sin(t), -(r + l / 2 * math.cos(t)))
		* CFrame.Angles(t, 0, 0)
	local p = decalDisc(name, parent, V3(w, 0.05, l), cf, FL.petal, color, a)
	local front = p:FindFirstChildOfClass("SurfaceGui")
	front.Brightness = 3.5
	local back = front:Clone()
	back.Face = Enum.NormalId.Bottom
	back.Parent = p
	return p
end

local function frostLotus(root)
	local m = model("FrostLotus", root, { PunchEvery = R(2, 3), PunchJitter = 0.5, PunchSwell = 1.3 })
	local grid4, grid8, grid2 = Enum.ParticleFlipbookLayout.Grid4x4, Enum.ParticleFlipbookLayout.Grid8x8, Enum.ParticleFlipbookLayout.Grid2x2
	local oneShot = Enum.ParticleFlipbookMode.OneShot

	-- ground: the frost and the lotus
	local ground = model("Ground", m)
	local floor = part("Floor", ground, CFrame.new(0, 0.1, 0), V3(0.1, 0.1, 0.1))
	loop(floor, "Ice", B.flat({ -- the dark base: deep ice under everything bright
		Texture = FL.crackedIce, Size = NS(3.4), Transparency = seq(0, 1, 0.25, 0.25, 0.75, 0.25, 1, 1), Color = CS(ICE_INK),
		Lifetime = R(6), Rate = 0.4, Rotation = R(0, 360), LightEmission = 0, ZOffset = 0,
	}), { Prime = 2 })
	loop(floor, "Frost", B.flat({ -- pale frost creeping out over it
		Texture = FL.crackedIce, Size = seq(0, 2, 1, 3.2), Transparency = seq(0, 1, 0.3, 0.45, 0.75, 0.55, 1, 1),
		Color = CS(ICE_CORE), Lifetime = R(4.5), Rate = 0.5, Rotation = R(0, 360), LightEmission = 0.5, Brightness = 1.5,
		ZOffset = 0.05,
	}), { Prime = 2, Breathe = R(0.7, 1.3), Drift = 0.05 })
	loop(part("Cup", ground, CFrame.new(0, 1.1, 0), V3(0.1, 0.1, 0.1)), "Cup", { -- cold light filling the lotus cup, behind the body
		Texture = FL.halo, Size = NS(2.6), Transparency = seq(0, 1, 0.3, 0.7, 0.7, 0.7, 1, 1), Color = CS(ICE),
		Lifetime = R(3), Rate = 0.8, Rotation = R(0, 360), LightEmission = 1, ZOffset = -1.5,
	}, { Prime = 2, Breathe = R(0.7, 1.3), Swell = 0.1, Drift = 0.05 })
	-- the lotus: three petal rings, inner first, one more each breath; the
	-- whole flower turns slowly (Spin) and the petals glint on the beat (no
	-- Grow: resizing a SurfaceGui's part re-renders it, 33 of them each frame)
	for ring, p in {
		{ n = 9, r = 1.45, tilt = 72, w = 1.05, l = 1.85, off = 0, color = ICE_WHITE, delay = 0, pulse = R(0, 0.2) },
		{ n = 11, r = 1.85, tilt = 46, w = 1.05, l = 1.65, off = 22.5, color = ICE_WHITE, delay = 5, pulse = R(0.05, 0.3) },
		{ n = 13, r = 2.2, tilt = 16, w = 1, l = 1.45, off = 9, color = ICE_CORE, delay = 10, pulse = R(0.12, 0.4) },
	} do
		for i = 1, p.n do
			petal(("Petal%d_%d"):format(ring, i), ground, p.off + (i - 1) * 360 / p.n, p.r, p.tilt, p.w, p.l, p.color, {
				Pulse = p.pulse, Delay = p.delay + (i - 1) * 0.1, Kick = 0.5, Spin = 3,
			})
		end
	end
	local rim = part("Rim", ground, CFrame.new(0, 0.12, 0), V3(5.4, 0.1, 5.4))
	loop(rim, "Crystals", { -- ice crystals growing and melting round the rim
		Texture = FL.crystals, FlipbookLayout = grid8, FlipbookMode = oneShot, Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = surface, EmissionDirection = up, Size = rnd(0.28, 0.42), Transparency = seq(0, 0.2, 0.75, 0.25, 1, 1),
		Color = cseq(0, ICE_WHITE, 1, ICE_CORE), Lifetime = R(2.2, 2.8), Speed = R(0.01), Rotation = R(-8, 8), Rate = 2.5,
		LightEmission = 0.5, Brightness = 2, ZOffset = 0.3,
	}, { Prime = 4, Scaled = true, Breathe = R(0.7, 1.3) })
	loop(rim, "Petals", { -- frost petals lifting off the lotus
		Texture = FL.petals, FlipbookLayout = grid4, FlipbookMode = oneShot, FlipbookFramerate = R(0),
		FlipbookStartRandom = true, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.1, 0.16),
		Transparency = seq(0, 1, 0.2, 0.15, 0.8, 0.3, 1, 1), Color = CS(ICE_WHITE), Lifetime = R(2.2, 3), Speed = R(0.5, 0.9),
		Acceleration = V3(0, 0.25, 0), SpreadAngle = Vector2.new(20, 20), Rotation = R(0, 360), RotSpeed = R(-60, 60),
		Rate = 1.5, LightEmission = 0.6, Brightness = 2, ZOffset = 0.4,
	}, { Scaled = true, Breathe = R(0.5, 1.5) })
	local sky = part("Sky", ground, CFrame.new(0, 4.6, 0), V3(5, 0.1, 5))
	loop(sky, "Dust", { -- diamond dust: tiny glints falling and twinkling
		Texture = FL.dust, FlipbookLayout = grid8, FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = R(10, 16),
		FlipbookStartRandom = true, Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.12, 0.2),
		Transparency = seq(0, 1, 0.15, 0, 0.85, 0.1, 1, 1), Color = CS(ICE_WHITE), Lifetime = R(3.5, 4.5),
		Speed = R(0.9, 1.2), SpreadAngle = Vector2.new(12, 12), Rate = 3, LightEmission = 1, Brightness = 2,
	}, { Scaled = true })

	-- body: the cold bud between the hands
	local body = model("Body", m)
	local bud = at("Lap", CFrame.new(0, 0.15, -0.1), "Bud", body)
	loop(bud, "Halo", { -- a deep halo under the white (dark under bright)
		Texture = FL.halo, Size = NS(0.7), Transparency = seq(0, 1, 0.3, 0.35, 0.7, 0.35, 1, 1), Color = CS(ICE_DEEP),
		Lifetime = R(1), Rate = 3, LightEmission = 0.4, ZOffset = 1.1, LockedToPart = true,
	}, { Prime = 2, Swell = 0.35 })
	loop(bud, "Hot", {
		Texture = FL.dot, Size = NS(0.2), Transparency = seq(0, 1, 0.3, 0, 1, 1), Color = CS(ICE_WHITE),
		Lifetime = R(0.45), Rate = 5, LightEmission = 1, Brightness = 4, ZOffset = 1.3, LockedToPart = true,
	}, { Prime = 2, Swell = 0.4 })
	loop(bud, "Glint", {
		Texture = FL.twinkle, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = NS(0.5), Transparency = NS(0),
		Color = CS(ICE_WHITE), Lifetime = R(0.8), Rate = 0.8, Rotation = R(-10, 10), LightEmission = 1, Brightness = 3,
		ZOffset = 1.4, LockedToPart = true,
	})

	-- limbs: rime glints on the skin, cold vapour pouring off and sinking
	local limbs = folder("Limbs", m)
	loop(limbs, "Rime", {
		Texture = FL.twinkle, FlipbookLayout = grid4, FlipbookMode = oneShot, Shape = box, ShapeStyle = surface,
		Size = rnd(0.12, 0.2), Transparency = NS(0), Color = CS(ICE_WHITE), Lifetime = R(0.6, 0.9), Rate = 2.5,
		LightEmission = 1, Brightness = 3, ZOffset = 0.5, LockedToPart = true,
	}, { On = "Head,Torso,Arms,Legs", Scaled = true, Breathe = R(0.6, 1.4), Surge = 5, PunchSurge = 2 })
	loop(limbs, "Cold", {
		Texture = FL.vapour, Shape = box, ShapeStyle = surface, EmissionDirection = Enum.NormalId.Bottom,
		Size = seq(0, 0.25, 1, 0.75), Transparency = seq(0, 1, 0.3, 0.6, 1, 1), Color = cseq(0, ICE_WHITE, 1, ICE_CORE),
		Lifetime = R(1.4, 1.9), Speed = R(0.3, 0.6), Acceleration = V3(0, -1.4, 0), Drag = 0.6, Rotation = R(0, 360),
		RotSpeed = R(-25, 25), Rate = 1.2, LightEmission = 0.35, ZOffset = 0.2,
	}, { On = "Arms", Scaled = true, Breathe = R(0.6, 1.4), Surge = 4, PunchSurge = 2, Swell = 0.15, Drift = 0.1 })

	-- the exhale: breath mist, a frost ring breaking out, a few petals lifting
	local breath = model("Breath", m)
	local mouth = at("Mouth", nil, "Mouth", breath)
	burst(mouth, "Mist", 4, {
		Texture = FL.mist, EmissionDirection = front, Size = seq(0, 0.15, 1, 0.75), Transparency = seq(0, 0.5, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1, 1.4), Speed = R(1, 1.6), SpreadAngle = Vector2.new(20, 20),
		Acceleration = V3(0, -0.3, 0), Drag = 1, Rotation = R(0, 360), LightEmission = 0.3,
	})
	local lap = at("Lap", CFrame.new(0, 0.15, -0.15), "Lap", breath)
	burst(lap, "Glint", 1, {
		Texture = FL.star, Size = seq(0, 0.2, 0.3, 0.9, 1, 0), Transparency = NS(0), Color = CS(ICE_WHITE),
		Lifetime = R(0.35), Rotation = R(0, 20), LightEmission = 1, Brightness = 3, ZOffset = 1.6,
	})
	local floorB = part("Floor", breath, CFrame.new(0, 0.18, 0), V3(4.4, 0.1, 4.4))
	burst(floorB, "Frost", 1, B.flat({
		Texture = FL.frostRing, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 2.2, 1, 3.6),
		Transparency = seq(0, 0.25, 0.7, 0.45, 1, 1), Color = CS(ICE_CORE), Lifetime = R(1.3), Rotation = R(0, 360),
		LightEmission = 0.6, Brightness = 2, ZOffset = 0.2,
	}))
	burst(floorB, "Petals", 4, {
		Texture = FL.petals, FlipbookLayout = grid4, FlipbookMode = oneShot, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.12, 0.18), Transparency = seq(0, 0.1, 0.8, 0.3, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1.6, 2.2), Speed = R(1.5, 2.5), Drag = 1, SpreadAngle = Vector2.new(30, 30),
		Rotation = R(0, 360), RotSpeed = R(-90, 90), LightEmission = 0.6, Brightness = 2,
	})

	-- a bloom every 2 or 3 breaths (a lighter ignition)
	local bloom = model("Punch", m)
	local pBud = at("Lap", CFrame.new(0, 0.15, -0.2), "Lap", bloom)
	burst(pBud, "Flash", 1, {
		Texture = FL.dot, Size = seq(0, 0.3, 0.2, 0.8, 1, 0.95), Transparency = seq(0, 0.05, 0.4, 0.5, 1, 1),
		Color = cseq(0, ICE_WHITE, 1, ICE_CORE), Lifetime = R(0.35), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(pBud, "Star", 1, {
		Texture = FL.star, Size = seq(0, 0.3, 0.25, 1.7, 1, 0), Transparency = NS(0), Color = CS(ICE_WHITE),
		Lifetime = R(0.4), Rotation = R(0, 20), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	local pBase = part("Base", bloom, CFrame.new(0, 0.2, 0), V3(5, 0.1, 5))
	burst(pBase, "Flash", 1, B.flat({ -- frost flashing over the ice
		Texture = FL.crackedIce, Size = seq(0, 2.4, 1, 3.4), Transparency = seq(0, 0.2, 1, 1), Color = CS(ICE_WHITE),
		Lifetime = R(0.7), Rotation = R(0, 360), LightEmission = 0.8, Brightness = 2, ZOffset = 0.15,
	}))
	wave(pBase, "Crown", {
		mesh = FL.lotusCrown, color = ICE_CORE, material = Enum.Material.ForceField, fromSize = V3(3.6, 0.5, 3.6),
		toSize = V3(5.6, 1.5, 5.6), fromOffset = V3(0, -0.1, 0), toOffset = V3(0, 0.35, 0), fromTransparency = 0,
		toTransparency = 1, duration = 0.9, style = "Quint",
	})
	burst(pBase, "Crystals", 6, {
		Texture = FL.crystals, FlipbookLayout = grid8, FlipbookMode = oneShot, Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = surface, EmissionDirection = up, Size = rnd(0.4, 0.55), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1.2, 1.5), Speed = R(0.01), Rotation = R(-8, 8), LightEmission = 0.6,
		Brightness = 2, ZOffset = 0.3,
	})
	burst(pBase, "Petals", 8, {
		Texture = FL.petals, FlipbookLayout = grid4, FlipbookMode = oneShot, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.13, 0.2), Transparency = seq(0, 0, 0.8, 0.3, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1.4, 2), Speed = R(3, 5), Drag = 1.5, SpreadAngle = Vector2.new(35, 35),
		Rotation = R(0, 360), RotSpeed = R(-120, 120), LightEmission = 0.6, Brightness = 2,
	})

	-- ignition: short and cold, on and round the body
	local ignite = model("Ignite", m)
	local core = at("Lap", CFrame.new(0, 0.25, -0.3), "Lap", ignite)
	burst(core, "Flash", 1, {
		Texture = FL.dot, Size = seq(0, 0.5, 0.15, 1.5, 1, 1.75), Transparency = seq(0, 0, 0.4, 0.5, 1, 1),
		Color = cseq(0, ICE_WHITE, 1, ICE_CORE), Lifetime = R(0.4), LightEmission = 1, Brightness = 3, ZOffset = 2,
	})
	burst(core, "Star", 1, {
		Texture = FL.chroma, Size = seq(0, 0.6, 0.25, 3.4, 1, 0), Transparency = NS(0), Color = CS(ICE_CORE),
		Lifetime = R(0.45), LightEmission = 1, Brightness = 3, ZOffset = 2.1,
	})
	burst(core, "Star45", 1, {
		Texture = FL.star, Size = seq(0, 0.3, 0.25, 1.9, 1, 0), Transparency = NS(0), Color = CS(ICE_WHITE),
		Lifetime = R(0.4), Rotation = R(45), LightEmission = 1, Brightness = 3, ZOffset = 2.05,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(4.6, 0.1, 4.6))
	wave(base, "Spikes", { -- a crown of ice spikes bursting up round the body
		mesh = FL.crown, color = ICE_CORE, material = Enum.Material.ForceField, fromSize = V3(3.2, 0.6, 3.2),
		toSize = V3(5.8, 2.8, 5.8), fromOffset = V3(0, -0.2, 0), toOffset = V3(0, 0.7, 0), fromTransparency = 0,
		toTransparency = 1, duration = 1, style = "Quint",
	})
	wave(base, "Crown", {
		mesh = FL.lotusCrown, color = ICE_WHITE, material = Enum.Material.ForceField, fromSize = V3(3, 0.4, 3),
		toSize = V3(6.6, 1.5, 6.6), toOffset = V3(0, 0.3, 0), fromTransparency = 0, toTransparency = 1, duration = 0.8,
		style = "Quint", delay = 0.05,
	})
	burst(base, "Frost", 1, B.flat({ -- frost slamming out over the ground
		Texture = FL.crackedIce, Size = seq(0, 1.8, 0.3, 3.6, 1, 3.9), Transparency = seq(0, 0, 0.6, 0.35, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1.1), Rotation = R(0, 360), LightEmission = 0.7, Brightness = 2, ZOffset = 0.15,
	}))
	burst(base, "Ring", 1, B.flat({
		Texture = FL.frostRing, FlipbookLayout = grid4, FlipbookMode = oneShot, Size = seq(0, 2.2, 1, 4.4),
		Transparency = seq(0, 0, 0.7, 0.3, 1, 1), Color = CS(ICE_CORE), Lifetime = R(0.9), Rotation = R(0, 360),
		LightEmission = 0.8, Brightness = 2, ZOffset = 0.25,
	}))
	burst(base, "Crystals", 10, {
		Texture = FL.crystals, FlipbookLayout = grid8, FlipbookMode = oneShot, Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = surface, EmissionDirection = up, Size = rnd(0.45, 0.65), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1.3, 1.7), Speed = R(0.01), Rotation = R(-10, 10), LightEmission = 0.6,
		Brightness = 2, ZOffset = 0.35,
	})
	burst(base, "Shards", 10, {
		Texture = FL.shards, FlipbookLayout = grid2, FlipbookMode = oneShot, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.2, 0.32), Transparency = seq(0, 0, 0.8, 0.2, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(0.8, 1.1), Speed = R(7, 10), SpreadAngle = Vector2.new(30, 30),
		Acceleration = V3(0, -22, 0), Rotation = R(0, 360), RotSpeed = R(-250, 250), LightEmission = 0.4, Brightness = 2,
	})
	burst(base, "Petals", 14, {
		Texture = FL.petals, FlipbookLayout = grid4, FlipbookMode = oneShot, FlipbookFramerate = R(0), FlipbookStartRandom = true,
		Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.14, 0.22), Transparency = seq(0, 0, 0.8, 0.3, 1, 1),
		Color = CS(ICE_WHITE), Lifetime = R(1.5, 2.2), Speed = R(4, 7), Drag = 1.8, SpreadAngle = Vector2.new(40, 40),
		Rotation = R(0, 360), RotSpeed = R(-150, 150), LightEmission = 0.6, Brightness = 2,
	}, { EmitDelay = 0.05 })
	burst(base, "Cold", 8, {
		Texture = FL.puff, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 0.6, 1, 1.4), Transparency = seq(0, 0.45, 1, 1), Color = CS(ICE_WHITE), Lifetime = R(0.9, 1.2),
		Speed = R(5, 8), Drag = 3, Rotation = R(0, 360), LightEmission = 0.2, LightInfluence = 0.4,
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
