--!nocheck
-- Builds the world-prompt card (StarterGui.Prompts.Board.List.Card) and sizes the
-- touch Dock's column (docs/ui/dialogue.md, "Interaction prompts"). No art: the
-- card is a rounded dark plate with a hairline edge, live text, a key cap (PC) or
-- the action's glyph (touch, WorldPrompts picks), and the hold fill's nine
-- outline pieces (src/client/PromptHold.luau).
-- Run in a sandbox (no Rojo) with execute_luau:
--   loadstring(HttpService:GetAsync(base .. "tools/build_prompts.luau"))()
--   _G.PromptBuild.install()            -- rebuild the template in StarterGui.Prompts
--   _G.PromptBuild.card(style?)         -- a loose card for previews (style overrides STYLE)
-- then export StarterGui.Prompts to assets/Prompts.rbxmx. Keeps the Dock's own box
-- (aspect and max size mirror Hud.Stack) and every name WorldPrompts looks up.

local STYLE = {
	h = 52, -- the card's height (44 on a phone through the dock's Fit)
	w = 200, -- the template's width; WorldPrompts fits each board's cards to their text
	radius = 10,
	plate = Color3.fromRGB(14, 17, 23),
	plateAlpha = 0.14,
	sheen = 0.06, -- how much lighter the plate's top is than its foot
	edge = Color3.fromRGB(214, 172, 92),
	edgeAlpha = 0.72,
	edgeT = 1,
	fill = Color3.fromRGB(255, 220, 140),
	fillT = 2,
	key = 30, -- the key cap's size
	keyRadius = 7,
	keyFill = Color3.fromRGB(54, 61, 74),
	keyAlpha = 0,
	keyEdge = Color3.fromRGB(252, 242, 218), -- the cap's hairline
	keyText = Color3.fromRGB(252, 242, 218),
	keyLeft = 11,
	glyph = 24, -- touch: the glyph's size
	glyphLeft = 14,
	gap = 11, -- key (or glyph) to text
	padRight = 18,
	object = Color3.fromRGB(230, 202, 146),
	objectSize = 14,
	action = Color3.fromRGB(252, 242, 218),
	actionSize = 18,
}

local CREAM = Color3.fromRGB(252, 242, 218)
local STROKE = Color3.fromRGB(10, 10, 10)
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local SAMPLE_GLYPH = "rbxassetid://129912521604806" -- harvest

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function label(name, props, parent)
	props.Name = name
	props.BackgroundTransparency = 1
	props.TextStrokeColor3 = STROKE
	props.FontFace = Font.new(BUILDER, Enum.FontWeight.Bold)
	return new("TextLabel", props, parent)
end

local function merged(over)
	local s = table.clone(STYLE)
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

local CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.5001, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- the hold fill: nine pieces tracing the outline (PromptHold)
local function holdPieces(card, s)
	local r = math.min(s.radius, s.h / 2)
	local t = s.fillT
	local hold = new("Frame", {
		Name = "Hold",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, card)
	local function run(name, anchor, pos, size)
		new("Frame", {
			Name = name,
			AnchorPoint = anchor,
			Position = pos,
			Size = size,
			BackgroundColor3 = s.fill,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 3,
		}, hold)
	end
	run("TopR", Vector2.new(0, 0), UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(0, t))
	run("Right", Vector2.new(1, 0), UDim2.new(1, 0, 0, r), UDim2.fromOffset(t, 0))
	run("Bottom", Vector2.new(1, 1), UDim2.new(1, -r, 1, 0), UDim2.fromOffset(0, t))
	run("Left", Vector2.new(0, 1), UDim2.new(0, 0, 1, -r), UDim2.fromOffset(t, 0))
	run("TopL", Vector2.new(0, 0), UDim2.new(0, r, 0, 0), UDim2.fromOffset(0, t))
	local corners = {
		TR = { Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromOffset(-r, 0) },
		BR = { Vector2.new(1, 1), UDim2.fromScale(1, 1), UDim2.fromOffset(-r, -r) },
		BL = { Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromOffset(0, -r) },
		TL = { Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromOffset(0, 0) },
	}
	for name, c in corners do
		local clip = new("Frame", {
			Name = name,
			AnchorPoint = c[1],
			Position = c[2],
			Size = UDim2.fromOffset(r, r),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 3,
		}, hold)
		local ring = new("Frame", {
			Name = "Ring",
			Position = c[3],
			Size = UDim2.fromOffset(2 * r, 2 * r),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, clip)
		new("UICorner", { CornerRadius = UDim.new(0, r) }, ring)
		local stroke = new("UIStroke", {
			Name = "Line",
			Color = Color3.new(1, 1, 1),
			Thickness = t,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, ring)
		new("UIGradient", {
			Color = ColorSequence.new(s.fill),
			Transparency = CUT,
		}, stroke)
	end
	return hold
end

local function card(over)
	local s = merged(over)
	local r = math.min(s.radius, s.h / 2)
	local c = new("ImageButton", {
		Name = "Card",
		Size = UDim2.fromOffset(s.w, s.h),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Image = "",
	})
	new("UIScale", { Name = "Motion" }, c)

	local plate = new("Frame", {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = s.plateAlpha,
		BorderSizePixel = 0,
	}, c)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, plate)
	local top = s.plate:Lerp(Color3.new(1, 1, 1), s.sheen)
	new("UIGradient", {
		Name = "Sheen",
		Rotation = 90,
		Color = ColorSequence.new(top, s.plate),
	}, plate)
	new("UIStroke", {
		Name = "Edge",
		Color = s.edge,
		Transparency = s.edgeAlpha,
		Thickness = s.edgeT,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, plate)

	-- PC: the key cap, with the key letter (or the gamepad button's image)
	local key = new("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, s.keyLeft, 0.5, 0),
		Size = UDim2.fromOffset(s.key, s.key),
		BackgroundColor3 = s.keyFill,
		BackgroundTransparency = s.keyAlpha,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, c)
	new("UICorner", { CornerRadius = UDim.new(0, s.keyRadius) }, key)
	key:SetAttribute("Fill", s.keyAlpha) -- WorldPrompts drops the cap under a gamepad button's art
	do
		new("UIStroke", {
			Name = "Edge",
			Enabled = s.keyEdge ~= nil,
			Color = s.keyEdge or s.keyFill,
			Transparency = 0.3,
			Thickness = 1,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, key)
	end
	label("Letter", {
		Size = UDim2.fromScale(1, 1),
		Text = "F",
		TextColor3 = s.keyText,
		TextSize = 17,
		TextStrokeTransparency = 1,
		ZIndex = 2,
	}, key)
	new("ImageLabel", {
		Name = "Pad",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 2,
	}, key)

	-- touch: the action's glyph instead of a key (WorldPrompts shows one or the other)
	new("ImageLabel", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, s.glyphLeft, 0.5, 0),
		Size = UDim2.fromOffset(s.glyph, s.glyph),
		BackgroundTransparency = 1,
		Image = SAMPLE_GLYPH,
		ImageColor3 = s.action,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 2,
	}, c)

	local textLeft = s.keyLeft + s.key + s.gap
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(textLeft, 0),
		Size = UDim2.new(1, -textLeft - s.padRight, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, c)
	local objH, actH = s.objectSize + 2, s.actionSize + 2
	local textTop = math.floor((s.h - objH - actH) / 2 + 0.5)
	label("Object", {
		Position = UDim2.fromOffset(0, textTop),
		Size = UDim2.new(1, 0, 0, objH),
		Text = "Herb Bed",
		TextColor3 = s.object,
		TextSize = s.objectSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeTransparency = 0.35,
		ZIndex = 2,
	}, body)
	label("Action", {
		Position = UDim2.fromOffset(0, textTop + objH),
		Size = UDim2.new(1, 0, 0, actH),
		Text = "Harvest",
		TextColor3 = s.action,
		TextSize = s.actionSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeTransparency = 0.35,
		ZIndex = 2,
	}, body)

	holdPieces(c, s)
	-- what WorldPrompts reads to lay a card out
	c:SetAttribute("TextLeftKey", textLeft)
	c:SetAttribute("TextLeftGlyph", s.glyphLeft + s.glyph + s.gap)
	c:SetAttribute("PadRight", s.padRight)
	c:SetAttribute("Gap", s.gap)
	c:SetAttribute("KeyPad", 9) -- a long key name's side padding on the cap
	return c
end

local function install(over)
	local s = merged(over)
	local prompts = game:GetService("StarterGui"):FindFirstChild("Prompts")
	local board = prompts:FindFirstChild("Board")
	local list = board:FindFirstChild("List")
	local old = list:FindFirstChild("Card")
	if old then
		old:Destroy()
	end
	local PAD = 6
	board.Size = UDim2.fromOffset(300, 460)
	list.Size = UDim2.new(1, 0, 0, 3 * s.h + 2 * PAD)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	layout.Padding = UDim.new(0, PAD)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local c = card(over)
	c.Visible = false
	c.Parent = list

	local dock = prompts:FindFirstChild("Dock")
	for _, name in { "List", "Lift" } do
		local f = dock:FindFirstChild(name)
		f.Size = UDim2.fromOffset(280, 3 * s.h + 2 * PAD)
		local l = f:FindFirstChildOfClass("UIListLayout")
		if l then
			l.Padding = UDim.new(0, PAD)
			l.HorizontalAlignment = Enum.HorizontalAlignment.Right
		end
	end
	return c
end

_G.PromptBuild = { STYLE = STYLE, card = card, install = install, CREAM = CREAM }
return "PromptBuild ready"
