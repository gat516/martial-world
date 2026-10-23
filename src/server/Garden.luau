--!strict
-- The garden. Plots are build pieces tagged HerbPlot (Herb Beds, Lotus Ponds,
-- Spirit Groves) whose Soil attribute says which plants they take (Herbs.Soils;
-- none means "bed"). A plot holds any number of plants, placed anywhere on its
-- PlotAnchor at least their spacing apart, and they may grow over each other.
-- Growth runs on real time, offline too. Each planting rolls a size; while the
-- owner is online, weather (Weather.luau `garden`) speeds growth, swells growing
-- plants and gives mutations, and garden build pieces nearby (BuildItems
-- `garden`) add growth and mutation luck. Size and mutations multiply harvests.
--
-- Plantings live in the profile (data.peak.plots, by plot id) and are mirrored
-- onto the plot as JSON in its Plants attribute for clients to draw.
--
-- Also: wild herbs that sprout on owned peaks during their weather event, seed
-- drops from beasts, and the Herbalist at the Spirit Market (buy seeds, sell herbs).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AllConfig = require(ReplicatedStorage.Shared.Config)
local Config = AllConfig.Garden
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local PlayerData = require(script.Parent.PlayerData)
local Peaks = require(script.Parent.Peaks)
local Cultivation = require(script.Parent.Cultivation)
local Inventory = require(script.Parent.Inventory)
local WeatherService = require(script.Parent.WeatherService)
local Receipts = require(script.Parent.Receipts)

local herbModels = ReplicatedStorage:WaitForChild("HerbModels")
local kit = ReplicatedStorage:WaitForChild("GardenKit")

local MAX_PLANTS = 60 -- per plot, whatever the spacing allows

local rng = Random.new()

local Garden = {}

--[[ Plots ]]

local function findPlot(peak: Model, plotId: string): Instance?
	for _, d in peak:GetDescendants() do
		if d:GetAttribute("PlotId") == plotId and d:HasTag("HerbPlot") then
			return d
		end
	end
	return nil
end

function Garden.soilOf(plot: Instance): string
	local soil = plot:GetAttribute("Soil")
	return if type(soil) == "string" then soil else "bed"
end

local function mirror(plot: Instance, plants: { Herbs.Plant }?)
	plot:SetAttribute("Plants", if plants and #plants > 0 then HttpService:JSONEncode(plants) else nil)
end

-- Draw every saved planting onto the owner's plots (after Peaks.applyLayout).
function Garden.apply(player: Player, data: PlayerData.Data)
	local peak = Peaks.ownedBy(player)
	if not peak then
		return
	end
	for plotId, plants in data.peak.plots do
		local plot = findPlot(peak, plotId)
		if plot then
			mirror(plot, plants)
		else
			data.peak.plots[plotId] = nil -- its plot was deleted
		end
	end
end

function Garden.isPlanted(data: PlayerData.Data, plotId: string): boolean
	local plants = data.peak.plots[plotId]
	return plants ~= nil and #plants > 0
end

local function ownPlot(player: Player, plotId: any): (PlayerData.Data?, Instance?)
	local data = PlayerData.get(player)
	local peak = Peaks.ownedBy(player)
	if not (data and peak and type(plotId) == "string") then
		return nil, nil
	end
	local plot = findPlot(peak, plotId)
	if not (plot and Peak.of(plot) == peak) then
		return nil, nil
	end
	return data, plot
end

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < 1e4
end

local function rollSize(): number
	local total = 0
	for _, band in Herbs.Sizes do
		total += band.weight
	end
	local roll = rng:NextNumber() * total
	for _, band in Herbs.Sizes do
		roll -= band.weight
		if roll <= 0 then
			return math.floor(rng:NextNumber(band.min, band.max) * 100 + 0.5) / 100
		end
	end
	return 1
end

local function findPlant(plants: { Herbs.Plant }, u: any): (Herbs.Plant?, number?)
	for i, plant in plants do
		if plant.u == u then
			return plant, i
		end
	end
	return nil, nil
end

local function stemWorld(plot: Instance, plant: Herbs.Plant): Vector3?
	local anchor = plot:FindFirstChild("PlotAnchor") :: BasePart?
	return anchor and (anchor.CFrame * CFrame.new(plant.x, anchor.Size.Y / 2, plant.z)).Position
end

function Garden.plant(player: Player, plotId: any, herbId: any, x: any, z: any): (boolean, string?)
	local data, plot = ownPlot(player, plotId)
	local herb = type(herbId) == "string" and Herbs.Defs[herbId]
	if not (data and plot and herb and finite(x) and finite(z)) then
		return false, "You can only plant in your own plots"
	end
	local soil = Garden.soilOf(plot)
	if herb.soil ~= soil then
		return false, `{herb.name} doesn't grow in a {Herbs.Soils[soil :: Herbs.Soil].name}. {Herbs.Soils[herb.soil].hint}`
	end
	if (data.seeds[herbId] or 0) < 1 then
		return false, `No {herb.name} seeds`
	end
	local anchor = plot:FindFirstChild("PlotAnchor") :: BasePart?
	if not anchor then
		return false, "This plot can't be planted"
	end
	local halfX, halfZ = anchor.Size.X / 2 - Config.EDGE, anchor.Size.Z / 2 - Config.EDGE
	local inside = if plot:GetAttribute("Round")
		then Vector2.new(x, z).Magnitude <= math.min(halfX, halfZ)
		else math.abs(x) <= halfX and math.abs(z) <= halfZ
	if not inside then
		return false, "Plant inside the plot"
	end
	local plants = data.peak.plots[plotId] or {}
	if #plants >= MAX_PLANTS then
		return false, "This plot is full"
	end
	for _, other in plants do
		local def = Herbs.Defs[other.h]
		local gap = (herb.spacing + (if def then def.spacing else 2)) / 2
		if Vector2.new(other.x - x, other.z - z).Magnitude < gap then
			return false, `Too close to {if def then def.name else "another plant"}`
		end
	end
	data.seeds[herbId] -= 1
	if data.seeds[herbId] <= 0 then
		data.seeds[herbId] = nil
	end
	local plant: Herbs.Plant = {
		u = HttpService:GenerateGUID(false):sub(1, 6),
		h = herbId :: string,
		x = math.floor(x * 10 + 0.5) / 10,
		z = math.floor(z * 10 + 0.5) / 10,
		p = os.time(),
		b = 0,
		n = 0,
		s = rollSize(),
	}
	if rng:NextNumber() < Herbs.GOLDEN_CHANCE then
		plant.m = { "Golden" }
	end
	table.insert(plants, plant)
	data.peak.plots[plotId] = plants
	mirror(plot, plants)
	Cultivation.pushState(player)
	local label = Herbs.sizeLabel(plant.s)
	if plant.m or label then
		return true, `A {Herbs.title(plant)} sprout!`
	end
	return true, nil
end

function Garden.harvest(player: Player, plotId: any, plantId: any): (boolean, string?)
	local data, plot = ownPlot(player, plotId)
	if not (data and plot) then
		return false, "You can only harvest your own plots"
	end
	local plants = data.peak.plots[plotId] or {}
	local plant, index = findPlant(plants, plantId)
	local herb = plant and Herbs.Defs[plant.h]
	if not (plant and index and herb) then
		return false, "Nothing is growing there"
	end
	if Herbs.progress(plant, os.time()) < 1 then
		return false, `{herb.name} isn't ready yet`
	end
	local base = rng:NextInteger(herb.yield[1], herb.yield[2])
	local count = math.max(1, math.floor(base * plant.s * Herbs.multiplier(plant.m) + 0.5))
	local extras = {}
	if herb.regrowSeconds then
		-- it stays and fruits again; weather mutations were spent on this harvest
		plant.p, plant.b, plant.n, plant.m = os.time(), 0, plant.n + 1, nil
	else
		table.remove(plants, index)
		local seeds = rng:NextInteger(Config.SEEDS_BACK[1], Config.SEEDS_BACK[2])
		data.seeds[plant.h] = (data.seeds[plant.h] or 0) + seeds
		table.insert(extras, `+{seeds} seed{if seeds == 1 then "" else "s"}`)
	end
	if herb.mutatesTo and rng:NextNumber() < (herb.mutateChance or 0) then
		data.seeds[herb.mutatesTo] = (data.seeds[herb.mutatesTo] or 0) + 1
		table.insert(extras, `a mutated {Herbs.Defs[herb.mutatesTo].name} seed!`)
	end
	if #plants == 0 then
		data.peak.plots[plotId] = nil
	end
	mirror(plot, plants)
	Inventory.grant(player, plant.h, count, stemWorld(plot, plant)) -- also pushes state
	local message = `Harvested {count} {Herbs.title(plant)}`
	if #extras > 0 then
		message ..= ` ({table.concat(extras, ", ")})`
	end
	return true, message
end

function Garden.uproot(player: Player, plotId: any, plantId: any): (boolean, string?)
	local data, plot = ownPlot(player, plotId)
	local plants = data and data.peak.plots[plotId]
	local plant, index = nil, nil
	if plants then
		plant, index = findPlant(plants, plantId)
	end
	if not (data and plot and plants and plant and index) then
		return false, "Nothing to uproot there"
	end
	table.remove(plants, index)
	if #plants == 0 then
		data.peak.plots[plotId] = nil
	end
	mirror(plot, plants)
	return true, `Uprooted the {Herbs.title(plant)}`
end

--[[ Grow now (Robux) ]]

-- The growing plant each player last pressed Grow now on, and the product they
-- were offered for it. Only this plant is finished when the receipt arrives.
type GrowTarget = { plotId: string, u: string, productId: number }
local growTargets: { [Player]: GrowTarget } = {}

local function tierRobux(productId: number): number?
	for _, tier in Config.GROW_NOW do
		if tier.productId == productId then
			return tier.robux
		end
	end
	return nil
end

-- The player pressed Grow now on a growing plant of theirs. Remember it and
-- return the product id to prompt (the tier for its time left, priced here so
-- the client can't pick a cheaper one). 0 means the product isn't set up yet.
function Garden.growTarget(player: Player, plotId: any, plantId: any): (boolean, any)
	local data, plot = ownPlot(player, plotId)
	local plants = data and data.peak.plots[plotId]
	local plant = if plants then findPlant(plants, plantId) else nil
	if not (data and plot and plant) then
		return false, "That plant isn't yours"
	end
	local left = Herbs.secondsLeft(plant, os.time())
	if left <= 0 then
		return false, "It's already ready"
	end
	local tier = Herbs.growNowTier(left)
	growTargets[player] = { plotId = plotId :: string, u = plant.u, productId = tier.productId }
	return true, tier.productId
end

-- Receipt handler for every Grow now product: finish the targeted plant. It
-- must still be on a plot of the buyer's own peak; if it ripened on its own
-- while they paid, it is already finished and the purchase is granted as is.
-- Anything else (gone, uprooted, no target) leaves the receipt unprocessed.
local function growNow(player: Player, data: PlayerData.Data?, info: any): boolean
	if not data then
		return false -- not playing a slot yet; Roblox retries the receipt later
	end
	local target = growTargets[player]
	local peak = Peaks.ownedBy(player)
	local plot = if peak and target then findPlot(peak, target.plotId) else nil
	local plants = if target then data.peak.plots[target.plotId] else nil
	local plant = if plants and target then findPlant(plants, target.u) else nil
	if not (target and plot and plants and plant) then
		warn(`Grow now: {player.Name} paid for product {info.ProductId} but their target plant is gone`)
		return false
	end
	local now = os.time()
	local left = Herbs.secondsLeft(plant, now)
	local paid = tierRobux(info.ProductId) or 0
	if left > 0 and paid < Herbs.growNowTier(left).robux then
		warn(`Grow now: {player.Name} bought product {info.ProductId}, too cheap for that plant`)
		return false
	end
	growTargets[player] = nil
	if left > 0 then
		plant.b += left
		mirror(plot, plants)
		Cultivation.pushState(player)
	end
	Cultivation.notify(player, `Your {Herbs.title(plant)} is ready to harvest`)
	return true
end

--[[ Weather and garden pieces ]]

type Boost = { at: Vector3, radius: number, growth: number, luck: number }

-- Garden build pieces on a peak, as positioned boosts.
local function boostsOn(peak: Model): { Boost }
	local list = {}
	for _, d in peak:GetDescendants() do
		local id = d:GetAttribute("ItemId")
		local def = type(id) == "string" and BuildItems.Defs[id]
		if def and def.garden and d:IsA("PVInstance") then
			local g = def.garden
			table.insert(list, { at = d:GetPivot().Position, radius = g.radius, growth = g.growth or 0, luck = g.luck or 0 })
		end
	end
	return list
end

local function boostAt(boosts: { Boost }, at: Vector3): (number, number)
	local growth, luck = 0, 0
	for _, b in boosts do
		if (b.at - at).Magnitude <= b.radius then
			growth += b.growth
			luck += b.luck
		end
	end
	return growth, luck
end

local function mutate(plant: Herbs.Plant, id: string): boolean
	local m = plant.m or {}
	if table.find(m, id) then
		return false
	end
	table.insert(m, id)
	plant.m = m
	return true
end

-- One weather tick of `seconds` for a player's garden.
local function tendGarden(player: Player, def: Weather.Def, seconds: number)
	local data = PlayerData.get(player)
	local peak = Peaks.ownedBy(player)
	if not (data and peak) then
		return
	end
	local g = def.garden or {}
	local boosts = boostsOn(peak)
	local now = os.time()
	local minutes = seconds / 60
	for plotId, plants in data.peak.plots do
		local plot = findPlot(peak, plotId)
		if not plot then
			continue
		end
		local changed = false
		for _, plant in plants do
			local at = stemWorld(plot, plant) or Vector3.zero
			local growth, luck = boostAt(boosts, at)
			local growing = Herbs.progress(plant, now) < 1
			local rate = (g.growth or 1) - 1 + growth + Roots.perk(data.root, "growth") + Registry.stat(data, "growth")
			if growing and rate > 0 then
				plant.b += seconds * rate
				changed = true
			end
			if growing and g.swell then
				plant.s = math.min(Herbs.MAX_SIZE, math.floor((plant.s + g.swell * minutes) * 100 + 0.5) / 100)
				changed = true
			end
			if g.mutation and rng:NextNumber() < (g.chance or 0) * minutes * (1 + luck) then
				changed = mutate(plant, g.mutation) or changed
			end
		end
		if changed then
			mirror(plot, plants)
		end
	end
end

--[[ Wild herbs ]]

local function wildSpot(peak: Model): CFrame?
	local frame = Peak.frame(peak)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { peak }
	for _ = 1, 12 do
		local a, r = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * AllConfig.Build.RADIUS * 0.8
		local at = frame * Vector3.new(math.cos(a) * r, 40, math.sin(a) * r)
		local hit = workspace:Raycast(at, Vector3.new(0, -80, 0), params)
		if hit and hit.Normal.Y > 0.85 and not Peak.pieceOf(hit.Instance) then
			return CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
		end
	end
	return nil
end

local function sprout(peak: Model, herbId: string)
	local template = herbModels:FindFirstChild(herbId) :: Model?
	local at = wildSpot(peak)
	if not (template and at) then
		return
	end
	local herb = Herbs.Defs[herbId]
	local model = template:Clone()
	model:ScaleTo(template:GetScale() * herb.scale)
	model:PivotTo(at)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		model:Destroy()
		return
	end
	for _, fx in (kit:FindFirstChild("WildGlow") :: Instance):GetChildren() do
		local c = fx:Clone()
		if c:IsA("Light") or c:IsA("ParticleEmitter") then
			(c :: any).Color = if c:IsA("Light") then herb.color else ColorSequence.new(herb.color)
		end
		c.Parent = root
	end
	local prompt = (kit:FindFirstChild("WildPrompt") :: ProximityPrompt):Clone()
	prompt.ObjectText = `Wild {herb.name}`
	prompt.Parent = root
	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken then
			return
		end
		if Peaks.ownerOf(peak) ~= player then
			Cultivation.notify(player, "This sprout belongs to the peak's owner")
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		taken = true
		local count = rng:NextInteger(Config.WILD_YIELD[1], Config.WILD_YIELD[2])
		if rng:NextNumber() < Config.WILD_SEED_CHANCE then
			data.seeds[herbId] = (data.seeds[herbId] or 0) + 1
			Cultivation.notify(player, `You gathered a {herb.name} seed!`)
		end
		Inventory.grant(player, herbId, count, root.Position)
		model:Destroy()
	end)
	model.Parent = workspace
	task.delay(Config.WILD_SECONDS, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

-- Sprout this many wild herbs of these kinds on a peak.
function Garden.sproutWild(peak: Model, herbIds: { string }, count: number)
	for _ = 1, count do
		sprout(peak, herbIds[rng:NextInteger(1, #herbIds)])
	end
end

local function onWeather(def: Weather.Def)
	local wild = {}
	for _, id in Herbs.Order do
		if Herbs.Defs[id].wild == def.id then
			table.insert(wild, id)
		end
	end
	if #wild == 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local peak = Peaks.ownedBy(player)
		if peak then
			Garden.sproutWild(peak, wild, Config.WILD_PER_PEAK)
			local names = {}
			for _, id in wild do
				table.insert(names, Herbs.Defs[id].name)
			end
			Cultivation.notify(player, `Wild {table.concat(names, " and ")} sprouted on your peak!`)
		end
	end
end

--[[ Beast seeds ]]

local function beastSeed(): string
	local total = 0
	for _, w in Config.BEAST_SEED_WEIGHTS do
		total += w
	end
	local roll = rng:NextNumber() * total
	for i, w in Config.BEAST_SEED_WEIGHTS do
		roll -= w
		if roll <= 0 then
			return Config.BEAST_SEEDS[i]
		end
	end
	return Config.BEAST_SEEDS[1]
end

function Garden.onKill(player: Player, def: Enemies.Def)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local count = 0
	if def.boss then
		count = rng:NextInteger(Config.BOSS_SEEDS[1], Config.BOSS_SEEDS[2])
	elseif rng:NextNumber() < Config.BEAST_SEED_CHANCE then
		count = 1
	end
	local got = {}
	for _ = 1, count do
		local id = beastSeed()
		data.seeds[id] = (data.seeds[id] or 0) + 1
		got[id] = (got[id] or 0) + 1
	end
	for id, n in got do
		Cultivation.notify(player, `The beast dropped {n} {Herbs.Defs[id].name} seed{if n == 1 then "" else "s"}`)
	end
	if count > 0 then
		Cultivation.pushState(player)
	end
end

--[[ The Herbalist ]]

local function herbalistNear(player: Player): boolean
	local hub = workspace:FindFirstChild("Hub")
	local market = hub and hub:FindFirstChild("SpiritMarket") :: Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return market ~= nil and root ~= nil and (root.Position - market:GetPivot().Position).Magnitude <= AllConfig.Build.MARKET_RANGE
end

local function count(n: any, max: number): number?
	return if type(n) == "number" and n == n // 1 and n >= 1 and n <= max then n else nil
end

function Garden.buySeed(player: Player, herbId: any, n: any): (boolean, string?)
	local data = PlayerData.get(player)
	local herb = type(herbId) == "string" and Herbs.Defs[herbId]
	local amount = count(n, Config.MAX_SEEDS_BUY)
	if not (data and herb and herb.seedCost and amount) then
		return false, "The Herbalist doesn't sell that"
	end
	if not herbalistNear(player) then
		return false, "Buy seeds from the Herbalist at the Spirit Market"
	end
	local price = herb.seedCost * amount
	if data.stones < price then
		return false, `You need {price - data.stones} more Spirit Stones`
	end
	data.stones -= price
	data.seeds[herbId] = (data.seeds[herbId] or 0) + amount
	Cultivation.pushState(player)
	return true, `Bought {amount} {herb.name} seed{if amount == 1 then "" else "s"} for {price} Spirit Stones`
end

local function sellOne(data: PlayerData.Data, herbId: string, amount: number): number
	local herb = Herbs.Defs[herbId]
	local have = data.herbs[herbId] or 0
	local sold = math.min(have, amount)
	if not herb or sold <= 0 then
		return 0
	end
	data.herbs[herbId] = if have - sold > 0 then have - sold else nil
	data.stones += sold * herb.sellPrice
	return sold * herb.sellPrice
end

function Garden.sell(player: Player, herbId: any, n: any): (boolean, string?)
	local data = PlayerData.get(player)
	local herb = type(herbId) == "string" and Herbs.Defs[herbId]
	local amount = count(n, Config.MAX_SELL)
	if not (data and herb and amount) then
		return false, "The Herbalist doesn't buy that"
	end
	if not herbalistNear(player) then
		return false, "Sell herbs to the Herbalist at the Spirit Market"
	end
	local before = data.herbs[herbId] or 0
	local earned = sellOne(data, herbId :: string, amount)
	if earned == 0 then
		return false, `You have no {herb.name}`
	end
	Cultivation.pushState(player)
	return true, `Sold {before - (data.herbs[herbId] or 0)} {herb.name} for {earned} Spirit Stones`
end

function Garden.sellAll(player: Player): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then
		return false, nil
	end
	if not herbalistNear(player) then
		return false, "Sell herbs to the Herbalist at the Spirit Market"
	end
	local earned = 0
	for _, id in Herbs.Order do
		earned += sellOne(data, id, math.huge)
	end
	if earned == 0 then
		return false, "You have no herbs to sell"
	end
	Cultivation.pushState(player)
	return true, `Sold every herb for {earned} Spirit Stones`
end

--[[ Admin ]]

-- Every plant on the player's plots becomes ready now.
function Garden.growAll(player: Player): number
	local data = PlayerData.get(player)
	local peak = Peaks.ownedBy(player)
	local n = 0
	if not (data and peak) then
		return 0
	end
	for plotId, plants in data.peak.plots do
		for _, plant in plants do
			plant.b += Herbs.secondsLeft(plant, os.time())
			n += 1
		end
		local plot = findPlot(peak, plotId)
		if plot then
			mirror(plot, plants)
		end
	end
	Cultivation.pushState(player)
	return n
end

function Garden.mutateAll(player: Player, mutation: string): number
	local data = PlayerData.get(player)
	local peak = Peaks.ownedBy(player)
	local n = 0
	if not (data and peak and Herbs.Mutations[mutation]) then
		return 0
	end
	for plotId, plants in data.peak.plots do
		for _, plant in plants do
			if mutate(plant, mutation) then
				n += 1
			end
		end
		local plot = findPlot(peak, plotId)
		if plot then
			mirror(plot, plants)
		end
	end
	return n
end

function Garden.handle(player: Player, action: any, ...: any): (boolean, string?)
	if action == "plant" then
		return Garden.plant(player, ...)
	elseif action == "harvest" then
		return Garden.harvest(player, ...)
	elseif action == "growTarget" then
		return Garden.growTarget(player, ...)
	elseif action == "uproot" then
		return Garden.uproot(player, ...)
	elseif action == "buySeed" then
		return Garden.buySeed(player, ...)
	elseif action == "sell" then
		return Garden.sell(player, ...)
	elseif action == "sellAll" then
		return Garden.sellAll(player)
	end
	return false, "Unknown action"
end

function Garden.start()
	for _, tier in Config.GROW_NOW do
		if tier.productId ~= 0 then
			Receipts.register(tier.productId, growNow)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		growTargets[player] = nil
	end)
	table.insert(WeatherService.onChanged, onWeather)
	task.spawn(function()
		while true do
			task.wait(Config.TICK)
			local def = WeatherService.current()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tendGarden, player, def, Config.TICK)
				if not ok then
					warn("Garden tick:", err)
				end
			end
		end
	end)
end

return Garden
