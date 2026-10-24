--!strict
-- The hotbar: nine slots (keys 1-9), each holding a technique, an item, or
-- nothing ("" in the saved array). Pressing a technique's slot casts it; pressing
-- an item's slot holds the item out. Techniques on the hotbar are the ones
-- equipped, up to MAX_TECHNIQUES; technique and item ids never collide.

local Items = require(script.Parent.Items)
local Techniques = require(script.Parent.Techniques)

local Hotbar = {}

Hotbar.SIZE = 9
Hotbar.MAX_TECHNIQUES = Techniques.SLOTS

function Hotbar.empty(start: { string }?): { string }
	local bar = {}
	for i = 1, Hotbar.SIZE do
		bar[i] = start and start[i] or ""
	end
	return bar
end

-- The words a hotbar slot shows for an art or item: its def's `short` (one or two
-- words, each at most 27 px wide in Oswald Bold 11, so a 32 px phone slot keeps them
-- at 11 px; docs/ui/inventory.md "Hotbar words"), else its name's first two words.
function Hotbar.label(id: string): string
	local def: any = Techniques.Defs[id] or Items.Defs[id]
	if not def then
		return ""
	end
	if def.short then
		return def.short
	end
	local words = string.split((string.gsub(def.name, "-", " ")), " ")
	return table.concat(words, " ", 1, math.min(2, #words))
end

function Hotbar.isTechnique(id: string): boolean
	return Techniques.Defs[id] ~= nil
end

function Hotbar.techniqueCount(bar: { string }): number
	local n = 0
	for _, id in bar do
		if Hotbar.isTechnique(id) then
			n += 1
		end
	end
	return n
end

-- Put id in the first empty slot unless it's already there. Returns its slot,
-- or nil when the bar is full.
function Hotbar.place(bar: { string }, id: string): number?
	local at = table.find(bar, id)
	if at then
		return at
	end
	local free = table.find(bar, "")
	if free then
		bar[free] = id
	end
	return free
end

return Hotbar
