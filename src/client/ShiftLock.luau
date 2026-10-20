--!strict
-- Roblox's shift lock, on Alt instead of Shift (Shift+R rotates in build mode),
-- with our own centre cursor. The toggle and camera stay Roblox's: this only
-- rebinds the keys through its MouseLockController's BoundKeys value.
-- PC: whenever the mouse is held at the centre (shift lock, first person) the
-- system cursor hides for Play.ShiftLockReticle. Lock-on (LockOn.luau) holds the
-- mouse too but marks its target instead, so then neither shows.
-- Roblox snaps the camera onto the shoulder when shift lock toggles; this eases
-- that slide over SHOULDER_SECONDS by offsetting against it for a moment.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LockOn = require(script.Parent.LockOn)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local KEYS = "LeftAlt,RightAlt"
local SHOULDER = 1.75 -- studs Roblox's shift lock moves the camera right (MouseLockController's default offset)
local SHOULDER_SECONDS = 0.2

local player = Players.LocalPlayer

local ShiftLock = {}

local function rebind()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 30)
	local camera = module and module:WaitForChild("CameraModule", 30)
	local controller = camera and camera:WaitForChild("MouseLockController", 30)
	local keys = controller and controller:WaitForChild("BoundKeys", 30) :: StringValue?
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
