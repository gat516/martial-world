--!strict
-- Technique definitions. All technique balance numbers live here.
-- Kinds and their fields:
--   line   length, width          a wave along the aim direction
--   circle radius                 a burst centred on the caster
--   chain  range, jumps, jumpRange  strikes the aimed enemy, then jumps on
--   zone   offset, radius, tick, seconds  a burning area ahead of the caster
--   buff   reduction, seconds      damage taken is cut by `reduction`
-- damage is per hit (per tick for zones), before realm power and technique level.

export type Def = {
	id: string,
	name: string,
	kind: string,
	cooldown: number,
	damage: number,
	color: Color3,
	blurb: string,
	animation: number, -- which Fists chain animation the cast plays
	glyph: string, -- the character on its button
	length: number?,
	width: number?,
	radius: number?,
	range: number?,
	jumps: number?,
	jumpRange: number?,
	offset: number?,
	tick: number?,
	seconds: number?,
	reduction: number?,
}

local Techniques = {}

Techniques.Defs = {
	SwordQiWave = {
		id = "SwordQiWave",
		glyph = "劍",
		name = "Sword Qi Wave",
		kind = "line",
		cooldown = 6,
		damage = 28,
		length = 32,
		width = 5,
		color = Color3.fromRGB(150, 230, 255),
		blurb = "A blade of qi that cuts through every enemy in a line.",
		animation = 3,
	},
	PalmStrike = {
		id = "PalmStrike",
		glyph = "掌",
		name = "Palm Strike",
		kind = "circle",
		cooldown = 8,
		damage = 24,
		radius = 9,
		color = Color3.fromRGB(255, 210, 120),
		blurb = "A palm of force that blasts everything around you.",
		animation = 4,
	},
	LightningTalisman = {
		id = "LightningTalisman",
		glyph = "雷",
		name = "Lightning Talisman",
		kind = "chain",
		cooldown = 10,
		damage = 20,
		range = 24,
		jumps = 3,
		jumpRange = 12,
		color = Color3.fromRGB(200, 180, 255),
		blurb = "Lightning that leaps between nearby enemies.",
		animation = 2,
	},
	IronSkin = {
		id = "IronSkin",
		glyph = "鐵",
		name = "Iron Skin",
		kind = "buff",
		cooldown = 15,
		damage = 0,
		reduction = 0.5,
		seconds = 4,
		color = Color3.fromRGB(230, 190, 90),
		blurb = "Harden your body: half damage for a few seconds.",
		animation = 1,
	},
	FireSeal = {
		id = "FireSeal",
		glyph = "火",
		name = "Fire Seal",
		kind = "zone",
		cooldown = 12,
		damage = 5,
		offset = 8,
		radius = 8,
		tick = 0.5,
		seconds = 4,
		color = Color3.fromRGB(255, 120, 60),
		blurb = "Seal the ground ahead in flame that burns whoever stands in it.",
		animation = 4,
	},
} :: { [string]: Def }

Techniques.Order = { "SwordQiWave", "PalmStrike", "LightningTalisman", "IronSkin", "FireSeal" }

Techniques.SLOTS = 3
Techniques.MAX_LEVEL = 10
Techniques.DAMAGE_PER_LEVEL = 0.08 -- +8% damage per level above 1

-- XP needed to go from `level` to the next.
function Techniques.xpToNext(level: number): number
	return 8 + level * 4
end

function Techniques.damage(def: Def, level: number): number
	return def.damage * (1 + Techniques.DAMAGE_PER_LEVEL * (level - 1))
end

return Techniques
