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
-- THE SHOT ("a tiger's claws"): tawny amber qi with a white-gold core and
-- black brush-ink stripes; every cut leaves three claw strokes in the air.
--   Windup (caster only): amber motes and a glow gather into the right hand.
--   Blade edge: the saber draws its arcs as an amber ribbon (Trail on the
--     weapon), on for the cut, the spin and the landing; II+ afterimage.
--   Cut (hit 1): three parallel claw strokes (Beams, amber over ink) flash
--     along the diagonal in front; each enemy in the circle gets an impact.
--   Leap: a torus and dust ring at the take-off.
--   Spin (spin hits): the blade's wheel draws itself; II+ a spinning amber
--     swirl ring stands in the blade's circle at the right side and turns
--     with it (III+ a second, counter-turning ForceField ring); each spin hit
--     flashes vertical claw strokes and impacts.
--   Landing (last hit): a flash where the blade bites, three claw gouges torn
--     into the ground ahead (Neon slits cooling to ink scars), a torus
--     shockwave to r 10 around the caster with a dust skirt, "roar" rings
--     thrown forward off the strike (1/1/2/3), heavy impacts timed by the
--     front. III+ Craters rock ring, cracks, rock kicks; IV a giant claw
--     standing over the strike, a swirl shell, the one PointLight, impact
--     frames and an Explosion quake.
--   Aftermath: the gouges cool over ~1-2 s, embers drift up (II+).
-- Remade 2026-10-21 on the saber (weapon models, Hit windows): the windup is a
-- `Charge` along the dadao's Base -> Tip (not a hand gather), each cut and the
-- landing flare on the live blade tip (`Flare`: cross glint, star-burst
-- flipbook over an ink splat, sparks) as the Hit marker fires, and the
-- landing's heavy impacts are squeezed into Hit 4 -> Hit Stop 4.
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

local RADIUS = 10
local HAND_AT = O * CFrame.new(-1.2, 3.6, -0.6) -- the right hand drawn up to the left shoulder

local A = {
	crack = id(93520831389146),
	crackSmall = id(97725700315217),
	spindle = id(7814053668),
	mote = id(9841260273),
	dust = id(11037785287),
	hitRing = id(13052235894),
	torus = id(471124075),
	swirl = id(129778117978668),
	swirl2 = id(73349240058321),
	swirlRing = id(122217820569960),
	glint = id(13366348510), -- crisp 4-point star
	hitFlip = id(13580358178), -- 4x4 flipbook: a spiky star burst opening and breaking up
	ink = id(16132530029), -- black ink splat
}
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
	B0.emitter(f, "Ink", {
		Texture = A.ink, Color = CS(INK),
		Size = NS({ KP(0, 1), KP(0.25, 2.2 + tier * 0.3), KP(1, 2.8 + tier * 0.3) }), Transparency = NS({ KP(0, 0.2), KP(0.6, 0.45), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0, Rotation = R(0, 360), ZOffset = 0.8,
	}, { EmitCount = 1 })
	B0.emitter(f, "Burst", {
		Texture = A.hitFlip, Color = CS(coreOf(tier), AMBER),
		FlipbookLayout = GRID4, FlipbookMode = ONESHOT,
		Size = NS({ KP(0, 1.8 + tier * 0.25), KP(1, 2.8 + tier * 0.35) }), Transparency = NS({ KP(0, 0.1), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.28), LightEmission = 0.6, Rotation = R(0, 360), ZOffset = 1.4,
	}, { EmitCount = 1 })
	B0.emitter(f, "Glint", {
		Texture = A.glint, Color = CS(coreOf(tier)),
		Size = NS({ KP(0, 0.4), KP(0.25, 2 + tier * 0.35), KP(1, 0) }), Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
		Lifetime = R(0.28), LightEmission = 0.85, Rotation = R(-12, 12), ZOffset = 2,
	}, { EmitCount = 1 })
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
	part:SetAttribute("GiantScale", 2.4)
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
		mesh = A.torus, color = Color3.fromRGB(240, 135, 45),
		fromSize = V(1.4, 0.2, 1.4), toSize = V(5.5 + tier, 0.5 + tier * 0.06, 5.5 + tier),
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

-- II+: the wheel the spinning blade cuts; the runtime stands it in the blade's
-- circle at the right side, sizes it to the reach and spins it
blocks.wheel = function(root, tier)
	local B0 = _G.vfxBlocks
	local K = KIT_()
	local holder = B0.part(root, "Wheel", O * CFrame.new(1.2, 3, -0.6))
	holder:SetAttribute("Spin", ({ 0, 900, 1000, 1150 })[tier]) -- deg/s
	holder:SetAttribute("StartTransparency", ({ 0, 0.4, 0.3, 0.2 })[tier])
	K.heldWave(holder, "Ring", { mesh = A.swirl2, color = N_AMBER })
	if tier >= 3 then
		K.heldWave(holder, "Counter", { mesh = A.swirl, color = AMBER, material = Enum.Material.ForceField })
	end
	B0.emitter(holder, "Embers", {
		Texture = A.mote, Color = CS(coreOf(tier), AMBER),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0.25), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.35, 0.6), Speed = R(3, 7), Drag = 2, LightEmission = 0.55, Rotation = R(0, 360),
		Rate = ({ 0, 16, 24, 32 })[tier],
	})
	return holder
end

blocks.strike = function(root, tier)
	local B0 = _G.vfxBlocks
	local q = pal(coreOf(tier))
	q.part, q.at, q.light = "Strike", O * CFrame.new(0.5, 0.4, -2.6), false
	local part = B0.releaseFlash(root, tier, q)
	B0.emitter(part, "Splash", B0.flat({
		Texture = A.hitRing, Color = CS(AMBER),
		Size = NS({ KP(0, 0.4), KP(1, 2 + tier * 0.45) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }),
		Lifetime = R(0.24), LightEmission = 0.45, Rotation = R(0, 360), ZOffset = 0.5,
	}), { EmitCount = 1 })
	-- the roar: rings thrown forward off the landing cut, low over the ground
	local roar = B0.part(root, "Roar", O * CFrame.new(0.3, 1.4, -2.2))
	local qa = pal(coreOf(tier))
	qa.part, qa.color = "Roar", Color3.fromRGB(255, 214, 160)
	qa.size, qa.travel, qa.duration = ({ 3.6, 4.4, 5.6, 7 })[tier], 5 + tier * 1.4, 0.34
	B0.airShockwave(root, tier, qa)
	return part
end

blocks.slam = function(root, tier)
	local B0 = _G.vfxBlocks
	local q = pal(coreOf(tier))
	q.part, q.radius, q.lifetime = "Slam", RADIUS, 0.32
	local ground = B0.groundShockwave(root, tier, q)
	local gw = ground:FindFirstChild("GroundWave")
	gw:SetAttribute("Duration", 0.46)
	gw:SetAttribute("FromTransparency", 0.32)
	gw:SetAttribute("FadeStyle", "Quint")
	gw.Mesh.Color = Color3.fromRGB(240, 130, 40)
	if tier >= 3 then
		B0.craterRing(root, tier, { parent = "Slam", attrs = {
			Radius = RADIUS * 0.7, Count = ({ 0, 0, 8, 12 })[tier], Duration = 0.3,
		} })
		B0.emitter(ground, "Cracks", B0.flat({
			Texture = A.crack, Color = CS(INK), LightInfluence = 0.3,
			Size = NS(({ 0, 0, 5, 6.5 })[tier]), Transparency = NS({ KP(0, 1), KP(0.04, 0.15), KP(0.65, 0.3), KP(1, 1) }),
			Lifetime = R(1.6), Rotation = R(0, 360), ZOffset = -0.4,
		}), { EmitCount = 1 })
	end
	if tier >= 4 then
		B0.shockwaveShell(root, tier, {
			name = "Shell", mesh = A.swirl, from = V(3, 0.8, 3), to = V(RADIUS * 2.1, 2.2, RADIUS * 2.1),
			startColor = N_PALE, endColor = AMBER, y0 = 0.6, y1 = 1.1, spin = 160, duration = 0.45, startTransparency = 0.35,
		})
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = AMBER
		light.Range = 22
		light.Brightness = 0
		light.Shadows = false
		light.Parent = ground
	end
	B0.screenShake(root, tier, { parent = "Slam", magnitude = ({ 1.2, 1.7, 2.3, 3.0 })[tier], falloff = "25~95", frames = tier >= 4 })
	return ground
end

blocks.gouges = function(root, tier)
	local K = KIT_()
	K.strips(root, tier, {
		name = "Gouge", scar = "GougeScar", color = Color3.fromRGB(255, 160, 60), fadeColor = N_AMBER, ink = INK,
		width = { { 0.34, 0.7 }, { 0.38, 0.8 }, { 0.44, 0.9 }, { 0.5, 1.0 } },
		fade = { 0.45, 0.55, 0.7, 0.85 }, scarFade = { 1.0, 1.3, 1.6, 2.0 },
	})
	local gouge = root:FindFirstChild("Gouge")
	gouge:SetAttribute("Length", ({ 5, 6, 7.5, 9 })[tier])
	gouge:SetAttribute("Spread", 1.0) -- studs between the claw lines
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

local spec = {
	id = "RampagingTiger",
	root = { attrs = { AuthoredRadius = RADIUS } },
	blocks = blocks,
	beats = {
		{ block = "charge" },
		{ block = "edge" },
		{ block = "flare" },
		{ block = "claw" },
		{ block = "impact" },
		{ block = "launch" },
		{ block = "wheel", from = 2 },
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
