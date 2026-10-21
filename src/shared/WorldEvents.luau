--!strict
-- World events: happenings that draw the whole server somewhere, such as a
-- heavenly herb ripening under a guardian beast, and later ancient battlefields
-- opening or a portal to a ruined sect where rival sects fight over inheritances.
--
-- Each event is a def here. Its `kind` names the server handler that runs it
-- (ServerScriptService.Server.WorldEvents.<kind>, see WorldEvents/init.luau for
-- the handler contract), and the rest of the def is that kind's settings. To add
-- a new kind of event, write a handler module and add defs that use it.
--   name      shown in announcements and, later, the event tracker
--   kind      handler module
--   minutes   how long it runs before ending on its own (handlers may end it sooner)
--   triggers  weather id -> chance it starts when that weather begins
--   weight    how often the timer picks it when nothing triggered (nil: never)
-- While running, events are listed for clients in the workspace attribute
-- WorldEvents (JSON: { id, name, ends, at? = {x, y, z}, direction? }).

export type Def = {
	id: string,
	name: string,
	kind: string,
	minutes: number,
	triggers: { [string]: number }?,
	weight: number?,
	[string]: any, -- the kind's own settings
}

local WorldEvents = {}

WorldEvents.Defs = {
	-- An auspicious omen: a giant heavenly herb in the wilds under a pillar of
	-- light, guarded by a beast. The first to gather it once the guardian falls
	-- keeps it, with seeds to grow their own.
	ThousandYearGinseng = {
		id = "ThousandYearGinseng",
		name = "Thousand-Year Ginseng",
		kind = "GuardedHerb",
		minutes = 12,
		triggers = { HeavenSplit = 1, AuspiciousMist = 0.35 },
		herb = "ThousandYearGinseng",
		guardian = "ElderWolfKing", -- Enemies.Defs id
		giantScale = 6, -- the herb's size, relative to a mature plot plant
		beaconScale = 3, -- its pillar of light, relative to a heavenly treasure's
		gatherSeconds = 3, -- hold to gather
		seeds = 1, -- seeds the gatherer also gets
	},
	-- A storm stirs the beasts: everyone roaming the open wilds runs into packs
	-- far more often, and bigger ones, until it passes.
	BeastSurge = {
		id = "BeastSurge",
		name = "Beast Surge",
		kind = "BeastSurge",
		minutes = 6,
		triggers = { Storm = 0.4 },
		rate = 3, -- ambient encounters come this many times as often (Spawner.boost)
		extra = 1, -- beasts added to each pack
	},
	-- Auspicious clouds descend from the cloud sea and coil into a turning vortex
	-- of wisps over a spot in the wilds. Meditating inside its ring cultivates far
	-- faster; near the end the clouds condense into a jade at the eye, and the
	-- first to claim it keeps it. Clients draw it (WorldEventFX).
	CloudConvergence = {
		id = "CloudConvergence",
		name = "Auspicious Cloud Convergence",
		kind = "CloudConvergence",
		minutes = 6,
		triggers = { AuspiciousMist = 0.5, Windy = 0.2 },
		weight = 1,
		radius = 36, -- studs: the meditation ring around the eye
		meditation = 4.5, -- passive multiplier while meditating inside (Pacing.Meditation: 1.5 anywhere, 2.5 on your peak)
		condenseSeconds = 75, -- the jade condenses this long before the end
		treasure = "CloudPatternJade", -- Items id
		beaconScale = 2, -- the jade's pillar of light, relative to a heavenly treasure's
	},
} :: { [string]: Def }

WorldEvents.MAX_RUNNING = 2 -- at most this many events at once
-- Untriggered events: the timer rolls every so often and starts a weighted pick
-- (only defs with a weight).
WorldEvents.TIMER_MINUTES = { 20, 35 }

return WorldEvents
