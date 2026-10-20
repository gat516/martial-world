--[[
Swaps the spirit-peak pillar meshes after File > Import 3D of art/SpiritPeakPillar.fbx. Run in Studio (Edit
mode) from the command bar or the MCP.

  1. finds the imported MeshParts by name, sizes/places them from SpiritPeakPillar.json, styles them, and
     rebuilds ServerStorage.PeakPillar from them (the import container is deleted)
  2. replaces every SpiritPeaks.Peak_N.Pillar with a clone of the template at the same pivot
  3. removes the old part-built CaveAbode.CliffStairs (the stairs are now PeakStairs/Rail/Ramp in the pillar)

One ChangeHistory recording, so Ctrl+Z undoes it. Collision geometry for PreciseConvexDecomposition parts is
computed per clone and can take a few seconds.

Mesh bounds are in Blender axes (x right, y outward, z up; origin = Plateau centre at world y 553.5). Import maps
Blender +X to mesh -X and +Y to mesh +Z, so relative to the pillar pivot: Size = (bx, bz, by),
CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy).
]]

-- BEGIN MESHES (generated from SpiritPeakPillar.json)
local MESHES = {
	PeakRock = { center = { -1.552, 3.292, -89.342 }, size = { 119.144, 125.416, 176.316 } }, -- 9544 tris
	PeakRockBase = { center = { 3.071, -6.655, -370.442 }, size = { 201.442, 214.075, 385.884 } }, -- 7296 tris
	PeakGrass = { center = { -2.845, 1.717, -212.531 }, size = { 149.838, 120.792, 422.734 } }, -- 883 tris
	AbodeWalls = { center = { 0.04, 16.581, -16.25 }, size = { 62.543, 75.837, 17.5 } }, -- 458 tris
	AbodeFloor = { center = { 0.0, 15.87, -25.0 }, size = { 62.0, 73.74, 0.0 } }, -- 68 tris
	PeakStairs = { center = { -38.058, 25.974, -15.116 }, size = { 32.445, 39.778, 24.305 } }, -- 247 tris
	PeakStairsRail = { center = { -40.479, 26.853, -12.359 }, size = { 26.907, 36.169, 25.681 } }, -- 430 tris
	PeakStairsRamp = { center = { -37.872, 25.407, -13.95 }, size = { 32.913, 41.149, 24.1 } }, -- 222 tris
}
-- END MESHES

-- plain colours, no textures: the rock's shape carries the detail
local ROCK = Color3.fromRGB(110, 110, 115)
local GRASS = Color3.fromRGB(110, 165, 70)

local STYLE = {
	PeakRock = { material = Enum.Material.SmoothPlastic, color = ROCK, fidelity = "PreciseConvexDecomposition" },
	PeakRockBase = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(96, 96, 100), fidelity = "Hull" },
	PeakGrass = { material = Enum.Material.SmoothPlastic, color = GRASS, fidelity = "PreciseConvexDecomposition" },
	AbodeWalls = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(150, 138, 120), fidelity = "PreciseConvexDecomposition" },
	AbodeFloor = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(120, 85, 55), fidelity = "Box", shadow = false },
	-- the treads are looks only; feet ride the invisible ramp through the middle of each tread
	PeakStairs = { material = Enum.Material.Slate, color = Color3.fromRGB(150, 146, 140), collide = false },
	PeakStairsRail = { material = Enum.Material.Wood, color = Color3.fromRGB(105, 70, 45), fidelity = "PreciseConvexDecomposition" },
	PeakStairsRamp = { material = Enum.Material.SmoothPlastic, transparency = 1, fidelity = "PreciseConvexDecomposition", shadow = false },
}

local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local peaks = workspace.Map.Sect.SpiritPeaks

local function buildTemplate()
	local template = ServerStorage:FindFirstChild("PeakPillar")
	local found, containers = {}, {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and MESHES[d.Name] and not d:IsDescendantOf(peaks) then
			assert(not found[d.Name], "two imported copies of " .. d.Name .. "; delete the extra import first")
			found[d.Name] = d
			local top = d
			while top.Parent ~= workspace do
				top = top.Parent
			end
			containers[top] = true
		end
	end
	for name in MESHES do
		assert(found[name], "imported mesh " .. name .. " not found; File > Import 3D SpiritPeakPillar.fbx first")
	end
	local model = Instance.new("Model")
	model.Name = "PeakPillar"
	for name, data in MESHES do
		local part, st, c, s = found[name], STYLE[name], data.center, data.size
		part.Size = Vector3.new(s[1], math.max(s[3], 0.05), s[2])
		part.CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-c[1], c[3], c[2])
		part.Material = st.material
		part.MaterialVariant = st.variant or ""
		part.Color = st.color or Color3.new(1, 1, 1)
		part.Transparency = st.transparency or 0
		part.Anchored = true
		part.CanTouch = false
		part.CanCollide = st.collide ~= false
		part.CanQuery = st.collide ~= false
		part.CastShadow = st.shadow ~= false
		if st.fidelity then
			part.CollisionFidelity = Enum.CollisionFidelity[st.fidelity]
		end
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity
	for top in containers do
		top:Destroy()
	end
	if template then
		template:Destroy()
	end
	model.Parent = ServerStorage
	return model
end

local function swapPillars(template)
	for _, peak in peaks:GetChildren() do
		local old = peak:FindFirstChild("Pillar")
		assert(old, peak.Name .. " has no Pillar")
		local pivot = old:GetPivot()
		local new = template:Clone()
		new.Name = "Pillar"
		new:PivotTo(pivot)
		old:Destroy()
		new.Parent = peak
		local stairs = peak:FindFirstChild("CaveAbode") and peak.CaveAbode:FindFirstChild("CliffStairs")
		if stairs then
			stairs:Destroy()
		end
		task.wait()
	end
end

local recording = CHS:TryBeginRecording("PlacePeakPillar")
local ok, err = pcall(function()
	swapPillars(buildTemplate())
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
print("swapped", #peaks:GetChildren(), "pillars")
