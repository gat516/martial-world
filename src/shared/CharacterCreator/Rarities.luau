--!strict
-- Rarity tiers shared by races and last names. Add a tier here and use its key in
-- Races.luau or Surnames.luau; the UI reads the label and colour from this table.
-- Order: lowest first, used to sort lists and pick the "rarest" glow.

export type Rarity = { DisplayName: string, Color: Color3, Order: number }

local Rarities: { [string]: Rarity } = {
	Common = { DisplayName = "Common", Color = Color3.fromRGB(150, 146, 134), Order = 1 },
	Uncommon = { DisplayName = "Uncommon", Color = Color3.fromRGB(96, 158, 112), Order = 2 },
	Rare = { DisplayName = "Rare", Color = Color3.fromRGB(150, 118, 196), Order = 3 },
	Epic = { DisplayName = "Epic", Color = Color3.fromRGB(196, 92, 84), Order = 4 },
	Legendary = { DisplayName = "Legendary", Color = Color3.fromRGB(214, 170, 72), Order = 5 },
}

return Rarities
