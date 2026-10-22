--!nocheck
-- Promotes the rigged ServerStorage._RosterQuadrupeds.NineTailFoxB (build + rig scripts) to the
-- testbed-only NineTailFoxB template. Run in a FRESH sandbox (so ServerStorage.Enemies is the
-- current assets/Enemies.rbxm), after the build and rig scripts. It clones Enemies into the
-- unmapped _StagingFoxEnemies with the new model added; export that with tools/export_rbxm.luau
-- (rootName "Enemies") to assets/Enemies.rbxm, then destroy the staging copy. The HRP is the
-- PrimaryPart at (0, 2.6 * Scale, 0) with identity rotation (EnemyService's root height).
local ServerStorage = game:GetService("ServerStorage")
local source = assert(ServerStorage._RosterQuadrupeds:FindFirstChild("NineTailFoxB"), "build and rig first")
local enemies = assert(ServerStorage:FindFirstChild("Enemies"), "missing Enemies")
assert(not ServerStorage:FindFirstChild("_StagingFoxEnemies"), "staging already exists")
assert(not enemies:FindFirstChild("NineTailFoxB"), "NineTailFoxB already shipped; inspect before replacing")
local staging = enemies:Clone()
staging.Name = "_StagingFoxEnemies"
local model = source:Clone()
model.Parent = staging
staging.Parent = ServerStorage
return ("staged NineTailFoxB (Scale %s) in ServerStorage._StagingFoxEnemies with %d other templates"):format(
	tostring(model:GetAttribute("Scale")), #staging:GetChildren() - 1)
