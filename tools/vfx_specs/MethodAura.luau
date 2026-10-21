--!nocheck
-- Builder for ReplicatedStorage.Effects.MethodAura, the cultivation method aura
-- drawn around a seated player (Meditating + Method attributes), played by
-- src/client/MethodAura.luau. Run through execute_luau in Edit mode (served by
-- tools/receive_rbxmx.py, after tools/vfx_session.luau so _G.vfxBlocks exists):
--   local m = Instance.new("ModuleScript"); m.Source = HttpService:GetAsync(
--     "http://127.0.0.1:8766/vfx_specs/MethodAura.luau"); require(m)
--   _G.buildMethodAura(staging)   -- staging = vfxStage.begin(who)
-- It replaces staging.MethodAura.
--
-- Layout (pivot = the ground under the seated player, +Y up, identity
-- rotation; everything is built at the origin). Every piece is a Model:
--   Base     every method: a Neon ground Halo ring (torus) that breathes, a
--            faint flat pool, qi motes drifting up, and Breath (a MeshWave torus
--            that rises from the ground to the head, re-emitted each breath).
--   Rare     Lightning/Wind/Ice: a second, wider halo and a second breath ring.
--   Lotus    16 Neon petals (two rings of ellipsoids) the player sits in:
--            Fire's flame lotus, Wood's leaf lotus, Ice's frost lotus.
--   Orbit    a wispy swirl ring circling the waist (Water's water ring,
--            Lightning, Wind).
--   Accents  one Model per element (Fire, Water, ...): its particles and any
--            3D of its own (Metal's orbiting needles, Earth's floating rocks,
--            Wind's second swirl). Attributes `Lotus` / `Orbit` = true pull in
--            those shared pieces.
-- Runtime attributes on BaseParts (MethodAura animates them, Transparency 1 in
-- the template so nothing shows unplayed):
--   Pulse   NumberRange: transparency at full exhale..inhale (breathes with
--           the root's `Breath` period)
--   Spin    deg/s around the aura's vertical axis (orbiting / turning pieces)
--   Bob     studs of vertical sine drift;  Tumble  deg/s around its own axis
--   Flicker 0..1 random extra transparency per frame (lightning)
-- `Tint` ("color", "core" or "deep") recolours from the element's colour, as
-- in RootPillar. Loop emitters carry EmitDuration = -1 so the plugin's Enable
-- (T) shows them; `Scaled` emitters get the method grade's rate multiplier.
-- Root attributes: Breath (seconds per breath), FadeIn, FadeOut.

local B = _G.vfxBlocks
assert(B, "load tools/vfx_session.luau first")

local function id(n)
	return "rbxassetid://" .. n
end

local A = {
	glowDot = id(9841273544),
	softRing = id(15611941586),
	thinRing = id(9841273159),
	wisp = id(9345352897),
	torus = id(471124075),
	swirlRing = id(129778117978668),
	swirlRing2 = id(73349240058321),
	star4 = id(13271628051),
	-- accents
	flame = id(265788038),
	tongue = id(7216854783),
	spark = id(9841260273),
	bubble = id(249902641),
	leaf = id(17259245248),
	rocks = id(425665059),
	dust = id(11037785287),
	arcs = id(528280947),
	windStreak = id(426653646),
	cloudSwirl = id(281625948),
	ice = id(18765221838),
	puff = id(933102662),
}
_G.MethodAuraAssets = A

local NS, CS, KP, CK, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, ColorSequenceKeypoint.new, NumberRange.new
local V3 = Vector3.new
local WHITE = Color3.new(1, 1, 1)
local LOOP = -1 -- EmitDuration: enable and never disable

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

local function part(name, parent, cf, size, a)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size or V3(0.2, 0.2, 0.2)
	p.CFrame = cf or CFrame.new()
	attrs(p, a)
	p.Parent = parent
	return p
end

-- A looping emitter (off in the template; the runtime and the plugin's T enable it).
local function emitter(parent, name, props, a)
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

-- A visible-at-runtime mesh (Neon by default), hidden in the template.
local function mesh(meshId, parent, name, size, cf, a, material)
	local m = B.mesh(meshId, parent, name, size, cf, WHITE, material)
	attrs(m, a)
	return m
end

-- An ellipsoid: a Block with a Sphere SpecialMesh takes the part's size.
local function ellipsoid(name, parent, size, cf, a, material)
	local p = part(name, parent, cf, size, a)
	p.Material = material or Enum.Material.Neon
	local sm = Instance.new("SpecialMesh")
	sm.MeshType = Enum.MeshType.Sphere
	sm.Parent = p
	return p
end

-- torus 471124075 is 150 x 9.51 x 150; a round tube is Y = D * 0.0634
local function ring(d, fat)
	return V3(d, d * 0.0634 * (fat or 1), d)
end

local up = Enum.NormalId.Top
local box = Enum.ParticleEmitterShape.Box
local disc = Enum.ParticleEmitterShape.Disc
local volume = Enum.ParticleEmitterShapeStyle.Volume
local surface = Enum.ParticleEmitterShapeStyle.Surface

-- ------------------------------------------------------------------ Base

local function base(root)
	local m = model("Base", root)
	mesh(A.torus, m, "Halo", ring(7.4, 1.3), CFrame.new(0, 0.25, 0), { Tint = "core", Pulse = R(0.35, 0.6) })

	local ground = part("Ground", m, CFrame.new(0, 0.2, 0), V3(5, 0.2, 5))
	emitter(ground, "Pool", B.flat({
		Texture = A.softRing, Size = seq(0, 3.2, 1, 3.9), Transparency = seq(0, 1, 0.3, 0.72, 0.7, 0.72, 1, 1),
		Lifetime = R(4), Rate = 0.5, LightEmission = 0.3, ZOffset = -1,
	}), { Tint = "color" })
	-- motes rise from a disc around the seat and drift past the head
	local rim = part("Rim", m, CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, 0), V3(6.4, 0.2, 6.4))
	emitter(rim, "Motes", {
		Texture = A.glowDot, Shape = disc, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0, 0.15, 0.32, 0.8, 0.22, 1, 0), Transparency = seq(0, 0.2, 0.7, 0.35, 1, 1),
		Lifetime = R(2.6, 3.6), Speed = R(1.4, 2.4), SpreadAngle = Vector2.new(8, 8), Rate = 3.5,
		LightEmission = 0.6, Drag = 0.2, Acceleration = V3(0, 0.4, 0),
	}, { Tint = "core", Scaled = true })
	emitter(rim, "Wisps", {
		Texture = A.wisp, Shape = disc, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0.6, 1, 1.4), Transparency = seq(0, 1, 0.3, 0.78, 1, 1), Rotation = R(0, 360),
		RotSpeed = R(-25, 25), Lifetime = R(2.4, 3), Speed = R(0.8, 1.4), Rate = 0.8, LightEmission = 0.3,
	}, { Tint = "color", Scaled = true })

	-- one breath: a ring rising from the halo to above the head, closing in
	local breath = part("Breath", m, CFrame.new(0, 0.3, 0), V3(1, 0.2, 1))
	local w = B.meshWave(breath, "Rise", {
		mesh = A.torus, color = WHITE, fromSize = ring(7, 1.6), toSize = ring(2.6, 2.2),
		fromOffset = V3(0, 0, 0), toOffset = V3(0, 5.6, 0),
		fromTransparency = 0.25, toTransparency = 1, duration = 2.4, style = "Sine",
	})
	w:SetAttribute("FadeStyle", "Quad")
	w.Mesh:SetAttribute("Tint", "core")
	return m
end

-- ------------------------------------------------------------------ Rare

local function rare(root)
	local m = model("Rare", root)
	mesh(A.torus, m, "OuterHalo", ring(10, 1), CFrame.new(0, 0.22, 0), { Tint = "deep", Pulse = R(0.5, 0.78) })
	local breath = part("Breath", m, CFrame.new(0, 0.3, 0), V3(1, 0.2, 1))
	local w = B.meshWave(breath, "Rise", {
		mesh = A.torus, color = WHITE, fromSize = ring(9.6, 1.2), toSize = ring(3.4, 1.8),
		toOffset = V3(0, 7, 0), fromTransparency = 0.4, toTransparency = 1, duration = 2.8, style = "Sine",
		delay = 0.5,
	})
	w:SetAttribute("FadeStyle", "Quad")
	w.Mesh:SetAttribute("Tint", "deep")
	return m
end

-- ------------------------------------------------------------------ Lotus

local function lotus(root)
	local m = model("Lotus", root)
	-- outer petals: long and low; inner: shorter, steeper, offset half a petal
	for layer, p in { { r = 2.9, tilt = 24, size = V3(1.35, 0.22, 2.7), t = R(0.45, 0.7), n = 8, off = 0 },
		{ r = 2.1, tilt = 52, size = V3(1.05, 0.2, 2.1), t = R(0.35, 0.62), n = 8, off = 22.5 } } do
		for i = 1, p.n do
			local yaw = math.rad(p.off + (i - 1) * 360 / p.n)
			-- petal points outward along local -Z after the yaw, tilted up by `tilt`
			local cf = CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.35 + p.size.Z / 2 * math.sin(math.rad(p.tilt)), -p.r)
				* CFrame.Angles(math.rad(p.tilt), 0, 0)
			ellipsoid(("Petal%d_%d"):format(layer, i), m, p.size, cf, {
				Tint = if layer == 1 then "color" else "core", Pulse = p.t, Spin = 4,
			})
		end
	end
	return m
end

-- ------------------------------------------------------------------ Orbit

local function orbit(root)
	local m = model("Orbit", root)
	mesh(A.swirlRing, m, "Ring", V3(7.6, 1.3, 7.6), CFrame.new(0, 1.7, 0), { Tint = "color", Pulse = R(0.3, 0.55), Spin = 50 })
	return m
end

-- ------------------------------------------------------------------ Accents

local function accents(root)
	local f = Instance.new("Folder")
	f.Name = "Accents"
	f.Parent = root
	local function pad(name, a)
		local mm = model(name, f, a)
		return mm, part("Pad", mm, CFrame.new(0, 0.3, 0), V3(6.4, 0.2, 6.4))
	end

	-- Fire: flame lotus. Flame tongues lick up round the petals, embers rise.
	local _, fire = pad("Fire", { Lotus = true })
	emitter(fire, "Flames", {
		Texture = A.flame, Shape = disc, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0.2, 0.25, 0.75, 1, 0), Transparency = seq(0, 0.6, 0.3, 0.15, 1, 1),
		Color = cseq(0, Color3.fromRGB(255, 225, 140), 0.5, Color3.fromRGB(255, 130, 50), 1, Color3.fromRGB(230, 70, 30)),
		Lifetime = R(0.6, 0.9), Speed = R(1.5, 2.6), SpreadAngle = Vector2.new(5, 5), Rate = 9, LightEmission = 0.5,
		ZOffset = 1,
	}, { Scaled = true })
	emitter(fire, "Embers", {
		Texture = A.spark, Shape = disc, ShapeStyle = volume, EmissionDirection = up,
		Size = seq(0, 0.22, 0.7, 0.16, 1, 0), Transparency = seq(0, 0, 0.75, 0.1, 1, 1),
		Color = cseq(0, Color3.fromRGB(255, 236, 150), 1, Color3.fromRGB(255, 110, 40)),
		Lifetime = R(1.6, 2.4), Speed = R(2.5, 4), SpreadAngle = Vector2.new(15, 15), Rate = 4,
		Orientation = Enum.ParticleOrientation.VelocityParallel, LightEmission = 0.7, Acceleration = V3(0, 1, 0),
	}, { Scaled = true })

	-- Water: a water ring circling the waist, ripples spreading on the ground,
	-- a few bubbles drifting up.
	local _, water = pad("Water", { Orbit = true })
	emitter(water, "Ripples", B.flat({
		Texture = A.thinRing, Size = seq(0, 1, 1, 5.2), Transparency = seq(0, 0.35, 0.6, 0.6, 1, 1),
		Color = CS(Color3.fromRGB(170, 215, 255)), Lifetime = R(2.6), Rate = 0.7, LightEmission = 0.3,
	}), { Scaled = true })
	emitter(water, "Bubbles", {
		Texture = A.bubble, Shape = disc, ShapeStyle = volume, EmissionDirection = up,
		Size = rnd(0.14, 0.3), Transparency = seq(0, 1, 0.2, 0.3, 0.8, 0.4, 1, 1),
		Color = CS(Color3.fromRGB(200, 232, 255)), Lifetime = R(2.4, 3.2), Speed = R(1, 1.8), Rate = 2.5,
		LightEmission = 0.3,
	}, { Scaled = true })

	-- Wood: a leaf lotus, leaves drifting down around the player.
	local woodM = pad("Wood", { Lotus = true })
	local canopy = part("Canopy", woodM, CFrame.new(0, 6.5, 0), V3(7, 0.2, 7))
	emitter(canopy, "Leaves", {
		Texture = A.leaf, Shape = box, EmissionDirection = Enum.NormalId.Bottom,
		Size = rnd(0.32, 0.5), Transparency = seq(0, 1, 0.12, 0, 0.85, 0.05, 1, 1),
		Color = cseq(0, Color3.fromRGB(160, 230, 110), 1, Color3.fromRGB(90, 175, 70)),
		Lifetime = R(3.6, 4.6), Speed = R(1, 1.6), SpreadAngle = Vector2.new(25, 25), Acceleration = V3(0.3, -0.2, 0),
		Rotation = R(0, 360), RotSpeed = R(-120, 120), Rate = 2.2, LightInfluence = 0.4,
	}, { Scaled = true })

	-- Metal: four bright needles orbiting at the chest, glints winking.
	local metalM = pad("Metal")
	for i = 1, 4 do
		local yaw = math.rad((i - 1) * 90)
		-- tangent to the circle, tip leading
		ellipsoid("Needle" .. i, metalM, V3(0.16, 0.16, 1.7), CFrame.Angles(0, yaw, 0) * CFrame.new(3, 2.4, 0), {
			Tint = "core", Pulse = R(0.05, 0.25), Spin = 55, Bob = 0.25,
		})
	end
	local air = part("Air", metalM, CFrame.new(0, 2.2, 0), V3(6.5, 3.6, 6.5))
	emitter(air, "Glints", {
		Texture = A.star4, Shape = box, ShapeStyle = volume, Size = seq(0, 0, 0.3, 0.6, 1, 0),
		Transparency = NS(0), Rotation = R(0, 45), Color = CS(WHITE), Lifetime = R(0.35, 0.5), Rate = 3,
		LightEmission = 0.6,
	}, { Scaled = true })

	-- Earth: stones lifted off the ground, orbiting slowly; dust at the base.
	local earthM, earth = pad("Earth")
	local rockColors = { Color3.fromRGB(150, 118, 82), Color3.fromRGB(128, 100, 72), Color3.fromRGB(170, 135, 92) }
	for i = 1, 5 do
		local yaw = math.rad((i - 1) * 72 + 10)
		local s = 0.45 + (i % 3) * 0.15
		local rock = part("Rock" .. i, earthM, CFrame.Angles(0, yaw, 0) * CFrame.new(3.3, 1.1 + (i % 2) * 1.1, 0)
			* CFrame.Angles(i * 0.7, i * 1.3, i * 0.4), V3(s, s * 0.8, s * 1.1), {
			Pulse = R(0, 0), Spin = 14, Bob = 0.3, Tumble = 25,
		})
		rock.Material = Enum.Material.Slate
		rock.Color = rockColors[(i % 3) + 1]
	end
	emitter(earth, "Dust", B.flat({
		Texture = A.puff, Size = seq(0, 1.2, 1, 2.6), Transparency = seq(0, 1, 0.3, 0.8, 1, 1),
		Color = CS(Color3.fromRGB(210, 180, 135)), Lifetime = R(3), Rate = 0.6, Rotation = R(0, 360),
		RotSpeed = R(-20, 20),
	}), { Scaled = true })
	emitter(earth, "Grit", {
		Texture = A.rocks, Shape = disc, ShapeStyle = volume, EmissionDirection = up, Size = rnd(0.12, 0.22),
		Transparency = seq(0, 1, 0.15, 0, 0.8, 0, 1, 1), Lifetime = R(2.4, 3), Speed = R(0.8, 1.3),
		Rotation = R(0, 360), RotSpeed = R(-40, 40), Rate = 1.5, LightInfluence = 0.6,
	}, { Scaled = true })

	-- Lightning (rare): a crackling ring at the waist, arcs snapping round it.
	local lightningM, lightning = pad("Lightning", { Orbit = true })
	local field = part("Field", lightningM, CFrame.new(0, 1.8, 0), V3(7, 3.2, 7))
	emitter(field, "Arcs", {
		Texture = A.arcs, Shape = box, ShapeStyle = volume, Size = rnd(0.9, 1.5), Transparency = NS(0),
		Rotation = R(0, 360), Color = cseq(0, Color3.fromRGB(240, 230, 255), 1, Color3.fromRGB(190, 150, 255)),
		Lifetime = R(0.08, 0.16), Rate = 4, LightEmission = 0.8,
	}, { Scaled = true })
	emitter(lightning, "Sparks", {
		Texture = A.spark, Shape = disc, ShapeStyle = surface, EmissionDirection = up,
		Size = seq(0, 0.18, 1, 0), Lifetime = R(0.35, 0.6), Speed = R(4, 7),
		Color = CS(Color3.fromRGB(225, 210, 255)), SpreadAngle = Vector2.new(40, 40),
		Orientation = Enum.ParticleOrientation.VelocityParallel, Drag = 3, Rate = 5, LightEmission = 0.8,
	}, { Scaled = true })
	attrs(lightningM, { Flicker = 0.35 }) -- the shared Orbit ring flickers for lightning

	-- Wind (rare): two swirl rings turning against each other, streaks and
	-- cloud curls riding round.
	local windM, wind = pad("Wind", { Orbit = true })
	mesh(A.swirlRing2, windM, "Swirl", V3(9, 1.6, 9), CFrame.new(0, 3.1, 0), { Tint = "core", Pulse = R(0.4, 0.65), Spin = -70 })
	emitter(wind, "Streaks", B.flat({
		Texture = A.windStreak, Size = seq(0, 2, 1, 4.6), Transparency = seq(0, 1, 0.3, 0.55, 1, 1),
		Color = CS(Color3.fromRGB(205, 250, 232)), Lifetime = R(1.4), Rate = 1.2, LightEmission = 0.3,
		Rotation = R(0, 360), RotSpeed = R(-160, -110),
	}), { Scaled = true })
	emitter(wind, "Curls", {
		Texture = A.cloudSwirl, Shape = disc, ShapeStyle = surface, EmissionDirection = up,
		Size = rnd(0.5, 0.8), Transparency = seq(0, 1, 0.25, 0.4, 0.8, 0.5, 1, 1), Color = CS(Color3.fromRGB(225, 255, 245)),
		Lifetime = R(2.2, 2.8), Speed = R(1.2, 2), Rotation = R(0, 360), RotSpeed = R(-90, -60), Rate = 1.2,
		LightEmission = 0.2,
	}, { Scaled = true })

	-- Ice (rare): a frost lotus, crystals and snow drifting down, a frost ring.
	local iceM, ice = pad("Ice", { Lotus = true })
	local sky = part("Sky", iceM, CFrame.new(0, 6.5, 0), V3(7.5, 0.2, 7.5))
	emitter(sky, "Snow", {
		Texture = A.glowDot, Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.1, 0.18),
		Transparency = seq(0, 1, 0.15, 0.1, 0.85, 0.2, 1, 1), Color = CS(Color3.fromRGB(235, 248, 255)),
		Lifetime = R(4, 5), Speed = R(1.1, 1.6), SpreadAngle = Vector2.new(15, 15), Rate = 4, LightEmission = 0.4,
	}, { Scaled = true })
	emitter(sky, "Crystals", {
		Texture = A.ice, Shape = box, EmissionDirection = Enum.NormalId.Bottom, Size = rnd(0.25, 0.4),
		Transparency = seq(0, 1, 0.15, 0, 0.85, 0.1, 1, 1), Color = CS(Color3.fromRGB(225, 245, 255)),
		Lifetime = R(4, 5), Speed = R(1, 1.4), Rotation = R(0, 360), RotSpeed = R(-50, 50), Rate = 1,
		LightEmission = 0.2,
	}, { Scaled = true })
	emitter(ice, "Frost", B.flat({
		Texture = A.softRing, Size = seq(0, 3.6, 1, 4.8), Transparency = seq(0, 1, 0.3, 0.6, 1, 1),
		Color = CS(Color3.fromRGB(215, 245, 255)), Lifetime = R(3.5), Rate = 0.4, LightEmission = 0.3,
	}), { Scaled = true })
	return f
end

function _G.buildMethodAura(parent)
	local old = parent:FindFirstChild("MethodAura")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "MethodAura"
	attrs(root, { Breath = 5, FadeIn = 1.2, FadeOut = 1 })
	base(root)
	rare(root)
	lotus(root)
	orbit(root)
	accents(root)
	-- the petals, halos and rings sit in the floor's plane: keep emitters in front
	for _, d in root:GetDescendants() do
		if d:IsA("Model") then
			d.WorldPivot = CFrame.new()
		end
	end
	root.Parent = parent
	return root
end

return "buildMethodAura installed"
