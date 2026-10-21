--!strict
-- Sort and filter for the Inventory's Arts and Weapons tabs: one square button at
-- the end of the tab row (Inventory.Tabs.SortButton) opens a small menu
-- (Inventory.SortMenu) of class chips over three sort pills. A tap applies at
-- once and the menu stays open; the button again, a tap outside
-- (SortCatcher) or a tab switch closes it. The button shows only once a tab
-- holds 3 or more entries, and turns gold wearing the class icon while a class
-- filter is on. Chips are offered only for classes the player actually has.
-- The choice is kept per tab for the session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Motion = require(script.Parent.Motion)
local SlotArt = require(script.Parent.SlotArt)

export type Tab = "Pouch" | "Arts" | "Weapons"

local GOLD = { image = "rbxassetid://124847805310931", text = Color3.fromRGB(255, 244, 214) }
local LACQUER = { image = "rbxassetid://88447362782150", text = Color3.fromRGB(170, 190, 184) }
local SORT_ICON = "rbxassetid://91875091957000"
local ALL, ANY = "All", "Any"
local MIN_ENTRIES = 3 -- fewer than this and there is nothing worth sorting

local SORTS: { [string]: { string } } = {
	Arts = { "Level", "Name", "Bottleneck" },
	Weapons = { "Grade", "Class", "Name" },
}
local PHRASE = {
	Level = "highest level first",
	Name = "by name",
	Bottleneck = "bottlenecks first",
	Grade = "best grade first",
	Class = "by class",
}

local InventoryFilter = {}

local views: { [string]: { filter: string, sort: string } } = {
	Arts = { filter = ALL, sort = "Level" },
	Weapons = { filter = ALL, sort = "Grade" },
}

local button: ImageButton
local menu: GuiObject
local catcher: GuiButton
local chips: Frame
local chipTemplate: ImageButton
local pills: Frame
local pillTemplate: ImageButton
local caption: TextLabel
local current: Tab = "Pouch"
local present: { string } = {} -- chip ids offered on the current tab
local changed: () -> () = function() end

local function label(b: GuiObject): TextLabel
	return b:FindFirstChild("Label") :: TextLabel
end

local function icon(b: GuiObject): ImageLabel
	return b:FindFirstChild("Icon") :: ImageLabel
end

local function paint(b: ImageButton, on: boolean)
	local style = if on then GOLD else LACQUER
	b.Image = style.image
	label(b).TextColor3 = style.text
end

-- The class a grid entry belongs to: an art's weapon ("Any" for universal arts),
-- a weapon's class (Bare Fists are "Fist").
function InventoryFilter.classOf(tab: Tab, id: string): string
	if tab == "Arts" then
		local def = Techniques.Defs[id]
		return if def then def.weapon or ANY else ANY
	end
	return Weapons.classOf(id)
end

-- The chosen class on this tab ("All" when filtering is off or not offered).
function InventoryFilter.filter(tab: Tab): string
	local view = views[tab]
	return if view and button.Visible and current == tab then view.filter else ALL
end

function InventoryFilter.sort(tab: Tab): string
	local view = views[tab]
	return if view then view.sort else ""
end

local function chipName(id: string): string
	if id == ALL then
		return "All"
	elseif id == ANY then
		return "Universal"
	end
	return Weapons.Classes[id] and Weapons.Classes[id].name or id
end

local function paintMenu()
	local view = views[current]
	if not view then
		return
	end
	for _, child in chips:GetChildren() do
		if child:IsA("GuiButton") and child ~= chipTemplate then
			child:Destroy()
		end
	end
	for i, id in present do
		local chip = chipTemplate:Clone()
		chip.Name = `Chip{id}`
		chip.LayoutOrder = i
		chip.Visible = true
		local text = id == ALL or id == ANY
		label(chip).Visible = text
		label(chip).Text = if id == ALL then "All" elseif id == ANY then "Any" else ""
		icon(chip).Visible = not text
		icon(chip).Image = if text then "" else SlotArt.classIcon(id)
		paint(chip, view.filter == id)
		chip.Activated:Connect(function()
			view.filter = id
			paintMenu()
			changed()
		end)
		chip.Parent = chips
	end
	for _, child in pills:GetChildren() do
		if child:IsA("GuiButton") and child ~= pillTemplate then
			child:Destroy()
		end
	end
	for i, mode in SORTS[current] do
		local pill = pillTemplate:Clone()
		pill.Name = `Sort{mode}`
		pill.LayoutOrder = i
		pill.Visible = true
		label(pill).Text = mode
		paint(pill, view.sort == mode)
		pill.Activated:Connect(function()
			view.sort = mode
			paintMenu()
			changed()
		end)
		pill.Parent = pills
	end
	local noun = if current == "Arts" then "arts" else "weapons"
	caption.Text = if view.filter == ALL
		then `All {noun}, {PHRASE[view.sort]}`
		else `{chipName(view.filter)} {noun}, {PHRASE[view.sort]}`
end

local function paintButton()
	local view = views[current]
	local filtered = view ~= nil and view.filter ~= ALL
	button.Image = if filtered then GOLD.image else LACQUER.image
	icon(button).Image = if filtered and view.filter ~= ANY then SlotArt.classIcon(view.filter) else SORT_ICON
end

function InventoryFilter.close()
	if menu.Visible then
		Motion.close(menu)
	end
	catcher.Visible = false
end

local function open()
	paintMenu()
	catcher.Visible = true
	Motion.open(menu)
end

-- Called on every Inventory render with the tab shown and every class it holds
-- (owned entries, hotbar ones included) and how many entries that is. Shows or
-- hides the button and drops a filter whose class is gone.
function InventoryFilter.update(tab: Tab, classes: { [string]: boolean }, count: number)
	if tab ~= current then
		InventoryFilter.close()
		current = tab
	end
	local view = views[tab]
	button.Visible = view ~= nil and count >= MIN_ENTRIES
	if not button.Visible then
		InventoryFilter.close()
		return
	end
	present = { ALL }
	if tab == "Arts" and classes[ANY] then
		table.insert(present, ANY)
	end
	for _, id in Weapons.ClassOrder do
		if classes[id] then
			table.insert(present, id)
		end
	end
	if not table.find(present, view.filter) then
		view.filter = ALL
	end
	paintButton()
	if menu.Visible then
		paintMenu()
	end
end

local function nameOf(tab: Tab, id: string): string
	if tab == "Arts" then
		local def = Techniques.Defs[id]
		return if def then def.name else id
	end
	return SlotArt.weaponName(id)
end

local function indexIn(list: { string }, id: string): number
	return table.find(list, id) or math.huge
end

-- Sort a tab's entries in place. level(id) and stuck(id) describe an art (its
-- level and whether it is at a bottleneck); pinned ids keep their order at the
-- front (the equipped weapon, then Bare Fists).
function InventoryFilter.order(
	tab: Tab,
	list: { string },
	level: (string) -> number,
	stuck: (string) -> boolean,
	pinned: { string }?
)
	local mode = InventoryFilter.sort(tab)
	local function rank(id: string): number
		return if pinned then indexIn(pinned, id) else math.huge
	end
	local function gradeOf(id: string): number
		local def = Weapons.Defs[id]
		local grade = def and Weapons.Grades[def.grade]
		return if grade then grade.order else 0
	end
	local base = if tab == "Arts" then Techniques.Order else Weapons.Order
	table.sort(list, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if mode == "Name" then
			return nameOf(tab, a) < nameOf(tab, b)
		end
		if tab == "Arts" then
			if mode == "Bottleneck" and stuck(a) ~= stuck(b) then
				return stuck(a)
			end
			if level(a) ~= level(b) then
				return level(a) > level(b)
			end
		else
			local ca = indexIn(Weapons.ClassOrder, Weapons.classOf(a))
			local cb = indexIn(Weapons.ClassOrder, Weapons.classOf(b))
			if mode == "Class" and ca ~= cb then
				return ca < cb
			end
			if gradeOf(a) ~= gradeOf(b) then
				return gradeOf(a) > gradeOf(b)
			end
			if ca ~= cb then
				return ca < cb
			end
		end
		return indexIn(base, a) < indexIn(base, b)
	end)
end

function InventoryFilter.init(window: Frame, onChange: () -> ())
	changed = onChange
	button = (window:FindFirstChild("Tabs") :: Frame):FindFirstChild("SortButton") :: ImageButton
	menu = window:FindFirstChild("SortMenu") :: GuiObject
	catcher = window:FindFirstChild("SortCatcher") :: GuiButton
	chips = menu:FindFirstChild("Classes") :: Frame
	chipTemplate = chips:FindFirstChild("ChipTemplate") :: ImageButton
	pills = menu:FindFirstChild("Sorts") :: Frame
	pillTemplate = pills:FindFirstChild("SortTemplate") :: ImageButton
	caption = menu:FindFirstChild("Caption") :: TextLabel
	button.Visible = false
	button.Activated:Connect(function()
		if menu.Visible and catcher.Visible then
			InventoryFilter.close()
		else
			open()
		end
	end)
	catcher.Activated:Connect(InventoryFilter.close)
	window:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.Visible then
			menu.Visible = false
			catcher.Visible = false
		end
	end)
end

return InventoryFilter
