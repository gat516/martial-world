--!strict
-- Build mode on your own peak.
--   Place: pick an item; a ghost follows the mouse (or your last tap on touch).
--          Click (desktop) or Place (any device) to build it; R / Rotate turns it.
--   Store: tap or click anything on your peak to select it, then tap it again (or Store)
--          to put it in your inventory. Stored items show first in the bar with a count.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Build
local Peak = require(ReplicatedStorage.Shared.Peak)
local Hud = require(script.Parent.Hud)
local MyPeak = require(script.Parent.MyPeak)
local State = require(script.Parent.State)

local buildRemote = ReplicatedStorage.Remotes.BuildAction :: RemoteFunction
local catalog = ReplicatedStorage:WaitForChild("BuildCatalog")

local VALID_COLOR = Color3.fromRGB(90, 220, 150)
local INVALID_COLOR = Color3.fromRGB(230, 80, 80)
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
local storeBox: SelectionBox? = nil
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
	aim = Vector3.new(Peak.snap(l.X, Config.GRID), l.Y, Peak.snap(l.Z, Config.GRID))
	aimValid = Peak.inBounds(aim) and Peak.of(hit.Instance) == peak
end

local function updateGhost()
	local frame = MyPeak.frame()
	if not (ghost and ghostHighlight and frame and aim) then
		return
	end
	ghost:PivotTo(frame * CFrame.new(aim) * CFrame.Angles(0, math.rad(yaw), 0))
	ghostHighlight.FillColor = if aimValid then VALID_COLOR else INVALID_COLOR
	ghostHighlight.OutlineColor = ghostHighlight.FillColor
end

-- Store selection -------------------------------------------------------------

local function setStoreTarget(piece: Instance?)
	storeTarget = piece
	if storeBox then
		storeBox.Adornee = piece :: PVInstance?
	end
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
		local ok, message = buildRemote:InvokeServer("place", { item = selectedId, pos = aim, yaw = yaw })
		if not ok and message then
			Hud.toast(message)
		end
	elseif mode == "store" and storeTarget then
		local ok, message = buildRemote:InvokeServer("store", { target = storeTarget })
		if not ok and message then
			Hud.toast(message)
		end
		setStoreTarget(nil)
	end
end

local function rotate()
	yaw = (yaw + Config.ROTATE_STEP) % 360
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
end

function BuildMode.open()
	if not MyPeak.model() then
		Hud.toast("You don't have a peak to build on")
		return
	end
	active = true
	bar.Visible = true
	setMode("idle")
	local box = Instance.new("SelectionBox")
	box.Color3 = VALID_COLOR
	box.LineThickness = 0.08
	box.Parent = workspace.CurrentCamera
	storeBox = box
	stepConn = RunService.RenderStepped:Connect(onStep)
end

function BuildMode.close()
	active = false
	bar.Visible = false
	deselectItem()
	setStoreTarget(nil)
	if storeBox then
		storeBox:Destroy()
		storeBox = nil
	end
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
end

function BuildMode.init(gui: ScreenGui)
	bar = gui:FindFirstChild("BuildBar") :: Frame
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
	button("RotateButton").Activated:Connect(rotate)
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
			rotate()
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
end

return BuildMode
