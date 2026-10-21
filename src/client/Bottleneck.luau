--!strict
-- Technique bottlenecks, shared by the Inventory's Arts pane (which shows them)
-- and the seated Practice row's Technique tile (where you break them). At a
-- bottleneck (Techniques.bottleneck: XP full at level 3, 6 or 9) XP stops until
-- you comprehend it, seated, for insight and Spirit Stones (Pacing.Comprehension).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Comprehension = require(ReplicatedStorage.Shared.Pacing).Comprehension
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction

export type Gate = { insight: number, stones: number }

local Bottleneck = {}

-- The gate a technique is stuck at, or nil while its XP still flows.
function Bottleneck.gateOf(owned: State.Technique): Gate?
	if Techniques.bottleneck(owned.level) and owned.xp >= Techniques.xpToNext(owned.level) then
		return Comprehension.GATES[owned.level]
	end
	return nil
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
		if t and Bottleneck.gateOf(t) then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Why comprehending can't run now, as a short caption (nil = it can).
function Bottleneck.block(gate: Gate): string?
	local s = State.current
	if s.meditation == nil then
		return "Meditate to comprehend"
	elseif (s.insight or 0) < gate.insight then
		return "Need insight"
	elseif Bottleneck.stones() < gate.stones then
		return "Need stones"
	end
	return nil
end

local LONG = {
	["Meditate to comprehend"] = "Sit and meditate, then choose Comprehend.",
	["Need insight"] = "You need more insight. Defeat new foes and bosses to gain it.",
	["Need stones"] = "You need more Spirit Stones.",
}

local busy = false

-- Try to break a technique's bottleneck; a blocked try toasts the reason. The
-- server's notify announces success.
function Bottleneck.comprehend(id: string)
	local owned = State.current.techniques.owned[id]
	local gate = owned and Bottleneck.gateOf(owned)
	if not gate or busy then
		return
	end
	local short = Bottleneck.block(gate)
	if short then
		Hud.toast(LONG[short] or short)
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
