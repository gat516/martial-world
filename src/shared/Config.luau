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

	Movement = {
		RUN_BONUS = 10, -- added to walking speed, including herb buffs (16 -> 26)
		RUN_ANIMATION_SPEED = 26, -- studs/s at the run animation's original playback rate
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
		-- Breakthroughs happen seated in meditation. In combat, at low health, one can
		-- be forced early; the new realm then starts in qi debt (negative cultivation)
		-- that peaceful cultivation has to pay off before the bar fills again.
		FORCE_BAR_SHARE = 0.9, -- the bar must be at least this full to force it
		FORCE_HEALTH_SHARE = 0.35, -- and health at most this share of max, in combat
		FORCE_DEBT_SHARE = 0.5, -- debt: the bar's shortfall plus this share of the new bar
	},

	Circulation = {
		RUNS_PER_DANTIAN = 2.5, -- a full run spends dantian / this raw qi
		MIN_RUN_FRACTION = 0.25, -- need at least this share of a full run's qi to start
		DURATION_START = 20, -- seconds at QC1
		DURATION_STEP = 2, -- added per realm stage
		DURATION_MAX = 40,
		IMPURITIES_PER_10S = 1.5, -- impure beats/motes per 10 s of run, in every game
		ACCURACY_WEIGHT = 0.75, -- score = accuracy * this + purged share * the rest
		EFFICIENCY_MIN = 0.5, -- cultivation per raw qi at score 0
		EFFICIENCY_MAX = 1.3, -- and at score 1
		DEVIATION_SCORE = 0.35, -- below this the run causes a qi deviation
		DEVIATION_SECONDS = 20, -- no circulating and no passive cultivation meanwhile
		MIN_DURATION_FRACTION = 0.9, -- a run reported sooner than this is rejected
		RUN_TIMEOUT_GRACE = 15, -- seconds past the duration before a run is dropped
		PEAK_RADIUS = 60, -- studs from your plateau centre that count as on your peak
		FIRST_RUN_GAME = "Maze", -- the very first run is always this game...
		FIRST_RUN_DURATION = 15, -- ...short...
		FIRST_RUN_DIFFICULTY = -0.5, -- ...and easier than `easy` (below 0 blends past it)

		-- Minigame difficulty. Each run gets a difficulty from 0 (easy) to 1 (hard):
		--   (realm stage - 1) / DIFFICULTY_STAGES * DIFFICULTY, clamped.
		-- DIFFICULTY is the master knob for all games: 0 keeps every run at `easy`,
		-- 1 reaches `hard` after DIFFICULTY_STAGES stages, 2 gets there twice as fast.
		-- Each game blends every value in `easy` toward `hard` by the run's difficulty.
		-- `weight` is how often the game is picked for a run (0 = never).
		DIFFICULTY = 1,
		DIFFICULTY_STAGES = 9,
		Games = {
			-- Maze Formation: swipe to slide your qi out of maze after maze.
			Maze = {
				weight = 1,
				easy = {
					size = 5, -- cells per side (at least 4)
					par = 8, -- seconds per maze for full accuracy
				},
				hard = { size = 9, par = 14 },
			},
			-- Thread the Meridian: drag a bead along a winding channel without touching its walls.
			Thread = {
				weight = 1,
				easy = {
					width = 0.09, -- channel half-width on level 1, share of the field height
					bends = 3, -- turns on level 1 (each later level adds one)
					par = 9, -- seconds per level for full accuracy
				},
				hard = { width = 0.055, bends = 5, par = 11 },
			},
			-- Meridian Pulse: tap anywhere as each ring closes on its acupoint.
			Pulse = {
				weight = 1,
				easy = {
					window = 0.3, -- seconds either side of the beat that still count ("Good")
					interval = 1.1, -- seconds between beats
					approach = 1.4, -- seconds a ring takes to close
				},
				hard = { window = 0.14, interval = 0.7, approach = 0.9 },
			},
			-- Gather Qi: drag the dantian bowl to catch falling qi and dodge impure motes.
			Gather = {
				weight = 1,
				easy = {
					bowl = 0.3, -- bowl width, share of the field
					fall = 0.45, -- mote fall speed, field heights per second
					interval = 0.6, -- seconds between qi motes
				},
				hard = { bowl = 0.17, fall = 0.8, interval = 0.38 },
			},
		} :: { [string]: { weight: number, easy: { [string]: number }, hard: { [string]: number } } },
	},

	-- Meditation (M / the Cultivate tile, then Meditate): sit still and passive cultivation is
	-- multiplied by where you sit. Seats and artifacts on your own peak add their
	-- bonus when you meditate within ITEM_RANGE of them (the best one counts).
	Meditation = {
		ANYWHERE = 1.5, -- passive multiplier meditating anywhere
		ON_PEAK = 2.5, -- on your own spirit peak (within Circulation.PEAK_RADIUS)
		ITEM_RANGE = 6, -- studs from a seat or artifact for its bonus to count
		-- (each build item's bonus is its `meditation` in BuildItems.luau)
		MAX_DRIFT = 4, -- studs from where you sat down before the server stands you up
	},

	Build = {
		RADIUS = 47, -- studs from the plateau centre, horizontally
		MIN_Y = -30, -- down to the abode hall floor (-25)
		MAX_Y = 30,
		MAX_ITEMS = 120,
		-- Precision presets the Grid button / G cycles: grid snap (studs) and rotation
		-- step (degrees). The server keeps positions to 0.05 studs and yaw to 1 degree.
		PRECISION = {
			{ grid = 1, rotate = 45 },
			{ grid = 2, rotate = 90 },
			{ grid = 4, rotate = 90 },
			{ grid = 0.5, rotate = 15 },
		} :: { { grid: number, rotate: number } },
		MIN_INTERVAL = 0.15, -- seconds between build requests per player
		MAX_CLEARANCE = 2, -- the largest `clearance` any build item has (widens neighbour queries)
		-- Natural ground: peak children whose surfaces count as terrain (items whose
		-- `on` is only "terrain" need these underneath)
		GROUND = { "Plateau", "Pillar" },
		-- Kept clear of building, around these peak children (radius in studs, and
		-- how far above and below the anchor the zone reaches)
		RESERVED = {
			{ anchor = "TeleportArray", name = "the teleport array", radius = 9, above = 14, below = 4 },
			{ anchor = "BridgeGate", name = "the bridge gate", radius = 9, above = 16, below = 6 },
			{ anchor = "AbodeEntrance", name = "the abode entrance", radius = 7, above = 12, below = 4 },
		} :: { { anchor: string, name: string, radius: number, above: number, below: number } },
		-- What placement says blocks it, by the peak child the restricted part is in
		RESTRICTED_NAMES = {
			Bridge = "the bridge",
			BridgeGate = "the bridge gate",
			CaveAbode = "the cave walls",
			NameStele = "the name stele",
			TeleportArray = "the teleport array",
			Pillar = "the rock",
			Garden = "the garden",
		} :: { [string]: string },
		MARKET_RANGE = 24, -- studs from the Spirit Market stall to buy there
		MAX_BUY = 10, -- items per purchase
	},

	-- Spirit Stones: the currency build items are bought with at the Spirit Market
	-- on the main peak. Beasts drop them (Enemies.luau `stones`), and so do qi nodes.
	Economy = {
		STARTING_STONES = 150,
		NODE_STONES = { 4, 8 }, -- per qi node gather (min, max)
	},

	Garden = {
		SEEDS_BACK = { 1, 2 }, -- seeds returned per harvest (min, max)
		PLANT_SPOTS = { -4, 0, 4 }, -- plant offsets along a bed's long axis
		SPROUT_SCALE = 0.35, -- plant size at planting, grows to 1 when mature
	},

	Combat = {
		-- Fist basic attack: a five-hit chain (ReplicatedStorage.Animations.Fists.1-5).
		-- The client predicts hits, casting the hitbox from each animation's "Hit"
		-- marker to its "Hit Stop" marker; the server checks them (see Combat.luau).
		-- Hit/Hit Stop times in the source animations, before playback speed.
		-- Animations 4 and 5 have no markers: their explicit windows below are
		-- the fallback. Never resolve a hit just because an animation stopped.
		FIST_STEPS = {
			{ damage = 8, hit = 0.35, hitStop = 0.50, speed = 1.25, recovery = 0.07 },
			{ damage = 8, hit = 0.35, hitStop = 13 / 30, speed = 1.25, recovery = 0.07 },
			{ damage = 10, hit = 0.35, hitStop = 14 / 30, speed = 1.25, recovery = 0.07 },
			{ damage = 12, hit = 0.35, hitStop = 0.50, speed = 1.25, recovery = 0.07 },
			{ damage = 18, hit = 0.35, hitStop = 16 / 30, speed = 1.15, recovery = 0.10 },
		},
		CHAIN_RESET = 0.85, -- idle time after recovery before returning to hit 1
		CHAIN_COOLDOWN = 0.45, -- final Hit Stop -> earliest next string; survives a dodge
		ATTACK_MOVE_MULTIPLIER = 0.6,
		ATTACK_RECOVERY_MULTIPLIER = 0.8,
		POSE_HOLD_SECONDS = 0.06, -- visual only; action permissions are already free
		ATTACK_IDLE_FADE = 0.24,
		DODGE_IDLE_FADE = 0.24,
		ACTION_CROSSFADE = 0.08, -- a new input takes over the lingering pose quickly
		DODGE_CROSSFADE = 0.035, -- dodge cuts the punch pose almost immediately
		INPUT_BUFFER = 0.20, -- one pending press; dodge takes priority over offense
		CANCEL_RETRY = 0.25, -- technique retry delay if dodged before release
		HIT_TIME_SLACK = 0.04,
		HITBOX = Vector3.new(5, 5, 6), -- width, height, reach in front of the root
		MAX_TARGETS = 1, -- fists hit one enemy per swing (the nearest in the box)
		AIM_RANGE = 14, -- soft auto-aim and auto-attack pick targets this close
		AUTO_RANGE = 6, -- auto-attack swings while the target is this close
		AUTO_ATTACK = true,
		-- server checks
		MAX_LAG = 1.0, -- seconds a swing's timestamp may trail the server clock
		CLOCK_SLACK = 0.1, -- and lead it
		HITBOX_SLACK = 4, -- studs added to each side of the hitbox for movement and lag
		AREA_SLACK = 3, -- studs added to technique areas on the server

		-- Dodge: a flying-sword dash (Q / the Dash button) with brief invulnerability.
		-- Driven by ApplyImpulse scaled by the character's AssemblyMass, so every
		-- avatar dashes the same; the caps below stop slopes and enemies launching it.
		DODGE_COOLDOWN = 1.2,
		DODGE_SPEED = 75, -- studs per second during the dash
		DODGE_SECONDS = 0.32,
		DODGE_RECOVERY = 0.06,
		DODGE_ACCEL = 600, -- studs/s² the dash may correct per second after the first kick
		DODGE_MAX_RISE = 6, -- upward speed cap while dashing, so ramps don't fling you
		DODGE_EXIT_SPEED = 24, -- horizontal speed left when the dash ends
		IFRAME_SECONDS = 0.35, -- invulnerable this long from the dodge's timestamp
		IFRAME_SLACK = 0.1, -- extra server-side allowance for latency
		PERFECT_WINDOW = 0.2, -- dodging this close before a hit lands is a perfect dodge
		PERFECT_REFUND = 1.5, -- seconds taken off every technique cooldown
		PERFECT_ANIMATION_SECONDS = 16 / 60,
		PERFECT_ANIMATION_GRACE = 0.25, -- late confirmation can finish the pose after the dash

		IN_COMBAT_SECONDS = 6, -- after being hurt, travel is blocked this long

		-- Lock-on (client, LockOn.luau): a hard lock the camera and facing follow.
		LOCK_RANGE = 45, -- enemies this close can be locked
		LOCK_BREAK_RANGE = 60, -- the lock lets go past this
		LOCK_LOS_SECONDS = 2.5, -- or once the target has been out of sight this long
		LOCK_FLICK_PIXELS = 90, -- PC: mouse travel that switches target
		LOCK_SWIPE_PIXELS = 60, -- touch: swipe length that switches target
		-- Touch Auto mode: lock the nearest enemy, close in and strike by itself,
		-- so the player only dashes and casts.
		AUTO_LOCK_RANGE = 22,
		AUTO_APPROACH_PAUSE = 1.0, -- seconds after a dash before it closes in again
	},

	-- Teleport formations between your peak, the main peak and the sect gate
	Travel = {
		MAIN_PEAK = Vector3.new(0, 653, 100), -- the plaza, by PlazaSpawn
		SECT_GATE = Vector3.new(0, 9, 500), -- just outside the gate, facing the wilds
		COOLDOWN = 3,
	},

	Wilds = {
		NODE_COOLDOWN = 45, -- seconds before the same player can gather a node again
		NODE_SHARE = 0.2, -- a gather gives this share of the player's dantian
		RESPAWN_SPREAD = 0.3, -- respawn timers vary by up to this share
		AI_TICK = 0.1, -- seconds between enemy decisions
	},

	-- Insight and technique manuals
	Progression = {
		FIRST_KILL_INSIGHT = 1, -- the first kill of each enemy type
		BOSS_INSIGHT = 1, -- every boss kill
		BOSS_FIRST_MANUAL = "LightningTalisman",
		-- kill milestones (total kills): insight and/or a manual, once each
		MILESTONES = {
			{ kills = 3, manual = "PalmStrike" },
			{ kills = 30, insight = 1, manual = "IronSkin" },
			{ kills = 100, insight = 1, manual = "FireSeal" },
		},
	},

	-- The heavenly tribulation before Foundation Establishment
	Tribulation = {
		CENTER = Vector3.new(2, 857, -86), -- on the main peak's tribulation platform
		ARENA_RADIUS = 34, -- stepping farther out than this fails the tribulation
		SECONDS = 30,
		STRIKE_RADIUS = 5,
		WINDUP_START = 1.2, -- seconds a strike's telegraph shows, at the start...
		WINDUP_END = 0.7, -- ...and by the end
		INTERVAL_START = 1.3, -- seconds between strikes, at the start...
		INTERVAL_END = 0.5, -- ...and by the end
		SCATTER = 9, -- strikes land up to this far from the player
		DAMAGE_SHARE = 0.22, -- of max health per strike
		FAIL_COOLDOWN = 120, -- seconds before trying again
	},

	-- Day and night (client-side, in step across clients through the server clock)
	Ambience = {
		DAY_MINUTES = 20, -- real minutes for a full day
		START_HOUR = 9, -- the hour at server-time zero
		NIGHT_LIGHT_SCALE = 1.8, -- lantern light brightness at night...
		DAY_LIGHT_SCALE = 0.5, -- ...and by day, relative to the place's setting
		FIREFLY_RATE = 14,
		PETAL_RATE = 3,
	},

	Spawn = {
		HEIGHT = 4, -- studs above a peak's teleport array when you arrive home
		-- after dying you reform at the main peak (the respawn hub), not on your peak
		RESPAWN_AT_HUB = true,
	},

	Login = {
		OFFLINE_MAX_HOURS = 12, -- offline cultivation counts at most this long
		OFFLINE_RATE = 1, -- share of the online passive rate while away
		DAILY_QI_SHARE = 0.5, -- first login of a day: this share of the dantian as raw qi
	},

	-- Studio playtests only: topped up on join so systems can be tried right away.
	TestKit = {
		ENABLED = true,
		HERBS_EACH = 5, -- every herb type
		SEEDS_EACH = 5, -- every seed type
		ITEMS_EACH = 2, -- every spirit core and treasure
		STONES = 3000, -- Spirit Stones, to try the Spirit Market
		ALL_TECHNIQUES = false, -- own every technique, to test them without earning manuals
		FILL_DANTIAN = true, -- no combat yet, so this is the only steady raw qi source
	},
}
