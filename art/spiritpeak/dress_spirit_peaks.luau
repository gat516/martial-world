--[[
Dresses the spirit peaks' lawns (docs/systems/map.md, "Spirit peak template"). Run in Studio Edit mode through
the MCP. Re-runnable: it rebuilds the Dressing groups it owns (Plants, Stones, Path) and re-seats the starter
foliage, so the layout below is the source of truth. One ChangeHistory recording per run.

  _G.SPIRIT_DRESS = { peaks = { 1 } }   -- default: all 8 peaks

Peak-local frame (Peak.frame): origin at the Plateau, -Z outward, +Z toward the main peak and the bridge,
+X right looking outward. The lawn is the PeakGrass mesh, top about y -1.5.

Composition: you arrive over the bridge (z ~50), the stepping-stone aisle runs between the beds to the
dwelling's terrace (z -25), and the view ends on the house with the signature tree off to its right. Plants
come in clusters of mixed sizes with quiet lawn between them:
  Signature   the biggest: the tree, a bush, ferns, a leaf tuft and a standing stone
  LeftFront   the starter pine outside the garden's front-left corner, a bush, a fern, a tuft, a small stone
              (it frames the gate view on the left; the stele balances it on the right)
  StairHead   a bush and the tallest standing stone either side of the cliff stairs' head, a fern, a stub
  Landing     a fern, a tuft and a column stub left of the bridge landing; one fern on the right
  Stele       two low tufts at the name stele's foot
  Back        two small bushes and a fern on the rim behind the house
  Trough      one fern past the trough's end
Rocks are only small angular column stubs (parts, Slate, warm grays) sunk into the lawn, never boulders.

Every item is seated by rays straight down at its centre and four footprint corners against the peak's
Pillar (PeakGrass, LawnCollider, Terrace): it rests on the LOWEST hit (so no edge floats) and sinks `sink`. A
corner that misses the lawn, or a hit more than 0.8 below the centre's (a rim bevel), is an error: the spot
is reported and skipped, so nothing hangs over an edge. Dressing never collides, touches or answers queries,
so it never blocks building. Starter foliage (Bush, StandingStone, PineTree, SpiritTree pieces) is moved into
the clusters by ItemId; ids never change.
]]

local ServerStorage = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")

local CFG = _G.SPIRIT_DRESS or {}
local PEAKS = CFG.peaks or { 1, 2, 3, 4, 5, 6, 7, 8 }

local LIB = ServerStorage:WaitForChild("AssetLibrary")
local BUSHES = LIB["Stylized Foliage + Pots"]["Stylized Bushes"]
local PLANTS = LIB["Stylized Foliage + Pots"]["Plants + Pots"]

local ROCK = { Color3.fromHex("7A7570"), Color3.fromHex("6E6A65"), Color3.fromHex("85807A"), Color3.fromHex("66625D") }
local PAVE = { Color3.fromHex("A39A8B"), Color3.fromHex("9A9183"), Color3.fromHex("ADA494"), Color3.fromHex("958C7E") }
-- the library foliage is a saturated green; a slight warm-gray tint pulls it toward the map's jade/sage
local FOLIAGE_TINT = Color3.fromHex("C9D2BE")

local function sizeOf(m: Instance): Vector3
	if m:IsA("Model") then
		return select(2, m:GetBoundingBox())
	end
	return (m :: BasePart).Size
end

-- the child of `folder` called `name` whose footprint (X) is closest to `sx`
local function pick(folder: Instance, name: string, sx: number): Instance
	local best, bestD = nil, math.huge
	for _, c in folder:GetChildren() do
		if c.Name == name then
			local d = math.abs(sizeOf(c).X - sx)
			if d < bestD then
				best, bestD = c, d
			end
		end
	end
	assert(best, "asset not found: " .. name)
	return best
end

local SRC = {
	bushL = pick(BUSHES, "Stylized Bush (Green)", 16), -- 16x9x14
	bushM = pick(BUSHES, "Stylized Bush (Green)", 11), -- 11x6x9
	fern = pick(PLANTS, "Fern", 10), -- 10x4x9
	fernS = pick(PLANTS, "Fern", 6), -- 6x2x5
	leaf = pick(PLANTS, "Leaf", 5), -- 5x2x5
	tree = LIB["Stylized Tree Pack"]["Stylized Tree (Dark Green)"], -- 24x43x29, a layered pine like the signature tree
}

-- Plants: { kind, x, z, scale, yaw, sink }. Spots come from a ray survey of Peak_1's lawn (the flat top ends
-- about r 48 at the sides and r 44-46 front and back; outside it is the bevelled lip) and keep clear of the
-- bridge (x +-11 beyond z 47), the gate's flank walls, the well, trough, stele, teleport array and terrace.
local PLANT_LAYOUT = {
	Signature = {
		{ "bushL", 28.6, -36.6, 0.42, 30, 0.4 },
		{ "leaf", 31.4, -33.4, 0.75, 15, 0.15 },
		{ "fern", 36.0, -26.6, 0.55, 110, 0.25 },
		{ "fernS", 39.6, -21.4, 0.8, 200, 0.2 },
	},
	LeftFront = {
		{ "tree", -26.4, 38.4, 0.42, 200, 0.4 },
		{ "bushM", -30.0, 34.8, 0.55, 300, 0.35 },
		{ "fernS", -21.8, 40.6, 0.8, 60, 0.2 },
		{ "leaf", -24.2, 34.2, 0.7, 140, 0.15 },
	},
	StairHead = {
		{ "fernS", -40.0, -12.6, 0.85, 20, 0.2 },
	},
	Landing = {
		{ "fern", -14.6, 46.0, 0.48, 250, 0.25 },
		{ "leaf", -19.4, 42.6, 0.7, 80, 0.15 },
		{ "fernS", 15.6, 44.2, 0.8, 170, 0.2 },
	},
	Stele = {
		{ "leaf", 33.6, 23.2, 0.65, 30, 0.15 },
		{ "fernS", 38.6, 22.2, 0.7, 300, 0.2 },
	},
	Back = {
		{ "fernS", -19.0, -44.0, 0.8, 0, 0.2 },
	},
	Trough = {
		{ "fernS", 44.2, 0.8, 0.75, 90, 0.2 },
	},
}
-- kinds seated on their trunk (a small footprint) rather than on most of their spread
local TRUNK = { tree = true }

-- Column stubs: { x, z, rise (top above the lawn), yaw } - two or three hexagonal columns each, sunk a stud deep
local STONES = {
	{ -36.8, -18.4, 1.2, 70 }, -- stair head, beside the bush
	{ -18.2, 44.8, 0.8, 340 }, -- bridge landing, left, by the standing stone
}

-- Starter foliage slots by ItemId, filled in order (StandingStones tallest first, the rest by StarterId).
-- The starter PineTree (a sparse, realistic tree) stands back by the stairs' head; the left front corner gets
-- a stylized pine from the library instead, so the view from the gate is framed by the same tree family as
-- the signature tree.
local SLOTS = {
	SpiritTree = { { 32.8, -30.8 } }, -- a little in from the rim, so a wide-rooted trunk stays on the lawn
	PineTree = { { -37.0, -24.0 } },
	Bush = { { 24.0, -40.4 }, { -38.6, -15.6 }, { -12.2, -45.6 }, { 14.6, -45.8 }, { 39.8, 18.8 }, { -35.0, 24.0 } },
	StandingStone = { { -44.6, -4.0 }, { 36.6, -22.6 }, { -16.6, 41.6 }, { -34.4, 30.0 }, { 22.2, -43.6 }, { -26.0, -38.0 } },
}

-- Stepping-stone aisle: gate to the terrace's front step, between the bed rows (x = 0)
local PATH = { z0 = 41.0, z1 = -24.2, step = 2.75, size = Vector2.new(2.7, 2.1) }

--------------------------------------------------------------------------------------------------------------

local function peakFrame(peak: Model): CFrame
	local c = (peak:FindFirstChild("Plateau") :: BasePart).Position
	return CFrame.lookAt(c, c + Vector3.new(c.X, 0, c.Z).Unit)
end

local function groundParams(peak: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { peak:FindFirstChild("Pillar") :: Instance }
	params.RespectCanCollide = true
	return params
end

local function groundY(frame: CFrame, params: RaycastParams, x: number, z: number): number?
	local o = frame:PointToWorldSpace(Vector3.new(x, 12, z))
	local hit = workspace:Raycast(o, frame:VectorToWorldSpace(Vector3.new(0, -20, 0)), params)
	return hit and frame:PointToObjectSpace(hit.Position).Y
end

-- lowest lawn height over a footprint, or nil + why
local function seatY(frame: CFrame, params: RaycastParams, x: number, z: number, hx: number, hz: number): (number?, string?)
	local centre = groundY(frame, params, x, z)
	if not centre then
		return nil, "no ground under the centre"
	end
	local low = centre
	for _, o in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local y = groundY(frame, params, x + o[1] * hx, z + o[2] * hz)
		if not y then
			return nil, "a corner hangs over the edge"
		elseif centre - y > 0.8 then
			return nil, string.format("a corner is on the rim bevel (%.2f below)", centre - y)
		end
		low = math.min(low, y)
	end
	return low, nil
end

local function quiet(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = d.Size.Magnitude > 3
		elseif d:IsA("Highlight") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("SurfaceAppearance") then
			pcall(function()
				(d :: any).Color = FOLIAGE_TINT
			end)
		end
	end
end

local errors = {}

local function plant(peak: Model, frame: CFrame, params: RaycastParams, group: Model, e: { any })
	local kind, x, z, s, yaw, sink = e[1], e[2], e[3], e[4], e[5], e[6]
	local m = SRC[kind]:Clone() :: Model
	m:ScaleTo(m:GetScale() * s)
	quiet(m)
	-- turn it to the frame plus `yaw` (the library models stand upright), then put its bbox centre over (x, z)
	-- and its bbox bottom `sink` under the lowest lawn beneath it
	local piv = m:GetPivot()
	m:PivotTo(CFrame.new(piv.Position) * frame.Rotation * CFrame.Angles(0, math.rad(yaw), 0) * piv.Rotation)
	local cf, size = m:GetBoundingBox()
	-- footprint for the seat: the inner 60% (leaf tips may overhang a little)
	local hx, hz = if TRUNK[kind] then 1 else size.X * 0.3, if TRUNK[kind] then 1 else size.Z * 0.3
	local y, why = seatY(frame, params, x, z, hx, hz)
	if not y then
		table.insert(errors, string.format("%s %s/%s at (%.1f, %.1f): %s", peak.Name, group.Name, kind, x, z, why))
		m:Destroy()
		return
	end
	local bottomCentre = cf.Position - Vector3.new(0, size.Y / 2, 0)
	m:PivotTo(m:GetPivot() + (frame:PointToWorldSpace(Vector3.new(x, y - sink, z)) - bottomCentre))
	m.Name = kind
	m.Parent = group
end

local rng = Random.new(11) -- reseeded per peak, so every peak gets the same jitter

local function stone(peak: Model, frame: CFrame, params: RaycastParams, group: Model, e: { number })
	local x, z, rise, yaw = e[1], e[2], e[3], e[4]
	local y, why = seatY(frame, params, x, z, 0.9, 0.9)
	if not y then
		table.insert(errors, string.format("%s stone at (%.1f, %.1f): %s", peak.Name, x, z, why))
		return
	end
	local m = Instance.new("Model")
	m.Name = "ColumnStub"
	-- a main column, a lower one beside it and sometimes a short third: hexagonal prisms (three boxes at 60
	-- degrees) with flat tops, like the pillar's rock columns
	local spec = { { 0, 0, 1.3, rise }, { 1.05, 0.45, 1.0, rise * 0.6 } }
	if rise > 1 then
		table.insert(spec, { -0.6, 0.95, 0.8, rise * 0.35 })
	end
	for i, p in spec do
		local w, h = p[3], p[4] + 1.0 -- a stud sunk into the lawn
		local col = ROCK[rng:NextInteger(1, #ROCK)]
		local base = frame * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(p[1], p[4] - h / 2, p[2])
			* CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(0, 60)), math.rad(rng:NextNumber(-4, 4)))
		for k = 0, 2 do
			local part = Instance.new("Part")
			part.Name = "Column" .. i
			part.Material = Enum.Material.Slate
			part.Color = col
			part.Size = Vector3.new(w, h, w / math.sqrt(3))
			part.CFrame = base * CFrame.Angles(0, math.rad(60 * k), 0)
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = m
		end
	end
	quiet(m)
	m.Parent = group
end

local function path(peak: Model, frame: CFrame, params: RaycastParams, group: Model)
	local n = math.floor((PATH.z0 - PATH.z1) / PATH.step + 0.5)
	for k = 0, n do
		local z = PATH.z0 - (PATH.z0 - PATH.z1) * k / n
		local x = rng:NextNumber(-0.25, 0.25)
		local sx, sz = PATH.size.X * rng:NextNumber(0.9, 1.08), PATH.size.Y * rng:NextNumber(0.88, 1.08)
		local y = seatY(frame, params, x, z, sx / 2, sz / 2)
		if not y then
			table.insert(errors, string.format("%s path stone at z %.1f: no lawn", peak.Name, z))
			continue
		end
		local part = Instance.new("Part")
		part.Name = "Flagstone"
		part.Material = Enum.Material.Slate
		part.Color = PAVE[rng:NextInteger(1, #PAVE)]
		part.Size = Vector3.new(sx, 0.8, sz)
		-- the top stands 0.06 proud of the lowest lawn under it; the rest is sunk
		part.CFrame = frame * CFrame.new(x, y + 0.06 - 0.4, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-7, 7)), 0)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = group
	end
	quiet(group)
end

local function moveStarters(peak: Model, frame: CFrame, params: RaycastParams)
	local byItem: { [string]: { Model } } = {}
	for _, d in (peak:FindFirstChild("Foliage") :: Instance):GetChildren() do
		local item = d:GetAttribute("ItemId")
		if d:IsA("Model") and SLOTS[item] then
			byItem[item] = byItem[item] or {}
			table.insert(byItem[item], d)
		end
	end
	for item, list in byItem do
		if item == "StandingStone" then
			table.sort(list, function(a, b)
				return sizeOf(a).Y > sizeOf(b).Y
			end)
		else
			table.sort(list, function(a, b)
				return (a:GetAttribute("StarterId") :: string) < (b:GetAttribute("StarterId") :: string)
			end)
		end
		for i, m in list do
			local slot = SLOTS[item][i]
			if not slot then
				table.insert(errors, peak.Name .. " " .. m:GetAttribute("StarterId") .. ": no slot left (not moved)")
				continue
			end
			local cf, size = m:GetBoundingBox()
			local foot = item == "SpiritTree" or item == "PineTree"
			-- trees stand on their trunk: seat on a small footprint; stones and bushes on most of theirs
			local hx, hz = if foot then 1 else size.X * 0.35, if foot then 1 else size.Z * 0.35
			local y, why = seatY(frame, params, slot[1], slot[2], hx, hz)
			if not y then
				table.insert(errors, string.format("%s %s slot (%.1f, %.1f): %s", peak.Name, m:GetAttribute("StarterId"), slot[1], slot[2], why))
				continue
			end
			local lc = frame:PointToObjectSpace(cf.Position)
			local sink = if item == "StandingStone" then 0.45 elseif foot then 0.3 else 0.3
			local bottom = lc.Y - size.Y / 2
			local delta = Vector3.new(slot[1] - lc.X, y - sink - bottom, slot[2] - lc.Z)
			m:PivotTo(m:GetPivot() + frame:VectorToWorldSpace(delta))
		end
	end
end

local OWN = { Plants = true, Stones = true, Path = true }
-- the previous pass's groups (lumpy library boulders, stacked edge clusters, terrain-era paving): removed
local RETIRED = { TeleportPad = true, Edge_E = true, Rim_W = true, Pad = true, Landing_L = true, Landing_R = true,
	Rim_Back = true, StairHead = true }

local function dress(peak: Model)
	rng = Random.new(11)
	local frame = peakFrame(peak)
	local params = groundParams(peak)
	local dressing = peak:FindFirstChild("Dressing") :: Model
	if not dressing then
		dressing = Instance.new("Model")
		dressing.Name = "Dressing"
		dressing.Parent = peak
	end
	for _, g in dressing:GetChildren() do
		if OWN[g.Name] or RETIRED[g.Name] then
			g:Destroy()
		end
	end
	moveStarters(peak, frame, params)
	local plants = Instance.new("Model")
	plants.Name = "Plants"
	for name, list in PLANT_LAYOUT do
		local g = Instance.new("Model")
		g.Name = name
		for _, e in list do
			plant(peak, frame, params, g, e)
		end
		g.Parent = plants
	end
	plants.Parent = dressing
	local stones = Instance.new("Model")
	stones.Name = "Stones"
	for _, e in STONES do
		stone(peak, frame, params, stones, e)
	end
	stones.Parent = dressing
	local p = Instance.new("Model")
	p.Name = "Path"
	path(peak, frame, params, p)
	p.Parent = dressing
end

local recording = CHS:TryBeginRecording("DressSpiritPeaks")
local ok, err = pcall(function()
	for _, i in PEAKS do
		dress(workspace.Map.Sect.SpiritPeaks:FindFirstChild("Peak_" .. i) :: Model)
		task.wait()
	end
end)
if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return "dressed peaks " .. table.concat(PEAKS, ",") .. (if #errors > 0 then "\n" .. table.concat(errors, "\n") else "\nno errors")
