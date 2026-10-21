--!strict
-- Testbed Elder Wolf King only. Reuses the plugin-authored SpiritWolf and
-- StoneBoar emission templates; every change below is on a temporary clone.
-- Silver/slate qi, amber attack warnings, restrained jade on the collar seal.
--
-- Contact is `strike` (windup -> recover), not the end of active/recovery.
-- Rush shares `strike`/`dash`, and ends on `land`. `seconds` is already the
-- remaining windup; cue.at/StateAt and a generation cancel interrupted cues.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
}

local TEMPLATE = "ElderWolfKingB"
local SILVER = Color3.fromRGB(228, 233, 238)
local RIM = Color3.fromRGB(158, 176, 193)
local SLATE = Color3.fromRGB(37, 44, 58)
local DUST = Color3.fromRGB(153, 155, 157)
local AMBER = Color3.fromRGB(255, 200, 90)
local JADE = Color3.fromRGB(93, 187, 152)
local WHITE = Color3.new(1, 1, 1)
local EPSILON = 0.035
local WINDUP = {
	royalBite = 0.90,
	kingsRush = 1.00,
	crownfall = 1.25,
	pawSwipe = 0.45,
	clawDown = 0.55,
	packCall = 1.20,
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

-- Keep the original texture/layer contrast, replacing blue and earth qi with
-- the King's silver. Emit attributes and tags survive on the runtime clone.
local function prepare(copy: BasePart, scale: number, accent: Color3?)
	copy.Size *= scale
	for _, d in copy:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position *= scale
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			local name = d.Name
			if name == "Dark" or name == "Shadow" or name == "Ink" or name == "Under" or name == "MarkDark" or name == "DustRing" or name == "Grit" or name == "Crack" then
				d.Color = ColorSequence.new(SLATE)
			elseif name == "Puff" or name == "Puffs" or name == "Dust" or name == "Chips" then
				d.Color = ColorSequence.new(DUST)
			elseif name == "Rim" then
				d.Color = ColorSequence.new(accent or RIM)
			else
				d.Color = ColorSequence.new(WHITE, accent or SILVER)
			end
			if d:IsA("ParticleEmitter") then
				d.Size = scaleSequence(d.Size, scale)
				d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
				d.Acceleration *= scale
			end
		end
	end
end

local function retime(copy: BasePart, authored: number, seconds: number)
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

local function clone(group: string, name: string, frame: CFrame, scale: number, accent: Color3?): BasePart?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local folder = effects and effects:FindFirstChild(group)
	local template = folder and folder:FindFirstChild(name)
	if not (template and template:IsA("BasePart")) then
		return nil
	end
	local copy = template:Clone()
	prepare(copy, scale, accent)
	copy.CFrame = frame * template.CFrame.Rotation
	return copy
end

local function play(group: string, name: string, frame: CFrame, scale: number, accent: Color3?, follow: BasePart?, edit: ((BasePart) -> ())?, guard: (() -> boolean)?): BasePart?
	local copy = clone(group, name, frame, scale, accent)
	if not copy then
		return nil
	end
	if edit then
		edit(copy)
	end
	copy.Parent = TechniqueVFX.folder
	if follow then
		local offset = follow.CFrame:ToObjectSpace(copy.CFrame)
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

local function windupPlay(cue: Cue, group: string, name: string, frame: CFrame, scale: number, accent: Color3?, follow: BasePart?, edit: ((BasePart) -> ())?)
	local s = state(cue.model)
	local generation = s.generation
	local effect = play(group, name, frame, scale, accent, follow, edit, function()
		return s.generation == generation and current(cue, "windup")
	end)
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

local function sealGlint(cue: Cue, windup: boolean)
	local frame, follow = point(cue, "SealFX", { "Seal", "Chest" })
	if windup then
		windupPlay(cue, "StoneBoar", "TuskGlint", frame, 0.75, JADE, follow)
	else
		play("StoneBoar", "TuskGlint", frame, 0.75, JADE, follow)
	end
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
		local combatEffects = effects :: any
		combatEffects.shake(amount)
	end
end

local function takeOff(cue: Cue)
	if not current(cue, "dash") or cue.attack ~= "kingsRush" then
		return
	end
	local s = state(cue.model)
	if math.abs(s.rushAt - cue.at) <= EPSILON then
		return
	end
	local seconds = cue.model:GetAttribute("DashSeconds")
	local duration = if type(seconds) == "number" then math.clamp(seconds, 0.05, 0.60) else 0.60
	local age = math.max(0, workspace:GetServerTimeNow() - cue.at)
	if age >= duration then
		return
	end
	cancelWindup(s)
	stopRush(s)
	s.rushAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	if age <= 0.2 then
		local left, right = pawGround(cue, "BL"), pawGround(cue, "BR")
		play("SpiritWolf", "DashDust", CFrame.new((left.Position + right.Position) / 2) * left.Rotation, 1.65)
	end
	local frame, chest = point(cue, "Core", { "Chest" })
	local trail = clone("SpiritWolf", "MoonTrail", frame, 2.0)
	if not trail then
		return
	end
	trail.Parent = TechniqueVFX.folder
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
	for _, name in { "EyeL", "EyeR" } do
		local eye = part(cue, { name })
		if eye ~= cue.root then
			windupPlay(cue, "StoneBoar", "EyeGlint", eye.CFrame, 1.05, if attack == "packCall" then SILVER else AMBER, eye)
		end
	end
	if attack == "royalBite" then
		local frame, skull = point(cue, "Mouth", { "Snout", "Skull" })
		windupPlay(cue, "SpiritWolf", "Breath", frame, 1.8, SILVER, skull, function(copy)
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d:SetAttribute("EmitDuration", seconds)
				end
			end
		end)
	elseif attack == "pawSwipe" then
		local shoulder = part(cue, { "ShoulderFL", "UpperLegFL", "Chest" })
		windupPlay(cue, "StoneBoar", "TuskGlint", shoulder.CFrame, 1.1, AMBER, shoulder)
	elseif attack == "clawDown" then
		windupBeat(cue, seconds, 0.55, function()
			local frame, paw = point(cue, "PawFR_FX", { "PawFR", "LowerLegFR" })
			windupPlay(cue, "StoneBoar", "TuskGlint", frame, 1.2, AMBER, paw)
		end)
	elseif attack == "kingsRush" or attack == "crownfall" then
		local frame, chest = point(cue, "Core", { "Chest" })
		windupPlay(cue, "SpiritWolf", "Gather", frame, if attack == "crownfall" then 1.65 else 1.4, SILVER, chest, function(copy)
			retime(copy, 0.7, seconds)
		end)
		windupBeat(cue, seconds, 0.6, function()
			if attack == "crownfall" then
				sealGlint(cue, true)
			else
				for _, side in { "BL", "BR" } do
					windupPlay(cue, "SpiritWolf", "PawDust", pawGround(cue, side), 1.4)
				end
			end
		end)
	elseif attack == "packCall" then
		local frame, skull = point(cue, "Mouth", { "Skull" })
		windupPlay(cue, "SpiritWolf", "HowlRings", frame, 1.6, SILVER, skull, function(copy)
			retime(copy, 1.04, seconds)
		end)
		local core, chest = point(cue, "Core", { "Chest" })
		windupPlay(cue, "SpiritWolf", "CrestGlow", core, 1.5, SILVER, chest, function(copy)
			retime(copy, 0.9, seconds)
		end)
		windupBeat(cue, seconds, 0.65, function()
			sealGlint(cue, true)
		end)
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
	if attack == "kingsRush" then
		takeOff(cue)
		return
	end
	-- A late phase packet can still arrive during the long recovery. Avoid
	-- replaying a contact that has already passed on the server's timeline.
	if workspace:GetServerTimeNow() - cue.at > 0.3 then
		return
	end
	if attack == "royalBite" then
		local frame = point(cue, "Mouth", { "Snout", "Skull" })
		play("SpiritWolf", "FangSnap", frame, 2.1)
	elseif attack == "pawSwipe" then
		local frame = point(cue, "PawFL_FX", { "PawFL", "LowerLegFL" })
		play("StoneBoar", "GoreHook", frame * CFrame.new(0, 0.3, -0.7), 1.25, SILVER, nil, function(copy)
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") and (d.Name == "Dark" or d.Name == "Rim" or d.Name == "Core") then
					d.Rotation = NumberRange.new(-35)
					d.RotSpeed = NumberRange.new(-280)
					d.EmissionDirection = Enum.NormalId.Right
					d.Speed = NumberRange.new(10)
					d.Lifetime = NumberRange.new(0.14)
				end
			end
		end)
	elseif attack == "clawDown" then
		local position = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else cue.root.CFrame:PointToWorldSpace(Vector3.new(1.7, 0, -7))
		local at = ground(cue, position)
		local facing = root(cue).CFrame.Rotation
		play("SpiritWolf", "ClawRake", CFrame.new(at + Vector3.new(0, 2.0, 0)) * facing, 1.35, SILVER, nil, function(copy)
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") and (d.Name == "Dark" or d.Name == "Rim" or d.Name == "Core") then
					d.Rotation = NumberRange.new(0)
					d.EmissionDirection = Enum.NormalId.Bottom
					d.Speed = NumberRange.new(12)
					d.Lifetime = NumberRange.new(0.14)
				end
			end
		end)
		play("SpiritWolf", "PawDust", CFrame.new(at + Vector3.new(0, 0.08, 0)) * facing, 1.4)
	elseif attack == "crownfall" then
		local position = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else cue.root.Position
		local radius = if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else 11
		local at = ground(cue, position)
		play("SpiritWolf", "Landing", CFrame.new(at + Vector3.new(0, 0.06, 0)), radius / 5, SILVER, nil, function(copy)
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") and d.Name == "Shockwave" then
					d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, radius * 1.5), NumberSequenceKeypoint.new(1, radius * 2) })
				elseif d:IsA("ParticleEmitter") and d.Name == "Puffs" then
					d.EmissionDirection = Enum.NormalId.Top
					d.SpreadAngle = Vector2.new(85, 85)
				end
			end
		end)
		shake(0.26, at, radius + 5)
	elseif attack == "packCall" then
		local frame = point(cue, "Mouth", { "Skull" })
		play("SpiritWolf", "HowlRings", frame, 1.8, SILVER, nil, function(copy)
			for _, d in copy:GetDescendants() do
				if d:IsA("ParticleEmitter") and (d.Name == "Ring2" or d.Name == "Ring3") then
					d:Destroy()
				end
			end
		end)
	end
end

function King.dash(cue: Cue)
	if not ours(cue) then
		return
	end
	takeOff(cue)
end

function King.land(cue: Cue)
	if not ours(cue) or not current(cue) or cue.attack ~= "kingsRush" then
		return
	end
	local s = state(cue.model)
	stopRush(s)
	if cue.model:GetAttribute("AIState") ~= "recover" or math.abs(s.landAt - cue.at) <= EPSILON then
		return
	end
	s.landAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	local left, right = pawGround(cue, "FL"), pawGround(cue, "FR")
	play("StoneBoar", "Skid", CFrame.new((left.Position + right.Position) / 2) * left.Rotation, 1.65)
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
	if cue.attack == "pawSwipe" then
		play("SpiritWolf", "ClawRake", frame, 1.1)
	elseif cue.attack == "clawDown" then
		play("StoneBoar", "GoreHit", frame, 1.1)
	elseif cue.attack == "kingsRush" or cue.attack == "crownfall" then
		play("StoneBoar", "ChargeHit", frame, 1.1)
	else
		play("SpiritWolf", "BiteHit", frame, 1.15)
	end
	if target == Players.LocalPlayer.Character then
		shake(if cue.attack == "crownfall" then 0.24 else 0.15)
	end
end

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
	play("SpiritWolf", "StaggerFlash", frame, 1.6, SILVER, chest)
end

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
	local frame = point(cue, "Core", { "Chest" })
	play("SpiritWolf", "Death", frame, 2.0)
	sealGlint(cue, false)
end

return King
