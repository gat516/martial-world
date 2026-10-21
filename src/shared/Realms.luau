--!strict
-- Realm ladder, in order. The numbers come from Pacing.luau (the master
-- progression tuning): its curve, with that stage's Pacing.Adjust entry and
-- Pacing.Global applied. Tune there, not here.
--   key        the stage id Pacing uses ("QC1".."QC9", "FE1")
--   bar        cultivation needed to fill this stage's realm bar
--   dantian    raw qi the dantian holds
--   passive    cultivation per second from sitting (online or offline), before buffs
--   health     max health
--   power      damage multiplier
--   insight    insight needed to break through out of this stage (0 = none)
--   refine     circulation efficiency multiplier
--   gather     raw qi income multiplier (qi nodes, daily qi, enemy kills)
--   difficulty circulation minigame difficulty (0 easy .. 1 hard)
--   levels     most levels in a circulation run
--   tribulation the tribulation that guards a major breakthrough out of this stage
--   beastHealth, beastDamage  multipliers for demon beasts whose realm is this stage

local Pacing = require(script.Parent.Pacing)

export type Stage = {
	key: string,
	beat: string,
	major: string,
	minor: number,
	name: string,
	bar: number,
	dantian: number,
	passive: number,
	health: number,
	power: number,
	insight: number,
	refine: number,
	gather: number,
	difficulty: number,
	levels: number,
	tribulation: Pacing.Tribulation?,
	beastHealth: number,
	beastDamage: number,
}

local MAJOR_NAMES = {
	QiCondensation = "Qi Condensation",
	Foundation = "Foundation Establishment",
}

local Realms = {}

Realms.Stages = {} :: { Stage }
Realms.ByKey = {} :: { [string]: Stage }

local G = Pacing.Global
for i, row in Pacing.Curve do
	local adjust = Pacing.Adjust[row.key] or {}
	local tribulation = row.tribulation
	if tribulation then
		local merged = table.clone(tribulation) :: any
		for field, value in adjust.tribulation or {} do
			merged[field] = value
		end
		merged.damageShare *= G.TRIBULATION_DAMAGE
		tribulation = merged
	end
	local stage: Stage = {
		key = row.key,
		beat = row.beat,
		major = row.major,
		minor = row.minor,
		name = if row.major == "Foundation" then MAJOR_NAMES.Foundation else `{MAJOR_NAMES[row.major]} {row.minor}`,
		bar = math.max(1, math.floor(row.bar * (adjust.bar or 1) * G.BAR + 0.5)),
		dantian = row.dantian,
		passive = row.passive * (adjust.passive or 1) * G.PASSIVE,
		health = math.floor(row.health * (adjust.health or 1) + 0.5),
		power = row.power * (adjust.power or 1),
		insight = adjust.insight or row.insight,
		refine = (adjust.refine or 1) * G.REFINE,
		gather = (adjust.gather or 1) * G.GATHER,
		difficulty = math.clamp(row.difficulty + (adjust.difficulty or 0) + G.DIFFICULTY, -0.5, 1),
		levels = adjust.levels or row.levels,
		tribulation = tribulation,
		beastHealth = (adjust.beastHealth or 1) * G.BEAST_HEALTH,
		beastDamage = (adjust.beastDamage or 1) * G.BEAST_DAMAGE,
	}
	Realms.Stages[i] = stage
	Realms.ByKey[row.key] = stage
end

-- The stage with this display name (the player's `Realm` attribute), or nil.
function Realms.byName(name: any): Stage?
	for _, s in Realms.Stages do
		if s.name == name then
			return s
		end
	end
	return nil
end

function Realms.index(major: string, minor: number): number
	for i, s in Realms.Stages do
		if s.major == major and s.minor == minor then
			return i
		end
	end
	return 1
end

function Realms.get(major: string, minor: number): Stage
	return Realms.Stages[Realms.index(major, minor)]
end

-- The stage after this one, or nil at the top of the MVP ladder.
function Realms.after(major: string, minor: number): Stage?
	return Realms.Stages[Realms.index(major, minor) + 1]
end

-- Raw qi an enemy with this qiDrop (its QC1 value) gives a player at `stage`.
function Realms.enemyQi(qiDrop: number, stage: Stage): number
	local scale = (stage.dantian / Realms.Stages[1].dantian) ^ Pacing.Income.ENEMY_QI_EXPONENT
	return math.floor(qiDrop * scale * stage.gather + 0.5)
end

-- Raw qi from one qi node gather at `stage` (before the dantian's room caps it).
function Realms.nodeQi(stage: Stage): number
	return math.floor(stage.dantian * Pacing.Income.NODE_SHARE * stage.gather)
end

-- The stage a demon beast cultivates at (Enemies `realm` = { major, minor }), for
-- its beastHealth / beastDamage multipliers.
function Realms.ofBeast(realm: { any }): Stage
	return Realms.get(realm[1], realm[2])
end

return Realms
