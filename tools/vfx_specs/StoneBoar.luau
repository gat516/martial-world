--!nocheck
-- Builder for ReplicatedStorage.Effects.StoneBoar: the Stone Boar's attack,
-- hit and death effects (an enemy, so no tiers and no buildFromSpec). Load
-- through the receiver, then build into the Effects folder:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/StoneBoar.luau")
--   require(m)  -- installs _G.buildStoneBoarFX(effectsFolder)
-- Runtime: src/client/EnemyFX/StoneBoar.luau (cue -> template, placement).
--
-- Earth qi: amber (#FF8A2B) core with a white-hot centre, umber dust
-- (#7E5D45), grey stone chips (#8F8B80), and a dark slate copy under every
-- bright shape so it reads on grass at noon. A ring-1 charger: every beat is
-- 2 to 6 layers, one-shot, short-lived.
--
-- Every template is an invisible Part (pivot = its centre, -Z = the boar's
-- facing or the blow's direction). Ground templates sit with their centre on
-- the ground. Emit attributes (EmitCount, EmitDelay, EmitDuration) are on the
-- emitters so the plugin's Emit button (R) plays each one as the game does.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local id = function(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local HOT = Color3.fromRGB(255, 214, 160) -- white-hot amber centre
local AMBER = Color3.fromRGB(255, 138, 43)
local UMBER = Color3.fromRGB(126, 93, 69)
local DUST = Color3.fromRGB(168, 140, 112) -- umber lifted for the soft puffs
local STONE = Color3.fromRGB(143, 139, 128)
local SLATE = Color3.fromRGB(44, 46, 52)
local BONE = Color3.fromRGB(246, 238, 220)

local TEX = {
	glint = id(84223532517124), -- crisp 4-point star glint
	dot = id(9841273544), -- hard round glow (flashes, motes, sparks)
	mote = id(8238126392), -- small soft dot
	hook = id(13366366767), -- double crescent sweep (the tusk hook)
	arc = id(14322954718), -- soft single crescent (hook mark)
	dustRing = id(13052235894), -- ring of spiky dust
	puff = id(14050360239), -- soft cloud puff
	chips = id(130042646554310), -- grey rock chunks
	chips2 = id(425665059), -- small rock chips
}

local function anchor(name, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Massless = true
	p.Transparency = 1
	p.Size = size
	p.CFrame = CFrame.new()
	p.Parent = parent
	return p
end

local function attach(parent, name, pos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

local function emitter(parent, name, props, attrs)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.LightInfluence = 0
	e.Speed = R(0)
	for k, v in props do
		e[k] = v
	end
	for k, v in attrs or { EmitCount = 1 } do
		e:SetAttribute(k, v)
	end
	e.Parent = parent
	return e
end

local function with(base, extra)
	local t = table.clone(base)
	for k, v in extra do
		t[k] = v
	end
	return t
end

local flat = { -- lies on the ground, facing up
	Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	EmissionDirection = Enum.NormalId.Top,
	Speed = R(0.01),
}
local fadeLate = NS({ KP(0, 0), KP(0.6, 0.1), KP(1, 1) })
local amberHot = CS({ CK(0, WHITE), CK(0.35, HOT), CK(1, AMBER) })

-- falling stone chips (grey, tumbling), `count` of them
local function chips(parent, name, dir, spread, speed, count, size)
	return emitter(parent, name, {
		Texture = TEX.chips,
		Color = CS(STONE),
		EmissionDirection = dir,
		SpreadAngle = Vector2.new(spread, spread),
		Lifetime = R(0.5, 0.75),
		Speed = speed,
		Acceleration = Vector3.new(0, -60, 0),
		Size = NS(size or 0.35),
		Rotation = R(0, 360),
		RotSpeed = R(-320, 320),
	}, { EmitCount = count })
end

function _G.buildStoneBoarFX(effects)
	local old = effects:FindFirstChild("StoneBoar")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "StoneBoar"

	-- EyeGlint (welded on each eye at windup t = 0): an amber star pop over a
	-- hot dot. 2 layers.
	do
		local p = anchor("EyeGlint", Vector3.new(0.2, 0.2, 0.2), root)
		emitter(p, "Glint", {
			Texture = TEX.glint,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.22),
			Size = NS({ KP(0, 0.3), KP(0.3, 1.5), KP(1, 0) }),
			Rotation = R(-10, 10),
			ZOffset = 2,
		})
		emitter(p, "Pop", {
			Texture = TEX.dot,
			Color = CS(AMBER),
			LightEmission = 1,
			Lifetime = R(0.25),
			Size = NS({ KP(0, 0.7), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
			ZOffset = 1.5,
		})
	end

	-- TuskGlint (gore windup, on each tusk point): a sharper glint that holds
	-- a beat, over a slate dot so it reads against the sky. 3 layers.
	do
		local p = anchor("TuskGlint", Vector3.new(0.2, 0.2, 0.2), root)
		emitter(p, "Dark", {
			Texture = TEX.dot,
			Color = CS(SLATE),
			Lifetime = R(0.35),
			Size = NS({ KP(0, 0.4), KP(0.3, 1.0), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			ZOffset = 1,
		})
		emitter(p, "Glint", {
			Texture = TEX.glint,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 5,
			Lifetime = R(0.35),
			Size = NS({ KP(0, 0), KP(0.25, 1.6), KP(1, 0) }),
			Rotation = R(0),
			RotSpeed = R(140),
			ZOffset = 2,
		})
		emitter(p, "Halo", {
			Texture = TEX.dot,
			Color = CS(AMBER),
			LightEmission = 1,
			Lifetime = R(0.3),
			Size = NS({ KP(0, 0.3), KP(0.3, 0.9), KP(1, 0.4) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			ZOffset = 1.5,
		})
	end

	-- HoofScrape (charge windup, on the ground under the fore hoof, -Z = the
	-- boar's facing): dust and grit kicked back past the hoof, a dust ring.
	-- 3 layers.
	do
		local p = anchor("HoofScrape", Vector3.new(0.6, 0.1, 0.6), root)
		emitter(p, "Ring", with(flat, {
			Texture = TEX.dustRing,
			Color = CS(UMBER),
			Lifetime = R(0.3),
			Size = NS({ KP(0, 0.4), KP(1, 2) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			Rotation = R(0, 360),
		}))
		emitter(p, "Puff", {
			Texture = TEX.puff,
			Color = CS(DUST),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(30, 30),
			Lifetime = R(0.45, 0.6),
			Speed = R(5, 7),
			Drag = 5,
			Acceleration = Vector3.new(0, 3, 0),
			Size = NS({ KP(0, 0.6), KP(1, 1.7) }),
			Transparency = NS({ KP(0, 0.2), KP(0.5, 0.5), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-40, 40),
		}, { EmitCount = 4 })
		emitter(p, "Grit", {
			Texture = TEX.chips2,
			Color = CS(SLATE),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(25, 25),
			Lifetime = R(0.35, 0.45),
			Speed = R(8, 11),
			Acceleration = Vector3.new(0, -45, 0),
			Size = NS(0.18),
			Rotation = R(0, 360),
		}, { EmitCount = 4 })
	end

	-- Snort (charge windup, at the nose, -Z = facing): two short umber jets
	-- down-forward out of the nostrils. 2 layers.
	do
		local p = anchor("Snort", Vector3.new(0.4, 0.4, 0.4), root)
		local base = {
			Texture = TEX.puff,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(15, 15),
			Speed = R(6, 9),
			Drag = 6,
			Acceleration = Vector3.new(0, -2, 0),
			Rotation = R(0, 360),
			RotSpeed = R(-60, 60),
		}
		for _, x in { -0.22, 0.22 } do
			local a = attach(p, if x < 0 then "L" else "R", Vector3.new(x, 0, 0))
			a.Orientation = Vector3.new(-25, if x < 0 then 12 else -12, 0)
			emitter(a, "Jet", with(base, {
				Color = CS({ CK(0, Color3.fromRGB(220, 208, 190)), CK(1, DUST) }),
				Lifetime = R(0.4, 0.55),
				Size = NS({ KP(0, 0.3), KP(1, 1.3) }),
				Transparency = NS({ KP(0, 0.25), KP(0.5, 0.55), KP(1, 1) }),
			}), { EmitCount = 3 })
		end
	end

	-- DashDust (charge sets off, on the ground between the hind hooves): a
	-- flat dust ring, puffs sprayed low and wide, chips kicked up, amber grit.
	-- 4 layers.
	do
		local p = anchor("DashDust", Vector3.new(1.5, 0.1, 1.5), root)
		emitter(p, "Ring", with(flat, {
			Texture = TEX.dustRing,
			Color = CS(UMBER),
			Lifetime = R(0.4),
			Size = NS({ KP(0, 0.8), KP(1, 4) }),
			Transparency = NS({ KP(0, 0.25), KP(1, 1) }),
			Rotation = R(0, 360),
		}))
		emitter(p, "Puffs", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(10, 70),
			Lifetime = R(0.6, 0.85),
			Speed = R(10, 15),
			Drag = 5,
			Size = NS({ KP(0, 1.1), KP(1, 3) }),
			Transparency = NS({ KP(0, 0.12), KP(0.5, 0.35), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-30, 30),
		}, { EmitCount = 9 })
		chips(p, "Chips", Enum.NormalId.Top, 45, R(12, 17), 5)
		emitter(p, "Embers", {
			Texture = TEX.dot,
			Color = amberHot,
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(50, 50),
			Lifetime = R(0.3, 0.45),
			Speed = R(7, 10),
			Drag = 3,
			Size = NS({ KP(0, 0.16), KP(1, 0) }),
		}, { EmitCount = 4 })
	end

	-- ChargeTrail (the charge, ridden along low under the body at hoof level):
	-- dust left hanging behind, chips flicked up, slate grit and a few amber
	-- sparks off the hooves. Rate emitters for 0.55 s; code switches them off
	-- early on land. 4 layers.
	do
		local p = anchor("ChargeTrail", Vector3.new(2.4, 0.2, 3.5), root)
		local box = {
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
		}
		emitter(p, "Dust", with(box, {
			Texture = TEX.puff,
			Color = CS(DUST),
			SpreadAngle = Vector2.new(40, 40),
			Lifetime = R(0.6, 0.9),
			Rate = 32,
			Speed = R(1.5, 3),
			Drag = 2,
			Size = NS({ KP(0, 1.2), KP(1, 3) }),
			Transparency = NS({ KP(0, 0.2), KP(0.5, 0.45), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-30, 30),
		}), { EmitDuration = 0.55 })
		emitter(p, "Chips", with(box, {
			Texture = TEX.chips,
			Color = CS(STONE),
			SpreadAngle = Vector2.new(35, 35),
			Lifetime = R(0.45, 0.6),
			Rate = 12,
			Speed = R(8, 12),
			Acceleration = Vector3.new(0, -60, 0),
			Size = NS(0.28),
			Rotation = R(0, 360),
			RotSpeed = R(-300, 300),
		}), { EmitDuration = 0.55 })
		emitter(p, "Grit", with(box, {
			Texture = TEX.chips2,
			Color = CS(SLATE),
			SpreadAngle = Vector2.new(50, 50),
			Lifetime = R(0.3, 0.45),
			Rate = 16,
			Speed = R(6, 9),
			Acceleration = Vector3.new(0, -50, 0),
			Size = NS(0.15),
			Rotation = R(0, 360),
		}), { EmitDuration = 0.55 })
		emitter(p, "Sparks", with(box, {
			Texture = TEX.dot,
			Color = amberHot,
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			SpreadAngle = Vector2.new(60, 60),
			Lifetime = R(0.15, 0.25),
			Rate = 10,
			Speed = R(8, 12),
			Drag = 4,
			Size = NS({ KP(0, 0.12), KP(1, 0) }),
			Squash = NS(-1.2),
		}), { EmitDuration = 0.55 })
	end

	-- Skid (charge ends, on the ground at the fore hooves, -Z = the charge):
	-- dust thrown forward, a slate under-puff and a few chips. 3 layers.
	do
		local p = anchor("Skid", Vector3.new(2, 0.1, 0.6), root)
		emitter(p, "Under", {
			Texture = TEX.puff,
			Color = CS(UMBER),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(20, 15),
			Lifetime = R(0.4, 0.55),
			Speed = R(5, 8),
			Drag = 5,
			Size = NS({ KP(0, 0.8), KP(1, 2.0) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			Rotation = R(0, 360),
		}, { EmitCount = 3 })
		emitter(p, "Puffs", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(30, 15),
			Lifetime = R(0.5, 0.7),
			Speed = R(8, 12),
			Drag = 5,
			Acceleration = Vector3.new(0, 2, 0),
			Size = NS({ KP(0, 0.7), KP(1, 2.1) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
			Rotation = R(0, 360),
		}, { EmitCount = 6 })
		chips(p, "Chips", Enum.NormalId.Front, 30, R(9, 13), 4, 0.3)
	end

	-- GoreHook (gore strike, ~5 studs ahead of the tusks, -Z = facing): an
	-- upward hooking crescent, bone-white core / amber rim / slate under,
	-- swept up through 0.15 s, with a glint at its peak. 4 layers.
	do
		local p = anchor("GoreHook", Vector3.new(0.4, 0.4, 0.4), root)
		local base = {
			Texture = TEX.hook,
			Lifetime = R(0.18),
			Rotation = R(150),
			RotSpeed = R(-260),
			EmissionDirection = Enum.NormalId.Top,
			Speed = R(10),
			Drag = 12,
		}
		emitter(p, "Dark", with(base, {
			Color = CS(SLATE),
			Size = NS({ KP(0, 2.4), KP(1, 3.4) }),
			Transparency = NS({ KP(0, 0.2), KP(0.6, 0.35), KP(1, 1) }),
			ZOffset = 0.5,
		}))
		emitter(p, "Rim", with(base, {
			Color = CS(AMBER),
			LightEmission = 0.8,
			Size = NS({ KP(0, 2.1), KP(1, 3.0) }),
			Transparency = NS({ KP(0, 0.1), KP(0.6, 0.25), KP(1, 1) }),
			ZOffset = 1,
		}))
		emitter(p, "Core", with(base, {
			Color = CS({ CK(0, WHITE), CK(1, BONE) }),
			LightEmission = 1,
			Brightness = 3,
			Size = NS({ KP(0, 1.8), KP(1, 2.6) }),
			Transparency = fadeLate,
			ZOffset = 1.5,
		}))
		local peak = attach(p, "Peak", Vector3.new(0, 1.5, 0))
		emitter(peak, "Glint", {
			Texture = TEX.glint,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.14),
			Size = NS({ KP(0, 0.4), KP(0.35, 1.6), KP(1, 0) }),
			ZOffset = 2,
		}, { EmitCount = 1, EmitDelay = 0.08 })
	end

	-- ChargeHit (charge hit, on the target's near side facing the boar; sprays
	-- go +Z, through the target): dust burst, stone chips, a short amber flash
	-- over a slate blot. Code adds the shake. 5 layers.
	do
		local p = anchor("ChargeHit", Vector3.new(0.6, 0.6, 0.6), root)
		emitter(p, "Dark", {
			Texture = TEX.dot,
			Color = CS(SLATE),
			Lifetime = R(0.16),
			Size = NS({ KP(0, 1.2), KP(0.3, 3), KP(1, 0.5) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			ZOffset = 1,
		})
		emitter(p, "Flash", {
			Texture = TEX.dot,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.12),
			Size = NS({ KP(0, 1), KP(0.3, 2.6), KP(1, 0) }),
			ZOffset = 3,
		})
		emitter(p, "Star", {
			Texture = TEX.glint,
			Color = amberHot,
			LightEmission = 1,
			Lifetime = R(0.14),
			Size = NS({ KP(0, 0.6), KP(0.3, 2.4), KP(1, 0) }),
			Rotation = R(0, 45),
			ZOffset = 3.5,
		})
		emitter(p, "Dust", {
			Texture = TEX.puff,
			Color = CS(DUST),
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(70, 70),
			Lifetime = R(0.5, 0.7),
			Speed = R(10, 14),
			Drag = 6,
			Size = NS({ KP(0, 1), KP(1, 2.4) }),
			Transparency = NS({ KP(0, 0.25), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-40, 40),
			ZOffset = 1.5,
		}, { EmitCount = 6 })
		chips(p, "Chips", Enum.NormalId.Back, 55, R(14, 20), 5)
	end

	-- GoreHit (gore hit, on the target's near side facing the boar): amber
	-- sparks, a small crescent mark (bone core over slate) and a white pop.
	-- 4 layers.
	do
		local p = anchor("GoreHit", Vector3.new(0.4, 0.4, 0.4), root)
		local mark = {
			Texture = TEX.arc,
			Lifetime = R(0.25),
			Rotation = R(-60),
		}
		emitter(p, "MarkDark", with(mark, {
			Color = CS(SLATE),
			Size = NS({ KP(0, 1.4), KP(0.2, 2.4), KP(1, 2.6) }),
			Transparency = NS({ KP(0, 0.2), KP(0.6, 0.3), KP(1, 1) }),
			ZOffset = 1.5,
		}))
		emitter(p, "Mark", with(mark, {
			Color = CS({ CK(0, WHITE), CK(0.5, BONE), CK(1, AMBER) }),
			LightEmission = 1,
			Brightness = 3,
			Size = NS({ KP(0, 1.2), KP(0.2, 2.1), KP(1, 2.2) }),
			Transparency = fadeLate,
			ZOffset = 2,
		}))
		emitter(p, "Sparks", {
			Texture = TEX.dot,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 3,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = R(0.15, 0.25),
			Speed = R(18, 26),
			Drag = 6,
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Back,
			Size = NS({ KP(0, 0.15), KP(1, 0) }),
			Squash = NS(-1.5),
			ZOffset = 2.5,
		}, { EmitCount = 6 })
		emitter(p, "Pop", {
			Texture = TEX.dot,
			Color = CS(WHITE),
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.08),
			Size = NS({ KP(0, 1.2), KP(1, 0) }),
			ZOffset = 3,
		})
	end

	-- StaggerChips (stagger, welded at the Core): stone chips popped off the
	-- chest, a dust puff and an amber pop. Code flickers the cracks. 3 layers.
	do
		local p = anchor("StaggerChips", Vector3.new(2.4, 1.5, 2.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 3,
			Lifetime = R(0.1),
			Size = NS({ KP(0, 1), KP(0.4, 2.8), KP(1, 0) }),
			ZOffset = 3,
		})
		emitter(p, "Dust", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(60, 60),
			Lifetime = R(0.45, 0.6),
			Speed = R(3, 5),
			Drag = 4,
			Size = NS({ KP(0, 0.8), KP(1, 1.8) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			Rotation = R(0, 360),
			ZOffset = 1.5,
		}, { EmitCount = 4 })
		local c = chips(p, "Chips", Enum.NormalId.Top, 70, R(12, 17), 7, 0.32)
		c.Shape = Enum.ParticleEmitterShape.Box
	end

	-- Death (at the Core, body-sized box): the body crumbles into umber dust
	-- sinking and drifting, amber motes rising, and the spirit-core glint.
	-- 4 layers over the 1 s fade.
	do
		local p = anchor("Death", Vector3.new(3, 2.6, 6), root)
		emitter(p, "Dust", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(80, 80),
			Lifetime = R(0.8, 1.2),
			Rate = 22,
			Speed = R(1, 2.5),
			Drag = 1,
			Acceleration = Vector3.new(0, -1.5, 0),
			Size = NS({ KP(0, 1.2), KP(1, 2.6) }),
			Transparency = NS({ KP(0, 0.4), KP(0.5, 0.55), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-25, 25),
		}, { EmitDuration = 0.9 })
		emitter(p, "Motes", {
			Texture = TEX.dot,
			Color = amberHot,
			LightEmission = 1,
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(20, 20),
			Lifetime = R(0.6, 1),
			Rate = 22,
			Speed = R(3, 5),
			Drag = 1,
			Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.1), KP(0.4, 0.5), KP(0.5, 0), KP(1, 0.6) }),
		}, { EmitDuration = 0.8 })
		local core = attach(p, "Core", Vector3.zero)
		emitter(core, "Glow", {
			Texture = TEX.dot,
			Color = CS(HOT),
			LightEmission = 1,
			Lifetime = R(0.45),
			Size = NS({ KP(0, 0.4), KP(0.3, 1.5), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			ZOffset = 2.5,
		}, { EmitCount = 1, EmitDelay = 0.15 })
		emitter(core, "Glint", {
			Texture = TEX.glint,
			Color = amberHot,
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.45),
			Size = NS({ KP(0, 0), KP(0.3, 2), KP(1, 0) }),
			Rotation = R(0),
			RotSpeed = R(90),
			ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.15 })
	end

	root.Parent = effects
	return root
end

return true
