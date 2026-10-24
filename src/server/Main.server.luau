--!strict
-- Server entry: peak assignment, profile load/save, and remote wiring.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Items = require(ReplicatedStorage.Shared.Items)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Cultivation = require(script.Parent.Cultivation)
local Garden = require(script.Parent.Garden)
local Receipts = require(script.Parent.Receipts)
local Build = require(script.Parent.Build)
local Circulation = require(script.Parent.Circulation)
local Combat = require(script.Parent.Combat)
local Travel = require(script.Parent.Travel)
local QiNodes = require(script.Parent.QiNodes)
local EnemyService = require(script.Parent.EnemyService)
local Spawner = require(script.Parent.Spawner)
local Shelter = require(script.Parent.Shelter)
local Progression = require(script.Parent.Progression)
local Tribulation = require(script.Parent.Tribulation)
local QiSurge = require(script.Parent.QiSurge)
local Quests = require(script.Parent.Quests)
local Sect = require(script.Parent.Sect)
local Analytics = require(script.Parent.Analytics)
local WeatherService = require(script.Parent.WeatherService)
local Meditation = require(script.Parent.Meditation)
local Seclusion = require(script.Parent.Seclusion)
local Inventory = require(script.Parent.Inventory)
local Haul = require(script.Parent.Haul)
local Admin = require(script.Parent.Admin)
local WorldEvents = require(script.Parent.WorldEvents)
local Treasures = require(script.Parent.Treasures)
local Settings = require(script.Parent.Settings)
local Weapons = require(script.Parent.Weapons)
local WorldCaches = require(script.Parent.WorldCaches)
local Roots = require(script.Parent.Roots)
local Methods = require(script.Parent.Methods)
local CharacterIdentity = require(script.Parent.CharacterIdentity)
local Slots = require(script.Parent.Slots)
local TestbedDummy = require(script.Parent.TestbedDummy)
local Traits = require(script.Parent.Traits)
local Party = require(script.Parent.Party)
local SafeZone = require(script.Parent.SafeZone)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)

local joinedAt: { [Player]: number } = {}
local joinedUnix: { [Player]: number } = {} -- os.time() at PlayerAdded (a fresh slot's firstJoinUnix)
local lastBreakthroughAt: { [Player]: number } = {}

local remotes = ReplicatedStorage.Remotes

-- Peak spawn pads are disabled so nobody spawns on someone else's peak;
-- move each character onto their own peak's teleport array instead (after a
-- death, onto the main peak's array).
local function sendHome(player: Player, character: Model)
	if Config.TESTBED then
		return -- no peaks or arrays; everyone (re)spawns on the arena's pad
	end
	if Config.Spawn.RESPAWN_AT_HUB and player:GetAttribute("Died") then
		player:SetAttribute("Died", nil)
		local hub = Travel.arrival(player, "MainPeak")
		if hub then
			character:PivotTo(hub)
		end
		return
	end
	local peak = Peaks.ownedBy(player)
	local home = peak and Peaks.homeCFrame(peak)
	if home then
		character:PivotTo(home)
	end
end

-- Studio playtests and the testbed: top every herb, seed, item and Spirit Stones up to the test-kit
-- amount, and fill the dantian (never above that, so repeated sessions don't inflate a saved
-- profile). The testbed's ready "Tester" (Slots.seedTestbed) also skips onboarding and owns
-- every technique and weapon; a character made in the creator there gets no kit at all, so
-- the first session plays as a new player's would (docs/systems/onboarding.md).
local function applyTestKit(data: PlayerData.Data)
	local kit = Config.TestKit
	if not (kit.ENABLED and (RunService:IsStudio() or Config.TESTBED)) then
		return
	end
	if Config.TESTBED and not data.lessons.Tester then
		return
	end
	if Config.TESTBED then
		for _, beat in Quests.Beats do
			if beat.id ~= "FreePlay" then
				data.beats[beat.id] = true
			end
		end
	end
	for _, id in Herbs.Order do
		data.herbs[id] = math.max(data.herbs[id] or 0, kit.HERBS_EACH)
		data.seeds[id] = math.max(data.seeds[id] or 0, kit.SEEDS_EACH)
	end
	for _, id in Items.Order do
		local bag = Items.bag(data, id)
		if not Herbs.Defs[id] and not kit.SKIP_ITEMS[id] then
			bag[id] = math.max(bag[id] or 0, kit.ITEMS_EACH)
		end
		if bag[id] then
			Hotbar.place(data.hotbar, id)
		end
	end
	data.stones = math.max(data.stones, kit.STONES)
	if kit.ALL_TECHNIQUES or Config.TESTBED then
		for _, id in Techniques.Order do
			data.techniques.owned[id] = data.techniques.owned[id] or { level = 1, xp = 0 }
		end
		for _, id in { "PalmStrike", "LightningTalisman" } do
			if Hotbar.techniqueCount(data.hotbar) < Hotbar.MAX_TECHNIQUES then
				Hotbar.place(data.hotbar, id)
			end
		end
	end
	if kit.ALL_WEAPONS or Config.TESTBED then
		for _, id in WeaponDefs.Order do
			data.weapons.owned[id] = math.max(data.weapons.owned[id] or 0, 1)
		end
	end
	if kit.FILL_DANTIAN then
		data.rawQi = math.max(data.rawQi, Realms.get(data.realm.major, data.realm.minor).dantian)
	end
end

local function onPlayerAdded(player: Player)
	Admin.mark(player)
	local peak = Peaks.assign(player)
	player.CharacterAdded:Connect(function(character)
		task.defer(sendHome, player, character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			player:SetAttribute("Died", true)
			local profile = PlayerData.get(player)
			if profile then
				profile.stats.deaths += 1 -- the heart-demon trial asks about fear
			end
			Analytics.event(player, "Death", 1, Combat.lastHurtBy(player))
			task.spawn(Haul.died, player, character) -- spill half the unbanked haul where they fell (an error can't stop the death screen)
			Combat.died(player, character, Players.RespawnTime, Config.Spawn.RESPAWN_AT_HUB and not Config.TESTBED)
		end)
	end)
	if player.Character then
		task.defer(sendHome, player, player.Character)
	end
	Cultivation.watch(player)

	PlayerData.load(player)
	joinedUnix[player] = os.time()
	-- a new player (no slot with any progress) walks the front-door funnel steps
	local account = PlayerData.account(player)
	local fresh = account ~= nil
	for _, slot in (if account then account.slots else {}) :: { [string]: PlayerData.Data } do
		if next(slot.beats) ~= nil or slot.stats.circulationRuns > 0 then
			fresh = false
		end
	end
	if fresh then
		Analytics.markNew(player)
		Analytics.front(player, "Joined")
	end
	-- the slot screen: the join waits until a slot is played (slots off: slot 1 at once)
	local data = Slots.awaitPlay(player)
	if not data or player.Parent == nil then
		PlayerData.release(player)
		Peaks.release(player)
		return
	end
	applyTestKit(data)
	local offline = Cultivation.claimLogin(player, data)
	Seclusion.resume(player, data) -- a seclusion left running at logout settles and ends (its card)
	joinedAt[player] = os.clock()
	lastBreakthroughAt[player] = os.clock()
	if next(data.beats) == nil and data.stats.circulationRuns == 0 then
		if data.firstJoinUnix == 0 then
			data.firstJoinUnix = joinedUnix[player] or os.time()
		end
		Analytics.progression(player, "start", 1, Realms.Stages[1].name)
	end
	if offline > 0 then
		Analytics.event(player, "OfflineQiClaimed", offline)
	end
	if player.Parent == nil then
		PlayerData.release(player)
		Peaks.release(player)
		return
	end
	if peak then
		Peaks.applyLayout(player, data)
		Peaks.applyRealm(player, data)
		Garden.apply(player, data)
	else
		warn(`No free peak for {player.Name}; all peaks are taken`)
	end
	Weapons.watch(player)
	Roots.publish(player, data)
	if Config.TESTBED then
		CharacterIdentity.load(player, data) -- race, variant, last name and traits (Traits.luau); test place only for now
		Traits.watch(player) -- body size (the size modifier) on every spawn
	end
	Cultivation.pushState(player)
	Methods.giveStarter(player) -- already at Foundation from before methods existed
	if Config.Slots.ENABLED then
		-- the played slot's identity and look; spawns the character (test place)
		CharacterIdentity.enter(player, PlayerData.active(player) :: string, data)
	end
	task.spawn(Party.entered, player) -- "<friend> is on this mountain" nudges (IsFriendsWith yields)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	if joinedAt[player] then
		Analytics.event(player, "SessionLength", math.floor(os.clock() - joinedAt[player]))
	end
	joinedAt[player] = nil
	joinedUnix[player] = nil
	lastBreakthroughAt[player] = nil
	Haul.leaving(player) -- combat-tagged: the haul's share is lost, before the save
	PlayerData.release(player)
	Peaks.release(player)
	Build.forget(player)
	Circulation.forget(player)
	Combat.forget(player)
	Travel.forget(player)
	Party.forget(player)
	QiNodes.forget(player)
	EnemyService.forget(player)
	Spawner.forget(player)
	Tribulation.forget(player)
	QiSurge.forget(player)
	Quests.forget(player)
	Sect.forget(player)
	Meditation.forget(player)
	Inventory.forget(player)
	CharacterIdentity.forget(player)
	Traits.forget(player)
	Cultivation.forget(player)
end)

local function guarded(fn: (Player, ...any) -> (boolean, any))
	return function(player: Player, ...): (boolean, any)
		local ok, success, message = pcall(fn, player, ...)
		if not ok then
			warn(`Remote error for {player.Name}: {success}`)
			return false, "Something went wrong"
		end
		return success, message
	end
end

(remotes.BuildAction :: RemoteFunction).OnServerInvoke = guarded(Build.handle);
-- "sect" goes to the sect board, Pavilion and quest log (Sect.handle); the rest is cultivation
(remotes.CultivationAction :: RemoteFunction).OnServerInvoke = guarded(function(player: Player, action: any, ...: any): (boolean, any)
	if action == "sect" then
		return Sect.handle(player, ...)
	end
	return Circulation.handle(player, action, ...)
end);
(remotes.Attack :: RemoteEvent).OnServerEvent:Connect(Combat.action);
(remotes.Meditate :: RemoteEvent).OnServerEvent:Connect(Meditation.handle);
(remotes.Sprint :: RemoteEvent).OnServerEvent:Connect(Cultivation.setRunning);
(remotes.TravelAction :: RemoteFunction).OnServerInvoke = guarded(Travel.go);
(remotes.SaveSettings :: RemoteEvent).OnServerEvent:Connect(Settings.save);
(remotes.WeaponAction :: RemoteFunction).OnServerInvoke = guarded(Weapons.handle);
(remotes.PartyAction :: RemoteFunction).OnServerInvoke = guarded(Party.handle);

QiNodes.start()
SafeZone.start()
Party.start()
Shelter.start() -- the party shelter's ShelteredBy attribute (Shelter.luau)
EnemyService.partyOf = Party.members -- nearby members share kills and the group bonus
table.insert(EnemyService.onKill, Progression.onKill)
table.insert(EnemyService.onKill, Inventory.onKill)
table.insert(EnemyService.onKill, Sect.onKill) -- hunt dailies and the chain's kill paths
table.insert(Quests.onBeat, Analytics.beat)
-- time-to-milestone events (seconds since the slot's first join)
table.insert(EnemyService.onKill, function(player)
	local data = PlayerData.get(player)
	if data and data.stats.kills == 1 then
		Analytics.timeTo(player, "TimeToFirstKill", data.firstJoinUnix)
	end
end)
table.insert(Cultivation.onBreakthrough, function(player, stage)
	local data = PlayerData.get(player)
	if data and stage.major == "QiCondensation" and (stage.minor == 2 or stage.minor == 4) then
		Analytics.timeTo(player, `TimeToQC{stage.minor}`, data.firstJoinUnix)
	end
end)
-- Store all: what it banked (the haul's own economy is the sources it came from)
table.insert(Haul.onBanked, function(player, amounts, how)
	if how == "store" then
		Analytics.event(player, "StoreAll", amounts.stones)
	end
end)
table.insert(Quests.onClaimed, function(player, id)
	Analytics.event(player, "QuestClaimed", 1, id)
end)
table.insert(Circulation.onFinished, function(player, score)
	Analytics.event(player, "CirculationScore", math.floor(score * 100 + 0.5))
end)
table.insert(Cultivation.onBreakthrough, Weapons.onBreakthrough)
table.insert(Cultivation.onBreakthrough, Methods.giveStarter)
table.insert(Methods.onGained, function(player, id)
	Analytics.event(player, "MethodGained", 1, id)
end)
table.insert(Cultivation.onBreakthrough, function(player, stage)
	local since = os.clock() - (lastBreakthroughAt[player] or os.clock())
	lastBreakthroughAt[player] = os.clock()
	Analytics.event(player, "Breakthrough", math.floor(since), stage.name)
end)
table.insert(Tribulation.onFinished, function(player, survived)
	Analytics.event(player, "TribulationResult", if survived then 1 else 0)
	local data = PlayerData.get(player)
	if not survived and data then
		local stage = Realms.get(data.realm.major, data.realm.minor)
		Analytics.progression(player, "fail", Realms.index(stage.major, stage.minor), stage.name)
	end
end)
-- the realm progression funnel: leaving one stage completes it and starts the next
table.insert(Cultivation.onBreakthrough, function(player, stage)
	local index = Realms.index(stage.major, stage.minor)
	local previous = Realms.Stages[index - 1]
	if previous then
		Analytics.progression(player, "complete", index - 1, previous.name)
	end
	Analytics.progression(player, "start", index, stage.name)
end)
table.insert(Cultivation.onBreakthrough, function(player)
	local data = PlayerData.get(player)
	if data then
		Peaks.applyRealm(player, data)
	end
end)
EnemyService.start()
Spawner.start()
Quests.start()
Sect.start() -- the board's dailies, the chain, rank and the Pavilion (docs/systems/sect.md)
Roots.start()
table.insert(Roots.onTested, function(player, element)
	Analytics.event(player, "RootTested", 1, element)
end)
Inventory.start()
Haul.start()
Treasures.start()
WorldCaches.start()
WeatherService.start()
Garden.start()
Receipts.start()
if Config.TESTBED then
	CharacterIdentity.start() -- race and last name rolls, paid rerolls; test place only for now
	TestbedDummy.start() -- a stand-in player to see namecards on
	-- traits with an Unlock requirement are checked whenever one could have been met
	table.insert(EnemyService.onKill, Traits.check)
	table.insert(Cultivation.onBreakthrough, Traits.check)
	table.insert(Quests.onClaimed, Traits.check)
end
WorldEvents.init()
table.insert(EnemyService.onKill, Garden.onKill);

(remotes.GardenAction :: RemoteFunction).OnServerInvoke = guarded(Garden.handle);
(remotes.AdminAction :: RemoteFunction).OnServerInvoke = guarded(Admin.handle);
(remotes.CharacterAction :: RemoteFunction).OnServerInvoke = guarded(CharacterIdentity.handle);

(remotes.InventoryAction :: RemoteFunction).OnServerInvoke = guarded(Inventory.handle)
