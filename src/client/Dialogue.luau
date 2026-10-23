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
-- or move the focus (lit art) with Up/Down, W/S, the d-pad or left stick and pick
-- with Enter, Space, E or A; or press 1-4 (shown on keyboards only). The dialogue
-- is a menu (Menus): opening it closes any other window and hides the HUD and the
-- world prompts, and it holds the keys it uses while open (so Space doesn't jump).
--
-- Layouts: a bar along the bottom of the screen. Canvas.Desktop (1920x1080
-- baseline, responses in a column above the bar's right end) or Canvas.Phone
-- (844x390, a shorter bar, responses in a 2x2 grid above the name tab, right-
-- aligned), picked once by UiScale.isPhone(); UiScale fits the canvas.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Glyphs = require(script.Parent.Glyphs)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)
local Ribbon = require(script.Parent.Ribbon)
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
local STICK_DEADZONE = 0.6
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
local UP_KEYS = { [Enum.KeyCode.Up] = true, [Enum.KeyCode.W] = true, [Enum.KeyCode.DPadUp] = true }
local DOWN_KEYS = { [Enum.KeyCode.Down] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.DPadDown] = true }
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
}

local Dialogue = {}

local layout: Frame
local panel: ImageButton
local tab: Frame
local speakerLabel: TextLabel
local portraitImage: ImageLabel
local mark: TextLabel
local line: TextLabel
local chevron: ImageLabel
local list: Frame
local template: ImageButton
local tabTextSize = 24 -- the name's authored size (Merriweather Bold, 24 desktop / 19 phone)
local tabMaxWidth = 0 -- 60 % of the panel's width

local session: Session? = nil
local stickHeld = false

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
	ContextActionService:UnbindAction(ACTION)
	ContextActionService:UnbindAction(ACTION .. "Stick")
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

local function showResponses(s: Session)
	s.choosing = true
	chevron.Visible = false
	list.Visible = true
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

local function onStick(_: string, _state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	local s = session
	if not s or not s.choosing then
		return Enum.ContextActionResult.Pass
	end
	local y = input.Position.Y
	if math.abs(y) < STICK_DEADZONE then
		stickHeld = false
	elseif not stickHeld then
		stickHeld = true
		moveFocus(s, if y > 0 then -1 else 1)
	end
	return Enum.ContextActionResult.Sink
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
	local lines = if #options.lines > 0 then options.lines else { "" }
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
	}
	session = s

	local speaker = options.speaker
	local unknown = speaker == nil or speaker == "" or options.portrait == "unknown"
	fitTab(if speaker == nil or speaker == "" then "???" else speaker)
	local key = options.portrait or (if unknown then "unknown" else "unnamed")
	portraitImage.Image = PORTRAITS[key] or key
	mark.Visible = key == "unknown"

	list.Visible = false
	stickHeld = false
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
		Enum.KeyCode.W,
		Enum.KeyCode.S,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadDown
	)
	ContextActionService:BindActionAtPriority(ACTION .. "Stick", onStick, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Thumbstick1)
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
	local portrait = panel:FindFirstChild("Portrait") :: Frame
	local backdrop = portrait:FindFirstChild("Backdrop") :: Frame
	portraitImage = backdrop:FindFirstChild("Image") :: ImageLabel
	mark = backdrop:FindFirstChild("Mark") :: TextLabel
	local box = panel:FindFirstChild("TextBox") :: Frame
	line = box:FindFirstChild("Line") :: TextLabel
	chevron = box:FindFirstChild("Chevron") :: ImageLabel
	list = layout:FindFirstChild("Responses") :: Frame
	template = list:FindFirstChild("Response") :: ImageButton
	template.Visible = false
	tabTextSize = speakerLabel.TextSize
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
