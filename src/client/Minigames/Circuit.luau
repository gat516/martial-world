--!strict
-- Small Heavenly Circuit. A qi orb circles the meridian. Holding anywhere raises
-- the pressure needle, and releasing lets it fall; keep it inside the drifting
-- green band. Impurities swell on the path ahead of the orb; tap them before the
-- orb arrives, or they jolt the pressure. Accuracy is time spent in the band.
--
-- Feel: the dantian core at the centre fills as you hold the band; the orb leaves
-- a fading trail and glows only while in the band; a Flow streak builds the
-- longer you stay in; the gauge edge flashes red outside the band; purges pop
-- with a ring. Band size, drift and orb laps come from Config (Games.Circuit).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

-- Feel. These are client-only, so they don't affect the server's scoring rules.
local PATH_RADIUS = 0.42 -- of the meridian frame
local DOTS = 40
local TRAIL = 7 -- fading dots behind the orb
local RISE = 2.6 -- needle acceleration while holding, gauge heights / s^2
local FALL = 2.2 -- and while released
local DAMPING = 2.4 -- velocity lost per second
local JOLT = 0.9 -- velocity kick from an impurity the orb reaches
local IMPURITY_LEAD = 2.2 -- seconds an impurity shows before the orb reaches it

local IN_COLOR = Color3.fromRGB(200, 255, 230)
local OUT_COLOR = Color3.fromRGB(120, 140, 135)
local GAUGE_OK = Color3.fromRGB(30, 38, 42)
local GAUGE_BAD = Color3.fromRGB(90, 30, 30)

type Impurity = { at: number, button: TextButton?, done: boolean }

local Circuit = {}

Circuit.TITLE = "Small Heavenly Circuit"
Circuit.HINT = "Hold to raise pressure and keep it in the green. Tap impurities before the orb reaches them."

local function pathPoint(fraction: number): UDim2
	local a = fraction * 2 * math.pi
	return UDim2.fromScale(0.5 + PATH_RADIUS * math.sin(a), 0.5 - PATH_RADIUS * math.cos(a))
end

function Circuit.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Circuit", info.difficulty)
	local meridian = stage:FindFirstChild("Meridian") :: Frame
	local orb = meridian:FindFirstChild("Orb") :: Frame
	local orbStroke = orb:FindFirstChildOfClass("UIStroke") :: UIStroke
	local dotTemplate = meridian:FindFirstChild("DotTemplate") :: Frame
	local impurityTemplate = meridian:FindFirstChild("ImpurityTemplate") :: TextButton
	local core = meridian:FindFirstChild("Core") :: Frame
	local coreFill = core:FindFirstChild("Fill") :: Frame
	local gauge = stage:FindFirstChild("Gauge") :: Frame
	local band = gauge:FindFirstChild("Band") :: Frame
	local needle = gauge:FindFirstChild("Needle") :: Frame
	local holdArea = stage:FindFirstChild("HoldArea") :: TextButton

	local made: { Instance } = {}
	for i = 1, DOTS do
		local dot = dotTemplate:Clone()
		dot.Name = "Dot"
		dot.Position = pathPoint(i / DOTS)
		dot.Visible = true
		dot.Parent = meridian
		table.insert(made, dot)
	end
	local trail: { Frame } = {}
	for i = 1, TRAIL do
		local dot = dotTemplate:Clone()
		dot.Name = "Trail"
		dot.Size = UDim2.fromOffset(18 - i * 1.6, 18 - i * 1.6)
		dot.BackgroundColor3 = IN_COLOR
		dot.ZIndex = 12
		dot.Visible = true
		dot.Parent = meridian
		table.insert(trail, dot)
		table.insert(made, dot)
	end
	coreFill.Size = UDim2.fromScale(0, 0)
	ui.score.Text = "In band 0%"

	local rng = Random.new(info.seed)
	local impurities: { Impurity } = {}
	for i = 1, info.impurities do
		local slot = info.duration / (info.impurities + 1)
		local at = math.max(IMPURITY_LEAD + 0.5, slot * i + rng:NextNumber(-0.3, 0.3) * slot)
		table.insert(impurities, { at = at, button = nil, done = false })
	end

	local bandSize = math.clamp(tune.band, 0.05, 0.9)
	band.Size = UDim2.fromScale(1, bandSize)
	local phase = rng:NextNumber(0, 2 * math.pi)
	local pressure, velocity = 0.5, 0
	local t, inBand, purged = 0, 0, 0
	local streak = 0

	-- Presses that began on the hold area, released wherever they end, so a thumb
	-- sliding off it (or onto an impurity) can't leave the needle stuck rising.
	local presses: { [InputObject]: boolean } = {}
	local spaceHeld = false
	local function holding(): boolean
		return spaceHeld or next(presses) ~= nil
	end

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, holdArea.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			presses[input] = true
		end
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			spaceHeld = true
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		presses[input] = nil
		if input.KeyCode == Enum.KeyCode.Space then
			spaceHeld = false
		end
	end))
	-- a mouse press reuses one InputObject; also clear on the button's own release
	table.insert(connections, holdArea.InputEnded:Connect(function(input)
		presses[input] = nil
	end))

	local history: { UDim2 } = {}
	local loopsPerSecond = tune.loops / info.duration
	local finished = false
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		dt = math.min(dt, 0.1)
		t += dt

		velocity += (if holding() then RISE else -FALL) * dt
		velocity -= velocity * math.min(1, DAMPING * dt)
		pressure += velocity * dt
		if pressure <= 0 or pressure >= 1 then
			pressure = math.clamp(pressure, 0, 1)
			velocity = 0
		end

		local half = bandSize / 2
		local center = 0.5 + 0.22 * math.sin(t * tune.drift + phase) + 0.1 * math.sin(t * tune.drift * 2.55 + phase * 2)
		center = math.clamp(center, half, 1 - half)
		local inside = math.abs(pressure - center) <= half
		if inside then
			inBand += dt
			streak += dt
		else
			streak = 0
		end

		band.Position = UDim2.fromScale(0, 1 - center)
		band.BackgroundTransparency = if inside then 0.05 else 0.35
		gauge.BackgroundColor3 = if inside then GAUGE_OK else GAUGE_BAD
		needle.Position = UDim2.fromScale(0.5, 1 - pressure)

		local orbAt = pathPoint((t * loopsPerSecond) % 1)
		orb.Position = orbAt
		orb.BackgroundColor3 = if inside then IN_COLOR else OUT_COLOR
		orbStroke.Transparency = if inside then 0 else 0.6
		table.insert(history, 1, orbAt)
		if #history > TRAIL * 2 then
			table.remove(history)
		end
		for i, dot in trail do
			local p = history[i * 2]
			if p then
				dot.Position = p
				dot.BackgroundTransparency = if inside then 0.3 + i * 0.09 else 0.85
			end
		end

		local fill = inBand / info.duration
		coreFill.Size = UDim2.fromScale(math.sqrt(fill), math.sqrt(fill))
		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `In band {math.floor(inBand / math.max(t, 0.001) * 100 + 0.5)}%`
		ui.flow.Text = if streak >= 2 then `Flow x{math.floor(streak)}` else ""

		for _, imp in impurities do
			if imp.done then
				continue
			end
			local spot = pathPoint((imp.at * loopsPerSecond) % 1)
			if not imp.button and t >= imp.at - IMPURITY_LEAD then
				local button = impurityTemplate:Clone()
				button.Name = "Impurity"
				button.Position = spot
				button.Size = UDim2.fromOffset(30, 30)
				button.Visible = true
				button.Parent = meridian
				table.insert(made, button)
				button.Activated:Connect(function()
					if not imp.done then
						imp.done = true
						purged += 1
						Feel.pop(meridian, spot, Color3.fromRGB(220, 160, 255))
						Feel.buzz(0.3, 0.08)
						button:Destroy()
					end
				end)
				imp.button = button
			end
			if imp.button then
				-- swell toward full size as the orb closes in
				local closeness = math.clamp(1 - (imp.at - t) / IMPURITY_LEAD, 0, 1)
				local size = 30 + 30 * closeness + 4 * math.sin(t * 12)
				imp.button.Size = UDim2.fromOffset(size, size)
			end
			if t >= imp.at then
				imp.done = true
				velocity += if pressure > 0.5 then -JOLT else JOLT
				Feel.pop(meridian, spot, Color3.fromRGB(255, 90, 80))
				Feel.buzz(0.7, 0.15)
				if imp.button then
					imp.button:Destroy()
				end
			end
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
	for _, inst in made do
		inst:Destroy()
	end
	gauge.BackgroundColor3 = GAUGE_OK
	return inBand / info.duration, purged
end

return Circuit
