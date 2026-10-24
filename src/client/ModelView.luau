--!strict
-- Draws a herb's or an item's real 3D model in a ViewportFrame, the way WeaponView
-- shows weapons (user, 2026-10-23: "you know how we display weapons? should be the
-- same for herbs and plants"). Used by the Herbarium's cards; ready for the
-- Inventory's herb and pill cells and the hotbar (docs/ui/inventory.md).
--
--   ModelView.herb(frame, herbId, opts?) -> boolean
--       Herbs.template: ReplicatedStorage.HerbModels (place file), then
--       HerbModelsExtra, else the herb's tinted stand-in.
--   ModelView.item(frame, itemId, opts?) -> boolean
--       ReplicatedStorage.ItemModels (pills, cores, dew...), then the herb models
--       (a herb in the pouch is an item with the herb's id).
--   ModelView.show(frame, template, opts?) -> boolean   any Model template
--   ModelView.clear(frame)
--   opts = { pose = "upright" | "diagonal"?, silhouette = boolean?, margin = number? }
--   (margin: each side, as a share of the frame; default 0.04)
--
-- Each returns whether a model is shown; false (no model) clears and hides the frame,
-- so the caller shows its icon instead. Showing what the frame already shows does
-- nothing (the frame's `Shows` attribute), so re-filling a card on every state push
-- costs nothing.
--
-- Poses: "upright" (default) stands the model on its base, turned a little to the
-- right and seen slightly from above, so a plant reads as a plant; "diagonal" also
-- rolls it 45 degrees, the weapons' lie. Lit from the upper left like the kit's art.
-- The camera fits every part's corners, so the model fills the frame with an even
-- margin whatever its proportions. `silhouette` draws it as a flat dark shape (no
-- light at all) for a herb the player hasn't found yet.
--
-- Cost: live viewports, not thumbnails. A ViewportFrame only re-renders when its
-- contents change, and these are static clones (herbs 15-85 parts, items 4-10), so
-- the Herbarium's twelve visible cards are one draw each per page turn; no per-frame
-- work. Scripts, sounds, particles, beams, trails and lights are stripped from clones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Herbs = require(ReplicatedStorage.Shared.Herbs)

local ModelView = {}

export type Options = {
	pose: string?, -- "upright" (default) or "diagonal"
	silhouette: boolean?, -- a flat dark shape (undiscovered)
	margin: number?, -- each side, as a share of the frame (default 0.06)
}

local FOV = 20
local MARGIN = 0.04
local YAW = math.rad(-25) -- turned so its right side faces the viewer a little
local PITCH = math.rad(14) -- seen from slightly above
local ROLL = math.rad(-45) -- diagonal: base at the lower left, top at the upper right
local LIGHT = Vector3.new(1, -1.2, -0.8) -- in camera space: from the upper left, in front
local AMBIENT = Color3.fromRGB(125, 120, 112) -- low enough that pale petals shade off the cream paper
local LIGHT_COLOR = Color3.fromRGB(190, 184, 172)
local SHADOW = Color3.new(0, 0, 0)
local SILHOUETTE_FADE = 0.45 -- the dark shape lets the card's paper through
local CORNERS = {
	Vector3.new(1, 1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, -1, -1),
}

local STRIP = {
	"Script",
	"LocalScript",
	"ModuleScript",
	"Sound",
	"ParticleEmitter",
	"Beam",
	"Trail",
	"Light",
	"BillboardGui",
	"SurfaceGui",
}

local emptyFolder = Instance.new("Folder") -- for Herbs.template when HerbModels is missing

function ModelView.clear(frame: ViewportFrame)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") or child:IsA("BasePart") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	frame:SetAttribute("Shows", nil)
	frame.Visible = false
end

local function clean(model: Model, silhouette: boolean)
	for _, d in model:GetDescendants() do
		local drop = false
		for _, class in STRIP do
			if d:IsA(class) then
				drop = true
				break
			end
		end
		if drop then
			d:Destroy()
		elseif silhouette and d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Material = Enum.Material.SmoothPlastic -- neon ignores the frame's light
		end
	end
end

type Fit = { right: Vector3, up: Vector3, back: Vector3, lo: Vector3, hi: Vector3, margin: number }
local fits: { [ViewportFrame]: Fit } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [ViewportFrame]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Point the frame's camera so the model's extents fill it with the margin, for the
-- frame's current shape (re-run when the frame resizes: a card filled before it is
-- laid out, a phone UIScale).
local function aim(frame: ViewportFrame)
	local fit = fits[frame]
	local camera = frame.CurrentCamera
	if not fit or not camera then
		return
	end
	local size = fit.hi - fit.lo
	local aspect = if frame.AbsoluteSize.Y > 0 then frame.AbsoluteSize.X / frame.AbsoluteSize.Y else 1
	local span = math.max(size.Y, size.X / aspect) / (1 - 2 * fit.margin)
	local distance = (span / 2) / math.tan(math.rad(FOV / 2)) + size.Z / 2
	local mid = (fit.lo + fit.hi) / 2
	local centre = fit.right * mid.X + fit.up * mid.Y + fit.back * mid.Z
	camera.CFrame = CFrame.fromMatrix(centre + fit.back * distance, fit.right, fit.up, fit.back)
end

-- Lay `model` (a fresh clone) in `frame` and point a fitted camera at it.
local function place(frame: ViewportFrame, model: Model, opts: Options)
	local silhouette = opts.silhouette == true
	clean(model, silhouette)
	local roll = if opts.pose == "diagonal" then ROLL else 0
	local view = CFrame.Angles(0, YAW, 0) * CFrame.Angles(-PITCH, 0, 0) * CFrame.Angles(0, 0, roll)
	local right, up, back = view.RightVector, view.UpVector, -view.LookVector
	-- every visible part's corners in the view's axes
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			local h = part.Size / 2
			for _, s in CORNERS do
				local p = part.CFrame:PointToWorldSpace(h * s)
				local v = Vector3.new(p:Dot(right), p:Dot(up), p:Dot(back))
				lo, hi = lo:Min(v), hi:Max(v)
			end
		end
	end
	if lo.X == math.huge then
		lo, hi = -Vector3.one, Vector3.one
	end
	fits[frame] = { right = right, up = up, back = back, lo = lo, hi = hi, margin = opts.margin or MARGIN }
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = frame
	frame.CurrentCamera = camera
	aim(frame)
	if not watched[frame] then
		watched[frame] = true
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			aim(frame)
		end)
	end
	frame.LightDirection = view:VectorToWorldSpace(LIGHT.Unit)
	frame.Ambient = if silhouette then SHADOW else AMBIENT
	frame.LightColor = if silhouette then SHADOW else LIGHT_COLOR
	frame.ImageTransparency = if silhouette then SILHOUETTE_FADE else 0
	model.Parent = frame
end

local function present(frame: ViewportFrame, key: string?, make: () -> Model?, opts: Options?): boolean
	local o: Options = opts or {}
	local full = if key then `{key}|{o.pose or "upright"}|{if o.silhouette then "s" else "m"}` else nil
	if full and frame:GetAttribute("Shows") == full and frame:FindFirstChildOfClass("Model") then
		frame.Visible = true
		return true -- already showing it
	end
	ModelView.clear(frame)
	local model = if key then make() else nil
	if not model then
		return false
	end
	place(frame, model, o)
	frame:SetAttribute("Shows", full)
	frame.Visible = true
	return true
end

-- Any Model template (cloned; the template is left alone).
function ModelView.show(frame: ViewportFrame, template: Model?, opts: Options?): boolean
	return present(frame, if template then template:GetFullName() else nil, function()
		return if template then template:Clone() else nil
	end, opts)
end

function ModelView.herb(frame: ViewportFrame, id: string?, opts: Options?): boolean
	return present(frame, if id and id ~= "" then "herb:" .. id else nil, function()
		local folder = ReplicatedStorage:FindFirstChild("HerbModels") or emptyFolder
		local model = Herbs.clone(folder, id :: string)
		return model
	end, opts)
end

function ModelView.item(frame: ViewportFrame, id: string?, opts: Options?): boolean
	local folder = ReplicatedStorage:FindFirstChild("ItemModels")
	local own = id and folder and folder:FindFirstChild(id)
	if own and own:IsA("Model") then
		return present(frame, "item:" .. (id :: string), function()
			return own:Clone()
		end, opts)
	end
	return ModelView.herb(frame, id, opts)
end

return ModelView
