--!strict
-- Finding things in the Inventory: the chip rail, the sort button and the search box.
--   Rail (Inventory.Rail): All, then one chip per section the tab has. On Weapons
--   and Arts a chip is a weapon class (its glyph in its colour, the same mark the
--   art badges, section headers and hotbar badges wear), or Any for universal arts;
--   on Pouch a kind of item (its first item's icon). A chip
--   shows that section alone; All (or the chosen chip again) shows every section.
--   Sort (Inventory.SortButton): a tap steps New -> Grade -> Alphabetical. New:
--   NEW things first, then the most recently first seen (Fresh.seenAt); Grade: best
--   tier first; Alphabetical: by name. The weapon in hand stays first in its row.
--   Search (Inventory.Search.Box): typed text narrows every tab to entries whose
--   name, class or kind, or grade contains it; the x clears it.
-- Sort and filter are kept per tab in the profile (PlayerData.inventoryView,
-- InventoryAction "view"), the same place NEW sightings live, so the Inventory
-- reopens as the player left it on any device. No saved choice: New, All. Profiles
-- from before the Weapons/Arts split saved one "Arsenal" view: both tabs start from it.
-- Search lasts while the window is open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(script.Parent.State)

local SELECTED = "rbxassetid://106949426671789" -- kit item_slot_selected
local PLAIN = "rbxassetid://76986126582220" -- kit item_slot
local ALL = "All"
local GOLD_TEXT = Color3.fromRGB(255, 226, 160)
local DIM_TEXT = Color3.fromRGB(214, 206, 190)
local SORTS = { "New", "Grade", "Alphabetical" }
local SORT_LABELS = { New = "Sort: New", Grade = "Sort: Grade", Alphabetical = "Sort: A–Z" }

export type Chip = { id: string, icon: string, color: Color3 }
type View = { sort: string, filter: string }

local InventoryFilter = {}

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction
local rail: ScrollingFrame
local chipTemplate: ImageButton
local sortButton: ImageButton
local box: TextBox
local clear: GuiButton
local tab = "Weapons"
local views: { [string]: View } = {
	Weapons = { sort = "New", filter = ALL },
	Arts = { sort = "New", filter = ALL },
	Pouch = { sort = "New", filter = ALL },
}
local loaded = false -- views taken from the profile once
local shown: { Chip } = {}
local shownKey = ""
local changed: () -> () = function() end

local function save()
	local view = views[tab]
	task.spawn(function()
		inventoryRemote:InvokeServer("view", tab, view.sort, view.filter)
	end)
end

local function paintChips()
	local view = views[tab]
	for _, child in rail:GetChildren() do
		if child:IsA("GuiButton") and child ~= chipTemplate then
			child:Destroy()
		end
	end
	for i, chipInfo in shown do
		local id = chipInfo.id
		local chip = chipTemplate:Clone()
		chip.Name = `Chip{id}`
		chip.LayoutOrder = i
		chip.Visible = true
		chip.Image = if id == view.filter then SELECTED else PLAIN
		local icon = chip:FindFirstChild("Icon") :: ImageLabel
		local label = chip:FindFirstChild("Label") :: TextLabel
		local text = chipInfo.icon == ""
		icon.Visible = not text
		label.Visible = text
		if text then
			label.Text = id
			label.TextColor3 = if id == view.filter then GOLD_TEXT else DIM_TEXT
		else
			icon.Image = chipInfo.icon
			icon.ImageColor3 = chipInfo.color
		end
		chip.Activated:Connect(function()
			view.filter = if view.filter == id then ALL else id
			save()
			paintChips()
			changed()
		end)
		chip.Parent = rail
	end
	(sortButton:FindFirstChild("Label") :: TextLabel).Text = SORT_LABELS[view.sort] or view.sort
end

-- The profile's saved views, the first time a snapshot carries them.
local function load(snapshot: any)
	if loaded or type(snapshot.inventoryView) ~= "table" then
		return
	end
	loaded = true
	local all = table.clone(snapshot.inventoryView)
	local old = all.Arsenal
	if type(old) == "table" then
		all.Weapons = all.Weapons or old
		all.Arts = all.Arts or old
	end
	for name, saved in all do
		local view = views[name]
		if view and type(saved) == "table" then
			view.sort = if table.find(SORTS, saved.sort) then saved.sort else view.sort
			view.filter = if type(saved.filter) == "string" then saved.filter else view.filter
		end
	end
end

-- Switch to a tab and offer its chips (sections in order; icon "" = text chip).
-- A saved filter whose section is gone shows All (and stays saved for later).
function InventoryFilter.update(name: string, chips: { Chip })
	tab = name
	local list: { Chip } = { { id = ALL, icon = "", color = DIM_TEXT } }
	local keys = { name, ALL }
	for _, chip in chips do
		table.insert(list, chip)
		table.insert(keys, chip.id)
	end
	local key = table.concat(keys, ",")
	shown = list
	if key ~= shownKey then
		shownKey = key
		rail.CanvasPosition = Vector2.zero
	end
	paintChips()
end

-- The chosen section on this tab ("All" for every one, or when it isn't there).
function InventoryFilter.filter(): string
	local filter = views[tab].filter
	for _, chip in shown do
		if chip.id == filter then
			return filter
		end
	end
	return ALL
end

function InventoryFilter.sort(): string
	return views[tab].sort
end

-- Whether any of these words contains the search text (no search: always).
function InventoryFilter.matches(words: { string }): boolean
	local query = string.lower(box.Text)
	query = string.gsub(query, "^%s+", "")
	query = string.gsub(query, "%s+$", "")
	if query == "" then
		return true
	end
	for _, word in words do
		if string.find(string.lower(word), query, 1, true) then
			return true
		end
	end
	return false
end

function InventoryFilter.searching(): boolean
	return string.find(box.Text, "%S") ~= nil
end

function InventoryFilter.clearSearch()
	box.Text = ""
end

function InventoryFilter.init(window: Frame, onChange: () -> ())
	changed = onChange
	rail = window:FindFirstChild("Rail") :: ScrollingFrame
	chipTemplate = rail:FindFirstChild("ChipTemplate") :: ImageButton
	sortButton = window:FindFirstChild("SortButton") :: ImageButton
	local search = window:FindFirstChild("Search") :: GuiObject
	box = search:FindFirstChild("Box") :: TextBox
	clear = search:FindFirstChild("Clear") :: GuiButton
	clear.Visible = false
	box:GetPropertyChangedSignal("Text"):Connect(function()
		clear.Visible = box.Text ~= ""
		changed()
	end)
	clear.Activated:Connect(function()
		box.Text = ""
	end)
	sortButton.Activated:Connect(function()
		local view = views[tab]
		local at = table.find(SORTS, view.sort) or 0
		view.sort = SORTS[at % #SORTS + 1]
		save()
		paintChips()
		changed()
	end)
	State.onChanged(function(snapshot: any)
		load(snapshot)
	end)
end

return InventoryFilter
