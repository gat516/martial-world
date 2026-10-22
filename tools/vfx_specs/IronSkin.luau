--!nocheck
-- Iron Skin's templates (IronSkin_T1..T4) as a spec for vfxBlocks.buildFromSpec.
-- Runtime: src/client/TechniqueFX/IronSkin.luau. New in the 2026-10-21 technique
-- remake: it had no effects of its own (a Highlight and a burst of sparkles).
--
-- The move: Fists.1 (Hit 0.35, Hit Stop 0.5 on the source clip, played at 1.75x:
-- windup 0.20 s, active 0.086 s), a self buff: half damage for 4 s. The motif is
-- the Golden Bell (金钟罩): the body hardens into plated gold-bronze.
--   Windup (cast start -> Hit, caster only): qi streams into the chest ("Windup").
--   Release (Hit): a flash on the torso ("Body": star, glint, star-burst
--     flipbook over ink, sparks), a gold ground ring ("Ground", r 4) and a bell
--     shell, a gold sphere that snaps out round the body and settles ("Bell",
--     a MeshWave) with a thin ring.
--   Loop (the buff, `def.seconds`, "Aura", emitters moved onto the body):
--     plate glints flickering over the torso over dark soot flecks, gold motes
--     rising off the arms; II+ a shimmering shell part ("Shell", ForceField,
--     pulsing) hugging the body; III+ a rune seal turning under the feet;
--     IV a bell-ring halo over the head.
--   End ("Fade"): the plating lets go in a soft ring and gold dust.
-- Authored for a 4 s buff and a ground ring of radius 4.
local B = _G.vfxBlocks
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local V = Vector3.new
local O = CFrame.new()
local id = function(n)
	return "rbxassetid://" .. n
end

local GOLD = Color3.fromRGB(230, 190, 90) -- Techniques.IronSkin.color
local CORE = Color3.fromRGB(255, 246, 214)
local BRONZE = Color3.fromRGB(176, 118, 44)
local INK = Color3.fromRGB(44, 30, 14)
local PAL = {
	color = GOLD, core = CORE, ink = INK,
	ringColor = Color3.fromRGB(255, 232, 160), swirlColor = Color3.fromRGB(240, 200, 100), groundColor = Color3.fromRGB(240, 205, 120),
}
local A = {
	glint = id(13366348510), mote = id(9841260273), ink = id(16132530029), seal = id(83667248904000),
	ornate = id(13399941667), ring = id(9841273159),
}

local blocks = B.BLOCKS -- this spec's own blocks register next to the shared ones

-- the aura's emitters carry `Bone`: the runtime moves each onto that body part
local function bone(inst, name)
	inst:SetAttribute("Bone", name)
	return inst
end

blocks.isAura = function(root, tier)
	local aura = B.part(root, "Aura", O * CFrame.new(0, 3, 0), V(1, 1, 1))
	local function em(name, boneName, props)
		local e = B.emitter(aura, name, props)
		e.LockedToPart = props.LockedToPart or false
		return bone(e, boneName)
	end
	-- plate glints flickering over the torso, over dark soot flecks
	em("Soot", "Torso", {
		Texture = A.ink, Color = CS(INK), Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0.5), KP(1, 1.1) }), Transparency = NS({ KP(0, 0.6), KP(0.5, 0.75), KP(1, 1) }),
		Lifetime = R(0.5, 0.8), Speed = R(0.2, 0.8), LightEmission = 0, Rotation = R(0, 360), Rate = 5 + tier,
	})
	em("Plates", "Torso", {
		Texture = A.glint, Color = CS(CORE, GOLD), Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0), KP(0.4, 0.6 + tier * 0.1), KP(1, 0) }), Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
		Lifetime = R(0.25, 0.4), Speed = R(0, 0.5), LightEmission = 0.8, Rotation = R(-20, 20), Rate = 12 + tier * 3, ZOffset = 0.5,
	})
	for _, arm in { "Left Arm", "Right Arm" } do
		em("Gleam" .. arm:sub(1, 1), arm, {
			Texture = A.mote, Color = CS(CORE, GOLD), Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Size = NS({ KP(0, 0.28), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.1), KP(1, 1) }), Lifetime = R(0.5, 0.8), Speed = R(1, 2.5), LightEmission = 0.7, Rotation = R(0, 360), Rate = 4 + tier,
		})
	end
	if tier >= 2 then
		-- the shell: a ForceField ball that shimmers round the body (driven by the runtime)
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Shape = Enum.PartType.Ball
		shell.Material = Enum.Material.ForceField
		shell.Color = GOLD
		shell.Size = V(6.4, 7.6, 6.4)
		shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow = true, false, false, false, false
		shell.Transparency = 1
		shell:SetAttribute("Bone", "Torso")
		shell:SetAttribute("Show", 0.72)
		shell:SetAttribute("Pulse", 0.14)
		shell:SetAttribute("Offset", CFrame.new(0, -0.4, 0))
		shell.Parent = aura
	end
	if tier >= 3 then
		local seal = B.attach(aura, "SealAt", V(0, -2.9, 0), { Bone = "HumanoidRootPart" })
		B.emitter(seal, "Seal", B.flat({
			Texture = A.seal, Color = CS(GOLD), Size = NS({ KP(0, 3.4), KP(1, 4) }), Transparency = NS({ KP(0, 1), KP(0.15, 0.3), KP(0.8, 0.45), KP(1, 1) }),
			Lifetime = R(2), LightEmission = 0.5, RotSpeed = R(60), Rotation = R(0, 360), Rate = 0.5, LockedToPart = true,
		}))
	end
	if tier >= 4 then
		local halo = B.attach(aura, "HaloAt", V(0, 2.6, 0), { Bone = "Head" })
		B.emitter(halo, "Halo", B.flat({
			Texture = A.ornate, Color = CS(CORE, GOLD), Size = NS({ KP(0, 1.8), KP(1, 2.2) }), Transparency = NS({ KP(0, 1), KP(0.2, 0.3), KP(0.8, 0.5), KP(1, 1) }),
			Lifetime = R(1.5), LightEmission = 0.6, RotSpeed = R(-50), Rotation = R(0, 360), Rate = 0.7, LockedToPart = true,
		}))
	end
	return aura
end

-- the plating lets go
blocks.isFade = function(root, tier)
	local f = B.part(root, "Fade", O * CFrame.new(0, 3, 0))
	B.emitter(f, "Ring", {
		Texture = A.ring, Color = CS(GOLD), Size = NS({ KP(0, 1), KP(1, 5 + tier) }), Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
		Lifetime = R(0.4), LightEmission = 0.5, ZOffset = 1,
	}, { EmitCount = 1 })
	B.emitter(f, "Dust", {
		Texture = A.mote, Color = CS(CORE, GOLD), SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0.3), KP(1, 0) }),
		Transparency = NS({ KP(0, 0), KP(1, 1) }), Lifetime = R(0.5, 0.9), Speed = R(3, 7), Drag = 3, LightEmission = 0.6, Rotation = R(0, 360),
	}, { EmitCount = 8 + tier * 3 })
	return f
end

-- the bell: a gold shell snapping out round the body at the release
blocks.isBell = function(root, tier)
	local body = B.part(root, "Body", O * CFrame.new(0, 3, 0))
	local d = ({ 8, 9, 10, 11 })[tier]
	B.meshWave(body, "Bell", {
		mesh = "Ball", material = Enum.Material.ForceField, color = GOLD,
		fromSize = V(2, 2.4, 2), toSize = V(d * 0.8, d, d * 0.8), fromTransparency = 0.25, toTransparency = 1, duration = 0.45, style = "Quart",
	})
	B.meshWave(body, "BellRing", {
		mesh = B.ASSETS.torusMesh, color = Color3.fromRGB(255, 232, 160),
		fromSize = V(1.5, 0.2, 1.5), toSize = V(d * 0.9, d * 0.9 * 0.1, d * 0.9), fromOffset = V(0, -1.2, 0), toOffset = V(0, 0.4, 0),
		fromTransparency = 0.2, toTransparency = 1, duration = 0.4, style = "Quart", rotation = V(0, 0, 0),
	})
	return body
end

return {
	id = "IronSkin",
	root = { attrs = { AuthoredWindup = 0.2, AuthoredSeconds = 4, AuthoredRadius = 4 } },
	beats = {
		{ block = "handGather", params = { color = GOLD, core = CORE, windup = 0.2, at = O * CFrame.new(0, 3, -1.2), wisps = false } },
		{ block = "releaseFlash", params = { part = "Body", at = O * CFrame.new(0, 3, 0), color = GOLD, core = CORE, light = false } },
		{ block = "bladeFlare", params = { part = "Body", color = GOLD, core = CORE, ink = INK } },
		{ block = "isBell" },
		{ block = "groundShockwave", params = { radius = 4, color = GOLD, core = CORE, dust = true, rays = false } },
		{ block = "screenShake", params = { parent = "Body", magnitude = 0.6 } },
		{ block = "isAura" },
		{ block = "isFade" },
	},
}
