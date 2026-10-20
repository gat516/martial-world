--!strict
-- The slim bar shown while planting (Hud.PlantingBar), in the look of the build
-- placement controls: the seed (icon or colour), how many are left, whether the
-- spot under the pointer works, and Change seed / Done. It sits at the bottom
-- and registers with Menus, so the gameplay HUD steps aside while the screen
-- centre stays clear for aiming at the soil.
--
-- Planting owns the session: it calls show() to start or update and hide() to
-- end. Done (or Menus closing the bar for another window) calls callbacks.done;
-- Change seed hands the screen to the seed picker and calls callbacks.switch. If
-- the picker then closes without a pick (no show() follows), that also ends the
-- session through callbacks.done, so planting never runs without its bar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Items = require(ReplicatedStorage.Shared.Items)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Platform = require(script.Parent.Platform)

local GOOD_COLOR = Color3.fromRGB(150, 230, 170)
local BAD_COLOR = Color3.fromRGB(240, 120, 100)

export type Info = { herb: string, count: number, status: string, good: boolean }
export type Callbacks = { done: () -> (), switch: () -> () }

local PlantingBar = {}

local bar: Frame
local seedLabel: TextLabel
local status: TextLabel
local swatch: Frame
local icon: ImageLabel
local callbacks: Callbacks
local quiet = false -- closing by hide() or a seed switch, not by the player
local switching = false -- waiting for the seed picker to hand back a seed

local function close(silently: boolean)
	quiet = silently
	Menus.close(bar)
	quiet = false
end

function PlantingBar.show(info: Info)
	local herb = Herbs.Defs[info.herb]
	local item = Items.Defs[info.herb]
	switching = false
	swatch.BackgroundColor3 = if herb then herb.color else Color3.new(1, 1, 1)
	icon.Image = if item and item.icon then item.icon else ""
	swatch.BackgroundTransparency = if icon.Image ~= "" then 1 else 0
	local name = if herb then herb.name else info.herb
	seedLabel.Text = `{name} seeds · {info.count} left`
	status.Text = info.status
	status.TextColor3 = if info.good then GOOD_COLOR else BAD_COLOR
	if not bar.Visible then
		Menus.open(bar)
	end
end

function PlantingBar.hide()
	switching = false
	if bar.Visible then
		close(true)
	end
end

function PlantingBar.isShown(): boolean
	return bar.Visible
end

function PlantingBar.init(gui: ScreenGui, c: Callbacks)
	callbacks = c
	bar = gui:FindFirstChild("PlantingBar") :: Frame
	local info = bar:FindFirstChild("Info") :: Frame
	seedLabel = info:FindFirstChild("SeedLabel") :: TextLabel
	status = info:FindFirstChild("Status") :: TextLabel
	swatch = info:FindFirstChild("Swatch") :: Frame
	icon = swatch:FindFirstChild("Icon") :: ImageLabel
	local row = bar:FindFirstChild("Row") :: Frame
	local switchButton = row:FindFirstChild("SwitchButton") :: GuiButton
	local doneButton = row:FindFirstChild("DoneButton") :: GuiButton

	local touch = Platform.isTouch();
	(bar:FindFirstChild("Hint") :: TextLabel).Text = if touch then "Tap soil to plant" else "Click soil to plant  ·  Q to finish"
	for _, b in { switchButton, doneButton } do
		local key = b:FindFirstChild("Key") :: GuiObject?
		if key then
			key.Visible = not touch
		end
	end

	Menus.register(bar, {
		close = function()
			Motion.close(bar)
			if not quiet and not switching then
				callbacks.done()
			end
		end,
	})
	-- the seed picker closed without a pick: planting ends
	Menus.onChanged(function()
		if switching and not Menus.isOpen() and not bar.Visible then
			switching = false
			callbacks.done()
		end
	end)

	doneButton.Activated:Connect(function()
		close(true)
		callbacks.done()
	end)
	switchButton.Activated:Connect(function()
		switching = true
		callbacks.switch()
		-- nothing opened (no other seeds for this soil): keep planting
		if bar.Visible and Menus.isOpen(bar) then
			switching = false
		end
	end)
end

return PlantingBar
