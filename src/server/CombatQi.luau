--!strict
-- Combat qi: the mana techniques spend. Separate from raw qi (data.rawQi, the
-- dantian), which only feeds cultivation. The pool's size comes from the realm
-- stage (Pacing.CombatQi.MAX via Realms `combatQi`); it regenerates after a short
-- delay since the last spend, faster out of combat. Not saved: it is full on
-- join, on respawn and after a breakthrough.
--
-- Player attributes (the HUD's contract, docs/systems/combat.md):
--   Qi        current combat qi (rounded to 0.1, updated about 10 times a second while it moves)
--   QiMax     the pool's size
--   QiDenied  workspace:GetServerTimeNow() of the last cast refused for lack of qi
--             (the client also sets it locally when its own early check refuses)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pacing = require(ReplicatedStorage.Shared.Pacing).CombatQi
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local TICK = 0.1

type Pool = { qi: number, max: number, lastSpent: number, character: Model? }
local pools: { [Player]: Pool } = {}

local CombatQi = {}

-- Set by Combat: whether the player is fighting (hurt or dealing damage lately).
CombatQi.fighting = nil :: ((Player) -> boolean)?

local function maxOf(player: Player): number?
	local data = PlayerData.get(player)
	return if data then Cultivation.stage(data).combatQi else nil
end

local function publish(player: Player, pool: Pool)
	local shown = math.floor(pool.qi * 10 + 0.5) / 10
	if player:GetAttribute("Qi") ~= shown then
		player:SetAttribute("Qi", shown)
	end
	if player:GetAttribute("QiMax") ~= pool.max then
		player:SetAttribute("QiMax", pool.max)
	end
end

-- The player's pool, or nil while their data is loading. A new pool (join) or a
-- new character (respawn) starts full.
local function pool(player: Player): Pool?
	local max = maxOf(player)
	if not max then
		return nil
	end
	local p = pools[player]
	if not p or p.character ~= player.Character then
		p = { qi = max, max = max, lastSpent = -math.huge, character = player.Character }
		pools[player] = p
	elseif p.max ~= max then
		p.max = max
		p.qi = math.min(p.qi, max)
	end
	return p
end

function CombatQi.get(player: Player): number
	local p = pool(player)
	return if p then p.qi else 0
end

function CombatQi.has(player: Player, cost: number): boolean
	local p = pool(player)
	return p ~= nil and p.qi >= cost
end

-- Spend `cost` if the pool holds it. Returns whether it did.
function CombatQi.spend(player: Player, cost: number): boolean
	local p = pool(player)
	if not p or p.qi < cost then
		return false
	end
	if cost > 0 then
		p.qi -= cost
		p.lastSpent = os.clock()
		publish(player, p)
	end
	return true
end

-- A cast was refused for lack of qi: the HUD flashes the qi bar.
function CombatQi.deny(player: Player)
	player:SetAttribute("QiDenied", workspace:GetServerTimeNow())
end

-- Fill the pool (breakthroughs).
function CombatQi.refill(player: Player)
	local p = pool(player)
	if p then
		p.qi = p.max
		publish(player, p)
	end
end

table.insert(Cultivation.onBreakthrough, function(player: Player)
	CombatQi.refill(player)
end)

Players.PlayerRemoving:Connect(function(player)
	pools[player] = nil
end)

task.spawn(function()
	while true do
		local dt = task.wait(TICK)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local p = pool(player)
			if p then
				if p.qi < p.max and now - p.lastSpent >= Pacing.REGEN_DELAY then
					local fighting = CombatQi.fighting ~= nil and CombatQi.fighting(player)
					local share = if fighting then Pacing.REGEN_SHARE else Pacing.OUT_OF_COMBAT_SHARE
					p.qi = math.min(p.max, p.qi + p.max * share * dt)
				end
				publish(player, p)
			end
		end
	end
end)

return CombatQi
