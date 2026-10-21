--[[
Dressing for the first two wilds zones: groves, path framing, clearing edges, rock outcrops and cliff
faces, ground cover. Run in Studio Edit mode after art/wilds/wilds_layout.luau and terrain_wilds.luau.

  _G.WILDS_DRESS = { zones = { "Inner", "Middle" }, kit = false }
    kit   rebuild ServerStorage.WildsKit from the AssetLibrary first (it is built when missing)

Stages:
  kit    clones the chosen AssetLibrary pieces (clone, never move, the originals) into
         ServerStorage.WildsKit under stable names, so the layout never depends on library child order.
         The crystal "Stylized Rock IV" (rainbow ore) is deliberately not in the kit.
  dress  clears and rebuilds Map.Ground.Wilds<Zone>.Dressing (seeded, deterministic). A jittered grid of
         candidates (CELL studs) is read against the layout: path edges (flowers, bushes, small rocks in
         the framing band, trees held back from the walking line), zone discs (open clearings: ground
         cover only; a dense ring of trees just outside), steep ground (sized-up rocks sunk into the slope
         as cliff faces), rocky ridges (outcrop clusters: one big + smaller pieces), groves from a noise
         field (dense stands with gaps between), POI footprints (kept empty for poi_wilds).
Collision: foliage is CanCollide/CanQuery/CanTouch off with Box fidelity (it must never catch the ground
raycasts of spawns and treasures). Trees get one invisible trunk collider. Rocks taller than 6 studs
collide (Hull); smaller ones don't. Only trees and big rocks cast shadows.
Old InnerRing/MiddleRing dressing inside the zone boxes is moved (once) to ServerStorage._WildsReplaced.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local LAYOUT = _G.WILDS_LAYOUT
assert(LAYOUT, "run art/wilds/wilds_layout.luau first")
local CFG = _G.WILDS_DRESS or {}
_G.WILDS_DRESS = nil

local SS = game:GetService("ServerStorage")

--[[ Kit ]]

local function buildKit()
	local L = SS.AssetLibrary
	local MD = L["Map Detailing"]
	local inno = MD["Inno's_Stylized_Asset_Pack"].Assets
	local R = L["Stylized Rock Packs"]
	local F = L["Stylized Foliage + Pots"]
	local old = SS:FindFirstChild("WildsKit")
	if old then
		old:Destroy()
	end
	local kit = Instance.new("Folder")
	kit.Name = "WildsKit"
	local function add(name, src, strip)
		assert(src, "kit source missing for " .. name)
		local c = src:Clone()
		c.Name = name
		for _, d in c:GetDescendants() do
			if d:IsA("LuaSourceContainer") or (strip and strip[d.Name]) then
				d:Destroy()
			end
		end
		if c:IsA("Model") then
			-- Some library models (Stone Rock Pack "Single Stone") keep their WorldPivot
			-- hundreds of studs from the mesh, so PivotTo(spot) dropped the stone far
			-- from the spot (the Wolf Den ring stones, the Middle's path stones). Pivot
			-- every kit model at its bounding box's bottom centre, keeping the rotation.
			local box, size = c:GetBoundingBox()
			c.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * c:GetPivot().Rotation
		end
		c.Parent = kit
	end
	local function byName(folder, name, size)
		-- the Nth child with this name and roughly this height (library names repeat)
		for _, c in folder:GetChildren() do
			if c.Name == name then
				local s
				if c:IsA("Model") then
					s = select(2, c:GetBoundingBox())
				else
					s = c.Size
				end
				if not size or math.abs(s.Y - size) < 1.5 then
					return c
				end
			end
		end
		return nil
	end
	local function mdTree(name, height)
		for _, c in MD:GetChildren() do
			if c.Name == name and c:IsA("Model") then
				local _, s = c:GetBoundingBox()
				if math.abs(s.Y - height) < 1.5 then
					return c
				end
			end
		end
		return nil
	end
	local function mdModelWith(childName)
		for _, c in MD:GetChildren() do
			if c:IsA("Model") and c:FindFirstChild(childName) then
				return c
			end
		end
		return nil
	end

	-- bamboo
	for i = 1, 3 do
		add("Bamboo_" .. i, SS._Templates["BambooCluster_" .. i])
	end
	-- broadleaf trees with layered canopies (Stylized Tree Pack; the reference's forest trees)
	local TP = L["Stylized Tree Pack"]
	add("Layer_Dark", byName(TP, "Stylized Tree (Dark Green)"))
	add("Layer_Light", byName(TP, "Stylized Tree (Light Green)"))
	add("Wide_M", byName(TP, "Stylized Tree (Wide)", 49))
	add("Wide_L", byName(TP, "Stylized Tree (Wide)", 107))
	add("Leafy_M", byName(TP, "Stylized Tree (Wind Physics) *", 46))
	add("PineLayered", mdTree("Pine Tree 3", 50)) -- tiered Chinese pine
	add("SmallRound", mdTree("Tree 1", 22))
	add("SmallBare", mdTree("Tree 1", 16)) -- leafless sapling
	-- pale birches with sparse maroon leaves (Tree 3 realistic): the dying woods of the borderlands
	add("Birch_L", mdTree("Tree 3 realistic", 66))
	add("Birch_M", mdTree("Tree 3 realistic", 47))
	add("Birch_S", mdTree("Tree 3 realistic", 29))
	-- pines
	local pines = inno.Regular_Assets.Pine_Trees
	add("Pine_A", pines.Variation_01["Pine_01.1"])
	add("Pine_B", pines.Variation_03["Pine_03.2"])
	add("Pine_C", pines.Variation_05["Pine_05.4"])
	-- dead and withered trees (Tree 2 realistic: trunk mesh + sparse maroon leaves)
	local t2 = mdModelWith("Tree 2 realistic")
	local t2s = {}
	for _, c in t2:GetChildren() do
		local _, s = c:GetBoundingBox()
		table.insert(t2s, { c = c, h = s.Y })
	end
	table.sort(t2s, function(a, b)
		return a.h > b.h
	end)
	add("Dead_L", t2s[1].c, { ["Tree_2_realistic_LOD0.001"] = true })
	add("Dead_M", t2s[4].c, { ["Tree_2_realistic_LOD0.001"] = true })
	add("Dead_S", t2s[9].c, { ["Tree_2_realistic_LOD0.001"] = true })
	add("Withered_L", t2s[2].c)
	add("Withered_M", t2s[7].c)
	-- bushes and ground cover
	local bushes = F["Stylized Bushes"]
	add("Bush_XL", byName(bushes, "Stylized Bush (Green)", 19))
	add("Bush_L", byName(bushes, "Stylized Bush (Green)", 17))
	add("Bush_M", byName(bushes, "Stylized Bush (Green)", 10))
	add("Bush_S", byName(bushes, "Stylized Bush (Green)", 6))
	add("Bush_XS", byName(bushes, "Stylized Bush (Green)", 7))
	add("BushDry_M", byName(bushes, "Stylized Bush (Orange)", 10))
	add("BushDry_S", byName(bushes, "Stylized Bush (Orange)", 8))
	local fol = inno.Regular_Assets.Foliage
	add("Shrub_A", fol.Foliage_01.Bush1_02)
	add("Shrub_B", fol.Foliage_02.Bush2_02)
	add("Shrub_C", fol.Foliage_02.Bush2_01)
	local plants = F["Plants + Pots"]
	add("Fern_L", byName(plants, "Fern", 4))
	add("Fern_M", byName(plants, "Fern", 3))
	add("Fern_S", byName(plants, "Fern", 1))
	add("Leaf_A", byName(plants, "Leaf", 2))
	add("Reeds", byName(plants, "Reeds"))
	local reg = inno.Regular_Assets
	add("Clover_M", reg.Clovers.Clover_02)
	add("Clover_L", reg.Clovers.Clover_03)
	add("Flowers_Blue", reg.Flowers.Blue_Flowers)
	add("Flowers_White", reg.Flowers.White_Flowers)
	add("Flowers_Yellow", reg.Flowers.Yellow_Flowers)
	add("Mushroom_M", reg.Mushrooms.Mushroom_02)
	add("Mushroom_L", reg.Mushrooms.Mushroom_03)
	add("Lily_A", reg.Lilypads.Lilypad_02)
	add("Lily_B", reg.Lilypads.Lilypad_05)
	-- logs and stumps
	add("Log_A", reg.Logs.Log_01)
	add("Log_B", reg.Logs.Log_02)
	add("LogPile", L["Stylized Asset Pack II (Props)"]["Stylized logs"].LogPile)
	local stumps = F["Tree Log Stumps"]
	add("Stump_L", byName(stumps, "Tree Stump", 14))
	add("Stump_M", byName(stumps, "Tree Stump", 9))
	add("Stump_S", byName(stumps, "Tree Stump", 7))
	-- rocks: pale rounded boulders (Inno, Fantasy), columnar cliff rocks, big cliff masses, standing stones
	local rocks = inno.Customizable_Assets.Rocks
	for _, n in { "Rock_01", "Rock_02", "Rock_03", "Rocks_04", "Rocks_05", "Rocks_06", "Rocks_07" } do
		add("Boulder_" .. n, rocks[n])
	end
	for i = 1, 6 do
		add("BoulderPile_" .. i, rocks.Presets["Rock_Preset_0" .. i])
	end
	local fantasy = R["Stylized Fantasy Rocks"]
	for _, n in { "Stylized Rock I", "Stylized Rock II", "Stylized Rock III", "Stylized Rock V" } do
		add("Fantasy_" .. n:sub(15), fantasy[n])
	end
	for _, c in fantasy:GetChildren() do
		-- the plain Rock IV only: the other Rock IV carries rainbow ore crystals (31 parts) and is never used
		if c.Name == "Stylized Rock IV" and #c:GetDescendants() <= 2 then
			add("Fantasy_IV", c)
		end
	end
	for i, c in R["Stylized Cliff Rock Pack I"]:GetChildren() do
		add("CliffRock_" .. i, c)
	end
	for i, c in R["Stylized Cliff Rock Pack II"]:GetChildren() do
		add("CliffMass_" .. i, c)
	end
	for i, c in R["Stylized Stone Rock Pack"]:GetChildren() do
		add("Stone_" .. i, c)
	end
	kit.Parent = SS
	return kit
end

--[[ Placement helpers ]]

local KIT = SS:FindFirstChild("WildsKit")
if CFG.kit or not KIT then
	KIT = buildKit()
end

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }

local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), terrainParams)
	return hit
end

-- world-space vertical extent of a model or part (unions stand rotated, so local Size.Y lies)
local function worldSpanY(inst)
	local minY, maxY = math.huge, -math.huge
	local list = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") then
			local cf, s = p.CFrame, p.Size / 2
			local ext = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
			minY = math.min(minY, cf.Position.Y - ext)
			maxY = math.max(maxY, cf.Position.Y + ext)
		end
	end
	return minY, maxY
end

-- kind: "foliage" | "tree" | "rock"
local function style(inst, kind, scale, height)
	local list = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Locked = false
			if kind == "rock" and height >= 6 then
				p.CanCollide = true
				p.CanQuery = true
				p.CanTouch = false
				if p:IsA("MeshPart") then
					pcall(function()
						p.CollisionFidelity = Enum.CollisionFidelity.Hull
					end)
				end
			else
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				if p:IsA("MeshPart") then
					pcall(function()
						p.CollisionFidelity = Enum.CollisionFidelity.Box
					end)
				end
			end
			p.CastShadow = (kind == "tree" and height > 24) or (kind == "rock" and height > 8)
		end
	end
end

local placed = 0
local parts = 0
-- src: kit name; at: ground hit; yaw (rad); scale; sink (fraction of height pushed below the ground)
local function place(parent, name, pos, yaw, scale, kind, sink, tilt)
	local src = KIT:FindFirstChild(name)
	if not src then
		warn("WildsKit missing " .. name)
		return nil
	end
	local c = src:Clone()
	local rot = (if c:IsA("Model") then c:GetPivot() else c.CFrame).Rotation
	local spin = CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt and tilt.X or 0, 0, tilt and tilt.Y or 0)
	if c:IsA("Model") then
		if scale ~= 1 then
			c:ScaleTo(c:GetScale() * scale)
		end
		c:PivotTo(CFrame.new(pos) * spin * rot)
	else
		c.Size *= scale
		c.CFrame = CFrame.new(pos) * spin * rot
	end
	local minY, maxY = worldSpanY(c)
	local h = maxY - minY
	local drop = (minY - pos.Y) + h * (sink or 0.05)
	if c:IsA("Model") then
		c:PivotTo(c:GetPivot() - Vector3.new(0, drop, 0))
	else
		c.CFrame -= Vector3.new(0, drop, 0)
	end
	style(c, kind, scale, h)
	c.Parent = parent
	placed += 1
	for _, d in (c:IsA("BasePart") and { c } or c:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return c, h
end

local function collider(parent, pos, radius, height)
	local p = Instance.new("Part")
	p.Name = "TrunkCollider"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos + Vector3.new(0, height / 2 - 1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	parts += 1
end

--[[ Layout context ]]

local function spline(pts)
	local out = {}
	local n = #pts
	for i = 1, n - 1 do
		local p0, p1, p2, p3 = pts[math.max(i - 1, 1)], pts[i], pts[i + 1], pts[math.min(i + 2, n)]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 3))
		for s = 0, steps - 1 do
			local t = s / steps
			local t2, t3 = t * t, t * t * t
			table.insert(out, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
		end
	end
	table.insert(out, pts[n])
	return out
end
local function segDist(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (p - (a + ab * t)).Magnitude
end
local function lineDist(p, pts)
	local best = math.huge
	for s = 1, #pts - 1 do
		best = math.min(best, segDist(p, pts[s], pts[s + 1]))
	end
	return best
end

local wilds = workspace.Wilds
local zonesDiscs = {}
for _, z in wilds.Zones:GetChildren() do
	if z:IsA("BasePart") then
		table.insert(zonesDiscs, { p = Vector2.new(z.Position.X, z.Position.Z), r = z:GetAttribute("Radius") or 30 })
	end
end
local nodes = {}
for _, n in wilds.QiNodes:GetChildren() do
	local b = n:FindFirstChild("Base")
	if b then
		table.insert(nodes, Vector2.new(b.Position.X, b.Position.Z))
	end
end

-- move the old ring dressing that sits inside a zone box out of the way (once)
local function retireOld(box)
	local store = SS:FindFirstChild("_WildsReplaced")
	if not store then
		store = Instance.new("Folder")
		store.Name = "_WildsReplaced"
		store.Parent = SS
	end
	local moved = 0
	for _, ringName in { "InnerRing", "MiddleRing" } do
		local ring = workspace.Map.Ground:FindFirstChild(ringName)
		if ring then
			for _, grp in ring:GetChildren() do
				for _, c in grp:GetChildren() do
					local pos = if c:IsA("Model") then c:GetPivot().Position elseif c:IsA("BasePart") then c.Position else nil
					if pos and pos.X > box[1] and pos.X < box[3] and pos.Z > box[2] and pos.Z < box[4] and pos.Y < 150 then
						c:SetAttribute("FromPath", c:GetFullName())
						c.Parent = store
						moved += 1
					end
				end
			end
		end
	end
	return moved
end

--[[ Dress ]]

local function weighted(rng, list)
	local total = 0
	for i = 2, #list, 2 do
		total += list[i]
	end
	local r = rng:NextNumber() * total
	for i = 1, #list, 2 do
		r -= list[i + 1]
		if r <= 0 then
			return list[i]
		end
	end
	return list[1]
end

local KITS = {
	Inner = {
		trees = { "Layer_Dark", 30, "Layer_Light", 12, "Wide_M", 16, "Leafy_M", 4, "PineLayered", 18, "SmallRound", 8, "Wide_L", 2 },
		hillTrees = { "PineLayered", 40, "Layer_Dark", 25, "Pine_A", 10, "Pine_B", 10, "Pine_C", 10 },
		riverTrees = { "Layer_Dark", 1 },
		bambooTones = { "6F8A4E", "7A9455", "66804A", "809A5C" },
		cliff = { "BoulderPile_1", 3, "BoulderPile_2", 3, "BoulderPile_4", 3, "BoulderPile_6", 3, "CliffMass_4", 2, "CliffMass_3", 1, "Boulder_Rocks_06", 2, "Fantasy_IV", 2, "Boulder_Rock_01", 2, "Boulder_Rocks_07", 2 },
		outcrop = { "BoulderPile_2", 2, "BoulderPile_5", 2, "CliffMass_3", 1, "Fantasy_IV", 2, "Boulder_Rocks_07", 2, "Boulder_Rock_01", 2 },
		small = { "Boulder_Rock_02", 2, "Boulder_Rock_03", 2, "Boulder_Rocks_04", 2, "Fantasy_I", 2, "Fantasy_V", 2, "Boulder_Rocks_05", 1 },
		bushes = { "Bush_L", 2, "Bush_M", 4, "Bush_S", 3, "Bush_XS", 3, "Shrub_A", 3, "Shrub_B", 3, "Fern_L", 3, "Fern_M", 3, "Leaf_A", 2 },
		cover = { "Clover_M", 3, "Clover_L", 2, "Fern_S", 2, "Mushroom_L", 1 },
		edge = { "Flowers_Blue", 3, "Flowers_White", 2, "Clover_M", 5, "Fern_S", 3, "Leaf_A", 2 },
	},
	Middle = {
		trees = { "Dead_L", 18, "Dead_M", 18, "Dead_S", 12, "Birch_L", 8, "Birch_M", 10, "Birch_S", 8, "Withered_L", 6, "Withered_M", 8, "SmallBare", 10 },
		hillTrees = { "Dead_L", 3, "Dead_M", 3, "Birch_M", 2, "SmallBare", 2 },
		riverTrees = { "Layer_Dark", 3, "SmallRound", 2, "Birch_M", 2 },
		cliff = { "CliffRock_1", 3, "CliffRock_2", 3, "CliffRock_3", 2, "CliffMass_1", 2, "CliffMass_4", 2, "CliffMass_5", 2, "BoulderPile_3", 2, "Fantasy_III", 2 },
		outcrop = { "CliffRock_1", 2, "CliffRock_2", 2, "CliffMass_2", 1, "CliffMass_5", 1, "Fantasy_II", 2, "BoulderPile_3", 1 },
		small = { "Boulder_Rock_02", 2, "Boulder_Rocks_04", 2, "CliffRock_3", 2, "Fantasy_III", 2, "Stone_4", 1 },
		bushes = { "BushDry_M", 1, "BushDry_S", 1, "Fern_M", 3, "Shrub_C", 3, "Stump_M", 2, "Stump_S", 2, "Log_A", 1, "Log_B", 1 },
		cover = { "Fern_S", 3, "Stone_2", 1, "Stone_5", 1 },
		edge = { "Fern_S", 3, "Stone_1", 1, "Stone_3", 1, "Stone_6", 1, "Shrub_C", 1 },
	},
}

-- bamboo belongs to the Inner Wilds' old stone places: groves round the hidden hollow, the steles, the
-- shrine's back slope and Old Stone Hill, plus a noise-field of smaller stands
local BAMBOO_SPOTS = { { -128, 598, 46 }, { -40, 690, 26 }, { -140, 840, 40 }, { -120, 580, 70 }, { -80, 744, 28 }, { 300, 640, 24 } }

local report = {}
for _, zoneName in CFG.zones or { "Inner", "Middle" } do
	local Z = LAYOUT[zoneName]
	local K = KITS[zoneName]
	local rng = Random.new(zoneName == "Inner" and 4101 or 4202)
	local seed = zoneName == "Inner" and 31 or 47
	local moved = retireOld(Z.box)

	local holder = workspace.Map.Ground:FindFirstChild("Wilds" .. zoneName)
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "Wilds" .. zoneName
		holder.Parent = workspace.Map.Ground
	end
	local old = holder:FindFirstChild("Dressing")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Dressing"
	local groups = {}
	for _, g in { "Trees", "Bamboo", "Rocks", "Shrubs", "GroundCover", "PathEdge", "Colliders" } do
		local f = Instance.new("Folder")
		f.Name = g
		f.Parent = root
		groups[g] = f
	end
	placed, parts = 0, 0

	local paths = {}
	for _, path in Z.paths do
		table.insert(paths, { name = path.name, w = path.w, pts = spline(path.pts) })
	end
	local ridges = {}
	for _, r in Z.ridges or {} do
		table.insert(ridges, { pts = spline(r.pts), h = r.h, hw = r.hw, rock = r.rock })
	end
	local pois = Z.pois or {}
	local caves = Z.caves or {}

	local function pathEdge(p)
		local edge = math.huge
		for _, path in paths do
			edge = math.min(edge, lineDist(p, path.pts) - path.w / 2)
		end
		return edge
	end
	local function free(p, margin)
		for _, poi in pois do
			if (p - Vector2.new(poi[2], poi[3])).Magnitude < poi[4] + (margin or 0) then
				return false
			end
		end
		for _, cave in caves do
			local dir = Vector2.new(math.cos(math.rad(cave.heading)), math.sin(math.rad(cave.heading)))
			local mouth = Vector2.new(cave.x, cave.z)
			if segDist(p, mouth - dir * 14, mouth + dir * cave.length) < cave.radius + 3 then
				return false
			end
		end
		for _, n in nodes do
			if (p - n).Magnitude < 9 then
				return false
			end
		end
		return true
	end
	local function zoneDist(p)
		local zd = math.huge
		for _, d in zonesDiscs do
			zd = math.min(zd, (p - d.p).Magnitude - d.r)
		end
		return zd
	end
	local function bambooAt(x, z)
		if zoneName ~= "Inner" then
			return false
		end
		for _, b in BAMBOO_SPOTS do
			if (Vector2.new(x, z) - Vector2.new(b[1], b[2])).Magnitude < b[3] then
				return true
			end
		end
		return math.noise(x / 70, z / 70, seed + 5) > 0.32
	end
	local function addTree(pick, pos, scaleLo, scaleHi, tilt)
		local s = rng:NextNumber(scaleLo, scaleHi)
		if pick == "Wide_L" then
			s *= 0.55
		elseif pick:find("^Pine_") then
			s *= 0.75
		end
		local yaw = rng:NextNumber(0, math.pi * 2)
		local _, h = place(groups.Trees, pick, pos, yaw, s, "tree", 0.03, tilt)
		if h and h > 28 then
			collider(groups.Colliders, pos, math.clamp(h / 30, 1.2, 3), 14)
		end
	end
	local function addBamboo(pos)
		local c = place(groups.Bamboo, "Bamboo_" .. rng:NextInteger(1, 3), pos, rng:NextNumber(0, 6.28), rng:NextNumber(0.95, 1.5), "foliage", 0.04)
		if c then
			c.UsePartColor = true
			c.Color = Color3.fromHex(K.bambooTones[rng:NextInteger(1, #K.bambooTones)])
			c.Material = Enum.Material.Plastic
			c.CastShadow = true
		end
	end

	-- 1) the field: a jittered grid read against the layout
	local CELL = 9
	local x0, z0, x1, z1 = Z.box[1] + 10, Z.box[2] + 4, Z.box[3] - 10, Z.box[4] - 4
	local col = 0
	for gx = x0, x1, CELL do
		col += 1
		for gz = z0, z1, CELL do
			local x = gx + rng:NextNumber(-3.8, 3.8)
			local z = gz + rng:NextNumber(-3.8, 3.8)
			local p = Vector2.new(x, z)
			local roll, roll2 = rng:NextNumber(), rng:NextNumber()
			local yaw = rng:NextNumber(0, math.pi * 2)
			local edge = pathEdge(p)
			if edge < 4 or not free(p) then
				continue -- path edges are dressed by the walk below
			end
			local zoneD = zoneDist(p)
			local hill, rocky = 0, false
			for _, r in ridges do
				local d = lineDist(p, r.pts)
				if d < r.hw then
					local s = 1 - d / r.hw
					if r.h * s > hill then
						hill = r.h * s
						rocky = r.rock == true
					end
				end
			end
			local hit = ground(x, z)
			if not hit or hit.Material == Enum.Material.Water then
				continue
			end
			local pos = hit.Position
			local steep = hit.Normal.Y < 0.78
			local grove = math.noise(x / 80, z / 80, seed) + 0.45 * math.noise(x / 27, z / 27, seed + 1)
			local tilt = Vector2.new(rng:NextNumber(-0.05, 0.05), rng:NextNumber(-0.05, 0.05))

			if zoneD < 2 then
				-- open clearings: beasts spawn and world events land here; low cover only
				if roll < 0.04 then
					place(groups.GroundCover, weighted(rng, K.cover), pos, yaw, rng:NextNumber(0.7, 1.2), "foliage", 0.2)
				end
				continue
			end

			if steep then
				-- cliff faces: sized-up rocks of several kinds sunk into the slope (kept off POI sightlines)
				if roll < 0.45 and free(p, 8) then
					local pick = weighted(rng, K.cliff)
					local s = pick:find("CliffMass") and rng:NextNumber(0.3, 0.5) or rng:NextNumber(0.9, 1.8)
					place(groups.Rocks, pick, pos, yaw, s, "rock", rng:NextNumber(0.3, 0.45), tilt * 2)
				end
				continue
			end

			if rocky and hill > 6 and roll < 0.1 and free(p, 8) then
				-- an outcrop: one big piece with two smaller ones leaning on it
				local big = weighted(rng, K.outcrop)
				local bs = big:find("CliffMass") and rng:NextNumber(0.3, 0.5) or rng:NextNumber(1.2, 2.2)
				local _, bh = place(groups.Rocks, big, pos, yaw, bs, "rock", 0.25, tilt)
				for k = 1, 2 do
					local a = yaw + k * 2.4 + rng:NextNumber(-0.4, 0.4)
					local r = (bh or 10) * 0.6 + rng:NextNumber(1, 4)
					local q = ground(x + math.cos(a) * r, z + math.sin(a) * r)
					if q then
						place(groups.Rocks, weighted(rng, K.small), q.Position, rng:NextNumber(0, 6.28), rng:NextNumber(0.7, 1.3), "rock", 0.2, tilt)
					end
				end
				continue
			end

			local pTree
			if zoneName == "Inner" then
				pTree = grove > 0.12 and 0.45 or (grove > -0.18 and 0.14 or 0.025)
			else
				pTree = grove > 0.2 and 0.26 or (grove > -0.1 and 0.07 or 0.012)
			end
			if zoneD < 20 then
				pTree += zoneName == "Inner" and 0.28 or 0.1 -- the ring of trees round each clearing
			end
			if edge > 7 and edge < 18 then
				pTree += 0.1 -- trees frame the paths a few steps back
			end
			if hill > 4 then
				pTree += 0.06
			end
			if edge > 7 and roll < pTree then
				if bambooAt(x, z) then
					local n = roll2 < 0.4 and 2 or 1
					for k = 1, n do
						local a, r = rng:NextNumber(0, 6.28), k == 1 and 0 or rng:NextNumber(4, 7)
						local q = ground(x + math.cos(a) * r, z + math.sin(a) * r)
						if q and q.Material ~= Enum.Material.Water then
							addBamboo(q.Position)
						end
					end
				else
					local list = K.trees
					if zoneName == "Middle" and z < 965 and math.noise(x / 30, z / 30, seed + 9) > 0 then
						list = K.riverTrees -- the last living trees by the river
					elseif hill > 9 then
						list = K.hillTrees
					end
					addTree(weighted(rng, list), pos, 0.95, 1.45, zoneName == "Middle" and tilt * 1.6 or nil)
				end
				continue
			end

			-- understory
			local pBush = zoneName == "Inner" and ((grove > 0.05 and 0.3 or 0.07) + ((edge > 4 and edge < 12) and 0.15 or 0)) or 0.08
			if roll < pBush then
				place(groups.Shrubs, weighted(rng, K.bushes), pos, yaw, rng:NextNumber(0.75, 1.35), "foliage", 0.12)
				if roll2 < 0.4 then
					local a = rng:NextNumber(0, 6.28)
					local q = ground(x + math.cos(a) * 4.5, z + math.sin(a) * 4.5)
					if q then
						place(groups.Shrubs, weighted(rng, K.cover), q.Position, a, rng:NextNumber(0.7, 1.1), "foliage", 0.1)
					end
				end
			elseif roll < pBush + 0.05 then
				place(groups.Rocks, weighted(rng, K.small), pos, yaw, rng:NextNumber(0.6, 1.5), "rock", 0.25, tilt)
			elseif roll < pBush + 0.08 then
				place(groups.GroundCover, weighted(rng, K.cover), pos, yaw, rng:NextNumber(0.7, 1.1), "foliage", 0.1)
			end
		end
		if col % 6 == 0 then
			task.wait()
		end
	end

	-- 2) the path edges: walk each path, dressing both sides in runs (clumps with bare stretches between)
	for pi, path in paths do
		local pts = path.pts
		local travelled, nextRock = 0, rng:NextNumber(20, 45)
		for s = 1, #pts - 1, 1 do
			local a, b = pts[s], pts[s + 1]
			local seg = b - a
			local len = seg.Magnitude
			if len < 0.01 then
				continue
			end
			local dir = seg / len
			local nrm = Vector2.new(-dir.Y, dir.X)
			travelled += len
			for side = -1, 1, 2 do
				local run = math.noise(travelled / 22, pi * 3.1 + side, seed + 20) -- clumps along the edge
				if run > -0.1 and rng:NextNumber() < 0.75 then
					local off = path.w / 2 + rng:NextNumber(0.3, 3.2)
					local q2 = a + nrm * side * off + dir * rng:NextNumber(0, len)
					if pathEdge(q2) > -0.2 and free(q2) then
						local hit = ground(q2.X, q2.Y)
						if hit and hit.Material ~= Enum.Material.Water then
							local pick = weighted(rng, K.edge)
							local sc = pick:find("Flowers") and rng:NextNumber(0.2, 0.36) or rng:NextNumber(0.6, 1.1)
							place(groups.PathEdge, pick, hit.Position, rng:NextNumber(0, 6.28), sc, "foliage", 0.1)
						end
					end
				end
				if run > 0.25 and rng:NextNumber() < 0.25 then
					-- a bush a little further back
					local off = path.w / 2 + rng:NextNumber(3.5, 7)
					local q2 = a + nrm * side * off
					if pathEdge(q2) > 2.5 and free(q2) and zoneDist(q2) > 2 then
						local hit = ground(q2.X, q2.Y)
						if hit and hit.Material ~= Enum.Material.Water then
							place(groups.PathEdge, weighted(rng, K.bushes), hit.Position, rng:NextNumber(0, 6.28), rng:NextNumber(0.7, 1.2), "foliage", 0.12)
						end
					end
				end
			end
			-- a rock cluster every so often on one side: big + medium + small, 3-8 studs off the edge
			if travelled > nextRock then
				nextRock = travelled + rng:NextNumber(40, 75)
				local side = rng:NextNumber() < 0.5 and -1 or 1
				local centre = a + nrm * side * (path.w / 2 + rng:NextNumber(5, 9))
				if pathEdge(centre) > 3 and free(centre, 4) and zoneDist(centre) > 4 then
					local hit = ground(centre.X, centre.Y)
					if hit and hit.Material ~= Enum.Material.Water then
						local yaw = rng:NextNumber(0, 6.28)
						local big = zoneName == "Inner" and weighted(rng, { "Boulder_Rock_01", 2, "BoulderPile_1", 1, "BoulderPile_6", 1, "Fantasy_IV", 1, "Boulder_Rocks_06", 2 })
							or weighted(rng, { "CliffRock_2", 2, "CliffRock_1", 1, "Fantasy_II", 1, "BoulderPile_3", 1 })
						local bs = big:find("Pile") and rng:NextNumber(0.4, 0.6) or rng:NextNumber(0.9, 1.4)
						local _, bh = place(groups.Rocks, big, hit.Position, yaw, bs, "rock", 0.2)
						for k = 1, rng:NextInteger(2, 3) do
							local ang = yaw + k * 2.2 + rng:NextNumber(-0.5, 0.5)
							local r = (bh or 8) * 0.55 + rng:NextNumber(1, 3)
							local q2 = centre + Vector2.new(math.cos(ang), math.sin(ang)) * r
							if pathEdge(q2) > 0.5 then
								local qh = ground(q2.X, q2.Y)
								if qh then
									place(groups.Rocks, weighted(rng, K.small), qh.Position, ang, rng:NextNumber(0.4, 0.9) * (k == 1 and 1.4 or 1), "rock", 0.25)
								end
							end
						end
						-- moss and ferns at the foot
						local fh = ground(centre.X - nrm.X * side * 3, centre.Y - nrm.Y * side * 3)
						if fh then
							place(groups.PathEdge, zoneName == "Inner" and "Fern_M" or "Fern_S", fh.Position, yaw, rng:NextNumber(0.7, 1.0), "foliage", 0.1)
						end
					end
				end
			end
		end
		task.wait()
	end

	-- 3) keep the walking line clear: colliding rocks and trunk colliders that reach into a path go
	local cleared = 0
	for _, g in { groups.Rocks, groups.Colliders } do
		for _, c in g:GetChildren() do
			local cf, size
			if c:IsA("Model") then
				cf, size = c:GetBoundingBox()
			else
				cf, size = c.CFrame, c.Size
			end
			local reach = math.max(size.X, size.Z) * 0.4
			if g == groups.Colliders then
				reach = size.Y / 2
			end
			local collides = c:IsA("BasePart") and c.CanCollide or (c:FindFirstChildWhichIsA("BasePart", true) and c:FindFirstChildWhichIsA("BasePart", true).CanCollide)
			local at = Vector2.new(cf.Position.X, cf.Position.Z)
			local inOpen = false
			for _, d in zonesDiscs do
				inOpen = inOpen or (at - d.p).Magnitude < d.r + 2 + reach
			end
			for _, n in nodes do
				inOpen = inOpen or (at - n).Magnitude < 8 + reach
			end
			if collides and (inOpen or pathEdge(at) < reach) then
				-- also out of the zone discs (spawns, treasures, events) and away from the qi nodes
				c:Destroy()
				cleared += 1
			end
		end
	end

	-- trees whose trunk (or a wide tree's root flare) reaches into a zone disc go too, with their colliders
	for _, c in groups.Trees:GetChildren() do
		local _, size = c:GetBoundingBox()
		local p = c:GetPivot().Position
		local at = Vector2.new(p.X, p.Z)
		local reach = c.Name:find("Wide") and size.X * 0.22 or 4
		for _, d in zonesDiscs do
			if (at - d.p).Magnitude < d.r + reach then
				for _, col in groups.Colliders:GetChildren() do
					if (Vector2.new(col.Position.X, col.Position.Z) - at).Magnitude < 1 then
						col:Destroy()
					end
				end
				c:Destroy()
				cleared += 1
				break
			end
		end
	end

	-- 4) pool edges: reeds and lily pads
	for _, pool in Z.pools or {} do
		local n = math.floor(pool[3] * 1.2)
		for k = 1, n do
			local a = k / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = pool[3] * rng:NextNumber(0.85, 1.15)
			local hit = ground(pool[1] + math.cos(a) * r, pool[2] + math.sin(a) * r)
			if hit then
				place(groups.GroundCover, rng:NextNumber() < 0.7 and "Reeds" or "Fern_S", hit.Position, a, rng:NextNumber(1.2, 2.2), "foliage", 0.1)
			end
		end
		for _ = 1, math.floor(pool[3] / 4) do
			local a, r = rng:NextNumber(0, 6.28), pool[3] * rng:NextNumber(0.2, 0.7)
			local lily = KIT:FindFirstChild(rng:NextNumber() < 0.5 and "Lily_A" or "Lily_B"):Clone()
			lily:PivotTo(CFrame.new(pool[1] + math.cos(a) * r, 0.55, pool[2] + math.sin(a) * r) * CFrame.Angles(0, a, 0) * lily:GetPivot().Rotation)
			local ls = rng:NextNumber(0.3, 0.5)
			if lily:IsA("Model") then
				lily:ScaleTo(ls)
			else
				lily.Size *= ls
			end
			style(lily, "foliage", 1, 0)
			lily.Parent = groups.GroundCover
			placed += 1
		end
	end

	root.Parent = holder
	table.insert(report, string.format("%s: %d pieces, %d parts, %d cleared off paths (old ring dressing retired: %d)", zoneName, placed, parts, cleared, moved))
	task.wait()
end

ChangeHistoryService:SetWaypoint("Wilds dressing")
return table.concat(report, "\n")
