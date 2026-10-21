--[[
Replaces each spirit peak's one-piece starter garden fence (StarterId "Garden/Fence", ItemId "GardenFence") with
16 separate segments of the buildable Fence item (ItemId "Fence", StarterId "Garden/Fence_1".."Garden/Fence_16"),
cloned from ReplicatedStorage.BuildCatalog.Fence so each is exactly what Build expects. Run in Studio Edit mode
(MCP execute_luau); re-runnable (it rebuilds the segments). Peaks.applyLayout treats a saved "Garden/Fence"
removal as all segments removed.

  _G.GARDEN_FENCE = { peaks = { 1 } }   -- default: all 8

Layout, peak-local (Peak.frame; -Z outward): a rectangle around the 12 beds (beds span X +-28, Z -20..32), four
13.4-stud segments a side, the front and back each split by a 9-stud gap on the garden aisle (x = 0).
Order: front left to right, right side front to back, back right to left, left side back to front. Each
segment's run (+Z) points along that loop, so its smaller end post always tucks into the next one's post.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local CFG = _G.GARDEN_FENCE or {}
local PEAKS = CFG.peaks or { 1, 2, 3, 4, 5, 6, 7, 8 }

local LAWN = -1.5
local RUN = 13.4 -- segment length (BuildItems Fence edges at +-6.7)
local SIDE_X = 31.3 -- side fences' centre line
local FRONT_Z, BACK_Z = 32.8, -20.8 -- front/back fences' centre lines (corners meet the sides exactly)
local SIDE_Z0 = -20.8 -- side runs start here and go 4 x RUN toward the front (to 32.8)
local GAP = 4.5 -- half-width of the aisle gap front and back
local SINK = 0.08 -- posts sink this far below the lowest lawn under them

local template = game:GetService("ReplicatedStorage").BuildCatalog:FindFirstChild("Fence") :: Model
assert(template, "BuildCatalog.Fence missing")
local cf0, size0 = template:GetBoundingBox()
local LIFT = template:GetPivot().Position.Y - (cf0.Position.Y - size0.Y / 2) -- pivot height above the base

local function segments(): { { x: number, z: number, yaw: number } }
	local list = {}
	local xs = { -(GAP + RUN * 1.5), -(GAP + RUN / 2), GAP + RUN / 2, GAP + RUN * 1.5 }
	for _, x in xs do -- front, left to right
		table.insert(list, { x = x, z = FRONT_Z, yaw = 90 }) -- run +Z points along the loop (clockwise from above)
	end
	for k = 3, 0, -1 do -- right side, front to back
		table.insert(list, { x = SIDE_X, z = SIDE_Z0 + RUN * (k + 0.5), yaw = 180 })
	end
	for i = 4, 1, -1 do -- back, right to left
		table.insert(list, { x = xs[i], z = BACK_Z, yaw = -90 })
	end
	for k = 0, 3 do -- left side, back to front
		table.insert(list, { x = -SIDE_X, z = SIDE_Z0 + RUN * (k + 0.5), yaw = 0 })
	end
	return list
end

local function rebuild(peak: Model)
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	local frame = CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
	local garden = peak:FindFirstChild("Garden") :: Model
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { peak:FindFirstChild("Pillar") :: Instance }
	params.RespectCanCollide = true
	for _, d in garden:GetChildren() do
		local id = d:GetAttribute("StarterId")
		if id == "Garden/Fence" or (type(id) == "string" and id:match("^Garden/Fence_%d+$")) then
			d:Destroy()
		end
	end
	for i, s in segments() do
		local seg = template:Clone()
		for k in seg:GetAttributes() do
			seg:SetAttribute(k, nil) -- catalogue display attributes don't belong on a piece
		end
		seg.Name = "Fence"
		seg:SetAttribute("ItemId", "Fence")
		seg:SetAttribute("StarterId", "Garden/Fence_" .. i)
		-- the lawn mesh rolls a little (about y -1.7..-1.2): stand the run on the lowest of its three post
		-- spots, sunk SINK, so no post floats (the higher ones sink a few tenths into the turf)
		local place = frame * CFrame.new(s.x, 0, s.z) * CFrame.Angles(0, math.rad(s.yaw), 0)
		local low = math.huge
		for _, dz in { -RUN / 2, 0, RUN / 2 } do
			local o = place * Vector3.new(0, 10, dz)
			local hit = workspace:Raycast(o, Vector3.new(0, -20, 0), params)
			low = math.min(low, if hit then frame:PointToObjectSpace(hit.Position).Y else LAWN)
		end
		seg:PivotTo(place * CFrame.new(0, low - SINK + LIFT, 0))
		seg.Parent = garden
	end
end

local recording = ChangeHistoryService:TryBeginRecording("GardenFenceSegments")
local ok, err = pcall(function()
	for _, i in PEAKS do
		rebuild(workspace.Map.Sect.SpiritPeaks:FindFirstChild("Peak_" .. i) :: Model)
	end
end)
if recording then
	ChangeHistoryService:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return "fence segments on peaks " .. table.concat(PEAKS, ",")
