--!nocheck
-- Twin Phoenix Cannon's templates (TwinPhoenixCannon_T1..T4). Build with
-- spec.build(parent) (this spec's own blocks resolve before the shared ones).
-- Runtime: src/client/TechniqueFX/TwinPhoenixCannon.luau.
--
-- Gameplay: Fist technique, kind "line" 18 x 6, two blasts (14 dmg each),
-- animation 134365896305843 (1.417 s): hits 0.30-0.38 (right fist) and
-- 0.83-0.92 (left fist). Both strikes are overhand forward-down punches:
-- the fist comes over the shoulder, sweeps down and is fully extended ~0.04 s
-- after the hit starts (right fist at Hit +0.04: root-space (1.8, -1.1,
-- -3.8); left at +0.03: (1.0, 0.5, -3.7)), the torso pitching forward, then
-- the body twists to load the other side. The template pivot is the ground
-- under the caster facing -Z; authored at length 18, width 6.
--
-- THE SHOT, tier by tier (R = the right fist's crimson phoenix, L = the left
-- fist's golden phoenix, a size up: the finisher)
--
-- I (levels 1-3), "two fire birds"
--   Windup (0 -> first Hit, caster only, part "Windup"): crimson motes stream
--     into the right fist as it rises over the shoulder, a charge glow swells.
--   Release R (Hit +0.03): a star flash and glow on the extended fist, one 3D
--     swirl air ring thrown forward.
--   Travel R (~0.26 s, part "BlastR"): the phoenix: a Neon fire head (a
--     solid ball) with swept-back wings of Beams (span ~5.5, a flat crimson
--     wing, a bright core, a camera-facing glow layer) and a burning tail
--     trail, shedding embers. It forms past the fist at fist height, settles
--     onto the line's centre at body height and flies the 18 studs (fast
--     launch, eases out). It stops at a wall or rising ground.
--   Impact (each enemy, when the head's front reaches it): fire impact
--     (star flash, puff, spiky ring, sparks, upright 3D torus, ground shock),
--     a flame flare up the body, CombatEffects.flash.
--   Terminal (where it ends): an explosion: a fatter torus, ground shock,
--     flash, a ring of flames and embers.
--   Aftermath: a hot Neon burn line on the ground behind the bird cooling
--     into a char mark (~1 s).
--   Between: gold motes gather into the left fist as it rises (part
--     "Gather", visible to everyone).
--   Release / travel / impact / terminal L: the same in gold, wider wings
--     and a bigger terminal.
-- II (4-6), "feathers of flame"
--   + flame feathers shed from the wings, release sparks, impact swirl and
--     dust, embers rising off the burn line, a swirl at the terminal.
-- III (7-9), "the cannon seal"
--   + a rune seal flashes in front of each fist as it fires (the cannon
--     mouth), 2 air rings, impact bubbles and rock kicks (Craters, first 2
--     targets), a Craters rock ring at each terminal, a light shake.
-- IV (10), "twin phoenix"
--   + 3 air rings, a gold-white head on both birds, the move's one PointLight
--     riding the golden bird, and its terminal becomes a fire dome (Neon
--     ball shell) with a spike crown, a rock ring and an Explosion quake.
--
-- Parts (runtime contract):
--   Windup        handGather on the right fist (CombatEffects.windup).
--   Gather        handGather (gold) on the left fist between the blasts.
--   FistR/FistL   release flash + air rings (+ III seal) at the live fist.
--   BlastR/BlastL the bird (moved by the runtime; children BaseParts are
--                 held: `Show` = their transparency while flying).
--   ImpactR/L     per-target hit (Body attachment).
--   TerminalR/L   the explosion where the bird ends.
--   BurnR/L, CharR/L  ground strips stretched along the path.
--   PathR/L       II+ aftermath embers over the flown path (a Box).
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local A = {
	flame = id(265788038), -- stylised white flame silhouette (tinted)
	glow = id(867619398),
	spindle = id(7814053668),
	mote = id(9841260273),
	rune = id(83667248904000), -- rune circle (cannon seal)
	torus = id(471124075),
	crownLow = id(489415286),
	crack = id(97725700315217),
}

-- Palettes: particles take the light tones; Neon meshes bloom toward white,
-- so they take deeper ones.
local PAL = {
	R = {
		color = Color3.fromRGB(255, 96, 52), core = Color3.fromRGB(255, 214, 160),
		edge = Color3.fromRGB(226, 52, 28), glowColor = Color3.fromRGB(255, 120, 70),
		neon = Color3.fromRGB(236, 70, 34), ember = Color3.fromRGB(255, 150, 80),
		ringColor = Color3.fromRGB(255, 170, 120), swirlColor = Color3.fromRGB(255, 120, 70), groundColor = Color3.fromRGB(255, 150, 100),
	},
	L = {
		color = Color3.fromRGB(255, 196, 80), core = Color3.fromRGB(255, 242, 200),
		edge = Color3.fromRGB(240, 150, 30), glowColor = Color3.fromRGB(255, 205, 100),
		neon = Color3.fromRGB(245, 160, 40), ember = Color3.fromRGB(255, 200, 110),
		ringColor = Color3.fromRGB(255, 225, 150), swirlColor = Color3.fromRGB(255, 196, 90), groundColor = Color3.fromRGB(255, 215, 130),
	},
}
local CHAR = Color3.fromRGB(46, 30, 24)
local MASTER_CORE = Color3.fromRGB(255, 250, 230)

local LENGTH, WIDTH = 18, 6
local FIST_AT = { R = O * CFrame.new(1.8, 1.9, -3.8), L = O * CFrame.new(1.0, 3.5, -3.7) } -- repositioned on the live fists
local GATHER_AT = O * CFrame.new(0.3, 5, 0)

local function B()
	return _G.vfxBlocks
end

-- params for the shared blocks from a palette, plus extras
local function pal(key, extra)
	local t = table.clone(PAL[key])
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

-- The wings: a crescent of Beams (two tapered halves per layer, the tips
-- swept back by `depth`), as on Sword Qi Wave's blade.
local function wing(part, layer, span, depth, y, width, color, transparency, faceCamera, light)
	local function att(name, pos, axis)
		local a = Instance.new("Attachment")
		a.Name = layer .. name
		a.CFrame = CFrame.fromMatrix(pos, axis, Vector3.yAxis)
		a.Parent = part
		return a
	end
	-- the tips sweep back and lift (a gull's V from behind), so the wings
	-- read as wings rather than a flat crescent
	local lift = span * 0.2
	local L = att("L", V(-span / 2, y + lift, depth), V(0, 0, -1))
	local C = att("C", V(0, y, -0.2), V(1, 0, 0))
	local Rt = att("R", V(span / 2, y + lift, depth), V(0, 0, 1))
	for i, pair in { { L, C, 0.05, width }, { C, Rt, width, 0.05 } } do
		local b = Instance.new("Beam")
		b.Name = layer .. (if i == 1 then "Left" else "Right")
		b.Attachment0, b.Attachment1 = pair[1], pair[2]
		b.Width0, b.Width1 = pair[3], pair[4]
		b.CurveSize0 = if i == 1 then depth * 0.6 else span * 0.22
		b.CurveSize1 = if i == 1 then span * 0.22 else depth * 0.6
		b.FaceCamera = faceCamera
		b.Color = CS(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Transparency = NS(transparency)
		b.Segments = 12
		b.Enabled = false
		b.Parent = part
	end
	return L, Rt
end

local function trail(parent, name, a0, a1, color, life, t0, faceCamera, light)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = color
	t.Transparency = NS({ KP(0, t0), KP(0.6, (1 + t0) / 2), KP(1, 1) })
	t.WidthScale = NS({ KP(0, 1), KP(1, 0.3) })
	t.Lifetime = life
	t.FaceCamera = faceCamera
	t.LightEmission, t.LightInfluence = light, 0
	t.MinLength = 0.05
	t.Enabled = false
	t.Parent = parent
	return t
end

local blocks = {}

-- The bird for side `key`.
function blocks.blast(root, tier, p)
	local key = p.key
	local c = PAL[key]
	local big = key == "L"
	local span = ({ 5.5, 6, 6.5, 7.5 })[tier] * (if big then 1.1 else 1)
	local depth = span * 0.42
	local blast = B().part(root, "Blast" .. key, O * CFrame.new(0, 2.4, -2), V(span, 0.3, depth))
	for k, v in {
		Span = span, Height = 2.4, Pitch = 10,
		TravelTime = if big then 0.28 else 0.26,
		TravelCurve = NS({ KP(0, 0), KP(0.2, 0.36), KP(0.5, 0.7), KP(0.75, 0.9), KP(1, 1) }),
	} do
		blast:SetAttribute(k, v)
	end
	local core = if tier >= 4 then MASTER_CORE else c.core
	local eL, eR = wing(blast, "Wing", span, depth, 0, span * 0.3, c.edge, 0.05, false, 0.2)
	wing(blast, "Core", span * 0.9, depth * 0.9, 0.05, span * 0.13, core, 0, false, 0.45)
	wing(blast, "Glow", span * 1.08, depth * 1.06, 0.02, span * 0.42, c.glowColor, 0.45, true, 0.35)
	-- the Neon head, held at the front of the wings
	local d = ({ 1.0, 1.15, 1.3, 1.5 })[tier] * (if big then 1.12 else 1)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Material = Enum.Material.Neon
	head.Color = if tier >= 4 then Color3.fromRGB(255, 226, 170) else c.neon
	head.Size = V(d, d, d * 1.25)
	head.Anchored, head.CanCollide, head.CanQuery, head.CanTouch, head.CastShadow = true, false, false, false, false
	head.Transparency = 1
	head.CFrame = blast.CFrame * CFrame.new(0, 0, -0.35)
	head:SetAttribute("Show", 0.05)
	head.Parent = blast
	-- the burning tail and the flat wake between the wing tips
	local t0 = B().attach(blast, "TailA", V(0, 0.3, -0.2))
	local t1 = B().attach(blast, "TailB", V(0, -0.3, -0.2))
	trail(blast, "Tail", t0, t1, CS({ CK(0, core), CK(0.35, c.color), CK(1, c.edge) }), ({ 0.16, 0.2, 0.24, 0.28 })[tier], 0.05, true, 0.5)
	trail(blast, "Wake", eL, eR, CS(c.glowColor), ({ 0.12, 0.15, 0.18, 0.22 })[tier], 0.6, false, 0.35)
	-- embers shed while it flies (the runtime toggles Enabled)
	local shed = B().emitter(blast, "Embers", {
		Texture = A.mote, Color = CS(core, c.color),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70),
		Size = NS({ KP(0, 0.24), KP(1, 0) }), Transparency = NS({ KP(0, 0.05), KP(1, 1) }),
		Lifetime = R(0.25, 0.45), Speed = R(2, 6), Drag = 3, LightEmission = 0.5, Rotation = R(0, 360),
		Acceleration = V(0, 4, 0), Rate = ({ 22, 28, 36, 45 })[tier],
	})
	shed:SetAttribute("Shed", true)
	if tier >= 2 then
		local feathers = B().emitter(blast, "Feathers", {
			Texture = A.flame, Color = CS({ CK(0, c.core), CK(0.4, c.color), CK(1, c.edge) }),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(25, 25),
			Size = NS({ KP(0, 0.5), KP(0.3, 0.75), KP(1, 0.1) }), Transparency = NS({ KP(0, 0.3), KP(0.3, 0.1), KP(1, 1) }),
			Lifetime = R(0.18, 0.3), Speed = R(3, 6), Drag = 4, LightEmission = 0.3, LightInfluence = 0.1,
			Rotation = R(-30, 30), Rate = ({ 0, 14, 18, 24 })[tier], ZOffset = -0.2,
		})
		feathers:SetAttribute("Shed", true)
	end
	if tier >= 4 and big then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = c.color
		light.Range = 16
		light.Brightness = 0 -- the runtime lights it while the bird flies
		light.Shadows = false
		light.Parent = blast
	end
	return blast
end

-- The release at the fist: flash, glow, sparks (II+), air rings, the III+
-- cannon seal and a small shake.
function blocks.fist(root, tier, p)
	local key = p.key
	local part = "Fist" .. key
	local q = pal(key, { part = part, at = FIST_AT[key], light = false })
	B().releaseFlash(root, tier, q)
	B().airShockwave(root, tier, pal(key, { part = part, at = FIST_AT[key], color = PAL[key].ringColor }))
	if tier >= 3 then
		B().emitterBlock(root, tier, {
			part = part, name = "Seal", flat = true, dir = Enum.NormalId.Front, attrs = { EmitCount = 1 },
			props = {
				Texture = A.rune, Color = CS(PAL[key].core, PAL[key].color),
				Size = NS({ KP(0, 0.6), KP(0.25, 2 + (tier - 3) * 0.6), KP(1, 2.4 + (tier - 3) * 0.6) }),
				Transparency = NS({ KP(0, 0.1), KP(0.6, 0.3), KP(1, 1) }),
				Lifetime = R(0.36), LightEmission = 0.5, RotSpeed = R(240), Rotation = R(0, 360), ZOffset = 1,
			},
		})
		B().screenShake(root, tier, { parent = part, magnitude = (if key == "L" then 1.4 else 1) * (tier - 1) * 0.6 })
	end
	return root:FindFirstChild(part)
end

-- The fire flare added to a burst (impact or terminal): flame tongues up
-- from the body / ground point.
local function flare(parent, key, count, size, spread)
	local c = PAL[key]
	return B().emitter(parent, "Flare", {
		Texture = A.flame, Color = CS({ CK(0, c.core), CK(0.35, c.color), CK(1, c.edge) }),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(spread, spread),
		Size = NS({ KP(0, size * 0.4), KP(0.25, size), KP(1, size * 0.15) }),
		Transparency = NS({ KP(0, 0.2), KP(0.3, 0.05), KP(1, 1) }),
		Lifetime = R(0.3, 0.45), Speed = R(5, 10), Drag = 4, Acceleration = V(0, 6, 0),
		LightEmission = 0.3, LightInfluence = 0.1, Rotation = R(-15, 15), ZOffset = 2,
	}, { EmitCount = count })
end

function blocks.impact(root, tier, p)
	local key = p.key
	local part = "Impact" .. key
	local big = key == "L"
	local k = if big then 1.1 else 1
	B().impactBurst(root, tier, pal(key, { part = part }))
	B().impactShockwave(root, tier, pal(key, {
		part = part, size = ({ 3.8, 4.6, 5.6, 6.8 })[tier] * k, groundSize = ({ 4, 4.8, 5.8, 7 })[tier] * k,
	}))
	local impact = root:FindFirstChild(part)
	flare(impact.Body, key, ({ 3, 4, 5, 6 })[tier], 1.3 + tier * 0.15, 30)
	if tier >= 3 then
		B().craterRing(root, tier, { parent = part, shape = "Cone" })
	end
	return impact
end

function blocks.terminal(root, tier, p)
	local key = p.key
	local c = PAL[key]
	local big = key == "L"
	local part = "Terminal" .. key
	local k = if big then 1.25 else 1
	local q = pal(key, { part = part, at = O * CFrame.new(0, 0.15, -LENGTH) })
	B().impactBurst(root, tier, q)
	q.size = ({ 4.6, 5.6, 6.8, 8.4 })[tier] * k
	q.groundSize = ({ 5.2, 6.4, 7.8, 9.6 })[tier] * k
	q.bubble = tier >= 3
	B().impactShockwave(root, tier, q)
	local term = root:FindFirstChild(part)
	-- a ring of flames thrown out along the ground and embers up
	B().emitter(term, "FlameRing", {
		Texture = A.flame, Color = CS({ CK(0, c.core), CK(0.35, c.color), CK(1, c.edge) }),
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(10, 180),
		Size = NS({ KP(0, 0.6), KP(0.25, 1.4 * k), KP(1, 0.2) }), Transparency = NS({ KP(0, 0.2), KP(0.3, 0.05), KP(1, 1) }),
		Lifetime = R(0.35, 0.5), Speed = R(14 * k, 20 * k), Drag = 6, Acceleration = V(0, 5, 0),
		LightEmission = 0.3, LightInfluence = 0.1, Rotation = R(-20, 20), ZOffset = 1,
	}, { EmitCount = ({ 8, 10, 12, 16 })[tier] })
	flare(term.Body, key, ({ 4, 5, 6, 8 })[tier], (1.6 + tier * 0.2) * k, 40)
	B().emitter(term, "Embers", {
		Texture = A.mote, Color = CS(c.core, c.color),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50),
		Size = NS({ KP(0, 0.25), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.6, 1), Speed = R(8, 14), Drag = 2.5, Acceleration = V(0, 3, 0), LightEmission = 0.5,
	}, { EmitCount = ({ 6, 8, 10, 14 })[tier] })
	if tier >= 2 then
		B().emitter(term, "Scorch", B().flat({
			Texture = A.crack, Color = CS(CHAR), LightInfluence = 0.3,
			Size = NS(1.6 * k + tier * 0.3), Transparency = NS({ KP(0, 1), KP(0.05, 0.25), KP(0.6, 0.35), KP(1, 1) }),
			Lifetime = R(1.3), Rotation = R(0, 360), ZOffset = -0.5,
		}), { EmitCount = 1 })
	end
	if tier >= 3 then
		B().craterRing(root, tier, { parent = part, name = "Crater", attrs = {
			Count = ({ 0, 0, 6, 10 })[tier], Radius = ({ 0, 0, 2.2, 3 })[tier] * k, Variance = 0.7, Duration = 0.12,
			Size = V(1, 0.75, 0.9), Lifetime = R(1.1, 1.4), RaycastDistance = 8,
		} })
	end
	if tier >= 4 and big then
		local dome = B().meshWave(term, "FireDome", {
			mesh = "Ball", material = Enum.Material.Neon, color = c.neon,
			fromSize = V(1.5, 1.2, 1.5), toSize = V(8, 5.5, 8), fromOffset = V(0, 0.6, 0), toOffset = V(0, 1.2, 0),
			fromTransparency = 0.25, toTransparency = 1, duration = 0.5, style = "Quart",
		})
		dome:SetAttribute("FadeStyle", "Quint")
		local crown = B().meshWave(term, "Crown", {
			mesh = A.crownLow, color = PAL.R.neon,
			fromSize = V(2.5, 1, 2.5), toSize = V(8.5, 4.5, 8.5), fromOffset = V(0, 0.3, 0), toOffset = V(0, 1.4, 0),
			fromTransparency = 0.15, toTransparency = 1, duration = 0.55, style = "Quart",
		})
		crown:SetAttribute("FadeStyle", "Quint")
		B().screenShake(root, tier, { parent = part, name = "Quake", preset = "Explosion", falloff = "20~80" })
	end
	return term
end

-- The burnt streak (the runtime stretches it along the flown path) and the
-- II+ embers that rise off it.
function blocks.streak(root, tier, p)
	local key = p.key
	local c = PAL[key]
	local k = if key == "L" then 1.15 else 1
	local function strip(name, material, color, width, attrs, thick)
		local s = B().part(root, name .. key, O * CFrame.new(0, 0.05, -LENGTH / 2), V(width, thick, 1))
		s.Material, s.Color = material, color
		for a, v in attrs do
			s:SetAttribute(a, v)
		end
		return s
	end
	strip("Burn", Enum.Material.Neon, c.neon, ({ 0.3, 0.36, 0.42, 0.5 })[tier] * k, {
		StartTransparency = 0.25, Fade = ({ 0.5, 0.6, 0.7, 0.85 })[tier], FadeColor = c.edge,
	}, 0.1)
	strip("Char", Enum.Material.SmoothPlastic, CHAR, ({ 0.8, 0.95, 1.1, 1.3 })[tier] * k, {
		StartTransparency = 0.35, Fade = ({ 0.9, 1.1, 1.3, 1.6 })[tier], FadeDelay = 0.25,
	}, 0.06)
	if tier >= 2 then
		local path = B().part(root, "Path" .. key, O * CFrame.new(0, 0.3, -LENGTH / 2), V(1.5, 0.2, LENGTH))
		B().emitter(path, "Embers", {
			Texture = A.mote, Color = CS(c.core, c.color),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
			Size = NS({ KP(0, 0.22), KP(0.5, 0.18), KP(1, 0) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.15), KP(1, 1) }),
			Lifetime = R(0.6, 1), Speed = R(1.5, 3.5), Drag = 1, LightEmission = 0.5, Rotation = R(0, 360),
		}, { EmitCount = ({ 0, 6, 9, 12 })[tier], EmitDelay = 0.1 })
	end
	return root:FindFirstChild("Burn" .. key)
end

local spec = {
	id = "TwinPhoenixCannon",
	root = { attrs = { AuthoredActive = 0.08, AuthoredLength = LENGTH, AuthoredWidth = WIDTH } },
	blocks = blocks,
	beats = {
		-- windup: crimson qi into the right fist (caster only)
		{ block = "handGather", params = pal("R", { windup = 0.30, at = FIST_AT.R }) },
		-- between the blasts: gold qi into the left fist (everyone)
		{ block = "handGather", params = pal("L", { part = "Gather", windup = 0.45, at = GATHER_AT, wisps = false }) },
		{ block = "fist", params = { key = "R" } },
		{ block = "fist", params = { key = "L" } },
		{ block = "blast", params = { key = "R" } },
		{ block = "blast", params = { key = "L" } },
		{ block = "streak", params = { key = "R" } },
		{ block = "streak", params = { key = "L" } },
		{ block = "impact", params = { key = "R" } },
		{ block = "impact", params = { key = "L" } },
		{ block = "terminal", params = { key = "R" } },
		{ block = "terminal", params = { key = "L" } },
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

-- A local def for previews until Techniques.luau has it (numbers from the
-- weapons design doc).
spec.previewDef = {
	id = "TwinPhoenixCannon", name = "Twin Phoenix Cannon", kind = "line", weapon = "Fist",
	length = 18, width = 6, damage = 14, cooldown = 9, color = PAL.R.color,
	animationId = "rbxassetid://116649566757684",
	hits = { { time = 0.30, damage = 14 }, { time = 0.83, damage = 14 } },
}

return spec
