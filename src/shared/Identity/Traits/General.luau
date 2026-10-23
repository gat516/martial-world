--!strict
-- General traits: open to everyone (or to anyone with a bloodline), earned in
-- play. Fields are the same as in Racial.luau (see its header).

local General = {
	SwiftStep = {
		DisplayName = "Swift Step",
		Description = "Your footwork has sharpened since you first condensed qi.",
		Rarity = "Common",
		Access = "Everyone",
		Obtain = "Unlock",
		Requires = { { Kind = "Realm", AtLeast = "QC3" } },
		Modifiers = { walk = 1 },
	},
	IronBody = {
		DisplayName = "Iron Body",
		Description = "A hundred beasts slain have hardened your flesh.",
		Rarity = "Uncommon",
		Access = "Everyone",
		Obtain = "Unlock",
		Requires = { { Kind = "Kills", AtLeast = 100 } },
		Modifiers = { health = 0.05 },
	},
	BeastSlayer = {
		DisplayName = "Beast Slayer",
		Description = "Felling great beasts has taught you where to strike.",
		Rarity = "Rare",
		Access = "Everyone",
		Obtain = "Unlock",
		Requires = { { Kind = "BossKills", AtLeast = 5 } },
		Excludes = { "Pacifist" },
		Modifiers = { strike = 0.04 },
	},
	Pacifist = {
		DisplayName = "Gentle Heart",
		Description = "Those who tend herbs instead of hunting see their gardens flourish.",
		Rarity = "Uncommon",
		Access = "Everyone",
		Obtain = "Grant",
		Excludes = { "BeastSlayer" },
		Modifiers = { growth = 0.1 },
	},
	-- bloodline-gated (bloodlines aren't built yet; docs/character/bloodline.md)
	DragonScales = {
		DisplayName = "Dragon Scales",
		Description = "An awakened dragon bloodline hardens your skin.",
		Rarity = "Epic",
		Access = { Bloodlines = { "AzureDragon" }, Races = { "Dragonblood" } },
		Obtain = "Grant",
		Modifiers = { guard = 0.04 },
	},
}

return General
