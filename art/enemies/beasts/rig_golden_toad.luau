--!nocheck
-- Rigs ServerStorage._RosterBeasts.GoldenToad (build_golden_toad.luau) with rig_core.luau.
-- Run in Edit mode through execute_luau; re-runnable. See RIGS.md "Golden Toad".
-- HRP: the hit volume, grown to the body's bounds (5 x 4 x 8.4, centre y 2.3, bottom 0.3
-- above the ground). The health bar sits 1 stud above the built model's top (computed).

local BASE = "http://127.0.0.1:8767/beasts/"
local model = game:GetService("ServerStorage")._RosterBeasts.GoldenToad
local top = 0
for _, p in model:GetDescendants() do
	if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
		local h = p.Size / 2
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			top = math.max(top, p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)).Y)
		end end end
	end
end
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
return rig({
	target = "GoldenToad",
	hrpSize = Vector3.new(5, 4, 8.4),
	hrpPos = Vector3.new(0, 2.3, 0),
	barHeight = top + 1,
}) .. ("\ntop %.2f"):format(top)
