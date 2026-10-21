--!strict
-- The Inventory window (the Inventory tile, or ` on a keyboard): a grid of
-- items you carry (Pouch), arts you know that aren't on the hotbar (Arts), or
-- weapons you own (Weapons), and a detail pane for the chosen one. Items can be
-- used or held out; arts added to the hotbar; weapons equipped (bare fists first:
-- choosing them puts the weapon away). Arts that need a weapon class wear its
-- badge. With no weapon chosen, the Weapons pane lists every class's Dao
-- comprehension; a chosen weapon shows its own class's.
-- A chosen art shows its level and XP bar. At a bottleneck (Techniques.bottleneck,
-- XP full at level 3, 6 or 9) the bar turns cinnabar, the cost rows (insight and
-- Spirit Stones, Pacing.Comprehension) show what you have, and Comprehend sits
-- beside the hotbar button; it reads the reason ("Meditate first") while it can't.
-- Items and arts in the grid can be dragged onto the hotbar (HotbarView); while
-- the window is open, tapping a hotbar slot shows that slot here instead.
-- Arts and Weapons sort and filter by class through InventoryFilter; a class
-- filter on Arts lists that class's hotbar arts too (slot number on PC).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage.Shared.Items)
local Comprehension = require(ReplicatedStorage.Shared.Pacing).Comprehension
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local HotbarView = require(script.Parent.HotbarView)
local Hud = require(script.Parent.Hud)
local InventoryFilter = require(script.Parent.InventoryFilter)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction

type Tab = "Pouch" | "Arts" | "Weapons"
type Dao = { level: number, xp: number }

-- tab art: gold for the open tab, lacquer for the other (art/ui/assets.json)
local TAB_ON = { image = "rbxassetid://124847805310931", text = Color3.fromRGB(255, 244, 214) }
local TAB_OFF = { image = "rbxassetid://88447362782150", text = Color3.fromRGB(170, 190, 184) }
local DAO_NAME = Color3.fromRGB(236, 242, 236)
local DAO_NAME_EQUIPPED = Color3.fromRGB(255, 226, 160)
local MARK_POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- comprehension (button art from art/ui/assets.json)
local BUTTON_JADE = "rbxassetid://124219422183170"
local BUTTON_LACQUER = "rbxassetid://88447362782150"
local BOTTLENECK = Color3.fromRGB(255, 150, 110)
local COST_SHORT = Color3.fromRGB(255, 130, 110)
local COST_OK = Color3.fromRGB(240, 210, 140)
local BAR_GOLD = ColorSequence.new(Color3.fromRGB(246, 214, 140), Color3.fromRGB(178, 124, 52))
local BAR_CINNABAR = ColorSequence.new(Color3.fromRGB(240, 120, 84), Color3.fromRGB(150, 46, 32))
local STONE_ICON = "rbxassetid://112328127073930"
local INSIGHT_ICON = "rbxassetid://92675446701433"
local TIER_NAMES = { "Tier I", "Tier II", "Tier III", "Mastery" }
local FIST_BLURB = "Palm and fist, always at hand. Choosing them puts your weapon away."
local EMPTY: { [Tab]: string } = {
	Pouch = "Your pouch is empty. Harvest herbs, hunt spirit beasts for their cores, and watch the skies for heavenly treasures.",
	Arts = "You know no arts yet. Beasts in the wilds sometimes drop manuals.",
	Weapons = "",
}

local Inventory = {}

local window: Frame
local grid: ScrollingFrame
local cellTemplate: GuiButton
local info: ScrollingFrame
local primary: ImageButton
local secondary: ImageButton
local tabButtons: { [Tab]: ImageButton } = {}
local daoList: Frame
local daoRows: { [string]: Frame } = {}
local tab: Tab = "Pouch"
local selected: string? = nil
local shownEquipped: string? = nil -- the equipped weapon at the last render, to pop its mark when it changes
local techniqueRow: Frame -- the chosen art's level and XP bar (a RowTemplate clone)
local costRows: { insight: Frame, stones: Frame }
local comprehendBlock: string? = nil -- why Comprehend can't run now (nil = it can)
local comprehending = false

local function weaponRemote(): RemoteFunction
	return (ReplicatedStorage.Remotes :: any).WeaponAction
end

local function invoke(...: any)
	local ok, message = inventoryRemote:InvokeServer(...)
	if message and (not ok or ... == "use") then
		Hud.toast(message)
	end
end

local function weaponState(): ({ [string]: number }, string, { [string]: Dao })
	local s = State.current :: any
	local weapons = s.weapons or {}
	return weapons.owned or {}, weapons.equipped or SlotArt.equipped(), s.dao or {}
end

-- The gate a technique is stuck at, or nil while its XP still flows.
local function gateOf(owned: State.Technique): { insight: number, stones: number }?
	if Techniques.bottleneck(owned.level) and owned.xp >= Techniques.xpToNext(owned.level) then
		return Comprehension.GATES[owned.level]
	end
	return nil
end

local function entries(): ({ string }, boolean)
	local s = State.current
	if tab == "Pouch" then
		InventoryFilter.update(tab, {}, 0)
		local list, hasOwned = {}, false
		for _, id in Items.Order do
			if Items.count(s, id) > 0 then
				hasOwned = true
				if not table.find(s.hotbar, id) then
					table.insert(list, id)
				end
			end
		end
		return list, hasOwned
	end
	-- Arts and Weapons: everything owned, then the tab's class filter and sort
	local all = {}
	local _, equipped = weaponState()
	if tab == "Weapons" then
		local owned = weaponState()
		all = { Weapons.FIST }
		for _, id in Weapons.Order do
			if (owned[id] or 0) > 0 then
				table.insert(all, id)
			end
		end
	else
		for _, id in Techniques.Order do
			if s.techniques.owned[id] then
				table.insert(all, id)
			end
		end
	end
	local classes = {}
	for _, id in all do
		classes[InventoryFilter.classOf(tab, id)] = true
	end
	InventoryFilter.update(tab, classes, #all)
	local filter = InventoryFilter.filter(tab)
	local list = {}
	for _, id in all do
		local onBar = tab == "Arts" and table.find(s.hotbar, id) ~= nil
		-- unfiltered, the Arts grid lists only what's off the hotbar; a class
		-- filter shows every art of that class, hotbar ones included
		if (filter == "All" and not onBar) or (filter ~= "All" and InventoryFilter.classOf(tab, id) == filter) then
			table.insert(list, id)
		end
	end
	local function level(id: string): number
		local known = s.techniques.owned[id]
		return if known then known.level else 0
	end
	local function stuck(id: string): boolean
		local known = s.techniques.owned[id]
		return known ~= nil and gateOf(known) ~= nil
	end
	local pinned = if tab == "Weapons" then { if equipped == "" then Weapons.FIST else equipped, Weapons.FIST } else nil
	InventoryFilter.order(tab, list, level, stuck, pinned)
	return list, #all > 0
end

local function label(name: string): TextLabel
	return info:FindFirstChild(name) :: TextLabel
end

-- The text on an art button (its Label child).
local function caption(button: GuiObject): TextLabel
	return button:FindFirstChild("Label") :: TextLabel
end

-- One Dao row: icon, "Sword Dao", "Lv 3 · 40/150" and the XP bar (eased).
local function paintDao(row: Frame, classId: string, dao: Dao, equipped: boolean, animate: boolean)
	local class = Weapons.Classes[classId]
	local level = dao.level or 0
	local name = row:FindFirstChild("NameLabel") :: TextLabel
	name.Text = class.dao
	name.TextColor3 = if equipped then DAO_NAME_EQUIPPED else DAO_NAME;
	(row:FindFirstChild("Icon") :: ImageLabel).Image = SlotArt.classIcon(classId)
	local fill = (row:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
	local share, text
	if level >= Weapons.MAX_LEVEL then
		share, text = 1, `Lv {level} · mastered`
	else
		local need = Weapons.xpToNext(level)
		share, text = math.clamp((dao.xp or 0) / need, 0, 1), `Lv {level} · {dao.xp or 0}/{need}`
	end
	(row:FindFirstChild("LevelLabel") :: TextLabel).Text = text
	local size = UDim2.fromScale(share, 1)
	if animate and fill.Size ~= size then
		Motion.ease(fill, { Size = size })
	else
		fill.Size = size
	end
end

-- The Dao rows: every class (only) or just one.
local function renderDao(only: string?)
	techniqueRow.Visible = false
	costRows.insight.Visible = false
	costRows.stones.Visible = false;
	(daoList:FindFirstChild("Header") :: GuiObject).Visible = true
	local _, equipped, dao = weaponState()
	local equippedClass = Weapons.classOf(equipped)
	local template = daoList:FindFirstChild("RowTemplate") :: Frame
	for i, classId in Weapons.ClassOrder do
		local row = daoRows[classId]
		local fresh = row == nil
		if not row then
			row = template:Clone()
			row.Name = classId
			row.LayoutOrder = i + 1
			row.Parent = daoList
			daoRows[classId] = row
		end
		local shown = only == nil or only == classId
		paintDao(row, classId, dao[classId] or { level = 0, xp = 0 }, classId == equippedClass, shown and row.Visible and not fresh)
		row.Visible = shown
	end
end

local function setDetailText(shown: boolean)
	for _, name in { "Preview", "Spacer", "NameLabel", "KindLabel", "Blurb", "Lore" } do
		(info:FindFirstChild(name) :: GuiObject).Visible = shown
	end
end

local function renderWeaponDetail()
	local owned, equipped = weaponState()
	local id = selected
	if id and id ~= Weapons.FIST and (owned[id] or 0) <= 0 then
		id = nil
	end
	secondary.Visible = false
	daoList.Visible = true
	label("Hint").Visible = false
	setDetailText(id ~= nil)
	if not id then
		primary.Visible = false
		renderDao(nil)
		return
	end
	local preview = info:FindFirstChild("Preview") :: TextButton
	SlotArt.paint(preview, id, nil, "")
	local isEquipped = id == equipped or (id == Weapons.FIST and equipped == "")
	local classId = Weapons.classOf(id)
	local def = Weapons.Defs[id]
	label("NameLabel").Text = SlotArt.weaponName(id)
	if def then
		local grade = Weapons.Grades[def.grade]
		local count = owned[id] or 0
		label("KindLabel").Text = `{grade and grade.name or def.grade} {Weapons.Classes[classId].noun}`
			.. (if count > 1 then ` · x{count}` else "")
			.. (if isEquipped then " · equipped" else "")
		label("Blurb").Text = def.blurb
	else
		label("KindLabel").Text = if isEquipped then "Bare hands · in use" else "Bare hands"
		label("Blurb").Text = FIST_BLURB
	end
	label("KindLabel").TextColor3 = SlotArt.weaponColor(id)
	label("Lore").Text = ""
	primary.Visible = not isEquipped or def ~= nil
	caption(primary).Text = if isEquipped then "Unequip" else "Equip"
	renderDao(classId)
end

local function stones(): number
	return (Players.LocalPlayer:GetAttribute("Stones") :: number?) or 0
end

local function paintCost(row: Frame, need: number, have: number)
	local text = row:FindFirstChild("LevelLabel") :: TextLabel
	text.Text = `{need} · you have {have}`
	text.TextColor3 = if have >= need then COST_OK else COST_SHORT
	row.Visible = true
end

-- The art's level row (tier, Lv, XP bar) and, at a bottleneck, its cost rows and
-- the Comprehend button (Secondary), which names what's missing while it can't.
local function renderTechnique(technique: any, owned: State.Technique, animate: boolean)
	local s = State.current
	local gate = gateOf(owned)
	daoList.Visible = true
	for _, row in daoRows do
		row.Visible = false
	end
	(daoList:FindFirstChild("Header") :: GuiObject).Visible = false
	techniqueRow.Visible = true
	local icon = techniqueRow:FindFirstChild("Icon") :: ImageLabel
	icon.Image = technique.icon
	icon.ImageColor3 = technique.color:Lerp(Color3.new(1, 1, 1), 0.35)
	local name = techniqueRow:FindFirstChild("NameLabel") :: TextLabel
	local level = techniqueRow:FindFirstChild("LevelLabel") :: TextLabel
	local fill = (techniqueRow:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame;
	(fill:FindFirstChild("UIGradient") :: UIGradient).Color = if gate then BAR_CINNABAR else BAR_GOLD
	local tier = Techniques.visualTier(owned.level)
	local share
	if owned.level >= Techniques.MAX_LEVEL then
		name.Text, name.TextColor3 = "Mastered", DAO_NAME_EQUIPPED
		level.Text, level.TextColor3 = `Lv {owned.level}`, COST_OK
		share = 1
	elseif gate then
		name.Text, name.TextColor3 = "Bottleneck", BOTTLENECK
		level.Text, level.TextColor3 = `Lv {owned.level} · XP full`, BOTTLENECK
		share = 1
	else
		local need = Techniques.xpToNext(owned.level)
		name.Text, name.TextColor3 = TIER_NAMES[tier] or "", DAO_NAME
		level.Text, level.TextColor3 = `Lv {owned.level} · {owned.xp}/{need}`, COST_OK
		share = math.clamp(owned.xp / need, 0, 1)
	end
	local size = UDim2.fromScale(share, 1)
	if animate and fill.Size ~= size then
		Motion.ease(fill, { Size = size })
	else
		fill.Size = size
	end
	secondary.Visible = gate ~= nil
	comprehendBlock = nil
	if gate then
		local insight = s.insight or 0
		paintCost(costRows.insight, gate.insight, insight)
		paintCost(costRows.stones, gate.stones, stones())
		local short = if s.meditation == nil
			then "Meditate first"
			elseif insight < gate.insight then "Need insight"
			elseif stones() < gate.stones then "Need stones"
			else nil
		comprehendBlock = short
		secondary.Image = if short then BUTTON_LACQUER else BUTTON_JADE
		secondary.ImageTransparency = if short then 0.3 else 0
		local text = caption(secondary)
		text.Text = short or "Comprehend"
		text.TextTransparency = if short then 0.3 else 0
	else
		costRows.insight.Visible = false
		costRows.stones.Visible = false
	end
end

local function renderDetail(animate: boolean?)
	secondary.Image = BUTTON_LACQUER
	secondary.ImageTransparency = 0
	caption(secondary).TextTransparency = 0
	if tab == "Weapons" then
		renderWeaponDetail()
		return
	end
	daoList.Visible = false
	setDetailText(true)
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
		local need = SlotArt.techniqueClass(technique.id)
		local kind = if need then `{Weapons.Classes[need].name} art` else "Technique"
		label("NameLabel").Text = technique.name
		label("KindLabel").Text = `{kind} · {technique.cooldown}s cooldown`
		label("KindLabel").TextColor3 = technique.color:Lerp(Color3.new(1, 1, 1), 0.3)
		label("Blurb").Text = technique.blurb
		label("Lore").Text = ""
		caption(primary).Text = if table.find(s.hotbar, technique.id) then "Remove from hotbar" else "Add to hotbar"
		renderTechnique(technique, owned, animate == true)
	else
		label("NameLabel").Text = ""
		label("KindLabel").Text = ""
		label("Blurb").Text = ""
		label("Lore").Text = ""
	end
end

-- animate: ease bars to new values (a state change), not a fresh selection.
local function render(animate: boolean?)
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
	local list, hasOwned = entries()
	-- a hotbar slot tapped while open stays chosen though the grid doesn't list it
	if selected and not table.find(list, selected) and not table.find(s.hotbar, selected) then
		selected = nil
	end
	local owned, equipped = weaponState()
	local equippedId = if equipped == "" then Weapons.FIST else equipped
	local equipChanged = shownEquipped ~= nil and shownEquipped ~= equippedId
	shownEquipped = equippedId
	for i, id in list do
		local cell = cellTemplate:Clone()
		cell.Name = id
		cell.LayoutOrder = i
		cell.Visible = true
		local isWeapon = tab == "Weapons"
		if isWeapon then
			SlotArt.paint(cell, id, owned[id])
			local mark = cell:FindFirstChild("EquipMark") :: ImageLabel
			mark.Visible = id == equippedId
			if mark.Visible and equipChanged then
				local size = mark.Size
				mark.Size = UDim2.fromScale(size.X.Scale * 1.8, size.Y.Scale * 1.8)
				mark.ImageTransparency = 1
				Motion.tween(mark, { Size = size, ImageTransparency = 0 }, MARK_POP)
			end
		elseif Techniques.Defs[id] then
			local known = s.techniques.owned[id]
			SlotArt.paint(cell, id, nil, `Lv {known.level}`)
			if gateOf(known) then
				(cell:FindFirstChild("CountLabel") :: TextLabel).TextColor3 = BOTTLENECK
			end
			SlotArt.gate(cell, id, true)
		else
			SlotArt.paint(cell, id, Items.count(s, id))
		end
		-- a filtered Arts grid also lists hotbar arts; with keys, say which slot
		local onBar = if isWeapon then nil else table.find(s.hotbar, id)
		local key = cell:FindFirstChild("KeyLabel") :: TextLabel
		key.Visible = onBar ~= nil and not Platform.isTouch()
		key.Text = if onBar then tostring(onBar) else ""
		local halo = cell:FindFirstChild("Halo") :: GuiObject
		halo.Visible = id == selected
		cell.Activated:Connect(function()
			if not HotbarView.justDragged() then
				-- weapons: choosing the chosen one again goes back to the Dao list
				selected = if isWeapon and selected == id then nil else id
				render()
			end
		end)
		if not isWeapon and not onBar then
			HotbarView.draggable(cell, function()
				return id
			end)
		end
		cell.Parent = grid
	end
	local empty = window:FindFirstChild("Empty") :: TextLabel
	empty.Text = if hasOwned
		then `All your {if tab == "Pouch" then "items" else "arts"} are on the hotbar. Tap one there to see it, or drag it off the bar to return it here.`
		else EMPTY[tab]
	empty.Visible = #list == 0
	renderDetail(animate)
end

local function equip(id: string)
	local ok, message
	if id == Weapons.FIST then
		ok, message = weaponRemote():InvokeServer("unequip")
	else
		ok, message = weaponRemote():InvokeServer("equip", id)
	end
	if not ok and message then
		Hud.toast(message)
	end
end

local function onPrimary()
	local id = selected
	if not id then
		return
	end
	if tab == "Weapons" then
		local _, equipped = weaponState()
		equip(if id == equipped then Weapons.FIST else id)
	elseif Items.Defs[id] then
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

local function comprehend(id: string)
	if comprehendBlock then
		Hud.toast(if comprehendBlock == "Meditate first"
			then "Sit and meditate to comprehend it."
			elseif comprehendBlock == "Need insight" then "You need more insight. Defeat new foes and bosses to gain it."
			else "You need more Spirit Stones.")
		return
	end
	if comprehending then
		return
	end
	comprehending = true
	local ok, message = inventoryRemote:InvokeServer("comprehend", id)
	comprehending = false
	if not ok and message then
		Hud.toast(message)
	end
end

-- Tapping a hotbar slot while the window is open shows that slot here.
local function inspect(id: string): boolean
	if not window.Visible or id == "" then
		return false
	end
	local nextTab: Tab? = if Techniques.Defs[id] then "Arts" elseif Items.Defs[id] then "Pouch" else nil
	if not nextTab then
		return false
	end
	tab = nextTab
	selected = id
	render()
	return true
end

local function onSecondary()
	if selected and Techniques.Defs[selected] and tab == "Arts" then
		comprehend(selected)
		return
	end
	if selected and Items.Defs[selected] then
		HotbarView.toggleHold(selected)
		task.defer(renderDetail)
	end
end

-- PC: the window keeps its authored place, centred on screen. Touch: the hotbar
-- stays up as a drop target (drawn over the window), so the window fills the
-- space above it instead, which keeps it centred in the free area.
local function layout()
	if Platform.isTouch() then
		window.AnchorPoint = Vector2.new(0.5, 0)
		window.Position = UDim2.new(0.5, 0, 0, 8)
		window.Size = UDim2.new(0.94, 0, 1, -70)
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
	daoList = info:FindFirstChild("DaoList") :: Frame
	local rowTemplate = daoList:FindFirstChild("RowTemplate") :: Frame
	techniqueRow = rowTemplate:Clone()
	techniqueRow.Name = "TechniqueRow"
	techniqueRow.LayoutOrder = 1
	techniqueRow.Parent = daoList
	-- cost rows: icon, name and "need · you have", no bar
	local function costRow(name: string, icon: string, order: number): Frame
		local row = rowTemplate:Clone()
		row.Name = `{name}Cost`
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 22);
		(row:FindFirstChild("Bar") :: GuiObject).Visible = false
		local image = row:FindFirstChild("Icon") :: ImageLabel
		image.Image = icon
		image.ImageColor3 = Color3.new(1, 1, 1)
		image.Size = UDim2.fromOffset(22, 22)
		image.Position = UDim2.new(0, 5, 0.5, 0)
		for _, text in { "NameLabel", "LevelLabel" } do
			local labelText = row:FindFirstChild(text) :: TextLabel
			labelText.Position = UDim2.new(labelText.Position.X, UDim.new(0, 3))
		end
		(row:FindFirstChild("NameLabel") :: TextLabel).Text = name;
		(row:FindFirstChild("LevelLabel") :: TextLabel).Size = UDim2.fromOffset(130, 16)
		row.Parent = daoList
		return row
	end
	costRows = {
		insight = costRow("Insight", INSIGHT_ICON, 2),
		stones = costRow("Spirit Stones", STONE_ICON, 3),
	}
	local actions = detail:FindFirstChild("Actions") :: Frame
	primary = actions:FindFirstChild("Primary") :: ImageButton
	secondary = actions:FindFirstChild("Secondary") :: ImageButton
	primary.Activated:Connect(onPrimary)
	secondary.Activated:Connect(onSecondary)
	InventoryFilter.init(window, function()
		render()
	end)
	Menus.register(window, { keepHotbar = true, coversTiles = true })
	ListWindow.bindClose(window)
	local tabs = window:FindFirstChild("Tabs") :: Frame
	for _, name: Tab in { "Pouch" :: Tab, "Arts" :: Tab, "Weapons" :: Tab } do
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
			render(true)
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Stones"):Connect(function()
		if window.Visible and tab == "Arts" then
			renderDetail(true)
		end
	end)
	HotbarView.inspect = inspect
	Players.LocalPlayer:GetAttributeChangedSignal("Weapon"):Connect(function()
		if window.Visible then
			render()
		end
	end)
end

return Inventory
