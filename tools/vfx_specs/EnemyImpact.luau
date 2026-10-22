--!nocheck
-- Builder for ReplicatedStorage.Effects.EnemyImpact: the shared impact kit
-- every enemy's ground blows, landings, explosions, skids, roars and
-- projectiles layer on top of their own element effects (the "oomph" pass,
-- docs/systems/telegraphs.md, "Impact"). Load through the receiver, then build
-- into staging:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/EnemyImpact.luau")
--   require(m)  -- installs _G.buildEnemyImpactFX(effectsFolder)
-- Runtime: src/client/EnemyFX/Impact.luau (placement, scale, element colour,
-- distance shake).
--
-- Every template is an invisible Part. Ground templates have their centre on
-- the ground (code lifts them 0.15) and are authored at AuthoredRadius 10, so
-- code rescales them to the blow's radius; -Z is the blow's facing. Colours are
-- authored neutral: each emitter, trail and wave carries a `Role` attribute
-- (core, color, dark, dust, rock, cool) and code paints it from the element's
-- palette, so one kit serves storm, venom, foxfire and moonlight. Emit
-- attributes are on the emitters so the plugin's Emit button (R) plays each one
-- as the game does.
local AssetService = game:GetService("AssetService")

local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local id = function(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 150, 150)
local DARK = Color3.fromRGB(30, 30, 36)

local TEX = {
	dot = id(9841273544), -- hard round glow (flashes, cores)
	ring = id(16878073342), -- thin bright ring
	roughRing = id(15190419677), -- rough ring of wind strokes (shock front, roar rings)
	rays = id(6991254829), -- radial streak burst
	crater = id(90713203428310), -- dark crater ring with a pale lip
	starBurst = id(13272043107), -- white spiky starburst
	glint = id(13366348510), -- crisp 4-point star
	spindle = id(7814053668), -- thin spindle streak (sparks)
	ink = id(16132530029), -- black ink splat
	dust = id(11037785287), -- soft dust puff
	puff = id(11037784926), -- soft cloud puff
	smokeRing = id(13556798897), -- ring of smoke (dust ring round a crater)
	smokeSheet = id(124269383519639), -- 4x4 smoke puffs (a dust plume)
	chips = id(130042646554310), -- 2x2 rock chips (FlipbookMode Random)
	chip = id(425665059), -- small rock chips
	crackWeb = id(7994630128), -- dark branching crack web
	crackGlow = id(93520831389146), -- white crack web (tinted: burning crack)
	scorch = id(464840466), -- soft dark smoke (scorch)
	breath = id(15753663130), -- soft wisp
	-- flipbooks
	hitFlip = id(13580358178), -- 4x4 spiky star burst opening and breaking up
	splatFlip = id(12360899465), -- 4x4 blotch blowing out into a ragged ring
	smokeFlip = id(14200879082), -- 4x4 smoke burst
	flameFlip = id(81332883799807), -- 2x2 tall flame tongue
	-- meshes
	torus = 471124075, -- torus ring (MeshSize 150 x 9.51 x 150; lies flat)
}

local function anchor(name, size, parent, attrs)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Massless = true
	p.Transparency = 1
	p.Size = size
	p.CFrame = CFrame.new()
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

local function attach(parent, name, pos, attrs, tag)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	for k, v in attrs or {} do
		a:SetAttribute(k, v)
	end
	if tag then
		a:AddTag(tag)
	end
	a.Parent = parent
	return a
end

-- One emitter. `role` paints it at runtime; `attrs` are Emit attributes.
local function emitter(parent, name, role, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	e.Color = CS(if role == "dark" then DARK elseif role == "dust" or role == "rock" then GREY else WHITE)
	for k, v in props do
		e[k] = v
	end
	for k, v in attrs or { EmitCount = 1 } do
		e:SetAttribute(k, v)
	end
	e:SetAttribute("Role", role)
	e.Parent = parent
	return e
end

local flat = { -- lies on the ground, facing up
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
	Speed = R(0.01),
}
local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
end

local meshCache = {}
local function torus(parent, name, role, a)
	local wave = Instance.new("Model")
	wave.Name = name
	for k, v in a do
		wave:SetAttribute(k, v)
	end
	wave:SetAttribute("MeshWave", true)
	wave:SetAttribute("Role", role)
	local source = meshCache[TEX.torus]
	if not source then
		source = AssetService:CreateMeshPartAsync(id(TEX.torus))
		meshCache[TEX.torus] = source
	end
	local m = source:Clone()
	m.Name = "Mesh"
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
	m.Material = Enum.Material.Neon
	m.Color = WHITE
	m.Transparency = 1
	m.CFrame = CFrame.new()
	m.Parent = wave
	wave.Parent = parent
	return wave
end

local function trail(parent, name, role, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Enabled = false
	t.LightInfluence = 0
	t.FaceCamera = true
	for k, v in props do
		t[k] = v
	end
	t:SetAttribute("Role", role)
	t.Parent = parent
	return t
end

local RADIUS = 10 -- every ground template is authored at this radius

function _G.buildEnemyImpactFX(effects)
	local old = effects:FindFirstChild("EnemyImpact")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "EnemyImpact"

	-- Shock: the ground shockwave. A Neon torus snapping out to the radius and
	-- a slower, thinner echo; a bright thin front and a rough wind ring on the
	-- ground; radial rays at the centre; a dark crater under it all.
	do
		local p = anchor("Shock", Vector3.new(1, 0.2, 1), root, { AuthoredRadius = RADIUS })
		torus(p, "Wave", "core", {
			FromSize = Vector3.new(2, 0.4, 2), ToSize = Vector3.new(RADIUS * 2, 0.9, RADIUS * 2),
			FromTransparency = 0.2, ToTransparency = 1, Duration = 0.34, Style = "Quart", FadeStyle = "Linear",
			FromOffset = Vector3.new(0, 0.3, 0), ToOffset = Vector3.new(0, 0.3, 0),
		})
		torus(p, "Echo", "color", {
			FromSize = Vector3.new(3, 0.3, 3), ToSize = Vector3.new(RADIUS * 2.5, 0.6, RADIUS * 2.5),
			FromTransparency = 0.5, ToTransparency = 1, Duration = 0.6, Style = "Quad", EmitDelay = 0.06,
			FromOffset = Vector3.new(0, 0.2, 0), ToOffset = Vector3.new(0, 0.2, 0),
		})
		emitter(p, "Front", "core", with(flat, {
			Texture = TEX.ring,
			LightEmission = 1,
			Brightness = 3,
			Lifetime = R(0.32),
			Size = NS({ KP(0, 1), KP(0.4, RADIUS * 0.8), KP(1, RADIUS * 1.05) }),
			Transparency = NS({ KP(0, 0), KP(0.6, 0.2), KP(1, 1) }),
			ZOffset = 1,
		}))
		emitter(p, "Rough", "color", with(flat, {
			Texture = TEX.roughRing,
			LightEmission = 0.7,
			Lifetime = R(0.5),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 2), KP(0.35, RADIUS * 0.85), KP(1, RADIUS * 1.2) }),
			Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }),
			ZOffset = 0.8,
		}))
		emitter(p, "Rays", "core", with(flat, {
			Texture = TEX.rays,
			LightEmission = 1,
			Brightness = 2,
			Lifetime = R(0.22),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.25), KP(1, RADIUS * 0.75) }),
			Transparency = NS({ KP(0, 0), KP(1, 1) }),
			ZOffset = 1.2,
		}))
		emitter(p, "Base", "dark", with(flat, {
			Texture = TEX.crater,
			Lifetime = R(1.3),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.45), KP(0.15, RADIUS * 0.62), KP(1, RADIUS * 0.66) }),
			Transparency = NS({ KP(0, 0.05), KP(0.6, 0.25), KP(1, 1) }),
			ZOffset = -0.5,
		}))
	end

	-- Dust: kicked out along the ground and up. A skirt of puffs sprayed flat
	-- out, a smoke ring rolling out, a plume of flipbook smoke and tumbling
	-- rock chips.
	do
		local p = anchor("Dust", Vector3.new(1, 0.2, 1), root, { AuthoredRadius = RADIUS })
		-- ground-hugging spray all round: Front with SpreadAngle (5, 180), from
		-- an attachment lifted off the floor so the puffs don't clip flat
		local skirt = attach(p, "Skirt", Vector3.new(0, RADIUS * 0.22, 0))
		emitter(skirt, "Skirt", "dust", {
			Texture = TEX.dust,
			LightInfluence = 0.6,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(5, 180),
			Speed = R(RADIUS * 2.2, RADIUS * 3.2),
			Drag = 4,
			Acceleration = Vector3.new(0, 2, 0),
			Lifetime = R(0.7, 1.1),
			Rotation = R(0, 360),
			RotSpeed = R(-60, 60),
			Size = NS({ KP(0, RADIUS * 0.15), KP(1, RADIUS * 0.42) }),
			Transparency = NS({ KP(0, 0.25), KP(0.5, 0.45), KP(1, 1) }),
		}, { EmitCount = 16 })
		emitter(p, "Ring", "dust", with(flat, {
			Texture = TEX.smokeRing,
			LightInfluence = 0.5,
			Lifetime = R(0.9),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.35), KP(1, RADIUS * 1.15) }),
			Transparency = NS({ KP(0, 0.2), KP(0.6, 0.5), KP(1, 1) }),
		}))
		emitter(p, "Plume", "dust", {
			Texture = TEX.smokeSheet,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightInfluence = 0.6,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(35, 35),
			Speed = R(RADIUS * 0.6, RADIUS * 1.3),
			Drag = 2,
			Lifetime = R(1.0, 1.4),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.25), KP(1, RADIUS * 0.6) }),
			Transparency = NS({ KP(0, 0.2), KP(0.7, 0.45), KP(1, 1) }),
		}, { EmitCount = 5 })
		emitter(p, "Chips", "rock", {
			Texture = TEX.chips,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
			FlipbookMode = Enum.ParticleFlipbookMode.Random,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(50, 50),
			Speed = R(RADIUS * 1.8, RADIUS * 3),
			Acceleration = Vector3.new(0, -RADIUS * 7, 0),
			Lifetime = R(0.8, 1.1),
			Rotation = R(0, 360),
			RotSpeed = R(-360, 360),
			Size = NS({ KP(0, RADIUS * 0.07), KP(1, RADIUS * 0.05) }),
			Transparency = NS({ KP(0, 0), KP(0.85, 0), KP(1, 1) }),
		}, { EmitCount = 14 })
	end

	-- Contact: the flash where the blow lands (centre lifted ~1/4 radius). A
	-- white-hot dot, a spiky flipbook star, a crisp glint, sparks flying out,
	-- an ink splat behind for daylight contrast.
	do
		local p = anchor("Contact", Vector3.new(0.5, 0.5, 0.5), root, { AuthoredRadius = RADIUS })
		emitter(p, "Ink", "dark", {
			Texture = TEX.ink,
			Lifetime = R(0.28),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.3), KP(1, RADIUS * 0.55) }),
			Transparency = NS({ KP(0, 0.15), KP(0.6, 0.3), KP(1, 1) }),
			ZOffset = -1,
		})
		emitter(p, "Flash", "core", {
			Texture = TEX.dot,
			LightEmission = 1,
			Brightness = 5,
			Lifetime = R(0.12),
			Size = NS({ KP(0, RADIUS * 0.15), KP(0.3, RADIUS * 0.4), KP(1, RADIUS * 0.1) }),
			Transparency = NS({ KP(0, 0), KP(1, 1) }),
			ZOffset = 2,
		})
		emitter(p, "Star", "color", {
			Texture = TEX.hitFlip,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightEmission = 1,
			Brightness = 2,
			Lifetime = R(0.28),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.45), KP(1, RADIUS * 0.6) }),
			ZOffset = 1.5,
		})
		emitter(p, "Glint", "core", {
			Texture = TEX.glint,
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.18),
			Rotation = R(-15, 15),
			Size = NS({ KP(0, RADIUS * 0.15), KP(0.25, RADIUS * 0.55), KP(1, 0) }),
			ZOffset = 2.5,
		})
		emitter(p, "Sparks", "color", {
			Texture = TEX.spindle,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			LightEmission = 1,
			Brightness = 3,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(80, 80),
			Speed = R(RADIUS * 4, RADIUS * 7),
			Drag = 5,
			Acceleration = Vector3.new(0, -RADIUS * 4, 0),
			Lifetime = R(0.25, 0.45),
			Size = NS({ KP(0, RADIUS * 0.12), KP(1, 0) }),
			ZOffset = 1,
		}, { EmitCount = 14 })
	end

	-- Burst: the explosion body for landings and projectiles. A splat
	-- flipbook blowing out, flame tongues shooting up, a Neon shell, embers
	-- and a dark smoke tail that outlives it.
	do
		local p = anchor("Burst", Vector3.new(1, 0.2, 1), root, { AuthoredRadius = RADIUS })
		local body = attach(p, "Body", Vector3.new(0, RADIUS * 0.3, 0))
		emitter(body, "Blow", "color", {
			Texture = TEX.splatFlip,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightEmission = 0.8,
			Brightness = 2,
			Lifetime = R(0.45),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.45), KP(1, RADIUS * 0.85) }),
			ZOffset = 1,
		})
		emitter(p, "Flames", "color", {
			Texture = TEX.flameFlip,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightEmission = 1,
			Brightness = 2,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(30, 30),
			Speed = R(RADIUS * 1, RADIUS * 2),
			Drag = 3,
			Lifetime = R(0.4, 0.55),
			Size = NS({ KP(0, RADIUS * 0.3), KP(1, RADIUS * 0.5) }),
			Transparency = NS({ KP(0, 0), KP(0.7, 0.2), KP(1, 1) }),
			ZOffset = 0.5,
		}, { EmitCount = 6 })
		emitter(body, "Embers", "color", {
			Texture = TEX.dot,
			LightEmission = 1,
			Brightness = 3,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(70, 70),
			Speed = R(RADIUS * 2.5, RADIUS * 4.5),
			Drag = 2,
			Acceleration = Vector3.new(0, -RADIUS * 3, 0),
			Lifetime = R(0.6, 1.0),
			Size = NS({ KP(0, RADIUS * 0.05), KP(1, 0) }),
		}, { EmitCount = 16 })
		emitter(body, "Smoke", "dark", {
			Texture = TEX.smokeFlip,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightInfluence = 0.4,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(60, 60),
			Speed = R(RADIUS * 0.5, RADIUS * 1.1),
			Drag = 2,
			Acceleration = Vector3.new(0, RADIUS * 0.3, 0),
			Lifetime = R(1.2, 1.7),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.3), KP(1, RADIUS * 0.7) }),
			Transparency = NS({ KP(0, 0.15), KP(0.6, 0.4), KP(1, 1) }),
			ZOffset = -0.5,
		}, { EmitCount = 6, EmitDelay = 0.05 })
	end

	-- Scar: what the blow leaves on the ground, fading over ~3.5 s. A dark
	-- crack web, the same web burning in the element's colour and cooling to
	-- dark, a soft scorch, and a few wisps smouldering up.
	do
		local p = anchor("Scar", Vector3.new(1, 0.2, 1), root, { AuthoredRadius = RADIUS })
		emitter(p, "Scorch", "dark", with(flat, {
			Texture = TEX.scorch,
			Lifetime = R(3.5),
			Rotation = R(0, 360),
			Size = NS(RADIUS * 0.6),
			Transparency = NS({ KP(0, 0.35), KP(0.7, 0.5), KP(1, 1) }),
			ZOffset = -0.3,
		}))
		emitter(p, "Crack", "dark", with(flat, {
			Texture = TEX.crackWeb,
			Lifetime = R(3.5),
			Rotation = R(0, 360),
			Size = NS(RADIUS * 0.7),
			Transparency = NS({ KP(0, 0.05), KP(0.75, 0.2), KP(1, 1) }),
			ZOffset = 0,
		}))
		emitter(p, "Glow", "cool", with(flat, {
			Texture = TEX.crackGlow,
			LightEmission = 1,
			Brightness = 2,
			Lifetime = R(1.8),
			Rotation = R(0, 360),
			Size = NS(RADIUS * 0.62),
			Transparency = NS({ KP(0, 0), KP(0.5, 0.25), KP(1, 1) }),
			ZOffset = 0.2,
		}))
		emitter(p, "Smoulder", "dust", {
			Texture = TEX.puff,
			LightInfluence = 0.5,
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			Speed = R(RADIUS * 0.2, RADIUS * 0.4),
			Lifetime = R(1.4, 2.2),
			Rotation = R(0, 360),
			Size = NS({ KP(0, RADIUS * 0.12), KP(1, RADIUS * 0.3) }),
			Transparency = NS({ KP(0, 0.6), KP(1, 1) }),
		}, { EmitCount = 5, EmitDelay = 0.2 })
		p.Size = Vector3.new(RADIUS * 0.8, 0.2, RADIUS * 0.8) -- the Box shape spreads the wisps
	end

	-- Rocks: a Craters ring (Game Module only): stones erupt round the edge.
	do
		local p = anchor("Rocks", Vector3.new(1, 0.2, 1), root, { AuthoredRadius = RADIUS })
		attach(p, "RockRing", Vector3.zero, {
			Shape = "Ring", Fill = true, Radius = RADIUS * 0.75, Variance = 1.2, Count = 8, Duration = 0.25,
			EmissionStart = "Progressive", EmissionEnd = "Progressive",
			Size = Vector3.new(1.4, 1.0, 1.2), SizeScale = R(0.7, 1.2), SizeBias = 0.7,
			Lifetime = R(1.6, 2.2), SpawnTime = R(0.06, 0.1), DespawnTime = R(0.4, 0.6),
			AngleX = R(25, 50), AngleY = R(-20, 20), AngleZ = R(-10, 10),
			Collision = false, MatchGround = true, YOffset = 0.45, RaycastDistance = 12,
			UseMesh = true, MeshId = id(17608108317),
		}, "CraterVFX")
	end

	-- Roar (normal wolf howl, at the Mouth, -Z out of the jaws): sound rings
	-- (rough wind rings flying forward, facing along the howl, three staggered,
	-- with thin bright rings between), a breath wisp cone and spit motes.
	do
		local p = anchor("Roar", Vector3.new(0.4, 0.4, 0.4), root, { AuthoredSeconds = 0.6 })
		for i, delay in { 0, 0.14, 0.28 } do
			emitter(p, "Rings" .. i, "core", {
				Texture = TEX.roughRing,
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				EmissionDirection = Enum.NormalId.Front,
				LightEmission = 0.6,
				Speed = R(20),
				Drag = 1.5,
				Lifetime = R(0.42),
				Rotation = R(0, 360),
				Size = NS({ KP(0, 0.6), KP(1, 4.2) }),
				Transparency = NS({ KP(0, 0.05), KP(0.5, 0.35), KP(1, 1) }),
				ZOffset = 1,
			}, { EmitCount = 1, EmitDelay = delay })
			if i < 3 then
				emitter(p, "Thin" .. i, "color", {
					Texture = TEX.ring,
					Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
					EmissionDirection = Enum.NormalId.Front,
					LightEmission = 1,
					Speed = R(26),
					Drag = 1.5,
					Lifetime = R(0.32),
					Size = NS({ KP(0, 0.4), KP(1, 3.2) }),
					Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
					ZOffset = 1.2,
				}, { EmitCount = 1, EmitDelay = delay + 0.07 })
			end
		end
		emitter(p, "Breath", "core", {
			Texture = TEX.breath,
			EmissionDirection = Enum.NormalId.Front,
			LightEmission = 0.3,
			SpreadAngle = Vector2.new(16, 16),
			Speed = R(12, 20),
			Drag = 3,
			Lifetime = R(0.5, 0.7),
			Rotation = R(0, 360),
			RotSpeed = R(-90, 90),
			Size = NS({ KP(0, 0.5), KP(1, 2.6) }),
			Transparency = NS({ KP(0, 0.45), KP(1, 1) }),
		}, { EmitCount = 3, EmitDuration = 0.45 })
		local breath = p:FindFirstChild("Breath")
		breath.Rate = 18
		emitter(p, "Motes", "color", {
			Texture = TEX.dot,
			EmissionDirection = Enum.NormalId.Front,
			LightEmission = 1,
			Brightness = 2,
			SpreadAngle = Vector2.new(25, 25),
			Speed = R(16, 28),
			Drag = 3,
			Lifetime = R(0.3, 0.5),
			Size = NS({ KP(0, 0.12), KP(1, 0) }),
		}, { EmitCount = 10 })
	end

	-- RoarDust (the ground ahead of the head, -Z = the howl's facing): dust
	-- blown forward off the ground, grit, and a flattening dust ring.
	do
		local p = anchor("RoarDust", Vector3.new(1.5, 0.2, 1), root, { AuthoredSeconds = 0.6 })
		local lift = attach(p, "Lift", Vector3.new(0, 0.9, 0)) -- puffs clear the floor
		emitter(lift, "Kick", "dust", {
			Texture = TEX.dust,
			LightInfluence = 0.6,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(8, 35),
			Speed = R(12, 20),
			Drag = 3,
			Acceleration = Vector3.new(0, 3, 0),
			Lifetime = R(0.8, 1.1),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 0.6), KP(1, 2.4) }),
			Transparency = NS({ KP(0, 0.35), KP(0.6, 0.55), KP(1, 1) }),
		}, { EmitCount = 4, EmitDuration = 0.4 })
		lift:FindFirstChild("Kick").Rate = 22
		emitter(lift, "Grit", "rock", {
			Texture = TEX.chip,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(25, 30),
			Speed = R(10, 16),
			Acceleration = Vector3.new(0, -30, 0),
			Lifetime = R(0.5, 0.8),
			Rotation = R(0, 360),
			RotSpeed = R(-300, 300),
			Size = NS(0.18),
		}, { EmitCount = 7, EmitDelay = 0.05 })
		emitter(p, "Flatten", "dust", with(flat, {
			Texture = TEX.smokeRing,
			LightInfluence = 0.5,
			Lifetime = R(0.7),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 0.8), KP(1, 3.2) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
		}))
	end

	-- Skid (at a planted foot, -Z = the way the body was travelling): dust
	-- sprayed ahead and out, chips, a dark scuff and a low puff ring.
	do
		local p = anchor("Skid", Vector3.new(1, 0.2, 1), root, { AuthoredRadius = 1 })
		local lift = attach(p, "Lift", Vector3.new(0, 0.8, 0)) -- puffs clear the floor
		emitter(lift, "Spray", "dust", {
			Texture = TEX.dust,
			LightInfluence = 0.6,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(15, 55),
			Speed = R(14, 24),
			Drag = 4,
			Acceleration = Vector3.new(0, 4, 0),
			Lifetime = R(0.6, 0.9),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 0.9), KP(1, 2.8) }),
			Transparency = NS({ KP(0, 0.3), KP(0.6, 0.5), KP(1, 1) }),
		}, { EmitCount = 8 })
		emitter(lift, "Chips", "rock", {
			Texture = TEX.chips,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
			FlipbookMode = Enum.ParticleFlipbookMode.Random,
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(35, 45),
			Speed = R(14, 22),
			Acceleration = Vector3.new(0, -50, 0),
			Lifetime = R(0.5, 0.8),
			Rotation = R(0, 360),
			RotSpeed = R(-360, 360),
			Size = NS(0.4),
		}, { EmitCount = 6 })
		emitter(p, "Scuff", "dark", with(flat, {
			Texture = TEX.scorch,
			Lifetime = R(1.6),
			Rotation = R(0, 360),
			Size = NS(1.6),
			Transparency = NS({ KP(0, 0.45), KP(1, 1) }),
			ZOffset = -0.3,
		}))
		emitter(p, "Puff", "dust", with(flat, {
			Texture = TEX.smokeRing,
			LightInfluence = 0.5,
			Lifetime = R(0.6),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 0.6), KP(1, 2.6) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
		}))
	end

	-- Shot (rides a projectile, -Z = its velocity): the white-hot core over a
	-- dark contrast disc, an element halo, a flickering glint, a wide dark
	-- trail under a narrow bright one, and sparks shed behind. Authored for a
	-- 1-stud radius; code scales it to the shot.
	do
		local p = anchor("Shot", Vector3.new(0.4, 0.4, 0.4), root, { AuthoredRadius = 1 })
		emitter(p, "Dark", "dark", {
			Texture = TEX.dot,
			LockedToPart = true,
			Lifetime = R(0.1),
			Size = NS(2.2),
			Transparency = NS(0.45),
			ZOffset = -1,
		}, { EmitDuration = -1 })
		emitter(p, "Halo", "color", {
			Texture = TEX.dot,
			LockedToPart = true,
			LightEmission = 1,
			Brightness = 2,
			Lifetime = R(0.08, 0.12),
			Size = NS({ KP(0, 1.5), KP(1, 1.8) }),
			Transparency = NS({ KP(0, 0.15), KP(1, 0.6) }),
			ZOffset = 0.5,
		}, { EmitDuration = -1 })
		emitter(p, "Core", "core", {
			Texture = TEX.dot,
			LockedToPart = true,
			LightEmission = 1,
			Brightness = 3,
			Lifetime = R(0.06, 0.09),
			Size = NS(0.65),
			ZOffset = 1,
		}, { EmitDuration = -1 })
		emitter(p, "Glint", "core", {
			Texture = TEX.glint,
			LockedToPart = true,
			LightEmission = 1,
			Brightness = 2,
			Lifetime = R(0.08, 0.14),
			Rotation = R(0, 360),
			Size = NS({ KP(0, 1.3), KP(1, 0.5) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
			ZOffset = 1.5,
		}, { EmitDuration = -1 })
		emitter(p, "Shed", "color", {
			Texture = TEX.spindle,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(30, 30),
			Speed = R(3, 7),
			Lifetime = R(0.25, 0.4),
			Size = NS({ KP(0, 0.35), KP(1, 0) }),
		}, { EmitDuration = -1 })
		p.Dark.Rate, p.Halo.Rate, p.Core.Rate, p.Glint.Rate, p.Shed.Rate = 30, 40, 50, 12, 30
		local d0 = attach(p, "D0", Vector3.new(0, 1.1, 0))
		local d1 = attach(p, "D1", Vector3.new(0, -1.1, 0))
		local b0 = attach(p, "B0", Vector3.new(0, 0.45, 0))
		local b1 = attach(p, "B1", Vector3.new(0, -0.45, 0))
		trail(p, "DarkTrail", "dark", d0, d1, {
			Lifetime = 0.28,
			MinLength = 0.05,
			Color = CS(DARK),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			WidthScale = NS({ KP(0, 1), KP(1, 0.2) }),
		})
		trail(p, "BrightTrail", "color", b0, b1, {
			Lifetime = 0.18,
			MinLength = 0.05,
			LightEmission = 1,
			Brightness = 3,
			Color = CS(WHITE),
			Transparency = NS({ KP(0, 0), KP(1, 1) }),
			WidthScale = NS({ KP(0, 1), KP(1, 0) }),
		})
	end

	root.Parent = effects
	return root
end

return true
