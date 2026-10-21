--!strict
-- The heavenly tribulation: a major breakthrough (QC9 -> Foundation) sends the
-- player to the main peak's tribulation platform to survive a storm of
-- lightning. How long and how hard is set per stage in Pacing.luau (the stage
-- being left's `tribulation`); the arena is Config.Tribulation. Every bolt is
-- telegraphed; they come faster and land quicker as it goes on. Lightning can't
-- kill: a player knocked to 1 health fails, which costs a cooldown, never
-- cultivation. Leaving the platform also fails it.
-- The whole server is told, and every client draws the bolts from the sky, so
-- the storm is visible from every peak.
-- One player at a time: the platform is reachable only by starting a
-- tribulation, anyone else on it is sent down to the plaza's array when one
-- starts (or if they get up there during it), and the challenger is sent down
-- a few seconds after it ends. Players turned away while it's taken are told
-- when it clears. Failing costs a cooldown, saved with the profile so
-- rejoining doesn't skip it, so nobody can chain attempts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Tribulation
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Cultivation = require(script.Parent.Cultivation)
local EnemyService = require(script.Parent.EnemyService)
local PlayerData = require(script.Parent.PlayerData)
local Travel = require(script.Parent.Travel)

local remotes = ReplicatedStorage.Remotes
local effectRemote = remotes.Effect :: RemoteEvent
local notifyRemote = remotes.Notify :: RemoteEvent

-- The trial in progress (only one at a time), and when its last strike lands.
local current: { player: Player, def: Pacing.Tribulation, endsAt: number }? = nil
-- Players turned away while the platform was taken, told when it clears.
local waiting: { [Player]: true } = {}

local Tribulation = {}

function Tribulation.isActive(player: Player): boolean
	return current ~= nil and current.player == player
end

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function onPlatform(position: Vector3): boolean
	local offset = position - Config.CENTER
	return Vector2.new(offset.X, offset.Z).Magnitude <= Config.ARENA_RADIUS and math.abs(offset.Y) <= 30
end

-- Down to the main peak's plaza array.
local function sendDown(player: Player)
	local character = player.Character
	local target = Travel.arrival(player, "MainPeak")
	if character and target then
		character:PivotTo(target)
	end
end

-- Sends everyone but the challenger off the platform.
local function clearPlatform(challenger: Player)
	for _, other in Players:GetPlayers() do
		local _, root = humanoidOf(other)
		if other ~= challenger and root and onPlatform(root.Position) then
			sendDown(other)
			Cultivation.notify(other, `The heavens descend on {challenger.DisplayName}. Watch from below.`)
		end
	end
end

-- Called with (player, survived) when a tribulation ends, for analytics.
Tribulation.onFinished = {} :: { (Player, boolean) -> () }

local function finish(player: Player, survived: boolean)
	local def = current and current.def
	current = nil
	for _, fn in Tribulation.onFinished do
		task.spawn(fn, player, survived)
	end
	effectRemote:FireAllClients("tribulationEnd", player, survived)
	for other in waiting do
		if other.Parent and other ~= player then
			Cultivation.notify(other, "The storm over the main peak has passed. The heavens will hear you now.")
		end
	end
	table.clear(waiting)
	if player.Parent == nil then
		return
	end
	-- a moment to take in the result, then off the platform for the next one
	task.delay(Config.RETURN_DELAY, function()
		local _, root = humanoidOf(player)
		if player.Parent and root and onPlatform(root.Position) and not Tribulation.isActive(player) then
			sendDown(player)
		end
	end)
	if survived then
		notifyRemote:FireAllClients(`{player.DisplayName} survived the heavenly tribulation!`)
		Cultivation.advance(player)
	else
		local cooldown = if def then def.failCooldown else 0
		local data = PlayerData.get(player)
		if data then
			data.tribulationReadyUnix = os.time() + cooldown
		end
		local wait = if cooldown >= 60 then `{cooldown // 60} minutes` else `{math.ceil(cooldown)} seconds`
		Cultivation.notify(player, `The tribulation overwhelmed you. Steady your qi and try again in {wait}.`)
	end
end

-- Height of the platform floor under the centre (strikes are drawn on it).
-- Only solid parts count: the platform carries invisible, non-colliding effect
-- parts above the floor that would otherwise put every strike in the air.
local function floorY(): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local characters = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(characters, p.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	local hit = workspace:Raycast(Config.CENTER + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else Config.CENTER.Y - 1.5
end

local function run(player: Player, def: Pacing.Tribulation)
	local started = os.clock()
	local center = Config.CENTER
	local floor = floorY()
	while os.clock() - started < def.seconds do
		local humanoid, root = humanoidOf(player)
		if not (humanoid and root) or player.Parent == nil then
			finish(player, false)
			return
		end
		if not onPlatform(root.Position) or humanoid.Health <= 1 then
			finish(player, false)
			return
		end
		clearPlatform(player)
		local t = (os.clock() - started) / def.seconds
		local windup = def.windupStart + (def.windupEnd - def.windupStart) * t
		local interval = def.intervalStart + (def.intervalEnd - def.intervalStart) * t
		-- aim at or near the player, kept on the platform
		local a, r = math.random() * math.pi * 2, math.random() * def.scatter
		local at = root.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local flat = Vector2.new(at.X - center.X, at.Z - center.Z)
		if flat.Magnitude > Config.ARENA_RADIUS - 4 then
			flat = flat.Unit * (Config.ARENA_RADIUS - 4)
		end
		local ground = Vector3.new(center.X + flat.X, floor, center.Z + flat.Y)
		local damage = humanoid.MaxHealth * def.damageShare
		task.spawn(function()
			EnemyService.strike({ kind = "circle", center = ground, radius = Config.STRIKE_RADIUS }, windup, damage, true, player, "Tribulation")
			effectRemote:FireAllClients("bolt", ground)
		end)
		task.wait(interval)
	end
	-- let the last strikes land before judging
	task.wait(def.windupStart)
	local humanoid = humanoidOf(player)
	finish(player, humanoid ~= nil and humanoid.Health > 1)
end

function Tribulation.start(player: Player): (boolean, string?)
	if current and current.player == player then
		return false, "The tribulation is already upon you!"
	end
	if current then
		waiting[player] = true
		local left = math.max(1, math.ceil(current.endsAt - os.clock()))
		return false, `{current.player.DisplayName} is facing the heavens. Wait for the storm to pass ({left}s); you'll be told when it does.`
	end
	local data = PlayerData.get(player)
	local wait = if data then data.tribulationReadyUnix - os.time() else 0
	if wait > 0 then
		return false, `Your qi is still unsettled. Try again in {wait}s.`
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return false, "You can't face the heavens right now."
	end
	local def = data and Cultivation.stage(data).tribulation
	if not def then
		return false, "The heavens are silent."
	end
	current = { player = player, def = def, endsAt = os.clock() + def.seconds + def.windupStart }
	waiting[player] = nil
	humanoid.Health = humanoid.MaxHealth
	;(player.Character :: Model):PivotTo(CFrame.new(Config.CENTER + Vector3.new(0, 3, 0)))
	clearPlatform(player)
	notifyRemote:FireAllClients(`{player.DisplayName} is facing the heavenly tribulation!`)
	effectRemote:FireAllClients("tribulationStart", player, Config.CENTER)
	task.spawn(run, player, def)
	return true, `Heavenly lightning gathers. Survive for {def.seconds} seconds!`
end

-- A leaving challenger's trial is failed by its own loop on the next check.
function Tribulation.forget(player: Player)
	waiting[player] = nil
end

Cultivation.startTribulation = Tribulation.start

return Tribulation
