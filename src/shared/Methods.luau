--!strict
-- Cultivation methods: how a player cultivates (server Methods.luau; design in
-- docs/systems/character.md). Until Foundation everyone uses the sect's unnamed
-- basic breathing method (BASIC). A method sets:
--   qi       multiplier on passive cultivation, refining and gathering
--   reaches  the last stage key it can take you to; a stage past it needs a
--            stronger method (a key not on the ladder yet = no limit today)
--   element  matching your spirit root adds Pacing.Methods.MATCH to qi
-- On reaching Foundation a player is given a random starter (server Methods);
-- better ones are found later. Numbers live in Pacing.Methods.

local Pacing = require(script.Parent.Pacing).Methods
local Realms = require(script.Parent.Realms)

export type Def = {
	id: string,
	name: string,
	element: string, -- Roots.Elements id, "" = none
	grade: string, -- Weapons.Grades name, for colour
	qi: number,
	reaches: string, -- stage key
	blurb: string, -- one line on its card
	starter: boolean, -- offered in the first choice
	rare: boolean, -- starter offered only to that rare root
}

local Methods = {}

Methods.BASIC = "SectBreathing"

local function def(t: any): Def
	t.element = t.element or ""
	t.starter = t.starter == true
	t.rare = t.rare == true
	return t :: Def
end

Methods.Defs = {
	SectBreathing = def({ id = "SectBreathing", name = "Sect Breathing Method", grade = "Mortal", qi = Pacing.BASIC_QI, reaches = Pacing.BASIC_REACHES, blurb = "The sect's basic breathing. It can only take you so far." }),
	BlazingHeart = def({ id = "BlazingHeart", name = "Blazing Heart Sutra", element = "Fire", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, blurb = "Qi burns hot and fast through the meridians." }),
	FlowingSpring = def({ id = "FlowingSpring", name = "Flowing Spring Scripture", element = "Water", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, blurb = "Qi gathers like water into a still pool." }),
	EverGreen = def({ id = "EverGreen", name = "Evergreen Root Canon", element = "Wood", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, blurb = "Qi grows patiently, like an old tree." }),
	IronMarrow = def({ id = "IronMarrow", name = "Iron Marrow Art", element = "Metal", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, blurb = "Qi is hammered into the bones." }),
	MountainBreath = def({ id = "MountainBreath", name = "Mountain Breath Method", element = "Earth", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, blurb = "Qi settles deep and steady as stone." }),
	ThunderPulse = def({ id = "ThunderPulse", name = "Thunder Pulse Manual", element = "Lightning", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, rare = true, blurb = "Qi crackles through you in sudden bursts." }),
	DriftingCloud = def({ id = "DriftingCloud", name = "Drifting Cloud Scripture", element = "Wind", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, rare = true, blurb = "Qi drifts in on every breath of wind." }),
	FrostLotus = def({ id = "FrostLotus", name = "Frost Lotus Sutra", element = "Ice", grade = "Mortal", qi = Pacing.STARTER_QI, reaches = Pacing.STARTER_REACHES, starter = true, rare = true, blurb = "Qi blooms cold and clear." }),
} :: { [string]: Def }

-- Display order: the basic method, then starters by element.
Methods.Order = { "SectBreathing", "BlazingHeart", "FlowingSpring", "EverGreen", "IronMarrow", "MountainBreath", "ThunderPulse", "DriftingCloud", "FrostLotus" }

-- The active method's def ("" or unknown = the basic one).
function Methods.active(active: string): Def
	return Methods.Defs[active] or Methods.Defs[Methods.BASIC]
end

-- Qi multiplier of a method for a root element (the match bonus included).
function Methods.speed(def: Def, rootElement: string): number
	local match = def.element ~= "" and def.element == rootElement
	return def.qi + (if match then Pacing.MATCH else 0)
end

-- Whether the method can take you into `stage` (a Realms stage).
function Methods.allows(def: Def, stage: Realms.Stage): boolean
	local limit = Realms.ByKey[def.reaches]
	if not limit then
		return true -- its limit is past the ladder built so far
	end
	return Realms.index(stage.major, stage.minor) <= Realms.index(limit.major, limit.minor)
end

-- The starters a root can be given: the five basic elements, plus the rare
-- root's own. The one matching the root comes first.
function Methods.starters(rootElement: string): { Def }
	local list = {}
	for _, id in Methods.Order do
		local d = Methods.Defs[id]
		if d.starter and (not d.rare or d.element == rootElement) then
			table.insert(list, d)
		end
	end
	table.sort(list, function(a, b)
		local am, bm = a.element == rootElement, b.element == rootElement
		if am ~= bm then
			return am
		end
		local ai: number = table.find(Methods.Order, a.id) or 0
		local bi: number = table.find(Methods.Order, b.id) or 0
		return ai < bi
	end)
	return list
end

return Methods
