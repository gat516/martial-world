--!strict
-- Sword Qi Wave from its tier template (ReplicatedStorage.Effects.SwordQiWave,
-- built from tools/vfx_specs/SwordQiWave.luau). Called by CombatEffects.cast at
-- Hit, for the caster and observers alike.
--
-- The release flashes on the right hand (Fists.3 sweeps the right arm flat
-- across the front through Hit), then a crescent of Beams (part "Blade") flies
-- the line on the template's TravelCurve, drawing a glowing slit on the ground
-- that cools into an ink scar. Every enemy on the line gets an impact as the
-- blade's front reaches its near side; the blade ends in a terminal burst at
-- max range, or earlier where a wall or rising ground stops it.
--
-- The blade's travel is a tween registered in TechniqueVFX.waves, so Edit-mode
-- previews can pause it for a capture like the MeshWave shockwaves.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)

local SIDE = "Right" -- the striking arm in Fists.3 (def.hand when it's set)

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

-- Progress (0..1) along a NumberSequence at time fraction t.
local function sample(curve: NumberSequence, t: number): number
	local kps = curve.Keypoints
	if t <= 0 then
		return kps[1].Value
	end
	for i = 2, #kps do
		local a, b = kps[i - 1], kps[i]
		if t <= b.Time then
			local k = (t - a.Time) / math.max(b.Time - a.Time, 1e-4)
			return a.Value + (b.Value - a.Value) * k
		end
	end
	return kps[#kps].Value
end

-- Rays along the path stop on world geometry only (walls, rising ground):
-- not characters, enemies, effects or non-colliding decoration.
local function pathParams(character: Model?): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local list: { Instance } = { workspace.CurrentCamera, TechniqueVFX.folder }
	if character then
		table.insert(list, character)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, enemy in CollectionService:GetTagged("Enemy") do
		table.insert(list, enemy)
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		table.insert(list, temp)
	end
	params.FilterDescendantsInstances = list
	return params
end

-- A scaled copy of the blade for the echo blades (attachments and beam widths).
local function scaledBlade(blade: BasePart, k: number, fade: number, echo: boolean): BasePart
	local copy = blade:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position *= k
		elseif d:IsA("Beam") then
			d.Width0 *= k
			d.Width1 *= k
			d.CurveSize0 *= k
			d.CurveSize1 *= k
			local kps = {}
			for _, kp in d.Transparency.Keypoints do
				table.insert(kps, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * (1 - fade)))
			end
			d.Transparency = NumberSequence.new(kps)
		elseif echo and (d:IsA("PointLight") or (d:IsA("ParticleEmitter") and d:GetAttribute("Shed"))) then
			d:Destroy()
		end
	end
	return copy
end

local function setBeams(blade: Instance, on: boolean)
	for _, d in blade:GetDescendants() do
		if d:IsA("Beam") then
			d.Enabled = on
		elseif d:IsA("ParticleEmitter") and d:GetAttribute("Shed") then
			d.Enabled = on
		end
	end
end

-- A tween on a NumberValue that previews can pause (TechniqueVFX.waves).
local function drive(seconds: number, onStep: (number) -> (), onDone: () -> ())
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Value = seconds })
	TechniqueVFX.waves[tween] = true
	tween.Completed:Once(function()
		TechniqueVFX.waves[tween] = nil
		value:Destroy()
		onDone()
	end)
	tween:Play()
end

-- A ground strip (the cut or the scar) from `a` to `b` (ground points).
local function placeStrip(strip: BasePart, a: Vector3, b: Vector3, width: number)
	local length = math.max((b - a).Magnitude, 0.05)
	strip.Size = Vector3.new(width, strip.Size.Y, length)
	strip.CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, strip.Size.Y / 2, 0)
end

local function fadeStrip(strip: BasePart, seconds: number, delay: number, color: Color3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if color then
		goal.Color = color
	end
	local tween = TweenService:Create(strip, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay), goal)
	TechniqueVFX.waves[tween] = true
	tween.Completed:Once(function()
		TechniqueVFX.waves[tween] = nil
		strip:Destroy()
	end)
	tween:Play()
end

local function cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return false
	end
	dir = dir.Unit
	local groundY = CastFX.groundBelow(origin)
	local ground = Vector3.new(origin.X, groundY, origin.Z)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local length = def.length :: number
	local width = def.width :: number
	local widthScale = width / num(copy, "AuthoredWidth", 5)
	local timeline = CastFX.phases(def)
	TechniqueVFX.fit(copy, "active", copy:GetAttribute("AuthoredActive") :: number?, timeline.active)

	local impact = TechniqueVFX.take(copy, "Impact")
	local terminal = TechniqueVFX.take(copy, "Terminal")
	local blade = TechniqueVFX.take(copy, "Blade")
	local cut = TechniqueVFX.take(copy, "Cut")
	local scar = TechniqueVFX.take(copy, "Scar")
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	if not blade then
		copy:Destroy()
		return false
	end

	-- the release on the live hand (observers see it on the replicated pose)
	local handAt = CastFX.handPosition(character, def.hand or SIDE) or (origin + dir * 1.2 + Vector3.new(0, 0.5, 0))
	local hand = copy:FindFirstChild("Hand") :: BasePart?
	if hand then
		hand.CFrame = CFrame.lookAt(handAt, handAt + dir)
	end

	-- the path: the blade forms just in front at hand height, settles to body
	-- height and flies along the line to its length (the hitbox's far end)
	local right = dir:Cross(Vector3.yAxis)
	local flatHand = Vector3.new(handAt.X - origin.X, 0, handAt.Z - origin.Z)
	local startAlong = 1.3
	local lateral0 = math.clamp(flatHand:Dot(right), -1.5, 1.5) * 0.5
	local height = num(blade, "Height", 2.6)
	local height0 = math.clamp(handAt.Y - groundY, 1.6, 4)
	local full = length - startAlong
	local function pointAt(progress: number): Vector3
		local along = startAlong + full * progress
		local settle = math.clamp(progress * 4, 0, 1)
		local lateral = lateral0 * (1 - settle)
		local h = height0 + (height - height0) * settle
		return Vector3.new(origin.X, groundY + h, origin.Z) + dir * along + right * lateral
	end
	-- stop where a wall or rising ground blocks it
	local stopProgress = 1
	local stopNormal: Vector3? = nil
	local startPoint = pointAt(0)
	local hit = workspace:Raycast(startPoint, dir * full, pathParams(character))
	if hit then
		stopProgress = math.clamp(hit.Distance / full, 0.05, 1)
		stopNormal = hit.Normal
	end
	local travelTime = num(blade, "TravelTime", 0.36)
	local curve = blade:GetAttribute("TravelCurve")
	if typeof(curve) ~= "NumberSequence" then
		curve = NumberSequence.new(0, 1)
	end
	local travelCurve = curve :: NumberSequence
	local stopTime = CastFX.curveTime(travelCurve, travelTime, stopProgress)
	local endPoint = pointAt(stopProgress)

	-- aftermath strips: stretched along the path as the blade passes
	local cutStart = Vector3.new(startPoint.X, groundY + 0.03, startPoint.Z)
	local endGround = CastFX.groundBelow(endPoint)
	local function groundAlong(progress: number): Vector3
		local p = pointAt(progress)
		return Vector3.new(p.X, groundY + (endGround - groundY) * (progress / stopProgress) + 0.03, p.Z)
	end
	local strips: { { part: BasePart, width: number } } = {}
	for _, s in { cut, scar } do
		if s then
			s.Transparency = num(s, "StartTransparency", 0.2)
			s.CastShadow, s.CanCollide, s.CanQuery, s.CanTouch, s.Anchored = false, false, false, false, true
			s.Parent = TechniqueVFX.folder
			table.insert(strips, { part = s, width = s.Size.X * widthScale })
			placeStrip(s, cutStart, cutStart + dir * 0.05, s.Size.X)
		end
	end
	-- the path box covers the stretch actually flown, for the motes and cracks
	local path = copy:FindFirstChild("Path") :: BasePart?
	if path then
		local a, b = groundAlong(0), groundAlong(stopProgress)
		path.Size = Vector3.new(width * 0.5, path.Size.Y, math.max((b - a).Magnitude, 1))
		path.CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.2, 0)
	end
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.emit(copy) -- the release (flash, air rings, shake) and path aftermath
	TechniqueVFX.cleanup(copy, 0.2)
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * 0.6)
	end

	-- the blade and its echoes
	local blades: { { part: BasePart, lag: number } } = {}
	local span = num(blade, "Span", 5)
	blade.Size = Vector3.new(span * widthScale, blade.Size.Y, blade.Size.Z)
	if math.abs(widthScale - 1) > 1e-3 then
		local scaled = scaledBlade(blade, widthScale, 0, false)
		blade:Destroy()
		blade = scaled
	end
	local main = blade :: BasePart
	table.insert(blades, { part = main, lag = 0 })
	local echoes = math.floor(num(main, "Echoes", 0))
	for i = 1, echoes do
		local k = num(main, "EchoScale", 0.82) ^ i
		table.insert(blades, { part = scaledBlade(main, k, 0.25 * i, true), lag = num(main, "EchoDelay", 0.045) * i })
	end
	local light = main:FindFirstChild("Light") :: PointLight?
	local tilt = CFrame.Angles(math.rad(num(main, "Pitch", 0)), 0, math.rad(num(main, "Roll", 0)))
	for _, b in blades do
		b.part.CFrame = CFrame.lookAt(startPoint, startPoint + dir) * tilt
		b.part.Parent = TechniqueVFX.folder
		setBeams(b.part, b.lag <= 0)
	end
	if light then
		light.Brightness = 2.5
	end
	local finished = false
	local lastLag = blades[#blades].lag
	local function step(t: number)
		for _, b in blades do
			local tb = math.clamp(t - b.lag, 0, stopTime)
			if t >= b.lag and not b.part:GetAttribute("_on") then
				b.part:SetAttribute("_on", true)
				setBeams(b.part, true)
			end
			local p = sample(travelCurve, tb / travelTime)
			p = math.min(p, stopProgress)
			local at = pointAt(p)
			b.part.CFrame = CFrame.lookAt(at, at + dir) * tilt
			if b.lag > 0 and tb >= stopTime then
				setBeams(b.part, false)
			end
		end
		local p = math.min(sample(travelCurve, math.min(t, stopTime) / travelTime), stopProgress)
		for _, s in strips do
			placeStrip(s.part, cutStart, groundAlong(p), s.width)
		end
		if light then
			light.Brightness = 2.5 * (1 - 0.6 * p)
		end
	end
	local function burst()
		if finished then
			return
		end
		finished = true
		-- the main blade bursts where it ends (echoes fold into it as they
		-- arrive); its trails finish their own fade
		setBeams(main, false)
		if light then
			light.Brightness = 0
		end
		if terminal then
			local at = endPoint
			local floor = Vector3.new(at.X, CastFX.groundBelow(at - dir * 0.4), at.Z)
			if stopNormal and math.abs(stopNormal.Y) < 0.6 then
				floor -= dir * 0.4 -- on a wall: burst just in front of it
			end
			-- placed (Body raised to the blade's height) before it plays, so the
			-- 3D rings start where the blade is
			local b = terminal:Clone()
			b.CFrame = CFrame.lookAt(floor, floor + dir)
			local body = b:FindFirstChild("Body")
			if body and body:IsA("Attachment") then
				body.Position = Vector3.new(0, math.max(at.Y - floor.Y, 1), 0)
			end
			b.Parent = TechniqueVFX.folder
			TechniqueVFX.emit(b)
			TechniqueVFX.cleanup(b)
			terminal:Destroy()
		end
		for _, s in strips do
			local part = s.part
			local colorAttr = part:GetAttribute("FadeColor")
			fadeStrip(part, num(part, "Fade", 0.6), num(part, "FadeDelay", 0), if typeof(colorAttr) == "Color3" then colorAttr else nil)
		end
		if not TechniqueVFX.full and tier >= 3 and CastFX.nearCamera(endPoint, 45) then
			CombatEffects.shake(0.15)
		end
	end
	drive(stopTime + lastLag, function(t)
		step(t)
		if t >= stopTime then
			burst()
		end
	end, function()
		burst()
		for _, b in blades do
			setBeams(b.part, false)
			task.delay(0.35, function()
				b.part:Destroy()
			end)
		end
	end)

	-- impacts: each enemy on the line as the blade's front reaches its near side
	local targets = CastFX.targets({ kind = "line", origin = origin, dir = dir, length = length, width = width, character = character })
	for _, target in targets do
		local along = target.progress * length
		local progress = math.clamp((along - startAlong) / full, 0, 1)
		local beyond = progress > stopProgress -- behind a wall: hit, but the blade never got there
		local delay = if beyond then stopTime else CastFX.curveTime(travelCurve, travelTime, progress)
		task.delay(delay, function()
			if impact and not beyond then
				CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
			end
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
			if target.index == 1 and tier >= 4 and not TechniqueVFX.full and CastFX.nearCamera(target.point, 45) then
				CombatEffects.shake(0.22)
			end
		end)
	end
	if impact then
		task.delay(travelTime + 0.5, function()
			impact:Destroy()
		end)
	end
	return true
end

return { cast = cast }
