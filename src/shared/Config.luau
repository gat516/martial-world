--!strict
-- Every gameplay tunable in one place. Herb stats live in Herbs.luau.

return {
	Data = {
		STORE_NAME = "PlayerData_v1",
		AUTOSAVE_SECONDS = 120,
		STARTING_SEEDS = { SpiritGrass = 6 },
	},

	Cultivation = {
		BASE_RATE = 1, -- Qi per second before buffs and garden aura
		BASE_WALKSPEED = 16,
		STATE_REFRESH_SECONDS = 10, -- full HUD state push even when nothing expired
	},

	Build = {
		RADIUS = 47, -- studs from the plateau centre, horizontally
		MIN_Y = -30, -- down to the abode hall floor (-25)
		MAX_Y = 30,
		MAX_ITEMS = 120,
		GRID = 0.5, -- placement snap, studs
		ROTATE_STEP = 45, -- degrees
		MIN_INTERVAL = 0.15, -- seconds between build requests per player
	},

	Garden = {
		SEEDS_BACK = { 1, 2 }, -- seeds returned per harvest (min, max)
		PLANT_SPOTS = { -4, 0, 4 }, -- plant offsets along a bed's long axis
		SPROUT_SCALE = 0.35, -- plant size at planting, grows to 1 when mature
	},

	Spawn = {
		HEIGHT = 4, -- studs above a peak's spawn pad
	},

	-- Studio playtests only: topped up on join so systems can be tried right away.
	TestKit = {
		ENABLED = true,
		HERBS_EACH = 5, -- every herb type
		SEEDS_EACH = 5, -- every seed type
	},
}
