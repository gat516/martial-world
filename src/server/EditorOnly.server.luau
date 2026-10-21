--!strict
-- Editor-only markers: planning blockouts, POI name labels and other inspection aids live
-- under Workspace._EditorMarkers (place-only) or carry the "EditorOnly" tag, so they show in
-- Studio Edit mode for reviewing the map. They are never part of the game: this runs before
-- any player can join (no requires, no yields) and destroys them, so nothing of them ever
-- replicates. See docs/systems/map.md, "Editor-only markers".

local CollectionService = game:GetService("CollectionService")

local markers = workspace:FindFirstChild("_EditorMarkers")
if markers then
	markers:Destroy()
end
for _, inst in CollectionService:GetTagged("EditorOnly") do
	inst:Destroy()
end
