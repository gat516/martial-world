--!strict
-- The HUD sizes itself: the Stack frame (vitals, hotbar, seat pills, Break Through)
-- fits the screen with aspect and size constraints, so Studio's edit view shows
-- what players see. This only flips what differs by device:
-- PC: no touch buttons (M1 swings, Q dashes, Space jumps); the stack may use the
-- full width; slots show their names.
-- The seated cultivation bars (Stack.SeatBars) share the vitals' box. On short
-- screens the stack takes at most SMALL_HEIGHT_SHARE of the height, on a touch
-- phone TOUCH_SMALL_SHARE.
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
-- Touch cluster (phone HUD pass, 2026-10-23): Strike (70) in the corner, Jump, Dash and
-- Guard (50 each) on one arc around it, ARC px from Strike's centre at 180, 135 and 90
-- degrees, so the cluster is a 146 px quarter instead of a 211 px column; Lock (shown
-- only with something to lock) sits outside the arc at 112.5 degrees, LOCK_ARC out.
local STRIKE = 70
local ARC = 74
local LOCK_ARC = 128
-- The most of the screen's height the stack may take. Both shares were cut by the
-- name row's 13.4% when the name plaque left the stack (2026-10-22), so the bars
-- keep their width where height is the limit.
local HEIGHT_SHARE = 0.39
local SMALL_HEIGHT_SHARE = 0.31 -- on short screens (Platform.isSmall), phones and small windows
-- A touch phone (short and touch) keeps less: the user couldn't see the world past the
-- HUD (2026-10-23). Readability comes from contrast, never from size.
local TOUCH_SMALL_SHARE = 0.26

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
	-- short screens cap the stack lower: at the full share a landscape phone (or the device
	-- emulator, which reports a mouse and so gets the PC layout) gave nearly half
	-- the screen to the vitals and hotbar
	local share = if Platform.isSmall() then (if touch then TOUCH_SMALL_SHARE else SMALL_HEIGHT_SHARE) else HEIGHT_SHARE
	stack.Size = UDim2.new(1, if touch then -CLUSTER_ROOM else -24, share, 0)
	-- the touch prompt dock mirrors the stack's box (WorldPrompts)
	local playerGui = player:FindFirstChild("PlayerGui")
	local prompts = playerGui and playerGui:FindFirstChild("Prompts")
	local dock = prompts and prompts:FindFirstChild("Dock") :: GuiObject?
	if dock then
		dock.Size = stack.Size
	end

	-- on touch the slots are too small for names: a bigger icon well, centred, instead.
	-- PC: the well sits centred in the space above the one-line name strip.
	local slots = (stack:FindFirstChild("Hotbar") :: Instance):FindFirstChild("Slots") :: Instance
	for _, slot in slots:GetChildren() do
		local name = slot:FindFirstChild("NameLabel") :: GuiObject?
		if name and slot.Name ~= "SlotTemplate" then
			name.Visible = not touch
			local well = slot:FindFirstChild("Well") :: GuiObject
			well.Size = if touch then UDim2.fromScale(0.64, 0.64) else UDim2.fromScale(0.54, 0.54)
			well.Position = if touch then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.355)
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
		-- Strike in the corner; the others centred on an arc around it (all AnchorPoint
		-- 0.5 but Strike's, as authored)
		strike.Position = UDim2.new(1, right, 1, -EDGE)
		local cx, cy = right - STRIKE / 2, -EDGE - STRIKE / 2
		local function onArc(button: GuiObject, degrees: number, radius: number)
			local a = math.rad(degrees)
			button.Position = UDim2.new(1, math.round(cx + math.cos(a) * radius), 1, math.round(cy - math.sin(a) * radius))
		end
		onArc(jump, 180, ARC)
		onArc(dodge, 135, ARC)
		onArc(block, 90, ARC)
		onArc(find("LockButton"), 112.5, LOCK_ARC) -- LockOn shows it when there's something to lock
		hideDefaultJump()
	end
	-- key hints are for keyboards only
	for _, button in { dodge, find("CultivateButton") } do
		local key = button:FindFirstChild("KeyLabel") :: GuiObject?
		if key then
			key.Visible = not touch
		end
	end
	-- top-right tiles: on touch the caption would render tiny, so it hides and the icon
	-- centres on the frame, larger; PC keeps the caption in the frame's bottom strip and
	-- centres the icon between the frame's inner line (11/128 in) and the caption's top
	for _, tile in find("Buttons"):GetChildren() do
		local icon = tile:FindFirstChild("Icon") :: GuiObject?
		local caption = tile:FindFirstChild("Caption") :: GuiObject?
		if icon and caption then
			caption.Visible = not touch
			icon.Size = if touch then UDim2.fromOffset(28, 28) else UDim2.fromOffset(24, 24)
			icon.Position = if touch then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.38225)
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
