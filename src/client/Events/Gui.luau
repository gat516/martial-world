--!strict
-- The Events screen (StarterGui.Events, assets/Events.rbxmx, built by
-- tools/events_ui_build.luau): world-event heralds and trackers, tribulation
-- cards, rift cards and the leaderboard window share it. Layout and art sources:
-- docs/ui/world-events.md and docs/ui/leaderboards.md.
--
-- The screen is laid out twice at a baseline (Canvas.Desktop at 1920x1080,
-- Canvas.Phone at 844x390) as empty slots; the art lives once in Templates,
-- sized in scale so a clone fills whichever slot it goes in. UiScale fits the
-- canvas, and the layout is picked once per session.
--
-- The top-centre herald (event scroll or tribulation ribbon) shows one message
-- at a time through Gui.herald; trackers step aside while one is up.

local Players = game:GetService("Players")

local Motion = require(script.Parent.Parent.Motion)
local UiScale = require(script.Parent.Parent.UiScale)

local Gui = {}

-- Text sizes for labels that size themselves (AutomaticSize), per layout, in
-- baseline pixels; the phone has its own floor.
local TEXT = {
	Desktop = { tracker = 20 },
	Phone = { tracker = 13 },
}

local screen: ScreenGui? = nil
local layout: Frame
local templates: Frame
local layoutName = "Desktop"
local heraldBusy = false
local heraldQueue: { () -> () } = {}

function Gui.init(): ScreenGui
	if screen then
		return screen
	end
	local found = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Events") :: ScreenGui
	screen = found
	local canvas = found:FindFirstChild("Canvas") :: Frame
	UiScale.fit(canvas)
	layoutName = if UiScale.isPhone() then "Phone" else "Desktop"
	for _, name in { "Desktop", "Phone" } do
		(canvas:FindFirstChild(name) :: Frame).Visible = name == layoutName
	end
	layout = canvas:FindFirstChild(layoutName) :: Frame
	templates = found:FindFirstChild("Templates") :: Frame
	return found
end

function Gui.isPhone(): boolean
	return layoutName == "Phone"
end

function Gui.textSize(key: string): number
	return TEXT[layoutName][key]
end

-- The active layout's slot (Herald, Ribbon, Tracker, Counter, Chips, Decree, Rift, Board).
function Gui.slot(name: string): Frame
	Gui.init()
	return layout:FindFirstChild(name) :: Frame
end

-- A fresh copy of a template (EventScroll, Ribbon, TrackerEntry, EdgeChip,
-- EventPin, Decree, StrikeCounter, RiftCard, RiftTag, Board, Row, RowYou).
function Gui.clone(name: string): any
	Gui.init()
	return (templates:FindFirstChild(name) :: Instance):Clone()
end

-- Clone a template into a slot, filling it.
function Gui.place(template: string, slot: string): any
	local inst = Gui.clone(template)
	inst.Parent = Gui.slot(slot)
	return inst
end

local function nextHerald()
	local show = table.remove(heraldQueue, 1)
	if not show then
		heraldBusy = false
		return
	end
	heraldBusy = true
	task.spawn(function()
		local ok, err = pcall(show)
		if not ok then
			warn(`Events herald: {err}`)
		end
		nextHerald()
	end)
end

-- Queue a top-centre message. show runs (and may yield) while it owns the
-- herald row; the next one starts when it returns. World-event trackers step
-- aside while one is up (Gui.heraldActive).
function Gui.herald(show: () -> ())
	table.insert(heraldQueue, show)
	if not heraldBusy then
		nextHerald()
	end
end

function Gui.heraldActive(): boolean
	return heraldBusy
end

Gui.fadeIn = Motion.fadeIn
Gui.fadeOut = Motion.fadeOut

return Gui
