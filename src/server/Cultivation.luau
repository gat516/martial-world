--!strict
-- Passive cultivation fills the realm bar every second at the realm's slow rate,
-- boosted by eaten-herb buffs, by the spirit aura of mature herbs left growing in
-- the player's beds, and by meditating (Meditation.luau). It stops at a full bar;
-- breakthroughs move the player on.
-- Also owns breakthroughs, qi deviation, the passive-progress warnings, per-realm
-- character stats and the PlayerState push the HUD renders from.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Cultivation
local CirculationConfig = require(ReplicatedStorage.Shared.Config).Circulation
local LoginConfig = require(ReplicatedStorage.Shared.Config).Login
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Realms = require(ReplicatedStorage.Shared.Realms)
local PlayerData = require(script.Parent.PlayerData)
local WeatherService = require(script.Parent.WeatherService)

local remotes = ReplicatedStorage.Remotes
local stateRemote = remotes.PlayerState :: RemoteEvent
local notifyRemote = remotes.Notify :: RemoteEvent
local breakthroughRemote = remotes.Breakthrough :: RemoteEvent

local Cultivation = {}

-- Per-session state that isn't saved.
type Session = { deviationUntil: number, lastActive: number, lastWarned: number, fullNoticed: boolean }
local sessions: { [Player]: Session } = {}

local function session(player: Player): Session
	local s = sessions[player]
	if not s then
		s = { deviationUntil = 0, lastActive = os.clock(), lastWarned = -math.huge, fullNoticed = false }
		sessions[player] = s
	end
	return s
end

function Cultivation.notify(player: Player, message: string)
	notifyRemote:FireClient(player, message)
end

-- Something active happened (a run, a breakthrough, later a kill): hold off the
-- "go and experience the world" warnings.
function Cultivation.markActive(player: Player)
	session(player).lastActive = os.clock()
end

function Cultivation.deviated(player: Player): boolean
	return os.clock() < session(player).deviationUntil
end

function Cultivation.deviate(player: Player, seconds: number)
	local s = session(player)
	s.deviationUntil = os.clock() + seconds
	player:SetAttribute("DeviationUntil", workspace:GetServerTimeNow() + seconds)
end

function Cultivation.aura(data: PlayerData.Data, now: number): number
	local total = 0
	for _, plot in data.peak.plots do
		local herb = Herbs.Defs[plot.herb]
		if herb and now - plot.planted >= herb.growSeconds then
			total += herb.aura
		end
	end
	return total
end

local function buffTotal(data: PlayerData.Data, kind: string): number
	local total = 0
	for _, b in data.buffs do
		if b.kind == kind then
			total += b.amount
		end
	end
	return total
end

function Cultivation.stage(data: PlayerData.Data): Realms.Stage
	return Realms.get(data.realm.major, data.realm.minor)
end

-- Set by Meditation: where the player is meditating and its passive multiplier,
-- or nil when they aren't.
Cultivation.meditation = nil :: ((Player) -> { multiplier: number, place: string }?)?

-- Passive cultivation per second.
function Cultivation.rate(data: PlayerData.Data, now: number, player: Player?): number
	local spot = if player and Cultivation.meditation then Cultivation.meditation(player) else nil
	return Cultivation.stage(data).passive
		* (1 + buffTotal(data, "QiRate"))
		* (1 + Cultivation.aura(data, now))
		* (1 + WeatherService.bonus("passive"))
		* (if spot then spot.multiplier else 1)
end

-- Mirror the numbers that change every second (and that other players may show,
-- like the realm) as attributes, so the HUD doesn't wait for a state push.
local function publish(player: Player, data: PlayerData.Data)
	local stage = Cultivation.stage(data)
	player:SetAttribute("Realm", stage.name)
	player:SetAttribute("Cultivation", math.floor(data.cultivation))
	player:SetAttribute("CultivationMax", stage.bar)
	player:SetAttribute("RawQi", math.floor(data.rawQi))
	player:SetAttribute("DantianCap", stage.dantian)
end

function Cultivation.pushState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local now = os.time()
	publish(player, data)
	stateRemote:FireClient(player, {
		insight = data.insight,
		techniques = data.techniques,
		rate = Cultivation.rate(data, now, player),
		aura = Cultivation.aura(data, now),
		meditation = if Cultivation.meditation then Cultivation.meditation(player) else nil,
		herbs = data.herbs,
		seeds = data.seeds,
		buffs = data.buffs,
		decor = data.decor,
	})
end

local function applyStats(player: Player, data: PlayerData.Data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.BASE_WALKSPEED + buffTotal(data, "WalkSpeed")
		local maxHealth = Cultivation.stage(data).health
		if humanoid.MaxHealth ~= maxHealth then
			local fraction = humanoid.Health / humanoid.MaxHealth
			humanoid.MaxHealth = maxHealth
			humanoid.Health = maxHealth * fraction
		end
	end
end

-- Eat a herb from the pouch: raw Qi now, plus its timed buffs.
function Cultivation.eat(player: Player, herbId: string): (boolean, string?)
	local data = PlayerData.get(player)
	local herb = Herbs.Defs[herbId]
	if not (data and herb) then
		return false, "Unknown herb"
	end
	if (data.herbs[herbId] or 0) < 1 then
		return false, "You have none left"
	end
	data.herbs[herbId] -= 1
	if data.herbs[herbId] <= 0 then
		data.herbs[herbId] = nil
	end
	local cap = Cultivation.stage(data).dantian
	data.rawQi = math.min(cap, data.rawQi + (herb.eat.qi or 0))
	local now = os.time()
	for _, b in herb.eat.buffs or {} do
		-- eating the same herb again refreshes its buff instead of stacking it
		local existing
		for _, active in data.buffs do
			if active.source == herbId and active.kind == b.kind then
				existing = active
			end
		end
		if existing then
			existing.expires = math.max(existing.expires, now + b.seconds)
		else
			table.insert(data.buffs, { source = herbId, kind = b.kind, amount = b.amount, expires = now + b.seconds })
		end
	end
	applyStats(player, data)
	Cultivation.pushState(player)
	return true, `Ate {herb.name}: {herb.blurb}`
end

-- Set by Tribulation: starts the tribulation a major breakthrough needs.
Cultivation.startTribulation = nil :: ((Player) -> (boolean, string?))?

-- Move the player up to the next stage. Major breakthroughs are announced to everyone.
function Cultivation.advance(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local stage = Cultivation.stage(data)
	local nextStage = Realms.after(stage.major, stage.minor)
	if not nextStage then
		return
	end
	local major = nextStage.major ~= stage.major
	data.realm = { major = nextStage.major, minor = nextStage.minor }
	data.cultivation = 0
	data.rawQi = math.min(data.rawQi, nextStage.dantian)
	data.stats.breakthroughs += 1
	local s = session(player)
	s.fullNoticed = false
	s.lastActive = os.clock()
	applyStats(player, data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	Cultivation.pushState(player)
	breakthroughRemote:FireAllClients(player, nextStage.name, major)
	for _, fn in Cultivation.onBreakthrough do
		task.spawn(fn, player, nextStage, major)
	end
end

-- Called with (player, newStage, major) after every breakthrough.
Cultivation.onBreakthrough = {} :: { (Player, Realms.Stage, boolean) -> () }

-- Minor breakthroughs (within a major realm) happen at once on a full bar.
-- Major ones need insight and survive a tribulation first.
function Cultivation.breakthrough(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local stage = Cultivation.stage(data)
	local nextStage = Realms.after(stage.major, stage.minor)
	if not nextStage then
		return false, "You stand at the peak of this world's cultivation, for now."
	end
	if data.cultivation < stage.bar then
		return false, "Your realm bar isn't full yet."
	end
	if data.insight < stage.insight then
		return false, "You feel as if you need more insight."
	end
	if nextStage.major ~= stage.major then
		if Cultivation.startTribulation then
			return Cultivation.startTribulation(player)
		end
		return false, "The heavens are silent."
	end
	Cultivation.advance(player)
	return true, nil -- the client shows its own title card
end

-- The flavor line for a player whose passive progress has fallen far behind what
-- active play would give, or nil when there's nothing to say.
local function warning(player: Player, data: PlayerData.Data, rate: number): string?
	local stage = Cultivation.stage(data)
	local s = session(player)
	if data.cultivation >= stage.bar then
		local first = not s.fullNoticed
		s.fullNoticed = true
		if data.insight < stage.insight then
			return "You feel as if you need more insight."
		end
		return if first then "Your meridians brim with qi. Break through!" else nil
	end
	if os.clock() - s.lastActive < Config.WARN_IDLE_SECONDS then
		return nil
	end
	local activeRate = stage.passive / Config.PASSIVE_SHARE
	if rate > 0 and activeRate / rate < Config.WARN_RATIO then
		return nil
	end
	local runQi = stage.dantian / CirculationConfig.RUNS_PER_DANTIAN * CirculationConfig.MIN_RUN_FRACTION
	if data.rawQi >= runQi then
		return "Qi stirs in your dantian. Circulate to refine it."
	end
	return "You must go out and experience the world."
end

-- On login: cultivation gathered while away (passive rate, up to the bar and the
-- offline cap), and the first-login-of-the-day raw qi bonus. Returns what was
-- claimed, for the caller to report.
function Cultivation.claimLogin(player: Player, data: PlayerData.Data): (number, number)
	local now = os.time()
	local stage = Cultivation.stage(data)
	local offline = 0
	if data.lastLogoutUnix > 0 then
		local away = math.clamp(now - data.lastLogoutUnix, 0, LoginConfig.OFFLINE_MAX_HOURS * 3600)
		offline = math.min(stage.passive * LoginConfig.OFFLINE_RATE * away, stage.bar - data.cultivation)
		offline = math.max(0, math.floor(offline))
		data.cultivation += offline
	end
	local daily = 0
	local today = now // 86400
	if data.lastDailyDay ~= today then
		data.lastDailyDay = today
		daily = math.min(math.floor(stage.dantian * LoginConfig.DAILY_QI_SHARE), stage.dantian - data.rawQi)
		daily = math.max(0, daily)
		data.rawQi += daily
	end
	task.delay(4, function()
		if player.Parent == nil then
			return
		end
		if offline > 0 then
			Cultivation.notify(player, `While you were away, your qi circulated on its own: +{offline} cultivation.`)
		end
		if daily > 0 then
			task.wait(if offline > 0 then 4 else 0)
			Cultivation.notify(player, `A new day on the mountain: +{daily} raw qi.`)
		end
	end)
	return offline, daily
end

function Cultivation.forget(player: Player)
	sessions[player] = nil
end

function Cultivation.watch(player: Player)
	player.CharacterAdded:Connect(function()
		local data = PlayerData.get(player)
		if data then
			task.defer(applyStats, player, data)
		end
	end)
end

task.spawn(function()
	local sinceRefresh = 0
	while true do
		local dt = task.wait(1)
		local now = os.time()
		sinceRefresh += dt
		for _, player in Players:GetPlayers() do
			local data = PlayerData.get(player)
			if data then
				local expired = false
				for i = #data.buffs, 1, -1 do
					if data.buffs[i].expires <= now then
						table.remove(data.buffs, i)
						expired = true
					end
				end
				local bar = Cultivation.stage(data).bar
				local rate = if Cultivation.deviated(player) then 0 else Cultivation.rate(data, now, player)
				data.cultivation = math.min(bar, data.cultivation + rate * dt)
				publish(player, data)
				local s = session(player)
				if os.clock() - s.lastWarned >= Config.WARN_INTERVAL or (data.cultivation >= bar and not s.fullNoticed) then
					local message = warning(player, data, rate)
					if message then
						s.lastWarned = os.clock()
						Cultivation.notify(player, message)
					end
				end
				if expired then
					applyStats(player, data)
				end
				if expired or sinceRefresh >= Config.STATE_REFRESH_SECONDS then
					Cultivation.pushState(player)
				end
			end
		end
		if sinceRefresh >= Config.STATE_REFRESH_SECONDS then
			sinceRefresh = 0
		end
	end
end)

return Cultivation
