--!strict
-- Spirit Fox variants (docs/systems/identity.md): which tail and ears a Spirit
-- Fox has. They're looks only; the fox traits stay on the race (FoxCunning). The
-- game sees them as race "SpiritFox" with variant "Plume" etc. Whether a variant
-- can be rolled, picked, unlocked or only tested lives in Availability.luau
-- (Variants.SpiritFox). The fields are BeastFolk.luau's.
--
-- Cosmetics are accessories in ServerStorage.Cosmetics (assets/Cosmetics.rbxm,
-- built by art/player/cosmetics/fox/place_fox_cosmetics.luau).

local BeastFolk = require(script.Parent.BeastFolk)

local Variants: { [string]: BeastFolk.Variant } = {
	Plume = {
		DisplayName = "Plume",
		Description = "A full tail that rises behind the back, with sleek upright ears.",
		Rarity = "Common",
		Weight = 45,
		Icon = "",
		Cosmetics = { "FoxTailPlume", "FoxEarsSleek" },
	},
	Crescent = {
		DisplayName = "Crescent",
		Description = "A tail that sweeps out to the side like a new moon, with broad tufted ears.",
		Rarity = "Uncommon",
		Weight = 35,
		Icon = "",
		Cosmetics = { "FoxTailCrescent", "FoxEarsBroad" },
	},
	Wisp = {
		DisplayName = "Wisp",
		Description = "A low tail that hooks up like a flicker of foxfire, with long swept-back ears.",
		Rarity = "Rare",
		Weight = 20,
		Icon = "",
		Cosmetics = { "FoxTailWisp", "FoxEarsLong" },
	},
}

return Variants
