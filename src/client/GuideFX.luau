--!strict
-- The onboarding guide's world visuals (Guide.luau's `place` guides), from the
-- template ReplicatedStorage.Effects.Guide (builder and layout notes in
-- tools/vfx_specs/Guide.luau). This client only.
--
--   path    a stream of jade qi along the ground from the player's feet toward
--           the target: one flat Stream beam (over a dark Bed beam) per
--           SEGMENT studs, each end raycast onto the ground so it follows
--           terrain and steps; it stops at a drop or a gap rather than float.
--           Spirit motes (Drift) run along it ahead of the player, on a loop.
--   marker  at the target's foot: a slow formation circle turning on the
--           ground (sized to the target's footprint) and a faint column of
--           light for reading it from afar, with a few motes rising.
--   arrive  once, when the player reaches the target: the formation flares,
--           a soft ring of light runs out over the ground and motes lift off,
--           with a soft chime (Sfx "GuideArrive").
--
-- Guide.luau owns when each shows; this module only places and plays them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Sfx = require(script.Parent.Sfx)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local GuideFX = {}

-- Where clones go (this client only); Edit-mode previews may point it at a
-- workspace folder.
GuideFX.folder = Workspace.CurrentCamera :: Instance
-- The template's parent (ReplicatedStorage.Effects); previews may swap it.
GuideFX.source = nil :: Instance?

local SEGMENT = 4 -- studs between ground samples along the path
local START = 2.5 -- the stream starts this far ahead of the feet
local MAX_LENGTH = 28 -- studs of path shown ahead of the player
local LIFT = 0.15 -- studs above the ground
local PROBE_UP = 10 -- rays start this far above the higher of player and target
local PROBE_DOWN = 80
local MAX_DROP = 10 -- a sample this far below the last one ends the path (a cliff)
local STEP_UP = 0.5 -- a gap whose ends differ this much in height gets a sample between (a stair's edge)
local REFRESH = 0.2 -- seconds between re-sampling the ground while standing still
local MOVED = 0.75 -- studs the player moves before the path is re-sampled
local FADE_IN = 0.12 -- the stream's first share fades in from the feet
local FADE_OUT = 0.3 -- its last share fades out
local MOTE_SPEED = 11 -- studs a second the motes run ahead
local MIN_RADIUS = 3
local MAX_RADIUS = 9
local PAD = 3 -- the circle reaches this far past the target's footprint

type Path = {
	points: { Vector3 },
	length: number,
	from: Vector3,
	goal: Vector3,
	at: number,
}

local template: Instance? = nil
local streams: { Beam } = {}
local beds: { Beam } = {}
local anchors: { Attachment } = {}
local drift: Attachment
local driftMotes: ParticleEmitter
local marker: Model
local markerCircle: BasePart
local markerTop: Attachment
local markerColumn: Beam
local markerMotes: ParticleEmitter
local rings: { ImageLabel } = {}
local markerRadius = 5
local markerHeight = 16
local ready = false

local path: Path? = nil
local shown = 0 -- segments currently shown
local runner = 0 -- distance of the mote runner along the path
local markerOn = false
local markerFor: Instance? = nil
local markerAt: CFrame? = nil
local markerPart: Vector3? = nil -- where the target's part was when the spot was found
local markerScale = 1

local function source(): Instance?
	local root = GuideFX.source or ReplicatedStorage:FindFirstChild("Effects")
	return root and root:FindFirstChild("Guide")
end

local function init(): boolean
	if ready then
		return true
	end
	local t = source()
	if not t then
		return false
	end
	template = t
	local stream = t:FindFirstChild("Stream") :: Beam
	local bed = t:FindFirstChild("Bed") :: Beam
	local segments = (math.ceil(MAX_LENGTH / SEGMENT) + 1) * 2 -- room for split gaps
	for i = 1, segments + 1 do
		local a = Instance.new("Attachment")
		a.Name = "GuidePath"
		a.Parent = Workspace.Terrain
		anchors[i] = a
	end
	for i = 1, segments do
		local s = stream:Clone()
		s.Attachment0, s.Attachment1 = anchors[i], anchors[i + 1]
		s.Enabled = false
		s.Parent = Workspace.Terrain
		streams[i] = s
		local b = bed:Clone()
		b.Attachment0, b.Attachment1 = anchors[i], anchors[i + 1]
		b.Enabled = false
		b.Parent = Workspace.Terrain
		beds[i] = b
	end
	drift = (t:FindFirstChild("Drift") :: Attachment):Clone()
	drift.Parent = Workspace.Terrain
	driftMotes = drift:FindFirstChild("Motes") :: ParticleEmitter

	marker = (t:FindFirstChild("Marker") :: Model):Clone()
	markerRadius = (marker:GetAttribute("Radius") :: number?) or 5
	markerHeight = (marker:GetAttribute("Height") :: number?) or 16
	markerCircle = marker:FindFirstChild("Circle") :: BasePart
	markerTop = markerCircle:FindFirstChild("Top") :: Attachment
	markerColumn = markerCircle:FindFirstChild("Column") :: Beam
	markerMotes = markerCircle:FindFirstChild("Motes") :: ParticleEmitter
	local gui = markerCircle:FindFirstChildWhichIsA("SurfaceGui") :: SurfaceGui
	for _, img in gui:GetChildren() do
		if img:IsA("ImageLabel") then
			table.insert(rings, img)
		end
	end
	gui.Enabled = false
	markerColumn.Enabled = false
	markerMotes.Enabled = false
	marker.Parent = GuideFX.folder
	ready = true
	return true
end

--[[ Ground ]]

local function ignoreList(extra: { Instance }?): { Instance }
	local list: { Instance } = { GuideFX.folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, inst in extra or {} do
		table.insert(list, inst)
	end
	return list
end

-- The ground under (x, z), from `top` down: terrain or a solid, visible,
-- non-character part. Bodies (enemies, NPCs) and invisible walls are skipped.
local function groundAt(x: number, z: number, top: number, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	local origin = Vector3.new(x, top, z)
	for _ = 1, 4 do
		local hit = Workspace:Raycast(origin, Vector3.new(0, -PROBE_DOWN, 0), params)
		if not hit then
			return nil
		end
		local inst = hit.Instance
		local body = inst:FindFirstAncestorWhichIsA("Model")
		local isBody = body ~= nil and body:FindFirstChildWhichIsA("Humanoid") ~= nil
		if inst:IsA("BasePart") and (inst.Transparency > 0.9 or isBody) then
			params:AddToFilter(if isBody and body then body :: Instance else inst)
			origin = hit.Position + Vector3.new(0, 0.01, 0)
			continue
		end
		return hit.Position
	end
	return nil
end

-- The ground point at a target's foot and the circle's radius from its footprint.
function GuideFX.footOf(target: Instance, part: BasePart): (Vector3?, number)
	local cf, size
	if target:IsA("Model") then
		cf, size = target:GetBoundingBox()
	else
		cf, size = part.CFrame, part.Size
	end
	local radius = math.clamp(math.max(size.X, size.Z) / 2 + PAD, MIN_RADIUS, MAX_RADIUS)
	local top = cf.Position.Y + size.Y / 2 + 2
	local ground = groundAt(cf.Position.X, cf.Position.Z, top, ignoreList({ target }))
	return ground, radius
end

--[[ Path ]]

local function sample(from: Vector3, goal: Vector3, stop: number): Path?
	local flat = (goal - from) * Vector3.new(1, 0, 1)
	local total = math.min(flat.Magnitude - stop, MAX_LENGTH + START)
	if total < START + SEGMENT * 0.75 then
		return nil
	end
	local dir = flat.Unit
	local top = math.max(from.Y, goal.Y) + PROBE_UP
	local ignore = ignoreList()
	local points: { Vector3 } = {}
	local d = START
	local last = from.Y - 3
	local lastD = d
	while d <= total + 1e-3 do
		local xz = from + dir * d
		local g = groundAt(xz.X, xz.Z, top, ignore)
		if not g or last - g.Y > MAX_DROP then
			break
		end
		if #points > 0 and math.abs(g.Y - last) > STEP_UP then
			-- split the gap so the stream folds over the edge instead of cutting through it
			local mid = from + dir * ((lastD + d) / 2)
			local m = groundAt(mid.X, mid.Z, top, ignore)
			if m and last - m.Y <= MAX_DROP then
				table.insert(points, m + Vector3.new(0, LIFT, 0))
			end
		end
		table.insert(points, g + Vector3.new(0, LIFT, 0))
		last = g.Y
		lastD = d
		if d >= total then
			break
		end
		d = math.min(d + SEGMENT, total)
	end
	if #points < 2 then
		return nil
	end
	local length = 0
	for i = 2, #points do
		length += (points[i] - points[i - 1]).Magnitude
	end
	return { points = points, length = length, from = from, goal = goal, at = os.clock() }
end

local function fade(t: number, base: number): number
	local k = math.min(1, t / FADE_IN, (1 - t) / FADE_OUT)
	return 1 - (1 - base) * math.max(0, k)
end

local function lay(p: Path)
	local pts = p.points
	local n = #pts - 1
	-- each joint's width axis (Y) lies sideways on the ground, so the beams lie flat
	for i, pos in pts do
		local a = pts[math.max(1, i - 1)]
		local b = pts[math.min(#pts, i + 1)]
		local along = b - a
		local side = Vector3.yAxis:Cross(along)
		if side.Magnitude < 1e-3 then
			side = Vector3.xAxis
		end
		anchors[i].WorldCFrame = CFrame.fromMatrix(pos, along.Unit, side.Unit)
	end
	local run = 0
	for i = 1, #streams do
		local on = i <= n
		if on then
			local seg = (pts[i + 1] - pts[i]).Magnitude
			local t0, t1 = run / p.length, (run + seg) / p.length
			run += seg
			local s, b = streams[i], beds[i]
			s.TextureLength = math.max(seg, 0.5)
			b.TextureLength = math.max(seg, 0.5)
			s.Transparency = NumberSequence.new(fade(t0, 0.4), fade(t1, 0.4))
			b.Transparency = NumberSequence.new(fade(t0, 0.78), fade(t1, 0.78))
		end
		streams[i].Enabled = on
		beds[i].Enabled = on
	end
	shown = n
end

local function pointAlong(p: Path, distance: number): Vector3
	local pts = p.points
	for i = 2, #pts do
		local seg = (pts[i] - pts[i - 1]).Magnitude
		if distance <= seg then
			return pts[i - 1]:Lerp(pts[i], if seg > 0 then distance / seg else 0)
		end
		distance -= seg
	end
	return pts[#pts]
end

-- Show the path from `from` (the player's root) toward `goal`, ending `stop`
-- studs short of it (the marker's edge). Call every frame; it re-samples the
-- ground only when the player moved or a moment passed.
function GuideFX.showPath(from: Vector3, goal: Vector3, stop: number, dt: number)
	if not init() then
		return
	end
	local p = path
	local now = os.clock()
	if not p or (p.from - from).Magnitude > MOVED or (p.goal - goal).Magnitude > MOVED or now - p.at > REFRESH then
		p = sample(from, goal, stop)
		path = p
		if p then
			lay(p)
		end
	end
	if not p then
		GuideFX.hidePath()
		return
	end
	runner = (runner + dt * MOTE_SPEED) % (p.length + 4) -- a short gap before it loops
	if runner <= p.length then
		drift.WorldPosition = pointAlong(p, runner) + Vector3.new(0, 0.5, 0)
		driftMotes.Enabled = true
	else
		driftMotes.Enabled = false
	end
end

function GuideFX.hidePath()
	path = nil
	if not ready then
		return
	end
	if shown > 0 then
		for i = 1, #streams do
			streams[i].Enabled = false
			beds[i].Enabled = false
		end
		shown = 0
	end
	driftMotes.Enabled = false
end

--[[ Marker ]]

-- Show the marker at `target`'s foot (re-found when the target changes or
-- moves). Returns the circle's radius, or nil when there's no ground under it.
function GuideFX.showMarker(target: Instance, part: BasePart, column: boolean, now: number): number?
	if not init() then
		return nil
	end
	if markerFor ~= target or not markerPart or (markerPart - part.Position).Magnitude > 1 then
		local ground, radius = GuideFX.footOf(target, part)
		if not ground then
			GuideFX.hideMarker()
			return nil
		end
		markerFor = target
		markerPart = part.Position
		markerAt = CFrame.new(ground)
		marker:PivotTo(markerAt :: CFrame) -- the template pivot is identity: stays upright
		markerScale = radius / markerRadius
		markerCircle.Size = Vector3.new(radius * 2, markerCircle.Size.Y, radius * 2)
		markerTop.Position = Vector3.new(0, markerHeight * math.clamp(markerScale, 0.8, 1.3), 0)
	end
	for _, img in rings do
		local spin = img:GetAttribute("Spin")
		img.Rotation = (now * (if type(spin) == "number" then spin else 0)) % 360
	end
	if not markerOn then
		markerOn = true
		;(markerCircle:FindFirstChildWhichIsA("SurfaceGui") :: SurfaceGui).Enabled = true
		markerMotes.Enabled = true
	end
	markerColumn.Enabled = column
	return markerRadius * markerScale
end

function GuideFX.hideMarker()
	if not ready or not markerOn then
		return
	end
	markerOn = false
	;(markerCircle:FindFirstChildWhichIsA("SurfaceGui") :: SurfaceGui).Enabled = false
	markerColumn.Enabled = false
	markerMotes.Enabled = false
end

-- Forget the marker's spot (the guide changed).
function GuideFX.reset()
	GuideFX.hidePath()
	GuideFX.hideMarker()
	markerFor = nil
	markerAt = nil
	markerPart = nil
end

--[[ Arrival ]]

-- The one-shot flourish where the marker stands (or at `at`), then the marker
-- hides. The Seal takes over from the circle at the same size on frame 1.
function GuideFX.arrive(at: Vector3?, radius: number?)
	if not init() then
		return
	end
	local spot = at or (markerAt and markerAt.Position)
	if not spot then
		return
	end
	local proto = (template :: Instance):FindFirstChild("Arrive") :: Model
	local copy = proto:Clone()
	local authored = (copy:GetAttribute("Radius") :: number?) or 5
	local k = (radius or markerRadius * markerScale) / authored
	if math.abs(k - 1) > 1e-3 then
		local rim = copy:FindFirstChild("Rim")
		if rim and rim:IsA("BasePart") then
			rim.Size = Vector3.new(rim.Size.X * k, rim.Size.Y, rim.Size.Z * k)
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("ParticleEmitter") and (d.Name == "Seal" or d.Name == "Ring") then
				local keys = {}
				for _, key in d.Size.Keypoints do
					table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * k, key.Envelope * k))
				end
				d.Size = NumberSequence.new(keys)
			end
		end
	end
	copy:PivotTo(CFrame.new(spot) * proto:GetPivot().Rotation)
	copy.Parent = GuideFX.folder
	GuideFX.hideMarker()
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.5)
	Sfx.play("GuideArrive", spot)
end

return GuideFX
