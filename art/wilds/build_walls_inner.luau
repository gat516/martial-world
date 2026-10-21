--!nocheck
-- Inner Wilds valley walls from giant library cliff rocks (docs/systems/map.md, "Inner Wilds
-- rework", "Walls"). Run in Studio Edit mode through execute_luau. It builds one Folder per
-- wall segment under Workspace.Map.Ground.WildsInner.Walls and skips any segment folder that
-- already exists, so pieces the user moved or scaled by hand are never overwritten (delete a
-- segment's folder to rebuild it). Seeded: a rebuilt segment comes out the same.
--
-- Method: "Stylized Cliff Terrain Rock" (Stylized Cliff Rock Pack II) clones, pivoted at their
-- bounding box's bottom centre, scaled with ScaleTo, sunk 10-20% of their height into the
-- lowest ground under them, Hull collision, nothing welded. Giants (85-125 tall) every ~62
-- studs along the crest line, medium rocks on the valley side over each seam, small ones at
-- the foot, a lower stepped row behind for the back seen from above, a few pines on giant
-- tops, mist anchors on the back. Then rays from the valley side at heights 4, 15 and 30 every
-- 10 studs; every miss gets a filler rock and is checked again.

local SS = game:GetService("ServerStorage")
local L = SS.AssetLibrary
local P2 = L["Stylized Rock Packs"]["Stylized Cliff Rock Pack II"]:GetChildren()
local function bySize(y)
	for _, m in P2 do
		local _, s = m:GetBoundingBox()
		if math.abs(s.Y - y) < 1.5 then
			return m
		end
	end
	error("no Cliff Terrain Rock " .. y)
end
local SRC = { CTR66 = bySize(66), CTR50 = bySize(50), CTR27 = bySize(27), CTR23 = bySize(23) }
local MD = L["Map Detailing"]
local PINES = {}
for _, c in MD:GetChildren() do
	if c:IsA("Model") and (c.Name == "Pine Tree 2" or c.Name == "Pine Tree 3") then
		table.insert(PINES, c)
	end
end
local MIST = SS:FindFirstChild("AmbientFX") and SS.AmbientFX:FindFirstChild("MistWisps")

local VALLEY_CENTRE = Vector3.new(0, 0, 1000)
-- crest polylines {x, z}; openings are simply where no segment runs (the sect gate front
-- x -110..150 on the north, the gorge gate x 175..262 on the south) and the karst groups
-- the segments end against (SouthWestField, EastSentinels, SouthEastFar, SouthHorizon).
local SEGMENTS = {
	-- the north walls sit at z ~500 until the rework moves the old Inner layout (the Wolf Den
	-- ring, the Bamboo Hollow, the camp cache) south: everything scripts read stays 40+ off
	{ name = "NorthWest", pts = { { -790, 556 }, { -620, 522 }, { -400, 505 }, { -112, 502 } } },
	{ name = "NorthEast", pts = { { 152, 500 }, { 270, 494 }, { 386, 500 } } },
	{ name = "NorthEast2", pts = { { 545, 600 }, { 700, 590 }, { 840, 640 } } },
	{ name = "East", pts = { { 840, 640 }, { 900, 800 }, { 905, 1000 }, { 880, 1180 }, { 800, 1262 } } },
	{ name = "SouthEast", pts = { { 618, 1425 }, { 420, 1450 }, { 262, 1452 } } },
	{ name = "SouthWest", pts = { { -212, 1448 }, { -280, 1452 }, { -500, 1440 }, { -760, 1400 } } },
	{ name = "West", pts = { { -760, 1400 }, { -860, 1250 }, { -900, 1000 }, { -872, 742 } } },
}

local terr = RaycastParams.new()
terr.FilterType = Enum.RaycastFilterType.Include
terr.FilterDescendantsInstances = { workspace.Terrain }
local function groundMin(cx, cz, hx, hz)
	local m = math.huge
	for _, o in { { 0, 0 }, { hx, 0 }, { -hx, 0 }, { 0, hz }, { 0, -hz }, { hx * 0.7, hz * 0.7 }, { -hx * 0.7, -hz * 0.7 }, { hx * 0.7, -hz * 0.7 }, { -hx * 0.7, hz * 0.7 } } do
		local h = workspace:Raycast(Vector3.new(cx + o[1], 300, cz + o[2]), Vector3.new(0, -400, 0), terr)
		if h then
			m = math.min(m, h.Position.Y)
		end
	end
	return if m == math.huge then 2 else m
end

local function rock(folder, name, key, height, x, z, yaw, sink)
	local m = SRC[key]:Clone()
	local box, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * m:GetPivot().Rotation
	m:ScaleTo(m:GetScale() * (height / size.Y))
	m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * m:GetPivot().Rotation)
	local b2, s2 = m:GetBoundingBox()
	local g = groundMin(b2.X, b2.Z, s2.X * 0.4, s2.Z * 0.4)
	m:PivotTo(m:GetPivot() + Vector3.new(0, (g - s2.Y * sink) - (b2.Y - s2.Y / 2), 0))
	m.Name = name
	m:SetAttribute("WallPiece", key)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = true
			p.CanQuery = true
			p.CanTouch = false
			p.CastShadow = height > 20
			if p:IsA("MeshPart") then
				pcall(function()
					p.CollisionFidelity = Enum.CollisionFidelity.Hull
				end)
			end
		end
	end
	m.Parent = folder
	return m
end

local function build(seg, walls)
	local folder = Instance.new("Folder")
	folder.Name = seg.name
	local rng = Random.new(#seg.name * 7919 + seg.pts[1][1])
	local n = 0
	local function nm(role)
		n += 1
		return string.format("Wall_%s%02d_%s", seg.name, n, role)
	end
	-- resample the polyline every ~62 studs
	local spots = {}
	for i = 1, #seg.pts - 1 do
		local a = Vector3.new(seg.pts[i][1], 0, seg.pts[i][2])
		local b = Vector3.new(seg.pts[i + 1][1], 0, seg.pts[i + 1][2])
		local steps = math.max(1, math.floor((b - a).Magnitude / 62 + 0.5))
		for k = (i == 1 and 0 or 1), steps do
			local p = a:Lerp(b, k / steps)
			local dir = (b - a).Unit
			local inward = Vector3.new(-dir.Z, 0, dir.X)
			if inward:Dot(VALLEY_CENTRE - p) < 0 then
				inward = -inward
			end
			table.insert(spots, { p = p, dir = dir, inward = inward })
		end
	end
	folder.Parent = walls
	for i, s in spots do
		local p = s.p + s.inward * rng:NextNumber(-6, 6)
		local key = (i % 3 == 0) and "CTR50" or "CTR66"
		rock(folder, nm("Giant"), key, rng:NextNumber(88, 124), p.X, p.Z, rng:NextNumber(0, math.pi * 2), 0.12)
		-- back row, lower, stepping down outward (what a flyer sees behind the rim)
		local back = s.p - s.inward * rng:NextNumber(48, 58)
		rock(folder, nm("Back"), (i % 2 == 0) and "CTR27" or "CTR50", rng:NextNumber(40, 60), back.X, back.Z, rng:NextNumber(0, math.pi * 2), 0.15)
		-- seam cover on the valley side, between this giant and the next
		if spots[i + 1] then
			local seam = s.p:Lerp(spots[i + 1].p, 0.5) + s.inward * rng:NextNumber(30, 40)
			rock(folder, nm("Seam"), (i % 2 == 0) and "CTR23" or "CTR27", rng:NextNumber(24, 38), seam.X, seam.Z, rng:NextNumber(0, math.pi * 2), 0.15)
		end
		-- small foot rocks in odd clusters, not at every giant
		if i % 2 == 1 then
			for k = 1, (i % 4 == 1) and 3 or 1 do
				local f = s.p + s.inward * rng:NextNumber(44, 58) + s.dir * rng:NextNumber(-22, 22)
				rock(folder, nm("Small"), "CTR23", rng:NextNumber(6, 12), f.X, f.Z, rng:NextNumber(0, math.pi * 2), 0.2)
			end
		end
	end
	-- pines on a few giant tops (rim dressing seen from above and from the valley)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { folder }
	if #PINES > 0 then
		for i, s in spots do
			if i % 3 == 2 then
				local at = s.p + s.dir * rng:NextNumber(-10, 10)
				local hit = workspace:Raycast(Vector3.new(at.X, 400, at.Z), Vector3.new(0, -500, 0), rp)
				if hit and hit.Normal.Y > 0.75 then
					local pine = PINES[rng:NextInteger(1, #PINES)]:Clone()
					for _, d in pine:GetDescendants() do
						if d:IsA("LuaSourceContainer") then
							d:Destroy()
						elseif d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
							d.CanQuery = false
							d.CanTouch = false
						end
					end
					local box, size = pine:GetBoundingBox()
					pine.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * pine:GetPivot().Rotation
					pine:ScaleTo(pine:GetScale() * rng:NextNumber(0.8, 1.2))
					pine:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * pine:GetPivot().Rotation)
					n += 1
					pine.Name = string.format("Wall_%s%02d_RimPine", seg.name, n)
					pine.Parent = folder
				end
			end
		end
	end
	-- mist on the back, every fourth spot (vfx MistWisps template; front face points outward)
	if MIST then
		for i, s in spots do
			if i % 4 == 0 then
				local back = s.p - s.inward * 75
				local m = MIST:Clone()
				m.Name = string.format("Wall_%s_FX_RimMist%02d", seg.name, i)
				m.Size = Vector3.new(70, 10, 30)
				m.CFrame = CFrame.lookAt(Vector3.new(back.X, 24, back.Z), Vector3.new(back.X, 24, back.Z) - s.inward)
				m.Parent = folder
			end
		end
	end
	-- contact check from the valley side; fill every gap and check again
	local fills = 0
	for pass = 1, 3 do
		local misses = {}
		for _, s in spots do
			for off = -31, 31, 10 do
				for _, h in { 4, 15, 30 } do
					local start = s.p + s.inward * 120 + s.dir * off
					local hit = workspace:Raycast(Vector3.new(start.X, h, start.Z), -s.inward * 200, rp)
					if not hit then
						table.insert(misses, s.p + s.dir * off)
						break
					end
				end
			end
		end
		if #misses == 0 then
			break
		end
		for _, at in misses do
			fills += 1
			rock(folder, nm("Fill"), "CTR23", rng:NextNumber(34, 46), at.X, at.Z, rng:NextNumber(0, 6.28), 0.15)
		end
		if pass == 3 then
			warn(seg.name .. ": " .. #misses .. " ray gaps left after 3 fill passes")
		end
	end
	return n, fills
end

local walls = workspace.Map.Ground.WildsInner:FindFirstChild("Walls")
if not walls then
	walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = workspace.Map.Ground.WildsInner
end
local report = {}
for _, seg in SEGMENTS do
	if walls:FindFirstChild(seg.name) then
		table.insert(report, seg.name .. ": exists, skipped")
	else
		local n, fills = build(seg, walls)
		table.insert(report, string.format("%s: %d pieces, %d fills", seg.name, n, fills))
	end
	task.wait()
end
return table.concat(report, "\n")
