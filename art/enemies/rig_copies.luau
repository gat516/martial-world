--!nocheck
-- Puts working copies of every roster template in Workspace._EnemyRigs, for the
-- animator: joints intact, only the HumanoidRootPart anchored, in rest pose, so the
-- Animation Editor (R6 for humanoids, Motor6D for beasts) can open them. The posed
-- previews (_RosterPreview*) are different: their motors are cut to hold a pose.
-- Re-run after a template changes; it replaces the whole folder. Run in Edit mode
-- through execute_luau. Tagged EditorOnly, so it's stripped at runtime.

local ROW_AT = CFrame.new(0, 400, 3060) -- off the map, behind the preview plates
local SPACING = 12
local SOURCES = {
	"_StagingEnemies", "_RosterWolves", "_RosterQuadrupeds", "_RosterBeasts", "_RosterBandits", "_RosterCultivators",
}

local ServerStorage = game:GetService("ServerStorage")

local old = workspace:FindFirstChild("_EnemyRigs")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "_EnemyRigs"
folder:AddTag("EditorOnly")

local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(400, 1, 30)
plate.Color = Color3.fromHex("6E7F5A")
plate.Parent = folder

local placed = {}
local x = 0
for _, source in SOURCES do
	local f = ServerStorage:FindFirstChild(source)
	if f then
		for _, template in f:GetChildren() do
			local hrp = template:IsA("Model") and template:FindFirstChild("HumanoidRootPart")
			if hrp then
				local copy = template:Clone()
				copy:PivotTo(ROW_AT * CFrame.new(x, hrp.Position.Y, 0))
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = d.Name == "HumanoidRootPart"
					end
				end
				copy.Parent = folder
				table.insert(placed, ("%s @x%d"):format(copy.Name, x))
				x += SPACING
			end
		end
	end
end
plate.CFrame = ROW_AT * CFrame.new(x / 2 - SPACING / 2, -0.5, 0)
plate.Size = Vector3.new(math.max(x, SPACING) + SPACING, 1, 30)
folder.Parent = workspace
return table.concat(placed, ", ")
