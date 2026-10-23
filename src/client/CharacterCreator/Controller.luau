--!strict
-- The character screen (docs/systems/character-creator.md): left nav, the live
-- preview in the middle, the parchment panel on the right, over the world seen
-- from a high vantage. Shown on join while Rules.SHOW_ON_JOIN and the player
-- hasn't confirmed a look (CharacterConfirmed); Controller.open() reopens it.
-- While open it hides the Hud, parks the camera (Backdrop) and stops the
-- character from walking; Enter World fades to ink and gives all of it back.
-- GUI: StarterGui.CharacterCreator (assets/CharacterCreator.rbxmx).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Backdrop = require(script.Parent.Backdrop)
local Bridge = require(script.Parent.Bridge)
local Components = require(script.Parent.Components)
local Defs = require(script.Parent.Defs)
local Menus = require(script.Parent.Parent.Menus)
local Motion = require(script.Parent.Parent.Motion)
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
	local navWidth, panelWidth = nav.Size.X.Offset, panel.Size.X.Offset
	local byHeight = size.Y / f.DesignHeight
	local byWidth = (size.X - 4 * f.Margin - 160) / (navWidth + panelWidth) -- leave the preview at least 160 px
	local scale = math.clamp(math.min(byHeight, byWidth), f.Min, f.Max);
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

local function tabById(id: string): { [string]: string }?
	for _, tab in Theme.Tabs do
		if tab.Id == id then
			return tab
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
	state:set("Tab", id)
	for tabId, button in navButtons do
		button.setSelected(tabId == id)
	end
	local header = panel:FindFirstChild("Header") :: Frame
	local title = header:FindFirstChild("Title") :: TextLabel
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
	Controller.select("Clothes", true)
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

local function enterWorld(): (boolean, any)
	local ok, payload = Bridge.enterWorld(state:look())
	if ok then
		task.spawn(Controller.close)
	end
	return ok, payload
end

function Controller.init(screen: ScreenGui)
	gui = screen
	root = gui:WaitForChild("Root") :: Frame
	nav = root:WaitForChild("Nav") :: Frame
	panel = root:WaitForChild("Panel") :: Frame
	veil = gui:WaitForChild("Veil") :: Frame
	local templates = gui:WaitForChild("Templates") :: Folder
	Components.init(templates)
	state = State.new(Defs)

	local list = nav:FindFirstChild("List") :: Frame
	for order, tab in Theme.Tabs do
		navButtons[tab.Id] = Components.navButton(list, tab, order, function()
			Controller.select(tab.Id)
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
		enterWorld = enterWorld,
	}
	local pages = panel:FindFirstChild("Pages") :: CanvasGroup
	for _, tab in Theme.Tabs do
		local page = pages:FindFirstChild(tab.Id) :: ScrollingFrame
		TabModules[tab.Id].build(page, ctx)
		sizeCanvas(page)
	end

	Motion.buttons(root)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	if Defs.Rules.SHOW_ON_JOIN and player:GetAttribute("CharacterConfirmed") ~= true then
		Controller.open()
	end
end

return Controller
