--!strict
-- Shared plumbing for the sect, quest, Hall and lineage screens
-- (StarterGui.Sect, assets/Sect.rbxmx; docs/ui/sect-board.md and
-- docs/ui/halls-masters.md). Finds the GUI on first use, fits its canvas,
-- registers each window with Menus (one menu at a time, the HUD steps aside),
-- binds its close seal and gives every button the shared hover and press.
--
-- Every window is authored once at the phone baseline (844x390, the 720x350
-- window sits inside it) and scaled by UiScale: about 1.0 on a landscape phone,
-- capped at 1.5 on a 1080p desktop. The phone layout is the native one, so its
-- text sizes (12-19 px) are what a phone shows.

local Players = game:GetService("Players")

local Menus = require(script.Parent.Parent.Menus)
local Motion = require(script.Parent.Parent.Motion)
local UiScale = require(script.Parent.Parent.UiScale)

local Ui = {}

local canvas: Frame? = nil
local registered: { [GuiObject]: boolean } = {}

-- The Sect canvas (fitted on first use).
function Ui.canvas(): Frame
	if canvas then
		return canvas
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild("Sect") :: ScreenGui
	local c = gui:WaitForChild("Canvas") :: Frame
	UiScale.fit(c, { base = UiScale.PHONE, max = 1.5 })
	Motion.buttons(c)
	canvas = c
	return c
end

-- Edit-mode previews (a Studio harness without a PlayerGui): use this canvas.
function Ui.useCanvas(c: Frame)
	canvas = c
end

-- A template from Canvas.Templates, cloned.
function Ui.clone(name: string): any
	local templates = Ui.canvas():FindFirstChild("Templates") :: Frame
	return (templates:FindFirstChild(name) :: GuiObject):Clone()
end

-- A window (Board, QuestLog, HallCrest, Hall, Lineage, Ceremony), registered
-- with Menus and its close seal bound the first time it's asked for.
function Ui.window(name: string, onClose: (() -> ())?): Frame
	local window = Ui.canvas():FindFirstChild(name) :: Frame
	if not registered[window] then
		registered[window] = true
		Menus.register(window)
		local close = window:FindFirstChild("Close") :: GuiButton?
		if close then
			close.Activated:Connect(function()
				Menus.close(window)
			end)
		end
		if onClose then
			window:GetPropertyChangedSignal("Visible"):Connect(function()
				if not window.Visible then
					onClose()
				end
			end)
		end
	end
	return window
end

function Ui.open(window: Frame)
	Menus.open(window)
end

function Ui.close(window: Frame)
	Menus.close(window)
end

-- Destroy the rows a fill made (children named "Row").
function Ui.clearRows(parent: Instance)
	for _, child in parent:GetChildren() do
		if child.Name == "Row" then
			child:Destroy()
		end
	end
end

-- Size a ScrollingFrame's canvas to its layout (AutomaticCanvasSize misses
-- rows that size themselves). The layout reports real pixels; the canvas is in
-- the scaled space, so divide by the fit scale.
function Ui.fitCanvas(scroll: ScrollingFrame)
	local layout = scroll:FindFirstChildWhichIsA("UIGridStyleLayout") :: UIGridStyleLayout
	local padding = scroll:FindFirstChildWhichIsA("UIPadding")
	local function apply()
		local scale = (Ui.canvas():FindFirstChild("UiScale") :: UIScale).Scale
		local extra = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
		scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / scale + extra)
	end
	if not scroll:GetAttribute("Fitted") then
		scroll:SetAttribute("Fitted", true)
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(apply)
	end
	apply()
end

-- Count a number label up (or down) to a value, with thousands separators.
local counting: { [TextLabel]: number } = {}
function Ui.formatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Ui.countTo(label: TextLabel, from: number, to: number, seconds: number?)
	local token = (counting[label] or 0) + 1
	counting[label] = token
	local duration = seconds or 0.6
	local start = os.clock()
	task.spawn(function()
		while counting[label] == token do
			local t = math.min((os.clock() - start) / duration, 1)
			local eased = 1 - (1 - t) ^ 3
			label.Text = Ui.formatNumber(from + (to - from) * eased)
			if t >= 1 then
				break
			end
			task.wait()
		end
	end)
end

return Ui
