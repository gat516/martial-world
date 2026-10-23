--!nocheck
-- One-time POI pass over the Inner Wilds pockets and finds (2026-10-21; docs/map/inner-wilds-rework.md,
-- "POI pass"). Run in Studio Edit mode through execute_luau after water_inner.luau, then run
-- group_poi_parts.luau (groups and seats every object) and ambience_inner.luau.
-- Clears what blocked the POIs (the clearance report in phase 3), fixes the prompt and cache spots
-- that couldn't be reached, and reports what it did. Removed pieces go to
-- ServerStorage._InnerWildsReplaced with FromPath. Every step looks things up by name and position,
-- so it is safe to re-run (a step whose target is already gone or moved just reports nothing).

local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local WI = workspace.Map.Ground.WildsInner
local rep = SS._InnerWildsReplaced
local report = {}

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end
local function stash(inst, why)
	if inst and inst.Parent and inst.Parent ~= rep then
		inst:SetAttribute("FromPath", inst:GetFullName())
		inst.Parent = rep
		table.insert(report, "removed " .. inst.Name .. ": " .. why)
	end
end
local function wall(name)
	for _, d in WI.Walls:GetDescendants() do
		if d.Name == name and d:IsA("Model") then
			return d
		end
	end
end
local function moveModel(m, delta)
	m:PivotTo(m:GetPivot() + delta)
end
local function deep(root, name)
	return root and root:FindFirstChild(name, true)
end

-- 1. wall seams and small rocks standing in POIs or in front of their trickles
for _, n in { "Wall_NorthWest32_Seam", "Wall_NorthWest35_Seam", "Wall_NorthWest36_Small", "Wall_NorthWest38_Small" } do
	stash(wall(n), "stood inside the Bamboo Hollow and hid its trickle")
end
for _, n in { "Wall_East25_Seam", "Wall_East28_Seam" } do
	stash(wall(n), "stood inside the Fox Hole and in front of the East trickle")
end
stash(wall("Wall_West44_Seam"), "hid the den trickle")

-- 2. path blockers: the giant at the gorge gate's east approach, the corner foot on the GorgeRoad
do
	local g = wall("Wall_SouthEast26_Giant")
	if g and g:GetPivot().Position.Z < 1455 then
		moveModel(g, Vector3.new(8, 0, 14))
		table.insert(report, "moved Wall_SouthEast26_Giant 16 studs out, off the SouthEast path's end")
	end
	local f = wall("Wall_S11_CornerFoot")
	if f and f:GetPivot().Position.Z < 1325 then
		f:ScaleTo(f:GetScale() * 0.75)
		moveModel(f, Vector3.new(6, 0, 12))
		table.insert(report, "shrank Wall_S11_CornerFoot and moved it off the GorgeRoad")
	end
end

-- 3. an old dead tree from the ring dressing inside the Wolf Den
for _, ring in { "InnerRing", "MiddleRing", "OuterRing" } do
	for _, grp in workspace.Map.Ground[ring]:GetChildren() do
		for _, c in grp:GetChildren() do
			local p = c:IsA("Model") and c:GetPivot().Position or (c:IsA("BasePart") and c.Position)
			if p and (Vector2.new(p.X, p.Z) - Vector2.new(-720, 790)).Magnitude < 50 and p.Y < 150 then
				stash(c, "old ring dressing standing in the Wolf Den")
			end
		end
	end
end

-- 4. Twin-Jade: bamboo away from the fall foot and the pool, the prompt on the open side
do
	local tj = WI.Pockets:FindFirstChild("TwinJadeSpring")
	local pool = deep(tj, "SpringPool")
	if tj and pool then
		local c = pool:GetBoundingBox().Position
		local lip = wall("Wall_TJ03_NotchLip")
		local inward = lip and (Vector3.new(565, 0, 1190) - Vector3.new(lip:GetPivot().X, 0, lip:GetPivot().Z)).Unit or Vector3.new(-0.7, 0, -0.71)
		for _, d in tj:GetDescendants() do
			if d:IsA("Model") and d.Name == "Bamboo" then
				local p = d:GetBoundingBox().Position
				local off = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
				if off.Magnitude < 20 then
					local dir = if off.Magnitude > 0.1 then off.Unit else -inward
					-- out to the side away from the fall line, 20+ studs from the pool centre
					local side = Vector3.new(-inward.Z, 0, inward.X)
					if dir:Dot(side) < 0 then
						side = -side
					end
					local target = Vector3.new(c.X, 0, c.Z) + side * 22 + inward * 4
					local g = gy(target.X, target.Z)
					local cf, size = d:GetBoundingBox()
					d:PivotTo(d:GetPivot() + Vector3.new(target.X - cf.X, (g - 0.4) - (cf.Y - size.Y / 2), target.Z - cf.Z))
					table.insert(report, "moved a Twin-Jade bamboo clump off the pool rim and the fall's foot")
				end
			end
		end
		local prompt = deep(tj, "PromptSpotAnchor")
		if prompt then
			local at = Vector3.new(c.X, 0, c.Z) + inward * 18
			prompt.CFrame = CFrame.new(at.X, gy(at.X, at.Z) + 2, at.Z)
			table.insert(report, string.format("Twin-Jade prompt spot to the open side (%.0f, %.0f)", at.X, at.Z))
		end
	end
end

-- 5. F18: its prompt spot sat below the ground in the dug wallow
do
	local p = deep(WI.Finds:FindFirstChild("F18_BoarWallow"), "PromptSpotAnchor")
	if p then
		p.CFrame = CFrame.new(p.Position.X, gy(p.Position.X, p.Position.Z) + 2, p.Position.Z)
		table.insert(report, "F18 prompt spot lifted onto the ground")
	end
end

-- 6. the Hunter's Camp lantern stood on the end of the Camp trail
do
	local camp = WI.Pockets:FindFirstChild("HuntersCamp")
	local lantern = camp and deep(camp, "Lantern")
	if lantern then
		local p = lantern:GetPivot().Position
		local trail = Vector3.new(653, p.Y, 716)
		if (Vector2.new(p.X, p.Z) - Vector2.new(trail.X, trail.Z)).Magnitude < 6 then
			local away = (Vector3.new(camp:GetPivot().X, p.Y, camp:GetPivot().Z) - trail)
			away = Vector3.new(away.X, 0, away.Z).Unit
			moveModel(lantern, away * 6)
			table.insert(report, "camp lantern moved 6 studs off the trail end")
		end
	end
end

-- 7. the hermitage clear of the SouthWestFar karst collider (players met an invisible wall)
do
	local h = WI.Pockets:FindFirstChild("ThreePillarsHermitage")
	if h and (Vector2.new(h:GetPivot().X, h:GetPivot().Z) - Vector2.new(-566, 1176)).Magnitude < 1 then
		moveModel(h, Vector3.new(14, 0, -11))
		local p = h:GetPivot()
		local g = gy(p.X, p.Z)
		table.insert(report, string.format("hermitage moved 18 studs off the karst collider to (%.0f, %.0f); ground %.1f under its pivot", p.X, p.Z, g))
		local q = deep(h, "QiNodeSpotAnchor")
		if q then
			table.insert(report, string.format("QiNode7 spot now (%.1f, %.1f, %.1f)", q.Position.X, q.Position.Y, q.Position.Z))
		end
	end
end

-- 8. the HeavenSplitter cache onto the shrine terrace's front edge, at the top of the stair
do
	local shrine = WI.Pockets:FindFirstChild("ShrineTerrace")
	local stair = deep(shrine, "FrontStair")
	local cache = workspace.Map.Markers.ManualCaches:FindFirstChild("Cache_HeavenSplitter")
	if shrine and stair and cache then
		local cf, size = stair:GetBoundingBox()
		-- top of the stair: the highest point of its box, one step back toward the terrace (+Z)
		local top = Vector3.new(cf.X + 6, cf.Y + size.Y / 2, cf.Z + size.Z / 2 + 3)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { cache, workspace:FindFirstChild("_EditorMarkers") }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(top + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), params)
		if hit then
			local f = cache.Footing
			cache:PivotTo(cache:GetPivot() + Vector3.new(hit.Position.X - f.Position.X, (hit.Position.Y - 0.1) - (f.Position.Y - f.Size.Y / 2), hit.Position.Z - f.Position.Z))
			table.insert(report, string.format("HeavenSplitter cache to the stair head (%.0f, %.1f, %.0f)", hit.Position.X, hit.Position.Y, hit.Position.Z))
		end
	end
end

return table.concat(report, "\n")
