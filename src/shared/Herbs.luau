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
--   aura        cultivation speed each mature, unharvested plant radiates
--   eat         qi is raw energy added at once; buffs are timed effects
--   scale       mature model size, relative to its HerbModels template
--   spacing     studs between stems when planting
--   seedCost    Spirit Stones per seed at the Herbalist (nil: not sold)
--   sellPrice   Spirit Stones per herb sold to the Herbalist
--   wild        weather event that makes it sprout wild on owned peaks
--   mutatesTo   a harvest may give a seed of this rarer plant (mutateChance)

export type Soil = "bed" | "pond" | "grove"
export type Buff = { kind: "QiRate" | "WalkSpeed", amount: number, seconds: number }
export type Herb = {
	name: string,
	rarity: string,
	color: Color3,
	soil: Soil,
	growSeconds: number,
	regrowSeconds: number?,
	yield: { number },
	aura: number,
	eat: { qi: number?, buffs: { Buff }? },
	blurb: string,
	scale: number,
	spacing: number,
	seedCost: number?,
	sellPrice: number,
	wild: string?,
	mutatesTo: string?,
	mutateChance: number?,
}
-- A planting, saved per plot and mirrored to clients as JSON (the plot's Plants
-- attribute). x, z are studs from the plot's PlotAnchor centre. The current
-- cycle began at p (unix time); b is growth seconds weather has added since then;
-- n counts harvests (regrowing plants); s is its size; m its mutations.
export type Plant = { u: string, h: string, x: number, z: number, p: number, b: number, n: number, s: number, m: { string }? }
export type Mutation = { name: string, color: Color3, bonus: number }

local Herbs = {}

Herbs.Soils = {
	bed = { name = "Herb Bed", hint = "Herb seeds grow in Herb Beds." },
	pond = { name = "Lotus Pond", hint = "Lotus seeds grow in a Lotus Pond." },
	grove = { name = "Spirit Grove", hint = "Bamboo and tree seeds grow in a Spirit Grove." },
} :: { [Soil]: { name: string, hint: string } }

Herbs.Order = {
	"SpiritGrass",
	"CloudMint",
	"BloodGinseng",
	"MoonpetalOrchid",
	"NineLeafLingzhi",
	"VioletCloudFungus",
	"ThousandYearGinseng",
	"JadeLotus",
	"RiftLotus",
	"PurpleBamboo",
	"SpiritPeach",
}

Herbs.Defs = {
	SpiritGrass = {
		name = "Spirit Grass",
		rarity = "Common",
		color = Color3.fromRGB(150, 235, 120),
		soil = "bed",
		growSeconds = 120,
		yield = { 2, 3 },
		aura = 0.007,
		eat = { buffs = { { kind = "QiRate", amount = 0.15, seconds = 180 } } },
		blurb = "+15% cultivation speed for 3 min",
		scale = 1,
		spacing = 2,
		seedCost = 10,
		sellPrice = 3,
		mutatesTo = "CloudMint",
		mutateChance = 0.15,
	},
	CloudMint = {
		name = "Cloud Mint",
		rarity = "Uncommon",
		color = Color3.fromRGB(170, 230, 245),
		soil = "bed",
		growSeconds = 300,
		yield = { 2, 3 },
		aura = 0.01,
		eat = {
			buffs = {
				{ kind = "WalkSpeed", amount = 6, seconds = 120 },
				{ kind = "QiRate", amount = 0.1, seconds = 120 },
			},
		},
		blurb = "Lighter steps (+6 speed) and +10% cultivation for 2 min",
		scale = 1,
		spacing = 2,
		seedCost = 40,
		sellPrice = 9,
		mutatesTo = "BloodGinseng",
		mutateChance = 0.1,
	},
	BloodGinseng = {
		name = "Blood Ginseng",
		rarity = "Rare",
		color = Color3.fromRGB(215, 60, 70),
		soil = "bed",
		growSeconds = 900,
		yield = { 1, 2 },
		aura = 0.017,
		eat = { qi = 300 },
		blurb = "Raw energy: +300 Qi at once",
		scale = 1.1,
		spacing = 2.5,
		seedCost = 160,
		sellPrice = 40,
		mutatesTo = "MoonpetalOrchid",
		mutateChance = 0.08,
	},
	MoonpetalOrchid = {
		name = "Moonpetal Orchid",
		rarity = "Epic",
		color = Color3.fromRGB(225, 205, 255),
		soil = "bed",
		growSeconds = 1800,
		yield = { 1, 2 },
		aura = 0.027,
		eat = { buffs = { { kind = "QiRate", amount = 0.5, seconds = 600 } } },
		blurb = "+50% cultivation speed for 10 min",
		scale = 1.1,
		spacing = 2.5,
		sellPrice = 110,
		mutatesTo = "NineLeafLingzhi",
		mutateChance = 0.05,
	},
	NineLeafLingzhi = {
		name = "Nine-Leaf Lingzhi",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 175, 60),
		soil = "bed",
		growSeconds = 7200,
		yield = { 1, 1 },
		aura = 0.05,
		eat = { qi = 2500, buffs = { { kind = "QiRate", amount = 1.0, seconds = 900 } } },
		blurb = "+2500 Qi and +100% cultivation for 15 min",
		scale = 1.2,
		spacing = 3,
		sellPrice = 600,
	},
	VioletCloudFungus = {
		name = "Violet Cloud Fungus",
		rarity = "Epic",
		color = Color3.fromRGB(190, 120, 255),
		soil = "bed",
		growSeconds = 1200,
		yield = { 1, 2 },
		aura = 0.03,
		eat = { qi = 600, buffs = { { kind = "QiRate", amount = 0.3, seconds = 300 } } },
		blurb = "+600 Qi and +30% cultivation for 5 min",
		scale = 1,
		spacing = 2.5,
		sellPrice = 150,
		wild = "AuspiciousMist",
	},
	ThousandYearGinseng = {
		name = "Thousand-Year Ginseng",
		rarity = "Legendary",
		color = Color3.fromRGB(240, 120, 80),
		soil = "bed",
		growSeconds = 14400,
		yield = { 1, 1 },
		aura = 0.1,
		eat = { qi = 8000, buffs = { { kind = "QiRate", amount = 1.5, seconds = 1200 } } },
		blurb = "+8000 Qi and +150% cultivation for 20 min",
		scale = 1.6,
		spacing = 4,
		sellPrice = 3000,
	},
	JadeLotus = {
		name = "Jade Lotus",
		rarity = "Uncommon",
		color = Color3.fromRGB(120, 220, 180),
		soil = "pond",
		growSeconds = 480,
		yield = { 1, 3 },
		aura = 0.012,
		eat = { qi = 120, buffs = { { kind = "QiRate", amount = 0.2, seconds = 180 } } },
		blurb = "+120 Qi and +20% cultivation for 3 min",
		scale = 1,
		spacing = 3,
		seedCost = 60,
		sellPrice = 14,
		mutatesTo = "RiftLotus",
		mutateChance = 0.02,
	},
	RiftLotus = {
		name = "Rift Lotus",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 225, 120),
		soil = "pond",
		growSeconds = 3600,
		yield = { 1, 1 },
		aura = 0.06,
		eat = { qi = 3000, buffs = { { kind = "QiRate", amount = 0.75, seconds = 900 } } },
		blurb = "+3000 Qi and +75% cultivation for 15 min",
		scale = 1.2,
		spacing = 3.5,
		sellPrice = 700,
		wild = "HeavenSplit",
	},
	PurpleBamboo = {
		name = "Purple Bamboo",
		rarity = "Uncommon",
		color = Color3.fromRGB(160, 110, 200),
		soil = "grove",
		growSeconds = 600,
		regrowSeconds = 240,
		yield = { 2, 3 },
		aura = 0.01,
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
		rarity = "Rare",
		color = Color3.fromRGB(255, 160, 170),
		soil = "grove",
		growSeconds = 2400,
		regrowSeconds = 600,
		yield = { 2, 4 },
		aura = 0.03,
		eat = { qi = 400, buffs = { { kind = "QiRate", amount = 0.25, seconds = 300 } } },
		blurb = "+400 Qi and +25% cultivation for 5 min",
		scale = 1,
		spacing = 5,
		seedCost = 400,
		sellPrice = 45,
	},
} :: { [string]: Herb }

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
