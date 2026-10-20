--!strict
-- Build mode on your own peak.
--   Place: pick an item; a ghost follows the mouse (or your finger as you drag on
--          touch) and sits on whatever surface it's over, snapped to the grid shown
--          under it. Click (desktop) or Place (any device) to build it. R / Rotate turns
--          it 45 degrees, Shift+R 15. Grid (or G) cycles the snap size.
--   Store: tap or click anything on your peak to select it (it lights up), then tap it
--          again (or Store) to put it in your inventory. On desktop, pieces glow
--          faintly as you hover over them. Stored items show first in the bar.
-- A ring marks how far from the plateau centre you can build.
-- The Build tile only shows on (or over) your own peak, where it does something.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Build
local PEAK_RADIUS = require(ReplicatedStorage.Shared.Config).Circulation.PEAK_RADIUS
local Peak = require(ReplicatedStorage.Shared.Peak)
local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local MyPeak = require(script.Parent.MyPeak)
local State = require(script.Parent.State)

local buildRemote = ReplicatedStorage.Remotes.BuildAction :: RemoteFunction
local catalog = ReplicatedStorage:WaitForChild("BuildCatalog")

local VALID_COLOR = Color3.fromRGB(90, 220, 150)
local INVALID_COLOR = Color3.fromRGB(230, 80, 80)
local STORE_COLOR = Color3.fromRGB(255, 190, 90)
local HOVER_COLOR = Color3.fromRGB(255, 255, 255)
local GRID_COLOR = Color3.fromRGB(150, 235, 200)
local GRID_LINES = 9 -- lines each way in the grid shown under the ghost
local GHOST_TRANSPARENCY = 0.45
local RAY_LENGTH = 600

type Mode = "idle" | "place" | "store"

local HINTS = {
	idle = "Pick an item below, or Store to pack things away",
	place = "Tap where it goes, then Place. R or Rotate turns it",
	store = "Tap something on your peak, then tap it again to store it",
}

local BuildMode = {}

local bar: Frame
local actions: Frame
local hint: TextLabel
local active = false
local mode: Mode = "idle"
local selectedId: string? = nil
local selectedTile: GuiButton? = nil
local yaw = 0
local ghost: Model? = nil
local ghostHighlight: Highlight? = nil
local aim: Vector3? = nil -- peak-local snapped position of the ghost
local aimValid = false
local storeTarget: Instance? = nil
local storeHighlight: Highlight? = nil
local hoverHighlight: Highlight? = nil
local gridIndex = 1
local gridLines: { BasePart } = {}
local boundsRing: { BasePart } = {}
local bottomOffset = 0 -- pivot height above the ghost's lowest point
local stepConn: RBXScriptConnection? = nil
local tiles: { [string]: GuiButton } = {}

local function button(name: string): TextButton
	return actions:FindFirstChild(name) :: TextButton
end

local function setMode(m: Mode)
	mode = m
	hint.Text = HINTS[m]
	button("PlaceButton").Text = if m == "store" then "Store" else "Place"
	button("PlaceButton").Visible = m ~= "idle"
	button("RotateButton").Visible = m == "place"
	button("GridButton").Visible = m == "place"
	button("DeleteButton").Text = if m == "store" then "Cancel" else "Store"
end

local function stripTags(model: Instance)
	for _, tag in CollectionService:GetTags(model) do
		model:RemoveTag(tag)
	end
end

-- Ghost ---------------------------------------------------------------------

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostHighlight, aim = nil, nil, nil
	for _, line in gridLines do
		line.Transparency = 1
	end
end

local function gridSize(): number
	return Config.GRID_SIZES[gridIndex]
end

-- Thin lines under the ghost showing the snap grid.
local function ensureGrid()
	if #gridLines > 0 then
		return
	end
	for i = 1, GRID_LINES * 2 do
		local line = Instance.new("Part")
		line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
		line.Material = Enum.Material.Neon
		line.Color = GRID_COLOR
		line.Transparency = 1
		line.Size = Vector3.new(0.06, 0.06, 1)
		line.Parent = workspace.CurrentCamera
		gridLines[i] = line
	end
end

local function drawGrid(frame: CFrame, center: Vector3)
	ensureGrid()
	local step = gridSize()
	local half = (GRID_LINES - 1) / 2
	local length = step * (GRID_LINES - 1)
	for i = 0, GRID_LINES - 1 do
		local offset = (i - half) * step
		local along = gridLines[i + 1]
		local across = gridLines[GRID_LINES + i + 1]
		-- fade toward the edges
		local fade = 0.55 + 0.4 * math.abs(i - half) / half
		along.Size = Vector3.new(0.06, 0.06, length)
		along.CFrame = frame * CFrame.new(center + Vector3.new(offset, 0.08, 0))
		along.Transparency = fade
		across.Size = Vector3.new(length, 0.06, 0.06)
		across.CFrame = frame * CFrame.new(center + Vector3.new(0, 0.08, offset))
		across.Transparency = fade
	end
end

-- A ring at the build radius, so the limit is visible.
local function showBounds(on: boolean)
	for _, p in boundsRing do
		p:Destroy()
	end
	table.clear(boundsRing)
	local frame = MyPeak.frame()
	if not (on and frame) then
		return
	end
	local segments = 48
	local r = Config.RADIUS
	for i = 1, segments do
		local a = (i + 0.5) / segments * math.pi * 2
		local seg = Instance.new("Part")
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material = Enum.Material.Neon
		seg.Color = GRID_COLOR
		seg.Transparency = 0.5
		seg.Size = Vector3.new(0.15, 0.15, 2 * math.pi * r / segments)
		seg.CFrame = (frame :: CFrame) * CFrame.new(math.cos(a) * r, 1.2, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		seg.Parent = workspace.CurrentCamera
		table.insert(boundsRing, seg)
	end
end

-- A small jade burst where something was just built.
local function placedBurst(at: CFrame)
	local ring = Instance.new("Part")
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = VALID_COLOR
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = workspace.CurrentCamera
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 9, 9),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

local function makeGhost(itemId: string)
	clearGhost()
	local template = catalog:FindFirstChild(itemId) :: Model?
	if not template then
		return
	end
	local g = template:Clone()
	stripTags(g)
	for _, d in g:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Transparency = math.max(d.Transparency, GHOST_TRANSPARENCY)
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	-- seat the ghost on surfaces by its lowest point, not its pivot
	local pivot = g:GetPivot()
	local box, size = g:GetBoundingBox()
	bottomOffset = pivot.Position.Y - (box.Position.Y - size.Y / 2)
	local h = Instance.new("Highlight")
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = g
	g.Parent = workspace
	ghost, ghostHighlight = g, h
end

-- inViewport: true for UserInputService:GetMouseLocation() (includes the top-bar inset),
-- false for InputObject positions (which don't).
local function raycastFrom(screenPos: Vector2, inViewport: boolean): RaycastResult?
	local camera = workspace.CurrentCamera
	local ray = if inViewport
		then camera:ViewportPointToRay(screenPos.X, screenPos.Y)
		else camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if ghost then
		table.insert(ignore, ghost)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
end

local function aimAt(screenPos: Vector2, inViewport: boolean)
	local frame, peak = MyPeak.frame(), MyPeak.model()
	local hit = raycastFrom(screenPos, inViewport)
	if not (frame and peak and hit) then
		return
	end
	local l = frame:PointToObjectSpace(hit.Position)
	local step = gridSize()
	local snapped = Vector3.new(Peak.snap(l.X, step), l.Y + bottomOffset, Peak.snap(l.Z, step))
	aim = snapped
	aimValid = Peak.inBounds(snapped) and Peak.of(hit.Instance) == peak
end

local function updateGhost()
	local frame = MyPeak.frame()
	if not (ghost and ghostHighlight and frame and aim) then
		return
	end
	ghost:PivotTo(frame * CFrame.new(aim) * CFrame.Angles(0, math.rad(yaw), 0))
	ghostHighlight.FillColor = if aimValid then VALID_COLOR else INVALID_COLOR
	ghostHighlight.OutlineColor = ghostHighlight.FillColor
	drawGrid(frame, aim - Vector3.new(0, bottomOffset, 0))
end

-- Store selection -------------------------------------------------------------

local function setStoreTarget(piece: Instance?)
	storeTarget = piece
	if storeHighlight then
		storeHighlight.Adornee = piece
		storeHighlight.Enabled = piece ~= nil
	end
end

-- Desktop: pieces glow faintly under the mouse in store mode.
local function updateHover()
	if not hoverHighlight then
		return
	end
	local piece: Instance? = nil
	if mode == "store" and UserInputService.MouseEnabled then
		local hit = raycastFrom(UserInputService:GetMouseLocation(), true)
		piece = hit and Peak.pieceOf(hit.Instance)
		if piece and (Peak.of(piece) ~= MyPeak.model() or piece == storeTarget) then
			piece = nil
		end
	end
	hoverHighlight.Adornee = piece
	hoverHighlight.Enabled = piece ~= nil
end

-- Returns true when the tap landed on the piece that was already selected.
local function selectForStore(screenPos: Vector2, inViewport: boolean): boolean
	local hit = raycastFrom(screenPos, inViewport)
	local piece = hit and Peak.pieceOf(hit.Instance)
	if piece and Peak.of(piece) == MyPeak.model() then
		if piece == storeTarget then
			return true
		end
		setStoreTarget(piece)
	else
		setStoreTarget(nil)
	end
	return false
end

-- Actions -------------------------------------------------------------------

local function confirm()
	if mode == "place" and selectedId and aim then
		if not aimValid then
			Hud.toast("That spot isn't on your peak")
			return
		end
		local placedAt = aim
		local ok, message = buildRemote:InvokeServer("place", { item = selectedId, pos = placedAt, yaw = yaw })
		if not ok and message then
			Hud.toast(message)
		elseif ok then
			local frame = MyPeak.frame()
			if frame then
				placedBurst(frame * CFrame.new(placedAt - Vector3.new(0, bottomOffset - 0.1, 0)))
			end
		end
	elseif mode == "store" and storeTarget then
		local ok, message = buildRemote:InvokeServer("store", { target = storeTarget })
		if not ok and message then
			Hud.toast(message)
		end
		setStoreTarget(nil)
	end
end

local function rotate(fine: boolean?)
	yaw = (yaw + (if fine then Config.FINE_ROTATE_STEP else Config.ROTATE_STEP)) % 360
	updateGhost()
end

local function cycleGrid()
	gridIndex = gridIndex % #Config.GRID_SIZES + 1
	button("GridButton").Text = `Grid {gridSize()}`
	updateGhost()
end

local function highlightTile(tile: GuiButton?, on: boolean)
	if tile then
		(tile:FindFirstChild("Selected") :: UIStroke).Enabled = on
	end
end

local function selectItem(itemId: string, tile: GuiButton)
	highlightTile(selectedTile, false)
	selectedId, selectedTile = itemId, tile
	highlightTile(tile, true)
	setStoreTarget(nil)
	makeGhost(itemId)
	setMode("place")
end

local function deselectItem()
	highlightTile(selectedTile, false)
	selectedId, selectedTile = nil, nil
	clearGhost()
end

-- Catalog -------------------------------------------------------------------

local function previewInto(viewport: ViewportFrame, template: Model)
	local model = template:Clone()
	stripTags(model)
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.8, 1).Unit * size.Magnitude * 1.25, cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- Stored items first (with a count), then free catalog items; anything else is hidden.
local function refreshCatalog()
	local decor = State.current.decor or {}
	for itemId, tile in tiles do
		local item = catalog:FindFirstChild(itemId)
		local owned = decor[itemId] or 0
		local order = (item and item:GetAttribute("Order") or 99) :: number
		tile.Visible = owned > 0 or (item ~= nil and item:GetAttribute("Free") == true)
		tile.LayoutOrder = if owned > 0 then order else 1000 + order
		local count = tile:FindFirstChild("CountLabel") :: TextLabel
		count.Text = `x{owned}`
		count.Visible = owned > 0
		if not tile.Visible and selectedId == itemId then
			deselectItem()
			setMode("idle")
		end
	end
end

local function buildCatalog()
	local list = bar:FindFirstChild("Catalog") :: ScrollingFrame
	local template = list:FindFirstChild("ItemTemplate") :: TextButton
	for _, item in catalog:GetChildren() do
		if item:IsA("Model") then
			local tile = template:Clone()
			tile.Name = item.Name;
			(tile:FindFirstChild("NameLabel") :: TextLabel).Text = item:GetAttribute("DisplayName") or item.Name
			previewInto(tile:FindFirstChild("Preview") :: ViewportFrame, item)
			tile.Activated:Connect(function()
				selectItem(item.Name, tile)
			end)
			tile.Parent = list
			tiles[item.Name] = tile
		end
	end
	refreshCatalog()
	State.onChanged(refreshCatalog)
end

-- Open / close ----------------------------------------------------------------

local function onStep()
	if mode == "place" and UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		aimAt(UserInputService:GetMouseLocation(), true)
	end
	updateGhost()
	updateHover()
end

function BuildMode.open()
	if not MyPeak.model() then
		Hud.toast("You don't have a peak to build on")
		return
	end
	active = true
	Motion.open(bar)
	setMode("idle")
	local selected = Instance.new("Highlight")
	selected.FillColor = STORE_COLOR
	selected.OutlineColor = STORE_COLOR
	selected.FillTransparency = 0.55
	selected.Enabled = false
	selected.Parent = workspace.CurrentCamera
	storeHighlight = selected
	local hover = Instance.new("Highlight")
	hover.FillColor = HOVER_COLOR
	hover.OutlineColor = HOVER_COLOR
	hover.FillTransparency = 0.85
	hover.OutlineTransparency = 0.4
	hover.Enabled = false
	hover.Parent = workspace.CurrentCamera
	hoverHighlight = hover
	showBounds(true)
	stepConn = RunService.RenderStepped:Connect(onStep)
end

function BuildMode.close()
	active = false
	Motion.close(bar)
	deselectItem()
	setStoreTarget(nil)
	for _, h in { storeHighlight, hoverHighlight } do
		if h then
			h:Destroy()
		end
	end
	storeHighlight, hoverHighlight = nil, nil
	showBounds(false)
	for _, line in gridLines do
		line:Destroy()
	end
	table.clear(gridLines)
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
end

function BuildMode.init(gui: ScreenGui)
	bar = gui:FindFirstChild("BuildBar") :: Frame
	Menus.register(bar, { close = BuildMode.close })
	actions = bar:FindFirstChild("Actions") :: Frame
	hint = bar:FindFirstChild("Hint") :: TextLabel
	buildCatalog()

	local toggle = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("BuildButton") :: TextButton
	toggle.Activated:Connect(function()
		if active then
			BuildMode.close()
		else
			BuildMode.open()
		end
	end)
	button("DoneButton").Activated:Connect(BuildMode.close)
	task.spawn(function()
		while true do
			local frame = MyPeak.frame()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local offset = frame and root and root.Position - frame.Position
			toggle.Visible = active or (offset ~= nil and Vector2.new(offset.X, offset.Z).Magnitude <= PEAK_RADIUS)
			task.wait(0.5)
		end
	end)
	button("RotateButton").Activated:Connect(function()
		rotate(false)
	end)
	button("GridButton").Activated:Connect(cycleGrid)
	button("GridButton").Text = `Grid {gridSize()}`
	button("PlaceButton").Activated:Connect(confirm)
	button("DeleteButton").Activated:Connect(function()
		deselectItem()
		setStoreTarget(nil)
		setMode(if mode == "store" then "idle" else "store")
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R and mode == "place" then
			rotate(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
		elseif input.KeyCode == Enum.KeyCode.G and mode == "place" then
			cycleGrid()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if mode == "place" then
				aimAt(pos, false)
			elseif mode == "store" and selectForStore(pos, false) then
				confirm()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = UserInputService:GetMouseLocation()
			if mode == "place" then
				aimAt(pos, true)
				confirm()
			elseif mode == "store" and selectForStore(pos, true) then
				confirm()
			end
		end
	end)
	-- touch: the ghost follows the finger while it drags
	UserInputService.InputChanged:Connect(function(input, processed)
		if active and not processed and mode == "place" and input.UserInputType == Enum.UserInputType.Touch then
			aimAt(Vector2.new(input.Position.X, input.Position.Y), false)
		end
	end)
end

return BuildMode
