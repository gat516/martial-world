--!strict
-- Short-lived combat visuals: technique casts, damage numbers, dodge streaks,
-- and hit flashes. Everything here is cosmetic and cleans itself up.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Sfx = require(script.Parent.Sfx)
local TechniqueVFX = require(script.Parent.TechniqueVFX)
local CastFX = require(script.Parent.CastFX)

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

-- Ground height under a point (CastFX skips characters, enemies and effects).
local groundBelow = CastFX.groundBelow

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

local SHAKE_BY_TIER = { 0.14, 0.2, 0.28, 0.38 }

-- Per-technique effect modules (Client.TechniqueFX.<Id>), each returning
-- { cast = function(CombatEffects, def, level, character, origin, dir, chain): boolean }.
-- Keeps every technique's drawing in its own file. Required lazily, once.
local techniqueModules: { [string]: any } = {}
local function techniqueModule(id: string): any?
	if techniqueModules[id] == nil then
		local folder = script.Parent:FindFirstChild("TechniqueFX")
		local m = folder and folder:FindFirstChild(id)
		local ok, mod = false, nil
		if m and m:IsA("ModuleScript") then
			ok, mod = pcall(require, m)
			if not ok then
				warn(`TechniqueFX.{id} failed to load:`, mod)
			end
		end
		techniqueModules[id] = if ok and type(mod) == "table" and type(mod.cast) == "function" then mod else false
	end
	return techniqueModules[id] or nil
end
CombatEffects.SHAKE_BY_TIER = SHAKE_BY_TIER

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
	local timeline = CastFX.phases(def)
	TechniqueVFX.fit(copy, "active", copy:GetAttribute("AuthoredActive"), timeline.active)
	local impact = TechniqueVFX.take(copy, "Impact")
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	-- the release comes from the striking hand (live, so observers see it on the
	-- caster's replicated pose too); the ring stays centred on the feet, where
	-- the gameplay circle is
	local palmAt = CastFX.handPosition(character, def.hand) or origin + dir * 1.6
	local palm = copy:FindFirstChild("Palm") :: BasePart?
	if palm then
		palm.CFrame = CFrame.lookAt(palmAt, palmAt + dir)
	end
	-- where the palm's burst drops to the ground and opens into the ring
	local strike = copy:FindFirstChild("Strike") :: BasePart?
	if strike then
		local below = Vector3.new(palmAt.X, groundBelow(palmAt) + 0.1, palmAt.Z)
		strike.CFrame = CFrame.lookAt(below, below + dir)
	end
	local halo = copy:FindFirstChild("Halo") :: BasePart?
	if halo then
		local at = origin - dir * 0.8 + Vector3.new(0, 1.6, 0) -- a nimbus behind the head, not across the body
		halo.CFrame = CFrame.lookAt(at, at + dir)
	end
	-- add-on parts follow the gameplay shape and the active window: the mesh
	-- shells (SimpleMeshVFX) sweep out by Hit Stop, and the rock ring (Craters)
	-- erupts outward over the same window at the def's radius
	for _, name in { "Shell", "Dome" } do
		local shell = copy:FindFirstChild(name)
		if shell then
			shell:SetAttribute("Duration", timeline.active + 0.05)
		end
	end
	-- the 3D ground torus rolls out to the def's radius (fit() times it to the
	-- active window with the other Phase="active" parts)
	local groundWave = copy:FindFirstChild("GroundWave", true)
	if groundWave then
		local size = groundWave:GetAttribute("ToSize")
		if typeof(size) == "Vector3" then
			groundWave:SetAttribute("ToSize", Vector3.new(radius * 2, size.Y, radius * 2))
		end
	end
	local rocks = copy:FindFirstChild("RockRing", true)
	if rocks then
		rocks:SetAttribute("Radius", radius)
		rocks:SetAttribute("Duration", timeline.active)
	end
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.emit(copy)

	local light = palm and palm:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 3
		TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	end
	-- the template's ScreenEffects CameraShake (with its own distance falloff)
	-- shakes through the Game Module; the plain fallback shakes here instead
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake(SHAKE_BY_TIER[tier] or 0.2)
	end
	TechniqueVFX.cleanup(copy, 0.2)

	-- impacts: every enemy inside the radius, hit as the wave front reaches it
	local ring = copy:FindFirstChild("WaveFront", true)
	if not (impact and ring and ring:IsA("ParticleEmitter")) then
		return true
	end
	-- rock kicks (Craters) on the first three targets, the mastery quake
	-- (ScreenEffects) on the first only
	local targets = CastFX.targets({ kind = "circle", origin = origin, dir = dir, radius = radius, character = character })
	for _, target in targets do
		task.delay(CastFX.frontTime(ring, target.progress), function()
			CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
			if target.index == 1 and tier >= 4 and not TechniqueVFX.full and CastFX.nearCamera(target.point, 45) then
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
	local def = Techniques.Defs[id]
	-- a technique that draws its own anticipation (a twirl, a charge that is
	-- not a hand gather) takes over from here
	local own = techniqueModule(id)
	if own and type(own.windup) == "function" then
		local ok, handled = pcall(own.windup, CombatEffects, def, level, character, CastFX.phases(def).windup)
		if not ok then
			warn(`TechniqueFX.{id}.windup:`, handled)
		elseif handled then
			return
		end
	end
	-- weapon skills charge along the real blade (its `Charge` part), not in
	-- the hand: the weapon model's Base/Tip attachments say where it is
	local template = TechniqueVFX.template(id, level)
	local charge = template and template:FindFirstChild("Charge")
	if charge and def.weapon ~= "Any" and def.weapon ~= "Fist" then
		local WeaponFX = require(script.Parent.TechniqueFX.WeaponFX)
		if WeaponFX.charge(character, charge, CastFX.phases(def).windup, def.weapon == "Staff" or def.weapon == "Spear") then
			return
		end
	end
	local function at(): CFrame
		local hand = CastFX.handPosition(character, def.hand)
		return if hand then CFrame.lookAt(hand, hand + root.CFrame.LookVector) else root.CFrame * CFrame.new(0, 0, -1.2)
	end
	local p = TechniqueVFX.part(id, level, "Windup", at())
	if not p then
		return
	end
	-- the charge fills the windup exactly, peaking at Hit when cast() takes over
	local seconds = CastFX.phases(def).windup
	TechniqueVFX.fit(p, nil, p:GetAttribute("AuthoredWindup"), seconds)
	-- qi wisps (Splines) curve in from around the body and reach the hand by Hit
	local wisps = p:FindFirstChild("Wisps") :: BasePart?
	if wisps then
		wisps:SetAttribute("Duration", NumberRange.new(seconds * 0.9))
		wisps.CFrame = p.CFrame
	end
	TechniqueVFX.emit(p)
	if wisps then
		TechniqueVFX.emit(wisps) -- emitting a part doesn't reach parts nested in it
	end
	TechniqueVFX.cleanup(p)
	-- qi gathers into the hand as it swings (the template's emitters are
	-- LockedToPart; the spline paths follow the Wisps part via SyncPosition)
	local started = os.clock()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or not p.Parent or not root.Parent then
			follow:Disconnect()
			return
		end
		local cf = at()
		p.CFrame = cf
		if wisps then
			wisps.CFrame = cf
		end
	end)
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
	-- a technique with its own effect module (TechniqueFX/<Id>) draws itself;
	-- it returns false (e.g. its templates are missing) to fall back to the
	-- old drawing below
	local own = techniqueModule(def.id)
	if own then
		local ok, handled = pcall(own.cast, CombatEffects, def, level :: number, character, origin, dir, chain)
		if not ok then
			warn(`TechniqueFX.{def.id}:`, handled)
		elseif handled then
			return
		end
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

-- Dodge effects (ReplicatedStorage.Effects.Dodge, built by
-- tools/vfx_specs/Dodge.luau). Only the dodging player sees them.
local function dodgeTemplate(name: string): Instance?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local group = effects and effects:FindFirstChild("Dodge")
	return group and group:FindFirstChild(name)
end

-- The latest dash, so a perfect dodge can leave its ghost where the dash began
-- and turn the rest of the streak gold.
local lastDash: { character: Model, origin: CFrame, at: number, trails: { Trail } }? = nil

-- The dash: one light qi streak along the path (two camera-facing Trails on
-- the root) that dies ~0.2 s after the dash ends. Nothing is left behind, so
-- the perfect dodge's ghost and flash stay the only lingering dodge visual.
function CombatEffects.dashTrail(character: Model, root: BasePart, seconds: number)
	local dash = { character = character, origin = root.CFrame, at = os.clock(), trails = {} :: { Trail } }
	lastDash = dash
	local template = dodgeTemplate("Streak")
	if not template then
		return
	end
	-- attachments and trails are cloned together, so the trails keep pointing
	-- at the moved attachments
	local copy = template:Clone()
	local moved = copy:GetChildren()
	local longest = 0
	for _, child in moved do
		child.Parent = root
		if child:IsA("Trail") then
			child.Enabled = true
			longest = math.max(longest, child.Lifetime)
			table.insert(dash.trails, child)
		end
	end
	copy:Destroy()
	task.delay(seconds, function()
		for _, t in dash.trails do
			t.Enabled = false
		end
		task.delay(longest + 0.05, function()
			for _, child in moved do
				child:Destroy()
			end
		end)
	end)
end

-- A beam pair from `a` to `b` that holds `hold` seconds, then thins and fades
-- out over `seconds`.
local function fadeBeams(part: BasePart, a: Vector3, b: Vector3, hold: number, seconds: number)
	local from = part:FindFirstChild("From") :: Attachment?
	local to = part:FindFirstChild("To") :: Attachment?
	if not (from and to) then
		part:Destroy()
		return
	end
	part.CFrame = CFrame.new(a)
	part.Parent = folder
	from.WorldPosition, to.WorldPosition = a, b
	local beams = {}
	for _, d in part:GetChildren() do
		if d:IsA("Beam") then
			table.insert(beams, { beam = d, w0 = d.Width0, w1 = d.Width1, t = d.Transparency })
		end
	end
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started - hold) / seconds, 0, 1)
		if k >= 1 or not part.Parent then
			connection:Disconnect()
			part:Destroy()
			return
		end
		if k <= 0 then
			return
		end
		local keep = 1 - k * k
		for _, b in beams do
			b.beam.Width0, b.beam.Width1 = b.w0 * keep, b.w1 * keep
			local points = {}
			for _, p in b.t.Keypoints do
				table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value + (1 - p.Value) * k))
			end
			b.beam.Transparency = NumberSequence.new(points)
		end
	end)
end

-- A perfect dodge, "the blow cut only a shadow": a gold-white ghost of the
-- body left where the dash began (where the blow lands) that holds, then
-- dissolves into rising qi motes; a gold streak from the ghost to the player
-- along the path taken; a sharp glint, flare and sparks on the player with a
-- gold rim; and a brief desaturated time-slow grade. No ground ring and no
-- shake: nothing was hit.
local PERFECT_GOLD = Color3.fromRGB(255, 212, 120)
local PERFECT_GHOST = Color3.fromRGB(255, 112, 32) -- Neon boosts it to gold (lighter colours clip to lemon)
function CombatEffects.perfectDodge(character: Model, root: BasePart)
	local here = root.CFrame
	local dash = lastDash
	local recent = dash and dash.character == character and os.clock() - dash.at < 1
	local origin = if dash and recent then dash.origin else here
	if dash and recent then
		-- what's left of the dash streak flares gold
		for _, t in dash.trails do
			if t.Parent then
				t.Color = ColorSequence.new(PERFECT_GOLD)
			end
		end
	end

	-- the ghost: this pose, moved back to the dash origin
	local shift = origin * here:Inverse()
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
		ghost.Color = PERFECT_GHOST
		ghost.Transparency = 0.12
		ghost.CFrame = shift * source.CFrame
		ghost.Parent = folder
		task.delay(0.12, function()
			if ghost.Parent then
				TweenService:Create(ghost, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
					Size = ghost.Size * 1.08,
				}):Play()
			end
		end)
		Debris:AddItem(ghost, 0.65)
	end

	local template = dodgeTemplate("Perfect")
	if template then
		local copy = template:Clone()
		local ghostPart = copy:FindFirstChild("Ghost") :: BasePart?
		local playerPart = copy:FindFirstChild("Player") :: BasePart?
		if ghostPart then
			ghostPart.CFrame = origin * CFrame.new(0, -0.2, 0)
		end
		if playerPart then
			playerPart.CFrame = here * CFrame.new(0, 0.8, 0)
		end
		local streak = TechniqueVFX.take(copy, "Streak")
		local chest = Vector3.new(0, 0.3, 0)
		if streak and (here.Position - origin.Position).Magnitude > 1.5 then
			fadeBeams(streak, origin.Position + chest, here.Position + chest, 0.1, 0.3)
		elseif streak then
			streak:Destroy()
		end
		copy.Parent = folder
		TechniqueVFX.emit(copy)
		TechniqueVFX.cleanup(copy)
	else
		burst(here.Position, {
			Texture = SPARKLE,
			Color = ColorSequence.new(PERFECT_GOLD),
			LightEmission = 1,
			Size = NumberSequence.new(0.9, 0),
			Lifetime = NumberRange.new(0.3, 0.55),
			Speed = NumberRange.new(14, 24),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 5,
		}, 16, 1.2)
	end

	-- a gold rim on the player
	local rim = Instance.new("Highlight")
	rim.FillColor = PERFECT_GOLD
	rim.FillTransparency = 0.55
	rim.OutlineColor = Color3.fromRGB(255, 244, 214)
	rim.OutlineTransparency = 0
	rim.DepthMode = Enum.HighlightDepthMode.Occluded
	rim.Parent = character
	TweenService:Create(rim, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	Debris:AddItem(rim, 0.4)

	-- time-slow accent: the world drains of colour for a beat, then returns
	local grade = Instance.new("ColorCorrectionEffect")
	grade.TintColor = Color3.fromRGB(255, 240, 210)
	grade.Brightness = 0.05
	grade.Saturation = -0.55
	grade.Contrast = 0.08
	grade.Parent = folder
	task.delay(0.08, function()
		TweenService:Create(grade, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TintColor = Color3.new(1, 1, 1),
			Brightness = 0,
			Saturation = 0,
			Contrast = 0,
		}):Play()
	end)
	Debris:AddItem(grade, 0.55)
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
