--!strict
-- Meridian Pulse. Acupoints light up in turn around the meridian, each with a
-- ring closing in on it; tap anywhere (or press Space) as the ring lands. Close
-- to the beat is Perfect, within the window is Good, and a beat let pass is a
-- Miss. Purple beats are impurities: hit them to purge them, and they don't
-- count toward accuracy. Taps with no beat near break the combo and count
-- against accuracy, so mashing doesn't pay.
--
-- Only the timing matters, so it plays with one thumb anywhere on the screen.
-- The timing window, beat interval and ring speed come from Config (Games.Pulse).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

local PATH_RADIUS = 0.42 -- of the field, matching its Path ring
local RING_START = 2.8 -- the approach ring starts this many times the note's size
local PERFECT_SHARE = 0.4 -- of the window that counts as Perfect
local GOOD_SCORE = 0.6 -- accuracy credit for a Good (Perfect is 1)
local STRAY_COST = 0.5 -- a tap with no beat near counts as this many missed beats
local LEAD_IN = 0.4 -- seconds after the count-in before the first ring lands, beyond its approach

local QI = Color3.fromRGB(200, 255, 230)
local IMPURE = Color3.fromRGB(190, 90, 220)
local IMPURE_FILL = Color3.fromRGB(70, 30, 90)
local PERFECT = Color3.fromRGB(255, 225, 140)
local GOOD = Color3.fromRGB(150, 245, 200)
local MISS = Color3.fromRGB(255, 110, 100)
local STRAY = Color3.fromRGB(200, 170, 165)

type Beat = { at: number, spot: UDim2, impure: boolean, note: Frame?, judged: boolean }

local Pulse = {}

Pulse.TITLE = "Meridian Pulse"
Pulse.HINT = "Tap anywhere as each ring closes on its point. Hit purple points to purge them."

function Pulse.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Pulse", info.difficulty)
	local window = math.max(0.06, tune.window)
	local field = stage:FindFirstChild("Field") :: Frame
	local core = field:FindFirstChild("Core") :: Frame
	local noteTemplate = field:FindFirstChild("NoteTemplate") :: Frame
	local judgeTemplate = field:FindFirstChild("JudgeTemplate") :: TextLabel

	-- the beat chart: steady beats stepping around the meridian, some impure
	local rng = Random.new(info.seed)
	local beats: { Beat } = {}
	local angle = rng:NextNumber(0, 2 * math.pi)
	local at = tune.approach + LEAD_IN
	while at <= info.duration - 0.3 do
		angle += rng:NextNumber(0.7, 1.3)
		local spot = UDim2.fromScale(0.5 + PATH_RADIUS * math.sin(angle), 0.5 - PATH_RADIUS * math.cos(angle))
		table.insert(beats, { at = at, spot = spot, impure = false, note = nil, judged = false })
		at += tune.interval
	end
	-- impurities never on the first two beats, and always leave some plain ones
	local candidates = {}
	for i = 3, #beats do
		table.insert(candidates, i)
	end
	local impureCount = math.min(info.impurities, math.max(0, #beats - 3))
	for _ = 1, impureCount do
		local pick = table.remove(candidates, rng:NextInteger(1, #candidates)) :: number
		beats[pick].impure = true
	end
	local plain = #beats - impureCount

	local t, credit, judged, strays, purged, combo = 0, 0, 0, 0, 0, 0
	local made: { Instance } = {}

	local function accuracy(): number
		return credit / math.max(1, judged + strays * STRAY_COST)
	end

	local function beatCore()
		core.Size = UDim2.fromScale(0.28, 0.28)
		TweenService:Create(core, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.24, 0.24),
		}):Play()
	end

	local function finish(beat: Beat, quality: number)
		beat.judged = true
		if beat.impure then
			if quality > 0 then
				purged += 1
				Feel.pop(field, beat.spot, IMPURE, 110)
				Feel.judge(judgeTemplate, beat.spot, "Purged", IMPURE)
				Feel.buzz(0.3, 0.08)
			else
				Feel.pop(field, beat.spot, MISS)
				Feel.judge(judgeTemplate, beat.spot, "Impure!", MISS)
				Feel.buzz(0.7, 0.15)
			end
		else
			judged += 1
			credit += quality
			local word, color = "Miss", MISS
			if quality >= 1 then
				word, color = "Perfect", PERFECT
			elseif quality > 0 then
				word, color = "Good", GOOD
			end
			Feel.judge(judgeTemplate, beat.spot, word, color)
			if quality > 0 then
				Feel.pop(field, beat.spot, color)
				beatCore()
			end
		end
		combo = if quality > 0 then combo + 1 else 0
		if beat.note then
			beat.note:Destroy()
			beat.note = nil
		end
	end

	local function tap()
		-- the earliest unjudged beat inside the window
		for _, beat in beats do
			if not beat.judged then
				local err = math.abs(t - beat.at)
				if err <= window then
					finish(beat, if err <= window * PERFECT_SHARE then 1 else GOOD_SCORE)
					return
				end
				if beat.at > t then
					break
				end
			end
		end
		strays += 1
		combo = 0
		-- an off-beat tap: the core flinches so the cost is felt, not just counted
		Feel.judge(judgeTemplate, UDim2.fromScale(0.5, 0.36), "Off beat", STRAY)
		core.Size = UDim2.fromScale(0.21, 0.21)
		TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.24, 0.24),
		}):Play()
	end

	ui.ready()
	local finished = false
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			if not finished then
				tap()
			end
		end
	end))

	ui.score.Text = "Accuracy 100%"
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		t += math.min(dt, 0.1)

		for _, beat in beats do
			if beat.judged then
				continue
			end
			local untilBeat = beat.at - t
			if untilBeat > tune.approach then
				break
			end
			if not beat.note then
				local note = noteTemplate:Clone()
				note.Name = "Note"
				note.Position = beat.spot
				note.Visible = true
				if beat.impure then
					note.BackgroundColor3 = IMPURE_FILL;
					(note:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = IMPURE;
					((note:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke).Color = IMPURE;
					(note:FindFirstChild("Dot") :: Frame).BackgroundColor3 = IMPURE
				end
				note.Parent = field
				table.insert(made, note)
				beat.note = note
			end
			local note = beat.note :: Frame
			local ring = note:FindFirstChild("Ring") :: Frame
			local closing = math.clamp(untilBeat / tune.approach, 0, 1)
			ring.Size = UDim2.fromScale(1 + (RING_START - 1) * closing, 1 + (RING_START - 1) * closing)
			note.BackgroundTransparency = 0.2 + 0.6 * closing;
			(ring:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 0.7 * closing
			if untilBeat < -window then
				finish(beat, 0)
			end
		end

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `Accuracy {math.floor(accuracy() * 100 + 0.5)}%`
		ui.flow.Text = if combo >= 3 then `Combo x{combo}` else ""
		if t >= info.duration then
			finished = true
		end
	end))

	while not finished do
		task.wait()
	end
	for _, c in connections do
		c:Disconnect()
	end
	ui.hold(function()
		for _, inst in made do
			inst:Destroy()
		end
		core.Size = UDim2.fromScale(0.24, 0.24)
	end)
	-- beats never reached (none, if the chart fits the run) count as misses
	for _, beat in beats do
		if not beat.judged and not beat.impure then
			judged += 1
		end
	end
	return if plain > 0 then accuracy() else 1, purged
end

return Pulse
