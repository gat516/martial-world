--!strict
-- Every gameplay tunable in one place. Herb stats live in Herbs.luau.
-- Progression pacing and per-stage difficulty (qi, breakthroughs, tribulations,
-- beast strength) live in Pacing.luau, the master tuning file.

local Pacing = require(script.Parent.Pacing)

export type Step = {
	damage: number, -- before realm power, weapon grade and Dao comprehension
	hit: number, -- the clip's Hit and Hit Stop, in clip seconds (before playback speed)
	hitStop: number,
	speed: number, -- playback speed
	recovery: number, -- real seconds after Hit Stop before the next action
	push: number, -- base knockback studs (Knockback.luau)
}

-- Basic attack chains, one per weapon class (Weapons.luau). Each step plays
-- ReplicatedStorage.Animations.Fists.<n> (Fist) or Animations.Weapons.<Class>.<n>;
-- the animation ids live only in assets/Animations.rbxmx. Hit/hitStop must
-- match each clip's "Hit"/"Hit Stop" markers (tools/anim_markers.luau): the
-- server validates hits against these numbers, not the markers.
-- Chains are 3-5 steps; the last is the finisher (CHAIN_COOLDOWN after it).
local FIST_STEPS: { Step } = {
	{ damage = 8, hit = 0.35, hitStop = 0.50, speed = 1.25, recovery = 0.07, push = 2 },
	{ damage = 8, hit = 0.35, hitStop = 13 / 30, speed = 1.25, recovery = 0.07, push = 2 },
	{ damage = 10, hit = 0.35, hitStop = 14 / 30, speed = 1.25, recovery = 0.07, push = 3 },
	{ damage = 12, hit = 0.35, hitStop = 0.50, speed = 1.25, recovery = 0.07, push = 4 },
	{ damage = 18, hit = 0.35, hitStop = 16 / 30, speed = 1.15, recovery = 0.10, push = 8 },
}

export type ClassCombat = {
	steps: { Step },
	hitbox: Vector3, -- width, height, reach in front of the root
	maxTargets: number, -- enemies one swing can hit (the nearest in the box)
}

local CLASSES: { [string]: ClassCombat } = {
	Fist = { steps = FIST_STEPS, hitbox = Vector3.new(5, 5, 6), maxTargets = 1 },
	-- jian: katana firstm1-fourthm1, one-handed (Hit = the animator's HitFrame 0.333)
	Sword = {
		steps = {
			{ damage = 9, hit = 0.333, hitStop = 0.433, speed = 1.2, recovery = 0.07, push = 2 },
			{ damage = 9, hit = 0.333, hitStop = 0.433, speed = 1.2, recovery = 0.07, push = 2 },
			{ damage = 11, hit = 0.333, hitStop = 0.433, speed = 1.2, recovery = 0.07, push = 3 },
			{ damage = 15, hit = 0.333, hitStop = 0.433, speed = 1.1, recovery = 0.12, push = 6 },
		},
		hitbox = Vector3.new(6, 5, 7),
		maxTargets = 2,
	},
	-- dadao: Greataxe1-5 (set C), upper body only, so it plays while walking
	Saber = {
		steps = {
			{ damage = 9, hit = 0.50, hitStop = 0.60, speed = 1.35, recovery = 0.07, push = 2 },
			{ damage = 9, hit = 0.50, hitStop = 0.60, speed = 1.35, recovery = 0.07, push = 2 },
			{ damage = 11, hit = 0.50, hitStop = 0.60, speed = 1.35, recovery = 0.07, push = 3 },
			{ damage = 12, hit = 0.50, hitStop = 0.60, speed = 1.35, recovery = 0.07, push = 3 },
			{ damage = 18, hit = 0.50, hitStop = 0.60, speed = 1.20, recovery = 0.12, push = 8 },
		},
		hitbox = Vector3.new(7, 5, 7),
		maxTargets = 2,
	},
	-- gs1-gs3: slow, wide sweeps
	Greatsword = {
		steps = {
			{ damage = 12, hit = 0.50, hitStop = 0.6667, speed = 1.15, recovery = 0.08, push = 4 },
			{ damage = 12, hit = 0.50, hitStop = 0.6667, speed = 1.15, recovery = 0.08, push = 4 },
			{ damage = 20, hit = 0.5833, hitStop = 0.6833, speed = 1.05, recovery = 0.15, push = 9 },
		},
		hitbox = Vector3.new(10, 6, 8),
		maxTargets = 3,
	},
	-- "Great axe 1-4" (set A1): long-haft cuts with long reach
	Guandao = {
		steps = {
			{ damage = 10, hit = 0.35, hitStop = 0.4333, speed = 1.10, recovery = 0.07, push = 3 },
			{ damage = 10, hit = 0.3333, hitStop = 0.4167, speed = 1.10, recovery = 0.07, push = 3 },
			{ damage = 12, hit = 0.35, hitStop = 0.4333, speed = 1.10, recovery = 0.07, push = 4 },
			{ damage = 18, hit = 0.30, hitStop = 0.4167, speed = 1.00, recovery = 0.12, push = 8 },
		},
		hitbox = Vector3.new(8, 6, 10),
		maxTargets = 3,
	},
	-- Spear1-4: thrusts that reach ~2.8 studs past the hands
	Spear = {
		steps = {
			{ damage = 9, hit = 0.3167, hitStop = 0.40, speed = 1.2, recovery = 0.07, push = 2 },
			{ damage = 9, hit = 0.30, hitStop = 0.40, speed = 1.2, recovery = 0.07, push = 2 },
			{ damage = 11, hit = 0.30, hitStop = 0.40, speed = 1.2, recovery = 0.07, push = 3 },
			{ damage = 15, hit = 0.2833, hitStop = 0.3833, speed = 1.1, recovery = 0.10, push = 6 },
		},
		hitbox = Vector3.new(4, 5, 11),
		maxTargets = 2,
	},
	-- BoStaff1-4: wide sweeps
	Staff = {
		steps = {
			{ damage = 8, hit = 0.2833, hitStop = 0.40, speed = 1.2, recovery = 0.07, push = 3 },
			{ damage = 8, hit = 0.3167, hitStop = 0.40, speed = 1.2, recovery = 0.07, push = 3 },
			{ damage = 10, hit = 0.35, hitStop = 0.4333, speed = 1.2, recovery = 0.07, push = 3 },
			{ damage = 15, hit = 0.3167, hitStop = 0.4167, speed = 1.1, recovery = 0.10, push = 7 },
		},
		hitbox = Vector3.new(9, 5, 8),
		maxTargets = 2,
	},
}

local TESTBED = workspace:GetAttribute("Testbed") == true

return {
	-- The testbed place (test.project.json sets this attribute on Workspace): a baseplate
	-- arena with the real Hub and no map. No timed events, rolled weather or ambient
	-- beasts, onboarding is skipped and every player gets the full test kit
	-- (docs/systems/testbed.md).
	TESTBED = TESTBED,
	-- The new telegraph language (docs/systems/telegraphs.md): one danger orange,
	-- glowing edges, timing fills, rails and reticles for projectiles, no howl
	-- rings. Testbed only until the user approves; `true` ships it.
	NEW_TELEGRAPHS = TESTBED,

	Data = {
		STORE_NAME = "PlayerData_v1",
		AUTOSAVE_SECONDS = 120,
		LOCK_STALE_SECONDS = 360, -- a lock not refreshed this long belongs to a dead server
		LOCK_WAIT_SECONDS = 15, -- wait this long for another server to release, then take over
		LOCK_RETRY_SECONDS = 3,
		STARTING_SEEDS = { SpiritGrass = 6 },
	},

	-- Save slots (docs/systems/save-slots.md): each slot is a separate character
	-- with its own progression, all in one session-locked account record. Testbed
	-- only until the user ships the join flow: off, PlayerData reads and writes the
	-- old single-profile key exactly as before, so live data is untouched.
	Slots = {
		ENABLED = TESTBED,
		MAX = 3, -- slots per account
		TRASH_DAYS = 7, -- a deleted slot is kept this long (one at a time) for support to restore
		DELETE_TOKEN_SECONDS = 30, -- the hold-to-delete must land this soon after it was asked for
		-- Skip the slot screen and creator and play slot 1 at once (combat testers).
		-- Workspace attribute in test.project.json, off by default.
		QUICK_PLAY = workspace:GetAttribute("QuickPlay") == true,
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
		-- Breakthrough numbers: Pacing.Breakthrough; the qi surge: Pacing.Surge.
	},

	-- Qi spent per run, efficiency, deviation, and each stage's run length and
	-- difficulty are progression pacing: Pacing.Refine and Pacing.Curve.
	Circulation = {
		-- A circulation run is Pacing `levels` levels (one on the first run) against a
		-- clock of LEVEL_SECONDS a level. It pays for the levels cleared when the
		-- clock runs out or the player leaves, and ends the moment the last one clears.
		LEVEL_SECONDS = 15, -- the run's time limit, per level
		IMPURITIES_PER_LEVEL = 2, -- impure beats/motes/spots per level, in every game
		ACCURACY_WEIGHT = 0.75, -- score = accuracy * this + purged share * the rest
		MIN_LEVEL_SECONDS = 3, -- a report faster than this per cleared level is rejected
		RUN_TIMEOUT_GRACE = 15, -- seconds past the time limit before an unreported run is dropped
		-- Practice Dao drills (Forms) are timed, not levelled:
		MIN_DURATION_FRACTION = 0.9, -- a drill reported sooner than this is rejected
		IMPURITIES_PER_10S = 1.5, -- impure points per 10 s of drill
		PEAK_RADIUS = 60, -- studs from your plateau centre that count as on your peak
		FIRST_RUN_GAME = "Maze", -- the very first run is always this game...
		FIRST_RUN_LEVELS = 1, -- ...one level...
		FIRST_RUN_DIFFICULTY = -0.5, -- ...and easier than `easy` (below 0 blends past it)
		-- ...and it always fills the realm bar, whatever the score (no deviation either), so
		-- the first breakthrough is guaranteed (docs/systems/onboarding.md, the hook)
		FIRST_RUN_FILLS_BAR = true,

		-- Minigames. Each run gets a difficulty from 0 (easy) to 1 (hard), set per
		-- stage in Pacing.Curve (`difficulty`); each game blends every value in
		-- `easy` toward `hard` by it. `weight` is how often the game is picked (0 = never).
		Games = {
			-- Maze Formation: drag your qi through the corridors; one maze a level.
			Maze = {
				weight = 1,
				easy = {
					size = 5, -- cells per side (at least 4)
					par = 8, -- seconds per maze for full accuracy (slower costs a little)
				},
				hard = { size = 9, par = 14 },
			},
			-- Thread the Meridian: drag a bead along a winding channel without touching
			-- its walls; one channel a level, each touch costs accuracy.
			Thread = {
				weight = 1,
				easy = {
					width = 0.09, -- channel half-width on level 1, share of the field height
					bends = 3, -- turns on level 1 (each later level adds one)
				},
				hard = { width = 0.055, bends = 5 },
			},
			-- Meridian Pulse: tap anywhere as each ring closes on its acupoint.
			Pulse = {
				weight = 1,
				easy = {
					window = 0.3, -- seconds either side of the beat that still count ("Good")
					interval = 1.1, -- seconds between beats
					approach = 1.4, -- seconds a ring takes to close
					beats = 10, -- beats a level
				},
				hard = { window = 0.14, interval = 0.7, approach = 0.9, beats = 14 },
			},
			-- Gather Qi: drag the dantian bowl to catch falling qi and dodge impure motes.
			Gather = {
				weight = 1,
				easy = {
					bowl = 0.3, -- bowl width, share of the field
					fall = 0.45, -- mote fall speed, field heights per second
					interval = 0.6, -- seconds between qi motes
					motes = 14, -- qi motes a level
				},
				hard = { bowl = 0.17, fall = 0.8, interval = 0.38, motes = 22 },
			},
			-- Weapon Forms: tap numbered points anywhere on the field as their rings
			-- close. The Practice Dao drill only (weight 0: never a circulation run).
			Forms = {
				weight = 0,
				easy = {
					window = 0.28, -- seconds either side of the beat that still count ("Good")
					interval = 0.8, -- seconds between points in a string
					approach = 1.3, -- seconds a ring takes to close
					jump = 0.3, -- usual distance to the next point, share of the field's longer side
				},
				hard = { window = 0.14, interval = 0.5, approach = 0.85, jump = 0.5 },
			},
		} :: { [string]: { weight: number, easy: { [string]: number }, hard: { [string]: number } } },
	},

	-- Meditation (M / the Cultivate tile, then Meditate): sit still and passive cultivation is
	-- multiplied by where you sit. Seats and artifacts on your own peak add their
	-- bonus when you meditate within ITEM_RANGE of them (the best one counts).
	Meditation = {
		-- passive multipliers, from Pacing.Meditation (read them there)
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
		-- Basic attack chains per weapon class (CLASSES above; Weapons.luau names
		-- the classes). The client predicts hits from Hit to Hit Stop; the
		-- server checks them against the same timeline (see Combat.luau).
		-- Never resolve a hit just because an animation stopped.
		CLASSES = CLASSES,
		FIST_STEPS = FIST_STEPS, -- = CLASSES.Fist.steps; old fist techniques time their casts from these
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
		AIM_RANGE = 14, -- soft auto-aim and auto-attack pick targets this close
		AUTO_RANGE = 6, -- auto-attack swings while the target is this close
		AUTO_ATTACK = true,
		-- server checks
		MAX_LAG = 1.0, -- seconds a swing's timestamp may trail the server clock
		CLOCK_SLACK = 0.1, -- and lead it
		HITBOX_SLACK = 4, -- studs added to each side of the hitbox for movement and lag
		AREA_SLACK = 3, -- studs added to technique areas on the server
		-- lag compensation (EnemyHistory): a swing that misses the beast where it is
		-- now still lands if it was in the box this far back at the swing's time.
		-- Also the most a forged timestamp can buy, so keep it short.
		REWIND = 0.35, -- seconds
		-- enemy strikes spare a player whose own movement (server-seen velocity)
		-- carries them out of the area within half their ping, up to this
		ESCAPE_LEAD = 0.15, -- seconds
		-- lunging skills (Techniques `lunge`): a hit lands from the caster's root
		-- unless it's farther from the cast's start than the lunge plus these
		LUNGE_SLACK = 4, -- studs
		LUNGE_WALK_ALLOWANCE = 10, -- studs per second of cast (walking, lag)

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

		-- Guard: hold right click / L2 / the Block button (src/server/Guard.luau,
		-- src/shared/GuardRules.luau; see docs/combat/guard-parry.md). Only enemy attacks with a
		-- source position in front of the player can be guarded; hazards can't.
		GUARD = {
			MOVE = 0.5, -- walk speed share while guarding
			FRONT_DOT = -0.2, -- guards hits from within ~100° either side of facing (melee, projectiles)
			CHIP = 0.15, -- share of a blocked hit's damage that still gets through
			DRAIN = 2.5, -- guard drained per share of max health a blocked hit would deal
			HEAVY_DRAIN = 1.6, -- times that for slams, charges and leaps (Config CC.HEAVY_KINDS)
			MIN_DRAIN = 0.08, -- even a scratch costs this much guard
			REGEN = 0.35, -- guard back per second once REGEN_DELAY has passed since the last drain
			REGEN_DELAY = 1.2,
			GUARDING_REGEN = 0.5, -- regen share while the guard is held
			BREAK_STAGGER = 1.0, -- seconds staggered when the guard breaks
			BREAK_REFILL = 0.5, -- the guard comes back this full after a break
			PARRY_WINDOW = 0.22, -- a hit this soon after pressing guard is a perfect parry, even if it was let go
			PARRY_RECOVER = 0.5, -- raising again sooner than this after the last raise opens no window (no spamming)
			PARRY_REFUND = 0.15, -- guard back on a perfect parry
			PARRY_STAGGER = 0.9, -- seconds the parried beast is staggered
			PARRY_STAGGER_BOSS = 0.45,
			PARRY_LATE = 0.05, -- a raise this long after the hit's server time still parries (clock jitter)
			-- Where a blow comes from (Guard.absorb): melee from the beast, dashes and
			-- leaps from where the beast set off, projectiles from where they were fired.
			DASH_DOT = -0.45, -- a dash or leap is guarded from within ~117° of facing (it arrives on top of you)
			LOOK_FRESH = 0.5, -- the facing the client last reported while guarding counts this long
			RACE_GRACE = 0.12, -- an unguarded hit waits up to half the player's ping (capped here) for a raise in flight
			FACE_RANGE = 30, -- while guarding without a lock you turn to the most pressing beast this close (0 = off)
			FACE_TURN = 18, -- how fast that turn closes (per second, exponential)
			-- Chain parry: after a perfect parry, the same attacker's next blows of
			-- the same assault (barrage bites, cone strikes, a follow-up combo, a
			-- slam's wave) are parried while the guard stays up, if each lands within
			-- CHAIN_SLACK of when it was due. The attacker staggers on the last one,
			-- at CHAIN_MAX, or when the flurry stops coming. No re-press needed, so
			-- PARRY_RECOVER doesn't apply inside a chain.
			CHAIN_SLACK = 0.45, -- seconds past a blow's due time the chain still waits for it
			CHAIN_MAX = 6, -- the sixth parried blow of a chain always staggers
			CHAIN_REFUND = 0.05, -- guard back per chained parry (the first gives PARRY_REFUND)
			CHAIN_STAGGER_BONUS = 0.12, -- the closing stagger is this much longer per chained blow
			CHAIN_STAGGER_MAX = 0.5, -- at most this much longer
		},

		IN_COMBAT_SECONDS = 6, -- after being hurt, travel is blocked this long

		-- Player crowd control (src/server/PlayerStun.luau; see combat.md).
		CC = {
			FLINCH_SECONDS = 0.28, -- the hit reaction; never locks input
			FLINCH_GAP = 0.3, -- a new flinch waits this long after the last one
			FLINCH_MOVE = 0.75, -- walk speed share during a flinch
			STAGGER_SECONDS = 0.75, -- default stagger length
			STAGGER_MIN = 0.4,
			STAGGER_MAX = 1.0,
			STAGGER_MOVE = 0.2, -- walk speed share while staggered
			STAGGER_PUSH = 14, -- studs/s the stumble shoves a player away from the source
			-- Enemy hits pick a reaction (EnemyService.reaction): an attack's
			-- `react`, else "stagger" for a HEAVY_KINDS attack from a beast of at
			-- least STAGGER_WEIGHT, else the flinch every hit gives.
			HEAVY_KINDS = { slam = true, charge = true, leap = true },
			STAGGER_WEIGHT = 2.5, -- the Stone Boar and up; wolves and serpents only flinch
			-- Knockback on the player from an enemy hit (EnemyService.knockback): the
			-- beast's `knock` studs, else KNOCK_BASE + KNOCK_PER_WEIGHT * weight,
			-- times KNOCK_BY_REACT for the reaction it caused, capped at KNOCK_MAX.
			-- An attack's own `knock` replaces all of that (0 = none).
			KNOCK_BASE = 1.5,
			KNOCK_PER_WEIGHT = 0.5, -- wolf ~2 studs, boar ~2.8, wolf king 5, ape 6
			KNOCK_BY_REACT = { flinch = 1, stagger = 1.5, stun = 1.5 },
			KNOCK_MAX = 9,
			KNOCK_SECONDS = 0.22, -- the shove plays out over this long, easing off
			STUN_SECONDS = 1.2, -- default stun length
			STUN_MAX = 3, -- no single stun lasts longer
			STUN_MIN = 0.4, -- diminished stuns shorter than this are ignored
			-- After any stagger or stun ends the player can't be staggered or
			-- stunned again for this long, and a stun landing within DR_WINDOW of
			-- the previous one lasts DR_FACTOR as long per link in the chain.
			IMMUNITY = 1.0,
			DR_WINDOW = 6,
			DR_FACTOR = 0.5,
		},

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
		-- arrays and where they lead: Shared.Gates
		SECT_GATE = Vector3.new(0, 9, 500), -- just outside the gate (the onboarding Gate beat checks it)
		COOLDOWN = 3,
	},

	Wilds = {
		-- qi node yield and cooldown: Pacing.Income
		RESPAWN_SPREAD = 0.3, -- respawn timers vary by up to this share
		AI_TICK = 0.1, -- seconds between enemy decisions
		-- idle beasts with no player this close stop thinking and anchor (no physics,
		-- nothing to replicate); keep it well past every def's aggro
		WAKE_RADIUS = 220,
		-- server movement (EnemyMover; enemies have no Humanoid)
		MOVE_TICK = 1 / 15, -- seconds between movement steps (and root replication)
		WALK_SLOPE = 0.6, -- surfaces with a normal's Y below this are walls
		CLIMB = 2.5, -- studs a beast steps up in one step, beyond its move
		FALL_SPEED = 60, -- studs per second it drops off a ledge
		TURN_RATE = 10, -- how fast it turns to face where it walks (per second)
		CROWD = 6, -- studs per second neighbours push apart when they overlap
		-- THE SPIRIT WOLF FIGHT (docs/enemies/spirit-wolf.md): the rigged body, its
		-- attack pool (bite, pounce, leap, howl, hop, circling), attack slots for
		-- every non-boss beast and dash hits that land as the dash arrives. Shipped
		-- 2026-10-21 after the user fought it in the testbed; false brings back the
		-- old one-lunge wolf until OLD_SPIRIT_WOLF and the SpiritWolf template go.
		NEW_WOLF = true,
		-- THE NEW STONE BOAR FIGHT (docs/enemies/stone-boar.md): its rigged body, the
		-- charge into a tusk gore, side-pacing. Shipped 2026-10-21 at the user's word
		-- (before a testbed fight); false brings back the old one-charge boar until
		-- OLD_STONE_BOAR and the StoneBoar template go.
		NEW_BOAR = true,
		-- THE ELDER WOLF KING TRIAL: rigged boss, heavy attacks and two quick paw
		-- checks. Testbed only until the user approves the fight; set true to ship.
		NEW_WOLF_KING = TESTBED,
		-- THE THUNDER APE TRIAL: a 30-stud storm boss (FE1) with fast combos, jump
		-- slams, lightning and a stagger roar. Testbed only until the user approves.
		NEW_THUNDER_APE = TESTBED,
		-- THE NINE-TAILED FOX TRIAL: an FE1 duelist boss with telescoping tails (lances,
		-- sweeps, a snare), foxfire volleys, tail-plunge eruptions, a scream stun and
		-- retreat flips. Testbed only until the user approves.
		NEW_NINE_TAIL_FOX = TESTBED,
		-- THE JADE JIAO TRIAL: a 115-stud venom serpent boss (QC7) with burrow ambushes,
		-- poison, a coil trap and phase moves. Testbed only until the user approves.
		NEW_JIAO = TESTBED,
		-- THE SECOND BESTIARY WAVE (docs/enemies/second-wave.md: "Venom Serpent", "Stone Tortoise", "Shadow Mane
		-- Wolf"): three regular beasts with their own bodies, poses and effects. Testbed only
		-- until the user approves; false keeps the old Venom Serpent (one spit). The Tortoise
		-- and the Shadow Mane have no old def, so they exist only with their flag.
		NEW_SERPENT = TESTBED,
		NEW_TORTOISE = TESTBED,
		NEW_SHADOW_MANE = TESTBED,
		-- THE THIRD WAVE (docs/enemies/third-wave.md): the Blood Centipede, Flame
		-- Raven and Iron-Winged Blood Bat (the Golden Toad and Frost Spider were cut). Testbed only until
		-- approved; each has no old def, so it exists only while its flag is on.
		NEW_CENTIPEDE = TESTBED,
		NEW_RAVEN = TESTBED,
		NEW_BAT = TESTBED,
		-- THE BOSS FEEL PASS (telegraphs.md, "Attacks that make sense"): beasts turn into
		-- leaps, bounds, charges and lunges over the windup and finish their yaw in the air,
		-- start an attack's `arrive` follow-up on arrival, and skid round (`<name>Skid`) to
		-- face a target they overshot. Testbed only until the user approves; the bosses'
		-- new moves also sit behind their own NEW_* flags.
		WEIGHTED_MOVES = TESTBED,
		-- REALM VARIANTS (docs/systems/enemies.md "Realm variants"): zones and ambient packs
		-- spawn their beasts at the realm ranges in Shared.Spawns, scaled and tiered by
		-- Pacing.Variants (young near the gate, elite and apex farther out). Off: every beast
		-- spawns at its def's own realm, as before (the admin panel's tier chips still work).
		-- Testbed only until the user approves; set true to ship.
		VARIANTS = TESTBED,
		-- attack slots (EnemyService): at most this many beasts (non-bosses, plus
		-- bosses with shareTurns) wind up or strike at one player at once; the next waits
		-- SLOT_GAP after the last one resolved, so a pack takes turns. Short tells
		-- still reward moving clear as well as spending the dodge.
		ATTACK_SLOTS = 1,
		SLOT_GAP = 0.6,
		ENGAGE_RESET = 6, -- seconds without a target before a beast's next fight counts as new (howl, opener)
	},

	-- Technique manuals: Pacing.Rewards; their Dao gates: Pacing.Comprehension.

	-- The heavenly tribulation's arena. How hard it is (length, strike rate and
	-- damage, fail cooldown) is per stage: Pacing.Curve `tribulation`.
	Tribulation = {
		CENTER = if TESTBED then Vector3.new(0, 650, 240) else Vector3.new(2, 857, -86), -- the main peak's tribulation platform (the testbed's own slab)
		ARENA_RADIUS = 34, -- stepping farther out than this fails the tribulation
		STRIKE_RADIUS = 5,
		RETURN_DELAY = 4, -- seconds after it ends before the challenger is sent down to the plaza
	},

	-- Day and night (client-side, in step across clients through the server clock)
	Ambience = {
		DAY_MINUTES = 20, -- real minutes for a full day
		START_HOUR = 9, -- the hour at server-time zero
		NIGHT_LIGHT_SCALE = 2.5, -- lamp light brightness at night...
		DAY_LIGHT_SCALE = 0.4, -- ...and by day, relative to the place's setting
		NIGHT_RANGE_SCALE = 1.4, -- lamp light range at night (by day: as set; capped at 60)
		-- lights inside models with these names follow day and night (as do all
		-- lights under Map's Ambience folder): map lamps and buildable lamps
		LAMP_MODELS = { "StoneLantern", "JadeLamp", "Brazier", "Lantern", "StoneLamp", "TallStoneLamp", "LampPost" },
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

	-- Studio playtests and the testbed: topped up on join so systems can be tried right
	-- away. The testbed also owns every technique and weapon.
	TestKit = {
		ENABLED = true,
		HERBS_EACH = 5, -- every herb type
		SEEDS_EACH = 5, -- every seed type
		ITEMS_EACH = 2, -- every spirit core and treasure
		-- not root pills: the RootPill lesson would purify the root before the tutorial's own
		-- root reveal is digested (give them from the admin panel)
		SKIP_ITEMS = { MarrowWashingPill = true, RootRebirthPill = true } :: { [string]: boolean },
		STONES = 3000, -- Spirit Stones, to try the Spirit Market
		ALL_TECHNIQUES = false, -- own every technique, to test them without earning manuals
		ALL_WEAPONS = false, -- own every weapon, to test each class
		FILL_DANTIAN = true, -- no combat yet, so this is the only steady raw qi source
	},
}
