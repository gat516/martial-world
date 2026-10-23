--!nocheck
-- Edit-mode preview of StarterGui.Events (tools/events_ui_build.luau): fits the
-- canvas to a baseline like UiScale does, and fills the chosen layout's slots
-- with sample clones named __P* (delete them with mode "clear").
-- Set _G.EVENTS_PREVIEW = { layout = "Desktop" | "Phone", show = { "Herald", ... } | "clear" }
local StarterGui = game:GetService("StarterGui")
local opts = _G.EVENTS_PREVIEW or {}
local gui = StarterGui:FindFirstChild("Events")
local canvas = gui.Canvas
for _, d in gui:GetDescendants() do
	if d.Name:sub(1, 3) == "__P" then
		d:Destroy()
	end
end
if opts.show == "clear" then
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.UiScale.Scale = 1
	canvas.BackgroundTransparency = 1
	canvas.Desktop.Visible = true
	canvas.Phone.Visible = false
	return "cleared"
end
local layout = opts.layout or "Desktop"
local base = if layout == "Phone" then Vector2.new(844, 390) else Vector2.new(1920, 1080)
local view = gui.AbsoluteSize
local s = math.min(view.X / base.X, view.Y / base.Y)
canvas.UiScale.Scale = s
canvas.Size = if opts.letterbox then UDim2.fromOffset(base.X, base.Y) else UDim2.fromOffset(view.X / s, view.Y / s)
canvas.BackgroundTransparency = if opts.letterbox then 0.75 else 1
canvas.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
canvas.Desktop.Visible = layout == "Desktop"
canvas.Phone.Visible = layout == "Phone"
local root = canvas[layout]
local T = gui.Templates

local function put(template, slot, name)
	local c = T[template]:Clone()
	c.Name = "__P" .. (name or template)
	c.Parent = root[slot]
	return c
end

local made = {}
for _, what in opts.show or {} do
	if what == "Herald" then
		put("EventScroll", "Herald")
	elseif what == "Ribbon" then
		put("Ribbon", "Ribbon")
	elseif what == "Tracker" then
		local slot = root.Tracker
		if not slot:FindFirstChild("__PList") then
			local l = Instance.new("UIListLayout")
			l.Name = "__PList"
			l.FillDirection = Enum.FillDirection.Horizontal
			l.HorizontalAlignment = Enum.HorizontalAlignment.Center
			l.Padding = UDim.new(0, 28)
			l.Parent = slot
		end
		local a = put("TrackerEntry", "Tracker", "A")
		local b = put("TrackerEntry", "Tracker", "B")
		b.Name = "__PB"
		b.Ring.Time.Text = "4:05"
		b.Title.Text = "Beast Surge"
	elseif what == "Chips" then
		local r = put("ChipRight", "Chips")
		r.AnchorPoint = Vector2.new(1, 0.5)
		r.Position = UDim2.fromScale(1, 0.5)
		r.Size = UDim2.fromScale(4, 1)
		local l = put("ChipLeft", "Chips")
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.fromScale(0, 0.5)
		l.Size = UDim2.fromScale(4, 1)
	elseif what == "Decree" then
		put("Decree", "Decree")
	elseif what == "Counter" then
		put("StrikeCounter", "Counter")
	elseif what == "Rift" then
		local card = put("RiftCard", "Rift")
		for i, m in { "Frenzied beasts", "Herbs grow thick", "No healing pills" } do
			local tag = T.RiftTag:Clone()
			tag.Name = "__PTag" .. i
			tag.LayoutOrder = i
			tag.Art.Mid.Label.Text = m
			tag.Parent = card.Modifiers
		end
	elseif what == "Board" then
		local board = put("Board", "Board")
		for i, t in { "Realm", "Herbarium", "Tallest Peak", "Garden" } do
			local tab = board.Tabs.Tab:Clone()
			tab.Name = "__PTab" .. i
			tab.Visible = true
			tab.LayoutOrder = i
			tab.Text = t
			tab.TextColor3 = if i == 1 then Color3.fromRGB(236, 196, 104) else Color3.fromRGB(196, 182, 150)
			tab.Underline.Visible = i == 1
			tab.Parent = board.Tabs
		end
		local names = { "Wei Lan", "Bai Xue", "Old Man Qiu", "Lin Feng", "Su Mei", "Zhao Tian", "Han Yu" }
		local medals = { "rbxassetid://70786467802236", "rbxassetid://108098976852111", "rbxassetid://126855116006582" }
		local rowH = board.List.AbsoluteSize.Y / 6.6
		for i, n in names do
			local row = T.Row:Clone()
			row.Name = "__PRow" .. i
			row.LayoutOrder = i
			row.Size = UDim2.new(1, 0, 0, rowH / s)
			row.Cells.Player.Text = n
			row.Cells.Rank.Text = tostring(i)
			row.Cells.Medal.Visible = i <= 3
			if i <= 3 then
				row.Cells.Medal.Image = medals[i]
			end
			row.Cells.Value.Text = "QC " .. (10 - i)
			row.Parent = board.List
		end
		local you = T.RowYou:Clone()
		you.Name = "__PYou"
		you.Size = UDim2.fromScale(1, 1)
		you.Cells.Rank.Text = "42"
		you.Cells.Medal.Visible = false
		you.Cells.Value.Text = "QC 3"
		you.Parent = board.You
	end
end
return `{layout} scale {s} canvas {canvas.AbsoluteSize}`
