--!strict
-- Realm ladder, in order. Every per-realm balance number lives here.
--   bar      cultivation needed to fill this stage's realm bar
--   dantian  raw qi the dantian holds
--   passive  cultivation per second from sitting (online or offline), before buffs
--   health   max health
--   power    damage multiplier
--   insight  insight needed to break through out of this stage (0 = none)

export type Stage = {
	major: string,
	minor: number,
	name: string,
	bar: number,
	dantian: number,
	passive: number,
	health: number,
	power: number,
	insight: number,
}

local MAJOR_NAMES = {
	QiCondensation = "Qi Condensation",
	Foundation = "Foundation Establishment",
}

local rows: { { any } } = {
	-- major, minor, bar, dantian, passive, health, power, insight
	{ "QiCondensation", 1, 40, 120, 0.20, 100, 1.00, 0 },
	{ "QiCondensation", 2, 110, 180, 0.25, 120, 1.10, 0 },
	{ "QiCondensation", 3, 200, 260, 0.32, 140, 1.20, 0 },
	{ "QiCondensation", 4, 340, 380, 0.40, 165, 1.32, 0 },
	{ "QiCondensation", 5, 560, 540, 0.50, 190, 1.45, 0 },
	{ "QiCondensation", 6, 900, 760, 0.62, 220, 1.60, 0 },
	{ "QiCondensation", 7, 1450, 1050, 0.78, 255, 1.76, 0 },
	{ "QiCondensation", 8, 2300, 1450, 0.95, 290, 1.94, 0 },
	{ "QiCondensation", 9, 3700, 2000, 1.15, 330, 2.13, 5 },
	{ "Foundation", 1, 12000, 4000, 2.00, 500, 3.00, 0 },
}

local Realms = {}

Realms.Stages = {} :: { Stage }

for i, r in rows do
	Realms.Stages[i] = {
		major = r[1],
		minor = r[2],
		name = if r[1] == "Foundation" then MAJOR_NAMES.Foundation else `{MAJOR_NAMES[r[1]]} {r[2]}`,
		bar = r[3],
		dantian = r[4],
		passive = r[5],
		health = r[6],
		power = r[7],
		insight = r[8],
	}
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

return Realms
