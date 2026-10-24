--!strict
-- World event kind: auspicious clouds gather around a sealed relic (a technique
-- manual or an ancient sword) at a random spot in the wilds. Meditating inside
-- the ring multiplies passive cultivation (Meditation.addSite). `condenseSeconds`
-- before the end the clouds pour into the relic and unseal it; the first to claim
-- it learns the technique the relic names, or another from the def's pool they
-- don't know yet, or Spirit Stones if they know them all; that ends the event.
-- A manual whose weapon Dao they lack is kept until they have it (Progression).
-- The clouds are drawn by clients (WorldEventFX) from the event's published
-- position; the relic is a server clone of
-- ReplicatedStorage.Effects.AuspiciousClouds.Relics.<def.relic>, whose
-- ClaimPrompt starts disabled.
-- Def settings: radius, meditation, condenseSeconds, relic, techniques, stones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Cultivation = require(script.Parent.Parent.Cultivation)
local Meditation = require(script.Parent.Parent.Meditation)
local PlayerData = require(script.Parent.Parent.PlayerData)
local Progression = require(script.Parent.Parent.Progression)
local Treasures = require(script.Parent.Parent.Treasures)
local Analytics = require(script.Parent.Parent.Analytics)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent
local wilds = workspace:WaitForChild("Wilds")

local AuspiciousClouds = {}

function AuspiciousClouds.start(run: any): boolean
	local def = run.def
	local techniqueId: string = def.techniques[math.random(#def.techniques)]
	local technique = Techniques.Defs[techniqueId]
	local effects = ReplicatedStorage.Effects:FindFirstChild("AuspiciousClouds")
	local relics = effects and effects:FindFirstChild("Relics")
	local template = relics and relics:FindFirstChild(def.relic) :: Model?
	local spot = Treasures.randomSpot()
	if not (technique and template and spot) then
		return false
	end
	local relicName = if def.relic == "Sword" then `{technique.name} sword inheritance` else `{technique.name} manual`

	local relic = template:Clone()
	relic.Name = def.id
	relic:PivotTo(CFrame.new(spot) * template:GetPivot().Rotation)
	local prompt = relic:FindFirstChild("ClaimPrompt", true) :: ProximityPrompt
	prompt.ObjectText = relicName
	prompt.Enabled = false
	local label = relic:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel?
	if label then
		label.Text = `{relicName}\nSealed by the clouds`
	end
	relic.Parent = wilds

	prompt.Triggered:Connect(function(player)
		local data = PlayerData.get(player)
		if run.ended or not data then
			return
		end
		local function has(id: string): boolean
			return data.techniques.owned[id] ~= nil or data.techniques.manuals[id] == true
		end
		local learn = if has(techniqueId) then nil else techniqueId
		for _, id in def.techniques do
			if not learn and not has(id) then
				learn = id
			end
		end
		if learn then
			Progression.grantManual(player, learn)
		elseif (def.stones or 0) > 0 then
			data.stones += def.stones
			Analytics.stones(player, "source", def.stones, data.stones, "Gameplay", "AuspiciousRelic")
			effectRemote:FireClient(player, "stones", relic:GetPivot().Position, def.stones)
			Cultivation.notify(player, `You studied the {relicName}: +{def.stones} Spirit Stones`)
		end
		Cultivation.markActive(player)
		Cultivation.pushState(player)
		run.announce(`{player.DisplayName} claimed the {relicName} from the {def.name}!`)
		run.finish("resolved")
	end)

	local close = Meditation.addSite(spot, def.radius, def.meditation, `in the {def.name}`)
	task.delay(math.max(0, def.minutes * 60 - def.condenseSeconds), function()
		if run.ended then
			return
		end
		prompt.Enabled = true
		if label then
			label.Text = relicName
		end
		run.announce(`The {def.name} pour into the {relicName} and its seal breaks! The first to claim it keeps it.`)
	end)

	run.onEnd(function(reason)
		close()
		relic:Destroy()
		if reason == "expired" then
			run.announce(`The {def.name} disperse, and the {relicName} goes with them.`)
		end
	end)

	run.locate(spot)
	run.announce(
		`{def.name} gather over the wilds to the {run.direction(spot)}, around a sealed {relicName}! Meditate within their ring to cultivate far faster until the seal breaks.`
	)
	return true
end

return AuspiciousClouds