--!strict
-- Fire Seal from its tier templates (ReplicatedStorage.Effects.FireSeal,
-- built from tools/vfx_specs/FireSeal.luau): the seal is thrown from the left
-- hand at Hit, lands at the zone centre (def.offset ahead, on the ground) with
-- an impact, burns there for def.seconds at exactly def.radius, pulses on every
-- damage tick (def.tick) with a burn hit on each enemy inside, and breaks with
-- a terminal burst. Caster and observers run the same code.
--
-- Tick timing: the server burns at release and then every def.tick
-- (Combat.luau, floor(seconds / tick) ticks). The client doesn't get the ticks,
-- so they're derived here from the cast time (cast() runs at Hit for the
-- caster, on receipt for observers): tick k at k * def.tick, the first one
-- held back until the seal has landed.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local CastFX = require(script.Parent.Parent.CastFX)

local FireSeal = {}

local BURN = Color3.fromRGB(255, 150, 90) -- CombatEffects.flash tint on a burn hit
local FADE_IN, FADE_OUT = 0.2, 0.35

-- Edit-mode previews set this to hold a frame: the driver stops moving the
-- held parts and no later ticks fire (tools/vfx_preview.luau freezes the rest).
FireSeal.frozen = false

local function fadeTo(part: BasePart, transparency: number, seconds: number, style: Enum.EasingStyle?)
	TweenService:Create(part, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = transparency }):Play()
end

-- Scale the X/Z of a sized instance (MeshWave attributes or a part) by k.
local function widen(value: any, k: number): any
	if typeof(value) == "Vector3" then
		return Vector3.new(value.X * k, value.Y, value.Z * k)
	end
	return value
end
local function widenAll(root: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MeshWave") then
			for _, name in { "FromSize", "ToSize" } do
				d:SetAttribute(name, widen(d:GetAttribute(name), k))
			end
		elseif d:IsA("BasePart") and d.Parent and d.Parent.Name == "Zone" then
			d.Size = widen(d.Size, k)
		end
	end
end

function FireSeal.cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	local radius = def.radius :: number
	local seconds = def.seconds :: number
	local tick = def.tick :: number
	local ground = CastFX.groundAt(origin)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local centreFlat = origin + dir * (def.offset :: number)
	local centre = CastFX.groundAt(centreFlat)
	local authored = copy:GetAttribute("AuthoredRadius")
	local k = if type(authored) == "number" and authored > 0 then radius / authored else 1
	local timeline = CastFX.phases(def)
	TechniqueVFX.fit(copy, "active", copy:GetAttribute("AuthoredActive"), timeline.active)
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	local zone = TechniqueVFX.take(copy, "Zone")
	local pulse = TechniqueVFX.take(copy, "Pulse")
	local impact = TechniqueVFX.take(copy, "Impact")
	local finale = TechniqueVFX.take(copy, "Finale")
	local at = CFrame.lookAt(centre, centre + dir)

	-- the throw: from the striking hand (Fists.4 strikes with the left), live so
	-- observers see it from the caster's replicated pose too
	local handAt = CastFX.handPosition(character, def.hand or "Left") or origin + dir * 1.6 + Vector3.new(0, 1, 0)
	local palm = copy:FindFirstChild("Palm") :: BasePart?
	local flight = 0.24
	if palm then
		palm.CFrame = CFrame.lookAt(handAt, handAt + dir)
		local target = palm.CFrame:PointToObjectSpace(centre + Vector3.new(0, 0.6, 0))
		for _, name in { "Bolt", "BoltRing" } do
			local w = palm:FindFirstChild(name)
			if w then
				w:SetAttribute("ToOffset", target)
				local d = w:GetAttribute("Duration")
				if type(d) == "number" then
					flight = d
				end
			end
		end
	end

	-- where it lands: everything on Land waits for the flight
	local land = copy:FindFirstChild("Land") :: BasePart?
	local life = seconds - flight + 0.25 -- glyphs hold to the end and fade with the rim
	if land then
		land.CFrame = at * CFrame.new(0, 0.2, 0)
		land:SetAttribute("EmitDelay", flight)
		for _, name in { "Glyph", "Glyph2", "Scorch" } do
			local e = land:FindFirstChild(name)
			if e and e:IsA("ParticleEmitter") then
				e.Lifetime = NumberRange.new(life)
			end
		end
		local body = land:FindFirstChild("Body")
		if body and body:IsA("Attachment") then
			body.WorldPosition = centre + Vector3.new(0, 1.2, 0)
		end
		local rocks = land:FindFirstChild("RockRing", true)
		if rocks then
			rocks:SetAttribute("Radius", (rocks:GetAttribute("Radius") or 3) * k)
		end
	end
	widenAll(copy, k)
	for _, part in { zone, pulse } do
		if part then
			widenAll(part, k)
		end
	end
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.rescale(copy, k)
	TechniqueVFX.emit(copy)
	if not TechniqueVFX.full and tier >= 3 and CastFX.nearCamera(centre, 45) then
		task.delay(flight, CombatEffects.shake, CombatEffects.SHAKE_BY_TIER[tier] * 0.7)
	end
	TechniqueVFX.cleanup(copy, 0.5)

	-- the sustained seal: emitters on from landing to the end, 3D parts faded
	-- in, spun and flickered by the driver below, then faded out
	local held: { { part: BasePart, offset: CFrame, show: number, spin: number, flicker: number, size: Vector3 } } = {}
	local light: PointLight? = nil
	if zone then
		zone.Size = Vector3.new(zone.Size.X * k, zone.Size.Y, zone.Size.Z * k)
		local base = zone.CFrame
		for _, d in zone:GetChildren() do
			if d:IsA("BasePart") then
				local show = d:GetAttribute("Show")
				local spin = d:GetAttribute("Spin")
				local flicker = d:GetAttribute("Flicker")
				table.insert(held, {
					part = d,
					offset = base:ToObjectSpace(d.CFrame),
					show = if type(show) == "number" then show else 0.2,
					spin = math.rad(if type(spin) == "number" then spin else 0),
					flicker = if type(flicker) == "number" then flicker else 0,
					size = d.Size,
				})
				d.Transparency = 1
			end
		end
		zone.CFrame = at * CFrame.new(0, 0.2, 0)
		light = zone:FindFirstChildOfClass("PointLight")
		zone.Parent = TechniqueVFX.folder
		TechniqueVFX.rescale(zone, k)
	end
	local started = os.clock()
	local function pose(now: number)
		if not zone then
			return
		end
		local t = now - started
		for _, h in held do
			local f = if h.flicker > 0 then 1 + h.flicker * math.sin(t * 13 + h.offset.X) * math.sin(t * 7.3) else 1
			h.part.Size = Vector3.new(h.size.X, h.size.Y * f, h.size.Z)
			h.part.CFrame = zone.CFrame * h.offset * CFrame.Angles(0, h.spin * t, 0) * CFrame.new(0, h.size.Y * (f - 1) / 2, 0)
		end
	end

	local finished = false
	local driver
	driver = RunService.Heartbeat:Connect(function()
		if zone and not zone.Parent then
			driver:Disconnect()
			return
		end
		if FireSeal.frozen or finished then
			return
		end
		pose(os.clock())
	end)

	task.delay(flight, function()
		if not zone or FireSeal.frozen then
			return
		end
		TechniqueVFX.enable(zone)
		for _, h in held do
			h.part.Transparency = 0
			fadeTo(h.part, h.show, FADE_IN)
		end
		if light then
			light.Brightness = 3.5
			TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0.7 }):Play()
		end
	end)

	-- one tick: the pulse ring, the rim flaring, and a burn hit on every enemy
	-- inside (re-queried each tick: they move in and out)
	local function onTick(index: number)
		if FireSeal.frozen then
			return
		end
		if pulse and index > 0 then -- the landing is the first pulse
			TechniqueVFX.burstAt(pulse, at * CFrame.new(0, 0.2, 0))
		end
		for _, h in held do
			if h.part.Name == "Rim" then
				h.part.Transparency = 0
				fadeTo(h.part, h.show, 0.35)
			end
		end
		if light then
			light.Brightness = 1.6
			TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0.7 }):Play()
		end
		if not impact then
			return
		end
		local targets = CastFX.targets({ kind = "zone", origin = origin, center = centre, dir = dir, radius = radius, character = character, cap = 4 })
		for _, target in targets do
			CastFX.impactAt(impact, target)
			if target.model.Parent then
				CombatEffects.flash(target.model, BURN)
			end
		end
	end
	local ticks = math.floor(seconds / tick)
	for i = 0, ticks - 1 do
		task.delay(math.max(i * tick, flight), onTick, i)
	end

	-- the end: emitters off, the hold fades out, the seal breaks with a burst
	task.delay(seconds, function()
		if FireSeal.frozen then
			return
		end
		finished = true
		if zone then
			TechniqueVFX.disable(zone)
			for _, h in held do
				fadeTo(h.part, 1, FADE_OUT, Enum.EasingStyle.Quad)
			end
		end
		if light then
			light.Brightness = 4
			TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		end
		if finale then
			local fin = finale:Clone()
			widenAll(fin, k)
			fin.CFrame = at * CFrame.new(0, 0.2, 0)
			fin.Parent = TechniqueVFX.folder
			TechniqueVFX.rescale(fin, k)
			TechniqueVFX.emit(fin)
			TechniqueVFX.cleanup(fin)
			if not TechniqueVFX.full and tier >= 4 and CastFX.nearCamera(centre, 45) then
				CombatEffects.shake(CombatEffects.SHAKE_BY_TIER[tier])
			end
		end
		task.delay(1.6, function()
			driver:Disconnect()
			if zone then
				zone:Destroy()
			end
			for _, inst in { pulse, impact, finale } do
				if inst then
					inst:Destroy()
				end
			end
		end)
	end)
	return true
end

return FireSeal
