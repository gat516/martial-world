--!strict
-- Herb definitions shared by the garden, the pouch UI and cultivation.
-- eat.qi is raw energy added at once; eat.buffs are timed effects.
-- aura: cultivation speed each *mature, unharvested* bed of this herb radiates.

export type Buff = { kind: "QiRate" | "WalkSpeed", amount: number, seconds: number }
export type Herb = {
	name: string,
	rarity: string,
	color: Color3,
	growSeconds: number,
	yield: { number },
	aura: number,
	eat: { qi: number?, buffs: { Buff }? },
	blurb: string,
	mutatesTo: string?,
	mutateChance: number?,
}

local Herbs = {}

Herbs.Order = { "SpiritGrass", "CloudMint", "BloodGinseng", "MoonpetalOrchid", "NineLeafLingzhi" }

Herbs.Defs = {
	SpiritGrass = {
		name = "Spirit Grass",
		rarity = "Common",
		color = Color3.fromRGB(150, 235, 120),
		growSeconds = 120,
		yield = { 2, 3 },
		aura = 0.02,
		eat = { buffs = { { kind = "QiRate", amount = 0.15, seconds = 180 } } },
		blurb = "+15% cultivation speed for 3 min",
		mutatesTo = "CloudMint",
		mutateChance = 0.15,
	},
	CloudMint = {
		name = "Cloud Mint",
		rarity = "Uncommon",
		color = Color3.fromRGB(170, 230, 245),
		growSeconds = 300,
		yield = { 2, 3 },
		aura = 0.03,
		eat = {
			buffs = {
				{ kind = "WalkSpeed", amount = 6, seconds = 120 },
				{ kind = "QiRate", amount = 0.1, seconds = 120 },
			},
		},
		blurb = "Lighter steps (+6 speed) and +10% cultivation for 2 min",
		mutatesTo = "BloodGinseng",
		mutateChance = 0.1,
	},
	BloodGinseng = {
		name = "Blood Ginseng",
		rarity = "Rare",
		color = Color3.fromRGB(215, 60, 70),
		growSeconds = 900,
		yield = { 1, 2 },
		aura = 0.05,
		eat = { qi = 300 },
		blurb = "Raw energy: +300 Qi at once",
		mutatesTo = "MoonpetalOrchid",
		mutateChance = 0.08,
	},
	MoonpetalOrchid = {
		name = "Moonpetal Orchid",
		rarity = "Epic",
		color = Color3.fromRGB(225, 205, 255),
		growSeconds = 1800,
		yield = { 1, 2 },
		aura = 0.08,
		eat = { buffs = { { kind = "QiRate", amount = 0.5, seconds = 600 } } },
		blurb = "+50% cultivation speed for 10 min",
		mutatesTo = "NineLeafLingzhi",
		mutateChance = 0.05,
	},
	NineLeafLingzhi = {
		name = "Nine-Leaf Lingzhi",
		rarity = "Legendary",
		color = Color3.fromRGB(255, 175, 60),
		growSeconds = 7200,
		yield = { 1, 1 },
		aura = 0.15,
		eat = { qi = 2500, buffs = { { kind = "QiRate", amount = 1.0, seconds = 900 } } },
		blurb = "+2500 Qi and +100% cultivation for 15 min",
	},
} :: { [string]: Herb }

return Herbs
