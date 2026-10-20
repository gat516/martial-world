--!strict
-- Owner-only building on their peak. Placing takes one of the item from the
-- player's owned count (data.decor); storing anything (placed items or the starter
-- pieces every peak comes with) puts it back. Starter pieces are stashed so they
-- return for the next owner of the peak. Items are bought with Spirit Stones at the
-- Spirit Market on the main peak (BuildItems.luau has every item's definition).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Build
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Peak = require(ReplicatedStorage.Shared.Peak)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Garden = require(script.Parent.Garden)
local Cultivation = require(script.Parent.Cultivation)

local catalog = ReplicatedStorage.BuildCatalog

local lastAction: { [Player]: number } = {}

local Build = {}

local function give(data: PlayerData.Data, itemId: any)
	if type(itemId) == "string" and BuildItems.Defs[itemId] then
		data.decor[itemId] = (data.decor[itemId] or 0) + 1
	end
end

local function take(data: PlayerData.Data, itemId: string)
	data.decor[itemId] -= 1
	if data.decor[itemId] <= 0 then
		data.decor[itemId] = nil
	end
end

-- How many of an item stand on the peak: placed copies plus starter pieces still out.
local function countOnPeak(peak: Model, itemId: string): number
	local n = 0
	for _, d in peak:GetDescendants() do
		if d:GetAttribute("ItemId") == itemId and (d:GetAttribute("PlacedId") or d:GetAttribute("StarterId")) then
			n += 1
		end
	end
	return n
end

local function place(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
	local itemId, pos, yaw = args.item, args.pos, args.yaw
	if type(itemId) ~= "string" or typeof(pos) ~= "Vector3" or type(yaw) ~= "number" then
		return false, "Bad request"
	end
	local def = BuildItems.Defs[itemId]
	if not (def and catalog:FindFirstChild(itemId)) then
		return false, "Unknown item"
	end
	if (data.decor[itemId] or 0) < 1 then
		return false, `You have no {def.name} left. Buy more at the Spirit Market`
	end
	if not Peak.inBounds(pos) then
		return false, "Too far from your peak"
	end
	if #data.peak.placed >= Config.MAX_ITEMS then
		return false, `Your peak holds at most {Config.MAX_ITEMS} items`
	end
	if def.limit and countOnPeak(peak, itemId) >= def.limit then
		return false, `Your peak holds at most {def.limit} {def.name}`
	end
	local rec = {
		u = HttpService:GenerateGUID(false):sub(1, 8),
		i = itemId,
		x = Peak.snap(pos.X, Config.GRID),
		y = Peak.snap(pos.Y, 0.05),
		z = Peak.snap(pos.Z, Config.GRID),
		r = Peak.snap(yaw, Config.FINE_ROTATE_STEP) % 360,
	}
	if not Peaks.spawnPlaced(peak, rec) then
		return false, "Couldn't place that"
	end
	table.insert(data.peak.placed, rec)
	take(data, itemId)
	return true, nil
end

local function store(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
	local target = args.target
	if typeof(target) ~= "Instance" then
		return false, "Bad request"
	end
	local piece = Peak.pieceOf(target)
	if not (piece and Peak.of(piece) == peak) then
		return false, "That isn't part of your peak"
	end
	local plotId = piece:GetAttribute("PlotId")
	if type(plotId) == "string" and Garden.isPlanted(data, plotId) then
		return false, "Harvest this bed before storing it"
	end
	local placedId = piece:GetAttribute("PlacedId")
	if type(placedId) == "string" then
		for i, rec in data.peak.placed do
			if rec.u == placedId then
				table.remove(data.peak.placed, i)
				break
			end
		end
		give(data, piece:GetAttribute("ItemId"))
		piece:Destroy()
		return true, nil
	end
	local starterId = piece:GetAttribute("StarterId") :: string
	data.peak.removed[starterId] = true
	Peaks.stashStarter(peak, starterId)
	give(data, piece:GetAttribute("ItemId"))
	return true, nil
end

-- The Spirit Market stall on the main peak, where items are bought.
local function marketNear(player: Player): boolean
	local hub = workspace:FindFirstChild("Hub")
	local market = hub and hub:FindFirstChild("SpiritMarket") :: Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return market ~= nil and root ~= nil and (root.Position - market:GetPivot().Position).Magnitude <= Config.MARKET_RANGE
end

local function buy(player: Player, data: PlayerData.Data, args: any): (boolean, string?)
	local itemId, count = args.item, args.count
	local def = type(itemId) == "string" and BuildItems.Defs[itemId]
	if not def or type(count) ~= "number" or count ~= count // 1 or count < 1 or count > Config.MAX_BUY then
		return false, "Bad request"
	end
	if not marketNear(player) then
		return false, "Buy build items at the Spirit Market on the main peak"
	end
	local ok, need = BuildItems.unlocked(def, data.realm)
	if not ok then
		return false, `{def.name} unlocks at {need}`
	end
	local price = def.cost * count
	if data.stones < price then
		return false, `You need {price - data.stones} more Spirit Stones`
	end
	data.stones -= price
	data.decor[def.id] = (data.decor[def.id] or 0) + count
	return true, `Bought {count} {def.name} for {price} Spirit Stones`
end

function Build.handle(player: Player, action: any, args: any): (boolean, string?)
	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.MIN_INTERVAL then
		return false, "Slow down"
	end
	lastAction[player] = now
	local data = PlayerData.get(player)
	if not data or type(args) ~= "table" then
		return false, "Bad request"
	end
	local ok, message
	if action == "buy" then
		ok, message = buy(player, data, args)
		if ok then
			Cultivation.pushState(player)
		end
		return ok, message
	end
	local peak = Peaks.ownedBy(player)
	if not peak then
		return false, "You don't have a peak to build on"
	end
	if action == "place" then
		ok, message = place(player, data, peak, args)
	elseif action == "store" then
		ok, message = store(player, data, peak, args)
	else
		return false, "Unknown action"
	end
	if ok then
		Cultivation.pushState(player) -- inventory counts changed
	end
	return ok, message
end

function Build.forget(player: Player)
	lastAction[player] = nil
end

return Build
