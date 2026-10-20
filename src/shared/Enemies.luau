--!strict
-- Enemy definitions for wilds ring 1. All enemy balance numbers live here.
-- Every attack that hurts is telegraphed on the ground first:
--   lunge   a short line in front (box), then a quick dash along it
--   charge  a long lane (box), then a fast charge down it
--   spit    a circle on the target's position
-- qiDrop is raw qi at QC1; it scales with the receiving player's dantian.

export type Attack = {
	kind: string, -- "lunge" | "charge" | "spit"
	damage: number,
	range: number, -- start the attack when the target is this close
	windup: number, -- seconds the telegraph shows before it resolves
	recover: number, -- seconds after resolving before moving again
	cooldown: number, -- seconds between attacks
	length: number?, -- box: how far it reaches
	width: number?, -- box: how wide
	radius: number?, -- circle
	dashSpeed: number?, -- lunge/charge: studs per second along the box
}

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
	attack: Attack,
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
		respawn = 20,
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
		respawn = 30,
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
		respawn = 25,
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
} :: { [string]: Def }

Enemies.QI_SCALE_EXPONENT = 0.8 -- drop = qiDrop * (dantian / QC1 dantian) ^ this

return Enemies
