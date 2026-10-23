--!nocheck
-- Builds the join screen's GUI (ReplicatedStorage.CharacterCreatorGui, exported to
-- assets/CharacterCreator.rbxmx): the slot screen and the character creator on
-- one stage (docs/systems/save-slots.md, docs/systems/character-creator.md).
-- Run with the Studio MCP's execute_luau in Edit. It keeps Backdrop.Image,
-- Veil, Root.Preview (its World and pedestal) and Templates.Dummy and rebuilds
-- everything else. Kit cuts only (ids in art/ui/assets.json); no ornaments
-- beyond the kit frame (cards, fields, buttons, the panel) and one divider.

local gui = game.ReplicatedStorage.CharacterCreatorGui

local ART = {
	Slot = "rbxassetid://135331792516626", -- codex/cut/ornament_item_slot.png
	SlotOn = "rbxassetid://96449593211039", -- ornament_item_slot_selected.png
	Divider = "rbxassetid://99789570259645", -- ornament_divider_diamond.png
	BackSeal = "rbxassetid://73842302611492", -- ornament_back_seal.png
}
local SLOT_SLICE = Rect.new(110, 110, 358, 344)

local C = {
	Cream = Color3.fromRGB(250, 236, 195),
	Muted = Color3.fromRGB(196, 186, 164),
	Gold = Color3.fromRGB(226, 188, 108),
	GoldBright = Color3.fromRGB(255, 222, 150),
	Lacquer = Color3.fromRGB(240, 110, 92),
	Ink = Color3.fromRGB(14, 16, 20),
	Fill = Color3.fromRGB(150, 42, 36),
}
local TITLE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function text(name, font, size, color, props)
	local t = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for k, v in props or {} do
		t[k] = v
	end
	return t
end

local function motion()
	return new("UIScale", { Name = "Motion" })
end

local function slotArt(inst, scale)
	inst.Image = ART.Slot
	inst.ScaleType = Enum.ScaleType.Slice
	inst.SliceCenter = SLOT_SLICE
	inst.SliceScale = scale
	inst.BackgroundTransparency = 1
	return inst
end

local function slotButton(name, w, h, label)
	return slotArt(new("ImageButton", { Name = name, Size = UDim2.fromOffset(w, h), AutoButtonColor = false }), 0.22), {
		motion(),
		text("Label", TITLE, 18, C.Cream, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = label,
		}),
	}
end

local function withChildren(inst, children)
	for _, c in children do
		c.Parent = inst
	end
	return inst
end

-- clear out the old screen
for _, name in { "Vignette", "Floor" } do
	local old = gui.Backdrop:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local root = gui.Root
for _, child in root:GetChildren() do
	if child.Name ~= "Preview" then
		child:Destroy()
	end
end
for _, child in gui.Templates:GetChildren() do
	if child.Name ~= "Dummy" then
		child:Destroy()
	end
end
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Preview: the hint sits low inside it
local preview = root.Preview
preview.BackgroundTransparency = 1
local hint = preview:FindFirstChild("Hint")
if hint then
	hint:Destroy()
end
text("Hint", BODY, 15, C.Muted, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(240, 20),
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Drag to turn",
	TextStrokeTransparency = 0.4,
	TextStrokeColor3 = C.Ink,
	Parent = preview,
})

-- Nameplate under the character (Controller places and scales it)
new("Frame", {
	Name = "Nameplate",
	Parent = root,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(520, 76),
}, {
	new("UIScale", { Name = "Fit" }),
	text("Title", TITLE, 32, C.Cream, {
		Size = UDim2.new(1, 0, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.Ink,
	}),
	text("Sub", BOLD, 19, Color3.fromRGB(226, 216, 190), {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.Ink,
	}),
})

-- Panel: one kit frame, a header (step tabs or a title), pages, a footer
local panel = slotArt(new("ImageLabel", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(480, 760),
	Active = true,
}), 0.42)
panel.Parent = root
new("UIScale", { Name = "Fit", Parent = panel })

new("Frame", {
	Name = "Head",
	Parent = panel,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 20),
	Size = UDim2.new(1, -48, 0, 48),
}, {
	new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}),
	text("Title", TITLE, 24, C.Cream, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Choose your cultivator",
	}),
})

local pages = new("CanvasGroup", {
	Name = "Pages",
	Parent = panel,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 76),
	Size = UDim2.new(1, 0, 1, -76 - 132),
})
for _, id in { "Slots", "Appearance", "Hair", "Name" } do
	new("ScrollingFrame", {
		Name = id,
		Parent = pages,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Gold,
		ScrollBarImageTransparency = 0.3,
		Visible = id == "Slots",
	}, {
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 24),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 12),
		}),
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
	})
end

local footer = new("Frame", {
	Name = "Footer",
	Parent = panel,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -22),
	Size = UDim2.new(1, -48, 0, 110),
}, {
	new("ImageLabel", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Image = ART.Divider,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.new(1, 0, 0, 20),
	}),
	text("Line", BODY, 17, C.Muted, {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}),
})
local buttons = new("Frame", {
	Name = "Buttons",
	Parent = footer,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 56),
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}),
	new("TextButton", {
		Name = "Quiet",
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(80, 56),
		FontFace = BOLD,
		TextSize = 18,
		TextColor3 = C.Lacquer,
		Text = "Delete",
	}, { motion() }),
})
local secondary, secondaryKids = slotButton("Secondary", 128, 56, "Back")
withChildren(secondary, secondaryKids).LayoutOrder = 2
secondary.Parent = buttons
local primary, primaryKids = slotButton("Primary", 200, 56, "Play")
withChildren(primary, primaryKids).LayoutOrder = 3
primary.Image = ART.SlotOn -- the lit frame: the one thing to press
primary.Label.TextColor3 = C.GoldBright
primary.Label.TextSize = 20
primary.Parent = buttons

-- Modal cards (no dimming behind them): the odds list and the delete confirm
local modal = new("Frame", {
	Name = "Modal",
	Parent = root,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Active = true,
	ZIndex = 5,
})
local function card(name, h)
	local c = slotArt(new("ImageLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, h),
		Visible = false,
		Active = true,
	}), 0.42)
	new("UIScale", { Name = "Fit", Parent = c })
	text("Title", TITLE, 24, C.Cream, {
		Position = UDim2.fromOffset(36, 28),
		Size = UDim2.new(1, -118, 0, 32),
		Parent = c,
	})
	c.Parent = modal
	return c
end
local odds = card("Odds", 560)
new("ImageButton", {
	Name = "Close",
	Parent = odds,
	BackgroundTransparency = 1,
	Image = ART.BackSeal,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -22, 0, 18),
	Size = UDim2.fromOffset(50, 46),
}, { motion() })
new("ScrollingFrame", {
	Name = "List",
	Parent = odds,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 76),
	Size = UDim2.new(1, 0, 1, -100),
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Gold,
}, {
	new("UIPadding", { PaddingLeft = UDim.new(0, 36), PaddingRight = UDim.new(0, 36), PaddingBottom = UDim.new(0, 8) }),
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
})

local confirm = card("Delete", 300)
text("Body", BODY, 18, C.Muted, {
	Parent = confirm,
	Position = UDim2.fromOffset(36, 70),
	Size = UDim2.new(1, -72, 0, 120),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local confirmButtons = new("Frame", {
	Name = "Buttons",
	Parent = confirm,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 36, 1, -28),
	Size = UDim2.new(1, -72, 0, 56),
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}),
})
local keep, keepKids = slotButton("Keep", 140, 56, "Keep")
withChildren(keep, keepKids).LayoutOrder = 1
keep.Parent = confirmButtons
local hold, holdKids = slotButton("Hold", 240, 56, "Hold to delete")
withChildren(hold, holdKids).LayoutOrder = 2
hold.Label.ZIndex = 3
new("Frame", {
	Name = "Track",
	Parent = hold,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(9, 9),
	Size = UDim2.new(1, -18, 1, -18),
	ClipsDescendants = true,
	ZIndex = 2,
}, {
	new("Frame", {
		Name = "Fill",
		BackgroundColor3 = C.Fill,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
	}),
})
hold.Parent = confirmButtons

-- Templates (Components clones them)
local T = gui.Templates
local tab = new("TextButton", {
	Name = "Tab",
	Parent = T,
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(140, 48),
	Text = "",
	AutoButtonColor = false,
}, {
	motion(),
	text("Label", TITLE, 19, C.Muted, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }),
	new("Frame", {
		Name = "Underline",
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(56, 2),
		Visible = false,
	}),
})

text("Section", TITLE, 18, C.Gold, { Parent = T, Size = UDim2.new(1, 0, 0, 28) })
text("Note", BODY, 17, C.Muted, {
	Parent = T,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true,
})
new("TextButton", {
	Name = "Link",
	Parent = T,
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 32),
	FontFace = BOLD,
	TextSize = 17,
	TextColor3 = C.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})

local function grid(name, cell, gap)
	return new("Frame", {
		Name = name,
		Parent = T,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		new("UIGridLayout", {
			CellSize = cell,
			CellPadding = gap,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end
grid("CardGrid", UDim2.fromOffset(132, 156), UDim2.fromOffset(18, 12))
grid("SwatchGrid", UDim2.fromOffset(60, 60), UDim2.fromOffset(14, 12))

local cardT = slotArt(new("ImageButton", { Name = "Card", Parent = T, Size = UDim2.fromOffset(132, 156), AutoButtonColor = false }), 0.22)
withChildren(cardT, {
	motion(),
	new("ImageLabel", {
		Name = "Thumb",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(100, 100),
		ScaleType = Enum.ScaleType.Fit,
	}),
	text("Placeholder", TITLE, 40, C.Muted, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(100, 100),
		TextXAlignment = Enum.TextXAlignment.Center,
	}),
	text("Caption", BOLD, 16, C.Cream, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.new(1, -20, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
	}),
})

local swatchT = slotArt(new("ImageButton", { Name = "Swatch", Parent = T, Size = UDim2.fromOffset(60, 60), AutoButtonColor = false }), 0.22)
withChildren(swatchT, {
	motion(),
	new("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -24),
		BorderSizePixel = 0,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 4) }) }),
})

local field = new("Frame", {
	Name = "TextField",
	Parent = T,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, {
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
})
local row = new("Frame", { Name = "Row", Parent = field, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56) }, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}),
})
local box = slotArt(new("ImageLabel", { Name = "Box", Parent = row, Size = UDim2.new(0, 100, 1, 0) }), 0.22)
withChildren(box, {
	new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	new("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -80, 1, 0),
		FontFace = BOLD,
		TextSize = 20,
		TextColor3 = C.Cream,
		PlaceholderColor3 = Color3.fromRGB(150, 144, 130),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Text = "",
	}),
	text("Counter", BODY, 15, C.Muted, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 52, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	}),
})
local action, actionKids = slotButton("Action", 104, 56, "Apply")
withChildren(action, actionKids).LayoutOrder = 2
action.Parent = row
text("Status", BODY, 16, C.Muted, {
	Parent = field,
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true,
})

local fate = new("Frame", {
	Name = "FateRow",
	Parent = T,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
}, {
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
})
local fateRow = slotArt(new("ImageLabel", { Name = "Row", Size = UDim2.new(1, 0, 0, 76) }), 0.22)
fateRow.Parent = fate
withChildren(fateRow, {
	text("Kind", BOLD, 15, C.Gold, { Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -200, 0, 20), RichText = true }),
	text("Value", TITLE, 21, C.Cream, {
		Position = UDim2.fromOffset(22, 34),
		Size = UDim2.new(1, -200, 0, 28),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}),
})
local change, changeKids = slotButton("Change", 140, 52, "Change")
withChildren(change, changeKids)
change.AnchorPoint = Vector2.new(1, 0.5)
change.Position = UDim2.new(1, -12, 0.5, 0)
change.Label.FontFace = BOLD
change.Label.TextSize = 17
change.Parent = fateRow
text("Status", BODY, 16, C.Lacquer, {
	Parent = fate,
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextWrapped = true,
	Visible = false,
})

withChildren(slotArt(new("ImageButton", {
	Name = "SlotCard",
	Parent = T,
	AutoButtonColor = false,
	Size = UDim2.new(1, 0, 0, 80),
}), 0.22), {
	motion(),
	text("Title", TITLE, 22, C.Cream, {
		Position = UDim2.fromOffset(22, 13),
		Size = UDim2.new(1, -210, 0, 30),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}),
	text("Sub", BODY, 16, C.Muted, {
		Position = UDim2.fromOffset(22, 45),
		Size = UDim2.new(1, -210, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}),
	text("Realm", BOLD, 17, C.Gold, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 15),
		Size = UDim2.fromOffset(180, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
	}),
	text("When", BODY, 15, C.Muted, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 45),
		Size = UDim2.fromOffset(180, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
	}),
})

new("Frame", { Name = "OddsRow", Parent = T, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, {
	text("Label", BODY, 17, C.Cream, { Size = UDim2.new(0.5, 0, 1, 0) }),
	text("Rarity", BOLD, 16, C.Muted, { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.3, 0, 1, 0) }),
	text("Chance", BOLD, 17, C.Cream, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.2, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	}),
})

return "built"
