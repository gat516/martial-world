--!strict
-- Every consumable a player can carry: herbs (from Herbs.luau), spirit cores
-- dropped by beasts, and heavenly treasures that fall during auspicious weather.
-- All item balance numbers live here (herb numbers stay in Herbs.luau).
--
-- use: what consuming one does
--   qi                raw qi into the dantian
--   qiShare           raw qi as a share of the dantian
--   cultivationShare  cultivation as a share of the realm bar (skips the dantian)
--   insight           insight points
--   heal              share of max health restored
--   buffs             timed effects, as herbs have
-- Herbs are stored in data.herbs (the garden fills it); everything else in data.items.

local Herbs = require(script.Parent.Herbs)

export type Use = {
	qi: number?,
	qiShare: number?,
	cultivationShare: number?,
	insight: number?,
	heal: number?,
	buffs: { Herbs.Buff }?,
}
export type Category = "Herb" | "Core" | "Treasure"
export type Item = {
	id: string,
	name: string,
	category: Category,
	rarity: string,
	color: Color3,
	glyph: string, -- the character drawn on its slot
	blurb: string, -- what it does, one line
	lore: string?,
	use: Use,
	treasureWeight: number?, -- treasures: how often this one falls, relative to the others
}

local Items = {}

Items.USE_COOLDOWN = 0.6 -- seconds between uses, per player

Items.Rarities = {
	Common = { order = 1, color = Color3.fromRGB(200, 206, 200) },
	Uncommon = { order = 2, color = Color3.fromRGB(120, 220, 140) },
	Rare = { order = 3, color = Color3.fromRGB(100, 170, 255) },
	Epic = { order = 4, color = Color3.fromRGB(195, 135, 255) },
	Legendary = { order = 5, color = Color3.fromRGB(255, 185, 70) },
} :: { [string]: { order: number, color: Color3 } }

Items.CategoryNames = { Herb = "Spirit herb", Core = "Spirit core", Treasure = "Heavenly treasure" }

local HERB_GLYPHS = {
	SpiritGrass = "草",
	CloudMint = "薄",
	BloodGinseng = "參",
	MoonpetalOrchid = "蘭",
	NineLeafLingzhi = "芝",
}

Items.Defs = {
	LesserSpiritCore = {
		id = "LesserSpiritCore",
		name = "Lesser Spirit Core",
		category = "Core",
		rarity = "Uncommon",
		color = Color3.fromRGB(110, 225, 205),
		glyph = "核",
		blurb = "Crush it to draw out raw qi: +25% of your dantian",
		lore = "The condensed qi of a spirit beast. Wolves, boars and serpents of the wilds carry them.",
		use = { qiShare = 0.25 },
	},
	GreaterSpiritCore = {
		id = "GreaterSpiritCore",
		name = "Greater Spirit Core",
		category = "Core",
		rarity = "Epic",
		color = Color3.fromRGB(255, 120, 90),
		glyph = "魄",
		blurb = "+35% of your realm bar at once, and +30% cultivation for 5 min",
		lore = "A beast king's core, dense enough to refine straight into your foundation.",
		use = { cultivationShare = 0.35, buffs = { { kind = "QiRate", amount = 0.3, seconds = 300 } } },
	},
	HeavenlyDew = {
		id = "HeavenlyDew",
		name = "Heavenly Dew",
		category = "Treasure",
		rarity = "Rare",
		color = Color3.fromRGB(150, 220, 255),
		glyph = "露",
		blurb = "Fills your dantian and heals you fully",
		lore = "Dew gathered where heaven and earth meet. It falls only under auspicious skies.",
		use = { qiShare = 1, heal = 1 },
		treasureWeight = 60,
	},
	CloudPatternJade = {
		id = "CloudPatternJade",
		name = "Cloud-Pattern Jade",
		category = "Treasure",
		rarity = "Epic",
		color = Color3.fromRGB(140, 235, 170),
		glyph = "玉",
		blurb = "Meditate on its patterns: +1 insight",
		lore = "Clouds drift across its surface. Those who study them see a little further.",
		use = { insight = 1 },
		treasureWeight = 30,
	},
	ImmortalPeach = {
		id = "ImmortalPeach",
		name = "Immortal Peach",
		category = "Treasure",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 160, 175),
		glyph = "桃",
		blurb = "+50% of your realm bar, full health, and +100% cultivation for 10 min",
		lore = "A peach from the heavenly orchards, ripened once in three thousand years.",
		use = { cultivationShare = 0.5, heal = 1, buffs = { { kind = "QiRate", amount = 1.0, seconds = 600 } } },
		treasureWeight = 10,
	},
} :: { [string]: Item }

-- Herbs are items too
for _, id in Herbs.Order do
	local herb = Herbs.Defs[id]
	Items.Defs[id] = {
		id = id,
		name = herb.name,
		category = "Herb",
		rarity = herb.rarity,
		color = herb.color,
		glyph = HERB_GLYPHS[id] or "草",
		blurb = herb.blurb,
		lore = "Grown in the beds of your spirit peak.",
		use = { qi = herb.eat.qi, buffs = herb.eat.buffs },
	}
end

Items.Order = table.clone(Herbs.Order)
for _, id in { "LesserSpiritCore", "GreaterSpiritCore", "HeavenlyDew", "CloudPatternJade", "ImmortalPeach" } do
	table.insert(Items.Order, id)
end

Items.Treasures = {} :: { Item }
for _, id in Items.Order do
	if Items.Defs[id].treasureWeight then
		table.insert(Items.Treasures, Items.Defs[id])
	end
end

-- The table a player's count of this item lives in (herbs or items).
function Items.bag(data: { herbs: { [string]: number }, items: { [string]: number } }, id: string): { [string]: number }
	return if Herbs.Defs[id] then data.herbs else data.items
end

function Items.count(data: { herbs: { [string]: number }, items: { [string]: number } }, id: string): number
	return Items.bag(data, id)[id] or 0
end

function Items.rarityColor(item: Item): Color3
	local rarity = Items.Rarities[item.rarity]
	return if rarity then rarity.color else Color3.new(1, 1, 1)
end

return Items
