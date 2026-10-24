--!strict
-- Every plant the garden grows, shared by the garden, the pouch UI, the Herbalist
-- and cultivation. A plant's id is also the herb its harvest gives.
--
-- Plots: each garden build item has a soil (its Soil attribute), and a plant only
-- grows in its own soil: herbs in Herb Beds, lotuses in Lotus Ponds, bamboo and
-- trees in a Spirit Grove. Plants go anywhere on a plot's surface, at least
-- `spacing` studs apart at their stems; as they grow they can sprawl over each
-- other.
--
-- Each planting rolls a size (Herbs.Sizes): most are ordinary, a few grow Large,
-- Huge or Colossal. Weather can swell growing plants further and give them
-- mutations (Herbs.Mutations, Weather.luau `garden`). Size and mutations both
-- multiply the harvest and the plant's aura.
--
-- Fields:
--   soil        the plot kind it grows in (Herbs.Soils)
--   growSeconds real time to mature (growth continues offline)
--   regrowSeconds  plants that stay after harvest fruit again after this long
--   yield       herbs per harvest at size 1, before mutations (min, max)
--   (aura)      no field: a plant's aura is Pacing.Aura BY_TIER x RARITY (Herbs.aura)
--   tier        I-V (1-5): the region it belongs to (I Common, II Spirit, III Rare,
--               IV Treasure, V Heavenly; docs/progression.md)
--   eat         qi = true: raw energy added at once, the tier's share of the
--               eater's current dantian with a floor (Pacing.Herbs EAT_SHARE,
--               EAT_FLOOR; event herbs a PRIZE share; Herbs.eatQi); buffs are timed
--               effects
--   blurb       what eating it does; for qi herbs only the buff part, the qi share
--               is put in front at load
--   scale       mature model size, relative to its HerbModels template
--   spacing     studs between stems when planting
--   seedCost    Spirit Stones per seed at the Herbalist (nil: not sold); at most
--               Pacing.Herbs.STOCK[tier] a player a day
--   soldFrom    the Herbalist sells it only from this stage key on (its band's first)
--   sellPrice   Spirit Stones per herb sold to the Herbalist
--   wild        weather event that makes it sprout wild on owned peaks
--   mutatesTo   a harvest may give a seed of this rarer plant (mutateChance)
--   region      the Herbs.Regions id it belongs to (where its seeds first drop)
--   model       its template in ReplicatedStorage.HerbModels (default: the id)
--   standIn     an existing template of the same soil drawn, tinted to `color`,
--               until `model` is built (docs/systems/garden.md "Models to build")
--
-- Seeds come from the Herbalist (seedCost), harvests (seeds back, mutatesTo), wild
-- sprouts, world events and beasts: a beast drops its region's seeds
-- (Herbs.Regions, Herbs.regionFor).

export type Soil = "bed" | "pond" | "grove"
export type Buff = { kind: "QiRate" | "WalkSpeed", amount: number, seconds: number }
export type Herb = {
	name: string,
	short: string?, -- the hotbar's words (Hotbar.label)
	rarity: string,
	tier: number,
	color: Color3,
	soil: Soil,
	growSeconds: number,
	regrowSeconds: number?,
	yield: { number },
	eat: { qi: boolean?, buffs: { Buff }? },
	blurb: string,
	scale: number,
	spacing: number,
	seedCost: number?,
	soldFrom: string?,
	sellPrice: number,
	wild: string?,
	mutatesTo: string?,
	mutateChance: number?,
	region: string,
	model: string?,
	standIn: string?,
}
-- A region's beast seed pools (Herbs.Regions).
export type SeedRegion = {
	id: string, -- a Regions.luau id where one exists on the map (Deep Wilds and the Far Reaches don't yet)
	name: string,
	tier: number, -- the herb tier its beasts drop most (docs/progression.md ladder)
	from: { any }, -- { major, minor }: the first stage it's for; beasts with no region use the realm
	seeds: { [string]: number }, -- herb id -> weight, every damager's roll
	bossSeeds: { [string]: number }?, -- added to the pool for this region's bosses
}
-- A planting, saved per plot and mirrored to clients as JSON (the plot's Plants
-- attribute). x, z are studs from the plot's PlotAnchor centre. The current
-- cycle began at p (unix time); b is growth seconds weather has added since then;
-- n counts harvests (regrowing plants); s is its size; m its mutations.
export type Plant = { u: string, h: string, x: number, z: number, p: number, b: number, n: number, s: number, m: { string }? }
export type Mutation = { name: string, color: Color3, bonus: number }

local Config = require(script.Parent.Config)
local Pacing = require(script.Parent.Pacing)
local Realms = require(script.Parent.Realms)

local Herbs = {}

Herbs.Soils = {
	bed = { name = "Herb Bed", hint = "Herb seeds grow in Herb Beds." },
	pond = { name = "Lotus Pond", hint = "Lotus seeds grow in a Lotus Pond." },
	grove = { name = "Spirit Grove", hint = "Bamboo and tree seeds grow in a Spirit Grove." },
} :: { [Soil]: { name: string, hint: string } }

-- By tier, then soil: the Herbarium's pages, the Herbalist and the seed picker.
Herbs.Order = {
	-- I Common
	"SpiritGrass",
	"CloudMint",
	"JadeLotus",
	"GhostlampLily",
	"PurpleBamboo",
	-- II Spirit
	"BloodGinseng",
	"MoonpetalOrchid",
	"VioletCloudFungus",
	"DuskwindThistle",
	"SpiritPeach",
	-- III Rare
	"SevenStarGrass",
	"NineLeafLingzhi",
	"ThousandYearGinseng",
	"RiftLotus",
	"EmberheartFruit",
	-- IV Treasure
	"DragonbloodVine",
	"PhoenixPlumeOrchid",
	"SnowpeakLotus",
	"StarfallBamboo",
	-- V Heavenly
	"TribulationThunderGrass",
	"NinefoldHeavenLotus",
	"DaoOriginFruit",
}

Herbs.Defs = {
	SpiritGrass = {
		name = "Spirit Grass",
		short = "Spirit Grass",
		rarity = "Common",
		tier = 1,
		region = "InnerWilds",
		color = Color3.fromRGB(150, 235, 120),
		soil = "bed",
		growSeconds = 120,
		yield = { 2, 3 },
		eat = { buffs = { { kind = "QiRate", amount = 0.1, seconds = 180 } } },
		blurb = "+10% cultivation speed for 3 min",
		scale = 1,
		spacing = 2,
		seedCost = 10,
		sellPrice = 3,
		mutatesTo = "CloudMint",
		mutateChance = 0.15,
	},
	CloudMint = {
		name = "Cloud Mint",
		short = "Cloud Mint",
		rarity = "Uncommon",
		tier = 1,
		region = "InnerWilds",
		color = Color3.fromRGB(170, 230, 245),
		soil = "bed",
		growSeconds = 300,
		yield = { 2, 3 },
		eat = {
			buffs = {
				{ kind = "WalkSpeed", amount = 6, seconds = 120 },
				{ kind = "QiRate", amount = 0.05, seconds = 120 },
			},
		},
		blurb = "Lighter steps (+6 speed) and +5% cultivation for 2 min",
		scale = 1,
		spacing = 2,
		seedCost = 40,
		sellPrice = 9,
		mutatesTo = "BloodGinseng",
		mutateChance = 0.1,
	},
	BloodGinseng = {
		name = "Blood Ginseng",
		short = "Blood Ginseng",
		rarity = "Rare",
		tier = 2,
		region = "OuterWilds",
		color = Color3.fromRGB(215, 60, 70),
		soil = "bed",
		growSeconds = 900,
		yield = { 1, 2 },
		eat = { qi = true },
		blurb = "",
		scale = 1.1,
		spacing = 2.5,
		seedCost = 160,
		sellPrice = 40,
		mutatesTo = "MoonpetalOrchid",
		mutateChance = 0.08,
	},
	MoonpetalOrchid = {
		name = "Moonpetal Orchid",
		short = "Moon Orchid",
		rarity = "Epic",
		tier = 2,
		region = "OuterWilds",
		color = Color3.fromRGB(225, 205, 255),
		soil = "bed",
		growSeconds = 1800,
		yield = { 1, 2 },
		eat = { buffs = { { kind = "QiRate", amount = 0.25, seconds = 600 } } },
		blurb = "+25% cultivation speed for 10 min",
		scale = 1.1,
		spacing = 2.5,
		sellPrice = 110,
		mutatesTo = "NineLeafLingzhi",
		mutateChance = 0.05,
	},
	NineLeafLingzhi = {
		name = "Nine-Leaf Lingzhi",
		short = "Lingzhi",
		rarity = "Legendary",
		tier = 3,
		region = "DeepWilds",
		color = Color3.fromRGB(255, 175, 60),
		soil = "bed",
		growSeconds = 7200,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.3, seconds = 900 } } },
		blurb = "+30% cultivation for 15 min",
		scale = 1.2,
		spacing = 3,
		sellPrice = 600,
		mutatesTo = "DragonbloodVine",
		mutateChance = 0.03,
	},
	VioletCloudFungus = {
		name = "Violet Cloud Fungus",
		short = "Violet Fungus",
		rarity = "Epic",
		tier = 2,
		region = "OuterWilds",
		color = Color3.fromRGB(190, 120, 255),
		soil = "bed",
		growSeconds = 1200,
		yield = { 1, 2 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.15, seconds = 300 } } },
		blurb = "+15% cultivation for 5 min",
		scale = 1,
		spacing = 2.5,
		sellPrice = 150,
		wild = "AuspiciousMist",
	},
	ThousandYearGinseng = {
		name = "Thousand-Year Ginseng",
		short = "Elder Ginseng",
		rarity = "Legendary",
		tier = 3,
		region = "DeepWilds",
		color = Color3.fromRGB(240, 120, 80),
		soil = "bed",
		growSeconds = 14400,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.3, seconds = 1200 } } },
		blurb = "+30% cultivation for 20 min",
		scale = 1.6,
		spacing = 4,
		sellPrice = 3000,
	},
	JadeLotus = {
		name = "Jade Lotus",
		short = "Jade Lotus",
		rarity = "Uncommon",
		tier = 1,
		region = "InnerWilds",
		color = Color3.fromRGB(120, 220, 180),
		soil = "pond",
		growSeconds = 480,
		yield = { 1, 3 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.15, seconds = 180 } } },
		blurb = "+15% cultivation for 3 min",
		scale = 1,
		spacing = 3,
		seedCost = 60,
		sellPrice = 14,
		mutatesTo = "RiftLotus",
		mutateChance = 0.02,
	},
	RiftLotus = {
		name = "Rift Lotus",
		short = "Rift Lotus",
		rarity = "Legendary",
		tier = 3,
		region = "DeepWilds",
		color = Color3.fromRGB(255, 225, 120),
		soil = "pond",
		growSeconds = 3600,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.3, seconds = 900 } } },
		blurb = "+30% cultivation for 15 min",
		scale = 1.2,
		spacing = 3.5,
		sellPrice = 700,
		wild = "HeavenSplit",
		mutatesTo = "SnowpeakLotus",
		mutateChance = 0.03,
	},
	PurpleBamboo = {
		name = "Purple Bamboo",
		short = "Purple Bamboo",
		rarity = "Uncommon",
		tier = 1,
		region = "InnerWilds",
		color = Color3.fromRGB(160, 110, 200),
		soil = "grove",
		growSeconds = 600,
		regrowSeconds = 240,
		yield = { 2, 3 },
		eat = { buffs = { { kind = "WalkSpeed", amount = 4, seconds = 180 } } },
		blurb = "Supple stride: +4 speed for 3 min",
		scale = 1,
		spacing = 3,
		seedCost = 80,
		sellPrice = 8,
		mutatesTo = "SpiritPeach",
		mutateChance = 0.04,
	},
	SpiritPeach = {
		name = "Spirit Peach",
		short = "Spirit Peach",
		rarity = "Rare",
		tier = 2,
		region = "OuterWilds",
		color = Color3.fromRGB(255, 160, 170),
		soil = "grove",
		growSeconds = 2400,
		regrowSeconds = 600,
		yield = { 2, 4 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.15, seconds = 300 } } },
		blurb = "+15% cultivation for 5 min",
		scale = 1,
		spacing = 5,
		seedCost = 400,
		sellPrice = 45,
		mutatesTo = "EmberheartFruit",
		mutateChance = 0.03,
	},
	-- I Common: the Ruined Borderlands' marsh (Serpent Fen, the Drowned Shrine)
	GhostlampLily = {
		name = "Ghostlamp Lily",
		short = "Ghost Lily",
		rarity = "Uncommon",
		tier = 1,
		region = "MiddleWilds",
		color = Color3.fromRGB(170, 240, 210),
		soil = "pond",
		growSeconds = 720,
		yield = { 1, 2 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.1, seconds = 180 } } },
		blurb = "+10% cultivation for 3 min",
		scale = 1,
		spacing = 3,
		sellPrice = 18,
		model = "GhostlampLily",
		standIn = "JadeLotus",
	},
	-- II Spirit: the Outer Wastes' wind-scoured ruins
	DuskwindThistle = {
		name = "Duskwind Thistle",
		short = "Thistle",
		rarity = "Rare",
		tier = 2,
		region = "OuterWilds",
		color = Color3.fromRGB(175, 140, 215),
		soil = "bed",
		growSeconds = 1500,
		yield = { 1, 2 },
		eat = { qi = true, buffs = { { kind = "WalkSpeed", amount = 5, seconds = 180 } } },
		blurb = "a dusk-wind stride: +5 speed for 3 min",
		scale = 1.1,
		spacing = 2.5,
		sellPrice = 55,
		mutatesTo = "SevenStarGrass",
		mutateChance = 0.04,
		model = "DuskwindThistle",
		standIn = "CloudMint",
	},
	-- III Rare: the Deep Wilds
	SevenStarGrass = {
		name = "Seven-Star Grass",
		short = "Star Grass",
		rarity = "Epic",
		tier = 3,
		region = "DeepWilds",
		color = Color3.fromRGB(120, 170, 255),
		soil = "bed",
		growSeconds = 5400,
		yield = { 1, 2 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.25, seconds = 600 } } },
		blurb = "+25% cultivation for 10 min",
		scale = 1,
		spacing = 2.5,
		seedCost = 400,
		soldFrom = "QR6",
		sellPrice = 320,
		mutatesTo = "NineLeafLingzhi",
		mutateChance = 0.05,
		model = "SevenStarGrass",
		standIn = "SpiritGrass",
	},
	EmberheartFruit = {
		name = "Emberheart Fruit",
		short = "Ember Fruit",
		rarity = "Epic",
		tier = 3,
		region = "DeepWilds",
		color = Color3.fromRGB(255, 120, 50),
		soil = "grove",
		growSeconds = 7200,
		regrowSeconds = 2700,
		yield = { 1, 3 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.2, seconds = 600 } } },
		blurb = "+20% cultivation for 10 min",
		scale = 1.1,
		spacing = 5,
		seedCost = 600,
		soldFrom = "QR6",
		sellPrice = 260,
		mutatesTo = "StarfallBamboo",
		mutateChance = 0.02,
		model = "EmberheartFruit",
		standIn = "SpiritPeach",
	},
	-- IV Treasure: the Far Reaches
	DragonbloodVine = {
		name = "Dragonblood Vine",
		short = "Dragon Vine",
		rarity = "Legendary",
		tier = 4,
		region = "FarReaches",
		color = Color3.fromRGB(200, 30, 50),
		soil = "bed",
		growSeconds = 14400,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.4, seconds = 1200 } } },
		blurb = "+40% cultivation for 20 min",
		scale = 1.3,
		spacing = 3.5,
		sellPrice = 1400,
		mutatesTo = "TribulationThunderGrass",
		mutateChance = 0.01,
		model = "DragonbloodVine",
		standIn = "BloodGinseng",
	},
	PhoenixPlumeOrchid = {
		name = "Phoenix Plume Orchid",
		short = "Plume Orchid",
		rarity = "Legendary",
		tier = 4,
		region = "FarReaches",
		color = Color3.fromRGB(255, 150, 60),
		soil = "bed",
		growSeconds = 21600,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.45, seconds = 1200 } } },
		blurb = "+45% cultivation for 20 min",
		scale = 1.3,
		spacing = 3.5,
		sellPrice = 2000,
		model = "PhoenixPlumeOrchid",
		standIn = "MoonpetalOrchid",
	},
	SnowpeakLotus = {
		name = "Snowpeak Lotus",
		short = "Snow Lotus",
		rarity = "Legendary",
		tier = 4,
		region = "FarReaches",
		color = Color3.fromRGB(225, 245, 255),
		soil = "pond",
		growSeconds = 10800,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.35, seconds = 900 } } },
		blurb = "+35% cultivation for 15 min",
		scale = 1.2,
		spacing = 3.5,
		sellPrice = 1200,
		mutatesTo = "NinefoldHeavenLotus",
		mutateChance = 0.01,
		model = "SnowpeakLotus",
		standIn = "JadeLotus",
	},
	StarfallBamboo = {
		name = "Starfall Bamboo",
		short = "Starfall",
		rarity = "Epic",
		tier = 4,
		region = "FarReaches",
		color = Color3.fromRGB(90, 110, 220),
		soil = "grove",
		growSeconds = 14400,
		regrowSeconds = 3600,
		yield = { 2, 3 },
		eat = { qi = true, buffs = { { kind = "WalkSpeed", amount = 8, seconds = 300 } } },
		blurb = "a falling-star stride: +8 speed for 5 min",
		scale = 1.2,
		spacing = 3.5,
		seedCost = 1200,
		soldFrom = "FE4",
		sellPrice = 500,
		mutatesTo = "DaoOriginFruit",
		mutateChance = 0.005,
		model = "StarfallBamboo",
		standIn = "PurpleBamboo",
	},
	-- V Heavenly: seeds only from the Far Reaches' bosses and from mutation
	TribulationThunderGrass = {
		name = "Tribulation Thunder Grass",
		short = "Storm Grass",
		rarity = "Legendary",
		tier = 5,
		region = "FarReaches",
		color = Color3.fromRGB(200, 170, 255),
		soil = "bed",
		growSeconds = 28800,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.5, seconds = 1200 } } },
		blurb = "+50% cultivation for 20 min",
		scale = 1.3,
		spacing = 3.5,
		sellPrice = 5000,
		model = "TribulationThunderGrass",
		standIn = "NineLeafLingzhi",
	},
	NinefoldHeavenLotus = {
		name = "Ninefold Heaven Lotus",
		short = "Heaven Lotus",
		rarity = "Legendary",
		tier = 5,
		region = "FarReaches",
		color = Color3.fromRGB(255, 235, 160),
		soil = "pond",
		growSeconds = 43200,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.5, seconds = 1800 } } },
		blurb = "+50% cultivation for 30 min",
		scale = 1.4,
		spacing = 4,
		sellPrice = 7000,
		model = "NinefoldHeavenLotus",
		standIn = "RiftLotus",
	},
	DaoOriginFruit = {
		name = "Dao Origin Fruit",
		short = "Dao Fruit",
		rarity = "Legendary",
		tier = 5,
		region = "FarReaches",
		color = Color3.fromRGB(200, 255, 230),
		soil = "grove",
		growSeconds = 86400,
		regrowSeconds = 21600,
		yield = { 1, 1 },
		eat = { qi = true, buffs = { { kind = "QiRate", amount = 0.5, seconds = 1800 } } },
		blurb = "+50% cultivation for 30 min",
		scale = 1.3,
		spacing = 6,
		sellPrice = 9000,
		model = "DaoOriginFruit",
		standIn = "SpiritPeach",
	},
} :: { [string]: Herb }

Herbs.TierNumerals = { "I", "II", "III", "IV", "V" }

-- Where beast seeds come from (docs/progression.md "Seeds come from the region").
-- A beast killed inside one of these Regions.luau regions drops from its pool; a
-- beast outside them (the testbed, or a region the map doesn't have yet) uses the
-- last region whose `from` stage is at or below the beast's realm. Bosses add
-- `bossSeeds`. Tier V seeds come only from the Far Reaches' bosses and mutation.
Herbs.Regions = {
	{
		id = "InnerWilds",
		name = "Inner Wilds",
		tier = 1,
		from = { "QiCondensation", 1 },
		seeds = { SpiritGrass = 40, CloudMint = 25, JadeLotus = 15, PurpleBamboo = 15, BloodGinseng = 5 },
	},
	{
		id = "MiddleWilds",
		name = "Ruined Borderlands",
		tier = 1,
		from = { "QiCondensation", 5 },
		seeds = { GhostlampLily = 30, CloudMint = 20, JadeLotus = 20, PurpleBamboo = 15, BloodGinseng = 15 },
	},
	{
		id = "OuterWilds",
		name = "Outer Wastes",
		tier = 2,
		from = { "QiRefining", 1 },
		seeds = { BloodGinseng = 35, DuskwindThistle = 35, SpiritPeach = 20, GhostlampLily = 10 },
	},
	{
		id = "DeepWilds",
		name = "Deep Wilds",
		tier = 3,
		from = { "QiRefining", 6 },
		seeds = { SevenStarGrass = 40, EmberheartFruit = 30, DuskwindThistle = 20, SpiritPeach = 10 },
		bossSeeds = { NineLeafLingzhi = 15 },
	},
	{
		id = "FarReaches",
		name = "The Far Reaches",
		tier = 4,
		from = { "Foundation", 4 },
		seeds = { StarfallBamboo = 35, SnowpeakLotus = 25, DragonbloodVine = 25, PhoenixPlumeOrchid = 15 },
		bossSeeds = { TribulationThunderGrass = 6, NinefoldHeavenLotus = 4, DaoOriginFruit = 2 },
	},
} :: { SeedRegion }

function Herbs.region(id: string?): SeedRegion?
	for _, r in Herbs.Regions do
		if r.id == id then
			return r
		end
	end
	return nil
end

-- A plant's model template: its own (`model`, default the id) in `folder`
-- (ReplicatedStorage.HerbModels, place file only), then in
-- ReplicatedStorage.HerbModelsExtra (assets/HerbModelsExtra.rbxm, the light-pass
-- models of the newer herbs), else its stand-in from `folder`. The second value is
-- true for a stand-in, which Herbs.clone tints to the herb's colour.
function Herbs.template(folder: Instance, id: string): (Model?, boolean)
	local herb = Herbs.Defs[id]
	local name = if herb and herb.model then herb.model else id
	local own = folder:FindFirstChild(name)
	if own and own:IsA("Model") then
		return own, false
	end
	local extra = game:GetService("ReplicatedStorage"):FindFirstChild("HerbModelsExtra")
	local extraOwn = extra and extra:FindFirstChild(name)
	if extraOwn and extraOwn:IsA("Model") then
		return extraOwn, false
	end
	local standIn = herb and herb.standIn and folder:FindFirstChild(herb.standIn)
	if standIn and standIn:IsA("Model") then
		return standIn, true
	end
	return nil, false
end

-- A fresh copy of a plant's model and its template's scale (nil, 1 when none).
function Herbs.clone(folder: Instance, id: string): (Model?, number)
	local template, standIn = Herbs.template(folder, id)
	if not template then
		return nil, 1
	end
	local model = template:Clone()
	local herb = Herbs.Defs[id]
	if standIn and herb then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = d.Color:Lerp(herb.color, 0.55)
			end
		end
	end
	return model, template:GetScale()
end

-- The realm band (a Herbs.Regions entry) a stage belongs to: the last region whose
-- `from` stage is at or below it.
function Herbs.band(major: string, minor: number): SeedRegion
	local at = Realms.index(major, minor)
	local band = Herbs.Regions[1]
	for _, r in Herbs.Regions do
		if at >= Realms.index(r.from[1], r.from[2]) then
			band = r
		end
	end
	return band
end

-- The raw qi eating one gives (0, 0 for buff-only herbs): a share of the eater's
-- current stage dantian (its tier's, or its Pacing.Herbs.PRIZE share) and the
-- least it gives (its tier's floor). With the eater's `stage`, a herb below its
-- band's tier gives only the floor (share 0; event PRIZE herbs keep theirs). The
-- server adds it only up to the dantian's room.
function Herbs.eatQi(id: string, stage: { major: string, minor: number }?): (number, number)
	local herb = Herbs.Defs[id]
	if not (herb and herb.eat.qi) then
		return 0, 0
	end
	local P = Pacing.Herbs
	local floor = P.EAT_FLOOR[herb.tier] or 0
	if P.PRIZE[id] then
		return P.PRIZE[id], floor
	end
	if stage and herb.tier < Herbs.band(stage.major, stage.minor).tier then
		return 0, floor
	end
	return P.EAT_SHARE[herb.tier] or 0, floor
end

-- A plant's aura at size 1 with no mutations, mature (Pacing.Aura BY_TIER x RARITY).
function Herbs.aura(id: string): number
	local herb = Herbs.Defs[id]
	if not herb then
		return 0
	end
	local A = Pacing.Aura
	return (A.BY_TIER[herb.tier] or 0) * (A.RARITY[herb.rarity] or 1)
end

-- Whether the Herbalist sells this seed to a player at this stage (seedCost, soldFrom).
function Herbs.soldAt(id: string, major: string, minor: number): boolean
	local herb = Herbs.Defs[id]
	if not (herb and herb.seedCost) then
		return false
	end
	local from = herb.soldFrom and Realms.ByKey[herb.soldFrom]
	return not from or Realms.index(major, minor) >= Realms.index(from.major, from.minor)
end

-- Seeds of `id` the Herbalist still sells this player today (Pacing.Herbs.STOCK by
-- tier, per UTC day), or nil when it isn't sold to them at all. `herbalist` is the
-- saved { day, bought }; a new day reads as nothing bought.
function Herbs.stockLeft(herbalist: { day: number, bought: { [string]: number } }, id: string, major: string, minor: number, now: number): number?
	if not Herbs.soldAt(id, major, minor) then
		return nil
	end
	local herb = Herbs.Defs[id]
	local bought = if herbalist.day == now // 86400 then herbalist.bought[id] or 0 else 0
	return math.max(0, (Pacing.Herbs.STOCK[herb.tier] or 0) - bought)
end

-- Qi herbs: put the share (and its floor) in front of the buff blurb.
for id, herb in Herbs.Defs do
	local share, floor = Herbs.eatQi(id)
	if share > 0 then
		local outgrow = if Pacing.Herbs.PRIZE[id] then "" else `, and just that past tier {Herbs.TierNumerals[herb.tier]}'s realms`
		local qi = `+{math.floor(share * 100 + 0.5)}% of your dantian in Qi (at least {floor}{outgrow})`
		herb.blurb = if herb.blurb == "" then `Raw energy: {qi} at once` else `{qi} and {herb.blurb}`
	end
end

-- Weather and luck give plants mutations; each adds its bonus to the harvest and
-- aura multiplier (1 + the sum of bonuses).
Herbs.MutationOrder = { "Golden", "Dewy", "Windswept", "Thunderstruck", "Auspicious", "Rainbow", "Heavenlit" }
Herbs.Mutations = {
	Golden = { name = "Golden", color = Color3.fromRGB(255, 205, 70), bonus = 3 },
	Dewy = { name = "Dewy", color = Color3.fromRGB(140, 200, 255), bonus = 0.5 },
	Windswept = { name = "Windswept", color = Color3.fromRGB(200, 235, 220), bonus = 0.3 },
	Thunderstruck = { name = "Thunderstruck", color = Color3.fromRGB(250, 240, 110), bonus = 2 },
	Auspicious = { name = "Auspicious", color = Color3.fromRGB(200, 140, 255), bonus = 1 },
	Rainbow = { name = "Rainbow", color = Color3.fromRGB(255, 150, 210), bonus = 4 },
	Heavenlit = { name = "Heavenlit", color = Color3.fromRGB(255, 240, 190), bonus = 6 },
} :: { [string]: Mutation }
Herbs.GOLDEN_CHANCE = 0.01 -- a fresh planting is Golden

-- Size rolls at planting, by weight. Labels mark the notable ones.
Herbs.Sizes = {
	{ weight = 80, min = 0.85, max = 1.2 },
	{ weight = 15, min = 1.3, max = 1.8, label = "Large" },
	{ weight = 4, min = 2, max = 3, label = "Huge" },
	{ weight = 1, min = 3.5, max = 5, label = "Colossal" },
}
Herbs.MAX_SIZE = 8 -- weather swelling stops here
Herbs.SPROUT_SCALE = 0.25 -- model size at planting, relative to mature

function Herbs.sizeLabel(size: number): string?
	local label = nil
	for _, band in Herbs.Sizes do
		if band.label and size >= band.min then
			label = band.label
		end
	end
	return label
end

function Herbs.multiplier(mutations: { string }?): number
	local total = 1
	for _, id in mutations or {} do
		local m = Herbs.Mutations[id]
		total += if m then m.bonus else 0
	end
	return total
end

-- How long the plant's current cycle takes: growing, or fruiting again.
function Herbs.cycleSeconds(plant: Plant): number
	local herb = Herbs.Defs[plant.h]
	if not herb then
		return math.huge
	end
	return if plant.n > 0 and herb.regrowSeconds then herb.regrowSeconds else herb.growSeconds
end

-- The Grow now tier (Config.Garden.GROW_NOW) for a plant with this long left.
-- Server and client both use it, so the price shown is the price charged.
function Herbs.growNowTier(secondsLeft: number): { upTo: number, robux: number, productId: number }
	local tiers = Config.Garden.GROW_NOW
	for _, tier in tiers do
		if secondsLeft <= tier.upTo then
			return tier
		end
	end
	return tiers[#tiers]
end

-- 0..1 through the current cycle; 1 is ready to harvest.
function Herbs.progress(plant: Plant, now: number): number
	return math.clamp((now - plant.p + plant.b) / Herbs.cycleSeconds(plant), 0, 1)
end

function Herbs.secondsLeft(plant: Plant, now: number): number
	return math.max(0, Herbs.cycleSeconds(plant) - (now - plant.p + plant.b))
end

-- e.g. "Huge Dewy Spirit Grass"
function Herbs.title(plant: Plant): string
	local herb = Herbs.Defs[plant.h]
	local parts = {}
	local label = Herbs.sizeLabel(plant.s)
	if label then
		table.insert(parts, label)
	end
	for _, id in plant.m or {} do
		local m = Herbs.Mutations[id]
		if m then
			table.insert(parts, m.name)
		end
	end
	table.insert(parts, if herb then herb.name else plant.h)
	return table.concat(parts, " ")
end

return Herbs
