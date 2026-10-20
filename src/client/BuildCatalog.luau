--!strict
-- The build catalog window (Hud.BuildBar), in two modes:
--   build  on your peak (the Place tab of build mode): pick an item and Place it.
--          Items you own none of show their cost and the main button reads
--          "Buy & Place": it buys one (anywhere) and goes straight to placing.
--   shop   from the Spirit Market stall on the main peak: Buy only. Closes when
--          you walk out of range of the stall.
-- Both list every item (BuildItems.Order) with category tabs, a search box and an
-- Owned filter. Each tile shows a 3D preview, its owned count, how many are placed
-- (and the limit), its cost, a badge for its main benefit, and a lock with the
-- reason when it can't be used: a realm not reached or the peak's limit reached.
-- The detail panel shows a big slowly turning preview, every benefit, the
-- placement rule and limits before you commit. Store and Move live in build
-- mode's banner (BuildMode), not here.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Config = require(ReplicatedStorage.Shared.Config).Build
local Hud = require(script.Parent.Hud)
local MarketRange = require(script.Parent.MarketRange)
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
local SPIN_SPEED = 0.35 -- radians per second, detail preview

export type Mode = "build" | "shop"
export type Handlers = {
	place: (itemId: string) -> (),
	closed: () -> (), -- the window closed in build mode (not by handing off)
}

local BuildCatalog = {}

local bar: Frame
local catalog: ScrollingFrame
local detail: GuiObject
local search: TextBox
local ownedToggle: GuiButton?
local handlers: Handlers
local mode: Mode = "build"
local category = "All"
local ownedOnly = false
local selected: string? = nil
local handingOff = false
local shopPlace: { anchor: Vector2, position: UDim2, size: UDim2 } -- authored: centred
local busy = false
local tiles: { [string]: GuiButton } = {}
local tabs: { [string]: GuiButton } = {}

-- the detail panel's turning preview
local detailViewport: ViewportFrame? = nil
local detailShown: string? = nil
local detailCamera: Camera? = nil
local detailFocus = Vector3.zero
local detailRadius = 1
local detailHeight = 0
local detailAngle = math.rad(45)

local function find(root: Instance, name: string): any
	return root:FindFirstChild(name, true)
end

-- `Selected` is also a GuiObject property, so always look the child up by name.
local function setSelected(button: Instance, on: boolean)
	local sel = button:FindFirstChild("Selected") :: GuiObject?
	if sel then
		sel.Visible = on
	end
end

local function setText(root: Instance, name: string, text: string)
	local label = find(root, name) :: TextLabel?
	if label then
		label.Text = text
	end
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

local function pct(n: number): string
	return `{math.floor(n * 100 + 0.5)}%`
end

local function soilName(soil: string): string
	local info = (Herbs.Soils :: any)[soil]
	return if info then info.name else soil
end

local function soilPlants(soil: string): string
	local names = {}
	for _, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		if herb and herb.soil == soil then
			table.insert(names, herb.name)
		end
		if #names >= 3 then
			break
		end
	end
	return table.concat(names, ", ")
end

-- Every benefit of an item, one line each.
function BuildCatalog.benefits(def: BuildItems.Def): { string }
	local lines = {}
	if def.soil then
		local plants = soilPlants(def.soil)
		table.insert(lines, `Plot: grows {string.lower(soilName(def.soil))} seeds{if plants ~= "" then ` ({plants}…)` else ""}`)
	end
	if def.meditation then
		table.insert(lines, `+{def.meditation} meditation nearby`)
	end
	local g = def.garden
	if g then
		if g.growth then
			table.insert(lines, `Plants within {g.radius} studs grow +{pct(g.growth)} faster`)
		end
		if g.luck then
			table.insert(lines, `+{pct(g.luck)} mutation chance within {g.radius} studs`)
		end
	end
	return lines
end

-- The one benefit a tile's badge shows (the detail panel lists them all).
function BuildCatalog.badge(def: BuildItems.Def): string?
	if def.soil then
		return "Plot"
	elseif def.meditation then
		return `Med +{def.meditation}`
	elseif def.garden and def.garden.growth then
		return `Grow +{pct(def.garden.growth)}`
	elseif def.garden and def.garden.luck then
		return `Luck +{pct(def.garden.luck)}`
	end
	return nil
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

type Status = { locked: string?, note: string?, color: Color3, canBuy: boolean, canPlace: boolean, needsBuy: boolean }

local function statusOf(def: BuildItems.Def, owned: number, placed: number): Status
	local ok, need = BuildItems.unlocked(def, realm())
	if not ok then
		return { locked = need, note = `Unlocks at {need}`, color = WARN_COLOR, canBuy = false, canPlace = false, needsBuy = owned < 1 }
	end
	local affordable = stones() >= def.cost
	if mode == "shop" then
		if not affordable then
			return { note = `You need {def.cost - stones()} more Spirit Stones`, color = WARN_COLOR, canBuy = false, canPlace = false, needsBuy = true }
		end
		return { note = if owned > 0 then `You own {owned}` else nil, color = NOTE_COLOR, canBuy = true, canPlace = false, needsBuy = true }
	end
	if def.limit and placed >= def.limit then
		return { locked = "Limit", note = `Your peak holds at most {def.limit}`, color = WARN_COLOR, canBuy = false, canPlace = false, needsBuy = owned < 1 }
	end
	if owned < 1 then
		if not affordable then
			return { note = `You need {def.cost - stones()} more Spirit Stones`, color = WARN_COLOR, canBuy = false, canPlace = false, needsBuy = true }
		end
		return { note = `Buy one for {def.cost} Spirit Stones and place it`, color = NOTE_COLOR, canBuy = true, canPlace = true, needsBuy = true }
	end
	return { note = `{owned} ready to place`, color = OK_COLOR, canBuy = affordable, canPlace = true, needsBuy = false }
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

-- Fill a viewport with a clone of the item's model and a camera looking at it.
local function previewInto(viewport: ViewportFrame, template: Model): (Camera, Vector3, number)
	local model = template:Clone()
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = size.Magnitude * 1.25
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.8, 1).Unit * distance, cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera, cf.Position, distance
end

local function showPreview(def: BuildItems.Def)
	local viewport = detailViewport
	if not viewport or detailShown == def.id then
		return
	end
	detailShown = def.id
	viewport:ClearAllChildren()
	detailCamera = nil
	local template = templates:FindFirstChild(def.id) :: Model?
	if template then
		local camera, focus, distance = previewInto(viewport, template)
		detailCamera = camera
		detailFocus = focus
		local flat = Vector3.new(1, 0.8, 1).Unit * distance
		detailRadius = Vector2.new(flat.X, flat.Z).Magnitude
		detailHeight = flat.Y
		detailAngle = math.rad(45)
	end
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
	showPreview(def)
	setText(detail, "NameLabel", def.name)
	setText(detail, "DescLabel", def.description)
	local benefits = BuildCatalog.benefits(def)
	local benefitLabel = find(detail, "Benefits") :: TextLabel?
	if benefitLabel then
		benefitLabel.Text = table.concat(benefits, "\n")
		benefitLabel.Visible = #benefits > 0
	end
	local limit = if def.limit then `{placed}/{def.limit} placed` else `{placed} placed`
	setText(detail, "InfoLabel", `{BuildCatalog.ruleText(def)}\nOwned {owned} · {limit} · peak cap {Config.MAX_ITEMS}`)
	local statusLabel = find(detail, "StatusLabel") :: TextLabel?
	if statusLabel then
		statusLabel.Text = status.note or ""
		statusLabel.TextColor3 = status.color
	end
	local buyButton = find(detail, "BuyButton") :: GuiButton?
	local placeButton = find(detail, "PlaceButton") :: GuiButton?
	if buyButton then
		buyButton.Visible = mode == "shop"
		setText(buyButton, "Label", "Buy")
		setText(buyButton, "CostLabel", tostring(def.cost));
		(buyButton :: any).ImageTransparency = if status.canBuy then 0 else 0.45
	end
	if placeButton then
		placeButton.Visible = mode == "build"
		setText(placeButton, "Label", if status.needsBuy then "Buy & Place" else "Place")
		setText(placeButton, "CostLabel", tostring(def.cost))
		local icon, cost = find(placeButton, "CostIcon") :: GuiObject?, find(placeButton, "CostLabel") :: GuiObject?
		if icon then
			icon.Visible = status.needsBuy
		end
		if cost then
			cost.Visible = status.needsBuy
		end
		(placeButton :: any).ImageTransparency = if status.canPlace then 0 else 0.45
	end
end

function BuildCatalog.refresh()
	if not bar then
		return
	end
	setText(bar, "StonesLabel", tostring(stones()))
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
		-- the cost shows whenever buying is the way to get one
		local showCost = mode == "shop" or owned < 1
		local cost = find(tile, "CostLabel") :: TextLabel
		cost.Text = tostring(def.cost)
		cost.TextColor3 = if stones() >= def.cost then COST_COLOR else WARN_COLOR
		cost.Visible = showCost
		find(tile, "CostIcon").Visible = showCost
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

-- Buy `count` of the selected item. Returns whether it went through.
local function buy(): boolean
	local def = selected and BuildItems.Defs[selected]
	if not def or busy then
		return false
	end
	busy = true
	local ok, message = buildRemote:InvokeServer("buy", { item = def.id, count = 1 })
	busy = false
	if message then
		Hud.toast(message)
	end
	local button = find(detail, if mode == "shop" then "BuyButton" else "PlaceButton") :: GuiObject?
	if ok and button then
		Motion.pulse(button)
		task.delay(0.25, function()
			Motion.stopPulse(button)
		end)
	end
	return ok == true
end

local function place()
	local def = selected and BuildItems.Defs[selected]
	if not def or busy then
		return
	end
	local owned = (State.current.decor or {})[def.id] or 0
	local status = statusOf(def, owned, placedCounts()[def.id] or 0)
	if not status.canPlace then
		Hud.toast(status.note or "You can't place that")
		return
	end
	if status.needsBuy and not buy() then
		return
	end
	handlers.place(def.id)
end

function BuildCatalog.open(m: Mode)
	mode = m
	local title = find(bar, "Title") :: TextLabel?
	if title then
		title.Text = if m == "shop" then "Spirit Market" else "Place"
	end
	if ownedToggle then
		ownedToggle.Visible = true
	end
	-- the shop sits centred (as authored); in build mode the window sits low,
	-- under the build banner, whose tabs stay usable
	if m == "shop" then
		bar.AnchorPoint, bar.Position, bar.Size = shopPlace.anchor, shopPlace.position, shopPlace.size
	else
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -8)
		bar.Size = UDim2.new(shopPlace.size.X, UDim.new(0.8, 0))
	end
	BuildCatalog.refresh()
	Menus.open(bar)
end

function BuildCatalog.isOpen(): boolean
	return bar ~= nil and bar.Visible
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
	local well = find(detail, "Well") :: Instance?
	detailViewport = well and well:FindFirstChild("Preview") :: ViewportFrame?
	shopPlace = { anchor = bar.AnchorPoint, position = bar.Position, size = bar.Size }

	Menus.register(bar, {
		coversTiles = true,
		close = function()
			Motion.close(bar)
			if handingOff then
				handingOff = false
			elseif mode == "build" then
				handlers.closed()
			end
		end,
	});
	(bar:FindFirstChild("Close") :: GuiButton).Activated:Connect(function()
		Menus.close(bar)
	end)

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
			local badge = find(tile, "Badge") :: GuiObject?
			local badgeText = BuildCatalog.badge(def)
			if badge then
				badge.Visible = badgeText ~= nil
				setText(badge, "Label", badgeText or "")
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
	if ownedToggle then
		local toggle = ownedToggle
		toggle.Activated:Connect(function()
			ownedOnly = not ownedOnly
			setSelected(toggle, ownedOnly)
			BuildCatalog.refresh()
		end)
		setSelected(toggle, false)
	end
	local buyButton = find(detail, "BuyButton") :: GuiButton?
	if buyButton then
		buyButton.Activated:Connect(buy)
	end
	local placeButton = find(detail, "PlaceButton") :: GuiButton?
	if placeButton then
		placeButton.Activated:Connect(place)
	end

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

	-- the detail preview turns slowly while the window is up
	RunService.RenderStepped:Connect(function(dt)
		local camera = detailCamera
		if not (camera and bar.Visible and detail.Visible) then
			return
		end
		detailAngle += dt * SPIN_SPEED
		local offset = Vector3.new(math.cos(detailAngle) * detailRadius, detailHeight, math.sin(detailAngle) * detailRadius)
		camera.CFrame = CFrame.lookAt(detailFocus + offset, detailFocus)
	end)

	-- the Spirit Market stall on the main peak opens the shop; leaving it closes it
	MarketRange.watch(function()
		return mode == "shop" and BuildCatalog.isOpen()
	end, BuildCatalog.close)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "MarketPrompt" then
			BuildCatalog.open("shop")
		end
	end)
	detail.Visible = false
end

return BuildCatalog
