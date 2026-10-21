--[[
Points of interest for the first two wilds zones: themed landmarks along or just off the paths, built from
plain parts (textured materials, palette colours from docs/systems/map.md) plus ServerStorage.WildsKit /
AssetLibrary pieces. Visual only: no scripts, prompts or gameplay hooks (the map doc lists where hooks
could go later). Run in Studio Edit mode after wilds_layout.luau, terrain_wilds.luau and dress_wilds.luau
(it uses ServerStorage.WildsKit).

  _G.WILDS_POI = { zones = { "Inner", "Middle" } }

Rebuilds Map.Ground.Wilds<Zone>.POIs (one Model per POI). Heights come from terrain raycasts, so it
follows the ground whatever the terrain pass did. Collision: walls, pillars, steps, stones and the bridge
deck collide; cloth, bones, debris, plants and roof shards don't (CanQuery off too, so they never catch a
spawn or treasure raycast). The bridge's arch mesh is visual; an invisible stepped deck carries players.
Lamps are Models named "StoneLantern" / "Lantern" (Config.Ambience.LAMP_MODELS), so DayNight dims them by
day and brightens them at night. VFX points are Attachments named FX_<What> on invisible anchor parts.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local LAYOUT = _G.WILDS_LAYOUT
assert(LAYOUT, "run art/wilds/wilds_layout.luau first")
local CFG = _G.WILDS_POI or {}
_G.WILDS_POI = nil
local KIT = SS:WaitForChild("WildsKit")
local LIB = SS.AssetLibrary
local TEMPLATES = SS._Templates

local C = {
	stone = Color3.fromHex("8E8983"),
	stoneMid = Color3.fromHex("7A7570"),
	stoneDark = Color3.fromHex("615D59"),
	stoneDeep = Color3.fromHex("4D4A47"),
	moss = Color3.fromHex("4E6B45"),
	mossLight = Color3.fromHex("56744A"),
	wood = Color3.fromHex("5A3F2E"),
	woodDark = Color3.fromHex("3F2C21"),
	char = Color3.fromHex("2B2420"),
	lacquer = Color3.fromHex("74201C"),
	lacquerFaded = Color3.fromHex("7E3A30"),
	roof = Color3.fromHex("33403F"),
	roofAsh = Color3.fromHex("3E4644"),
	jade = Color3.fromHex("5FAE96"),
	gold = Color3.fromHex("8E6E30"),
	earth = Color3.fromHex("8A7A62"),
	earthDark = Color3.fromHex("6E6150"),
	bone = Color3.fromHex("D9D0BC"),
	cloth = Color3.fromHex("6E2A24"),
	hide = Color3.fromHex("7A5A3E"),
	ember = Color3.fromHex("FF8A3D"),
	ghost = Color3.fromHex("7FE0C0"),
}
local M = Enum.Material

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 150, z), Vector3.new(0, -250, 0), terrainParams)
	return hit and hit.Position.Y or 4
end
local function G(x, z, up)
	return Vector3.new(x, gy(x, z) + (up or 0), z)
end

local partCount = 0
-- a part; opts: nc (no collision/query), shadow (default true), shape, trans
local function P(parent, name, size, cf, color, mat, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Slate
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.nc then
		p.CanCollide = false
		p.CanQuery = false
	end
	p.CastShadow = opts.shadow ~= false
	if opts.trans then
		p.Transparency = opts.trans
	end
	p.Parent = parent
	partCount += 1
	return p
end

-- a kit / library piece; pos is a ground point; sink is the fraction of its height pushed below
local function worldSpanY(inst)
	local minY, maxY = math.huge, -math.huge
	for _, p in (inst:IsA("BasePart") and { inst } or inst:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, s = p.CFrame, p.Size / 2
			local ext = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
			minY = math.min(minY, cf.Position.Y - ext)
			maxY = math.max(maxY, cf.Position.Y + ext)
		end
	end
	return minY, maxY
end
local function Kp(parent, src, pos, yaw, scale, opts)
	opts = opts or {}
	if type(src) == "string" then
		src = KIT:FindFirstChild(src)
	end
	assert(src, "missing kit piece")
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local rot = (if c:IsA("Model") then c:GetPivot() else c.CFrame).Rotation
	local spin = CFrame.Angles(0, yaw or 0, 0) * (opts.tilt or CFrame.identity)
	if c:IsA("Model") then
		if scale and scale ~= 1 then
			c:ScaleTo(c:GetScale() * scale)
		end
		c:PivotTo(CFrame.new(pos) * spin * rot)
	else
		if scale then
			c.Size *= scale
		end
		c.CFrame = CFrame.new(pos) * spin * rot
	end
	if not opts.raw then
		local minY, maxY = worldSpanY(c)
		local drop = (minY - pos.Y) + (maxY - minY) * (opts.sink or 0.05)
		if c:IsA("Model") then
			c:PivotTo(c:GetPivot() - Vector3.new(0, drop, 0))
		else
			c.CFrame -= Vector3.new(0, drop, 0)
		end
	end
	for _, p in (c:IsA("BasePart") and { c } or c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			if opts.collide then
				p.CanCollide = true
				p.CanQuery = true
				if p:IsA("MeshPart") then
					pcall(function()
						p.CollisionFidelity = Enum.CollisionFidelity.Hull
					end)
				end
			else
				p.CanCollide = false
				p.CanQuery = false
				if p:IsA("MeshPart") then
					pcall(function()
						p.CollisionFidelity = Enum.CollisionFidelity.Box
					end)
				end
			end
			partCount += 1
		end
	end
	if opts.name then
		c.Name = opts.name
	end
	c.Parent = parent
	return c
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- a named VFX point (Attachment on an invisible anchor) for the vfx pass
local function fx(parent, name, cf, size)
	local a = P(parent, name .. "Anchor", size or Vector3.new(1, 1, 1), cf, C.stone, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 })
	local att = Instance.new("Attachment")
	att.Name = name
	att.Parent = a
	return att
end

-- a stone lantern with a warm light that follows day/night (model named StoneLantern)
local function stoneLantern(parent, pos, yaw, color)
	local m = TEMPLATES.FX_StoneLantern:Clone()
	m.Name = "StoneLantern"
	local _, s = m:GetBoundingBox()
	m:PivotTo(CFrame.new(pos + Vector3.new(0, s.Y / 2 - 0.3, 0)) * CFrame.Angles(0, yaw or 0, 0))
	local flame = m:FindFirstChild("Flame")
	if flame then
		local light = Instance.new("PointLight")
		light.Color = color or Color3.fromHex("FFB56B")
		light.Range = 14
		light.Brightness = 0.9
		light.Shadows = false
		light.Parent = flame
		if color then
			flame.Color = color
		end
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			partCount += 1
		end
	end
	m.Parent = parent
	return m
end

-- a column of rough stone blocks (pillar), optionally broken off at a height
local function pillar(parent, base, height, w, color, tiltZ)
	local segs = math.max(1, math.floor(height / 4))
	local y = 0
	local cf = CFrame.new(base) * CFrame.Angles(0, 0, tiltZ or 0)
	for i = 1, segs do
		local h = height / segs
		local inset = (i % 2 == 0) and 0.3 or 0
		P(parent, "PillarStone", Vector3.new(w - inset, h - 0.15, w - inset), cf * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, math.rad((i * 7) % 11 - 5), 0), i % 2 == 0 and C.stoneMid or color or C.stone, M.Slate)
		y += h
	end
	return cf * CFrame.new(0, y, 0)
end

-- moss cap: a thin irregular slab of moss on top of something
local function moss(parent, cf, size)
	P(parent, "Moss", size, cf, math.random() < 0.5 and C.moss or C.mossLight, M.LeafyGrass, { nc = true, shadow = false })
end

-- a ruined wall run from a to b (stone footing + rammed earth, ragged top, gaps)
local function ruinWall(parent, a, b, height, thick, rng, opts)
	opts = opts or {}
	local dir = (b - a)
	local len = dir.Magnitude
	dir = dir.Unit
	local n = math.max(1, math.floor(len / 4))
	local seg = len / n
	local yaw = math.atan2(-dir.Z, dir.X)
	for i = 0, n - 1 do
		if rng:NextNumber() < (opts.gaps or 0.12) then
			continue
		end
		local mid = a + dir * (seg * (i + 0.5))
		local g = gy(mid.X, mid.Z)
		local h = height * rng:NextNumber(0.35, 1)
		local rot = CFrame.Angles(0, yaw, 0)
		P(parent, "Footing", Vector3.new(seg + 0.2, 1.6, thick + 0.8), CFrame.new(mid.X, g + 0.3, mid.Z) * rot, C.stoneDark, M.Slate)
		P(parent, "Wall", Vector3.new(seg + 0.05, h, thick), CFrame.new(mid.X, g + 1.1 + h / 2, mid.Z) * rot * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-2, 2))), opts.color or (i % 2 == 0 and C.earth or C.earthDark), opts.mat or M.Ground)
		if opts.char and rng:NextNumber() < 0.3 then
			P(parent, "Scorch", Vector3.new(seg * 0.6, h * 0.5, thick + 0.1), CFrame.new(mid.X, g + 1.1 + h * 0.7, mid.Z) * rot, C.char, M.Ground, { nc = true })
		end
	end
end

-- scattered rubble pieces around a point
local function rubble(parent, centre, radius, count, rng, mat, color)
	for _ = 1, count do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, radius)
		local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
		local s = rng:NextNumber(0.6, 2.2)
		P(parent, "Rubble", Vector3.new(s * 1.4, s * 0.7, s), CFrame.new(x, gy(x, z) + s * 0.2, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)), color or C.stoneMid, mat or M.Slate, { nc = true })
	end
end

-- bones: long bones and a skull-ish lump
local function bones(parent, centre, radius, count, rng)
	for _ = 1, count do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, radius)
		local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
		local l = rng:NextNumber(1.6, 3.4)
		P(parent, "Bone", Vector3.new(l, 0.45, 0.45), CFrame.new(x, gy(x, z) + 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), C.bone, M.SmoothPlastic, { nc = true, shadow = false, shape = Enum.PartType.Cylinder })
	end
	local x, z = centre.X + rng:NextNumber(-radius, radius) * 0.5, centre.Z + rng:NextNumber(-radius, radius) * 0.5
	P(parent, "Skull", Vector3.new(1.4, 1.1, 1.7), CFrame.new(x, gy(x, z) + 0.45, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.3), C.bone, M.SmoothPlastic, { nc = true })
end

-- a sword stuck in the ground
local function sword(parent, x, z, yaw, lean, rng)
	local g = gy(x, z)
	local cf = CFrame.new(x, g - 0.8, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, rng:NextNumber(-0.15, 0.15))
	P(parent, "Blade", Vector3.new(0.25, 4.2, 0.7), cf * CFrame.new(0, 2.1, 0), C.stoneMid, M.Metal, { nc = true })
	P(parent, "Guard", Vector3.new(0.5, 0.3, 1.8), cf * CFrame.new(0, 4.3, 0), C.gold, M.Metal, { nc = true })
	P(parent, "Hilt", Vector3.new(0.4, 1.5, 0.4), cf * CFrame.new(0, 5.15, 0), C.woodDark, M.Wood, { nc = true })
end

-- a torn banner on a pole
local function banner(parent, x, z, yaw, rng)
	local g = gy(x, z)
	local lean = rng:NextNumber(-0.2, 0.2)
	local cf = CFrame.new(x, g, z) * CFrame.Angles(0, yaw, lean)
	P(parent, "Pole", Vector3.new(0.4, 11, 0.4), cf * CFrame.new(0, 5, 0), C.woodDark, M.Wood, { nc = true })
	P(parent, "Cloth", Vector3.new(0.1, 5, 2.4), cf * CFrame.new(0, 7.5, 1.3) * CFrame.Angles(0.08, 0, 0), C.cloth, M.Fabric, { nc = true, shadow = false })
	P(parent, "ClothTatter", Vector3.new(0.1, 1.6, 1.2), cf * CFrame.new(0, 4.4, 1.0) * CFrame.Angles(0.2, 0, 0), C.cloth, M.Fabric, { nc = true, shadow = false })
end

--[[ Inner Wilds ]]

local INNER = {}

-- the old stone gate where the sect's paving gives way to the wild path: two weathered pillars, the
-- lintel broken in two (one half still up, one fallen beside the path), moss on everything
function INNER.OldStoneGate(root, rng)
	local m = model(root, "OldStoneGate")
	local cx, cz = -4, 642
	local half = 8.5
	local top1 = pillar(m, G(cx - half, cz, -1), 17, 3.4, C.stone, math.rad(1.5))
	local top2 = pillar(m, G(cx + half, cz, -1), 14.5, 3.4, C.stoneMid, math.rad(-3))
	moss(m, top1 * CFrame.new(0, 0.15, 0), Vector3.new(3.6, 0.3, 3.2))
	-- the half lintel still resting on the taller pillar, cantilevered over the path
	P(m, "Lintel", Vector3.new(11, 2.2, 3), top1 * CFrame.new(3.5, 1.1, 0) * CFrame.Angles(0, 0, math.rad(-4)), C.stoneMid, M.Slate)
	moss(m, top1 * CFrame.new(3.5, 2.35, 0), Vector3.new(7, 0.3, 2.6))
	-- the fallen half
	local fx0, fz0 = cx + half + 5, cz + 6
	P(m, "LintelFallen", Vector3.new(10, 2.2, 3), CFrame.new(fx0, gy(fx0, fz0) + 0.7, fz0) * CFrame.Angles(0, math.rad(62), math.rad(14)), C.stoneMid, M.Slate)
	moss(m, CFrame.new(fx0, gy(fx0, fz0) + 1.9, fz0) * CFrame.Angles(0, math.rad(62), math.rad(14)), Vector3.new(6, 0.3, 2.4))
	rubble(m, Vector3.new(cx + half + 2, 0, cz + 2), 5, 7, rng)
	-- a stone tablet set into the left pillar's foot
	P(m, "Tablet", Vector3.new(0.6, 3.2, 2.2), CFrame.new(G(cx - half - 2.2, cz + 0.5, 1.4)) * CFrame.Angles(0, 0, math.rad(-8)), C.stoneDark, M.Slate)
	Kp(m, "Fern_M", G(cx - half - 1, cz - 2), 0.4, 0.9)
	Kp(m, "Fern_S", G(cx + half + 1.5, cz - 1.5), 2.1, 1)
end

-- three old steles at the trunk's first bend: lore stones, one leaning, jade characters worn faint
function INNER.Steles(root, rng)
	local m = model(root, "Steles")
	local spots = { { -26, 680, 9, 0.05 }, { -31, 686, 7, -0.12 }, { -24, 690, 5.2, 0.18 } }
	for i, s in spots do
		local g = gy(s[1], s[2])
		local cf = CFrame.new(s[1], g, s[2]) * CFrame.Angles(0, math.rad(80 + i * 9), s[4])
		P(m, "Plinth", Vector3.new(4.2, 1.2, 2.6), cf * CFrame.new(0, 0.3, 0), C.stoneDark, M.Slate)
		P(m, "Stele", Vector3.new(3.2, s[3], 1.2), cf * CFrame.new(0, 0.9 + s[3] / 2, 0), i == 2 and C.stoneMid or C.stone, M.Slate)
		P(m, "Inscription", Vector3.new(0.6, s[3] * 0.6, 0.08), cf * CFrame.new(0, 0.9 + s[3] * 0.55, -0.62), C.jade, M.SmoothPlastic, { nc = true, shadow = false })
		P(m, "Cap", Vector3.new(3.8, 0.7, 1.7), cf * CFrame.new(0, 0.9 + s[3] + 0.35, 0), C.stoneMid, M.Slate)
		moss(m, cf * CFrame.new(0, 0.9 + s[3] + 0.8, 0), Vector3.new(3, 0.25, 1.3))
	end
	Kp(m, "Fern_L", G(-29, 677), 0.2, 0.8)
	Kp(m, "Boulder_Rock_03", G(-34, 682), 1.2, 0.6, { collide = false, sink = 0.3 })
end

-- the hero: a weathered pavilion on the cliff-edged terrace at the end of the trunk's first long view,
-- a stone stair up from the path, lanterns at its foot and top, an old tree behind it
function INNER.ShrineTerrace(root, rng)
	local m = model(root, "ShrineTerrace")
	local cx, cz = -58, 826
	local top = gy(cx, cz)
	-- stair from the trunk (x ~ -16) up the terrace's east face
	local x0, x1 = -20, -46
	local zS = 822
	local base = gy(x0, zS)
	local steps = math.max(4, math.ceil((top - base) / 1.1))
	local run = (x0 - x1) / steps
	for i = 1, steps do
		local x = x0 - run * (i - 0.5)
		local y = base + (top - base) * i / steps
		P(m, "Step", Vector3.new(run + 0.6, y - base + 2, 9), CFrame.new(x, (y + base - 2) / 2, zS), i % 2 == 0 and C.stoneMid or C.stone, M.Slate)
	end
	for _, side in { -1, 1 } do
		P(m, "StairWall", Vector3.new(x0 - x1 + 2, 2.2, 1.2), CFrame.new((x0 + x1) / 2, (base + top) / 2 + 1.1, zS + side * 5.1) * CFrame.Angles(0, 0, -math.atan2(top - base, x0 - x1)), C.stoneDark, M.Slate)
		stoneLantern(m, G(x0 - 2, zS + side * 7.5), 0)
		stoneLantern(m, G(x1 - 3, zS + side * 6.5), 0)
	end
	-- pavilion (library Temple Structure, weathered) on a stone plinth
	P(m, "Plinth", Vector3.new(24, 2, 24), CFrame.new(cx - 2, top + 0.6, cz + 2), C.stoneMid, M.Slate)
	local temple = Kp(m, LIB["Map Detailing"]["Temple Structure"], Vector3.new(cx - 2, top + 1.6, cz + 2), math.rad(90), 0.62, { sink = 0.02 })
	temple.Name = "Pavilion"
	-- an incense brazier inside, and a meditation mat of stone
	local b = TEMPLATES.FX_Brazier:Clone()
	b.Name = "Brazier"
	b:PivotTo(CFrame.new(cx - 2, top + 1.6 + 2.6, cz + 2))
	for _, p in b:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			partCount += 1
		end
	end
	b.Parent = m
	P(m, "MeditationStone", Vector3.new(5, 0.6, 5), CFrame.new(cx - 8, top + 1.9, cz + 2), C.stoneDark, M.Slate)
	-- the old tree behind, rocks along the terrace lip
	Kp(m, "Wide_L", G(cx - 22, cz + 14), 0.8, 0.62, { name = "ShrineTree" })
	P(m, "ShrineTreeCollider", Vector3.new(14, 5, 5), CFrame.new(G(cx - 22, cz + 14, 6)) * CFrame.Angles(0, 0, math.pi / 2), C.wood, M.Wood, { shadow = false, trans = 1, shape = Enum.PartType.Cylinder })
	for i = 1, 5 do
		local a = math.rad(200 + i * 28)
		local x, z = cx + math.cos(a) * 17, cz + math.sin(a) * 17
		Kp(m, ({ "BoulderPile_6", "Boulder_Rock_01", "Fantasy_IV", "Boulder_Rocks_06", "BoulderPile_1" })[i], G(x, z), a, ({ 0.5, 1.3, 0.9, 1.4, 0.45 })[i], { collide = true, sink = 0.35 })
	end
	fx(m, "FX_ShrineIncense", CFrame.new(cx - 2, top + 6, cz + 2))
	fx(m, "FX_Fireflies", CFrame.new(cx - 2, top + 3, cz + 2), Vector3.new(24, 5, 24))
end

-- the wolf den: the cave in the crag's east face, its mouth framed by leaning rocks, bones outside
function INNER.WolfDen(root, rng)
	local m = model(root, "WolfDen")
	local mx, mz = -292, 654
	Kp(m, "CliffMass_2", G(mx - 4, mz - 13), math.rad(100), 0.42, { collide = true, sink = 0.25 })
	Kp(m, "CliffMass_4", G(mx - 4, mz + 13), math.rad(-80), 0.45, { collide = true, sink = 0.25 })
	Kp(m, "BoulderPile_5", G(mx + 3, mz - 9), math.rad(30), 0.45, { collide = true, sink = 0.3 })
	Kp(m, "Boulder_Rocks_07", G(mx + 4, mz + 10), math.rad(190), 1.1, { collide = true, sink = 0.3 })
	bones(m, Vector3.new(mx + 9, 0, mz), 7, 9, rng)
	Kp(m, "Stump_M", G(mx + 13, mz - 7), 0.6, 0.9)
	-- claw marks on the stump: three pale gouges
	for i = -1, 1 do
		P(m, "ClawMark", Vector3.new(0.15, 2.4, 0.35), CFrame.new(G(mx + 11.4, mz - 6 + i * 0.6, 3.5)) * CFrame.Angles(0, 0, 0.3), C.bone, M.Wood, { nc = true, shadow = false })
	end
	Kp(m, "Fern_M", G(mx + 6, mz + 7), 0.4, 1)
	fx(m, "FX_DenMist", CFrame.new(mx - 6, gy(mx, mz) + 2, mz), Vector3.new(10, 3, 14))
	-- the hunting ring: the WolfDen clearing doubles as the Inner Wilds' boss arena; old standing stones
	-- mark its edge (r 44), leaving the West path's entry (south-east) and the den (west) open
	local ax, az = -240, 660
	for i = 0, 11 do
		local deg = i * 30 + 8
		if (deg > 20 and deg < 80) or (deg > 150 and deg < 215) then
			continue
		end
		local a = math.rad(deg)
		local x, z = ax + math.cos(a) * 44, az + math.sin(a) * 44
		Kp(m, "Stone_" .. (i % 2 == 0 and 1 or 2), G(x, z), a, 1.2 + (i % 3) * 0.2, { collide = true, sink = 0.15, tilt = CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), name = "RingStone" })
	end
end

-- the hidden bamboo hollow: a moss-grown stone table and stools where someone once played weiqi alone,
-- a flat meditation stone and a single lantern
function INNER.BambooHollow(root, rng)
	local m = model(root, "BambooHollow")
	local cx, cz = -130, 596
	local g = gy(cx, cz)
	P(m, "TableFoot", Vector3.new(2.2, 2.4, 2.2), CFrame.new(cx, g + 1.1, cz), C.stoneDark, M.Slate, { shape = Enum.PartType.Cylinder }).CFrame = CFrame.new(cx, g + 1.1, cz) * CFrame.Angles(0, 0, math.pi / 2)
	P(m, "TableTop", Vector3.new(0.8, 5.5, 5.5), CFrame.new(cx, g + 2.6, cz) * CFrame.Angles(0, 0, math.pi / 2), C.stone, M.Slate, { shape = Enum.PartType.Cylinder })
	P(m, "Board", Vector3.new(3.4, 0.06, 3.4), CFrame.new(cx, g + 3.03, cz) * CFrame.Angles(0, 0.3, 0), C.stoneMid, M.Slate, { nc = true, shadow = false })
	for i = 1, 7 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0.3, 1.5)
		P(m, "Stone" .. (i % 2 == 0 and "Black" or "White"), Vector3.new(0.3, 0.12, 0.3), CFrame.new(cx + math.cos(a) * r, g + 3.1, cz + math.sin(a) * r), i % 2 == 0 and C.char or C.bone, M.SmoothPlastic, { nc = true, shadow = false })
	end
	for _, a in { 0.4, 3.5 } do
		P(m, "Stool", Vector3.new(1.6, 2.2, 2.2), CFrame.new(cx + math.cos(a) * 4.5, g + 0.8, cz + math.sin(a) * 4.5) * CFrame.Angles(0, 0, math.pi / 2), C.stoneMid, M.Slate, { shape = Enum.PartType.Cylinder })
	end
	moss(m, CFrame.new(cx + 1.2, g + 2.95, cz - 1.5) * CFrame.Angles(0, 0.5, 0), Vector3.new(2.2, 0.2, 1.6))
	P(m, "MeditationStone", Vector3.new(6, 0.8, 6), CFrame.new(cx - 9, g + 0.2, cz + 6) * CFrame.Angles(0, 0.2, 0), C.stoneDark, M.Slate)
	stoneLantern(m, G(cx - 8, cz - 8), 0.3)
	Kp(m, "Clover_L", G(cx - 4, cz - 7), 0.2, 0.9)
	Kp(m, "Mushroom_L", G(cx + 6, cz - 5), 1.3, 0.8)
	fx(m, "FX_Fireflies", CFrame.new(cx, g + 3, cz), Vector3.new(24, 5, 24))
end

-- a fallen giant: a huge trunk lying over the gully beside the east path, root plate torn up at one end,
-- broken crown at the other; it bridges the gully and can be walked
function INNER.FallenGiant(root, rng)
	local m = model(root, "FallenGiant")
	local a, b = Vector3.new(124, 0, 674), Vector3.new(176, 0, 670)
	local ya, yb = gy(a.X, a.Z) + 3.5, gy(b.X, b.Z) + 3
	local p0, p1 = Vector3.new(a.X, ya, a.Z), Vector3.new(b.X, yb, b.Z)
	local mid = (p0 + p1) / 2
	local len = (p1 - p0).Magnitude
	local log = Kp(m, "Log_A", mid, 0, nil, { raw = true, collide = true })
	log.Size = Vector3.new(len + 4, 8, 8)
	log.CFrame = CFrame.lookAt(mid, p1) * CFrame.Angles(0, math.rad(90), 0)
	log.Name = "GiantLog"
	Kp(m, "Stump_L", Vector3.new(a.X - 4, gy(a.X - 4, a.Z), a.Z), math.rad(75), 1.5, { collide = true, sink = 0.15, tilt = CFrame.Angles(0, 0, math.rad(70)) })
	Kp(m, "Dead_M", Vector3.new(b.X + 6, gy(b.X + 6, b.Z), b.Z + 2), math.rad(10), 0.9, { tilt = CFrame.Angles(0, 0, math.rad(-78)), sink = 0.0 })
	for i = 1, 6 do
		local t = i / 7
		local q = p0:Lerp(p1, t)
		Kp(m, i % 2 == 0 and "Mushroom_L" or "Fern_S", q + Vector3.new(0, 3.6, rng:NextNumber(-1.5, 1.5)), rng:NextNumber(0, 6), 0.7, { raw = true })
	end
	moss(m, CFrame.lookAt(mid + Vector3.new(0, 3.9, 0), p1 + Vector3.new(0, 3.9, 0)), Vector3.new(4.5, 0.4, len * 0.6))
end

-- the hunter's camp in the lee of the east hills: a tent, a fire ring with crossed logs, log benches,
-- a drying rack with hides, barrels and crates, a lantern on a pole
function INNER.HunterCamp(root, rng)
	local m = model(root, "HunterCamp")
	local cx, cz = 314, 618
	local g = gy(cx, cz)
	-- fire ring
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		P(m, "FireStone", Vector3.new(1.2, 0.8, 1), CFrame.new(cx + math.cos(a) * 2.4, g + 0.25, cz + math.sin(a) * 2.4) * CFrame.Angles(0, a, 0), C.stoneDark, M.Slate, { nc = true })
	end
	for i = 0, 2 do
		P(m, "FireLog", Vector3.new(3.6, 0.6, 0.6), CFrame.new(cx, g + 0.6, cz) * CFrame.Angles(0, i * 2.1, 0.35), C.char, M.Wood, { nc = true, shape = Enum.PartType.Cylinder })
	end
	P(m, "Embers", Vector3.new(1.6, 0.3, 1.6), CFrame.new(cx, g + 0.35, cz), C.ember, M.Neon, { nc = true, shadow = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFB56B")
	light.Range = 12
	light.Brightness = 0.7
	light.Shadows = false
	light.Parent = m:FindFirstChild("Embers")
	fx(m, "FX_Campfire", CFrame.new(cx, g + 0.8, cz))
	-- benches
	Kp(m, "Log_B", G(cx - 6, cz + 1), math.rad(85), 0.35, { collide = true, sink = 0.2 })
	Kp(m, "Log_A", G(cx + 1, cz + 6.5), math.rad(10), 0.3, { collide = true, sink = 0.2 })
	-- tent
	Kp(m, LIB["Stylized Asset Pack I (Props)"]["Stylized Market Tent"], G(cx + 10, cz - 8), math.rad(-140), 1.1, { collide = true, name = "Tent" })
	-- drying rack with hides
	local rx, rz = cx - 8, cz - 8
	local rg = gy(rx, rz)
	for _, s in { -3, 3 } do
		P(m, "RackPost", Vector3.new(0.5, 6.5, 0.5), CFrame.new(rx + s, rg + 3, rz), C.wood, M.Wood)
	end
	P(m, "RackBar", Vector3.new(7.2, 0.4, 0.4), CFrame.new(rx, rg + 6, rz), C.wood, M.Wood, { nc = true })
	P(m, "Hide", Vector3.new(2.6, 3.4, 0.12), CFrame.new(rx - 1.6, rg + 4.2, rz) * CFrame.Angles(0, 0, 0.05), C.hide, M.Fabric, { nc = true })
	P(m, "Hide", Vector3.new(2.2, 2.8, 0.12), CFrame.new(rx + 1.6, rg + 4.5, rz) * CFrame.Angles(0, 0, -0.04), Color3.fromHex("8C6B4A"), M.Fabric, { nc = true })
	-- stores
	local props = LIB["Stylized Asset Pack I (Props)"]["Stylized Props"]
	Kp(m, props["Stylized Barrel II"], G(cx + 4, cz - 11), 0.3, 1, { collide = true })
	Kp(m, props["Box Crate"], G(cx + 1, cz - 12), 0.8, 1, { collide = true })
	Kp(m, props["Crate"], G(cx + 1.2, cz - 12, 4), 0.2, 1, { raw = true })
	Kp(m, props["Sack 1"], G(cx + 6.5, cz - 12.5), 1.1, 1)
	Kp(m, "LogPile", G(cx - 12, cz + 4), math.rad(20), 0.6, { collide = true })
	-- a lantern on a pole by the trail
	local lp = Kp(m, LIB["Map Detailing"]["Inno's_Stylized_Asset_Pack"].Assets.Regular_Assets.Wood_Iron_Assets.Lantern_Pole, G(cx - 5, cz + 12), 0, 1.2, { collide = true, name = "Lantern" })
	local _, maxY = worldSpanY(lp)
	local glow = P(m, "LanternLightAnchor", Vector3.new(0.5, 0.5, 0.5), CFrame.new(cx - 5, maxY - 2, cz + 12), C.ember, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 })
	glow.Parent = lp
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromHex("FFB56B")
	pl.Range = 12
	pl.Brightness = 0.8
	pl.Shadows = false
	pl.Parent = glow
end

-- the qi spring shrine beside QiNode3: a spring rock with pools and old vines behind the node, jade lamps
function INNER.QiSpringShrine(root, rng)
	local m = model(root, "QiSpringShrine")
	Kp(m, LIB.VFX["Stylized Shrine Statue"], G(272, 850), math.rad(200), 0.55, { collide = true, name = "SpringRock", sink = 0.05 })
	for _, s in { { 258, 838 }, { 241, 842 } } do
		local lamp = TEMPLATES.FX_JadeLamp:Clone()
		lamp.Name = "JadeLamp"
		local _, sz = lamp:GetBoundingBox()
		lamp:PivotTo(CFrame.new(G(s[1], s[2], sz.Y / 2 - 0.2)))
		for _, p in lamp:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				partCount += 1
			end
		end
		lamp.Parent = m
	end
	local g = gy(262, 856)
	P(m, "SpringStele", Vector3.new(2.6, 5.5, 0.9), CFrame.new(262, g + 2.5, 856) * CFrame.Angles(0, math.rad(20), 0.06), C.stone, M.Slate)
	P(m, "Inscription", Vector3.new(0.5, 3.2, 0.06), CFrame.new(262, g + 3, 856) * CFrame.Angles(0, math.rad(20), 0.06) * CFrame.new(0, 0, -0.47), C.jade, M.SmoothPlastic, { nc = true, shadow = false })
	fx(m, "FX_QiSpring", CFrame.new(272, gy(272, 850) + 4, 850), Vector3.new(10, 4, 10))
end

-- the stone bridge over the border river (arch mesh; an invisible stepped deck carries players), gate
-- posts with lanterns at both ends
function INNER.Bridge(root, rng)
	local m = model(root, "BorderBridge")
	local B = LAYOUT.Bridge
	local zA, zB = B.z0, B.z1
	local yA, yB = gy(B.x, zA - 2), gy(B.x, zB + 2)
	local len = zB - zA
	local mesh = Kp(m, LIB["Map Detailing"]["Inno's_Stylized_Asset_Pack"].Assets.Regular_Assets.Stone_Bridges.Bridge_Regular, Vector3.new(B.x, 0, (zA + zB) / 2), math.rad(90), nil, { raw = true })
	mesh.Size = Vector3.new(len + 8, 15, 14)
	mesh.CFrame = CFrame.new(B.x, (yA + yB) / 2 - 3.2, (zA + zB) / 2) * CFrame.Angles(0, math.rad(90), 0)
	mesh.Name = "Arch"
	mesh.CastShadow = true
	-- deck: a gentle hump of collider slabs along the arch's walking line
	local n = 10
	for i = 1, n do
		local t0, t1 = (i - 1) / n, i / n
		local function deckY(t)
			return yA + (yB - yA) * t + math.sin(t * math.pi) * 3.2
		end
		local z0, z1 = zA - 4 + (len + 8) * t0, zA - 4 + (len + 8) * t1
		local y0, y1 = deckY(t0), deckY(t1)
		local mid = Vector3.new(B.x, (y0 + y1) / 2, (z0 + z1) / 2)
		local seg = Vector3.new(0, y1 - y0, z1 - z0)
		P(m, "Deck", Vector3.new(8, 1, seg.Magnitude + 0.3), CFrame.lookAt(mid, mid + seg) * CFrame.new(0, -0.5, 0), C.stone, M.Slate, { shadow = false, trans = 1 })
	end
	-- gate posts and lanterns at both ends
	for _, e in { { zA - 6, yA, -1 }, { zB + 6, yB, 1 } } do
		for _, side in { -1, 1 } do
			local x = B.x + side * 6.5
			P(m, "GatePost", Vector3.new(1.4, 9, 1.4), CFrame.new(x, e[2] + 4, e[1]), C.lacquerFaded, M.Wood)
			P(m, "PostCap", Vector3.new(2, 0.6, 2), CFrame.new(x, e[2] + 8.8, e[1]), C.gold, M.Metal)
			P(m, "PostFoot", Vector3.new(2.2, 1.4, 2.2), CFrame.new(x, e[2] + 0.3, e[1]), C.stoneDark, M.Slate)
		end
		stoneLantern(m, Vector3.new(B.x - 8.5, e[2], e[1] + e[3] * 3), 0)
	end
end

--[[ Ruined Borderlands ]]

local MIDDLE = {}

-- a ruined house: stone footing, broken rammed-earth walls, charred corner posts, a collapsed roof slab
local function ruinHouse(parent, cx, cz, w, d, yaw, rng, name)
	local m = model(parent, name or "RuinHouse")
	local rot = CFrame.Angles(0, yaw, 0)
	local corners = {}
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		table.insert(corners, (CFrame.new(cx, 0, cz) * rot * CFrame.new(c[1] * w / 2, 0, c[2] * d / 2)).Position)
	end
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		ruinWall(m, a, b, rng:NextNumber(4, 9), 1.4, rng, { gaps = i == 1 and 0.4 or 0.18, char = true })
		local g = gy(a.X, a.Z)
		local ph = rng:NextNumber(5, 11)
		P(m, "Post", Vector3.new(1.1, ph, 1.1), CFrame.new(a.X, g + ph / 2, a.Z) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), C.char, M.Wood)
	end
	-- floor rubble and the fallen roof
	local g = gy(cx, cz)
	local roofSide = rng:NextNumber() < 0.5 and -1 or 1
	P(m, "RoofSlab", Vector3.new(w * 0.9, 0.8, d * 0.6), CFrame.new(cx, g + 2.4, cz) * rot * CFrame.new(roofSide * w * 0.12, 0, 0) * CFrame.Angles(0, 0, roofSide * math.rad(24)), C.roofAsh, M.Slate, { nc = true })
	P(m, "RoofRidge", Vector3.new(w * 0.7, 0.7, 0.9), CFrame.new(cx, g + 4.2, cz) * rot * CFrame.new(-roofSide * w * 0.1, 0, 0) * CFrame.Angles(0, 0, roofSide * math.rad(24)), C.roof, M.Slate, { nc = true })
	for _ = 1, 4 do
		local bx, bz = cx + rng:NextNumber(-w / 2, w / 2), cz + rng:NextNumber(-d / 2, d / 2)
		P(m, "Beam", Vector3.new(rng:NextNumber(4, 7), 0.7, 0.7), CFrame.new(bx, gy(bx, bz) + 0.5, bz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), C.char, M.Wood, { nc = true })
	end
	rubble(m, Vector3.new(cx, 0, cz), math.min(w, d) / 2, 6, rng, M.Slate, C.roofAsh)
	return m
end

-- the border gate: the old wall that marked the sect's border, broken; gate piers by the road, torn
-- banners, and the collapsed watchtower beside it
function MIDDLE.BorderGate(root, rng)
	local m = model(root, "BorderGate")
	ruinWall(m, Vector3.new(-140, 0, 926), Vector3.new(-18, 0, 924), 8, 2.4, rng, { gaps = 0.18 })
	ruinWall(m, Vector3.new(6, 0, 924), Vector3.new(16, 0, 930), 7, 2.4, rng, { gaps = 0.1 })
	for _, x in { -15.5, 3.5 } do
		pillar(m, G(x, 925, -0.5), x < 0 and 13 or 9, 4.4, C.stoneMid, x < 0 and math.rad(2) or math.rad(-5))
	end
	-- the gate beam, fallen across the verge
	P(m, "GateBeam", Vector3.new(16, 1.4, 1.4), CFrame.new(G(-19, 932, 1.2)) * CFrame.Angles(0, math.rad(70), math.rad(8)), C.char, M.Wood, { nc = true })
	banner(m, -17, 920, math.rad(90), rng)
	banner(m, 5, 919, math.rad(80), rng)
	-- watchtower: four posts, a broken platform, a slumped roof
	local tx, tz = 28, 936
	local g = gy(tx, tz)
	for i, c in { { -4, -4 }, { 4, -4 }, { 4, 4 }, { -4, 4 } } do
		local h = ({ 18, 15, 9, 17 })[i]
		P(m, "TowerPost", Vector3.new(1.4, h, 1.4), CFrame.new(tx + c[1], g + h / 2 - 0.5, tz + c[2]) * CFrame.Angles(0, 0, i == 3 and 0.12 or 0), C.char, M.Wood)
	end
	P(m, "Platform", Vector3.new(9.5, 0.8, 9.5), CFrame.new(tx, g + 12, tz) * CFrame.Angles(math.rad(9), 0, math.rad(-6)), C.woodDark, M.WoodPlanks)
	P(m, "RoofFallen", Vector3.new(12, 0.8, 9), CFrame.new(tx + 7, g + 2.2, tz + 3) * CFrame.Angles(0, 0.4, math.rad(28)), C.roofAsh, M.Slate, { nc = true })
	P(m, "Brace", Vector3.new(0.6, 11, 0.6), CFrame.new(tx, g + 6, tz - 4) * CFrame.Angles(0, 0, math.rad(42)), C.char, M.Wood, { nc = true })
	rubble(m, Vector3.new(tx + 4, 0, tz + 5), 6, 8, rng, M.Wood, C.char)
end

-- Ashen Hollow: the dead village around QiNode4, five burned houses, a dry well, a broken cart
function MIDDLE.AshenHollow(root, rng)
	local m = model(root, "AshenHollow")
	ruinHouse(m, -62, 938, 12, 9, math.rad(8), rng)
	ruinHouse(m, -98, 948, 10, 12, math.rad(-14), rng)
	ruinHouse(m, -122, 966, 9, 9, math.rad(20), rng)
	ruinHouse(m, -72, 1006, 13, 9, math.rad(4), rng)
	ruinHouse(m, -106, 1007, 9, 11, math.rad(-8), rng)
	Kp(m, LIB.VFX["Stylized Well (Decaying Red)"], G(-82, 968), math.rad(30), 0.32, { collide = true, name = "DryWell" })
	local props = LIB["Stylized Asset Pack I (Props)"]
	Kp(m, props["Stylized Wooden Props I"]["Pushing Cart"], G(-46, 952), math.rad(130), 0.9, { collide = true, tilt = CFrame.Angles(0, 0, math.rad(12)), name = "BrokenCart" })
	Kp(m, props["Stylized Props"]["Barrel"], G(-58, 949), 0.4, 1.1, { tilt = CFrame.Angles(math.rad(90), 0, 0) })
	Kp(m, props["Stylized Props"]["Bucket"], G(-79, 973), 0.4, 1.1)
	local plants = LIB["Stylized Foliage + Pots"]["Plants + Pots"]
	Kp(m, plants["Pot"], G(-96, 958), 0.2, 1, { tilt = CFrame.Angles(math.rad(80), 0, 0) })
	banner(m, -50, 990, math.rad(10), rng)
	fx(m, "FX_AshDrift", CFrame.new(-80, gy(-80, 970) + 3, 970), Vector3.new(60, 6, 60))
end

-- an overturned caravan cart on the east road, its cargo strewn, bones of the drivers nearby
function MIDDLE.Caravan(root, rng)
	local m = model(root, "Caravan")
	local cx, cz = 116, 976
	local props = LIB["Stylized Asset Pack I (Props)"]
	Kp(m, props["Stylized Wooden Props I"]["Pushing Cart"], G(cx, cz), math.rad(40), 1.2, { collide = true, tilt = CFrame.Angles(0, 0, math.rad(78)), sink = 0.1, name = "OverturnedCart" })
	Kp(m, props["Stylized Props"]["CartWheel"], G(cx - 7, cz + 5), 0.3, 1.4, { tilt = CFrame.Angles(math.rad(85), 0, 0) })
	for i, n in { "Box Crate", "Crate", "Small Box", "Long Crate", "Sack 2", "Sack 1" } do
		local a = i * 1.1
		local src = props["Stylized Props"]:FindFirstChild(n) or props["Stylized Wooden Props I"]:FindFirstChild(n)
		if src then
			Kp(m, src, G(cx + math.cos(a) * rng:NextNumber(4, 8), cz + math.sin(a) * rng:NextNumber(4, 8)), rng:NextNumber(0, 6), 1, { tilt = CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)) })
		end
	end
	bones(m, Vector3.new(cx + 7, 0, cz - 6), 4, 6, rng)
	sword(m, cx + 5, cz + 6, 0.6, 0.4, rng)
end

-- the cultivators' graves: mounds, tombstones, swords driven in for markers, banners, a memorial stele
function MIDDLE.Graves(root, rng)
	local m = model(root, "Graves")
	local cx, cz = -164, 1064
	local tomb
	for _, c in LIB["Map Detailing"]:GetChildren() do
		if c:FindFirstChild("Meshes/tombstone!") then
			tomb = c
			break
		end
	end
	local rows = { { -10, -8 }, { 0, -9 }, { 10, -8 }, { -12, 2 }, { -2, 1 }, { 9, 3 }, { -6, 11 }, { 5, 12 }, { 15, 11 } }
	for i, r in rows do
		local x, z = cx + r[1] + rng:NextNumber(-1, 1), cz + r[2] + rng:NextNumber(-1, 1)
		local g = gy(x, z)
		P(m, "Mound", Vector3.new(3.4, 1.2, 6), CFrame.new(x, g + 0.2, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), C.earthDark, M.Ground, { nc = true })
		if i % 3 == 0 then
			sword(m, x, z - 3.6, rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2), rng)
		elseif tomb then
			local t = Kp(m, tomb:GetChildren()[(i % 3) + 1], G(x, z - 3.6), rng:NextNumber(-0.15, 0.15) + math.pi, 1.6, { collide = true, tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, 0) })
			t.Name = "Tombstone"
		end
	end
	-- memorial stele at the head of the field
	local sx, sz = cx, cz - 20
	local g = gy(sx, sz)
	P(m, "Plinth", Vector3.new(7, 1.6, 4), CFrame.new(sx, g + 0.4, sz), C.stoneDark, M.Slate)
	P(m, "Memorial", Vector3.new(5, 12, 1.6), CFrame.new(sx, g + 7, sz) * CFrame.Angles(0, 0, math.rad(4)), C.stoneMid, M.Slate)
	P(m, "Inscription", Vector3.new(0.8, 7.5, 0.08), CFrame.new(sx, g + 7.3, sz) * CFrame.Angles(0, 0, math.rad(4)) * CFrame.new(0, 0, -0.82), C.jade, M.SmoothPlastic, { nc = true, shadow = false })
	P(m, "Crack", Vector3.new(0.2, 5, 1.7), CFrame.new(sx + 1.2, g + 10, sz) * CFrame.Angles(0, 0, math.rad(20)), C.stoneDeep, M.Slate, { nc = true, shadow = false })
	banner(m, cx - 14, cz - 14, math.rad(30), rng)
	banner(m, cx + 16, cz - 12, math.rad(-20), rng)
	stoneLantern(m, G(sx - 5, sz + 2), 0, C.ghost)
	fx(m, "FX_GhostLights", CFrame.new(cx, g + 3, cz), Vector3.new(30, 6, 30))
end

-- the drowned shrine: a torii sinking into the marsh, a waterlogged boat
function MIDDLE.DrownedShrine(root, rng)
	local m = model(root, "DrownedShrine")
	Kp(m, LIB["Map Detailing"]["Tori Gate no Sign"], Vector3.new(176, gy(176, 958), 958), math.rad(-25), 0.7, { tilt = CFrame.Angles(0, 0, math.rad(11)), sink = 0.28, name = "SunkenGate" })
	Kp(m, LIB["Stylized Boats"]["Stylized Boat"], Vector3.new(184, 0.2, 980), math.rad(30), 0.16, { tilt = CFrame.Angles(math.rad(14), 0, math.rad(-20)), sink = 0.35, name = "SunkenBoat" })
	fx(m, "FX_MarshMist", CFrame.new(170, 3, 966), Vector3.new(40, 4, 30))
end

-- the serpent's bones in the fen: a long arched spine with ribs, half in the black pools
function MIDDLE.SerpentBones(root, rng)
	local m = model(root, "SerpentBones")
	local n = 22
	for i = 1, n do
		local t = i / n
		local x = -336 + t * 50
		local z = 990 + math.sin(t * math.pi * 1.6) * 12
		local y = gy(x, z) + 0.6 + math.sin(t * math.pi) * 1.2
		local s = 1.5 + math.sin(t * math.pi) * 1.4
		local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + 2, y, z + math.cos(t * math.pi * 1.6) * 2))
		P(m, "Vertebra", Vector3.new(s, s * 0.9, s * 0.8), cf, C.bone, M.SmoothPlastic, { nc = true })
		if i > 3 and i < n - 2 then
			for _, side in { -1, 1 } do
				P(m, "Rib", Vector3.new(0.5, 0.5, s * 3.2), cf * CFrame.new(side * s * 1.2, s * 0.9, 0) * CFrame.Angles(0, math.rad(90), side * math.rad(55)), C.bone, M.SmoothPlastic, { nc = true, shadow = false })
			end
		end
	end
	P(m, "SkullTop", Vector3.new(6, 3.2, 8), CFrame.new(G(-339, 986, 1.2)) * CFrame.Angles(0.2, 0.5, 0.1), C.bone, M.SmoothPlastic, { nc = true })
	P(m, "Jaw", Vector3.new(5, 1.2, 7), CFrame.new(G(-341, 982, 0.4)) * CFrame.Angles(-0.1, 0.9, 0), C.bone, M.SmoothPlastic, { nc = true })
end

-- the fallen outpost: the boss arena inside the broken walls of a border fort, piers at its north gate,
-- broken pillars outside the fighting ring, flagstones half buried
function MIDDLE.FallenOutpost(root, rng)
	local m = model(root, "FallenOutpost")
	local cx, cz = 0, 1100
	local R = 60
	-- wall ring with a gate gap to the north (toward the road) and breaches
	local segs = 22
	for i = 0, segs - 1 do
		local a0, a1 = i / segs * math.pi * 2, (i + 1) / segs * math.pi * 2
		local mid = (a0 + a1) / 2
		local gateGap = math.abs(math.atan2(math.sin(mid + math.pi / 2), math.cos(mid + math.pi / 2))) < 0.24
		if gateGap then
			continue
		end
		local a = Vector3.new(cx + math.cos(a0) * R, 0, cz + math.sin(a0) * R)
		local b = Vector3.new(cx + math.cos(a1) * R, 0, cz + math.sin(a1) * R)
		ruinWall(m, a, b, rng:NextNumber(5, 10), 2.6, rng, { gaps = 0.22, color = C.stoneMid, mat = M.Slate })
	end
	for _, side in { -1, 1 } do
		pillar(m, G(cx + side * 11, cz - R, -0.5), side < 0 and 16 or 11, 5, C.stoneMid, side * math.rad(3))
	end
	-- broken pillars outside the fighting ring (r 50), some fallen
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + 0.3
		local x, z = cx + math.cos(a) * 51, cz + math.sin(a) * 51
		if math.abs(x - cx) < 10 and z < cz then
			continue -- keep the north gate open
		end
		if i % 3 == 0 then
			P(m, "FallenPillar", Vector3.new(12, 3.2, 3.2), CFrame.new(G(x, z, 1.2)) * CFrame.Angles(0, a + 1.2, 0), C.stone, M.Slate)
		else
			pillar(m, G(x, z, -0.5), rng:NextNumber(4, 12), 3.4, C.stone, rng:NextNumber(-0.06, 0.06))
		end
	end
	-- half-buried flagstones (flush, walkable)
	for _ = 1, 46 do
		local a, r = rng:NextNumber(0, 6.28), math.sqrt(rng:NextNumber()) * 44
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		P(m, "Flagstone", Vector3.new(rng:NextNumber(3, 5.5), 0.5, rng:NextNumber(3, 5.5)), CFrame.new(x, gy(x, z) - 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber() < 0.5 and C.stoneMid or C.stoneDark, M.Slate, { nc = true, shadow = false })
	end
	bones(m, Vector3.new(cx + 20, 0, cz + 14), 8, 10, rng)
	bones(m, Vector3.new(cx - 24, 0, cz - 10), 6, 7, rng)
	for _, s in { { -30, 1125 }, { 34, 1082 } } do
		sword(m, s[1], s[2], rng:NextNumber(0, 6), 0.3, rng)
	end
	banner(m, cx - 12, cz - R - 4, 0, rng)
	banner(m, cx + 12, cz - R - 4, 0, rng)
	fx(m, "FX_ArenaMist", CFrame.new(cx, gy(cx, cz) + 2, cz), Vector3.new(90, 4, 90))
end

-- the broken pagoda on its mound behind the arena: the zone's hero, seen from the bridge down the road
function MIDDLE.BrokenPagoda(root, rng)
	local m = model(root, "BrokenPagoda")
	local cx, cz = 0, 1172
	local g = gy(cx, cz)
	P(m, "Base", Vector3.new(20, 2.4, 20), CFrame.new(cx, g + 0.6, cz), C.stoneDark, M.Slate)
	P(m, "BaseStep", Vector3.new(24, 1.2, 24), CFrame.new(cx, g - 0.2, cz), C.stoneDeep, M.Slate)
	local y = g + 1.8
	local tiers = { { 15, 9, 22, 0 }, { 11, 7.5, 17, math.rad(4) }, { 7.5, 6, 12, math.rad(9) } }
	local tilt = CFrame.identity
	for i, t in tiers do
		local w, h, roofW, lean = t[1], t[2], t[3], t[4]
		tilt = tilt * CFrame.Angles(lean * 0.6, 0, lean)
		local base = CFrame.new(cx, y, cz) * tilt
		-- walls (earth, burned) between charred corner posts; one side broken open
		for k, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			P(m, "Post", Vector3.new(1.2, h, 1.2), base * CFrame.new(c[1] * w / 2, h / 2, c[2] * w / 2), C.char, M.Wood)
			if not (i == 1 and k == 1) then
				local nx = ({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } })[k]
				P(m, "Wall", Vector3.new(nx[1] == 0 and w - 1 or 0.9, h * rng:NextNumber(0.55, 0.95), nx[2] == 0 and w - 1 or 0.9), base * CFrame.new(nx[1] * (w / 2 - 0.4), h * 0.4, nx[2] * (w / 2 - 0.4)), i == 1 and C.earthDark or C.earth, M.Ground)
			end
		end
		-- roof: slate-teal slab with upturned gold-tipped corners; the top tier's roof is gone
		if i < 3 then
			P(m, "Roof", Vector3.new(roofW, 1, roofW), base * CFrame.new(0, h + 0.5, 0), C.roof, M.Slate)
			P(m, "RoofCap", Vector3.new(roofW * 0.7, 1.2, roofW * 0.7), base * CFrame.new(0, h + 1.4, 0), C.roofAsh, M.Slate)
			for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				P(m, "Eave", Vector3.new(3, 0.6, 1), base * CFrame.new(c[1] * roofW / 2, h + 1.0, c[2] * roofW / 2) * CFrame.Angles(0, math.atan2(c[1], c[2]), math.rad(25)), C.gold, M.Metal, { nc = true })
			end
		else
			P(m, "SnappedPost", Vector3.new(1.4, 9, 1.4), base * CFrame.new(1, h + 3, -1) * CFrame.Angles(0, 0, math.rad(14)), C.char, M.Wood, { nc = true })
		end
		y += h + 2
	end
	-- roof tiles fallen down the mound
	rubble(m, Vector3.new(cx + 6, 0, cz - 12), 8, 12, rng, M.Slate, C.roof)
	Kp(m, "Dead_L", G(cx - 15, cz + 6), 0.6, 2.0, { name = "PagodaDeadTree" })
	stoneLantern(m, G(cx - 6, cz - 12), 0, C.ghost)
	stoneLantern(m, G(cx + 6, cz - 12), 0, C.ghost)
	fx(m, "FX_PagodaEmbers", CFrame.new(cx, y, cz), Vector3.new(8, 4, 8))
end

-- the serpent grotto: the cave in the crag north of the fen, mouth framed by dark rocks, shed skin
function MIDDLE.SerpentGrotto(root, rng)
	local m = model(root, "SerpentGrotto")
	local mx, mz = -322, 1066
	Kp(m, "CliffRock_1", G(mx - 14, mz + 4), math.rad(20), 1.2, { collide = true, sink = 0.2 })
	Kp(m, "CliffRock_2", G(mx + 14, mz + 6), math.rad(200), 1.2, { collide = true, sink = 0.2 })
	Kp(m, "CliffMass_5", G(mx - 2, mz + 14), math.rad(160), 0.35, { collide = true, sink = 0.3 })
	-- shed skin: pale translucent coils
	for i = 1, 8 do
		local a = i * 0.7
		local x, z = mx + 2 + math.cos(a) * (3 + i * 0.4), mz - 6 + math.sin(a) * (3 + i * 0.4)
		P(m, "ShedSkin", Vector3.new(3.2, 0.25, 1.6), CFrame.new(x, gy(x, z) + 0.15, z) * CFrame.Angles(0, a + 1.57, 0.1), Color3.fromHex("CFC8B0"), M.Fabric, { nc = true, shadow = false, trans = 0.25 })
	end
	bones(m, Vector3.new(mx + 4, 0, mz - 9), 4, 6, rng)
	fx(m, "FX_GrottoMist", CFrame.new(mx, gy(mx, mz) + 2, mz + 6), Vector3.new(12, 3, 12))
end

-- the ruined courtyard round QiNode5: low broken walls, a gate toward the road, toppled lanterns
function MIDDLE.RuinedCourtyard(root, rng)
	local m = model(root, "RuinedCourtyard")
	local cx, cz, h = 120, 1040, 12
	local c = { Vector3.new(cx - h, 0, cz - h), Vector3.new(cx + h, 0, cz - h), Vector3.new(cx + h, 0, cz + h), Vector3.new(cx - h, 0, cz + h) }
	-- north wall has the gate (toward the east road), the others are broken
	ruinWall(m, c[1], Vector3.new(cx - 3.5, 0, cz - h), 5, 1.6, rng, { gaps = 0.1 })
	ruinWall(m, Vector3.new(cx + 3.5, 0, cz - h), c[2], 5, 1.6, rng, { gaps = 0.1 })
	ruinWall(m, c[2], c[3], 5, 1.6, rng, { gaps = 0.3 })
	ruinWall(m, c[3], c[4], 5, 1.6, rng, { gaps = 0.25 })
	ruinWall(m, c[4], c[1], 5, 1.6, rng, { gaps = 0.3 })
	for _, x in { cx - 3.8, cx + 3.8 } do
		pillar(m, G(x, cz - h, -0.4), 7, 2, C.stoneMid)
	end
	-- toppled stone lanterns (no light: this place is dead)
	for _, s in { { cx - 7, cz - 6, 1.4 }, { cx + 8, cz + 6, -1.2 } } do
		local l = TEMPLATES.FX_StoneLantern:Clone()
		l.Name = "ToppledLantern"
		if l:FindFirstChild("Flame") then
			l.Flame:Destroy()
		end
		l:PivotTo(CFrame.new(G(s[1], s[2], 1.6)) * CFrame.Angles(0, s[3], math.rad(85)))
		for _, p in l:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				partCount += 1
			end
		end
		l.Parent = m
	end
	for _ = 1, 14 do
		local x, z = cx + rng:NextNumber(-10, 10), cz + rng:NextNumber(-10, 10)
		if (Vector2.new(x, z) - Vector2.new(cx, cz)).Magnitude > 7 then
			P(m, "Flagstone", Vector3.new(rng:NextNumber(2.5, 4), 0.5, rng:NextNumber(2.5, 4)), CFrame.new(x, gy(x, z) - 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), C.stoneMid, M.Slate, { nc = true, shadow = false })
		end
	end
end

-- the deserters' camp behind the east bluff: an enemy outpost (room for 3-5 beasts or bandits later)
-- inside a stake palisade open toward the trail, three tents round a fire, stolen stores, a bone cage
function MIDDLE.DeserterCamp(root, rng)
	local m = model(root, "DeserterCamp")
	local cx, cz = 184, 1142
	local R = 19
	local gapA = math.atan2(1124 - cz, 174 - cx)
	for i = 0, 63 do
		local a = i / 64 * math.pi * 2
		local da = math.abs(math.atan2(math.sin(a - gapA), math.cos(a - gapA)))
		if da > 0.32 and rng:NextNumber() > 0.08 then
			local x, z = cx + math.cos(a) * R, cz + math.sin(a) * R
			local h = rng:NextNumber(6, 8.5)
			local g = gy(x, z)
			local cf = CFrame.new(x, g + h / 2 - 1, z) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 4)))
			P(m, "Stake", Vector3.new(1.1, h, 1.1), cf, rng:NextNumber() < 0.5 and C.wood or C.woodDark, M.Wood)
			P(m, "StakeTip", Vector3.new(0.8, 1.2, 0.8), cf * CFrame.new(0, h / 2 + 0.5, 0) * CFrame.Angles(0, math.rad(45), 0), C.woodDark, M.Wood, { nc = true })
		end
	end
	for _, s in { -1, 1 } do
		local ga = gapA + s * 0.36
		local x, z = cx + math.cos(ga) * R, cz + math.sin(ga) * R
		local g = gy(x, z)
		P(m, "GatePost", Vector3.new(1.6, 11, 1.6), CFrame.new(x, g + 4.5, z), C.woodDark, M.Wood)
		P(m, "Skull", Vector3.new(1.4, 1.1, 1.7), CFrame.new(x, g + 10.6, z), C.bone, M.SmoothPlastic, { nc = true })
	end
	local tent = LIB["Stylized Asset Pack I (Props)"]["Stylized Market Tent"]
	for _, a in { 0.6, 2.3, 4.1 } do
		Kp(m, tent, G(cx + math.cos(a) * 11, cz + math.sin(a) * 11), -a + math.pi / 2, 1.25, { collide = true, name = "Tent" })
	end
	local g = gy(cx, cz)
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		P(m, "FireStone", Vector3.new(1.2, 0.8, 1), CFrame.new(cx + math.cos(a) * 2.6, g + 0.25, cz + math.sin(a) * 2.6) * CFrame.Angles(0, a, 0), C.stoneDark, M.Slate, { nc = true })
	end
	for i = 0, 2 do
		P(m, "FireLog", Vector3.new(3.8, 0.6, 0.6), CFrame.new(cx, g + 0.6, cz) * CFrame.Angles(0, i * 2.1, 0.35), C.char, M.Wood, { nc = true, shape = Enum.PartType.Cylinder })
	end
	local emb = P(m, "Embers", Vector3.new(1.8, 0.3, 1.8), CFrame.new(cx, g + 0.35, cz), C.ember, M.Neon, { nc = true, shadow = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FF9A55")
	light.Range = 14
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = emb
	fx(m, "FX_Campfire", CFrame.new(cx, g + 0.8, cz))
	local rx, rz = cx - 6, cz + 9
	local rg = gy(rx, rz)
	for _, s in { -2.5, 2.5 } do
		P(m, "RackPost", Vector3.new(0.5, 5, 0.5), CFrame.new(rx + s, rg + 2.3, rz), C.wood, M.Wood)
	end
	P(m, "RackBar", Vector3.new(6, 0.4, 0.4), CFrame.new(rx, rg + 4.4, rz), C.wood, M.Wood, { nc = true })
	for i = -1, 1 do
		sword(m, rx + i * 1.6, rz + 0.6, 0, -0.25, rng)
	end
	local props = LIB["Stylized Asset Pack I (Props)"]["Stylized Props"]
	for i, n in { "Stylized Barrel II", "Box Crate", "Fabric Sack Stack", "Crate", "Barrel", "Sack 2" } do
		local a = 3.3 + i * 0.28
		local src = props:FindFirstChild(n)
		if src then
			Kp(m, src, G(cx + math.cos(a) * 15, cz + math.sin(a) * 15), rng:NextNumber(0, 6), 1.1, { collide = i <= 3 })
		end
	end
	local kx, kz = cx + 12, cz - 6
	local kg = gy(kx, kz)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		P(m, "CageBar", Vector3.new(0.4, 6, 0.4), CFrame.new(kx + math.cos(a) * 2.4, kg + 3, kz + math.sin(a) * 2.4), C.woodDark, M.Wood)
	end
	P(m, "CageTop", Vector3.new(0.6, 5.6, 5.6), CFrame.new(kx, kg + 6.2, kz) * CFrame.Angles(0, 0, math.pi / 2), C.woodDark, M.Wood, { shape = Enum.PartType.Cylinder })
	bones(m, Vector3.new(kx, 0, kz), 1.6, 4, rng)
	local wx, wz = cx - 14, cz - 4
	local wg = gy(wx, wz)
	for _, c in { { -2, -2 }, { 2, -2 }, { 2, 2 }, { -2, 2 } } do
		P(m, "WatchPost", Vector3.new(0.8, 10, 0.8), CFrame.new(wx + c[1], wg + 4.5, wz + c[2]), C.wood, M.Wood)
	end
	P(m, "WatchDeck", Vector3.new(5.4, 0.6, 5.4), CFrame.new(wx, wg + 9.2, wz), C.woodDark, M.WoodPlanks)
	banner(m, cx + 4, cz - 17, 0.5, rng)
	banner(m, cx - 17, cz + 6, 2.1, rng)
	fx(m, "FX_CampSmoke", CFrame.new(cx, g + 4, cz))
end

--[[ Run ]]

local BUILDERS = { Inner = INNER, Middle = MIDDLE }
local report = {}
for _, zoneName in CFG.zones or { "Inner", "Middle" } do
	local holder = workspace.Map.Ground:FindFirstChild("Wilds" .. zoneName)
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "Wilds" .. zoneName
		holder.Parent = workspace.Map.Ground
	end
	local old = holder:FindFirstChild("POIs")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "POIs"
	partCount = 0
	local names = {}
	for name, build in BUILDERS[zoneName] do
		local rng = Random.new(#name * 97 + 13)
		math.randomseed(#name * 31)
		local ok, err = pcall(build, root, rng)
		table.insert(names, ok and name or (name .. " FAILED: " .. tostring(err)))
		task.wait()
	end
	root.Parent = holder
	table.sort(names)
	table.insert(report, string.format("%s POIs (%d parts): %s", zoneName, partCount, table.concat(names, ", ")))
end
ChangeHistoryService:SetWaypoint("Wilds POIs")
return table.concat(report, "\n")
