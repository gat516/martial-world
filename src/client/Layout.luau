--!strict
-- Places the HUD for the device. Every device gets the same bottom stack: the
-- vitals mount (health, qi, cultivation, realm crest) over one row of hotbar
-- slots, scaled down to fit narrow screens. The top-right tiles run compact.
-- PC: the stack is centred; there's no Strike or Dash button (M1 swings, Q dashes).
-- Touch: Strike and Dash sit side by side above Roblox's jump button at the far
-- right; the stack stays centred unless it would reach the jump button.
-- Everything stays inside the device's safe area except Strike and Dash, which
-- reach past the right inset to the screen edge.
-- The top-left corner is always left to Roblox's chat.

local Platform = require(script.Parent.Platform)

local STACK_WIDTH = 560 -- the vitals mount and hotbar row at full size, with margin
local TOUCH_HOTBAR_MIN = 0.75 -- touch: the hotbar never shrinks past this (thumb targets)
local TOUCH_VITALS_HEIGHT = 0.2 -- touch: the vitals mount's height as a share of the screen's
local JUMP_ROOM = 104 -- touch: Roblox's jump button owns this much of the bottom right

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

	local scale = math.clamp((width - 24) / STACK_WIDTH, 0.5, 1)
	local barScale, vitalsScale = scale, scale
	if touch then
		-- short screens: the hotbar keeps thumb-sized slots, the vitals give way
		barScale = math.max(scale, TOUCH_HOTBAR_MIN)
		vitalsScale = math.clamp(math.min(scale, height * TOUCH_VITALS_HEIGHT / 52), 0.55, 1)
	end
	local centre = UDim.new(0.5, 0)
	if touch then
		local half = STACK_WIDTH * barScale / 2
		centre = UDim.new(0, math.min(width / 2, width - JUMP_ROOM - half))
	end
	hotbar.Position = UDim2.new(centre, UDim.new(1, -10 * barScale))
	vitals.Position = UDim2.new(centre, UDim.new(1, -10 * barScale - 60 * barScale - 13 * vitalsScale))
	setScale(hotbar, barScale)
	setScale(vitals, vitalsScale)
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
	if touch then
		-- above the jump button (bottom right): Strike at the edge, Dash beside it
		strike.AnchorPoint = Vector2.new(1, 1)
		strike.Position = UDim2.new(1, rightInset - 12, 1, -92)
		strike.Size = UDim2.fromOffset(64, 64)
		dodge.AnchorPoint = Vector2.new(1, 0.5)
		dodge.Position = UDim2.new(1, rightInset - 86, 1, -124)
		dodge.Size = UDim2.fromOffset(50, 50)
	end
	local key = dodge:FindFirstChild("KeyLabel") :: GuiObject?
	if key then
		key.Visible = not touch
	end
	setScale(find("Buttons"), if Platform.isSmall() then 0.75 else 0.85)
end

function Layout.init(screenGui: ScreenGui)
	gui = screenGui
	Layout.apply()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout.apply)
	Platform.onChanged(Layout.apply)
end

return Layout
