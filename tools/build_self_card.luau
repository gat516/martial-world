--!nocheck
-- Builds StarterGui.Hud.SelfCard, the character window (docs/character/character-window.md),
-- in a sandbox Studio (no Rojo: it replaces the frame in place). Export the result with
-- tools/export_rbxmx.luau and splice it into assets/Hud.rbxmx; src/client/SelfCard.luau
-- fills it at runtime. The authored text is sample data, so Edit view shows a full card.
--
--   _G.buildSelfCard({ style = "open" })   -- "open" (shipped) | "wells" | "hero" (the directions)
--   _G.buildSelfCardTitles(card)          -- adds Edit look, the title line and the Titles page
--                                            to a built card (buildSelfCard calls it too)
-- Not built here: the Header seals (People, Settings) from the four-tile pass. To change an
-- exported card, run buildSelfCardTitles on it so the seals survive.
--
-- Shape (Inventory-sized: 760x500 at most, centred; Menus moves it under Roblox's top bar on
-- short screens):
--   SelfCard: Backdrop (panel_frame_h512), TitlePlaque "Self" (PC), Close, Motion, UISizeConstraint
--     Desktop: three columns, Self | Cultivation | Path, split by hairline dividers; each a
--       Head (title + rule) and a scrolling Body of sections
--     Phone: Tabs (Self, Cultivation, Path) and Pages, one page at a time, each two columns
--   A section (TextButton, plain, taps to expand): Kind (gold capitals, "+" when it has detail),
--   Top (NameLabel, Right), optional Bar (trough, Fill, Value), Summary (a few lines), Detail
--   (hidden; the exact numbers). The Weapon Dao section holds Rows built from RowTemplate.

local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")

local IMG = {
	panel = "rbxassetid://109038686288941", -- sized/panel_frame_h512
	plaque = "rbxassetid://106177972063212", -- sized/title_plaque_h80
	close = "rbxassetid://121641567885110", -- sized/seal_close_h96
	well = "rbxassetid://85613268683045", -- slot_plain (128, Rect 24..104)
	tabOn = "rbxassetid://89951515494594", -- sized/button_gold_h64
	tabOff = "rbxassetid://70679462267599", -- sized/button_lacquer_h64
	seal = "rbxassetid://88219194445713", -- sized/hud_round_seal_h128 (the header seals)
	back = "rbxassetid://117000073543601", -- icon_back
	check = "rbxassetid://83079856331555", -- sized/ornament_checkmark_h32 (51x42)
	chevron = "rbxassetid://86690174795106", -- sized/ornament_chevron_h24 (47x32)
}

local BUILDER = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local MERRI = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local CREAM = Color3.fromRGB(236, 232, 220)
local GOLD = Color3.fromRGB(226, 186, 104)
local MUTED = Color3.fromRGB(140, 136, 126)
local DETAIL = Color3.fromRGB(200, 196, 184)
local INK = Color3.fromRGB(10, 12, 14)
local RULE = Color3.fromRGB(214, 172, 92) -- the Inventory divider
local TROUGH = Color3.fromRGB(14, 18, 20)
local GOLD_FILL = ColorSequence.new(Color3.fromRGB(190, 140, 50), Color3.fromRGB(250, 214, 120))
local QI_FILL = ColorSequence.new(Color3.fromRGB(128, 92, 236), Color3.fromRGB(222, 206, 255))
local OVER_FILL = ColorSequence.new(Color3.fromRGB(255, 242, 196), Color3.fromRGB(255, 255, 244)) -- pale, apart from the gold's 250,214,120 end
local JADE_FILL = ColorSequence.new(Color3.fromRGB(62, 150, 112), Color3.fromRGB(150, 232, 190))

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
	return new("TextLabel", props, parent)
end

local function list(parent, padding, horizontal)
	return new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding),
	}, parent)
end

-- Text sizes per layout: phone body text has a floor of 14 px (character-window.md).
local function sizes(phone)
	return {
		kind = if phone then 12 else 11,
		name = 16,
		right = if phone then 14 else 13,
		summary = 14,
		detail = if phone then 14 else 13,
		value = 11,
		head = 15,
		row = 14,
	}
end

-- A bar: dark rounded trough with a faint gold edge and a gradient fill. Its value is the
-- section's Right label (the critic: text on an 8-14 px bar didn't read).
local function bar(parent, order, fillColors, share, marks, over)
	local holder = frame("Bar", { Size = UDim2.new(1, 0, 0, 8), LayoutOrder = order }, parent)
	local trough = frame("Trough", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TROUGH, BackgroundTransparency = 0.1 }, holder)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, trough)
	new("UIStroke", { Color = RULE, Transparency = 0.6, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, trough)
	local fill = frame("Fill", { Size = UDim2.fromScale(share, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 }, trough)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	new("UIGradient", { Name = "Theme", Color = fillColors }, fill)
	if over then
		-- the foundation past 100 %: the fill runs on in a brighter tone from the 100 % mark
		local o = frame("Over", {
			Size = UDim2.fromScale(over[2], 1),
			Position = UDim2.fromScale(over[1], 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Visible = over[2] > 0,
		}, trough)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, o)
		new("UIGradient", { Name = "Theme", Color = OVER_FILL }, o)
	end
	for i, at in marks or {} do
		frame(`Mark{i}`, {
			Size = UDim2.new(0, 2, 1, 0),
			Position = UDim2.fromScale(at, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = if at <= share then TROUGH else CREAM,
			BackgroundTransparency = 0.3,
			ZIndex = 2,
		}, trough)
	end
	return holder
end

-- One section. o: kind, name, right, rightColor, nameColor, bar = { colors, share, value, marks },
-- summary, detail, order, muted.
local function section(parent, name, o, phone)
	local s = sizes(phone)
	local b = new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CREAM,
		BackgroundTransparency = 1, -- SelfCard brightens it a little on hover
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = o.order or 0,
		Selectable = o.detail ~= nil,
		Active = o.detail ~= nil,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, if phone then 3 else 4),
		PaddingBottom = UDim.new(0, if phone then 4 else 5),
	}, b)
	list(b, 3)
	local kind = label("Kind", string.upper(o.kind), s.kind, {
		Size = UDim2.new(1, 0, 0, s.kind + 3),
		TextColor3 = if o.muted then MUTED else GOLD,
		LayoutOrder = 1,
	}, b)
	label("More", "+", 17, {
		Size = UDim2.new(0, 16, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
		Visible = o.detail ~= nil,
	}, kind)
	local top = frame("Top", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2 }, b)
	-- the name takes what the right-hand label leaves (SelfCard refits it at runtime)
	local rightW = if (o.right or "") ~= "" then TextService:GetTextSize(o.right, s.right, Enum.Font.BuilderSansBold, Vector2.new(400, 40)).X + 8 else 0
	label("NameLabel", o.name, s.name, {
		Size = UDim2.new(1, -rightW, 1, 0),
		TextColor3 = o.nameColor or (if o.muted then MUTED else CREAM),
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, top)
	label("Right", o.right or "", s.right, {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = o.rightColor or CREAM,
	}, top)
	if o.bar then
		bar(b, 3, o.bar.colors, o.bar.share, o.bar.marks, o.bar.over)
	end
	label("Summary", o.summary or "", s.summary, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		RichText = true,
		LineHeight = 1.1,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 4,
		Visible = (o.summary or "") ~= "",
	}, b)
	label("Detail", o.detail or "", s.detail, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		RichText = true,
		LineHeight = 1.1,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = DETAIL,
		LayoutOrder = 5,
		Visible = false,
	}, b)
	return b
end

-- A scrolling list of sections.
local function scroller(parent, name, props, gap)
	props.Name = name
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 4
	props.ScrollBarImageColor3 = RULE
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	props.ScrollBarImageTransparency = 0.65
	local sf = new("ScrollingFrame", props, parent)
	list(sf, gap or 6)
	new("UIPadding", { PaddingBottom = UDim.new(0, 6) }, sf) -- the last line ends clear of the edge
	return sf
end

-- Sample content -------------------------------------------------------------------

local GAIN = "#82E6B9"
local function g(t)
	return `<font color="{GAIN}">{t}</font>`
end
local CAT = "#E2BA68"
local function hint(cat, t, phone)
	return `<font color="{CAT}" size="{if phone then 12 else 11}">{cat}</font>  {t}`
end

local function selfSections(parent, phone, startOrder)
	local n = startOrder or 0
	section(parent, "Race", {
		kind = "Race",
		name = "Beast Folk · Wolf",
		right = "Rare",
		rightColor = Color3.fromRGB(140, 196, 255),
		detail = g("+1 run speed") .. "\n" .. g("+5% weapon strike damage"),
		order = n + 1,
	}, phone)
	section(parent, "Bloodline", { kind = "Bloodline", name = "None", muted = true, order = n + 2 }, phone)
	section(parent, "Stats", {
		kind = "Strength",
		name = "120 health",
		right = "Power x1.26",
		detail = "Max health 120\nPower x1.21 from your realm, " .. g("+4%") .. " from your foundations",
		order = n + 3,
	}, phone)
end

local function cultivationSections(parent, phone, which)
	if which == nil or which == "a" then
		section(parent, "Realm", {
			kind = "Realm",
			name = "Qi Condensation 3",
			nameColor = GOLD,
			right = "41%",
			bar = { colors = GOLD_FILL, share = 0.41 },
			summary = "Next: Qi Condensation 4",
			detail = "1,240 / 3,000 cultivation",
			order = 1,
		}, phone)
	end
	if which == nil or which == "b" then
		section(parent, "Foundation", {
			kind = "Foundation",
			-- 0-150 % on the bar, marks at 50 and 100 %, past 100 % brighter (SelfCard)
			name = `<font color="#82E6B9">Solid</font> foundation`,
			right = "118%",
			bar = { colors = GOLD_FILL, share = 100 / 150, marks = { 50 / 150, 100 / 150 }, over = { 100 / 150, 18 / 150 } },
			summary = hint("HUNT", "Slay a Stone Boar for the first time", phone)
				.. "\n"
				.. hint("HOME", "Harvest a tier II herb", phone),
			detail = hint("BOSS", "The fast road: defeat the Elder Wolf King", phone)
				.. "\n"
				.. g("+4% max health and power from your foundations"),
			order = 2,
		}, phone)
	end
	if which == nil or which == "a" then
		section(parent, "Dantian", {
			kind = "Dantian",
			name = "Raw qi",
			right = "180 / 260",
			bar = { colors = QI_FILL, share = 0.69 },
			detail = "Circulate while meditating to refine raw qi into cultivation",
			order = 3,
		}, phone)
		section(parent, "Heart", {
			kind = "Heart demon",
			name = "Calmed",
			right = "Qi Condensation",
			rightColor = DETAIL,
			nameColor = Color3.fromRGB(130, 230, 185),
			summary = "You let the old grudge go. The demon was calmed.",
			detail = g("Tempered 1 of your foundations"),
			order = 4,
		}, phone)
	end
end

local function daoSection(parent, phone, order)
	local s = sizes(phone)
	local sec = section(parent, "Dao", { kind = "Weapon Dao", name = "", order = order }, phone)
	sec.Top.Visible = false
	sec.Summary.Visible = false
	sec.Active = false
	sec.Selectable = false
	local rows = frame("Rows", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, sec)
	list(rows, 4)
	local samples = {
		{ "Sword Dao", "Lv 2 · 45%", 0.45, "rbxassetid://92216583348567" }, -- class glyphs (SlotArt)
		{ "Fist Dao", "Lv 1 · 60%", 0.6, "rbxassetid://121264210892533" },
		{ "Saber Dao", "Lv 0 · 20%", 0.2, "rbxassetid://92852547529431" },
	}
	for i, d in samples do
		local row = new("TextButton", {
			Name = if i == 1 then "RowTemplate" else `__PRow{i}`,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CREAM,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
		}, rows)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
		new("UIPadding", { PaddingBottom = UDim.new(0, 2) }, row)
		list(row, 2)
		local top = frame("Top", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 }, row)
		new("ImageLabel", {
			Name = "Icon",
			Image = d[4],
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ScaleType = Enum.ScaleType.Fit,
		}, top)
		label("NameLabel", d[1], s.row, { Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(24, 0), TextTruncate = Enum.TextTruncate.AtEnd }, top)
		label("Right", d[2], s.right, {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.fromScale(1, 0),
			AnchorPoint = Vector2.new(1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}, top)
		local holder = frame("Bar", { Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 2 }, row)
		local trough = frame("Trough", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TROUGH, BackgroundTransparency = 0.1 }, holder)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, trough)
		new("UIStroke", { Color = RULE, Transparency = 0.6, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, trough)
		local fill = frame("Fill", { Size = UDim2.fromScale(d[3], 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 }, trough)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
		new("UIGradient", { Name = "Theme", Color = GOLD_FILL }, fill)
		local detail = label("Detail", "12 / 30 Dao XP\n" .. g("+4% weapon damage") .. "\nNext level: " .. g("+8% weapon damage"), s.detail, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			RichText = true,
			LineHeight = 1.1,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = DETAIL,
			LayoutOrder = 3,
			Visible = false,
		}, row)
		if i == 1 then
			row.Visible = false -- the template; SelfCard clones it per trained class
		end
	end
	return sec
end

local function pathSections(parent, phone, which)
	if which == nil or which == "a" then
		section(parent, "Root", {
			kind = "Spirit Root",
			name = "Metal Root",
			nameColor = Color3.fromRGB(220, 224, 232),
			right = "Spirit grade",
			rightColor = Color3.fromRGB(150, 210, 255),
			summary = g("+10% weapon strike damage") .. "\nWashed 1 / 3 toward Earth grade",
			detail = g("+15% Metal technique damage") .. "\n" .. g("+10% cultivation speed"),
			order = 1,
		}, phone)
		section(parent, "Method", {
			kind = "Cultivation Method",
			name = "Iron Marrow Art",
			nameColor = Color3.fromRGB(150, 210, 255),
			right = "Spirit grade",
			rightColor = Color3.fromRGB(150, 210, 255),
			summary = g("+20% cultivation speed"),
			detail = "Matches your root\nTakes you up to the end of Foundation",
			order = 2,
		}, phone)
	end
	if which == nil or which == "b" then
		daoSection(parent, phone, 3)
	end
end

-- The avatar well: a plain ink well (slot_plain) with the ViewportFrame inset in it.
local function avatar(parent, size, position, order)
	local well = new("ImageLabel", {
		Name = "Avatar",
		Image = IMG.well,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(24, 24, 104, 104),
		SliceScale = 0.5,
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		LayoutOrder = order or 0,
	}, parent)
	new("ViewportFrame", {
		Name = "View",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 244, 226),
		LightDirection = Vector3.new(1, -1, -1), -- from the upper left
	}, well)
	return well
end

local function nameLabel(parent, order, phone)
	local n = label("PlayerName", "Lin Feng", if phone then 18 else 18, {
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = MERRI,
		TextColor3 = Color3.fromRGB(255, 226, 160),
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = order,
	}, parent)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, n)
	return n
end

-- Desktop -----------------------------------------------------------------------------

local COLS = {
	{ "Self", "Self", 0.27 },
	{ "Cultivation", "Cultivation", 0.38 },
	{ "Path", "Path", 0.35 },
}
local GAP = 10

local function column(parent, id, title, share, order, style)
	local col = frame(id, { Size = UDim2.new(share, -14, 1, 0), LayoutOrder = order }, parent)
	if style == "wells" then
		new("ImageLabel", {
			Name = "Well",
			Image = IMG.well,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(24, 24, 104, 104),
			SliceScale = 0.5,
			BackgroundTransparency = 1,
			ImageTransparency = 0.15,
			Size = UDim2.new(1, 0, 1, -30),
			Position = UDim2.fromOffset(0, 30),
		}, col)
	end
	local head = label("Head", title, 15, { Size = UDim2.new(1, 0, 0, 22), FontFace = MERRI, TextColor3 = Color3.fromRGB(255, 226, 160) }, col)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, head)
	frame("Rule", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 24), BackgroundColor3 = RULE, BackgroundTransparency = 0.6 }, col)
	local inset = if style == "wells" then 6 else 0
	local body = scroller(col, "Body", {
		Size = UDim2.new(1, -2 * inset, 1, -32 - 2 * inset),
		Position = UDim2.fromOffset(inset, 32 + inset),
	})
	return col, body
end

local function buildDesktop(card, style)
	local d = frame("Desktop", { Size = UDim2.new(1, -44, 1, -62), Position = UDim2.fromOffset(22, 40) }, card)
	list(d, GAP, true)
	local bodies = {}
	for i, c in COLS do
		local _, body = column(d, c[1], c[2], c[3], i * 2 - 1, style)
		bodies[c[1]] = body
		if i < #COLS then
			frame(`Divider{i}`, { Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = RULE, BackgroundTransparency = 0.6, LayoutOrder = i * 2 }, d)
		end
	end
	-- Self: avatar, name, then race / bloodline / strength
	local selfBody = bodies.Self
	if style == "hero" then
		local well = avatar(selfBody, UDim2.new(1, -6, 0, 236), nil, 0)
		local foot = frame("Foot", {
			Size = UDim2.new(1, -12, 0, 54),
			Position = UDim2.new(0.5, 0, 1, -6),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0,
			ZIndex = 2,
		}, well)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.25), NumberSequenceKeypoint.new(1, 0.1) }) }, foot)
		local nm = nameLabel(foot, 0, false)
		nm.Position = UDim2.fromOffset(0, 8)
		nm.ZIndex = 3
		label("RaceLine", "Beast Folk · Wolf", 13, { Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(6, 34), ZIndex = 3 }, foot)
		selfSections(selfBody, false, 1)
	else
		avatar(selfBody, UDim2.new(1, -6, 0, 140), nil, 0)
		nameLabel(selfBody, 1, false)
		selfSections(selfBody, false, 1)
	end
	cultivationSections(bodies.Cultivation, false)
	pathSections(bodies.Path, false)
	return d
end

-- Phone --------------------------------------------------------------------------------

local function tab(parent, id, text, order, on)
	local b = new("ImageButton", {
		Name = id .. "Tab",
		Image = if on then IMG.tabOn else IMG.tabOff,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(32, 20, 224, 44),
		SliceScale = 0.6,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
	}, parent)
	new("UIScale", { Name = "Motion" }, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, b)
	label("Label", text, 15, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if on then Color3.fromRGB(255, 244, 214) else Color3.fromRGB(170, 190, 184),
	}, b)
	return b
end

local function buildPhone(card)
	local p = frame("Phone", { Size = UDim2.fromScale(1, 1), Visible = false }, card)
	local tabs = frame("Tabs", { Size = UDim2.new(1, -110, 0, 36), Position = UDim2.fromOffset(22, 18) }, p)
	list(tabs, 8, true)
	tab(tabs, "Self", "Self", 1, true)
	tab(tabs, "Cultivation", "Cultivation", 2, false)
	tab(tabs, "Path", "Path", 3, false)
	local pages = frame("Pages", { Size = UDim2.new(1, -44, 1, -80), Position = UDim2.fromOffset(22, 62) }, p)
	-- each page: two columns split by a hairline
	local function page(id, visible)
		local pg = frame(id, { Size = UDim2.fromScale(1, 1), Visible = visible }, pages)
		return pg
	end
	local function halves(pg, leftShare)
		local a = scroller(pg, "Left", { Size = UDim2.new(leftShare, -8, 1, 0) }, 4)
		frame("Divider", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(leftShare, 0, 0, 0), BackgroundColor3 = RULE, BackgroundTransparency = 0.6 }, pg)
		local b = scroller(pg, "Right", { Size = UDim2.new(1 - leftShare, -8, 1, 0), Position = UDim2.new(leftShare, 8, 0, 0) }, 4)
		return a, b
	end
	-- Self: the avatar on the left, who you are on the right
	local selfPage = page("Self", true)
	avatar(selfPage, UDim2.new(0.3, -8, 1, 0))
	local who = scroller(selfPage, "Right", { Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0.3, 8, 0, 0) }, 4)
	who.Size = UDim2.new(0.7, -8, 1, 0)
	nameLabel(who, 0, true)
	selfSections(who, true, 0)
	-- Cultivation: realm, dantian, heart | foundation
	local cul = page("Cultivation", false)
	local ca, cb = halves(cul, 0.5)
	cultivationSections(ca, true, "a")
	cultivationSections(cb, true, "b")
	-- Path: root, method | weapon Dao
	local path = page("Path", false)
	local pa, pb = halves(path, 0.5)
	pathSections(pa, true, "a")
	pathSections(pb, true, "b")
	return p
end

-- Titles, Edit look ---------------------------------------------------------------------
-- (docs/systems/titles.md, character-window.md) Added to a built card by
-- _G.buildSelfCardTitles(card); buildSelfCard calls it too.
--   Self column: EditLook (a lacquer pill under the avatar; testbed only while the
--   creator is) and TitleRow (the name with the worn title and a chevron under it; one
--   46 px tap target that opens the Titles page).
--   Titles: a page over the card's body: Bar (Back seal, "Titles", the count, Wear none)
--   and a scrolling List of category groups (GroupTemplate, its Grid holding
--   CellTemplate), filled by SelfCard.

local SEAL_GLYPH = Color3.fromRGB(236, 214, 160) -- the header seals' cream glyphs
local SILHOUETTE = Color3.fromRGB(78, 80, 84)
local RARE = Color3.fromRGB(112, 222, 156)

local function pill(parent, name, text, height, props)
	local b = new("ImageButton", {
		Name = name,
		Image = IMG.tabOff,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(32, 20, 224, 44),
		SliceScale = 0.6,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = props.Size or UDim2.new(0, 0, 0, height),
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	}, parent)
	new("UIScale", { Name = "Motion" }, b)
	if not props.Size then
		new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, b)
	end
	label("Label", text, props.TextSize or 14, {
		Size = if props.Size then UDim2.fromScale(1, 1) else UDim2.new(0, 0, 1, 0),
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(236, 226, 200),
	}, b)
	return b
end

local function seal(parent, name, icon, order)
	local b = new("ImageButton", {
		Name = name,
		Image = IMG.seal,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(44, 44),
		LayoutOrder = order,
	}, parent)
	new("ImageLabel", {
		Name = "Icon",
		Image = icon,
		ImageColor3 = SEAL_GLYPH,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, b)
	new("UIScale", { Name = "Motion" }, b)
	return b
end

-- The name block: PlayerName over the worn title and the count; taps open Titles.
local function titleRow(parent, order, phone, nameInst)
	local b = new("TextButton", {
		Name = "TitleRow",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CREAM,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	new("UIPadding", { PaddingBottom = UDim.new(0, 2) }, b)
	list(b, 0)
	nameInst.LayoutOrder = 1
	nameInst.Parent = b
	local line = frame("Line", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 2 }, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 4) }, line)
	-- the count earned is on the Titles page: the Self column (160 px) has room for the
	-- longest title ("Foundation Perfected") or the count, not both
	label("NameLabel", "Wolf King's Bane", if phone then 15 else 14, {
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = RARE,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, line)
	new("ImageLabel", {
		Name = "Chevron",
		Image = IMG.chevron,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(12, 8),
		Position = UDim2.new(1, -4, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -90,
	}, line)
	return b
end

local function titleCell(parent, phone)
	local c = new("TextButton", {
		Name = "CellTemplate",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CREAM,
		BackgroundTransparency = 0.96,
		BorderSizePixel = 0,
		Visible = false,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, c)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 4),
	}, c)
	-- the worn cell's edge (SelfCard turns it on); a stroke on the button's border, never on text
	new("UIStroke", {
		Name = "WornEdge",
		Color = GOLD,
		Transparency = 0.35,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
	}, c)
	label("NameLabel", "Qi Refiner", 16, {
		Size = UDim2.new(1, -24, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, c)
	frame("Silhouette", {
		Size = UDim2.fromOffset(96, 10),
		Position = UDim2.fromOffset(0, 10),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = SILHOUETTE,
		BackgroundTransparency = 0.3,
		Visible = false,
	}, c)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, c.Silhouette)
	new("ImageLabel", {
		Name = "Worn",
		Image = IMG.check,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(19, 16),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
	}, c)
	label("How", "Reach Qi Refining 1.", if phone then 14 else 13, {
		Size = UDim2.new(1, 0, 1, -20),
		Position = UDim2.fromOffset(0, 20),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = DETAIL,
		LineHeight = 1, -- two lines fit the 56/58 px cells (measured: 26 px of 27 on PC, 28 of 29 at 667x375)
	}, c)
	return c
end

local function titlesPage(card, phone)
	local p = frame("Titles", {
		Size = UDim2.new(1, -44, 1, -62),
		Position = UDim2.fromOffset(22, 40),
		Visible = false,
	}, card)
	new("UIScale", { Name = "Motion" }, p)
	local bar = frame("Bar", { Size = UDim2.new(1, -134, 0, 44) }, p)
	local l = list(bar, 10, true)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	seal(bar, "Back", IMG.back, 1)
	label("Heading", "Titles", 18, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = MERRI,
		TextColor3 = Color3.fromRGB(255, 226, 160),
		LayoutOrder = 2,
	}, bar)
	label("Count", "12 / 43 earned", 15, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = DETAIL,
		LayoutOrder = 3,
	}, bar)
	pill(bar, "WearNone", "Wear none", 36, { LayoutOrder = 4 })
	local sc = scroller(p, "List", { Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52) }, 6)
	sc:FindFirstChildOfClass("UIPadding").PaddingRight = UDim.new(0, 6) -- clear of the scroll bar
	local g = frame("GroupTemplate", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, sc)
	list(g, 4)
	local head = frame("Head", { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 }, g)
	label("Kind", "REALM", if phone then 12 else 11, { Size = UDim2.fromScale(1, 1), TextColor3 = GOLD }, head)
	label("Count", "2 / 4", if phone then 12 else 11, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = DETAIL,
	}, head)
	local grid = frame("Grid", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, g)
	new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = if phone then UDim2.new(0.5, -4, 0, 58) else UDim2.new(1 / 3, -6, 0, 56),
		CellPadding = UDim2.fromOffset(8, 6),
	}, grid)
	titleCell(grid, phone)
	return p
end

-- Adds (or rebuilds) the Edit look button, the title row and the Titles page.
_G.buildSelfCardTitles = function(card)
	for _, d in card:GetDescendants() do
		if d.Name == "EditLook" or d.Name == "EditLookRow" or d.Name == "Titles" then
			d:Destroy()
		end
	end
	for _, d in card:GetDescendants() do
		if d.Name == "TitleRow" then
			local nm = d:FindFirstChild("PlayerName")
			nm.Parent = d.Parent
			d:Destroy()
		end
	end
	-- desktop: Avatar, EditLook, TitleRow (PlayerName inside), the sections
	local selfBody = card.Desktop.Self.Body
	selfBody.Avatar.LayoutOrder = -2
	-- in a row of its own, narrower than the well, so its hover pop stays inside the column
	local lookRow = frame("EditLookRow", { Size = UDim2.new(1, -6, 0, 32), LayoutOrder = -1 }, selfBody)
	pill(lookRow, "EditLook", "Edit look", 32, {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	titleRow(selfBody, 1, false, selfBody.PlayerName)
	-- phone: the avatar column ends in EditLook; the right column starts with TitleRow
	local selfPage = card.Phone.Pages.Self
	selfPage.Avatar.Size = UDim2.new(0.3, -8, 1, -50)
	pill(selfPage, "EditLook", "Edit look", 44, {
		Size = UDim2.new(0.3, -8, 0, 44),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 15,
	})
	titleRow(selfPage.Right, 0, true, selfPage.Right.PlayerName)
	titlesPage(card, false)
	return card
end

-- The card ------------------------------------------------------------------------------

_G.buildSelfCard = function(opts)
	opts = opts or {}
	local style = opts.style or "open"
	local hud = StarterGui:FindFirstChild(opts.gui or "Hud")
	local old = hud:FindFirstChild("SelfCard")
	local visible = opts.visible
	if old then
		if visible == nil then
			visible = old.Visible
		end
		old:Destroy()
	end
	local card = frame("SelfCard", {
		Size = UDim2.fromScale(0.94, 0.86),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = visible or false,
		ZIndex = 1,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(760, 500) }, card)
	new("UIScale", { Name = "Motion" }, card)
	new("ImageLabel", {
		Name = "Backdrop",
		Image = IMG.panel,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(100, 100, 412, 412),
		SliceScale = 0.6,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, card)
	local plaque = new("ImageLabel", {
		Name = "TitlePlaque",
		Image = IMG.plaque,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(320, 40),
		Position = UDim2.new(0.5, 0, 0, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, card)
	label("Title", "Self", 16, {
		Size = UDim2.fromScale(1, 1),
		FontFace = MERRI,
		TextColor3 = Color3.fromRGB(255, 226, 160),
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, plaque)
	local close = new("ImageButton", {
		Name = "Close",
		Image = IMG.close,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -24, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
	}, card)
	new("UIScale", { Name = "Motion" }, close)
	local desktop = buildDesktop(card, style)
	local phone = buildPhone(card)
	_G.buildSelfCardTitles(card)
	if opts.phone then
		desktop.Visible = false
		phone.Visible = true
		plaque.Visible = false
	end
	card.Parent = hud
	return card
end

return "buildSelfCard installed"
