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
-- THE SHOT (heavy pass 2026-10-23: the sigil behind the head, the flame
-- eruption, sound on every beat; animation, markers and defs untouched)
--
-- Intent: the Great Sage wakes. The twirl gathers qi into the spinning staff,
-- the staff end bites the ground (the one peak), and the Sage's golden flame
-- erupts up the body as a seal of script unfolds behind his head. The seal is
-- the buff indicator: it stays up, slowly turning, for the buff's seconds.
--
-- BEAT SHEET (clip ms, castSpeed 1; marker or clock that starts it)
--   0-1150     windup (cast start -> Hit): charge beam and motes along the
--              staff, qi into the right hand
--   167-1150   Twirl "start": gold ribbons on both staff ends, the ground seal
--              turning, streaks rising into the spin; sound Spin from 167,
--              Whirl rising from ~600, both cut at Hit
--   1150       Hit, THE PEAK (1-3 frames): the bite (white core, ink splat,
--              star burst, sparks) where the staff end strikes; the hero flame
--              erupts from the feet, full height by +40 ms, decaying from
--              +120 ms, gone by +450; sounds Bite + Slam + Tail
--   1150-1250  active (Hit -> Hit Stop): heave and dust at the bite, the
--              ragged ring rolls out to def.radius, an impact on every enemy as
--              the front reaches it
--   1210       +60 ms: the sigil unfolds behind the head (0.3 -> 1.1 -> 1 in
--              ~200 ms, flaring as it lands); sound Awaken
--   1250-1900  follow-through: flame column breaks up, dust settles, III+
--              crack scar and rock ring
--   buff 8 s   circlet, flame wisps, staff arcs, II+ sigil (faint), III+ full
--              sigil and eyes, IV double ring that pulses on every staff swing
--              and one soft light; sound Hum (II+, low loop), IV Pulse per swing
--   end        sigil collapses over ~0.5 s, mote puff; sound End
--
-- LAYER SHEET (role: cause -> asset and why; per-beat counts in the doc)
-- Flame        HERO: the Sage's golden flame igniting in the body -> tall flame burst flipbook 81332883799807 (2x2) over an ink copy of itself
-- Sigil        secondary: the awakened seal fixed to the back of the head (SurfaceGui disc in the head's frame) -> script array 14191668646 (A), rune-seal ring 139744345977881 (B), meander seal 87153714607286 (C); on an ink copy; IV outer script ring 16397769425 counter-turning
-- GroundWave   secondary: the bite's shock rolling out to the radius -> broken flat ring mesh 121387125059545
-- Heave        secondary: earth thrown up by the staff end -> low spiked splash mesh 89195313060285, umber
-- SlamDust     tertiary: dust blown out of the bite -> dust puff flipbook 11509655546
-- Wisps        tertiary: flame licking off the body while the buff holds -> small flame flipbook 127240501320910
-- Flare        support: the contact instant -> core dot 9841273544, core star flipbook 13580358178
-- Scar         environment: the ground cracked by the bite (III+) -> cracks 93520831389146
--
-- Cut in this pass: the Neon pillar cylinder, the T4 spike "Crown" mesh (no
-- crowns), both torus waves, the stock ray burst, the stock glow on the body,
-- the shared impact torus rings at the bite.
--
-- DIRECTIONS (spec.variant, the sigil only; everything else is shared):
--   A "gold array": one dense script array (rings of script, a six-point star,
--     a character at the centre), flat gold on an ink copy, turning slowly.
--   B "two-plane seal": a ring of eight rune seals inside a band of script,
--     the IV outer script ring counter-turning against it.
--   C "burning ink seal": a meander-pattern seal brushed in ink, gold held low,
--     flaring bright on every staff swing from II.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local A = {
	glow = id(867619398),
	star12 = id(243728206),
	spindle = id(7814053668),
	mote = id(9841260273),
	rune = id(83667248904000),
	thinRing = id(9841273159),
	cloud = id(11037785676),
	crack = id(93520831389146),
	swirl = id(129778117978668),
	-- the heavy pass
	flameBurst = id(81332883799807), -- 2x2 flipbook: tall flame bursts (white, tint it)
	flameWisp = id(127240501320910), -- 4x4 flipbook: a small white flame flickering up
	dustFlip = id(11509655546), -- 4x4 flipbook: a tan dust puff (fills ~half its cell)
	ringMesh = id(121387125059545), -- broken flat ring mesh (2.44 x 0.48 x 2.29)
	heaveMesh = id(89195313060285), -- low spiked splash mesh (1.11 x 0.32 x 1.10)
	torus = id(471124075), -- the circlet only
	-- the sigil, per direction (spec.variant)
	sigilA = id(14191668646), -- dense script array: script rings, six-point star, a character at the centre
	sigilB = id(139744345977881), -- eight rune seals in a ring inside a band of script
	sigilC = id(87153714607286), -- meander-pattern seal with an ornate rim
	sigilOuter = id(16397769425), -- a thin band of script (the IV outer ring)
}

local GOLD = Color3.fromRGB(255, 204, 84)
local CORE = Color3.fromRGB(255, 244, 205)
local FLAME = Color3.fromRGB(255, 132, 44) -- the red-orange edge of the Sage's flame
local N_GOLD = Color3.fromRGB(236, 166, 36) -- Neon blooms toward white, so deeper
local CLOUD = Color3.fromRGB(255, 246, 228)
local INK = Color3.fromRGB(46, 26, 12) -- burnt-umber ink under the gold
local EARTH = Color3.fromRGB(92, 74, 54)
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

local spec -- set at the bottom; the sigil reads spec.variant
local function variant()
	return spec and spec.variant or "A"
end

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

-- The awakening at the peak (HERO): the Sage's golden flame erupts from the
-- feet up the body, a flame-burst flipbook over an ink copy of itself, with a
-- white star on the chest the frame it ignites. II+ streaks shoot up out of
-- it. The ground wave (the damage) rolls out from the feet: a ragged ring mesh
-- the runtime sizes to def.radius ("GroundWave").
function blocks.awaken(root, tier, p)
	local ground = root:FindFirstChild("Ground")
	local k = RADIUS / 8
	-- the shared ground dust, halved and short: settled by Hit + 0.55 s
	-- (longer, a dozen round puffs sat across the arena into the buff)
	local dust = ground:FindFirstChild("Dust")
	if dust then
		dust:SetAttribute("EmitCount", math.ceil((dust:GetAttribute("EmitCount") or 10) / 2))
		dust.Lifetime = R(0.3, 0.45)
	end
	wave(ground, "GroundWave", {
		mesh = A.ringMesh, color = Color3.fromRGB(255, 226, 150),
		fromSize = V(2, 0.5, 2), toSize = V(RADIUS * 2, 0.9 + tier * 0.15, RADIUS * 2),
		fromOffset = V(0, 0.25, 0), toOffset = V(0, 0.3, 0),
		fromTransparency = 0.2, toTransparency = 1, duration = 0.42, style = "Quart",
	})
	-- the flame column: one tall burst engulfing the body (FacingCameraWorldUp
	-- keeps it standing at any camera height), the ink copy a touch bigger behind
	local body = B().part(root, "Body", BODY_AT)
	local tall = ({ 6.5, 7.5, 8.5, 10 })[tier]
	-- the burst rises from the feet: its centre held up so the quad never
	-- reaches under the ground (Body sits ~3 studs up, on the root)
	local rise = B().attach(body, "Rise", V(0, tall * 0.4 - 2.6, 0))
	local function flame(name, color, light, transparency, scale, z, delay)
		return emitter(rise, name, {
			Texture = A.flameBurst, Color = color, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			EmissionDirection = Enum.NormalId.Top, Speed = R(2, 3), Acceleration = V(0, 6, 0),
			Size = NS({ KP(0, tall * 0.7 * scale), KP(0.08, tall * scale), KP(1, tall * 1.05 * scale) }),
			Squash = NS(0.45),
			Transparency = transparency, Lifetime = R(0.45), LightEmission = light, LightInfluence = if light > 0 then 0 else 1,
			ZOffset = z,
		}, { EmitCount = 1, EmitDelay = delay })
	end
	flame("FlameInk", CS(INK), 0, NS({ KP(0, 0.45), KP(0.3, 0.55), KP(1, 1) }), 1.08, -0.6, 0)
	flame("Flame", CS({ CK(0, Color3.fromRGB(255, 230, 160)), CK(0.3, GOLD), CK(1, FLAME) }), 0.5, NS({ KP(0, 0), KP(0.25, 0.15), KP(0.6, 0.55), KP(1, 1) }), 1, 0, 0)
	emitter(body, "Flash", {
		Texture = A.star12, Color = CS(CORE),
		Size = NS({ KP(0, 0.5), KP(0.25, 3 + tier * 0.4), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 0.5) }),
		Lifetime = R(0.12), LightEmission = 0.8, Brightness = 2, Rotation = R(0, 360), ZOffset = 1.5,
	}, { EmitCount = 1 })
	if tier >= 2 then
		emitter(body, "Streaks", {
			Texture = A.spindle, Color = CS(CORE, GOLD), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(8, 8),
			Size = NS({ KP(0, 0.3), KP(1, 0.1) }), Squash = NS(2.5), Transparency = NS({ KP(0, 0), KP(1, 1) }),
			Lifetime = R(0.3, 0.45), Speed = R(26, 38), Drag = 3, LightEmission = 0.6,
		}, { EmitCount = ({ 0, 6, 8, 10 })[tier], EmitDelay = 0.04 })
	end
	if tier >= 3 then
		B().craterRing(root, tier, { parent = "Ground", radius = RADIUS * k, attrs = { Duration = 0.3 } })
	end
	if tier >= 4 then
		B().screenShake(root, tier, { parent = "Ground", name = "Quake", preset = "Explosion", falloff = "20~80" })
	end
	return body
end

-- The staff end biting the ground ahead (the shared flare sits on the same
-- part): earth heaved up round the bite, dust blown out of it, chips falling,
-- III+ a crack scar left behind.
function blocks.slam(root, tier, p)
	local slam = B().part(root, "Slam", SLAM_AT)
	local h = ({ 2.6, 3, 3.6, 4.2 })[tier]
	wave(slam, "Heave", {
		mesh = A.heaveMesh, color = EARTH, material = Enum.Material.SmoothPlastic,
		fromSize = V(0.6, 0.2, 0.6), toSize = V(h, h * 0.42, h),
		fromOffset = V(0, 0, 0), toOffset = V(0, 0.1, 0),
		fromTransparency = 0.05, toTransparency = 1, duration = 0.45, style = "Quart",
	}, "Quint")
	emitter(slam, "Dust", {
		Texture = A.dustFlip, Color = CS(Color3.fromRGB(214, 196, 164)), LightInfluence = 0.6,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70),
		Size = NS({ KP(0, 1.4), KP(1, 3.2 + tier * 0.3) }), Transparency = NS({ KP(0, 0.25), KP(0.6, 0.45), KP(1, 1) }),
		Lifetime = R(0.6, 0.85), Speed = R(6, 10), Drag = 5, Rotation = R(0, 360), ZOffset = 0.4,
	}, { EmitCount = ({ 3, 4, 5, 6 })[tier] })
	emitter(slam, "Chips", {
		Texture = id(130042646554310), Color = CS(Color3.fromRGB(120, 104, 84)), LightInfluence = 0.8,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2, FlipbookMode = Enum.ParticleFlipbookMode.Random,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(45, 45),
		Size = NS({ KP(0, 0.32), KP(1, 0.22) }), Transparency = NS({ KP(0, 0), KP(0.8, 0), KP(1, 1) }),
		Lifetime = R(0.5, 0.8), Speed = R(11, 17), Acceleration = V(0, -60, 0), Rotation = R(0, 360), RotSpeed = R(-360, 360), ZOffset = 0.5,
	}, { EmitCount = ({ 3, 4, 6, 8 })[tier] })
	if tier >= 3 then
		emitter(slam, "Cracks", B().flat({
			Texture = A.crack, Color = CS(Color3.fromRGB(70, 54, 36)), LightInfluence = 0.3,
			Size = NS(2.4 + (tier - 3) * 0.8), Transparency = NS({ KP(0, 1), KP(0.04, 0.1), KP(0.6, 0.25), KP(1, 1) }),
			Lifetime = R(1.5), Rotation = R(0, 360), ZOffset = -0.5,
		}), { EmitCount = 1 })
	end
	B().screenShake(root, tier, { parent = "Slam", magnitude = ({ 1, 1.4, 1.9, 2.4 })[tier] })
	return slam
end

-- The sigil behind the head: a flat disc fixed in the head's own frame (its
-- plane parallel to the back of the skull, its normal along the head's look
-- axis, a little behind it), so it turns with the character and reads edge-on
-- from the side, like a seal welded to the back of the head (user, 2026-10-23).
-- A held Part (Bone = Head, Offset, Spin deg/s about its own normal) carrying
-- SurfaceGuis on both faces: the glyph in gold over an ink copy of itself
-- (ImageLabels "Ink" and "Gold", each with its Show transparency). The runtime
-- unfolds it EmitDelay after the peak (size 0.3 -> 1.1 -> 1 in ~0.2 s), holds
-- it for the buff, collapses it at the end, and flares PulseOnSwing discs on
-- every staff swing. A turning SurfaceGui stays crisp and in step, where two
-- turning particles drift apart (docs/vfx/toolkit/library.md).
-- II faint, III full, IV a counter-turning outer ring of script and pulses.
local function disc(aura, name, tex, d, show, inkShow, spin, back, delay, pulse)
	local part = B().part(aura, name, BODY_AT, V(d, 0.05, d))
	for k, v in {
		Bone = "Head", Offset = CFrame.new(0, 0.45, back) * CFrame.Angles(math.rad(90), 0, 0), -- the centre character clears the circlet
		Show = 1, Spin = spin, Gui = true, EmitDelay = delay, PulseOnSwing = pulse,
	} do
		part:SetAttribute(k, v)
	end
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = if face == Enum.NormalId.Top then "Back" else "Front"
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 1.6
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 100
		gui.ClipsDescendants = false
		for _, layer in { { "Ink", INK, inkShow, 1, 1.05 }, { "Gold", GOLD, show, 2, 1 } } do
			local img = Instance.new("ImageLabel")
			img.Name = layer[1]
			img.BackgroundTransparency = 1
			img.Image = tex
			img.ImageColor3 = layer[2]
			img.ImageTransparency = 1 -- the runtime fades it to Show
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(layer[5], layer[5])
			img.ZIndex = layer[4]
			img:SetAttribute("Show", layer[3])
			img.Parent = gui
		end
		gui.Parent = part
	end
	return part
end

local function sigil(aura, tier)
	if tier < 2 then
		return
	end
	local v = variant()
	local main = ({ A = A.sigilA, B = A.sigilB, C = A.sigilC })[v]
	local d = ({ 0, 1.7, 2, 2 })[tier] -- about 1.5-2 head widths
	local show = ({ 0, 0.5, 0.15, 0.1 })[tier]
	local inkShow = ({ 0, 0.55, 0.3, 0.25 })[tier]
	if v == "C" then
		-- the burning ink seal: ink carries it, the gold is held low until a swing
		show, inkShow = ({ 0, 0.7, 0.5, 0.45 })[tier], ({ 0, 0.35, 0.1, 0.05 })[tier]
	end
	local pulse = tier >= 4 or (v == "C" and tier >= 2)
	disc(aura, "Sigil", main, d, show, inkShow, 12, 0.85, 0.06, pulse) -- ~0.35 behind the skull, clear of the circlet
	if tier >= 4 then
		disc(aura, "SigilOuter", A.sigilOuter, d * 1.25, 0.45, 0.55, -8, 0.9, 0.12, pulse)
	end
end

-- The buff aura: emitters the runtime moves onto the body (Bone = the body
-- part), held MeshParts it drives there (Offset from the bone, Show
-- transparency, Spin deg/s, Pulse), and the staff trail for the buff.
function blocks.aura(root, tier, p)
	local aura = B().part(root, "Aura", BODY_AT, V(2, 2, 1))
	aura:SetAttribute("EmitDuration", 8) -- the plugin's T button shows the hold
	-- the Sage's flame licking off the body: a flickering flame flipbook
	local flames = emitter(aura, "Flames", {
		Texture = A.flameWisp, Color = CS({ CK(0, CORE), CK(0.35, GOLD), CK(1, FLAME) }),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4, FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
		Size = NS({ KP(0, 0.7), KP(0.4, 1.1 + tier * 0.12), KP(1, 0.5) }),
		Transparency = NS({ KP(0, 1), KP(0.12, 0.15), KP(0.7, 0.35), KP(1, 1) }),
		Lifetime = R(0.45, 0.7), Speed = R(1.5, 3), Acceleration = V(0, 4, 0),
		LightEmission = 0.5, LightInfluence = 0.1, ZOffset = -0.3,
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
	sigil(aura, tier)
	-- the golden circlet round the head
	-- on the brow, below most hair (higher, it vanished inside hair accessories)
	-- (a solid gold band hugging the brow, not Neon: a glowing ring higher up
	-- read as a halo floating over the head and cut across the sigil)
	local circlet = B().mesh(A.torus, aura, "Circlet", V(1.3, 0.16, 1.3), O, Color3.fromRGB(153, 110, 35), Enum.Material.SmoothPlastic)
	for k, v in { Bone = "Head", Offset = CFrame.new(0, 0.15, 0.02) * CFrame.Angles(math.rad(-8), 0, 0), Show = 0 } do
		circlet:SetAttribute(k, v)
	end
	if tier >= 4 then
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
	return aura
end

spec = {
	id = "GreatSageAwakening",
	variant = "A", -- the pick (critic, 2026-10-23): the only one that reads as a glyph in one look
	root = { attrs = { AuthoredActive = ACTIVE, AuthoredRadius = RADIUS, AuthoredSeconds = 8 } },
	blocks = blocks,
	beats = {
		{ block = "handGather", params = pal({ windup = WINDUP, at = HAND_AT, wisps = false }) },
		-- gold motes and a dark-under-gold beam along the whole staff (butt -> head) while it spins
		{ block = "bladeCharge", params = { color = GOLD, core = CORE, ink = INK, width = 0.55, full = true } },
		{ block = "twirl" },
		{ block = "slam" },
		{ block = "bladeFlare", params = { part = "Slam", color = GOLD, core = CORE, ink = INK } },
		{ block = "groundShockwave", params = pal({ radius = RADIUS, lifetime = 0.3, torus = false, rays = false, echo = false, dustColor = Color3.fromRGB(214, 196, 164) }) },
		{ block = "awaken" },
		{ block = "impactStack", params = { burst = pal(), wave = false } },
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
