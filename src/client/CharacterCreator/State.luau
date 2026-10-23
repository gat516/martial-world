--!strict
-- What the player has picked so far on the character screen. Only a preview:
-- nothing here counts until Enter World (or Save look) sends it to the server.
--   Shirt, Pants   Clothing option Ids
--   Hair1..Hair3   catalog id of a hair the server loaded in that slot (one per
--                  field on the Hair tab, Rules.MAX_HAIRS of them), or nil
--   HairColor      HairColors Id
--   SkinColor      SkinColors Id ("Avatar" keeps the avatar's own skin)
--   FirstName      the raw text in the field (checked with Rules.checkFirstName)
--   Tab            the open tab's Id
-- Race and last name are not here: they're the server's, read from the
-- player's attributes.

local State = {}
State.__index = State

export type Values = {
	Shirt: string,
	Pants: string,
	Hair1: number?,
	Hair2: number?,
	Hair3: number?,
	HairColor: string,
	SkinColor: string,
	FirstName: string,
	Tab: string,
}

export type State = typeof(setmetatable(
	{} :: { values: Values, listeners: { (string, any) -> () } },
	State
))

function State.new(defs: any): State
	local self = setmetatable({
		values = {
			Shirt = defs.Clothing.Shirt[1].Id,
			Pants = defs.Clothing.Pants[1].Id,
			Hair1 = nil,
			Hair2 = nil,
			Hair3 = nil,
			HairColor = defs.HairColors[1].Id,
			SkinColor = defs.SkinColors[1].Id,
			FirstName = "",
			Tab = "Appearance",
		} :: Values,
		listeners = {},
	}, State)
	return self
end

function State.get(self: State, key: string): any
	return (self.values :: any)[key]
end

-- Starts over from a look (a slot's saved look, or nil for the defaults). Every
-- listener hears each value, so the tabs and the preview repaint.
function State.load(self: State, defs: any, look: { [string]: any }?, firstName: string?)
	local hairs = if look and type(look.HairIds) == "table" then look.HairIds else {}
	local values = {
		Shirt = look and look.Shirt or defs.Clothing.Shirt[1].Id,
		Pants = look and look.Pants or defs.Clothing.Pants[1].Id,
		HairColor = look and look.HairColor or defs.HairColors[1].Id,
		SkinColor = look and look.SkinColor or defs.SkinColors[1].Id,
		FirstName = firstName or "",
	}
	for key, value in values do
		self:set(key, value)
	end
	for slot = 1, 3 do
		self:set(`Hair{slot}`, hairs[slot])
	end
end

-- Sets one value and tells every listener (key, value) if it changed.
function State.set(self: State, key: string, value: any)
	local values = self.values :: any
	if values[key] == value then
		return
	end
	values[key] = value
	for _, listener in table.clone(self.listeners) do
		listener(key, value)
	end
end

-- Listens for changes; returns a function that stops listening.
function State.onChanged(self: State, listener: (string, any) -> ()): () -> ()
	table.insert(self.listeners, listener)
	return function()
		local index = table.find(self.listeners, listener)
		if index then
			table.remove(self.listeners, index)
		end
	end
end

-- The hair ids worn, in slot order, gaps and repeats dropped.
function State.hairIds(self: State): { number }
	local ids = {}
	for _, id in { self.values.Hair1, self.values.Hair2, self.values.Hair3 } do
		if id and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	return ids
end

export type Missing = { tab: string, field: string, label: string }

-- What still blocks Enter World, in the order the player should fix it. Only the
-- first name has no default; race and last name come from the server's roll
-- (attributes) and are only missing until it lands. Outfit, skin and hair colour
-- start picked, and hair is optional. The server checks all of it again.
function State.missing(self: State, rules: any, race: string?, surname: string?): { Missing }
	local out = {}
	if not rules.checkFirstName(self.values.FirstName) then
		table.insert(out, { tab = "Name", field = "FirstName", label = "first name" })
	end
	if not race or not surname then
		table.insert(out, { tab = "Name", field = "Roll", label = "race and clan (still being drawn)" })
	end
	return out
end

-- The Look the server's "confirm" action takes.
function State.look(self: State): { [string]: any }
	local v = self.values
	return {
		Shirt = v.Shirt,
		Pants = v.Pants,
		HairIds = self:hairIds(),
		HairColor = v.HairColor,
		SkinColor = v.SkinColor,
		FirstName = v.FirstName,
	}
end

return State
