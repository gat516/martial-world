--!strict
-- Twin Phoenix Cannon from its tier templates (ReplicatedStorage.Effects.
-- TwinPhoenixCannon, built from tools/vfx_specs/TwinPhoenixCannon.luau).
-- Called by CombatEffects.cast at the first Hit, for the caster and observers.
--
-- The animation (116649566757684, a marked copy of 134365896305843: Hit/Release
-- "1" 0.30, Hit Stop "1" 0.383, Hit/Release "2" 0.833, Hit Stop "2" 0.917;
-- 1.417 s) throws two overhand forward
-- strikes: the right fist comes down from over the shoulder and is fully
-- extended ~0.04 s after the first hit (0.30-0.38), then the body twists and
-- the left fist does the same at the second (0.83-0.92). Each strike fires a
-- phoenix blast down the line (def.length x def.width): the right a crimson
-- phoenix, the left a golden one, a size up (the finisher).
--
-- Per blast: a muzzle flash and 3D air rings off the live fist, a fire bird
-- (a Neon head with swept-back wings of Beams and a burning tail) flying the
-- line on TravelCurve, a fire impact on every enemy when its front reaches
-- them, a terminal explosion where it ends (max range, a wall or rising
-- ground) and a burnt streak on the ground. Between the blasts qi gathers in
-- the left fist.
--
-- Timing: cast() runs at hits[1]; the second blast is scheduled from def.hits
-- (clip seconds) at the cast's playback rate, so it follows retuned timings.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local BladeSkill = require(script.Parent.BladeSkill)
local WeaponFX = require(script.Parent.WeaponFX)

local TwinPhoenixCannon = {}

local SIDES = { "Right", "Left" } -- blast 1 = right fist (crimson), blast 2 = left (gold)
local KEYS = { "R", "L" }
local DEFAULT_HITS = { 0.30, 0.83 } -- clip seconds, when def.hits is missing
local RELEASE_LAG = 0.03 -- clip seconds from Hit to the fist's full extension

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

-- Seconds after the first hit for each blast, and the cast's playback rate:
-- CastFX.phases(def) (the live cast profile), else def.hits / def.castSpeed.
function TwinPhoenixCannon.timeline(def: any): ({ number }, number)
	local times = {}
	if type(def.hits) == "table" then
		for _, h in def.hits do
			local t = if type(h) == "table" then (h.time or h[1]) else h
			if type(t) == "number" then
				table.insert(times, t)
			end
		end
	end
	if #times == 0 then
		times = table.clone(DEFAULT_HITS)
	end
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else 1
	local ok, phases = pcall(CastFX.phases, def)
	if ok and type(phases) == "table" and type(phases.speed) == "number" and phases.speed > 0 then
		speed = phases.speed
		-- CastFX.phases(def).hits: each hit's real seconds after the first
		if type(phases.hits) == "table" and #phases.hits >= #times then
			return table.clone(phases.hits), speed
		end
	end
	local out = {}
	for i, t in times do
		out[i] = (t - times[1]) / speed
	end
	return out, speed
end

local function sample(curve: NumberSequence, t: number): number
	local kps = curve.Keypoints
	if t <= 0 then
		return kps[1].Value
	end
	for i = 2, #kps do
		local a, b = kps[i - 1], kps[i]
		if t <= b.Time then
			return a.Value + (b.Value - a.Value) * (t - a.Time) / math.max(b.Time - a.Time, 1e-4)
		end
	end
	return kps[#kps].Value
end

-- Rays along the path stop on world geometry only.
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

-- A tween on a NumberValue that previews can pause (TechniqueVFX.waves).
local function drive(seconds: number, onStep: (number) -> (), onDone: () -> ())
	local value = Instance.new("NumberValue")
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

-- Scale a blast's wings (attachments and beam widths) to the def's width.
local function scaleBlast(blast: BasePart, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in blast:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position *= k
		elseif d:IsA("Beam") then
			d.Width0 *= k
			d.Width1 *= k
			d.CurveSize0 *= k
			d.CurveSize1 *= k
		end
	end
	blast.Size = Vector3.new(blast.Size.X * k, blast.Size.Y, blast.Size.Z * k)
end

local function setFlying(blast: Instance, on: boolean)
	for _, d in blast:GetDescendants() do
		if d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = on
		elseif d:IsA("ParticleEmitter") and d:GetAttribute("Shed") then
			d.Enabled = on
		end
	end
end

-- Qi gathering into the left fist between the blasts (follows the live hand).
local function gather(copy: Instance, character: Model?, seconds: number)
	local part = TechniqueVFX.take(copy, "Gather")
	if not part then
		return
	end
	if not character or seconds <= 0.05 then
		part:Destroy()
		return
	end
	local function at(): CFrame?
		local hand = CastFX.handPosition(character, "Left")
		return if hand then CFrame.new(hand) else nil
	end
	local cf = at()
	if not cf then
		part:Destroy()
		return
	end
	TechniqueVFX.fit(part, nil, part:GetAttribute("AuthoredWindup") :: number?, seconds)
	part.CFrame = cf
	part.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(part)
	TechniqueVFX.cleanup(part, 0.2)
	local started = os.clock()
	local follow
	follow = RunService.RenderStepped:Connect(function()
		local now = at()
		if os.clock() - started > seconds or not part.Parent or not now then
			follow:Disconnect()
			return
		end
		part.CFrame = now
	end)
end

type Blast = {
	index: number,
	key: string,
	tier: number,
	def: any,
	character: Model?,
	origin: Vector3,
	dir: Vector3,
}

-- One phoenix blast: release at the fist, flight down the line, impacts, the
-- terminal burst and the burnt streak. `copy` is the spawned tier template.
local function fire(CombatEffects: any, copy: Model, b: Blast)
	local key, tier, def, dir = b.key, b.tier, b.def, b.dir
	local length = def.length :: number
	local width = def.width :: number
	local widthScale = width / num(copy, "AuthoredWidth", 6)
	local origin = b.origin
	local groundY = CastFX.groundBelow(origin)

	local fist = TechniqueVFX.take(copy, "Fist" .. key)
	local blast = TechniqueVFX.take(copy, "Blast" .. key)
	local impact = TechniqueVFX.take(copy, "Impact" .. key)
	local terminal = TechniqueVFX.take(copy, "Terminal" .. key)
	local burn = TechniqueVFX.take(copy, "Burn" .. key)
	local char = TechniqueVFX.take(copy, "Char" .. key)
	local path = TechniqueVFX.take(copy, "Path" .. key)
	if not blast then
		for _, p in { fist, impact, terminal, burn, char, path } do
			if p then
				p:Destroy()
			end
		end
		return
	end

	-- the release on the live fist (observers see it on the replicated pose)
	local handAt = CastFX.handPosition(b.character, SIDES[b.index])
		or (origin + dir * 1.8 + Vector3.new(0, 0.2, 0))
	if fist then
		fist.CFrame = CFrame.lookAt(handAt, handAt + dir)
		fist.Parent = TechniqueVFX.folder
		TechniqueVFX.emit(fist)
		TechniqueVFX.cleanup(fist)
		if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
			CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * (if b.index == 1 then 0.45 else 0.65))
		end
	end

	-- the path: the bird forms just past the fist at fist height, settles onto
	-- the line's centre at body height and flies to the line's end
	local right = dir:Cross(Vector3.yAxis)
	local flatHand = Vector3.new(handAt.X - origin.X, 0, handAt.Z - origin.Z)
	local startAlong = math.clamp(flatHand:Dot(dir) + 0.6, 1, 3.5)
	local lateral0 = math.clamp(flatHand:Dot(right), -2, 2)
	local height = num(blast, "Height", 2.4)
	local height0 = math.clamp(handAt.Y - groundY, 1.2, 4)
	local full = math.max(length - startAlong, 1)
	local function pointAt(progress: number): Vector3
		local settle = math.clamp(progress * 3, 0, 1)
		local s = settle * settle * (3 - 2 * settle)
		local along = startAlong + full * progress
		return Vector3.new(origin.X, groundY + height0 + (height - height0) * s, origin.Z) + dir * along + right * lateral0 * (1 - s)
	end
	local stopProgress, stopNormal = 1, nil :: Vector3?
	local startPoint = pointAt(0)
	local hit = workspace:Raycast(startPoint, pointAt(1) - startPoint, pathParams(b.character))
	if hit then
		stopProgress = math.clamp(hit.Distance / full, 0.05, 1)
		stopNormal = hit.Normal
	end
	local travelTime = num(blast, "TravelTime", 0.26)
	local curveAttr = blast:GetAttribute("TravelCurve")
	local curve: NumberSequence = if typeof(curveAttr) == "NumberSequence" then curveAttr else NumberSequence.new(0, 1)
	local stopTime = CastFX.curveTime(curve, travelTime, stopProgress)
	local endPoint = pointAt(stopProgress)
	local endGround = CastFX.groundBelow(endPoint)
	local function groundAlong(progress: number): Vector3
		local p = pointAt(progress)
		return Vector3.new(p.X, groundY + (endGround - groundY) * (progress / stopProgress) + 0.03, p.Z)
	end

	-- the burnt streak (a hot Neon line over a char mark) stretched behind it
	local strips: { { part: BasePart, width: number } } = {}
	local stripStart = groundAlong(0)
	for _, s in { burn, char } do
		if s then
			s.Transparency = num(s, "StartTransparency", 0.3)
			s.CastShadow, s.CanCollide, s.CanQuery, s.CanTouch, s.Anchored = false, false, false, false, true
			s.Parent = TechniqueVFX.folder
			table.insert(strips, { part = s, width = s.Size.X * widthScale })
			placeStrip(s, stripStart, stripStart + dir * 0.05, s.Size.X)
		end
	end
	if path then
		local a, c = groundAlong(0), groundAlong(stopProgress)
		path.Size = Vector3.new(width * 0.4, path.Size.Y, math.max((c - a).Magnitude, 1))
		path.CFrame = CFrame.lookAt((a + c) / 2, c) + Vector3.new(0, 0.3, 0)
		path.Parent = TechniqueVFX.folder
		TechniqueVFX.emit(path)
		TechniqueVFX.cleanup(path)
	end

	-- the bird: its Beams, trails and shed embers ride the part; its Neon
	-- head (and any other held part) is moved with it
	scaleBlast(blast, widthScale)
	local held: { { part: BasePart, offset: CFrame, show: number } } = {}
	for _, d in blast:GetChildren() do
		if d:IsA("BasePart") then
			table.insert(held, { part = d, offset = blast.CFrame:ToObjectSpace(d.CFrame), show = num(d, "Show", 0) })
		end
	end
	local tilt = CFrame.Angles(math.rad(num(blast, "Pitch", 0)), 0, 0)
	local light = blast:FindFirstChildOfClass("PointLight")
	local function place(at: Vector3)
		blast.CFrame = CFrame.lookAt(at, at + dir) * tilt
		for _, h in held do
			h.part.CFrame = blast.CFrame * h.offset
		end
	end
	place(startPoint)
	blast.Parent = TechniqueVFX.folder
	for _, h in held do
		h.part.Transparency = h.show
	end
	setFlying(blast, true)
	if light then
		light.Brightness = 2.2
	end
	local finished = false
	local function burst()
		if finished then
			return
		end
		finished = true
		setFlying(blast, false)
		for _, h in held do
			h.part.Transparency = 1
		end
		if light then
			light.Brightness = 0
		end
		if terminal then
			local floor = Vector3.new(endPoint.X, CastFX.groundBelow(endPoint - dir * 0.4), endPoint.Z)
			if stopNormal and math.abs(stopNormal.Y) < 0.6 then
				floor -= dir * 0.5 -- on a wall: explode just in front of it
			end
			local body = terminal:FindFirstChild("Body")
			if body and body:IsA("Attachment") then
				body.Position = Vector3.new(0, math.max(endPoint.Y - floor.Y, 1), 0)
			end
			terminal.CFrame = CFrame.lookAt(floor, floor + dir)
			terminal.Parent = TechniqueVFX.folder
			TechniqueVFX.emit(terminal)
			TechniqueVFX.cleanup(terminal)
			if not TechniqueVFX.full and tier >= 3 and CastFX.nearCamera(floor, 45) then
				CombatEffects.shake(if b.index == 2 then 0.2 else 0.12)
			end
		end
		for _, s in strips do
			local colour = s.part:GetAttribute("FadeColor")
			fadeStrip(s.part, num(s.part, "Fade", 0.6), num(s.part, "FadeDelay", 0), if typeof(colour) == "Color3" then colour else nil)
		end
		task.delay(0.4, function()
			blast:Destroy()
		end)
	end
	drive(stopTime, function(t)
		local p = math.min(sample(curve, t / travelTime), stopProgress)
		place(pointAt(p))
		for _, s in strips do
			placeStrip(s.part, stripStart, groundAlong(p), s.width)
		end
		if t >= stopTime then
			burst()
		end
	end, burst)

	-- impacts: every enemy on the line as the bird's front reaches it, squeezed
	-- into this blow's Hit -> Hit Stop window (the damage number shows at Hit)
	local window = WeaponFX.hitWindow(def, b.index)
	local targets = CastFX.targets({ kind = "line", origin = origin, dir = dir, length = length, width = width, character = b.character })
	for _, target in targets do
		local along = target.progress * length
		local progress = math.clamp((along - startAlong) / full, 0, 1)
		local beyond = progress > stopProgress
		local arrival = if beyond then stopTime else CastFX.curveTime(curve, travelTime, progress)
		task.delay(WeaponFX.landing(arrival, travelTime, window), function()
			if impact and not beyond then
				CastFX.impactAt(impact, target, { Kick = 2, Quake = 1 })
			end
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
		end)
	end
	if impact then
		task.delay(travelTime + 0.6, function()
			impact:Destroy()
		end)
	end
end

function TwinPhoenixCannon.cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 or type(def.length) ~= "number" or type(def.width) ~= "number" then
		return false
	end
	dir = dir.Unit
	-- once per cast, even if CombatEffects.cast comes once per hit
	if not BladeSkill.claim(character, def.id, 0.9) then
		return true
	end
	local ground = CastFX.groundAt(origin)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	CastFX.keepCratersOffEnemies()
	local times, speed = TwinPhoenixCannon.timeline(def)
	local lag = RELEASE_LAG / speed
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local function blast(i: number)
		local key = KEYS[i]
		-- later blasts fire from where the caster is now (the cast lunges)
		local from = if i > 1 and root and root.Parent then root.Position else origin
		local look = if i > 1 and root and root.Parent then Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z) else dir
		look = if look.Magnitude > 0.1 then look.Unit else dir
		fire(CombatEffects, copy, { index = i, key = key, tier = tier, def = def, character = character, origin = from, dir = look })
	end
	local function drop(key: string)
		for _, name in { "Fist", "Blast", "Impact", "Terminal", "Burn", "Char", "Path" } do
			local p = copy:FindFirstChild(name .. key)
			if p then
				p:Destroy()
			end
		end
	end
	for i = #times + 1, #KEYS do
		drop(KEYS[i]) -- fewer hits than blasts
	end
	-- blast 1 now (cast() runs at the first hit); later ones on the clip's
	-- `Release "n"` markers via BladeSkill's clip clock (the playing track on
	-- the caster, the replicated one for observers), with the def's hit time
	-- as the fallback; a cast cancelled before a blast drops it
	task.delay(lag, blast, 1)
	local clipHits = BladeSkill.hitTimes(def, DEFAULT_HITS)
	if #times >= 2 then
		local clock = BladeSkill.clock(character, def, clipHits[1])
		local seq = BladeSkill.sequence(clock, clipHits[#clipHits])
		for i = 2, math.min(#times, #KEYS) do
			local fired = false
			seq:at(clipHits[i] or (clipHits[1] + times[i] * speed), function()
				fired = true
				task.delay(lag, blast, i)
			end, { name = "Release", value = tostring(i) })
			-- the clock only drops a beat when the track was found and stopped;
			-- anything left unfired then is cleaned up below
			task.delay(times[i] + 1, function()
				if not fired then
					drop(KEYS[i])
				end
			end)
		end
		seq:start()
		-- the left fist charges between the blasts
		task.delay(lag + 0.05, gather, copy, character, math.max(times[2] - 0.05, 0))
	end
	task.delay((times[#times] or 0) + lag + 1.2, function()
		TechniqueVFX.cleanup(copy, 0.5)
	end)
	return true
end

return TwinPhoenixCannon
