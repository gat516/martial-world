--!strict
-- Named regions of the world and how dangerous each is. Crossing into one
-- announces it on screen (client: RegionBanner), and ambient encounters there
-- (server: Spawner.luau) come from its own pack table in Shared.Spawns.
--   name     shown on the banner
--   subtitle a line of flavour under it
--   realm    the realm it's meant for, { major, minor } on the Realms ladder;
--            nil for safe ground
--   packs    Spawns.Encounters key for ambient packs here (nil: no ambient beasts)
--   rings    flat distance from the sect's centre (origin) it covers: { min, max }
--   above    only at or above this height
--   below    only below this height (the sect and its peaks sit far above the wilds)
-- Regions are checked in order; the first that contains a point wins, and a
-- point in none has no region (no banner change, no ambient beasts).
--
-- The shapes follow Workspace.Map.Ground's rings (RadiusMin/RadiusMax) and are
-- placeholders until the world layout settles: change them here when it does.

export type Region = {
	id: string,
	name: string,
	subtitle: string,
	realm: { any }?,
	packs: string?,
	rings: { number }?,
	above: number?,
	below: number?,
}

local Regions = {}

Regions.List = {
	{
		id = "Sect",
		name = "The Sect",
		subtitle = "Sheltered ground. No beast dares come here.",
		realm = nil,
		packs = nil,
		-- the ground under the peaks too: the spirit pillars' outer feet reach r ~405, and a disciple
		-- who falls off a peak lands in this forest (art/ground/terrain_ground.luau)
		rings = { 0, 410 },
	},
	{
		id = "SectHeights",
		name = "The Sect",
		subtitle = "Sheltered ground. No beast dares come here.",
		realm = nil,
		packs = nil,
		above = 150, -- everything high up (the peaks, the plaza) is the sect's
	},
	{
		id = "InnerWilds",
		name = "Inner Wilds",
		subtitle = "Bamboo and old stone, where young beasts hunt.",
		realm = { "QiCondensation", 1 },
		packs = "Inner",
		rings = { 410, 900 },
		below = 150,
	},
	{
		id = "MiddleWilds",
		name = "Ruined Borderlands",
		subtitle = "Dead villages. The beasts here have eaten cultivators.",
		realm = { "QiCondensation", 5 },
		packs = "Middle",
		rings = { 900, 1600 },
		below = 150,
	},
	{
		id = "OuterWilds",
		name = "Outer Wastes",
		subtitle = "Only those who have laid their foundation return.",
		realm = { "Foundation", 1 },
		packs = "Outer",
		rings = { 1600, 2200 },
		below = 150,
	},
} :: { Region }

function Regions.at(position: Vector3): Region?
	local distance = Vector2.new(position.X, position.Z).Magnitude
	for _, region in Regions.List do
		local rings = region.rings
		local inRing = rings == nil or (distance >= rings[1] and distance < rings[2])
		local inHeight = (region.above == nil or position.Y >= region.above)
			and (region.below == nil or position.Y < region.below)
		if inRing and inHeight then
			return region
		end
	end
	return nil
end

return Regions
