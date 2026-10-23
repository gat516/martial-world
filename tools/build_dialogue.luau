-- Builds StarterGui.Dialogue (the dialogue screen template, docs/ui/dialogue.md)
-- from the uploaded cut art. Run with the Studio MCP's execute_luau in a sandbox
-- (no Rojo there), preview, then export StarterGui.Dialogue to assets/Dialogue.rbxmx.
-- Re-running replaces the old copy. Layouts are in baseline pixels: Desktop at
-- 1920x1080, Phone at 844x390 (UiScale fits the Canvas at runtime).
-- Stale since 2026-10-23: assets/Dialogue.rbxmx has the frame corners as margined
-- display-sized copies with grown elements (tools/ui_margin.py) and moved response
-- labels and keys (ui_lint text-cap), and the bottom-bar layout (docs/ui/dialogue.md,
-- "Layout": bar sizes, the name tab's cloud Flourish, responses above the bar) was set
-- on the template by hand. Don't rerun it over the export; port those first.

local IDS = {
	chevron = "rbxassetid://105373918142379",
	fx_glow = "rbxassetid://117370482889201",
	glyph_talk = "rbxassetid://110522667354738",
	inkwash_b = "rbxassetid://89713614645342",
	tab_capL = "rbxassetid://106944267283704",
	tab_capR = "rbxassetid://140388191762822",
	tab_mid = "rbxassetid://115833543136061",
	resp_capL = "rbxassetid://136592388357881",
	resp_mid = "rbxassetid://131645449010810",
	resp_capR = "rbxassetid://75114607597440",
	resp_hi_capL = "rbxassetid://133777338178578",
	resp_hi_mid = "rbxassetid://79276246412779",
	resp_hi_capR = "rbxassetid://103853460559963",
	portrait = "rbxassetid://87074548141272", -- Elder Qingyun, the template's sample
	pcorner_tl = "rbxassetid://76644657652089",
	pcorner_tr = "rbxassetid://96043709103203",
	pcorner_bl = "rbxassetid://105309554555537",
	pcorner_br = "rbxassetid://82898632014624",
	pcorner_rail_top = "rbxassetid://111090585342729",
	pcorner_rail_bottom = "rbxassetid://81727626482641",
	pcorner_rail_left = "rbxassetid://71050343838227",
	pcorner_rail_right = "rbxassetid://87159641406799",
	window_tl = "rbxassetid://70897818016181",
	window_tr = "rbxassetid://114050819321245",
	window_bl = "rbxassetid://98285226898898",
	window_br = "rbxassetid://134032133131620",
	window_rail_top = "rbxassetid://124084030586822",
	window_rail_bottom = "rbxassetid://115494920971606",
	window_rail_left = "rbxassetid://119880016920049",
	window_rail_right = "rbxassetid://107546488399706",
}

-- source sizes of the cut art (px)
local WINDOW = Vector2.new(1011, 529)
local WINDOW_RAIL = 110
local PCORNER = Vector2.new(238, 158)
local PCORNER_RAIL = 40
local TAB_CAP = Vector2.new(233, 125)
local RESP_CAPL = Vector2.new(377, 221)
local RESP_CAPR = Vector2.new(305, 221)
local CHEVRON = Vector2.new(210, 129)
-- measured in the response art: the plate's visible middle (rows 40-204 of 221)
-- and the icon ring's hole (x 55-180 of the 377 px left cap, rows 58-183)
local PLATE_Y = 0.552
local RING_X = 0.312
local RING_Y = 0.545

local CREAM = Color3.fromRGB(245, 236, 214)
local GOLD_TEXT = Color3.fromRGB(240, 214, 150)
local INK = Color3.fromRGB(10, 10, 10)
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local MERRI = "rbxasset://fonts/families/Merriweather.json"

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
	if props.ScaleType == nil then
		props.ScaleType = Enum.ScaleType.Stretch
	end
	return new("ImageLabel", props, parent)
end

local function text(name: string, props: { [string]: any }, parent: Instance): TextLabel
	props.Name = name
	props.BackgroundTransparency = 1
	if props.TextStrokeTransparency == nil then
		props.TextStrokeTransparency = 0
	end
	props.TextStrokeColor3 = props.TextStrokeColor3 or INK
	return new("TextLabel", props, parent)
end

-- Four mirrored corners and the four rail strips between them, filling `parent`.
-- `k` scales the source art; works at any parent size (rails stretch along).
local function frameArt(parent: Instance, prefix: string, source: Vector2, rail: number, k: number, z: number)
	local cw, ch, d = source.X * k, source.Y * k, rail * k
	local art = new("Frame", { Name = "Frame", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z }, parent)
	local corners = {
		{ "TL", Vector2.new(0, 0) },
		{ "TR", Vector2.new(1, 0) },
		{ "BL", Vector2.new(0, 1) },
		{ "BR", Vector2.new(1, 1) },
	}
	for _, c in corners do
		image(c[1], IDS[prefix .. "_" .. string.lower(c[1])], {
			AnchorPoint = c[2],
			Position = UDim2.fromScale(c[2].X, c[2].Y),
			Size = UDim2.fromOffset(cw, ch),
			ZIndex = z,
		}, art)
	end
	image("Top", IDS[prefix .. "_rail_top"], { Position = UDim2.new(0, cw, 0, 0), Size = UDim2.new(1, -2 * cw, 0, d), ZIndex = z }, art)
	image("Bottom", IDS[prefix .. "_rail_bottom"], {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, cw, 1, 0),
		Size = UDim2.new(1, -2 * cw, 0, d),
		ZIndex = z,
	}, art)
	image("Left", IDS[prefix .. "_rail_left"], { Position = UDim2.new(0, 0, 0, ch), Size = UDim2.new(0, d, 1, -2 * ch), ZIndex = z }, art)
	image("Right", IDS[prefix .. "_rail_right"], {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, ch),
		Size = UDim2.new(0, d, 1, -2 * ch),
		ZIndex = z,
	}, art)
	return art
end

type Spec = {
	name: string,
	size: Vector2, -- the whole block
	panel: Vector2, -- panel size
	panelY: number, -- panel top (room for the name tab above)
	k: number, -- window corner scale
	pk: number, -- portrait/text-box corner scale
	pad: number, -- portrait inset from the panel edge
	portrait: number, -- portrait frame side
	gap: number, -- portrait to text box
	tabX: number,
	tabH: number,
	tabW: number, -- authored for the sample name; the script fits it
	nameSize: number,
	lineSize: number,
	linePad: Vector2,
	respPos: Vector2,
	respSize: Vector2,
	respH: number,
	respText: number,
	grid: boolean, -- phone: two-column grid
	cell: Vector2?,
}

local function buildLayout(canvas: Instance, s: Spec)
	local root = new("Frame", {
		Name = s.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(s.size.X, s.size.Y),
		BackgroundTransparency = 1,
		Visible = false,
	}, canvas)
	new("UIScale", { Name = "Motion" }, root)

	-- the panel
	local panel = new("ImageButton", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, s.panelY),
		Size = UDim2.fromOffset(s.panel.X, s.panel.Y),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Image = "",
	}, root)
	local inset = math.round(5 * s.k / 0.17)
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, panel)
	new("UIGradient", {
		Rotation = 35,
		Color = ColorSequence.new(Color3.fromRGB(30, 42, 60), Color3.fromRGB(14, 19, 28)),
	}, body)
	frameArt(panel, "window", WINDOW, WINDOW_RAIL, s.k, 6)

	-- portrait
	local p = s.portrait
	local portrait = new("Frame", {
		Name = "Portrait",
		Position = UDim2.fromOffset(s.pad, (s.panel.Y - p) / 2),
		Size = UDim2.fromOffset(p, p),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, panel)
	local pd = math.round(PCORNER_RAIL * s.pk * 0.45)
	local backdrop = new("Frame", {
		Name = "Backdrop",
		Position = UDim2.fromOffset(pd, pd),
		Size = UDim2.new(1, -2 * pd, 1, -2 * pd),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, portrait)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(44, 56, 84), Color3.fromRGB(16, 21, 34)),
	}, backdrop)
	image("Glow", IDS.fx_glow, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1.15, 1.15),
		ImageColor3 = Color3.fromRGB(130, 150, 200),
		ImageTransparency = 0.72,
		ZIndex = 2,
	}, backdrop)
	image("Image", IDS.portrait, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, backdrop)
	text("Mark", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.36),
		Text = "?",
		TextScaled = true,
		TextColor3 = CREAM,
		TextStrokeTransparency = 0.4,
		FontFace = Font.new(MERRI, Enum.FontWeight.Bold),
		Visible = false,
		ZIndex = 4,
	}, backdrop)
	frameArt(portrait, "pcorner", PCORNER, PCORNER_RAIL, s.pk, 5)
	-- text box
	local tx = s.pad + p + s.gap
	local box = new("Frame", {
		Name = "TextBox",
		Position = UDim2.fromOffset(tx, (s.panel.Y - p) / 2),
		Size = UDim2.fromOffset(s.panel.X - tx - s.pad, p),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, panel)
	new("Frame", {
		Name = "Back",
		Position = UDim2.fromOffset(pd, pd),
		Size = UDim2.new(1, -2 * pd, 1, -2 * pd),
		BackgroundColor3 = Color3.fromRGB(10, 14, 22),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, box)
	for i, side in { 0, 1 } do
		image(if i == 1 then "InkL" else "InkR", IDS.inkwash_b, {
			AnchorPoint = Vector2.new(side, 1),
			Position = UDim2.new(side, if side == 0 then pd else -pd, 1, -pd),
			Size = UDim2.new(0.55, 0, 0.55 * (s.panel.X - tx - s.pad) * 129 / 1024 / p, 0),
			ImageTransparency = 0.88,
			ZIndex = 3,
		}, box)
	end
	frameArt(box, "pcorner", PCORNER, PCORNER_RAIL, s.pk, 5)
	text("Line", {
		Position = UDim2.fromOffset(s.linePad.X, s.linePad.Y),
		Size = UDim2.new(1, -2 * s.linePad.X, 1, -2 * s.linePad.Y),
		Text = "Have you completed your root test?",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = s.lineSize,
		LineHeight = 1.12,
		TextColor3 = CREAM,
		FontFace = Font.new(BUILDER, Enum.FontWeight.SemiBold),
		ZIndex = 6,
	}, box)
	local chevW = math.round(s.lineSize * 1.15)
	image("Chevron", IDS.chevron, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -s.linePad.X + 4, 1, -s.linePad.Y + 6),
		Size = UDim2.fromOffset(chevW, math.round(chevW * CHEVRON.Y / CHEVRON.X)),
		ZIndex = 6,
	}, box)

	-- name tab (on the panel's top rail, left)
	local th = s.tabH
	local tcw = math.round(TAB_CAP.X * th / TAB_CAP.Y)
	local tab = new("Frame", {
		Name = "NameTab",
		Position = UDim2.fromOffset(s.tabX, 0),
		Size = UDim2.fromOffset(s.tabW, th),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, root)
	image("CapL", IDS.tab_capL, { Size = UDim2.new(0, tcw, 1, 0), ZIndex = 8 }, tab)
	image("Mid", IDS.tab_mid, { Position = UDim2.new(0, tcw, 0, 0), Size = UDim2.new(1, -2 * tcw, 1, 0), ZIndex = 8 }, tab)
	image("CapR", IDS.tab_capR, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, tcw, 1, 0), ZIndex = 8 }, tab)
	text("Speaker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.584),
		Size = UDim2.new(1, -math.round(1.2 * tcw), 0.62, 0),
		Text = "Elder Qingyun",
		TextSize = s.nameSize,
		TextColor3 = GOLD_TEXT,
		TextStrokeTransparency = 0.2,
		FontFace = Font.new(MERRI, Enum.FontWeight.Bold),
		ZIndex = 9,
	}, tab)

	-- responses
	local list = new("Frame", {
		Name = "Responses",
		Position = UDim2.fromOffset(s.respPos.X, s.respPos.Y),
		Size = UDim2.fromOffset(s.respSize.X, s.respSize.Y),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	if s.grid then
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset((s.cell :: Vector2).X, (s.cell :: Vector2).Y),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, list)
	else
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, list)
	end
	local h = s.respH
	local lw = math.round(RESP_CAPL.X * h / RESP_CAPL.Y)
	local rw = math.round(RESP_CAPR.X * h / RESP_CAPR.Y)
	local button = new("ImageButton", {
		Name = "Response",
		Size = UDim2.new(1, 0, 0, h),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = false,
		Image = "",
		Visible = false,
	}, list)
	new("UIScale", { Name = "Motion" }, button)
	for _, set in { { "Normal", "resp_" }, { "Hi", "resp_hi_" } } do
		local f = new("Frame", { Name = set[1], BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = set[1] == "Normal" }, button)
		image("CapL", IDS[set[2] .. "capL"], { Size = UDim2.new(0, lw, 1, 0) }, f)
		image("Mid", IDS[set[2] .. "mid"], { Position = UDim2.new(0, lw, 0, 0), Size = UDim2.new(1, -lw - rw, 1, 0) }, f)
		image("CapR", IDS[set[2] .. "capR"], { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, rw, 1, 0) }, f)
	end
	local icon = math.round(h * 0.36)
	image("Icon", IDS.glyph_talk, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, math.round(lw * RING_X), RING_Y, 0),
		Size = UDim2.fromOffset(icon, icon),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = CREAM,
		ZIndex = 2,
	}, button)
	local tl = math.round(lw * 0.68)
	text("Label", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, tl, PLATE_Y, 0),
		Size = UDim2.new(1, -tl - math.round(rw * 0.42), 0.7, 0),
		Text = "I have completed it.",
		TextSize = s.respText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = CREAM,
		FontFace = Font.new(BUILDER, Enum.FontWeight.Bold),
		ZIndex = 2,
	}, button)
	text("Key", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -math.round(rw * 0.62), PLATE_Y, 0),
		Size = UDim2.fromOffset(math.round(h * 0.4), math.round(h * 0.4)),
		Text = "1",
		TextSize = math.round(s.respText * 0.8),
		TextColor3 = GOLD_TEXT,
		TextTransparency = 0.2,
		FontFace = Font.new(BUILDER, Enum.FontWeight.Bold),
		Visible = false,
		ZIndex = 2,
	}, button)
	return root
end

local StarterGui = game:GetService("StarterGui")
local old = StarterGui:FindFirstChild("Dialogue")
if old then
	old:Destroy()
end
local gui = new("ScreenGui", {
	Name = "Dialogue",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 7,
})
local canvas = new("Frame", {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, gui)
new("UIScale", { Name = "UiScale" }, canvas)

buildLayout(canvas, {
	name = "Desktop",
	size = Vector2.new(1480, 292),
	panel = Vector2.new(1000, 250),
	panelY = 42,
	k = 0.17,
	pk = 0.28,
	pad = 22,
	portrait = 206,
	gap = 14,
	tabX = 30,
	tabH = 58,
	tabW = 320,
	nameSize = 24,
	lineSize = 24,
	linePad = Vector2.new(30, 26),
	respPos = Vector2.new(1020, 42),
	respSize = Vector2.new(460, 250),
	respH = 56,
	respText = 20,
	grid = false,
})
buildLayout(canvas, {
	name = "Phone",
	size = Vector2.new(600, 346),
	panelY = 34,
	panel = Vector2.new(600, 200),
	k = 0.13,
	pk = 0.22,
	pad = 18,
	portrait = 164,
	gap = 10,
	tabX = 22,
	tabH = 46,
	tabW = 260,
	nameSize = 19,
	lineSize = 18,
	linePad = Vector2.new(20, 18),
	respPos = Vector2.new(0, 242),
	respSize = Vector2.new(600, 104),
	respH = 48,
	respText = 17,
	grid = true,
	cell = Vector2.new(296, 48),
})
gui.Parent = StarterGui
return "built"
