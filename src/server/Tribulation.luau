--!strict
-- The heavenly tribulation: a major breakthrough (QC9 -> Foundation) sends the
-- player to the main peak's tribulation platform to survive 30 seconds of
-- lightning. Every bolt is telegraphed; they come faster and land quicker as it
-- goes on. Lightning can't kill: a player knocked to 1 health fails, which costs
-- a cooldown, never cultivation. Leaving the platform also fails it.
-- The whole server is told, and every client draws the bolts from the sky, so
-- the storm is visible from every peak.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Tribulation
local Cultivation = require(script.Parent.Cultivation)
local EnemyService = require(script.Parent.EnemyService)

local remotes = ReplicatedStorage.Remotes
local effectRemote = remotes.Effect :: RemoteEvent
local notifyRemote = remotes.Notify :: RemoteEvent

local active: { [Player]: boolean } = {}
local readyAt: { [Player]: number } = {}

local Tribulation = {}

function Tribulation.isActive(player: Player): boolean
	return active[player] == true
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

local function finish(player: Player, survived: boolean)
	active[player] = nil
	effectRemote:FireAllClients("tribulationEnd", player, survived)
	if player.Parent == nil then
		return
	end
	if survived then
		notifyRemote:FireAllClients(`{player.DisplayName} survived the heavenly tribulation!`)
		Cultivation.advance(player)
	else
		readyAt[player] = os.clock() + Config.FAIL_COOLDOWN
		Cultivation.notify(player, `The tribulation overwhelmed you. Steady your qi and try again in {Config.FAIL_COOLDOWN // 60} minutes.`)
	end
end

-- Height of the platform floor under the centre (strikes are drawn on it).
local function floorY(): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
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

local function run(player: Player)
	local started = os.clock()
	local center = Config.CENTER
	local floor = floorY()
	while os.clock() - started < Config.SECONDS do
		local humanoid, root = humanoidOf(player)
		if not (humanoid and root) or player.Parent == nil then
			finish(player, false)
			return
		end
		local offset = root.Position - center
		if Vector2.new(offset.X, offset.Z).Magnitude > Config.ARENA_RADIUS or math.abs(offset.Y) > 30 then
			finish(player, false)
			return
		end
		if humanoid.Health <= 1 then
			finish(player, false)
			return
		end
		local t = (os.clock() - started) / Config.SECONDS
		local windup = Config.WINDUP_START + (Config.WINDUP_END - Config.WINDUP_START) * t
		local interval = Config.INTERVAL_START + (Config.INTERVAL_END - Config.INTERVAL_START) * t
		-- aim at or near the player, kept on the platform
		local a, r = math.random() * math.pi * 2, math.random() * Config.SCATTER
		local at = root.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local flat = Vector2.new(at.X - center.X, at.Z - center.Z)
		if flat.Magnitude > Config.ARENA_RADIUS - 4 then
			flat = flat.Unit * (Config.ARENA_RADIUS - 4)
		end
		local ground = Vector3.new(center.X + flat.X, floor, center.Z + flat.Y)
		local damage = humanoid.MaxHealth * Config.DAMAGE_SHARE
		task.spawn(function()
			EnemyService.strike({ kind = "circle", center = ground, radius = Config.STRIKE_RADIUS }, windup, damage, true, player)
			effectRemote:FireAllClients("bolt", ground)
		end)
		task.wait(interval)
	end
	-- let the last strikes land before judging
	task.wait(Config.WINDUP_START)
	local humanoid = humanoidOf(player)
	finish(player, humanoid ~= nil and humanoid.Health > 1)
end

function Tribulation.start(player: Player): (boolean, string?)
	if active[player] then
		return false, "The tribulation is already upon you!"
	end
	local wait = (readyAt[player] or 0) - os.clock()
	if wait > 0 then
		return false, `Your qi is still unsettled. Try again in {math.ceil(wait)}s.`
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return false, "You can't face the heavens right now."
	end
	active[player] = true
	humanoid.Health = humanoid.MaxHealth
	;(player.Character :: Model):PivotTo(CFrame.new(Config.CENTER + Vector3.new(0, 3, 0)))
	notifyRemote:FireAllClients(`{player.DisplayName} is facing the heavenly tribulation!`)
	effectRemote:FireAllClients("tribulationStart", player, Config.CENTER)
	task.spawn(run, player)
	return true, "Heavenly lightning gathers. Survive for 30 seconds!"
end

function Tribulation.forget(player: Player)
	active[player] = nil
	readyAt[player] = nil
end

Cultivation.startTribulation = Tribulation.start

return Tribulation
