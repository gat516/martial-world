--[[
Strict floating check for the spirit peaks: every visible unit standing on a peak's lawn must have its whole
footprint on something. Run in Studio Edit mode through the MCP; returns a report. One ChangeHistory recording.

  _G.STRICT_SEAT = { peaks = { 1 }, dry = true }   -- defaults: all 8 peaks, apply

A unit is measured on its feet: the visible parts whose bottoms are within FOOT of the unit's lowest point. A
grid of rays (every STEP studs, over each foot's own area) goes straight down from RISE above the feet against
the support: the Pillar (turf, terrace, rock) without the invisible LawnCollider boxes, the BridgeGate (its
flank walls carry lanterns) and Terrain. gap = foot bottom - surface under it.
  - the largest gap > TOL: the unit floats somewhere; it is lowered by that gap + EMBED, so its whole
    footprint rests on the surface (the rest sinks a little into the turf);
  Plants (Dressing.Plants and Planters, Bush pieces) need only the inner half of their footprint supported:
  their leaves spread past their roots.
  - a ray that finds nothing within REACH: an edge hangs over a drop; reported, never moved (fix by hand);
  - lowering more than MAX_DROP: reported, not moved.
Units, in order (supports before what stands on them): BridgeGate (whole), NameStele, TeleportArray, Well,
Trough, Dwelling, Props/*, Garden JadeLamps and Fences, Foliage/*, then each model or part in Dressing's
groups. Never moved: Plateau, Pillar, Garden.Beds (PlotAnchors),
Bridge, CaveAbode, CliffDecor, SpawnLocation, Dressing.Abode (porch, below the cliff) and Dressing.FX.
]]

local CHS = game:GetService("ChangeHistoryService")
local CFG = _G.STRICT_SEAT or {}
local PEAKS = CFG.peaks or { 1, 2, 3, 4, 5, 6, 7, 8 }
local DRY = CFG.dry == true

local FOOT = 0.35
local STEP = 1.0
local TOL = 0.04
local EMBED = 0.06
local REACH = 3
local RISE = 2.5 -- rays start this far above a foot
local TRUNK = 6 -- a foot part wider than this is a tree mesh: only its trunk foot (around its centre) is sampled
local MAX_DROP = 2.5

local function frameOf(peak: Model): CFrame
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	return CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
end

local function visibleParts(u: Instance): { BasePart }
	local list = {}
	if u:IsA("BasePart") and u.Transparency < 1 then
		table.insert(list, u)
	end
	for _, d in u:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(list, d)
		end
	end
	return list
end

-- local-frame extents of a part
local function extents(frame: CFrame, p: BasePart): (Vector3, Vector3)
	local s = p.Size / 2
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local v = frame:PointToObjectSpace(p.CFrame * Vector3.new(x * s.X, y * s.Y, z * s.Z))
				lo, hi = lo:Min(v), hi:Max(v)
			end
		end
	end
	return lo, hi
end

-- plants spread leaves past their roots: only the inner PLANT_CORE of their footprint must stand on something
local PLANT_CORE = 0.5
local function isPlant(peak: Model, u: Instance): boolean
	local dressing = peak:FindFirstChild("Dressing")
	local item = u:GetAttribute("ItemId")
	return (dressing ~= nil and ((dressing :: Instance):FindFirstChild("Plants") ~= nil and u:IsDescendantOf((dressing :: Instance):FindFirstChild("Plants") :: Instance)
		or (dressing :: Instance):FindFirstChild("Planters") ~= nil and u:IsDescendantOf((dressing :: Instance):FindFirstChild("Planters") :: Instance)))
		or item == "Bush"
end

local function measure(peak: Model, frame: CFrame, u: Instance): (number?, number?, number)
	local parts = visibleParts(u)
	if #parts == 0 then
		return nil, nil, 0
	end
	local bottom = math.huge
	local ext = {}
	for i, p in parts do
		local lo, hi = extents(frame, p)
		ext[i] = { lo, hi }
		bottom = math.min(bottom, lo.Y)
	end
	-- support = the ground and what things are built on: the pillar (lawn, terrace, rock) without the invisible
	-- lawn collider, the gate (its flank walls carry lanterns), and Terrain
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local support: { Instance } = { workspace.Terrain }
	for _, c in (peak:FindFirstChild("Pillar") :: Instance):GetChildren() do
		if c.Name ~= "LawnCollider" then
			table.insert(support, c)
		end
	end
	local gate = peak:FindFirstChild("BridgeGate")
	if gate and gate ~= u then
		table.insert(support, gate)
	end
	params.FilterDescendantsInstances = support
	params.RespectCanCollide = false
	local maxGap, minGap, overhang = nil, nil, 0
	for i, p in parts do
		local lo, hi = ext[i][1], ext[i][2]
		if lo.Y <= bottom + FOOT then
			-- small feet (posts, leaf tips) are sampled at their centre and corners; slabs on a grid
			local xs, zs = {}, {}
			local inset = 0.12
			local x0, x1, z0, z1 = lo.X + inset, hi.X - inset, lo.Z + inset, hi.Z - inset
			if isPlant(peak, u) then
				local cx, cz, hx, hz = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2, (hi.X - lo.X) * PLANT_CORE / 2, (hi.Z - lo.Z) * PLANT_CORE / 2
				x0, x1, z0, z1 = cx - hx, cx + hx, cz - hz, cz + hz
			end
			if hi.X - lo.X > TRUNK or hi.Z - lo.Z > TRUNK then
				-- a tree's trunk-and-canopy mesh: its box is mostly air; only the trunk's foot stands on the lawn
				-- (library trees are pivoted at the trunk's foot)
				local pc = frame:PointToObjectSpace(if u:IsA("Model") then u:GetPivot().Position else p.Position)
				local cx, cz = pc.X, pc.Z
				x0, x1, z0, z1 = cx - 0.8, cx + 0.8, cz - 0.8, cz + 0.8
			end
			local nx = math.max(1, math.ceil((x1 - x0) / STEP))
			local nz = math.max(1, math.ceil((z1 - z0) / STEP))
			for a = 0, nx do
				table.insert(xs, x0 + (x1 - x0) * a / nx)
			end
			for b = 0, nz do
				table.insert(zs, z0 + (z1 - z0) * b / nz)
			end
			for _, x in xs do
				for _, z in zs do
					-- only where the part really is (a rotated part's box corners can be empty air)
					local world = frame:PointToWorldSpace(Vector3.new(x, lo.Y + 0.05, z))
					local localToPart = p.CFrame:PointToObjectSpace(world)
					local half = p.Size / 2 + Vector3.new(0.05, 0.3, 0.05)
					if math.abs(localToPart.X) <= half.X and math.abs(localToPart.Z) <= half.Z then -- (trunk samples are inside too)
						-- from RISE above the foot, so a foot sunk into the turf still finds the turf above it
						local origin = frame:PointToWorldSpace(Vector3.new(x, lo.Y + RISE, z))
						local hit = workspace:Raycast(origin, frame:VectorToWorldSpace(Vector3.new(0, -(RISE + REACH), 0)), params)
						if not hit or (hit.Instance:IsA("BasePart") and hit.Instance.Transparency >= 1 and hit.Instance ~= workspace.Terrain) then
							overhang += 1
						else
							local gap = lo.Y - frame:PointToObjectSpace(hit.Position).Y
							maxGap = if maxGap then math.max(maxGap, gap) else gap
							minGap = if minGap then math.min(minGap, gap) else gap
						end
					end
				end
			end
		end
	end
	return maxGap, minGap, overhang
end

local function units(peak: Model): { Instance }
	local list = {}
	local function add(x: Instance?)
		if x then
			table.insert(list, x)
		end
	end
	for _, n in { "BridgeGate", "NameStele", "TeleportArray", "Well", "Trough", "Dwelling" } do
		add(peak:FindFirstChild(n))
	end
	for _, g in { "Props", "Foliage" } do
		local f = peak:FindFirstChild(g)
		if f then
			for _, c in f:GetChildren() do
				add(c)
			end
		end
	end
	for _, c in (peak:FindFirstChild("Garden") :: Instance):GetChildren() do
		if c.Name == "JadeLamp" or c.Name == "Fence" then
			add(c)
		end
	end
	local dressing = peak:FindFirstChild("Dressing")
	if dressing then
		for _, g in dressing:GetChildren() do
			if g.Name ~= "Abode" and g.Name ~= "FX" then
				local function walk(m: Instance)
					for _, c in m:GetChildren() do
						if c:IsA("Model") and not c:FindFirstChildWhichIsA("BasePart") and c:FindFirstChildWhichIsA("Model") then
							walk(c) -- a cluster group (Plants/Signature)
						else
							add(c)
						end
					end
				end
				walk(g)
			end
		end
	end
	return list
end

local function move(frame: CFrame, u: Instance, dy: number)
	local w = frame:VectorToWorldSpace(Vector3.new(0, dy, 0))
	if u:IsA("BasePart") then
		u.CFrame += w
	elseif u:IsA("Model") then
		u:PivotTo(u:GetPivot() + w)
	end
end

local report = {}
local recording = CHS:TryBeginRecording("StrictSeatSpiritPeaks")
local ok, err = pcall(function()
	for _, i in PEAKS do
		local peak = workspace.Map.Sect.SpiritPeaks:FindFirstChild("Peak_" .. i) :: Model
		local frame = frameOf(peak)
		-- raycasts skip CanQuery = false parts, and some support is built that way (the terrace's coping and
		-- slabs, the gate's trim): let rays see the support while measuring, then put it back
		local hidden = {}
		for _, root in { peak:FindFirstChild("Pillar"), peak:FindFirstChild("BridgeGate") } do
			for _, d in (root :: Instance):GetDescendants() do
				if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 1 then
					d.CanQuery = true
					table.insert(hidden, d)
				end
			end
		end
		local mok, merr = pcall(function()
		for _, u in units(peak) do
			local maxGap, minGap, over = measure(peak, frame, u)
			local name = u:GetFullName():gsub("^Workspace%.Map%.Sect%.SpiritPeaks%.", "")
			if over > 0 then
				table.insert(report, string.format("%s: %d foot rays find no ground (hangs over an edge; check by hand)", name, over))
			end
			if maxGap and maxGap > TOL then
				local drop = maxGap + EMBED
				if drop > MAX_DROP then
					table.insert(report, string.format("%s floats %.2f (NOT MOVED: too far)", name, maxGap))
				else
					table.insert(report, string.format("%s floated %.2f -> lowered %.2f (deepest foot now %.2f in)", name, maxGap, drop, drop - (minGap or 0)))
					if not DRY then
						move(frame, u, -drop)
					end
				end
			end
		end
		end)
		for _, d in hidden do
			d.CanQuery = false
		end
		assert(mok, merr)
		task.wait()
	end
end)
if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return (if DRY then "[dry] " else "") .. #report .. " findings\n" .. table.concat(report, "\n")
