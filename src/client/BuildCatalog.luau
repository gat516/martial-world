--!strict
-- The build catalog window (Hud.BuildBar), in two modes:
--   build  on your peak: pick an item you own and Place it; Store and Move are
--          in the header. Items you own none of say where to buy them.
--   shop   at the Spirit Market on the main peak: Buy items with Spirit Stones.
-- Both list every item (BuildItems.Order) with category tabs, a search box and an
-- Owned filter. Each tile shows its owned count, how many are placed (and the
-- limit), its cost, and a lock with the reason when it can't be used: a realm not
-- reached, none owned, or the peak's limit reached. The detail panel spells out
-- the item's placement rule and limits before you commit.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Config = require(ReplicatedStorage.Shared.Config).Build
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local MyPeak = require(script.Parent.MyPeak)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local buildRemote = ReplicatedStorage.Remotes.BuildAction :: RemoteFunction
local templates = ReplicatedStorage:WaitForChild("BuildCatalog")

local OK_COLOR = Color3.fromRGB(150, 230, 170)
local WARN_COLOR = Color3.fromRGB(240, 120, 100)
local NOTE_COLOR = Color3.fromRGB(230, 214, 170)
local COST_COLOR = Color3.fromRGB(240, 230, 200)

export type Mode = "build" | "shop"
export type Handlers = {
	place: (itemId: string) -> (),
	store: () -> (),
	move: () -> (),
	closed: () -> (), -- the window closed in build mode (not by handing off)
}

local BuildCatalog = {}

local bar: Frame
local catalog: ScrollingFrame
local detail: GuiObject
local search: TextBox
local ownedToggle: GuiButton
local handlers: Handlers
local mode: Mode = "build"
local category = "All"
local ownedOnly = false
local selected: string? = nil
local handingOff = false
local tiles: { [string]: GuiButton } = {}
local tabs: { [string]: GuiButton } = {}

local function find(root: Instance, name: string): any
	return root:FindFirstChild(name, true)
end

-- `Selected` is also a GuiObject property, so always look the child up by name.
local function setSelected(button: Instance, on: boolean)
	(button:FindFirstChild("Selected") :: GuiObject).Visible = on
end

local function realm(): { major: string, minor: number }
	local name = player:GetAttribute("Realm")
	for _, s in Realms.Stages do
		if s.name == name then
			return { major = s.major, minor = s.minor }
		end
	end
	return { major = "QiCondensation", minor = 1 }
end

local function stones(): number
	return (player:GetAttribute("Stones") :: number?) or 0
end

-- Pieces of each item standing on your peak (placed copies and starters).
local function placedCounts(): { [string]: number }
	local counts: { [string]: number } = {}
	local peak = MyPeak.model()
	if peak then
		for _, d in peak:GetDescendants() do
			local id = d:GetAttribute("ItemId")
			if type(id) == "string" and (d:GetAttribute("PlacedId") or d:GetAttribute("StarterId")) then
				counts[id] = (counts[id] or 0) + 1
			end
		end
	end
	return counts
end

-- How an item is placed, in a few words.
function BuildCatalog.ruleText(def: BuildItems.Def): string
	local parts = {}
	local on = def.on
	if table.find(on, "floor") then
		table.insert(parts, "Floor")
	elseif table.find(on, "terrain") then
		table.insert(parts, "Ground only")
	end
	if table.find(on, "wall") then
		table.insert(parts, "Wall")
	end
	if table.find(on, "ceiling") then
		table.insert(parts, "Ceiling")
	end
	if table.find(on, "socket") then
		table.insert(parts, "Table tops")
	end
	if def.stack then
		table.insert(parts, "stacks")
	end
	if def.top then
		table.insert(parts, "holds items")
	end
	if def.edges then
		table.insert(parts, "joins end to end")
	end
	if def.free then
		table.insert(parts, "free placement")
	end
	if def.lift then
		table.insert(parts, `lifts {def.lift} studs`)
	end
	return table.concat(parts, " · ")
end

type Status = { locked: string?, note: string?, color: Color3, canBuy: boolean, canPlace: boolean }

local function statusOf(def: BuildItems.Def, owned: number, placed: number): Status
	if mode == "shop" then
		local ok, need = BuildItems.unlocked(def, realm())
		if not ok then
			return { locked = need, note = `Unlocks at {need}`, color = WARN_COLOR, canBuy = false, canPlace = false }
		end
		if stones() < def.cost then
			return { note = `You need {def.cost - stones()} more Spirit Stones`, color = WARN_COLOR, canBuy = false, canPlace = false }
		end
		return { note = if owned > 0 then `You own {owned}` else nil, color = NOTE_COLOR, canBuy = true, canPlace = false }
	end
	if def.limit and placed >= def.limit then
		return { locked = "Limit", note = `Your peak holds at most {def.limit}`, color = WARN_COLOR, canBuy = false, canPlace = false }
	end
	if owned < 1 then
		return { locked = "Market", note = "Buy more at the Spirit Market on the main peak", color = WARN_COLOR, canBuy = false, canPlace = false }
	end
	return { note = `{owned} ready to place`, color = OK_COLOR, canBuy = false, canPlace = true }
end

local function matches(def: BuildItems.Def, owned: number): boolean
	if category ~= "All" and def.category ~= category then
		return false
	end
	if ownedOnly and owned < 1 then
		return false
	end
	local q = string.lower(search.Text)
	if q ~= "" then
		local hay = string.lower(`{def.name} {def.category} {def.description}`)
		return string.find(hay, q, 1, true) ~= nil
	end
	return true
end

local function showDetail()
	local def = selected and BuildItems.Defs[selected]
	detail.Visible = def ~= nil
	if not def then
		return
	end
	local owned = (State.current.decor or {})[def.id] or 0
	local placed = placedCounts()[def.id] or 0
	local status = statusOf(def, owned, placed)
	find(detail, "NameLabel").Text = def.name
	find(detail, "DescLabel").Text = def.description
	local limit = if def.limit then `{placed}/{def.limit} placed` else `{placed} placed`
	find(detail, "InfoLabel").Text = `{BuildCatalog.ruleText(def)}\nOwned {owned} · {limit} · peak cap {Config.MAX_ITEMS}`
	local statusLabel = find(detail, "StatusLabel") :: TextLabel
	statusLabel.Text = status.note or ""
	statusLabel.TextColor3 = status.color
	local buy = find(detail, "BuyButton") :: GuiButton
	local placeButton = find(detail, "PlaceButton") :: GuiButton
	buy.Visible = mode == "shop"
	placeButton.Visible = mode == "build"
	find(buy, "Label").Text = `Buy  {def.cost}`
	buy.AutoButtonColor = status.canBuy;
	(buy :: any).ImageTransparency = if status.canBuy then 0 else 0.45;
	(placeButton :: any).ImageTransparency = if status.canPlace then 0 else 0.45
end

function BuildCatalog.refresh()
	if not bar then
		return
	end
	find(bar, "StonesLabel").Text = tostring(stones())
	local decor = State.current.decor or {}
	local placed = placedCounts()
	for id, tile in tiles do
		local def = BuildItems.Defs[id]
		local owned = decor[id] or 0
		local count = placed[id] or 0
		local status = statusOf(def, owned, count)
		tile.Visible = matches(def, owned)
		local countLabel = find(tile, "CountLabel") :: TextLabel
		countLabel.Text = `x{owned}`
		countLabel.Visible = owned > 0
		local placedLabel = find(tile, "PlacedLabel") :: TextLabel
		placedLabel.Text = if def.limit then `{count}/{def.limit}` else tostring(count)
		placedLabel.Visible = mode == "build" and (count > 0 or def.limit ~= nil)
		local cost = find(tile, "CostLabel") :: TextLabel
		cost.Text = tostring(def.cost)
		cost.TextColor3 = if stones() >= def.cost then COST_COLOR else WARN_COLOR
		cost.Visible = mode == "shop"
		find(tile, "CostIcon").Visible = mode == "shop"
		local lock = find(tile, "LockOverlay") :: GuiObject
		lock.Visible = status.locked ~= nil
		find(lock, "LockLabel").Text = status.locked or ""
		setSelected(tile, id == selected)
	end
	showDetail()
end

local function select(id: string)
	selected = id
	BuildCatalog.refresh()
end

local function setCategory(name: string)
	category = name
	for c, tab in tabs do
		setSelected(tab, c == name)
	end
	catalog.CanvasPosition = Vector2.zero
	BuildCatalog.refresh()
end

local function previewInto(viewport: ViewportFrame, template: Model)
	local model = template:Clone()
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.8, 1).Unit * size.Magnitude * 1.25, cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function buy()
	local def = selected and BuildItems.Defs[selected]
	if not def then
		return
	end
	local ok, message = buildRemote:InvokeServer("buy", { item = def.id, count = 1 })
	if message then
		Hud.toast(message)
	end
	if ok then
		Motion.pulse(find(detail, "BuyButton"))
		task.delay(0.25, function()
			Motion.stopPulse(find(detail, "BuyButton"))
		end)
	end
end

local function place()
	local def = selected and BuildItems.Defs[selected]
	if not def then
		return
	end
	local status = statusOf(def, (State.current.decor or {})[def.id] or 0, placedCounts()[def.id] or 0)
	if not status.canPlace then
		Hud.toast(status.note or "You can't place that")
		return
	end
	handlers.place(def.id)
end

function BuildCatalog.open(m: Mode)
	mode = m
	find(bar, "Title").Text = if m == "shop" then "Spirit Market" else "Build"
	find(bar, "Actions").Visible = m == "build"
	BuildCatalog.refresh()
	Menus.open(bar)
end

function BuildCatalog.isOpen(): boolean
	return bar.Visible
end

function BuildCatalog.mode(): Mode
	return mode
end

-- Hide the window because the placement controls are taking over (not a close).
function BuildCatalog.handOff()
	handingOff = true
end

function BuildCatalog.close()
	Menus.close(bar)
end

function BuildCatalog.init(gui: ScreenGui, h: Handlers)
	handlers = h
	bar = gui:FindFirstChild("BuildBar") :: Frame
	catalog = find(bar, "Catalog")
	detail = find(bar, "Detail")
	search = find(bar, "SearchBox")
	ownedToggle = find(bar, "OwnedToggle")

	Menus.register(bar, {
		close = function()
			Motion.close(bar)
			if handingOff then
				handingOff = false
			elseif mode == "build" then
				handlers.closed()
			end
		end,
	})

	-- category tabs
	local tabTemplate = find(bar, "TabTemplate") :: GuiButton
	local names = { "All", table.unpack(BuildItems.Categories) }
	for i, name in names do
		local tab = tabTemplate:Clone()
		tab.Name = name
		tab.LayoutOrder = i
		find(tab, "Label").Text = if name == "All" then "All" else BuildItems.CategoryNames[name]
		tab.Visible = true
		tab.Activated:Connect(function()
			setCategory(name)
		end)
		tab.Parent = tabTemplate.Parent
		tabs[name] = tab
	end

	-- one tile per item
	local itemTemplate = find(catalog, "ItemTemplate") :: GuiButton
	for _, id in BuildItems.Order do
		local def = BuildItems.Defs[id]
		local template = templates:FindFirstChild(id) :: Model?
		if template then
			local tile = itemTemplate:Clone()
			tile.Name = id
			tile.LayoutOrder = def.order
			find(tile, "NameLabel").Text = def.name
			local icon = find(tile, "Icon") :: ImageLabel
			local preview = find(tile, "Preview") :: ViewportFrame
			if def.icon then
				icon.Image = def.icon
				icon.Visible = true
				preview.Visible = false
			else
				previewInto(preview, template)
			end
			local lastTap = 0
			tile.Activated:Connect(function()
				-- a second tap on the selected tile places (build) or buys (shop)
				local again = selected == id and os.clock() - lastTap < 0.5
				lastTap = os.clock()
				select(id)
				if again then
					if mode == "shop" then
						buy()
					else
						place()
					end
				end
			end)
			tile.Parent = catalog
			tiles[id] = tile
		end
	end
	setCategory("All")

	search:GetPropertyChangedSignal("Text"):Connect(BuildCatalog.refresh)
	ownedToggle.Activated:Connect(function()
		ownedOnly = not ownedOnly
		setSelected(ownedToggle, ownedOnly)
		BuildCatalog.refresh()
	end)
	setSelected(ownedToggle, false)
	find(detail, "BuyButton").Activated:Connect(buy)
	find(detail, "PlaceButton").Activated:Connect(place)
	find(bar, "StoreButton").Activated:Connect(function()
		handlers.store()
	end)
	find(bar, "MoveButton").Activated:Connect(function()
		handlers.move()
	end)
	find(bar, "DoneButton").Activated:Connect(BuildCatalog.close)

	State.onChanged(function()
		if bar.Visible then
			BuildCatalog.refresh()
		end
	end)
	player:GetAttributeChangedSignal("Stones"):Connect(function()
		if bar.Visible then
			BuildCatalog.refresh()
		end
	end)

	-- the Spirit Market stall on the main peak opens the shop
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "MarketPrompt" then
			BuildCatalog.open("shop")
		end
	end)
	detail.Visible = false
end

return BuildCatalog
