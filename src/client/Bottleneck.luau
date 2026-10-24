--!strict
-- Technique bottlenecks, shared by the Inventory's Arts pane (which shows them)
-- and the seated Practice row's Technique tile (where you break them). At a
-- bottleneck (Techniques.bottleneck: XP full at level 3, 6 or 9) XP stops until
-- you comprehend it, seated, for Spirit Stones, with enough weapon Dao
-- (Pacing.Comprehension, Techniques.comprehendDao).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Comprehension = require(ReplicatedStorage.Shared.Pacing).Comprehension
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction

-- stones: the cost; dao / daoHave: the weapon Dao needed and held; daoText: "Sword Dao 4"
export type Gate = { stones: number, dao: number, daoHave: number, daoText: string }

local Bottleneck = {}

-- The player's Dao level that counts for a technique (its class, or the highest).
function Bottleneck.daoLevel(id: string): number
	return Techniques.daoLevel(Techniques.Defs[id], State.current.dao or {})
end

-- The gate a technique is stuck at, or nil while its XP still flows.
function Bottleneck.gateOf(id: string, owned: State.Technique): Gate?
	local def = Techniques.Defs[id]
	local gate = Comprehension.GATES[owned.level]
	if not (def and gate) or not Techniques.bottleneck(owned.level) or owned.xp < Techniques.xpToNext(owned.level) then
		return nil
	end
	local dao = Techniques.comprehendDao(def, owned.level) :: number
	return { stones = gate.stones, dao = dao, daoHave = Bottleneck.daoLevel(id), daoText = Techniques.daoText(def, dao) }
end

function Bottleneck.stones(): number
	return Players.LocalPlayer:GetAttribute("Stones") or 0
end

-- Every owned technique at a bottleneck, in Techniques.Order.
function Bottleneck.list(): { string }
	local owned = State.current.techniques.owned
	local ids = {}
	for _, id in Techniques.Order do
		local t = owned[id]
		if t and Bottleneck.gateOf(id, t) then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Why comprehending can't run now, as a short caption (nil = it can), and the
-- longer toast for it.
function Bottleneck.block(gate: Gate): (string?, string?)
	local s = State.current
	if s.meditation == nil then
		return "Meditate to comprehend", "Sit and meditate, then choose Comprehend."
	elseif gate.daoHave < gate.dao then
		return `Need {gate.daoText}`, `You need {gate.daoText}. Fight with that weapon to deepen its Dao.`
	elseif Bottleneck.stones() < gate.stones then
		return "Need stones", "You need more Spirit Stones."
	end
	return nil, nil
end

local busy = false

-- Try to break a technique's bottleneck; a blocked try toasts the reason. The
-- server's notify announces success.
function Bottleneck.comprehend(id: string)
	local owned = State.current.techniques.owned[id]
	local gate = owned and Bottleneck.gateOf(id, owned)
	if not gate or busy then
		return
	end
	local short, long = Bottleneck.block(gate)
	if short then
		Hud.toast(long or short)
		return
	end
	busy = true
	local ok, message = remote:InvokeServer("comprehend", id)
	busy = false
	if not ok and message then
		Hud.toast(message)
	end
end

return Bottleneck
