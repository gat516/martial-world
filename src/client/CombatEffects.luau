--!strict
-- Short-lived combat visuals: technique casts, damage numbers, dash afterimages,
-- and hit flashes. Everything here is cosmetic and cleans itself up.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Rules = require(ReplicatedStorage.Shared.ActionRules)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Sfx = require(script.Parent.Sfx)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

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

-- Ground rays skip effects, every player character and every enemy: callers
-- pass root or body positions, and a ray from there would otherwise land on
-- the caster's (or target's) own body and put the effect at torso height.
-- The filter is rebuilt at most twice a second (markTarget calls this per frame).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local groundFilterAt = -math.huge
local function groundFilter(): RaycastParams
	local now = os.clock()
	if now - groundFilterAt > 0.5 then
		groundFilterAt = now
		local list: { Instance } = { folder }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		for _, enemy in CollectionService:GetTagged("Enemy") do
			table.insert(list, enemy)
		end
		groundParams.FilterDescendantsInstances = list
	end
	return groundParams
end

-- Ground height under a point (falls back to 3 studs below it).
local function groundBelow(position: Vector3): number
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -24, 0), groundFilter())
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

-- Seconds after emit until a flat ring emitter's front reaches `frac` of its
-- final radius (its Size curve is the ring radius over its lifetime).
local function frontTime(ring: ParticleEmitter, frac: number): number
	local kps = ring.Size.Keypoints
	local final = kps[#kps].Value
	local want = frac * final
	for i = 2, #kps do
		local a, b = kps[i - 1], kps[i]
		if want <= b.Value then
			local t = (want - a.Value) / math.max(b.Value - a.Value, 1e-3)
			return (a.Time + (b.Time - a.Time) * math.clamp(t, 0, 1)) * ring.Lifetime.Max
		end
	end
	return ring.Lifetime.Max
end

local function nearCamera(position: Vector3, studs: number): boolean
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude <= studs
end

local SHAKE_BY_TIER = { 0.14, 0.2, 0.28, 0.38 }

-- Palm Strike from its tier template (ReplicatedStorage.Effects.PalmStrike):
-- a ground wave from the caster's feet out to the gameplay radius, and an
-- impact on every enemy the front reaches, timed to when it gets there.
-- Returns false when the template is missing so the old drawing still plays.
local function palmStrike(def: Techniques.Def, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	local radius = def.radius :: number
	local ground = Vector3.new(origin.X, groundBelow(origin), origin.Z)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local authored = copy:GetAttribute("AuthoredRadius")
	local scale = if type(authored) == "number" and authored > 0 then radius / authored else 1
	TechniqueVFX.rescale(copy, scale)
	-- cast() runs at Hit: the wave reaches the radius by Hit Stop, so every
	-- impact lands inside the active window; aftermath keeps its authored fade
	local timeline = Rules.castProfile(def)
	TechniqueVFX.fit(copy, "active", copy:GetAttribute("AuthoredActive"), timeline.active)
	local impact = TechniqueVFX.take(copy, "Impact")
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	-- hand-height parts follow the caster's root, not the template's guess
	local palm = copy:FindFirstChild("Palm") :: BasePart?
	if palm then
		palm.CFrame = CFrame.lookAt(origin + dir * 1.6, origin + dir * 2.6)
	end
	local halo = copy:FindFirstChild("Halo") :: BasePart?
	if halo then
		local at = origin - dir * 1.2 + Vector3.new(0, 0.6, 0)
		halo.CFrame = CFrame.lookAt(at, at + dir)
	end
	TechniqueVFX.emit(copy)

	local swirl = copy:FindFirstChild("Swirl") :: BasePart?
	if swirl then
		local reach = radius * 2 * 1.05
		swirl.Transparency = 0.3
		TweenService:Create(swirl, TweenInfo.new(timeline.active + 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(reach, swirl.Size.Y * 2, reach),
			Transparency = 1,
			CFrame = swirl.CFrame * CFrame.Angles(0, math.rad(140), 0),
		}):Play()
	end
	local light = palm and palm:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 3
		TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	end
	if nearCamera(origin, 45) then
		CombatEffects.shake(SHAKE_BY_TIER[tier] or 0.2)
	end
	TechniqueVFX.cleanup(copy, 0.2)

	-- impacts: every enemy inside the radius, hit as the wave front reaches it
	local ring = copy:FindFirstChild("WaveFront", true)
	if not (impact and ring and ring:IsA("ParticleEmitter")) then
		return true
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, character :: Instance? }
	local box = Vector3.new(radius * 2 + 2, 16, radius * 2 + 2)
	local hits = 0
	for _, model in Hitbox.enemiesIn(CFrame.new(origin), box, params, origin) do
		if hits >= 6 then
			break
		end
		local cf, size = model:GetBoundingBox()
		local p = cf.Position
		local flat = Vector3.new(p.X - ground.X, 0, p.Z - ground.Z)
		local distance = flat.Magnitude
		if distance > radius + 1.5 then
			continue
		end
		hits += 1
		local index = hits
		local toward = if distance > 0.01 then flat.Unit else dir
		-- the near side of the target, where the front meets it
		local near = math.max(distance - math.min(size.X, size.Z) * 0.4, 1)
		local at = Vector3.new(ground.X, 0, ground.Z) + toward * near
		local feet = Vector3.new(at.X, groundBelow(Vector3.new(at.X, p.Y, at.Z)) + 0.15, at.Z)
		task.delay(frontTime(ring, math.clamp(near / radius, 0, 1)), function()
			local burst = TechniqueVFX.burstAt(impact, CFrame.lookAt(feet, feet + toward))
			local body = burst:FindFirstChild("Body")
			if body and body:IsA("Attachment") then
				body.Position = Vector3.new(0, math.max(p.Y - feet.Y, 1), 0)
			end
			if model.Parent then
				CombatEffects.flash(model)
			end
			if index == 1 and tier >= 4 and nearCamera(feet, 45) then
				CombatEffects.shake(0.25) -- the mastery strike lands twice: release, then the first impact
			end
		end)
	end
	return true
end

-- Anticipation while a cast winds up (the caster's own client only, from
-- cast start to Hit): plays the tier template's Windup part in front of the
-- caster, if it has one. Observers only receive the cast at release.
function CombatEffects.windup(character: Model, id: string, level: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not Techniques.Defs[id] then
		return
	end
	local p = TechniqueVFX.part(id, level, "Windup", root.CFrame * CFrame.new(0, 0, -1.2))
	if p then
		-- the charge fills the windup exactly, peaking at Hit when cast() takes over
		TechniqueVFX.fit(p, nil, p:GetAttribute("AuthoredWindup"), Rules.castProfile(Techniques.Defs[id]).windup)
		TechniqueVFX.emit(p)
		TechniqueVFX.cleanup(p)
	end
end

-- `chain` lists the chain technique's targets, in order (nil for other kinds).
-- `level` is the caster's technique level at cast time; it picks the visual tier
-- (Techniques.visualTier) once a technique's templates exist in Effects.
function CombatEffects.cast(character: Model?, id: string, origin: Vector3, dir: Vector3, chain: { Model }?, level: number?)
	local def = Techniques.Defs[id]
	if not def then
		return
	end
	level = math.clamp(if type(level) == "number" then level else 1, 1, Techniques.MAX_LEVEL)
	Sfx.play(def.id, origin) -- each technique's sound is named after its id
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
	elseif def.kind == "circle" and palmStrike(def, level :: number, character, origin, dir) then
		return
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
-- after LockOn writes the camera (Camera + 1)
RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
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

-- One afterimage: a frozen, glowing copy of the character's current pose. Body
-- parts are cloned bare (meshes kept, joints/decals/clothing dropped) so the copy
-- can't weld itself to the live rig.
local function afterimage(character: Model, color: Color3, transparency: number, seconds: number, grow: number?)
	for _, source in character:GetDescendants() do
		if not source:IsA("BasePart") or source.Name == "HumanoidRootPart" or source.Transparency >= 1 then
			continue
		end
		local ghost = source:Clone()
		if not ghost then
			continue
		end
		for _, child in ghost:GetChildren() do
			if not child:IsA("DataModelMesh") then
				child:Destroy()
			end
		end
		if ghost:IsA("MeshPart") then
			ghost.TextureID = ""
		end
		ghost.Anchored, ghost.CanCollide, ghost.CanQuery, ghost.CanTouch, ghost.CastShadow = true, false, false, false, false
		ghost.Massless = true
		ghost.Material = Enum.Material.Neon
		ghost.Color = color
		ghost.Transparency = transparency
		ghost.Parent = folder
		fade(ghost, seconds, if grow then { Size = ghost.Size * grow } else nil)
	end
end

-- The dash: a trail of pale afterimages dropped along the path, plus a gust at
-- the feet where it started.
function CombatEffects.dashTrail(character: Model, root: BasePart, seconds: number)
	local color = Color3.fromRGB(150, 210, 255)
	burst(Vector3.new(root.Position.X, groundBelow(root.Position), root.Position.Z), {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(220, 235, 245)),
		Transparency = NumberSequence.new(0.5, 1),
		Size = NumberSequence.new(1.2, 3),
		Lifetime = NumberRange.new(0.3, 0.45),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(180, 10),
		Drag = 5,
	}, 8, 1)
	local started = os.clock()
	local nextGhost = 0
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > seconds or not root.Parent then
			connection:Disconnect()
			return
		end
		if t >= nextGhost then
			nextGhost += 0.04
			-- earlier ghosts start fainter, so the trail thickens toward the player
			afterimage(character, color, 0.45 + 0.3 * (1 - t / seconds), 0.28)
		end
	end)
end

-- A perfect dodge: a golden afterimage left where the blow would have landed,
-- a shockwave ring, sparks, and a brief warm flash of the whole screen.
function CombatEffects.perfectDodge(character: Model, root: BasePart)
	local gold = Color3.fromRGB(255, 214, 120)
	afterimage(character, gold, 0.15, 0.6, 1.15)
	local ground = groundBelow(root.Position)
	local ring = disc(gold, Vector3.new(root.Position.X, ground + 0.05, root.Position.Z), 1.5, 0.15)
	ring.Transparency = 0.1
	fade(ring, 0.45, { Size = Vector3.new(0.15, 22, 22) })
	burst(root.Position, {
		Texture = SPARKLE,
		Color = ColorSequence.new(gold),
		LightEmission = 1,
		Size = NumberSequence.new(0.9, 0),
		Lifetime = NumberRange.new(0.3, 0.55),
		Speed = NumberRange.new(14, 24),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
	}, 24, 1.2)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.TintColor = Color3.fromRGB(255, 236, 190)
	grade.Brightness = 0.12
	grade.Saturation = -0.35
	grade.Parent = folder
	TweenService:Create(grade, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = Color3.new(1, 1, 1),
		Brightness = 0,
		Saturation = 0,
	}):Play()
	Debris:AddItem(grade, 0.5)
	CombatEffects.shake(0.2)
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
	Sfx.play("Thunder", ground)
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
