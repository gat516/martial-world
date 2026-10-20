--!strict
-- Draws every plot's plants (client-side clones from HerbModels, so the server
-- sends only the plot's Plants JSON) as they grow, swell and mutate, gives each
-- of the owner's ripe plants a Harvest prompt, and shows a PlantTag card over the
-- plant under the pointer or, failing that, the nearest one. The plot's own Plant
-- prompt starts planting (Planting.luau sets GardenView.onTend). Bed and ripe
-- plants share F (the nearest one shows). Each of the owner's growing plants also
-- gets a "Grow now (N R$)" prompt on G, which buys the Robux product for its tier;
-- the server remembers the target and finishes that plant when the receipt lands.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Hud = require(script.Parent.Hud)
local MyPeak = require(script.Parent.MyPeak)
local State = require(script.Parent.State)
local PlantTag = require(script.Parent.PlantTag)
local WorldPrompts = require(script.Parent.WorldPrompts)

local gardenRemote = ReplicatedStorage.Remotes.GardenAction :: RemoteFunction
local herbModels = ReplicatedStorage:WaitForChild("HerbModels")
local kit = ReplicatedStorage:WaitForChild("GardenKit")

local SCALE_STEP = 0.03 -- only rescale a plant when its size moves this much (share)
local TAG_RANGE = 14 -- studs: the nearest plant within this gets the tag on touch
local TICK = 0.25
local HARVEST_RANGE = 10 -- studs; ScaleTo scales a prompt's range with the plant, so we pin it

type PlantView = {
	plant: Herbs.Plant,
	model: Model,
	root: BasePart, -- the largest part: holds the prompt and mutation effects
	baseScale: number,
	scale: number,
	mutations: string,
	prompt: ProximityPrompt,
	grow: ProximityPrompt,
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

-- Grow now: ask the server which product this plant's time left costs (it also
-- remembers the plant), then open Roblox's purchase dialog for it.
local function growNow(plot: Instance, u: string)
	local plotId = plot:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return
	end
	local ok, result = gardenRemote:InvokeServer("growTarget", plotId, u)
	if not ok then
		if type(result) == "string" then
			Hud.toast(result)
		end
		return
	end
	if type(result) ~= "number" or result <= 0 then
		warn("Grow now: no developer product id set for this tier (Config.Garden.GROW_NOW); skipping the purchase")
		return
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, result)
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
	local grow = (kit:FindFirstChild("GrowPrompt") :: ProximityPrompt):Clone()
	grow.Parent = root
	local view: PlantView = {
		plant = plant,
		model = model,
		root = root,
		baseScale = template:GetScale(),
		scale = 0,
		mutations = "",
		prompt = prompt,
		grow = grow,
	}
	prompt.Triggered:Connect(function()
		harvest(plot, view.plant.u)
	end)
	grow.Triggered:Connect(function()
		growNow(plot, view.plant.u)
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
		pv.prompt.MaxActivationDistance = HARVEST_RANGE
		pv.grow.MaxActivationDistance = HARVEST_RANGE
		setMutations(pv)
		local left = Herbs.secondsLeft(pv.plant, now())
		local title = Herbs.title(pv.plant)
		pv.prompt.Enabled = mine and left <= 0
		pv.prompt.ObjectText = title
		local herb = Herbs.Defs[pv.plant.h]
		pv.prompt.ActionText = if herb and herb.regrowSeconds then "Pick" else "Harvest"
		pv.grow.Enabled = mine and left > 0
		if left > 0 then
			pv.grow.ObjectText = title
			pv.grow.ActionText = `Grow now ({Herbs.growNowTier(left).robux} R$)`
		end
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
	if not prompt then
		return
	end
	-- Owner only. It says what is in the bed's soil, and hints when there is
	-- nothing to plant, so the F button is never a dead end.
	local soil = GardenView.soilOf(plot)
	local seeds = State.current.seeds or {}
	local have = false
	for id, count in seeds do
		local herb = Herbs.Defs[id]
		if herb and herb.soil == soil and count > 0 then
			have = true
			break
		end
	end
	local info = (Herbs.Soils :: any)[soil]
	prompt.Enabled = MyPeak.owns(Peak.of(plot))
	prompt.ActionText = if have then "Plant" else "No seeds"
	prompt.ObjectText = if info then info.name else "Plot"
	-- The beds are authored in the place file, not in git, so the style is set here.
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by WorldPrompts
	prompt.MaxActivationDistance = 12
end

local function track(plot: Instance)
	if views[plot] or not plot:IsDescendantOf(workspace) then -- skip catalog templates and previews
		return
	end
	views[plot] = { json = nil, plants = {}, list = {} }
	plot:GetAttributeChangedSignal("Plants"):Connect(function()
		sync(plot)
	end)
	-- With streaming the bed's Model arrives at join but its anchor only when
	-- you come near, so draw the plants once it lands.
	plot.ChildAdded:Connect(function(child)
		if child.Name == "PlotAnchor" then
			local view = views[plot]
			if view then
				view.json = nil
			end
			sync(plot)
		end
	end)
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
	-- A bed's Plant prompt, found by where it is rather than connected when the
	-- bed is tracked: the anchor that holds it may not have streamed in yet.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name ~= "Tend" then
			return
		end
		local node: Instance? = prompt.Parent
		while node and not views[node] do
			node = node.Parent
		end
		if node and GardenView.onTend then
			GardenView.onTend(node)
		end
	end)
	-- a focused plant brings its bed's Plant prompt along
	WorldPrompts.companionOf = function(target)
		local node: Instance? = target
		while node and not views[node] do
			node = node.Parent
		end
		local anchor = node and GardenView.anchorOf(node)
		return anchor and anchor:FindFirstChild("Tend") :: ProximityPrompt?
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
