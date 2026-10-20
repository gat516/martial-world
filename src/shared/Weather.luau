--!strict
-- Weather events: the sky's moods over the mountain, layered on top of the day and
-- night cycle. The server picks one at a time (shared by everyone); clients draw
-- it. Rare phenomena carry a small blessing. All weather numbers live here.
--   weight    how often it's picked, relative to the others
--   minutes   how long it lasts (min, max)
--   announce  told to everyone when it starts (nil: says nothing)
--   bonus     { kind = "passive" | "circulation", amount } while it lasts
--   treasures how many heavenly treasures fall in the wilds as it starts (Treasures.luau)
--   garden    what it does to plants in owned plots while it lasts (Garden.luau):
--               growth    growth speed multiplier for plants still growing
--               mutation  mutation it can give (Herbs.Mutations), with `chance`
--                         per minute for each plant
--               swell     size each growing plant gains per minute
--             Herbs with `wild` set to an event's id also sprout wild on owned
--             peaks while it lasts (Config.Garden.WILD_*).
-- Visuals (client): rain / wind / mist particle rates, lightning (seconds between
-- distant strikes), aurora, and lighting changes (brightness scale, extra
-- atmosphere density and haze, and a tint the color grade leans toward).

export type Def = {
	id: string,
	weight: number,
	minutes: { number },
	announce: string?,
	bonus: { kind: string, amount: number }?,
	treasures: number?,
	garden: { growth: number?, mutation: string?, chance: number?, swell: number? }?,
	rain: number?,
	wind: number?,
	mist: number?,
	lightning: { number }?,
	aurora: boolean?,
	brightness: number?,
	density: number?,
	haze: number?,
	tint: Color3?,
	atmoColor: Color3?,
}

local Weather = {}

Weather.Defs = {
	Clear = { id = "Clear", weight = 48, minutes = { 4, 8 } },
	Rain = {
		id = "Rain",
		weight = 14,
		minutes = { 3, 5 },
		garden = { growth = 1.5, mutation = "Dewy", chance = 0.2 },
		announce = "A soft rain drifts across the peaks.",
		rain = 260,
		brightness = 0.75,
		density = 0.08,
		haze = 0.6,
		tint = Color3.fromRGB(215, 222, 235),
	},
	Storm = {
		id = "Storm",
		weight = 8,
		minutes = { 2, 4 },
		garden = { growth = 1.5, mutation = "Thunderstruck", chance = 0.12 },
		announce = "Storm clouds gather. Thunder rolls over the sect.",
		rain = 520,
		wind = 40,
		lightning = { 5, 13 },
		brightness = 0.55,
		density = 0.16,
		haze = 1.2,
		tint = Color3.fromRGB(190, 198, 222),
		atmoColor = Color3.fromRGB(120, 128, 150),
	},
	Windy = {
		id = "Windy",
		weight = 12,
		minutes = { 3, 5 },
		garden = { mutation = "Windswept", chance = 0.15 },
		announce = "A strong wind sweeps the mountain.",
		wind = 90,
		density = 0.02,
	},
	AuspiciousMist = {
		id = "AuspiciousMist",
		weight = 7,
		minutes = { 3, 4 },
		garden = { growth = 2, mutation = "Auspicious", chance = 0.15, swell = 0.08 },
		announce = "An auspicious violet mist descends! Passive cultivation +50% while it lingers.",
		bonus = { kind = "passive", amount = 0.5 },
		treasures = 3,
		mist = 18,
		density = 0.1,
		haze = 1.4,
		tint = Color3.fromRGB(232, 210, 255),
		atmoColor = Color3.fromRGB(196, 150, 240),
	},
	RainbowAurora = {
		id = "RainbowAurora",
		weight = 5,
		minutes = { 2, 3 },
		garden = { mutation = "Rainbow", chance = 0.08 },
		announce = "Rainbow light spans the heavens! Circulation is 20% more efficient while it shines.",
		bonus = { kind = "circulation", amount = 0.2 },
		treasures = 2,
		aurora = true,
		brightness = 1.05,
		tint = Color3.fromRGB(255, 244, 250),
	},
	HeavenSplit = {
		id = "HeavenSplit",
		weight = 3,
		minutes = { 2, 3 },
		announce = "The sky splits open! Heavenly light pours onto the peaks. Plants swell and Rift Lotuses sprout.",
		bonus = { kind = "passive", amount = 1 },
		treasures = 4,
		garden = { growth = 3, mutation = "Heavenlit", chance = 0.05, swell = 0.2 },
		lightning = { 3, 7 },
		aurora = true,
		brightness = 1.25,
		density = 0.05,
		haze = 0.8,
		tint = Color3.fromRGB(255, 236, 190),
		atmoColor = Color3.fromRGB(255, 210, 140),
	},
} :: { [string]: Def }

Weather.FADE_SECONDS = 8 -- clients blend into and out of each event over this long

return Weather
