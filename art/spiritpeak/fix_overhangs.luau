--[[
Pulls back the pieces that hung over an edge on the spirit peaks (found by strict_seat.luau), on every peak in
its own Peak.frame. Re-runnable (each fix checks first). Run before strict_seat.luau. One ChangeHistory recording.

  _G.FIX_OVERHANGS = { peaks = { 1 } }   -- default: all 8 peaks

  - Dwelling.StoneLantern (both): their plinths stuck 1.6 past the terrace's front coping and floated ~0.9
    over the lawn; moved back onto the terrace (just clear of the porch pillars).
  - Props: anything standing on the terrace whose footprint pokes past the terrace's sides is slid in.
  - Dressing.GateLanterns: stone lanterns perched on the gate's flank walls, wider than the walls, so their
    plinths hung in the air; removed (the gate keeps its own hanging lanterns).
]]

local CHS = game:GetService("ChangeHistoryService")
local CFG = _G.FIX_OVERHANGS or {}
local PEAKS = CFG.peaks or { 1, 2, 3, 4, 5, 6, 7, 8 }

local TERRACE_FRONT = -25.4 -- front edge of the coping, peak-local z
local TERRACE_X = 17.0 -- the terrace body's half-width

local function frameOf(peak: Model): CFrame
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	return CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
end

local function bounds(frame: CFrame, inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local parts = if inst:IsA("BasePart") then { inst } else {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		local s = p.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local v = frame:PointToObjectSpace(p.CFrame * Vector3.new(x * s.X, y * s.Y, z * s.Z))
					lo, hi = lo:Min(v), hi:Max(v)
				end
			end
		end
	end
	return lo, hi
end

local function shift(frame: CFrame, m: Model, d: Vector3)
	m:PivotTo(m:GetPivot() + frame:VectorToWorldSpace(d))
end

local report = {}
local recording = CHS:TryBeginRecording("FixSpiritPeakOverhangs")
local ok, err = pcall(function()
	for _, i in PEAKS do
		local peak = workspace.Map.Sect.SpiritPeaks:FindFirstChild("Peak_" .. i) :: Model
		local frame = frameOf(peak)
		local dwelling = peak:FindFirstChild("Dwelling")
		if dwelling then
			for _, l in dwelling:GetChildren() do
				if l.Name == "StoneLantern" and l:IsA("Model") then
					local _, hi = bounds(frame, l)
					if hi.Z > TERRACE_FRONT + 0.05 then
						shift(frame, l, Vector3.new(0, 0, TERRACE_FRONT - 0.05 - hi.Z))
						table.insert(report, string.format("%s Dwelling.StoneLantern back %.2f", peak.Name, hi.Z - TERRACE_FRONT + 0.05))
					end
				end
			end
		end
		local props = peak:FindFirstChild("Props")
		if props then
			for _, p in props:GetChildren() do
				local lo, hi = bounds(frame, p)
				local onTerrace = lo.Y > -1.0 and hi.Z < TERRACE_FRONT + 1 and lo.Z > -46
				if p:IsA("Model") and onTerrace then
					local dx = if hi.X > TERRACE_X - 0.1 then TERRACE_X - 0.1 - hi.X elseif lo.X < -TERRACE_X + 0.1 then -TERRACE_X + 0.1 - lo.X else 0
					if dx ~= 0 then
						shift(frame, p, Vector3.new(dx, 0, 0))
						table.insert(report, string.format("%s %s slid in %.2f", peak.Name, p.Name, dx))
					end
				end
			end
		end
		local dressing = peak:FindFirstChild("Dressing")
		local gl = dressing and dressing:FindFirstChild("GateLanterns")
		if gl then
			gl:Destroy()
			table.insert(report, peak.Name .. " Dressing.GateLanterns removed")
		end
	end
end)
if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return table.concat(report, "\n")
