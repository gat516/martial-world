--!strict
-- Meridian Pulse. Acupoints light up in turn around the meridian, each with a
-- ring closing in on it; tap anywhere (or press Space) as the ring lands. Close
-- to the beat is Perfect, within the window is Good, and a beat let pass is a
-- Miss. Purple beats are impurities: hit them to purge them, and they don't
-- count toward accuracy. Taps with no beat near break the combo and count
-- against accuracy, so mashing doesn't pay.
--
-- A run is the server's number of levels, each a string of beats with a short
-- breath between; a level is cleared once its last beat has passed, and the run
-- ends after the last level. Each level's accuracy is scored on its own.
--
-- Only the timing matters, so it plays with one thumb anywhere on the screen.
-- The timing window, beat interval, ring speed and beats a level come from
-- Config (Games.Pulse).
-- Look: a faint bagua array plate (maze_array.png) under a gold meridian ring
-- (pulse_path.png) round the dantian seal (pulse_core.png, glowing on each
-- hit); beats are lacquered acupoints (mg_note.png, violet mg_note_impure.png)
-- that pop in, each with a glowing ring (mg_ring.png) closing on it.

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
local LEVEL_GAP = 1.2 -- extra seconds of rest between one level's last beat and the next one's first
local END_PAUSE = 0.5 -- seconds after the last beat before the run ends

local NOTE_IMPURE = "rbxassetid://72392262787490" -- mg_note_impure.png
local CORE_SIZE = 0.24 -- of the field, as authored
local POP_IN = 0.18 -- seconds a beat takes to pop in

local QI = Color3.fromRGB(200, 255, 230)
local IMPURE = Color3.fromRGB(190, 90, 220)
local PERFECT = Color3.fromRGB(255, 225, 140)
local GOOD = Color3.fromRGB(150, 245, 200)
local MISS = Color3.fromRGB(255, 110, 100)
local STRAY = Color3.fromRGB(200, 170, 165)

type Beat = { at: number, spot: UDim2, impure: boolean, level: number, note: ImageLabel?, born: number, judged: boolean }

local Pulse = {}

Pulse.TITLE = "Meridian Pulse"
Pulse.HINT = "Tap anywhere as each ring closes on its point. Hit purple points to purge them."

function Pulse.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Pulse", info.difficulty)
	local window = math.max(0.06, tune.window)
	local field = stage:FindFirstChild("Field") :: Frame
	local core = field:FindFirstChild("Core") :: ImageLabel
	local coreGlow = field:FindFirstChild("CoreGlow") :: ImageLabel
	local noteTemplate = field:FindFirstChild("NoteTemplate") :: ImageLabel
	local noteSize = noteTemplate.Size
	local judgeTemplate = field:FindFirstChild("JudgeTemplate") :: TextLabel

	-- the beat chart: each level a string of steady beats stepping around the
	-- meridian, some impure, with a breath between levels
	local rng = Random.new(info.seed)
	local levels = info.levels or 1
	local perLevel = math.max(4, math.floor(tune.beats + 0.5))
	local beats: { Beat } = {}
	local lastBeat: { number } = {} -- each level's last beat index
	local angle = rng:NextNumber(0, 2 * math.pi)
	local at = tune.approach + LEAD_IN
	for level = 1, levels do
		local first = #beats + 1
		for _ = 1, perLevel do
			angle += rng:NextNumber(0.7, 1.3)
			local spot = UDim2.fromScale(0.5 + PATH_RADIUS * math.sin(angle), 0.5 - PATH_RADIUS * math.cos(angle))
			table.insert(beats, { at = at, spot = spot, impure = false, level = level, note = nil, born = 0, judged = false })
			at += tune.interval
		end
		at += LEVEL_GAP
		lastBeat[level] = #beats
		-- impurities never on a level's first two beats, and always leave some plain ones
		local candidates = {}
		for i = first + 2, #beats do
			table.insert(candidates, i)
		end
		for _ = 1, math.min(info.impurities, perLevel - 3) do
			local pick = table.remove(candidates, rng:NextInteger(1, #candidates)) :: number
			beats[pick].impure = true
		end
	end

	-- per level: accuracy credit, plain beats judged, stray taps
	local credit, judged, strays = table.create(levels, 0), table.create(levels, 0), table.create(levels, 0)
	local t, purged, combo, cleared, total = 0, 0, 0, 0, 0 -- total: cleared levels' accuracy, summed
	local endAt: number? = nil
	local made: { Instance } = {}

	local function accuracy(level: number): number
		local count = judged[level] + strays[level] * STRAY_COST
		return if count > 0 then credit[level] / count else 1
	end

	-- the level being played: the earliest beat still to come
	local function current(): number
		for _, beat in beats do
			if not beat.judged then
				return beat.level
			end
		end
		return levels
	end

	-- the dantian swells and glows with a landed beat
	local function beatCore(color: Color3)
		core.Size = UDim2.fromScale(CORE_SIZE * 1.18, CORE_SIZE * 1.18)
		TweenService:Create(core, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(CORE_SIZE, CORE_SIZE),
		}):Play()
		coreGlow.ImageColor3 = color
		coreGlow.ImageTransparency = 0.15
		TweenService:Create(coreGlow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = 0.7,
		}):Play()
	end

	-- a judged beat flares out (hit) or sinks away (missed) instead of vanishing
	local function retire(note: ImageLabel, hit: boolean)
		local ring = note:FindFirstChild("Ring") :: ImageLabel
		ring.Visible = false
		local grow = if hit then 1.35 else 0.7
		TweenService:Create(note, TweenInfo.new(if hit then 0.15 else 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(noteSize.X.Scale * grow, 0, noteSize.Y.Scale * grow, 0),
			ImageTransparency = 1,
			ImageColor3 = if hit then Color3.new(1, 1, 1) else Color3.fromRGB(120, 120, 120),
		}):Play()
		task.delay(0.3, note.Destroy, note)
	end

	local function finish(beat: Beat, quality: number)
		beat.judged = true
		if beat.impure then
			if quality > 0 then
				purged += 1
				Feel.pop(field, beat.spot, IMPURE, 110)
				Feel.burst(field, beat.spot, IMPURE, 100)
				Feel.judge(judgeTemplate, beat.spot, "Purged", IMPURE)
				Feel.sound("Purge")
				Feel.buzz(0.3, 0.08)
			else
				Feel.pop(field, beat.spot, MISS)
				Feel.judge(judgeTemplate, beat.spot, "Impure!", MISS)
				Feel.sound("Thud")
				Feel.shake(field, 4, 0.2)
				Feel.buzz(0.7, 0.15)
			end
		else
			judged[beat.level] += 1
			credit[beat.level] += quality
			local word, color = "Miss", MISS
			if quality >= 1 then
				word, color = "Perfect", PERFECT
			elseif quality > 0 then
				word, color = "Good", GOOD
			end
			Feel.judge(judgeTemplate, beat.spot, word, color)
			if quality >= 1 then
				Feel.pop(field, beat.spot, color)
				Feel.burst(field, beat.spot, color, 100)
				Feel.sound("Perfect", 1 + 0.04 * math.min(combo, 10))
				beatCore(color)
			elseif quality > 0 then
				Feel.pop(field, beat.spot, color)
				Feel.sound("Tick", 1 + 0.04 * math.min(combo, 10))
				beatCore(color)
			else
				Feel.sound("Thud", 1.3)
			end
		end
		combo = if quality > 0 then combo + 1 else 0
		if beat.note then
			retire(beat.note, quality > 0)
			beat.note = nil
		end
		if beats[lastBeat[beat.level]] == beat then
			cleared += 1
			total += accuracy(beat.level)
			Feel.burst(field, UDim2.fromScale(0.5, 0.5), PERFECT, 220)
			Feel.sound("Clear")
			if cleared >= levels then
				endAt = t + END_PAUSE
			else
				local text = `Level {cleared + 1}`
				ui.flow.Text = text
				task.delay(LEVEL_GAP + 0.6, function()
					if ui.flow.Text == text then
						ui.flow.Text = ""
					end
				end)
			end
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
		strays[current()] += 1
		combo = 0
		-- an off-beat tap: the core flinches so the cost is felt, not just counted
		Feel.judge(judgeTemplate, UDim2.fromScale(0.5, 0.36), "Off beat", STRAY)
		Feel.sound("Thud", 1.5)
		core.Size = UDim2.fromScale(CORE_SIZE * 0.87, CORE_SIZE * 0.87)
		TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(CORE_SIZE, CORE_SIZE),
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
				ui.tapped()
			end
		end
	end))

	local function scoreText(): string
		local level = current()
		return `Level {level} / {levels}   {math.floor(accuracy(level) * 100 + 0.5)}%`
	end
	ui.score.Text = scoreText()
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
					note.Image = NOTE_IMPURE;
					(note:FindFirstChild("Ring") :: ImageLabel).ImageColor3 = IMPURE
				end
				note.Parent = field
				table.insert(made, note)
				beat.note = note
				beat.born = t
			end
			local note = beat.note :: ImageLabel
			local ring = note:FindFirstChild("Ring") :: ImageLabel
			local closing = math.clamp(untilBeat / tune.approach, 0, 1)
			ring.Size = UDim2.fromScale(1.1 + (RING_START - 1.1) * closing, 1.1 + (RING_START - 1.1) * closing)
			ring.ImageTransparency = 0.75 * closing
			-- pops in (a little overshoot), then sits half-faded until its ring nears
			local age = math.clamp((t - beat.born) / POP_IN, 0, 1)
			local grow = 0.5 + 0.5 * age + 0.15 * math.sin(age * math.pi)
			note.Size = UDim2.new(noteSize.X.Scale * grow, 0, noteSize.Y.Scale * grow, 0)
			note.ImageTransparency = 0.45 * closing
			if untilBeat < -window then
				finish(beat, 0)
			end
		end

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = scoreText()
		if combo >= 3 then
			ui.flow.Text = `Combo x{combo}`
		elseif string.find(ui.flow.Text, "Combo") then
			ui.flow.Text = ""
		end
		if t >= info.duration or (endAt and t >= endAt) or ui.quit() then
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
		core.Size = UDim2.fromScale(CORE_SIZE, CORE_SIZE)
		coreGlow.ImageTransparency = 0.7
	end)
	return total / math.max(1, cleared), purged, cleared
end

return Pulse
