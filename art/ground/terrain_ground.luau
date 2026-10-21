--[[
Under-sect forest floor: fills the void under the main peak and the spirit peaks with smooth Terrain,
blended into the wilds ground around it. Run in Studio Edit mode (MCP execute_luau); re-runnable.

  _G.TERRAIN_GROUND = { remask = false }   -- remask: forget the saved mask and measure the void again
                                            -- (only right after clearing this fill, or it finds nothing)

What it does:
  1. Mask: the 4-stud columns (r < MAX_R) where the ground had no terrain at all. Measured once and kept in
     Map.Ground.GroundFillMask (StringValue, run-length), so re-runs rewrite exactly the same columns and never
     touch the terrain that was already there (the wilds rim, the ridge "spokes" between the peaks, the gate
     courtyard, the karst spires).
  2. Height: a smooth membrane (relaxed Laplace) from the heights of the surrounding ground, pulled down toward a
     gently rolling forest floor (FLOOR_Y + noise) with distance from that ground, so the fill meets every edge at
     its height and settles lower inside.
  3. Talus: against every peak's rock base (radial profile raycast at y 12) the ground rises in an apron of
     Mud / Ground that buries the mesh seam. The path through the slot keeps it low.
  4. Path: a paved path (Pavement, dirt edges) from the gate courtyard north to the Ascension Array at the main peak's foot (0, 6, 236).
  5. Knolls: three clusters of grassy mounds (OUTCROPS), big + medium + small.
Left open for karst pillars (Map.Karst): (262, 211), (210, -265), (-345, 41), (-43, -344), (340, -41), each a
flat pocket ~40-45 studs across between two spirit pillars at r ~340.
Only stylized terrain materials (Grass, LeafyGrass, Ground, Mud, Pavement have MaterialService overrides).
Writes the voxel band y BAND_Y0..BAND_Y1 of the masked columns only (air above the new surface, so lowering a
height works on re-run). Where an old terrain spire hangs over a masked column with its underside below JOIN_Y1, the
column is filled solid up to it in the spire's own material, so the spire stands on the floor.

Terrain material colours are global and owned by the main-peak pass: this script never sets them.
Grass decoration is left as it is.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local CFG = _G.TERRAIN_GROUND or {}

local CELL = 4 -- voxel / mask cell size (studs)
local HALF = 472 -- area: x, z in [-HALF, HALF)
local N = (HALF * 2) // CELL
local MAX_R = 470 -- the fill never goes past this radius from the origin
local BAND_Y0, BAND_Y1 = -40, 48 -- written voxel band (multiples of 4)
local JOIN_Y1 = 120 -- spires whose underside hangs below this are joined down to the fill...
local JOIN_MIN_R = 240 -- ...outside the main peak's foot (the old hanging columns at r ~212 stay as they are)
local PROBE_TOP, PROBE_DEPTH = 70, 140 -- void test: no terrain from y 70 down to y -70

local FLOOR_Y = 8 -- forest floor mean height
local FLOOR_NOISE = { { 110, 3.0 }, { 38, 1.2 } } -- { wavelength, amplitude }
local BLEND = 70 -- studs over which the fill eases from the surrounding ground's height to the floor
local EDGE_CAP = 30 -- surrounding heights above this (spires) are treated as this
local RELAX_ITERS = 220
local RELAX_OMEGA = 1.85

local TALUS_REACH = 18 -- scree apron width outside a rock base
local TALUS_HEIGHT = 5 -- apron height at the rock face
local TALUS_INSIDE = 4 -- extra fill under the rock (hidden; keeps the seam buried)
local PROFILE_Y = 12 -- height at which the rock bases' outlines are measured
local PROFILE_STEPS = 72

local PATH = { -- paved path: gate courtyard -> slot between Peak_8 and Peak_1 -> Ascension Array
	Vector2.new(0, 396),
	Vector2.new(3, 352),
	Vector2.new(-2, 318),
	Vector2.new(5, 288),
	Vector2.new(3, 266),
	Vector2.new(0, 250),
}
local PATH_Y = 5 -- path surface: the gate courtyard's paving and the old strip at the array are at y 5
local PATH_HALF = 5 -- paved core half-width
local PATH_BLEND = 20 -- the floor eases to the path height over this many studs either side
local CLEARING = { at = Vector2.new(0, 244), radius = 14 } -- flat paved pad round the array

local OUTCROPS = { -- { x, z, radius, height }: grassy knolls (Map.Ground.SectRoots dresses them with rocks)
	{ 46, 338, 12, 4 }, { 62, 320, 6, 2.5 }, { 30, 362, 4, 1.8 }, -- east of the path, before the slot
	{ -214, 268, 14, 5 }, { -197, 288, 7, 3 }, { -231, 250, 4, 2 }, -- under Peak_8's west side
	{ -268, -213, 12, 5 }, { -251, -229, 6, 3 }, { -283, -196, 4, 2 }, -- between Peak_5 and Peak_6
}

local terrain = workspace.Terrain
local ground = workspace.Map.Ground

local function idx(i: number, k: number): number
	return k * N + i + 1
end
local function cellX(i: number): number
	return -HALF + CELL * i + CELL / 2
end

--[[ 1. mask ]]

local function encodeMask(mask: { boolean }): string
	local runs, cur, len = {}, false, 0
	for n = 1, N * N do
		local v = mask[n] == true
		if v == cur then
			len += 1
		else
			table.insert(runs, tostring(len))
			cur, len = v, 1
		end
	end
	table.insert(runs, tostring(len))
	return table.concat(runs, ",") -- alternating runs, starting with "not masked"
end

local function decodeMask(s: string): { boolean }
	local mask, n, cur = table.create(N * N, false), 1, false
	for token in string.gmatch(s, "%d+") do
		local len = tonumber(token) :: number
		for _ = 1, len do
			mask[n] = cur
			n += 1
		end
		cur = not cur
	end
	assert(n - 1 == N * N, "GroundFillMask has the wrong size")
	return mask
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { terrain }

local function surfaceAt(x: number, z: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, PROBE_TOP, z), Vector3.new(0, -PROBE_DEPTH, 0), terrainOnly)
end

local maskValue = ground:FindFirstChild("GroundFillMask") :: StringValue?
local mask: { boolean }
if maskValue and not CFG.remask then
	mask = decodeMask(maskValue.Value)
else
	mask = table.create(N * N, false)
	for k = 0, N - 1 do
		for i = 0, N - 1 do
			local x, z = cellX(i), cellX(k)
			if math.sqrt(x * x + z * z) < MAX_R and not surfaceAt(x, z) then
				mask[idx(i, k)] = true
			end
		end
		if k % 16 == 0 then
			task.wait()
		end
	end
	if not maskValue then
		maskValue = Instance.new("StringValue")
		maskValue.Name = "GroundFillMask"
		maskValue.Parent = ground
	end
	(maskValue :: StringValue).Value = encodeMask(mask)
end

local masked = 0
for n = 1, N * N do
	if mask[n] then
		masked += 1
	end
end

--[[ 2. heights ]]

local function floorY(x: number, z: number): number
	local y = FLOOR_Y
	for o, octave in FLOOR_NOISE do
		y += octave[2] * 2 * math.noise(x / octave[1], o * 7.31, z / octave[1])
	end
	return y
end

-- known heights of the surrounding ground (outside the mask)
local H = table.create(N * N, 0)
for k = 0, N - 1 do
	for i = 0, N - 1 do
		local n = idx(i, k)
		local x, z = cellX(i), cellX(k)
		if mask[n] then
			H[n] = floorY(x, z)
		else
			local hit = surfaceAt(x, z)
			H[n] = if hit then math.min(hit.Position.Y, EDGE_CAP) else floorY(x, z)
		end
	end
	if k % 16 == 0 then
		task.wait()
	end
end

-- relax the masked cells (SOR) into a membrane spanning the surrounding heights
local cells = {}
for n = 1, N * N do
	if mask[n] then
		table.insert(cells, n)
	end
end
for iter = 1, RELAX_ITERS do
	for _, n in cells do
		local i, k = (n - 1) % N, (n - 1) // N
		local l = if i > 0 then H[n - 1] else H[n]
		local r = if i < N - 1 then H[n + 1] else H[n]
		local d = if k > 0 then H[n - N] else H[n]
		local u = if k < N - 1 then H[n + N] else H[n]
		H[n] += RELAX_OMEGA * ((l + r + d + u) * 0.25 - H[n])
	end
	if iter % 10 == 0 then
		task.wait()
	end
end

-- distance (studs) from each masked cell to the nearest surrounding-ground cell: two-pass chamfer
local INF = 1e9
local D = table.create(N * N, 0)
for n = 1, N * N do
	D[n] = if mask[n] then INF else 0
end
local S, DG = CELL, CELL * math.sqrt(2)
for k = 0, N - 1 do
	for i = 0, N - 1 do
		local n = idx(i, k)
		if mask[n] then
			local v = D[n]
			if i > 0 then v = math.min(v, D[n - 1] + S) end
			if k > 0 then
				v = math.min(v, D[n - N] + S)
				if i > 0 then v = math.min(v, D[n - N - 1] + DG) end
				if i < N - 1 then v = math.min(v, D[n - N + 1] + DG) end
			end
			D[n] = v
		end
	end
end
for k = N - 1, 0, -1 do
	for i = N - 1, 0, -1 do
		local n = idx(i, k)
		if mask[n] then
			local v = D[n]
			if i < N - 1 then v = math.min(v, D[n + 1] + S) end
			if k < N - 1 then
				v = math.min(v, D[n + N] + S)
				if i < N - 1 then v = math.min(v, D[n + N + 1] + DG) end
				if i > 0 then v = math.min(v, D[n + N - 1] + DG) end
			end
			D[n] = v
		end
	end
end
task.wait()

-- rock bases: radial outline of each pillar and of the main peak's rock, at PROFILE_Y
type Base = { c: Vector2, prof: { number } }
local bases: { Base } = {}
local function addBase(model: Instance, center: Vector2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local prof = {}
	local last = 0
	for s = 0, PROFILE_STEPS - 1 do
		local a = s / PROFILE_STEPS * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local origin = Vector3.new(center.X, PROFILE_Y, center.Y) + dir * 420
		local hit = workspace:Raycast(origin, -dir * 420, params)
		if hit then
			last = (Vector2.new(hit.Position.X, hit.Position.Z) - center).Magnitude
		end
		prof[s + 1] = last
	end
	table.insert(bases, { c = center, prof = prof })
end
for _, peak in workspace.Map.Sect.SpiritPeaks:GetChildren() do
	local pillar = peak:FindFirstChild("Pillar")
	if pillar and pillar:IsA("Model") then
		local cf = pillar:GetBoundingBox()
		addBase(pillar, Vector2.new(cf.X, cf.Z))
	end
end
local mainRock = workspace.Map.Sect.MainPeak:FindFirstChild("Rock")
if mainRock then
	addBase(mainRock, Vector2.new(2, 2))
end

-- signed distance outside the nearest rock base (negative: under the rock)
local function rockEdge(p: Vector2): number
	local best = INF
	for _, b in bases do
		local v = p - b.c
		local r = v.Magnitude
		local a = math.atan2(v.Y, v.X) / (math.pi * 2) * PROFILE_STEPS
		a %= PROFILE_STEPS
		local a0 = math.floor(a)
		local t = a - a0
		local r0 = b.prof[a0 + 1]
		local r1 = b.prof[(a0 + 1) % PROFILE_STEPS + 1]
		local e = r - (r0 + (r1 - r0) * t)
		if e < best then
			best = e
		end
	end
	return best
end

local function pathDistance(p: Vector2): number
	local best = INF
	for s = 1, #PATH - 1 do
		local a, b = PATH[s], PATH[s + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return math.min(best, math.max(0, (p - CLEARING.at).Magnitude - CLEARING.radius))
end

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- final height and surface material per masked cell
local heightOf = table.create(N * N, 0)
local matOf = table.create(N * N, Enum.Material.Grass)
for _, n in cells do
	local i, k = (n - 1) % N, (n - 1) // N
	local x, z = cellX(i), cellX(k)
	local p = Vector2.new(x, z)
	local edgeW = 1 - smoothstep(0, BLEND, D[n]) -- 1 at the surrounding ground, 0 deep inside
	local h = floorY(x, z) + (H[n] - floorY(x, z)) * edgeW

	local dp = pathDistance(p)
	local pathW = 1 - smoothstep(PATH_HALF, PATH_HALF + PATH_BLEND, dp)
	h += (PATH_Y + 0.4 * math.noise(x / 14, 3.3, z / 14) * (1 - pathW) - h) * pathW

	local e = rockEdge(p)
	local talus = 0
	if e < 0 then
		talus = TALUS_HEIGHT + TALUS_INSIDE * math.min(1, -e / 12)
	elseif e < TALUS_REACH then
		local wob = 1 + 0.35 * math.noise(x / 9, 1.7, z / 9)
		talus = TALUS_HEIGHT * (1 - e / TALUS_REACH) ^ 1.5 * wob
	end
	h += talus * (1 - pathW * 0.85)

	local rockiness = 0
	for _, o in OUTCROPS do
		local d = (p - Vector2.new(o[1], o[2])).Magnitude
		if d < o[3] then
			local q = 1 - (d / o[3]) ^ 2
			h += o[4] * q * (1 + 0.25 * math.noise(x / 5, 9.1, z / 5))
			rockiness = math.max(rockiness, q)
		end
	end

	local n1 = math.noise(x / 60, 7.7, z / 60)
	local n2 = math.noise(x / 11, 2.1, z / 11)
	local mat = if n1 > 0.04 then Enum.Material.LeafyGrass else Enum.Material.Grass
	-- only the stylized materials (MaterialService overrides): Rock and Slate still have the default look
	if rockiness > 0.55 and n2 > -0.1 then
		mat = Enum.Material.Ground
	elseif dp < PATH_HALF + n2 * 3 then
		mat = Enum.Material.Pavement
	elseif dp < PATH_HALF + 2.5 + n2 * 4 then
		mat = Enum.Material.Ground
	elseif e < 5 + n2 * 4 then
		mat = Enum.Material.Mud
	elseif e < 11 + n2 * 6 then
		mat = if n2 > 0.05 then Enum.Material.Ground else Enum.Material.Mud
	elseif e < 16 + n2 * 8 and n1 < 0.1 then
		mat = Enum.Material.Ground
	end
	heightOf[n] = h
	matOf[n] = mat
end
task.wait()

--[[ 3. write ]]

local recording = ChangeHistoryService:TryBeginRecording("TerrainGround")
local CHUNK = 32 -- cells per chunk side
local layers = (BAND_Y1 - BAND_Y0) // CELL
local written, joined = 0, 0
local joinLayers = (JOIN_Y1 - BAND_Y1) // CELL
for k0 = 0, N - 1, CHUNK do
	for i0 = 0, N - 1, CHUNK do
		local ci, ck = math.min(CHUNK, N - i0), math.min(CHUNK, N - k0)
		local any = false
		for k = k0, k0 + ck - 1 do
			for i = i0, i0 + ci - 1 do
				if mask[idx(i, k)] then
					any = true
					break
				end
			end
			if any then
				break
			end
		end
		if any then
			local x0, z0 = -HALF + i0 * CELL, -HALF + k0 * CELL
			local region = Region3.new(Vector3.new(x0, BAND_Y0, z0), Vector3.new(x0 + ci * CELL, BAND_Y1, z0 + ck * CELL))
			local joinRegion = Region3.new(Vector3.new(x0, BAND_Y1, z0), Vector3.new(x0 + ci * CELL, JOIN_Y1, z0 + ck * CELL))
			local mats, occs = terrain:ReadVoxels(region, CELL)
			local jmats, joccs = terrain:ReadVoxels(joinRegion, CELL)
			local joinChanged = false
			for di = 1, ci do
				for dk = 1, ck do
					local n = idx(i0 + di - 1, k0 + dk - 1)
					if mask[n] then
						local h, top = heightOf[n], matOf[n]
						-- terrain hanging just above this column (a spire whose base never reached the ground):
						-- carry the spire's own material down so it stands on the floor
						local underside, spireMat = nil, nil
						local cx, cz = cellX(i0 + di - 1), cellX(k0 + dk - 1)
						for j = 1, if cx * cx + cz * cz >= JOIN_MIN_R * JOIN_MIN_R then joinLayers else 0 do
							if joccs[di][j][dk] > 0.3 and jmats[di][j][dk] ~= Enum.Material.Air and jmats[di][j][dk] ~= Enum.Material.Water then
								underside, spireMat = BAND_Y1 + (j - 1) * CELL, jmats[di][j][dk]
								break
							end
						end
						for j = 1, layers do
							local yb = BAND_Y0 + (j - 1) * CELL
							local occ = math.clamp((h - yb) / CELL, 0, 1)
							if underside and yb + CELL > h then
								mats[di][j][dk] = spireMat
								occs[di][j][dk] = 1
							elseif occ < 0.04 then
								mats[di][j][dk] = Enum.Material.Air
								occs[di][j][dk] = 0
							else
								local depth = h - (yb + CELL)
								mats[di][j][dk] = if depth < 4 then top
									elseif depth < 14 then Enum.Material.Ground
									else Enum.Material.Rock
								occs[di][j][dk] = occ
							end
						end
						if underside then
							for j = 1, joinLayers do
								if BAND_Y1 + (j - 1) * CELL >= underside then
									break
								end
								jmats[di][j][dk] = spireMat
								joccs[di][j][dk] = 1
								joinChanged = true
							end
							joined += 1
						end
						written += 1
					end
				end
			end
			terrain:WriteVoxels(region, CELL, mats, occs)
			if joinChanged then
				terrain:WriteVoxels(joinRegion, CELL, jmats, joccs)
			end
			task.wait()
		end
	end
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

return string.format("masked %d cells, wrote %d columns (%d joined to a spire above), %d rock bases", masked, written, joined, #bases)
