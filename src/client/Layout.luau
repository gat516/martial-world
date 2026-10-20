--!strict
-- Places the HUD for the device. Every device gets the same bottom stack, always
-- centred: the vitals mount (health, qi, cultivation, realm crest) over one row of
-- hotbar slots. The top-right tiles run compact.
-- PC: the stack shrinks only on narrow windows; there are no touch buttons
-- (M1 swings, Q dashes, Space jumps).
-- Touch: our own cluster at the bottom right replaces Roblox's jump button:
-- Strike in the corner, Jump to its left, Dash above it. The stack shrinks until
-- it clears the cluster, the vitals more on short screens, and slots drop their
-- names for a bigger icon or glyph.
-- Pop-ups that sit over the stack (the Cultivate prompt) are placed above it.
-- Everything stays inside the device's safe area except the cluster, which
-- reaches past the right inset to the screen edge.
-- The top-left corner is always left to Roblox's chat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Platform = require(script.Parent.Platform)

local STACK_WIDTH = 560 -- the vitals mount and hotbar row at full size, with margin
local HOTBAR_WIDTH = 508
local PROMPT_HEIGHT = 236 -- the Cultivate prompt at full size
local TOUCH_VITALS_HEIGHT = 0.2 -- touch: the vitals mount's height as a share of the screen's
local EDGE = 12 -- touch: the cluster's gap from the screen edge
local STRIKE, SMALL, GAP = 70, 50, 10 -- touch: Strike's size, Jump and Dash's size, gap between
local CLUSTER_WIDTH = EDGE + STRIKE + GAP + SMALL + GAP -- bottom-row room the cluster takes

local player = Players.LocalPlayer

local Layout = {}

local gui: ScreenGui

local function find(name: string): GuiObject
	return gui:FindFirstChild(name) :: GuiObject
end

local function setScale(object: GuiObject, scale: number)
	local ui = object:FindFirstChildOfClass("UIScale")
	if ui then
		ui.Scale = scale
	end
end

-- Roblox's own touch jump button; ours replaces it.
local function defaultJump(): GuiObject?
	local playerGui = player:FindFirstChild("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	return frame and frame:FindFirstChild("JumpButton") :: GuiObject?
end

local function hideDefaultJump()
	local button = defaultJump()
	if button and button.Visible and Platform.isTouch() then
		button.Visible = false
	end
end

function Layout.apply()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- the Hud's area inside the safe-area insets, and how far the right inset reaches
	local width, height = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
	local rightInset = math.max(0, viewport.X - (gui.AbsolutePosition.X + width))
	local touch = Platform.isTouch()
	local vitals = find("Vitals")
	local hotbar = find("Hotbar")
	local dodge = find("DodgeButton")
	local strike = find("AttackButton")
	local jump = find("JumpButton")

	local scale = math.clamp((width - 24) / STACK_WIDTH, 0.5, 1)
	local barScale, vitalsScale = scale, scale
	if touch then
		-- centred, the hotbar's right end must clear the cluster
		barScale = math.clamp((width - 2 * CLUSTER_WIDTH) / HOTBAR_WIDTH, 0.5, 1)
		vitalsScale = math.clamp(math.min(barScale, height * TOUCH_VITALS_HEIGHT / 52), 0.5, 1)
	end
	hotbar.Position = UDim2.new(0.5, 0, 1, -10 * barScale)
	vitals.Position = UDim2.new(0.5, 0, 1, -10 * barScale - 60 * barScale - 13 * vitalsScale)
	setScale(hotbar, barScale)
	setScale(vitals, vitalsScale)
	-- the Cultivate prompt rises above the stack (crest included), shrinking to fit short screens
	local stackTop = 70 * barScale + 81 * vitalsScale
	local prompt = find("CultivatePrompt")
	prompt.Position = UDim2.new(0.5, 0, 1, -stackTop - 8)
	setScale(prompt, math.clamp((height - stackTop - 24) / PROMPT_HEIGHT, 0.6, 1))
	-- on touch the slots are too small for names: a bigger icon or glyph instead
	for _, slot in (hotbar:FindFirstChild("Slots") :: Instance):GetChildren() do
		local name = slot:FindFirstChild("NameLabel") :: GuiObject?
		if name and slot.Name ~= "SlotTemplate" then
			name.Visible = not touch
			local icon = slot:FindFirstChild("Icon") :: GuiObject
			local glyph = slot:FindFirstChild("Glyph") :: GuiObject
			icon.Size = if touch then UDim2.fromScale(0.62, 0.62) else UDim2.fromScale(0.5, 0.5)
			icon.Position = if touch then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.36)
			glyph.Size = if touch then UDim2.fromScale(0.58, 0.58) else UDim2.fromScale(0.46, 0.46)
			glyph.Position = if touch then UDim2.fromScale(0.5, 0.48) else UDim2.fromScale(0.5, 0.34)
		end
	end

	dodge.Visible = touch
	strike.Visible = touch
	jump.Visible = touch
	if touch then
		local right = rightInset - EDGE
		strike.AnchorPoint = Vector2.new(1, 1)
		strike.Position = UDim2.new(1, right, 1, -EDGE)
		strike.Size = UDim2.fromOffset(STRIKE, STRIKE)
		jump.AnchorPoint = Vector2.new(1, 0.5)
		jump.Position = UDim2.new(1, right - STRIKE - GAP, 1, -EDGE - STRIKE / 2)
		jump.Size = UDim2.fromOffset(SMALL, SMALL)
		dodge.AnchorPoint = Vector2.new(0.5, 1)
		dodge.Position = UDim2.new(1, right - STRIKE / 2, 1, -EDGE - STRIKE - GAP)
		dodge.Size = UDim2.fromOffset(SMALL, SMALL)
		hideDefaultJump()
	end
	local key = dodge:FindFirstChild("KeyLabel") :: GuiObject?
	if key then
		key.Visible = not touch
	end
	setScale(find("Buttons"), if Platform.isSmall() then 0.75 else 0.85)
end

-- Our Jump button: jumps while held, like Roblox's.
local function bindJump(button: GuiButton)
	local held = false
	local function pointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	button.InputBegan:Connect(function(input)
		if pointer(input) then
			held = true
		end
	end)
	button.InputEnded:Connect(function(input)
		if pointer(input) then
			held = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		local humanoid = held and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Jump = true
		end
	end)
end

function Layout.init(screenGui: ScreenGui)
	gui = screenGui
	bindJump(find("JumpButton") :: GuiButton)
	Layout.apply()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout.apply)
	Platform.onChanged(Layout.apply)
	-- Roblox builds (and re-shows) its jump button with each character; keep it hidden
	local playerGui = player:WaitForChild("PlayerGui")
	local function watch(button: Instance)
		if button.Name == "JumpButton" and button:IsA("GuiObject") and button ~= find("JumpButton") then
			button:GetPropertyChangedSignal("Visible"):Connect(hideDefaultJump)
			task.defer(hideDefaultJump)
		end
	end
	playerGui.DescendantAdded:Connect(watch)
	local existing = defaultJump()
	if existing then
		watch(existing)
	end
end

return Layout
