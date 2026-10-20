--!strict
-- Shared UI motion: short, snappy tweens (0.1-0.25s) so the HUD feels alive
-- without getting in the way. Scale effects use the "Motion" UIScale authored on
-- each animated frame and button in StarterGui.Hud; anything without one just
-- appears and disappears instantly.
--   Windows pop open and shrink away (Menus calls open/close).
--   Prompts (seat pills, Break Through, toast, elder line) pop in when shown.
--   Buttons swell slightly under a mouse and dip when pressed.
--   Bars ease to new values (Motion.tween on a fill's Size).

local TweenService = game:GetService("TweenService")

local Motion = {}

local OPEN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PULSE = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local HOVER_SCALE = 1.05
local PRESS_SCALE = 0.92
local PULSE_SCALE = 1.12

local EASE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local playing: { [Instance]: Tween } = {}
local closing: { [Instance]: number } = {} -- frame -> token of its pending close
local pulsing: { [Instance]: boolean } = {}

-- Tween inst's props, replacing whatever tween it was already running.
function Motion.tween(inst: Instance, props: { [string]: any }, info: TweenInfo?): Tween
	local old = playing[inst]
	if old then
		old:Cancel()
	end
	local tween = TweenService:Create(inst, info or HOVER, props)
	playing[inst] = tween
	tween.Completed:Once(function()
		if playing[inst] == tween then
			playing[inst] = nil
		end
	end)
	tween:Play()
	return tween
end

-- Ease a value change (bar fills and the like).
function Motion.ease(inst: Instance, props: { [string]: any }): Tween
	return Motion.tween(inst, props, EASE)
end

local function scaleOf(obj: Instance): UIScale?
	local scale = obj:FindFirstChild("Motion")
	return if scale and scale:IsA("UIScale") then scale else nil
end

local function popFrom(obj: GuiObject, from: number, info: TweenInfo)
	local scale = scaleOf(obj)
	if scale then
		scale.Scale = from
		Motion.tween(scale, { Scale = 1 }, info)
	end
end

-- Show a window with a small pop (and cancel a close still under way).
function Motion.open(frame: GuiObject)
	closing[frame] = nil
	frame.Visible = true
	popFrom(frame, 0.94, OPEN)
end

-- Shrink a window away, then hide it.
function Motion.close(frame: GuiObject)
	local scale = scaleOf(frame)
	if not scale or not frame.Visible then
		frame.Visible = false
		return
	end
	local token = (closing[frame] or 0) + 1
	closing[frame] = token
	Motion.tween(scale, { Scale = 0.94 }, CLOSE).Completed:Once(function()
		if closing[frame] == token then
			closing[frame] = nil
			frame.Visible = false
			scale.Scale = 1
		end
	end)
end

-- The pop a window plays when it becomes visible by any route (Menus).
function Motion.popWindow(frame: GuiObject)
	if not closing[frame] then
		popFrom(frame, 0.94, OPEN)
	end
end

-- Pop obj in whenever it's shown.
function Motion.appear(obj: GuiObject)
	obj:GetPropertyChangedSignal("Visible"):Connect(function()
		if obj.Visible then
			popFrom(obj, 0.8, POP)
		end
	end)
end

-- A gentle, endless swell drawing the eye to a button (onboarding).
function Motion.pulse(obj: GuiObject)
	local scale = scaleOf(obj)
	if scale then
		pulsing[scale] = true
		scale.Scale = 1
		Motion.tween(scale, { Scale = PULSE_SCALE }, PULSE)
	end
end

function Motion.stopPulse(obj: GuiObject)
	local scale = scaleOf(obj)
	if scale and pulsing[scale] then
		pulsing[scale] = nil
		Motion.tween(scale, { Scale = 1 }, HOVER)
	end
end

local function pointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

-- Hover and press feedback for one button.
local function bindButton(button: GuiButton)
	local scale = scaleOf(button)
	if not scale then
		return
	end
	local s = scale :: UIScale
	local hovered, pressed = false, false
	local function settle()
		if pulsing[s] then
			return
		end
		local target = if pressed then PRESS_SCALE elseif hovered then HOVER_SCALE else 1
		Motion.tween(s, { Scale = target }, if pressed then PRESS elseif target == 1 then RELEASE else HOVER)
	end
	button.MouseEnter:Connect(function()
		hovered = true
		settle()
	end)
	button.MouseLeave:Connect(function()
		hovered, pressed = false, false
		settle()
	end)
	button.InputBegan:Connect(function(input)
		if pointer(input) then
			pulsing[s] = nil -- a press ends any pulse
			pressed = true
			settle()
		end
	end)
	button.InputEnded:Connect(function(input)
		if pointer(input) then
			pressed = false
			if input.UserInputType == Enum.UserInputType.Touch then
				hovered = false -- touch has no hover to return to
			end
			settle()
		end
	end)
end

-- Press feedback for every button under root, including ones cloned in later.
function Motion.buttons(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") then
			bindButton(d)
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") then
			task.defer(bindButton, d) -- after its children are parented
		end
	end)
end

return Motion
