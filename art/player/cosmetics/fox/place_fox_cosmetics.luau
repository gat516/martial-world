--!nocheck
-- Spirit Fox ears and tails: turns the six imported skinned FBX models into
-- Accessory templates in ReplicatedStorage.Cosmetics.Fox. Run in Edit mode through the
-- Studio MCP (execute_luau, paste the file) after inserting each set's model asset
-- (ASSETS below, uploaded with tools/upload_asset.py model) into Workspace as
-- `_Import<Set>`. It rebuilds the accessory of every set that has an import
-- (the others keep their current template, so re-importing just the ears is
-- fine), removes the old part-built FoxEars / FoxTail prototypes and deletes the
-- import models. One
-- ChangeHistoryService recording, so Ctrl+Z undoes it.
--
-- What the importer gives: a Model with an invisible `RootPart` (the FBX origin,
-- which is the attachment point) holding the Bones (Root -> ...), the skinned
-- MeshParts Motor6D'd to it at their places, an AnimationController and an
-- InitialPoses folder. RootPart's frame is the attachment's Roblox frame already
-- (Blender (x, y, z) -> (-x, z, y): +X is the avatar's right, +Z its back), so
-- nothing is moved: RootPart becomes the Handle, the Motor6Ds become Welds.
--
-- Each accessory:
--   Accessory <Set>                AccessoryType Hat (ears) or Waist (tails)
--     Handle (Part)                invisible 0.2 cube at the attachment point
--       HatAttachment / WaistBackAttachment   identity
--       Bone Root -> ...           the rig (names as in the Blender armature)
--     <Set>_<Region> (MeshPart)    skinned; Weld to Handle; Color = region colour
--       SurfaceAppearance          ColorMap = fox_shade.png, Color = region colour
-- Recolour a region by setting both the MeshPart's Color and its
-- SurfaceAppearance.Color (the SurfaceAppearance shows over the part colour).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Uploaded model assets (tools/upload_asset.py model, 2026-10-23)
local ASSETS = {
	FoxTailPlume = 103142310298137,
	FoxTailCrescent = 91533908538003,
	FoxTailWisp = 95800596652636,
	FoxEarsSleek = 98916068347166,
	FoxEarsBroad = 124732163729948,
	FoxEarsLong = 115950384313807,
}
local SHADE = "rbxassetid://124559907609415" -- fox_shade.png (Studio MCP upload_image)

-- Region colours: the JSON's linear defaults, converted to sRGB below
local LINEAR = {
	FurOuter = { 0.80, 0.22, 0.055 },
	FurInner = { 0.93, 0.70, 0.60 },
	FurTip = { 0.95, 0.89, 0.78 },
}
local REGION = { -- mesh name suffix -> region
	Tail = "FurOuter",
	TailTip = "FurTip",
	LeftEar = "FurOuter",
	RightEar = "FurOuter",
	LeftEarInner = "FurInner",
	RightEarInner = "FurInner",
}
local SETS = {
	FoxTailPlume = { attachment = "WaistBackAttachment", meshes = { "Tail", "TailTip" } },
	FoxTailCrescent = { attachment = "WaistBackAttachment", meshes = { "Tail", "TailTip" } },
	FoxTailWisp = { attachment = "WaistBackAttachment", meshes = { "Tail", "TailTip" } },
	FoxEarsSleek = { attachment = "HatAttachment", meshes = { "LeftEar", "LeftEarInner", "RightEar", "RightEarInner" } },
	FoxEarsBroad = { attachment = "HatAttachment", meshes = { "LeftEar", "LeftEarInner", "RightEar", "RightEarInner" } },
	FoxEarsLong = { attachment = "HatAttachment", meshes = { "LeftEar", "LeftEarInner", "RightEar", "RightEarInner" } },
}
local ORDER = { "FoxTailPlume", "FoxTailCrescent", "FoxTailWisp", "FoxEarsSleek", "FoxEarsBroad", "FoxEarsLong" }
local OLD = { "FoxEars", "FoxTail" } -- part-built prototypes this replaces
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
	assert(root and root:FindFirstChild("Root"), `{setName}: import has no RootPart with the Root bone`)
	local accessory = Instance.new("Accessory")
	accessory.Name = setName
	accessory.AccessoryType = if def.attachment == "HatAttachment" then Enum.AccessoryType.Hat else Enum.AccessoryType.Waist
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
		local color = srgb(LINEAR[region])
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
local recording = ChangeHistoryService:TryBeginRecording("Fox cosmetics (skinned)")
local ok, err = pcall(function()
	local cosmetics = ReplicatedStorage:FindFirstChild("Cosmetics")
	local folder = cosmetics and cosmetics:FindFirstChild("Fox")
	assert(folder, "ReplicatedStorage.Cosmetics.Fox is missing")
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
			built[setName] = build(setName, SETS[setName], imports[1])
			imports[1]:Destroy()
		else
			assert(folder:FindFirstChild(setName), `{setName}: no Workspace._Import{setName} and no existing template`)
		end
	end
	assert(next(built), "nothing to build: insert at least one _Import<Set>")
	for _, name in OLD do
		local old = folder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
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
