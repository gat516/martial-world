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

local STAGES = _G.MAIN_PEAK_STAGES or { place = true, collision = true, terrain = true, pines = true }

-- BEGIN MESHES (generated from MainPeakRock.json)
local MESHES = {
	MainRockSpire = { center = { -0.356, 94.032, 730.905 }, size = { 171.466, 109.16, 161.413 } }, -- 9300 tris
	MainRockMesa = { center = { -1.047, 13.164, 617.914 }, size = { 261.215, 279.722, 71.251 } }, -- 9527 tris
	MainRockCliffA = { center = { 60.076, -24.905, 496.933 }, size = { 259.092, 334.085, 173.866 } }, -- 7086 tris
	MainRockCliffB = { center = { -31.943, -38.861, 496.843 }, size = { 315.137, 290.118, 173.686 } }, -- 7179 tris
	MainRockCliffC = { center = { 0.39, 35.611, 496.845 }, size = { 335.321, 304.35, 173.69 } }, -- 6720 tris
	MainRockBase = { center = { 1.851, 3.227, 209.007 }, size = { 472.997, 469.427, 435.775 } }, -- 6000 tris
	MainGrass = { center = { 0.12, -2.081, 620.127 }, size = { 379.002, 379.734, 384.283 } }, -- 7182 tris
	MainPath = { center = { -0.097, 0.066, 581.91 }, size = { 331.778, 331.681, 0.42 } }, -- 2048 tris
}
-- END MESHES

local CLEAR_RADIUS = 203 -- the 8 spirit peaks (r 300) and their terrain start beyond ~205
local CLEAR_BOTTOM, CLEAR_TOP = 12, 900 -- ground ring is at y ~ -10..8
local GRASS_VARIANT = "Stylized Grass I - BZ1 Studios"

local CHS = game:GetService("ChangeHistoryService")
local terrain = workspace.Terrain
local mainPeak = workspace.Map.Sect.MainPeak

local STYLE = {
	MainGrass = { material = Enum.Material.Grass, variant = GRASS_VARIANT, color = Color3.new(1, 1, 1), fidelity = "PreciseConvexDecomposition" },
	MainPath = { material = Enum.Material.Pavement, terrainColor = Enum.Material.Pavement, collide = false, shadow = false },
	MainRockBase = { material = Enum.Material.Rock, terrainColor = Enum.Material.Rock, fidelity = "Hull" },
}
local ROCK = { material = Enum.Material.Rock, terrainColor = Enum.Material.Rock, fidelity = "PreciseConvexDecomposition" }

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
		part.Color = st.color or terrain:GetMaterialColor(st.terrainColor)
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = st.collide ~= false
		part.CanQuery = st.collide ~= false
		part.CastShadow = st.shadow ~= false
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		part.Parent = rock
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
