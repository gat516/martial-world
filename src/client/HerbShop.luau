--!strict
-- The Herbalist's window (Hud.HerbShop), opened from the Herbalist prompt at the
-- Spirit Market on the main peak. Two tabs:
--   Buy Seeds   every herb with a seedCost: Buy 1 / Buy 5
--   Sell Herbs  every herb you hold, at its sellPrice: Sell 1 / Sell all of it,
--               plus Sell everything in the footer
-- The Spirit Stones total sits in the header. Rows rebuild whenever State or the
-- Stones attribute changes. The server checks range and prices; its message is
-- toasted either way. Walking out of range of the stall closes the window.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local HerbArt = require(script.Parent.HerbArt)
local Hud = require(script.Parent.Hud)
local MarketRange = require(script.Parent.MarketRange)
local Menus = require(script.Parent.Menus)
local SeedPicker = require(script.Parent.SeedPicker)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local gardenRemote = ReplicatedStorage.Remotes.GardenAction :: RemoteFunction

local WARN_COLOR = Color3.fromRGB(240, 120, 100)
local PRICE_COLOR = Color3.fromRGB(206, 246, 222)

type Tab = "buy" | "sell"

local HerbShop = {}

local window: Frame
local list: ScrollingFrame
local template: ImageLabel
local empty: TextLabel
local note: TextLabel
local sellAll: GuiButton
local tabs: { [Tab]: GuiButton } = {}
local tab: Tab = "buy"
local busy = false

local function stones(): number
	return (player:GetAttribute("Stones") :: number?) or 0
end

local function label(button: Instance): TextLabel
	return button:FindFirstChild("Label") :: TextLabel
end

local function find(root: Instance, name: string): any
	return root:FindFirstChild(name, true)
end

-- Ask the server, toast its answer. One request at a time.
local function act(...: any)
	if busy then
		return
	end
	busy = true
	local ok, _, message = pcall(function(...)
		return gardenRemote:InvokeServer(...)
	end, ...)
	busy = false
	if ok and message then
		Hud.toast(message)
	elseif not ok then
		Hud.toast("The Herbalist is busy. Try again.")
	end
end

local function paintRow(row: Instance, id: string)
	HerbArt.paint(row:FindFirstChild("Swatch") :: Instance, id)
	local gem = row:FindFirstChild("Gem") :: ImageLabel?
	if gem then
		HerbArt.gem(gem, Herbs.Defs[id].rarity)
	end
end

local function setButton(button: GuiButton, text: string, enabled: boolean)
	label(button).Text = text;
	(button :: any).ImageTransparency = if enabled then 0 else 0.45
	label(button).TextTransparency = if enabled then 0 else 0.35
	button.Active = enabled
end

local function addRow(order: number, id: string, detail: string, price: number, affordable: boolean)
	local herb = Herbs.Defs[id]
	local row = template:Clone()
	row.Name = "Row"
	row.LayoutOrder = order
	paintRow(row, id)
	find(row, "NameLabel").Text = herb.name
	find(row, "Detail").Text = detail
	local priceLabel = find(row, "PriceLabel") :: TextLabel
	priceLabel.Text = tostring(price)
	priceLabel.TextColor3 = if affordable then PRICE_COLOR else WARN_COLOR
	row.Visible = true
	row.Parent = list
	return row
end

function HerbShop.refresh()
	if not window then
		return
	end
	find(window, "StonesLabel").Text = tostring(stones())
	for t, button in tabs do
		(button:FindFirstChild("Selected") :: GuiObject).Visible = t == tab;
		-- ruby plaque idle, gold plaque chosen: the label turns gold too
		(button:FindFirstChild("Label") :: TextLabel).TextColor3 = if t == tab
			then Color3.fromRGB(255, 208, 112)
			else Color3.fromRGB(250, 236, 195)
	end
	for _, child in list:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
	local count = 0
	local total = 0
	for i, id in Herbs.Order do
		local herb = Herbs.Defs[id]
		if not herb then
			continue
		end
		if tab == "buy" and herb.seedCost then
			local cost = herb.seedCost :: number
			local soil = (Herbs.Soils :: any)[herb.soil]
			local owned = State.current.seeds[id] or 0
			local have = if owned > 0 then ` · {owned} seeds` else ""
			local row = addRow(i, id, `{herb.rarity} · {soil and soil.name or herb.soil} · {SeedPicker.growLabel(id)}{have}`, cost, stones() >= cost)
			local one, many = find(row, "OneButton") :: GuiButton, find(row, "ManyButton") :: GuiButton
			setButton(one, "Buy 1", stones() >= cost)
			setButton(many, "Buy 5", stones() >= cost * 5)
			one.Activated:Connect(function()
				act("buySeed", id, 1)
			end)
			many.Activated:Connect(function()
				act("buySeed", id, 5)
			end)
			count += 1
		elseif tab == "sell" then
			local held = State.current.herbs[id] or 0
			if held > 0 then
				total += held * herb.sellPrice
				local row = addRow(i, id, `{herb.rarity} · you hold {held}`, herb.sellPrice, true)
				local one, many = find(row, "OneButton") :: GuiButton, find(row, "ManyButton") :: GuiButton
				setButton(one, "Sell 1", true)
				setButton(many, `Sell {held}`, true)
				one.Activated:Connect(function()
					act("sell", id, 1)
				end)
				many.Activated:Connect(function()
					act("sell", id, held)
				end)
				count += 1
			end
		end
	end
	empty.Visible = count == 0
	empty.Text = if tab == "sell" then "No herbs to sell. Harvest your garden first." else "The Herbalist has no seeds today."
	sellAll.Visible = tab == "sell"
	setButton(sellAll, `Sell everything · {total}`, total > 0)
	note.Visible = tab == "buy"
end

local function setTab(t: Tab)
	tab = t
	list.CanvasPosition = Vector2.zero
	HerbShop.refresh()
end

function HerbShop.open()
	HerbShop.refresh()
	Menus.open(window)
end

function HerbShop.init(gui: ScreenGui)
	window = gui:FindFirstChild("HerbShop") :: Frame
	list = window:FindFirstChild("List") :: ScrollingFrame
	template = list:FindFirstChild("RowTemplate") :: ImageLabel
	empty = window:FindFirstChild("Empty") :: TextLabel
	local footer = window:FindFirstChild("Footer") :: Frame
	note = footer:FindFirstChild("Note") :: TextLabel
	sellAll = footer:FindFirstChild("SellAllButton") :: GuiButton
	local header = window:FindFirstChild("Header") :: Frame
	tabs.buy = header:FindFirstChild("BuyTab") :: GuiButton
	tabs.sell = header:FindFirstChild("SellTab") :: GuiButton

	Menus.register(window);
	(window:FindFirstChild("Close") :: GuiButton).Activated:Connect(function()
		Menus.close(window)
	end)
	tabs.buy.Activated:Connect(function()
		setTab("buy")
	end)
	tabs.sell.Activated:Connect(function()
		setTab("sell")
	end)
	sellAll.Activated:Connect(function()
		if sellAll.Active then
			act("sellAll")
		end
	end)

	State.onChanged(function()
		if window.Visible then
			HerbShop.refresh()
		end
	end)
	player:GetAttributeChangedSignal("Stones"):Connect(function()
		if window.Visible then
			HerbShop.refresh()
		end
	end)
	MarketRange.watch(function()
		return window.Visible
	end, function()
		Menus.close(window)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "Herbalist" then
			HerbShop.open()
		end
	end)
end

return HerbShop
