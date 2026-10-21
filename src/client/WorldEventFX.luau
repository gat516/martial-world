--!strict
-- Draws world events on this client. Today: the Auspicious Clouds family
-- (defs with kind "AuspiciousClouds" in Shared.WorldEvents), clouds gathering
-- round a sealed relic in the wilds.
--
-- Reads the workspace attribute WorldEvents (JSON list of { id, name, ends, at? },
-- set by the server). For every entry whose def is an AuspiciousClouds kind and
-- that has an `at`, it clones the shared pieces of
-- ReplicatedStorage.Effects.AuspiciousClouds (Ring, Column, Whirl, Eye) plus
-- the def's pattern Model (look.pattern: Vortex, Mist, Spiral), tints them from
-- look.color / look.accent, scales the ring to def.radius and plays:
--   arrival   wisps descend from the cloud plane and spiral into their rings (ARRIVE s)
--   running   every layer turns about the eye at its own speed, with a bob/ripple
--   condense  CONDENSE s before ends - condenseSeconds the clouds pour into the
--             relic; at that moment (when the server enables the claim prompt)
--             the seal shatters with a burst and the relic glows bright
--   departure when the entry leaves the attribute the clouds rise and fade (DEPART s)
-- Joining mid-event starts at the right phase (no arrival, no burst if the seal
-- already broke). The relic itself is a server Model named after the def id in
-- Workspace.Wilds; this module only bobs and turns it.
--
-- Template contract (see tools/vfx_specs/AuspiciousClouds.luau): a Model with a
-- `Speed` attribute is a turning layer (Bob, BobPeriod, Ripple, RipplePeriod,
-- Phase, Order, Condense, Absolute). Parts with `Fade` are faded from that
-- resting Transparency; anything with `Tint` takes look[Tint] (mixed with white
-- by TintMix); emitters with `Scale` follow the ring's radius; `Unsealed`
-- emitters run only once the seal broke.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldEvents = require(ReplicatedStorage.Shared.WorldEvents)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local WorldEventFX = {}

-- Where clones go (local to this client). Edit-mode previews point it at a
-- workspace folder, since screen captures swap the camera.
WorldEventFX.folder = workspace.CurrentCamera :: Instance
-- The template's parent (ReplicatedStorage.Effects); previews point it at the
-- staging copy.
WorldEventFX.source = nil :: Instance?

local ARRIVE = 8 -- seconds for the clouds to descend into their rings
local CONDENSE = 4 -- seconds for them to pour into the relic (ending at the unseal)
local DEPART = 4 -- seconds to rise and fade when the event ends
local JOIN_FADE = 1.5 -- fade-in when joining an event already under way
local DESCENT = 30 -- studs above the cloud plane the wisps start from
local CONDENSED_RADIUS = 0.15 -- layer size and radius once poured into the relic (x authored)
local CONDENSED_HEIGHT = 0.1 -- layer height above the core once poured in (x authored)
local SHATTER = 0.45 -- seconds the seal takes to burst apart
local FAR = 1500 -- beyond this the layers update a few times a second, not every frame
local WHITE = Color3.new(1, 1, 1)

type Piece = { part: BasePart, pos: Vector3, rot: CFrame, size: Vector3, fade: number, scales: boolean }
type Layer = {
	pieces: { Piece },
	speed: number,
	bob: number,
	bobPeriod: number,
	ripple: number,
	ripplePeriod: number,
	phase: number,
	order: number,
	condense: boolean,
	absolute: boolean,
	seal: boolean,
	angle: number,
	lastK: number,
	lastAlpha: number,
}
type Show = {
	id: string,
	def: any,
	model: Model,
	base: Vector3, -- ground point at the eye
	coreHeight: number,
	layers: { Layer },
	statics: { Piece }, -- fading parts that don't turn (ring)
	beams: { { beam: Beam, seq: NumberSequence, seal: boolean } },
	core: Attachment?,
	light: PointLight?,
	lightBrightness: number,
	glow: { ParticleEmitter },
	start: number, -- server time the event began
	unsealAt: number, -- server time the seal breaks (ends - condenseSeconds)
	seenAt: number, -- os.clock() first drawn here
	joined: boolean, -- first seen after the arrival
	unsealed: boolean,
	unsealedClock: number?,
	leftAt: number?, -- os.clock() the entry left the attribute
	lastBeamAlpha: number,
	lastUpdate: number,
	relic: Model?,
	relicBase: CFrame?,
}

local shows: { [string]: Show } = {}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function outQuad(x: number): number
	x = clamp01(x)
	return 1 - (1 - x) * (1 - x)
end

local function fadedSeq(seq: NumberSequence, alpha: number): NumberSequence
	local kps = {}
	for _, k in seq.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(k.Time, 1 - (1 - k.Value) * alpha, k.Envelope))
	end
	return NumberSequence.new(kps)
end

local function scaledSeq(seq: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, p in seq.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end

local function tint(root: Instance, look: any)
	for _, d in root:GetDescendants() do
		local which = d:GetAttribute("Tint")
		if type(which) ~= "string" then
			continue
		end
		local base = look[which]
		if typeof(base) ~= "Color3" then
			continue
		end
		local mix = d:GetAttribute("TintMix")
		local c = WHITE:Lerp(base, if type(mix) == "number" then mix else 1)
		if d:IsA("BasePart") then
			d.Color = c
			-- a textured MeshPart ignores Color: tinted clouds drop the white ramp
			-- texture (Fabric still shades them); near-white looks keep it
			local _, sat = c:ToHSV()
			if d:IsA("MeshPart") and sat > 0.06 and d.TextureID ~= "" then
				d.TextureID = ""
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Color = ColorSequence.new(c)
		elseif d:IsA("PointLight") then
			d.Color = c
		end
	end
end

local function inWave(d: Instance, root: Instance): boolean
	local at = d.Parent
	while at and at ~= root do
		if at:IsA("Model") and at:GetAttribute("MeshWave") then
			return true
		end
		at = at.Parent
	end
	return false
end

-- Parts of `m` relative to the ground point, with `k` scaling the radius.
local function piecesOf(m: Instance, root: Model, k: number, lift: number): { Piece }
	local list = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not inWave(d, root) then
			local fade = d:GetAttribute("Fade")
			local p = d.Position
			table.insert(list, {
				part = d,
				pos = Vector3.new(p.X * k, p.Y + lift, p.Z * k),
				rot = d.CFrame.Rotation,
				size = if type(fade) == "number" then d.Size * k else d.Size,
				fade = if type(fade) == "number" then fade else -1,
				scales = type(fade) == "number",
			})
		end
	end
	return list
end

local function layerOf(m: Model, root: Model, k: number, lift: number, seal: boolean): Layer
	local function num(name: string, default: number): number
		local v = m:GetAttribute(name)
		return if type(v) == "number" then v else default
	end
	return {
		pieces = piecesOf(m, root, k, lift),
		speed = num("Speed", 0),
		bob = num("Bob", 0),
		bobPeriod = num("BobPeriod", 8),
		ripple = num("Ripple", 0),
		ripplePeriod = num("RipplePeriod", 7),
		phase = num("Phase", 0),
		order = num("Order", 0),
		condense = m:GetAttribute("Condense") ~= false,
		absolute = m:GetAttribute("Absolute") == true,
		seal = seal,
		angle = 0,
		lastK = -1,
		lastAlpha = -1,
	}
end

local function setEnabled(root: Instance, on: boolean, filter: ((Instance) -> boolean)?)
	for _, d in root:GetDescendants() do
		if (d:IsA("ParticleEmitter") or d:IsA("Beam")) and (not filter or filter(d)) then
			d.Enabled = on
		end
	end
end

local function findRelic(id: string): Model?
	local wilds = workspace:FindFirstChild("Wilds")
	local relic = wilds and wilds:FindFirstChild(id)
	return if relic and relic:IsA("Model") then relic else nil
end

local function create(entry: any, def: any): Show?
	local effects = WorldEventFX.source or ReplicatedStorage:FindFirstChild("Effects")
	local template = effects and effects:FindFirstChild("AuspiciousClouds")
	local look = def.look or {}
	local pattern = template and template:FindFirstChild(look.pattern or "Vortex")
	if not (template and pattern and pattern:IsA("Model")) then
		warn(`WorldEventFX: no Effects.AuspiciousClouds pattern for {entry.id}`)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = entry.id
	for _, name in { "Ring", "Column", "Whirl", "Eye" } do
		local piece = template:FindFirstChild(name)
		if piece then
			piece:Clone().Parent = model
		end
	end
	pattern:Clone().Parent = model
	tint(model, look)

	local at = entry.at
	local base = Vector3.new(at[1], at[2], at[3])
	local relicTemplate = template:FindFirstChild("Relics")
	relicTemplate = relicTemplate and relicTemplate:FindFirstChild(def.relic or "Manual")
	local coreHeight = relicTemplate and relicTemplate:GetAttribute("CoreHeight")
	coreHeight = if type(coreHeight) == "number" then coreHeight else 5
	local eyeLift = coreHeight - 5 -- the Eye is authored for a core 5 studs up

	local authored = template:GetAttribute("AuthoredRadius")
	local ringK = (def.radius or 36) / (if type(authored) == "number" then authored else 36)
	local patternAuthored = pattern:GetAttribute("AuthoredRadius")
	local patternK = (def.radius or 36) / (if type(patternAuthored) == "number" then patternAuthored else 36)

	-- the ring: band and mote cylinder widen, scaled emitters grow
	local ring = model:FindFirstChild("Ring")
	if ring and math.abs(ringK - 1) > 1e-3 then
		for _, d in ring:GetDescendants() do
			if d.Name == "RingBand" and d:IsA("BasePart") then
				d.Size = Vector3.new(d.Size.X * ringK, d.Size.Y, d.Size.Z * ringK)
			elseif d.Name == "RingFX" and d:IsA("BasePart") then
				d.Size = Vector3.new(d.Size.X, d.Size.Y * ringK, d.Size.Z * ringK)
			elseif d:IsA("ParticleEmitter") and d:GetAttribute("Scale") then
				d.Size = scaledSeq(d.Size, ringK)
			end
		end
	end

	-- the light column reaches a fixed world height above the cloud plane
	local column = model:FindFirstChild("Column")
	local top = column and column:FindFirstChild("Top", true)
	if top and top:IsA("Attachment") then
		local worldY = top:GetAttribute("WorldY")
		if type(worldY) == "number" then
			top.Position = Vector3.new(0, worldY - base.Y, 0)
		end
	end

	local show: Show = {
		id = entry.id,
		def = def,
		model = model,
		base = base,
		coreHeight = coreHeight,
		layers = {},
		statics = {},
		beams = {},
		core = nil,
		light = nil,
		lightBrightness = 1.5,
		glow = {},
		start = entry.ends - (def.minutes or 6) * 60,
		unsealAt = entry.ends - (def.condenseSeconds or 75),
		seenAt = os.clock(),
		joined = false,
		unsealed = false,
		unsealedClock = nil,
		leftAt = nil,
		lastBeamAlpha = -1,
		lastUpdate = 0,
		relic = nil,
		relicBase = nil,
	}
	local now = workspace:GetServerTimeNow()
	show.joined = now - show.start > ARRIVE * 0.5

	local planeTop = template:GetAttribute("PlaneTop")
	planeTop = if type(planeTop) == "number" then planeTop else 440
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Speed") ~= nil then
			local inPattern = d:IsDescendantOf(model:FindFirstChild(pattern.Name) :: Instance)
			local seal = d.Name == "Seal"
			local layer = layerOf(d, model, if inPattern then patternK else 1, if seal then eyeLift else 0, seal)
			if layer.absolute then
				-- authored in world Y (the cloud plane): relative to this ground point
				for _, p in layer.pieces do
					p.pos -= Vector3.new(0, base.Y, 0)
				end
			end
			table.insert(show.layers, layer)
		end
	end
	-- fading parts outside the layers (the ring band)
	if ring then
		for _, p in piecesOf(ring, model, 1, 0) do
			if p.fade >= 0 then
				p.scales = false
				table.insert(show.statics, p)
			end
		end
	end
	local eye = model:FindFirstChild("Eye")
	local eyePart = eye and eye:FindFirstChild("Eye")
	if eyePart and eyePart:IsA("BasePart") then
		eyePart.CFrame = CFrame.new(base + Vector3.new(0, coreHeight, 0))
		show.core = eyePart:FindFirstChild("Core") :: Attachment?
		local glow = eyePart:FindFirstChild("Glow")
		if glow then
			show.light = glow:FindFirstChildWhichIsA("PointLight")
			local b = show.light and show.light:GetAttribute("Brightness")
			show.lightBrightness = if type(b) == "number" then b else 1.5
			for _, e in glow:GetChildren() do
				if e:IsA("ParticleEmitter") then
					table.insert(show.glow, e)
				end
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Beam") then
			table.insert(show.beams, { beam = d, seq = d.Transparency, seal = eye ~= nil and d:IsDescendantOf(eye) })
		end
	end
	-- static parts and Eye parts outside layers: put them in place once
	local shaft = column and column:FindFirstChild("Shaft")
	if shaft and shaft:IsA("BasePart") then
		shaft.CFrame = CFrame.new(base)
	end
	if ring then
		for _, d in ring:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = CFrame.new(base) * d.CFrame
			end
		end
	end
	for _, p in show.statics do
		p.part.Transparency = 1
	end
	-- the MeshWave meshes (cloned when played) start where the Core is
	model.Parent = WorldEventFX.folder

	-- emitters: everything but the Eye's core bursts and post-unseal glow
	for _, name in { "Ring", "Column", "Whirl", pattern.Name } do
		local piece = model:FindFirstChild(name)
		if piece then
			TechniqueVFX.enable(piece)
		end
	end
	local seal = eye and eye:FindFirstChild("Seal")
	if seal then
		TechniqueVFX.enable(seal)
	end
	if now >= show.unsealAt then
		show.unsealed = true
		show.unsealedClock = os.clock() - SHATTER
		if seal then
			setEnabled(seal, false)
		end
	end
	for _, e in show.glow do
		e.Enabled = (e:GetAttribute("Unsealed") == true) == show.unsealed
	end
	return show
end

local function unseal(show: Show)
	show.unsealed = true
	show.unsealedClock = os.clock()
	local eye = show.model:FindFirstChild("Eye")
	local seal = eye and eye:FindFirstChild("Seal")
	if seal then
		setEnabled(seal, false, function(d)
			return d:IsA("ParticleEmitter")
		end)
	end
	if show.core then
		TechniqueVFX.emit(show.core)
	end
	for _, e in show.glow do
		e.Enabled = e:GetAttribute("Unsealed") == true
	end
end

local function depart(show: Show)
	if show.leftAt then
		return
	end
	show.leftAt = os.clock()
	setEnabled(show.model, false)
	task.delay(DEPART + 10, function()
		show.model:Destroy()
	end)
end

-- Bob and turn the server's relic (it does no animation itself).
local function animateRelic(show: Show, t: number)
	local relic = show.relic
	if not (relic and relic.Parent) then
		relic = findRelic(show.id)
		show.relic = relic
		show.relicBase = relic and relic:GetPivot()
	end
	local base = show.relicBase
	if relic and base then
		local bob = math.sin(t * math.pi * 2 / 4) * 0.35 * (if show.unsealed then 1.6 else 1)
		local spin = t * math.rad(if show.def.relic == "Sword" then 30 else 14)
		relic:PivotTo(base * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0))
	end
end

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function update(show: Show, dt: number, now: number, clock: number)
	local origin = show.base
	local cam = workspace.CurrentCamera
	local far = cam and (cam.CFrame.Position - origin).Magnitude > FAR
	if far and clock - show.lastUpdate < 0.25 then
		return
	end
	local step = if far then clock - show.lastUpdate else dt
	show.lastUpdate = clock

	local join = if show.joined then smooth((clock - show.seenAt) / JOIN_FADE) else 1
	local leave = if show.leftAt then smooth((clock - show.leftAt) / DEPART) else 0
	local pour = smooth((now - (show.unsealAt - CONDENSE)) / CONDENSE)
	if show.unsealed then
		pour = 1
	end
	if not show.unsealed and now >= show.unsealAt and not show.leftAt then
		unseal(show)
	end
	local shatter = if show.unsealedClock then outQuad((clock - show.unsealedClock) / SHATTER) else 0
	local planeTop = 440
	local descentFrom = planeTop + DESCENT - origin.Y

	for _, layer in show.layers do
		local arrive = if show.joined then 1 else outQuad((now - show.start - layer.order * 2.5) / (ARRIVE - 2.5))
		local spinBoost = 1 + 2 * (if layer.condense then pour else 0)
		layer.angle += math.rad(layer.speed) * step * spinBoost
		local angle = layer.angle + (1 - arrive) * math.rad(120) * math.sign(layer.speed)
		local k = 1 + 0.8 * (1 - arrive)
		local alpha = arrive * join * (1 - leave)
		local c = if layer.condense then pour else 0
		if c > 0 then
			k *= 1 + (CONDENSED_RADIUS - 1) * c
			alpha *= 1 - c * c -- gone into the relic as the seal breaks
		end
		if layer.seal then
			k *= 1 + 0.9 * shatter
			alpha *= 1 - shatter
		end
		k *= 1 + 0.4 * leave
		local bob = layer.bob * math.sin(now * math.pi * 2 / layer.bobPeriod + layer.phase) * (1 - 0.6 * c)
		local ripple = layer.ripple * math.sin(now * math.pi * 2 / layer.ripplePeriod + layer.phase) * (1 - c)
		local turn = CFrame.Angles(0, angle, 0)
		local resize = math.abs(k - layer.lastK) > 1e-3
		local refade = math.abs(alpha - layer.lastAlpha) > 4e-3
		if resize then
			layer.lastK = k
		end
		if refade then
			layer.lastAlpha = alpha
		end
		for _, p in layer.pieces do
			local pos = p.pos
			local r = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
			local radial = k + (if r > 1 then ripple / r else 0)
			local y = pos.Y
			if not layer.absolute then
				y = descentFrom + (y - descentFrom) * arrive
				if c > 0 then
					local core = show.coreHeight
					y += ((core + (pos.Y - core) * CONDENSED_HEIGHT) - pos.Y) * c
				end
				y += 120 * leave
			end
			y += bob
			table.insert(moveParts, p.part)
			table.insert(moveFrames, CFrame.new(origin) * turn * CFrame.new(pos.X * radial, y, pos.Z * radial) * p.rot)
			if resize and p.scales then
				p.part.Size = p.size * k
			end
			if refade and p.fade >= 0 then
				p.part.Transparency = 1 - (1 - p.fade) * alpha
			end
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveFrames)
	end

	local arriveAll = if show.joined then 1 else outQuad((now - show.start) / ARRIVE)
	local alpha = arriveAll * join * (1 - leave)
	for _, p in show.statics do
		p.part.Transparency = 1 - (1 - p.fade) * alpha
	end
	if math.abs(alpha - show.lastBeamAlpha) > 4e-3 or (shatter > 0 and shatter < 1) then
		show.lastBeamAlpha = alpha
		for _, b in show.beams do
			local a = if b.seal then alpha * (1 - shatter) else alpha
			b.beam.Transparency = fadedSeq(b.seq, a)
			if b.seal and shatter >= 1 then
				b.beam.Enabled = false
			end
		end
	end
	if show.light then
		local glow = if show.unsealed then show.lightBrightness * shatter else 0
		show.light.Brightness = glow * (1 - leave)
	end
	if not far then
		animateRelic(show, now)
	end
end

local function sync()
	local raw = workspace:GetAttribute("WorldEvents")
	local list = {}
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			list = decoded
		end
	end
	local live: { [string]: boolean } = {}
	for _, entry in list do
		local def = type(entry) == "table" and WorldEvents.Defs[entry.id]
		if not (def and def.kind == "AuspiciousClouds" and type(entry.at) == "table" and type(entry.ends) == "number") then
			continue
		end
		live[entry.id] = true
		local show = shows[entry.id]
		if show and show.leftAt then
			shows[entry.id] = nil -- restarted while the last one was leaving
			show = nil
		end
		if not show then
			local made = create(entry, def)
			if made then
				shows[entry.id] = made
			end
		end
	end
	for id, show in shows do
		if not live[id] then
			depart(show)
		end
	end
end

function WorldEventFX.init()
	workspace:GetAttributeChangedSignal("WorldEvents"):Connect(sync)
	sync()
	RunService.RenderStepped:Connect(function(dt: number)
		if next(shows) == nil then
			return
		end
		local now = workspace:GetServerTimeNow()
		local clock = os.clock()
		for id, show in shows do
			update(show, dt, now, clock)
			if show.leftAt and clock - show.leftAt > DEPART then
				shows[id] = nil
			end
		end
	end)
end

-- Edit-mode preview hooks (tools): draw an entry now, step it, end it.
WorldEventFX._create = create
WorldEventFX._update = update
WorldEventFX._depart = depart

return WorldEventFX
