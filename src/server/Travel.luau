--!strict
-- Teleport arrays (Shared.Gates): standing on one, travel to your own peak, the
-- main peak, the sect gate or a wilds array your realm has opened. Blocked for a
-- few seconds after taking damage, so it can't be used to escape a fight
-- mid-attack. Arrivals and hub respawns land on an array too (Travel.arrival).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gates = require(ReplicatedStorage.Shared.Gates)
local Combat = require(script.Parent.Combat)
local Peaks = require(script.Parent.Peaks)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)

local STREAM_TIMEOUT = 5 -- seconds to wait for the destination to stream in

local lastTravel: { [Player]: number } = {}

local Travel = {}

-- The array instance for a gate id; "Peak" is the player's own peak's array.
local function array(player: Player, id: string): Instance?
	if id == "Peak" then
		local peak = Peaks.ownedBy(player)
		return peak and peak:FindFirstChild("TeleportArray")
	end
	for _, tagged in CollectionService:GetTagged(Gates.TAG) do
		if tagged:GetAttribute("Gate") == id then
			return tagged
		end
	end
	return nil
end

-- Where a character lands on a gate's array, facing the way the array faces.
function Travel.arrival(player: Player, id: string): CFrame?
	if id == "Peak" then
		local peak = Peaks.ownedBy(player)
		return peak and Peaks.homeCFrame(peak)
	end
	local at = array(player, id)
	if not at then
		warn(`Travel: no TravelGate tagged with Gate "{id}"`)
		return nil
	end
	-- the arrays' cores are cylinders lying on their side, so keep only the yaw
	local pivot = if at:IsA("Model") then at:GetPivot() else (at :: BasePart).CFrame
	local look = pivot.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	local position = pivot.Position + Vector3.new(0, Config.Spawn.HEIGHT, 0)
	return CFrame.lookAt(position, position + look)
end

-- The array the player stands on, or nil.
function Travel.standingOn(player: Player): Instance?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	for _, tagged in CollectionService:GetTagged(Gates.TAG) do
		if Gates.on(tagged, root.Position) then
			return tagged
		end
	end
	return nil
end

function Travel.go(player: Player, where: any): (boolean, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid and humanoid.Health > 0) then
		return false, "You can't travel right now"
	end
	local data = PlayerData.get(player)
	if data and not Quests.travelUnlocked(data) then
		return false, "The elder hasn't taught you the teleport formation yet."
	end
	local gate = typeof(where) == "string" and Gates.ById[where]
	if not gate then
		return false, "Unknown destination"
	end
	local from = Travel.standingOn(player)
	if not from then
		return false, "Stand on a teleport array to travel."
	end
	if from == array(player, gate.id) then
		return false, `You're already at {gate.name}.`
	end
	if data and not Gates.open(gate, data.realm) then
		local need = Gates.required(gate)
		return false, `The {gate.name} array opens at {need and need.name or "a higher realm"}.`
	end
	if humanoid:GetAttribute("ActionBusy") or Combat.inCombat(player) then
		return false, "You can't form the array mid-fight."
	end
	local now = os.clock()
	if now - (lastTravel[player] or -math.huge) < Config.Travel.COOLDOWN then
		return false, "The formation is still recharging."
	end
	local target = Travel.arrival(player, gate.id)
	if not target then
		return false, "That array has gone quiet."
	end
	lastTravel[player] = now
	pcall(player.RequestStreamAroundAsync, player, target.Position, STREAM_TIMEOUT)
	if player.Character ~= character or humanoid.Health <= 0 then
		return false, nil
	end
	character:PivotTo(target)
	return true, nil
end

function Travel.forget(player: Player)
	lastTravel[player] = nil
end

return Travel
