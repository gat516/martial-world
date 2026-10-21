--!nocheck
-- Capture helper: drops every preview model except the ones named in _G.RosterSolo
-- (a set of labels) 60 studs under the plate, so side views along the lineup are clear.
-- Re-run preview_beasts.luau to restore the lineup.
local keep = _G.RosterSolo or {}
local preview = workspace._RosterPreviewBeasts
local moved = {}
for _, c in preview:GetChildren() do
	if c:IsA("Model") and not keep[c.Name] then
		c:PivotTo(c:GetPivot() + Vector3.new(0, -60, 0))
		table.insert(moved, c.Name)
	end
end
return "moved " .. table.concat(moved, ",")
