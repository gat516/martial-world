--!strict
-- The HUD sizes itself: the Stack frame (vitals, hotbar, seat pills, Break Through)
-- fits the screen with aspect and size constraints, so Studio's edit view shows
-- what players see. This only flips what differs by device:
-- PC: no touch buttons (M1 swings, Q dashes, Space jumps); the stack may use the
-- full width; slots show their names.
-- The seated cultivation bars (Stack.SeatBars) share the vitals' box. On short
-- screens the stack takes at most SMALL_HEIGHT_SHARE of the height.
-- Touch: our own Strike, Jump, Dash and Guard cluster replaces Roblox's jump button and
-- reaches past the right safe-area inset to the screen edge; slots drop their
-- names for a bigger icon or glyph. The mini cooldown chips in the vitals plate's
-- notch are PC and gamepad only (Dash and Strike show their own).
-- The top-left corner is always left to Roblox's chat.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Platform = require(script.Parent.Platform)

local CLUSTER_ROOM = 320 -- touch: width the stack leaves free (twice the cluster, so it stays centred)
local EDGE = 12 -- touch: the cluster's gap from the screen edge
local HEIGHT_SHARE = 0.45 -- the most of the screen's height the stack may take
local SMALL_HEIGHT_SHARE = 0.36 -- on short screens (Platform.isSmall), phones and small windows (0.3 before
-- the name plaque joined the stack, 2026-10-23; 0.36 keeps the bars as wide on a phone)

local player = Players.LocalPlayer

local Layout = {}

local gui: ScreenGui
local clusterShown = true -- false while seated (Meditation)

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
	-- short screens cap the stack lower: at 0.45 a landscape phone (or the device
	-- emulator, which reports a mouse and so gets the PC layout) gave nearly half
	-- the screen to the vitals and hotbar
	local share = if Platform.isSmall() then SMALL_HEIGHT_SHARE else HEIGHT_SHARE
	stack.Size = UDim2.new(1, if touch then -CLUSTER_ROOM else -24, share, 0)
	-- the touch prompt dock mirrors the stack's box (WorldPrompts)
	local playerGui = player:FindFirstChild("PlayerGui")
	local prompts = playerGui and playerGui:FindFirstChild("Prompts")
	local dock = prompts and prompts:FindFirstChild("Dock") :: GuiObject?
	if dock then
		dock.Size = stack.Size
	end

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

	-- touch: the big Dash and Strike buttons show their own cooldowns, so the mini
	-- chips (tucked into the vitals plate's left notch on PC) go; Menus shows them
	-- on PC. The vitals sit right on the hotbar on every device.

	local strike, jump, dodge = find("AttackButton"), find("JumpButton"), find("DodgeButton")
	local block = find("BlockButton")
	local cluster = touch and clusterShown
	strike.Visible, jump.Visible, dodge.Visible, block.Visible = cluster, cluster, cluster, cluster
	if touch then
		-- reach past the right inset: Strike in the corner, Jump left of it, Dash above it
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize.X else gui.AbsoluteSize.X
		local right = math.max(0, viewport - (gui.AbsolutePosition.X + gui.AbsoluteSize.X)) - EDGE
		strike.Position = UDim2.new(1, right, 1, -EDGE)
		jump.Position = UDim2.new(1, right - 80, 1, -EDGE - 35)
		dodge.Position = UDim2.new(1, right - 35, 1, -EDGE - 80)
		-- Guard above Dash, on the same arc from the Strike corner
		block.Position = UDim2.new(1, right - 35, 1, -EDGE - 138)
		-- Lock on the arc between Jump and Dash (LockOn shows it when there's something to lock)
		find("LockButton").Position = UDim2.new(1, right - 95, 1, -EDGE - 100)
		hideDefaultJump()
	end
	-- key hints are for keyboards only
	for _, button in { dodge, find("CultivateButton") } do
		local key = button:FindFirstChild("KeyLabel") :: GuiObject?
		if key then
			key.Visible = not touch
		end
	end
	local tiles = find("Buttons"):FindFirstChildOfClass("UIScale")
	if tiles then
		-- touch: tiles stay thumb-sized (about 50px); PC: a little smaller
		tiles.Scale = if touch then 0.9 elseif Platform.isSmall() then 0.75 else 0.85
	end
end

-- The touch combat cluster steps aside while seated (getting up is the move).
function Layout.showCluster(shown: boolean)
	if shown ~= clusterShown then
		clusterShown = shown
		if gui then
			Layout.apply()
		end
	end
end

function Layout.clusterShown(): boolean
	return clusterShown
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
