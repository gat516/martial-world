--!strict
-- Rampaging Tiger Cleave (Saber) from its tier template
-- (ReplicatedStorage.Effects.RampagingTiger, built from
-- tools/vfx_specs/RampagingTiger.luau). Called by CombatEffects.cast for the
-- caster and observers; plays the whole move once per cast, synced to the
-- clip (BladeSkill.clock/sequence: the playing track and its markers).
--
-- Clip beats (markers on Skill_RampagingTiger): Hit 1 0.48 (diagonal cut),
-- Leap 0.95, Hit 2 1.03 and Hit 3 1.32 (the spinning blade wheel), Hit 4
-- 1.78 + Land 1.83 (the landing cleave), Hit Stop 4 1.90. Every cut leaves
-- three claw strokes in the air; the landing tears three claw gouges into the
-- ground and rolls a shockwave out to the circle around the caster.

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local BladeSkill = require(script.Parent.BladeSkill)

local HITS = { 0.4833, 1.0333, 1.3167, 1.7833 } -- until def.hits exists
local LEAP = 0.95
local SPEED = 1.0
local SWINGS = { { 0.46, 0.72 }, { 1.0, 1.96 } } -- the cut; the wheel and the landing cleave
local WHEEL = { 1.0, 1.78 }

-- the claw's turn (degrees about the facing axis) and place for each hit:
-- the first cut runs high-left to low-right, the rest fall vertically
local function clawPose(index: number, count: number): (number, Vector3)
	if index == 1 then
		return -35, Vector3.new(0, 0.7, -2.6)
	elseif index == count then
		return 90, Vector3.new(0.3, -0.2, -2.8)
	end
	return 90, Vector3.new(0.9, 0.9, -2.4)
end

-- a copy of the claw scaled by k (attachment positions, beam widths, curves)
local function scaledClaw(claw: BasePart, k: number): BasePart
	local copy = claw:Clone()
	if math.abs(k - 1) > 1e-3 then
		for _, d in copy:GetDescendants() do
			if d:IsA("Attachment") then
				d.Position *= k
			elseif d:IsA("Beam") then
				d.Width0 *= k
				d.Width1 *= k
				d.CurveSize0 *= k
				d.CurveSize1 *= k
			end
		end
	end
	return copy
end

local function flashClaw(claw: BasePart?, cf: CFrame, k: number)
	if not claw then
		return
	end
	local c = scaledClaw(claw, k)
	c.CFrame = cf
	c.Parent = TechniqueVFX.folder
	local beams = {}
	for _, d in c:GetDescendants() do
		if d:IsA("Beam") then
			table.insert(beams, d)
		end
	end
	BladeSkill.fadeBeams(beams, BladeSkill.num(claw, "Hold", 0.1), BladeSkill.num(claw, "Fade", 0.3), function()
		c:Destroy()
	end)
end

local function cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return false
	end
	dir = dir.Unit
	local hits = BladeSkill.hitTimes(def, HITS)
	local landAt = hits[#hits]
	local speed = if type(def.castSpeed) == "number" and def.castSpeed > 0 then def.castSpeed else SPEED
	local groundY = CastFX.groundBelow(origin)
	local ground = Vector3.new(origin.X, groundY, origin.Z)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	if not BladeSkill.claim(character, def.id, (landAt - hits[1]) / speed + 0.3) then
		copy:Destroy()
		return true
	end
	local radius = if type(def.radius) == "number" then def.radius else BladeSkill.num(copy, "AuthoredRadius", 10)
	local k = radius / BladeSkill.num(copy, "AuthoredRadius", 10)

	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy()
	end
	local edgeT = TechniqueVFX.take(copy, "Edge")
	local claw = TechniqueVFX.take(copy, "Claw")
	local impact = TechniqueVFX.take(copy, "Impact")
	local launch = TechniqueVFX.take(copy, "Launch")
	local wheel = TechniqueVFX.take(copy, "Wheel")
	local gouge = TechniqueVFX.take(copy, "Gouge")
	local gougeScar = TechniqueVFX.take(copy, "GougeScar")
	local slam = copy:FindFirstChild("Slam") :: BasePart?
	if slam then
		BladeSkill.fitRadius(slam, k)
	end
	CastFX.keepCratersOffEnemies()

	local clock = BladeSkill.clock(character, def, hits[1])
	local seq = BladeSkill.sequence(clock, landAt)
	local blade = BladeSkill.blade(character)
	local edge = if blade then BladeSkill.edge(edgeT, blade) else nil
	if edgeT then
		edgeT:Destroy()
	end

	local function here(): (Vector3, Vector3, Vector3)
		local pos, look = BladeSkill.facing(character, origin, dir)
		return pos, CastFX.groundAt(pos), look
	end

	if edge then
		for _, w in SWINGS do
			seq:span(w[1], w[2], function()
				BladeSkill.setTrails(edge, true)
			end, function()
				BladeSkill.setTrails(edge, false)
			end)
		end
		if tier >= 2 then
			seq:span(WHEEL[1], WHEEL[2], function()
				if edge.motes then
					edge.motes.Enabled = true
				end
			end, function()
				if edge.motes then
					edge.motes.Enabled = false
				end
			end)
		end
	end

	-- the cut and the spin hits: claw strokes in the air, impacts on the circle
	for i = 1, #hits - 1 do
		seq:at(hits[i], function()
			local pos, feet, look = here()
			local roll, at = clawPose(i, #hits)
			local cf = CFrame.lookAt(pos, pos + look) * CFrame.new(at) * CFrame.Angles(0, 0, math.rad(roll))
			flashClaw(claw, cf, 1)
			if impact then
				for _, target in BladeSkill.circleTargets(feet, radius, character, 4) do
					CastFX.impactAt(impact, target, { Kick = 0, Quake = 0 })
					if target.model.Parent then
						CombatEffects.flash(target.model)
					end
				end
			end
		end, { name = "Hit", value = tostring(i) })
	end

	seq:at(LEAP, function()
		if launch then
			local _, feet, look = here()
			TechniqueVFX.burstAt(launch, CFrame.lookAt(feet, feet + look))
		end
	end, { name = "Leap" })

	-- II+: the wheel the spinning blade cuts, stood in its circle at the right side
	if wheel and character then
		local spin = BladeSkill.num(wheel, "Spin", 900)
		local t0 = BladeSkill.num(wheel, "StartTransparency", 0.35)
		local rings: { { part: BasePart, dirn: number } } = {}
		for _, m in wheel:GetChildren() do
			local mesh = m:FindFirstChild("Mesh")
			if m:IsA("Model") and mesh and mesh:IsA("BasePart") then
				local p = mesh:Clone()
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Transparency = 1
				p.Parent = TechniqueVFX.folder
				table.insert(rings, { part = p, dirn = if m.Name == "Counter" then -0.7 else 1 })
			end
		end
		local holder = wheel:Clone()
		holder:ClearAllChildren()
		local embers = wheel:FindFirstChild("Embers")
		if embers then
			embers:Clone().Parent = holder
		end
		holder.Parent = TechniqueVFX.folder
		local reach = 4.5
		if blade then
			local _, _, len = BladeSkill.axis(blade)
			reach = math.clamp(len + 1.6, 3.5, 7)
		end
		local function fade(t: number): number
			local a = math.clamp((t - WHEEL[1]) / 0.08, 0, 1)
			local b = math.clamp((WHEEL[2] - t) / 0.15, 0, 1)
			return math.min(a, b)
		end
		seq:span(WHEEL[1], WHEEL[2], function(_, t)
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			local pos, _, look = here()
			local right = look:Cross(Vector3.yAxis)
			local centre = if torso and torso:IsA("BasePart") then torso.Position + right * 1.4 + Vector3.new(0, 0.6, 0) else pos + right * 1.4 + Vector3.new(0, 1, 0)
			-- ring meshes lie flat (axis Y): turn the axis to the side, then spin about it
			local frame = CFrame.fromMatrix(centre, look, right)
			for i, r in rings do
				local d = reach * 2 * (if i == 1 then 1 else 0.82)
				r.part.Size = Vector3.new(d, 0.9, d)
				r.part.CFrame = frame * CFrame.Angles(0, math.rad(spin * r.dirn * (t - WHEEL[1]) / speed), 0)
				r.part.Transparency = 1 - (1 - t0) * fade(t)
			end
			holder.CFrame = frame
			for _, e in holder:GetChildren() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = true
				end
			end
		end, function()
			for _, r in rings do
				r.part:Destroy()
			end
			for _, e in holder:GetChildren() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = false
				end
			end
			task.delay(0.8, function()
				holder:Destroy()
			end)
		end)
	end

	-- the landing cleave
	seq:at(landAt, function()
		local pos, feet, look = here()
		copy:PivotTo(CFrame.lookAt(feet, feet + look))
		local bite = feet + look * 2.6
		if blade and blade.real then
			local tip = blade.tip.WorldPosition
			local along = math.clamp((Vector3.new(tip.X, 0, tip.Z) - Vector3.new(feet.X, 0, feet.Z)):Dot(look), 1.5, 4)
			bite = CastFX.groundAt(Vector3.new(feet.X, pos.Y, feet.Z) + look * along)
		end
		local roll, at = clawPose(#hits, #hits)
		flashClaw(claw, CFrame.lookAt(pos, pos + look) * CFrame.new(at) * CFrame.Angles(0, 0, math.rad(roll)), 1)
		if tier >= 4 and claw then
			-- the giant claw standing over the strike
			local g = BladeSkill.num(claw, "GiantScale", 2.4)
			local top = bite + Vector3.new(0, 2.6 * g * 0.7, 0) + look * 1.5
			flashClaw(claw, CFrame.lookAt(top, top + look) * CFrame.Angles(0, 0, math.rad(90)), g)
		end
		local strike = copy:FindFirstChild("Strike") :: BasePart?
		if strike then
			strike.CFrame = CFrame.lookAt(bite + Vector3.new(0, 0.4, 0), bite + Vector3.new(0, 0.4, 0) + look)
			TechniqueVFX.emit(strike)
		end
		local roar = copy:FindFirstChild("Roar") :: BasePart?
		if roar then
			roar.CFrame = CFrame.lookAt(bite + Vector3.new(0, 1.4, 0), bite + Vector3.new(0, 1.4, 0) + look)
			TechniqueVFX.emit(roar)
		end
		if slam then
			TechniqueVFX.emit(slam)
			local light = slam:FindFirstChild("Light") :: PointLight?
			if light then
				BladeSkill.drive(0.5, function(s)
					light.Brightness = 3.5 * (1 - s / 0.5) ^ 2
				end)
			end
		end
		local shell = copy:FindFirstChild("Shell")
		if shell and TechniqueVFX.full then
			TechniqueVFX.emit(shell)
		end
		-- three claw gouges fanning forward from the bite
		if gouge then
			local length = BladeSkill.num(gouge, "Length", 6) * math.sqrt(k)
			local spread = BladeSkill.num(gouge, "Spread", 1)
			local right = look:Cross(Vector3.yAxis)
			for i = -1, 1 do
				local d = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(-i * 6)) :: CFrame):VectorToWorldSpace(look)
				local a = bite + right * (i * spread * 0.6) - look * 0.4
				local b = CastFX.groundAt(a + d * length * (1 - math.abs(i) * 0.15) + Vector3.new(0, 1, 0))
				BladeSkill.strip(gouge, a + Vector3.new(0, 0.03, 0), b + Vector3.new(0, 0.03, 0), 0.14)
				BladeSkill.strip(gougeScar, a + Vector3.new(0, 0.02, 0), b + Vector3.new(0, 0.02, 0), 0.14)
			end
			local path = copy:FindFirstChild("GougePath") :: BasePart?
			if path then
				path.Size = Vector3.new(path.Size.X, path.Size.Y, length)
				path.CFrame = CFrame.lookAt(bite + look * length / 2, bite + look * length) + Vector3.new(0, 0.2, 0)
				TechniqueVFX.emit(path)
			end
		end
		BladeSkill.shake(CombatEffects, tier, feet, 1.2)
		local wave = slam and slam:FindFirstChild("GroundWave")
		local duration = if wave then BladeSkill.num(wave, "Duration", 0.46) else 0.46
		for _, target in BladeSkill.circleTargets(feet, radius, character, 6) do
			task.delay(BladeSkill.quartTime(duration, target.progress), function()
				if impact then
					CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
				end
				if target.model.Parent then
					CombatEffects.flash(target.model)
				end
			end)
		end
		TechniqueVFX.cleanup(copy, 0.5)
	end, { name = "Hit", value = tostring(#hits) })

	seq:start(function()
		BladeSkill.release(blade, 0.6)
		task.delay(3, function()
			for _, p in { claw, impact, launch, wheel, gouge, gougeScar } do
				if p then
					p:Destroy()
				end
			end
			if copy.Parent and clock.stopped() and clock.now() < landAt then
				copy:Destroy()
			end
		end)
	end)
	return true
end

return { cast = cast }
