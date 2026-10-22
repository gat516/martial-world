--!strict
-- Shared runtime for the blade techniques that play their own long animation
-- (HeavenSplitter, RampagingTiger): not a technique itself (CombatEffects only
-- loads TechniqueFX.<def.id>). It answers three questions:
--
--   * When: `clock` follows the move's AnimationTrack on the character (the
--     caster's own, or the replicated one on an observer), so every beat lands
--     on the clip's own pose even when the relay arrives late; without a
--     track it runs from the assumed clip time at the speed of def.castSpeed.
--     `sequence` fires beats at clip times and drives spans each frame, and
--     drops what's left if the track stops early (a cancelled cast).
--   * Where: `blade` finds the held weapon (a Model in the character with
--     `Tip` and `Base` attachments, per the weapon model contract; the older
--     lower-case `tip`/`guard` too) and puts an edge on it; without a weapon
--     the edge rides a virtual blade off the right arm.
--   * What: `edge` moves a template's Edge trails/glow/motes onto the blade,
--     `strip` lays ground slits/scars, `drive` is a pausable tween (registered
--     in TechniqueVFX.waves so Edit-mode previews can freeze it).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)

local BladeSkill = {}

function BladeSkill.num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

-- ------------------------------------------------------------------ timing

local function digits(v: any): string?
	if v == nil then
		return nil
	end
	return (tostring(v):match("(%d+)%s*$"))
end

-- The playing track of the technique's animation on `character`, if any.
function BladeSkill.track(character: Model?, def: any): AnimationTrack?
	-- the clip is ReplicatedStorage.Animations.Techniques.<Id> (def.animationId
	-- overrides it when set)
	local id = def.animationId
	if id == nil then
		local anims = game:GetService("ReplicatedStorage"):FindFirstChild("Animations")
		local folder = anims and anims:FindFirstChild("Techniques")
		local anim = folder and folder:FindFirstChild(def.id)
		id = if anim and anim:IsA("Animation") then anim.AnimationId else nil
	end
	local want = digits(id)
	if not (character and want) then
		return nil
	end
	local holder = character:FindFirstChildOfClass("Humanoid") or character:FindFirstChildOfClass("AnimationController")
	local animator = holder and holder:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		local anim = track.Animation
		if anim and digits(anim.AnimationId) == want then
			return track
		end
	end
	return nil
end

-- The clip time of each def hit, in order (def.hits = { { time, damage } },
-- or `fallback` when the def has none yet).
function BladeSkill.hitTimes(def: any, fallback: { number }): { number }
	local out = {}
	if type(def.hits) == "table" then
		for _, h in def.hits do
			local t = if type(h) == "table" then (h.time or h[1]) else h
			if type(t) == "number" then
				table.insert(out, t)
			end
		end
	end
	if #out == 0 then
		return table.clone(fallback)
	end
	table.sort(out)
	return out
end

export type Clock = {
	now: () -> number,
	stopped: () -> boolean, -- the track was found and has stopped (cancelled or ended)
	tracked: boolean,
	track: AnimationTrack?,
}

-- A clip clock. `assumed` is the clip time when there's no track to read
-- (CombatEffects.cast runs at the first hit).
function BladeSkill.clock(character: Model?, def: any, assumed: number): Clock
	local track = BladeSkill.track(character, def)
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else 1
	local last = assumed
	if track and track.TimePosition > 0.02 then
		last = track.TimePosition
	end
	local lastAt = os.clock()
	local ended = false
	local function now(): number
		if track and not ended then
			if track.IsPlaying then
				local tp = track.TimePosition
				if tp + 0.05 >= last then
					if tp > last then
						last, lastAt = tp, os.clock()
					end
					-- a scrubbed track (Edit previews: speed 0) holds the clock
					if track.Speed == 0 then
						lastAt = os.clock()
					end
					return last
				end
			end
			ended = true -- stopped or looped back: extrapolate from here
		end
		return last + (os.clock() - lastAt) * speed
	end
	return {
		now = now,
		stopped = function()
			return track ~= nil and ended
		end,
		tracked = track ~= nil,
		track = track,
	}
end

export type Sequence = {
	at: (self: Sequence, t: number, fn: () -> (), marker: { name: string, value: string? }?) -> (),
	span: (self: Sequence, from: number, to: number, step: (k: number, t: number) -> (), finish: (() -> ())?) -> (),
	start: (self: Sequence, cleanup: (() -> ())?) -> (),
	clock: Clock,
}

-- Beats at clip times and spans (from -> to, step(k 0..1, t) each frame,
-- finish once). If the tracked animation stops before `cancelBefore`, the
-- remaining beats are dropped and open spans finish at once.
function BladeSkill.sequence(clock: Clock, cancelBefore: number): Sequence
	local beats: { { t: number, fn: () -> (), done: boolean } } = {}
	local spans: { { from: number, to: number, step: (number, number) -> (), finish: (() -> ())?, done: boolean } } = {}
	local seq = { clock = clock } :: any
	-- With a `marker` (an animation event on the move's clip) and a tracked
	-- animation, the beat fires on the event itself; the clock time stays as
	-- the fallback (a little late, so the event wins when it comes).
	local markerConns: { RBXScriptConnection } = {}
	function seq:at(t: number, fn: () -> (), marker: { name: string, value: string? }?)
		local beat = { t = t, fn = fn, done = false }
		local track = clock.track
		if marker and track then
			beat.t = t + 0.08
			table.insert(markerConns, track:GetMarkerReachedSignal(marker.name):Connect(function(value)
				if beat.done or (marker.value and tostring(value) ~= marker.value) then
					return
				end
				beat.done = true
				local ok, err = pcall(fn)
				if not ok then
					warn("BladeSkill beat:", err)
				end
			end))
		end
		table.insert(beats, beat)
	end
	function seq:span(from: number, to: number, step: (number, number) -> (), finish: (() -> ())?)
		table.insert(spans, { from = from, to = to, step = step, finish = finish, done = false })
	end
	function seq:start(cleanup: (() -> ())?)
		local conn: RBXScriptConnection
		local function run(t: number, cancelled: boolean)
			local pending = false
			for _, b in beats do
				if not b.done then
					if cancelled then
						b.done = true
					elseif t >= b.t then
						b.done = true
						local ok, err = pcall(b.fn)
						if not ok then
							warn("BladeSkill beat:", err)
						end
					else
						pending = true
					end
				end
			end
			for _, s in spans do
				if not s.done then
					if cancelled or t >= s.to then
						s.done = true
						if t >= s.from and not cancelled then
							pcall(s.step, 1, t)
						end
						if s.finish then
							pcall(s.finish)
						end
					else
						pending = true
						if t >= s.from then
							pcall(s.step, (t - s.from) / math.max(s.to - s.from, 1e-3), t)
						end
					end
				end
			end
			return pending
		end
		local function tick()
			local t = clock.now()
			local cancelled = clock.stopped() and t < cancelBefore
			if not run(t, cancelled) then
				conn:Disconnect()
				for _, c in markerConns do
					c:Disconnect()
				end
				if cleanup then
					cleanup()
				end
			end
		end
		conn = RunService.Heartbeat:Connect(tick)
		tick()
	end
	return seq :: Sequence
end

-- One running sequence per caster and technique: CombatEffects.cast may be
-- called once per cast or once per hit, the effect plays once either way.
local running: { [Instance]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
function BladeSkill.claim(character: Model?, id: string, seconds: number): boolean
	local key: Instance = character or workspace
	local now = os.clock()
	local mine = running[key]
	if not mine then
		mine = {}
		running[key] = mine
	end
	if mine[id] and now < mine[id] then
		return false
	end
	mine[id] = now + seconds
	return true
end

-- A tween on a NumberValue (0 -> seconds) that previews can pause.
function BladeSkill.drive(seconds: number, onStep: (number) -> (), onDone: (() -> ())?)
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(onStep)
	local tween = TweenService:Create(value, TweenInfo.new(math.max(seconds, 0.01), Enum.EasingStyle.Linear), { Value = seconds })
	TechniqueVFX.waves[tween] = true
	tween.Completed:Once(function()
		TechniqueVFX.waves[tween] = nil
		value:Destroy()
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

-- ------------------------------------------------------------------ the blade

export type Blade = {
	base: Attachment, -- hilt end of the edge
	tip: Attachment, -- point
	mid: Attachment, -- 60% along (motes)
	part: BasePart, -- what the attachments ride
	owned: { Instance }, -- created here, destroyed by release()
	real: boolean, -- false: a virtual blade off the arm
}

local function findWeapon(character: Model): (Attachment?, Attachment?)
	for _, child in character:GetChildren() do
		if not child:IsA("Model") and not child:IsA("Tool") and not child:IsA("Accessory") then
			continue
		end
		local tip = child:FindFirstChild("Tip", true) or child:FindFirstChild("tip", true)
		if tip and tip:IsA("Attachment") then
			local base = child:FindFirstChild("Base", true) or child:FindFirstChild("guard", true) or child:FindFirstChild("grip", true)
			return if base and base:IsA("Attachment") then base else nil, tip
		end
	end
	return nil, nil
end

-- An edge on the character's weapon (inner 25% left bare, so the ribbon is
-- the blade, not the grip). nil only without a character or right arm.
function BladeSkill.blade(character: Model?): Blade?
	if not character then
		return nil
	end
	local base, tip = findWeapon(character)
	local owned: { Instance } = {}
	local function att(part: BasePart, name: string, world: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = part
		a.WorldPosition = world
		table.insert(owned, a)
		return a
	end
	if tip then
		local part = tip.Parent :: BasePart
		local p1 = tip.WorldPosition
		local p0 = if base then base.WorldPosition else (part :: BasePart).Position
		local inner = p0 + (p1 - p0) * 0.25
		return {
			base = att(part, "_EdgeBase", inner),
			tip = att(part, "_EdgeTip", p1 + (p1 - p0).Unit * 0.15),
			mid = att(part, "_EdgeMid", p0 + (p1 - p0) * 0.6),
			part = part,
			owned = owned,
			real = true,
		}
	end
	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	if not (arm and arm:IsA("BasePart")) then
		return nil
	end
	-- no weapon: a 4-stud virtual blade continuing the arm
	local down = -arm.CFrame.UpVector
	local hand = arm.Position + down * (arm.Size.Y / 2)
	return {
		base = att(arm, "_EdgeBase", hand + down * 0.8),
		tip = att(arm, "_EdgeTip", hand + down * 4.2),
		mid = att(arm, "_EdgeMid", hand + down * 2.8),
		part = arm,
		owned = owned,
		real = false,
	}
end

function BladeSkill.release(blade: Blade?, delay: number?)
	if not blade then
		return
	end
	task.delay(delay or 0, function()
		for _, inst in blade.owned do
			inst:Destroy()
		end
	end)
end

-- Move the template's Edge pieces (Trails, the Glow beam, the Motes emitter)
-- onto the blade. Returns them by name; all start disabled.
export type Edge = { trails: { Trail }, glow: Beam?, motes: ParticleEmitter? }
function BladeSkill.edge(template: Instance?, blade: Blade): Edge
	local out: Edge = { trails = {}, glow = nil, motes = nil }
	if not template then
		return out
	end
	for _, d in template:GetDescendants() do
		if d:IsA("Trail") then
			d.Attachment0, d.Attachment1 = blade.base, blade.tip
			d.Enabled = false
			d.Parent = blade.part
			table.insert(blade.owned, d)
			table.insert(out.trails, d)
		elseif d:IsA("Beam") and d.Name == "Glow" then
			d.Attachment0, d.Attachment1 = blade.base, blade.tip
			d.Enabled = false
			d.Parent = blade.part
			table.insert(blade.owned, d)
			out.glow = d
		elseif d:IsA("ParticleEmitter") and d.Name == "Motes" then
			d.Enabled = false
			d.Parent = blade.mid
			out.motes = d
		end
	end
	return out
end

function BladeSkill.setTrails(edge: Edge, on: boolean)
	for _, t in edge.trails do
		t.Enabled = on
	end
end

-- The blade's direction and length right now (hilt -> tip).
function BladeSkill.axis(blade: Blade): (Vector3, Vector3, number)
	local a, b = blade.base.WorldPosition, blade.tip.WorldPosition
	local v = b - a
	local len = v.Magnitude
	return a, (if len > 1e-3 then v / len else Vector3.yAxis), len / 0.75 -- full blade length (the edge skips the inner quarter)
end

-- ------------------------------------------------------------------ helpers

-- Root CFrame, flattened to face along the ground.
function BladeSkill.facing(character: Model?, fallbackPos: Vector3, fallbackDir: Vector3): (Vector3, Vector3)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		return root.Position, if flat.Magnitude > 1e-3 then flat.Unit else fallbackDir
	end
	return fallbackPos, fallbackDir
end

-- A ground strip (slit or scar) from `a` to `b` (ground points).
function BladeSkill.placeStrip(strip: BasePart, a: Vector3, b: Vector3, width: number)
	local length = math.max((b - a).Magnitude, 0.05)
	strip.Size = Vector3.new(width, strip.Size.Y, length)
	strip.CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, strip.Size.Y / 2, 0)
end

-- Lay a strip from the template (Cut/Scar convention: StartTransparency, Fade,
-- FadeDelay, FadeColor) along a -> b, opening over `open` seconds, then fade.
function BladeSkill.strip(template: BasePart?, a: Vector3, b: Vector3, open: number, widthScale: number?)
	if not template then
		return
	end
	local s = template:Clone()
	s.Transparency = BladeSkill.num(s, "StartTransparency", 0.2)
	s.CastShadow, s.CanCollide, s.CanQuery, s.CanTouch, s.Anchored = false, false, false, false, true
	local width = s.Size.X * (widthScale or 1)
	BladeSkill.placeStrip(s, a, a + (b - a).Unit * 0.05, width)
	s.Parent = TechniqueVFX.folder
	BladeSkill.drive(open, function(t)
		local k = math.clamp(t / math.max(open, 1e-3), 0, 1)
		k = 1 - (1 - k) ^ 3
		BladeSkill.placeStrip(s, a, a + (b - a) * math.max(k, 0.01), width)
	end, function()
		local colorAttr = s:GetAttribute("FadeColor")
		local goal: { [string]: any } = { Transparency = 1 }
		if typeof(colorAttr) == "Color3" then
			goal.Color = colorAttr
		end
		local tween = TweenService:Create(s, TweenInfo.new(BladeSkill.num(s, "Fade", 0.6), Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, BladeSkill.num(s, "FadeDelay", 0)), goal)
		TechniqueVFX.waves[tween] = true
		tween.Completed:Once(function()
			TechniqueVFX.waves[tween] = nil
			s:Destroy()
		end)
		tween:Play()
	end)
end

-- Carve a rend (block groundRend: part `Rend` and its `RendKicks`) into the
-- ground from the bite `a` toward `b` (ground points), opening over `open`
-- seconds: the carving grows from the bite with its Textures held still on
-- the ground (their U origin rides the part's +X edge, which stays on `a`),
-- the qi seam burns in it and cools (GlowFade), the carving lingers
-- (CarveHold) and fades (CarveFade); the stations along the path kick dust,
-- chips and rocks as the carving reaches them. `widthScale` widens it.
function BladeSkill.rend(template: BasePart?, kicksT: BasePart?, a: Vector3, b: Vector3, open: number, widthScale: number?)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	if length < 0.5 then
		return
	end
	local dir = flat / length
	local up = Vector3.yAxis
	local ws = widthScale or 1
	open = math.max(open, 0.02)
	if kicksT then
		local kicks = kicksT:Clone()
		kicks.Size = Vector3.new(kicks.Size.X * ws, kicks.Size.Y, length)
		kicks.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + dir) + up * 0.2
		for _, d in kicks:GetChildren() do
			local along = d:GetAttribute("Along")
			if d:IsA("Attachment") and type(along) == "number" then
				local p = a + (b - a) * along
				d.WorldPosition = Vector3.new(p.X, CastFX.groundBelow(p + up * 2) + 0.15, p.Z)
				d:SetAttribute("EmitDelay", along * open)
			end
		end
		kicks.Parent = TechniqueVFX.folder
		TechniqueVFX.emit(kicks)
		TechniqueVFX.cleanup(kicks, 0.3)
	end
	if not template then
		return
	end
	local r = template:Clone()
	local width = BladeSkill.num(r, "Width", r.Size.Z) * ws
	-- child parts (the slit, III+ the crack web) ride along at their own widths
	local layers: { { part: BasePart, width: number } } = {}
	for _, c in r:GetChildren() do
		if c:IsA("BasePart") then
			table.insert(layers, { part = c, width = c.Size.Z * ws })
		end
	end
	local textures: { Texture } = {}
	for _, d in r:GetDescendants() do
		if d:IsA("Texture") and d.Parent then
			-- U runs the path once; V shows the middle `Band` of the image
			-- across the part's width (thin drawn strokes read thick)
			local w = if d.Parent == r then width else (d.Parent :: BasePart).Size.Z * ws
			local band = math.clamp(BladeSkill.num(d, "Band", 1), 0.05, 1)
			d.StudsPerTileU = length
			d.StudsPerTileV = w / band
			d.OffsetStudsV = (w / band - w) / 2
			table.insert(textures, d)
		end
	end
	local seamA = r:FindFirstChild("SeamA") :: Attachment?
	local seamB = r:FindFirstChild("SeamB") :: Attachment?
	local beams: { Beam } = {}
	for _, d in r:GetChildren() do
		if d:IsA("Beam") then
			d.Width0 *= ws
			d.Width1 *= ws
			table.insert(beams, d)
		end
	end
	local back = -dir -- the part's +X looks back at the bite
	local function place(k: number)
		local len = math.max(length * k, 0.05)
		local centre = a + dir * (len / 2) + up * 0.05
		local cf = CFrame.fromMatrix(centre, back, up)
		r.Size = Vector3.new(len, r.Size.Y, width)
		r.CFrame = cf
		for i, l in layers do
			l.part.Size = Vector3.new(len, l.part.Size.Y, l.width)
			l.part.CFrame = cf + up * (0.01 * i)
		end
		local turn = CFrame.Angles(0, 0, math.pi / 2)
		if seamA then
			seamA.CFrame = CFrame.new(len / 2, 0.08, 0) * turn
		end
		if seamB then
			seamB.CFrame = CFrame.new(-len / 2, 0.08, 0) * turn
		end
	end
	place(0.02)
	r.Parent = TechniqueVFX.folder
	local glowColor = r:GetAttribute("GlowColor")
	local inkColor = r:GetAttribute("InkColor")
	local slit = r:FindFirstChild("Slit") :: Texture?
	local brightness = BladeSkill.num(r, "Brightness", 3)
	local glowFade = BladeSkill.num(r, "GlowFade", 0.6)
	local carveHold = BladeSkill.num(r, "CarveHold", 1)
	local carveFade = BladeSkill.num(r, "CarveFade", 1)
	local baseT: { [Beam]: NumberSequence } = {}
	for _, bm in beams do
		baseT[bm] = bm.Transparency
	end
	BladeSkill.drive(open, function(t)
		local k = math.clamp(t / open, 0, 1)
		place(1 - (1 - k) ^ 2)
	end, function()
		place(1)
		-- the seam cools: bright -> gone, the slit's tint -> ink
		BladeSkill.drive(glowFade, function(t)
			local f = math.clamp(t / glowFade, 0, 1)
			for _, bm in beams do
				bm.Brightness = brightness * (1 - f) ^ 2
				local kps = {}
				for _, kp in baseT[bm].Keypoints do
					table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * f * f))
				end
				bm.Transparency = NumberSequence.new(kps)
			end
			if slit and typeof(glowColor) == "Color3" and typeof(inkColor) == "Color3" then
				slit.Color3 = glowColor:Lerp(inkColor, f)
			end
		end)
		-- the carving lingers, then fades
		local fades: { { tex: Texture, from: number } } = {}
		for _, tex in textures do
			table.insert(fades, { tex = tex, from = tex.Transparency })
		end
		BladeSkill.drive(carveHold + carveFade, function(t)
			local f = math.clamp((t - carveHold) / carveFade, 0, 1)
			for _, e in fades do
				e.tex.Transparency = e.from + (1 - e.from) * f * f
			end
		end, function()
			r:Destroy()
		end)
	end)
end

-- Seconds until a Quart-Out MeshWave of `duration` reaches `frac` of its size.
function BladeSkill.quartTime(duration: number, frac: number): number
	return duration * (1 - (1 - math.clamp(frac, 0, 1)) ^ 0.25)
end

-- Play a copy of a template part placed at `cf` (Body raised by `height`).
function BladeSkill.burst(part: BasePart?, cf: CFrame)
	if part then
		TechniqueVFX.burstAt(part, cf)
	end
end

-- Enemies in a circle (for each hit), nearest first.
function BladeSkill.circleTargets(centre: Vector3, radius: number, character: Model?, cap: number?): { CastFX.Target }
	return CastFX.targets({ kind = "circle", origin = centre, radius = radius, character = character, cap = cap or 6 })
end

-- Fade a set of Beams out (transparency `from` -> 1) after `hold`, over `fade`,
-- easing In so they stay solid and go late. Calls done() at the end.
function BladeSkill.fadeBeams(beams: { Beam }, hold: number, fade: number, done: (() -> ())?)
	local base: { [Beam]: NumberSequence } = {}
	for _, b in beams do
		base[b] = b.Transparency
	end
	BladeSkill.drive(hold + fade, function(t)
		local k = math.clamp((t - hold) / math.max(fade, 1e-3), 0, 1)
		k = k * k
		for b, seq in base do
			local kps = {}
			for _, kp in seq.Keypoints do
				table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * k))
			end
			b.Transparency = NumberSequence.new(kps)
		end
	end, done)
end

-- Shake fallback when the Game Module (ScreenEffects) isn't there.
function BladeSkill.shake(CombatEffects: any, tier: number, at: Vector3, scale: number)
	if not TechniqueVFX.full and CastFX.nearCamera(at, 45) then
		CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * scale)
	end
end

-- Rescale a template's ground wave part (groundShockwave layout) from its
-- authored radius by `k`: MeshWave ToSize X/Z, ring emitters' Size, the dust
-- skirt's speed, a Craters ring's Radius.
function BladeSkill.fitRadius(part: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in part:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MeshWave") then
			local to = d:GetAttribute("ToSize")
			if typeof(to) == "Vector3" and to.X > 3 then
				d:SetAttribute("ToSize", Vector3.new(to.X * k, to.Y, to.Z * k))
			end
		elseif d:IsA("ParticleEmitter") then
			if d.Name == "WaveFront" or d.Name == "WaveEcho" or d.Name == "Seal" or d.Name == "Halo" then
				local kps = {}
				for _, kp in d.Size.Keypoints do
					table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k))
				end
				d.Size = NumberSequence.new(kps)
			elseif d.Name == "Dust" then
				d.Speed = NumberRange.new(d.Speed.Min * k, d.Speed.Max * k)
			end
		elseif d:IsA("Attachment") and type(d:GetAttribute("Radius")) == "number" then
			d:SetAttribute("Radius", (d:GetAttribute("Radius") :: number) * k)
		end
	end
end

return BladeSkill
