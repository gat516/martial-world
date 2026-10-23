--!strict
-- Beast Folk variants (docs/systems/identity.md). A Beast Folk character is always
-- one of these; the game sees them as race "BeastFolk" with variant "Wolf"
-- etc. There's no Fox variant: foxes are their own race, Spirit Fox, which holds
-- the fox traits (user, 2026-10-23).
-- Whether a variant can be rolled, picked, unlocked or only tested lives in
-- Availability.luau (Variants.BeastFolk), not here.
--
-- Adding a variant (a Bear, a Dragon): add an entry here, an availability line,
-- and any traits it uses in Traits/. Nothing else changes.
--
-- Each variant:
--   DisplayName, Description  shown on the character screen
--   Rarity, Weight            as races: its pill colour and its share of the
--                             variant roll among the variants rolled right now
--   Icon                      optional rbxassetid:// image
--   InnateTraits              trait ids every member of this variant gets, on top
--                             of the race's own
--   Modifiers                 stat modifiers added to the race's (Registry.MODIFIERS)
--   Mechanics                 optional passive or ability ids (server
--                             Traits.mechanics); none are built yet
-- Which other traits a variant may take is set on each trait (its Access in
-- Traits/*.luau names the variants), so a variant's trait pool is every trait
-- open to it plus its innate ones (Registry.traitPool).

export type Variant = {
	DisplayName: string,
	Description: string,
	Rarity: string,
	Weight: number,
	Icon: string,
	InnateTraits: { string }?,
	Modifiers: { [string]: number }?,
	Mechanics: { string }?,
	Cosmetics: { string }?,
}

local Variants: { [string]: Variant } = {
	Wolf = {
		DisplayName = "Wolf",
		Description = "Tireless hunters who fight best with the pack.",
		Rarity = "Common",
		Weight = 30,
		Icon = "",
		InnateTraits = { "WolfStamina" },
		Modifiers = { walk = 1 },
	},
	Tiger = {
		DisplayName = "Tiger",
		Description = "Fierce and proud. Their claws strike harder than most blades.",
		Rarity = "Uncommon",
		Weight = 20,
		Icon = "",
		InnateTraits = { "TigerClaws" },
		Modifiers = { strike = 0.04 },
	},
	Crane = {
		DisplayName = "Crane",
		Description = "Graceful and light, closer to the sky than the earth.",
		Rarity = "Rare",
		Weight = 15,
		Icon = "",
		InnateTraits = { "CraneGrace" },
		Modifiers = { jump = 0.1 },
	},
	Serpent = {
		DisplayName = "Serpent",
		Description = "Patient and venomous, with scales that turn aside blows.",
		Rarity = "Rare",
		Weight = 10,
		Icon = "",
		InnateTraits = { "SerpentScales" },
		Modifiers = { guard = 0.03 },
	},
}

return Variants
