--!strict
-- The character screen (docs/systems/character-creator.md): left nav, the live
-- preview in the middle, the parchment panel on the right, over the world seen
-- from a high vantage. Shown on join while Rules.SHOW_ON_JOIN and the player
-- hasn't confirmed a look (CharacterConfirmed); Controller.open() reopens it.
-- While open it hides the Hud, parks the camera (Backdrop) and stops the
-- character from walking; Enter World fades to ink and gives all of it back.
-- Flow: the steps go in nav order; Back and Next (Enter World on the last) sit in
-- the panel's footer. A step after one with a required field still empty is
-- locked, and pressing it, a dimmed Next or Enter World jumps to that field.
-- This is only UX: the server checks the whole look again on Enter World.
-- GUI: StarterGui.CharacterCreator (assets/CharacterCreator.rbxmx).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Backdrop = require(script.Parent.Backdrop)
local Bridge = require(script.Parent.Bridge)
local Components = require(script.Parent.Components)
local Defs = require(script.Parent.Defs)
local Menus = require(script.Parent.Parent.Menus)
local Motion = require(script.Parent.Parent.Motion)
local Platform = require(script.Parent.Parent.Platform)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local TabModules = {
	Clothes = require(script.Parent.Tabs.Clothes),
	Hair = require(script.Parent.Tabs.Hair),
	Identity = require(script.Parent.Tabs.Identity),
	Confirm = require(script.Parent.Tabs.Confirm),
}

local player = Players.LocalPlayer

local Controller = {}

local gui: ScreenGui
local root: Frame
local nav: Frame
local panel: Frame
local veil: Frame
local state: State.State
local navButtons: { [string]: any } = {}
local visited: { [string]: boolean } = {}
local fieldFocus: { [string]: () -> () } = {} -- required field -> shows and highlights it
local footer: Frame
local entering = false
local refreshFlow: () -> ()
local isOpen = false
local hudWasEnabled: boolean? = nil

local function play(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

-- Scale the nav and panel to the screen (they're authored at a desktop design
-- size), keep the panel inside the screen height, and put the preview in the
-- gap between them.
local function fit()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local f = Theme.Fit
	local panelWidth = panel.Size.X.Offset
	local byHeight = size.Y / f.DesignHeight
	local function scaleFor(navWidth: number): number
		local byWidth = (size.X - 4 * f.Margin - f.MinPreview) / (navWidth + panelWidth)
		return math.clamp(math.min(byHeight, byWidth), f.Min, f.Max)
	end
	-- a narrow screen (a phone) turns the nav into a column of glyph rings so the
	-- character keeps room
	local scale = scaleFor(f.NavWidth)
	local compact = size.X - 2 * f.Margin - (f.NavWidth + panelWidth) * scale < f.CompactBelow
	if compact then
		scale = scaleFor(f.NavCompactWidth)
	end
	local navWidth = if compact then f.NavCompactWidth else f.NavWidth
	for _, button in navButtons do
		button.setCompact(compact)
	end
	nav.Size = UDim2.fromOffset(navWidth, math.min(f.NavHeight, (size.Y - 2 * f.Margin) / scale))
	for _, corner in (nav:FindFirstChild("Backing") :: Frame):GetChildren() do
		if corner:IsA("ImageLabel") and corner.Name:sub(1, 3) == "Orn" then
			corner.Size = if compact then UDim2.fromOffset(46, 31) else UDim2.fromOffset(92, 62)
		end
	end;
	(nav:FindFirstChild("Fit") :: UIScale).Scale = scale;
	(panel:FindFirstChild("Fit") :: UIScale).Scale = scale
	local designHeight = 740
	panel.Size = UDim2.fromOffset(panelWidth, math.min(designHeight, (size.Y - 2 * f.Margin) / scale))
	nav.Position = UDim2.new(0, f.Margin, 0.5, 0)
	panel.Position = UDim2.new(1, -f.Margin, 0.5, 0)
	local left = f.Margin + navWidth * scale
	local right = size.X - f.Margin - panelWidth * scale
	local preview = root:FindFirstChild("Preview") :: ViewportFrame
	preview.Position = UDim2.fromOffset((left + right) / 2, size.Y / 2)
	preview.Size = UDim2.fromOffset(math.max(right - left - 8, 120), size.Y * 0.94)
	-- the gold portrait corners frame the preview; they scale with the panels
	local frame = root:FindFirstChild("PreviewFrame") :: Frame
	frame.Position = preview.Position
	frame.Size = preview.Size
	for _, corner in frame:GetChildren() do
		if corner:IsA("ImageLabel") then
			corner.Size = UDim2.fromOffset(84 * scale, 56 * scale)
		end
	end
	-- title on top, name plinth at the bottom (both shrink to the preview's
	-- width), the halo behind the head and chest, the ink cloud at the feet
	local cx, cy = preview.Position.X.Offset, preview.Position.Y.Offset
	local w, h = preview.Size.X.Offset, preview.Size.Y.Offset
	local top, bottom = cy - h / 2, cy + h / 2
	local title = root:FindFirstChild("ScreenTitle") :: Frame
	local titleScale = math.min(scale, (w - 16) / title.Size.X.Offset);
	(title:FindFirstChild("Fit") :: UIScale).Scale = titleScale
	title.Position = UDim2.fromOffset(cx, top + 14 * scale)
	local plinth = root:FindFirstChild("Plinth") :: ImageLabel
	-- the family seal is stamped over the plinth's right end and overhangs it by
	-- SEAL_OVERHANG design px; the plinth shifts left by half of that so the pair
	-- is centred under the character
	local SEAL_OVERHANG = 15
	local plinthScale = math.min(scale, (w - 12) / (plinth.Size.X.Offset + SEAL_OVERHANG));
	(plinth:FindFirstChild("Fit") :: UIScale).Scale = plinthScale
	plinth.Position = UDim2.fromOffset(cx - SEAL_OVERHANG / 2 * plinthScale, bottom - 16 * scale)
	local hint = preview:FindFirstChild("Hint") :: TextLabel
	hint.Position = UDim2.new(0.5, 0, 1, -(16 * scale + plinth.Size.Y.Offset * plinthScale + 4))
	local halo = root:FindFirstChild("Halo") :: ImageLabel
	local haloSize = math.min(w * 0.9, h * 0.6)
	halo.Size = UDim2.fromOffset(haloSize, haloSize * 291 / 300)
	halo.Position = UDim2.fromOffset(cx, cy - h * 0.12)
	local ink = root:FindFirstChild("Ink") :: ImageLabel
	ink.Size = UDim2.fromOffset(w, w * 0.18)
	ink.Position = UDim2.fromOffset(cx, cy + h * 0.28)
end

-- Each page scrolls when its content outgrows it (AutomaticCanvasSize doesn't
-- count rows that size themselves; docs/systems/ui.md). AbsoluteContentSize is
-- in screen pixels, after the panel's Fit UIScale, while CanvasSize is scaled
-- by it again, so divide it back out or a shrunk panel cuts the bottom off.
local function sizeCanvas(page: ScrollingFrame)
	local layout = page:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local padding = page:FindFirstChildOfClass("UIPadding")
	local fitScale = panel:FindFirstChild("Fit") :: UIScale
	local function update()
		local extra = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
		page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / math.max(fitScale.Scale, 0.01) + extra)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	fitScale:GetPropertyChangedSignal("Scale"):Connect(update)
	update()
end

local function tabById(id: string): ({ [string]: string }?, number)
	for index, tab in Theme.Tabs do
		if tab.Id == id then
			return tab, index
		end
	end
	return nil, 0
end

local function missing(): { State.Missing }
	return state:missing(Defs.Rules, player:GetAttribute("Race"), player:GetAttribute("Surname"))
end

-- The first missing field on a step before `index` (what locks that step), or nil.
local function blockerBefore(index: number): State.Missing?
	for _, item in missing() do
		local _, at = tabById(item.tab)
		if at < index then
			return item
		end
	end
	return nil
end

-- Switch tabs: the nav highlight moves, the title cross-fades and the new page
-- fades and slides in.
function Controller.select(id: string, instant: boolean?)
	local tab = tabById(id)
	if not tab then
		return
	end
	if state:get("Tab") ~= id then
		visited[state:get("Tab")] = true -- leaving a step marks it seen
	end
	visited[id] = true
	state:set("Tab", id)
	refreshFlow()
	local header = panel:FindFirstChild("Header") :: Frame
	local title = header:FindFirstChild("Title", true) :: TextLabel -- on the crest
	local subtitle = header:FindFirstChild("Subtitle") :: TextLabel
	title.Text = tab.Title
	subtitle.Text = tab.Subtitle
	local pages = panel:FindFirstChild("Pages") :: CanvasGroup
	for _, page in pages:GetChildren() do
		if page:IsA("ScrollingFrame") then
			page.Visible = page.Name == id
			if page.Name == id then
				page.CanvasPosition = Vector2.zero
				if not instant then
					page.Position = UDim2.fromOffset(14, 0)
					play(page, Theme.Tween.Page, { Position = UDim2.new() })
				end
			end
		end
	end
	if not instant then
		pages.GroupTransparency = 0.7
		play(pages, Theme.Tween.Page, { GroupTransparency = 0 })
		title.TextTransparency = 0.6
		subtitle.TextTransparency = 0.6
		play(title, Theme.Tween.Page, { TextTransparency = 0 })
		play(subtitle, Theme.Tween.Page, { TextTransparency = 0 })
	end
end

-- Calls fn(value, changed) now and whenever the player's attribute changes.
local function onAttribute(name: string, fn: (any, boolean) -> ())
	fn(player:GetAttribute(name), false)
	player:GetAttributeChangedSignal(name):Connect(function()
		fn(player:GetAttribute(name), true)
	end)
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

-- Takes the player to the first thing still missing (or the one given): opens
-- its step, shakes its nav plate and lets the tab highlight the field.
local function showMissing(item: State.Missing?)
	local target = item or missing()[1]
	if not target then
		return
	end
	if state:get("Tab") ~= target.tab then
		Controller.select(target.tab)
	end
	local button = navButtons[target.tab]
	if button then
		button.nudge()
	end
	local focus = fieldFocus[target.field]
	if focus then
		task.delay(0.05, focus) -- after the page switch has laid out
	end
	local line = footer:FindFirstChild("Missing") :: TextLabel
	line.TextTransparency = 0.8
	play(line, Theme.Tween.Pop, { TextTransparency = 0 })
end

local function gotoStep(id: string)
	local _, index = tabById(id)
	local blocker = blockerBefore(index)
	if blocker then
		showMissing(blocker)
	else
		Controller.select(id)
	end
end

-- Nav plate states, the footer's Back / Next (or Enter World) and the
-- "Missing: ..." line, from the current step and what's still missing.
refreshFlow = function()
	local current = state:get("Tab")
	local _, index = tabById(current)
	local items = missing()
	local missingOn: { [string]: boolean } = {}
	for _, item in items do
		missingOn[item.tab] = true
	end
	for at, tab in Theme.Tabs do
		local button = navButtons[tab.Id]
		if button then
			button.setState(
				if tab.Id == current then "current"
				elseif blockerBefore(at) then "locked"
				elseif missingOn[tab.Id] then "missing"
				elseif visited[tab.Id] then "done"
				else "todo"
			)
		end
	end

	local buttons = footer:FindFirstChild("Buttons") :: Frame
	local back = buttons:FindFirstChild("Back") :: ImageButton
	local primary = buttons:FindFirstChild("Primary") :: ImageButton
	local label = primary:FindFirstChild("Label") :: TextLabel
	local glyph = primary:FindFirstChild("Glyph") :: TextLabel
	local line = footer:FindFirstChild("Missing") :: TextLabel
	back.Visible = index > 1
	local last = index >= #Theme.Tabs
	local blocker
	if last then
		blocker = items[1]
		label.Text = if entering then "Entering..." else "Enter World"
		glyph.Text = Theme.Tabs[index].Glyph
	else
		local nextTab = Theme.Tabs[index + 1]
		blocker = blockerBefore(index + 1)
		label.Text = `Next: {nextTab.Label}`
		glyph.Text = nextTab.Glyph
	end
	local enabled = blocker == nil and not entering
	primary.ImageColor3 = if enabled then Color3.new(1, 1, 1) else Theme.Color.Disabled
	label.TextTransparency = if enabled then 0 else 0.35
	glyph.TextTransparency = label.TextTransparency
	if not entering then
		line.Text = if blocker then `Missing: {blocker.label}` else ""
	end
end

local function enterWorld()
	if entering then
		return
	end
	if missing()[1] then
		showMissing()
		return
	end
	entering = true
	refreshFlow()
	local ok, payload = Bridge.enterWorld(state:look())
	entering = false
	refreshFlow()
	if ok then
		task.spawn(Controller.close)
	else
		(footer:FindFirstChild("Missing") :: TextLabel).Text = if type(payload) == "string"
			then payload
			else "Something went wrong. Try again."
	end
end

local function onPrimary()
	local _, index = tabById(state:get("Tab"))
	if index >= #Theme.Tabs then
		task.spawn(enterWorld)
	else
		gotoStep(Theme.Tabs[index + 1].Id)
	end
end

local function onBack()
	local _, index = tabById(state:get("Tab"))
	if index > 1 then
		Controller.select(Theme.Tabs[index - 1].Id)
	end
end

function Controller.open()
	if isOpen or not gui then
		return
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
	table.clear(visited)
	Controller.select(Theme.Tabs[1].Id, true)
	play(veil, Theme.Tween.Veil, { BackgroundTransparency = 1 })
end

function Controller.close()
	if not isOpen then
		return
	end
	isOpen = false
	play(veil, Theme.Tween.Veil, { BackgroundTransparency = 0 }).Completed:Wait()
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

function Controller.init(screen: ScreenGui)
	gui = screen
	root = gui:WaitForChild("Root") :: Frame
	nav = root:WaitForChild("Nav") :: Frame
	panel = root:WaitForChild("Panel") :: Frame
	veil = gui:WaitForChild("Veil") :: Frame
	footer = panel:WaitForChild("Footer") :: Frame
	local templates = gui:WaitForChild("Templates") :: Folder
	Components.init(templates)
	state = State.new(Defs)

	local list = nav:FindFirstChild("List") :: Frame
	for order, tab in Theme.Tabs do
		navButtons[tab.Id] = Components.navButton(list, tab, order, function()
			gotoStep(tab.Id)
		end)
	end

	Preview.init(root:FindFirstChild("Preview") :: ViewportFrame, templates)

	local ctx = {
		state = state,
		defs = Defs,
		components = Components,
		preview = Preview,
		bridge = Bridge,
		theme = Theme,
		player = player,
		onAttribute = onAttribute,
		gotoTab = Controller.select,
		-- a tab registers how to show one of its required fields (State.missing's `field`)
		registerField = function(field: string, focus: () -> ())
			fieldFocus[field] = focus
		end,
		showMissing = showMissing,
		isTouch = Platform.isTouch(), -- no auto keyboard pop-up on touch
	}
	local pages = panel:FindFirstChild("Pages") :: CanvasGroup
	for _, tab in Theme.Tabs do
		local page = pages:FindFirstChild(tab.Id) :: ScrollingFrame
		TabModules[tab.Id].build(page, ctx)
		sizeCanvas(page)
	end

	local buttons = footer:FindFirstChild("Buttons") :: Frame;
	(buttons:FindFirstChild("Primary") :: ImageButton).Activated:Connect(onPrimary);
	(buttons:FindFirstChild("Back") :: ImageButton).Activated:Connect(onBack)
	state:onChanged(function(key)
		if key ~= "Tab" then
			refreshFlow()
		end
	end)
	onAttribute("Race", function()
		refreshFlow()
	end)
	-- the plinth under the preview: the full name (or a lacquer prompt) and the
	-- family seal
	local plinth = root:FindFirstChild("Plinth") :: ImageLabel
	local plinthName = plinth:FindFirstChild("Label") :: TextLabel
	local sealGlyph = (plinth:FindFirstChild("Seal") :: ImageLabel):FindFirstChild("Glyph") :: TextLabel
	local nameColor = plinthName.TextColor3
	local function paintName()
		local first = Defs.Rules.checkFirstName(state:get("FirstName"))
		local surname = Defs.Surnames[player:GetAttribute("Surname") or ""]
		sealGlyph.Text = if surname then surname.Glyph else ""
		if first then
			plinthName.Text = if surname then `{surname.DisplayName} {first}` else first -- surname first, like the nameplates
			plinthName.TextColor3 = nameColor
		else
			plinthName.Text = "Choose a first name"
			plinthName.TextColor3 = Theme.Color.AlertLight
		end
	end
	state:onChanged(function(key)
		if key == "FirstName" then
			paintName()
		end
	end)
	onAttribute("Surname", function()
		refreshFlow()
		paintName()
	end)

	Motion.buttons(root)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	if Defs.Rules.SHOW_ON_JOIN and player:GetAttribute("CharacterConfirmed") ~= true then
		Controller.open()
	end
end

return Controller
