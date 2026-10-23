--!nocheck
-- Stone Spirit plates, sleeves and floating shards: turns the nine imported skinned FBX
-- models into Accessory templates in ReplicatedStorage.Cosmetics.StoneSpirit. Run in Edit
-- mode in a SANDBOX (no Rojo) through the Studio MCP (execute_luau, paste the file, or serve
-- the worktree and loadstring it) after inserting each set's model asset (ASSETS below,
-- uploaded with tools/upload_asset.py model) into Workspace as `_Import<Set>`. It creates
-- the StoneSpirit folder if it's missing, rebuilds the accessory of every set that has an
-- import (the others keep their current template) and deletes the import models. One
-- ChangeHistoryService recording, so Ctrl+Z undoes it. Then export the folder to
-- assets/Cosmetics/StoneSpirit.rbxm (README.md). Adapted from the Dragonblood one.
--
-- What the importer gives: a Model with an invisible `RootPart` (the FBX origin, which is
-- the attachment point) holding the Bones (Root -> ...), the skinned MeshParts Motor6D'd
-- to it, an AnimationController and an InitialPoses folder. RootPart's frame is the
-- attachment's Roblox frame already (Blender (x, y, z) -> (-x, z, y)), and every R6 body
-- attachment these use is unrotated, so nothing moves: RootPart becomes the Handle, the
-- Motor6Ds become Welds.
--
-- Each accessory:
--   Accessory <Set>                  AccessoryType Shoulder (plates), Back (shards),
--                                    Unknown (bracers, gauntlets)
--     Handle (Part)                  invisible 0.2 cube at the attachment point
--       <Body>Attachment             identity, named like the R6 attachment it wears on
--       Bone Root -> ...             the rig (names as in the Blender armature)
--     <Set>_<Mesh> (MeshPart)        skinned; Weld to Handle; Region attribute
--       SurfaceAppearance            Rock only: ColorMap = the shade ramp, Color = rock
-- Rock is SmoothPlastic with the ramp; recolour it by setting both the MeshPart's Color and
-- its SurfaceAppearance.Color. Jade is plain Neon with no SurfaceAppearance (one would
-- replace the Neon glow); recolour it with the MeshPart's Color alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Uploaded model assets (tools/upload_asset.py model, 2026-10-23)
local ASSETS = {
	StonePeakPlateL = 92669054322581,
	StonePeakPlateR = 97682972584791,
	StonePeakShards = 74609701843949,
	StoneOrbitShards = 106334816334151,
	StoneOrbitBracerL = 83150393363152,
	StoneOrbitBracerR = 132340835437575,
	StoneFistGauntletL = 70562460080742,
	StoneFistGauntletR = 95537660485688,
	StoneFistShards = 138619509712287,
}
-- stone_shade.png (Studio MCP upload_image, 2026-10-23)
local SHADE = "rbxassetid://89749165133866"

-- Region colours: the JSONs' linear `colors`, converted to sRGB below. Jade is Neon, which
-- brightens and pushes the converted green (0.22, 0.95, 0.68) to cyan in game, so it uses
-- its own sRGB colour picked against the sandbox render to read jade green.
local COLORS = { Rock = { 0.075, 0.08, 0.088 } }
local JADE_NEON = Color3.new(0.1, 0.75, 0.3)
local MATERIAL = { Rock = Enum.Material.SmoothPlastic, Jade = Enum.Material.Neon }

local function plate(attachment)
	return { attachment = attachment, type = Enum.AccessoryType.Shoulder, meshes = { Rock = "Rock", Jade = "Jade", Chip1 = "Rock", Chip2 = "Rock" } }
end
local function sleeve(attachment, chip)
	local meshes = { Rock = "Rock", Jade = "Jade" }
	if chip then
		meshes.Chip1 = "Rock"
	end
	return { attachment = attachment, type = Enum.AccessoryType.Unknown, meshes = meshes }
end
local function shards(n)
	local meshes = {}
	for i = 1, n do
		meshes[`Shard{i}`] = "Rock"
		meshes[`Shard{i}Jade`] = "Jade"
	end
	return { attachment = "NeckAttachment", type = Enum.AccessoryType.Back, meshes = meshes }
end
local SETS = {
	StonePeakPlateL = plate("LeftShoulderAttachment"),
	StonePeakPlateR = plate("RightShoulderAttachment"),
	StonePeakShards = shards(5),
	StoneOrbitShards = shards(6),
	StoneOrbitBracerL = sleeve("LeftGripAttachment", false),
	StoneOrbitBracerR = sleeve("RightGripAttachment", false),
	StoneFistGauntletL = sleeve("LeftGripAttachment", true),
	StoneFistGauntletR = sleeve("RightGripAttachment", true),
	StoneFistShards = shards(3),
}
local ORDER = { -- Peak (default), Orbit, Fist
	"StonePeakPlateL",
	"StonePeakPlateR",
	"StonePeakShards",
	"StoneOrbitShards",
	"StoneOrbitBracerL",
	"StoneOrbitBracerR",
	"StoneFistGauntletL",
	"StoneFistGauntletR",
	"StoneFistShards",
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

local function build(setName, def, import)
	local root = import:FindFirstChild("RootPart")
	assert(root, `{setName}: import has no RootPart`)
	assert(root:FindFirstChild("Root"), `{setName}: import has no Root bone on its RootPart`)
	local accessory = Instance.new("Accessory")
	accessory.Name = setName
	accessory.AccessoryType = def.type
	accessory:SetAttribute("SourceAsset", ASSETS[setName])

	local rootCf = root.CFrame
	local parts = {}
	local count = 0
	for suffix in def.meshes do
		local name = `{setName}_{suffix}`
		local found = {}
		for _, d in import:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == name then
				table.insert(found, d)
			end
		end
		assert(#found == 1, `{setName}: expected one {name}, found {#found}`)
		parts[suffix] = { part = found[1], rel = rootCf:ToObjectSpace(found[1].CFrame) }
		count += 1
	end
	local total = 0
	for _, d in import:GetDescendants() do
		if d:IsA("MeshPart") then
			total += 1
		end
	end
	assert(total == count, `{setName}: import has {total} MeshParts, expected {count}`)

	root.Name = "Handle"
	root.Size = Vector3.one * 0.2 -- bones keep their frames (they're relative to the part's CFrame)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.CastShadow = false
	quiet(root)
	for _, c in root:GetChildren() do
		if c:IsA("Attachment") and not c:IsA("Bone") then
			c:Destroy()
		end
	end
	local att = Instance.new("Attachment")
	att.Name = def.attachment
	att.Parent = root
	root.Parent = accessory

	for suffix, info in parts do
		local p = info.part
		for _, c in p:GetChildren() do
			if c:IsA("JointInstance") or c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		local region = def.meshes[suffix]
		local color = if region == "Jade" then JADE_NEON else srgb(COLORS[region])
		p.CFrame = info.rel
		quiet(p)
		p.Material = MATERIAL[region]
		p.Color = color
		p.CastShadow = region == "Rock"
		p.DoubleSided = false
		p:SetAttribute("Region", region)
		if region == "Rock" then
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
local recording = ChangeHistoryService:TryBeginRecording("Stone Spirit cosmetics (skinned)")
local ok, err = pcall(function()
	local cosmetics = ReplicatedStorage:FindFirstChild("Cosmetics")
	if not cosmetics then -- a sandbox built before Cosmetics was mapped (never in a Rojo place)
		cosmetics = Instance.new("Folder")
		cosmetics.Name = "Cosmetics"
		cosmetics.Parent = ReplicatedStorage
	end
	local folder = cosmetics:FindFirstChild("StoneSpirit")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "StoneSpirit"
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
