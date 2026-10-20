--!strict
-- Insight and technique manuals: what kills earn beyond raw qi.
--   - the first kill of each enemy type: insight
--   - every boss kill: insight; the first one also drops a manual
--   - total-kill milestones: insight and/or a manual, once each
-- A new manual goes onto the hotbar if there's room (Inventory.slotTechnique).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Pacing).Rewards
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
	local slotted = Progression.slotTechnique ~= nil and Progression.slotTechnique(data, id)
	effectRemote:FireClient(player, "manual", id, slotted)
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

return Progression
