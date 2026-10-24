--!strict
-- Placement rules, shared so the client's preview and the server's check agree.
-- The server is the authority: it re-runs Placement.check on every place and move.
--
-- Three kinds of geometry are kept apart:
--   visual     the item's model, as drawn
--   collision  its parts' own CanCollide geometry (what players bump into)
--   bounds     placement boxes, in the item's pivot space: by default the model's
--              bounding box; an item may narrow it (`footprint`, for canopies) or
--              replace it (`boxes`, for hollow things like the garden fence).
-- Pieces are tested against each other by their bounds (oriented-box overlap, with
-- clearance and soft overlap), found through a spatial hash. Everything else on the
-- peak that isn't a piece (rock, the bridge, the cave walls) is restricted geometry,
-- tested against the bounds with a precise GetPartsInPart probe.
--
-- Support: a placement mode says what holds a piece up.
--   floor    rays down from its base find an upward surface, within its `lift`;
--            items whose `on` has only "terrain" need natural ground (Build.GROUND, or a
--            peak tier's Ground terraces)
--   wall     a ray back from its rear face finds a vertical surface
--   ceiling  a ray up from its top finds a downward surface
--   socket   its base sits on a matching socket another piece offers
-- A piece resting on another piece (stacked, socketed or hung from it) depends on
-- it: storing a piece stores its dependents too, and moving one carries them along.

local Config = require(script.Parent.Config).Build
local BuildItems = require(script.Parent.BuildItems)
local Peak = require(script.Parent.Peak)

export type Mode = "floor" | "wall" | "ceiling" | "socket"
export type Box = { cf: CFrame, size: Vector3 } -- in pivot space, or in world space once placed
export type Entry = {
	piece: Instance,
	def: BuildItems.Def,
	pivot: CFrame,
	boxes: { Box }, -- world space
	min: Vector3, -- world AABB of the boxes
	max: Vector3,
}
export type Index = {
	peak: Model,
	entries: { [Instance]: Entry },
	cells: { [Vector2]: { Entry } },
}
export type Context = {
	peak: Model,
	frame: CFrame, -- the peak-local frame (Peak.frame)
	index: Index,
	ignore: { [Instance]: boolean }?, -- pieces being moved (they and their dependents)
	probe: BasePart, -- a block used for restricted-geometry queries (BuildKit.Probe)
}

local CELL = 8 -- spatial hash cell size, studs
local TOUCH = 0.06 -- boxes may touch or interpenetrate this much
local PROBE_INSET = 0.12 -- restricted-geometry probe shrinks by this on every side
local RAY_IN = 0.35 -- rays start this far inside the bounds
local RAY_GAP = 0.5 -- and reach this far past them (plus lift for floor items)
local SOCKET_SNAP = 0.25 -- studs between a base and a socket for it to count

local Placement = {}

local function pivotOf(inst: Instance): CFrame
	return if inst:IsA("Model") then inst:GetPivot() elseif inst:IsA("BasePart") then inst.CFrame else CFrame.identity
end

-- Bounds ------------------------------------------------------------------------

local boxCache: { [Instance]: { Box } } = setmetatable({}, { __mode = "k" }) :: any

-- Placement boxes of a model or piece, in its pivot space.
function Placement.boxes(inst: Instance, def: BuildItems.Def): { Box }
	local cached = boxCache[inst]
	if cached then
		return cached
	end
	local out: { Box } = {}
	if def.boxes then
		for _, b in def.boxes do
			table.insert(out, { cf = CFrame.new(b.at), size = b.size })
		end
	else
		local pivot = pivotOf(inst)
		local cf: CFrame, size: Vector3
		if inst:IsA("Model") then
			cf, size = inst:GetBoundingBox()
		else
			cf, size = (inst :: BasePart).CFrame, (inst :: BasePart).Size
		end
		-- axis-aligned box in pivot space around the (possibly rotated) bounding box
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = pivot:PointToObjectSpace(cf * (size / 2 * Vector3.new(sx, sy, sz)))
					lo, hi = lo:Min(p), hi:Max(p)
				end
			end
		end
		local centre, extent = (lo + hi) / 2, hi - lo
		if def.footprint then
			extent = Vector3.new(math.min(extent.X, def.footprint.X), extent.Y, math.min(extent.Z, def.footprint.Y))
		end
		table.insert(out, { cf = CFrame.new(centre), size = extent })
	end
	boxCache[inst] = out
	return out
end

function Placement.worldBoxes(pivot: CFrame, boxes: { Box }): { Box }
	local out = table.create(#boxes)
	for i, b in boxes do
		out[i] = { cf = pivot * b.cf, size = b.size }
	end
	return out
end

-- The pivot-space extremes of a set of boxes (all axis-aligned in pivot space).
function Placement.extent(boxes: { Box }): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, b in boxes do
		local c, h = b.cf.Position, b.size / 2
		lo, hi = lo:Min(c - h), hi:Max(c + h)
	end
	return lo, hi
end

local function aabb(boxes: { Box }): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, b in boxes do
		local h = b.size / 2
		local r = b.cf
		local e = Vector3.new(
			math.abs(r.XVector.X) * h.X + math.abs(r.YVector.X) * h.Y + math.abs(r.ZVector.X) * h.Z,
			math.abs(r.XVector.Y) * h.X + math.abs(r.YVector.Y) * h.Y + math.abs(r.ZVector.Y) * h.Z,
			math.abs(r.XVector.Z) * h.X + math.abs(r.YVector.Z) * h.Y + math.abs(r.ZVector.Z) * h.Z
		)
		lo, hi = lo:Min(r.Position - e), hi:Max(r.Position + e)
	end
	return lo, hi
end

-- Separating-axis test for two oriented boxes (half sizes), allowing `slack` of
-- interpenetration.
local function obbOverlap(a: CFrame, ha: Vector3, b: CFrame, hb: Vector3, slack: number): boolean
	local A = { a.XVector, a.YVector, a.ZVector }
	local B = { b.XVector, b.YVector, b.ZVector }
	local hA = { ha.X, ha.Y, ha.Z }
	local hB = { hb.X, hb.Y, hb.Z }
	local t = b.Position - a.Position
	local function separated(axis: Vector3): boolean
		local m = axis.Magnitude
		if m < 1e-5 then
			return false
		end
		local l = axis / m
		local ra = hA[1] * math.abs(A[1]:Dot(l)) + hA[2] * math.abs(A[2]:Dot(l)) + hA[3] * math.abs(A[3]:Dot(l))
		local rb = hB[1] * math.abs(B[1]:Dot(l)) + hB[2] * math.abs(B[2]:Dot(l)) + hB[3] * math.abs(B[3]:Dot(l))
		return math.abs(t:Dot(l)) > ra + rb - slack
	end
	for i = 1, 3 do
		if separated(A[i]) or separated(B[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(A[i]:Cross(B[j])) then
				return false
			end
		end
	end
	return true
end

local function boxesOverlap(xs: { Box }, ys: { Box }, grow: number): boolean
	for _, x in xs do
		for _, y in ys do
			if obbOverlap(x.cf, x.size / 2 + Vector3.one * grow, y.cf, y.size / 2, TOUCH) then
				return true
			end
		end
	end
	return false
end

-- Pieces and the spatial index ----------------------------------------------------

function Placement.defOf(piece: Instance): BuildItems.Def?
	local id = piece:GetAttribute("ItemId")
	return if type(id) == "string" then BuildItems.Defs[id] else nil
end

-- Whether an instance is a storable piece (placed item or starter) with a definition.
function Placement.isPiece(inst: Instance): boolean
	return (inst:GetAttribute("PlacedId") ~= nil or inst:GetAttribute("StarterId") ~= nil)
		and Placement.defOf(inst) ~= nil
end

local function cellsOf(lo: Vector3, hi: Vector3): { Vector2 }
	local out = {}
	for x = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
		for z = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
			table.insert(out, Vector2.new(x, z))
		end
	end
	return out
end

function Placement.entryFor(piece: Instance): Entry?
	local def = Placement.defOf(piece)
	if not def then
		return nil
	end
	local pivot = pivotOf(piece)
	local boxes = Placement.worldBoxes(pivot, Placement.boxes(piece, def))
	local lo, hi = aabb(boxes)
	return { piece = piece, def = def, pivot = pivot, boxes = boxes, min = lo, max = hi }
end

local function insert(index: Index, entry: Entry)
	index.entries[entry.piece] = entry
	for _, key in cellsOf(entry.min, entry.max) do
		local cell = index.cells[key]
		if not cell then
			cell = {}
			index.cells[key] = cell
		end
		table.insert(cell, entry)
	end
end

-- Every piece on the peak, hashed by where its bounds are.
function Placement.newIndex(peak: Model): Index
	local index: Index = { peak = peak, entries = {}, cells = {} }
	for _, d in peak:GetDescendants() do
		if Placement.isPiece(d) then
			local entry = Placement.entryFor(d)
			if entry then
				insert(index, entry)
			end
		end
	end
	return index
end

function Placement.query(index: Index, lo: Vector3, hi: Vector3): { Entry }
	local seen: { [Entry]: boolean } = {}
	local out = {}
	for _, key in cellsOf(lo, hi) do
		for _, e in index.cells[key] or {} do
			if not seen[e] and e.max.X >= lo.X and e.min.X <= hi.X and e.max.Y >= lo.Y and e.min.Y <= hi.Y and e.max.Z >= lo.Z and e.min.Z <= hi.Z then
				seen[e] = true
				table.insert(out, e)
			end
		end
	end
	return out
end

-- Snap points ----------------------------------------------------------------------

-- Sockets a piece offers, in world space (kind and CFrame, facing up).
function Placement.sockets(entry: Entry): { { kind: string, cf: CFrame } }
	local out = {}
	for _, s in entry.def.sockets or {} do
		local at: CFrame
		if s.at == "top" then
			local b = entry.boxes[1]
			at = b.cf * CFrame.new(0, b.size.Y / 2, 0)
		else
			at = entry.pivot * (s.at :: CFrame)
		end
		table.insert(out, { kind = s.kind, cf = at })
	end
	return out
end

-- Edge connectors of a piece placed at `pivot`, in world space, facing outward.
function Placement.edges(def: BuildItems.Def, pivot: CFrame): { { kind: string, cf: CFrame } }
	local out = {}
	for _, e in def.edges or {} do
		table.insert(out, { kind = e.kind, cf = pivot * (e.at :: CFrame) })
	end
	return out
end

local function edgeJoined(defA: BuildItems.Def, pivotA: CFrame, entry: Entry): boolean
	if not (defA.edges and entry.def.edges) then
		return false
	end
	for _, a in Placement.edges(defA, pivotA) do
		for _, b in Placement.edges(entry.def, entry.pivot) do
			if a.kind == b.kind and (a.cf.Position - b.cf.Position).Magnitude < 0.2 then
				return true
			end
		end
	end
	return false
end

-- Surfaces and support ---------------------------------------------------------------

local function isGround(part: Instance, peak: Model): boolean
	if part:IsA("Terrain") then
		return true
	end
	local node: Instance? = part
	while node and node ~= peak do
		if table.find(Config.GROUND, node.Name) and node.Parent == peak then
			return true
		end
		-- a peak tier's new terraces (Peaks.applyRealm parents the tier as RealmTier)
		local parent = node.Parent
		if node.Name == Config.TIER_GROUND and parent and parent.Name == "RealmTier" and parent.Parent == peak then
			return true
		end
		node = node.Parent
	end
	return false
end

-- The piece an instance belongs to, if it's a piece on this peak.
local function pieceAt(inst: Instance, ctx: Context): Instance?
	local piece = Peak.pieceOf(inst)
	return if piece and ctx.index.entries[piece] then piece else nil
end

-- First collidable hit along a ray, passing through non-collidable parts and the
-- skipped pieces (Include filters can't exclude, so it steps past them).
local function cast(ctx: Context, origin: Vector3, dir: Vector3, skip: { [Instance]: boolean }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ctx.peak, workspace.Terrain }
	params.RespectCanCollide = false
	params.IgnoreWater = true
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, dir, params)
		if not hit then
			return nil
		end
		local inst = hit.Instance
		local piece = Peak.pieceOf(inst)
		local pass = (inst:IsA("BasePart") and not inst.CanCollide) or (piece ~= nil and skip[piece] == true)
		if not pass then
			return hit
		end
		local travelled = (hit.Position - origin).Magnitude + 0.02
		if travelled >= dir.Magnitude then
			return nil
		end
		origin += dir.Unit * travelled
		dir = dir.Unit * (dir.Magnitude - travelled)
	end
	return nil
end

type Support = { ok: boolean, reason: string?, piece: Instance?, part: Instance? }

local function floorSupport(ctx: Context, def: BuildItems.Def, pivot: CFrame, lo: Vector3, hi: Vector3, skip: { [Instance]: boolean }): Support
	local reach = RAY_IN + RAY_GAP + (def.lift or 0)
	local cx, cz = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
	local ix, iz = (hi.X - lo.X) * 0.3, (hi.Z - lo.Z) * 0.3
	local points = {
		Vector3.new(cx, lo.Y + RAY_IN, cz),
		Vector3.new(cx - ix, lo.Y + RAY_IN, cz - iz),
		Vector3.new(cx + ix, lo.Y + RAY_IN, cz - iz),
		Vector3.new(cx - ix, lo.Y + RAY_IN, cz + iz),
		Vector3.new(cx + ix, lo.Y + RAY_IN, cz + iz),
	}
	local down = -pivot.UpVector * reach
	local groundOnly = not BuildItems.allows(def, "floor")
	local centre: RaycastResult? = nil
	local hits = 0
	for i, p in points do
		local hit = cast(ctx, pivot * p, down, skip)
		if hit and hit.Normal.Y > 0.6 then
			hits += 1
			if groundOnly and not isGround(hit.Instance, ctx.peak) then
				return { ok = false, reason = "Needs open ground" }
			end
			if i == 1 then
				centre = hit
			end
		end
	end
	if not centre or hits < 3 then
		return { ok = false, reason = if hits == 0 then "Nothing underneath to stand on" else "Not enough support underneath" }
	end
	local under = pieceAt(centre.Instance, ctx)
	if under then
		local underDef = Placement.defOf(under) :: BuildItems.Def
		if not def.stack then
			return { ok = false, reason = `{def.name} must stand on the ground` }
		elseif not underDef.top then
			return { ok = false, reason = `Nothing can stand on the {underDef.name}` }
		end
	end
	return { ok = true, piece = under, part = centre.Instance }
end

local function wallSupport(ctx: Context, pivot: CFrame, lo: Vector3, hi: Vector3, skip: { [Instance]: boolean }): Support
	-- the back is the +Z face: wall pieces face out along their LookVector (-Z)
	local origin = pivot * Vector3.new((lo.X + hi.X) / 2, (lo.Y + hi.Y) / 2, hi.Z - RAY_IN)
	local hit = cast(ctx, origin, pivot.ZVector * (RAY_IN + RAY_GAP), skip)
	if not (hit and math.abs(hit.Normal.Y) < 0.3) then
		return { ok = false, reason = "Needs a wall behind it" }
	end
	return { ok = true, piece = pieceAt(hit.Instance, ctx), part = hit.Instance }
end

local function ceilingSupport(ctx: Context, pivot: CFrame, lo: Vector3, hi: Vector3, skip: { [Instance]: boolean }): Support
	local origin = pivot * Vector3.new((lo.X + hi.X) / 2, hi.Y - RAY_IN, (lo.Z + hi.Z) / 2)
	local hit = cast(ctx, origin, pivot.UpVector * (RAY_IN + RAY_GAP), skip)
	if not (hit and hit.Normal.Y < -0.6) then
		return { ok = false, reason = "Needs a ceiling above it" }
	end
	return { ok = true, piece = pieceAt(hit.Instance, ctx), part = hit.Instance }
end

local function socketSupport(ctx: Context, def: BuildItems.Def, pivot: CFrame, lo: Vector3, hi: Vector3): Support
	local base = pivot * Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	local near = Placement.query(ctx.index, base - Vector3.one * 2, base + Vector3.one * 2)
	for _, e in near do
		if not (ctx.ignore and ctx.ignore[e.piece]) then
			for _, s in Placement.sockets(e) do
				if s.kind == def.fits and (s.cf.Position - base).Magnitude <= SOCKET_SNAP then
					return { ok = true, piece = e.piece }
				end
			end
		end
	end
	return { ok = false, reason = "Not on a matching spot" }
end

function Placement.support(ctx: Context, def: BuildItems.Def, boxes: { Box }, pivot: CFrame, mode: Mode, self: Instance?): Support
	local lo, hi = Placement.extent(boxes)
	local skip: { [Instance]: boolean } = {}
	if self then
		skip[self] = true
	end
	for piece in ctx.ignore or {} do
		skip[piece] = true
	end
	if mode == "floor" then
		return floorSupport(ctx, def, pivot, lo, hi, skip)
	elseif mode == "wall" then
		return wallSupport(ctx, pivot, lo, hi, skip)
	elseif mode == "ceiling" then
		return ceilingSupport(ctx, pivot, lo, hi, skip)
	end
	return socketSupport(ctx, def, pivot, lo, hi)
end

-- Whether a mode is allowed for an item.
function Placement.allowsMode(def: BuildItems.Def, mode: Mode): boolean
	if mode == "floor" then
		return BuildItems.allows(def, "floor") or BuildItems.allows(def, "terrain")
	end
	return BuildItems.allows(def, mode)
end

-- Area rules --------------------------------------------------------------------------

local function inArea(frame: CFrame, radius: number, boxes: { Box }): boolean
	for _, b in boxes do
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = b.cf * (b.size / 2 * Vector3.new(sx, sy, sz))
					if not Peak.inBounds(frame:PointToObjectSpace(corner), radius) then
						return false
					end
				end
			end
		end
	end
	return true
end

-- Where a reserved zone is on this peak: its anchor's position.
local function anchorPosition(peak: Model, name: string): Vector3?
	local anchor = peak:FindFirstChild(name)
	if anchor and anchor:IsA("Model") then
		return anchor:GetPivot().Position
	elseif anchor and anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

-- The reserved zone a set of boxes intrudes on, by name.
function Placement.reservedHit(peak: Model, boxes: { Box }): string?
	for _, zone in Config.RESERVED do
		local at = anchorPosition(peak, zone.anchor)
		if at then
			for _, b in boxes do
				local l = b.cf:PointToObjectSpace(at)
				local h = b.size / 2
				local closest = b.cf * Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
				local flat = Vector2.new(closest.X - at.X, closest.Z - at.Z).Magnitude
				local dy = closest.Y - at.Y
				if flat < zone.radius and dy > -zone.below and dy < zone.above then
					return zone.name
				end
			end
		end
	end
	return nil
end

-- Restricted geometry: collidable non-piece parts of the peak inside the bounds.
local function restrictedHit(ctx: Context, boxes: { Box }, supportPart: Instance?): string?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ctx.peak, workspace.Terrain }
	local probe = ctx.probe
	for _, b in boxes do
		probe.Size = (b.size - Vector3.one * PROBE_INSET * 2):Max(Vector3.one * 0.05)
		probe.CFrame = b.cf
		for _, part in workspace:GetPartsInPart(probe, params) do
			if part.CanCollide and part ~= supportPart and not Peak.pieceOf(part) then
				local node: Instance = part
				while node.Parent and node.Parent ~= ctx.peak do
					node = node.Parent
				end
				return Config.RESTRICTED_NAMES[node.Name] or "something in the way"
			end
		end
	end
	return nil
end

-- The full check -------------------------------------------------------------------------

export type Result = { ok: boolean, reason: string?, support: Instance? }

-- Can `def`, with placement `boxes` (pivot space), go at `pivot` in `mode`?
-- `self` is the piece being moved, if any (it's in ctx.ignore too).
function Placement.check(ctx: Context, def: BuildItems.Def, boxes: { Box }, pivot: CFrame, mode: Mode, self: Instance?): Result
	if not Placement.allowsMode(def, mode) then
		local where = { floor = "on the ground", wall = "on a wall", ceiling = "on a ceiling", socket = "there" }
		return { ok = false, reason = `The {def.name} can't go {where[mode]}` }
	end
	local world = Placement.worldBoxes(pivot, boxes)
	if not inArea(ctx.frame, Peak.radius(ctx.peak), world) then
		return { ok = false, reason = "Outside your peak's build area" }
	end
	local zone = Placement.reservedHit(ctx.peak, world)
	if zone then
		return { ok = false, reason = `Keep {zone} clear` }
	end
	local support = Placement.support(ctx, def, boxes, pivot, mode, self)
	if not support.ok then
		return { ok = false, reason = support.reason }
	end
	-- other pieces' bounds
	local grow = def.clearance or 0
	local lo, hi = aabb(world)
	local pad = Vector3.one * (grow + Config.MAX_CLEARANCE)
	for _, e in Placement.query(ctx.index, lo - pad, hi + pad) do
		local skip = e.piece == self or e.piece == support.piece or (ctx.ignore and ctx.ignore[e.piece])
		if skip or (def.soft and e.def.soft) or edgeJoined(def, pivot, e) then
			continue
		end
		if boxesOverlap(world, e.boxes, 0) then
			return { ok = false, reason = `Overlaps the {e.def.name}` }
		end
		local theirs = e.def.clearance or 0
		if (grow > 0 and boxesOverlap(world, e.boxes, grow)) or (theirs > 0 and boxesOverlap(e.boxes, world, theirs)) then
			return { ok = false, reason = `Too close to the {e.def.name}` }
		end
	end
	local blocked = restrictedHit(ctx, world, support.part)
	if blocked then
		return { ok = false, reason = `Blocked by {blocked}` }
	end
	return { ok = true, support = support.piece }
end

-- Dependents ------------------------------------------------------------------------------

-- The piece holding this one up, judged the same way placement is.
function Placement.supporterOf(ctx: Context, entry: Entry, mode: Mode): Instance?
	local boxes = Placement.boxes(entry.piece, entry.def)
	return Placement.support(ctx, entry.def, boxes, entry.pivot, mode, entry.piece).piece
end

-- Every piece resting on this one, directly or through others. `modeOf` gives each
-- piece's placement mode (saved with placed items; starters stand on the floor).
function Placement.dependents(ctx: Context, root: Instance, modeOf: (Instance) -> Mode): { Instance }
	local out: { Instance } = {}
	local found: { [Instance]: boolean } = { [root] = true }
	local queue = { root }
	while #queue > 0 do
		local current = table.remove(queue, 1) :: Instance
		local entry = ctx.index.entries[current]
		if entry then
			local pad = Vector3.one * (RAY_GAP + 8)
			for _, e in Placement.query(ctx.index, entry.min - pad, entry.max + pad) do
				if not found[e.piece] and Placement.supporterOf(ctx, e, modeOf(e.piece)) == current then
					found[e.piece] = true
					table.insert(out, e.piece)
					table.insert(queue, e.piece)
				end
			end
		end
	end
	return out
end

return Placement
