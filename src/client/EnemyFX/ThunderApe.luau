--!nonstrict
-- Thunder Ape boss (template ThunderApeB) effects. Plays the ape's own
-- templates, Effects.ThunderApe (built by tools/vfx_specs/ThunderApe.luau,
-- whose header holds each move's intent, beat sheet and layer sheet), and their
-- sounds, SoundService.SFX.Enemies.ThunderApe.<Name> (Sfx.play at the peak,
-- from where the cause is). Storm blue-white over indigo and slate; violet
-- only in phase 3; dust and rock are lit earth. No copy of the body is ever
-- drawn, nothing crowns the head, and nothing redraws a telegraph's area.
-- Cues: ready/aggro (aura), windup, strike, dash, land, skid, hit, stagger,
-- death and the server's "phase". Areas are read from each cue's `shape`
-- (radius, centre, lane); the authored templates are rescaled to them.
--
-- Contact is `strike` (windup -> dash/recover). `windup` also arrives for the
-- stormBolt and poundWave circles (AIState is recover then, so no state guard)
-- and twice for the roars (howl ring + stun circle): deduped by `at`. A
-- generation counter cancels everything an interrupted windup scheduled.
-- Every layer comes from these templates (the shared Impact kit is not layered
-- on top any more: its generic rings and scars doubled the ape's own impacts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local ProjectileView = require(script.Parent.Parent.ProjectileView)
local Sfx = require(script.Parent.Parent.Sfx)

local TEMPLATE = "ThunderApeB"
local SOUNDS = "Enemies/ThunderApe/"
local WHITE = Color3.new(1, 1, 1)
local INDIGO = Color3.fromRGB(27, 37, 71)
local VIOLET = Color3.fromRGB(143, 123, 255)
local SLATE = Color3.fromRGB(62, 68, 80)
local EPSILON = 0.035

-- fixed fight timing (contracts: seconds into the windup)
local BEATS = {
	challenge = { 0.55, 1.15, 1.75 },
	thunderRoar = { 0.45, 0.85 },
	phaseRoar = { 0.4, 0.8, 1.2 },
}
local WINDUP = {
	rushSwipe = 0.4, skyfallSweep = 0.5,
	challenge = 2.4, clubSwing = 0.8, backhand = 0.6, thunderPound = 0.85, bodySlam = 1.1, skyfallSlam = 1.95,
	thunderRush = 1.2, bound = 0.45, boulderHurl = 1.7, thunderLance = 1.4, thunderRoar = 1.3, stormCall = 1.2,
	judgment = 2.6, phaseRoar = 1.6,
}
-- fallbacks only: windup cues carry `seconds` (a leap's is windup + flight)
local FLIGHT = { skyfallSlam = 0.75, judgment = 1.0 }
local THROW_FLIGHT = 0.45 -- boulderHurl: the rock leaves the hand this long before the windup ends
local INHALE = 0.45 -- the roar's breath: the last 0.45 s of its windup
local JUDGE_HEIGHT = 52 -- the judgment storm cloud over the landing

local Ape = {}
local states = setmetatable({}, { __mode = "k" })

local function ours(cue)
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function state(model)
	local s = states[model]
	if not s then
		s = {
			generation = 0, latestAt = -math.huge, windupAt = -math.huge, strikeAt = -math.huge,
			dashAt = -math.huge, landAt = -math.huge, dead = false, shape = nil, windups = {}, stops = {},
			aura = nil, flareUntil = 0, tweens = {}, stunR = nil, arcToken = 0, boulder = nil, phase = 0,
			cloudAt = nil, stopCharge = nil,
		}
		states[model] = s
	end
	return s
end

local function current(cue, phase, grace)
	if not ours(cue) or not cue.model.Parent or not cue.root.Parent then
		return false
	end
	local s = state(cue.model)
	local at = cue.model:GetAttribute("StateAt")
	local health = cue.model:GetAttribute("Health")
	if s.dead or cue.model:GetAttribute("FadeAt") ~= nil or (type(health) == "number" and health <= 0) then
		return false
	end
	local g = grace or EPSILON
	if cue.at + g < s.latestAt or (type(at) == "number" and at > cue.at + g) then
		return false
	end
	if cue.attack ~= cue.model:GetAttribute("Attack") then
		return false
	end
	return phase == nil or cue.model:GetAttribute("AIState") == phase
end

local function body(model)
	return model:FindFirstChild("Body") or model
end
local function part(cue, names)
	for _, name in names do
		local found = body(cue.model):FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return cue.root
end
local function root(cue)
	return part(cue, { "HumanoidRootPart" })
end
local function facing(cue)
	return root(cue).CFrame.Rotation
end

-- A frame at a named attachment (root-facing), and the part that carries it.
local function point(cue, name, fallback)
	local a = body(cue.model):FindFirstChild(name, true)
	local follow = part(cue, fallback)
	local position = follow.Position
	if a and a:IsA("Attachment") then
		position = a.WorldPosition
		if a.Parent and a.Parent:IsA("BasePart") then
			follow = a.Parent
		end
	end
	return CFrame.new(position) * facing(cue), follow
end

local function ground(cue, position)
	local exclude = { cue.model }
	local wilds = workspace:FindFirstChild("Wilds")
	local enemies = wilds and wilds:FindFirstChild("Enemies")
	if enemies then
		table.insert(exclude, enemies)
	end
	if workspace.CurrentCamera then
		table.insert(exclude, workspace.CurrentCamera)
	end
	if TechniqueVFX.folder then
		table.insert(exclude, TechniqueVFX.folder)
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

local function scaleSequence(sequence, scale)
	local points = {}
	for _, key in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale))
	end
	return NumberSequence.new(points)
end

local function prepare(copy, scale)
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
		elseif d:IsA("Model") and d:GetAttribute("MeshWave") then
			for _, key in { "FromSize", "ToSize", "FromOffset", "ToOffset" } do
				local v = d:GetAttribute(key)
				if typeof(v) == "Vector3" then
					d:SetAttribute(key, v * scale)
				end
			end
		end
	end
end

local function retime(copy, seconds)
	local authored = copy:GetAttribute("AuthoredSeconds")
	if type(authored) ~= "number" or authored <= 0 then
		return
	end
	local k = seconds / authored
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Lifetime = NumberRange.new(d.Lifetime.Min * k, d.Lifetime.Max * k)
		end
		if d:IsA("ParticleEmitter") or (d:IsA("Model") and d:GetAttribute("MeshWave")) then
			for _, key in { "EmitDelay", "EmitDuration", "Duration" } do
				local value = d:GetAttribute(key)
				if type(value) == "number" and value > 0 then
					d:SetAttribute(key, value * k)
				end
			end
		end
	end
end

local function tint(copy, color)
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.LightEmission > 0.3 then
			d.Color = ColorSequence.new(WHITE, color)
		end
	end
end

local function boost(copy, factor)
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local count = d:GetAttribute("EmitCount")
			if type(count) == "number" then
				d:SetAttribute("EmitCount", math.max(1, math.round(count * factor)))
			end
		end
	end
end

local function template(name)
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local folder = effects and effects:FindFirstChild("ThunderApe")
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- o: radius (live circle radius, for templates with AuthoredRadius), scale
-- (plain factor), seconds (refit a held effect), tint, boost, edit, follow,
-- rotate (false: follow the position only), guard.
local function make(name, frame, o)
	local base = template(name)
	if not base then
		return nil
	end
	o = o or {}
	local copy = base:Clone()
	local scale = o.scale or 1
	local authored = copy:GetAttribute("AuthoredRadius")
	if o.radius and type(authored) == "number" then
		scale = scale * o.radius / authored
	end
	prepare(copy, scale)
	if o.seconds then
		retime(copy, o.seconds)
	end
	if o.tint then
		tint(copy, o.tint)
	end
	if o.boost then
		boost(copy, o.boost)
	end
	if o.edit then
		o.edit(copy)
	end
	copy.CFrame = frame
	return copy
end

local function play(name, frame, o)
	local copy = make(name, frame, o)
	if not copy then
		return nil
	end
	o = o or {}
	copy.Parent = TechniqueVFX.folder
	local follow = o.follow
	if follow then
		local offset = follow.CFrame:ToObjectSpace(copy.CFrame)
		local worldOffset = copy.Position - follow.Position
		local rotation = copy.CFrame.Rotation
		local guard = o.guard
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if not copy.Parent then
				connection:Disconnect()
			elseif not follow.Parent or (guard and not guard()) then
				connection:Disconnect()
				copy:Destroy()
			elseif o.rotate == false then
				copy.CFrame = CFrame.new(follow.Position + worldOffset) * rotation
			else
				copy.CFrame = follow.CFrame * offset
			end
		end)
	end
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.3)
	return copy
end

-- A peak's sound, from where its cause is.
local function sound(name, at, gap)
	return Sfx.play(SOUNDS .. name, at, gap)
end

local function shake(amount, position, radius)
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
		effects.shake(amount)
	end
end

local function hurtShake(amount)
	local ok, effects = pcall(require, script.Parent.Parent.CombatEffects)
	if ok then
		effects.shake(amount)
	end
end

----------------------------------------------------------------------
-- Screen: sky flicker, flash and the storm's darkening (a short-lived
-- ColorCorrection; DayNight owns Lighting's own values every frame)
----------------------------------------------------------------------

local function grade(brightness, tintColor, inSeconds, holdSeconds, outSeconds)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ThunderApeGrade"
	cc.Brightness = 0
	cc.TintColor = WHITE
	cc.Parent = Lighting
	local up = TweenService:Create(cc, TweenInfo.new(inSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = brightness, TintColor = tintColor })
	up:Play()
	task.delay(inSeconds + holdSeconds, function()
		local down = TweenService:Create(cc, TweenInfo.new(outSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0, TintColor = WHITE })
		down:Play()
		down.Completed:Once(function()
			cc:Destroy()
		end)
	end)
end
local function near(position, reach)
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < reach
end
local function skyFlash(strength)
	grade(strength, Color3.fromRGB(214, 236, 255), 0.03, 0.04, 0.3)
end
local function skyFlicker(strength)
	skyFlash(strength)
	task.delay(0.16, skyFlash, strength * 0.7)
end
local function skyDark(amount, total)
	grade(-amount, Color3.fromRGB(176, 190, 230), 0.6, total, 0.9)
end

----------------------------------------------------------------------
-- Bolts: jagged beams from the Bolt template (indigo edge, glow, strip core)
----------------------------------------------------------------------

local function boltBeam(a, b, width, life, segs, jag)
	local tpl = template("Bolt")
	if not tpl then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(a)
	holder.Parent = TechniqueVFX.folder
	local n = segs or 8
	local dir = b - a
	local length = dir.Magnitude
	if length < 0.1 then
		holder:Destroy()
		return
	end
	local unit = dir / length
	local side = unit:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = side:Cross(unit).Unit
	local points = {}
	local amp = (jag or 0.07) * length / n * 3
	for i = 0, n do
		local p = a + dir * (i / n)
		if i > 0 and i < n then
			p += side * (math.random() - 0.5) * 2 * amp + up * (math.random() - 0.5) * 2 * amp
		end
		local at = Instance.new("Attachment")
		at.Position = p - a
		at.Parent = holder
		points[i + 1] = at
	end
	local beams = {}
	-- a thin indigo edge for daylight, a cyan glow, the white electric strip
	local widths = { Dark = 1.25, Glow = 2.4, Core = 1.1 }
	for i = 1, n do
		for _, template_beam in tpl:GetChildren() do
			if template_beam:IsA("Beam") then
				local beam = template_beam:Clone()
				beam.Attachment0, beam.Attachment1 = points[i], points[i + 1]
				local w = width * (widths[beam.Name] or 1)
				beam.Width0, beam.Width1 = w, w
				beam.Enabled = true
				beam.Parent = holder
				table.insert(beams, { beam = beam, w = w, base = if beam.Name == "Glow" then 0.45 elseif beam.Name == "Dark" then 0.35 else 0 })
			end
		end
	end
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - started) / life
		if t >= 1 or not holder.Parent then
			connection:Disconnect()
			holder:Destroy()
			return
		end
		local flick = if t < 0.5 and math.floor(t * 18) % 2 == 1 then 0.35 else 0
		for _, item in beams do
			local transparency = math.min(1, item.base + flick + (1 - item.base) * t * t)
			item.beam.Transparency = NumberSequence.new(transparency)
			local w = item.w * (1 - 0.7 * t)
			item.beam.Width0, item.beam.Width1 = w, w
		end
	end)
end

-- a lightning stroke from the sky to a ground point: the main bolt and two forks
local function pillarBolt(top, bottom, width)
	boltBeam(top, bottom, width, 0.45, 10, 0.06)
	for _ = 1, 2 do
		local f = 0.35 + 0.3 * math.random()
		local from = top:Lerp(bottom, f)
		local out = Vector3.new(math.random() - 0.5, -0.2, math.random() - 0.5).Unit * (12 + math.random() * 12)
		boltBeam(from, from + out + Vector3.new(0, -8, 0), width * 0.35, 0.32, 5, 0.12)
	end
end

local function bodyBox(cue, shrink)
	local cf, size = cue.model:GetBoundingBox()
	local k = shrink or 1
	return CFrame.new(cf.Position) * facing(cue), Vector3.new(size.X * k, size.Y * k, size.Z * k)
end

----------------------------------------------------------------------
-- Tells (Neon parts flagged Tell): dim -> bright over a windup
----------------------------------------------------------------------

local function baseColor(p)
	local base = p:GetAttribute("TellBase")
	if typeof(base) ~= "Color3" then
		base = p.Color
		p:SetAttribute("TellBase", base)
	end
	return base
end

local function tells(cue, prefixes)
	local list = {}
	for _, d in body(cue.model):GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Tell") == true then
			if not prefixes then
				table.insert(list, d)
			else
				for _, prefix in prefixes do
					if d.Name:sub(1, #prefix) == prefix then
						table.insert(list, d)
						break
					end
				end
			end
		end
	end
	return list
end

local function resetTells(cue)
	local s = state(cue.model)
	for _, tw in s.tweens do
		tw:Cancel()
	end
	table.clear(s.tweens)
	for _, p in tells(cue) do
		p.Color = baseColor(p)
	end
end

local function tellUp(cue, prefixes, seconds, peak)
	local s = state(cue.model)
	local generation = s.generation
	local list = tells(cue, prefixes)
	for _, p in list do
		local base = baseColor(p)
		p.Color = base:Lerp(INDIGO, 0.6)
		local tw = TweenService:Create(p, TweenInfo.new(math.max(0.05, seconds), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = peak or WHITE })
		table.insert(s.tweens, tw)
		tw:Play()
	end
	task.delay(seconds + 0.2, function()
		if s.generation == generation then
			for _, p in list do
				if p.Parent and not s.dead then
					p.Color = baseColor(p)
				end
			end
		end
	end)
end

local FIST_R = { "KnuckleR", "ForeArmFRBolt" }
local FIST_L = { "KnuckleL", "ForeArmFLBolt" }
local FISTS = { "KnuckleR", "ForeArmFRBolt", "KnuckleL", "ForeArmFLBolt" }
local CHEST = { "ChestSigil", "ChestBolt" }
local EYES = { "Eye" }
local BACK = { "BackBolt", "ChestBolt", "ForeArmFLBolt", "ForeArmFRBolt" }

----------------------------------------------------------------------
-- Generation / scheduling
----------------------------------------------------------------------

local function cancelWindup(cue)
	local s = state(cue.model)
	s.generation += 1
	for _, effect in s.windups do
		effect:Destroy()
	end
	table.clear(s.windups)
	for _, stop in s.stops do
		stop()
	end
	table.clear(s.stops)
	if s.boulder then
		s.boulder:Destroy()
		s.boulder = nil
	end
	resetTells(cue)
end

-- the judgment cloud outlives its windup (the landing's bolt comes out of it);
-- a stagger or death clears it
local function clearCloud(s)
	if s.judgeCloud then
		s.judgeCloud:Destroy()
		s.judgeCloud = nil
	end
	s.cloudAt = nil
end

-- a rising charge sound that belongs to the windup (stops if it breaks)
local function windupSound(cue, name, at)
	local s = state(cue.model)
	local stop = sound(name, at)
	if stop then
		table.insert(s.stops, stop)
	end
end

local function windupPlay(cue, name, frame, o)
	local s = state(cue.model)
	local generation = s.generation
	o = table.clone(o or {})
	o.guard = function()
		return s.generation == generation and current(cue, "windup", 1)
	end
	local effect = play(name, frame, o)
	if effect then
		table.insert(s.windups, effect)
	end
	return effect
end

-- run `fn` `t` seconds after the windup started (server clock)
local function atTime(cue, t, fn)
	local s = state(cue.model)
	local generation = s.generation
	local delay = cue.at + t - workspace:GetServerTimeNow()
	task.delay(math.max(0, delay), function()
		if s.generation == generation and not s.dead and cue.model.Parent and current(cue, "windup", 0.3) then
			fn()
		end
	end)
end

----------------------------------------------------------------------
-- Aura: arcs on the forearms, storm wisps on the shoulders and back; phase
-- 2+ adds bold arcs on the fists and shoulders and arcs jumping between them
----------------------------------------------------------------------

local function hookPart(cue, name, fallback)
	local a = body(cue.model):FindFirstChild(name, true)
	if a and a:IsA("Attachment") and a.Parent and a.Parent:IsA("BasePart") then
		return a.Parent, a.Position
	end
	local p = part(cue, fallback)
	return p, Vector3.zero
end

local function mount(items, parent, position, templateName)
	local source = template(templateName)
	if not source or not parent then
		return
	end
	local a = Instance.new("Attachment")
	a.Name = "Ape" .. templateName
	a.Position = position
	a.Parent = parent
	table.insert(items, a)
	for _, e in source:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = true
			c.Parent = a
			local base = e:GetAttribute("BaseRate")
			table.insert(items, { e = c, base = if type(base) == "number" then base else 0, name = e.Name })
		end
	end
end

local function phaseOf(cue)
	local p = cue.model:GetAttribute("Phase")
	return if type(p) == "number" then math.clamp(p, 1, 3) else 1
end

local function applyAura(cue)
	local s = state(cue.model)
	local aura = s.aura
	if not aura then
		return
	end
	local health, max = cue.model:GetAttribute("Health"), cue.model:GetAttribute("MaxHealth")
	local ratio = if type(health) == "number" and type(max) == "number" and max > 0 then math.clamp(health / max, 0, 1) else 1
	if s.dead or ratio <= 0 then
		for _, item in aura.items do
			if type(item) == "table" and item.e then
				item.e.Enabled = false
			end
		end
		return
	end
	local flare = if os.clock() < s.flareUntil then 2.2 else 1
	local k = (1 + (1 - ratio) * 0.8) * flare
	for _, item in aura.items do
		if type(item) == "table" and item.e then
			item.e.Enabled = true
			item.e.Rate = item.base * k
		end
	end
end

local function setEyes(cue, white)
	for _, p in tells(cue, EYES) do
		local orig = p:GetAttribute("EyeOrig")
		if orig == nil then
			orig = baseColor(p)
			p:SetAttribute("EyeOrig", orig)
		end
		local c = if white then Color3.fromRGB(235, 250, 255) else orig
		p:SetAttribute("TellBase", c)
		p.Color = c
	end
end

-- arcs jumping between fists and shoulders (phase 2+), a short beam now and then
local function arcLoop(cue)
	local s = state(cue.model)
	s.arcToken += 1
	local token = s.arcToken
	task.spawn(function()
		while s.arcToken == token and cue.model.Parent and not s.dead and phaseOf(cue) >= 2 do
			task.wait(0.5 + math.random() * 0.7)
			if s.aura and near(cue.root.Position, 140) then
				local pts = {}
				for _, n in { "KnuckleL2", "KnuckleR2", "ShoulderL_FX", "ShoulderR_FX", "BackTop" } do
					local a = body(cue.model):FindFirstChild(n, true)
					if a then
						table.insert(pts, if a:IsA("Attachment") then a.WorldPosition else a.Position)
					end
				end
				if #pts >= 2 then
					local i = math.random(#pts)
					local j = (i + math.random(#pts - 1) - 1) % #pts + 1
					boltBeam(pts[i], pts[j], 0.45, 0.16, 6, 0.1)
				end
			end
		end
	end)
end

local function buildAura(cue)
	local s = state(cue.model)
	if s.aura then
		for _, item in s.aura.items do
			if typeof(item) == "Instance" then
				item:Destroy()
			end
		end
		s.aura = nil
	end
	local phase = phaseOf(cue)
	s.phase = phase
	local items = {}
	local function at(names, templateName, hook)
		for _, n in names do
			local p, offset
			if hook then
				p, offset = hookPart(cue, n, { n })
			else
				p, offset = part(cue, { n }), Vector3.zero
			end
			if p ~= cue.root then
				mount(items, p, offset, templateName)
			end
		end
	end
	at({ "ForeArmFLBolt2", "ForeArmFRBolt2", "KnuckleL2", "KnuckleR2" }, "AuraForearm")
	at({ "ShoulderL_FX", "ShoulderR_FX", "BackTop" }, "AuraCloud", true)
	if phase >= 2 then
		at({ "KnuckleL2", "KnuckleR2" }, "AuraArcs")
		at({ "ShoulderL_FX", "ShoulderR_FX" }, "AuraArcs", true)
	end
	if phase >= 3 then
		for _, item in items do
			if type(item) == "table" and item.e and item.e.LightEmission > 0.3 then
				item.e.Color = ColorSequence.new(WHITE, VIOLET)
			end
		end
	end
	setEyes(cue, phase >= 3)
	s.aura = { items = items }
	CollectionService:AddTag(cue.model, "CraterIgnore")
	applyAura(cue)
	if phase >= 2 then
		arcLoop(cue)
	end
end

local function startAura(cue)
	local s = state(cue.model)
	if s.aura or s.dead then
		return
	end
	if part(cue, { "Chest" }) == cue.root then
		return
	end
	buildAura(cue)
	cue.model:GetAttributeChangedSignal("Health"):Connect(function()
		applyAura(cue)
	end)
	cue.model:GetAttributeChangedSignal("Phase"):Connect(function()
		if not s.dead and phaseOf(cue) ~= s.phase then
			buildAura(cue)
		end
	end)
end

local function flareAura(cue, seconds)
	local s = state(cue.model)
	s.flareUntil = os.clock() + seconds
	applyAura(cue)
	task.delay(seconds + 0.05, function()
		if cue.model.Parent then
			applyAura(cue)
		end
	end)
end

-- phase 3 turns the storm's bright layers violet
local function phaseTint(cue)
	return if phaseOf(cue) >= 3 then VIOLET else nil
end

----------------------------------------------------------------------
-- Pieces shared by several attacks
----------------------------------------------------------------------

local function knuckle(cue, side)
	return part(cue, { "Knuckle" .. side .. "2", "HandF" .. side })
end

-- the intent glint on both eyes, for the big moves
local function eyes(cue, seconds)
	for _, name in { "EyeL", "EyeR" } do
		local eye = part(cue, { name })
		if eye ~= cue.root then
			windupPlay(cue, "EyeGlint", eye.CFrame, { follow = eye, seconds = math.min(seconds, 0.5) })
		end
	end
end

-- lightning gathering in a fist through the windup
local function charge(cue, side, seconds, scale)
	local k = knuckle(cue, side)
	if k ~= cue.root then
		windupPlay(cue, "KnuckleCharge", k.CFrame, { follow = k, seconds = seconds, scale = scale, tint = phaseTint(cue) })
	end
end

local function groundFrame(cue, hook, fallback)
	local frame = point(cue, hook, fallback)
	return CFrame.new(ground(cue, frame.Position) + Vector3.new(0, 0.06, 0)) * facing(cue)
end

local function feetMid(cue)
	local l, r = groundFrame(cue, "FootBL_FX", { "FootBL" }), groundFrame(cue, "FootBR_FX", { "FootBR" })
	return CFrame.new((l.Position + r.Position) / 2) * facing(cue), l, r
end

local LIMBS = { { "FistL_FX", "HandFL" }, { "FistR_FX", "HandFR" }, { "FootBL_FX", "FootBL" }, { "FootBR_FX", "FootBR" } }

-- the feet and fists dig in to load a charge or a leap (from `from` of the windup)
local function coil(cue, seconds, from, limbs)
	atTime(cue, seconds * from, function()
		for _, spec in limbs do
			windupPlay(cue, "Coil", groundFrame(cue, spec[1], { spec[2] }), { seconds = seconds * (1 - from), scale = 1.6 })
		end
	end)
end

-- a chest beat: a fist thumps the chest; the air and sparks are knocked forward
local function chestBeat(cue, sides, scale)
	for _, side in sides do
		local frame, chest = point(cue, "ChestBeat" .. side .. "_FX", { "Chest" })
		play("ChestBeat", frame, { follow = chest, scale = scale or 1, tint = phaseTint(cue) })
	end
	local frame = point(cue, "Core", { "Chest" })
	sound("ChestBeat", frame.Position)
end

-- the roar's breath: air drawn into the mouth, lightning building over the body
local function inhale(cue, seconds)
	local frame, skull = point(cue, "Mouth", { "Skull" })
	windupPlay(cue, "Inhale", frame, { follow = skull, seconds = seconds, scale = 1.2 })
	local core, chest = point(cue, "Core", { "Chest" })
	windupPlay(cue, "BodyCrackle", core * CFrame.new(0, 2, 5), { follow = chest, seconds = seconds, tint = phaseTint(cue) })
	sound("Inhale", frame.Position)
end

-- the roar: the sound cone and rings leave the mouth, tipped a little down;
-- the air shoves dust out along the floor to the stun radius.
local function roarRelease(cue, radius, scale)
	local frame = point(cue, "Mouth", { "Skull" })
	local look = facing(cue).LookVector
	local aim = CFrame.lookAt(frame.Position, frame.Position + look - Vector3.new(0, 0.18, 0))
	play("RoarBlast", aim, { scale = scale, tint = phaseTint(cue) })
	local g = ground(cue, root(cue).Position)
	play("RoarGround", CFrame.new(g) * facing(cue), { radius = radius })
	sound("RoarBlast", frame.Position)
	sound("RoarCrackle", frame.Position)
	flareAura(cue, 1.6)
	skyFlicker(0.12)
	shake(0.3, frame.Position, 140)
end

local function shapeCircle(shape, fallbackRadius, fallbackCenter)
	local radius = if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else fallbackRadius
	local center = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else fallbackCenter
	return radius, center
end

local function lane(cue, shape)
	local length, width, look, center = 90, 8, cue.root.CFrame.LookVector, cue.root.Position
	if type(shape) == "table" and typeof(shape.cframe) == "CFrame" then
		look = shape.cframe.LookVector
		center = shape.cframe.Position
		if typeof(shape.size) == "Vector2" then
			width, length = shape.size.X, shape.size.Y
		end
	end
	return center - look * length / 2, look, length, width
end

-- the feet push off the ground
local function takeoff(cue, scale)
	local mid, l, r = feetMid(cue)
	play("Launch", l, { scale = scale })
	play("Launch", r, { scale = scale })
	return mid
end

----------------------------------------------------------------------
-- Trails that ride a moving limb or the body
----------------------------------------------------------------------

-- `name` follows `follow` for `seconds` with its emitters, Trails and Beams on;
-- `guard` (optional) stops it early
local function ride(cue, name, follow, localOffset, seconds, guard, edit)
	local s = state(cue.model)
	local trail = make(name, follow.CFrame * CFrame.new(localOffset), { edit = edit, tint = phaseTint(cue) })
	if not trail then
		return
	end
	trail.Parent = TechniqueVFX.folder
	local offset = follow.CFrame:ToObjectSpace(trail.CFrame)
	TechniqueVFX.enable(trail)
	for _, d in trail:GetDescendants() do
		if d:IsA("Trail") or d:IsA("Beam") then
			d.Enabled = true
		end
	end
	local stopped = false
	local connection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		connection:Disconnect()
		TechniqueVFX.disable(trail)
		for _, d in trail:GetDescendants() do
			if d:IsA("Trail") or d:IsA("Beam") then
				d.Enabled = false
			end
		end
		TechniqueVFX.cleanup(trail, 0.4)
	end
	connection = RunService.RenderStepped:Connect(function()
		if not trail.Parent or not follow.Parent or (guard and not guard()) then
			stop()
		else
			trail.CFrame = follow.CFrame * offset
		end
	end)
	table.insert(s.stops, stop)
	task.delay(seconds + 0.05, stop)
end

local function dashSeconds(cue, default, max)
	local seconds = cue.model:GetAttribute("DashSeconds")
	local value = if type(seconds) == "number" then seconds else default
	return math.clamp(value, 0.05, max)
end

-- dash / flight: the take-off, the air ahead of the body, the storm it sheds,
-- the limbs streaking
local function launch(cue)
	if not current(cue, "dash", 0.5) then
		return
	end
	local s = state(cue.model)
	if math.abs(s.dashAt - cue.at) <= EPSILON then
		return
	end
	s.dashAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	local attack = cue.attack
	local age = math.max(0, workspace:GetServerTimeNow() - cue.at)
	cancelWindup(cue)
	local chest = part(cue, { "Chest" })
	local function dashing()
		return current(cue, "dash", 0.5)
	end
	local function shed(seconds)
		if seconds <= 0 then
			return
		end
		local _, size = bodyBox(cue, 0.55)
		ride(cue, "SpeedShed", chest, Vector3.zero, seconds, dashing, function(copy)
			copy.Size = size
		end)
	end
	local function limbs(seconds, feet)
		if seconds <= 0 then
			return
		end
		for _, side in { "L", "R" } do
			ride(cue, "LimbTrail", knuckle(cue, side), Vector3.zero, seconds, dashing)
			if feet then
				ride(cue, "LimbTrail", part(cue, { "FootB" .. side }), Vector3.zero, seconds, dashing)
			end
		end
	end
	local function bow(seconds)
		if seconds > 0 then
			ride(cue, "BowWave", chest, Vector3.zero, seconds, dashing)
		end
	end
	if attack == "bodySlam" then
		local d = dashSeconds(cue, 0.55, 0.8) - age
		bow(d)
		shed(d)
	elseif attack == "thunderRush" then
		local d = dashSeconds(cue, 0.7, 1.2) - age
		if d > 0 then
			local mid = takeoff(cue, 1.1)
			sound("RushLaunch", mid.Position)
			bow(d)
			shed(d)
			limbs(d, false)
		end
	elseif attack == "skyfallSlam" then
		local mid = takeoff(cue, 1.5)
		sound("Launch", mid.Position)
		local d = FLIGHT.skyfallSlam - age
		limbs(d, true)
		shed(d)
	elseif attack == "judgment" then
		local d = FLIGHT.judgment - age
		limbs(d, true)
		shed(d)
	elseif attack == "bound" then
		local mid = takeoff(cue, 0.5)
		sound("Launch", mid.Position, 0.3)
	end
end

----------------------------------------------------------------------
-- Boulder
----------------------------------------------------------------------

-- boulderHurl's windup (`seconds` from the cue): the rock is torn out of the
-- floor at the right fist (0 -> rip), rides the fist up, is charged with
-- lightning for the last 0.25 s before the throw (THROW_FLIGHT before the
-- windup ends). The flight is the server's projectile (cue "boulder", drawn
-- below), which takes this rock over; an interrupted windup takes it away.
local function boulderWindup(cue, seconds)
	local s = state(cue.model)
	local generation = s.generation
	local release = math.max(0.3, seconds - THROW_FLIGHT)
	local rip = math.min(0.6, release * 0.48)
	local tpl = template("BoulderRock")
	if not tpl then
		return
	end
	local rock = tpl:Clone()
	rock.Name = "ApeBoulder"
	local half = rock.Size.Y / 2
	local fist = knuckle(cue, "R")
	local floor = ground(cue, fist.Position)
	local buried = floor - Vector3.new(0, half * 0.9, 0)
	local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	rock.CFrame = CFrame.new(buried) * spin
	rock.Parent = TechniqueVFX.folder
	local skin = make("BoulderSkin", rock.CFrame)
	if skin then
		skin.Parent = TechniqueVFX.folder
		TechniqueVFX.enable(skin)
	end
	local held = { rock = rock, skin = skin, spin = spin }
	s.boulder = rock
	s.held = held
	local charged = false
	local connection
	local function drop()
		connection:Disconnect()
		if s.held == held then
			s.held = nil
		end
	end
	-- the projectile drawer takes the rock and skin; nothing is destroyed here
	function held.take()
		drop()
		if s.boulder == rock then
			s.boulder = nil
		end
		return rock, skin
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - cue.at
		-- cancelWindup destroys s.boulder; the skin goes with it. A throw that
		-- never arrives (0.6 s past release) is dropped the same way.
		if s.generation ~= generation or s.boulder ~= rock or not rock.Parent or not fist.Parent or t > release + 0.6 then
			drop()
			rock:Destroy()
			if skin then
				skin:Destroy()
			end
			return
		end
		local hold = fist.Position + Vector3.new(0, half * 0.85, 0)
		local pos = hold
		if t < rip then
			local a = math.clamp(t / rip, 0, 1)
			pos = buried:Lerp(hold, 1 - (1 - a) * (1 - a))
		end
		rock.CFrame = CFrame.new(pos) * spin
		if skin then
			skin.CFrame = rock.CFrame
		end
		if not charged and t >= release - 0.25 then
			charged = true
			play("BoulderCharge", rock.CFrame, { follow = rock, rotate = false, seconds = math.max(0.1, release - t), tint = phaseTint(cue) })
		end
	end)
end

----------------------------------------------------------------------
-- Projectiles (server-simulated; ProjectileView flies them and calls these)
----------------------------------------------------------------------

-- a cue-shaped table for helpers that take one (ground raycasts skip the ape)
local function ownerCue(shot)
	local model = shot.owner
	local main = model and model:FindFirstChild("HumanoidRootPart")
	if not (model and main and main:IsA("BasePart")) then
		return nil
	end
	return { model = model, root = main, at = shot.startedAt }
end

local function floorUnder(shot, position)
	local c = ownerCue(shot)
	if c then
		return ground(c, position)
	end
	local hit = workspace:Raycast(position, Vector3.new(0, -200, 0))
	return if hit then hit.Position else position - Vector3.new(0, 10, 0)
end

-- the rock's diameter: data.size is its hit radius (5 -> a 10-stud rock)
local function sizeOf(shot, fallback)
	local data = shot.data
	local size = data and data.size
	return if type(size) == "number" then size * 2 else fallback
end

-- the boulder: the rock in the ape's hand flies on (or a fresh one appears at
-- the shot), shedding grit with its dust trail on; its shadow tracks under it
-- and darkens as it comes down; it shatters where the server ends it
local function boulderStart(shot)
	local c = ownerCue(shot)
	local s = c and state(c.model)
	local rock, skin, spin
	if s and s.held then
		spin = s.held.spin
		rock, skin = s.held.take()
	end
	local tpl = template("BoulderRock")
	if not rock and tpl then
		rock = tpl:Clone()
		rock.Name = "ApeBoulder"
		rock.Parent = TechniqueVFX.folder
	end
	if not rock then
		return
	end
	sound("BoulderThrow", rock.Position)
	spin = spin or CFrame.Angles(math.random() * 6, math.random() * 6, 0)
	local diameter = sizeOf(shot, rock.Size.Magnitude / math.sqrt(3))
	local k = diameter / (rock.Size.Magnitude / math.sqrt(3))
	if math.abs(k - 1) > 0.05 then
		rock.Size *= k
	end
	if not skin then
		skin = make("BoulderSkin", rock.CFrame, { scale = k })
		if skin then
			skin.Parent = TechniqueVFX.folder
			TechniqueVFX.enable(skin)
		end
	end
	if skin then
		for _, d in skin:GetDescendants() do
			if d:IsA("Trail") then
				d.Enabled = true
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = true
				d.Rate = math.max(d.Rate * 2, 8)
			end
		end
	end
	local shadow = make("BoulderShadow", CFrame.new(floorUnder(shot, shot.state.position)))
	if shadow then
		shadow.Parent = TechniqueVFX.folder
		TechniqueVFX.enable(shadow)
	end
	shot.visual = { rock = rock, skin = skin, shadow = shadow, spin = spin, diameter = diameter, t = 0 }
end

local function boulderStep(shot, position, velocity, dt)
	local v = shot.visual
	if not v then
		return
	end
	v.t += dt
	v.rock.CFrame = CFrame.new(position) * v.spin * CFrame.Angles(v.t * 9, v.t * 6, 0)
	if v.skin then
		-- the skin keeps world up so its trail stays an upright ribbon
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		v.skin.CFrame = if flat.Magnitude > 0.1 then CFrame.lookAt(position, position + flat) else CFrame.new(position)
	end
	if v.shadow then
		local floor = floorUnder(shot, position)
		v.shadow.CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0))
		local height = math.max(0, position.Y - floor.Y)
		-- close to the floor: as wide as the rock and dark; high up: wide and faint
		local close = math.clamp(1 - height / 40, 0, 1)
		local radius = v.diameter * (0.55 + 0.6 * close)
		for _, e in v.shadow:GetDescendants() do
			if e:IsA("ParticleEmitter") then
				e.Size = NumberSequence.new(radius)
				e.Transparency = NumberSequence.new(0.8 - 0.45 * close)
			end
		end
	end
end

local function boulderFinish(shot, position, _reason)
	local v = shot.visual
	shot.visual = nil
	if v then
		v.rock:Destroy()
		for _, item in { v.skin, v.shadow } do
			if item then
				TechniqueVFX.disable(item)
				for _, d in item:GetDescendants() do
					if d:IsA("Trail") then
						d.Enabled = false
					end
				end
				TechniqueVFX.cleanup(item, 0.4)
			end
		end
	end
	local radius = math.max(6, v and v.diameter or 10) -- the server splashes r10
	local g = floorUnder(shot, position + Vector3.new(0, 4, 0))
	play("BoulderImpact", CFrame.new(g), { radius = radius })
	sound("BoulderImpact", g)
	shake(0.25, g, 70)
end

-- the lance: a javelin of lightning along its velocity, the floor scorched
-- under it while it flies low, an end flash and a strike where it stops
local function lanceStart(shot)
	local frame = CFrame.lookAt(shot.state.position, shot.state.position + shot.state.velocity)
	local c = ownerCue(shot)
	local violet = c and phaseOf(c) >= 3
	local bolt = make("LanceBolt", frame, { tint = if violet then VIOLET else nil })
	if not bolt then
		return
	end
	bolt.Parent = TechniqueVFX.folder
	TechniqueVFX.enable(bolt)
	for _, d in bolt:GetDescendants() do
		if d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = true
		end
	end
	play("LanceFlash", frame, { scale = 0.9 })
	sound("LanceThrow", frame.Position)
	if near(frame.Position, 90) then
		skyFlash(0.1)
	end
	shot.visual = { bolt = bolt, lastScorch = shot.state.position }
end

local function lanceStep(shot, position, velocity)
	local v = shot.visual
	if not v then
		return
	end
	if velocity.Magnitude > 0.1 then
		v.bolt.CFrame = CFrame.lookAt(position, position + velocity)
	else
		v.bolt.Position = position
	end
	if (position - v.lastScorch).Magnitude >= 11 then
		v.lastScorch = position
		local floor = floorUnder(shot, position)
		if position.Y - floor.Y < 14 then
			play("ScorchSpot", CFrame.new(floor + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.random() * 6, 0), { scale = 1.4 })
		end
	end
end

local function lanceFinish(shot, position, _reason)
	local v = shot.visual
	shot.visual = nil
	if v then
		TechniqueVFX.disable(v.bolt)
		for _, d in v.bolt:GetDescendants() do
			if d:IsA("Beam") or d:IsA("Trail") then
				d.Enabled = false
			end
		end
		TechniqueVFX.cleanup(v.bolt, 0.4)
	end
	local floor = floorUnder(shot, position + Vector3.new(0, 2, 0))
	play("LanceFlash", CFrame.new(position), { scale = 1.1 })
	if position.Y - floor.Y < 14 then
		play("BoltStrike", CFrame.new(floor), { radius = 6 })
	end
	sound("LanceImpact", position)
	shake(0.2, position, 60)
end

ProjectileView.register("boulder", { start = boulderStart, step = boulderStep, finish = boulderFinish })
ProjectileView.register("thunderLance", { start = lanceStart, step = lanceStep, finish = lanceFinish })

----------------------------------------------------------------------
-- Storm bolts and landings
----------------------------------------------------------------------

-- a bolt from its cloud (or the sky) to the floor: the stroke, then the strike
local function boltStrike(cue, center, radius, top)
	local g = ground(cue, center)
	local from = top or (g + Vector3.new(math.random() * 6 - 3, 62, math.random() * 6 - 3))
	pillarBolt(from, g, math.max(2.5, radius * 0.45))
	play("BoltStrike", CFrame.new(g) * CFrame.Angles(0, math.random() * 6, 0), { radius = radius, tint = phaseTint(cue) })
	sound("BoltStrike", g, 0.08)
	if near(g, 90) then
		skyFlash(0.08)
	end
end

----------------------------------------------------------------------
-- Cues
----------------------------------------------------------------------

function Ape.ready(cue)
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

function Ape.aggro(cue)
	if not ours(cue) then
		return
	end
	startAura(cue)
end

-- stormBolt: the strike's cloud gathers over the point for the warning, then
-- the bolt comes down out of it
local function boltWarn(cue)
	local radius, center = shapeCircle(cue.shape, 8, cue.root.Position)
	local seconds = cue.seconds or 0.9
	local g = ground(cue, center)
	local top = g + Vector3.new(0, 30, 0)
	play("BoltGather", CFrame.new(top), { seconds = seconds, tint = phaseTint(cue) })
	task.delay(seconds, function()
		if cue.model.Parent then
			boltStrike(cue, center, radius, top)
		end
	end)
end

-- poundWave: the pound's shock rolls out through the ground and bursts at r34
local function poundWave(cue)
	local radius, center = shapeCircle(cue.shape, 34, cue.root.Position)
	local seconds = cue.seconds or 0.45
	local g = ground(cue, center)
	play("PoundWave", CFrame.new(g + Vector3.new(0, 0.05, 0)), { radius = radius, seconds = seconds, tint = phaseTint(cue) })
	task.delay(seconds, function()
		play("PoundWaveEnd", CFrame.new(g + Vector3.new(0, 2.5, 0)), { radius = radius, tint = phaseTint(cue) })
		sound("PoundWave", g)
		shake(0.2, g, radius + 30)
	end)
end

local SWINGS = { clubSwing = "R", rushSwipe = "R", backhand = "L", skyfallSweep = "L" }
local BIG = { clubSwing = true, bodySlam = true, skyfallSlam = true, judgment = true, thunderRush = true, boulderHurl = true, thunderLance = true, thunderRoar = true, phaseRoar = true, stormCall = true }

function Ape.windup(cue)
	if not ours(cue) then
		return
	end
	local attack = cue.attack or ""
	local shape = cue.shape
	local s = state(cue.model)
	local isCircle = type(shape) == "table" and shape.kind == "circle" and type(shape.radius) == "number"
	if attack == "stormBolt" or (attack == "stormCall" and isCircle and shape.radius <= 12) then
		boltWarn(cue)
		return
	end
	if attack == "poundWave" or (attack == "thunderPound" and isCircle and shape.radius > 25) then
		if math.abs(s.landAt - cue.at) > EPSILON then
			s.landAt = cue.at
			poundWave(cue)
		end
		return
	end
	if (attack == "thunderRoar" or attack == "phaseRoar") and isCircle then
		s.stunR = shape.radius
	end
	if not current(cue, "windup") then
		return
	end
	local seconds = cue.seconds or WINDUP[attack]
	if not seconds or seconds <= 0 then
		return
	end
	if math.abs(s.windupAt - cue.at) <= EPSILON then
		return
	end
	cancelWindup(cue)
	s.windupAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	s.shape = shape
	if attack == "skyfallSlam" or attack == "judgment" then
		s.leapShape = shape -- the arrival follow-up's windup replaces s.shape before touchdown
	end
	s.stunR = if (attack == "thunderRoar" or attack == "phaseRoar") and isCircle then shape.radius else nil
	if attack ~= "bound" then
		flareAura(cue, math.min(seconds, 1.2) + 0.3)
	end
	if BIG[attack] then
		eyes(cue, seconds)
	end
	local side = SWINGS[attack]
	if side then
		tellUp(cue, if side == "R" then FIST_R else FIST_L, seconds * 0.9)
		charge(cue, side, seconds, 1.4)
	elseif attack == "thunderPound" then
		tellUp(cue, FISTS, seconds * 0.9)
		charge(cue, "L", seconds, 1.6)
		charge(cue, "R", seconds, 1.6)
	elseif attack == "bodySlam" then
		tellUp(cue, CHEST, seconds * 0.9)
		local frame, chest = point(cue, "Core", { "Chest" })
		windupPlay(cue, "ChestCharge", frame, { follow = chest, seconds = seconds, tint = phaseTint(cue) })
	elseif attack == "skyfallSlam" then
		local crouch = math.max(0.3, seconds - FLIGHT.skyfallSlam)
		tellUp(cue, FISTS, crouch)
		charge(cue, "L", crouch, 1.3)
		charge(cue, "R", crouch, 1.3)
		coil(cue, crouch, 0.5, { LIMBS[3], LIMBS[4] })
	elseif attack == "thunderRush" then
		tellUp(cue, FISTS, seconds * 0.9)
		charge(cue, "L", seconds, 1.1)
		charge(cue, "R", seconds, 1.1)
		coil(cue, seconds, 0.4, LIMBS)
	elseif attack == "boulderHurl" then
		local release = math.max(0.3, seconds - THROW_FLIGHT)
		local rip = math.min(0.6, release * 0.48)
		tellUp(cue, FIST_R, release)
		local floor = groundFrame(cue, "FistR_FX", { "HandFR" })
		windupPlay(cue, "BoulderRip", floor, { seconds = rip, scale = 1.6 })
		sound("BoulderRip", floor.Position)
		boulderWindup(cue, seconds)
	elseif attack == "thunderLance" then
		tellUp(cue, FIST_R, seconds * 0.9)
		-- the red lane is the server's warnLane; the javelin forms on the fist
		local _, look = lane(cue, shape)
		local k = knuckle(cue, "R")
		windupPlay(cue, "LanceForm", CFrame.lookAt(k.Position, k.Position + look), { follow = k, rotate = false, seconds = seconds, scale = 1.2, tint = phaseTint(cue) })
		-- the charge sound (sped up in its template) runs out at the throw
		windupSound(cue, "LanceCharge", k)
	elseif attack == "thunderRoar" or attack == "phaseRoar" or attack == "challenge" then
		tellUp(cue, if attack == "challenge" then { "ChestSigil", "ChestBolt", "Eye" } else nil, seconds * 0.95)
		local beats = BEATS[attack]
		for i, t in beats do
			atTime(cue, t, function()
				local both = i == #beats and attack ~= "thunderRoar"
				chestBeat(cue, if both then { "L", "R" } else { if i % 2 == 1 then "L" else "R" }, if attack == "phaseRoar" then 1.4 else 1.15)
			end)
		end
		atTime(cue, math.max(0.1, seconds - INHALE), function()
			inhale(cue, INHALE)
		end)
	elseif attack == "stormCall" then
		tellUp(cue, BACK, seconds * 0.9)
		local frame, chest = point(cue, "BackTop", { "Chest" })
		windupPlay(cue, "StormRaise", frame, { follow = chest, seconds = seconds, tint = phaseTint(cue) })
		charge(cue, "L", seconds, 1.1)
		charge(cue, "R", seconds, 1.1)
		skyDark(0.18, seconds + 2)
	elseif attack == "judgment" then
		local radius, center = shapeCircle(shape, 28, cue.root.Position)
		local crouch = math.max(0.6, seconds - FLIGHT.judgment)
		tellUp(cue, nil, crouch)
		charge(cue, "L", crouch, 1.8)
		charge(cue, "R", crouch, 1.8)
		coil(cue, crouch, 0.5, { LIMBS[3], LIMBS[4] })
		atTime(cue, crouch * 0.5, function()
			local core, chest = point(cue, "Core", { "Chest" })
			windupPlay(cue, "BodyCrackle", core * CFrame.new(0, 2, 5), { follow = chest, seconds = crouch * 0.5, scale = 1.2, tint = VIOLET })
		end)
		local top = ground(cue, center) + Vector3.new(0, JUDGE_HEIGHT, 0)
		s.cloudAt = top
		-- the cloud outlives the windup: it is the bolt's source at touchdown
		s.judgeCloud = play("JudgeCloud", CFrame.new(top), { seconds = seconds + 0.2, scale = radius / 28, tint = VIOLET })
		skyDark(0.26, seconds)
		for _, f in { 0.4, 0.7 } do
			atTime(cue, crouch * f, function()
				skyFlicker(0.08)
			end)
		end
	end
end

function Ape.strike(cue)
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
	local attack = cue.attack
	local stunR = s.stunR
	cancelWindup(cue)
	s.shape = shape -- landings read it
	if attack == "skyfallSlam" or attack == "thunderRush" or attack == "bodySlam" or attack == "bound" then
		launch(cue)
		return
	end
	if attack == "judgment" then
		-- the storm strikes the ape as it leaps: it carries the bolt down
		launch(cue)
		local frame = point(cue, "Core", { "Chest" })
		local top = s.cloudAt or (frame.Position + Vector3.new(0, 80, 0))
		boltBeam(top, frame.Position, 7, 0.4, 9, 0.05)
		play("BoltHit", frame, { tint = VIOLET })
		local mid = takeoff(cue, 2)
		sound("JudgmentTakeoff", frame.Position)
		sound("Launch", mid.Position)
		skyFlash(0.4)
		shake(0.3, cue.root.Position, 150)
		return
	end
	if workspace:GetServerTimeNow() - cue.at > 0.35 then
		return
	end
	local face = facing(cue)
	local side = SWINGS[attack or ""]
	if attack == "challenge" then
		roarRelease(cue, stunR or 30, 0.85)
	elseif attack == "thunderRoar" then
		roarRelease(cue, stunR or 42, 1)
	elseif attack == "phaseRoar" then
		local radius = stunR or 34
		roarRelease(cue, radius, 1.15)
		-- the storm answers the roar
		local g = ground(cue, cue.root.Position)
		for i = 1, 4 do
			task.delay(0.15 + i * 0.1, function()
				if cue.model.Parent then
					local angle = (i / 4) * math.pi * 2 + math.random() * 0.8
					boltStrike(cue, g + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius * (0.5 + 0.35 * math.random())), 6)
				end
			end)
		end
		sound("StormRaise", g)
	elseif side then
		local radius = if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else 30
		local k = knuckle(cue, side)
		local look = if type(shape) == "table" and typeof(shape.cframe) == "CFrame" then shape.cframe.LookVector else cue.root.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
		local g = ground(cue, cue.root.Position)
		local scale = radius / 30
		local at = g + look * radius * 0.45 + Vector3.new(0, 6.5 * scale, 0)
		-- the sweep is tilted along the fist's path (high on the side it starts from)
		local roll = CFrame.Angles(0, 0, math.rad(if side == "R" then 16 else -16))
		play("SwingArc" .. side, CFrame.lookAt(at, at + look) * roll, { scale = scale, tint = phaseTint(cue) })
		-- the fist carries on past the target (no dead frame): its trail rides it
		ride(cue, "LimbTrail", k, Vector3.zero, 0.3)
		sound("SwingWhoosh", k.Position)
		shake(0.14, cue.root.Position, 70)
	elseif attack == "thunderPound" then
		local radius, center = shapeCircle(shape, 15, cue.root.Position)
		local g = ground(cue, center)
		play("PoundImpact", CFrame.new(g) * face, { radius = radius, tint = phaseTint(cue) })
		sound("PoundSlam", g)
		task.delay(0.15, sound, "PoundDebris", g)
		if near(g, 90) then
			skyFlash(0.08)
		end
		shake(0.3, center, 70)
	elseif attack == "thunderLance" then
		return -- the throw flash and the bolt are the projectile's (lanceStart)
	elseif attack == "stormCall" then
		-- the call: a bolt leaves the back for the sky
		local frame = point(cue, "BackTop", { "Chest" })
		boltBeam(frame.Position, frame.Position + Vector3.new(math.random() * 8 - 4, 70, math.random() * 8 - 4), 3.5, 0.4, 9, 0.07)
		sound("StormRaise", frame.Position)
		flareAura(cue, 2)
		skyFlicker(0.14)
		shake(0.2, cue.root.Position, 90)
	end
end

function Ape.dash(cue)
	if not ours(cue) then
		return
	end
	launch(cue)
end

-- The arrival follow-ups and skids replace the model's Attack as the dash ends,
-- so a landing is also live when Attack has moved on to its own follow-up.
local ARRIVE = {
	thunderRush = { rushSwipe = true, thunderRushSkid = true },
	skyfallSlam = { skyfallSweep = true, skyfallSlamSkid = true },
}
local function arrived(cue)
	local follow = ARRIVE[cue.attack or ""]
	local now = cue.model:GetAttribute("Attack")
	if not (follow and type(now) == "string" and follow[now]) then
		return false
	end
	local s = state(cue.model)
	local health = cue.model:GetAttribute("Health")
	return cue.model.Parent ~= nil and not s.dead and not (type(health) == "number" and health <= 0)
end

function Ape.land(cue)
	if not ours(cue) or not (current(cue, nil, 1.2) or arrived(cue)) then
		return
	end
	local s = state(cue.model)
	local attack = cue.attack
	for _, stop in s.stops do
		stop()
	end
	table.clear(s.stops)
	if math.abs(s.landAt - cue.at) <= EPSILON then
		return
	end
	s.landAt = cue.at
	s.latestAt = math.max(s.latestAt, cue.at)
	local face = facing(cue)
	if attack == "skyfallSlam" then
		local radius, center = shapeCircle(s.leapShape or s.shape, 20, cue.root.Position)
		local g = ground(cue, center)
		play("SkyfallImpact", CFrame.new(g) * face, { radius = radius, tint = phaseTint(cue) })
		sound("SkyfallLand", g)
		task.delay(0.15, sound, "PoundDebris", g)
		if near(g, 100) then
			skyFlash(0.12)
		end
		shake(0.45, g, radius + 60)
	elseif attack == "judgment" then
		local radius, center = shapeCircle(s.leapShape or s.shape, 28, cue.root.Position)
		local g = ground(cue, center)
		local top = s.cloudAt or (g + Vector3.new(0, 90, 0))
		s.cloudAt = nil
		s.judgeCloud = nil -- it finishes its own fade
		pillarBolt(top, g, 13)
		play("JudgmentImpact", CFrame.new(g) * face, { radius = radius, tint = VIOLET })
		sound("JudgmentBolt", g)
		task.delay(0.1, sound, "JudgmentQuake", g)
		skyFlash(0.4)
		shake(0.6, g, radius + 70)
	elseif attack == "bodySlam" then
		local g = ground(cue, part(cue, { "Chest" }).Position)
		play("BellyImpact", CFrame.new(g) * face, { tint = phaseTint(cue) })
		sound("BellySlam", g)
		shake(0.35, g, 90)
	elseif attack == "thunderRush" then
		for _, spec in { LIMBS[1], LIMBS[2] } do
			play("Skid", groundFrame(cue, spec[1], { spec[2] }), { scale = 1.8 })
		end
		sound("Skid", cue.root.Position)
		shake(0.2, cue.root.Position, 80)
	elseif attack == "bound" then
		local frame = feetMid(cue)
		play("Launch", frame, { scale = 0.7 })
		sound("BoundLand", frame.Position, 0.3)
	end
end

-- thunderRushSkid / skyfallSlamSkid: the knuckles and feet plough as the body
-- swings round to the target.
function Ape.skid(cue)
	if not ours(cue) then
		return
	end
	for _, spec in LIMBS do
		play("Skid", groundFrame(cue, spec[1], { spec[2] }), { scale = 1.5 })
	end
	sound("Skid", cue.root.Position, 0.3)
	shake(0.18, cue.root.Position, 60)
end

function Ape.hit(cue)
	local phase = cue.model:GetAttribute("AIState")
	local grace = (WINDUP[cue.attack or ""] or 0) + 0.7
	if not ours(cue) or not current(cue, nil, grace) or (phase ~= "windup" and phase ~= "dash" and phase ~= "recover") then
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
	local attack = cue.attack
	local heavy = attack == "thunderPound" or attack == "skyfallSlam" or attack == "judgment" or attack == "bodySlam" or attack == "boulderHurl"
	play(if heavy then "HitHeavy" else "HitStorm", frame, { scale = if heavy then 1.3 else 1, tint = phaseTint(cue) })
	sound(if heavy then "HitHeavy" else "HitStorm", torso.Position, 0.1)
	if attack == "judgment" then
		play("StunArcs", torso.CFrame, { follow = torso, tint = VIOLET })
	end
	if Players.LocalPlayer and target == Players.LocalPlayer.Character then
		hurtShake(if attack == "judgment" then 0.3 elseif heavy then 0.24 else 0.15)
	end
end

function Ape.stagger(cue)
	if not ours(cue) or not current(cue, "stagger") then
		return
	end
	local s = state(cue.model)
	cancelWindup(cue)
	clearCloud(s)
	s.shape = nil
	s.latestAt = math.max(s.latestAt, cue.at)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("StaggerPop", frame, { follow = chest, tint = phaseTint(cue) })
	local list = tells(cue)
	task.spawn(function()
		for _ = 1, 3 do
			for _, p in list do
				if p.Parent then
					p.Color = WHITE
				end
			end
			task.wait(0.06)
			for _, p in list do
				if p.Parent and not s.dead then
					p.Color = baseColor(p)
				end
			end
			task.wait(0.06)
		end
	end)
end

-- the storm in the body surges out into the new phase
function Ape.phase(cue)
	if not ours(cue) then
		return
	end
	local phase = phaseOf(cue)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("PhaseSurge", frame, { follow = chest, rotate = false, tint = if phase >= 3 then VIOLET else nil })
	sound("PhaseSurge", frame.Position)
	local list = tells(cue)
	for _, p in list do
		p.Color = WHITE
		TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = baseColor(p) }):Play()
	end
	skyFlash(0.25)
	buildAura(cue)
	flareAura(cue, 3)
	shake(0.3, cue.root.Position, 120)
end

-- Death (3.2 s): the storm leaks out of the body, faster and faster (arcs
-- crawling over it, bolts lancing out); then the last of it leaps up into the
-- sky: a twister rising round a bolt, a flash, a ground shock.
function Ape.death(cue)
	if not ours(cue) then
		return
	end
	local s = state(cue.model)
	if s.dead then
		return
	end
	cancelWindup(cue)
	clearCloud(s)
	s.dead = true
	s.arcToken += 1
	s.shape = nil
	applyAura(cue)
	local frame, chest = point(cue, "Core", { "Chest" })
	local list = tells(cue)
	for _, p in list do
		p.Color = baseColor(p):Lerp(INDIGO, 0.5)
		TweenService:Create(p, TweenInfo.new(2.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = WHITE }):Play()
	end
	sound("DeathCrackle", chest)
	local boxFrame, boxSize = bodyBox(cue, 0.6)
	local leak = play("DeathLeak", boxFrame, {
		follow = chest,
		rotate = false,
		edit = function(copy)
			copy.Size = boxSize
		end,
	})
	if leak then
		local rates = {}
		for _, e in leak:GetChildren() do
			if e:IsA("ParticleEmitter") then
				rates[e] = e.Rate
			end
		end
		task.spawn(function()
			local started = os.clock()
			while leak.Parent and os.clock() - started < 3.0 do
				local k = 0.4 + 2.4 * ((os.clock() - started) / 3.0) ^ 2
				for e, rate in rates do
					e.Rate = rate * k
				end
				task.wait(0.1)
			end
		end)
	end
	task.spawn(function()
		local started = os.clock()
		while chest.Parent do
			local t = os.clock() - started
			if t > 3.0 then
				break
			end
			local from = chest.Position + Vector3.new(0, 2, 0)
			local angle = math.random() * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0.2 + math.random() * 0.8, math.sin(angle)) * (18 + math.random() * 16)
			boltBeam(from, from + out, 0.8 + t * 0.3, 0.2, 6, 0.09)
			task.wait(math.max(0.09, 0.55 - t * 0.15))
		end
	end)
	local at = ground(cue, root(cue).Position)
	task.delay(3.05, function()
		local live = if chest.Parent then chest.Position else frame.Position
		play("DeathRelease", CFrame.new(live))
		play("DeathGround", CFrame.new(at + Vector3.new(0, 0.05, 0)))
		boltBeam(live, live + Vector3.new(math.random() * 6 - 3, 90, math.random() * 6 - 3), 5, 0.5, 10, 0.06)
		sound("DeathRelease", live)
		skyFlash(0.5)
		shake(0.4, live, 180)
		for _, p in list do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.3), { Color = SLATE }):Play()
			end
		end
	end)
end

return Ape
