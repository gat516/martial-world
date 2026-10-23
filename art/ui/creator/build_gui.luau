--!nocheck
-- Builds the join screen's GUI (ReplicatedStorage.CharacterCreatorGui, exported to
-- assets/CharacterCreator.rbxmx): the slot screen and the character creator on
-- one stage (docs/systems/save-slots.md, docs/systems/character-creator.md).
-- Run with the Studio MCP's execute_luau in Edit. It keeps Backdrop.Image,
-- Veil, Root.Preview (its World and pedestal) and Templates.Dummy and rebuilds
-- everything else. House pieces only (ids in art/ui/assets.json), the same ones the
-- Inventory wears (docs/ui/inventory.md), so the join screen matches the rest of the
-- UI (user, 2026-10-23: the curl frame on every card "does not match at all"):
--   the panel and the cards: the house window frame (panel_frame.png);
--   buttons and step tabs: the gold (primary, current) and lacquer pills;
--   arrow pickers, swatches, fields and rows: plain ink wells (slot_plain.png) with a thin
--   neutral edge (slot_edge.png) and, when chosen, the cream ring 3 px outside;
--   the slot screen's title: the gold house plaque (Ribbon.luau, docs/ui/ribbons.md);
--   one diamond divider. No ornament on anything that repeats.

local gui = game.ReplicatedStorage.CharacterCreatorGui

local ART = {
	Panel = "rbxassetid://89258362336776", -- panel_frame.png (the Inventory's window)
	Gold = "rbxassetid://124847805310931", -- button_gold.png
	Lacquer = "rbxassetid://88447362782150", -- button_lacquer.png
	Well = "rbxassetid://85613268683045", -- slot_plain.png
	Edge = "rbxassetid://104219227467575", -- slot_edge.png (white, tinted)
	Divider = "rbxassetid://99789570259645", -- codex/cut/ornament_divider_diamond.png
	Close = "rbxassetid://115115955425573", -- seal_close.png (the Inventory's close)
	PlaqueL = "rbxassetid://118333801422561", -- plaque/plaque_gold_capL.png
	PlaqueMid = "rbxassetid://99954964250094", -- plaque/plaque_gold_mid.png
	PlaqueR = "rbxassetid://137033002952842", -- plaque/plaque_gold_capR.png
}
local PANEL_SLICE = Rect.new(200, 200, 824, 824)
local PILL_SLICE = Rect.new(64, 40, 448, 88)
local WELL_SLICE = Rect.new(24, 24, 104, 104)
local WELL_SCALE = 0.6 -- as the Inventory's cells: 14 px corners

local C = {
	Cream = Color3.fromRGB(250, 236, 195),
	Muted = Color3.fromRGB(196, 186, 164),
	Gold = Color3.fromRGB(226, 188, 108),
	GoldBright = Color3.fromRGB(255, 222, 150),
	Lacquer = Color3.fromRGB(240, 110, 92),
	Ink = Color3.fromRGB(14, 16, 20),
	Stroke = Color3.fromRGB(10, 10, 10),
	Fill = Color3.fromRGB(150, 42, 36),
	Edge = Color3.fromRGB(150, 140, 120), -- SlotArt's NO_GRADE: the dim neutral edge
	Ring = Color3.fromRGB(255, 232, 178), -- the Inventory's chosen-cell ring
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

local function sliced(inst, image, rect, scale)
	inst.Image = image
	inst.ScaleType = Enum.ScaleType.Slice
	inst.SliceCenter = rect
	inst.SliceScale = scale
	inst.BackgroundTransparency = 1
	return inst
end

-- the house window frame (panel, modal cards)
local function panelArt(inst)
	return sliced(inst, ART.Panel, PANEL_SLICE, 0.3)
end

-- a pill button like the Inventory's: gold for the one thing to press, lacquer otherwise
local function pillButton(name, w, h, label, gold)
	local b = sliced(
		new("ImageButton", { Name = name, Size = UDim2.fromOffset(w, h), AutoButtonColor = false }),
		if gold then ART.Gold else ART.Lacquer,
		PILL_SLICE,
		0.3
	)
	return b, {
		motion(),
		text("Label", BOLD, 18, C.Cream, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -10),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = C.Stroke,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = label,
			ZIndex = 3,
		}),
	}
end

-- a plain ink well with its thin neutral edge; ring: also the cream ring 3 px
-- outside it, shown while chosen (Components.setSelected)
local function well(inst, ring)
	sliced(inst, ART.Well, WELL_SLICE, WELL_SCALE)
	new("ImageLabel", {
		Name = "Edge",
		Parent = inst,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = C.Edge,
		ImageTransparency = 0.35,
		ZIndex = 2,
	})
	sliced(inst.Edge, ART.Edge, WELL_SLICE, WELL_SCALE)
	if ring then
		local halo = new("ImageLabel", {
			Name = "Halo",
			Parent = inst,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 6, 1, 6),
			ImageColor3 = C.Ring,
			Visible = false,
			ZIndex = 2,
		})
		sliced(halo, ART.Edge, WELL_SLICE, WELL_SCALE)
	end
	return inst
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

-- Panel: the house window frame, a header (step tabs or a title), pages, a footer
local panel = panelArt(new("ImageLabel", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(480, 760),
	Active = true,
}))
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
			Padding = UDim.new(0, 8), -- four 102 px tabs fill the 432 px row exactly
		}),
	}),
	-- the slot screen's title on the gold house plaque; Ribbon.fit sizes it to its text
	new("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 48),
	}, {
		new("Frame", { Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
			new("ImageLabel", { Name = "CapL", BackgroundTransparency = 1, Image = ART.PlaqueL, Size = UDim2.new(0, 30, 1, 0) }),
			new("ImageLabel", {
				Name = "Mid",
				BackgroundTransparency = 1,
				Image = ART.PlaqueMid,
				ScaleType = Enum.ScaleType.Stretch,
				Position = UDim2.fromOffset(30, 0),
				Size = UDim2.new(1, -60, 1, 0),
			}),
			new("ImageLabel", {
				Name = "CapR",
				BackgroundTransparency = 1,
				Image = ART.PlaqueR,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 30, 1, 0),
			}),
		}),
		text("Title", TITLE, 21, C.Cream, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -60, 0.59, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = C.Stroke,
			Text = "Choose your cultivator",
			ZIndex = 2,
		}),
	}),
})

local pages = new("CanvasGroup", {
	Name = "Pages",
	Parent = panel,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 76),
	Size = UDim2.new(1, 0, 1, -76 - 132),
})
for _, id in { "Slots", "Appearance", "Hair", "Fate", "Name" } do
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
local secondary, secondaryKids = pillButton("Secondary", 128, 56, "Back", false)
withChildren(secondary, secondaryKids).LayoutOrder = 2
secondary.Parent = buttons
local primary, primaryKids = pillButton("Primary", 200, 56, "Play", true) -- gold: the one thing to press
withChildren(primary, primaryKids).LayoutOrder = 3
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
	local c = panelArt(new("ImageLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, h),
		Visible = false,
		Active = true,
	}))
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
	Image = ART.Close,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 22),
	Size = UDim2.fromOffset(44, 44),
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
local keep, keepKids = pillButton("Keep", 140, 56, "Keep", false)
withChildren(keep, keepKids).LayoutOrder = 1
keep.Parent = confirmButtons
local hold, holdKids = pillButton("Hold", 236, 56, "Hold to delete", false) -- with Keep, exactly the card's inner width (388)
withChildren(hold, holdKids).LayoutOrder = 2
new("Frame", {
	Name = "Track",
	Parent = hold,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.new(1, -12, 1, -12),
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
	}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) }),
})
hold.Parent = confirmButtons

-- Templates (Components clones them)
local T = gui.Templates
-- a step tab: the Inventory's tab pills (gold while current, lacquer otherwise);
-- four of them (Appearance, Hair, Fate, Name) across the panel's 432 px
local tab, tabKids = pillButton("Tab", 102, 44, "", false)
withChildren(tab, tabKids)
tab.Label.TextSize = 16
tab.Label.Size = UDim2.new(1, -10, 1, -10)
tab.Parent = T

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
grid("SwatchGrid", UDim2.fromOffset(60, 60), UDim2.fromOffset(14, 12))

-- An arrow picker (shirt, pants, a race's looks): a plain well, a lacquer arrow
-- pill at each end (56 px: 45 px on a phone at the 0.8 floor), the pick's name
-- centred with "1 / 3" under it (Components.arrowRow).
local arrowRow = well(new("ImageLabel", { Name = "ArrowRow", Parent = T, Size = UDim2.new(1, 0, 0, 68) }), false)
for _, side in { { "Prev", "\u{2039}", 0 }, { "Next", "\u{203A}", 1 } } do
	local arrow, arrowKids = pillButton(side[1], 56, 56, side[2], false)
	withChildren(arrow, arrowKids)
	arrow.AnchorPoint = Vector2.new(side[3], 0.5)
	arrow.Position = UDim2.new(side[3], if side[3] == 0 then 6 else -6, 0.5, 0)
	arrow.Label.TextSize = 30
	arrow.Label.Size = UDim2.fromScale(1, 1)
	arrow.Label.Position = UDim2.new(0.5, 0, 0.5, -2) -- the chevrons sit low in Builder Sans
	arrow.Parent = arrowRow
end
text("Value", TITLE, 20, C.Cream, {
	Parent = arrowRow,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(1, -140, 0, 28),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextStrokeTransparency = 0,
	TextStrokeColor3 = C.Stroke,
	RichText = true,
})
text("Count", BOLD, 15, C.Muted, {
	Parent = arrowRow,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 38),
	Size = UDim2.new(1, -140, 0, 20),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0,
	TextStrokeColor3 = C.Stroke,
})

-- A colour swatch (skin, hair): a plain well with the colour as a rounded chip
local swatchT = well(new("ImageButton", { Name = "Swatch", Parent = T, Size = UDim2.fromOffset(60, 60), AutoButtonColor = false }), true)
withChildren(swatchT, {
	motion(),
	new("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -16),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) }),
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
local box = well(new("ImageLabel", { Name = "Box", Parent = row, Size = UDim2.new(0, 100, 1, 0) }), false)
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
		ZIndex = 3,
	}),
	text("Counter", BODY, 15, C.Muted, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(0, 52, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}),
})
local action, actionKids = pillButton("Action", 104, 56, "Apply", false)
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
local fateRow = well(new("ImageLabel", { Name = "Row", Size = UDim2.new(1, 0, 0, 76) }), false)
fateRow.Parent = fate
withChildren(fateRow, {
	text("Kind", BOLD, 15, C.Gold, { Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -200, 0, 20), RichText = true, ZIndex = 3 }),
	text("Value", TITLE, 21, C.Cream, {
		Position = UDim2.fromOffset(22, 34),
		Size = UDim2.new(1, -200, 0, 28),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
	}),
})
local change, changeKids = pillButton("Change", 140, 52, "Change", false)
withChildren(change, changeKids)
change.AnchorPoint = Vector2.new(1, 0.5)
change.Position = UDim2.new(1, -12, 0.5, 0)
change.ZIndex = 3
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

withChildren(well(new("ImageButton", {
	Name = "SlotCard",
	Parent = T,
	AutoButtonColor = false,
	Size = UDim2.new(1, 0, 0, 80),
}), true), {
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

-- Sibling ZIndex: a well's Edge and Halo (ZIndex 2) draw over its other children
-- unless those sit higher; lift the text and buttons above them.
for _, d in gui:GetDescendants() do
	local edge = d:FindFirstChild("Edge")
	if d:IsA("ImageLabel") or d:IsA("ImageButton") then
		if edge and edge:IsA("ImageLabel") then
			for _, child in d:GetChildren() do
				if child:IsA("GuiObject") and child.Name ~= "Edge" and child.Name ~= "Halo" and child.ZIndex < 3 then
					child.ZIndex = 3
				end
			end
		end
	end
end

return "built"
