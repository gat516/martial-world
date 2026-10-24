--!strict
-- Teleport arrays (Shared.Gates). Anywhere on the sect's safe ground you can ride
-- to your own peak, the main peak or the sect gate; out in the wilds only from an
-- array. The wilds arrays open by realm and only from the Sect Gate's array or
-- another wilds array. Blocked for a few seconds after taking damage, so it can't
-- be used to escape a fight mid-attack. Arrivals and hub respawns land on an
-- array too (Travel.arrival).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gates = require(ReplicatedStorage.Shared.Gates)
local Combat = require(script.Parent.Combat)
local Peaks = require(script.Parent.Peaks)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)

local STREAM_TIMEOUT = 5 -- seconds to wait for the destination to stream in
local JOIN_NEAR = 40 -- studs: closer than this to a member, "join" says you're already there

local lastTravel: { [Player]: number } = {}

local Travel = {}

-- Called with (player) just before a ride moves the character (Haul banks quietly).
Travel.onTravel = {} :: { (Player) -> () }

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

-- Where a character lands on an array instance, facing the way it faces (the
-- arrays' cores are cylinders lying on their side, so keep only the yaw).
function Travel.landing(at: Instance): CFrame
	local pivot = if at:IsA("Model") then at:GetPivot() else (at :: BasePart).CFrame
	local look = pivot.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	local position = pivot.Position + Vector3.new(0, Config.Spawn.HEIGHT, 0)
	return CFrame.lookAt(position, position + look)
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
	return Travel.landing(at)
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

-- The checks every ride shares: alive, taught, not mid-fight, not recharging.
local function ready(player: Player): (Model?, Humanoid?, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid and humanoid.Health > 0) then
		return nil, nil, "You can't travel right now"
	end
	local data = PlayerData.get(player)
	if data and not Quests.travelUnlocked(data) then
		return nil, nil, "The elder hasn't taught you the teleport formation yet."
	end
	if humanoid:GetAttribute("ActionBusy") or Combat.inCombat(player) then
		return nil, nil, "You can't form the array mid-fight."
	end
	if os.clock() - (lastTravel[player] or -math.huge) < Config.Travel.COOLDOWN then
		return nil, nil, "The formation is still recharging."
	end
	return character, humanoid, nil
end

-- Move the character to `target` (after the onTravel hooks and streaming).
local function ride(player: Player, character: Model, humanoid: Humanoid, target: CFrame): (boolean, string?)
	lastTravel[player] = os.clock()
	for _, fn in Travel.onTravel do
		pcall(fn, player)
	end
	pcall(player.RequestStreamAroundAsync, player, target.Position, STREAM_TIMEOUT)
	if player.Character ~= character or humanoid.Health <= 0 then
		return false, nil
	end
	character:PivotTo(target)
	return true, nil
end

-- Sect rides (and rides to another player) start from an array or the sect's ground.
local function fromSectOrArray(player: Player, character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return Travel.standingOn(player) ~= nil or (root ~= nil and Gates.inSect(root.Position))
end

function Travel.go(player: Player, where: any): (boolean, string?)
	local gate = typeof(where) == "string" and Gates.ById[where]
	if not gate then
		return false, "Unknown destination"
	end
	local character, humanoid, why = ready(player)
	if not (character and humanoid) then
		return false, why
	end
	local data = PlayerData.get(player)
	local from = Travel.standingOn(player)
	if Gates.wild(gate) then
		if not (from and Gates.leadsOut(from:GetAttribute("Gate"))) then
			return false, "The wilds arrays answer only from the Sect Gate's array."
		end
	elseif not fromSectOrArray(player, character) then
		return false, "Out in the wilds, stand on a teleport array to travel."
	end
	if from and from == array(player, gate.id) then
		return false, `You're already at {gate.name}.`
	end
	if data and not Gates.open(gate, data.realm) then
		local need = Gates.required(gate)
		return false, `The {gate.name} array opens at {need and need.name or "a higher realm"}.`
	end
	local target = Travel.arrival(player, gate.id)
	if not target then
		return false, "That array has gone quiet."
	end
	return ride(player, character, humanoid, target)
end

-- The array nearest `position` that a player at `realm` may ride to, or nil.
local function nearestOpenArray(position: Vector3, realm: { major: string, minor: number }?): Instance?
	local best, bestDistance = nil, math.huge
	for _, tagged in CollectionService:GetTagged(Gates.TAG) do
		local gate = Gates.ById[tagged:GetAttribute("Gate") :: any]
		if gate and (not realm or Gates.open(gate, realm)) and (tagged:IsA("Model") or tagged:IsA("BasePart")) then
			local pivot = if tagged:IsA("Model") then tagged:GetPivot() else (tagged :: BasePart).CFrame
			local distance = (pivot.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = tagged, distance
			end
		end
	end
	return best
end

-- Ride to another player in this server (docs/systems/party.md):
--   "join"   a party member: the array nearest them that your realm has opened
--            (the Sect Gate rule is waived; you still leave from an array or the
--            sect's ground). The testbed has no arrays: you land beside them.
--   "visit"  their spirit peak's array (Peaks.homeCFrame), from an array or the sect.
function Travel.toPlayer(player: Player, other: Player, mode: "join" | "visit"): (boolean, string?)
	if other == player or other.Parent == nil then
		return false, "They're not on this mountain."
	end
	local character, humanoid, why = ready(player)
	if not (character and humanoid) then
		return false, why
	end
	if not fromSectOrArray(player, character) then
		return false, "Out in the wilds, stand on a teleport array to travel."
	end
	local name = other.DisplayName
	local target: CFrame? = nil
	if mode == "visit" then
		local peak = Peaks.ownedBy(other)
		target = peak and Peaks.homeCFrame(peak)
		if not target then
			return false, `{name} has no peak to visit.`
		end
	else
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local mine = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false, `{name} isn't anywhere you can reach.`
		end
		if mine and (mine.Position - root.Position).Magnitude <= JOIN_NEAR then
			return false, `You're already beside {name}.`
		end
		local data = PlayerData.get(player)
		local at = nearestOpenArray(root.Position, data and data.realm)
		if at then
			if at == Travel.standingOn(player) then
				return false, `You're already at the array nearest {name}.`
			end
			target = Travel.landing(at)
		elseif Config.TESTBED then
			local beside = root.CFrame * CFrame.new(4, 0, 4)
			target = CFrame.lookAt(beside.Position, Vector3.new(root.Position.X, beside.Position.Y, root.Position.Z))
		else
			return false, `No array you can ride to lies near {name}.`
		end
	end
	return ride(player, character, humanoid, target :: CFrame)
end

function Travel.forget(player: Player)
	lastTravel[player] = nil
end

return Travel
