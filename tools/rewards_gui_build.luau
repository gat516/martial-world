--!nocheck
-- Builds StarterGui.Rewards (the reward banners: feed, floats, banner, card) from the
-- kit cuts, in a sandbox Studio (no Rojo), for export to assets/Rewards.rbxmx.
-- Run with execute_luau in Edit. It replaces Rewards' children; the ScreenGui itself
-- keeps its properties. Layout and art: docs/ui/rewards.md.
-- Ids: art/ui/assets.json ("codex/cut/ornament_*.png").

local gui = game:GetService("StarterGui"):FindFirstChild("Rewards")
assert(gui, "StarterGui.Rewards missing")
for _, c in gui:GetChildren() do
	c:Destroy()
end

local A = {
	card_boss = "rbxassetid://139872711040576",
	card_quest = "rbxassetid://120119552621110",
	rays_boss = "rbxassetid://95676207958916",
	ribbon_crimson = { "rbxassetid://121316271063702", "rbxassetid://128154077838383", "rbxassetid://108527414387394" },
	coin = "rbxassetid://91563334675271",
	tile_neutral = "rbxassetid://121233995525578",
	gem_gold = "rbxassetid://103434738704063",
	glyph_stone = "rbxassetid://76651936131955",
	emblem_peak = "rbxassetid://102118062177874",
	glint = "rbxassetid://131306954850384",
	plaque = "rbxassetid://131186990824070", -- toast_plaque.png
	disc = "rbxassetid://120857701622858", -- art_disc.png
	ruby_stud = "rbxassetid://73915978017269", -- codex/cut/ornament_ruby_stud.png
}

local CREAM = Color3.fromRGB(250, 236, 195)
local GOLD = Color3.fromRGB(240, 204, 115)
local JADE = Color3.fromRGB(140, 235, 185)
local DIM = Color3.fromRGB(215, 205, 180)
local INK = Color3.fromRGB(10, 10, 10)
local TITLE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local ITALIC = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local NUM = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	if (inst :: any):IsA("GuiObject") and props.BackgroundTransparency == nil then
		(inst :: any).BackgroundTransparency = 1
	end
	inst.Parent = parent
	return inst
end

local function text(name: string, props: { [string]: any }, parent: Instance): TextLabel
	local base = {
		Name = name,
		TextColor3 = CREAM,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0,
		FontFace = BODY,
		TextSize = 15,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local function aspect(parent: Instance, ratio: number, axis: Enum.DominantAxis?)
	return new("UIAspectRatioConstraint", { AspectRatio = ratio, DominantAxis = axis or Enum.DominantAxis.Width }, parent)
end

-- A three-part art strip (cap, stretched plain middle, cap) filling `parent`:
-- the caps keep their aspect at the strip's height, the middle takes the rest.
local function strip(parent: Instance, images: { string }, ratios: { number }, z: number): Frame
	local art = new("Frame", { Name = "Art", Size = UDim2.fromScale(1, 1), ZIndex = z }, parent)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, art)
	local capL = new("ImageLabel", { Name = "CapL", LayoutOrder = 1, Size = UDim2.fromScale(1, 1), Image = images[1], ZIndex = z }, art)
	aspect(capL, ratios[1], Enum.DominantAxis.Height)
	local mid = new("ImageLabel", { Name = "Mid", LayoutOrder = 2, Size = UDim2.fromScale(0, 1), Image = images[2], ZIndex = z }, art)
	new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }, mid)
	local capR = new("ImageLabel", { Name = "CapR", LayoutOrder = 3, Size = UDim2.fromScale(1, 1), Image = images[3], ZIndex = z }, art)
	aspect(capR, ratios[3], Enum.DominantAxis.Height)
	return art
end

-- An icon slot's contents: an image icon or a text glyph, centred.
local function iconSlot(parent: Instance, z: number, size: number)
	local icon = new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(size, size),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.glyph_stone,
		ZIndex = z,
	}, parent)
	local glyph = text("Glyph", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(size, size),
		TextScaled = true,
		FontFace = TITLE,
		Text = "卷",
		TextColor3 = GOLD,
		Visible = false,
		ZIndex = z,
	}, parent)
	return icon, glyph
end

-- Canvas: one authored UIScale (UiScale.fit) over a 1920x1080 / 844x390 baseline.
local canvas = new("Frame", {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
}, gui)
new("UIScale", { Name = "UiScale" }, canvas)

-- Feed ------------------------------------------------------------------------------
-- Rows are the toast's plaque (art/ui/toast_plaque.png, pointed bevelled ends), plain:
-- the colour sits on the icon's seal disc (art_disc), not on a frame. 34 px rows,
-- 6 px apart; the disc's left edge and the count's right edge both 4 px inside the
-- points (docs/ui/rewards.md, "Feed").
local feed = new("Frame", {
	Name = "Feed",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 0.58, 0),
	Size = UDim2.new(0, 264, 0.3, 0),
}, canvas)
new("UISizeConstraint", { MaxSize = Vector2.new(264, 196) }, feed)
new("UIListLayout", {
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
}, feed)
do
	local H = 34
	local point = 36 * H / 96 -- the plaque's point depth at this height
	local e = new("ImageLabel", {
		Name = "EntryTemplate",
		Size = UDim2.fromOffset(256, H),
		Image = A.plaque,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 47, 464, 49),
		SliceScale = H / 96,
		Visible = false,
		ZIndex = 2,
	}, feed)
	new("UIScale", { Name = "Motion" }, e)
	local disc = new("ImageLabel", {
		Name = "Disc",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, math.round(point) + 4, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		Image = A.disc,
		ImageColor3 = Color3.fromRGB(160, 188, 204),
		ZIndex = 3,
	}, e)
	iconSlot(disc, 4, 0.62)
	text("NameLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, math.round(point) + 4 + 24 + 8, 0.5, 0),
		Size = UDim2.new(1, -(math.round(point) + 36 + 52 + 8 + math.round(point) + 4), 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 15,
		Text = "Spirit Stones",
		ZIndex = 3,
	}, e)
	text("CountLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(math.round(point) + 4), 0.5, 0),
		Size = UDim2.fromOffset(52, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = NUM,
		TextSize = 16,
		TextColor3 = GOLD,
		Text = "x24",
		ZIndex = 3,
	}, e)
end

-- Floats (small tier) ---------------------------------------------------------------
local floats = new("Frame", { Name = "Floats", Size = UDim2.fromScale(1, 1), ZIndex = 4 }, canvas)
do
	local f = new("Frame", {
		Name = "FloatTemplate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Visible = false,
		ZIndex = 4,
	}, floats)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
	}, f)
	new("ImageLabel", {
		Name = "Icon",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(22, 22),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.glyph_stone,
		ZIndex = 4,
	}, f)
	text("Label", {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		FontFace = NUM,
		TextSize = 24,
		Text = "+12",
		ZIndex = 4,
	}, f)
end

-- Banner (medium tier; the region entry banner) -------------------------------------
local banner = new("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.fromOffset(620, 118),
	Visible = false,
	ZIndex = 5,
}, canvas)
new("UIScale", { Name = "Motion" }, banner)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 2),
}, banner)
text("Kicker", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), Text = "YOU HAVE ENTERED", TextColor3 = GOLD, ZIndex = 6 }, banner)
do
	local ribbon = new("Frame", { Name = "Ribbon", LayoutOrder = 2, Size = UDim2.fromOffset(440, 56), ZIndex = 5 }, banner)
	strip(ribbon, A.ribbon_crimson, { 242 / 151, 1, 244 / 151 }, 5)
	local title = text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.503),
		Size = UDim2.fromScale(0.64, 0.46),
		FontFace = TITLE,
		TextScaled = true,
		Text = "Ruined Borderlands",
		TextStrokeTransparency = 0.3,
		ZIndex = 7,
	}, ribbon)
	new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 13 }, title)
	local glint = new("ImageLabel", {
		Name = "Glint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.2, 0.5),
		Size = UDim2.fromScale(0.5, 1),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.glint,
		ImageTransparency = 1,
		ZIndex = 8,
	}, ribbon)
end
text("Tag", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), RichText = true, Text = "Qi Refining 3", ZIndex = 6 }, banner)
text("Subtitle", {
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 18),
	FontFace = ITALIC,
	TextSize = 14,
	TextColor3 = DIM,
	Text = "Broken walls of an older sect.",
	ZIndex = 6,
}, banner)

-- Card (big tier: boss victory, quest complete, milestone) -------------------------
local card = new("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -10),
	Size = UDim2.fromScale(0.62, 0.84),
	Visible = false,
	ZIndex = 10,
}, canvas)
aspect(card, 1024 / 652)
new("UISizeConstraint", { MaxSize = Vector2.new(600, 382) }, card)
new("UIScale", { Name = "Motion" }, card)
local rays = new("ImageLabel", {
	Name = "Rays",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(1.35, 1.35),
	Image = A.rays_boss,
	ImageTransparency = 0.25,
	ZIndex = 10,
}, card)
aspect(rays, 1)
local art = new("ImageLabel", {
	Name = "Art",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	Image = A.card_boss,
	ZIndex = 11,
}, card)
aspect(art, 1024 / 596)
do
	local crest = new("ImageLabel", {
		Name = "Crest",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 90 / 652),
		Size = UDim2.fromScale(0.083, 0.13),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.emblem_peak,
		Visible = false,
		ZIndex = 12,
	}, art)
	-- a rank crest's emblem, placed on the crest's hole by Rewards.openCard
	local emblem = new("ImageLabel", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 13,
	}, crest)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, emblem)
end
do
	local ribbon = new("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.119),
		Size = UDim2.fromScale(0.74, 0.17),
		ZIndex = 12,
	}, art)
	strip(ribbon, A.ribbon_crimson, { 242 / 151, 1, 244 / 151 }, 12)
	local title = text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.503),
		Size = UDim2.fromScale(0.62, 0.5),
		FontFace = TITLE,
		TextScaled = true,
		Text = "Victory",
		TextStrokeTransparency = 0.3,
		ZIndex = 14,
	}, ribbon)
	new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 14 }, title)
	new("ImageLabel", {
		Name = "Glint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.2, 0.5),
		Size = UDim2.fromScale(0.5, 1),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.glint,
		ImageTransparency = 1,
		ZIndex = 15,
	}, ribbon)
end
local body = new("Frame", {
	Name = "Body",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.22),
	Size = UDim2.fromScale(0.84, 0.71),
	ZIndex = 12,
}, art)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
}, body)
text("Subtitle", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 24),
	FontFace = ITALIC,
	TextSize = 19,
	TextColor3 = GOLD,
	Text = "Elder Wolf King defeated",
	ZIndex = 13,
}, body)
do
	local list = new("Frame", { Name = "List", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 82), ZIndex = 12 }, body)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 14),
	}, list)
	local t = new("Frame", { Name = "RewardTemplate", Size = UDim2.fromOffset(64, 82), Visible = false, ZIndex = 12 }, list)
	new("UIScale", { Name = "Motion" }, t)
	local tile = new("ImageLabel", {
		Name = "Tile",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.coin,
		ZIndex = 13,
	}, t)
	iconSlot(tile, 14, 0.5)
	new("ImageLabel", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(20, 20),
		ScaleType = Enum.ScaleType.Fit,
		Image = A.gem_gold,
		Visible = false,
		ZIndex = 15,
	}, tile)
	text("CountLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 2),
		Size = UDim2.fromOffset(56, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = NUM,
		TextSize = 16,
		Text = "x120",
		ZIndex = 15,
	}, tile)
	text("NameLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(78, 16),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "Spirit Stones",
		ZIndex = 13,
	}, t)
end
text("Stats", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), RichText = true, TextColor3 = JADE, Text = "", ZIndex = 13 }, body)
text("Unlock", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 20), TextColor3 = GOLD, Text = "", ZIndex = 13 }, body)
text("Flavour", {
	LayoutOrder = 5,
	Size = UDim2.new(1, 0, 0, 20),
	FontFace = ITALIC,
	TextSize = 14,
	TextColor3 = DIM,
	TextWrapped = true,
	Text = "",
	ZIndex = 13,
}, body)
text("Hint", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 6),
	Size = UDim2.new(0.6, 0, 0, 18),
	TextSize = 14,
	TextColor3 = DIM,
	Text = "Click to continue",
	ZIndex = 13,
}, art)

-- The Hud toast (only its subtree): the plaque (toast_plaque, pointed bevelled ends,
-- dark lacquer) with a kit ruby_stud set into each end. Hud.placeToast sizes the
-- message to its text and places the toast in Roblox's top bar row (docs/ui/rewards.md).
local toast = game:GetService("StarterGui").Hud:FindFirstChild("Toast")
if toast then
	toast.Image = A.plaque
	toast.ScaleType = Enum.ScaleType.Slice
	toast.SliceCenter = Rect.new(48, 47, 464, 49)
	toast.SliceScale = 0.375 -- 36 px tall
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.new(0.5, 0, 0, 30)
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.Size = UDim2.fromOffset(0, 0)
	for _, name in { "UIListLayout", "UISizeConstraint" } do
		local c = toast:FindFirstChild(name)
		if c then
			c:Destroy()
		end
	end
	local pad = toast:FindFirstChildOfClass("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 34)
	pad.PaddingRight = UDim.new(0, 34)
	local message = toast:FindFirstChild("Message")
	message.AutomaticSize = Enum.AutomaticSize.None
	message.Size = UDim2.fromOffset(200, 20)
	message.TextWrapped = true
	message.TextSize = 16
	message.LineHeight = 1
	message.TextColor3 = Color3.fromRGB(250, 236, 200)
	message.TextStrokeColor3 = Color3.fromRGB(12, 6, 4)
	local mc = message:FindFirstChildOfClass("UISizeConstraint")
	if mc then
		mc:Destroy()
	end
	-- studs sit in the ends: 16 px from each tip, outside the padded text box
	for name, x in { StudL = UDim.new(0, -18), StudR = UDim.new(1, 18) } do
		local stud = toast:FindFirstChild(name) or new("ImageLabel", { Name = name }, toast)
		stud.Image = A.ruby_stud
		stud.ScaleType = Enum.ScaleType.Fit
		stud.AnchorPoint = Vector2.new(0.5, 0.5)
		stud.Position = UDim2.new(x, UDim.new(0.5, 0))
		stud.Size = UDim2.fromOffset(20, 20)
		stud.LayoutOrder = 0
		stud.ZIndex = 21
	end
end

return "built"
