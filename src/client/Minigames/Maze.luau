--!strict
-- Maze Formation. Your qi is caught in a maze formation; find the way out, like
-- the maze on a cereal box. The spark runs to where you point: the mouse over
-- the board (no click; the OS arrow gives way to the qi pointer there), or your
-- finger while it's down. It slides along the open corridors toward the pointer
-- (closing FOLLOW of the gap a second, never faster than MAX_SPEED), and a wall
-- in the way stops it there, with a faint tether from the spark to the pointer
-- so you can see where you're pulling. Hold WASD / the arrows to walk it
-- instead. Pushing across a corridor near a turning takes the turning, so
-- corners don't need pixel-perfect aim. Each maze is a level: escape and the next
-- forms, until the server's number of levels is cleared (the run ends then) or
-- the clock runs out. Purple impurities sit in dead ends off the way out: detour
-- through one to purge it. A maze escaped within its par time is full accuracy;
-- slower costs a little (par / time, never below MIN_QUALITY).
--
-- Maze size and par seconds per maze come from Config (Games.Maze).

local MIN_QUALITY = 0.5 -- accuracy for a maze escaped far slower than its par

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

local KEY_SPEED = 6 -- cells per second while an arrow key is held
local FOLLOW = 24 -- share of the gap to the pointer the spark closes per second
local MAX_SPEED = 30 -- cells per second the spark can slide at most
local TURN_BIAS = 1.3 -- the pointer takes a turning only once it pulls this much more across than along
local TETHER_AT = 0.6 -- cells between spark and pointer before the tether shows (when a wall holds it)
local TETHER_PX = 8 -- tether thickness
local CORNER = 0.4 -- pushing across a corridor this close (in cells) to a turning takes it
local EPS = 1e-4
local WALL_SHARE = 0.1 -- wall line thickness as a share of a cell, in even pixels within WALL_PX
local WALL_PX = { 4, 8 }
local WALL_CORE = 0.4 -- share of maze_wall.png's width the gold line fills (the rest is its aura)
local TRAIL_SHARE = 0.3 -- qi trail thickness (glow included) as a share of a cell, within TRAIL_PX
local TRAIL_PX = { 10, 28 }
local SLICE_SOURCE = 128 -- maze_wall / maze_trail source size (9-slice Rect(63, 63, 65, 65))
local SPARK_SIZE, EXIT_SIZE, IMPURITY_SIZE = 0.85, 0.95, 0.62 -- in cells
local NEXT_PAUSE = 0.35 -- seconds between escaping and the next maze
local MIN_SIZE = 4

local IMPURE = Color3.fromRGB(220, 160, 255)
local EXIT = Color3.fromRGB(255, 225, 140)
local WHITE = Color3.new(1, 1, 1)

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
Maze.HINT = "Point where your qi should go and it follows through the formation. Find the way out; detour through purple impurities to purge them."
Maze.TOUCH_HINT = "Hold your finger where your qi should go and it follows through the formation. Find the way out; detour through purple impurities to purge them."

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

function Maze.play(stage: Frame, info: Feel.Info, ui: Feel.Ui): (number, number, number)
	local tune = Feel.tune("Maze", info.difficulty)
	local n = math.max(MIN_SIZE, math.floor(tune.size + 0.5))
	local levels = info.levels or 1
	local field = stage:FindFirstChild("Field") :: Frame
	local board = field:FindFirstChild("Board") :: Frame
	local wallTemplate = board:FindFirstChild("WallTemplate") :: ImageLabel
	local trailTemplate = board:FindFirstChild("TrailTemplate") :: ImageLabel
	local impurityTemplate = board:FindFirstChild("ImpurityTemplate") :: ImageLabel
	local spark = board:FindFirstChild("Spark") :: ImageLabel
	local tether = board:FindFirstChild("Tether") :: ImageLabel
	local exitMark = board:FindFirstChild("Exit") :: ImageLabel
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

	-- Walls and trail are round-capped strokes, 9-sliced from one radially
	-- symmetric image so the caps meet as rounded joints. The wall's gold line is
	-- an even whole number of pixels (crisp at any board size); its image is
	-- wider by the aura around the line.
	local wallPx, trailPx = WALL_PX[1] / WALL_CORE, TRAIL_PX[1]
	local function measure()
		local cellPx = board.AbsoluteSize.X / n
		wallPx = math.clamp(2 * math.round(cellPx * WALL_SHARE / 2), WALL_PX[1], WALL_PX[2]) / WALL_CORE
		trailPx = math.clamp(math.round(cellPx * TRAIL_SHARE), TRAIL_PX[1], TRAIL_PX[2])
	end

	local function fadeIn(image: ImageLabel, seconds: number)
		image.ImageTransparency = 1
		TweenService:Create(image, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = 0,
		}):Play()
	end

	local function wall(x0: number, y0: number, x1: number, y1: number)
		local frame = wallTemplate:Clone()
		frame.Name = "Wall"
		frame.SliceScale = wallPx / SLICE_SOURCE
		frame.Position = UDim2.new(x0 / n, -wallPx / 2, y0 / n, -wallPx / 2)
		frame.Size = UDim2.new((x1 - x0) / n, wallPx, (y1 - y0) / n, wallPx)
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
		frame.SliceScale = trailPx / SLICE_SOURCE
		frame.Position = UDim2.fromScale((math.min(ax, bx) + 0.5) / n, (math.min(ay, by) + 0.5) / n)
			- UDim2.fromOffset(trailPx / 2, trailPx / 2)
		frame.Size = UDim2.new(math.abs(bx - ax) / n, trailPx, math.abs(by - ay) / n, trailPx)
		frame.Visible = true
		frame.Parent = board
		fadeIn(frame, 0.15)
		table.insert(made, frame)
	end

	-- The spark sits on a corridor's centre line, at (px, py) in cells (cell
	-- centres are whole numbers).
	local px, py = 0, 0
	local walked: { [string]: boolean } = {} -- corridors already trailed
	local mazeStart = 0 -- when the current maze began
	local t, solved, purged, nudge, total = 0, 0, 0, 0, 0 -- total: escaped mazes' accuracy, summed
	local grid: Grid
	local impurities: { [number]: ImageLabel } = {}

	local function newMaze()
		clear()
		table.clear(impurities)
		grid = generate(n, rng)
		px, py = xyOf(n, grid.start)
		table.clear(walked)
		measure()
		drawWalls(grid)
		mazeStart = t
		for _, spot in impuritySpots(grid, info.impurities, rng) do
			local frame = impurityTemplate:Clone()
			frame.Name = "Impurity"
			frame.Position = center(spot)
			frame.Size = UDim2.fromScale(IMPURITY_SIZE / n, IMPURITY_SIZE / n)
			frame.Visible = true
			frame.Parent = board
			table.insert(made, frame)
			impurities[spot] = frame
		end
		exitMark.Position = center(grid.exit)
		exitMark.Size = UDim2.fromScale(EXIT_SIZE / n, EXIT_SIZE / n)
		exitMark.Visible = true
		spark.Position = center(grid.start)
		spark.Size = UDim2.fromScale(SPARK_SIZE / n, SPARK_SIZE / n)
		spark.Visible = true
	end

	local pauseUntil = 0
	local veilAt: number? = nil -- when the veil starts to fall over an escaped maze
	local endAt: number? = nil -- the last maze is escaped: the run ends then

	local function isOpen(x: number, y: number, dir: number): boolean
		return grid.open[cellOf(n, x, y)][dir]
	end

	local function shrink(v: number, by: number): number
		return if v > 0 then math.max(0, v - by) else math.min(0, v + by)
	end

	-- Reached the centre of `to` from `from`: trail, purge, escape.
	local function arrive(from: number, to: number)
		local key = `{math.min(from, to)}:{math.max(from, to)}`
		if not walked[key] then
			walked[key] = true
			trail(from, to)
		end
		local frame = impurities[to]
		if frame then
			impurities[to] = nil
			purged += 1
			Feel.pop(board, center(to), IMPURE)
			Feel.burst(board, center(to), IMPURE, 90)
			Feel.sound("Purge")
			Feel.buzz(0.3, 0.08)
			frame:Destroy()
		end
		if to == grid.exit then
			solved += 1
			total += math.clamp(tune.par / math.max(0.01, t - mazeStart), MIN_QUALITY, 1)
			Feel.pop(board, center(to), EXIT, 140)
			Feel.burst(board, center(to), EXIT, 160)
			Feel.sound("Clear")
			Feel.buzz(0.5, 0.12)
			ui.flow.Text = "Escaped!"
			if solved >= levels then
				endAt = t + NEXT_PAUSE
				pauseUntil = math.huge
				return
			end
			veilAt = t + NEXT_PAUSE
			pauseUntil = t + NEXT_PAUSE + Feel.VEIL_IN
			task.delay(NEXT_PAUSE + Feel.VEIL_IN + 0.4, function()
				if ui.flow.Text == "Escaped!" then
					ui.flow.Text = ""
				end
			end)
		end
	end

	-- Move the spark by (dx, dy) cells along the corridors; walls stop it. Pushing
	-- across a corridor just short of or past a turning slides it to the turning.
	-- `bias`: how much more a push must pull across than along to take a
	-- turning (1 for keys; above 1 for the pointer, so a diagonal pull doesn't
	-- flick between the two ways at a junction).
	local function move(dx: number, dy: number, bias: number?)
		local turnBias = bias or 1
		for _ = 1, 64 do
			if t < pauseUntil then
				return
			end
			local cx, cy = math.round(px), math.round(py)
			local onRow, onColumn = math.abs(py - cy) < EPS, math.abs(px - cx) < EPS
			local dir: number? = nil
			local amount, byX = 0, true
			if onRow and onColumn then
				px, py = cx, cy
				local horiz, vert = if dx > 0 then 2 else 4, if dy > 0 then 3 else 1
				local xFirst = math.abs(dx) >= math.abs(dy)
				for _, useX in { xFirst, not xFirst } do
					local want = math.abs(if useX then dx else dy)
					local d = if useX then horiz else vert
					if want > EPS and isOpen(cx, cy, d) then
						dir, amount, byX = d, want, useX
						break
					end
				end
			else
				-- along this corridor, and across it
				local along, across = if onRow then dx else dy, if onRow then dy else dx
				local pos, near = if onRow then px else py, if onRow then cx else cy
				local acrossDir = if onRow then (if dy > 0 then 3 else 1) else (if dx > 0 then 2 else 4)
				local fwd, back = if onRow then 2 else 3, if onRow then 4 else 1
				if
					math.abs(across) > math.abs(along) * turnBias
					and math.abs(across) > EPS
					and math.abs(pos - near) <= CORNER
					and isOpen(if onRow then near else cx, if onRow then cy else near, acrossDir)
				then
					dir, amount, byX = if near > pos then fwd else back, math.abs(across), not onRow
				elseif math.abs(along) > EPS then
					dir, amount, byX = if along > 0 then fwd else back, math.abs(along), onRow
				end
			end
			if not dir then
				return
			end
			-- the next cell centre that way
			local tx, ty = px, py
			if dir == 2 then
				tx = math.floor(px + EPS) + 1
			elseif dir == 4 then
				tx = math.ceil(px - EPS) - 1
			elseif dir == 3 then
				ty = math.floor(py + EPS) + 1
			else
				ty = math.ceil(py - EPS) - 1
			end
			local gap = math.abs(tx - px) + math.abs(ty - py)
			local step = math.min(amount, gap)
			if byX then
				dx = shrink(dx, step)
			else
				dy = shrink(dy, step)
			end
			if step >= gap - EPS then
				px, py = tx, ty
				arrive(cellOf(n, tx - DX[dir], ty - DY[dir]), cellOf(n, tx, ty))
			else
				px += DX[dir] * step
				py += DY[dir] * step
			end
		end
	end

	newMaze()
	ui.ready()

	local held: { number } = {} -- held arrow keys' directions, latest last
	local finger: InputObject? = nil -- the touch steering the spark
	local grip = 0 -- 0..1, eases up while the spark is being steered
	local pointer = Feel.pointer(field, "qi")
	local tetherShown = 0 -- 0..1, eases toward showing while a wall holds the spark

	-- the board point under a screen point, in cells (cell centres are whole)
	local function cellsAt(screen: Vector2): Vector2
		local cellPx = math.max(1, board.AbsoluteSize.X / n)
		local p = (screen - board.AbsolutePosition) / cellPx - Vector2.new(0.5, 0.5)
		return Vector2.new(math.clamp(p.X, -0.5, n - 0.5), math.clamp(p.Y, -0.5, n - 0.5))
	end

	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			finger = finger or input
		elseif KEYS[input.KeyCode] then
			local dir = KEYS[input.KeyCode]
			table.insert(held, dir)
			local cx, cy = math.round(px), math.round(py)
			local atCentre = math.abs(px - cx) < EPS and math.abs(py - cy) < EPS
			if atCentre and t >= pauseUntil and not isOpen(cx, cy, dir) then
				nudge = 0.12
				Feel.buzz(0.15, 0.05)
			end
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		-- a thumb already down through the count-in takes hold where it is
		if input.UserInputType == Enum.UserInputType.Touch and not finger then
			finger = input
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input == finger then
			finger = nil
		end
		local dir = KEYS[input.KeyCode]
		if dir then
			local at = table.find(held, dir)
			if at then
				table.remove(held, at)
			end
		end
	end))

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
		local ex, ey = xyOf(n, grid.exit)
		if t >= pauseUntil and math.abs(px - ex) < EPS and math.abs(py - ey) < EPS then
			newMaze()
			Feel.veilOut(field)
		end
		-- held keys: the latest wins, an earlier one carries on until it can turn
		local latest, earlier = held[#held], held[#held - 1]
		if latest then
			local step = KEY_SPEED * dt
			local dx, dy = DX[latest] * step, DY[latest] * step
			if earlier and earlier ~= latest then
				dx += DX[earlier] * step * 0.99
				dy += DY[earlier] * step * 0.99
			end
			move(dx, dy)
		end
		-- the pointer: the mouse over the board, else a finger that's down
		local screen = pointer.step()
		local fingerAt = finger and finger.Position
		if fingerAt then
			screen = Vector2.new(fingerAt.X, fingerAt.Y)
		end
		local target = screen and cellsAt(screen)
		local held_ = false -- a wall holds the spark short of the pointer
		if target and t >= pauseUntil and #held == 0 then
			local gap = target - Vector2.new(px, py)
			if gap.Magnitude > 0.02 then
				local step = gap * math.min(1, FOLLOW * dt)
				local cap = MAX_SPEED * dt
				if step.Magnitude > cap then
					step = step.Unit * cap
				end
				local before = Vector2.new(px, py)
				move(step.X, step.Y, TURN_BIAS)
				local moved = (Vector2.new(px, py) - before).Magnitude
				held_ = gap.Magnitude > TETHER_AT and moved < step.Magnitude * 0.5
			end
		end
		tetherShown += ((if held_ then 1 else 0) - tetherShown) * math.min(1, dt * (if held_ then 10 else 16))
		if target and tetherShown > 0.02 then
			local cellPx = board.AbsoluteSize.X / n
			local from = (Vector2.new(px, py) + Vector2.new(0.5, 0.5)) * cellPx
			local to = (target + Vector2.new(0.5, 0.5)) * cellPx
			Feel.line(tether, from, to, TETHER_PX)
			tether.ImageTransparency = 1 - 0.5 * tetherShown
			tether.Visible = true
		else
			tether.Visible = false
		end

		local active = target ~= nil or #held > 0
		grip += ((if active then 1 else 0) - grip) * math.min(1, dt * 14)
		local size = SPARK_SIZE * (1 + 0.14 * grip + 0.04 * math.sin(t * 5)) / n
		spark.Size = UDim2.fromScale(size, size)
		exitMark.Rotation = (t * 24) % 360
		for spot, frame in impurities do
			local pulse = IMPURITY_SIZE * (1 + 0.08 * math.sin(t * 3 + spot)) / n
			frame.Size = UDim2.fromScale(pulse, pulse)
		end
		local at = UDim2.fromScale((px + 0.5) / n, (py + 0.5) / n)
		if nudge > 0 then
			nudge = math.max(0, nudge - dt)
			at += UDim2.fromOffset(math.sin(t * 90) * 3, 0)
		end
		spark.Position = at
		spark.ImageColor3 = if t < pauseUntil then EXIT else WHITE

		Feel.timer(ui.timer, t, info.duration)
		ui.score.Text = `Escaped {solved} / {levels}`
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
		spark.Visible = false
		exitMark.Visible = false
		local veil = field:FindFirstChild("Veil") :: Frame
		veil.BackgroundTransparency = 1
	end)
	return total / math.max(1, solved), purged, solved
end

return Maze
