--!nocheck
-- Builds ReplicatedStorage.GuardFX (Parry, Block, GuardBreak, Hold) for
-- src/client/GuardFX.luau. Run through execute_luau in a sandbox Studio, then
-- export (tools/export_rbxm.luau) to assets/GuardFX.rbxm. Re-runnable: it
-- replaces the folder. Every emitter carries EmitCount/EmitDelay so the plugin's
-- Emit button and the Game Module play it.
--
-- Orientation contract: Parry/Block pivot at the contact point (their Core part),
-- -Z (Front) pointing along the deflect, away from the player toward the
-- attacker. GuardBreak pivots at the torso, -Z = the way the player faces.

local RS = game:GetService("ReplicatedStorage")
local old = RS:FindFirstChild("GuardFX")
if old then old:Destroy() end
local root = Instance.new("Folder")
root.Name = "GuardFX"

local A = {
	star = "rbxassetid://1053546634", -- four point star glow
	flare = "rbxassetid://13271628051", -- thin lens flare cross
	dot = "rbxassetid://9841273544", -- hard dot
	streak = "rbxassetid://9841260008", -- speed streak
	crescent = "rbxassetid://1084963972",
	arc = "rbxassetid://1266209505",
	ring = "rbxassetid://13322173171",
	ringThin = "rbxassetid://9841273159",
	ringSpiky = "rbxassetid://13052243772",
	crack = "rbxassetid://97725700315217",
	crack2 = "rbxassetid://93520831389146",
	shards = "rbxassetid://122615286116832",
	shards2 = "rbxassetid://5602763719",
	shield = "rbxassetid://132994367426450",
	puff = "rbxassetid://11037785287",
	smoke = "rbxassetid://9841261024",
}

local WHITE = Color3.fromRGB(255, 252, 238)
local GOLD = Color3.fromRGB(236, 226, 160)
local JADE = Color3.fromRGB(120, 214, 170)
local JADE_D = Color3.fromRGB(60, 150, 120)

local function seq(...) -- ColorSequence evenly spaced
	local c = { ... }
	local kp = {}
	for i, col in c do
		kp[i] = ColorSequenceKeypoint.new((i - 1) / (#c - 1), col)
	end
	return ColorSequence.new(kp)
end
local function nums(...) -- NumberSequence evenly spaced
	local n = { ... }
	local kp = {}
	for i, v in n do
		kp[i] = NumberSequenceKeypoint.new((i - 1) / (#n - 1), v)
	end
	return NumberSequence.new(kp)
end

local function part(parent, name, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.CFrame = cf or CFrame.identity
	p.Parent = parent
	return p
end

-- props: ParticleEmitter properties; count/delay become Emit attributes
local function emitter(parent, name, p, count, delay)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.LightInfluence = 0
	e.LightEmission = 1
	e.Acceleration = Vector3.zero
	e.Drag = 0
	e.RotSpeed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0)
	e.SpreadAngle = Vector2.new(0, 0)
	e.Speed = NumberRange.new(0)
	e.EmissionDirection = Enum.NormalId.Front
	e.ZOffset = 1
	e.Transparency = nums(0, 0, 1)
	for k, v in p do
		e[k] = v
	end
	e:SetAttribute("EmitCount", count)
	if delay and delay > 0 then
		e:SetAttribute("EmitDelay", delay)
	end
	e.Parent = parent
	return e
end

local FLAT = { Orientation = Enum.ParticleOrientation.VelocityPerpendicular, Speed = NumberRange.new(0.01) }
local function flat(p)
	for k, v in FLAT do
		p[k] = v
	end
	return p
end

------------------------------------------------------------------ Parry
do
	local m = Instance.new("Model")
	m.Name = "Parry"
	local core = part(m, "Core")
	m.PrimaryPart = core
	-- 1 white-hot hard dot, the flash itself
	emitter(core, "Flash", { Texture = A.dot, Color = seq(WHITE, GOLD), Size = nums(5.5, 2.5, 0), Lifetime = NumberRange.new(0.13), Transparency = nums(0, 0.1, 1), ZOffset = 2 }, 1)
	-- 2 star glint (cross), snaps and spins slightly
	emitter(core, "Glint", { Texture = A.star, Color = seq(WHITE, WHITE, GOLD), Size = nums(1, 9, 0), Lifetime = NumberRange.new(0.2), Rotation = NumberRange.new(-12, 12), RotSpeed = NumberRange.new(-60, 60), ZOffset = 3 }, 1)
	-- 3 thin lens flare cross, long and crisp (the metallic ring of steel on steel)
	emitter(core, "Flare", { Texture = A.flare, Color = seq(WHITE, GOLD), Size = nums(4, 16, 3), Lifetime = NumberRange.new(0.22), Rotation = NumberRange.new(-30, 30), RotSpeed = NumberRange.new(-20, 20), ZOffset = 3 }, 2)
	-- 4 fractured-glass crack star: the guard cracking the strike
	emitter(core, "Crack", flat({ Texture = A.crack, Color = seq(WHITE, JADE), Size = nums(3.5, 5, 6), Lifetime = NumberRange.new(0.24), Rotation = NumberRange.new(0, 360), Transparency = nums(0.1, 0.3, 1), ZOffset = 1 }), 1)
	-- 5 spark spray thrown along the deflect, streaks pointing where they fly
	emitter(core, "Sparks", { Texture = A.streak, Color = seq(WHITE, GOLD, JADE), Size = nums(1.1, 0.7, 0), Lifetime = NumberRange.new(0.16, 0.32), Speed = NumberRange.new(45, 85), SpreadAngle = Vector2.new(28, 28), Drag = 4, Orientation = Enum.ParticleOrientation.VelocityParallel, Transparency = nums(0, 0.2, 1) }, 16)
	-- 6 hot dots, heavier, with a little gravity: embers off the clash
	emitter(core, "Embers", { Texture = A.star, Color = seq(WHITE, GOLD, JADE_D), Size = nums(0.8, 0.5, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(14, 34), SpreadAngle = Vector2.new(70, 70), Drag = 3, Acceleration = Vector3.new(0, -26, 0) }, 12)
	-- 7 crescent deflect arc, two blades, each sweeping out along the deflect
	emitter(core, "Crescent", flat({ Texture = A.crescent, Color = seq(WHITE, GOLD, JADE), Size = nums(3, 6.5, 8), Lifetime = NumberRange.new(0.2), Speed = NumberRange.new(14), Rotation = NumberRange.new(-50, 50), Transparency = nums(0.05, 0.25, 1), ZOffset = 2 }), 2)
	-- 8 a thin outer arc line behind it
	emitter(core, "Arc", flat({ Texture = A.arc, Color = seq(GOLD, JADE), Size = nums(5, 10, 12), Lifetime = NumberRange.new(0.26), Speed = NumberRange.new(10), Rotation = NumberRange.new(-60, 60), Transparency = nums(0.2, 0.5, 1) }), 1, 0.02)
	-- 9 quick ring shockwave (clean), 10 thin trailing ring
	emitter(core, "Ring", flat({ Texture = A.ring, Color = seq(WHITE, GOLD, JADE), Size = nums(0.5, 6, 8), Lifetime = NumberRange.new(0.22), Transparency = nums(0, 0.3, 1) }), 1)
	emitter(core, "RingThin", flat({ Texture = A.ringThin, Color = seq(GOLD, JADE), Size = nums(1, 10, 14), Lifetime = NumberRange.new(0.32), Transparency = nums(0.2, 0.5, 1) }), 1, 0.04)
	-- 11 jade qi puff: the guard's qi bursting
	emitter(core, "Puff", { Texture = A.puff, Color = seq(GOLD, JADE, JADE_D), Size = nums(2, 7, 9), Lifetime = NumberRange.new(0.3), Transparency = nums(0.5, 0.65, 1), LightEmission = 0.8, ZOffset = 0 }, 2)
	m:SetAttribute("AuthoredRadius", 7)
	m.Parent = root
end

------------------------------------------------------------------ Block
do
	local m = Instance.new("Model")
	m.Name = "Block"
	local core = part(m, "Core")
	m.PrimaryPart = core
	-- 1 jade spark burst, small
	emitter(core, "Sparks", { Texture = A.star, Color = seq(WHITE, JADE, JADE_D), Size = nums(0.7, 0.4, 0), Lifetime = NumberRange.new(0.2, 0.4), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(65, 65), Drag = 3, Acceleration = Vector3.new(0, -14, 0) }, 7)
	-- 2 a few short streaks
	emitter(core, "Streaks", { Texture = A.streak, Color = seq(WHITE, JADE), Size = nums(0.8, 0.5, 0), Lifetime = NumberRange.new(0.12, 0.2), Speed = NumberRange.new(26, 42), SpreadAngle = Vector2.new(40, 40), Drag = 4, Orientation = Enum.ParticleOrientation.VelocityParallel }, 5)
	-- 3 faint ripple on the guard plane: a shield shape that swells and fades
	emitter(core, "Plane", flat({ Texture = A.shield, Color = seq(JADE, JADE_D), Size = nums(3.4, 3.9, 4.2), Lifetime = NumberRange.new(0.3), Transparency = nums(0.62, 0.78, 1), ZOffset = -1 }), 1)
	-- 4 ripple ring on that plane
	emitter(core, "Ripple", flat({ Texture = A.ringThin, Color = seq(WHITE, JADE), Size = nums(0.5, 3.2, 4.2), Lifetime = NumberRange.new(0.26), Transparency = nums(0.2, 0.5, 1) }), 1)
	-- 5 pinpoint flash
	emitter(core, "Flash", { Texture = A.dot, Color = seq(WHITE, JADE), Size = nums(2.2, 1, 0), Lifetime = NumberRange.new(0.1), Transparency = nums(0, 0.2, 1) }, 1)
	m.Parent = root
end

------------------------------------------------------------------ GuardBreak
do
	local m = Instance.new("Model")
	m.Name = "GuardBreak"
	local core = part(m, "Core") -- torso, -Z the way the player faces
	m.PrimaryPart = core
	local shell = part(m, "Shell", CFrame.new(0, 0, -2.4)) -- where the guard hung
	local feet = part(m, "Feet", CFrame.new(0, -2.8, 0))
	-- 1 the guard shell flashes solid, then 2 its cracks show over it
	emitter(shell, "Shell", flat({ Texture = A.shield, Color = seq(WHITE, JADE, JADE_D), Size = nums(5.2, 5.6, 6.2), Lifetime = NumberRange.new(0.3), Transparency = nums(0.15, 0.4, 1), ZOffset = 0 }), 1)
	emitter(shell, "Cracks", flat({ Texture = A.crack2, Color = seq(WHITE, WHITE), Size = nums(5, 6.5, 7), Lifetime = NumberRange.new(0.32), Rotation = NumberRange.new(0, 360), Transparency = nums(0, 0.2, 1), ZOffset = 2 }), 1)
	-- 3 big shards thrown outward, 4 small chips
	emitter(shell, "Shards", { Texture = A.shards, Color = seq(WHITE, JADE), LightEmission = 0.7, Size = nums(2.4, 2, 1.2), Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(14, 30), SpreadAngle = Vector2.new(75, 75), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-260, 260), Drag = 1.5, Acceleration = Vector3.new(0, -34, 0), Transparency = nums(0, 0.5, 1) }, 9)
	emitter(shell, "Chips", { Texture = A.shards2, Color = seq(JADE, JADE_D), LightEmission = 0.5, Size = nums(1.2, 1, 0.4), Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(10, 26), SpreadAngle = Vector2.new(90, 90), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300), Acceleration = Vector3.new(0, -40, 0), Transparency = nums(0, 0.6, 1) }, 9)
	-- 5 jade sparks all round
	emitter(shell, "Sparks", { Texture = A.star, Color = seq(WHITE, JADE, JADE_D), Size = nums(1, 0.5, 0), Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(14, 32), SpreadAngle = Vector2.new(110, 110), Drag = 2, Acceleration = Vector3.new(0, -16, 0) }, 16)
	-- 6 spiky ring shockwave
	emitter(shell, "Ring", flat({ Texture = A.ringSpiky, Color = seq(WHITE, JADE), Size = nums(1, 8, 11), Lifetime = NumberRange.new(0.3), Transparency = nums(0.05, 0.4, 1) }), 1)
	-- 7 qi puff where the shell was, 8 dust at the feet
	emitter(shell, "Puff", { Texture = A.puff, Color = seq(JADE, JADE_D), Size = nums(3, 9, 11), Lifetime = NumberRange.new(0.4), Transparency = nums(0.45, 0.65, 1), LightEmission = 0.6, ZOffset = 0 }, 2)
	emitter(feet, "Dust", { Texture = A.smoke, Color = seq(Color3.fromRGB(190, 186, 170), Color3.fromRGB(150, 146, 134)), LightEmission = 0, Size = nums(2, 5, 7), Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(180, 180), EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), Drag = 3, Transparency = nums(0.5, 0.65, 1), ZOffset = 0 }, 7)
	m.Parent = root
end

------------------------------------------------------------------ Hold (forearm shimmer)
do
	local at = Instance.new("Attachment")
	at.Name = "Hold"
	local e = emitter(at, "Shimmer", { Texture = A.star, Color = seq(WHITE, JADE), Size = nums(0, 0.5, 0), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), EmissionDirection = Enum.NormalId.Top, Transparency = nums(1, 0.55, 1), Rate = 3 }, 1)
	e.Rate = 3
	e.Enabled = false
	at.Parent = root
end

root.Parent = RS
return "built"
