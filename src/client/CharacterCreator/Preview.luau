--!strict
-- The character in the middle of the screen: an R6 dummy (Templates.Dummy,
-- every part anchored) standing on the jade pedestal in the Preview
-- ViewportFrame's WorldModel, seen through its own Camera. Drag (mouse or touch)
-- to turn it; it eases toward the dragged angle. Shirt, pants, hair and hair
-- colour update live from the tabs.

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
local hair: Accessory? = nil
local yaw, target = START_YAW, START_YAW
local dragging: InputObject? = nil
local lastX = 0
local stepper: RBXScriptConnection? = nil

-- The local player's skin on the dummy, when their avatar has one to copy.
local function copySkin()
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	if not character then
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

local function frame()
	local fov = math.rad(camera.FieldOfView)
	local distance = (FRAME_HEIGHT / 2) / math.tan(fov / 2)
	-- the dummy faces -Z, so the camera stands on that side
	camera.CFrame = CFrame.lookAt(Vector3.new(0, CAMERA_HEIGHT, -distance), LOOK_AT)
end

local function pose()
	dummy:PivotTo(base * CFrame.Angles(0, yaw, 0))
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Preview.init(frameGui: ViewportFrame, templates: Folder)
	viewport = frameGui
	camera = viewport:FindFirstChild("Camera") :: Camera
	viewport.CurrentCamera = camera
	local world = viewport:FindFirstChild("World") :: WorldModel
	dummy = (templates:FindFirstChild("Dummy") :: Model):Clone()
	base = dummy:GetPivot()
	dummy.Parent = world
	copySkin()
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

-- Puts a hair accessory on the dummy (nil takes it off). The accessory is
-- cloned, anchored and placed by its attachment, so turning the dummy carries it.
function Preview.setHair(source: Accessory?)
	if hair then
		hair:Destroy()
		hair = nil
	end
	if not source then
		return
	end
	local accessory = source:Clone()
	local handle = accessory:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		accessory:Destroy()
		return
	end
	for _, d in accessory:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	local attachment = handle:FindFirstChildOfClass("Attachment")
	local onBody = attachment and dummy:FindFirstChild(attachment.Name, true)
	if attachment and onBody and onBody:IsA("Attachment") then
		handle.CFrame = onBody.WorldCFrame * attachment.CFrame:Inverse()
	else
		local head = dummy:FindFirstChild("Head") :: BasePart
		handle.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2, 0) * accessory.AttachmentPoint:Inverse()
	end
	accessory.Parent = dummy
	hair = accessory
end

function Preview.tintHair(color: Color3, tint: (Accessory, Color3) -> ())
	if hair then
		tint(hair, color)
	end
end

return Preview
