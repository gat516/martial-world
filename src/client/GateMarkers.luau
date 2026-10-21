--!strict
-- A small seal and name floating over each teleport array (Hud.GateMarker, a
-- BillboardGui template), so players can find where to travel from. Shown once
-- the elder has taught the formation, hidden over the array you stand on (the
-- Travel button takes over there) and while a menu is open. Arrays the player's
-- realm hasn't opened carry a cinnabar seal; other players' peak arrays only
-- show up close. Arrays stream in and out, so markers follow the TravelGate tag.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gates = require(ReplicatedStorage.Shared.Gates)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Menus = require(script.Parent.Menus)
local MyPeak = require(script.Parent.MyPeak)

local player = Players.LocalPlayer

local HEIGHT = 7 -- studs above the array's centre
local OTHER_PEAK_DISTANCE = 60 -- someone else's peak array shows only this close
local OPEN_TINT = Color3.fromRGB(70, 150, 120)
local LOCKED_TINT = Color3.fromRGB(196, 58, 40)

local GateMarkers = {}

local template: BillboardGui
local markers: { [Instance]: BillboardGui } = {}
local taught = false
local here: Instance? = nil

local function refresh(array: Instance, marker: BillboardGui)
	local id = array:GetAttribute("Gate")
	local gate = if typeof(id) == "string" then Gates.ById[id] else nil
	local stage = Realms.byName(player:GetAttribute("Realm")) or Realms.Stages[1]
	local name, locked, near = "Teleport Array", false, false
	if gate and gate.id == "Peak" then
		if MyPeak.owns(array.Parent) then
			name = gate.name
		else
			near = true
		end
	elseif gate then
		name = gate.name
		locked = not Gates.open(gate, stage)
	end
	(marker:FindFirstChild("NameLabel") :: TextLabel).Text = name;
	(marker:FindFirstChild("Seal") :: ImageLabel).ImageColor3 = if locked then LOCKED_TINT else OPEN_TINT
	marker.MaxDistance = if near then OTHER_PEAK_DISTANCE else template.MaxDistance
	marker.Enabled = taught and array ~= here and not Menus.isOpen()
end

local function add(array: Instance)
	if markers[array] then
		return
	end
	-- the arrays' cores are cylinders lying on their side, and the billboard's
	-- world-space offset is in the adornee's frame: aim it at a point straight above
	local core = if array:IsA("BasePart") then array else (array :: Model).PrimaryPart or array:FindFirstChildWhichIsA("BasePart", true)
	if not core then
		return
	end
	local pivot = if array:IsA("Model") then array:GetPivot() else (core :: BasePart).CFrame
	local marker = template:Clone()
	marker.Name = "GateMarker"
	marker.Adornee = core
	marker.StudsOffsetWorldSpace = (core :: BasePart).CFrame:PointToObjectSpace(pivot.Position + Vector3.new(0, HEIGHT, 0))
	marker.Parent = player:FindFirstChildOfClass("PlayerGui")
	markers[array] = marker
	refresh(array, marker)
end

local function remove(array: Instance)
	local marker = markers[array]
	if marker then
		markers[array] = nil
		marker:Destroy()
	end
end

local function refreshAll()
	for array, marker in markers do
		refresh(array, marker)
	end
end

-- Onboarding (through TravelMenu) with whether travel is taught.
function GateMarkers.setTaught(on: boolean)
	if taught ~= on then
		taught = on
		refreshAll()
	end
end

-- TravelMenu with the array the character stands on (or nil), every check.
function GateMarkers.setHere(array: Instance?)
	if here ~= array then
		here = array
		refreshAll()
	end
end

function GateMarkers.init(gui: ScreenGui)
	template = gui:FindFirstChild("GateMarker") :: BillboardGui
	for _, array in CollectionService:GetTagged(Gates.TAG) do
		add(array)
	end
	CollectionService:GetInstanceAddedSignal(Gates.TAG):Connect(function(array)
		task.defer(add, array) -- after the streamed model's parts are in
	end)
	CollectionService:GetInstanceRemovedSignal(Gates.TAG):Connect(remove)
	player:GetAttributeChangedSignal("Realm"):Connect(refreshAll)
	player:GetAttributeChangedSignal("Peak"):Connect(refreshAll)
	Menus.onChanged(refreshAll)
end

return GateMarkers
