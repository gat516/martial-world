--!strict
-- Where and when beasts appear (server: Spawner.luau). Two sources:
--   zones    designated spawns: parts in Workspace.Wilds.Zones with Enemy /
--            Count / Radius attributes, kept topped up with respawns
--   ambient  encounters that find a player roaming open ground away from any
--            zone: a small pack appears a little way off, out of the player's
--            line of sight, and comes for them. Packs come from the region's
--            table below (Shared.Regions `packs`), so deeper regions are deadlier;
--            regions without one (the sect) have no ambient beasts.
-- World events can lean on ambient spawning (Spawner.boost): more often, bigger
-- packs, while the event runs.
--
-- The safe spots below are placeholders until the world layout settles.

export type Pack = {
	weight: number,
	beasts: { [string]: { number } }, -- Enemies.Defs id -> { min, max } count
	-- realm variants (Config.Wilds.VARIANTS; docs/systems/enemies.md "Realm variants"): the
	-- stage range its beasts roll, { lo, hi } keys, leaning toward hi the deeper the encounter
	-- is into its region (Regions `depth`). Each beast's tier follows from the gap to its own
	-- realm (Pacing.Variants), so one range gives a wolf and a boar different tiers. nil: own realm.
	realm: { string }?,
}

local Spawns = {}

Spawns.Ambient = {
	ENABLED = true,
	TICK = 2, -- seconds between checks
	INTERVAL = { 45, 90 }, -- seconds between encounters for one player
	FIRST_DELAY = 20, -- seconds after reaching open ground before the first
	DISTANCE = { 30, 45 }, -- studs from the player a pack appears
	ROAM = 15, -- studs an ambient beast wanders from where it appeared
	MAX_PER_PLAYER = 4, -- live ambient beasts drawn by one player
	MAX_TOTAL = 24, -- live ambient beasts on the server
	DESPAWN_DISTANCE = 150, -- an ambient beast with no player this close...
	DESPAWN_SECONDS = 20, -- ...for this long fades away
	ZONE_MARGIN = 40, -- studs past a designated zone's radius that it covers
	SAFE = { -- no ambient encounters within these
		{ at = Vector3.new(0, 9, 500), radius = 90 }, -- the sect gate
		-- the wilds arrays (Map.Markers.TeleportHome), so no pack lands on an arrival
		{ at = Vector3.new(18, 7, 676), radius = 75 }, -- TeleportHome_Inner
		{ at = Vector3.new(234, 2, 1662), radius = 75 }, -- TeleportHome_Middle
	},
}

-- Ambient packs by region (Shared.Regions `packs`). Only the ring-1 beasts
-- exist so far; Middle and Outer reuse them in bigger packs until their own
-- beasts are made. Bosses never come from packs (Spawner skips them): they
-- have their own zone and respawn timer.
-- Realms: wolves are QC2, serpents QC3, boars QC4 (young below, elite from 3 stages up,
-- apex from 6 or a major realm up), so the Inner Wilds mix young and adult beasts, the
-- Borderlands adult and elite, the Outer Wastes apex.
Spawns.Encounters = {
	Inner = { -- QC1-4: single beasts and small packs; young wolves near the gate
		{ weight = 5, beasts = { SpiritWolf = { 1, 2 } }, realm = { "QC1", "QC3" } },
		{ weight = 2, beasts = { VenomSerpent = { 1, 1 } }, realm = { "QC2", "QC4" } },
		{ weight = 2, beasts = { SpiritWolf = { 2, 3 } }, realm = { "QC2", "QC4" } },
		{ weight = 1, beasts = { StoneBoar = { 1, 1 } }, realm = { "QC3", "QC5" } },
	},
	Middle = { -- QC5-9: mixed packs, elite wolves and serpents deeper in
		{ weight = 3, beasts = { SpiritWolf = { 3, 4 } }, realm = { "QC5", "QC8" } },
		{ weight = 3, beasts = { StoneBoar = { 1, 2 } }, realm = { "QC5", "QC8" } },
		{ weight = 3, beasts = { StoneBoar = { 1, 1 }, SpiritWolf = { 2, 2 } }, realm = { "QC5", "QC7" } },
		{ weight = 2, beasts = { VenomSerpent = { 2, 2 }, SpiritWolf = { 1, 2 } }, realm = { "QC5", "QC8" } },
	},
	Outer = { -- QR1-5: apex ring-1 beasts until the wastes' own exist
		{ weight = 3, beasts = { StoneBoar = { 2, 3 } }, realm = { "QR1", "QR3" } },
		{ weight = 3, beasts = { SpiritWolf = { 3, 4 }, VenomSerpent = { 1, 2 } }, realm = { "QR1", "QR3" } },
		{ weight = 2, beasts = { StoneBoar = { 1, 2 }, SpiritWolf = { 2, 3 } }, realm = { "QR1", "QR3" } },
	},
} :: { [string]: { Pack } }

-- Zone overrides by zone name, on top of the zone's own `Count` attribute and
-- its beast's `respawn`. The onboarding's first fights (the FirstKill and
-- Technique beats, docs/systems/onboarding.md) need 3 kills with no waiting,
-- for a solo player and for a pair: GateWolves on the map, WolfPair in the
-- testbed (its count stays 2, for tuning the fight).
-- `realm` (Config.Wilds.VARIANTS): the stage, or a { lo, hi } range rolled per beast, its
-- beasts cultivate at (realm variants; the part's Realm attribute, "QC2" or "QC2-QC4", works
-- too); `tier` forces a tier (else it follows from the realm). Close to the sect gate is
-- gentle, farther out stronger: the GateWolves are young (their howl only rallies, no leap).
-- Testbed zones keep their beasts' own realms; the admin panel spawns any tier.
Spawns.Zones = {
	GateWolves = { count = 3, respawn = 8, realm = "QC1" }, -- by the gate: young
	WolfPocket = { realm = { "QC2", "QC3" } }, -- adult
	WolfDen = { realm = { "QC3", "QC5" } }, -- the boss ring: adult, now and then an elite
	BoarMeadow = { realm = { "QC3", "QC4" } }, -- young and adult
	BoarField = { realm = { "QC4", "QC5" } }, -- adult
	SerpentMarsh = { realm = { "QC5", "QC7" } }, -- Borderlands: adult and elite
	SerpentFen = { realm = { "QC5", "QC6" } }, -- adult and elite
	WolfPair = { respawn = 8 },
	WolfTiers = { respawn = 8, realm = { "QC1", "QC8" } }, -- testbed: a mix of young, adult, elite and apex wolves
} :: { [string]: { count: number?, respawn: number?, realm: any?, tier: string? } }

return Spawns
