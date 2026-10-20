--!strict
-- Herb beds: plant a seed, wait real time (growth continues offline), harvest herbs
-- and seeds back, with a small chance of a seed mutating into the next rarer herb.
-- Bed state lives in the profile and is mirrored onto the bed as attributes
-- (Herb, PlantedAt, GrowSeconds) for clients to draw the plants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Garden
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Peak = require(ReplicatedStorage.Shared.Peak)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Cultivation = require(script.Parent.Cultivation)

local rng = Random.new()

local Garden = {}

local function findPlot(peak: Model, plotId: string): Instance?
	for _, d in peak:GetDescendants() do
		if d:GetAttribute("PlotId") == plotId and d:HasTag("HerbPlot") then
			return d
		end
	end
	return nil
end

local function mirror(bed: Instance, plot: PlayerData.Plot?)
	local herb = plot and Herbs.Defs[plot.herb]
	bed:SetAttribute("Herb", plot and plot.herb)
	bed:SetAttribute("PlantedAt", plot and plot.planted)
	bed:SetAttribute("GrowSeconds", herb and herb.growSeconds)
end

-- Draw every saved planting onto the owner's beds (after Peaks.applyLayout).
function Garden.apply(player: Player, data: PlayerData.Data)
	local peak = Peaks.ownedBy(player)
	if not peak then
		return
	end
	for plotId, plot in data.peak.plots do
		local bed = findPlot(peak, plotId)
		if bed then
			mirror(bed, plot)
		else
			data.peak.plots[plotId] = nil -- its bed was deleted
		end
	end
end

function Garden.isPlanted(data: PlayerData.Data, plotId: string): boolean
	return data.peak.plots[plotId] ~= nil
end

local function ownBed(player: Player, plotId: any): (PlayerData.Data?, Instance?)
	local data = PlayerData.get(player)
	local peak = Peaks.ownedBy(player)
	if not (data and peak and type(plotId) == "string") then
		return nil, nil
	end
	local bed = findPlot(peak, plotId)
	if not (bed and Peak.of(bed) == peak) then
		return nil, nil
	end
	return data, bed
end

function Garden.plant(player: Player, plotId: any, herbId: any): (boolean, string?)
	local data, bed = ownBed(player, plotId)
	local herb = type(herbId) == "string" and Herbs.Defs[herbId]
	if not (data and bed and herb) then
		return false, "You can only plant in your own beds"
	end
	if data.peak.plots[plotId] then
		return false, "Something is already growing here"
	end
	if (data.seeds[herbId] or 0) < 1 then
		return false, `No {herb.name} seeds`
	end
	data.seeds[herbId] -= 1
	if data.seeds[herbId] <= 0 then
		data.seeds[herbId] = nil
	end
	local plot = { herb = herbId :: string, planted = os.time() }
	data.peak.plots[plotId] = plot
	mirror(bed, plot)
	Cultivation.pushState(player)
	return true, `Planted {herb.name}`
end

function Garden.harvest(player: Player, plotId: any): (boolean, string?)
	local data, bed = ownBed(player, plotId)
	if not (data and bed) then
		return false, "You can only harvest your own beds"
	end
	local plot = data.peak.plots[plotId]
	local herb = plot and Herbs.Defs[plot.herb]
	if not (plot and herb) then
		return false, "Nothing is planted here"
	end
	if os.time() - plot.planted < herb.growSeconds then
		return false, `{herb.name} isn't ready yet`
	end
	local count = rng:NextInteger(herb.yield[1], herb.yield[2])
	data.herbs[plot.herb] = (data.herbs[plot.herb] or 0) + count
	local seeds = rng:NextInteger(Config.SEEDS_BACK[1], Config.SEEDS_BACK[2])
	data.seeds[plot.herb] = (data.seeds[plot.herb] or 0) + seeds
	local message = `Harvested {count} {herb.name} (+{seeds} seeds)`
	if herb.mutatesTo and rng:NextNumber() < (herb.mutateChance or 0) then
		data.seeds[herb.mutatesTo] = (data.seeds[herb.mutatesTo] or 0) + 1
		message ..= ` and a mutated {Herbs.Defs[herb.mutatesTo].name} seed!`
	end
	data.peak.plots[plotId] = nil
	mirror(bed, nil)
	Cultivation.pushState(player)
	return true, message
end

return Garden
