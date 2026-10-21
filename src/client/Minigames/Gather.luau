--!strict
-- Gather Qi. Motes of qi fall through the field; slide the dantian bowl along
-- the bottom to catch them. Drag anywhere (the bowl follows your thumb's side to
-- side), move the mouse, or hold A/D or the arrow keys. Purple motes are
-- impurities: let them fall past to purge them, catch one and it jolts you.
-- A run is the server's number of levels, each a fall of qi with a short breath
-- between; a level is cleared once its last mote has landed, and the run ends
-- after the last level. Each level's accuracy is the share of its qi caught.
--
-- Bowl width, fall speed, how often qi falls and motes a level come from
-- Config (Games.Gather).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

local BOWL_SPEED = 2.4 -- field widths per second the bowl can travel
local KEY_SPEED = 1.5 -- field widths per second keys move the target
local MAX_STEP = 0.45 -- furthest (field widths) one qi mote lands from the last
local EDGE = 0.06 -- motes stay this far from the field's sides
local BOWL_LIFT = 10 -- px from the field bottom to the bowl's bottom, as authored
local MOTE_SIZE = 22
local IMPURE_SIZE = 28
local LEVEL_GAP = 1.2 -- extra seconds between one level's last mote and the next one's first
local END_PAUSE = 0.5 -- seconds after the last mote lands before the run ends

local QI = Color3.fromRGB(200, 255, 230)
local IMPURE = Color3.fromRGB(190, 90, 220)
local JOLT = Color3.fromRGB(255, 110, 100)
local MISSED = Color3.fromRGB(120, 150, 140)

type Mote = { spawn: number, x: number, impure: boolean, level: number, frame: Frame?, done: boolean }

local Gather = {}

Gather.TITLE = "Gather Qi"
Gather.HINT = "Drag to slide your dantian and catch the falling qi. Let purple impurities fall past."

function Gather.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Gather", info.difficulty)
	local bowlWidth = math.clamp(tune.bowl, 0.08, 0.8)
	local fallTime = 1 / math.max(0.1, tune.fall)
	local field = stage:FindFirstChild("Field") :: Frame
	local bowl = field:FindFirstChild("Bowl") :: Frame
	local glow = bowl:FindFirstChild("Glow") :: Frame
	local moteTemplate = field:FindFirstChild("MoteTemplate") :: Frame
	local impureTemplate = field:FindFirstChild("ImpureTemplate") :: Frame
	bowl.Size = UDim2.new(bowlWidth, 0, bowl.Size.Y.Scale, bowl.Size.Y.Offset)

	-- the fall schedule, level by level: qi at a steady pace within reach of the
	-- last one, impurities spread through the level near where qi is about to fall
	local rng = Random.new(info.seed)
	local levels = info.levels or 1
	local perLevel = math.max(4, math.floor(tune.motes + 0.5))
	local motes: { Mote } = {}
	local left = table.create(levels, 0) -- motes still to land, per level
	local last = 0.5
	local spawn = 0.3
	for level = 1, levels do
		local from = spawn
		for _ = 1, perLevel do
			last = math.clamp(last + rng:NextNumber(-MAX_STEP, MAX_STEP), EDGE, 1 - EDGE)
			table.insert(motes, { spawn = spawn, x = last, impure = false, level = level, frame = nil, done = false })
			spawn += tune.interval * rng:NextNumber(0.8, 1.2)
		end
		local to = spawn - tune.interval
		for i = 1, info.impurities do
			local when = math.clamp(from + (to - from) * i / (info.impurities + 1) + rng:NextNumber(-0.3, 0.3), from + 0.6, to)
			local x = rng:NextNumber(EDGE, 1 - EDGE)
			table.insert(motes, { spawn = when, x = x, impure = true, level = level, frame = nil, done = false })
		end
		left[level] = perLevel + info.impurities
		spawn += LEVEL_GAP
	end
	table.sort(motes, function(a, b)
		return a.spawn < b.spawn
	end)

	local caught = table.create(levels, 0) -- qi caught, per level
	local t, purged, combo, cleared, total = 0, 0, 0, 0, 0 -- total: cleared levels' accuracy, summed
	local endAt: number? = nil
	local bowlX, target = 0.5, 0.5
	local made: { Instance } = {}

	local function fieldX(screenX: number): number
		return math.clamp((screenX - field.AbsolutePosition.X) / math.max(1, field.AbsoluteSize.X), bowlWidth / 2, 1 - bowlWidth / 2)
	end

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			target = fieldX(input.Position.X)
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		-- any moving thumb steers, including one already down through the count-in
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseMovement then
			target = fieldX(input.Position.X)
		end
	end))
	local function keyAxis(): number
		local axis = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			axis -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			axis += 1
		end
		return axis
	end

	local function flashGlow(color: Color3)
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 0.1
		TweenService:Create(glow, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end

	ui.ready()
	local finished = false
	local function scoreText(): string
		local level = math.min(cleared + 1, levels)
		return `Level {level} / {levels}   Caught {math.floor(caught[level] / perLevel * 100 + 0.5)}%`
	end
	ui.score.Text = scoreText()
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		dt = math.min(dt, 0.1)
		t += dt

		local axis = keyAxis()
		if axis ~= 0 then
			target = math.clamp(target + axis * KEY_SPEED * dt, bowlWidth / 2, 1 - bowlWidth / 2)
		end
		local step = math.clamp(target - bowlX, -BOWL_SPEED * dt, BOWL_SPEED * dt)
		bowlX += step
		bowl.Position = UDim2.new(bowlX, 0, 1, -BOWL_LIFT)

		local size = field.AbsoluteSize
		local catchY = 1 - (BOWL_LIFT + bowl.AbsoluteSize.Y) / math.max(1, size.Y)
		for _, mote in motes do
			if mote.done then
				continue
			end
			if t < mote.spawn then
				break
			end
			if not mote.frame then
				local frame = (if mote.impure then impureTemplate else moteTemplate):Clone()
				frame.Name = "Mote"
				frame.Visible = true
				frame.Parent = field
				Feel.fadeIn(frame, 0.2)
				table.insert(made, frame)
				mote.frame = frame
			end
			local frame = mote.frame :: Frame
			local y = (t - mote.spawn) / fallTime * (catchY + 0.04) - 0.04
			frame.Position = UDim2.fromScale(mote.x, y)
			if y >= catchY then
				mote.done = true
				local radius = (if mote.impure then IMPURE_SIZE else MOTE_SIZE) / 2 / math.max(1, size.X)
				local inBowl = math.abs(mote.x - bowlX) <= bowlWidth / 2 + radius
				local at = UDim2.fromScale(mote.x, catchY)
				if mote.impure and inBowl then
					combo = 0
					Feel.pop(field, at, JOLT)
					Feel.buzz(0.7, 0.15)
					flashGlow(JOLT)
				elseif mote.impure then
					purged += 1
					Feel.pop(field, UDim2.fromScale(mote.x, 1), IMPURE, 60)
				elseif inBowl then
					caught[mote.level] += 1
					combo += 1
					Feel.pop(field, at, QI, 70)
					flashGlow(QI)
				else
					-- a mote let fall: a faint ripple where it left
					combo = 0
					Feel.pop(field, UDim2.fromScale(mote.x, 1), MISSED, 40)
				end
				frame:Destroy()
				left[mote.level] -= 1
				if left[mote.level] == 0 then
					cleared += 1
					total += caught[mote.level] / perLevel
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
			if inst.Parent then
				inst:Destroy()
			end
		end
		bowl.Position = UDim2.new(0.5, 0, 1, -BOWL_LIFT)
	end)
	return total / math.max(1, cleared), purged, cleared
end

return Gather
