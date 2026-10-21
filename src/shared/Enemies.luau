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
-- Lunges and charges hit each player when the dash front reaches them, not when
-- the windup ends, so the blow lands as the beast arrives.
-- Regular beasts with `attacks` pick from that pool each time (in order: the
-- first whose range band holds the target and whose own cooldown is up), open
-- every engagement with `attack`, and may howl, hop back and circle (`pack`).
-- Every non-boss beast takes an attack slot on its target first
-- (Config.Wilds.ATTACK_SLOTS / SLOT_GAP), so a pack takes turns.
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
	kind: string, -- "lunge" | "charge" | "spit" | "cone" | "slam" | "summon" | "leap" | "howl"
	name: string?, -- shown to clients as the model's Attack attribute (default: kind); name it when one beast has two of a kind
	damage: number,
	range: number, -- start the attack when the target is this close
	windup: number, -- seconds the telegraph shows before it resolves
	recover: number, -- seconds after resolving before moving again
	cooldown: number, -- seconds between attacks
	length: number?, -- box: how far it reaches
	width: number?, -- box: how wide
	radius: number?, -- circle
	dashSpeed: number?, -- lunge/charge: studs per second along the box
	angle: number?, -- cone: degrees
	summons: string?, -- summon: enemy id
	count: number?, -- summon: how many
	maxAlive: number?, -- summon: skip if this many summons are still alive
	minRange: number?, -- attack pools: only start it when the target is at least this far
	notBefore: number?, -- attack pools: not until this many seconds into an engagement
	active: number?, -- leap: flight seconds (the hit lands at the end)
	arc: number?, -- leap: studs the body rises mid-flight (client only)
	hopAfter: boolean?, -- attack pools: hop back once it recovers
}

-- Pack behaviour for regular beasts with an attack pool.
export type Pack = {
	howl: Attack?, -- on first noticing a player (kind "howl", radius = who it calls)
	hop: { distance: number, seconds: number, arc: number, cooldown: number, hits: number, window: number }?,
	circle: { radius: number, speed: number }?, -- orbit the target while waiting to attack
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
	attack: Attack, -- the only attack, the opener of an attack pool, or the opener of a boss pattern
	attacks: { Attack }?, -- regular beasts: the pool it picks from (see the header)
	pack: Pack?,
	body: string?, -- the template in ServerStorage.Enemies to draw (default: id)
	pattern: { Attack }?, -- bosses: attacks used in rotation after `attack`
	summonAt: { number }?, -- bosses: health fractions that trigger a summon
}

local NEW_WOLF = require(script.Parent.Config).Wilds.NEW_WOLF

local Enemies = {}

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
			howl = { kind = "howl", name = "howl", damage = 0, range = 0, windup = 0.8, recover = 0.2, cooldown = 0, radius = 30 },
			hop = { distance = 7, seconds = 0.25, arc = 1.2, cooldown = 4, hits = 3, window = 2 },
			circle = { radius = 10, speed = 8 },
		},
	},
	StoneBoar = {
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

return Enemies
