--!strict
-- Technique definitions. All technique balance numbers live here.
-- Kinds and their fields:
--   line   length, width          a wave along the aim direction
--   circle radius                 a burst centred on the caster
--   chain  range, jumps, jumpRange  strikes the aimed enemy, then jumps on
--   zone   offset, radius, tick, seconds  a burning area ahead of the caster
--   buff   reduction, seconds      damage taken is cut by `reduction`
-- damage is per hit (per tick for zones), before realm power and technique level.

-- Windup changes playback speed so release still coincides with the source Hit
-- pose. Movement is a fraction of buffed walking speed; zero roots the caster.
export type Cast = {
	windup: number,
	recovery: number,
	moveMultiplier: number,
	recoveryMoveMultiplier: number,
	dodgeBeforeHit: boolean,
}

export type Def = {
	id: string,
	name: string,
	kind: string,
	cooldown: number,
	damage: number,
	color: Color3,
	blurb: string,
	animation: number, -- which Fists chain animation the cast plays
	hand: string?, -- visuals: "Left" or "Right", the hand that strikes in that animation
	cast: Cast,
	icon: string, -- the image on its HUD button; names only show in the Arts window
	length: number?,
	width: number?,
	radius: number?,
	range: number?,
	jumps: number?,
	jumpRange: number?,
	offset: number?,
	tick: number?,
	seconds: number?,
	reduction: number?,
}

local Techniques = {}

Techniques.Defs = {
	SwordQiWave = {
		id = "SwordQiWave",
		icon = "rbxassetid://100918699109239",
		name = "Sword Qi Wave",
		kind = "line",
		cooldown = 6,
		damage = 28,
		length = 32,
		width = 5,
		color = Color3.fromRGB(150, 230, 255),
		blurb = "A blade of qi that cuts through every enemy in a line.",
		animation = 3,
		hand = "Right", -- Fists.3 cuts flat across the front with the right arm at Hit
		cast = { windup = 0.32, recovery = 0.16, moveMultiplier = 0.35, recoveryMoveMultiplier = 0.7, dodgeBeforeHit = true },
	},
	PalmStrike = {
		id = "PalmStrike",
		icon = "rbxassetid://98382420618802",
		name = "Palm Strike",
		kind = "circle",
		cooldown = 8,
		damage = 24,
		radius = 9,
		color = Color3.fromRGB(255, 210, 120),
		blurb = "A palm of force that blasts everything around you.",
		animation = 4,
		hand = "Left", -- Fists.4 thrusts the left palm forward through Hit
		cast = { windup = 0.38, recovery = 0.18, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
	},
	LightningTalisman = {
		id = "LightningTalisman",
		icon = "rbxassetid://89161711966835",
		name = "Lightning Talisman",
		kind = "chain",
		cooldown = 10,
		damage = 20,
		range = 24,
		jumps = 3,
		jumpRange = 12,
		color = Color3.fromRGB(200, 180, 255),
		blurb = "Lightning that leaps between nearby enemies.",
		animation = 2,
		hand = "Left", -- Fists.2 reaches back over the right shoulder and flings the talisman with the left at Hit
		cast = { windup = 0.25, recovery = 0.12, moveMultiplier = 0.5, recoveryMoveMultiplier = 0.8, dodgeBeforeHit = true },
	},
	IronSkin = {
		id = "IronSkin",
		icon = "rbxassetid://73960875385866",
		name = "Iron Skin",
		kind = "buff",
		cooldown = 15,
		damage = 0,
		reduction = 0.5,
		seconds = 4,
		color = Color3.fromRGB(230, 190, 90),
		blurb = "Harden your body: half damage for a few seconds.",
		animation = 1,
		cast = { windup = 0.20, recovery = 0.10, moveMultiplier = 0.6, recoveryMoveMultiplier = 0.8, dodgeBeforeHit = true },
	},
	FireSeal = {
		id = "FireSeal",
		icon = "rbxassetid://123372008874762",
		name = "Fire Seal",
		kind = "zone",
		cooldown = 12,
		damage = 5,
		offset = 8,
		radius = 8,
		tick = 0.5,
		seconds = 4,
		color = Color3.fromRGB(255, 120, 60),
		blurb = "Seal the ground ahead in flame that burns whoever stands in it.",
		animation = 4,
		hand = "Left", -- Fists.4 thrusts the left palm forward through Hit (same as Palm Strike)
		cast = { windup = 0.50, recovery = 0.20, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
	},
} :: { [string]: Def }

Techniques.Order = { "SwordQiWave", "PalmStrike", "LightningTalisman", "IronSkin", "FireSeal" }

Techniques.SLOTS = 3
Techniques.MAX_LEVEL = 10
Techniques.DAMAGE_PER_LEVEL = 0.08 -- +8% damage per level above 1

-- XP needed to go from `level` to the next.
function Techniques.xpToNext(level: number): number
	return 8 + level * 4
end

function Techniques.damage(def: Def, level: number): number
	return def.damage * (1 + Techniques.DAMAGE_PER_LEVEL * (level - 1))
end

-- Visuals tuning knob: the highest level of each visual tier. A technique's cast
-- plays template `<Id>_T<tier>` from ReplicatedStorage.Effects.<Id>; levels
-- inside a tier step up its particle counts a little (see TechniqueVFX).
Techniques.VISUAL_TIERS = { 3, 6, 9, 10 } -- I: 1-3, II: 4-6, III: 7-9, IV: 10 (mastery)

-- (tier, step): step is how many levels above the tier's first level.
function Techniques.visualTier(level: number): (number, number)
	local first = 1
	for tier, last in Techniques.VISUAL_TIERS do
		if level <= last then
			return tier, math.max(0, level - first)
		end
		first = last + 1
	end
	return #Techniques.VISUAL_TIERS, 0
end

return Techniques
