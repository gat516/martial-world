--!strict
-- Insight and technique manuals: what kills earn beyond raw qi, and slotting the
-- techniques you own.
--   - the first kill of each enemy type: insight
--   - every boss kill: insight; the first one also drops a manual
--   - total-kill milestones: insight and/or a manual, once each
-- A new manual goes into the first empty technique slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Progression
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
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

-- Learn a technique (if new) and slot it into the first empty slot.
function Progression.grantManual(player: Player, id: string)
	local data = PlayerData.get(player)
	local def = Techniques.Defs[id]
	if not (data and def) or data.techniques.owned[id] then
		return
	end
	data.techniques.owned[id] = { level = 1, xp = 0 }
	local slots = data.techniques.slots
	local free = table.find(slots, "")
	if free then
		slots[free] = id
	end
	effectRemote:FireClient(player, "manual", id, free ~= nil)
	earned(player, "manual", id)
end

function Progression.onKill(player: Player, def: Enemies.Def, _model: Model)
	local data = PlayerData.get(player)
	if not data then
		return
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

-- Equip or unequip an owned technique.
function Progression.handle(player: Player, action: any, id: any): (boolean, string?)
	local data = PlayerData.get(player)
	if not data or type(id) ~= "string" or not data.techniques.owned[id] then
		return false, "You don't know that technique"
	end
	local slots = data.techniques.slots
	local at = table.find(slots, id)
	if action == "unequip" then
		if at then
			slots[at] = ""
		end
	elseif action == "equip" then
		if not at then
			local free = table.find(slots, "")
			if not free then
				return false, "All slots are full. Unequip one first."
			end
			slots[free] = id
		end
	else
		return false, "Unknown action"
	end
	Cultivation.pushState(player)
	return true, nil
end

return Progression
