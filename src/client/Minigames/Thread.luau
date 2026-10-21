--!strict
-- Thread the Meridian. A bead of qi must travel a winding meridian without
-- touching its walls, level after level, each one narrower and twistier. Put
-- the pointer on the bead to take hold of it (the mouse, no click; the OS arrow
-- gives way to the qi pointer over the board; or a finger), and from then on
-- it follows the pointer, however fast you move: nothing outruns it and lets
-- go. Its path is swept in small steps, so a flick across a wall still touches
-- it. Touch a wall and the qi scatters back to the last acupoint you lit, and
-- you take hold of it there again (a faint tether runs from the pointer to it
-- meanwhile). A lifted finger lets go too. WASD / the arrows steer it as well.
-- Purple impurities hug the walls: brush through one to purge it, if you dare.
-- A run is the server's number of levels against its clock and ends once the
-- last is cleared; each level's accuracy drops SCATTER_COST for every wall touched.
--
-- Channel width and bends come from Config (Games.Thread).
-- Lengths here are in field heights; the field keeps a fixed aspect ratio.
-- Look: the meridian is a dark jade channel in an engraved gold rim
-- (thread_wall.png under mg_disc.png, round-capped 9-slice strokes), the qi
-- you've carried fills it as a glowing trail (maze_trail.png), the bead is the
-- Maze's spark, the goal its turning seal, acupoints light gold
-- (thread_node.png), all over a faint ink-wash landscape (field_wash.png).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)
local Platform = require(script.Parent.Parent.Platform)

local ASPECT = 1.6 -- field width / height, as authored (UIAspectRatioConstraint)
local BEAD_RADIUS = 0.018
local BEAD_ART = 3.2 -- the spark image's size over the bead's hit size (its halo)
local WALL = 0.012 -- wall thickness drawn around the channel
local WALL_CORE = 0.78 -- share of thread_wall.png's width the gold rim fills (the rest is its aura)
local TRAIL_SHARE = 1.1 -- the qi trail's width (glow included) over the channel's
local NARROW = 0.88 -- each level's channel is this much of the last one's width
local MIN_HALF_WIDTH = 0.032
local MAX_BENDS = 9
local MAX_SPEED = 6 -- field heights per second the bead may sweep (it never lets go; it only trails behind)
local KEY_SPEED = 0.55
local STEP = 0.006 -- collision sub-step
local SCATTER_SECONDS = 0.45 -- frozen after touching a wall
local IMPURITY_RADIUS = 0.016
local IMPURITY_ART = 3.4 -- the miasma image's size over the impurity's hit size
local NEXT_PAUSE = 0.35
local SCATTER_COST = 0.2 -- accuracy a level loses for each wall touched
local GRAB_RADIUS = 0.06 -- the mouse must come this close to the bead to take hold
local GRAB_PX = 48 -- ...and a finger this many pixels (a thumb covers more)
local TETHER_PX = 6

local QI = Color3.fromRGB(200, 255, 230)
local IMPURE = Color3.fromRGB(220, 160, 255)
local JOLT = Color3.fromRGB(255, 110, 100)
local LIT = Color3.fromRGB(255, 225, 140)
local UNLIT = Color3.fromRGB(80, 150, 125)
local WHITE = Color3.new(1, 1, 1)

type Level = {
	points: { Vector2 },
	cum: { number }, -- path length up to each point
	length: number,
	half: number, -- channel half-width
}

local Thread = {}

Thread.TITLE = "Thread the Meridian"
Thread.HINT = "Point at the qi to take hold of it, then guide it along the meridian without touching the walls. Brush purple impurities to purge them."
Thread.TOUCH_HINT = "Put your finger on the qi, then guide it along the meridian without touching the walls. Brush purple impurities to purge them."

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

function Thread.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number, number)
	local tune = Feel.tune("Thread", info.difficulty)
	local levels = info.levels or 1
	local field = stage:FindFirstChild("Field") :: ImageLabel
	local wallTemplate = field:FindFirstChild("WallTemplate") :: ImageLabel
	local channelTemplate = field:FindFirstChild("ChannelTemplate") :: ImageLabel
	local trailTemplate = field:FindFirstChild("TrailTemplate") :: ImageLabel
	local acupointTemplate = field:FindFirstChild("AcupointTemplate") :: ImageLabel
	local impurityTemplate = field:FindFirstChild("ImpurityTemplate") :: ImageLabel
	local bead = field:FindFirstChild("Bead") :: ImageLabel
	local goalMark = field:FindFirstChild("Goal") :: ImageLabel
	local tether = field:FindFirstChild("Tether") :: ImageLabel
	local rng = Random.new(info.seed)
	local touch = Platform.isTouch()

	local made: { Instance } = {}
	local function clear()
		for _, inst in made do
			inst:Destroy()
		end
		table.clear(made)
	end
	local function place(template: ImageLabel, at: Vector2, width: number, height: number, rotation: number?): ImageLabel
		local frame = template:Clone()
		frame.Position = toUDim(at)
		frame.Size = UDim2.fromScale(width / ASPECT, height)
		frame.Rotation = rotation or 0
		frame.Visible = true
		frame.Parent = field
		table.insert(made, frame)
		return frame
	end
	-- A round-capped stroke from a to b, `thick` field heights wide, 9-sliced
	-- from a radially symmetric image so neighbouring strokes meet as round joints.
	local function stroke(template: ImageLabel, a: Vector2, b: Vector2, thick: number): ImageLabel
		local d = b - a
		local frame = place(template, (a + b) / 2, d.Magnitude + thick, thick, math.deg(math.atan2(d.Y, d.X)))
		frame.SliceScale = thick * field.AbsoluteSize.Y / 128
		return frame
	end

	local levelIndex = 0
	local level: Level
	local acupoints: { ImageLabel } = {}
	local trails: { ImageLabel } = {} -- one per segment, grown as the qi is carried along it
	local impurities: { { at: Vector2, frame: ImageLabel } } = {}
	local pos = Vector2.zero
	local checkpoint = 1 -- index into level.points
	local best = 0 -- furthest along the current level

	local function newLevel()
		clear()
		table.clear(acupoints)
		table.clear(trails)
		table.clear(impurities)
		levelIndex += 1
		local half = math.max(MIN_HALF_WIDTH, tune.width * NARROW ^ (levelIndex - 1))
		level = generate(levelIndex, math.floor(tune.bends + 0.5), half, rng)
		local points = level.points
		-- the gold rim layer under the channel layer reads as one engraved tube
		for i = 1, #points - 1 do
			stroke(wallTemplate, points[i], points[i + 1], 2 * (half + WALL) / WALL_CORE)
		end
		for i = 1, #points - 1 do
			stroke(channelTemplate, points[i], points[i + 1], 2 * half)
		end
		for i = 1, #points - 1 do
			local trail = stroke(trailTemplate, points[i], points[i], 2 * half * TRAIL_SHARE)
			trail.Visible = false
			trails[i] = trail
		end
		for i = 2, #points - 1 do
			local node = place(acupointTemplate, points[i], half * 1.1, half * 1.1)
			node.ImageColor3 = UNLIT
			acupoints[i] = node
		end
		local count = info.impurities
		for i = 1, count do
			local s = level.length * (i / (count + 1)) * rng:NextNumber(0.85, 1.15)
			local at, dir = pointAt(level, s)
			local side = if rng:NextNumber() < 0.5 then 1 else -1
			at += Vector2.new(-dir.Y, dir.X) * side * (half - BEAD_RADIUS) * 0.8
			local frame = place(impurityTemplate, at, IMPURITY_RADIUS * IMPURITY_ART, IMPURITY_RADIUS * IMPURITY_ART)
			table.insert(impurities, { at = at, frame = frame })
		end
		goalMark.Position = toUDim(points[#points])
		goalMark.Size = UDim2.fromScale(half * 2.4 / ASPECT, half * 2.4)
		goalMark.Visible = true
		bead.Size = UDim2.fromScale(BEAD_RADIUS * 2 * BEAD_ART / ASPECT, BEAD_RADIUS * 2 * BEAD_ART)
		bead.Visible = true
		pos = points[1]
		checkpoint = 1
		best = 0
	end

	-- the qi carried so far glows in the channel, up to `best`
	local function drawTrail()
		local points = level.points
		local thick = 2 * level.half * TRAIL_SHARE
		for i = 1, #points - 1 do
			local trail = trails[i]
			local filled = math.clamp(best - level.cum[i], 0, level.cum[i + 1] - level.cum[i])
			if filled > 1e-3 then
				local a = points[i]
				local b = a + (points[i + 1] - a).Unit * filled
				trail.Position = toUDim((a + b) / 2)
				trail.Size = UDim2.fromScale((filled + thick) / ASPECT, thick)
				trail.Visible = true
			else
				trail.Visible = false
			end
		end
	end

	local t, cleared, purged, streak = 0, 0, 0, 0
	local scatters, quality = 0, 0 -- wall touches this level; accuracy summed over cleared levels
	local endAt: number? = nil -- the last level is cleared: the run ends then
	local frozenUntil = 0
	local joltUntil = 0
	local nextLevelAt: number? = nil
	local veilAt: number? = nil -- when the veil starts to fall over a cleared level
	local grabbed = false -- the pointer is holding the bead
	local flung: { from: Vector2, at: number }? = nil -- the bead flying back after a scatter

	local function flow(text: string, seconds: number)
		ui.flow.Text = text
		task.delay(seconds, function()
			if ui.flow.Text == text then
				ui.flow.Text = ""
			end
		end)
	end

	local function scatter()
		Feel.pop(field, toUDim(pos), JOLT)
		Feel.shake(field, 6, 0.25)
		Feel.sound("Thud")
		Feel.buzz(0.7, 0.15)
		flung = { from = pos, at = t }
		pos = level.points[checkpoint]
		best = math.max(level.cum[checkpoint], 0)
		frozenUntil = t + SCATTER_SECONDS
		joltUntil = frozenUntil
		streak = 0
		scatters += 1
		grabbed = false
		flow("Scattered!", 0.8)
	end

	-- Sweeps the bead toward pos + delta in small steps, stopping at a wall.
	local function move(delta: Vector2)
		local steps = math.max(1, math.ceil(delta.Magnitude / STEP))
		for _ = 1, steps do
			local next = pos + delta / steps
			local d, along = nearest(level, next)
			if d > level.half - BEAD_RADIUS then
				pos = next
				scatter()
				return
			end
			pos = next
			best = math.max(best, along)
			for i = checkpoint + 1, #level.points - 1 do
				if best >= level.cum[i] then
					checkpoint = i
					streak += 1
					local node = acupoints[i]
					node.ImageColor3 = LIT
					node.Size = UDim2.fromScale(level.half * 1.6 / ASPECT, level.half * 1.6)
					TweenService:Create(node, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.fromScale(level.half * 1.1 / ASPECT, level.half * 1.1),
					}):Play()
					Feel.pop(field, toUDim(level.points[i]), LIT, 60)
					Feel.sound("Tick", 1 + 0.06 * math.min(streak, 8))
				end
			end
			for i = #impurities, 1, -1 do
				local imp = impurities[i]
				if (imp.at - pos).Magnitude <= BEAD_RADIUS + IMPURITY_RADIUS then
					purged += 1
					Feel.pop(field, toUDim(imp.at), IMPURE)
					Feel.burst(field, toUDim(imp.at), IMPURE, 80)
					Feel.sound("Purge")
					Feel.buzz(0.3, 0.08)
					imp.frame:Destroy()
					table.remove(impurities, i)
				end
			end
			if (pos - level.points[#level.points]).Magnitude <= level.half * 0.6 then
				cleared += 1
				quality += math.max(0, 1 - SCATTER_COST * scatters)
				scatters = 0
				best = level.length
				Feel.pop(field, toUDim(pos), LIT, 140)
				Feel.burst(field, toUDim(pos), LIT, 150)
				Feel.sound("Clear")
				Feel.buzz(0.5, 0.12)
				frozenUntil = math.huge
				grabbed = false
				if cleared >= levels then
					endAt = t + NEXT_PAUSE
				else
					veilAt = t + NEXT_PAUSE
					nextLevelAt = t + NEXT_PAUSE + Feel.VEIL_IN
				end
				flow(`Meridian {cleared} cleared`, NEXT_PAUSE + 0.6)
				return
			end
		end
	end

	newLevel()
	drawTrail()
	ui.ready()

	local finger: InputObject? = nil -- the touch steering the bead
	local pointer = Feel.pointer(field, "qi")
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			finger = finger or input
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		-- a thumb already down through the count-in counts
		if input.UserInputType == Enum.UserInputType.Touch and not finger then
			finger = input
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input == finger then
			finger = nil
			if touch then
				grabbed = false -- a lifted finger lets go
			end
		end
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

	-- a screen point in field coordinates (field heights from its top-left)
	local function fieldAt(screen: Vector2): Vector2
		return (screen - field.AbsolutePosition) / math.max(1, field.AbsoluteSize.Y)
	end

	local finished = false
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		dt = math.min(dt, 0.1)
		t += dt

		local veil = veilAt
		if veil and t >= veil then
			veilAt = nil
			Feel.veilIn(field)
		end
		local due = nextLevelAt
		if due and t >= due then
			nextLevelAt = nil
			frozenUntil = 0
			newLevel()
			Feel.veilOut(field)
		end

		-- the pointer: the mouse over the board, else a finger that's down
		local screen = pointer.step()
		local fingerAt = finger and finger.Position
		if fingerAt then
			screen = Vector2.new(fingerAt.X, fingerAt.Y)
		end
		local target = screen and fieldAt(screen)
		if t >= frozenUntil then
			local delta = keyAxis() * KEY_SPEED * dt
			if target and not grabbed then
				local reach = if fingerAt then GRAB_PX / math.max(1, field.AbsoluteSize.Y) else GRAB_RADIUS
				if (target - pos).Magnitude <= reach then
					grabbed = true
					Feel.pop(field, toUDim(pos), QI, 50)
				end
			end
			if target and grabbed then
				-- straight at the pointer, swept; a fast hand only leaves it trailing
				delta += target - pos
			end
			local limit = math.max(MAX_SPEED, KEY_SPEED) * dt
			if delta.Magnitude > limit then
				delta = delta.Unit * limit
			end
			if delta.Magnitude > 1e-5 then
				move(delta)
			end
		end
		drawTrail()

		-- the bead flies back to its acupoint after a scatter
		local shown = pos
		local fling = flung
		if fling then
			local f = math.clamp((t - fling.at) / 0.22, 0, 1)
			shown = fling.from:Lerp(pos, 1 - (1 - f) ^ 3)
			if f >= 1 then
				flung = nil
			end
		end
		bead.Position = toUDim(shown)
		bead.ImageColor3 = if t < joltUntil then JOLT elseif nextLevelAt or endAt then LIT else WHITE
		-- loose, it breathes and a tether runs to it from the pointer
		local waiting = not grabbed and t >= frozenUntil
		local breathe = if waiting then 1 + 0.18 * (0.5 + 0.5 * math.sin(t * 7)) else 1
		bead.Size = UDim2.fromScale(BEAD_RADIUS * 2 * BEAD_ART * breathe / ASPECT, BEAD_RADIUS * 2 * BEAD_ART * breathe)
		if waiting and target and (target - pos).Magnitude > GRAB_RADIUS then
			local h = field.AbsoluteSize.Y
			Feel.line(tether, Vector2.new(pos.X, pos.Y) * h, target * h, TETHER_PX)
			tether.Visible = true
		else
			tether.Visible = false
		end
		goalMark.Rotation = (t * 24) % 360
		for i, imp in impurities do
			local pulse = IMPURITY_RADIUS * IMPURITY_ART * (1 + 0.1 * math.sin(t * 3 + i))
			imp.frame.Size = UDim2.fromScale(pulse / ASPECT, pulse)
		end

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `Meridians {cleared} / {levels}`
		if waiting and not nextLevelAt and not endAt and (ui.flow.Text == "" or ui.flow.Text == "Take hold of the qi") then
			ui.flow.Text = "Take hold of the qi"
		elseif ui.flow.Text == "" or string.find(ui.flow.Text, "Unbroken") or ui.flow.Text == "Take hold of the qi" then
			ui.flow.Text = if streak >= 2 then `Unbroken x{streak}` else ""
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
	pointer.stop()
	tether.Visible = false
	ui.hold(function()
		clear()
		table.clear(trails)
		bead.Visible = false
		goalMark.Visible = false
		local veil = field:FindFirstChild("Veil") :: Frame
		veil.BackgroundTransparency = 1
	end)
	return quality / math.max(1, cleared), purged, cleared
end

return Thread
