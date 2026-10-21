--!nocheck
-- Builder for ReplicatedStorage.WorldFX (assets/WorldFX.rbxm): the sky-scale world
-- event kit drawn by src/client/WorldFX/*. Run through execute_luau in Edit mode
-- (served by tools/receive_rbxmx.py; tools/ensure_receiver.sh):
--   local m = Instance.new("ModuleScript"); m.Source = game:GetService("HttpService"):GetAsync(
--     "http://127.0.0.1:8766/worldfx_build.luau"); require(m)
--   local staging = _G.worldfxStage.begin()     -- ReplicatedStorage._StagingWorldFX
--   _G.worldfxBuild(staging, { only = { "LightPillar" } })  -- or nil for every piece
--   _G.worldfxStage.finish()                     -- export to tools/frag/WorldFX.rbxm, destroy staging
-- then copy tools/frag/WorldFX.rbxm to assets/WorldFX.rbxm (Rojo patches the live folder).
-- Pieces (each a Model, PrimaryPart nil, identity WorldPivot at its ground point):
--   Grade        ColorCorrectionEffect cloned into Lighting by SkyGrade (pulses)
--   LightPillar  ground-to-sky pillar: Core/Body/Haze/Flow beams, rising streaks and
--                motes, a glowing puncture ring where it crosses the cloud plane
--                (WorldY 441), a landing burst
-- Tint attributes ("core", "color", "accent", "dark") are painted by Kit.paint.
-- Asset ids are picked for these pieces from their own references
-- (docs/reference/vfx/README.md, world events), not carried over from other effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local function id(n)
	return "rbxassetid://" .. tostring(n)
end

local A = {
	band = id(2382169232), -- soft vertical band: bright centre, soft edges (beam body)
	bands = id(9841273413), -- soft streaky bands (flowing layer)
	sliver = id(11226108137), -- thin vertical sliver (streaks)
	dot = id(9841273544), -- hard dot (flash, motes)
	star = id(3060556198), -- 4-point star glint
	lens = id(14684195806), -- horizontal lens streak
	ringSoft = id(7216854285), -- soft round ring
	ringFine = id(12362706897), -- fine lined ring (shock)
	puff = id(258128463), -- cloud puff
}
_G.WorldFXAssets = A

local function noPhysics(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
end

local function attrs(inst, t)
	for k, v in t or {} do
		inst:SetAttribute(k, v)
	end
	return inst
end

local function set(inst, props)
	for k, v in props or {} do
		inst[k] = v
	end
	return inst
end

local function ns(...)
	local args = { ... }
	if #args == 1 then
		return NumberSequence.new(args[1])
	end
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function part(name, parent, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	noPhysics(p)
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = cf or CFrame.new()
	p.Parent = parent
	return p
end

local function att(name, parent, pos, a)
	local x = Instance.new("Attachment")
	x.Name = name
	x.Position = pos or Vector3.zero
	attrs(x, a)
	x.Parent = parent
	return x
end

local function beam(name, a0, a1, props, a)
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.LightInfluence = 0
	b.TextureMode = Enum.TextureMode.Stretch
	set(b, props)
	attrs(b, a)
	b.Parent = a0.Parent
	return b
end

local function emitter(name, parent, props, a)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.Enabled = false
	set(e, props)
	attrs(e, a)
	e.Parent = parent
	return e
end

local function model(name, parent, a)
	local m = Instance.new("Model")
	m.Name = name
	attrs(m, a)
	m.Parent = parent
	return m
end

local function finishModel(m)
	m.WorldPivot = CFrame.new() -- upright pivot at the ground point (PrimaryPart nil)
	return m
end

local Build = {}

function Build.Grade(root)
	local g = Instance.new("ColorCorrectionEffect")
	g.Name = "Grade"
	g.Enabled = false
	g.Parent = root
	return g
end

-- Authored for the large (anomaly) size; Kit/Pillar scales widths by the def's scale.
function Build.LightPillar(root)
	local m = model("LightPillar", root, { TopWorldY = 1400, PlaneY = 441 })
	local shaft = part("Shaft", m)
	local bottom = att("Bottom", shaft, Vector3.new(0, 0.5, 0))
	local top = att("Top", shaft, Vector3.new(0, 1000, 0), { WorldY = 1400 })
	local fadeTop = ns(0, 0, 0.75, 0.05, 1, 1)
	-- far: a white-hot core, a coloured body and a wide haze (the far-read test:
	-- the core carries through haze, the colour needs the sky grade's clear-up)
	beam("Core", bottom, top, { Width0 = 8, Width1 = 8, Brightness = 6, LightEmission = 1, Texture = A.band, Transparency = fadeTop, ZOffset = 3 }, { Tint = "core" })
	beam("Body", bottom, top, { Width0 = 50, Width1 = 44, Brightness = 3, LightEmission = 1, Texture = A.band, Transparency = ns(0, 0.05, 0.7, 0.2, 1, 1), ZOffset = 2 }, { Tint = "color" })
	beam("Haze", bottom, top, { Width0 = 180, Width1 = 150, Brightness = 2, LightEmission = 0.5, Texture = A.band, Transparency = ns(0, 0.25, 0.6, 0.5, 1, 1), ZOffset = 1 }, { Tint = "accent" })
	-- mid: streaky light flowing up the body
	beam("Flow", bottom, top, {
		Width0 = 30, Width1 = 26, Brightness = 4, LightEmission = 1, Texture = A.bands,
		TextureMode = Enum.TextureMode.Wrap, TextureLength = 160, TextureSpeed = 0.35,
		Transparency = ns(0, 0.45, 0.6, 0.6, 1, 1), ZOffset = 2,
	}, { Tint = "core", TintMix = 0.5 })

	-- mid: streaks shooting up and motes rising round the foot (lower 400 studs)
	local rise = part("Rise", m, Vector3.new(16, 400, 16), CFrame.new(0, 200, 0))
	emitter("Streaks", rise, {
		Texture = A.sliver, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
		Speed = NumberRange.new(70, 120), Lifetime = NumberRange.new(2, 3), Rate = 10,
		Size = ns(0, 4, 0.5, 6, 1, 2), Transparency = ns(0, 1, 0.15, 0.1, 0.8, 0.3, 1, 1),
		LightEmission = 1, Brightness = 4, SpreadAngle = Vector2.new(2, 2),
	}, { Tint = "core", TintMix = 0.6, Layer = "mid" })
	emitter("Motes", rise, {
		Texture = A.dot, EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
		Speed = NumberRange.new(10, 26), Lifetime = NumberRange.new(4, 7), Rate = 14,
		Size = ns(0, 0.6, 0.5, 1.1, 1, 0), Transparency = ns(0, 1, 0.2, 0.1, 0.8, 0.2, 1, 1),
		LightEmission = 1, Brightness = 3, SpreadAngle = Vector2.new(25, 25),
		RotSpeed = NumberRange.new(-40, 40),
	}, { Tint = "accent", TintMix = 0.8, Layer = "mid" })

	-- far: where it pierces the cloud plane, a glowing ring and tinted billows
	local puncture = part("Puncture", m, Vector3.new(30, 0.2, 30), CFrame.new(0, 441, 0))
	attrs(puncture, { WorldY = 441 })
	emitter("Ring", puncture, {
		Texture = A.ringSoft, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01), Shape = Enum.ParticleEmitterShape.Box,
		Lifetime = NumberRange.new(6), Rate = 0.6, Size = ns(0, 50, 1, 140),
		Transparency = ns(0, 1, 0.2, 0.2, 1, 1), LightEmission = 1, Brightness = 3,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-8, 8), ZOffset = 1,
	}, { Tint = "color", Layer = "far" })
	emitter("Billow", puncture, {
		Texture = A.puff, EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Box,
		Speed = NumberRange.new(4, 10), SpreadAngle = Vector2.new(70, 70),
		Lifetime = NumberRange.new(6, 9), Rate = 3, Size = ns(0, 18, 0.5, 40, 1, 55),
		Transparency = ns(0, 1, 0.25, 0.35, 0.7, 0.5, 1, 1), LightEmission = 0.4, Brightness = 2,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-10, 10),
	}, { Tint = "accent", TintMix = 0.55, Layer = "far" })

	-- close: the landing burst (played once by the drive beat)
	local landing = part("Landing", m, Vector3.new(4, 0.2, 4), CFrame.new(0, 0.3, 0))
	emitter("Flash", landing, {
		Texture = A.dot, Lifetime = NumberRange.new(0.35), Speed = NumberRange.new(0),
		Size = ns(0, 10, 0.3, 45, 1, 60), Transparency = ns(0, 0, 0.5, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, ZOffset = 4,
	}, { Tint = "core", EmitCount = 1 })
	emitter("Glint", landing, {
		Texture = A.star, Lifetime = NumberRange.new(0.7), Speed = NumberRange.new(0),
		Size = ns(0, 6, 0.2, 40, 1, 0), Transparency = ns(0, 0, 0.7, 0.2, 1, 1),
		LightEmission = 1, Brightness = 8, ZOffset = 5,
	}, { Tint = "core", EmitCount = 1 })
	emitter("Lens", landing, {
		Texture = A.lens, Lifetime = NumberRange.new(0.6), Speed = NumberRange.new(0),
		Size = ns(0, 10, 0.2, 70, 1, 20), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 6, ZOffset = 5,
	}, { Tint = "color", TintMix = 0.6, EmitCount = 1 })
	emitter("Shock", landing, {
		Texture = A.ringFine, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.01),
		Lifetime = NumberRange.new(0.9), Size = ns(0, 2, 1, 70), Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
		LightEmission = 1, Brightness = 4,
	}, { Tint = "color", EmitCount = 1 })
	emitter("Rays", landing, {
		Texture = A.sliver, Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(90, 160), SpreadAngle = Vector2.new(85, 85),
		Lifetime = NumberRange.new(0.35, 0.6), Size = ns(0, 3, 1, 1), Transparency = ns(0, 0, 1, 1),
		LightEmission = 1, Brightness = 5, Drag = 4,
	}, { Tint = "core", TintMix = 0.7, EmitCount = 24 })
	return finishModel(m)
end

local ORDER = { "Grade", "LightPillar" }

_G.worldfxBuild = function(root, opts)
	opts = opts or {}
	local only = opts.only and {} or nil
	for _, n in opts.only or {} do
		only[n] = true
	end
	for _, name in ORDER do
		if not only or only[name] then
			local old = root:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			Build[name](root)
		end
	end
	return root
end

-- Staging (AGENTS.md "Studio instances"): never edit the Rojo-managed folder in place.
local Stage = {}
local NAME = "_StagingWorldFX"

function Stage.begin()
	assert(not ReplicatedStorage:FindFirstChild(NAME), "a _StagingWorldFX exists already: finish or destroy it first")
	local live = ReplicatedStorage:FindFirstChild("WorldFX")
	local staging
	if live then
		staging = live:Clone()
	else
		staging = Instance.new("Folder")
	end
	staging.Name = NAME
	staging.Parent = ReplicatedStorage
	return staging
end

function Stage.finish()
	local staging = ReplicatedStorage:FindFirstChild(NAME)
	assert(staging, "no staging copy")
	if not _G.exportRbxm then
		local m = Instance.new("ModuleScript")
		m.Source = HttpService:GetAsync("http://127.0.0.1:8766/export_rbxm.luau")
		require(m)
	end
	HttpService:PostAsync("http://127.0.0.1:8766/WorldFX.rbxm", _G.exportRbxm("ReplicatedStorage." .. NAME, "WorldFX"))
	staging:Destroy()
	return "exported tools/frag/WorldFX.rbxm; copy it to assets/WorldFX.rbxm"
end

-- After copying the file: does the live folder hold exactly one copy with these pieces?
function Stage.synced(names)
	local copies = 0
	for _, c in ReplicatedStorage:GetChildren() do
		if c.Name == "WorldFX" then
			copies += 1
		end
	end
	local live = ReplicatedStorage:FindFirstChild("WorldFX")
	local missing = {}
	for _, n in names or ORDER do
		if not (live and live:FindFirstChild(n)) then
			table.insert(missing, n)
		end
	end
	return copies, missing
end

_G.worldfxStage = Stage
return true
