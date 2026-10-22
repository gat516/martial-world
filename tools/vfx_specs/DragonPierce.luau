--!nocheck
-- Dragon-Piercing Thrust's templates (DragonPierce_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Runtime: src/client/TechniqueFX/DragonPierce.luau.
--
-- The move: Animations.Techniques.DragonPierce (0.8 s, Spear, joint Hilt),
-- markers Hit 0.30 / Hit Stop 0.40 with Lunge start/end on the same frames
-- (the caster lunges def.lunge, 8 studs, through the active window); the line
-- is 22 x 4 from where the caster is at Hit. Sampled on SpearRig: 0-0.30 the torso pulls back 1.5 and the spear
-- is drawn back along the right side (tip out to the right at 0.30, ~3.9
-- studs off the ground); 0.30-0.40 both hands drive it round and forward,
-- the tip sweeping from the right to straight ahead (7.6 studs out at 0.40)
-- and holding there.
--
-- The pitch ("a red-tasselled dragon bursts out of the spear point"):
--   Windup (cast start -> Hit, part "Windup" on the right hand): crimson qi
--     spirals into the hands as the spear is drawn back (II+ Spline wisps,
--     III+ a closing seal).
--   Release (Hit, part "Tip" where the lance starts on the line, at the spear
--     point's height; the point itself is still out to the side at Hit): a gold-white
--     star and glow, a spinning crimson vortex disc facing forward, a train of
--     swirl rings punched down the line, a shake.
--   Travel (Hit -> ~0.18 s, part "Lance", runtime-driven): a drill of crimson
--     qi (a twisted spiral-cone mesh) shoots from the point to the line's end,
--     a gold core Beam and a wide crimson glow Beam ride with it, and sonic
--     swirl rings burst at intervals as the front passes (3D MeshWaves).
--     II+ a coiling dragon helix wraps the lance; III+ a second, counter-wound.
--   Impact (each enemy as the front reaches it, part "Impact"): a crimson
--     impactStack (star, spiky ring, sparks, standing torus facing the thrust,
--     ground shock) plus a spray of sparks punched out of its far side.
--   Terminal (the line's end or the first wall, part "Terminal"): the lance
--     bursts: a bigger impactStack, a vortex disc, III+ a Craters ring, IV a quake.
--   Aftermath: a straight dark furrow along the line ("Furrow"), dust thrown
--     to both sides along it and gold motes rising (II+, "Path").
--
-- Tiers:
--   I   drill + core/glow beams, 2 rings along the line, release flash and
--       1 air ring, impacts, terminal burst, furrow.
--   II  3 rings, the dragon helix, release sparks, impact swirl, path dust
--       and motes.
--   III 4 rings, a counter-wound second helix, 2 air rings, impact bubble and
--       rock kicks, terminal Craters ring, path cracks.
--   IV  5 rings, gold-white core, 3 air rings, the dragon seal flashing at
--       the release with impact frames, one point light on the lance head,
--       a quake on the terminal burst.
--
-- Remade 2026-10-21 on the spear and the Hit window: the 0.3 s windup is a
-- `Charge` along the whole spear (butt -> head, WeaponFX.charge full: a dark
-- beam under a crimson one, motes along the shaft, a glint on the head), the
-- release on the live spear head gets the shared flare (cross glint,
-- star-burst flipbook over ink, sparks), the lance has an ink beam under its
-- glow, and the front crosses the line in 0.12 s with every impact squeezed
-- into the thrust's Hit 0.30 -> Hit Stop 0.40 window.
-- Authored along -Z at length 22, width 4.
local B = _G.vfxBlocks
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local CRIMSON = Color3.fromRGB(232, 66, 70) -- the technique colour (suggested def.color)
local DEEP = Color3.fromRGB(196, 34, 52)
local CORE = Color3.fromRGB(255, 238, 206)
local GOLD = Color3.fromRGB(255, 204, 112)
local INK = Color3.fromRGB(58, 22, 26)
local PALETTE = {
	color = CRIMSON, core = CORE,
	ringColor = Color3.fromRGB(255, 196, 170), swirlColor = Color3.fromRGB(240, 90, 90), groundColor = Color3.fromRGB(255, 170, 140),
}
local function pal(extra)
	local t = table.clone(PALETTE)
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

local A = {
	vortex = id(6700005265), -- swirl disc
	seal = id(132774975653552), -- seal-script glyph (dragon seal)
	mote = id(9841260273),
	crackSmall = id(97725700315217),
	drillMesh = id(117701979506507), -- twisted spiral cone (2 x 2 x 2, axis Y, wide end +Y)
	helixMesh = id(903178515), -- helix spring (50 x 72 x 50, axis Y)
}

local LENGTH = 22
local HEIGHT = 3.2
local TIP_AT = O * CFrame.new(0.4, HEIGHT, -3) -- the spear point at Hit; runtime puts it on the live tip
local LANCE_AT = O * CFrame.new(0, HEIGHT, -3)
local TERMINAL_AT = O * CFrame.new(0, 0.15, -LENGTH)

-- The lance: a part at the lance's start facing the line, holding MeshWaves
-- the runtime stretches to the actual length (Stretch = true: Size.Y and the
-- offsets' Z scale with it) and the Beams it drives.
B.BLOCKS.dpLance = function(root, tier, p)
	local run = LENGTH - 3
	local lance = B.part(root, "Lance", LANCE_AT, Vector3.new(0.4, 0.4, run))
	for k, v in {
		Run = run, Height = HEIGHT,
		TravelTime = 0.12, -- seconds for the front to reach the end: inside the thrust's Hit -> Hit Stop (0.1 s) plus a frame or two
		TravelCurve = NS({ KP(0, 0), KP(0.3, 0.5), KP(0.6, 0.82), KP(1, 1) }),
		Hold = 0.16, Fade = 0.28, -- beams hold at full length, then fade
		Rings = ({ 2, 3, 4, 5 })[tier],
	} do
		lance:SetAttribute(k, v)
	end
	local core = if tier >= 4 then CORE else Color3.fromRGB(255, 226, 190)
	-- the drill: narrow end forward (Rotation 90,0,0 turns +Y to +Z, back
	-- toward the spear), grows from the point out to the full run
	local dw = ({ 2.2, 2.6, 3, 3.4 })[tier]
	local drill = B.meshWave(lance, "Drill", {
		mesh = A.drillMesh, color = CRIMSON,
		fromSize = Vector3.new(dw * 0.5, 1, dw * 0.5), toSize = Vector3.new(dw, run, dw),
		fromOffset = Vector3.new(0, 0, -0.5), toOffset = Vector3.new(0, 0, -run / 2),
		rotation = Vector3.new(90, 0, 0), fromTransparency = 0.15, toTransparency = 1,
		duration = 0.42, style = "Quint",
	})
	drill:SetAttribute("Stretch", true)
	drill:SetAttribute("FadeStyle", "Quart")
	-- the inner bright drill
	local inner = B.meshWave(lance, "DrillCore", {
		mesh = A.drillMesh, color = core,
		fromSize = Vector3.new(0.4, 1, 0.4), toSize = Vector3.new(dw * 0.4, run * 1.02, dw * 0.4),
		fromOffset = Vector3.new(0, 0, -0.5), toOffset = Vector3.new(0, 0, -run * 0.51),
		rotation = Vector3.new(90, 0, 0), fromTransparency = 0, toTransparency = 1,
		duration = 0.34, style = "Quint",
	})
	inner:SetAttribute("Stretch", true)
	inner:SetAttribute("FadeStyle", "Quart")
	-- the dragon helix coiled round the lance (II+), III+ counter-wound
	if tier >= 2 then
		local hd = ({ 0, 3.2, 3.6, 4.2 })[tier]
		for i = 1, (if tier >= 3 then 2 else 1) do
			local h = B.meshWave(lance, if i == 1 then "Helix" else "Helix2", {
				mesh = A.helixMesh, color = if i == 1 then GOLD else DEEP,
				fromSize = Vector3.new(hd * 0.4, 1, hd * 0.4), toSize = Vector3.new(hd, run, hd),
				fromOffset = Vector3.new(0, 0, -0.5), toOffset = Vector3.new(0, 0, -run / 2),
				rotation = Vector3.new(90, if i == 1 then 0 else 180, 0), fromTransparency = 0.1, toTransparency = 1,
				duration = 0.48, style = "Quint", delay = (i - 1) * 0.03,
			})
			h:SetAttribute("Stretch", true)
			h:SetAttribute("FadeStyle", "Quart")
		end
	end
	-- beams from the start to the front (the runtime moves Front)
	local a0 = B.attach(lance, "Start", Vector3.zero)
	local a1 = B.attach(lance, "Front", Vector3.new(0, 0, -run))
	local function beam(name, w0, w1, color, transparency, light)
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = w0, w1
		b.FaceCamera = true
		b.Color = CS(color)
		b.LightEmission, b.LightInfluence = light, 0
		b.Transparency = NS({ KP(0, transparency + (1 - transparency) * 0.5), KP(0.2, transparency), KP(1, transparency) })
		b.Segments = 10
		b.Enabled = false
		b.Parent = lance
	end
	beam("Ink", 1.4, ({ 3.2, 3.6, 4, 4.6 })[tier], INK, 0.45, 0) -- dark under light: the lance reads on grass at noon
	beam("Core", 0.35, ({ 0.6, 0.7, 0.8, 0.95 })[tier], core, 0, 0.5)
	beam("Glow", 1.2, ({ 2.4, 2.8, 3.2, 3.8 })[tier], CRIMSON, 0.45, 0.35)
	-- the lance head: a hot point riding the front
	local head = B.attach(lance, "Head", Vector3.new(0, 0, -run))
	local headGlow = B.emitter(head, "HeadGlow", {
		Texture = B.ASSETS.glow, Color = CS(CORE, CRIMSON),
		Size = NS({ KP(0, 1.6 + tier * 0.3), KP(1, 0.8) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.12), LightEmission = 0.6, Rate = 60, LockedToPart = false,
	})
	headGlow:SetAttribute("Shed", true)
	local sparks = B.emitter(head, "HeadSparks", {
		Texture = B.ASSETS.spindle, Color = CS(CORE, GOLD), Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Back, SpreadAngle = Vector2.new(25, 25),
		Size = NS({ KP(0, 0.2), KP(1, 0) }), Squash = NS({ KP(0, 2), KP(1, 1) }), Transparency = NS(0),
		Lifetime = R(0.15, 0.25), Speed = R(12, 20), Drag = 6, LightEmission = 0.6,
		Rate = ({ 40, 55, 70, 90 })[tier],
	})
	sparks:SetAttribute("Shed", true)
	if tier >= 4 then
		local light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = CRIMSON
		light.Range = 16
		light.Brightness = 0
		light.Shadows = false
		light.Parent = head
	end
	-- sonic rings standing across the line, spaced along it; the runtime
	-- moves each to its station and delays it to when the front passes
	local rd = ({ 3.6, 4.2, 4.8, 5.6 })[tier]
	for i = 1, ({ 2, 3, 4, 5 })[tier] do
		local ring = B.meshWave(lance, "Ring" .. i, {
			mesh = B.ASSETS.swirlMesh, color = PALETTE.ringColor,
			fromSize = Vector3.new(0.8, 0.3, 0.8), toSize = Vector3.new(rd * (1 - i * 0.05), 0.8, rd * (1 - i * 0.05)),
			fromOffset = Vector3.new(0, 0, -run * i / (({ 2, 3, 4, 5 })[tier] + 1)),
			toOffset = Vector3.new(0, 0, -run * i / (({ 2, 3, 4, 5 })[tier] + 1) - 1.2),
			rotation = Vector3.new(90, 0, 0), fromTransparency = 0.25, toTransparency = 1,
			duration = 0.32, style = "Quad",
		})
		ring:SetAttribute("Station", i / (({ 2, 3, 4, 5 })[tier] + 1)) -- fraction along the run
	end
	return lance
end

-- The release at the spear point: star, glow, a vortex disc facing forward.
B.BLOCKS.dpRelease = function(root, tier, p)
	local tip = B.part(root, "Tip", TIP_AT)
	B.emitter(tip, "Vortex", B.flat({
		Texture = A.vortex, Color = CS(CORE, CRIMSON),
		Size = NS({ KP(0, 0.6), KP(0.35, 2 + tier * 0.4), KP(1, 2.6 + tier * 0.45) }), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.25), KP(1, 1) }),
		Lifetime = R(0.3), LightEmission = 0.5, Rotation = R(0, 360), RotSpeed = R(-540), ZOffset = 1,
	}, Enum.NormalId.Front), { EmitCount = 1 })
	if tier >= 4 then
		-- the dragon seal flaring in front of the point
		B.emitter(tip, "Seal", B.flat({
			Texture = A.seal, Color = CS(GOLD),
			Size = NS({ KP(0, 1.5), KP(0.25, 3.4), KP(1, 4) }), Transparency = NS({ KP(0, 0.4), KP(0.25, 0.05), KP(0.7, 0.25), KP(1, 1) }),
			Lifetime = R(0.5), LightEmission = 0.45, ZOffset = 1.5,
		}, Enum.NormalId.Front), { EmitCount = 1 })
		B.screenShake(root, tier, { parent = "Tip", name = "Frames", shake = false, framesName = "TipFrames", frames = true })
	end
	return tip
end

B.BLOCKS.dpShake = function(root, tier, p)
	return B.screenShake(root, tier, { parent = "Tip", magnitude = ({ 0.9, 1.2, 1.6, 2.1 })[tier] })
end

-- A spray of sparks punched out of each target's far side (the pierce).
B.BLOCKS.dpThrough = function(root, tier, p)
	local impact = root:FindFirstChild(p.part or "Impact")
	local body = impact:FindFirstChild("Body")
	return B.emitter(body, "Through", {
		Texture = B.ASSETS.spindle, Color = CS(CORE, CRIMSON), Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Front, SpreadAngle = Vector2.new(18, 18),
		Size = NS({ KP(0, 0.35), KP(1, 0) }), Squash = NS({ KP(0, 2.5), KP(1, 1) }), Transparency = NS(0),
		Lifetime = R(0.18, 0.32), Speed = R(40, 60), Drag = 6, LightEmission = 0.6, ZOffset = 2,
	}, { EmitCount = ({ 8, 10, 12, 16 })[tier] })
end

B.BLOCKS.dpImpact = function(root, tier, p)
	local wave = pal({ size = ({ 3.6, 4.4, 5.4, 6.4 })[tier], groundSize = ({ 3.6, 4.4, 5.4, 6.6 })[tier] })
	return B.impactStack(root, tier, { burst = pal(), wave = wave })
end

B.BLOCKS.dpTerminal = function(root, tier, p)
	local q = pal({ part = "Terminal", at = TERMINAL_AT })
	B.impactBurst(root, tier, q)
	q.size = ({ 4.8, 6, 7.4, 9.2 })[tier]
	q.groundSize = ({ 5.2, 6.6, 8.2, 10.5 })[tier]
	q.bubble = tier >= 3
	B.impactShockwave(root, tier, q)
	local term = root:FindFirstChild("Terminal")
	B.emitter(term.Body, "Vortex", B.flat({
		Texture = A.vortex, Color = CS(CORE, CRIMSON),
		Size = NS({ KP(0, 1), KP(0.35, 2.6 + tier * 0.5), KP(1, 3.2 + tier * 0.5) }), Transparency = NS({ KP(0, 0.05), KP(0.6, 0.3), KP(1, 1) }),
		Lifetime = R(0.36), LightEmission = 0.5, Rotation = R(0, 360), RotSpeed = R(-480), ZOffset = 2,
	}, Enum.NormalId.Back), { EmitCount = 1 })
	if tier >= 3 then
		B.craterRing(root, tier, { parent = "Terminal", name = "Crater", attrs = {
			Count = ({ 0, 0, 6, 9 })[tier], Radius = ({ 0, 0, 2.2, 2.8 })[tier], Variance = 0.7, Duration = 0.12,
			Size = Vector3.new(1, 0.75, 0.9), Lifetime = R(1.1, 1.4), RaycastDistance = 8,
		} })
	end
	if tier >= 4 then
		B.screenShake(root, tier, { parent = "Terminal", name = "Quake", preset = "Explosion", falloff = "20~80" })
	end
	return term
end

-- The furrow along the line and what's thrown off it.
B.BLOCKS.dpPath = function(root, tier, p)
	local furrow = B.part(root, "Furrow", O * CFrame.new(0, 0.03, -LENGTH / 2), Vector3.new(({ 0.6, 0.7, 0.8, 0.95 })[tier], 0.06, LENGTH))
	furrow.Material, furrow.Color = Enum.Material.SmoothPlastic, INK
	furrow:SetAttribute("StartTransparency", 0.35)
	furrow:SetAttribute("Fade", ({ 0.9, 1.1, 1.4, 1.8 })[tier])
	furrow:SetAttribute("FadeDelay", 0.35)
	local path = B.part(root, "Path", O * CFrame.new(0, 0.2, -LENGTH / 2), Vector3.new(1.5, 0.2, LENGTH))
	if tier >= 2 then
		B.emitter(path, "Dust", {
			Texture = B.ASSETS.dust, Color = CS(B.COLORS.dust), LightInfluence = 0.5,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(20, 180),
			Size = NS({ KP(0, 0.7), KP(1, 1.7) }), Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			Lifetime = R(0.4, 0.6), Speed = R(8, 14), Drag = 5, Rotation = R(0, 360),
		}, { EmitCount = ({ 0, 8, 11, 14 })[tier], EmitDelay = 0.05 })
		B.emitter(path, "Motes", {
			Texture = A.mote, Color = CS(CORE, GOLD),
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

local HAND_AT = O * CFrame.new(1.4, 3.2, 1.2) -- the right hand drawn back

return {
	id = "DragonPierce",
	root = { attrs = { AuthoredActive = 0.1, AuthoredLength = LENGTH, AuthoredWidth = 4 } },
	beats = {
		{ block = "bladeCharge", params = { color = CRIMSON, core = CORE, ink = INK, width = 0.5, full = true } },
		{ block = "dpRelease" },
		{ block = "bladeFlare", params = { part = "Tip", color = CRIMSON, core = CORE, ink = INK } },
		{ block = "releaseFlash", params = pal({ part = "Tip", at = TIP_AT, light = false }) },
		{ block = "airShockwave", params = pal({ part = "Tip", at = TIP_AT, color = PALETTE.ringColor, travel = nil }) },
		{ block = "dpShake" },
		{ block = "dpLance" },
		{ block = "dpPath" },
		{ block = "dpImpact" },
		{ block = "dpThrough" },
		{ block = "dpTerminal" },
	},
}
