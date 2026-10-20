--!strict
-- Places the HUD for the device. Every device gets the same bottom stack: the
-- vitals mount (health, qi, cultivation, realm crest) over one row of hotbar
-- slots, scaled down to fit narrow screens. The top-right tiles run compact.
-- PC: the stack is centred; there's no Strike or Dash button (M1 swings, Q dashes).
-- Touch: Strike and Dash sit at the far right around Roblox's jump button, and
-- the stack is centred in the space left of them, scaled for short screens too.
-- Everything stays inside the device's safe area except Strike and Dash, which
-- reach past the right inset to the screen edge.
-- The top-left corner is always left to Roblox's chat.

local Platform = require(script.Parent.Platform)

local STACK_WIDTH = 560 -- the vitals mount and hotbar row at full size, with margin
local STACK_HEIGHT_ROOM = 560 -- touch screens shorter than this scale the stack down
local TOUCH_CLUSTER = 180 -- room kept at the right for Strike, Dash and jump

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

	local room = if touch then width - TOUCH_CLUSTER else width
	local scale = math.clamp((room - 24) / STACK_WIDTH, 0.5, 1)
	if touch then
		scale = math.clamp(math.min(scale, height / STACK_HEIGHT_ROOM), 0.5, 1)
	end
	local centre = if touch then UDim.new(0, room / 2) else UDim.new(0.5, 0)
	hotbar.Position = UDim2.new(centre, UDim.new(1, -10 * scale))
	vitals.Position = UDim2.new(centre, UDim.new(1, -83 * scale))
	setScale(hotbar, scale)
	setScale(vitals, scale)

	dodge.Visible = touch
	strike.Visible = touch
	if touch then
		-- around the jump button (bottom right): Strike above it, Dash beside it
		strike.AnchorPoint = Vector2.new(1, 1)
		strike.Position = UDim2.new(1, rightInset - 10, 1, -100)
		strike.Size = UDim2.fromOffset(76, 76)
		dodge.AnchorPoint = Vector2.new(1, 1)
		dodge.Position = UDim2.new(1, rightInset - 100, 1, -20)
		dodge.Size = UDim2.fromOffset(60, 60)
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
