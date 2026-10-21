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
		-- "Bamboo and old stone, where young beasts hunt."
		box = { -430, 560, 410, 878 }, -- area the terrain pass rewrites (x0, z0, x1, z1), feathered at the edge
		base = 4.6, -- mean ground height
		noise = { { 90, 1.4 }, { 33, 0.6 } }, -- { wavelength, amplitude }
		bank = 3.2, -- grass banks either side of the paths
		pathMat = "Sand",
		edgeMat = "Ground",
		cliffMat = "Ground", -- slopes steeper than CLIFF_SLOPE
		grass = { "Grass", "LeafyGrass" },
		paths = {
			-- the trunk: end of the sect gate's paving -> old stone gate -> steles -> shrine terrace -> bridge
			{ name = "Trunk", w = 10, pts = P({ 0, 586, 4, 615, -6, 648, -10, 680, 6, 712, 14, 740, 2, 772, -14, 798, -12, 826, -4, 848, -8, 868 }) },
			-- west: QiNode2 nook -> wolf den hunting ground
			{ name = "West", w = 7, pts = P({ -8, 662, -48, 674, -96, 694, -140, 710, -178, 716, -212, 694, -238, 672 }) },
			-- west loop: boar field -> north foot of the shrine terrace -> trunk
			{ name = "WestLoop", w = 6, pts = P({ -178, 716, -176, 750, -160, 778, -125, 792, -90, 788, -40, 792, -12, 798 }) },
			-- hidden trail: a cleft through Old Stone Hill into the bamboo hollow
			{ name = "Hidden", w = 4, pts = P({ -48, 674, -66, 648, -88, 626, -110, 608, -124, 600 }) },
			-- east: through the gap -> fallen giant over the gully -> boar meadow -> qi spring shrine
			{ name = "East", w = 7, pts = P({ 6, 712, 50, 706, 100, 700, 140, 696, 185, 694, 230, 690, 258, 722, 270, 770, 262, 804, 244, 824 }) },
			-- back along the river bank
			{ name = "EastBank", w = 6, pts = P({ 244, 824, 226, 840, 190, 850, 130, 856, 70, 858, 20, 858, -4, 852 }) },
			-- hunter's camp in the lee of the east hills
			{ name = "Camp", w = 4, pts = P({ 252, 676, 280, 652, 304, 634 }) },
		},
		-- hills and ridges: polyline spines, height above base, half width; rock = outcrop dressing on it
		ridges = {
			{ name = "OldStoneHill", pts = P({ -40, 590, -90, 572, -160, 580, -205, 610 }), h = 20, hw = 34, rock = true },
			{ name = "GateRidge", pts = P({ 40, 600, 62, 640, 70, 684 }), h = 17, hw = 22, rock = true },
			{ name = "EastHills", pts = P({ 96, 780, 150, 772, 200, 792 }), h = 15, hw = 22, rock = true },
			{ name = "MeadowNorth", pts = P({ 130, 610, 200, 628, 250, 618 }), h = 13, hw = 22 },
			{ name = "WestSpur", pts = P({ -112, 738, -76, 744, -46, 754 }), h = 11, hw = 16, rock = true },
			{ name = "DenNorth", pts = P({ -260, 596, -200, 640 }), h = 12, hw = 18 },
			{ name = "WestRim", pts = P({ -400, 600, -385, 700, -395, 800, -370, 860 }), h = 22, hw = 34, rock = true },
			{ name = "EastRim", pts = P({ 380, 640, 360, 730, 372, 820 }), h = 20, hw = 30, rock = true },
			{ name = "ShrineBack", pts = P({ -110, 840, -150, 830, -200, 836 }), h = 9, hw = 18 },
		},
		-- terraces / knolls: { x, z, flatRadius, outerRadius, topY, steep } (steep: cliff-edged, rocks around)
		knolls = {
			{ -58, 826, 14, 24, 15, true }, -- shrine terrace (hero)
			{ -318, 652, 14, 40, 26, true }, -- wolf den crag (the den cave runs into it)
			{ 314, 616, 7, 22, 7.5, false }, -- camp rise
		},
		-- gullies: dry ravines, polyline, depth below the ground, half width
		gullies = {
			{ name = "GiantsGully", pts = P({ 150, 640, 146, 690, 156, 740, 150, 800 }), depth = 7, hw = 11 },
		},
		-- bowls: { x, z, flatRadius, rimRadius, rimHeight }
		bowls = {
			{ -128, 598, 16, 30, 0 }, -- the hidden bamboo hollow inside Old Stone Hill (floor kept at base)
		},
		-- caves carved after the heightmap: mouth (x, z), floor Y, heading (deg, 0 = +X, 90 = +Z), length, radius
		caves = {
			{ name = "WolfDenCave", x = -296, z = 654, floor = 4.8, heading = 180, length = 30, radius = 7.5 },
		},
		pools = {},
		-- points of interest: dressing keeps out of these footprints ({ name, x, z, radius })
		pois = {
			{ "OldStoneGate", -4, 642, 12 },
			{ "Steles", -28, 684, 9 },
			{ "ShrineTerrace", -58, 826, 24 },
			{ "ShrineStair", -32, 822, 11 },
			{ "WolfDen", -300, 654, 16 },
			{ "BambooHollow", -128, 598, 15 },
			{ "FallenGiant", 150, 697, 14 },
			{ "HunterCamp", 314, 618, 16 },
			{ "QiSpringShrine", 266, 844, 13 },
			{ "BridgeNorth", -8, 866, 12 },
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

return "WILDS_LAYOUT set"
