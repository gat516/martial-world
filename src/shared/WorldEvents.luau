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
	-- Auspicious clouds (kind AuspiciousClouds): a relic, a technique manual or an
	-- ancient sword, appears sealed at a spot in the wilds and the clouds gather
	-- around it, each variety in its own pattern and colours (`look`, drawn by
	-- clients in WorldEventFX). Meditating inside the ring cultivates far faster;
	-- `condenseSeconds` before the end the clouds pour into the relic and unseal it,
	-- and the first to claim it learns a technique from `techniques` (the one the
	-- relic names if they don't know it, else another they don't; `insight` if they
	-- know them all).
	--   radius      studs: the meditation ring around the relic
	--   meditation  passive multiplier inside (Pacing.Meditation: 1.5 anywhere, 2.5 on your peak)
	--   relic       ReplicatedStorage.Effects.AuspiciousClouds.Relics child
	--   look        { pattern = AuspiciousClouds child, color, accent }
	AuspiciousClouds = {
		id = "AuspiciousClouds",
		name = "Auspicious Clouds",
		kind = "AuspiciousClouds",
		minutes = 6,
		triggers = { Windy = 0.2, RainbowAurora = 0.4 },
		weight = 2,
		radius = 36,
		meditation = 4.5,
		condenseSeconds = 90,
		relic = "Manual",
		techniques = { "PalmStrike", "IronSkin" },
		insight = 1, -- for a claimer who already knows every technique in the pool
		look = { pattern = "Vortex", color = Color3.fromRGB(246, 250, 255), accent = Color3.fromRGB(140, 235, 190) },
	},
	VioletCloudMist = {
		id = "VioletCloudMist",
		name = "Violet Cloud Mist",
		kind = "AuspiciousClouds",
		minutes = 6,
		triggers = { AuspiciousMist = 0.5 },
		weight = 1,
		radius = 44,
		meditation = 4.5,
		condenseSeconds = 90,
		relic = "Manual",
		techniques = { "FireSeal", "LightningTalisman" },
		insight = 1,
		look = { pattern = "Mist", color = Color3.fromRGB(214, 190, 255), accent = Color3.fromRGB(160, 110, 240) },
	},
	GoldenAuspiciousClouds = {
		id = "GoldenAuspiciousClouds",
		name = "Golden Auspicious Clouds",
		kind = "AuspiciousClouds",
		minutes = 5,
		triggers = { HeavenSplit = 0.5 },
		weight = 0.4,
		radius = 30,
		meditation = 6,
		condenseSeconds = 75,
		relic = "Sword",
		techniques = { "LightningTalisman", "FireSeal", "IronSkin", "PalmStrike" },
		insight = 2,
		look = { pattern = "Spiral", color = Color3.fromRGB(255, 244, 214), accent = Color3.fromRGB(255, 196, 90) },
	},
} :: { [string]: Def }

WorldEvents.MAX_RUNNING = 2 -- at most this many events at once
-- Untriggered events: the timer rolls every so often and starts a weighted pick
-- (only defs with a weight).
WorldEvents.TIMER_MINUTES = { 20, 35 }

return WorldEvents
