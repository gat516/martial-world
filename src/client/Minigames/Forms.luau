--!strict
-- Weapon Forms, the Practice Dao drill (never a circulation run: weight 0).
-- Numbered strike points pop up anywhere on the field, each with a ring closing
-- in on it; tap the point itself as its ring lands. Points come in flowing
-- strings that jump across the field and restart their count after each string,
-- with the odd quick double, so several are often up at once. Close to the beat
-- is Perfect, within the window is Good, and a point let pass is a Miss. Purple
-- points are bad habits: strike them to purge them; they don't count toward
-- accuracy. A tap on empty field, or on a point well before its beat, breaks
-- the combo and counts against accuracy.
--
-- Touch and mouse aim with the tap; Space/Z/X strike at the mouse; a gamepad's
-- A strikes whichever point is due, wherever it is. Window, spacing, ring speed
-- and jump distance come from Config (Games.Forms). Over the field the mouse
-- shows as the qi pointer, so aim is exact.
-- Look: the same lacquered points and closing rings as Meridian Pulse
-- (mg_note.png / mg_note_impure.png, mg_ring.png) on a scroll panel over a faint
-- ink-wash landscape (field_wash.png); hits flare out, misses sink away.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

local RING_START = 2.8 -- the approach ring starts this many times the point's size
local PERFECT_SHARE = 0.4 -- of the window that counts as Perfect
local GOOD_SCORE = 0.6 -- accuracy credit for a Good (Perfect is 1)
local STRAY_COST = 0.5 -- a stray tap counts as this many missed points
local LEAD_IN = 0.4 -- seconds after the count-in before the first ring lands, beyond its approach
local HIT_SLACK = 1.3 -- a tap this many radii from a point's centre still lands on it
local STRING = { 3, 6 } -- points per string before the count restarts
local BREATHER = 0.5 -- extra share of an interval between strings
local DOUBLE_CHANCE = 0.2 -- a point that follows its last at half the interval, close by
local TURN = 1.2 -- radians a string may bend per point

local NOTE_IMPURE = "rbxassetid://72392262787490" -- mg_note_impure.png
local POP_IN = 0.18 -- seconds a point takes to pop in

local IMPURE = Color3.fromRGB(190, 90, 220)
local PERFECT = Color3.fromRGB(255, 225, 140)
local GOOD = Color3.fromRGB(150, 245, 200)
local MISS = Color3.fromRGB(255, 110, 100)
local STRAY = Color3.fromRGB(200, 170, 165)

type Beat = { at: number, spot: UDim2, px: Vector2, number: number, impure: boolean, note: ImageLabel?, born: number, judged: boolean }

local Forms = {}

Forms.TITLE = "Weapon Forms"
Forms.HINT = "Click each point as its ring closes. Strike purple points to clear bad habits."
Forms.TOUCH_HINT = "Tap each point as its ring closes. Strike purple points to clear bad habits."

-- The chart: strings of points that flow across the field (field pixels), each
-- clear of any point still up when it appears.
-- The Field is already inset by a point's radius inside its backdrop, so
-- centres may use all of it.
local function chart(rng: Random, tune: { [string]: number }, duration: number, size: Vector2, radius: number): { Beat }
	local lo, hi = Vector2.zero, size
	local function inside(p: Vector2): boolean
		return p.X >= lo.X and p.X <= hi.X and p.Y >= lo.Y and p.Y <= hi.Y
	end
	local function anywhere(): Vector2
		return Vector2.new(rng:NextNumber(lo.X, hi.X), rng:NextNumber(lo.Y, hi.Y))
	end

	local beats: { Beat } = {}
	local function clear(p: Vector2, at: number): boolean
		for i = #beats, 1, -1 do
			local other = beats[i]
			if at - other.at > tune.approach + 0.2 then
				break
			end
			if (other.px - p).Magnitude < radius * 2.3 then
				return false
			end
		end
		return true
	end

	-- the longer side: a phone's landscape field is only a few points tall
	local reach = tune.jump * math.max(size.X, size.Y)
	local at = tune.approach + LEAD_IN
	local heading = rng:NextNumber(0, 2 * math.pi)
	local left, number = rng:NextInteger(STRING[1], STRING[2]), 0
	local stretch = 1 -- the next jump's length, as a share of reach
	local prev: Vector2? = nil
	while at <= duration - 0.3 do
		local spot: Vector2? = nil
		if prev then
			for try = 1, 12 do
				-- bend gently at first, then take any direction that fits
				local turn = if try <= 4 then rng:NextNumber(-TURN, TURN) else rng:NextNumber(-math.pi, math.pi)
				local p = prev + Vector2.new(math.cos(heading + turn), math.sin(heading + turn)) * reach * stretch * rng:NextNumber(0.75, 1.25)
				if inside(p) and clear(p, at) then
					spot, heading = p, heading + turn
					break
				end
			end
		end
		if not spot then
			for _ = 1, 12 do
				local p = anywhere()
				if clear(p, at) then
					spot = p
					break
				end
			end
		end
		local p = spot or anywhere()
		if prev and (p - prev).Magnitude > 1 then
			local d = p - prev
			heading = math.atan2(d.Y, d.X)
		end
		number += 1
		table.insert(beats, {
			at = at,
			spot = UDim2.fromScale(p.X / size.X, p.Y / size.Y),
			px = p,
			number = number,
			impure = false,
			note = nil,
			born = 0,
			judged = false,
		})
		prev = p
		left -= 1
		if left <= 0 then
			-- a new string: count from 1, a breath, and a long jump
			left, number = rng:NextInteger(STRING[1], STRING[2]), 0
			at += tune.interval * (1 + BREATHER)
			stretch = 1.6
		elseif rng:NextNumber() < DOUBLE_CHANCE then
			at += tune.interval * 0.5
			stretch = 0.45
		else
			at += tune.interval
			stretch = 1
		end
	end
	return beats
end

function Forms.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Forms", info.difficulty)
	local window = math.max(0.06, tune.window)
	local field = stage:FindFirstChild("Field") :: Frame
	local noteTemplate = field:FindFirstChild("NoteTemplate") :: ImageLabel
	local noteSize = noteTemplate.Size
	local judgeTemplate = field:FindFirstChild("JudgeTemplate") :: TextLabel

	local size = field.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		size = Vector2.new(600, 400)
	end
	local radius = noteTemplate.AbsoluteSize.X / 2
	if radius < 1 then
		radius = 0.07 * math.min(size.X, size.Y)
	end

	local rng = Random.new(info.seed)
	local beats = chart(rng, tune, info.duration, size, radius)
	-- impurities never on the first two points, and always leave some plain ones
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

	-- a judged point flares out (hit) or sinks away (missed) instead of vanishing
	local function retire(note: ImageLabel, hit: boolean)
		(note:FindFirstChild("Ring") :: ImageLabel).Visible = false;
		(note:FindFirstChild("Number") :: TextLabel).Visible = false
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
				Feel.judge(judgeTemplate, beat.spot, "Bad habit!", MISS)
				Feel.sound("Thud")
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
			if quality >= 1 then
				Feel.pop(field, beat.spot, color)
				Feel.burst(field, beat.spot, color, 110)
				Feel.sound("Perfect", 1 + 0.04 * math.min(combo, 10))
			elseif quality > 0 then
				Feel.pop(field, beat.spot, color)
				Feel.sound("Tick", 1 + 0.04 * math.min(combo, 10))
			else
				Feel.sound("Thud", 1.3)
			end
		end
		combo = if quality > 0 then combo + 1 else 0
		if beat.note then
			retire(beat.note, quality > 0)
			beat.note = nil
		end
	end

	local function stray(at: UDim2, word: string)
		strays += 1
		combo = 0
		Feel.judge(judgeTemplate, at, word, STRAY)
		Feel.pop(field, at, STRAY, 40)
		Feel.sound("Thud", 1.5)
	end

	-- A strike at a screen point (GUI space), or at whatever is due (nil: gamepad).
	local function tap(pos: Vector2?)
		local target: Beat? = nil
		for _, beat in beats do
			if beat.judged or not beat.note then
				continue
			end
			if pos then
				local note = beat.note :: ImageLabel
				local centre = note.AbsolutePosition + note.AbsoluteSize / 2
				if (pos - centre).Magnitude <= note.AbsoluteSize.X / 2 * HIT_SLACK then
					target = beat
					break
				end
			elseif math.abs(t - beat.at) <= window then
				target = beat
				break
			end
		end
		local at = if pos
			then UDim2.fromScale((pos.X - field.AbsolutePosition.X) / size.X, (pos.Y - field.AbsolutePosition.Y) / size.Y)
			else UDim2.fromScale(0.5, 0.5)
		if not target then
			stray(at, "Off form")
			return
		end
		local err = math.abs(t - target.at)
		if err <= window then
			finish(target, if err <= window * PERFECT_SHARE then 1 else GOOD_SCORE)
		else
			-- on the point but well before its ring lands
			stray(target.spot, "Early")
		end
	end

	ui.ready()
	local finished = false
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if finished then
			return
		end
		local kind, key = input.UserInputType, input.KeyCode
		local pos: Vector2? = nil
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			pos = Vector2.new(input.Position.X, input.Position.Y)
		elseif key == Enum.KeyCode.Space or key == Enum.KeyCode.Z or key == Enum.KeyCode.X then
			pos = Feel.mouse()
		elseif key ~= Enum.KeyCode.ButtonA then
			return
		end
		size = field.AbsoluteSize -- the field may have resized (a phone turned)
		tap(pos)
		ui.tapped()
	end))

	local pointer = Feel.pointer(stage:FindFirstChild("Backdrop") :: GuiObject, "qi")
	ui.score.Text = "Accuracy 100%"
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		t += math.min(dt, 0.1)
		pointer.step()

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
				note.Visible = true;
				(note:FindFirstChild("Number") :: TextLabel).Text = tostring(beat.number)
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
			note.ImageTransparency = 0.45 * closing;
			(note:FindFirstChild("Number") :: TextLabel).TextTransparency = 0.6 * closing
			if untilBeat < -window then
				finish(beat, 0)
			end
		end

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `Accuracy {math.floor(accuracy() * 100 + 0.5)}%`
		ui.flow.Text = if combo >= 3 then `Combo x{combo}` else ""
		if t >= info.duration or ui.quit() then
			finished = true
		end
	end))

	while not finished do
		task.wait()
	end
	for _, c in connections do
		c:Disconnect()
	end
	pointer.stop()
	ui.hold(function()
		for _, inst in made do
			inst:Destroy()
		end
	end)
	-- points never reached (none, if the chart fits the run) count as misses
	for _, beat in beats do
		if not beat.judged and not beat.impure then
			judged += 1
		end
	end
	return if plain > 0 then accuracy() else 1, purged
end

return Forms
