--!strict
-- What the player has picked so far on the character screen. Only a preview:
-- nothing here counts until Enter World sends it to the server.
--   Shirt, Pants   Clothing option Ids
--   HairId         catalog id of a hair the server loaded, or nil for none
--   HairColor      HairColors Id
--   FirstName      the raw text in the field (checked with Rules.checkFirstName)
--   Tab            the open tab's Id
-- Race and last name are not here: they're the server's, read from the
-- player's attributes.

local State = {}
State.__index = State

export type Values = {
	Shirt: string,
	Pants: string,
	HairId: number?,
	HairColor: string,
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
			HairId = nil,
			HairColor = defs.HairColors[1].Id,
			FirstName = "",
			Tab = "Clothes",
		} :: Values,
		listeners = {},
	}, State)
	return self
end

function State.get(self: State, key: string): any
	return (self.values :: any)[key]
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

-- The Look the server's "confirm" action takes.
function State.look(self: State): { [string]: any }
	local v = self.values
	return {
		Shirt = v.Shirt,
		Pants = v.Pants,
		HairId = v.HairId,
		HairColor = v.HairColor,
		FirstName = v.FirstName,
	}
end

return State
