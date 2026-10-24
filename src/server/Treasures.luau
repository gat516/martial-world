--!strict
-- Heavenly treasures: when auspicious weather begins (Weather.Defs[*].treasures),
-- that many treasures fall at random spots on the wilds' event grounds. The first
-- player to claim one keeps it. Unclaimed ones fade when the weather ends.
--
-- Each birth is published in the workspace attribute HeavenlyTreasures (JSON list of
-- { key, at = {x,y,z}, color = {r,g,b}, weather, born = server time }), and every
-- client draws it from there (src/client/WorldFX/TreasureFX.luau): a rift tears open
-- in the sky, the treasure falls as a meteor and lands at born + LAND under a light
-- pillar. Drawn from the attribute because the place streams: the model below
-- doesn't reach players on the peaks. The server's model (the glowing orb, its claim
-- prompt and label from ServerStorage.ItemTemplates.WorldTreasure, without the old
-- Neon pillar and ring) only appears once it has landed, so the claim waits for it.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Items = require(ReplicatedStorage.Shared.Items)
local Weather = require(ReplicatedStorage.Shared.Weather)
local EventGrounds = require(script.Parent.EventGrounds)
local Inventory = require(script.Parent.Inventory)
local Foundation = require(script.Parent.Foundation)
local WeatherService = require(script.Parent.WeatherService)

local notifyRemote = ReplicatedStorage.Remotes.Notify :: RemoteEvent
local template = (ServerStorage:WaitForChild("ItemTemplates") :: Folder):WaitForChild("WorldTreasure") :: Model
local wilds = workspace:WaitForChild("Wilds")

local Treasures = {}

-- Seconds from the birth to the landing (the client's fall is timed to land just
-- before this; TreasureFX IMPACT).
Treasures.LAND = 7

type Live = { key: string, model: Model, entry: any }
local live: { Live } = {}
local nextKey = 0

local function publish()
	local list = {}
	for _, l in live do
		table.insert(list, l.entry)
	end
	workspace:SetAttribute("HeavenlyTreasures", if #list > 0 then HttpService:JSONEncode(list) else nil)
end

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

-- A random spot on an event ground (EventGrounds.luau). World events (GuardedHerb,
-- AuspiciousClouds) use it through here too.
Treasures.randomSpot = EventGrounds.randomSpot

local function fadeOut(record: Live)
	local i = table.find(live, record)
	if i then
		table.remove(live, i)
		publish()
	end
	local model = record.model
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

local function spawnOne(weatherId: string): boolean
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
	-- keep the template's authored pivot rotation: its pivot is the Ring, a
	-- cylinder turned upright, so dropping it lays the model on its side
	model:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)
	-- the Neon pillar and ring are retired: clients draw the pillar and ground sigil
	-- (GuardedHerb still uses them as its beacon)
	for _, name in { "Pillar", "Ring" } do
		local old = model:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt
	prompt.ObjectText = item.name
	nextKey += 1
	local c = item.color
	local record: Live = {
		key = tostring(nextKey),
		model = model,
		entry = {
			key = tostring(nextKey),
			at = { spot.X, spot.Y, spot.Z },
			color = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) },
			weather = weatherId,
			born = workspace:GetServerTimeNow(),
		},
	}
	local claimed = false
	prompt.Triggered:Connect(function(player)
		if claimed then
			return
		end
		claimed = true
		Foundation.world(player, `treasure:{weatherId}`) -- a World foundation experience, once per weather
		Inventory.grant(player, item.id, 1, spot)
		notifyRemote:FireAllClients(`{player.DisplayName} claimed a heavenly treasure: {item.name}!`)
		fadeOut(record)
	end)
	table.insert(live, record)
	publish()
	task.delay(Treasures.LAND, function()
		if table.find(live, record) then
			model.Parent = wilds -- landed: the orb and its claim appear
		else
			model:Destroy()
		end
	end)
	return true
end

local function onWeather(def: Weather.Def)
	for i = #live, 1, -1 do
		fadeOut(live[i])
	end
	local count = def.treasures or 0
	local spawned = 0
	for _ = 1, count do
		if spawnOne(def.id) then
			spawned += 1
		end
	end
	if spawned > 0 then
		task.wait(3) -- after the weather's own announcement
		notifyRemote:FireAllClients(`{spawned} heavenly treasures are falling from the sky into the wilds! Look for the pillars of light.`)
	end
end

function Treasures.start()
	table.insert(WeatherService.onChanged, onWeather)
end

return Treasures
