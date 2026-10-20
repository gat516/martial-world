--!strict
-- Short-lived combat visuals: technique casts, damage numbers, the dodge's flying
-- sword, and hit flashes. Everything here is cosmetic and cleans itself up.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Techniques = require(ReplicatedStorage.Shared.Techniques)

local CombatEffects = {}

-- Effects live under the camera, so they're local to this client.
local folder = workspace.CurrentCamera

local function part(color: Color3, size: Vector3, cframe: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function fade(p: BasePart, seconds: number, goal: { [string]: any }?)
	local props: { [string]: any } = goal or {}
	props.Transparency = 1
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	Debris:AddItem(p, seconds + 0.1)
end

-- A flat disc (cylinder lying on the ground) of the given radius.
local function disc(color: Color3, center: Vector3, radius: number, thickness: number?): Part
	local t = thickness or 0.3
	return part(color, Vector3.new(t, radius * 2, radius * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
end

local function beam(color: Color3, a: Vector3, b: Vector3, width: number): Part
	local length = (b - a).Magnitude
	return part(color, Vector3.new(width, width, math.max(length, 0.1)), CFrame.lookAt((a + b) / 2, b), nil)
end

-- Ground height under a point (falls back to 3 studs below it).
local function groundBelow(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), params)
	return if hit then hit.Position.Y + 0.1 else position.Y - 3
end

-- `chain` lists the chain technique's targets, in order (nil for other kinds).
function CombatEffects.cast(character: Model?, id: string, origin: Vector3, dir: Vector3, chain: { Model }?)
	local def = Techniques.Defs[id]
	if not def then
		return
	end
	local color = def.color
	if def.kind == "line" then
		local length = def.length :: number
		local blade = part(color, Vector3.new(def.width :: number, 0.5, 2.5), CFrame.lookAt(origin, origin + dir))
		blade.Transparency = 0.15
		local goal = CFrame.lookAt(origin + dir * length, origin + dir * (length + 1))
		TweenService:Create(blade, TweenInfo.new(0.3, Enum.EasingStyle.Linear), { CFrame = goal }):Play()
		task.delay(0.2, fade, blade, 0.15)
	elseif def.kind == "circle" then
		local ground = Vector3.new(origin.X, groundBelow(origin), origin.Z)
		local ring = disc(color, ground, 1, 0.4)
		ring.Transparency = 0.2
		local r = def.radius :: number
		fade(ring, 0.3, { Size = Vector3.new(0.4, r * 2, r * 2) })
	elseif def.kind == "chain" then
		local from = origin + Vector3.new(0, 1.5, 0)
		local targets: { Model } = chain or {}
		for _, model in targets do
			local to = model:GetPivot().Position
			local bolt = beam(color, from, to, 0.35)
			bolt.Transparency = 0.1
			fade(bolt, 0.3)
			from = to
		end
	elseif def.kind == "zone" then
		local center = origin + dir * (def.offset :: number)
		local ground = Vector3.new(center.X, groundBelow(center), center.Z)
		local zone = disc(color, ground, def.radius :: number, 0.25)
		zone.Transparency = 0.45
		local seconds = def.seconds :: number
		TweenService:Create(zone, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
		task.delay(seconds, fade, zone, 0.3)
	elseif def.kind == "buff" and character then
		local glow = Instance.new("Highlight")
		glow.FillColor = color
		glow.OutlineColor = color
		glow.FillTransparency = 0.6
		glow.Parent = character
		Debris:AddItem(glow, def.seconds :: number)
	end
end

-- A number that floats up from a world position.
function CombatEffects.number(position: Vector3, text: string, color: Color3, size: number?)
	local anchor = part(color, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(math.random() - 0.5, 2, math.random() - 0.5)))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.TextSize = size or 22
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.Parent = gui
	gui.Parent = anchor
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.9)
end

-- Brief white flash on something that was hit.
function CombatEffects.flash(model: Instance, color: Color3?)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color or Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, 0.12)
end

-- The dodge's flying sword: a blade under the feet for the length of the dash.
function CombatEffects.flyingSword(root: BasePart, seconds: number)
	local blade = part(Color3.fromRGB(170, 225, 255), Vector3.new(0.5, 0.2, 5), root.CFrame * CFrame.new(0, -3, 0))
	blade.Transparency = 0.2
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or not root.Parent then
			connection:Disconnect()
			fade(blade, 0.15)
			return
		end
		local flat = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local facing = if flat.Magnitude > 1 then CFrame.lookAt(root.Position, root.Position + flat) else root.CFrame
		blade.CFrame = facing * CFrame.new(0, -3, 0)
	end)
end

return CombatEffects
