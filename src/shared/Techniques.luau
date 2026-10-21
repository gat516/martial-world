--!strict
-- Technique definitions. All technique balance numbers live here.
-- Kinds and their fields:
--   line   length, width          a wave along the aim direction
--   circle radius                 a burst centred on the caster
--   chain  range, jumps, jumpRange  strikes the aimed enemy, then jumps on
--   zone   offset, radius, tick, seconds  a burning area ahead of the caster
--   buff   seconds, and any of: reduction (damage taken is cut by it),
--          damageBonus / attackSpeed (share added to your damage / M1 speed),
--          radius (with hits: a burst around you at each hit)
-- circle may have `offset`: its centre that far ahead of the caster.
-- damage is per hit (per tick for zones), before realm power and technique level.
-- weapon: the class that must be equipped to cast it (Weapons.Classes), or "Any".
--   Class techniques also scale with that class's grade and Dao comprehension.
--
-- Weapon-skill fields (the class techniques with their own clip):
--   hits        { { time, stop, damage } }: clip seconds of each strike's window
--               (time = Hit, stop = Hit Stop; must match the clip's markers)
--               and its damage. Plays Animations.Techniques.<Id> (the id lives
--               only in assets/Animations.rbxmx); windup runs to the first hit,
--               the active window to the last stop. Later hits resolve on the
--               server at their times, from wherever the caster is then.
--   castSpeed   playback speed (default 1)
--   lunge       studs the caster is driven forward over `lungeWindow` (clip
--               seconds { from, to }, default 0 -> last hit); the server checks it
--   fromStart   line: measured from where the cast began (a dash-slash's path)
--   iframes     invulnerable for the lunge window

-- Windup changes playback speed so release still coincides with the source Hit
-- pose. Movement is a fraction of buffed walking speed; zero roots the caster.
export type Cast = {
	windup: number, -- ignored when the def has `hits` (derived from the first hit)
	recovery: number,
	moveMultiplier: number,
	recoveryMoveMultiplier: number,
	dodgeBeforeHit: boolean,
}

export type Hit = { time: number, stop: number, damage: number }

export type Def = {
	id: string,
	name: string,
	kind: string,
	weapon: string, -- a Weapons class id, or "Any"
	cooldown: number,
	damage: number,
	color: Color3,
	blurb: string,
	animation: number, -- which Fists chain animation the cast plays (when it has no `hits`)
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
	damageBonus: number?,
	attackSpeed: number?,
	hits: { Hit }?,
	castSpeed: number?,
	lunge: number?,
	lungeWindow: { number }?,
	fromStart: boolean?,
	iframes: boolean?,
}

local Techniques = {}

Techniques.Defs = {
	SwordQiWave = {
		id = "SwordQiWave",
		weapon = "Sword",
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
		weapon = "Fist",
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
		weapon = "Any",
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
		weapon = "Any",
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
		weapon = "Any",
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
	-- Class weapon skills (Animations.Techniques.<Id>)
	TwinPhoenixCannon = {
		id = "TwinPhoenixCannon",
		weapon = "Fist",
		icon = "rbxassetid://81953324274209",
		name = "Twin Phoenix Cannon",
		kind = "line",
		cooldown = 9,
		damage = 14,
		length = 18,
		width = 6,
		color = Color3.fromRGB(255, 150, 80),
		blurb = "Two blasts of qi from alternating fists, right then left.",
		animation = 0,
		hand = "Right", -- right fist first, then the left
		hits = { { time = 0.30, stop = 0.3833, damage = 14 }, { time = 0.8333, stop = 0.9167, damage = 14 } },
		castSpeed = 1,
		cast = { windup = 0, recovery = 0.2, moveMultiplier = 0.3, recoveryMoveMultiplier = 0.7, dodgeBeforeHit = true },
	},
	MoonflashDraw = {
		id = "MoonflashDraw",
		weapon = "Sword",
		icon = "rbxassetid://96346324489936",
		name = "Moonflash Draw",
		kind = "line",
		cooldown = 7,
		damage = 30,
		length = 18, -- the 14-stud dash plus the blade's reach
		width = 5,
		color = Color3.fromRGB(200, 225, 255),
		blurb = "Dash through your foes and cut them down as you pass. Untouchable while you dash.",
		animation = 0,
		hand = "Right",
		hits = { { time = 0.0667, stop = 0.2333, damage = 30 } },
		castSpeed = 1,
		lunge = 14,
		lungeWindow = { 0.0667, 0.2333 }, -- the clip's Lunge start/end markers
		fromStart = true,
		iframes = true,
		cast = { windup = 0, recovery = 0.25, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
	},
	RampagingTiger = {
		id = "RampagingTiger",
		weapon = "Saber",
		icon = "rbxassetid://104006341750065",
		name = "Rampaging Tiger Cleave",
		kind = "circle",
		cooldown = 12,
		damage = 9,
		radius = 10,
		color = Color3.fromRGB(255, 120, 90),
		blurb = "A cut, a spinning leap and a cleave on landing that tear through everything around you.",
		animation = 0,
		hand = "Right",
		hits = {
			{ time = 0.4833, stop = 0.6333, damage = 9 },
			{ time = 1.0333, stop = 1.1667, damage = 7 },
			{ time = 1.3167, stop = 1.45, damage = 7 },
			{ time = 1.7833, stop = 1.90, damage = 16 },
		},
		castSpeed = 1,
		lunge = 6,
		lungeWindow = { 0.95, 1.8333 }, -- Leap -> Land
		cast = { windup = 0, recovery = 0.2, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
	},
	HeavenSplitter = {
		id = "HeavenSplitter",
		weapon = "Greatsword",
		icon = "rbxassetid://131580966208055",
		name = "Heaven-Splitting Descent",
		kind = "circle",
		cooldown = 16,
		damage = 60,
		radius = 12,
		offset = 4, -- centred ahead, where the slam lands
		color = Color3.fromRGB(255, 220, 140),
		blurb = "Sweep, launch yourself skyward and bring the greatsword down like falling heaven.",
		animation = 0,
		hand = "Right",
		hits = {
			{ time = 0.1833, stop = 0.3667, damage = 6 },
			{ time = 1.0167, stop = 1.2167, damage = 6 },
			{ time = 2.1167, stop = 2.2333, damage = 60 },
		},
		castSpeed = 1.3,
		lunge = 6,
		lungeWindow = { 1.1, 2.1667 }, -- Leap -> Land
		cast = { windup = 0, recovery = 0.3, moveMultiplier = 0, recoveryMoveMultiplier = 0.5, dodgeBeforeHit = true },
	},
	CrescentSweep = {
		id = "CrescentSweep",
		weapon = "Guandao",
		icon = "rbxassetid://110851099640824",
		name = "Crescent Moon Sweep",
		kind = "circle",
		cooldown = 9,
		damage = 32,
		radius = 11,
		color = Color3.fromRGB(150, 230, 170),
		blurb = "A spinning low sweep of the crescent blade that mows down everything around you.",
		animation = 0,
		hand = "Right",
		hits = { { time = 0.6333, stop = 0.75, damage = 32 } },
		castSpeed = 1,
		cast = { windup = 0, recovery = 0.2, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
	},
	DragonPierce = {
		id = "DragonPierce",
		weapon = "Spear",
		icon = "rbxassetid://123799153426166",
		name = "Dragon-Piercing Thrust",
		kind = "line",
		cooldown = 8,
		damage = 34,
		length = 22,
		width = 4,
		color = Color3.fromRGB(120, 200, 255),
		blurb = "Lunge forward and drive the spear through every enemy in a long line.",
		animation = 0,
		hand = "Right",
		hits = { { time = 0.30, stop = 0.40, damage = 34 } },
		castSpeed = 1,
		lunge = 8,
		lungeWindow = { 0.30, 0.40 }, -- the clip's Lunge start/end markers
		cast = { windup = 0, recovery = 0.25, moveMultiplier = 0, recoveryMoveMultiplier = 0.6, dodgeBeforeHit = true },
	},
	GreatSageAwakening = {
		id = "GreatSageAwakening",
		weapon = "Staff",
		icon = "rbxassetid://115862718192751",
		name = "Great Sage Awakening",
		kind = "buff",
		cooldown = 20,
		damage = 12,
		radius = 8, -- the burst at the strike
		seconds = 8,
		damageBonus = 0.25,
		attackSpeed = 0.15,
		color = Color3.fromRGB(255, 200, 90),
		blurb = "Twirl the staff to awaken your power: more damage and faster strikes for a while.",
		animation = 0,
		hand = "Right",
		hits = { { time = 1.15, stop = 1.25, damage = 12 } },
		castSpeed = 1,
		cast = { windup = 0, recovery = 0.25, moveMultiplier = 0.3, recoveryMoveMultiplier = 0.8, dodgeBeforeHit = true },
	},
} :: { [string]: Def }

Techniques.Order = {
	"SwordQiWave", "PalmStrike", "LightningTalisman", "IronSkin", "FireSeal",
	"TwinPhoenixCannon", "MoonflashDraw", "RampagingTiger", "HeavenSplitter", "CrescentSweep", "DragonPierce", "GreatSageAwakening",
}

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

-- Damage of hit `index` of a multi-hit technique (or its single hit).
function Techniques.hitDamage(def: Def, level: number, index: number): number
	local hit = def.hits and def.hits[index]
	local base = if hit then hit.damage else def.damage
	return base * (1 + Techniques.DAMAGE_PER_LEVEL * (level - 1))
end

-- Whether a technique can be cast with `class` equipped.
function Techniques.allowed(def: Def, class: string): boolean
	return def.weapon == "Any" or def.weapon == class
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
