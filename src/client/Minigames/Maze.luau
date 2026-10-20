--!strict
-- Maze Formation. Your qi is caught in a maze formation; find the way out, like
-- the maze on a cereal box. Swipe anywhere (or press WASD / the arrows) and the
-- spark slides that way, following the corridor round its bends until the next
-- junction or dead end; a swipe made while it slides is taken at the next turn,
-- and swiping back reverses it on the spot. Escape and a new maze forms, as many
-- as the run allows. Purple impurities sit in dead ends off the way out: detour
-- through one to purge it. Accuracy is mazes escaped (plus how far along the
-- current one) against the run's par.
--
-- Maze size and par seconds per maze come from Config (Games.Maze).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

local SLIDE_SPEED = 11 -- cells per second
local SWIPE_PX = 26 -- drag this far to count as a swipe; keep dragging to swipe again
local WALL_PX = 4
local TRAIL_PX = 5
local NEXT_PAUSE = 0.35 -- seconds between escaping and the next maze
local MIN_SIZE = 4

local QI = Color3.fromRGB(200, 255, 230)
local IMPURE = Color3.fromRGB(220, 160, 255)
local EXIT = Color3.fromRGB(255, 225, 140)

-- up, right, down, left
local DX = { 0, 1, 0, -1 }
local DY = { -1, 0, 1, 0 }
local function opposite(dir: number): number
	return (dir + 1) % 4 + 1
end

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.W] = 1,
	[Enum.KeyCode.Up] = 1,
	[Enum.KeyCode.D] = 2,
	[Enum.KeyCode.Right] = 2,
	[Enum.KeyCode.S] = 3,
	[Enum.KeyCode.Down] = 3,
	[Enum.KeyCode.A] = 4,
	[Enum.KeyCode.Left] = 4,
}

type Grid = {
	n: number,
	open: { { boolean } }, -- open[cell][dir]
	start: number,
	exit: number,
	startSide: number,
	exitSide: number,
	toExit: { number }, -- steps from each cell to the exit
}

local Maze = {}

Maze.TITLE = "Maze Formation"
Maze.HINT = "Swipe to slide your qi through the formation and find the way out. Detour through purple impurities to purge them."

local function cellOf(n: number, x: number, y: number): number
	return y * n + x + 1
end

local function xyOf(n: number, cell: number): (number, number)
	return (cell - 1) % n, (cell - 1) // n
end

-- Steps from `from` to every cell.
local function distances(grid: Grid, from: number): { number }
	local n = grid.n
	local dist = { [from] = 0 }
	local queue, head = { from }, 1
	while queue[head] do
		local cell = queue[head]
		head += 1
		local x, y = xyOf(n, cell)
		for dir = 1, 4 do
			if grid.open[cell][dir] then
				local next = cellOf(n, x + DX[dir], y + DY[dir])
				if not dist[next] then
					dist[next] = dist[cell] + 1
					table.insert(queue, next)
				end
			end
		end
	end
	return dist
end

-- The side of the board a border cell opens onto.
local function sideOf(n: number, cell: number): number
	local x, y = xyOf(n, cell)
	if x == 0 then
		return 4
	elseif x == n - 1 then
		return 2
	elseif y == 0 then
		return 1
	end
	return 3
end

-- A recursive-backtracker maze (long winding corridors), entered on the left
-- edge and left by the border cell farthest from the entrance.
local function generate(n: number, rng: Random): Grid
	local open = {}
	for i = 1, n * n do
		open[i] = { false, false, false, false }
	end
	local start = cellOf(n, 0, rng:NextInteger(0, n - 1))
	local seen = { [start] = true }
	local stack = { start }
	while #stack > 0 do
		local cell = stack[#stack]
		local x, y = xyOf(n, cell)
		local options = {}
		for dir = 1, 4 do
			local nx, ny = x + DX[dir], y + DY[dir]
			if nx >= 0 and nx < n and ny >= 0 and ny < n and not seen[cellOf(n, nx, ny)] then
				table.insert(options, dir)
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local dir = options[rng:NextInteger(1, #options)]
			local next = cellOf(n, x + DX[dir], y + DY[dir])
			open[cell][dir] = true
			open[next][opposite(dir)] = true
			seen[next] = true
			table.insert(stack, next)
		end
	end
	local grid: Grid = { n = n, open = open, start = start, exit = start, startSide = 4, exitSide = 2, toExit = {} }
	local fromStart = distances(grid, start)
	local best = -1
	for cell = 1, n * n do
		local x, y = xyOf(n, cell)
		local border = x == 0 or y == 0 or x == n - 1 or y == n - 1
		if border and cell ~= start and fromStart[cell] > best then
			best = fromStart[cell]
			grid.exit = cell
		end
	end
	grid.exitSide = sideOf(n, grid.exit)
	grid.toExit = distances(grid, grid.exit)
	return grid
end

-- Dead ends (else any cells) off the way out, for impurities.
local function impuritySpots(grid: Grid, count: number, rng: Random): { number }
	local onPath = {}
	local cell = grid.start
	while cell ~= grid.exit do
		onPath[cell] = true
		local x, y = xyOf(grid.n, cell)
		for dir = 1, 4 do
			local next = cellOf(grid.n, x + DX[dir], y + DY[dir])
			if grid.open[cell][dir] and grid.toExit[next] < grid.toExit[cell] then
				cell = next
				break
			end
		end
	end
	onPath[grid.exit] = true
	local deadEnds, others = {}, {}
	for c = 1, grid.n * grid.n do
		if not onPath[c] then
			local exits = 0
			for dir = 1, 4 do
				if grid.open[c][dir] then
					exits += 1
				end
			end
			table.insert(if exits == 1 then deadEnds else others, c)
		end
	end
	local spots = {}
	for _, pool in { deadEnds, others } do
		while #spots < count and #pool > 0 do
			table.insert(spots, table.remove(pool, rng:NextInteger(1, #pool)))
		end
	end
	return spots
end

function Maze.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number)
	local tune = Feel.tune("Maze", info.difficulty)
	local n = math.max(MIN_SIZE, math.floor(tune.size + 0.5))
	local goal = math.max(1, info.duration / math.max(1, tune.par))
	local field = stage:FindFirstChild("Field") :: Frame
	local board = field:FindFirstChild("Board") :: Frame
	local wallTemplate = board:FindFirstChild("WallTemplate") :: Frame
	local trailTemplate = board:FindFirstChild("TrailTemplate") :: Frame
	local impurityTemplate = board:FindFirstChild("ImpurityTemplate") :: Frame
	local spark = board:FindFirstChild("Spark") :: Frame
	local exitMark = board:FindFirstChild("Exit") :: Frame
	local rng = Random.new(info.seed)

	local function center(cell: number): UDim2
		local x, y = xyOf(n, cell)
		return UDim2.fromScale((x + 0.5) / n, (y + 0.5) / n)
	end

	local made: { Instance } = {} -- this maze's walls, trail and impurities
	local function clear()
		for _, inst in made do
			inst:Destroy()
		end
		table.clear(made)
	end

	local function wall(x0: number, y0: number, x1: number, y1: number)
		local frame = wallTemplate:Clone()
		frame.Name = "Wall"
		frame.Position = UDim2.new(x0 / n, -WALL_PX / 2, y0 / n, -WALL_PX / 2)
		frame.Size = UDim2.new((x1 - x0) / n, WALL_PX, (y1 - y0) / n, WALL_PX)
		frame.Visible = true
		frame.Parent = board
		table.insert(made, frame)
	end

	-- Walls merged into runs, with gaps in the border at the entrance and exit.
	local function drawWalls(grid: Grid)
		local function closed(x: number, y: number, dir: number): boolean
			local inside = x >= 0 and x < n and y >= 0 and y < n
			if not inside then
				return false
			end
			local cell = cellOf(n, x, y)
			if (cell == grid.start and dir == grid.startSide) or (cell == grid.exit and dir == grid.exitSide) then
				return false
			end
			return not grid.open[cell][dir]
		end
		for line = 0, n do
			local runFrom: number? = nil
			for x = 0, n do
				local shut = x < n and (closed(x, line, 1) or closed(x, line - 1, 3))
				if shut and not runFrom then
					runFrom = x
				elseif not shut and runFrom then
					wall(runFrom, line, x, line)
					runFrom = nil
				end
			end
			runFrom = nil
			for y = 0, n do
				local shut = y < n and (closed(line, y, 4) or closed(line - 1, y, 2))
				if shut and not runFrom then
					runFrom = y
				elseif not shut and runFrom then
					wall(line, runFrom, line, y)
					runFrom = nil
				end
			end
		end
	end

	local function trail(a: number, b: number)
		local ax, ay = xyOf(n, a)
		local bx, by = xyOf(n, b)
		local frame = trailTemplate:Clone()
		frame.Name = "Trail"
		frame.Position = UDim2.fromScale((math.min(ax, bx) + 0.5) / n, (math.min(ay, by) + 0.5) / n)
			- UDim2.fromOffset(TRAIL_PX / 2, TRAIL_PX / 2)
		frame.Size = UDim2.new(math.abs(bx - ax) / n, TRAIL_PX, math.abs(by - ay) / n, TRAIL_PX)
		frame.Visible = true
		frame.Parent = board
		table.insert(made, frame)
	end

	local impuritiesLeft = info.impurities
	local mazesLeft = math.ceil(goal)
	local grid: Grid
	local cell: number
	local impurities: { [number]: Frame } = {}

	local function newMaze()
		clear()
		table.clear(impurities)
		grid = generate(n, rng)
		cell = grid.start
		drawWalls(grid)
		local count = math.ceil(impuritiesLeft / math.max(1, mazesLeft))
		mazesLeft -= 1
		for _, spot in impuritySpots(grid, count, rng) do
			local frame = impurityTemplate:Clone()
			frame.Name = "Impurity"
			frame.Position = center(spot)
			frame.Size = UDim2.fromScale(0.5 / n, 0.5 / n)
			frame.Visible = true
			frame.Parent = board
			table.insert(made, frame)
			impurities[spot] = frame
			impuritiesLeft -= 1
		end
		exitMark.Position = center(grid.exit)
		exitMark.Size = UDim2.fromScale(0.8 / n, 0.8 / n)
		exitMark.Visible = true
		spark.Position = center(cell)
		spark.Size = UDim2.fromScale(0.55 / n, 0.55 / n)
		spark.Visible = true
	end

	-- the slide in progress: from `cell` toward `to` along `dir`
	local moving: { dir: number, to: number, progress: number }? = nil
	local wanted: number? = nil
	local pauseUntil = 0
	local t, solved, purged, nudge = 0, 0, 0, 0

	local function tryStart(dir: number): boolean
		if grid.open[cell][dir] then
			local x, y = xyOf(n, cell)
			moving = { dir = dir, to = cellOf(n, x + DX[dir], y + DY[dir]), progress = 0 }
			return true
		end
		return false
	end

	local function want(dir: number)
		if t < pauseUntil then
			return
		end
		local slide = moving
		if slide and dir == opposite(slide.dir) then
			-- turn back on the spot
			cell, slide.to = slide.to, cell
			slide.dir = dir
			slide.progress = 1 - slide.progress
			wanted = nil
		elseif slide then
			wanted = dir
		elseif not tryStart(dir) then
			nudge = 0.12
			Feel.buzz(0.15, 0.05)
		end
	end

	local function heldKey(): number?
		for key, dir in KEYS do
			if UserInputService:IsKeyDown(key) then
				return dir
			end
		end
		return nil
	end

	-- Arrived at a cell: purge, escape, or decide whether to keep sliding.
	local function arrive(dir: number)
		local frame = impurities[cell]
		if frame then
			impurities[cell] = nil
			purged += 1
			Feel.pop(board, center(cell), IMPURE)
			Feel.buzz(0.3, 0.08)
			frame:Destroy()
		end
		if cell == grid.exit then
			moving = nil
			wanted = nil
			solved += 1
			Feel.pop(board, center(cell), EXIT, 140)
			Feel.buzz(0.5, 0.12)
			ui.flow.Text = "Escaped!"
			pauseUntil = t + NEXT_PAUSE
			task.delay(NEXT_PAUSE, function()
				ui.flow.Text = ""
			end)
			return
		end
		if wanted and wanted ~= opposite(dir) and tryStart(wanted) then
			wanted = nil
			return
		end
		local onward = {}
		for d = 1, 4 do
			if d ~= opposite(dir) and grid.open[cell][d] then
				table.insert(onward, d)
			end
		end
		if #onward == 1 then
			tryStart(onward[1])
		else
			moving = nil
			local queued = wanted
			wanted = nil
			if queued then
				want(queued)
			end
		end
	end

	local anchors: { [InputObject]: Vector3 } = {}
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			anchors[input] = input.Position
		elseif KEYS[input.KeyCode] then
			want(KEYS[input.KeyCode])
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		local key: InputObject? = input
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- the held mouse button's InputObject carries the anchor
			key = nil
			for held in anchors do
				if held.UserInputType == Enum.UserInputType.MouseButton1 then
					key = held
				end
			end
		end
		local anchor = key and anchors[key]
		if not (key and anchor) then
			return
		end
		local delta = input.Position - anchor
		if delta.Magnitude >= SWIPE_PX then
			anchors[key] = input.Position
			if math.abs(delta.X) > math.abs(delta.Y) then
				want(if delta.X > 0 then 2 else 4)
			else
				want(if delta.Y > 0 then 3 else 1)
			end
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		anchors[input] = nil
	end))

	newMaze()
	local finished = false
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		dt = math.min(dt, 0.1)
		t += dt

		if t >= pauseUntil and cell == grid.exit then
			newMaze()
		end
		if t >= pauseUntil and not moving then
			local key = heldKey()
			if key then
				tryStart(key)
			end
		end
		local slide = moving
		if slide then
			slide.progress += SLIDE_SPEED * dt
			while slide and slide.progress >= 1 do
				local carry = slide.progress - 1
				trail(cell, slide.to)
				cell = slide.to
				arrive(slide.dir)
				slide = moving
				if slide then
					slide.progress = carry
				end
			end
		end
		local at = center(cell)
		if slide then
			local to = center(slide.to)
			at = at:Lerp(to, slide.progress)
		end
		if nudge > 0 then
			nudge = math.max(0, nudge - dt)
			at += UDim2.fromOffset(math.sin(t * 90) * 3, 0)
		end
		spark.Position = at
		spark.BackgroundColor3 = if t < pauseUntil then EXIT else QI

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `Escaped {solved} / {math.ceil(goal)}`
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
	-- partial credit for how far along the current maze you got
	local along = 0
	if cell ~= grid.exit then
		local total = grid.toExit[grid.start]
		along = math.clamp(1 - grid.toExit[cell] / math.max(1, total), 0, 1)
	end
	clear()
	spark.Visible = false
	exitMark.Visible = false
	return math.min(1, (solved + along) / goal), purged
end

return Maze
