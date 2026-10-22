--!nocheck
-- Moonflash Draw's templates (MoonflashDraw_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Runtime: src/client/TechniqueFX/MoonflashDraw.luau.
--
-- The move: Animations.Techniques.MoonflashDraw (1.0 s, Sword/jian, joint
-- HiltR), markers Hit 0.0667 / Hit Stop 0.2333 with Lunge start/end on the
-- same frames: the caster lunges def.lunge (14) studs during the active
-- window, and the line (def.length 18) runs from the cast's start. Sampled
-- with the Jian model (root frame): at Hit the blade is still sheathed, tip
-- behind the right hip (2.0, 3.0, +1.7); it is drawn flat round the right
-- side (0.13), across the front (0.15-0.21, point ~3.5 ahead, 3.0-3.7 off the
-- ground) and out to the left (0.233, 4.5 up), then held low behind-left
-- (zanshin) to 1.0. The draw is fastest at ~0.13-0.17.
--
-- The story (rebuilt 2026-10-21 after the user's playtest: "very misaligned
-- and make no sense ... just throwing vfx all over the place"). Every piece
-- has one job, one anchor and one moment; nothing is placed at a world point
-- that the 84 stud/s dash leaves behind:
--   Charge  (windup, 0 -> Hit): "Charge" on the jian's Base -> Tip.
--   Draw    (the draw's peak in Hit -> Hit Stop, WeaponFX.swing): "Hand" on
--           the jian's point, riding it for 0.3 s: a white-hot core, a crescent
--           moon in the cut's plane, star, glow, glint (LockedToPart), sparks
--           flying free, the shake.
--   Cut     (Hit -> dash end + 0.12): "Edge" on the jian's Base -> Tip: the
--           moon ribbon (II+ a longer afterimage ribbon), the glow, motes.
--   Ghosts  (II+, along the dash): afterimages of the body where it was.
--   Line    (Hit -> split): "Streak" from the dash start to the blade's reach
--           ahead of the live root, at the cut's height: ink under a white core
--           under a moon glow.
--   Hits    (as the reach passes each target): "Impact" (the hit stack and a
--           crescent cut through the body) on the target.
--   Split   (dash end + SheatheDelay): the line flares wide (Split) and fades,
--           "Sheathe" flashes on every target cut (II+; IV impact frames),
--           "SheatheGlint" on the live point as the blade settles; III+ the
--           hit-pause punch.
-- Cut in this pass: the crescent "Front" riding ahead of the root (a second
-- arc that never matched the blade), its echo crescents and wake, the air rings
-- left hanging where the draw happened, the ground cut and path motes, the
-- finish mark and torus at the feet, the hand glint "Windup".
--
-- Authored along -Z at length 14, width 5, active 0.16 s.
local B = _G.vfxBlocks
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local MOON = Color3.fromRGB(165, 182, 255) -- the technique colour (suggested def.color)
local CORE = Color3.fromRGB(246, 248, 255)
local EDGE = Color3.fromRGB(98, 112, 246) -- the crescent's body, deeper than MOON
local GOLD_CORE = Color3.fromRGB(255, 242, 208) -- mastery core
local INK = Color3.fromRGB(28, 30, 62)
local PALETTE = {
	color = MOON, core = CORE,
	ringColor = Color3.fromRGB(226, 232, 255), swirlColor = Color3.fromRGB(176, 190, 255), groundColor = Color3.fromRGB(200, 212, 255),
}
local function pal(extra)
	local t = table.clone(PALETTE)
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

local A = {
	moon = id(1084963972), -- crisp crescent moon
	slash = id(7216852121), -- clean horizontal crescent
	layered = id(13366366767), -- layered crescent slashes
	mote = id(9841260273), -- glowing spindle mote
	crackSmall = id(97725700315217),
	star4 = id(13271628051),
	crescentFlip = id(13972642464), -- 4x4 flipbook: a thin crescent moon sweeping and fading (cold edge)
	ring = id(9841273159), -- clean thin ring
}
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local ONESHOT = Enum.ParticleFlipbookMode.OneShot

local HEIGHT = 3.4 -- the blade's arc, chest height
local HAND_AT = O * CFrame.new(1.4, 3.4, -1.2) -- right hand at Hit; runtime puts it on the live hand

-- A straight streak of moonlight from the dash start to the front (the
-- runtime places A0 at the start and A1 at the front).
B.BLOCKS.mfdStreak = function(root, tier, p)
	local streak = B.part(root, "Streak", O * CFrame.new(0, HEIGHT, 0))
	local a0 = B.attach(streak, "A0", Vector3.zero)
	local a1 = B.attach(streak, "A1", Vector3.new(0, 0, -14))
	local function beam(name, width, color, transparency, light)
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = width * 0.35, width
		b.FaceCamera = true
		b.Color = CS(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Transparency = NS({ KP(0, 1), KP(0.25, transparency + (1 - transparency) * 0.4), KP(1, transparency) })
		b.Segments = 10
		b.Enabled = false
		b.Parent = streak
	end
	beam("Ink", ({ 0.7, 0.8, 0.9, 1.05 })[tier], INK, 0.5, 0) -- dark under light: the line reads on grass at noon
	beam("Core", ({ 0.22, 0.26, 0.3, 0.36 })[tier], if tier >= 4 then GOLD_CORE else CORE, 0, 1)
	beam("Glow", ({ 1.2, 1.4, 1.7, 2 })[tier], MOON, 0.6, 0.6)
	streak:SetAttribute("Height", HEIGHT)
	streak:SetAttribute("Fade", ({ 0.3, 0.35, 0.4, 0.5 })[tier])
	streak:SetAttribute("Split", ({ 1.6, 2, 2.4, 3 })[tier]) -- how wide the line flares when it splits
	return streak
end

-- The draw flash: the runtime plays part "Hand" on the jian's point where
-- the draw is fastest and moves it with the point for `Ride` seconds; emitters
-- tagged `Ride` are LockedToPart there, so the flash travels with the cut. A
-- white-hot core (blinding, one beat), a crescent moon lying in the cut's
-- plane, then releaseFlash's star, glow, glint and sparks.
B.BLOCKS.mfdDraw = function(root, tier, p)
	local hand = B.part(root, "Hand", HAND_AT)
	hand:SetAttribute("Ride", 0.3)
	B.emitter(hand, "Core", {
		Texture = B.ASSETS.dot, Color = CS(CORE),
		Size = NS({ KP(0, 0.8), KP(0.25, 2 + tier * 0.35), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.1), KP(1, 1) }),
		Lifetime = R(0.12), LightEmission = 1, Brightness = 5, ZOffset = 2,
	}, { EmitCount = 1, Ride = true })
	B.emitter(hand, "Moon", B.flat({
		Texture = A.moon, Color = CS(CORE, MOON),
		Size = NS({ KP(0, 1), KP(0.3, 2.6 + tier * 0.4), KP(1, 3.2 + tier * 0.45) }), Transparency = NS({ KP(0, 0.05), KP(0.5, 0.2), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.7, Rotation = R(80, 100), ZOffset = 1,
	}, Enum.NormalId.Top), { EmitCount = 1, Ride = true })
	return hand
end

-- The release flash's star, glow and glint ride the point too (sparks fly free).
B.BLOCKS.mfdRide = function(root, tier, p)
	local hand = root:FindFirstChild("Hand")
	for _, name in { "Flash", "Glow", "Glint" } do
		local e = hand:FindFirstChild(name)
		if e then
			e:SetAttribute("Ride", true)
		end
	end
	return hand
end

-- The horizontal crescent cut through each target.
B.BLOCKS.mfdSlash = function(root, tier, p)
	local part = root:FindFirstChild(p.part or "Impact")
	local body = part:FindFirstChild("Body")
	-- the moon's own edge sweeping through the body: a crescent flipbook
	B.emitter(body, (p.name or "Slash") .. "Flip", {
		Texture = A.crescentFlip, Color = CS(Color3.new(1, 1, 1)),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 2.4 + tier * 0.3), KP(1, 3.4 + tier * 0.4) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.15), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.5, Rotation = p.rotation or R(-8, 8), ZOffset = 3.2,
	}, { EmitCount = 1 })
	return B.emitter(body, p.name or "Slash", {
		Texture = p.texture or A.slash, Color = CS(CORE, MOON),
		Size = NS({ KP(0, 1), KP(0.25, 2.8 + tier * 0.45), KP(1, 3.4 + tier * 0.5) }), Transparency = NS({ KP(0, 0), KP(0.55, 0.15), KP(1, 1) }),
		Lifetime = R(p.life or 0.28), LightEmission = 0.55, Rotation = p.rotation or R(-8, 8), ZOffset = 3,
	}, { EmitCount = 1 })
end

B.BLOCKS.mfdImpact = function(root, tier, p)
	local wave = pal({ size = ({ 3.4, 4.2, 5.2, 6.2 })[tier], groundSize = ({ 3.6, 4.4, 5.4, 6.6 })[tier] })
	return B.impactStack(root, tier, { burst = pal(), wave = wave })
end

-- II+: the after-the-draw flash on each target cut (a crossing crescent, a
-- star, a white standing ring), IV impact frames on the first.
B.BLOCKS.mfdSheathe = function(root, tier, p)
	local part = B.part(root, "Sheathe", O * CFrame.new(0, 0.15, -6))
	local body = B.attach(part, "Body", Vector3.new(0, 2.2, 0))
	B.BLOCKS.mfdSlash(root, tier, { part = "Sheathe", name = "Cross", texture = A.layered, rotation = R(-40, -25), life = 0.34 })
	B.emitter(body, "Flash", {
		Texture = A.star4, Color = CS(CORE),
		Size = NS({ KP(0, 0.8), KP(0.3, 2.4 + tier * 0.35), KP(1, 0) }), Transparency = NS(0),
		Lifetime = R(0.16), LightEmission = 0.8, Rotation = R(-15, 15), ZOffset = 3,
	}, { EmitCount = 1 })
	B.emitter(body, "Motes", {
		Texture = A.mote, Color = CS(CORE, MOON), SpreadAngle = Vector2.new(180, 180),
		Size = NS({ KP(0, 0.3), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.4, 0.7), Speed = R(6, 12), Drag = 4, LightEmission = 0.6, Rotation = R(0, 360), ZOffset = 2,
	}, { EmitCount = ({ 0, 6, 9, 12 })[tier] })
	local d = ({ 0, 4.4, 5.4, 6.6 })[tier]
	B.meshWave(body, "SheatheRing", {
		mesh = B.ASSETS.torusMesh, color = CORE,
		fromSize = Vector3.new(1, 0.15, 1), toSize = Vector3.new(d, d * 0.12, d),
		rotation = Vector3.new(90, 0, 0), fromTransparency = 0.15, toTransparency = 1,
		duration = 0.34, style = "Quart",
	})
	if tier >= 4 then
		B.screenShake(root, tier, { parent = "Sheathe", name = "Frames", shake = false, framesName = "SheatheFrames", frames = true })
	end
	return part
end

-- The real blade's edge: the runtime moves Edge's Trails, Glow beam and Motes
-- onto the held model's Base -> Tip for the dash.
B.BLOCKS.mfdEdge = function(root, tier, p)
	return _G.vfxSpecs.BladeKit.edge(root, tier, {
		color = MOON, core = if tier >= 4 then GOLD_CORE else CORE, tail = EDGE,
		trailLife = { 0.22, 0.26, 0.3, 0.36 }, glowWidth = { 0.7, 0.9, 1.1, 1.3 }, moteRate = { 10, 16, 22, 30 },
	})
end

-- The flare on the blade tip as it is put away (a beat after the dash).
B.BLOCKS.mfdSheatheGlint = function(root, tier, p)
	local g = B.part(root, "SheatheGlint", O * CFrame.new(0, HEIGHT, -4), Vector3.new(1, 1, 1))
	B.emitter(g, "Star", {
		Texture = A.star4, Color = CS(CORE),
		Size = NS({ KP(0, 0.5), KP(0.3, 2.8 + tier * 0.5), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }),
		Lifetime = R(0.38), LightEmission = 0.9, Rotation = R(-10, 10), ZOffset = 1,
	}, { EmitCount = 1 })
	B.emitter(g, "Halo", {
		Texture = A.ring, Color = CS(MOON),
		Size = NS({ KP(0, 0.4), KP(1, 2.6 + tier * 0.4) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.34), LightEmission = 0.6, ZOffset = 0.5,
	}, { EmitCount = 1 })
	B.emitter(g, "Crescent", {
		Texture = A.crescentFlip, Color = CS(Color3.new(1, 1, 1)),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 2), KP(1, 3.4 + tier * 0.4) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.4), LightEmission = 0.55, Rotation = R(-40, -20), ZOffset = 1.2,
	}, { EmitCount = 1 })
	B.emitter(g, "Motes", {
		Texture = A.mote, Color = CS(CORE, MOON), SpreadAngle = Vector2.new(180, 180),
		Size = NS({ KP(0, 0.28), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.4, 0.8), Speed = R(2, 6), Drag = 2, LightEmission = 0.6, Rotation = R(0, 360), Acceleration = Vector3.new(0, 1.5, 0),
	}, { EmitCount = 4 + tier * 2 })
	return g
end

B.BLOCKS.mfdShake = function(root, tier, p)
	return B.screenShake(root, tier, { parent = "Hand", magnitude = ({ 0.6, 1, 1.6, 2.3 })[tier] })
end

return {
	id = "MoonflashDraw",
	root = { attrs = { AuthoredActive = 0.16, AuthoredLength = 14, AuthoredWidth = 5 } },
	beats = {
		-- the blade catches the light as it clears the scabbard (along Base -> Tip)
		{ block = "bladeCharge", params = { color = MOON, core = CORE, ink = INK, width = 0.4 } },
		-- the draw: on the jian's point where the draw is fastest, riding it
		{ block = "mfdDraw" },
		{ block = "releaseFlash", params = pal({ part = "Hand", at = HAND_AT, light = false }) },
		{ block = "mfdRide" },
		{ block = "mfdShake" },
		-- the cut: the real blade through the dash; the line along the dash
		{ block = "mfdEdge" },
		{ block = "mfdStreak" },
		-- each target as the blade's reach passes it, and again at the split
		{ block = "mfdImpact" },
		{ block = "mfdSlash" },
		{ block = "mfdSheathe", from = 2 },
		{ block = "mfdSheatheGlint" },
	},
}
