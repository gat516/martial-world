-- Rebuilds the world-prompt card in StarterGui.Prompts (Board.List.Card) and sizes
-- the touch Dock's list, from the kit's cut art (docs/ui/dialogue.md, "Interaction
-- prompts"). Run with execute_luau in a sandbox (no Rojo), preview, then export
-- StarterGui.Prompts to assets/Prompts.rbxmx. Keeps the Dock's own box (aspect and
-- max size mirror Hud.Stack) and every name WorldPrompts looks up.

local IDS = {
	keyplate = "rbxassetid://121226474356083",
	hold_ring = "rbxassetid://135790271348479",
	capL = "rbxassetid://79837537690613",
	mid = "rbxassetid://122116613176732",
	capR = "rbxassetid://102124660271118",
	glyph = "rbxassetid://129912521604806", -- harvest, the template's sample
}
local CAP_L = Vector2.new(159, 233)
local CAP_R = Vector2.new(559, 233)
-- the key plate's cream tile, measured in ornament_keyplate.png (270x262): x 55-215,
-- y 56-209 with its bevel; the flat face is about 0.44 of the plate
local TILE_CENTRE = Vector2.new(0.5, 0.506)
local TILE_SIZE = 0.44
-- the banner's visible plate is rows 3-210 of 233, so its middle sits at 0.457
local BANNER_MID = 0.457

local CARD_H = 52 -- the plate's diameter; at least a thumb on touch
local BANNER_H = 40
local CARD_W = 300 -- billboard
local DOCK_W = 280 -- touch column
local PAD = 6

local INK = Color3.fromRGB(26, 30, 34)
local STROKE = Color3.fromRGB(10, 10, 10)
local CREAM = Color3.fromRGB(252, 242, 218)
local OBJECT = Color3.fromRGB(206, 192, 160)
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function image(name: string, id: string, props: { [string]: any }, parent: Instance): ImageLabel
	props.Name = name
	props.Image = id
	props.BackgroundTransparency = 1
	return new("ImageLabel", props, parent)
end

local function label(name: string, props: { [string]: any }, parent: Instance): TextLabel
	props.Name = name
	props.BackgroundTransparency = 1
	props.TextStrokeColor3 = STROKE
	props.FontFace = Font.new(BUILDER, Enum.FontWeight.Bold)
	return new("TextLabel", props, parent)
end

local prompts = game:GetService("StarterGui"):FindFirstChild("Prompts") :: ScreenGui
local board = prompts:FindFirstChild("Board") :: BillboardGui
local list = board:FindFirstChild("List") :: Frame
local old = list:FindFirstChild("Card")
if old then
	old:Destroy()
end

board.Size = UDim2.fromOffset(CARD_W, 460)
list.Size = UDim2.new(1, 0, 0, 3 * CARD_H + 2 * PAD)
local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
layout.Padding = UDim.new(0, PAD)

local card = new("ImageButton", {
	Name = "Card",
	Size = UDim2.new(1, 0, 0, CARD_H),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Selectable = false,
	Image = "",
	Visible = false,
}, nil)
new("UIScale", { Name = "Motion" }, card)

-- the dark banner, tucked behind the plate from its centre
local lw = math.round(CAP_L.X * BANNER_H / CAP_L.Y)
local rw = math.round(CAP_R.X * BANNER_H / CAP_R.Y)
local banner = new("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, CARD_H / 2, 0.5, math.round((0.5 - BANNER_MID) * BANNER_H)),
	Size = UDim2.new(1, -CARD_H / 2, 0, BANNER_H),
	BackgroundTransparency = 1,
}, card)
image("CapL", IDS.capL, { Size = UDim2.new(0, lw, 1, 0) }, banner)
image("Mid", IDS.mid, { Position = UDim2.new(0, lw, 0, 0), Size = UDim2.new(1, -lw - rw, 1, 0) }, banner)
image("CapR", IDS.capR, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, rw, 1, 0) }, banner)

-- the action glyph at the banner's right end, just before the cap's cloud (keyboard and gamepad)
local glyph = math.round(BANNER_H * 0.5)
local glyphRight = rw - math.round(rw * 0.12) -- just inside the cap's plain left end
image("Icon", IDS.glyph, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -glyphRight, 0.5, 0),
	Size = UDim2.fromOffset(glyph, glyph),
	ScaleType = Enum.ScaleType.Fit,
	ImageColor3 = CREAM,
	ZIndex = 2,
}, card)

-- the key plate, with the key letter (or gamepad button, or on touch the glyph) on its tile
local key = image("Key", IDS.keyplate, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.fromOffset(CARD_H, CARD_H),
	ZIndex = 3,
}, card)
local tile = UDim2.fromScale(TILE_CENTRE.X, TILE_CENTRE.Y)
label("Letter", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = tile,
	Size = UDim2.fromScale(TILE_SIZE * 0.9, TILE_SIZE * 0.8),
	Text = "F",
	TextColor3 = INK,
	TextSize = 19,
	TextStrokeTransparency = 1,
	ZIndex = 4,
}, key)
image("Pad", "", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = tile,
	Size = UDim2.fromScale(TILE_SIZE, TILE_SIZE),
	ScaleType = Enum.ScaleType.Fit,
	Visible = false,
	ZIndex = 4,
}, key)
image("Glyph", IDS.glyph, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = tile,
	Size = UDim2.fromScale(TILE_SIZE * 0.8, TILE_SIZE * 0.8),
	ScaleType = Enum.ScaleType.Fit,
	ImageColor3 = INK,
	Visible = false,
	ZIndex = 4,
}, key)

-- hold progress: a dim track ring round the plate and a lit copy swept in two
-- clipped halves (WorldPrompts sets each half's UIGradient rotation)
local hold = new("Frame", {
	Name = "Hold",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1.14, 1.14),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
}, key)
image("Track", IDS.hold_ring, {
	Size = UDim2.fromScale(1, 1),
	ImageColor3 = Color3.fromRGB(70, 58, 36),
	ImageTransparency = 0.15,
	ZIndex = 2,
}, hold)
local cut = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
for _, side in { "Right", "Left" } do
	local right = side == "Right"
	local half = new("Frame", {
		Name = side,
		Position = UDim2.fromScale(if right then 0.5 else 0, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2,
	}, hold)
	local ring = image("Ring", IDS.hold_ring, {
		Position = UDim2.fromScale(if right then -1 else 0, 0),
		Size = UDim2.fromScale(2, 1),
		ImageColor3 = Color3.fromRGB(255, 232, 150),
		ZIndex = 2,
	}, half)
	new("UIGradient", { Transparency = cut, Rotation = if right then 0 else 180 }, ring)
end

-- the text, between the plate and the glyph
local textLeft = CARD_H + 6
local body = new("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(textLeft, 0),
	Size = UDim2.new(1, -textLeft - glyphRight - glyph - 6, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 2,
}, card)
label("Object", {
	Position = UDim2.fromOffset(0, 9),
	Size = UDim2.new(1, 0, 0, 14),
	Text = "Herb Bed",
	TextColor3 = OBJECT,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextStrokeTransparency = 0,
	ZIndex = 2,
}, body)
label("Action", {
	Position = UDim2.fromOffset(0, 23),
	Size = UDim2.new(1, 0, 0, 19),
	Text = "Harvest",
	TextColor3 = CREAM,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextStrokeTransparency = 0,
	ZIndex = 2,
}, body)
card.Parent = list

-- touch: the same cards in a column over the right end of the vitals plate
local dock = prompts:FindFirstChild("Dock") :: Frame
local dockList = dock:FindFirstChild("List") :: Frame
dockList.Size = UDim2.fromOffset(DOCK_W, 3 * CARD_H + 2 * PAD)
local dockLayout = dockList:FindFirstChildOfClass("UIListLayout") :: UIListLayout
dockLayout.Padding = UDim.new(0, PAD)
-- WorldPrompts shrinks the column with the stack on short screens (Fit.Scale)
local fit = dockList:FindFirstChild("Fit") or new("UIScale", { Name = "Fit" }, dockList)
fit.Scale = 1
-- Lift: where a leaving touch card fades out, lifted out of the list so the rest
-- don't move; the list's own box and scale
local lift = dock:FindFirstChild("Lift")
if lift then
	lift:Destroy()
end
lift = new("Frame", {
	Name = "Lift",
	AnchorPoint = dockList.AnchorPoint,
	Position = dockList.Position,
	Size = dockList.Size,
	BackgroundTransparency = 1,
}, dock)
new("UIScale", { Name = "Fit" }, lift)
return "built"
