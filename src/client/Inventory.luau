--!strict
-- The Inventory window (the Inventory tile, or ` on a keyboard). Three tabs (user,
-- 2026-10-23: weapons and arts in one spot was confusing):
--   Weapons: one section per weapon class (the class in hand first): its glyph and
--     Dao level, then the class's weapons (Bare Fists under Fist), each shown as its
--     real model (WeaponView).
--   Arts: one section per weapon class the arts need (the class in hand first, then
--     universal arts, then the rest), each art its glyph on a seal disc.
--   Pouch: one section per kind of item (herbs, cores, treasures, pills).
-- The class rail and the search box (InventoryFilter) narrow every tab.
-- After the tabs, a book tab (Tabs.HerbariumTab, the book-and-leaf glyph, leaf green)
-- opens the Herbarium; closing the book comes back here (user, 2026-10-24: the
-- Herbarium left the tile row for the Inventory). On a touch phone the search box
-- goes (chips only, design review 2026-10-23) and the book tab has its room.
-- Every cell is a plain slot with its rarity in colour (SlotArt, Rarity: bronze,
-- silver, jade, violet, gold), names show under it (one size, two lines, then
-- truncated), arts wear their class glyph, the weapon in hand its seal,
-- the slot number shows for hotbar entries (keyboards), and anything not yet
-- looked at a NEW tag (Fresh; the tabs and the Inventory tile count them).
-- The detail pane says in plain words what the chosen thing is (grade gem and
-- label, class), where it is (in hand, hotbar slot, not on the bar) and what goes
-- with it (a weapon's arts, an art's weapon), then what it does.
-- Dragging: items and arts onto a hotbar slot (HotbarView); weapons onto the
-- weapon slot by the hotbar (or any slot) to wield them, off it to put them away.
-- Taps: choose a cell, then tap a hotbar slot (place it) or the weapon slot
-- (wield it). With nothing placeable chosen, tapping a slot shows it here.
-- A chosen art shows its level and XP bar; at a bottleneck (Techniques.bottleneck)
-- the bar turns cinnabar, the cost rows (weapon Dao, Spirit Stones) show, and
-- Comprehend sits beside the hotbar button (Bottleneck holds the shared logic).
-- A manual kept until its weapon Dao is reached (techniques.manuals) sits in
-- Arts with "Dao N" in its corner; its detail says what it requires and shows
-- that Dao's progress. It can't go on the hotbar until it's learned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Items = require(ReplicatedStorage.Shared.Items)
local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Bottleneck = require(script.Parent.Bottleneck)
local Fresh = require(script.Parent.Fresh)
local Herbarium = require(script.Parent.Herbarium)
local HotbarView = require(script.Parent.HotbarView)
local Hud = require(script.Parent.Hud)
local InventoryFilter = require(script.Parent.InventoryFilter)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local Rarity = require(script.Parent.Rarity)
local SlotArt = require(script.Parent.SlotArt)
local State = require(script.Parent.State)

local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction

type Tab = "Weapons" | "Arts" | "Pouch"
type Dao = { level: number, xp: number }
type Section = {
	key: string, -- class id, "Any", or item category
	title: string,
	glyph: string,
	color: Color3,
	info: string,
	entries: { string }, -- weapons, arts or items
}

-- tab art: gold for the open tab, lacquer for the other (art/ui/assets.json)
local TAB_ON = { image = "rbxassetid://89951515494594", text = Color3.fromRGB(255, 244, 214) }
local TAB_OFF = { image = "rbxassetid://70679462267599", text = Color3.fromRGB(170, 190, 184) }
local DAO_NAME = Color3.fromRGB(236, 242, 236)
local DAO_NAME_EQUIPPED = Color3.fromRGB(255, 226, 160)
local MARK_POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- comprehension (button art from art/ui/assets.json)
local BUTTON_JADE = "rbxassetid://132904097543542"
local BUTTON_LACQUER = "rbxassetid://70679462267599"
local BOTTLENECK = Color3.fromRGB(255, 150, 110)
local COST_SHORT = Color3.fromRGB(255, 130, 110)
local COST_OK = Color3.fromRGB(240, 210, 140)
local STATUS = Color3.fromRGB(240, 210, 140)
local STATUS_WARN = Color3.fromRGB(255, 150, 110)
local COUNT = Color3.fromRGB(240, 242, 236)
local BAR_GOLD = ColorSequence.new(Color3.fromRGB(246, 214, 140), Color3.fromRGB(178, 124, 52))
local BAR_CINNABAR = ColorSequence.new(Color3.fromRGB(240, 120, 84), Color3.fromRGB(150, 46, 32))
local STONE_ICON = "rbxassetid://93333997810513"
local TIER_NAMES = { "Tier I", "Tier II", "Tier III", "Mastery" }
local FIST_BLURB = "Palm and fist, always at hand. Choosing them puts your weapon away."
local CATEGORY_ORDER = { "Herb", "Pill", "Core", "Treasure" }
local CATEGORY_TITLES = { Herb = "Spirit herbs", Core = "Spirit cores", Treasure = "Heavenly treasures", Pill = "Spirit pills" }
local EMPTY_TEXT: { [Tab]: string } = {
	Weapons = "No weapons yet. Sect racks and fallen foes give them up.",
	Arts = "You know no arts yet. Manuals drop from spirit beasts and wait in hidden caches.",
	Pouch = "Your pouch is empty. Harvest herbs, hunt spirit beasts for their cores, and watch the skies for heavenly treasures.",
}
local TABS: { Tab } = { "Weapons", "Arts", "Pouch" }

local Inventory = {}

local window: Frame
local grid: ScrollingFrame
local sectionTemplate: Frame
local cellTemplate: GuiButton
local info: ScrollingFrame
local actions: Frame
local primary: ImageButton
local secondary: ImageButton
local ringButton: ImageButton -- items only: put the stack in the spirit ring or take it out
local tabButtons: { [Tab]: ImageButton } = {}
local daoList: Frame
local daoRows: { [string]: Frame } = {}
local tab: Tab = "Weapons"
local selected: string? = nil
local shownEquipped: string? = nil -- the weapon in hand at the last render, to pop its seal when it changes
local techniqueRow: Frame -- the chosen art's level and XP bar (a RowTemplate clone)
local costRows: { dao: Frame, stones: Frame }
local cells: { [string]: GuiObject } = {} -- the grid's cells by id, for NEW refreshes
local newDot: GuiObject? -- the Inventory tile's NEW count

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

local function heldId(): string
	local _, equipped = weaponState()
	return if equipped == "" then Weapons.FIST else equipped
end

local function isWeapon(id: string?): boolean
	return id ~= nil and (id == Weapons.FIST or Weapons.Defs[id] ~= nil)
end

local gateOf = Bottleneck.gateOf

-- A manual found but not learned yet (its weapon Dao isn't there).
local function heldManual(id: string?): boolean
	local manuals = State.current.techniques.manuals
	return id ~= nil and manuals ~= nil and manuals[id] == true and State.current.techniques.owned[id] == nil
end

local function nameOf(id: string): string
	local item = Items.Defs[id]
	local technique = Techniques.Defs[id]
	return if item then item.name elseif technique then technique.name else SlotArt.weaponName(id)
end

-- The tab's sort (InventoryFilter): New (NEW first, then most recently first
-- seen), Grade (best tier, then arts' level) or Alphabetical. Ties fall back to
-- grade, then name. pinned (the weapon in hand) stays first.
local function before(a: string, b: string, pinned: string?): boolean
	if pinned and (a == pinned) ~= (b == pinned) then
		return a == pinned
	end
	local sort = InventoryFilter.sort()
	if sort == "Alphabetical" then
		return nameOf(a) < nameOf(b)
	end
	if sort == "New" then
		local na, nb = Fresh.seenAt(a), Fresh.seenAt(b)
		if na ~= nb then
			return na > nb
		end
	end
	local ra, rb = Rarity.rank(a), Rarity.rank(b)
	if ra ~= rb then
		return ra > rb
	end
	local owned = State.current.techniques.owned
	local la, lb = owned[a] and owned[a].level or 0, owned[b] and owned[b].level or 0
	if la ~= lb then
		return la > lb
	end
	return nameOf(a) < nameOf(b)
end

local function sortEntries(list: { string }, pinned: string?)
	table.sort(list, function(a, b)
		return before(a, b, pinned)
	end)
end

--[[ What the tabs hold ]]

-- The class in hand first, then (arts) universal arts, then the other classes.
local function classOrder(withAny: boolean): { string }
	local heldClass = Weapons.classOf(heldId())
	local order = { heldClass }
	if withAny then
		table.insert(order, "Any")
	end
	for _, classId in Weapons.ClassOrder do
		if classId ~= heldClass then
			table.insert(order, classId)
		end
	end
	return order
end

local function classSection(key: string): Section
	local class = Weapons.Classes[key]
	if class then
		local _, _, dao = weaponState()
		local level = (dao[key] or { level = 0 }).level or 0
		return {
			key = key,
			title = class.name,
			glyph = SlotArt.classGlyph(key),
			color = SlotArt.classColor(key),
			info = `{class.dao} · Lv {level}`,
			entries = {},
		}
	end
	return { key = key, title = "Universal arts", glyph = "", color = SlotArt.classColor("Any"), info = "any weapon", entries = {} }
end

local function gather(byClass: { [string]: Section }, withAny: boolean, pinned: string?): { Section }
	local list = {}
	for _, key in classOrder(withAny) do
		local sec = byClass[key]
		if sec then
			sortEntries(sec.entries, pinned)
			table.insert(list, sec)
		end
	end
	return list
end

local function weaponSections(): { Section }
	local owned = weaponState()
	local byClass: { [string]: Section } = {}
	local function add(classId: string, id: string)
		byClass[classId] = byClass[classId] or classSection(classId)
		table.insert(byClass[classId].entries, id)
	end
	add(Weapons.FIST, Weapons.FIST)
	for _, id in Weapons.Order do
		if (owned[id] or 0) > 0 then
			add(Weapons.classOf(id), id)
		end
	end
	return gather(byClass, false, heldId())
end

local function artSections(): { Section }
	local s = State.current
	local byClass: { [string]: Section } = {}
	for _, id in Techniques.Order do
		if s.techniques.owned[id] or heldManual(id) then
			local key = SlotArt.techniqueClass(id) or "Any"
			byClass[key] = byClass[key] or classSection(key)
			table.insert(byClass[key].entries, id)
		end
	end
	return gather(byClass, true, nil)
end

local function pouchSections(): { Section }
	local s = State.current
	local byCategory: { [string]: { string } } = {}
	for _, id in Items.Order do
		if Items.count(s, id) > 0 then
			local category = Items.Defs[id].category
			byCategory[category] = byCategory[category] or {}
			table.insert(byCategory[category], id)
		end
	end
	local list = {}
	for _, category in CATEGORY_ORDER do
		local ids = byCategory[category]
		if ids then
			sortEntries(ids)
			-- the chip and header wear the kind's first icon
			local icon = ""
			for _, itemId in Items.Order do
				local def = Items.Defs[itemId]
				if def.category == category and def.icon then
					icon = def.icon
					break
				end
			end
			table.insert(list, {
				key = category,
				title = CATEGORY_TITLES[category] or category,
				glyph = icon,
				color = DAO_NAME_EQUIPPED,
				info = "",
				entries = ids,
			})
		end
	end
	return list
end

-- The words search looks in: its name, class and kind, grade.
local function words(id: string): { string }
	local list = { nameOf(id), Rarity.of(id).label }
	local item = Items.Defs[id]
	if item then
		table.insert(list, Items.CategoryNames[item.category] or "")
	elseif isWeapon(id) then
		local class = Weapons.Classes[Weapons.classOf(id)]
		table.insert(list, class.name)
		table.insert(list, "weapon")
	else
		local need = SlotArt.techniqueClass(id)
		table.insert(list, if need then Weapons.Classes[need].name else "universal")
		table.insert(list, "art")
	end
	return list
end

-- The ids each tab lists (for NEW counts), hotbar entries left out: those are
-- seen on the bar.
local function newCounts(): { [Tab]: number }
	local s = State.current
	local counts: { [Tab]: number } = { Weapons = 0, Arts = 0, Pouch = 0 }
	local owned = weaponState()
	local function count(t: Tab, id: string)
		if Fresh.isNew(id) and not table.find(s.hotbar, id) then
			counts[t] += 1
		end
	end
	for _, id in Weapons.Order do
		if (owned[id] or 0) > 0 then
			count("Weapons", id)
		end
	end
	for id in s.techniques.owned do
		count("Arts", id)
	end
	for id in s.techniques.manuals or {} do
		if heldManual(id) then
			count("Arts", id)
		end
	end
	for _, id in Items.Order do
		if Items.count(s, id) > 0 then
			count("Pouch", id)
		end
	end
	return counts
end

-- A text line of the detail pane (the name sits in its header).
local function label(name: string): TextLabel
	if name == "NameLabel" then
		return ((info:FindFirstChild("Header") :: Instance):FindFirstChild("Titles") :: Instance):FindFirstChild(name) :: TextLabel
	end
	return info:FindFirstChild(name) :: TextLabel
end

-- The text on an art button (its Label child).
local function caption(button: GuiObject): TextLabel
	return button:FindFirstChild("Label") :: TextLabel
end

local function paintCount(holder: GuiObject?, n: number)
	if not holder then
		return
	end
	holder.Visible = n > 0
	local text = holder:FindFirstChild("Label") :: TextLabel?
	if text then
		text.Text = if n > 9 then "9+" else tostring(n)
	end
end

-- NEW tags on the cells, counts on the tabs and the Inventory tile.
local function refreshNew()
	local counts = newCounts()
	for name, button in tabButtons do
		paintCount(button:FindFirstChild("NewCount") :: GuiObject?, counts[name])
	end
	paintCount(newDot, counts.Weapons + counts.Arts + counts.Pouch)
	for id, cell in cells do
		local isNew = Fresh.isNew(id);
		(cell:FindFirstChild("NewTag") :: GuiObject).Visible = isNew
		local mark = cell:FindFirstChild("EquipMark") :: GuiObject
		if isNew then
			mark.Visible = false
		end
	end
end

--[[ Detail pane ]]

-- One Dao row: icon, "Sword Dao", "Lv 3 · 40/150" and the XP bar (eased).
local function paintDao(row: Frame, classId: string, dao: Dao, equipped: boolean, animate: boolean)
	local class = Weapons.Classes[classId]
	local level = dao.level or 0
	local name = row:FindFirstChild("NameLabel") :: TextLabel
	name.Text = class.dao
	name.TextColor3 = if equipped then DAO_NAME_EQUIPPED else DAO_NAME
	local icon = row:FindFirstChild("Icon") :: ImageLabel
	icon.Image = SlotArt.classGlyph(classId)
	icon.ImageColor3 = SlotArt.classColor(classId)
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

-- The Dao rows: every class (only == nil) or just one.
local function renderDao(only: string?, animate: boolean)
	techniqueRow.Visible = false
	costRows.dao.Visible = false
	costRows.stones.Visible = false;
	(daoList:FindFirstChild("Header") :: GuiObject).Visible = only == nil
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
		paintDao(row, classId, dao[classId] or { level = 0, xp = 0 }, classId == equippedClass, animate and shown and row.Visible and not fresh)
		row.Visible = shown
	end
end

local function setHeader(id: string?)
	local header = info:FindFirstChild("Header") :: Frame
	header.Visible = id ~= nil
	if not id then
		return
	end
	local preview = header:FindFirstChild("Preview") :: GuiObject
	SlotArt.paint(preview, id, nil, "", true)
	local rarity = Rarity.of(id)
	label("NameLabel").Text = nameOf(id)
	local gradeRow = header:FindFirstChild("GradeRow", true) :: Frame
	Rarity.gem(gradeRow:FindFirstChild("Gem") :: ImageLabel, rarity.tier)
	local gradeText = gradeRow:FindFirstChild("Label") :: TextLabel
	gradeText.Text = rarity.label
	gradeText.TextColor3 = rarity.color
	-- class row: what it is, in its class colour
	local classRow = header:FindFirstChild("ClassRow", true) :: Frame
	local glyph = classRow:FindFirstChild("Glyph") :: ImageLabel
	local classText = classRow:FindFirstChild("Label") :: TextLabel
	local item = Items.Defs[id]
	local classId: string? = nil
	if item then
		classText.Text = Items.CategoryNames[item.category] or ""
	elseif isWeapon(id) then
		classId = Weapons.classOf(id)
		classText.Text = if id == Weapons.FIST then "Bare hands" else `{Weapons.Classes[classId :: string].name} · weapon`
	else
		classId = SlotArt.techniqueClass(id)
		classText.Text = if classId then `{Weapons.Classes[classId].name} art` else "Universal art"
	end
	glyph.Visible = classId ~= nil
	classText.Position = UDim2.fromOffset(if classId then 23 else 0, 0)
	if classId then
		glyph.Image = SlotArt.classGlyph(classId)
		glyph.ImageColor3 = SlotArt.classColor(classId)
	end
	classText.TextColor3 = if classId then SlotArt.classColor(classId) else SlotArt.classColor("Any")
end

local function setText(name: string, text: string, color: Color3?)
	local l = label(name)
	l.Text = text
	l.Visible = text ~= ""
	if color then
		l.TextColor3 = color
	end
end

-- Where it is, in plain words.
local function placeText(id: string): string
	local touch = Platform.isTouch()
	local at = table.find(State.current.hotbar, id)
	if at then
		return `On your hotbar, slot {at}.`
	end
	return if touch
		then "Not on your hotbar. Tap a hotbar slot to put it there."
		else "Not on your hotbar. Drag it onto a slot to use it."
end

-- The spirit ring (server Haul, docs/systems/haul.md): the ids kept safe even in
-- the wilds, its size by realm, and whether an item is rare enough to be safe anyway
-- (the server refuses those).
local function ringState(): ({ string }, number)
	local s = State.current :: any
	return s.ring or {}, s.ringSlots or 0
end

local function safeFind(id: string): boolean
	local item = Items.Defs[id]
	local rarity = item and Items.Rarities[item.rarity]
	return rarity ~= nil and rarity.order >= Pacing.Haul.SAFE_RARITY
end

local function showActions(shown: boolean)
	actions.Visible = shown
	ringButton.Visible = false -- the item branch shows it
	info.Size = if shown then UDim2.new(1, 0, 1, -46) else UDim2.fromScale(1, 1)
end

local function renderWeaponDetail(id: string, animate: boolean)
	local owned = weaponState()
	local held = heldId()
	local touch = Platform.isTouch()
	local isHeld = id == held
	local classId = Weapons.classOf(id)
	local class = Weapons.Classes[classId]
	local def = Weapons.Defs[id]
	showActions(false)
	daoList.Visible = true
	if id == Weapons.FIST then
		setText(
			"Status",
			if isHeld
				then "In use: no weapon in hand."
				elseif touch then "Tap the weapon slot, left of the hotbar, to put your weapon away."
				else "Drag onto the weapon slot, left of the hotbar, to put your weapon away.",
			STATUS
		)
	elseif isHeld then
		setText(
			"Status",
			if touch then "In your hand. Tap the weapon slot to put it away." else "In your hand. Drag it off the weapon slot to put it away.",
			STATUS
		)
	else
		setText(
			"Status",
			if touch then "Tap the weapon slot, left of the hotbar, to wield it." else "Drag it onto the weapon slot, left of the hotbar, to wield it.",
			STATUS
		)
	end
	-- the arts that go with it
	local arts = {}
	for _, techniqueId in Techniques.Order do
		if State.current.techniques.owned[techniqueId] and SlotArt.techniqueClass(techniqueId) == classId then
			table.insert(arts, Techniques.Defs[techniqueId].name)
		end
	end
	setText(
		"Pairs",
		if #arts > 0 then `{class.name} arts: {table.concat(arts, ", ")}.` else `You know no {string.lower(class.name)} arts yet.`,
		SlotArt.classColor(classId)
	)
	if def then
		local grade = Weapons.Grades[def.grade]
		local count = owned[id] or 0
		local strength = if grade and grade.multiplier ~= 1
			then ` {grade.name} grade: {class.noun} strikes and {class.noun} arts deal x{grade.multiplier}.`
			else ""
		setText("Blurb", def.blurb .. strength .. (if count > 1 then ` You have {count}.` else ""))
	else
		setText("Blurb", FIST_BLURB)
	end
	setText("Lore", "")
	renderDao(classId, animate)
end

local stones = Bottleneck.stones

local function paintCost(row: Frame, need: number, have: number)
	local text = row:FindFirstChild("LevelLabel") :: TextLabel
	text.Text = `{need} · you have {have}`
	text.TextColor3 = if have >= need then COST_OK else COST_SHORT
	row.Visible = true
end

-- The art's level row (tier, Lv, XP bar) and, at a bottleneck, its cost rows and
-- the Comprehend button (Secondary), which names what's missing while it can't.
-- The Dao cost row: the class's glyph and Dao name ("Weapon Dao" for an
-- any-weapon art, which counts the highest class), "need · you have".
local function paintDaoCost(technique: any, gate: Bottleneck.Gate)
	local classId = SlotArt.techniqueClass(technique.id)
	local row = costRows.dao
	local icon = row:FindFirstChild("Icon") :: ImageLabel
	icon.Image = if classId then SlotArt.classGlyph(classId) else ""
	icon.ImageColor3 = SlotArt.classColor(classId or "Any");
	(row:FindFirstChild("NameLabel") :: TextLabel).Text = if classId then Weapons.Classes[classId].dao else "Weapon Dao"
	paintCost(row, gate.dao, gate.daoHave)
end

local function renderTechnique(technique: any, owned: State.Technique, animate: boolean)
	local gate = gateOf(technique.id, owned)
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
	if gate then
		paintDaoCost(technique, gate)
		paintCost(costRows.stones, gate.stones, stones())
		local short = Bottleneck.block(gate)
		secondary.Image = if short then BUTTON_LACQUER else BUTTON_JADE
		secondary.ImageTransparency = if short then 0.3 else 0
		local text = caption(secondary)
		text.Text = short or "Comprehend"
		text.TextTransparency = if short then 0.3 else 0
	else
		costRows.dao.Visible = false
		costRows.stones.Visible = false
	end
end

local function renderDetail(animate: boolean?)
	secondary.Image = BUTTON_LACQUER
	secondary.ImageTransparency = 0
	caption(secondary).TextTransparency = 0
	local s = State.current
	local id = selected
	local item = id and Items.Defs[id]
	local technique = id and Techniques.Defs[id]
	local ownedArt = technique and s.techniques.owned[technique.id]
	local held = technique ~= nil and heldManual(technique.id)
	local owned = weaponState()
	local valid = (item ~= nil and Items.count(s, item.id) > 0)
		or ownedArt ~= nil
		or held
		or id == Weapons.FIST
		or (id ~= nil and (owned[id] or 0) > 0)
	if not valid then
		id, item, technique = nil, nil, nil
	end
	setHeader(id)
	label("Hint").Visible = id == nil
	if not id then
		-- nothing chosen: what Dao comprehension stands at, on the Weapons tab
		showActions(false)
		-- the Pouch's ring view: how many of its stacks are kept safe
		local ring, slots = ringState()
		setText("Status", if tab == "Pouch" and slots > 0 then `Spirit ring: {#ring}/{slots} stacks kept safe.` else "", STATUS)
		setText("Pairs", "")
		setText("Blurb", "")
		setText("Lore", "")
		daoList.Visible = tab == "Weapons"
		if tab == "Weapons" then
			renderDao(nil, animate == true)
		end
		return
	end
	if isWeapon(id) then
		renderWeaponDetail(id :: string, animate == true)
		return
	end
	showActions(true)
	if item then
		daoList.Visible = false
		local count = Items.count(s, item.id)
		setText("Status", placeText(item.id) .. (if count > 1 then ` You have {count}.` else ""), STATUS)
		-- the spirit ring: the Ring button puts the stack in (its label counts the
		-- slots) or takes it out; rare finds are safe without it
		local ring, slots = ringState()
		local inRing = table.find(ring, item.id) ~= nil
		local safe = safeFind(item.id)
		setText(
			"Pairs",
			if inRing then `In your spirit ring ({#ring}/{slots}): safe even in the wilds.`
				elseif safe then "A rare find: it never spills, ring or not."
				else "",
			STATUS
		)
		ringButton.Visible = slots > 0 and (inRing or not safe)
		caption(ringButton).Text = if inRing then "Take out" else `Ring {#ring}/{slots}`
		setText("Blurb", item.blurb)
		setText("Lore", item.lore or "")
		primary.Visible = true
		secondary.Visible = true
		caption(primary).Text = if item.category == "Herb" then "Eat" else "Use"
		local held = HotbarView.held()
		caption(secondary).Text = if held and held:GetAttribute("ItemId") == item.id then "Put away" else "Hold"
	elseif technique and ownedArt then
		local need = SlotArt.techniqueClass(technique.id)
		setText("Status", placeText(technique.id), STATUS)
		if need then
			local held = heldId()
			local ready = Weapons.classOf(held) == need
			local holding = if held == Weapons.FIST then "nothing" else SlotArt.weaponName(held)
			setText(
				"Pairs",
				if ready
					then `{Weapons.requires(need)}: you hold {holding}.`
					else `{Weapons.requires(need)}. You hold {holding}, so it won't cast.`,
				if ready then SlotArt.classColor(need) else STATUS_WARN
			)
		else
			setText("Pairs", "Works with any weapon, or none.", SlotArt.classColor("Any"))
		end
		setText("Blurb", `{technique.blurb} Cooldown {technique.cooldown}s.`)
		setText("Lore", "")
		primary.Visible = true
		caption(primary).Text = if table.find(s.hotbar, technique.id) then "Remove from hotbar" else "Add to hotbar"
		renderTechnique(technique, ownedArt, animate == true)
	elseif technique and held then
		-- a kept manual: what it requires, and that Dao's progress below
		showActions(false)
		local need = Techniques.learnDao(technique)
		local have = Bottleneck.daoLevel(technique.id)
		setText("Status", "A manual you can't learn yet. You will learn it the moment your Dao is deep enough.", STATUS)
		setText("Pairs", `Requires {Techniques.daoText(technique, need)}. Yours is {have}.`, STATUS_WARN)
		setText("Blurb", technique.blurb)
		setText("Lore", "")
		daoList.Visible = true
		renderDao(SlotArt.techniqueClass(technique.id), animate == true)
	end
end

--[[ Grid ]]

local function choose(id: string?)
	selected = id
	if id then
		Fresh.see({ id })
	end
end

local function makeCell(id: string, order: number, held: string, equipChanged: boolean): GuiButton
	local s = State.current
	local cell = cellTemplate:Clone()
	cell.Name = id
	cell.LayoutOrder = order
	cell.Visible = true
	local weapon = isWeapon(id)
	local technique = Techniques.Defs[id]
	local owned = weaponState()
	if weapon then
		SlotArt.paint(cell, id, owned[id])
	elseif technique then
		local known = s.techniques.owned[id]
		if known then
			SlotArt.paint(cell, id, nil, `Lv {known.level}`);
			(cell:FindFirstChild("CountLabel") :: TextLabel).TextColor3 = if gateOf(id, known) then BOTTLENECK else COUNT
		else
			-- a kept manual: the Dao it waits on
			SlotArt.paint(cell, id, nil, `Dao {Techniques.learnDao(technique)}`);
			(cell:FindFirstChild("CountLabel") :: TextLabel).TextColor3 = STATUS_WARN
		end
	else
		SlotArt.paint(cell, id, Items.count(s, id), nil, true) -- herbs and pills as their models
	end
	-- the jade 戒 seal on Pouch stacks in the spirit ring (top-left, opposite NEW)
	local ring = ringState();
	(cell:FindFirstChild("RingMark") :: GuiObject).Visible = not weapon and technique == nil and table.find(ring, id) ~= nil
	local mark = cell:FindFirstChild("EquipMark") :: ImageLabel
	mark.Visible = weapon and id == held
	if mark.Visible and equipChanged then
		local size = mark.Size
		mark.Size = UDim2.fromOffset(size.X.Offset * 1.8, size.Y.Offset * 1.8)
		mark.ImageTransparency = 1
		Motion.tween(mark, { Size = size, ImageTransparency = 0 }, MARK_POP)
	end
	local onBar = if weapon then nil else table.find(s.hotbar, id)
	local key = cell:FindFirstChild("KeyLabel") :: TextLabel
	key.Visible = onBar ~= nil and not Platform.isTouch()
	key.Text = if onBar then tostring(onBar) else ""
	local isNew = Fresh.isNew(id);
	(cell:FindFirstChild("NewTag") :: GuiObject).Visible = isNew
	if isNew then
		mark.Visible = false
	end
	(cell:FindFirstChild("Halo") :: GuiObject).Visible = id == selected
	cell.MouseEnter:Connect(function()
		Fresh.see({ id })
	end)
	cell.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Fresh.see({ id })
		end
	end)
	cell.Activated:Connect(function()
		if not HotbarView.justDragged() then
			-- choosing the chosen one again goes back to the overview
			choose(if selected == id then nil else id)
			Inventory.render()
		end
	end)
	HotbarView.draggable(cell, function()
		return if heldManual(id) then nil else id
	end)
	cells[id] = cell
	return cell
end

local function render(animate: boolean?)
	for name, button in tabButtons do
		local style = if name == tab then TAB_ON else TAB_OFF
		button.Image = style.image
		caption(button).TextColor3 = style.text
	end
	for _, child in grid:GetChildren() do
		if child.Name == "Section" then
			child:Destroy()
		end
	end
	table.clear(cells)
	local s = State.current
	local sections = if tab == "Weapons" then weaponSections() elseif tab == "Arts" then artSections() else pouchSections()
	local chips: { InventoryFilter.Chip } = {}
	for _, sec in sections do
		local pouch = tab == "Pouch"
		table.insert(chips, { id = sec.key, icon = sec.glyph, color = if pouch then Color3.new(1, 1, 1) else sec.color })
	end
	InventoryFilter.update(tab, chips)
	local filter = InventoryFilter.filter()
	local held = heldId()
	local equipChanged = shownEquipped ~= nil and shownEquipped ~= held
	shownEquipped = held
	local listed = 0
	local order = 0
	for _, sec in sections do
		if filter ~= "All" and filter ~= sec.key then
			continue
		end
		local entries = {}
		for _, id in sec.entries do
			if InventoryFilter.matches(words(id)) then
				table.insert(entries, id)
			end
		end
		if #entries == 0 then
			continue
		end
		order += 1
		local frame = sectionTemplate:Clone()
		frame.Name = "Section"
		frame.LayoutOrder = order
		frame.Visible = true
		local header = frame:FindFirstChild("Header") :: Frame
		local glyph = header:FindFirstChild("Glyph") :: ImageLabel
		glyph.Visible = sec.glyph ~= ""
		glyph.Image = sec.glyph
		glyph.ImageColor3 = if tab == "Pouch" then Color3.new(1, 1, 1) else sec.color
		local title = header:FindFirstChild("Title") :: TextLabel
		title.Text = sec.title
		title.TextColor3 = sec.color
		title.Position = UDim2.new(0, if sec.glyph ~= "" then 26 else 0, 0.5, 0);
		(header:FindFirstChild("Info") :: TextLabel).Text = sec.info
		local row = frame:FindFirstChild("Cells") :: Frame
		for n, id in entries do
			makeCell(id, n, held, equipChanged).Parent = row
		end
		listed += #entries
		frame.Parent = grid
	end
	-- a hotbar slot tapped while open stays chosen though the grid may not list it
	if selected and not cells[selected] and not table.find(s.hotbar, selected) then
		selected = nil
	end
	local empty = window:FindFirstChild("Empty") :: TextLabel
	empty.Text = if InventoryFilter.searching() then "Nothing here matches your search." else EMPTY_TEXT[tab]
	empty.Visible = listed == 0
	renderDetail(animate)
	refreshNew()
end
Inventory.render = render

-- Tapping hotbar slot i while the window is open: place the chosen art or item
-- there (if it isn't on the bar yet), wield the chosen weapon, or show the slot.
local function tapSlot(i: number): boolean
	if not window.Visible then
		return false
	end
	local s = State.current
	local id = selected
	if id and isWeapon(id) then
		HotbarView.equipWeapon(id)
		return true
	end
	if id and (Techniques.Defs[id] or Items.Defs[id]) and not heldManual(id) and not table.find(s.hotbar, id) then
		invoke("slot", id, i)
		return true
	end
	local there = s.hotbar[i] or ""
	if there == "" then
		return true
	end
	local nextTab: Tab = if Items.Defs[there] then "Pouch" else "Arts"
	if nextTab ~= tab then
		tab = nextTab
	end
	choose(there)
	render()
	return true
end

-- Tapping the weapon slot: wield the chosen weapon (the one in hand: put it
-- away), or show the weapon in hand.
local function tapWeapon()
	if not window.Visible then
		return
	end
	local id = selected
	if id and isWeapon(id) then
		HotbarView.equipWeapon(if id == heldId() then Weapons.FIST else id)
		return
	end
	tab = "Weapons"
	choose(heldId())
	render()
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

local function onRing()
	local id = selected
	if id and Items.Defs[id] then
		local ring = ringState()
		invoke("ring", id, table.find(ring, id) == nil)
	end
end

local function onSecondary()
	if selected and Techniques.Defs[selected] then
		Bottleneck.comprehend(selected)
		return
	end
	if selected and Items.Defs[selected] then
		HotbarView.toggleHold(selected)
		task.defer(renderDetail)
	end
end

-- PC: the window keeps its authored place, centred on screen. Touch: the hotbar
-- stays up as a drop target (drawn over the window), so the window fills the space
-- between Roblox's top bar and the hotbar instead: it starts below the bar, so its
-- top-left never crowds Roblox's menu and chat buttons and the bar's row stays free
-- for toasts. The title plaque (which rides on the window's top edge) is left out
-- there: it would reach back into the bar, and the chosen tab already says where
-- you are; the header rows (tabs, search, rail, sort) and the grid move up into
-- its room, so the grid gets the height.
-- Phone pass (user's device-emulator playtest, 2026-10-23: "the phone view got
-- fucked up for inventory"): Platform.topbar read the bar 116 px deep (since
-- fixed: it mixed two coordinate spaces) and a fixed 70 px hotbar allowance left
-- ~40 px unused, so the window was 170 px tall with a 30 px grid. The bar's depth
-- is also capped at TOPBAR_MAX (Roblox's 58 px bar), and the window runs down to
-- the hotbar's real top.
-- Phones (Platform.isSmall, 2026-10-24: "it's cramped"): the window is ~250 px tall
-- there and two header rows left the grid one row of cells, so the rail and sort
-- join the tabs in one toolbar row (rail scrolling sideways between them, sort by
-- the close seal) and the search box is left out (a phone keyboard would cover the
-- window anyway; the rail still narrows every tab). Grid, divider and detail start
-- right under that row.
local TOUCH_TOP_GAP = 6
local TOPBAR_MAX = 58
local TOUCH_HOTBAR_GAP = 12 -- above the hotbar's top (the weapon slot's caption pokes 7 px up)
local TOUCH_HOTBAR_ROOM = 70 -- fallback when the hotbar can't be measured
local PLAQUE_ROOM = 22 -- how much higher the header rows sit without the plaque
local SHIFTED = { "Tabs", "Search", "Rail", "SortButton", "Grid", "Empty", "Divider" }
local GROWN = { Grid = true, Divider = true } -- keep their bottom where it was
local TOOLBAR_GAP = 8 -- between the tabs, rail and sort in the phone toolbar row
local TOOLBAR_SORT_WIDTH = 96
local TOOLBAR_CLOSE_ROOM = 54 -- from the window's right edge to the sort button (the close seal)
local BODY_GAP = 8 -- from the toolbar row's bottom to the grid and detail

-- Phones: one toolbar row (see above). Runs once, after the plaque shift.
local function compactHeader()
	local tabs = window:FindFirstChild("Tabs") :: Frame
	local rail = window:FindFirstChild("Rail") :: GuiObject
	local sort = window:FindFirstChild("SortButton") :: GuiObject
	local railLeft = tabs.Position.X.Offset + tabs.Size.X.Offset + TOOLBAR_GAP
	local rowCentre = tabs.Position.Y.Offset + tabs.Size.Y.Offset / 2;
	(window:FindFirstChild("Search") :: GuiObject).Visible = false
	sort.AnchorPoint = Vector2.new(1, 0.5)
	sort.Position = UDim2.new(1, -TOOLBAR_CLOSE_ROOM, 0, rowCentre)
	sort.Size = UDim2.fromOffset(TOOLBAR_SORT_WIDTH, sort.Size.Y.Offset)
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.fromOffset(railLeft, rowCentre)
	rail.Size = UDim2.new(1, -(railLeft + TOOLBAR_GAP + TOOLBAR_SORT_WIDTH + TOOLBAR_CLOSE_ROOM), 0, rail.Size.Y.Offset)
	-- the grid, divider and detail start under the row, keeping their bottom edge;
	-- the empty note rides with the grid
	local bodyTop = rowCentre + rail.Size.Y.Offset / 2 + BODY_GAP
	local rise = (window:FindFirstChild("Grid") :: GuiObject).Position.Y.Offset - bodyTop
	for _, name in { "Grid", "Divider", "Detail", "Empty" } do
		local part = window:FindFirstChild(name) :: GuiObject
		local p, s = part.Position, part.Size
		local by = if name == "Empty" then rise else p.Y.Offset - bodyTop
		part.Position = UDim2.new(p.X, UDim.new(p.Y.Scale, p.Y.Offset - by))
		if name ~= "Empty" then
			part.Size = UDim2.new(s.X, UDim.new(s.Y.Scale, s.Y.Offset + by))
		end
	end
end

local shifted = false
local function layout()
	if not Platform.isTouch() then
		return
	end
	local parent = window.Parent :: GuiBase2d
	local top = math.min(Platform.topbar(parent), TOPBAR_MAX) + TOUCH_TOP_GAP
	local stack = parent:FindFirstChild("Stack")
	local hotbar = stack and stack:FindFirstChild("Hotbar") :: GuiObject?
	local bottom = parent.AbsoluteSize.Y - TOUCH_HOTBAR_ROOM
	if hotbar and hotbar.AbsoluteSize.Y > 0 then
		bottom = hotbar.AbsolutePosition.Y - parent.AbsolutePosition.Y - TOUCH_HOTBAR_GAP
	end
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, top)
	window.Size = UDim2.new(1, -16, 0, math.max(0, bottom - top));
	(window:FindFirstChild("TitlePlaque") :: GuiObject).Visible = false
	if not shifted then
		shifted = true
		for _, name in SHIFTED do
			local part = window:FindFirstChild(name) :: GuiObject?
			if part then
				local p, s = part.Position, part.Size
				part.Position = UDim2.new(p.X, UDim.new(p.Y.Scale, p.Y.Offset - PLAQUE_ROOM))
				if GROWN[name] then
					part.Size = UDim2.new(s.X, UDim.new(s.Y.Scale, s.Y.Offset + PLAQUE_ROOM))
				end
			end
		end
		if Platform.isSmall() then
			compactHeader()
		end
	end
end

local function setOpen(open: boolean)
	if open then
		layout()
		InventoryFilter.clearSearch()
		render()
		Menus.open(window)
	else
		Menus.close(window)
	end
end
Inventory.setOpen = setOpen

function Inventory.init(gui: ScreenGui)
	window = gui:FindFirstChild("Inventory") :: Frame
	grid = window:FindFirstChild("Grid") :: ScrollingFrame
	sectionTemplate = grid:FindFirstChild("SectionTemplate") :: Frame
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
		dao = costRow("Weapon Dao", "", 2),
		stones = costRow("Spirit Stones", STONE_ICON, 3),
	}
	actions = detail:FindFirstChild("Actions") :: Frame
	primary = actions:FindFirstChild("Primary") :: ImageButton
	secondary = actions:FindFirstChild("Secondary") :: ImageButton
	primary.Activated:Connect(onPrimary)
	secondary.Activated:Connect(onSecondary)
	ringButton = actions:FindFirstChild("Ring") :: ImageButton
	ringButton.Activated:Connect(onRing)
	InventoryFilter.init(window, function()
		render()
	end)
	Menus.register(window, { keepHotbar = true })
	ListWindow.bindClose(window)
	local tabs = window:FindFirstChild("Tabs") :: Frame
	for _, name in TABS do
		local button = tabs:FindFirstChild(`{name}Tab`) :: ImageButton
		tabButtons[name] = button
		button.Activated:Connect(function()
			if tab ~= name then
				tab = name
				selected = nil
				grid.CanvasPosition = Vector2.zero
				render()
			end
		end)
	end
	-- the book tab: the Herbarium, and back here when it closes
	local bookTab = tabs:FindFirstChild("HerbariumTab") :: GuiButton
	bookTab.Activated:Connect(function()
		Herbarium.openMine(function()
			setOpen(true)
		end)
	end)
	if Platform.isTouch() and Platform.isSmall() then
		(window:FindFirstChild("Search") :: GuiObject).Visible = false
	end
	local tile = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("InventoryButton") :: TextButton
	newDot = tile:FindFirstChild("NewDot") :: GuiObject?
	tile.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Backquote then
			setOpen(not window.Visible)
		end
	end)
	Platform.topbarChanged(function()
		if window.Visible then
			layout()
		end
	end)
	State.onChanged(function()
		-- what's on the hotbar has been seen there
		local onBar = {}
		for _, id in State.current.hotbar do
			if id ~= "" then
				table.insert(onBar, id)
			end
		end
		Fresh.see(onBar)
		if window.Visible then
			render(true)
		else
			refreshNew()
		end
	end)
	Fresh.onChanged(refreshNew)
	Players.LocalPlayer:GetAttributeChangedSignal("Stones"):Connect(function()
		if window.Visible and selected and Techniques.Defs[selected] then
			renderDetail(true)
		end
	end)
	HotbarView.tapSlot = tapSlot
	HotbarView.tapWeapon = tapWeapon
	Players.LocalPlayer:GetAttributeChangedSignal("Weapon"):Connect(function()
		if window.Visible then
			render()
		end
	end)
end

return Inventory
