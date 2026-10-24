--!strict
-- Loads, caches and saves each player's profile in a DataStore.
-- Profiles are session-locked: a server claims the record on load and only that
-- server may save it, so two servers can't overwrite each other's progress when a
-- player hops. If a load fails the player still plays, but their profile is never
-- saved, so a DataStore outage can't overwrite real progress with an empty profile.
-- In an unpublished place (PlaceId 0) an in-memory store stands in for the session.
--
-- Save slots (Config.Slots, docs/systems/save-slots.md): with slots on, the
-- record is an Account under "a_<userId>": up to Slots.MAX separate characters
-- (each a full Data profile), their race and last name by slot position
-- (fates), and what all slots share (settings, Robux receipts). The first load
-- wraps the old "u_<userId>" profile into slot 1 untouched and never writes the
-- old key again, so it stays as a backup. With slots off (the live game for
-- now) the old key is read and written exactly as before, seen here as a
-- one-slot account. Either way nothing is played until `activate` picks a slot;
-- `get` returns that slot's profile.

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
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)

local Slots = require(ReplicatedStorage.Shared.Config).Slots

local SCHEMA_VERSION = 12 -- one slot's profile (Data)
local ACCOUNT_VERSION = 1 -- the slots wrapper (Account)

-- a placed build item: id, item, peak-local pivot, yaw, and placement mode (nil = floor)
export type Placed = { u: string, i: string, x: number, y: number, z: number, r: number, m: string? }
export type ActiveBuff = { source: string, kind: string, amount: number, expires: number, seconds: number? } -- seconds: the full span (nil on buffs saved before it)
export type Technique = { level: number, xp: number }
-- weapon Dao comprehension of one class (Weapons.Classes), level 0..Pacing.Weapons.MAX_LEVEL
export type Dao = { level: number, xp: number }
export type HerbRecord = { n: number, l: number, m: { string } } -- one Herbarium entry
-- Player preferences (the Settings window): volumes 0..1, and toggles
-- one finished heart-demon trial: calmed (no denials), denials, old grades tempered,
-- the heart line the player keeps (the Self card), and os.time()
export type HeartTrial = { calm: boolean, denials: number, tempered: number, note: string, at: number }
export type SeclusionTally = { stones: number, frac: number, cultivation: number, items: { [string]: number }, seeds: { [string]: number }, mutations: number, growth: number }
export type Seclusion = { since: number, counted: number, online: number, start: number, rolled: number, tally: SeclusionTally, streak: number, streakDay: number, first: boolean }

export type Settings = { music: number, sfx: number, autoAttack: boolean, lockHint: boolean }
-- hotbar always has Hotbar.SIZE entries: a technique id, an item id, or "" (empty)
export type Data = {
	v: number,
	realm: { major: string, minor: number },
	cultivation: number, -- progress in the current realm bar
	rawQi: number, -- held in the dantian, refined by circulation runs
	stones: number, -- Spirit Stones, spent at the Spirit Market
	methods: { owned: { [string]: boolean }, active: string }, -- active "" = Sect Breathing
	-- owned: learned; manuals: found but its weapon Dao isn't there yet (learned when it is)
	techniques: { owned: { [string]: Technique }, manuals: { [string]: boolean } },
	hotbar: { string },
	firstKills: { [string]: boolean },
	milestones: { [string]: boolean }, -- kill milestones claimed, by kill count
	-- foundation (server Foundation): experience keys earned (once ever), the weighted
	-- count this stage, each stage's foundation percent by stage key (profiles from
	-- before percents hold a grade word; Foundation.percentOf reads both), whether this
	-- stage's "unsteady" toast was shown, and this stage's deeds (kills per beast id,
	-- herb ids harvested, deed ids done; reset at each breakthrough)
	foundation: {
		seen: { [string]: boolean },
		count: number,
		grades: { [string]: any },
		warned: boolean,
		deeds: { kills: { [string]: number }, herbs: { [string]: boolean }, done: { [string]: boolean } },
	},
	-- the Herbarium (server Herbarium): per herb id, n harvested in all, l the largest
	-- size seen, m the mutation ids seen; tiers: herb tiers whose page is complete
	-- and rewarded, by tier numeral string ("1".."5")
	herbarium: { herbs: { [string]: HerbRecord }, tiers: { [string]: boolean } },
	beats: { [string]: boolean }, -- onboarding beats completed, by id (Quests.Beats)
	lessons: { [string]: boolean }, -- first-encounter lessons already shown (Quests.Lessons), plus markers: RootPillUsed, Loop (the elder named the loop)
	quests: { [string]: boolean }, -- rewarded objectives claimed, by quest id (beats, lessons, later real quests)
	onboardingMark: number, -- circulation runs when the current beat began
	lastLogoutUnix: number,
	lastDailyDay: number, -- os.time() // 86400 of the last daily bonus
	tribulationReadyUnix: number, -- os.time() a failed tribulation can be retried
	heavenDefying: boolean, -- the heavens refuse this cultivator: a tribulation guards every major breakthrough (set by a heaven-defying bloodline or root; docs/progression.md)
	daoPracticeReadyUnix: number, -- os.time() the next Practice Dao drill opens
	-- slain: kills by enemy id; harvests: plants harvested; deaths; seated: seconds
	-- meditating; the rest below. The heart-demon trial reads them all.
	stats: {
		breakthroughs: number,
		circulationRuns: number,
		kills: number,
		bossKills: number,
		slain: { [string]: number },
		harvests: number,
		deaths: number,
		seated: number,
		forced: number, -- forced breakthroughs, removed (the qi surge replaced it); old profiles keep theirs
		secluded: number, -- seconds in seclusion, online and offline (server Seclusion)
		surges: number, -- qi surges fired (QiSurge)
		spills: number, -- deaths that spilled a haul (Haul.died)
		reclaimed: number, -- spills walked back to and gathered
		fled: number, -- logouts mid-fight that cost a haul share (Haul.leaving)
		stored: number, -- Store all uses that banked something (Haul.storeAll)
		ringed: number, -- stacks put in the spirit ring (Haul.setRing)
		placed: number, -- build pieces placed on the peak (Build "place")
		peakBest: number, -- the highest peak score reached (Peaks.refreshScore, uncapped)
		elites: number, -- elite-tier beasts slain (realm variants, Progression.onKill)
		apexes: number, -- apex-tier beasts slain
		washed: number, -- Marrow Washing Pills absorbed (Roots.wash)
		rerolls: number, -- Root Rebirth Pills used (Roots.reroll)
		partied: number, -- seconds in a party with a member nearby (server Party)
	},
	-- seclusion (server Seclusion): since = os.time() it began (0 = not secluded);
	-- counted = seconds of it that earned (up to Pacing.Seclusion MAX_HOURS); online =
	-- seconds of it spent online; start = cultivation when it began; rolled = hourly
	-- rare rolls made; tally = what this one has earned so far (stones and the
	-- fractional stone, cultivation, finds by id, seeds by id, mutations, plants tended);
	-- streak days and the day (os.time() // 86400) last counted; first = the
	-- onboarding's first seclusion is done
	seclusion: Seclusion,
	-- heart-demon trials (server HeartDemon), by major id: the result, and when a
	-- seat offer was last declined
	heartDemon: { trials: { [string]: HeartTrial }, declined: { [string]: number } },
	herbs: { [string]: number },
	items: { [string]: number }, -- spirit cores and treasures (herbs stay in herbs)
	seeds: { [string]: number },
	ring: { string }, -- the spirit ring: herb and item ids whose whole stack is banked even in the wilds (Haul.luau)
	-- the unbanked haul left out when the last session logged off away from a bank point (Haul.luau)
	haul: { rawQi: number, stones: number, herbs: { [string]: number }, items: { [string]: number }, seeds: { [string]: number } },
	buffs: { ActiveBuff },
	decor: { [string]: number }, -- stored build items, by catalog id
	receipts: { [string]: number }, -- Robux purchases already granted: PurchaseId -> os.time()
	settings: Settings,
	weapons: { owned: { [string]: number }, equipped: string }, -- owned counts by weapon id; "" = Fist
	dao: { [string]: Dao }, -- by class id; a missing class is level 0
	caches: { [string]: boolean }, -- world ManualCache / WeaponRack anchors claimed, by Cache id
	seen: { [string]: number }, -- items, arts and weapons the Inventory has shown, by os.time() first seen (0 = before v10); held and not here = NEW
	inventoryView: { [string]: { sort: string, filter: string } }, -- the Inventory's sort and class/kind filter, per tab (Weapons, Arts, Pouch; older profiles: Arsenal, mapped to both on first use)
	root: Roots.Root, -- spirit root; element "" until tested at the Testing Stone
	-- the character screen's choices: firstName "" until named; look is
	-- CharacterIdentity.Look without FirstName (nil until named)
	character: { firstName: string?, look: { [string]: any }? },
	-- traits, and a copy of the slot fate's race and variant that Traits reads
	-- (docs/systems/identity.md); race "" until the slot is played
	identity: Registry.Identity,
	peak: {
		removed: { [string]: boolean },
		placed: { Placed },
		plots: { [string]: { Herbs.Plant } }, -- plantings, by plot id
	},
}

-- Race, variant and last name of a slot position (Shared.Identity race and variant ids,
-- Shared.CharacterCreator.Surnames keys).
export type Fate = { Race: string, Variant: string?, Surname: string } -- Variant "" for a race without variants (nil before variants)
export type Trash = { slot: string, data: any, fate: Fate?, at: number }
-- Everything stored for one player with slots on. Slot ids are "1".."MAX"
-- (string keys: DataStores can't keep nil holes in arrays).
export type Account = {
	av: number,
	slots: { [string]: Data },
	fates: { [string]: Fate }, -- by slot position; kept when the slot is deleted
	last: string, -- the slot played last ("" for none)
	settings: Settings, -- shared by every slot
	receipts: { [string]: number }, -- shared: a reroll is bought before its slot exists
	rerollFor: string, -- slot position a pending Robux reroll applies to
	trash: Trash?, -- the last deleted slot, kept Slots.TRASH_DAYS
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

local function newTally(): SeclusionTally
	return { stones = 0, frac = 0, cultivation = 0, items = {}, seeds = {}, mutations = 0, growth = 0 }
end

local function default(): Data
	return {
		v = SCHEMA_VERSION,
		realm = { major = "QiCondensation", minor = 1 },
		cultivation = 0,
		rawQi = Income.STARTING_RAW_QI,
		stones = Economy.STARTING_STONES,
		methods = { owned = {}, active = "" },
		-- no starting technique: the first one is the onboarding's 3-kill manual (Fire Seal),
		-- taught in its own beat (docs/systems/onboarding.md)
		techniques = { owned = {}, manuals = {} },
		hotbar = Hotbar.empty(),
		firstKills = {},
		milestones = {},
		foundation = { seen = {}, count = 0, grades = {}, warned = false, deeds = { kills = {}, herbs = {}, done = {} } },
		herbarium = { herbs = {}, tiers = {} },
		beats = {},
		lessons = {},
		quests = {},
		onboardingMark = 0,
		lastLogoutUnix = 0,
		lastDailyDay = 0,
		tribulationReadyUnix = 0,
		heavenDefying = false,
		daoPracticeReadyUnix = 0,
		stats = { breakthroughs = 0, circulationRuns = 0, kills = 0, bossKills = 0, slain = {}, harvests = 0, deaths = 0, seated = 0, forced = 0, secluded = 0,
			surges = 0, spills = 0, reclaimed = 0, fled = 0, stored = 0, ringed = 0, placed = 0, peakBest = 0, elites = 0, apexes = 0, washed = 0, rerolls = 0, partied = 0 },
		heartDemon = { trials = {}, declined = {} },
		seclusion = { since = 0, counted = 0, online = 0, start = 0, rolled = 0, tally = newTally(), streak = 0, streakDay = 0, first = false },
		herbs = {},
		items = {},
		seeds = table.clone(Config.STARTING_SEEDS),
		ring = {},
		haul = { rawQi = 0, stones = 0, herbs = {}, items = {}, seeds = {} },
		buffs = {},
		decor = {},
		receipts = {},
		settings = { music = 1, sfx = 1, autoAttack = true, lockHint = true },
		weapons = { owned = { [Weapons.STARTING] = 1 }, equipped = Weapons.STARTING },
		seen = { [Weapons.STARTING] = 0 }, -- the starting kit isn't NEW
		inventoryView = {
			Weapons = { sort = "New", filter = "All" },
			Arts = { sort = "New", filter = "All" },
			Pouch = { sort = "New", filter = "All" },
		},
		dao = startingDao(),
		caches = {},
		root = Roots.new(),
		character = {},
		peak = { removed = {}, placed = {}, plots = {} },
		identity = { race = "", variant = "", traits = {} },
	}
end

local function defaultSettings(): Settings
	return { music = 1, sfx = 1, autoAttack = true, lockHint = true }
end

local function newAccount(): Account
	return {
		av = ACCOUNT_VERSION,
		slots = {},
		fates = {},
		last = "",
		settings = defaultSettings(),
		receipts = {},
		rerollFor = "",
		trash = nil,
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
	-- v6 tracked insight separately from insight earned (insight is gone since v12)
	[6] = function() end,
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
	-- v9 had no NEW badges: everything already owned counts as seen
	[9] = function(d)
		local seen = {}
		for _, bag in { d.herbs or {}, d.items or {}, (d.weapons or {}).owned or {} } do
			for id, count in bag do
				if type(count) == "number" and count > 0 then
					seen[id] = 0
				end
			end
		end
		for id in (d.techniques or {}).owned or {} do
			seen[id] = 0
		end
		d.seen = seen
	end,
	-- v10 had no character screen: the slot is unnamed until its player names it
	[10] = function(d)
		d.character = {}
	end,
	-- v11 had insight (deleted in Phase A: walls are the bar, techniques gate on weapon Dao)
	[11] = function(d)
		d.insight = nil
		d.insightEarned = nil
	end,
}

-- Nested tables whose own keys get defaults too; the rest (herbs, seeds...) are
-- player-owned maps where a missing key means zero, not "use the default".
local NESTED = { "realm", "techniques", "stats", "peak", "settings", "weapons", "root", "methods", "identity", "foundation", "heartDemon", "herbarium", "seclusion" }

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


local function validSlot(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	local n = tonumber(id)
	return n ~= nil and n == math.floor(n) and n >= 1 and n <= Slots.MAX and tostring(n) == id
end

-- Account schema steps (none yet past v1). The wrap from the old single-profile
-- record is `wrapLegacy`: it runs once, when the account key is still empty.
local function reconcileAccount(saved: any): Account
	if type(saved) ~= "table" then
		return newAccount()
	end
	saved.av = ACCOUNT_VERSION
	for k, v in newAccount() :: any do
		if saved[k] == nil then
			saved[k] = v
		end
	end
	for k, v in defaultSettings() :: any do
		if saved.settings[k] == nil then
			saved.settings[k] = v
		end
	end
	-- a slot id outside 1..MAX (the cap lowered later) stays stored but unused
	for id, slot in saved.slots do
		if validSlot(id) then
			saved.slots[id] = reconcile(slot)
		end
	end
	local trash = saved.trash
	if type(trash) == "table" and os.time() - (tonumber(trash.at) or 0) > Slots.TRASH_DAYS * 86400 then
		saved.trash = nil
	end
	return saved
end

-- The old single profile becomes slot 1, untouched (its own migrations run in
-- reconcileAccount). What every slot shares is copied up; the slot keeps its
-- copies, so nothing is dropped. nil (a new player) gives an empty account.
local function wrapLegacy(profile: any): any
	local account = newAccount()
	if type(profile) == "table" then
		account.slots["1"] = profile
		account.last = "1"
		if type(profile.settings) == "table" then
			account.settings = table.clone(profile.settings)
		end
		if type(profile.receipts) == "table" then
			account.receipts = table.clone(profile.receipts)
		end
	end
	return account
end

-- Slots off: the old profile seen as a one-slot account. Settings and receipts
-- are the profile's own tables, so saving writes exactly what it did before.
local function singleSlot(data: Data): Account
	local account = newAccount()
	account.slots["1"] = data
	account.last = "1"
	account.settings = data.settings
	account.receipts = data.receipts
	return account
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
		GetAsync = function(_, k: string): any
			return copy(records[k])
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

type Profile = {
	account: Account,
	data: Data?, -- the slot being played (nil until activate)
	active: string?,
	canSave: boolean,
	releasing: boolean?,
}
local profiles: { [Player]: Profile } = {}

local PlayerData = {}
PlayerData.newTally = newTally -- a fresh seclusion tally (server Seclusion)

PlayerData.validSlot = validSlot
-- Slot ids in order, "1".."MAX".
PlayerData.SLOT_IDS = {} :: { string }
for i = 1, Slots.MAX do
	table.insert(PlayerData.SLOT_IDS, tostring(i))
end

local function legacyKey(player: Player): string
	return "u_" .. player.UserId
end

local function key(player: Player): string
	return if Slots.ENABLED then "a_" .. player.UserId else legacyKey(player)
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

-- Reads the old single-profile key without writing it (it stays as the
-- backup). A server of the old version still holding it gets the usual wait to
-- save and release first.
local function readLegacy(player: Player): (boolean, any)
	local waited = 0
	while true do
		local ok, stored = pcall(function()
			return store:GetAsync(legacyKey(player))
		end)
		if not ok then
			return false, stored
		end
		local record = toRecord(stored)
		local s = record.session
		local live = s ~= nil and s.job ~= jobId and os.time() - s.t <= Config.LOCK_STALE_SECONDS
		if not live or waited >= Config.LOCK_WAIT_SECONDS then
			return true, record.data
		end
		if player.Parent == nil then
			return false, "player left while waiting for the old profile's lock"
		end
		task.wait(Config.LOCK_RETRY_SECONDS)
		waited += Config.LOCK_RETRY_SECONDS
	end
end

-- Loads the player's account (every slot). Nothing is played yet: `activate`
-- picks the slot. If the load fails the player still plays, unsaved.
function PlayerData.load(player: Player): Account
	local account: Account? = nil
	local canSave = false
	if okStore then
		for attempt = 1, 3 do
			local ok, result = claim(player)
			if ok and Slots.ENABLED and result == nil then
				-- no account yet: wrap the old profile (if any) into slot 1. A failed
				-- read fails the load, or an empty account would hide the old profile.
				ok, result = readLegacy(player)
				if ok then
					result = wrapLegacy(result)
				end
			end
			if ok then
				account = if Slots.ENABLED then reconcileAccount(result) else singleSlot(reconcile(result))
				canSave = true
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
	local loaded: Account = account or (if Slots.ENABLED then newAccount() else singleSlot(default()))
	profiles[player] = { account = loaded, canSave = canSave }
	return loaded
end

-- The profile of the slot being played (nil before a slot is played).
function PlayerData.get(player: Player): Data?
	local p = profiles[player]
	return p and p.data
end

-- Every slot of the player (nil before load).
function PlayerData.account(player: Player): Account?
	local p = profiles[player]
	return p and p.account
end

-- Whether this session will be saved (false after a failed load).
function PlayerData.canSave(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.canSave
end

-- The slot id being played, or nil.
function PlayerData.active(player: Player): string?
	local p = profiles[player]
	return p and p.active
end

-- Plays a slot: its profile becomes `get`'s, sharing the account's settings and
-- receipts. Once per session (switching means rejoining).
function PlayerData.activate(player: Player, id: string): Data?
	local p = profiles[player]
	if not (p and p.active == nil and validSlot(id)) then
		return nil
	end
	local data = p.account.slots[id]
	if not data then
		return nil
	end
	data.settings = p.account.settings
	data.receipts = p.account.receipts
	p.data, p.active = data, id
	p.account.last = id
	return data
end

-- A fresh profile in an empty slot position (not played yet).
function PlayerData.createSlot(player: Player, id: string): Data?
	local p = profiles[player]
	if not (p and validSlot(id)) or p.account.slots[id] then
		return nil
	end
	local data = default()
	p.account.slots[id] = data
	return data
end

-- Moves a slot to the account's trash (the previous trash is dropped). Never
-- the slot being played. The position's fate stays.
function PlayerData.deleteSlot(player: Player, id: string): boolean
	local p = profiles[player]
	if not (p and p.canSave and validSlot(id)) or p.active == id then
		return false
	end
	local data = p.account.slots[id]
	if not data then
		return false
	end
	p.account.trash = { slot = id, data = data, fate = p.account.fates[id], at = os.time() }
	p.account.slots[id] = nil
	if p.account.last == id then
		p.account.last = ""
	end
	return true
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
			-- slots off: the bare profile, as it always was
			local payload = if Slots.ENABLED then p.account else p.account.slots["1"]
			return { data = payload, session = session }, { player.UserId }
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
		if p.data then
			p.data.lastLogoutUnix = os.time()
		end
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

PlayerData.default = default

return PlayerData
