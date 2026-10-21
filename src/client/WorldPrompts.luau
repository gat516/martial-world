--!strict
-- Our look for every ProximityPrompt in the world (all of them use Style Custom,
-- so Roblox draws nothing). With a mouse, keyboard or gamepad, prompts are drawn
-- in the world, on the thing they belong to: one billboard (StarterGui.Prompts.Board,
-- cloned per target) holds that target's cards in a short list.
-- On touch the cards go to a fixed spot in thumb reach instead (Prompts.Dock): a
-- column just above the right end of the vitals and hotbar, left of the Lock and
-- Dash buttons, growing upward. A card on a plant or bed ended up wherever the
-- camera put it, under the hotbar or the thumbstick, so players tilted the camera
-- to tap it. Dock mirrors Hud.Stack's box (same position, size and constraints),
-- so the column always sits just over the stack; keep the two in step. The card's
-- object line ("Huge Dewy Spirit Grass", "Herb Bed") says what it acts on, and the
-- PlantTag still marks the plant in the world.
--
-- Only one target is in focus at a time: the nearest one with an enabled prompt
-- in range (with a little stickiness so walking between two plants doesn't
-- flicker). Its prompts are the only ones drawn, plus its companion (a plant
-- brings its bed's Plant, see companionOf), so a garden full of plants shows one
-- plant's card (Harvest or Grow now) with the bed's Plant under it.
-- Roblox's one-prompt-per-key rule doesn't apply on touch, which is why we pick.
-- Every other Custom prompt has its keys muted locally (KeyboardKeyCode and
-- GamepadKeyCode set to Unknown, restored when it gains focus), so F or G can
-- only ever fire the prompt whose card is on screen. Nothing else in the game
-- sets those keys, and Enabled is left alone: the server and GardenView own it.
--
-- The billboard (non-touch) sits just under the PlantTag card above a plant (same anchor:
-- top of the part plus a stud, then the 55px the tag hangs below that), sized in
-- pixels so it reads and taps the same at any distance. Each card shows the key
-- cap (keyboard key, or the gamepad button), the object and action text (kept
-- live: prices and "No seeds" change while shown), and a hold bar for prompts
-- with a HoldDuration. On touch there's no key cap: the whole card is the button.
-- A mouse can click a card too (ClickablePrompt), but only while the cursor is
-- free: under shift lock or lock-on the mouse sits at the screen's centre, which
-- is usually right on the board of whatever you face, and the card would sink
-- every click (no swing, the prompt held instead) and the right-drag that turns
-- the camera. So the board takes no input while the mouse is held (mouseFree).
-- A card that leaves is lifted out of the list while it fades, so it never pushes
-- the others around.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local HOLD_RESET = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_TIME = 0.15 -- Motion.fadeOut's length: when a left card can go
local FOCUS_EVERY = 0.1 -- seconds between focus checks
local STICKY = 1 -- studs: another target must be this much nearer to take focus
local HIDE_GRACE = 0.08 -- seconds a hidden prompt's card waits in case it shows again

-- Keys whose GetStringForKeyCode is empty or unhelpful.
local KEY_NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Space] = "Space",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.Tab] = "Tab",
	[Enum.KeyCode.Backspace] = "Bksp",
}

type Board = {
	gui: BillboardGui?, -- the world billboard; nil for the touch dock (kept, not per target)
	holder: GuiObject, -- where a leaving card is lifted to while it fades (the list's parent)
	list: Frame,
	target: Instance,
	cards: { [ProximityPrompt]: () -> () }, -- each drawn prompt, by how to take its card away
	releases: { [ProximityPrompt]: () -> () }, -- each card's end-a-held-click
}

local WorldPrompts = {}

-- Set by GardenView: a prompt drawn alongside the focused target's own. Growing
-- plants are nearer than their bed's anchor, so without this a bed with plants in
-- it could never be planted again.
WorldPrompts.companionOf = nil :: ((target: Instance) -> ProximityPrompt?)?

local player = Players.LocalPlayer
local playerGui: PlayerGui
local boardTemplate: BillboardGui
local cardTemplate: ImageButton
local dock: Frame -- touch: the fixed card column (Prompts.Dock)
local actionBelow: UDim2 -- where the action line sits under the object line (authored)

local prompts: { [ProximityPrompt]: boolean } = {} -- every prompt in the world
local muted: { [ProximityPrompt]: { keyboard: Enum.KeyCode, gamepad: Enum.KeyCode } } = {}
local live: { [ProximityPrompt]: Enum.ProximityPromptInputType } = {} -- shown by ProximityPromptService
local focus: Instance? = nil -- the target whose prompts are drawn
local companion: ProximityPrompt? = nil -- drawn with focus's own (companionOf)
local board: Board? = nil
local mouseFree = true -- PC: the cursor isn't held at the centre (boards take clicks only then)
local shown = 0 -- counts cards, to keep same-key cards in the order they appeared

local function keyText(code: Enum.KeyCode): string
	local named = KEY_NAMES[code]
	if named then
		return named
	end
	local s = UserInputService:GetStringForKeyCode(code)
	return if s ~= "" then string.upper(s) else code.Name
end

-- Where a prompt's target is, or nil if it isn't somewhere in the world.
local function positionOf(target: Instance?): Vector3?
	if target and target:IsA("BasePart") then
		return target.Position
	elseif target and target:IsA("Attachment") then
		return target.WorldPosition
	elseif target and target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

local function adorneeOf(target: Instance): Instance?
	if target:IsA("Model") then
		return target.PrimaryPart
	end
	return target
end

local function fill(prompt: ProximityPrompt, card: ImageButton, inputType: Enum.ProximityPromptInputType)
	local key = card:FindFirstChild("Key") :: ImageLabel
	local letter = key:FindFirstChild("Letter") :: TextLabel
	local pad = key:FindFirstChild("Pad") :: ImageLabel
	local text = card:FindFirstChild("Body") :: Frame
	local object = text:FindFirstChild("Object") :: TextLabel
	local action = text:FindFirstChild("Action") :: TextLabel
	local track = text:FindFirstChild("Track") :: Frame

	local touch = Platform.isTouch()
	key.Visible = not touch
	if touch then
		text.Position = UDim2.new(0, 14, 0, 0)
		text.Size = UDim2.new(1, -28, 1, 0)
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
		pad.Image = image
		pad.Visible = image ~= ""
		letter.Visible = image == ""
		letter.Text = (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	else
		pad.Visible = false
		letter.Visible = true
		letter.Text = keyText(prompt.KeyboardKeyCode)
	end
	-- long key names (Space, Enter) shrink to fit the cap
	letter.TextScaled = #letter.Text > 1

	local hasObject = prompt.ObjectText ~= ""
	object.Visible = hasObject
	object.Text = prompt.ObjectText
	action.Text = prompt.ActionText
	-- one line sits in the middle; two share the card
	action.Position = if hasObject then actionBelow else UDim2.new(0, 0, 0.5, -action.Size.Y.Offset / 2)
	track.Visible = prompt.HoldDuration > 0
end

local function bindInput(prompt: ProximityPrompt, card: ImageButton): () -> ()
	local holding = false
	local function release()
		if holding then
			holding = false
			prompt:InputHoldEnd()
		end
	end
	card.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or (t == Enum.UserInputType.MouseButton1 and prompt.ClickablePrompt) then
			if not holding then
				holding = true
				prompt:InputHoldBegin()
			end
		end
	end)
	card.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			release()
		end
	end)
	card.MouseLeave:Connect(release)
	return release
end

-- Fade a card out, lifted out of the list first (to the slot the list gave it,
-- worked out from the layout rather than read back mid-pop) so the rest don't
-- move for it. The billboard's list fills from the top, the dock's from the bottom.
local function retire(card: ImageButton, b: Board)
	card.Active = false
	if card.Parent == b.list then
		local list = b.list
		local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		local fromBottom = layout.VerticalAlignment == Enum.VerticalAlignment.Bottom
		local y = 0 -- the cards before it (top-down) or after it (bottom-up)
		for _, other in list:GetChildren() do
			if other ~= card and other:IsA("GuiObject") and other.Visible then
				local before = other.LayoutOrder < card.LayoutOrder
				if before ~= fromBottom then
					y += other.Size.Y.Offset + layout.Padding.Offset
				end
			end
		end
		if fromBottom then
			y = list.Size.Y.Offset - y - card.Size.Y.Offset
		end
		-- the list's top-left in its parent, then the card's slot under that
		local at, size, anchor = list.Position, list.Size, list.AnchorPoint
		card.Position = UDim2.new(
			at.X.Scale - anchor.X * size.X.Scale,
			at.X.Offset - anchor.X * size.X.Offset,
			at.Y.Scale - anchor.Y * size.Y.Scale,
			at.Y.Offset - anchor.Y * size.Y.Offset + y
		)
		-- its width came from the list; keep it once it's out
		local w = card.Size.X
		card.Size = UDim2.new(size.X.Scale * w.Scale, size.X.Offset * w.Scale + w.Offset, 0, card.Size.Y.Offset)
		card.Parent = b.holder
	end
	Motion.fadeOut(card, function()
		card:Destroy()
	end)
end

local function addCard(b: Board, prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	shown += 1
	local card = cardTemplate:Clone()
	card.Name = "Prompt"
	fill(prompt, card, inputType)
	-- F above G: cards order by key, then by when they appeared
	card.LayoutOrder = prompt.KeyboardKeyCode.Value * 1000 + shown % 1000

	local bar = ((card:FindFirstChild("Body") :: Frame):FindFirstChild("Track") :: Frame):FindFirstChild("Fill") :: Frame
	bar.Size = UDim2.fromScale(0, 1)

	local connections: { RBXScriptConnection } = {}
	for _, prop in { "ActionText", "ObjectText", "HoldDuration" } do
		table.insert(
			connections,
			prompt:GetPropertyChangedSignal(prop):Connect(function()
				fill(prompt, card, inputType)
			end)
		)
	end
	table.insert(
		connections,
		prompt.PromptButtonHoldBegan:Connect(function()
			local left = 1 - bar.Size.X.Scale
			Motion.tween(bar, { Size = UDim2.fromScale(1, 1) }, TweenInfo.new(prompt.HoldDuration * left, Enum.EasingStyle.Linear))
		end)
	)
	table.insert(
		connections,
		prompt.PromptButtonHoldEnded:Connect(function()
			Motion.tween(bar, { Size = UDim2.fromScale(0, 1) }, HOLD_RESET)
		end)
	)
	table.insert(
		connections,
		prompt.Triggered:Connect(function()
			Motion.tap(card)
		end)
	)
	local release = bindInput(prompt, card)

	card.Visible = true
	card.Interactable = Platform.isTouch() or mouseFree
	card.Parent = b.list
	Motion.fadeIn(card)

	b.cards[prompt] = function()
		for _, c in connections do
			c:Disconnect()
		end
		release()
		retire(card, b)
	end
	b.releases[prompt] = release
end

-- PC: let the board take clicks only while the cursor is free (see the header).
local function updateMouseFree()
	local free = UserInputService.MouseBehavior == Enum.MouseBehavior.Default
	if free == mouseFree then
		return
	end
	mouseFree = free
	local b = board
	if b and b.gui then
		b.gui.Active = free
		for _, card in b.list:GetChildren() do
			if card:IsA("GuiButton") then
				card.Interactable = free
			end
		end
		if not free then
			for _, release in b.releases do
				release() -- a click held as the mouse locked would never see its release
			end
		end
	end
end

local function newBoard(target: Instance): Board?
	if Platform.isTouch() then
		return { holder = dock, list = dock:FindFirstChild("List") :: Frame, target = target, cards = {}, releases = {} }
	end
	local adornee = adorneeOf(target)
	if not adornee then
		return nil
	end
	local gui = boardTemplate:Clone()
	gui.Name = "PromptBoard"
	gui.Adornee = adornee
	gui.Enabled = true
	gui.Active = mouseFree
	gui.Parent = playerGui -- a BillboardGui only takes taps from PlayerGui
	Motion.buttons(gui)
	return { gui = gui, holder = gui, list = gui:FindFirstChild("List") :: Frame, target = target, cards = {}, releases = {} }
end

local function closeBoard(b: Board)
	for _, take in b.cards do
		take()
	end
	table.clear(b.cards)
	table.clear(b.releases)
	local gui = b.gui
	if gui then
		task.delay(FADE_TIME + 0.05, function()
			gui:Destroy()
		end)
	end
end

-- Draw exactly the focused target's shown prompts.
local function reconcile()
	local want: { [ProximityPrompt]: Enum.ProximityPromptInputType } = {}
	local any = false
	for prompt, inputType in live do
		if focus and (prompt.Parent == focus or prompt == companion) then
			want[prompt] = inputType
			any = true
		end
	end
	local b = board
	if b and (not any or b.target ~= focus) then
		closeBoard(b)
		board, b = nil, nil
	end
	if not any then
		return
	end
	if not b then
		b = newBoard(focus :: Instance)
		board = b
	end
	if not b then
		return
	end
	for prompt, take in b.cards do
		if not want[prompt] then
			b.cards[prompt] = nil
			b.releases[prompt] = nil
			take()
		end
	end
	for prompt, inputType in want do
		if not b.cards[prompt] then
			addCard(b, prompt, inputType)
		end
	end
end

local function setMuted(prompt: ProximityPrompt, mute: boolean)
	local keys = muted[prompt]
	local unknown = Enum.KeyCode.Unknown
	if mute then
		-- first time, or the server set a key (GuardedHerb, QiNodes) while muted:
		-- remember the real keys and mute again
		local keyboard, gamepad = prompt.KeyboardKeyCode, prompt.GamepadKeyCode
		if not keys or keyboard ~= unknown or gamepad ~= unknown then
			local saved = keys or { keyboard = keyboard, gamepad = gamepad }
			if keyboard ~= unknown then
				saved.keyboard = keyboard
			end
			if gamepad ~= unknown then
				saved.gamepad = gamepad
			end
			muted[prompt] = saved
			prompt.KeyboardKeyCode = unknown
			prompt.GamepadKeyCode = unknown
		end
	elseif keys then
		muted[prompt] = nil
		prompt.KeyboardKeyCode = keys.keyboard
		prompt.GamepadKeyCode = keys.gamepad
	end
end

-- The nearest target with an enabled prompt in range; the current one keeps
-- focus unless another is clearly nearer.
local function pickFocus(): Instance?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local here = root.Position
	local best: Instance?, bestDistance = nil, math.huge
	local current = math.huge
	for prompt in prompts do
		if prompt.Enabled and prompt.Style == Enum.ProximityPromptStyle.Custom then
			local target = prompt.Parent
			local at = positionOf(target)
			if at then
				local distance = (at - here).Magnitude
				if distance <= prompt.MaxActivationDistance then
					if distance < bestDistance then
						best, bestDistance = target, distance
					end
					if target == focus then
						current = math.min(current, distance)
					end
				end
			end
		end
	end
	if focus and current < math.huge and current <= bestDistance + STICKY then
		return focus
	end
	return best
end

local function refocus()
	local picked = pickFocus()
	local hook = WorldPrompts.companionOf
	local with = if picked and hook then hook(picked) else nil
	-- unmute the new target's keys before anything else, so its cards read right
	for prompt in prompts do
		local mine = picked ~= nil and (prompt.Parent == picked or prompt == with)
		if prompt.Style == Enum.ProximityPromptStyle.Custom or muted[prompt] then
			setMuted(prompt, not mine)
		end
	end
	if picked ~= focus or with ~= companion then
		focus, companion = picked, with
		reconcile()
	end
end

local function track(d: Instance)
	if d:IsA("ProximityPrompt") then
		prompts[d] = true
	end
end

local function untrack(d: Instance)
	if d:IsA("ProximityPrompt") then
		prompts[d] = nil
		setMuted(d, false) -- it may come back (a picked-up item), so give its keys back
		if live[d] then
			live[d] = nil
			reconcile()
		end
	end
end

function WorldPrompts.init()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = playerGui:WaitForChild("Prompts") :: ScreenGui
	boardTemplate = gui:WaitForChild("Board") :: BillboardGui
	cardTemplate = (boardTemplate:WaitForChild("List") :: Frame):WaitForChild("Card") :: ImageButton
	actionBelow = ((cardTemplate:FindFirstChild("Body") :: Frame):FindFirstChild("Action") :: TextLabel).Position
	dock = gui:WaitForChild("Dock") :: Frame
	dock.Visible = Platform.isTouch()
	Motion.buttons(dock)

	for _, d in workspace:GetDescendants() do
		track(d)
	end
	workspace.DescendantAdded:Connect(track)
	workspace.DescendantRemoving:Connect(untrack)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			live[prompt] = inputType
			reconcile()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if live[prompt] then
			live[prompt] = nil
			-- a hide that's straight away undone (its keys coming back as it takes
			-- focus) keeps its card instead of fading it out and in again
			task.delay(HIDE_GRACE, reconcile)
		end
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		if not Platform.isTouch() then
			updateMouseFree()
		end
		since += dt
		if since >= FOCUS_EVERY then
			since = 0
			refocus()
		end
	end)
end

return WorldPrompts
