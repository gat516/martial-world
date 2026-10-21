--[[
Shared layout for the first two wilds zones (docs/systems/map.md, "Wilds zones"): path splines, landforms
(hills, ridges, terraces, gullies, caves, pools). Run this first in Studio (Edit mode, command bar or MCP
execute_luau); it sets _G.WILDS_LAYOUT, which art/wilds/terrain_wilds.luau and art/wilds/dress_wilds.luau
read.

Coordinates are world studs (x, z); +Z is south, away from the sect. Heights are absolute ground Y.
Gameplay anchors (Workspace.Wilds.Zones, Workspace.Wilds.QiNodes) are read live by the stage scripts and
always win: each zone disc keeps flat open ground out past its Radius (beasts spawn there, and world
events land at random inside the discs: Treasures.randomSpot), each qi node keeps its ground.
]]

local function P(list)
	local out = {}
	for i = 1, #list, 2 do
		table.insert(out, Vector2.new(list[i], list[i + 1]))
	end
	return out
end

_G.WILDS_LAYOUT = {
	Inner = {
		-- "Bamboo and old stone, where young beasts hunt." The walled valley (docs/systems/map.md,
		-- "Inner Wilds rework", 2026-10-21): spine from the arrival court south to the Shrine Terrace,
		-- arms and loops to seven pockets, three event grounds, a find every 100-150 studs.
		box = { -1000, 500, 1000, 1460 }, -- the whole valley inside the wall ring (x0, z0, x1, z1)
		base = 4.6, -- mean ground height
		noise = { { 120, 1.6 }, { 33, 0.6 } }, -- { wavelength, amplitude }
		bank = 3.2, -- grass banks either side of the paths
		pathMat = "Sand",
		edgeMat = "Ground",
		cliffMat = "Ground", -- slopes steeper than CLIFF_SLOPE
		grass = { "Grass", "LeafyGrass" },
		paths = {
			-- the spine: end of the sect gate's paving -> old stone gate -> arrival court -> shrine stair
			{ name = "Spine", w = 10, pts = P({ 0, 586, 4, 615, -6, 648, -10, 680, 4, 712, 10, 760, 8, 800, -6, 870, -20, 950, -10, 1030, 0, 1100, -4, 1180, -10, 1250, -24, 1300, -36, 1335 }) },
			-- the gorge road: spine end -> gorge gate -> the bridge
			{ name = "GorgeRoad", w = 8, pts = P({ -10, 1250, 40, 1280, 120, 1320, 170, 1370, 205, 1420, 212, 1455 }) },
			-- west arm: the court -> QiNode2 -> the Wolf Den Hollow
			{ name = "WestArm", w = 7, pts = P({ -8, 664, -48, 674, -96, 694, -150, 712, -200, 722, -280, 735, -360, 745, -450, 755, -540, 762 }) },
			-- the Hidden trail through the Bamboo Sea to the hollow
			{ name = "Hidden", w = 4, pts = P({ -150, 712, -190, 680, -230, 650, -280, 625, -320, 610 }) },
			-- west loop: down past the West Field to the Three Pillars
			{ name = "WestLoop", w = 6, pts = P({ -360, 745, -420, 850, -430, 930, -410, 990, -470, 1060, -520, 1120, -560, 1165 }) },
			-- south-west: back east along the south wall to the spine
			{ name = "SouthWest", w = 6, pts = P({ -560, 1165, -480, 1250, -420, 1300, -330, 1320, -250, 1330, -180, 1320, -120, 1300, -60, 1270, -10, 1250 }) },
			-- east arm: the court -> over the Fallen Giant -> boar wallow -> the Hunter's Camp
			{ name = "EastArm", w = 7, pts = P({ 4, 712, 40, 712, 100, 728, 150, 735, 220, 728, 262, 760, 290, 798, 335, 797, 380, 800, 450, 795, 500, 800, 570, 760, 630, 725 }) },
			{ name = "Camp", w = 4, pts = P({ 630, 725, 660, 714 }) },
			-- east loop: south to the Twin-Jade Spring
			{ name = "EastLoop", w = 6, pts = P({ 500, 800, 560, 870, 600, 950, 610, 1050, 600, 1130, 590, 1185 }) },
			-- south-east: back west to the gorge gate
			{ name = "SouthEast", w = 6, pts = P({ 590, 1185, 530, 1250, 470, 1300, 380, 1330, 300, 1340, 250, 1380, 210, 1420 }) },
			-- cross paths linking the loops to the spine
			{ name = "CrossWest", w = 6, pts = P({ -20, 950, -80, 968, -150, 985, -220, 995, -300, 1000, -345, 1000 }) },
			{ name = "CrossEast", w = 6, pts = P({ 0, 1100, 80, 1135, 150, 1160, 240, 1160, 330, 1150, 415, 1130, 530, 1090, 605, 1045 }) },
			{ name = "LotusLane", w = 4, pts = P({ -150, 985, -190, 1040, -225, 1100, -238, 1122 }) },
			-- the north foot under the wall to the North Terrace (G2's second route)
			{ name = "NorthFoot", w = 5, pts = P({ -6, 648, 40, 640, 130, 618, 240, 628, 280, 650, 296, 676 }) },
			-- risky shortcuts (narrow trails)
			{ name = "CutWest", w = 3, pts = P({ -10, 700, -60, 760, -120, 810, -180, 850, -240, 895, -300, 940, -350, 975 }) },
			{ name = "CutRidge", w = 3, pts = P({ 40, 665, 90, 668, 150, 664, 200, 660, 255, 670 }) },
			{ name = "CutGully", w = 3, pts = P({ 300, 812, 298, 860, 304, 920, 318, 980, 345, 1040, 420, 1100 }) },
		},
		-- hills and ridges: polyline spines, height above base, half width; rock = outcrop dressing on it
		ridges = {
			-- the ground rises into the wall feet (crest lines of art/wilds/build_walls_inner.luau)
			{ name = "BermNW", pts = P({ -790, 556, -620, 522, -400, 505, -112, 502 }), h = 9, hw = 70 },
			{ name = "BermNE", pts = P({ 152, 500, 270, 494, 386, 500 }), h = 9, hw = 70 },
			{ name = "BermNE2", pts = P({ 545, 600, 700, 590, 840, 640 }), h = 9, hw = 70 },
			{ name = "BermE", pts = P({ 840, 640, 900, 800, 905, 1000, 880, 1180, 800, 1262 }), h = 9, hw = 70 },
			{ name = "BermSE", pts = P({ 618, 1425, 420, 1450, 262, 1452 }), h = 9, hw = 70 },
			{ name = "BermS", pts = P({ -212, 1448, -110, 1418, -12, 1400, 42, 1402, 62, 1360, 60, 1300 }), h = 9, hw = 60 },
			{ name = "BermSW", pts = P({ -212, 1448, -280, 1452, -500, 1440, -760, 1400 }), h = 9, hw = 70 },
			{ name = "BermW", pts = P({ -760, 1400, -860, 1250, -900, 1000, -872, 742 }), h = 9, hw = 70 },
			-- Old Stone Hill under the Bamboo Sea, holding the hidden hollow
			{ name = "OldStoneHill", pts = P({ -470, 650, -410, 668, -340, 676, -270, 664 }), h = 16, hw = 30, rock = true },
			-- the GateRidge east of the court; the G2 shortcut runs along its crest
			{ name = "GateRidge", pts = P({ 60, 668, 150, 666, 235, 664 }), h = 11, hw = 20, rock = true },
		},
		-- terraces / knolls: { x, z, flatRadius, outerRadius, topY, steep } (steep: cliff-edged, rocks around)
		knolls = {
			-- the Shrine Terrace, the den crag and cave come from InnerWildsPrefabs (part-built), not terrain
			{ 660, 702, 26, 42, 7.0, false }, -- hunter's camp rise (the HuntersCamp prefab sits on it)
			{ -566, 1176, 34, 50, 6.0, false }, -- the hermitage rise at the Three Pillars' feet
		},
		-- gullies: dry ravines, polyline, depth below the ground, half width
		gullies = {
			{ name = "GiantsGully", pts = P({ 300, 743, 296, 793, 306, 843, 300, 903, 312, 980, 330, 1040 }), depth = 7, hw = 11 },
		},
		-- bowls: { x, z, flatRadius, rimRadius, rimHeight }
		bowls = {},
		-- caves carved after the heightmap: mouth (x, z), floor Y, heading (deg, 0 = +X, 90 = +Z), length, radius
		caves = {}, -- the den cave is part of the WolfDen prefab
		pools = {}, -- no terrain water in the valley: pools are WaterKit parts on flats
		-- flats: { x, z, radius, Y, material? } (event grounds, the Lotus Mere floor, fall pools, the arrival court)
		flats = {
			{ -400, 1000, 52, 4.6, "LeafyGrass" }, -- G1 West Field
			{ 300, 680, 46, 4.8, "LeafyGrass" }, -- G2 North Terrace
			{ 470, 1120, 52, 4.6, "Grass" }, -- G3 East Flat
			{ -260, 1170, 46, 3.4, "LeafyGrass" }, -- Lotus Mere floor (the LotusMere prefab digs its own pond)
			{ -2, 1340, 14, 3.9, "Sand" }, -- Jade Veil pool
			{ 592, 1218, 16, 3.9, "Sand" }, -- Twin-Jade pool
			{ 18, 676, 20, 4.6, "Grass" }, -- arrival court
			{ -330, 585, 38, 4.6, "LeafyGrass" }, -- the Bamboo Hollow under the north wall's trickle
			{ -58, 1360, 40, 4.6, "Grass" }, -- the Shrine Terrace prefab's ground
		},
		-- points of interest: dressing keeps out of these footprints ({ name, x, z, radius })
		pois = {
			{ "OldStoneGate", -4, 642, 12 },
			{ "Steles", -28, 684, 9 },
			{ "ShrineTerrace", -62, 1360, 40 },
			{ "JadeVeilPool", -2, 1340, 18 },
			{ "WolfDen", -700, 786, 42 },
			{ "WolfDenRing", -580, 780, 50 },
			{ "WolfDenRockGate", -480, 760, 28 },
			{ "BambooHollow", -330, 588, 40 },
			{ "FallenGiant", 300, 800, 60 },
			{ "HunterCamp", 660, 702, 30 },
			{ "TwinJadeSpring", 620, 1245, 40 },
			{ "Hermitage", -566, 1176, 45 },
			{ "LotusMere", -260, 1170, 52 },
			{ "GorgeGate", 212, 1440, 16 },
		},
		-- builder offsets for poi_wilds.luau: these POIs keep their old literal coordinates in the
		-- builder and are moved by this much (sampling the ground at the new spot)
		poiMoves = {
			ShrineTerrace = Vector2.new(-12, 539),
			WolfDen = Vector2.new(-340, 120),
			BambooHollow = Vector2.new(-200, 4),
			FallenGiant = Vector2.new(150, 103),
			HunterCamp = Vector2.new(346, 94),
			QiSpringShrine = Vector2.new(324, 371),
		},
	},
	Middle = {
		-- "Dead villages. The beasts here have eaten cultivators."
		box = { -420, 912, 280, 1260 },
		base = 2.9,
		noise = { { 80, 1.2 }, { 28, 0.5 } },
		bank = 1.6,
		pathMat = "Sand",
		edgeMat = "Mud",
		cliffMat = "Ground",
		grass = { "Ground", "Mud" },
		grassPatch = "LeafyGrass", -- sparse surviving grass, thicker by the river
		paths = {
			-- the old road: bridge -> border gate -> village -> arena north gate
			{ name = "Road", w = 10, pts = P({ -8, 908, -4, 934, -14, 958, -34, 976, -40, 1000, -22, 1024, -6, 1040, 0, 1054 }) },
			{ name = "EastRoad", w = 7, pts = P({ -4, 934, 40, 950, 82, 972, 104, 996, 114, 1022 }) },
			{ name = "MarshTrail", w = 5, pts = P({ 82, 972, 124, 966, 150, 958 }) },
			{ name = "WestRoad", w = 7, pts = P({ -34, 976, -80, 986, -130, 982, -190, 970, -250, 962, -276, 960 }) },
			{ name = "Graves", w = 4, pts = P({ -130, 982, -150, 1012, -160, 1044 }) },
			{ name = "Grotto", w = 4, pts = P({ -276, 960, -300, 1000, -312, 1040, -318, 1060 }) },
			-- deserters' camp behind the east bluff (an enemy outpost site)
			{ name = "DeserterTrail", w = 4, pts = P({ 114, 1022, 146, 1018, 160, 1050, 166, 1094, 174, 1124 }) },
		},
		ridges = {
			-- burned bluffs that close the arena basin and hide it from the road until the gate
			{ name = "WestBluff", pts = P({ -70, 1060, -100, 1110, -96, 1170 }), h = 16, hw = 24, rock = true },
			{ name = "EastBluff", pts = P({ 66, 1060, 104, 1110, 100, 1172 }), h = 16, hw = 24, rock = true },
			{ name = "SouthBluff", pts = P({ -80, 1214, 0, 1230, 84, 1214 }), h = 20, hw = 26, rock = true },
			{ name = "VillageBack", pts = P({ -150, 940, -110, 930 }), h = 7, hw = 16 },
			{ name = "GrottoCrag", pts = P({ -360, 1100, -330, 1090, -300, 1110 }), h = 24, hw = 30, rock = true },
			{ name = "MarshBank", pts = P({ 200, 1040, 240, 1000 }), h = 10, hw = 20, rock = true },
			{ name = "WestRim", pts = P({ -410, 940, -405, 1020 }), h = 18, hw = 26, rock = true },
		},
		knolls = {
			{ 0, 1172, 12, 26, 8, true }, -- broken pagoda mound (hero)
			{ -162, 1062, 14, 30, 5, false }, -- grave field rise
		},
		gullies = {
			{ name = "BoneGully", pts = P({ -110, 1000, -104, 1040, -118, 1080, -110, 1120 }), depth = 6, hw = 10 },
		},
		bowls = {},
		caves = {
			{ name = "SerpentGrotto", x = -322, z = 1066, floor = 2.8, heading = 75, length = 28, radius = 8 },
		},
		-- fen / marsh pools: { x, z, radius, bedY, waterY } (terrain water only shows above Y 2 here)
		pools = {
			{ -332, 944, 14, -1.5, 2.5 },
			{ -268, 990, 12, -1.5, 2.5 },
			{ -322, 996, 10, -1.0, 2.5 },
			{ -262, 934, 9, -1.0, 2.5 },
			{ -300, 1020, 8, -1.0, 2.5 },
			{ 188, 978, 12, -1.5, 2.4 },
			{ 136, 984, 9, -1.0, 2.4 },
		},
		-- the arena floor stays flat at this height inside this radius
		flats = { { 0, 1100, 56, 2.9 }, { 184, 1142, 20, 3.4 } },
		pois = {
			{ "BridgeSouth", -8, 910, 12 },
			{ "BorderGate", -6, 928, 16 },
			{ "Watchtower", 28, 934, 10 },
			{ "AshenHollow", -72, 962, 40 },
			{ "Caravan", 116, 976, 12 },
			{ "Graves", -162, 1062, 24 },
			{ "DrownedShrine", 176, 958, 10 },
			{ "FallenOutpost", 0, 1100, 64 },
			{ "BrokenPagoda", 0, 1172, 18 },
			{ "SerpentGrotto", -320, 1062, 12 },
			{ "RuinedCourtyard", 120, 1040, 16 },
			{ "DeserterCamp", 184, 1142, 26 },
		},
	},
	-- the stone bridge over the river between the zones (river surface Y 0, banks ~4)
	Bridge = { x = -8, z0 = 866, z1 = 910, y = 4.4 },
}

-- The Ruined Borderlands moved south as one block (2026-10-21, docs/systems/map.md "Inner Wilds
-- rework"): the Middle table above keeps its old coordinates, and this shifts every one of them by
-- MIDDLE_OFFSET into the new box (x -200..500, z 1612..1960), with the bridge, so the river, the gorge
-- gate and the bridge stay one walk from the Inner valley. poi_wilds.luau builds the Middle's POIs at
-- their old literal coordinates and moves each one by `offset` (sampling the ground at the new spot).
local MIDDLE_OFFSET = Vector2.new(220, 700)
do
	local Z = _G.WILDS_LAYOUT.Middle
	local o = MIDDLE_OFFSET
	Z.offset = o
	Z.box = { Z.box[1] + o.X, Z.box[2] + o.Y, Z.box[3] + o.X, Z.box[4] + o.Y }
	for _, key in { "paths", "ridges", "gullies" } do
		for _, item in Z[key] or {} do
			for i, v in item.pts do
				item.pts[i] = v + o
			end
		end
	end
	for _, key in { "knolls", "bowls", "pools", "flats" } do
		for _, item in Z[key] or {} do
			item[1] += o.X
			item[2] += o.Y
		end
	end
	for _, item in Z.pois or {} do
		item[2] += o.X
		item[3] += o.Y
	end
	for _, c in Z.caves or {} do
		c.x += o.X
		c.z += o.Y
	end
	local B = _G.WILDS_LAYOUT.Bridge
	B.x += o.X
	B.z0 += o.Y
	B.z1 += o.Y
end

return "WILDS_LAYOUT set"
