--!strict
-- The Settings window (the gear tile): music and sound-effect volume, plus
-- Auto combat (touch only: LockOn's auto lock, close-in and strike) and the PC
-- lock-on key hint. Volumes drive the SoundService.Music and SoundService.SFX
-- groups; every sound belongs in one of them.
-- Changes apply at once and are sent to the server a moment after the last one
-- (SaveSettings), which stores them with the profile. The saved set arrives with
-- the first PlayerState push; after that this window is the authority.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local ListWindow = require(script.Parent.ListWindow)
local LockOn = require(script.Parent.LockOn)
local Menus = require(script.Parent.Menus)
local Platform = require(script.Parent.Platform)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.SaveSettings :: RemoteEvent

local SAVE_DELAY = 1 -- seconds after the last change before saving

type Values = { music: number, sfx: number, autoAttack: boolean, lockHint: boolean }

local Settings = {}

local values: Values = { music = 1, sfx = 1, autoAttack = true, lockHint = true }
local loaded = false
local saveToken = 0
local refreshers: { () -> () } = {}

local function apply()
	local music = SoundService:FindFirstChild("Music") :: SoundGroup?
	local sfx = SoundService:FindFirstChild("SFX") :: SoundGroup?
	if music then
		music.Volume = values.music
	end
	if sfx then
		sfx.Volume = values.sfx
	end
	LockOn.setAuto(values.autoAttack and Platform.isTouch())
	LockOn.setHint(values.lockHint)
	for _, refresh in refreshers do
		refresh()
	end
end

local function saveSoon()
	saveToken += 1
	local token = saveToken
	task.delay(SAVE_DELAY, function()
		if token == saveToken then
			remote:FireServer(values)
		end
	end)
end

local function change(key: string, value: any)
	(values :: any)[key] = value
	apply()
	saveSoon()
end

-- A Track that sets a 0..1 value while pressed and dragged along it.
local function bindSlider(row: Instance, key: string)
	local track = row:FindFirstChild("Track") :: GuiObject
	local fill = track:FindFirstChild("Fill") :: GuiObject
	local knob = track:FindFirstChild("Knob") :: GuiObject
	local label = row:FindFirstChild("Value") :: TextLabel
	local function refresh()
		local v = (values :: any)[key] :: number
		fill.Size = UDim2.fromScale(v, fill.Size.Y.Scale)
		knob.Position = UDim2.fromScale(v, knob.Position.Y.Scale)
		label.Text = `{math.round(v * 100)}%`
	end
	table.insert(refreshers, refresh)

	local dragging: InputObject? = nil
	-- the bar is the track's inner width: its UIPadding keeps a bigger touch target
	local padding = track:FindFirstChildOfClass("UIPadding")
	local function setFrom(x: number)
		local left = if padding then padding.PaddingLeft.Offset else 0
		local right = if padding then padding.PaddingRight.Offset else 0
		local width = math.max(track.AbsoluteSize.X - left - right, 1)
		local v = math.clamp((x - track.AbsolutePosition.X - left) / width, 0, 1)
		change(key, math.round(v * 20) / 20) -- steps of 5%
	end
	track.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = input
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input == dragging or (input.UserInputType == Enum.UserInputType.MouseMovement and dragging.UserInputType == Enum.UserInputType.MouseButton1) then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == dragging or (dragging and input.UserInputType == dragging.UserInputType) then
			dragging = nil
			if key == "sfx" then
				Sfx.play("Hit") -- a sample at the level just set
			end
		end
	end)
end

local function bindToggle(row: Instance, key: string)
	local toggle = row:FindFirstChild("Toggle") :: GuiButton
	local on = toggle:FindFirstChild("On") :: GuiObject
	table.insert(refreshers, function()
		on.Visible = (values :: any)[key] == true
	end)
	toggle.Activated:Connect(function()
		change(key, not (values :: any)[key])
	end)
end

function Settings.init(gui: ScreenGui)
	local window = gui:FindFirstChild("SettingsWindow") :: Frame
	Menus.register(window)
	ListWindow.bindClose(window)
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("SettingsButton") :: GuiButton
	button.Activated:Connect(function()
		Menus.toggle(window)
	end)

	local rows = window:FindFirstChild("Rows") :: Frame
	bindSlider(rows:FindFirstChild("Music") :: Instance, "music")
	bindSlider(rows:FindFirstChild("SFX") :: Instance, "sfx")
	local auto = rows:FindFirstChild("AutoAttack") :: GuiObject
	local hint = rows:FindFirstChild("LockHint") :: GuiObject
	auto.Visible = Platform.isTouch()
	hint.Visible = not Platform.isTouch()
	bindToggle(auto, "autoAttack")
	bindToggle(hint, "lockHint")
	apply() -- defaults until the saved set arrives

	State.onChanged(function(snapshot)
		local saved = snapshot.settings
		-- only the first push carries news: after that the window is the authority
		if saved and not loaded then
			loaded = true
			values = table.clone(saved)
			apply()
		end
	end)
end

return Settings
