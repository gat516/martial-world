--!strict
-- World event kind: auspicious clouds coil into a vortex over a random spot in
-- the wilds. Meditating inside its ring multiplies passive cultivation
-- (Meditation.addSite). `condenseSeconds` before the end the clouds condense into
-- a treasure at the eye under a pillar of light; the first to claim it keeps it,
-- which ends the event. The vortex itself is drawn by clients (WorldEventFX) from
-- the event's published position.
-- Def settings: radius, meditation, condenseSeconds, treasure, beaconScale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local Cultivation = require(script.Parent.Parent.Cultivation)
local Inventory = require(script.Parent.Parent.Inventory)
local Meditation = require(script.Parent.Parent.Meditation)
local Treasures = require(script.Parent.Parent.Treasures)

local beaconTemplate = (ServerStorage:WaitForChild("ItemTemplates") :: Folder):WaitForChild("WorldTreasure") :: Model
local wilds = workspace:WaitForChild("Wilds")

local CloudConvergence = {}

local function condense(run: any, spot: Vector3, item: Items.Item): Model
	local def = run.def
	local beacon = beaconTemplate:Clone()
	beacon.Name = def.id
	beacon:ScaleTo(def.beaconScale)
	-- keep the template's authored pivot rotation, or its pillar lies on its side
	beacon:PivotTo(CFrame.new(spot) * beaconTemplate:GetPivot().Rotation)
	for _, d in beacon:GetDescendants() do
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
	local prompt = beacon:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt
	prompt.ObjectText = item.name
	prompt.Triggered:Connect(function(player)
		if run.ended then
			return
		end
		Inventory.grant(player, item.id, 1, spot)
		Cultivation.markActive(player)
		run.announce(`{player.DisplayName} claimed the {item.name} from the cloud convergence!`)
		run.finish("resolved")
	end)
	beacon.Parent = wilds
	return beacon
end

function CloudConvergence.start(run: any): boolean
	local def = run.def
	local item = Items.Defs[def.treasure]
	local spot = Treasures.randomSpot()
	if not (item and spot) then
		return false
	end

	local close = Meditation.addSite(spot, def.radius, def.meditation, "in the cloud convergence")
	local beacon: Model? = nil
	task.delay(math.max(0, def.minutes * 60 - def.condenseSeconds), function()
		if run.ended then
			return
		end
		beacon = condense(run, spot, item)
		run.announce(`The clouds condense into a {item.name} at the eye of the convergence! The first to claim it keeps it.`)
	end)

	run.onEnd(function(reason)
		close()
		if beacon then
			beacon:Destroy()
		end
		if reason == "expired" then
			run.announce(`The auspicious clouds disperse, and the {item.name} fades with them.`)
		end
	end)

	run.locate(spot)
	run.announce(
		`Auspicious clouds descend on the wilds to the {run.direction(spot)}! Meditate within their ring to cultivate far faster, before they condense.`
	)
	return true
end

return CloudConvergence