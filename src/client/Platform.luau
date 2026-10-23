--!strict
-- Whether this player is on a touch screen (phones, tablets) rather than a
-- mouse and keyboard, and small-screen checks for the HUD layout.
-- Decided once at startup and never changed, so the HUD keeps one layout for the
-- whole session however input devices take turns.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Platform = {}

local function preferredTouch(): boolean
	local ok, preferred = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	return ok and preferred ~= nil and preferred == (Enum :: any).PreferredInput.Touch
end

local touch = UserInputService.TouchEnabled
	and (not UserInputService.KeyboardEnabled or not UserInputService.MouseEnabled or preferredTouch())

function Platform.isTouch(): boolean
	return touch
end

-- A phone-sized screen: short enough that the HUD shrinks.
function Platform.isSmall(): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y < 520
end

-- Roblox's top bar in a ScreenGui's own coordinates: how far down it reaches (windows
-- start below it) and where its free space starts after Roblox's menu and chat
-- buttons (the toast's lane lives in that row). Zero in Studio's Edit view.
function Platform.topbar(gui: GuiBase2d): (number, number)
	local inset = GuiService.TopbarInset
	local origin = gui.AbsolutePosition
	return math.max(0, inset.Max.Y - origin.Y), math.max(0, inset.Min.X - origin.X)
end

-- Fires when the top bar's size or free space changes.
function Platform.topbarChanged(fn: () -> ())
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fn)
end

return Platform
