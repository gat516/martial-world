--!strict
-- Titles (docs/systems/titles.md; defs in Shared.Titles). Earned titles are kept in
-- data.titles.owned (id -> os.time() earned), the worn one in data.titles.equipped
-- ("" = none). The worn one is published as Player attributes Title and TitleColor,
-- which every namecard shows (client Nameplates).
--
-- Granting reads the profile's record, so it needs no hook per system: Main runs
-- Titles.check after every state push (Cultivation.onPush), which fires after kills,
-- breakthroughs, claims and the periodic refresh. A heart-demon trial stores the Dao
-- heart its path answer picked in the trial record (`title`), and its push grants it.
-- The first check of a session grants silently what the record already earned (a
-- veteran's backlog) and shows one banner for all of them; after that each title gets
-- its own banner (Effect "reward", a Rewards.show spec).
--
-- The picker equips through CultivationAction "title" (Main routes it here):
--   "title", "equip", id   wear an owned title
--   "title", "unequip"     wear none

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Defs = require(ReplicatedStorage.Shared.Titles)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local RootDefs = require(ReplicatedStorage.Shared.Roots)
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)
local Analytics = require(script.Parent.Analytics)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

local Titles = {}

-- Set by Main: the state push, after an equip or a grant.
Titles.onChanged = nil :: ((Player) -> ())?

local primed: { [Player]: boolean } = {} -- this session's first check is done

local function rankIndex(id: string): number
	for i, r in Pacing.Sect.RANKS do
		if r.id == id then
			return i
		end
	end
	return 0
end

-- a root grade's place on the ladder (Roots.GradeOrder: Spirit, Earth, Heaven, Immortal)
local function gradeOrder(grade: string?): number
	return if grade then table.find(RootDefs.GradeOrder, grade) or 0 else 0
end

-- Whether the profile meets a title's rule.
function Titles.met(data: PlayerData.Data, def: Defs.Def): boolean
	local rule = def.rule
	local kind = rule.kind
	if kind == "realm" then
		local stage = Realms.ByKey[rule.key :: string]
		return stage ~= nil and Realms.index(data.realm.major, data.realm.minor) >= Realms.index(stage.major, stage.minor)
	elseif kind == "stat" then
		local value = (data.stats :: any)[rule.stat :: string]
		return type(value) == "number" and value >= (rule.min or 1)
	elseif kind == "slain" then
		for _, id in rule.ids or {} do
			if (data.stats.slain[id] or 0) < 1 then
				return false
			end
		end
		return true
	elseif kind == "rank" then
		return rankIndex(data.sect.rank) >= rankIndex(rule.id :: string)
	elseif kind == "pages" then
		local n = 0
		for _, done in data.herbarium.tiers do
			if done then
				n += 1
			end
		end
		return n >= (rule.min or 1)
	elseif kind == "herbs" then
		for _, id in Herbs.Order do
			if not data.herbarium.herbs[id] then
				return false
			end
		end
		return true
	elseif kind == "foundation" then
		for _, value in data.foundation.grades do
			if Foundation.percentOf(value) >= (rule.min or 0) then
				return true
			end
		end
		return false
	elseif kind == "root" then
		local need = gradeOrder(rule.grade)
		if data.root.element ~= "" and gradeOrder(data.root.grade) >= need then
			return true
		end
		for _, grade in data.root.grades do
			if gradeOrder(grade) >= need then
				return true
			end
		end
		return false
	elseif kind == "dao" then
		local entry = data.dao[rule.class :: string]
		return entry ~= nil and entry.level >= (rule.min or 1)
	elseif kind == "heart" then
		for _, trial in data.heartDemon.trials do
			if trial.title == def.id then
				return true
			end
		end
		return false
	elseif kind == "calm" then
		for _, trial in data.heartDemon.trials do
			if trial.calm then
				return true
			end
		end
		return false
	end
	return false
end

-- The worn title onto the Player's attributes (the namecard reads them).
local function publish(player: Player, data: PlayerData.Data)
	local id = data.titles.equipped
	local def = Defs.Defs[id]
	if def and data.titles.owned[id] then
		player:SetAttribute("Title", def.name)
		player:SetAttribute("TitleColor", Defs.color(id))
	else
		player:SetAttribute("Title", nil)
		player:SetAttribute("TitleColor", nil)
	end
end

local function banner(player: Player, kicker: string, title: string, tag: string, tagColor: Color3?, subtitle: string)
	effectRemote:FireClient(player, "reward", {
		tier = "banner",
		style = "gold",
		kicker = kicker,
		title = title,
		tag = tag,
		tagColor = tagColor,
		subtitle = subtitle,
	})
end

-- Grant every title the record now meets. Returns the newly earned ids.
function Titles.check(player: Player, data: PlayerData.Data?): { string }
	data = data or PlayerData.get(player)
	if not data then
		return {}
	end
	local earned = {}
	local now = os.time()
	for _, id in Defs.Order do
		local def = Defs.Defs[id]
		if not data.titles.owned[id] and Titles.met(data, def) then
			data.titles.owned[id] = now
			table.insert(earned, id)
			Analytics.event(player, "TitleEarned", 1, id)
		end
	end
	local first = not primed[player]
	primed[player] = true
	publish(player, data)
	if #earned == 0 then
		return earned
	end
	if first and #earned > 1 then
		banner(player, "TITLES EARNED", `{#earned} titles`, "From your record", nil, "Wear one from your Self card.")
	else
		for _, id in earned do
			local def = Defs.Defs[id]
			banner(player, "TITLE EARNED", def.name, def.rarity, Defs.color(id), def.how)
		end
	end
	if Titles.onChanged then
		Titles.onChanged(player)
	end
	return earned
end

-- CultivationAction "title": "equip" id, "unequip".
function Titles.handle(player: Player, op: any, id: any): (boolean, any)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading"
	end
	if op == "equip" then
		if type(id) ~= "string" or not Defs.Defs[id] then
			return false, "No such title."
		end
		if not data.titles.owned[id] then
			return false, "You haven't earned that title yet."
		end
		data.titles.equipped = id
	elseif op == "unequip" then
		data.titles.equipped = ""
	else
		return false, "Unknown action"
	end
	publish(player, data)
	if Titles.onChanged then
		Titles.onChanged(player)
	end
	return true, data.titles.equipped
end

function Titles.forget(player: Player)
	primed[player] = nil
end

return Titles
