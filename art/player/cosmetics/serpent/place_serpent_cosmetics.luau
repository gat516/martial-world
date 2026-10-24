--!nocheck
-- Beast Folk (Serpent) fins and face plates: turns the six imported FBX models into Accessory
-- templates in ReplicatedStorage.Cosmetics.Serpent. Run in Edit mode in a SANDBOX (no Rojo)
-- through the Studio MCP (execute_luau, paste the file) after inserting each set's model asset
-- (ASSETS below, uploaded with tools/upload_asset.py model) into Workspace as `_Import<Set>`.
-- It creates the Serpent folder if it's missing, rebuilds the accessory of every set that has
-- an import (the others keep their current template) and deletes the import models. One
-- ChangeHistoryService recording, so Ctrl+Z undoes it. Then export the folder to
-- assets/Cosmetics/Serpent.rbxm (README.md). Adapted from the Demonic Human's.
--
-- What the importer gives:
--   fins (skinned): a Model with an invisible `RootPart` (the FBX origin = HatAttachment)
--     holding the Bones (Root -> FinLBase -> FinL -> FinLTip, and R), the MeshParts
--     Motor6D'd to it, an AnimationController and InitialPoses. RootPart becomes the Handle,
--     the Motor6Ds become Welds, nothing moves.
--   plates (rigid, no armature): a Model of four loose MeshParts and no RootPart. The
--     importer drops the model anywhere, so the attachment frame is recovered from each part
--     and its JSON `roblox_center` (PLATE_CENTERS); the parts must agree within 0.01 studs.
--     A fresh invisible 0.2 Handle sits at HatAttachment and the plates are welded to it.
--
-- Each accessory (AccessoryType Hat):
--   Accessory <Set>
--     Handle (Part)                invisible 0.2 cube at the attachment point
--       HatAttachment              identity
--       (fins) Bone Root -> ...    the rig (names as in the Blender armature)
--     <Set>_<Mesh> (MeshPart)      Weld to Handle; Region attribute; Color = region colour
--       SurfaceAppearance          ColorMap = the shade ramp, Color = region colour
--                                  (not on the Neon Seam, which must glow)
-- Recolour a region by setting both the MeshPart's Color and its SurfaceAppearance.Color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Uploaded model assets (tools/upload_asset.py model, 2026-10-23)
local ASSETS = {
	SerpentFinsVeil = 110117735613413,
	SerpentFinsSovereign = 73675592443421,
	SerpentFinsFang = 133891447016938,
	SerpentScalesVeil = 127532799973901,
	SerpentScalesSovereign = 137171599768106,
	SerpentScalesFang = 101289195663998,
}
-- serpent_shade.png is byte-identical to fox_shade.png: the shared ramp upload
local SHADE = "rbxassetid://124559907609415"

-- Region looks: each JSON's linear `colors` (the same for every set), converted to sRGB below
local REGIONS = {
	Scale = { color = { 0.014, 0.085, 0.072 }, material = Enum.Material.SmoothPlastic, transparency = 0, shade = true },
	Seam = { color = { 0.10, 0.95, 0.78 }, material = Enum.Material.Neon, transparency = 0, shade = false },
	FinWeb = { color = { 0.08, 0.55, 0.52 }, material = Enum.Material.SmoothPlastic, transparency = 0.35, shade = true },
	FinSpine = { color = { 0.80, 0.52, 0.16 }, material = Enum.Material.SmoothPlastic, transparency = 0, shade = true },
}
local REGION = { -- mesh name suffix -> region
	LeftFin = "FinWeb",
	RightFin = "FinWeb",
	LeftFinSpines = "FinSpine",
	RightFinSpines = "FinSpine",
	LeftScales = "Scale",
	RightScales = "Scale",
	LeftSeam = "Seam",
	RightSeam = "Seam",
}
-- BEGIN PLATE_CENTERS (each plate JSON's meshes.<name>.roblox_center, attachment space)
local PLATE_CENTERS = {
	SerpentScalesVeil_LeftScales = Vector3.new(-0.541, -0.44, -0.19),
	SerpentScalesVeil_LeftSeam = Vector3.new(-0.536, -0.437, -0.184),
	SerpentScalesVeil_RightScales = Vector3.new(0.541, -0.44, -0.19),
	SerpentScalesVeil_RightSeam = Vector3.new(0.536, -0.437, -0.184),
	SerpentScalesSovereign_LeftScales = Vector3.new(-0.54, -0.503, -0.139),
	SerpentScalesSovereign_LeftSeam = Vector3.new(-0.53, -0.475, -0.139),
	SerpentScalesSovereign_RightScales = Vector3.new(0.54, -0.503, -0.139),
	SerpentScalesSovereign_RightSeam = Vector3.new(0.53, -0.475, -0.139),
	SerpentScalesFang_LeftScales = Vector3.new(-0.543, -0.528, -0.091),
	SerpentScalesFang_LeftSeam = Vector3.new(-0.534, -0.502, -0.12),
	SerpentScalesFang_RightScales = Vector3.new(0.543, -0.528, -0.091),
	SerpentScalesFang_RightSeam = Vector3.new(0.534, -0.502, -0.12),
}
-- END PLATE_CENTERS
local FINS = { rig = true, meshes = { "LeftFin", "LeftFinSpines", "RightFin", "RightFinSpines" } }
local PLATES = { rig = false, meshes = { "LeftScales", "LeftSeam", "RightScales", "RightSeam" } }
local SETS = {
	SerpentFinsVeil = FINS,
	SerpentFinsSovereign = FINS,
	SerpentFinsFang = FINS,
	SerpentScalesVeil = PLATES,
	SerpentScalesSovereign = PLATES,
	SerpentScalesFang = PLATES,
}
local ORDER = { -- Sovereign is the Serpent's look (Variants/BeastFolk.luau)
	"SerpentFinsSovereign",
	"SerpentScalesSovereign",
	"SerpentFinsVeil",
	"SerpentScalesVeil",
	"SerpentFinsFang",
	"SerpentScalesFang",
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

local function findMesh(import, name)
	local found = {}
	for _, d in import:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == name then
			table.insert(found, d)
		end
	end
	assert(#found == 1, `expected one {name}, found {#found}`)
	return found[1]
end

local function build(setName, def, import)
	local accessory = Instance.new("Accessory")
	accessory.Name = setName
	accessory.AccessoryType = Enum.AccessoryType.Hat
	accessory:SetAttribute("SourceAsset", ASSETS[setName])

	local root, rootCf
	local parts = {}
	if def.rig then
		root = import:FindFirstChild("RootPart")
		assert(root, `{setName}: import has no RootPart`)
		assert(root:FindFirstChild("Root"), `{setName}: import has no Root bone on its RootPart`)
		rootCf = root.CFrame
		for _, suffix in def.meshes do
			local p = findMesh(import, `{setName}_{suffix}`)
			parts[suffix] = { part = p, rel = rootCf:ToObjectSpace(p.CFrame) }
		end
	else
		-- recover the attachment frame from the first plate, check the others against it
		for _, suffix in def.meshes do
			local name = `{setName}_{suffix}`
			local p = findMesh(import, name)
			local center = PLATE_CENTERS[name]
			assert(center, `{name}: no PLATE_CENTERS entry`)
			local origin = p.CFrame * CFrame.new(-center)
			if not rootCf then
				rootCf = origin
			else
				local d = (origin.Position - rootCf.Position).Magnitude
				assert(d < 0.01, `{name}: frame disagrees with the other plates by {d}`)
			end
			parts[suffix] = { part = p }
		end
		for _, info in parts do
			info.rel = rootCf:ToObjectSpace(info.part.CFrame)
		end
		root = Instance.new("Part")
	end

	root.Name = "Handle"
	root.Size = Vector3.one * 0.2 -- bones keep their frames (they're relative to the part's CFrame)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.CastShadow = false
	quiet(root)
	local att = Instance.new("Attachment")
	att.Name = "HatAttachment"
	att.Parent = root
	root.Parent = accessory

	for suffix, info in parts do
		local p = info.part
		for _, c in p:GetChildren() do
			if c:IsA("JointInstance") or c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		local region = REGION[suffix]
		local look = REGIONS[region]
		local color = srgb(look.color)
		p.CFrame = info.rel
		quiet(p)
		p.Material = look.material
		p.Color = color
		p.Transparency = look.transparency
		p.CastShadow = look.transparency == 0
		p.DoubleSided = false
		p:SetAttribute("Region", region)
		if look.shade then
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = SHADE
			sa.Color = color
			sa.Parent = p
		end
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
local recording = ChangeHistoryService:TryBeginRecording("Serpent cosmetics")
local ok, err = pcall(function()
	local cosmetics = ReplicatedStorage:FindFirstChild("Cosmetics")
	if not cosmetics then -- a sandbox built before Cosmetics was mapped (never in a Rojo place)
		cosmetics = Instance.new("Folder")
		cosmetics.Name = "Cosmetics"
		cosmetics.Parent = ReplicatedStorage
	end
	local folder = cosmetics:FindFirstChild("Serpent")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Serpent"
		folder.Parent = cosmetics
	end
	local built = {}
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
			imports[1]:Destroy()
		else
			assert(folder:FindFirstChild(setName), `{setName}: no Workspace._Import{setName} and no existing template`)
		end
	end
	assert(next(built), "nothing to build: insert at least one _Import<Set>")
	for _, setName in ORDER do
		if built[setName] then
			local existing = folder:FindFirstChild(setName)
			if existing then
				existing:Destroy()
			end
			built[setName].Parent = folder
			table.insert(rebuilt, setName)
		end
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return "rebuilt " .. table.concat(rebuilt, ", ")
