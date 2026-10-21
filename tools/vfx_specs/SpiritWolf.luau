--!nocheck
-- Builder for ReplicatedStorage.Effects.SpiritWolf: the Spirit Wolf's attack,
-- hit and death effects (an enemy, so no tiers and no buildFromSpec). Load
-- through the receiver, then build into staging:
--   local m = Instance.new("ModuleScript")
--   m.Source = HttpService:GetAsync("http://127.0.0.1:8766/vfx_specs/SpiritWolf.luau")
--   require(m)  -- installs _G.buildSpiritWolfFX(effectsFolder)
-- Runtime: src/client/EnemyFX/SpiritWolf.luau (cue -> template, placement).
--
-- Moonlight qi: white-hot core, pale blue (#CFE6FF) falloff, blue rim
-- (#7FA8D8), and a dark slate (#2F3B50) copy under every bright shape so it
-- reads on grass at noon. Ring-1 pack beast: every beat is 2 to 6 layers,
-- one-shot, short-lived (packs of 3-4 die often).
--
-- Every template is an invisible Part (pivot = its centre, -Z = the wolf's
-- facing or the blow's direction). Ground templates sit with their centre on
-- the ground; code lifts nothing. Emit attributes (EmitCount, EmitDelay,
-- EmitDuration) are on the emitters so the plugin's Emit button (R) plays each
-- one as the game does. `AuthoredSeconds` on a root says how long it was timed
-- for, so code refits it to the live windup.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local CK = ColorSequenceKeypoint.new
local id = function(n)
	return "rbxassetid://" .. n
end

local WHITE = Color3.new(1, 1, 1)
local CORE = Color3.fromRGB(207, 230, 255)
local RIM = Color3.fromRGB(127, 168, 216)
local SLATE = Color3.fromRGB(47, 59, 80)
local INK = Color3.fromRGB(18, 20, 28)
local DUST = Color3.fromRGB(176, 170, 156)
local EYE = Color3.fromRGB(255, 64, 52)
local GOLD = Color3.fromRGB(255, 240, 200)

local TEX = {
	glint = id(84223532517124), -- crisp 4-point star glint
	dot = id(9841273544), -- hard round glow (flashes, motes, sparks)
	mote = id(8238126392), -- small soft dot
	fang = id(7216852121), -- thin bright crescent arc
	claw = id(11636552631), -- three parallel tapered streaks (a claw rake)
	moon = id(1084963972), -- crisp crescent moon
	ring = id(16878073342), -- thin bright ring
	dustRing = id(13052235894), -- ring of spiky dust
	puff = id(14050360239), -- soft cloud puff
	breath = id(15753663130), -- soft wisp
	line = id(7886908733), -- thin line streak
	streak = id(18244764764), -- soft tapered streak (trail)
	crack = id(7994630128), -- dark branching cracks
	chips = id(425665059), -- rock chips
	ink = id(16132530029), -- black ink splash
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

local function trail(parent, name, a0, a1, props)
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Enabled = false
	t.LightInfluence = 0
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local fadeLate = NS({ KP(0, 0), KP(0.6, 0.1), KP(1, 1) })
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

-- A crescent (core, rim, dark base) in one attachment: the fang.
local function fang(parent, name, pos, rotation, dir)
	local a = attach(parent, name, pos)
	local base = {
		Texture = TEX.fang,
		Lifetime = R(0.14),
		Rotation = R(rotation),
		EmissionDirection = dir,
		Speed = R(7),
		Drag = 10,
	}
	emitter(a, "Dark", with(base, {
		Color = CS(SLATE),
		Size = NS({ KP(0, 1.05), KP(1, 1.35) }),
		Transparency = NS({ KP(0, 0.25), KP(0.6, 0.35), KP(1, 1) }),
		ZOffset = 0.5,
	}))
	emitter(a, "Rim", with(base, {
		Color = CS(RIM),
		LightEmission = 0.6,
		Size = NS({ KP(0, 0.9), KP(1, 1.15) }),
		Transparency = NS({ KP(0, 0.15), KP(0.6, 0.25), KP(1, 1) }),
		ZOffset = 1,
	}))
	emitter(a, "Core", with(base, {
		Color = CS({ CK(0, WHITE), CK(1, CORE) }),
		LightEmission = 1,
		Brightness = 3,
		Size = NS({ KP(0, 0.8), KP(1, 1.0) }),
		Transparency = fadeLate,
		ZOffset = 1.5,
	}))
end

function _G.buildSpiritWolfFX(effects)
	local old = effects:FindFirstChild("SpiritWolf")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SpiritWolf"

	-- EyeGlint (welded on each eye, every windup): a red star pop, then the
	-- held glow (`Hold` runs for the windup; code enables and disables it).
	do
		local p = anchor("EyeGlint", Vector3.new(0.2, 0.2, 0.2), root)
		emitter(p, "Glint", {
			Texture = TEX.glint,
			Color = CS({ CK(0, WHITE), CK(0.5, EYE), CK(1, EYE) }),
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.16),
			Size = NS({ KP(0, 0.3), KP(0.3, 1.4), KP(1, 0) }),
			Rotation = R(-10, 10),
			ZOffset = 2,
		})
		emitter(p, "Pop", {
			Texture = TEX.dot,
			Color = CS(EYE),
			LightEmission = 1,
			Lifetime = R(0.22),
			Size = NS({ KP(0, 0.7), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
			ZOffset = 1.5,
		})
		emitter(p, "Hold", {
			Texture = TEX.dot,
			Color = CS(EYE),
			LightEmission = 1,
			Lifetime = R(0.12, 0.18),
			Rate = 18,
			Size = NS({ KP(0, 0.32), KP(1, 0.22) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 0.8) }),
			LockedToPart = true,
			ZOffset = 1.5,
		}, { EmitDuration = 0.45 })
	end

	-- Breath (bite windup, welded at the Mouth): a faint white wisp curling
	-- out of the jaws, pale motes drawn in.
	do
		local p = anchor("Breath", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Wisp", {
			Texture = TEX.breath,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 0.5,
			Lifetime = R(0.4, 0.55),
			Rate = 14,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(20, 20),
			Speed = R(1.5, 2.5),
			Acceleration = Vector3.new(0, 1.5, 0),
			Size = NS({ KP(0, 0.25), KP(1, 0.8) }),
			Transparency = NS({ KP(0, 1), KP(0.2, 0.55), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-60, 60),
		}, { EmitDuration = 0.4 })
		emitter(p, "Motes", {
			Texture = TEX.mote,
			Color = CS(CORE),
			LightEmission = 1,
			Lifetime = R(0.3),
			Rate = 10,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Speed = R(3),
			Size = NS({ KP(0, 0.12), KP(1, 0.05) }),
			Transparency = NS({ KP(0, 1), KP(0.3, 0.2), KP(1, 0.6) }),
		}, { EmitDuration = 0.4 })
	end

	-- FangSnap (bite strike, at the Mouth facing the bite): two crescents,
	-- white core / blue rim / slate base, snap shut ~1.5 studs ahead of the
	-- muzzle, and a glint where they meet.
	do
		local p = anchor("FangSnap", Vector3.new(0.4, 0.4, 0.4), root)
		fang(p, "Upper", Vector3.new(0, 0.7, -1.1), 0, Enum.NormalId.Bottom)
		fang(p, "Lower", Vector3.new(0, -0.7, -1.1), 180, Enum.NormalId.Top)
		local snap = attach(p, "Snap", Vector3.new(0, 0, -1.2))
		emitter(snap, "Glint", {
			Texture = TEX.glint,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.12),
			Size = NS({ KP(0, 0.4), KP(0.35, 1.3), KP(1, 0) }),
			ZOffset = 2,
		}, { EmitCount = 1, EmitDelay = 0.08 })
	end

	-- BiteHit (on the struck player, near side at chest height): red-white
	-- sparks, a tiny ink splash behind them, a white pop.
	do
		local p = anchor("BiteHit", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Ink", {
			Texture = TEX.ink,
			Color = CS(INK),
			Lifetime = R(0.3),
			Size = NS({ KP(0, 0.7), KP(1, 1.5) }),
			Transparency = NS({ KP(0, 0.1), KP(0.5, 0.3), KP(1, 1) }),
			Rotation = R(0, 360),
			ZOffset = 1,
		})
		emitter(p, "Sparks", {
			Texture = TEX.dot,
			Color = CS({ CK(0, WHITE), CK(1, Color3.fromRGB(255, 80, 64)) }),
			LightEmission = 1,
			Brightness = 3,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = R(0.15, 0.25),
			Speed = R(18, 26),
			Drag = 6,
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Back,
			Size = NS({ KP(0, 0.14), KP(1, 0) }),
			Squash = NS(-1.5),
			ZOffset = 2.5,
		}, { EmitCount = 4 })
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

	-- Gather (pounce windup, welded at the Core): moon motes and thin streaks
	-- pulled in from all round, a glow swelling at the chest. 0.7 s.
	do
		local p = anchor("Gather", Vector3.new(7, 5, 9), root)
		p:SetAttribute("AuthoredSeconds", 0.7)
		local inward = {
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		}
		emitter(p, "Motes", with(inward, {
			Texture = TEX.dot,
			Color = CS({ CK(0, RIM), CK(1, WHITE) }),
			LightEmission = 1,
			Lifetime = R(0.45, 0.6),
			Rate = 28,
			Speed = R(6, 8),
			Size = NS({ KP(0, 0.26), KP(1, 0.12) }),
			Transparency = NS({ KP(0, 1), KP(0.25, 0), KP(1, 0.2) }),
		}), { EmitDuration = 0.6 })
		emitter(p, "Streaks", with(inward, {
			Texture = TEX.line,
			Color = CS(CORE),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = R(0.3),
			Rate = 12,
			Speed = R(12, 14),
			Size = NS({ KP(0, 1.2), KP(1, 0.6) }),
			Transparency = NS({ KP(0, 1), KP(0.3, 0.1), KP(1, 0.6) }),
		}), { EmitDuration = 0.55 })
		local core = attach(p, "Core", Vector3.zero)
		emitter(core, "Glow", {
			Texture = TEX.dot,
			Color = CS(CORE),
			LightEmission = 1,
			Lifetime = R(0.75),
			Size = NS({ KP(0, 0.4), KP(0.85, 2), KP(1, 0.5) }),
			Transparency = NS({ KP(0, 0.8), KP(0.8, 0.3), KP(1, 1) }),
			LockedToPart = true,
			ZOffset = 2.5, -- the chest is inside the body: pull it out to the camera
		})
	end

	-- PawDust (hind paws, on the ground): a small dust kick and grit. Hop,
	-- the pounce windup's push-off.
	do
		local p = anchor("PawDust", Vector3.new(0.6, 0.1, 0.6), root)
		emitter(p, "Puff", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Lifetime = R(0.45, 0.65),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(55, 55),
			Speed = R(3, 5),
			Drag = 5,
			Size = NS({ KP(0, 0.7), KP(1, 1.8) }),
			Transparency = NS({ KP(0, 0.15), KP(0.5, 0.45), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-40, 40),
		}, { EmitCount = 4 })
		emitter(p, "Grit", {
			Texture = TEX.mote,
			Color = CS(SLATE),
			Lifetime = R(0.35, 0.45),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(40, 40),
			Speed = R(7, 10),
			Acceleration = Vector3.new(0, -40, 0),
			Size = NS(0.1),
		}, { EmitCount = 4 })
	end

	-- DashDust (pounce/leap take-off, on the ground under the hind paws): a
	-- flat dust ring, puffs sprayed low and wide, moon motes kicked up.
	do
		local p = anchor("DashDust", Vector3.new(1.5, 0.1, 1.5), root)
		emitter(p, "Ring", with(flat, {
			Texture = TEX.dustRing,
			Color = CS(DUST),
			Lifetime = R(0.35),
			Size = NS({ KP(0, 0.6), KP(1, 3) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
			Rotation = R(0, 360),
		}))
		emitter(p, "Puffs", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(5, 180),
			Lifetime = R(0.5, 0.7),
			Speed = R(10, 14),
			Drag = 5,
			Size = NS({ KP(0, 0.7), KP(1, 2) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-30, 30),
		}, { EmitCount = 6 })
		emitter(p, "Motes", {
			Texture = TEX.dot,
			Color = CS(CORE),
			LightEmission = 1,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(50, 50),
			Lifetime = R(0.35, 0.5),
			Speed = R(7, 10),
			Drag = 3,
			Size = NS({ KP(0, 0.16), KP(1, 0) }),
		}, { EmitCount = 5 })
	end

	-- Skid (pounce ends, on the ground at the front paws, facing the dash):
	-- dust thrown forward and grit.
	do
		local p = anchor("Skid", Vector3.new(1.5, 0.1, 0.6), root)
		emitter(p, "Puffs", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(25, 15),
			Lifetime = R(0.45, 0.65),
			Speed = R(6, 10),
			Drag = 5,
			Acceleration = Vector3.new(0, 2, 0),
			Size = NS({ KP(0, 0.6), KP(1, 1.7) }),
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			Rotation = R(0, 360),
		}, { EmitCount = 5 })
		emitter(p, "Grit", {
			Texture = TEX.mote,
			Color = CS(SLATE),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(30, 20),
			Lifetime = R(0.35, 0.45),
			Speed = R(9, 12),
			Acceleration = Vector3.new(0, -40, 0),
			Size = NS(0.1),
		}, { EmitCount = 5 })
	end

	-- MoonTrail (pounce and leap flight): code moves the attachments onto the
	-- body (Top at the crest, Bottom at the belly) and enables the trails and
	-- the shed motes for the flight. Bright core over a wider slate band.
	do
		local p = anchor("MoonTrail", Vector3.new(0.2, 0.2, 0.2), root)
		local top = attach(p, "Top", Vector3.new(0, 1.4, 0))
		local mid = attach(p, "Mid", Vector3.new(0, 0.5, 0))
		local bottom = attach(p, "Bottom", Vector3.new(0, -0.6, 0))
		trail(p, "Dark", top, bottom, {
			Texture = TEX.streak,
			TextureMode = Enum.TextureMode.Stretch,
			Color = CS(SLATE),
			Lifetime = 0.25,
			MinLength = 0.05,
			Transparency = NS({ KP(0, 0.35), KP(1, 1) }),
			WidthScale = NS({ KP(0, 1), KP(1, 0.3) }),
		})
		trail(p, "Bright", top, mid, {
			Texture = TEX.streak,
			TextureMode = Enum.TextureMode.Stretch,
			Color = CS({ CK(0, WHITE), CK(0.4, CORE), CK(1, RIM) }),
			LightEmission = 1,
			Brightness = 2,
			Lifetime = 0.25,
			MinLength = 0.05,
			Transparency = NS({ KP(0, 0), KP(0.6, 0.4), KP(1, 1) }),
			WidthScale = NS({ KP(0, 1), KP(1, 0.2) }),
		})
		emitter(mid, "Shed", {
			Texture = TEX.dot,
			Color = CS(CORE),
			LightEmission = 1,
			Lifetime = R(0.3, 0.45),
			Rate = 22,
			SpreadAngle = Vector2.new(180, 180),
			Speed = R(0.5, 1.5),
			Size = NS({ KP(0, 0.15), KP(1, 0) }),
		}, { EmitDuration = 0.3 })
	end

	-- ClawRake (pounce hit, on the target's near side facing the wolf): three
	-- diagonal claw streaks (white core, blue rim, slate base) and a spark.
	do
		local p = anchor("ClawRake", Vector3.new(0.4, 0.4, 0.4), root)
		local base = {
			Texture = TEX.claw,
			Lifetime = R(0.22),
			Rotation = R(-35),
		}
		emitter(p, "Dark", with(base, {
			Color = CS(SLATE),
			Size = NS({ KP(0, 1.0), KP(0.2, 2.2), KP(1, 2.4) }),
			Transparency = NS({ KP(0, 0.2), KP(0.6, 0.3), KP(1, 1) }),
			ZOffset = 1.5,
		}))
		emitter(p, "Rim", with(base, {
			Color = CS(RIM),
			LightEmission = 0.6,
			Size = NS({ KP(0, 0.9), KP(0.2, 1.95), KP(1, 2.1) }),
			Transparency = NS({ KP(0, 0.1), KP(0.6, 0.2), KP(1, 1) }),
			ZOffset = 2,
		}))
		emitter(p, "Core", with(base, {
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Brightness = 3,
			Size = NS({ KP(0, 0.8), KP(0.2, 1.7), KP(1, 1.8) }),
			Transparency = fadeLate,
			ZOffset = 2.5,
		}))
		emitter(p, "Glint", {
			Texture = TEX.glint,
			Color = CS(WHITE),
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.14),
			Size = NS({ KP(0, 0.5), KP(0.3, 1.5), KP(1, 0) }),
			ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.04 })
		emitter(p, "Sparks", {
			Texture = TEX.dot,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = R(0.15, 0.25),
			Speed = R(16, 24),
			Drag = 6,
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Back,
			Size = NS({ KP(0, 0.13), KP(1, 0) }),
			Squash = NS(-1.5),
			ZOffset = 3,
		}, { EmitCount = 4 })
	end

	-- LeapSigil (leap windup, centred in the landing circle, on the ground):
	-- a crescent moon turning on a slate shadow inside a thin pale ring, on top
	-- of the stock red telegraph. Authored for the 1.0 s windup + 0.45 s
	-- flight; code refits it to the telegraph's seconds left + flight, and
	-- scales it to the circle's radius (authored for r5).
	do
		local p = anchor("LeapSigil", Vector3.new(1, 0.1, 1), root)
		p:SetAttribute("AuthoredSeconds", 1.45)
		p:SetAttribute("AuthoredRadius", 5)
		local hold = NS({ KP(0, 1), KP(0.12, 0.15), KP(0.85, 0.15), KP(1, 1) })
		local moon = {
			Texture = TEX.moon,
			Lifetime = R(1.45),
			Rotation = R(0),
			RotSpeed = R(80),
		}
		local low = attach(p, "Low", Vector3.new(0, 0.4, 0)) -- over the telegraph disc
		emitter(low, "Shadow", with(flat, with(moon, {
			Color = CS(SLATE),
			Size = NS({ KP(0, 0.5), KP(0.12, 3.3), KP(1, 3.5) }),
			Transparency = NS({ KP(0, 1), KP(0.12, 0.05), KP(0.85, 0.05), KP(1, 1) }),
		})))
		local high = attach(p, "High", Vector3.new(0, 0.46, 0))
		emitter(high, "Moon", with(flat, with(moon, {
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Brightness = 3,
			Size = NS({ KP(0, 0.4), KP(0.12, 2.8), KP(1, 3) }),
			Transparency = hold,
		})))
		emitter(high, "Ring", with(flat, {
			Texture = TEX.ring,
			Color = CS(CORE),
			LightEmission = 1,
			Lifetime = R(1.45),
			Rotation = R(0),
			RotSpeed = R(-40),
			Size = NS({ KP(0, 3.5), KP(0.15, 4.4), KP(1, 4.5) }),
			Transparency = NS({ KP(0, 1), KP(0.15, 0.45), KP(0.85, 0.35), KP(1, 1) }),
		}))
	end

	-- LeapGlint (leap windup, above the wolf's head as it rears up): a star
	-- glint with a soft halo.
	do
		local p = anchor("LeapGlint", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Glint", {
			Texture = TEX.glint,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Brightness = 5,
			Lifetime = R(0.4),
			Size = NS({ KP(0, 0), KP(0.25, 2.2), KP(1, 0) }),
			Rotation = R(0),
			RotSpeed = R(120),
			ZOffset = 2,
		})
		emitter(p, "Halo", {
			Texture = TEX.dot,
			Color = CS(CORE),
			LightEmission = 1,
			Lifetime = R(0.35),
			Size = NS({ KP(0, 0.4), KP(0.3, 1.3), KP(1, 0.6) }),
			Transparency = NS({ KP(0, 0.5), KP(1, 1) }),
			ZOffset = 1.5,
		})
	end

	-- Landing (leap lands, centred on the landing point, on the ground): r5
	-- shockwave ring over a slate dust ring, low dust spray, rock chips, a
	-- crack decal that holds ~0.6 s, and a white flash. Code adds the shake.
	do
		local p = anchor("Landing", Vector3.new(1.5, 0.1, 1.5), root)
		p:SetAttribute("AuthoredRadius", 5)
		local low = attach(p, "Low", Vector3.new(0, 0.18, 0))
		emitter(low, "Crack", with(flat, {
			Texture = TEX.crack,
			Color = CS(Color3.fromRGB(30, 34, 44)),
			Lifetime = R(0.8),
			Size = NS({ KP(0, 2.2), KP(0.1, 3), KP(1, 3.1) }),
			Transparency = NS({ KP(0, 1), KP(0.05, 0.1), KP(0.7, 0.2), KP(1, 1) }),
			Rotation = R(0, 360),
		}))
		emitter(low, "DustRing", with(flat, {
			Texture = TEX.dustRing,
			Color = CS(SLATE),
			Lifetime = R(0.5),
			Size = NS({ KP(0, 0.8), KP(1, 4.8) }),
			Transparency = NS({ KP(0, 0.25), KP(1, 1) }),
			Rotation = R(0, 360),
		}))
		local high = attach(p, "High", Vector3.new(0, 0.26, 0))
		emitter(high, "Shockwave", with(flat, {
			Texture = TEX.ring,
			Color = CS({ CK(0, WHITE), CK(1, RIM) }),
			LightEmission = 1,
			Brightness = 2,
			Lifetime = R(0.4),
			Size = NS({ KP(0, 0.6), KP(0.5, 4.3), KP(1, 5) }),
			Transparency = NS({ KP(0, 0), KP(0.5, 0.2), KP(1, 1) }),
		}))
		local air = attach(p, "Air", Vector3.new(0, 0.6, 0))
		emitter(air, "Puffs", {
			Texture = TEX.puff,
			Color = CS(DUST),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(5, 180),
			Lifetime = R(0.55, 0.75),
			Speed = R(14, 20),
			Drag = 6,
			Size = NS({ KP(0, 0.9), KP(1, 2.4) }),
			Transparency = NS({ KP(0, 0.3), KP(1, 1) }),
			Rotation = R(0, 360),
			RotSpeed = R(-30, 30),
		}, { EmitCount = 8 })
		emitter(air, "Chips", {
			Texture = TEX.chips,
			Color = CS(Color3.fromRGB(120, 124, 132)),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(45, 45),
			Lifetime = R(0.6, 0.8),
			Speed = R(14, 20),
			Acceleration = Vector3.new(0, -55, 0),
			Size = NS(0.35),
			Rotation = R(0, 360),
			RotSpeed = R(-300, 300),
		}, { EmitCount = 6 })
		local flash = attach(p, "Flash", Vector3.new(0, 1.2, 0))
		emitter(flash, "Flash", {
			Texture = TEX.dot,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Brightness = 3,
			Lifetime = R(0.12),
			Size = NS({ KP(0, 1), KP(0.3, 3), KP(1, 0) }),
			ZOffset = 1,
		})
	end

	-- HowlRings (howl, at the Mouth facing forward): three pale sound rings
	-- rolling out of the jaws, the first over a slate ring.
	do
		local p = anchor("HowlRings", Vector3.new(0.4, 0.4, 0.4), root)
		local ring = {
			Texture = TEX.ring,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Front,
			Lifetime = R(0.6),
			Speed = R(7),
			Drag = 2,
		}
		emitter(p, "Dark", with(ring, {
			Color = CS(SLATE),
			Size = NS({ KP(0, 0.6), KP(1, 3.9) }),
			Transparency = NS({ KP(0, 0.5), KP(1, 1) }),
		}), { EmitCount = 1, EmitDelay = 0.03 })
		for i, delay in { 0, 0.22, 0.44 } do
			emitter(p, "Ring" .. i, with(ring, {
				Color = CS({ CK(0, WHITE), CK(1, CORE) }),
				LightEmission = 0.8,
				Size = NS({ KP(0, 0.5), KP(1, 3.5) }),
				Transparency = NS({ KP(0, 0.2), KP(1, 1) }),
			}), { EmitCount = 1, EmitDelay = delay })
		end
	end

	-- CrestGlow (howl, welded on the crest): a faint moon-glow and motes
	-- rising off the ridge for the howl.
	do
		local p = anchor("CrestGlow", Vector3.new(0.8, 0.3, 3), root)
		emitter(p, "Glow", {
			Texture = TEX.dot,
			Color = CS(CORE),
			LightEmission = 1,
			Lifetime = R(0.9),
			Size = NS({ KP(0, 1), KP(0.4, 2.2), KP(1, 1.6) }),
			Transparency = NS({ KP(0, 1), KP(0.35, 0.65), KP(1, 1) }),
			LockedToPart = true,
		})
		emitter(p, "Motes", {
			Texture = TEX.mote,
			Color = CS(CORE),
			LightEmission = 1,
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			Lifetime = R(0.5, 0.8),
			Rate = 12,
			Speed = R(1.5, 3),
			Size = NS({ KP(0, 0.14), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.2), KP(0.5, 0.6), KP(0.6, 0.1), KP(1, 1) }),
		}, { EmitDuration = 0.7 })
	end

	-- StaggerFlash (stagger, welded at the Core): a white pop and a star
	-- burst. Code adds the 0.08 s white body flash and the eye flicker.
	do
		local p = anchor("StaggerFlash", Vector3.new(0.4, 0.4, 0.4), root)
		emitter(p, "Pop", {
			Texture = TEX.dot,
			Color = CS(WHITE),
			LightEmission = 1,
			Brightness = 3,
			Lifetime = R(0.08),
			Size = NS({ KP(0, 1), KP(0.4, 2.6), KP(1, 0) }),
			ZOffset = 3,
		})
		emitter(p, "Star", {
			Texture = TEX.glint,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Lifetime = R(0.12),
			Size = NS({ KP(0, 0.6), KP(0.3, 2), KP(1, 0) }),
			Rotation = R(0, 45),
			ZOffset = 3,
		})
	end

	-- Death (at the Core, body-sized): pale-blue qi motes rising off the body
	-- through the 1 s fade, a soft gold-white glow and the spirit-core glint.
	do
		local p = anchor("Death", Vector3.new(2.6, 2, 6), root)
		emitter(p, "Motes", {
			Texture = TEX.dot,
			Color = CS({ CK(0, WHITE), CK(1, CORE) }),
			LightEmission = 1,
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(20, 20),
			Lifetime = R(0.6, 1),
			Rate = 26,
			Speed = R(3, 5),
			Drag = 1,
			Size = NS({ KP(0, 0.2), KP(1, 0) }),
			Transparency = NS({ KP(0, 0.1), KP(0.4, 0.5), KP(0.5, 0), KP(1, 0.6) }),
		}, { EmitDuration = 0.8 })
		local core = attach(p, "Core", Vector3.zero)
		emitter(core, "Glow", {
			Texture = TEX.dot,
			Color = CS(GOLD),
			LightEmission = 1,
			Lifetime = R(0.4),
			Size = NS({ KP(0, 0.4), KP(0.3, 1.3), KP(1, 0.2) }),
			Transparency = NS({ KP(0, 0.4), KP(1, 1) }),
			ZOffset = 2,
		}, { EmitCount = 1, EmitDelay = 0.1 })
		emitter(core, "Glint", {
			Texture = TEX.glint,
			Color = CS({ CK(0, WHITE), CK(1, GOLD) }),
			LightEmission = 1,
			Brightness = 4,
			Lifetime = R(0.4),
			Size = NS({ KP(0, 0), KP(0.3, 1.8), KP(1, 0) }),
			Rotation = R(0),
			RotSpeed = R(90),
			ZOffset = 3,
		}, { EmitCount = 1, EmitDelay = 0.1 })
	end

	root.Parent = effects
	return root
end

return true
