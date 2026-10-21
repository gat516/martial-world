--!strict
-- Lightning Talisman's cast (CombatEffects.cast dispatches here; templates
-- are ReplicatedStorage.Effects.LightningTalisman.LightningTalisman_T1..T4,
-- built from tools/vfx_specs/LightningTalisman.luau).
--
-- At Hit the talisman card leaves the left hand (Fists.2 flings it with the
-- left), flies on a low arc to a point above the first target in `chain`, and
-- a bolt slams down from it; then a bolt hops to each next target every
-- HopDelay seconds. Every target gets an impact (flash, 3D impact torus and
-- ground shock, crackling arcs, II+ scorch, seals by tier); the last gets the
-- Finale (the impact one tier up, an electric ring, shake, III+ rocks). With
-- no target the card flies to max range (or the wall it meets) and bursts
-- there (Fizzle), earthing a short bolt into the ground. IV adds the sky
-- strike on the first target.
--
-- Bolts are Beams on a jittered attachment chain, drawn here in both modes
-- (with or without the Game Module), so every client sees the same thing.
-- Damage already landed at Hit (Combat applies it to the whole chain at
-- once); the hops are a short visual stagger.
--
-- Everything after release runs off one Tween (registered in
-- TechniqueVFX.waves), so Edit-mode previews can pause it for a capture.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local CastFX = require(script.Parent.Parent.CastFX)

local HAND = "Left" -- Fists.2 throws with the left hand (def.hand overrides)
local SKY_HEIGHT = 55
local BURN = 0.32 -- seconds the card burns away above the first target

local rng = Random.new()

local function attr(inst: Instance, name: string, default: any): any
	local v = inst:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The chain when the payload has none (an Edit-mode preview): the server's
-- rule (Combat.chainTargets): the nearest enemy in range, preferring those in
-- front, then each nearest unhit enemy within jumpRange of the last.
local function predict(origin: Vector3, aim: Vector3, def: Techniques.Def, character: Model?): { Model }
	local alive: { Model } = {}
	for _, model in CollectionService:GetTagged("Enemy") do
		if model:IsA("Model") and model ~= character and Hitbox.alive(model) then
			table.insert(alive, model)
		end
	end
	local hits: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local first, firstScore = nil, math.huge
	for _, model in alive do
		local offset = flat(model:GetPivot().Position - origin)
		local d = offset.Magnitude
		if d <= (def.range :: number) then
			local score = d * (if d > 0 and aim:Dot(offset.Unit) < 0 then 2 else 1)
			if score < firstScore then
				first, firstScore = model, score
			end
		end
	end
	local current = first
	while current and #hits < (def.jumps :: number) + 1 do
		table.insert(hits, current)
		seen[current] = true
		local from = current:GetPivot().Position
		local nextOne, best = nil, def.jumpRange :: number
		for _, model in alive do
			local d = flat(model:GetPivot().Position - from).Magnitude
			if not seen[model] and d <= best then
				nextOne, best = model, d
			end
		end
		current = nextOne
	end
	return hits
end

-- Where a bolt coming from `from` meets a target right now: its body on the
-- near side, the ground under that, and the CastFX.Target for impactAt.
-- `upper` is where hop bolts leave and land: high on the near side, so the
-- jumps arc over the bodies instead of hiding inside them.
type Hit = { body: Vector3, top: Vector3, upper: Vector3, target: CastFX.Target }
local function hitOn(model: Model, from: Vector3, fallback: Vector3, index: number, aim: Vector3): Hit
	local centre, depth, tall = fallback, 0.8, 3
	if model.Parent then
		local cf, box = model:GetBoundingBox()
		centre, depth, tall = cf.Position, math.min(box.X, box.Z) * 0.4, box.Y
	end
	local toward = flat(centre - from)
	toward = if toward.Magnitude > 0.05 then toward.Unit else aim
	local body = centre - toward * depth
	local feet = Vector3.new(body.X, CastFX.groundBelow(body) + 0.15, body.Z)
	return {
		body = body,
		top = centre + Vector3.new(0, tall * 0.5 + 3.2, 0) - toward * depth * 0.5,
		upper = centre + Vector3.new(0, tall * 0.3, 0) - toward * depth * 0.7,
		target = { model = model, point = feet, toward = toward, height = math.max(centre.Y - feet.Y, 1), progress = 0, index = index },
	}
end

-- ------------------------------------------------------------------ bolts

-- Two unit vectors perpendicular to `axis`.
local function basis(axis: Vector3): (Vector3, Vector3)
	local up = if math.abs(axis.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local s = axis:Cross(up).Unit
	return s, axis:Cross(s).Unit
end

-- A jagged bolt from a to b: `segments` straight Beams per strand between
-- jittered attachments that re-roll `flickers` times, snap in, hold and thin
-- out late. o: width, segments, jitter, flickers, strands, forks.
-- With the Game Module the main strand's core is the LightningBeams add-on's
-- Neon bolt (the template's Arc, emitted here for `seconds`); the glow, the
-- second strand and the forks are always these Beams.
local function makeBolt(look: Instance, a: Vector3, b: Vector3, o: { [string]: number }, seconds: number): (BasePart, (number) -> ())
	local holder = Instance.new("Part")
	holder.Name = "LightningBolt"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(a)
	local axis = b - a
	local length = math.max(axis.Magnitude, 0.1)
	local unit = axis / length
	local s, t = basis(unit)
	local amp = o.jitter * math.clamp(length / 8, 0.5, 2.2)
	local core, glow = look:FindFirstChild("Core") :: Beam?, look:FindFirstChild("Glow") :: Beam?
	local arc = look:FindFirstChild("Arc")
	local addon = TechniqueVFX.full and arc ~= nil and arc:FindFirstChild("B") ~= nil
	if addon and arc then
		-- its own holder, so the Game Module's emit sees only the Arc
		local arcHolder = holder:Clone()
		arcHolder.Name = "LightningArc"
		local copy = arc:Clone()
		copy:SetAttribute("Duration", seconds)
		copy.Parent = arcHolder
		copy.WorldPosition = a;
		(copy :: any).B.WorldPosition = b
		arcHolder.Parent = TechniqueVFX.folder
		TechniqueVFX.emit(arcHolder)
		task.delay(seconds + 0.5, function()
			arcHolder:Destroy()
		end)
	end
	local strands = {}
	for strand = 1, o.strands do
		local n = o.segments
		local points: { Attachment } = {}
		for k = 0, n do
			local at = Instance.new("Attachment")
			at.Parent = holder
			points[k + 1] = at
		end
		local beams: { { beam: Beam, w: number } } = {}
		local w = o.width * (if strand == 1 then 1 else 0.55)
		for k = 1, n do
			for _, source in { if strand == 1 and addon then nil else core, if strand == 1 then glow else nil } do
				if source then
					local beam = source:Clone()
					beam.Attachment0, beam.Attachment1 = points[k], points[k + 1]
					beam.Enabled = true
					beam.Parent = holder
					table.insert(beams, { beam = beam, w = w * (if source == glow then 3 else 1) * (1 - 0.35 * (k - 1) / n) })
				end
			end
		end
		table.insert(strands, { points = points, beams = beams, n = n, scale = if strand == 1 then 1 else 1.4 })
	end
	-- forks: short thin branches off the first strand's middle
	local forks = {}
	for _ = 1, o.forks do
		local n = 2
		local points: { Attachment } = {}
		for k = 0, n do
			local at = Instance.new("Attachment")
			at.Parent = holder
			points[k + 1] = at
		end
		local beams = {}
		for k = 1, n do
			if core then
				local beam = core:Clone()
				beam.Attachment0, beam.Attachment1 = points[k], points[k + 1]
				beam.Enabled = true
				beam.Parent = holder
				table.insert(beams, { beam = beam, w = o.width * 0.5 * (1 - 0.4 * (k - 1)) })
			end
		end
		table.insert(forks, { points = points, beams = beams, from = rng:NextInteger(2, math.max(2, o.segments - 2)) })
	end

	local function roll()
		for _, st in strands do
			for k = 0, st.n do
				local u = k / st.n
				local taper = math.sin(math.pi * u) ^ 0.6
				local off = (s * rng:NextNumber(-1, 1) + t * rng:NextNumber(-1, 1)) * amp * taper * st.scale
				local lift = Vector3.yAxis * ((o.bow or 0) * length * math.sin(math.pi * u))
				st.points[k + 1].WorldPosition = a + axis * u + lift + (if k == 0 or k == st.n then Vector3.zero else off)
			end
		end
		local main = strands[1]
		for _, f in forks do
			local root = main.points[math.min(f.from + 1, #main.points)].WorldPosition
			local away = (unit * rng:NextNumber(0.2, 0.7) + (s * rng:NextNumber(-1, 1) + t * rng:NextNumber(-1, 1)).Unit).Unit
			local reach = math.clamp(length * 0.18, 1.2, 3.2)
			for k = 0, 2 do
				local wobble = (s * rng:NextNumber(-1, 1) + t * rng:NextNumber(-1, 1)) * 0.35 * k
				f.points[k + 1].WorldPosition = root + away * reach * (k / 2) + wobble
			end
		end
	end
	roll()
	local rolled = 0
	local function setWidth(k: number, forkK: number, transparency: number)
		for _, st in strands do
			for _, b in st.beams do
				b.beam.Width0, b.beam.Width1 = b.w * k, b.w * k * 0.85
			end
		end
		for _, f in forks do
			for _, b in f.beams do
				b.beam.Width0, b.beam.Width1 = b.w * forkK, b.w * forkK * 0.3
			end
		end
		if glow then
			local seq = NumberSequence.new(transparency)
			for _, b in strands[1].beams do
				if b.beam.Name == "Glow" then
					b.beam.Transparency = seq
				end
			end
		end
	end
	setWidth(0.5, 0.5, 0.6)
	-- u: 0..1 through the bolt's life
	local function update(u: number)
		local step = math.floor(u * (o.flickers + 1))
		if step > rolled then
			rolled = step
			roll()
		end
		-- snap in, hold solid, thin out late (eased in)
		local k = if u < 0.08 then 0.5 + u / 0.08 * 0.5 elseif u < 0.55 then 1 else 1 - ((u - 0.55) / 0.45) ^ 2
		local forkK = if u < 0.6 then k else 0
		setWidth(math.max(k, 0), math.max(forkK, 0), 0.4 + 0.6 * (1 - math.max(k, 0)))
	end
	return holder, update
end

-- Play a detached template part (Impact, Finale, Fizzle, Sky) through
-- CastFX.impactAt, which raises its Body attachment before it emits.
local function playAt(part: BasePart, point: Vector3, toward: Vector3, height: number, index: number, limits: { [string]: number }?): BasePart
	local target: CastFX.Target = { model = nil :: any, point = point, toward = toward, height = height, progress = 0, index = index }
	return CastFX.impactAt(part, target, limits)
end

-- Show the (hidden) card template for its flight: paper, glyphs, rim, trail,
-- sparks and aura on.
local function showCard(card: BasePart)
	card.Transparency = 0
	for _, d in card:GetDescendants() do
		if d:IsA("Decal") then
			d.Transparency = 0
		elseif d.Name == "Rim" and d:IsA("BasePart") then
			d.Transparency = 0.4
		elseif d:IsA("Trail") or (d:IsA("ParticleEmitter") and d.Rate > 0) then
			d.Enabled = true
		end
	end
end

local function placeCard(card: BasePart, cf: CFrame)
	card.CFrame = cf
	local rim = card:FindFirstChild("Rim") :: BasePart?
	if rim then
		rim.CFrame = cf * CFrame.new(0, 0, 0.01)
	end
end

-- The card's end: it flares (star flash, ash) and burns away in place over
-- `seconds`, shrinking while the paper, glyphs and rim fade.
local function burnUpdate(card: BasePart, cf: CFrame): (number) -> ()
	for _, d in card:GetDescendants() do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	for _, name in { "Flare", "Ash" } do
		local e = card:FindFirstChild(name)
		if e and e:IsA("ParticleEmitter") then
			e:Emit(math.max(1, math.round(attr(e, "EmitCount", 1))))
		end
	end
	local size = card.Size
	local rim = card:FindFirstChild("Rim") :: BasePart?
	local rimSize = if rim then rim.Size else Vector3.one
	return function(u: number)
		local k = 1 - 0.55 * u
		card.Size = Vector3.new(size.X * k, size.Y * k, size.Z)
		card.Transparency = u ^ 0.7
		card.Color = Color3.fromRGB(240, 208, 126):Lerp(Color3.fromRGB(255, 120, 60), u)
		for _, d in card:GetChildren() do
			if d:IsA("Decal") then
				d.Transparency = u ^ 0.7
			end
		end
		if rim then
			rim.Size = Vector3.new(rimSize.X * k, rimSize.Y * k, rimSize.Z)
			rim.Transparency = 0.1 + 0.9 * u
		end
		placeCard(card, cf * CFrame.Angles(0, 0, u * 0.6))
	end
end

-- Rays along the throw stop on world geometry only (walls, rising ground):
-- not characters, enemies or effects (as in SwordQiWave's pathParams).
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

-- ------------------------------------------------------------------ cast

local Module = {}

function Module.cast(CombatEffects: any, def: Techniques.Def, level: number, character: Model?, origin: Vector3, dir: Vector3, chain: { Model }?): boolean
	local ground = CastFX.groundAt(origin)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	local cardTemplate = TechniqueVFX.take(copy, "Card")
	local look = TechniqueVFX.take(copy, "Bolt")
	local impact = TechniqueVFX.take(copy, "Impact")
	local finale = TechniqueVFX.take(copy, "Finale")
	local fizzle = TechniqueVFX.take(copy, "Fizzle")
	local sky = TechniqueVFX.take(copy, "Sky")
	if not (cardTemplate and look and impact and finale and fizzle) then
		copy:Destroy()
		return false
	end
	local o = {
		width = attr(copy, "BoltWidth", 0.5), segments = attr(copy, "Segments", 6), jitter = attr(copy, "Jitter", 1),
		flickers = attr(copy, "Flickers", 3), strands = attr(copy, "Strands", 1), forks = attr(copy, "Forks", 0),
	}
	local life = attr(copy, "BoltLife", 0.32)
	local hop = attr(copy, "HopDelay", 0.09)
	local speed = attr(copy, "CardSpeed", 115)
	local seals = attr(copy, "SealTargets", 0)
	local skyStrike = attr(copy, "SkyStrike", false) and sky ~= nil
	local shakes = CombatEffects.SHAKE_BY_TIER or { 0.14, 0.2, 0.28, 0.38 }

	-- the release, from the throwing hand
	local handAt = CastFX.handPosition(character, def.hand or HAND) or (origin + dir * 1.6 + Vector3.new(0, 1, 0))
	local handPart = copy:FindFirstChild("Hand") :: BasePart?
	if handPart then
		handPart.CFrame = CFrame.lookAt(handAt, handAt + dir)
	end
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.2)

	local folder = TechniqueVFX.folder
	local models = chain or predict(origin, dir, def, character)
	-- positions at cast time, in case a target dies (and leaves) mid-chain
	local fallbacks: { Vector3 } = {}
	for i, model in models do
		fallbacks[i] = model:GetPivot().Position
	end

	-- the timeline: events fire as the master tween passes them; actors
	-- (the card, bolts) update every frame until their life is over
	type Actor = { start: number, life: number, update: (number) -> (), done: (() -> ())? }
	local events: { { t: number, fn: () -> () } } = {}
	local actors: { Actor } = {}
	local parts: { Instance } = {}
	local function at(t: number, fn: () -> ())
		table.insert(events, { t = t, fn = fn })
	end
	local now = 0
	local function bolt(a: Vector3, b: Vector3, extra: { [string]: number }?, seconds: number?)
		local opts = table.clone(o)
		for k, v in extra or {} do
			opts[k] = v
		end
		local holder, update = makeBolt(look, a, b, opts, seconds or life)
		holder.Parent = folder
		table.insert(parts, holder)
		table.insert(actors, { start = now, life = seconds or life, update = update, done = function()
			holder:Destroy()
		end })
	end
	local function strike(index: number, from: Vector3)
		local model = models[index]
		local last = index == #models
		local h = hitOn(model, from, fallbacks[index], index, dir)
		local source = if last then finale else impact
		playAt(source :: BasePart, h.target.point, h.target.toward, h.target.height, index, { Seal = seals })
		if model.Parent then
			CombatEffects.flash(model, def.color)
		end
		if last and not TechniqueVFX.full and CastFX.nearCamera(h.body, 45) then
			CombatEffects.shake((shakes[tier] or 0.2) * 0.8)
		end
		return h
	end

	local endTime = 0
	if #models > 0 then
		local first = hitOn(models[1], handAt, fallbacks[1], 1, dir)
		local cardEnd = first.top
		local flight = math.clamp((cardEnd - handAt).Magnitude / speed, 0.08, 0.22)
		-- the card's flight
		local card = cardTemplate:Clone()
		at(0, function()
			card.Parent = folder
			table.insert(parts, card)
		end)
		local arc = math.min((cardEnd - handAt).Magnitude * 0.08, 1.5)
		local travel = cardEnd - handAt
		local face = if flat(travel).Magnitude > 0.01 then flat(travel) else dir
		local lastCf = CFrame.lookAt(handAt, handAt + face)
		local function cardUpdate(u: number)
			local e = 1 - (1 - u) ^ 1.6
			local p = handAt:Lerp(cardEnd, e) + Vector3.new(0, arc * math.sin(math.pi * e), 0)
			-- tumbling end over end, so its face flashes from every side
			lastCf = CFrame.lookAt(p, p + face) * CFrame.Angles(u * 11, 0, 0.3)
			placeCard(card, lastCf)
		end
		table.insert(actors, { start = 0, life = flight, update = cardUpdate, done = function()
			-- it hangs above the target and burns away while the bolt falls
			table.insert(actors, { start = now, life = BURN, update = burnUpdate(card, CFrame.lookAt(cardEnd, cardEnd + face)), done = function()
				card:Destroy()
			end })
		end })
		showCard(card)
		cardUpdate(0)
		-- the card flares and the first bolt slams down into the target
		at(flight, function()
			local h = strike(1, handAt)
			bolt(cardEnd, h.body, { segments = math.max(o.segments - 2, 4) })
			if skyStrike and sky then
				local top = h.body + Vector3.new(rng:NextNumber(-5, 5), SKY_HEIGHT, rng:NextNumber(-5, 5))
				bolt(top, h.body, { width = o.width * 1.6, segments = 10, jitter = o.jitter * 1.6, forks = 3 }, life * 1.2)
				local burst = playAt(sky, h.target.point, h.target.toward, 0, 1)
				local light = burst:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 4
					TweenService:Create(light, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
				end
				if not TechniqueVFX.full and CastFX.nearCamera(h.body, 45) then
					CombatEffects.shake(0.3)
				end
			end
			-- the hops, each from where the last bolt landed
			local from = h.upper
			for i = 2, #models do
				at(flight + (i - 1) * hop, function()
					local hi = strike(i, from)
					bolt(from, hi.upper, { bow = 0.18 })
					from = hi.upper
				end)
			end
		end)
		endTime = math.max(flight + (#models - 1) * hop + life * (if skyStrike then 1.2 else 1), flight + BURN)
	else
		-- no target: fly to max range or the first wall, burst there and earth
		-- a short bolt into the ground below
		-- the throw dips a little as it flies, so a ray along it meets walls
		-- and rising ground alike
		local reach = def.range :: number
		local drop = math.min(handAt.Y - CastFX.groundBelow(handAt) - 1.2, 2.5)
		local throw = dir * reach - Vector3.new(0, math.max(drop, 0), 0)
		local hit = workspace:Raycast(handAt, throw, pathParams(character))
		local stop = if hit then hit.Position - throw.Unit * 0.4 else handAt + throw
		local flight = math.clamp((stop - handAt).Magnitude / speed, 0.08, 0.24)
		local card = cardTemplate:Clone()
		showCard(card)
		card.Parent = folder
		table.insert(parts, card)
		table.insert(actors, { start = 0, life = flight, update = function(u: number)
			local p = handAt:Lerp(stop, 1 - (1 - u) ^ 1.6)
			placeCard(card, CFrame.lookAt(p, p + dir) * CFrame.Angles(u * 11, 0, 0.3))
		end, done = function()
			table.insert(actors, { start = now, life = BURN * 0.6, update = burnUpdate(card, CFrame.lookAt(stop, stop + dir)), done = function()
				card:Destroy()
			end })
		end })
		at(flight, function()
			local below = CastFX.groundBelow(stop)
			local onGround = stop.Y - below < 10
			local base = if onGround then Vector3.new(stop.X, below + 0.15, stop.Z) else stop
			playAt(fizzle :: BasePart, base, dir, stop.Y - base.Y, 1)
			if onGround and stop.Y - base.Y > 0.8 then
				bolt(stop, base, { segments = 4, forks = math.min(o.forks, 1), strands = 1 })
			end
		end)
		endTime = flight + math.max(life, BURN * 0.6)
	end

	-- the master timeline (pausable: registered with TechniqueVFX.waves)
	table.sort(events, function(x, y)
		return x.t < y.t
	end)
	local clock = Instance.new("NumberValue")
	local nextEvent = 1
	local function advance(t: number)
		while nextEvent <= #events and events[nextEvent].t <= t do
			local e = events[nextEvent]
			nextEvent += 1
			now = e.t
			e.fn()
			-- events may add events (the hops); keep them in order
			table.sort(events, function(x, y)
				return x.t < y.t
			end)
		end
		now = t
		for i = #actors, 1, -1 do
			local actor = actors[i]
			local u = (t - actor.start) / actor.life
			if u >= 1 then
				table.remove(actors, i)
				if actor.done then
					actor.done()
				end
			elseif u >= 0 then
				actor.update(u)
			end
		end
	end
	advance(0)
	local total = endTime + 0.05
	local tween = TweenService:Create(clock, TweenInfo.new(total, Enum.EasingStyle.Linear), { Value = total })
	clock.Changed:Connect(advance)
	TechniqueVFX.waves[tween] = true
	tween.Completed:Once(function()
		TechniqueVFX.waves[tween] = nil
		advance(total + 1)
		for _, p in parts do
			p:Destroy()
		end
		clock:Destroy()
	end)
	tween:Play()
	return true
end

return Module
