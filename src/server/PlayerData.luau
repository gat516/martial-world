--!strict
-- Loads, caches and saves each player's profile in a DataStore.
-- Profiles are session-locked: a server claims the record on load and only that
-- server may save it, so two servers can't overwrite each other's progress when a
-- player hops. If a load fails the player still plays, but their profile is never
-- saved, so a DataStore outage can't overwrite real progress with an empty profile.
-- In an unpublished place (PlaceId 0) an in-memory store stands in for the session.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Data
local Economy = require(ReplicatedStorage.Shared.Config).Economy
local Income = require(ReplicatedStorage.Shared.Pacing).Income
local Realms = require(ReplicatedStorage.Shared.Realms)
local Hotbar = require(ReplicatedStorage.Shared.Hotbar)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local WeaponPacing = require(ReplicatedStorage.Shared.Pacing).Weapons
local Roots = require(ReplicatedStorage.Shared.Roots)

local SCHEMA_VERSION = 9

-- a placed build item: id, item, peak-local pivot, yaw, and placement mode (nil = floor)
export type Placed = { u: string, i: string, x: number, y: number, z: number, r: number, m: string? }
export type ActiveBuff = { source: string, kind: string, amount: number, expires: number }
export type Technique = { level: number, xp: number }
-- weapon Dao comprehension of one class (Weapons.Classes), level 0..Pacing.Weapons.MAX_LEVEL
export type Dao = { level: number, xp: number }
-- Player preferences (the Settings window): volumes 0..1, and toggles
export type Settings = { music: number, sfx: number, autoAttack: boolean, lockHint: boolean }
-- hotbar always has Hotbar.SIZE entries: a technique id, an item id, or "" (empty)
export type Data = {
	v: number,
	realm: { major: string, minor: number },
	cultivation: number, -- progress in the current realm bar
	rawQi: number, -- held in the dantian, refined by circulation runs
	stones: number, -- Spirit Stones, spent at the Spirit Market
	insight: number, -- unspent insight (spent comprehending techniques)
	insightEarned: number, -- every insight ever gained; breakthroughs check this
	methods: { owned: { [string]: boolean }, active: string }, -- active "" = Sect Breathing
	techniques: { owned: { [string]: Technique } },
	hotbar: { string },
	firstKills: { [string]: boolean },
	milestones: { [string]: boolean }, -- kill milestones claimed, by kill count
	beats: { [string]: boolean }, -- onboarding beats completed, by id (Quests.Beats)
	lessons: { [string]: boolean }, -- first-encounter lessons already shown (Quests.Lessons)
	quests: { [string]: boolean }, -- rewarded objectives claimed, by quest id (beats, lessons, later real quests)
	onboardingMark: number, -- circulation runs when the current beat began
	lastLogoutUnix: number,
	lastDailyDay: number, -- os.time() // 86400 of the last daily bonus
	tribulationReadyUnix: number, -- os.time() a failed tribulation can be retried
	daoPracticeReadyUnix: number, -- os.time() the next Practice Dao drill opens
	stats: { breakthroughs: number, circulationRuns: number, kills: number, bossKills: number },
	herbs: { [string]: number },
	items: { [string]: number }, -- spirit cores and treasures (herbs stay in herbs)
	seeds: { [string]: number },
	buffs: { ActiveBuff },
	decor: { [string]: number }, -- stored build items, by catalog id
	receipts: { [string]: number }, -- Robux purchases already granted: PurchaseId -> os.time()
	settings: Settings,
	weapons: { owned: { [string]: number }, equipped: string }, -- owned counts by weapon id; "" = Fist
	dao: { [string]: Dao }, -- by class id; a missing class is level 0
	caches: { [string]: boolean }, -- world ManualCache / WeaponRack anchors claimed, by Cache id
	root: Roots.Root, -- spirit root; element "" until tested at the Testing Stone
	peak: {
		removed: { [string]: boolean },
		placed: { Placed },
		plots: { [string]: { Herbs.Plant } }, -- plantings, by plot id
	},
}

-- What's actually stored under a player's key: the profile plus who holds it.
type Session = { job: string, t: number }
type Record = { data: any, session: Session? }

local function startingDao(): { [string]: Dao }
	local dao = {}
	for class, level in WeaponPacing.STARTING do
		dao[class] = { level = level, xp = 0 }
	end
	return dao
end

local function default(): Data
	return {
		v = SCHEMA_VERSION,
		realm = { major = "QiCondensation", minor = 1 },
		cultivation = 0,
		rawQi = Income.STARTING_RAW_QI,
		stones = Economy.STARTING_STONES,
		insight = 0,
		insightEarned = 0,
		methods = { owned = {}, active = "" },
		techniques = { owned = { LightningTalisman = { level = 1, xp = 0 } } }, -- any weapon
		hotbar = Hotbar.empty({ "LightningTalisman" }),
		firstKills = {},
		milestones = {},
		beats = {},
		lessons = {},
		quests = {},
		onboardingMark = 0,
		lastLogoutUnix = 0,
		lastDailyDay = 0,
		tribulationReadyUnix = 0,
		daoPracticeReadyUnix = 0,
		stats = { breakthroughs = 0, circulationRuns = 0, kills = 0, bossKills = 0 },
		herbs = {},
		items = {},
		seeds = table.clone(Config.STARTING_SEEDS),
		buffs = {},
		decor = {},
		receipts = {},
		settings = { music = 1, sfx = 1, autoAttack = true, lockHint = true },
		weapons = { owned = { [Weapons.STARTING] = 1 }, equipped = Weapons.STARTING },
		dao = startingDao(),
		caches = {},
		root = Roots.new(),
		peak = { removed = {}, placed = {}, plots = {} },
	}
end

-- Step a saved profile up one schema version at a time.
local migrations: { [number]: (any) -> () } = {
	-- v1 had one passively-accrued qi pool; it becomes raw qi, capped to a QC1 dantian
	[1] = function(d)
		d.rawQi = math.min(math.floor(d.qi or 0), Realms.Stages[1].dantian)
		d.qi = nil
	end,
	-- v2 had three technique slots; they open the free-form hotbar, with the
	-- herbs already in the pouch placed after them
	[2] = function(d)
		local start = {}
		for i = 1, 3 do
			local id = d.techniques and d.techniques.slots and d.techniques.slots[i]
			start[i] = if type(id) == "string" then id else ""
		end
		d.hotbar = Hotbar.empty(start)
		for _, id in Herbs.Order do
			if (d.herbs and d.herbs[id] or 0) > 0 then
				Hotbar.place(d.hotbar, id)
			end
		end
		if d.techniques then
			d.techniques.slots = nil
		end
	end,
	-- v3 beds held one herb in three fixed spots; they become three plantings
	[3] = function(d)
		local plots = d.peak and d.peak.plots
		if not plots then
			return
		end
		for plotId, old in plots do
			if type(old.herb) == "string" then
				local plants = {}
				for i, z in { -4, 0, 4 } do
					table.insert(plants, { u = `m{i}`, h = old.herb, x = 0, z = z, p = old.planted, b = 0, n = 0, s = 1 })
				end
				plots[plotId] = plants
			end
		end
	end,
	-- v4 had no weapons: everyone gets the starting jian, equipped, and their
	-- Fist and Sword Dao at the neutral level (so their power is unchanged)
	[4] = function(d)
		d.weapons = { owned = { [Weapons.STARTING] = 1 }, equipped = Weapons.STARTING }
		d.dao = startingDao()
		d.caches = {}
	end,
	-- v5 had no Root beat (now the 3rd): players already past Breakthrough skip
	-- it (the quest board asks them to have their root tested instead)
	[5] = function(d)
		if (d.onboardingStep or 0) >= 2 then
			d.onboardingStep += 1
		end
		d.root = Roots.new()
	end,
	-- v6 never spent insight, so everything held so far was earned
	[6] = function(d)
		d.insightEarned = d.insight or 0
	end,
	-- v7 counted onboarding beats by position; v8 keeps them by id, so beats
	-- can be reordered or inserted. This is the v7 beat order.
	[7] = function(d)
		local order = { "Circulate", "Breakthrough", "Root", "Gate", "FirstKill", "Technique", "Refine", "QC3" }
		d.beats = {}
		for i = 1, math.min(d.onboardingStep or 0, #order) do
			d.beats[order[i]] = true
		end
		d.onboardingStep = nil
	end,
	-- v8 had no objective rewards: beats already passed count as claimed (the
	-- tutorial isn't paid in arrears); lessons already done pay out once
	[8] = function(d)
		d.quests = {}
		for id, passed in d.beats or {} do
			if passed then
				d.quests[id] = true
			end
		end
	end,
}

-- Nested tables whose own keys get defaults too; the rest (herbs, seeds...) are
-- player-owned maps where a missing key means zero, not "use the default".
local NESTED = { "realm", "techniques", "stats", "peak", "settings", "weapons", "root", "methods" }

local function fillMissing(target: any, fresh: any)
	for k, v in fresh do
		if target[k] == nil then
			target[k] = v
		end
	end
	for _, k in NESTED do
		for nk, nv in fresh[k] do
			if target[k][nk] == nil then
				target[k][nk] = nv
			end
		end
	end
end

local function reconcile(saved: any): Data
	if type(saved) ~= "table" then
		return default()
	end
	local v = saved.v or 1
	while v < SCHEMA_VERSION do
		local step = migrations[v]
		if step then
			step(saved)
		end
		v += 1
	end
	saved.v = SCHEMA_VERSION
	fillMissing(saved, default())
	-- the hotbar is a fixed-length array; "" marks an empty slot (DataStores drop nil holes)
	for i = 1, Hotbar.SIZE do
		saved.hotbar[i] = saved.hotbar[i] or ""
	end
	return saved
end

-- v1 stored the profile bare; v2 wraps it with the session lock.
local function toRecord(stored: any): Record
	if type(stored) ~= "table" then
		return { data = nil, session = nil }
	end
	if stored.data == nil and stored.v ~= nil then
		return { data = stored, session = nil }
	end
	return stored
end

-- An unpublished place (the local test build) can't reach DataStores at all, so
-- it gets an in-memory stand-in: profiles save and load for the session only.
local function memoryStore(): any
	local records: { [string]: any } = {}
	local function copy(v: any): any
		if type(v) ~= "table" then
			return v
		end
		local t = {}
		for k, x in v do
			t[k] = copy(x)
		end
		return t
	end
	return {
		UpdateAsync = function(_, k: string, transform: (any) -> any): any
			local new = transform(copy(records[k]))
			if new == nil then
				return copy(records[k])
			end
			records[k] = copy(new)
			return copy(new)
		end,
	}
end

local okStore, store
if game.PlaceId == 0 then
	okStore, store = true, memoryStore()
	warn("PlayerData: unpublished place, so profiles save in memory for this session only")
else
	okStore, store = pcall(function()
		return DataStoreService:GetDataStore(Config.STORE_NAME)
	end)
end

local jobId = if game.JobId ~= "" then game.JobId else "studio"

local profiles: { [Player]: { data: Data, canSave: boolean, releasing: boolean? } } = {}

local PlayerData = {}

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- Claim the record for this server. Waits for another server's lock to clear,
-- and takes it over once it has gone stale (that server likely crashed).
local function claim(player: Player): (boolean, any)
	local waited = 0
	while true do
		local blocked = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key(player), function(stored): any
				local record = toRecord(stored)
				local s = record.session
				local stale = s == nil or os.time() - s.t > Config.LOCK_STALE_SECONDS
				if s and s.job ~= jobId and not stale and waited < Config.LOCK_WAIT_SECONDS then
					blocked = true
					return nil
				end
				record.session = { job = jobId, t = os.time() }
				return record, { player.UserId }
			end)
		end)
		if not ok then
			return false, result
		end
		if not blocked then
			return true, toRecord(result).data
		end
		if player.Parent == nil then
			return false, "player left while waiting for the session lock"
		end
		task.wait(Config.LOCK_RETRY_SECONDS)
		waited += Config.LOCK_RETRY_SECONDS
	end
end

function PlayerData.load(player: Player): Data
	local data, canSave = default(), false
	if okStore then
		for attempt = 1, 3 do
			local ok, result = claim(player)
			if ok then
				data, canSave = reconcile(result), true
				break
			end
			warn(`PlayerData: load {attempt}/3 failed for {player.Name}: {result}`)
			if string.find(tostring(result), "Studio access to APIs", 1, true) then
				warn("PlayerData: Studio API access is off, so this is an unsaved test session")
				break -- retrying can't help
			end
			task.wait(attempt)
		end
	else
		warn("PlayerData: DataStores unavailable (enable Studio API access to save); progress won't persist")
	end
	profiles[player] = { data = data, canSave = canSave }
	return data
end

function PlayerData.get(player: Player): Data?
	local p = profiles[player]
	return p and p.data
end

-- Write the profile if this server still holds the lock; `release` drops the lock.
function PlayerData.save(player: Player, release: boolean?)
	local p = profiles[player]
	if not (p and p.canSave) then
		return
	end
	local lost = false
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(stored): any
			if p.releasing and not release then
				return nil -- an autosave landing after the release would re-lock it
			end
			local s = toRecord(stored).session
			if s and s.job ~= jobId then
				lost = true
				return nil
			end
			local session = if release then nil else { job = jobId, t = os.time() }
			return { data = p.data, session = session }, { player.UserId }
		end)
	end)
	if not ok then
		warn(`PlayerData: save failed for {player.Name}: {err}`)
	elseif lost then
		-- another server took the profile over; never save from here again
		p.canSave = false
		warn(`PlayerData: {player.Name}'s profile is now held by another server`)
		if player.Parent then
			player:Kick("Your profile was opened on another server. Please rejoin.")
		end
	end
end

function PlayerData.release(player: Player)
	local p = profiles[player]
	if p then
		p.releasing = true
		p.data.lastLogoutUnix = os.time()
	end
	PlayerData.save(player, true)
	profiles[player] = nil
end

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_SECONDS)
		for player in profiles do
			task.spawn(PlayerData.save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			PlayerData.release(player)
			pending -= 1
		end)
	end
	while pending > 0 do
		task.wait()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	-- Main handles the peak first; this is a fallback so nothing is left cached
	task.defer(function()
		if profiles[player] then
			PlayerData.release(player)
		end
	end)
end)

return PlayerData
