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

-- An endless soft bob of `pixels` along Y from obj's authored position (scroll
-- hints). Call once; the tween runs while obj exists.
local BOB = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
function Motion.bob(obj: GuiObject, pixels: number)
	local base = obj.Position
	Motion.tween(obj, { Position = base + UDim2.fromOffset(0, pixels) }, BOB)
end

function Motion.stopPulse(obj: GuiObject)
	local scale = scaleOf(obj)
	if scale and pulsing[scale] then
		pulsing[scale] = nil
		Motion.tween(scale, { Scale = 1 }, HOVER)
	end
end

-- Fading a whole card in and out (world prompts). Each piece fades to its own
-- authored transparency, which is read once per root the first time it fades.
local FADE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE_PROPS = {
	ImageLabel = { "ImageTransparency" },
	ImageButton = { "ImageTransparency" },
	TextLabel = { "TextTransparency", "TextStrokeTransparency" },
	Frame = { "BackgroundTransparency" },
	UIStroke = { "Transparency" },
}
local authored: { [Instance]: { [Instance]: { [string]: number } } } = setmetatable({}, { __mode = "k" }) :: any

local function fadeTargets(root: Instance): { [Instance]: { [string]: number } }
	local known = authored[root]
	if known then
		return known
	end
	local found = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, inst in all do
		local props = FADE_PROPS[inst.ClassName]
		if props then
			local values = {}
			for _, prop in props do
				values[prop] = (inst :: any)[prop]
			end
			found[inst] = values
		end
	end
	authored[root] = found
	return found
end

-- Fade root in from nothing to its authored look, with a small pop.
function Motion.fadeIn(root: GuiObject)
	for inst, values in fadeTargets(root) do
		local target = inst :: any
		for prop in values do
			target[prop] = 1
		end
		TweenService:Create(inst, FADE_IN, values):Play()
	end
	popFrom(root, 0.9, POP)
end

-- Fade root out (shrinking a little); done runs once it's invisible.
function Motion.fadeOut(root: GuiObject, done: (() -> ())?)
	for inst, values in fadeTargets(root) do
		local to = {}
		for prop in values do
			to[prop] = 1
		end
		TweenService:Create(inst, FADE_OUT, to):Play()
	end
	local scale = scaleOf(root)
	if scale then
		Motion.tween(scale, { Scale = 0.94 }, FADE_OUT)
	end
	if done then
		task.delay(FADE_OUT.Time, done)
	end
end

-- Fading whole HUD regions away and back (the calm view while meditating).
-- Unlike fadeIn/fadeOut this reads each piece's transparency fresh every time,
-- so values scripts change at runtime (dimmed slots, hidden fills) survive: the
-- region fades to nothing, hides, and gets its real values back while hidden.
local CALM_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CALM_IN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CALM_PROPS = {
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	ImageButton = { "ImageTransparency", "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" },
	TextButton = { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
	UIStroke = { "Transparency" },
}
-- root -> the values it had when its fade away began (only while fading)
local fading: { [Instance]: { [Instance]: { [string]: number } } } = {}
local fadeTokens: { [Instance]: number } = {}
local calmTweens: { [Instance]: Tween } = {} -- own map, so bar eases keep running

local function calmTween(inst: Instance, props: { [string]: number }, info: TweenInfo)
	local old = calmTweens[inst]
	if old then
		old:Cancel()
	end
	local tween = TweenService:Create(inst, info, props)
	calmTweens[inst] = tween
	tween:Play()
end

local function snapshot(root: Instance): { [Instance]: { [string]: number } }
	local found = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, inst in all do
		local props = CALM_PROPS[inst.ClassName]
		if props then
			local values = {}
			for _, prop in props do
				values[prop] = (inst :: any)[prop]
			end
			found[inst] = values
		end
	end
	return found
end

local function restore(values: { [Instance]: { [string]: number } })
	for inst, props in values do
		local tween = calmTweens[inst]
		if tween then
			tween:Cancel()
			calmTweens[inst] = nil
		end
		for prop, value in props do
			(inst :: any)[prop] = value
		end
	end
end

-- Show or hide a HUD region; `fade` eases it instead of snapping.
function Motion.setShown(root: GuiObject, shown: boolean, fade: boolean?)
	local pending = fading[root]
	if pending and not shown and fade then
		-- already on its way out; a new token here would strand that fade (the
		-- region stays Visible at full transparency, and anything a script repaints
		-- shows through: the seclusion plaque's streak pips over open windows)
		return
	end
	local token = (fadeTokens[root] or 0) + 1
	fadeTokens[root] = token
	if shown then
		if pending then
			-- caught mid-fade: ease back to the values it had
			fading[root] = nil
			for inst, props in pending do
				calmTween(inst, props, CALM_IN)
			end
			root.Visible = true
		elseif not root.Visible then
			if fade then
				local values = snapshot(root)
				for inst, props in values do
					for prop in props do
						(inst :: any)[prop] = 1
					end
				end
				root.Visible = true
				for inst, props in values do
					calmTween(inst, props, CALM_IN)
				end
			else
				root.Visible = true
			end
		end
		return
	end
	if pending then -- hidden without a fade: cut the one under way short
		fading[root] = nil
		root.Visible = false
		restore(pending)
		return
	end
	if not root.Visible then
		return
	end
	if not fade then
		root.Visible = false
		return
	end
	local values = snapshot(root)
	fading[root] = values
	for inst, props in values do
		local to = {}
		for prop in props do
			to[prop] = 1
		end
		calmTween(inst, to, CALM_OUT)
	end
	task.delay(CALM_OUT.Time, function()
		if fadeTokens[root] == token and fading[root] == values then
			fading[root] = nil
			root.Visible = false
			restore(values)
		end
	end)
end

-- A quick dip and spring back, for a press that came from a key, not a pointer.
function Motion.tap(obj: GuiObject)
	local scale = scaleOf(obj)
	if scale then
		local s = scale :: UIScale
		Motion.tween(s, { Scale = PRESS_SCALE }, PRESS).Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				Motion.tween(s, { Scale = 1 }, RELEASE)
			end
		end)
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
