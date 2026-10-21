--!strict
-- Insight and technique manuals: what kills earn beyond raw qi.
--   - the first kill of each enemy type: insight
--   - every boss kill: insight; the first one also drops a manual
--   - total-kill milestones: insight and/or a manual, once each
--   - boss drop pools (Enemies `bossDrops`): a manual or weapon not owned yet,
--     guaranteed on the first kill of that boss, then by chance
-- Learning a class manual grants that class Dao XP (Pacing.Weapons.XP_MANUAL).
-- A new manual goes onto the hotbar if there's room (Inventory.slotTechnique).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Pacing).Rewards
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local WeaponPacing = require(ReplicatedStorage.Shared.Pacing).Weapons
local Weapons = require(script.Parent.Weapons)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local Progression = {}

-- Called with (player, kind, detail) when something is earned, for analytics.
Progression.onEarned = {} :: { (Player, string, string) -> () }

local function earned(player: Player, kind: string, detail: string)
	for _, fn in Progression.onEarned do
		task.spawn(fn, player, kind, detail)
	end
end

function Progression.grantInsight(player: Player, amount: number, reason: string)
	local data = PlayerData.get(player)
	if not data or amount <= 0 then
		return
	end
	data.insight += amount
	effectRemote:FireClient(player, "insight", amount, reason)
	earned(player, "insight", reason)
end

-- Set by Inventory: puts a technique on the hotbar if there's room for it.
Progression.slotTechnique = nil :: ((PlayerData.Data, string) -> boolean)?

-- Learn a technique (if new) and put it on the hotbar if there's room.
function Progression.grantManual(player: Player, id: string)
	local data = PlayerData.get(player)
	local def = Techniques.Defs[id]
	if not (data and def) or data.techniques.owned[id] then
		return
	end
	data.techniques.owned[id] = { level = 1, xp = 0 }
	if def.weapon ~= "Any" then
		Weapons.addXp(player, def.weapon, WeaponPacing.XP_MANUAL)
	end
	local slotted = Progression.slotTechnique ~= nil and Progression.slotTechnique(data, id)
	effectRemote:FireClient(player, "manual", id, slotted)
	earned(player, "manual", id)
end

-- One entry of a boss pool the player doesn't own yet, or nil.
local function rollPool(player: Player, data: PlayerData.Data, pool: Enemies.BossDrops)
	local options: { () -> () } = {}
	for _, id in pool.manuals do
		if Techniques.Defs[id] and not data.techniques.owned[id] then
			table.insert(options, function()
				Progression.grantManual(player, id)
			end)
		end
	end
	for _, id in pool.weapons do
		if (data.weapons.owned[id] or 0) <= 0 then
			table.insert(options, function()
				if Weapons.grant(player, id) then
					earned(player, "weapon", id)
				end
			end)
		end
	end
	if #options > 0 then
		options[math.random(#options)]()
	end
end

function Progression.onKill(player: Player, def: Enemies.Def, _model: Model)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local firstKill = not data.firstKills[def.id]
	if def.bossDrops and (firstKill or math.random() < def.bossDrops.chance) then
		rollPool(player, data, def.bossDrops)
	end
	if not data.firstKills[def.id] then
		data.firstKills[def.id] = true
		Progression.grantInsight(player, Config.FIRST_KILL_INSIGHT, `First {def.name} slain`)
	end
	if def.boss then
		data.stats.bossKills += 1
		Progression.grantInsight(player, Config.BOSS_INSIGHT, `{def.name} defeated`)
		if data.stats.bossKills == 1 then
			Progression.grantManual(player, Config.BOSS_FIRST_MANUAL)
		end
	end
	for _, m in Config.MILESTONES do
		local key = tostring(m.kills)
		if data.stats.kills >= m.kills and not data.milestones[key] then
			data.milestones[key] = true
			if m.insight then
				Progression.grantInsight(player, m.insight, `{m.kills} enemies slain`)
			end
			if m.manual then
				Progression.grantManual(player, m.manual)
			end
		end
	end
	Cultivation.pushState(player)
end

return Progression
