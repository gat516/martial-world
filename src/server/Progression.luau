--!strict
-- Technique manuals and comprehension: what kills earn beyond raw qi.
--   - the first kill of each beast type and of each boss are foundation
--     experiences (Foundation.kill: Hunt, Boss); the first boss kill drops a manual
--   - total-kill milestones: a manual, once each
--   - boss drop pools (Enemies `bossDrops`): a manual or weapon not owned yet,
--     guaranteed on the first kill of that boss, then by chance
-- Learning a class manual grants that class Dao XP (Pacing.Weapons.XP_MANUAL).
-- Learning needs weapon Dao (Techniques.learnDao): a manual found too early is
-- kept (data.techniques.manuals) and learned the moment the Dao is reached.
-- Comprehending a bottleneck costs Spirit Stones and needs more Dao (comprehend).
-- A new manual goes onto the hotbar if there's room (Inventory.slotTechnique).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Pacing).Rewards
local Comprehension = require(ReplicatedStorage.Shared.Pacing).Comprehension
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local WeaponPacing = require(ReplicatedStorage.Shared.Pacing).Weapons
local Weapons = require(script.Parent.Weapons)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)
local Analytics = require(script.Parent.Analytics)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local Progression = {}

-- Called with (player, kind, detail) when something is earned, for analytics.
Progression.onEarned = {} :: { (Player, string, string) -> () }

local function earned(player: Player, kind: string, detail: string)
	for _, fn in Progression.onEarned do
		task.spawn(fn, player, kind, detail)
	end
end

-- Break a technique's bottleneck: seated in meditation, with enough weapon Dao,
-- spend the gate's Spirit Stones to open its next tier (Pacing.Comprehension).
function Progression.comprehend(player: Player, id: any): (boolean, string?)
	local data = PlayerData.get(player)
	local def = type(id) == "string" and Techniques.Defs[id]
	local owned = def and data and data.techniques.owned[id]
	if not (data and def and owned) then
		return false, "You don't know that technique"
	end
	local gate = Comprehension.GATES[owned.level]
	if not (gate and Techniques.bottleneck(owned.level)) then
		return false, "There's nothing to comprehend yet"
	end
	if owned.xp < Techniques.xpToNext(owned.level) then
		return false, `Practice {def.name} more first`
	end
	if not (Cultivation.meditation and Cultivation.meditation(player)) then
		return false, "Sit and meditate to comprehend it"
	end
	local needDao = Techniques.comprehendDao(def, owned.level) :: number
	if Techniques.daoLevel(def, data.dao) < needDao then
		return false, `You need {Techniques.daoText(def, needDao)}`
	end
	if data.stones < gate.stones then
		return false, `You need {gate.stones} Spirit Stones`
	end
	data.stones -= gate.stones
	Analytics.stones(player, "sink", gate.stones, data.stones, "Gameplay", "Comprehend")
	owned.level += 1
	owned.xp = 0
	Cultivation.notify(player, `You comprehended {def.name}! It reached level {owned.level}.`)
	earned(player, "comprehend", `{id}:{owned.level}`)
	Cultivation.pushState(player)
	return true, nil
end

-- Set by Inventory: puts a technique on the hotbar if there's room for it.
Progression.slotTechnique = nil :: ((PlayerData.Data, string) -> boolean)?

-- Learn a technique (if new) and put it on the hotbar if there's room. Without
-- the Dao it needs, the manual is kept and the player told what it asks for.
function Progression.grantManual(player: Player, id: string)
	local data = PlayerData.get(player)
	local def = Techniques.Defs[id]
	if not (data and def) or data.techniques.owned[id] then
		return
	end
	local need = Techniques.learnDao(def)
	if Techniques.daoLevel(def, data.dao) < need then
		if not data.techniques.manuals[id] then
			data.techniques.manuals[id] = true
			Cultivation.notify(player, `{def.name} manual: requires {Techniques.daoText(def, need)}. It waits in your Arts.`)
			earned(player, "manualHeld", id)
		end
		return
	end
	data.techniques.manuals[id] = nil
	data.techniques.owned[id] = { level = 1, xp = 0 }
	if def.weapon ~= "Any" then
		Weapons.addXp(player, def.weapon, WeaponPacing.XP_MANUAL)
	end
	local slotted = Progression.slotTechnique ~= nil and Progression.slotTechnique(data, id)
	effectRemote:FireClient(player, "manual", id, slotted)
	earned(player, "manual", id)
end

-- Learn every kept manual whose Dao is now reached (Weapons.onLevelUp).
function Progression.learnReady(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	for _, id in Techniques.Order do
		local def = Techniques.Defs[id]
		if data.techniques.manuals[id] and Techniques.daoLevel(def, data.dao) >= Techniques.learnDao(def) then
			Progression.grantManual(player, id)
		end
	end
	Cultivation.pushState(player)
end

-- One entry of a boss pool the player doesn't own yet, or nil.
local function rollPool(player: Player, data: PlayerData.Data, pool: Enemies.BossDrops)
	local options: { () -> () } = {}
	for _, id in pool.manuals do
		if Techniques.Defs[id] and not data.techniques.owned[id] and not data.techniques.manuals[id] then
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
	Foundation.kill(player, def) -- first kills and bosses: foundation experiences (pushed below)
	if not data.firstKills[def.id] then
		data.firstKills[def.id] = true
	end
	data.stats.slain[def.id] = (data.stats.slain[def.id] or 0) + 1 -- the heart-demon trial names them
	if def.tier == "elite" then
		data.stats.elites += 1 -- sought danger (realm variants)
	elseif def.tier == "apex" then
		data.stats.apexes += 1
	end
	if def.boss then
		data.stats.bossKills += 1
		if data.stats.bossKills == 1 then
			Progression.grantManual(player, Config.BOSS_FIRST_MANUAL)
		end
	end
	for _, m in Config.MILESTONES do
		local key = tostring(m.kills)
		if data.stats.kills >= m.kills and not data.milestones[key] then
			data.milestones[key] = true
			if m.manual then
				Progression.grantManual(player, m.manual)
			end
		end
	end
	Cultivation.pushState(player)
end

table.insert(Weapons.onLevelUp, function(player: Player, class: string)
	Foundation.dao(player, class) -- each Dao level reached is a foundation experience
	Progression.learnReady(player)
end)

return Progression
