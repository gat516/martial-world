--!strict
-- The Herbarium (StarterGui.Herbarium, assets/Herbarium.rbxmx): the collection
-- book of every herb, roadmap §5 / Phase B. A ready-to-wire component: the real
-- system (herb tiers and the collection record) isn't built yet, so nothing in
-- the game opens it; its owner calls Herbarium.open with the player's entries.
-- Contract and layout: docs/ui/herbarium.md.
--
--   Herbarium.open({ entries = { Entry, ... }, title = "Herbarium"? })
--   Herbarium.close()
--   Herbarium.isOpen()
--   Herbarium.preview()   sample book (every herb in Herbs.Order plus a few
--                         undiscovered pages), from the client console in play:
--     require(game.Players.LocalPlayer.PlayerScripts.Client.Herbarium).preview()
--
-- The open book shows six herb cards per page, twelve per spread, in the order
-- given: a discovered herb's card has its art, tier shield (I-V), name, rarity
-- gem, how many were harvested, the largest size seen and the mutations seen
-- (kit tag ribbons, one row); an undiscovered one is the greyed card with a
-- question mark and its tier. The seals on the book's edges turn the spread.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local HerbArt = require(script.Parent.HerbArt)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Ribbon = require(script.Parent.Ribbon)
local UiScale = require(script.Parent.UiScale)

export type Entry = {
	herb: string, -- Herbs.Defs id: name, rarity and art come from the defs
	tier: number, -- herb tier 1-5 (I bronze, II silver, III gold, IV jade, V violet)
	discovered: boolean,
	harvested: number?, -- total ever harvested
	largest: number?, -- the biggest size seen (×)
	mutations: { string }?, -- Herbs.Mutations ids seen on this herb
	name: string?, -- overrides the def's name (a herb not in Herbs.Defs yet)
}
export type Book = { entries: { Entry }, title: string? }

local PER_PAGE = 6
local TITLE_SIZE = 22 -- the title on its plaque (Merriweather Bold), baseline pixels
local CARD = "rbxassetid://128801964051831" -- C1 herb_card
local CARD_EMPTY = "rbxassetid://139968594156334" -- C1 herb_card_empty
local INK = Color3.fromRGB(62, 38, 18)
local FADED = Color3.fromRGB(110, 106, 100)
local GREY = Color3.fromRGB(150, 150, 150)
local WHITE = Color3.new(1, 1, 1)
local OFF_TRANSPARENCY = 0.6 -- a page-turn seal with nowhere to go

local Herbarium = {}

local window: Frame
local pages: { Frame }
local template: GuiButton
local footer: TextLabel
local title: TextLabel
local prev: GuiButton
local nextButton: GuiButton
local book: Book = { entries = {} }
local spread = 1
local phone = false -- phone cards are about 80x125: one stat line, smaller rarity text

local function find(root: Instance, name: string): any
	return root:FindFirstChild(name, true)
end

local function rarityOf(entry: Entry): string
	local herb = Herbs.Defs[entry.herb]
	return if herb then herb.rarity else "Common"
end

local function fillCard(card: GuiButton, entry: Entry)
	local tier = HerbArt.Tiers[math.clamp(entry.tier, 1, #HerbArt.Tiers)]
	local shield = card:FindFirstChild("Tier") :: ImageLabel
	shield.Image = tier.image
	shield.ImageColor3 = if entry.discovered then WHITE else GREY;
	(shield:FindFirstChild("Numeral") :: TextLabel).Text = tier.numeral

	local name = card:FindFirstChild("NameLabel") :: TextLabel
	local art = card:FindFirstChild("Art") :: Frame
	local swatch = art:FindFirstChild("Swatch") :: ImageLabel
	local unknown = art:FindFirstChild("Unknown") :: ImageLabel
	local tags = card:FindFirstChild("Tags") :: Frame
	local found = entry.discovered;
	(card :: any).Image = if found then CARD else CARD_EMPTY
	swatch.Visible = found
	unknown.Visible = not found
	for _, part in { "RarityRow", "Divider", "Stats" } do
		(card:FindFirstChild(part) :: GuiObject).Visible = found and not (phone and part == "Divider")
	end
	tags.Visible = found
	if not found then
		name.Text = "Undiscovered"
		name.TextColor3 = FADED
		return
	end

	local herb = Herbs.Defs[entry.herb]
	local item = Items.Defs[entry.herb]
	name.Text = entry.name or (if herb then herb.name elseif item then item.name else entry.herb)
	name.TextColor3 = INK
	HerbArt.paint(swatch, entry.herb)
	local rarity = rarityOf(entry)
	HerbArt.gem(find(card, "Gem") :: ImageLabel, rarity);
	(find(card, "RarityLabel") :: TextLabel).Text = rarity

	local lines = {}
	if not (phone and entry.largest) then
		table.insert(lines, `Harvested {entry.harvested or 0}`)
	end
	if entry.largest then
		table.insert(lines, "Largest ×" .. string.format("%.1f", entry.largest))
	end;
	(card:FindFirstChild("Stats") :: TextLabel).Text = table.concat(lines, "\n")

	-- mutations seen: one row of ribbons (the row clips what doesn't fit)
	local tagTemplate = tags:FindFirstChild("TagTemplate") :: ImageLabel
	for _, child in tags:GetChildren() do
		if child.Name == "Tag" then
			child:Destroy()
		end
	end
	for i, id in entry.mutations or {} do
		local m = Herbs.Mutations[id]
		if m then
			local tag = tagTemplate:Clone()
			tag.Name = "Tag"
			tag.LayoutOrder = i
			tag.Visible = true
			tag.Parent = tags
			Ribbon.fit(tag, m.name, { style = HerbArt.tagStyle(id), label = "Label", textSize = 10, minMid = 0 })
		end
	end
end

local function spreads(): number
	return math.max(1, math.ceil(#book.entries / (PER_PAGE * 2)))
end

local function render()
	for _, page in pages do
		for _, child in page:GetChildren() do
			if child.Name == "Card" then
				child:Destroy()
			end
		end
	end
	local first = (spread - 1) * PER_PAGE * 2
	for i = 1, PER_PAGE * 2 do
		local entry = book.entries[first + i]
		if not entry then
			break
		end
		local card = template:Clone()
		card.Name = "Card"
		card.LayoutOrder = i
		fillCard(card, entry)
		card.Visible = true
		card.Parent = pages[if i <= PER_PAGE then 1 else 2]
	end
	local found = 0
	for _, e in book.entries do
		if e.discovered then
			found += 1
		end
	end
	local total = spreads()
	footer.Text = `Page {spread} / {total}  ·  {found} of {#book.entries} discovered`
	-- the gold title plaque fits its title (docs/ui/ribbons.md)
	local plaque = title.Parent :: Frame
	task.spawn(Ribbon.fit, plaque, book.title or "Herbarium", {
		style = "gold_curl",
		textSize = TITLE_SIZE,
		-- at most 60 % of the window (its width in the plaque's units)
		maxWidth = (plaque.Parent :: Frame).AbsoluteSize.X * 0.6 * plaque.Size.Y.Offset / math.max(plaque.AbsoluteSize.Y, 1),
		height = plaque.Size.Y.Offset,
	})
	for _, b in { { prev, spread > 1 }, { nextButton, spread < total } } do
		local button, on = b[1] :: GuiButton, b[2] :: boolean
		(button :: any).ImageTransparency = if on then 0 else OFF_TRANSPARENCY;
		(button:FindFirstChild("Glyph") :: ImageLabel).ImageTransparency = if on then 0 else OFF_TRANSPARENCY
		button.Active = on
	end
end

local function turn(step: number)
	local target = math.clamp(spread + step, 1, spreads())
	if target == spread then
		return
	end
	spread = target
	render()
	for _, page in pages do
		Motion.popWindow(page :: any)
	end
end

function Herbarium.open(b: Book)
	assert(window, "Herbarium.init hasn't run")
	book = b
	spread = 1
	render()
	Menus.open(window)
end

function Herbarium.close()
	if window then
		Menus.close(window)
	end
end

function Herbarium.isOpen(): boolean
	return window ~= nil and window.Visible
end

-- Sample content to review the book: every herb in Herbs.Order (a few with
-- harvest counts, sizes and mutations), then undiscovered pages. Preview only;
-- the real flow passes the player's record.
function Herbarium.preview()
	local entries: { Entry } = {}
	local mutationIds = { "Dewy", "Windswept", "Auspicious", "Golden", "Thunderstruck", "Rainbow", "Heavenlit" }
	for i, id in Herbs.Order do
		local found = i % 4 ~= 0
		table.insert(entries, {
			herb = id,
			tier = math.clamp(math.ceil(i / 3), 1, 5),
			discovered = found,
			harvested = if found then i * 7 else nil,
			largest = if found then 1 + (i % 5) * 0.6 else nil,
			mutations = if found then { mutationIds[(i % #mutationIds) + 1], mutationIds[((i * 3) % #mutationIds) + 1] } else nil,
		})
	end
	for tier = 3, 5 do
		for _ = 1, 3 do
			table.insert(entries, { herb = "", tier = tier, discovered = false })
		end
	end
	Herbarium.open({ entries = entries })
end

function Herbarium.init()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Herbarium") :: ScreenGui
	local canvas = gui:WaitForChild("Canvas") :: Frame
	UiScale.fit(canvas)
	window = canvas:WaitForChild("Window") :: Frame
	pages = { window:WaitForChild("LeftPage") :: Frame, window:WaitForChild("RightPage") :: Frame }
	template = window:WaitForChild("CardTemplate") :: GuiButton
	footer = window:WaitForChild("Footer") :: TextLabel
	title = find(window, "Title") :: TextLabel
	prev = window:WaitForChild("PrevButton") :: GuiButton
	nextButton = window:WaitForChild("NextButton") :: GuiButton
	template.Visible = false
	-- Phone cards are about 80x125: the rarity gem moves to the art window's
	-- corner (its word and the divider go), and the name gets two lines.
	phone = UiScale.isPhone()
	if phone then
		local row = template:FindFirstChild("RarityRow") :: Frame
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.82, 0.155)
		row.Size = UDim2.fromScale(0.2, 0.08);
		(row:FindFirstChild("RarityLabel") :: TextLabel).Visible = false;
		(template:FindFirstChild("Divider") :: GuiObject).Visible = false
		local name = template:FindFirstChild("NameLabel") :: TextLabel
		name.Position = UDim2.fromScale(0.5, 0.405)
		name.Size = UDim2.fromScale(0.9, 0.2);
		(name:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint).MinTextSize = 9
		local stats = template:FindFirstChild("Stats") :: TextLabel
		stats.Position = UDim2.fromScale(0.5, 0.63)
		stats.Size = UDim2.fromScale(0.86, 0.11)
	end

	Menus.register(window);
	(window:WaitForChild("Close") :: GuiButton).Activated:Connect(Herbarium.close)
	prev.Activated:Connect(function()
		turn(-1)
	end)
	nextButton.Activated:Connect(function()
		turn(1)
	end)
end

return Herbarium
