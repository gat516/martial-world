--!strict
-- Shows a weapon's real model in a slot's Model ViewportFrame (Inventory cells and
-- preview, the weapon slot, the drag ghost), instead of a flat icon (user,
-- 2026-10-23: "we should opt for like, using a photo of the tool").
--
-- Live viewports rather than uploaded thumbnails: only weapons get one (a player owns a
-- handful, one cell each, plus the preview and the weapon slot), each is a static
-- part-built model of 9-24 parts, and a ViewportFrame only re-renders when its
-- contents change, so a dozen cost little even on phones. In return a new weapon or
-- a retextured model shows up with no render-and-upload step.
--
-- One shared pose: the model is laid diagonally, hilt (its PrimaryPart) at the lower
-- left and tip at the upper right, its flat side to the camera, lit from the upper
-- left like the kit's art, then framed so its bounding box fills the frame with an
-- even margin. CLASS_POSE tunes the angle or margin per class.
-- Models: ReplicatedStorage.WeaponModels (the same assets/WeaponModels.rbxm the server
-- holds in ServerStorage, mapped twice so the client can draw them).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(ReplicatedStorage.Shared.Weapons)

local WeaponView = {}

local FOV = 20
local MARGIN = 0.04 -- each side, as a share of the frame
type Pose = { angle: number, margin: number }
local DEFAULT_POSE: Pose = { angle = 45, margin = MARGIN }
-- per class: the angle of the long axis above horizontal (degrees) and the margin
local CLASS_POSE: { [string]: Pose } = {}

local function models(): Instance?
	return ReplicatedStorage:FindFirstChild("WeaponModels")
end

-- The model's local axes, longest first, and its box (in the PrimaryPart's frame).
local function axes(model: Model): ({ Vector3 }, Vector3, CFrame)
	local box, size = model:GetBoundingBox()
	local list = {
		{ v = box.RightVector, n = size.X },
		{ v = box.UpVector, n = size.Y },
		{ v = box.LookVector, n = size.Z },
	}
	table.sort(list, function(a, b)
		return a.n > b.n
	end)
	return { list[1].v, list[2].v, list[3].v }, Vector3.new(list[1].n, list[2].n, list[3].n), box
end

-- Show weaponId's model in frame (nil or a missing model: clear it). Returns whether
-- a model is shown.
function WeaponView.show(frame: ViewportFrame, weaponId: string?): boolean
	local def = weaponId and Weapons.Defs[weaponId]
	local folder = models()
	local template = def and folder and folder:FindFirstChild(def.model)
	if template and def and frame:GetAttribute("Shows") == def.model and frame:FindFirstChildOfClass("Model") then
		frame.Visible = true
		return true -- already showing it
	end
	for _, child in frame:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	frame:SetAttribute("Shows", if template and def then def.model else nil)
	if not template or not def or not template:IsA("Model") then
		frame.Visible = false
		return false
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	local pose = CLASS_POSE[def.class] or DEFAULT_POSE
	local axis, size, box = axes(model)
	-- the view: long axis on the diagonal, the middle axis across it in the screen
	-- plane (the blade's flat side faces the camera), the thinnest toward the camera
	local a = math.rad(pose.angle)
	local long = Vector3.new(math.cos(a), math.sin(a), 0)
	local across = Vector3.new(-math.sin(a), math.cos(a), 0)
	local depth = long:Cross(across)
	-- the hilt goes to the lower left: flip the long axis if it points at the hilt
	local hilt = model.PrimaryPart
	local along = axis[1]
	if hilt and (hilt.Position - box.Position):Dot(along) > 0 then
		along = -along
	end
	local side = axis[2]
	local thin = along:Cross(side)
	-- rotation taking the model's (along, side, thin) onto the view's (long, across, depth)
	local from = CFrame.fromMatrix(Vector3.zero, along, side, thin)
	local to = CFrame.fromMatrix(Vector3.zero, long, across, depth)
	model:PivotTo(to * from:Inverse() * (CFrame.new(-box.Position) * model:GetPivot()))
	-- frame the rotated box: its extent on screen, plus the margin
	local w = math.abs(long.X) * size.X + math.abs(across.X) * size.Y
	local h = math.abs(long.Y) * size.X + math.abs(across.Y) * size.Y
	local aspect = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.X / frame.AbsoluteSize.Y else 1
	local fit = math.max(h, w / aspect) / (1 - 2 * pose.margin)
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	local distance = (fit / 2) / math.tan(math.rad(FOV / 2)) + size.Z
	camera.CFrame = CFrame.new(Vector3.new(0, 0, distance), Vector3.zero)
	camera.Parent = frame
	frame.CurrentCamera = camera
	model.Parent = frame
	frame.Visible = true
	return true
end

return WeaponView
