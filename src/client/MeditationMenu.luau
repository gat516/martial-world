--!strict
-- The meditation menu's small panel (Hud.MeditationPanel), opened from the
-- seated tiles (Meditation.luau). One page at a time, each a short list of rows
-- cloned from List.RowTemplate (seal, name, two lines, a blurb, an action):
--   Comprehend  techniques at a bottleneck (Bottleneck), their cost in insight
--               and Spirit Stones, and a Comprehend button that names what's
--               missing while it can't run.
--   Method      owned cultivation methods (Shared.Methods); Use switches
--               (CultivationAction "method"), the active one reads "Active".
--   Root        the spirit root's card and its exact numbers (Note), the same
--               text as the Self card, then a row per root pill the player holds
--               (Marrow Washing raises the grade, Root Rebirth reforms the
--               element; Absorb = InventoryAction "use", marked GuideKey
--               "RootPill" for the onboarding guide). While a reformed
--               element is pending it shows the old and the new root instead,
--               each with its choice (CultivationAction "root", keepNew).
-- The panel is a window (Menus): the seated row and the HUD step aside while it's
-- open, and its seal closes it. It is centred on screen like the other windows
-- (docs/systems/ui.md: menus go in the centre, not docked at the bottom).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
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
local inventoryRemote = ReplicatedStorage.Remotes.InventoryAction :: RemoteFunction
local player = Players.LocalPlayer

export type Page = "Comprehend" | "Method" | "Root"

-- button art (art/ui/assets.json): the kit's cloud-end tags, jade for the
-- suggested action, bronze for the rest (RowTemplate.Action slices them)
local BUTTON_JADE = "rbxassetid://101467676951805" -- ornament_tag_jade
local BUTTON_LACQUER = "rbxassetid://98060115715507" -- ornament_tag_bronze
local LIGHT = Color3.fromRGB(236, 232, 220)
local DIM = Color3.fromRGB(176, 186, 180)
local JADE = Color3.fromRGB(130, 230, 185)
local BOTTLENECK = Color3.fromRGB(255, 150, 110)
local COST_OK = "#F0D28C"
local COST_SHORT = "#FF826E"
local TITLES: { [Page]: string } = { Comprehend = "Comprehend", Method = "Method", Root = "Spirit Root" }
local PILLS = { "MarrowWashingPill", "RootRebirthPill" }
local PILL_SUB = { MarrowWashingPill = "Raise your root one grade", RootRebirthPill = "Reform as another element" }
local NEXT_TIER: { [number]: string } = { [3] = "Tier II", [6] = "Tier III", [9] = "Mastery" }

local MeditationMenu = {}

local panel: Frame
local title: TextLabel
local list: ScrollingFrame
local template: GuiObject
local note: TextLabel
local page: Page = "Method"
local switching = false -- a method switch, pill or root choice is on its way to the server

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
	plain: boolean?, -- lacquer but bright: a real choice that isn't the suggested one
	onAction: (() -> ())?,
	guideKey: string?, -- the onboarding guide can point at this row's button (Guide INSIDE)
	guideSay: string?, -- and the guide's callout line while it does
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
	button:SetAttribute("GuideKey", spec.guideKey)
	button:SetAttribute("GuideSay", spec.guideSay)
	if spec.action then
		local label = button:FindFirstChild("Label") :: TextLabel
		label.Text = spec.action
		local bright = spec.ready or spec.plain
		button.Image = if spec.ready then BUTTON_JADE else BUTTON_LACQUER
		button.ImageTransparency = if bright then 0 else 0.3
		label.TextTransparency = if bright then 0 else 0.3
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

-- One request at a time; a refusal toasts its reason (`always`: toast success too).
local function send(remote: RemoteFunction, always: boolean, ...: any)
	if switching then
		return
	end
	switching = true
	local ok, message = remote:InvokeServer(...)
	switching = false
	if message and (always or not ok) then
		Hud.toast(message)
	end
end

local function switchTo(id: string)
	send(cultivationRemote, false, "method", id)
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

-- One root as a row: its seal, name, grade and perk; `tag` leads the grade line.
local function rootRow(order: number, element: string, grade: string, tag: string, spec: { action: string?, ready: boolean?, plain: boolean?, onAction: (() -> ())? })
	local def = Roots.Elements[element]
	addRow(order, {
		icon = SelfCard.rootIcon(def.id),
		name = `{def.name} Root`,
		nameColor = def.color,
		info = `{tag}{grade} grade`,
		infoColor = SelfCard.gradeColor(grade),
		sub = def.blurb,
		blurb = "",
		action = spec.action,
		ready = spec.ready,
		plain = spec.plain,
		onAction = spec.onAction,
	})
end

-- The pending choice after a Root Rebirth Pill: the old root, then the new.
local function pendingRows(root: Roots.Root): number
	local old, new = Roots.Elements[root.element], Roots.Elements[root.pending]
	rootRow(1, root.element, root.grade, "Current · ", {
		action = `Return to {old.name}`,
		plain = true,
		onAction = function()
			send(cultivationRemote, false, "root", false)
		end,
	})
	rootRow(2, root.pending, Roots.gradeOf(root, root.pending), "New · ", {
		action = `Keep {new.name}`,
		ready = true,
		onAction = function()
			send(cultivationRemote, false, "root", true)
		end,
	})
	return 2
end

-- The root pills the player holds, each with Absorb (the server checks the seat).
local function pillRows(root: Roots.Root): number
	local items = State.current.items or {}
	local n = 0
	for i, id in PILLS do
		local count = items[id] or 0
		if count > 0 then
			n += 1
			local def = Items.Defs[id]
			local purest = id == "MarrowWashingPill" and Roots.nextGrade(root.grade) == nil
			addRow(10 + i, {
				icon = def.icon or "",
				name = def.name,
				nameColor = Items.Rarities[def.rarity].color,
				info = `Owned {count}`,
				sub = if purest then "Your root is at its purest." else PILL_SUB[id],
				blurb = "",
				action = if purest then nil else "Absorb",
				ready = true,
				guideKey = "RootPill",
				guideSay = if id == "MarrowWashingPill" then "Absorb it to purify your root" else "Absorb it to reform your root",
				onAction = function()
					send(inventoryRemote, false, "use", id)
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
	local live = State.current.root
	if live and live.pending ~= "" and Roots.Elements[live.pending] then
		return pendingRows(live)
	end
	rootRow(1, root.element, root.grade, "", {})
	return 1 + pillRows(root)
end

-- A reformed element is waiting for the player's choice.
function MeditationMenu.rootPending(): boolean
	local root = State.current.root
	return root ~= nil and root.pending ~= nil and root.pending ~= ""
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
		if MeditationMenu.rootPending() then
			note.Text = "Your root is reforming. Keep the new element, or return to the old. Each element keeps its own grade."
		elseif root and count <= 1 then
			note.Text = `{SelfCard.rootDetail(root)}\nRare pills can purify or reform your root.`
		else
			note.Text = if root then SelfCard.rootDetail(root) else ""
		end
	elseif page == "Comprehend" and count == 0 then
		note.Text = "No technique is at a bottleneck. Practice your arts until one is."
	elseif page == "Method" and count == 0 then
		note.Text = "You know no cultivation method yet."
	elseif page == "Method" then
		note.Text = "Switching is free while you meditate."
	else
		note.Visible = false
	end
end

-- The list grows with its rows; its UISizeConstraint caps it and it scrolls.
-- The canvas is set from the layout here: AutomaticCanvasSize doesn't count rows
-- that size themselves (AutomaticSize Y), so it stayed at the capped frame height
-- and everything past the first row or so was clipped with no way to scroll.
local function fitList()
	local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local height = layout.AbsoluteContentSize.Y
	list.Size = UDim2.new(1, 0, 0, height)
	list.CanvasSize = UDim2.fromOffset(0, height)
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
