--!strict
-- Heaven-Splitting Descent (Greatsword) from its tier template
-- (ReplicatedStorage.Effects.HeavenSplitter, built from
-- tools/vfx_specs/HeavenSplitter.luau). Called by CombatEffects.cast for the
-- caster and observers; it plays the whole move once per cast, synced to the
-- clip (BladeSkill.clock/sequence: the playing track and its markers).
--
-- Clip beats (markers on Skill_HeavenSplitter): Hit 1 0.18 (low sweep),
-- Hit 2 1.02 + Leap 1.10 (rising cut, launch), airborne to Hit 3 2.12 + Land
-- 2.17 (the overhead slam), Hit Stop 3 2.23. The blade draws its own arcs
-- (Edge trails on the weapon) in the windows the sampled motion swings
-- through; the slam lands at the root's live position, so the backend's
-- lunge is already in it.

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local BladeSkill = require(script.Parent.BladeSkill)
local WeaponFX = require(script.Parent.WeaponFX)

local HITS = { 0.1833, 1.0167, 2.1167 } -- until def.hits exists
local LEAP = 1.10
local SPEED = 1.3
-- when the blade is actually swinging (clip s, sampled): the low sweep crosses
-- the front 0.45-0.58, the rising cut 1.05-1.25, the slam 2.10-2.25
local SWINGS = { { 0.36, 0.66 }, { 1.0, 1.32 }, { 2.04, 2.34 } }
local GLOW = { 1.0, 2.3 } -- the blade wreathed in qi from the launch to the bite
local PHANTOM_FROM = 1.9

local function cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return false
	end
	dir = dir.Unit
	local hits = BladeSkill.hitTimes(def, HITS)
	local slamAt = hits[#hits]
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else SPEED
	local groundY = CastFX.groundBelow(origin)
	local ground = Vector3.new(origin.X, groundY, origin.Z)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	if not BladeSkill.claim(character, def.id, (slamAt - hits[1]) / speed + 0.3) then
		copy:Destroy()
		return true -- already playing this cast (called again for a later hit)
	end
	local radius = if type(def.radius) == "number" then def.radius else BladeSkill.num(copy, "AuthoredRadius", 12)
	local offset = if type(def.offset) == "number" then def.offset else BladeSkill.num(copy, "AuthoredOffset", 4)
	local k = radius / BladeSkill.num(copy, "AuthoredRadius", 12)

	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	local edgeT = TechniqueVFX.take(copy, "Edge")
	local flare = TechniqueVFX.take(copy, "Flare")
	local lightImpact = TechniqueVFX.take(copy, "LightImpact")
	local impact = TechniqueVFX.take(copy, "Impact")
	local launch = TechniqueVFX.take(copy, "Launch")
	local mark = TechniqueVFX.take(copy, "Mark")
	local rift = TechniqueVFX.take(copy, "Rift")
	local phantom = TechniqueVFX.take(copy, "Phantom")
	local rend = TechniqueVFX.take(copy, "Rend")
	local rendKicks = TechniqueVFX.take(copy, "RendKicks")
	local slam = copy:FindFirstChild("Slam") :: BasePart?
	if slam then
		BladeSkill.fitRadius(slam, k)
	end
	if mark then
		BladeSkill.fitRadius(mark, k)
	end
	CastFX.keepCratersOffEnemies()

	local clock = BladeSkill.clock(character, def, hits[1])
	local seq = BladeSkill.sequence(clock, slamAt)
	local blade = BladeSkill.blade(character)
	local edge = if blade then BladeSkill.edge(edgeT, blade) else nil
	if edgeT then
		edgeT:Destroy()
	end

	-- where the landing circle will be: the root's live position (the lunge is
	-- the backend's), `offset` ahead
	local function centreNow(): (Vector3, Vector3, Vector3)
		local pos, look = BladeSkill.facing(character, origin, dir)
		local feet = CastFX.groundAt(pos)
		return feet + look * offset, feet, look
	end
	-- the lunge still to come at clip time t (the root is driven over
	-- def.lungeWindow, Leap -> Land, assumed even)
	local lunge = if type(def.lunge) == "number" then def.lunge else 6
	local window = if type(def.lungeWindow) == "table" then def.lungeWindow else { LEAP, 2.1667 }
	local function aheadAt(t: number): number
		return lunge * math.clamp((window[2] - t) / math.max(window[2] - window[1], 0.1), 0, 1)
	end

	-- each Hit marker fires as a swing starts (the blade still raised); the
	-- flare, the impacts and the slam's bite land where the blade does, at the
	-- swing's peak inside that hit's Hit -> Hit Stop window
	local function onSwing(index: number, fallback: Vector3, fn: (Vector3, Vector3) -> ())
		WeaponFX.swing(character, WeaponFX.hitWindow(def, index), fn, fallback)
	end

	-- the blade's arcs
	if edge then
		for _, w in SWINGS do
			seq:span(w[1], w[2], function()
				BladeSkill.setTrails(edge, true)
			end, function()
				BladeSkill.setTrails(edge, false)
			end)
		end
		seq:span(GLOW[1], GLOW[2], function()
			if edge.glow then
				edge.glow.Enabled = true
			end
			if edge.motes and tier >= 2 then
				edge.motes.Enabled = true
			end
		end, function()
			if edge.glow then
				edge.glow.Enabled = false
			end
			if edge.motes then
				edge.motes.Enabled = false
			end
		end)
	end

	-- light hits: every enemy in the circle (as it stands now)
	for i = 1, #hits - 1 do
		seq:at(hits[i], function()
			local centre = centreNow()
			onSwing(i, centre + Vector3.new(0, 3, 0), function(at, swing)
				WeaponFX.flare(flare, at, swing, 1)
				if lightImpact then
					for _, target in BladeSkill.circleTargets(centre, radius, character, 4) do
						CastFX.impactAt(lightImpact, target)
						if target.model.Parent then
							CombatEffects.flash(target.model)
						end
					end
				end
			end)
		end, { name = "Hit", value = tostring(i) })
	end

	-- take-off
	seq:at(LEAP, function()
		if launch then
			local _, feet, look = centreNow()
			TechniqueVFX.burstAt(launch, CFrame.lookAt(feet, feet + look))
		end
	end, { name = "Leap" })

	-- airborne: the seal over the landing circle and the rift above it
	local airFrom = LEAP + 0.15
	local airSeconds = math.max((slamAt - airFrom) / speed, 0.1)
	local markCopy: BasePart?, riftCopy: BasePart?
	local function predicted(t: number): (Vector3, Vector3)
		local centre, _, look = centreNow()
		return centre + look * aheadAt(t), look
	end
	if mark or rift then
		seq:span(airFrom, slamAt, function(_, t)
			local at, look = predicted(t)
			if mark and not markCopy then
				local m = mark:Clone()
				TechniqueVFX.fit(m, nil, BladeSkill.num(m, "AuthoredAir", 0.67), airSeconds)
				for _, e in m:GetDescendants() do
					if e:IsA("ParticleEmitter") then
						e.LockedToPart = true
					end
				end
				m.CFrame = CFrame.lookAt(at, at + look) + Vector3.new(0, 0.15, 0)
				m.Parent = TechniqueVFX.folder
				TechniqueVFX.emit(m)
				markCopy = m
			end
			if rift and not riftCopy then
				local r = rift:Clone()
				r.Parent = TechniqueVFX.folder
				for _, b in r:GetDescendants() do
					if b:IsA("Beam") then
						b.Enabled = true
					elseif b:IsA("ParticleEmitter") then
						b.Enabled = true
					end
				end
				riftCopy = r
			end
			if markCopy then
				markCopy.CFrame = CFrame.lookAt(at, at + look) + Vector3.new(0, 0.15, 0)
			end
			if riftCopy and rift then
				local height = (rift :: BasePart).Position.Y - (copy:GetPivot().Position.Y)
				riftCopy.CFrame = CFrame.lookAt(at + Vector3.new(0, height, 0), at + Vector3.new(0, height, 0) + look)
				-- tears open fast, then keeps widening to the slam
				local open = math.clamp((t - airFrom) / math.max(slamAt - airFrom, 0.1), 0, 1)
				local w = BladeSkill.num(rift, "Width", 1.2) * (0.35 + 0.65 * (1 - (1 - open) ^ 2))
				for _, b in riftCopy:GetDescendants() do
					if b:IsA("Beam") then
						local s = BladeSkill.num(b, "Scale", 1)
						if b.Name:match("Upper$") then
							b.Width0, b.Width1 = 0, w * s
						else
							b.Width0, b.Width1 = w * s, 0
						end
					end
				end
			end
		end, function()
			if markCopy then
				TechniqueVFX.cleanup(markCopy, 0.1)
			end
			if riftCopy then
				-- the rift closes as the pillar drops through it
				local beams = {}
				for _, b in riftCopy:GetDescendants() do
					if b:IsA("Beam") then
						table.insert(beams, b)
					elseif b:IsA("ParticleEmitter") then
						b.Enabled = false
					end
				end
				local r = riftCopy
				BladeSkill.fadeBeams(beams, 0.06, 0.3, function()
					r:Destroy()
				end)
			end
		end)
	end

	-- the phantom blade laid over the real one as it comes down
	if phantom and blade then
		local len = BladeSkill.num(phantom, "Length", 12) * k ^ 0.5
		local width = BladeSkill.num(phantom, "Width", 1.8)
		local t0 = BladeSkill.num(phantom, "StartTransparency", 0.3)
		local pieces: { { part: BasePart, kind: string } } = {}
		for _, m in phantom:GetChildren() do
			local mesh = m:FindFirstChild("Mesh")
			if m:IsA("Model") and mesh and mesh:IsA("BasePart") then
				local p = mesh:Clone()
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Transparency = 1
				p.Parent = TechniqueVFX.folder
				table.insert(pieces, { part = p, kind = m.Name })
			end
		end
		local function place(alpha: number)
			local a, u = BladeSkill.axis(blade)
			local _, _, look = centreNow()
			local right = look:Cross(Vector3.yAxis)
			right = (right - u * right:Dot(u))
			right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
			local w = right:Cross(u)
			local tipLen = width * 1.2
			local bodyLen = len - tipLen
			local base = a - u * 0.6
			for _, piece in pieces do
				local p = piece.part
				if piece.kind == "Tip" then
					p.Size = Vector3.new(0.3, width, tipLen)
					p.CFrame = CFrame.fromMatrix(base + u * (bodyLen + tipLen / 2), right, w)
				elseif piece.kind == "Aura" then
					p.Size = Vector3.new(0.9, width * 1.35, len * 1.04)
					p.CFrame = CFrame.fromMatrix(base + u * (len / 2), right, w)
				else
					p.Size = Vector3.new(0.3, width, bodyLen)
					p.CFrame = CFrame.fromMatrix(base + u * (bodyLen / 2), right, w)
				end
				p.Transparency = 1 - (1 - t0) * alpha * (if piece.kind == "Aura" then 0.7 else 1)
			end
		end
		-- follows the real blade until it has bitten the ground (the last Hit Stop)
		local last = type(def.hits) == "table" and def.hits[#def.hits]
		local bitten = (if type(last) == "table" and type(last.stop) == "number" then last.stop else slamAt + 0.12) + 0.03
		seq:span(PHANTOM_FROM, bitten, function(_, t)
			place(math.clamp((t - PHANTOM_FROM) / 0.1, 0, 1))
		end, function()
			-- bitten into the ground: hold, then dissolve
			BladeSkill.drive(BladeSkill.num(phantom, "Hold", 0.25) + BladeSkill.num(phantom, "Fade", 0.5), function(s)
				local hold = BladeSkill.num(phantom, "Hold", 0.25)
				local f = math.clamp((s - hold) / BladeSkill.num(phantom, "Fade", 0.5), 0, 1)
				for _, piece in pieces do
					local base = if piece.kind == "Aura" then 1 - (1 - t0) * 0.7 else t0
					piece.part.Transparency = base + (1 - base) * f * f
				end
			end, function()
				for _, piece in pieces do
					piece.part:Destroy()
				end
			end)
		end)
	end

	-- the slam
	seq:at(slamAt, function()
		local c0 = centreNow()
		onSwing(#hits, c0, function(tipAt, swing)
		local centre, feet, look = centreNow()
		copy:PivotTo(CFrame.lookAt(feet, feet + look))
		if slam then
			slam.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0.2, 0), centre + Vector3.new(0, 0.2, 0) + look)
		end
		-- where the blade bites: the ground under its point at contact (the clip
		-- drives it ~9 studs ahead of the root), kept inside the circle
		local bite = feet + look * math.min(offset * 0.7, 3)
		if blade and blade.real then
			local rel = Vector3.new(tipAt.X - feet.X, 0, tipAt.Z - feet.Z)
			local along = math.clamp(rel:Dot(look), 1.5, offset + radius * 0.6)
			local side = math.clamp(rel:Dot(look:Cross(Vector3.yAxis)), -2, 2)
			bite = CastFX.groundAt(feet + look * along + look:Cross(Vector3.yAxis) * side + Vector3.new(0, 2, 0))
		end
		local strike = copy:FindFirstChild("Strike") :: BasePart?
		if strike then
			strike.CFrame = CFrame.lookAt(bite + Vector3.new(0, 0.4, 0), bite + Vector3.new(0, 0.4, 0) + look)
			TechniqueVFX.emit(strike)
		end
		if slam then
			TechniqueVFX.emit(slam)
			local light = slam:FindFirstChild("Light") :: PointLight?
			if light then
				BladeSkill.drive(0.6, function(s)
					light.Brightness = 4 * (1 - s / 0.6) ^ 2
				end)
			end
		end
		local dome = copy:FindFirstChild("Dome")
		if dome and TechniqueVFX.full then
			dome:PivotTo(CFrame.lookAt(centre, centre + look))
			TechniqueVFX.emit(dome)
		end
		-- the rend: the blade splits the ground from the bite on through the circle
		local far = CastFX.groundAt(bite + look * math.max(radius * 0.85, 4) + Vector3.new(0, 2, 0))
		BladeSkill.rend(rend, rendKicks, bite - look * 0.4, far, BladeSkill.num(copy, "RendOpen", 0.18))
		WeaponFX.flare(flare, Vector3.new(tipAt.X, math.max(tipAt.Y, bite.Y + 0.6), tipAt.Z), swing, 1.5) -- the point sinks into the ground
		BladeSkill.shake(CombatEffects, tier, centre, 1.4)
		-- the hit-pause of the slam (II+), hardest at mastery
		if tier >= 2 then
			CombatEffects.punch(bite, ({ 0, 0.45, 0.7, 1 })[tier], Color3.fromRGB(128, 156, 255), WeaponFX.hitWindow(def, #hits))
		end
		-- heavy impacts as the torus front reaches each enemy, squeezed into Hit 3 -> Hit Stop 3
		local wave = slam and slam:FindFirstChild("GroundWave")
		local duration = if wave then BladeSkill.num(wave, "Duration", 0.5) else 0.5
		local window = WeaponFX.hitWindow(def, #hits)
		for _, target in BladeSkill.circleTargets(centre, radius, character, 6) do
			task.delay(WeaponFX.landing(BladeSkill.quartTime(duration, target.progress), duration, window), function()
				if impact then
					CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
				end
				if target.model.Parent then
					CombatEffects.flash(target.model)
				end
			end)
		end
		TechniqueVFX.cleanup(copy, 0.5)
		end)
	end, { name = "Hit", value = tostring(#hits) })

	seq:start(function()
		-- after the slam (or a cancelled cast): let the trails finish, then tidy up.
		-- Read the cut now: the clock extrapolates past the slam once stopped,
		-- so a later check never saw the cancel and left the copy behind
		local cut = clock.stopped() and clock.now() < slamAt
		BladeSkill.release(blade, 0.6)
		task.delay(3, function()
			for _, p in { flare, lightImpact, impact, launch, mark, rift, phantom, rend, rendKicks } do
				if p then
					p:Destroy()
				end
			end
			if copy.Parent and cut then
				copy:Destroy() -- cancelled before the slam
			end
		end)
	end)
	return true
end

return { cast = cast }
