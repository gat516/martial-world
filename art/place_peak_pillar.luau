--[[
Swaps the spirit-peak pillar meshes after File > Import 3D of art/SpiritPeakPillar.fbx. Run in Studio (Edit
mode) from the command bar or the MCP.

  1. finds the imported MeshParts by name, sizes/places them from SpiritPeakPillar.json, styles them, and
     rebuilds ServerStorage.PeakPillar from them (the import container is deleted)
  2. replaces every SpiritPeaks.Peak_N.Pillar with a clone of the template at the same pivot
  3. removes the old part-built CaveAbode.CliffStairs (the stairs are now PeakStairs/Rail/Ramp in the pillar)
  4. lays invisible LawnCollider boxes just under each lawn (template and every peak): PeakGrass is an open
     turf shell (it used to run 420 studs down the cliff to the ledge turf), and its convex-decomposed collision has holes in the lawn (one over the abode
     dome, a crack across the middle) that players fell through. The boxes come from art/lawn_collider.py.

Set _G.PEAK_PILLAR_STAGES = { colliders = true } to only (re)lay the lawn colliders, without an import, and add
`peaks = { 1 }` to either stage to touch only those peaks (the template is always rebuilt on a swap). Children of
an old Pillar that aren't meshes or the collider (Peak_N.Pillar.Terrace) are moved onto the new one.

One ChangeHistory recording, so Ctrl+Z undoes it. Collision geometry for PreciseConvexDecomposition parts is
computed per clone and can take a few seconds.

Mesh bounds are in Blender axes (x right, y outward, z up; origin = Plateau centre at world y 553.5). Import maps
Blender +X to mesh -X and +Y to mesh +Z, so relative to the pillar pivot: Size = (bx, bz, by),
CFrame = CFrame.Angles(0, math.pi, 0) * CFrame.new(-cx, cz, cy).
]]

-- BEGIN MESHES (generated from SpiritPeakPillar.json)
local MESHES = {
	PeakRock = { center = { 5.232, -0.768, -90.51 }, size = { 152.267, 143.797, 173.98 } }, -- 8193 tris
	PeakRockBase = { center = { -0.25, 0.606, -370.505 }, size = { 214.559, 212.153, 386.011 } }, -- 13106 tris
	PeakGrass = { center = { -1.588, 1.108, -2.668 }, size = { 106.956, 106.034, 3.065 } }, -- 3860 tris
	AbodeWalls = { center = { 0.04, 16.581, -16.25 }, size = { 62.543, 75.837, 17.5 } }, -- 461 tris
	AbodeFloor = { center = { 0.0, 16.75, -25.0 }, size = { 62.0, 75.5, 0.0 } }, -- 48 tris
	PeakStairs = { center = { -39.385, 28.288, -15.116 }, size = { 29.803, 44.402, 24.305 } }, -- 247 tris
	PeakStairsRail = { center = { -41.85, 29.071, -12.359 }, size = { 24.19, 40.601, 25.681 } }, -- 430 tris
	PeakStairsRamp = { center = { -39.165, 27.738, -13.95 }, size = { 30.331, 45.811, 24.1 } }, -- 222 tris
}
-- END MESHES

-- BEGIN LAWN_COLLIDER (generated from SpiritPeakPillar.json: x0, x1, y0, y1, top in Blender axes)
local LAWN_COLLIDER = {
	{ -48.0, -44.0, -5.908, 5.092, -1.827 },
	{ -44.0, -40.0, -19.408, 6.092, -1.843 },
	{ -40.0, -36.0, -27.408, 16.092, -1.838 },
	{ -40.0, -36.0, 21.092, 28.092, -1.794 },
	{ -36.0, -32.0, -31.908, 33.092, -1.824 },
	{ -32.0, -28.0, -35.908, 37.592, -1.801 },
	{ -28.0, -24.0, -38.908, 42.092, -1.775 },
	{ -24.0, -20.0, -41.408, 46.092, -1.725 },
	{ -20.0, -16.0, -43.408, 48.092, -1.777 },
	{ -16.0, -12.0, -44.908, 49.092, -1.746 },
	{ -12.0, -8.0, -46.408, 50.092, -1.684 },
	{ -8.0, -4.0, -47.408, 50.592, -1.697 },
	{ -4.0, 0.0, -48.408, 51.092, -1.724 },
	{ 0.0, 4.0, -48.908, 51.592, -1.736 },
	{ 4.0, 8.0, -48.908, 51.092, -1.715 },
	{ 8.0, 12.0, -47.908, 50.092, -1.69 },
	{ 12.0, 16.0, -46.408, 48.592, -1.711 },
	{ 16.0, 20.0, -44.908, 47.092, -1.738 },
	{ 20.0, 24.0, -42.908, 43.592, -1.742 },
	{ 24.0, 28.0, -40.908, 39.092, -1.755 },
	{ 28.0, 32.0, -37.908, 33.592, -1.758 },
	{ 32.0, 36.0, -33.908, 28.592, -1.758 },
	{ 36.0, 40.0, -29.408, 22.592, -1.737 },
	{ 40.0, 44.0, -22.408, 17.092, -1.75 },
	{ 44.0, 48.0, -11.408, 8.092, -1.73 },
}
-- END LAWN_COLLIDER
local COLLIDER_DEPTH = 3.5 -- box thickness; stays above the abode dome (apex 7.5 under the lawn)
local COLLIDER_OVERLAP = 0.1 -- neighbouring strips overlap this much, so no seam is left between them

-- Roblox's textured materials tinted to the map palette (docs/systems/map.md): the user found SmoothPlastic
-- "too plasticy". LeafyGrass is overridden by MaterialService's stylized grass variant, the same one the
-- terrain lawns use, and tinted like terrain LeafyGrass (6E8F5A), so the peaks read as the same green.
local STYLE = {
	PeakRock = { material = Enum.Material.Slate, color = Color3.fromHex("7A7570"), fidelity = "PreciseConvexDecomposition" },
	PeakRockBase = { material = Enum.Material.Slate, color = Color3.fromHex("615D59"), fidelity = "Hull" },
	PeakGrass = { material = Enum.Material.LeafyGrass, color = Color3.fromHex("6E8F5A"), fidelity = "PreciseConvexDecomposition" },
	AbodeWalls = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(150, 138, 120), fidelity = "PreciseConvexDecomposition" },
	AbodeFloor = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(120, 85, 55), fidelity = "Box", shadow = false },
	-- the treads are looks only; feet ride the invisible ramp through the middle of each tread
	PeakStairs = { material = Enum.Material.Slate, color = Color3.fromRGB(150, 146, 140), collide = false },
	PeakStairsRail = { material = Enum.Material.Wood, color = Color3.fromRGB(105, 70, 45), fidelity = "PreciseConvexDecomposition" },
	PeakStairsRamp = { material = Enum.Material.SmoothPlastic, transparency = 1, fidelity = "PreciseConvexDecomposition", shadow = false },
}

local STAGES = _G.PEAK_PILLAR_STAGES or { swap = true, colliders = true }
local ONLY = STAGES.peaks -- e.g. { 1 }: swap/lay only these peaks' pillars (default all 8)

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

local function chosen(peak: Instance): boolean
	if not ONLY then
		return true
	end
	for _, i in ONLY do
		if peak.Name == "Peak_" .. i then
			return true
		end
	end
	return false
end

local function swapPillars(template)
	for _, peak in peaks:GetChildren() do
		if not chosen(peak) then
			continue
		end
		local old = peak:FindFirstChild("Pillar")
		assert(old, peak.Name .. " has no Pillar")
		local pivot = old:GetPivot()
		local new = template:Clone()
		new.Name = "Pillar"
		new:PivotTo(pivot)
		-- keep what was built onto the pillar by other scripts (the dwelling's Terrace): anything that is
		-- not one of the meshes or the lawn collider moves across unchanged
		for _, c in old:GetChildren() do
			if not MESHES[c.Name] and c.Name ~= "LawnCollider" then
				c.Parent = new
			end
		end
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
		if not chosen(peak) then
			continue
		end
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
