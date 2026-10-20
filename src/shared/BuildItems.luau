--!strict
-- Every build item, in one place. The id is stable: it's saved in profiles
-- (decor counts, placed records) and names the item's model template in
-- ReplicatedStorage.BuildCatalog, which holds only geometry. Starter pieces on
-- every peak carry the same id in their ItemId attribute.
--
-- Items are bought with Spirit Stones at the Spirit Market on the main peak and
-- kept as an owned count (data.decor). Placing one takes it from the count;
-- storing a piece puts it back.
--
-- Placement fields (see Placement.luau for how they're applied):
--   on        surfaces it may rest on or hang from:
--               floor    any upward-facing surface (ground, floors, tops of pieces)
--               terrain  natural ground only (the plateau, not floors or pieces)
--               wall     a vertical surface; the piece faces out from it
--               ceiling  hangs below a downward-facing surface
--               socket   snaps onto a matching socket another piece offers
--   fits      the socket kind it snaps onto (with "socket" in `on`)
--   sockets   points this piece offers others: kind plus where, in pivot space
--             ("top" means the centre of its top face)
--   edges     connectors that snap end-to-end with the same kind on another piece
--             (fences), in pivot space, facing outward
--   stack     may rest on pieces marked `top`
--   top       other pieces may stand on it
--   soft      may overlap other soft pieces (ground cover, flowers)
--   free      allows free placement (no grid snap)
--   lift      studs it may be raised above its support
--   clearance studs around it that other pieces must keep clear
--   footprint narrows the placement bounds to this many studs (X, Z), centred,
--             so canopies and overhangs don't block placement
--   boxes     replaces the placement bounds with these boxes (pivot space)
-- Limits: `limit` caps how many can be placed on a peak (Build.MAX_ITEMS caps them all).
-- Unlocks: `realm` is the cultivation realm needed to buy it.
-- Effects: `meditation` adds to the meditation multiplier when seated near it;
-- the best piece in range counts (Meditation.luau).

local Realms = require(script.Parent.Realms)

export type Surface = "floor" | "terrain" | "wall" | "ceiling" | "socket"
export type Point = { kind: string, at: CFrame | "top" }
export type Box = { size: Vector3, at: Vector3 }
export type Def = {
	id: string,
	name: string,
	description: string,
	category: string,
	icon: string?, -- slot image; the catalog draws a 3D preview when there's none
	cost: number, -- Spirit Stones
	realm: { major: string, minor: number }?,
	limit: number?,
	on: { Surface },
	fits: string?,
	sockets: { Point }?,
	edges: { Point }?,
	stack: boolean?,
	top: boolean?,
	soft: boolean?,
	free: boolean?,
	lift: number?,
	clearance: number?,
	footprint: Vector2?,
	boxes: { Box }?,
	meditation: number?,
	order: number,
}

local BuildItems = {}

BuildItems.Categories = { "Structures", "Furniture", "Lighting", "Garden", "Nature", "Decor", "Cultivation" }

BuildItems.CategoryNames = {
	Structures = "Structures",
	Furniture = "Furniture",
	Lighting = "Lighting",
	Garden = "Garden",
	Nature = "Nature",
	Decor = "Decor",
	Cultivation = "Cultivation",
}

local FLOOR = { "floor" } :: { Surface }
local GROUND = { "terrain" } :: { Surface }

local list: { Def } = {
	-- Structures
	{
		id = "Dwelling",
		name = "Dwelling",
		description = "A timber hall to call home on your peak.",
		category = "Structures",
		cost = 400,
		limit = 1,
		on = GROUND,
		clearance = 2,
		order = 0,
	},
	{
		id = "SpiritWell",
		name = "Spirit Well",
		description = "A stone well drawing water steeped in mountain qi.",
		category = "Structures",
		cost = 220,
		limit = 1,
		on = GROUND,
		clearance = 1,
		order = 0,
	},
	{
		id = "MarketTent",
		name = "Market Tent",
		description = "A canopy on timber posts, for shade or show.",
		category = "Structures",
		cost = 120,
		limit = 2,
		on = FLOOR,
		order = 0,
	},
	{
		id = "Fence",
		name = "Fence",
		description = "A run of timber fence. Ends snap together, and rotate to turn corners.",
		category = "Structures",
		cost = 15,
		on = FLOOR,
		edges = {
			{ kind = "Fence", at = CFrame.new(0, 0, -6.7) },
			{ kind = "Fence", at = CFrame.new(0, 0, 6.7) * CFrame.Angles(0, math.pi, 0) },
		},
		order = 0,
	},
	{
		id = "GardenFence",
		name = "Garden Fence",
		description = "A low fence around a whole garden.",
		category = "Structures",
		cost = 160,
		limit = 1,
		on = GROUND,
		-- only the four sides count, so beds fit inside
		boxes = {
			{ size = Vector3.new(60.7, 3.3, 1), at = Vector3.new(0, 1.6, 29.85) },
			{ size = Vector3.new(60.7, 3.3, 1), at = Vector3.new(0, 1.6, -29.85) },
			{ size = Vector3.new(1, 3.3, 60.7), at = Vector3.new(29.85, 1.6, 0) },
			{ size = Vector3.new(1, 3.3, 60.7), at = Vector3.new(-29.85, 1.6, 0) },
		},
		order = 0,
	},

	-- Furniture
	{
		id = "Bench",
		name = "Bench",
		description = "A sturdy wooden bench.",
		category = "Furniture",
		cost = 30,
		on = FLOOR,
		order = 0,
	},
	{
		id = "Chair",
		name = "Chair",
		description = "A simple wooden chair.",
		category = "Furniture",
		cost = 20,
		on = FLOOR,
		order = 0,
	},
	{
		id = "SmallTable",
		name = "Small Table",
		description = "A small round table. Things can sit on top.",
		category = "Furniture",
		cost = 30,
		on = FLOOR,
		top = true,
		sockets = { { kind = "Tabletop", at = "top" } },
		order = 0,
	},
	{
		id = "LowTable",
		name = "Low Table",
		description = "A low lacquered table for tea or study.",
		category = "Furniture",
		cost = 35,
		on = FLOOR,
		top = true,
		sockets = { { kind = "Tabletop", at = "top" } },
		order = 0,
	},
	{
		id = "DiningSet",
		name = "Dining Set",
		description = "A long table with stools for guests.",
		category = "Furniture",
		cost = 70,
		on = FLOOR,
		top = true,
		order = 0,
	},
	{
		id = "ScrollShelf",
		name = "Scroll Shelf",
		description = "A shelf for manuals and scrolls.",
		category = "Furniture",
		cost = 45,
		on = FLOOR,
		top = true,
		order = 0,
	},

	-- Lighting
	{
		id = "Lantern",
		name = "Lantern",
		description = "A paper lantern. Hang it from a wall or ceiling, or set it on a table.",
		category = "Lighting",
		cost = 20,
		on = { "floor", "wall", "ceiling", "socket" },
		fits = "Tabletop",
		stack = true,
		free = true,
		lift = 6,
		order = 0,
	},
	{
		id = "StoneLamp",
		name = "Stone Lamp",
		description = "A squat stone lamp that glows at dusk.",
		category = "Lighting",
		cost = 35,
		on = FLOOR,
		order = 0,
	},
	{
		id = "TallStoneLamp",
		name = "Tall Stone Lamp",
		description = "A tall stone lantern to line a path.",
		category = "Lighting",
		cost = 55,
		on = FLOOR,
		order = 0,
	},
	{
		id = "LampPost",
		name = "Lamp Post",
		description = "A wooden post with a hanging lamp.",
		category = "Lighting",
		cost = 45,
		on = FLOOR,
		order = 0,
	},
	{
		id = "JadeLamp",
		name = "Jade Lamp",
		description = "A jade lamp whose light never gutters.",
		category = "Lighting",
		cost = 90,
		realm = { major = "QiCondensation", minor = 5 },
		on = FLOOR,
		order = 0,
	},

	-- Garden
	{
		id = "HerbBed",
		name = "Herb Bed",
		description = "A raised bed for growing spirit herbs.",
		category = "Garden",
		cost = 80,
		limit = 16,
		on = GROUND,
		order = 0,
	},
	{
		id = "Trough",
		name = "Water Trough",
		description = "A trough of clear water.",
		category = "Garden",
		cost = 30,
		on = FLOOR,
		order = 0,
	},
	{
		id = "Bucket",
		name = "Bucket",
		description = "A wooden bucket.",
		category = "Garden",
		cost = 8,
		on = FLOOR,
		stack = true,
		free = true,
		order = 0,
	},

	-- Nature
	{
		id = "Tree",
		name = "Tree",
		description = "A broad leafy tree.",
		category = "Nature",
		cost = 90,
		limit = 6,
		on = GROUND,
		footprint = Vector2.new(6, 6),
		order = 0,
	},
	{
		id = "PineTree",
		name = "Pine Tree",
		description = "An evergreen pine.",
		category = "Nature",
		cost = 70,
		limit = 6,
		on = GROUND,
		footprint = Vector2.new(5, 5),
		order = 0,
	},
	{
		id = "SpiritTree",
		name = "Spirit Tree",
		description = "An ancient tree heavy with qi.",
		category = "Nature",
		cost = 300,
		realm = { major = "Foundation", minor = 1 },
		limit = 1,
		on = GROUND,
		footprint = Vector2.new(8, 8),
		order = 0,
	},
	{
		id = "Bush",
		name = "Bush",
		description = "A round green bush.",
		category = "Nature",
		cost = 12,
		on = GROUND,
		soft = true,
		free = true,
		order = 0,
	},
	{
		id = "Fern",
		name = "Fern",
		description = "A low fern for ground cover.",
		category = "Nature",
		cost = 8,
		on = GROUND,
		soft = true,
		free = true,
		order = 0,
	},
	{
		id = "PinkFlowers",
		name = "Pink Flowers",
		description = "A clump of pink blossoms.",
		category = "Nature",
		cost = 10,
		on = GROUND,
		soft = true,
		free = true,
		order = 0,
	},
	{
		id = "YellowFlowers",
		name = "Yellow Flowers",
		description = "A clump of yellow blossoms.",
		category = "Nature",
		cost = 10,
		on = GROUND,
		soft = true,
		free = true,
		order = 0,
	},
	{
		id = "Rock",
		name = "Rock",
		description = "A weathered boulder.",
		category = "Nature",
		cost = 25,
		on = GROUND,
		free = true,
		order = 0,
	},
	{
		id = "StandingStone",
		name = "Standing Stone",
		description = "An upright stone, old as the mountain.",
		category = "Nature",
		cost = 30,
		on = GROUND,
		free = true,
		order = 0,
	},

	-- Decor
	{
		id = "PottedFlower",
		name = "Potted Flower",
		description = "Flowers in a glazed pot.",
		category = "Decor",
		cost = 15,
		on = FLOOR,
		stack = true,
		order = 0,
	},
	{
		id = "Crate",
		name = "Crate",
		description = "A wooden crate. Stack them.",
		category = "Decor",
		cost = 10,
		on = FLOOR,
		stack = true,
		top = true,
		order = 0,
	},
	{
		id = "Barrel",
		name = "Barrel",
		description = "A banded barrel.",
		category = "Decor",
		cost = 12,
		on = FLOOR,
		stack = true,
		top = true,
		order = 0,
	},
	{
		id = "Hay",
		name = "Hay Bale",
		description = "A bale of straw.",
		category = "Decor",
		cost = 8,
		on = FLOOR,
		stack = true,
		top = true,
		order = 0,
	},
	{
		id = "GrainSack",
		name = "Grain Sack",
		description = "A full sack of grain.",
		category = "Decor",
		cost = 8,
		on = FLOOR,
		stack = true,
		order = 0,
	},
	{
		id = "SackBundle",
		name = "Sack Bundle",
		description = "Sacks piled together.",
		category = "Decor",
		cost = 14,
		on = FLOOR,
		stack = true,
		order = 0,
	},
	{
		id = "Scroll",
		name = "Scroll",
		description = "A rolled scroll. Set it on a table or shelf.",
		category = "Decor",
		cost = 12,
		on = { "floor", "socket" },
		fits = "Tabletop",
		stack = true,
		free = true,
		order = 0,
	},
	{
		id = "Gong",
		name = "Gong",
		description = "A great bronze gong on a frame.",
		category = "Decor",
		cost = 180,
		realm = { major = "Foundation", minor = 1 },
		limit = 1,
		on = FLOOR,
		clearance = 1,
		order = 0,
	},

	-- Cultivation (boosters)
	{
		id = "MeditationCushion",
		name = "Meditation Cushion",
		description = "Meditate beside it: +1.5 to your meditation multiplier.",
		category = "Cultivation",
		cost = 260,
		limit = 2,
		on = FLOOR,
		stack = true,
		meditation = 1.5,
		order = 0,
	},
	{
		id = "MeditationMat",
		name = "Meditation Mat",
		description = "Meditate beside it: +0.75 to your meditation multiplier.",
		category = "Cultivation",
		cost = 140,
		limit = 2,
		on = FLOOR,
		meditation = 0.75,
		order = 0,
	},
	{
		id = "IncenseBurner",
		name = "Incense Burner",
		description = "Calming smoke. Meditate beside it: +0.5 to your meditation multiplier.",
		category = "Cultivation",
		cost = 90,
		limit = 3,
		on = { "floor", "socket" },
		fits = "Tabletop",
		stack = true,
		meditation = 0.5,
		order = 0,
	},
	{
		id = "SpiritStone",
		name = "Spirit Stone",
		description = "A large stone humming with qi. Meditate beside it: +1 to your multiplier.",
		category = "Cultivation",
		cost = 200,
		realm = { major = "QiCondensation", minor = 5 },
		limit = 2,
		on = { "floor", "socket" },
		fits = "Tabletop",
		stack = true,
		meditation = 1,
		order = 0,
	},
}

BuildItems.Defs = {} :: { [string]: Def }
BuildItems.Order = {} :: { string }

local categoryRank: { [string]: number } = {}
for i, c in BuildItems.Categories do
	categoryRank[c] = i
end
for i, def in list do
	def.order = categoryRank[def.category] * 100 + i
	BuildItems.Defs[def.id] = def
	table.insert(BuildItems.Order, def.id)
end

function BuildItems.allows(def: Def, surface: Surface): boolean
	return table.find(def.on, surface) ~= nil
end

-- Whether the player's realm is high enough to buy it, and if not, the realm needed.
function BuildItems.unlocked(def: Def, realm: { major: string, minor: number }): (boolean, string?)
	local need = def.realm
	if not need then
		return true, nil
	end
	if Realms.index(realm.major, realm.minor) >= Realms.index(need.major, need.minor) then
		return true, nil
	end
	return false, Realms.get(need.major, need.minor).name
end

-- How many of this item are placed on a peak, by its placed records.
function BuildItems.countPlaced(placed: { { i: string } }, id: string): number
	local n = 0
	for _, rec in placed do
		if rec.i == id then
			n += 1
		end
	end
	return n
end

return BuildItems
