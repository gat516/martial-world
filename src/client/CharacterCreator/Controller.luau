--!strict
-- The join screen (docs/systems/save-slots.md, docs/systems/character-creator.md):
-- the character on a stage over the live world, and one panel beside it that
-- is either the slot screen or the creator.
--   slots: pick a slot. Play, Edit look and Delete for a named one; Create on
--          an empty one; "Name & play" on an unnamed one (a profile from before
--          slots). Nothing is in the world until a slot is played.
--   new:   a new character on one page (Tabs/Begin, the front door): the Fate
--          reveal, a drawn first name to keep or change, and a big Enter World.
--          The look starts on the preset; Edit look changes it later. An
--          account with no character skips the slot screen and opens here.
--   edit:  the creator on a slot's look: Appearance, Hair, Fate, Name, the name
--          locked, Save look on every step, Cancel back to the slots. From the
--          world (Controller.editLook, for the Self card) it edits the played
--          slot and Save or Cancel hand the world back.
-- While open it hides the Hud, parks the camera (Backdrop) and stops the
-- character from walking; playing fades to ink and gives all of it back.
-- Client gating is only UX: the server checks everything again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Backdrop = require(script.Parent.Backdrop)
local Bridge = require(script.Parent.Bridge)
local Components = require(script.Parent.Components)
local Defs = require(script.Parent.Defs)
local Look = require(script.Parent.Look)
local Modals = require(script.Parent.Modals)
local Menus = require(script.Parent.Parent.Menus)
local Motion = require(script.Parent.Parent.Motion)
local Platform = require(script.Parent.Parent.Platform)
local Preview = require(script.Parent.Preview)
local Ribbon = require(script.Parent.Parent.Ribbon)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local TabModules = {
	Appearance = require(script.Parent.Tabs.Appearance),
	Hair = require(script.Parent.Tabs.Hair),
	Fate = require(script.Parent.Tabs.Fate),
	-- not Tabs.Name: that's the folder's own Name property ("Tabs")
	Name = require(script.Parent.Tabs:FindFirstChild("Name") :: ModuleScript),
}
local Begin = require(script.Parent.Tabs.Begin)

local player = Players.LocalPlayer

local Controller = {}

type Summary = {
	id: string,
	filled: boolean,
	named: boolean,
	firstName: string?,
	race: string?,
	variant: string?,
	surname: string?,
	realm: { major: string, minor: number }?,
	lastPlayed: number?,
	look: { [string]: any }?,
}

local gui: ScreenGui
local root: Frame
local panel: ImageLabel
local veil: Frame
local footer: Frame
local nameplate: Frame
local state: State.State
local tabs: { [string]: any } = {}
local handles: { [string]: any } = {}
local begin: any = nil -- the first-character page's handle (Tabs/Begin)
local fieldFocus: { [string]: () -> () } = {}
local isOpen = false
local busy = false
local hudWasEnabled: boolean? = nil

local mode = "slots" -- "slots" | "new" | "edit"
local slotList: { Summary } = {}
local cards: { [string]: any } = {}
local selected = ""
local canSave = true
local session: { id: string, firstName: string? }? = nil
local live = false -- edit opened from the world (editLook): closing returns there
local previewToken = 0

local function play(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

local function buttonsFrame(): Frame
	return footer:FindFirstChild("Buttons") :: Frame
end
local function primary(): ImageButton
	return buttonsFrame():FindFirstChild("Primary") :: ImageButton
end
local function secondary(): ImageButton
	return buttonsFrame():FindFirstChild("Secondary") :: ImageButton
end
local function quiet(): TextButton
	return buttonsFrame():FindFirstChild("Quiet") :: TextButton
end
local function enter(): ImageButton
	return buttonsFrame():FindFirstChild("Enter") :: ImageButton
end
-- the button the player presses to go on: the big Enter on the first-character page
local function goButton(): ImageButton
	return if mode == "new" then enter() else primary()
end
local function line(): TextLabel
	return footer:FindFirstChild("Line") :: TextLabel
end

-- Whether the account has any character (else the slot screen is skipped).
local function hasCharacters(): boolean
	for _, slot in slotList do
		if slot.filled then
			return true
		end
	end
	return false
end

local function setLine(text: string, alert: boolean?)
	line().Text = text
	line().TextColor3 = if alert then Theme.Color.Lacquer else Theme.Color.Muted
end

-- The panel, nameplate and cards scale together (Theme.Fit); the preview takes
-- the rest of the width.
local function fit()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local f = Theme.Fit
	local scale = math.clamp(size.Y / f.DesignHeight, f.Min, f.Max)
	local m = f.Margin
	local height = math.min(f.PanelHeight, (size.Y - 2 * m) / scale)
	-- a short panel (phones) drops the footer's divider to give the page room
	local compact = height < f.CompactBelow
	-- The first-character page: a taller Enter, no status line (its field says
	-- what's needed), and on a phone no title plaque, so it all fits unscrolled.
	local first = mode == "new"
	local buttonHeight = if first then f.EnterHeight else 56
	local footerHeight = if first
		then buttonHeight + (if compact then 0 else 30)
		else (if compact then 84 else 110)
	local headHeight = if first and compact then 20 else 76
	buttonsFrame().Size = UDim2.new(1, 0, 0, buttonHeight);
	(panel:FindFirstChild("Head") :: Frame).Visible = headHeight > 20;
	(footer:FindFirstChild("Line") :: TextLabel).Visible = not first
	if mode == "slots" and #slotList > 0 then
		-- the slot list is short: the panel hugs it (head 76 + cards + footer)
		height = math.min(height, 76 + 16 + #slotList * 90 + footerHeight + 22)
	elseif first then
		-- the first-character page is short too: hug its rows
		local page = (panel:FindFirstChild("Pages") :: CanvasGroup):FindFirstChild("Begin") :: ScrollingFrame
		local rows = page.CanvasSize.Y.Offset
		if rows > 0 then
			height = math.min(height, headHeight + rows + footerHeight + 22)
		end
	end
	footer.Size = UDim2.new(1, -48, 0, footerHeight);
	(footer:FindFirstChild("Divider") :: ImageLabel).Visible = not compact;
	(footer:FindFirstChild("Line") :: TextLabel).Position = UDim2.fromOffset(0, if compact then 0 else 24);
	local pages = panel:FindFirstChild("Pages") :: CanvasGroup
	pages.Position = UDim2.fromOffset(0, headHeight)
	pages.Size = UDim2.new(1, 0, 1, -headHeight - footerHeight - 22)
	panel.Size = UDim2.fromOffset(f.PanelWidth, height)
	panel.Position = UDim2.new(1, -m, 0.5, 0);
	(panel:FindFirstChild("Fit") :: UIScale).Scale = scale
	local right = size.X - m - f.PanelWidth * scale
	local width = math.max(right - 2 * m, 120)
	local cx = m + width / 2
	local preview = root:FindFirstChild("Preview") :: ViewportFrame
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.Position = UDim2.fromOffset(cx, size.Y / 2)
	preview.Size = UDim2.fromOffset(width, size.Y)
	local plateScale = math.min(scale, width / 540)
	nameplate.Position = UDim2.fromOffset(cx, size.Y - 34 * scale);
	(nameplate:FindFirstChild("Fit") :: UIScale).Scale = plateScale
	local hint = preview:FindFirstChild("Hint") :: TextLabel
	hint.Position = UDim2.new(0.5, 0, 1, -(34 * scale + 80 * plateScale))
	-- the modal cards: same scale, the odds list shortened to the screen
	local modal = root:FindFirstChild("Modal") :: Frame
	for _, card in modal:GetChildren() do
		local fitScale = card:FindFirstChild("Fit")
		if fitScale and fitScale:IsA("UIScale") then
			fitScale.Scale = scale
		end
	end
	local odds = modal:FindFirstChild("Odds") :: ImageLabel
	odds.Size = UDim2.fromOffset(460, math.min(560, (size.Y - 2 * m) / scale))
end

-- A page scrolls when its content outgrows it. AbsoluteContentSize is in screen
-- pixels (after the Fit UIScale) while CanvasSize is scaled again, so divide it out.
local function sizeCanvas(page: ScrollingFrame)
	local layout = page:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local padding = page:FindFirstChildOfClass("UIPadding")
	local fitScale = panel:FindFirstChild("Fit") :: UIScale
	local function update()
		local extra = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
		page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / math.max(fitScale.Scale, 0.01) + extra)
		if page.Name == "Begin" and mode == "new" then
			fit() -- the panel hugs this page
		end
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	fitScale:GetPropertyChangedSignal("Scale"):Connect(update)
	update()
end

local function showPage(id: string, instant: boolean?)
	local pages = panel:FindFirstChild("Pages") :: CanvasGroup
	for _, page in pages:GetChildren() do
		if page:IsA("ScrollingFrame") then
			page.Visible = page.Name == id
			if page.Name == id then
				page.CanvasPosition = Vector2.zero
				if not instant then
					page.Position = UDim2.fromOffset(8, 0)
					play(page, Theme.Tween.Page, { Position = UDim2.new() })
				end
			end
		end
	end
	if not instant then
		pages.GroupTransparency = 0.6
		play(pages, Theme.Tween.Page, { GroupTransparency = 0 })
	end
end

local function missing(): { State.Missing }
	return state:missing(Defs.Rules, player:GetAttribute("Race"), player:GetAttribute("Surname"))
end

local function fullName(surnameKey: string?, first: string?): string
	local surname = Defs.Surnames[surnameKey or ""]
	if surname and first and first ~= "" then
		return `{surname.DisplayName} {first}` -- surname first, like the nameplates
	end
	return first or (surname and surname.DisplayName) or ""
end

local function realmName(realm: { major: string, minor: number }?): string
	if not realm then
		return ""
	end
	local ok, stage = pcall(function()
		return require(ReplicatedStorage.Shared.Realms).get(realm.major, realm.minor)
	end)
	return if ok and stage then stage.name else ""
end

local function since(unix: number?): string
	if not unix or unix <= 0 then
		return "Not played yet"
	end
	local away = os.time() - unix
	if away < 3600 then
		return "Played just now"
	elseif away < 86400 then
		return `Played {away // 3600} h ago`
	end
	local days = away // 86400
	return if days == 1 then "Played yesterday" else `Played {days} days ago`
end

local function setNameplate(name: string, sub: string)
	(nameplate:FindFirstChild("Title") :: TextLabel).Text = name;
	(nameplate:FindFirstChild("Sub") :: TextLabel).Text = sub
end

local function summaryById(id: string): Summary?
	for _, s in slotList do
		if s.id == id then
			return s
		end
	end
	return nil
end

-- The creator's nameplate: the clan, and the first name once it's valid.
local function paintCreatorName()
	local first = if session and session.firstName then session.firstName else Defs.Rules.checkFirstName(state:get("FirstName"))
	local race = Defs.Races[player:GetAttribute("Race") or ""]
	setNameplate(
		fullName(player:GetAttribute("Surname"), first),
		if race then Defs.Registry.label(player:GetAttribute("Race"), player:GetAttribute("RaceVariant")) else ""
	)
end

-- Footer and header for the current mode and step.
local function refresh()
	local tabbed = mode == "edit"
	local head = panel:FindFirstChild("Head") :: Frame
	;(head:FindFirstChild("Tabs") :: Frame).Visible = tabbed
	;(head:FindFirstChild("Title") :: Frame).Visible = not tabbed
	local p, s, q, e = primary(), secondary(), quiet(), enter()
	local label = p:FindFirstChild("Label") :: TextLabel
	local secondLabel = s:FindFirstChild("Label") :: TextLabel
	local enabled = not busy
	p.Visible = mode ~= "new"
	e.Visible = mode == "new"
	if mode == "slots" then
		local slot = summaryById(selected)
		q.Visible = slot ~= nil and slot.filled and canSave
		s.Visible = slot ~= nil and slot.named
		secondLabel.Text = "Edit look"
		if not slot or not slot.filled then
			label.Text = "Create"
		elseif not slot.named then
			label.Text = "Name & play"
		else
			label.Text = "Play"
		end
		setLine(if not canSave then "Your characters couldn't be loaded: this session won't be saved." else "", not canSave)
	elseif mode == "new" then
		-- one page: Back only when there's a slot screen to go back to
		q.Visible = false
		s.Visible = hasCharacters()
		secondLabel.Text = "Back"
		label = e:FindFirstChild("Label") :: TextLabel
		label.Text = if busy then "Entering..." else "Enter World"
		local blocker = missing()[1]
		if blocker then
			enabled = false
			setLine(if blocker.field == "FirstName" then "Choose a first name to enter the world." else "The heavens are still drawing your fate...", true)
		else
			setLine("")
		end
	else
		local current = state:get("Tab")
		for _, step in Theme.Steps do
			local text = if step.EditLabel then step.EditLabel else step.Label
			tabs[step.Id].set(text, step.Id == current)
		end
		q.Visible = false
		s.Visible = true
		secondLabel.Text = "Cancel"
		label.Text = if busy then "Saving..." else "Save look"
		setLine("")
	end
	local go = goButton()
	go.ImageColor3 = if enabled then Color3.new(1, 1, 1) else Theme.Color.Disabled
	label.TextTransparency = if enabled then 0 else 0.35
end

function Controller.select(id: string, instant: boolean?)
	state:set("Tab", id)
	showPage(id, instant)
	refresh()
end

local function showMissing()
	local target = missing()[1]
	if not target then
		return
	end
	-- the first-character page holds every field itself
	local key = if mode == "new" then "Begin:" .. target.field else target.field
	if mode ~= "new" and state:get("Tab") ~= target.tab then
		Controller.select(target.tab)
	end
	local focus = fieldFocus[key]
	if focus then
		task.delay(0.05, focus) -- after the page switch has laid out
	end
end

-- The selected slot's character on the stage.
local function previewSlot(slot: Summary?)
	previewToken += 1
	local mine = previewToken
	if not slot or not slot.filled then
		Look.apply(nil, {})
		Look.race(nil, nil)
		setNameplate("New cultivator", "An empty slot")
		return
	end
	local race = Defs.Races[slot.race or ""]
	local sub = if race then `{Defs.Registry.label(slot.race, slot.variant)}  ·  {realmName(slot.realm)}` else realmName(slot.realm)
	setNameplate(if slot.named then fullName(slot.surname, slot.firstName) else "Unnamed cultivator", sub)
	Look.apply(slot.look, {})
	Look.race(slot.race, slot.variant, slot.look and slot.look.RaceLook)
	task.spawn(function()
		local hairs = if slot.named then Bridge.slotHairs(slot.id) else {}
		if mine == previewToken and #hairs > 0 then
			Look.apply(slot.look, hairs)
		end
	end)
end

local function selectSlot(id: string)
	selected = id
	for cardId, card in cards do
		card.setSelected(cardId == id)
	end
	previewSlot(summaryById(id))
	refresh()
end

local function paintCards()
	for _, slot in slotList do
		local card = cards[slot.id]
		if card then
			if not slot.filled then
				card.set("+  New cultivator", "An empty slot", "", "", true)
			else
				local race = Defs.Races[slot.race or ""]
				card.set(
					if slot.named then fullName(slot.surname, slot.firstName) else "Unnamed cultivator",
					if not slot.named then "Name them to play" elseif race then Defs.Registry.label(slot.race, slot.variant) else "",
					realmName(slot.realm),
					since(slot.lastPlayed),
					false
				)
			end
		end
	end
end

-- Fetches the slots and shows the slot page (keeps the selection if it can).
local function loadSlots(prefer: string?): boolean
	local ok, payload = Bridge.slots()
	if not ok or type(payload) ~= "table" then
		setLine(if type(payload) == "string" then payload else "Couldn't load your characters. Try again.", true)
		return false
	end
	slotList = payload.slots
	canSave = payload.canSave ~= false
	local page = (panel:FindFirstChild("Pages") :: CanvasGroup):FindFirstChild("Slots") :: ScrollingFrame
	for _, slot in slotList do
		if not cards[slot.id] then
			local id = slot.id
			cards[id] = Components.slotCard(page, tonumber(id) or 0, function()
				if mode == "slots" then
					selectSlot(id)
				end
			end)
		end
	end
	paintCards()
	fit()
	local pick = prefer or (if selected ~= "" then selected else payload.last)
	if not summaryById(pick or "") then
		pick = slotList[1] and slotList[1].id or ""
	end
	selectSlot(pick :: string)
	return payload.playing == true
end

-- The title on the gold house plaque (docs/ui/ribbons.md): the slot screen's,
-- or the first-character page's.
local function setTitle(text: string)
	local plaque = (panel:FindFirstChild("Head") :: Frame):FindFirstChild("Title") :: Frame
	task.spawn(Ribbon.fit, plaque, text, {
		style = "gold",
		textSize = 21,
		height = plaque.Size.Y.Offset,
		maxWidth = 432,
	})
end

local function setMode(new: string)
	mode = new
	Modals.close()
	fit()
	if new == "slots" then
		session = nil
		live = false
		setTitle(Theme.Titles.Slots)
		showPage("Slots")
		refresh()
	elseif new == "new" then
		setTitle(Theme.Titles.New)
		showPage("Begin")
		refresh()
	else
		Controller.select(Theme.Steps[1].Id, true)
		showPage(Theme.Steps[1].Id)
	end
end

local function setControls(enabled: boolean)
	pcall(function()
		local scripts = player:FindFirstChildOfClass("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			local controls = (require(module :: ModuleScript) :: any):GetControls()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

local function setHud(shown: boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("Hud")
	if not (hud and hud:IsA("ScreenGui")) then
		return
	end
	if not shown then
		hudWasEnabled = hud.Enabled
		hud.Enabled = false
	elseif hudWasEnabled ~= nil then
		hud.Enabled = hudWasEnabled
		hudWasEnabled = nil
	end
end

-- After Play or Enter World: wait for the character the server spawns, then
-- fade out and hand the world back.
local function enterTheWorld()
	local deadline = os.clock() + 15
	while not player.Character and os.clock() < deadline do
		task.wait(0.1)
	end
	Controller.close()
end

-- Opens the creator on a slot: "new" (empty or unnamed) or "edit". fromWorld:
-- edit the played slot from the world (editLook; id is ignored). Returns
-- whether it opened.
local function openCreator(id: string, which: string, fromWorld: boolean?): boolean
	busy = true
	refresh()
	local ok, payload
	if fromWorld then
		ok, payload = Bridge.editPlayed()
		id = if ok and type(payload) == "table" then payload.id else id
	elseif which == "edit" then
		ok, payload = Bridge.editSlot(id)
	else
		ok, payload = Bridge.newSlot(id)
	end
	busy = false
	if not ok or type(payload) ~= "table" then
		refresh()
		setLine(if type(payload) == "string" then payload else "Something went wrong. Try again.", true)
		return false
	end
	live = fromWorld == true
	if which == "edit" then
		session = { id = id, firstName = payload.firstName }
		state:load(Defs, payload.look, payload.firstName, player:GetAttribute("Race"))
		handles.Appearance.reset()
		handles.Fate.reset()
		handles.Name.reset("edit", payload.firstName)
		local look = payload.look
		task.spawn(function()
			handles.Hair.reset(Bridge.slotHairs(id))
			Preview.tintHair(Look.hairColor(look and look.HairColor), Defs.Rules.tintHair)
		end)
	else
		-- the preset look (the ranger outfit, the avatar's skin and hairs), the
		-- Fate reveal and a drawn name, on one page
		session = { id = id }
		state:load(Defs, nil, nil, player:GetAttribute("Race"))
		handles.Appearance.reset()
		handles.Hair.reset(nil)
		begin.reset()
	end
	Look.race(player:GetAttribute("Race"), player:GetAttribute("RaceVariant"), state:get("RaceLook"))
	setMode(which)
	paintCreatorName()
	return true
end

local function onPrimary()
	if busy or Modals.isOpen() then
		return
	end
	if mode == "slots" then
		local slot = summaryById(selected)
		if not slot then
			return
		end
		if not slot.filled or not slot.named then
			task.spawn(openCreator, slot.id, "new")
			return
		end
		busy = true
		refresh()
		local ok, payload = Bridge.play(slot.id)
		busy = false
		refresh()
		if ok then
			task.spawn(enterTheWorld)
		else
			setLine(if type(payload) == "string" then payload else "Something went wrong. Try again.", true)
		end
		return
	end
	if mode == "new" and missing()[1] then
		showMissing()
		return
	end
	local look = state:look()
	if mode == "new" then
		look.NameSource = begin.source() -- analytics only: kept, redrawn or typed
	end
	busy = true
	refresh()
	local ok, payload = Bridge.enterWorld(look)
	busy = false
	refresh()
	if not ok then
		setLine(if type(payload) == "string" then payload else "Something went wrong. Try again.", true)
		return
	end
	if mode == "edit" and live then
		Controller.close() -- the server dressed the character in the new look
	elseif mode == "edit" then
		local id = if session then session.id else selected
		setMode("slots")
		loadSlots(id)
	else
		task.spawn(enterTheWorld)
	end
end

local function onSecondary()
	if busy or Modals.isOpen() then
		return
	end
	if mode == "slots" then
		local slot = summaryById(selected)
		if slot and slot.named then
			task.spawn(openCreator, slot.id, "edit")
		end
		return
	end
	-- back to the slots (Cancel, or Back), or to the world for an edit from there
	task.spawn(Bridge.cancel)
	if live then
		Controller.close()
		return
	end
	local id = if session then session.id else selected
	setMode("slots")
	task.spawn(loadSlots, id)
end

local function onDelete()
	local slot = summaryById(selected)
	if busy or mode ~= "slots" or not (slot and slot.filled) then
		return
	end
	local name = if slot.named then fullName(slot.surname, slot.firstName) else "this unnamed cultivator"
	local body = `{realmName(slot.realm)}  ·  {since(slot.lastPlayed)}.\n\nAll of this cultivator's progress is lost. A new cultivator in this slot keeps the same race and clan.`
	Modals.confirmDelete(`Delete {name}?`, body, function(): (boolean, string?)
		local ok, payload = Bridge.deleteAsk(slot.id)
		if not ok or type(payload) ~= "table" then
			return false, if type(payload) == "string" then payload else nil
		end
		local done, message = Bridge.delete(slot.id, payload.token, slot.firstName or "")
		if not done then
			return false, if type(message) == "string" then message else nil
		end
		task.spawn(loadSlots, slot.id)
		return true, nil
	end)
end

-- Opens the screen behind the ink veil, sets it up with `start` (default: the
-- slot screen), then fades the veil off. `start` may yield (a server call); if it
-- fails the slot screen shows instead, or with `orClose` the screen closes again.
-- Returns whether the screen is open.
local function openWith(start: (() -> boolean)?, orClose: boolean?): boolean
	if isOpen or not gui then
		return false
	end
	isOpen = true
	veil.BackgroundTransparency = 0
	gui.Enabled = true
	Menus.setScreen(true) -- no attacks or prompts behind the screen
	setHud(false)
	setControls(false)
	Backdrop.open(gui:FindFirstChild("Backdrop") :: Frame, Defs.Background)
	Preview.setActive(true)
	fit()
	if not (start and start()) then
		if orClose then
			Controller.close()
			return false
		end
		setMode("slots")
	end
	play(veil, Theme.Tween.Veil, { BackgroundTransparency = 1 })
	return true
end

function Controller.open()
	openWith(nil)
end

-- Edit look from the world (for the Self card): the played slot's look on the
-- Appearance, Hair, Fate and Name steps; Save look dresses the character and
-- Save or Cancel hand the world back. Yields for the server; returns whether it
-- opened (false while the screen is already open or the creator is off).
function Controller.editLook(): boolean
	if isOpen or not gui or not Defs.Rules.SHOW_ON_JOIN then
		return false
	end
	return openWith(function()
		return openCreator("", "edit", true)
	end, true)
end

function Controller.close()
	if not isOpen then
		return
	end
	isOpen = false
	live = false
	play(veil, Theme.Tween.Veil, { BackgroundTransparency = 0 }).Completed:Wait()
	Modals.close()
	Preview.setActive(false)
	Backdrop.close()
	setControls(true)
	setHud(true)
	Menus.setScreen(false)
	gui.Enabled = false
	veil.BackgroundTransparency = 1
end

function Controller.isOpen(): boolean
	return isOpen
end

-- Calls fn(value, changed) now and whenever the player's attribute changes.
local function onAttribute(name: string, fn: (any, boolean) -> ())
	fn(player:GetAttribute(name), false)
	player:GetAttributeChangedSignal(name):Connect(function()
		fn(player:GetAttribute(name), true)
	end)
end

function Controller.init(screen: ScreenGui)
	gui = screen
	root = gui:WaitForChild("Root") :: Frame
	panel = root:WaitForChild("Panel") :: ImageLabel
	veil = gui:WaitForChild("Veil") :: Frame
	footer = panel:WaitForChild("Footer") :: Frame
	nameplate = root:WaitForChild("Nameplate") :: Frame
	local templates = gui:WaitForChild("Templates") :: Folder
	Components.init(templates)
	Modals.init(root)
	state = State.new(Defs)

	local tabRow = (panel:FindFirstChild("Head") :: Frame):FindFirstChild("Tabs") :: Frame
	for order, step in Theme.Steps do
		tabs[step.Id] = Components.tab(tabRow, step.Id, order, function()
			if mode ~= "slots" and not busy then
				Controller.select(step.Id)
			end
		end)
	end

	Preview.init(root:FindFirstChild("Preview") :: ViewportFrame, templates)
	setTitle(Theme.Titles.Slots)

	local ctx = {
		state = state,
		defs = Defs,
		components = Components,
		templates = templates,
		preview = Preview,
		bridge = Bridge,
		theme = Theme,
		player = player,
		onAttribute = onAttribute,
		registerField = function(field: string, focus: () -> ())
			fieldFocus[field] = focus
		end,
		openOdds = Modals.openOdds,
		isTouch = Platform.isTouch(), -- no auto keyboard pop-up on touch
	}
	local pages = panel:FindFirstChild("Pages") :: CanvasGroup
	for _, step in Theme.Steps do
		local page = pages:FindFirstChild(step.Id) :: ScrollingFrame
		handles[step.Id] = TabModules[step.Id].build(page, ctx)
		sizeCanvas(page)
	end
	-- the first-character page: its own field registry, so Enter World focuses its field
	local beginCtx = table.clone(ctx)
	beginCtx.registerField = function(field: string, focus: () -> ())
		fieldFocus["Begin:" .. field] = focus
	end
	local beginPage = pages:FindFirstChild("Begin") :: ScrollingFrame
	begin = Begin.build(beginPage, beginCtx)
	sizeCanvas(beginPage)
	sizeCanvas(pages:FindFirstChild("Slots") :: ScrollingFrame)

	local buttons = buttonsFrame()
	;(buttons:FindFirstChild("Primary") :: ImageButton).Activated:Connect(function()
		task.spawn(onPrimary)
	end)
	;(buttons:FindFirstChild("Enter") :: ImageButton).Activated:Connect(function()
		task.spawn(onPrimary)
	end)
	;(buttons:FindFirstChild("Secondary") :: ImageButton).Activated:Connect(function()
		task.spawn(onSecondary)
	end)
	;(buttons:FindFirstChild("Quiet") :: TextButton).Activated:Connect(onDelete)

	state:onChanged(function(key)
		if mode ~= "slots" and key ~= "Tab" then
			refresh()
			if key == "FirstName" then
				paintCreatorName()
			elseif key == "RaceLook" then
				Look.race(player:GetAttribute("Race"), player:GetAttribute("RaceVariant"), state:get("RaceLook"))
			end
		end
	end)
	for _, attribute in { "Race", "RaceVariant", "Surname" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if mode ~= "slots" then
				refresh()
				paintCreatorName()
				if attribute ~= "Surname" then
					Look.race(player:GetAttribute("Race"), player:GetAttribute("RaceVariant"), state:get("RaceLook"))
				end
			end
		end)
	end

	Motion.buttons(root)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	-- QuickPlay (combat testers) plays slot 1 on the server with no screens
	local quickPlay = require(ReplicatedStorage.Shared.Config).Slots.QUICK_PLAY
	if Defs.Rules.SHOW_ON_JOIN and not quickPlay then
		task.spawn(function()
			local playing = loadSlots(nil)
			if playing then
				return
			end
			-- the front door: an account with no character skips the slot screen
			-- and opens on the first-character page (user, 2026-10-24)
			local first = if hasCharacters() then nil else (slotList[1] and slotList[1].id)
			openWith(if first
				then function()
					return openCreator(first, "new")
				end
				else nil)
			if mode == "slots" then
				selectSlot(selected) -- repaint the stage now the preview is active
			end
		end)
	end
end

return Controller
