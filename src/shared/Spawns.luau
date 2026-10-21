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
		{ at = Vector3.new(14, 3, 962), radius = 75 }, -- TeleportHome_Middle
	},
}

-- Ambient packs by region (Shared.Regions `packs`). Only the ring-1 beasts
-- exist so far; Middle and Outer reuse them in bigger packs until their own
-- beasts are made.
Spawns.Encounters = {
	Inner = { -- QC1+: single beasts and small packs
		{ weight = 5, beasts = { SpiritWolf = { 1, 2 } } },
		{ weight = 2, beasts = { VenomSerpent = { 1, 1 } } },
		{ weight = 2, beasts = { SpiritWolf = { 2, 3 } } },
		{ weight = 1, beasts = { StoneBoar = { 1, 1 } } },
	},
	Middle = { -- QC5+: mixed packs
		{ weight = 3, beasts = { SpiritWolf = { 3, 4 } } },
		{ weight = 3, beasts = { StoneBoar = { 1, 2 } } },
		{ weight = 3, beasts = { StoneBoar = { 1, 1 }, SpiritWolf = { 2, 2 } } },
		{ weight = 2, beasts = { VenomSerpent = { 2, 2 }, SpiritWolf = { 1, 2 } } },
	},
	Outer = { -- Foundation+: placeholder until Foundation-realm beasts exist
		{ weight = 3, beasts = { StoneBoar = { 2, 3 } } },
		{ weight = 3, beasts = { SpiritWolf = { 3, 4 }, VenomSerpent = { 1, 2 } } },
		{ weight = 1, beasts = { ElderWolfKing = { 1, 1 } } },
	},
} :: { [string]: { Pack } }

return Spawns
