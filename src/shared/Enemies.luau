--!strict
-- Enemy definitions for wilds ring 1. All enemy balance numbers live here.
-- Every attack that hurts is telegraphed on the ground first:
--   lunge   a short line in front (box), then a quick dash along it
--   charge  a long lane (box), then a fast charge down it
--   spit    a circle on the target's position
--   cone    a wide cone in front (bite)
--   slam    a circle around the attacker
--   summon  no area; calls `count` more of `summons` to its side
--   leap    a circle on the target's ground, then the beast flies there over
--           `active` seconds and the circle resolves as it lands
--   howl    no area, no damage: calls packmates within `radius` onto its target
--   lance   a long lane (box) hit all at once when the windup ends (no dash)
--   bound   no telegraph, no damage: hops to a flank spot `landMin`-`landMax` studs from
--           the target over `active` seconds (arc is client-only); with `boundModes`, a
--           landing mode each time (over, flank, back, short; EnemyService startBound)
--   barrage Nine-Tailed Fox: timed sub-areas computed at the windup's start from where the
--           target stands (`barrage` names the pattern: fangs, lance, lanceFan, snare,
--           volley, ringHeart, spiral; EnemyService buildParts), each hitting `delay`
--           seconds after the windup. Sent to clients as Telegraph shape "multi"
--   retreat no hit of its own: a backflip `distance` studs straight away over `active`
--           seconds (arc is client-only) leaving a three-tick fire trail (`trailScale`
--           of `damage` per tick, `width` wide)
--   storm   `bolts` lightning strikes after the windup, each a circle on where the target
--           stands `boltInterval` apart, hitting `boltWindup` later (`damage` per bolt)
-- Lunges and charges hit each player when the dash front reaches them, not when
-- the windup ends, so the blow lands as the beast arrives. With Config.Wilds.WEIGHTED_MOVES
-- a lunge, charge, leap or bound can end in an `arrive` follow-up (started on arrival when
-- the target is in its range and in front) or a `skid` round to face the target.
-- Regular beasts with `attacks` pick from that pool each time (in order: the
-- first whose range band holds the target and whose own cooldown is up), open
-- every engagement with `attack`, and may howl, hop back and circle (`pack`).
-- Every non-boss beast takes an attack slot on its target first
-- (Config.Wilds.ATTACK_SLOTS / SLOT_GAP), so a pack takes turns; bosses opt in
-- with shareTurns. A thresholdOnly summon stays out of the normal rotation.
-- qiDrop is raw qi at QC1; it scales with the receiving player's dantian
-- (Realms.enemyQi, Pacing.Income.ENEMY_QI_EXPONENT).
-- drops: items (Items.luau) each damager may get on a kill, rolled separately.
-- bossDrops (bosses): a pool of technique manuals and weapons. Each kill rolls
-- `chance` (the first kill of the boss always rolls) and grants one entry the
-- player doesn't own yet, picked at random (Progression.luau).
-- realm: the demon beast's cultivation, on the same ladder as players (Realms.luau).
-- weight: how hard it is to shove (1 = a wolf). Realm and weight together set how
-- far player hits knock it back (Knockback.luau).

export type Attack = {
	kind: string, -- "lunge" | "charge" | "spit" | "cone" | "slam" | "summon" | "leap" | "howl" | "lance" | "bound" | "storm" | "barrage" | "retreat" | "guard"
	name: string?, -- shown to clients as the model's Attack attribute (default: kind); name it when one beast has two of a kind
	damage: number,
	range: number, -- start the attack when the target is this close
	windup: number, -- seconds the telegraph shows before it resolves
	recover: number, -- seconds after resolving before moving again
	cooldown: number, -- seconds between attacks
	length: number?, -- box: how far it reaches
	width: number?, -- box: how wide
	radius: number?, -- circle
	offset: Vector3?, -- slam: ground centre in facing-local studs (negative Z is forward)
	dashSpeed: number?, -- lunge/charge: studs per second along the box
	angle: number?, -- cone: degrees
	summons: string?, -- summon: enemy id; howl: the reinforcements it calls when it rallies nobody
	count: number?, -- summon: how many (howl: the fewest reinforcements)
	countMax: number?, -- howl: the most reinforcements (a random count from count to countMax)
	maxAlive: number?, -- summon: skip if this many summons are still alive
	minRange: number?, -- attack pools: only start it when the target is at least this far
	notBefore: number?, -- attack pools: not until this many seconds into an engagement
	active: number?, -- leap: flight seconds (the hit lands at the end)
	arc: number?, -- leap: studs the body rises mid-flight (client only)
	hopAfter: boolean?, -- attack pools: hop back once it recovers
	followUp: string?, -- attack pools: this attack's name starts as soon as it recovers, if the target is in its range
	stopPast: number?, -- lunge/charge: dash only to this many studs past the target (between minRange and length; negative stops short)
	-- lunge/charge/leap/bound (WEIGHTED_MOVES): an attack started the moment the dash or leap
	-- arrives, if the target is within its `range` and at most ~100 degrees off the nose
	-- (its windup turns into it). Also list it in the pattern or pool with chainOnly, so
	-- clients find its timing.
	arrive: Attack?,
	-- lunge/charge/leap (WEIGHTED_MOVES): on arrival with no follow-up to start, skid round
	-- to face the target over the recover (AttackName `<name>Skid`). With `arrive`: when it
	-- misses; without: when the target ends up more than ~60 degrees off the nose.
	skid: boolean?,
	-- bound: landing modes (EnemyService startBound), each with its flight seconds and arc
	boundModes: { [string]: { active: number, arc: number } }?,
	rangedNext: { string }?, -- rotating bosses: after this attack, only these until one fires (or rangedWait passes)
	rangedWait: number?, -- seconds past the recover that rangedNext holds (default 2.5)
	telegraph: string?, -- "heavy": the stronger telegraph tier (telegraphs.md)
	barrage: string?, -- barrage: the pattern name (see the kind list above)
	ring: number?, -- ringHeart: radius of the eruption ring round the target
	heartRadius: number?, -- ringHeart: the centre circle's radius
	finalRadius: number?, -- spiral: the circle under the beast at the end
	distance: number?, -- retreat: studs it flips away
	trailScale: number?, -- retreat: damage share of each fire-trail tick
	pull: { distance: number, seconds: number }?, -- barrage part with `snare`: yanks a hit player to this far from the beast
	hitStun: { kind: string, seconds: number }?, -- barrage parts flagged `stun`: PlayerStun.apply on hit players
	recoverP3: number?, -- barrage: recover seconds in phase 3 (its parts run longer)
	followUpOnHit: string?, -- barrage: this attack follows only if a snare caught someone
	thresholdOnly: boolean?, -- boss pattern: kept here for poses/cues, called only by summonAt
	react: string?, -- "flinch" | "stagger" | "stun": the reaction a landed hit causes (default: see Config.Combat.CC.HEAVY_KINDS)
	reactSeconds: number?, -- stagger/stun length for `react` (default: the kind's)
	knock: number?, -- studs a landed hit shoves the player away (default: the beast's `knock`; 0 = none)
	stun: { kind: string, radius: number, seconds: number?, onHit: boolean?, secondsP3: number? }?, -- on resolve, PlayerStun.apply("stagger" | "stun") to players in the circle (shown as its own telegraph)
	-- Jade Jiao kinds (BossAttacks.luau): "bolt" (fast venom lanes), "pools" (circles that leave
	-- poison pools), "burrow" (dive underground along a lane, no damage), "coil" (trap ring)
	poison: { stacks: number, seconds: number }?, -- a landed hit adds poison stacks (PlayerPoison)
	-- guard (Stone Tortoise shellGuard): no damage; hunkers down for `hold` seconds (AIState dash,
	-- model attributes Guarding + GuardReduction) while player hits do (1 - `reduction`) of
	-- their damage and shove nothing (Combat.damageEnemy); its `arrive` follow-up snaps out of
	-- the hold if the target is in its range and in front, else it recovers
	reduction: number?,
	-- lunge (Shadow Mane shadowStep): the lane ends this many studs beside the target, approached
	-- 60 degrees off the line to it on a random side, so the beast comes in on a flank instead of
	-- through the target; an `arrive` rake follows
	flankPoint: number?,
	-- lunge/charge: studs the hit box runs past the dash's end, for a head or muzzle that leads
	-- the root (the serpent's strike); the telegraph shows it too
	reach: number?,
	-- Third wave: `leech` heals the beast this share of the damage a landed hit dealt (the bat);
	-- `slot` takes an attack slot even with no damage (the bat's shriek); `slow` slows a player a
	-- landed hit catches (PlayerSlow); `patch` (spit) leaves a lingering circle at the landing for
	-- `seconds`, poisoning it ("poison") or slowing it ("slow" with `slow`), drawn by EnemyFX `patch`;
	-- `perch` (a dash/charge) lowers the beast's root that many studs for the recover, so a flier's
	-- hit volume follows it down after a dive
	leech: number?,
	slot: boolean?,
	slow: { factor: number, seconds: number }?,
	patch: { seconds: number, effect: string, slow: { factor: number, seconds: number }?, radius: number? }?,
	perch: number?,
	lanes: { number }?, -- bolt: lane angles in degrees from the target direction (default { 0 })
	boltSpeed: number?, -- bolt: studs per second the front travels (a hit lands as it arrives)
	strikes: { { at: number, radius: number, angle: number } }?, -- cone: follow-up cones `at` seconds after the first, re-aimed
	flank: number?, -- pools: studs either side of the target the two extra circles sit
	poolSeconds: number?, -- pools: how long each circle stays as a poison pool
	unburrow: boolean?, -- surfaces the beast (clears its Burrowed attribute) when it resolves
	coilRadius: number?, -- coil: the ring's centreline radius (the telegraph circle is `radius`)
	hold: number?, -- coil: seconds from the ring forming (after the dash) to the squeeze
	holdP3: number?,
	halfAngle: number?, -- coil: half width in degrees of the door gap
	halfAngleP3: number?,
	squeezeDamage: number?, -- coil: damage at the squeeze to anyone inside the ring and outside the gap
	dashMin: number?, -- a dash lasts at least this long
	mouth: number?, -- bolt: studs from the root centre to the mouth (the lanes start there)
	mouthHeight: number?, -- bolt: how high the mouth is above the ground
	boltName: string?, -- storm: the name its circles' telegraphs carry (default "stormBolt")
	-- Thunder Ape kit
	phase: number?, -- rotating bosses (`rotate`): the lowest phase that uses this attack
	chainOnly: boolean?, -- rotating bosses: only started as another attack's followUp
	phaseStep: boolean?, -- resolving this attack moves the boss to its next phase (Phase attribute)
	landMin: number?, -- bound: nearest and farthest landing from the target
	landMax: number?,
	bolts: number?, -- storm: strikes (`boltsP3` from phase 3)
	boltsP3: number?,
	boltWindup: number?,
	boltInterval: number?,
	boltRadius: number?,
	-- slam: a second ring from the same centre `delay` s after contact (from `phase`),
	-- `scale` x damage, sparing anyone the slam itself already caught
	wave: { radius: number, delay: number, scale: number, phase: number }?,
	-- boss attacks that fly a real projectile (Projectiles.luau) instead of resolving an
	-- area at windup end. cue: the drawer clients use. A lob (spit) fires `release` seconds
	-- into the windup and lands `flight` s later on the locked circle; a lane (lance) fires
	-- at windup end at `speed`. `origin`: root-relative offset (the server has no body).
	projectile: { cue: string, release: number?, radius: number, origin: Vector3, flight: number?, gravity: number?, speed: number?, range: number?, pierce: boolean?, data: { [string]: any }? }?,
}

-- Pack behaviour for regular beasts with an attack pool.
export type Pack = {
	howl: Attack?, -- on first noticing a player (kind "howl", radius = who it calls)
	hop: { distance: number, seconds: number, arc: number, cooldown: number, hits: number, window: number }?,
	-- orbit the target while waiting to attack; with waitFor, only while that attack is
	-- ready (or within a second of it) and close in to melee otherwise
	circle: { radius: number, speed: number, waitFor: string? }?,
	-- target inside the opener's minRange at the start: use the pool instead of waiting
	closeOpener: boolean?,
}

export type Drop = { item: string, chance: number }
export type BossDrops = { manuals: { string }, weapons: { string }, chance: number }

export type Def = {
	id: string,
	name: string,
	health: number,
	walkSpeed: number,
	runSpeed: number,
	aggro: number, -- notices players this close
	leash: number, -- gives up past this far from its spawn zone
	keepAway: number?, -- backs off when a player is closer than this
	qiDrop: number,
	respawn: number, -- seconds before a replacement spawns
	drops: { Drop }?,
	bossDrops: BossDrops?,
	stones: { number }, -- Spirit Stones each damager gets on a kill (min, max)
	boss: boolean?,
	realm: { any }, -- { major, minor } on the Realms ladder
	weight: number,
	knock: number?, -- studs its hits shove a player (default from weight, Config.Combat.CC.KNOCK_BASE)
	attack: Attack, -- the only attack, the opener of an attack pool, or the opener of a boss pattern
	attacks: { Attack }?, -- regular beasts: the pool it picks from (see the header)
	pack: Pack?,
	body: string?, -- the template in ServerStorage.Enemies to draw (default: id)
	pattern: { Attack }?, -- bosses: attacks used in rotation after `attack`
	summonAt: { number }?, -- bosses: health fractions that trigger a summon
	spacing: { leap: string, meleeChain: number, closeRange: number, closeSeconds: number, hurtFraction: number, hurtSeconds: number, cooldownScale: { number } }?, -- boss: random pool pick with retreat triggers (EnemyService foxAttack)
	rotate: boolean?, -- boss: pick the next pattern attack that fits the range band and phase (not strictly in order)
	phaseCall: Attack?, -- boss: the attack the `summonAt` thresholds call (a phase roar), instead of a summon
	phaseSpeed: number?, -- boss: run speed multiplier gained at each phase step
	closeIn: number?, -- boss: stops closing in this near its target (default 0.7 x min(range, 20))
	phaseCalls: { Attack }?, -- boss: per `summonAt` threshold, the attack it calls (else phaseCall)
	startsBurrowed: boolean?, -- boss: spawns and resets with Burrowed = true (immune and hidden until its opener surfaces it)
	shareTurns: boolean?, -- boss joins its summons' attack slots instead of overlapping their blows
	resetOnEvade: boolean?, -- return home, heal/reset the fight and dismiss owned summons on losing the target
}

local Wilds = require(script.Parent.Config).Wilds
local NEW_WOLF = Wilds.NEW_WOLF
local NEW_BOAR = Wilds.NEW_BOAR
local NEW_WOLF_KING = Wilds.NEW_WOLF_KING
local NEW_JIAO = Wilds.NEW_JIAO
local NEW_THUNDER_APE = Wilds.NEW_THUNDER_APE
local NEW_NINE_TAIL_FOX = Wilds.NEW_NINE_TAIL_FOX
local NEW_SERPENT = Wilds.NEW_SERPENT
local NEW_TORTOISE = Wilds.NEW_TORTOISE
local NEW_SHADOW_MANE = Wilds.NEW_SHADOW_MANE
local NEW_TOAD = Wilds.NEW_TOAD
local NEW_CENTIPEDE = Wilds.NEW_CENTIPEDE
local NEW_RAVEN = Wilds.NEW_RAVEN
local NEW_BAT = Wilds.NEW_BAT
local NEW_SPIDER = Wilds.NEW_SPIDER

local Enemies = {}

-- The Stone Boar until its new fight ships (Config.Wilds.NEW_BOAR).
local OLD_STONE_BOAR: Def = {
	id = "StoneBoar",
	name = "Stone Boar",
	realm = { "QiCondensation", 4 },
	weight = 2.5,
	health = 160,
	walkSpeed = 6,
	runSpeed = 12,
	aggro = 35,
	leash = 90,
	qiDrop = 24,
	stones = { 5, 9 },
	respawn = 30,
	drops = { { item = "LesserSpiritCore", chance = 0.35 } },
	attack = {
		kind = "charge",
		damage = 26,
		range = 24,
		windup = 1.0,
		recover = 1.2,
		cooldown = 3.5,
		length = 30,
		width = 5,
		dashSpeed = 55,
	},
}

local BOAR_CHARGE: Attack = {
	kind = "charge",
	name = "charge",
	damage = 26,
	range = 28,
	minRange = 12,
	windup = 1.0,
	recover = 0.7,
	cooldown = 4,
	length = 30,
	width = 5,
	dashSpeed = 55,
	stopPast = 3, -- skids to a stop just past you, so the gore can follow
	followUp = "gore",
}

local BOAR_GORE: Attack = {
	kind = "cone",
	name = "gore",
	damage = 20,
	range = 7,
	windup = 0.6,
	recover = 0.8,
	cooldown = 2.5,
	radius = 7,
	angle = 100,
}

-- The Spirit Wolf until the new fight ships (Config.Wilds.NEW_WOLF): one lunge,
-- the old part-built body.
local OLD_SPIRIT_WOLF: Def = {
	id = "SpiritWolf",
	name = "Spirit Wolf",
	realm = { "QiCondensation", 2 },
	weight = 1,
	health = 60,
	walkSpeed = 8,
	runSpeed = 18,
	aggro = 40,
	leash = 90,
	qiDrop = 14,
	stones = { 3, 6 },
	respawn = 20,
	drops = { { item = "LesserSpiritCore", chance = 0.2 } },
	attack = {
		kind = "lunge",
		damage = 12,
		range = 9,
		windup = 0.55,
		recover = 0.6,
		cooldown = 1.8,
		length = 10,
		width = 3.5,
		dashSpeed = 40,
	},
}

Enemies.Defs = {
	-- Ring 1's pack hunter and the FirstKill beast (GateWolves). Hit and run: the
	-- first to notice howls the pack in, one commits while the others circle, it
	-- hops back when hit three times or after a bite. Pounce is the opener; the
	-- leap waits 6 s into a fight. At QC2 (120 HP): bite 8%, pounce 13%, leap 15%.
	SpiritWolf = if not NEW_WOLF then OLD_SPIRIT_WOLF else {
		id = "SpiritWolf",
		name = "Spirit Wolf",
		body = "SpiritWolfB", -- the rigged Studio-part wolf (art/enemies/spirit_wolf_b)
		realm = { "QiCondensation", 2 },
		weight = 1,
		health = 80,
		walkSpeed = 8,
		runSpeed = 18,
		aggro = 40,
		leash = 90,
		qiDrop = 14,
		stones = { 3, 6 },
		respawn = 20,
		drops = { { item = "LesserSpiritCore", chance = 0.2 } },
		attack = {
			kind = "lunge",
			name = "pounce",
			damage = 16,
			range = 12,
			minRange = 5,
			windup = 0.7,
			recover = 0.9,
			cooldown = 3.5,
			length = 12,
			width = 3.5,
			dashSpeed = 40,
			skid = true, -- overshoots turn round (pounceSkid)
		},
		attacks = {
			{
				kind = "leap",
				name = "leap",
				damage = 18,
				range = 24,
				minRange = 12,
				notBefore = 6,
				windup = 1.0,
				active = 0.45,
				arc = 5,
				recover = 1.1,
				cooldown = 9,
				radius = 5,
				skid = true, -- leapSkid
			},
			{
				kind = "lunge",
				name = "pounce",
				damage = 16,
				range = 12,
				minRange = 5,
				windup = 0.7,
				recover = 0.9,
				cooldown = 3.5,
				length = 12,
				width = 3.5,
				dashSpeed = 40,
				skid = true,
			},
			{
				kind = "cone",
				name = "bite",
				damage = 10,
				range = 5,
				windup = 0.45,
				recover = 0.5,
				cooldown = 2.2,
				radius = 6,
				angle = 70,
				hopAfter = true,
			},
		} :: { Attack },
		pack = {
			-- rallies idle packmates within 30; with none, calls 1-3 Spirit Wolves from
			-- 18-25 studs around the target (only 1, and only with no wolf near, while
			-- the target is in onboarding). They pay full rewards and leave when the
			-- fight ends.
			howl = {
				kind = "howl",
				name = "howl",
				damage = 0,
				range = 0,
				windup = 0.8,
				recover = 0.2,
				cooldown = 0,
				radius = 30,
				summons = "SpiritWolf",
				count = 1,
				countMax = 3,
				maxAlive = 3,
			},
			hop = { distance = 7, seconds = 0.25, arc = 1.2, cooldown = 4, hits = 3, window = 2 },
			circle = { radius = 10, speed = 8 },
		},
	},
	-- Ring 1-2's charger (QC4). Keeps its distance pacing side to side, charges
	-- down a long lane, and gores at once if you're still close when it skids to
	-- a stop. At QC4 (165 HP): charge 16%, gore 12%.
	StoneBoar = if not NEW_BOAR then OLD_STONE_BOAR else {
		id = "StoneBoar",
		name = "Stone Boar",
		body = "StoneBoarB", -- the rigged Studio-part boar (art/enemies/quadrupeds)
		realm = { "QiCondensation", 4 },
		weight = 2.5,
		health = 200,
		walkSpeed = 6,
		runSpeed = 12,
		aggro = 35,
		leash = 90,
		qiDrop = 24,
		stones = { 5, 9 },
		respawn = 30,
		drops = { { item = "LesserSpiritCore", chance = 0.35 } },
		attack = BOAR_CHARGE,
		attacks = { BOAR_CHARGE, BOAR_GORE } :: { Attack },
		pack = {
			-- paces side to side at charging distance while the charge is ready;
			-- closes in to gore while it cools down
			circle = { radius = 16, speed = 5, waitFor = "charge" },
			closeOpener = true, -- rushed under 12 studs, it gores instead of waiting
		},
	},
	VenomSerpent = {
		id = "VenomSerpent",
		name = "Venom Serpent",
		realm = { "QiCondensation", 3 },
		weight = 0.8,
		health = 80,
		walkSpeed = 5,
		runSpeed = 9,
		aggro = 45,
		leash = 80,
		keepAway = 12,
		qiDrop = 20,
		stones = { 4, 8 },
		respawn = 25,
		drops = { { item = "LesserSpiritCore", chance = 0.25 } },
		attack = {
			kind = "spit",
			damage = 16,
			range = 32,
			windup = 1.1,
			recover = 0.6,
			cooldown = 2.6,
			radius = 5.5,
		},
	},
	ElderWolfKing = {
		id = "ElderWolfKing",
		name = "Elder Wolf King",
		realm = { "QiCondensation", 9 },
		weight = 7,
		boss = true,
		health = 1500,
		walkSpeed = 8,
		runSpeed = 16,
		aggro = 55,
		leash = 95,
		qiDrop = 160,
		stones = { 60, 90 },
		respawn = 180,
		drops = {
			{ item = "GreaterSpiritCore", chance = 1 },
			{ item = "LesserSpiritCore", chance = 1 },
			{ item = "MarrowWashingPill", chance = 0.05 },
			{ item = "RootRebirthPill", chance = 0.08 },
		},
		bossDrops = {
			manuals = { "RampagingTiger", "HeavenSplitter", "CrescentSweep", "GreatSageAwakening" },
			weapons = { "AzureFrostJian", "CrimsonFangDadao", "MountainSplitterGreatsword", "GreenDragonGuandao", "SilverSerpentSpear", "CloudSageStaff" },
			chance = 0.25,
		},
		summonAt = { 0.66, 0.33 },
		attack = {
			kind = "cone",
			damage = 30,
			range = 14,
			windup = 1.1,
			recover = 0.8,
			cooldown = 2.2,
			radius = 17,
			angle = 100,
		},
		pattern = {
			{
				kind = "charge",
				damage = 32,
				range = 28,
				windup = 1.1,
				recover = 1.0,
				cooldown = 2.4,
				length = 30,
				width = 7,
				dashSpeed = 60,
			},
			{
				kind = "slam",
				damage = 36,
				range = 12,
				windup = 1.3,
				recover = 1.0,
				cooldown = 2.6,
				radius = 14,
			},
			{
				kind = "cone",
				damage = 30,
				range = 14,
				windup = 1.0,
				recover = 0.8,
				cooldown = 2.2,
				radius = 17,
				angle = 100,
			},
			{
				kind = "summon",
				damage = 0,
				range = 60,
				windup = 1.2,
				recover = 0.6,
				cooldown = 2.0,
				summons = "SpiritWolf",
				count = 2,
				maxAlive = 4,
			},
		} :: { Attack },
	},
} :: { [string]: Def }

-- A boss animation/fight trial, isolated from the main game's older King by
-- Config.Wilds.NEW_WOLF_KING. At QC9 (330 HP), the quick checks take 10-14%,
-- the bite 19%, the rush 25%, Crownfall 32%, the King's Leap 26% and its rake 12%. Small mistakes accumulate;
-- every heavy hit is reactable and every attack leaves time to answer it.
if NEW_WOLF_KING then
	local royalBite: Attack = {
		kind = "cone",
		name = "royalBite",
		damage = 64,
		range = 14,
		windup = 0.9,
		recover = 1.0,
		cooldown = 2.3,
		radius = 15,
		angle = 100,
	}
	local pawSwipe: Attack = {
		kind = "cone",
		name = "pawSwipe",
		damage = 34,
		range = 11,
		windup = 0.45,
		recover = 0.75,
		cooldown = 1.6,
		radius = 12,
		angle = 95,
	}
	local kingsRush: Attack = {
		kind = "charge",
		name = "kingsRush",
		damage = 82,
		range = 30,
		windup = 1.0,
		recover = 1.0,
		cooldown = 3.1,
		length = 30,
		width = 7,
		dashSpeed = 50,
		minRange = 12, -- the shortest rush lane, including when started close
		stopPast = if Wilds.WEIGHTED_MOVES then -4 else 3, -- pulls up short of you for the rake
	}
	local clawDown: Attack = {
		kind = "slam",
		name = "clawDown",
		damage = 46,
		range = 11,
		windup = 0.55,
		recover = 0.85,
		cooldown = 1.8,
		radius = 4.5,
		offset = Vector3.new(1.7, 0, -7), -- under the right forepaw, not the root
	}
	local crownfall: Attack = {
		kind = "slam",
		name = "crownfall",
		damage = 104,
		range = 14,
		windup = 1.25,
		recover = 1.25,
		cooldown = 2.9,
		radius = 13,
		offset = Vector3.new(0, 0, -3.5),
	}
	local packCall: Attack = {
		kind = "summon",
		name = "packCall",
		damage = 0,
		range = 40,
		windup = 1.2,
		recover = 1.0,
		cooldown = 2.6,
		summons = "SpiritWolf",
		count = 2,
		maxAlive = 2,
		thresholdOnly = true,
		-- the howl rattles anyone close: dodge out of the ring or through the roar
		stun = { kind = "stun", radius = 20, seconds = 1.0 },
	}
	-- The engage roar: a fresh engagement (Config.ENGAGE_RESET) opens with it
	-- through pack.howl. No damage; staggers everyone within the ring unless they
	-- dodge or back off. Timings match the authored Roar pose (1.0 / 0.1 / 0.8).
	local roar: Attack = {
		kind = "howl",
		name = "roar",
		damage = 0,
		range = 0,
		windup = 1.0,
		recover = 0.9,
		cooldown = 0,
		radius = 30,
		stun = { kind = "stagger", radius = 18, seconds = 0.8 },
	}
	-- King's Leap: a high pounce onto where the target stood (a gap closer: skipped
	-- under minRange), the slam circle on landing, then the rake if they're still in
	-- reach and in front (the leap is the warning; the rake shows its own cone). Missed:
	-- kingLeapSkid, round to face them.
	local kingRake: Attack = {
		kind = "cone",
		name = "kingRake",
		damage = 40,
		range = 18,
		windup = 0.5,
		recover = 0.9,
		cooldown = 0,
		radius = 16,
		angle = 120,
		chainOnly = true,
	}
	local kingLeap: Attack = {
		kind = "leap",
		name = "kingLeap",
		telegraph = "heavy",
		damage = 86,
		range = 42,
		minRange = 12,
		windup = 1.1,
		active = 0.7,
		arc = 16,
		recover = 1.0,
		cooldown = 3.2,
		radius = 14,
		arrive = kingRake,
		skid = true,
	}
	-- the rush ends in the same rake (or kingsRushSkid)
	kingsRush.arrive, kingsRush.skid = kingRake, true
	local king = Enemies.Defs.ElderWolfKing
	king.pack = { howl = roar }
	king.body = "ElderWolfKingB"
	king.health = 1900
	king.walkSpeed = 5
	king.runSpeed = 20 -- the player walks at 16: a boss that runs slower never catches them
	king.aggro = 55
	king.leash = 110
	king.attack = royalBite
	-- Quick checks alternate with the big commitments. Pack Call is included so
	-- clients can find its timing, but the server calls it only at the thresholds.
	king.pattern = { pawSwipe, kingsRush, clawDown, crownfall, royalBite, kingLeap, packCall, kingRake }
	king.summonAt = { 0.65, 0.30 }
	king.shareTurns = true
	king.resetOnEvade = true
end

-- THE THUNDER APE (Config.Wilds.NEW_THUNDER_APE, testbed only): a 30-stud storm
-- boss for Foundation 1 (player 500 HP, power 3). The body is 3.71x the old ape
-- (ThunderApeB, root box 14.8 x 14.8 x 16.3, body radius ~15), so every reach is
-- measured from its centre and starts past ~15 studs: melee cones reach 30, the pound
-- lands 18 ahead. Shares of the player's health at FE1: club/backhand 10%, pound 22%
-- (wave 11%), body slam 28%, skyfall 30% + sweep 11%, rush 22% + swipe 12%, boulder 14%,
-- lance 24%, bolt 14%, judgment 38% + stun. Roars stagger. Chain: clubSwing -> backhand
-- -> thunderPound. Arrivals (WEIGHTED_MOVES): thunderRush stops short of where you
-- stood and swipes (rushSwipe), skyfallSlam lands and sweeps (skyfallSweep); a miss
-- skids round. Bounds pick over/flank/back/short, never twice running.
-- Design and contracts: the enemy-designer's Thunder Ape sheet (timings the pose and
-- effect modules hardcode: challenge beats 0.55/1.15/1.75, roars 0.45/0.85 and
-- 0.4/0.8/1.2, boulder released at 1.25 s).
if NEW_THUNDER_APE then
	local function atk(a: Attack): Attack
		return a
	end
	local clubSwing = atk({
		kind = "cone", name = "clubSwing", damage = 50, range = 26, windup = 0.80, recover = 0.45,
		cooldown = 1.3, radius = 30, angle = 110, followUp = "backhand",
	})
	local backhand = atk({
		kind = "cone", name = "backhand", damage = 50, range = 26, windup = 0.60, recover = 0.45,
		cooldown = 1.1, radius = 30, angle = 120, chainOnly = true, followUp = "thunderPound",
	})
	local thunderPound = atk({
		kind = "slam", name = "thunderPound", damage = 110, range = 28, windup = 0.85, recover = 1.30,
		cooldown = 2.65, radius = 15, offset = Vector3.new(0, 0, -18), chainOnly = true,
		wave = { radius = 34, delay = 0.45, scale = 0.5, phase = 2 },
	})
	local bodySlam = atk({
		kind = "lunge", name = "bodySlam", telegraph = "heavy", damage = 140, range = 38, windup = 1.10, recover = 1.10,
		cooldown = 3.45, length = 34, width = 20, dashSpeed = 55, react = "stagger",
	})
	local skyfallSlam = atk({
		kind = "leap", name = "skyfallSlam", telegraph = "heavy", damage = 150, range = 55, minRange = 22, windup = 1.20,
		active = 0.75, arc = 26, recover = 1.10, cooldown = 3.6, radius = 20,
	})
	local thunderRush = atk({
		kind = "charge", name = "thunderRush", damage = 110, range = 80, minRange = 24, windup = 1.20,
		recover = 0.90, cooldown = 3.4, length = 64, width = 14, dashSpeed = 95,
		stopPast = -12, -- commits to the line and pulls up just short of you, for the swipe
	})
	-- the arrivals: short windups, since the rush or leap itself was the warning
	local rushSwipe = atk({
		kind = "cone", name = "rushSwipe", damage = 60, range = 32, windup = 0.40, recover = 0.90,
		cooldown = 0, radius = 30, angle = 110, chainOnly = true,
	})
	local skyfallSweep = atk({
		kind = "cone", name = "skyfallSweep", damage = 55, range = 34, windup = 0.50, recover = 1.00,
		cooldown = 0, radius = 32, angle = 140, chainOnly = true,
	})
	thunderRush.arrive, thunderRush.skid = rushSwipe, true
	skyfallSlam.arrive, skyfallSlam.skid = skyfallSweep, true
	local bound = atk({
		kind = "bound", name = "bound", damage = 0, range = 200, windup = 0.45, active = 0.55, arc = 10,
		recover = 0.35, cooldown = 1.3, landMin = 22, landMax = 28,
		-- flight seconds (DashSeconds) and arc per landing mode (BoundMode)
		boundModes = {
			over = { active = 0.80, arc = 24 }, flank = { active = 0.60, arc = 11 },
			back = { active = 0.55, arc = 9 }, short = { active = 0.42, arc = 5 },
		},
	})
	local boulderHurl = atk({
		kind = "spit", name = "boulderHurl", damage = 70, range = 85, minRange = 45, windup = 1.70,
		recover = 0.90, cooldown = 3.2, radius = 10,
		projectile = {
			cue = "boulder", release = 1.25, flight = 0.45, gravity = 160, radius = 5,
			origin = Vector3.new(7, 14, -2), data = { size = 5 },
		},
	})
	local thunderLance = atk({
		kind = "lance", name = "thunderLance", damage = 120, range = 85, minRange = 20, windup = 1.40,
		recover = 0.90, cooldown = 2.9, length = 90, width = 8, phase = 2,
		projectile = {
			cue = "thunderLance", radius = 2.5, speed = 150, range = 74, pierce = true,
			origin = Vector3.new(0, 0, -16), data = { length = 90, width = 8 },
		},
	})
	local thunderRoar = atk({
		kind = "howl", name = "thunderRoar", damage = 0, range = 45, windup = 1.30, recover = 1.00,
		cooldown = 3.0, radius = 8, phase = 2, stun = { kind = "stagger", radius = 42, seconds = 0.9 },
	})
	local stormCall = atk({
		kind = "storm", name = "stormCall", damage = 70, range = 90, windup = 1.20, recover = 3.0,
		cooldown = 4.8, phase = 2, bolts = 5, boltsP3 = 7, boltWindup = 0.9, boltInterval = 0.45,
		boltRadius = 8,
	})
	local judgment = atk({
		kind = "leap", name = "judgment", telegraph = "heavy", damage = 190, range = 70, minRange = 25, windup = 1.60,
		active = 1.00, arc = 48, recover = 1.80, cooldown = 5.0, radius = 28, phase = 3,
		stun = { kind = "stun", radius = 0, seconds = 1.0, onHit = true },
	})
	local phaseRoar = atk({
		kind = "howl", name = "phaseRoar", damage = 0, range = 60, windup = 1.60, recover = 1.20,
		cooldown = 0, radius = 8, thresholdOnly = true, phaseStep = true,
		stun = { kind = "stagger", radius = 34, seconds = 0.8 },
	})
	-- the entrance: a fresh engagement opens with it (pack.howl). No damage, no stun.
	local challenge = atk({
		kind = "howl", name = "challenge", damage = 0, range = 0, windup = 2.40, recover = 0.80,
		cooldown = 0, radius = 30, chainOnly = true,
	})
	Enemies.Defs.ThunderApe = {
		id = "ThunderApe",
		name = "Thunder Ape",
		realm = { "Foundation", 1 },
		weight = 9,
		boss = true,
		health = 3000,
		walkSpeed = 8,
		runSpeed = 22, -- the player walks at 16; phases add phaseSpeed
		phaseSpeed = 1.09,
		aggro = 90,
		leash = 240,
		closeIn = 20,
		qiDrop = 300,
		stones = { 120, 180 },
		respawn = 300,
		body = "ThunderApeB",
		drops = {
			{ item = "GreaterSpiritCore", chance = 1 },
			{ item = "LesserSpiritCore", chance = 1 },
			{ item = "MarrowWashingPill", chance = 0.08 },
			{ item = "RootRebirthPill", chance = 0.12 },
		},
		-- placeholder pool until the user picks this boss's rewards (same as the King's)
		bossDrops = Enemies.Defs.ElderWolfKing.bossDrops,
		summonAt = { 0.66, 0.33 }, -- the boss bar's phase ticks; phaseCall answers them
		phaseCall = phaseRoar,
		pack = { howl = challenge },
		attack = clubSwing,
		pattern = {
			clubSwing, bound, boulderHurl, bodySlam, skyfallSlam, bound, thunderRush, thunderLance,
			thunderRoar, bound, stormCall, judgment, backhand, thunderPound, phaseRoar, challenge,
			rushSwipe, skyfallSweep,
		} :: { Attack },
		rotate = true,
		resetOnEvade = true,
	} :: Def
end

-- THE JADE JIAO (Config.Wilds.NEW_JIAO, testbed only): a jade serpent boss for
-- QC7 (player 255 HP, power 1.76). The body is the user's reference python at 3.17x
-- (24 x 19 x 38 studs; root box 24.7 x 9.5 x 26.3 centred under the coil, the skull
-- about 17 studs and the fang tips about 24 studs ahead of the root, head 14.6 up), so
-- every reach is measured from the root centre and clears the head. Shares of a QC7 player's health:
-- fang 14% (+poison), flurry 7% a strike, sweep 12%, shove 7%, slam 24%, erupt 22%, lance 11%,
-- spray 8% a lane, pools 7% (+poison), coil 8% + squeeze 28%, rain 10% a drop. Crowd
-- control rides `stun.onHit` (PlayerStun), the coil stuns 1.4 s and the squeeze is
-- damage only (a stun's immunity window would swallow its CC). Mechanics for bolt,
-- pools, burrow and coil live in BossAttacks.luau; poison in PlayerPoison.luau.
-- Design and contracts: the enemy-designer's Jade Jiao sheet.
if NEW_JIAO then
	local function atk(a: Attack): Attack
		return a
	end
	local venom = { stacks = 1, seconds = 5 }
	local venomLance = atk({
		kind = "bolt", name = "venomLance", damage = 28, range = 70, minRange = 26, windup = 0.70,
		recover = 0.80, cooldown = 1.5, lanes = { 0 }, boltSpeed = 75, length = 72, width = 3.6, poison = venom,
		mouth = 24.2, mouthHeight = 13.1, boltRadius = 1.8,
	})
	local venomFang = atk({
		kind = "cone", name = "venomFang", damage = 36, range = 30, windup = 0.75, recover = 0.90,
		cooldown = 1.65, radius = 34, angle = 80, poison = venom,
	})
	local pillarSlam = atk({
		kind = "slam", name = "pillarSlam", damage = 61, range = 36, windup = 1.00, recover = 1.30,
		cooldown = 2.3, radius = 9, offset = Vector3.new(0, 0, -27),
		stun = { kind = "stagger", radius = 0, seconds = 0.7, onHit = true },
	})
	local tailSweep = atk({
		kind = "slam", name = "tailSweep", damage = 31, range = 20, windup = 0.80, recover = 1.00,
		cooldown = 1.8, radius = 22, offset = Vector3.new(0, 0, 0),
		stun = { kind = "stagger", radius = 0, seconds = 0.5, onHit = true },
	})
	-- Tail Shove: the coil whips out and throws anyone close 36 studs clear, then it holds
	-- and shoots from range (rangedNext): the Jiao makes its own range.
	local tailShove = atk({
		kind = "slam", name = "tailShove", damage = 18, range = 22, windup = 0.70, recover = 0.80,
		cooldown = 1.0, radius = 20, offset = Vector3.new(0, 0, 0), knock = 36,
		stun = { kind = "stagger", radius = 0, seconds = 0.5, onHit = true },
		rangedNext = { "venomLance", "venomSpray", "venomPools" }, rangedWait = 2.5,
	})
	local mireDive = atk({
		kind = "burrow", name = "mireDive", damage = 0, range = 56, minRange = 30, windup = 0.80, recover = 0.10,
		cooldown = 1.0, length = 56, width = 6, dashSpeed = 75, stopPast = 0, followUp = "erupt", phase = 2,
	})
	local erupt = atk({
		kind = "slam", name = "erupt", telegraph = "heavy", damage = 56, range = 200, windup = 0.85, recover = 1.10,
		cooldown = 1.0, radius = 14, offset = Vector3.new(0, 0, 0), chainOnly = true, unburrow = true,
		stun = { kind = "stagger", radius = 0, seconds = 0.8, onHit = true },
	})
	local dreadHiss = atk({
		kind = "howl", name = "dreadHiss", damage = 0, range = 30, windup = 1.10, recover = 0.90,
		cooldown = 2.0, radius = 1, phase = 2, stun = { kind = "stagger", radius = 30, seconds = 0.8 },
	})
	local venomSpray = atk({
		kind = "bolt", name = "venomSpray", damage = 20, range = 60, minRange = 26, windup = 1.00,
		recover = 1.20, cooldown = 2.0, lanes = { 0, -22, 22 }, boltSpeed = 75, length = 62, width = 3,
		mouth = 24.2, mouthHeight = 13.1, boltRadius = 1.5, poison = venom, phase = 2,
	})
	local jiaoCoil = atk({
		kind = "coil", name = "jiaoCoil", telegraph = "heavy", damage = 20, range = 45, minRange = 8, windup = 1.50, recover = 4.40,
		cooldown = 4.0, radius = 13.5, coilRadius = 11.9, dashSpeed = 40, length = 40, dashMin = 0.45,
		hold = 3.0, holdP3 = 2.6, halfAngle = 40, halfAngleP3 = 30, squeezeDamage = 71, phase = 2,
		knock = 0, -- a shove would throw players out of the ring it traps them in
		stun = { kind = "stun", radius = 0, seconds = 1.4, secondsP3 = 1.6, onHit = true },
	})
	local fangFlurry = atk({
		kind = "cone", name = "fangFlurry", damage = 18, range = 28, windup = 0.90, recover = 2.10,
		cooldown = 3.0, radius = 30, angle = 70, poison = venom, phase = 2,
		strikes = { { at = 0.4, radius = 30, angle = 70 }, { at = 1.0, radius = 36, angle = 90 } },
	})
	local venomPools = atk({
		kind = "pools", name = "venomPools", damage = 18, range = 60, minRange = 24, windup = 1.00,
		recover = 0.90, cooldown = 2.0, radius = 7, flank = 11, poolSeconds = 7, poison = venom, phase = 2,
	})
	local molt = atk({
		kind = "summon", name = "molt", damage = 0, range = 80, windup = 1.60, recover = 0.90, cooldown = 0,
		summons = "VenomSerpent", count = 2, maxAlive = 2, thresholdOnly = true, phaseStep = true,
	})
	local ascension = atk({
		kind = "summon", name = "ascension", damage = 0, range = 80, windup = 2.00, recover = 1.00, cooldown = 0,
		summons = "VenomSerpent", count = 2, maxAlive = 2, thresholdOnly = true, phaseStep = true,
		followUp = "venomRain",
	})
	-- Rain: 9 circles one every 0.3 s from the release, each on where the target stands
	-- then and striking 0.9 s after it shows (EnemyService callStorm).
	local venomRain = atk({
		kind = "storm", name = "venomRain", damage = 26, range = 200, windup = 2.00, recover = 5.00, cooldown = 0,
		bolts = 9, boltInterval = 0.3, boltWindup = 0.9, boltRadius = 7, boltName = "venomRain",
		thresholdOnly = true, chainOnly = true,
	})
	-- the entrance: a fresh engagement opens with it (pack.howl). No damage, no stun.
	local emerge = atk({
		kind = "howl", name = "emerge", damage = 0, range = 0, windup = 2.20, recover = 0.60, cooldown = 0,
		radius = 1, chainOnly = true, unburrow = true,
	})
	Enemies.Defs.JadeJiao = {
		id = "JadeJiao",
		name = "Jade Jiao",
		realm = { "QiCondensation", 7 },
		weight = 9,
		boss = true,
		health = 1500,
		walkSpeed = 6,
		runSpeed = 21, -- the player walks at 16; phases add phaseSpeed
		phaseSpeed = 1.025,
		aggro = 60,
		leash = 130,
		closeIn = 26, -- stops just past the head, not inside the body
		qiDrop = 130,
		stones = { 50, 80 },
		respawn = 240,
		drops = {
			{ item = "GreaterSpiritCore", chance = 1 },
			{ item = "LesserSpiritCore", chance = 1 },
			{ item = "MarrowWashingPill", chance = 0.06 },
			{ item = "RootRebirthPill", chance = 0.10 },
		},
		-- placeholder pool until the user picks this boss's rewards (same as the King's)
		bossDrops = Enemies.Defs.ElderWolfKing.bossDrops,
		-- thresholds: molt (phase 2), ascension then rain (phase 3), and the rain again at
		-- 12%. The boss bar draws a tick at each.
		summonAt = { 0.66, 0.33, 0.12 },
		phaseCall = molt,
		phaseCalls = { molt, ascension, venomRain },
		startsBurrowed = true,
		pack = { howl = emerge },
		attack = venomLance,
		pattern = {
			venomLance, venomFang, tailShove, pillarSlam, tailSweep, mireDive, erupt, dreadHiss, venomSpray, jiaoCoil,
			fangFlurry, venomPools, molt, ascension, venomRain, emerge,
		} :: { Attack },
		rotate = true,
		shareTurns = true,
		resetOnEvade = true,
	} :: Def
end

-- THE NINE-TAILED FOX (Config.Wilds.NEW_NINE_TAIL_FOX, testbed only): an FE1 duelist
-- boss with telescoping tails (NineTailFoxB at 2.13x: tails reach 8.7 studs at rest,
-- 21.4 extended, so lances and sweeps are 18-20 studs, not the 30 first sketched).
-- A random pool pick with spacing triggers (EnemyService foxAttack); phases at 66% and
-- 33% (veilBreak, `Phase` attribute); every hit is 8-25% of an FE1 player's 500 HP.
-- Cut for now, listed in enemies.md as later add-ons: snapBite, tailWhirl, crossLash,
-- wispRain, phantomStep, mirrorVeil.
if NEW_NINE_TAIL_FOX then
	local function atk(a: Attack): Attack
		return a
	end
	local intro = atk({
		kind = "howl", name = "intro", damage = 0, range = 0, windup = 2.2, recover = 0.8,
		cooldown = 0, radius = 8, chainOnly = true,
	})
	local fangDance = atk({
		kind = "barrage", barrage = "fangs", name = "fangDance", damage = 28, range = 18, windup = 0.65,
		recover = 1.2, cooldown = 3.0, radius = 20, angle = 80,
	})
	local tailSweep = atk({
		kind = "cone", name = "tailSweep", damage = 55, range = 16, windup = 0.9, recover = 1.1,
		cooldown = 3.5, radius = 18, angle = 200,
	})
	local tailLance = atk({
		kind = "barrage", barrage = "lance", name = "tailLance", damage = 60, range = 24, minRange = 5,
		windup = 0.6, recover = 0.8, cooldown = 2.4, length = 20, width = 4,
	})
	local lanceFan = atk({
		kind = "barrage", barrage = "lanceFan", name = "lanceFan", damage = 45, range = 24, minRange = 5,
		windup = 0.95, recover = 1.1, recoverP3 = 1.8, cooldown = 4.5, length = 20, width = 4,
	})
	local tailSnare = atk({
		kind = "barrage", barrage = "snare", name = "tailSnare", damage = 40, range = 24, minRange = 8,
		windup = 0.85, recover = 0.9, cooldown = 6.0, length = 20, width = 4,
		pull = { distance = 11, seconds = 0.45 }, followUpOnHit = "fangDance",
	})
	local rendingPounce = atk({
		kind = "lunge", name = "rendingPounce", damage = 75, range = 36, minRange = 18, windup = 0.75,
		recover = 1.0, cooldown = 4.0, length = 30, width = 8, dashSpeed = 55,
	})
	local foxfireVolley = atk({
		kind = "barrage", barrage = "volley", name = "foxfireVolley", damage = 40, range = 70, minRange = 20,
		windup = 1.1, recover = 1.0, recoverP3 = 1.8, cooldown = 6.5, length = 56, width = 4,
	})
	local rootfireEruption = atk({
		kind = "barrage", barrage = "ringHeart", name = "rootfireEruption", damage = 55, range = 55, minRange = 8,
		windup = 1.5, recover = 1.6, cooldown = 8.0, radius = 5, ring = 11, heartRadius = 7, phase = 2,
		hitStun = { kind = "stagger", seconds = 0.6 },
	})
	local moonLeap = atk({
		kind = "retreat", name = "moonLeap", damage = 40, range = 200, windup = 0.4, active = 0.6, arc = 8,
		recover = 0.4, cooldown = 7.0, distance = 34, width = 6, trailScale = 0.3, followUp = "foxfireVolley",
	})
	local mournfulScream = atk({
		kind = "howl", name = "mournfulScream", damage = 0, range = 28, windup = 1.4, recover = 1.6,
		cooldown = 14.0, radius = 8, phase = 2, stun = { kind = "stun", radius = 30, seconds = 1.2 },
	})
	local nineTailFall = atk({
		kind = "barrage", barrage = "spiral", name = "nineTailFall", telegraph = "heavy", damage = 55, range = 45, windup = 1.8,
		recover = 2.0, cooldown = 12.0, radius = 7, finalRadius = 20, phase = 3,
		hitStun = { kind = "stagger", seconds = 0.6 },
	})
	local veilBreak = atk({
		kind = "howl", name = "veilBreak", damage = 0, range = 60, windup = 1.6, recover = 1.0,
		cooldown = 0, radius = 8, thresholdOnly = true, phaseStep = true,
		stun = { kind = "stagger", radius = 16, seconds = 0.6 },
	})
	local pool: { Attack } = {
		fangDance, tailSweep, tailLance, lanceFan, tailSnare, rendingPounce, foxfireVolley, rootfireEruption,
		moonLeap, mournfulScream, nineTailFall, veilBreak, intro,
	}
	Enemies.Defs.NineTailFox = {
		id = "NineTailFox",
		name = "Nine-Tailed Fox",
		realm = { "Foundation", 1 },
		weight = 7,
		boss = true,
		health = 2600,
		walkSpeed = 8,
		runSpeed = 22, -- the player walks at 16
		aggro = 70,
		leash = 160,
		qiDrop = 280,
		stones = { 110, 170 },
		respawn = 300,
		body = "NineTailFoxB",
		drops = {
			{ item = "GreaterSpiritCore", chance = 1 },
			{ item = "LesserSpiritCore", chance = 1 },
			{ item = "MarrowWashingPill", chance = 0.08 },
			{ item = "RootRebirthPill", chance = 0.12 },
		},
		-- placeholder pool until the user picks this boss's rewards (same as the King's)
		bossDrops = Enemies.Defs.ElderWolfKing.bossDrops,
		summonAt = { 0.66, 0.33 }, -- the boss bar's phase ticks; phaseCall answers them
		phaseCall = veilBreak,
		pack = { howl = intro, circle = { radius = 24, speed = 14, waitFor = "foxfireVolley" } },
		attack = fangDance,
		attacks = pool,
		pattern = pool,
		spacing = {
			leap = "moonLeap", meleeChain = 2, closeRange = 14, closeSeconds = 2.5,
			hurtFraction = 0.12, hurtSeconds = 3, cooldownScale = { 1, 0.85, 0.7 },
		},
		shareTurns = true,
		resetOnEvade = true,
	} :: Def
end

-- THE SECOND BESTIARY WAVE (testbed only, Config.Wilds.NEW_SERPENT / NEW_TORTOISE /
-- NEW_SHADOW_MANE). Numbers are first guesses for the user's playtest, not balance.

-- Venom Serpent (QC3, player 140 HP, power 1.2): the small cobra, a skirmisher. It circles
-- 14 studs out and spits (a lobbed gob onto a closing circle, 1 poison stack), darts in
-- with a hooded strike when you come close (poison), and slides back after it. Shares of
-- a QC3 player's health: spit 11%, strike 10%. The Jade Jiao's moves (lance, fang,
-- spray, pools, coil, dive) are not repeated.
if NEW_SERPENT then
	local venom = { stacks = 1, seconds = 4 }
	local venomSpit: Attack = {
		kind = "spit", name = "venomSpit", damage = 15, range = 32, minRange = 12, windup = 1.1,
		recover = 0.6, cooldown = 2.6, radius = 5.5, poison = venom,
	}
	local hoodStrike: Attack = {
		kind = "lunge", name = "hoodStrike", damage = 14, range = 12, minRange = 2, windup = 0.6,
		recover = 0.8, cooldown = 3.2, length = 8, width = 3.5, dashSpeed = 32, poison = venom,
		stopPast = -4, reach = 7, -- the muzzle leads the root by 7.1: the root stops 4 short, the head lands 3 past
		skid = true, hopAfter = true, -- the backslide: pack.hop below
	}
	Enemies.Defs.VenomSerpent = {
		id = "VenomSerpent",
		name = "Venom Serpent",
		body = "VenomSerpentB",
		realm = { "QiCondensation", 3 },
		weight = 0.8,
		health = 80,
		walkSpeed = 5,
		runSpeed = 9,
		aggro = 45,
		leash = 80,
		qiDrop = 20,
		stones = { 4, 8 },
		respawn = 25,
		drops = { { item = "LesserSpiritCore", chance = 0.25 } },
		attack = venomSpit,
		attacks = { venomSpit, hoodStrike } :: { Attack },
		pack = {
			-- player hits never trigger the backslide (hits = 99); only hoodStrike's hopAfter does
			hop = { distance = 9, seconds = 0.35, arc = 0, cooldown = 3, hits = 99, window = 1 },
			circle = { radius = 14, speed = 5 },
			closeOpener = true, -- rushed under 12 studs, it strikes instead of waiting
		},
	} :: Def
end

-- Stone Tortoise (QC6, player 220 HP, power 1.6): the user's reference tortoise at 1.76x
-- (13.3 x 13.9 x 22), a slow tank that owns the ground around its feet. Neck Snap is the
-- quick check, Quake Stomp the big one, Shell Guard the lesson in patience (hits do 20%
-- for 2 s, then it snaps out). Reaches are measured from the root centre (13.3 x 8.5 x 22
-- box; the beak is 10.8 ahead, 11.5 stretched; the fore feet 3.3 ahead), so the stomp
-- circle sits under the fore feet and the cone reaches the stretched beak plus a stud or two.
if NEW_TORTOISE then
	local shellSnap: Attack = {
		kind = "cone", name = "shellSnap", damage = 24, range = 14, windup = 0.35, recover = 1.0,
		cooldown = 0, radius = 14, angle = 70, chainOnly = true,
	}
	local neckSnap: Attack = {
		kind = "cone", name = "neckSnap", damage = 24, range = 13, windup = 0.7, recover = 0.9,
		cooldown = 2.5, radius = 14, angle = 60,
	}
	local quakeStomp: Attack = {
		kind = "slam", name = "quakeStomp", damage = 40, range = 13, windup = 1.2, recover = 1.4,
		cooldown = 5, radius = 10, offset = Vector3.new(0, 0, -3.3), react = "stagger",
	}
	local shellGuard: Attack = {
		kind = "guard", name = "shellGuard", damage = 0, range = 16, notBefore = 5, windup = 0.5,
		recover = 0.5, cooldown = 14, hold = 2.0, reduction = 0.8, arrive = shellSnap,
	}
	Enemies.Defs.StoneTortoise = {
		id = "StoneTortoise",
		name = "Stone Tortoise",
		body = "StoneTortoiseB",
		realm = { "QiCondensation", 6 },
		weight = 6,
		health = 450,
		walkSpeed = 3.5,
		runSpeed = 6,
		aggro = 35,
		leash = 70,
		qiDrop = 48,
		stones = { 10, 18 },
		respawn = 60,
		drops = {
			{ item = "LesserSpiritCore", chance = 0.5 },
			{ item = "GreaterSpiritCore", chance = 0.05 },
		},
		attack = neckSnap,
		attacks = { shellGuard, quakeStomp, neckSnap, shellSnap } :: { Attack },
	} :: Def
end

-- Shadow Mane Wolf (QC6, player 220 HP, power 1.6): a flanker on the wolf-family rig at
-- 1.63x. It circles wide, comes in on a flank (shadowStep, ending in a rake), tears with a
-- double rake, lashes with its mane when you hug it, and fades back after a rend. No howl.
-- Shares of a QC6 player's health: step lane 5%, rake 10%, rend 7% a strike, lash 9%.
if NEW_SHADOW_MANE then
	local shadowRake: Attack = {
		kind = "cone", name = "shadowRake", damage = 22, range = 14, windup = 0.4, recover = 0.9,
		cooldown = 0, radius = 13, angle = 100, chainOnly = true,
	}
	local shadowStep: Attack = {
		kind = "lunge", name = "shadowStep", damage = 12, range = 26, minRange = 11, windup = 0.7,
		recover = 0.9, cooldown = 3.5, length = 26, width = 5, dashSpeed = 45, flankPoint = 8,
		arrive = shadowRake, skid = true,
	}
	local maneRend: Attack = {
		kind = "cone", name = "maneRend", damage = 16, range = 11, windup = 0.6, recover = 1.0,
		cooldown = 2.4, radius = 12, angle = 90, strikes = { { at = 0.35, radius = 12, angle = 90 } },
		hopAfter = true, -- fadeBack: pack.hop
	}
	local maneLash: Attack = {
		kind = "slam", name = "maneLash", damage = 20, range = 8, windup = 0.8, recover = 1.1,
		cooldown = 6, radius = 12,
	}
	Enemies.Defs.ShadowManeWolf = {
		id = "ShadowManeWolf",
		name = "Shadow Mane Wolf",
		body = "ShadowManeWolfB",
		realm = { "QiCondensation", 6 },
		weight = 1.8,
		health = 300,
		walkSpeed = 9,
		runSpeed = 20,
		aggro = 48,
		leash = 100,
		qiDrop = 40,
		stones = { 8, 14 },
		respawn = 40,
		drops = { { item = "LesserSpiritCore", chance = 0.4 } },
		attack = shadowStep,
		attacks = { maneLash, maneRend, shadowStep, shadowRake } :: { Attack },
		pack = {
			hop = { distance = 10, seconds = 0.3, arc = 0.6, cooldown = 3, hits = 99, window = 1 },
			circle = { radius = 18, speed = 7 },
			closeOpener = true, -- rushed under 11 studs, it uses its pool instead of waiting
		},
	} :: Def
end

-- THE THIRD WAVE (testbed only, Config.Wilds.NEW_TOAD / NEW_CENTIPEDE / NEW_RAVEN / NEW_BAT /
-- NEW_SPIDER). Like the second wave, first guesses for the user's playtest, not balance. Reaches
-- are measured from the root centre (RIGS.md has each body's root box and mouth distance).

-- Golden Toad (QC3, player 140 HP): a bog ambusher. Its tongue lashes down a lane and yanks a
-- caught player in (the Fox's snare barrage), the gulp follows only on a catch, its croak
-- staggers a circle, and it lobs a bubbling poison puddle from range. Hops 6 studs back after.
if NEW_TOAD then
	local gulp: Attack = {
		kind = "cone", name = "gulp", damage = 14, range = 9, windup = 0.35, recover = 0.8,
		cooldown = 0, radius = 7, angle = 90, chainOnly = true, hopAfter = true,
	}
	local tongueLash: Attack = {
		kind = "barrage", barrage = "snare", name = "tongueLash", damage = 12, range = 18, minRange = 4,
		windup = 0.7, recover = 0.9, cooldown = 3.5, length = 18, width = 2.4,
		pull = { distance = 4, seconds = 0.3 }, followUpOnHit = "gulp", hopAfter = true,
	}
	local bogCroak: Attack = {
		kind = "howl", name = "bogCroak", damage = 0, range = 10, windup = 1.0, recover = 0.8,
		cooldown = 9, radius = 10, stun = { kind = "stagger", radius = 10, seconds = 0.7 },
	}
	local miasmaLob: Attack = {
		kind = "spit", name = "miasmaLob", damage = 10, range = 24, minRange = 10, windup = 1.0,
		recover = 0.7, cooldown = 6, radius = 4, poison = { stacks = 1, seconds = 4 },
		patch = { seconds = 3, effect = "poison" },
	}
	Enemies.Defs.GoldenToad = {
		id = "GoldenToad",
		name = "Golden Toad",
		body = "GoldenToad",
		realm = { "QiCondensation", 3 },
		weight = 1.2,
		health = 90,
		walkSpeed = 3,
		runSpeed = 7,
		aggro = 30,
		leash = 70,
		qiDrop = 22,
		stones = { 4, 8 },
		respawn = 30,
		drops = { { item = "LesserSpiritCore", chance = 0.3 } },
		attack = tongueLash,
		attacks = { bogCroak, miasmaLob, tongueLash, gulp } :: { Attack },
		pack = {
			hop = { distance = 6, seconds = 0.3, arc = 1.2, cooldown = 3, hits = 99, window = 1 },
			closeOpener = true,
		},
	} :: Def
end

-- Blood Centipede (QC6, player 220 HP): a low grave-hunter, 16 studs long. Pincers first, a wide
-- sweep when flanked, and a burrow dive that runs underground (immune, no damage) to the
-- target's spot and erupts there. It spawns surfaced.
if NEW_CENTIPEDE then
	local erupt: Attack = {
		kind = "slam", name = "erupt", damage = 30, range = 40, windup = 0.7, recover = 1.1,
		cooldown = 0, radius = 6.5, chainOnly = true, unburrow = true, react = "stagger",
	}
	local pincerSnap: Attack = {
		kind = "cone", name = "pincerSnap", damage = 18, range = 14, windup = 0.6, recover = 0.9,
		cooldown = 2.2, radius = 11, angle = 60,
	}
	local coilSweep: Attack = {
		kind = "cone", name = "coilSweep", damage = 22, range = 10, windup = 0.9, recover = 1.0,
		cooldown = 4, radius = 12, angle = 200,
	}
	local burrowDive: Attack = {
		kind = "burrow", name = "burrowDive", damage = 0, range = 32, minRange = 8, windup = 0.5,
		recover = 0.1, cooldown = 9, length = 30, width = 5, dashSpeed = 40, stopPast = 0,
		followUp = "erupt",
	}
	Enemies.Defs.BloodCentipede = {
		id = "BloodCentipede",
		name = "Blood Centipede",
		body = "BloodCentipede",
		realm = { "QiCondensation", 6 },
		weight = 2.2,
		health = 320,
		walkSpeed = 6,
		runSpeed = 18,
		aggro = 40,
		leash = 90,
		qiDrop = 44,
		stones = { 8, 14 },
		respawn = 45,
		drops = { { item = "LesserSpiritCore", chance = 0.45 }, { item = "GreaterSpiritCore", chance = 0.04 } },
		attack = pincerSnap,
		attacks = { coilSweep, burrowDive, pincerSnap, erupt } :: { Attack },
		pack = { closeOpener = true },
	} :: Def
end

-- Flame Raven (QC8, player 290 HP): a hovering fire-crow at head height. It dives in a lane and
-- rakes, perching low and exposed afterwards, fans three ember lobs onto closing circles, and
-- beats a gust that shoves you off and hops it back.
if NEW_RAVEN then
	local talonRake: Attack = {
		kind = "cone", name = "talonRake", damage = 24, range = 9, windup = 0.35, recover = 1.0,
		cooldown = 0, radius = 8, angle = 100, chainOnly = true,
	}
	local talonDive: Attack = {
		kind = "charge", name = "talonDive", damage = 20, range = 24, minRange = 10, windup = 0.8,
		recover = 1.2, cooldown = 5, length = 20, width = 3, dashSpeed = 34, arrive = talonRake,
		skid = true, perch = 1.5,
	}
	local emberFan: Attack = {
		kind = "barrage", barrage = "embers", name = "emberFan", damage = 18, range = 24, minRange = 8,
		windup = 1.0, recover = 0.9, cooldown = 6, radius = 3.5, flank = 9,
	}
	local windGust: Attack = {
		kind = "cone", name = "windGust", damage = 8, range = 9, windup = 0.5, recover = 0.7,
		cooldown = 4, radius = 10, angle = 70, knock = 10, hopAfter = true,
	}
	Enemies.Defs.FlameRaven = {
		id = "FlameRaven",
		name = "Flame Raven",
		body = "FlameRavenB",
		realm = { "QiCondensation", 8 },
		weight = 0.6,
		health = 260,
		walkSpeed = 8,
		runSpeed = 16,
		aggro = 50,
		leash = 100,
		qiDrop = 70,
		stones = { 14, 24 },
		respawn = 60,
		drops = { { item = "LesserSpiritCore", chance = 0.5 }, { item = "GreaterSpiritCore", chance = 0.1 } },
		attack = talonDive,
		attacks = { windGust, talonDive, emberFan, talonRake } :: { Attack },
		pack = {
			hop = { distance = 8, seconds = 0.35, arc = 1.5, cooldown = 3, hits = 99, window = 1 },
			circle = { radius = 12, speed = 8 },
			closeOpener = true,
		},
	} :: Def
end

-- Iron-Winged Blood Bat (QC8, player 290 HP): one of a swarm of 3-4. It stoops in a lane, drinks
-- half of what it deals and flaps away; one bat at a time lets out a shriek that staggers a
-- circle (`slot` shares the attack slot, so shrieks don't stack).
if NEW_BAT then
	local bloodDive: Attack = {
		kind = "charge", name = "bloodDive", damage = 12, range = 16, minRange = 6, windup = 0.6,
		recover = 0.8, cooldown = 3, length = 14, width = 2.5, dashSpeed = 30, leech = 0.5, skid = true,
		hopAfter = true,
	}
	local sonicShriek: Attack = {
		kind = "howl", name = "sonicShriek", damage = 0, range = 10, windup = 1.0, recover = 0.8,
		cooldown = 10, radius = 10, slot = true, stun = { kind = "stagger", radius = 10, seconds = 0.6 },
	}
	Enemies.Defs.BloodBat = {
		id = "BloodBat",
		name = "Iron-Winged Blood Bat",
		body = "BloodBat",
		realm = { "QiCondensation", 8 },
		weight = 0.4,
		health = 60,
		walkSpeed = 10,
		runSpeed = 20,
		aggro = 45,
		leash = 90,
		qiDrop = 20,
		stones = { 3, 6 },
		respawn = 40,
		drops = { { item = "LesserSpiritCore", chance = 0.25 } },
		attack = bloodDive,
		attacks = { sonicShriek, bloodDive } :: { Attack },
		pack = {
			hop = { distance = 8, seconds = 0.3, arc = 2, cooldown = 2, hits = 99, window = 1 },
			circle = { radius = 9, speed = 12 },
			closeOpener = true,
		},
	} :: Def
end

-- Frost Spider (FE1, player 500 HP): a trapper. It webs from range (a slowing patch), closes
-- while you are slowed, bites with a chill and skitters back. Its core is a new higher-grade
-- drop that needs its own item and art; until then it drops the Greater core.
if NEW_SPIDER then
	local slowWeb = { factor = 0.5, seconds = 1.0 }
	local webShot: Attack = {
		kind = "spit", name = "webShot", damage = 25, range = 30, minRange = 12, windup = 0.9,
		recover = 0.7, cooldown = 5, radius = 5, slow = { factor = 0.5, seconds = 2 },
		patch = { seconds = 4, effect = "slow", slow = slowWeb },
	}
	local frostFang: Attack = {
		kind = "lunge", name = "frostFang", damage = 60, range = 14, minRange = 3, windup = 0.7,
		recover = 0.9, cooldown = 3.2, length = 10, width = 3.5, dashSpeed = 38, stopPast = -2, reach = 4,
		slow = { factor = 0.6, seconds = 1.5 }, skid = true, hopAfter = true,
	}
	Enemies.Defs.FrostSpider = {
		id = "FrostSpider",
		name = "Frost Spider",
		body = "FrostSpider",
		realm = { "Foundation", 1 },
		weight = 3,
		health = 420,
		walkSpeed = 6,
		runSpeed = 14,
		aggro = 50,
		leash = 100,
		qiDrop = 110,
		stones = { 30, 50 },
		respawn = 60,
		drops = { { item = "GreaterSpiritCore", chance = 0.6 }, { item = "LesserSpiritCore", chance = 0.5 } },
		attack = webShot,
		attacks = { webShot, frostFang } :: { Attack },
		pack = {
			hop = { distance = 10, seconds = 0.35, arc = 0, cooldown = 3, hits = 99, window = 1 },
			circle = { radius = 18, speed = 6 },
			closeOpener = true,
		},
	} :: Def
end

return Enemies
