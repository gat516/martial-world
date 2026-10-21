--!nocheck
-- Builder for ReplicatedStorage.Effects.MethodAura: one aura per cultivation
-- method (art brief docs/systems/auras.md), drawn on a seated player
-- (Meditating + Method attributes) by src/client/MethodAura.luau.
-- Run through execute_luau in Edit mode (served by tools/receive_rbxmx.py,
-- after tools/vfx_blocks.luau so _G.vfxBlocks exists):
--   local m = Instance.new("ModuleScript"); m.Source = HttpService:GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/MethodAura.luau"); require(m)
--   _G.buildMethodAura(staging)   -- staging = vfxStage.begin(who)
-- It replaces staging.MethodAura.
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
--     Ignite  emitted when the player sits, switches to this method or breaks
--             through; Limbs emitters with `Surge` = n also Emit(n) then
-- Animation attributes on parts (and Lines where they make sense):
--   Pulse   NumberRange: transparency at breath peak..rest (template parts
--           stay at Transparency 1, so nothing shows unplayed)
--   Grow    NumberRange: size scale rest..peak (GrowIn = true: peak..rest)
--   Lift    studs moved up at the peak (negative settles down)
--   Spin    deg/s orbit about the aura's axis;  Turn  deg/s about its own Y
--   Bob     studs of slow sine drift;  Tumble deg/s;  Flicker 0..1 random dimming
--   Kick    extra opacity (and size) flashed on each breath beat
--   Delay   seconds after the aura starts before it fades in (growth)
--   Hidden  keep the part invisible and breathe only its SurfaceGui image
-- Emitters: loop ones carry EmitDuration = -1 (the plugin's T shows them);
-- `Scaled` ones get the method grade's rate multiplier; `Breathe` ones run
-- faster on the inhale. Colours are baked per method (no tinting).

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
local function decalDisc(name, parent, d, y, image, color, a)
	local p = part(name, parent, CFrame.new(0, y, 0), V3(d, 0.05, d), a)
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
-- The basics: a faint mote or two drifting up from the belly on each breath.

local function sectBreathing(root)
	local m = model("SectBreathing", root)
	local breath = model("Breath", m)
	local belly = at("Belly", nil, "Belly", breath)
	burst(belly, "Motes", 2, {
		Size = seq(0, 0, 0.2, 0.16, 1, 0), Transparency = seq(0, 0.3, 0.7, 0.45, 1, 1),
		Color = CS(rgb(205, 245, 225)), Lifetime = R(2.2, 2.8), Speed = R(0.8, 1.3), SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = up, LightEmission = 0.5, Drag = 0.3,
	})
	return m
end

-- ---------------------------------------------------------------- Blazing Heart (Fire)
-- A heart that burns: an orange core in the chest beating on the breath,
-- flame tongues licking up from the shoulders and arms, embers, a warm rim.

local FIRE_CORE, FIRE, FIRE_DEEP = rgb(255, 214, 120), rgb(255, 130, 50), rgb(225, 60, 25)

local function blazingHeart(root)
	local m = model("BlazingHeart", root)
	shell(m, rgb(255, 120, 40), { Pulse = R(0, 0.4), Pad = 0.4 })

	local body = model("Body", m)
	local core = ball("Core", body, 0.55, CFrame.new(0, 0, -0.12), FIRE_CORE, { Point = "Chest", Pulse = R(0, 0.12), Grow = R(0.8, 1.3) })
	light(core, FIRE, 10, 1.6)
	loop(core, "Heat", {
		Texture = A.glow, Size = seq(0, 1.1, 1, 1.5), Transparency = seq(0, 0.5, 0.5, 0.35, 1, 1), Color = CS(FIRE),
		Lifetime = R(0.5), Rate = 5, LightEmission = 0.35, ZOffset = 0.8, LockedToPart = true,
	})

	local limbs = folder("Limbs", m)
	loop(limbs, "Tongues", {
		Texture = A.flame, Shape = box, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0.35, 0.3, 0.85, 1, 0.1), Transparency = seq(0, 0.4, 0.2, 0, 0.7, 0.2, 1, 1),
		Color = cseq(0, FIRE_CORE, 0.4, FIRE, 1, FIRE_DEEP), Lifetime = R(0.45, 0.7), Speed = R(0.5, 1.5),
		Acceleration = V3(0, 10, 0), Rotation = R(-12, 12), Rate = 13, LightEmission = 0.25, ZOffset = 0.4,
	}, { On = "Arms,Torso", Scaled = true, Surge = 10 })
	loop(limbs, "Embers", {
		Texture = A.spark, Shape = box, ShapeStyle = volume, EmissionDirection = up, Orientation = streak,
		Size = seq(0, 0.14, 0.7, 0.1, 1, 0), Transparency = seq(0, 0, 0.75, 0.1, 1, 1),
		Color = cseq(0, FIRE_CORE, 1, FIRE), Lifetime = R(1.2, 1.8), Speed = R(2, 3.5),
		SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0, 2, 0), Rate = 3, LightEmission = 0.6,
	}, { On = "Torso", Scaled = true, Surge = 14 })

	local ground = model("Ground", m)
	mesh(A.torus, ground, "Ring", ring(4, 0.9), CFrame.new(0, 0.12, 0), FIRE, { Pulse = R(0.3, 0.7) })

	-- the beat: a flare of the core and a warm ring breathing out
	local breath = model("Breath", m)
	local chest = at("Chest", nil, "Chest", breath)
	burst(chest, "Beat", 1, {
		Texture = A.glow, Size = seq(0, 0.8, 0.3, 2.4, 1, 2.8), Transparency = seq(0, 0.25, 1, 1), Color = CS(FIRE),
		Lifetime = R(0.5), LightEmission = 0.4, ZOffset = 1,
	})
	local floor = part("Floor", breath, CFrame.new(0, 0.15, 0))
	wave(floor, "Out", {
		mesh = A.torus, color = FIRE, fromSize = ring(3.6, 2), toSize = ring(6.5, 1.2),
		fromTransparency = 0.2, toTransparency = 1, duration = 1.2, style = "Quad",
	})

	-- ignition (ref red_flame_surge): flames roar up off the body and a ring of
	-- fire climbs past the head
	local ignite = model("Ignite", m)
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(3.4, 0.2, 3.4))
	burst(base, "Roar", 26, {
		Texture = A.flame, Shape = disc, ShapeStyle = volume, EmissionDirection = up,
		Size = seq(0, 0.5, 0.3, 1.1, 1, 0), Transparency = seq(0, 0.4, 0.2, 0, 0.8, 0.3, 1, 1),
		Color = cseq(0, FIRE_CORE, 0.45, FIRE, 1, FIRE_DEEP), Lifetime = R(0.6, 0.95), Speed = R(6, 11),
		SpreadAngle = Vector2.new(10, 10), Acceleration = V3(0, 6, 0), Rotation = R(-15, 15), LightEmission = 0.35,
		ZOffset = 0.5,
	})
	wave(base, "Climb", {
		mesh = A.torus, color = FIRE, fromSize = ring(4.2, 2.6), toSize = ring(2, 3),
		fromOffset = V3(0, 0, 0), toOffset = V3(0, 6.5, 0), fromTransparency = 0, toTransparency = 1,
		duration = 0.9, style = "Quad",
	})
	wave(base, "Flare", {
		mesh = A.torus, color = FIRE, fromSize = ring(3, 2.4), toSize = ring(10, 1.2),
		fromTransparency = 0, toTransparency = 1, duration = 0.8, style = "Quint",
	})
	return m
end

-- ---------------------------------------------------------------- Flowing Spring (Water)
-- Water gathering into a still pool: a mirror-still disc that ripples once per
-- breath, droplets drawn in from all round to a soft blue belly core.

local WATER_CORE, WATER, WATER_DEEP = rgb(190, 232, 255), rgb(90, 170, 255), rgb(40, 110, 230)

local function flowingSpring(root)
	local m = model("FlowingSpring", root)
	shell(m, rgb(110, 185, 255), { Pulse = R(0.8, 0.92), Pad = 0.2 }, Enum.Material.Neon)

	local body = model("Body", m)
	local core = ball("Core", body, 0.5, CFrame.new(0, 0, -0.12), WATER_CORE, { Point = "Belly", Pulse = R(0, 0.25), Grow = R(0.85, 1.2) })
	light(core, WATER, 9, 1.4)
	-- droplets spawned on a shell round the body, streaming in to the core
	local shell = at("Dantian", nil, "Shell", body, V3(7, 7, 7))
	loop(shell, "Inflow", {
		Texture = A.spark, Shape = sphere, ShapeStyle = surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Orientation = streak, Size = seq(0, 0.14, 0.3, 0.26, 1, 0.08), Transparency = seq(0, 1, 0.25, 0, 0.85, 0.1, 1, 1),
		Color = CS(rgb(160, 215, 255)), Lifetime = R(0.95, 1.05), Speed = R(3.3), Rate = 10, LightEmission = 0.3,
	}, { Scaled = true, Breathe = true })

	local ground = model("Ground", m)
	local pool = part("Pool", ground, CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), V3(0.06, 5.6, 5.6), { Pulse = R(0.5, 0.62) })
	pool.Shape = Enum.PartType.Cylinder
	pool.Color = WATER
	mesh(A.torus, ground, "Rim", ring(5.7, 0.8), CFrame.new(0, 0.1, 0), WATER_CORE, { Pulse = R(0.2, 0.5) })

	-- one ripple per breath, out across the pool
	local breath = model("Breath", m)
	local floor = part("Floor", breath, CFrame.new(0, 0.14, 0))
	wave(floor, "Ripple", {
		mesh = A.torus, color = WATER_CORE, fromSize = ring(1, 2.4), toSize = ring(5.6, 1.1),
		fromTransparency = 0.05, toTransparency = 1, duration = 1.8, style = "Sine",
	})
	wave(floor, "Ripple2", {
		mesh = A.torus, color = WATER_CORE, fromSize = ring(0.6, 2.4), toSize = ring(4.2, 1.1),
		fromTransparency = 0.3, toTransparency = 1, duration = 1.8, style = "Sine", delay = 0.45,
	})

	-- ignition: the pool springs up, a wave rolls out and droplets fall back
	local ignite = model("Ignite", m)
	local base = part("Base", ignite, CFrame.new(0, 0.2, 0), V3(5, 0.2, 5))
	wave(base, "Wave", {
		mesh = A.torus, color = WATER, fromSize = ring(3, 3), toSize = ring(11, 1.4),
		fromTransparency = 0, toTransparency = 1, duration = 1, style = "Quint",
	})
	wave(base, "Spout", {
		mesh = A.torus, color = WATER, fromSize = ring(5.4, 2.4), toSize = ring(1.6, 3),
		toOffset = V3(0, 3.2, 0), fromTransparency = 0, toTransparency = 1, duration = 0.8, style = "Quad",
	})
	burst(base, "Droplets", 22, {
		Texture = A.bubble, Shape = disc, ShapeStyle = volume, EmissionDirection = up,
		Size = rnd(0.16, 0.3), Transparency = seq(0, 0.1, 0.8, 0.3, 1, 1), Color = CS(WATER_CORE),
		Lifetime = R(0.9, 1.3), Speed = R(8, 13), SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0, -30, 0),
		LightEmission = 0.3,
	})
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
-- Qi hammered into the bones: a hard white-gold diamond spinning between the
-- hands; on each exhale a clang (a thin ring snaps out with sparks, the bone
-- lines and outline glint) (ref sunburst_diamond_core).

local GOLD_CORE, GOLD, STEEL = rgb(255, 248, 215), rgb(255, 220, 130), rgb(220, 228, 245)

local function ironMarrow(root)
	local m = model("IronMarrow", root)
	shell(m, rgb(255, 225, 150), { Pulse = R(0.3, 0.8), Pad = 0.35, Kick = 0.9 })

	local body = model("Body", m)
	-- a cube stood on its corner: a gem
	local gem = part("Diamond", body, CFrame.new(0, 0.45, -0.1) * CFrame.Angles(math.rad(45), 0, math.rad(35.26)), V3(0.6, 0.6, 0.6), {
		Point = "Lap", Pulse = R(0.02, 0.12), Grow = R(0.9, 1.1), Turn = 70, Kick = 1,
	})
	gem.Color = rgb(255, 196, 80)
	light(gem, GOLD, 9, 1.8)
	loop(gem, "Gleam", {
		Texture = A.star4, Size = seq(0, 0.8, 0.5, 1.8, 1, 0.8), Transparency = seq(0, 0.6, 0.5, 0.2, 1, 1),
		Color = CS(GOLD_CORE), Lifetime = R(0.7), Rate = 2.5, Rotation = R(0, 45), LightEmission = 0.4, ZOffset = 0.6,
		LockedToPart = true,
	})

	local lines = folder("Lines", m)
	local props = { Color = CS(GOLD), Width0 = 0.11, Width1 = 0.11, Brightness = 2.5, LightEmission = 0.3, Transparency = NS(0) }
	for _, l in { { "LShoulder", "LElbow" }, { "LElbow", "LHand" }, { "RShoulder", "RElbow" }, { "RElbow", "RHand" }, { "Neck", "Belly" } } do
		beam(lines, l[1] .. "_" .. l[2], l[1], l[2], props, { Pulse = R(0.55, 0.85), Kick = 0.9 })
	end

	local ground = model("Ground", m)
	mesh(A.torus, ground, "Ring", ring(3.6, 1), CFrame.new(0, 0.12, 0), rgb(255, 205, 110), { Pulse = R(0.25, 0.6), Kick = 0.7 })

	-- the clang
	local breath = model("Breath", m)
	local lap = at("Lap", nil, "Lap", breath)
	wave(lap, "Clang", {
		mesh = A.torus, color = GOLD_CORE, fromSize = ring(0.8, 1.6), toSize = ring(7.5, 0.8),
		fromTransparency = 0, toTransparency = 1, duration = 0.55, style = "Quint",
	})
	wave(lap, "Clang2", {
		mesh = A.torus, color = GOLD, fromSize = ring(0.6, 1.6), toSize = ring(5, 0.8), rotation = V3(90, 0, 0),
		fromTransparency = 0.1, toTransparency = 1, duration = 0.5, style = "Quint",
	})
	burst(lap, "Sparks", 12, {
		Texture = A.spark, Orientation = streak, Size = seq(0, 0.16, 1, 0), Transparency = NS(0),
		Color = cseq(0, GOLD_CORE, 1, GOLD), Lifetime = R(0.25, 0.45), Speed = R(10, 16), Drag = 5,
		SpreadAngle = Vector2.new(180, 180), LightEmission = 0.6,
	})
	burst(lap, "Star", 1, {
		Texture = A.star4, Size = seq(0, 0.5, 0.3, 2.4, 1, 0), Transparency = NS(0), Color = CS(GOLD_CORE),
		Lifetime = R(0.3), Rotation = R(0, 45), LightEmission = 0.5, ZOffset = 1,
	})

	-- ignition: a great clang, a sunburst flash behind and a ring across the ground
	local ignite = model("Ignite", m)
	local lap2 = at("Lap", nil, "Lap", ignite)
	wave(lap2, "Clang", {
		mesh = A.torus, color = GOLD_CORE, fromSize = ring(1, 2), toSize = ring(14, 0.9),
		fromTransparency = 0, toTransparency = 1, duration = 0.8, style = "Quint",
	})
	burst(lap2, "Sunburst", 1, {
		Texture = A.star12, Size = seq(0, 1, 0.25, 6, 1, 7), Transparency = seq(0, 0.1, 1, 1), Color = CS(GOLD),
		Lifetime = R(0.6), Rotation = R(0, 360), RotSpeed = R(-30, 30), LightEmission = 0.4, ZOffset = -2,
	})
	burst(lap2, "Sparks", 26, {
		Texture = A.spark, Orientation = streak, Size = seq(0, 0.22, 1, 0), Transparency = NS(0),
		Color = cseq(0, GOLD_CORE, 1, GOLD), Lifetime = R(0.35, 0.6), Speed = R(14, 22), Drag = 4,
		SpreadAngle = Vector2.new(180, 180), LightEmission = 0.6,
	})
	local base = part("Base", ignite, CFrame.new(0, 0.15, 0))
	wave(base, "Floor", {
		mesh = A.torus, color = STEEL, fromSize = ring(3, 2), toSize = ring(10, 1),
		fromTransparency = 0, toTransparency = 1, duration = 0.9, style = "Quint",
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
-- Sudden bursts: a dark body with violet-white cracks across the torso and
-- arms that flare irregularly; on a burst arcs jump from the hands to the
-- ground (ref dark_lightning_cracks).

local BOLT_CORE, BOLT, BOLT_DEEP = rgb(245, 235, 255), rgb(190, 150, 255), rgb(120, 70, 230)

local function thunderPulse(root)
	local m = model("ThunderPulse", root, { Rhythm = "burst" })
	-- the body darkened, with a violet rim that flares on a burst
	shell(m, rgb(28, 16, 46), { Pulse = R(0.3, 0.38), Pad = 0.08 }, Enum.Material.SmoothPlastic, "ShellDark")
	shell(m, BOLT, { Pulse = R(0, 0.85), Pad = 0.35 })

	local lines = folder("Lines", m)
	local crack = {
		Color = cseq(0, BOLT_CORE, 1, rgb(215, 190, 255)), Width0 = 0.16, Width1 = 0.1, Brightness = 4, LightEmission = 0.4,
		Transparency = NS(0),
	}
	for _, l in {
		{ "ChestR", "Belly" }, { "Belly", "SideL" }, { "Chest", "ChestL" }, { "ChestL", "LShoulder" },
		{ "LShoulder", "LElbow" }, { "LElbow", "LHand" }, { "RShoulder", "RElbow" }, { "RElbow", "RHand" },
		{ "Neck", "ChestR" },
	} do
		beam(lines, l[1] .. "_" .. l[2], l[1], l[2], crack, { Pulse = R(0, 0.6), Flicker = 0.25, Segs = 3, Jag = 0.12 })
	end
	-- arcs to the ground, only lit on a burst
	local arc = {
		Color = cseq(0, BOLT_CORE, 1, BOLT), Width0 = 0.2, Width1 = 0.12, Brightness = 5, LightEmission = 0.5,
		Transparency = NS(0), ZOffset = 0.3,
	}
	beam(lines, "BoltL", "LHand", "ArcL", arc, { Pulse = R(0, 1), Segs = 4, Jag = 0.35 })
	beam(lines, "BoltR", "RHand", "ArcR", arc, { Pulse = R(0, 1), Segs = 4, Jag = 0.35 })

	local ground = model("Ground", m)
	local anchors = part("Anchors", ground, CFrame.new(0, 0.1, 0))
	B.attach(anchors, "ArcL", V3(-2.3, 0, -1.5))
	B.attach(anchors, "ArcR", V3(2.3, 0, -1.5))
	mesh(A.torus, ground, "Ring", ring(3.8, 1.2), CFrame.new(0, 0.12, 0), rgb(100, 50, 210), { Pulse = R(0, 0.75), Flicker = 0.3 })

	local limbs = folder("Limbs", m)
	loop(limbs, "Ozone", {
		Texture = A.spark, Shape = box, ShapeStyle = surface, Orientation = streak,
		Size = seq(0, 0.1, 1, 0), Transparency = NS(0), Color = CS(BOLT_CORE), Lifetime = R(0.15, 0.3),
		Speed = R(2, 4), SpreadAngle = Vector2.new(180, 180), Rate = 2, LightEmission = 0.6,
	}, { On = "Arms,Torso", Scaled = true, Surge = 6 })

	-- a burst: a flash at the chest, sparks where the arcs land, a ground snap
	local breath = model("Breath", m)
	local chest = at("Chest", nil, "Chest", breath)
	burst(chest, "Flash", 1, {
		Texture = A.star4, Size = seq(0, 0.6, 0.3, 1.8, 1, 0), Transparency = NS(0), Color = CS(BOLT_CORE),
		Lifetime = R(0.18), Rotation = R(0, 45), LightEmission = 0.6, ZOffset = 1,
	})
	local floor = part("Floor", breath, CFrame.new(0, 0.12, 0), V3(5, 0.2, 5))
	wave(floor, "Snap", {
		mesh = A.torus, color = BOLT_DEEP, fromSize = ring(2.4, 1.8), toSize = ring(6.5, 0.8),
		fromTransparency = 0, toTransparency = 1, duration = 0.35, style = "Quint",
	})
	for _, side in { -1, 1 } do
		local hit = part(if side < 0 then "HitL" else "HitR", breath, CFrame.new(2.3 * side, 0.15, -1.5))
		burst(hit, "Sparks", 6, {
			Texture = A.spark, Orientation = streak, Size = seq(0, 0.14, 1, 0), Transparency = NS(0),
			Color = CS(BOLT_CORE), Lifetime = R(0.2, 0.35), Speed = R(6, 11), Drag = 4, EmissionDirection = up,
			SpreadAngle = Vector2.new(70, 70), LightEmission = 0.6,
		})
	end

	-- ignition: a strike out of the sky onto you
	local ignite = model("Ignite", m)
	local base = part("Base", ignite, CFrame.new(0, 0.15, 0), V3(5, 0.2, 5))
	wave(base, "Strike", {
		mesh = A.torus, color = BOLT_DEEP, fromSize = ring(2, 2.6), toSize = ring(12, 1),
		fromTransparency = 0, toTransparency = 1, duration = 0.7, style = "Quint",
	})
	local field = part("Field", ignite, CFrame.new(0, 2, 0), V3(4.5, 4, 4.5))
	burst(field, "Arcs", 10, {
		Texture = A.arcs, Shape = box, ShapeStyle = volume, Size = rnd(0.8, 1.4), Transparency = NS(0),
		Rotation = R(0, 360), Color = cseq(0, BOLT_CORE, 1, BOLT), Lifetime = R(0.12, 0.25), LightEmission = 0.7,
	})
	local crown = at("Crown", nil, "Crown", ignite)
	burst(crown, "Flash", 1, {
		Texture = A.star4, Size = seq(0, 1, 0.3, 4.5, 1, 0), Transparency = NS(0), Color = CS(BOLT_CORE),
		Lifetime = R(0.35), Rotation = R(0, 45), LightEmission = 0.6, ZOffset = 1,
	})
	return m
end

-- ---------------------------------------------------------------- Drifting Cloud (Wind, rare)
-- Qi drifting in on the wind: a soft cloud you sit on; wind rings spiral in
-- toward you on each inhale and loosen on the exhale; wisps lift off you.

local WIND_CORE, WIND, CLOUD = rgb(220, 255, 242), rgb(140, 230, 200), rgb(246, 252, 250)

local function driftingCloud(root)
	local m = model("DriftingCloud", root, { BreathAt = 0.05 }) -- the inhale's start
	shell(m, rgb(170, 245, 220), { Pulse = R(0.3, 0.7), Pad = 0.35 })

	local ground = model("Ground", m)
	-- the cloud: soft white puffs round the seat
	for i, p in {
		{ 0, 0, 2.6, 1.2 }, { 1.5, -0.6, 1.9, 1 }, { -1.5, -0.6, 1.9, 1 }, { 1.2, 1.1, 1.8, 0.9 },
		{ -1.2, 1.1, 1.8, 0.9 }, { 0, -1.6, 1.8, 0.9 }, { 0, 1.6, 1.7, 0.85 }, { 2.3, 0.5, 1.4, 0.8 }, { -2.3, 0.5, 1.4, 0.8 },
	} do
		ellipsoid("Puff" .. i, ground, V3(p[3], p[4], p[3]), CFrame.new(p[1], 0.35, p[2]), CLOUD, {
			Pulse = R(0.04, 0.12), Bob = 0.06, Grow = R(0.97, 1.04),
		}, Enum.Material.SmoothPlastic)
	end
	mesh(A.torus, ground, "Under", ring(4.6, 1.2), CFrame.new(0, 0.1, 0), WIND, { Pulse = R(0.2, 0.55) })
	-- two wind rings turning against each other, drawn in on the inhale
	mesh(A.swirlRing, ground, "Swirl", V3(7, 1.2, 7), CFrame.new(0, 1.3, 0), WIND_CORE, {
		Pulse = R(0.25, 0.5), Spin = -120, Grow = R(0.62, 1), GrowIn = true,
	})
	mesh(A.swirlRing2, ground, "Swirl2", V3(6, 1.4, 6), CFrame.new(0, 2.7, 0), WIND, {
		Pulse = R(0.35, 0.6), Spin = 90, Grow = R(0.6, 1), GrowIn = true,
	})
	local rim = part("Rim", ground, CFrame.new(0, 1.6, 0), V3(7.5, 2.6, 7.5))
	loop(rim, "Streaks", {
		Texture = A.windStreak, Shape = sphere, ShapeStyle = surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Orientation = streak, Size = seq(0, 0.2, 0.5, 0.45, 1, 0.2), Transparency = seq(0, 1, 0.3, 0.45, 1, 1),
		Color = CS(WIND_CORE), Lifetime = R(0.9, 1.1), Speed = R(3, 3.6), Rate = 4, LightEmission = 0.3,
	}, { Scaled = true, Breathe = true })

	local limbs = folder("Limbs", m)
	loop(limbs, "Lift", {
		Texture = A.wisp, Shape = box, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0.3, 1, 0.8), Transparency = seq(0, 1, 0.3, 0.6, 1, 1), Color = CS(WIND_CORE),
		Lifetime = R(1, 1.4), Speed = R(1, 2), Acceleration = V3(0, 1.5, 0), Rotation = R(0, 360), RotSpeed = R(-60, 60),
		Rate = 1.2, LightEmission = 0.2,
	}, { On = "Arms,Torso", Scaled = true, Surge = 4 })

	-- each inhale: a wide wind ring sweeps in to the body
	local breath = model("Breath", m)
	local base = part("Base", breath, CFrame.new(0, 1.6, 0))
	wave(base, "Gather", {
		mesh = A.swirlRing, color = WIND_CORE, fromSize = V3(11, 1.6, 11), toSize = V3(2.6, 1.2, 2.6),
		fromTransparency = 0.35, toTransparency = 1, duration = 2, style = "Sine", fadeStyle = "Quart",
	})

	-- ignition: a gust bursts out of the cloud
	local ignite = model("Ignite", m)
	local gust = part("Base", ignite, CFrame.new(0, 0.6, 0), V3(4, 0.2, 4))
	wave(gust, "Gust", {
		mesh = A.swirlRing, color = WIND_CORE, fromSize = V3(3, 1.4, 3), toSize = V3(15, 3, 15),
		fromTransparency = 0, toTransparency = 1, duration = 0.9, style = "Quint",
	})
	wave(gust, "Gust2", {
		mesh = A.swirlRing2, color = WIND, fromSize = V3(4, 2, 4), toSize = V3(3, 3, 3), toOffset = V3(0, 5, 0),
		fromTransparency = 0.1, toTransparency = 1, duration = 0.9, style = "Quad",
	})
	burst(gust, "Puffs", 12, {
		Texture = A.puff, Shape = box, EmissionDirection = front, SpreadAngle = Vector2.new(5, 180),
		Size = seq(0, 0.8, 1, 2.2), Transparency = seq(0, 0.3, 1, 1), Color = CS(CLOUD), Lifetime = R(0.9, 1.2),
		Speed = R(8, 12), Drag = 3, Rotation = R(0, 360), LightInfluence = 0.3,
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

function _G.buildMethodAura(parent)
	local old = parent:FindFirstChild("MethodAura")
	if old then
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
	root.Parent = parent
	return root
end

return "buildMethodAura installed"
