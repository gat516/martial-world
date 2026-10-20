--!strict
-- The Inventory window (the Inventory tile, or ` on a keyboard): a grid of
-- everything you carry (Pouch) or know (Arts), and a detail pane for the chosen
-- one. Items can be used or held out; arts added to or taken off the hotbar.
-- Anything in the grid can be dragged onto the hotbar (HotbarView).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage.Shared.Items)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local HotbarView = require(script.Parent.HotbarView)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Platform = require(script.Parent.Platform)
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction

type Tab = "Pouch" | "Arts"

-- tab art: gold for the open tab, lacquer for the other (art/ui/assets.json)
local TAB_ON = { image = "rbxassetid://124847805310931", text = Color3.fromRGB(255, 244, 214) }
local TAB_OFF = { image = "rbxassetid://88447362782150", text = Color3.fromRGB(170, 190, 184) }
local EMPTY: { [Tab]: string } = {
	Pouch = "Your pouch is empty. Harvest herbs, hunt spirit beasts for their cores, and watch the skies for heavenly treasures.",
	Arts = "You know no arts yet. Beasts in the wilds sometimes drop manuals.",
}

local Inventory = {}

local window: Frame
local grid: ScrollingFrame
local cellTemplate: GuiButton
local info: ScrollingFrame
local primary: ImageButton
local secondary: ImageButton
local tabButtons: { [Tab]: ImageButton } = {}
local tab: Tab = "Pouch"
local selected: string? = nil

local function invoke(...: any)
	local ok, message = inventoryRemote:InvokeServer(...)
	if message and (not ok or ... == "use") then
		Hud.toast(message)
	end
end

local function entries(): { string }
	local list = {}
	local s = State.current
	if tab == "Pouch" then
		for _, id in Items.Order do
			if Items.count(s, id) > 0 then
				table.insert(list, id)
			end
		end
	else
		for _, id in Techniques.Order do
			if s.techniques.owned[id] then
				table.insert(list, id)
			end
		end
	end
	return list
end

local function label(name: string): TextLabel
	return info:FindFirstChild(name) :: TextLabel
end

-- The text on an art button (its Label child).
local function caption(button: GuiObject): TextLabel
	return button:FindFirstChild("Label") :: TextLabel
end

local function renderDetail()
	local s = State.current
	local preview = info:FindFirstChild("Preview") :: TextButton
	local item = selected and Items.Defs[selected]
	local technique = selected and Techniques.Defs[selected]
	local owned = technique and s.techniques.owned[technique.id]
	if item and Items.count(s, item.id) <= 0 then
		item = nil
	end
	local any = item ~= nil or owned ~= nil
	label("Hint").Visible = not any
	primary.Visible = any
	secondary.Visible = item ~= nil
	SlotArt.paint(preview, if any then selected else nil, nil, "")
	preview.Visible = any
	if item then
		local count = Items.count(s, item.id)
		label("NameLabel").Text = item.name
		label("KindLabel").Text = `{item.rarity} {string.lower(Items.CategoryNames[item.category])} · x{count}`
		label("KindLabel").TextColor3 = Items.rarityColor(item)
		label("Blurb").Text = item.blurb
		label("Lore").Text = item.lore or ""
		caption(primary).Text = if item.category == "Herb" then "Eat" else "Use"
		local held = HotbarView.held()
		caption(secondary).Text = if held and held:GetAttribute("ItemId") == item.id then "Put away" else "Hold"
	elseif technique and owned then
		local xp = if owned.level >= Techniques.MAX_LEVEL
			then "max level"
			else `{owned.xp}/{Techniques.xpToNext(owned.level)} xp`
		label("NameLabel").Text = technique.name
		label("KindLabel").Text = `Technique · Lv {owned.level} · {xp} · {technique.cooldown}s`
		label("KindLabel").TextColor3 = technique.color:Lerp(Color3.new(1, 1, 1), 0.3)
		label("Blurb").Text = technique.blurb
		label("Lore").Text = ""
		caption(primary).Text = if table.find(s.hotbar, technique.id) then "Remove from hotbar" else "Add to hotbar"
	else
		label("NameLabel").Text = ""
		label("KindLabel").Text = ""
		label("Blurb").Text = ""
		label("Lore").Text = ""
	end
end

local function render()
	for name, button in tabButtons do
		local style = if name == tab then TAB_ON else TAB_OFF
		button.Image = style.image
		caption(button).TextColor3 = style.text
	end
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") and child ~= cellTemplate then
			child:Destroy()
		end
	end
	local s = State.current
	local list = entries()
	for i, id in list do
		local cell = cellTemplate:Clone()
		cell.Name = id
		cell.LayoutOrder = i
		cell.Visible = true
		if Techniques.Defs[id] then
			SlotArt.paint(cell, id, nil, `Lv {s.techniques.owned[id].level}`)
		else
			SlotArt.paint(cell, id, Items.count(s, id))
		end
		local onBar = table.find(s.hotbar, id)
		local key = cell:FindFirstChild("KeyLabel") :: TextLabel
		key.Visible = onBar ~= nil and not Platform.isTouch() -- key hints are for keyboards
		key.Text = if onBar then tostring(onBar) else ""
		local halo = cell:FindFirstChild("Halo") :: GuiObject
		halo.Visible = id == selected
		cell.Activated:Connect(function()
			if not HotbarView.justDragged() then
				selected = id
				render()
			end
		end)
		HotbarView.draggable(cell, function()
			return id
		end)
		cell.Parent = grid
	end
	local empty = window:FindFirstChild("Empty") :: TextLabel
	empty.Text = EMPTY[tab]
	empty.Visible = #list == 0
	renderDetail()
end

local function onPrimary()
	local id = selected
	if not id then
		return
	end
	if Items.Defs[id] then
		invoke("use", id)
	elseif Techniques.Defs[id] then
		local at = table.find(State.current.hotbar, id)
		if at then
			invoke("clear", at)
		else
			invoke("slot", id)
		end
	end
end

local function onSecondary()
	if selected and Items.Defs[selected] then
		HotbarView.toggleHold(selected)
		task.defer(renderDetail)
	end
end

-- On touch the window sits high so the hotbar (drawn over it) stays a drop target.
local function layout()
	if Platform.isTouch() then
		window.AnchorPoint = Vector2.new(0.5, 0)
		window.Position = UDim2.new(0.5, 0, 0, 8)
		window.Size = UDim2.new(0.94, 0, 1, -70)
	else
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Position = UDim2.fromScale(0.5, 0.48)
		window.Size = UDim2.fromScale(0.94, 0.8)
	end
end

local function setOpen(open: boolean)
	if open then
		layout()
		render()
		Menus.open(window)
	else
		Menus.close(window)
	end
end

function Inventory.init(gui: ScreenGui)
	window = gui:FindFirstChild("Inventory") :: Frame
	grid = window:FindFirstChild("Grid") :: ScrollingFrame
	cellTemplate = grid:FindFirstChild("CellTemplate") :: GuiButton
	local detail = window:FindFirstChild("Detail") :: Frame
	info = detail:FindFirstChild("Info") :: ScrollingFrame
	local actions = detail:FindFirstChild("Actions") :: Frame
	primary = actions:FindFirstChild("Primary") :: ImageButton
	secondary = actions:FindFirstChild("Secondary") :: ImageButton
	primary.Activated:Connect(onPrimary)
	secondary.Activated:Connect(onSecondary)
	Menus.register(window, { keepHotbar = true, coversTiles = true })
	ListWindow.bindClose(window)
	local tabs = window:FindFirstChild("Tabs") :: Frame
	for _, name: Tab in { "Pouch" :: Tab, "Arts" :: Tab } do
		local button = tabs:FindFirstChild(`{name}Tab`) :: ImageButton
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			selected = nil
			render()
		end)
	end
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("InventoryButton") :: TextButton
	button.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Backquote then
			setOpen(not window.Visible)
		end
	end)
	State.onChanged(function()
		if window.Visible then
			render()
		end
	end)
end

return Inventory
