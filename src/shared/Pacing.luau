--!strict
-- PACING: the master progression and difficulty tuning. Every number that
-- decides how fast a player climbs the realm ladder, and how hard each stage
-- feels, lives here and nowhere else. Realms.luau resolves it into
-- Realms.Stages, which every system reads (Cultivation, Circulation,
-- Tribulation, QiNodes, Combat power, Inventory, Quests, the HUD, enemies).
--
-- STRUCTURE: one row per stage, three dials, two layers.
--   Each stage ("QC1".."QC9", "FE1") has three groups of numbers:
--     QI            how much qi the stage needs and how fast it comes
--                   (bar, dantian, passive, refine, gather)
--     BREAKTHROUGH  what it takes to leave the stage
--                   (insight, minigame runSeconds and difficulty, tribulation)
--     FIGHT         how hard fights feel at this stage
--                   (the player's health and power; beastHealth and beastDamage
--                   for demon beasts whose Enemies `realm` is this stage)
--   Layer 1, Pacing.Curve: the designed curve, the intended rhythm. Change it
--     to redesign; keep the time estimates below in step.
--   Layer 2, Pacing.Adjust: per-stage multipliers/overrides on top of the curve,
--     keyed by stage. This is the analytics dial: one stage, every system.
--   Then Pacing.Global scales the whole game (all stages) on top of both.
--
-- HOW TO USE IT
--   * Analytics shows players quitting at one stage (Creator Dashboard >
--     Analytics > Progression, path "Realm"; see docs/systems/cultivation.md)?
--     Don't touch the curve: add an entry for that stage to Pacing.Adjust.
--     Stuck on qi: bar / refine / gather / passive. Stuck at a breakthrough:
--     insight / difficulty / tribulation. Dying a lot: health / power /
--     beastHealth / beastDamage.
--   * Want the whole game faster, slower, easier or harder? Change Pacing.Global.
--   * Redesigning the rhythm? Edit Pacing.Curve.

-- WEAPON DAO (Pacing.Weapons, at the end): per-class comprehension levels and XP.

-- THE RHYTHM (Qi Condensation 1-9, then Foundation Establishment)
--   QC1-3  HOOK      fast, one or two runs each; the onboarding ends at QC3
--   QC4    BREATHER  a cheap stage right after the tutorial, to reward staying
--   QC5    RAMP      the bar passes one dantian; the loop of gather/refine sets in
--   QC6    MINI-WALL the first stage that needs more than one dantian of qi
--   QC7    BREATHER  cheaper than QC6 for its dantian: relief after the wall
--   QC8    RAMP      a long climb that sets up the wall
--   QC9    WALL      the biggest bar, 5 insight (first kills, the Elder Wolf King,
--                    milestones) and a heavenly tribulation to leave it
--   FE1    the top of the current ladder (no breakthrough out yet)
--
-- TIME-TO-BREAKTHROUGH ESTIMATES (derived from the numbers below, Global = 1,
-- no herbs, weather or garden aura; "active" assumes ~0.8 minigame score, i.e.
-- 1.1 cultivation per raw qi):
--   stage  bar   idle   meditate  on peak  active: runs, raw qi to gather (wolf kills or node gathers)
--   QC1     40   3 min   2 min    1 min    1 run,    36 qi  (~3 wolves  / 2 nodes; the starting qi covers it)
--   QC2    110   7 min   5 min    3 min    2 runs,  100 qi  (~5 wolves  / 3 nodes)
--   QC3    200  10 min   7 min    4 min    2 runs,  180 qi  (~7 wolves  / 4 nodes)
--   QC4    300  13 min   8 min    5 min    2 runs,  270 qi  (~8 wolves  / 4 nodes)
--   QC5    560  19 min  12 min    8 min    3 runs,  510 qi  (~11 wolves / 5 nodes)
--   QC6   1000  27 min  18 min   11 min    3 runs,  910 qi  (~15 wolves / 6 nodes)
--   QC7   1300  28 min  19 min   11 min    3 runs, 1180 qi  (~15 wolves / 6 nodes)
--   QC8   2300  40 min  27 min   16 min    4 runs, 2090 qi  (~20 wolves / 7 nodes)
--   QC9   3700  54 min  36 min   21 min    5 runs, 3360 qi  (~25 wolves / 8 nodes) + insight + tribulation
-- Active play stacks with the idle rate (passive cultivation never stops), so an
-- engaged player clears a stage in roughly the "active" column plus travel.
-- Formulas: idle = bar / passive; meditate = idle / Meditation.ANYWHERE; on peak =
-- idle / Meditation.ON_PEAK; runs = bar / (dantian / RUNS_PER_DANTIAN * 1.1);
-- wolf qi = 14 * (dantian / 120) ^ Income.ENEMY_QI_EXPONENT; node = dantian * NODE_SHARE.

export type Tribulation = {
	seconds: number, -- survive this long
	windupStart: number, -- seconds a strike's telegraph shows, at the start...
	windupEnd: number, -- ...and by the end
	intervalStart: number, -- seconds between strikes, at the start...
	intervalEnd: number, -- ...and by the end
	scatter: number, -- strikes land up to this many studs from the player
	damageShare: number, -- of max health per strike
	failCooldown: number, -- seconds before trying again
}

-- One stage of the designed curve.
export type Row = {
	key: string, -- the id Pacing.Adjust uses: "QC1".."QC9", "FE1"
	major: string, -- Realms major id
	minor: number,
	beat: string, -- the intended feel, for readers (HOOK, BREATHER, RAMP, MINI-WALL, WALL)
	bar: number, -- cultivation to fill this stage's realm bar
	dantian: number, -- raw qi the dantian holds (also scales node and kill qi)
	passive: number, -- cultivation per second, always on (online and offline), before buffs
	health: number, -- the player's max health
	power: number, -- the player's damage multiplier (also sets knockback, Knockback.luau)
	insight: number, -- insight needed to break out of this stage (0 = none)
	runSeconds: number, -- circulation minigame length
	difficulty: number, -- circulation minigame difficulty, 0 (easy) to 1 (hard); below 0 is easier than easy
	tribulation: Tribulation?, -- set on a stage whose breakthrough is major (into a new realm)
}

-- A per-stage correction on top of the curve. Every field is optional.
export type Adjust = {
	bar: number?, -- multiplies the qi needed (0.8 = 20% less to fill)
	passive: number?, -- multiplies the idle/meditation rate
	refine: number?, -- multiplies circulation efficiency (cultivation per raw qi)
	gather: number?, -- multiplies raw qi income: qi nodes, daily login qi (and enemy kills, see Income)
	difficulty: number?, -- added to the minigame difficulty (-0.2 = easier)
	runSeconds: number?, -- replaces the minigame length
	insight: number?, -- replaces the insight requirement
	tribulation: { [string]: number }?, -- replaces fields of this stage's tribulation
	health: number?, -- multiplies the player's max health at this stage
	power: number?, -- multiplies the player's damage (and knockback) at this stage
	beastHealth: number?, -- multiplies the health of beasts whose realm is this stage
	beastDamage: number?, -- multiplies the damage of beasts whose realm is this stage
}

local Pacing = {}

-- The standard tribulation (QC9 -> Foundation). Survivable with two or three
-- hits to spare at QC9 health if the player watches the telegraphs.
local HEAVENLY_TRIBULATION: Tribulation = {
	seconds = 30,
	windupStart = 1.2,
	windupEnd = 0.7,
	intervalStart = 1.3,
	intervalEnd = 0.5,
	scatter = 9,
	damageShare = 0.22,
	failCooldown = 120, -- failing costs time, never cultivation
}

-- THE CURVE. Bars grow about 1.6x a stage after the hook; dantians about 1.4x,
-- so each stage needs a bit more gathering per bar than the last. Breathers and
-- walls bend that ramp on purpose (see THE RHYTHM above).
-- Minigame length grows 2 s a stage (capped at 40) and difficulty reaches hard at
-- the last Qi Condensation stage's breakthrough (FE1).
Pacing.Curve = {
	-- HOOK: one run fills the bar; the very first run is always a short, easy Maze
	-- (Config.Circulation.FIRST_RUN_*). Breakthrough within the first few minutes.
	{ key = "QC1", major = "QiCondensation", minor = 1, beat = "HOOK", bar = 40, dantian = 120, passive = 0.20, health = 100, power = 1.00, insight = 0, runSeconds = 20, difficulty = 0.000 },
	-- HOOK: the elder sends the player to the wilds; kills refill the dantian.
	{ key = "QC2", major = "QiCondensation", minor = 2, beat = "HOOK", bar = 110, dantian = 180, passive = 0.25, health = 120, power = 1.10, insight = 0, runSeconds = 22, difficulty = 0.111 },
	-- HOOK: the onboarding's last goal is reaching QC3.
	{ key = "QC3", major = "QiCondensation", minor = 3, beat = "HOOK", bar = 200, dantian = 260, passive = 0.32, health = 140, power = 1.20, insight = 0, runSeconds = 24, difficulty = 0.222 },
	-- BREATHER: the first free-play stage. Kept under the 1.6x ramp (was 340) so
	-- the first goal off the rails comes quickly.
	{ key = "QC4", major = "QiCondensation", minor = 4, beat = "BREATHER", bar = 300, dantian = 380, passive = 0.40, health = 165, power = 1.32, insight = 0, runSeconds = 26, difficulty = 0.333 },
	-- RAMP: the bar outgrows one dantian; gather -> refine becomes the loop.
	{ key = "QC5", major = "QiCondensation", minor = 5, beat = "RAMP", bar = 560, dantian = 540, passive = 0.50, health = 190, power = 1.45, insight = 0, runSeconds = 28, difficulty = 0.444 },
	-- MINI-WALL: 1.3 dantians of qi (was 900). Herbs, cores and the garden start to matter.
	{ key = "QC6", major = "QiCondensation", minor = 6, beat = "MINI-WALL", bar = 1000, dantian = 760, passive = 0.62, health = 220, power = 1.60, insight = 0, runSeconds = 30, difficulty = 0.556 },
	-- BREATHER: relief after the mini-wall (was 1450); about as long as QC6.
	{ key = "QC7", major = "QiCondensation", minor = 7, beat = "BREATHER", bar = 1300, dantian = 1050, passive = 0.78, health = 255, power = 1.76, insight = 0, runSeconds = 32, difficulty = 0.667 },
	-- RAMP: the long climb before the wall.
	{ key = "QC8", major = "QiCondensation", minor = 8, beat = "RAMP", bar = 2300, dantian = 1450, passive = 0.95, health = 290, power = 1.94, insight = 0, runSeconds = 34, difficulty = 0.778 },
	-- WALL: the biggest bar, 5 insight, then the heavenly tribulation. This is
	-- where the first realm ends; the payoff is Foundation's 1.4x power jump.
	{ key = "QC9", major = "QiCondensation", minor = 9, beat = "WALL", bar = 3700, dantian = 2000, passive = 1.15, health = 330, power = 2.13, insight = 5, runSeconds = 36, difficulty = 0.889, tribulation = HEAVENLY_TRIBULATION },
	-- The top of the ladder for now. Its bar is only shown, never broken through.
	{ key = "FE1", major = "Foundation", minor = 1, beat = "PEAK", bar = 12000, dantian = 4000, passive = 2.00, health = 500, power = 3.00, insight = 0, runSeconds = 38, difficulty = 1.000 },
} :: { Row }

-- PER-STAGE CORRECTIONS, by stage key. Empty by default: the curve is the design.
-- To ease a dropoff at a stage, add an entry, e.g.
--   QC6 = { bar = 0.8 },                 -- 20% less qi to fill the bar
--   QC6 = { refine = 1.25 },             -- each circulation run gives 25% more
--   QC6 = { gather = 1.5 },              -- nodes and kills pour 50% more raw qi
--   QC6 = { difficulty = -0.2 },         -- easier minigames at this stage
--   QC6 = { passive = 1.5 },             -- idlers and meditators progress faster
--   QC9 = { insight = 3 },               -- fewer insight needed for the wall
--   QC9 = { tribulation = { damageShare = 0.15, seconds = 25 } }  -- a softer tribulation
--   QC6 = { health = 1.2 },              -- players at QC6 survive more hits
--   QC9 = { beastDamage = 0.8 },         -- QC9 beasts (the Elder Wolf King) hit 20% softer
--   QC4 = { beastHealth = 0.8 },         -- QC4 beasts (Stone Boars) die 20% faster
-- Player-side fields (health, power) apply to players AT that stage; beast-side
-- fields apply to beasts whose Enemies `realm` IS that stage, whoever fights them.
-- To make a stage harder, use the same fields the other way (bar = 1.2, ...).
Pacing.Adjust = {} :: { [string]: Adjust }

-- WHOLE-GAME KNOBS, applied on top of every stage (and on top of Adjust).
Pacing.Global = {
	BAR = 1, -- multiplies every stage's bar
	PASSIVE = 1, -- multiplies every stage's passive rate
	REFINE = 1, -- multiplies circulation efficiency everywhere
	GATHER = 1, -- multiplies raw qi income everywhere
	DIFFICULTY = 0, -- added to every stage's minigame difficulty
	BEAST_HEALTH = 1, -- multiplies every beast's health
	BEAST_DAMAGE = 1, -- multiplies every beast's damage
	TRIBULATION_DAMAGE = 1, -- multiplies every tribulation's strike damage
}

-- REFINING (circulation runs turn raw qi into cultivation). The minigames
-- themselves (games, impurities, first run, anti-cheat timing) are in Config.Circulation.
Pacing.Refine = {
	RUNS_PER_DANTIAN = 2.5, -- a full run spends dantian / this raw qi
	MIN_RUN_FRACTION = 0.25, -- need at least this share of a full run's qi to start
	EFFICIENCY_MIN = 0.5, -- cultivation per raw qi at score 0
	EFFICIENCY_MAX = 1.3, -- and at score 1 (before the stage's refine multiplier)
	DEVIATION_SCORE = 0.35, -- below this the run causes a qi deviation
	DEVIATION_SECONDS = 20, -- no circulating and no passive cultivation meanwhile
}

-- RAW QI INCOME (what refining spends). Herb and item qi are fixed per item
-- (Herbs.luau `eat`, Items.luau `use`); enemy qiDrop is per enemy (Enemies.luau).
Pacing.Income = {
	STARTING_RAW_QI = 60, -- a new player's dantian: enough for the first circulation run
	NODE_SHARE = 0.2, -- a qi node gather gives this share of the dantian (times gather)
	NODE_COOLDOWN = 45, -- seconds before the same player can gather a node again
	-- enemy qi = qiDrop * (dantian / QC1 dantian) ^ this, times the stage's gather
	ENEMY_QI_EXPONENT = 0.8,
	DAILY_QI_SHARE = 0.5, -- first login of a day: this share of the dantian (times gather)
	OFFLINE_MAX_HOURS = 12, -- offline cultivation counts at most this long
	OFFLINE_RATE = 1, -- share of the passive rate while away
}

-- MEDITATION multiplies the passive rate while seated (build items on the peak
-- add their BuildItems `meditation` bonus on top of ON_PEAK).
Pacing.Meditation = {
	ANYWHERE = 1.5,
	ON_PEAK = 2.5, -- on your own spirit peak
}

-- BREAKTHROUGHS. Minor ones happen seated on a full bar. In combat, at low
-- health, a minor one can be forced early; the new stage then starts in qi debt.
Pacing.Breakthrough = {
	FORCE_BAR_SHARE = 0.9, -- the bar must be at least this full to force it
	FORCE_HEALTH_SHARE = 0.35, -- and health at most this share of max, in combat
	FORCE_DEBT_SHARE = 0.5, -- debt: the bar's shortfall plus this share of the new bar
}

-- INSIGHT AND MANUALS (Progression.luau). Insight gates the QC9 wall: with 3
-- normal beasts and the boss, first kills give 4, the boss kill 1 more, so a
-- player who has seen the whole wilds ring once has the 5 it needs.
Pacing.Rewards = {
	-- a player is credited with a kill (qi, stones, insight, drops) only if they
	-- dealt at least this share of the beast's max health; a boss asks more, so
	-- one tag in a crowd doesn't earn the boss rewards
	KILL_SHARE = 0.1,
	BOSS_KILL_SHARE = 0.15,
	FIRST_KILL_INSIGHT = 1, -- the first kill of each enemy type
	BOSS_INSIGHT = 1, -- every boss kill
	BOSS_FIRST_MANUAL = "LightningTalisman",
	-- boss pools of class manuals and Spirit weapons: Enemies `bossDrops`;
	-- the rest of the class manuals and the Mortal weapons are in world caches
	-- and the sect weapon rack (docs/systems/weapons.md)
	-- kill milestones (total kills): insight and/or a manual, once each
	MILESTONES = {
		{ kills = 3, manual = "PalmStrike" },
		{ kills = 12, manual = "TwinPhoenixCannon" },
		{ kills = 30, insight = 1, manual = "IronSkin" },
		{ kills = 60, manual = "MoonflashDraw" },
		{ kills = 100, insight = 1, manual = "FireSeal" },
	} :: { { kills: number, insight: number?, manual: string? } },
}

-- TECHNIQUE COMPREHENSION (Techniques.bottleneck, Progression.comprehend). Casting
-- levels a technique, but at the top of each visual tier (Techniques.VISUAL_TIERS:
-- levels 3, 6, 9) its XP stops at a bottleneck. Breaking it takes insight and
-- Spirit Stones, spent seated in meditation, and opens the next tier. Spending
-- insight never blocks a breakthrough: those check insight ever earned.
Pacing.Comprehension = {
	GATES = { -- by the level the bottleneck sits at
		[3] = { insight = 1, stones = 60 }, -- into tier II
		[6] = { insight = 2, stones = 250 }, -- into tier III
		[9] = { insight = 3, stones = 600 }, -- into mastery
	} :: { [number]: { insight: number, stones: number } },
}

-- CULTIVATION METHODS (Methods.luau, server Methods; docs/systems/character.md).
-- Everyone cultivates with the basic Sect Breathing until Foundation, when they
-- are given a random starter. `qi` multiplies passive, refining and gathering;
-- `reaches` is the last stage a method can take you to (a key not on the ladder
-- yet means no limit today). Matching your root's element adds MATCH.
Pacing.Methods = {
	BASIC_QI = 1.0,
	BASIC_REACHES = "FE1", -- Sect Breathing stops at Foundation's first stage
	STARTER_QI = 1.1,
	STARTER_REACHES = "FE9", -- the whole of Foundation
	MATCH = 0.1,
	GIVEN_AT = "Foundation", -- the major (Pacing.Curve `major`) where the starter is given
}

-- WEAPON DAO COMPREHENSION (Weapons.luau, server Weapons). Each weapon class
-- (Fist, Sword, Saber, ...) has its own level 0..MAX_LEVEL that multiplies M1
-- and that class's technique damage (on top of the weapon's grade and the
-- realm's power). NEUTRAL_LEVEL is today's strength (x1.0): a new player's
-- Fist and Sword start there, so starting power is unchanged; an untrained
-- class is ~20% weaker and mastery ~30% stronger.
Pacing.Weapons = {
	MAX_LEVEL = 10,
	NEUTRAL_LEVEL = 2,
	STARTING = { Fist = 2, Sword = 2 } :: { [string]: number }, -- new profiles (and the v5 migration)
	-- damage multiplier by level, index 1 = level 0
	MULTIPLIER = { 0.8, 0.9, 1.0, 1.04, 1.08, 1.12, 1.16, 1.2, 1.24, 1.27, 1.3 },
	-- XP to go from `level` to the next: XP_BASE + level * XP_PER_LEVEL
	XP_BASE = 30,
	XP_PER_LEVEL = 30,
	XP_HIT = 1, -- an M1 swing that lands (once per swing, not per target)
	XP_CAST = 3, -- casting one of the class's techniques
	XP_MANUAL = 25, -- learning one of the class's manuals
}

-- PRACTICE DAO (server DaoPractice, the seated Practice row's Weapon Dao tile). A
-- short seated drill with the equipped weapon, played on a circulation
-- minigame, for that class's Dao XP. It helps you catch up but never beats
-- fighting: one drill per COOLDOWN, worth at most XP_SHARE of the current
-- level's XP (scaled by the score). Leaving a drill early costs nothing.
Pacing.DaoPractice = {
	FROM = "QC7", -- the stage it unlocks (the core loop's second-weapon slot)
	COOLDOWN = 300, -- seconds between finished drills (saved, so rejoining doesn't skip it)
	XP_SHARE = 0.25, -- of xpToNext(level), at a perfect score
	SECONDS = 20,
	GAME = "Forms", -- Minigames/<GAME>: osu-style strike points anywhere on the field
	DIFFICULTY = 0.35,
}

-- SPIRIT ROOTS (Roots.luau, server Roots; docs/systems/character.md). A root's
-- element is rolled once at the Testing Stone; its grade starts at STARTING_GRADE
-- for everyone and is raised by rare items. Grade multiplies passive and refining
-- speed and the element's perk. Perks are kept small so no element is "the best".
Pacing.Roots = {
	-- roll weights (percent)
	ODDS = { Fire = 18, Water = 18, Wood = 18, Metal = 18, Earth = 18, Lightning = 4, Wind = 3, Ice = 3 } :: { [string]: number },
	STARTING_GRADE = "Spirit",
	-- per grade: cultivation speed (passive and refining) and perk strength
	GRADES = {
		Spirit = { speed = 1.0, perk = 1.0 },
		Earth = { speed = 1.1, perk = 1.5 },
		Heaven = { speed = 1.25, perk = 2.0 },
	} :: { [string]: { speed: number, perk: number } },
	-- each element's perk at perk strength 1 (Roots.Elements says what kind it is)
	PERKS = {
		Fire = 0.08, -- share added to technique damage
		Water = 0.02, -- share of max health healed per second out of combat
		Wood = 0.25, -- share added to herb growth speed (while online)
		Metal = 0.08, -- share added to weapon strike (M1) damage
		Earth = 0.10, -- share added to max health
		Lightning = 2, -- studs/s added to walk speed
		Wind = 0.15, -- share added to jump height
		Ice = 0.06, -- share cut from damage taken
	} :: { [string]: number },
	MATCH = 0.15, -- share added to techniques of your root's element
}

return Pacing
