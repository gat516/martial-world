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
--   QR1-3  the new realm opens fast: no bar is ever smaller than the one before, so
--          QR1-2 pour more raw qi instead (the row's `gather`: x2.0, x1.6)
--   QR4-9  THE REAL SLOWDOWN: bars outgrow hunting, and passive grows as a share of
--          income so the garden aura, peak build items and herbs (all multiply or
--          add to it) are what keep cultivation moving (user, 2026-10-23; not alchemy)
--   FE1-9  the long realm; no stage over about 3 h; FE9 is the cap for now
--          (PEAK: its bar is shown, never broken through)
--   The walls are the bar (and the tribulation for heaven-defiers); nothing
--   else gates a breakthrough. A heaven-defier's bar is HeavenDefying.BAR x longer.
--
-- TIME-TO-BREAKTHROUGH ESTIMATES (Global = 1; bars after Pacing.Adjust). Regenerate
-- with `python3 tools/pacing_model.py --header` (the model checks this table on every run).
--   active   the bare fighter: passive (never stops) plus about 2 wolf kills'
--            worth of raw qi a minute (kills and nodes, net of travel and
--            refining), refined at 1.1 cultivation per raw qi (~0.8 score);
--            no herbs, cores, garden, seat, buffs, method or party
--   on peak  the bare gardener: meditating on their own peak, nothing else
--   regular  THE TARGET: the model's regular player (1.5 h a day, hunts about half
--            the time and sits on the peak the rest, a growing garden, a cushion,
--            some building, a party a quarter of the time), online time only
--            (docs/systems/pacing-model.md). Since the 2026-10-24 rebalance the
--            bars are sized for players who use the systems, so the bare columns
--            are far slower than the targets, by design.
--   stage     bar    active  on peak  meditate    idle  regular  refine runs, wolf kills of qi
--   QC1         40    1 min    1 min     2 min   3 min    1 min     1 runs  ~3 wolves
--   QC2        100    2 min    3 min     4 min   7 min    1 min     1 runs  ~5 wolves
--   QC3        200    3 min    4 min     7 min  11 min    3 min     2 runs  ~7 wolves
--   QC4        782    8 min   16 min    27 min  41 min    7 min     5 runs  ~20 wolves
--   QC5       1782   14 min   28 min    46 min   1.2 h   13 min     8 runs  ~35 wolves
--   QC6       3507   21 min   42 min     1.2 h   1.7 h   19 min    10 runs  ~52 wolves
--   QC7       3795   17 min   35 min    58 min   1.4 h   15 min     8 runs  ~43 wolves
--   QC8      10752   38 min    1.3 h     2.1 h   3.1 h   33 min    17 runs  ~95 wolves
--   QC9      23000    1.0 h    2.1 h     3.5 h   5.2 h   51 min    26 runs  ~157 wolves   QC total: 2.8 h active, 5.5 h on peak, regular 2.4 h
--   QR1      36300   36 min    1.6 h     2.6 h   3.9 h   33 min    26 runs  ~85 wolves (gather 2)
--   QR2      38775   41 min    1.5 h     2.6 h   3.8 h   31 min    23 runs  ~100 wolves (gather 1.6)
--   QR3      42075   58 min    1.6 h     2.6 h   3.9 h   43 min    22 runs  ~153 wolves
--   QR4      42900   53 min    1.5 h     2.5 h   3.8 h   30 min    19 runs  ~138 wolves
--   QR5      88275    1.6 h    2.7 h     4.4 h   6.7 h   55 min    33 runs  ~251 wolves
--   QR6     131175    2.1 h    3.4 h     5.6 h   8.4 h    1.2 h    43 runs  ~329 wolves
--   QR7     131175    1.2 h    2.7 h     4.5 h   6.7 h   48 min    36 runs  ~181 wolves (gather 1.6)
--   QR8     141900    1.7 h    2.7 h     4.5 h   6.8 h   53 min    34 runs  ~277 wolves
--   QR9     189750    2.0 h    3.2 h     5.3 h   8.0 h    1.0 h    39 runs  ~327 wolves   QR total: 11.8 h active, 20.8 h on peak, regular 7.1 h
--   FE1     777000    5.6 h    8.4 h    14.0 h  21.0 h    1.7 h    98 runs  ~916 wolves
--   FE2    1134000    7.3 h   11.0 h    18.3 h  27.4 h    2.0 h   125 runs  ~1196 wolves
--   FE3    1638000    9.5 h   14.2 h    23.7 h  35.5 h    2.2 h   156 runs  ~1545 wolves
--   FE4    1638000    7.1 h   12.1 h    20.2 h  30.3 h    2.2 h   136 runs  ~1104 wolves (gather 1.25)
--   FE5    2058000    9.5 h   14.3 h    23.8 h  35.7 h    2.4 h   148 runs  ~1551 wolves
--   FE6    2793000   11.5 h   17.3 h    28.9 h  43.3 h    2.7 h   175 runs  ~1883 wolves
--   FE7    2793000    9.2 h   14.8 h    24.6 h  36.9 h    2.0 h   153 runs  ~1465 wolves (gather 1.15)
--   FE8    3402000   11.2 h   16.9 h    28.1 h  42.2 h    2.2 h   161 runs  ~1834 wolves
--   FE9    4158000   12.3 h   18.4 h    30.7 h  46.0 h    2.4 h   172 runs  ~2006 wolves   FE total: 83.1 h active, 127.4 h on peak, regular 19.9 h
-- The bare gardener's road is about 2x the bare fighter's in QC and 1.5-1.8x after;
-- the garden aura, herbs and the seat close it (the model's garden road is within 15%
-- of the regular; docs/systems/progression-rules.md "No lever is mandatory").
-- "Wolves" counts qi, not fights: from QC5 on players hunt bigger beasts whose
-- qiDrop is several wolves'. Untuned in play; tune from analytics with Adjust.
-- Formulas (w = one spirit wolf's qi at the stage = 14 * (dantian / 120) ^
-- Income.ENEMY_QI_EXPONENT; p = passive; bar = the curve's bar x Adjust):
--   active = bar / (60 p + 2 * 1.1 * w * gather) minutes (gather: the row's, default 1)
--   idle = bar / p; meditate = idle / Meditation.ANYWHERE; on peak = idle / Meditation.ON_PEAK
--   runs = bar / (dantian / RUNS_PER_DANTIAN * 1.1); wolves = bar / 1.1 / (w * gather)
-- The curve's rows were set from a bare fighter's minutes (bar = minutes * (60 p +
-- 2.2 w gather)); Adjust then scales each realm for the stacked systems.
-- Every bar is at least the previous stage's (user, 2026-10-23: bars never go down).
-- A breather keeps the previous bar (or a little more) and eases it with the row's
-- `gather` (QR7 x1.6, FE4 x1.25, FE7 x1.15) and a small passive lift instead.
-- Passive is set as a share of w (about 0.009 in QC; QR1-3 lifted to 0.012-0.013
-- with the gather boost, about 0.011 at QR4 rising to 0.0125 at QR8, 0.0133 in FE,
-- the breathers QR7, FE4 and FE7 a little above their neighbours):
-- it sets the gardener's ratio.
--
-- AFK, OFFLINE AND SECLUSION (decided 2026-10-23; docs/systems/seclusion.md). Offline,
-- AFK online (no input for Income.AFK_AFTER) and secluded all earn the same: the
-- stage's plain passive (OFFLINE_RATE x p; no meditation, aura, weather, buffs, root or
-- method), out of ONE Income.OFFLINE_MAX_HOURS (12 h) budget a UTC day shared by every
-- absence and AFK stretch (Cultivation.awayLeft; rebalance 2026-10-24: two logins used
-- to earn two nights), up to the overflow cap. Nothing breaks through on its own and
-- none of it earns foundation experiences. A night (12 h) is p * 43200 cultivation: it
-- fills the cap (150% of the bar) at every QC and QR stage (the idle column against
-- 12 h), but since the rebalance only 26-57% of an FE bar (FE1 57%, FE3 34%, FE6 28%,
-- FE9 26%). So a night is worth about one stage in QC and QR, a third to a half of one
-- in FE (the owner's call: docs/systems/progression-rules.md "Open calls").
-- The model's profiles with nights (docs/systems/pacing-model.md): 30 min a day reaches
-- FE9 on about day 27, 1.5 h a day on day 14, 3 h a day on day 7 (online only: 57,
-- 18, 8). The foundation grade (cracked when a stage was mostly slept through) is the
-- cost of sleeping through.
-- Lowering the AFK ceiling below the cap barely moves QC and QR (the carry already
-- drops the excess); to slow nights, lower OFFLINE_RATE or OFFLINE_MAX_HOURS.
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
	gather: number?, -- the curve's own raw qi multiplier at this stage (kills, nodes, daily qi); the new realm's hook (QR1-2) and the breathers (QR7, FE4, FE7)
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
	-- BREATHER: quicker than QC6 (a bigger dantian pours more qi), on a bar a little bigger.
	{ key = "QC7", major = "QiCondensation", minor = 7, beat = "BREATHER", bar = 3300, dantian = 1050, passive = 0.73, health = 175, power = 1.77, levels = 3, difficulty = 0.667 },
	-- RAMP: the long climb before the wall.
	{ key = "QC8", major = "QiCondensation", minor = 8, beat = "RAMP", bar = 9350, dantian = 1450, passive = 0.95, health = 195, power = 1.95, levels = 3, difficulty = 0.778 },
	-- WALL: the biggest bar, about an hour. This is where the first realm ends. A
	-- player who is heaven-defying (PlayerData `heavenDefying`) must also survive
	-- the tribulation; everyone else breaks through at once.
	{ key = "QC9", major = "QiCondensation", minor = 9, beat = "WALL", bar = 20000, dantian = 2000, passive = 1.22, health = 215, power = 2.14, levels = 3, difficulty = 0.889, tribulation = HEAVENLY_TRIBULATION },
	-- HOOK: Qi Refining opens: x2.25 strength, a bigger dantian, and its beasts and
	-- nodes pour double qi (gather), so a bar bigger than QC9's still fills in about 22 min.
	-- A fresh region (the Outer Wastes) and the first chapter quests.
	{ key = "QR1", major = "QiRefining", minor = 1, beat = "HOOK", bar = 22000, dantian = 3200, passive = 2.60, gather = 2.0, health = 480, power = 4.82, levels = 3, difficulty = 0.900 },
	-- RAMP: weekly sect tasks settle in.
	{ key = "QR2", major = "QiRefining", minor = 2, beat = "RAMP", bar = 23500, dantian = 3750, passive = 2.80, gather = 1.6, health = 530, power = 5.31, levels = 3, difficulty = 0.911 },
	-- MINI-WALL: tier II herbs and the Herbarium (alchemy is a later update).
	{ key = "QR3", major = "QiRefining", minor = 3, beat = "MINI-WALL", bar = 25500, dantian = 4400, passive = 3.00, health = 585, power = 5.84, levels = 3, difficulty = 0.922 },
	-- BREATHER: the last easy stage before the real slowdown (seclusion is taught in
	-- the second session, Quests' Seclusion lesson). From here passive grows as a share of income,
	-- so the garden and the peak carry cultivation.
	{ key = "QR4", major = "QiRefining", minor = 4, beat = "BREATHER", bar = 26000, dantian = 5150, passive = 3.12, health = 640, power = 6.42, levels = 3, difficulty = 0.933 },
	-- RAMP: the Thunder Ape; hunting alone gets slow.
	{ key = "QR5", major = "QiRefining", minor = 5, beat = "RAMP", bar = 53500, dantian = 6000, passive = 3.68, health = 705, power = 7.06, levels = 3, difficulty = 0.944 },
	-- MINI-WALL: Dao glimpses; the Deep Wilds seal.
	{ key = "QR6", major = "QiRefining", minor = 6, beat = "MINI-WALL", bar = 79500, dantian = 7000, passive = 4.35, health = 775, power = 7.77, levels = 3, difficulty = 0.956 },
	-- BREATHER: sect trials. QR6's bar again, eased by gather x1.6 (bars never go down).
	{ key = "QR7", major = "QiRefining", minor = 7, beat = "BREATHER", bar = 79500, dantian = 8200, passive = 5.45, gather = 1.6, health = 855, power = 8.54, levels = 3, difficulty = 0.967 },
	-- RAMP: the first secret-realm rift (weapon refinement is a later update).
	{ key = "QR8", major = "QiRefining", minor = 8, beat = "RAMP", bar = 86000, dantian = 9600, passive = 5.83, health = 940, power = 9.40, levels = 3, difficulty = 0.978 },
	-- WALL: the biggest bar of the realm. A heaven-defier faces a tribulation to leave it.
	{ key = "QR9", major = "QiRefining", minor = 9, beat = "WALL", bar = 115000, dantian = 11200, passive = 6.59, health = 1030, power = 10.30, levels = 3, difficulty = 0.989, tribulation = QR_TRIBULATION },
	-- HOOK: x2.25 strength; the cultivation method and the Far Reaches.
	{ key = "FE1", major = "Foundation", minor = 1, beat = "HOOK", bar = 185000, dantian = 18000, passive = 10.30, health = 2330, power = 23.30, levels = 3, difficulty = 1.000 },
	-- RAMP: method upgrades from exploring.
	{ key = "FE2", major = "Foundation", minor = 2, beat = "RAMP", bar = 270000, dantian = 20700, passive = 11.50, health = 2560, power = 25.60, levels = 3, difficulty = 1.000 },
	-- MINI-WALL: tier III herbs.
	{ key = "FE3", major = "Foundation", minor = 3, beat = "MINI-WALL", bar = 390000, dantian = 23800, passive = 12.80, health = 2810, power = 28.10, levels = 3, difficulty = 1.000 },
	-- BREATHER: the treasure slot. FE3's bar again, eased by gather x1.25.
	{ key = "FE4", major = "Foundation", minor = 4, beat = "BREATHER", bar = 390000, dantian = 27400, passive = 15.00, gather = 1.25, health = 3100, power = 31.00, levels = 3, difficulty = 1.000 },
	-- RAMP: secret realms.
	{ key = "FE5", major = "Foundation", minor = 5, beat = "RAMP", bar = 490000, dantian = 31500, passive = 16.00, health = 3410, power = 34.10, levels = 3, difficulty = 1.000 },
	-- MINI-WALL: the spirit beast egg.
	{ key = "FE6", major = "Foundation", minor = 6, beat = "MINI-WALL", bar = 665000, dantian = 36200, passive = 17.90, health = 3750, power = 37.50, levels = 3, difficulty = 1.000 },
	-- BREATHER: tier IV herbs. FE6's bar again, eased by gather x1.15.
	{ key = "FE7", major = "Foundation", minor = 7, beat = "BREATHER", bar = 665000, dantian = 41600, passive = 21.00, gather = 1.15, health = 4120, power = 41.20, levels = 3, difficulty = 1.000 },
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
-- hits and EnemyService's hurtBy for beast and boss blows; PlayerPoison's ticks too,
-- and the Blood Bat's leech heals from the suppressed damage). Damage from an attacker
-- whose MAJOR realm is below the target's is multiplied by KEEP for each major
-- between them: a QC player deals 20% to a QR beast and 4% to an FE one, and a QC
-- beast does the same to a QR player. A higher-realm attacker gets nothing extra
-- beyond its own stats. Beasts and bosses use their Enemies `realm` major. Minor
-- stages never suppress. Tribulation strikes aren't suppressed.
Pacing.Suppression = {
	KEEP = 0.2,
}

-- REALM PRESSURE (docs/systems/combat.md "Realm pressure"). Three small
-- pieces around suppression, all server-side:
-- THE PARTY SHELTER (server Shelter): a player in a party with a member of a higher
-- MAJOR realm within Party RADIUS (the "patron", the strongest such member) is
-- sheltered against beasts above their own major. Their hits are suppressed from the
-- patron's major instead of their own and synced up to the beast's stage (capped at
-- the patron's): x HIT x (sync power / own power), never less than unsheltered. Beast
-- blows and poison on them are x HURT x (own health / sync health), never more than
-- unsheltered, so a hit takes about HURT times the share it takes from a same-stage
-- player. Rewards stay their own realm's (qi by their stage, the dantian caps it).
-- The patron gets SENIOR_QI_SHARE of their own qi for each beast a sheltered member is
-- credited with (stats.sheltered counts them; the junior's stats.leaned), and, once
-- the sect is open to them, CONTRIBUTION sect contribution inside the sect's WEEK_CAP.
Pacing.Shelter = {
	HIT = 0.8, -- a sheltered hit deals this share of what a same-stage player's would (the senior still carries)
	HURT = 1.25, -- a beast's blow takes this times the health share it takes from a same-stage player
	SENIOR_QI_SHARE = 0.2, -- the patron's qi per kill a sheltered member earns, of their own qi for that beast
	CONTRIBUTION = 2, -- the patron's sect contribution per sheltered kill (counted in Pacing.Sect.WEEK_CAP)
	SUPPRESSED_HOLD = 5, -- seconds the Suppressed status (player attribute) outlasts the last unsheltered hit or blow with a higher major
	TICK = 0.5, -- seconds between ShelteredBy attribute refreshes (damage checks live)
	HEART_LINE_AT = 3, -- stats.leaned / stats.sheltered from which the heart demon's company question names it
}

-- BEASTS FEEL A REALM ABOVE THEM (EnemyService). A regular beast (not a boss, a summon
-- or one sent after a player) a full major below a player doesn't pick them as a
-- target unless they've hurt it; when such a player first comes within its aggro it
-- flinches (FLINCH seconds of stagger, again after REARM seconds out of sight). Two
-- majors below, it runs from them (FLEE_STUDS at a time, inside its leash) instead.
-- A breakthrough sends a wave: every regular beast within WAVE_RADIUS below the new
-- stage staggers WAVE_STAGGER seconds (flavour).
Pacing.Pressure = {
	ENABLED = true,
	FLINCH = 0.8,
	REARM = 30,
	FLEE_STUDS = 24,
	WAVE_RADIUS = 60,
	WAVE_STAGGER = 1.2,
}

-- HEAVEN-DEFIERS (PlayerData `heavenDefying`): the heavens resist them, so every
-- bar is BAR x longer (Cultivation.stage) and a tribulation guards every major
-- breakthrough; in return they shrug off part of realm suppression when they hit
-- upward: SUPPRESSION_RESIST of the reduction is ignored (half: 0.6 per major
-- instead of 0.2), so they fight above their realm and farm stronger beasts.
Pacing.HeavenDefying = {
	BAR = 1.5,
	SUPPRESSION_RESIST = 0.5,
	-- the player-facing name for the flag (user, 2026-10-24): never "heaven-defying"
	-- in UI text, so it can't be mixed up with a Heaven-grade spirit root
	TITLE = "Defier of Heaven",
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
-- THE 2026-10-24 REBALANCE (owner-approved; docs/systems/pacing-model.md and
-- docs/systems/progression-rules.md): the curve's bars were sized for a bare fighter,
-- but players stack herbs, cores, the garden aura, buffs, the seat, the method and the
-- rest. After the trims (cores, herb floors, the daily offline budget, buff falloff
-- and caps, the aura on your own peak, a lighter seat), these bars are solved by
-- tools/pacing_model.py so the regular profile meets the active targets online
-- (QC 2.4 h, QR 7.1 h, FE 19.8 h). One multiplier per realm, rising, so bars never
-- go down; the hook (QC1-3) keeps its bars. Re-solve (solve_bars) after any change
-- to a lever.
Pacing.Adjust = {
	QC4 = { bar = 1.15 }, QC5 = { bar = 1.15 }, QC6 = { bar = 1.15 }, QC7 = { bar = 1.15 }, QC8 = { bar = 1.15 }, QC9 = { bar = 1.15 },
	QR1 = { bar = 1.65 }, QR2 = { bar = 1.65 }, QR3 = { bar = 1.65 }, QR4 = { bar = 1.65 }, QR5 = { bar = 1.65 }, QR6 = { bar = 1.65 }, QR7 = { bar = 1.65 }, QR8 = { bar = 1.65 }, QR9 = { bar = 1.65 },
	FE1 = { bar = 4.2 }, FE2 = { bar = 4.2 }, FE3 = { bar = 4.2 }, FE4 = { bar = 4.2 }, FE5 = { bar = 4.2 }, FE6 = { bar = 4.2 }, FE7 = { bar = 4.2 }, FE8 = { bar = 4.2 }, FE9 = { bar = 4.2 },
} :: { [string]: Adjust }

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
	OFFLINE_MAX_HOURS = 12, -- offline and AFK cultivation count at most this long A DAY (UTC day), shared by every absence and AFK stretch
	OFFLINE_RATE = 1, -- share of the passive rate while away (and while AFK or secluded online)
	-- AFK online: no input (the client's "awake" pings, Meditate remote) and no active
	-- action for this many seconds, and online cultivation earns exactly what offline
	-- would: the plain passive x OFFLINE_RATE, out of the same daily OFFLINE_MAX_HOURS
	-- budget as offline time (then nothing until the next day). Seclusion counts as AFK
	-- from the start.
	AFK_AFTER = 600,
	AWAKE_PING = 30, -- the client sends "awake" on input at most this often (seconds)
	-- a Lesser Spirit Core is `qiKills` kills of this qiDrop (a spirit wolf's) at the
	-- eater's stage (Realms.enemyQi): it keeps pace with hunting at every stage
	CORE_KILL_QIDROP = 14,
}

-- HERBS: eating a herb whose `eat.qi` is set gives this share of the eater's
-- current stage dantian (Herbs.eatQi), by the herb's tier (I Common, II Spirit, III Rare,
-- IV Treasure, V Heavenly; docs/progression.md "Home, herbs and the loop"). A
-- share, not a flat number, so the garden stays worth it at every stage.
-- Early on a share is tiny (a tier II herb is 16 qi at QC1), so each tier also
-- has a floor in raw qi (about the old flat values). Event herbs (PRIZE, by herb
-- id) replace their tier's share with a bigger one so they stay a prize at any
-- stage. Either way raw qi only fills the room left in the dantian.
-- A herb below the eater's band tier (Herbs.Regions: the region whose stages the
-- eater is in) gives only its floor (Herbs.eatQi): each band's own tier is the
-- garden's qi, and a fast low-tier herb stops scaling once you outgrow it
-- (rebalance 2026-10-24; docs/systems/progression-rules.md).
-- QiRate buffs from different herbs and items stack with falloff: the strongest
-- counts whole, the next BUFF_FALLOFF[2], ... the rest nothing, and the sum stops at
-- BUFF_CAP by the eater's major (Cultivation buffTotal). Every herb's own QiRate is at
-- most its band's cap, so a blurb never promises more than it gives alone.
-- STOCK: seeds of one herb the Herbalist sells a player a day (UTC), by tier; tier
-- III and IV seeds are sold only from their band's first stage (Herbs `soldFrom`).
Pacing.Herbs = {
	EAT_SHARE = { 0.06, 0.09, 0.12, 0.16, 0.2 }, -- by tier, I..V
	EAT_FLOOR = { 60, 150, 900, 3000, 8000 }, -- raw qi at least, by tier (tier II's 150 is about 4 wolves at QC4)
	BUFF_FALLOFF = { 1, 0.5, 0.25 },
	BUFF_CAP = { QiCondensation = 0.2, QiRefining = 0.3, Foundation = 0.5 } :: { [string]: number },
	STOCK = { 30, 12, 3, 2, 0 }, -- seeds of one herb a day, by tier I..V (V is deferred)
	PRIZE = {
		ThousandYearGinseng = 1.0, -- a full dantian (the Thousand-Year Ginseng event)
		RiftLotus = 0.5, -- half a dantian (Heaven Split's wild bloom)
	} :: { [string]: number },
}

-- THE HERBARIUM (server Herbarium; docs/ui/herbarium.md). A herb is discovered the
-- first time it's harvested or gathered; each discovery pays DISCOVER stones by its
-- tier. Discovering every herb of a tier completes its page: TIER stones and a Home
-- foundation experience ("home:book:<tier>"). First guesses (roadmap open question:
-- small stone rewards plus a foundation experience, no cosmetics yet). Tier V's numbers
-- are parked with the deferred herbs (Herbs.Deferred): no tier V page today.
Pacing.Herbarium = {
	DISCOVER = { 15, 40, 120, 300, 800 }, -- Spirit Stones per new herb, by tier I..V
	TIER = { 150, 400, 1200, 3000, 8000 }, -- Spirit Stones for a completed tier page
}

-- MEDITATION multiplies the passive rate while seated (build items on the peak
-- add their BuildItems `meditation` bonus on top of ON_PEAK, the best one in range).
Pacing.Meditation = {
	ANYWHERE = 1.5,
	ON_PEAK = 2.5, -- on your own spirit peak
}

-- THE GARDEN AURA (Cultivation.aura; docs/systems/garden.md "Aura"). Every plant in
-- your plots radiates spirit energy into your abode: BY_TIER[tier] x RARITY[rarity]
-- x its size x its mutations, GROWING of that while it grows, all of it once mature.
-- Summed over every planted herb, so a fuller, rarer garden is always more, up to CAP
-- by your peak tier (your major). It multiplies MEDITATION ON YOUR OWN PEAK only
-- (x (1 + aura)), never fighting or meditating elsewhere.
-- DECORATE YOUR ABODE: the peak score lifts the cap, by up to DECOR of it at the
-- tier's scoreCap (Config.Build.TIERS): a decorated abode holds more spirit energy.
-- One mature Legendary tier III herb is +0.3 (the whole QC cap), a Legendary tier IV
-- +0.6 (the QR cap); a full tier III-IV garden fills the FE cap.
Pacing.Aura = {
	BY_TIER = { 0.02, 0.05, 0.15, 0.3, 0.6 }, -- I..V
	RARITY = { Common = 1, Uncommon = 1.1, Rare = 1.25, Epic = 1.5, Legendary = 2 } :: { [string]: number },
	CAP = { QiCondensation = 0.3, QiRefining = 0.6, Foundation = 1.0 } :: { [string]: number },
	GROWING = 0.5, -- a growing plant's share of its mature aura
	DECOR = 0.25, -- the cap rises by up to this share at the peak tier's score cap
}

-- SECLUSION (server Seclusion; docs/systems/seclusion.md): the AFK mode, entered from
-- the meditation seat on your own peak. Cultivation runs at the AFK rate (the plain
-- passive, Income above) and never breaks through; seclusion pays its own rewards
-- instead, online and offline alike (a logout while secluded keeps it going) up to
-- MAX_HOURS. The garden's mutation roll isn't seclusion's: it rolls while the owner
-- stays online on their own peak, secluded or not, never offline. No foundation experiences. Leaving (rising, being hit, logging back in)
-- shows the result card.
Pacing.Seclusion = {
	MAX_HOURS = 12, -- rewards stop counting after this long in one seclusion (as offline)
	-- Spirit Stones an hour, by major (a slow trickle: a QC wolf drops about 4.5)
	STONES_PER_HOUR = { QiCondensation = 25, QiRefining = 60, Foundation = 150 } :: { [string]: number },
	-- the garden is tended: growing plants grow this much faster (0.5 = +50%), online and offline
	GROWTH = 0.5,
	-- the garden's online roll (server Garden, while the owner stands on their own peak,
	-- secluded or not; never offline): each plant's chance an hour to take one of these
	-- mutations (by weight)
	MUTATION_PER_HOUR = 0.03,
	MUTATIONS = { Dewy = 50, Windswept = 30, Auspicious = 15, Golden = 5 } :: { [string]: number },
	-- each full hour: this chance of a rare find, by weight: a treasure, or a seed of
	-- the player's major's next herb tier (never root pills)
	RARE_CHANCE = 0.1,
	RARE = { HeavenlyDew = 50, CloudPatternJade = 25, ImmortalPeach = 5, Seed = 60 } :: { [string]: number },
	SEED_TIER = { QiCondensation = 2, QiRefining = 3, Foundation = 4 } :: { [string]: number },
	-- the streak: days with a seclusion of at least STREAK_MIN_HOURS (a missed day
	-- pauses it, never resets it); each day past the first adds STREAK_BONUS to the
	-- stones (up to STREAK_MAX days)
	STREAK_MIN_HOURS = 1,
	STREAK_BONUS = 0.1,
	STREAK_MAX = 7,
	-- the result card shows only after this long in seclusion (or for the first one);
	-- a shorter one rises with a small "+N Spirit Stones" line (user, 2026-10-24)
	CARD_MIN_MINUTES = 10,
	-- the first seclusion (the onboarding's Seclusion lesson) ends by itself after
	-- FIRST_SECONDS with a generous card: FIRST_STONES, FIRST_SEEDS, a FIRST_BAR share
	-- of the bar as cultivation (never past the bar) and FIRST_GROWTH seconds on every
	-- growing plant (the seed planted for Home is ready when the player opens their eyes)
	FIRST_SECONDS = 45, -- 30-60 s (user, 2026-10-24): a taste, offered in the second session
	FIRST_STONES = 60,
	FIRST_SEEDS = { CloudMint = 2 } :: { [string]: number },
	FIRST_BAR = 0.25,
	FIRST_GROWTH = 300,
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
	MEDITATION = 0.0024, -- meditation multiplier per point (QR cap 150: +0.36, FE cap 250: +0.6 on ON_PEAK); the score also lifts the aura cap (Pacing.Aura.DECOR)
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
	CARRY_SHARE = 0.5, -- the whole overflow carries (it is at most 0.5 of a bar, and bars never go down), so AFK hours past the bar are never wasted
	-- the breakthrough card (client BreakthroughView) shows only for a major, a stage
	-- that opens an array or brings the foundation, or one that took at least this
	-- long since the last breakthrough (or the join); quicker ones get a small line
	-- (user, 2026-10-24: like seclusion's CARD_MIN_MINUTES)
	CARD_MIN_MINUTES = 10,
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
	-- the first boss kill's manual is one usable now: the held weapon class's best art
	-- the player's Dao reaches, else a starter art they lack (Progression firstBossManual);
	-- this only when they already have every one of those
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
-- PARTIES (server Party.luau, docs/systems/party.md): server-local groups of up to
-- MAX_SIZE. A party is never required: it adds a small qi bonus and lets nearby
-- members who didn't earn the kill still share in its qi.
-- SAFE ZONES (server SafeZone.luau): the sect's grounds and every spirit peak.
Pacing.SafeZone = {
	TESTBED_RADIUS = 24, -- testbed: studs from the spawn pad that count (the TestPeak sits there)
}

Pacing.Party = {
	MAX_SIZE = 4,
	INVITE_SECONDS = 30, -- an unanswered invite lapses after this
	INVITE_COOLDOWN = 2, -- seconds between invites from one player (spam guard)
	RADIUS = 120, -- studs: "nearby" for the kill share, the group bonus and stats.partied
	-- qi for a helper who didn't earn the kill (Rewards KILL_SHARE): a party member
	-- within RADIUS of it, or anyone who hit it for less than the share. A share
	-- of their own realm-scaled qi for the beast; no stones, drops or kill count.
	HELPER_QI_SHARE = 0.5,
	BONUS_PER_MEMBER = 0.05, -- beast qi per other party member within RADIUS of the kill
	BONUS_CAP = 0.15,
	PUSH_SECONDS = 1, -- how often members' health and nearness are re-sent (only on change)
}

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
	-- lessons (met later, when each first matters; one per chapter)
	RootPill = { stones = 20 },
	Home = { stones = 30 }, -- QC4
	Seclusion = { stones = 20 }, -- the second session (or QC5): its own card pays more, Pacing.Seclusion FIRST_*
	Rumours = { stones = 40 }, -- QC5, the Borderlands' hidden caches
	Herbs = { stones = 20 }, -- QC6
	DaoPractice = { stones = 50 }, -- QC7
	HeartDemon = { stones = 50 }, -- QC9
	Bottleneck = { stones = 40 },
	WeaponRack = { stones = 30 }, -- QR1
	Build = { stones = 30 }, -- QR2
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
	FROM = "QC7", -- the stage it unlocks (user, 2026-10-23: back at QC7; class skills need Dao, and the gardener road needs a way to raise it)
	RACK_FROM = "QR1", -- the second-weapon lesson (QR, docs/roadmap.md section 2)
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
-- for SPILL_SECONDS (a second death merges into it); leaving while combat-tagged
-- spills the same share where they stood, kept for a join within KEEP_SECONDS.
-- Finds at or above SAFE_RARITY bank the moment they're picked up, and the
-- spirit ring keeps RING_SLOTS whole stacks banked even in the wilds.
Pacing.Haul = {
	SPILL_SHARE = 0.5, -- of each unbanked amount, rounded to the nearest whole
	SPILL_SECONDS = 300, -- the spill waits this long, then it's gone
	KEEP_SECONDS = 2 * 3600, -- a spill unclaimed at logout (combat-leave or death) waits this long for the next join, then SPILL_SECONDS from it
	RECLAIM_RADIUS = 7, -- studs from the spill that pick it back up
	SAFE_RARITY = 4, -- Items.Rarities order (4 Epic, 5 Legendary): banks on pickup
	RING_SLOTS = { QiCondensation = 2, QiRefining = 3, Foundation = 4 } :: { [string]: number }, -- by major realm
	CHECK_SECONDS = 0.5, -- how often banking, the ring and the spill are checked
}

-- SPIRIT ROOTS (Roots.luau, server Roots; docs/character/spirit-root.md). A root's
-- element is rolled once at the Testing Stone; its grade starts at STARTING_GRADE
-- for everyone and is raised by rare items. Grade multiplies passive and refining
-- speed and the element's perks. Perks are kept small so no element is "the best",
-- and the rare elements (4%, 3%, 3%) are worth at least as much as the common ones
-- (user, 2026-10-24): a main perk plus a BONUS.
Pacing.Roots = {
	-- roll weights (percent)
	ODDS = { Fire = 18, Water = 18, Wood = 18, Metal = 18, Earth = 18, Lightning = 4, Wind = 3, Ice = 3 } :: { [string]: number },
	STARTING_GRADE = "Spirit",
	-- per grade: cultivation speed (passive and refining) and perk strength.
	-- Immortal is the rare top step above Heaven (user, 2026-10-24: more steps,
	-- Earth and Heaven keep their names)
	GRADES = {
		Spirit = { speed = 1.0, perk = 1.0 },
		Earth = { speed = 1.1, perk = 1.5 },
		Heaven = { speed = 1.25, perk = 2.0 },
		Immortal = { speed = 1.4, perk = 2.5 },
	} :: { [string]: { speed: number, perk: number } },
	-- each element's main perk at perk strength 1 (Roots.Elements says what kind it is)
	PERKS = {
		Fire = 0.08, -- share added to technique damage
		Water = 0.02, -- share of max health healed per second out of combat
		Wood = 0.25, -- share added to herb growth speed (while online)
		Metal = 0.08, -- share added to weapon strike (M1) damage
		Earth = 0.10, -- share added to max health
		Lightning = 3, -- studs/s added to walk speed
		Wind = 0.20, -- share added to jump height
		Ice = 0.08, -- share cut from damage taken
	} :: { [string]: number },
	-- the rare elements' second perk, by perk kind (Roots.Perk), at perk strength 1:
	-- each rare root gets a common root's whole perk on top of its own
	BONUS = {
		Lightning = { technique = 0.06 }, -- a lightning strike: techniques hit harder
		Wind = { strike = 0.06 }, -- a wind blade: weapon strikes hit harder
		Ice = { health = 0.06 }, -- an ice shell: more health
	} :: { [string]: { [string]: number } },
	MATCH = 0.15, -- share added to techniques of your root's element
	-- Marrow Washing Pills absorbed to reach each grade from the one below (kept
	-- per element in root.washed). Pills are boss and treasure drops at a few
	-- percent (Enemies drops, Items treasureWeight), so Earth is a long hunt and
	-- Heaven (3 + 5 = 8 pills) is a Foundation-and-beyond goal (user, 2026-10-23:
	-- "should be hard to get one"); Immortal (8 more) is the rare top
	WASH = { Earth = 3, Heaven = 5, Immortal = 8 } :: { [string]: number },
	-- PITY FRAGMENTS (user, 2026-10-24; server Roots.fragment, root.fragments): a boss
	-- kill (Enemies `boss`) or a claimed heavenly treasure that gives no root pill
	-- gives one Marrow Washing fragment, and at REBIRTH_CHANCE a Root Rebirth
	-- fragment too. PER_PILL fragments of a kind combine into its pill on their own.
	-- The Sect Pavilion also sells them (Pacing.Sect.FRAGMENTS). Never for Robux.
	FRAGMENTS = {
		PER_PILL = 10,
		REBIRTH_CHANCE = 0.25,
		PILLS = { "MarrowWashingPill", "RootRebirthPill" },
	},
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

-- BEAST VARIANTS (Enemies.variant; docs/systems/enemies.md "Realm variants"). One def,
-- many strengths: a spawn can set a beast's realm (Spawns zones and ambient packs) and
-- it follows the curve there (health by player power, damage by player health, from
-- BeastBaseline at its own realm to the spawn's), so a same-stage player needs as many
-- hits and takes as large a share of health as at the def's own realm. The stage GAP
-- (spawn realm minus the def's realm) also picks a TIER, which adds small steps on top:
--   name     prefix on the bar ("" = the plain name)
--   at       the smallest gap that reaches the tier (young: anything below adult)
--   size     body, hit volume, reaches and telegraph areas (dash speeds too, so a dash
--            takes as long and its poses stay in time)
--   speed    walk, run and circling speed
--   cadence  multiplies cooldowns and notBefore (lower = attacks come more often).
--            Windups and recovers never change: tells stay readable, punish windows stay.
--   health   on top of the realm scaling (more hits to kill)
--   damage   on top of the realm scaling
--   reward   qiDrop and Spirit Stones
--   tint     body colour lerped toward (Neon, Tell and Eye parts keep theirs), by tintAmount
-- Apex is also any variant a major realm above the def's own. Which moves each tier has
-- is per def (Enemies attack `minTier`, `tiers` overrides). Bosses never take variants.
Pacing.Variants = {
	ORDER = { "young", "adult", "elite", "apex" },
	TIERS = {
		young = { name = "Young", at = -math.huge, size = 0.85, speed = 0.9, cadence = 1.25, health = 0.8, damage = 0.85, reward = 1, -- full pay: the onboarding's gate wolves are young
			tint = Color3.fromRGB(236, 230, 214), tintAmount = 0.2 },
		adult = { name = "", at = 0, size = 1, speed = 1, cadence = 1, health = 1, damage = 1, reward = 1 },
		elite = { name = "Elite", at = 3, size = 1.12, speed = 1.08, cadence = 0.88, health = 1.25, damage = 1, reward = 1.6,
			tint = Color3.fromRGB(38, 30, 52), tintAmount = 0.25 },
		apex = { name = "Apex", at = 6, size = 1.25, speed = 1.15, cadence = 0.8, health = 1.5, damage = 1.05, reward = 2.4,
			tint = Color3.fromRGB(58, 12, 22), tintAmount = 0.35 },
	} :: { [string]: { name: string, at: number, size: number, speed: number, cadence: number, health: number, damage: number, reward: number, tint: Color3?, tintAmount: number? } },
	-- ambient packs with a realm range lean deeper the farther the encounter is into its
	-- region (Regions `depth`), give or take this many stages at random
	AMBIENT_SPREAD = 1,
}

-- FOUNDATION (server Foundation; docs/systems/cultivation.md "Foundation grade").
-- Experiences earned while at a stage are weighed against the stage's TARGET at the
-- breakthrough out of it, as a percent: 100% is a full foundation, more experiences
-- go past it up to MAX_PERCENT (at OVER_COST times the price). Each graded stage adds BONUS_TO_FULL by 100% and BONUS_PAST_FULL more by MAX_PERCENT
-- to max health and power (always positive: 80% is a good breakthrough, just a bit
-- less), summed over all stages as its own multiplier on top of Pacing.Curve (about
-- +92% at most by FE9, 23 graded stages QC4-FE8, below a major jump). Players only ever see
-- the percent (owner, 2026-10-24: no grade words). Experiences come from per-region pools (the realm band's region,
-- Herbs.Regions) plus per-stage deeds, so every stage has fresh ones.
-- Time fills the bar, not the foundation. Untuned first guesses.
--
-- TARGETS AND THEIR SOURCES (a stage's 100%; the pools are shared by the band's stages,
-- so a band's first stage gets the most and the deeds (4 a stage) are the floor).
-- Solved with tools/pacing_model.py --foundation (rebalance 2026-10-24; OVER_COST raised
-- to 5 the same day, owner: "if foundation is too easy, then raise the bar") for medians
-- of about 97% (casual), 110% (regular) and 112% (heavy), 130%+ on 1 / 3 / 7 stages:
--   QC1-3   none   the hook has no foundation (FROM): nothing earned, graded or shown,
--                  so the first breakthroughs never read as a failure
--   QC4-9   4      Inner Wilds and Borderlands pools: the QC beasts, Jade Jiao and the
--                  Elder Wolf King (2 each), tier I harvests, mutations, the tier I
--                  Herbarium page, Dao levels, caches, events and treasures, the deeds
--   QR1-FE9 2.5    Outer Wastes, Deep Wilds and Far Reaches bands: tier II-IV harvests and
--                  pages, mutations, events and treasures again, the bosses, Dao, the deeds
-- CARRY: experiences past what MAX_PERCENT needs carry into the next stage's count
-- (Foundation.seal), so a band's front-loaded pool spreads over its stages.
-- With Config.Wilds.VARIANTS off (the main map today) QR and FE have no beasts at their
-- realm, so the Hunter and Daring deeds and the hunts there wait on variants (hence
-- their lower target; raise it toward QC's when variants ship).
Pacing.Foundation = {
	-- what one experience of each category counts for
	WEIGHTS = { Hunt = 1, Boss = 2, Home = 1, Dao = 1, Discover = 1, World = 1, Deed = 1 } :: { [string]: number },
	-- experiences per stage for 100%; a stage missing here gets DEFAULT_TARGET
	FROM = "QC4", -- the first stage with a foundation; the hook (QC1-3) has none
	TARGET = {
		QC4 = 4, QC5 = 4, QC6 = 4, QC7 = 4, QC8 = 4, QC9 = 4,
	} :: { [string]: number },
	DEFAULT_TARGET = 2.5, -- Qi Refining and Foundation Establishment (no same-realm beasts there while variants are off)
	MAX_PERCENT = 150, -- the hidden road tops out here (user, 2026-10-24: hidden tasks "can get u up to 130 or 140")
	-- 100% is meant to be easy (user, 2026-10-24: "break through at 100 percent should be
	-- easy to reach... players should have to grind crazy hard so they get the real, extra
	-- bonuses"): past the target each percent costs OVER_COST times as many experiences
	-- (150% takes target x 3.5), and most of the bonus lives past 100%. 3 let the regular
	-- reach 130%+ on half its stages; 5 leaves 130%+ to band-entry stages and the heavy.
	OVER_COST = 5,
	-- past this percent the open experiences stop being listed: the rest are found, not
	-- read (user, 2026-10-24: "the tasks u do past 110 or 120 percent are hidden")
	HIDDEN_FROM = 110,
	BONUS_TO_FULL = 0.01, -- share of max health and power at 100% (linear from 0)
	BONUS_PAST_FULL = 0.02, -- added from 100% to MAX_PERCENT (linear): 150% is +3% a stage
	-- below this percent the stage is unsteady: the once-a-stage toast when the bar
	-- fills, and a heaven-defier's tribulation strikes UNSTEADY_TRIBULATION harder
	UNSTEADY_BELOW = 50,
	UNSTEADY_TRIBULATION = 1.2,
	-- tempering (the heart-demon trial): each step raises one old stage this many points,
	-- the lowest first, never past TEMPER_MAX
	TEMPER_POINTS = 25,
	TEMPER_MAX = 150,
	-- profiles sealed before percents stored a word: what each word reads as
	LEGACY = { Cracked = 25, Steady = 60, Solid = 100, Deep = 150 } :: { [string]: number },
	MUTATION_BONUS = 1, -- a harvest mutation counts as rare (Home) from this Herbs.Mutations bonus up
	EVENT_RADIUS = 150, -- studs from a located world event that count as taking part
	-- a kill is an experience only from a beast at most this many stages below the player
	-- (so a later realm can't farm the young beasts of the first region)
	FIT_BELOW = 3,
	HINTS = 5, -- open experiences listed in the PlayerState push
	HINT_BELOW = 3, -- beasts suggested from this many stages below the player...
	HINT_ABOVE = 2, -- ...to this many above (bosses too, as "the fast road")
	-- Deeds: repeatable once per stage (reset at the breakthrough), each worth WEIGHTS.Deed.
	-- Each asks for range, not repetition.
	DEEDS = {
		-- slay `kills` beasts at most `below` stages under you; only `perKind` of one beast count
		Hunter = { kills = 10, perKind = 4, below = 2 },
		-- slay a beast (or boss) at least `above` stages over you
		Daring = { above = 2 },
		-- harvest `kinds` different herbs
		Gardener = { kinds = 3 },
		-- one Store all banking at least `share` of the dantian in raw qi
		Haul = { share = 0.75 },
	},
	DEED_ORDER = { "Hunter", "Gardener", "Haul", "Daring" },
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
	SECLUDED_MIN_HOURS = 8, -- hours in seclusion (online and offline) before it's a question
	SURGE_MIN = 1, -- qi surges (plus old forced breakthroughs) before the surge is a question
	DANGER_MIN = 3, -- elite kills + apex kills x2 before the danger sought is a question
	HAUL_LOST_MIN = 2, -- spills + mid-fight logouts before greed is a question
	HAUL_LOST_WEIGHT = 4, -- greed only while lost x this is at least the Store all count
	HAUL_STORED_MIN = 5, -- Store all uses, with nothing ever lost, before caution is a question
	BUILD_MIN = 10, -- build pieces placed before the builder question
	WANDER_MAX = 2, -- pieces placed at most (with SLAIN_MIN kills) for the wanderer question
	HERB_MIN = 5, -- herbs in the Herbarium before it's a question
	ROOT_MIN = 1, -- root pills (washing + rebirth) before chasing a better self is a question
	DUTY_MIN = 10, -- sect dailies claimed before the dutiful-disciple question
	LONE_MAX = 1, -- dailies claimed at most (the board open to them) for the lone-wolf question
	WEIGHT_CAP = 4, -- the loudest a record question can weigh (1 at its threshold, +1 per doubling)
	SOLITARY_MAX_MINUTES = 2, -- under this many minutes partied (stats.partied): "you never walked with another"
	COMPANY_MIN_MINUTES = 30, -- from here: "you walked beside others" (between: no question)
	OFFER_COOLDOWN = 20 * 3600, -- seconds after "Not now" before the seat offers it again
}

-- THE SECT (server Sect; docs/systems/sect.md). The MVP: rank, contribution, the
-- board's dailies, one chapter chain and the Pavilion. Every number here is a first
-- guess (2026-10-23), a proposal for the user to tune in play.
-- Contribution is earned by dailies, chain steps and promotions and spent at the
-- Pavilion; rank goes by contribution EARNED (lifetime), so shopping never costs a
-- promotion. The weekly cap applies to dailies only (the chain and promotions are
-- finite). Never qi, never whole root pills (roadmap 3): root pill fragments only,
-- a few a week (FRAGMENTS).
Pacing.Sect = {
	OPENS = "QC5", -- the board's dailies and the chain start here (pointed at by the QC5 Rumours lesson's talk); the testbed opens it at any realm
	-- ranks in order: the realm and lifetime contribution a promotion needs, and what it pays
	RANKS = {
		{ id = "Outer", name = "Outer Disciple" },
		{ id = "Inner", name = "Inner Disciple", realm = "QR1", earned = 600, stones = 300 },
		{ id = "Core", name = "Core Disciple", realm = "FE1", earned = 2500, stones = 1500 },
	} :: { { id: string, name: string, realm: string?, earned: number?, stones: number? } },
	WEEK_CAP = 700, -- contribution from dailies and sheltering (Pacing.Shelter.CONTRIBUTION) per week (Monday 00:00 UTC); about six days of all three
	OFFERED = 3, -- dailies on the board each day (reset at 00:00 UTC, like the daily login)
	COMBAT_MAX = 1, -- at most this many combat dailies among them: the rest are peaceful
	COMBAT_CHANCE = 0.65, -- the chance a day's offer includes one
	-- Spirit Stones a daily pays, by major, times its kind's `stones` share
	DAILY_STONES = { QiCondensation = 40, QiRefining = 110, Foundation = 300 } :: { [string]: number },
	-- the daily pool: contribution, stone share, goal by major (nil: 1), and combat
	DAILIES = {
		hunt = { contribution = 40, stones = 1, goal = { QiCondensation = 8, QiRefining = 10, Foundation = 12 }, combat = true },
		herbs = { contribution = 40, stones = 1, goal = { QiCondensation = 6, QiRefining = 6, Foundation = 6 } },
		gather = { contribution = 30, stones = 0.75, goal = { QiCondensation = 3, QiRefining = 4, Foundation = 4 } },
		seclusion = { contribution = 40, stones = 0.75, goal = { QiCondensation = 3600, QiRefining = 3600, Foundation = 3600 } },
		store = { contribution = 25, stones = 0.5 },
		harvest = { contribution = 30, stones = 0.75, goal = { QiCondensation = 4, QiRefining = 6, Foundation = 8 } },
		cache = { contribution = 60, stones = 1.5 },
	} :: { [string]: { contribution: number, stones: number, goal: { [string]: number }?, combat: boolean? } },
	HUNT_BELOW = 2, -- a hunt counts beasts at most this many stages below the player's (realm variants)
	HERB_TIER = { QiCondensation = 1, QiRefining = 2, Foundation = 3 } :: { [string]: number }, -- the herb errand's tier
	-- the chapter chain's steps pay this (contribution, stones); the last step pays FINAL
	CHAIN = { contribution = 60, stones = 60 },
	CHAIN_FINAL = { contribution = 150, stones = 200 },
	PLACE_RADIUS = 50, -- studs (flat) from a chain step's place that count as there
	-- the Pavilion's stock (contribution prices). Seeds by tier (a packet: `seeds` of a
	-- random sold herb of that tier), the spirit ring's +1 slot (once per major, by
	-- major), the kill-milestone manuals as copies (only while not owned or held).
	-- `rank` is the least rank that may buy it.
	SEEDS = {
		{ tier = 1, seeds = 4, cost = 40, rank = "Outer" },
		{ tier = 2, seeds = 3, cost = 150, rank = "Inner" },
		{ tier = 3, seeds = 2, cost = 450, rank = "Core" },
	} :: { { tier: number, seeds: number, cost: number, rank: string } },
	RING_SLOT = { QiCondensation = 200, QiRefining = 500, Foundation = 1200 } :: { [string]: number },
	MANUALS = { FireSeal = 60, SwordQiWave = 100, IronSkin = 150, MoonflashDraw = 200, PalmStrike = 250 } :: { [string]: number },
	MANUAL_ORDER = { "FireSeal", "SwordQiWave", "IronSkin", "MoonflashDraw", "PalmStrike" },
	-- root pill fragments (Pacing.Roots.FRAGMENTS; user, 2026-10-24: the gardener's road
	-- to a better root): contribution each, at most `week` of each kind a week (Monday
	-- 00:00 UTC, the dailies' week). 3 Marrow a week is about 300 of the ~700 a week of
	-- dailies pay, and a pill every ~3.5 weeks from the Pavilion alone
	FRAGMENTS = {
		MarrowWashingPill = { cost = 100, week = 3 },
		RootRebirthPill = { cost = 80, week = 2 },
	} :: { [string]: { cost: number, week: number } },
	-- bonus quests (docs/systems/sect.md "Bonus quests"): teach the party shelter by doing
	-- it. Offered only while someone of the right major is on the server (the testbed:
	-- always), at most one taken at a time, each claimable once a day. `from` the least
	-- stage; `goal` sheltered kills; contribution (inside WEEK_CAP) and the DAILY_STONES
	-- share on claim; `junior` the DAILY_STONES share (at the junior's major) each junior
	-- who helped gets when an escort completes
	BONUS = {
		escort = { from = "QR1", goal = 5, contribution = 50, stones = 1, junior = 0.5 },
		senior = { from = "QC5", goal = 3, contribution = 30, stones = 0.75 },
	} :: { [string]: { from: string, goal: number, contribution: number, stones: number, junior: number? } },
}

return Pacing
