--!strict
-- Enemy definitions for wilds ring 1. All enemy balance numbers live here.
-- Every attack that hurts is telegraphed on the ground first:
--   lunge   a short line in front (box), then a quick dash along it
--   charge  a long lane (box), then a fast charge down it
--   spit    a circle on the target's position
--   cone    a wide cone in front (bite)
--   slam    a circle around the attacker
--   summon  no area; calls `count` more of `summons` to its side
-- qiDrop is raw qi at QC1; it scales with the receiving player's dantian.
-- drops: items (Items.luau) each damager may get on a kill, rolled separately.

export type Attack = {
	kind: string, -- "lunge" | "charge" | "spit" | "cone" | "slam" | "summon"
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
}

export type Drop = { item: string, chance: number }

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
	stones: { number }, -- Spirit Stones each damager gets on a kill (min, max)
	boss: boolean?,
	attack: Attack, -- the only attack, or the opener of a boss pattern
	pattern: { Attack }?, -- bosses: attacks used in rotation after `attack`
	summonAt: { number }?, -- bosses: health fractions that trigger a summon
}

local Enemies = {}

Enemies.Defs = {
	SpiritWolf = {
		id = "SpiritWolf",
		name = "Spirit Wolf",
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
	},
	StoneBoar = {
		id = "StoneBoar",
		name = "Stone Boar",
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
		boss = true,
		health = 1500,
		walkSpeed = 8,
		runSpeed = 16,
		aggro = 55,
		leash = 95,
		qiDrop = 160,
		stones = { 60, 90 },
		respawn = 180,
		drops = { { item = "GreaterSpiritCore", chance = 1 }, { item = "LesserSpiritCore", chance = 1 } },
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

Enemies.QI_SCALE_EXPONENT = 0.8 -- drop = qiDrop * (dantian / QC1 dantian) ^ this

return Enemies
