--!nocheck
-- Scale and sense pass over the placed Inner Wilds pockets and finds (2026-10-21, the user: "a lot of
-- the pois need to be resized or upscaled entirely ... fisherman boat in the middle of a forest?").
-- Run in Studio Edit mode through execute_luau after place_pockets/place_finds/swap/poi_pass and
-- group_poi_parts (it needs _G.seatPoiObjects), then ambience_inner.luau and PoiTour.labels().
--
-- SCALE: each POI grows about its ground pivot by its factor, judged against a 5-stud player, the
-- 80-120 stud wall rocks and the trees: doors and steps a player fits, steles taller than a person,
-- statues and skeletons that impress. MOVE: finds that made no sense where they stood go where their
-- story fits. A POI carries its applied factor in the attribute AppliedScale, so a re-run only scales
-- by what's missing and never twice. Every changed POI is re-seated (seatPoiObjects) and the caches
-- on pocket CacheSpotAnchors follow.

local CollectionService = game:GetService("CollectionService")
local WI = workspace.Map.Ground.WildsInner
assert(_G.seatPoiObjects, "run art/wilds/group_poi_parts.luau first (installs _G.seatPoiObjects)")

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end

-- name = { scale, x?, z?, yaw? (degrees), why? }
local PLAN = {
	-- pockets
	WolfDen = { 1.4 },
	WolfDenRockGate = { 1.3 },
	HuntersCamp = { 1.3 },
	ThreePillarsHermitage = { 1.15 },
	ShrineTerrace = { 1.25, -62, 1316, 0, "10 studs forward so the bigger terrace still clears the Shrine Cliff" },
	-- finds: scale
	F01_SteleGrove = { 1.8 },
	F02_EarthGodShrine = { 1.8 },
	F03_MeditationRock = { 1.6 },
	F04_TeaStall = { 1.4 },
	F06_LanternStairFoot = { 1.3 },
	F09_HerbPatch_West = { 1.3 },
	F10_AbandonedCart = { 1.4 },
	F11_ClawTree = { 1.5 },
	F13_PagodaFinial = { 2.0 },
	F14_WoodcutterClearing = { 1.4 },
	F15_DryCreekBridge = { 1.4 },
	F16_HerbPatch_East = { 1.3 },
	F17_VistaNotch = { 1.3 },
	F18_BoarWallow = { 1.4 },
	F19_CollapsedWatchPost = { 1.6 },
	F20_MossSteleCircle = { 1.8 },
	F21_FoxHoleCave = { 1.8 },
	F23_SwordInRock = { 2.0 },
	F24_LonePineMat = { 1.3 },
	F26_StatueHead = { 2.5 },
	F27_BeastSkeleton = { 2.5 },
	F29_TurtleStele = { 2.0 },
	F30_WeiqiTable = { 1.2 },
	F31_GullyArmour = { 1.6 },
	-- finds: scale and move where the story fits
	F05_OldWell = { 1.4, -2, 1040, nil, "beside the tea stall: a wayside rest needs water" },
	F07_FerrymanHut = { 1.5, 180, 1532, 90, "by the river crossing past the gorge gate, door to the road" },
	F08_RiverJetty = { 1.3, 250, 1562, 0, "on the river bank east of the bridge, running out over the water" },
	F28_FishermansBoat = { 1.4, 178, 1556, 0, "on trestles on the river bank by the ferryman's hut (it stood in a forest)" },
	F22_CharcoalKiln = { 1.6, -292, 1366, 0, "next to the woodcutter's clearing, where the wood comes from" },
	F12_SnareLine = { 1.2, -240, 895, 37, "across the CutWest beast trail through the wolf country" },
	F25_DryingRacks = { 1.4, -585, 1148, 40, "beside the hermit's hut and herb bed" },
}

local CACHE_FOR = {
	WolfDen = "Cache_DragonPierce",
	BambooHollow = "Cache_CrescentSweep",
	HuntersCamp = "Cache_RampagingTiger",
}

local report = {}
local rng = Random.new(23)
for _, folder in { WI.Pockets, WI.Finds } do
	for _, m in folder:GetChildren() do
		local p = PLAN[m.Name]
		if not (p and m:IsA("Model")) then
			continue
		end
		local applied = m:GetAttribute("AppliedScale") or 1
		local want = p[1]
		local changed = false
		if math.abs(want / applied - 1) > 0.01 then
			m:ScaleTo(m:GetScale() * (want / applied))
			m:SetAttribute("AppliedScale", want)
			changed = true
		end
		if p[2] then
			local piv = m:GetPivot()
			if (Vector2.new(piv.X, piv.Z) - Vector2.new(p[2], p[3])).Magnitude > 1 then
				local rot = if p[4] then CFrame.Angles(0, math.rad(p[4]), 0) else piv - piv.Position
				m:PivotTo(CFrame.new(p[2], gy(p[2], p[3]), p[3]) * rot)
				local a = m:FindFirstChild("POIAnchor")
				if a then
					a.CFrame = m:GetPivot()
				end
				table.insert(report, string.format("moved %s to (%d, %d): %s", m.Name, p[2], p[3], p[5]))
				changed = true
			end
		end
		if changed then
			-- level ground under the moved or grown footprint's structures, everything else rooted
			_G.seatPoiObjects(m, rng)
			table.insert(report, string.format("%s x%.2f", m.Name, want))
		end
		local cacheName = CACHE_FOR[m.Name]
		local spot = cacheName and m:FindFirstChild("CacheSpotAnchor", true)
		if spot then
			local cache = workspace.Map.Markers.ManualCaches:FindFirstChild(cacheName)
			local f = cache.Footing
			local base = math.max(gy(spot.Position.X, spot.Position.Z), spot.Position.Y - spot.Size.Y / 2)
			cache:PivotTo(cache:GetPivot() + Vector3.new(spot.Position.X - f.Position.X, (base - 0.3) - (f.Position.Y - f.Size.Y / 2), spot.Position.Z - f.Position.Z))
		end
		task.wait()
	end
end

-- the HeavenSplitter cache back to the (scaled) shrine stair's head
do
	local shrine = WI.Pockets:FindFirstChild("ShrineTerrace")
	local stair = shrine and shrine:FindFirstChild("FrontStair", true)
	local cache = workspace.Map.Markers.ManualCaches:FindFirstChild("Cache_HeavenSplitter")
	if stair and cache then
		local cf, size = stair:GetBoundingBox()
		local top = Vector3.new(cf.X + 7, cf.Y + size.Y / 2, cf.Z + size.Z / 2 + 3.5)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { cache, workspace:FindFirstChild("_EditorMarkers") }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(top + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), params)
		if hit then
			local f = cache.Footing
			cache:PivotTo(cache:GetPivot() + Vector3.new(hit.Position.X - f.Position.X, (hit.Position.Y - 0.1) - (f.Position.Y - f.Size.Y / 2), hit.Position.Z - f.Position.Z))
		end
	end
end

-- qi node spots that moved with their pockets (for assets/Wilds.rbxmx)
for _, n in { "ThreePillarsHermitage", "LotusMere", "TwinJadeSpring" } do
	local q = WI.Pockets:FindFirstChild(n) and WI.Pockets[n]:FindFirstChild("QiNodeSpotAnchor", true)
	if q then
		table.insert(report, string.format("%s QiNodeSpot (%.1f, %.1f, %.1f)", n, q.Position.X, q.Position.Y, q.Position.Z))
	end
end
return table.concat(report, "\n")
