--!strict
-- Circulation runs: the skill minigames that refine raw qi into cultivation.
-- The server picks the game (Config.Circulation.Games, weighted, not the same one
-- twice running) and its length, difficulty and impurity count; the client plays
-- it and reports an accuracy and how many impurities it purged, scored the same
-- way for every game. The server enforces where and how often runs happen and
-- sanity-checks the report (clamped score, minimum duration, qi actually held).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Circulation
local Peak = require(ReplicatedStorage.Shared.Peak)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local WeatherService = require(script.Parent.WeatherService)

type Run = { id: string, started: number, duration: number, impurities: number, stageIndex: number }

local runs: { [Player]: Run } = {}
local lastGame: { [Player]: string } = {}

local Circulation = {}

-- Called with (player, score 0-1) after every scored run, for analytics.
Circulation.onFinished = {} :: { (Player, number) -> () }

local function fullRunQi(stage: Realms.Stage): number
	return math.floor(stage.dantian / Config.RUNS_PER_DANTIAN)
end

-- A weighted pick from Config.Games, avoiding the player's last game when another can run.
local function pickGame(player: Player): string
	local total, pool = 0, {}
	for name, def in Config.Games do
		if def.weight > 0 and name ~= lastGame[player] then
			total += def.weight
			table.insert(pool, name)
		end
	end
	if total == 0 then
		return lastGame[player] or "Circuit"
	end
	table.sort(pool) -- pairs order isn't stable; keep the roll reproducible
	local roll = math.random() * total
	for _, name in pool do
		roll -= Config.Games[name].weight
		if roll <= 0 then
			return name
		end
	end
	return pool[#pool]
end

-- On your own peak, or within a qi node's radius (CollectionService tag "QiNode").
local function atRefiningSpot(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local peak = Peaks.ownedBy(player)
	if peak then
		local offset = Peak.frame(peak):PointToObjectSpace(root.Position)
		if Vector2.new(offset.X, offset.Z).Magnitude <= Config.PEAK_RADIUS and math.abs(offset.Y) <= Config.PEAK_RADIUS then
			return true
		end
	end
	for _, node in CollectionService:GetTagged("QiNode") do
		if node:IsA("BasePart") and node:IsDescendantOf(workspace) then
			local radius = node:GetAttribute("Radius") or 16
			if (node.Position - root.Position).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end

function Circulation.start(player: Player): (boolean, any)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local now = os.clock()
	local active = runs[player]
	if active and now - active.started < active.duration + Config.RUN_TIMEOUT_GRACE then
		return false, "You're already circulating"
	end
	if Cultivation.deviated(player) then
		return false, "Your qi is still in deviation. Let it settle."
	end
	local stage = Cultivation.stage(data)
	if data.cultivation >= stage.bar then
		return false, "Your realm bar is full. Break through first."
	end
	if data.rawQi < fullRunQi(stage) * Config.MIN_RUN_FRACTION then
		return false, "Your dantian is nearly empty. Go out and gather qi."
	end
	if not atRefiningSpot(player) then
		return false, "Circulate on your own peak or at a qi node."
	end

	local index = Realms.index(data.realm.major, data.realm.minor)
	local duration = math.min(Config.DURATION_MAX, Config.DURATION_START + Config.DURATION_STEP * (index - 1))
	local difficulty = math.clamp((index - 1) / Config.DIFFICULTY_STAGES * Config.DIFFICULTY, 0, 1)
	local minigame = pickGame(player)
	if data.stats.circulationRuns == 0 then
		-- the onboarding run: short, forgiving, and the game the elder explains
		duration = Config.FIRST_RUN_DURATION
		difficulty = Config.FIRST_RUN_DIFFICULTY
		minigame = "Circuit"
	end
	lastGame[player] = minigame
	local run = {
		id = HttpService:GenerateGUID(false),
		started = now,
		duration = duration,
		impurities = math.max(1, math.floor(duration / 10 * Config.IMPURITIES_PER_10S + 0.5)),
		stageIndex = index,
	}
	runs[player] = run
	return true,
		{
			id = run.id,
			game = minigame,
			duration = duration,
			difficulty = difficulty,
			impurities = run.impurities,
			seed = math.random(1, 1e6),
		}
end

function Circulation.finish(player: Player, id: any, accuracy: any, purged: any): (boolean, any)
	local run = runs[player]
	local data = PlayerData.get(player)
	if not (run and data and run.id == id) then
		return false, "That run has ended"
	end
	runs[player] = nil
	if os.clock() - run.started < run.duration * Config.MIN_DURATION_FRACTION then
		return false, "The run ended too soon"
	end
	local stage = Cultivation.stage(data)
	if Realms.index(data.realm.major, data.realm.minor) ~= run.stageIndex then
		return false, "Your realm changed during the run"
	end

	local acc = if type(accuracy) == "number" and accuracy == accuracy then math.clamp(accuracy, 0, 1) else 0
	local purgedShare = if type(purged) == "number" then math.clamp(math.floor(purged), 0, run.impurities) / run.impurities else 0
	local score = acc * Config.ACCURACY_WEIGHT + purgedShare * (1 - Config.ACCURACY_WEIGHT)
	local efficiency = (Config.EFFICIENCY_MIN + (Config.EFFICIENCY_MAX - Config.EFFICIENCY_MIN) * score)
		* (1 + WeatherService.bonus("circulation"))

	-- spend only what fills the bar; the rest stays in the dantian
	local qi = math.min(data.rawQi, fullRunQi(stage))
	local gain = math.min(qi * efficiency, stage.bar - data.cultivation)
	local spent = math.ceil(gain / efficiency)
	data.rawQi = math.max(0, data.rawQi - spent)
	data.cultivation = math.min(stage.bar, data.cultivation + gain)
	data.stats.circulationRuns += 1

	local deviation = score < Config.DEVIATION_SCORE
	if deviation then
		Cultivation.deviate(player, Config.DEVIATION_SECONDS)
	end
	for _, fn in Circulation.onFinished do
		task.spawn(fn, player, score)
	end
	Cultivation.markActive(player)
	Cultivation.pushState(player)
	return true,
		{
			score = score,
			gain = math.floor(gain),
			spent = spent,
			deviation = deviation,
			full = data.cultivation >= stage.bar,
		}
end

function Circulation.handle(player: Player, action: any, ...: any): (boolean, any)
	if action == "start" then
		return Circulation.start(player)
	elseif action == "finish" then
		return Circulation.finish(player, ...)
	elseif action == "breakthrough" then
		return Cultivation.breakthrough(player)
	end
	return false, "Unknown action"
end

function Circulation.forget(player: Player)
	runs[player] = nil
	lastGame[player] = nil
end

return Circulation
