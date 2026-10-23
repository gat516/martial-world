--!strict
-- The character on the stage: an R6 dummy (Templates.Dummy,
-- every part anchored) standing on the jade pedestal in the Preview
-- ViewportFrame's WorldModel, seen through its own Camera. Drag (mouse or touch)
-- to turn it; it eases toward the dragged angle. Shirt, pants, hair and hair
-- colour update live from the tabs; the race's look (cosmetics and body size)
-- from the drawn race (Look.race).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Preview = {}

local START_YAW = math.rad(-14) -- a slight three-quarter turn, like the references
local DRAG_SPEED = 0.011 -- radians per pixel dragged
local EASE = 12 -- how fast the dummy catches up with the drag (per second)
local LOOK_AT = Vector3.new(0, 2.3, 0) -- framing: the dummy's middle, a little low
local CAMERA_HEIGHT = 2.8
local FRAME_HEIGHT = 9.0 -- studs of height the camera keeps in view (dummy + pedestal + margin)

local viewport: ViewportFrame
local camera: Camera
local dummy: Model
local base: CFrame
local hairs: { [number]: Accessory } = {} -- by Hair tab slot
local cosmetics: { Accessory } = {} -- the race's (ReplicatedStorage.Cosmetics)
local bodyScale = 1 -- the race's size (Giant's Titan Frame)
local avatarSkin: Color3? = nil -- the avatar's skin, for when there's no character to copy
local chosenSkin: Color3? = nil -- a SkinColors pick; nil keeps the avatar's skin
local yaw, target = START_YAW, START_YAW
local dragging: InputObject? = nil
local lastX = 0
local stepper: RBXScriptConnection? = nil

-- The local player's skin on the dummy, from their character or, before one
-- has spawned, from their avatar (Preview.setSkin).
-- A skin picked on the Clothes tab (Preview.chooseSkin) wins over both.
local function copySkin()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local flat = chosenSkin or (if character then nil else avatarSkin)
	if flat or not character then
		if flat then
			for _, part in dummy:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Color = flat
				end
			end
		end
		return
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	local head = character:FindFirstChild("Head")
	local skin = if colors then colors.HeadColor3 elseif head and head:IsA("BasePart") then head.Color else nil
	if not skin then
		return
	end
	for _, part in dummy:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = skin
		end
	end
	if colors then
		local map = {
			Torso = colors.TorsoColor3,
			["Left Arm"] = colors.LeftArmColor3,
			["Right Arm"] = colors.RightArmColor3,
			["Left Leg"] = colors.LeftLegColor3,
			["Right Leg"] = colors.RightLegColor3,
		}
		for name, color in map do
			local part = dummy:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = color
			end
		end
	end
end

local ground = 0 -- the pedestal top under the dummy's feet (measured in init)

-- The lowest point of the dummy's legs.
local function feet(): number
	local low = math.huge
	for _, name in { "Left Leg", "Right Leg" } do
		local leg = dummy:FindFirstChild(name)
		if leg and leg:IsA("BasePart") then
			low = math.min(low, leg.Position.Y - leg.Size.Y / 2)
		end
	end
	return low
end

-- The camera keeps the whole body in view: a bigger body (Giant) pulls it back
-- and up by the same share, so the character fills the stage the same way and
-- reads big against the pedestal instead of running off the top.
local function frame()
	local fov = math.rad(camera.FieldOfView)
	local distance = (FRAME_HEIGHT * bodyScale / 2) / math.tan(fov / 2)
	local function lift(y: number): number
		return ground + (y - ground) * bodyScale
	end
	-- the dummy faces -Z, so the camera stands on that side
	camera.CFrame = CFrame.lookAt(
		Vector3.new(LOOK_AT.X, lift(CAMERA_HEIGHT), -distance),
		Vector3.new(LOOK_AT.X, lift(LOOK_AT.Y), LOOK_AT.Z)
	)
end

local function pose()
	dummy:PivotTo(base * CFrame.Angles(0, yaw, 0))
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Preview.init(frameGui: ViewportFrame, templates: Folder)
	viewport = frameGui
	-- Built here, not in the GUI file: a Camera inside a ViewportFrame doesn't
	-- survive the Rojo sync, so the preview would have none.
	camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local world = viewport:FindFirstChild("World") :: WorldModel
	dummy = (templates:FindFirstChild("Dummy") :: Model):Clone()
	base = dummy:GetPivot()
	dummy.Parent = world
	copySkin()
	ground = feet()
	frame()
	pose()

	viewport.InputBegan:Connect(function(input)
		if isPointer(input) and not dragging then
			dragging = input
			lastX = input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local drag = dragging
		if not drag then
			return
		end
		local moved = (drag.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
			or input == drag
		if moved then
			local hint = viewport:FindFirstChild("Hint")
			if hint and hint:IsA("TextLabel") then
				hint.Visible = false -- they've found it
			end
			target += (input.Position.X - lastX) * DRAG_SPEED
			lastX = input.Position.X
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == dragging or (dragging and input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)
end

-- Runs the turn easing only while the screen is open.
function Preview.setActive(on: boolean)
	if on and not stepper then
		copySkin()
		stepper = RunService.RenderStepped:Connect(function(dt)
			if math.abs(target - yaw) > 1e-3 then
				yaw += (target - yaw) * math.min(1, dt * EASE)
				pose()
			end
		end)
	elseif not on and stepper then
		stepper:Disconnect()
		stepper = nil
		dragging = nil
	end
end

-- kind "Shirt" or "Pants"; template "" takes the clothing off.
function Preview.setClothing(kind: string, template: string)
	local clothing = dummy:FindFirstChild(kind)
	if clothing and clothing:IsA("Shirt") then
		clothing.ShirtTemplate = template
	elseif clothing and clothing:IsA("Pants") then
		clothing.PantsTemplate = template
	end
end

-- The avatar's skin colour, used while the player has no character yet.
function Preview.setSkin(color: Color3?)
	avatarSkin = color
	copySkin()
end

-- The skin picked on the Clothes tab (nil goes back to the avatar's own).
function Preview.chooseSkin(color: Color3?)
	chosenSkin = color
	copySkin()
end

-- Scales the dummy (and everything on it) to `target`, keeping its feet on the
-- pedestal: ScaleTo scales about the pivot, so the legs' lowest point is put back.
local function scaleBody(target: number)
	if math.abs(dummy:GetScale() - target) < 1e-3 then
		return
	end
	dummy:PivotTo(base)
	local before = feet()
	dummy:ScaleTo(target)
	base = dummy:GetPivot() + Vector3.yAxis * (before - feet())
	pose()
end

-- Accessories go on at scale 1 (their attachments are authored for it), then
-- the body goes back to its size and they grow with it, as on the server.
local function atScaleOne(fn: () -> ())
	local was = dummy:GetScale()
	scaleBody(1)
	fn()
	scaleBody(was)
end

-- A clone of an accessory, anchored and placed by its attachment, so turning
-- the dummy carries it. Joints are dropped (nothing simulates in a viewport) and
-- the whole accessory moves rigidly with its Handle, so multi-part ones (ears,
-- tails) keep their shape.
local function wear(source: Accessory): Accessory?
	local accessory = source:Clone()
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		accessory:Destroy()
		return nil
	end
	local parts = {}
	for _, d in accessory:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			table.insert(parts, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	local attachment = handle:FindFirstChildOfClass("Attachment")
	local onBody = attachment and dummy:FindFirstChild(attachment.Name, true)
	local goal
	if attachment and onBody and onBody:IsA("Attachment") then
		goal = onBody.WorldCFrame * attachment.CFrame:Inverse()
	else
		local head = dummy:FindFirstChild("Head") :: BasePart
		goal = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0) * accessory.AttachmentPoint:Inverse()
	end
	local move = goal * handle.CFrame:Inverse()
	for _, part in parts do
		part.CFrame = move * part.CFrame
	end
	accessory.Parent = dummy
	return accessory
end

-- Puts a hair accessory on the dummy in a Hair tab slot (nil takes that one off).
function Preview.setHair(slot: number, source: Accessory?)
	local old = hairs[slot]
	if old then
		old:Destroy()
		hairs[slot] = nil
	end
	if not source then
		return
	end
	atScaleOne(function()
		hairs[slot] = wear(source)
	end)
end

-- The race's look: its cosmetics (templates from ReplicatedStorage.Cosmetics)
-- and body size. Replaces the previous race's.
function Preview.setRaceLook(templates: { Accessory }, scale: number)
	bodyScale = scale
	scaleBody(1)
	for _, accessory in cosmetics do
		accessory:Destroy()
	end
	table.clear(cosmetics)
	for _, template in templates do
		local accessory = wear(template)
		if accessory then
			table.insert(cosmetics, accessory)
		end
	end
	scaleBody(bodyScale)
	frame()
end

-- Paints another dummy's body (an outfit card's) in the stage dummy's colours, so
-- the cards show the skin the player will wear.
function Preview.copyBodyTo(model: Model)
	for _, part in dummy:GetChildren() do
		local twin = model:FindFirstChild(part.Name)
		if part:IsA("BasePart") and twin and twin:IsA("BasePart") then
			twin.Color = part.Color
		end
	end
end

-- Takes every hair off (a slot switch or a fresh look).
function Preview.clearHairs()
	for slot in table.clone(hairs) do
		Preview.setHair(slot, nil)
	end
end

function Preview.tintHair(color: Color3, tint: (Accessory, Color3) -> ())
	for _, hair in hairs do
		tint(hair, color)
	end
end

return Preview
