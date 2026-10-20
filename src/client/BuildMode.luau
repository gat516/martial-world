--!strict
-- Build mode on your own peak: placing, moving and storing pieces.
--
-- The catalog (BuildCatalog) picks what to place. While placing or moving, the
-- window gives way to the slim BuildControls bar and a ghost of the item follows
-- the pointer (mouse on PC, your finger as you drag on touch, the screen centre
-- on a controller). The ghost runs the same Placement.check the server will, so
-- it's green when the spot is good and red with the reason when it isn't.
--
-- Snapping:
--   Grid    snaps to the peak's grid (size from the precision preset)
--   Free    no grid (only items allowed free placement)
--   Points  only snaps to compatible attachment points: sockets (a lantern on a
--           table) and edges (fence ends; rotate to turn corners)
--   Grid and Free also catch a nearby snap point. A caught point or grid cell is
--   held until the pointer is clearly past it, so the ghost doesn't flicker
--   between targets near a boundary.
-- What it rests on decides the mode: floors and tops, walls (it faces out) or
-- ceilings (it hangs), as the item allows. Items with `lift` can be raised.
--
-- Controls
--               PC            controller    touch
--   confirm     click / Enter A             Place
--   cancel      X / Backspace B             Cancel
--   rotate      R (Shift back) RB / LB      Rotate
--   snap mode   T             X             Snap
--   precision   G             Y             Grid
--   raise/lower E / C         D-pad         Up / Down
-- Store and Move pick a piece first (tap or click it; the controller aims with the
-- screen centre). Storing a piece stores what rests on it too, and moving one
-- carries them along; both are outlined before you confirm.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Build
local PEAK_RADIUS = require(ReplicatedStorage.Shared.Config).Circulation.PEAK_RADIUS
local BuildItems = require(ReplicatedStorage.Shared.BuildItems)
local Peak = require(ReplicatedStorage.Shared.Peak)
local Placement = require(ReplicatedStorage.Shared.Placement)
local BuildCatalog = require(script.Parent.BuildCatalog)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local MyPeak = require(script.Parent.MyPeak)
local Platform = require(script.Parent.Platform)
local State = require(script.Parent.State)

local player = Players.LocalPlayer
local buildRemote = ReplicatedStorage.Remotes.BuildAction :: RemoteFunction
local templates = ReplicatedStorage:WaitForChild("BuildCatalog")
local kit = ReplicatedStorage:WaitForChild("BuildKit")

local VALID_COLOR = Color3.fromRGB(90, 220, 150)
local INVALID_COLOR = Color3.fromRGB(230, 80, 80)
local READY_TEXT_COLOR = Color3.fromRGB(150, 230, 170)
local BAD_TEXT_COLOR = Color3.fromRGB(240, 120, 100)
local GHOST_TRANSPARENCY = 0.45
local GRID_LINES = 9
local RAY_LENGTH = 600
local ACQUIRE = 1.5 -- studs from the pointer that catch a snap point (Grid / Free)
local ACQUIRE_POINTS = 4 -- in Points mode
local RELEASE_EXTRA = 1.5 -- a caught point lets go this much farther out
local GRID_STICK = 0.2 -- share of a cell the pointer must pass a boundary by
local LIFT_STEP = 0.5

type Session = "idle" | "place" | "pick" | "move" | "store"
type SnapMode = "Grid" | "Free" | "Points"
type Target = { kind: "socket" | "edge", cf: CFrame, piece: Instance, key: string }

local BuildMode = {}

local controls: Frame
local status: TextLabel
local itemLabel: TextLabel
local row: Frame
local banner: Frame? -- Hud.BuildBanner: "Build mode · <peak>", the Place / Move / Store tabs and Exit
local tilesFrame: GuiObject? -- the top-right tiles; build mode's banner replaces them
local toast: GuiObject?
local toastHome: UDim2? = nil
local building = false -- a build session is open (banner up)

local session: Session = "idle"
local pickFor: "move" | "store" = "store"
local handingOff = false

-- what's being placed or moved
local def: BuildItems.Def? = nil
local itemId: string? = nil
local boxes: { Placement.Box } = {}
local lo, hi = Vector3.zero, Vector3.zero
local ghost: Model? = nil
local ghostHighlight: Highlight? = nil
local moving: Instance? = nil
local riders: { Instance } = {}
local yaw = 0 -- user rotation, degrees
local lift = 0
local snapMode: SnapMode = "Grid"
local precision = 1

-- the current aim
local pivot: CFrame? = nil
local mode: Placement.Mode = "floor"
local result: Placement.Result = { ok = false, reason = "Point at your peak" }
local target: Target? = nil
local gridCell: Vector3? = nil
local lastChecked: string? = nil
local pointer: Vector2? = nil -- screen point to aim from (nil: screen centre for gamepads)
local pointerInViewport = true

-- store / move picking
local picked: Instance? = nil
local pickedRiders: { Instance } = {}

local ctx: Placement.Context? = nil
local indexDirty = true
local conns: { RBXScriptConnection } = {}
local visuals: { Instance } = {}
local gridLines: { BasePart } = {}
local marker: BasePart? = nil
local selectHighlight: Highlight? = nil
local hoverHighlight: Highlight? = nil
local riderHighlights: { Highlight } = {}

local function button(name: string): GuiButton
	return row:FindFirstChild(name) :: GuiButton
end

local function caption(name: string): TextLabel
	return button(name):FindFirstChild("Label") :: TextLabel
end

local function preset(): { grid: number, rotate: number }
	return Config.PRECISION[precision]
end

-- Context and index ------------------------------------------------------------------

local function context(): Placement.Context?
	local peak, frame = MyPeak.model(), MyPeak.frame()
	if not (peak and frame) then
		return nil
	end
	if not ctx or indexDirty then
		local probe = if ctx then ctx.probe else (kit:FindFirstChild("Probe") :: BasePart):Clone()
		ctx = { peak = peak, frame = frame, index = Placement.newIndex(peak), probe = probe }
		indexDirty = false
		lastChecked = nil
	end
	local c = ctx :: Placement.Context
	local ignore: { [Instance]: boolean } = {}
	if moving then
		ignore[moving] = true
		for _, r in riders do
			ignore[r] = true
		end
	end
	c.ignore = ignore
	return c
end

local function modeOf(piece: Instance): Placement.Mode
	return (piece:GetAttribute("PlaceMode") or "floor") :: Placement.Mode
end

-- Visuals -----------------------------------------------------------------------------

local function clone(name: string): Instance
	local inst = (kit:FindFirstChild(name) :: Instance):Clone()
	table.insert(visuals, inst)
	return inst
end

local function clearVisuals()
	for _, v in visuals do
		v:Destroy()
	end
	table.clear(visuals)
	table.clear(gridLines)
	table.clear(riderHighlights)
	marker, selectHighlight, hoverHighlight = nil, nil, nil
end

local function showArea()
	local frame, peak = MyPeak.frame(), MyPeak.model()
	if not (frame and peak) then
		return
	end
	-- the build radius
	local segments = 48
	local r = Config.RADIUS
	for i = 1, segments do
		local a = (i + 0.5) / segments * math.pi * 2
		local seg = clone("RingSegment") :: BasePart
		seg.Size = Vector3.new(0.15, 0.15, 2 * math.pi * r / segments)
		seg.CFrame = frame * CFrame.new(math.cos(a) * r, 1.2, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		seg.Parent = workspace.CurrentCamera
	end
	-- reserved zones
	for _, zone in Config.RESERVED do
		local anchor = peak:FindFirstChild(zone.anchor)
		local at = if anchor and anchor:IsA("Model") then anchor:GetPivot().Position
			elseif anchor and anchor:IsA("BasePart") then anchor.Position
			else nil
		if at then
			local disc = clone("ReservedZone") :: BasePart
			disc.Size = Vector3.new(0.12, zone.radius * 2, zone.radius * 2)
			disc.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			disc.Parent = workspace.CurrentCamera
		end
	end
	marker = clone("SnapMarker") :: BasePart;
	(marker :: BasePart).Transparency = 1;
	(marker :: BasePart).Parent = workspace.CurrentCamera
	for i = 1, GRID_LINES * 2 do
		local line = clone("GridLine") :: BasePart
		line.Transparency = 1
		line.Parent = workspace.CurrentCamera
		gridLines[i] = line
	end
	local function highlight(name: string): Highlight
		local h = clone(name) :: Highlight
		h.Parent = workspace.CurrentCamera
		return h
	end
	selectHighlight = highlight("SelectHighlight")
	hoverHighlight = highlight("HoverHighlight")
end

local function hideGrid()
	for _, line in gridLines do
		line.Transparency = 1
	end
end

local function drawGrid(frame: CFrame, centre: Vector3)
	local step = preset().grid
	local half = (GRID_LINES - 1) / 2
	local length = step * (GRID_LINES - 1)
	for i = 0, GRID_LINES - 1 do
		local offset = (i - half) * step
		local along, across = gridLines[i + 1], gridLines[GRID_LINES + i + 1]
		if along and across then
			local fade = 0.55 + 0.4 * math.abs(i - half) / half
			along.Size = Vector3.new(0.06, 0.06, length)
			along.CFrame = frame * CFrame.new(centre + Vector3.new(offset, 0.08, 0))
			along.Transparency = fade
			across.Size = Vector3.new(length, 0.06, 0.06)
			across.CFrame = frame * CFrame.new(centre + Vector3.new(0, 0.08, offset))
			across.Transparency = fade
		end
	end
end

local function setRiderHighlights(pieces: { Instance })
	for _, h in riderHighlights do
		h:Destroy()
	end
	table.clear(riderHighlights)
	for _, p in pieces do
		local h = clone("DependentHighlight") :: Highlight
		h.Adornee = p
		h.Enabled = true
		h.Parent = workspace.CurrentCamera
		table.insert(riderHighlights, h)
	end
end

local function placedBurst(at: CFrame)
	local ring = (kit:FindFirstChild("Burst") :: BasePart):Clone()
	ring.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace.CurrentCamera
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 9, 9),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

-- Ghost ---------------------------------------------------------------------------------

local function strip(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Transparency = math.max(d.Transparency, GHOST_TRANSPARENCY)
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Script") then
			d:Destroy()
		end
	end
	for _, tag in model:GetTags() do
		model:RemoveTag(tag)
	end
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostHighlight, pivot, target, gridCell, lastChecked = nil, nil, nil, nil, nil, nil
	hideGrid()
	if marker then
		marker.Transparency = 1
	end
end

-- The ghost of a template, or of a piece and what rides on it (moving).
local function makeGhost(source: Instance, extra: { Instance })
	clearGhost()
	local g = Instance.new("Model")
	g.Name = "BuildGhost"
	local main = source:Clone()
	main.Parent = g
	for _, r in extra do
		r:Clone().Parent = g
	end
	strip(g)
	g.WorldPivot = if source:IsA("Model") then source:GetPivot() else (source :: BasePart).CFrame
	local h = (kit:FindFirstChild("GhostHighlight") :: Highlight):Clone()
	h.Enabled = true
	h.Parent = g
	g.Parent = workspace.CurrentCamera
	ghost, ghostHighlight = g, h
end

-- Pieces being moved fade so the ghost reads as the thing in your hand.
local function fadePieces(pieces: { Instance }, amount: number)
	for _, p in pieces do
		for _, d in p:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = amount
			end
		end
	end
end

-- Aim -----------------------------------------------------------------------------------

local function screenRay(): Ray
	local camera = workspace.CurrentCamera
	if pointer then
		return if pointerInViewport
			then camera:ViewportPointToRay(pointer.X, pointer.Y)
			else camera:ScreenPointToRay(pointer.X, pointer.Y)
	end
	local size = camera.ViewportSize
	return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
end

local function aimRaycast(): RaycastResult?
	local peak = MyPeak.model()
	if not peak then
		return nil
	end
	local ray = screenRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { peak, workspace.Terrain }
	-- step through pieces being moved and non-collidable dressing
	local origin, dir = ray.Origin, ray.Direction * RAY_LENGTH
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, dir, params)
		if not hit then
			return nil
		end
		local piece = Peak.pieceOf(hit.Instance)
		local skip = (moving ~= nil and (piece == moving or table.find(riders, piece :: any) ~= nil))
			or (hit.Instance:IsA("BasePart") and not hit.Instance.CanCollide and piece == nil)
		if not skip then
			return hit
		end
		local travelled = (hit.Position - origin).Magnitude + 0.05
		origin += dir.Unit * travelled
		dir = dir.Unit * math.max(0, dir.Magnitude - travelled)
	end
	return nil
end

-- Snap a peak-local coordinate to the grid, sticking to the current cell near edges.
local function stick(value: number, current: number?, step: number): number
	local snapped = Peak.snap(value, step)
	if current and math.abs(value - current) < step * (0.5 + GRID_STICK) then
		return current
	end
	return snapped
end

local function yawCFrame(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- Snap points near a world position that this item fits.
local function snapTargets(c: Placement.Context, near: Vector3, radius: number): { Target }
	local d = def :: BuildItems.Def
	local out: { Target } = {}
	local pad = Vector3.one * (radius + 1)
	for _, e in Placement.query(c.index, near - pad, near + pad) do
		if not (c.ignore and c.ignore[e.piece]) then
			if d.fits and table.find(d.on, "socket") then
				for i, s in Placement.sockets(e) do
					if s.kind == d.fits then
						table.insert(out, { kind = "socket", cf = s.cf, piece = e.piece, key = `{e.piece:GetFullName()}#s{i}` })
					end
				end
			end
			if d.edges then
				for i, edge in Placement.edges(e.def, e.pivot) do
					for _, mine in d.edges do
						if mine.kind == edge.kind then
							table.insert(out, { kind = "edge", cf = edge.cf, piece = e.piece, key = `{e.piece:GetFullName()}#e{i}` })
							break
						end
					end
				end
			end
		end
	end
	return out
end

local function pickTarget(c: Placement.Context, at: Vector3): Target?
	local acquire = if snapMode == "Points" then ACQUIRE_POINTS else ACQUIRE
	local candidates = snapTargets(c, at, acquire + RELEASE_EXTRA)
	-- hold the current target until the pointer is clearly away from it
	if target then
		for _, t in candidates do
			if t.key == target.key and (t.cf.Position - at).Magnitude <= acquire + RELEASE_EXTRA then
				return t
			end
		end
	end
	local best, bestDist = nil, acquire
	for _, t in candidates do
		local dist = (t.cf.Position - at).Magnitude
		if dist < bestDist then
			best, bestDist = t, dist
		end
	end
	return best
end

-- Where the ghost goes for a snap point.
local function pivotForTarget(t: Target, rough: CFrame?): (CFrame, Placement.Mode)
	local d = def :: BuildItems.Def
	if t.kind == "socket" then
		local base = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
		return CFrame.new(t.cf.Position) * yawCFrame(yaw) * CFrame.new(-base), "socket"
	end
	-- edges: my nearest end meets theirs, facing it; rotating turns the joint
	local mine = (d.edges :: { BuildItems.Point })[1]
	if rough then
		local bestDist = math.huge
		for _, e in d.edges :: { BuildItems.Point } do
			local dist = ((rough * (e.at :: CFrame)).Position - t.cf.Position).Magnitude
			if dist < bestDist then
				mine, bestDist = e, dist
			end
		end
	end
	local joint = t.cf * CFrame.Angles(0, math.pi + math.rad(yaw), 0)
	return joint * (mine.at :: CFrame):Inverse(), "floor"
end

-- Pivot on a surface hit, by which way the surface faces.
local function pivotForSurface(c: Placement.Context, hit: RaycastResult): (CFrame?, Placement.Mode)
	local d = def :: BuildItems.Def
	local frame = c.frame
	local n = frame:VectorToObjectSpace(hit.Normal)
	local l = frame:PointToObjectSpace(hit.Position)
	local step = preset().grid
	local grid = snapMode == "Grid"
	local cx, cz = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
	if n.Y > 0.6 or not (Placement.allowsMode(d, "wall") or Placement.allowsMode(d, "ceiling")) then
		-- floors and tops
		local x, z = l.X, l.Z
		if grid then
			local cell = Vector3.new(stick(x, gridCell and gridCell.X, step), 0, stick(z, gridCell and gridCell.Z, step))
			gridCell = cell
			x, z = cell.X, cell.Z
		end
		-- find the surface under the snapped spot (it may differ from where the pointer hit)
		local rot = frame * CFrame.new(x, l.Y, z) * yawCFrame(yaw)
		local top = rot * Vector3.new(cx, 0, cz) + frame.UpVector * (hi.Y - lo.Y + 1)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { c.peak, workspace.Terrain }
		local down = workspace:Raycast(top, -frame.UpVector * (hi.Y - lo.Y + 4), params)
		local y = if down then frame:PointToObjectSpace(down.Position).Y else l.Y
		return frame * CFrame.new(x, y - lo.Y + lift, z) * yawCFrame(yaw), "floor"
	elseif n.Y < -0.6 then
		local x, z = l.X, l.Z
		if grid then
			x, z = Peak.snap(x, step), Peak.snap(z, step)
		end
		local base = frame * CFrame.new(x, l.Y, z) * yawCFrame(yaw)
		return base * CFrame.new(-cx, -hi.Y, -cz), "ceiling"
	end
	-- a wall: face out along its normal
	local flat = Vector3.new(n.X, 0, n.Z)
	if flat.Magnitude < 1e-3 then
		return nil, "wall"
	end
	local wallYaw = math.deg(math.atan2(-flat.X, -flat.Z))
	local y = if grid then Peak.snap(l.Y, step) else l.Y
	local base = frame * CFrame.new(l.X, y, l.Z) * yawCFrame(wallYaw)
	return base * CFrame.new(-cx, -(lo.Y + hi.Y) / 2, -hi.Z), "wall"
end

-- Quantise as the server will, so the preview checks what gets built.
local function quantise(frame: CFrame, p: CFrame): (Vector3, number, CFrame)
	local l = frame:ToObjectSpace(p)
	local pos = Vector3.new(Peak.snap(l.X, 0.05), Peak.snap(l.Y, 0.05), Peak.snap(l.Z, 0.05))
	local look = l.LookVector
	local r = Peak.snap(math.deg(math.atan2(-look.X, -look.Z)), 1) % 360
	return pos, r, frame * CFrame.new(pos) * yawCFrame(r)
end

local function setStatus(text: string, good: boolean)
	status.Text = text
	status.TextColor3 = if good then READY_TEXT_COLOR else BAD_TEXT_COLOR
end

local function updateAim()
	local d = def
	local c = context()
	if not (d and c and ghost) then
		return
	end
	local hit = aimRaycast()
	if not hit then
		pivot = nil
		ghost.Parent = nil
		setStatus("Point at your peak", false)
		hideGrid()
		return
	end
	ghost.Parent = workspace.CurrentCamera
	local p: CFrame? = nil
	local m: Placement.Mode = "floor"
	local rough, roughMode = pivotForSurface(c, hit)
	local wantsPoints = (d.fits ~= nil and table.find(d.on, "socket") ~= nil) or d.edges ~= nil
	target = if wantsPoints then pickTarget(c, hit.Position) else nil
	if target then
		p, m = pivotForTarget(target, rough)
	elseif snapMode ~= "Points" or not wantsPoints then
		p, m = rough, roughMode
	end
	if not p then
		pivot = nil
		setStatus(if snapMode == "Points" then "Point at a matching spot" else "Can't go here", false)
		ghost.Parent = nil
		return
	end
	local _, _, q = quantise(c.frame, p)
	pivot, mode = q, m
	ghost:PivotTo(q)
	-- only re-check when the spot changes
	local key = `{q}|{m}`
	if key ~= lastChecked then
		lastChecked = key
		local self = moving
		result = Placement.check(c, d, boxes, q, m, self)
	end
	local good = result.ok
	if session == "place" and itemId then
		local owned = (State.current.decor or {})[itemId] or 0
		if owned < 1 then
			good, result = false, { ok = false, reason = "None left. Buy more at the Spirit Market" }
		end
	end
	if ghostHighlight then
		ghostHighlight.FillColor = if good then VALID_COLOR else INVALID_COLOR
		ghostHighlight.OutlineColor = ghostHighlight.FillColor
	end
	setStatus(if good then (if session == "move" then "Ready to move" else "Ready to place") else (result.reason or "Can't go here"), good)
	if marker then
		marker.Transparency = if target then 0.25 else 1
		if target then
			marker.CFrame = target.cf
		end
	end
	if m == "floor" and snapMode == "Grid" and not target then
		local l = c.frame:PointToObjectSpace(q * Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2))
		drawGrid(c.frame, l)
	else
		hideGrid()
	end
end

-- Picking pieces (store / move) ------------------------------------------------------------

local function pieceAtPointer(): Instance?
	local hit = aimRaycast()
	local piece = hit and Peak.pieceOf(hit.Instance)
	return if piece and Peak.of(piece) == MyPeak.model() and Placement.isPiece(piece) then piece else nil
end

local function setPicked(piece: Instance?)
	picked = piece
	table.clear(pickedRiders)
	if selectHighlight then
		selectHighlight.Adornee = piece
		selectHighlight.Enabled = piece ~= nil
	end
	local c = context()
	if piece and c then
		pickedRiders = Placement.dependents(c, piece, modeOf)
	end
	setRiderHighlights(pickedRiders)
	if not piece then
		local verb = if Platform.isTouch() then "Tap" else "Click"
		setStatus(if pickFor == "store" then `{verb} a piece to store it` else `{verb} a piece to move it`, true)
		return
	end
	local d = Placement.defOf(piece) :: BuildItems.Def
	local extra = if #pickedRiders > 0 then ` and {#pickedRiders} on it` else ""
	setStatus(`{if pickFor == "store" then "Store" else "Move"} the {d.name}{extra}?`, true)
end

local function updateHover()
	if not hoverHighlight then
		return
	end
	local piece: Instance? = nil
	if session == "pick" and (UserInputService.MouseEnabled or not pointer) then
		piece = pieceAtPointer()
		if piece == picked then
			piece = nil
		end
	end
	hoverHighlight.Adornee = piece
	hoverHighlight.Enabled = piece ~= nil
end

-- Mode banner ------------------------------------------------------------------------------
-- While building, a banner across the top says so ("Build mode · <peak>") and holds
-- the three mode tabs (Place opens the catalog, Move and Store pick a piece) and
-- Exit. The top-right tiles step aside meanwhile (Exit is the way out), and toasts
-- drop below the banner.

local function peakName(): string
	local peak = MyPeak.model()
	local name = peak and peak:GetAttribute("PeakName")
	if type(name) ~= "string" then
		return "Your peak"
	end
	return if string.find(name, "Peak") then name else `{name} Peak`
end

local function currentTab(): string
	if session == "pick" or session == "move" or session == "store" then
		return if session == "move" or pickFor == "move" then "MoveTab" else "StoreTab"
	end
	return "PlaceTab"
end

local function refreshBanner()
	local b = banner
	if not b then
		return
	end
	if b.Visible ~= building then
		if building then
			Motion.open(b)
		else
			b.Visible = false
		end
	end
	if tilesFrame and building then
		tilesFrame.Visible = false
	end
	if toast and toastHome then
		toast.Position = if building then toastHome + UDim2.fromOffset(0, 62) else toastHome
	end
	if not building then
		return
	end
	local tag = b:FindFirstChild("Tag")
	local label = tag and tag:FindFirstChild("PeakLabel") :: TextLabel?
	if label then
		label.Text = peakName()
	end
	local tab = currentTab()
	for _, name in { "PlaceTab", "MoveTab", "StoreTab" } do
		local button = b:FindFirstChild(name)
		local sel = button and button:FindFirstChild("Selected") :: GuiObject?
		if sel then
			sel.Visible = name == tab
		end
	end
end

-- Controls bar -----------------------------------------------------------------------------

local KEYS = {
	keyboard = { ConfirmButton = "Click", CancelButton = "X", RotateButton = "R", SnapButton = "T", GridButton = "G", RaiseButton = "E", LowerButton = "C" },
	gamepad = { ConfirmButton = "A", CancelButton = "B", RotateButton = "RB", SnapButton = "X", GridButton = "Y", RaiseButton = "↑", LowerButton = "↓" },
} :: { [string]: { [string]: string } }

local function refreshKeys()
	local last = UserInputService:GetLastInputType()
	local pad = last.Name:find("Gamepad") ~= nil
	local keys = if Platform.isTouch() and not pad then nil elseif pad then KEYS.gamepad else KEYS.keyboard
	for _, b in row:GetChildren() do
		local key = b:FindFirstChild("Key") :: TextLabel?
		if key then
			key.Visible = keys ~= nil and keys[b.Name] ~= nil
			key.Text = if keys then keys[b.Name] or "" else ""
		end
	end
end

local function snapModes(): { SnapMode }
	local d = def
	local modes: { SnapMode } = { "Grid" }
	if d and d.free then
		table.insert(modes, "Free")
	end
	if d and ((d.fits and table.find(d.on, "socket")) or d.edges) then
		table.insert(modes, "Points")
	end
	return modes
end

local function refreshControls()
	local placing = session == "place" or session == "move"
	local d = def
	button("RotateButton").Visible = placing
	button("SnapButton").Visible = placing and #snapModes() > 1
	button("GridButton").Visible = placing
	button("RaiseButton").Visible = placing and d ~= nil and (d.lift or 0) > 0
	button("LowerButton").Visible = placing and d ~= nil and (d.lift or 0) > 0
	caption("SnapButton").Text = snapMode
	local p = preset()
	caption("GridButton").Text = `{p.grid} · {p.rotate}°`
	caption("ConfirmButton").Text = if session == "store" or (session == "pick" and pickFor == "store") then "Store"
		elseif session == "move" or session == "pick" then "Move"
		else "Place"
	if session == "place" and d and itemId then
		local owned = (State.current.decor or {})[itemId] or 0
		itemLabel.Text = `{d.name} · {owned} left`
	elseif session == "move" and d then
		itemLabel.Text = if #riders > 0 then `Moving the {d.name} (+{#riders})` else `Moving the {d.name}`
	elseif session == "pick" then
		itemLabel.Text = if pickFor == "store" then "Store" else "Move"
	else
		itemLabel.Text = ""
	end
	refreshKeys()
	refreshBanner()
end

-- Session flow -----------------------------------------------------------------------------

local function endPlacing()
	if moving then
		fadePieces({ moving, table.unpack(riders) }, 0)
	end
	clearGhost()
	def, itemId, moving = nil, nil, nil
	table.clear(riders)
	lift = 0
end

local function showControls()
	if not controls.Visible then
		if BuildCatalog.isOpen() then
			BuildCatalog.handOff()
		end
		Menus.open(controls)
	end
	refreshControls()
end

local function backToCatalog()
	endPlacing()
	setPicked(nil)
	session = "idle"
	handingOff = controls.Visible
	BuildCatalog.open("build")
	refreshBanner()
end

local function beginPlace(id: string)
	local template = templates:FindFirstChild(id) :: Model?
	local d = BuildItems.Defs[id]
	if not (template and d) then
		return
	end
	endPlacing()
	setPicked(nil)
	def, itemId = d, id
	boxes = Placement.boxes(template, d)
	lo, hi = Placement.extent(boxes)
	yaw, lift = 0, 0
	local modes = snapModes()
	if not table.find(modes, snapMode) then
		snapMode = "Grid"
	end
	makeGhost(template, {})
	session = "place"
	showControls()
end

local function beginMove(piece: Instance)
	local d = Placement.defOf(piece)
	local c = context()
	if not (d and c) then
		return
	end
	endPlacing()
	def, moving = d, piece
	riders = Placement.dependents(c, piece, modeOf)
	setPicked(nil)
	if selectHighlight then
		selectHighlight.Enabled = false
	end
	setRiderHighlights({})
	boxes = Placement.boxes(piece, d)
	lo, hi = Placement.extent(boxes)
	local look = c.frame:VectorToObjectSpace((if piece:IsA("Model") then piece:GetPivot() else (piece :: BasePart).CFrame).LookVector)
	yaw = Peak.snap(math.deg(math.atan2(-look.X, -look.Z)), 1) % 360
	lift = 0
	makeGhost(piece, riders)
	fadePieces({ piece, table.unpack(riders) }, 0.7)
	session = "move"
	indexDirty = true
	refreshControls()
end

local function beginPick(kind: "move" | "store")
	endPlacing()
	pickFor = kind
	session = "pick"
	setPicked(nil)
	showControls()
end

local function confirm()
	local c = context()
	if session == "place" and def and itemId then
		if not (pivot and c) then
			return
		end
		if not result.ok then
			Hud.toast(result.reason or "That spot doesn't work")
			return
		end
		local pos, r = quantise(c.frame, pivot)
		local placedAt = pivot
		local ok, message = buildRemote:InvokeServer("place", { item = itemId, pos = pos, yaw = r, mode = mode })
		if ok then
			placedBurst(placedAt * CFrame.new((lo.X + hi.X) / 2, lo.Y + 0.1, (lo.Z + hi.Z) / 2))
			indexDirty = true
			lastChecked = nil
			-- keep placing while there are more; otherwise back to the catalog
			task.defer(function()
				if session == "place" and itemId and ((State.current.decor or {})[itemId] or 0) < 1 then
					backToCatalog()
				else
					refreshControls()
				end
			end)
		elseif message then
			Hud.toast(message)
		end
	elseif session == "move" and moving then
		if not (pivot and c) then
			return
		end
		if not result.ok then
			Hud.toast(result.reason or "That spot doesn't work")
			return
		end
		local pos, r = quantise(c.frame, pivot)
		local ok, message = buildRemote:InvokeServer("move", { target = moving, pos = pos, yaw = r, mode = mode })
		if ok then
			placedBurst(pivot * CFrame.new((lo.X + hi.X) / 2, lo.Y + 0.1, (lo.Z + hi.Z) / 2))
			endPlacing()
			indexDirty = true
			session = "pick"
			pickFor = "move"
			setPicked(nil)
			refreshControls()
		elseif message then
			Hud.toast(message)
		end
	elseif session == "pick" and picked then
		if pickFor == "move" then
			beginMove(picked)
			return
		end
		local ok, message = buildRemote:InvokeServer("store", { target = picked })
		if message then
			Hud.toast(message)
		end
		if ok then
			indexDirty = true
		end
		setPicked(nil)
	end
end

local function cancel()
	if session == "move" then
		-- put it down where it was and pick again
		endPlacing()
		session = "pick"
		setPicked(nil)
		refreshControls()
		return
	end
	backToCatalog()
end

local function rotate(direction: number)
	if session ~= "place" and session ~= "move" then
		return
	end
	yaw = (yaw + direction * preset().rotate) % 360
	lastChecked = nil
end

local function cycleSnap()
	local modes = snapModes()
	local i = table.find(modes, snapMode) or 0
	snapMode = modes[i % #modes + 1]
	target, gridCell, lastChecked = nil, nil, nil
	refreshControls()
end

local function cyclePrecision()
	precision = precision % #Config.PRECISION + 1
	gridCell, lastChecked = nil, nil
	refreshControls()
end

local function raise(direction: number)
	local d = def
	if not (d and d.lift) then
		return
	end
	lift = math.clamp(lift + direction * LIFT_STEP, 0, d.lift)
	lastChecked = nil
end

-- Open / close ------------------------------------------------------------------------------

local function onStep()
	local pad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
	if pad then
		pointer = nil -- controllers aim with the screen centre
	elseif not Platform.isTouch() and UserInputService.MouseEnabled then
		pointer, pointerInViewport = UserInputService:GetMouseLocation(), true
	end
	if session == "place" or session == "move" then
		updateAim()
	end
	updateHover()
end

local function watchPeak()
	local peak = MyPeak.model()
	if not peak then
		return
	end
	local function changed(inst: Instance)
		if inst:GetAttribute("ItemId") ~= nil then
			indexDirty = true
			lastChecked = nil
		end
	end
	table.insert(conns, peak.DescendantAdded:Connect(changed))
	table.insert(conns, peak.DescendantRemoving:Connect(changed))
end

local function active(): boolean
	return BuildCatalog.isOpen() and BuildCatalog.mode() == "build" or controls.Visible
end

-- Whether a build session is open (the catalog on your peak or the placement
-- controls). Combat stands down meanwhile.
function BuildMode.isActive(): boolean
	return controls ~= nil and active()
end

-- Tear down everything a build session made.
local function finish()
	endPlacing()
	setPicked(nil)
	session = "idle"
	for _, conn in conns do
		conn:Disconnect()
	end
	table.clear(conns)
	clearVisuals()
	ctx = nil
	indexDirty = true
	if building then
		building = false
		if tilesFrame then
			tilesFrame.Visible = true -- Menus settles them on its next update
		end
		refreshBanner()
	end
end

function BuildMode.open()
	if not MyPeak.model() then
		Hud.toast("You don't have a peak to build on")
		return
	end
	finish()
	showArea()
	watchPeak()
	table.insert(conns, RunService.RenderStepped:Connect(onStep))
	session = "idle"
	building = true
	BuildCatalog.open("build")
	refreshBanner()
end

function BuildMode.close()
	if controls.Visible then
		Menus.close(controls)
	end
	if BuildCatalog.isOpen() then
		BuildCatalog.close()
	end
	finish()
end

local function bindInput()
	local function inWorld(input: InputObject): boolean
		-- touches that land on our GUI are handled by the buttons
		local guis = player:FindFirstChildOfClass("PlayerGui")
		if not guis then
			return true
		end
		local p = input.Position
		for _, obj in guis:GetGuiObjectsAtPosition(p.X, p.Y) do
			if obj.Visible and (obj:IsA("GuiButton") or obj:IsA("TextBox")) then
				return false
			end
		end
		return true
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not controls.Visible or processed then
			return
		end
		local key = input.KeyCode
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if key == Enum.KeyCode.R then
			rotate(if shift then -1 else 1)
		elseif key == Enum.KeyCode.ButtonR1 then
			rotate(1)
		elseif key == Enum.KeyCode.ButtonL1 then
			rotate(-1)
		elseif key == Enum.KeyCode.T or key == Enum.KeyCode.ButtonX then
			cycleSnap()
		elseif key == Enum.KeyCode.G or key == Enum.KeyCode.ButtonY then
			cyclePrecision()
		elseif key == Enum.KeyCode.E or key == Enum.KeyCode.DPadUp then
			raise(1)
		elseif key == Enum.KeyCode.C or key == Enum.KeyCode.DPadDown then
			raise(-1)
		elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA then
			if session == "pick" and not pointer then
				local piece = pieceAtPointer()
				if piece and piece ~= picked then
					setPicked(piece)
					return
				end
			end
			confirm()
		elseif key == Enum.KeyCode.X or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
			cancel()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			pointer, pointerInViewport = UserInputService:GetMouseLocation(), true
			if session == "pick" then
				local piece = pieceAtPointer()
				if piece and piece == picked then
					confirm()
				else
					setPicked(piece)
				end
			else
				confirm()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch and inWorld(input) then
			pointer, pointerInViewport = Vector2.new(input.Position.X, input.Position.Y), false
			if session == "pick" then
				local piece = pieceAtPointer()
				if piece and piece == picked then
					confirm()
				else
					setPicked(piece)
				end
			end
		end
	end)
	-- touch: the ghost follows the finger while it drags
	UserInputService.InputChanged:Connect(function(input, processed)
		if controls.Visible and not processed and input.UserInputType == Enum.UserInputType.Touch then
			pointer, pointerInViewport = Vector2.new(input.Position.X, input.Position.Y), false
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		if controls.Visible then
			refreshKeys()
		end
	end)
end

function BuildMode.init(gui: ScreenGui)
	controls = gui:FindFirstChild("BuildControls") :: Frame
	status = controls:FindFirstChild("Status", true) :: TextLabel
	itemLabel = controls:FindFirstChild("ItemLabel", true) :: TextLabel
	row = controls:FindFirstChild("Row") :: Frame

	banner = gui:FindFirstChild("BuildBanner") :: Frame?
	tilesFrame = gui:FindFirstChild("Buttons") :: GuiObject?
	toast = gui:FindFirstChild("Toast") :: GuiObject?
	toastHome = toast and toast.Position

	BuildCatalog.init(gui, {
		place = beginPlace,
		closed = function()
			if not controls.Visible then
				finish()
			end
		end,
	})
	Menus.register(controls, {
		close = function()
			Motion.close(controls)
			if handingOff then
				handingOff = false
			else
				finish()
			end
		end,
	})

	button("ConfirmButton").Activated:Connect(confirm)
	button("CancelButton").Activated:Connect(cancel)
	button("RotateButton").Activated:Connect(function()
		rotate(1)
	end)
	button("SnapButton").Activated:Connect(cycleSnap)
	button("GridButton").Activated:Connect(cyclePrecision)
	button("RaiseButton").Activated:Connect(function()
		raise(1)
	end)
	button("LowerButton").Activated:Connect(function()
		raise(-1)
	end)
	State.onChanged(function()
		if controls.Visible then
			refreshControls()
		end
	end)
	bindInput()

	-- the banner's mode tabs and Exit
	local function bannerButton(name: string, fn: () -> ())
		local b = banner and banner:FindFirstChild(name) :: GuiButton?
		if b then
			b.Activated:Connect(fn)
		end
	end
	bannerButton("PlaceTab", function()
		if session == "idle" and BuildCatalog.isOpen() then
			return
		end
		backToCatalog()
	end)
	bannerButton("MoveTab", function()
		beginPick("move")
	end)
	bannerButton("StoreTab", function()
		beginPick("store")
	end)
	bannerButton("ExitButton", BuildMode.close)
	-- Menus re-shows the tiles whenever a window changes; keep them hidden while building
	Menus.onChanged(refreshBanner)

	-- the Build tile shows only on (or over) your own peak
	local toggle = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("BuildButton") :: GuiButton
	toggle.Activated:Connect(function()
		if active() then
			BuildMode.close()
		else
			BuildMode.open()
		end
	end)
	task.spawn(function()
		while true do
			local frame = MyPeak.frame()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local offset = frame and root and root.Position - frame.Position
			toggle.Visible = active() or (offset ~= nil and Vector2.new(offset.X, offset.Z).Magnitude <= PEAK_RADIUS)
			task.wait(0.5)
		end
	end)
end

return BuildMode
