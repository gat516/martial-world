--!strict
-- Passive cultivation fills the realm bar every second at the realm's slow rate,
-- boosted by eaten-herb buffs (stacking with falloff, capped by major), by meditating
-- (Meditation.luau) and, while meditating on their own peak, by the spirit aura of
-- every plant in their plots (Pacing.Aura). It keeps filling past
-- the bar up to the overflow cap (Pacing.Breakthrough.OVERFLOW_CAP) without moving
-- the realm; breakthroughs (seated only) move the player on and carry some of the excess.
-- Also owns breakthroughs, qi deviation, the passive-progress warnings, per-realm
-- character stats and the PlayerState push the HUD renders from.
-- AFK (decided 2026-10-23): online with no input for Pacing.Income.AFK_AFTER, or in
-- seclusion (Seclusion.luau), earns exactly what offline would (Cultivation.afkRate),
-- out of one OFFLINE_MAX_HOURS budget a UTC day shared with offline time
-- (Cultivation.awayLeft). At the overflow cap it says once (and again
-- on coming back from AFK or offline) that the dantian is full; nothing breaks
-- through on its own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Cultivation
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Movement = require(script.Parent.Movement)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry) -- race, variant and trait modifiers
local Methods = require(ReplicatedStorage.Shared.Methods)
local StarterPlayer = game:GetService("StarterPlayer")
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)
local HeartDemon = require(script.Parent.HeartDemon)
local WeatherService = require(script.Parent.WeatherService)
local Analytics = require(script.Parent.Analytics)

local remotes = ReplicatedStorage.Remotes
local stateRemote = remotes.PlayerState :: RemoteEvent
local notifyRemote = remotes.Notify :: RemoteEvent
local breakthroughRemote = remotes.Breakthrough :: RemoteEvent

local Cultivation = {}

local CAP_LINE = "Your dantian can hold no more. Break through."

-- Per-session state that isn't saved.
type Session = {
	deviationUntil: number,
	lastActive: number,
	lastWarned: number,
	fullNoticed: boolean,
	lastInput: number, -- os.clock() of the last input ping or active action
	wasAfk: boolean,
	capNoticed: boolean, -- the "dantian can hold no more" line was shown for this stretch
}
local sessions: { [Player]: Session } = {}

local function session(player: Player): Session
	local s = sessions[player]
	if not s then
		local now = os.clock()
		s = { deviationUntil = 0, lastActive = now, lastWarned = -math.huge, fullNoticed = false, lastInput = now, wasAfk = false, capNoticed = false }
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
	local s = session(player)
	s.lastActive = os.clock()
	s.lastInput = s.lastActive
end

-- The client saw input (its throttled "awake" ping on the Meditate remote).
function Cultivation.awake(player: Player)
	session(player).lastInput = os.clock()
end

-- Set by Seclusion: whether the player is in seclusion, and entering it (the
-- CultivationAction "seclusion", through Circulation.handle).
Cultivation.secluded = nil :: ((Player) -> boolean)?
Cultivation.enterSeclusion = nil :: ((Player) -> (boolean, string?))?

local function secluded(player: Player): boolean
	return Cultivation.secluded ~= nil and Cultivation.secluded(player)
end

-- AFK: in seclusion, or no input for Pacing.Income.AFK_AFTER seconds.
function Cultivation.afk(player: Player): boolean
	return secluded(player) or os.clock() - session(player).lastInput >= Pacing.Income.AFK_AFTER
end

function Cultivation.deviated(player: Player): boolean
	return os.clock() < session(player).deviationUntil
end

function Cultivation.deviate(player: Player, seconds: number)
	local s = session(player)
	s.deviationUntil = os.clock() + seconds
	player:SetAttribute("DeviationUntil", workspace:GetServerTimeNow() + seconds)
end

-- The garden's aura (Pacing.Aura): every plant in the plots radiates its herb's aura
-- (Herbs.aura) x size x mutations, GROWING of it until mature, summed and capped by
-- the major's CAP, lifted by up to DECOR of it by the peak score (`decor`, the score's
-- share of the tier's cap, 0..1). Cultivation.rate applies it on the owner's own peak.
function Cultivation.aura(data: PlayerData.Data, now: number, decor: number?): number
	local A = Pacing.Aura
	local total = 0
	for _, plants in data.peak.plots do
		for _, plant in plants do
			local share = if Herbs.progress(plant, now) >= 1 then 1 else A.GROWING
			total += Herbs.aura(plant.h) * plant.s * Herbs.multiplier(plant.m) * share
		end
	end
	local cap = (A.CAP[data.realm.major] or 0) * (1 + A.DECOR * math.clamp(decor or 0, 0, 1))
	return math.min(total, cap)
end

-- The sum of active buffs of `kind`. QiRate buffs from different sources stack with
-- falloff (the strongest whole, then Pacing.Herbs.BUFF_FALLOFF) up to BUFF_CAP by major.
local function buffTotal(data: PlayerData.Data, kind: string): number
	if kind ~= "QiRate" then
		local total = 0
		for _, b in data.buffs do
			if b.kind == kind then
				total += b.amount
			end
		end
		return total
	end
	local amounts = {}
	for _, b in data.buffs do
		if b.kind == kind then
			table.insert(amounts, b.amount)
		end
	end
	table.sort(amounts, function(a, b)
		return a > b
	end)
	local H = Pacing.Herbs
	local total = 0
	for i, amount in amounts do
		total += amount * (H.BUFF_FALLOFF[i] or 0)
	end
	return math.min(total, H.BUFF_CAP[data.realm.major] or total)
end
Cultivation.buffTotal = buffTotal

-- The player's stage as they live it: a heaven-defier's has the longer bar
-- (Pacing.HeavenDefying.BAR; Realms.forPlayer).
function Cultivation.stage(data: PlayerData.Data): Realms.Stage
	return Realms.forPlayer(Realms.get(data.realm.major, data.realm.minor), data.heavenDefying == true)
end

-- The stage after the player's, as they'll live it, or nil at the top (FE9).
local function nextOf(data: PlayerData.Data, stage: Realms.Stage): Realms.Stage?
	local after = Realms.after(stage.major, stage.minor)
	return if after then Realms.forPlayer(after, data.heavenDefying == true) else nil
end

-- Set by QiSurge: the stage a surging player fights at (the next one), nil otherwise.
Cultivation.surgeStage = nil :: ((Player) -> Realms.Stage?)?

-- The stage whose health and power the player has right now: their own, or the
-- next one during a qi surge (QiSurge, Pacing.Surge).
function Cultivation.fightStage(player: Player, data: PlayerData.Data): Realms.Stage
	return (Cultivation.surgeStage and Cultivation.surgeStage(player)) or Cultivation.stage(data)
end

-- The most cultivation the current stage holds: past the bar, up to the overflow cap.
function Cultivation.cap(data: PlayerData.Data): number
	return math.floor(Cultivation.stage(data).bar * Pacing.Breakthrough.OVERFLOW_CAP + 0.5)
end

-- Add `amount` cultivation, up to the overflow cap (never lowers it). Returns what was added.
function Cultivation.add(data: PlayerData.Data, amount: number): number
	local before = data.cultivation
	if amount > 0 and before < Cultivation.cap(data) then
		data.cultivation = math.min(Cultivation.cap(data), before + amount)
	end
	return data.cultivation - before
end

-- The active cultivation method's qi multiplier (passive, refining, gathering),
-- with the bonus for matching the root's element.
function Cultivation.methodSpeed(data: PlayerData.Data): number
	return Methods.speed(Methods.active(data.methods.active), data.root.element)
end

-- Why a full bar can't break into `nextStage` because of the method, or nil.
local function methodLimit(data: PlayerData.Data, nextStage: Realms.Stage): string?
	if Methods.allows(Methods.active(data.methods.active), nextStage) then
		return nil
	end
	return "Your method can take you no further. Elder Qingyun may have a task for you, or seek a stronger method out in the world."
end
Cultivation.methodLimit = methodLimit

-- What stops a seated breakthrough right now, "" when nothing does:
-- "peak" (no stage beyond), "method", then "bar" (not full yet).
-- Doesn't count the seat, the tribulation cooldown or a tribulation in progress.
function Cultivation.block(data: PlayerData.Data): string
	local stage = Cultivation.stage(data)
	local nextStage = nextOf(data, stage)
	if not nextStage then
		return "peak"
	end
	if methodLimit(data, nextStage) then
		return "method"
	end
	if data.cultivation < stage.bar then
		return "bar"
	end
	return ""
end

-- Set by Meditation: where the player is meditating and its passive multiplier,
-- or nil when they aren't. `own`: on their own peak; `decor`: the peak score's share
-- of the tier's cap there (lifts the aura cap, Pacing.Aura.DECOR).
Cultivation.meditation = nil :: ((Player) -> { multiplier: number, place: string, own: boolean?, decor: number? }?)?

-- Set by Combat: whether the player was hurt recently.
Cultivation.inCombat = nil :: ((Player) -> boolean)?

-- What AFK, seclusion and offline time earn per second: the stage's plain passive
-- times OFFLINE_RATE (no meditation, aura, weather, buffs, root or method).
function Cultivation.afkRate(data: PlayerData.Data): number
	return Cultivation.stage(data).passive * Pacing.Income.OFFLINE_RATE
end

-- Passive cultivation per second. The garden's aura counts only while meditating on
-- your own peak (the air of your spirit abode).
function Cultivation.rate(data: PlayerData.Data, now: number, player: Player?): number
	local spot = if player and Cultivation.meditation then Cultivation.meditation(player) else nil
	local aura = if spot and spot.own then Cultivation.aura(data, now, spot.decor) else 0
	return Cultivation.stage(data).passive
		* (1 + buffTotal(data, "QiRate"))
		* (1 + aura)
		* (1 + WeatherService.bonus("passive"))
		* (if spot then spot.multiplier else 1)
		* Roots.speed(data.root)
		* Cultivation.methodSpeed(data)
end

-- Mirror the numbers that change every second (and that other players may show,
-- like the realm) as attributes, so the HUD doesn't wait for a state push.
local function publish(player: Player, data: PlayerData.Data)
	local stage = Cultivation.stage(data)
	player:SetAttribute("Realm", stage.name)
	player:SetAttribute("Cultivation", math.floor(data.cultivation))
	player:SetAttribute("CultivationMax", stage.bar)
	player:SetAttribute("CultivationCap", Cultivation.cap(data))
	local block = Cultivation.block(data)
	player:SetAttribute("BreakthroughBlock", block)
	player:SetAttribute("BreakthroughReady", block == "")
	player:SetAttribute("RawQi", math.floor(data.rawQi))
	player:SetAttribute("DantianCap", stage.dantian)
	player:SetAttribute("Stones", data.stones)
	player:SetAttribute("Method", if data.methods.active ~= "" then data.methods.active else nil)
end

-- Called with (player, data) after every state push (Inventory syncs tools from it).
Cultivation.onPush = {} :: { (Player, PlayerData.Data) -> () }

function Cultivation.pushState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local now = os.time()
	publish(player, data)
	local spot = if Cultivation.meditation then Cultivation.meditation(player) else nil
	local shop = {}
	for _, id in Herbs.Order do
		shop[id] = Herbs.stockLeft(data.herbalist, id, data.realm.major, data.realm.minor, now)
	end
	stateRemote:FireClient(player, {
		techniques = data.techniques,
		rate = Cultivation.rate(data, now, player),
		aura = Cultivation.aura(data, now, spot and spot.decor),
		meditation = if Cultivation.meditation then Cultivation.meditation(player) else nil,
		herbs = data.herbs,
		shop = shop, -- the Herbalist's seeds left today for this player (HerbShop): id -> count
		items = data.items,
		hotbar = data.hotbar,
		seeds = data.seeds,
		ring = data.ring, -- spirit ring stacks (Haul.luau)
		ringSlots = (Pacing.Haul.RING_SLOTS[data.realm.major] or 0) + (data.sect.ring[data.realm.major] or 0), -- Haul.ringSlots
		buffs = data.buffs,
		decor = data.decor,
		settings = data.settings,
		weapons = data.weapons,
		dao = data.dao,
		caches = data.caches,
		seen = data.seen,
		inventoryView = data.inventoryView,
		root = data.root,
		methods = data.methods,
		daoPracticeReady = data.daoPracticeReadyUnix,
		foundation = Foundation.state(data),
		heartDemon = HeartDemon.state(data),
		herbarium = data.herbarium, -- the Herbarium's record (server Herbarium)
		titles = data.titles, -- earned titles and the worn one (server Titles; defs in Shared.Titles)
	})
	for _, fn in Cultivation.onPush do
		task.spawn(fn, player, data)
	end
end
Foundation.onChanged = Cultivation.pushState

function Cultivation.applyStats(player: Player, data: PlayerData.Data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local walkSpeed = Config.BASE_WALKSPEED + buffTotal(data, "WalkSpeed") + Roots.perk(data.root, "walk") + Registry.stat(data, "walk")
		humanoid:SetAttribute("BaseWalkSpeed", walkSpeed)
		Movement.apply(humanoid)
		local jump = 1 + Roots.perk(data.root, "jump") + Registry.stat(data, "jump")
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight * jump
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower * jump
		local maxHealth = math.floor(
			Cultivation.fightStage(player, data).health
				* (1 + Roots.perk(data.root, "health") + Registry.stat(data, "health"))
				* Foundation.multiplier(data) -- graded foundations (Pacing.Foundation)
				+ 0.5
		)
		if humanoid.MaxHealth ~= maxHealth then
			local fraction = humanoid.Health / humanoid.MaxHealth
			humanoid.MaxHealth = maxHealth
			humanoid.Health = maxHealth * fraction
		end
	end
end

-- The heart-demon trial reads the seat and refreshes stats after tempering.
HeartDemon.seated = function(player: Player): boolean
	return Cultivation.meditation ~= nil and Cultivation.meditation(player) ~= nil
end
HeartDemon.onChanged = function(player: Player)
	local data = PlayerData.get(player)
	if data then
		Cultivation.applyStats(player, data)
	end
	Cultivation.pushState(player)
end

-- Running is character state, so it resets on respawn and survives stat refreshes.
function Cultivation.setRunning(player: Player, on: any)
	if typeof(on) ~= "boolean" then
		return
	end
	local data = PlayerData.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid then
		return
	end
	local running = on and humanoid.Health > 0 and not humanoid.Sit and not humanoid:GetAttribute("ActionBusy")
	if humanoid:GetAttribute("Running") == running then
		return
	end
	humanoid:SetAttribute("Running", running)
	Cultivation.applyStats(player, data)
end

-- Add a timed buff from `source` (an item id). Using the same item again
-- refreshes its buff instead of stacking it.
function Cultivation.addBuff(data: PlayerData.Data, source: string, kind: string, amount: number, seconds: number)
	local now = os.time()
	for _, active in data.buffs do
		if active.source == source and active.kind == kind then
			active.expires = math.max(active.expires, now + seconds)
			active.seconds = active.expires - now -- the refreshed span, for the HUD's timer ring
			return
		end
	end
	table.insert(data.buffs, { source = source, kind = kind, amount = amount, expires = now + seconds, seconds = seconds })
end

-- Whether the heavens refuse this player: only heaven-defying cultivators face a
-- tribulation at a major breakthrough (docs/progression.md). Everyone else
-- breaks through quietly. Set `data.heavenDefying` from a heaven-defying
-- bloodline or root; nothing sets it yet.
function Cultivation.heavenDefying(data: PlayerData.Data): boolean
	return data.heavenDefying == true
end

-- Set by Tribulation: starts the tribulation a major breakthrough needs.
Cultivation.startTribulation = nil :: ((Player) -> (boolean, string?))?

-- Move the player up to the next stage, with the excess past the old bar carried
-- over (at most Pacing.Breakthrough.CARRY_SHARE of the new bar). Major breakthroughs
-- are announced to everyone. The stage being left gets its foundation percent.
function Cultivation.advance(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local stage = Cultivation.stage(data)
	local nextStage = nextOf(data, stage)
	if not nextStage then
		return
	end
	local major = nextStage.major ~= stage.major
	local percent = Foundation.seal(data) -- settles the stage being left, resets the count and deeds
	data.realm = { major = nextStage.major, minor = nextStage.minor }
	local excess = math.max(0, data.cultivation - stage.bar)
	data.cultivation = math.floor(math.min(excess, nextStage.bar * Pacing.Breakthrough.CARRY_SHARE))
	data.rawQi = math.min(data.rawQi, nextStage.dantian)
	data.stats.breakthroughs += 1
	local s = session(player)
	s.fullNoticed = false
	s.lastActive = os.clock()
	Cultivation.applyStats(player, data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	Cultivation.pushState(player)
	breakthroughRemote:FireAllClients(player, nextStage.name, major, percent)
	for _, fn in Cultivation.onBreakthrough do
		task.spawn(fn, player, nextStage, major)
	end
end

-- Called with (player, newStage, major) after every breakthrough.
Cultivation.onBreakthrough = {} :: { (Player, Realms.Stage, boolean) -> () }

-- Set by QiSurge: fire the qi surge (CultivationAction "surge").
Cultivation.surge = nil :: ((Player) -> (boolean, string?))?

-- Breakthroughs happen seated in meditation on a full bar: minor ones at once,
-- and a heaven-defying player must survive a tribulation before a major one. Never
-- standing: in a fight the bar's answer is the qi surge (QiSurge).
function Cultivation.breakthrough(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	local stage = Cultivation.stage(data)
	local nextStage = nextOf(data, stage)
	if not nextStage then
		return false, "You stand at the peak of this world's cultivation, for now."
	end
	local limit = methodLimit(data, nextStage)
	if limit then
		return false, limit
	end
	if secluded(player) then
		return false, "You are in seclusion. Rise to leave it first."
	end
	local major = nextStage.major ~= stage.major
	local seated = Cultivation.meditation ~= nil and Cultivation.meditation(player) ~= nil
	if not seated then
		return false, "Sit and meditate to break through."
	end
	if data.cultivation < stage.bar then
		return false, "Your realm bar isn't full yet."
	end
	if major and Cultivation.heavenDefying(data) then
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
		if not first then
			return nil
		end
		local nextStage = nextOf(data, stage)
		if not nextStage then
			return "You stand at the peak of this world's cultivation, for now."
		end
		return methodLimit(data, nextStage) or "Your meridians brim with qi. Sit and meditate to break through."
	end
	if os.clock() - s.lastActive < Config.WARN_IDLE_SECONDS then
		return nil
	end
	local activeRate = stage.passive / Config.PASSIVE_SHARE
	if rate > 0 and activeRate / rate < Config.WARN_RATIO then
		return nil
	end
	local runQi = stage.dantian / Pacing.Refine.RUNS_PER_DANTIAN * Pacing.Refine.MIN_RUN_FRACTION
	if data.rawQi >= runQi then
		return "Qi stirs in your dantian. Circulate to refine it."
	end
	return "You must go out and experience the world."
end

-- Seconds left of today's offline/AFK budget (Pacing.Income.OFFLINE_MAX_HOURS a UTC
-- day, shared by every absence, AFK stretch and seclusion; rebalance 2026-10-24: two
-- logins a day used to earn two nights).
function Cultivation.awayLeft(data: PlayerData.Data, now: number): number
	local today = now // 86400
	if data.awayDay ~= today then
		data.awayDay = today
		data.awayUsed = 0
	end
	return math.max(0, Pacing.Income.OFFLINE_MAX_HOURS * 3600 - data.awayUsed)
end

-- Spend `seconds` of today's budget.
function Cultivation.spendAway(data: PlayerData.Data, now: number, seconds: number)
	Cultivation.awayLeft(data, now)
	data.awayUsed += seconds
end

-- On login: cultivation gathered while away (passive rate, up to the overflow cap
-- and today's offline/AFK budget), and the first-login-of-the-day raw qi bonus. Returns
-- what was claimed, for the caller to report.
function Cultivation.claimLogin(player: Player, data: PlayerData.Data): (number, number)
	local now = os.time()
	local stage = Cultivation.stage(data)
	local offline = 0
	if data.lastLogoutUnix > 0 then
		local away = math.clamp(now - data.lastLogoutUnix, 0, Cultivation.awayLeft(data, now))
		Cultivation.spendAway(data, now, away)
		offline = math.min(Cultivation.afkRate(data) * away, Cultivation.cap(data) - data.cultivation)
		offline = math.max(0, math.floor(offline))
		data.cultivation += offline
	end
	local daily = 0
	local today = now // 86400
	if data.lastDailyDay ~= today then
		data.lastDailyDay = today
		daily = math.min(math.floor(stage.dantian * Pacing.Income.DAILY_QI_SHARE * stage.gather), stage.dantian - data.rawQi)
		daily = math.max(0, daily)
		data.rawQi += daily
		Analytics.qi(player, "source", daily, data.rawQi, "TimedReward", "DailyQi")
	end
	session(player).capNoticed = true -- said below, once the HUD is up, not by the tick
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
		if data.cultivation >= Cultivation.cap(data) and Cultivation.block(data) == "" then
			task.wait(4)
			Cultivation.notify(player, CAP_LINE)
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
			task.defer(Cultivation.applyStats, player, data)
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
				local s = session(player)
				local afk = Cultivation.afk(player)
				local rate
				if Cultivation.deviated(player) then
					rate = 0
				elseif afk then
					-- AFK earns what offline would, out of the same daily budget
					local left = Cultivation.awayLeft(data, now)
					rate = if left > 0 then Cultivation.afkRate(data) * math.min(1, left / dt) else 0
					Cultivation.spendAway(data, now, math.min(dt, left))
				else
					rate = Cultivation.rate(data, now, player)
				end
				if not afk then
					if s.wasAfk then
						s.capNoticed = false -- back from AFK: say it again if the dantian is full
					end
				end
				s.wasAfk = afk
				if Cultivation.meditation and Cultivation.meditation(player) and not secluded(player) then
					data.stats.seated += dt -- time in stillness (the heart-demon trial; seclusion counts apart)
				end
				Cultivation.add(data, rate * dt)
				publish(player, data)
				-- the dantian is full: once per stretch (and again after AFK, offline or seclusion)
				local cap = Cultivation.cap(data)
				if data.cultivation < cap then
					s.capNoticed = false
				elseif not s.capNoticed and not afk then
					s.capNoticed = true
					if Cultivation.block(data) == "" then
						Cultivation.notify(player, CAP_LINE)
					end
				end
				if os.clock() - s.lastWarned >= Config.WARN_INTERVAL or (data.cultivation >= bar and not s.fullNoticed) then
					local firstFull = data.cultivation >= bar and not s.fullNoticed
					local message = warning(player, data, rate)
					if message then
						s.lastWarned = os.clock()
						Cultivation.notify(player, message)
					end
					-- once per stage: the bar filled before the world taught enough
					if firstFull and Cultivation.block(data) == "" and not data.foundation.warned
						and Foundation.active(data) and Foundation.unsteady(Foundation.percent(data)) then
						data.foundation.warned = true
						task.delay(4, Cultivation.notify, player, `Your foundation is only {Foundation.percent(data)}%. The world still has things to teach you.`)
					end
				end
				if expired then
					Cultivation.applyStats(player, data)
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
