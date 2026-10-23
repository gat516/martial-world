--!strict
-- Race definitions: what each race is (docs/systems/identity.md). Whether a race
-- can be rolled, picked, unlocked or only tested lives in Availability.luau, not
-- here, so releasing a race is a one-line change there.
--
-- Each race:
--   DisplayName, Description  shown on the character screen
--   Rarity                    a key of CharacterCreator/Rarities.luau (pill colour)
--   Weight                    its share of the join roll (chance = Weight / total
--                             weight of the races that are rolled right now)
--   Icon                      optional rbxassetid:// image ("" = default silhouette)
--   Variants                  optional: the name of a module in Variants/ holding
--                             this race's variants (Beast Folk: "BeastFolk", Spirit Fox:
--                             "SpiritFox"). A race
--                             with variants always has one (rolled or chosen)
--   InnateTraits              trait ids every member gets (Traits/*.luau)
--   Modifiers                 stat modifiers, same kinds as spirit root perks
--                             (Registry.MODIFIERS): health, walk, jump, strike,
--                             guard, technique, growth, regen
--   Mechanics                 optional ids of passives or abilities this race
--                             unlocks, resolved by the server's Traits.mechanics
--                             registry (none are built yet; unknown ids are inert)
--   Cosmetics                 optional accessory ids every member wears
--                             (ReplicatedStorage.Cosmetics, assets/Cosmetics/; Spirit Fox's are on its variants)
--
-- Existing races (Human, Spirit Fox, Stone Spirit, Dragonblood) are placeholders
-- from the character screen; the four after them were added 2026-10-23.

export type Race = {
	DisplayName: string,
	Description: string,
	Rarity: string,
	Weight: number,
	Icon: string,
	Variants: string?,
	InnateTraits: { string }?,
	Modifiers: { [string]: number }?,
	Mechanics: { string }?,
	Cosmetics: { string }?,
}

local Races: { [string]: Race } = {
	Human = {
		DisplayName = "Human",
		Description = "A balanced and adaptable race.",
		Rarity = "Common",
		Weight = 50,
		Icon = "",
		InnateTraits = { "Adaptable" },
	},
	SpiritFox = {
		DisplayName = "Spirit Fox",
		Description = "A race attuned to spiritual energy. Clever and quick, with a gift for illusion.",
		Rarity = "Rare",
		Weight = 12,
		Icon = "",
		Variants = "SpiritFox", -- tail and ear shapes (Plume, Crescent, Wisp); they carry the cosmetics
		-- the fox traits, moved here from the removed Beast Folk Fox variant (user, 2026-10-23)
		InnateTraits = { "FoxCunning" },
		Modifiers = { technique = 0.03 },
	},
	StoneSpirit = {
		DisplayName = "Stone Spirit",
		Description = "Born of mountain stone; slow to stir, hard to break.",
		Rarity = "Uncommon",
		Weight = 10,
		Icon = "",
		Modifiers = { health = 0.05, walk = -1 },
		Cosmetics = { "StoneShards" },
	},
	Dragonblood = {
		DisplayName = "Dragonblood",
		Description = "A faint trace of the true dragons runs in their veins.",
		Rarity = "Legendary",
		Weight = 3,
		Icon = "",
		Cosmetics = { "DragonHorns" },
	},

	BeastFolk = {
		DisplayName = "Beast Folk",
		Description = "Descendants of spirit beasts who took human shape. Each carries the mark of one beast.",
		Rarity = "Uncommon",
		Weight = 15,
		Icon = "",
		Variants = "BeastFolk",
		InnateTraits = { "BeastSenses" },
	},
	DemonicHuman = {
		DisplayName = "Demonic Human",
		Description = "Humans touched by demonic qi. The orthodox sects watch them closely.",
		Rarity = "Rare",
		Weight = 6,
		Icon = "",
		InnateTraits = { "DemonicQi" },
		Cosmetics = { "DemonHorns" },
	},
	Ghost = {
		DisplayName = "Ghost",
		Description = "A lingering soul that refused to pass on, held together by will alone.",
		Rarity = "Epic",
		Weight = 2,
		Icon = "",
		InnateTraits = { "Incorporeal" },
		Cosmetics = { "GhostWisps" },
	},
	Giant = {
		DisplayName = "Giant",
		Description = "Heirs of the ancient giants of the northern wastes. Huge, hardy and slow.",
		Rarity = "Rare",
		Weight = 4,
		Icon = "",
		InnateTraits = { "TitanFrame" },
		Modifiers = { walk = -1 },
	},
}

return Races
