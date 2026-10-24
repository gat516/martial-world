--!strict
-- The spilled haul's spirit-light (server Haul; docs/systems/haul.md). Only the
-- player who died gets the Effect, so only they see it.
--   "spill" (at, expires)   show the light where they fell, until `expires`
--                           (server time); a new spill moves it
--   "spillGone" (reclaimed) hide it; when reclaimed, the arrival flourish plays
-- It reuses the onboarding guide's marker (ReplicatedStorage.Effects.Guide:
-- Marker, a formation circle with a column of light and rising motes; Arrive,
-- the one-shot flare), cloned for this and tinted spirit violet. Without the
-- template it falls back to a small glowing orb.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Sfx = require(script.Parent.Sfx)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local HaulSpill = {}

local COLOR = Color3.fromRGB(196, 160, 255) -- spirit violet, apart from the guide's jade
local RADIUS = 3.5 -- the circle's radius on the ground (studs)
local FADE = 30 -- the last seconds the light dims as it runs out

local current: Instance? = nil
local spot: Vector3? = nil
local expiresAt = 0
local rings: { ImageLabel } = {}
local column: Beam? = nil
local spin: RBXScriptConnection? = nil

local function guide(): Instance?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	return effects and effects:FindFirstChild("Guide")
end

local function ground(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace.CurrentCamera }
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

local function tint(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Color = ColorSequence.new(COLOR)
		elseif d:IsA("ImageLabel") then
			d.ImageColor3 = COLOR
		elseif d:IsA("Light") then
			d.Color = COLOR
		end
	end
end

local function clear()
	if spin then
		spin:Disconnect()
		spin = nil
	end
	if current then
		current:Destroy()
		current = nil
	end
	rings = {}
	column = nil
end

local function fallback(at: Vector3): Instance
	local orb = Instance.new("Part")
	orb.Name = "HaulSpill"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.6, 1.6, 1.6)
	orb.Material = Enum.Material.Neon
	orb.Color = COLOR
	orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch = true, false, false, false
	orb.CFrame = CFrame.new(at + Vector3.new(0, 2.5, 0))
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = COLOR, 12, 2
	light.Parent = orb
	return orb
end

local function show(at: Vector3, expires: number)
	clear()
	local foot = ground(at)
	spot = foot
	expiresAt = expires
	local template = guide()
	local proto = template and template:FindFirstChild("Marker")
	if proto and proto:IsA("Model") then
		local marker = proto:Clone()
		marker.Name = "HaulSpill"
		local circle = marker:FindFirstChild("Circle") :: BasePart?
		if circle then
			circle.Size = Vector3.new(RADIUS * 2, circle.Size.Y, RADIUS * 2)
			local gui = circle:FindFirstChildWhichIsA("SurfaceGui")
			if gui then
				gui.Enabled = true
				for _, img in gui:GetChildren() do
					if img:IsA("ImageLabel") then
						table.insert(rings, img)
					end
				end
			end
			local beam = circle:FindFirstChild("Column")
			if beam and beam:IsA("Beam") then
				beam.Enabled = true
				column = beam
			end
			local motes = circle:FindFirstChild("Motes")
			if motes and motes:IsA("ParticleEmitter") then
				motes.Enabled = true
			end
		end
		marker:SetAttribute("Radius", RADIUS)
		marker:PivotTo(CFrame.new(foot) * proto:GetPivot().Rotation)
		tint(marker)
		marker.Parent = Workspace.CurrentCamera
		current = marker
	else
		local orb = fallback(foot)
		orb.Parent = Workspace.CurrentCamera
		current = orb
	end
	local columnWidth = column and column.Width0 or 0
	spin = RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		if now >= expiresAt then
			clear()
			return
		end
		local clock = os.clock()
		for _, img in rings do
			local s = img:GetAttribute("Spin")
			img.Rotation = (clock * (if type(s) == "number" then s else 20)) % 360
		end
		-- the light thins as its time runs out
		local left = math.clamp((expiresAt - now) / FADE, 0.25, 1)
		if column then
			column.Width0 = columnWidth * left
			column.Width1 = columnWidth * left
		end
	end)
end

local function gone(reclaimed: boolean)
	local at = spot
	clear()
	spot = nil
	if not (reclaimed and at) then
		return
	end
	local template = guide()
	local proto = template and template:FindFirstChild("Arrive")
	if proto and proto:IsA("Model") then
		local copy = proto:Clone()
		copy:PivotTo(CFrame.new(at) * proto:GetPivot().Rotation)
		tint(copy)
		copy.Parent = Workspace.CurrentCamera
		TechniqueVFX.emit(copy)
		TechniqueVFX.cleanup(copy, 0.5)
	end
	Sfx.play("Pickup", nil, 0.1)
end

function HaulSpill.init()
	(ReplicatedStorage.Remotes.Effect :: RemoteEvent).OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "spill" and typeof(a) == "Vector3" and type(b) == "number" then
			show(a, b)
		elseif kind == "spillGone" then
			gone(a == true)
		end
	end)
end

return HaulSpill
