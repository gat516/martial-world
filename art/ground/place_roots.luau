--[[
Places the peak roots (art/ground/build_roots.py -> PeakRoots.fbx) after the manual FBX import.
Run in Studio Edit mode (MCP execute_luau); re-runnable (rebuilds Map.Ground.PeakRoots from the template).

  1. Finds the imported MeshParts PeakRoot, PeakRootFoot, MainRoot, MainRootFoot (each exactly once, anywhere under
     Workspace outside Map), styles them and keeps them as the template ServerStorage.PeakRootsKit, then deletes the
     import container. Without a fresh import it reuses the kit.
  2. Clones PeakRoot + PeakRootFoot onto all eight spirit peaks (in each peak's frame: Plateau x, z at y 0, looking
     outward, the frame build_peak_pillar.py and build_roots.py use) and MainRoot + MainRootFoot at world (2, 0, 2).
Roots are non-colliding (CanQuery off); the *Foot hulls are invisible colliders for the bottom ~40 studs.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

-- BEGIN MESHES (PeakRoots.json: centre and size in Blender axes)
local MESHES = {
	PeakRoot = { center = Vector3.new(-14.484, 3.833, 54.0), size = Vector3.new(215.084, 230.23, 152.0) },
	PeakRootFoot = { center = Vector3.new(-14.484, 3.833, 6.0), size = Vector3.new(215.084, 230.23, 56.0) },
	MainRoot = { center = Vector3.new(0.292, 4.849, 42.0), size = Vector3.new(475.433, 471.775, 128.0) },
	MainRootFoot = { center = Vector3.new(0.292, 4.849, 6.0), size = Vector3.new(475.433, 471.775, 56.0) },
}
-- END MESHES

local ROCK = Color3.fromHex("5E5A56") -- a step darker than the pillars' base rock (#615D59): the foot is in shade

-- Blender (x, y, z) -> Studio, relative to the pivot (the modeler's FBX rule)
local function offset(name: string): CFrame
	local m = MESHES[name]
	return CFrame.Angles(0, math.pi, 0) * CFrame.new(-m.center.X, m.center.Z, m.center.Y)
end
local function size(name: string): Vector3
	local s = MESHES[name].size
	return Vector3.new(s.X, s.Z, s.Y)
end

local function style(part: MeshPart, name: string)
	part.Name = name
	part.Anchored = true
	part.Size = size(name)
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = ROCK
	if string.sub(name, -4) == "Foot" then
		part.Transparency = 1
		part.CanCollide = true
		part.CanQuery = true
		part.CastShadow = false
		part.CollisionFidelity = Enum.CollisionFidelity.Hull
	else
		part.Transparency = 0
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = true
		part.CollisionFidelity = Enum.CollisionFidelity.Box
	end
end

local recording = ChangeHistoryService:TryBeginRecording("PlaceRoots")

-- 1. import -> kit
local found: { [string]: { MeshPart } } = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") and MESHES[d.Name] and not d:IsDescendantOf(workspace.Map) then
		found[d.Name] = found[d.Name] or {}
		table.insert(found[d.Name], d)
	end
end
local kit = ServerStorage:FindFirstChild("PeakRootsKit")
if next(found) then
	for name in MESHES do
		local list = found[name]
		assert(list and #list == 1, `PeakRoots import: expected one {name}, found {list and #list or 0}`)
	end
	local containers = {}
	if kit then
		kit:Destroy()
	end
	kit = Instance.new("Folder")
	kit.Name = "PeakRootsKit"
	for name, list in found do
		local part = list[1]
		local top = part
		while top.Parent ~= workspace do
			top = top.Parent :: Instance
		end
		if top ~= part then
			containers[top] = true
		end
		style(part, name)
		part.Parent = kit
	end
	kit.Parent = ServerStorage
	for c in containers do
		c:Destroy()
	end
end
assert(kit, "no PeakRoots import in Workspace and no ServerStorage.PeakRootsKit: import art/fbx_export/PeakRoots.fbx first")

-- 2. place
local ground = workspace.Map.Ground
local old = ground:FindFirstChild("PeakRoots")
if old then
	old:Destroy()
end
local roots = Instance.new("Folder")
roots.Name = "PeakRoots"

local function place(names: { string }, pivot: CFrame, modelName: string)
	local model = Instance.new("Model")
	model.Name = modelName
	for _, name in names do
		local part = (kit :: Instance):FindFirstChild(name):Clone() :: MeshPart
		part.CFrame = pivot * offset(name)
		part.Parent = model
	end
	model.WorldPivot = pivot
	model.Parent = roots
end

for _, peak in workspace.Map.Sect.SpiritPeaks:GetChildren() do
	local plateau = peak:FindFirstChild("Plateau") :: BasePart?
	if plateau then
		local c = Vector3.new(plateau.Position.X, 0, plateau.Position.Z)
		place({ "PeakRoot", "PeakRootFoot" }, CFrame.lookAt(c, c + c.Unit), peak.Name)
	end
end
place({ "MainRoot", "MainRootFoot" }, CFrame.new(2, 0, 2), "MainPeak")
roots.Parent = ground

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return `placed {#roots:GetChildren()} roots`
