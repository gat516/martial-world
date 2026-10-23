--!nocheck
-- Builds StarterGui.Events (assets/Events.rbxmx): the world-event herald and
-- tracker, map pins and edge chips, the tribulation decree card, ribbon and
-- strike counter, the secret-realm rift card and the leaderboard window
-- (docs/ui/world-events.md, docs/ui/leaderboards.md). Run in a sandbox's Edit
-- datamodel (execute_luau, or loadstring over the art server), then export with
-- tools/export_rbxmx.luau. Rebuilding replaces StarterGui.Events entirely, so
-- check the live one for hand edits first.
--
-- Layout: Canvas (fitted by UiScale) holds a Desktop (1920x1080 baseline) and a
-- Phone (844x390 baseline) set of empty slots; the art lives once in Templates
-- (scale-sized, so a clone fills whatever slot it's put in). Scripts clone a
-- template into the active layout's slot (src/client/Events/Gui.luau).

local StarterGui = game:GetService("StarterGui")

local ID = {
	scrollL = "rbxassetid://73036725196235",
	scrollMid = "rbxassetid://106133334803822",
	scrollR = "rbxassetid://129705601108362",
	ring = "rbxassetid://97810020385298",
	pin_gold = "rbxassetid://140034976306899",
	pin_jade = "rbxassetid://125833552344790",
	pin_crimson = "rbxassetid://92114884196856",
	pin_violet = "rbxassetid://102174260949277",
	chip = "rbxassetid://108041912018323",
	chipLeft = "rbxassetid://107078935288974",
	decree = "rbxassetid://108539019875953",
	ribbonL = "rbxassetid://102351252997165",
	ribbonMid = "rbxassetid://134353008526051",
	ribbonR = "rbxassetid://125394177999203",
	rift = "rbxassetid://124608158646937",
	tagL = "rbxassetid://70503999231778",
	tagMid = "rbxassetid://111722632788009",
	tagR = "rbxassetid://79899687264489",
	rowL = "rbxassetid://90852865444525",
	rowMid = "rbxassetid://120707014056985",
	rowR = "rbxassetid://101821756222961",
	youL = "rbxassetid://74971763076994",
	youMid = "rbxassetid://134125149375254",
	youR = "rbxassetid://117844412948423",
	medal_gold = "rbxassetid://70786467802236",
	path_orthodox = "rbxassetid://110501063485049",
	cornerTL = "rbxassetid://128154669671865",
	cornerTR = "rbxassetid://138302523387403",
	cornerBL = "rbxassetid://93741706328335",
	cornerBR = "rbxassetid://88254032578616",
	crestL = "rbxassetid://121155858743627",
	crestMidL = "rbxassetid://77750472638110",
	crestCentre = "rbxassetid://126214334515284",
	crestMidR = "rbxassetid://123468701383865",
	crestR = "rbxassetid://139949631719973",
	closeSeal = "rbxassetid://123993787841180",
	btnL = "rbxassetid://76786990710767",
	btnMid = "rbxassetid://139624663880942",
	btnR = "rbxassetid://108707235283751",
	rubyStud = "rbxassetid://132816042612852",
	goldStud = "rbxassetid://103441340188755",
	divider = "rbxassetid://109654303489676",
	glint = "rbxassetid://108563894970515",
	sparkle = "rbxassetid://135105198809137",
	glow = "rbxassetid://133805277290521",
	notePanel = "rbxassetid://125037975495218",
}

local c = Color3.fromRGB
local GOLD = c(236, 196, 104)
local CREAM = c(250, 236, 195)
local INK = c(58, 34, 18)
local LACQUER = c(150, 28, 30)
local STROKE = c(14, 10, 8)
local DIM = c(196, 182, 150)

local TITLE = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local SMALL = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local NUMBER = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function frame(name, props, parent)
	props.Name = name
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.BorderSizePixel = 0
	return new("Frame", props, parent)
end

local function img(name, image, props, parent)
	props.Name = name
	props.Image = image
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	return new("ImageLabel", props, parent)
end

local function aspect(parent, ratio, dominant)
	return new("UIAspectRatioConstraint", {
		AspectRatio = ratio,
		DominantAxis = dominant or Enum.DominantAxis.Width,
	}, parent)
end

-- A text label filling its box: scaled text capped at maxSize, floored at minSize.
local function text(name, props, parent, maxSize, minSize)
	props.Name = name
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	props.FontFace = props.FontFace or SMALL
	props.TextColor3 = props.TextColor3 or CREAM
	if props.TextStrokeTransparency == nil then
		props.TextStrokeTransparency = 0
		props.TextStrokeColor3 = STROKE
	end
	local label = new("TextLabel", props, parent)
	if maxSize then
		new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = minSize or 1 }, label)
	end
	return label
end

-- Three-part (or five-part) horizontal art: caps keep their aspect (sized from
-- the height), the middle strips stretch. parts = { {name, id, w, h, fill?} }.
local function strip(parent, parts)
	local art = frame("Art", { Size = UDim2.fromScale(1, 1) }, parent)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	}, art)
	local made = {}
	for i, p in parts do
		local name, id, w, h, fill = p[1], p[2], p[3], p[4], p[5]
		local piece = img(name, id, { LayoutOrder = i, ScaleType = Enum.ScaleType.Stretch }, art)
		if fill then
			piece.Size = UDim2.fromScale(0, 1)
			new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }, piece)
		else
			piece.Size = UDim2.fromScale(4, 1)
			aspect(piece, w / h, Enum.DominantAxis.Height)
		end
		made[name] = piece
	end
	return art, made
end

local function motion(parent)
	return new("UIScale", { Name = "Motion", Scale = 1 }, parent)
end

local old = StarterGui:FindFirstChild("Events")
if old then
	old:Destroy()
end

local gui = new("ScreenGui", {
	Name = "Events",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 4,
})

local canvas = frame("Canvas", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1) }, gui)
new("UIScale", { Name = "UiScale", Scale = 1 }, canvas)

-- Slots per layout. Units are baseline pixels (1920x1080 desktop, 844x390 phone).
local SLOTS = {
	Desktop = {
		Herald = { UDim2.new(0.5, 0, 0, 112), Vector2.new(760, 118), Vector2.new(0.5, 0) },
		Ribbon = { UDim2.new(0.5, 0, 0, 112), Vector2.new(720, 96), Vector2.new(0.5, 0) },
		Tracker = { UDim2.new(0.5, 0, 0, 116), Vector2.new(900, 72), Vector2.new(0.5, 0) },
		Counter = { UDim2.new(0.5, 0, 0, 216), Vector2.new(84, 106), Vector2.new(0.5, 0) },
		Chips = { UDim2.fromScale(0.5, 0.42), Vector2.new(1920 - 48, 59), Vector2.new(0.5, 0.5) },
		Decree = { UDim2.new(0.5, 0, 0, 96), Vector2.new(280, 359), Vector2.new(0.5, 0) },
		Rift = { UDim2.fromScale(0.5, 0.5), Vector2.new(380, 519), Vector2.new(0.5, 0.5) },
		Board = { UDim2.fromScale(0.5, 0.5), Vector2.new(720, 600), Vector2.new(0.5, 0.5) },
	},
	Phone = {
		Herald = { UDim2.new(0.5, 0, 0, 96), Vector2.new(430, 70), Vector2.new(0.5, 0) },
		Ribbon = { UDim2.new(0.5, 0, 0, 96), Vector2.new(460, 62), Vector2.new(0.5, 0) },
		Tracker = { UDim2.new(0.5, 0, 0, 98), Vector2.new(560, 44), Vector2.new(0.5, 0) },
		Counter = { UDim2.new(0.5, 0, 0, 152), Vector2.new(56, 72), Vector2.new(0.5, 0) },
		Chips = { UDim2.fromScale(0.5, 0.5), Vector2.new(844 - 24, 46), Vector2.new(0.5, 0.5) },
		Decree = { UDim2.new(0.5, 0, 0, 68), Vector2.new(150, 192), Vector2.new(0.5, 0) },
		Rift = { UDim2.fromScale(0.5, 0.5), Vector2.new(250, 341), Vector2.new(0.5, 0.5) },
		Board = { UDim2.fromScale(0.5, 0.5), Vector2.new(600, 350), Vector2.new(0.5, 0.5) },
	},
}
for layout, slots in SLOTS do
	local root = frame(layout, { Size = UDim2.fromScale(1, 1), Visible = layout == "Desktop" }, canvas)
	for name, s in slots do
		local slot = frame(name, { Position = s[1], Size = UDim2.fromOffset(s[2].X, s[2].Y), AnchorPoint = s[3] }, root)
		if name == "Tracker" then
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, if layout == "Phone" then 16 else 28),
			}, slot)
		end
	end
end

local templates = frame("Templates", { Visible = false, Size = UDim2.fromScale(1, 1) }, gui)

----------------------------------------------------------------------------
-- Herald: the event scroll (paper rows 0.204-0.741 of the art's height).
do
	local root = frame("EventScroll", { Size = UDim2.fromScale(1, 1) }, templates)
	motion(root)
	strip(root, {
		{ "CapL", ID.scrollL, 239, 294 },
		{ "Mid", ID.scrollMid, 32, 294, true },
		{ "CapR", ID.scrollR, 249, 294 },
	})
	-- text on the root, centred on the whole scroll (the caps differ by a few px)
	text("Kicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.7, 0.17),
		ZIndex = 2,
		Text = "WORLD EVENT  ·  TO THE NORTHEAST",
		TextColor3 = LACQUER,
		TextStrokeTransparency = 1,
	}, root, 15, 10)
	text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.7, 0.29),
		ZIndex = 2,
		FontFace = TITLE,
		Text = "Thousand-Year Ginseng",
		TextColor3 = INK,
		TextStrokeTransparency = 1,
	}, root, 30, 14)
end

-- Ribbon: the tribulation warning (dark band rows 0.226-0.667).
do
	local root = frame("Ribbon", { Size = UDim2.fromScale(1, 1) }, templates)
	motion(root)
	strip(root, {
		{ "CapL", ID.ribbonL, 322, 177 },
		{ "Mid", ID.ribbonMid, 32, 177, true },
		{ "CapR", ID.ribbonR, 290, 177 },
	})
	text("Label", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.446),
		Size = UDim2.fromScale(0.72, 0.3),
		ZIndex = 2,
		FontFace = TITLE,
		Text = "The heavens descend on Wei Lan",
		TextColor3 = c(255, 226, 170),
	}, root, 26, 12)
end

-- Tracker entry: the countdown ring (hole 0.185-0.807 x, 0.174-0.819 y) with
-- the time, and the event's name beside it.
do
	local root = frame("TrackerEntry", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X }, templates)
	motion(root)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.12, 0),
	}, root)
	local ring = img("Ring", ID.ring, { LayoutOrder = 1, Size = UDim2.fromScale(4, 1) }, root)
	aspect(ring, 476 / 459, Enum.DominantAxis.Height)
	img("Pin", ID.pin_gold, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.496, 0.497),
		Size = UDim2.fromScale(0.62, 0.62),
		ImageTransparency = 0.82,
	}, ring)
	text("Time", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.496, 0.497),
		Size = UDim2.fromScale(0.62, 0.34),
		FontFace = NUMBER,
		Text = "11:42",
	}, ring, 24, 10)
	text("Title", {
		LayoutOrder = 2,
		Size = UDim2.fromScale(0, 0.4),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 20,
		Text = "Thousand-Year Ginseng",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, root)
end

-- Edge chip pointing at an off-screen event (plate 0.221-0.853 x, 0.26-0.83 y;
-- mirrored for the left edge).
for _, side in { "Right", "Left" } do
	local root = img("Chip" .. side, if side == "Right" then ID.chip else ID.chipLeft, { Size = UDim2.fromScale(4, 1) }, templates)
	aspect(root, 475 / 147, Enum.DominantAxis.Height)
	motion(root)
	local cx = if side == "Right" then 0.537 else 0.463
	text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, 0.44),
		Size = UDim2.fromScale(0.56, 0.27),
		Text = "Ginseng",
	}, root, 16, 10)
	text("Distance", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, 0.68),
		Size = UDim2.fromScale(0.56, 0.22),
		FontFace = NUMBER,
		Text = "240m",
		TextColor3 = GOLD,
	}, root, 13, 10)
end

-- The pin over the event in the world (head 0.219-0.80 x, 0.243-0.703 y).
do
	local bb = new("BillboardGui", {
		Name = "EventPin",
		Size = UDim2.fromOffset(44, 64),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 4000,
		StudsOffsetWorldSpace = Vector3.new(0, 16, 0),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, templates)
	local pin = img("Pin", ID.pin_gold, { Size = UDim2.new(1, 0, 0, 50) }, bb)
	text("Glyph", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.51, 0.473),
		Size = UDim2.fromScale(0.46, 0.4),
		FontFace = TITLE,
		Text = "參",
	}, pin, 18)
	text("Distance", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1.6, 0, 0, 14),
		Text = "240m",
	}, bb, 13)
end

----------------------------------------------------------------------------
-- Decree card (interior 0.102-0.900 x, 0.111-0.899 y).
do
	local root = img("Decree", ID.decree, { Size = UDim2.fromScale(1, 1) }, templates)
	motion(root)
	img("Glow", ID.glow, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromScale(0.9, 0.3),
		ImageColor3 = c(255, 214, 140),
		ImageTransparency = 0.7,
	}, root)
	text("Kicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.17),
		Size = UDim2.fromScale(0.7, 0.045),
		Text = "THE HEAVENS HAVE SPOKEN",
		TextColor3 = DIM,
	}, root, 14, 10)
	text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.235),
		Size = UDim2.fromScale(0.74, 0.08),
		FontFace = TITLE,
		Text = "Heaven's Decree",
		TextColor3 = GOLD,
	}, root, 34, 16)
	img("Divider", ID.divider, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.3),
		Size = UDim2.fromScale(0.62, 0.035),
		ScaleType = Enum.ScaleType.Fit,
	}, root)
	text("Count", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.45),
		Size = UDim2.fromScale(0.6, 0.15),
		FontFace = NUMBER,
		Text = "34",
		TextColor3 = GOLD,
	}, root, 72, 24)
	text("Unit", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.56),
		Size = UDim2.fromScale(0.74, 0.055),
		Text = "strikes of heavenly lightning",
	}, root, 20, 11)
	text("Body", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.68),
		Size = UDim2.fromScale(0.74, 0.1),
		Text = "Endure them on the platform. Watch the seals.",
		TextWrapped = true,
	}, root, 18, 11)
	text("Footer", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.501, 0.83),
		Size = UDim2.fromScale(0.7, 0.04),
		Text = "Fall, and the heavens will wait.",
		TextColor3 = DIM,
	}, root, 14, 10)
	img("Glint", ID.glint, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.111),
		Size = UDim2.fromScale(0.9, 0.06),
		ImageTransparency = 1,
	}, root)
end

-- Strike counter: the ring with strikes left, a label under it.
do
	local root = frame("StrikeCounter", { Size = UDim2.fromScale(1, 1) }, templates)
	motion(root)
	local ring = img("Ring", ID.ring, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 0.792),
		ImageColor3 = c(255, 236, 225),
	}, root)
	aspect(ring, 476 / 459)
	img("Flash", ID.sparkle, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.496, 0.497),
		Size = UDim2.fromScale(1.3, 1.3),
		ImageTransparency = 1,
	}, ring)
	text("Count", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.496, 0.497),
		Size = UDim2.fromScale(0.56, 0.4),
		FontFace = NUMBER,
		Text = "34",
	}, ring, 40, 14)
	text("Label", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1.6, 0.17),
		Text = "strikes left",
	}, root, 16, 11)
end

----------------------------------------------------------------------------
-- Rift card (interior below the portal, 0.19-0.98 y).
do
	local root = img("RiftCard", ID.rift, { Size = UDim2.fromScale(1, 1) }, templates)
	motion(root)
	text("Kicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.215),
		Size = UDim2.fromScale(0.7, 0.034),
		Text = "SECRET REALM RIFT",
		TextColor3 = c(206, 186, 255),
	}, root, 14, 10)
	text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.265),
		Size = UDim2.fromScale(0.84, 0.06),
		FontFace = TITLE,
		Text = "Sunken Bamboo Grotto",
		TextColor3 = GOLD,
	}, root, 30, 13)
	text("Realm", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.31),
		Size = UDim2.fromScale(0.8, 0.032),
		Text = "Recommended: Qi Condensation 6",
	}, root, 16, 10)
	img("Divider", ID.divider, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.348),
		Size = UDim2.fromScale(0.64, 0.024),
		ScaleType = Enum.ScaleType.Fit,
	}, root)
	text("ModsKicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.385),
		Size = UDim2.fromScale(0.7, 0.032),
		Text = "MODIFIERS",
		TextColor3 = DIM,
	}, root, 13, 10)
	local list = frame("Modifiers", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.41),
		Size = UDim2.fromScale(0.84, 0.33),
	}, root)
	new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.02, 0),
	}, list)
	text("Bonus", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.77),
		Size = UDim2.fromScale(0.8, 0.032),
		Text = "First clear today: double rewards",
		TextColor3 = c(150, 230, 190),
	}, root, 16, 10)
	-- the primary button (response_button: icon ring on the left cap)
	local button = new("ImageButton", {
		Name = "Enter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.865),
		Size = UDim2.fromScale(0.78, 0.085),
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		AutoButtonColor = false,
	}, root)
	motion(button)
	local _, bparts = strip(button, {
		{ "CapL", ID.btnL, 377, 221 },
		{ "Mid", ID.btnMid, 32, 221, true },
		{ "CapR", ID.btnR, 305, 221 },
	})
	text("Label", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.42),
		FontFace = TITLE,
		Text = "Enter the Rift",
		TextColor3 = CREAM,
	}, bparts.Mid, 20, 12)
	text("Glyph", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		FontFace = TITLE,
		Position = UDim2.fromScale(0.321, 0.543),
		Size = UDim2.fromScale(0.3, 0.46),
		Text = "入",
		TextColor3 = GOLD,
	}, bparts.CapL, 18, 10)
	local close = new("ImageButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.925, 0.215),
		Size = UDim2.fromScale(0.12, 0.08),
		BackgroundTransparency = 1,
		Image = ID.closeSeal,
		AutoButtonColor = false,
	}, root)
	aspect(close, 377 / 343)
	motion(close)
	text("Glyph", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		Text = "×",
	}, close, 22)
end

-- Rift modifier tag (plate 0.24-0.84 y).
do
	local root = frame("RiftTag", { Size = UDim2.fromScale(1, 0.23) }, templates)
	local _, parts = strip(root, {
		{ "CapL", ID.tagL, 231, 150 },
		{ "Mid", ID.tagMid, 32, 150, true },
		{ "CapR", ID.tagR, 139, 150 },
	})
	text("Label", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.02, 0.54),
		Size = UDim2.fromScale(0.96, 0.46),
		Text = "Frenzied beasts",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parts.Mid, 18, 10)
end

----------------------------------------------------------------------------
-- Leaderboard window: the note panel body, kit corners, title crest, close seal,
-- board tabs, a scrolling list of rows and your own row pinned under it.
do
	local root = frame("Board", { Size = UDim2.fromScale(1, 1) }, templates)
	motion(root)
	img("Body", ID.notePanel, {
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(64, 64, 448, 192),
		SliceScale = 0.5,
	}, root)
	local corners = { { "CornerTL", ID.cornerTL, 0, 0 }, { "CornerTR", ID.cornerTR, 1, 0 }, { "CornerBL", ID.cornerBL, 0, 1 }, { "CornerBR", ID.cornerBR, 1, 1 } }
	for _, k in corners do
		local corner = img(k[1], k[2], {
			AnchorPoint = Vector2.new(k[3], k[4]),
			Position = UDim2.new(k[3], if k[3] == 0 then -4 else 4, k[4], if k[4] == 0 then -4 else 4),
			Size = UDim2.fromScale(0.2, 0.2),
		}, root)
		aspect(corner, 573 / 386)
	end
	local crest = frame("Crest", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.56, 0.115),
	}, root)
	strip(crest, {
		{ "CapL", ID.crestL, 180, 250 },
		{ "MidL", ID.crestMidL, 32, 250, true },
		{ "Centre", ID.crestCentre, 402, 250 },
		{ "MidR", ID.crestMidR, 32, 250, true },
		{ "CapR", ID.crestR, 180, 250 },
	})
	text("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.62, 0.42),
		FontFace = TITLE,
		Text = "Rankings",
		TextColor3 = GOLD,
	}, crest, 28, 13)
	local close = new("ImageButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromScale(0.1, 0.1),
		BackgroundTransparency = 1,
		Image = ID.closeSeal,
		AutoButtonColor = false,
	}, root)
	aspect(close, 377 / 343)
	motion(close)
	text("Glyph", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		Text = "×",
	}, close, 22)

	local tabs = frame("Tabs", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.86, 0.075),
	}, root)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.02, 0),
	}, tabs)
	local tab = new("TextButton", {
		Name = "Tab",
		Size = UDim2.fromScale(0.23, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		FontFace = TITLE,
		Text = "Realm",
		TextScaled = true,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = STROKE,
		Visible = false,
	}, tabs)
	new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12 }, tab)
	new("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0) }, tab)
	img("Underline", ID.divider, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromScale(0.9, 0.16),
		ScaleType = Enum.ScaleType.Fit,
	}, tab)

	local heads = frame("Heads", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.185),
		Size = UDim2.fromScale(0.86, 0.04),
	}, root)
	for _, h in { { "Rank", 0.075, 0.5, Enum.TextXAlignment.Center }, { "Cultivator", 0.17, 0.4, Enum.TextXAlignment.Left }, { "Path", 0.69, 0.08, Enum.TextXAlignment.Center }, { "Value", 0.8, 0.13, Enum.TextXAlignment.Right } } do
		text(h[1], {
			Position = UDim2.fromScale(h[2], 0),
			Size = UDim2.fromScale(h[3], 1),
			Text = string.upper(h[1]),
			TextColor3 = DIM,
			TextXAlignment = h[4],
		}, heads, 13, 10)
	end
	heads.Rank.Size = UDim2.fromScale(0.1, 1)
	heads.Rank.Position = UDim2.fromScale(0.025, 0)

	local list = new("ScrollingFrame", {
		Name = "List",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.235),
		Size = UDim2.fromScale(0.86, 0.56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}, root)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, list)

	img("Rule", ID.divider, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.815),
		Size = UDim2.fromScale(0.7, 0.03),
		ScaleType = Enum.ScaleType.Fit,
	}, root)
	frame("You", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.84),
		Size = UDim2.fromScale(0.86, 0.085),
	}, root)
end

-- A leaderboard row (dark band rows 0.27-0.80) and the "you" highlight.
for _, kind in { "Row", "RowYou" } do
	local you = kind == "RowYou"
	local root = frame(kind, { Size = UDim2.new(1, 0, 0, 44) }, templates)
	local _, parts = strip(root, {
		{ "CapL", if you then ID.youL else ID.rowL, if you then 192 else 190, if you then 165 else 164 },
		{ "Mid", if you then ID.youMid else ID.rowMid, 32, 164, true },
		{ "CapR", if you then ID.youR else ID.rowR, if you then 191 else 192, if you then 165 else 164 },
	})
	local cells = frame("Cells", { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, root)
	new("UIPadding", { PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0) }, cells)
	local medal = img("Medal", ID.medal_gold, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.075, 0.537),
		Size = UDim2.fromScale(4, 1.02),
	}, cells)
	aspect(medal, 570 / 562, Enum.DominantAxis.Height)
	text("Rank", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.075, 0.537),
		Size = UDim2.fromScale(0.08, 0.42),
		FontFace = NUMBER,
		Text = "1",
	}, cells, 22, 11)
	text("Player", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.17, 0.537),
		Size = UDim2.fromScale(0.5, 0.42),
		Text = if you then "You" else "Wei Lan",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if you then c(255, 236, 190) else CREAM,
	}, cells, 20, 11)
	local crest = img("Crest", ID.path_orthodox, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.73, 0.537),
		Size = UDim2.fromScale(4, 0.78),
	}, cells)
	aspect(crest, 1, Enum.DominantAxis.Height)
	text("Value", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.93, 0.537),
		Size = UDim2.fromScale(0.16, 0.42),
		FontFace = NUMBER,
		Text = "QC 9",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
	}, cells, 20, 11)
end

gui.Parent = StarterGui
return "built " .. #gui:GetDescendants() .. " instances"
