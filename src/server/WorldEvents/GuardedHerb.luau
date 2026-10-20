--!strict
-- World event kind: a giant heavenly herb at a random spot in the wilds, under a
-- pillar of light tall enough to see from the peaks, with a guardian beast
-- standing over it. It can't be gathered until the guardian falls; then the
-- first to finish the hold-to-gather keeps it, plus seeds to grow their own.
-- Def settings: herb, guardian, giantScale, beaconScale, gatherSeconds, seeds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Cultivation = require(script.Parent.Parent.Cultivation)
local EnemyService = require(script.Parent.Parent.EnemyService)
local Inventory = require(script.Parent.Parent.Inventory)
local PlayerData = require(script.Parent.Parent.PlayerData)
local Treasures = require(script.Parent.Parent.Treasures)

local beaconTemplate = (ServerStorage:WaitForChild("ItemTemplates") :: Folder):WaitForChild("WorldTreasure") :: Model
local herbModels = ReplicatedStorage:WaitForChild("HerbModels")
local wilds = workspace:WaitForChild("Wilds")

local GuardedHerb = {}

local function tint(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Base" then
			d.Color = color
		elseif d:IsA("Light") then
			d.Color = color
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		end
	end
end

function GuardedHerb.start(run: any): boolean
	local def = run.def
	local herbId: string = def.herb
	local herb = Herbs.Defs[herbId]
	local guardianDef = Enemies.Defs[def.guardian]
	local template = herbModels:FindFirstChild(herbId) :: Model?
	local spot = Treasures.randomSpot()
	if not (herb and guardianDef and template and spot) then
		return false
	end

	local site = Instance.new("Model")
	site.Name = def.id
	local beacon = beaconTemplate:Clone()
	beacon:ScaleTo(def.beaconScale)
	-- keep the template's authored pivot rotation, or its pillar lies on its side
	beacon:PivotTo(CFrame.new(spot) * beaconTemplate:GetPivot().Rotation)
	tint(beacon, herb.color)
	beacon.Parent = site
	local plant = template:Clone()
	plant:ScaleTo(template:GetScale() * herb.scale * def.giantScale)
	plant:PivotTo(CFrame.new(spot) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	plant.Parent = site

	-- the treasure orb's prompt and label become the herb's
	local prompt = beacon:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt
	local label = beacon:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel?
	prompt.ActionText = "Gather"
	prompt.ObjectText = herb.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F -- gathering is F everywhere, like herb beds
	prompt.HoldDuration = def.gatherSeconds
	prompt.Enabled = false
	if label then
		label.Text = `{herb.name}\nGuarded by the {guardianDef.name}`
	end
	site.Parent = wilds

	local guardian = EnemyService.spawn(def.guardian, spot + Vector3.new(8, 0, 0), nil, false)
	local function unguard()
		if run.ended then
			return
		end
		prompt.Enabled = true
		if label then
			label.Text = herb.name
		end
		run.announce(`The {guardianDef.name} has fallen! The {herb.name} is free to gather.`)
	end
	local humanoid = guardian and guardian:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(unguard)
	else
		unguard()
	end

	prompt.Triggered:Connect(function(player)
		local data = PlayerData.get(player)
		if run.ended or not data then
			return
		end
		data.seeds[herbId] = (data.seeds[herbId] or 0) + def.seeds
		Inventory.grant(player, herbId, 1, spot) -- also pushes state
		Cultivation.markActive(player)
		run.announce(`{player.DisplayName} gathered the {herb.name}!`)
		run.finish("resolved")
	end)

	run.onEnd(function(reason)
		site:Destroy()
		local h = guardian and guardian:FindFirstChildOfClass("Humanoid")
		if reason ~= "resolved" and h and h.Health > 0 then
			h.Health = 0 -- it dies through EnemyService, which tidies it away
		end
		if reason == "expired" then
			run.announce(`The {herb.name} withered back into the earth, unclaimed.`)
		end
	end)

	run.locate(spot)
	run.announce(
		`An auspicious omen! A {herb.name} has ripened in the wilds to the {run.direction(spot)}, guarded by the {guardianDef.name}. Follow the pillar of light.`
	)
	return true
end

return GuardedHerb
