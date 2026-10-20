--!strict
-- Weather events: the sky's moods over the mountain, layered on top of the day and
-- night cycle. The server picks one at a time (shared by everyone); clients draw
-- it. Rare phenomena carry a small blessing. All weather numbers live here.
--   weight    how often it's picked, relative to the others
--   minutes   how long it lasts (min, max)
--   announce  told to everyone when it starts (nil: says nothing)
--   bonus     { kind = "passive" | "circulation", amount } while it lasts
--   treasures how many heavenly treasures fall in the wilds as it starts (Treasures.luau)
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
		announce = "A strong wind sweeps the mountain.",
		wind = 90,
		density = 0.02,
	},
	AuspiciousMist = {
		id = "AuspiciousMist",
		weight = 7,
		minutes = { 3, 4 },
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
		announce = "Rainbow light spans the heavens! Circulation is 20% more efficient while it shines.",
		bonus = { kind = "circulation", amount = 0.2 },
		treasures = 2,
		aurora = true,
		brightness = 1.05,
		tint = Color3.fromRGB(255, 244, 250),
	},
} :: { [string]: Def }

Weather.FADE_SECONDS = 8 -- clients blend into and out of each event over this long

return Weather
