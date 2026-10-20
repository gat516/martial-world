--!strict
-- Every gameplay tunable in one place. Herb stats live in Herbs.luau.
-- Progression pacing and per-stage difficulty (qi, breakthroughs, tribulations,
-- insight, beast strength) live in Pacing.luau, the master tuning file.

local Pacing = require(script.Parent.Pacing)

return {
	Data = {
		STORE_NAME = "PlayerData_v1",
		AUTOSAVE_SECONDS = 120,
		LOCK_STALE_SECONDS = 360, -- a lock not refreshed this long belongs to a dead server
		LOCK_WAIT_SECONDS = 15, -- wait this long for another server to release, then take over
		LOCK_RETRY_SECONDS = 3,
		STARTING_SEEDS = { SpiritGrass = 6 },
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
		-- Breakthrough and forced-breakthrough numbers: Pacing.Breakthrough.
	},

	-- Qi spent per run, efficiency, deviation, and each stage's run length and
	-- difficulty are progression pacing: Pacing.Refine and Pacing.Curve.
	Circulation = {
		IMPURITIES_PER_10S = 1.5, -- impure beats/motes per 10 s of run, in every game
		ACCURACY_WEIGHT = 0.75, -- score = accuracy * this + purged share * the rest
		MIN_DURATION_FRACTION = 0.9, -- a run reported sooner than this is rejected
		RUN_TIMEOUT_GRACE = 15, -- seconds past the duration before a run is dropped
		PEAK_RADIUS = 60, -- studs from your plateau centre that count as on your peak
		FIRST_RUN_GAME = "Maze", -- the very first run is always this game...
		FIRST_RUN_DURATION = 15, -- ...short...
		FIRST_RUN_DIFFICULTY = -0.5, -- ...and easier than `easy` (below 0 blends past it)

		-- Minigames. Each run gets a difficulty from 0 (easy) to 1 (hard), set per
		-- stage in Pacing.Curve (`difficulty`); each game blends every value in
		-- `easy` toward `hard` by it. `weight` is how often the game is picked (0 = never).
		Games = {
			-- Maze Formation: drag your qi through the corridors, out of maze after maze.
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
		-- passive multipliers, from Pacing.Meditation (read them there)
		ANYWHERE = Pacing.Meditation.ANYWHERE, -- meditating anywhere
		ON_PEAK = Pacing.Meditation.ON_PEAK, -- on your own spirit peak (within Circulation.PEAK_RADIUS)
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
		MARKET_RANGE = 24, -- studs from the Spirit Market stall to trade with the Herbalist
		MAX_BUY = 10, -- items per purchase
	},

	-- Spirit Stones: the currency build items are bought with at the Spirit Market
	-- on the main peak. Beasts drop them (Enemies.luau `stones`), and so do qi nodes.
	Economy = {
		STARTING_STONES = 150,
		NODE_STONES = { 4, 8 }, -- per qi node gather (min, max)
	},

	-- Plant numbers live in Herbs.luau, weather's effects on plants in Weather.luau.
	Garden = {
		SEEDS_BACK = { 1, 2 }, -- seeds returned per single harvest (min, max)
		EDGE = 0.5, -- studs a stem keeps from a plot's edge
		TICK = 10, -- seconds between weather growth, swelling and mutation rolls
		AURA_CAP = 1.5, -- the most cultivation speed a garden's plants can add
		MAX_SELL = 999, -- herbs per sell request
		MAX_SEEDS_BUY = 25, -- seeds per buy request
		-- wild herbs that sprout on owned peaks during their weather event
		WILD_PER_PEAK = 3, -- sprouts on each owned peak as the event starts
		WILD_YIELD = { 1, 2 }, -- herbs per wild sprout
		WILD_SEED_CHANCE = 0.5, -- a wild sprout also gives its seed
		WILD_SECONDS = 300, -- a sprout withers after this long
		-- seeds beasts drop: each damager rolls once per kill
		BEAST_SEED_CHANCE = 0.12, -- normal beasts
		BOSS_SEEDS = { 2, 4 }, -- bosses always drop this many
		BEAST_SEEDS = { "SpiritGrass", "CloudMint", "JadeLotus", "PurpleBamboo", "BloodGinseng" },
		BEAST_SEED_WEIGHTS = { 40, 25, 15, 15, 5 },
		-- "Grow now": a Robux developer product that finishes one growing plant.
		-- A product has a fixed price, so there is one per tier; the tier is picked
		-- by the seconds the plant has left (first tier whose upTo covers it).
		-- TODO: create the three developer products (3, 6 and 9 Robux) in the
		-- Creator Dashboard and paste their ids here. 0 is a placeholder: the
		-- prompt still shows, but pressing it only warns in the output.
		GROW_NOW = {
			{ upTo = 5 * 60, robux = 3, productId = 0 }, -- almost done
			{ upTo = 30 * 60, robux = 6, productId = 0 },
			{ upTo = math.huge, robux = 9, productId = 0 }, -- just planted, or a long grower
		},
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
		-- qi node yield and cooldown: Pacing.Income
		RESPAWN_SPREAD = 0.3, -- respawn timers vary by up to this share
		AI_TICK = 0.1, -- seconds between enemy decisions
	},

	-- Insight and technique manuals: Pacing.Rewards.

	-- The heavenly tribulation's arena. How hard it is (length, strike rate and
	-- damage, fail cooldown) is per stage: Pacing.Curve `tribulation`.
	Tribulation = {
		CENTER = Vector3.new(2, 857, -86), -- on the main peak's tribulation platform
		ARENA_RADIUS = 34, -- stepping farther out than this fails the tribulation
		STRIKE_RADIUS = 5,
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

	-- Offline cultivation and the daily raw qi bonus: Pacing.Income.

	-- Admins (AdminPanel): the creator, these user ids, and anyone in Studio.
	Admin = {
		USER_IDS = {} :: { number },
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
