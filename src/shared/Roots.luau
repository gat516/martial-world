--!strict
-- Spirit roots: a player's element, rolled once at the Testing Stone, and its
-- grade (Weapons.Grades colours; everyone starts at Pacing.Roots.STARTING_GRADE).
-- Each element has one perk on a system that already exists; the grade scales
-- the perk and the player's cultivation speed. Techniques of the root's element
-- (Techniques `element`) get Pacing.Roots.MATCH more damage.
-- Design: docs/character/spirit-root.md.

local Pacing = require(script.Parent.Pacing).Roots

-- element "" = not tested yet; grade = that element's; pending = a rerolled
-- element waiting for the player to keep it or return to `element` ("" = none);
-- grades = the grade each other element held reached while it was the root
-- (one never held starts at STARTING_GRADE); washed = Marrow Washing Pills each
-- element has absorbed toward its next grade (Pacing.Roots.WASH; reset when it rises);
-- fragments = pity fragments held toward each root pill, by pill id (shared by
-- every element; Pacing.Roots.FRAGMENTS)
export type Root = {
	element: string,
	grade: string,
	pending: string,
	grades: { [string]: string },
	washed: { [string]: number }?,
	fragments: { [string]: number }?,
}

-- What an element's perk changes (amounts in Pacing.Roots.PERKS; the rare
-- elements' second perk in Pacing.Roots.BONUS):
--   technique  share added to technique damage
--   regen      share of max health healed per second out of combat
--   growth     share added to herb growth speed
--   strike     share added to weapon strike (M1) damage
--   health     share added to max health
--   walk       studs/s added to walk speed
--   jump       share added to jump height
--   guard      share cut from damage taken
export type Perk = "technique" | "regen" | "growth" | "strike" | "health" | "walk" | "jump" | "guard"

export type Element = {
	id: string,
	name: string,
	perk: Perk,
	blurb: string, -- the one line on its card
	color: Color3,
	rare: boolean,
}

local Roots = {}

local function element(id: string, perk: Perk, blurb: string, color: Color3, rare: boolean?): Element
	return { id = id, name = id, perk = perk, blurb = blurb, color = color, rare = rare == true }
end

Roots.Elements = {
	Fire = element("Fire", "technique", "Your techniques hit harder.", Color3.fromRGB(255, 120, 60)),
	Water = element("Water", "regen", "You heal faster out of combat.", Color3.fromRGB(80, 160, 255)),
	Wood = element("Wood", "growth", "Your herbs grow faster.", Color3.fromRGB(110, 200, 90)),
	Metal = element("Metal", "strike", "Your weapon strikes hit harder.", Color3.fromRGB(225, 225, 235)),
	Earth = element("Earth", "health", "You have more health.", Color3.fromRGB(200, 150, 80)),
	Lightning = element("Lightning", "walk", "You run faster, and your techniques hit harder.", Color3.fromRGB(180, 140, 255), true),
	Wind = element("Wind", "jump", "You jump higher, and your weapon strikes hit harder.", Color3.fromRGB(150, 235, 210), true),
	Ice = element("Ice", "guard", "You take less damage, and you have more health.", Color3.fromRGB(170, 230, 255), true),
} :: { [string]: Element }

Roots.Order = { "Fire", "Water", "Wood", "Metal", "Earth", "Lightning", "Wind", "Ice" }

-- Grades low to high. Spirit, Earth and Heaven match Weapons.Grades (for colour);
-- Immortal, the rare top, has no weapon grade and takes its colour from here.
Roots.GradeOrder = { "Spirit", "Earth", "Heaven", "Immortal" }
Roots.GradeColors = { Immortal = Color3.fromRGB(255, 110, 140) } :: { [string]: Color3 }

-- What a pity fragment of each root pill is called (Pacing.Roots.FRAGMENTS).
Roots.FragmentNames = {
	MarrowWashingPill = "Marrow Washing fragment",
	RootRebirthPill = "Root Rebirth fragment",
} :: { [string]: string }

function Roots.new(): Root
	return { element = "", grade = Pacing.STARTING_GRADE, pending = "", grades = {}, washed = {}, fragments = {} }
end

-- Pity fragments held toward `pill`, and how many make one.
function Roots.fragments(root: Root, pill: string): (number, number)
	return if root.fragments then root.fragments[pill] or 0 else 0, Pacing.FRAGMENTS.PER_PILL
end

-- The grade `element` has (or would come back at) for this player.
function Roots.gradeOf(root: Root, element: string): string
	if element == root.element then
		return root.grade
	end
	return root.grades[element] or Pacing.STARTING_GRADE
end

-- Make `element` the root ("" = untested), keeping the old element's grade for
-- if it ever comes back and taking up the new one's own grade.
function Roots.switch(root: Root, element: string)
	if element == root.element then
		return
	end
	if Roots.tested(root) then
		root.grades[root.element] = root.grade
	end
	root.grade = Roots.gradeOf(root, element)
	root.grades[element] = nil
	root.element = element
end

function Roots.tested(root: Root): boolean
	return Roots.Elements[root.element] ~= nil
end

local function grade(root: Root): { speed: number, perk: number }
	return Pacing.GRADES[root.grade] or Pacing.GRADES[Pacing.STARTING_GRADE]
end

-- The perks an element gives, main first, as { kind, amount at perk strength 1 }.
function Roots.perks(id: string): { { kind: Perk, amount: number } }
	local def = Roots.Elements[id]
	if not def then
		return {}
	end
	local list = { { kind = def.perk, amount = Pacing.PERKS[id] or 0 } }
	for kind, amount in Pacing.BONUS[id] or {} do
		table.insert(list, { kind = kind :: Perk, amount = amount })
	end
	return list
end

-- The root's perk of this kind at its grade (0 when its element gives none).
function Roots.perk(root: Root, kind: Perk): number
	local total = 0
	for _, p in Roots.perks(root.element) do
		if p.kind == kind then
			total += p.amount
		end
	end
	return total * grade(root).perk
end

-- Multiplier on passive cultivation and refining.
function Roots.speed(root: Root): number
	return if Roots.tested(root) then grade(root).speed else 1
end

-- Share added to a technique of `element` (nil = no element).
function Roots.match(root: Root, element: string?): number
	return if element and Roots.tested(root) and element == root.element then Pacing.MATCH else 0
end

function Roots.roll(rng: Random): string
	local total = 0
	for _, id in Roots.Order do
		total += Pacing.ODDS[id] or 0
	end
	local pick = rng:NextNumber() * total
	for _, id in Roots.Order do
		pick -= Pacing.ODDS[id] or 0
		if pick < 0 then
			return id
		end
	end
	return Roots.Order[1]
end

-- Marrow Washing Pills the current element has absorbed toward its next grade,
-- and how many that grade needs (nil at the top).
function Roots.washed(root: Root): (number, number?)
	local nextGrade = Roots.nextGrade(root.grade)
	local done = if root.washed then root.washed[root.element] or 0 else 0
	return done, if nextGrade then Pacing.WASH[nextGrade] else nil
end

-- The grade above `name`, or nil at the top.
function Roots.nextGrade(name: string): string?
	local i = table.find(Roots.GradeOrder, name)
	return if i then Roots.GradeOrder[i + 1] else nil
end

return Roots
