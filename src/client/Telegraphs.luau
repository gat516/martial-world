--!strict
-- Ground telegraphs for every attack that hurts (docs/systems/telegraphs.md).
-- Shapes come from the server (EnemyService.Shape): box, circle or cone, a barrage
-- (`parts`), with the enemy, attack name and the server time it started
-- (EnemyService.strike sends no enemy).
--
-- Two looks, switched by Config.NEW_TELEGRAPHS (on in the testbed only until the
-- user approves):
--   new     one danger orange: a thin bright edge with a soft glow and a very faint
--           fill; a brighter timing fill grows to the edge as the blow lands (circles
--           from the centre, boxes from the attacker, cones out from the apex); the
--           edge brightens and swells in the last PULSE s; fades in FADE s at release.
--           `telegraph = "heavy"` on the attack def: stronger fills, a double edge,
--           an earlier, longer pulse. Barrage parts share one faint fill (none of
--           their own). Projectile lanes (`aim = "rails"`, barrage `bolt` lanes and
--           `bolt` attacks) draw two rails that vanish on release; lobs (`lob`) a
--           reticle whose ring closes onto the landing edge; attacks with
--           `poolSeconds` keep a dim breathing edge for the pool's life. Howl shapes
--           draw nothing. Circles and boxes are one SurfaceGui part each (UIStroke
--           edges), cones one anchor part with Beams.
--   legacy  the old red outline and growing fill (the main game today).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Enemies = require(ReplicatedStorage.Shared.Enemies)

local NEW = (Config :: any).NEW_TELEGRAPHS == true

local RED = Color3.fromRGB(255, 40, 30)
local LIFT = 0.15 -- studs above the ground, so the decal doesn't z-fight
local THICKNESS = 0.2

-- new look: tuning knobs
local DANGER = Color3.fromRGB(255, 118, 30) -- every enemy, every element
local EDGE_MIN = 0.5 -- studs: never thinner (phones at 40 studs)
local EDGE_SHARE = 0.045 -- edge width as a share of the radius / half-width
local EDGE_MAX = 1.3
local EDGE_OPACITY = 0.8 -- the edge before the pulse (1 at the pulse)
local GLOW_WIDTH = 3.2 -- the soft glow round the edge, in edge widths
local GLOW_OPACITY = 0.2
local FILL_OPACITY = 0.07 -- the faint body
local TIMING_OPACITY = 0.26 -- the timing fill
local HEAVY_FILL, HEAVY_TIMING = 0.14, 0.4
local HEAVY_INSET = 2.6 -- the heavy tier's inner edge, in edge widths in from the outer
local PULSE = 0.25 -- s before impact: the edge brightens and swells once
local HEAVY_PULSE = 0.5
local PULSE_WIDEN = 0.6 -- share the edge widens at the pulse's peak
local FADE = 0.15 -- s to fade at release
local BARRAGE_TIMING = 0.16 -- a barrage part's timing fill (no faint fill of its own)
local LINGER_OPACITY = 0.4 -- a pool's edge while it hurts, breathing
local LINGER_BREATH = 1.8 -- s per breath
local RAIL_WIDTH = 0.5 -- a projectile lane's rails
local RAIL_DRAW = 0.2 -- s for the rails to run out from the mouth
local RAIL_FADE = 0.08 -- s: the rails vanish as the shot leaves
local RETICLE_START = 1.8 -- a lob's closing ring starts at this many radii
local MARK_RADIUS = 3.5 -- a homing shot's ring under its target
local MAX_CANVAS = 1024 -- px: a SurfaceGui's longest side
local MAX_PPS = 24

local Telegraphs = {}

local folder = workspace.CurrentCamera

local function part(size: Vector3, cframe: CFrame, transparency: number, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Size = size
	p.CFrame = cframe
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- Flat triangle a-b-c (all at the same height) from two wedges.
local function triangle(a: Vector3, b: Vector3, c: Vector3, transparency: number): { Part }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = part(Vector3.new(THICKNESS, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), transparency)
	local w2 = part(Vector3.new(THICKNESS, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), transparency)
	for _, w in { w1, w2 } do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = w
	end
	return { w1, w2 }
end

local function cone(center: Vector3, look: Vector3, radius: number, angle: number, transparency: number): { Part }
	local parts = {}
	local segments = math.max(3, math.ceil(angle / 15))
	local base = math.atan2(-look.X, -look.Z)
	local half = math.rad(angle) / 2
	local function at(i: number): Vector3
		local a = base - half + (2 * half) * i / segments
		return center + Vector3.new(-math.sin(a), 0, -math.cos(a)) * radius
	end
	for i = 0, segments - 1 do
		for _, p in triangle(center, at(i), at(i + 1), transparency) do
			table.insert(parts, p)
		end
	end
	return parts
end

-- `startedAt` (server time the attack began) shortens a late telegraph so its
-- fill still finishes the moment the blow lands on the server.
local function legacyShow(shape: any, seconds: number, _model: Instance?, _attack: string?, startedAt: number?)
	if type(startedAt) == "number" then
		seconds = math.max(0.05, seconds - (workspace:GetServerTimeNow() - startedAt))
	end
	local outline: { BasePart } = {}
	local fill: { BasePart } = {}
	local lift = Vector3.new(0, LIFT, 0)
	-- a barrage or retreat (Nine-Tailed Fox): each sub-area fills until the windup ends
	-- plus its own delay, so a sequence reads left to right or ring by ring
	if shape.parts then
		for _, sub in shape.parts do
			if not sub.hidden then
				legacyShow(sub, seconds + (sub.delay or 0), nil, nil, nil)
			end
		end
	end
	if shape.kind == "box" then
		local cframe = shape.cframe + lift
		local size = shape.size :: Vector2
		table.insert(outline, part(Vector3.new(size.X, THICKNESS, size.Y), cframe, 0.65))
		-- the fill grows from the attacker's end toward the far end
		local start = part(Vector3.new(size.X, THICKNESS * 1.2, 0.05), cframe * CFrame.new(0, 0, size.Y / 2), 0.35)
		TweenService:Create(start, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Size = Vector3.new(size.X, THICKNESS * 1.2, size.Y),
			CFrame = cframe,
		}):Play()
		table.insert(fill, start)
	elseif shape.kind == "circle" then
		local center = shape.center + lift
		local r = shape.radius :: number
		local rotated = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(outline, part(Vector3.new(THICKNESS, r * 2, r * 2), rotated, 0.65, Enum.PartType.Cylinder))
		local grow = part(Vector3.new(THICKNESS * 1.2, 0.1, 0.1), rotated, 0.35, Enum.PartType.Cylinder)
		TweenService:Create(grow, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = Vector3.new(THICKNESS * 1.2, r * 2, r * 2) }):Play()
		table.insert(fill, grow)
	elseif shape.kind == "howl" then
		-- a summon: a pale ring that swells around the caster (no damage). Bosses
		-- skip it: their roars, intros and phase calls have their own effects
		-- (EnemyFX), and the flat disc under them read as a cheap placeholder.
		local id = _model and _model:GetAttribute("EnemyType")
		local def = type(id) == "string" and (Enemies.Defs :: any)[id]
		if def and def.boss then
			return
		end
		local center = shape.center + lift
		local ring = part(Vector3.new(THICKNESS, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), 0.4, Enum.PartType.Cylinder)
		ring.Color = Color3.fromRGB(255, 220, 150)
		local r = (shape.radius :: number) * 3
		TweenService:Create(ring, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(THICKNESS, r * 2, r * 2),
			Transparency = 0.9,
		}):Play()
		table.insert(outline, ring)
	elseif shape.kind == "cone" then
		local look = (shape.cframe :: CFrame).LookVector
		for _, p in cone(shape.center + lift, look, shape.radius, shape.size.X, 0.6) do
			table.insert(outline, p)
		end
		-- no growing fill for cones; the outline brightens as it lands
		task.delay(seconds * 0.75, function()
			for _, p in outline do
				if p.Parent then
					p.Transparency = 0.3
				end
			end
		end)
	end
	for _, list in { outline, fill } do
		for _, p in list do
			Debris:AddItem(p, seconds + 0.12)
		end
	end
end


--[[ New look ]]

type Look = {
	t: number, -- s since it started
	k: number, -- 0..1 timing (1 = the blow lands)
	edge: number, -- edge opacity
	widen: number, -- edge width multiplier
	fill: number, -- faint fill opacity
	timing: number, -- timing fill opacity
	fade: number, -- 1 -> 0 over the release fade
}

type Live = {
	started: number,
	seconds: number,
	pulse: number,
	fill: number,
	timing: number,
	linger: number,
	fadeLen: number,
	part: BasePart,
	draw: (Look) -> (),
	follow: (() -> Vector3?)?,
}

local live: { Live } = {}

local function edgeWidth(size: number): number
	return math.clamp(size * EDGE_SHARE, EDGE_MIN, EDGE_MAX)
end

-- the def's attack table for this telegraph (heavy tier, pools, bolts)
local attackCache: { [string]: any } = {}
local function find(node: any, name: string, depth: number): any
	if depth > 6 then
		return nil
	end
	if node.name == name and node.kind then
		return node
	end
	for _, v in node do
		if type(v) == "table" then
			local hit = find(v, name, depth + 1)
			if hit then
				return hit
			end
		end
	end
	return nil
end

local function attackDef(model: Instance?, name: string?): any
	if typeof(model) ~= "Instance" or type(name) ~= "string" then
		return nil
	end
	local id = (model :: Instance):GetAttribute("EnemyType")
	if type(id) ~= "string" then
		return nil
	end
	local key = id .. "/" .. name
	local cached = attackCache[key]
	if cached == nil then
		local def = (Enemies.Defs :: any)[id]
		cached = def and find(def, name, 0) or false
		attackCache[key] = cached
	end
	return cached or nil
end

local function anchor(cframe: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cframe
	return p
end

-- A flat part with a SurfaceGui on top. GUI x runs along the part's -Z (x = 0 at
-- +Z), GUI y along +X (y = 0 at -X).
local function surface(cframe: CFrame, across: number, along: number): (Part, SurfaceGui, number)
	local p = anchor(cframe, Vector3.new(across, 0.05, along))
	local pps = math.min(MAX_PPS, MAX_CANVAS / math.max(across, along))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.ClipsDescendants = false
	gui.Parent = p
	return p, gui, pps
end

local function frame(parent: Instance, round: boolean): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundColor3 = DANGER
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

-- An outline: a transparent frame whose stroke spans [outer - width, outer].
-- `w`, `h` are the outline's outer size in studs (a circle: w = h = 2r).
type Outline = { set: (w: number, h: number, width: number, opacity: number) -> () }
local function outline(parent: Instance, pps: number, round: boolean): Outline
	local f = frame(parent, round)
	local stroke = Instance.new("UIStroke")
	stroke.Color = DANGER
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = if round then Enum.LineJoinMode.Round else Enum.LineJoinMode.Miter
	stroke.Parent = f
	return {
		set = function(w: number, h: number, width: number, opacity: number)
			f.Size = UDim2.fromOffset(math.max(0, w - 2 * width) * pps, math.max(0, h - 2 * width) * pps)
			stroke.Thickness = width * pps
			stroke.Transparency = 1 - opacity
		end,
	}
end

-- edge + glow (+ the heavy inner edge) round an outer w x h, the shared part of
-- circles and boxes
local function edges(parent: Instance, pps: number, round: boolean, heavy: boolean, w: number, h: number, ew: number): (Look) -> ()
	local glow = outline(parent, pps, round)
	local edge = outline(parent, pps, round)
	local inner = if heavy then outline(parent, pps, round) else nil
	return function(look: Look)
		local width = ew * look.widen
		local g = ew * GLOW_WIDTH * look.widen
		-- the glow straddles the edge's centre line
		local grow = g - ew
		glow.set(w + grow, h + grow, g, GLOW_OPACITY * look.edge * look.fade)
		edge.set(w, h, width, look.edge * look.fade)
		if inner then
			local inset = 2 * ew * HEAVY_INSET
			inner.set(w - inset, h - inset, ew * 0.55, look.edge * 0.8 * look.fade)
		end
	end
end

local function circle(center: Vector3, r: number, heavy: boolean, reticle: boolean): (Part, (Look) -> ())
	local ew = edgeWidth(r)
	local span = 2 * r * (if reticle then RETICLE_START else 1) + 2 * ew * GLOW_WIDTH * 2
	local p, gui, pps = surface(CFrame.new(center + Vector3.new(0, LIFT, 0)), span, span)
	local body = frame(gui, true)
	local inside = 2 * (r - ew)
	body.Size = UDim2.fromOffset(inside * pps, inside * pps)
	local timing = frame(gui, true)
	local drawEdges = edges(gui, pps, true, heavy, 2 * r, 2 * r, ew)
	local closing = if reticle then outline(gui, pps, true) else nil
	local ticks: { Frame } = {}
	if reticle then
		-- four ticks pointing in from the edge and a centre dot: a landing mark
		for i, at in { Vector2.new(0.5, 0), Vector2.new(0.5, 1), Vector2.new(0, 0.5), Vector2.new(1, 0.5) } do
			local tick = frame(body, false)
			tick.Position = UDim2.fromScale(at.X, at.Y)
			local long, thin = math.max(1.2, r * 0.22) * pps, ew * pps
			tick.Size = if i <= 2 then UDim2.fromOffset(thin, long) else UDim2.fromOffset(long, thin)
			table.insert(ticks, tick)
		end
		local dot = frame(body, true)
		dot.Size = UDim2.fromOffset(ew * 1.6 * pps, ew * 1.6 * pps)
		table.insert(ticks, dot)
	end
	return p, function(look: Look)
		body.BackgroundTransparency = 1 - look.fill * look.fade
		if closing then
			-- the reticle: a ring closing from RETICLE_START radii onto the edge
			timing.BackgroundTransparency = 1
			local d = 2 * r * (RETICLE_START - (RETICLE_START - 1) * look.k)
			closing.set(d, d, ew * look.widen, math.min(1, look.edge + 0.1) * look.fade * (if look.k >= 1 then 0 else 1))
			for _, tick in ticks do
				tick.BackgroundTransparency = 1 - look.edge * look.fade
			end
		else
			local d = inside * look.k
			timing.Size = UDim2.fromOffset(d * pps, d * pps)
			timing.BackgroundTransparency = 1 - look.timing * look.fade
		end
		drawEdges(look)
	end
end

local function box(cframe: CFrame, size: Vector2, heavy: boolean): (Part, (Look) -> ())
	local width, length = size.X, size.Y
	local ew = edgeWidth(math.min(width, length) / 2)
	local pad = 2 * ew * GLOW_WIDTH
	local p, gui, pps = surface(cframe, width + pad, length + pad)
	-- GUI x = along the lane (0 = the attacker's end), y = across
	local w, h = length, width
	local body = frame(gui, false)
	body.Size = UDim2.fromOffset((w - 2 * ew) * pps, (h - 2 * ew) * pps)
	local timing = frame(gui, false)
	timing.AnchorPoint = Vector2.new(0, 0.5)
	local drawEdges = edges(gui, pps, false, heavy, w, h, ew)
	local start = (pad / 2 + ew) * pps
	return p, function(look: Look)
		body.BackgroundTransparency = 1 - look.fill * look.fade
		timing.Position = UDim2.new(0, start, 0.5, 0)
		timing.Size = UDim2.fromOffset((w - 2 * ew) * look.k * pps, (h - 2 * ew) * pps)
		timing.BackgroundTransparency = 1 - look.timing * look.fade
		drawEdges(look)
	end
end

-- A projectile's lane: two rails along its sides that run out from the mouth,
-- fade toward the far end, brighten before release and vanish when it fires.
local function rails(cframe: CFrame, size: Vector2): (Part, (Look) -> ())
	local width, length = size.X, size.Y
	local p, gui, pps = surface(cframe, width + 2 * RAIL_WIDTH, length)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	local list: { Frame } = {}
	for _, y in { 0, 1 } do
		local rail = frame(gui, false)
		rail.AnchorPoint = Vector2.new(0, y)
		rail.Position = UDim2.fromScale(0, y)
		rail.BackgroundTransparency = 0
		fade:Clone().Parent = rail
		table.insert(list, rail)
	end
	return p, function(look: Look)
		local run = math.clamp(look.t / RAIL_DRAW, 0, 1)
		local thick = RAIL_WIDTH * look.widen
		for _, rail in list do
			rail.Size = UDim2.fromOffset(length * run * pps, thick * pps)
			rail.BackgroundTransparency = 1 - look.edge * look.fade
		end
	end
end

-- Beams on an anchor part, lying flat: attachments with Axis along the path and
-- SecondaryAxis horizontal.
local function attach(p: Part, position: Vector3, axis: Vector3): Attachment
	local a = Instance.new("Attachment")
	local side = Vector3.yAxis:Cross(axis)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	a.CFrame = CFrame.fromMatrix(position, axis.Unit, side)
	a.Parent = p
	return a
end

local function beam(p: Part, a0: Attachment, a1: Attachment, segments: number): Beam
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = false
	b.Color = ColorSequence.new(DANGER)
	b.LightEmission, b.LightInfluence, b.Brightness = 0, 0, 1
	b.Segments = segments
	b.Transparency = NumberSequence.new(1)
	b.Parent = p
	return b
end

local function sector(center: Vector3, look: Vector3, r: number, degrees: number, heavy: boolean): (Part, (Look) -> ())
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.new(0, 0, -1)
	local origin = center + Vector3.new(0, LIFT, 0)
	local p = anchor(CFrame.lookAt(origin, origin + flatLook), Vector3.one * 0.2)
	local ew = edgeWidth(r)
	local angle = math.rad(math.min(degrees, 359))
	local half = angle / 2
	local function dirAt(a: number): Vector3
		return Vector3.new(-math.sin(a), 0, -math.cos(a))
	end
	local function tangent(a: number): Vector3
		return Vector3.new(-math.cos(a), 0, math.sin(a))
	end
	-- arcs (Bezier, at most 90 degrees each) at radius `at`
	local function arc(at: number): { Beam }
		local list = {}
		local n = math.ceil(angle / math.rad(90))
		for i = 0, n - 1 do
			local a0 = -half + angle * i / n
			local a1 = -half + angle * (i + 1) / n
			local k = 4 / 3 * math.tan((a1 - a0) / 4) * at
			local b = beam(p, attach(p, dirAt(a0) * at, tangent(a0)), attach(p, dirAt(a1) * at, tangent(a1)), 12)
			b.CurveSize0, b.CurveSize1 = k, k
			table.insert(list, b)
		end
		return list
	end
	local edgeBeams = arc(r - ew / 2)
	local glowBeams = arc(r - ew / 2)
	local innerBeams = if heavy then arc(r - ew * HEAVY_INSET) else {}
	if degrees < 359 then
		for _, a in { -half, half } do
			local d = dirAt(a)
			local a0, a1 = attach(p, Vector3.zero, d), attach(p, d * r, d)
			table.insert(edgeBeams, beam(p, a0, a1, 1))
			table.insert(glowBeams, beam(p, a0, a1, 1))
		end
	end
	-- fills: triangle slices of at most 20 degrees, corners on the arc
	local slices = math.ceil(angle / math.rad(20))
	local sliceHalf = angle / slices / 2
	local fillR = r - ew
	local fills: { Beam } = {}
	local timings: { { beam: Beam, tip: Attachment, d: Vector3 } } = {}
	for i = 0, slices - 1 do
		local d = dirAt(-half + angle * (i + 0.5) / slices)
		local apex = attach(p, Vector3.zero, d)
		local far = fillR * math.cos(sliceHalf)
		local f = beam(p, apex, attach(p, d * far, d), 1)
		f.Width0, f.Width1 = 0, 2 * fillR * math.sin(sliceHalf)
		table.insert(fills, f)
		local tip = attach(p, d * 0.01, d)
		local t = beam(p, apex, tip, 1)
		t.Width0 = 0
		table.insert(timings, { beam = t, tip = tip, d = d })
	end
	return p, function(look: Look)
		local edgeT = NumberSequence.new(1 - look.edge * look.fade)
		for _, b in edgeBeams do
			b.Width0 = ew * look.widen
			b.Width1 = b.Width0
			b.Transparency = edgeT
		end
		local glowT = NumberSequence.new(1 - GLOW_OPACITY * look.edge * look.fade)
		for _, b in glowBeams do
			b.Width0 = ew * GLOW_WIDTH * look.widen
			b.Width1 = b.Width0
			b.Transparency = glowT
		end
		local innerT = NumberSequence.new(1 - look.edge * 0.8 * look.fade)
		for _, b in innerBeams do
			b.Width0, b.Width1 = ew * 0.55, ew * 0.55
			b.Transparency = innerT
		end
		local fillT = NumberSequence.new(1 - look.fill * look.fade)
		for _, b in fills do
			b.Transparency = fillT
		end
		local reach = math.max(0.01, fillR * look.k)
		local timingT = NumberSequence.new(1 - look.timing * look.fade)
		for _, s in timings do
			s.tip.Position = s.d * reach * math.cos(sliceHalf)
			s.beam.Width1 = 2 * reach * math.sin(sliceHalf)
			s.beam.Transparency = timingT
		end
	end
end

local function lookAt(entry: Live, now: number): Look?
	local t = now - entry.started
	local s = entry.seconds
	local look: Look = { t = t, k = math.clamp(t / s, 0, 1), edge = EDGE_OPACITY, widen = 1, fill = entry.fill, timing = entry.timing, fade = 1 }
	if t < s then
		local into = t - (s - entry.pulse)
		if into > 0 then
			look.edge = EDGE_OPACITY + (1 - EDGE_OPACITY) * math.min(1, into / (entry.pulse * 0.4))
			look.widen = 1 + PULSE_WIDEN * math.sin(math.pi * into / entry.pulse)
		end
		return look
	end
	local after = t - s
	if after < entry.linger then
		-- a pool: the timing fill is spent, a dim edge breathes while it hurts
		local breath = 0.5 - 0.5 * math.cos(2 * math.pi * after / LINGER_BREATH)
		look.k, look.timing, look.fill = 0, 0, entry.fill * 0.6
		look.edge = LINGER_OPACITY * (1 - 0.45 * breath)
		look.fade = math.min(1, (entry.linger - after) / FADE)
		return look
	end
	local gone = after - entry.linger
	if entry.linger > 0 or gone >= entry.fadeLen then
		return nil
	end
	look.edge, look.fade = 1, 1 - gone / entry.fadeLen
	return look
end

local stepping: RBXScriptConnection? = nil
local function step()
	local now = os.clock()
	for i = #live, 1, -1 do
		local entry = live[i]
		local look = lookAt(entry, now)
		local follow = entry.follow
		local at = if look and follow then follow() else nil
		if look and follow and not at then
			look = nil
		end
		if look then
			if at then
				entry.part.CFrame = CFrame.new(at + Vector3.new(0, LIFT, 0))
			end
			entry.draw(look)
		else
			entry.part:Destroy()
			table.remove(live, i)
		end
	end
	if #live == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

type Style = { heavy: boolean, barrage: boolean, linger: number, rails: boolean, lob: boolean }

-- previews (Telegraphs.still): paint one frozen moment into a folder instead
local freeze: { t: number, parent: Instance }? = nil

local function add(p: Part, paint: (Look) -> (), seconds: number, style: Style, follow: (() -> Vector3?)?)
	local entry: Live = {
		started = os.clock(),
		seconds = math.max(0.05, seconds),
		pulse = if style.heavy then HEAVY_PULSE else PULSE,
		fill = if style.barrage then 0 elseif style.heavy then HEAVY_FILL else FILL_OPACITY,
		timing = if style.barrage then BARRAGE_TIMING elseif style.heavy then HEAVY_TIMING else TIMING_OPACITY,
		linger = style.linger,
		fadeLen = if style.rails then RAIL_FADE else FADE,
		part = p,
		draw = paint,
		follow = follow,
	}
	if freeze then
		local look = lookAt(entry, entry.started + freeze.t)
		if look then
			paint(look)
			p.Parent = freeze.parent
		else
			p:Destroy()
		end
		return
	end
	local first = lookAt(entry, entry.started)
	if first then
		paint(first)
	end
	p.Parent = folder
	table.insert(live, entry)
	if not stepping then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local function draw(shape: any, seconds: number, style: Style)
	if shape.parts then
		for _, sub in shape.parts do
			if not sub.hidden then
				local subStyle = table.clone(style)
				subStyle.barrage = true
				subStyle.rails = sub.bolt == true
				draw(sub, seconds + (sub.delay or 0), subStyle)
			end
		end
	end
	local p: Part?, fn: ((Look) -> ())? = nil, nil
	if shape.kind == "box" then
		local cframe = (shape.cframe :: CFrame) + Vector3.new(0, LIFT, 0)
		if style.rails or shape.aim == "rails" then
			style = table.clone(style)
			style.rails = true
			p, fn = rails(cframe, shape.size)
		else
			p, fn = box(cframe, shape.size, style.heavy)
		end
	elseif shape.kind == "circle" then
		p, fn = circle(shape.center, shape.radius, style.heavy, style.lob or shape.lob == true)
	elseif shape.kind == "cone" then
		local look = (shape.cframe :: CFrame).LookVector
		if shape.size.X >= 359 then
			p, fn = circle(shape.center, shape.radius, style.heavy, false)
		else
			p, fn = sector(shape.center, look, shape.radius, shape.size.X, style.heavy)
		end
	end
	-- "howl" (summons, roars), "multi" and "bound" draw nothing of their own
	if p and fn then
		add(p, fn, seconds, style)
	end
end

local function newShow(shape: any, seconds: number, model: Instance?, attack: string?)
	local def = attackDef(model, attack)
	local style: Style = {
		heavy = def ~= nil and def.telegraph == "heavy",
		barrage = false,
		linger = if def and type(def.poolSeconds) == "number" and shape.kind == "circle" then def.poolSeconds else 0,
		rails = def ~= nil and def.kind == "bolt" and shape.kind == "box",
		lob = false,
	}
	draw(shape, seconds, style)
end

-- `startedAt` (server time the attack began) shortens a late telegraph so its
-- fill still finishes the moment the blow lands on the server.
function Telegraphs.show(shape: any, seconds: number, model: Instance?, attack: string?, startedAt: number?)
	if type(shape) ~= "table" or type(seconds) ~= "number" then
		return
	end
	if not NEW then
		legacyShow(shape, seconds, model, attack, startedAt)
		return
	end
	if type(startedAt) == "number" then
		seconds = math.max(0.05, seconds - (workspace:GetServerTimeNow() - startedAt))
	end
	newShow(shape, seconds, model, attack)
end

-- A ring that follows a point (a homing shot's mark under its target) for
-- `seconds`, timing to the shot's release. `at` returns the ground point, or nil
-- to drop it. New look only (ProjectileView keeps its own ring otherwise).
function Telegraphs.follow(at: () -> Vector3?, seconds: number, radius: number?)
	local start = at()
	if not start then
		return
	end
	local p, fn = circle(start, radius or MARK_RADIUS, false, false)
	add(p, fn, seconds, { heavy = false, barrage = false, linger = 0, rails = false, lob = false }, at)
end

-- Edit-mode preview: draw `shape` (new look) frozen `t` s into a `seconds` windup,
-- into `parent`. `model`/`attack` pick the tier as live telegraphs do.
function Telegraphs.still(shape: any, seconds: number, t: number, parent: Instance, model: Instance?, attack: string?)
	freeze = { t = t, parent = parent }
	local ok, err = pcall(newShow, shape, seconds, model, attack)
	freeze = nil
	if not ok then
		error(err)
	end
end

Telegraphs.NEW = NEW

function Telegraphs.init()
	(ReplicatedStorage.Remotes.Telegraph :: RemoteEvent).OnClientEvent:Connect(Telegraphs.show)
end

return Telegraphs
