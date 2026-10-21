--!strict
-- Teleport arrays. Players arrive and respawn on them. Inside the sect the
-- Travel button rides to the sect's own arrays (My Peak, Main Peak, Sect Gate)
-- from anywhere; out in the wilds you travel only from an array (its prompt opens
-- the menu), and the wilds arrays are reached only from the Sect Gate's array or
-- another wilds array: you leave the sect through its gate.
-- Each array in the place is tagged TravelGate with a `Gate` attribute naming
-- its entry below; every spirit peak's TeleportArray is tagged with Gate "Peak"
-- (you can leave from anyone's, but "Peak" always takes you to your own).
--   id      the `Gate` attribute value and the TravelMenu button name
--   name    shown in the menu and in messages
--   region  Shared.Regions id whose `realm` gates the array (nil: always open)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Realms = require(ReplicatedStorage.Shared.Realms)
local Regions = require(ReplicatedStorage.Shared.Regions)

export type Gate = {
	id: string,
	name: string,
	region: string?,
}

local Gates = {}

Gates.TAG = "TravelGate"
Gates.RANGE = 12 -- flat studs from an array's pivot that count as standing on it
Gates.HEIGHT_RANGE = 10 -- and at most this far above or below it

Gates.List = {
	{ id = "Peak", name = "My Peak" },
	{ id = "MainPeak", name = "Main Peak" },
	{ id = "SectGate", name = "Sect Gate" },
	{ id = "InnerWilds", name = "Inner Wilds", region = "InnerWilds" },
	{ id = "MiddleWilds", name = "Ruined Borderlands", region = "MiddleWilds" },
	{ id = "OuterWilds", name = "Outer Wastes", region = "OuterWilds" },
} :: { Gate }

Gates.ById = {} :: { [string]: Gate }
for _, gate in Gates.List do
	Gates.ById[gate.id] = gate
end

-- The realm stage an array opens at, or nil when it's always open.
function Gates.required(gate: Gate): Realms.Stage?
	if not gate.region then
		return nil
	end
	for _, region in Regions.List do
		if region.id == gate.region and region.realm then
			return Realms.get(region.realm[1], region.realm[2])
		end
	end
	return nil
end

-- Whether a player at `realm` ({ major, minor }) may travel to the array.
function Gates.open(gate: Gate, realm: { major: string, minor: number }): boolean
	local need = Gates.required(gate)
	return need == nil or Realms.index(realm.major, realm.minor) >= Realms.index(need.major, need.minor)
end

-- Whether the gate is out in the wilds (reached only from a Gates.leadsOut array).
function Gates.wild(gate: Gate): boolean
	return gate.region ~= nil
end

-- Whether the array with this `Gate` attribute can send you into the wilds: the
-- Sect Gate's and the wilds arrays themselves.
function Gates.leadsOut(id: any): boolean
	if id == "SectGate" then
		return true
	end
	local gate = if typeof(id) == "string" then Gates.ById[id] else nil
	return gate ~= nil and Gates.wild(gate)
end

-- Whether `position` is on the sect's safe ground, where travel to the sect's
-- arrays works from anywhere. The Sect Gate's array stands outside, in the wilds.
function Gates.inSect(position: Vector3): boolean
	local region = Regions.at(position)
	return region ~= nil and region.realm == nil
end

-- Whether `position` stands on the array instance.
function Gates.on(array: Instance, position: Vector3): boolean
	local pivot = if array:IsA("Model") then array:GetPivot() elseif array:IsA("BasePart") then array.CFrame else nil
	if not pivot then
		return false
	end
	local offset = position - pivot.Position
	return Vector2.new(offset.X, offset.Z).Magnitude <= Gates.RANGE and math.abs(offset.Y) <= Gates.HEIGHT_RANGE
end

return Gates
