--!strict
-- Owner-only building on their peak: place catalog items, delete placed items, and
-- delete starter pieces (stashed, so they come back for the next owner).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Build
local Peak = require(ReplicatedStorage.Shared.Peak)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Garden = require(script.Parent.Garden)

local catalog = ReplicatedStorage.BuildCatalog

local lastAction: { [Player]: number } = {}

local Build = {}

local function place(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
	local itemId, pos, yaw = args.item, args.pos, args.yaw
	if type(itemId) ~= "string" or typeof(pos) ~= "Vector3" or type(yaw) ~= "number" then
		return false, "Bad request"
	end
	if not catalog:FindFirstChild(itemId) then
		return false, "Unknown item"
	end
	if not Peak.inBounds(pos) then
		return false, "Too far from your peak"
	end
	if #data.peak.placed >= Config.MAX_ITEMS then
		return false, `Your peak holds at most {Config.MAX_ITEMS} items`
	end
	local rec = {
		u = HttpService:GenerateGUID(false):sub(1, 8),
		i = itemId,
		x = Peak.snap(pos.X, Config.GRID),
		y = Peak.snap(pos.Y, 0.05),
		z = Peak.snap(pos.Z, Config.GRID),
		r = Peak.snap(yaw, Config.ROTATE_STEP) % 360,
	}
	if not Peaks.spawnPlaced(peak, rec) then
		return false, "Couldn't place that"
	end
	table.insert(data.peak.placed, rec)
	return true, nil
end

local function remove(player: Player, data: PlayerData.Data, peak: Model, args: any): (boolean, string?)
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
		return false, "Harvest this bed before removing it"
	end
	local placedId = piece:GetAttribute("PlacedId")
	if type(placedId) == "string" then
		for i, rec in data.peak.placed do
			if rec.u == placedId then
				table.remove(data.peak.placed, i)
				break
			end
		end
		piece:Destroy()
		return true, nil
	end
	local starterId = piece:GetAttribute("StarterId") :: string
	data.peak.removed[starterId] = true
	Peaks.stashStarter(peak, starterId)
	return true, nil
end

function Build.handle(player: Player, action: any, args: any): (boolean, string?)
	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.MIN_INTERVAL then
		return false, "Slow down"
	end
	lastAction[player] = now
	local data = PlayerData.get(player)
	local peak = Peaks.ownedBy(player)
	if not (data and peak) then
		return false, "You don't have a peak to build on"
	end
	if type(args) ~= "table" then
		return false, "Bad request"
	end
	if action == "place" then
		return place(player, data, peak, args)
	elseif action == "remove" then
		return remove(player, data, peak, args)
	end
	return false, "Unknown action"
end

function Build.forget(player: Player)
	lastAction[player] = nil
end

return Build
