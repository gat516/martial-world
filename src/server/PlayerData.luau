--!strict
-- Loads, caches and saves each player's profile in a DataStore.
-- If a load fails the player still plays, but their profile is never saved,
-- so a DataStore outage can't overwrite real progress with an empty profile.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Data

export type Placed = { u: string, i: string, x: number, y: number, z: number, r: number }
export type Plot = { herb: string, planted: number }
export type ActiveBuff = { source: string, kind: string, amount: number, expires: number }
export type Data = {
	v: number,
	qi: number,
	herbs: { [string]: number },
	seeds: { [string]: number },
	buffs: { ActiveBuff },
	decor: { [string]: number }, -- stored build items, by catalog id
	peak: {
		removed: { [string]: boolean },
		placed: { Placed },
		plots: { [string]: Plot },
	},
}

local function default(): Data
	return {
		v = 1,
		qi = 0,
		herbs = {},
		seeds = table.clone(Config.STARTING_SEEDS),
		buffs = {},
		decor = {},
		peak = { removed = {}, placed = {}, plots = {} },
	}
end

local function reconcile(saved: any): Data
	local fresh = default()
	if type(saved) ~= "table" then
		return fresh
	end
	for k, v in (fresh :: any) do
		if saved[k] == nil then
			saved[k] = v
		end
	end
	for k, v in (fresh.peak :: any) do
		if saved.peak[k] == nil then
			saved.peak[k] = v
		end
	end
	return saved
end

local okStore, store = pcall(function()
	return DataStoreService:GetDataStore(Config.STORE_NAME)
end)

local profiles: { [Player]: { data: Data, canSave: boolean } } = {}

local PlayerData = {}

local function key(player: Player): string
	return "u_" .. player.UserId
end

function PlayerData.load(player: Player): Data
	local data, canSave = default(), false
	if okStore then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
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

function PlayerData.save(player: Player)
	local p = profiles[player]
	if not (p and p.canSave) then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(key(player), p.data, { player.UserId })
	end)
	if not ok then
		warn(`PlayerData: save failed for {player.Name}: {err}`)
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
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
			PlayerData.save(player)
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
