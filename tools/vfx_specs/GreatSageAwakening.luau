--!nocheck
-- Great Sage Awakening's templates (GreatSageAwakening_T1..T4). Build with
-- spec.build(parent). Runtime: src/client/TechniqueFX/GreatSageAwakening.luau.
--
-- Gameplay: Staff technique, a self buff (+25% damage, +15% attack speed for
-- 8 s) with a circle r 8 burst at the strike (12 dmg). Animation
-- 92849379287075 (1.75 s), one hit 1.15-1.25. Sampled on StaffRig: the staff
-- is raised over the head by 0.2 s and twirled flat ~2.5 studs above the
-- root (~5 turns a second, both ends ~5 studs out) until ~1.0 s; at 1.05-1.15
-- it is brought down so one end strikes the ground ~5 studs ahead at 1.15,
-- then it sweeps on to the left. The template pivot is the ground under the
-- caster facing -Z; authored at radius 8, active 0.1 s, windup 1.15 s.
--
-- The motif: the Great Sage (the Monkey King) wakes: his golden circlet,
-- golden flame, the somersault cloud, fiery golden eyes.
--
-- THE SHOT, tier by tier
--
-- I (levels 1-3), "the circlet"
--   Twirl (cast start -> Hit; TechniqueFX windup(), part "Twirl"): both ends
--     of the spinning staff trail gold ribbons of light (a disc of arcs over
--     the head); a rune seal grows and turns on the ground under the feet;
--     gold motes rise from it into the spin; qi gathers into the right hand
--     ("Windup").
--   Strike (Hit): the staff end slams the ground ~5 studs ahead ("Slam": star
--     flash, upright and ground 3D shock rings, dust, a light shake); a gold
--     flash on the body ("Body"); the awakening burst opens from the feet to
--     the radius ("Ground": the shared ground shockwave with a 3D torus,
--     dust skirt) and a pillar of gold light (a stretched Neon ball) shoots
--     up from the caster (~0.55 s). Every enemy inside gets a gold
--     impactStack as the front reaches it.
--   Buff (8 s, everyone sees it, "Aura"): a solid gold Neon circlet round the
--     head; gold flame wisps rising off the body (~6 a second); the staff
--     leaves short gold arcs on every swing ("Staff"). At the end a puff of
--     gold motes and a thin ring ("Fade").
-- II (4-6), "the cloud"
--   + rays behind the body flash, an echo ring, gold streaks up the pillar,
--     impact swirl and dust; the aura adds somersault-cloud puffs at the feet
--     and rising motes; the circlet pulses.
-- III (7-9), "fiery golden eyes"
--   + a wind swirl climbs the body during the twirl; the strike adds a
--     Craters rock ring at the radius, an ornate seal on the ground and slam
--     cracks; impacts get bubbles and rock kicks; the aura adds two glowing
--     golden eyes.
-- IV (10), "Equal to Heaven"
--   + a second torus, a taller pillar with a spike crown at its foot and an
--     Explosion quake; the aura adds a turning halo ring behind the back and
--     the move's one light, flashed bright at the strike and held soft gold
--     on the body for the 8 s.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local A = {
	flame = id(265788038),
	glow = id(867619398),
	star12 = id(243728206),
	spindle = id(7814053668),
	mote = id(9841260273),
	rune = id(83667248904000),
	ornate = id(13399941667),
	rays = id(15773612675),
	thinRing = id(9841273159),
	dust = id(11037785287),
	cloud = id(11037785676),
	crack = id(93520831389146),
	torus = id(471124075),
	swirl = id(129778117978668),
	swirlRing = id(122217820569960),
	crownLow = id(489415286),
}

local GOLD = Color3.fromRGB(255, 204, 84)
local CORE = Color3.fromRGB(255, 244, 205)
local FLAME = Color3.fromRGB(255, 132, 44) -- the red-orange edge of the Sage's flame
local N_GOLD = Color3.fromRGB(236, 166, 36) -- Neon blooms toward white, so deeper
local CLOUD = Color3.fromRGB(255, 246, 228)
local PAL = {
	color = GOLD, core = CORE,
	ringColor = Color3.fromRGB(255, 232, 160), swirlColor = Color3.fromRGB(255, 205, 100), groundColor = Color3.fromRGB(255, 220, 140),
}
local function pal(extra)
	local t = table.clone(PAL)
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

local RADIUS, WINDUP, ACTIVE = 8, 1.15, 0.1
local HAND_AT = O * CFrame.new(0.5, 5.6, -0.9) -- the right hand holding the spin
local SLAM_AT = O * CFrame.new(0, 0.15, -4.8)
local BODY_AT = O * CFrame.new(0, 3, 0)

local function B()
	return _G.vfxBlocks
end
local function emitter(parent, name, props, attrs)
	return B().emitter(parent, name, props, attrs)
end
local function wave(parent, name, p, fadeStyle)
	local w = B().meshWave(parent, name, p)
	w:SetAttribute("FadeStyle", fadeStyle or "Quint")
	return w
end

local blocks = {}

-- The twirl at the feet: the ground seal, rising motes, III+ the climbing
-- wind swirl, and the staff-end trail the runtime fixes to the weapon.
function blocks.twirl(root, tier, p)
	local twirl = B().part(root, "Twirl", O * CFrame.new(0, 0.2, 0), V(5, 0.2, 5))
	twirl:SetAttribute("AuthoredWindup", WINDUP)
	emitter(twirl, "Seal", B().flat({
		Texture = A.rune, Color = CS(GOLD),
		Size = NS({ KP(0, 0.8), KP(0.7, 3.6 + tier * 0.3), KP(0.9, 4 + tier * 0.3), KP(1, 4.2 + tier * 0.3) }),
		Transparency = NS({ KP(0, 1), KP(0.3, 0.35), KP(0.85, 0.15), KP(1, 0.6) }),
		Lifetime = R(WINDUP + 0.1), LightEmission = 0.45, RotSpeed = R(70), Rotation = R(0, 360), ZOffset = 0.2,
	}), { EmitCount = 1 })
	-- streaks rising from the seal into the spin (spindles, so they read
	-- at play distance; round motes this small vanished)
	local rise = emitter(twirl, "Rise", {
		Texture = A.spindle, Color = CS(CORE, GOLD), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12),
		Size = NS({ KP(0, 0.42), KP(1, 0.12) }), Squash = NS(1.8), Transparency = NS({ KP(0, 1), KP(0.15, 0.05), KP(1, 0.7) }),
		Lifetime = R(0.55, 0.75), Speed = R(7, 10), LightEmission = 0.6, Rotation = R(0, 360),
		Rate = ({ 9, 11, 14, 18 })[tier],
	})
	rise:SetAttribute("EmitDuration", WINDUP - 0.15)
	if tier >= 3 then
		wave(twirl, "Swirl", {
			mesh = A.swirl, color = Color3.fromRGB(255, 226, 150),
			fromSize = V(3.2, 0.7, 3.2), toSize = V(4.4, 1.4, 4.4),
			fromOffset = V(0, 0.3, 0), toOffset = V(0, 5.2, 0),
			fromTransparency = 0.45, toTransparency = 1, duration = 0.9, style = "Sine", delay = 0.15,
		}, "Quad")
	end
	local arc = Instance.new("Trail")
	arc.Name = "Arc"
	arc.Color = CS({ CK(0, CORE), CK(0.4, GOLD), CK(1, FLAME) })
	arc.Transparency = NS({ KP(0, 0.1), KP(0.5, 0.45), KP(1, 1) })
	arc.WidthScale = NS({ KP(0, 1), KP(1, 0.4) })
	arc.Lifetime = ({ 0.14, 0.16, 0.18, 0.2 })[tier]
	arc.LightEmission, arc.LightInfluence = 0.6, 0
	arc.MinLength = 0.05
	arc.Enabled = false
	arc:SetAttribute("Inward", 1.6)
	arc.Parent = twirl
	return twirl
end

-- The pillar of gold light and the body flash at the strike.
function blocks.awaken(root, tier, p)
	local ground = root:FindFirstChild("Ground")
	local tall = ({ 12, 15, 18, 24 })[tier]
	-- a Cylinder, stood up (a Ball part can't be stretched: it stays round)
	-- (translucent and slim: a solid one hid the caster and bloomed lemon)
	local d = 1.5 + tier * 0.25
	local pillar = wave(ground, "Pillar", {
		mesh = "Ball", material = Enum.Material.Neon, color = Color3.fromRGB(226, 146, 40),
		fromSize = V(3, 1.2, 1.2), toSize = V(tall, d, d), rotation = V(0, 0, 90),
		fromOffset = V(0, 1.5, 0), toOffset = V(0, tall / 2, 0),
		fromTransparency = 0.45, toTransparency = 1, duration = 0.55, style = "Quart",
	}, "Quad")
	pillar.Mesh.Shape = Enum.PartType.Cylinder
	if tier >= 2 then
		emitter(ground, "Streaks", {
			Texture = A.spindle, Color = CS(CORE, GOLD), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6),
			Size = NS({ KP(0, 0.3), KP(1, 0.1) }), Squash = NS(2.5), Transparency = NS({ KP(0, 0), KP(1, 1) }),
			Lifetime = R(0.35, 0.5), Speed = R(26, 38), Drag = 2, LightEmission = 0.6,
		}, { EmitCount = ({ 0, 6, 8, 12 })[tier] })
	end
	if tier >= 3 then
		emitter(ground, "Seal", B().flat({
			Texture = A.ornate, Color = CS(GOLD),
			Size = NS({ KP(0, 2), KP(0.2, 5.5), KP(1, 6.2) }), Transparency = NS({ KP(0, 0.15), KP(0.5, 0.3), KP(1, 1) }),
			Lifetime = R(0.95), LightEmission = 0.45, RotSpeed = R(-50), Rotation = R(0, 360), ZOffset = 0.1,
		}), { EmitCount = 1 })
		B().craterRing(root, tier, { parent = "Ground", radius = RADIUS, attrs = { Duration = 0.3 } })
	end
	if tier >= 4 then
		wave(ground, "GroundWave2", {
			mesh = A.torus, color = Color3.fromRGB(255, 236, 190),
			fromSize = V(1.5, 0.2, 1.5), toSize = V(RADIUS * 2.3, 1.4, RADIUS * 2.3),
			fromOffset = V(0, 0.25, 0), toOffset = V(0, 0.25, 0),
			fromTransparency = 0.5, toTransparency = 1, duration = 0.5, style = "Quart", delay = 0.1,
		})
		wave(ground, "Crown", {
			mesh = A.crownLow, color = N_GOLD,
			fromSize = V(2.5, 1, 2.5), toSize = V(7, 4, 7), fromOffset = V(0, 0.3, 0), toOffset = V(0, 1.2, 0),
			fromTransparency = 0.2, toTransparency = 1, duration = 0.5, style = "Quart",
		})
		B().screenShake(root, tier, { parent = "Ground", name = "Quake", preset = "Explosion", falloff = "20~80" })
	end
	-- the flash on the body
	local body = B().part(root, "Body", BODY_AT)
	emitter(body, "Flash", {
		Texture = A.star12, Color = CS(CORE),
		Size = NS({ KP(0, 0.5), KP(0.3, 3 + tier * 0.4), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 0.5) }),
		Lifetime = R(0.2), LightEmission = 0.6, Rotation = R(0, 360), ZOffset = 1.5,
	}, { EmitCount = 1 })
	emitter(body, "Glow", {
		Texture = A.glow, Color = CS(GOLD),
		Size = NS({ KP(0, 1.5), KP(1, 3.5 + tier * 0.4) }), Transparency = NS({ KP(0, 0.25), KP(1, 1) }),
		Lifetime = R(0.35), LightEmission = 0.4, ZOffset = 1,
	}, { EmitCount = 1 })
	if tier >= 2 then
		emitter(body, "Rays", {
			Texture = A.rays, Color = CS(GOLD),
			Size = NS({ KP(0, 1.5), KP(0.3, 4.5 + tier * 0.4), KP(1, 5 + tier * 0.4) }), Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			Lifetime = R(0.45), LightEmission = 0.5, RotSpeed = R(40), Rotation = R(0, 360), ZOffset = -1,
		}, { EmitCount = 1 })
	end
	return body
end

-- The staff end striking the ground ahead.
function blocks.slam(root, tier, p)
	local q = pal({ part = "Slam", at = SLAM_AT })
	B().impactBurst(root, tier, q)
	q.size = ({ 3.2, 3.8, 4.6, 5.6 })[tier]
	q.groundSize = ({ 4.2, 5, 6, 7.4 })[tier]
	q.swirl, q.bubble = false, false
	B().impactShockwave(root, tier, q)
	local slam = root:FindFirstChild("Slam")
	slam.Body.Position = V(0, 0.8, 0)
	if tier >= 3 then
		emitter(slam, "Cracks", B().flat({
			Texture = A.crack, Color = CS(Color3.fromRGB(110, 88, 56)), LightInfluence = 0.3,
			Size = NS(2.2 + (tier - 3) * 0.8), Transparency = NS({ KP(0, 1), KP(0.04, 0.15), KP(0.6, 0.3), KP(1, 1) }),
			Lifetime = R(1.3), Rotation = R(0, 360), ZOffset = -0.5,
		}), { EmitCount = 1 })
	end
	B().screenShake(root, tier, { parent = "Slam", magnitude = ({ 0.9, 1.3, 1.8, 2.2 })[tier] })
	return slam
end

-- The buff aura: emitters the runtime moves onto the body (Bone = the body
-- part), held MeshParts it drives there (Offset from the bone, Show
-- transparency, Spin deg/s, Pulse), and the staff trail for the buff.
function blocks.aura(root, tier, p)
	local aura = B().part(root, "Aura", BODY_AT, V(2, 2, 1))
	aura:SetAttribute("EmitDuration", 8) -- the plugin's T button shows the hold
	local flames = emitter(aura, "Flames", {
		Texture = A.flame, Color = CS({ CK(0, CORE), CK(0.35, GOLD), CK(1, FLAME) }),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
		Size = NS({ KP(0, 0.5), KP(0.3, 1.0 + tier * 0.1), KP(1, 0.15) }),
		Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(0.7, 0.4), KP(1, 1) }),
		Lifetime = R(0.5, 0.8), Speed = R(1.5, 3), Acceleration = V(0, 4, 0),
		LightEmission = 0.3, LightInfluence = 0.15, Rotation = R(-10, 10), ZOffset = -0.3,
		Rate = ({ 6, 8, 10, 12 })[tier],
	})
	flames:SetAttribute("Bone", "Torso")
	if tier >= 2 then
		local motes = emitter(aura, "Motes", {
			Texture = A.mote, Color = CS(CORE, GOLD),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
			Size = NS({ KP(0, 0.18), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
			Lifetime = R(0.7, 1), Speed = R(1.5, 3), LightEmission = 0.6, Rate = ({ 0, 4, 5, 6 })[tier],
		})
		motes:SetAttribute("Bone", "Torso")
		local feet = B().attach(aura, "Feet", V(0, -2.8, 0), { Bone = "HumanoidRootPart" })
		emitter(feet, "Cloud", {
			Texture = A.cloud, Color = CS(CLOUD, Color3.fromRGB(255, 226, 170)), LightInfluence = 0.4,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(85, 85),
			Size = NS({ KP(0, 0.6), KP(0.4, 1.3), KP(1, 1.8) }), Transparency = NS({ KP(0, 1), KP(0.25, 0.45), KP(1, 1) }),
			Lifetime = R(0.9, 1.3), Speed = R(1.5, 2.5), Drag = 2, Rotation = R(0, 360), RotSpeed = R(-30, 30),
			Rate = ({ 0, 3, 3.5, 4 })[tier], ZOffset = -0.5,
		})
	end
	if tier >= 3 then
		for _, x in { -0.2, 0.2 } do
			local eye = B().attach(aura, if x < 0 then "EyeL" else "EyeR", V(x, 0.15, -0.58), { Bone = "Head" })
			emitter(eye, "Glint", {
				Texture = A.glow, Color = CS(Color3.fromRGB(255, 236, 150), FLAME),
				Size = NS({ KP(0, 0.22), KP(1, 0.14) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
				Lifetime = R(0.18), LightEmission = 0.7, LockedToPart = true, Rate = 10, ZOffset = 0.6,
			})
		end
	end
	-- the golden circlet round the head
	-- on the brow, below most hair (higher, it vanished inside hair accessories)
	local circlet = B().mesh(A.torus, aura, "Circlet", V(1.75, 0.2, 1.75), O, N_GOLD)
	for k, v in { Bone = "Head", Offset = CFrame.new(0, 0.3, 0.02) * CFrame.Angles(math.rad(-8), 0, 0), Show = 0.05, Pulse = if tier >= 2 then 0.2 else 0 } do
		circlet:SetAttribute(k, v)
	end
	if tier >= 4 then
		local halo = B().mesh(A.swirlRing, aura, "Halo", V(3.6, 0.35, 3.6), O, Color3.fromRGB(255, 214, 110))
		for k, v in { Bone = "Torso", Offset = CFrame.new(0, 1.1, 1.0) * CFrame.Angles(math.rad(90), 0, 0), Show = 0.35, Spin = 40 } do
			halo:SetAttribute(k, v)
		end
		local glow = B().attach(aura, "Glow", V(0, 0.5, 0), { Bone = "Torso" })
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = GOLD
		light.Range = 10
		light.Brightness = 0.8 -- the runtime flashes it x3 at the strike, then holds it
		light.Shadows = false
		light.Parent = glow
	end
	-- the staff's gold arcs while the buff holds
	local staff = B().part(root, "Staff", BODY_AT)
	local arc = Instance.new("Trail")
	arc.Name = "BuffArc"
	arc.Color = CS({ CK(0, CORE), CK(0.5, GOLD), CK(1, FLAME) })
	arc.Transparency = NS({ KP(0, ({ 0.45, 0.35, 0.3, 0.2 })[tier]), KP(1, 1) })
	arc.WidthScale = NS({ KP(0, 1), KP(1, 0.3) })
	arc.Lifetime = ({ 0.08, 0.1, 0.12, 0.14 })[tier]
	arc.LightEmission, arc.LightInfluence = 0.5, 0
	arc.MinLength = 0.05
	arc.Enabled = false
	arc:SetAttribute("Inward", 1.3)
	arc.Parent = staff
	-- the puff when the buff runs out
	local fade = B().part(root, "Fade", BODY_AT)
	emitter(fade, "Motes", {
		Texture = A.mote, Color = CS(CORE, GOLD), SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NS({ KP(0, 0.25), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.5, 0.8), Speed = R(4, 7), Drag = 3, Acceleration = V(0, 2, 0), LightEmission = 0.6,
	}, { EmitCount = ({ 8, 10, 12, 16 })[tier] })
	emitter(fade, "Ring", {
		Texture = A.thinRing, Color = CS(GOLD),
		Size = NS({ KP(0, 0.8), KP(1, 3.4) }), Transparency = NS({ KP(0, 0.25), KP(1, 1) }),
		Lifetime = R(0.4), LightEmission = 0.5, ZOffset = 1,
	}, { EmitCount = 1 })
	return aura
end

local spec = {
	id = "GreatSageAwakening",
	root = { attrs = { AuthoredActive = ACTIVE, AuthoredRadius = RADIUS, AuthoredSeconds = 8 } },
	blocks = blocks,
	beats = {
		{ block = "handGather", params = pal({ windup = WINDUP, at = HAND_AT, wisps = false }) },
		{ block = "twirl" },
		{ block = "slam" },
		{ block = "groundShockwave", params = pal({ radius = RADIUS, lifetime = 0.3 }) },
		{ block = "awaken" },
		{ block = "impactStack", params = { burst = pal(), wave = pal() } },
		{ block = "aura" },
	},
}

function spec.build(parent)
	local B0 = _G.vfxBlocks
	local built = {}
	for tier = 1, 4 do
		local name = spec.id .. "_T" .. tier
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local root = Instance.new("Model")
		root.Name = name
		for k, v in spec.root.attrs do
			root:SetAttribute(k, v)
		end
		for _, beat in spec.beats do
			if tier >= (beat.from or 1) and tier <= (beat.to or 4) then
				local fn = blocks[beat.block] or B0.BLOCKS[beat.block]
				assert(fn, "unknown block " .. tostring(beat.block))
				fn(root, tier, beat.params or {})
			end
		end
		root.WorldPivot = O
		root.Parent = parent
		table.insert(built, root)
	end
	return built
end

spec.previewDef = {
	id = "GreatSageAwakening", name = "Great Sage Awakening", kind = "buff", weapon = "Staff",
	radius = 8, seconds = 8, damage = 12, cooldown = 20, color = GOLD, hand = "Right",
	animationId = "rbxassetid://117310636316384",
	hits = { { time = 1.15, damage = 12 } },
}

return spec
