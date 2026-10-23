--!nocheck
-- Rigs ServerStorage._RosterBeasts.BloodBat (build_blood_bat.luau) with the shared
-- rig_core.luau, then adds the FX attachments. Run in Edit mode through execute_luau;
-- re-runnable. 13 joints: see rigs/blood-bat.md ("Blood Bat".
-- Flier convention as the Flame Raven's: the model is built in place at hover height, the
-- pivot is the HRP centre (not the ground) with identity rotation, and the HRP floats at
-- HipHeight = its bottom. HRP 2.6 x 2.4 x 2.6 centred at (0, 4.6, -0.2): bottom 3.4, so a
-- grounded player's melee box (root Y 3, 5 tall) overlaps it. The wings reach past it; hits
-- land on the body. Health bar 1 stud over the ear tips.

local ServerStorage = game:GetService("ServerStorage")
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/beasts/") or "http://127.0.0.1:8767/beasts/"
local rig = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "rig_core.luau?" .. os.clock()))()
local model = ServerStorage._RosterBeasts.BloodBat

local top = -math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
		local cf, s = d.CFrame, d.Size / 2
		local ext = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
		top = math.max(top, d.Position.Y + ext)
	end
end
local hrpSize, hrpPos = Vector3.new(2.6, 2.4, 2.6), Vector3.new(0, 4.6, -0.2)
local msg = rig({ target = "BloodBat", hrpSize = hrpSize, hrpPos = hrpPos, barHeight = top + 1 })

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
-- the outer tip of a wing's leading finger (the WingL3 / WingR3 bone, built along its -Z)
local function tip(name)
	local p = model[name]
	return (p.CFrame * CFrame.new(0, 0, -(p.Size.Z - 0.12) / 2)).Position
end
attach("Skull", "Mouth", Vector3.new(0, 4.6, -1.5)) -- in front of the snout, between the fangs
attach("Body", "Core", Vector3.new(0, 4.3, -0.77)) -- the front of the ChestCore
attach("WingL3", "WingTipL_FX", tip("WingL3"))
attach("WingR3", "WingTipR_FX", tip("WingR3"))
return msg .. ("\nHRP %s at %s, top %.2f"):format(tostring(hrpSize), tostring(hrpPos), top)
