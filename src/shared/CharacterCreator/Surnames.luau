--!strict
-- Last names (family names), rolled by the server: free and automatic on first
-- join, then a paid reroll (Products.RerollSurname). Same weighting as races:
-- chance = Weight / sum of all weights. Rarity is a key of Rarities.luau. Glyph is
-- the optional Chinese character shown beside the name ("" hides it).
-- Placeholder names and rarities; edit freely.

export type Surname = { DisplayName: string, Glyph: string, Rarity: string, Weight: number }

local Surnames: { [string]: Surname } = {
	Li = { DisplayName = "Li", Glyph = "李", Rarity = "Common", Weight = 20 },
	Wang = { DisplayName = "Wang", Glyph = "王", Rarity = "Common", Weight = 20 },
	Zhang = { DisplayName = "Zhang", Glyph = "张", Rarity = "Common", Weight = 20 },
	Chen = { DisplayName = "Chen", Glyph = "陈", Rarity = "Uncommon", Weight = 12 },
	Luo = { DisplayName = "Luo", Glyph = "罗", Rarity = "Uncommon", Weight = 12 },
	Murong = { DisplayName = "Murong", Glyph = "慕容", Rarity = "Rare", Weight = 8 },
	Shangguan = { DisplayName = "Shangguan", Glyph = "上官", Rarity = "Epic", Weight = 5 },
	Ximen = { DisplayName = "Ximen", Glyph = "西门", Rarity = "Legendary", Weight = 3 },
}

return Surnames
