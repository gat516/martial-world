--!strict
-- Races, rolled by the server when a player first joins (weighted by Weight; the
-- chance is Weight / sum of all weights). Players can't pick one; a paid reroll
-- (Products.RerollRace) rolls again. Add, remove or reweight races here only: the
-- UI shows whatever race the server hands it. Rarity is a key of Rarities.luau.
-- Icon is an optional rbxassetid:// image ("" shows the default silhouette).
-- These are placeholders, not final races.

export type Race = {
	DisplayName: string,
	Description: string,
	Rarity: string,
	Weight: number,
	Icon: string,
}

local Races: { [string]: Race } = {
	Human = {
		DisplayName = "Human",
		Description = "A balanced and adaptable race.",
		Rarity = "Common",
		Weight = 60,
		Icon = "",
	},
	SpiritFox = {
		DisplayName = "Spirit Fox",
		Description = "A race attuned to spiritual energy.",
		Rarity = "Rare",
		Weight = 20,
		Icon = "",
	},
	StoneSpirit = {
		DisplayName = "Stone Spirit",
		Description = "Born of mountain stone; slow to stir, hard to break.",
		Rarity = "Uncommon",
		Weight = 15,
		Icon = "",
	},
	Dragonblood = {
		DisplayName = "Dragonblood",
		Description = "A faint trace of the true dragons runs in their veins.",
		Rarity = "Legendary",
		Weight = 5,
		Icon = "",
	},
}

return Races
