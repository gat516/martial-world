--!strict
-- "There's more below" on every scrolling list in the Hud: an ink fade over the
-- list's bottom edge and a small bobbing gold chevron (Hud.ScrollHint.Hint,
-- art in art/ui/draw_ui.py scroll). It shows only while the list has more
-- content below the fold, and goes once the player reaches the end or when
-- everything fits. The scroll bar itself is drawn art too (Top/Mid/BottomImage
-- on each ScrollingFrame, authored in the Hud).
--
-- Hints can't live inside a ScrollingFrame (they'd scroll with the canvas and
-- its UIListLayout would lay them out), so each is a clone of the template in
-- the Hud.ScrollHint layer, kept over its list's window every frame while the
-- list is on screen. The layer and its pieces sink no input.
--
-- ScrollHint.reveal scrolls a control inside a list into view (the onboarding
-- guide uses it to bring an in-window target on screen).

local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Motion)

local SLACK = 4 -- px of leftover canvas that doesn't count as "more"
local REVEAL = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ScrollHint = {}

type Entry = { list: ScrollingFrame, hint: Frame }

local gui: ScreenGui
local layer: Frame
local template: Frame
local entries: { Entry } = {}

-- The list and every frame above it are shown.
local function shown(obj: GuiObject): boolean
	if not gui.Enabled then
		return false
	end
	local node: Instance? = obj
	while node and node ~= gui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node == gui
end

local function moreBelow(list: ScrollingFrame): boolean
	local canvas = list.AbsoluteCanvasSize.Y
	local window = list.AbsoluteWindowSize.Y
	return canvas > window + SLACK and list.CanvasPosition.Y < canvas - window - SLACK
end

local function step()
	local origin = layer.AbsolutePosition
	for _, e in entries do
		local list, hint = e.list, e.hint
		local on = list.Parent ~= nil and list.AbsoluteSize.Y > 1 and shown(list) and moreBelow(list)
		if on then
			local window = list.AbsoluteWindowSize
			hint.Position = UDim2.fromOffset(list.AbsolutePosition.X - origin.X, list.AbsolutePosition.Y - origin.Y)
			hint.Size = UDim2.fromOffset(window.X, window.Y)
		end
		hint.Visible = on
	end
end

function ScrollHint.attach(list: ScrollingFrame)
	local hint = template:Clone()
	hint.Name = `Hint_{list.Name}`
	hint.Visible = false
	hint.Parent = layer
	local more = hint:FindFirstChild("More") :: GuiObject?
	if more then
		Motion.bob(more, 4)
	end
	table.insert(entries, { list = list, hint = hint })
end

-- Scroll obj's list (the nearest ScrollingFrame above it) so obj is fully in view.
function ScrollHint.reveal(obj: GuiObject)
	local list = obj:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not list then
		return
	end
	local top = obj.AbsolutePosition.Y - list.AbsolutePosition.Y
	local bottom = top + obj.AbsoluteSize.Y
	local window = list.AbsoluteWindowSize.Y
	local y = list.CanvasPosition.Y
	if top < 0 then
		y += top - 8
	elseif bottom > window then
		y += bottom - window + 8
	else
		return
	end
	local max = math.max(0, list.AbsoluteCanvasSize.Y - window)
	Motion.tween(list, { CanvasPosition = Vector2.new(list.CanvasPosition.X, math.clamp(y, 0, max)) }, REVEAL)
end

function ScrollHint.init(screenGui: ScreenGui)
	gui = screenGui
	layer = gui:FindFirstChild("ScrollHint") :: Frame
	template = layer:FindFirstChild("Hint") :: Frame
	template.Visible = false
	layer.Visible = true
	for _, inst in gui:GetDescendants() do
		if inst:IsA("ScrollingFrame") and inst.ScrollingDirection ~= Enum.ScrollingDirection.X then
			ScrollHint.attach(inst)
		end
	end
	RunService.RenderStepped:Connect(step)
end

return ScrollHint
