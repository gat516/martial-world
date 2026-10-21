--!nocheck
-- Builder for the world-ambience templates in ServerStorage.AmbientFX
-- (assets/AmbientFX.rbxm). Run this file through execute_luau in Edit mode; it
-- installs _G.buildAmbientFX(parent) which (re)builds every template under
-- `parent` (a staging folder, never the mapped one). Tune here and rebuild, then
-- export the staging folder with tools/export_rbxm.luau as "AmbientFX".
--
-- Every template is one invisible, anchored, non-colliding Part (the emission
-- volume): position/rotate/resize it to fit the spot. Night-only emitters carry
-- the NightFX tag plus DayScale/NightScale attributes (DayNight.luau scales them with night).
-- Lantern glows carry MountOffset: the flame's offset from the matching
-- ServerStorage._Templates FX_* model's pivot.

local CollectionService = game:GetService("CollectionService")

local A = {
	tinyDot = "rbxassetid://117230952319539", -- tiny droplet/ember dot
	orb = "rbxassetid://9841273544", -- soft glow orb (fireflies, spirit motes)
	glow = "rbxassetid://867619398", -- wide soft glow (halos)
	starGlow = "rbxassetid://1454292685", -- soft star glow (flame flicker core)
	glint = "rbxassetid://13271628051", -- 4-point star (water glints)
	fog = "rbxassetid://14265652323", -- soft fog patch
	wisp = "rbxassetid://9345352897", -- curling smoke wisp
	puff = "rbxassetid://13556798897", -- cloud puff (spray)
	splash = "rbxassetid://106562423542893", -- 4x4 splash flipbook
	ring = "rbxassetid://15611941586", -- soft ring (ripples)
	petals = "rbxassetid://90111316485044", -- 4x4 petal sheet
}
_G.AmbientAssets = A

local NS, NK = NumberSequence.new, NumberSequenceKeypoint.new
local CS, CK = ColorSequence.new, ColorSequenceKeypoint.new
local NR = NumberRange.new
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function seq(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, NK(p[1], p[2], p[3] or 0))
	end
	return NS(kps)
end

local function volume(name, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color or rgb(255, 255, 255)
	p.Locked = false
	return p
end

-- defaults for a soft ambient emitter; props override
local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Shape = Enum.ParticleEmitterShape.Box
	e.LightInfluence = 0
	e.LightEmission = 0
	e.Brightness = 1
	e.ZOffset = 0
	e.Rotation = NR(0, 360)
	e.RotSpeed = NR(0, 0)
	e.Drag = 0
	for k, v in props do
		if k ~= "night" and k ~= "emitCount" then
			e[k] = v
		end
	end
	if props.night then
		CollectionService:AddTag(e, "NightFX")
		e:SetAttribute("DayScale", props.night[1])
		e:SetAttribute("NightScale", props.night[2])
	end
	-- the plugin's Emit button (R) bursts this many
	e:SetAttribute("EmitCount", props.emitCount or math.max(1, math.floor(e.Rate * 2)))
	e.Parent = parent
	return e
end

local B = {}

-- 1. Fireflies and spirit motes over gardens and lawns. Size the part to the lawn
-- (bottom ~0.5 above the grass); counts below are for 24x5x24, scale Rate with area.
function B.Fireflies()
	local p = volume("Fireflies", Vector3.new(24, 5, 24))
	emitter(p, "Fireflies", {
		Texture = A.orb,
		Color = CS({ CK(0, rgb(232, 255, 110)), CK(1, rgb(255, 210, 90)) }),
		Size = seq({ { 0, 0.16, 0.03 }, { 0.5, 0.2, 0.04 }, { 1, 0.14, 0.03 } }),
		-- blink: on, dim, on, dim, out
		Transparency = seq({ { 0, 1 }, { 0.08, 0.05 }, { 0.22, 0.75 }, { 0.36, 0.05 }, { 0.55, 0.8 }, { 0.7, 0.1 }, { 0.88, 0.6 }, { 1, 1 } }),
		Lifetime = NR(5, 8),
		Rate = 3,
		Speed = NR(0.25, 0.7),
		SpreadAngle = Vector2.new(180, 180),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 0.06, 0),
		Drag = 0.15,
		LightEmission = 1,
		Brightness = 3,
		night = { 0, 1 },
	})
	emitter(p, "SpiritMotes", {
		Texture = A.orb,
		Color = CS(rgb(170, 255, 222)),
		Size = seq({ { 0, 0 }, { 0.2, 0.26, 0.06 }, { 0.8, 0.22, 0.05 }, { 1, 0 } }),
		Transparency = seq({ { 0, 1 }, { 0.25, 0.35 }, { 0.75, 0.45 }, { 1, 1 } }),
		Lifetime = NR(6, 9),
		Rate = 0.7,
		Speed = NR(0.1, 0.3),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 0.22, 0),
		LightEmission = 1,
		Brightness = 1.6,
		night = { 0.2, 1 },
	})
	return p
end

-- 2. Lantern flicker and halo, a companion for the FX_* lamps: pivot it on the
-- flame (lamp:GetPivot() * CFrame.new(glow:GetAttribute("MountOffset"))).
-- No light of its own; DayNight scales the lamps' own lights.
local function glow(name, mount, c, halo, opts)
	local p = volume(name, Vector3.new(0.6, 0.6, 0.6), c.core)
	p:SetAttribute("MountOffset", mount)
	emitter(p, "Halo", {
		Texture = A.glow,
		Color = CS(c.halo),
		Size = seq({ { 0, halo * 0.85, halo * 0.08 }, { 0.5, halo, halo * 0.1 }, { 1, halo * 0.9, halo * 0.08 } }),
		Transparency = seq({ { 0, 1 }, { 0.25, opts.haloAlpha }, { 0.75, opts.haloAlpha + 0.04 }, { 1, 1 } }),
		Lifetime = NR(0.7, 1.1),
		Rate = 4,
		Speed = NR(0, 0),
		LockedToPart = true,
		Rotation = NR(0, 0),
		LightEmission = 1,
		ZOffset = 0.6,
		night = { 0.3, 1 },
	})
	emitter(p, "Flicker", {
		Texture = A.starGlow,
		Color = CS(c.core),
		Size = seq({ { 0, opts.core * 0.8, opts.core * 0.25 }, { 1, opts.core, opts.core * 0.3 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.35, 0.2 }, { 1, 1 } }),
		Lifetime = NR(0.15, 0.32),
		Rate = 9,
		Speed = NR(0, 0),
		LockedToPart = true,
		LightEmission = 1,
		ZOffset = 0.8,
		night = { 0.6, 1 },
	})
	if opts.embers then
		emitter(p, "Embers", {
			Texture = A.tinyDot,
			Color = CS(c.ember),
			Size = seq({ { 0, 0.12, 0.03 }, { 1, 0 } }),
			Transparency = seq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
			Lifetime = NR(1.4, 2.4),
			Rate = opts.embers,
			Speed = NR(0.8, 1.8),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0.25, 0.5, 0.1),
			Drag = 0.4,
			LightEmission = 1,
			Brightness = 2,
		})
	end
	if opts.smoke then
		emitter(p, "Smoke", {
			Texture = A.wisp,
			Color = CS(rgb(150, 140, 136)),
			Size = seq({ { 0, 0.6 }, { 1, 2.4 } }),
			Transparency = seq({ { 0, 1 }, { 0.25, 0.9 }, { 1, 1 } }),
			Lifetime = NR(2.5, 3.5),
			Rate = opts.smoke,
			Speed = NR(1.5, 2.5),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0.3, 0, 0.1),
			RotSpeed = NR(-20, 20),
			LightInfluence = 1,
		})
	end
	return p
end

function B.LanternGlow()
	return glow("LanternGlow", Vector3.new(0, 4.37, 0), {
		core = rgb(255, 196, 110), halo = rgb(255, 128, 36), ember = rgb(255, 180, 90),
	}, 2.4, { haloAlpha = 0.6, core = 0.7, embers = 0.4 })
end

function B.JadeLampGlow()
	return glow("JadeLampGlow", Vector3.new(0, 8.1, 0), {
		core = rgb(200, 255, 228), halo = rgb(90, 240, 180), ember = rgb(160, 255, 210),
	}, 2.8, { haloAlpha = 0.68, core = 0.9 })
end

function B.BrazierGlow()
	return glow("BrazierGlow", Vector3.new(0, 5.1, 0), {
		core = rgb(255, 190, 100), halo = rgb(255, 120, 40), ember = rgb(255, 160, 70),
	}, 3.4, { haloAlpha = 0.74, core = 1.2, embers = 1.6, smoke = 0.5 })
end

-- 3. Low mist drifting along a cliff edge or the cloud-sea surface. The part's
-- front face (LookVector) is the drift direction; size it to the strip.
function B.MistWisps()
	local p = volume("MistWisps", Vector3.new(40, 3, 40))
	emitter(p, "Fog", {
		Texture = A.fog,
		Color = CS(rgb(232, 238, 250)),
		Size = seq({ { 0, 5, 1 }, { 1, 10, 2 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.62 }, { 0.7, 0.66 }, { 1, 1 } }),
		Lifetime = NR(12, 18),
		Rate = 0.8,
		Speed = NR(0.5, 1.1),
		SpreadAngle = Vector2.new(15, 4),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NR(-4, 4),
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		LightInfluence = 0.7,
		LightEmission = 0.2,
	})
	emitter(p, "Wisps", {
		Texture = A.wisp,
		Color = CS(rgb(240, 244, 255)),
		Size = seq({ { 0, 2.5, 0.5 }, { 1, 5, 1 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.6 }, { 0.7, 0.66 }, { 1, 1 } }),
		Lifetime = NR(7, 11),
		Rate = 0.5,
		Speed = NR(1, 1.8),
		SpreadAngle = Vector2.new(15, 4),
		EmissionDirection = Enum.NormalId.Front,
		RotSpeed = NR(-8, 8),
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		LightInfluence = 0.7,
		LightEmission = 0.2,
	})
	return p
end

-- 4a. Waterfall base: put the part flat on the plunge-pool surface where the
-- water lands, front face (LookVector) pointing away from the cliff.
function B.WaterfallSpray()
	local p = volume("WaterfallSpray", Vector3.new(10, 0.4, 5))
	emitter(p, "Spray", {
		Texture = A.puff,
		Color = CS(rgb(236, 246, 255)),
		Size = seq({ { 0, 1.5, 0.4 }, { 0.4, 4, 0.8 }, { 1, 6, 1 } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.55 }, { 0.6, 0.75 }, { 1, 1 } }),
		Lifetime = NR(1.8, 2.8),
		Rate = 5,
		Speed = NR(3, 6),
		SpreadAngle = Vector2.new(35, 25),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 0.6, 0),
		Drag = 1.2,
		RotSpeed = NR(-15, 15),
		LightInfluence = 0.9,
		LightEmission = 0.15,
	})
	emitter(p, "Splash", {
		Texture = A.splash,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = CS(rgb(240, 248, 255)),
		Size = seq({ { 0, 2.2, 0.6 }, { 1, 3, 0.6 } }),
		Transparency = seq({ { 0, 0.25 }, { 1, 0.4 } }),
		Lifetime = NR(0.8, 1.1),
		Rate = 3.5,
		Speed = NR(0, 0),
		Rotation = NR(-15, 15),
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		LightInfluence = 0.8,
		LightEmission = 0.25,
	})
	emitter(p, "Droplets", {
		Texture = A.tinyDot,
		Color = CS(rgb(230, 244, 255)),
		Size = seq({ { 0, 0.3, 0.08 }, { 1, 0.16 } }),
		Transparency = seq({ { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }),
		Lifetime = NR(0.6, 1),
		Rate = 12,
		Speed = NR(9, 15),
		SpreadAngle = Vector2.new(30, 20),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -40, 0),
		LightEmission = 0.6,
	})
	emitter(p, "Ripples", {
		Texture = A.ring,
		Color = CS(rgb(230, 245, 255)),
		Size = seq({ { 0, 0.8 }, { 1, 4.5 } }),
		Transparency = seq({ { 0, 1 }, { 0.12, 0.3 }, { 1, 1 } }),
		Lifetime = NR(1.6, 2.2),
		Rate = 1.4,
		Speed = NR(0.01, 0.01),
		Rotation = NR(0, 360),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		LightInfluence = 0.7,
		LightEmission = 0.3,
	})
	return p
end

-- 4b. Waterfall lip: a thin strip along the top edge where the water tips over,
-- front face (LookVector) pointing out over the drop.
function B.WaterfallLip()
	local p = volume("WaterfallLip", Vector3.new(8, 0.3, 1))
	emitter(p, "Spill", {
		Texture = A.tinyDot,
		Color = CS(rgb(232, 246, 255)),
		Size = seq({ { 0, 0.16, 0.04 }, { 1, 0.1 } }),
		Transparency = seq({ { 0, 0.2 }, { 0.8, 0.4 }, { 1, 1 } }),
		Lifetime = NR(0.5, 0.8),
		Rate = 7,
		Speed = NR(2.5, 4.5),
		SpreadAngle = Vector2.new(15, 15),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -30, 0),
		LightEmission = 0.5,
	})
	emitter(p, "LipMist", {
		Texture = A.fog,
		Color = CS(rgb(236, 244, 255)),
		Size = seq({ { 0, 1 }, { 1, 2.6 } }),
		Transparency = seq({ { 0, 1 }, { 0.25, 0.75 }, { 1, 1 } }),
		Lifetime = NR(1.5, 2.4),
		Rate = 1.6,
		Speed = NR(0.8, 1.6),
		SpreadAngle = Vector2.new(15, 10),
		EmissionDirection = Enum.NormalId.Front,
		Acceleration = Vector3.new(0, -2.5, 0),
		RotSpeed = NR(-10, 10),
		LightInfluence = 0.9,
		LightEmission = 0.1,
	})
	emitter(p, "Glints", {
		Texture = A.glint,
		Color = CS(rgb(220, 240, 255)),
		Size = seq({ { 0, 0 }, { 0.5, 0.35, 0.1 }, { 1, 0 } }),
		Transparency = NS(0.2),
		Lifetime = NR(0.3, 0.5),
		Rate = 1.2,
		Speed = NR(0, 0),
		Rotation = NR(0, 45),
		LightEmission = 1,
		Brightness = 1.5,
	})
	return p
end

-- 5. Falling petals (and leaves) under a flowering tree: a flat part at the
-- canopy's underside, about the canopy's footprint.
local function falling(name, colors)
	local p = volume(name, Vector3.new(14, 1, 14))
	emitter(p, "Petals", {
		Texture = A.petals,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Random,
		FlipbookFramerate = NR(0, 0),
		Color = colors,
		Size = seq({ { 0, 0.36, 0.08 }, { 1, 0.32, 0.08 } }),
		Transparency = seq({ { 0, 1 }, { 0.08, 0.05 }, { 0.85, 0.1 }, { 1, 1 } }),
		Lifetime = NR(7, 10),
		Rate = 2,
		Speed = NR(0.3, 0.8),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(0.45, -0.9, 0.2),
		Drag = 0.25,
		RotSpeed = NR(-90, 90),
		LightInfluence = 1,
		LightEmission = 0,
	})
	return p
end

function B.FallingPetals()
	return falling("FallingPetals", CS({ CK(0, rgb(255, 196, 214)), CK(1, rgb(255, 226, 234)) }))
end

function B.FallingLeaves()
	return falling("FallingLeaves", CS({ CK(0, rgb(190, 214, 110)), CK(1, rgb(240, 196, 92)) }))
end

_G.AmbientBuilders = B
_G.buildAmbientFX = function(parent)
	local order = { "Fireflies", "LanternGlow", "JadeLampGlow", "BrazierGlow", "MistWisps", "WaterfallSpray", "WaterfallLip", "FallingPetals", "FallingLeaves" }
	for _, name in order do
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		B[name]().Parent = parent
	end
	return order
end

return "installed _G.buildAmbientFX"
