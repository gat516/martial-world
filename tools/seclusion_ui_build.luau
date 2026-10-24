--!nocheck
-- Builds the seclusion pieces of the Cultivation ScreenGui (docs/ui/cultivation.md,
-- "Seclusion"): Canvas.Seclusion, the secluded-state overlay, and
-- Templates.SeclusionStreak, the streak's day pips that the seclusion card clones
-- into its body (Rewards.luau, kind "seclusion"). Sandbox only (edits
-- StarterGui.Cultivation in place); export the ScreenGui afterwards.
--
--   loadstring(game:GetService("HttpService"):GetAsync(base .. "tools/seclusion_ui_build.luau"))()
--
-- Names are the contract SeclusionView.luau reads (found recursively): Time,
-- Stones.Count, Finds (+Count), Garden (+Count), Streak (Pips.Pip1..7, Label), Hint.

local StarterGui = game:GetService("StarterGui")

local ART = {
	plaque = "rbxassetid://131186990824070", -- toast_plaque (draw_ui.py plain)
	lotus = "rbxassetid://124761481101447", -- art/ui/sized: margined display-sized copies (edge-margin lint)
	stone = "rbxassetid://78969533962170",
	chest = "rbxassetid://95028853803287",
	plant = "rbxassetid://132487955875515",
	gemJade = "rbxassetid://139500197356694",
	gemGrey = "rbxassetid://82455700461918",
}
local GOLD = Color3.fromRGB(240, 204, 115)
local CREAM = Color3.fromRGB(250, 236, 195)
local DIMC = Color3.fromRGB(215, 205, 180)
local STONE = Color3.fromRGB(200, 235, 255)
local JADE = Color3.fromRGB(130, 230, 185)
local INK = Color3.fromRGB(12, 10, 8)
local FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json")
local MERRI = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local BUILDER = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	i.Parent = parent
	return i
end

local function frame(name, props, parent)
	local f = new("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
	for k, v in props do
		f[k] = v
	end
	return f
end

local function row(parent, pad, h)
	return new("UIListLayout", {
		FillDirection = h == false and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, pad),
	}, parent)
end

local function text(name, font, size, color, value, parent, order)
	return new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0,
		Text = value,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
		LayoutOrder = order or 0,
	}, parent)
end

local function icon(name, image, w, h, color, parent, order)
	return new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = color or Color3.new(1, 1, 1),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(w, h),
		LayoutOrder = order or 0,
	}, parent)
end

-- A glyph and a count, side by side.
local function gain(name, image, w, h, tint, count, size, parent, order, font)
	local g = frame(name, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size + 6), LayoutOrder = order }, parent)
	row(g, 3) -- the icons carry their own clear margin
	icon("Icon", image, w, h, tint, g, 1)
	text("Count", font or FREDOKA, size, CREAM, count, g, 2)
	return g
end

-- The streak: seven day pips and a label ("Day 3", or the card's bonus line).
local function streak(parent, pip, size, order)
	local s = frame("Streak", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, pip + 4), LayoutOrder = order or 0 }, parent)
	row(s, 8)
	local pips = frame("Pips", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, pip), LayoutOrder = 1 }, s)
	row(pips, math.max(2, math.floor(pip / 5)))
	for k = 1, 7 do
		icon(`Pip{k}`, if k <= 3 then ART.gemJade else ART.gemGrey, pip, pip, nil, pips, k).ImageTransparency = if k <= 3 then 0 else 0.35
	end
	text("Label", BUILDER, size, JADE, "Day 3", s, 2)
	return s
end

local gui = StarterGui:FindFirstChild("Cultivation")
local canvas = gui.Canvas
local old = canvas:FindFirstChild("Seclusion")
if old then
	old:Destroy()
end

local root = frame("Seclusion", {
	AnchorPoint = Vector2.new(0.5, 0),
	-- just under the toast: 84 baseline px on PC (1080), 72 on a phone (390)
	Position = UDim2.new(0.5, 0, 0.0174, 65),
	Size = UDim2.fromOffset(640, 92),
	Visible = false,
}, canvas)
new("UIScale", { Name = "Device", Scale = 1 }, root)

-- A lacquer plaque (the toast's, sliced taller) holding the line; the timer is the
-- hero, the gains sit dimmer beside it; the streak and the hint under it. Text sizes
-- keep 11 px on a phone (Device 0.62 times the canvas fit, about 0.89 at 844x390).
local plaque = new("ImageLabel", {
	Name = "Plaque",
	BackgroundTransparency = 1,
	Image = ART.plaque,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(48, 47, 464, 49),
	SliceScale = 0.62,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 58),
}, root)
new("UIPadding", { PaddingLeft = UDim.new(0, 42), PaddingRight = UDim.new(0, 42) }, plaque)
row(plaque, 12)
icon("Lotus", ART.lotus, 40, 34, nil, plaque, 1)
local time = text("Time", FREDOKA, 32, Color3.fromRGB(255, 244, 214), "2:14:05", plaque, 3)
time.Size = UDim2.fromOffset(0, 36)
frame("Sep", { BackgroundTransparency = 0.5, BackgroundColor3 = GOLD, Size = UDim2.fromOffset(2, 28), LayoutOrder = 4 }, plaque)
local stones = gain("Stones", ART.stone, 18, 29, STONE, "56", 24, plaque, 5)
local finds = gain("Finds", ART.chest, 29, 27, GOLD, "1", 24, plaque, 6)
local garden = gain("Garden", ART.plant, 32, 25, JADE, "Tended", 20, plaque, 7, BUILDER)
for _, g in { stones, finds, garden } do
	g.Count.TextColor3 = DIMC
end
garden.Count.TextColor3 = JADE
-- a faint dark backing behind the footer (the kit glow tinted near black, a sibling
-- so the row's layout ignores it) so the pips and hint read over a bright floor
local backing = icon("Backing", "rbxassetid://104343892760987", 520, 64, INK, root, 0)
backing.ScaleType = Enum.ScaleType.Stretch
backing.ImageTransparency = 0
backing.AnchorPoint = Vector2.new(0.5, 0.5)
backing.Position = UDim2.new(0.5, 0, 0, 64 + 13)
local footer = frame("Footer", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 26),
}, root)
row(footer, 18)
streak(footer, 22, 20, 1)
text("Hint", BUILDER, 20, CREAM, "Rise to leave", footer, 2)

-- The card's streak row (cloned into the Rewards card body, in card units)
local templates = gui.Templates
local oldT = templates:FindFirstChild("SeclusionStreak")
if oldT then
	oldT:Destroy()
end
local holder = frame("SeclusionStreak", { Size = UDim2.new(1, 0, 0, 22), Visible = false }, templates)
row(holder, 0)
local s = streak(holder, 16, 15, 1)
s.Label.Text = "Day 3 of your streak  ·  +20% stones"

return "built"
