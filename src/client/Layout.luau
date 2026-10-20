--!strict
-- The HUD sizes itself: the Stack frame (vitals, hotbar, seat pills, Break Through)
-- fits the screen with aspect and size constraints, so Studio's edit view shows
-- what players see. This only flips what differs by device:
-- PC: no touch buttons (M1 swings, Q dashes, Space jumps); the stack may use the
-- full width; slots show their names.
-- Touch: our own Strike, Jump and Dash cluster replaces Roblox's jump button and
-- reaches past the right safe-area inset to the screen edge; slots drop their
-- names for a bigger icon or glyph.
-- The top-left corner is always left to Roblox's chat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Platform = require(script.Parent.Platform)

local CLUSTER_ROOM = 320 -- touch: width the stack leaves free (twice the cluster, so it stays centred)
local EDGE = 12 -- touch: the cluster's gap from the screen edge

local player = Players.LocalPlayer

local Layout = {}

local gui: ScreenGui

local function find(name: string): GuiObject
	return gui:FindFirstChild(name, true) :: GuiObject
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
	local touch = Platform.isTouch()
	local stack = find("Stack")
	stack.Size = UDim2.new(1, if touch then -CLUSTER_ROOM else -24, 0.45, 0)

	-- on touch the slots are too small for names: a bigger icon or glyph instead
	local slots = (stack:FindFirstChild("Hotbar") :: Instance):FindFirstChild("Slots") :: Instance
	for _, slot in slots:GetChildren() do
		local name = slot:FindFirstChild("NameLabel") :: GuiObject?
		if name and slot.Name ~= "SlotTemplate" then
			name.Visible = not touch
			local icon = slot:FindFirstChild("Icon") :: GuiObject
			local glyph = slot:FindFirstChild("Glyph") :: GuiObject
			icon.Size = if touch then UDim2.fromScale(0.62, 0.62) else UDim2.fromScale(0.52, 0.52)
			icon.Position = if touch then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.42)
			glyph.Size = if touch then UDim2.fromScale(0.58, 0.58) else UDim2.fromScale(0.46, 0.46)
			glyph.Position = if touch then UDim2.fromScale(0.5, 0.48) else UDim2.fromScale(0.5, 0.34)
		end
	end

	local strike, jump, dodge = find("AttackButton"), find("JumpButton"), find("DodgeButton")
	strike.Visible, jump.Visible, dodge.Visible = touch, touch, touch
	if touch then
		-- reach past the right inset: Strike in the corner, Jump left of it, Dash above it
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize.X else gui.AbsoluteSize.X
		local right = math.max(0, viewport - (gui.AbsolutePosition.X + gui.AbsoluteSize.X)) - EDGE
		strike.Position = UDim2.new(1, right, 1, -EDGE)
		jump.Position = UDim2.new(1, right - 80, 1, -EDGE - 35)
		dodge.Position = UDim2.new(1, right - 35, 1, -EDGE - 80)
		hideDefaultJump()
	end
	local key = dodge:FindFirstChild("KeyLabel") :: GuiObject?
	if key then
		key.Visible = not touch
	end
	local tiles = find("Buttons"):FindFirstChildOfClass("UIScale")
	if tiles then
		tiles.Scale = if Platform.isSmall() then 0.75 else 0.85
	end
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
