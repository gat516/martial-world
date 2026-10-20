--!strict
-- Our look for every ProximityPrompt in the world (all of them use Style Custom,
-- so Roblox draws nothing). Visible prompts stack as cards in one list beside the
-- character (StarterGui.Prompts.List, Card is the template) instead of floating
-- over their objects, so two prompts never overlap each other or a plant's card.
-- Each card shows the key cap (keyboard key, or the gamepad button), the object
-- and action text (kept live: prices and "No seeds" change while shown), and a
-- hold bar for prompts with a HoldDuration. On touch there's no key cap: the
-- whole card is the button. A mouse can click a card too (ClickablePrompt).
-- ProximityPromptService still decides what shows (range, Enabled, line of
-- sight, one prompt per key, Menus switching it off while a window is open).
--
-- PC: the list hangs just below and right of screen centre, clear of the plant
-- card that floats above a plant. Touch: it stacks upward from the centre
-- instead, clear of the Strike/Jump/Dash cluster in the bottom-right corner.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local HOLD_RESET = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Keys whose GetStringForKeyCode is empty or unhelpful.
local KEY_NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Space] = "Space",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.Tab] = "Tab",
	[Enum.KeyCode.Backspace] = "Bksp",
}

local WorldPrompts = {}

local list: Frame
local template: ImageButton
local actionBelow: UDim2 -- where the action line sits under the object line (authored)
local hides: { [ProximityPrompt]: () -> () } = {} -- each shown prompt's card, by how to hide it
local shown = 0 -- counts shows, to keep same-key cards in the order they appeared

local function keyText(code: Enum.KeyCode): string
	local named = KEY_NAMES[code]
	if named then
		return named
	end
	local s = UserInputService:GetStringForKeyCode(code)
	return if s ~= "" then string.upper(s) else code.Name
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
		text.Position = UDim2.new(0, 18, 0, 0)
		text.Size = UDim2.new(1, -36, 1, 0)
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

	-- F above G: cards order by key, then by when they appeared
	card.LayoutOrder = prompt.KeyboardKeyCode.Value * 1000 + shown % 1000
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

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local old = hides[prompt]
	if old then
		old()
	end
	shown += 1
	local card = template:Clone()
	card.Name = "Prompt"
	fill(prompt, card, inputType)

	local bar = ((card:FindFirstChild("Body") :: Frame):FindFirstChild("Track") :: Frame):FindFirstChild("Fill") :: Frame
	bar.Size = UDim2.fromScale(0, 1)

	local connections: { RBXScriptConnection } = {}
	for _, prop in { "ActionText", "ObjectText", "KeyboardKeyCode", "GamepadKeyCode", "HoldDuration" } do
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
	card.Parent = list
	Motion.fadeIn(card)

	local gone = false
	local function hide()
		if gone then
			return
		end
		gone = true
		for _, c in connections do
			c:Disconnect()
		end
		release()
		if hides[prompt] == hide then
			hides[prompt] = nil
		end
		card.Active = false
		Motion.fadeOut(card, function()
			card:Destroy()
		end)
	end
	hides[prompt] = hide
	table.insert(connections, prompt.PromptHidden:Connect(hide))
	table.insert(connections, prompt.Destroying:Connect(hide))
end

function WorldPrompts.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("Prompts") :: ScreenGui
	list = gui:WaitForChild("List") :: Frame
	template = list:WaitForChild("Card") :: ImageButton
	template.Visible = false
	actionBelow = ((template:FindFirstChild("Body") :: Frame):FindFirstChild("Action") :: TextLabel).Position

	if Platform.isTouch() then
		list.AnchorPoint = Vector2.new(0, 1)
		list.Position = UDim2.new(0.5, 56, 0.5, 4)
		local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end
	Motion.buttons(list)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType)
		end
	end)
end

return WorldPrompts
