--!nocheck
-- Builds the SpiritWolf variant A body (build_spirit_wolf.py: rigid segment meshes) from a fresh
-- Import 3D of SpiritWolf.fbx into ServerStorage._StagingEnemies.SpiritWolf_A, 15 studs over in +X.
-- Run in Studio, Edit mode, through the MCP (execute_luau) or the command bar, after the import.
-- One ChangeHistoryService recording (Ctrl+Z undoes it).
--
-- It only sizes, styles and places the segments: it adds no HumanoidRootPart, Humanoid, HealthBar,
-- Motor6Ds or welds. art/enemies/spirit_wolf/rig_wolf.luau (TARGET = "SpiritWolf_A") rigs it, the
-- same way as the Part-built variant B. ServerStorage.Enemies (Rojo-mapped) is never touched; any
-- SpiritWolf_B next to it is left alone.
--
-- Model space: ground Y 0, the wolf faces -Z, its left side is -X. Each mesh's centre/size come from
-- SpiritWolf.json (roblox_center/roblox_size = (cx, cz, -cy)/(bx, bz, by) of the Blender bounds), and
-- every MeshPart keeps the FBX import's frame, CFrame.Angles(0, math.pi, 0). Colour is one 64x64
-- palette texture (SpiritWolfPalette.png, every face UV'd onto one swatch) shared as TextureID on
-- SmoothPlastic; the eyes are Neon with a plain Color.
-- Regenerate the MESHES block after a rebuild: python3 art/enemies/spirit_wolf/gen_place_block.py

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local IMPORT_NAME = "SpiritWolf" -- the Import 3D container (Workspace.<file name>)
local OFFSET = Vector3.new(15, 0, 0)
local PALETTE = "rbxassetid://107542389233794" -- SpiritWolfPalette.png
local EYE_COLOR = Color3.fromRGB(255, 43, 43)

-- BEGIN MESHES (generated from SpiritWolf.json: name = { centre, size, tris, textured })
local MESHES = {
	Hips = { center = { 0, 3.018, 1.7 }, size = { 2.16, 1.935, 2.599 }, tris = 376, textured = true },
	Chest = { center = { 0, 3.076, -0.415 }, size = { 2.324, 2.711, 3.226 }, tris = 474, textured = true },
	Neck = { center = { 0, 3.376, -2.299 }, size = { 2.743, 2.348, 1.699 }, tris = 364, textured = true },
	Skull = { center = { 0, 3.1, -3.735 }, size = { 2, 1.36, 2.37 }, tris = 406, textured = true },
	Jaw = { center = { 0, 2.67, -3.911 }, size = { 0.68, 0.5, 1.438 }, tris = 208, textured = true },
	TailBase = { center = { 0, 3.25, 3.286 }, size = { 0.842, 0.721, 1.569 }, tris = 154, textured = true },
	TailMid = { center = { 0, 3.341, 4.308 }, size = { 0.946, 0.915, 1.714 }, tris = 196, textured = true },
	TailTip = { center = { 0, 3.738, 5.141 }, size = { 0.79, 1.325, 1.197 }, tris = 178, textured = true },
	EarL = { center = { -0.45, 3.975, -3.13 }, size = { 0.42, 0.95, 0.26 }, tris = 14, textured = true },
	EyeL = { center = { -0.375, 3.305, -3.971 }, size = { 0.293, 0.129, 0.184 }, tris = 12, textured = false },
	UpperLegFL = { center = { -0.7, 1.946, -1.175 }, size = { 0.68, 1.608, 1.05 }, tris = 140, textured = true },
	LowerLegFL = { center = { -0.72, 0.86, -1.27 }, size = { 0.38, 1.378, 0.458 }, tris = 112, textured = true },
	PawFL = { center = { -0.72, 0.259, -1.71 }, size = { 0.64, 0.518, 1.22 }, tris = 208, textured = true },
	UpperLegBL = { center = { -0.706, 1.986, 2.092 }, size = { 0.848, 1.721, 1.051 }, tris = 112, textured = true },
	LowerLegBL = { center = { -0.75, 1.011, 2.022 }, size = { 0.38, 1.077, 0.857 }, tris = 112, textured = true },
	PawBL = { center = { -0.75, 0.4, 2.13 }, size = { 0.64, 0.8, 1.26 }, tris = 222, textured = true },
	EarR = { center = { 0.45, 3.975, -3.13 }, size = { 0.42, 0.95, 0.26 }, tris = 14, textured = true },
	EyeR = { center = { 0.375, 3.308, -3.971 }, size = { 0.292, 0.128, 0.212 }, tris = 12, textured = false },
	UpperLegFR = { center = { 0.7, 1.946, -1.175 }, size = { 0.68, 1.608, 1.05 }, tris = 140, textured = true },
	LowerLegFR = { center = { 0.72, 0.86, -1.27 }, size = { 0.38, 1.378, 0.458 }, tris = 112, textured = true },
	PawFR = { center = { 0.72, 0.259, -1.71 }, size = { 0.64, 0.518, 1.22 }, tris = 208, textured = true },
	UpperLegBR = { center = { 0.706, 1.986, 2.092 }, size = { 0.848, 1.721, 1.051 }, tris = 112, textured = true },
	LowerLegBR = { center = { 0.75, 1.011, 2.022 }, size = { 0.38, 1.077, 0.857 }, tris = 112, textured = true },
	PawBR = { center = { 0.75, 0.4, 2.13 }, size = { 0.64, 0.8, 1.26 }, tris = 222, textured = true },
}
-- END MESHES

local recording = ChangeHistoryService:TryBeginRecording("Place SpiritWolf_A")

local ok, err = pcall(function()
	-- find the imported meshes: one MeshPart per name inside the import container(s), the Workspace
	-- children named after the file (the map has its own parts called Chest and the like)
	local found, containers = {}, {}
	for _, top in workspace:GetChildren() do
		if top.Name ~= IMPORT_NAME then
			continue
		end
		containers[top] = true
		for _, d in top:GetDescendants() do
			if d:IsA("MeshPart") and MESHES[d.Name] then
				found[d.Name] = found[d.Name] or {}
				table.insert(found[d.Name], d)
			end
		end
	end
	assert(next(containers), "no Workspace." .. IMPORT_NAME .. ": import SpiritWolf.fbx first (File > Import 3D)")
	local missing, doubled = {}, {}
	for name in MESHES do
		local n = found[name] and #found[name] or 0
		if n == 0 then
			table.insert(missing, name)
		elseif n > 1 then
			table.insert(doubled, name .. " x" .. n)
		end
	end
	assert(#missing == 0, "SpiritWolf import: missing meshes " .. table.concat(missing, ", "))
	assert(#doubled == 0, "SpiritWolf import: meshes imported more than once " .. table.concat(doubled, ", "))

	local staging = ServerStorage:FindFirstChild("_StagingEnemies")
	if not staging then
		staging = Instance.new("Folder")
		staging.Name = "_StagingEnemies"
		staging.Parent = ServerStorage
	end
	local old = staging:FindFirstChild("SpiritWolf_A")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "SpiritWolf_A"

	local yaw = CFrame.Angles(0, math.pi, 0)
	for name, m in MESHES do
		local part = found[name][1]
		part.Parent = model
		for _, c in part:GetChildren() do
			if not c:IsA("SurfaceAppearance") then
				continue
			end
			c:Destroy()
		end
		part.Size = Vector3.new(m.size[1], m.size[2], m.size[3])
		part.CFrame = CFrame.new(OFFSET + Vector3.new(m.center[1], m.center[2], m.center[3])) * yaw
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.CollisionFidelity = Enum.CollisionFidelity.Box
		part.DoubleSided = false
		if m.textured then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.new(1, 1, 1)
			part.TextureID = PALETTE
		else
			part.Material = Enum.Material.Neon
			part.Color = EYE_COLOR
			part.TextureID = ""
		end
	end
	model.WorldPivot = CFrame.new(OFFSET)
	model:SetAttribute("Variant", "A: Blender segment meshes (art/enemies/spirit_wolf/build_spirit_wolf.py)")
	model.Parent = staging

	for top in containers do
		top:Destroy()
	end
end)

if recording then
	ChangeHistoryService:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit
		or Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return "SpiritWolf_A placed in ServerStorage._StagingEnemies"
