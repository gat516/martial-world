--!nocheck
-- Rigs ServerStorage._RosterQuadrupeds.NineTailFoxB (build_nine_tail_fox_boss.luau) with
-- rig_lib.luau, then adds the boss extras: ExtendAxis / ExtendMax attributes on the
-- telescoping tail motors, the FX attachments, the Scale attribute and the tag-free template
-- contract (identity-pivot, Atomic streaming). Legacy names kept: JointRoot, JointHead,
-- JointTail (root of the whole fan), JointLeg*. Tail i (1 far left .. 9 far right):
-- JointTail<i> (Tail > Tail<i>), JointTail<i>Mid, JointTail<i>Tip, JointTail<i>Whip.
-- A telescoping motor's pivot is the point on the child at its parent's mouth at rest.
-- Re-runnable. RIGS.md has the tables and safe ranges.

local BASE = "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local rig = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/rig_lib.luau?" .. os.clock()))()
local TAIL = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/nine_tail_fox_boss_tails.luau?" .. os.clock()))()
local lay = TAIL.layout()

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

local joints = {
	{ "JointRoot", "HumanoidRootPart", "Hips", v(0, 6.5, 2.2) },
	{ "JointChest", "Hips", "Chest", v(0, 6.5, 1.0) },
	{ "JointNeck", "Chest", "Neck", v(0, 7.2, -3.4) },
	{ "JointHead", "Neck", "Head", v(0, 8.6, -5.2) },
	{ "JointJaw", "Head", "Jaw", v(0, 8.1, -6.6) },
	{ "JointEarL", "Head", "EarL", v(-0.95, 9.95, -5.8) },
	{ "JointEarR", "Head", "EarR", v(0.95, 9.95, -5.8) },
	{ "JointTail", "Hips", "Tail", v(0, 7.7, 4.8) },
}
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local x = s * 1.1
	table.insert(joints, { "JointLegF" .. side, "Chest", "UpperLegF" .. side, v(x, 6.3, -3.0) })
	table.insert(joints, { "JointLowerLegF" .. side, "UpperLegF" .. side, "LowerLegF" .. side, v(x, 3.7, -3.0) })
	table.insert(joints, { "JointPawF" .. side, "LowerLegF" .. side, "PawF" .. side, v(x, 0.8, -3.0) })
	x = s * 1.15
	table.insert(joints, { "JointLegB" .. side, "Hips", "UpperLegB" .. side, v(x, 6.8, 3.8) })
	table.insert(joints, { "JointLowerLegB" .. side, "UpperLegB" .. side, "LowerLegB" .. side, v(x, 3.7, 3.4) })
	table.insert(joints, { "JointPawB" .. side, "LowerLegB" .. side, "PawB" .. side, v(x, 1.6, 4.5) })
end
local ext = {} -- [motor name] = { axis, max }
for i = 1, 9 do
	local d = TAIL.dir(i)
	local function at(s)
		return TAIL.root + d * s
	end
	local n = "Tail" .. i
	table.insert(joints, { "Joint" .. n, "Tail", n, at(0) })
	table.insert(joints, { "Joint" .. n .. "Mid", n, n .. "Mid", at(lay.baseE) })
	table.insert(joints, { "Joint" .. n .. "Tip", n .. "Mid", n .. "Tip", at(lay.midE) })
	table.insert(joints, { "Joint" .. n .. "Whip", n .. "Tip", n .. "Whip", at(lay.tipE) })
	ext["Joint" .. n .. "Mid"] = { d, lay.extMid }
	ext["Joint" .. n .. "Tip"] = { d, lay.extTip }
	ext["Joint" .. n .. "Whip"] = { d, lay.extWhip }
end

-- The build script's coordinates are authored at 2.4x the pose module's unit space; the final
-- body is SCALE x unit space (2.13 matches the user's NineTailFox_R reference row), reached by
-- one ScaleTo of K = SCALE / 2.4 after rigging (it scales C0/C1, welds, attachments and sizes).
local SCALE = 2.13
local K = SCALE / 2.4
local HRP_Y = 2.6 * 2.4 -- authored root height; rescaled below (final = 2.6 * SCALE)
local result = rig({
	folder = "_RosterQuadrupeds",
	target = "NineTailFoxB",
	hrpSize = v(3.6, 3.6, 9),
	hrpPos = v(0, HRP_Y, 0),
	joints = joints,
})

local model = game:GetService("ServerStorage")._RosterQuadrupeds.NineTailFoxB
model:SetAttribute("Scale", SCALE)
for _, m in model:GetDescendants() do
	if m:IsA("Motor6D") and ext[m.Name] then
		m:SetAttribute("ExtendAxis", ext[m.Name][1])
		m:SetAttribute("ExtendMax", ext[m.Name][2] * K)
	end
end

-- FX attachments (identity world rotation, they ride their segment)
local function hook(name, partName, point)
	local part = assert(model:FindFirstChild(partName), partName)
	for _, c in part:GetChildren() do
		if c:IsA("Attachment") and c.Name == name then
			c:Destroy()
		end
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(CFrame.new(point))
	a.Parent = part
end
hook("Mouth", "Head", v(0, 8.35, -10.05))
hook("Core", "Chest", v(0, 5.8, -3.6))
hook("Throat", "Neck", v(0, 7.6, -4.4))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	hook("PawF" .. side .. "_FX", "PawF" .. side, v(s * 1.1, 0, -3.3))
	hook("PawB" .. side .. "_FX", "PawB" .. side, v(s * 1.15, 0, 4.0))
end
hook("TailRoot_FX", "Tail", TAIL.root)
for i = 1, 9 do
	local d = TAIL.dir(i)
	hook("TailBase" .. i .. "_FX", "Tail" .. i, TAIL.root)
	hook("TailTip" .. i .. "_FX", "Tail" .. i .. "Whip", TAIL.root + d * TAIL.geo.flame.s) -- the foxfire ball's centre
end

-- final scale: about the HRP pivot, then re-ground (the HRP's Y is the root height)
model:ScaleTo(K)
local hrp = model.HumanoidRootPart
local finalY = 2.6 * SCALE
model:PivotTo(CFrame.new(0, finalY, 0))
model.WorldPivot = CFrame.new(0, finalY, 0)
local hum = model.Humanoid
hum.HipHeight = hrp.Position.Y - hrp.Size.Y / 2
local bodyTop = -math.huge
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d ~= hrp then
		local cf, s = d.CFrame, d.Size / 2
		bodyTop = math.max(bodyTop, cf.Y + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X
			+ math.abs(cf.LookVector.Y) * s.Z)
	end
end
hrp.HealthBar.StudsOffset = Vector3.new(0, bodyTop - hrp.Position.Y + 1.0, 0)

return result .. (" | SCALE %.2f, ExtendMax mid %.2f tip %.2f whip %.2f, rest reach %.2f, full reach %.2f, HRP y %.2f, top %.2f"):format(
	SCALE, lay.extMid * K, lay.extTip * K, lay.extWhip * K, lay.restReach * K, lay.fullReach * K, hrp.Position.Y, bodyTop)
