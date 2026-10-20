--!strict
-- Whether this player is on a touch screen (phones, tablets) rather than a
-- mouse and keyboard, and small-screen checks for the HUD layout.

local UserInputService = game:GetService("UserInputService")

local Platform = {}

-- A touch screen with no keyboard, or a player whose preferred input is touch
-- (PreferredInput, where the engine has it). Studio's device emulator reports a
-- mouse too, and only prefers touch once tapped, so both are checked.
function Platform.isTouch(): boolean
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	local ok, preferred = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	return ok and preferred ~= nil and preferred == (Enum :: any).PreferredInput.Touch
end

-- Calls fn whenever the answer to isTouch might have changed.
function Platform.onChanged(fn: () -> ())
	local ok, signal = pcall(function()
		return UserInputService:GetPropertyChangedSignal("PreferredInput" :: any)
	end)
	if ok and signal then
		signal:Connect(fn)
	end
	UserInputService.LastInputTypeChanged:Connect(fn)
end

-- A phone-sized screen: short enough that the HUD shrinks.
function Platform.isSmall(): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y < 520
end

return Platform
