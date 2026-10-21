--[[
Dresses the under-sect floor (art/ground/terrain_ground.luau) with library rocks on its three knolls.
Run in Studio Edit mode (MCP execute_luau) after the terrain; re-runnable (rebuilds Map.Ground.SectRoots.Knolls).

Each knoll gets an odd cluster, big + medium + small, from ServerStorage.AssetLibrary["Stylized Rock Packs"]
(clones; the library stays untouched), seated on the terrain and sunk a little so they grow out of the ground.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local LIB = game.ServerStorage.AssetLibrary["Stylized Rock Packs"]
local CLIFF = LIB["Stylized Cliff Rock Pack I"]
local FANTASY = LIB["Stylized Fantasy Rocks"]

-- { pack, rock name, x, z, scale, yaw (deg), sink }
local ROCKS = {
	-- east of the path before the slot (knoll at 46, 338)
	{ CLIFF, "Stylized Cliff Rock I", 48, 336, 1.5, 20, 3 },
	{ FANTASY, "Stylized Rock III", 61, 322, 1.0, 140, 2 },
	{ FANTASY, "Stylized Rock I", 33, 357, 0.7, 260, 1.5 },
	-- under Peak_8's west side (knoll at -214, 268)
	{ CLIFF, "Stylized Cliff Rock II", -216, 266, 1.6, 75, 3 },
	{ CLIFF, "Stylized Cliff Rock III", -199, 287, 1.1, 200, 2 },
	{ FANTASY, "Stylized Rock V", -232, 249, 0.8, 310, 1.5 },
	-- between Peak_5 and Peak_6 (knoll at -268, -213)
	{ FANTASY, "Stylized Rock IV", -268, -212, 1.7, 35, 3 },
	{ CLIFF, "Stylized Cliff Rock III", -250, -230, 1.2, 170, 2 },
	{ FANTASY, "Stylized Rock II", -284, -195, 0.8, 290, 1.5 },
}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function lowestGround(x: number, z: number, r: number): number
	local low = math.huge
	for _, o in { Vector2.zero, Vector2.new(r, 0), Vector2.new(-r, 0), Vector2.new(0, r), Vector2.new(0, -r) } do
		local hit = workspace:Raycast(Vector3.new(x + o.X, 200, z + o.Y), Vector3.new(0, -400, 0), terrainOnly)
		low = math.min(low, if hit then hit.Position.Y else 0)
	end
	return low
end

local recording = ChangeHistoryService:TryBeginRecording("DressSectRoots")
local ground = workspace.Map.Ground
local root = ground:FindFirstChild("SectRoots") or Instance.new("Folder")
root.Name = "SectRoots"
root.Parent = ground
local old = root:FindFirstChild("Knolls")
if old then
	old:Destroy()
end
local knolls = Instance.new("Model")
knolls.Name = "Knolls"

for _, r in ROCKS do
	local src = r[1]:FindFirstChild(r[2])
	assert(src, `missing library rock {r[2]}`)
	local rock = src:Clone()
	if rock:IsA("Model") then
		rock:ScaleTo(r[5])
	end
	for _, d in rock:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CastShadow = true
			d.CanTouch = false
		end
	end
	local _, size = rock:GetBoundingBox()
	local gy = lowestGround(r[3], r[4], math.min(size.X, size.Z) * 0.3)
	rock:PivotTo(CFrame.new(r[3], 0, r[4]) * CFrame.Angles(0, math.rad(r[6]), 0))
	local cf, sz = rock:GetBoundingBox()
	rock:PivotTo(rock:GetPivot() + Vector3.new(0, gy - r[7] - (cf.Y - sz.Y / 2), 0))
	rock.Parent = knolls
end
knolls.Parent = root

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return `placed {#knolls:GetChildren()} rocks`
