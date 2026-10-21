--!nocheck
-- Palm Strike's templates (PalmStrike_T1..T4) as a spec for
-- vfxBlocks.buildFromSpec. Beats play in order for every tier between
-- `from` and `to` (default 1-4). Shared pieces come from blocks; the seal,
-- cracks, crater and halo are Palm Strike's own (generic `emitter` beats).
-- Authored at radius 9 and an active window of 0.3 s; CombatEffects rescales
-- to def.radius and fits Phase "active" emitters to Hit -> Hit Stop.
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local GOLD = Color3.fromRGB(255, 210, 120)
local CRACK = Color3.fromRGB(110, 88, 56)
local CRATER = Color3.fromRGB(70, 56, 40)
local id = function(n)
	return "rbxassetid://" .. n
end

local function crackProps(size)
	return {
		Texture = id(93520831389146), Color = CS(CRACK), LightInfluence = 0.3,
		Size = NS(size), Transparency = NS({ KP(0, 1), KP(0.04, 0.1), KP(0.6, 0.25), KP(1, 1) }),
		Lifetime = R(1.4), Rotation = R(0, 360), ZOffset = -0.5,
	}
end

local HALO_AT = CFrame.new(0, 3.6, 1.2) -- repositioned behind the head at runtime

return {
	id = "PalmStrike",
	root = { attrs = { AuthoredActive = 0.3, AuthoredRadius = 9 } },
	beats = {
		-- the ground wave out to the radius (3D torus + particle front), with
		-- echo ring, rays and dust skirt
		{ block = "groundShockwave", params = { radius = 9 } },
		{ block = "emitter", from = 3, params = {
			part = "Ground", name = "Seal", flat = true, attrs = { EmitCount = 1 },
			props = {
				Texture = id(83667248904000), Color = CS(GOLD),
				Size = NS({ KP(0, 2), KP(0.2, 4.5), KP(1, 5) }), Transparency = NS({ KP(0, 0.1), KP(0.5, 0.25), KP(1, 1) }),
				Lifetime = R(0.8), LightEmission = 0.45, RotSpeed = R(90), Rotation = R(0, 360),
			},
		} },
		{ block = "emitter", from = 3, to = 3, params = { part = "Ground", name = "Cracks", flat = true, attrs = { EmitCount = 1, EmitDelay = 0.02 }, props = crackProps(3.2) } },
		{ block = "emitter", from = 4, params = { part = "Ground", name = "Cracks", flat = true, attrs = { EmitCount = 1, EmitDelay = 0.02 }, props = crackProps(4.5) } },
		{ block = "craterRing", from = 3, params = { parent = "Ground", radius = 9 } },
		{ block = "shockwaveShell", from = 3, params = { name = "Shell" } },
		{ block = "emitter", from = 4, params = {
			part = "Ground", name = "Crater", flat = true, attrs = { EmitCount = 1 },
			props = {
				Texture = id(90713203428310), Color = CS(CRATER), LightInfluence = 0.4,
				Size = NS(3), Transparency = NS({ KP(0, 1), KP(0.03, 0.1), KP(0.65, 0.2), KP(1, 1) }),
				Lifetime = R(1.8), Rotation = R(0, 360), ZOffset = -0.6,
			},
		} },
		-- the release from the left palm, the drop to the ground, the shake
		{ block = "releaseFlash" },
		{ block = "airShockwave" }, -- 3D rings flying forward off the palm (1/1/2/3)
		{ block = "dropStreak" },
		{ block = "screenShake", to = 3 },
		{ block = "screenShake", from = 4, params = { frames = true } },
		-- mastery: a nimbus halo behind the head and a flattening dome
		{ block = "emitter", from = 4, params = {
			part = "Halo", partAt = HALO_AT, name = "Ring", flat = true, dir = Enum.NormalId.Back, attrs = { EmitCount = 1 },
			props = {
				Texture = id(13399941667), Color = CS(GOLD),
				Size = NS({ KP(0, 0.5), KP(0.2, 2.6), KP(1, 2.9) }), Transparency = NS({ KP(0, 0.2), KP(0.5, 0.35), KP(1, 1) }),
				Lifetime = R(0.75), LightEmission = 0.5, RotSpeed = R(45),
			},
		} },
		{ block = "emitter", from = 4, params = {
			part = "Halo", partAt = HALO_AT, name = "Rays", flat = true, dir = Enum.NormalId.Back, attrs = { EmitCount = 1 },
			props = {
				Texture = id(15773612675), Color = CS(GOLD),
				Size = NS({ KP(0, 1), KP(0.3, 3.8), KP(1, 4.4) }), Transparency = NS({ KP(0, 0.6), KP(1, 1) }),
				Lifetime = R(0.6), LightEmission = 0.6, RotSpeed = R(-20), ZOffset = -0.2,
			},
		} },
		{ block = "shockwaveShell", from = 4, params = {
			name = "Dome", mesh = id(13567208057), from = Vector3.new(2.5, 1.6, 2.5), to = Vector3.new(16, 0.4, 16),
			y0 = 0.3, y1 = 0.1, spin = 0, duration = 0.3, startTransparency = 0.55,
			startColor = Color3.fromRGB(255, 244, 214), endColor = GOLD,
		} },
		-- windup: qi gathers into the left palm
		{ block = "handGather" },
		-- each target: the burst, the 3D impact shockwave (ring, II+ swirl, III+
		-- bubble, ground shock), III+ a rock kick, IV the quake
		{ block = "impactStack" },
	},
}
