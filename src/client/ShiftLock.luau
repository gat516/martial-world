--!strict
-- Roblox's shift lock, on Alt instead of Shift (Shift+R rotates in build mode),
-- with our own centre cursor. The toggle and camera stay Roblox's: this only
-- rebinds the keys through its MouseLockController's BoundKeys value.
-- PC: whenever the mouse is held at the centre (shift lock, first person) the
-- system cursor hides for Play.ShiftLockReticle. Lock-on (LockOn.luau) holds the
-- mouse too but marks its target instead, so then neither shows.
-- Roblox snaps the camera onto the shoulder when shift lock toggles; this eases
-- that slide over SHOULDER_SECONDS by offsetting against it for a moment.
-- While a window is open (Menus: inventory, reward card, minigame...) shift lock
-- is switched off so the mouse is free over it, and switched back on when the
-- last window closes. Roblox gives no handle on its MouseLockController, so this
-- catches the controller the first time the camera asks it for its state (which
-- the camera does on every toggle) and toggles it the same way Alt does.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LockOn = require(script.Parent.LockOn)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local KEYS = "LeftAlt,RightAlt"
local SHOULDER = 1.75 -- studs Roblox's shift lock moves the camera right (MouseLockController's default offset)
local SHOULDER_SECONDS = 0.2

local player = Players.LocalPlayer

local ShiftLock = {}

-- Roblox's MouseLockController instance, once caught (see hook)
type Controller = { isMouseLocked: boolean, OnMouseLockToggled: (any) -> () }
local controller: Controller? = nil
local suspended = false -- shift lock was on when a window opened

-- The camera calls GetIsMouseLocked on the controller whenever shift lock toggles,
-- so wrapping it on the shared class hands us the instance before it can matter.
local function hook(module: ModuleScript)
	local ok, class = pcall(require, module)
	if not ok or type(class) ~= "table" or type(class.GetIsMouseLocked) ~= "function" or type(class.OnMouseLockToggled) ~= "function" then
		warn("ShiftLock: MouseLockController isn't the shape expected; windows won't suspend shift lock")
		return
	end
	local original = class.GetIsMouseLocked
	class.GetIsMouseLocked = function(self, ...)
		controller = self
		return original(self, ...)
	end
end

-- Keep shift lock off while a window is open, and put it back afterwards.
local function suspendForMenus()
	local c = controller
	if not c then
		return
	end
	if Menus.isOpen() then
		if c.isMouseLocked then -- on as it opened, or Alt pressed over it
			c:OnMouseLockToggled()
			suspended = true
		end
	elseif suspended then
		suspended = false
		if not c.isMouseLocked then
			c:OnMouseLockToggled()
		end
	end
end

local function rebind()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 30)
	local camera = module and module:WaitForChild("CameraModule", 30)
	local lockModule = camera and camera:WaitForChild("MouseLockController", 30) :: ModuleScript?
	if lockModule and not Platform.isTouch() then
		hook(lockModule)
	end
	local keys = lockModule and lockModule:WaitForChild("BoundKeys", 30) :: StringValue?
	if keys then
		keys.Value = KEYS
	else
		warn("ShiftLock: MouseLockController.BoundKeys not found; shift lock stays on Shift")
	end
end

function ShiftLock.init(gui: ScreenGui)
	task.spawn(rebind)
	if Platform.isTouch() then
		return
	end
	local play = gui:FindFirstChild("Play") :: GuiObject
	local reticle = play:FindFirstChild("ShiftLockReticle") :: GuiObject
	reticle.Visible = false
	local scale = reticle:FindFirstChild("Motion") :: UIScale?
	local iconShown = true
	local shoulderOn = false -- shift lock's shoulder offset is applied (not first person, not locked on)
	local easeLeft = 0
	local easeFrom = 0 -- studs right the camera stood when the shoulder snapped

	-- after the camera module and LockOn have set this frame's mouse behaviour
	RunService:BindToRenderStep("ShiftLockReticle", Enum.RenderPriority.Camera.Value + 3, function(dt: number)
		suspendForMenus()
		local camera = workspace.CurrentCamera
		local centred = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		local locked = LockOn.target() ~= nil

		-- ease the shoulder slide: lock-on owns the camera meanwhile, so skip it then
		if not locked then
			local distance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
			local nowOn = centred and distance > 1.5
			if nowOn ~= shoulderOn then
				shoulderOn = nowOn
				-- where the camera was, relative to where Roblox just put it
				local shown = easeFrom * (easeLeft / SHOULDER_SECONDS) ^ 2
				easeFrom = shown + (if nowOn then -SHOULDER else SHOULDER)
				easeLeft = SHOULDER_SECONDS
			end
		end
		if easeLeft > 0 then
			easeLeft = math.max(0, easeLeft - dt)
			local t = easeLeft / SHOULDER_SECONDS
			local offset = easeFrom * t * t -- quad out toward Roblox's own placement
			camera.CFrame += camera.CFrame.RightVector * offset
		end

		local show = centred and not locked and play.Visible
		if show then
			-- the viewport's centre (where Roblox holds the mouse), in Play's space
			local centre = workspace.CurrentCamera.ViewportSize / 2 - GuiService:GetGuiInset() - play.AbsolutePosition
			reticle.Position = UDim2.fromOffset(centre.X, centre.Y)
			if not reticle.Visible and scale then
				scale.Scale = 1.4
				Motion.tween(scale, { Scale = 1 }, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
			end
		end
		reticle.Visible = show
		local wantIcon = not (show or locked)
		if wantIcon ~= iconShown then
			iconShown = wantIcon
			UserInputService.MouseIconEnabled = wantIcon
		end
	end)
end

return ShiftLock
