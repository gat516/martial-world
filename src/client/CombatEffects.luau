--!strict
-- Short-lived combat visuals: technique casts, damage numbers, the dodge's flying
-- sword, and hit flashes. Everything here is cosmetic and cleans itself up.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Techniques = require(ReplicatedStorage.Shared.Techniques)

local CombatEffects = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

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

-- A one-shot particle burst at a point (an invisible anchor that cleans itself up).
local function burst(position: Vector3, props: { [string]: any }, count: number, life: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	for k, v in props do
		(emitter :: any)[k] = v
	end
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, life or 2)
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
		-- a glowing trail behind the crescent
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = Vector3.new(-(def.width :: number) / 2, 0, 0)
		a1.Position = Vector3.new((def.width :: number) / 2, 0, 0)
		a0.Parent, a1.Parent = blade, blade
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = 1
		trail.Lifetime = 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = blade
		TweenService:Create(blade, TweenInfo.new(0.3, Enum.EasingStyle.Linear), { CFrame = goal }):Play()
		task.delay(0.2, fade, blade, 0.15)
	elseif def.kind == "circle" then
		local ground = Vector3.new(origin.X, groundBelow(origin), origin.Z)
		local ring = disc(color, ground, 1, 0.4)
		ring.Transparency = 0.2
		local r = def.radius :: number
		fade(ring, 0.3, { Size = Vector3.new(0.4, r * 2, r * 2) })
		-- a dust burst kicked out along the ground
		burst(ground + Vector3.new(0, 0.5, 0), {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(230, 215, 190)),
			Size = NumberSequence.new(1.5, 4),
			Transparency = NumberSequence.new(0.5, 1),
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(r * 2, r * 3),
			SpreadAngle = Vector2.new(180, 5),
			Drag = 4,
		}, 24)
		CombatEffects.shake(0.2)
	elseif def.kind == "chain" then
		local from = origin + Vector3.new(0, 1.5, 0)
		local targets: { Model } = chain or {}
		for _, model in targets do
			local to = model:GetPivot().Position
			-- a jagged bolt: two kinked segments that flicker out
			local mid = (from + to) / 2 + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
			for _, seg in { beam(color, from, mid, 0.35), beam(color, mid, to, 0.35) } do
				seg.Transparency = 0.05
				fade(seg, 0.3)
			end
			burst(to, {
				Texture = SPARKLE,
				Color = ColorSequence.new(color),
				LightEmission = 1,
				Size = NumberSequence.new(0.8, 0),
				Lifetime = NumberRange.new(0.2, 0.4),
				Speed = NumberRange.new(8, 16),
				SpreadAngle = Vector2.new(180, 180),
			}, 14)
			from = to
		end
	elseif def.kind == "zone" then
		local center = origin + dir * (def.offset :: number)
		local ground = Vector3.new(center.X, groundBelow(center), center.Z)
		local zone = disc(color, ground, def.radius :: number, 0.25)
		zone.Transparency = 0.45
		local seconds = def.seconds :: number
		local flames = Instance.new("ParticleEmitter")
		flames.Texture = FIRE
		flames.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 70, 40))
		flames.LightEmission = 1
		flames.Size = NumberSequence.new(1.6, 0.2)
		flames.Transparency = NumberSequence.new(0.2, 1)
		flames.Lifetime = NumberRange.new(0.5, 0.9)
		flames.Speed = NumberRange.new(3, 6)
		flames.EmissionDirection = Enum.NormalId.Right -- the disc's local X is world up
		flames.Rate = 40
		flames.Shape = Enum.ParticleEmitterShape.Cylinder
		flames.Parent = zone
		task.delay(seconds, function()
			flames.Enabled = false
		end)
		TweenService:Create(zone, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
		task.delay(seconds, fade, zone, 0.3)
	elseif def.kind == "buff" and character then
		local glow = Instance.new("Highlight")
		glow.FillColor = color
		glow.OutlineColor = color
		glow.FillTransparency = 0.6
		glow.Parent = character
		Debris:AddItem(glow, def.seconds :: number)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			burst(root.Position, {
				Texture = SPARKLE,
				Color = ColorSequence.new(color),
				LightEmission = 1,
				Size = NumberSequence.new(0.6, 0),
				Lifetime = NumberRange.new(0.6, 1),
				Speed = NumberRange.new(4, 7),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 3,
			}, 30)
		end
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

-- Sparks where a hit landed.
function CombatEffects.sparks(position: Vector3)
	burst(position + Vector3.new(0, 1, 0), {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)),
		LightEmission = 1,
		Size = NumberSequence.new(0.7, 0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 6,
	}, 10, 1)
end

-- A short camera shake (strength in studs of jitter, decaying over ~0.2s).
local shakeLeft = 0
local shakeStrength = 0
function CombatEffects.shake(strength: number)
	shakeStrength = math.max(shakeStrength * (shakeLeft / 0.2), strength)
	shakeLeft = 0.2
end
RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if shakeLeft <= 0 then
		return
	end
	shakeLeft -= dt
	local s = shakeStrength * math.max(0, shakeLeft / 0.2)
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
end)

-- A soft ring under whatever the basic attack and techniques will aim at.
local targetRing: Part? = nil
function CombatEffects.markTarget(model: Model?)
	if not model then
		if targetRing then
			targetRing.Transparency = 1
		end
		return
	end
	local ring = targetRing
	if not ring then
		-- gold, never red: red on the ground always means an incoming attack
		local made = disc(Color3.fromRGB(255, 225, 140), Vector3.zero, 1, 0.12)
		made.Transparency = 1
		targetRing = made
		ring = made
	end
	local r = ring :: Part
	local _, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2 + 0.8
	local pivot = model:GetPivot().Position
	local ground = groundBelow(pivot - Vector3.new(0, size.Y / 2 - 1, 0))
	local pulse = 0.08 * math.sin(os.clock() * 6)
	r.Size = Vector3.new(0.12, radius * 2 * (1 + pulse), radius * 2 * (1 + pulse))
	r.CFrame = CFrame.new(pivot.X, ground + 0.05, pivot.Z) * CFrame.Angles(0, 0, math.rad(90))
	r.Transparency = 0.72
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

-- A jagged lightning bolt from high in the sky down to `ground`, with a flash.
-- Drawn tall and bright so it reads from every peak.
function CombatEffects.bolt(ground: Vector3)
	local color = Color3.fromRGB(205, 215, 255)
	local top = ground + Vector3.new(math.random(-12, 12), 260, math.random(-12, 12))
	local points = { top }
	local segments = 9
	for i = 1, segments - 1 do
		local t = i / segments
		local p = top:Lerp(ground, t)
		local jitter = 10 * (1 - t) + 2
		table.insert(points, p + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * jitter)
	end
	table.insert(points, ground)
	for i = 1, #points - 1 do
		local seg = beam(color, points[i], points[i + 1], if i > segments - 3 then 0.9 else 1.6)
		seg.Transparency = 0
		fade(seg, 0.35)
	end
	local flash = part(color, Vector3.new(1, 1, 1), CFrame.new(ground + Vector3.new(0, 2, 0)))
	flash.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 8
	light.Range = 40
	light.Parent = flash
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.5)
	local scorch = disc(Color3.fromRGB(150, 170, 255), ground + Vector3.new(0, 0.12, 0), 4, 0.2)
	scorch.Transparency = 0.2
	fade(scorch, 0.6, { Size = Vector3.new(0.2, 12, 12) })
end

-- Storm clouds over the tribulation platform while it lasts.
local storms: { [Player]: { Part } } = {}
function CombatEffects.storm(who: Player, center: Vector3?)
	local old = storms[who]
	if old then
		for _, p in old do
			fade(p, 1.5)
		end
	end
	storms[who] = nil
	if not center then
		return
	end
	local parts = {}
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local r = 30 + math.random() * 30
		local size = 30 + math.random() * 25
		local cloud = part(Color3.fromRGB(38, 36, 52), Vector3.new(size, size * 0.5, size), CFrame.new(center + Vector3.new(math.cos(a) * r, 120 + math.random() * 20, math.sin(a) * r)), Enum.PartType.Ball)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Transparency = 1
		TweenService:Create(cloud, TweenInfo.new(2), { Transparency = 0.15 }):Play()
		table.insert(parts, cloud)
	end
	storms[who] = parts
end

return CombatEffects
