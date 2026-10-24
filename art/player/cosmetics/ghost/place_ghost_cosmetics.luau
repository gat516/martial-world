--!nocheck
-- Ghost talismans and spirit silk: turns the seven imported skinned FBX models into
-- Accessory templates in ReplicatedStorage.Cosmetics.Ghost. Run in Edit mode in a SANDBOX
-- (no Rojo) through the Studio MCP (execute_luau, paste the file) after inserting each
-- set's model asset (ASSETS below, uploaded with tools/upload_asset.py model) into
-- Workspace as `_Import<Set>`. It creates the Ghost folder if it's missing, rebuilds the
-- accessory of every set that has an import (the others keep their current template) and
-- deletes the import models. One ChangeHistoryService recording, so Ctrl+Z undoes it.
-- Then export the folder to assets/Cosmetics/Ghost.rbxm (README.md). Adapted from the
-- dragonblood's.
--
-- What the importer gives: a Model with an invisible `RootPart` (the FBX origin, which is
-- the attachment point) holding the Bones (Root -> ...), the skinned MeshParts Motor6D'd
-- to it, an AnimationController and an InitialPoses folder. RootPart's frame is the
-- attachment's Roblox frame already (Blender (x, y, z) -> (-x, z, y)), so nothing moves:
-- RootPart becomes the Handle, the Motor6Ds become Welds.
--
-- Each accessory:
--   Accessory <Set>                AccessoryType Face, Shoulder, Waist or Back
--     Handle (Part)                invisible 0.2 cube at the attachment point
--       <Attachment>               identity (FaceFront, Left/RightGrip, WaistCenter, BodyBack)
--       Bone Root -> ...           the rig (names as in the Blender armature)
--     <Set>_<Region> (MeshPart)    skinned; Weld to Handle; Color = region colour
--       SurfaceAppearance          ColorMap = the region's ramp, Color = region colour
-- Paper, Ink and Cord use the shared shade ramp (opaque). Spirit and Wisp use
-- ghost_fade.png with AlphaMode Transparency: the silk fades out toward its tips, and
-- casts no shadow. Recolour a region by setting both the MeshPart's Color and its
-- SurfaceAppearance.Color (the SurfaceAppearance shows over the part colour).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Uploaded model assets (tools/upload_asset.py model, 2026-10-23)
local ASSETS = {
	GhostTalismanBanner = 90085270826165,
	GhostTalismanStrip = 103216655075163,
	GhostTalismanSeal = 116359512598161,
	GhostTrain = 126381646311638,
	GhostSleeveL = 122195345882662,
	GhostSleeveR = 86335057645184,
	GhostStole = 109224132470640,
}
local SHADE = "rbxassetid://124559907609415" -- fox_shade.png, byte-identical (shared ramp)
local FADE = "rbxassetid://106658937544761" -- ghost_fade.png, RGBA (Studio MCP upload_image, 2026-10-23)

-- Region colours: the JSONs' linear `colors`, converted to sRGB below
local LINEAR = {
	Paper = { 0.79, 0.62, 0.32 },
	Ink = { 0.52, 0.025, 0.015 },
	Cord = { 0.025, 0.03, 0.08 },
	Spirit = { 0.60, 0.78, 0.95 },
	Wisp = { 0.42, 0.78, 0.90 },
}
local FADES = { Spirit = true, Wisp = true } -- regions on the alpha ramp
local TALISMAN = { attachment = "FaceFrontAttachment", type = Enum.AccessoryType.Face }
local SETS = {
	GhostTalismanBanner = { def = TALISMAN, meshes = { "Paper", "Ink", "Cord" } },
	GhostTalismanStrip = { def = TALISMAN, meshes = { "Paper", "Ink" } },
	GhostTalismanSeal = { def = TALISMAN, meshes = { "Paper", "Ink" } },
	GhostTrain = { def = { attachment = "WaistCenterAttachment", type = Enum.AccessoryType.Waist }, meshes = { "Wisp", "Spirit" } },
	GhostSleeveL = { def = { attachment = "LeftGripAttachment", type = Enum.AccessoryType.Shoulder }, meshes = { "Wisp", "Spirit" } },
	GhostSleeveR = { def = { attachment = "RightGripAttachment", type = Enum.AccessoryType.Shoulder }, meshes = { "Wisp", "Spirit" } },
	GhostStole = { def = { attachment = "BodyBackAttachment", type = Enum.AccessoryType.Back }, meshes = { "Wisp" } },
}
local ORDER = { -- Talisman look (Banner default), Spirit look (Train default)
	"GhostTalismanBanner",
	"GhostTalismanStrip",
	"GhostTalismanSeal",
	"GhostTrain",
	"GhostSleeveL",
	"GhostSleeveR",
	"GhostStole",
}
---------------------------------------------------------------------------

local function srgb(c)
	local function f(v)
		return if v <= 0.0031308 then v * 12.92 else 1.055 * v ^ (1 / 2.4) - 0.055
	end
	return Color3.new(f(c[1]), f(c[2]), f(c[3]))
end

local function quiet(p)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

local function build(setName, set, import)
	local def = set.def
	local root = import:FindFirstChild("RootPart")
	if not root then
		-- a one-mesh import has no RootPart: the bones sit in the MeshPart. Make the Handle at
		-- the Root bone (the attachment point; the mesh's axes are the attachment's) and move
		-- the rig onto it.
		local bone = import:FindFirstChild("Root", true)
		assert(bone and bone:IsA("Bone") and bone.Parent:IsA("MeshPart"), `{setName}: import has no RootPart and no Root bone in a mesh`)
		local mesh = bone.Parent
		root = Instance.new("Part")
		root.CFrame = mesh.CFrame * CFrame.new(bone.CFrame.Position)
		bone.CFrame = root.CFrame:ToObjectSpace(mesh.CFrame * bone.CFrame)
		bone.Parent = root
		root.Parent = import
	end
	assert(root:FindFirstChild("Root"), `{setName}: import's RootPart has no Root bone`)
	local accessory = Instance.new("Accessory")
	accessory.Name = setName
	accessory.AccessoryType = def.type
	accessory:SetAttribute("SourceAsset", ASSETS[setName])

	local rootCf = root.CFrame
	local parts = {}
	for _, region in set.meshes do
		local name = `{setName}_{region}`
		local found = {}
		for _, d in import:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == name then
				table.insert(found, d)
			end
		end
		assert(#found == 1, `{setName}: expected one {name}, found {#found}`)
		parts[region] = { part = found[1], rel = rootCf:ToObjectSpace(found[1].CFrame) }
	end

	root.Name = "Handle"
	root.Size = Vector3.one * 0.2 -- bones keep their frames (they're relative to the part's CFrame)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.CastShadow = false
	quiet(root)
	local att = Instance.new("Attachment")
	att.Name = def.attachment
	att.Parent = root
	root.Parent = accessory

	for region, info in parts do
		local p = info.part
		for _, c in p:GetChildren() do
			if c:IsA("JointInstance") or c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		local color = srgb(LINEAR[region])
		local fades = FADES[region] == true
		p.CFrame = info.rel
		quiet(p)
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.CastShadow = not fades
		p.DoubleSided = false
		p:SetAttribute("Region", region)
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = if fades then FADE else SHADE
		sa.AlphaMode = if fades then Enum.AlphaMode.Transparency else Enum.AlphaMode.Overlay
		sa.Color = color
		sa.Parent = p
		local w = Instance.new("Weld")
		w.Name = "Weld"
		w.Part0, w.Part1 = root, p
		w.C0 = info.rel
		w.Parent = p
		p.Parent = accessory
	end
	return accessory
end

local rebuilt = {}
local recording = ChangeHistoryService:TryBeginRecording("Ghost cosmetics (skinned)")
local ok, err = pcall(function()
	local cosmetics = ReplicatedStorage:FindFirstChild("Cosmetics")
	if not cosmetics then -- a sandbox built before Cosmetics was mapped (never in a Rojo place)
		cosmetics = Instance.new("Folder")
		cosmetics.Name = "Cosmetics"
		cosmetics.Parent = ReplicatedStorage
	end
	local folder = cosmetics:FindFirstChild("Ghost")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Ghost"
		folder.Parent = cosmetics
	end
	local built, done = {}, {}
	for _, setName in ORDER do
		local imports = {}
		for _, c in workspace:GetChildren() do
			if c:IsA("Model") and c.Name == "_Import" .. setName then
				table.insert(imports, c)
			end
		end
		assert(#imports <= 1, `expected at most one Workspace._Import{setName}, found {#imports}`)
		if imports[1] then
			local link = imports[1]:FindFirstChildOfClass("PackageLink")
			if link then
				link:Destroy()
			end
			built[setName] = build(setName, SETS[setName], imports[1])
			table.insert(done, imports[1])
		else
			assert(folder:FindFirstChild(setName), `{setName}: no Workspace._Import{setName} and no existing template`)
		end
	end
	assert(next(built), "nothing to build: insert at least one _Import<Set>")
	for _, import in done do -- only once every set built, so a failure keeps the imports
		import:Destroy()
	end
	for _, setName in ORDER do
		if built[setName] then
			local existing = folder:FindFirstChild(setName)
			if existing then
				existing:Destroy()
			end
			built[setName].Parent = folder
		end
	end
	rebuilt = {}
	for _, setName in ORDER do
		if built[setName] then
			table.insert(rebuilt, setName)
		end
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return "rebuilt " .. table.concat(rebuilt, ", ")
