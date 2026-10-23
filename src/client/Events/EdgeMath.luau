--!strict
-- Screen-edge geometry for the world-event chips (WorldEventView): which way an
-- event lies on screen, where a chip for it sits on an inset rectangle, and how
-- chips sharing an edge keep apart. Pure math, so it can be checked numerically.
-- Positions are in the Events canvas's baseline pixels.

local EdgeMath = {}

export type Rect = { x0: number, y0: number, x1: number, y1: number }

-- The on-screen direction (unit, y down) from the screen centre toward a world point,
-- valid behind the camera too: the camera-space x and y keep their sign behind you, so
-- an event behind and to the right leads to the right edge, one straight behind and
-- below leads to the bottom.
function EdgeMath.direction(cameraFrame: CFrame, point: Vector3): Vector2
	local v = cameraFrame:PointToObjectSpace(point)
	local d = Vector2.new(v.X, -v.Y)
	if d.Magnitude < 1e-4 then
		return Vector2.new(0, 1)
	end
	return d.Unit
end

-- The rectangle chip centres move on: the screen less the HUD's insets, the chip's
-- own half extents (pointer included) and a margin, so the whole chip stays inside.
function EdgeMath.rect(size: Vector2, insets: { top: number, bottom: number, side: number }, half: Vector2, margin: number): Rect
	local x0 = insets.side + half.X + margin
	local x1 = size.X - insets.side - half.X - margin
	local y0 = insets.top + half.Y + margin
	local y1 = size.Y - insets.bottom - half.Y - margin
	if x1 < x0 then
		x0, x1 = (x0 + x1) / 2, (x0 + x1) / 2
	end
	if y1 < y0 then
		y0, y1 = (y0 + y1) / 2, (y0 + y1) / 2
	end
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

-- Where a ray from `from` (inside the rect) along `dir` meets the rect's border.
function EdgeMath.hit(r: Rect, from: Vector2, dir: Vector2): Vector2
	local cx = math.clamp(from.X, r.x0, r.x1)
	local cy = math.clamp(from.Y, r.y0, r.y1)
	local t = math.huge
	if dir.X > 1e-6 then
		t = math.min(t, (r.x1 - cx) / dir.X)
	elseif dir.X < -1e-6 then
		t = math.min(t, (r.x0 - cx) / dir.X)
	end
	if dir.Y > 1e-6 then
		t = math.min(t, (r.y1 - cy) / dir.Y)
	elseif dir.Y < -1e-6 then
		t = math.min(t, (r.y0 - cy) / dir.Y)
	end
	if t == math.huge then
		t = 0
	end
	return Vector2.new(math.clamp(cx + dir.X * t, r.x0, r.x1), math.clamp(cy + dir.Y * t, r.y0, r.y1))
end

function EdgeMath.perimeter(r: Rect): number
	return 2 * (r.x1 - r.x0) + 2 * (r.y1 - r.y0)
end

-- A border point as distance along the border, clockwise from the top-left corner.
function EdgeMath.param(r: Rect, p: Vector2): number
	local w, h = r.x1 - r.x0, r.y1 - r.y0
	local dTop, dRight = math.abs(p.Y - r.y0), math.abs(p.X - r.x1)
	local dBottom, dLeft = math.abs(p.Y - r.y1), math.abs(p.X - r.x0)
	local m = math.min(dTop, dRight, dBottom, dLeft)
	if m == dTop then
		return math.clamp(p.X - r.x0, 0, w)
	elseif m == dRight then
		return w + math.clamp(p.Y - r.y0, 0, h)
	elseif m == dBottom then
		return w + h + math.clamp(r.x1 - p.X, 0, w)
	end
	return 2 * w + h + math.clamp(r.y1 - p.Y, 0, h)
end

-- The border point at a distance along the border (wraps).
function EdgeMath.point(r: Rect, s: number): Vector2
	local w, h = r.x1 - r.x0, r.y1 - r.y0
	local per = 2 * w + 2 * h
	if per <= 0 then
		return Vector2.new(r.x0, r.y0)
	end
	s %= per
	if s < w then
		return Vector2.new(r.x0 + s, r.y0)
	elseif s < w + h then
		return Vector2.new(r.x1, r.y0 + s - w)
	elseif s < 2 * w + h then
		return Vector2.new(r.x1 - (s - w - h), r.y1)
	end
	return Vector2.new(r.x0, r.y1 - (s - 2 * w - h))
end

-- Keep chips apart along the border: sorted by distance, each one that overlaps the
-- one before it (boxes grown by `gap`) moves on clockwise until it's clear, round
-- corners too, so the order never swaps. Each is checked against all before it.
export type Item = { s: number, size: Vector2 }
local STEP = 2

local function overlaps(r: Rect, a: Item, b: Item, gap: number): boolean
	local pa, pb = EdgeMath.point(r, a.s), EdgeMath.point(r, b.s)
	return math.abs(pa.X - pb.X) < (a.size.X + b.size.X) / 2 + gap
		and math.abs(pa.Y - pb.Y) < (a.size.Y + b.size.Y) / 2 + gap
end

function EdgeMath.separate(r: Rect, items: { Item }, gap: number)
	table.sort(items, function(a, b)
		return a.s < b.s
	end)
	local per = EdgeMath.perimeter(r)
	local n = #items
	local function clash(i: number): boolean
		for j = 1, i - 1 do
			if overlaps(r, items[j], items[i], gap) then
				return true
			end
		end
		return false
	end
	for i = 2, n do
		-- never behind the one before (a push round a corner can carry it far on)
		items[i].s = math.max(items[i].s, items[i - 1].s)
		local guard = 0
		while clash(i) and guard < per / STEP do
			items[i].s += STEP
			guard += 1
		end
	end
end

-- Ease a border distance toward a target the short way round, so a chip slides along
-- the edges (round the corners) instead of cutting across the screen.
function EdgeMath.ease(r: Rect, s: number, target: number, k: number): number
	local per = EdgeMath.perimeter(r)
	if per <= 0 then
		return target
	end
	local d = (target - s + per / 2) % per - per / 2
	return (s + d * k) % per
end

-- Ease an angle (radians) the short way round, turning at most `maxStep` (radians)
-- this frame: an event passing straight behind you swings the chip round the bottom
-- edge calmly instead of flicking it across.
function EdgeMath.easeAngle(a: number, target: number, k: number, maxStep: number?): number
	local d = ((target - a + math.pi) % (2 * math.pi) - math.pi) * k
	if maxStep then
		d = math.clamp(d, -maxStep, maxStep)
	end
	return a + d
end

return EdgeMath
