--!strict
-- Whether this player is on a touch screen (phones, tablets) rather than a
-- mouse and keyboard, and small-screen checks for the HUD layout.

local UserInputService = game:GetService("UserInputService")

local Platform = {}

-- Studio's device emulator reports a mouse too, so this asks what the player
-- prefers (PreferredInput) where the engine has it, and falls back to "touch
-- screen with no keyboard".
function Platform.isTouch(): boolean
	local ok, preferred = pcall(function()
		return (UserInputService :: any).PreferredInput
	end)
	if ok and preferred ~= nil then
		return preferred == (Enum :: any).PreferredInput.Touch
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
