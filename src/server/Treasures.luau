--!strict
-- Heavenly treasures: when auspicious weather begins (Weather.Defs[*].treasures),
-- that many treasures fall at random spots in the wilds' enemy zones, each a
-- glowing orb under a pillar of light (ServerStorage.ItemTemplates.WorldTreasure).
-- The first player to claim one keeps it. Unclaimed ones fade when the weather ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Items = require(ReplicatedStorage.Shared.Items)
local Weather = require(ReplicatedStorage.Shared.Weather)
local Inventory = require(script.Parent.Inventory)
local WeatherService = require(script.Parent.WeatherService)

local notifyRemote = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local template = (ServerStorage:WaitForChild("ItemTemplates") :: Folder):WaitForChild("WorldTreasure") :: Model
local wilds = workspace:WaitForChild("Wilds")

local Treasures = {}

local live: { Model } = {}

local function pickTreasure(): Items.Item
	local total = 0
	for _, item in Items.Treasures do
		total += item.treasureWeight or 0
	end
	local roll = math.random() * total
	for _, item in Items.Treasures do
		roll -= item.treasureWeight or 0
		if roll <= 0 then
			return item
		end
	end
	return Items.Treasures[1]
end

-- A random spot on the ground inside one of the wilds' enemy zones.
function Treasures.randomSpot(): Vector3?
	local zones = {}
	for _, zone in (wilds:FindFirstChild("Zones") :: Instance):GetChildren() do
		if zone:IsA("BasePart") then
			table.insert(zones, zone)
		end
	end
	if #zones == 0 then
		return nil
	end
	local zone = zones[math.random(#zones)]
	local radius = ((zone:GetAttribute("Radius") :: number?) or 20) * 0.9
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
	local at = zone.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { zone.Parent :: Instance, wilds:FindFirstChild("Enemies") :: Instance }
	local hit = workspace:Raycast(at + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position else nil
end

local function fadeOut(model: Model)
	local i = table.find(live, model)
	if i then
		table.remove(live, i)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	task.delay(1.6, function()
		model:Destroy()
	end)
end

local function spawnOne(): boolean
	local spot = Treasures.randomSpot()
	if not spot then
		return false
	end
	local item = pickTreasure()
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Base" then
			d.Color = item.color
		elseif d:IsA("Light") then
			d.Color = item.color
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(item.color, Color3.new(1, 1, 1))
		elseif d:IsA("TextLabel") then
			d.Text = item.name
			d.TextColor3 = Items.rarityColor(item)
		end
	end
	model:PivotTo(CFrame.new(spot))
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt
	prompt.ObjectText = item.name
	local claimed = false
	prompt.Triggered:Connect(function(player)
		if claimed then
			return
		end
		claimed = true
		Inventory.grant(player, item.id, 1, spot)
		notifyRemote:FireAllClients(`{player.DisplayName} claimed a heavenly treasure: {item.name}!`)
		fadeOut(model)
	end)
	model.Parent = wilds
	table.insert(live, model)
	return true
end

local function onWeather(def: Weather.Def)
	for i = #live, 1, -1 do
		fadeOut(live[i])
	end
	local count = def.treasures or 0
	local spawned = 0
	for _ = 1, count do
		if spawnOne() then
			spawned += 1
		end
	end
	if spawned > 0 then
		task.wait(3) -- after the weather's own announcement
		notifyRemote:FireAllClients(`{spawned} heavenly treasures have fallen in the wilds! Look for the pillars of light.`)
	end
end

function Treasures.start()
	table.insert(WeatherService.onChanged, onWeather)
end

return Treasures
