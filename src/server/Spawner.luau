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
local TESTBED = require(ReplicatedStorage.Shared.Config).TESTBED
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Variants = require(ReplicatedStorage.Shared.Pacing).Variants
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

--[[ Realm variants (Pacing.Variants, Enemies.variant) ]]

-- A stage key from a realm setting: "QC5", { "QC5", "QC7" } or "QC5-QC7". A range picks
-- at random, or with `depth` (0 near .. 1 deep) leans toward its top, give or take
-- Variants.AMBIENT_SPREAD stages. nil: the beast's own realm.
local function pickStage(setting: any, depth: number?): string?
	if not Config.VARIANTS then
		return nil
	end
	local range = setting
	if type(setting) == "string" then
		local lo, hi = string.match(setting, "^(%w+)%s*%-%s*(%w+)$")
		range = if lo then { lo, hi } else { setting, setting }
	end
	if type(range) ~= "table" then
		return nil
	end
	local lo, hi = Realms.ByKey[range[1]], Realms.ByKey[range[2] or range[1]]
	if not (lo and hi) then
		warn(`Spawner: unknown realm range {tostring(range[1])}..{tostring(range[2])}`)
		return nil
	end
	local a, b = Realms.index(lo.major, lo.minor), Realms.index(hi.major, hi.minor)
	if a > b then
		a, b = b, a
	end
	local i = if depth
		then math.floor(a + (b - a) * depth + (math.random() * 2 - 1) * Variants.AMBIENT_SPREAD + 0.5)
		else math.random(a, b)
	return Realms.Stages[math.clamp(i, a, b)].key
end

-- A tier forced by a zone (Spawns.Zones `tier` or the part's Tier attribute), if any.
local function zoneTier(zone: BasePart): string?
	if not Config.VARIANTS then
		return nil
	end
	local tuned = Spawns.Zones[zone.Name]
	local tier = (tuned and tuned.tier) or zone:GetAttribute("Tier")
	return if type(tier) == "string" and Variants.TIERS[tier] then tier else nil
end

--[[ Zones ]]

local function spawnInZone(zone: BasePart)
	local id = zone:GetAttribute("Enemy")
	if type(id) ~= "string" then
		return
	end
	local radius = zoneRadius(zone)
	local tuned = Spawns.Zones[zone.Name]
	-- a zone's realm (Spawns.Zones `realm`, else the part's Realm attribute) is rolled per
	-- beast, so a range spawns a mix of strengths
	local model = EnemyService.spawn(id, randomPointNear(zone.Position, radius * 0.8), {
		home = zone.Position,
		roam = radius * 0.6,
		stage = pickStage((tuned and tuned.realm) or zone:GetAttribute("Realm")),
		tier = zoneTier(zone),
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

local function pickPack(packs: { Spawns.Pack }): ({ [string]: number }, Spawns.Pack)
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
	return beasts, chosen
end

-- How deep a spot is into its region, 0 at the near edge to 1 at the far (Regions `depth`:
-- flat distance from the sect's centre), for a pack's realm range.
local function depthOf(region: Regions.Region, at: Vector3): number?
	local depth = region.depth
	if not depth then
		return nil
	end
	local distance = Vector2.new(at.X, at.Z).Magnitude
	return math.clamp((distance - depth[1]) / math.max(depth[2] - depth[1], 1), 0, 1)
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
	local beasts, chosen = pickPack(packs)
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
	local depth = depthOf(region :: Regions.Region, spot)
	for id, count in beasts do
		for _ = 1, count do
			-- each beast rolls its own realm in the pack's range, leaning deeper farther in
			local model = EnemyService.spawn(id, randomPointNear(spot, 4), {
				roam = Ambient.ROAM,
				target = player,
				stage = pickStage(chosen.realm, depth),
			})
			if model then
				ambient[model] = { player = player, lonely = now }
			end
		end
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
			local tuned = Spawns.Zones[zone.Name]
			local respawn = (tuned and tuned.respawn) or (if def then def.respawn else 30)
			local spread = 1 + (math.random() * 2 - 1) * Config.RESPAWN_SPREAD
			task.delay(respawn * spread, spawnInZone, zone)
		end
	end)
	for _, zone in zones() do
		local tuned = Spawns.Zones[zone.Name]
		for _ = 1, (tuned and tuned.count) or zone:GetAttribute("Count") or 0 do
			spawnInZone(zone)
		end
	end
	task.spawn(function()
		while true do
			task.wait(Ambient.TICK)
			local now = os.clock()
			if Ambient.ENABLED and not TESTBED then -- the testbed only has what you spawn
				for _, player in Players:GetPlayers() do
					tickPlayer(player, now)
				end
			end
			tidy(now)
		end
	end)
end

return Spawner
