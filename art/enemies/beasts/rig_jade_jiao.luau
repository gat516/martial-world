--!nocheck
-- Rigs ServerStorage._RosterBeasts.JadeJiao (build_jade_jiao.luau) with the shared
-- rig_core.luau. Run in Edit mode through execute_luau; re-runnable. 37 joints: see
-- RIGS.md "Jade Jiao". HRP: the hit volume (7, 12, 14), bottom 0.5 above the ground.

local ServerStorage = game:GetService("ServerStorage")
local BASE = "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
-- health bar about 1 stud over the built body's top (computed from the unrigged parts)
local model = ServerStorage._RosterBeasts.JadeJiao
local top = -math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
		top = math.max(top, d.Position.Y + d.Size.Magnitude / 2 * 0.0 + math.abs(d.CFrame.UpVector.Y) * d.Size.Y / 2
			+ math.abs(d.CFrame.RightVector.Y) * d.Size.X / 2 + math.abs(d.CFrame.LookVector.Y) * d.Size.Z / 2)
	end
end
local K = 3.17 / 1.9 -- same lift as build_jade_jiao.luau
return rig({
	target = "JadeJiao",
	hrpSize = Vector3.new(7, 12, 14) * K,
	hrpPos = Vector3.new(0, 6.5, -1.5) * K,
	barHeight = top + 1,
}) .. ("\ntop %.2f"):format(top)
