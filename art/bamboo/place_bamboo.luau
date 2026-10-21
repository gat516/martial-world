--[[
Builds the bamboo templates ServerStorage._Templates.BambooCluster_4..16 from the kit made by
art/bamboo/build_bamboo.py, and optionally a preview row. Run in Studio (Edit mode) from the command bar or
the MCP, after File > Import 3D of art/bamboo/Bamboo.fbx (defaults, meshes not merged). Re-runnable: once
the templates exist the import isn't needed again for the preview stage.

Stages (set _G.BAMBOO_STAGES to run one on its own, e.g. { preview = true }):
  kit      find the imported Bamboo* MeshParts (each exactly once, or it errors), style them (SmoothPlastic,
           plain colour from the JSON, anchored, no collision/query/touch, Box fidelity), group each kind's
           parts into a Model template, replace any old template of that name, delete the import containers.
  preview  rebuild Workspace._BambooPreview: a ground slab with every template in a row (the old
           BambooCluster_1..3 first, for scale), and a small grove (stand tiles in a 4 x 3 grid, edge strips
           along its front, two giants) behind it. Delete the folder when done looking (_G.BAMBOO_STAGES =
           { clear = true } does that).
Everything is one ChangeHistory recording per run, so Ctrl+Z undoes it.

Templates (BambooKind attribute on each Model; all are non-colliding foliage like BambooCluster_1..3):
  4  Grove    tall dense clump, 9 culms 40-57 tall              Clump
  5  Sparse   4 culms 30-46 with room between                   Clump / Edge
  6  Single   one thick culm 55 tall with a nodding top         Accent
  7  Arching  6 wind-bent culms arching to one side (+X)        Clump
  8  Young    short clump 13-22 tall with 5 shoot cones         Edge
  9  Stumps   cut stumps with pale slanted cut faces, 2 regrowing culms and sprigs   Edge
  10 Dry      dry gold clump 30-45 tall, thinner crowns         Accent
  11 Thicket  wide low oval row of 8 culms 24-38 tall           Edge
  12-14 StandA/B/C  dense 16 x 16 stand tiles, 12-13 culms 42-68 tall, culms on a jittered grid over the
           whole square so tiles butt edge to edge into a continuous grove (rotate by 90 deg steps)   Stand
  15 Giant    three very tall thick culms 78-96, for the hero grove                  Giant
  16 Edge     16 x 8 grove border strip: stand height on the back (+Z) stepping down to young culms and
           shoots on the front (the pivot's LookVector, -Z); put the back against the stand tiles   Edge
Pivot: PrimaryPart nil, WorldPivot at the base centre on the ground with identity rotation, so
PivotTo(CFrame.new(spot) * template:GetPivot().Rotation) stands them up. Culms reach 1 stud below it.

Import maps Blender (x, y, z) to mesh-local (x, z, -y) about the kit origin: Size = (bx, bz, by), part
offset = CFrame.Angles(0, pi, 0) * CFrame.new(-cx, cz, cy).
]]

local STAGES = _G.BAMBOO_STAGES or { kit = true, preview = true }
_G.BAMBOO_STAGES = nil -- flags apply to one run only

-- BEGIN MESHES (generated from Bamboo.json: size and centre in Blender axes, Studio colour)
local MESHES = {
	BambooGrove_Culm = { size = { 14.81, 16.614, 59.543 }, center = { 3.029, -0.406, 28.472 }, color = "7A9A50", tris = 2322 },
	BambooGrove_CulmAlt = { size = { 4.144, 3.391, 49.061 }, center = { -3.078, -2.131, 23.232 }, color = "627E44", tris = 276 },
	BambooGrove_Leaf = { size = { 27.154, 25.464, 36.657 }, center = { 2.346, 0.852, 39.608 }, color = "5E7F45", tris = 628 },
	BambooGrove_LeafLight = { size = { 25.398, 25.713, 33.47 }, center = { 3.087, -0.863, 36.699 }, color = "86A65B", tris = 456 },
	BambooSparse_Culm = { size = { 14.406, 15.17, 44.052 }, center = { 2.562, -0.96, 20.726 }, color = "7A9A50", tris = 924 },
	BambooSparse_Leaf = { size = { 17.537, 22.673, 9.907 }, center = { 6.029, 0.522, 25.221 }, color = "5E7F45", tris = 116 },
	BambooSparse_LeafLight = { size = { 23.675, 22.619, 22.873 }, center = { 1.665, -2.238, 31.138 }, color = "86A65B", tris = 188 },
	BambooSingle_Culm = { size = { 5.767, 3.504, 57.679 }, center = { 1.967, 0.838, 27.54 }, color = "7A9A50", tris = 306 },
	BambooSingle_Leaf = { size = { 14.75, 15.177, 26.04 }, center = { 2.976, 0.352, 38.937 }, color = "5E7F45", tris = 88 },
	BambooSingle_LeafLight = { size = { 17.721, 13.985, 21.086 }, center = { 1.806, 1.489, 45.217 }, color = "86A65B", tris = 84 },
	BambooArching_Culm = { size = { 30.85, 10.568, 45.608 }, center = { 11.659, 2.268, 21.505 }, color = "7A9A50", tris = 1758 },
	BambooArching_Leaf = { size = { 28.946, 21.358, 23.347 }, center = { 11.957, 2.017, 30.809 }, color = "5E7F45", tris = 400 },
	BambooArching_LeafLight = { size = { 33.23, 18.38, 24.984 }, center = { 12.099, 1.348, 32.22 }, color = "86A65B", tris = 528 },
	BambooYoung_Culm = { size = { 8.581, 13.593, 23.311 }, center = { 1.31, -0.327, 10.356 }, color = "86A65A", tris = 630 },
	BambooYoung_CulmAlt = { size = { 8.115, 8.978, 22.012 }, center = { -1.725, 1.429, 9.708 }, color = "9BB866", tris = 414 },
	BambooYoung_Leaf = { size = { 16.615, 20.502, 11.891 }, center = { 0.123, -0.25, 10.236 }, color = "5E7F45", tris = 160 },
	BambooYoung_LeafLight = { size = { 19.173, 22.282, 17.156 }, center = { -0.455, -0.724, 13.035 }, color = "92B262", tris = 300 },
	BambooYoung_Shoot = { size = { 10.441, 9.368, 7.049 }, center = { -0.217, -0.527, 2.325 }, color = "8C8452", tris = 120 },
	BambooStumps_Culm = { size = { 9.808, 6.973, 16.679 }, center = { 0.758, -1.069, 7.04 }, color = "7A9A50", tris = 330 },
	BambooStumps_CulmAlt = { size = { 9.49, 7.408, 16.939 }, center = { -0.737, 1.062, 7.169 }, color = "627E44", tris = 300 },
	BambooStumps_Leaf = { size = { 15.052, 11.628, 13.191 }, center = { -0.489, 2.018, 8.472 }, color = "5E7F45", tris = 100 },
	BambooStumps_LeafLight = { size = { 6.653, 8.557, 11.176 }, center = { -2.349, 0.475, 9.608 }, color = "86A65B", tris = 36 },
	BambooStumps_Cut = { size = { 10.845, 8.78, 5.328 }, center = { 0.101, 0.252, 3.442 }, color = "D6CB98", tris = 168 },
	BambooDry_Culm = { size = { 3.094, 13.707, 42.012 }, center = { 0.978, 0.708, 19.707 }, color = "C3A152", tris = 516 },
	BambooDry_CulmAlt = { size = { 16.205, 9.045, 44.393 }, center = { 2.686, 1.289, 20.897 }, color = "A6853D", tris = 660 },
	BambooDry_Leaf = { size = { 22.433, 21.083, 25.097 }, center = { 1.217, 2.23, 27.89 }, color = "AE9549", tris = 184 },
	BambooDry_LeafLight = { size = { 19.132, 18.956, 27.898 }, center = { 5.232, 0.385, 28.637 }, color = "CDB46A", tris = 80 },
	BambooThicket_Culm = { size = { 20.489, 11.159, 39.523 }, center = { -0.484, -0.324, 18.462 }, color = "7A9A50", tris = 1098 },
	BambooThicket_CulmAlt = { size = { 17.673, 8.19, 36.404 }, center = { 6.207, 0.138, 16.902 }, color = "627E44", tris = 642 },
	BambooThicket_Leaf = { size = { 37.462, 23.189, 28.907 }, center = { 2.303, -0.661, 23.187 }, color = "5E7F45", tris = 496 },
	BambooThicket_LeafLight = { size = { 29.405, 19.298, 26.008 }, center = { -0.951, -0.71, 21.208 }, color = "86A65B", tris = 296 },
	BambooStandA_Culm = { size = { 16.701, 14.687, 66.628 }, center = { 1.286, 0.058, 32.014 }, color = "7A9A50", tris = 1860 },
	BambooStandA_CulmAlt = { size = { 17.559, 15.25, 64.506 }, center = { 2.188, 0.877, 30.953 }, color = "627E44", tris = 858 },
	BambooStandA_Leaf = { size = { 29.243, 25.317, 35.217 }, center = { 2.876, 0.696, 45.514 }, color = "5E7F45", tris = 572 },
	BambooStandA_LeafLight = { size = { 27.356, 21.928, 33.666 }, center = { 0.509, 1.315, 47.854 }, color = "86A65B", tris = 312 },
	BambooStandB_Culm = { size = { 17.626, 15.819, 57.187 }, center = { 0.919, -0.606, 27.294 }, color = "7A9A50", tris = 1430 },
	BambooStandB_CulmAlt = { size = { 16.893, 14.338, 58.299 }, center = { -1.803, 1.863, 27.85 }, color = "627E44", tris = 1050 },
	BambooStandB_Leaf = { size = { 26.019, 26.907, 28.764 }, center = { -1.85, 0.297, 41.98 }, color = "5E7F45", tris = 436 },
	BambooStandB_LeafLight = { size = { 28.495, 21.529, 27.897 }, center = { -0.487, 1.52, 41.87 }, color = "86A65B", tris = 328 },
	BambooStandC_Culm = { size = { 17.639, 16.147, 63.319 }, center = { -0.952, 0.19, 30.36 }, color = "7A9A50", tris = 1846 },
	BambooStandC_CulmAlt = { size = { 12.98, 10.664, 69.85 }, center = { 1.314, 1.73, 33.625 }, color = "627E44", tris = 686 },
	BambooStandC_Leaf = { size = { 29.491, 26.245, 36.396 }, center = { -2.438, -0.323, 50.057 }, color = "5E7F45", tris = 388 },
	BambooStandC_LeafLight = { size = { 29.077, 27.62, 31.216 }, center = { -0.451, 0.192, 45.86 }, color = "86A65B", tris = 372 },
	BambooGiant_Culm = { size = { 10.165, 13.553, 94.025 }, center = { 4.934, 0.368, 45.713 }, color = "7A9A50", tris = 726 },
	BambooGiant_CulmAlt = { size = { 5.769, 7.51, 91.862 }, center = { -1.657, 1.58, 44.631 }, color = "627E44", tris = 378 },
	BambooGiant_Leaf = { size = { 29.938, 24.79, 43.486 }, center = { 2.941, -0.762, 68.659 }, color = "5E7F45", tris = 264 },
	BambooGiant_LeafLight = { size = { 27.004, 26.616, 38.381 }, center = { 3.713, -0.657, 73.64 }, color = "86A65B", tris = 220 },
	BambooEdge_Culm = { size = { 14.631, 8.507, 43.668 }, center = { 1.285, 0.446, 20.534 }, color = "7A9A50", tris = 920 },
	BambooEdge_CulmAlt = { size = { 13.3, 4.81, 49.753 }, center = { -2.274, -1.78, 23.577 }, color = "627E44", tris = 432 },
	BambooEdge_Leaf = { size = { 26.052, 17.657, 24.64 }, center = { -0.81, 0.416, 23.143 }, color = "5E7F45", tris = 300 },
	BambooEdge_LeafLight = { size = { 27.031, 18.616, 38.607 }, center = { -0.129, 0.053, 29.258 }, color = "86A65B", tris = 368 },
	BambooEdge_Shoot = { size = { 13.862, 4.839, 5.472 }, center = { 2.764, 5.461, 1.539 }, color = "8C8452", tris = 60 },
}
-- END MESHES

-- kind -> template number and grove role (BambooKind attribute)
local KINDS = {
	BambooGrove = { 4, "Clump" },
	BambooSparse = { 5, "Clump" },
	BambooSingle = { 6, "Accent" },
	BambooArching = { 7, "Clump" },
	BambooYoung = { 8, "Edge" },
	BambooStumps = { 9, "Edge" },
	BambooDry = { 10, "Accent" },
	BambooThicket = { 11, "Edge" },
	BambooStandA = { 12, "Stand" },
	BambooStandB = { 13, "Stand" },
	BambooStandC = { 14, "Stand" },
	BambooGiant = { 15, "Giant" },
	BambooEdge = { 16, "Edge" },
}
local STAND_TILE = 16 -- stand tiles cover 16 x 16 studs; the edge strip 16 x 8
local PREVIEW_AT = Vector3.new(3000, 200, 3000) -- out of the way, over open cloud sea

local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local TEMPLATES = SS:FindFirstChild("_Templates")
assert(TEMPLATES, "ServerStorage._Templates missing")

local function kitStage()
	-- find each imported mesh exactly once
	local found, containers = {}, {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and MESHES[d.Name] and not d:FindFirstAncestor("_BambooPreview") then
			if found[d.Name] then
				error("place_bamboo: " .. d.Name .. " imported twice (" .. found[d.Name]:GetFullName() .. ", " .. d:GetFullName() .. "); delete the extra import")
			end
			found[d.Name] = d
			local top = d
			while top.Parent ~= workspace do
				top = top.Parent
			end
			if top ~= d then
				containers[top] = true
			end
		end
	end
	local missing = {}
	for name in MESHES do
		if not found[name] then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		error("place_bamboo: missing imported meshes (import art/bamboo/Bamboo.fbx, meshes not merged): " .. table.concat(missing, ", "))
	end

	for kind, info in KINDS do
		local name = "BambooCluster_" .. info[1]
		local old = TEMPLATES:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("BambooKind", info[2])
		m:SetAttribute("Source", kind)
		local pivot = CFrame.new()
		for mesh, spec in MESHES do
			if mesh:sub(1, #kind + 1) == kind .. "_" then
				local p = found[mesh]
				local s, c = spec.size, spec.center
				p.Size = Vector3.new(s[1], s[3], s[2])
				p.CFrame = pivot * CFrame.Angles(0, math.pi, 0) * CFrame.new(-c[1], c[3], c[2])
				p.Material = Enum.Material.SmoothPlastic
				p.Color = Color3.fromHex(spec.color)
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CollisionFidelity = Enum.CollisionFidelity.Box
				local role = mesh:sub(#kind + 2)
				p.CastShadow = role ~= "Shoot" and role ~= "Cut"
				p.Name = role
				p.Parent = m
			end
		end
		assert(#m:GetChildren() > 0, "no parts for " .. kind)
		m.PrimaryPart = nil
		m.WorldPivot = pivot
		m.Parent = TEMPLATES
	end
	for c in containers do
		if c.Parent then
			c:Destroy()
		end
	end
end

local function clearPreview()
	local old = workspace:FindFirstChild("_BambooPreview")
	if old then
		old:Destroy()
	end
end

local function previewStage()
	clearPreview()
	local f = Instance.new("Folder")
	f.Name = "_BambooPreview"
	local base = PREVIEW_AT
	local floor = Instance.new("Part")
	floor.Name = "Ground"
	floor.Anchored = true
	floor.Size = Vector3.new(560, 2, 170)
	floor.CFrame = CFrame.new(base + Vector3.new(250, -1, 50))
	floor.Color = Color3.fromHex("6E8F5A")
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = f
	local function put(name, pos, yaw)
		local t = TEMPLATES:FindFirstChild(name)
		if not t then
			warn("place_bamboo preview: missing " .. name)
			return
		end
		local c = t:Clone()
		if c:IsA("Model") then
			c:PivotTo(CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0) * t:GetPivot().Rotation)
		else -- the old unions lie on X; stand them on the ground
			c.CFrame = CFrame.new(pos + Vector3.new(0, c.Size.X / 2, 0)) * c.CFrame.Rotation
		end
		c.Parent = f
	end
	-- row: old 1..3 then 4..16, front of the slab
	for i = 1, 16 do
		put("BambooCluster_" .. i, base + Vector3.new((i - 1) * 32, 0, 0))
	end
	-- grove: 4 x 3 stand tiles, random stand kind and 90 deg turn each, edge strips along the front, giants
	local rng = Random.new(7)
	local g0 = base + Vector3.new(160, 0, 70)
	for i = 0, 3 do
		for j = 0, 2 do
			local pick = "BambooCluster_" .. rng:NextInteger(12, 14)
			put(pick, g0 + Vector3.new((i + 0.5) * STAND_TILE, 0, (j + 0.5) * STAND_TILE), rng:NextInteger(0, 3) * math.pi / 2)
		end
		-- edge strip: back (+Z in template) against the stands, front facing the row (-Z)
		put("BambooCluster_16", g0 + Vector3.new((i + 0.5) * STAND_TILE, 0, -STAND_TILE / 4), 0)
	end
	put("BambooCluster_15", g0 + Vector3.new(STAND_TILE * 1.5, 0, STAND_TILE * 1.6))
	put("BambooCluster_15", g0 + Vector3.new(STAND_TILE * 3.1, 0, STAND_TILE * 1.1), 2)
	put("BambooCluster_8", g0 + Vector3.new(-8, 0, 4))
	put("BambooCluster_5", g0 + Vector3.new(4 * STAND_TILE + 9, 0, 10))
	f.Parent = workspace
end

local rec = CHS:TryBeginRecording("place_bamboo")
local ok, err = pcall(function()
	if STAGES.kit then
		kitStage()
	end
	if STAGES.clear then
		clearPreview()
	end
	if STAGES.preview then
		previewStage()
	end
end)
if rec then
	CHS:FinishRecording(rec, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
print("place_bamboo done")
