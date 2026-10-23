--!nocheck
-- Dragonblood horns and tails: turns the six imported skinned FBX models into Accessory
-- templates in ReplicatedStorage.Cosmetics.Dragonblood. Run in Edit mode in a SANDBOX (no
-- Rojo) through the Studio MCP (execute_luau, paste the file) after inserting each set's
-- model asset (ASSETS below, uploaded with tools/upload_asset.py model) into Workspace as
-- `_Import<Set>`. It creates the Dragonblood folder if it's missing, rebuilds the accessory
-- of every set that has an import (the others keep their current template) and deletes the
-- import models. One ChangeHistoryService recording, so Ctrl+Z undoes it. Then export the
-- folder to assets/Cosmetics/Dragonblood.rbxm (README.md). Adapted from the tiger's.
--
-- What the importer gives: a Model with an invisible `RootPart` (the FBX origin, which is
-- the attachment point) holding the Bones (Root -> ...), the skinned MeshParts Motor6D'd
-- to it, an AnimationController and an InitialPoses folder. RootPart's frame is the
-- attachment's Roblox frame already (Blender (x, y, z) -> (-x, z, y)), so nothing moves:
-- RootPart becomes the Handle, the Motor6Ds become Welds.
--
-- Each accessory:
--   Accessory <Set>                AccessoryType Hat (horns) or Waist (tail)
--     Handle (Part)                invisible 0.2 cube at the attachment point
--       HatAttachment / WaistBackAttachment   identity
--       Bone Root -> ...           the rig (names as in the Blender armature)
--     <Set>_<Mesh> (MeshPart)      skinned; Weld to Handle; Color = region colour
--       SurfaceAppearance          ColorMap = the shade ramp, Color = region colour
-- Recolour a region by setting both the MeshPart's Color and its
-- SurfaceAppearance.Color (the SurfaceAppearance shows over the part colour).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Uploaded model assets (tools/upload_asset.py model, 2026-10-23)
local ASSETS = {
	DragonHornsAntler = 118059820164717,
	DragonTailTuft = 103414032997884,
	DragonHornsCelestial = 81657172073477,
	DragonTailRising = 95287185628849,
	DragonHornsCub = 89450489379839,
	DragonTailStub = 109732643027806,
}
-- dragon_shade.png (Studio MCP upload_image, 2026-10-23)
local SHADE = "rbxassetid://113054218156121"

-- Region colours per set: each JSON's linear `colors`, converted to sRGB below
local IVORY_GOLD = { Horn = { 0.855, 0.776, 0.604 }, HornTip = { 0.672, 0.402, 0.077 } }
local JADE_GOLD = { Horn = { 0.36, 0.52, 0.36 }, HornTip = { 0.75, 0.48, 0.10 } }
local TAIL_COLORS = { Scales = { 0.04, 0.16, 0.085 }, Ridge = { 0.83, 0.75, 0.58 }, Tuft = { 0.88, 0.84, 0.73 } }
local COLORS = {
	DragonHornsAntler = IVORY_GOLD,
	DragonHornsCelestial = JADE_GOLD,
	DragonHornsCub = IVORY_GOLD,
	DragonTailTuft = TAIL_COLORS,
	DragonTailRising = TAIL_COLORS,
	DragonTailStub = TAIL_COLORS,
}
local REGION = { -- mesh name suffix -> region
	LeftHorn = "Horn",
	RightHorn = "Horn",
	LeftHornTip = "HornTip",
	RightHornTip = "HornTip",
	Tail = "Scales",
	TailRidge = "Ridge",
	TailTuft = "Tuft",
}
local HORNS = { attachment = "HatAttachment", type = Enum.AccessoryType.Hat, meshes = { "LeftHorn", "LeftHornTip", "RightHorn", "RightHornTip" } }
local TAIL = { attachment = "WaistBackAttachment", type = Enum.AccessoryType.Waist, meshes = { "Tail", "TailRidge", "TailTuft" } }
local SETS = {
	DragonHornsAntler = HORNS,
	DragonTailTuft = TAIL,
	DragonHornsCelestial = HORNS,
	DragonTailRising = TAIL,
	DragonHornsCub = HORNS,
	DragonTailStub = TAIL,
}
local ORDER = { -- A (Antler, worn), B (Celestial), C (Cub)
	"DragonHornsAntler",
	"DragonTailTuft",
	"DragonHornsCelestial",
	"DragonTailRising",
	"DragonHornsCub",
	"DragonTailStub",
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
	for _, suffix in def.meshes do
		local name = `{setName}_{suffix}`
		local found = {}
		for _, d in import:GetDescendants() do
			if d:IsA("MeshPart") and d.Name == name then
				table.insert(found, d)
			end
		end
		assert(#found == 1, `{setName}: expected one {name}, found {#found}`)
		parts[suffix] = { part = found[1], rel = rootCf:ToObjectSpace(found[1].CFrame) }
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

	for suffix, info in parts do
		local p = info.part
		for _, c in p:GetChildren() do
			if c:IsA("JointInstance") or c:IsA("SurfaceAppearance") then
				c:Destroy()
			end
		end
		local region = REGION[suffix]
		local color = srgb(COLORS[setName][region])
		p.CFrame = info.rel
		quiet(p)
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.CastShadow = true
		p.DoubleSided = false
		p:SetAttribute("Region", region)
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = SHADE
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
local recording = ChangeHistoryService:TryBeginRecording("Dragonblood cosmetics (skinned)")
local ok, err = pcall(function()
	local cosmetics = ReplicatedStorage:FindFirstChild("Cosmetics")
	if not cosmetics then -- a sandbox built before Cosmetics was mapped (never in a Rojo place)
		cosmetics = Instance.new("Folder")
		cosmetics.Name = "Cosmetics"
		cosmetics.Parent = ReplicatedStorage
	end
	local folder = cosmetics:FindFirstChild("Dragonblood")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Dragonblood"
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
