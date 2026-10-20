--!strict
-- Build mode on your own peak.
--   Place: pick a catalog item; a ghost follows the mouse (or your last tap on touch).
--          Click (desktop) or Place (any device) to build it; R / Rotate turns it.
--   Delete: tap or click any placed item or starter piece, then Remove.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Build
local Peak = require(ReplicatedStorage.Shared.Peak)
local Hud = require(script.Parent.Hud)
local MyPeak = require(script.Parent.MyPeak)

local buildRemote = ReplicatedStorage.Remotes.BuildAction :: RemoteFunction
local catalog = ReplicatedStorage:WaitForChild("BuildCatalog")
local player = Players.LocalPlayer

local VALID_COLOR = Color3.fromRGB(90, 220, 150)
local INVALID_COLOR = Color3.fromRGB(230, 80, 80)
local GHOST_TRANSPARENCY = 0.45
local RAY_LENGTH = 600

local HINTS = {
	idle = "Pick an item below, or Delete to clear things away",
	place = "Tap where it goes, then Place. R or Rotate turns it",
	delete = "Tap something on your peak, then Remove",
}

local BuildMode = {}

local bar: Frame
local actions: Frame
local hint: TextLabel
local active = false
local mode: "idle" | "place" | "delete" = "idle"
local selectedId: string? = nil
local selectedButton: GuiButton? = nil
local yaw = 0
local ghost: Model? = nil
local ghostHighlight: Highlight? = nil
local aim: Vector3? = nil -- peak-local snapped position of the ghost
local aimValid = false
local deleteTarget: Instance? = nil
local deleteBox: SelectionBox? = nil
local stepConn: RBXScriptConnection? = nil

local function button(name: string): TextButton
	return actions:FindFirstChild(name) :: TextButton
end

local function setMode(m: "idle" | "place" | "delete")
	mode = m
	hint.Text = HINTS[m]
	button("PlaceButton").Text = if m == "delete" then "Remove" else "Place"
	button("PlaceButton").Visible = m ~= "idle"
	button("RotateButton").Visible = m == "place"
	button("DeleteButton").Text = if m == "delete" then "Cancel" else "Delete"
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
	for _, tag in CollectionService:GetTags(g) do
		g:RemoveTag(tag)
	end
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

local function raycastFrom(screenPos: Vector2): RaycastResult?
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if ghost then
		table.insert(ignore, ghost)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
end

local function aimAt(screenPos: Vector2)
	local frame, peak = MyPeak.frame(), MyPeak.model()
	local hit = raycastFrom(screenPos)
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

-- Delete selection ------------------------------------------------------------

local function selectForDelete(screenPos: Vector2)
	local hit = raycastFrom(screenPos)
	local piece = hit and Peak.pieceOf(hit.Instance)
	if piece and Peak.of(piece) == MyPeak.model() then
		deleteTarget = piece
		if deleteBox then
			deleteBox.Adornee = piece :: PVInstance
		end
	else
		deleteTarget = nil
		if deleteBox then
			deleteBox.Adornee = nil
		end
	end
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
	elseif mode == "delete" and deleteTarget then
		local ok, message = buildRemote:InvokeServer("remove", { target = deleteTarget })
		if not ok and message then
			Hud.toast(message)
		end
		deleteTarget = nil
		if deleteBox then
			deleteBox.Adornee = nil
		end
	end
end

local function rotate()
	yaw = (yaw + Config.ROTATE_STEP) % 360
	updateGhost()
end

local function selectItem(itemId: string, tile: GuiButton)
	if selectedButton then
		((selectedButton :: GuiButton):FindFirstChild("Selected") :: UIStroke).Enabled = false
	end
	selectedId, selectedButton = itemId, tile;
	(tile:FindFirstChild("Selected") :: UIStroke).Enabled = true
	deleteTarget = nil
	makeGhost(itemId)
	setMode("place")
end

-- Catalog -------------------------------------------------------------------

local function previewInto(viewport: ViewportFrame, template: Model)
	local model = template:Clone()
	for _, tag in CollectionService:GetTags(model) do
		model:RemoveTag(tag)
	end
	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = size.Magnitude * 1.25
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.8, 1).Unit * distance, cf.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function buildCatalog()
	local list = bar:FindFirstChild("Catalog") :: ScrollingFrame
	local template = list:FindFirstChild("ItemTemplate") :: TextButton
	local items = catalog:GetChildren()
	table.sort(items, function(a, b)
		return (a:GetAttribute("Order") or 99) < (b:GetAttribute("Order") or 99)
	end)
	for i, item in items do
		if item:IsA("Model") then
			local tile = template:Clone()
			tile.Name = item.Name
			tile.LayoutOrder = i
			tile.Visible = true;
			(tile:FindFirstChild("NameLabel") :: TextLabel).Text = item:GetAttribute("DisplayName") or item.Name
			previewInto(tile:FindFirstChild("Preview") :: ViewportFrame, item)
			tile.Activated:Connect(function()
				selectItem(item.Name, tile)
			end)
			tile.Parent = list
		end
	end
end

-- Open / close ----------------------------------------------------------------

local function onStep()
	if mode == "place" and UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		aimAt(UserInputService:GetMouseLocation())
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
	box.Color3 = INVALID_COLOR
	box.LineThickness = 0.08
	box.Parent = workspace.CurrentCamera
	deleteBox = box
	stepConn = RunService.RenderStepped:Connect(onStep)
end

function BuildMode.close()
	active = false
	bar.Visible = false
	clearGhost()
	if selectedButton then
		((selectedButton :: GuiButton):FindFirstChild("Selected") :: UIStroke).Enabled = false
	end
	selectedId, selectedButton, deleteTarget = nil, nil, nil
	if deleteBox then
		deleteBox:Destroy()
		deleteBox = nil
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
		clearGhost()
		deleteTarget = nil
		setMode(if mode == "delete" then "idle" else "delete")
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
				aimAt(pos)
			elseif mode == "delete" then
				selectForDelete(pos)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = UserInputService:GetMouseLocation()
			if mode == "place" then
				aimAt(pos)
				confirm()
			elseif mode == "delete" then
				selectForDelete(pos)
			end
		end
	end)
end

return BuildMode
