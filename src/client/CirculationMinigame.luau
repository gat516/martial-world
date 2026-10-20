--!strict
-- The circulation minigame (Small Heavenly Circuit), full screen and one thumb.
-- A qi orb circles the meridian. Holding anywhere raises the pressure needle, and
-- releasing lets it fall; keep it inside the drifting green band. Impurities appear
-- on the path ahead of the orb; tap them before the orb arrives, or they jolt the
-- pressure. The server sets the run's length, band and impurity count, and turns the
-- reported accuracy and purges into cultivation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Hud = require(script.Parent.Hud)

local remote = ReplicatedStorage.Remotes.CultivationAction :: RemoteFunction
local player = Players.LocalPlayer

-- Feel. These are client-only, so they don't affect the server's scoring rules.
local PATH_RADIUS = 0.42 -- of the meridian frame
local DOTS = 40
local RISE = 2.6 -- needle acceleration while holding, gauge heights / s^2
local FALL = 2.2 -- and while released
local DAMPING = 2.4 -- velocity lost per second
local JOLT = 0.9 -- velocity kick from an impurity the orb reaches
local IMPURITY_LEAD = 2.2 -- seconds an impurity shows before the orb reaches it
local RESULT_SECONDS = 2.2

type Info = { id: string, duration: number, band: number, impurities: number, loops: number, seed: number }
type Impurity = { at: number, button: TextButton?, done: boolean }

local CirculationMinigame = {}

local overlay: Frame
local running = false

local function controls(): any?
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any).PlayerModule)
	end)
	return if ok then (module :: any):GetControls() else nil
end

local function pathPoint(fraction: number): UDim2
	local a = fraction * 2 * math.pi
	return UDim2.fromScale(0.5 + PATH_RADIUS * math.sin(a), 0.5 - PATH_RADIUS * math.cos(a))
end

local function play(info: Info): (number, number)
	local meridian = overlay:FindFirstChild("Meridian") :: Frame
	local orb = meridian:FindFirstChild("Orb") :: Frame
	local dotTemplate = meridian:FindFirstChild("DotTemplate") :: Frame
	local impurityTemplate = meridian:FindFirstChild("ImpurityTemplate") :: TextButton
	local gauge = overlay:FindFirstChild("Gauge") :: Frame
	local band = gauge:FindFirstChild("Band") :: Frame
	local needle = gauge:FindFirstChild("Needle") :: Frame
	local holdArea = overlay:FindFirstChild("HoldArea") :: TextButton
	local timer = overlay:FindFirstChild("Timer") :: TextLabel
	local accuracyLabel = overlay:FindFirstChild("Accuracy") :: TextLabel

	local made: { Instance } = {}
	for i = 1, DOTS do
		local dot = dotTemplate:Clone()
		dot.Name = "Dot"
		dot.Position = pathPoint(i / DOTS)
		dot.Visible = true
		dot.Parent = meridian
		table.insert(made, dot)
	end

	local rng = Random.new(info.seed)
	local impurities: { Impurity } = {}
	for i = 1, info.impurities do
		local slot = info.duration / (info.impurities + 1)
		local at = math.max(IMPURITY_LEAD + 0.5, slot * i + rng:NextNumber(-0.3, 0.3) * slot)
		table.insert(impurities, { at = at, button = nil, done = false })
	end

	band.Size = UDim2.fromScale(1, info.band)
	local phase = rng:NextNumber(0, 2 * math.pi)
	local pressure, velocity = 0.5, 0
	local t, inBand, purged = 0, 0, 0
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

	local loopsPerSecond = info.loops / info.duration
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

		local half = info.band / 2
		local center = 0.5 + 0.22 * math.sin(t * 0.9 + phase) + 0.1 * math.sin(t * 2.3 + phase * 2)
		center = math.clamp(center, half, 1 - half)
		local inside = math.abs(pressure - center) <= half
		if inside then
			inBand += dt
		end

		band.Position = UDim2.fromScale(0, 1 - center)
		band.BackgroundTransparency = if inside then 0.05 else 0.35
		needle.Position = UDim2.fromScale(0.5, 1 - pressure)
		orb.Position = pathPoint((t * loopsPerSecond) % 1)
		timer.Text = string.format("%d", math.max(0, math.ceil(info.duration - t)))
		accuracyLabel.Text = `In band {math.floor(inBand / math.max(t, 0.001) * 100 + 0.5)}%`

		for _, imp in impurities do
			if imp.done then
				continue
			end
			if not imp.button and t >= imp.at - IMPURITY_LEAD then
				local button = impurityTemplate:Clone()
				button.Name = "Impurity"
				button.Position = pathPoint((imp.at * loopsPerSecond) % 1)
				button.Visible = true
				button.Parent = meridian
				table.insert(made, button)
				button.Activated:Connect(function()
					if not imp.done then
						imp.done = true
						purged += 1
						button:Destroy()
					end
				end)
				imp.button = button
			end
			if t >= imp.at then
				imp.done = true
				velocity += if pressure > 0.5 then -JOLT else JOLT
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
	return inBand / info.duration, purged
end

local function showResult(text: string)
	local result = overlay:FindFirstChild("Result") :: TextLabel
	result.Text = text
	result.Visible = true
	task.wait(RESULT_SECONDS)
	result.Visible = false
end

function CirculationMinigame.start()
	if running then
		return
	end
	running = true
	local ok, info = remote:InvokeServer("start")
	if not ok then
		Hud.toast(info or "You can't circulate right now")
		running = false
		return
	end

	local ctl = controls()
	if ctl then
		ctl:Disable()
	end
	overlay.Visible = true
	local accuracy, purged = play(info)
	local done, result = remote:InvokeServer("finish", info.id, accuracy, purged)
	if done then
		local lines = `+{result.gain} cultivation\nScore {math.floor(result.score * 100 + 0.5)}%`
		if result.deviation then
			lines ..= "\nQi deviation! Let it settle."
		elseif result.full then
			lines ..= "\nYour realm bar is full!"
		end
		showResult(lines)
	else
		showResult(result or "The run fizzled")
	end
	overlay.Visible = false
	if ctl then
		ctl:Enable()
	end
	running = false
end

function CirculationMinigame.isRunning(): boolean
	return running
end

function CirculationMinigame.init(gui: ScreenGui)
	overlay = gui:FindFirstChild("Circulation") :: Frame
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("CirculateButton") :: TextButton
	button.Activated:Connect(function()
		task.spawn(CirculationMinigame.start)
	end)
end

return CirculationMinigame
