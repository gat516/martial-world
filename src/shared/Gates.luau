--!strict
-- Teleport arrays: the only way to travel. Players arrive, respawn and leave
-- through them, and the travel menu works only while standing on one.
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
