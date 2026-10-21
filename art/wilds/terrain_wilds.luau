--[[
Terrain for the first two wilds zones (Inner Wilds, Ruined Borderlands): sandy paths sunk between banks,
rolling ground, hills and ridges that break each zone into pockets and channel the paths (cut into clefts
where a path crosses them), cliff-edged terraces, dry gullies, caves, and the fen / marsh pools.
Run in Studio Edit mode after art/wilds/wilds_layout.luau (it reads _G.WILDS_LAYOUT).

  _G.WILDS_TERRAIN = { zones = { "Inner", "Middle" }, dry = false, caves = true }
    dry   measure and report, write nothing
    caves carve the caves after the heightmap (default on)

Re-runnable: every column inside a zone's box is rewritten to an absolute target height (not a delta), then
the caves are carved again, so a second run gives the same ground. The target is feathered back to the
existing ground over FEATHER studs at the box edge and away from columns the pass doesn't own (the river,
the sect gate's paving). Gameplay anchors are read live and win over every landform: each
Workspace.Wilds.Zones disc keeps flat ground at the disc's height out past its Radius, each qi node keeps
its ground at its base. Only stylized terrain materials are used (Grass, LeafyGrass, Ground, Mud, Sand have
MaterialService overrides); material colours are global and never set here.

Voxel note (measured): a column's surface sits at voxelBottom + 2 + 4 * occupancy of its top voxel.
The path splines are saved to Map.Ground.WildsLayout (StringValue, JSON) for reference.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")

local LAYOUT = _G.WILDS_LAYOUT
assert(LAYOUT, "run art/wilds/wilds_layout.luau first")
local CFG = _G.WILDS_TERRAIN or {}
_G.WILDS_TERRAIN = nil

local function run(CFG)
	local ZONES = CFG.zones or { "Inner", "Middle" }
	local CELL = 4
	local Y0, Y1 = -8, 48 -- written voxel band
	local NY = (Y1 - Y0) // CELL
	local FEATHER = 36
	local KEEP_NEAR = { 3, 20 }
	local CLIFF_SLOPE = 0.95 -- rise over run above which the ground is bare cliff earth

	local terrain = workspace.Terrain
	local wilds = workspace:WaitForChild("Wilds")
	local M = Enum.Material

	local function smooth(a, b, x)
		local t = math.clamp((x - a) / (b - a), 0, 1)
		return t * t * (3 - 2 * t)
	end
	local function lerp(a, b, t)
		return a + (b - a) * t
	end
	local function fbm(x, z, octaves, seed)
		local h = 0
		for i, o in octaves do
			h += math.noise(x / o[1], z / o[1], seed + i * 7.31) * o[2] * 2
		end
		return h
	end
	local function spline(pts)
		local out = {}
		local n = #pts
		for i = 1, n - 1 do
			local p0, p1, p2, p3 = pts[math.max(i - 1, 1)], pts[i], pts[i + 1], pts[math.min(i + 2, n)]
			local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 3))
			for s = 0, steps - 1 do
				local t = s / steps
				local t2, t3 = t * t, t * t * t
				table.insert(out, 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
			end
		end
		table.insert(out, pts[n])
		return out
	end
	local function segDist(p, a, b)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		return (p - (a + ab * t)).Magnitude
	end
	local function lineDist(p, pts)
		local best = math.huge
		for s = 1, #pts - 1 do
			best = math.min(best, segDist(p, pts[s], pts[s + 1]))
		end
		return best
	end

	local anchors = {}
	for _, zone in wilds.Zones:GetChildren() do
		if zone:IsA("BasePart") then
			table.insert(anchors, { p = Vector2.new(zone.Position.X, zone.Position.Z), y = zone.Position.Y, r = (zone:GetAttribute("Radius") or 30) + 6, fade = 18 })
		end
	end
	for _, node in wilds.QiNodes:GetChildren() do
		local base = node:FindFirstChild("Base")
		if base then
			table.insert(anchors, { p = Vector2.new(base.Position.X, base.Position.Z), y = base.Position.Y - 0.6, r = 8, fade = 10 })
		end
	end

	local saved = { zones = {} }
	local report = {}

	for _, zoneName in ZONES do
		local Z = LAYOUT[zoneName]
		local seed = zoneName == "Inner" and 11 or 29
		local x0, z0, x1, z1 = Z.box[1], Z.box[2], Z.box[3], Z.box[4]
		x0, z0 = math.floor(x0 / CELL) * CELL, math.floor(z0 / CELL) * CELL
		x1, z1 = math.ceil(x1 / CELL) * CELL, math.ceil(z1 / CELL) * CELL
		local nx, nz = (x1 - x0) // CELL, (z1 - z0) // CELL
		local function idx(i, k)
			return (k - 1) * nx + i
		end

		local paths, savedPaths = {}, {}
		for _, path in Z.paths do
			local pts = spline(path.pts)
			local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
			for _, p in pts do
				minX, minZ, maxX, maxZ = math.min(minX, p.X), math.min(minZ, p.Y), math.max(maxX, p.X), math.max(maxZ, p.Y)
			end
			table.insert(paths, { w = path.w, pts = pts, bb = { minX, minZ, maxX, maxZ } })
			local flat = {}
			for _, p in pts do
				table.insert(flat, math.floor(p.X * 10) / 10)
				table.insert(flat, math.floor(p.Y * 10) / 10)
			end
			table.insert(savedPaths, { name = path.name, w = path.w, pts = flat })
		end
		saved.zones[zoneName] = { paths = savedPaths }
		local ridges = {}
		for _, r in Z.ridges or {} do
			table.insert(ridges, { pts = spline(r.pts), h = r.h, hw = r.hw })
		end
		local gullies = {}
		for _, g in Z.gullies or {} do
			table.insert(gullies, { pts = spline(g.pts), depth = g.depth, hw = g.hw })
		end

		local region = Region3.new(Vector3.new(x0, Y0, z0), Vector3.new(x1, Y1, z1))
		local mats, occs = terrain:ReadVoxels(region, CELL)

		-- existing surface and the kept mask (water, paving, empty columns)
		local h0 = table.create(nx * nz, 0)
		local keep = table.create(nx * nz, false)
		for i = 1, nx do
			for k = 1, nz do
				local top, h, water = 0, Y0, false
				for j = NY, 1, -1 do
					local m = mats[i][j][k]
					if m == M.Water then
						water = true
					elseif m ~= M.Air and occs[i][j][k] > 0 and top == 0 then
						top = j
						h = Y0 + (j - 1) * CELL + 2 + occs[i][j][k] * CELL
					end
				end
				h0[idx(i, k)] = h
				local topMat = top > 0 and mats[i][top][k] or M.Air
				-- columns with no terrain in the band are old fissures (the Middle ring had 4-8 stud wide
				-- cracks down to Y -18 across the roads): they are filled like any other column
				if water or topMat == M.Pavement or topMat == M.Cobblestone then
					keep[idx(i, k)] = true
				end
			end
		end
		local function poolAt(x, z)
			for _, pool in Z.pools or {} do
				local r = pool[3] * (1 + 0.18 * math.noise(x / 9, z / 9, 3.3))
				local d = (Vector2.new(x, z) - Vector2.new(pool[1], pool[2])).Magnitude
				if d < r + 6 then
					return pool, d, r
				end
			end
			return nil
		end
		for i = 1, nx do
			for k = 1, nz do
				if poolAt(x0 + (i - 0.5) * CELL, z0 + (k - 0.5) * CELL) then
					keep[idx(i, k)] = false -- our own pools, water and all
				end
			end
		end
		-- chamfer distance (cells) to the nearest kept column
		local dist = table.create(nx * nz, 99)
		for n = 1, nx * nz do
			if keep[n] then
				dist[n] = 0
			end
		end
		for _ = 1, 2 do
			for k = 1, nz do
				for i = 1, nx do
					local n = idx(i, k)
					local d = dist[n]
					if i > 1 then d = math.min(d, dist[n - 1] + 1) end
					if k > 1 then d = math.min(d, dist[n - nx] + 1) end
					if i > 1 and k > 1 then d = math.min(d, dist[n - nx - 1] + 1.414) end
					if i < nx and k > 1 then d = math.min(d, dist[n - nx + 1] + 1.414) end
					dist[n] = d
				end
			end
			for k = nz, 1, -1 do
				for i = nx, 1, -1 do
					local n = idx(i, k)
					local d = dist[n]
					if i < nx then d = math.min(d, dist[n + 1] + 1) end
					if k < nz then d = math.min(d, dist[n + nx] + 1) end
					if i < nx and k < nz then d = math.min(d, dist[n + nx + 1] + 1.414) end
					if i > 1 and k < nz then d = math.min(d, dist[n + nx - 1] + 1.414) end
					dist[n] = d
				end
			end
		end

		-- pass 1: target heights
		local H = table.create(nx * nz, 0)
		local info = table.create(nx * nz, false)
		local raisedMax, loweredMax = 0, 0
		for i = 1, nx do
			for k = 1, nz do
				local n = idx(i, k)
				local x, z = x0 + (i - 0.5) * CELL, z0 + (k - 0.5) * CELL
				if keep[n] then
					H[n] = h0[n]
					continue
				end
				local p = Vector2.new(x, z)

				local dPath, wPath = math.huge, 6
				for _, path in paths do
					local bb = path.bb
					if x > bb[1] - 70 and x < bb[3] + 70 and z > bb[2] - 70 and z < bb[4] + 70 then
						local pts = path.pts
						for s = 1, #pts - 1 do
							local d = segDist(p, pts[s], pts[s + 1])
							if d - path.w / 2 < dPath - wPath / 2 then
								dPath, wPath = d, path.w
							end
						end
					end
				end
				local half = wPath / 2 * (1 + 0.16 * math.noise(x / 11, z / 11, seed + 1))
				local edge = dPath - half

				local quiet = smooth(-2, 10, edge)
				local t = Z.base + fbm(x, z, Z.noise, seed) * (0.35 + 0.65 * quiet)
				if edge > 0 then
					local bank = smooth(3, 16, edge) * (1 - smooth(26, 60, edge))
					t += Z.bank * bank * (0.55 + 0.45 * math.noise(x / 37, z / 37, seed + 2))
				else
					t -= 0.35 * smooth(0, -half, edge)
				end
				local pathFade = smooth(2, 12, edge) -- landforms are cut back to the path's height beside it

				-- hills and ridges (plateau-ish profile, warped outline, height varying along the spine)
				local hill = 0
				for _, r in ridges do
					local d = lineDist(p, r.pts)
					local hw = r.hw * (1 + 0.3 * math.noise(x / 26, z / 26, seed + 3))
					if d < hw then
						local s = smooth(0, 0.65, 1 - d / hw)
						local along = 0.7 + 0.3 * math.noise(x / 40, z / 40, seed + 4) + 0.12 * math.noise(x / 9, z / 9, seed + 15)
						hill = math.max(hill, r.h * s * along)
					end
				end
				t += hill * pathFade

				-- gullies
				for _, g in gullies do
					local d = lineDist(p, g.pts)
					local hw = g.hw * (1 + 0.2 * math.noise(x / 17, z / 17, seed + 16))
					if d < hw then
						local s = smooth(0, 0.7, 1 - d / hw)
						t -= g.depth * s * lerp(0.3, 1, pathFade)
					end
				end

				-- bowls (flat floor, optional rim)
				for _, b in Z.bowls or {} do
					local d = (p - Vector2.new(b[1], b[2])).Magnitude
					local rim = b[4] * (1 + 0.12 * math.noise(x / 13, z / 13, seed + 5))
					if d < rim then
						local s = 1 - smooth(b[3], rim, d)
						t = lerp(t, Z.base + 0.3 * math.noise(x / 8, z / 8, seed + 17), s)
						if b[5] > 0 then
							t += b[5] * math.sin(math.clamp((d - b[3]) / (rim - b[3]), 0, 1) * math.pi) * pathFade
						end
					end
				end

				-- terraces and knolls (absolute tops)
				local onKnoll = 0
				for _, kn in Z.knolls or {} do
					local d = (p - Vector2.new(kn[1], kn[2])).Magnitude
					local outer = kn[4] * (1 + 0.2 * math.noise(x / 14, z / 14, seed + 6))
					if d < outer then
						local inner = kn[3] * (1 + 0.15 * math.noise(x / 10, z / 10, seed + 18))
						local s = kn[6] and (1 - smooth(inner, inner + (outer - inner) * 0.45, d)) or (1 - smooth(inner, outer, d))
						local top = kn[5] + 0.4 * math.noise(x / 9, z / 9, seed + 7)
						t = math.max(t, lerp(t, top, s * lerp(0.15, 1, pathFade)))
						onKnoll = math.max(onKnoll, s)
					end
				end

				for _, f in Z.flats or {} do
					local d = (p - Vector2.new(f[1], f[2])).Magnitude
					t = lerp(t, f[4], 1 - smooth(f[3], f[3] + 14, d))
				end

				-- gameplay anchors win
				for _, a in anchors do
					local d = (p - a.p).Magnitude
					if d < a.r + a.fade then
						local s = 1 - smooth(a.r, a.r + a.fade, d)
						t = lerp(t, a.y + 0.25 * math.noise(x / 12, z / 12, seed + 8), s)
					end
				end

				local pool, pd, pr = poolAt(x, z)
				local waterTop
				if pool then
					if pd < pr then
						t = lerp(pool[4], math.min(t, pool[5] - 0.6), smooth(pr - 4, pr, pd))
						waterTop = pool[5]
					else
						t = math.min(t, lerp(pool[5] + 0.3, t, smooth(pr, pr + 6, pd)))
					end
				end

				local inset = math.min(x - x0, x1 - x, z - z0, z1 - z)
				local w = smooth(0, FEATHER, inset) * smooth(KEEP_NEAR[1], KEEP_NEAR[2], dist[n] * CELL)
				local h = math.min(lerp(h0[n], t, w), Y1 - 3)
				H[n] = h
				raisedMax = math.max(raisedMax, h - h0[n])
				loweredMax = math.min(loweredMax, h - h0[n])
				info[n] = { edge = edge, dPath = dPath, half = half, wPath = wPath, onKnoll = onKnoll, pool = pool, pd = pd, pr = pr, waterTop = waterTop, hill = hill }
			end
			if i % 32 == 0 then
				task.wait()
			end
		end

		-- pass 2: materials (slope from the final heights) and the voxel write
		local pathMat, edgeMat, cliffMat = M[Z.pathMat], M[Z.edgeMat], M[Z.cliffMat or "Ground"]
		local g1, g2 = M[Z.grass[1]], M[Z.grass[2]]
		local patchMat = Z.grassPatch and M[Z.grassPatch]
		local sub = zoneName == "Inner" and M.Ground or M.Mud
		local written = 0
		for i = 1, nx do
			for k = 1, nz do
				local n = idx(i, k)
				local c = info[n]
				if not c then
					continue
				end
				local x, z = x0 + (i - 0.5) * CELL, z0 + (k - 0.5) * CELL
				local p = Vector2.new(x, z)
				local h = H[n]
				local hx = (H[idx(math.min(i + 1, nx), k)] - H[idx(math.max(i - 1, 1), k)]) / (2 * CELL)
				local hz = (H[idx(i, math.min(k + 1, nz))] - H[idx(i, math.max(k - 1, 1))]) / (2 * CELL)
				local slope = math.sqrt(hx * hx + hz * hz)

				local top
				local edgeN = 1.4 + 1.1 * math.noise(x / 7, z / 7, seed + 9)
				if c.pool and c.pd < c.pr + 4 then
					top = M.Mud
				elseif c.edge < (c.wPath <= 5 and 1.3 or 0.6) then
					-- the core is a little wider than the nominal width: 4-stud voxels need two columns to read
					top = pathMat
					if zoneName == "Middle" then
						local rut = math.abs(math.abs(c.dPath) - c.half * 0.45)
						if rut < 0.9 and math.noise(x / 16, z / 16, seed + 10) > -0.2 then
							top = M.Mud
						end
					end
				elseif slope > CLIFF_SLOPE + 0.25 * math.noise(x / 6, z / 6, seed + 19) then
					top = cliffMat
				elseif c.edge < edgeN then
					top = edgeMat
				else
					local nG = math.noise(x / 55, z / 55, seed + 11) + 0.35 * math.noise(x / 17, z / 17, seed + 12)
					top = nG > 0.05 and g2 or g1
					if patchMat and math.noise(x / 31, z / 31, seed + 13) > 0.32 then
						top = patchMat
					end
					if patchMat and dist[n] * CELL < 36 and math.noise(x / 19, z / 19, seed + 14) > -0.15 then
						top = patchMat -- the riverbank keeps some green
					end
					if c.onKnoll > 0.6 and zoneName == "Inner" then
						top = M.Grass
					end
					for _, f in Z.flats or {} do
						if (p - Vector2.new(f[1], f[2])).Magnitude < f[3] + 6 then
							top = M.Ground -- arena floors: bare packed earth
						end
					end
				end

				for j = 1, NY do
					local yb = Y0 + (j - 1) * CELL
					local old = mats[i][j][k]
					if h >= yb + 2 + CELL then
						mats[i][j][k] = (h < yb + 2 + 3 * CELL) and top or ((old ~= M.Air and old ~= M.Water) and old or sub)
						occs[i][j][k] = 1
					elseif h > yb + 2 then
						mats[i][j][k] = top
						occs[i][j][k] = math.max((h - yb - 2) / CELL, 0.05)
					elseif c.waterTop and c.waterTop > yb + 2 then
						mats[i][j][k] = M.Water
						occs[i][j][k] = math.min((c.waterTop - yb - 2) / CELL, 1)
					else
						mats[i][j][k] = M.Air
						occs[i][j][k] = 0
					end
				end
				written += 1
			end
			if i % 32 == 0 then
				task.wait()
			end
		end

		if not CFG.dry then
			terrain:WriteVoxels(region, CELL, mats, occs)
			-- caves: a chain of air balls along the heading, narrowing toward the back, then the floor
			-- re-laid flat so it walks like the ground outside
			if CFG.caves ~= false then
				for _, cave in Z.caves or {} do
					local dir = Vector3.new(math.cos(math.rad(cave.heading)), 0, math.sin(math.rad(cave.heading)))
					local side = Vector3.new(-dir.Z, 0, dir.X)
					for s = -4, cave.length, 2 do
						local f = math.clamp(s / cave.length, 0, 1)
						local r = cave.radius * (1 - 0.35 * f) * (1 + 0.12 * math.noise(s / 5, seed, 1.7))
						local wob = side * 2.2 * math.noise(s / 9, seed, 4.1)
						local centre = Vector3.new(cave.x, cave.floor + r * 0.62, cave.z) + dir * s + wob
						terrain:FillBall(centre, r, M.Air)
					end
					local floorLen = cave.length + 6
					local mid = Vector3.new(cave.x, cave.floor - 3, cave.z) + dir * (floorLen / 2 - 4)
					terrain:FillBlock(CFrame.lookAt(mid, mid + dir), Vector3.new(cave.radius * 1.5, 6, floorLen), M.Ground)
				end
			end
		end
		table.insert(report, string.format("%s: %d columns rewritten, raised up to %.1f, lowered up to %.1f", zoneName, written, raisedMax, loweredMax))
	end

	if not CFG.dry then
		local ground = workspace.Map.Ground
		local holder = ground:FindFirstChild("WildsLayout") or Instance.new("StringValue")
		holder.Name = "WildsLayout"
		local old = holder.Value ~= "" and HttpService:JSONDecode(holder.Value) or { zones = {} }
		for name, z in saved.zones do
			old.zones[name] = z
		end
		holder.Value = HttpService:JSONEncode(old)
		holder.Parent = ground
		ChangeHistoryService:SetWaypoint("Wilds terrain")
	end
	return table.concat(report, "\n")
end

_G.WildsTerrainRun = run -- re-run later with _G.WildsTerrainRun({ zones = { "Middle" } })
return run(CFG)
