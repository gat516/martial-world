--!strict
-- PC: our own mouse pointer, a paper-white arrow in the HUD's palette that turns
-- gold over a clickable button. Art: art/ui/draw_cursor.py (Roblox centres the
-- icon on the mouse, so the arrow's tip is the image's centre).
-- This only picks which image the pointer uses. Whether it shows at all stays
-- with ShiftLock.luau (MouseIconEnabled), which hides it whenever the mouse is
-- held at the centre (shift lock, first person, lock-on), so nothing here
-- touches MouseBehavior or the camera.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Platform = require(script.Parent.Platform)

local ARROW = "rbxassetid://96712021684899"
local HOVER = "rbxassetid://134487250595279"
local CHECK_EVERY = 0.05 -- seconds between hover checks (also catches menus opening under a still mouse)

local Cursor = {}

-- The top-most thing under the mouse is a button the player can press.
local function overButton(playerGui: PlayerGui): boolean
	local at = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(at.X, at.Y) do
		if object:IsA("GuiButton") then
			return object.Active and object.Interactable
		end
		if object.Active then
			return false -- an active frame or label over the button takes the click
		end
	end
	return false
end

function Cursor.init()
	if Platform.isTouch() then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local current = ARROW
	UserInputService.MouseIcon = current
	local wait = 0
	RunService.Heartbeat:Connect(function(dt: number)
		wait -= dt
		if wait > 0 then
			return
		end
		wait = CHECK_EVERY
		-- a centred mouse is hidden anyway (ShiftLock), so keep the plain arrow ready for its return
		local free = UserInputService.MouseBehavior == Enum.MouseBehavior.Default
		local want = if free and overButton(playerGui) then HOVER else ARROW
		if want ~= current then
			current = want
			UserInputService.MouseIcon = want
		end
	end)
end

return Cursor
