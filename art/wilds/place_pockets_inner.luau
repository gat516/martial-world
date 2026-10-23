--!nocheck
-- Places the Inner Wilds pocket prefabs (ServerStorage.InnerWildsPrefabs, built by the POI builder) on
-- the valley (docs/map/inner-wilds-rework.md). Run in Studio Edit mode through execute_luau
-- after terrain_wilds.luau, before water_inner.luau and ambience_inner.luau. Rebuilds
-- Map.Ground.WildsInner.Pockets each run.
--
-- Each prefab has an upright pivot at its ground point and its front (approach side) on local -Z. The
-- table below sets where and which way each goes (yaw: radians about Y; local -Z ends up facing
-- (-sin yaw, 0, -cos yaw)). Its pivot sits on the terrain (the lowest of a few samples over the
-- footprint, so nothing floats; tall rocks go into the ground). Prefabs marked ReseatChildren have each
-- child model grounded on its own (the Wolf Den ring stones). The four Inner caches move onto their
-- pocket's CacheSpotAnchor; qi node spots are reported for Wilds.rbxmx. Every placed prefab keeps its
-- POI tag and attributes and is tagged NeedsHandPass (structures and fits the user checks by hand).

local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local function waterPart(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Water" or game:GetService("CollectionService"):HasTag(d, "StylizedWater")) then
			return d
		end
	end
	return nil
end
local PREFABS = SS:WaitForChild("InnerWildsPrefabs")
local ground = workspace.Map.Ground.WildsInner

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end

local rad = math.rad
local PLACE = {
	-- name, x, z, yaw, ground mode ("min" over the footprint, "centre", or a number), cache to move here
	{ "WolfDen", -700, 786, rad(-90), "min", "Cache_DragonPierce", "Den crag, cave and bones: check the cave mouth is walkable, the crag meets the ground and the West wall without gaps." },
	{ "WolfDenRing", -580, 780, rad(-90), "centre", nil, "Ring stones grounded one by one: check none float or lean into each other, and the gaps line up with the WestArm (east) and the den (west)." },
	{ "WolfDenRockGate", -480, 760, rad(-90), "min", nil, "Rock gate over the WestArm: check the path runs through the gap and nothing blocks it." },
	{ "BambooHollow", -330, 590, rad(180), "min", "Cache_CrescentSweep", "Spring under the north wall's trickle: check the outcrop meets the wall rocks, the spring sits in the ground (no carve was done), rim stones close it." },
	{ "FallenGiant", 300, 800, 0, "banks", nil, "Log bridge over Giants Gully: check both ends rest on the banks, the deck is walkable and the limb ramp reaches the gully floor." },
	{ "HuntersCamp", 660, 702, rad(127.7), "centre", "Cache_RampagingTiger", "Camp with a lookout tower: check the tower's ladder reaches the deck and the ground, the tent meets its poles, crates sit on the ground." },
	{ "ThreePillarsHermitage", -566, 1176, rad(-51.9), "centre", nil, "Hut, terrace and ledge stair: the prefab's buttress rocks stand in for the SouthWestFar karst foot; check them against the real pillars and that the ledge stair reaches its landing." },
	{ "LotusMere", -260, 1170, 0, 4.6, nil, "Mere with pavilion, boardwalk and skiff: check the water sits in the dug floor (sand at Y 3.4), the boardwalk lands on the north bank and the pavilion's posts reach the bed." },
	{ "ShrineTerrace", -62, 1325, 0, "min", "Cache_HeavenSplitter", "Hero shrine: check the terrace back meets the Shrine Cliff rocks, the front stair reaches the ground, the pine's canopy clears the pavilion roof." },
	{ "TwinJadeSpring", 0, 0, 0, "min", nil, "Spring pool under the Twin-Jade falls: check the falls land in the pool, the fall rocks meet the notch and the karst, the shrine sits level." },
}

local old = ground:FindFirstChild("Pockets")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Pockets"
root.Parent = ground

local report = {}
local nodes = {}
local function footprintMin(m)
	local cf, size = m:GetBoundingBox()
	local lo = math.huge
	-- sample the footprint's outer ring (not the middle, where a prefab's pool carves the ground away
	-- and a re-run would sink the prefab)
	for _, o in { { 0.45, 0 }, { -0.45, 0 }, { 0, 0.45 }, { 0, -0.45 }, { 0.4, 0.4 }, { -0.4, 0.4 }, { 0.4, -0.4 }, { -0.4, -0.4 } } do
		local p = cf * Vector3.new(size.X * o[1], 0, size.Z * o[2])
		lo = math.min(lo, gy(p.X, p.Z))
	end
	return lo
end

for _, e in PLACE do
	local name, x, z, yaw, mode, cacheName, why = e[1], e[2], e[3], e[4], e[5], e[6], e[7]
	local src = PREFABS:FindFirstChild(name)
	if not src then
		table.insert(report, name .. ": prefab missing")
		continue
	end
	local m = src:Clone()
	if name == "TwinJadeSpring" then
		-- under the Twin-Jade falls: SpringPool at the foot of the notch lip, rocks (+Z) toward the karst
		local notch = ground.Walls:FindFirstChild("TwinJadeNotch")
		local lip = notch and notch:FindFirstChild("Wall_TJ03_NotchLip")
		local lipPos = lip and lip:GetPivot().Position or Vector3.new(625, 0, 1251)
		local inward = (Vector3.new(565, 0, 1190) - Vector3.new(lipPos.X, 0, lipPos.Z)).Unit
		yaw = math.atan2(-inward.X, -inward.Z) -- local +Z points back at the notch
		m:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, yaw, 0))
		local pool = m:FindFirstChild("SpringPool", true)
		local poolPos = pool and pool:GetBoundingBox().Position
		local want = Vector3.new(lipPos.X, 0, lipPos.Z) + inward * 14
		local off = if poolPos then want - Vector3.new(poolPos.X, 0, poolPos.Z) else want
		x, z = off.X, off.Z
	end
	m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * src:GetPivot().Rotation)
	local y
	if type(mode) == "number" then
		y = mode
	elseif mode == "centre" then
		y = gy(x, z)
	elseif mode == "banks" then
		local r = CFrame.Angles(0, yaw, 0)
		local a, b = r * Vector3.new(38, 0, 0), r * Vector3.new(-38, 0, 0)
		y = math.min(gy(x + a.X, z + a.Z), gy(x + b.X, z + b.Z))
	else
		y = footprintMin(m)
	end
	m:PivotTo(m:GetPivot() + Vector3.new(0, y, 0))
	if src:GetAttribute("ReseatChildren") then
		for _, c in m:GetChildren() do
			if c:IsA("Model") then
				local cf, size = c:GetBoundingBox()
				local g = gy(cf.X, cf.Z)
				c:PivotTo(c:GetPivot() + Vector3.new(0, (g - size.Y * 0.12) - (cf.Y - size.Y / 2), 0))
			end
		end
	end
	-- LotusMere: its Shore discs top out 0.1 under the water's top and z-fight with it (reads as a sand
	-- pond); sink them under the surface until the prefab is fixed
	if name == "LotusMere" then
		local w = waterPart(m)
		local top = w and (w.Position.Y + math.min(w.Size.X, w.Size.Y, w.Size.Z) / 2) or 0
		for _, c in m:GetDescendants() do
			if c:IsA("BasePart") and c.Name == "Shore" then
				local sTop = c.Position.Y + c.Size.X / 2
				if sTop > top - 0.6 then
					c.CFrame -= Vector3.new(0, sTop - (top - 0.6), 0)
				end
			end
		end
	end
	m.Parent = root
	-- dig the terrain the prefab's water needs: every TerrainCarve disc (an upright cylinder part)
	-- clears a column from its bottom up, so the bank never covers the water
	for _, c in m:GetDescendants() do
		if c:IsA("BasePart") and c.Name == "TerrainCarve" then
			local r = math.max(c.Size.Y, c.Size.Z) / 2
			local bottom = c.Position.Y - c.Size.X / 2
			workspace.Terrain:FillCylinder(CFrame.new(c.Position.X, bottom + 12, c.Position.Z), 24, r, Enum.Material.Air)
		end
	end
	CollectionService:AddTag(m, "POI")
	CollectionService:AddTag(m, "NeedsHandPass")
	m:SetAttribute("HandPassReason", why)
	m:SetAttribute("HandPassStatus", "open")
	-- caches onto the pocket's cache spot
	local spot = m:FindFirstChild("CacheSpotAnchor", true)
	if cacheName and spot then
		local cache = workspace.Map.Markers.ManualCaches:FindFirstChild(cacheName)
		if cache then
			local f = cache.Footing
			local g = gy(spot.Position.X, spot.Position.Z)
			local base = math.max(g, spot.Position.Y - spot.Size.Y / 2)
			cache:PivotTo(cache:GetPivot() + Vector3.new(spot.Position.X - f.Position.X, (base - 0.3) - (f.Position.Y - f.Size.Y / 2), spot.Position.Z - f.Position.Z))
		end
	end
	local q = m:FindFirstChild("QiNodeSpotAnchor", true)
	if q then
		table.insert(nodes, string.format("%s QiNodeSpot (%.1f, %.1f, %.1f)", name, q.Position.X, q.Position.Y, q.Position.Z))
	end
	table.insert(report, string.format("%s at (%.0f, %.1f, %.0f) yaw %.0f", name, x, y, z, math.deg(yaw)))
	task.wait()
end
return table.concat(report, "\n") .. "\n" .. table.concat(nodes, "\n")
