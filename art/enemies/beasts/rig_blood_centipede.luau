--!nocheck
-- Rigs ServerStorage._RosterBeasts.BloodCentipede (build_blood_centipede.luau) with the
-- shared rig_core.luau, then adds the FX attachments. Run in Edit mode through
-- execute_luau; re-runnable. 43 joints: see RIGS.md "Blood Centipede".
-- HRP: the whole body line (skull to cerci) by the plates' width, from just above the
-- ground to the plate tops, centred on the line, so melee lands anywhere along it.
-- The health bar sits 1 stud over the built body's top (computed from the visible parts).

local ServerStorage = game:GetService("ServerStorage")
local BASE = "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
local model = ServerStorage._RosterBeasts.BloodCentipede

local function extent(p, axis)
	local cf, s = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector[axis]) * s.X + math.abs(cf.UpVector[axis]) * s.Y + math.abs(cf.LookVector[axis]) * s.Z
end
local top, minZ, maxZ = -math.huge, math.huge, -math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
		top = math.max(top, d.Position.Y + extent(d, "Y"))
		if not d.Name:match("^Jaw") and not d.Name:match("^Ant") then
			minZ = math.min(minZ, d.Position.Z - extent(d, "Z"))
		end
		maxZ = math.max(maxZ, d.Position.Z + extent(d, "Z"))
	end
end
local z0, z1 = math.floor(minZ * 10) / 10, math.ceil(maxZ * 10) / 10
local hrpSize = Vector3.new(3.2, 2.5, z1 - z0)
local hrpPos = Vector3.new(0, 1.3, (z0 + z1) / 2)
local msg = rig({
	target = "BloodCentipede",
	hrpSize = hrpSize,
	hrpPos = hrpPos,
	barHeight = top + 1,
})

-- FX attachments, placed in world (rest) space on their part
local function attach(partName, name, worldPos)
	local part = model:FindFirstChild(partName)
	assert(part, "no part " .. partName)
	local old = part:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = part.CFrame:PointToObjectSpace(worldPos)
	a.Parent = part
end
local skull = model.Skull
attach("Skull", "Mouth", Vector3.new(0, 1.0, skull.Position.Z - skull.Size.Z / 2 - 0.4))
attach("Seg3", "Core", Vector3.new(0, 1.5, model.Seg3.Position.Z))
attach("Seg6", "Seg6_FX", Vector3.new(0, 1.6, model.Seg6.Position.Z))
attach("Tail", "TailTip_FX", Vector3.new(0, 0.75, model.Tail.Position.Z + 2.4))
return msg .. ("\nHRP %s at %s, top %.2f, z %.1f..%.1f"):format(tostring(hrpSize), tostring(hrpPos), top, minZ, maxZ)
