--!strict
-- Where and when beasts appear (server: Spawner.luau). Two sources:
--   zones    designated spawns: parts in Workspace.Wilds.Zones with Enemy /
--            Count / Radius attributes, kept topped up with respawns
--   ambient  encounters that find a player roaming open ground away from any
--            zone: a small pack appears a little way off, out of the player's
--            line of sight, and comes for them. Packs are picked by the player's
--            realm, so the wilds keep pace with them wherever they go.
-- World events can lean on ambient spawning (Spawner.boost): more often, bigger
-- packs, while the event runs.
--
-- The safety rules below (height, safe spots) are placeholders until the world
-- layout settles.

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
	MAX_GROUND_Y = 150, -- only below this (the peaks and sect sit far above the wilds)
	SAFE = { -- no ambient encounters within these
		{ at = Vector3.new(0, 9, 500), radius = 90 }, -- the sect gate
	},
}

-- Ambient packs by the player's realm stage (Realms.Stages index): the first
-- row whose `upTo` covers the stage.
Spawns.Encounters = {
	{
		upTo = 3, -- QC1-3: single beasts to learn on
		packs = {
			{ weight = 5, beasts = { SpiritWolf = { 1, 2 } } },
			{ weight = 2, beasts = { VenomSerpent = { 1, 1 } } },
		},
	},
	{
		upTo = 6, -- QC4-6: small packs, the first boar
		packs = {
			{ weight = 4, beasts = { SpiritWolf = { 2, 3 } } },
			{ weight = 3, beasts = { StoneBoar = { 1, 1 } } },
			{ weight = 3, beasts = { VenomSerpent = { 1, 2 } } },
			{ weight = 2, beasts = { SpiritWolf = { 1, 2 }, VenomSerpent = { 1, 1 } } },
		},
	},
	{
		upTo = math.huge, -- QC7 and up: mixed packs
		packs = {
			{ weight = 3, beasts = { SpiritWolf = { 3, 4 } } },
			{ weight = 3, beasts = { StoneBoar = { 1, 2 } } },
			{ weight = 3, beasts = { StoneBoar = { 1, 1 }, SpiritWolf = { 2, 2 } } },
			{ weight = 2, beasts = { VenomSerpent = { 2, 2 }, SpiritWolf = { 1, 2 } } },
		},
	},
} :: { { upTo: number, packs: { Pack } } }

-- The encounter table for a realm stage.
function Spawns.packsFor(stage: number): { Pack }
	for _, row in Spawns.Encounters do
		if stage <= row.upTo then
			return row.packs
		end
	end
	return Spawns.Encounters[#Spawns.Encounters].packs
end

return Spawns
