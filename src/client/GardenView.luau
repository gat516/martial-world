--!strict
-- Draws herbs growing in every bed (client-side clones, so the server sends only
-- three attributes per bed) and drives the Tend prompt on the local player's beds.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Garden
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Hud = require(script.Parent.Hud)
local MyPeak = require(script.Parent.MyPeak)
local SeedPicker = require(script.Parent.SeedPicker)

local gardenRemote = ReplicatedStorage.Remotes.GardenAction :: RemoteFunction
local herbModels = ReplicatedStorage:WaitForChild("HerbModels")

local SCALE_STEP = 0.05 -- only rescale plants when growth moves this much

type BedView = { herb: string?, plants: { Model }, scale: number, baseScale: number }

local views: { [Instance]: BedView } = {}

local GardenView = {}

local function anchorOf(bed: Instance): BasePart?
	return bed:FindFirstChild("PlotAnchor") :: BasePart?
end

local function progressOf(bed: Instance): number
	local planted, grow = bed:GetAttribute("PlantedAt"), bed:GetAttribute("GrowSeconds")
	if type(planted) ~= "number" or type(grow) ~= "number" or grow <= 0 then
		return 0
	end
	return math.clamp((workspace:GetServerTimeNow() - planted) / grow, 0, 1)
end

local function clearPlants(view: BedView)
	for _, m in view.plants do
		m:Destroy()
	end
	view.plants = {}
end

local function placePlants(bed: Instance, view: BedView, herb: string)
	local anchor = anchorOf(bed)
	local template = herbModels:FindFirstChild(herb) :: Model?
	if not (anchor and template) then
		return
	end
	for _, offset in Config.PLANT_SPOTS do
		local plant = template:Clone()
		plant:PivotTo(anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, offset) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
		plant.Parent = bed
		table.insert(view.plants, plant)
	end
	view.baseScale = template:GetScale() -- templates are authored at mature size
	view.scale = 1
end

local function setScale(view: BedView, scale: number)
	for _, plant in view.plants do
		plant:ScaleTo(view.baseScale * scale)
	end
	view.scale = scale
end

local function promptText(bed: Instance): string
	local herbId = bed:GetAttribute("Herb")
	if type(herbId) ~= "string" then
		return "Plant"
	end
	local p = progressOf(bed)
	if p >= 1 then
		return "Harvest"
	end
	return `Growing {math.floor(p * 100)}%`
end

local function refresh(bed: Instance)
	local view = views[bed]
	if not view then
		return
	end
	local herb = bed:GetAttribute("Herb")
	herb = if type(herb) == "string" then herb else nil
	if herb ~= view.herb then
		clearPlants(view)
		view.herb = herb
		if herb then
			placePlants(bed, view, herb)
		end
	end
	if herb then
		local target = Config.SPROUT_SCALE + (1 - Config.SPROUT_SCALE) * progressOf(bed)
		if math.abs(target - view.scale) >= SCALE_STEP or (target == 1 and view.scale ~= 1) then
			setScale(view, target)
		end
	end
	local anchor = anchorOf(bed)
	local prompt = anchor and anchor:FindFirstChild("Tend") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = MyPeak.owns(Peak.of(bed))
		prompt.ActionText = promptText(bed)
		if herb then
			prompt.ObjectText = Herbs.Defs[herb] and Herbs.Defs[herb].name or "Herb Bed"
		else
			prompt.ObjectText = "Herb Bed"
		end
	end
end

local function onTend(bed: Instance)
	local plotId = bed:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return
	end
	local herb = bed:GetAttribute("Herb")
	if type(herb) ~= "string" then
		SeedPicker.open(plotId)
		return
	end
	if progressOf(bed) < 1 then
		local def = Herbs.Defs[herb]
		local left = (bed:GetAttribute("PlantedAt") :: number) + (bed:GetAttribute("GrowSeconds") :: number) - workspace:GetServerTimeNow()
		Hud.toast(`{def and def.name or herb} is ready in {math.ceil(left / 60)} min`)
		return
	end
	local _, message = gardenRemote:InvokeServer("harvest", plotId)
	if message then
		Hud.toast(message)
	end
end

local function track(bed: Instance)
	if views[bed] or not bed:IsDescendantOf(workspace) then -- skip catalog templates and previews
		return
	end
	views[bed] = { herb = nil, plants = {}, scale = 1, baseScale = 1 }
	for _, attr in { "Herb", "PlantedAt", "GrowSeconds" } do
		bed:GetAttributeChangedSignal(attr):Connect(function()
			refresh(bed)
		end)
	end
	local anchor = anchorOf(bed)
	local prompt = anchor and anchor:FindFirstChild("Tend") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function()
			onTend(bed)
		end)
	end
	refresh(bed)
end

local function untrack(bed: Instance)
	local view = views[bed]
	if view then
		clearPlants(view)
		views[bed] = nil
	end
end

function GardenView.init()
	CollectionService:GetInstanceAddedSignal("HerbPlot"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("HerbPlot"):Connect(untrack)
	for _, bed in CollectionService:GetTagged("HerbPlot") do
		track(bed)
	end
	-- growth and prompt text tick; also catches the peak's Owner changing
	task.spawn(function()
		while true do
			task.wait(1)
			for bed in views do
				refresh(bed)
			end
		end
	end)
end

return GardenView
