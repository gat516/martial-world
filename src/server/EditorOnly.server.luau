--!strict
-- Editor-only markers: planning blockouts, POI name labels and other inspection aids live
-- under Workspace._EditorMarkers (place-only) or carry the "EditorOnly" tag, so they show in
-- Studio Edit mode for reviewing the map. They are never part of the game: this runs before
-- any player can join (no requires, no yields) and destroys them, so nothing of them ever
-- replicates. ReplicatedFirst.EditorOnly (src/first/EditorOnly.client.luau) also strips any
-- copy that reaches a client. See docs/map/editor-markers.md.

local CollectionService = game:GetService("CollectionService")

local removed = 0
local markers = workspace:FindFirstChild("_EditorMarkers")
if markers then
	markers:Destroy()
	removed += 1
end
for _, inst in CollectionService:GetTagged("EditorOnly") do
	inst:Destroy()
	removed += 1
end
if removed > 0 then
	print(`EditorOnly: removed {removed} editor-only marker root(s) for runtime`)
end
