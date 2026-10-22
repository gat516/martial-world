--!nocheck
-- Sword Qi Wave's templates (SwordQiWave_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Runtime: src/client/TechniqueFX/SwordQiWave.luau.
--
-- The move: Fists.3 (Hit 0.35, Hit Stop 0.467 of 0.70 s; matches
-- Config.FIST_STEPS[3]). The RIGHT arm is the blade: it comes from behind the
-- body, reaches the right side at Hit and sweeps flat across the front to the
-- left by +0.04 s (a horizontal hand-blade cut at chest height). The cast plays
-- it at 1.09x: windup 0.32 s, active 0.107 s, recovery 0.16 s.
--
-- The pitch, beat by beat (every tier):
--   Windup (cast start -> Hit, caster only, part "Windup"): ice-cyan qi motes
--     stream into the swinging hand and a charge glow builds on it (II+ Spline
--     wisps, III+ a closing seal).
--   Release (Hit, part "Hand" at the right hand): a star flash and glow where
--     the hand-blade cuts, sonic swirl rings (3D MeshWaves) thrown forward off
--     the hand, a light shake.
--   Travel (Hit -> ~0.36 s, part "Blade", runtime-driven): the crescent of
--     sword qi, a physical horizontal wing of Beams with real width (a bright
--     core, a cyan edge, a camera-facing glow layer so it reads at grazing
--     angles), leaving a flat wake trail and a white centre streak, shedding
--     motes. It forms in front of the caster at hand height, settles to body
--     height and flies the line (32 studs) on TravelCurve (fast launch, eases
--     out). Raycast along the path: it ends at max range, a wall or rising
--     ground.
--   Impact (each enemy, when the blade's front reaches its near side, part
--     "Impact"): impactStack in cyan (star flash, spiky ring, sparks, 3D
--     standing impact torus and ground shock) plus a horizontal crescent cut
--     flash through the body.
--   Terminal (where the blade ends, part "Terminal"): the blade bursts. A
--     bigger impactStack (standing torus, ground shock, flash, sparks) so the
--     projectile never just vanishes.
--   Aftermath (parts "Cut", "Scar", "Path"): a glowing Neon slit drawn on the
--     ground behind the blade as it flies, cooling into a dark ink scar that
--     lingers and fades; II+ qi motes rise off the cut.
--
-- What each tier adds:
--   I   one crescent (span 5), 1 air ring, impact ring + ground shock, a small
--       terminal burst, slit + scar ~1 s.
--   II  span 5.5, one echo blade trailing it, release sparks, impact swirl and
--       dust, motes rising from the cut, terminal swirl.
--   III span 6, two echo blades, 2 air rings, impact bubble and rock kicks
--       (Craters cone, first 3 targets), cracks along the cut, terminal
--       crater ring (Craters) and cracks, a longer scar.
--   IV  span 7 (mastery): three blades with a gold-white core, 3 air rings,
--       the one point light riding the blade, a "sword intent" crescent flash
--       at the release, ScreenEffects impact frames at release and an
--       Explosion quake on the first impact, a big terminal burst (bubble,
--       swirl, crater ring, shards), the longest scar.
--
-- Remade 2026-10-21 on the jian and the Hit window (the sword is held through
-- Fists.3, so the arm's swing is the blade's):
--   Windup (cast start -> Hit, 0.32 s): part "Charge" rides the model's Base ->
--     Tip (WeaponFX.charge): a dark beam under a cyan one, motes along the edge
--     and a glint at the point, instead of a hand gather.
--   Release (Hit, part "Hand"): the star flash, flare (cross glint, star-burst
--     flipbook over ink, sparks) and air rings burst on the blade, 0.8 of the
--     way to the tip, not on the hand; the real edge draws its own ribbon,
--     glow and motes ("Edge") through the cut.
--   Travel: the crescent has an ink crescent under it (dark under light) and
--     crosses the line in 0.12 s (was 0.36 s), the echo blades trailing, so
--     each impact lands inside Hit -> Hit Stop (0.107 s) plus a frame or two
--     instead of up to 0.3 s after the damage number; every cut also gets a
--     cyan crescent-moon flipbook.
-- Authored at length 32, width 5, active 0.107 s; the runtime rescales to the
-- def and fits Phase "active" emitters (none critical here: the blade's travel
-- is authored, like Palm Strike's ground torus, so it is seen).
local B = _G.vfxBlocks
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local CYAN = Color3.fromRGB(150, 230, 255) -- Techniques.SwordQiWave.color
local CORE = Color3.fromRGB(232, 251, 255)
local GOLD_CORE = Color3.fromRGB(255, 246, 214) -- mastery core
local INK = Color3.fromRGB(28, 44, 60)
local EDGE = Color3.fromRGB(95, 205, 255) -- the blade's body, deeper than the def colour
local PALETTE = {
	color = CYAN, core = CORE,
	ringColor = Color3.fromRGB(205, 245, 255), swirlColor = Color3.fromRGB(150, 225, 255), groundColor = Color3.fromRGB(170, 232, 255),
}
local function pal(extra)
	local t = table.clone(PALETTE)
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

local SPAN = { 5.5, 6, 6.5, 7.5 } -- the hitbox is width 5 plus 1.5 slack a side
local BLADE_AT = O * CFrame.new(0, 2.6, -1.5) -- repositioned along the line at runtime
local TERMINAL_AT = O * CFrame.new(0, 0.15, -32)
local A = {
	slash = id(7216852121), -- clean horizontal crescent (the cut through a target)
	intent = id(13366366767), -- layered crescent slashes (mastery sword intent)
	mote = id(9841260273), -- small glowing spindle mote
	crackSmall = id(97725700315217), -- radial ground crack
	crescentFlip = id(13972642464), -- 4x4 flipbook: a thin crescent moon sweeping and fading
}
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local ONESHOT = Enum.ParticleFlipbookMode.OneShot

-- The blade: a Part whose attachments and Beams draw a horizontal crescent
-- (two tapered half-beams per layer, tips trailing back), plus wake trails,
-- shed motes and (IV) the light. The runtime moves it; nothing here is emitted.
local function crescent(part, layer, span, depth, y, width, color, transparency, faceCamera, light)
	local function att(name, pos, axis)
		local a = Instance.new("Attachment")
		a.Name = layer .. name
		a.CFrame = CFrame.fromMatrix(pos, axis, Vector3.yAxis) -- secondary axis up: the ribbon lies flat
		a.Parent = part
		return a
	end
	local L = att("L", Vector3.new(-span / 2, y, depth), Vector3.new(0, 0, -1))
	local C = att("C", Vector3.new(0, y, 0), Vector3.new(1, 0, 0))
	local Rt = att("R", Vector3.new(span / 2, y, depth), Vector3.new(0, 0, 1))
	for i, pair in { { L, C, 0.04, width }, { C, Rt, width, 0.04 } } do
		local b = Instance.new("Beam")
		b.Name = layer .. (if i == 1 then "Left" else "Right")
		b.Attachment0, b.Attachment1 = pair[1], pair[2]
		b.Width0, b.Width1 = pair[3], pair[4]
		b.CurveSize0 = if i == 1 then depth * 0.9 else span * 0.28
		b.CurveSize1 = if i == 1 then span * 0.28 else depth * 0.9
		b.FaceCamera = faceCamera
		b.Color = CS(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Transparency = NS(transparency)
		b.Segments = 14
		b.Parent = part
	end
end

B.BLOCKS.sqwBlade = function(root, tier, p)
	local span = SPAN[tier]
	local depth = span * 0.4
	local blade = B.part(root, "Blade", BLADE_AT, Vector3.new(span, 0.3, depth))
	for k, v in {
		Span = span, Depth = depth, Height = 2.6,
		Pitch = 16, Roll = -10, -- degrees: leading edge up so its face shows from behind the caster, left tip high like the sweep's end
		TravelTime = 0.12, -- seconds to the full length: inside Hit -> Hit Stop (0.107 s) plus a frame or two
		TravelCurve = NS({ KP(0, 0), KP(0.25, 0.37), KP(0.5, 0.65), KP(0.75, 0.86), KP(1, 1) }), -- progress over time
		Echoes = ({ 0, 1, 2, 2 })[tier], EchoDelay = 0.045, EchoScale = 0.82,
	} do
		blade:SetAttribute(k, v)
	end
	local core = if tier >= 4 then GOLD_CORE else CORE
	-- saturated and nearly solid, low LightEmission: additive white-out washes
	-- the blade into the sky and the grass by day
	-- dark under light: an ink crescent a hair under the bright ones, so the blade reads on grass at noon
	crescent(blade, "Ink", span * 1.04, depth * 1.04, -0.05, span * 0.38, INK, 0.3, false, 0)
	crescent(blade, "Edge", span, depth, 0, span * 0.34, EDGE, 0.04, false, 0.15)
	crescent(blade, "Core", span * 0.94, depth * 0.9, 0.05, span * 0.16, core, 0, false, 0.4)
	crescent(blade, "Glow", span * 1.1, depth * 1.08, 0.02, span * 0.46, CYAN, 0.4, true, 0.35)
	-- the flat wake between the tips and a bright streak behind the centre
	local function trail(name, a0, a1, color, life, t0, faceCamera, light)
		local t = Instance.new("Trail")
		t.Name = name
		t.Attachment0, t.Attachment1 = a0, a1
		t.Color = CS(color)
		t.Transparency = NS({ KP(0, t0), KP(0.6, (1 + t0) / 2), KP(1, 1) })
		t.WidthScale = NS({ KP(0, 1), KP(1, 0.5) })
		t.Lifetime = life
		t.FaceCamera = faceCamera
		t.LightEmission, t.LightInfluence = light, 0
		t.MinLength = 0.05
		t.Parent = blade
	end
	trail("Wake", blade.EdgeL, blade.EdgeR, CYAN, ({ 0.16, 0.2, 0.24, 0.3 })[tier], 0.55, false, 0.4)
	local s0 = B.attach(blade, "StreakA", Vector3.new(0, 0.25, 0))
	local s1 = B.attach(blade, "StreakB", Vector3.new(0, -0.25, 0))
	trail("Streak", s0, s1, core, ({ 0.1, 0.12, 0.14, 0.18 })[tier], 0.15, true, 0.6)
	-- motes shed off the blade while it flies (the runtime toggles Enabled)
	local shed = B.emitter(blade, "Shed", {
		Texture = A.mote, Color = CS(CORE, CYAN),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(60, 60),
		Size = NS({ KP(0, 0.22), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.25, 0.45), Speed = R(2, 5), Drag = 3, LightEmission = 0.6, Rotation = R(0, 360),
		Rate = ({ 18, 26, 34, 45 })[tier],
	})
	shed:SetAttribute("Shed", true)
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = CYAN
		light.Range = 16
		light.Brightness = 0 -- the runtime lights it while the blade flies
		light.Shadows = false
		light.Parent = blade
	end
	return blade
end

-- The cut drawn on the ground behind the blade: a glowing Neon slit and the
-- dark ink scar it cools into (the runtime stretches both along the path).
B.BLOCKS.sqwCut = function(root, tier, p)
	local function strip(name, material, color, width, attrs, thick)
		local s = B.part(root, name, O * CFrame.new(0, 0.05, -16), Vector3.new(width, thick, 1))
		s.Material, s.Color = material, color
		for k, v in attrs do
			s:SetAttribute(k, v)
		end
		return s
	end
	strip("Cut", Enum.Material.Neon, Color3.fromRGB(120, 215, 255), ({ 0.22, 0.26, 0.3, 0.36 })[tier], {
		StartTransparency = 0.35, Fade = ({ 0.45, 0.55, 0.65, 0.8 })[tier], FadeColor = CYAN,
	}, 0.1) -- a hair above the scar, so the two never z-fight
	strip("Scar", Enum.Material.SmoothPlastic, INK, ({ 0.5, 0.6, 0.7, 0.85 })[tier], {
		StartTransparency = 0.35, Fade = ({ 1.0, 1.25, 1.5, 1.9 })[tier], FadeDelay = 0.25,
	}, 0.06)
	return root:FindFirstChild("Cut")
end

-- Aftermath emitters spread over the whole path (a Box the runtime sizes to it).
B.BLOCKS.sqwPath = function(root, tier, p)
	local path = B.part(root, "Path", O * CFrame.new(0, 0.2, -16), Vector3.new(0.6, 0.2, 32))
	if tier >= 2 then
		B.emitter(path, "Motes", {
			Texture = A.mote, Color = CS(CORE, CYAN),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
			Size = NS({ KP(0, 0.25), KP(0.5, 0.2), KP(1, 0) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(1, 1) }),
			Lifetime = R(0.7, 1.1), Speed = R(1.5, 3), Drag = 1, LightEmission = 0.5, Rotation = R(0, 360),
		}, { EmitCount = ({ 0, 8, 12, 16 })[tier], EmitDelay = 0.12 })
	end
	if tier >= 3 then
		B.emitter(path, "Cracks", B.flat({
			Texture = A.crackSmall, Color = CS(INK), LightInfluence = 0.3,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Size = NS(1.3), Transparency = NS({ KP(0, 1), KP(0.05, 0.3), KP(0.6, 0.45), KP(1, 1) }),
			Lifetime = R(1.1, 1.4), Rotation = R(0, 360), ZOffset = -0.5,
		}), { EmitCount = ({ 0, 0, 4, 6 })[tier], EmitDelay = 0.1 })
	end
	return path
end

-- The horizontal crescent cut flashed through each target's body.
-- The real blade's edge: the runtime moves Edge's Trails, Glow and Motes onto
-- the held model's Base -> Tip for the cut.
B.BLOCKS.sqwEdge = function(root, tier, p)
	return _G.vfxSpecs.BladeKit.edge(root, tier, {
		color = CYAN, core = if tier >= 4 then GOLD_CORE else CORE, tail = EDGE,
		trailLife = { 0.16, 0.2, 0.24, 0.3 }, glowWidth = { 0.5, 0.7, 0.9, 1.1 }, moteRate = { 10, 16, 22, 30 },
	})
end

B.BLOCKS.sqwSlash = function(root, tier, p)
	local part = root:FindFirstChild(p.part or "Impact")
	local body = part:FindFirstChild("Body")
	B.emitter(body, "SlashFlip", {
		Texture = A.crescentFlip, Color = CS(Color3.fromRGB(205, 240, 255)),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 2.2 + tier * 0.3), KP(1, 3.2 + tier * 0.4) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.15), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.5, Rotation = R(-8, 8), ZOffset = 3.2,
	}, { EmitCount = 1 })
	return B.emitter(body, "Slash", {
		Texture = A.slash, Color = CS(CORE, CYAN),
		Size = NS({ KP(0, 1), KP(0.25, 2.6 + tier * 0.45), KP(1, 3.2 + tier * 0.5) }), Transparency = NS({ KP(0, 0), KP(0.55, 0.15), KP(1, 1) }),
		Lifetime = R(0.26), LightEmission = 0.55, Rotation = R(-8, 8), ZOffset = 3,
	}, { EmitCount = 1 })
end

B.BLOCKS.sqwIntent = function(root, tier, p)
	local hand = B.part(root, "Hand", O * CFrame.new(1.2, 3.4, -0.8))
	return B.emitter(hand, "Intent", B.flat({
		Texture = A.intent, Color = CS(GOLD_CORE, CYAN),
		Size = NS({ KP(0, 1.5), KP(0.3, 4.6), KP(1, 5.4) }), Transparency = NS({ KP(0, 0.15), KP(0.5, 0.35), KP(1, 1) }),
		Lifetime = R(0.42), LightEmission = 0.5, Rotation = R(170, 190), ZOffset = 1,
	}, Enum.NormalId.Top), { EmitCount = 1 })
end

-- A lighter shake than Palm Strike's (a cut, not a ground blow); IV adds
-- impact frames at the release.
B.BLOCKS.sqwShake = function(root, tier, p)
	return B.screenShake(root, tier, { parent = "Hand", magnitude = ({ 0.8, 1.1, 1.5, 2 })[tier], frames = tier >= 4 })
end

-- The terminal burst where the blade ends: impactBurst + impactShockwave a
-- size up from a target's, the crescent cut, III+ a Craters rock ring.
B.BLOCKS.sqwTerminal = function(root, tier, p)
	local q = pal({ part = "Terminal", at = TERMINAL_AT })
	B.impactBurst(root, tier, q)
	q.size = ({ 4.6, 5.8, 7.2, 9 })[tier]
	q.groundSize = ({ 5, 6.4, 8, 10.5 })[tier]
	q.bubble = tier >= 3
	B.impactShockwave(root, tier, q)
	B.BLOCKS.sqwSlash(root, tier, { part = "Terminal" })
	if tier >= 3 then
		B.craterRing(root, tier, { parent = "Terminal", name = "Crater", attrs = {
			Count = ({ 0, 0, 6, 9 })[tier], Radius = ({ 0, 0, 2.2, 2.8 })[tier], Variance = 0.7, Duration = 0.12,
			Size = Vector3.new(1, 0.75, 0.9), Lifetime = R(1.1, 1.4), RaycastDistance = 8,
		} })
	end
	return root:FindFirstChild("Terminal")
end

-- Each target: impactStack in cyan, its 3D rings a size down from Palm
-- Strike's (a cut passing through, not a blast), III+ rock kicks, IV quake.
B.BLOCKS.sqwImpact = function(root, tier, p)
	local wave = pal({ size = ({ 3.4, 4.2, 5.2, 6.2 })[tier], groundSize = ({ 3.6, 4.4, 5.4, 6.6 })[tier] })
	return B.impactStack(root, tier, { burst = pal(), wave = wave })
end

local HAND_AT = O * CFrame.new(1.2, 3.4, -0.8) -- the right hand at Hit; runtime puts it on the live hand

return {
	id = "SwordQiWave",
	root = { attrs = { AuthoredActive = 0.107, AuthoredLength = 32, AuthoredWidth = 5 } },
	beats = {
		-- windup: a charge along the real blade (Base -> Tip) as it swings in
		{ block = "bladeCharge", params = { color = CYAN, core = CORE, ink = INK, width = 0.45 } },
		-- release off the blade
		{ block = "releaseFlash", params = pal({ part = "Hand", at = HAND_AT, light = false }) },
		{ block = "bladeFlare", params = { part = "Hand", color = CYAN, core = CORE, ink = INK } },
		{ block = "sqwEdge" },
		{ block = "airShockwave", params = pal({ part = "Hand", at = HAND_AT, color = PALETTE.ringColor, travel = nil }) },
		{ block = "sqwShake" },
		{ block = "sqwIntent", from = 4 },
		-- the blade itself and what it leaves on the ground
		{ block = "sqwBlade" },
		{ block = "sqwCut" },
		{ block = "sqwPath" },
		-- each target it passes through
		{ block = "sqwImpact" },
		{ block = "sqwSlash" },
		-- where it ends (max range, a wall or the ground): a bigger burst
		{ block = "sqwTerminal" },
	},
}
