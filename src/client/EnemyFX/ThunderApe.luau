--!nonstrict
-- Thunder Ape boss (template ThunderApeB) effects: storm blue-white on slate,
-- built from Effects.ThunderApe (tools/vfx_specs/ThunderApe.luau). No gold, and
-- nothing crowns or circles the head: cloud wisps sit on the back and shoulders.
-- Cues: ready/aggro (aura), windup, strike, dash, land, hit, stagger, death and
-- the server's "phase". Areas are read from each cue's `shape` (radius, centre,
-- lane); the authored templates are rescaled to them.
--
-- Contact is `strike` (windup -> dash/recover). `windup` also arrives for the
-- stormBolt and poundWave circles (AIState is recover then, so no state guard)
-- and twice for the roars (howl ring + stun circle): deduped by `at`. A
-- generation counter cancels everything an interrupted windup scheduled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local ProjectileView = require(script.Parent.Parent.ProjectileView)

local TEMPLATE = "ThunderApeB"
local WHITE = Color3.new(1, 1, 1)
local BRIGHT = Color3.fromRGB(91, 216, 255)
local RIM = Color3.fromRGB(184, 240, 255)
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
	challenge = 2.4, clubSwing = 0.8, backhand = 0.6, thunderPound = 0.85, bodySlam = 1.1, skyfallSlam = 1.95,
	thunderRush = 1.2, bound = 0.45, boulderHurl = 1.7, thunderLance = 1.4, thunderRoar = 1.3, stormCall = 1.2,
	judgment = 2.6, phaseRoar = 1.6,
}
-- fallbacks only: windup cues carry `seconds` (a leap's is windup + flight)
local FLIGHT = { skyfallSlam = 0.75, judgment = 1.0 }
local THROW_FLIGHT = 0.45 -- boulderHurl: the rock leaves the hand this long before the windup ends

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

local function retime(copy, seconds)
	local authored = copy:GetAttribute("AuthoredSeconds")
	if type(authored) ~= "number" or authored <= 0 then
		return
	end
	local k = seconds / authored
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Lifetime = NumberRange.new(d.Lifetime.Min * k, d.Lifetime.Max * k)
			for _, key in { "EmitDelay", "EmitDuration" } do
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
-- Screen: sky flicker, flash and the stormCall darkening (a short-lived
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
-- Bolts: jagged white-blue beams from the Bolt template (dark, glow, core)
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
	-- a thin indigo edge, a soft cyan glow wider than it, a white-hot core:
	-- a wide opaque Dark read as a grey tube against the sky
	local widths = { Dark = 1.25, Glow = 2.6, Core = 0.5 }
	for i = 1, n do
		for _, template_beam in tpl:GetChildren() do
			if template_beam:IsA("Beam") then
				local beam = template_beam:Clone()
				beam.Attachment0, beam.Attachment1 = points[i], points[i + 1]
				local w = width * (widths[beam.Name] or 1)
				beam.Width0, beam.Width1 = w, w
				beam.Enabled = true
				beam.Parent = holder
				table.insert(beams, { beam = beam, w = w, base = if beam.Name == "Glow" then 0.25 elseif beam.Name == "Dark" then 0.35 else 0 })
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

-- a full lightning pillar: main bolt, two forks, from the sky to a ground point
local function pillarBolt(top, bottom, width)
	boltBeam(top, bottom, width, 0.5, 10, 0.06)
	for i = 1, 2 do
		local f = 0.35 + 0.3 * math.random()
		local from = top:Lerp(bottom, f)
		local out = Vector3.new(math.random() - 0.5, -0.2, math.random() - 0.5).Unit * (14 + math.random() * 14)
		boltBeam(from, from + out + Vector3.new(0, -8, 0), width * 0.35, 0.36, 5, 0.12)
	end
end

-- The body's box (for effects that cover the whole silhouette)
----------------------------------------------------------------------

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
-- Aura
----------------------------------------------------------------------

local function hookPart(cue, name, fallback)
	local a = body(cue.model):FindFirstChild(name, true)
	if a and a:IsA("Attachment") and a.Parent and a.Parent:IsA("BasePart") then
		return a.Parent, a.Position
	end
	local p = part(cue, fallback)
	return p, Vector3.zero
end

local function mount(items, parent, position, templateName, only)
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
		if e:IsA("ParticleEmitter") and (not only or table.find(only, e.Name)) then
			local c = e:Clone()
			c.Enabled = true
			c.Parent = a
			local base = e:GetAttribute("BaseRate")
			table.insert(items, { e = c, base = if type(base) == "number" then base else 0, name = e.Name })
		end
	end
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
			if item.name == "Under" or item.name == "Array" or item.name == "Sigil" then
				item.e.Rate = item.base * (if flare > 1 then 1.6 else 1)
			else
				item.e.Rate = item.base * k
			end
		end
	end
end

local function phaseOf(cue)
	local p = cue.model:GetAttribute("Phase")
	return if type(p) == "number" then math.clamp(p, 1, 3) else 1
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

-- arcs jumping between fists and shoulders (P2+), a short beam now and then
local function arcLoop(cue)
	local s = state(cue.model)
	s.arcToken += 1
	local token = s.arcToken
	task.spawn(function()
		while s.arcToken == token and cue.model.Parent and not s.dead and phaseOf(cue) >= 2 do
			task.wait(0.35 + math.random() * 0.5)
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - cue.root.Position).Magnitude < 160 and s.aura then
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
	local function at(names, templateName, only, hook)
		for _, n in names do
			local p, offset
			if hook then
				p, offset = hookPart(cue, n, { n })
			else
				p, offset = part(cue, { n }), Vector3.zero
			end
			if p ~= cue.root then
				mount(items, p, offset, templateName, only)
			end
		end
	end
	at({ "ForeArmFLBolt2", "ForeArmFRBolt2", "KnuckleL2", "KnuckleR2" }, "AuraForearm")
	at({ "ShoulderL_FX", "ShoulderR_FX", "BackTop" }, "AuraCloud", nil, true)
	if phase >= 2 then
		at({ "KnuckleL2", "KnuckleR2" }, "AuraArcs")
		at({ "ShoulderL_FX", "ShoulderR_FX" }, "AuraArcs", nil, true)
		at({ "Core" }, "AuraSigil", nil, true)
		local main = root(cue)
		local feet = ground(cue, main.Position).Y - main.Position.Y + 0.2
		mount(items, main, Vector3.new(0, feet, 0), "AuraGround")
	end
	if phase >= 3 then
		at({ "BackTop" }, "AuraBack", nil, true)
		at({ "Core" }, "AuraMotes", nil, true)
		at({ "EyeL", "EyeR" }, "AuraEye")
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

----------------------------------------------------------------------
-- Pieces shared by several attacks
----------------------------------------------------------------------

local function knuckle(cue, side)
	return part(cue, { "Knuckle" .. side .. "2", "HandF" .. side })
end

local function eyes(cue, seconds)
	for _, name in { "EyeL", "EyeR" } do
		local eye = part(cue, { name })
		if eye ~= cue.root then
			windupPlay(cue, "EyeFlare", eye.CFrame, { follow = eye, seconds = math.min(seconds, 0.6) })
		end
	end
end

local function charge(cue, side, seconds, scale)
	local k = knuckle(cue, side)
	if k ~= cue.root then
		windupPlay(cue, "FistCharge", k.CFrame, { follow = k, seconds = seconds, scale = scale })
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

-- a chest beat: the ring and clap on the chest, the sigil flares, and the
-- floor thumps under the feet
local function beat(cue, sides, scale)
	for _, side in sides do
		local frame, chest = point(cue, "ChestBeat" .. side .. "_FX", { "Chest" })
		play("BeatPulse", frame, { follow = chest, scale = scale or 1 })
	end
	local frame, chest = point(cue, "Core", { "Chest" })
	play("SigilFlare", frame, { follow = chest, rotate = false, seconds = 0.35, scale = 0.8 })
	play("BeatGround", (feetMid(cue)), { scale = scale or 1 })
	skyFlash(0.07)
end

-- the roar's windup on the floor: the storm drawn in from the stun radius
local function roarGather(cue, radius, seconds)
	local main = root(cue)
	local g = ground(cue, main.Position)
	windupPlay(cue, "RoarGather", CFrame.new(g + Vector3.new(0, 0.5, 0)), { radius = radius, seconds = seconds })
end

-- the roar thrown forward from the mouth; its floor ring runs to the stun
-- radius. The muzzle layers keep a fixed size (only the floor follows radius).
local function roarRelease(cue, radius, strength)
	local frame = point(cue, "Mouth", { "Skull" })
	local g = ground(cue, frame.Position)
	local look = facing(cue).LookVector
	-- tip the muzzle frame down a little, so the waves sweep the ground ahead
	local aim = CFrame.lookAt(frame.Position, frame.Position + look - Vector3.new(0, 0.18, 0))
	local base = template("RoarShock")
	local authored = base and base:GetAttribute("AuthoredRadius")
	local k = if type(authored) == "number" then radius / authored else 1
	play("RoarShock", aim, {
		edit = function(copy)
			local floor = copy:FindFirstChild("Ground")
			if floor then
				floor.CFrame = aim:ToObjectSpace(CFrame.new(Vector3.new(frame.Position.X, g.Y + 0.15, frame.Position.Z)))
				for _, e in floor:GetChildren() do
					if e:IsA("ParticleEmitter") then
						e.Size = scaleSequence(e.Size, k)
						e.Speed = NumberRange.new(e.Speed.Min * k, e.Speed.Max * k)
					end
				end
			end
		end,
	})
	flareAura(cue, 1.6)
	skyFlicker(strength)
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

local function takeoff(cue, scale)
	local _, l, r = feetMid(cue)
	play("Takeoff", l, { scale = scale })
	play("Takeoff", r, { scale = scale })
end

----------------------------------------------------------------------
-- Dash trails
----------------------------------------------------------------------

local function followTrail(cue, name, follow, localOffset, seconds, wakeDrop, edit)
	local s = state(cue.model)
	local trail = make(name, follow.CFrame * CFrame.new(localOffset), { edit = edit })
	if not trail then
		return
	end
	trail.Parent = TechniqueVFX.folder
	if wakeDrop then
		local wake = trail:FindFirstChild("Wake")
		if wake then
			wake.Position = Vector3.new(0, -math.max(4, follow.Position.Y - ground(cue, follow.Position).Y), 0)
		end
	end
	local offset = follow.CFrame:ToObjectSpace(trail.CFrame)
	TechniqueVFX.enable(trail)
	local stopped = false
	local connection
	local function stop()
		if stopped then
			return
		end
		stopped = true
		connection:Disconnect()
		TechniqueVFX.disable(trail)
		TechniqueVFX.cleanup(trail, 0.3)
	end
	connection = RunService.RenderStepped:Connect(function()
		if not trail.Parent or not follow.Parent or not current(cue, "dash", 0.5) then
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
	-- the whole body sheds storm along its path (sparks, arcs, cloud left
	-- hanging where it passed): the speed read, with no copies of the body
	local function shed(seconds, density)
		if seconds <= 0 then
			return
		end
		local _, size = bodyBox(cue, 0.55)
		followTrail(cue, "SpeedShed", chest, Vector3.zero, seconds, false, function(copy)
			copy.Size = size
			for _, e in copy:GetChildren() do
				if e:IsA("ParticleEmitter") then
					e.Rate *= density or 1
				end
			end
		end)
	end
	local function limbs(seconds)
		if seconds <= 0 then
			return
		end
		for _, side in { "L", "R" } do
			followTrail(cue, "LimbTrail", knuckle(cue, side), Vector3.zero, seconds)
			followTrail(cue, "LimbTrail", part(cue, { "FootB" .. side }), Vector3.zero, seconds)
		end
	end
	if attack == "bodySlam" then
		local d = dashSeconds(cue, 0.47, 0.8)
		if age < d then
			followTrail(cue, "BodyTrail", chest, Vector3.new(0, -6, 0), d - age, true)
			shed(d - age, 0.6)
		end
	elseif attack == "thunderRush" then
		local d = dashSeconds(cue, 0.7, 1.2)
		if age < d then
			takeoff(cue, 0.8)
			followTrail(cue, "BodyTrail", chest, Vector3.new(0, -6, 0), d - age, true)
			limbs(d - age)
			shed(d - age, 1)
		end
	elseif attack == "skyfallSlam" then
		takeoff(cue, 1.5)
		local d = FLIGHT.skyfallSlam - age
		followTrail(cue, "BodyTrail", chest, Vector3.new(0, -4, 0), d)
		limbs(d)
		shed(d, 1)
	elseif attack == "judgment" then
		-- the bolt strike on the ape is judgmentStrike (called from strike)
		local d = FLIGHT.judgment - age
		followTrail(cue, "BodyTrail", chest, Vector3.new(0, -4, 0), d)
		limbs(d)
		shed(d, 1.3)
	elseif attack == "bound" then
		takeoff(cue, 0.5)
		for _, name in { "EyeL", "EyeR" } do
			local eye = part(cue, { name })
			if eye ~= cue.root then
				play("EyeFlare", eye.CFrame, { follow = eye })
			end
		end
		local d = dashSeconds(cue, 0.55, 0.8) - age
		limbs(d)
		shed(d, 0.5)
	end
end

----------------------------------------------------------------------
-- Boulder
----------------------------------------------------------------------

-- boulderHurl's windup (`seconds` from the cue): the rock is torn out of the
-- floor at the right fist (0 -> rip), rides the fist up overhead, goes white
-- with lightning for the last 0.25 s before the throw (THROW_FLIGHT before
-- the windup ends). The flight is the server's projectile (cue "boulder",
-- drawn by the drawer below), which takes this rock over when it spawns; an
-- interrupted windup takes the rock away.
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
		for _, d in skin:GetDescendants() do
			if d:IsA("Trail") then
				d.Enabled = false
			elseif d:IsA("ParticleEmitter") then
				d.Rate *= 0.5
			end
		end
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
			play("BoulderCharge", rock.CFrame, { follow = rock, rotate = false, seconds = math.max(0.1, release - t) })
			skyFlicker(0.06)
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
-- the shot), its skin's trails switch on, a shadow tracks under it and grows
-- as it comes down; the impact plays where the server ended it
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
	local startY = shot.state.position.Y
	shot.visual = { rock = rock, skin = skin, shadow = shadow, spin = spin, diameter = diameter, startY = startY, t = 0 }
end

local function boulderStep(shot, position, velocity, dt)
	local v = shot.visual
	if not v then
		return
	end
	v.t += dt
	v.rock.CFrame = CFrame.new(position) * v.spin * CFrame.Angles(v.t * 9, v.t * 6, 0)
	if v.skin then
		-- the skin keeps world up so its trail pair stays an upright ribbon
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		v.skin.CFrame = if flat.Magnitude > 0.1 then CFrame.lookAt(position, position + flat) else CFrame.new(position)
	end
	if v.shadow then
		local floor = floorUnder(shot, position)
		v.shadow.CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0))
		local height = math.max(0, position.Y - floor.Y)
		-- close to the floor: as wide as the rock and dark; high up: wide and faint
		local near = math.clamp(1 - height / 40, 0, 1)
		local radius = v.diameter * (0.55 + 0.6 * near)
		for _, e in v.shadow:GetDescendants() do
			if e:IsA("ParticleEmitter") then
				e.Size = NumberSequence.new(if e.Name == "Rim" then radius * 1.06 else radius)
				e.Transparency = NumberSequence.new(if e.Name == "Rim" then 0.75 - 0.5 * near else 0.75 - 0.45 * near)
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
				TechniqueVFX.cleanup(item, 0.3)
			end
		end
	end
	local c = ownerCue(shot)
	local radius = math.max(6, v and v.diameter or 10) -- the server splashes r10
	local g = floorUnder(shot, position + Vector3.new(0, 4, 0))
	play("BoulderImpact", CFrame.new(g), { radius = radius })
	shake(0.25, g, 70)
	if c and workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position - g).Magnitude < 80 then
		skyFlash(0.05)
	end
end

-- the lance: a javelin of lightning along its velocity, scorch spots dropped
-- on the floor under it every few studs, an end flash and bolt where it stops
local function lanceStart(shot)
	local frame = CFrame.lookAt(shot.state.position, shot.state.position + shot.state.velocity)
	local bolt = make("LanceBolt", frame)
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
	play("LanceFlash", frame, { scale = 0.8 })
	skyFlash(0.18)
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
			if d:IsA("Beam") then
				d.Enabled = false
			end
		end
		TechniqueVFX.cleanup(v.bolt, 0.3)
	end
	local floor = floorUnder(shot, position + Vector3.new(0, 2, 0))
	play("LanceFlash", CFrame.new(position), { scale = 1.0 })
	if position.Y - floor.Y < 14 then
		play("BoltStrike", CFrame.new(floor), { radius = 5 })
	end
	shake(0.2, position, 60)
end

ProjectileView.register("boulder", { start = boulderStart, step = boulderStep, finish = boulderFinish })
ProjectileView.register("thunderLance", { start = lanceStart, step = lanceStep, finish = lanceFinish })

----------------------------------------------------------------------
-- Storm bolts and landings
----------------------------------------------------------------------

local function boltStrike(cue, center, radius, visual)
	local g = ground(cue, center)
	play("BoltStrike", CFrame.new(g) * facing(cue), { radius = radius })
	pillarBolt(g + Vector3.new(math.random() * 6 - 3, 62, math.random() * 6 - 3), g, radius * 0.5)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - g).Magnitude < 90 then
		skyFlash(if visual then 0.05 else 0.1)
	end
end

local function pillarLanding(cue, center, radius, big)
	local g = ground(cue, center)
	play("PillarImpact", CFrame.new(g) * facing(cue), {
		radius = radius,
		edit = function(copy)
			if big then
				for _, d in copy:GetDescendants() do
					if d:IsA("ParticleEmitter") and d.Name:sub(1, 6) == "Scorch" then
						d.Lifetime = NumberRange.new(d.Lifetime.Min * 2, d.Lifetime.Max * 2)
					end
				end
			end
		end,
	})
	pillarBolt(g + Vector3.new(0, if big then 90 else 46, 0), g, if big then 14 else 6)
	shake(if big then 0.55 else 0.4, g, radius + 60)
	skyFlash(if big then 0.4 else 0.22)
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
	skyFlicker(0.1)
end

local function boltWarn(cue)
	local radius, center = shapeCircle(cue.shape, 8, cue.root.Position)
	local seconds = cue.seconds or 0.9
	local g = ground(cue, center)
	play("BoltWarn", CFrame.new(g + Vector3.new(0, 0.06, 0)), { radius = radius, seconds = seconds })
	task.delay(seconds, function()
		if cue.model.Parent then
			boltStrike(cue, center, radius, false)
		end
	end)
end

local function poundWave(cue)
	local radius, center = shapeCircle(cue.shape, 34, cue.root.Position)
	local seconds = cue.seconds or 0.45
	local g = ground(cue, center)
	play("PoundWave", CFrame.new(g + Vector3.new(0, 0.05, 0)), { radius = radius, seconds = seconds })
	task.delay(seconds, function()
		play("PoundWaveEnd", CFrame.new(g + Vector3.new(0, 1, 0)), { scale = radius / 16 })
	end)
end

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
	s.stunR = if (attack == "thunderRoar" or attack == "phaseRoar") and isCircle then shape.radius else nil
	if attack ~= "bound" then
		flareAura(cue, math.min(seconds, 1.2) + 0.3)
	end
	if attack == "challenge" then
		tellUp(cue, { "ChestSigil", "ChestBolt", "Eye" }, seconds)
		roarGather(cue, 28, seconds)
		atTime(cue, 0.4, function()
			eyes(cue, 0.6)
		end)
		atTime(cue, BEATS.challenge[1], function()
			beat(cue, { "L" })
		end)
		atTime(cue, BEATS.challenge[2], function()
			beat(cue, { "R" })
		end)
		atTime(cue, BEATS.challenge[3], function()
			beat(cue, { "L", "R" }, 1.3)
		end)
		atTime(cue, math.max(0.1, seconds - 0.4), function()
			local frame, skull = point(cue, "Mouth", { "Skull" })
			windupPlay(cue, "FistCharge", frame, { follow = skull, seconds = 0.4, scale = 1.8 })
		end)
		return
	end
	eyes(cue, seconds)
	if attack == "clubSwing" or attack == "backhand" then
		local side = if attack == "clubSwing" then "R" else "L"
		tellUp(cue, if side == "R" then FIST_R else FIST_L, seconds * 0.9)
		charge(cue, side, seconds, 1.4)
		if attack == "backhand" then
			local k = knuckle(cue, side)
			windupPlay(cue, "SnapFlare", k.CFrame, { follow = k, scale = 1.3 })
		end
	elseif attack == "thunderPound" then
		tellUp(cue, FISTS, seconds * 0.9)
		charge(cue, "L", seconds, 1.5)
		charge(cue, "R", seconds, 1.5)
	elseif attack == "bodySlam" then
		tellUp(cue, CHEST, seconds * 0.9)
		local frame, chest = point(cue, "Core", { "Chest" })
		windupPlay(cue, "SigilFlare", frame, { follow = chest, rotate = false, seconds = seconds, scale = 1.3 })
	elseif attack == "skyfallSlam" then
		local radius, center = shapeCircle(shape, 20, cue.root.Position)
		local part_seconds = math.max(0.3, seconds - FLIGHT.skyfallSlam)
		tellUp(cue, FISTS, part_seconds)
		tellUp(cue, CHEST, part_seconds)
		charge(cue, "L", part_seconds, 1.3)
		charge(cue, "R", part_seconds, 1.3)
		windupPlay(cue, "SkySigil", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { radius = radius, seconds = seconds })
	elseif attack == "thunderRush" then
		tellUp(cue, FISTS, seconds * 0.9)
		charge(cue, "L", seconds, 1.1)
		charge(cue, "R", seconds, 1.1)
	elseif attack == "boulderHurl" then
		local release = math.max(0.3, seconds - THROW_FLIGHT)
		local rip = math.min(0.6, release * 0.48)
		tellUp(cue, FIST_R, release)
		windupPlay(cue, "BoulderRip", groundFrame(cue, "FistR_FX", { "HandFR" }), { seconds = rip, scale = 2.2 })
		boulderWindup(cue, seconds)
	elseif attack == "thunderLance" then
		tellUp(cue, FIST_R, seconds * 0.9)
		-- the red lane is the server's warnLane; the javelin forms on the fist
		local _, look = lane(cue, shape)
		local k = knuckle(cue, "R")
		windupPlay(cue, "LanceForm", CFrame.lookAt(k.Position, k.Position + look), { follow = k, rotate = false, seconds = seconds, scale = 1.6 })
	elseif attack == "thunderRoar" or attack == "phaseRoar" then
		tellUp(cue, nil, seconds * 0.95)
		roarGather(cue, s.stunR or (if attack == "phaseRoar" then 34 else 42), seconds)
		for i, t in BEATS[attack] do
			atTime(cue, t, function()
				beat(cue, if attack == "phaseRoar" and i == #BEATS.phaseRoar then { "L", "R" } else { if i % 2 == 1 then "L" else "R" }, if attack == "phaseRoar" then 1.4 else 1.1)
			end)
		end
		atTime(cue, seconds - 0.45, function()
			local frame, skull = point(cue, "Mouth", { "Skull" })
			windupPlay(cue, "FistCharge", frame, { follow = skull, seconds = 0.45, scale = 1.8 })
		end)
	elseif attack == "stormCall" then
		tellUp(cue, BACK, seconds * 0.9)
		local frame, chest = point(cue, "BackTop", { "Chest" })
		windupPlay(cue, "StormGather", frame, { follow = chest, seconds = seconds, scale = 1.4 })
		local core, chest2 = point(cue, "Core", { "Chest" })
		windupPlay(cue, "SigilFlare", core, { follow = chest2, rotate = false, seconds = seconds, scale = 1.3 })
		charge(cue, "L", seconds, 1.1)
		charge(cue, "R", seconds, 1.1)
		skyDark(0.22, seconds)
	elseif attack == "judgment" then
		local radius, center = shapeCircle(shape, 28, cue.root.Position)
		local part_seconds = math.max(0.6, seconds - FLIGHT.judgment)
		tellUp(cue, nil, part_seconds)
		charge(cue, "L", part_seconds, 1.9)
		charge(cue, "R", part_seconds, 1.9)
		local main = root(cue)
		windupPlay(cue, "JudgeCloud", CFrame.new(main.Position + Vector3.new(0, 52, 0)), { follow = main, rotate = false, seconds = part_seconds, scale = 1.3 })
		windupPlay(cue, "SkySigil", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { radius = radius, seconds = seconds })
		skyDark(0.28, seconds)
		for _, f in { 0.35, 0.6, 0.85 } do
			atTime(cue, part_seconds * f, function()
				skyFlicker(0.12)
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
		launch(cue)
		local frame = point(cue, "Core", { "Chest" })
		play("BoltHit", frame)
		boltBeam(frame.Position + Vector3.new(0, 80, 0), frame.Position, 9, 0.5, 9, 0.05)
		takeoff(cue, 2.2)
		skyFlash(0.5)
		shake(0.3, cue.root.Position, 150)
		return
	end
	if workspace:GetServerTimeNow() - cue.at > 0.35 then
		return
	end
	local face = facing(cue)
	if attack == "challenge" then
		roarRelease(cue, stunR or 28, 0.2)
	elseif attack == "thunderRoar" then
		roarRelease(cue, stunR or 42, 0.25)
	elseif attack == "phaseRoar" then
		local radius = stunR or 34
		local g = ground(cue, cue.root.Position)
		play("PhaseBurst", CFrame.new(g) * face, { radius = radius })
		roarRelease(cue, radius * 0.8, 0.6)
		skyFlash(0.55)
		for i = 1, 6 do
			task.delay(0.05 + i * 0.07, function()
				if cue.model.Parent then
					local angle = (i / 6) * math.pi * 2 + math.random() * 0.5
					boltStrike(cue, g + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius * (0.35 + 0.4 * math.random())), 6, true)
				end
			end)
		end
		flareAura(cue, 3)
	elseif attack == "clubSwing" or attack == "backhand" then
		local side = if attack == "clubSwing" then "R" else "L"
		local radius = if type(shape) == "table" and type(shape.radius) == "number" then shape.radius else 30
		local k = knuckle(cue, side)
		local look = if type(shape) == "table" and typeof(shape.cframe) == "CFrame" then shape.cframe.LookVector else cue.root.CFrame.LookVector
		local origin = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else cue.root.Position
		local g = ground(cue, origin)
		play("Crescent" .. side, CFrame.new(Vector3.new(k.Position.X, g.Y + 7, k.Position.Z)) * CFrame.lookAt(Vector3.zero, look).Rotation * CFrame.new(0, 0, -4), { scale = radius / 15 })
		play("StrikeBurst", CFrame.new(g + look * radius * 0.55 + Vector3.new(0, 4, 0)) * face, { scale = 1.6 })
		shake(0.14, cue.root.Position, 70)
	elseif attack == "thunderPound" then
		local radius, center = shapeCircle(shape, 15, cue.root.Position)
		for _, side in { "L", "R" } do
			play("PoundFist", groundFrame(cue, "Fist" .. side .. "_FX", { "HandF" .. side }), { scale = 1.6 })
		end
		play("PoundRing", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)) * face, { radius = radius })
		skyFlash(0.12)
		shake(0.3, center, 25)
	elseif attack == "thunderLance" then
		return -- the throw flash and the bolt are the projectile's (lanceStart)
	elseif attack == "stormCall" then
		local frame, chest = point(cue, "BackTop", { "Chest" })
		play("PhaseArrival", frame, { follow = chest, boost = 0.4, scale = 0.5 })
		flareAura(cue, 2)
		shake(0.2, cue.root.Position, 90)
	end
end

function Ape.dash(cue)
	if not ours(cue) then
		return
	end
	launch(cue)
end

function Ape.land(cue)
	if not ours(cue) or not current(cue, nil, 1.2) then
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
		local radius, center = shapeCircle(s.shape, 20, cue.root.Position)
		pillarLanding(cue, center, radius, false)
	elseif attack == "judgment" then
		local radius, center = shapeCircle(s.shape, 28, cue.root.Position)
		pillarLanding(cue, center, radius, true)
		play("PoundWave", CFrame.new(ground(cue, center) + Vector3.new(0, 0.05, 0)), { radius = radius, seconds = 0.6 })
		play("PoundWaveEnd", CFrame.new(ground(cue, center) + Vector3.new(0, 1, 0)), { scale = radius / 14 })
	elseif attack == "bodySlam" then
		local g = ground(cue, part(cue, { "Chest" }).Position)
		play("BellyWave", CFrame.new(g + Vector3.new(0, 0.06, 0)) * face)
		skyFlash(0.1)
		shake(0.35, g, 90)
	elseif attack == "thunderRush" then
		local frame = groundFrame(cue, "FistL_FX", { "HandFL" })
		local right = groundFrame(cue, "FistR_FX", { "HandFR" })
		play("RushSkid", CFrame.new((frame.Position + right.Position) / 2) * face, { scale = 1.5 })
		shake(0.25, cue.root.Position, 80)
	elseif attack == "bound" then
		local frame = feetMid(cue)
		play("Takeoff", frame, { scale = 0.5 })
		play("PoundWaveEnd", frame * CFrame.new(0, 1, 0), { scale = 0.5 })
	end
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
	local heavy = attack == "thunderPound" or attack == "skyfallSlam" or attack == "judgment" or attack == "bodySlam"
	play(if heavy then "HitHeavy" else "HitStorm", frame, { scale = if heavy then 1.3 else 1 })
	if attack == "judgment" then
		play("StunFlash", frame)
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
	s.shape = nil
	s.latestAt = math.max(s.latestAt, cue.at)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("StaggerPop", frame, { follow = chest })
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
	local flash = Instance.new("Highlight")
	flash.FillColor = WHITE
	flash.FillTransparency = 0.25
	flash.OutlineTransparency = 1
	flash.Parent = cue.model
	task.delay(0.08, function()
		flash:Destroy()
	end)
end

function Ape.phase(cue)
	if not ours(cue) then
		return
	end
	local phase = phaseOf(cue)
	local frame, chest = point(cue, "Core", { "Chest" })
	play("PhaseArrival", frame, { follow = chest, tint = if phase >= 3 then VIOLET else nil })
	skyFlash(0.3)
	buildAura(cue)
	flareAura(cue, 3)
	shake(0.3, cue.root.Position, 120)
end

-- Death (3.2 s): the sigil overloads and bolts lance out of the body, faster
-- and faster; then a white flash and shock ring, storm-cloud puffs, a
-- spirit-core glint at the Core and a slow rise of motes.
function Ape.death(cue)
	if not ours(cue) then
		return
	end
	local s = state(cue.model)
	if s.dead then
		return
	end
	cancelWindup(cue)
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
	play("DeathBuild", frame, { follow = chest, seconds = 3.0 })
	for i, t in { 0, 0.8, 1.5, 2.1, 2.6 } do
		task.delay(t, function()
			if chest.Parent then
				local f = point(cue, "Core", { "Chest" })
				play("SigilFlare", f, { follow = chest, rotate = false, seconds = 0.6, scale = 1 + i * 0.15 })
			end
		end)
	end
	-- the storm spirit streams up out of the whole body, ramping to a torrent
	local boxFrame, boxSize = bodyBox(cue, 0.7)
	local soul = play("DeathSoul", boxFrame, {
		follow = chest,
		rotate = false,
		seconds = 3.0,
		edit = function(copy)
			copy.Size = boxSize
		end,
	})
	if soul then
		local rates = {}
		for _, e in soul:GetChildren() do
			if e:IsA("ParticleEmitter") then
				rates[e] = e.Rate
			end
		end
		task.spawn(function()
			local started = os.clock()
			while soul.Parent and os.clock() - started < 3.0 do
				local k = 0.4 + 2.2 * ((os.clock() - started) / 3.0) ^ 2
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
			local out = Vector3.new(math.cos(angle), 0.2 + math.random() * 0.8, math.sin(angle)) * (24 + math.random() * 22)
			boltBeam(from, from + out, 0.9 + t * 0.35, 0.22, 6, 0.09)
			if t > 1.8 then
				local f2 = body(cue.model):FindFirstChild("BackTop", true)
				if f2 and f2:IsA("Attachment") then
					boltBeam(f2.WorldPosition, f2.WorldPosition + Vector3.new(math.random() * 16 - 8, 24, math.random() * 16 - 8), 1.2, 0.2, 5, 0.1)
				end
			end
			task.wait(math.max(0.07, 0.5 - t * 0.15))
		end
	end)
	local at = ground(cue, root(cue).Position)
	task.delay(3.05, function()
		local live = if chest.Parent then chest.Position else frame.Position
		play("DeathBurst", CFrame.new(live))
		play("DeathSpirit", CFrame.new(at + Vector3.new(0, 0.05, 0)), { radius = 14 })
		skyFlash(0.7)
		shake(0.4, live, 180)
		for _, p in list do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.3), { Color = SLATE }):Play()
			end
		end
	end)
end

return Ape
