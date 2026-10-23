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

-- `required` shows the lacquer "Required" tag at the rule's end.
function Components.sectionHeader(parent: Instance, text: string, order: number, required: boolean?): Frame
	local header = clone("SectionHeader")
	header.Name = "Header_" .. text:gsub("%s", "");
	(header:FindFirstChild("Label") :: TextLabel).Text = text;
	(header:FindFirstChild("Tag") :: TextLabel).Visible = required == true
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

-- Nav plate states (Controller sets them from the flow):
--   "current"  the open step: the lit plate, slid right
--   "done"     visited and complete: gold check
--   "missing"  a required field on it is empty: lacquer "!"
--   "locked"   can't be opened until an earlier step is done: dimmed, lock
--   "todo"     not visited yet, nothing missing: plain
local PLATE, PLATE_HI = Theme.Art.Plate, Theme.Art.PlateHi
local STATUS_ICON = {
	done = { image = Theme.Art.Check, color = Theme.Color.GoldBright, size = UDim2.fromOffset(22, 17) },
	missing = { image = Theme.Art.Exclaim, color = Theme.Color.Alert, size = UDim2.fromOffset(8, 24) },
	locked = { image = Theme.Art.Lock, color = Theme.Color.Locked, size = UDim2.fromOffset(17, 20) },
}

function Components.navButton(parent: Instance, tab: { [string]: string }, order: number, onClick: () -> ())
	local button = clone("NavButton") :: TextButton
	button.Name = tab.Id
	button.LayoutOrder = order
	local plate = button:FindFirstChild("Plate") :: ImageLabel
	local label = plate:FindFirstChild("Label") :: TextLabel
	local glyph = plate:FindFirstChild("Glyph") :: TextLabel
	local status = plate:FindFirstChild("Status") :: ImageLabel
	label.Text = tab.Label
	glyph.Text = tab.Glyph
	local platePos = plate.Position
	button.Activated:Connect(onClick)
	button.Parent = parent
	local current = ""
	local isCompact = false
	-- where the plate rests: slid right while current, centred when compact
	local function restPosition(): UDim2
		if isCompact then
			return UDim2.fromScale(0.5, 0.5)
		end
		return platePos + UDim2.fromOffset(if current == "current" then Theme.Selection.NavShift else 0, 0)
	end
	local function setState(state: string)
		if state == current then
			return
		end
		current = state
		local on = state == "current"
		plate.Image = if on then PLATE_HI else PLATE
		tween(plate, Theme.Tween.Select, {
			Position = restPosition(),
			ImageColor3 = if state == "locked" then Theme.Color.Disabled else Color3.new(1, 1, 1),
		})
		label.TextTransparency = if state == "locked" then 0.35 else 0
		glyph.TextTransparency = if state == "locked" then 0.35 else 0;
		(plate:FindFirstChild("Marker") :: ImageLabel).Visible = on
		local icon = STATUS_ICON[state]
		status.Visible = icon ~= nil
		if icon then
			status.Image = icon.image
			status.ImageColor3 = icon.color
			status.Size = icon.size
		end
	end
	setState("todo")
	-- compact: only the plate's ring (the first 240 px of the art) with the glyph;
	-- the status mark moves onto the ring's shoulder
	local plateSize, statusPos, plateAnchor = plate.Size, status.Position, plate.AnchorPoint
	local function setCompact(on: boolean)
		if on == isCompact then
			return
		end
		isCompact = on
		label.Visible = not on
		if on then
			local h = plateSize.Y.Offset
			plate.ScaleType = Enum.ScaleType.Stretch
			plate.ImageRectOffset = Vector2.zero
			plate.ImageRectSize = Vector2.new(240, 221)
			plate.Size = UDim2.fromOffset(math.floor(h * 240 / 221 + 0.5), h)
			plate.AnchorPoint = Vector2.new(0.5, 0.5)
			status.Position = UDim2.fromOffset(glyph.Position.X.Offset + h * 0.36, glyph.Position.Y.Offset - h * 0.3)
		else
			plate.ScaleType = Enum.ScaleType.Slice
			plate.ImageRectSize = Vector2.zero
			plate.Size = plateSize
			plate.AnchorPoint = plateAnchor
			status.Position = statusPos
		end
		-- a zero-length tween, so it also cancels a slide still running
		tween(plate, TweenInfo.new(0), { Position = restPosition() })
	end
	return {
		button = button,
		setState = setState,
		setCompact = setCompact,
		-- a short shake and flash: "this step needs something"
		nudge = function()
			local rest = restPosition()
			plate.Position = rest + UDim2.fromOffset(-6, 0)
			tween(plate, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Position = rest })
		end,
	}
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
	-- kind: "error" (lacquer), "ok" (jade), "need" (lacquer, a required field
	-- still empty) or "info" (soft ink)
	function handle.setStatus(text: string?, kind: string?)
		status.Text = text or ""
		status.TextColor3 = if kind == "error" or kind == "need"
			then Theme.Color.Lacquer
			elseif kind == "ok" then Theme.Color.JadeText
			else Theme.Color.InkSoft
	end
	-- The field's rim: "need" (gold, required and empty), "error" (lacquer) or
	-- nil (as authored).
	local rim = (row:FindFirstChild("Field") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
	local rimColor, rimThickness = rim.Color, rim.Thickness
	local need: string? = nil
	local function paintRim()
		rim.Color = if need == "need" then Theme.Color.Need elseif need == "error" then Theme.Color.Lacquer else rimColor
		rim.Thickness = if need then 2.5 else rimThickness
	end
	function handle.setNeed(kind: string?)
		need = kind
		paintRim()
	end
	-- Draws the eye: the rim flares lacquer and settles back.
	function handle.flash()
		rim.Color = Theme.Color.Lacquer
		rim.Thickness = 4
		tween(rim, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = if need == "need" then Theme.Color.Need elseif need == "error" then Theme.Color.Lacquer else rimColor,
			Thickness = if need then 2.5 else rimThickness,
		})
	end
	function handle.setBusy(on: boolean)
		action.Active = not on
		action.ImageTransparency = if on then 0.4 else 0
	end
	return handle
end

-- The keyplate emblem at the front of a field's row (the first name's family
-- seal); returns its glyph label.
function Components.keyplate(field: Frame): TextLabel
	local plate = clone("Keyplate") :: ImageLabel
	plate.LayoutOrder = -1
	plate.Parent = field:FindFirstChild("Row")
	return plate:FindFirstChild("Glyph") :: TextLabel
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
	local label = value:FindFirstChild("Label") :: TextLabel
	local authoredColor = label.TextColor3
	return {
		root = row,
		-- a required value still missing: lacquer text
		setWarn = function(on: boolean)
			label.TextColor3 = if on then Theme.Color.Lacquer else authoredColor
		end,
		set = function(text: string, swatch: Color3?, rarity: string?, rarities: any?)
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

return Components
