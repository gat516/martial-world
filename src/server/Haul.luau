--!strict
-- The haul and the spirit ring: the cost of death (docs/systems/haul.md,
-- tuning in Pacing.Haul).
--   - The haul is everything gained since the player last banked: raw qi in the
--     dantian, herbs, seeds, spirit cores and other common items, Spirit Stones.
--     It's tracked as a snapshot of what they held when they last banked; the
--     haul is whatever they hold above it. Using or spending anything lowers the
--     snapshot with it (spending eats the banked part first), so every way of
--     gaining something counts without each one reporting in.
--   - Never at risk: refined cultivation, stages, weapons, techniques and manuals
--     (none of them are in the snapshot), finds at or above SAFE_RARITY (banked the
--     moment they're held), and whatever stacks sit in the spirit ring.
--   - Banking is a beat, like "sell all" but "store all": at a bank point (the
--     safe zone, SafeZone.at: the sect's grounds, any spirit peak; or any teleport
--     array), out of combat and with something unbanked, the player attribute
--     `HaulReady` is set and the client offers a one-tap "Store all" prompt
--     (InventoryAction "storeAll" -> Haul.storeAll) that banks the lot with one
--     summary line. Only riding an array (Travel.onTravel) and logging out at a
--     bank point bank silently. In the testbed (no map, and the whole arena reads
--     as the sect) only near the spawn pad, where the TestPeak sits.
--   - Haul.onBanked hooks (player, amounts, how: "store" | "travel") let
--     onboarding teach the beat after the first hunt.
--   - Death: SPILL_SHARE of each unbanked amount leaves the player and waits as a
--     spill at the last place they stood, for SPILL_SECONDS. Only they see it (the
--     Effect "spill" goes to them alone) and walking into it gives it back, as
--     haul again. A new death replaces an unclaimed spill.
--   - Leaving while combat-tagged (the InCombat attribute) loses the same share,
--     with nothing to reclaim.
-- The snapshot and the spill live in memory. Logging out away from a bank point
-- saves the unbanked haul in `data.haul`, so a rejoin (at home) offers Store all
-- for it; logging out at a bank point banks it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Tuning = require(ReplicatedStorage.Shared.Pacing).Haul
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local SafeZone = require(script.Parent.SafeZone)
local Travel = require(script.Parent.Travel)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

-- Amounts by kind: raw qi, stones, and counts by id for herbs, items and seeds.
export type Amounts = {
	rawQi: number,
	stones: number,
	herbs: { [string]: number },
	items: { [string]: number },
	seeds: { [string]: number },
}
type Spill = { at: Vector3, expires: number, contents: Amounts }
type State = {
	data: PlayerData.Data?, -- the profile the snapshot belongs to (a slot switch rebanks)
	banked: Amounts,
	ready: boolean, -- the HaulReady attribute as last published
	lastGround: Vector3?, -- the last place they stood: where a fall spills
	spill: Spill?,
}

local states: { [Player]: State } = {}

local Haul = {}

-- Called with (player, amounts banked, how) on every bank that moved something:
-- "store" (the Store all prompt) or "travel" (riding an array). Onboarding watches it.
Haul.onBanked = {} :: { (Player, Amounts, string) -> () }

local BAGS = { "herbs", "items", "seeds" }

local function empty(): Amounts
	return { rawQi = 0, stones = 0, herbs = {}, items = {}, seeds = {} }
end

local function snapshot(data: PlayerData.Data): Amounts
	return {
		rawQi = data.rawQi,
		stones = data.stones,
		herbs = table.clone(data.herbs),
		items = table.clone(data.items),
		seeds = table.clone(data.seeds),
	}
end

local function isEmpty(a: Amounts): boolean
	if a.rawQi > 0 or a.stones > 0 then
		return false
	end
	for _, bag in BAGS do
		if next((a :: any)[bag]) ~= nil then
			return false
		end
	end
	return true
end

-- Whether this item id is never at risk: a rare find (SAFE_RARITY and up).
-- Seeds go by their herb's rarity.
function Haul.safeFind(id: string): boolean
	local item = Items.Defs[id]
	local rarity = item and Items.Rarities[item.rarity]
	return rarity ~= nil and rarity.order >= Tuning.SAFE_RARITY
end

--[[ The spirit ring ]]

-- How many stacks the ring holds at this player's realm.
function Haul.ringSlots(data: PlayerData.Data): number
	return Tuning.RING_SLOTS[data.realm.major] or 0
end

-- Put a stack (every one of this herb or item) in the ring, or take it out.
-- InventoryAction ("ring", id, true/false).
function Haul.setRing(player: Player, id: any, inRing: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	if type(id) ~= "string" or not Items.Defs[id] then
		return false, "That can't go in the ring"
	end
	local ring = data.ring
	local at = table.find(ring, id)
	if inRing == false then
		if at then
			table.remove(ring, at)
			-- it was banked while in the ring, so it stays banked
			local s = states[player]
			if s then
				local bag = (s.banked :: any)[if Herbs.Defs[id] then "herbs" else "items"]
				bag[id] = Items.count(data, id)
			end
		end
		return true, nil
	end
	if at then
		return true, nil
	end
	if Items.count(data, id) <= 0 then
		return false, "You have none to store"
	end
	if Haul.safeFind(id) then
		return false, `{Items.Defs[id].name} is rare enough to be safe already.`
	end
	if #ring >= Haul.ringSlots(data) then
		return false, `Your spirit ring holds {Haul.ringSlots(data)} stacks. Take one out first.`
	end
	table.insert(ring, id)
	data.stats.ringed += 1
	return true, `{Items.Defs[id].name} is in your spirit ring: safe even in the wilds.`
end

-- Stacks the player no longer holds leave the ring (it shows only what you carry),
-- and a ring over its size after a realm change keeps its first stacks.
local function tidyRing(data: PlayerData.Data)
	local ring = data.ring
	for i = #ring, 1, -1 do
		local id = ring[i]
		if type(id) ~= "string" or not Items.Defs[id] or Items.count(data, id) <= 0 then
			table.remove(ring, i)
		end
	end
	while #ring > math.max(Haul.ringSlots(data), 0) do
		table.remove(ring)
	end
end

--[[ Banking ]]

-- Rare finds and ringed stacks are banked at every check (and before a loss).
local function bankSafe(s: State, data: PlayerData.Data)
	for _, bag in BAGS do
		local held = (data :: any)[bag] :: { [string]: number }
		local banked = (s.banked :: any)[bag] :: { [string]: number }
		for id, count in held do
			local ringed = bag ~= "seeds" and table.find(data.ring, id) ~= nil
			if Haul.safeFind(id) or ringed then
				banked[id] = count
			end
		end
	end
end

-- Spending or using what was banked lowers the snapshot with it.
local function lower(s: State, data: PlayerData.Data)
	local b = s.banked
	b.rawQi = math.min(b.rawQi, data.rawQi)
	b.stones = math.min(b.stones, data.stones)
	for _, bag in BAGS do
		local held = (data :: any)[bag] :: { [string]: number }
		local banked = (b :: any)[bag] :: { [string]: number }
		for id, count in banked do
			local now = held[id] or 0
			if now < count then
				banked[id] = if now > 0 then now else nil
			end
		end
	end
end

-- What the player holds above the snapshot: this trip's haul.
function Haul.unbanked(player: Player): Amounts
	local s = states[player]
	local data = PlayerData.get(player)
	if not (s and data and s.data == data) then
		return empty()
	end
	bankSafe(s, data)
	lower(s, data)
	local out = empty()
	out.rawQi = math.max(0, data.rawQi - s.banked.rawQi)
	out.stones = math.max(0, data.stones - s.banked.stones)
	for _, bag in BAGS do
		local held = (data :: any)[bag] :: { [string]: number }
		local banked = (s.banked :: any)[bag] :: { [string]: number }
		local into = (out :: any)[bag] :: { [string]: number }
		for id, count in held do
			local extra = count - (banked[id] or 0)
			if extra > 0 then
				into[id] = extra
			end
		end
	end
	return out
end

-- A short line for a set of amounts ("120 raw qi, 3 herbs, 40 Spirit Stones").
local function describe(a: Amounts): string
	local parts = {}
	if a.rawQi >= 1 then
		table.insert(parts, `{math.floor(a.rawQi)} raw qi`)
	end
	local herbs, items, seeds = 0, 0, 0
	for _, n in a.herbs do
		herbs += n
	end
	for _, n in a.items do
		items += n
	end
	for _, n in a.seeds do
		seeds += n
	end
	if herbs > 0 then
		table.insert(parts, `{herbs} herb{if herbs == 1 then "" else "s"}`)
	end
	if items > 0 then
		table.insert(parts, `{items} item{if items == 1 then "" else "s"}`)
	end
	if seeds > 0 then
		table.insert(parts, `{seeds} seed{if seeds == 1 then "" else "s"}`)
	end
	if a.stones > 0 then
		table.insert(parts, `{a.stones} Spirit Stones`)
	end
	return table.concat(parts, ", ")
end

-- Whether standing here banks the haul: a safe zone (SafeZone.at: the sect's
-- grounds, any spirit peak; in the testbed the spawn pad's ring) or any teleport array.
function Haul.safeAt(player: Player, position: Vector3): boolean
	if Config.TESTBED then
		return SafeZone.at(position)
	end
	return SafeZone.at(position) or Travel.standingOn(player) ~= nil
end

-- Bank everything held now. Returns what was newly banked.
function Haul.bank(player: Player): Amounts
	local data = PlayerData.get(player)
	local s = states[player]
	if not (data and s) then
		return empty()
	end
	local gained = Haul.unbanked(player)
	s.banked = snapshot(data)
	s.data = data
	return gained
end

local function announce(player: Player, gained: Amounts, how: string)
	if isEmpty(gained) then
		return
	end
	for _, fn in Haul.onBanked do
		task.spawn(fn, player, gained, how)
	end
end

-- Silent bank (riding an array). Travel.onTravel, before the character moves.
function Haul.bankQuietly(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (root and Haul.safeAt(player, root.Position)) then
		return
	end
	announce(player, Haul.bank(player), "travel")
end

-- InventoryAction "storeAll": the Store all prompt at a bank point.
function Haul.storeAll(player: Player): (boolean, string?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (root and Haul.safeAt(player, root.Position)) then
		return false, "Store your haul at home, in the sect, or on a teleport array."
	end
	if player:GetAttribute("InCombat") == true then
		return false, "You can't store your haul mid-fight."
	end
	local gained = Haul.bank(player)
	if isEmpty(gained) then
		return false, "Nothing to store: your haul is already safe."
	end
	local data = PlayerData.get(player)
	if data then
		data.stats.stored += 1
	end
	local line = `Stored: {describe(gained)}`
	effectRemote:FireClient(player, "banked", line)
	effectRemote:FireClient(player, "reward", { tier = "small", text = line, color = Color3.fromRGB(240, 210, 140) })
	announce(player, gained, "store")
	return true, nil
end

--[[ Losing it ]]

-- Take SPILL_SHARE of each unbanked amount out of the profile. Returns what was taken.
local function takeShare(player: Player): Amounts
	local data = PlayerData.get(player)
	local taken = empty()
	if not data then
		return taken
	end
	local share = Tuning.SPILL_SHARE
	local haul = Haul.unbanked(player)
	local qi = math.floor(haul.rawQi * share)
	if qi > 0 then
		data.rawQi -= qi
		taken.rawQi = qi
	end
	local stones = math.floor(haul.stones * share + 0.5)
	if stones > 0 then
		data.stones -= stones
		taken.stones = stones
	end
	for _, bag in BAGS do
		local held = (data :: any)[bag] :: { [string]: number }
		local into = (taken :: any)[bag] :: { [string]: number }
		for id, n in (haul :: any)[bag] :: { [string]: number } do
			local lose = math.min(held[id] or 0, math.floor(n * share + 0.5))
			if lose > 0 then
				held[id] -= lose
				if held[id] <= 0 then
					held[id] = nil
				end
				into[id] = lose
			end
		end
	end
	return taken
end

local function sendSpill(player: Player, spill: Spill)
	effectRemote:FireClient(player, "spill", spill.at, spill.expires)
end

-- Humanoid.Died (before Combat.died): spill the share where they last stood.
function Haul.died(player: Player, character: Model)
	local s = states[player]
	if not s or not s.data then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = s.lastGround or (root and root.Position)
	if not at then
		return
	end
	local taken = takeShare(player)
	if isEmpty(taken) then
		return
	end
	if s.spill then
		effectRemote:FireClient(player, "spillGone", false) -- the older spill is lost
	end
	s.spill = { at = at, expires = workspace:GetServerTimeNow() + Tuning.SPILL_SECONDS, contents = taken }
	local data = PlayerData.get(player)
	if data then
		data.stats.spills += 1 -- the heart-demon trial reads greed and caution
	end
	sendSpill(player, s.spill :: Spill)
	Cultivation.pushState(player)
end

-- PlayerRemoving (before the profile is released): leaving mid-fight is a death
-- with nothing to reclaim.
-- Otherwise: at a bank point it banks; elsewhere the haul is saved as unbanked
-- (data.haul) for the next session.
function Haul.leaving(player: Player)
	local s = states[player]
	local data = PlayerData.get(player)
	if s and data and s.data == data then
		if player:GetAttribute("InCombat") == true then
			local taken = takeShare(player)
			if not isEmpty(taken) then
				data.stats.fled += 1
				print(`Haul: {player.Name} left in combat and lost {describe(taken)}`)
			end
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local home = root ~= nil and Haul.safeAt(player, root.Position) and player:GetAttribute("InCombat") ~= true
		data.haul = if home then empty() else Haul.unbanked(player) :: any
	end
	states[player] = nil
end

local function reclaim(player: Player, s: State, data: PlayerData.Data)
	local spill = s.spill :: Spill
	s.spill = nil
	local c = spill.contents
	data.stats.reclaimed += 1
	local dantian = Cultivation.stage(data).dantian
	data.rawQi = math.min(math.max(dantian, data.rawQi), data.rawQi + c.rawQi)
	data.stones += c.stones
	for _, bag in BAGS do
		local held = (data :: any)[bag] :: { [string]: number }
		for id, n in (c :: any)[bag] :: { [string]: number } do
			held[id] = (held[id] or 0) + n
		end
	end
	effectRemote:FireClient(player, "spillGone", true)
	Cultivation.notify(player, `You gathered your spilled haul back: {describe(c)}. Bring it home.`)
	Cultivation.pushState(player)
end

--[[ The check ]]

local function check(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local s = states[player]
	if not s or s.data ~= data then
		-- a fresh session: everything is banked but what the last one left out (data.haul)
		local banked = snapshot(data)
		local saved = (data.haul or empty()) :: any
		banked.rawQi = math.max(0, banked.rawQi - (saved.rawQi or 0))
		banked.stones = math.max(0, banked.stones - (saved.stones or 0))
		for _, bag in BAGS do
			local into = (banked :: any)[bag] :: { [string]: number }
			for id, n in ((saved :: any)[bag] or {}) :: { [string]: number } do
				if into[id] then
					local left = into[id] - n
					into[id] = if left > 0 then left else nil
				end
			end
		end
		data.haul = empty()
		s = { data = data, banked = banked, ready = false, lastGround = nil, spill = nil }
		states[player] = s
	end
	local st = s :: State
	tidyRing(data)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local alive = humanoid ~= nil and humanoid.Health > 0 and root ~= nil
	if st.spill and workspace:GetServerTimeNow() >= st.spill.expires then
		st.spill = nil
		effectRemote:FireClient(player, "spillGone", false)
	end
	if not (alive and root and humanoid) then
		bankSafe(st, data)
		lower(st, data)
		return
	end
	local position = root.Position
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		st.lastGround = position
	end
	if st.spill and (st.spill.at - position).Magnitude <= Tuning.RECLAIM_RADIUS then
		reclaim(player, st, data)
	end
	-- at a bank point with something unbanked: offer Store all (HaulReady)
	local left = Haul.unbanked(player) -- also lowers the snapshot and banks the ring
	local ready = not isEmpty(left) and player:GetAttribute("InCombat") ~= true and Haul.safeAt(player, position)
	if ready ~= st.ready then
		st.ready = ready
		player:SetAttribute("HaulReady", ready or nil)
	end
end

function Haul.start()
	table.insert(Travel.onTravel, Haul.bankQuietly)
	local function watch(player: Player)
		-- a respawn re-sends the spill (and says where it is)
		player.CharacterAdded:Connect(function()
			local s = states[player]
			if s and s.spill then
				task.delay(1, function()
					if states[player] == s and s.spill then
						sendSpill(player, s.spill :: Spill)
						local left = math.max(0, math.floor((s.spill.expires - workspace:GetServerTimeNow()) / 60 + 0.5))
						Cultivation.notify(
							player,
							`Half your haul spilled where you fell. Only you can see its light: walk back to it within {left} min.`
						)
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	task.spawn(function()
		while true do
			task.wait(Tuning.CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(check, player)
				if not ok then
					warn(`Haul: check failed for {player.Name}: {err}`)
				end
			end
		end
	end)
end

return Haul
