--!strict
-- The dialogue screen (StarterGui.Dialogue, docs/ui/dialogue.md): a speaker's
-- lines typed out in the panel, then a choice of responses.
--
--   local choice = Dialogue.open({
--       speaker = "Elder Qingyun",     -- nil or "" shows "???"
--       portrait = "elder_qingyun",    -- a PORTRAITS key or an rbxassetid; "unknown" adds the "?"
--       lines = { "Have you completed your root test?" },
--       responses = {                  -- optional, at most 4
--           { text = "I have completed it.", icon = "quest", highlight = true },
--           { text = "Can you tell me more?", icon = "talk" },
--           { text = "Nevermind.", icon = "leave", cancel = true },
--       },
--   })
--
-- open() yields until the conversation ends and returns the chosen response's
-- index, or nil (no responses, closed early, or replaced by another open()).
-- Responses may be plain strings (icon "talk"). `icon` is a Glyphs name;
-- `highlight` marks the recommended one (lit art, focused first); `cancel` is
-- what B on a gamepad picks; `disabled` dims it with a lock and it can't be picked.
--
-- Input: a click or tap on the panel, Space, Enter, E or gamepad A finishes the
-- typing, then moves to the next line. Once the responses show: click or tap one;
-- or move the focus (lit art) with Up/Down or the d-pad and pick with Enter, Space,
-- E or A; or press 1-4 (shown on keyboards only). The dialogue is a menu (Menus):
-- opening it closes any other window and hides the HUD and the world prompts, and
-- it holds the keys it uses while open (so Space doesn't jump). WASD, the left
-- stick and the touch thumbstick stay free: with `near`, walking more than `range`
-- studs from it ends the conversation (open() returns nil).
--
-- Layouts: a bar centred along the bottom of the screen (Menus hides the HUD while
-- it's open), the responses in a column to its right with the bar's top and bottom.
-- Canvas.Desktop (1920x1080 baseline) or Canvas.Phone (844x390, authored with
-- the column showing and the pair centred; while only lines show, the bar sits
-- centred, -ChoiceShift to the right, and slides back for the column), picked once
-- by UiScale.isPhone(); UiScale fits the canvas. A line too long for the text box
-- is split into pages at word breaks (each a click or tap).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Glyphs = require(script.Parent.Glyphs)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local Ribbon = require(script.Parent.Ribbon)
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UiScale = require(script.Parent.UiScale)

export type Response = string | {
	text: string,
	icon: string?,
	highlight: boolean?,
	cancel: boolean?,
	disabled: boolean?,
}

export type Options = {
	speaker: string?,
	portrait: string?,
	lines: { string },
	responses: { Response }?,
	speed: number?, -- characters per second (default CHARS_PER_SECOND)
	near: (PVInstance | Attachment)?, -- who's speaking: walking away from it closes the dialogue
	range: number?, -- studs from `near` (default WALK_AWAY_RANGE)
}

-- Gray silhouettes (art/ui/codex/cut/portrait_*.png; never painted busts).
local PORTRAITS: { [string]: string } = {
	elder_qingyun = "rbxassetid://87074548141272",
	herbalist = "rbxassetid://82972158000665",
	weapon_rack_keeper = "rbxassetid://81124939840651",
	unnamed = "rbxassetid://116403537977379",
	unknown = "rbxassetid://104901113924575",
}

local CHARS_PER_SECOND = 48
local MAX_RESPONSES = 4
local REVEAL_STAGGER = 0.04 -- seconds between response buttons fading in
local WALK_AWAY_RANGE = 14
local ACTION = "DialogueInput"
local CREAM = Color3.fromRGB(245, 236, 214)
local DIM = Color3.fromRGB(150, 146, 136)

local CONFIRM_KEYS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.KeypadEnter] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.ButtonA] = true,
}
local UP_KEYS = { [Enum.KeyCode.Up] = true, [Enum.KeyCode.DPadUp] = true }
local DOWN_KEYS = { [Enum.KeyCode.Down] = true, [Enum.KeyCode.DPadDown] = true }
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

type Choice = {
	text: string,
	icon: string,
	highlight: boolean,
	cancel: boolean,
	disabled: boolean,
	button: ImageButton?,
}

type Session = {
	lines: { string },
	index: number,
	typing: boolean,
	choices: { Choice },
	choosing: boolean, -- the responses are up
	focus: number?, -- the lit response
	waiter: thread?,
	speed: number,
	typeConn: RBXScriptConnection?,
	rangeConn: RBXScriptConnection?,
}

local Dialogue = {}

local layout: Frame
local panel: ImageButton
local tab: Frame
local speakerLabel: TextLabel
local portraitImage: ImageLabel? -- optional: a layout may drop the portrait
local mark: TextLabel?
local line: TextLabel
local chevron: ImageLabel
local list: Frame
local template: ImageButton
local tabTextSize = 24 -- the name's authored size (Merriweather Bold, 24 desktop / 19 phone)
local tabMaxWidth = 0 -- 60 % of the panel's width
local home: UDim2 -- the layout's authored position: where it sits with the responses up
local choiceShift = 0 -- ChoiceShift: home's offset from the centred bar (phone: the bar slides left by it)
local SLIDE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local session: Session? = nil

local function toChoice(r: Response): Choice
	if type(r) == "string" then
		return { text = r, icon = "talk", highlight = false, cancel = false, disabled = false }
	end
	return {
		text = r.text,
		icon = r.icon or "talk",
		highlight = r.highlight == true,
		cancel = r.cancel == true,
		disabled = r.disabled == true,
	}
end

local function showKeys(): boolean
	if Platform.isTouch() then
		return false
	end
	local last = UserInputService:GetLastInputType()
	return not string.find(last.Name, "Gamepad")
end

-- Fit the name tab (a ruby plaque, docs/ui/ribbons.md) to the name: the name sits on
-- the plaque's plain middle with even room to each stud; a long name grows the tab up
-- to the panel's width, then shrinks a little, then truncates.
local function fitTab(name: string)
	Ribbon.fit(tab, name, {
		style = "ruby",
		label = "Speaker",
		textSize = tabTextSize,
		maxWidth = tabMaxWidth,
		height = tab.Size.Y.Offset,
	})
end

local function setFocus(s: Session, index: number?)
	s.focus = index
	for i, c in s.choices do
		local b = c.button
		if b then
			local lit = i == index or (index == nil and c.highlight)
			local normal = b:FindFirstChild("Normal") :: Frame
			local hi = b:FindFirstChild("Hi") :: Frame
			normal.Visible = not lit
			hi.Visible = lit
		end
	end
end

local function finish(s: Session, result: number?)
	if session ~= s then
		return
	end
	session = nil
	if s.typeConn then
		s.typeConn:Disconnect()
	end
	if s.rangeConn then
		s.rangeConn:Disconnect()
	end
	ContextActionService:UnbindAction(ACTION)
	-- the buttons go once the window has shrunk away
	local buttons = {}
	for _, c in s.choices do
		if c.button then
			c.button.Active = false
			table.insert(buttons, c.button)
		end
	end
	task.delay(0.2, function()
		for _, b in buttons do
			b:Destroy()
		end
	end)
	Menus.close(layout)
	local waiter = s.waiter
	if waiter and coroutine.status(waiter) == "suspended" then
		task.spawn(waiter, result)
	end
end

local function pick(s: Session, index: number)
	local c = s.choices[index]
	if not c or c.disabled or not s.choosing then
		return
	end
	if c.button then
		Motion.tap(c.button)
	end
	finish(s, index)
end

-- Keep a response's text on its plate: room for the number key when it shows,
-- then the authored size, shrunk to the label's MinTextSize attribute if the text
-- is too wide, then truncated (TextTruncate) past that.
local function fitLabel(button: ImageButton, label: TextLabel, keyRoom: number)
	local size = label.Size
	label.Size = UDim2.new(size.X.Scale, size.X.Offset - keyRoom, size.Y.Scale, size.Y.Offset)
	local max = label.TextSize
	local min = label:GetAttribute("MinTextSize") :: number? or max
	local width = button.Size.X.Offset
	if width <= 0 then
		-- a row of a list: as wide as the list
		width = (button.Parent :: Frame).Size.X.Offset
	end
	width += label.Size.X.Offset
	local params = Instance.new("GetTextBoundsParams")
	params.Text = label.Text
	params.Font = label.FontFace
	params.Width = math.huge
	for textSize = max, min, -1 do
		label.TextSize = textSize
		params.Size = textSize
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if not ok or bounds.X <= width then
			break
		end
	end
end

local function showResponses(s: Session)
	s.choosing = true
	chevron.Visible = false
	list.Visible = true
	if choiceShift ~= 0 then
		-- the phone bar is centred alone; it slides left so the pair is centred
		TweenService:Create(layout, SLIDE, { Position = home }):Play()
	end
	local keys = showKeys()
	for i, c in s.choices do
		local b = template:Clone()
		b.Name = "Response" .. i
		b.LayoutOrder = i
		local label = b:FindFirstChild("Label") :: TextLabel
		label.Text = c.text
		local icon = b:FindFirstChild("Icon") :: ImageLabel
		icon.Image = Glyphs.get(if c.disabled then "lock" else c.icon) or Glyphs.get("talk") :: string
		local key = b:FindFirstChild("Key") :: TextLabel
		key.Text = tostring(i)
		key.Visible = keys and not c.disabled
		if c.disabled then
			label.TextColor3 = DIM
			icon.ImageColor3 = DIM
			for _, part in (b:FindFirstChild("Normal") :: Frame):GetChildren() do
				local art = part :: ImageLabel
				art.ImageTransparency = 0.35
			end
		else
			label.TextColor3 = CREAM
		end
		b.Activated:Connect(function()
			pick(s, i)
		end)
		b.MouseEnter:Connect(function()
			if s.choosing and not c.disabled and not Platform.isTouch() then
				setFocus(s, i)
			end
		end)
		b.Visible = true
		b.Parent = list
		-- after parenting (a row takes the list's width); measuring yields, and this
		-- can run inside an input callback
		task.spawn(fitLabel, b, label, if key.Visible then key.Size.X.Offset + 4 else 0)
		c.button = b
		task.delay((i - 1) * REVEAL_STAGGER, function()
			if b.Parent then
				Motion.fadeIn(b)
			end
		end)
	end
	-- keyboard and gamepad start on the recommended (or first) response; touch
	-- only lights the recommended one
	local first: number? = nil
	for i, c in s.choices do
		if not c.disabled and (c.highlight or first == nil) then
			if c.highlight then
				first = i
				break
			end
			first = first or i
		end
	end
	setFocus(s, if Platform.isTouch() then nil else first)
end

local function moveFocus(s: Session, step: number)
	local n = #s.choices
	local at = s.focus or (if step > 0 then 0 else n + 1)
	for _ = 1, n do
		at += step
		if at < 1 then
			at = n
		elseif at > n then
			at = 1
		end
		if not s.choices[at].disabled then
			setFocus(s, at)
			return
		end
	end
end

local function showLine(s: Session)
	local text = s.lines[s.index] or ""
	line.Text = text
	chevron.Visible = false
	local total = utf8.len(text) or #text
	s.typing = true
	line.MaxVisibleGraphemes = 0
	local shown = 0
	if s.typeConn then
		s.typeConn:Disconnect()
	end
	s.typeConn = RunService.Heartbeat:Connect(function(dt)
		shown += dt * s.speed
		if shown >= total then
			line.MaxVisibleGraphemes = -1
			s.typing = false
			if s.typeConn then
				s.typeConn:Disconnect()
				s.typeConn = nil
			end
			if s.index >= #s.lines and #s.choices > 0 then
				showResponses(s)
			else
				chevron.Visible = true
			end
		else
			line.MaxVisibleGraphemes = math.floor(shown)
		end
	end)
end

-- Skip the typing, or go on to the next line, or end a dialogue without responses.
local function advance(s: Session)
	if s.choosing then
		return
	end
	if s.typing then
		line.MaxVisibleGraphemes = -1
		s.typing = false
		if s.typeConn then
			s.typeConn:Disconnect()
			s.typeConn = nil
		end
		if s.index >= #s.lines and #s.choices > 0 then
			showResponses(s)
		else
			chevron.Visible = true
		end
		return
	end
	if s.index < #s.lines then
		s.index += 1
		showLine(s)
	else
		finish(s, nil)
	end
end

local function onInput(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	local s = session
	if not s or state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local code = input.KeyCode
	if s.choosing then
		if CONFIRM_KEYS[code] then
			if s.focus then
				pick(s, s.focus)
			end
		elseif UP_KEYS[code] then
			moveFocus(s, -1)
		elseif DOWN_KEYS[code] then
			moveFocus(s, 1)
		elseif code == Enum.KeyCode.ButtonB then
			for i, c in s.choices do
				if c.cancel then
					pick(s, i)
					break
				end
			end
		else
			local n = table.find(NUMBER_KEYS, code)
			if n then
				pick(s, n)
			end
		end
	elseif CONFIRM_KEYS[code] then
		advance(s)
	end
	return Enum.ContextActionResult.Sink
end

-- Split lines that don't fit the text box into pages at word breaks. Line has a
-- fixed authored height, so its width in layout units is its on-screen width over
-- the on-screen scale (any nested UIScale cancels out).
local function paginate(source: { string }): { string }
	local abs = line.AbsoluteSize
	local width = if abs.Y > 0 then abs.X * line.Size.Y.Offset / abs.Y else 0
	if width <= 0 then
		return source
	end
	local rows = math.max(1, math.floor(line.Size.Y.Offset / (line.TextSize * line.LineHeight) + 0.05))
	local params = Instance.new("GetTextBoundsParams")
	params.Font = line.FontFace
	params.Size = line.TextSize
	params.Width = width
	local function fits(text: string): boolean
		params.Text = text
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		return not ok or math.round(bounds.Y / line.TextSize) <= rows
	end
	local pages = {}
	for _, text in source do
		if fits(text) then
			table.insert(pages, text)
			continue
		end
		local page = ""
		for word in string.gmatch(text, "%S+") do
			local candidate = if page == "" then word else page .. " " .. word
			if page ~= "" and not fits(candidate) then
				table.insert(pages, page)
				page = word
			else
				page = candidate
			end
		end
		if page ~= "" then
			table.insert(pages, page)
		end
	end
	return pages
end

-- Show a conversation and wait for its end (see the header). Returns the
-- chosen response's index, or nil.
function Dialogue.open(options: Options): number?
	local old = session
	if old then
		finish(old, nil)
	end
	local choices = {}
	for i, r in options.responses or {} do
		if i > MAX_RESPONSES then
			warn(`Dialogue: only {MAX_RESPONSES} responses fit; dropped "{toChoice(r).text}"`)
			break
		end
		table.insert(choices, toChoice(r))
	end
	local lines = paginate(if #options.lines > 0 then options.lines else { "" })
	local s: Session = {
		lines = lines,
		index = 1,
		typing = false,
		choices = choices,
		choosing = false,
		focus = nil,
		waiter = nil,
		speed = options.speed or CHARS_PER_SECOND,
		typeConn = nil,
		rangeConn = nil,
	}
	session = s

	local speaker = options.speaker
	local unknown = speaker == nil or speaker == "" or options.portrait == "unknown"
	fitTab(if speaker == nil or speaker == "" then "???" else speaker)
	local key = options.portrait or (if unknown then "unknown" else "unnamed")
	if portraitImage then
		portraitImage.Image = PORTRAITS[key] or key
	end
	if mark then
		mark.Visible = key == "unknown"
	end

	list.Visible = false
	layout.Position = home - UDim2.fromOffset(choiceShift, 0)
	ContextActionService:BindActionAtPriority(
		ACTION,
		onInput,
		false,
		Enum.ContextActionPriority.High.Value + 10,
		Enum.KeyCode.Space,
		Enum.KeyCode.Return,
		Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.E,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadDown
	)
	local near = options.near
	if near then
		local range = options.range or WALK_AWAY_RANGE
		s.rangeConn = RunService.Heartbeat:Connect(function()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not near.Parent then
				finish(s, nil)
			elseif root then
				local at = if near:IsA("Attachment") then near.WorldPosition else near:GetPivot().Position
				if (root.Position - at).Magnitude > range then
					finish(s, nil)
				end
			end
		end)
	end
	Menus.open(layout)
	showLine(s)

	s.waiter = coroutine.running()
	return coroutine.yield()
end

-- End the conversation now (open() returns nil).
function Dialogue.close()
	local s = session
	if s then
		finish(s, nil)
	end
end

function Dialogue.isOpen(): boolean
	return session ~= nil
end

-- Sample conversations for a look in play (client console:
-- require(game.Players.LocalPlayer.PlayerScripts.Client.Dialogue).preview()).
-- Never called by the game.
function Dialogue.preview()
	task.spawn(function()
		local choice = Dialogue.open({
			speaker = "Elder Qingyun",
			portrait = "elder_qingyun",
			lines = {
				"You have the look of someone who has hit a wall.",
				"Have you completed your root test?",
			},
			responses = {
				{ text = "I have completed it.", icon = "quest", highlight = true },
				{ text = "Can you tell me more?", icon = "talk" },
				{ text = "I have a question.", icon = "question" },
				{ text = "Nevermind.", icon = "leave", cancel = true },
			},
		})
		print("Dialogue.preview: chose", choice)
		Dialogue.open({ portrait = "unknown", lines = { "............" } })
	end)
end

function Dialogue.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("Dialogue") :: ScreenGui
	if not gui.Enabled then
		-- a disabled copy in the place (a review leftover) would open unseen while
		-- Menus hid the HUD: everything gone and no dialogue
		warn(`Dialogue: {gui:GetFullName()} was disabled; enabling it (check StarterGui for a stale copy)`)
		gui.Enabled = true
	end
	local copies = 0
	for _, child in playerGui:GetChildren() do
		if child.Name == "Dialogue" then
			copies += 1
		end
	end
	if copies > 1 then
		warn(`Dialogue: {copies} Dialogue ScreenGuis in PlayerGui; StarterGui has a stale copy beside Rojo's`)
	end
	local canvas = gui:WaitForChild("Canvas") :: Frame
	UiScale.fit(canvas)
	local phone = UiScale.isPhone()
	local desktopLayout = canvas:WaitForChild("Desktop") :: Frame
	local phoneLayout = canvas:WaitForChild("Phone") :: Frame
	layout = if phone then phoneLayout else desktopLayout
	local unused = if phone then desktopLayout else phoneLayout
	unused:Destroy()
	layout.Visible = false

	panel = layout:FindFirstChild("Panel") :: ImageButton
	tab = layout:FindFirstChild("NameTab") :: Frame
	speakerLabel = tab:FindFirstChild("Speaker") :: TextLabel
	local backdrop = panel:FindFirstChild("Backdrop", true)
	portraitImage = backdrop and backdrop:FindFirstChild("Image") :: ImageLabel?
	mark = backdrop and backdrop:FindFirstChild("Mark") :: TextLabel?
	local box = panel:FindFirstChild("TextBox") :: Frame
	line = box:FindFirstChild("Line") :: TextLabel
	chevron = box:FindFirstChild("Chevron") :: ImageLabel
	list = layout:FindFirstChild("Responses") :: Frame
	template = list:FindFirstChild("Response") :: ImageButton
	template.Visible = false
	tabTextSize = speakerLabel.TextSize
	home = layout.Position
	choiceShift = (layout:GetAttribute("ChoiceShift") :: number?) or 0
	tabMaxWidth = panel.Size.X.Offset * 0.6

	Motion.bob(chevron, 4)
	Motion.buttons(list)
	panel.Activated:Connect(function()
		local s = session
		if s then
			advance(s)
		end
	end)
	Menus.register(layout, { close = function()
		Motion.close(layout)
		local s = session
		if s then
			finish(s, nil)
		end
	end })
end

return Dialogue
