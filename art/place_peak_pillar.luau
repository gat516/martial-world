--[[
Swaps the spirit-peak pillar meshes after File > Import 3D of art/SpiritPeakPillar.fbx. Run in Studio (Edit
mode) from the command bar or the MCP.

  1. finds the imported MeshParts by name, sizes/places them from SpiritPeakPillar.json, styles them, and
     rebuilds ServerStorage.PeakPillar from them (the import container is deleted)
  2. replaces every SpiritPeaks.Peak_N.Pillar with a clone of the template at the same pivot
  3. removes the old part-built CaveAbode.CliffStairs (the stairs are now PeakStairs/Rail/Ramp in the pillar)
  4. lays invisible LawnCollider boxes just under each lawn (template and every peak): PeakGrass is an open
     turf shell 420 studs tall, and its convex-decomposed collision has holes in the lawn (one over the abode
     dome, a crack across the middle) that players fell through. The boxes come from art/lawn_collider.py.

Set _G.PEAK_PILLAR_STAGES = { colliders = true } to only (re)lay the lawn colliders, without an import.

One ChangeHistory recording, so Ctrl+Z undoes it. Collision geometry for PreciseConvexDecomposition parts is
computed per clone and can take a few seconds.

Mesh bounds are in Blender axes (x right, y outward, z up; origin = Plateau centre at world y 553.5). Import maps
Blender +X to mesh -X and +Y to mesh +Z, so relative to the pillar pivot: Size = (bx, bz, by),
CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy).
]]

-- BEGIN MESHES (generated from SpiritPeakPillar.json)
local MESHES = {
	PeakRock = { center = { 5.232, -0.768, -90.51 }, size = { 152.267, 143.797, 173.98 } }, -- 8165 tris
	PeakRockBase = { center = { -0.25, 0.606, -370.505 }, size = { 214.559, 212.153, 386.011 } }, -- 13079 tris
	PeakGrass = { center = { -5.35, 3.369, -211.962 }, size = { 177.62, 151.409, 421.653 } }, -- 4353 tris
	AbodeWalls = { center = { 0.04, 16.581, -16.25 }, size = { 62.543, 75.837, 17.5 } }, -- 461 tris
	AbodeFloor = { center = { 0.0, 16.75, -25.0 }, size = { 62.0, 75.5, 0.0 } }, -- 48 tris
	PeakStairs = { center = { -39.385, 28.288, -15.116 }, size = { 29.803, 44.402, 24.305 } }, -- 247 tris
	PeakStairsRail = { center = { -41.85, 29.071, -12.359 }, size = { 24.19, 40.601, 25.681 } }, -- 430 tris
	PeakStairsRamp = { center = { -39.165, 27.738, -13.95 }, size = { 30.331, 45.811, 24.1 } }, -- 222 tris
}
-- END MESHES

-- BEGIN LAWN_COLLIDER (generated from SpiritPeakPillar.json: x0, x1, y0, y1, top in Blender axes)
local LAWN_COLLIDER = {
	{ -48.0, -44.0, -5.836, 5.164, -1.825 },
	{ -44.0, -40.0, -19.336, 6.164, -1.843 },
	{ -40.0, -36.0, -27.336, 15.664, -1.838 },
	{ -40.0, -36.0, 21.164, 28.164, -1.794 },
	{ -36.0, -32.0, -31.836, 33.164, -1.823 },
	{ -32.0, -28.0, -35.836, 37.664, -1.801 },
	{ -28.0, -24.0, -38.836, 42.164, -1.775 },
	{ -24.0, -20.0, -41.336, 45.664, -1.723 },
	{ -20.0, -16.0, -43.336, 48.164, -1.776 },
	{ -16.0, -12.0, -45.336, 49.164, -1.749 },
	{ -12.0, -8.0, -46.336, 50.164, -1.684 },
	{ -8.0, -4.0, -47.336, 50.664, -1.697 },
	{ -4.0, 0.0, -48.336, 51.164, -1.724 },
	{ 0.0, 4.0, -48.836, 51.664, -1.738 },
	{ 4.0, 8.0, -48.836, 51.164, -1.715 },
	{ 8.0, 12.0, -47.836, 50.164, -1.69 },
	{ 12.0, 16.0, -46.836, 48.664, -1.711 },
	{ 16.0, 20.0, -44.836, 47.164, -1.739 },
	{ 20.0, 24.0, -43.336, 43.664, -1.743 },
	{ 24.0, 28.0, -40.836, 38.664, -1.755 },
	{ 28.0, 32.0, -37.836, 33.664, -1.758 },
	{ 32.0, 36.0, -34.336, 28.664, -1.758 },
	{ 36.0, 40.0, -29.336, 22.664, -1.737 },
	{ 40.0, 44.0, -22.836, 17.164, -1.75 },
	{ 44.0, 48.0, -11.336, 8.164, -1.73 },
}
-- END LAWN_COLLIDER
local COLLIDER_DEPTH = 3.5 -- box thickness; stays above the abode dome (apex 7.5 under the lawn)
local COLLIDER_OVERLAP = 0.1 -- neighbouring strips overlap this much, so no seam is left between them

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

local STAGES = _G.PEAK_PILLAR_STAGES or { swap = true, colliders = true }

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

-- Blender (x, y, z) is pillar-local (x, z, -y), as for the meshes
local function layLawnCollider(pillar)
	local old = pillar:FindFirstChild("LawnCollider")
	if old then
		old:Destroy()
	end
	local pivot = pillar:GetPivot()
	local folder = Instance.new("Model")
	folder.Name = "LawnCollider"
	for i, b in LAWN_COLLIDER do
		local x0, x1, y0, y1, top = b[1], b[2], b[3], b[4], b[5]
		local part = Instance.new("Part")
		part.Name = "LawnCollider" .. i
		part.Size = Vector3.new(x1 - x0 + 2 * COLLIDER_OVERLAP, COLLIDER_DEPTH, y1 - y0)
		part.CFrame = pivot * CFrame.new((x0 + x1) / 2, top - COLLIDER_DEPTH / 2, -(y0 + y1) / 2)
		part.Anchored = true
		part.Transparency = 1
		part.CanCollide = true
		part.CanQuery = true
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = folder
	end
	folder.Parent = pillar
end

local function layAllLawnColliders()
	local template = ServerStorage:FindFirstChild("PeakPillar")
	assert(template, "ServerStorage.PeakPillar missing; run the full swap first")
	layLawnCollider(template)
	for _, peak in peaks:GetChildren() do
		layLawnCollider(assert(peak:FindFirstChild("Pillar"), peak.Name .. " has no Pillar"))
	end
end

local recording = CHS:TryBeginRecording("PlacePeakPillar")
local ok, err = pcall(function()
	if STAGES.swap then
		local template = buildTemplate()
		layLawnCollider(template) -- clones carry it
		swapPillars(template)
	elseif STAGES.colliders then
		layAllLawnColliders()
	end
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
print(STAGES.swap and "swapped" or "laid lawn colliders on", #peaks:GetChildren(), "pillars")
