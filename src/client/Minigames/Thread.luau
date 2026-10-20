--!strict
-- Thread the Meridian. A bead of qi must travel a winding meridian without
-- touching its walls, level after level, each one narrower and twistier. Drag
-- anywhere to steer it (it moves with your thumb, not under it), or hold
-- WASD / the arrows. With a mouse the cursor locks onto the bead: put the cursor
-- on it to take hold and the bead follows the cursor exactly (outrun it, or
-- scatter, and you must put the cursor back on the bead). Touch a wall and the qi scatters back to the last
-- acupoint you lit. Purple impurities hug the walls: brush through one to purge
-- it, if you dare. Accuracy is levels cleared (plus how far along the current
-- one) against the run's par.
--
-- Channel width, bends and par seconds per level come from Config (Games.Thread).
-- Lengths here are in field heights; the field keeps a fixed aspect ratio.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Feel = require(script.Parent.Feel)

local ASPECT = 1.6 -- field width / height, as authored (UIAspectRatioConstraint)
local BEAD_RADIUS = 0.018
local WALL = 0.012 -- wall thickness drawn around the channel
local NARROW = 0.88 -- each level's channel is this much of the last one's width
local MIN_HALF_WIDTH = 0.032
local MAX_BENDS = 9
local MAX_SPEED = 1.4 -- field heights per second the bead can travel
local KEY_SPEED = 0.55
local STEP = 0.006 -- collision sub-step
local SCATTER_SECONDS = 0.45 -- frozen after touching a wall
local IMPURITY_RADIUS = 0.016
local NEXT_PAUSE = 0.35
local GRAB_RADIUS = 0.05 -- the cursor must be this close to the bead to take hold of it
local LOSE_RADIUS = 0.09 -- ...and outrunning the bead by this much lets go

local QI = Color3.fromRGB(200, 255, 230)
local IMPURE = Color3.fromRGB(220, 160, 255)
local JOLT = Color3.fromRGB(255, 110, 100)
local LIT = Color3.fromRGB(255, 225, 140)

type Level = {
	points: { Vector2 },
	cum: { number }, -- path length up to each point
	length: number,
	half: number, -- channel half-width
}

local Thread = {}

Thread.TITLE = "Thread the Meridian"
Thread.HINT = "Put your cursor on the qi and guide it along the meridian without touching the walls. Brush purple impurities to purge them."

local function toUDim(p: Vector2): UDim2
	return UDim2.fromScale(p.X / ASPECT, p.Y)
end

-- A zigzag from the left of the field to the right, alternating up and down.
local function generate(level: number, bends: number, half: number, rng: Random): Level
	local count = math.min(MAX_BENDS, bends + level - 1)
	local margin = half + WALL + 0.05
	local points = { Vector2.new(margin + 0.04, rng:NextNumber(0.3, 0.7)) }
	local right = ASPECT - margin - 0.04
	local sign = if rng:NextNumber() < 0.5 then 1 else -1
	for i = 1, count + 1 do
		local x = points[1].X + (right - points[1].X) * i / (count + 1)
		local prev = points[#points].Y
		local y = prev + sign * rng:NextNumber(0.25, 0.6)
		if y < margin or y > 1 - margin then
			y = prev - sign * rng:NextNumber(0.25, 0.6)
		end
		y = math.clamp(y, margin, 1 - margin)
		sign = if y > prev then -1 else 1
		table.insert(points, Vector2.new(x, y))
	end
	local cum = { 0 }
	for i = 2, #points do
		cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
	end
	return { points = points, cum = cum, length = cum[#cum], half = half }
end

-- Distance from p to the path, and how far along the path its nearest point is.
local function nearest(level: Level, p: Vector2): (number, number)
	local best, along = math.huge, 0
	local points = level.points
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		local f = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		local d = (p - (a + ab * f)).Magnitude
		if d < best then
			best = d
			along = level.cum[i] + (level.cum[i + 1] - level.cum[i]) * f
		end
	end
	return best, along
end

local function pointAt(level: Level, s: number): (Vector2, Vector2)
	local points = level.points
	for i = 1, #points - 1 do
		if s <= level.cum[i + 1] or i == #points - 1 then
			local a, b = points[i], points[i + 1]
			local f = math.clamp((s - level.cum[i]) / (level.cum[i + 1] - level.cum[i]), 0, 1)
			return a:Lerp(b, f), (b - a).Unit
		end
	end
	return points[1], Vector2.new(1, 0)
end

function Thread.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Thread", info.difficulty)
	local goal = math.max(1, info.duration / math.max(1, tune.par))
	local field = stage:FindFirstChild("Field") :: Frame
	local wallTemplate = field:FindFirstChild("WallTemplate") :: Frame
	local wallJointTemplate = field:FindFirstChild("WallJointTemplate") :: Frame
	local channelTemplate = field:FindFirstChild("ChannelTemplate") :: Frame
	local channelJointTemplate = field:FindFirstChild("ChannelJointTemplate") :: Frame
	local acupointTemplate = field:FindFirstChild("AcupointTemplate") :: Frame
	local impurityTemplate = field:FindFirstChild("ImpurityTemplate") :: Frame
	local bead = field:FindFirstChild("Bead") :: Frame
	local goalMark = field:FindFirstChild("Goal") :: Frame
	local rng = Random.new(info.seed)

	local made: { Instance } = {}
	local function clear()
		for _, inst in made do
			inst:Destroy()
		end
		table.clear(made)
	end
	local function place(template: Frame, at: Vector2, width: number, height: number, rotation: number?): Frame
		local frame = template:Clone()
		frame.Position = toUDim(at)
		frame.Size = UDim2.fromScale(width / ASPECT, height)
		frame.Rotation = rotation or 0
		frame.Visible = true
		frame.Parent = field
		table.insert(made, frame)
		return frame
	end

	local levelIndex = 0
	local level: Level
	local acupoints: { Frame } = {}
	local impurities: { { at: Vector2, frame: Frame } } = {}
	local impuritiesLeft = info.impurities
	local levelsLeft = math.ceil(goal)
	local pos = Vector2.zero
	local checkpoint = 1 -- index into level.points
	local best = 0 -- furthest along the current level

	local function newLevel()
		clear()
		table.clear(acupoints)
		table.clear(impurities)
		levelIndex += 1
		local half = math.max(MIN_HALF_WIDTH, tune.width * NARROW ^ (levelIndex - 1))
		level = generate(levelIndex, math.floor(tune.bends + 0.5), half, rng)
		local points = level.points
		-- the wall layer under the channel layer reads as one outlined tube
		local function tube(segment: Frame, joint: Frame, h: number)
			for i = 1, #points do
				place(joint, points[i], h * 2, h * 2)
				if i < #points then
					local a, b = points[i], points[i + 1]
					local d = b - a
					place(segment, (a + b) / 2, d.Magnitude, h * 2, math.deg(math.atan2(d.Y, d.X)))
				end
			end
		end
		tube(wallTemplate, wallJointTemplate, half + WALL)
		tube(channelTemplate, channelJointTemplate, half)
		for i = 2, #points - 1 do
			acupoints[i] = place(acupointTemplate, points[i], half * 0.7, half * 0.7)
		end
		local count = math.ceil(impuritiesLeft / math.max(1, levelsLeft))
		levelsLeft -= 1
		for i = 1, math.min(count, impuritiesLeft) do
			local s = level.length * (i / (count + 1)) * rng:NextNumber(0.85, 1.15)
			local at, dir = pointAt(level, s)
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			at += Vector2.new(-dir.Y, dir.X) * side * (half - BEAD_RADIUS) * 0.8
			local frame = place(impurityTemplate, at, IMPURITY_RADIUS * 2, IMPURITY_RADIUS * 2)
			table.insert(impurities, { at = at, frame = frame })
			impuritiesLeft -= 1
		end
		goalMark.Position = toUDim(points[#points])
		goalMark.Size = UDim2.fromScale(half * 1.6 / ASPECT, half * 1.6)
		goalMark.Visible = true
		bead.Size = UDim2.fromScale(BEAD_RADIUS * 2 / ASPECT, BEAD_RADIUS * 2)
		bead.Visible = true
		pos = points[1]
		checkpoint = 1
		best = 0
	end

	local t, cleared, purged, streak = 0, 0, 0, 0
	local frozenUntil = 0
	local joltUntil = 0
	local nextLevelAt: number? = nil
	local pending = Vector2.zero -- drag movement not yet applied, in field heights
	local grabbed = false -- the mouse cursor is holding the bead

	local function scatter()
		Feel.pop(field, toUDim(pos), JOLT)
		Feel.buzz(0.7, 0.15)
		pos = level.points[checkpoint]
		best = level.cum[checkpoint]
		frozenUntil = t + SCATTER_SECONDS
		joltUntil = frozenUntil
		streak = 0
		pending = Vector2.zero
		grabbed = false
	end

	-- Moves the bead toward pos + delta in small steps, stopping at a wall.
	local function move(delta: Vector2)
		local steps = math.max(1, math.ceil(delta.Magnitude / STEP))
		for _ = 1, steps do
			local next = pos + delta / steps
			local d, along = nearest(level, next)
			if d > level.half - BEAD_RADIUS then
				scatter()
				return
			end
			pos = next
			best = math.max(best, along)
			for i = checkpoint + 1, #level.points - 1 do
				if best >= level.cum[i] then
					checkpoint = i
					streak += 1
					acupoints[i].BackgroundColor3 = LIT
					Feel.pop(field, toUDim(level.points[i]), LIT, 60)
				end
			end
			for i = #impurities, 1, -1 do
				local imp = impurities[i]
				if (imp.at - pos).Magnitude <= BEAD_RADIUS + IMPURITY_RADIUS then
					purged += 1
					Feel.pop(field, toUDim(imp.at), IMPURE)
					Feel.buzz(0.3, 0.08)
					imp.frame:Destroy()
					table.remove(impurities, i)
				end
			end
			if (pos - level.points[#level.points]).Magnitude <= level.half * 0.6 then
				cleared += 1
				Feel.pop(field, toUDim(pos), LIT, 140)
				Feel.buzz(0.5, 0.12)
				frozenUntil = math.huge
				nextLevelAt = t + NEXT_PAUSE
				pending = Vector2.zero
				ui.flow.Text = `Meridian {cleared} cleared`
				task.delay(NEXT_PAUSE + 0.6, function()
					ui.flow.Text = ""
				end)
				return
			end
		end
	end

	local touches: { [InputObject]: Vector3 } = {}
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touches[input] = input.Position
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		local from: Vector3?
		if input.UserInputType == Enum.UserInputType.Touch then
			from = touches[input]
			if from then
				touches[input] = input.Position
			end
		end
		if from and t >= frozenUntil then
			local delta = input.Position - from
			pending += Vector2.new(delta.X, delta.Y) / math.max(1, field.AbsoluteSize.Y)
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		touches[input] = nil
	end))

	local function keyAxis(): Vector2
		local x, y = 0, 0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			x -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			x += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			y -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			y += 1
		end
		local v = Vector2.new(x, y)
		return if v.Magnitude > 0 then v.Unit else v
	end

	-- the mouse cursor in field coordinates (field heights from its top-left)
	local function cursor(): Vector2
		local m = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		return (m - field.AbsolutePosition) / math.max(1, field.AbsoluteSize.Y)
	end

	newLevel()
	local finished = false
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		dt = math.min(dt, 0.1)
		t += dt

		local due = nextLevelAt
		if due and t >= due then
			nextLevelAt = nil
			frozenUntil = 0
			newLevel()
		end
		if t >= frozenUntil then
			-- a flick can't fling the bead: it travels at most MAX_SPEED, and drag
			-- beyond that is dropped rather than saved up
			local delta = pending + keyAxis() * KEY_SPEED * dt
			pending = Vector2.zero
			if next(touches) == nil and UserInputService.MouseEnabled then
				local to = cursor() - pos
				if not grabbed and to.Magnitude <= GRAB_RADIUS then
					grabbed = true
				end
				if grabbed then
					if to.Magnitude > LOSE_RADIUS then
						grabbed = false
					else
						delta += to
					end
				end
			end
			local limit = MAX_SPEED * dt
			if delta.Magnitude > limit then
				delta = delta.Unit * limit
			end
			if delta.Magnitude > 0 then
				move(delta)
			end
		else
			pending = Vector2.zero
		end
		bead.Position = toUDim(pos)
		bead.BackgroundColor3 = if t < joltUntil then JOLT elseif nextLevelAt then LIT else QI

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `Meridians {cleared} / {math.ceil(goal)}`
		if ui.flow.Text == "" or string.find(ui.flow.Text, "Unbroken") then
			ui.flow.Text = if streak >= 2 then `Unbroken x{streak}` else ""
		end
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
	-- partial credit for how far along the current level you got
	local along = if nextLevelAt then 0 else math.clamp(best / math.max(0.001, level.length), 0, 1)
	clear()
	bead.Visible = false
	goalMark.Visible = false
	return math.min(1, (cleared + along) / goal), purged
end

return Thread
