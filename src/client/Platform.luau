--!strict
-- Whether this player is on a touch screen (phones, tablets) rather than a
-- mouse and keyboard, and small-screen checks for the HUD layout.
-- Decided once at startup and never changed, so the HUD keeps one layout for the
-- whole session however input devices take turns.

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

return Platform
