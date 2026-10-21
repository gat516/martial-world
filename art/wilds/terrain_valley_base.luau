--!nocheck
-- Base terrain for the Inner Wilds valley outside the built boxes (docs/systems/map.md,
-- "Inner Wilds rework"): an even grass floor up to the wall feet, rising into them, so the
-- new walls don't stand on bare dark ground or old pools. Run in Studio Edit mode through
-- execute_luau. Re-runnable: it writes absolute heights from noise, so re-runs give the same
-- ground. The detailed pockets, paths and the new river come with the rework's
-- terrain_wilds.luau.
--
-- Also carves the border river (RIVER) between the valley and the moved Borderlands.
-- Leaves alone: the Ruined Borderlands box (feathered 36 studs into what is there; the old Inner
-- box and its old river are valley floor since the rework's phase 2, which runs terrain_wilds
-- over the whole valley afterwards), the sect-gate front, and everything within r 480 of the origin (the
-- under-sect ground). Replaces old terrain water and fills old fissures down to Y -24.
-- Materials: LeafyGrass and Grass by noise (the built zone's banks), Ground on slopes over
-- ~35 deg and under the top layer. Material colours are global and not touched.

local RES = 4
local Y0, Y1 = -24, 40
local BOUNDS = { x0 = -1020, x1 = 1020, z0 = 470, z1 = 1620 }
local KEEP = { -- {x0, x1, z0, z1}: built areas left as they are
	{ -200, 500, 1612, 1960 }, -- Ruined Borderlands box (moved south 2026-10-21)
	{ -120, 160, 470, 612 }, -- sect-gate front
}
local FEATHER = 36
local SECT_R = 480
local WALLS = { -- crest polylines (build_walls_inner.luau SEGMENTS + the test stretch)
	{ { -790, 556 }, { -620, 522 }, { -400, 505 }, { -112, 502 } },
	{ { 152, 500 }, { 270, 494 }, { 386, 500 } },
	{ { 545, 600 }, { 700, 590 }, { 840, 640 } },
	{ { 840, 640 }, { 900, 800 }, { 905, 1000 }, { 880, 1180 }, { 800, 1262 } },
	{ { 618, 1425 }, { 420, 1450 }, { 262, 1452 } },
	{ { -212, 1448 }, { -110, 1418 }, { -12, 1400 }, { 42, 1402 }, { 62, 1360 }, { 60, 1300 } },
	{ { -212, 1448 }, { -280, 1452 }, { -500, 1440 }, { -760, 1400 } },
	{ { -760, 1400 }, { -860, 1250 }, { -900, 1000 }, { -872, 742 } },
}
local BERM_H, BERM_R = 10, 80
-- the border river between the valley and the Borderlands: terrain water, surface Y 0, under the
-- stone bridge (wilds_layout Bridge: x 212, z 1566..1610)
local RIVER = { z = 1588, wiggle = 5, half = 22, bank = 14, bed = -5, water = 0, bridgeX = 212 }
local function riverDist(x, z)
	return math.abs(z - (RIVER.z + RIVER.wiggle * math.sin((x - RIVER.bridgeX) / 110)))
end
local SEED = 31

local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((ax + dx * t - px) ^ 2 + (az + dz * t - pz) ^ 2)
end
local function wallDist(x, z)
	local d = math.huge
	for _, line in WALLS do
		for i = 1, #line - 1 do
			d = math.min(d, segDist(x, z, line[i][1], line[i][2], line[i + 1][1], line[i + 1][2]))
		end
	end
	return d
end
local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
-- 0 inside a kept area or the sect, 1 at FEATHER studs outside
local function weight(x, z)
	if math.sqrt(x * x + z * z) < SECT_R then
		return 0
	end
	local w = 1
	for _, k in KEEP do
		local dx = math.max(k[1] - x, 0, x - k[2])
		local dz = math.max(k[3] - z, 0, z - k[4])
		w = math.min(w, math.sqrt(dx * dx + dz * dz) / FEATHER)
	end
	return smooth(w)
end
local function target(x, z)
	local h = 3 + math.noise(x / 160, z / 160, SEED) * 3 + math.noise(x / 45, z / 45, SEED + 3) * 0.8
	local d = wallDist(x, z)
	return h + BERM_H * (1 - smooth(d / BERM_R))
end

local terrain = workspace.Terrain
local CHUNK = 128
local written = 0
for cx = BOUNDS.x0, BOUNDS.x1 - 1, CHUNK do
	for cz = BOUNDS.z0, BOUNDS.z1 - 1, CHUNK do
		local region = Region3.new(Vector3.new(cx, Y0, cz), Vector3.new(math.min(cx + CHUNK, BOUNDS.x1), Y1, math.min(cz + CHUNK, BOUNDS.z1))):ExpandToGrid(RES)
		local mats, occs = terrain:ReadVoxels(region, RES)
		local size = mats.Size
		local min = region.CFrame.Position - region.Size / 2
		local touched = false
		for ix = 1, size.X do
			local x = min.X + (ix - 0.5) * RES
			for iz = 1, size.Z do
				local z = min.Z + (iz - 0.5) * RES
				local w = weight(x, z)
				local dr = riverDist(x, z)
				local inRiver = dr < RIVER.half + RIVER.bank
				if inRiver then
					w = 1
				end
				if w > 0 then
					touched = true
					-- existing surface height from the voxels (for the feather)
					local hOld = Y0
					for iy = size.Y, 1, -1 do
						local m = mats[ix][iy][iz]
						if m ~= Enum.Material.Air and m ~= Enum.Material.Water and occs[ix][iy][iz] > 0 then
							hOld = min.Y + (iy - 1) * RES + occs[ix][iy][iz] * RES
							break
						end
					end
					local h = hOld + (target(x, z) - hOld) * w
					if inRiver then
						h = RIVER.bed + (h - RIVER.bed) * smooth((dr - RIVER.half + 6) / (RIVER.bank + 6))
					end
					local slope = math.abs(target(x + RES, z) - target(x - RES, z)) + math.abs(target(x, z + RES) - target(x, z - RES))
					local top
					if slope / (2 * RES) > 0.7 then
						top = Enum.Material.Ground
					elseif math.noise(x / 70, z / 70, SEED + 7) > 0.05 then
						top = Enum.Material.LeafyGrass
					else
						top = Enum.Material.Grass
					end
					for iy = 1, size.Y do
						local y0 = min.Y + (iy - 1) * RES
						local occ = math.clamp((h - y0) / RES, 0, 1)
						if occ <= 0 then
							local water = inRiver and y0 < RIVER.water
							mats[ix][iy][iz] = if water then Enum.Material.Water else Enum.Material.Air
							occs[ix][iy][iz] = if water then math.clamp((RIVER.water - y0) / RES, 0, 1) else 0
						else
							mats[ix][iy][iz] = if inRiver and h < 1.5 then Enum.Material.Sand elseif y0 + RES > h - 3 then top else Enum.Material.Ground
							occs[ix][iy][iz] = occ
						end
					end
				end
			end
		end
		if touched then
			terrain:WriteVoxels(region, RES, mats, occs)
			written += 1
		end
		task.wait()
	end
end
return "chunks written: " .. written
