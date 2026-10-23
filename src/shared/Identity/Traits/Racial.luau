--!strict
-- Racial traits: open only to the races, Beast Folk variants or bloodlines named
-- in their Access (docs/systems/identity.md). Every file in Traits/ is one
-- category (its file name), so a new category is a new file; the fields are the
-- same in every file:
--
--   DisplayName, Description  shown in the character window and admin panel
--   Rarity                    a key of CharacterCreator/Rarities.luau
--   Access                    who may own it: "Everyone", or any of
--                             { Races = {...}, Variants = { "BeastFolk.Wolf" },
--                               Bloodlines = {...} } (a match on any list is
--                             enough). One variant listed = exclusive to it;
--                             several = shared between them.
--   Obtain                    how normal play gives it:
--                               "Innate"  from a race or variant's InnateTraits
--                               "Unlock"  granted on its own once Requires is met
--                               "Grant"   only when game code calls Traits.grant
--                                         (a quest, an item, an event)
--   Requires                  optional unlock conditions (Requirements.luau kinds)
--   Excludes                  optional trait ids it can't be held with
--   Modifiers                 stat modifiers (Registry.MODIFIERS)
--   Mechanics                 optional passive or ability ids (server
--                             Traits.mechanics); none are built yet
-- Whether a trait is released, hidden for testing or disabled lives in
-- Availability.luau.

local Racial = {
	-- Human
	Adaptable = {
		DisplayName = "Adaptable",
		Description = "Humans learn anything a little faster.",
		Rarity = "Common",
		Access = { Races = { "Human" } },
		Obtain = "Innate",
		Modifiers = { growth = 0.05 },
	},

	-- Beast Folk, every variant
	BeastSenses = {
		DisplayName = "Beast Senses",
		Description = "Sharp ears and a keen nose, shared by all Beast Folk.",
		Rarity = "Common",
		Access = { Races = { "BeastFolk" } },
		Obtain = "Innate",
		Modifiers = { walk = 0.5 },
	},
	-- Spirit Fox (the fox traits; there's no Beast Folk Fox)
	FoxCunning = {
		DisplayName = "Fox Cunning",
		Description = "A fox's mind turns qi into sharper techniques.",
		Rarity = "Uncommon",
		Access = { Races = { "SpiritFox" } },
		Obtain = "Innate",
		Modifiers = { technique = 0.03 },
	},
	-- one per Beast Folk variant (exclusive)
	WolfStamina = {
		DisplayName = "Wolf Stamina",
		Description = "Wolves recover on the move.",
		Rarity = "Uncommon",
		Access = { Variants = { "BeastFolk.Wolf" } },
		Obtain = "Innate",
		Modifiers = { regen = 0.005 },
	},
	TigerClaws = {
		DisplayName = "Tiger Claws",
		Description = "Every strike lands like a tiger's swipe.",
		Rarity = "Uncommon",
		Access = { Variants = { "BeastFolk.Tiger" } },
		Obtain = "Innate",
		Modifiers = { strike = 0.04 },
	},
	CraneGrace = {
		DisplayName = "Crane Grace",
		Description = "Light bones and a high leap.",
		Rarity = "Uncommon",
		Access = { Variants = { "BeastFolk.Crane" } },
		Obtain = "Innate",
		Modifiers = { jump = 0.1 },
	},
	SerpentScales = {
		DisplayName = "Serpent Scales",
		Description = "Fine scales turn aside a share of every blow.",
		Rarity = "Uncommon",
		Access = { Variants = { "BeastFolk.Serpent" } },
		Obtain = "Innate",
		Modifiers = { guard = 0.03 },
	},
	-- shared between two variants, earned in play
	PackHunter = {
		DisplayName = "Pack Hunter",
		Description = "Predators who have tasted many hunts strike harder.",
		Rarity = "Rare",
		Access = { Variants = { "BeastFolk.Wolf", "BeastFolk.Tiger" } },
		Obtain = "Unlock",
		Requires = { { Kind = "Kills", AtLeast = 100 } },
		Modifiers = { strike = 0.03 },
	},
	-- exclusive, for a later quest or item to grant
	NineTails = {
		DisplayName = "Nine Tails",
		Description = "The legendary sign of an ascended fox.",
		Rarity = "Legendary",
		Access = { Races = { "SpiritFox" } },
		Obtain = "Grant",
		Modifiers = { technique = 0.08 },
	},

	-- Demonic Human
	DemonicQi = {
		DisplayName = "Demonic Qi",
		Description = "Corrupted qi burns hotter in techniques.",
		Rarity = "Rare",
		Access = { Races = { "DemonicHuman" } },
		Obtain = "Innate",
		Modifiers = { technique = 0.05, health = -0.03 },
	},

	-- Ghost
	Incorporeal = {
		DisplayName = "Incorporeal",
		Description = "Half of you is not quite here. Blows pass partly through.",
		Rarity = "Epic",
		Access = { Races = { "Ghost" } },
		Obtain = "Innate",
		Modifiers = { guard = 0.05, health = -0.1 },
	},

	-- Giant
	TitanFrame = {
		DisplayName = "Titan Frame",
		Description = "A giant's body: larger than others, and holding far more life.",
		Rarity = "Rare",
		Access = { Races = { "Giant" } },
		Obtain = "Innate",
		Modifiers = { health = 0.15, size = 0.15 }, -- 15% larger (user, 2026-10-23: 25% was too big)
	},
}

return Racial
