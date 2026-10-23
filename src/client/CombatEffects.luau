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

local SHAKE_BY_TIER = { 0.12, 0.2, 0.32, 0.46 } -- tier I stays clean, IV hits hard

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
		if WeaponFX.charge(character, charge, CastFX.phases(def).windup, def.weapon == "Staff" or def.weapon == "Spear" or def.weapon == "Guandao") then
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
	local follow: RBXScriptConnection
	local unregister: () -> () = function() end
	follow = RunService.RenderStepped:Connect(function()
		if os.clock() - started > seconds or not p.Parent or not root.Parent then
			follow:Disconnect()
			unregister()
			return
		end
		local cf = at()
		p.CFrame = cf
		if wisps then
			wisps.CFrame = cf
		end
	end)
	-- a cast cut short before Hit drops its gather at once
	unregister = require(script.Parent.TechniqueFX.WeaponFX).onCancel(character, function()
		follow:Disconnect()
		p:Destroy()
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

-- The hit-pause feel of a big blow, for the Hit -> Hit Stop window: the
-- camera punches in toward what it looks at and eases back, and the world
-- grades hard for a beat (contrast and saturation up, a flash of the
-- element's tint). `strength` 0..1 (tier IV slam ~1); only near the camera.
local punchLeft, punchTotal, punchDepth = 0, 0.2, 0
function CombatEffects.punch(at: Vector3, strength: number, tint: Color3?, seconds: number?)
	if (workspace.CurrentCamera.CFrame.Position - at).Magnitude > 60 or strength <= 0 then
		return
	end
	local hold = math.clamp(seconds or 0.1, 0.05, 0.2)
	punchTotal = hold + 0.18
	punchLeft = punchTotal
	punchDepth = math.max(punchDepth * (punchLeft / punchTotal), 0.9 * strength)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.TintColor = Color3.new(1, 1, 1):Lerp(tint or Color3.new(1, 1, 1), 0.35 * strength)
	grade.Brightness = 0.06 * strength
	grade.Contrast = 0.32 * strength
	grade.Saturation = 0.25 * strength
	grade.Parent = folder
	task.delay(hold, function()
		TweenService:Create(grade, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0,
		}):Play()
	end)
	Debris:AddItem(grade, hold + 0.3)
end

-- A cast cut short: stop what its effects left running (TechniqueFX.WeaponFX).
function CombatEffects.cancel(character: Model?)
	local WeaponFX = require(script.Parent.TechniqueFX.WeaponFX)
	WeaponFX.cancel(character)
end

-- after LockOn writes the camera (Camera + 1)
RunService:BindToRenderStep("CombatShake", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
	local camera = workspace.CurrentCamera
	if punchLeft > 0 then
		punchLeft -= dt
		-- in fast, out slow: a push along the view
		local k = math.max(0, punchLeft / punchTotal)
		local d = punchDepth * math.sin(math.pi * (1 - k) ^ 0.35) * k ^ 0.5
		camera.CFrame *= CFrame.new(0, 0, -d)
		if punchLeft <= 0 then
			punchDepth = 0
		end
	end
	if shakeLeft <= 0 then
		return
	end
	shakeLeft -= dt
	local s = shakeStrength * math.max(0, shakeLeft / 0.2)
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

-- A pose of the body during the dash: every visible part's world CFrame.
type Pose = { root: CFrame, parts: { [BasePart]: CFrame } }

-- The latest dash, so a perfect dodge can leave its afterimages along the path
-- and turn the rest of the streak gold. `poses` are sampled every
-- GHOST_SPACING studs while it runs; `onPose` (set by a perfect dodge that
-- lands mid-dash) drops an afterimage at each new one as the player passes.
type Dash = {
	character: Model,
	origin: CFrame,
	at: number,
	trails: { Trail },
	poses: { Pose },
	onPose: ((Pose, number) -> ())?,
}
local lastDash: Dash? = nil

local GHOST_SPACING = 5 -- studs between sampled poses (a dash covers ~24)
local GHOST_MAX = 5 -- afterimages per perfect dodge, the start one included
local GHOST_CLEAR = 4.5 -- no afterimage this close to where the player stands (a body is ~4 wide)
local GHOST_STAGGER = 0.025 -- afterimages appear start first, this far apart

local function snapshot(character: Model, root: BasePart): Pose
	local parts = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Transparency < 1 then
			parts[d] = d.CFrame
		end
	end
	return { root = root.CFrame, parts = parts }
end

-- The dash: one light qi streak along the path (two camera-facing Trails on
-- the root) that dies ~0.2 s after the dash ends, and the pose samples a
-- perfect dodge draws its afterimages from. Nothing is left behind.
function CombatEffects.dashTrail(character: Model, root: BasePart, seconds: number)
	local dash: Dash = {
		character = character, origin = root.CFrame, at = os.clock(), trails = {},
		poses = { snapshot(character, root) },
	}
	lastDash = dash
	local sampler: RBXScriptConnection
	sampler = RunService.Heartbeat:Connect(function()
		if os.clock() - dash.at > seconds + 0.05 or not root.Parent or #dash.poses >= GHOST_MAX then
			sampler:Disconnect()
			dash.onPose = nil
			return
		end
		if (root.Position - dash.poses[#dash.poses].root.Position).Magnitude >= GHOST_SPACING then
			local pose = snapshot(character, root)
			table.insert(dash.poses, pose)
			if dash.onPose then
				dash.onPose(pose, #dash.poses)
			end
		end
	end)
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

-- Afterimages: gold Neon copies of the body's parts, pooled per source part
-- (a perfect dodge can come every second in a fight) and faded by one
-- RenderStepped loop instead of a tween per part.
local PERFECT_GOLD = Color3.fromRGB(255, 212, 120)
local PERFECT_GHOST = Color3.fromRGB(255, 112, 32) -- Neon boosts it to gold (lighter colours clip to lemon)

local ghostPool: { [BasePart]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function takeGhost(source: BasePart): BasePart?
	local free = ghostPool[source]
	local ghost = free and table.remove(free)
	-- a pooled copy destroyed from outside (the camera's children cleared) is locked
	while ghost and not pcall(function()
		(ghost :: BasePart).Parent = folder
	end) do
		ghost = free and table.remove(free)
	end
	if not ghost then
		ghost = source:Clone() -- nil when the part isn't Archivable
		if not ghost then
			return nil
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
		ghost.Parent = folder
	end
	ghost.Size = source.Size
	return ghost
end

local function giveGhost(source: BasePart, ghost: BasePart)
	ghost.Parent = nil
	local free = ghostPool[source]
	if not free then
		free = {}
		ghostPool[source] = free
	end
	if #free < GHOST_MAX and source.Parent then
		table.insert(free, ghost)
	else
		ghost:Destroy()
	end
end

type Ghost = {
	parts: { { ghost: BasePart, source: BasePart, size: Vector3 } },
	born: number,
	from: number,
	hold: number,
	fade: number,
}
local ghosts: { Ghost } = {}
local ghostLoop: RBXScriptConnection? = nil

local function stepGhosts()
	local now = os.clock()
	for i = #ghosts, 1, -1 do
		local g = ghosts[i]
		local k = (now - g.born - g.hold) / g.fade
		if k >= 1 then
			for _, p in g.parts do
				giveGhost(p.source, p.ghost)
			end
			table.remove(ghosts, i)
		elseif k > 0 then
			-- hold solid, then swell slightly and dissolve, slow then fast
			local e = k * k
			local t = g.from + (1 - g.from) * e
			for _, p in g.parts do
				p.ghost.Transparency = t
				p.ghost.Size = p.size * (1 + 0.08 * e)
			end
		end
	end
	if #ghosts == 0 and ghostLoop then
		ghostLoop:Disconnect()
		ghostLoop = nil
	end
end

-- One afterimage of `pose`, moved by `shift`. `index` 1 is the dash start: the
-- solid one that lingers longest; each later one starts fainter and goes sooner.
local function spawnGhost(pose: Pose, index: number, shift: CFrame?)
	local k = math.clamp((index - 1) / (GHOST_MAX - 1), 0, 1)
	local g: Ghost = {
		parts = {}, born = os.clock(),
		from = 0.12 + 0.5 * k, hold = 0.14 - 0.1 * k, fade = 0.46 - 0.22 * k,
	}
	for source, cframe in pose.parts do
		if not source.Parent then
			continue
		end
		local ghost = takeGhost(source)
		if not ghost then
			continue
		end
		ghost.CFrame = if shift then shift * cframe else cframe
		ghost.Transparency = g.from
		table.insert(g.parts, { ghost = ghost, source = source, size = ghost.Size })
	end
	table.insert(ghosts, g)
	if not ghostLoop then
		ghostLoop = RunService.RenderStepped:Connect(stepGhosts)
	end
end

-- A perfect dodge, "the blow cut only a shadow": a trail of up to five
-- gold-white afterimages along the dash, from where it began (where the blow
-- lands, solid, lingering ~0.6 s) toward the player (each fainter and shorter,
-- appearing 25 ms apart, start first); a glint, cut-air wisps, a push-off ring
-- and rising motes at the start one; the rest of the dash streak turning gold;
-- a small glint and sparks on the player with a gold rim; and a brief
-- desaturated time-slow grade. No shake: nothing was hit.
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

	-- the start afterimage: this pose, moved back to the dash origin (the look
	-- the single ghost had)
	spawnGhost(snapshot(character, root), 1, origin * here:Inverse())
	if dash and recent then
		-- the rest: the poses sampled along the path, start first
		local delay = 0
		for i = 2, #dash.poses do
			local pose = dash.poses[i]
			if (pose.root.Position - here.Position).Magnitude >= GHOST_CLEAR then
				delay += GHOST_STAGGER
				task.delay(delay, spawnGhost, pose, i)
			end
		end
		-- still dashing: drop one at each pose still to come, as the player passes
		dash.onPose = function(pose: Pose, i: number)
			spawnGhost(pose, i)
		end
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
