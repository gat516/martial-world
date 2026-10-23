--!strict
-- The world behind the character screen (Shared.CharacterCreator.Background).
--   Live:  the player's camera is parked at the vantage (a part tagged
--          Background.VantageTag, else Background.VantageCFrame) with a slow
--          sway, and the world is softened by a blur and depth of field that
--          exist only while the screen is open.
--   Image: the GUI's Backdrop.Image (FallbackImage, else its ink-wash gradient
--          and mountain mist). Also used when there's no vantage, and in the
--          testbed (no map), where only a tagged part counts.
-- The vignette frames in Backdrop are always on so the UI reads on any view.
-- close() puts the camera and Lighting back exactly as they were.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Backdrop = {}

type Saved = { cameraType: Enum.CameraType, subject: Instance?, fov: number }

local saved: Saved? = nil
local STEP = "CharacterCreatorBackdrop"
local effects: { Instance } = {}

local function vantage(settings: any): CFrame?
	for _, tagged in CollectionService:GetTagged(settings.VantageTag) do
		if tagged:IsA("BasePart") and tagged:IsDescendantOf(workspace) then
			return tagged.CFrame
		end
	end
	-- the fixed vantage looks at the main map; a place without Workspace.Map (the
	-- bare testbed) gets the image instead of an empty sky
	return if workspace:FindFirstChild("Map") then settings.VantageCFrame else nil
end

local function addEffects(settings: any)
	if settings.Blur and settings.Blur > 0 then
		local blur = Instance.new("BlurEffect")
		blur.Name = "CharacterCreatorBlur"
		blur.Size = settings.Blur
		blur.Parent = Lighting
		table.insert(effects, blur)
	end
	local dof = settings.DepthOfField
	if dof and dof.Enabled then
		local effect = Instance.new("DepthOfFieldEffect")
		effect.Name = "CharacterCreatorFocus"
		effect.FocusDistance = dof.FocusDistance
		effect.InFocusRadius = dof.InFocusRadius
		effect.FarIntensity = dof.FarIntensity
		effect.NearIntensity = 0
		effect.Parent = Lighting
		table.insert(effects, effect)
	end
end

function Backdrop.open(frame: Frame, settings: any)
	local image = frame:FindFirstChild("Image") :: ImageLabel
	local view = if settings.Mode == "Live" then vantage(settings) else nil
	image.Image = settings.FallbackImage or ""
	local mist = image:FindFirstChild("Mist") :: ImageLabel?
	if mist then
		mist.Visible = image.Image == "" -- the mist belongs to the plain gradient
	end
	image.Visible = view == nil
	if not view or saved then
		return
	end
	local camera = workspace.CurrentCamera
	saved = { cameraType = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
	addEffects(settings)
	local drift = settings.Drift or { Degrees = 0, Period = 1 }
	local start = os.clock()
	local function place()
		local cam = workspace.CurrentCamera
		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable -- respawns hand the camera back to the player
		end
		local t = (os.clock() - start) / math.max(drift.Period, 0.1) * math.pi * 2
		local sway = CFrame.Angles(math.rad(drift.Degrees * 0.25 * math.sin(t * 2)), math.rad(drift.Degrees * math.sin(t)), 0)
		cam.CFrame = (view :: CFrame) * sway
		cam.FieldOfView = settings.FieldOfView
	end
	place()
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 1, place)
end

function Backdrop.close()
	RunService:UnbindFromRenderStep(STEP)
	for _, effect in effects do
		effect:Destroy()
	end
	table.clear(effects)
	local was = saved
	if not was then
		return
	end
	saved = nil
	local camera = workspace.CurrentCamera
	local subject = was.subject
	if not subject or not subject:IsDescendantOf(game) then
		local character = Players.LocalPlayer.Character
		subject = character and character:FindFirstChildOfClass("Humanoid")
	end
	-- Before a character exists the camera sits in Fixed (no auto loading in the
	-- test place); handing that back would leave it parked at the vantage.
	local stuck = was.cameraType == Enum.CameraType.Scriptable or was.cameraType == Enum.CameraType.Fixed
	camera.CameraType = if stuck then Enum.CameraType.Custom else was.cameraType
	camera.CameraSubject = subject
	camera.FieldOfView = was.fov
end

return Backdrop
