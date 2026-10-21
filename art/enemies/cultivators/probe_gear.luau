--!nocheck
-- Maps the real surface of a catalog accessory mesh (SpecialMesh handles only ray-hit
-- their box), so hats, guans and ribbons can be seated on hair exactly. Builds a
-- MeshPart copy of the mesh (PreciseConvexDecomposition) over the accessory on the
-- Solo preview copy, raycasts it top-down and from behind, and prints the maps in
-- MODEL units (feet at Y 0, divided by the model's scale). Set MODEL and GEAR by gsub.
-- Run solo_cultivator.luau for MODEL first.
local MODEL = "OuterSectDisciple"
local GEAR = "Kate Hair"
local STEP = 0.2
local m = workspace._RosterPreviewCultivators.Solo[MODEL]
local s = m:GetScale()
local handle = m:FindFirstChild(GEAR).Handle
local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
local mp = game:GetService("AssetService"):CreateMeshPartAsync(mesh.MeshId,
	{ CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition })
mp.Size = mp.MeshSize * mesh.Scale
mp.CFrame = handle.CFrame * CFrame.new(mesh.Offset)
mp.Anchored = true
mp.Transparency = 1
mp.Parent = m.Parent
local base = m.HumanoidRootPart.Position - Vector3.new(0, 3 * s, 0)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { mp }
local rows = { "top-down Y (rows z, cols x -0.8..0.8):" }
for z = -0.8, 1.4, STEP do
	local line = string.format("z%5.1f:", z)
	for x = -0.8, 0.81, STEP do
		local r = workspace:Raycast(base + Vector3.new(x, 9, z) * s, Vector3.new(0, -8, 0) * s, rp)
		line ..= r and string.format(" %4.2f", (r.Position.Y - base.Y) / s) or "  -- "
	end
	table.insert(rows, line)
end
table.insert(rows, "from behind, Z of the back surface (rows y, cols x):")
for y = 6.4, 4.0, -STEP do
	local line = string.format("y%4.1f:", y)
	for x = -0.8, 0.81, STEP do
		local r = workspace:Raycast(base + Vector3.new(x, y, 4) * s, Vector3.new(0, 0, -6) * s, rp)
		line ..= r and string.format(" %4.2f", (r.Position.Z - base.Z) / s) or "  -- "
	end
	table.insert(rows, line)
end
mp:Destroy()
return table.concat(rows, "\n")
