--[[
The grand stairs from the ring terrace (Y 582) up to the south balcony (Y 649), both flights (east, west mirror).
Run in Studio Edit mode through the MCP; re-runnable (it rebuilds MainPeak.GrandStairs.FlightEast/FlightWest
and keeps the Balcony, Pier and the balcony posts).

Each side, climbing toward the axis against the mesa's south wall (z 129..149):
  foot pad      x 98..106, a paifang over the start of the flight, a lantern pair in front of it
  flight 1      x 98 -> 74.5, 582.6 -> 606
  landing 1     x 66..74.5 at 606: lantern pair (red lacquer posts, gold caps) and a potted pine
  flight 2      x 66 -> 42.5, 606 -> 628
  landing 2     x 34..42.5 at 628: lantern pair and flowers
  flight 3      x 34 -> 14, 628 -> 649 onto the balcony
The treads don't collide: each flight has an invisible ramp on its nosing line (walkable, verified by raycast);
landings and the foot pad collide. Under every flight a stone wedge closes it down to the terrace, and the
outer side has a stone balustrade (posts with caps, a sloped rail); landings get red lacquer posts.
Lamps are _Templates.FX_StoneLantern clones named StoneLantern (DayNight scales them).
]]

local CHS = game:GetService("ChangeHistoryService")
local Templates = game:GetService("ServerStorage")._Templates
local Lib = game:GetService("ServerStorage").AssetLibrary
local Stairs = workspace.Map.Sect.MainPeak.GrandStairs

local Z_IN, Z_OUT = 129.5, 148.5 -- tread span (wall side, outer side)
local RAIL_Z = 149.2

local C = {
	tread = Color3.fromHex("A39A8B"),
	treadAlt = Color3.fromHex("978E80"),
	riser = Color3.fromHex("7A7266"),
	mass = Color3.fromHex("6E6A65"),
	pad = Color3.fromHex("B3AA9A"),
	post = Color3.fromHex("8E8983"),
	cap = Color3.fromHex("C29A48"),
	lacquer = Color3.fromHex("9B2D26"),
	roof = Color3.fromHex("33403F"),
	roofEdge = Color3.fromHex("43524F"),
	wood = Color3.fromHex("5A3F2E"),
	plaque = Color3.fromHex("262F2F"),
}

local SEGMENTS = { -- along +x for the east side: kind, x0 (high end) .. x1 (low end), y0 (at x0) .. y1 (at x1)
	{ "flight", 14, 34, 649, 628 },
	{ "landing", 34, 42.5, 628 },
	{ "flight", 42.5, 66, 628, 606 },
	{ "landing", 66, 74.5, 606 },
	{ "flight", 74.5, 98, 606, 582.6 },
	{ "landing", 98, 106, 582.6 },
}

local function part(parent, name, cf, size, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end

local function wedge(parent, name, cf, size, color)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.CanTouch = false
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.Slate
	w.Parent = parent
	return w
end

local function lamp(parent, pos)
	local m = Templates.FX_StoneLantern:Clone()
	m.Name = "StoneLantern"
	local flame = m:FindFirstChild("Flame", true)
	if flame and not flame:FindFirstChildWhichIsA("Light") then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromHex("FFB56B"), 14, 1.2, false
		l.Parent = flame
	end
	m.Parent = parent
	m:PivotTo(CFrame.new(pos))
	return m
end

local function libProp(path, parent, pos, yaw, scale)
	local node = Lib
	for n in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(n)
	end
	if not node then
		warn("missing asset " .. path)
		return
	end
	local m = node:Clone()
	if scale then
		m:ScaleTo(scale)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m.Parent = parent
	local cf, size = m:GetBoundingBox()
	local pv = m:GetPivot()
	local lift = pv.Position.Y - (cf.Position.Y - size.Y / 2)
	m:PivotTo(CFrame.new(pos + Vector3.new(0, lift, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	return m
end

-- a post with a cap; lacquer posts are the accent ones at landings
local function post(parent, x, yBase, z, h, lacquer)
	local w = lacquer and 1.3 or 1.1
	part(parent, "Post", CFrame.new(x, yBase + h / 2, z), Vector3.new(w, h, w), lacquer and C.lacquer or C.post,
		lacquer and Enum.Material.Wood or Enum.Material.Slate)
	part(parent, "PostCap", CFrame.new(x, yBase + h + 0.25, z), Vector3.new(w + 0.4, 0.5, w + 0.4), C.cap,
		Enum.Material.Metal)
end

-- a beam between two points (rails), thickness t x t
local function beam(parent, name, a, b, t, color, material)
	local mid, len = (a + b) / 2, (b - a).Magnitude
	return part(parent, name, CFrame.lookAt(mid, b), Vector3.new(t, t, len), color, material)
end

local function buildFlight(parent, s, xHigh, xLow, yHigh, yLow)
	-- s = +1 east, -1 west; x values are the east-side magnitudes
	local run = xLow - xHigh
	local rise = yHigh - yLow
	local n = math.max(2, math.round(rise / 1.5))
	local stepRun, stepRise = run / n, rise / n
	local width = Z_OUT - Z_IN
	local zc = (Z_IN + Z_OUT) / 2
	for i = 1, n do
		-- step i counted from the bottom: its tread top at yLow + i * stepRise, spanning x from
		-- xLow - (i - 1) * stepRun (front nosing) to xLow - i * stepRun (back)
		local xFront = xLow - (i - 1) * stepRun
		local xBack = xLow - i * stepRun
		local top = yLow + i * stepRise
		local h = stepRise + 1.2
		local cx = s * (xFront + xBack) / 2
		part(parent, "Step", CFrame.new(cx, top - h / 2, zc), Vector3.new(stepRun + 0.05, h, width),
			i % 2 == 0 and C.tread or C.treadAlt, Enum.Material.Slate, false)
	end
	-- a stone slab under the steps following the slope (a cliff stair: open underneath, the cliff shows)
	local under = 1.2 -- the steps' blocks reach this far under their treads
	local a0 = Vector3.new(s * xLow, yLow - under - 1.2, zc)
	local a1 = Vector3.new(s * xHigh, yHigh - under - 1.2, zc)
	local slen = (a1 - a0).Magnitude
	part(parent, "Stringer", CFrame.lookAt((a0 + a1) / 2, a1), Vector3.new(width + 0.8, 2.6, slen + 1.5), C.mass)
	-- the outer face gets a lighter fascia strip so the flight reads as a built thing against the rock
	local f0 = Vector3.new(s * xLow, yLow - under - 0.6, Z_OUT + 0.45)
	local f1 = Vector3.new(s * xHigh, yHigh - under - 0.6, Z_OUT + 0.45)
	part(parent, "Fascia", CFrame.lookAt((f0 + f1) / 2, f1), Vector3.new(0.4, 1.4, (f1 - f0).Magnitude + 1.5),
		C.riser)
	-- the walkable ramp on the nosing line (invisible)
	local a = Vector3.new(s * xLow, yLow + 0.05, zc)
	local b = Vector3.new(s * xHigh, yHigh + 0.05, zc)
	local len = (b - a).Magnitude
	local ramp = part(parent, "Ramp", CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.5, 0),
		Vector3.new(width, 1, len + 0.6), C.tread, Enum.Material.SmoothPlastic)
	ramp.Transparency = 1
	ramp.CastShadow = false
	-- outer balustrade: stone posts every ~4.5 studs and a rail following the slope
	local nPosts = math.max(2, math.round(run / 4.5))
	local prevTop
	for k = 0, nPosts do
		local x = xLow - run * k / nPosts
		local y = yLow + rise * k / nPosts
		post(parent, s * x, y - 0.5, RAIL_Z, 3.6, false)
		local topP = Vector3.new(s * x, y + 3.0, RAIL_Z)
		if prevTop then
			beam(parent, "Rail", prevTop, topP, 0.55, C.post)
			beam(parent, "RailLow", prevTop - Vector3.new(0, 1.6, 0), topP - Vector3.new(0, 1.6, 0), 0.35, C.post)
		end
		prevTop = topP
	end
	-- a low stone curb on the wall side, so the steps meet the cliff on a line
	beam(parent, "Curb", Vector3.new(s * xLow, yLow + 0.4, Z_IN - 0.5), Vector3.new(s * xHigh, yHigh + 0.4, Z_IN - 0.5),
		1.0, C.riser)
end

local function buildLanding(parent, s, x0, x1, y, isFoot)
	local zc = (Z_IN + Z_OUT) / 2
	local width = Z_OUT - Z_IN
	local z0, z1 = Z_IN, Z_OUT + (isFoot and 2.5 or 1.2)
	local h = isFoot and (y - (582 - 1.5)) or 3.0
	part(parent, isFoot and "FootPad" or "Landing", CFrame.new(s * (x0 + x1) / 2, y - h / 2, (z0 + z1) / 2),
		Vector3.new(x1 - x0, h, z1 - z0), C.pad, Enum.Material.Slate)
	if not isFoot then
		-- stepped corbels under the landing, tucked into the cliff
		for k, f in { 0.8, 0.55, 0.3 } do
			local ch = 2.2
			local depth = (z1 - z0) * f
			part(parent, "Corbel", CFrame.new(s * (x0 + x1) / 2, y - 3.0 - ch * (k - 0.5), z0 + depth / 2),
				Vector3.new((x1 - x0) * (0.9 - 0.15 * k), ch, depth), C.mass)
		end
	end
	-- a slightly darker border slab on the outer edge
	part(parent, "LandingEdge", CFrame.new(s * (x0 + x1) / 2, y + 0.1, z1 - 0.6), Vector3.new(x1 - x0, 0.2, 1.2),
		C.riser, Enum.Material.Slate)
	if not isFoot then
		-- red lacquer posts at the landing's outer corners, rail between them, lanterns inside the corners
		post(parent, s * x0, y, RAIL_Z, 4.2, true)
		post(parent, s * x1, y, RAIL_Z, 4.2, true)
		beam(parent, "Rail", Vector3.new(s * x0, y + 3.6, RAIL_Z), Vector3.new(s * x1, y + 3.6, RAIL_Z), 0.55, C.lacquer,
			Enum.Material.Wood)
		lamp(parent, Vector3.new(s * (x0 + 1.8), y, Z_OUT - 2.2))
		lamp(parent, Vector3.new(s * (x1 - 1.8), y, Z_OUT - 2.2))
	end
	return zc, width
end

local function paifang(parent, s, x, yBase)
	-- a lacquer gateway straddling the foot of the flight, facing along the stairs
	local zA, zB = Z_IN + 0.5, Z_OUT + 0.5
	local H = 15
	for _, z in { zA, zB } do
		part(parent, "GateBase", CFrame.new(s * x, yBase + 0.6, z), Vector3.new(2.6, 1.2, 2.6), C.post)
		part(parent, "GateColumn", CFrame.new(s * x, yBase + 1.2 + H / 2, z), Vector3.new(1.6, H, 1.6), C.lacquer,
			Enum.Material.Wood)
	end
	local span = zB - zA
	local zc = (zA + zB) / 2
	part(parent, "GateBeamLow", CFrame.new(s * x, yBase + 1.2 + H - 3.2, zc), Vector3.new(1.2, 1.0, span + 1), C.lacquer,
		Enum.Material.Wood)
	part(parent, "GatePlaque", CFrame.new(s * x, yBase + 1.2 + H - 1.6, zc), Vector3.new(0.5, 2.2, 6), C.plaque,
		Enum.Material.Wood)
	part(parent, "GatePlaqueTrim", CFrame.new(s * x, yBase + 1.2 + H - 1.6, zc), Vector3.new(0.4, 2.6, 6.4), C.cap,
		Enum.Material.Metal)
	part(parent, "GateBeamTop", CFrame.new(s * x, yBase + 1.2 + H, zc), Vector3.new(1.4, 1.2, span + 5), C.lacquer,
		Enum.Material.Wood)
	part(parent, "GateRoof", CFrame.new(s * x, yBase + 2.4 + H, zc), Vector3.new(4.4, 0.8, span + 8), C.roof,
		Enum.Material.Slate)
	part(parent, "GateRoofRidge", CFrame.new(s * x, yBase + 3.1 + H, zc), Vector3.new(1.2, 0.7, span + 7), C.roofEdge,
		Enum.Material.Slate)
	for _, dz in { -1, 1 } do -- upturned eave ends
		part(parent, "GateEave", CFrame.new(s * x, yBase + 2.6 + H, zc + dz * (span / 2 + 4)) * CFrame.Angles(math.rad(dz * 18), 0, 0),
			Vector3.new(4.4, 0.6, 2), C.roof, Enum.Material.Slate)
	end
	-- the lantern pair in front of the gate
	lamp(parent, Vector3.new(s * (x + 3.5), yBase, zA + 0.8))
	lamp(parent, Vector3.new(s * (x + 3.5), yBase, zB + 0.2))
end

local function buildSide(s)
	local name = s > 0 and "FlightEast" or "FlightWest"
	local old = Stairs:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	for _, seg in SEGMENTS do
		if seg[1] == "flight" then
			buildFlight(m, s, seg[2], seg[3], seg[4], seg[5])
		else
			buildLanding(m, s, seg[2], seg[3], seg[4], seg[2] == 98)
		end
	end
	paifang(m, s, 101.5, 582.6)
	-- plants on the landings, against the cliff (where people would put them)
	libProp("Stylized Foliage + Pots/Plants + Pots/Pot & Flower", m, Vector3.new(s * 70.5, 606, Z_IN + 1.8), 0, 1.5)
	libProp("Stylized Foliage + Pots/Plants + Pots/Fern", m, Vector3.new(s * 68.5, 606, Z_IN + 2.0), 30)
	libProp("Stylized Foliage + Pots/Plants + Pots/Pot & Flower", m, Vector3.new(s * 38, 628, Z_IN + 1.8), 60, 1.2)
	m.Parent = Stairs
	return m
end

local recording = CHS:TryBeginRecording("GrandStairs")
local ok, err = pcall(function()
	-- the old flights' lone posts at the balcony end stay; only the flights are rebuilt
	buildSide(1)
	task.wait()
	buildSide(-1)
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "grand stairs built"
