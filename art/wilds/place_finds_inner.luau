--!nocheck
-- Places the Inner Wilds finds (ServerStorage.InnerWildsPrefabs F01..F31, built by the POI builder) on
-- the valley (docs/map/inner-wilds-rework.md, finds list). Run in Studio Edit mode after
-- terrain_wilds.luau and place_pockets_inner.luau. Rebuilds Map.Ground.WildsInner.Finds each run.
--
-- Each find goes to its PlannedSpot attribute with its front (local -Z) facing the nearest path (from
-- the terrain pass's saved splines in Map.Ground.WildsLayout), unless OVERRIDE says otherwise. It is
-- pushed off the path and out of the pocket prefabs if its footprint overlaps them, then seated on the
-- lowest ground under its footprint. Structural finds are tagged NeedsHandPass.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local PREFABS = SS.InnerWildsPrefabs
local ground = workspace.Map.Ground.WildsInner

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end

-- paths: segments { ax, az, bx, bz, halfWidth }
local SEGS = {}
local saved = HttpService:JSONDecode(workspace.Map.Ground.WildsLayout.Value)
for _, path in saved.zones.Inner.paths do
	local pts = path.pts
	for i = 1, #pts - 3, 2 do
		table.insert(SEGS, { pts[i], pts[i + 1], pts[i + 2], pts[i + 3], (path.w or 6) / 2 })
	end
end
local function nearestPath(x, z)
	local best, bp, bw = math.huge, nil, 3
	for _, s in SEGS do
		local dx, dz = s[3] - s[1], s[4] - s[2]
		local L = dx * dx + dz * dz
		local t = L > 0 and math.clamp(((x - s[1]) * dx + (z - s[2]) * dz) / L, 0, 1) or 0
		local px, pz = s[1] + dx * t, s[2] + dz * t
		local d = math.sqrt((px - x) ^ 2 + (pz - z) ^ 2)
		if d < best then
			best, bp, bw = d, Vector3.new(px, 0, pz), s[5]
		end
	end
	return best, bp, bw
end

local rad = math.rad
local function facing(dx, dz) -- yaw that turns local -Z toward (dx, dz)
	return math.atan2(-dx, -dz)
end
-- name -> { x?, z?, yaw?, ground?, keep? (stays on its spot over a path), flag? (hand-pass reason) }
local OVERRIDE = {
	F01_SteleGrove = { flag = "Steles and bamboo: check the steles stand upright on the ground and the bamboo clears them." },
	F02_EarthGodShrine = { flag = "Little roofed shrine: check the roof sits on its posts and the base on the ground." },
	F03_MeditationRock = { yaw = facing(-12 - 25, 1395 - 900) },
	F04_TeaStall = { flag = "Ruined stall: check posts reach the ground and the roof remnant rests on them." },
	F06_LanternStairFoot = { yaw = math.atan2(-62 - -15, 1325 - 1280), keep = true, flag = "Lantern stair foot below the Shrine Terrace: check the steps meet the ground and lead toward the shrine stair." },
	F07_FerrymanHut = { flag = "Hut: check walls meet at the corners, roof on the walls, door facing the GorgeRoad." },
	F08_RiverJetty = { x = 250, z = 1562, yaw = 0, ground = "centre", keep = true, flag = "Jetty on the border river: check the root meets the bank and the piles reach the river bed." },
	F12_SnareLine = { keep = true },
	F15_DryCreekBridge = { yaw = rad(90), keep = true, flag = "Small bridge on the SouthWest path: check both ends meet the ground and the path runs over it." },
	F17_VistaNotch = { yaw = rad(180), ground = "centre", flag = "Ledge on the GateRidge crest: check it sits in the crest, reachable by the ridge trail, nothing floats." },
	F18_BoarWallow = { carve = true },
	F19_CollapsedWatchPost = { flag = "Collapsed watch post: check the fallen deck rests on the ground and posts don't float." },
	F14_WoodcutterClearing = { x = -330, z = 1346, keep = true },
	F21_FoxHoleCave = { x = 838, z = 992, yaw = facing(-1, 0), keep = true, flag = "Cave mouth at the East wall's foot: check it sits against the rock, not free-standing." },
	F22_CharcoalKiln = { flag = "Kiln: check it sits on the ground and the chimney is upright." },
	F24_LonePineMat = { flag = "Pine on a rock with a mat: check the trunk grows out of the rock and the mat lies on it." },
	F27_BeastSkeleton = { keep = true },
	F31_GullyArmour = { ground = "centre" },
}

local old = ground:FindFirstChild("Finds")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Finds"
root.Parent = ground

local pocketBoxes = {}
for _, p in (ground:FindFirstChild("Pockets") or Instance.new("Folder")):GetChildren() do
	local cf, size = p:GetBoundingBox()
	table.insert(pocketBoxes, { cf, size })
end
local function inPocket(pos, r)
	for _, b in pocketBoxes do
		local lp = b[1]:PointToObjectSpace(pos)
		if math.abs(lp.X) < b[2].X / 2 + r and math.abs(lp.Z) < b[2].Z / 2 + r then
			return b
		end
	end
	return nil
end

local report = {}
for _, src in PREFABS:GetChildren() do
	if not src.Name:match("^F%d%d_") then
		continue
	end
	local o = OVERRIDE[src.Name] or {}
	local spot = src:GetAttribute("PlannedSpot")
	local x, z = o.x or (spot and spot.X) or 0, o.z or (spot and spot.Z) or 0
	local _, size = src:GetBoundingBox()
	local r = math.max(size.X, size.Z) / 2
	-- out of any pocket prefab
	for _ = 1, 8 do
		local b = inPocket(Vector3.new(x, 0, z), r * 0.6)
		if not b then
			break
		end
		local away = Vector3.new(x - b[1].X, 0, z - b[1].Z)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		x += away.X * 8
		z += away.Z * 8
	end
	-- off the path (unless it belongs on it)
	local d, p, hw = nearestPath(x, z)
	if not o.keep and d < r * 0.7 + hw + 1 then
		local away = Vector3.new(x - p.X, 0, z - p.Z)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
		local push = (r * 0.7 + hw + 1) - d
		x += away.X * push
		z += away.Z * push
		d, p, hw = nearestPath(x, z)
	end
	local yaw = o.yaw or facing(p.X - x, p.Z - z)
	local m = src:Clone()
	m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * src:GetPivot().Rotation)
	local y
	if o.ground == "centre" then
		y = gy(x, z)
	else
		local cf, s = m:GetBoundingBox()
		y = math.huge
		for _, q in { { 0, 0 }, { 0.4, 0.4 }, { -0.4, 0.4 }, { 0.4, -0.4 }, { -0.4, -0.4 } } do
			local w = cf * Vector3.new(s.X * q[1], 0, s.Z * q[2])
			y = math.min(y, gy(w.X, w.Z))
		end
	end
	m:PivotTo(m:GetPivot() + Vector3.new(0, y, 0))
	if src.Name == "F12_SnareLine" then
		for _, c in m:GetChildren() do
			if c:IsA("Model") or c:IsA("BasePart") then
				local cf, s
				if c:IsA("Model") then
					cf, s = c:GetBoundingBox()
				else
					cf, s = c.CFrame, c.Size
				end
				local g = gy(cf.X, cf.Z)
				local delta = Vector3.new(0, g - (cf.Y - s.Y / 2), 0)
				if c:IsA("Model") then
					c:PivotTo(c:GetPivot() + delta)
				else
					c.CFrame += delta
				end
			end
		end
	end
	m.Parent = root
	if o.carve then
		for _, c in m:GetDescendants() do
			if c:IsA("BasePart") and c.Name == "TerrainCarve" then
				local rr = math.max(c.Size.Y, c.Size.Z) / 2
				workspace.Terrain:FillCylinder(CFrame.new(c.Position.X, c.Position.Y - c.Size.X / 2 + 10, c.Position.Z), 20, rr, Enum.Material.Air)
			end
		end
	end
	CollectionService:AddTag(m, "POI")
	if not m:GetAttribute("Kind") then
		m:SetAttribute("Kind", "Find")
	end
	if not m:GetAttribute("Zone") then
		m:SetAttribute("Zone", "Inner")
	end
	if o.flag then
		CollectionService:AddTag(m, "NeedsHandPass")
		m:SetAttribute("HandPassReason", o.flag)
		m:SetAttribute("HandPassStatus", "open")
	end
	table.insert(report, string.format("%s (%.0f, %.1f, %.0f) yaw %.0f, path %.0f away", src.Name, x, y, z, math.deg(yaw), d))
	task.wait()
end
table.sort(report)
return table.concat(report, "\n")
