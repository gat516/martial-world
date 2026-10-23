--!strict
-- What the death screen says (docs/ui/death-screen.md). Data only: add lines to
-- any pool and the screen picks them up. Keep every line short (one line on a
-- phone, about 50 characters) and free of markup.
--
-- Titles: `{name}` becomes the beast's name ("Spirit Wolf"). Flavour: one line
-- under the divider. A known cause takes its own flavour most of the time and a
-- general line otherwise; the last few lines shown are skipped, so the screen
-- rarely repeats.

local DeathLines = {}

-- Share of deaths with a known cause that use the cause's own flavour pool.
DeathLines.CAUSE_SHARE = 0.65
-- How many recent lines (per kind: titles, flavour) are skipped.
DeathLines.MEMORY = 4

DeathLines.Titles = {
	beast = { "Slain by the {name}", "Felled by the {name}", "Torn down by the {name}" },
	boss = { "Slain by the {name}", "Crushed by the {name}", "Felled by the {name}" },
	poison = { "Slain by the {name}", "Felled by the {name}" },
	fall = { "Lost to the Drop", "The Ground Was Swifter", "You Fell from the Heights" },
	tribulation = { "Struck Down by Heaven", "Unworthy of the Thunder" },
	unknown = { "You Have Fallen", "Your Body Fails", "Your Light Dims" },
}

DeathLines.Flavour = {
	beast = {
		"The wilds do not forgive the careless.",
		"Fang and claw outpaced your guard.",
		"A beast's hunger knows no realm.",
		"Your guard broke before your will did.",
		"Watch the tell. Strike in the gap.",
	},
	boss = {
		"Its cultivation ran deeper than yours. For now.",
		"A tyrant of the wilds remembers your face.",
		"Temper your foundation, then return.",
		"Learn its rhythm. Every beast has a gap.",
		"Today the mountain was taller than you.",
	},
	poison = {
		"Venom finished what the fangs began.",
		"Poison crept through your meridians.",
		"The venom reached your heart first.",
	},
	fall = {
		"Not even a cultivator outruns the ground.",
		"The cliffs keep what they take.",
		"Your qi could not catch you.",
		"Ride the wind next time, not the drop.",
	},
	tribulation = {
		"Heaven's lightning tests all who rise.",
		"The thunder found your foundation wanting.",
		"Heaven cleanses the unworthy. Rise again.",
	},
	general = {
		"The Dao is long. One death is one step.",
		"Your body breaks; your will endures.",
		"Ten thousand failures temper one immortal.",
		"Rest your qi. The peak still waits.",
		"Every master once lay in the dust.",
		"The river of rebirth spits you back out.",
		"Heaven was not watching. Rise anyway.",
		"Defeat is a teacher who charges dearly.",
		"Breathe. Gather your qi. Climb again.",
		"Even jade must be cut before it shines.",
		"Your soul lingers; your path is not done.",
		"A cultivator's heart is forged in loss.",
		"The wheel turns, and you turn with it.",
		"Dust to dust, qi to qi. Stand again.",
	},
}

-- The countdown line: `{n}` is the seconds left; `soon` shows at zero.
DeathLines.Respawn = {
	hub = { count = "Reforming at the main peak in {n}", soon = "Reforming at the main peak..." },
	here = { count = "Reforming in {n}", soon = "Reforming..." },
}

local recent: { [string]: { string } } = {}

-- A random entry of `pool` that wasn't among the last MEMORY picks for `key`.
local function pick(pool: { string }, key: string): string
	local seen = recent[key] or {}
	recent[key] = seen
	local fresh = {}
	for _, line in pool do
		if not table.find(seen, line) then
			table.insert(fresh, line)
		end
	end
	local from = if #fresh > 0 then fresh else pool
	local line = from[math.random(#from)]
	table.insert(seen, line)
	while #seen > DeathLines.MEMORY do
		table.remove(seen, 1)
	end
	return line
end

-- The title and flavour for a cause ("beast", "boss", "poison", "fall",
-- "tribulation" or "unknown") and the killer's display name (beasts and bosses).
function DeathLines.pick(cause: string, name: string?): (string, string)
	if (cause == "beast" or cause == "boss" or cause == "poison") and not name then
		cause = "unknown"
	end
	local titles = DeathLines.Titles[cause] or DeathLines.Titles.unknown
	local title = string.gsub(pick(titles, "title"), "{name}", name or "")
	local own = DeathLines.Flavour[cause]
	local flavour = if own and math.random() < DeathLines.CAUSE_SHARE
		then pick(own, "flavour")
		else pick(DeathLines.Flavour.general, "flavour")
	return title, flavour
end

return DeathLines
