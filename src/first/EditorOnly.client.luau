--!strict
-- Client side of the editor-only markers (Workspace._EditorMarkers, tag "EditorOnly"; see
-- src/server/EditorOnly.server.luau and docs/map/editor-markers.md).
-- The server destroys them at startup, but in a Studio playtest the client can receive the
-- place before that destroy arrives (a playtest showed the blockout labels). This runs in
-- ReplicatedFirst, before the rest of the game loads, and removes any copy that reaches the
-- client, including one that replicates in later.

local CollectionService = game:GetService("CollectionService")

local function strip(inst: Instance)
	if inst.Name == "_EditorMarkers" and inst.Parent == workspace then
		inst:Destroy()
	end
end

for _, child in workspace:GetChildren() do
	strip(child)
end
workspace.ChildAdded:Connect(strip)

for _, inst in CollectionService:GetTagged("EditorOnly") do
	inst:Destroy()
end
CollectionService:GetInstanceAddedSignal("EditorOnly"):Connect(function(inst)
	inst:Destroy()
end)
