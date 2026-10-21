--!strict
-- Draws heavenly treasure births (server: Treasures.luau) from the workspace
-- attribute HeavenlyTreasures (JSON list of { key, at = {x,y,z}, color = {r,g,b},
-- weather, born }). Drawn by every client from the published position, so the far
-- layer shows even where the treasure model hasn't streamed in.
--
-- The cloud plane (Kit.planeY) is opaque from both sides, so the sky has two
-- audiences: the peaks see everything above it, the valley everything below. The
-- birth plays on both: a rift high in the sky (peaks) and a rift in the cloud
-- ceiling (valley) where the meteor punches through.
-- Beats (seconds from `born`, server clock, so everyone sees the same phase):
--   0 - OMEN          a star glint, then the high rift tears open at RIFT_Y off to one
--                     side; a glint and faint seam appear in the ceiling (valley omen)
--   FALL - IMPACT     the treasure falls out of the high rift as a meteor, arcing down;
--                     where it crosses the cloud plane the ceiling rift tears wide and a
--                     rain of light fans down out of it
--   IMPACT            flash, glint, shock ring; the light pillar drives down into the
--                     ground; a gentle pulse and shake only near it. The server
--                     enables the claim at Treasures.LAND (just after)
--   sustain           pillar (far), sky circle turning over it, the puncture ring on
--                     the cloud plane, two rings of wisp arcs circling (mid), the
--                     ground sigil, mist bank, motes and petals round the treasure (close)
--   gone              (claimed, or the weather ended) the pillar pulls up into the
--                     sky circle, which shrinks out; the arcs fling outward and fade
-- Colour follows the anomaly: violet (Auspicious Mist), pearl (Rainbow Aurora), gold
-- (Heaven Split). The sky clears (SkyGrade caps Atmosphere density/haze) while any
-- treasure is up, so the pillars read from the peaks (far-read test, world.md), and the
-- air takes the anomaly's colour near one.
-- Layers by distance: far always (pillar beams, puncture ring and billows, sky
-- circle, rift); mid within MID (streaks, motes, arc mist, rift flicker and shards);
-- close within CLOSE (ground sigil emitters, mist bank, light).

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Kit)
local SkyGrade = require(script.Parent.SkyGrade)

local TreasureFX = {}

local OMEN = 2 -- the rift has torn open
local FALL = 2 -- the meteor leaves the rift
local IMPACT = 6.5 -- it lands (Treasures.LAND is 7: the claim opens just after)
local DRIVE = 0.6 -- the pillar drives down from the sky
local HEAL = 3 -- the rift closes after the impact, leaving the sky circle
local CIRCLE_OPEN = 1.4
local RING_ARRIVE = 4
local COLLAPSE = 2.5
local JOIN_FADE = 1.5
local RIFT_Y = 1150 -- the high rift (seen from the peaks)
local CEILING_DROP = 24 -- the ceiling rift, this far under the cloud plane's top
local CIRCLE_DROP = 40 -- the sky circle, under the ceiling rift
local CEILING_TEAR = 0.35 -- seconds for the ceiling rift to tear wide
local CEILING_SIZE = 2.2 -- its beams are widened: it's seen from the valley floor, 300+ studs below
local CIRCLE_RADIUS = 110
local PILLAR_SCALE = 0.6 -- a treasure's pillar against the authored (anomaly) size
local FAR = 1500 -- beyond this, update a few times a second
local MID = 650
local CLOSE = 300
local NEAR_INNER, NEAR_OUTER = 120, 340 -- the air takes the anomaly's colour

local PALETTES: { [string]: Kit.Palette } = {
	AuspiciousMist = {
		core = Color3.fromRGB(255, 245, 255),
		color = Color3.fromRGB(176, 110, 255),
		accent = Color3.fromRGB(130, 60, 230),
		dark = Color3.fromRGB(40, 16, 70),
	},
	RainbowAurora = {
		core = Color3.fromRGB(255, 255, 255),
		color = Color3.fromRGB(225, 235, 255),
		accent = Color3.fromRGB(150, 210, 255),
		dark = Color3.fromRGB(30, 40, 75),
	},
	HeavenSplit = {
		core = Color3.fromRGB(255, 252, 235),
		color = Color3.fromRGB(255, 205, 100),
		accent = Color3.fromRGB(255, 160, 60),
		dark = Color3.fromRGB(70, 40, 10),
	},
}

-- Injected by init (the game's camera shake); previews leave it a no-op.
TreasureFX.shake = function(_strength: number) end

type Rift = { model: Model, beams: { { beam: Beam, seg: number } }, emit: { [string]: ParticleEmitter }, ceiling: boolean }
type ArcPiece = { part: BasePart, rel: CFrame, layer: Model, speed: number, bob: number, bobPeriod: number, phase: number }
type Show = {
	key: string,
	at: Vector3,
	born: number,
	yaw: number,
	palette: Kit.Palette,
	model: Model,
	rifts: { Rift },
	riftAt: Vector3,
	crossT: number, -- seconds from born when the meteor crosses the cloud plane
	meteor: Model?,
	head: BasePart?,
	tail: Trail?,
	headEmit: { ParticleEmitter },
	pillar: Model?,
	bottom: Attachment?,
	topY: number,
	beams: { [string]: Beam },
	pillarEmit: { [string]: ParticleEmitter },
	circle: Model?,
	circleImages: { ImageLabel },
	ground: Model?,
	groundImages: { ImageLabel },
	groundEmit: { ParticleEmitter },
	light: PointLight?,
	lightBrightness: number,
	arcs: { ArcPiece },
	arcEmit: { ParticleEmitter },
	joined: boolean,
	seenAt: number,
	leftAt: number?,
	impacted: boolean,
	lastUpdate: number,
	farness: number,
}

local shows: { [string]: Show } = {}

local function emitters(root: Instance?, filter: ((ParticleEmitter) -> boolean)?): { ParticleEmitter }
	local list = {}
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("ParticleEmitter") and (not filter or filter(d)) then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function images(root: Instance?): { ImageLabel }
	local list = {}
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("ImageLabel") then
				table.insert(list, d)
			end
		end
	end
	return list
end

-- The meteor's arc from the high rift to the spot (e = eased 0..1).
function TreasureFX._path(show: any, e: number): Vector3
	local p0 = show.riftAt
	local p2 = show.at + Vector3.new(0, 3, 0)
	local p1 = Vector3.new(p0.X, p0.Y - 250, p0.Z):Lerp(Vector3.new(p2.X, p0.Y - 250, p2.Z), 0.25)
	local a = p0:Lerp(p1, e)
	local b = p1:Lerp(p2, e)
	return a:Lerp(b, e)
end

local function create(entry: any): Show?
	local at = Vector3.new(entry.at[1], entry.at[2], entry.at[3])
	local palette = PALETTES[entry.weather] or PALETTES.AuspiciousMist
	local rng = Random.new(#entry.key * 7919 + math.floor(entry.born))
	local yaw = rng:NextNumber() * math.pi * 2
	local model = Instance.new("Model")
	model.Name = "HeavenlyTreasure_" .. entry.key

	local function piece(name: string, spot: Vector3, pieceYaw: number): Model?
		local m = Kit.clone(name)
		if m then
			Kit.place(m, spot, pieceYaw)
			Kit.paint(m, palette)
			m.Parent = model
		end
		return m
	end

	-- the rift sits a little off the spot so the meteor arcs in, not straight down
	local side = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * 140
	local riftAt = Vector3.new(at.X, RIFT_Y, at.Z) + side
	local show: Show = {
		key = entry.key,
		at = at,
		born = entry.born,
		yaw = yaw,
		palette = palette,
		model = model,
		rifts = {},
		riftAt = riftAt,
		crossT = IMPACT,
		meteor = piece("Meteor", riftAt, 0),
		head = nil,
		tail = nil,
		headEmit = {},
		pillar = piece("LightPillar", at, yaw),
		bottom = nil,
		topY = 1400,
		beams = {},
		pillarEmit = {},
		circle = piece("SkyCircle", Vector3.new(at.X, Kit.planeY() - CIRCLE_DROP, at.Z), yaw), -- under the cloud ceiling
		circleImages = {},
		ground = piece("GroundCircle", at, yaw),
		groundImages = {},
		groundEmit = {},
		light = nil,
		lightBrightness = 2.5,
		arcs = {},
		arcEmit = {},
		joined = Kit.now() - entry.born > FALL,
		seenAt = os.clock(),
		leftAt = nil,
		impacted = false,
		lastUpdate = 0,
		farness = -1,
	}

	-- where the meteor's path crosses the cloud plane: the ceiling rift goes there
	local crossAt = at
	for i = 0, 200 do
		local u = i / 200
		local p = TreasureFX._path(show, Kit.inQuad(u))
		if p.Y <= Kit.planeY() then
			show.crossT = FALL + u * (IMPACT - FALL)
			crossAt = p
			break
		end
	end
	local function addRift(spot: Vector3, ceiling: boolean)
		local m = piece("SkyRift", spot, yaw + math.pi / 2)
		if not m then
			return
		end
		local rift: Rift = { model = m, beams = {}, emit = {}, ceiling = ceiling }
		for _, d in m:GetDescendants() do
			if d:IsA("Beam") then
				local seg = d:GetAttribute("Seg")
				table.insert(rift.beams, { beam = d, seg = if type(seg) == "number" then seg else 0 })
				Kit.beam(d, 0, 0)
			elseif d:IsA("ParticleEmitter") then
				rift.emit[d.Name] = d
			end
		end
		table.insert(show.rifts, rift)
	end
	addRift(riftAt, false)
	addRift(Vector3.new(crossAt.X, Kit.planeY() - CEILING_DROP, crossAt.Z), true)
	local meteor = show.meteor
	if meteor then
		show.head = meteor:FindFirstChild("Head") :: BasePart?
		show.tail = meteor:FindFirstChild("Tail", true) :: Trail?
		show.headEmit = emitters(meteor)
	end
	local pillar = show.pillar
	if pillar then
		local shaft = pillar:FindFirstChild("Shaft")
		show.bottom = shaft and shaft:FindFirstChild("Bottom") :: Attachment?
		local top = shaft and shaft:FindFirstChild("Top") :: Attachment?
		show.topY = if top then top.WorldPosition.Y else 1400
		for _, d in pillar:GetDescendants() do
			if d:IsA("Beam") then
				show.beams[d.Name] = d
				Kit.beam(d, 0, 0)
			elseif d:IsA("ParticleEmitter") then
				show.pillarEmit[d.Name] = d
			end
		end
	end
	local circle = show.circle
	if circle then
		local disc = circle:FindFirstChild("Disc") :: BasePart?
		if disc then
			disc.Size = Vector3.new(CIRCLE_RADIUS * 2, 0.2, CIRCLE_RADIUS * 2)
		end
		show.circleImages = images(circle)
	end
	local ground = show.ground
	if ground then
		show.groundImages = images(ground)
		show.groundEmit = emitters(ground)
		show.light = ground:FindFirstChild("Light", true) :: PointLight?
		local b = show.light and show.light:GetAttribute("Brightness")
		show.lightBrightness = if type(b) == "number" then b else 2.5
	end
	local ring = Kit.clone("CloudRing")
	if ring then
		Kit.paint(ring, palette)
		ring.Parent = model
		for _, layer in ring:GetChildren() do
			if not layer:IsA("Model") then
				continue
			end
			local function num(name: string, default: number): number
				local v = layer:GetAttribute(name)
				return if type(v) == "number" then v else default
			end
			for _, p in layer:GetChildren() do
				if p:IsA("BasePart") then
					table.insert(show.arcs, {
						part = p,
						rel = p.CFrame, -- authored about the origin
						layer = layer,
						speed = num("Speed", 0),
						bob = num("Bob", 0),
						bobPeriod = num("BobPeriod", 8),
						phase = num("Phase", 0),
					})
					p.Transparency = 1
				end
			end
		end
		show.arcEmit = emitters(ring)
	end
	for _, img in show.circleImages do
		img.ImageTransparency = 1
	end
	for _, img in show.groundImages do
		img.ImageTransparency = 1
	end
	model.Parent = Kit.folder
	return show
end

local function setOn(list: { ParticleEmitter }, on: boolean)
	for _, e in list do
		if e.Enabled ~= on then
			e.Enabled = on
		end
	end
end

local function imageAlpha(img: ImageLabel, alpha: number, base: number?)
	local b = base or 0
	img.ImageTransparency = 1 - (1 - b) * alpha
end

local function update(show: Show, now: number, clock: number)
	local dist = Kit.distance(show.at)
	local far = dist > FAR
	if far and clock - show.lastUpdate < 0.25 then
		return
	end
	show.lastUpdate = clock
	local t = now - show.born
	local join = if show.joined then Kit.smooth((clock - show.seenAt) / JOIN_FADE) else 1
	local leave = if show.leftAt then Kit.smooth((clock - show.leftAt) / COLLAPSE) else 0
	local live = join * (1 - leave)
	local mid = dist < MID
	local close = dist < CLOSE

	-- the rifts: the high one tears open from its eye during the omen; the ceiling
	-- one glints and shows a faint seam, then tears wide as the meteor punches
	-- through. Both heal after the impact, leaving the sky circle.
	local heal = 1 - Kit.smooth((t - IMPACT - 0.5) / HEAL)
	local shimmer = 1 + 0.12 * math.sin(now * 9)
	for _, rift in show.rifts do
		local emit = rift.emit
		local glintAt = if rift.ceiling then 1 else 0
		if not show.joined and t >= glintAt and rift.model:GetAttribute("Glinted") == nil then
			rift.model:SetAttribute("Glinted", true)
			for _, name in { "Glint", "Lens" } do
				local e = emit[name]
				if e then
					Kit.emit(e)
				end
			end
		end
		local open
		if show.joined then
			open = 1
		elseif rift.ceiling then
			-- a faint seam from the omen, torn wide at the crossing
			open = 0.25 * Kit.smooth((t - 1) / 1.5) + 0.75 * Kit.smooth((t - show.crossT) / CEILING_TEAR)
		else
			open = Kit.smooth(t / OMEN)
		end
		local size = if rift.ceiling then CEILING_SIZE else 1
		for _, rb in rift.beams do
			local reveal = Kit.clamp01(open * 4.5 - rb.seg)
			Kit.beam(rb.beam, size * reveal * heal * shimmer, reveal * heal * live)
		end
		local riftOn = heal > 0.05 and live > 0.05 and mid and open > 0.2
		for _, name in { "Flicker", "Shards" } do
			local e = emit[name]
			if e and e.Enabled ~= riftOn then
				e.Enabled = riftOn
			end
		end
		local rain = emit.Rain
		if rain then
			local from = if rift.ceiling then show.crossT else FALL
			if not show.joined and t >= from and t < IMPACT and rain:GetAttribute("Rained") == nil then
				rain:SetAttribute("Rained", true)
				Kit.emit(rain)
			end
			local on = riftOn and t >= from
			if rain.Enabled ~= on then
				rain.Enabled = on
			end
		end
	end

	-- the meteor: out of the rift, arcing down (accelerating) into the spot
	local head = show.head
	if head then
		local u = (t - FALL) / (IMPACT - FALL)
		local falling = u >= 0 and u < 1 and not show.joined
		if falling then
			Kit.move(head, CFrame.new(TreasureFX._path(show, Kit.inQuad(u))))
		end
		if show.tail and show.tail.Enabled ~= falling then
			show.tail.Enabled = falling
		end
		setOn(show.headEmit, falling)
	end

	-- the impact: the pillar drives down, flash, a gentle pulse near it
	if not show.impacted and t >= IMPACT then
		show.impacted = true
		if t - IMPACT < 1.5 and not show.joined then
			local landing = show.pillar and show.pillar:FindFirstChild("Landing")
			if landing then
				Kit.emit(landing)
			end
			if dist < 150 then
				SkyGrade.pulse({ brightness = 0.25, attack = 0.05, hold = 0.05, decay = 0.6 })
			end
			if dist < 80 then
				TreasureFX.shake(0.2 * (1 - dist / 80) + 0.05)
			end
		end
	end
	local drive = if show.joined then 1 else Kit.smooth((t - IMPACT) / DRIVE)
	local bottom = show.bottom
	if bottom then
		local groundY = show.at.Y + 0.5
		-- drives down from the top; collapses back up when it goes
		local y = show.topY + (groundY - show.topY) * drive
		y += (show.topY - y) * leave
		local p = bottom.WorldPosition
		if math.abs(p.Y - y) > 0.05 then
			bottom.WorldPosition = Vector3.new(p.X, y, p.Z)
		end
	end
	local near = Kit.near(dist, 80, 320)
	local pillarAlpha = Kit.clamp01(drive * 3) * join
	local shimmer = 1 + 0.08 * math.sin(now * 6.3) + 0.04 * math.sin(now * 17)
	local k = PILLAR_SCALE * (1 - 0.6 * leave)
	local beams = show.beams
	if beams.Core then
		Kit.beam(beams.Core, k * shimmer, pillarAlpha)
	end
	-- colour layers widen with distance so the hue survives the haze, and thin out
	-- up close so the pillar isn't a wall of light
	local farness = Kit.smooth((dist - 300) / 900)
	local widen = 1 + 0.8 * farness
	-- and brighten and turn additive with distance: an alpha-blended hue reads up
	-- close, but across 1000 studs of haze only a bright additive glow survives
	-- (far-read test: Haze ~10, Body ~6 from the plaza)
	if math.abs(farness - show.farness) > 0.01 then
		show.farness = farness
		if beams.Body then
			beams.Body.Brightness = 1.6 + 4.4 * farness
			beams.Body.LightEmission = 0.15 + 0.6 * farness
		end
		if beams.Haze then
			beams.Haze.Brightness = 1.2 + 8.8 * farness
			beams.Haze.LightEmission = farness
		end
	end
	if beams.Body then
		Kit.beam(beams.Body, k * widen * (1 - 0.5 * near), pillarAlpha * (1 - 0.6 * near))
	end
	if beams.Haze then
		Kit.beam(beams.Haze, k * widen * (1 - 0.4 * near), pillarAlpha * (1 - 0.95 * near))
	end
	if beams.Flow then
		Kit.beam(beams.Flow, k, pillarAlpha * (if mid then 1 else 0))
	end
	local up = drive >= 1 and live > 0.2
	for name, e in show.pillarEmit do
		local layer = e:GetAttribute("Layer")
		local on = up and (layer == "far" or (layer == "mid" and mid))
		if layer ~= nil and e.Enabled ~= on then
			e.Enabled = on
		end
	end

	-- the sky circle: rings open one after another, turn, shrink out when it goes
	local circleOpen = if show.joined then 1 else Kit.outQuad((t - IMPACT - 0.2) / CIRCLE_OPEN)
	for i, img in show.circleImages do
		local scale = img:GetAttribute("Scale")
		local speed = img:GetAttribute("Speed")
		local o = Kit.clamp01(circleOpen * 1.6 - (i - 1) * 0.15) * (1 - leave)
		local s = (if type(scale) == "number" then scale else 1) * (0.3 + 0.7 * o)
		img.Size = UDim2.fromScale(s, s)
		img.Rotation = (if type(speed) == "number" then speed else 0) * now % 360
		imageAlpha(img, o * join, if img.Name == "Dark" then 0.5 else 0)
	end

	-- the ground sigil and the close layer
	local groundOpen = if show.joined then 1 else Kit.outQuad((t - IMPACT) / 0.8)
	for _, img in show.groundImages do
		local speed = img:GetAttribute("Speed")
		img.Rotation = (if type(speed) == "number" then speed else 0) * now % 360
		imageAlpha(img, groundOpen * live, if img.Name == "Dark" then 0.3 else 0)
	end
	setOn(show.groundEmit, close and groundOpen > 0.5 and live > 0.2)
	if show.light then
		local b = if close then show.lightBrightness * groundOpen * live else 0
		if math.abs(show.light.Brightness - b) > 0.01 then
			show.light.Brightness = b
		end
	end

	-- the wisp rings: settle down from above after the impact, turn and bob; fling
	-- outward and fade when it goes
	local arrive = if show.joined then 1 else Kit.outQuad((t - IMPACT - 0.3) / RING_ARRIVE)
	local arcAlpha = arrive * live
	local spread = 1 + 0.6 * leave
	local origin = CFrame.new(show.at) * CFrame.Angles(0, show.yaw, 0)
	for _, a in show.arcs do
		local turn = CFrame.Angles(0, math.rad(a.speed) * now, 0)
		local bob = a.bob * math.sin(now * math.pi * 2 / a.bobPeriod + a.phase)
		local rel = a.rel
		local pos = rel.Position
		local lift = 80 * (1 - arrive) + bob + 40 * leave
		local placed = turn * CFrame.new(pos.X * spread, pos.Y + lift, pos.Z * spread) * rel.Rotation
		Kit.move(a.part, origin * placed)
		local tr = 1 - arcAlpha
		if math.abs(a.part.Transparency - tr) > 0.01 then
			a.part.Transparency = tr
		end
	end
	setOn(show.arcEmit, mid and arcAlpha > 0.3)
	Kit.flush()
end

local function depart(show: Show)
	if show.leftAt then
		return
	end
	show.leftAt = os.clock()
	task.delay(COLLAPSE + 6, function()
		show.model:Destroy()
	end)
end

-- The sky clears while any treasure is up (so the pillars read from the peaks),
-- and the air near one takes the anomaly's colour.
local function grade(now: number, clock: number)
	local presence, nearest, nearPalette = 0, 0, nil :: Kit.Palette?
	for _, show in shows do
		local t = now - show.born
		local p = Kit.smooth(t / 3) * (if show.leftAt then 1 - Kit.smooth((clock - show.leftAt) / COLLAPSE) else 1)
		presence = math.max(presence, p)
		local n = Kit.near(Kit.distance(show.at), NEAR_INNER, NEAR_OUTER) * p
		if n > nearest then
			nearest, nearPalette = n, show.palette
		end
	end
	if presence > 0 then
		SkyGrade.set("TreasureClear", { weight = presence, densityCap = 0.28, hazeCap = 1.0 })
	else
		SkyGrade.clear("TreasureClear")
	end
	if nearPalette and nearest > 0 then
		SkyGrade.set("TreasureNear", {
			weight = nearest,
			atmoColor = nearPalette.accent,
			atmoMix = 0.55,
			tint = nearPalette.color,
			tintMix = 0.2,
		})
	else
		SkyGrade.clear("TreasureNear")
	end
end

local function sync()
	local raw = workspace:GetAttribute("HeavenlyTreasures")
	local list = {}
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(decoded) == "table" then
			list = decoded
		end
	end
	local live: { [string]: boolean } = {}
	for _, entry in list do
		if not (type(entry) == "table" and type(entry.key) == "string" and type(entry.at) == "table" and type(entry.born) == "number") then
			continue
		end
		live[entry.key] = true
		if not shows[entry.key] then
			local made = create(entry)
			if made then
				shows[entry.key] = made
			end
		end
	end
	for _, show in shows do
		if not live[show.key] then
			depart(show)
		end
	end
end

function TreasureFX.step()
	local now = Kit.now()
	local clock = os.clock()
	for key, show in shows do
		update(show, now, clock)
		if show.leftAt and clock - show.leftAt > COLLAPSE then
			shows[key] = nil
		end
	end
	grade(now, clock)
end

function TreasureFX.init()
	local ok, CombatEffects = pcall(require, (script.Parent.Parent :: Instance):FindFirstChild("CombatEffects") :: ModuleScript)
	if ok and CombatEffects then
		TreasureFX.shake = (CombatEffects :: any).shake
	end
	workspace:GetAttributeChangedSignal("HeavenlyTreasures"):Connect(sync)
	sync()
	RunService.RenderStepped:Connect(function()
		if next(shows) == nil then
			SkyGrade.clear("TreasureClear")
			SkyGrade.clear("TreasureNear")
			return
		end
		TreasureFX.step()
	end)
end

-- Edit-mode preview hooks (tools/worldfx_preview.luau).
TreasureFX._create = create
TreasureFX._update = update
TreasureFX._depart = depart
TreasureFX._shows = shows
TreasureFX._sync = sync

return TreasureFX
