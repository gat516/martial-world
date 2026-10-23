--!nocheck
-- Rampaging Tiger Cleave's templates (RampagingTiger_T1..T4). Build with
-- RampagingTiger.build(parent). Runtime: src/client/TechniqueFX/RampagingTiger.luau
-- (+ BladeSkill.luau).
--
-- The move (Saber / dadao, one-handed, anim 75310024933368, 2.12 s; clip
-- seconds, real = clip / castSpeed). Sampled on gsrigrea2lfixed:
--   0.00-0.45  the saber is drawn up to the left shoulder (windup).
--   0.50-0.65  the DIAGONAL CUT: high left, through the front, low right.
--   0.65-0.95  crouch; 0.95-1.40 the LEAP (up 3.0 at 1.4).
--   1.00-1.75  the SPIN: the blade wheels through a vertical circle at the
--              right side (HiltR spins 381 deg): low-right, back, up over the
--              head and down through the front at 1.30-1.40, round again.
--   1.75-1.90  the LANDING CUT: down through the front into the ground as the
--              body lands in a crouch; held to 2.12.
-- Gameplay: circle r 10 around the caster, lunge 6, hits { 0.48 cut, two
-- spin hits ~1.0-1.7, 1.78 landing } (9, 7, 7, 16 dmg).
--
-- INTENT (heavy pass 2026-10-23): a tiger pounces. The saber cuts, the body
-- leaps and the blade wheels like a tiger rolling in to strike, then it lands
-- with the whole weight on one cleave that rakes the ground. The player should
-- feel ferocity and weight; the job is a hit confirm over the r 10 circle, the
-- landing the one peak. Palette: tawny amber over black ink, white-gold core
-- at IV.
--
-- BEAT SHEET (real ms at castSpeed 1.0; clip markers drive every beat):
--   0-480     windup: Charge along the dadao (Base -> Tip)
--   480       Hit 1, the diagonal cut: claw strokes, tip flare, light impacts
--   950       Leap: ragged wind ring + dust at the feet
--   1000-1780 THE WHEEL (anticipation, ~35%): the blade's circle at the right
--             side draws itself (spec.variant below), spin hits at 1033/1317
--   1783      PEAK, the landing cleave (Hit 4 window, WeaponFX.swing): the
--             variant's hero at the bite, core flash, chips
--   1783-2200 follow-through: ragged shock ring + dust wall out to r 10, heavy
--             impacts as the front reaches each enemy, three claw rends torn
--             forward, III+ rock ring and cracks
--   2200-3500 dissipation: the rends cool to ink, dust settles, the scar fades
--
-- DIRECTIONS (spec.variant; the wheel and the landing hero only):
--   A "Tiger's claws" (SHIPPED, the user's pick 2026-10-23): the wheel is a
--     run of claw crescents (amber over ink) torn along the blade's circle as
--     it turns; the landing is a giant three-claw rake in the cut's plane.
--   B "Ink-brush cleave" (finished; slated to become its own technique,
--     Inkfall Cleave): the wheel is a thick ink brush circle (an enso)
--     painted round behind the blade with an amber edge; the landing is a
--     huge brush stroke in the cut's plane, an umber dust burst and an ink
--     splat on the ground.
-- NO CAMERA-FACING SHAPES (user, 2026-10-23): every shaped layer lies in a
-- world plane set by the cut (claw strokes along the look, the wheel in the
-- blade's circle, the hero and the tip flare in the cut's plane); only round
-- dust, motes, chips, sparks and the shared per-enemy impact face the camera.
--
-- LAYER SHEET (role: cause -> asset and why)
-- Rake (A)     HERO: the tiger's paw coming down with the cleave, in the cut's plane -> three-claw spindles 11636552631 on an ink copy
-- Wheel (A)    secondary: the blade tearing through its circle -> claw crescent flipbook 13463732785 (2x2) over an ink copy
-- Brush (B)    HERO: the cleave as one falling brush stroke -> brush crescent 109919844196737 on an ink copy
-- Enso (B)     secondary: the blade's circle painted in ink -> brush crescent 109919844196737
-- BrushBurst (B) secondary: the ground bursting under the weight -> explosive puff flipbook 12360899465 over umber
-- GroundWave   secondary: the landing's shock to the radius -> ragged wind ring mesh 121387125059545
-- DustWall     tertiary: air shoved along the ground -> dust cloud flipbook 113990972016632
-- LaunchRing   secondary: air pushed off by the leap -> ragged wind ring mesh 136611516099795
-- Splat        environment: ink thrown on the ground at the bite -> ink splat 16132530029
-- Cracks       environment: the circle left broken (III+) -> crack 93520831389146
--
local spec -- set at the bottom; blocks read spec.variant
local KIT_ = function()
	return _G.vfxSpecs.BladeKit
end
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local AMBER = Color3.fromRGB(255, 172, 66) -- suggested def.color
local CORE = Color3.fromRGB(255, 240, 206)
local GOLD = Color3.fromRGB(255, 226, 140)
local INK = Color3.fromRGB(30, 20, 14)
local N_AMBER = Color3.fromRGB(240, 118, 28)
local N_PALE = Color3.fromRGB(255, 170, 70)
local DUST = Color3.fromRGB(222, 206, 178)
local UMBER = Color3.fromRGB(70, 48, 30)

local RADIUS = 10
local HAND_AT = O * CFrame.new(-1.2, 3.6, -0.6) -- the right hand drawn up to the left shoulder

local A = {
	crack = id(93520831389146),
	spindle = id(7814053668),
	mote = id(9841260273),
	dust = id(11037785287),
	glint = id(13366348510), -- crisp 4-point star
	hitFlip = id(13580358178), -- 4x4 flipbook: a spiky star burst opening and breaking up
	ink = id(16132530029), -- black ink splat
	rake = id(11636552631), -- three tall claw spindles
	clawFlip = id(13463732785), -- 2x2 flipbook: a thick claw crescent opening
	brush = id(109919844196737), -- a thick dry-brush crescent
	burst = id(12360899465), -- 4x4 explosive puff
	dustFlip = id(113990972016632), -- 4x4 dust cloud
	raggedRing = id(121387125059545), -- ragged wind ring mesh (the landing's shock)
	leapRing = id(136611516099795), -- ragged wind ring mesh (the leap)
	dot = id(9841273544), -- core dot
}
local GRID2 = Enum.ParticleFlipbookLayout.Grid2x2

local function variant()
	return spec.variant or "A"
end
local GRID4 = Enum.ParticleFlipbookLayout.Grid4x4
local ONESHOT = Enum.ParticleFlipbookMode.OneShot

local function pal(core)
	return {
		color = AMBER, core = core or CORE,
		ringColor = Color3.fromRGB(255, 176, 90), swirlColor = Color3.fromRGB(255, 160, 70), groundColor = Color3.fromRGB(255, 165, 75),
	}
end
local function coreOf(tier)
	return if tier >= 4 then GOLD else CORE
end

local blocks = {}

blocks.windup = function(root, tier)
	local p = pal(coreOf(tier))
	p.windup, p.at, p.wisps = 0.4, HAND_AT, false
	return _G.vfxBlocks.handGather(root, tier, p)
end

blocks.charge = function(root, tier)
	return _G.vfxBlocks.bladeCharge(root, tier, { color = AMBER, core = coreOf(tier), ink = INK, width = 0.5 })
end

-- The flare on the blade tip at each cut (the runtime puts it on the live tip).
blocks.flare = function(root, tier)
	local B0 = _G.vfxBlocks
	local f = B0.part(root, "Flare", O * CFrame.new(0, 3, -3), V(1, 1, 1))
	B0.emitter(f, "Ink", B0.flat({
		Texture = A.ink, Color = CS(INK),
		Size = NS({ KP(0, 1), KP(0.25, 2.2 + tier * 0.3), KP(1, 2.8 + tier * 0.3) }), Transparency = NS({ KP(0, 0.2), KP(0.6, 0.45), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0, Rotation = R(0, 360), ZOffset = 0.8,
	}, Enum.NormalId.Front), { EmitCount = 1 })
	B0.emitter(f, "Burst", B0.flat({
		Texture = A.hitFlip, Color = CS(coreOf(tier), AMBER),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 1.8 + tier * 0.25), KP(1, 2.8 + tier * 0.35) }), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.28), LightEmission = 0.6, Rotation = R(0, 360), ZOffset = 1.4,
	}, Enum.NormalId.Front), { EmitCount = 1 })
	B0.emitter(f, "Glint", B0.flat({
		Texture = A.glint, Color = CS(coreOf(tier)),
		Size = NS({ KP(0, 0.4), KP(0.25, 2 + tier * 0.35), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.28), LightEmission = 0.85, Rotation = R(-12, 12), ZOffset = 2,
	}, Enum.NormalId.Front), { EmitCount = 1 })
	B0.emitter(f, "Sparks", {
		Texture = A.spindle, Color = CS(coreOf(tier), AMBER), Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(60, 60), Size = NS({ KP(0, 0.22), KP(1, 0) }), Squash = NS({ KP(0, 2), KP(1, 1) }),
		Transparency = NS(0), Lifetime = R(0.15, 0.3), Speed = R(16, 28), Drag = 6, LightEmission = 0.6,
	}, { EmitCount = ({ 4, 6, 8, 10 })[tier] })
	return f
end

blocks.edge = function(root, tier)
	return KIT_().edge(root, tier, { color = AMBER, core = coreOf(tier), tail = N_AMBER, trailLife = { 0.16, 0.2, 0.24, 0.28 }, glowWidth = { 0.4, 0.55, 0.7, 0.9 } })
end

-- three parallel claw strokes, amber over a black ink stroke; the runtime
-- turns it to each cut (Roll) and fades it (Hold, Fade)
blocks.claw = function(root, tier)
	local B0 = _G.vfxBlocks
	local K = KIT_()
	local span = ({ 4.8, 5.3, 5.8, 6.4 })[tier]
	local part = B0.part(root, "Claw", O * CFrame.new(0, 2.6, -2.6), V(span, 2, 0.2))
	part:SetAttribute("Hold", 0.1)
	part:SetAttribute("Fade", ({ 0.28, 0.32, 0.36, 0.42 })[tier])
	local gap = span * 0.17
	for i = -1, 1 do
		local y = i * gap
		local s = span * (1 - math.abs(i) * 0.14) -- outer strokes a little shorter
		K.crescent(part, "Ink" .. (i + 2), { span = s * 1.05, bow = s * 0.24, y = y - 0.08, width = s * 0.13, color = INK, transparency = 0.45, light = 0 })
		K.crescent(part, "Stroke" .. (i + 2), { span = s, bow = s * 0.24, y = y, width = s * 0.1, color = if i == 0 then coreOf(tier) else AMBER, transparency = 0, light = 0.35 })
	end
	return part
end

blocks.impact = function(root, tier)
	local wave = pal(coreOf(tier))
	wave.size = ({ 3.4, 4.2, 5.2, 6.4 })[tier]
	wave.groundSize = ({ 3.6, 4.4, 5.4, 6.8 })[tier]
	return _G.vfxBlocks.impactStack(root, tier, { burst = pal(coreOf(tier)), wave = wave })
end

blocks.launch = function(root, tier)
	local B0 = _G.vfxBlocks
	local part = B0.part(root, "Launch", O * CFrame.new(0, 0.2, 0))
	B0.meshWave(part, "LaunchRing", {
		mesh = A.leapRing, color = N_PALE,
		fromSize = V(1.4, 0.3, 1.4), toSize = V(6 + tier, 0.9 + tier * 0.1, 6 + tier),
		fromOffset = V(0, 0.15, 0), toOffset = V(0, 0.15, 0),
		fromTransparency = 0.35, toTransparency = 1, duration = 0.36, style = "Quart",
	}):SetAttribute("FadeStyle", "Quint")
	B0.emitter(part, "Dust", {
		Texture = A.dust, Color = CS(DUST), LightInfluence = 0.5,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Size = NS({ KP(0, 0.7), KP(1, 1.9) }), Transparency = NS({ KP(0, 0.35), KP(0.5, 0.55), KP(1, 1) }),
		Lifetime = R(0.4, 0.6), Speed = R(14, 20), Drag = 4, Rotation = R(0, 360), RotSpeed = R(-60, 60),
	}, { EmitCount = ({ 5, 7, 8, 10 })[tier] })
	return part
end

-- the wheel the spinning blade cuts at the right side. The runtime stands
-- `Wheel` in the blade's circle (local +Y = the wheel's axis, so these
-- VelocityPerpendicular emitters lie in the wheel plane), scales every Size by
-- the blade's reach (authored at radius 1) and emits each Wheel* emitter once
-- per `Step` degrees the tip turns, rolled to the tip's angle (Rotation =
-- RollSign * angle + RollOffset; angle 0 = the tip straight down)
blocks.wheel = function(root, tier)
	local B0 = _G.vfxBlocks
	local v = variant()
	local holder = B0.part(root, "Wheel", O * CFrame.new(1.2, 3, -0.6))
	holder:SetAttribute("Step", ({ 70, 60, 55, 48 })[tier])
	holder:SetAttribute("RollSign", -1) -- Rotation turns clockwise as seen from the right, the angle counter-clockwise
	holder:SetAttribute("RollOffset", 0)
	local plane = function(props)
		props.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		props.EmissionDirection = Enum.NormalId.Top
		props.Speed = R(0.01)
		props.SpreadAngle = Vector2.zero
		props.Rate = 0
		return props
	end
	if v == "A" then
		-- claw crescents torn along the circle, amber over an ink copy
		B0.emitter(holder, "WheelInk", plane({
			Texture = A.clawFlip, Color = CS(INK), FlipbookLayout = GRID2, FlipbookMode = ONESHOT,
			LightEmission = 0, LightInfluence = 0.2,
			Size = NS({ KP(0, 2.05), KP(1, 2.2) }), Transparency = NS({ KP(0, 0.35), KP(0.6, 0.5), KP(1, 1) }),
			Lifetime = R(0.17), ZOffset = -0.3,
		}))
		B0.emitter(holder, "WheelClaw", plane({
			Texture = A.clawFlip, Color = CS(coreOf(tier), AMBER), FlipbookLayout = GRID2, FlipbookMode = ONESHOT,
			LightEmission = 0.7, Brightness = 1.4,
			Size = NS({ KP(0, 2), KP(1, 2.1) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.25), KP(1, 1) }),
			Lifetime = R(0.15),
		}))
	else
		-- an enso: a thick ink brush circle painted behind the blade, amber edge
		B0.emitter(holder, "WheelInk", plane({
			Texture = A.brush, Color = CS(INK), LightEmission = 0, LightInfluence = 0.2,
			Size = NS({ KP(0, 2.05), KP(1, 2.2) }), Transparency = NS({ KP(0, 0.05), KP(0.7, 0.3), KP(1, 1) }),
			Lifetime = R(0.5), ZOffset = -0.3,
		}))
		B0.emitter(holder, "WheelBrush", plane({
			Texture = A.brush, Color = CS(coreOf(tier), N_AMBER), LightEmission = 0.5, Brightness = 1.2,
			Size = NS({ KP(0, 2), KP(1, 2.1) }), Transparency = NS({ KP(0, 0.1), KP(0.4, 0.35), KP(1, 1) }),
			Lifetime = R(0.3),
		}))
	end
	if tier >= 3 then
		B0.emitter(holder, "Embers", {
			Texture = A.mote, Color = CS(coreOf(tier), AMBER),
			Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0.25), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
			Lifetime = R(0.35, 0.6), Speed = R(3, 7), Drag = 2, LightEmission = 0.55, Rotation = R(0, 360),
			Rate = ({ 0, 0, 18, 26 })[tier],
		})
	end
	return holder
end

-- the bite, where the landing cleave strikes (placed at the ground under the
-- point, looking along the cut): the variant's hero, a core flash, chips
blocks.strike = function(root, tier)
	local B0 = _G.vfxBlocks
	local v = variant()
	local core = coreOf(tier)
	local part = B0.part(root, "Strike", O * CFrame.new(0.5, 0.4, -2.6))
	B0.emitter(part, "Core", {
		Texture = A.dot, Color = CS(core), LightEmission = 1, Brightness = 3,
		Size = NS({ KP(0, ({ 2.2, 2.6, 3, 3.4 })[tier]), KP(1, 0.4) }), Transparency = NS({ KP(0, 0), KP(1, 1) }),
		Lifetime = R(0.09), ZOffset = 1,
	}, { EmitCount = 1 })
	B0.emitter(part, "Splat", B0.flat({
		Texture = A.ink, Color = CS(INK), LightEmission = 0, LightInfluence = 0.3,
		Size = NS({ KP(0, 1.5), KP(0.12, ({ 4, 4.6, 5.4, 6.4 })[tier]), KP(1, ({ 4.3, 5, 5.8, 6.8 })[tier]) }),
		Transparency = NS({ KP(0, 0.15), KP(0.7, 0.35), KP(1, 1) }),
		Lifetime = R(1.4), Rotation = R(0, 360), ZOffset = -0.2,
	}), { EmitCount = 1 })
	-- the hero lives on `Cleave`, a world-space plane along the cut: the runtime
	-- turns its local X to the cut plane's normal (the swing x the blade) and
	-- adds the swing's angle in that plane to each emitter's Rotation, so the
	-- hero lies in the blade's travel (edge-on from behind, full from the side)
	local cleave = B0.part(root, "Cleave", O * CFrame.new(0.5, 0.4, -2.6))
	local inPlane = function(props)
		props.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		props.EmissionDirection = Enum.NormalId.Right
		props.Speed = R(0.01)
		props.SpreadAngle = Vector2.zero
		return props
	end
	if v == "A" then
		-- HERO: the tiger's paw comes down with the cleave, three claws raking
		-- through the bite along the swing, on an ink copy
		local H = ({ 6, 7, 8, 9.5 })[tier]
		local at = B0.attach(cleave, "RakeAt", V(0, H * 0.42, 0))
		B0.emitter(at, "RakeInk", inPlane({
			Texture = A.rake, Color = CS(INK),
			LightEmission = 0, LightInfluence = 0.2,
			Size = NS({ KP(0, H * 1.05), KP(0.2, H * 1.12), KP(1, H * 1.15) }), Squash = NS({ KP(0, 1.4), KP(0.2, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.3), KP(0.5, 0.45), KP(1, 1) }), Lifetime = R(0.36), ZOffset = -0.5,
		}), { EmitCount = 1 })
		B0.emitter(at, "Rake", inPlane({
			Texture = A.rake, Color = CS(core, AMBER),
			LightEmission = 0.8, Brightness = 1.6,
			-- lands long and thin (the claws tearing down), then settles to full width
			Size = NS({ KP(0, H), KP(0.2, H * 1.05), KP(1, H * 1.08) }), Squash = NS({ KP(0, 1.6), KP(0.2, 0.25), KP(1, 0.05) }),
			Transparency = NS({ KP(0, 0), KP(0.4, 0.15), KP(1, 1) }), Lifetime = R(0.3),
		}), { EmitCount = 1 })
	else
		-- HERO: the cleave as one falling brush stroke, ink with an amber edge,
		-- over an umber dust burst where the ground gives
		local H = ({ 7.5, 9, 10.5, 12.5 })[tier]
		local at = B0.attach(cleave, "BrushAt", V(0, H * 0.4, 0))
		B0.emitter(at, "BrushInk", inPlane({
			Texture = A.brush, Color = CS(INK),
			LightEmission = 0, LightInfluence = 0.2,
			Size = NS({ KP(0, H * 0.9), KP(0.15, H * 1.1), KP(1, H * 1.15) }), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.3), KP(1, 1) }),
			Lifetime = R(0.5), Rotation = R(-28), ZOffset = -0.5,
		}), { EmitCount = 1 })
		B0.emitter(at, "Brush", inPlane({
			Texture = A.brush, Color = CS(core, N_AMBER),
			LightEmission = 0.6, Brightness = 1.4,
			Size = NS({ KP(0, H * 0.8), KP(0.15, H), KP(1, H * 1.02) }), Transparency = NS({ KP(0, 0), KP(0.4, 0.25), KP(1, 1) }),
			Lifetime = R(0.32), Rotation = R(-28),
		}), { EmitCount = 1 })
		local s = ({ 5, 6, 7.5, 9 })[tier]
		local bAt = B0.attach(part, "BurstAt", V(0, s * 0.3, 0))
		B0.emitter(bAt, "BurstInk", {
			Texture = A.burst, Color = CS(UMBER), LightEmission = 0, LightInfluence = 0.6,
			FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
			Size = NS({ KP(0, s * 0.8), KP(1, s * 1.1) }), Transparency = NS({ KP(0, 0.05), KP(0.3, 0.6), KP(0.6, 0.9), KP(1, 1) }),
			Lifetime = R(0.22), Rotation = R(0, 360), ZOffset = -0.6,
		}, { EmitCount = 1 })
		B0.emitter(bAt, "Burst", {
			Texture = A.burst, Color = CS(DUST), LightEmission = 0.1, LightInfluence = 0.8,
			FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
			Size = NS({ KP(0, s * 0.6), KP(1, s * 0.95) }), Transparency = NS({ KP(0, 0), KP(0.5, 0.45), KP(0.7, 0.95), KP(1, 1) }),
			Lifetime = R(0.3), Rotation = R(0, 360),
		}, { EmitCount = 1 })
	end
	-- tertiary: chips and dust kicked up by the edge
	B0.emitter(part, "Chips", {
		Texture = A.dust, Color = CS(DUST), LightInfluence = 0.8,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
		Size = NS({ KP(0, 0.6), KP(1, 1.6) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		Lifetime = R(0.4, 0.6), Speed = R(9, 14), Drag = 4, Rotation = R(0, 360), Acceleration = V(0, -12, 0),
	}, { EmitCount = 3 + tier })
	return part
end

-- what rolls out from the landing to the circle (centred on the caster)
blocks.slam = function(root, tier)
	local B0 = _G.vfxBlocks
	local v = variant()
	local ground = B0.part(root, "Slam", O * CFrame.new(0, 0.2, 0))
	B0.meshWave(ground, "GroundWave", {
		mesh = A.raggedRing, color = v == "B" and Color3.fromRGB(150, 110, 70) or N_PALE,
		material = v == "B" and Enum.Material.Slate or Enum.Material.Neon,
		fromSize = V(2, 0.6, 2), toSize = V(RADIUS * 2.3, 1.5 + tier * 0.3, RADIUS * 2.3),
		fromOffset = V(0, 0.3, 0), toOffset = V(0, 0.3, 0),
		fromTransparency = v == "B" and 0.1 or 0.25, toTransparency = 1, duration = 0.46, style = "Quint",
	}):SetAttribute("FadeStyle", "Quint")
	B0.emitter(ground, "DustWall", {
		Texture = A.dustFlip, Color = CS(DUST), LightEmission = 0, LightInfluence = 1,
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(4, 180),
		Size = NS({ KP(0, 1.8), KP(1, 3.8 + tier * 0.4) }), Transparency = NS({ KP(0, 0.15), KP(0.6, 0.4), KP(1, 1) }),
		Lifetime = R(0.6, 0.9), Speed = R(26, 34), Drag = 3, Rotation = R(0, 360), RotSpeed = R(-40, 40),
	}, { EmitCount = 6 + tier * 2 })
	if tier >= 3 then
		B0.craterRing(root, tier, { parent = "Slam", attrs = {
			Radius = RADIUS * 0.7, Count = ({ 0, 0, 8, 12 })[tier], Duration = 0.3,
		} })
		B0.emitter(ground, "Cracks", B0.flat({
			Texture = A.crack, Color = CS(INK), LightInfluence = 0.3,
			Size = NS(({ 0, 0, 6, 8 })[tier]), Transparency = NS({ KP(0, 1), KP(0.04, 0.15), KP(0.65, 0.3), KP(1, 1) }),
			Lifetime = R(1.8), Rotation = R(0, 360), ZOffset = -0.4,
		}), { EmitCount = 1 })
	end
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = AMBER
		light.Range = 22
		light.Brightness = 0
		light.Shadows = false
		light.Parent = ground
	end
	B0.screenShake(root, tier, { parent = "Slam", magnitude = ({ 1.1, 1.8, 2.8, 3.8 })[tier], falloff = "25~95", frames = tier >= 3 })
	return ground
end

blocks.gouges = function(root, tier)
	-- three claw rends (groundRend, narrow): a carved crack under an amber slit
	-- and an amber seam that cools; the middle one kicks dust and chips
	local gouge = _G.vfxBlocks.groundRend(root, tier, {
		part = "Gouge", color = AMBER, core = coreOf(tier), ink = INK,
		width = { 1.2, 1.4, 1.6, 1.9 }, seam = { 0.18, 0.22, 0.26, 0.3 }, stations = { 2, 2, 3, 3 },
	})
	gouge:SetAttribute("Length", ({ 5, 6, 7.5, 9 })[tier])
	gouge:SetAttribute("Spread", 2.2) -- spacing of the claw lines (x0.6 studs off the middle)
	local B0 = _G.vfxBlocks
	if tier >= 2 then
		local path = B0.part(root, "GougePath", O * CFrame.new(0, 0.2, -5), V(2.4, 0.2, 7))
		B0.emitter(path, "Embers", {
			Texture = A.mote, Color = CS(coreOf(tier), AMBER),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
			Size = NS({ KP(0, 0.25), KP(0.5, 0.2), KP(1, 0) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.2), KP(1, 1) }),
			Lifetime = R(0.7, 1.1), Speed = R(1.5, 3), Drag = 1, LightEmission = 0.5, Rotation = R(0, 360),
		}, { EmitCount = ({ 0, 7, 10, 14 })[tier], EmitDelay = 0.1 })
	end
	return gouge
end

spec = {
	id = "RampagingTiger",
	variant = "A",
	root = { attrs = { AuthoredRadius = RADIUS } },
	blocks = blocks,
	beats = {
		{ block = "charge" },
		{ block = "edge" },
		{ block = "flare" },
		{ block = "claw" },
		{ block = "impact" },
		{ block = "launch" },
		{ block = "wheel" },
		{ block = "strike" },
		{ block = "slam" },
		{ block = "gouges" },
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

return spec
