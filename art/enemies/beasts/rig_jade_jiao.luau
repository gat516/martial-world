--!nocheck
-- Rigs ServerStorage._RosterBeasts.JadeJiao (build_jade_jiao.luau) with the shared
-- rig_core.luau. Run in Edit mode through execute_luau; re-runnable. 37 joints: see
-- rigs/jade-jiao.md ("Jade Jiao".
-- HRP: the reference's height band (bottom 0.5 x S above the ground, 3 x S tall, so the
-- root height stays 2 x S = 6.35), widened in X and Z to cover the coiled body's footprint
-- (Body and Tail parts) so melee lands on the coil; centred on x = 0 (the neck's plane).
-- The health bar sits 1 stud over the built body's top (computed from the visible parts).

local ServerStorage = game:GetService("ServerStorage")
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
local model = ServerStorage._RosterBeasts.JadeJiao
local S = model:GetAttribute("Scale")

local function extent(p, axis)
	local cf, s = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector[axis]) * s.X + math.abs(cf.UpVector[axis]) * s.Y + math.abs(cf.LookVector[axis]) * s.Z
end
local top, maxX, minZ, maxZ = -math.huge, 0, math.huge, -math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
		top = math.max(top, d.Position.Y + extent(d, "Y"))
		local seg = d:GetAttribute("Segment") or d.Name
		if seg == "Body" or seg:match("^Tail%d+$") then
			maxX = math.max(maxX, math.abs(d.Position.X) + extent(d, "X"))
			minZ = math.min(minZ, d.Position.Z - extent(d, "Z"))
			maxZ = math.max(maxZ, d.Position.Z + extent(d, "Z"))
		end
	end
end
-- round the footprint to a tenth so re-runs give identical numbers
local w = math.floor(maxX * 2 * 10 + 0.5) / 10
local z0, z1 = math.floor(minZ * 10) / 10, math.ceil(maxZ * 10) / 10
local hrpSize = Vector3.new(w, 3 * S, z1 - z0)
local hrpPos = Vector3.new(0, 2 * S, (z0 + z1) / 2)
return rig({
	target = "JadeJiao",
	hrpSize = hrpSize,
	hrpPos = hrpPos,
	barHeight = top + 1,
}) .. ("\nHRP %s at %s, top %.2f"):format(tostring(hrpSize), tostring(hrpPos), top)
