--[[
Places the MainPeak rock meshes after File > Import 3D of art/main_peak/MainPeakRock.fbx, then clears
the old main-peak terrain and re-seats the pines. Run in Studio (Edit mode) from the command bar or the MCP.

Each stage can be run on its own (set STAGES below) so no single call runs too long:
  place      find the imported MeshParts, size/place them, materials, move into MainPeak.Rock, delete the import
  collision  CollisionFidelity per part (PreciseConvexDecomposition is slow, one part per frame)
  terrain    clear terrain in a cylinder r < 203 around the origin, y 12..900 (spirit peaks / ground ring untouched)
  pines      drop/raise each MainPeak.Pines tree onto the new rock
Everything is one ChangeHistory recording per run, so Ctrl+Z undoes it.

Mesh bounds come from MainPeakRock.json (Blender axes). Import maps Blender +X to mesh -X and +Y to mesh +Z,
and the Blender origin is the world origin, so: Size = (bx, bz, by),
CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy).
]]

-- terrain clearing and the pines are now terrain_main_peak.luau's and dress_main_peak.luau's job (clearing here
-- would wipe the terrain floors); run them only on purpose
local STAGES = _G.MAIN_PEAK_STAGES or { place = true, collision = true }

-- BEGIN MESHES (generated from MainPeakRock.json)
local MESHES = {
	MainRockSpire1 = { center = { -0.019, 103.521, 695.5 }, size = { 165.52, 108.092, 191.0 } }, -- 8429 tris
	MainRockSpire2 = { center = { 2.776, 94.613, 695.5 }, size = { 157.271, 99.703, 191.0 } }, -- 11500 tris
	MainRockSpire3 = { center = { 0.403, 98.706, 680.95 }, size = { 154.021, 105.91, 161.9 } }, -- 7633 tris
	MainRockMesa1 = { center = { -2.989, 16.853, 616.863 }, size = { 249.243, 277.922, 72.725 } }, -- 6157 tris
	MainRockMesa2 = { center = { 0.655, 18.424, 617.493 }, size = { 257.85, 281.439, 73.986 } }, -- 8140 tris
	MainRockMesa3 = { center = { 0.859, 16.437, 616.733 }, size = { 253.673, 277.464, 72.466 } }, -- 6389 tris
	MainRockCliff1 = { center = { -0.37, -0.218, 498.648 }, size = { 371.052, 379.29, 177.344 } }, -- 17522 tris
	MainRockCliff2 = { center = { 0.371, -0.989, 497.937 }, size = { 374.0, 377.974, 175.922 } }, -- 15564 tris
	MainRockCliff3 = { center = { 0.058, 0.31, 498.476 }, size = { 370.92, 373.581, 176.979 } }, -- 11847 tris
	MainRockFoot1 = { center = { 1.379, 3.106, 202.084 }, size = { 452.069, 454.322, 424.168 } }, -- 10583 tris
	MainRockFoot2 = { center = { 1.002, 2.566, 202.144 }, size = { 451.315, 454.251, 424.245 } }, -- 10530 tris
	MainRockFoot3 = { center = { 1.002, 1.486, 202.044 }, size = { 451.315, 456.41, 424.045 } }, -- 8886 tris
	MainLedges = { center = { -84.157, -88.91, 520.935 }, size = { 210.716, 233.966, 61.542 } }, -- 2056 tris
}
-- END MESHES

-- meshes earlier builds made that this one replaces (deleted from MainPeak.Rock on place)
local RETIRED = {
	"MainRockSpire", "MainRockMesa", "MainRockCliffA", "MainRockCliffB", "MainRockCliffC", "MainGrass", "MainPath",
	"MainTufts", "MainLawn1", "MainLawn2", "MainLawn3", "MainRockBase",
	"MainTurfLip", -- the terrain lawn's own drooping edge reads better; the lip mesh floated where they differed
	"MainMoss", -- made for the turf lip: under the sunk rim rock it hung as a dark green sheet (still in the old FBX)
}

local CLEAR_RADIUS = 203 -- the 8 spirit peaks (r 300) and their terrain start beyond ~205
local CLEAR_BOTTOM, CLEAR_TOP = 12, 900 -- ground ring is at y ~ -10..8
-- palette colours (docs/systems/map.md) on Roblox's textured materials: rock in three values per region (split
-- per stone column / tower band in Blender); the lawns themselves are Terrain (terrain_main_peak.luau), with no
-- green meshes on their edges
local function hex(h)
	return Color3.fromHex(h)
end
local COLORS = {
	MainRockSpire1 = hex("8E8983"), MainRockSpire2 = hex("7F7A74"), MainRockSpire3 = hex("6E6A65"),
	MainRockMesa1 = hex("8A847D"), MainRockMesa2 = hex("7A7570"), MainRockMesa3 = hex("6A6661"),
	MainRockCliff1 = hex("7F7A74"), MainRockCliff2 = hex("706B66"), MainRockCliff3 = hex("615D59"),
	MainRockFoot1 = hex("7F7A74"), MainRockFoot2 = hex("706B66"), MainRockFoot3 = hex("615D59"),
	MainLedges = hex("7A7570"),
	MainTurfLip = hex("5A7A48"), MainMoss = hex("4E6B45"),
}

local CHS = game:GetService("ChangeHistoryService")
local terrain = workspace.Terrain
local mainPeak = workspace.Map.Sect.MainPeak

local ROCK_MATERIAL = Enum.Material[_G.MAIN_PEAK_ROCK_MATERIAL or "Rock"] -- Rock / Slate / Basalt, tinted
local STYLE = {
	MainTurfLip = { material = Enum.Material.Grass, fidelity = "PreciseConvexDecomposition" },
	MainMoss = { material = Enum.Material.Grass, collide = false, shadow = false },
	-- the foot is below the cloud deck, seen from afar and from the wilds: simple hull collision
	MainRockFoot1 = { material = ROCK_MATERIAL, fidelity = "Hull" },
	MainRockFoot2 = { material = ROCK_MATERIAL, fidelity = "Hull" },
	MainRockFoot3 = { material = ROCK_MATERIAL, fidelity = "Hull" },
}
local ROCK = { material = ROCK_MATERIAL, fidelity = "PreciseConvexDecomposition" }

local function rockFolder()
	local rock = mainPeak:FindFirstChild("Rock")
	if not rock then
		rock = Instance.new("Model")
		rock.Name = "Rock"
		rock.Parent = mainPeak
	end
	return rock
end

local function place()
	local rock = rockFolder()
	local found, containers = {}, {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and MESHES[d.Name] and not d:IsDescendantOf(rock) then
			assert(not found[d.Name], "two imported copies of " .. d.Name .. "; delete the extra import first")
			found[d.Name] = d
			local top = d
			while top.Parent ~= workspace do
				top = top.Parent
			end
			containers[top] = true
		end
	end
	for name, data in MESHES do
		local old = rock:FindFirstChild(name)
		local part = found[name]
		if not part then
			assert(old, "imported mesh " .. name .. " not found; File > Import 3D MainPeakRock.fbx first")
			part = old -- re-run: just re-apply the placement
		elseif old then
			old:Destroy()
		end
		local c, s = data.center, data.size
		part.Size = Vector3.new(s[1], math.max(s[3], 0.05), s[2])
		part.CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-c[1], c[3], c[2])
		local st = STYLE[name] or ROCK
		part.Material = st.material
		part.MaterialVariant = st.variant or ""
		part.Color = COLORS[name] or Color3.fromHex("7A7570")
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = st.collide ~= false
		part.CanQuery = st.collide ~= false
		part.CastShadow = st.shadow ~= false
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		part.Parent = rock
	end
	for _, name in RETIRED do
		local old = rock:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	-- the import container (and any helper meshes that came with it)
	for top in containers do
		if top ~= workspace.Map and not top:IsAncestorOf(mainPeak) then
			local others = {}
			for _, d in top:GetDescendants() do
				if d:IsA("BasePart") and not d:IsA("MeshPart") then
					table.insert(others, d:GetFullName())
				end
			end
			if #others == 0 then
				top:Destroy() -- only helper meshes left, if any
			else
				warn("left import container in place, it holds non-mesh parts: " .. table.concat(others, ", "))
			end
		end
	end
	print("placed", #rock:GetChildren(), "rock meshes")
end

local function collision()
	for name in MESHES do
		local part = mainPeak.Rock:FindFirstChild(name)
		local fid = (STYLE[name] or ROCK).fidelity
		if part and fid and part.CollisionFidelity.Name ~= fid then
			part.CollisionFidelity = Enum.CollisionFidelity[fid]
			print("collision", name, fid)
			task.wait()
		end
	end
end

local function clearTerrain()
	local y = CLEAR_BOTTOM
	while y < CLEAR_TOP do
		local h = math.min(48, CLEAR_TOP - y)
		terrain:FillCylinder(CFrame.new(0, y + h / 2, 0), h, CLEAR_RADIUS, Enum.Material.Air)
		y += h
		task.wait()
	end
	print("cleared terrain r <", CLEAR_RADIUS, "y", CLEAR_BOTTOM, "..", CLEAR_TOP)
end

local function reseatPines()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mainPeak.Rock }
	local moved, report = 0, {}
	for _, pine in mainPeak.Pines:GetChildren() do
		local cf, size = pine:GetBoundingBox()
		local base = cf.Position - Vector3.new(0, size.Y / 2, 0)
		local hit = workspace:Raycast(base + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), params)
		if not hit then -- trunk now inside the rock, or floating: look further up and down
			local up = workspace:Raycast(base + Vector3.new(0, 30, 0), Vector3.new(0, -30, 0), params)
			local down = workspace:Raycast(base, Vector3.new(0, -40, 0), params)
			hit = up or down
			if up and down and math.abs(down.Position.Y - base.Y) < math.abs(up.Position.Y - base.Y) then
				hit = down
			end
		end
		if hit then
			local dy = hit.Position.Y - 0.6 - base.Y -- trunk sinks a little into the ground, no gap
			if math.abs(dy) > 0.05 then
				pine:PivotTo(pine:GetPivot() + Vector3.new(0, dy, 0))
				moved += 1
				if math.abs(dy) > 3 then
					table.insert(report, string.format("%s at (%.0f, %.0f, %.0f) moved %.1f", pine.Name, base.X, base.Y, base.Z, dy))
				end
			end
		else
			table.insert(report, string.format("%s at (%.0f, %.0f, %.0f) has no rock under it", pine.Name, base.X, base.Y, base.Z))
		end
	end
	print("re-seated", moved, "pines")
	for _, line in report do
		warn(line)
	end
end

local recording = CHS:TryBeginRecording("PlaceMainPeakRock")
local ok, err = pcall(function()
	if STAGES.place then
		place()
	end
	if STAGES.collision then
		collision()
	end
	if STAGES.terrain then
		clearTerrain()
	end
	if STAGES.pines then
		reseatPines()
	end
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
