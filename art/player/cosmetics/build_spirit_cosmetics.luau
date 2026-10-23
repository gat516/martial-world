--!nocheck
-- Spirit race looks: Accessory prototypes for Stone Spirit, Dragonblood,
-- Demonic Human and Ghost, in the fox and Beast Folk shape language (plain
-- SmoothPlastic, Neon only where something glows).
-- Run in Edit mode through the Studio MCP (execute_luau, or loadstring from the
-- served worktree). It (re)builds ReplicatedStorage.Cosmetics.Spirits (a Folder
-- of 4 Accessories); nothing else. Export that folder to
-- assets/Cosmetics/Spirits.rbxm with tools/export_rbxm.luau.
--
-- Space: each accessory is built in its Handle's space (Handle at the origin,
-- identity rotation). The character faces -Z, its left is -X, +Y is up.
--   Horns (HatAttachment): origin = the R6 Head's HatAttachment (0.6 above the
--     head centre; head top at -0.1, front at Z -0.6, normal hair top ~0.27).
--   StoneShards, GhostWisps (BodyBackAttachment): origin = the Torso's back
--     surface centre. The torso spans X -1..1, Y -1..1, Z -1..0 here; the arms
--     hang outboard of |X| 1 and swing about (±1.5, 0.5, -0.5), so their top
--     corners reach Y ~1.2 in a walk. Nothing sits outboard of |X| 0.95 below Y 1.3.
-- Joints are Motor6Ds whose frames are identity in Handle space at rest, so
-- Transform rotates about the character's axes: X pitches, Y yaws, Z rolls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Palette ---------------------------------------------------------------------
local STONE = Color3.fromRGB(152, 140, 122) -- grey-brown
local STONE_DARK = Color3.fromRGB(114, 104, 92)
local STONE_LIGHT = Color3.fromRGB(178, 168, 150)
local JADE_VEIN = Color3.fromRGB(56, 176, 112) -- Neon: saturated mid tone so it glows jade, not white
local IVORY = Color3.fromRGB(238, 228, 204)
local IVORY_GOLD = Color3.fromRGB(230, 204, 142)
local PALE_GOLD = Color3.fromRGB(214, 170, 78)
local DEMON_BLACK = Color3.fromRGB(40, 30, 36)
local DEMON_MID = Color3.fromRGB(100, 22, 32)
local DEMON_CRIMSON = Color3.fromRGB(170, 26, 40)
local SOUL_CORE = Color3.fromRGB(110, 180, 255) -- saturated enough not to bloom to white
local SOUL_SHELL = Color3.fromRGB(90, 150, 255)
local MIST = Color3.fromRGB(190, 220, 255)

-- DragonHorns: antler beams rise from the temples and sweep back, two tines each.
-- Points are for the left horn (s = -1); the right mirrors X.
local DRAGON_BEAM = {
	Vector3.new(0.30, 0.08, 0.05),
	Vector3.new(0.46, 0.56, 0.28),
	Vector3.new(0.62, 0.92, 0.66),
	Vector3.new(0.72, 1.1, 1.16),
}
local DRAGON_BEAM_D = { 0.3, 0.23, 0.16 }
local DRAGON_BEAM_COL = { IVORY, IVORY_GOLD, PALE_GOLD }
-- { along beam segment (index, fraction), offset to tip, diameter }
local DRAGON_TINES = {
	{ 1, 0.85, Vector3.new(0.06, 0.44, -0.18), 0.15 },
	{ 2, 0.8, Vector3.new(0.08, 0.42, 0.0), 0.12 },
}
local HORN_OVERLAP = 1.35 -- ellipsoid length / segment length

-- DemonHorns: short, thick at the root, from the upper forehead, rising out and
-- hooking forward at the tip (no tines, swept forward, not back).
local DEMON_PATH = {
	Vector3.new(0.30, 0.14, -0.22),
	Vector3.new(0.46, 0.5, -0.22),
	Vector3.new(0.56, 0.8, -0.3),
	Vector3.new(0.5, 1.02, -0.5),
}
local DEMON_D = { 0.32, 0.23, 0.14 }
local DEMON_COL = { DEMON_BLACK, DEMON_MID, DEMON_CRIMSON }

-- StoneShards: { root, direction (up/back/out, normalised later), width, depth,
-- body height, cap height, colour, vein }. Roots sit just inside the torso top.
local SHARDS = {
	{ Vector3.new(-0.75, 0.9, -0.44), Vector3.new(-0.32, 1, 0.25), 0.34, 0.34, 0.72, 0.42, STONE, true },
	{ Vector3.new(-0.74, 0.9, -0.76), Vector3.new(-0.5, 1, -0.2), 0.26, 0.26, 0.36, 0.26, STONE_LIGHT, false },
	{ Vector3.new(0.74, 0.9, -0.42), Vector3.new(0.34, 1, 0.3), 0.32, 0.32, 0.62, 0.38, STONE, true },
	{ Vector3.new(0.74, 0.88, -0.74), Vector3.new(0.55, 1, -0.15), 0.24, 0.24, 0.34, 0.24, STONE_LIGHT, false },
	{ Vector3.new(-0.3, 0.42, -0.08), Vector3.new(-0.3, 1, 0.75), 0.32, 0.3, 0.45, 0.3, STONE_DARK, true },
	{ Vector3.new(0.26, 0.56, -0.08), Vector3.new(0.3, 1, 0.8), 0.24, 0.24, 0.34, 0.24, STONE_DARK, false },
}
-- crust plates the shards grow from, flat on the shoulder tops
local CRUST = {
	{ Vector3.new(-0.75, 1.0, -0.42), Vector3.new(0.34, 0.12, 0.54), 8 },
	{ Vector3.new(0.75, 1.0, -0.42), Vector3.new(0.34, 0.12, 0.52), -10 },
}

-- GhostWisps: { name, position, size } of each soul flame
local WISPS = {
	{ "WispL", Vector3.new(-1.08, 1.42, -0.45), 0.32 },
	{ "WispR", Vector3.new(1.08, 1.46, -0.4), 0.28 },
	{ "WispBack", Vector3.new(-0.15, 0.4, 0.85), 0.3 },
}
---------------------------------------------------------------------------

local function style(p, color)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	return p
end

local function weld(p0, p1)
	local w = Instance.new("Weld")
	w.Name = "Weld_" .. p1.Name
	w.Part0, w.Part1 = p0, p1
	w.C0 = p0.CFrame:Inverse() * p1.CFrame
	w.C1 = CFrame.identity
	w.Parent = p1
end

local function motor(name, p0, p1, pivot)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = p0, p1
	m.C0 = p0.CFrame:Inverse() * CFrame.new(pivot)
	m.C1 = p1.CFrame:Inverse() * CFrame.new(pivot)
	m.Parent = p0
	return m
end

local function accessory(name, kind, attName, parent)
	local acc = Instance.new("Accessory")
	acc.Name = name
	acc.AccessoryType = kind
	local h = style(Instance.new("Part"), Color3.new(1, 1, 1))
	h.Name = "Handle"
	h.Size = Vector3.new(0.2, 0.2, 0.2)
	h.Transparency = 1
	h.CastShadow = false
	h.CFrame = CFrame.identity
	h.Parent = acc
	local att = Instance.new("Attachment")
	att.Name = attName
	att.Parent = h
	acc.Parent = parent
	return acc, h
end

local function ellipsoid(name, cf, size, color, parent)
	local p = style(Instance.new("Part"), color)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	local mesh = Instance.new("SpecialMesh") -- fills the box; ScaleTo scales it with the part
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

-- An ellipsoid spanning a..b (overlapping past both ends), long axis along a->b
local function span(name, a, b, d, color, parent, overlap)
	return ellipsoid(name, CFrame.lookAt((a + b) / 2, b), Vector3.new(d, d, (b - a).Magnitude * (overlap or HORN_OVERLAP)), color, parent)
end

local function mirror(v, s)
	return Vector3.new(v.X * s, v.Y, v.Z)
end

local root = ReplicatedStorage:FindFirstChild("Cosmetics")
if not root then
	root = Instance.new("Folder")
	root.Name = "Cosmetics"
	root.Parent = ReplicatedStorage
end
local old = root:FindFirstChild("Spirits")
if old then
	old:Destroy()
end
local set = Instance.new("Folder")
set.Name = "Spirits"

-- A horn from a point path: segment 1 is the primary (jointed at the root),
-- the rest are welded to it. Returns the segment parts.
local function horn(acc, handle, prefix, jointName, path, diam, cols, s)
	local segs = {}
	for i = 1, #diam do
		local a, b = mirror(path[i], s), mirror(path[i + 1], s)
		local overlap = (i == #diam) and 1.15 or HORN_OVERLAP -- tip ends near its point
		local p = span(i == 1 and prefix or (prefix .. "Seg" .. i), a, b, diam[i], cols[i], acc, overlap)
		if i == 1 then
			motor(jointName, handle, p, a)
		else
			weld(segs[1], p)
		end
		segs[i] = p
	end
	return segs
end

-- StoneShards -------------------------------------------------------------------
do
	local acc, handle = accessory("StoneShards", Enum.AccessoryType.Back, "BodyBackAttachment", set)
	for i, c in CRUST do
		local p = style(Instance.new("Part"), STONE_DARK)
		p.Name = "ShardCrust" .. i
		p.Size = c[2]
		p.CFrame = CFrame.new(c[1]) * CFrame.Angles(0, math.rad(c[3]), 0)
		p.Parent = acc
		weld(handle, p)
	end
	for i, sh in SHARDS do
		local rootPos, dir, w, t, h, capH, col, vein = sh[1], sh[2].Unit, sh[3], sh[4], sh[5], sh[6], sh[7], sh[8]
		-- frame: Y along the shard, faces turned a little about it so the set looks jagged
		local frame = CFrame.lookAt(rootPos, rootPos + dir) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.rad(35 + i * 17), 0)
		local body = style(Instance.new("Part"), col)
		body.Name = "Shard" .. i
		body.Size = Vector3.new(w, h, t)
		body.CFrame = frame * CFrame.new(0, h / 2, 0)
		body.Parent = acc
		weld(handle, body)
		-- chisel cap: a wedge of the same footprint, its slope facing outward
		local cap = style(Instance.new("WedgePart"), col)
		cap.Name = "Shard" .. i .. "Cap"
		cap.Size = Vector3.new(w, capH, t)
		cap.CFrame = frame * CFrame.new(0, h + capH / 2 - 0.01, 0)
		cap.Parent = acc
		weld(body, cap)
		if vein then
			-- jade vein: a thin Neon inset flush on both broad faces of the shard
			for k, side in { 1, -1 } do
				local v = style(Instance.new("Part"), JADE_VEIN)
				v.Material = Enum.Material.Neon
				v.Name = "Shard" .. i .. "Vein" .. k
				v.Size = Vector3.new(0.1, h * 0.7, 0.05)
				v.CFrame = frame * CFrame.new(side * w * 0.1, h * 0.5, side * (t / 2 - 0.015)) * CFrame.Angles(0, 0, math.rad(side * 14))
				v.Parent = acc
				weld(body, v)
			end
		end
	end
end

-- DragonHorns -------------------------------------------------------------------
do
	local acc, handle = accessory("DragonHorns", Enum.AccessoryType.Hat, "HatAttachment", set)
	for _, side in { { "Left", -1, "HornL" }, { "Right", 1, "HornR" } } do
		local name, s = side[1] .. "Horn", side[2]
		local segs = horn(acc, handle, name, side[3], DRAGON_BEAM, DRAGON_BEAM_D, DRAGON_BEAM_COL, s)
		for k, tn in DRAGON_TINES do
			local a0, b0 = DRAGON_BEAM[tn[1]], DRAGON_BEAM[tn[1] + 1]
			local a = mirror(a0:Lerp(b0, tn[2]), s)
			local b = a + mirror(tn[3], s)
			weld(segs[1], span(name .. "Tine" .. k, a, b, tn[4], PALE_GOLD, acc, 1.2))
		end
	end
end

-- DemonHorns --------------------------------------------------------------------
do
	local acc, handle = accessory("DemonHorns", Enum.AccessoryType.Hat, "HatAttachment", set)
	for _, side in { { "Left", -1, "HornL" }, { "Right", 1, "HornR" } } do
		horn(acc, handle, side[1] .. "Horn", side[3], DEMON_PATH, DEMON_D, DEMON_COL, side[2])
	end
end

-- GhostWisps --------------------------------------------------------------------
do
	local acc, handle = accessory("GhostWisps", Enum.AccessoryType.Back, "BodyBackAttachment", set)
	for i, wd in WISPS do
		local name, pos, r = wd[1], wd[2], wd[3]
		-- teardrop: a round core, a flame tongue rising from it, a faint outer shell
		local core = ellipsoid(name, CFrame.new(pos), Vector3.new(r, r * 0.95, r), SOUL_CORE, acc)
		core.Material = Enum.Material.Neon
		core.Transparency = 0.35
		core.CastShadow = false
		local lean = (pos.X < -0.5 and 1) or (pos.X > 0.5 and -1) or 0 -- +Z roll tips the top toward -X
		local tongue = ellipsoid(name .. "Flame", CFrame.new(pos + Vector3.new(-lean * r * 0.15, r * 0.6, 0)) * CFrame.Angles(0, 0, math.rad(lean * 13)), Vector3.new(r * 0.5, r * 1.5, r * 0.5), SOUL_CORE, acc)
		tongue.Material = Enum.Material.Neon
		tongue.Transparency = 0.4
		tongue.CastShadow = false
		weld(core, tongue)
		local shell = ellipsoid(name .. "Shell", CFrame.new(pos + Vector3.new(0, r * 0.25, 0)), Vector3.new(r * 1.45, r * 1.9, r * 1.45), SOUL_SHELL, acc)
		shell.Material = Enum.Material.Neon
		shell.Transparency = 0.78
		shell.CastShadow = false
		weld(core, shell)
		motor("Wisp" .. i, handle, core, pos)
	end
	-- one faint, slow mist trail behind the back (phone-light: ~3 particles alive)
	local at = Instance.new("Attachment")
	at.Name = "MistFX"
	at.Position = Vector3.new(0, 0.4, 0.5)
	at.Parent = handle
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Mist"
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(MIST)
	pe.LightEmission = 0.3
	pe.Rate = 1.2
	pe.Lifetime = NumberRange.new(2.5, 3.5)
	pe.Speed = NumberRange.new(0.15, 0.35)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Acceleration = Vector3.new(0, 0.12, 0)
	pe.EmissionDirection = Enum.NormalId.Back
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.8) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-10, 10)
	pe.Parent = at
end

set.Parent = root
local counts = {}
for _, acc in set:GetChildren() do
	local n = 0
	for _, d in acc:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(counts, acc.Name .. "=" .. n)
end
table.sort(counts)
return "built Spirits: " .. table.concat(counts, " ")
