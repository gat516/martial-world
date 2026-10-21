--!strict
-- The meditation menu's small panel (Hud.Stack.MeditationPanel), opened from the
-- seated tiles (Meditation.luau). One page at a time, each a short list of rows
-- cloned from List.RowTemplate (seal, name, two lines, a blurb, an action):
--   Comprehend  techniques at a bottleneck (Bottleneck), their cost in insight
--               and Spirit Stones, and a Comprehend button that names what's
--               missing while it can't run.
--   Method      owned cultivation methods (Shared.Methods); Use switches
--               (CultivationAction "method"), the active one reads "Active".
--   Root        the spirit root's card and its exact numbers (Note), the same
--               text as the Self card. Raising its grade or rerolling come later.
-- The panel is a window (Menus): the seated row and the HUD step aside while it's
-- open, and its seal closes it. It sits where the vitals were, at the bottom
-- of the stack, so the meditating character stays in view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Methods = require(ReplicatedStorage.Shared.Methods)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Bottleneck = require(script.Parent.Bottleneck)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local SelfCard = require(script.Parent.SelfCard)
local State = require(script.Parent.State)

local cultivationRemote = ReplicatedStorage.Remotes.CultivationAction :: RemoteFunction
local player = Players.LocalPlayer

export type Page = "Comprehend" | "Method" | "Root"

-- button art (art/ui/assets.json)
local BUTTON_JADE = "rbxassetid://124219422183170"
local BUTTON_LACQUER = "rbxassetid://88447362782150"
local LIGHT = Color3.fromRGB(236, 232, 220)
local DIM = Color3.fromRGB(176, 186, 180)
local JADE = Color3.fromRGB(130, 230, 185)
local BOTTLENECK = Color3.fromRGB(255, 150, 110)
local COST_OK = "#F0D28C"
local COST_SHORT = "#FF826E"
local TITLES: { [Page]: string } = { Comprehend = "Comprehend", Method = "Method", Root = "Spirit Root" }
local NEXT_TIER: { [number]: string } = { [3] = "Tier II", [6] = "Tier III", [9] = "Mastery" }

local MeditationMenu = {}

local panel: Frame
local title: TextLabel
local list: ScrollingFrame
local template: GuiObject
local note: TextLabel
local page: Page = "Method"
local switching = false

-- Which tiles have something to show.
function MeditationMenu.relevant(): { [Page]: boolean }
	local methods = State.current.methods
	return {
		Comprehend = #Bottleneck.list() > 0,
		Method = methods ~= nil and next(methods.owned) ~= nil,
		Root = SelfCard.currentRoot() ~= nil,
	}
end

local function cost(need: number, have: number, what: string): string
	return `<font color="{if have >= need then COST_OK else COST_SHORT}">{need} {what}</font>`
end

type RowSpec = {
	icon: string,
	iconColor: Color3?,
	element: string?, -- paint the seal as this element (methods)
	name: string,
	nameColor: Color3,
	info: string,
	infoColor: Color3?,
	sub: string,
	blurb: string,
	action: string?, -- caption; nil hides the button
	ready: boolean?, -- jade and bright; else lacquer and dimmed
	onAction: (() -> ())?,
}

local function addRow(order: number, spec: RowSpec)
	local row = template:Clone()
	row.Name = "Row"
	row.LayoutOrder = order
	row.Visible = true
	local seal = row:FindFirstChild("Seal") :: Instance
	if spec.element then
		SelfCard.paintSeal(seal, spec.element)
	else
		local icon = seal:FindFirstChild("Icon") :: ImageLabel
		icon.Image = spec.icon
		icon.ImageColor3 = spec.iconColor or Color3.new(1, 1, 1);
		(seal:FindFirstChild("Glyph") :: GuiObject).Visible = false
	end
	local lines = row:FindFirstChild("Lines") :: Instance
	local name = (lines:FindFirstChild("Top") :: Instance):FindFirstChild("NameLabel") :: TextLabel
	name.Text = spec.name
	name.TextColor3 = spec.nameColor
	local info = lines:FindFirstChild("Info") :: TextLabel
	info.Text = spec.info
	info.TextColor3 = spec.infoColor or LIGHT;
	(lines:FindFirstChild("Sub") :: TextLabel).Text = spec.sub
	local blurb = lines:FindFirstChild("Blurb") :: TextLabel
	blurb.Text = spec.blurb
	blurb.Visible = spec.blurb ~= ""
	local button = row:FindFirstChild("Action") :: ImageButton
	button.Visible = spec.action ~= nil
	if spec.action then
		local label = button:FindFirstChild("Label") :: TextLabel
		label.Text = spec.action
		button.Image = if spec.ready then BUTTON_JADE else BUTTON_LACQUER
		button.ImageTransparency = if spec.ready then 0 else 0.3
		label.TextTransparency = if spec.ready then 0 else 0.3
		local onAction = spec.onAction
		if onAction then
			button.Activated:Connect(function()
				task.spawn(onAction)
			end)
		end
	end
	row.Parent = list
end

local function comprehendRows(): number
	local s = State.current
	local ids = Bottleneck.list()
	for i, id in ids do
		local def = Techniques.Defs[id] :: any
		local owned = s.techniques.owned[id]
		local gate = Bottleneck.gateOf(owned) :: Bottleneck.Gate
		local short = Bottleneck.block(gate)
		local insight, stones = s.insight or 0, Bottleneck.stones()
		addRow(i, {
			icon = def.icon,
			iconColor = def.color:Lerp(Color3.new(1, 1, 1), 0.35),
			name = def.name,
			nameColor = LIGHT,
			info = `Lv {owned.level} · bottleneck`,
			infoColor = BOTTLENECK,
			sub = `{cost(gate.insight, insight, "insight")} · {cost(gate.stones, stones, "Spirit Stones")}`,
			blurb = `Into {NEXT_TIER[owned.level] or "the next tier"}. You have {insight} insight, {stones} stones.`,
			action = if short then short else "Comprehend",
			ready = short == nil,
			onAction = function()
				Bottleneck.comprehend(id)
			end,
		})
	end
	return #ids
end

local function switchTo(id: string)
	if switching then
		return
	end
	switching = true
	local ok, message = cultivationRemote:InvokeServer("method", id)
	switching = false
	if not ok and message then
		Hud.toast(message)
	end
end

local function methodRows(): number
	local methods = State.current.methods
	if not methods then
		return 0
	end
	local n = 0
	for _, id in Methods.Order do
		if methods.owned[id] then
			n += 1
			local def = Methods.Defs[id]
			local qi, match, reaches = SelfCard.methodInfo(def)
			local active = methods.active == id
			addRow(if active then 0 else n, {
				icon = "",
				element = def.element,
				name = def.name,
				nameColor = SelfCard.gradeColor(def.grade),
				info = qi,
				infoColor = if match then JADE else LIGHT,
				sub = reaches,
				blurb = def.blurb,
				action = if active then "Active" else "Use",
				ready = not active,
				onAction = if active then nil else function()
					switchTo(id)
				end,
			})
		end
	end
	return n
end

local function rootRows(): number
	local root = SelfCard.currentRoot()
	if not root then
		return 0
	end
	local def = Roots.Elements[root.element]
	addRow(1, {
		icon = SelfCard.rootIcon(def.id),
		name = `{def.name} Root`,
		nameColor = def.color,
		info = `{root.grade} grade`,
		infoColor = SelfCard.gradeColor(root.grade),
		sub = def.blurb,
		blurb = "",
	})
	return 1
end

local function render()
	for _, child in list:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
	title.Text = TITLES[page]
	local count = if page == "Comprehend" then comprehendRows() elseif page == "Method" then methodRows() else rootRows()
	note.Visible = true
	if page == "Root" then
		local root = SelfCard.currentRoot()
		note.Text = if root then SelfCard.rootDetail(root) else ""
	elseif page == "Comprehend" and count == 0 then
		note.Text = "No technique is at a bottleneck. Practise your arts until one is."
	elseif page == "Method" and count == 0 then
		note.Text = "You know no cultivation method yet."
	elseif page == "Method" then
		note.Text = "Switching is free while you meditate."
	else
		note.Visible = false
	end
end

-- The list grows with its rows; its UISizeConstraint caps it and it scrolls.
local function fitList()
	local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
end

function MeditationMenu.open(which: Page)
	page = which
	render()
	list.CanvasPosition = Vector2.zero
	Menus.open(panel)
end

-- A tile: open its page, or close the panel if that page is already open.
function MeditationMenu.toggle(which: Page)
	if panel.Visible and page == which then
		Menus.close(panel)
	else
		MeditationMenu.open(which)
	end
end

function MeditationMenu.close()
	Menus.close(panel)
end

function MeditationMenu.init(gui: ScreenGui)
	panel = gui:FindFirstChild("MeditationPanel", true) :: Frame
	local body = panel:FindFirstChild("Body") :: Instance
	title = (body:FindFirstChild("Header") :: Instance):FindFirstChild("Title") :: TextLabel
	list = body:FindFirstChild("List") :: ScrollingFrame
	template = list:FindFirstChild("RowTemplate") :: GuiObject
	note = body:FindFirstChild("Note") :: TextLabel
	note.TextColor3 = DIM
	Menus.register(panel)
	ListWindow.bindClose(panel);
	(list:FindFirstChildOfClass("UIListLayout") :: UIListLayout):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitList)
	fitList()

	local function rerender()
		if panel.Visible then
			render()
		end
	end
	State.onChanged(function()
		rerender()
	end)
	for _, attr in { "Stones", "Root", "RootGrade", "Method" } do
		player:GetAttributeChangedSignal(attr):Connect(rerender)
	end
end

return MeditationMenu
