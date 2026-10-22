--!strict
-- Testbed Elder Wolf King only. Plays the King's own templates,
-- Effects.ElderWolfKing (built by tools/vfx_specs/ElderWolfKing.luau, whose
-- header holds each move's intent, beat sheet and layer sheet), and their
-- sounds, SoundService.SFX.Enemies.ElderWolfKing.<Name> (Sfx.play, at the
-- peak, from where the cause is). Moon-silver qi on ink and slate; gold only in
-- the first-frame tells (eyes, raised claws). No copy of the body is ever
-- drawn, and nothing redraws the telegraph's danger area.
-- Cues: ready (aura on), aggro, windup, strike, dash, land, skid, hit,
-- stagger, death. Health drives the aura's intensity.
--
-- Contact is `strike` (windup -> recover), not the end of active/recovery.
-- Rush shares `strike`/`dash`, and ends on `land`. `seconds` is already the
-- remaining windup; cue.at/StateAt and a generation cancel interrupted cues.
-- Every effect layer comes from these templates (the shared Impact kit is not
-- layered on top any more: its generic rings doubled the King's own impacts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CollectionService = game:GetService("CollectionService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local Sfx = require(script.Parent.Parent.Sfx)

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

type State = {
	generation: number,
	latestAt: number,
	windupAt: number,
	strikeAt: number,
	rushAt: number,
	landAt: number,
	dead: boolean,
	shape: any?,
	windups: { BasePart },
	stopRush: (() -> ())?,
	aura: any?,
	roarAt: number,
	flareUntil: number,
	leapShape: any?,
	stopCharge: (() -> ())?,
}

local TEMPLATE = "ElderWolfKingB"
local WHITE = Color3.new(1, 1, 1)
local MOON = Color3.fromRGB(226, 236, 250)
local RIM = Color3.fromRGB(150, 178, 222)
local GOLD = Color3.fromRGB(255, 200, 96)
local HOT = Color3.fromRGB(255, 236, 176)
local SOUNDS = "Enemies/ElderWolfKing/"
local EPSILON = 0.035
local WINDUP = {
	royalBite = 0.90,
	kingsRush = 1.00,
	crownfall = 1.25,
	pawSwipe = 0.45,
	kingLeap = 1.6,
	kingRake = 0.45,
	clawDown = 0.55,
	packCall = 1.20,
	roar = 1.00,
}

local King = {}
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
			rushAt = -math.huge,
			landAt = -math.huge,
			dead = false,
			shape = nil,
			windups = {},
			stopRush = nil,
			aura = nil,
			roarAt = -math.huge,
			flareUntil = 0,
		}
		states[model] = s
	end
	return s
end

-- Ignore a queued task once a newer state/attack has superseded its cue.
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
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -36, 0), params)
	return if hit then hit.Position else Vector3.new(position.X, cue.root.Position.Y - cue.root.Size.Y / 2, position.Z)
end

local function scaleSequence(sequence: NumberSequence, scale: number): NumberSequence
	local points = {}
	for _, key in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale))
	end
	return NumberSequence.new(points)
end

-- Templates are authored at the King's size; ground shapes carry an
-- AuthoredRadius and are scaled to the live circle. Emit attributes, tags and
-- textures survive on the runtime clone.
local function scaleV(d: Instance, key: string, scale: number)
	local v = d:GetAttribute(key)
	if typeof(v) == "Vector3" then
		d:SetAttribute(key, v * scale)
	end
end

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
		elseif d:IsA("Model") and d:GetAttribute("MeshWave") then
			-- 3D shock rings: sizes and travel are studs
			for _, key in { "FromSize", "ToSize", "FromOffset", "ToOffset" } do
				scaleV(d, key, scale)
			end
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

-- Recolour the bright layers (not the ink and slate bases) of a clone.
local function tint(copy: BasePart, color: Color3)
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.LightEmission > 0.3 then
			d.Color = ColorSequence.new(WHITE, color)
		end
	end
end

-- More (or fewer) particles for the second Pack Call.
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
	local folder = effects and effects:FindFirstChild("ElderWolfKing")
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

-- `radius` (if given) is the live circle's radius for a ground template.
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

local function cancelWindup(s: State)
	s.generation += 1
	if s.stopCharge then
		s.stopCharge()
		s.stopCharge = nil
	end
	for _, effect in s.windups do
		effect:Destroy()
	end
	table.clear(s.windups)
end

local function stopRush(s: State)
	if s.stopRush then
		s.stopRush()
	end
end

local function windupPlay(cue: Cue, name: string, frame: CFrame, o: Options?)
	local s = state(cue.model)
	local generation = s.generation
	local opts: Options = table.clone(o or {}) :: any
	opts.guard = function()
		return s.generation == generation and current(cue, "windup")
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
		if s.generation == generation and current(cue, "windup") then
			action()
		end
	end)
end

local function pawGround(cue: Cue, side: string): CFrame
	local frame = point(cue, "Paw" .. side .. "_FX", { "Foot" .. side, "Paw" .. side })
	return CFrame.new(ground(cue, frame.Position) + Vector3.new(0, 0.08, 0)) * root(cue).CFrame.Rotation
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
		local combatEffects = effects :: any
		combatEffects.shake(amount)
	end
end

-- The player's own hit shake (the hit cue is local to the struck player).
local function hurtShake(amount: number)
	local ok, effects = pcall(require, script.Parent.Parent.CombatEffects)
	if ok then
		local combatEffects = effects :: any
		combatEffects.shake(amount)
	end
end

local function facing(cue: Cue): CFrame
	return root(cue).CFrame.Rotation
end

-- A peak's sound, from where its cause is.
local function sound(name: string, at: (Vector3 | BasePart)?, gap: number?)
	Sfx.play(SOUNDS .. name, at, gap)
end

-- A ground frame `forward` studs ahead of the root, `up` above the floor.
local function ahead(cue: Cue, forward: number, up: number): CFrame
	local r = root(cue)
	local at = ground(cue, r.Position + r.CFrame.LookVector * forward)
	return CFrame.new(at + Vector3.new(0, up, 0)) * facing(cue)
end

-- Aura ------------------------------------------------------------------

local function mount(parent: BasePart, name: string, position: Vector3, templateName: string, into: { any }, only: { string }?)
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
			table.insert(into, { e = c, base = if type(base) == "number" then base else 0, name = e.Name })
		end
	end
end

local function applyAura(cue: Cue)
	local s = state(cue.model)
	local aura = s.aura
	if not aura then
		return
	end
	local health, max = cue.model:GetAttribute("Health"), cue.model:GetAttribute("MaxHealth")
	local ratio = if type(health) == "number" and type(max) == "number" and max > 0 then math.clamp(health / max, 0, 1) else 1
	if s.dead or ratio <= 0 then
		for _, item in aura.items do
			item.e.Enabled = false
		end
		return
	end
	local flare = if os.clock() < s.flareUntil then 2.2 else 1
	local k = (1 + (1 - ratio) * 1.2) * flare
	local color
	if ratio <= 0.30 then
		color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.4, HOT), ColorSequenceKeypoint.new(1, GOLD) })
	elseif ratio <= 0.65 then
		color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, HOT), ColorSequenceKeypoint.new(1, MOON) })
	else
		color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, MOON), ColorSequenceKeypoint.new(1, RIM) })
	end
	for _, item in aura.items do
		local e: ParticleEmitter = item.e
		e.Enabled = true
		if item.name == "Embers" then
			e.Rate = math.max(0, 0.7 - ratio) * 14 * flare
		else
			e.Rate = item.base * k
		end
		if item.name == "Flames" then
			e.Color = color
		end
	end
end

local function startAura(cue: Cue)
	local s = state(cue.model)
	if s.aura or s.dead then
		return
	end
	local main = root(cue)
	local neck = part(cue, { "Neck", "Chest" })
	local chest = part(cue, { "Chest" })
	local skull = part(cue, { "Skull" })
	local crest = part(cue, { "Crest", "Chest" })
	if main == cue.root and chest == cue.root then
		return
	end
	local items: { any } = {}
	-- No ground layer: the AuraGround template (ink disc + turning moon
	-- mandala) read as a pale circle always under the King (user,
	-- 2026-10-21), and its ink disc showed as a dark ring on grass. The
	-- template stays in Effects.ElderWolfKing but is not mounted.
	mount(neck, "AuraMane", Vector3.zero, "AuraMane", items, { "Flames" })
	mount(chest, "AuraMotes", Vector3.new(0, 1.5, 0), "AuraMane", items, { "Motes" })
	mount(crest, "AuraEmbers", Vector3.zero, "AuraMane", items, { "Embers" })
	local mouth = body(cue.model):FindFirstChild("Mouth", true)
	if mouth and mouth:IsA("Attachment") then
		mount(skull, "AuraBreath", mouth.Position, "AuraBreath", items)
	end
	s.aura = { items = items }
	CollectionService:AddTag(cue.model, "CraterIgnore")
	applyAura(cue)
	cue.model:GetAttributeChangedSignal("Health"):Connect(function()
		applyAura(cue)
	end)
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

-- Rush -----------------------------------------------------------------

local function takeOff(cue: Cue)
	if not current(cue, "dash") or (cue.attack ~= "kingsRush" and cue.attack ~= "kingLeap") then
		return
	end
	local s = state(cue.model)
	if math.abs(s.rushAt - cue.at) <= EPSILON then
		return
	end
	local seconds = cue.model:GetAttribute("DashSeconds")
	local duration = if type(seconds) == "number" then math.clamp(seconds, 0.05, 0.70) else 0.60
	local age = math.max(0, workspace:GetServerTimeNow() - cue.at)
	if age >= duration then
		return
	end
	cancelWindup(s)
	stopRush(s)
	s.rushAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	if age <= 0.2 then
		-- the hind legs drive off the ground
		local left, right = pawGround(cue, "BL"), pawGround(cue, "BR")
		local mid = (left.Position + right.Position) / 2
		play("Launch", CFrame.new(mid) * facing(cue), { scale = if cue.attack == "kingLeap" then 1.3 else 1 })
		sound("Launch", mid)
	end
	local frame, chest = point(cue, "Core", { "Chest" })
	local trail = make("RushTrail", frame)
	if not trail then
		return
	end
	trail.Parent = TechniqueVFX.folder
	local wake = trail:FindFirstChild("Wake")
	if wake and wake:IsA("Attachment") then
		wake.Position = Vector3.new(0, -math.max(2, frame.Position.Y - ground(cue, frame.Position).Y), 2)
	end
	local offset = chest.CFrame:ToObjectSpace(trail.CFrame)
	TechniqueVFX.enable(trail)
	local stopped = false
	local connection: RBXScriptConnection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		s.stopRush = nil
		connection:Disconnect()
		TechniqueVFX.disable(trail)
		TechniqueVFX.cleanup(trail, 0.3)
	end
	connection = RunService.RenderStepped:Connect(function()
		if not trail.Parent or not chest.Parent or not current(cue, "dash") then
			stop()
		else
			trail.CFrame = chest.CFrame * offset
		end
	end)
	s.stopRush = stop
	task.delay(duration - age + 0.05, stop)
end

-- Cues -----------------------------------------------------------------

function King.ready(cue: Cue)
	if not ours(cue) then
		return
	end
	for _ = 1, 20 do
		if body(cue.model) ~= cue.model and part(cue, { "Chest" }) ~= cue.root then
			break
		end
		task.wait(0.25)
	end
	startAura(cue)
end

-- Noticing a player lights the aura; the roar itself plays on the release of
-- the engage `roar` attack (King.strike), so it lines up with the stagger.
function King.aggro(cue: Cue)
	if not ours(cue) then
		return
	end
	startAura(cue)
end

-- The engage roar's release: sound and air leave the mouth (RoarBlast), the
-- blast shoves dust along the floor ahead (RoarGround), the mane flares.
local function roarBurst(cue: Cue)
	local s = state(cue.model)
	if os.clock() - s.roarAt < 12 or s.dead then
		return
	end
	s.roarAt = os.clock()
	startAura(cue)
	local mouth = point(cue, "Mouth", { "Skull" })
	local face = facing(cue)
	play("RoarBlast", CFrame.new(mouth.Position) * face)
	play("RoarGround", CFrame.new(ground(cue, mouth.Position) + Vector3.new(0, 0.1, 0)) * face)
	flareAura(cue, 1.6)
	sound("RoarBlast", mouth.Position)
	shake(0.3, mouth.Position, 90)
end

local function forepaws(cue: Cue, name: string, seconds: number, lift: number)
	for _, side in { "FL", "FR" } do
		local frame, paw = point(cue, "Paw" .. side .. "_FX", { "Paw" .. side, "LowerLeg" .. side })
		windupPlay(cue, name, frame * CFrame.new(0, lift, 0), { follow = paw, seconds = seconds })
	end
end

local function coil(cue: Cue, sides: { string }, seconds: number)
	for _, side in sides do
		windupPlay(cue, "Coil", pawGround(cue, side), { seconds = seconds })
	end
end

function King.windup(cue: Cue)
	if not ours(cue) or not current(cue, "windup") then
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
	-- the King's intent flashes in its eyes on the first frame of every move
	for _, name in { "EyeL", "EyeR" } do
		local eye = part(cue, { name })
		if eye ~= cue.root then
			windupPlay(cue, "EyeGlint", eye.CFrame, { follow = eye, seconds = math.min(seconds, 0.6) })
		end
	end
	if attack == "royalBite" then
		local frame, skull = point(cue, "Mouth", { "Snout", "Skull" })
		windupPlay(cue, "BiteTell", frame, { follow = skull, seconds = seconds })
	elseif attack == "pawSwipe" then
		local frame, paw = point(cue, "PawFL_FX", { "PawFL", "LowerLegFL" })
		windupPlay(cue, "SwipeTell", frame * CFrame.new(0, 1.2, 0), { follow = paw, seconds = seconds })
	elseif attack == "clawDown" then
		-- the paw is raised through the second half of the windup
		windupBeat(cue, seconds, 0.5, function()
			local frame, paw = point(cue, "PawFR_FX", { "PawFR", "LowerLegFR" })
			windupPlay(cue, "ClawRaise", frame * CFrame.new(0, 1.5, 0), { follow = paw, seconds = seconds * 0.5 })
		end)
	elseif attack == "kingsRush" then
		coil(cue, { "BL", "BR" }, seconds)
	elseif attack == "kingLeap" then
		s.leapShape = cue.shape
		coil(cue, { "FL", "FR", "BL", "BR" }, seconds)
	elseif attack == "kingRake" then
		forepaws(cue, "SwipeTell", seconds, 1.2)
	elseif attack == "crownfall" then
		forepaws(cue, "CrownfallTell", seconds, 1.5)
		-- the rising charge (0.98 s at 0.9 speed ~ 1.09 s) ends on contact
		windupBeat(cue, seconds, math.max(0, 1 - 1.09 / seconds), function()
			s.stopCharge = Sfx.play(SOUNDS .. "CrownfallCharge", root(cue))
		end)
	elseif attack == "roar" then
		local frame, skull = point(cue, "Mouth", { "Skull" })
		windupPlay(cue, "RoarTell", frame, { follow = skull, seconds = seconds })
	elseif attack == "packCall" then
		local frame, skull = point(cue, "Mouth", { "Skull" })
		windupPlay(cue, "HowlTell", frame, { follow = skull, seconds = seconds })
		local at = ground(cue, root(cue).Position)
		windupPlay(cue, "HowlGather", CFrame.new(at + Vector3.new(0, 0.1, 0)), { seconds = seconds, scale = 11 })
	end
end

function King.strike(cue: Cue)
	if not ours(cue) or not current(cue) then
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
	cancelWindup(s)
	local attack = cue.attack
	if attack == "kingsRush" or attack == "kingLeap" then
		takeOff(cue)
		return
	end
	-- A late phase packet can still arrive during the long recovery. Avoid
	-- replaying a contact that has already passed on the server's timeline.
	if workspace:GetServerTimeNow() - cue.at > 0.3 then
		return
	end
	local face = facing(cue)
	local shapeCenter = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else nil
	local shapeRadius = if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else nil
	if attack == "royalBite" then
		local frame = point(cue, "Mouth", { "Snout", "Skull" })
		play("BiteSnap", CFrame.new(frame.Position) * face)
		sound("BiteSnap", frame.Position)
		shake(0.26, cue.root.Position, 60)
	elseif attack == "pawSwipe" then
		-- the foreleg sweeps the cone in front of the chest
		local frame = ahead(cue, 12, 3)
		play("SwipeSlash", frame)
		sound("SwipeSlash", frame.Position)
		shake(0.14, cue.root.Position, 50)
	elseif attack == "clawDown" then
		local position = ground(cue, shapeCenter or cue.root.CFrame:PointToWorldSpace(Vector3.new(1.7, 0, -7)))
		play("ClawStrike", CFrame.new(position) * face, { scale = shapeRadius or 4.5 })
		sound("ClawStrike", position)
		shake(0.2, position, 55)
	elseif attack == "crownfall" then
		local position = ground(cue, shapeCenter or cue.root.CFrame:PointToWorldSpace(Vector3.new(0, 0, -3.5)))
		local radius = shapeRadius or 13
		play("CrownfallImpact", CFrame.new(position) * face, { scale = radius })
		sound("CrownfallImpact", position)
		task.delay(0.15, sound, "CrownfallRumble", position)
		shake(0.34, position, radius + 40)
	elseif attack == "kingRake" then
		-- both forepaws rake the arrival cone, left then right
		for i, side in { "FL", "FR" } do
			task.delay((i - 1) * 0.08, function()
				if cue.model.Parent then
					local frame = ahead(cue, 13, 3)
					play("SwipeSlash", if side == "FL" then frame else frame * CFrame.Angles(0, 0, math.pi), { scale = 1.15 })
				end
			end)
		end
		sound("Rake", ahead(cue, 13, 3).Position)
		shake(0.2, cue.root.Position, 50)
	elseif attack == "roar" then
		roarBurst(cue)
	elseif attack == "packCall" then
		local health, max = cue.model:GetAttribute("Health"), cue.model:GetAttribute("MaxHealth")
		local second = type(health) == "number" and type(max) == "number" and max > 0 and health / max <= 0.35
		local mouth = point(cue, "Mouth", { "Skull" })
		local at = ground(cue, root(cue).Position)
		-- the howl to the sky; its air shock sweeps the stun ring
		play("HowlBlast", CFrame.new(mouth.Position) * face, { boost = if second then 1.5 else nil })
		play("HowlGround", CFrame.new(at) * face, { scale = shapeRadius or 20, boost = if second then 1.4 else nil })
		local neck = part(cue, { "Neck", "Chest" })
		play("ManeFlare", neck.CFrame, { follow = neck, boost = if second then 1.6 else nil })
		sound("HowlBlast", mouth.Position)
		flareAura(cue, 3)
		shake(0.3, cue.root.Position, 100)
	end
end

function King.dash(cue: Cue)
	if not ours(cue) then
		return
	end
	takeOff(cue)
end

-- The arrival follow-up or skid replaces the model's Attack as the dash ends.
local ARRIVE: { [string]: { [string]: boolean } } = {
	kingLeap = { kingRake = true, kingLeapSkid = true },
	kingsRush = { kingsRushSkid = true, kingRake = true },
}
local function arrived(cue: Cue): boolean
	local follow = ARRIVE[cue.attack or ""]
	local now = cue.model:GetAttribute("Attack")
	local health = cue.model:GetAttribute("Health")
	return follow ~= nil and type(now) == "string" and follow[now] == true and cue.model.Parent ~= nil
		and not state(cue.model).dead and not (type(health) == "number" and health <= 0)
end

local function plough(cue: Cue, sides: { string })
	for _, side in sides do
		play("Skid", pawGround(cue, side))
	end
	sound("Skid", root(cue).Position, 0.3)
end

function King.land(cue: Cue)
	if not ours(cue) or (cue.attack ~= "kingsRush" and cue.attack ~= "kingLeap") or not (current(cue) or arrived(cue)) then
		return
	end
	local s = state(cue.model)
	stopRush(s)
	if math.abs(s.landAt - cue.at) <= EPSILON then
		return
	end
	if cue.attack == "kingLeap" then
		s.landAt = cue.at
		s.latestAt = math.max(s.latestAt, cue.at)
		local shape = s.leapShape
		local center = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else root(cue).Position
		local radius = if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else 14
		local at = ground(cue, center)
		play("LeapImpact", CFrame.new(at) * facing(cue), { scale = radius })
		sound("LeapLand", at)
		shake(0.34, at, radius + 40)
		return
	end
	if cue.model:GetAttribute("AIState") ~= "recover" and not arrived(cue) then
		return
	end
	s.landAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	plough(cue, { "FL", "FR" })
	shake(0.18, cue.root.Position, 60)
end

-- kingsRushSkid / kingLeapSkid: all four paws plough as the body swings round.
function King.skid(cue: Cue)
	if not ours(cue) then
		return
	end
	plough(cue, { "FL", "FR", "BL", "BR" })
	shake(0.12, cue.root.Position, 50)
end

function King.hit(cue: Cue)
	-- The hit remote can precede the replicated windup -> recover/dash change.
	-- Keep that confirmed contact across the transition, but still reject another
	-- attack, a finished recovery, a stale iteration, a despawn or a dead boss.
	local phase = cue.model:GetAttribute("AIState")
	local grace = (WINDUP[cue.attack or ""] or 0) + 0.7
	if not ours(cue) or not current(cue, nil, grace) or cue.attack == "packCall"
		or (phase ~= "windup" and phase ~= "dash" and phase ~= "recover") then
		return
	end
	local target = cue.target
	local torso = target and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local delta = root(cue).Position - torso.Position
	local toward = Vector3.new(delta.X, 0, delta.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(torso.Position + toward * 0.9, torso.Position + toward * 1.9)
	local name = if cue.attack == "pawSwipe" or cue.attack == "kingRake" then "HitClaw" elseif cue.attack == "royalBite" then "HitBite" else "HitHeavy"
	play(name, frame)
	sound(name, torso.Position, 0.08)
	if Players.LocalPlayer and target == Players.LocalPlayer.Character then
		hurtShake(if cue.attack == "crownfall" then 0.26 elseif cue.attack == "royalBite" or cue.attack == "kingsRush" then 0.2 else 0.15)
	end
end

-- Knocked back: qi is knocked out of the chest (EnemySounds plays Hurt).
function King.stagger(cue: Cue)
	if not ours(cue) or not current(cue, "stagger") then
		return
	end
	local s = state(cue.model)
	cancelWindup(s)
	s.shape = nil
	stopRush(s)
	s.latestAt = math.max(s.latestAt, cue.at)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("Stagger", frame, { follow = chest })
end

-- Death: the King's qi leaks off the body (DeathLeak), then at 0.85 s its
-- spirit breaks free upward (DeathRelease). EnemySounds plays the death cry.
function King.death(cue: Cue)
	if not ours(cue) then
		return
	end
	local s = state(cue.model)
	if s.dead then
		return
	end
	s.dead = true
	cancelWindup(s)
	s.shape = nil
	stopRush(s)
	applyAura(cue)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("DeathLeak", frame, { follow = chest })
	local at = ground(cue, root(cue).Position)
	local face = facing(cue)
	task.delay(0.85, function()
		play("DeathRelease", CFrame.new(at + Vector3.new(0, 0.05, 0)) * face)
		sound("DeathRelease", at)
		task.delay(0.3, sound, "DeathRumble", at)
		shake(0.34, at, 150)
	end)
end

return King
