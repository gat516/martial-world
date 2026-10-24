--!strict
-- Realm ladder, in order. The numbers come from Pacing.luau (the master
-- progression tuning): its curve, with that stage's Pacing.Adjust entry and
-- Pacing.Global applied. Tune there, not here.
--   key        the stage id Pacing uses ("QC1".."QC9", "QR1".."QR9", "FE1".."FE9")
--   bar        cultivation needed to fill this stage's realm bar
--   dantian    raw qi the dantian holds
--   passive    cultivation per second from sitting (online or offline), before buffs
--   health     max health
--   power      damage multiplier
--   refine     circulation efficiency multiplier
--   gather     raw qi income multiplier (qi nodes, daily qi, enemy kills)
--   difficulty circulation minigame difficulty (0 easy .. 1 hard)
--   levels     most levels in a circulation run
--   tribulation the tribulation a heaven-defying player faces on the major breakthrough out
--              of this stage (everyone else breaks through without one; Cultivation.heavenDefying)
--   beastHealth, beastDamage  multipliers for demon beasts whose realm is this stage:
--              the curve's power and health over Pacing.BeastBaseline's, times Adjust and Global
--   combatQi   the combat qi pool's size (Pacing.CombatQi.MAX)

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
	refine: number,
	gather: number,
	difficulty: number,
	levels: number,
	tribulation: Pacing.Tribulation?,
	beastHealth: number,
	beastDamage: number,
	combatQi: number,
}

local MAJOR_NAMES = {
	QiCondensation = "Qi Condensation",
	QiRefining = "Qi Refining",
	Foundation = "Foundation Establishment",
}

local Realms = {}

Realms.Stages = {} :: { Stage }
Realms.ByKey = {} :: { [string]: Stage }
local DEFIER: { [Stage]: Stage } = {} -- each stage's heaven-defier copy

-- Majors in ladder order, for realm suppression.
Realms.MAJORS = {} :: { string }
for _, row in Pacing.Curve do
	if Realms.MAJORS[#Realms.MAJORS] ~= row.major then
		table.insert(Realms.MAJORS, row.major)
	end
end

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
		name = `{MAJOR_NAMES[row.major]} {row.minor}`,
		bar = math.max(1, math.floor(row.bar * (adjust.bar or 1) * G.BAR + 0.5)),
		dantian = row.dantian,
		passive = row.passive * (adjust.passive or 1) * G.PASSIVE,
		health = math.floor(row.health * (adjust.health or 1) + 0.5),
		power = row.power * (adjust.power or 1),
		refine = (adjust.refine or 1) * G.REFINE,
		gather = (row.gather or 1) * (adjust.gather or 1) * G.GATHER,
		difficulty = math.clamp(row.difficulty + (adjust.difficulty or 0) + G.DIFFICULTY, -0.5, 1),
		levels = adjust.levels or row.levels,
		tribulation = tribulation,
		-- beasts follow the curve from the stats their defs were authored against
		beastHealth = row.power / (Pacing.BeastBaseline.power[row.key] or row.power) * (adjust.beastHealth or 1) * G.BEAST_HEALTH,
		beastDamage = row.health / (Pacing.BeastBaseline.health[row.key] or row.health) * (adjust.beastDamage or 1) * G.BEAST_DAMAGE,
		combatQi = Pacing.CombatQi.MAX[row.key] or Pacing.CombatQi.DEFAULT_MAX,
	}
	Realms.Stages[i] = stage
	Realms.ByKey[row.key] = stage
	-- the same stage as a heaven-defier lives it: a longer bar (Pacing.HeavenDefying)
	local defier = table.clone(stage)
	defier.bar = math.max(1, math.floor(stage.bar * Pacing.HeavenDefying.BAR + 0.5))
	DEFIER[stage] = defier
end

-- The stage as this player lives it: a heaven-defier's copy has the longer bar.
-- Server code reads a player's stage through Cultivation.stage, which does this.
function Realms.forPlayer(stage: Stage, heavenDefying: boolean): Stage
	return if heavenDefying then DEFIER[stage] or stage else stage
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

-- The stage after this one, or nil at the top of the ladder (FE9).
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

-- 1 for Qi Condensation, 2 for Qi Refining, ... (1 for an unknown major).
function Realms.majorIndex(major: string): number
	return table.find(Realms.MAJORS, major) or 1
end

-- Realm suppression (Pacing.Suppression): the multiplier on damage an attacker of
-- `attackerMajor` deals to a target of `targetMajor`. 1 unless the attacker's major
-- is lower; then KEEP per major between them, with a heaven-defying attacker
-- ignoring HeavenDefying.SUPPRESSION_RESIST of the reduction.
function Realms.suppression(attackerMajor: string, targetMajor: string, heavenDefying: boolean?): number
	local gap = Realms.majorIndex(targetMajor) - Realms.majorIndex(attackerMajor)
	if gap <= 0 then
		return 1
	end
	local keep = Pacing.Suppression.KEEP
	if heavenDefying then
		keep += (1 - keep) * Pacing.HeavenDefying.SUPPRESSION_RESIST
	end
	return keep ^ gap
end

-- The stage a demon beast cultivates at (Enemies `realm` = { major, minor }), for
-- its beastHealth / beastDamage multipliers.
function Realms.ofBeast(realm: { any }): Stage
	return Realms.get(realm[1], realm[2])
end

return Realms
