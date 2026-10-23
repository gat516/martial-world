--!nocheck
-- Builder for ReplicatedStorage.WorldFX.Tribulation (assets/WorldFX.rbxm): the
-- heavenly tribulation's sky and strike effects, drawn by
-- src/client/WorldFX/TribulationFX.luau. Run through execute_luau in Edit mode
-- (served by tools/receive_rbxmx.py):
--   local m = Instance.new("ModuleScript"); m.Source = game:GetService("HttpService"):GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/Tribulation.luau"); require(m)
--   _G.tribulationBuild(game.ReplicatedStorage.WorldFX)  -- replaces WorldFX.Tribulation
--
-- Intent: the heavens judge a cultivator. A black-indigo storm wheel gathers over
-- the main peak's platform and churns, lightning crawling inside it round a glowing
-- eye; every strike is chosen first (the heavens' seal burns onto the ground and a
-- faint leader feels down from the eye), then the bolt slams down out of the eye.
-- Survive and the wheel tears open: gold light pours down through the eye and the
-- clouds are flung apart. Feel: dread, then release. Job: a server-wide landmark
-- (far), the motion of the storm (mid), and a readable strike rhythm up close.
--
-- Beat sheet (TribulationFX drives every phase from code; Emit attributes are kept
-- so the plugin can preview each piece with R):
--   gather   0-4 s after tribulationStart: arcs sink 80 studs and draw in from 1.4x,
--            the wheels fade in, the sky darkens (SkyGrade)
--   churn    while it lasts: wheels and arcs turn (inner fastest), billows roll on
--            the rim, the eye breathes, in-cloud flicker every 0.5-1.6 s (one
--            re-flash, never a strobe), crawling sky arcs, crackle on the arena edge
--   strike   per bolt, windup W from the server telegraph:
--              0      Seal fades in at the strike radius, closing ring starts at 2.2r
--              0.6W   Leader flickers down from the eye, Charge gathers under it
--              W      Bolt: core/body/glow beams down a jagged path + 3 branches;
--                     flash, star, shock rings, arcs, sparks, debris, dust; one light;
--                     the Scorch is left behind
--              +60ms  re-strike (the bolt dims and flares once), fade by +450 ms
--              Scorch cooling cracks 1.5 s, gone by 6 s
--   clear    tribulationEnd survived: eye flare 0.4 s, gold pillar drives down
--            0.3-1.0 s, wheels and arcs flung outward and up 0.6-5 s, gold motes
--            fall, a gold ring on the platform; failed: the wheel unwinds and fades
--
-- Layers (asset, why):
--   Vortex.Arcs      far   12 Cloud_WispArc clones (the user's cloud piece, CloudRing's
--                          mesh) in 4 rings, storm grey-indigo: the silhouette
--   Vortex.Wheel     far   ink swirl 266366832 (dark under light) and storm swirl
--                          95981596731268 on discs' undersides, turning
--   Vortex.Eye       far   spiral-core glow 13401485455 (black bg, additive) and a hard
--                          dot core: the eye the bolts fall from
--   Vortex.Billows   far   dark puffs 1084987899 rolling round the rim (reads edge-on)
--   Vortex.Flicker   far   cloud lightning 103597677385771 and a branching arc
--                          11736666805, emitted at random points inside the wheel
--   Vortex.SkyArcs   mid   jagged spiky line 131069691699670 beams crawling the underside
--   Vortex.Crackle   close arc flipbook 12800312415 (2x2) on the arena edge; Static motes
--   Seal             close thunder seal 133746306498771 and closing double ring
--                          18391527082 (SurfaceGui, turning); Leader beam
--                          136924338465402; Charge arcs 84820541525710 (2x2)
--   Strike.Bolt      far   per segment: Core (plain white), Body 136924338465402 (white
--                          bolt with dark edges: reads on a bright sky), Glow
--                          111922012770839 (soft violet)
--   Strike.Impact    close star 8944363782, dot 9841273544, spiky shock 13052243772,
--                          electric ring 6900421398, arcs 12800312415, sparks 243660364,
--                          rocks 130042646554310 (2x2), dust 11037785287
--   Scorch           close dark crater 127029400731687, glowing cracks 97725700315217,
--                          embers 9841273544
--   Finale           far   pillar body 16892366666 (soft band with stars) and core
--                          107598860822563, rays 12363860994, gold motes 7216848960,
--                          gold spiky ring 13052235894
-- Sounds (SoundService.SFX.Tribulation): Rumble 12222030, Charge 17524153633,
-- Crack 9119594718, Clear 140049602451857; the bolt keeps SFX.Thunder.

local function id(n)
	return "rbxassetid://" .. tostring(n)
end

local A = {
	inkSwirl = id(266366832),
	stormSwirl = id(95981596731268),
	eyeCore = id(13401485455),
	dot = id(9841273544),
	puff = id(1084987899),
	cloudBolt = id(103597677385771),
	branch = id(11736666805),
	spiky = id(131069691699670),
	arcs = id(12800312415),
	arcs2 = id(84820541525710),
	seal = id(133746306498771),
	doubleRing = id(18391527082),
	boltBody = id(136924338465402),
	boltGlow = id(111922012770839),
	star = id(8944363782),
	shock = id(13052243772),
	elecRing = id(6900421398),
	sliver = id(243660364),
	rocks = id(130042646554310),
	dust = id(11037785287),
	crater = id(127029400731687),
	cracks = id(97725700315217),
	pillarBody = id(16892366666),
	pillarCore = id(107598860822563),
	rays = id(12363860994),
	mote = id(7216848960),
	goldRing = id(13052235894),
}

local C = {
	ink = Color3.fromRGB(26, 22, 42),
	storm = Color3.fromRGB(86, 80, 118),
	stormLit = Color3.fromRGB(150, 146, 196),
	core = Color3.fromRGB(242, 246, 255),
	bolt = Color3.fromRGB(178, 170, 255),
	electric = Color3.fromRGB(120, 190, 255),
	gold = Color3.fromRGB(255, 208, 110),
	goldCore = Color3.fromRGB(255, 249, 228),
}

-- Heights above the platform (Config.Tribulation.CENTER)
local H = {
	eye = 118, -- the eye and the bolts' top
	wheel = 186, -- the storm swirl's underside
	ink = 196, -- the ink swirl above it
}

-- 4 rings of 3 arcs: length, height, turn speed (deg/s), phase
local RINGS = {
	{ len = 210, y = 112, speed = 16, phase = 0 },
	{ len = 340, y = 138, speed = -10, phase = 40 },
	{ len = 520, y = 162, speed = 7, phase = 15 },
	{ len = 780, y = 184, speed = -4.5, phase = 70 },
}
local ARC_RADIUS = 0.2865 -- an arc of length L closes a 3-arc ring at radius L * this

local function attrs(inst, t)
	for k, v in t or {} do
		inst:SetAttribute(k, v)
	end
	return inst
end

local function set(inst, props)
	for k, v in props or {} do
		inst[k] = v
	end
	return inst
end

local function ns(...)
	local args = { ... }
	if #args == 1 then
		return NumberSequence.new(args[1])
	end
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function nsr(a, b)
	local mid, env = (a + b) / 2, (b - a) / 2
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, mid, env), NumberSequenceKeypoint.new(1, mid, env) })
end

local function cs(c)
	return ColorSequence.new(c)
end

local function part(name, parent, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = cf or CFrame.new()
	p.Parent = parent
	return p
end

local function att(name, parent, pos, a)
	local x = Instance.new("Attachment")
	x.Name = name
	x.Position = pos or Vector3.zero
	attrs(x, a)
	x.Parent = parent
	return x
end

local function beam(name, a0, a1, props, a)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.LightInfluence = 0
	b.TextureMode = Enum.TextureMode.Stretch
	b.Enabled = false
	set(b, props)
	attrs(b, a)
	b.Parent = a0.Parent
	return b
end

local function emitter(name, parent, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.Enabled = false
	e.Rate = 0
	set(e, props)
	attrs(e, a)
	e.Parent = parent
	return e
end

-- A flat disc part (up = world up) with a SurfaceGui on `face` holding images.
local function disc(name, parent, diameter, y, face, brightness)
	local p = part(name, parent, Vector3.new(diameter, 0.2, diameter), CFrame.new(0, y, 0))
	local g = Instance.new("SurfaceGui")
	g.Name = "Gui"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(512, 512)
	g.LightInfluence = 0
	g.Brightness = brightness or 1
	g.ClipsDescendants = false
	g.Parent = p
	return p, g
end

local function image(name, gui, asset, color, transparency, scale, a)
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.Image = asset
	i.ImageColor3 = color
	i.ImageTransparency = transparency
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.Size = UDim2.fromScale(scale or 1, scale or 1)
	attrs(i, a)
	i.Parent = gui
	return i
end

local function model(name, parent, a)
	local m = Instance.new("Model")
	m.Name = name
	attrs(m, a)
	m.Parent = parent
	return m
end

local function finish(m)
	m.WorldPivot = CFrame.new() -- upright pivot at the ground point (PrimaryPart nil)
	return m
end

-- The arc mesh: CloudRing's (the user's Cloud_WispArc), or the map's kit.
local function arcSource()
	local wfx = game:GetService("ReplicatedStorage"):FindFirstChild("WorldFX")
	local ring = wfx and wfx:FindFirstChild("CloudRing")
	local arc = ring and ring:FindFirstChild("Arc", true)
	if not arc then
		local kit = game:GetService("ServerStorage"):FindFirstChild("CloudKit")
		arc = kit and kit:FindFirstChild("Cloud_WispArc")
	end
	assert(arc, "no Cloud_WispArc to clone (WorldFX.CloudRing or ServerStorage.CloudKit)")
	return arc
end

local Build = {}

function Build.Vortex(root)
	local m = model("Vortex", root, { EyeHeight = H.eye })

	-- far: the storm wheel of arcs, inner rings lower and faster (a funnel)
	local arcs = model("Arcs", m)
	local src = arcSource()
	local baseLen = src.Size.X
	for ri, ring in RINGS do
		local k = ring.len / baseLen
		local r = ring.len * ARC_RADIUS
		for j = 0, 2 do
			local arc = src:Clone()
			for _, c in arc:GetChildren() do
				if not c:IsA("SurfaceAppearance") then
					c:Destroy()
				end
			end
			arc.Name = "Arc"
			arc.Size = src.Size * k
			arc.Anchored, arc.CanCollide, arc.CanQuery, arc.CanTouch, arc.CastShadow = true, false, false, false, false
			local yaw = math.rad(ring.phase + j * 120)
			arc.CFrame = CFrame.new(math.sin(yaw) * r, ring.y, math.cos(yaw) * r) * CFrame.Angles(0, yaw, 0)
			local sa = arc:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa.Color = Color3.new(1, 1, 1):Lerp(C.storm, 0.85)
				attrs(sa, { Tint = "storm", TintMix = 0.85 })
			end
			attrs(arc, { Ring = ri, Yaw = ring.phase + j * 120, Radius = r, Height = ring.y, Speed = ring.speed })
			arc.Parent = arcs
		end
	end

	-- far: the turning wheel seen from below: an ink swirl behind a storm swirl
	local _, inkGui = disc("Ink", m, 820, H.ink, Enum.NormalId.Bottom, 1)
	image("Swirl", inkGui, A.inkSwirl, C.ink, 0.05, 1, { Speed = 5 })
	local _, wheelGui = disc("Wheel", m, 560, H.wheel, Enum.NormalId.Bottom, 1)
	image("Swirl", wheelGui, A.stormSwirl, C.storm, 0.15, 1, { Speed = 11 })
	image("Lit", wheelGui, A.stormSwirl, C.stormLit, 1, 0.82, { Speed = 15 }) -- flares with the flicker

	-- far: the eye
	local eye = part("Eye", m, Vector3.new(6, 6, 6), CFrame.new(0, H.eye, 0))
	emitter("Spiral", eye, {
		Texture = A.eyeCore, Lifetime = NumberRange.new(5), Rate = 0.8, Speed = NumberRange.new(0),
		Size = ns(0, 40, 0.5, 56, 1, 48), Transparency = ns(0, 1, 0.3, 0.55, 0.7, 0.55, 1, 1),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(30, 40),
		LightEmission = 1, Brightness = 1.3, Color = cs(C.bolt), LockedToPart = true, ZOffset = 1,
	}, { Layer = "far", EmitCount = 1 })
	emitter("Core", eye, {
		Texture = A.dot, Lifetime = NumberRange.new(1.6), Rate = 2, Speed = NumberRange.new(0),
		Size = ns(0, 10, 0.5, 15, 1, 10), Transparency = ns(0, 1, 0.4, 0.3, 1, 1),
		LightEmission = 1, Brightness = 3, Color = cs(C.core), LockedToPart = true, ZOffset = 2,
	}, { Layer = "far", EmitCount = 1 })

	-- far: dark billows rolling round the rim (they read from any angle)
	local rim = part("Rim", m, Vector3.new(620, 1, 620), CFrame.new(0, 165, 0))
	emitter("Billows", rim, {
		Texture = A.puff, Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = 0.55,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, EmissionDirection = Enum.NormalId.Top,
		Lifetime = NumberRange.new(10, 14), Rate = 2.5, Speed = NumberRange.new(1, 4), SpreadAngle = Vector2.new(90, 90),
		Size = ns(0, 90, 0.5, 170, 1, 190), Transparency = ns(0, 1, 0.25, 0.3, 0.75, 0.35, 1, 1),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-6, 6),
		LightEmission = 0, Brightness = 1, Color = cs(C.ink), LightInfluence = 0.3,
	}, { Layer = "far", EmitCount = 8 })

	-- mid: lightning flickering inside the wheel (TribulationFX moves the attachment
	-- to a random point and emits; the curve flares once more, never strobes)
	local flick = att("Flicker", eye, Vector3.new(0, 30, 0))
	local flare = ns(0, 0, 0.25, 0.55, 0.4, 0.05, 1, 1)
	emitter("Sheet", flick, {
		Texture = A.cloudBolt, Lifetime = NumberRange.new(0.28, 0.4), Speed = NumberRange.new(0),
		Size = nsr(110, 170), Transparency = flare, Rotation = NumberRange.new(0, 360),
		LightEmission = 1, Brightness = 3, Color = cs(C.bolt), ZOffset = 1,
	}, { Layer = "far", EmitCount = 1 })
	emitter("Branch", flick, {
		Texture = A.branch, Lifetime = NumberRange.new(0.22, 0.32), Speed = NumberRange.new(0),
		Size = nsr(50, 90), Transparency = flare, Rotation = NumberRange.new(0, 360),
		LightEmission = 1, Brightness = 5, Color = cs(C.core), ZOffset = 2,
	}, { Layer = "far", EmitCount = 1 })

	-- mid: arcs crawling the underside between two points (TribulationFX places them)
	local sky = part("SkyArcs", m, Vector3.new(1, 1, 1), CFrame.new(0, 150, 0))
	for i = 1, 3 do
		local a0 = att("A" .. i, sky, Vector3.new(-40, 0, 0))
		local a1 = att("B" .. i, sky, Vector3.new(40, 0, 0))
		beam("Arc" .. i, a0, a1, {
			Texture = A.spiky, Width0 = 9, Width1 = 9, Brightness = 4, LightEmission = 1,
			Color = cs(C.bolt), Transparency = ns(0, 0.6, 0.5, 0.05, 1, 0.6), Segments = 6,
			CurveSize0 = 20, CurveSize1 = -20,
		}, { Layer = "mid" })
	end

	-- close: crackle on the arena's edge and static in the air over the platform
	local floor = part("Floor", m, Vector3.new(70, 1, 70), CFrame.new(0, 0.6, 0))
	emitter("Crackle", floor, {
		Texture = A.arcs, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, FlipbookStartRandom = true,
		Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = 0.95, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.2, 0.35), Rate = 9,
		Speed = NumberRange.new(0.5, 2), Size = nsr(3, 6), Rotation = NumberRange.new(0, 360),
		Transparency = ns(0, 0, 0.7, 0.2, 1, 1), LightEmission = 1, Brightness = 4, Color = cs(C.electric),
	}, { Layer = "close", EmitCount = 6 })
	emitter("Static", floor, {
		Texture = A.dot, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(2, 3.5), Rate = 10,
		Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(20, 20), Size = ns(0, 0.25, 0.5, 0.45, 1, 0),
		Transparency = ns(0, 1, 0.15, 0, 0.5, 0.7, 0.6, 0, 1, 1), LightEmission = 1, Brightness = 4,
		Color = cs(C.electric),
	}, { Layer = "close", EmitCount = 10 })

	-- the one light: TribulationFX moves it to each strike and decays it
	local lamp = part("Lamp", m, Vector3.new(1, 1, 1), CFrame.new(0, 6, 0))
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = C.bolt
	light.Brightness = 0
	light.Range = 55
	light.Shadows = false
	light.Parent = lamp

	return finish(m)
end

-- The heavens choose the spot. Authored for radius 5 (Config.Tribulation.STRIKE_RADIUS);
-- TribulationFX resizes the disc to the server's radius.
function Build.Seal(root)
	local m = model("Seal", root, { Radius = 5 })
	local p, gui = disc("Disc", m, 5 * 2 * 1.25, 0.25, Enum.NormalId.Top, 3)
	image("Seal", gui, A.seal, C.electric, 0.3, 1, { Speed = 40 })
	image("Closing", gui, A.doubleRing, C.core, 0.2, 2.2 / 1.25, { Speed = -25 }) -- shrinks to 1 / 1.25 (the strike radius)
	-- the leader: from the eye down to the seal, flickering in the last part of the windup
	local top = att("Top", p, Vector3.new(0, 128, 0))
	local bottom = att("Bottom", p, Vector3.new(0, 0, 0))
	beam("Leader", top, bottom, {
		Texture = A.boltBody, Width0 = 1.6, Width1 = 0.8, Brightness = 3, LightEmission = 1,
		Color = cs(C.bolt), Transparency = ns(0, 0.3, 1, 0.6), TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 40, TextureSpeed = -2, ZOffset = 1,
	})
	emitter("Charge", top, {
		Texture = A.arcs2, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, FlipbookStartRandom = true,
		Lifetime = NumberRange.new(0.2, 0.3), Rate = 14, Speed = NumberRange.new(0), Size = nsr(10, 18),
		Rotation = NumberRange.new(0, 360), Transparency = ns(0, 0, 1, 1), LightEmission = 1, Brightness = 5,
		Color = cs(C.core),
	}, { EmitCount = 3 })
	emitter("Spark", bottom, {
		Texture = A.arcs, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, FlipbookStartRandom = true,
		Shape = Enum.ParticleEmitterShape.Disc, ShapePartial = 0.9, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.18, 0.28), Rate = 0,
		Speed = NumberRange.new(0.5, 1.5), Size = nsr(1.5, 3), Rotation = NumberRange.new(0, 360),
		Transparency = ns(0, 0, 1, 1), LightEmission = 1, Brightness = 4, Color = cs(C.electric),
	}, { EmitCount = 4 })
	return finish(m)
end

-- The bolt and its impact. The Bolt part's P0..P7 attachments are set to a jagged
-- path by TribulationFX (P0 at the eye, P7 on the ground); branches fork off P2/P3/P5.
local SEGMENTS = 7
function Build.Strike(root)
	local m = model("Strike", root, { Segments = SEGMENTS })
	local bolt = part("Bolt", m, Vector3.new(1, 1, 1), CFrame.new(0, 0, 0))
	local pts = {}
	for i = 0, SEGMENTS do
		pts[i] = att("P" .. i, bolt, Vector3.new(0, H.eye * (1 - i / SEGMENTS), 0))
	end
	for i = 1, SEGMENTS do
		local a0, a1 = pts[i - 1], pts[i]
		beam("Glow" .. i, a0, a1, {
			Texture = A.boltGlow, Width0 = 16, Width1 = 16, Brightness = 3, LightEmission = 1,
			Color = cs(C.bolt), Transparency = ns(0.35), ZOffset = 0,
		}, { Role = "glow" })
		beam("Body" .. i, a0, a1, {
			Texture = A.boltBody, Width0 = 6, Width1 = 6, Brightness = 6, LightEmission = 0.6,
			Color = cs(C.core), Transparency = ns(0), ZOffset = 1,
		}, { Role = "body" })
		beam("Core" .. i, a0, a1, {
			Width0 = 0.8, Width1 = 0.8, Brightness = 12, LightEmission = 1,
			Color = cs(C.core), Transparency = ns(0), ZOffset = 2,
		}, { Role = "core" })
	end
	for b = 1, 3 do
		local from = att("BranchFrom" .. b, bolt)
		local mid = att("BranchMid" .. b, bolt)
		local to = att("BranchTo" .. b, bolt)
		for s, pair in { { from, mid }, { mid, to } } do
			beam("Branch" .. b .. "_" .. s, pair[1], pair[2], {
				Texture = A.boltGlow, Width0 = 5 - s, Width1 = 4 - s * 1.5, Brightness = 5, LightEmission = 1,
				Color = cs(C.bolt), Transparency = ns(0), ZOffset = 1,
			}, { Role = "branch" })
		end
	end

	-- impact (flat, up = world up)
	local hit = part("Impact", m, Vector3.new(4, 0.2, 4), CFrame.new(0, 0.3, 0))
	emitter("Star", hit, {
		Texture = A.star, Lifetime = NumberRange.new(0.22), Speed = NumberRange.new(0),
		Size = ns(0, 14, 0.25, 30, 1, 8), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, Color = cs(C.core), ZOffset = 4,
	}, { EmitCount = 1 })
	emitter("Flash", hit, {
		Texture = A.dot, Lifetime = NumberRange.new(0.16), Speed = NumberRange.new(0),
		Size = ns(0, 8, 0.3, 14, 1, 6), Transparency = ns(0, 0, 1, 1),
		LightEmission = 1, Brightness = 6, Color = cs(C.bolt), ZOffset = 3,
	}, { EmitCount = 1 })
	emitter("Shock", hit, {
		Texture = A.shock, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.32), Size = ns(0, 3, 1, 24), Transparency = ns(0, 0, 0.5, 0.2, 1, 1),
		Rotation = NumberRange.new(0, 360), LightEmission = 1, Brightness = 5, Color = cs(C.core),
	}, { EmitCount = 1 })
	emitter("Ring", hit, {
		Texture = A.elecRing, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.6), Size = ns(0, 6, 1, 36), Transparency = ns(0, 0.1, 0.6, 0.4, 1, 1),
		Rotation = NumberRange.new(0, 360), LightEmission = 1, Brightness = 4, Color = cs(C.electric),
	}, { EmitCount = 1, EmitDelay = 0.04 })
	emitter("Arcs", hit, {
		Texture = A.arcs, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, FlipbookStartRandom = true,
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.2, 0.32),
		Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(60, 60), Size = nsr(4, 8),
		Rotation = NumberRange.new(0, 360), Transparency = ns(0, 0, 0.7, 0.2, 1, 1),
		LightEmission = 1, Brightness = 5, Color = cs(C.electric),
	}, { EmitCount = 6 })
	emitter("Sparks", hit, {
		Texture = A.sliver, Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(35, 75), SpreadAngle = Vector2.new(75, 75),
		Lifetime = NumberRange.new(0.3, 0.6), Acceleration = Vector3.new(0, -60, 0), Drag = 3,
		Size = ns(0, 1.4, 1, 0.3), Transparency = ns(0, 0, 0.8, 0.2, 1, 1),
		LightEmission = 1, Brightness = 6, Color = cs(C.core),
	}, { EmitCount = 22 })
	emitter("Debris", hit, {
		Texture = A.rocks, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot, FlipbookFramerate = NumberRange.new(0.01),
		FlipbookStartRandom = true, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(22, 40), SpreadAngle = Vector2.new(45, 45), Lifetime = NumberRange.new(0.9, 1.3),
		Acceleration = Vector3.new(0, -110, 0), Size = nsr(0.7, 1.5), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-360, 360), Transparency = ns(0, 0, 0.8, 0, 1, 1),
		LightEmission = 0, Brightness = 1, Color = cs(Color3.fromRGB(70, 66, 82)), LightInfluence = 0.6,
	}, { EmitCount = 9 })
	emitter("Dust", hit, {
		Texture = A.dust, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(80, 80), Lifetime = NumberRange.new(1.1, 1.6), Drag = 2,
		Size = ns(0, 5, 1, 13), Transparency = ns(0, 0.5, 0.3, 0.55, 1, 1),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
		LightEmission = 0, Brightness = 1, Color = cs(Color3.fromRGB(96, 90, 118)), LightInfluence = 0.5,
	}, { EmitCount = 5, EmitDelay = 0.05 })
	return finish(m)
end

-- The burnt mark a strike leaves: a dark crater with cracks glowing and cooling.
function Build.Scorch(root)
	local m = model("Scorch", root, { Radius = 5 })
	local _, gui = disc("Disc", m, 5 * 2 * 1.5, 0.18, Enum.NormalId.Top, 2.5)
	image("Burn", gui, A.crater, Color3.fromRGB(20, 16, 28), 0.1, 1)
	image("Cracks", gui, A.cracks, C.electric, 0, 0.8)
	local p = m:FindFirstChild("Disc")
	emitter("Embers", p, {
		Texture = A.dot, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.8, 1.6), Rate = 10,
		Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(25, 25), Size = ns(0, 0.3, 1, 0),
		Transparency = ns(0, 0, 1, 1), LightEmission = 1, Brightness = 4, Color = cs(C.electric),
	}, { EmitDuration = 1.2 })
	return finish(m)
end

-- Survived: the heavens open. Placed at the platform; the pillar runs to the eye.
function Build.Finale(root)
	local m = model("Finale", root)
	local shaft = part("Shaft", m, Vector3.new(1, 1, 1), CFrame.new(0, 0, 0))
	local bottom = att("Bottom", shaft, Vector3.new(0, 0.5, 0))
	local top = att("Top", shaft, Vector3.new(0, H.eye + 60, 0))
	beam("Body", bottom, top, {
		Texture = A.pillarBody, Width0 = 46, Width1 = 70, Brightness = 2.5, LightEmission = 0.6,
		Color = cs(C.gold), Transparency = ns(0, 0.2, 0.8, 0.3, 1, 1), ZOffset = 1,
		TextureMode = Enum.TextureMode.Wrap, TextureLength = 90, TextureSpeed = -0.25,
	})
	beam("Core", bottom, top, {
		Texture = A.pillarCore, Width0 = 9, Width1 = 12, Brightness = 8, LightEmission = 1,
		Color = cs(C.goldCore), Transparency = ns(0, 0, 0.85, 0.2, 1, 1), ZOffset = 2,
	})
	local eye = part("Eye", m, Vector3.new(80, 1, 80), CFrame.new(0, H.eye + 10, 0))
	emitter("Rays", eye, {
		Texture = A.rays, Lifetime = NumberRange.new(2.5, 3.5), Speed = NumberRange.new(0),
		Size = ns(0, 120, 0.5, 260, 1, 300), Transparency = ns(0, 1, 0.3, 0.35, 1, 1),
		Rotation = NumberRange.new(-10, 10), LightEmission = 1, Brightness = 2.5, Color = cs(C.gold), ZOffset = 0,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
	}, { EmitCount = 2 })
	emitter("Flare", eye, {
		Texture = A.star, Lifetime = NumberRange.new(0.8), Speed = NumberRange.new(0),
		Size = ns(0, 30, 0.25, 160, 1, 40), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, Color = cs(C.goldCore), ZOffset = 3,
	}, { EmitCount = 1 })
	emitter("Motes", eye, {
		Texture = A.mote, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Bottom, Lifetime = NumberRange.new(6, 9), Rate = 26,
		Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(20, 20), Acceleration = Vector3.new(0, 0.6, 0),
		Size = ns(0, 0.8, 0.5, 1.8, 1, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
		Transparency = ns(0, 1, 0.1, 0, 0.8, 0.3, 1, 1), LightEmission = 1, Brightness = 4, Color = cs(C.gold),
	}, { EmitDuration = 3.5 })
	local ground = part("Ground", m, Vector3.new(30, 0.2, 30), CFrame.new(0, 0.3, 0))
	emitter("Ring", ground, {
		Texture = A.goldRing, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(1.2), Size = ns(0, 6, 1, 80), Transparency = ns(0, 0, 0.6, 0.35, 1, 1),
		Rotation = NumberRange.new(0, 360), LightEmission = 1, Brightness = 4, Color = cs(C.gold),
	}, { EmitCount = 1, EmitDelay = 0.7 })
	emitter("Rise", ground, {
		Texture = A.mote, Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(15, 15), Size = ns(0, 0.6, 0.5, 1.2, 1, 0), Rotation = NumberRange.new(0, 360),
		Transparency = ns(0, 1, 0.1, 0, 1, 1), LightEmission = 1, Brightness = 4, Color = cs(C.goldCore),
	}, { EmitCount = 30, EmitDelay = 0.7 })
	return finish(m)
end

local ORDER = { "Vortex", "Seal", "Strike", "Scorch", "Finale" }

_G.tribulationBuild = function(root)
	local old = root:FindFirstChild("Tribulation")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Tribulation"
	attrs(folder, { Spec = "tools/vfx_specs/Tribulation.luau" })
	for _, name in ORDER do
		Build[name](folder)
	end
	folder.Parent = root
	return folder
end

_G.TribulationAssets = A
return true
