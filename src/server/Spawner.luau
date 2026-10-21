--!strict
-- Decides where and when beasts appear; EnemyService runs them once they do.
-- Designated zones are kept topped up with respawns, and players roaming open
-- ground away from any zone run into ambient packs from their region's table
-- (see Shared.Spawns and Shared.Regions). World events use Spawner.boost to make ambient
-- encounters more frequent and bigger while they run, and Spawner.pack to drop
-- a group of beasts somewhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Wilds
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Regions = require(ReplicatedStorage.Shared.Regions)
local Spawns = require(ReplicatedStorage.Shared.Spawns)
local Cultivation = require(script.Parent.Cultivation)
local EnemyService = require(script.Parent.EnemyService)

local Ambient = Spawns.Ambient

local wilds = workspace:WaitForChild("Wilds")

export type Boost = {
	rate: number?, -- encounters come this many times as often
	extra: number?, -- beasts added to each pack
}

local Spawner = {}

local zoneOf: { [Model]: BasePart } = {} -- zone-spawned beasts, for respawning
local ambient: { [Model]: { player: Player, lonely: number } } = {} -- lonely: os.clock() since no player was near
local nextEncounter: { [Player]: number } = {}
local boosts: { [string]: Boost } = {}

local function zones(): { BasePart }
	local list = {}
	for _, zone in (wilds:WaitForChild("Zones")):GetChildren() do
		if zone:IsA("BasePart") then
			table.insert(list, zone)
		end
	end
	return list
end

local function zoneRadius(zone: BasePart): number
	return (zone:GetAttribute("Radius") :: number?) or 20
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function randomPointNear(center: Vector3, radius: number): Vector3
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
	return center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

--[[ Zones ]]

local function spawnInZone(zone: BasePart)
	local id = zone:GetAttribute("Enemy")
	if type(id) ~= "string" then
		return
	end
	local radius = zoneRadius(zone)
	local model = EnemyService.spawn(id, randomPointNear(zone.Position, radius * 0.8), {
		home = zone.Position,
		roam = radius * 0.6,
	})
	if model then
		zoneOf[model] = zone
	end
end

--[[ Packs ]]

-- Spawn `beasts` (id -> count) scattered within `spread` studs of `at`.
function Spawner.pack(beasts: { [string]: number }, at: Vector3, spread: number, options: EnemyService.SpawnOptions?): { Model }
	local spawned = {}
	for id, count in beasts do
		for _ = 1, count do
			local model = EnemyService.spawn(id, randomPointNear(at, spread), options)
			if model then
				table.insert(spawned, model)
			end
		end
	end
	return spawned
end

-- Make ambient encounters livelier until the returned function is called.
function Spawner.boost(id: string, boost: Boost): () -> ()
	boosts[id] = boost
	return function()
		boosts[id] = nil
	end
end

local function boosted(): (number, number)
	local rate, extra = 1, 0
	for _, b in boosts do
		rate *= b.rate or 1
		extra += b.extra or 0
	end
	return rate, extra
end

--[[ Ambient encounters ]]

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

-- Open ground: in a region with ambient packs, away from safe spots and
-- designated zones.
local function openGround(position: Vector3): boolean
	local region = Regions.at(position)
	if not (region and region.packs and Spawns.Encounters[region.packs]) then
		return false
	end
	for _, safe in Ambient.SAFE do
		if flat(position - safe.at).Magnitude <= safe.radius then
			return false
		end
	end
	for _, zone in zones() do
		if flat(position - zone.Position).Magnitude <= zoneRadius(zone) + Ambient.ZONE_MARGIN then
			return false
		end
	end
	return true
end

local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { wilds }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- A spot on dry, open ground behind the player (out of view), or nil.
local function encounterSpot(root: BasePart): Vector3?
	local back = flat(-root.CFrame.LookVector)
	back = if back.Magnitude > 0.01 then back.Unit else Vector3.zAxis
	local params = groundParams()
	for _ = 1, 6 do
		local angle = math.rad((math.random() * 2 - 1) * 70)
		local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(back)
		local distance = Ambient.DISTANCE[1] + math.random() * (Ambient.DISTANCE[2] - Ambient.DISTANCE[1])
		local probe = root.Position + dir * distance
		local hit = workspace:Raycast(probe + Vector3.new(0, 40, 0), Vector3.new(0, -100, 0), params)
		if
			hit
			and hit.Material ~= Enum.Material.Water
			and math.abs(hit.Position.Y - root.Position.Y) < 20
			and openGround(hit.Position)
		then
			return hit.Position
		end
	end
	return nil
end

local function pickPack(packs: { Spawns.Pack }): { [string]: number }
	local total = 0
	for _, pack in packs do
		total += pack.weight
	end
	local roll = math.random() * total
	local chosen = packs[#packs]
	for _, pack in packs do
		roll -= pack.weight
		if roll <= 0 then
			chosen = pack
			break
		end
	end
	local beasts = {}
	for id, range in chosen.beasts do
		local def = Enemies.Defs[id]
		if def and not def.boss then
			beasts[id] = math.random(range[1], range[2])
		end
	end
	return beasts
end

local function ambientCount(player: Player?): number
	local n = 0
	for _, entry in ambient do
		if player == nil or entry.player == player then
			n += 1
		end
	end
	return n
end

local function encounter(player: Player, root: BasePart)
	local spot = encounterSpot(root)
	local region = spot and Regions.at(spot)
	local packs = region and region.packs and Spawns.Encounters[region.packs]
	if not (spot and packs) then
		return
	end
	local beasts = pickPack(packs)
	local _, extra = boosted()
	for id, count in beasts do
		beasts[id] = count + extra
	end
	local room = math.min(Ambient.MAX_PER_PLAYER - ambientCount(player), Ambient.MAX_TOTAL - ambientCount(nil))
	for id, count in beasts do
		beasts[id] = math.min(count, room)
		room -= beasts[id]
	end
	local now = os.clock()
	for _, model in Spawner.pack(beasts, spot, 4, { roam = Ambient.ROAM, target = player }) do
		ambient[model] = { player = player, lonely = now }
	end
end

local function tickPlayer(player: Player, now: number)
	local root = livingRoot(player)
	local meditating = Cultivation.meditation and Cultivation.meditation(player)
	if not root or meditating or not openGround(root.Position) then
		nextEncounter[player] = nil -- the clock starts again on open ground
		return
	end
	local due = nextEncounter[player]
	if not due then
		nextEncounter[player] = now + Ambient.FIRST_DELAY
		return
	end
	if now < due then
		return
	end
	local rate = boosted()
	local wait = Ambient.INTERVAL[1] + math.random() * (Ambient.INTERVAL[2] - Ambient.INTERVAL[1])
	nextEncounter[player] = now + wait / rate
	if ambientCount(player) < Ambient.MAX_PER_PLAYER and ambientCount(nil) < Ambient.MAX_TOTAL then
		encounter(player, root)
	end
end

-- Ambient beasts nobody is near for a while fade away.
local function tidy(now: number)
	for model, entry in ambient do
		local position = model:GetPivot().Position
		local near = false
		for _, player in Players:GetPlayers() do
			local root = livingRoot(player)
			if root and (root.Position - position).Magnitude <= Ambient.DESPAWN_DISTANCE then
				near = true
				break
			end
		end
		if near then
			entry.lonely = now
		elseif now - entry.lonely >= Ambient.DESPAWN_SECONDS then
			EnemyService.despawn(model)
		end
	end
end

function Spawner.forget(player: Player)
	nextEncounter[player] = nil
end

function Spawner.start()
	table.insert(EnemyService.onRemoved, function(model: Model, killed: boolean)
		ambient[model] = nil
		local zone = zoneOf[model]
		zoneOf[model] = nil
		if zone and killed then
			local def = Enemies.Defs[zone:GetAttribute("Enemy") :: string]
			local spread = 1 + (math.random() * 2 - 1) * Config.RESPAWN_SPREAD
			task.delay((if def then def.respawn else 30) * spread, spawnInZone, zone)
		end
	end)
	for _, zone in zones() do
		for _ = 1, zone:GetAttribute("Count") or 0 do
			spawnInZone(zone)
		end
	end
	task.spawn(function()
		while true do
			task.wait(Ambient.TICK)
			local now = os.clock()
			if Ambient.ENABLED then
				for _, player in Players:GetPlayers() do
					tickPlayer(player, now)
				end
			end
			tidy(now)
		end
	end)
end

return Spawner
