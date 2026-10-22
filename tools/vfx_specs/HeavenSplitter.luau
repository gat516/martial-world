--!nocheck
-- Heaven-Splitting Descent's templates (HeavenSplitter_T1..T4). Build with
-- HeavenSplitter.build(parent) (its own blocks first, then vfxBlocks').
-- Runtime: src/client/TechniqueFX/HeavenSplitter.luau (+ BladeSkill.luau).
--
-- The move (Greatsword, anim 90109091413405, 3.67 s, castSpeed ~1.3; clip
-- seconds below, real = clip / castSpeed). Sampled on gsrigrea2lfixed:
--   0.00-0.20  the blade swings back to the right, low.
--   0.45-0.60  the LOW SWEEP: the tip skims the ground across the whole front,
--              right to left. (The def's first hit is 0.18-0.37, by body
--              speed; the blade actually crosses the front at 0.45-0.58.)
--   0.60-1.00  crouch, blade held low-left behind, torso drives forward.
--   1.05-1.25  the RISING CUT: low front -> straight up overhead; the body
--              launches (up 3.8 by 1.7) - the "launch" hit 1.02-1.22.
--   1.25-2.10  airborne, blade raised behind the head, hands at y+6.
--   2.10-2.25  the SLAM: the blade falls from behind the head and strikes the
--              ground ahead (2.22-2.25); the body lands in a deep crouch.
--   2.25-2.65  held in the ground; recovery to 3.0.
-- Gameplay: hits { 0.18 light, 1.02 light, 2.12 slam }, lunge 6, circle r 12
-- centred 4 ahead of the landing.
--
-- THE SHOT ("the sky splits and the blade comes down through it"),
-- palette: heaven-azure qi (Neon parts deeper), white core, ink scars;
-- mastery adds a gold core.
--   Windup (cast start -> first hit, caster only): a glint and motes gather
--     on the right hand.
--   Blade edge (all three cuts): the held greatsword draws its own arc as a
--     solid azure ribbon (Trail on the weapon's Base -> Tip), on for each swing
--     window; II+ a faint afterimage ribbon.
--   Light hits (sweep, launch): each enemy in the circle gets a light impact
--     (star flash, spiky ring, a small standing torus and ground shock).
--   Launch (launch hit): a torus and dust ring kick out at the feet; II+ swirl
--     rings rise up the body like an updraft; III+ upward streaks.
--   Airborne (1.25 -> slam): the blade is wreathed in qi (Glow beam + motes
--     shed); III+ a rune seal opens on the ground over the landing circle
--     (faint, it marks r 12) and a vertical rift tears open in the sky above
--     it; IV a giant phantom blade forms over the real one and follows it down.
--   Slam (last hit, at the swing's contact inside Hit 3 -> Hit Stop 3): a
--     star flash where the blade bites the ground, a rend splits the ground
--     from there through the circle (groundRend: a carved crack under an azure
--     slit and a burning qi seam that cools, dust and chips kicked up as it
--     opens), a torus shockwave rolls out to r 12 with a dust skirt; each
--     enemy gets a heavy impact as the front reaches it. II+ a pillar of light
--     drops onto the bite, an echo torus, rays; III+ Craters rock ring,
--     crater and cracks, rock kicks; IV a dome shell, the one PointLight,
--     impact frames and an Explosion quake.
--   Remade 2026-10-21 on the greatsword and the clip's markers: the windup is a
--     `Charge` along the Base -> Tip (not a hand gather), every Hit marker flares
--     on the live blade tip (`Flare`, 1.5x at the slam), and the slam's heavy
--     impacts are squeezed into Hit 3 -> Hit Stop 3.
--   QA pass 2026-10-21: flares, light impacts and the slam fire at each swing's
--     peak inside its Hit window (WeaponFX.swing; the markers fire with the
--     blade still raised), the bite is where the point lands (~9 ahead), the
--     Neon fissure is replaced by the rend, III+ impact frames, a harder
--     shake and a hit-pause punch (CombatEffects.punch) at II+.
--   Aftermath: the rend cools for ~1-2 s, motes rise from it (II+), the
--     dust settles; the phantom (IV) dissolves where it bit.
local KIT_ = function()
	return _G.vfxSpecs.BladeKit
end
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local AZURE = Color3.fromRGB(128, 156, 255) -- suggested def.color
local CORE = Color3.fromRGB(236, 242, 255)
local GOLD = Color3.fromRGB(255, 232, 170) -- mastery core
local INK = Color3.fromRGB(22, 24, 48)
local N_AZURE = Color3.fromRGB(78, 108, 240) -- Neon blooms, so parts go deeper
local N_PALE = Color3.fromRGB(150, 175, 255)
local DUST = Color3.fromRGB(214, 210, 200)

local RADIUS, OFFSET = 12, 4
local CENTRE = O * CFrame.new(0, 0.2, -OFFSET)
local HAND_AT = O * CFrame.new(1.1, 2.2, -0.9)

local A = {
	seal = id(83667248904000),
	ornate = id(13399941667),
	crater = id(90713203428310),
	crack = id(93520831389146),
	crackSmall = id(97725700315217),
	spindle = id(7814053668),
	mote = id(9841260273),
	glow = id(867619398),
	dust = id(11037785287),
	hitRing = id(13052235894),
	torus = id(471124075),
	swirl = id(129778117978668),
	swirl2 = id(73349240058321),
	dome = id(13567208057),
}

local function pal(core)
	return {
		color = AZURE, core = core or CORE,
		ringColor = Color3.fromRGB(120, 150, 255), swirlColor = Color3.fromRGB(110, 140, 255), groundColor = Color3.fromRGB(105, 135, 250),
	}
end
local function coreOf(tier)
	return if tier >= 4 then GOLD else CORE
end

local blocks = {}

-- anticipation along the greatsword (Base -> Tip), played at cast start; the
-- hand gather below is only the fallback for a missing weapon rig
blocks.charge = function(root, tier)
	return _G.vfxBlocks.bladeCharge(root, tier, { color = AZURE, core = coreOf(tier), ink = INK, width = 0.6 })
end

-- the flare on the live blade tip as each Hit marker fires (1.5x at the slam)
blocks.flare = function(root, tier)
	return _G.vfxBlocks.bladeFlare(root, tier, { color = AZURE, core = coreOf(tier), ink = INK })
end


blocks.edge = function(root, tier)
	return KIT_().edge(root, tier, { color = AZURE, core = coreOf(tier), tail = N_PALE, trailLife = { 0.18, 0.22, 0.26, 0.32 }, glowWidth = { 0.35, 0.45, 0.55, 0.7 } })
end

-- the light hits (sweep and launch): a smaller impact stack
blocks.lightImpact = function(root, tier)
	local B0 = _G.vfxBlocks
	local q = pal(coreOf(tier))
	q.part = "LightImpact"
	B0.impactBurst(root, tier, q)
	q.size = ({ 2.6, 3.1, 3.6, 4.2 })[tier]
	q.groundSize = ({ 2.8, 3.3, 3.8, 4.4 })[tier]
	q.swirl, q.bubble = false, false
	q.duration = 0.24
	B0.impactShockwave(root, tier, q)
	return root:FindFirstChild("LightImpact")
end

-- the take-off at the feet (launch hit)
blocks.launch = function(root, tier)
	local B0 = _G.vfxBlocks
	local part = B0.part(root, "Launch", O * CFrame.new(0, 0.2, 0))
	B0.meshWave(part, "LaunchRing", {
		mesh = A.torus, color = Color3.fromRGB(110, 140, 255),
		fromSize = V(1.6, 0.2, 1.6), toSize = V(7 + tier, 0.55 + tier * 0.08, 7 + tier),
		fromOffset = V(0, 0.15, 0), toOffset = V(0, 0.15, 0),
		fromTransparency = 0.3, toTransparency = 1, duration = 0.4, style = "Quart",
	}):SetAttribute("FadeStyle", "Quint")
	B0.emitter(part, "Dust", {
		Texture = A.dust, Color = CS(DUST), LightInfluence = 0.5,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(5, 180),
		Size = NS({ KP(0, 0.8), KP(1, 2.2) }), Transparency = NS({ KP(0, 0.35), KP(0.5, 0.55), KP(1, 1) }),
		Lifetime = R(0.45, 0.7), Speed = R(16, 22), Drag = 4, Rotation = R(0, 360), RotSpeed = R(-60, 60),
	}, { EmitCount = ({ 6, 8, 10, 12 })[tier] })
	if tier >= 2 then
		-- swirl rings rising up the body: the updraft that carries the leap
		for i = 1, ({ 0, 2, 2, 3 })[tier] do
			local w = B0.meshWave(part, "Updraft" .. i, {
				mesh = A.swirl, color = N_PALE,
				fromSize = V(2.4, 0.3, 2.4), toSize = V(4.2 - i * 0.4, 0.9, 4.2 - i * 0.4),
				fromOffset = V(0, 0.6, 0), toOffset = V(0, 6 + i * 0.8, 0),
				fromTransparency = 0.25, toTransparency = 1, duration = 0.42, style = "Quad",
				delay = (i - 1) * 0.07,
			})
			w:SetAttribute("FadeStyle", "Quint")
		end
	end
	if tier >= 3 then
		B0.emitter(part, "Streaks", {
			Texture = A.spindle, Color = CS(coreOf(tier), AZURE), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(6, 6),
			Size = NS({ KP(0, 0.3), KP(1, 0) }), Squash = NS(2.5), Transparency = NS({ KP(0, 0), KP(1, 0.6) }),
			Lifetime = R(0.25, 0.4), Speed = R(26, 34), Drag = 3, LightEmission = 0.5,
		}, { EmitCount = ({ 0, 0, 6, 9 })[tier] })
	end
	return part
end

-- III+: the rune seal over the landing circle while airborne (held long and
-- faint: it marks r 12 without hiding any ground warning)
blocks.mark = function(root, tier)
	local B0 = _G.vfxBlocks
	local part = B0.part(root, "Mark", CENTRE)
	part:SetAttribute("AuthoredAir", 0.67)
	B0.emitter(part, "Seal", B0.flat({
		Texture = A.seal, Color = CS(AZURE), LightEmission = 0.35,
		Size = NS({ KP(0, RADIUS * 1.0), KP(0.4, RADIUS * 1.45), KP(1, RADIUS * 1.5) }),
		Transparency = NS({ KP(0, 1), KP(0.15, 0.4), KP(0.85, 0.3), KP(1, 1) }),
		Lifetime = R(0.67), RotSpeed = R(28), Rotation = R(0, 360), ZOffset = 0.2,
	}), { EmitCount = 1 })
	if tier >= 4 then
		B0.emitter(part, "Halo", B0.flat({
			Texture = A.ornate, Color = CS(GOLD), LightEmission = 0.4,
			Size = NS({ KP(0, RADIUS * 0.5), KP(0.5, RADIUS * 0.85), KP(1, RADIUS * 0.9) }),
			Transparency = NS({ KP(0, 1), KP(0.15, 0.4), KP(0.85, 0.3), KP(1, 1) }),
			Lifetime = R(0.67), RotSpeed = R(-40), Rotation = R(0, 360), ZOffset = 0.3,
		}), { EmitCount = 1 })
	end
	return part
end

-- III+: a vertical rift torn in the sky above the landing (two tapered Beams,
-- widened by the runtime while airborne), shedding sparks downward
blocks.rift = function(root, tier)
	local B0 = _G.vfxBlocks
	local h = ({ 0, 0, 14, 18 })[tier]
	local part = B0.part(root, "Rift", CENTRE * CFrame.new(0, 6 + h / 2, 0))
	part:SetAttribute("Width", ({ 0, 0, 1.1, 1.5 })[tier])
	local top = B0.attach(part, "Top", V(0, h / 2, 0))
	local mid = B0.attach(part, "Mid", V(0, 0, 0))
	local bottom = B0.attach(part, "Bottom", V(0, -h / 2, 0))
	for i, pair in { { top, mid, 0, 1 }, { mid, bottom, 1, 0 } } do
		for layer, look in { Core = { coreOf(tier), 0, 0.5, 0.6 }, Glow = { AZURE, 0.35, 2.6, 0.4 } } do
			local b = Instance.new("Beam")
			b.Name = layer .. (if i == 1 then "Upper" else "Lower")
			b.Attachment0, b.Attachment1 = pair[1], pair[2]
			b.Width0, b.Width1 = 0, 0 -- the runtime opens it: Width * look[3] at Mid
			b:SetAttribute("Scale", look[3])
			b.FaceCamera = true
			b.Color = CS(look[1])
			b.Transparency = NS(look[2])
			b.LightEmission, b.LightInfluence = look[4], 0
			b.Segments = 2
			b.Enabled = false
			b.Parent = part
		end
	end
	B0.emitter(part, "Sparks", {
		Texture = A.spindle, Color = CS(coreOf(tier), AZURE), Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(10, 10),
		Size = NS({ KP(0, 0.25), KP(1, 0) }), Squash = NS(2), Transparency = NS({ KP(0, 0.1), KP(1, 0.8) }),
		Lifetime = R(0.3, 0.5), Speed = R(10, 18), LightEmission = 0.5, Rate = ({ 0, 0, 14, 22 })[tier],
	})
	part.Size = V(0.4, h * 0.6, 0.4)
	return part
end

-- IV (III fainter): a giant phantom blade the runtime lays over the real one
-- from the top of the leap down into the ground
blocks.phantom = function(root, tier)
	local B0 = _G.vfxBlocks
	local K = KIT_()
	local holder = B0.part(root, "Phantom", O * CFrame.new(0, 6, 2))
	holder:SetAttribute("Length", ({ 0, 0, 11, 14 })[tier]) -- studs, base to tip
	holder:SetAttribute("Width", ({ 0, 0, 1.6, 2.1 })[tier])
	holder:SetAttribute("StartTransparency", ({ 0, 0, 0.55, 0.25 })[tier])
	holder:SetAttribute("Hold", 0.25)
	holder:SetAttribute("Fade", 0.5)
	-- blade body (Neon at IV, ForceField at III) plus a ForceField aura; the
	-- tip is a wedge. Sizes are per stud of Length/Width, set at runtime.
	K.heldWave(holder, "Body", { color = if tier >= 4 then N_AZURE else N_PALE, material = if tier >= 4 then Enum.Material.Neon else Enum.Material.ForceField })
	K.heldWave(holder, "Aura", { color = AZURE, material = Enum.Material.ForceField })
	local _, tip = K.heldWave(holder, "Tip", { color = if tier >= 4 then N_AZURE else N_PALE, material = if tier >= 4 then Enum.Material.Neon else Enum.Material.ForceField })
	-- swap the Tip's block for a wedge
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Mesh"
	wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CanTouch, wedge.CastShadow = true, false, false, false, false
	wedge.Material, wedge.Color, wedge.Transparency = tip.Material, tip.Color, 1
	wedge.Parent = tip.Parent
	tip:Destroy()
	return holder
end

-- the bite: where the blade strikes the ground
blocks.strike = function(root, tier)
	local B0 = _G.vfxBlocks
	local q = pal(coreOf(tier))
	q.part, q.at, q.light = "Strike", O * CFrame.new(0.4, 0.4, -3), false
	local part = B0.releaseFlash(root, tier, q)
	B0.emitter(part, "Splash", B0.flat({
		Texture = A.hitRing, Color = CS(AZURE),
		Size = NS({ KP(0, 0.5), KP(1, 2.4 + tier * 0.5) }), Transparency = NS({ KP(0, 0), KP(0.6, 0.3), KP(1, 1) }),
		Lifetime = R(0.25), LightEmission = 0.45, Rotation = R(0, 360), ZOffset = 0.5,
	}), { EmitCount = 1 })
	if tier >= 2 then
		-- the pillar of light from the rift, down onto the blade's bite
		KIT_().cylinderWave(part, "Pillar", {
			color = N_AZURE, fromSize = V(30, ({ 0, 2.6, 3.2, 3.8 })[tier], ({ 0, 2.6, 3.2, 3.8 })[tier]), toSize = V(30, 0.3, 0.3),
			fromOffset = V(0, 14.6, 0), toOffset = V(0, 14.6, 0),
			fromTransparency = 0.3, toTransparency = 1, duration = ({ 0, 0.32, 0.38, 0.45 })[tier], style = "Quad", fadeStyle = "Quint",
		})
	end
	B0.emitter(part, "Chips", {
		Texture = A.dust, Color = CS(DUST), LightInfluence = 0.5,
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
		Size = NS({ KP(0, 0.7), KP(1, 1.8) }), Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
		Lifetime = R(0.4, 0.65), Speed = R(9, 15), Drag = 4, Rotation = R(0, 360),
	}, { EmitCount = 3 + tier })
	return part
end

-- the slam's ground wave and everything that rolls out with it
blocks.slam = function(root, tier)
	local B0 = _G.vfxBlocks
	local q = pal(coreOf(tier))
	q.part, q.radius, q.lifetime = "Slam", RADIUS, 0.36
	local ground = B0.groundShockwave(root, tier, q)
	ground.CFrame = CENTRE
	-- the main torus a little bolder and slower for the showpiece
	local gw = ground:FindFirstChild("GroundWave")
	gw:SetAttribute("Duration", 0.5)
	gw:SetAttribute("FromTransparency", 0.3)
	gw:SetAttribute("FadeStyle", "Quint")
	gw:SetAttribute("ToSize", V(RADIUS * 2, 2.2 + tier * 0.25, RADIUS * 2))
	gw.Mesh.Color = Color3.fromRGB(105, 135, 255)
	if tier >= 2 then
		B0.meshWave(ground, "EchoWave", {
			mesh = A.torus, color = N_AZURE,
			fromSize = V(1.5, 0.2, 1.5), toSize = V(RADIUS * 1.7, 1.2, RADIUS * 1.7),
			fromOffset = V(0, 0.25, 0), toOffset = V(0, 0.25, 0),
			fromTransparency = 0.45, toTransparency = 1, duration = 0.55, style = "Quart", delay = 0.08,
		}):SetAttribute("FadeStyle", "Quint")
	end
	if tier >= 3 then
		B0.craterRing(root, tier, { parent = "Slam", attrs = {
			Radius = RADIUS * 0.75, Count = ({ 0, 0, 10, 14 })[tier], Duration = 0.36,
			Size = V(1.5, 1.1, 1.3), Lifetime = R(1.4, 1.8),
		} })
		B0.emitter(ground, "Crater", B0.flat({
			Texture = A.crater, Color = CS(Color3.fromRGB(56, 52, 70)), LightInfluence = 0.4,
			Size = NS(({ 0, 0, 3.6, 4.6 })[tier]), Transparency = NS({ KP(0, 1), KP(0.04, 0.2), KP(0.7, 0.35), KP(1, 1) }),
			Lifetime = R(1.8), Rotation = R(0, 360), ZOffset = -0.3,
		}), { EmitCount = 1 })
		B0.emitter(ground, "Cracks", B0.flat({
			Texture = A.crack, Color = CS(INK), LightInfluence = 0.3,
			Size = NS(({ 0, 0, 6.5, 8.5 })[tier]), Transparency = NS({ KP(0, 1), KP(0.04, 0.15), KP(0.65, 0.3), KP(1, 1) }),
			Lifetime = R(1.9), Rotation = R(0, 360), ZOffset = -0.4,
		}), { EmitCount = 1 })
	end
	if tier >= 4 then
		local shell = B0.shockwaveShell(root, tier, {
			name = "Dome", mesh = A.dome, from = V(4, 1.5, 4), to = V(RADIUS * 2.1, 7, RADIUS * 2.1),
			startColor = N_PALE, endColor = AZURE, y0 = 0.2, y1 = 0.2, spin = 40, duration = 0.5, startTransparency = 0.45,
		})
		shell:PivotTo(CENTRE)
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = AZURE
		light.Range = 26
		light.Brightness = 0 -- the runtime flashes it
		light.Shadows = false
		light.Parent = ground
	end
	B0.screenShake(root, tier, { parent = "Slam", magnitude = ({ 1.4, 2.2, 3.4, 4.6 })[tier], falloff = "30~110", frames = tier >= 3 })
	return ground
end

-- the rend the blade splits into the ground, from the bite on through the
-- circle (BladeSkill.rend): a black branching crack carved under a jagged
-- slit tinted azure, a seam of azure qi streaks burning in it and cooling to
-- ink, dust puffs and falling rock chips as it opens, a crack-web flash at the
-- bite; II+ glowing star cracks along it and motes rising; III+ a wider web of
-- cracks and Craters rock kicks
blocks.rend = function(root, tier)
	return _G.vfxBlocks.groundRend(root, tier, {
		color = AZURE, core = coreOf(tier), ink = INK,
		width = { 3, 3.5, 4.1, 4.8 }, seam = { 0.32, 0.4, 0.48, 0.58 }, stations = { 3, 3, 4, 5 },
	})
end

-- the slam's heavy impact on each enemy
blocks.impact = function(root, tier)
	local q = pal(coreOf(tier))
	local wave = pal(coreOf(tier))
	wave.size = ({ 4.2, 5.2, 6.4, 7.8 })[tier]
	wave.groundSize = ({ 4.4, 5.4, 6.8, 8.4 })[tier]
	return _G.vfxBlocks.impactStack(root, tier, { burst = q, wave = wave })
end

local spec = {
	id = "HeavenSplitter",
	root = { attrs = { AuthoredRadius = RADIUS, AuthoredOffset = OFFSET, RendOpen = 0.18 } },
	blocks = blocks,
	beats = {
		{ block = "charge" },
		{ block = "edge" },
		{ block = "flare" },
		{ block = "lightImpact" },
		{ block = "launch" },
		{ block = "mark", from = 3 },
		{ block = "rift", from = 3 },
		{ block = "phantom", from = 3 },
		{ block = "strike" },
		{ block = "slam" },
		{ block = "rend" },
		{ block = "impact" },
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
