--!strict
-- Choose which seed to plant in an empty bed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local State = require(script.Parent.State)

local gardenRemote = ReplicatedStorage.Remotes.GardenAction :: RemoteFunction

local SeedPicker = {}

local window: Frame

local function growLabel(seconds: number): string
	if seconds >= 3600 then
		return `{seconds / 3600}h`
	end
	return `{math.floor(seconds / 60)} min`
end

function SeedPicker.open(plotId: string)
	local rows: { ListWindow.Row } = {}
	for _, id in Herbs.Order do
		local count = State.current.seeds[id] or 0
		if count > 0 then
			local herb = Herbs.Defs[id]
			table.insert(rows, {
				color = herb.color,
				name = herb.name,
				detail = `{herb.rarity} · grows in {growLabel(herb.growSeconds)}`,
				count = count,
				onPress = function()
					window.Visible = false
					local _, message = gardenRemote:InvokeServer("plant", plotId, id)
					if message then
						Hud.toast(message)
					end
				end,
			})
		end
	end
	if #rows == 0 then
		Hud.toast("No seeds left. Harvest grown herbs to get more.")
		return
	end
	ListWindow.fill(window, "SeedTemplate", "PlantButton", rows)
	window.Visible = true
end

function SeedPicker.init(gui: ScreenGui)
	window = gui:FindFirstChild("SeedPicker") :: Frame
	ListWindow.bindClose(window)
end

return SeedPicker
