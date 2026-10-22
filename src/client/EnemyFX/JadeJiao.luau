--!strict
-- Testbed Jade Jiao boss only. Plays the boss's own templates,
-- Effects.JadeJiao (built by tools/vfx_specs/JadeJiao.luau): acid venom-green
-- with white-hot centres, amber-gold for every warning tell, pale spirit-jade
-- for the phase 3 aura and the spirit beats. No crown, halo or ring over the
-- head, and no copies of the body: emerge, molt, ascension, phase and death
-- read through mist, motes, flares and a skyward stream (the user rejected
-- Neon afterimages of the bosses). Body hooks are looked up by name with
-- fallbacks, so a rebuilt body with the same hook names keeps working.
--
-- Cues: ready (aura / dormant mound), aggro, windup, strike, dash, land, hit,
-- stagger, death, plus enemyCue handlers phase, squeeze, coilBreak. Contact is
-- `strike` for stationary attacks. Multi-circle and multi-lane attacks (spray
-- lanes, pools, flurry strikes, rain drops) deliver several windup cues: they
-- are deduped by attack and time, and each impact is played here when its own
-- `seconds` run out (there is no per-circle strike cue).
-- Attributes read: Burrowed, Phase, Coil*, Dash*; the body hooks are named in
-- the Jade Jiao fight sheet (Mouth, Core, Dive_FX, TailTip_FX, ...). A missing
-- part falls back to the Skull, the Body or the root.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)

type Cue = {
	model: Model,
	root: BasePart,
	kind: string,
	attack: string?,
	shape: any?,
	seconds: number?,
	target: Model?,
	at: number,
}

type Bolt = { stop: (Vector3?) -> (), position: () -> Vector3 }

type State = {
	generation: number,
	latestAt: number,
	windupAt: number,
	strikeAt: number,
	landAt: number,
	dead: boolean,
	attack: string?,
	shapes: { any },
	windups: { BasePart },
	aura: any?,
	roarAt: number,
	flareUntil: number,
	stopRidge: (() -> ())?,
	bolts: { Bolt },
	dome: BasePart?,
	moundFX: BasePart?,
	hidden: boolean,
	holdHidden: boolean,
	parts: { BasePart }?,
	hideLoop: RBXScriptConnection?,
	coil: any?,
	phaseSeen: number,
	seen: { [number]: boolean },
}

local TEMPLATE = "JadeJiao"
local WHITE = Color3.new(1, 1, 1)
local VENOM = Color3.fromRGB(155, 255, 74)
local VHOT = Color3.fromRGB(226, 255, 182)
local JADE = Color3.fromRGB(168, 255, 216)
local GOLD = Color3.fromRGB(255, 190, 70)
local HOT = Color3.fromRGB(255, 236, 176)
local SOIL = Color3.fromRGB(92, 72, 50)
local EPSILON = 0.035
local BOLT_SPEED = 75

local WINDUP = {
	emerge = 2.2,
	venomFang = 0.75,
	tailSweep = 0.8,
	pillarSlam = 1.0,
	fangFlurry = 0.9,
	mireDive = 0.8,
	erupt = 0.85,
	venomLance = 0.7,
	venomSpray = 1.0,
	venomPools = 1.0,
	jiaoCoil = 1.5,
	dreadHiss = 1.1,
	molt = 1.6,
	ascension = 2.0,
	venomRain = 2.0,
}
-- attacks whose cues arrive several at once (lanes or circles)
local MULTI = { venomSpray = true, venomPools = true }

local Jiao = {}
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function ours(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function state(model: Model): State
	local s = states[model]
	if not s then
		s = {
			generation = 0,
			latestAt = -math.huge,
			windupAt = -math.huge,
			strikeAt = -math.huge,
			landAt = -math.huge,
			dead = false,
			attack = nil,
			shapes = {},
			windups = {},
			aura = nil,
			roarAt = -math.huge,
			flareUntil = 0,
			stopRidge = nil,
			bolts = {},
			dome = nil,
			moundFX = nil,
			hidden = false,
			holdHidden = false,
			parts = nil,
			hideLoop = nil,
			coil = nil,
			phaseSeen = 0,
			seen = {},
		}
		states[model] = s
	end
	return s
end

-- The boss is still in the world and alive.
local function alive(cue: Cue): boolean
	if not ours(cue) or not cue.model.Parent or not cue.root.Parent then
		return false
	end
	local s = state(cue.model)
	local health = cue.model:GetAttribute("Health")
	return not (s.dead or cue.model:GetAttribute("FadeAt") ~= nil or (type(health) == "number" and health <= 0))
end

-- Ignore a queued task once a newer state/attack has superseded its cue.
local function current(cue: Cue, phase: string?, contactGrace: number?): boolean
	if not alive(cue) then
		return false
	end
	local s = state(cue.model)
	local at = cue.model:GetAttribute("StateAt")
	local grace = contactGrace or EPSILON
	if cue.at + grace < s.latestAt or (type(at) == "number" and at > cue.at + grace) then
		return false
	end
	if cue.attack ~= cue.model:GetAttribute("Attack") then
		return false
	end
	return phase == nil or cue.model:GetAttribute("AIState") == phase
end

-- The snake's "Body" is a part, so hooks are searched from the whole model.
local function find(cue: Cue, name: string): Instance?
	return cue.model:FindFirstChild(name, true)
end

local function part(cue: Cue, names: { string }): BasePart
	for _, name in names do
		local found = find(cue, name)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return cue.root
end

local function root(cue: Cue): BasePart
	return cue.root
end

local function point(cue: Cue, name: string, fallback: { string }): (CFrame, BasePart)
	local a = find(cue, name)
	local follow = part(cue, fallback)
	local position = follow.Position
	if a and a:IsA("Attachment") then
		position = a.WorldPosition
		if a.Parent and a.Parent:IsA("BasePart") then
			follow = a.Parent
		end
	end
	return CFrame.new(position) * root(cue).CFrame.Rotation, follow
end

local function ground(cue: Cue, position: Vector3): Vector3
	local exclude: { Instance } = { cue.model }
	local wilds = workspace:FindFirstChild("Wilds")
	local enemies = wilds and wilds:FindFirstChild("Enemies")
	if enemies then
		table.insert(exclude, enemies)
	end
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(exclude, camera)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else Vector3.new(position.X, cue.root.Position.Y - cue.root.Size.Y / 2, position.Z)
end

local function scaleSequence(sequence: NumberSequence, scale: number): NumberSequence
	local points = {}
	for _, key in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale))
	end
	return NumberSequence.new(points)
end

-- Templates are authored at the boss's size; ground shapes carry an
-- AuthoredRadius and are scaled to the live circle.
local function prepare(copy: BasePart, scale: number)
	if math.abs(scale - 1) < 1e-3 then
		return
	end
	copy.Size *= scale
	for _, d in copy:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position *= scale
			local radius = d:GetAttribute("Radius")
			if type(radius) == "number" then
				d:SetAttribute("Radius", radius * scale)
			end
		elseif d:IsA("ParticleEmitter") then
			d.Size = scaleSequence(d.Size, scale)
			d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
			d.Acceleration *= scale
		end
	end
end

-- Refit a held effect to the windup that is actually left.
local function retime(copy: BasePart, seconds: number)
	local authored = copy:GetAttribute("AuthoredSeconds")
	if type(authored) ~= "number" or authored <= 0 then
		return
	end
	local scale = seconds / authored
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Lifetime = NumberRange.new(d.Lifetime.Min * scale, d.Lifetime.Max * scale)
			for _, key in { "EmitDelay", "EmitDuration" } do
				local value = d:GetAttribute(key)
				if type(value) == "number" and value > 0 then
					d:SetAttribute(key, value * scale)
				end
			end
		end
	end
end

-- Recolour the bright layers (not the ink and soil bases) of a clone.
local function tint(copy: BasePart, color: Color3)
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.LightEmission > 0.3 then
			d.Color = ColorSequence.new(WHITE, color)
		end
	end
end

local function boost(copy: BasePart, factor: number)
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local count = d:GetAttribute("EmitCount")
			if type(count) == "number" then
				d:SetAttribute("EmitCount", math.max(1, math.round(count * factor)))
			end
		end
	end
end

local function template(name: string): BasePart?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local folder = effects and effects:FindFirstChild(TEMPLATE)
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

type Options = {
	scale: number?,
	follow: BasePart?,
	seconds: number?,
	tint: Color3?,
	boost: number?,
	edit: ((BasePart) -> ())?,
	guard: (() -> boolean)?,
}

local function make(name: string, frame: CFrame, o: Options?): BasePart?
	local base = template(name)
	if not base then
		return nil
	end
	local opts: Options = o or {}
	local copy = base:Clone()
	local scale = opts.scale or 1
	local authored = copy:GetAttribute("AuthoredRadius")
	if opts.scale and type(authored) == "number" then
		scale = opts.scale / authored
	end
	prepare(copy, scale)
	if opts.seconds then
		retime(copy, opts.seconds)
	end
	if opts.tint then
		tint(copy, opts.tint)
	end
	if opts.boost then
		boost(copy, opts.boost)
	end
	if opts.edit then
		opts.edit(copy)
	end
	copy.CFrame = frame
	return copy
end

local function follow(copy: BasePart, target: BasePart, guard: (() -> boolean)?)
	local offset = target.CFrame:ToObjectSpace(copy.CFrame)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not copy.Parent then
			connection:Disconnect()
		elseif not target.Parent or (guard and not guard()) then
			connection:Disconnect()
			copy:Destroy()
		else
			copy.CFrame = target.CFrame * offset
		end
	end)
end

local function play(name: string, frame: CFrame, o: Options?): BasePart?
	local copy = make(name, frame, o)
	if not copy then
		return nil
	end
	local opts: Options = o or {}
	copy.Parent = TechniqueVFX.folder
	if opts.follow then
		follow(copy, opts.follow, opts.guard)
	end
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.3)
	return copy
end

local function cancelWindup(s: State)
	s.generation += 1
	for _, effect in s.windups do
		effect:Destroy()
	end
	table.clear(s.windups)
end

local function windupPlay(cue: Cue, name: string, frame: CFrame, o: Options?)
	local s = state(cue.model)
	local generation = s.generation
	local opts: Options = table.clone(o or {}) :: any
	opts.guard = function()
		return s.generation == generation and alive(cue)
	end
	local effect = play(name, frame, opts)
	if effect then
		table.insert(s.windups, effect)
	end
end

-- Schedule against the server phase start, so latency consumes part of the
-- windup instead of adding a second windup after the telegraph arrives.
local function windupBeat(cue: Cue, seconds: number, fraction: number, action: () -> ())
	local s = state(cue.model)
	local generation = s.generation
	local now = workspace:GetServerTimeNow()
	local duration = math.max(seconds, now + seconds - cue.at)
	local delay = math.max(0, cue.at + duration * fraction - now)
	task.delay(delay, function()
		if s.generation == generation and alive(cue) then
			action()
		end
	end)
end

local function shake(amount: number, position: Vector3?, radius: number?)
	if TechniqueVFX.full then
		return -- the templates carry ScreenEffects shakes
	end
	if position and radius then
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart") and (hrp.Position - position).Magnitude <= radius) then
			return
		end
	end
	local ok, effects = pcall(require, script.Parent.Parent.CombatEffects)
	if ok then
		(effects :: any).shake(amount)
	end
end

local function hurtShake(amount: number)
	local ok, effects = pcall(require, script.Parent.Parent.CombatEffects)
	if ok then
		(effects :: any).shake(amount)
	end
end

local function facing(cue: Cue): CFrame
	return root(cue).CFrame.Rotation
end

-- shape helpers --------------------------------------------------------------

local function circleOf(shape: any, fallbackRadius: number, cue: Cue): (Vector3, number)
	if type(shape) == "table" and typeof(shape.center) == "Vector3" then
		local r = if type(shape.radius) == "number" then shape.radius else fallbackRadius
		return shape.center, r
	end
	return cue.root.Position, fallbackRadius
end

-- a box lane: start (the attacker's end) to the far end, along the ground
local function laneOf(shape: any, cue: Cue): (Vector3, Vector3)
	if type(shape) == "table" and typeof(shape.cframe) == "CFrame" and typeof(shape.size) == "Vector2" then
		local cf: CFrame = shape.cframe
		local length = (shape.size :: Vector2).Y
		return cf:PointToWorldSpace(Vector3.new(0, 0, length / 2)), cf:PointToWorldSpace(Vector3.new(0, 0, -length / 2))
	end
	local mouth = point(cue, "Mouth", { "Skull" }).Position
	return mouth, mouth + root(cue).CFrame.LookVector * 40
end

local function torsoOf(target: Model?): BasePart?
	local torso = target and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
	return if torso and torso:IsA("BasePart") then torso else nil
end

-- Spirit beats: emitters mounted on body hooks, never copies of the body.
local SPIRIT_HOOKS = { "Throat", "Core", "Coil_Tail6", "Coil_Tail12", "TailTip_FX" }

-- Scale flakes and jade motes shed off the hooks that exist on this body.
local function shedAlong(cue: Cue, seconds: number, boostBy: number?, windup: boolean?)
	for _, name in SPIRIT_HOOKS do
		local frame, host = point(cue, name, { "Body" })
		if windup then
			windupPlay(cue, "ShedSkin", frame, { follow = host, seconds = seconds, boost = boostBy })
		else
			play("ShedSkin", frame, { follow = host, seconds = seconds, boost = boostBy, tint = JADE })
		end
	end
end

-- A spirit stream thrown skyward from a hook: flash, jade rays and motes.
local function skyStream(cue: Cue, name: string, fallback: { string })
	local frame = point(cue, name, fallback)
	play("RainRelease", CFrame.lookAt(frame.Position, frame.Position + Vector3.new(0, 1, 0)))
end

-- Tell parts ---------------------------------------------------------------------

-- Dim to hot over `seconds`, held until the windup ends (the generation
-- changes), then back over 0.2 s. `swell` also puffs the ThroatSac; `pulses`
-- makes it beat that many times (the spray's three throat pulses).
local function tellRun(cue: Cue, names: { string }, color: Color3, seconds: number, stagger: number?, swell: number?, pulses: number?)
	local s = state(cue.model)
	local generation = s.generation
	local list: { { p: BasePart, base: Color3, size: Vector3, delay: number } } = {}
	for i, name in names do
		local p = find(cue, name)
		if p and p:IsA("BasePart") then
			local base = p:GetAttribute("TellBase")
			table.insert(list, {
				p = p,
				base = if typeof(base) == "Color3" then base else p.Color,
				size = p.Size,
				delay = (i - 1) * (stagger or 0),
			})
		end
	end
	if #list == 0 then
		return
	end
	local started = os.clock()
	local decayAt: number? = nil
	local peaks: { number } = {}
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock() - started
		if not decayAt and (s.generation ~= generation or now > seconds + 0.8 or not cue.model.Parent) then
			decayAt = now
			for i, it in list do
				peaks[i] = math.clamp((now - it.delay) / math.max(0.05, seconds - it.delay), 0, 1) ^ 1.5
			end
		end
		local finished = true
		for i, it in list do
			local p = it.p
			if p.Parent then
				local a
				if decayAt then
					a = peaks[i] * math.max(0, 1 - (now - decayAt) / 0.2)
				else
					a = math.clamp((now - it.delay) / math.max(0.05, seconds - it.delay), 0, 1) ^ 1.5
				end
				p.Color = it.base:Lerp(color, a)
				if swell and p.Name == "ThroatSac" then
					local beat = if pulses then math.abs(math.sin(pulses * math.pi * math.min(now, seconds) / seconds)) else 1
					p.Size = it.size * (1 + swell * a * (0.4 + 0.6 * beat))
				end
				if a > 0.001 then
					finished = false
				end
			end
		end
		if decayAt and finished then
			connection:Disconnect()
			for _, it in list do
				if it.p.Parent then
					it.p.Color = it.base
					it.p.Size = it.size
				end
			end
		end
	end)
end

local EYES = { "EyeL", "EyeR", "EyeSideL", "EyeSideR", "BrowPearl" }
local function withEyes(extra: { string }): { string }
	local list = table.clone(EYES)
	for _, n in extra do
		table.insert(list, n)
	end
	return list
end
local SEAMS = { "ScaleSeam1", "ScaleSeam2", "ScaleSeam3", "ScaleSeam4", "ScaleSeam5", "ScaleSeam6", "ScaleSeam7", "ScaleSeam8", "ScaleSeam9", "TailTipGem" }

-- Body visibility (burrow) -------------------------------------------------------

local function bodyList(cue: Cue): { BasePart }
	local s = state(cue.model)
	if not s.parts then
		local list = {}
		for _, d in cue.model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestor("HealthBar") then
				table.insert(list, d)
			end
		end
		s.parts = list
	end
	return s.parts :: { BasePart }
end

-- Tween LocalTransparencyModifier on every body part (one loop, not 177 tweens).
local function setHidden(cue: Cue, hidden: boolean, duration: number)
	local s = state(cue.model)
	if s.hidden == hidden and not s.hideLoop then
		return
	end
	s.hidden = hidden
	if s.hideLoop then
		s.hideLoop:Disconnect()
		s.hideLoop = nil
	end
	local list = bodyList(cue)
	local from = if list[1] then list[1].LocalTransparencyModifier else 0
	local to = if hidden then 1 else 0
	local started = os.clock()
	s.hideLoop = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - started) / math.max(0.01, duration), 0, 1)
		local value = from + (to - from) * a
		for _, p in list do
			if p.Parent then
				p.LocalTransparencyModifier = value
			end
		end
		if a >= 1 and s.hideLoop then
			s.hideLoop:Disconnect()
			s.hideLoop = nil
		end
	end)
end

-- Phase reveal parts: cracks at phase 2, fins and whiskers at phase 3.
local function revealPhase(cue: Cue)
	local phase = cue.model:GetAttribute("Phase")
	if type(phase) ~= "number" then
		return
	end
	local s = state(cue.model)
	if phase <= s.phaseSeen then
		return
	end
	s.phaseSeen = phase
	for _, d in cue.model:GetDescendants() do
		local need = d:GetAttribute("PhaseReveal")
		if d:IsA("BasePart") and type(need) == "number" and need <= phase then
			TweenService:Create(d, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Transparency = 0.05 }):Play()
		end
	end
end

-- Aura ---------------------------------------------------------------------------

local function mount(parent: BasePart, name: string, position: Vector3, templateName: string, into: { any }, only: { string }?, divide: number?)
	local source = template(templateName)
	if not source then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	for _, e in source:GetChildren() do
		if e:IsA("ParticleEmitter") and (not only or table.find(only, e.Name)) then
			local c = e:Clone()
			c.Enabled = true
			c.Parent = a
			local base = e:GetAttribute("BaseRate")
			table.insert(into, { e = c, base = if type(base) == "number" then base / (divide or 1) else 0, name = e.Name })
		end
	end
end

local function dormant(cue: Cue): boolean
	return cue.model:GetAttribute("Burrowed") == true and cue.model:GetAttribute("AIState") == "idle"
end

local function applyAura(cue: Cue)
	local s = state(cue.model)
	local aura = s.aura
	if not aura then
		return
	end
	local health, max = cue.model:GetAttribute("Health"), cue.model:GetAttribute("MaxHealth")
	local ratio = if type(health) == "number" and type(max) == "number" and max > 0 then math.clamp(health / max, 0, 1) else 1
	local phase = cue.model:GetAttribute("Phase")
	local off = s.dead or ratio <= 0 or cue.model:GetAttribute("Burrowed") == true
	local flare = if os.clock() < s.flareUntil then 2.2 else 1
	local k = (1 + (1 - ratio) * 1.2) * flare
	for _, item in aura.items do
		local e: ParticleEmitter = item.e
		if off then
			e.Enabled = false
		else
			e.Enabled = true
			if item.name == "JadeWisp" then
				e.Rate = if type(phase) == "number" and phase >= 3 then 2.4 * flare else 0
			elseif item.name == "JadeMotes" then
				e.Rate = if type(phase) == "number" and phase >= 3 then 3 * flare else 0
			elseif item.name == "Under" or item.name == "Array" or item.name == "Sigil" then
				e.Rate = item.base
			else
				e.Rate = item.base * k
			end
		end
	end
end

-- The dormant mound: a soil dome over the sunk body, a dust leak and green glints.
local function showMound(cue: Cue, on: boolean)
	local s = state(cue.model)
	if on then
		if s.dome then
			return
		end
		local at = ground(cue, root(cue).Position)
		local dome = Instance.new("Part")
		dome.Name = "JiaoMound"
		dome.Shape = Enum.PartType.Ball
		dome.Anchored, dome.CanCollide, dome.CanQuery, dome.CanTouch, dome.CastShadow = true, false, false, false, true
		dome.Material = Enum.Material.Ground
		dome.Color = SOIL
		dome.Size = Vector3.new(26, 11, 26)
		dome.CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0))
		dome.Parent = TechniqueVFX.folder
		s.dome = dome
		local fx = make("MoundFX", CFrame.new(at + Vector3.new(0, 4.5, 0)))
		if fx then
			fx.Parent = TechniqueVFX.folder
			TechniqueVFX.enable(fx)
			s.moundFX = fx
		end
	else
		local dome, fx = s.dome, s.moundFX
		s.dome, s.moundFX = nil, nil
		if fx then
			TechniqueVFX.disable(fx)
			TechniqueVFX.cleanup(fx, 0.3)
		end
		if dome then
			TweenService:Create(dome, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			task.delay(0.7, function()
				dome:Destroy()
			end)
		end
	end
end

local function refreshMode(cue: Cue)
	local s = state(cue.model)
	if s.dead then
		return
	end
	local burrowed = cue.model:GetAttribute("Burrowed") == true
	-- the Burrowed flip can beat the emerge windup cue: treat it as emerging too
	local emerging = cue.model:GetAttribute("Attack") == "emerge" and cue.model:GetAttribute("AIState") == "windup"
	local held = s.holdHidden or emerging
	showMound(cue, dormant(cue) or (held and s.dome ~= nil))
	if burrowed then
		-- the body is under: hide it at once unless a dive is still sinking
		if cue.model:GetAttribute("Attack") ~= "mireDive" then
			setHidden(cue, true, 0.05)
		end
	elseif held then
		-- emerge: the body stays under and the mound stays until the eruption
		setHidden(cue, true, 0.05)
	else
		setHidden(cue, false, 0.15)
	end
	applyAura(cue)
end

local function startAura(cue: Cue)
	local s = state(cue.model)
	if s.aura or s.dead then
		return
	end
	local main = root(cue)
	local body = part(cue, { "Body" })
	if body == cue.root then
		return
	end
	local items: { any } = {}
	local feet = ground(cue, main.Position).Y - main.Position.Y + 0.2
	mount(main, "AuraGround", Vector3.new(0, feet, 0), "AuraGround", items)
	for _, name in { "Body", "Neck3", "Tail5", "Tail10", "Tail15" } do
		local p = part(cue, { name })
		if p ~= cue.root then
			mount(p, "AuraMist", Vector3.zero, "AuraBody", items, { "Mist" }, 2)
		end
	end
	for _, name in { "Body", "Neck4", "Tail8" } do
		local p = part(cue, { name })
		if p ~= cue.root then
			mount(p, "AuraMotes", Vector3.zero, "AuraBody", items, { "Motes" }, 1)
		end
	end
	for _, name in { "Neck2", "Body", "Tail10" } do
		local p = part(cue, { name })
		if p ~= cue.root then
			mount(p, "AuraJade", Vector3.zero, "AuraBody", items, { "JadeWisp", "JadeMotes" }, 1)
		end
	end
	local mouth = find(cue, "Mouth")
	local skull = part(cue, { "Skull" })
	if mouth and mouth:IsA("Attachment") and skull ~= cue.root then
		mount(skull, "AuraBreath", mouth.Position, "AuraBreath", items)
	end
	s.aura = { items = items }
	CollectionService:AddTag(cue.model, "CraterIgnore")
	applyAura(cue)
	cue.model:GetAttributeChangedSignal("Health"):Connect(function()
		applyAura(cue)
	end)
	cue.model:GetAttributeChangedSignal("Phase"):Connect(function()
		applyAura(cue)
		revealPhase(cue)
	end)
	cue.model:GetAttributeChangedSignal("Burrowed"):Connect(function()
		refreshMode(cue)
	end)
	cue.model:GetAttributeChangedSignal("AIState"):Connect(function()
		if dormant(cue) ~= (s.dome ~= nil) then
			refreshMode(cue)
		end
	end)
	revealPhase(cue)
	refreshMode(cue)
end

local function flareAura(cue: Cue, seconds: number)
	local s = state(cue.model)
	s.flareUntil = os.clock() + seconds
	applyAura(cue)
	task.delay(seconds + 0.05, function()
		if cue.model.Parent then
			applyAura(cue)
		end
	end)
end

-- Projectiles --------------------------------------------------------------------

-- Fly `name` from -> to at `speed` (an arc of `arc` studs if given). Returns a
-- handle so a `hit` cue can stop it early.
local function fly(cue: Cue, name: string, from: Vector3, to: Vector3, speed: number, arc: number, scale: number?, onLand: ((Vector3) -> ())?): Bolt?
	local copy = make(name, CFrame.lookAt(from, to), { scale = scale })
	if not copy then
		if onLand then
			task.delay((to - from).Magnitude / speed, function()
				onLand(to)
			end)
		end
		return nil
	end
	copy.Parent = TechniqueVFX.folder
	TechniqueVFX.enable(copy)
	local distance = math.max(1, (to - from).Magnitude)
	local duration = distance / speed
	local started = os.clock()
	local done = false
	local position = from
	local connection: RBXScriptConnection
	local function finish(at: Vector3?)
		if done then
			return
		end
		done = true
		connection:Disconnect()
		TechniqueVFX.disable(copy)
		TechniqueVFX.cleanup(copy, 0.3)
		if onLand then
			onLand(at or position)
		end
	end
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - started) / duration, 0, 1)
		local nextPos = from:Lerp(to, u) + Vector3.new(0, arc * 4 * u * (1 - u), 0)
		if (nextPos - position).Magnitude > 0.01 then
			copy.CFrame = CFrame.lookAt(nextPos, nextPos + (nextPos - position))
		else
			copy.Position = nextPos
		end
		position = nextPos
		if u >= 1 or not copy.Parent then
			finish(to)
		end
	end)
	return {
		stop = function(at: Vector3?)
			if at then
				position = at
				copy.Position = at
			end
			finish(at)
		end,
		position = function()
			return position
		end,
	}
end

local function boltImpact(position: Vector3)
	play("BoltImpact", CFrame.new(position))
end

-- Fire one bolt per lane, from the Mouth to the lane's end (or the first hit).
local function fireLanes(cue: Cue, lanes: { any })
	local s = state(cue.model)
	local mouth = point(cue, "Mouth", { "Skull" }).Position
	play("SpitRelease", CFrame.lookAt(mouth, mouth + root(cue).CFrame.LookVector))
	for _, shape in lanes do
		local _, finish = laneOf(shape, cue)
		local target = ground(cue, finish) + Vector3.new(0, 1.6, 0)
		local bolt
		bolt = fly(cue, "VenomBolt", mouth, target, BOLT_SPEED, 0, 1, function(at)
			boltImpact(at)
			if bolt then
				local i = table.find(s.bolts, bolt)
				if i then
					table.remove(s.bolts, i)
				end
			end
		end)
		if bolt then
			table.insert(s.bolts, bolt)
		end
	end
end

-- Pools: a glob lobbed in an arc to each circle, then the 7 s hazard disc.
local function lobPool(cue: Cue, shape: any, seconds: number)
	local center, radius = circleOf(shape, 4.5, cue)
	play("MarkerLite", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { scale = radius, seconds = seconds })
	local launch = seconds * 0.42
	local flight = math.max(0.25, seconds - launch)
	task.delay(launch, function()
		if not alive(cue) then
			return
		end
		local from = point(cue, "Mouth", { "Skull" }).Position
		local spot = ground(cue, center)
		local to = spot + Vector3.new(0, 0.4, 0)
		local distance = (to - from).Magnitude
		fly(cue, "VenomBolt", from, to, distance / flight, math.clamp(distance * 0.35, 8, 26), 1.5, function(at)
			local at2 = ground(cue, at)
			play("PoolSplash", CFrame.new(at2), { scale = radius })
			play("PoolDisc", CFrame.new(at2 + Vector3.new(0, 0.05, 0)), { scale = radius })
			shake(0.1, at2, 50)
		end)
	end)
end

-- Rain: marker, then a drop falling from high, a splash and a fume puff.
local function rainDrop(cue: Cue, shape: any, seconds: number)
	local center, radius = circleOf(shape, 4.5, cue)
	local spot = ground(cue, center)
	local marker = play("MarkerLite", CFrame.new(spot + Vector3.new(0, 0.05, 0)), { scale = radius, seconds = seconds })
	local fall = math.min(0.4, seconds * 0.5)
	task.delay(math.max(0, seconds - fall), function()
		if not cue.model.Parent then
			return
		end
		fly(cue, "RainDrop", spot + Vector3.new(0, 60, 0), spot + Vector3.new(0, 0.5, 0), 60 / fall, 0, 1, function(at)
			play("RainSplash", CFrame.new(ground(cue, at)), { scale = radius })
			shake(0.06, at, 40)
		end)
	end)
	if marker then
		marker.Name = "RainMarker"
	end
end

-- Ridge (mireDive) -----------------------------------------------------------------

local function stopRidge(s: State)
	if s.stopRidge then
		s.stopRidge()
	end
end

local function startRidge(cue: Cue)
	local s = state(cue.model)
	stopRidge(s)
	local from, to = cue.model:GetAttribute("DashFrom"), cue.model:GetAttribute("DashTo")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 1 then
		return
	end
	local unit = flat.Unit
	local speedAttr, secondsAttr, dashAt = cue.model:GetAttribute("DashSpeed"), cue.model:GetAttribute("DashSeconds"), cue.model:GetAttribute("DashAt")
	local speed = if type(speedAttr) == "number" and speedAttr > 1 then speedAttr elseif type(secondsAttr) == "number" and secondsAttr > 0.05 then length / secondsAttr else 45
	local started = if type(dashAt) == "number" then dashAt else workspace:GetServerTimeNow()
	local head = make("RidgeFX", CFrame.new(from))
	if head then
		head.Parent = TechniqueVFX.folder
		TechniqueVFX.enable(head)
	end
	local segments: { BasePart } = {}
	local lastSpawn = -math.huge
	local stopped = false
	local connection: RBXScriptConnection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		s.stopRidge = nil
		connection:Disconnect()
		if head then
			TechniqueVFX.disable(head)
			TechniqueVFX.cleanup(head, 0.3)
		end
		for _, seg in segments do
			TweenService:Create(seg, TweenInfo.new(0.7), { Transparency = 1, Size = seg.Size * Vector3.new(1, 0.3, 1) }):Play()
			task.delay(0.8, function()
				seg:Destroy()
			end)
		end
	end
	connection = RunService.RenderStepped:Connect(function()
		local travelled = math.clamp(speed * (workspace:GetServerTimeNow() - started), 0, length)
		local position = from + unit * travelled
		local floor = ground(cue, position)
		if head then
			head.CFrame = CFrame.lookAt(floor, floor + unit)
		end
		if travelled - lastSpawn >= 3.2 then
			lastSpawn = travelled
			local seg = Instance.new("Part")
			seg.Name = "JiaoRidge"
			seg.Shape = Enum.PartType.Ball
			seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
			seg.Material = Enum.Material.Ground
			seg.Color = SOIL
			seg.Size = Vector3.new(5.5, 0.6, 7.5)
			seg.CFrame = CFrame.lookAt(floor + Vector3.new(0, 0.1, 0), floor + unit)
			seg.Parent = TechniqueVFX.folder
			TweenService:Create(seg, TweenInfo.new(0.15), { Size = Vector3.new(5.5, 3.2, 7.5) }):Play()
			table.insert(segments, seg)
			if #segments > 14 then
				table.remove(segments, 1):Destroy()
			end
		end
		if travelled >= length and workspace:GetServerTimeNow() - started > length / speed + 1.2 then
			stop()
		end
	end)
	s.stopRidge = stop
end

-- Coil ring --------------------------------------------------------------------

local function removeCoil(cue: Cue, quick: boolean?)
	local s = state(cue.model)
	local coil = s.coil
	if not coil then
		return
	end
	s.coil = nil
	coil.connection:Disconnect()
	for _, g in coil.gates do
		TechniqueVFX.disable(g)
		TechniqueVFX.cleanup(g, 0.3)
	end
	for _, glow in coil.glows do
		glow:Destroy()
	end
	for _, seg in coil.segments do
		TweenService:Create(seg, TweenInfo.new(if quick then 0.15 else 0.6), { Transparency = 1 }):Play()
		task.delay(0.7, function()
			seg:Destroy()
		end)
	end
end

local function buildCoil(cue: Cue)
	local s = state(cue.model)
	local centre = cue.model:GetAttribute("CoilCenter")
	local radius = cue.model:GetAttribute("CoilRadius")
	local gapDir = cue.model:GetAttribute("CoilGap")
	local half = cue.model:GetAttribute("CoilHalfAngle")
	if typeof(centre) ~= "Vector3" or type(radius) ~= "number" or typeof(gapDir) ~= "Vector3" or type(half) ~= "number" then
		return
	end
	removeCoil(cue, true)
	local squeezeAt = cue.model:GetAttribute("CoilSqueezeAt")
	local startedAt = workspace:GetServerTimeNow()
	local endAt = if type(squeezeAt) == "number" then squeezeAt else startedAt + 3
	local floor = ground(cue, centre)
	play("CoilForm", CFrame.new(floor), { scale = radius })
	shake(0.3, centre, radius + 60)
	local gapAngle = math.atan2(gapDir.X, gapDir.Z)
	local segments: { BasePart } = {}
	local count = 40
	local chord = 2 * math.pi * radius / count
	local gapEdges: { number } = { gapAngle - math.rad(half), gapAngle + math.rad(half) }
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * 2 * math.pi
		local delta = math.abs((angle - gapAngle + math.pi) % (2 * math.pi) - math.pi)
		local inGap = delta < math.rad(half)
		local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local seg = Instance.new("Part")
		seg.Name = "JiaoCoilRing"
		seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
		seg.Material = Enum.Material.Neon
		local pos = centre + dir * radius
		local y = ground(cue, pos).Y + 0.25
		seg.CFrame = CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) + Vector3.new(dir.Z, 0, -dir.X))
		if inGap then
			-- the door: sparse bright dashes
			seg.Color = WHITE
			seg.Size = Vector3.new(0.6, 0.3, chord * 0.35)
			if i % 2 == 0 then
				seg.Transparency = 0.1
			else
				seg.Transparency = 1
			end
		else
			seg.Color = JADE
			seg.Size = Vector3.new(1.4, 0.35, chord * 1.02)
			seg.Transparency = 0.15
		end
		seg.Parent = TechniqueVFX.folder
		table.insert(segments, seg)
	end
	local gates: { BasePart } = {}
	for _, angle in gapEdges do
		local pos = centre + Vector3.new(math.sin(angle), 0, math.cos(angle)) * radius
		local gate = make("CoilGate", CFrame.new(ground(cue, pos)))
		if gate then
			gate.Parent = TechniqueVFX.folder
			TechniqueVFX.enable(gate)
			table.insert(gates, gate)
		end
	end
	-- body glow along the coil
	local glows: { Instance } = {}
	local hood = template("HoodFlare")
	local hold = hood and hood:FindFirstChild("Hold")
	for _, name in { "Coil_Tail3", "Coil_Tail6", "Coil_Tail9", "Coil_Tail12" } do
		local a = find(cue, name)
		if a and a:IsA("Attachment") and hold and hold:IsA("ParticleEmitter") then
			local e = hold:Clone()
			e.Color = ColorSequence.new(WHITE, JADE)
			e.Rate = 10
			e.Enabled = true
			e.Parent = a
			table.insert(glows, e)
		end
	end
	-- pulses tighten toward the squeeze: a ring each, shorter gaps
	local remaining = math.max(0.5, endAt - startedAt)
	for k = 1, 4 do
		local when = remaining * (1 - 0.5 ^ k) - 0.1
		task.delay(math.max(0.2, when), function()
			if s.coil and s.coil.id == startedAt then
				play("CoilPulse", CFrame.new(floor), { scale = radius })
			end
		end)
	end
	local clockStart = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		local phase = math.clamp((workspace:GetServerTimeNow() - startedAt) / remaining, 0, 1)
		local pulse = 0.5 + 0.5 * math.sin((os.clock() - clockStart) * (4 + 14 * phase * phase))
		local color = JADE:Lerp(WHITE, pulse * 0.8)
		for _, seg in segments do
			if seg.Color ~= WHITE and seg.Parent then
				seg.Color = color
			end
		end
		if workspace:GetServerTimeNow() > endAt + 2 or not cue.model.Parent then
			removeCoil(cue)
		end
	end)
	s.coil = { id = startedAt, centre = centre, radius = radius, segments = segments, gates = gates, glows = glows, connection = connection, floor = floor }
end

-- Cues -----------------------------------------------------------------

function Jiao.ready(cue: Cue)
	if not ours(cue) then
		return
	end
	for _ = 1, 20 do
		if part(cue, { "Body" }) ~= cue.root and part(cue, { "Skull" }) ~= cue.root then
			break
		end
		task.wait(0.25)
	end
	startAura(cue)
	-- the rain's gather has no circle of its own: if no windup cue arrived, play it
	cue.model:GetAttributeChangedSignal("Attack"):Connect(function()
		if cue.model:GetAttribute("Attack") == "venomRain" and cue.model:GetAttribute("AIState") == "windup" then
			local at = cue.model:GetAttribute("StateAt")
			task.delay(0.25, function()
				local s = state(cue.model)
				if type(at) == "number" and math.abs(s.windupAt - at) > 0.3 and alive(cue) and cue.model:GetAttribute("Attack") == "venomRain" then
					Jiao.windup({
						model = cue.model, root = cue.root, kind = cue.kind, attack = "venomRain",
						shape = nil, seconds = math.max(0.3, WINDUP.venomRain - 0.25), target = nil, at = at,
					})
				end
			end)
		end
	end)
end

function Jiao.aggro(cue: Cue)
	if not ours(cue) then
		return
	end
	startAura(cue)
end

local function hoodFlare(cue: Cue, seconds: number, blaze: boolean?)
	for _, name in { "HoodL_FX", "HoodR_FX" } do
		local frame, hood = point(cue, name, { "HoodL", "HoodR" })
		windupPlay(cue, "HoodFlare", frame, { follow = hood, seconds = math.min(seconds, 0.8), boost = if blaze then 1.8 else 1 })
	end
	tellRun(cue, { "HoodSpotL", "HoodSpotR" }, if blaze then VHOT else VENOM, seconds)
end

-- one fang strike of the flurry (its own windup cue)
local function flurryStrike(cue: Cue, shape: any, seconds: number)
	local at = math.floor(cue.at * 20 + 0.5)
	local s = state(cue.model)
	if s.seen[at] then
		return
	end
	s.seen[at] = true
	task.delay(math.max(0, seconds), function()
		if not alive(cue) or cue.model:GetAttribute("Attack") ~= "fangFlurry" then
			return
		end
		local mouth = point(cue, "Mouth", { "Snout", "Skull" })
		local look = mouth.LookVector
		local aim = look
		local centre, radius = cue.root.Position, 12
		if type(shape) == "table" and typeof(shape.center) == "Vector3" then
			centre = shape.center
			radius = if type(shape.radius) == "number" then shape.radius else 12
			if typeof(shape.cframe) == "CFrame" then
				aim = (shape.cframe :: CFrame).LookVector
			end
		end
		play("FangSnap", CFrame.new(mouth.Position) * CFrame.lookAt(Vector3.zero, aim).Rotation, { scale = 0.8 })
		local markAt = ground(cue, centre + Vector3.new(aim.X, 0, aim.Z).Unit * radius * 0.6)
		play("GroundMark", CFrame.new(markAt), { scale = 4.5 })
		shake(0.14, cue.root.Position, 70)
	end)
end

function Jiao.windup(cue: Cue)
	if not alive(cue) then
		return
	end
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack]
	if not seconds or seconds <= 0 then
		return
	end
	local shape = cue.shape
	local s = state(cue.model)

	-- rain drops: each circle is its own cue and its own lead time
	if attack == "venomRain" and type(shape) == "table" and shape.kind == "circle" and seconds < 1.5 then
		rainDrop(cue, shape, seconds)
		return
	end
	-- the flurry's later strikes
	if attack == "fangFlurry" and s.attack == "fangFlurry" and cue.at - s.windupAt > 0.12 and cue.at - s.windupAt < 3 then
		flurryStrike(cue, shape, seconds)
		return
	end
	-- lanes or circles delivered together: collect, one tell
	if MULTI[attack] and s.attack == attack and math.abs(cue.at - s.windupAt) <= 0.12 then
		table.insert(s.shapes, shape)
		if attack == "venomPools" then
			lobPool(cue, shape, seconds)
		end
		return
	end
	if not current(cue, "windup") and attack ~= "venomRain" then
		return
	end
	if math.abs(s.windupAt - cue.at) <= EPSILON and s.attack == attack then
		return
	end
	cancelWindup(s)
	stopRidge(s)
	s.windupAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	s.attack = attack
	s.shapes = { shape }
	table.clear(s.seen)

	-- every windup: amber star flare on both eyes, tell parts toward hot amber
	for _, name in { "EyeL", "EyeR" } do
		local eye = part(cue, { name })
		if eye ~= cue.root then
			windupPlay(cue, "EyeFlare", eye.CFrame, { follow = eye, seconds = math.min(seconds, 0.6) })
		end
	end

	local mouthFrame, skull = point(cue, "Mouth", { "Skull" })
	if attack == "emerge" then
		local spot = ground(cue, root(cue).Position)
		windupPlay(cue, "EmergeBuild", CFrame.new(spot + Vector3.new(0, 0.05, 0)), { scale = 20, seconds = seconds })
		s.holdHidden = true
		tellRun(cue, withEyes({}), GOLD, seconds)
		hoodFlare(cue, seconds)
		refreshMode(cue)
	elseif attack == "venomFang" then
		windupPlay(cue, "FangTell", mouthFrame, { follow = skull, seconds = seconds })
		tellRun(cue, withEyes({ "FangTipL", "FangTipR" }), GOLD, seconds)
		hoodFlare(cue, seconds)
	elseif attack == "fangFlurry" then
		windupPlay(cue, "FangTell", mouthFrame, { follow = skull, seconds = seconds, boost = 1.4 })
		tellRun(cue, withEyes({ "FangTipL", "FangTipR" }), GOLD, seconds)
		hoodFlare(cue, seconds, true)
		flurryStrike(cue, shape, seconds)
	elseif attack == "tailSweep" then
		local frame, tip = point(cue, "TailTip_FX", { "Tail18" })
		windupPlay(cue, "TailTell", frame, { follow = tip, seconds = seconds })
		local center, radius = circleOf(shape, 13, cue)
		windupPlay(cue, "Marker", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { scale = radius, seconds = seconds })
		tellRun(cue, withEyes({ "TailTipGem" }), GOLD, seconds)
		hoodFlare(cue, seconds)
	elseif attack == "pillarSlam" then
		windupPlay(cue, "SlamTell", mouthFrame, { follow = skull, seconds = seconds })
		local center, radius = circleOf(shape, 6.5, cue)
		local spot = ground(cue, center) + Vector3.new(0, 0.05, 0)
		windupPlay(cue, "Marker", CFrame.new(spot), { scale = radius, seconds = seconds })
		windupPlay(cue, "GroundGather", CFrame.new(spot), { scale = math.max(5, radius * 1.1), seconds = seconds })
		tellRun(cue, withEyes({}), GOLD, seconds)
		hoodFlare(cue, seconds)
	elseif attack == "mireDive" then
		local frame = point(cue, "Dive_FX", { "Body" })
		local spot = ground(cue, frame.Position)
		windupPlay(cue, "GroundGather", CFrame.new(spot + Vector3.new(0, 0.05, 0)), { scale = 9, seconds = seconds })
		tellRun(cue, withEyes({}), GOLD, seconds)
		hoodFlare(cue, seconds)
	elseif attack == "erupt" then
		local center, radius = circleOf(shape, 7, cue)
		local spot = ground(cue, center) + Vector3.new(0, 0.05, 0)
		windupPlay(cue, "EmergeBuild", CFrame.new(spot), { scale = math.max(8, radius * 1.6), seconds = seconds })
		windupPlay(cue, "Marker", CFrame.new(spot), { scale = radius, seconds = seconds })
		s.holdHidden = false
	elseif attack == "venomLance" or attack == "venomSpray" or attack == "venomPools" then
		windupPlay(cue, "SpitGather", mouthFrame, { follow = skull, seconds = seconds, boost = if attack == "venomSpray" then 1.3 else 1 })
		tellRun(cue, withEyes({ "ThroatSac" }), GOLD, seconds, nil, 0.35, if attack == "venomSpray" then 3 else nil)
		if attack == "venomSpray" then
			hoodFlare(cue, seconds, true)
		else
			hoodFlare(cue, seconds)
		end
		if attack == "venomPools" then
			lobPool(cue, shape, seconds)
		end
	elseif attack == "jiaoCoil" then
		local center, radius = circleOf(shape, 9, cue)
		windupPlay(cue, "Marker", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { scale = radius, seconds = seconds })
		tellRun(cue, SEAMS, JADE, seconds, seconds * 0.08)
		tellRun(cue, withEyes({}), GOLD, seconds)
		local frame, tip = point(cue, "TailTip_FX", { "Tail18" })
		windupBeat(cue, seconds, 0.55, function()
			windupPlay(cue, "EyeFlare", frame, { follow = tip, tint = JADE, seconds = seconds * 0.4 })
		end)
	elseif attack == "dreadHiss" or attack == "molt" or attack == "ascension" or attack == "venomRain" then
		local jade = attack == "ascension" or attack == "venomRain"
		if attack == "venomRain" then
			windupPlay(cue, "RainGather", mouthFrame, { follow = skull, seconds = seconds })
		else
			windupPlay(cue, "RoarTell", mouthFrame, { follow = skull, seconds = seconds, tint = if jade then JADE else nil })
		end
		tellRun(cue, withEyes({ "ThroatSac" }), GOLD, seconds, nil, 0.25)
		hoodFlare(cue, seconds, true)
		if attack == "molt" or attack == "ascension" then
			-- shed skin: flakes and motes drifting off body parts
			shedAlong(cue, seconds, nil, true)
			-- the phase move reads on the floor too (no stock howl disc for
			-- bosses): mist and motes drawn in under the coils
			windupPlay(cue, "GroundGather", CFrame.new(ground(cue, root(cue).Position)), {
				scale = 14,
				seconds = seconds,
				tint = if attack == "ascension" then JADE else nil,
			})
		end
		if attack == "ascension" then
			-- a jade glow column gathering on the chest, rays standing up
			local frame, core = point(cue, "Core", { "Body" })
			windupPlay(cue, "RainGather", frame, { follow = core, seconds = seconds })
		end
	end
end

local function strikeWhip(cue: Cue, duration: number)
	local frame, tip = point(cue, "TailTip_FX", { "Tail18" })
	local trail = make("TailWhip", frame)
	if not trail then
		return
	end
	trail.Parent = TechniqueVFX.folder
	TechniqueVFX.enable(trail)
	local offset = tip.CFrame:ToObjectSpace(trail.CFrame)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not trail.Parent or not tip.Parent or os.clock() - started > duration then
			connection:Disconnect()
			TechniqueVFX.disable(trail)
			TechniqueVFX.cleanup(trail, 0.3)
		else
			trail.CFrame = tip.CFrame * offset
		end
	end)
end

local function emergeBurst(cue: Cue, position: Vector3, radius: number)
	local floor = ground(cue, position)
	play("EmergeBurst", CFrame.new(floor) * facing(cue), { scale = radius })
	-- venom mist bursting out of the hole, and a flare off the surfacing head
	play("HissBurst", CFrame.new(floor) * facing(cue), { scale = radius * 0.8 })
	local frame, skull = point(cue, "Mouth", { "Skull", "Head" })
	play("PhaseFlare", frame, { follow = skull, boost = 0.6 })
	flareAura(cue, 1.8)
	shake(0.55, position, radius + 140)
end

function Jiao.strike(cue: Cue)
	if not alive(cue) then
		return
	end
	local phase = cue.model:GetAttribute("AIState")
	if phase ~= "recover" and phase ~= "dash" then
		return
	end
	local s = state(cue.model)
	if math.abs(s.strikeAt - cue.at) <= EPSILON then
		return
	end
	local attack = cue.attack
	local shapes = s.shapes
	local shape = shapes[1]
	s.strikeAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	s.shapes = {}
	cancelWindup(s)
	-- a late phase packet can still arrive during the long recovery
	if workspace:GetServerTimeNow() - cue.at > 0.3 then
		return
	end
	local face = facing(cue)
	if attack == "emerge" then
		s.holdHidden = false
		refreshMode(cue)
		setHidden(cue, false, 0.05)
		showMound(cue, false)
		local center, _ = circleOf(shape, 1, cue)
		emergeBurst(cue, if shape then center else root(cue).Position, 20)
	elseif attack == "erupt" then
		s.holdHidden = false
		setHidden(cue, false, 0.05)
		local center, radius = circleOf(shape, 7, cue)
		stopRidge(s)
		emergeBurst(cue, center, math.max(8, radius * 1.6))
	elseif attack == "venomFang" then
		local frame = point(cue, "Mouth", { "Skull" })
		play("FangSnap", CFrame.new(frame.Position) * face)
		play("SpitRelease", CFrame.new(frame.Position) * face)
		shake(0.28, cue.root.Position, 70)
	elseif attack == "tailSweep" then
		local center, radius = circleOf(shape, 13, cue)
		play("SweepImpact", CFrame.new(ground(cue, center)) * face, { scale = radius })
		strikeWhip(cue, 0.7)
		shake(0.3, center, radius + 60)
	elseif attack == "pillarSlam" then
		local center, radius = circleOf(shape, 6.5, cue)
		play("SlamImpact", CFrame.new(ground(cue, center)) * face, { scale = radius })
		shake(0.36, center, radius + 60)
	elseif attack == "venomLance" or attack == "venomSpray" then
		fireLanes(cue, if #shapes > 0 then shapes else { shape })
		shake(0.14, cue.root.Position, 60)
	elseif attack == "dreadHiss" then
		local center, radius = circleOf(shape, 14, cue)
		local at = ground(cue, if shape then center else root(cue).Position)
		play("HissBurst", CFrame.new(at) * face, { scale = math.max(10, radius) })
		shake(0.3, at, radius + 60)
	elseif attack == "venomRain" then
		local frame = point(cue, "Mouth", { "Skull" })
		play("RainRelease", CFrame.lookAt(frame.Position, frame.Position + Vector3.new(0, 1, 0)))
		shake(0.25, cue.root.Position, 100)
	end
end

function Jiao.dash(cue: Cue)
	if not alive(cue) then
		return
	end
	local s = state(cue.model)
	if cue.attack == "mireDive" then
		local frame = point(cue, "Dive_FX", { "Body" })
		local spot = ground(cue, frame.Position)
		play("DiveBurst", CFrame.new(spot + Vector3.new(0, 0.05, 0)), { scale = 8 })
		setHidden(cue, true, 0.25)
		startRidge(cue)
		shake(0.22, spot, 90)
	end
end

function Jiao.land(cue: Cue)
	if not ours(cue) or cue.attack ~= "mireDive" then
		return
	end
	stopRidge(state(cue.model))
end

function Jiao.hit(cue: Cue)
	-- the hit remote can precede the replicated state change: accept a
	-- confirmed contact across the transition, but not a stale attack
	local grace = (WINDUP[cue.attack or ""] or 0) + 0.8
	if not ours(cue) or not current(cue, nil, grace) then
		return
	end
	local torso = torsoOf(cue.target)
	if not torso then
		return
	end
	local attack = cue.attack or ""
	local s = state(cue.model)
	-- a projectile stops on the first player it caught
	if attack == "venomLance" or attack == "venomSpray" then
		for _, bolt in table.clone(s.bolts) do
			if (bolt.position() - torso.Position).Magnitude < 40 then
				bolt.stop(torso.Position)
				break
			end
		end
	end
	local delta = root(cue).Position - torso.Position
	local toward = Vector3.new(delta.X, 0, delta.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(torso.Position + toward * 0.9, torso.Position + toward * 1.9)
	local name
	if attack == "venomFang" or attack == "fangFlurry" then
		name = "HitFang"
	elseif attack == "tailSweep" then
		name = "HitTail"
	elseif attack == "pillarSlam" or attack == "erupt" or attack == "jiaoCoil" or attack == "emerge" then
		name = "HitHeavy"
	else
		name = "HitVenom"
	end
	play(name, frame)
	if Players.LocalPlayer and cue.target == Players.LocalPlayer.Character then
		hurtShake(if attack == "pillarSlam" or attack == "jiaoCoil" then 0.26 elseif attack == "venomFang" or attack == "tailSweep" then 0.2 else 0.14)
	end
end

function Jiao.stagger(cue: Cue)
	if not alive(cue) then
		return
	end
	local s = state(cue.model)
	cancelWindup(s)
	s.shapes = {}
	stopRidge(s)
	s.latestAt = math.max(s.latestAt, cue.at)
	if s.holdHidden then
		s.holdHidden = false
		refreshMode(cue)
	end
	local frame, core = point(cue, "Core", { "Body" })
	play("PhaseFlare", frame, { follow = core, boost = 0.5 })
end

-- enemyCue handlers ---------------------------------------------------------------

function Jiao.phase(cue: Cue)
	if not alive(cue) then
		return
	end
	local s = state(cue.model)
	if os.clock() - s.roarAt < 4 then
		return
	end
	s.roarAt = os.clock()
	revealPhase(cue)
	local phase = cue.model:GetAttribute("Phase")
	local big = type(phase) == "number" and phase >= 3
	local at = ground(cue, root(cue).Position)
	local face = facing(cue)
	play("PhaseBurst", CFrame.new(at) * face, { boost = if big then 1.5 else 1, tint = nil })
	local frame, core = point(cue, "Core", { "Body" })
	play("PhaseFlare", frame, { follow = core, boost = if big then 1.6 else 1 })
	skyStream(cue, "Mouth", { "Skull", "Head" })
	if big then
		-- phase 3: spirit motes shed along the whole body, a second stream
		shedAlong(cue, 1.6, 1.5)
		task.delay(0.3, function()
			if cue.model.Parent then
				skyStream(cue, "Core", { "Body" })
			end
		end)
	end
	flareAura(cue, 3)
	shake(0.34, cue.root.Position, 140)
end

function Jiao.squeeze(cue: Cue)
	if not alive(cue) then
		return
	end
	local coil = state(cue.model).coil
	if not coil then
		return
	end
	play("CoilSqueeze", CFrame.new(coil.floor), { scale = coil.radius })
	for _, seg in coil.segments do
		if seg.Parent and seg.Transparency < 1 then
			seg.Color = WHITE
			TweenService:Create(seg, TweenInfo.new(0.3), { Color = JADE }):Play()
		end
	end
end

function Jiao.coilBreak(cue: Cue)
	if not ours(cue) then
		return
	end
	local coil = state(cue.model).coil
	if not coil then
		return
	end
	play("CoilBreak", CFrame.new(coil.floor), { scale = coil.radius })
	removeCoil(cue, true)
end

-- Death: a collapsing gather, then a white-out burst, a venom splash, rays and a
-- pillar, while jade motes and scale flakes shed off the whole body and a
-- spirit stream leaves the chest skyward.
function Jiao.death(cue: Cue)
	if not ours(cue) then
		return
	end
	local s = state(cue.model)
	if s.dead then
		return
	end
	s.dead = true
	cancelWindup(s)
	s.shapes = {}
	stopRidge(s)
	removeCoil(cue, true)
	showMound(cue, false)
	setHidden(cue, false, 0.1)
	applyAura(cue)
	local frame, core = point(cue, "Core", { "Body" })
	play("DeathBuild", frame, { follow = core, seconds = 0.9 })
	shedAlong(cue, 3.0, 1.6)
	local at = ground(cue, root(cue).Position)
	local face = facing(cue)
	task.delay(0.85, function()
		local live = if core.Parent then core.Position else frame.Position
		play("DeathBurst", CFrame.new(live))
		play("DeathSpirit", CFrame.new(at + Vector3.new(0, 0.05, 0)) * face, { scale = 22 })
		play("RainRelease", CFrame.lookAt(live, live + Vector3.new(0, 1, 0)))
		shake(0.4, live, 180)
	end)
end

return Jiao
