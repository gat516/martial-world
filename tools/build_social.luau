--!nocheck
-- Builds StarterGui.Social (assets/Social.rbxmx), the party and player-interaction UI
-- (docs/systems/party.md), in a sandbox Studio (no Rojo: it replaces the gui in place).
-- Export it with tools/export_rbxmx.luau to assets/Social.rbxmx; src/client/Social.luau
-- fills it at runtime. The authored text is sample data, so Edit view shows full pieces.
--
--   _G.buildSocial({ card = "ledger" })   -- "ledger" (shipped) | "slip" (the other direction)
--
-- Laid out once at the phone baseline (844x390) inside Canvas and fitted by UiScale
-- (max 1.3 on a desktop), like StarterGui.Sect. Every piece is a kit cut already
-- uploaded (art/ui/assets.json); nothing new is drawn.
--   Canvas
--     Card     the player card (centred window): name, realm, marks, Race / Bloodline /
--              Hall / Party rows, an avatar well (ledger), the action buttons (Actions)
--     People   everyone in the server (centred window): a scrolling list of PersonRows
--     Invite   the small invite prompt under the top bar: message, countdown, Accept/Decline
--     Pips     the party stack at the left edge: one PipRow per member
--     Leave    the "Leave party" button that pops beside your own pip
--     Templates  PersonRow, PipRow, ActionButton (cloned by the script)

local StarterGui = game:GetService("StarterGui")

local IMG = {
	panel = "rbxassetid://109038686288941", -- sized/panel_frame_h512 (Rect 100..412)
	close = "rbxassetid://121641567885110", -- sized/seal_close_h96
	well = "rbxassetid://85613268683045", -- slot_plain (128, Rect 24..104)
	gold = "rbxassetid://89951515494594", -- sized/button_gold_h64 (Rect 32,20,224,44)
	jade = "rbxassetid://132904097543542", -- sized/button_jade_h64
	lacquer = "rbxassetid://70679462267599", -- sized/button_lacquer_h64
	inset = "rbxassetid://135577003680078", -- sized/field_inset_h64 (Rect 24,24,232,40)
	note = "rbxassetid://119446469150241", -- sized/note_panel_h96 (Rect 24,24,168,72)
	band = "rbxassetid://77034028645753", -- nameplate_band (704x128, stretch)
	seal = "rbxassetid://108501117687747", -- seal_mark (cinnabar stamp, 128)
	shelterShield = "rbxassetid://70393328505917", -- sized/shelter_shield_h28 (the kit shield's silhouette)
	qiSwirl = "rbxassetid://86512540519668", -- sized/ornament_glyph_qi_h28
	plaque = "rbxassetid://106177972063212", -- sized/title_plaque_h80
}

local BUILDER = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MERRI = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local CREAM = Color3.fromRGB(236, 232, 220)
local GOLD = Color3.fromRGB(226, 186, 104)
local TITLE = Color3.fromRGB(255, 226, 160)
local MUTED = Color3.fromRGB(140, 136, 126)
local JADE = Color3.fromRGB(120, 214, 170)
local INK = Color3.fromRGB(10, 12, 14)
local RULE = Color3.fromRGB(214, 172, 92)
local TROUGH = Color3.fromRGB(14, 18, 20)
local HEALTH = ColorSequence.new(Color3.fromRGB(176, 40, 44), Color3.fromRGB(236, 96, 80))

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function frame(name, props, parent)
	props.Name = name
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.BorderSizePixel = 0
	return new("Frame", props, parent)
end

local function label(name, text, size, props, parent)
	props.Name = name
	props.Text = text
	props.TextSize = size
	props.FontFace = props.FontFace or BUILDER
	props.TextColor3 = props.TextColor3 or CREAM
	props.TextStrokeColor3 = INK
	props.TextStrokeTransparency = props.TextStrokeTransparency or 0
	props.BackgroundTransparency = 1
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
	return new("TextLabel", props, parent)
end

local function list(parent, padding, horizontal, props)
	local l = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding),
	}, parent)
	for k, v in props or {} do
		l[k] = v
	end
	return l
end

local function sliced(name, image, rect, scale, props, parent)
	props.Name = name
	props.Image = image
	props.ScaleType = Enum.ScaleType.Slice
	props.SliceCenter = rect
	props.SliceScale = scale
	props.BackgroundTransparency = 1
	return new("ImageLabel", props, parent)
end

-- A kit button (gold / jade / lacquer) with its caption as a child label.
local function button(name, text, style, size, parent, order)
	local b = new("ImageButton", {
		Name = name,
		Image = IMG[style],
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(32, 20, 224, 44),
		SliceScale = 0.6,
		BackgroundTransparency = 1,
		AutoButtonColor = true,
		Size = size,
		LayoutOrder = order or 0,
	}, parent)
	new("UIScale", { Name = "Motion" }, b)
	label("Label", text, 15, {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if style == "gold" then Color3.fromRGB(46, 28, 8) else CREAM,
		TextStrokeTransparency = if style == "gold" then 1 else 0,
	}, b)
	return b
end

local function window(name, size, title)
	local w = frame(name, {
		Size = size,
		Position = UDim2.new(0.5, 0, 0.5, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Active = true,
	})
	new("UIScale", { Name = "Motion" }, w)
	sliced("Backdrop", IMG.panel, Rect.new(100, 100, 412, 412), 0.42, { Size = UDim2.fromScale(1, 1) }, w)
	if title then
		local plaque = new("ImageLabel", {
			Name = "TitlePlaque",
			Image = IMG.plaque,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(224, 28),
			Position = UDim2.new(0.5, 0, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 2,
		}, w)
		label("Title", title, 15, {
			Size = UDim2.fromScale(1, 1),
			FontFace = MERRI,
			TextColor3 = TITLE,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, plaque)
	end
	local close = new("ImageButton", {
		Name = "Close",
		Image = IMG.close,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -20, 0, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
	}, w)
	new("UIScale", { Name = "Motion" }, close)
	return w
end

-- One "KIND  value" line of the card.
local function infoRow(parent, key, kind, value, order, muted, kindWidth)
	local r = frame(key, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order }, parent)
	label("Kind", kind, 14, { Size = UDim2.new(0, kindWidth, 1, 0), TextColor3 = GOLD }, r)
	label("Value", value, 16, {
		Size = UDim2.new(1, -kindWidth, 1, 0),
		Position = UDim2.fromOffset(kindWidth, 0),
		TextColor3 = if muted then MUTED else CREAM,
	}, r)
	return r
end

local function actions(parent, props)
	local a = frame("Actions", props, parent)
	list(a, 8, true, { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center })
	button("Invite", "Invite", "gold", UDim2.fromOffset(112, 44), a, 1)
	button("Visit", "Visit peak", "jade", UDim2.fromOffset(112, 44), a, 2)
	return a
end

-- Direction 1, "ledger": the Self card's family, avatar well on the left, who they are on
-- the right as KIND / value lines, the actions along the bottom.
local function cardLedger()
	local w = window("Card", UDim2.fromOffset(440, 252), nil)
	local well = sliced("Avatar", IMG.well, Rect.new(24, 24, 104, 104), 0.25, {
		Size = UDim2.fromOffset(104, 158),
		Position = UDim2.fromOffset(24, 22),
	}, w)
	local view = new("ViewportFrame", {
		Name = "View",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 244, 226),
		LightDirection = Vector3.new(-1, -1, -0.6),
	}, well)
	new("WorldModel", {}, view)
	local info = frame("Info", { Size = UDim2.fromOffset(272, 160), Position = UDim2.fromOffset(144, 22) }, w)
	label("PlayerName", "Li Wei", 20, { Size = UDim2.new(1, -30, 0, 26), FontFace = MERRI }, info)
	-- the marks (Friend, With you, Party leader) follow the realm in jade, as rich text
	label("Realm", 'Qi Condensation 3  <font color="#78D6AA">· Friend</font>', 16, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 28),
		TextColor3 = GOLD,
		RichText = true,
	}, info)
	frame("Rule", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 54), BackgroundColor3 = RULE, BackgroundTransparency = 0.6 }, info)
	local rows = frame("Rows", { Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 62) }, info)
	list(rows, 4)
	infoRow(rows, "Race", "RACE", "Beast Folk · Wolf", 1, false, 84)
	infoRow(rows, "Bloodline", "BLOODLINE", "None", 2, true, 84)
	infoRow(rows, "Hall", "HALL", "No Hall", 3, true, 84)
	infoRow(rows, "Party", "PARTY", "Travelling alone", 4, false, 84)
	actions(w, { Size = UDim2.new(1, -48, 0, 44), Position = UDim2.new(0, 24, 1, -22), AnchorPoint = Vector2.new(0, 1) })
	return w
end

-- Direction 2, "slip": no avatar; a narrow centred card, name and realm centred over a
-- two-by-two grid of KIND over value, the actions in a grid below.
local function cardSlip()
	local w = window("Card", UDim2.fromOffset(320, 262), nil)
	local info = frame("Info", { Size = UDim2.new(1, -48, 0, 170), Position = UDim2.fromOffset(24, 20) }, w)
	label("PlayerName", "Li Wei", 20, { Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 0), FontFace = MERRI, TextXAlignment = Enum.TextXAlignment.Center }, info)
	label("Realm", "Qi Condensation 3", 15, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 28), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center }, info)
	label("Mark", "Friend", 13, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 46), TextColor3 = JADE, TextXAlignment = Enum.TextXAlignment.Center }, info)
	frame("Rule", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 68), BackgroundColor3 = RULE, BackgroundTransparency = 0.6 }, info)
	local rows = frame("Rows", { Size = UDim2.new(1, 0, 0, 92), Position = UDim2.fromOffset(0, 76) }, info)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 40), CellPadding = UDim2.fromOffset(12, 6), SortOrder = Enum.SortOrder.LayoutOrder }, rows)
	local function cell(key, kind, value, order, muted)
		local c = frame(key, { LayoutOrder = order }, rows)
		label("Kind", kind, 12, { Size = UDim2.new(1, 0, 0, 16), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center }, c)
		label("Value", value, 15, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 18), TextColor3 = if muted then MUTED else CREAM, TextXAlignment = Enum.TextXAlignment.Center }, c)
	end
	cell("Race", "RACE", "Beast Folk · Wolf", 1)
	cell("Bloodline", "BLOODLINE", "None", 2, true)
	cell("Hall", "HALL", "No Hall", 3, true)
	cell("Party", "PARTY", "Travelling alone", 4)
	actions(w, { Size = UDim2.new(1, -40, 0, 44), Position = UDim2.new(0, 20, 1, -22), AnchorPoint = Vector2.new(0, 1) })
	return w
end

local function people()
	local w = window("People", UDim2.fromOffset(440, 276), "People")
	local scroller = new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -40, 1, -58),
		Position = UDim2.fromOffset(20, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}, w)
	list(scroller, 6)
	label("Empty", "No one else is on this mountain yet.", 15, {
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, w)
	return w, scroller
end

local function personRow(parent, name, realm, race, mark, markColor, order)
	local r = new("ImageButton", {
		Name = "PersonRow",
		Image = IMG.inset,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(24, 24, 232, 40),
		SliceScale = 0.4,
		BackgroundTransparency = 1,
		AutoButtonColor = true,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = order or 0,
	}, parent)
	label("PlayerName", name, 16, { Size = UDim2.new(1, -120, 0, 20), Position = UDim2.fromOffset(14, 4) }, r)
	label("Sub", `{realm} · {race}`, 14, { Size = UDim2.new(1, -120, 0, 16), Position = UDim2.fromOffset(14, 24), TextColor3 = GOLD }, r)
	label("Mark", mark, 13, {
		Size = UDim2.new(0, 96, 1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = markColor,
	}, r)
	return r
end

local function pipRow(parent, name, health, leader, near, order)
	local r = new("TextButton", {
		Name = "PipRow",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(150, 28),
		LayoutOrder = order or 0,
	}, parent)
	local seal = new("ImageLabel", {
		Name = "Leader",
		Image = IMG.seal,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Visible = leader,
	}, r)
	label("Glyph", "首", 10, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, TextTruncate = Enum.TextTruncate.None }, seal)
	local band = new("ImageLabel", {
		Name = "Band",
		Image = IMG.band,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromOffset(130, 24),
		Position = UDim2.fromOffset(20, 0),
	}, r)
	label("PlayerName", name, 13, { Size = UDim2.new(1, -36, 0, 16), Position = UDim2.fromOffset(18, 2), TextXAlignment = Enum.TextXAlignment.Center }, band)
	local trough = frame("Health", {
		Size = UDim2.new(1, -44, 0, 3),
		Position = UDim2.fromOffset(22, 19),
		BackgroundColor3 = TROUGH,
		BackgroundTransparency = 0.1,
	}, band)
	local fill = frame("Fill", { Size = UDim2.fromScale(health, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 }, trough)
	new("UIGradient", { Color = HEALTH }, fill)
	-- the party shelter's marks (Social.refreshShelter shows one): a jade shield on a
	-- sheltered member, the jade qi swirl on their patron; white glyphs, tinted here
	for _, mark in { { "Sheltered", IMG.shelterShield }, { "Patron", IMG.qiSwirl } } do
		new("ImageLabel", {
			Name = mark[1],
			Image = mark[2],
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ImageColor3 = Color3.fromRGB(150, 230, 190),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -17, 0, 1),
			Size = UDim2.fromOffset(16, 18),
			Visible = false,
		}, band)
	end
	if not near then
		band.ImageTransparency = 0.5
	end
	return r
end

local function invite()
	local w = frame("Invite", {
		Size = UDim2.fromOffset(320, 110),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Active = true,
	})
	new("UIScale", { Name = "Motion" }, w)
	sliced("Backdrop", IMG.note, Rect.new(24, 24, 168, 72), 0.5, { Size = UDim2.fromScale(1, 1) }, w)
	label("Message", "Li Wei invites you to travel together", 16, { Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(16, 10) }, w)
	label("Sub", "Qi Condensation 3 · party of 2", 14, { Size = UDim2.new(1, -80, 0, 16), Position = UDim2.fromOffset(16, 31), TextColor3 = GOLD }, w)
	label("Seconds", "30s", 14, {
		Size = UDim2.new(0, 48, 0, 16),
		Position = UDim2.new(1, -16, 0, 31),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = MUTED,
	}, w)
	local trough = frame("Timer", { Size = UDim2.new(1, -32, 0, 2), Position = UDim2.fromOffset(16, 50), BackgroundColor3 = TROUGH, BackgroundTransparency = 0.1 }, w)
	frame("Fill", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, BackgroundTransparency = 0 }, trough)
	local row = frame("Buttons", { Size = UDim2.new(1, -32, 0, 44), Position = UDim2.new(0, 16, 1, -10), AnchorPoint = Vector2.new(0, 1) }, w)
	list(row, 12, true, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	button("Accept", "Accept", "gold", UDim2.fromOffset(132, 44), row, 1)
	button("Decline", "Decline", "lacquer", UDim2.fromOffset(132, 44), row, 2)
	return w
end

_G.buildSocial = function(opts)
	opts = opts or {}
	local old = StarterGui:FindFirstChild("Social")
	if old then
		old:Destroy()
	end
	local gui = new("ScreenGui", {
		Name = "Social",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = 4,
	})
	local canvas = frame("Canvas", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) }, gui)
	new("UIScale", { Name = "UiScale" }, canvas)

	local card = if opts.card == "slip" then cardSlip() else cardLedger()
	card.Parent = canvas

	local peopleWindow, scroller = people()
	personRow(scroller, "Han Yue", "Qi Condensation 5", "Human", "Friend", JADE, 1)
	personRow(scroller, "Li Wei", "Qi Condensation 3", "Beast Folk", "With you", GOLD, 2)
	personRow(scroller, "Mo Lan", "Body Tempering 9", "Human", "In a party", MUTED, 3)
	personRow(scroller, "Su Qing", "Foundation 1", "Spirit Fox", "", MUTED, 4)
	peopleWindow.Parent = canvas

	invite().Parent = canvas

	local pips = frame("Pips", { Size = UDim2.fromOffset(150, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 8, 0.36, 0), Visible = false }, canvas)
	list(pips, 2)
	pipRow(pips, "Li Wei", 0.8, true, true, 1)
	pipRow(pips, "Han Yue", 1, false, true, 2)
	pipRow(pips, "Mo Lan", 0.35, false, false, 3)
	local leave = button("Leave", "Leave party", "lacquer", UDim2.fromOffset(130, 40), canvas)
	leave.Visible = false
	leave.Position = UDim2.new(0, 28, 0.36, 56) -- the script drops it under your own pip
	leave.ZIndex = 3

	local templates = frame("Templates", { Visible = false, Size = UDim2.fromOffset(400, 200) }, canvas)
	personRow(templates, "Name", "Realm", "Race", "", MUTED).Size = UDim2.fromOffset(400, 44)
	pipRow(templates, "Name", 1, false, true)
	button("ActionButton", "Action", "lacquer", UDim2.fromOffset(112, 44), templates)

	if opts.show then
		for _, n in opts.show do
			canvas:FindFirstChild(n).Visible = true
		end
	end
	gui.Parent = StarterGui
	return gui
end

return "buildSocial installed"
