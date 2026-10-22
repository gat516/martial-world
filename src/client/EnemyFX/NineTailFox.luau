--!nonstrict
-- Testbed Nine-Tailed Fox boss only. Plays Effects.NineTailFox (built by
-- tools/vfx_specs/NineTailFox.luau): foxfire azure with a white-hot core in
-- phase 1, violet in phase 2, white-hot with a crimson edge in phase 3, a
-- slate base under every bright shape; lances and tail strikes are white-gold
-- streaks, the scream is pale blue-white. No crown, halo or head ring.
-- Cues: ready, aggro, windup, strike, dash, land, hit, stagger, death, and the
-- server's enemyCue "snare". Contracts: the fight sheet in
-- docs/systems/enemies.md (Nine-Tailed Fox).
--
-- No copies of the fox's body anywhere (user, 2026-10-21: the Neon ghost
-- heads, afterimages and death ghost looked bad): roars are thrown from the
-- jaws (RoarBreath), the intro kindles from the ground, the phase break
-- spirals up in ribbons, the death burns the body away (Dissolve) into nine
-- streams. Ribbons and lances ride the live TailTip{i}_FX of the real tails.
-- foxfireVolley's bolts are real projectiles drawn by the "foxfireBolt"
-- ProjectileView drawer at the bottom of this file.
-- Barrage attacks (fangDance, tailLance, lanceFan, tailSnare,
-- rootfireEruption, nineTailFall) schedule each part at
-- release + part.delay (release = the end of the windup); `part.ext` is the
-- seconds before that the tail starts extending. Shapes, lengths and radii are
-- always read from the cue (cue.shape / shape.parts / shape.trail), never
-- hardcoded, since the designer may retune them. Tails are followed through
-- TailTip{i}_FX, which rides the extending whip.
-- Weight (Impact kit, EnemyFX/Impact.luau): every rootfire eruption and tail
-- plunge lands with a foxfire shockwave, dust and a contact flash in the
-- phase's colour; the eruption's heart and NineTailFall's final burst add the
-- explosion and a fading scorched crack; the foxfire bolts explode where they
-- land.
-- Phone budget: cues past 220 studs are skipped (EnemyFX) and per-frame
-- follow work stops at the same distance.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local Impact = require(script.Parent.Impact)

local TEMPLATE = "NineTailFoxB"
local MAX_DISTANCE = 220
local EPSILON = 0.035
local WHITE = Color3.new(1, 1, 1)
local PALE = Color3.fromRGB(214, 238, 255)
local HOT = Color3.fromRGB(255, 236, 176)
local GOLD = Color3.fromRGB(255, 196, 90)
local SLATE = Color3.fromRGB(34, 42, 58)

-- phase palettes: bright-layer tint (core -> edge) and the body's Tell colours
local PHASES = {
	{ mid = Color3.fromRGB(190, 232, 255), edge = Color3.fromRGB(110, 200, 255), eye = Color3.fromRGB(127, 216, 255), lit = Color3.fromRGB(159, 228, 255), dim = Color3.fromRGB(70, 150, 215) },
	{ mid = Color3.fromRGB(205, 170, 255), edge = Color3.fromRGB(150, 90, 255), eye = Color3.fromRGB(176, 124, 255), lit = Color3.fromRGB(201, 160, 255), dim = Color3.fromRGB(125, 95, 200) },
	{ mid = Color3.fromRGB(250, 215, 235), edge = Color3.fromRGB(225, 60, 130), eye = Color3.fromRGB(255, 120, 180), lit = Color3.fromRGB(255, 240, 246), dim = Color3.fromRGB(190, 90, 140) },
}
-- which tails burn in each phase (the intro lights all nine in turn)
local LIT = { { 2, 5, 8 }, { 2, 3, 4, 5, 7, 8 }, { 1, 2, 3, 4, 5, 6, 7, 8, 9 } }
local GOLD_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, HOT), ColorSequenceKeypoint.new(1, GOLD) })
local PALE_SEQ = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(1, PALE) })

local WINDUP = {
	intro = 2.2, fangDance = 0.65, tailSweep = 0.9, tailLance = 0.6, lanceFan = 0.95, tailSnare = 0.85,
	rendingPounce = 0.75, foxfireVolley = 1.1, rootfireEruption = 1.5, moonLeap = 0.4,
	mournfulScream = 1.4, nineTailFall = 1.8, veilBreak = 1.6,
}
-- outer tails first, then inward (the volley's tips flare in turn)
local OUTSIDE_IN = { 1, 9, 2, 8, 3, 7, 4, 6, 5 }

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

local Fox = {}
local states = setmetatable({}, { __mode = "k" })

local function ours(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function state(model: Model)
	local s = states[model]
	if not s then
		s = {
			generation = 0,
			latestAt = -math.huge,
			windupAt = -math.huge,
			strikeAt = -math.huge,
			rushAt = -math.huge,
			landAt = -math.huge,
			snareAt = -math.huge,
			roarAt = -math.huge,
			dead = false,
			shape = nil,
			release = 0,
			windups = {}, -- instances destroyed when a windup is cancelled or released
			tells = {}, -- running Tell tweens
			tellBase = nil,
			stopRush = nil,
			aura = nil,
			phase = 0,
			flareUntil = 0,
			snareTail = 5,
			held = {}, -- longer effects stopped by a stagger or death (fire, stuck glow)
		}
		states[model] = s
	end
	return s
end

local function phaseOf(cue: Cue): number
	local p = cue.model:GetAttribute("Phase")
	return if type(p) == "number" then math.clamp(math.floor(p), 1, 3) else 1
end

local function phaseSeq(phase: number): ColorSequence
	local p = PHASES[phase]
	return ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.4, p.mid), ColorSequenceKeypoint.new(1, p.edge) })
end

-- The Impact kit's palette for a phase: the phase's foxfire over its slate base.
local function impactPalette(phase: number)
	local p = PHASES[phase]
	return { core = WHITE:Lerp(p.mid, 0.25), color = p.mid, dark = SLATE }
end

-- The cue is still the live one (King's generation check).
local function current(cue: Cue, phase: string?, contactGrace: number?): boolean
	if not ours(cue) or not cue.model.Parent or not cue.root.Parent then
		return false
	end
	local s = state(cue.model)
	local at = cue.model:GetAttribute("StateAt")
	local health = cue.model:GetAttribute("Health")
	if s.dead or cue.model:GetAttribute("FadeAt") ~= nil or (type(health) == "number" and health <= 0) then
		return false
	end
	local grace = contactGrace or EPSILON
	if cue.at + grace < s.latestAt or (type(at) == "number" and at > cue.at + grace) then
		return false
	end
	if cue.attack ~= cue.model:GetAttribute("Attack") then
		return false
	end
	return phase == nil or cue.model:GetAttribute("AIState") == phase
end

-- Still worth drawing: alive and within the phone cutoff. Used by every
-- scheduled beat and per-frame follower (they stop at the distance cutoff).
local function alive(cue: Cue): boolean
	if not ours(cue) or not cue.model.Parent or not cue.root.Parent then
		return false
	end
	local s = state(cue.model)
	local health = cue.model:GetAttribute("Health")
	if s.dead or cue.model:GetAttribute("FadeAt") ~= nil or (type(health) == "number" and health <= 0) then
		return false
	end
	local camera = workspace.CurrentCamera
	return not (camera and (cue.root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE)
end

local function body(model: Model): Instance
	return model:FindFirstChild("Body") or model
end

local function part(cue: Cue, names: { string }): BasePart
	for _, name in names do
		local found = body(cue.model):FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return cue.root
end

local function root(cue: Cue): BasePart
	return part(cue, { "HumanoidRootPart" })
end

local function facing(cue: Cue): CFrame
	return root(cue).CFrame.Rotation
end

-- (frame at the attachment with the fox's rotation, the part it rides)
local function point(cue: Cue, name: string, fallback: { string }): (CFrame, BasePart)
	local a = body(cue.model):FindFirstChild(name, true)
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

local function tip(cue: Cue, i: number): (CFrame, BasePart)
	return point(cue, `TailTip{i}_FX`, { `Tail{i}Whip`, `Tail{i}Tip`, `Tail{i}` })
end

local function ground(cue: Cue, position: Vector3): Vector3
	local exclude = { cue.model }
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
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else Vector3.new(position.X, cue.root.Position.Y - cue.root.Size.Y / 2, position.Z)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Templates ---------------------------------------------------------------

local function scaleSequence(sequence: NumberSequence, scale: number): NumberSequence
	local points = {}
	for _, key in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale))
	end
	return NumberSequence.new(points)
end

local function prepare(copy: BasePart, scale: number)
	if math.abs(scale - 1) < 1e-3 then
		return
	end
	copy.Size *= scale
	for _, d in copy:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position *= scale
		elseif d:IsA("ParticleEmitter") then
			d.Size = scaleSequence(d.Size, scale)
			d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
			d.Acceleration *= scale
		end
	end
end

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

-- Recolour the bright layers (not slate bases, not NoTint ones).
local function tint(copy: Instance, color: ColorSequence)
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.LightEmission > 0.3 and not d:GetAttribute("NoTint") then
			d.Color = color
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
	local folder = effects and effects:FindFirstChild("NineTailFox")
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

type Options = {
	scale: number?, -- ground templates: the live radius
	size: number?, -- other templates: a plain size multiplier
	follow: BasePart?,
	seconds: number?,
	tint: ColorSequence?,
	boost: number?,
	guard: (() -> boolean)?,
	hold: any?, -- a state to register in (destroyed on cancel)
}

local function make(name: string, frame: CFrame, o: Options?): BasePart?
	local base = template(name)
	if not base then
		return nil
	end
	local opts: Options = o or {}
	local copy = base:Clone()
	local scale = opts.size or 1
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
	copy.CFrame = frame
	return copy
end

local function play(name: string, frame: CFrame, o: Options?): BasePart?
	local copy = make(name, frame, o)
	if not copy then
		return nil
	end
	local opts: Options = o or {}
	copy.Parent = TechniqueVFX.folder
	local follow = opts.follow
	if follow then
		local offset = follow.CFrame:ToObjectSpace(copy.CFrame)
		local guard = opts.guard
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not copy.Parent then
				connection:Disconnect()
			elseif not follow.Parent or (guard and not guard()) then
				connection:Disconnect()
				copy:Destroy()
			else
				copy.CFrame = follow.CFrame * offset
			end
		end)
	end
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.3)
	return copy
end

-- State, cancelling and scheduling ----------------------------------------

local function destroyList(list)
	for _, item in list do
		if typeof(item) == "Instance" then
			item:Destroy()
		end
	end
	table.clear(list)
end

local function restoreTells(s)
	for _, tween in s.tells do
		tween:Cancel()
	end
	table.clear(s.tells)
	if s.tellBase then
		for p, color in s.tellBase do
			if p.Parent then
				p.Color = color
			end
		end
	end
end

-- Tells and held visuals of a windup end (the strike keeps scheduled beats).
local function clearTells(s)
	destroyList(s.windups)
	restoreTells(s)
end

-- A new windup, a stagger or a death: everything scheduled is void.
local function cancelWindup(s)
	s.generation += 1
	clearTells(s)
end

local function stopHeld(s)
	for _, stop in s.held do
		stop()
	end
	table.clear(s.held)
end

local function stopRush(s)
	if s.stopRush then
		s.stopRush()
	end
end

-- Run `fn` at server time `absolute` unless the attack was cancelled.
local function afterAbs(cue: Cue, absolute: number, fn: () -> ())
	local s = state(cue.model)
	local generation = s.generation
	local delay = math.max(0, absolute - workspace:GetServerTimeNow())
	task.delay(delay, function()
		if s.generation == generation and alive(cue) then
			fn()
		end
	end)
end

local function held(cue: Cue, name: string, frame: CFrame, o: Options?): BasePart?
	local s = state(cue.model)
	local generation = s.generation
	local opts: Options = table.clone(o or {})
	opts.guard = function()
		return s.generation == generation and alive(cue)
	end
	local effect = play(name, frame, opts)
	if effect then
		table.insert(s.windups, effect)
	end
	return effect
end

-- A per-frame driver that stops at the distance cutoff or a cancel. `always`
-- (the death) keeps driving after the fox is dead, while its model exists.
local function drive(cue: Cue, duration: number, step: (number) -> (), finish: (() -> ())?, cancelOnGeneration: boolean?, always: boolean?)
	local s = state(cue.model)
	local generation = s.generation
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - started) / duration
		local live = if always then cue.model.Parent ~= nil else alive(cue)
		local stop = a >= 1 or not live or (cancelOnGeneration and s.generation ~= generation)
		if stop then
			connection:Disconnect()
			if finish then
				finish()
			end
		else
			step(a)
		end
	end)
end

local function shake(amount: number, position: Vector3?, radius: number?)
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

local function torsoOf(character: Model?): BasePart?
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart"))
	return if torso and torso:IsA("BasePart") then torso else nil
end

-- The body: Tell parts, phase look ------------------------------------------

local function tellParts(cue: Cue): { BasePart }
	local list = {}
	for _, d in body(cue.model):GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Tell") then
			table.insert(list, d)
		end
	end
	return list
end

-- Phase 1 reads straight from the body's own TellBase (a saturated azure);
-- later phases recolour. Unlit tails and the thin whip lance are a lower
-- intensity of the same hue, never near-black.
local function tellColor(p: BasePart, phase: number): Color3
	local look = PHASES[phase]
	local base = p:GetAttribute("TellBase")
	local lit, dim
	if phase == 1 and typeof(base) == "Color3" then
		lit, dim = base, base:Lerp(Color3.new(), 0.3)
	else
		lit, dim = (if p:GetAttribute("TailIndex") then look.lit else look.eye), look.dim
	end
	local index = p:GetAttribute("TailIndex")
	if type(index) == "number" then
		if p.Name:sub(-4) == "Whip" then
			return dim
		end
		return if table.find(LIT[phase], index) then lit else dim
	end
	return lit
end

-- Recolour the Tell parts for a phase (instantly or over `fadeTime`).
local function paintTells(cue: Cue, phase: number, fadeTime: number)
	local s = state(cue.model)
	s.tellBase = s.tellBase or {}
	for _, p in tellParts(cue) do
		local color = tellColor(p, phase)
		s.tellBase[p] = color
		if fadeTime > 0 then
			TweenService:Create(p, TweenInfo.new(fadeTime), { Color = color }):Play()
		else
			p.Color = color
		end
	end
end

-- Every Tell part dims to half, then brightens until the blow lands.
local function tellPulse(cue: Cue, seconds: number)
	local s = state(cue.model)
	restoreTells(s)
	local phase = phaseOf(cue)
	if not s.tellBase then
		paintTells(cue, phase, 0)
	end
	for _, p in tellParts(cue) do
		local base = (s.tellBase and s.tellBase[p]) or p.Color
		p.Color = base:Lerp(Color3.new(), 0.35)
		local tween = TweenService:Create(p, TweenInfo.new(math.max(0.1, seconds), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = base:Lerp(WHITE, 0.65) })
		tween:Play()
		table.insert(s.tells, tween)
	end
end

local function tellsRestore(cue: Cue)
	local s = state(cue.model)
	for _, tween in s.tells do
		tween:Cancel()
	end
	table.clear(s.tells)
	if s.tellBase then
		for p, color in s.tellBase do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.3), { Color = color }):Play()
			end
		end
	end
end

local function eyeGlints(cue: Cue, seconds: number)
	for _, name in { "EyeL", "EyeR" } do
		local eye = part(cue, { name })
		if eye ~= cue.root then
			held(cue, "EyeGlint", eye.CFrame, { follow = eye, seconds = math.min(seconds, 0.6), tint = phaseSeq(phaseOf(cue)) })
		end
	end
end

-- Aura ----------------------------------------------------------------------

local function applyAura(cue: Cue)
	local s = state(cue.model)
	local aura = s.aura
	if not aura then
		return
	end
	local phase = phaseOf(cue)
	local litSet = LIT[phase]
	local flare = if os.clock() < s.flareUntil then 2.4 else 1
	local gutter = s.gutter or {}
	for _, item in aura.items do
		local e: ParticleEmitter = item.e
		if s.dead and not item.tail then
			e.Enabled = false
		elseif item.tail then
			local on = not gutter[item.tail]
			e.Enabled = on
			local lit = table.find(litSet, item.tail) ~= nil
			e.Rate = item.base * (if lit then 2.4 else 0.4) * flare * (if phase == 3 then 1.3 else 1)
			if item.name == "Flames" then
				e.Color = phaseSeq(phase)
			else
				e.Color = ColorSequence.new(PHASES[phase].mid)
			end
		elseif item.name == "Mist" then
			e.Rate = item.base * flare
		end
	end
end

local function mountAura(parent: BasePart, name: string, position: Vector3, templateName: string, items: { any }, tail: number?)
	local source = template(templateName)
	if not source then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = position
	a.Parent = parent
	for _, e in source:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = true
			c.Parent = a
			local base = e:GetAttribute("BaseRate")
			table.insert(items, { e = c, base = if type(base) == "number" then base else 0, name = e.Name, tail = tail })
		end
	end
end

local function startAura(cue: Cue)
	local s = state(cue.model)
	if s.aura or s.dead then
		return
	end
	local main = root(cue)
	local items = {}
	local feet = ground(cue, main.Position).Y - main.Position.Y + 0.2
	mountAura(main, "AuraGround", Vector3.new(0, feet, 0), "AuraGround", items)
	for i = 1, 9 do
		local a = body(cue.model):FindFirstChild(`TailTip{i}_FX`, true)
		if a and a:IsA("Attachment") and a.Parent and a.Parent:IsA("BasePart") then
			mountAura(a.Parent, `AuraTail{i}`, a.Position, "AuraTail", items, i)
		end
	end
	if #items == 0 then
		return
	end
	s.aura = { items = items }
	CollectionService:AddTag(cue.model, "CraterIgnore")
	applyAura(cue)
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

-- Sync the body and aura to the model's Phase (fade over `fadeTime`).
local function syncPhase(cue: Cue, fadeTime: number?)
	local s = state(cue.model)
	local phase = phaseOf(cue)
	if s.phase == phase then
		return
	end
	local first = s.phase == 0
	s.phase = phase
	paintTells(cue, phase, if first then 0 else (fadeTime or 0.6))
	applyAura(cue)
end

local function waitForBody(cue: Cue)
	for _ = 1, 20 do
		if body(cue.model) ~= cue.model and body(cue.model):FindFirstChild("Core", true) then
			return
		end
		task.wait(0.25)
	end
end

-- The roar, thrown from the jaws -------------------------------------------------

-- Sound rings, wisps, streaks and breath fired forward out of the Mouth (the
-- intro roar, the scream, the phase break). No copies of the fox's body: the
-- user rejected the Neon ghost and afterimage copies (2026-10-21).
local function roarBreath(cue: Cue, size: number, seq: ColorSequence)
	local mouth = point(cue, "Mouth", { "Head", "Snout" })
	local look = flat(root(cue).CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	-- aim a little down the line of the head, never into the sky
	play("RoarBreath", CFrame.lookAt(mouth.Position, mouth.Position + look - Vector3.new(0, 0.12, 0)), { size = size, tint = seq })
end

-- Ribbons, threads, lanes ------------------------------------------------------

local function tweenFrom(a: number): number
	return a * a * (3 - 2 * a)
end

-- A flying head with three trails behind it. `path(a)` gives its CFrame for
-- a = 0..1 over `duration`. o: width (studs; match it to what it rides: a
-- tail's lance is ~0.3, its flame ~1.2, its brush ~1.6), wide / core
-- (ColorSequence), tint, lifeScale (longer trails), always (keeps flying
-- through the death).
local function ribbon(cue: Cue, duration: number, path: (number) -> CFrame, o: any?)
	local base = template("Ribbon")
	if not base then
		return
	end
	local opts = o or {}
	local copy = base:Clone()
	local width = opts.width or 2
	local a0, a1 = copy:FindFirstChild("A0"), copy:FindFirstChild("A1")
	if a0 and a1 then
		a0.Position = Vector3.new(0, width / 2, 0)
		a1.Position = Vector3.new(0, -width / 2, 0)
	end
	local seq = opts.tint or phaseSeq(phaseOf(cue))
	tint(copy, seq)
	-- the head (glow, tongues, sparks) is authored for a 2-stud ribbon
	prepare(copy, math.clamp(width / 2, 0.4, 1.4))
	if a0 and a1 then
		a0.Position = Vector3.new(0, width / 2, 0)
		a1.Position = Vector3.new(0, -width / 2, 0)
	end
	local last = seq.Keypoints[#seq.Keypoints].Value
	local mid = seq.Keypoints[math.ceil(#seq.Keypoints / 2)].Value
	local trails = {}
	for _, t in copy:GetChildren() do
		if t:IsA("Trail") then
			if t.Name == "Wide" then
				t.Color = opts.wide or ColorSequence.new(mid, last)
			elseif t.Name == "Core" then
				t.Color = opts.core or ColorSequence.new(WHITE, mid)
			end
			t.Lifetime *= (opts.lifeScale or 1)
			table.insert(trails, t)
		end
	end
	copy.CFrame = path(0)
	copy.Parent = TechniqueVFX.folder
	for _, d in copy:GetDescendants() do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") then
			d.Enabled = true
		end
	end
	local function finish()
		for _, d in copy:GetDescendants() do
			if d:IsA("Trail") or d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
		task.delay(1.4 * (opts.lifeScale or 1), function()
			copy:Destroy()
		end)
	end
	drive(cue, duration, function(a)
		copy.CFrame = path(a)
	end, finish, false, opts.always)
end

-- Beams between two moving points (a thread of foxfire). `from` and `to`
-- return positions; the thread lives `duration` seconds. o: width scale,
-- tint, flat (a ground line), shrink (width falls to 0).
local function thread(cue: Cue, name: string, duration: number, from: () -> Vector3, to: () -> Vector3, o: any?): () -> ()
	local base = template(name)
	if not base then
		return function() end
	end
	local opts = o or {}
	local copy = base:Clone()
	local endPart = Instance.new("Part")
	endPart.Name = name .. "End"
	endPart.Anchored, endPart.CanCollide, endPart.CanQuery, endPart.CanTouch, endPart.CastShadow, endPart.Massless = true, false, false, false, false, true
	endPart.Transparency = 1
	endPart.Size = Vector3.new(0.2, 0.2, 0.2)
	local e = copy:FindFirstChild("End")
	local a = copy:FindFirstChild("A")
	local flatRot = CFrame.Angles(0, 0, math.pi / 2)
	if opts.flat and a and e then
		a.CFrame, e.CFrame = flatRot, flatRot
	end
	local seq = opts.tint or phaseSeq(phaseOf(cue))
	local beams = {}
	for _, b in copy:GetChildren() do
		if b:IsA("Beam") then
			table.insert(beams, { beam = b, w0 = b.Width0 * (opts.width or 1) })
			if b.Name == "Wide" then
				b.Color = ColorSequence.new(seq.Keypoints[2].Value, seq.Keypoints[#seq.Keypoints].Value)
			end
		end
	end
	copy.CFrame = CFrame.new(from())
	endPart.CFrame = CFrame.new(to())
	copy.Parent = TechniqueVFX.folder
	endPart.Parent = TechniqueVFX.folder
	if e then
		e.Parent = endPart
	end
	for _, item in beams do
		item.beam.Width0, item.beam.Width1 = item.w0, item.w0
		item.beam.Enabled = true
	end
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		copy:Destroy()
		endPart:Destroy()
	end
	drive(cue, duration, function(t)
		copy.CFrame = CFrame.new(from())
		endPart.CFrame = CFrame.new(to())
		if opts.shrink then
			for _, item in beams do
				local w = item.w0 * (1 - t * 0.85)
				item.beam.Width0, item.beam.Width1 = w, w
			end
		end
		if done then
			return
		end
	end, stop, false)
	return stop
end

-- A thin lit sigil line on the ground along a damage box, until `untilAbs`.
local function lane(cue: Cue, p: any, untilAbs: number, tintSeq: ColorSequence?)
	if type(p) ~= "table" or p.hidden or typeof(p.cframe) ~= "CFrame" or typeof(p.size) ~= "Vector2" then
		return
	end
	local s = state(cue.model)
	local cf: CFrame = p.cframe
	local length = p.size.Y
	local a = ground(cue, (cf * CFrame.new(0, 0, length / 2)).Position) + Vector3.new(0, 0.3, 0)
	local b = ground(cue, (cf * CFrame.new(0, 0, -length / 2)).Position) + Vector3.new(0, 0.3, 0)
	local duration = math.max(0.1, untilAbs - workspace:GetServerTimeNow() + 0.12)
	local stop = thread(cue, "Lane", duration, function()
		return a
	end, function()
		return b
	end, { flat = true, tint = tintSeq, width = math.clamp(p.size.X / 3, 0.6, 1.6) })
	table.insert(s.windups, { Destroy = stop })
end

-- A lance-length streak along a box from a tail tip (white-gold) with a
-- trailing ribbon, snapping at the far end.
local function boxEnds(p: any): (Vector3, Vector3)
	local cf: CFrame = p.cframe
	local length = p.size.Y
	return (cf * CFrame.new(0, 0, length / 2)).Position, (cf * CFrame.new(0, 0, -length / 2)).Position
end

-- Tail helpers ------------------------------------------------------------------

local function partsOf(shape: any): { any }
	if type(shape) == "table" and type(shape.parts) == "table" then
		return shape.parts
	end
	return {}
end

-- Glow along a whole tail (its sleeves) for `seconds`.
local function tailGlow(cue: Cue, i: number, seconds: number, seq: ColorSequence)
	local s = state(cue.model)
	local source = template("TailGlow")
	if not source then
		return
	end
	for _, suffix in { "Mid", "Tip" } do
		local sleeve = body(cue.model):FindFirstChild(`Tail{i}{suffix}`, true)
		if sleeve and sleeve:IsA("BasePart") then
			for _, e in source:GetChildren() do
				if e:IsA("ParticleEmitter") then
					local c = e:Clone()
					c.Color = seq
					c.Enabled = true
					c.Parent = sleeve
					table.insert(s.windups, c)
					task.delay(seconds, function()
						c.Enabled = false
						task.delay(1, function()
							c:Destroy()
						end)
					end)
				end
			end
		end
	end
end

local function tipCharge(cue: Cue, i: number, seconds: number, seq: ColorSequence, delay: number?)
	local function go()
		local frame, whip = tip(cue, i)
		held(cue, "TipCharge", frame, { follow = whip, seconds = math.max(0.15, seconds), tint = seq })
	end
	if delay and delay > 0 then
		afterAbs(cue, workspace:GetServerTimeNow() + delay, go)
	else
		go()
	end
end

-- A lance from tail `i` down a box, landing at `landAbs` (the hit time).
local function lanceStreak(cue: Cue, i: number, p: any, landAbs: number, ext: number, seq: ColorSequence, hitName: string?)
	local _, far = boxEnds(p)
	local endPoint = far + Vector3.new(0, 1.2, 0)
	local _, whip = tip(cue, i)
	afterAbs(cue, landAbs - ext, function()
		local startFrame = tip(cue, i)
		play("TailIgnite", startFrame, { follow = whip, tint = seq, size = 0.7 })
		local duration = math.max(0.08, ext)
		local started = os.clock()
		local function reach(): Vector3
			local a = math.clamp((os.clock() - started) / duration, 0, 1)
			return (tip(cue, i)).Position:Lerp(endPoint, tweenFrom(a))
		end
		-- the lance: a thin beam that leaves the live tail tip (it keeps riding
		-- the tail as the pose moves it) and runs down to the lane's end, held
		-- a beat past the hit; a small head of foxfire leads it
		thread(cue, "Thread", duration + 0.18, function()
			return (tip(cue, i)).Position
		end, reach, { tint = seq, width = 0.7 })
		ribbon(cue, duration, function()
			local pos = reach()
			local dir = endPoint - pos
			return if dir.Magnitude > 0.05 then CFrame.lookAt(pos, endPoint) else CFrame.new(pos)
		end, { width = 0.9, tint = seq, wide = ColorSequence.new(HOT, GOLD), core = ColorSequence.new(WHITE, HOT), lifeScale = 0.7 })
	end)
	afterAbs(cue, landAbs, function()
		play(hitName or "LanceHit", CFrame.new(endPoint) * facing(cue), { tint = seq })
		shake(0.1, endPoint, 40)
	end)
end

-- Windups ---------------------------------------------------------------------

local W = {}

function W.intro(cue: Cue, c)
	-- nine flames ignite one by one, the sigil blooms, the mist swells
	local pos = ground(cue, root(cue).Position) + Vector3.new(0, 0.05, 0)
	held(cue, "Sigil", CFrame.new(pos) * facing(cue), { scale = 10, seconds = c.seconds })
	local step = math.max(0.08, (c.seconds - 0.5) / 9)
	for i = 1, 9 do
		local at = c.now + 0.25 + (i - 1) * step
		afterAbs(cue, at, function()
			local frame, whip = tip(cue, i)
			play("TailIgnite", frame, { follow = whip, tint = phaseSeq(c.phase) })
			local state_ = state(cue.model)
			for p, base in state_.tellBase or {} do
				if p:GetAttribute("TailIndex") == i then
					p.Color = PHASES[c.phase].lit
					TweenService:Create(p, TweenInfo.new(0.4), { Color = base }):Play()
				end
			end
		end)
	end
	-- foxfire wakes in the ground round it and climbs (no body copy)
	held(cue, "Kindle", CFrame.new(pos) * facing(cue), { scale = 7, seconds = c.seconds, tint = phaseSeq(c.phase) })
end

function W.fangDance(cue: Cue, c)
	local frame, head = point(cue, "Mouth", { "Head", "Snout" })
	held(cue, "Breath", frame, { follow = head, seconds = c.seconds, tint = phaseSeq(c.phase) })
	for _, p in c.parts do
		if p.shape == "cone" or p.cframe then
			local delay = p.delay or 0
			afterAbs(cue, c.release + delay, function()
				local mouth = point(cue, "Mouth", { "Head", "Snout" })
				local look = if typeof(p.cframe) == "CFrame" then p.cframe.LookVector else root(cue).CFrame.LookVector
				play("FangSnap", CFrame.lookAt(mouth.Position, mouth.Position + look), { tint = phaseSeq(phaseOf(cue)) })
				shake(0.1, cue.root.Position, 50)
			end)
		end
	end
end

function W.tailSweep(cue: Cue, c)
	for _, i in { 2, 5, 8 } do
		tipCharge(cue, i, c.seconds, GOLD_SEQ)
		tailGlow(cue, i, c.seconds, GOLD_SEQ)
	end
end

function W.tailLance(cue: Cue, c)
	local p = c.parts[1]
	local tail = (p and p.tail) or 5
	tipCharge(cue, tail, c.seconds, GOLD_SEQ)
	tailGlow(cue, tail, c.seconds + (p and p.delay or 0), GOLD_SEQ)
	if p and p.cframe then
		local at = c.release + (p.delay or 0)
		lane(cue, p, at, GOLD_SEQ)
		lanceStreak(cue, tail, p, at, p.ext or 0.2, GOLD_SEQ)
	end
end

function W.lanceFan(cue: Cue, c)
	local started = {}
	for index, p in c.parts do
		local tail = p.tail or 5
		local at = c.release + (p.delay or 0)
		if not started[tail] then
			started[tail] = true
			tipCharge(cue, tail, math.max(0.2, at - c.now - 0.1), GOLD_SEQ)
		end
		if p.cframe then
			lane(cue, p, at, GOLD_SEQ)
			lanceStreak(cue, tail, p, at, p.ext or 0.2, GOLD_SEQ)
		end
	end
end

function W.tailSnare(cue: Cue, c)
	local s = state(cue.model)
	local p = c.parts[1]
	local tail = (p and p.tail) or 5
	s.snareTail = tail
	tipCharge(cue, tail, c.seconds, ColorSequence.new(WHITE, PALE))
	tailGlow(cue, tail, c.seconds, ColorSequence.new(WHITE, PALE))
	if p and p.cframe then
		local at = c.release + (p.delay or 0)
		local ext = p.ext or 0.2
		lane(cue, p, at, ColorSequence.new(WHITE, PALE))
		local near, far = boxEnds(p)
		afterAbs(cue, at - ext, function()
			local frame, whip = tip(cue, tail)
			local started = os.clock()
			local stop
			stop = thread(cue, "Thread", ext + 0.6, function()
				return (tip(cue, tail)).Position
			end, function()
				local a = math.clamp((os.clock() - started) / math.max(0.05, ext), 0, 1)
				return (tip(cue, tail)).Position:Lerp(far + Vector3.new(0, 1.4, 0), tweenFrom(a))
			end, { tint = ColorSequence.new(WHITE, PALE), width = 1 })
			table.insert(s.windups, { Destroy = stop })
			s.snareThread = stop
		end)
	end
end

function W.rendingPounce(cue: Cue, c)
	local frame, chest = point(cue, "Core", { "Chest" })
	held(cue, "Gather", frame, { follow = chest, seconds = c.seconds, scale = 4, tint = phaseSeq(c.phase) })
end

function W.foxfireVolley(cue: Cue, c)
	local seq = phaseSeq(c.phase)
	local tails = {}
	for _, p in c.parts do
		tails[p.tail or 5] = true
	end
	if next(tails) == nil then
		for i = 1, 9 do
			tails[i] = true
		end
	end
	local k = 0
	for _, i in OUTSIDE_IN do
		if tails[i] then
			tipCharge(cue, i, math.max(0.2, c.seconds - k * 0.07), seq, k * 0.07)
			k += 1
		end
	end
	-- the bolts themselves are real projectiles (cue "foxfireBolt", drawn by
	-- the ProjectileView drawer below); the red lanes are the server's
	-- warnLane, so nothing here marks the lanes or flies a bolt
end

local PLUNGE_TAILS = { 1, 3, 5, 7, 9 }

function W.rootfireEruption(cue: Cue, c)
	local s = state(cue.model)
	local seq = phaseSeq(c.phase)
	local plungeAt = c.now + c.seconds * 0.6
	local circles = {}
	for _, p in c.parts do
		if typeof(p.center) == "Vector3" then
			table.insert(circles, p)
		end
	end
	for _, i in PLUNGE_TAILS do
		tailGlow(cue, i, c.seconds * 0.6, seq)
	end
	-- the tails drive into the earth: an impact at each tip, then a vein crawls
	-- along the ground to the nearest circle, arriving as it erupts
	afterAbs(cue, plungeAt, function()
		local tipsGround = {}
		for _, i in PLUNGE_TAILS do
			local frame = tip(cue, i)
			local at = ground(cue, frame.Position)
			tipsGround[i] = at
			play("PlungeImpact", CFrame.new(at + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = 3.5, tint = phaseSeq(phaseOf(cue)) })
		end
		shake(0.14, cue.root.Position, 60)
		local used = {}
		for _, circle in circles do
			local best, bestD = nil, math.huge
			for _, i in PLUNGE_TAILS do
				local d = (flat(tipsGround[i]) - flat(circle.center)).Magnitude
				-- spread the veins across tips while still preferring the closest
				if not used[i] and d < bestD then
					best, bestD = i, d
				end
			end
			if not best then
				best = PLUNGE_TAILS[1]
			end
			used[best] = true
			local from = tipsGround[best] + Vector3.new(0, 0.5, 0)
			local to = ground(cue, circle.center) + Vector3.new(0, 0.5, 0)
			local arrive = c.release + (circle.delay or 0)
			local duration = math.max(0.25, arrive - workspace:GetServerTimeNow())
			local side = (to - from):Cross(Vector3.yAxis)
			side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
			ribbon(cue, duration, function(a)
				local wobble = math.sin(a * math.pi * 3) * 1.4 * (1 - a)
				local pos = from:Lerp(to, a) + side * wobble
				return CFrame.new(pos)
			end, { width = 1.4, tint = seq, lifeScale = 2.2 })
		end
	end)
	-- the buried tails glow through the punish window
	afterAbs(cue, c.release + 0.05, function()
		local mounted = {}
		local source = template("StuckGlow")
		if not source then
			return
		end
		local live = phaseSeq(phaseOf(cue))
		for _, i in PLUNGE_TAILS do
			local a = body(cue.model):FindFirstChild(`TailTip{i}_FX`, true)
			if a and a:IsA("Attachment") then
				local mount = Instance.new("Attachment")
				mount.Name = "StuckGlow"
				mount.Parent = a.Parent
				mount.Position = a.Position
				for _, e in source:GetChildren() do
					if e:IsA("ParticleEmitter") then
						local clone = e:Clone()
						clone.Color = live
						clone.Enabled = true
						clone.Parent = mount
					end
				end
				table.insert(mounted, mount)
			end
		end
		local function stop()
			for _, m in mounted do
				for _, e in m:GetChildren() do
					if e:IsA("ParticleEmitter") then
						e.Enabled = false
					end
				end
				task.delay(1.5, function()
					m:Destroy()
				end)
			end
			table.clear(mounted)
		end
		table.insert(s.held, stop)
		task.delay(0.85, stop)
	end)
	-- the eruptions themselves
	for _, circle in circles do
		local at = c.release + (circle.delay or 0)
		local heart = (circle.delay or 0) > 0.3
		afterAbs(cue, at, function()
			local pos = ground(cue, circle.center)
			local live = phaseSeq(phaseOf(cue))
			play("Eruption", CFrame.new(pos + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = circle.radius or 3.5, tint = live })
			local pal = impactPalette(phaseOf(cue))
			if heart then
				Impact.explode(pos, { radius = (circle.radius or 5) * 1.2, element = "fox", palette = pal, rocks = true, shake = 0.3, reach = 40 })
			else
				Impact.ground(pos, { radius = (circle.radius or 3.5) * 1.3, element = "fox", palette = pal, dust = 0.6, shake = 0.12, reach = 25 })
			end
			if heart then
				play("Burst", CFrame.new(pos + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = (circle.radius or 5) * 1.1, tint = live })
				shake(0.28, pos, 12)
			else
				shake(0.1, pos, 25)
			end
		end)
	end
end

function W.moonLeap(cue: Cue, c)
	local seq = phaseSeq(c.phase)
	for _, side in { "BL", "BR" } do
		local frame, paw = point(cue, `Paw{side}_FX`, { `PawB{side:sub(2)}`, "Chest" })
		held(cue, "Gather", frame, { follow = paw, seconds = c.seconds, scale = 2.4, tint = seq })
	end
end

function W.mournfulScream(cue: Cue, c)
	local frame, neck = point(cue, "Throat", { "Neck", "Chest" })
	held(cue, "ScreamTell", frame, { follow = neck, seconds = c.seconds })
	for _, i in LIT[c.phase] do
		local f, whip = tip(cue, i)
		held(cue, "TailFlare", f, { follow = whip, seconds = c.seconds, tint = phaseSeq(c.phase) })
	end
end

function W.nineTailFall(cue: Cue, c)
	local seq = phaseSeq(c.phase)
	local count = 0
	for _, p in c.parts do
		if typeof(p.center) == "Vector3" then
			count += 1
			local at = c.release + (p.delay or 0)
			local final = p.tail == nil or p.tail == 0
			local center = p.center
			-- the circle's sigil brightens until its own impact, staggered
			afterAbs(cue, c.now + 0.08 * count, function()
				local seconds = math.max(0.3, at - workspace:GetServerTimeNow())
				held(cue, "FallSigil", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { scale = p.radius or 5, seconds = seconds, tint = phaseSeq(phaseOf(cue)) })
			end)
			if not final then
				local tail = p.tail
				-- the tail rises with a growing white-violet pillar over it
				local frame, whip = tip(cue, tail)
				held(cue, "TailPillar", frame, { follow = whip, seconds = math.max(0.4, at - c.now - 0.1), tint = seq })
				afterAbs(cue, at - 0.05, function()
					local live = phaseSeq(phaseOf(cue))
					local tipFrame = tip(cue, tail)
					local pos = ground(cue, center)
					play("PlungeImpact", CFrame.new(ground(cue, tipFrame.Position) + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = 3.5, tint = live })
					task.delay(0.07, function()
						if cue.model.Parent then
							play("Eruption", CFrame.new(pos + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = p.radius or 5, tint = live })
							Impact.ground(pos, { radius = (p.radius or 5) * 1.2, element = "fox", palette = impactPalette(phaseOf(cue)), dust = 0.7, shake = 0.15, reach = 30 })
							shake(0.12, pos, 30)
						end
					end)
				end)
			else
				afterAbs(cue, at, function()
					local pos = ground(cue, center)
					play("FallBurst", CFrame.new(pos + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = p.radius or 14, tint = phaseSeq(phaseOf(cue)) })
					Impact.ground(pos, { radius = p.radius or 14, element = "fox", palette = impactPalette(phaseOf(cue)), burst = true, scar = true, rocks = true, shake = 0.55, reach = (p.radius or 14) + 60 })
					shake(0.45, pos, (p.radius or 14) + 45)
				end)
			end
		end
	end
end

function W.veilBreak(cue: Cue, c)
	local frame, chest = point(cue, "Core", { "Chest" })
	held(cue, "Gather", frame, { follow = chest, seconds = c.seconds, scale = 12, boost = 2, tint = phaseSeq(c.phase) })
	local pos = ground(cue, root(cue).Position) + Vector3.new(0, 0.05, 0)
	held(cue, "Sigil", CFrame.new(pos) * facing(cue), { scale = 7, seconds = c.seconds, tint = phaseSeq(c.phase) })
end

function Fox.windup(cue: Cue)
	if not ours(cue) or not current(cue, "windup") or not alive(cue) then
		return
	end
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack]
	if not seconds or seconds <= 0 then
		return
	end
	local s = state(cue.model)
	if math.abs(s.windupAt - cue.at) <= EPSILON then
		return
	end
	cancelWindup(s)
	stopRush(s)
	s.windupAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	s.shape = cue.shape
	syncPhase(cue, 0)
	local now = workspace:GetServerTimeNow()
	local c = {
		seconds = seconds,
		now = now,
		release = now + seconds,
		phase = phaseOf(cue),
		parts = partsOf(cue.shape),
		shape = cue.shape,
	}
	-- the moon leap's boxes ride the howl shape (shape.trail)
	if attack == "moonLeap" and type(cue.shape) == "table" and type(cue.shape.trail) == "table" then
		c.trail = cue.shape.trail
	end
	eyeGlints(cue, seconds)
	tellPulse(cue, seconds)
	local fn = W[attack]
	if fn then
		fn(cue, c)
	end
	s.release = c.release
end

-- Strikes -----------------------------------------------------------------------

local function takeOff(cue: Cue)
	local attack = cue.attack
	if attack ~= "rendingPounce" and attack ~= "moonLeap" then
		return
	end
	if not current(cue, "dash") or not alive(cue) then
		return
	end
	local s = state(cue.model)
	if math.abs(s.rushAt - cue.at) <= EPSILON then
		return
	end
	local seconds = cue.model:GetAttribute("DashSeconds")
	local duration = if type(seconds) == "number" then math.clamp(seconds, 0.05, 0.9) else (if attack == "moonLeap" then 0.6 else 0.4)
	local age = math.max(0, workspace:GetServerTimeNow() - cue.at)
	if age >= duration then
		return
	end
	cancelWindup(s)
	stopRush(s)
	s.rushAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	local seq = phaseSeq(phaseOf(cue))
	if age <= 0.2 then
		for _, side in { "BL", "BR" } do
			local frame = point(cue, `Paw{side}_FX`, { `PawB{side:sub(2)}`, "Chest" })
			local at = ground(cue, frame.Position) + Vector3.new(0, 0.08, 0)
			play("Dust", CFrame.new(at) * facing(cue), { scale = if attack == "moonLeap" then 3.5 else 3 })
		end
	end
	local frame, chest = point(cue, "Core", { "Chest" })
	local offset = chest.CFrame:ToObjectSpace(frame)
	local stopped = false
	local width = if attack == "moonLeap" then 3 else 2.4
	local template_ = template("Ribbon")
	if template_ then
		local copy = template_:Clone()
		local a0, a1 = copy:FindFirstChild("A0"), copy:FindFirstChild("A1")
		if a0 and a1 then
			a0.Position, a1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
		end
		tint(copy, if attack == "moonLeap" then seq else GOLD_SEQ)
		for _, t in copy:GetChildren() do
			if t:IsA("Trail") then
				if attack == "rendingPounce" then
					if t.Name == "Wide" then
						t.Color = ColorSequence.new(HOT, GOLD)
					elseif t.Name == "Core" then
						t.Color = ColorSequence.new(WHITE, HOT)
					end
				else
					t.Lifetime *= 1.6 -- the moon crescent lingers
					if t.Name == "Wide" then
						t.Color = ColorSequence.new(PHASES[phaseOf(cue)].mid, PHASES[phaseOf(cue)].edge)
					end
				end
			end
		end
		copy.CFrame = chest.CFrame * offset
		copy.Parent = TechniqueVFX.folder
		for _, d in copy:GetDescendants() do
			if d:IsA("Trail") or d:IsA("ParticleEmitter") then
				d.Enabled = true
			end
		end
		local connection: RBXScriptConnection
		local function stop()
			if stopped then
				return
			end
			stopped = true
			s.stopRush = nil
			connection:Disconnect()
			for _, d in copy:GetDescendants() do
				if d:IsA("Trail") or d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
			task.delay(1.6, function()
				copy:Destroy()
			end)
		end
		connection = RunService.RenderStepped:Connect(function()
			if not copy.Parent or not chest.Parent or not alive(cue) then
				stop()
			else
				copy.CFrame = chest.CFrame * offset
			end
		end)
		s.stopRush = stop
		task.delay(duration - age + 0.05, stop)
	end
end

-- The leap's fire trail along its damage boxes, igniting along the flight and
-- flaring on each tick.
local function igniteTrail(cue: Cue, trail: { any }, release: number)
	local s = state(cue.model)
	local source = template("FireStrip")
	if not source or #trail == 0 then
		return
	end
	local seq = phaseSeq(phaseOf(cue))
	local ticks = {}
	local strips = {}
	local lastTick = release + 1.5
	-- identical boxes listed once per damage tick are one strip with several ticks
	local unique = {}
	for _, p in trail do
		if typeof(p.cframe) == "CFrame" and typeof(p.size) == "Vector2" then
			local match
			for _, u in unique do
				if (u.cframe.Position - p.cframe.Position).Magnitude < 0.5 and (u.size - p.size).Magnitude < 0.5 then
					match = u
					break
				end
			end
			if match then
				if type(p.delay) == "number" then
					table.insert(ticks, release + p.delay)
					lastTick = math.max(lastTick, release + p.delay)
				end
			else
				table.insert(unique, p)
				if type(p.delay) == "number" then
					table.insert(ticks, release + p.delay)
					lastTick = math.max(lastTick, release + p.delay)
				end
			end
		end
	end
	for _, p in unique do
		do
			local cf: CFrame = p.cframe
			local length = p.size.Y
			local segments = math.max(1, math.ceil(length / 7))
			local segLength = length / segments
			for k = 1, segments do
				-- from the take-off end (+Z, the box's start) toward the landing
				local z = length / 2 - segLength * (k - 0.5)
				local centre = ground(cue, (cf * CFrame.new(0, 0, z)).Position)
				local strip = source:Clone()
				strip.Size = Vector3.new(p.size.X, 1, segLength)
				strip.CFrame = CFrame.new(centre + Vector3.new(0, 0.4, 0)) * cf.Rotation
				tint(strip, seq)
				for _, e in strip:GetChildren() do
					if e:IsA("ParticleEmitter") then
						local base = e:GetAttribute("BaseRate") or 0
						e:SetAttribute("BaseRate", base * segLength)
						e.Rate = 0
						e.Enabled = false
					end
				end
				strip.Parent = TechniqueVFX.folder
				table.insert(strips, { part = strip, order = k / segments })
			end
		end
	end
	if #ticks == 0 then
		ticks = { release + 0.5, release + 1.0, release + 1.5 }
	end
	local function rates(strip: BasePart, factor: number)
		for _, e in strip:GetChildren() do
			if e:IsA("ParticleEmitter") then
				local base = e:GetAttribute("BaseRate") or 0
				e.Rate = base * factor
				e.Enabled = factor > 0
			end
		end
	end
	local flight = 0.6
	for _, strip in strips do
		local at = release + strip.order * flight
		task.delay(math.max(0, at - workspace:GetServerTimeNow()), function()
			if strip.part.Parent and alive(cue) then
				rates(strip.part, 1)
			end
		end)
		for _, tick in ticks do
			task.delay(math.max(0, tick - workspace:GetServerTimeNow()), function()
				if strip.part.Parent and alive(cue) then
					rates(strip.part, 3.2)
					task.delay(0.25, function()
						if strip.part.Parent then
							rates(strip.part, 1)
						end
					end)
				end
			end)
		end
	end
	local function stop()
		for _, strip in strips do
			if strip.part.Parent then
				rates(strip.part, 0)
				task.delay(2.5, function()
					strip.part:Destroy()
				end)
			end
		end
		table.clear(strips)
	end
	table.insert(s.held, stop)
	task.delay(math.max(0.1, lastTick + 0.6 - workspace:GetServerTimeNow()), stop)
end

-- The pose of a roar: rings racing out on the ground, the roar thrown from
-- the jaws.
local function roarBurst(cue: Cue)
	local s = state(cue.model)
	if os.clock() - s.roarAt < 12 or s.dead then
		return
	end
	s.roarAt = os.clock()
	startAura(cue)
	local at = ground(cue, root(cue).Position)
	play("RoarWave", CFrame.new(at) * facing(cue), { tint = phaseSeq(phaseOf(cue)) })
	roarBreath(cue, 1.2, phaseSeq(phaseOf(cue)))
	flareAura(cue, 1.6)
	shake(0.3, cue.root.Position, 90)
end

local function shapeRadius(shape: any, default: number): number
	return if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else default
end

local function shapeCenter(shape: any, fallback: Vector3): Vector3
	return if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else fallback
end

local function sweepArc(cue: Cue, shape: any)
	local look = flat(root(cue).CFrame.LookVector)
	if type(shape) == "table" and typeof(shape.cframe) == "CFrame" then
		look = flat(shape.cframe.LookVector)
	end
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local centre = shapeCenter(shape, root(cue).Position)
	local radius = shapeRadius(shape, 20)
	local angle = if type(shape) == "table" and typeof(shape.size) == "Vector2" then shape.size.X else 200
	local half = math.rad(angle) / 2
	local base = math.atan2(-look.X, -look.Z)
	local floor = ground(cue, centre).Y
	-- the three sweeping tails (2, 5, 8) each draw a white-gold crescent from
	-- their own flame as the pose swings them, sized to the fur brush
	for index, i in { 2, 5, 8 } do
		task.delay((index - 1) * 0.02, function()
			if not alive(cue) then
				return
			end
			ribbon(cue, 0.34, function()
				return CFrame.new((tip(cue, i)).Position)
			end, { width = 1.6, tint = GOLD_SEQ, wide = ColorSequence.new(HOT, GOLD), core = ColorSequence.new(WHITE, HOT), lifeScale = 1.2 })
		end)
	end
	-- the ends of the arc kick dust
	for _, sign in { -1, 1 } do
		local theta = base + sign * half
		local pos = Vector3.new(centre.X - math.sin(theta) * radius * 0.9, floor, centre.Z - math.cos(theta) * radius * 0.9)
		task.delay(0.14 + (if sign > 0 then 0.14 else 0), function()
			if alive(cue) then
				play("Dust", CFrame.new(pos + Vector3.new(0, 0.08, 0)), { scale = 3.5 })
			end
		end)
	end
end

local function aggregateLate(cue: Cue): boolean
	return workspace:GetServerTimeNow() - cue.at > 0.3
end

local S = {}

function S.intro(cue: Cue)
	roarBurst(cue)
end

function S.tailSweep(cue: Cue, shape: any)
	sweepArc(cue, shape)
	for _, i in { 2, 5, 8 } do
		local frame, whip = tip(cue, i)
		play("TailIgnite", frame, { follow = whip, tint = GOLD_SEQ })
	end
	shake(0.18, cue.root.Position, 60)
end

function S.rendingPounce(cue: Cue)
	takeOff(cue)
end

function S.moonLeap(cue: Cue, shape: any)
	takeOff(cue)
	local trail = if type(shape) == "table" and type(shape.trail) == "table" then shape.trail else partsOf(shape)
	igniteTrail(cue, trail, workspace:GetServerTimeNow())
end

function S.mournfulScream(cue: Cue, shape: any)
	local at = ground(cue, root(cue).Position)
	local radius = shapeRadius(shape, 22)
	play("ScreamWave", CFrame.new(at + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = radius })
	flareAura(cue, 1.4)
	roarBreath(cue, 1.5, PALE_SEQ)
	shake(0.35, cue.root.Position, 25)
	-- the server fires no hit for a damage-0 attack: sting the local character
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local torso = torsoOf(character)
	if torso and (flat(torso.Position) - flat(cue.root.Position)).Magnitude <= radius then
		play("StunSting", CFrame.new(torso.Position), { follow = torso, guard = function()
			return character and character.Parent ~= nil
		end })
	end
end

function S.veilBreak(cue: Cue)
	local s = state(cue.model)
	-- Phase is written at this very release: wait a beat for it
	local old = s.phase
	for _ = 1, 8 do
		if phaseOf(cue) ~= old then
			break
		end
		task.wait(0.04)
	end
	local phase = phaseOf(cue)
	local seq = phaseSeq(phase)
	local at = ground(cue, root(cue).Position)
	local radius = shapeRadius(s.shapeAtRelease, 10)
	play("PhaseBurst", CFrame.new(at + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = radius, tint = seq })
	play("Sigil", CFrame.new(at + Vector3.new(0, 0.05, 0)) * facing(cue), { scale = radius * 1.1, tint = seq })
	local frame, chest = point(cue, "Core", { "Chest" })
	play("SpiritGlint", frame, { follow = chest, tint = seq })
	roarBreath(cue, 1.4, seq)
	-- the veil tears: foxfire spirals up round the fox (three strands, five
	-- in the last phase) and bursts as one star over it
	local base = ground(cue, root(cue).Position)
	local apex = base + Vector3.new(0, 19, 0)
	local strands = if phase >= 3 then 5 else 3
	local rise = 0.85
	for k = 1, strands do
		local a0 = (k - 1) / strands * math.pi * 2
		ribbon(cue, rise, function(a)
			local t = tweenFrom(a)
			local r = radius * 0.75 * (1 - t) + 1.2 * t
			local theta = a0 + t * math.pi * 2.2
			return CFrame.new(base + Vector3.new(math.cos(theta) * r, 1 + t * 18, math.sin(theta) * r))
		end, { width = 1.4, tint = seq, lifeScale = 1.6 })
	end
	task.delay(rise, function()
		if alive(cue) then
			play("SpiritGlint", CFrame.new(apex), { tint = seq })
			play("SoulRelease", CFrame.new(apex), { tint = seq, size = 0.8 })
		end
	end)
	-- the tails re-ignite for the new phase (colour crossfades over 0.6 s)
	s.phase = old
	syncPhase(cue, 0.6)
	local k = 0
	for _, i in LIT[phase] do
		if not table.find(LIT[math.max(1, phase - 1)], i) or phase == 1 then
			k += 1
			task.delay(0.08 * k, function()
				if alive(cue) then
					local f, whip = tip(cue, i)
					play("TailIgnite", f, { follow = whip, tint = seq })
				end
			end)
		end
	end
	flareAura(cue, 3)
	shake(0.4, cue.root.Position, 80)
end

function Fox.strike(cue: Cue)
	if not ours(cue) or not current(cue) or not alive(cue) then
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
	s.strikeAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	local shape = s.shape
	s.shape = nil
	s.shapeAtRelease = shape
	clearTells(s)
	tellsRestore(cue)
	if not (cue.attack == "rendingPounce" or cue.attack == "moonLeap") and aggregateLate(cue) then
		return
	end
	local fn = S[cue.attack or ""]
	if fn then
		fn(cue, shape)
	end
end

function Fox.dash(cue: Cue)
	if not ours(cue) then
		return
	end
	takeOff(cue)
end

function Fox.land(cue: Cue)
	if not ours(cue) or not current(cue) or not alive(cue) then
		return
	end
	local attack = cue.attack
	if attack ~= "rendingPounce" and attack ~= "moonLeap" then
		return
	end
	local s = state(cue.model)
	stopRush(s)
	if cue.model:GetAttribute("AIState") ~= "recover" or math.abs(s.landAt - cue.at) <= EPSILON then
		return
	end
	s.landAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	local left, right = point(cue, "PawFL_FX", { "PawFL", "Chest" }), point(cue, "PawFR_FX", { "PawFR", "Chest" })
	local centre = ground(cue, (left.Position + right.Position) / 2) + Vector3.new(0, 0.08, 0)
	if attack == "moonLeap" then
		play("Landing", CFrame.new(centre) * facing(cue), { scale = 6, tint = phaseSeq(phaseOf(cue)) })
		shake(0.2, cue.root.Position, 60)
	else
		play("Dust", CFrame.new(centre) * facing(cue), { scale = 4.5 })
		play("Dust", CFrame.new(centre) * facing(cue) * CFrame.new(0, 0, -2), { scale = 3 })
		shake(0.16, cue.root.Position, 50)
	end
end

-- Hit, snare, stagger, death ----------------------------------------------------------

local LANCE_FAMILY = { tailLance = true, lanceFan = true, tailSnare = true }
local PHASE_FAMILY = { foxfireVolley = true, rootfireEruption = true, nineTailFall = true }

function Fox.hit(cue: Cue)
	if not ours(cue) or not cue.model.Parent or not alive(cue) then
		return
	end
	local target = cue.target
	local torso = torsoOf(target)
	if not torso then
		return
	end
	local delta = root(cue).Position - torso.Position
	local toward = flat(delta)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(torso.Position + toward * 0.9, torso.Position + toward * 1.9)
	local attack = cue.attack or ""
	if LANCE_FAMILY[attack] then
		play("Hit", frame, { tint = GOLD_SEQ })
	elseif attack == "tailSweep" or attack == "rendingPounce" then
		play("HitHeavy", frame, { tint = GOLD_SEQ })
	elseif PHASE_FAMILY[attack] or attack == "moonLeap" then
		play("HitHeavy", frame, { tint = phaseSeq(phaseOf(cue)) })
	else
		play("Hit", frame, { tint = phaseSeq(phaseOf(cue)) })
	end
	if Players.LocalPlayer and target == Players.LocalPlayer.Character then
		hurtShake(if attack == "nineTailFall" then 0.26 elseif attack == "tailSweep" or attack == "rootfireEruption" then 0.2 else 0.14)
	end
end

-- The server's pull began: a ribbon coils round the torso while a thread
-- tethers it to the tail tip, shrinking as it pulls; a flash on arrival.
function Fox.snare(cue: Cue)
	if not ours(cue) or not alive(cue) then
		return
	end
	local s = state(cue.model)
	if math.abs(s.snareAt - workspace:GetServerTimeNow()) <= 0.1 then
		return
	end
	s.snareAt = workspace:GetServerTimeNow()
	local torso = torsoOf(cue.target)
	if not torso then
		return
	end
	if s.snareThread then
		s.snareThread()
		s.snareThread = nil
	end
	local tail = s.snareTail or 5
	local white = ColorSequence.new(WHITE, PALE)
	local duration = 0.45
	local started = os.clock()
	thread(cue, "Thread", duration, function()
		return (tip(cue, tail)).Position
	end, function()
		return torso.Position
	end, { tint = white, width = 1.4, shrink = true })
	ribbon(cue, duration, function(a)
		local turns = a * math.pi * 2 * 3
		local r = 2.2 * (1 - a * 0.6)
		local c = torso.Position
		return CFrame.new(c + Vector3.new(math.cos(turns) * r, 1.2 - a * 2.4, math.sin(turns) * r))
	end, { width = 0.9, tint = white, wide = ColorSequence.new(WHITE, PALE), core = ColorSequence.new(WHITE, WHITE), lifeScale = 1.4 })
	task.delay(duration, function()
		if torso.Parent then
			play("Hit", CFrame.new(torso.Position), { tint = white })
		end
	end)
end

function Fox.stagger(cue: Cue)
	if not ours(cue) or not current(cue, "stagger") then
		return
	end
	local s = state(cue.model)
	cancelWindup(s)
	stopHeld(s)
	s.shape = nil
	stopRush(s)
	s.latestAt = math.max(s.latestAt, cue.at)
	tellsRestore(cue)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("SpiritGlint", frame, { follow = chest, boost = 0.5, size = 0.6, tint = phaseSeq(phaseOf(cue)) })
end

function Fox.ready(cue: Cue)
	if not ours(cue) then
		return
	end
	waitForBody(cue)
	if not alive(cue) then
		return
	end
	syncPhase(cue, 0)
	startAura(cue)
end

function Fox.aggro(cue: Cue)
	if not ours(cue) then
		return
	end
	syncPhase(cue, 0)
	startAura(cue)
end

-- One foxfire stream leaving a guttered tail: it lifts off the flame, curls
-- once round the fox's axis and meets the others at `apex`.
local STREAM_RISE = 1.1
local function soulStream(cue: Cue, i: number, from: Vector3, apex: Vector3, seq: ColorSequence)
	local out = flat(from - apex)
	local r0 = math.max(2, out.Magnitude)
	local a0 = math.atan2(out.Z, out.X)
	local spin = if i % 2 == 0 then 1 else -1
	ribbon(cue, STREAM_RISE, function(a)
		local t = 1 - (1 - a) ^ 2
		local theta = a0 + spin * t * math.pi * 0.9
		local r = r0 * (1 - t) ^ 1.4
		local y = from.Y + (apex.Y - from.Y) * (t ^ 0.8)
		return CFrame.new(Vector3.new(apex.X + math.cos(theta) * r, y, apex.Z + math.sin(theta) * r))
	end, { width = 1.1, tint = seq, lifeScale = 1.5, always = true })
end

-- Death: the flames gutter out one by one (tails 1..9) and each one leaves its
-- tail as a foxfire stream that curls up over the fox, while the body burns
-- away into rising flames and motes (Dissolve). The nine streams meet over it
-- and the spirit core breaks free there (SpiritGlint + SoulRelease). No copy
-- of the body: the old Neon ghost fox was rejected (user, 2026-10-21).
function Fox.death(cue: Cue)
	if not ours(cue) then
		return
	end
	local s = state(cue.model)
	if s.dead then
		return
	end
	s.dead = true
	cancelWindup(s)
	stopHeld(s)
	s.shape = nil
	stopRush(s)
	tellsRestore(cue)
	local phase = phaseOf(cue)
	local seq = phaseSeq(phase)
	s.gutter = {}
	applyAura(cue)
	-- aura emitters stay (applyAura turns the ground ones off) until each tail gutters
	for _, item in (s.aura and s.aura.items) or {} do
		item.e.Enabled = item.tail ~= nil
	end
	local main = root(cue)
	local apex = main.Position + Vector3.new(0, 15, 0)
	play("Dissolve", main.CFrame, { follow = main, tint = seq, guard = function()
		return cue.model.Parent ~= nil
	end })
	for i = 1, 9 do
		task.delay(0.2 * (i - 1), function()
			s.gutter[i] = true
			for _, item in (s.aura and s.aura.items) or {} do
				if item.tail == i then
					item.e.Enabled = false
				end
			end
			for p, _ in s.tellBase or {} do
				if p.Parent and p:GetAttribute("TailIndex") == i then
					TweenService:Create(p, TweenInfo.new(0.35), { Color = (s.tellBase[p] or p.Color):Lerp(Color3.new(), 0.5) }):Play()
				end
			end
			local frame, whip = tip(cue, i)
			if cue.model.Parent then
				play("TailIgnite", frame, { follow = whip, boost = 0.4, size = 0.6, tint = seq })
				soulStream(cue, i, frame.Position, apex, seq)
			end
		end)
	end
	-- the last stream arrives at 1.6 + STREAM_RISE: the core breaks free there
	task.delay(1.6 + STREAM_RISE, function()
		play("SpiritGlint", CFrame.new(apex), { tint = seq })
		play("SoulRelease", CFrame.new(apex), { tint = seq })
		shake(0.3, apex, 120)
	end)
end

-- Foxfire bolts (foxfireVolley) ------------------------------------------------
-- The volley's bolts are real projectiles (server Projectiles, cue
-- "foxfireBolt", data = { tail, phase }); ProjectileView flies them and calls
-- this drawer. In flight the bolt is the warning, so it is the brightest thing
-- the fox throws: the Bolt template (core over a slate halo, star, flipbook
-- flames, a comet tail of trails) with its Shadow on the ground beneath it.

local BOLT_WIDTH = 1.7
local BOLT_EASE = 0.15

local function ownerCue(owner: Model?): Cue?
	if not owner or not owner.Parent or owner:GetAttribute("Template") ~= TEMPLATE then
		return nil
	end
	local found = (owner:FindFirstChild("Body") or owner):FindFirstChild("HumanoidRootPart", true)
	local main = if found and found:IsA("BasePart") then found else owner.PrimaryPart
	if not main then
		return nil
	end
	return { model = owner, root = main, kind = "projectile", at = workspace:GetServerTimeNow() }
end

local function boltPhase(shot: any): number
	local data = shot.data or {}
	local phase = data.phase
	if type(phase) ~= "number" and shot.owner then
		phase = shot.owner:GetAttribute("Phase")
	end
	return if type(phase) == "number" then math.clamp(math.floor(phase), 1, 3) else 1
end

local function floorUnder(shot: any, position: Vector3, depth: number): Vector3?
	local exclude = { TechniqueVFX.folder }
	if shot.owner then
		table.insert(exclude, shot.owner)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -depth, 0), params)
	return hit and hit.Position
end

local function boltStart(shot: any)
	local camera = workspace.CurrentCamera
	local origin = shot.state.position
	if camera and (origin - camera.CFrame.Position).Magnitude > MAX_DISTANCE + 60 then
		return
	end
	local base = template("Bolt")
	if not base then
		return
	end
	local seq = phaseSeq(boltPhase(shot))
	local copy = base:Clone()
	tint(copy, seq)
	local a0, a1 = copy:FindFirstChild("A0"), copy:FindFirstChild("A1")
	if a0 and a1 then
		a0.Position, a1.Position = Vector3.new(0, BOLT_WIDTH / 2, 0), Vector3.new(0, -BOLT_WIDTH / 2, 0)
	end
	local mid, edge = seq.Keypoints[2].Value, seq.Keypoints[#seq.Keypoints].Value
	for _, t in copy:GetChildren() do
		if t:IsA("Trail") then
			if t.Name == "Wide" then
				t.Color = ColorSequence.new(mid, edge)
			elseif t.Name == "Core" then
				t.Color = ColorSequence.new(WHITE, mid)
			end
		end
	end
	copy.CFrame = CFrame.new(origin)
	copy.Parent = TechniqueVFX.folder
	for _, d in copy:GetDescendants() do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") then
			d.Enabled = true
		end
	end
	shot.visual = copy
	shot.boltBorn = os.clock()
	-- the tail it leaves flares as it fires; the bolt is drawn leaving that
	-- flame and eases onto the server's path (which starts at torso height
	-- ahead of the fox) over BOLT_EASE
	local cue = ownerCue(shot.owner)
	local data = shot.data or {}
	if cue and type(data.tail) == "number" then
		local frame, whip = tip(cue, data.tail)
		shot.boltFrom = frame.Position
		copy.CFrame = CFrame.new(frame.Position)
		play("TailIgnite", frame, { follow = whip, tint = seq, size = 0.8 })
	end
end

local function boltStep(shot: any, position: Vector3, velocity: Vector3)
	local copy = shot.visual
	if typeof(copy) ~= "Instance" or not copy.Parent then
		return
	end
	local from = shot.boltFrom
	local age = os.clock() - (shot.boltBorn or 0)
	if typeof(from) == "Vector3" and age < BOLT_EASE then
		local k = age / BOLT_EASE
		position = from:Lerp(position, k * k * (3 - 2 * k))
	end
	copy.CFrame = if velocity.Magnitude > 0.1 then CFrame.lookAt(position, position + velocity) else CFrame.new(position)
	local shadow = copy:FindFirstChild("Shadow")
	if shadow and shadow:IsA("BasePart") then
		local floor = floorUnder(shot, position, 40)
		for _, e in shadow:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = floor ~= nil
			end
		end
		if floor then
			shadow.CFrame = CFrame.new(floor + Vector3.new(0, 0.12, 0))
		end
	end
end

local function boltFinish(shot: any, position: Vector3, reason: string)
	local copy = shot.visual
	shot.visual = nil
	if typeof(copy) == "Instance" then
		for _, d in copy:GetDescendants() do
			if d:IsA("Trail") or d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
		task.delay(0.7, function()
			copy:Destroy()
		end)
	end
	if reason == "cancel" or reason == "owner" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local seq = phaseSeq(boltPhase(shot))
	local floor = floorUnder(shot, position, 8)
	if floor then
		play("Burst", CFrame.new(floor + Vector3.new(0, 0.05, 0)), { scale = 2.6, tint = seq })
		Impact.explode(floor, { radius = 3.5, element = "fox", palette = impactPalette(boltPhase(shot)), dust = 0.5, shake = 0.1, reach = 30 })
	end
	if not floor and reason ~= "hit" then
		-- ended in the air (the enemy "hit" cue draws the burst on a player)
		play("Hit", CFrame.new(position), { tint = seq, size = 0.9 })
	end
	shake(0.08, position, 30)
end

do
	local module = script.Parent.Parent:FindFirstChild("ProjectileView")
	if module and module:IsA("ModuleScript") then
		local ok, view = pcall(require, module)
		if ok and type(view) == "table" and type((view :: any).register) == "function" then
			(view :: any).register("foxfireBolt", { start = boltStart, step = boltStep, finish = boltFinish })
		end
	end
end
-- exposed for previews (a sandbox flies a fake shot through it)
Fox.boltDrawer = { start = boltStart, step = boltStep, finish = boltFinish }

return Fox
