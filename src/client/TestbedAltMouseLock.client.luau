--!strict
-- The testbed's current Roblox camera has no PlayerModule/BoundKeys to rebind.
-- Its built-in Shift toggle is disabled in test.project.json; this script gives
-- keyboard players an Alt toggle while leaving the main experience untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
if not Config.TESTBED then
	return
end

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Menus = require(script.Parent.Menus)
local LockOn = require(script.Parent.LockOn)

if not UserInputService.KeyboardEnabled or not UserInputService.MouseEnabled then
	return
end

local player = Players.LocalPlayer
local SHOULDER = Vector3.new(1.75, 0, 0)
local wanted = false
local active = false
local lockedByUs = false
local offsetHumanoid: Humanoid? = nil
local originalOffset = Vector3.zero

ContextActionService:BindActionAtPriority("TestbedAltMouseLock", function(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() or Menus.isOpen() then
		return Enum.ContextActionResult.Pass
	end
	wanted = not wanted
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt)

local function beforeCamera()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= offsetHumanoid then
		if offsetHumanoid then
			offsetHumanoid.CameraOffset = originalOffset
		end
		offsetHumanoid = humanoid
		originalOffset = if humanoid then humanoid.CameraOffset else Vector3.zero
	end

	active = wanted and not Menus.isOpen() and humanoid ~= nil and humanoid.Health > 0
	local camera = workspace.CurrentCamera
	local firstPerson = camera ~= nil and (camera.CFrame.Position - camera.Focus.Position).Magnitude <= 1.5
	if humanoid then
		humanoid.CameraOffset = originalOffset + (if active and not firstPerson and LockOn.target() == nil then SHOULDER else Vector3.zero)
	end
	if active then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		lockedByUs = true
	elseif lockedByUs then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		lockedByUs = false
	end
end

-- Core camera code may write MouseBehavior during its update. Reapply Alt lock
-- after the camera and LockOn update, before the reticle and Movement read it.
local function afterCamera()
	if active and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

RunService:BindToRenderStep("TestbedAltLockBeforeCamera", Enum.RenderPriority.Input.Value + 2, beforeCamera)
RunService:BindToRenderStep("TestbedAltLockAfterCamera", Enum.RenderPriority.Camera.Value + 2, afterCamera)
