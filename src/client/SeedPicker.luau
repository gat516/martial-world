--!strict
-- Choose which seed to plant on a plot (Hud.SeedPicker). Only seeds for the plot's
-- soil are listed (Herbs.Order), each as a seed packet tile (Codex C1 `seed_packet`):
-- the herb's art, its rarity gem, how many seeds you hold, its name and grow time.
-- Tapping a packet closes the window and hands the herb id back, so the caller
-- (Planting) can start planting it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local HerbArt = require(script.Parent.HerbArt)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local State = require(script.Parent.State)

local SeedPicker = {}

local window: Frame
local list: ScrollingFrame
local template: ImageButton

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

-- A short grow time for the packet ("2 min", "1.5h"; regrowing herbs say so).
local function packetTime(id: string): string
	local herb = Herbs.Defs[id]
	return timeLabel(herb.growSeconds) .. (if herb.regrowSeconds then ", regrows" else "")
end

function SeedPicker.open(soil: string, onPick: (herbId: string) -> ())
	local ids: { string } = {}
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		if herb and herb.soil == soil and (State.current.seeds[id] or 0) > 0 then
			table.insert(ids, id)
		end
	end
	local info = (Herbs.Soils :: any)[soil]
	if #ids == 0 then
		local hint = if info then `{info.hint} ` else ""
		Hud.toast(`{hint}Buy seeds from the Herbalist at the Spirit Market.`)
		return
	end
	(window:FindFirstChild("Title", true) :: TextLabel).Text = if info then `Plant in the {info.name}` else "Plant a Seed"
	for _, child in list:GetChildren() do
		if child.Name == "Packet" then
			child:Destroy()
		end
	end
	for i, id in ids do
		local herb = Herbs.Defs[id]
		local tile = template:Clone()
		tile.Name = "Packet"
		tile.LayoutOrder = i
		HerbArt.paint(tile:FindFirstChild("Swatch") :: Instance, id)
		HerbArt.gem(tile:FindFirstChild("Gem") :: ImageLabel, herb.rarity);
		(tile:FindFirstChild("NameLabel") :: TextLabel).Text = herb.name;
		(tile:FindFirstChild("Detail") :: TextLabel).Text = packetTime(id);
		(tile:FindFirstChild("CountLabel") :: TextLabel).Text = `×{State.current.seeds[id] or 0}`
		tile.Visible = true
		tile.Activated:Connect(function()
			Menus.close(window)
			onPick(id)
		end)
		tile.Parent = list
	end
	list.CanvasPosition = Vector2.zero
	Menus.open(window)
end

function SeedPicker.isOpen(): boolean
	return window.Visible
end

function SeedPicker.init(gui: ScreenGui)
	window = gui:FindFirstChild("SeedPicker") :: Frame
	list = window:FindFirstChild("List") :: ScrollingFrame
	template = list:FindFirstChild("SeedTemplate") :: ImageButton
	Menus.register(window)
	ListWindow.bindClose(window)
end

return SeedPicker
