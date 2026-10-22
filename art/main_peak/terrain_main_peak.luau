--[[
Main-peak walkable floors as smooth Terrain (docs/systems/map.md, "Main peak"). Run in Studio Edit mode through
the MCP after place_main_peak.luau. Re-runnable: it clears the main peak's terrain and writes it again.

Reads the outlines art/main_peak/build_main_peak.py exports (MainPeakRock.json, "terrain" and "anchors"),
fetched over loopback HTTP (set _G.MAIN_PEAK_JSON_URL, e.g. "http://127.0.0.1:8793/art/main_peak/MainPeakRock.json",
served by `python3 -m http.server 8793 --bind 127.0.0.1` from the repo root), or pass the decoded table in
_G.MAIN_PEAK_JSON.

  terrace  Grass out to the rim (less a little, the mesh turf lip covers the edge), the ring walk in
           Cobblestone, surface at Y 582; the rock under it is sunk TERRAIN_SINK in the mesh
  ledge    the plaza ledge (Y 614) as Grass out to its edge, none on the south where there is no ledge, and only
           over the rock's sunk ledge flat (never past its lip)
  shelves  off (SHELF_BASINS): every cliff shelf stays bare stone, like the shrine ledge
Pools, streams and their basins are dress_main_peak.luau's (it carves into this terrain).

Global terrain colours (Terrain:SetMaterialColor is place-wide; spirit peaks use the same) are set here too and
listed in map.md. Terrain decoration (grass blades) stays off: Workspace.Terrain.Decoration isn't scriptable
from the MCP, so it is a manual Studio setting (Terrain > Decoration unticked).
]]

local HttpService = game:GetService("HttpService")
local CHS = game:GetService("ChangeHistoryService")
local terrain = workspace.Terrain

local data = _G.MAIN_PEAK_JSON
	or HttpService:JSONDecode(HttpService:GetAsync(_G.MAIN_PEAK_JSON_URL or "http://127.0.0.1:8793/art/main_peak/MainPeakRock.json"))
local T = data.terrain
local N = T.n

local VOXEL = 4
local CLEAR_RADIUS = 203 -- spirit peaks (r 300) and their terrain start beyond ~240
local CLEAR_BOTTOM, CLEAR_TOP = 430, 900

local COLORS = { -- the map palette, picked for the textured materials (they read darker than plastic)
	Grass = Color3.fromHex("7E9C63"),
	LeafyGrass = Color3.fromHex("66804F"), -- blade-free borders beside paving and the rim (its texture reads brighter than Grass)
	Ground = Color3.fromHex("7A6A55"),
	Mud = Color3.fromHex("5E5244"),
	Rock = Color3.fromHex("7A7570"),
	Slate = Color3.fromHex("7A746D"), -- 8A847D read pale and washed out at night beside the rock meshes
	Basalt = Color3.fromHex("615D59"),
	Cobblestone = Color3.fromHex("A39A8B"),
	Pavement = Color3.fromHex("B3AA9A"),
	Sand = Color3.fromHex("B9AC8F"),
}

-- outline lookups (world angle atan2(z, x), sampled every 360/N degrees)
local function sample(list, a)
	local f = (a % (2 * math.pi)) / (2 * math.pi) * N
	local i0 = math.floor(f) % N
	local i1 = (i0 + 1) % N
	local t = f - math.floor(f)
	local v0, v1 = list[i0 + 1], list[i1 + 1]
	if type(v0) == "table" then
		local out = {}
		for k = 1, #v0 do
			out[k] = v0[k] + (v1[k] - v0[k]) * t
		end
		return out
	end
	return v0 + (v1 - v0) * t
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

-- occupancy from signed distances (studs, positive = inside) from a voxel's centre to the nearest side and to
-- the top. Measured in Studio: a voxel with full voxels under it renders its surface at centre + 4 * occupancy,
-- so a surface d above the centre needs occupancy d / 4 (not d / 4 + 0.5).
local function occ(dSide, dTop)
	return clamp01(math.min(dSide, dTop) / VOXEL)
end

local function writeRegion(x0, x1, y0, y1, z0, z1, fn)
	-- fn(x, y, z) -> material, occupancy for the voxel centred at (x, y, z)
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x1, y1, z1)):ExpandToGrid(VOXEL)
	local size = region.Size / VOXEL
	local min = region.CFrame.Position - region.Size / 2
	local mats, occs = {}, {}
	for ix = 1, size.X do
		mats[ix], occs[ix] = {}, {}
		for iy = 1, size.Y do
			mats[ix][iy], occs[ix][iy] = {}, {}
			for iz = 1, size.Z do
				local p = min + (Vector3.new(ix, iy, iz) - Vector3.new(0.5, 0.5, 0.5)) * VOXEL
				local m, o = fn(p.X, p.Y, p.Z)
				if o <= 0 then
					m, o = Enum.Material.Air, 0
				end
				mats[ix][iy][iz], occs[ix][iy][iz] = m, o
			end
		end
		if ix % 16 == 0 then
			task.wait()
		end
	end
	terrain:WriteVoxels(region, VOXEL, mats, occs)
end

local function clear()
	local y = CLEAR_BOTTOM
	while y < CLEAR_TOP do
		local h = math.min(48, CLEAR_TOP - y)
		terrain:FillCylinder(CFrame.new(0, y + h / 2, 0), h, CLEAR_RADIUS, Enum.Material.Air)
		y += h
		task.wait()
	end
end

-- paved things standing on the terrace (bridgeheads, stair landings, my landings): found at run time, any
-- visible colliding part whose top is 0-2 studs above the floor out on the ring. Under them the terrain is
-- Cobblestone sunk a little below their top, and a blade-free LeafyGrass border runs round them.
local function pavedFootprints(Y)
	local out = {}
	for _, d in workspace.Map:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Transparency < 1 and d.Size.X * d.Size.Z > 20 then
			local top = d.Position.Y + d.Size.Y / 2
			local r = Vector2.new(d.Position.X, d.Position.Z).Magnitude
			if top > Y - 0.1 and top < Y + 2 and r > 100 and r < 195 then
				table.insert(out, { cf = d.CFrame, half = d.Size / 2 })
			end
		end
	end
	return out
end

-- distance (studs) outside a footprint's rectangle in plan, negative inside
local function rectDist(fp, x, z)
	local p = fp.cf:PointToObjectSpace(Vector3.new(x, fp.cf.Position.Y, z))
	local dx, dz = math.abs(p.X) - fp.half.X, math.abs(p.Z) - fp.half.Z
	return math.max(dx, dz)
end

-- the terrace: grass to the rim, the ring walk in cobble. Grass (which grows blades) stays a voxel clear of
-- anything paved and of the rim: those borders are LeafyGrass (no blades), so no grass grows over stone.
local RIM_INSET = _G.MP_RIM_INSET or -1.5 -- negative: the voxels' rounded edge droops just past the rim
local BORDER = _G.MP_BORDER or 8 -- two voxels: grass blades spill about a voxel past their own cells
local function terrace()
	local Y = T.terrace_y
	local paved = pavedFootprints(Y)
	writeRegion(-196, 196, Y - 12, Y + 2, -196, 196, function(x, y, z)
		local r = math.sqrt(x * x + z * z)
		if r > 192 then
			return nil, 0
		end
		local a = math.atan2(z, x)
		local rim0 = sample(T.rim, a)
		-- only the top voxel layer reaches past the rim (the overhang); deeper layers stay inside the rock wall,
		-- or they show as a green band down the cliff face
		local rim = rim0 - (y > Y - VOXEL and RIM_INSET or 3.0)
		local top = Y
		local p = sample(T.path, a)
		local mat
		local pd = math.huge
		for _, fp in paved do
			pd = math.min(pd, rectDist(fp, x, z))
		end
		if pd < 0.5 then
			mat, top = Enum.Material.Cobblestone, Y - 0.6
		elseif pd < 4 then
			mat = Enum.Material.Cobblestone -- a paved apron round each pad, joining it to the ring walk
		elseif r > p[1] and r < p[2] then
			mat = Enum.Material.Cobblestone
		elseif pd < BORDER or r > rim0 - BORDER or math.abs(r - p[1]) < BORDER or math.abs(r - p[2]) < BORDER then
			mat = Enum.Material.LeafyGrass
		else
			mat = Enum.Material.Grass
		end
		-- the deeper layers near the rim show through crevices in the cliff columns: Rock there, not green patches
		if y < Y - VOXEL and r > rim0 - 12 then
			mat = Enum.Material.Rock
		end
		return mat, occ(rim - r, top - y)
	end)
end

-- the plaza ledge at Y 614: grass out to its outer edge; nothing where the ledge is narrower than 3
local LEDGE_OUT, LEDGE_LIFT = _G.MP_LEDGE_OUT or 0.5, _G.MP_LEDGE_LIFT or 0.8
-- a ledge voxel column is only written where the rock's sunk ledge flat is right under it (its top within 3 studs
-- under Y): past the rock's lip, over the mesa's hollows and inside the rock there is no grass, so nothing green
-- hangs over the cliff (the outline alone let the lawn overhang the lip as a green sheet; user, 2026-10-20)
local ledgeRock = RaycastParams.new()
ledgeRock.FilterType = Enum.RaycastFilterType.Include
ledgeRock.FilterDescendantsInstances = { workspace.Map.Sect.MainPeak:WaitForChild("Rock") }
local ledgeSupport = {}
local function onLedgeRock(x, z, Y)
	local key = x .. "," .. z
	if ledgeSupport[key] == nil then
		local hit = workspace:Raycast(Vector3.new(x, Y + 10, z), Vector3.new(0, -14, 0), ledgeRock)
		ledgeSupport[key] = hit ~= nil and hit.Position.Y > Y - 3 and hit.Position.Y < Y + 0.5
	end
	return ledgeSupport[key]
end
local function ledge()
	local Y = T.ledge_y
	local cx, cz = T.plaza[1], T.plaza[2]
	writeRegion(cx - 130, cx + 130, Y - 8, Y + 2, cz - 100, cz + 100, function(x, y, z)
		local dx, dz = x - cx, z - cz
		local d = math.sqrt(dx * dx + dz * dz)
		local e = sample(T.ledge, math.atan2(dz, dx))
		if e[2] < 3 or not onLedgeRock(x, z, Y) then
			return nil, 0
		end
		-- the shelf is only 9-12 studs deep (two or three voxels), so the voxels' rounding would sink it under the
		-- rock: aim a little high and out to the edge (the turf-lip mesh hides the outer stud)
		local mat = (e[1] - d < BORDER) and Enum.Material.LeafyGrass or Enum.Material.Grass
		-- every layer reaches the edge (the columns are already limited to the rock's ledge flat, onLedgeRock): an
		-- inset lower layer left the top layer a lone 0.2-occupancy cell at the edge, which renders as a thin green
		-- curl floating over the stone. The lower layers are Rock (tinted like the mesh), so where they show on the
		-- cliff face under the lip they read as stone, not as a green band
		local edge = e[1] + LEDGE_OUT
		if y < Y - VOXEL / 2 then
			mat = Enum.Material.Rock
		end
		return mat, occ(edge - d, Y + LEDGE_LIFT - y)
	end)
end

-- the cliff shelves' basins (pine and waterfall shelves; the shrine ledge stays bare stone)
local LEDGE_RECESS = 1.2
-- off: the basin blocks leaked out between the shelves' column stumps as green cubes and drips down the cliff
-- (user, 2026-10-20); the pine and waterfall shelves stay bare stone like the shrine ledge
local SHELF_BASINS = _G.MP_SHELF_BASINS == true
local function shelves()
	if not SHELF_BASINS then
		return
	end
	for _, l in data.anchors.ledges do
		if l.kind ~= "shrine" then
			local top = l.top[2] - LEDGE_RECESS + 0.8 -- just under the stone lip around the basin
			local out = Vector3.new(l.out[1], 0, l.out[3])
			local centre = Vector3.new(l.top[1], 0, l.top[3]) - out * (l.size * 0.55 * 0.15)
			local cf = CFrame.lookAt(Vector3.new(centre.X, top - 1.5, centre.Z), Vector3.new(centre.X, top - 1.5, centre.Z) + out)
			terrain:FillBlock(cf, Vector3.new(l.half_w * 0.95, 3, l.size * 0.55 * 0.6), Enum.Material.LeafyGrass)
		end
	end
end

local recording = CHS:TryBeginRecording("MainPeakTerrain")
local ok, err = pcall(function()
	for name, c in COLORS do
		terrain:SetMaterialColor(Enum.Material[name], c)
	end
	clear()
	terrace()
	ledge()
	shelves()
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "main peak terrain written"
