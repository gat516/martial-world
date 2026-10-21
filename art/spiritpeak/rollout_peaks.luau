--[[
Rolls the approved Peak_1 template out to the other spirit peaks, each in its own Peak.frame (origin at its
Plateau, -Z outward). Run in Studio Edit mode through the MCP, then run garden_fence.luau and
dress_spirit_peaks.luau for the same peaks (they build the fence segments, plants, stones and path).

  _G.SPIRIT_ROLLOUT = { peaks = { 2, 3, 4, 5, 6, 7, 8 } }   -- the default

Per peak:
  Pillar      replaced by a clone of ServerStorage.PeakPillar (PeakGrass on LeafyGrass, Slate rock, lawn
              collider) at the old pivot; anything else under the old Pillar moves across; Peak_1's Terrace
              (the dwelling's stone terrace) is copied in.
  starters    every starter piece whose StarterId Peak_1 also has (Dwelling, Props/*, Well, Trough,
              Garden/JadeLamp*, Abode/*) takes Peak_1's peak-local CFrame. Foliage/* ids differ per peak
              and Garden/Fence_* are rebuilt by garden_fence.luau, so both are skipped here, and so are
              the beds (Garden/Bed_*), which are never re-posed.
  Dressing    rebuilt: Peak_1's Abode porch lanterns, Planters and FX placeholders copied in.
Never touched: Plateau, Placed, Garden.Beds (PlotIds, HerbPlot tags, PlotAnchors), TeleportArray,
NameStele, SpawnLocation, BridgeGate, Bridge, CaveAbode, CliffDecor.
]]

local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local CFG = _G.SPIRIT_ROLLOUT or {}
local PEAKS = CFG.peaks or { 2, 3, 4, 5, 6, 7, 8 }
local COPY_DRESSING = { Abode = true, Planters = true, FX = true }
local MESHES = { PeakRock = true, PeakRockBase = true, PeakGrass = true, AbodeWalls = true, AbodeFloor = true,
	PeakStairs = true, PeakStairsRail = true, PeakStairsRamp = true, LawnCollider = true, Terrace = true }

local peaks = workspace.Map.Sect.SpiritPeaks
local source = peaks:WaitForChild("Peak_1") :: Model

local function frameOf(peak: Model): CFrame
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	return CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
end

-- move `inst` (a copy of something on Peak_1) from Peak_1's frame into `to`
local function carry(inst: Instance, from: CFrame, to: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(to * from:ToObjectSpace(inst:GetPivot()))
	elseif inst:IsA("BasePart") then
		inst.CFrame = to * from:ToObjectSpace(inst.CFrame)
	else
		for _, c in inst:GetChildren() do
			carry(c, from, to)
		end
	end
end

local function starters(peak: Instance): { [string]: Instance }
	local map = {}
	for _, d in peak:GetDescendants() do
		local id = d:GetAttribute("StarterId")
		if type(id) == "string" then
			map[id] = d
		end
	end
	return map
end

local f1 = frameOf(source)
local template = ServerStorage:WaitForChild("PeakPillar") :: Model
local sourceStarters = starters(source)
local report = {}

local function roll(peak: Model)
	local fN = frameOf(peak)
	-- pillar
	local old = peak:FindFirstChild("Pillar") :: Model
	local new = template:Clone()
	new.Name = "Pillar"
	new:PivotTo(old:GetPivot())
	for _, c in old:GetChildren() do
		if not MESHES[c.Name] then
			c.Parent = new
		end
	end
	local terrace = (source:FindFirstChild("Pillar") :: Model):FindFirstChild("Terrace")
	if terrace then
		local t = terrace:Clone()
		carry(t, f1, fN)
		t.Parent = new
	end
	old:Destroy()
	new.Parent = peak
	-- starter pieces
	local moved = 0
	for id, inst in starters(peak) do
		local src = sourceStarters[id]
		-- beds are skipped too: they already share one layout, and re-posing them would only add float noise
		-- to their PlotAnchors (saved herbs are relative to those)
		if src and not id:match("^Foliage/") and not id:match("^Garden/Fence") and not id:match("^Garden/Bed_") then
			local rel = if src:IsA("Model") then f1:ToObjectSpace(src:GetPivot()) else f1:ToObjectSpace((src :: BasePart).CFrame)
			if inst:IsA("Model") then
				inst:PivotTo(fN * rel)
			elseif inst:IsA("BasePart") then
				inst.CFrame = fN * rel
			end
			moved += 1
		end
	end
	-- dressing
	local dressing = peak:FindFirstChild("Dressing")
	if dressing then
		dressing:Destroy()
	end
	dressing = Instance.new("Model")
	dressing.Name = "Dressing"
	for _, g in (source:FindFirstChild("Dressing") :: Model):GetChildren() do
		if COPY_DRESSING[g.Name] then
			local c = g:Clone()
			carry(c, f1, fN)
			c.Parent = dressing
		end
	end
	dressing.Parent = peak
	table.insert(report, string.format("%s: pillar swapped, %d starters aligned", peak.Name, moved))
end

local recording = CHS:TryBeginRecording("RolloutSpiritPeaks")
local ok, err = pcall(function()
	for _, i in PEAKS do
		roll(peaks:FindFirstChild("Peak_" .. i) :: Model)
		task.wait()
	end
end)
if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return table.concat(report, "\n")
