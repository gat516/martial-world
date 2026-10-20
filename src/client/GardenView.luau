--!strict
-- Draws every plot's plants (client-side clones from HerbModels, so the server
-- sends only the plot's Plants JSON) as they grow, swell and mutate, gives each
-- of the owner's ripe plants a Harvest prompt, and shows a PlantTag card over the
-- plant under the pointer or, failing that, the nearest one. The plot's own Plant
-- prompt starts planting (Planting.luau sets GardenView.onTend).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Hud = require(script.Parent.Hud)
local MyPeak = require(script.Parent.MyPeak)
local PlantTag = require(script.Parent.PlantTag)

local gardenRemote = ReplicatedStorage.Remotes.GardenAction :: RemoteFunction
local herbModels = ReplicatedStorage:WaitForChild("HerbModels")
local kit = ReplicatedStorage:WaitForChild("GardenKit")

local SCALE_STEP = 0.03 -- only rescale a plant when its size moves this much (share)
local TAG_RANGE = 14 -- studs: the nearest plant within this gets the tag on touch
local TICK = 0.25

type PlantView = {
	plant: Herbs.Plant,
	model: Model,
	root: BasePart, -- the largest part: holds the prompt and mutation effects
	baseScale: number,
	scale: number,
	mutations: string,
	prompt: ProximityPrompt,
}
type PlotView = { json: string?, plants: { [string]: PlantView }, list: { Herbs.Plant } }

local views: { [Instance]: PlotView } = {}

local GardenView = {}

-- Set by Planting: the owner pressed a plot's Plant prompt.
GardenView.onTend = nil :: ((plot: Instance) -> ())?

function GardenView.soilOf(plot: Instance): string
	local soil = plot:GetAttribute("Soil")
	return if type(soil) == "string" then soil else "bed"
end

function GardenView.anchorOf(plot: Instance): BasePart?
	return plot:FindFirstChild("PlotAnchor") :: BasePart?
end

-- The plot's plantings, as last mirrored by the server.
function GardenView.plantsOf(plot: Instance): { Herbs.Plant }
	local view = views[plot]
	return if view then view.list else {}
end

-- Every tracked plot in the world (not catalog templates or previews).
function GardenView.plots(): { Instance }
	local list = {}
	for plot in views do
		table.insert(list, plot)
	end
	return list
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A stable turn for each plant, so it faces the same way for everyone.
local function yawOf(u: string): number
	local h = 0
	for i = 1, #u do
		h = (h * 31 + string.byte(u, i)) % 3600
	end
	return math.rad(h / 10)
end

local function growthScale(plant: Herbs.Plant): number
	if plant.n > 0 then
		return 1 -- a regrowing plant stays full size
	end
	return Herbs.SPROUT_SCALE + (1 - Herbs.SPROUT_SCALE) * Herbs.progress(plant, now())
end

local function targetScale(view: PlantView): number
	local herb = Herbs.Defs[view.plant.h]
	return view.baseScale * (if herb then herb.scale else 1) * view.plant.s * growthScale(view.plant)
end

local function setMutations(view: PlantView)
	local key = table.concat(view.plant.m or {}, ",")
	if key == view.mutations then
		return
	end
	view.mutations = key
	for _, child in view.root:GetChildren() do
		if child:IsA("ParticleEmitter") and child:GetAttribute("Mutation") then
			child:Destroy()
		end
	end
	local fx = kit:FindFirstChild("MutationFX") :: Folder
	for _, id in view.plant.m or {} do
		local template = fx:FindFirstChild(id)
		if template then
			local e = template:Clone()
			e:SetAttribute("Mutation", true)
			e.Parent = view.root
		end
	end
end

local function largestPart(model: Model): BasePart?
	local best, bestVolume = nil, -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	return best or model.PrimaryPart
end

local function harvest(plot: Instance, u: string)
	local plotId = plot:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return
	end
	local _, message = gardenRemote:InvokeServer("harvest", plotId, u)
	if message then
		Hud.toast(message)
	end
end

local function addPlant(plot: Instance, anchor: BasePart, plant: Herbs.Plant): PlantView?
	local template = herbModels:FindFirstChild(plant.h) :: Model?
	if not template then
		return nil
	end
	local model = template:Clone()
	model.Name = "Plant"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	model:PivotTo(anchor.CFrame * CFrame.new(plant.x, anchor.Size.Y / 2, plant.z) * CFrame.Angles(0, yawOf(plant.u), 0))
	local root = largestPart(model) :: BasePart
	local prompt = (kit:FindFirstChild("PlantPrompt") :: ProximityPrompt):Clone()
	prompt.Parent = root
	local view: PlantView = {
		plant = plant,
		model = model,
		root = root,
		baseScale = template:GetScale(),
		scale = 0,
		mutations = "",
		prompt = prompt,
	}
	prompt.Triggered:Connect(function()
		harvest(plot, view.plant.u)
	end)
	model.Parent = plot
	return view
end

local function parse(plot: Instance): { Herbs.Plant }
	local json = plot:GetAttribute("Plants")
	if type(json) ~= "string" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, json)
	return if ok and type(list) == "table" then list else {}
end

local function update(plot: Instance, view: PlotView)
	local mine = MyPeak.owns(Peak.of(plot))
	for _, pv in view.plants do
		local target = targetScale(pv)
		if math.abs(target - pv.scale) > pv.scale * SCALE_STEP then
			pv.model:ScaleTo(target)
			pv.scale = target
		end
		setMutations(pv)
		local ready = Herbs.progress(pv.plant, now()) >= 1
		pv.prompt.Enabled = mine and ready
		pv.prompt.ObjectText = Herbs.title(pv.plant)
	end
end

local function sync(plot: Instance)
	local view = views[plot]
	local anchor = GardenView.anchorOf(plot)
	if not (view and anchor) then
		return
	end
	local json = plot:GetAttribute("Plants")
	if json == view.json then
		return
	end
	view.json = if type(json) == "string" then json else nil
	view.list = parse(plot)
	local seen = {}
	for _, plant in view.list do
		seen[plant.u] = true
		local pv = view.plants[plant.u]
		if pv and pv.plant.h ~= plant.h then
			pv.model:Destroy()
			pv = nil
		end
		if pv then
			pv.plant = plant
		else
			view.plants[plant.u] = addPlant(plot, anchor, plant) :: PlantView
		end
	end
	for u, pv in view.plants do
		if not seen[u] then
			pv.model:Destroy()
			view.plants[u] = nil
		end
	end
	update(plot, view)
end

local function refreshTendPrompt(plot: Instance)
	local anchor = GardenView.anchorOf(plot)
	local prompt = anchor and anchor:FindFirstChild("Tend") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = MyPeak.owns(Peak.of(plot))
	end
end

local function track(plot: Instance)
	if views[plot] or not plot:IsDescendantOf(workspace) then -- skip catalog templates and previews
		return
	end
	views[plot] = { json = nil, plants = {}, list = {} }
	plot:GetAttributeChangedSignal("Plants"):Connect(function()
		sync(plot)
	end)
	local anchor = GardenView.anchorOf(plot)
	local prompt = anchor and anchor:FindFirstChild("Tend") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function()
			if GardenView.onTend then
				GardenView.onTend(plot)
			end
		end)
	end
	sync(plot)
	refreshTendPrompt(plot)
end

local function untrack(plot: Instance)
	local view = views[plot]
	if view then
		for _, pv in view.plants do
			pv.model:Destroy()
		end
		views[plot] = nil
	end
end

--[[ The plant tag ]]

local function plantAtPointer(): PlantView?
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return nil
	end
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	local node: Instance? = hit and hit.Instance
	while node and node.Name ~= "Plant" do
		node = node.Parent
	end
	if not node then
		return nil
	end
	local view = views[node.Parent :: Instance]
	if view then
		for _, pv in view.plants do
			if pv.model == node then
				return pv
			end
		end
	end
	return nil
end

local function nearestPlant(): PlantView?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDistance = nil, TAG_RANGE
	for _, view in views do
		for _, pv in view.plants do
			local d = (pv.model:GetPivot().Position - root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = pv, d
			end
		end
	end
	return best
end

local function updateTag()
	local pv = plantAtPointer() or nearestPlant()
	if not pv then
		PlantTag.hide()
		return
	end
	local plant = pv.plant
	local herb = Herbs.Defs[plant.h]
	local mutations = {}
	for _, id in plant.m or {} do
		local m = Herbs.Mutations[id]
		if m then
			table.insert(mutations, { name = m.name, color = m.color })
		end
	end
	local t = now()
	PlantTag.show(pv.root, {
		title = Herbs.title(plant),
		color = if herb then herb.color else Color3.new(1, 1, 1),
		rarity = if herb then herb.rarity else "",
		sizeLabel = Herbs.sizeLabel(plant.s),
		size = plant.s,
		mutations = mutations,
		progress = Herbs.progress(plant, t),
		ready = Herbs.progress(plant, t) >= 1,
		secondsLeft = Herbs.secondsLeft(plant, t),
		regrows = herb ~= nil and herb.regrowSeconds ~= nil,
	})
end

function GardenView.init()
	CollectionService:GetInstanceAddedSignal("HerbPlot"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("HerbPlot"):Connect(untrack)
	for _, plot in CollectionService:GetTagged("HerbPlot") do
		track(plot)
	end
	-- growth, prompts and the tag; also catches the peak's Owner changing
	task.spawn(function()
		while true do
			task.wait(TICK)
			for plot, view in views do
				update(plot, view)
				refreshTendPrompt(plot)
			end
			updateTag()
		end
	end)
end

return GardenView
