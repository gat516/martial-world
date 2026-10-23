--!strict
-- The heavenly tribulation's sky and strikes (server: Tribulation.luau), drawn by
-- every client from templates in ReplicatedStorage.WorldFX.Tribulation
-- (assets/WorldFX.rbxm, built by tools/vfx_specs/Tribulation.luau; the spec header
-- has the intent, beat sheet and assets).
--
-- Remotes (no new ones):
--   Effect "tribulationStart" (player, center)   -> TribulationFX.start(center)
--   Telegraph (shape, windup, nil, "Tribulation", startedAt), the server's
--     EnemyService.strike telegraph       -> TribulationFX.warn(center, radius, windup)
--   Effect "bolt" (ground)                       -> TribulationFX.strike(ground)
--   Effect "tribulationEnd" (player, survived)   -> TribulationFX.finish(survived)
-- The danger-orange ground telegraph (Telegraphs.luau) still says where and when;
-- the seal here is the heavens choosing the spot, in the storm's colour, under it.
--
-- Beats:
--   gather  GATHER s: the arcs sink and draw in, the wheels and eye fade in, the sky
--           darkens near the peak (SkyGrade "Tribulation") and clears its haze
--           server-wide so the storm reads from the other peaks ("TribulationClear")
--   churn   wheels and arcs turn from the server clock (every client in step); the
--           cloud flickers from inside every FLICKER s (one re-flash, never a strobe),
--           arcs crawl the underside, the arena edge crackles (close)
--   strike  seal and closing ring over the windup, the leader feels down from the
--           eye in the last LEADER share; then the bolt (core, body, glow, branches,
--           one re-strike), the impact stack, the light, a scorch that cools
--   clear   survived: the eye flares, a gold pillar drives down, the clouds are
--           flung apart and rise, gold motes fall; failed: the wheel unwinds
-- Layers by camera distance from the eye: far always (arcs, wheels, eye, billows,
-- in-cloud flicker, bolts, widened with distance); mid within MID (sky arcs); close within CLOSE (crackle, static,
-- seals, impacts, scorches). Past FAR it updates a few times a second.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Tribulation
local Kit = require(script.Parent.Kit)
local SkyGrade = require(script.Parent.SkyGrade)

local TribulationFX = {}

local GATHER = 4
local FLICKER = NumberRange.new(0.5, 1.6) -- s between in-cloud flashes
local RUMBLE = NumberRange.new(5, 9) -- s between distant rumbles
local LEADER = 0.4 -- last share of the windup the leader shows
local CLOSING = 2.2 -- the closing ring starts at this many strike radii
local SEAL_ART = 1.25 -- the seal disc is this many radii wide per radius (art margin)
local SCORCH_ART = 1.5
local BOLT_SPREAD = 16 -- the bolt leaves the eye this far off centre
local SCORCH_LIFE = 6
local CLEAR_SURVIVED = 7
local CLEAR_FAILED = 3.5
local FAR = 1500
local MID = 900
local CLOSE = 320
local PULSE_RANGE = 260 -- flashes only grade the screen near the strike...
local PULSE_GAP = 0.45 -- ...and never faster than this (no strobe)
local SHAKE_RANGE = 45

local INK = Color3.fromRGB(58, 52, 92)
local ATMO = Color3.fromRGB(96, 90, 124)
local GOLD = Color3.fromRGB(255, 214, 140)
local BOLT_TINT = Color3.fromRGB(200, 196, 255)
local STORM = Color3.fromRGB(86, 80, 118)

-- Replaceable for Edit-mode previews.
TribulationFX.clock = os.clock
TribulationFX.shake = nil :: ((number) -> ())?
TribulationFX.sound = nil :: ((string, Vector3) -> ())?

type Arc = { part: BasePart, yaw: number, radius: number, height: number, speed: number, sa: SurfaceAppearance? }
type Spin = { image: ImageLabel, speed: number, base: number }
type Storm = {
	center: Vector3,
	started: number,
	model: Model,
	arcs: { Arc },
	spins: { Spin },
	lit: ImageLabel?,
	litLevel: number,
	eye: BasePart,
	flicker: Attachment?,
	skyArcs: { { beam: Beam, a: Attachment, b: Attachment, endsAt: number } },
	lamp: PointLight?,
	lampPart: BasePart?,
	nextFlicker: number,
	nextRumble: number,
	layer: string,
	nextLayer: number,
	ending: { t: number, survived: boolean, finale: Model? }?,
	lastStep: number,
}
type Seal = { model: Model, t0: number, windup: number, seal: ImageLabel?, closing: ImageLabel?, leader: Beam?, charge: ParticleEmitter?, flick: number, top: Attachment? }
type Bolt = { model: Model, t0: number, beams: { { beam: Beam, role: string } }, widen: number }
type Scorch = { model: Model, t0: number, burn: ImageLabel?, cracks: ImageLabel? }

local storm: Storm? = nil
local seals: { Seal } = {}
local bolts: { Bolt } = {}
local scorches: { Scorch } = {}
local lastPulse = -math.huge

local function rand(r: NumberRange): number
	return r.Min + math.random() * (r.Max - r.Min)
end

local function folder(): Instance?
	local root = Kit.templates()
	return root and root:FindFirstChild("Tribulation")
end

local function cloneOf(name: string): Model?
	local f = folder()
	local t = f and f:FindFirstChild(name)
	if t and t:IsA("Model") then
		return t:Clone()
	end
	return nil
end

-- True when the templates are there (CombatController falls back to the old bolt).
function TribulationFX.ready(): boolean
	return folder() ~= nil
end

local function play(name: string, at: Vector3)
	local fn = TribulationFX.sound
	if fn then
		fn(name, at)
	end
end

local function eyeOf(center: Vector3): Vector3
	local f = folder()
	local v = f and f:FindFirstChild("Vortex")
	local h = v and v:GetAttribute("EyeHeight")
	return center + Vector3.new(0, if type(h) == "number" then h else 128, 0)
end

-- Emitters by Layer: far always; mid / close by camera distance.
local function setLayers(s: Storm, layer: string)
	if s.layer == layer then
		return
	end
	s.layer = layer
	for _, d in s.model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local l = d:GetAttribute("Layer")
			local on = l == "far" or (l == "mid" and layer ~= "far") or (l == "close" and layer == "close")
			-- flicker emitters are emitted by hand (Rate 0); the rest stream
			if d.Rate > 0 then
				d.Enabled = on and s.ending == nil
			end
		end
	end
end

function TribulationFX.start(center: Vector3)
	if storm then
		storm.model:Destroy()
		if storm.ending and storm.ending.finale then
			storm.ending.finale:Destroy()
		end
		storm = nil
	end
	local model = cloneOf("Vortex")
	if not model then
		return
	end
	Kit.place(model, center)
	local now = TribulationFX.clock()
	local arcs: { Arc } = {}
	local arcFolder = model:FindFirstChild("Arcs")
	if arcFolder then
		for _, p in arcFolder:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(arcs, {
					part = p,
					yaw = math.rad(p:GetAttribute("Yaw") :: number or 0),
					radius = p:GetAttribute("Radius") :: number or 100,
					height = p:GetAttribute("Height") :: number or 150,
					speed = math.rad(p:GetAttribute("Speed") :: number or 5),
					sa = p:FindFirstChildOfClass("SurfaceAppearance"),
				})
				p.Transparency = 1
			end
		end
	end
	local spins: { Spin } = {}
	local lit: ImageLabel? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("ImageLabel") then
			local speed = d:GetAttribute("Speed")
			table.insert(spins, { image = d, speed = if type(speed) == "number" then speed else 0, base = d.ImageTransparency })
			if d.Name == "Lit" then
				lit = d
			end
			d.ImageTransparency = 1
		end
	end
	local sky = model:FindFirstChild("SkyArcs")
	local skyArcs = {}
	if sky then
		for i = 1, 3 do
			local b = sky:FindFirstChild("Arc" .. i)
			local a0 = sky:FindFirstChild("A" .. i)
			local a1 = sky:FindFirstChild("B" .. i)
			if b and b:IsA("Beam") and a0 and a0:IsA("Attachment") and a1 and a1:IsA("Attachment") then
				table.insert(skyArcs, { beam = b, a = a0, b = a1, endsAt = 0 })
			end
		end
	end
	local eye = model:FindFirstChild("Eye") :: BasePart
	local lampPart = model:FindFirstChild("Lamp") :: BasePart?
	local s: Storm = {
		center = center,
		started = now,
		model = model,
		arcs = arcs,
		spins = spins,
		lit = lit,
		litLevel = 0,
		eye = eye,
		flicker = eye and eye:FindFirstChild("Flicker") :: Attachment?,
		skyArcs = skyArcs,
		lamp = lampPart and lampPart:FindFirstChildOfClass("PointLight"),
		lampPart = lampPart,
		nextFlicker = now + 1.5,
		nextRumble = now + 0.3,
		layer = "",
		nextLayer = 0,
		ending = nil,
		lastStep = now,
	}
	model.Parent = Kit.folder
	storm = s
	setLayers(s, "far")
	-- the eye opens with one burst so it isn't empty while its loop warms up
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Layer") == "far" then
			local n = d:GetAttribute("EmitCount")
			d:Emit(if type(n) == "number" then n else 1)
		end
	end
end

function TribulationFX.finish(survived: boolean)
	local s = storm
	if not s or s.ending then
		return
	end
	local now = TribulationFX.clock()
	s.ending = { t = now, survived = survived, finale = nil }
	for _, d in s.model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	if survived then
		local finale = cloneOf("Finale")
		if finale then
			Kit.place(finale, s.center)
			finale.Parent = Kit.folder
			s.ending.finale = finale
			Kit.emit(finale)
			for _, d in finale:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					local dur = d:GetAttribute("EmitDuration")
					if type(dur) == "number" and dur > 0 then
						d.Enabled = true
						task.delay(dur, function()
							d.Enabled = false
						end)
					end
				elseif d:IsA("Beam") then
					Kit.beam(d, 1, 0)
				end
			end
		end
		play("Tribulation/Clear", eyeOf(s.center))
		if Kit.distance(s.center) < 600 then
			SkyGrade.pulse({ tint = GOLD, brightness = 0.12, attack = 0.25, hold = 0.2, decay = 1.6 })
		end
	end
end

-- The heavens choose a spot: called with the server telegraph's windup.
function TribulationFX.warn(center: Vector3, radius: number, windup: number)
	if Kit.distance(center) > CLOSE then
		return
	end
	local model = cloneOf("Seal")
	if not model then
		return
	end
	Kit.place(model, center, math.random() * math.pi * 2)
	local disc = model:FindFirstChild("Disc") :: BasePart?
	if disc then
		local d = radius * 2 * SEAL_ART
		disc.Size = Vector3.new(d, disc.Size.Y, d)
	end
	local gui = disc and disc:FindFirstChildOfClass("SurfaceGui")
	local top = disc and disc:FindFirstChild("Top") :: Attachment?
	if top then
		top.WorldPosition = if storm then storm.eye.Position else eyeOf(center)
	end
	local seal: Seal = {
		model = model,
		t0 = TribulationFX.clock(),
		windup = math.max(windup, 0.1),
		seal = gui and gui:FindFirstChild("Seal") :: ImageLabel?,
		closing = gui and gui:FindFirstChild("Closing") :: ImageLabel?,
		leader = disc and disc:FindFirstChild("Leader") :: Beam?,
		charge = top and top:FindFirstChild("Charge") :: ParticleEmitter?,
		flick = 0,
		top = top,
	}
	if seal.seal then
		seal.seal.ImageTransparency = 1
	end
	model.Parent = Kit.folder
	table.insert(seals, seal)
	play("Tribulation/Charge", center)
end

-- A jagged path from `top` to `ground`, written into P0..Pn.
local function boltPath(bolt: BasePart, top: Vector3, ground: Vector3, n: number): { Vector3 }
	local pts = {}
	for i = 0, n do
		local t = i / n
		local p = top:Lerp(ground, t)
		if i > 0 and i < n then
			local jitter = 9 * (1 - t) + 2
			p += Vector3.new(math.random() * 2 - 1, (math.random() - 0.5) * 4, math.random() * 2 - 1) * jitter
		end
		pts[i] = p
		local a = bolt:FindFirstChild("P" .. i) :: Attachment?
		if a then
			a.WorldPosition = p
		end
	end
	return pts
end

function TribulationFX.strike(ground: Vector3)
	local s = storm
	local model = cloneOf("Strike")
	if not model then
		return
	end
	local now = TribulationFX.clock()
	local dist = Kit.distance(ground)
	Kit.place(model, ground)
	local eye = if s then s.eye.Position else eyeOf(ground)
	local a = math.random() * math.pi * 2
	local top = eye + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * BOLT_SPREAD
	local bolt = model:FindFirstChild("Bolt") :: BasePart
	local n = model:GetAttribute("Segments") :: number? or 7
	local pts = boltPath(bolt, top, ground, n)
	-- branches fork off the upper half and reach out and down
	for b = 1, 3 do
		local from = pts[math.clamp(({ 2, 3, 5 })[b], 1, n - 1)]
		local yaw = math.random() * math.pi * 2
		local dir = (Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * 0.9 + Vector3.new(0, -1, 0)).Unit
		local len = 16 + math.random() * 20
		local mid = from + dir * len * 0.5 + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 6
		local to = from + dir * len
		local f = bolt:FindFirstChild("BranchFrom" .. b) :: Attachment?
		local m = bolt:FindFirstChild("BranchMid" .. b) :: Attachment?
		local t = bolt:FindFirstChild("BranchTo" .. b) :: Attachment?
		if f and m and t then
			f.WorldPosition, m.WorldPosition, t.WorldPosition = from, mid, to
		end
	end
	local beams = {}
	for _, d in bolt:GetChildren() do
		if d:IsA("Beam") then
			table.insert(beams, { beam = d, role = d:GetAttribute("Role") :: string? or "core" })
			Kit.beam(d, 1, 1)
		end
	end
	model.Parent = Kit.folder
	-- far away the bolt widens so it still reads as a stroke from the other peaks
	table.insert(bolts, { model = model, t0 = now, beams = beams, widen = 1 + 1.5 * Kit.smooth((dist - 200) / 800) })

	play("Thunder", ground)
	if dist < CLOSE then
		local impact = model:FindFirstChild("Impact")
		if impact then
			Kit.emit(impact)
		end
		play("Tribulation/Crack", ground)
		local scorch = cloneOf("Scorch")
		if scorch then
			Kit.place(scorch, ground, math.random() * math.pi * 2)
			local disc = scorch:FindFirstChild("Disc") :: BasePart?
			local radius = Config.STRIKE_RADIUS
			if disc then
				local d = radius * 2 * SCORCH_ART
				disc.Size = Vector3.new(d, disc.Size.Y, d)
				local embers = disc:FindFirstChild("Embers") :: ParticleEmitter?
				if embers then
					embers.Enabled = true
					task.delay(1.2, function()
						embers.Enabled = false
					end)
				end
			end
			local gui = disc and disc:FindFirstChildOfClass("SurfaceGui")
			scorch.Parent = Kit.folder
			table.insert(scorches, {
				model = scorch,
				t0 = now,
				burn = gui and gui:FindFirstChild("Burn") :: ImageLabel?,
				cracks = gui and gui:FindFirstChild("Cracks") :: ImageLabel?,
			})
		end
	end
	-- the one light, moved to each strike
	if s and s.lamp and s.lampPart and dist < MID then
		s.lampPart.CFrame = CFrame.new(ground + Vector3.new(0, 6, 0))
		s.lamp.Brightness = 7
		s.litLevel = 1
	end
	-- the screen: a soft cool flash near it, never faster than PULSE_GAP; a small shake
	if dist < PULSE_RANGE and now - lastPulse > PULSE_GAP then
		lastPulse = now
		local k = Kit.near(dist, 40, PULSE_RANGE)
		SkyGrade.pulse({ tint = BOLT_TINT, brightness = 0.14 * k, contrast = 0.05 * k, attack = 0.03, hold = 0.04, decay = 0.3 })
	end
	if dist < SHAKE_RANGE and TribulationFX.shake then
		(TribulationFX.shake :: any)(0.22 * Kit.near(dist, 8, SHAKE_RANGE))
	end
end

-- Bolt brightness over its life: strike, dim, re-strike, fade. Exactly one peak
-- pair, then gone; no strobe.
local function boltAlpha(age: number, role: string): (number, number)
	local fade = if role == "glow" then 0.55 elseif role == "branch" then 0.32 else 0.45
	if age < 0.06 then
		return 1, 1.15
	elseif age < 0.11 then
		return 0.35, 0.9
	elseif age < 0.16 then
		return 1, 1.05
	end
	local k = 1 - Kit.outQuad((age - 0.16) / (fade - 0.16))
	return k, 0.5 + 0.5 * k
end

local function stepStorm(s: Storm, now: number, serverNow: number, dt: number)
	local center = s.center
	local dist = Kit.distance(s.eye.Position)
	if now >= s.nextLayer then
		s.nextLayer = now + 0.5
		setLayers(s, if dist < CLOSE then "close" elseif dist < MID then "mid" else "far")
	end
	local g = Kit.smooth((now - s.started) / GATHER)
	local alpha, spread, rise, goldMix = g, 1.4 - 0.4 * g, 80 * (1 - g), 0
	local ending = s.ending
	local te = 0
	if ending then
		te = now - ending.t
		if ending.survived then
			local k = Kit.smooth((te - 0.5) / 4.5)
			alpha = g * (1 - k)
			spread = 1 + 1.8 * Kit.outQuad((te - 0.5) / 5)
			rise = 140 * Kit.inQuad((te - 0.5) / 5)
			goldMix = Kit.smooth(te / 1.5) * (1 - Kit.smooth((te - 3) / 3))
		else
			local k = Kit.smooth(te / (CLEAR_FAILED - 0.5))
			alpha = g * (1 - k)
			spread = 1 + 0.35 * k
			rise = 40 * k
		end
	end

	-- arcs: turn (server clock), breathe, gather, part
	local tint = Color3.new(1, 1, 1):Lerp(STORM, 0.85):Lerp(GOLD, goldMix)
	for i, arc in s.arcs do
		local yaw = arc.yaw + serverNow * arc.speed
		local breathe = 1 + 0.035 * math.sin(serverNow * 0.45 + i)
		local r = arc.radius * spread * breathe
		local h = arc.height + rise + 3 * math.sin(serverNow * 0.3 + i * 1.7)
		Kit.move(arc.part, CFrame.new(center + Vector3.new(math.sin(yaw) * r, h, math.cos(yaw) * r)) * CFrame.Angles(0, yaw, 0))
		arc.part.Transparency = 1 - alpha * 0.98
		if arc.sa and goldMix > 0 then
			(arc.sa :: any).Color = tint
		end
	end
	Kit.flush()

	-- wheels: turn, flare with the flicker
	s.litLevel = math.max(0, s.litLevel - dt * 4)
	for _, spin in s.spins do
		spin.image.Rotation = (serverNow * spin.speed) % 360
		if spin.image == s.lit then
			spin.image.ImageTransparency = 1 - 0.7 * s.litLevel * alpha
		else
			spin.image.ImageTransparency = 1 - (1 - spin.base) * alpha
		end
	end
	if s.lamp then
		s.lamp.Brightness = math.max(0, s.lamp.Brightness - dt * 18)
	end

	-- in-cloud flicker and crawling arcs (mid), rumbles
	if not ending and g > 0.5 then
		if now >= s.nextFlicker then
			s.nextFlicker = now + rand(FLICKER)
			if s.flicker then
				local a, r = math.random() * math.pi * 2, 30 + math.random() * 200
				s.flicker.WorldPosition = center + Vector3.new(math.cos(a) * r, 135 + math.random() * 45, math.sin(a) * r)
				for _, e in s.flicker:GetChildren() do
					if e:IsA("ParticleEmitter") then
						e:Emit(1)
					end
				end
				local arc = s.skyArcs[math.random(1, math.max(1, #s.skyArcs))]
				if arc and s.layer ~= "far" then
					local b = a + (math.random() - 0.5) * 1.6
					local r2 = 40 + math.random() * 180
					arc.a.WorldPosition = s.flicker.WorldPosition
					arc.b.WorldPosition = center + Vector3.new(math.cos(b) * r2, 140 + math.random() * 40, math.sin(b) * r2)
					arc.endsAt = now + 0.22
					arc.beam.Enabled = true
				end
			end
			s.litLevel = math.max(s.litLevel, 0.6)
		end
		if now >= s.nextRumble then
			s.nextRumble = now + rand(RUMBLE)
			play("Tribulation/Rumble", s.eye.Position)
		end
	end
	for _, arc in s.skyArcs do
		if arc.beam.Enabled and now > arc.endsAt then
			arc.beam.Enabled = false
		end
	end

	-- finale: the gold pillar drives down from the eye, holds, fades
	local finale = ending and ending.finale
	if finale then
		local shaft = finale:FindFirstChild("Shaft")
		local bottom = shaft and shaft:FindFirstChild("Bottom") :: Attachment?
		local top = shaft and shaft:FindFirstChild("Top") :: Attachment?
		if bottom and top then
			local drive = Kit.outQuad((te - 0.3) / 0.7)
			bottom.WorldPosition = top.WorldPosition:Lerp(center + Vector3.new(0, 0.5, 0), drive)
			local fadeK = 1 - Kit.smooth((te - 3.5) / 2.5)
			for _, b in (shaft :: Instance):GetChildren() do
				if b:IsA("Beam") then
					Kit.beam(b, 0.6 + 0.4 * drive, if te < 0.3 then 0 else fadeK)
				end
			end
		end
	end

	-- the sky: darker and cooler near the peak, clearer everywhere while it lasts
	local nearK = Kit.near(Kit.distance(center), 350, 1600)
	SkyGrade.set("Tribulation", {
		weight = alpha * nearK,
		tint = if goldMix > 0 then INK:Lerp(GOLD, goldMix) else INK,
		tintMix = 0.35,
		atmoColor = ATMO,
		atmoMix = 0.45,
		brightness = 0.78 + 0.4 * goldMix,
		saturation = -0.12,
		contrast = 0.06,
	})
	SkyGrade.set("TribulationClear", { weight = math.max(alpha, goldMix), densityCap = 0.28, hazeCap = 1.0 })

	if ending and te > (if ending.survived then CLEAR_SURVIVED else CLEAR_FAILED) then
		s.model:Destroy()
		if finale then
			finale:Destroy()
		end
		storm = nil
		SkyGrade.clear("Tribulation")
		SkyGrade.clear("TribulationClear")
	end
end

function TribulationFX.step()
	local now = TribulationFX.clock()
	local serverNow = Kit.now()
	local s = storm
	if s then
		local dt = math.min(now - s.lastStep, 0.25)
		-- far away: a few updates a second
		if dt < 0.2 and Kit.distance(s.center) > FAR then
			return
		end
		s.lastStep = now
		stepStorm(s, now, serverNow, dt)
	end

	for i = #seals, 1, -1 do
		local seal = seals[i]
		local k = (now - seal.t0) / seal.windup
		if k >= 1 then
			seal.model:Destroy()
			table.remove(seals, i)
			continue
		end
		if seal.seal then
			seal.seal.ImageTransparency = 1 - 0.85 * Kit.smooth(k / 0.25)
			seal.seal.Rotation = (now * 40) % 360
		end
		if seal.closing then
			local scale = (CLOSING - (CLOSING - 1) * Kit.inQuad(k)) / SEAL_ART
			seal.closing.Size = UDim2.fromScale(scale, scale)
			seal.closing.ImageTransparency = 1 - 0.85 * Kit.smooth(k / 0.15)
			seal.closing.Rotation = (-now * 25) % 360
		end
		local leading = k > 1 - LEADER
		if seal.leader then
			if leading and now >= seal.flick then
				seal.flick = now + 0.07
				Kit.beam(seal.leader, 1, 0.35 + 0.5 * math.random() * Kit.smooth((k - (1 - LEADER)) / LEADER))
			elseif not leading then
				seal.leader.Enabled = false
			end
		end
		if seal.charge then
			seal.charge.Enabled = k > 0.5
		end
	end

	for i = #bolts, 1, -1 do
		local bolt = bolts[i]
		local age = now - bolt.t0
		if age > 1.6 then
			bolt.model:Destroy()
			table.remove(bolts, i)
			continue
		end
		for _, b in bolt.beams do
			local alpha, width = boltAlpha(age, b.role)
			Kit.beam(b.beam, width * bolt.widen, math.max(alpha, 0))
		end
	end

	for i = #scorches, 1, -1 do
		local sc = scorches[i]
		local age = now - sc.t0
		if age > SCORCH_LIFE then
			sc.model:Destroy()
			table.remove(scorches, i)
			continue
		end
		if sc.cracks then
			sc.cracks.ImageTransparency = Kit.smooth(age / 1.6)
		end
		if sc.burn then
			sc.burn.ImageTransparency = 0.1 + 0.9 * Kit.smooth((age - 3) / (SCORCH_LIFE - 3))
		end
	end
end

function TribulationFX.active(): boolean
	return storm ~= nil or #seals > 0 or #bolts > 0 or #scorches > 0
end

function TribulationFX.init()
	local parent = script.Parent.Parent :: Instance
	local okFx, CombatEffects = pcall(require, parent:FindFirstChild("CombatEffects") :: ModuleScript)
	if okFx and CombatEffects then
		TribulationFX.shake = (CombatEffects :: any).shake
	end
	local okSfx, Sfx = pcall(require, parent:FindFirstChild("Sfx") :: ModuleScript)
	if okSfx and Sfx then
		TribulationFX.sound = function(name: string, at: Vector3)
			(Sfx :: any).play(name, at, 0.12)
		end
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Telegraph") :: RemoteEvent
	remote.OnClientEvent:Connect(function(shape: any, seconds: any, _model: any, source: any, startedAt: any)
		if source ~= "Tribulation" or type(shape) ~= "table" or shape.kind ~= "circle" or type(seconds) ~= "number" then
			return
		end
		if type(startedAt) == "number" then
			seconds = math.max(0.05, seconds - (workspace:GetServerTimeNow() - startedAt))
		end
		TribulationFX.warn(shape.center, shape.radius, seconds)
	end)
	RunService.RenderStepped:Connect(function()
		if TribulationFX.active() then
			TribulationFX.step()
		end
	end)
end

return TribulationFX
