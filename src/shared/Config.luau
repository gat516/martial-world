--!strict
-- Every gameplay tunable in one place. Herb stats live in Herbs.luau.

return {
	Data = {
		STORE_NAME = "PlayerData_v1",
		AUTOSAVE_SECONDS = 120,
		LOCK_STALE_SECONDS = 360, -- a lock not refreshed this long belongs to a dead server
		LOCK_WAIT_SECONDS = 15, -- wait this long for another server to release, then take over
		LOCK_RETRY_SECONDS = 3,
		STARTING_SEEDS = { SpiritGrass = 6 },
		STARTING_RAW_QI = 60, -- half a QC1 dantian: enough for the first circulation run
	},

	Cultivation = {
		BASE_WALKSPEED = 16,
		STATE_REFRESH_SECONDS = 10, -- full HUD state push even when nothing expired
		-- Passive-progress warnings: shown when the player has been idle a while and
		-- the passive rate is this many times slower than active play would be.
		PASSIVE_SHARE = 0.15, -- passive rate as a share of the expected active rate
		WARN_RATIO = 5,
		WARN_IDLE_SECONDS = 180, -- no runs or breakthroughs for this long
		WARN_INTERVAL = 240, -- at most one warning this often
	},

	Circulation = {
		RUNS_PER_DANTIAN = 2.5, -- a full run spends dantian / this raw qi
		MIN_RUN_FRACTION = 0.25, -- need at least this share of a full run's qi to start
		DURATION_START = 20, -- seconds at QC1
		DURATION_STEP = 2, -- added per realm stage
		DURATION_MAX = 40,
		BAND_START = 0.34, -- green band height as a share of the gauge at QC1
		BAND_STEP = 0.022, -- narrows by this per realm stage
		BAND_MIN = 0.14,
		IMPURITIES_PER_10S = 1.5,
		LOOPS = 2, -- times the orb circles the meridian per run
		ACCURACY_WEIGHT = 0.75, -- score = accuracy * this + purged share * the rest
		EFFICIENCY_MIN = 0.5, -- cultivation per raw qi at score 0
		EFFICIENCY_MAX = 1.3, -- and at score 1
		DEVIATION_SCORE = 0.35, -- below this the run causes a qi deviation
		DEVIATION_SECONDS = 20, -- no circulating and no passive cultivation meanwhile
		MIN_DURATION_FRACTION = 0.9, -- a run reported sooner than this is rejected
		RUN_TIMEOUT_GRACE = 15, -- seconds past the duration before a run is dropped
		PEAK_RADIUS = 60, -- studs from your plateau centre that count as on your peak
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

	Combat = {
		-- Fist basic attack: a four-hit chain (ReplicatedStorage.Animations.Fists.1-4).
		-- The client predicts hits; the server checks them (see Combat.luau).
		FIST_DAMAGE = { 8, 8, 10, 16 }, -- per chain hit, before the realm's power
		SWING_SECONDS = 0.42, -- time between swings
		CHAIN_RESET = 1.0, -- idle seconds before the chain starts over at hit 1
		HIT_DELAY = 0.15, -- seconds from swing to impact, when the client casts the hitbox
		HITBOX = Vector3.new(5, 5, 6), -- width, height, reach in front of the root
		MAX_TARGETS = 1, -- fists hit one enemy per swing (the nearest in the box)
		AIM_RANGE = 14, -- soft auto-aim and auto-attack pick targets this close
		AUTO_RANGE = 6, -- auto-attack swings while the target is this close
		AUTO_ATTACK = true,
		-- server checks
		MAX_LAG = 1.0, -- seconds a swing's timestamp may trail the server clock
		CLOCK_SLACK = 0.1, -- and lead it
		COOLDOWN_SLACK = 0.9, -- swings may be this fraction of SWING_SECONDS apart
		HITBOX_SLACK = 4, -- studs added to each side of the hitbox for movement and lag
		AREA_SLACK = 3, -- studs added to technique areas on the server

		-- Dodge: a flying-sword dash with brief invulnerability
		DODGE_COOLDOWN = 1.2,
		DODGE_SPEED = 75, -- studs per second during the dash
		DODGE_SECONDS = 0.22,
		IFRAME_SECONDS = 0.35, -- invulnerable this long from the dodge's timestamp
		IFRAME_SLACK = 0.1, -- extra server-side allowance for latency
		PERFECT_WINDOW = 0.2, -- dodging this close before a hit lands is a perfect dodge
		PERFECT_REFUND = 1.5, -- seconds taken off every technique cooldown

		IN_COMBAT_SECONDS = 6, -- after being hurt, travel is blocked this long
	},

	Spawn = {
		HEIGHT = 4, -- studs above a peak's spawn pad
	},

	-- Studio playtests only: topped up on join so systems can be tried right away.
	TestKit = {
		ENABLED = true,
		HERBS_EACH = 5, -- every herb type
		SEEDS_EACH = 5, -- every seed type
		ALL_TECHNIQUES = true, -- own every technique (manuals aren't in yet)
		FILL_DANTIAN = true, -- no combat yet, so this is the only steady raw qi source
	},
}
