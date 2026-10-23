--!strict
-- Reusable pieces of the join screen. Each builder clones a template from the
-- GUI's `Templates` (assets/CharacterCreator.rbxmx, art/ui/creator/build_gui.luau),
-- fills it and returns a small handle. Sizes, art and colours live in the
-- templates; hover and press come from Motion (every button has a `Motion`
-- UIScale). Selection is the Inventory's plain cream ring (a well's Halo), nothing more.

local Theme = require(script.Parent.Theme)

local Components = {}

local templates: Instance

function Components.init(folder: Instance)
	templates = folder
end

local function clone(name: string): any
	return (templates:FindFirstChild(name) :: Instance):Clone()
end

-- A swatch or slot card: the cream ring round its well while selected.
function Components.setSelected(wellArt: GuiObject, on: boolean)
	local halo = wellArt:FindFirstChild("Halo") :: GuiObject?
	if halo then
		halo.Visible = on
	end
end

function Components.tab(parent: Instance, id: string, order: number, onClick: () -> ())
	local tab = clone("Tab") :: ImageButton
	tab.Name = id
	tab.LayoutOrder = order
	tab.Activated:Connect(onClick)
	tab.Parent = parent
	local label = tab:FindFirstChild("Label") :: TextLabel
	return {
		button = tab,
		set = function(text: string, current: boolean)
			label.Text = text
			tab.Image = if current then Theme.Art.Gold else Theme.Art.Lacquer
		end,
	}
end

function Components.section(parent: Instance, text: string, order: number): TextLabel
	local label = clone("Section") :: TextLabel
	label.Name = "Section_" .. text:gsub("%W", "")
	label.Text = text
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

function Components.note(parent: Instance, text: string, order: number, name: string?): TextLabel
	local note = clone("Note") :: TextLabel
	note.Name = name or "Note"
	note.Text = text
	note.LayoutOrder = order
	note.Parent = parent
	return note
end

function Components.link(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local link = clone("Link") :: TextButton
	link.Text = text
	link.LayoutOrder = order
	link.Activated:Connect(onClick)
	link.Parent = parent
	return link
end

-- kind: "SwatchGrid" (six per row)
function Components.grid(parent: Instance, kind: string, order: number, name: string?): Frame
	local grid = clone(kind)
	grid.Name = name or kind
	grid.LayoutOrder = order
	grid.Parent = parent
	return grid
end

-- An arrow picker in a plain well: a lacquer arrow on each side, the pick's name
-- centred with "1 / 3" under it. It wraps around; the caller keeps the index.
-- step(-1) or step(1) is called on a press.
function Components.arrowRow(parent: Instance, name: string, order: number, step: (number) -> ())
	local row = clone("ArrowRow") :: ImageLabel
	row.Name = name
	row.LayoutOrder = order
	local value = row:FindFirstChild("Value") :: TextLabel
	local count = row:FindFirstChild("Count") :: TextLabel
	local prev = row:FindFirstChild("Prev") :: ImageButton
	local nextButton = row:FindFirstChild("Next") :: ImageButton
	prev.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)
	row.Parent = parent
	return {
		root = row,
		-- label: an optional gold prefix ("Tail") before the pick's name
		set = function(text: string, index: number, total: number, label: string?)
			value.Text = if label then `<font color="#{Theme.Color.Gold:ToHex()}">{label}:</font> {text}` else text
			count.Text = `{index} / {total}`
			-- one option: nothing to step through
			prev.Visible = total > 1
			nextButton.Visible = total > 1
		end,
	}
end

function Components.swatch(parent: Instance, id: string, color: Color3, order: number, onClick: () -> ())
	local swatch = clone("Swatch") :: ImageButton
	swatch.Name = id
	;(swatch:FindFirstChild("Chip") :: Frame).BackgroundColor3 = color
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

export type FieldOptions = {
	name: string,
	placeholder: string,
	order: number,
	action: string?, -- label of the button beside the field; nil hides it
	counter: boolean?,
}

-- A text field in a plain well, an optional button and a status line under it.
function Components.textField(parent: Instance, opts: FieldOptions)
	local field = clone("TextField") :: Frame
	field.Name = opts.name
	field.LayoutOrder = opts.order
	local row = field:FindFirstChild("Row") :: Frame
	local frame = row:FindFirstChild("Box") :: ImageLabel
	local box = frame:FindFirstChild("Input") :: TextBox
	local counter = frame:FindFirstChild("Counter") :: TextLabel
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
	local handle = { root = field, input = box, action = action, counter = counter, frame = frame }
	-- kind: "error" or "need" (lacquer), "ok" (jade) or "info" (muted)
	function handle.setStatus(text: string?, kind: string?)
		status.Text = text or ""
		status.Visible = status.Text ~= ""
		status.TextColor3 = if kind == "error" or kind == "need"
			then Theme.Color.Lacquer
			elseif kind == "ok" then Theme.Color.Jade
			else Theme.Color.Muted
	end
	-- the field's edge turns gold while it needs attention (a required field still empty)
	local edge = frame:FindFirstChild("Edge") :: ImageLabel
	function handle.setNeed(on: boolean)
		edge.ImageColor3 = if on then Theme.Edge.Need else Theme.Edge.Rest
		edge.ImageTransparency = if on then 0 else Theme.Edge.RestTransparency
	end
	function handle.setBusy(on: boolean)
		action.Active = not on
		action.ImageColor3 = if on then Theme.Color.Disabled else Color3.new(1, 1, 1)
	end
	function handle.setLocked(on: boolean)
		box.TextEditable = not on
		box.Active = not on
		box.TextColor3 = if on then Theme.Color.Muted else Theme.Color.Cream
	end
	return handle
end

-- A race or clan row in a plain well: "Race · Rare" over the value, and a
-- Change button with its Robux price.
function Components.fateRow(parent: Instance, name: string, order: number)
	local block = clone("FateRow") :: Frame
	block.Name = name
	block.LayoutOrder = order
	local row = block:FindFirstChild("Row") :: Frame
	local kind = row:FindFirstChild("Kind") :: TextLabel
	local value = row:FindFirstChild("Value") :: TextLabel
	local change = row:FindFirstChild("Change") :: ImageButton
	local changeLabel = change:FindFirstChild("Label") :: TextLabel
	local status = block:FindFirstChild("Status") :: TextLabel
	local busy = false
	local price: number? = nil
	local handle = { root = block, button = change }
	function handle.set(label: string, text: string, rarity: { DisplayName: string, Color: Color3 }?)
		value.Text = text
		kind.Text = if rarity
			then `{label}  ·  <font color="#{rarity.Color:ToHex()}">{rarity.DisplayName}</font>`
			else label
	end
	function handle.setPrice(value: number?)
		price = value
		changeLabel.Text = if value then `Change  {Theme.ROBUX} {value}` else "Change"
	end
	function handle.setBusy(on: boolean)
		busy = on
		change.Active = not on
		change.ImageColor3 = if on then Theme.Color.Disabled else Color3.new(1, 1, 1)
		changeLabel.TextTransparency = if on then 0.4 else 0
	end
	function handle.isBusy(): boolean
		return busy
	end
	function handle.setStatus(text: string?)
		status.Text = text or ""
		status.Visible = status.Text ~= ""
	end
	handle.setPrice(price)
	block.Parent = parent
	return handle
end

-- One slot on the slot screen.
function Components.slotCard(parent: Instance, order: number, onClick: () -> ())
	local card = clone("SlotCard") :: ImageButton
	card.Name = "Slot" .. order
	card.LayoutOrder = order
	card.Activated:Connect(onClick)
	card.Parent = parent
	local labels = {
		Name = card:FindFirstChild("Title") :: TextLabel,
		Sub = card:FindFirstChild("Sub") :: TextLabel,
		Realm = card:FindFirstChild("Realm") :: TextLabel,
		When = card:FindFirstChild("When") :: TextLabel,
	}
	return {
		button = card,
		set = function(name: string, sub: string, realm: string, when: string, empty: boolean)
			labels.Name.Text = name
			labels.Name.TextColor3 = if empty then Theme.Color.Gold else Theme.Color.Cream
			labels.Sub.Text = sub
			labels.Realm.Text = realm
			labels.When.Text = when
		end,
		setSelected = function(on: boolean)
			Components.setSelected(card, on)
		end,
	}
end

function Components.oddsRow(parent: Instance, order: number, name: string, rarity: any, chance: string)
	local row = clone("OddsRow") :: Frame
	row.LayoutOrder = order
	;(row:FindFirstChild("Label") :: TextLabel).Text = name
	local r = row:FindFirstChild("Rarity") :: TextLabel
	r.Text = if rarity then rarity.DisplayName else ""
	r.TextColor3 = if rarity then rarity.Color else Theme.Color.Muted
	;(row:FindFirstChild("Chance") :: TextLabel).Text = chance
	row.Parent = parent
	return row
end

return Components
