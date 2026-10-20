--!nocheck
-- Lists siblings that share a Name and ClassName in the Rojo-mapped assets
-- (default.project.json). Run it through the Studio MCP's execute_luau in Edit
-- after writing any .rbxmx: Rojo's live sync adds instances from the file next to
-- hand-made copies instead of replacing them, and scripts then find the wrong
-- one with FindFirstChild. Returns "clean" or one line per duplicate set.

-- Scanned all the way down: every name in these is looked up by scripts.
local DEEP = { "StarterGui.Hud", "ReplicatedStorage.Remotes", "ReplicatedStorage.Animations", "ReplicatedStorage.Ambience", "ReplicatedStorage.BuildKit" }
-- World geometry and templates repeat names on purpose; only the root and its
-- direct children are checked.
local SHALLOW = { "Workspace.Wilds", "Workspace.Hub", "ServerStorage.Enemies", "ServerStorage.PeakTiers", "ServerStorage.ItemTemplates" }

local found = {}

local function check(parent: Instance, deep: boolean)
	local seen = {}
	for _, child in parent:GetChildren() do
		local key = `{child.ClassName} "{child.Name}"`
		seen[key] = (seen[key] or 0) + 1
		if seen[key] == 2 then
			table.insert(found, `{parent:GetFullName()}: {key}`)
		end
		if deep then
			check(child, true)
		end
	end
end

local function checkRoot(path: string, deep: boolean)
	local service, name = path:match("^(%w+)%.(%w+)$")
	local parent = game:GetService(service)
	local copies = 0
	for _, child in parent:GetChildren() do
		if child.Name == name then
			copies += 1
			check(child, deep)
		end
	end
	if copies ~= 1 then
		table.insert(found, `{path}: {copies} copies`)
	end
end

for _, path in DEEP do
	checkRoot(path, true)
end
for _, path in SHALLOW do
	checkRoot(path, false)
end

return if #found == 0 then "clean" else table.concat(found, "\n")
