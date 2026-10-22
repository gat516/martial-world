--[[
Main-peak ring terrace, waterfalls and cliff dressing (docs/systems/map.md, "Main peak"). Run in Studio Edit
mode through the MCP AFTER terrain_main_peak.luau (that script clears and rewrites the terrain this one carves
pools into). Re-runnable: it rebuilds MainPeak.Ring and re-carves the pools.

  west fall   spring from the mesa's west groove (y 639) -> step pool on the plaza ledge (614) -> down the
              lower groove into a terrace pool (-134, -16) -> a stream across the ring walk (footbridge) ->
              the rim notch (186 deg) -> the waterfall step shelf (535) -> down into the cloud sea
  east fall   from the east groove (604) into a small terrace pool (124, -6)
  shelves     the shrine on the shrine ledge with two lanterns; pines on the pine shelves are MainPeak.Pines
  towers      a few pines on the column crowns (the green on top comes from trees, never grass caps)
  terrace     three low shrub groups at the foot of the mesa, small angular stone stumps where four bridges
              meet the rim (sunk, low, sparse), fireflies over two lawns
  lamps       LanternGlow on every main-peak StoneLantern; spray, lip and mist effects at the falls
Water: Terrain Water in carved basins (pools, stream), and beams cloned from AssetLibrary VFX "Blue Waterfall"
for the falling sheets. Effects are ServerStorage.AmbientFX clones (placement guide: docs/systems/world.md).
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local terrain = workspace.Terrain
local MainPeak = workspace.Map.Sect.MainPeak
local Lib = SS.AssetLibrary
local FX = SS:FindFirstChild("AmbientFX")
local TERRACE_Y, LEDGE_Y = 582, 614

local ROCK = { Color3.fromHex("7F7A74"), Color3.fromHex("706B66"), Color3.fromHex("615D59") }
local WATER_TINT = Color3.fromHex("7FC4D4")

local Ring

local function folder(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function part(parent, name, cf, size, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Rock
	p.Parent = parent
	return p
end

local function hash(a, b)
	return (math.sin(a * 12.9898 + b * 78.233) * 43758.5453) % 1
end

-- angular stone stumps like the column rock: a few upright prisms of different heights, sunk into the ground
local function stumps(parent, centre, n, size, seed, groundY)
	for i = 1, n do
		local h = hash(seed, i)
		local ang = 2 * math.pi * hash(seed + 3, i)
		local off = (i == 1) and Vector3.zero or Vector3.new(math.cos(ang), 0, math.sin(ang)) * size * (0.7 + 0.5 * h)
		local w = size * ((i == 1) and 1 or (0.45 + 0.35 * h))
		local tall = w * (0.7 + 0.8 * hash(seed + 7, i))
		local pos = centre + off
		local y = (groundY or pos.Y) - 0.5
		part(parent, "Stone", CFrame.new(pos.X, y + tall / 2, pos.Z) * CFrame.Angles(0, ang, math.rad((h - 0.5) * 8)),
			Vector3.new(w, tall, w * (0.8 + 0.3 * h)), ROCK[1 + (i % 3)], Enum.Material.Rock)
	end
end

local function libClone(path, parent, pos, yaw, scale)
	local node = Lib
	for n in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(n)
	end
	if not node then
		warn("missing asset " .. path)
		return nil
	end
	local m = node:Clone()
	if m:IsA("BasePart") then
		local w = Instance.new("Model")
		w.Name = m.Name
		m.Parent = w
		m = w
	end
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

local function fx(name, parent, cf, size)
	if not FX or not FX:FindFirstChild(name) then
		-- templates not synced yet: leave a named spot for the vfx pass
		local p = part(parent, "FX_" .. name, cf, size or Vector3.one, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
		p.Transparency = 1
		return p
	end
	local p = FX[name]:Clone()
	p.CFrame = cf
	if size then
		p.Size = size
	end
	p.Parent = parent
	return p
end

-- --- falling water -------------------------------------------------------------------------------------------

local SHEET = Lib.VFX["Blue Waterfall"]
local SHEET_PIVOT = SHEET:GetPivot()
local function findAttachment(root, name)
	for _, d in root:GetDescendants() do
		if d:IsA("Attachment") and d.Name == name then
			return d
		end
	end
end
local SHEET_TOP = findAttachment(SHEET, "Top")
local SHEET_BOTTOM = findAttachment(SHEET, "Bottom")

-- a falling sheet of water from top to bottom, facing `out` (horizontal, away from the rock), `width` wide:
-- the AssetLibrary "Blue Waterfall" (beams + splash emitters) scaled to the drop and turned to face out
local SHEET_SIZE = select(2, SHEET:GetBoundingBox())
local function fall(parent, name, top, bottom, out, width)
	local h = top.Y - bottom.Y
	local m = SHEET:Clone()
	m.Name = name
	m:ScaleTo(math.max(0.15, h / SHEET_SIZE.Y))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("Light") then
			d:Destroy() -- no extra lights from the asset
		end
	end
	-- face out over the drop (the asset's +Z is the side its splash and mist fall on)
	local mid = Vector3.new((top.X + bottom.X) / 2, (top.Y + bottom.Y) / 2, (top.Z + bottom.Z) / 2)
	m:PivotTo(CFrame.lookAt(mid, mid - out))
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (mid - cf.Position))
	m.Parent = parent
	-- lip at the top (front face out over the drop)
	fx("WaterfallLip", m, CFrame.lookAt(top + out * 0.4, top + out * 1.4), Vector3.new(width, 0.3, 1))
	return m
end

-- --- terrain pools ---------------------------------------------------------------------------------------------

-- edit terrain voxels in a box in place: fn(x, y, z, material, occupancy) -> new material, occupancy (or nil to
-- keep the voxel). Voxels are 4 studs; a voxel over full voxels renders its surface at centre + 4 * occupancy.
local function editVoxels(x0, x1, y0, y1, z0, z1, fn)
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)):ExpandToGrid(4)
	local mats, occs = terrain:ReadVoxels(region, 4)
	local min = region.CFrame.Position - region.Size / 2
	for ix = 1, #mats do
		for iy = 1, #mats[ix] do
			for iz = 1, #mats[ix][iy] do
				local p = min + Vector3.new(ix - 0.5, iy - 0.5, iz - 0.5) * 4
				local m, o = fn(p.X, p.Y, p.Z, mats[ix][iy][iz], occs[ix][iy][iz])
				if m then
					mats[ix][iy][iz], occs[ix][iy][iz] = m, o
				end
			end
		end
	end
	terrain:WriteVoxels(region, 4, mats, occs)
end

local function level(centreY, surfaceY) -- occupancy that puts a surface at surfaceY in the voxel centred at centreY
	return math.clamp((surfaceY - centreY) / 4, 0, 1)
end

-- a basin: inside(x, z) < 1 is water (surface waterY over a mud floor), < RIM is a blade-free LeafyGrass
-- margin a little lower than the lawn, so the water's edge reads; everything above is cleared
local RIM = 1.25
local function basin(x0, x1, z0, z1, groundY, waterY, inside, waterDepth)
	waterDepth = waterDepth or 6
	editVoxels(x0, x1, groundY - 10, groundY + 4, z0, z1, function(x, y, z)
		local d = inside(x, z)
		if d >= RIM then
			return nil
		end
		if d < 1 then
			if y > waterY + 2 then
				return Enum.Material.Air, 0
			elseif y > groundY - waterDepth then
				return Enum.Material.Water, level(y, waterY) > 0 and math.max(level(y, waterY), 0.05) or 0
			end
			return Enum.Material.Mud, 1
		end
		if y > groundY - 2 then
			return Enum.Material.LeafyGrass, level(y, groundY - 0.4)
		end
		return nil
	end)
end

local function pool(cx, cz, rx, rz, waterY, depth, seed)
	local function inside(x, z)
		local a = math.atan2(z - cz, x - cx)
		local wob = 1 + 0.12 * math.sin(a * 3 + seed) + 0.08 * math.sin(a * 5 + seed * 2)
		local dx, dz = (x - cx) / (rx * wob), (z - cz) / (rz * wob)
		return dx * dx + dz * dz
	end
	local onLedge = waterY > LEDGE_Y - 2
	local ground = onLedge and LEDGE_Y or TERRACE_Y
	-- on the narrow plaza ledge only the top voxel layer holds water (deeper ones would hang out of the rock)
	basin(cx - rx * 1.6, cx + rx * 1.6, cz - rz * 1.6, cz + rz * 1.6, ground, waterY, inside, onLedge and 2.5 or depth + 3)
	return inside
end

-- a channel of water from a to b, `w` wide
local function channel(a, b, w, waterY)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = d.Magnitude
	local u = d / len
	local function inside(x, z)
		local px, pz = x - a.X, z - a.Z
		local t = math.clamp(px * u.X + pz * u.Z, 0, len)
		local qx, qz = px - u.X * t, pz - u.Z * t
		local dist = math.sqrt(qx * qx + qz * qz)
		return (dist / (w / 2)) ^ 2
	end
	basin(math.min(a.X, b.X) - w * 2, math.max(a.X, b.X) + w * 2, math.min(a.Z, b.Z) - w * 2, math.max(a.Z, b.Z) + w * 2,
		TERRACE_Y, waterY, inside)
end

-- --- the build ---------------------------------------------------------------------------------------------------

local function westFall()
	local m = folder("WestFall", Ring)
	local out = Vector3.new(-1, 0, 0)
	-- spring: the groove's mouth just under the plaza edge; a dark stone lintel and two stumps frame it
	part(m, "SpringLintel", CFrame.new(-101.2, 640.4, -16), Vector3.new(3, 1.6, 12), ROCK[3], Enum.Material.Rock)
	fall(m, "UpperFall", Vector3.new(-101.5, 639, -16), Vector3.new(-106.5, 614.3, -16), out, 6)
	-- step pool on the ledge, rimmed by low stumps on its outer side
	pool(-106.8, -16, 2.4, 5, LEDGE_Y - 0.3, 1.6, 1)
	stumps(m, Vector3.new(-112.2, LEDGE_Y, -21.5), 2, 1.6, 11, LEDGE_Y)
	stumps(m, Vector3.new(-112.4, LEDGE_Y, -10.8), 2, 1.3, 12, LEDGE_Y)
	fx("WaterfallSpray", m, CFrame.lookAt(Vector3.new(-107.5, LEDGE_Y - 0.1, -16), Vector3.new(-108.5, LEDGE_Y - 0.1, -16)),
		Vector3.new(6, 0.4, 4))
	-- lower fall down the lower groove into the terrace pool
	fall(m, "LowerFall", Vector3.new(-112.6, 613.6, -16), Vector3.new(-122, TERRACE_Y - 0.4, -16), out, 7)
	pool(-134, -16, 12, 13, TERRACE_Y - 0.5, 2.4, 2)
	fx("WaterfallSpray", m, CFrame.lookAt(Vector3.new(-123.5, TERRACE_Y - 0.4, -16), Vector3.new(-127, TERRACE_Y - 0.4, -16)),
		Vector3.new(10, 0.4, 6))
	-- the pool's edge: a few stumps where the lawn meets the water (not a ring), reeds and lily pads
	stumps(m, Vector3.new(-125.5, TERRACE_Y, -29.5), 3, 2.0, 21, TERRACE_Y)
	stumps(m, Vector3.new(-128, TERRACE_Y, -3.2), 2, 1.5, 22, TERRACE_Y)
	stumps(m, Vector3.new(-143.5, TERRACE_Y, -27), 1, 1.4, 23, TERRACE_Y)
	libClone("Stylized Foliage + Pots/Plants + Pots/Reeds", m, Vector3.new(-139, TERRACE_Y - 0.6, -28.5), 20, 1.4)
	libClone("Stylized Foliage + Pots/Plants + Pots/Reeds", m, Vector3.new(-136.5, TERRACE_Y - 0.6, -29.5), 70, 1.1)
	libClone("Stylized Foliage + Pots/Plants + Pots/Reeds", m, Vector3.new(-130, TERRACE_Y - 0.6, -3.5), 140, 1.2)
	for i, p in { Vector3.new(-137, 0, -12), Vector3.new(-139.5, 0, -18), Vector3.new(-133.5, 0, -21) } do
		local lily = libClone("Stylized Foliage + Pots/LilyPads/LilyPad W Flower", m, Vector3.new(p.X, TERRACE_Y - 0.55, p.Z), i * 70,
			0.6 + 0.15 * i)
		if lily then
			for _, d in lily:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
				end
			end
		end
	end
	-- the stream to the rim notch, under a footbridge where it crosses the ring walk
	local a, b = Vector3.new(-145.5, 0, -16.5), Vector3.new(-177.5, 0, -18.6)
	channel(a, b, 4, TERRACE_Y - 0.5)
	local fb = folder("Footbridge", m)
	local bc = Vector3.new(-158.5, TERRACE_Y + 0.55, -17.4)
	local dir = (b - a).Unit
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local deckCF = CFrame.lookAt(bc, bc + across)
	for i = -3, 3 do
		part(fb, "Plank", deckCF * CFrame.new(0, 0, i * 1.15), Vector3.new(5.2, 0.4, 1.05),
			i % 2 == 0 and Color3.fromHex("5A3F2E") or Color3.fromHex("6E4F3A"), Enum.Material.WoodPlanks)
	end
	for _, sx in { -1, 1 } do
		part(fb, "Beam", deckCF * CFrame.new(sx * 2.4, -0.5, 0), Vector3.new(0.6, 0.6, 9), Color3.fromHex("3F2C21"), Enum.Material.Wood)
		for _, sz in { -1, 1 } do
			part(fb, "Post", deckCF * CFrame.new(sx * 2.6, 1.0, sz * 3.6), Vector3.new(0.5, 2.2, 0.5), Color3.fromHex("5A3F2E"), Enum.Material.Wood)
		end
		part(fb, "Rail", deckCF * CFrame.new(sx * 2.6, 1.9, 0), Vector3.new(0.35, 0.35, 7.6), Color3.fromHex("5A3F2E"), Enum.Material.Wood)
	end
	-- the notch fall, the step shelf, the long drop into the clouds
	local notchTop = Vector3.new(-176.5, TERRACE_Y - 0.6, -18.5)
	fall(m, "NotchFall", notchTop, Vector3.new(-183.5, 536.2, -19.3), Vector3.new(-0.9945, 0, -0.1047), 6)
	fx("WaterfallSpray", m, CFrame.lookAt(Vector3.new(-183.5, 535.8, -19.3), Vector3.new(-186.5, 535.8, -19.6)), Vector3.new(8, 0.4, 5))
	fall(m, "CloudFall", Vector3.new(-188.5, 535.4, -19.8), Vector3.new(-196, 430, -20.6), Vector3.new(-0.9945, 0, -0.1047), 9)
	fx("MistWisps", m, CFrame.lookAt(Vector3.new(-205, 430, -21), Vector3.new(-215, 430, -22)), Vector3.new(40, 3, 40))
end

local function eastFall()
	local m = folder("EastFall", Ring)
	part(m, "SpringLintel", CFrame.new(113.6, 605.2, -6), Vector3.new(2.6, 1.4, 9), ROCK[3], Enum.Material.Rock)
	fall(m, "Fall", Vector3.new(115.2, 603.4, -6), Vector3.new(119.5, TERRACE_Y - 0.4, -6), Vector3.new(1, 0, 0), 5)
	pool(125, -6, 6.5, 7.5, TERRACE_Y - 0.5, 2.0, 3)
	fx("WaterfallSpray", m, CFrame.lookAt(Vector3.new(120.5, TERRACE_Y - 0.4, -6), Vector3.new(123.5, TERRACE_Y - 0.4, -6)), Vector3.new(6, 0.4, 4))
	stumps(m, Vector3.new(131.5, TERRACE_Y, 0.5), 2, 1.6, 31, TERRACE_Y)
	stumps(m, Vector3.new(120, TERRACE_Y, -14.5), 3, 1.8, 32, TERRACE_Y)
	libClone("Stylized Foliage + Pots/Plants + Pots/Reeds", m, Vector3.new(129.8, TERRACE_Y - 0.6, -12), 40, 1.1)
end

local function shrine()
	local m = folder("ShrineLedge", Ring)
	local top = Vector3.new(0, 547.3, 191.5)
	libClone("VFX/Stylized Shrine Statue", m, top, 180, 0.42)
	for _, x in { -6.5, 6.5 } do
		local l = SS._Templates.FX_StoneLantern:Clone()
		l.Name = "StoneLantern"
		local flame = l:FindFirstChild("Flame", true)
		if flame and not flame:FindFirstChildWhichIsA("Light") then
			local pl = Instance.new("PointLight")
			pl.Color, pl.Range, pl.Brightness, pl.Shadows = Color3.fromHex("FFB56B"), 12, 1, false
			pl.Parent = flame
		end
		l.Parent = m
		l:PivotTo(CFrame.new(x, 547.3, 196.5))
	end
end

-- pines on a few tower crowns: raycast for the column tops and stand a small pine on the highest near each axis
local TOWERS = { { -30, -68 }, { 36, -66 }, { 30, -120 }, { -62, -98 }, { 4, -138 } }
local function towerPines()
	local m = folder("TowerPines", Ring)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { MainPeak.Rock }
	for i, t in TOWERS do
		local best
		for dx = -6, 6, 3 do
			for dz = -6, 6, 3 do
				local h = workspace:Raycast(Vector3.new(t[1] + dx, 900, t[2] + dz), Vector3.new(0, -300, 0), params)
				if h and h.Normal.Y > 0.9 and (not best or h.Position.Y > best.Position.Y) then
					best = h
				end
			end
		end
		if best then
			libClone("Map Detailing/Pine Tree 3", m, best.Position - Vector3.new(0, 0.6, 0), i * 67, 0.32 + 0.06 * (i % 3))
		end
	end
end

-- terrace greenery and the bridgeheads' stones
local function terrace()
	local m = folder("Terrace", Ring)
	local BUSH = "Stylized Foliage + Pots/Stylized Bushes/Stylized Bush (Green)"
	-- shrub groups at the foot of the mesa / massif (big + medium + small), quiet lawn between them
	local groups = {
		{ Vector3.new(-122, TERRACE_Y, 52), 0.7 }, { Vector3.new(118, TERRACE_Y, 62), 0.6 }, { Vector3.new(-96, TERRACE_Y, -112), 0.65 },
	}
	for gi, g in groups do
		local c, s = g[1], g[2]
		local dir = Vector3.new(c.X, 0, c.Z).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		libClone(BUSH, m, c - Vector3.new(0, 0.6, 0), gi * 40, s)
		libClone(BUSH, m, c + side * 7 + dir * 2 - Vector3.new(0, 0.6, 0), gi * 40 + 90, s * 0.62)
		libClone(BUSH, m, c - side * 5 + dir * 4 - Vector3.new(0, 0.6, 0), gi * 40 + 200, s * 0.4)
	end
	-- where four of the bridges meet the rim: low stone stumps on one side of the landing
	for i, ang in { 22.5, 157.5, 247.5, 337.5 } do
		local a = math.rad(ang)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-d.Z, 0, d.X) * ((i % 2 == 0) and 1 or -1)
		stumps(m, d * 174 + side * 11 + Vector3.new(0, TERRACE_Y, 0), 3, 1.8, 40 + i, TERRACE_Y)
	end
	-- fireflies over two quiet lawns (by the west pool, by the south-west shrubs)
	fx("Fireflies", m, CFrame.new(-140, TERRACE_Y + 3, 10), Vector3.new(24, 5, 24))
	fx("Fireflies", m, CFrame.new(-125, TERRACE_Y + 3, 60), Vector3.new(24, 5, 24))
end

-- a LanternGlow on every StoneLantern of the main peak (plaza, stairs, shrine)
local function lanternGlows()
	if not FX or not FX:FindFirstChild("LanternGlow") then
		return
	end
	for _, d in MainPeak:GetDescendants() do
		if d:IsA("Model") and d.Name == "StoneLantern" and not d:FindFirstChild("LanternGlow") then
			local g = FX.LanternGlow:Clone()
			g.Parent = d
			g:PivotTo(d:GetPivot() * CFrame.new(g:GetAttribute("MountOffset")))
		end
	end
end

local recording = CHS:TryBeginRecording("DressMainPeak")
local ok, err = pcall(function()
	for _, n in { "Waterfalls", "RingLanterns", "Ring" } do
		local old = MainPeak:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	Ring = folder("Ring", MainPeak)
	westFall()
	task.wait()
	eastFall()
	shrine()
	towerPines()
	terrace()
	lanternGlows()
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "main peak dressed"
