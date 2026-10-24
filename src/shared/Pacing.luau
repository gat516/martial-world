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
--                   (minigame levels and difficulty, tribulation)
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
--     difficulty / tribulation. Dying a lot: health / power /
--     beastHealth / beastDamage.
--   * Want the whole game faster, slower, easier or harder? Change Pacing.Global.
--   * Redesigning the rhythm? Edit Pacing.Curve.

-- WEAPON DAO (Pacing.Weapons, at the end): per-class comprehension levels and XP.

-- THE RHYTHM (docs/roadmap.md "Pacing, realm gaps and verbs", decided 2026-10-23)
--   Active-play targets: Qi Condensation about 2.5 h, Qi Refining about 7 h,
--   Foundation Establishment about 20 h (about 30 h to FE9, the cap). Passive and
--   offline cultivation stretch it over real days.
--   Every realm is three thirds (1-3, 4-6, 7-9), each easy to hard, opened by a
--   breather so a breakthrough feels good; stage 9 is the realm's wall.
--   QC1-3  HOOK      the first session lands two or three breakthroughs: QC1->2
--                    within about 1.5 min of first sitting, QC3 by about 4-5 min,
--                    QC4 by about 9-10 min (with the onboarding's talk and travel)
--   4-6    BREATHER, RAMP, MINI-WALL   (in QC: the loop of gather/refine sets in)
--   7-9    BREATHER, RAMP, WALL        (QC9, the first realm's wall, about an hour)
--   1-3 of QR and FE: HOOK (the new realm), RAMP, MINI-WALL
--   QR1-3  the new realm opens fast (its first bar is smaller than QC9's wall)
--   QR4-9  THE REAL SLOWDOWN: bars outgrow hunting, and passive grows as a share of
--          income so the garden aura, peak build items and herbs (all multiply or
--          add to it) are what keep cultivation moving (user, 2026-10-23; not alchemy)
--   FE1-9  the long realm; no stage over about 3 h; FE9 is the cap for now
--          (PEAK: its bar is shown, never broken through)
--   The walls are the bar (and the tribulation for heaven-defiers); nothing
--   else gates a breakthrough. A heaven-defier's bar is HeavenDefying.BAR x longer.
--
-- TIME-TO-BREAKTHROUGH ESTIMATES (Global = 1, no herbs, weather, garden aura,
-- build items or method; a normal player):
--   active   the fighter: passive (never stops) plus about 2 wolf kills'
--            worth of raw qi a minute (kills and nodes, net of travel and
--            refining), refined at 1.1 cultivation per raw qi (~0.8 score)
--   on peak  the gardener: meditating on their own peak, nothing else
--   stage     bar    active  on peak  meditate    idle  refine runs, wolf kills of qi
--   QC1        40    1 min    1 min    2 min    3 min    1 runs  ~3 wolves (the starting qi covers it)
--   QC2       100    2 min    3 min    4 min    7 min    1 runs  ~5 wolves
--   QC3       200    3 min    4 min    7 min   11 min    2 runs  ~7 wolves
--   QC4       680    7 min   14 min   24 min   35 min    4 runs  ~18 wolves
--   QC5      1550   12 min   24 min   40 min   60 min    7 runs  ~30 wolves
--   QC6      3050   18 min   36 min   61 min    1.5 h    9 runs  ~45 wolves
--   QC7      3300   15 min   30 min   50 min   75 min    7 runs  ~38 wolves
--   QC8      9350   33 min   66 min    1.8 h    2.7 h   15 runs  ~83 wolves
--   QC9     20000   55 min    1.8 h    3.0 h    4.6 h   23 runs  ~137 wolves   QC total: 2.4 h active, 4.8 h on peak
--   QR1     12000   22 min   41 min   69 min    1.7 h    9 runs  ~56 wolves
--   QR2     15500   25 min   47 min   78 min    2.0 h    9 runs  ~64 wolves
--   QR3     24500   35 min   65 min    1.8 h    2.7 h   13 runs  ~89 wolves
--   QR4     26000   32 min   56 min    1.5 h    2.3 h   11 runs  ~83 wolves
--   QR5     53500   58 min    1.6 h    2.7 h    4.0 h   20 runs  ~152 wolves
--   QR6     79500   75 min    2.0 h    3.4 h    5.1 h   26 runs  ~200 wolves
--   QR7     54500   45 min   71 min    2.0 h    2.9 h   15 runs  ~121 wolves
--   QR8     78500   57 min   90 min    2.5 h    3.7 h   19 runs  ~153 wolves
--   QR9    115000   74 min    1.9 h    3.2 h    4.8 h   23 runs  ~198 wolves   QR total: 7.1 h active, 11.8 h on peak
--   FE1    185000   80 min    2.0 h    3.3 h    5.0 h   23 runs  ~218 wolves
--   FE2    270000    1.7 h    2.6 h    4.3 h    6.5 h   30 runs  ~285 wolves
--   FE3    390000    2.3 h    3.4 h    5.6 h    8.5 h   37 runs  ~368 wolves
--   FE4    355000    1.8 h    2.8 h    4.6 h    6.9 h   29 runs  ~299 wolves
--   FE5    490000    2.3 h    3.4 h    5.7 h    8.5 h   35 runs  ~369 wolves
--   FE6    665000    2.7 h    4.1 h    6.9 h   10.3 h   42 runs  ~448 wolves
--   FE7    610000    2.3 h    3.4 h    5.6 h    8.5 h   33 runs  ~368 wolves
--   FE8    810000    2.7 h    4.0 h    6.7 h   10.0 h   38 runs  ~437 wolves
--   FE9    990000    2.9 h    4.4 h    7.3 h   11.0 h   41 runs  ~478 wolves   FE total: 20 h active, 30 h on peak
-- The gardener's road is about 2x the fighter's in QC, about 1.6x in QR and 1.5x in
-- FE (before garden aura, build items and herbs, which close it further).
-- "Wolves" counts qi, not fights: from QC5 on players hunt bigger beasts whose
-- qiDrop is several wolves'. Untuned in play; tune from analytics with Adjust.
-- Formulas (w = one spirit wolf's qi at the stage = 14 * (dantian / 120) ^
-- Income.ENEMY_QI_EXPONENT; p = passive):
--   active = bar / (60 p + 2 * 1.1 * w) minutes
--   idle = bar / p; meditate = idle / Meditation.ANYWHERE; on peak = idle / Meditation.ON_PEAK
--   runs = bar / (dantian / RUNS_PER_DANTIAN * 1.1); wolves = bar / 1.1 / w
-- To set a stage: pick its active minutes, then bar = minutes * (60 p + 2.2 w).
-- Passive is set as a share of w (about 0.009 in QC, rising from 0.010 at QR1 to
-- 0.0125 at QR7, 0.0133 in FE): it sets the gardener's ratio.
--
-- STRENGTH (health, power): about +10% a minor stage and x2.25 at each major
-- (QC9->QR1, QR9->FE1). Beasts follow the same curve (Pacing.BeastBaseline), so a
-- same-stage beast stays a fair fight, one minor stage up is fightable, and a major
-- up is not: x2.25 on both sides plus realm suppression (Pacing.Suppression).

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
	levels: number, -- most levels in a circulation run (1-3); leave after any one and keep what it refined
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
	levels: number?, -- replaces the most levels in a run
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

-- The Qi Refining -> Foundation tribulation: longer and faster than the first.
local QR_TRIBULATION: Tribulation = {
	seconds = 40,
	windupStart = 1.1,
	windupEnd = 0.65,
	intervalStart = 1.2,
	intervalEnd = 0.45,
	scatter = 11,
	damageShare = 0.20,
	failCooldown = 120,
}

-- THE CURVE. Each stage's bar comes from its target active minutes (formulas in
-- the header); dantians grow about 1.4x a stage in QC, about 1.17x after, with a
-- 1.6x step at each major. Health and power: +10% a minor stage, x2.25 at a major.
-- Runs are two levels at QC1-2 and three after; difficulty reaches hard at FE1.
Pacing.Curve = {
	-- HOOK: one run fills the bar; the very first run is always a short, easy Maze
	-- (Config.Circulation.FIRST_RUN_*). Breakthrough within about 1.5 min of sitting.
	{ key = "QC1", major = "QiCondensation", minor = 1, beat = "HOOK", bar = 40, dantian = 120, passive = 0.20, health = 100, power = 1.00, levels = 2, difficulty = 0.000 },
	-- HOOK: the elder sends the player to the wilds; a few kills and a refine fill it.
	{ key = "QC2", major = "QiCondensation", minor = 2, beat = "HOOK", bar = 100, dantian = 180, passive = 0.25, health = 110, power = 1.10, levels = 2, difficulty = 0.111 },
	-- HOOK: technique and refine; QC4 by about 9-10 min of play.
	{ key = "QC3", major = "QiCondensation", minor = 3, beat = "HOOK", bar = 200, dantian = 260, passive = 0.30, health = 120, power = 1.21, levels = 3, difficulty = 0.222 },
	-- BREATHER: the first free-play stage; the home grows.
	{ key = "QC4", major = "QiCondensation", minor = 4, beat = "BREATHER", bar = 680, dantian = 380, passive = 0.32, health = 135, power = 1.33, levels = 3, difficulty = 0.333 },
	-- RAMP: the bar outgrows the dantian; gather -> refine becomes the loop.
	{ key = "QC5", major = "QiCondensation", minor = 5, beat = "RAMP", bar = 1550, dantian = 540, passive = 0.43, health = 145, power = 1.46, levels = 3, difficulty = 0.444 },
	-- MINI-WALL: herbs, cores and the garden start to matter.
	{ key = "QC6", major = "QiCondensation", minor = 6, beat = "MINI-WALL", bar = 3050, dantian = 760, passive = 0.56, health = 160, power = 1.61, levels = 3, difficulty = 0.556 },
	-- BREATHER: quicker than QC6 for a bigger dantian.
	{ key = "QC7", major = "QiCondensation", minor = 7, beat = "BREATHER", bar = 3300, dantian = 1050, passive = 0.73, health = 175, power = 1.77, levels = 3, difficulty = 0.667 },
	-- RAMP: the long climb before the wall.
	{ key = "QC8", major = "QiCondensation", minor = 8, beat = "RAMP", bar = 9350, dantian = 1450, passive = 0.95, health = 195, power = 1.95, levels = 3, difficulty = 0.778 },
	-- WALL: the biggest bar, about an hour. This is where the first realm ends. A
	-- player who is heaven-defying (PlayerData `heavenDefying`) must also survive
	-- the tribulation; everyone else breaks through at once.
	{ key = "QC9", major = "QiCondensation", minor = 9, beat = "WALL", bar = 20000, dantian = 2000, passive = 1.22, health = 215, power = 2.14, levels = 3, difficulty = 0.889, tribulation = HEAVENLY_TRIBULATION },
	-- HOOK: Qi Refining opens: x2.25 strength, a bigger dantian, a fast first bar.
	-- A fresh region (the Outer Wastes) and the first chapter quests.
	{ key = "QR1", major = "QiRefining", minor = 1, beat = "HOOK", bar = 12000, dantian = 3200, passive = 1.94, health = 480, power = 4.82, levels = 3, difficulty = 0.900 },
	-- RAMP: weekly sect tasks settle in.
	{ key = "QR2", major = "QiRefining", minor = 2, beat = "RAMP", bar = 15500, dantian = 3750, passive = 2.20, health = 530, power = 5.31, levels = 3, difficulty = 0.911 },
	-- MINI-WALL: tier II herbs and the Herbarium (alchemy is a later update).
	{ key = "QR3", major = "QiRefining", minor = 3, beat = "MINI-WALL", bar = 24500, dantian = 4400, passive = 2.50, health = 585, power = 5.84, levels = 3, difficulty = 0.922 },
	-- BREATHER: seclusion. The real slowdown starts after it: from here passive
	-- grows as a share of income, so the garden and the peak carry cultivation.
	{ key = "QR4", major = "QiRefining", minor = 4, beat = "BREATHER", bar = 26000, dantian = 5150, passive = 3.12, health = 640, power = 6.42, levels = 3, difficulty = 0.933 },
	-- RAMP: the Thunder Ape; hunting alone gets slow.
	{ key = "QR5", major = "QiRefining", minor = 5, beat = "RAMP", bar = 53500, dantian = 6000, passive = 3.68, health = 705, power = 7.06, levels = 3, difficulty = 0.944 },
	-- MINI-WALL: Dao glimpses; the Deep Wilds seal.
	{ key = "QR6", major = "QiRefining", minor = 6, beat = "MINI-WALL", bar = 79500, dantian = 7000, passive = 4.35, health = 775, power = 7.77, levels = 3, difficulty = 0.956 },
	-- BREATHER: sect trials.
	{ key = "QR7", major = "QiRefining", minor = 7, beat = "BREATHER", bar = 54500, dantian = 8200, passive = 5.14, health = 855, power = 8.54, levels = 3, difficulty = 0.967 },
	-- RAMP: the first secret-realm rift (weapon refinement is a later update).
	{ key = "QR8", major = "QiRefining", minor = 8, beat = "RAMP", bar = 78500, dantian = 9600, passive = 5.83, health = 940, power = 9.40, levels = 3, difficulty = 0.978 },
	-- WALL: the biggest bar of the realm. A heaven-defier faces a tribulation to leave it.
	{ key = "QR9", major = "QiRefining", minor = 9, beat = "WALL", bar = 115000, dantian = 11200, passive = 6.59, health = 1030, power = 10.30, levels = 3, difficulty = 0.989, tribulation = QR_TRIBULATION },
	-- HOOK: x2.25 strength; the cultivation method and the Far Reaches.
	{ key = "FE1", major = "Foundation", minor = 1, beat = "HOOK", bar = 185000, dantian = 18000, passive = 10.30, health = 2330, power = 23.30, levels = 3, difficulty = 1.000 },
	-- RAMP: method upgrades from exploring.
	{ key = "FE2", major = "Foundation", minor = 2, beat = "RAMP", bar = 270000, dantian = 20700, passive = 11.50, health = 2560, power = 25.60, levels = 3, difficulty = 1.000 },
	-- MINI-WALL: tier III herbs.
	{ key = "FE3", major = "Foundation", minor = 3, beat = "MINI-WALL", bar = 390000, dantian = 23800, passive = 12.80, health = 2810, power = 28.10, levels = 3, difficulty = 1.000 },
	-- BREATHER: the treasure slot.
	{ key = "FE4", major = "Foundation", minor = 4, beat = "BREATHER", bar = 355000, dantian = 27400, passive = 14.30, health = 3100, power = 31.00, levels = 3, difficulty = 1.000 },
	-- RAMP: secret realms.
	{ key = "FE5", major = "Foundation", minor = 5, beat = "RAMP", bar = 490000, dantian = 31500, passive = 16.00, health = 3410, power = 34.10, levels = 3, difficulty = 1.000 },
	-- MINI-WALL: the spirit beast egg.
	{ key = "FE6", major = "Foundation", minor = 6, beat = "MINI-WALL", bar = 665000, dantian = 36200, passive = 17.90, health = 3750, power = 37.50, levels = 3, difficulty = 1.000 },
	-- BREATHER: tier IV herbs.
	{ key = "FE7", major = "Foundation", minor = 7, beat = "BREATHER", bar = 610000, dantian = 41600, passive = 20.00, health = 4120, power = 41.20, levels = 3, difficulty = 1.000 },
	-- RAMP: the Far Reaches' secret realm (mining is a later update).
	{ key = "FE8", major = "Foundation", minor = 8, beat = "RAMP", bar = 810000, dantian = 47900, passive = 22.40, health = 4530, power = 45.30, levels = 3, difficulty = 1.000 },
	-- PEAK: the cap for now (Core Formation awaits). Its bar is shown, never broken through.
	{ key = "FE9", major = "Foundation", minor = 9, beat = "PEAK", bar = 990000, dantian = 55000, passive = 25.10, health = 4990, power = 49.90, levels = 3, difficulty = 1.000 },
} :: { Row }

-- BEASTS FOLLOW THE CURVE. Enemies defs (health, attack damage) were authored
-- against these player stats (the 2026-10-22 curve) at the beast's `realm`. A
-- beast's health is scaled by (the curve's power / this power) and its damage by
-- (the curve's health / this health) at its stage, so a same-stage beast takes as
-- many hits and lands as many as it was designed to, whatever the curve becomes.
-- The factor applies to every beast at the stage, so new beasts are authored
-- against these numbers too (e.g. FE1: a 700 HP player hitting at power 3.9).
Pacing.BeastBaseline = {
	health = { QC1 = 100, QC2 = 120, QC3 = 140, QC4 = 165, QC5 = 190, QC6 = 220, QC7 = 255, QC8 = 290, QC9 = 330,
		QR1 = 360, QR2 = 390, QR3 = 420, QR4 = 450, QR5 = 480, QR6 = 515, QR7 = 550, QR8 = 585, QR9 = 620,
		FE1 = 700, FE2 = 745, FE3 = 790, FE4 = 835, FE5 = 880, FE6 = 925, FE7 = 970, FE8 = 1015, FE9 = 1060 } :: { [string]: number },
	power = { QC1 = 1.00, QC2 = 1.10, QC3 = 1.20, QC4 = 1.32, QC5 = 1.45, QC6 = 1.60, QC7 = 1.76, QC8 = 1.94, QC9 = 2.13,
		QR1 = 2.28, QR2 = 2.42, QR3 = 2.56, QR4 = 2.70, QR5 = 2.84, QR6 = 2.98, QR7 = 3.12, QR8 = 3.26, QR9 = 3.40,
		FE1 = 3.90, FE2 = 4.08, FE3 = 4.26, FE4 = 4.44, FE5 = 4.62, FE6 = 4.80, FE7 = 4.98, FE8 = 5.16, FE9 = 5.34 } :: { [string]: number },
}

-- REALM SUPPRESSION (Realms.suppression; applied in Combat.damageEnemy for player
-- hits and EnemyService's hurtBy for beast and boss blows). Damage from an attacker
-- whose MAJOR realm is below the target's is multiplied by KEEP for each major
-- between them: a QC player deals 20% to a QR beast and 4% to an FE one, and a QC
-- beast does the same to a QR player. A higher-realm attacker gets nothing extra
-- beyond its own stats. Beasts and bosses use their Enemies `realm` major. Minor
-- stages never suppress. Tribulation strikes aren't suppressed.
Pacing.Suppression = {
	KEEP = 0.2,
}

-- HEAVEN-DEFIERS (PlayerData `heavenDefying`): the heavens resist them, so every
-- bar is BAR x longer (Cultivation.stage) and a tribulation guards every major
-- breakthrough; in return they shrug off part of realm suppression when they hit
-- upward: SUPPRESSION_RESIST of the reduction is ignored (half: 0.6 per major
-- instead of 0.2), so they fight above their realm and farm stronger beasts.
Pacing.HeavenDefying = {
	BAR = 1.5,
	SUPPRESSION_RESIST = 0.5,
}

-- PER-STAGE CORRECTIONS, by stage key. Empty by default: the curve is the design.
-- To ease a dropoff at a stage, add an entry, e.g.
--   QC6 = { bar = 0.8 },                 -- 20% less qi to fill the bar
--   QC6 = { refine = 1.25 },             -- each circulation run gives 25% more
--   QC6 = { gather = 1.5 },              -- nodes and kills pour 50% more raw qi
--   QC6 = { difficulty = -0.2 },         -- easier minigames at this stage
--   QC6 = { passive = 1.5 },             -- idlers and meditators progress faster
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
	RUNS_PER_DANTIAN = 2.5, -- a full run (every level cleared) spends dantian / this raw qi; each level its share
	MIN_RUN_FRACTION = 0.25, -- need at least this share of a full run's qi to start
	EFFICIENCY_MIN = 0.5, -- cultivation per raw qi at score 0
	EFFICIENCY_MAX = 1.3, -- and at score 1 (before the stage's refine multiplier)
	DEVIATION_SCORE = 0.35, -- below this the run causes a qi deviation
	DEVIATION_SECONDS = 20, -- no circulating and no passive cultivation meanwhile
	FULL_CLEAR_BONUS = 0.2, -- clearing every level of a run refines this much more, for no extra qi
}

-- RAW QI INCOME (what refining spends). Herb qi is a share of the eater's current
-- dantian by the herb's tier (Pacing.Herbs below, Herbs.luau `tier`); item qi is
-- per item (Items.luau `use`); enemy qiDrop is per enemy (Enemies.luau).
Pacing.Income = {
	STARTING_RAW_QI = 48, -- a new player's dantian: exactly the first circulation run (QC1 dantian / RUNS_PER_DANTIAN), so it's spent and the wolves are why you go out
	NODE_SHARE = 0.2, -- a qi node gather gives this share of the dantian (times gather)
	NODE_COOLDOWN = 45, -- seconds before the same player can gather a node again
	-- enemy qi = qiDrop * (dantian / QC1 dantian) ^ this, times the stage's gather
	ENEMY_QI_EXPONENT = 0.8,
	DAILY_QI_SHARE = 0.5, -- first login of a day: this share of the dantian (times gather)
	OFFLINE_MAX_HOURS = 12, -- offline cultivation counts at most this long
	OFFLINE_RATE = 1, -- share of the passive rate while away
}

-- HERBS: eating a herb whose `eat.qi` is set gives this share of the eater's
-- current stage dantian (Herbs.eatQi), by the herb's tier (I Common, II Spirit, III Rare,
-- IV Treasure, V Heavenly; docs/progression.md "Home, herbs and the loop"). A
-- share, not a flat number, so the garden stays worth it at every stage.
-- Early on a share is tiny (a tier II herb is 16 qi at QC1), so each tier also
-- has a floor in raw qi (about the old flat values). Event herbs (PRIZE, by herb
-- id) replace their tier's share with a bigger one so they stay a prize at any
-- stage. Either way raw qi only fills the room left in the dantian.
Pacing.Herbs = {
	EAT_SHARE = { 0.06, 0.09, 0.12, 0.16, 0.2 }, -- by tier, I..V
	EAT_FLOOR = { 120, 400, 2500, 8000, 20000 }, -- raw qi at least, by tier
	PRIZE = {
		ThousandYearGinseng = 1.0, -- a full dantian (the Thousand-Year Ginseng event)
		RiftLotus = 0.5, -- half a dantian (Heaven Split's wild bloom)
	} :: { [string]: number },
}

-- THE HERBARIUM (server Herbarium; docs/ui/herbarium.md). A herb is discovered the
-- first time it's harvested or gathered; each discovery pays DISCOVER stones by its
-- tier. Discovering every herb of a tier completes its page: TIER stones and a Home
-- foundation experience ("home:book:<tier>"). First guesses (roadmap open question:
-- small stone rewards plus a foundation experience, no cosmetics yet).
Pacing.Herbarium = {
	DISCOVER = { 15, 40, 120, 300, 800 }, -- Spirit Stones per new herb, by tier I..V
	TIER = { 150, 400, 1200, 3000, 8000 }, -- Spirit Stones for a completed tier page
}

-- MEDITATION multiplies the passive rate while seated (build items on the peak
-- add their BuildItems `meditation` bonus on top of ON_PEAK).
Pacing.Meditation = {
	ANYWHERE = 1.5,
	ON_PEAK = 2.5, -- on your own spirit peak
}

-- PEAK SCORE: every build piece standing on your peak (placed or starter) scores
-- points; the score, up to your peak tier's cap (Config.Build.TIERS `scoreCap`),
-- adds to meditation on your peak and to your plants' growth speed. The mid-QR
-- lever: QR raises the cap, so building your abode keeps cultivation moving.
--   points = BuildItems `score`, else BY_CATEGORY[category] + GATED[the gate's major]
--   only the first PER_ITEM copies of one item count
Pacing.PeakScore = {
	BY_CATEGORY = {
		Structures = 6,
		Cultivation = 5,
		Garden = 3,
		Furniture = 2,
		Lighting = 2,
		Decor = 1,
		Nature = 1,
	} :: { [string]: number },
	GATED = { QiCondensation = 2, QiRefining = 4, Foundation = 6 } :: { [string]: number },
	PER_ITEM = 5,
	MEDITATION = 0.004, -- meditation multiplier per point (QR cap 150: +0.6 on ON_PEAK)
	GROWTH = 0.002, -- garden growth speed per point (QR cap 150: +30%)
}

-- BREAKTHROUGHS happen seated on a full bar, never anywhere else. The FORCE_*
-- shares are the qi surge's ready rule (Pacing.Surge below), the conditions the
-- forced breakthrough used before the surge replaced it.
Pacing.Breakthrough = {
	FORCE_BAR_SHARE = 0.9, -- the bar must be at least this full for a qi surge
	FORCE_HEALTH_SHARE = 0.35, -- and health at most this share of max, in combat
	-- Past the bar: passive, refining and items keep filling cultivation up to
	-- this share of the bar (the realm doesn't move until the player breaks
	-- through). On a breakthrough the excess carries into the next stage,
	-- at most CARRY_SHARE of the new bar.
	OVERFLOW_CAP = 1.5,
	CARRY_SHARE = 0.25,
}

-- THE QI SURGE (server QiSurge; docs/systems/cultivation.md "Qi surge"). In combat,
-- badly hurt, with the bar at FORCE_BAR_SHARE: the player fights for SECONDS at the
-- next stage's health and power, healed HEAL_SHARE of the raised max health, and it
-- burns RAW_QI_SHARE of the raw qi in the dantian. Once per combat engagement (until
-- the InCombat tag drops) when ONCE_PER_COMBAT. Never seated, in a tribulation or at
-- the peak stage.
Pacing.Surge = {
	SECONDS = 15,
	HEAL_SHARE = 0.2, -- of the surged max health, on top of what the raise keeps
	RAW_QI_SHARE = 0.25, -- of the raw qi in the dantian when it fires
	ONCE_PER_COMBAT = true,
}

-- COMBAT QI (server CombatQi; docs/systems/combat.md). The mana techniques
-- spend, separate from the raw qi in the dantian (which only feeds cultivation).
-- Not saved: full on join, on respawn and after a breakthrough. Basic attacks,
-- dashes and the guard are free.
Pacing.CombatQi = {
	-- the pool's size by stage; a stage missing here gets DEFAULT_MAX
	MAX = { QC1 = 100, QC2 = 110, QC3 = 120, QC4 = 130, QC5 = 140, QC6 = 155, QC7 = 170, QC8 = 185, QC9 = 200,
		QR1 = 210, QR2 = 220, QR3 = 230, QR4 = 240, QR5 = 250, QR6 = 260, QR7 = 270, QR8 = 280, QR9 = 290,
		FE1 = 300, FE2 = 310, FE3 = 320, FE4 = 330, FE5 = 340, FE6 = 350, FE7 = 360, FE8 = 370, FE9 = 380 } :: { [string]: number },
	DEFAULT_MAX = 100,
	REGEN_SHARE = 0.04, -- of max per second while fighting (hurt or dealing damage in the last Combat.IN_COMBAT_SECONDS)
	OUT_OF_COMBAT_SHARE = 0.2, -- of max per second otherwise (empty to full in 5 s)
	REGEN_DELAY = 1.5, -- seconds after spending before regen resumes
	-- a technique's cost when its Techniques def has no `qiCost`: cooldown seconds times this
	COST_PER_COOLDOWN = 2.5,
}

-- KILL CREDIT AND MANUALS (Progression.luau). Kill milestones and the first boss
-- kill grant manuals; first kills of each beast and boss are foundation
-- experiences (Pacing.Foundation).
Pacing.Rewards = {
	-- a player is credited with a kill (qi, stones, drops) only if they
	-- dealt at least this share of the beast's max health; a boss asks more, so
	-- one tag in a crowd doesn't earn the boss rewards
	KILL_SHARE = 0.1,
	BOSS_KILL_SHARE = 0.15,
	BOSS_FIRST_MANUAL = "TwinPhoenixCannon",
	-- boss pools of class manuals and Spirit weapons: Enemies `bossDrops`;
	-- the rest of the class manuals and the Mortal weapons are in world caches
	-- and the sect weapon rack (docs/systems/weapons.md)
	-- kill milestones (total kills): a manual, once each
	MILESTONES = {
		-- early manuals work with any weapon (the onboarding's first manual is the
		-- 3-kill one), then the starting sword's, then other classes'
		{ kills = 3, manual = "FireSeal" },
		{ kills = 12, manual = "SwordQiWave" },
		{ kills = 30, manual = "IronSkin" },
		{ kills = 60, manual = "MoonflashDraw" },
		{ kills = 100, manual = "PalmStrike" },
	} :: { { kills: number, manual: string? } },
}

-- OBJECTIVE REWARDS (server Quests; docs/systems/onboarding.md). Every
-- onboarding beat and lesson is a rewarded objective, claimed once per profile
-- (data.quests, by id). Keyed by the beat or lesson id.
--   stones   Spirit Stones
--   qiShare  raw qi, as a share of the dantian of the stage it's claimed at
--            (so it stays worth the same later; capped by the room left)
-- SIZING. The early economy: a new player starts with 150 stones; a Spirit
-- Grass seed costs 10 and a Cloud Mint seed 40; a spirit wolf drops 3-6 stones
-- (about 4.5), a qi node 4-8; the first technique bottleneck costs 60 stones;
-- the Elder Wolf King drops 60-90. So:
--   * the ten first-session beats pay 85 stones in all (about 18 wolf kills,
--     half the starting purse): felt at every step, not a second economy.
--     Cast adds a fifth of a dantian of raw qi (36 at QC2) so the refine run
--     right after the first hunt reaches the second breakthrough; QC3 adds a
--     quarter (65 at QC3, over half a run) toward the third.
--   * the lessons pay 20-50 each, about one Spirit Grass bed (Home: 3 seeds) or
--     two thirds of a bottleneck gate (Bottleneck), never a whole purchase.
--   * a cultivation method (a big moment) pays the most.
-- Kids should feel every step pays; nothing here should outpace hunting.
export type QuestReward = { stones: number?, qiShare: number? }
Pacing.Quests = {
	-- beats (QC1-4, the first session)
	Circulate = { stones = 5 },
	Breakthrough = { stones = 10 },
	FirstKill = { stones = 10 },
	Technique = { stones = 10 },
	Cast = { stones = 5, qiShare = 0.2 },
	Store = { stones = 5 },
	Refine = { stones = 5 },
	QC3 = { stones = 20, qiShare = 0.25 },
	Root = { stones = 10 },
	QC4 = { stones = 5 },
	-- lessons (met later, when each first matters; QC4-9 one per chapter)
	RootPill = { stones = 20 },
	Home = { stones = 30 },
	Board = { stones = 20 },
	Herbs = { stones = 20 },
	Rumours = { stones = 40 },
	Wall = { stones = 50 },
	Bottleneck = { stones = 40 },
	WeaponRack = { stones = 30 },
	DaoPractice = { stones = 50 },
	Method = { stones = 150 },
} :: { [string]: QuestReward }

-- TECHNIQUE COMPREHENSION (Techniques.bottleneck, Progression.comprehend). Casting
-- levels a technique, but at the top of each visual tier (Techniques.VISUAL_TIERS:
-- levels 3, 6, 9) its XP stops at a bottleneck. Breaking it costs Spirit Stones,
-- spent seated in meditation, needs weapon Dao (Pacing.Weapons, levels 0-10), and
-- opens the next tier.
-- DAO GATES (Techniques.learnDao, Techniques.comprehendDao). Learning a technique
-- needs its class's Dao at its `learnDao` (the def's `dao`, nil = 0); any-weapon
-- arts check the player's highest class Dao. Bottleneck `step` k (1, 2, 3) needs
-- Dao >= min(10, learnDao + k * DAO_PER_BOTTLENECK), or k * DAO_PER_BOTTLENECK_HIGH from HIGH_FROM up. A manual found too early is
-- kept and learned the moment that Dao is reached.
Pacing.Comprehension = {
	-- the Dao rungs of a class's skills (each def picks one as its `dao`); starter arts
	-- need 0. Plain is each class's mediocre first skill (none made yet), Adept and Peak
	-- the showpieces: Peak for the most spectacular (Tiger, Heaven-Splitter, Great Sage)
	SKILL_DAO = { Plain = 2, Adept = 5, Peak = 8 },
	DAO_PER_BOTTLENECK = 2,
	DAO_PER_BOTTLENECK_HIGH = 1, -- the step for skills learned at HIGH_FROM or above (Dao 5: 6, 7, 8; Dao 8: 9, 10, 10)
	HIGH_FROM = 5,
	GATES = { -- by the level the bottleneck sits at
		[3] = { stones = 60, step = 1 }, -- into tier II
		[6] = { stones = 250, step = 2 }, -- into tier III
		[9] = { stones = 600, step = 3 }, -- into mastery
	} :: { [number]: { stones: number, step: number } },
}

-- CULTIVATION METHODS (Methods.luau, server Methods; docs/character/method.md).
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
	FROM = "QR1", -- the stage it unlocks, with the second-weapon lesson (QR, docs/roadmap.md section 2)
	COOLDOWN = 300, -- seconds between finished drills (saved, so rejoining doesn't skip it)
	XP_SHARE = 0.25, -- of xpToNext(level), at a perfect score
	SECONDS = 20,
	GAME = "Forms", -- Minigames/<GAME>: osu-style strike points anywhere on the field
	DIFFICULTY = 0.35,
}

-- THE HAUL (server Haul; docs/systems/haul.md). What a player has gained since
-- they last banked (raw qi in the dantian, herbs, seeds, spirit cores and the
-- like, Spirit Stones) is at risk until they reach the sect (their peak, the
-- plaza) or stand on any teleport array out of combat. A death spills SPILL_SHARE
-- of it where they fell, as a spirit-light only they can see and walk back into
-- for SPILL_SECONDS; leaving while combat-tagged loses that share outright.
-- Finds at or above SAFE_RARITY bank the moment they're picked up, and the
-- spirit ring keeps RING_SLOTS whole stacks banked even in the wilds.
Pacing.Haul = {
	SPILL_SHARE = 0.5, -- of each unbanked amount, rounded to the nearest whole
	SPILL_SECONDS = 300, -- the spill waits this long, then it's gone
	RECLAIM_RADIUS = 7, -- studs from the spill that pick it back up
	SAFE_RARITY = 4, -- Items.Rarities order (4 Epic, 5 Legendary): banks on pickup
	RING_SLOTS = { QiCondensation = 2, QiRefining = 3, Foundation = 4 } :: { [string]: number }, -- by major realm
	TESTBED_BANK_RADIUS = 24, -- testbed: studs from the spawn pad that count as home
	CHECK_SECONDS = 0.5, -- how often banking, the ring and the spill are checked
}

-- SPIRIT ROOTS (Roots.luau, server Roots; docs/character/spirit-root.md). A root's
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
	-- Marrow Washing Pills absorbed to reach each grade from the one below (kept
	-- per element in root.washed). Pills are boss and treasure drops at a few
	-- percent (Enemies drops, Items treasureWeight), so Earth is a long hunt and
	-- Heaven (3 + 5 = 8 pills) is a Foundation-and-beyond goal (user, 2026-10-23:
	-- "should be hard to get one")
	WASH = { Earth = 3, Heaven = 5 } :: { [string]: number },
}

-- BEAST DANGER (client EnemyBars; docs/systems/enemies.md). A regular demon
-- beast's overhead bar is dressed by its realm gap: Realms.index(beast) minus
-- Realms.index(player), in stages on the ladder. Bosses keep their screen bar.
-- Thresholds are the smallest gap that reaches each tier; below BELOW_AT and up
-- to EVEN_AT the beast reads as your equal.
--   gap <= BELOW_AT    "below"   muted bronze, no omen
--   gap <  ABOVE_AT    "even"    jade, no omen
--   gap >= ABOVE_AT    "above"   gold with a seal tip and an omen line
--   gap >= FAR_AT      "far"     violet with a pulsing qi aura, a sheen and an ornate tip
--   gap >= DEADLY_AT   "deadly"  no bar: a skull seal and a "do not fight" omen
-- Realm suppression overrides the count: a beast one major realm up reads at least
-- "far" (two: "deadly"), and one a major below reads "below".
Pacing.Danger = {
	BELOW_AT = -2,
	ABOVE_AT = 2,
	FAR_AT = 4,
	DEADLY_AT = 6,
}

-- FOUNDATION GRADES (server Foundation; docs/systems/cultivation.md "Foundation
-- grade"). One-time experiences earned while at a stage (each key once ever per
-- profile) are weighed against the stage's TARGET at the breakthrough out of it:
-- the share of the target reached picks the grade (GRADES, lowest first). Every
-- graded stage adds its grade's BONUS to max health and to power, summed over all
-- stages and applied as its own multiplier on top of Pacing.Curve. Time fills the
-- bar, not the grade. Untuned first guesses (roadmap open questions).
export type FoundationGrade = "Cracked" | "Steady" | "Solid" | "Deep"
Pacing.Foundation = {
	-- what one experience of each category counts for
	WEIGHTS = { Hunt = 1, Boss = 2, Home = 1, Dao = 1, Discover = 1, World = 1 } :: { [string]: number },
	-- experiences per stage for a Deep grade; a stage missing here gets DEFAULT_TARGET
	TARGET = { QC1 = 2, QC2 = 3, QC3 = 3, QC4 = 4, QC5 = 4, QC6 = 4, QC7 = 4, QC8 = 4, QC9 = 5 } :: { [string]: number },
	DEFAULT_TARGET = 5, -- Qi Refining and Foundation (pools there are thin until their regions exist)
	-- the share of the target that reaches each grade, lowest first (Cracked below Steady's)
	GRADES = {
		{ name = "Cracked", share = 0 },
		{ name = "Steady", share = 0.34 },
		{ name = "Solid", share = 0.67 },
		{ name = "Deep", share = 1 },
	} :: { { name: FoundationGrade, share: number } },
	SOLID = "Solid", -- grades below this get the unsteady toast and a harder tribulation
	-- share added to max health and power per stage graded so
	BONUS = { Cracked = 0, Steady = 0.01, Solid = 0.02, Deep = 0.04 } :: { [string]: number },
	-- a heaven-defier's tribulation strike damage, by the grade the stage would get now
	TRIBULATION_DAMAGE = { Cracked = 1.25, Steady = 1.1 } :: { [string]: number },
	MUTATION_BONUS = 1, -- a harvest mutation counts as rare (Home) from this Herbs.Mutations bonus up
	EVENT_RADIUS = 150, -- studs from a located world event that count as taking part
	HINTS = 5, -- open experiences listed in the PlayerState push
	HINT_BELOW = 3, -- beasts suggested from this many stages below the player...
	HINT_ABOVE = 2, -- ...to this many above (bosses too, as "the fast road")
}

-- The heart-demon trial (server HeartDemon, docs/systems/heart-demon.md): an
-- optional, choice-based reflection at each major's stage 9 that tempers old
-- foundation grades. Never costs a stage or cultivation.
Pacing.HeartDemon = {
	QUESTIONS = 4, -- the most asked: the path question, then the record's strongest
	TEMPER_CALM = 3, -- old grades a calmed demon (no denials) raises one step each, lowest first
	TEMPER_ROUGH = 1, -- the least a finished trial tempers, however many denials
	-- each denial (an answer the record contradicts) tempers one fewer, down to TEMPER_ROUGH
	HARVEST_WEIGHT = 2, -- one harvest weighs as this many kills when reading the path
	HUNTER_SHARE = 0.65, -- kills / (kills + weighted harvests) from here up: a hunter
	GARDENER_SHARE = 0.35, -- and up to here: a gardener (between: both roads)
	LEAN_MIN = 6, -- below this many kills + weighted harvests: the still road (sat, little else)
	SLAIN_MIN = 10, -- kills before the demon names the beasts you slew
	STILL_MIN_HOURS = 0.5, -- hours seated before stillness is a question
	OFFER_COOLDOWN = 20 * 3600, -- seconds after "Not now" before the seat offers it again
}

return Pacing
