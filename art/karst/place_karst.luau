--[[
Builds Workspace.Map.Karst: Zhangjiajie-style stone pillars rising from the ground through the cloud sea,
from the kit made by art/karst/build_karst.py. Run in Studio (Edit mode) from the command bar or the MCP,
after File > Import 3D of art/karst/Karst.fbx (defaults, meshes not merged). Re-runnable: once the kit is in
ServerStorage.KarstKit the import isn't needed again, and the layout is deterministic (seeded).

Stages (set _G.KARST_STAGES to run one on its own):
  kit     find the imported Karst*/KarstFar* MeshParts, style them (SmoothPlastic + the atlas TextureID the
          importer set, no collision/query/touch/shadow, Box fidelity), move them into ServerStorage.KarstKit,
          delete the import containers.
  layout  clear Map.Karst and place every group in GROUPS. Each pillar is a Model: the upper piece from the
          joint (inside the cloud deck, at the local deck's mid height) to its crown, one trunk per leg from
          the ground (raycast on Terrain, sunk 12) up to the joint, one invisible collider per trunk near the
          ground (the only collision: players reach the feet from the wilds), FX_KarstMist attachments
          where the deck wraps the hero pillars and on a few ledges (MistWisps clones when
          ServerStorage.AmbientFX.MistWisps exists).
  With _G.KARST_BLOCKOUT = true the layout stage builds gray cylinders per leg (ground to top) under
  Workspace._KarstBlockout instead, without needing the kit (layout check before the import).
Everything is one ChangeHistory recording per run, so Ctrl+Z undoes it. The layout prints a warning for any
pillar breaking a clearance rule (spirit peaks, bridge view wedges, wilds, arrays, deck gaps).

Import maps Blender (x, y, z) to mesh-local (x, z, -y) about the kit origin (the kind's base centre): Size =
(bx, bz, by), part offset = CFrame.Angles(0, pi, 0) * CFrame.new(-cx, cz, cy).
]]

local STAGES = _G.KARST_STAGES or { kit = true, layout = true }
local BLOCKOUT = _G.KARST_BLOCKOUT == true
_G.KARST_STAGES, _G.KARST_BLOCKOUT = nil, nil -- flags apply to one run only

-- BEGIN MESHES (generated from Karst.json: size and centre in Blender axes)
local MESHES = {
	Karst_Needle = { size = { 79.655, 79.801, 417.114 }, center = { 0.962, -0.158, 208.743 }, tris = 2200 },
	Karst_Needle_Green = { size = { 57.933, 61.778, 162.527 }, center = { 5.56, 2.822, 338.963 }, tris = 594 },
	Karst_Spire = { size = { 122.759, 124.645, 457.116 }, center = { 1.904, 2.211, 228.742 }, tris = 2800 },
	Karst_Spire_Green = { size = { 107.814, 99.703, 209.943 }, center = { -5.377, 4.286, 355.272 }, tris = 1132 },
	Karst_Tower = { size = { 215.757, 210.32, 417.267 }, center = { -1.963, -2.922, 208.667 }, tris = 4199 },
	Karst_Tower_Green = { size = { 190.465, 190.726, 246.546 }, center = { -4.239, 3.122, 296.973 }, tris = 1768 },
	Karst_Mesa = { size = { 185.226, 178.921, 397.519 }, center = { 2.588, 0.138, 198.541 }, tris = 4400 },
	Karst_Mesa_Green = { size = { 155.893, 167.935, 162.948 }, center = { 1.481, 6.934, 318.774 }, tris = 914 },
	Karst_Twin = { size = { 139.834, 99.71, 447.359 }, center = { -7.342, -2.744, 223.62 }, tris = 4199 },
	Karst_Twin_Green = { size = { 121.692, 84.908, 227.928 }, center = { -6.741, -5.96, 336.264 }, tris = 1052 },
	Karst_Arch = { size = { 179.152, 87.831, 437.386 }, center = { -6.905, 0.018, 218.607 }, tris = 4200 },
	Karst_Arch_Green = { size = { 159.33, 66.604, 72.887 }, center = { -7.168, -1.344, 403.744 }, tris = 934 },
	Karst_Broken = { size = { 107.534, 110.003, 359.227 }, center = { 1.477, -0.949, 179.686 }, tris = 2999 },
	Karst_Broken_Green = { size = { 94.533, 84.887, 201.989 }, center = { -3.97, -0.865, 261.194 }, tris = 674 },
	Karst_Leaning = { size = { 105.078, 97.922, 427.24 }, center = { 5.169, -0.286, 213.68 }, tris = 2600 },
	Karst_Leaning_Green = { size = { 81.22, 74.382, 217.934 }, center = { 17.842, 3.715, 321.267 }, tris = 754 },
	Karst_Stub = { size = { 129.971, 133.856, 167.286 }, center = { 1.362, -0.433, 83.657 }, tris = 2000 },
	Karst_Stub_Green = { size = { 112.673, 118.507, 47.924 }, center = { 3.926, 0.035, 146.262 }, tris = 876 },
	Karst_Trio = { size = { 85.994, 87.894, 447.297 }, center = { 1.481, -7.913, 223.651 }, tris = 3800 },
	Karst_Trio_Green = { size = { 75.454, 74.284, 152.882 }, center = { 0.718, -6.846, 373.741 }, tris = 554 },
	Karst_Trunk = { size = { 123.891, 126.571, 397.08 }, center = { -0.843, 1.166, 198.67 }, tris = 1500 },
	KarstFar_Spire = { size = { 110.85, 103.371, 447.584 }, center = { 0.567, 0.824, 223.508 }, tris = 699 },
	KarstFar_Spire_Green = { size = { 81.754, 77.694, 92.832 }, center = { 3.146, 0.118, 403.716 }, tris = 336 },
	KarstFar_Tower = { size = { 182.11, 186.212, 417.58 }, center = { -0.296, -0.525, 208.51 }, tris = 850 },
	KarstFar_Tower_Green = { size = { 161.045, 159.487, 122.915 }, center = { -3.602, 3.868, 358.758 }, tris = 644 },
	KarstFar_Twin = { size = { 126.273, 81.521, 447.242 }, center = { -3.139, 0.621, 223.679 }, tris = 850 },
	KarstFar_Twin_Green = { size = { 98.572, 49.059, 102.865 }, center = { 0.247, 0.584, 398.732 }, tris = 296 },
	KarstFar_Trunk = { size = { 131.598, 130.871, 395.091 }, center = { 1.511, 0.9, 198.128 }, tris = 260 },
}
-- END MESHES

-- BEGIN KINDS (generated from Karst.json: legs at the joint (x, y, h crown base, r0 radius at the joint), ledges)
local KINDS = {
	Karst_Needle = {
		legs = { { x = 0, y = 0, h = 420, r0 = 43.69, rtop = 19.4 } },
		ledges = { { x = 4.57, y = 1.4, z = 372, r = 26.77 }, { x = 5.04, y = 0, z = 420, r = 12.8 }, { x = 26.14, y = 22.79, z = 260.4, r = 9 } },
		trees = { { "pine", -9.77, -13.07, 372, 0.46 }, { "bush", 16.88, -18.69, 372, 0.9 }, { "bush", 25.04, -9.57, 372, 1.07 }, { "bush", 29.02, 0.27, 372, 1 }, { "pine", 7.73, -3.21, 420, 0.42 }, { "bush", 14.72, -4.87, 420, 1.14 }, { "bush", 15.78, -1.08, 420, 1.18 }, { "bush", 14.16, 5.34, 420, 0.95 }, { "pine", 26.14, 22.79, 260.4, 0.9 } },
	},
	Karst_Spire = {
		legs = { { x = 0, y = 0, h = 460, r0 = 67.69, rtop = 23.97 } },
		ledges = { { x = -2.43, y = 4.86, z = 330, r = 47.55 }, { x = -1.15, y = 2.3, z = 405, r = 31.39 }, { x = -0, y = 0, z = 460, r = 16.2 }, { x = -47.55, y = -10, z = 253, r = 12 } },
		trees = { { "pine", -29.25, 35.01, 330, 0.5 }, { "pine", 37.37, 14.41, 330, 0.41 }, { "pine", 16.35, -30.97, 330, 0.44 }, { "bush", -35.19, -28.92, 330, 1 }, { "pine", 23.42, -1.4, 405, 0.65 }, { "pine", -7.31, 26.54, 405, 0.47 }, { "pine", 9.71, 25.65, 405, 0.6 }, { "bush", -21.01, 22.81, 405, 1.11 }, { "pine", -8.03, 0.18, 460, 0.68 }, { "bush", -13.66, 3, 460, 0.92 }, { "bush", -13.32, -2.41, 460, 1.19 }, { "bush", -11.29, -6.54, 460, 0.95 }, { "pine", -47.55, -10, 253, 1 } },
	},
	Karst_Tower = {
		legs = { { x = 0, y = 0, h = 420, r0 = 115, rtop = 37.2 } },
		ledges = { { x = -4.42, y = 1.36, z = 262, r = 90.59 }, { x = -2.75, y = 0.85, z = 338, r = 63.31 }, { x = -0.99, y = 0.31, z = 392, r = 42.84 }, { x = -0, y = 0, z = 420, r = 27 }, { x = -52.17, y = 83.77, z = 176.4, r = 16 }, { x = 42.37, y = -80.19, z = 210, r = 11 } },
		trees = { { "pine", 26.57, 72.55, 262, 1.1 }, { "pine", 15.94, -72.19, 262, 0.95 }, { "pine", 61.75, 43.75, 262, 1.13 }, { "pine", 71.76, -15.79, 262, 1.1 }, { "pine", -79.42, -12.15, 262, 0.9 }, { "bush", -0.07, 87.31, 262, 0.96 }, { "pine", -48.02, -28.26, 338, 0.61 }, { "pine", -17.38, 52.22, 338, 0.57 }, { "pine", 43.99, 27.78, 338, 0.77 }, { "pine", -56.04, -3.48, 338, 0.71 }, { "pine", 51.79, 6.66, 338, 0.61 }, { "bush", 53.33, -26.83, 338, 1.29 }, { "pine", -29.81, 21.97, 392, 0.52 }, { "pine", 5.48, -35.46, 392, 0.4 }, { "pine", -0.17, 36.39, 392, 0.4 }, { "bush", 10.95, -38.93, 392, 0.89 }, { "pine", -18.2, -1.01, 420, 1.13 }, { "pine", -9.94, 5.53, 420, 0.97 }, { "pine", 0.4, -0.02, 420, 1.18 }, { "bush", 23.87, -3.8, 420, 0.81 }, { "bush", 23.52, 5.73, 420, 1.3 }, { "bush", 16.02, 17.98, 420, 1.09 }, { "pine", -52.17, 83.77, 176.4, 1.13 }, { "pine", 42.37, -80.19, 210, 0.97 } },
	},
	Karst_Mesa = {
		legs = { { x = 0, y = 0, h = 400, r0 = 98, rtop = 63.93 } },
		ledges = { { x = -0.07, y = 1.25, z = 345, r = 74.12 }, { x = -0, y = 0, z = 400, r = 51.3 }, { x = 26.69, y = 76.62, z = 240, r = 15 } },
		trees = { { "pine", 24.64, 59.08, 345, 0.71 }, { "pine", -58.64, 28.11, 345, 0.88 }, { "pine", 62.67, 6.96, 345, 0.71 }, { "pine", 44.37, -45.31, 345, 0.96 }, { "pine", -2.79, 65.66, 345, 0.84 }, { "bush", 2.25, -72.47, 345, 1.24 }, { "bush", 38.62, -63.13, 345, 1.13 }, { "bush", 58.89, -45.11, 345, 1.1 }, { "pine", -11.93, -13.33, 400, 1.06 }, { "pine", -27.72, 10.9, 400, 1.1 }, { "pine", -3.97, 14.23, 400, 1.01 }, { "pine", -6.19, 32.31, 400, 1.12 }, { "pine", 22.11, -19.1, 400, 0.9 }, { "bush", -43.11, 20.16, 400, 1.16 }, { "bush", -47.29, -6.94, 400, 0.82 }, { "bush", -45.61, -15.8, 400, 1.2 }, { "pine", 26.69, 76.62, 240, 1.1 } },
	},
	Karst_Twin = {
		legs = { { x = -24, y = 0, h = 450, r0 = 53.43, rtop = 28.37 }, { x = 28, y = 3, h = 350, r0 = 37.82, rtop = 29.42 } },
		ledges = { { x = -29.37, y = -0.32, z = 380, r = 35.39 }, { x = -27.6, y = -0, z = 450, r = 20.2 }, { x = 31.5, y = 3, z = 350, r = 21.6 }, { x = -44.4, y = -38.17, z = 225, r = 11 } },
		trees = { { "pine", -7.26, 18, 380, 0.51 }, { "pine", -30.02, -29.4, 380, 0.54 }, { "pine", -41.72, 27.07, 380, 0.64 }, { "bush", -55.61, 18.35, 380, 1.2 }, { "pine", -23.35, 12.19, 450, 0.77 }, { "bush", -21.84, -17.07, 450, 0.86 }, { "pine", 30.67, -0.77, 350, 0.78 }, { "pine", 17.9, 2.38, 350, 0.86 }, { "pine", 26.51, 11.27, 350, 0.84 }, { "bush", 46.32, -8.21, 350, 1.04 }, { "bush", 49.92, 0.16, 350, 0.8 }, { "bush", 49.84, 7.78, 350, 0.86 }, { "pine", -44.4, -38.17, 225, 0.97 } },
	},
	Karst_Arch = {
		legs = { { x = -52, y = 0, h = 440, r0 = 48.71, rtop = 25.15 }, { x = 52, y = 0, h = 380, r0 = 33.78, rtop = 26.18 } },
		ledges = { { x = -52.64, y = -1.29, z = 370, r = 32.29 }, { x = -52, y = -0, z = 440, r = 17.6 }, { x = 52, y = 0, z = 380, r = 18.9 } },
		trees = { { "pine", -37.07, 19.65, 370, 0.5 }, { "pine", -64.83, 21.79, 370, 0.46 }, { "pine", -76.2, -12.24, 370, 0.45 }, { "bush", -44.04, 26.7, 370, 1.17 }, { "bush", -59.72, 26.17, 370, 1.01 }, { "bush", -64.9, 24, 370, 1.16 }, { "pine", -51.73, -7.53, 440, 0.71 }, { "bush", -56.57, 14.37, 440, 1.28 }, { "pine", 53.02, 9.43, 380, 0.78 }, { "bush", 57.33, -15.89, 380, 0.87 }, { "bush", 63.7, -11.44, 380, 1.07 }, { "bush", 67.52, -5.12, 380, 1.28 }, { "bush", -1.38, -0.55, 328, 1 } },
	},
	Karst_Broken = {
		legs = { { x = 0, y = 0, h = 362, r0 = 60.01, rtop = 23.69 } },
		ledges = { { x = 1.33, y = -0.68, z = 318, r = 40.5 }, { x = 0, y = -0, z = 362, r = 15 }, { x = -40.6, y = 14.26, z = 162.9, r = 13 } },
		trees = { { "pine", -23, -16.56, 318, 1.09 }, { "pine", 20.55, 19.87, 318, 1.05 }, { "pine", 6.61, 28.02, 318, 0.85 }, { "pine", -24.55, 13.29, 318, 1.19 }, { "pine", 7.46, -29.75, 318, 1.16 }, { "bush", -26.52, -27.16, 318, 1.23 }, { "bush", -6.84, -37.48, 318, 0.94 }, { "bush", 15.42, -36.29, 318, 1.09 }, { "pine", 1.69, -3.95, 362, 0.56 }, { "bush", 3.09, -11.58, 362, 0.89 }, { "pine", -40.6, 14.26, 162.9, 1.03 } },
	},
	Karst_Leaning = {
		legs = { { x = 0, y = 0, h = 430, r0 = 53.65, rtop = 28.25 } },
		ledges = { { x = 14.17, y = 3.01, z = 350, r = 35.65 }, { x = 19.35, y = 4.3, z = 430, r = 20.2 }, { x = 49.55, y = 16.81, z = 215, r = 10 } },
		trees = { { "pine", -15.26, 1.09, 350, 0.52 }, { "pine", 42.88, -1.75, 350, 0.52 }, { "pine", 18.82, 32.14, 350, 0.66 }, { "bush", -1.98, 32.69, 350, 0.9 }, { "bush", -14.61, 17.93, 350, 0.91 }, { "bush", -18.1, 2.38, 350, 1.14 }, { "pine", 15.33, -4.79, 430, 0.77 }, { "bush", 3.39, 12.76, 430, 0.91 }, { "bush", 1.31, 4.93, 430, 1.19 }, { "bush", 3.83, -3.59, 430, 1.18 }, { "pine", 49.55, 16.81, 215, 0.93 } },
	},
	Karst_Stub = {
		legs = { { x = 0, y = 0, h = 170, r0 = 73.28, rtop = 47.65 } },
		ledges = { { x = 1.47, y = 0.11, z = 125, r = 55.25 }, { x = 0, y = 0, z = 170, r = 36.5 } },
		trees = { { "pine", 31.72, 36.06, 125, 0.51 }, { "pine", 3.72, -46.87, 125, 0.65 }, { "pine", -23.18, -39.93, 125, 0.59 }, { "pine", -43.5, 15.43, 125, 0.71 }, { "pine", 45.61, -17.42, 125, 0.51 }, { "bush", -24.64, 47.4, 125, 0.92 }, { "bush", -43.04, 26.51, 125, 1.01 }, { "bush", -48.91, 1.87, 125, 0.83 }, { "pine", 9.98, 3.35, 170, 0.9 }, { "pine", 13.28, 17.72, 170, 1.02 }, { "pine", -20.69, 8.39, 170, 0.94 }, { "pine", -10.9, 19.64, 170, 1.07 }, { "pine", -15.5, -7.52, 170, 1.15 }, { "bush", -13.53, 30.53, 170, 1.3 } },
	},
	Karst_Trio = {
		legs = { { x = 0, y = -23, h = 450, r0 = 29.59, rtop = 21.49 }, { x = 20, y = 13, h = 370, r0 = 26.61, rtop = 19.95 }, { x = -20, y = 12, h = 300, r0 = 23.92, rtop = 18.52 } },
		ledges = { { x = -0, y = -27.5, z = 450, r = 14.9 }, { x = 23.7, y = 14.85, z = 370, r = 13.5 }, { x = -23, y = 13.5, z = 300, r = 12.2 } },
		trees = { { "pine", 6.52, -22.25, 450, 0.58 }, { "bush", -2.41, -15.65, 450, 1.01 }, { "bush", -6.6, -17.57, 450, 1.2 }, { "bush", -12.37, -24.75, 450, 0.82 }, { "pine", 17.92, 18.36, 370, 0.6 }, { "bush", 17.12, 6.01, 370, 1.08 }, { "bush", 22.29, 4.01, 370, 1.09 }, { "bush", 24.55, 3.91, 370, 1.06 }, { "pine", -21.77, 18.71, 300, 0.39 }, { "bush", -28.04, 6.01, 300, 1.09 }, { "bush", -25.13, 4.64, 300, 0.98 }, { "bush", -21.26, 4.34, 300, 1.23 } },
	},
	Karst_Trunk = {
		legs = { { x = 0, y = 0, h = 400, r0 = 71.36, rtop = 63.36 } },
		ledges = {  },
		trees = {  },
	},
	KarstFar_Spire = {
		legs = { { x = 0, y = 0, h = 450, r0 = 58.03, rtop = 29.48 } },
		ledges = { { x = 3.42, y = 0.85, z = 360, r = 37.02 }, { x = 0, y = 0, z = 450, r = 17.6 } },
		trees = {  },
	},
	KarstFar_Tower = {
		legs = { { x = 0, y = 0, h = 420, r0 = 105.99, rtop = 45.57 } },
		ledges = { { x = -2.33, y = 3.14, z = 300, r = 79.17 }, { x = -0.88, y = 1.18, z = 380, r = 50.9 }, { x = -0, y = 0, z = 420, r = 29.7 } },
		trees = {  },
	},
	KarstFar_Twin = {
		legs = { { x = -24, y = 0, h = 450, r0 = 44.85, rtop = 34.95 }, { x = 28, y = 3, h = 350, r0 = 39.76, rtop = 31.36 } },
		ledges = { { x = -24, y = -0, z = 450, r = 23 }, { x = 28, y = 3, z = 350, r = 20.2 } },
		trees = {  },
	},
	KarstFar_Trunk = {
		legs = { { x = 0, y = 0, h = 400, r0 = 74.36, rtop = 66.36 } },
		ledges = {  },
		trees = {  },
	},
}
-- END KINDS

local SEED = 4417
local FAR_FROM = "KarstFar_" -- far kinds use the far trunk
local TRUNK, FAR_TRUNK = "Karst_Trunk", "KarstFar_Trunk"
local SINK = 12 -- trunk bases sit this far into the ground
local JOINT_DEFAULT = 350 -- joint height where no deck clump covers the spot
local COLLIDER_H = 90 -- invisible collider height above the ground
local NO_COLLIDER_R = 2250 -- past the walkable ground ring, no colliders
local BLOCK_COLOR = Color3.fromRGB(150, 148, 145)

-- clearance rules
local PEAK_R, PEAK_CLEAR = 300, 140 -- spirit peak plateaus: nothing within 140 of a plateau centre
local WEDGE_DEG, WEDGE_R = 9, 1000 -- bridge view wedges: nothing within 9 deg of a peak's bearing inside r 1000
local WILDS = { -420, 330, 200, 1250 } -- x0, x1, z0, z1: the wilds field, sect gate and the route to it
-- (the Inner valley, x -1020..1020 z 470..1560, takes the karst groups already standing in it as its
-- corners and towers; keep this box as it is so a re-run doesn't push them out)
local KEEP = { -- ground spots to keep clear (x, z, radius): arrays, qi nodes
	{ 18, 676, 150 }, -- TeleportHome_Inner
	{ 234, 1662, 150 }, -- TeleportHome_Middle (the Borderlands moved south 2026-10-21)
	{ 880, -1524, 150 },
	{ 48, 470, 150 },
}
local GAPS = { -- the cloud deck's holes (deg, r, hole radius), from place_clouds.luau, plus a margin
	{ 100, 650, 140 },
	{ 20, 760, 175 },
	{ 215, 700, 165 },
	{ 305, 1200, 240 },
	{ 160, 1380, 220 },
}
local GAP_MARGIN = 40

--[[ GROUPS: each { name, deg, r, members, hero }
  deg/r: group centre (deg from +X toward +Z, like the clouds). members: { kind, along, out, top, w? }
  along = tangential offset (studs, toward increasing deg), out = radial offset, top = crown height (world Y),
  w = width factor (default 1). hero groups get mist at the deck line and on ledges.
  Composition: three layers. Heroes frame the views from the balcony/plaza and the spirit peaks (G1 east
  sentinels and G2 south-west pair either side of the plaza's southern view, G3 the west mesa, G4 the
  north-east grove behind the lone cloud tower, G5 the east arch, G7 the west trio); the middle layer
  fills the windows between with groups of 3/5/7 (G9 is the dense "forest" from the reference); far
  silhouettes on a ring r 1750-2300 melt into the horizon banks. The plaza's north axis behind the spire
  stays empty to r 1100, the south axis to r 1400 (wilds below, and the view from the balcony ends on G6).
]]
local GROUPS = {
	{ "EastSentinels", 48, 680, hero = true, {
		{ "Karst_Twin", 0, 0, 840 }, { "Karst_Needle", -50, -15, 690 }, { "Karst_Stub", 45, 60, 520 } } },
	{ "SouthWestPair", 140, 650, hero = true, {
		{ "Karst_Spire", 0, 0, 800 }, { "Karst_Broken", -65, 30, 590 }, { "Karst_Stub", 55, 45, 480 } } },
	{ "WestMesa", 232, 1000, hero = true, {
		{ "Karst_Mesa", 0, 0, 900 }, { "Karst_Leaning", 85, 30, 700 }, { "Karst_Needle", -80, -20, 640 } } },
	{ "NorthEastGrove", 310, 820, hero = true, {
		{ "Karst_Tower", 0, 0, 780 }, { "Karst_Needle", 70, 50, 640 }, { "Karst_Twin", -80, -10, 720 },
		{ "Karst_Stub", 110, 10, 490 }, { "Karst_Trio", -20, 60, 610 } } },
	{ "EastArch", 355, 880, hero = true, {
		{ "Karst_Arch", 0, 0, 720 }, { "Karst_Spire", 95, 40, 790 }, { "Karst_Needle", -85, -20, 560 } } },
	{ "WestTrio", 182, 880, hero = true, {
		{ "Karst_Leaning", 0, 0, 700 }, { "Karst_Trio", 75, 40, 630 }, { "Karst_Stub", -65, -20, 470 } } },
	{ "SouthHorizon", 92, 1500, {
		{ "Karst_Tower", 0, 0, 830 }, { "Karst_Twin", 100, -20, 760 }, { "KarstFar_Spire", -95, 30, 700 },
		{ "KarstFar_Spire", 175, 70, 610 }, { "KarstFar_Tower", -170, -40, 560, 0.8 } } },
	{ "NorthBack", 262, 1150, {
		{ "KarstFar_Spire", 0, 0, 650 }, { "KarstFar_Spire", -45, 40, 560, 0.8 }, { "KarstFar_Tower", 70, 10, 540, 0.7 } } },
	{ "EastForest", 18, 1250, {
		{ "Karst_Tower", 0, 0, 760 }, { "Karst_Spire", 85, 50, 700 }, { "KarstFar_Spire", -75, 40, 600 },
		{ "KarstFar_Twin", 155, -30, 680 }, { "KarstFar_Spire", -145, -40, 560, 0.8 }, { "Karst_Stub", 40, -95, 500 },
		{ "KarstFar_Spire", -30, 125, 640, 0.9 } } },
	{ "SouthWestField", 146, 1100, {
		{ "Karst_Spire", 0, 0, 740 }, { "KarstFar_Tower", 80, 40, 580, 0.8 }, { "KarstFar_Spire", -75, 30, 640 },
		{ "Karst_Stub", 30, -80, 480 }, { "KarstFar_Twin", -40, 110, 700 } } },
	{ "NorthWestPair", 205, 1180, {
		{ "KarstFar_Tower", 0, 0, 720 }, { "KarstFar_Spire", 70, 30, 600 }, { "KarstFar_Spire", -60, 40, 520, 0.8 } } },
	{ "NorthEastFar", 285, 1450, {
		{ "KarstFar_Tower", 0, 0, 760 }, { "KarstFar_Spire", 90, 40, 680 }, { "KarstFar_Twin", -85, 30, 720 },
		{ "KarstFar_Spire", 40, -90, 560, 0.8 }, { "KarstFar_Spire", -30, 130, 640 } } },
	{ "SouthWestFar", 118, 1380, {
		{ "KarstFar_Twin", 0, 0, 720 }, { "KarstFar_Spire", 80, 30, 620 }, { "KarstFar_Spire", -70, 40, 560, 0.8 } } },
	{ "SouthEastFar", 62, 1500, {
		{ "KarstFar_Tower", 0, 0, 780 }, { "KarstFar_Spire", -85, 25, 660 }, { "KarstFar_Spire", 75, 50, 590, 0.8 } } },
	{ "NorthWestFar", 240, 1420, {
		{ "KarstFar_Spire", 0, 0, 800 }, { "KarstFar_Tower", 95, 40, 700 }, { "KarstFar_Twin", -90, 30, 760 },
		{ "KarstFar_Spire", 45, -95, 580, 0.8 }, { "KarstFar_Spire", -40, 130, 650 } } },
	-- far ring: silhouettes into the horizon banks (sizes 5/3/3/5/3/3/5/3 round the ring, uneven spacing)
	{ "Far_008", 8, 1950, {
		{ "KarstFar_Tower", 0, 0, 900, 1.2 }, { "KarstFar_Spire", 120, 60, 820 }, { "KarstFar_Spire", -110, 40, 760 },
		{ "KarstFar_Twin", 220, -40, 860 }, { "KarstFar_Spire", -230, -30, 700 } } },
	{ "Far_050", 50, 2150, {
		{ "KarstFar_Twin", 0, 0, 880, 1.1 }, { "KarstFar_Spire", 130, 50, 780 }, { "KarstFar_Spire", -120, 60, 720 } } },
	{ "Far_133", 133, 2050, {
		{ "KarstFar_Spire", 0, 0, 900 }, { "KarstFar_Tower", 140, 40, 780, 1.1 }, { "KarstFar_Spire", -130, 70, 740 } } },
	{ "Far_172", 172, 1900, {
		{ "KarstFar_Tower", 0, 0, 920, 1.2 }, { "KarstFar_Spire", 120, 50, 800 }, { "KarstFar_Twin", -125, 40, 840 },
		{ "KarstFar_Spire", 230, -30, 700 }, { "KarstFar_Spire", -240, -50, 760 } } },
	{ "Far_214", 214, 2200, {
		{ "KarstFar_Spire", 0, 0, 860 }, { "KarstFar_Spire", 110, 40, 760 }, { "KarstFar_Tower", -130, 60, 800, 1.1 } } },
	{ "Far_266", 266, 1950, {
		{ "KarstFar_Twin", 0, 0, 900, 1.2 }, { "KarstFar_Spire", 125, 45, 780 }, { "KarstFar_Spire", -120, 30, 720 } } },
	{ "Far_301", 301, 2100, {
		{ "KarstFar_Tower", 0, 0, 940, 1.2 }, { "KarstFar_Spire", 135, 50, 820 }, { "KarstFar_Spire", -125, 40, 760 },
		{ "KarstFar_Twin", 240, -40, 860 }, { "KarstFar_Spire", -235, -50, 720 } } },
	{ "Far_338", 338, 2250, {
		{ "KarstFar_Spire", 0, 0, 880 }, { "KarstFar_Tower", 130, 50, 800, 1.1 }, { "KarstFar_Spire", -120, 40, 740 } } },
}

local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local map = workspace.Map

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Locked = false
end

local function robloxSize(name)
	local s = MESHES[name].size
	return Vector3.new(s[1], s[3], s[2])
end

-- kit -------------------------------------------------------------------------------------------------

local function kit()
	local folder = ServerStorage:FindFirstChild("KarstKit")
	local found, containers = {}, {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and MESHES[d.Name] and not d:IsDescendantOf(map) then
			assert(not found[d.Name], "two imported copies of " .. d.Name .. "; delete the extra import first")
			found[d.Name] = d
			local top = d
			while top.Parent ~= workspace do
				top = top.Parent
			end
			containers[top] = true
		end
	end
	if next(found) == nil then
		assert(folder and folder:FindFirstChildWhichIsA("MeshPart"), "no Karst_* import found; File > Import 3D Karst.fbx first")
		return -- re-run on the existing kit
	end
	for name in MESHES do
		assert(found[name], "imported mesh " .. name .. " missing from the Karst.fbx import")
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "KarstKit"
	for name, part in found do
		part = part :: MeshPart
		part.Size = robloxSize(name)
		part.CFrame = CFrame.new()
		part.Material = Enum.Material.SmoothPlastic -- as PeakRock; colour is set per pillar
		part.TextureID = ""
		part.CollisionFidelity = Enum.CollisionFidelity.Box
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		part.DoubleSided = false
		quiet(part)
		part.Parent = folder
	end
	for top in containers do
		if top.Parent and top ~= folder then
			top:Destroy()
		end
	end
	folder.Parent = ServerStorage
end

-- layout ----------------------------------------------------------------------------------------------

local function polar(deg, r)
	local a = math.rad(deg)
	return Vector2.new(math.cos(a) * r, math.sin(a) * r)
end
local function b2r(x, y, z) -- Blender kit coords -> Roblox local about the kit origin
	return Vector3.new(x, z, -y)
end

local deckParts = {}
local function collectDeck()
	local deck = map.Clouds:FindFirstChild("Deck")
	if deck then
		for _, p in deck:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(deckParts, p)
			end
		end
	end
end

-- (joint y, deck top) at a spot: the mid height of the highest deck clump whose core covers it
local function deckAt(x: number, z: number)
	local best, top = nil, nil
	for _, p in deckParts do
		local l = p.CFrame:PointToObjectSpace(Vector3.new(x, p.Position.Y, z))
		local nx, nz = l.X / (p.Size.X / 2), l.Z / (p.Size.Z / 2)
		if nx * nx + nz * nz < 0.8 then
			local t = p.Position.Y + p.Size.Y / 2
			if not top or t > top then
				best, top = p.Position.Y, t
			end
		end
	end
	return best, top
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { workspace.Terrain }
local function groundAt(x: number, z: number)
	local hit = workspace:Raycast(Vector3.new(x, 280, z), Vector3.new(0, -400, 0), rayParams)
	return hit and hit.Position.Y or 0
end

local warnings = {}
local function check(name: string, p: Vector2, radius: number)
	local r = p.Magnitude
	local deg = math.deg(math.atan2(p.Y, p.X)) % 360
	for k = 0, 7 do
		local c = polar(22.5 + 45 * k, PEAK_R)
		if (p - c).Magnitude < PEAK_CLEAR + radius then
			table.insert(warnings, name .. " near Peak_" .. (k + 1))
		end
		local diff = math.abs(((deg - (22.5 + 45 * k) + 180) % 360) - 180)
		if r < WEDGE_R and diff < WEDGE_DEG then
			table.insert(warnings, name .. " in the view wedge of Peak_" .. (k + 1))
		end
	end
	if p.X > WILDS[1] - radius and p.X < WILDS[2] + radius and p.Y > WILDS[3] - radius and p.Y < WILDS[4] + radius then
		table.insert(warnings, name .. " over the wilds field")
	end
	for _, k in KEEP do
		if (p - Vector2.new(k[1], k[2])).Magnitude < k[3] + radius then
			table.insert(warnings, name .. " near ground spot " .. k[1] .. "," .. k[2])
		end
	end
	for _, g in GAPS do
		if (p - polar(g[1], g[2])).Magnitude < g[3] + GAP_MARGIN + radius then
			table.insert(warnings, name .. " in deck gap " .. g[1] .. "/" .. g[2])
		end
	end
end

local planted = {} -- { p, r } of every pillar placed so far (overlap check)
local templates = {}
local function place(model: Model, name: string, origin: CFrame, sh: number, sv: number)
	local m = MESHES[name]
	local p = templates[name]:Clone()
	local c = m.center
	p.Size = Vector3.new(m.size[1] * sh, m.size[3] * sv, m.size[2] * sh)
	p.CFrame = origin * CFrame.Angles(0, math.pi, 0) * CFrame.new(-c[1] * sh, c[3] * sv, c[2] * sh)
	p.Parent = model
	return p
end

local function block(model: Model, name: string, bottom: Vector3, top: number, radius: number, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(top - bottom.Y, radius * 2, radius * 2)
	p.CFrame = CFrame.new(bottom.X, (bottom.Y + top) / 2, bottom.Z) * CFrame.Angles(0, 0, math.pi / 2)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	quiet(p)
	p.Parent = model
	return p
end

-- decoration draws from its own stream, so the layout (and the blockout) stays the same with or without it
local deco = Random.new(SEED + 1)
local function drand(a, b)
	return deco:NextNumber(a, b)
end

-- palette (docs/systems/map.md): each pillar a step either way inside its family
-- The rock takes the spirit peaks' PeakRock look (material, variant, colour) and the lawns the colour of
-- the peaks' terrain lawn (LeafyGrass), read from the place so the pillars follow when those change.
local ROCK_BASE, ROCK_MATERIAL, ROCK_VARIANT = Color3.fromHex("7A7570"), Enum.Material.SmoothPlastic, ""
local LAWN_BASE = Color3.fromHex("6E8F5A")
do
	local peak = map.Sect:FindFirstChild("SpiritPeaks") and map.Sect.SpiritPeaks:FindFirstChild("Peak_1")
	local rock = peak and peak:FindFirstChild("Pillar") and peak.Pillar:FindFirstChild("PeakRock")
	if rock then
		ROCK_BASE, ROCK_MATERIAL, ROCK_VARIANT = rock.Color, rock.Material, rock.MaterialVariant
	end
	local ok, c = pcall(function()
		return workspace.Terrain:GetMaterialColor(Enum.Material.LeafyGrass)
	end)
	if ok and c then
		LAWN_BASE = c:Lerp(Color3.new(0, 0, 0), 0.32) -- terrain grass renders darker than its material colour
	end
end
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local ROCK_COLORS = { ROCK_BASE:Lerp(BLACK, 0.14), ROCK_BASE, ROCK_BASE:Lerp(WHITE, 0.1) }
local TRUNK_COLORS = { ROCK_BASE:Lerp(BLACK, 0.3) }
local LAWN_COLORS = { LAWN_BASE:Lerp(BLACK, 0.12), LAWN_BASE, LAWN_BASE:Lerp(WHITE, 0.08) }
local function shade(c3, spread: number)
	local t = math.clamp(0.5 + drand(-spread, spread) * 0.5, 0, 1) * 2
	return t < 1 and c3[1]:Lerp(c3[2], t) or c3[2]:Lerp(c3[3], t - 1)
end

-- the pines and bushes the spirit peaks use (CliffDecor): Map Detailing pines, the stylized green bush
local TREE_R = 1400 -- no trees past this radius (haze)
local TREES_PER_PILLAR = 3 -- pines on non-hero pillars
local PINE_H = 34 -- a scale-1 spot's pine height (studs)
local BUSH_W = 11
local treeTemplates
do
	local lib = ServerStorage:FindFirstChild("AssetLibrary")
	local pack = lib and lib:FindFirstChild("Map Detailing") and lib["Map Detailing"]:FindFirstChild("Asset Pack")
	local bushes = lib and lib:FindFirstChild("Stylized Foliage + Pots") and lib["Stylized Foliage + Pots"]:FindFirstChild("Stylized Bushes")
	if pack and bushes then
		local pines = {}
		for _, n in { "Pine Tree 2", "Pine Tree 3" } do
			table.insert(pines, pack:FindFirstChild(n))
		end
		local bush
		for _, b in bushes:GetChildren() do
			if b.Name == "Stylized Bush (Green)" and b:IsA("Model") then
				local _, sz = b:GetBoundingBox()
				if sz.X > 14 and sz.X < 20 and sz.Y < 12 then
					bush = b
					break
				end
			end
		end
		if #pines == 2 and bush then
			treeTemplates = { pine = pines, bush = bush }
		end
	end
end
local treeCount = { pine = 0, bush = 0 }
local function tree(model: Model, kind: string, at: Vector3, s: number)
	local src = kind == "pine" and treeTemplates.pine[deco:NextInteger(1, 2)] or treeTemplates.bush
	local m = src:Clone()
	local _, size = m:GetBoundingBox()
	local target = kind == "pine" and PINE_H * s * drand(0.85, 1.15) / size.Y or BUSH_W * s * drand(0.85, 1.15) / size.X
	m:ScaleTo(m:GetScale() * target)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, drand(0, 2 * math.pi), 0))
	local cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (at - Vector3.new(cf.X, cf.Y - sz.Y / 2, cf.Z)) - Vector3.new(0, kind == "pine" and 0.8 or sz.Y * 0.25, 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			quiet(d)
			if d:IsA("MeshPart") then
				d.CollisionFidelity = Enum.CollisionFidelity.Box
			end
		end
	end
	m.Name = kind == "pine" and "Pine" or "Bush"
	m.Parent = model
	treeCount[kind] += 1
end

local mistTemplate = ServerStorage:FindFirstChild("AmbientFX") and ServerStorage.AmbientFX:FindFirstChild("MistWisps")
local mistCount = 0
local function mist(model: Model, anchor: BasePart, world: Vector3, width: number)
	local a = Instance.new("Attachment")
	a.Name = "FX_KarstMist"
	a.WorldPosition = world
	a.Parent = anchor
	mistCount += 1
	if mistTemplate then
		local w = mistTemplate:Clone()
		w.Size = Vector3.new(width, w.Size.Y, width)
		w.CFrame = CFrame.new(world)
		quiet(w)
		w.Parent = model
	end
end

-- the size of one pillar at a spot: joint height from the deck there, vertical and horizontal scale, the
-- radius of its footprint at the joint. Jitter comes from the pillar's own seed, so measuring twice gives the
-- same answer.
local function measure(kindName: string, p: Vector2, top: number, w: number, seed: number)
	local kind = assert(KINDS[kindName], "unknown kind " .. kindName)
	local joint, deckTop = deckAt(p.X, p.Y)
	local covered = joint ~= nil
	joint = joint or JOINT_DEFAULT
	local hmax = 0
	for _, leg in kind.legs do
		hmax = math.max(hmax, leg.h)
	end
	local own = Random.new(seed)
	local sv = (top - joint) / hmax
	local sh = math.clamp(sv ^ 0.55 * own:NextNumber(0.92, 1.08), 0.7, 1.5) * w
	local footprint = 0
	for _, leg in kind.legs do
		footprint = math.max(footprint, Vector2.new(leg.x, leg.y).Magnitude * sh + leg.r0 * sh)
	end
	return { kind = kind, joint = joint, deckTop = deckTop, covered = covered, sv = sv, sh = sh, r = footprint,
		yaw = own:NextNumber(0, 2 * math.pi) }
end

-- true when a pillar of footprint r at p keeps every clearance and a sky gap to every pillar placed so far
local function fits(p: Vector2, r: number, gap: number)
	local before = #warnings
	check("probe", p, r)
	local ok = #warnings == before
	for k = #warnings, before + 1, -1 do
		table.remove(warnings, k)
	end
	if not ok then
		return false
	end
	for _, o in planted do
		if (p - o.p).Magnitude < r + o.r + gap then
			return false
		end
	end
	return true
end

-- Compose a group around its first member (the hero, at the group centre). Each other member keeps its
-- preferred side (the spec's along/out offset) but sits just clear of the pillars already standing, a sky gap
-- of 8-30 studs away; when that spot breaks a clearance it tries the nearby bearings, then further out.
-- A member that fits nowhere is dropped with a warning.
local SWEEP = { 0, 25, -25, 50, -50, 80, -80, 115, -115, 150, -150, 180 }
local function compose(g, gi: number)
	local centre, deg = polar(g[2], g[3]), g[2]
	local radial, tangent = polar(deg, 1), polar(deg + 90, 1)
	local out = {}
	for i, spec in g[4] do
		local kindName, along, off, top, w = spec[1], spec[2], spec[3], spec[4], spec[5] or 1
		local seed = SEED + gi * 997 + i * 31
		local gap = 8 + 22 * Random.new(seed + 7):NextNumber()
		local chosen, m
		if i == 1 then
			for _, d in { 0, 40, 80, 120 } do
				for _, a in SWEEP do
					local q = centre + polar(deg + 90 + a, d)
					m = measure(kindName, q, top, w, seed)
					if fits(q, m.r, gap) then
						chosen = q
						break
					end
				end
				if chosen then
					break
				end
			end
		else
			local pref = tangent * along + radial * off
			local base = pref.Magnitude > 1 and math.deg(math.atan2(pref.Y, pref.X)) or deg + 90
			local anchor = out[1] and out[1].p or centre
			for _, grow in { 1, 1.3, 1.7 } do
				for _, a in SWEEP do
					local dir = polar(base + a, 1)
					-- walk out from the anchor until clear of everything already standing
					local q
					for step = 0, 80 do
						q = anchor + dir * (step * 6)
						m = measure(kindName, q, top, w, seed)
						local clear = true
						for _, o in planted do
							if (q - o.p).Magnitude < m.r + o.r + gap * grow then
								clear = false
								break
							end
						end
						if clear then
							break
						end
					end
					if fits(q, m.r, gap) then
						chosen = q
						break
					end
				end
				if chosen then
					break
				end
			end
		end
		if chosen then
			table.insert(planted, { p = chosen, r = m.r })
			table.insert(out, { p = chosen, m = m, spec = spec, idx = i })
		else
			table.insert(warnings, g[1] .. "_" .. i .. " " .. kindName .. " dropped: no clear spot")
		end
	end
	return out
end

local function pillar(parent: Instance, gname: string, idx: number, spec, p: Vector2, m, deg: number, hero: boolean)
	local kindName = spec[1]
	local kind = m.kind
	local radial = polar(deg, 1)
	local name = string.format("%s_%d_%s", gname, idx, (kindName:gsub("^Karst%w*_", "")))
	local far = kindName:sub(1, #FAR_FROM) == FAR_FROM
	local joint, deckTop, covered, sv, sh, footprint = m.joint, m.deckTop, m.covered, m.sv, m.sh, m.r
	if not covered and p.Magnitude < 1750 then
		table.insert(warnings, name .. " joint not under a deck clump")
	end
	local origin = CFrame.new(p.X, joint, p.Y) * CFrame.Angles(0, m.yaw, 0)
	check(name, p, footprint)

	local model = Instance.new("Model")
	model.Name = name
	local upper
	if BLOCKOUT then
		for li, leg in kind.legs do
			local lp = origin * b2r(leg.x * sh, leg.y * sh, 0)
			local g = groundAt(lp.X, lp.Z)
			block(model, "Leg" .. li, Vector3.new(lp.X, g - SINK, lp.Z), joint + leg.h * sv, leg.r0 * sh, BLOCK_COLOR)
		end
		local j = block(model, "Joint", Vector3.new(p.X, joint - 1, p.Y), joint + 1, footprint + 6, Color3.fromRGB(200, 90, 80))
		j.Transparency = 0.4
	else
		upper = place(model, kindName, origin, sh, sv)
		upper.Color = shade(ROCK_COLORS, 0.5)
		upper.Material, upper.MaterialVariant = ROCK_MATERIAL, ROCK_VARIANT
		if MESHES[kindName .. "_Green"] then
			place(model, kindName .. "_Green", origin, sh, sv).Color = shade(LAWN_COLORS, 0.6)
		end
		-- the peaks' library pines and bushes on the lawns (near pillars only; all spots on heroes)
		if not far and treeTemplates and p.Magnitude < TREE_R then
			local budget = hero and 99 or TREES_PER_PILLAR
			for _, t in kind.trees do
				if budget <= 0 then
					break
				end
				if t[1] == "pine" or hero then
					budget -= 1
					tree(model, t[1], origin * b2r(t[2] * sh, t[3] * sh, t[4] * sv), t[5] * math.min(sh, 1.25))
				end
			end
		end
		local trunkName = far and FAR_TRUNK or TRUNK
		local tk = KINDS[trunkName]
		local tleg = tk.legs[1]
		for _, leg in kind.legs do
			local lp = origin * b2r(leg.x * sh, leg.y * sh, 0)
			local g = groundAt(lp.X, lp.Z)
			local base = g - SINK
			local tsv = (joint - base + 14) / tleg.h -- trunk top tucks 14 into the upper piece
			local tsh = leg.r0 * sh * 1.04 / tleg.rtop -- trunk top a hair wider than the upper's foot
			local tOrigin = CFrame.new(lp.X, base, lp.Z) * CFrame.Angles(0, drand(0, 2 * math.pi), 0)
			local t = place(model, trunkName, tOrigin, tsh, tsv)
			-- the same stone, a touch darker in the shade under the deck; exactly the same where the deck is
			-- thin over the joint, so no colour seam shows there
			t.Color = covered and upper.Color:Lerp(TRUNK_COLORS[1], 0.25) or upper.Color
			t.Material, t.MaterialVariant = ROCK_MATERIAL, ROCK_VARIANT
			if Vector2.new(lp.X, lp.Z).Magnitude < NO_COLLIDER_R then
				local c = Instance.new("Part")
				c.Name = "Collider"
				c.Shape = Enum.PartType.Cylinder
				local rr = tleg.r0 * tsh * 1.1 -- flared foot
				c.Size = Vector3.new(COLLIDER_H + SINK, rr * 2, rr * 2)
				c.CFrame = CFrame.new(lp.X, base + (COLLIDER_H + SINK) / 2, lp.Z) * CFrame.Angles(0, 0, math.pi / 2)
				c.Transparency = 1
				c.Anchored = true
				c.CanCollide = true
				c.CanQuery = true
				c.CanTouch = false
				c.CastShadow = false
				c.Parent = model
			end
		end
		if hero and idx <= 2 then
			-- mist where the deck wraps the pillar, on the side facing the main peak
			local inward = -radial
			local leg = kind.legs[1]
			local y = (deckTop or joint + 60) - 10
			local at = Vector3.new(p.X, y, p.Y) + Vector3.new(inward.X, 0, inward.Y) * leg.r0 * sh
			mist(model, upper, at, leg.r0 * sh * 2 + 40)
			local ledge = kind.ledges[1]
			if ledge and idx == 1 then
				local lw = origin * b2r(ledge.x * sh, ledge.y * sh, ledge.z * sv)
				mist(model, upper, lw + Vector3.new(inward.X, 0, inward.Y) * ledge.r * sh, ledge.r * sh * 2 + 20)
			end
		end
	end
	model.WorldPivot = CFrame.new(p.X, joint, p.Y)
	model.Parent = parent
	return model
end

local function layout()
	collectDeck()
	local root
	if BLOCKOUT then
		root = workspace:FindFirstChild("_KarstBlockout")
		if root then
			root:Destroy()
		end
		root = Instance.new("Folder")
		root.Name = "_KarstBlockout"
		root.Parent = workspace
	else
		local kitFolder = assert(ServerStorage:FindFirstChild("KarstKit"), "run the kit stage first")
		for name in MESHES do
			templates[name] = assert(kitFolder:FindFirstChild(name), "KarstKit." .. name .. " missing")
		end
		local old = map:FindFirstChild("Karst")
		if old then
			old:Destroy()
		end
		root = Instance.new("Folder")
		root.Name = "Karst"
		root.Parent = map
	end
	local counts = { pillars = 0, groups = 0 }
	for gi, g in GROUPS do
		local model = Instance.new("Model")
		model.Name = g[1]
		for _, it in compose(g, gi) do
			pillar(model, g[1], it.idx, it.spec, it.p, it.m, g[2], g.hero == true)
			counts.pillars += 1
		end
		model.Parent = root
		counts.groups += 1
		task.wait()
	end
	return counts, root
end

local rec = CHS:TryBeginRecording("Place karst")
local ok, counts, root = pcall(function()
	if STAGES.kit and not BLOCKOUT then
		kit()
	end
	if STAGES.layout then
		return layout()
	end
	return nil
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
assert(ok, counts)
if not counts then
	return "karst kit ready"
end
local parts, tris = 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d:IsA("MeshPart") and MESHES[d.Name] then
			tris += MESHES[d.Name].tris
		end
	end
end
return string.format("karst %s: %d groups, %d pillars, %d parts, %d kit tris placed, %d pines, %d bushes, %d mist spots\n%s",
	BLOCKOUT and "blockout" or "placed", counts.groups, counts.pillars, parts, tris, treeCount.pine, treeCount.bush, mistCount,
	#warnings > 0 and ("WARN " .. table.concat(warnings, "\nWARN ")) or "no clearance warnings")
