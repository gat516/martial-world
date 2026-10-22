--!strict
-- Reusable pieces of the character screen. Each builder clones a template from
-- the GUI's `Templates` folder (assets/CharacterCreator.rbxmx), fills it and
-- wires its selection or busy states, and returns a small handle. Sizes, art and
-- colours live in the templates; hover and press scaling comes from Motion
-- (every button carries a `Motion` UIScale, bound by Controller).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Components = {}

local templates: Instance

function Components.init(folder: Instance)
	templates = folder
end

local function clone(name: string): any
	return (templates:FindFirstChild(name) :: Instance):Clone()
end

local function tween(inst: Instance, info: TweenInfo, props: { [string]: any })
	TweenService:Create(inst, info, props):Play()
end

-- Selection (cards and swatches): gold glow, gold rim and the check badge.
local authoredStroke: { [UIStroke]: { Color: Color3, Thickness: number, Transparency: number } } =
	setmetatable({}, { __mode = "k" }) :: any

function Components.setSelected(button: GuiObject, on: boolean)
	local glow = button:FindFirstChild("Glow") :: ImageLabel?
	local check = button:FindFirstChild("Check") :: Frame?
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if glow then
		tween(glow, Theme.Tween.Select, { ImageTransparency = if on then Theme.Selection.GlowOn else 1 })
	end
	if stroke then
		local authored = authoredStroke[stroke]
		if not authored then
			authored = { Color = stroke.Color, Thickness = stroke.Thickness, Transparency = stroke.Transparency }
			authoredStroke[stroke] = authored
		end
		local a = authored :: { Color: Color3, Thickness: number, Transparency: number }
		tween(stroke, Theme.Tween.Select, {
			Color = if on then Theme.Color.GoldBright else a.Color,
			Thickness = if on then Theme.Selection.StrokeOn else a.Thickness,
			Transparency = if on then 0 else a.Transparency,
		})
	end
	if check then
		local wasOn = check.Visible
		check.Visible = on
		local pop = check:FindFirstChild("Pop") :: UIScale?
		if on and not wasOn and pop then
			pop.Scale = 0.4
			tween(pop, Theme.Tween.Pop, { Scale = 1 })
		end
	end
end

-- Paints a RarityPill (or any frame with a Label child) for a Rarities key.
function Components.paintPill(pill: Frame, rarities: { [string]: any }, key: string?)
	local rarity = key and rarities[key]
	pill.Visible = rarity ~= nil
	if rarity then
		pill.BackgroundColor3 = rarity.Color;
		(pill:FindFirstChild("Label") :: TextLabel).Text = rarity.DisplayName
	end
end

function Components.sectionHeader(parent: Instance, text: string, order: number): Frame
	local header = clone("SectionHeader")
	header.Name = "Header_" .. text:gsub("%s", "");
	(header:FindFirstChild("Label") :: TextLabel).Text = text
	header.LayoutOrder = order
	header.Parent = parent
	return header
end

-- kind: "CardGrid" (two per row) or "SwatchGrid" (six per row)
function Components.grid(parent: Instance, kind: string, order: number, name: string?): Frame
	local grid = clone(kind)
	grid.Name = name or kind
	grid.LayoutOrder = order
	grid.Parent = parent
	return grid
end

function Components.note(parent: Instance, text: string, order: number, name: string?): TextLabel
	local note = clone("Note")
	note.Name = name or "Note"
	note.Text = text
	note.LayoutOrder = order
	note.Parent = parent
	return note
end

export type CardOptions = {
	id: string,
	caption: string,
	image: string, -- "" shows the placeholder glyph
	glyph: string,
	order: number,
	onClick: () -> (),
}

function Components.card(parent: Instance, opts: CardOptions)
	local card = clone("Card") :: TextButton
	card.Name = opts.id
	card.LayoutOrder = opts.order;
	(card:FindFirstChild("Caption") :: TextLabel).Text = opts.caption
	local thumb = card:FindFirstChild("Thumb") :: ImageLabel
	local placeholder = card:FindFirstChild("Placeholder") :: TextLabel
	thumb.Image = opts.image
	thumb.Visible = opts.image ~= ""
	placeholder.Text = opts.glyph
	placeholder.Visible = opts.image == ""
	card.Activated:Connect(opts.onClick)
	card.Parent = parent
	return {
		button = card,
		setSelected = function(on: boolean)
			Components.setSelected(card, on)
		end,
	}
end

function Components.swatch(parent: Instance, id: string, color: Color3, order: number, onClick: () -> ())
	local swatch = clone("Swatch") :: TextButton
	swatch.Name = id
	swatch.BackgroundColor3 = color
	swatch.LayoutOrder = order
	swatch.Activated:Connect(onClick)
	swatch.Parent = parent
	return {
		button = swatch,
		setSelected = function(on: boolean)
			Components.setSelected(swatch, on)
		end,
	}
end

-- A nav tab: diamond badge with a glyph, a label, and a node on the rail.
function Components.navButton(parent: Instance, tab: { [string]: string }, order: number, onClick: () -> ())
	local button = clone("NavButton") :: TextButton
	button.Name = tab.Id
	button.LayoutOrder = order;
	(button:FindFirstChild("Label") :: TextLabel).Text = tab.Label;
	(button:FindFirstChild("Glyph") :: TextLabel).Text = tab.Glyph
	local plate = button:FindFirstChild("Plate") :: Frame
	local label = button:FindFirstChild("Label") :: TextLabel
	local node = button:FindFirstChild("Node") :: Frame
	local plateStroke = plate:FindFirstChildOfClass("UIStroke") :: UIStroke
	local plateGradient = plate:FindFirstChildOfClass("UIGradient") :: UIGradient
	local platePos = plate.Position
	local labelPos = label.Position
	button.Activated:Connect(onClick)
	button.Parent = parent
	local function setSelected(on: boolean)
		local shift = UDim2.fromOffset(if on then Theme.Selection.NavShift else 0, 0)
		plateGradient.Color = if on then Theme.Plate.Selected else Theme.Plate.Idle
		tween(plate, Theme.Tween.Select, { Position = platePos + shift })
		tween(label, Theme.Tween.Select, {
			Position = labelPos + shift,
			TextColor3 = if on then Theme.Color.Ink else Theme.Color.Cream,
			TextStrokeTransparency = if on then 1 else 0.4,
		})
		tween(plateStroke, Theme.Tween.Select, {
			Color = if on then Theme.Color.GoldBright else Theme.Color.GoldDim,
			Thickness = if on then 2 else 1.5,
		})
		node.BackgroundColor3 = if on then Theme.Color.GoldBright else Theme.Color.Jade
	end
	setSelected(false)
	return { button = button, setSelected = setSelected }
end

-- Gold button with a label over a Robux price.
function Components.robuxButton(button: ImageButton, label: string, price: number?)
	local labelText = button:FindFirstChild("Label") :: TextLabel
	local priceText = button:FindFirstChild("Price") :: TextLabel
	labelText.Text = label
	local busy = false
	local handle = {}
	function handle.setPrice(value: number?)
		priceText.Text = if value then `{Theme.ROBUX} {value}` else ""
	end
	function handle.setBusy(on: boolean)
		busy = on
		button.Active = not on
		tween(button, Theme.Tween.Select, { ImageColor3 = if on then Color3.fromRGB(170, 170, 170) else Color3.new(1, 1, 1) })
		labelText.TextTransparency = if on then 0.35 else 0
		priceText.TextTransparency = if on then 0.35 else 0
	end
	function handle.isBusy(): boolean
		return busy
	end
	handle.button = button
	handle.setPrice(price)
	return handle
end

-- Race and last-name block: emblem (icon, glyph or silhouette), name, rarity
-- pill, a note, and a Robux button on the right.
function Components.identityBlock(parent: Instance, name: string, buttonLabel: string, order: number)
	local block = clone("IdentityBlock") :: Frame
	block.Name = name
	block.LayoutOrder = order
	local body = block:FindFirstChild("Body") :: Frame
	local card = body:FindFirstChild("Card") :: Frame
	local emblem = card:FindFirstChild("Emblem") :: Frame
	local status = block:FindFirstChild("Status") :: TextLabel
	local pop = card:FindFirstChild("Pop") :: UIScale
	local handle = {}
	handle.root = block
	handle.change = Components.robuxButton(body:FindFirstChild("Change") :: ImageButton, buttonLabel, nil)
	function handle.set(info: { title: string, note: string, rarity: string?, rarities: any, icon: string?, glyph: string? })
		local title = card:FindFirstChild("Title") :: TextLabel
		local note = card:FindFirstChild("Note") :: TextLabel
		title.Text = info.title
		note.Text = info.note
		Components.paintPill(card:FindFirstChild("Pill") :: Frame, info.rarities, info.rarity)
		local icon = emblem:FindFirstChild("Icon") :: ImageLabel
		local glyph = emblem:FindFirstChild("Glyph") :: TextLabel
		local silhouette = emblem:FindFirstChild("Silhouette") :: Frame
		local hasIcon = info.icon ~= nil and info.icon ~= ""
		local hasGlyph = not hasIcon and info.glyph ~= nil and info.glyph ~= ""
		icon.Image = if hasIcon then info.icon :: string else ""
		icon.Visible = hasIcon
		glyph.Text = if hasGlyph then info.glyph :: string else ""
		glyph.Visible = hasGlyph
		silhouette.Visible = not hasIcon and not hasGlyph
	end
	function handle.setStatus(text: string?)
		status.Text = text or ""
		status.Visible = text ~= nil and text ~= ""
	end
	-- A new roll landed: the card swells and settles, its rim flashes gold.
	function handle.reveal()
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		pop.Scale = 0.9
		tween(pop, Theme.Tween.Reveal, { Scale = 1 })
		stroke.Color = Theme.Color.GoldBright
		stroke.Thickness = 3
		stroke.Transparency = 0
		tween(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Theme.Color.GoldDim,
			Thickness = 1.2,
			Transparency = 0.4,
		})
	end
	block.Parent = parent
	return handle
end

export type FieldOptions = {
	name: string,
	placeholder: string,
	order: number,
	action: string?, -- label of the button beside the field; nil hides it
	counter: boolean?,
}

-- A parchment text field with an optional button and a status line under it.
function Components.textField(parent: Instance, opts: FieldOptions)
	local field = clone("TextField") :: Frame
	field.Name = opts.name
	field.LayoutOrder = opts.order
	local row = field:FindFirstChild("Row") :: Frame
	local box = (row:FindFirstChild("Field") :: Frame):FindFirstChild("Input") :: TextBox
	local counter = (row:FindFirstChild("Field") :: Frame):FindFirstChild("Counter") :: TextLabel
	local action = row:FindFirstChild("Action") :: ImageButton
	local status = field:FindFirstChild("Status") :: TextLabel
	box.PlaceholderText = opts.placeholder
	box.Text = ""
	action.Visible = opts.action ~= nil
	if opts.action then
		(action:FindFirstChild("Label") :: TextLabel).Text = opts.action
	end
	counter.Visible = opts.counter == true
	field.Parent = parent
	local handle = { root = field, input = box, action = action, counter = counter }
	-- kind: "error" (lacquer), "ok" (jade) or "info" (soft ink)
	function handle.setStatus(text: string?, kind: string?)
		status.Text = text or ""
		status.TextColor3 = if kind == "error"
			then Theme.Color.Lacquer
			elseif kind == "ok" then Theme.Color.JadeText
			else Theme.Color.InkSoft
	end
	function handle.setBusy(on: boolean)
		action.Active = not on
		action.ImageTransparency = if on then 0.4 else 0
	end
	return handle
end

-- One line of the Confirm summary: key on the left, value (with an optional
-- colour swatch and rarity pill) on the right.
function Components.summaryRow(parent: Instance, key: string, order: number)
	local row = clone("SummaryRow") :: Frame
	row.Name = key:gsub("%s", "")
	row.LayoutOrder = order;
	(row:FindFirstChild("Key") :: TextLabel).Text = key
	local value = row:FindFirstChild("Value") :: Frame
	row.Parent = parent
	return {
		root = row,
		set = function(text: string, swatch: Color3?, rarity: string?, rarities: any?)
			local label = value:FindFirstChild("Label") :: TextLabel
			label.Text = text
			local chip = value:FindFirstChild("Swatch") :: Frame
			chip.Visible = swatch ~= nil
			if swatch then
				chip.BackgroundColor3 = swatch
			end
			Components.paintPill(value:FindFirstChild("Pill") :: Frame, rarities or {}, rarity)
		end,
	}
end

-- The big gold button (Enter World). setEnabled dims it without hiding it.
function Components.bigButton(parent: Instance, name: string, label: string, order: number)
	local button = clone("BigButton") :: ImageButton
	button.Name = name
	button.LayoutOrder = order
	local text = button:FindFirstChild("Label") :: TextLabel
	text.Text = label
	button.Parent = parent
	local handle = { button = button }
	function handle.setEnabled(on: boolean)
		tween(button, Theme.Tween.Select, { ImageColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(150, 146, 140) })
		text.TextTransparency = if on then 0 else 0.4
	end
	function handle.setLabel(value: string)
		text.Text = value
	end
	return handle
end

return Components
