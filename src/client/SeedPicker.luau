--!strict
-- Choose which seed to plant on a plot. Only seeds for the plot's soil are listed
-- (Herbs.Order); picking one closes the window and hands the herb id back, so the
-- caller (Planting) can start planting it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.State)

local SeedPicker = {}

local window: Frame

local function timeLabel(seconds: number): string
	if seconds >= 3600 then
		local hours = seconds / 3600
		return if hours == math.floor(hours) then `{hours}h` else string.format("%.1fh", hours)
	end
	if seconds < 60 then
		return `{seconds}s`
	end
	return `{math.floor(seconds / 60)} min`
end

function SeedPicker.growLabel(id: string): string
	local herb = Herbs.Defs[id]
	local text = `grows in {timeLabel(herb.growSeconds)}`
	if herb.regrowSeconds then
		text ..= `, regrows every {timeLabel(herb.regrowSeconds)}`
	end
	return text
end

function SeedPicker.open(soil: string, onPick: (herbId: string) -> ())
	local rows: { ListWindow.Row } = {}
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		local count = State.current.seeds[id] or 0
		if herb and herb.soil == soil and count > 0 then
			table.insert(rows, {
				color = herb.color,
				name = herb.name,
				detail = `{herb.rarity} · {SeedPicker.growLabel(id)}`,
				count = count,
				onPress = function()
					Menus.close(window)
					onPick(id)
				end,
			})
		end
	end
	if #rows == 0 then
		local info = (Herbs.Soils :: any)[soil]
		local hint = if info then `{info.hint} ` else ""
		Hud.toast(`{hint}Buy seeds from the Herbalist at the Spirit Market.`)
		return
	end
	local info = (Herbs.Soils :: any)[soil];
	(window:FindFirstChild("Title") :: TextLabel).Text = if info then `Plant in the {info.name}` else "Plant a Seed"
	ListWindow.fill(window, "SeedTemplate", "PlantButton", rows)
	Menus.open(window)
end

function SeedPicker.isOpen(): boolean
	return window.Visible
end

function SeedPicker.init(gui: ScreenGui)
	window = gui:FindFirstChild("SeedPicker") :: Frame
	Menus.register(window)
	ListWindow.bindClose(window)
end

return SeedPicker
