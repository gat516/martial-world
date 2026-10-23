--!strict
-- The death-save prompt (roadmap 1, "Force breakthrough becomes a death-save";
-- docs/ui/cultivation.md). Ready to wire: nothing calls it yet. When a blow
-- would kill the player and their bar is high enough, the server slows time and
-- the client asks DeathSave.prompt; the player holds (or taps) the big seal in
-- the middle of the screen to break through and survive.
--
--   DeathSave.prompt({ seconds = 4, hold = 0.6 }, function(accepted) ... end)
--   DeathSave.cancel()     -- the offer ended elsewhere (answers false)
--   DeathSave.isOpen()
--   DeathSave.preview()    -- sample prompt, prints the answer (client console)
--
-- Look: Cultivation.Canvas.DeathSave. A subtle red vignette (death_vignette)
-- fades in, the heartbeat ring beats behind the seal (two quick beats, a rest),
-- and a gold ring sweeps round the seal while it is held (two clipped halves of
-- hold_ring, each swept by a UIGradient). Letting go early drains it back.
-- Mouse, touch, Space/E and gamepad A all hold. No shift-lock needed.

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CultivationGui = require(script.Parent.CultivationGui)

export type Options = {
	seconds: number?, -- how long the offer stands before it answers false (default 4)
	hold: number?, -- seconds to hold the seal; 0 answers on a tap (default 0.6)
	title: string?, -- default "Break through to survive?"
	hint: string?, -- default "Hold to break through" ("Tap to break through" when hold is 0)
}

local VIGNETTE = 0.45 -- the vignette's transparency while open (subtle)
local BEAT = { 0.11, 0.13, 0.11, 0.45 } -- grow, settle, grow, rest (seconds)
local DRAIN = 2.5 -- progress per second lost after letting go early
local ACTION = "DeathSaveHold"

local DeathSave = {}

local token = 0
local answer: ((boolean) -> ())? = nil
local holding = 0 -- inputs currently holding the seal
local progress = 0
local stepper: RBXScriptConnection? = nil

local function parts()
	local root = CultivationGui.piece("DeathSave")
	local prompt = root:FindFirstChild("Prompt") :: Frame
	return root, prompt
end

local function setProgress(prompt: Frame, p: number)
	local ring = prompt:FindFirstChild("Progress") :: Frame;
	(((ring:FindFirstChild("Right") :: Frame):FindFirstChild("Ring") :: ImageLabel):FindFirstChild("Sweep") :: UIGradient).Rotation = 180 * math.clamp(p * 2, 0, 1);
	(((ring:FindFirstChild("Left") :: Frame):FindFirstChild("Ring") :: ImageLabel):FindFirstChild("Sweep") :: UIGradient).Rotation = 180 * math.clamp(p * 2 - 1, 0, 1)
end

local function heartbeat(prompt: Frame, mine: number)
	local pulse = prompt:FindFirstChild("Pulse") :: ImageLabel
	local base = pulse:GetAttribute("Base") :: UDim2? or pulse.Size
	pulse:SetAttribute("Base", base)
	task.spawn(function()
		while token == mine do
			for i, seconds in BEAT do
				if token ~= mine then
					break
				end
				local big = i == 1 or i == 3
				local grown = UDim2.fromOffset(base.X.Offset * 1.12, base.Y.Offset * 1.12)
				TweenService:Create(pulse, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = if big then grown else base,
					ImageTransparency = if big then 0.05 else 0.45,
				}):Play()
				task.wait(seconds)
			end
		end
		pulse.Size = base
	end)
end

local function finish(accepted: boolean)
	local reply = answer
	if not reply then
		return
	end
	answer = nil
	token += 1
	holding = 0
	if stepper then
		stepper:Disconnect()
		stepper = nil
	end
	ContextActionService:UnbindAction(ACTION)
	local root, prompt = parts()
	local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(root:FindFirstChild("Vignette") :: ImageLabel, out, { ImageTransparency = 1 }):Play()
	TweenService:Create(prompt:FindFirstChild("Device") :: UIScale, out, { Scale = (prompt:FindFirstChild("Device") :: UIScale).Scale * 0.9 }):Play()
	local mine = token
	task.delay(0.25, function()
		if token == mine then
			root.Visible = false
		end
	end)
	reply(accepted)
end

function DeathSave.isOpen(): boolean
	return answer ~= nil
end

function DeathSave.cancel()
	finish(false)
end

function DeathSave.prompt(options: Options?, onAnswer: (accepted: boolean) -> ())
	finish(false)
	local opts: Options = options or {}
	local hold = opts.hold or 0.6
	local seconds = opts.seconds or 4
	local root, prompt = parts()
	token += 1
	local mine = token
	answer = onAnswer
	holding = 0
	progress = 0
	setProgress(prompt, 0);
	(prompt:FindFirstChild("Title") :: TextLabel).Text = opts.title or "Break through to survive?";
	(prompt:FindFirstChild("Hint") :: TextLabel).Text = opts.hint or (if hold > 0 then "Hold to break through" else "Tap to break through")

	local device = prompt:FindFirstChild("Device") :: UIScale
	local size = device:GetAttribute("Base") :: number? or device.Scale
	device:SetAttribute("Base", size)
	local vignette = root:FindFirstChild("Vignette") :: ImageLabel
	vignette.ImageTransparency = 1
	device.Scale = size * 0.85
	root.Visible = true
	TweenService:Create(vignette, TweenInfo.new(0.3), { ImageTransparency = VIGNETTE }):Play()
	TweenService:Create(device, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = size }):Play()
	heartbeat(prompt, mine)

	local button = prompt:FindFirstChild("Button") :: ImageButton
	local press = button:FindFirstChild("Motion") :: UIScale
	local function down()
		if token ~= mine then
			return
		end
		holding += 1
		TweenService:Create(press, TweenInfo.new(0.08), { Scale = 0.94 }):Play()
		if hold <= 0 then
			finish(true)
		end
	end
	local function up()
		holding = math.max(0, holding - 1)
		if holding == 0 then
			TweenService:Create(press, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	local began = button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			down()
		end
	end)
	local ended = button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			up()
		end
	end)
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			down()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			up()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA)

	local opened = os.clock()
	stepper = RunService.RenderStepped:Connect(function(dt)
		if hold > 0 then
			progress = if holding > 0 then progress + dt / hold else math.max(0, progress - DRAIN * dt)
			setProgress(prompt, progress)
			if progress >= 1 then
				finish(true)
				return
			end
		end
		if os.clock() - opened >= seconds then
			finish(false)
		end
	end)
	task.spawn(function()
		while token == mine do
			task.wait(0.2)
		end
		began:Disconnect()
		ended:Disconnect()
		press.Scale = 1
	end)
end

function DeathSave.preview()
	DeathSave.prompt({ seconds = 6 }, function(accepted)
		print("DeathSave preview answered", accepted)
	end)
end

return DeathSave
