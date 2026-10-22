--!nocheck
-- Rigs ServerStorage._RosterBeasts.FrostSpider (build_frost_spider.luau) with rig_core.luau.
-- Run in Edit mode through execute_luau; re-runnable. See RIGS.md "Frost Spider".
-- HRP: the hit volume, 6 x 3 x 7 at (0, 2, 0.7) over the cephalothorax and abdomen
-- (bottom 0.5 above the ground; legs are not hit volume). The health bar sits 1 stud above the built model's top (computed).

local BASE = "http://127.0.0.1:8767/beasts/"
local model = game:GetService("ServerStorage")._RosterBeasts.FrostSpider
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
	target = "FrostSpider",
	hrpSize = Vector3.new(6, 3, 7),
	hrpPos = Vector3.new(0, 2.0, 0.7),
	barHeight = top + 1,
}) .. ("\ntop %.2f"):format(top)
