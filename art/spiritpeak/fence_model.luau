--[[
Rebuilds ReplicatedStorage.BuildCatalog.Fence (the buildable Fence item, also the starter garden fence
segments) as a low, clean timber fence: knee-high, slim posts, two straight rails. Run in Studio Edit mode.
Then re-run garden_fence.luau so the starter segments match.

Kept from the old model so saved fences don't shift: the pivot (run along local Z, centre of the run) and
its height above the base (LIFT, 3.277), and the 13.4-stud run with BuildItems' snap edges at +-6.7.
One post per joint: the full post stands at the -Z end; the +Z end post and its cap are a hair smaller, so
where two segments meet they sit inside the neighbour's post instead of doubling it (and show at a free end).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local LIFT = 3.277 -- pivot height above the base (the old model's)
local RUN = 13.4
local H = 2.6 -- post height (knee-high)
local POST = Color3.fromHex("3F2C21")
local RAIL = Color3.fromHex("5A3F2E")

local catalog = game:GetService("ReplicatedStorage"):WaitForChild("BuildCatalog")
local old = catalog:FindFirstChild("Fence")

local function part(m: Model, name: string, size: Vector3, at: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = Enum.Material.Wood
	p.Color = color
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local recording = ChangeHistoryService:TryBeginRecording("FenceModel")
local m = Instance.new("Model")
m.Name = "Fence"
local base = -LIFT
-- posts: full at -Z, mid, and a slightly slimmer one at +Z
part(m, "Post", Vector3.new(0.5, H, 0.5), Vector3.new(0, base + H / 2, -RUN / 2), POST)
part(m, "PostCap", Vector3.new(0.62, 0.14, 0.62), Vector3.new(0, base + H + 0.07, -RUN / 2), POST)
part(m, "PostMid", Vector3.new(0.42, H - 0.25, 0.42), Vector3.new(0, base + (H - 0.25) / 2, 0), POST)
part(m, "PostEnd", Vector3.new(0.46, H, 0.46), Vector3.new(0, base + H / 2, RUN / 2), POST)
-- its cap is a hair smaller and a hair higher than the full cap, so at a joint it hides inside the neighbour's
-- and at a free end (the aisle gaps) the run still ends on a capped post
part(m, "PostEndCap", Vector3.new(0.58, 0.12, 0.58), Vector3.new(0, base + H + 0.005 + 0.06, RUN / 2), POST)
-- rails: straight, the full run, butting at the post centres
part(m, "RailTop", Vector3.new(0.18, 0.26, RUN), Vector3.new(0, base + H - 0.42, 0), RAIL)
part(m, "RailLow", Vector3.new(0.16, 0.22, RUN), Vector3.new(0, base + 1.0, 0), RAIL)
m.WorldPivot = CFrame.new(0, 0, 0)
if old then
	for k, v in old:GetAttributes() do
		m:SetAttribute(k, v)
	end
	for _, t in old:GetTags() do
		m:AddTag(t)
	end
	m:PivotTo(old:GetPivot())
	old:Destroy()
end
m.Parent = catalog
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "Fence rebuilt"
