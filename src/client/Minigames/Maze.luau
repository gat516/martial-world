--!strict
-- Maze Formation. Your qi is caught in a maze formation; find the way out, like
-- the maze on a cereal box. Drag anywhere and the spark moves with your finger
-- (relative, so the finger never hides it), held to the corridors; hold WASD /
-- the arrows to walk it. It only moves while you drag or hold, and stops when you
-- stop. Pushing across a corridor near a turning takes the turning, so corners
-- don't need pixel-perfect drags. Escape and a new maze forms, as many
-- as the run allows. Purple impurities sit in dead ends off the way out: detour
-- through one to purge it. Accuracy is mazes escaped (plus how far along the
-- current one) against the run's par.
--
-- Maze size and par seconds per maze come from Config (Games.Maze).

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Feel = require(script.Parent.Feel)

local KEY_SPEED = 6 -- cells per second while an arrow key is held
local DRAG_GAIN = 1 -- spark pixels per dragged pixel
local CORNER = 0.4 -- pushing across a corridor this close (in cells) to a turning takes it
local EPS = 1e-4
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
Maze.HINT = "Drag to guide your qi through the formation and find the way out. Detour through purple impurities to purge them."

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
	local impurities: { [number]: Frame } = {}

	local function newMaze()
		clear()
		table.clear(impurities)
		grid = generate(n, rng)
		px, py = xyOf(n, grid.start)
		table.clear(walked)
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
		spark.Position = center(grid.start)
		spark.Size = UDim2.fromScale(0.55 / n, 0.55 / n)
		spark.Visible = true
	end

	-- The spark sits on a corridor's centre line, at (px, py) in cells (cell
	-- centres are whole numbers).
	local px, py = 0, 0
	local walked: { [string]: boolean } = {} -- corridors already trailed
	local pauseUntil = 0
	local t, solved, purged, nudge = 0, 0, 0, 0

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
			Feel.buzz(0.3, 0.08)
			frame:Destroy()
		end
		if to == grid.exit then
			solved += 1
			Feel.pop(board, center(to), EXIT, 140)
			Feel.buzz(0.5, 0.12)
			ui.flow.Text = "Escaped!"
			pauseUntil = t + NEXT_PAUSE
			task.delay(NEXT_PAUSE, function()
				ui.flow.Text = ""
			end)
		end
	end

	-- Move the spark by (dx, dy) cells along the corridors; walls stop it. Pushing
	-- across a corridor just short of or past a turning slides it to the turning.
	local function move(dx: number, dy: number)
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
					math.abs(across) > math.abs(along)
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

	local held: { number } = {} -- held arrow keys' directions, latest last
	local lasts: { [InputObject]: Vector3 } = {} -- each drag's last position
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1 then
			lasts[input] = input.Position
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
		local key: InputObject? = input
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- the held mouse button's InputObject carries the drag
			key = nil
			for down in lasts do
				if down.UserInputType == Enum.UserInputType.MouseButton1 then
					key = down
				end
			end
		end
		local last = key and lasts[key]
		if not (key and last) then
			return
		end
		lasts[key] = input.Position
		local cellPx = math.max(1, board.AbsoluteSize.X / n)
		local delta = (input.Position - last) * DRAG_GAIN / cellPx
		move(delta.X, delta.Y)
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		lasts[input] = nil
		local dir = KEYS[input.KeyCode]
		if dir then
			local at = table.find(held, dir)
			if at then
				table.remove(held, at)
			end
		end
	end))

	newMaze()
	local finished = false
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if finished then
			return
		end
		dt = math.min(dt, 0.1)
		t += dt

		local ex, ey = xyOf(n, grid.exit)
		if t >= pauseUntil and math.abs(px - ex) < EPS and math.abs(py - ey) < EPS then
			newMaze()
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
		local at = UDim2.fromScale((px + 0.5) / n, (py + 0.5) / n)
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
	local cell = cellOf(n, math.round(px), math.round(py))
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
