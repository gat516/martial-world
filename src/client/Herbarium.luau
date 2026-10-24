--!strict
-- The Herbarium (StarterGui.Herbarium, assets/Herbarium.rbxmx): the collection
-- book of every herb, roadmap §5 / Phase B. H and the top-right tile
-- (Hud.Buttons.HerbariumButton) toggle the player's own book, built from the server's
-- record in the PlayerState push (`herbarium`, server Herbarium.luau). Contract
-- and layout: docs/ui/herbarium.md.
--
--   Herbarium.open({ entries = { Entry, ... }, title = "Herbarium"?, done = { tier }? })
--   Herbarium.openMine()   the player's own book (Herbarium.fromState)
--   Herbarium.toggle()
--   Herbarium.close()
--   Herbarium.isOpen()
--   Herbarium.preview()   sample book (a made-up record over every herb), from the
--                         client console in play:
--     require(game.Players.LocalPlayer.PlayerScripts.Client.Herbarium).preview()
--
-- The open book shows six herb cards per page, twelve per spread, in the order
-- given: a discovered herb's card has its art, tier shield (I-V), name, rarity
-- gem, how many were harvested, the largest size seen and the mutations seen
-- (kit tag ribbons, one row); an undiscovered one is the greyed card with a
-- question mark and its tier; a blank entry leaves its slot empty. The player's
-- book gives each tier its own page (blanks pad it), so a page is a tier and
-- completing it is the tier reward; the footer lists the completed pages. The
-- seals on the book's edges turn the spread.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local HerbArt = require(script.Parent.HerbArt)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Ribbon = require(script.Parent.Ribbon)
local State = require(script.Parent.State)
local UiScale = require(script.Parent.UiScale)

export type Entry = {
	herb: string, -- Herbs.Defs id: name, rarity and art come from the defs
	tier: number, -- herb tier 1-5 (I bronze, II silver, III gold, IV jade, V violet)
	discovered: boolean,
	harvested: number?, -- total ever harvested
	largest: number?, -- the biggest size seen (×)
	mutations: { string }?, -- Herbs.Mutations ids seen on this herb
	name: string?, -- overrides the def's name (a herb not in Herbs.Defs yet)
	blank: boolean?, -- an empty slot (pads a tier to its own page)
}
-- done: tiers whose page is complete, listed in the footer; mine: the player's own
-- book, rebuilt from State while open
export type Book = { entries: { Entry }, title: string?, done: { number }?, mine: boolean? }

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
		if entry.blank then
			continue
		end
		local card = template:Clone()
		card.Name = "Card"
		card.LayoutOrder = i
		fillCard(card, entry)
		card.Visible = true
		card.Parent = pages[if i <= PER_PAGE then 1 else 2]
	end
	local found, herbs = 0, 0
	for _, e in book.entries do
		if not e.blank then
			herbs += 1
			if e.discovered then
				found += 1
			end
		end
	end
	local total = spreads()
	local line = `Page {spread} / {total}  ·  {found} of {herbs} discovered`
	if book.done and #book.done > 0 then
		local numerals = {}
		for _, t in book.done do
			table.insert(numerals, Herbs.TierNumerals[t] or tostring(t))
		end
		line ..= `  ·  Complete: {table.concat(numerals, " ")}`
	end
	footer.Text = line
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

type Record = { herbs: { [string]: { n: number, l: number, m: { string } } }, tiers: { [string]: boolean } }

-- A book from a Herbarium record (the PlayerState `herbarium`): every herb, tier by
-- tier in Herbs.Order, each tier padded with blanks to whole pages.
function Herbarium.fromState(record: Record?): Book
	local herbs = if record then record.herbs else {}
	local tiers = if record then record.tiers else {}
	local entries: { Entry } = {}
	local done = {}
	for tier = 1, #Herbs.TierNumerals do
		local count = 0
		for _, id in Herbs.Order do
			local herb = Herbs.Defs[id]
			if herb.tier == tier then
				local r = herbs[id]
				table.insert(entries, {
					herb = id,
					tier = tier,
					discovered = r ~= nil,
					harvested = if r then r.n else nil,
					largest = if r and r.l > 0 then r.l else nil,
					mutations = if r then r.m else nil,
				})
				count += 1
			end
		end
		while count % PER_PAGE ~= 0 do
			table.insert(entries, { herb = "", tier = tier, discovered = false, blank = true })
			count += 1
		end
		if tiers[tostring(tier)] then
			table.insert(done, tier)
		end
	end
	return { entries = entries, done = done }
end

function Herbarium.openMine()
	local b = Herbarium.fromState(State.current.herbarium)
	b.mine = true
	Herbarium.open(b)
end

function Herbarium.toggle()
	if Herbarium.isOpen() then
		Herbarium.close()
	else
		Herbarium.openMine()
	end
end

function Herbarium.close()
	if window then
		Menus.close(window)
	end
end

function Herbarium.isOpen(): boolean
	return window ~= nil and window.Visible
end

-- Sample content to review the book: a made-up record over every herb (most
-- discovered, with harvest counts, sizes and mutations; tier I complete). Preview
-- only; the real flow reads the player's record.
function Herbarium.preview()
	local mutationIds = { "Dewy", "Windswept", "Auspicious", "Golden", "Thunderstruck", "Rainbow", "Heavenlit" }
	local record: Record = { herbs = {}, tiers = { ["1"] = true } }
	for i, id in Herbs.Order do
		if Herbs.Defs[id].tier == 1 or i % 4 ~= 0 then
			record.herbs[id] = {
				n = i * 7,
				l = 1 + (i % 5) * 0.6,
				m = { mutationIds[(i % #mutationIds) + 1], mutationIds[((i * 3) % #mutationIds) + 1] },
			}
		end
	end
	Herbarium.open(Herbarium.fromState(record))
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
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			Herbarium.toggle()
		end
	end)
	-- the top-right HUD tile (docs/ui/herbarium.md "Opening it")
	local hud = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Hud")
	local tile = hud and hud:FindFirstChild("HerbariumButton", true)
	if tile and tile:IsA("GuiButton") then
		tile.Activated:Connect(Herbarium.toggle)
	end
	-- the player's own book follows the record while open (a harvest, a reward)
	State.onChanged(function(snapshot)
		if book.mine and Herbarium.isOpen() then
			local keep = spread
			local b = Herbarium.fromState(snapshot.herbarium)
			b.mine = true
			book = b
			spread = math.clamp(keep, 1, spreads())
			render()
		end
	end)
end

return Herbarium
