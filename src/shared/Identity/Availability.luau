--!strict
-- Who can get what: the one place to release, hide or switch off races, Beast
-- Folk variants and traits, and to say how each is obtained (docs/systems/identity.md).
-- Definitions (names, stats, traits) live in Races.luau, Variants/ and Traits/.
--
-- Status
--   "Released"  in the game for everyone, through its Acquire methods
--   "Hidden"    implemented but unreleased: never rolled, offered or unlocked for
--               normal players and left off the character screen; admins can
--               still assign it for testing (admin panel)
--   "Disabled"  switched off: nobody gets it, admins included, and anyone who
--               already has it keeps the record but gets no effect (a race or
--               variant is replaced on their next join)
-- Acquire (races and variants; one method or a list)
--   "Roll"      in the free join roll and the paid reroll, weighted by Weight
--   "Select"    the player may pick it on the character screen
--   "Unlock"    the player may pick it once Requires is met
-- Requires: unlock conditions, a list of Requirements.luau kinds, all needed.
--   e.g. { { Kind = "Realm", AtLeast = "QC5" }, { Kind = "Quest", Id = "..." } }
--
-- To release something that's Hidden: set Status = "Released" and give it the
-- Acquire (and Requires) it should have. Nothing else changes.

export type Entry = {
	Status: string,
	Acquire: (string | { string })?,
	Requires: { any }?,
}

local Availability = {}

-- Races: anything not listed here counts as Hidden.
Availability.Races = {
	Human = { Status = "Released", Acquire = "Roll" },
	SpiritFox = { Status = "Released", Acquire = "Roll" },
	StoneSpirit = { Status = "Released", Acquire = "Roll" },
	Dragonblood = { Status = "Released", Acquire = "Roll" },
	BeastFolk = { Status = "Released", Acquire = "Roll" },
	DemonicHuman = { Status = "Released", Acquire = "Roll" },
	Ghost = { Status = "Released", Acquire = "Roll" },
	Giant = { Status = "Released", Acquire = "Roll" },
} :: { [string]: Entry }

-- Variants, by race (the race's Variants module). Anything not listed counts as
-- Hidden. A variant is only reached through its race: rolling Beast Folk rolls
-- one of its Roll variants; Select and Unlock variants can be picked by a Beast
-- Folk player on the character screen.
Availability.Variants = {
	BeastFolk = {
		Fox = { Status = "Released", Acquire = "Roll" },
		Wolf = { Status = "Released", Acquire = "Roll" },
		Tiger = { Status = "Released", Acquire = "Roll" },
		Crane = { Status = "Released", Acquire = "Roll" },
		-- not finished yet: testable by admins only (user, 2026-10-23). To release:
		-- Status = "Released", Acquire = "Unlock", Requires = { ... }.
		Serpent = { Status = "Hidden", Acquire = "Unlock", Requires = { { Kind = "Realm", AtLeast = "QC5" } } },
	},
} :: { [string]: { [string]: Entry } }

-- Traits: anything not listed is Released (its Obtain and Requires live on the
-- trait itself, in Traits/).
Availability.Traits = {
	NineTails = { Status = "Hidden" },
	DragonScales = { Status = "Hidden" }, -- waits for bloodlines
} :: { [string]: Entry }

return Availability
