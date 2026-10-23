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
-- three claw strokes in the air; the wheel draws the blade's circle behind its
-- tip; the landing is the one peak: the spec's hero at the bite, three claw
-- rends torn into the ground and a ragged shock out to the circle.

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local BladeSkill = require(script.Parent.BladeSkill)
local WeaponFX = require(script.Parent.WeaponFX)
local Sfx = require(Client.Sfx)

local SFX = "Techniques/RampagingTiger/"

local HITS = { 0.4833, 1.0333, 1.3167, 1.7833 } -- until def.hits exists
local LEAP = 0.95
local SPEED = 1.0
local SWINGS = { { 0.46, 0.72 }, { 1.0, 1.96 } } -- the cut; the wheel and the landing cleave
local WHEEL = { 1.0, 1.78 }

-- a copy of the claw scaled by k (attachment positions, beam widths, curves)
-- each cut's claw roll about the look axis (degrees) and place (caster space):
-- the first cut runs high-left to low-right, the spin hits stand upright
local function clawPose(index: number, count: number): (number, Vector3)
	if index == 1 then
		return -35, Vector3.new(0, 0.7, -2.6)
	end
	return 0, Vector3.new(0.9, 0.9, -2.4)
end

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
	local flare = TechniqueVFX.take(copy, "Flare")
	local launch = TechniqueVFX.take(copy, "Launch")
	local wheel = TechniqueVFX.take(copy, "Wheel")
	local gouge = TechniqueVFX.take(copy, "Gouge")
	local gougeKicks = TechniqueVFX.take(copy, "GougeKicks")
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

	local function soundAt(name: string, at: Vector3?, gap: number?)
		Sfx.play(SFX .. name, at or (BladeSkill.facing(character, origin, dir)), gap)
	end

	-- the claw strokes of a cut, in world space: the strokes run along the
	-- caster's look (slashing forward into the circle) in a plane standing on
	-- that line, rolled about it by the cut (Hit 1 the diagonal, the spin hits
	-- upright); they bow down at the ends, an arc over the top
	local function clawFrame(index: number, pos: Vector3, look: Vector3): CFrame
		local roll, at = clawPose(index, #hits)
		local base = CFrame.lookAt(pos, pos + look)
		local up = (CFrame.fromAxisAngle(look, math.rad(roll)) :: CFrame):VectorToWorldSpace(Vector3.yAxis)
		return CFrame.fromMatrix(base * at, look, -up)
	end

	local function here(): (Vector3, Vector3, Vector3)
		local pos, look = BladeSkill.facing(character, origin, dir)
		return pos, CastFX.groundAt(pos), look
	end

	-- each Hit marker fires as a swing starts (the dadao still raised: the
	-- first cut's marker has the point behind the head); the claw, the flare
	-- and the impacts land where the blade cuts, at the swing's peak inside
	-- that hit's Hit -> Hit Stop window (WeaponFX.swing)
	local function onSwing(index: number, fn: (Vector3, Vector3, Vector3) -> ())
		local pos = here()
		WeaponFX.swing(character, WeaponFX.hitWindow(def, index), fn, pos + Vector3.new(0, 2, 0))
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
			soundAt(if i == 1 then "Cut" else "SpinCut")
			onSwing(i, function(tipAt)
				local pos, feet, look = here()
				local cf = clawFrame(i, pos, look)
				flashClaw(claw, cf, 1)
				-- the tip flare lies in the claws' plane (its sprites are flat)
				WeaponFX.flare(flare, tipAt, cf.ZVector, 1)
				if impact then
					for _, target in BladeSkill.circleTargets(feet, radius, character, 4) do
						CastFX.impactAt(impact, target, { Kick = 0, Quake = 0 })
						soundAt("Hit", target.point, 0.05)
						if target.model.Parent then
							CombatEffects.flash(target.model)
						end
					end
				end
			end)
		end, { name = "Hit", value = tostring(i) })
	end

	seq:at(LEAP, function()
		local _, feet, look = here()
		soundAt("Leap", feet)
		if launch then
			TechniqueVFX.burstAt(launch, CFrame.lookAt(feet, feet + look))
		end
	end, { name = "Leap" })

	-- the wheel the spinning blade cuts, stood in its circle at the right side:
	-- each Wheel* emitter fires once per `Step` degrees the tip turns, rolled to
	-- the tip's angle in the wheel plane, so the circle draws itself behind it
	if wheel and character then
		local holder = wheel:Clone()
		holder.Parent = TechniqueVFX.folder
		local reach = 4.5
		if blade then
			local _, _, len = BladeSkill.axis(blade)
			reach = math.clamp(len + 1.2, 3.5, 5.5)
		end
		local marks: { ParticleEmitter } = {}
		for _, e in holder:GetChildren() do
			if e:IsA("ParticleEmitter") and e.Name:sub(1, 5) == "Wheel" then
				-- authored at radius 1: scale to the blade's reach
				local kps = {}
				for _, kp in e.Size.Keypoints do
					table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * reach, kp.Envelope * reach))
				end
				e.Size = NumberSequence.new(kps)
				table.insert(marks, e)
			end
		end
		local step = BladeSkill.num(wheel, "Step", 45)
		local rollSign = BladeSkill.num(wheel, "RollSign", -1)
		local rollOffset = BladeSkill.num(wheel, "RollOffset", 0)
		local last: number? = nil
		local stopWhirl: (() -> ())? = nil
		seq:span(WHEEL[1], WHEEL[2], function(_, t)
			if not stopWhirl then
				stopWhirl = Sfx.play(SFX .. "Whirl", holder) or function() end
			end
			local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			local pos, _, look = here()
			local right = look:Cross(Vector3.yAxis)
			local centre = if torso and torso:IsA("BasePart") then torso.Position + right * 1.4 + Vector3.new(0, 0.6, 0) else pos + right * 1.4 + Vector3.new(0, 1, 0)
			-- local X = look, Y = right (the wheel's axis), so the emitters lie in the wheel plane
			holder.CFrame = CFrame.fromMatrix(centre, look, right)
			-- the tip's angle in the wheel plane, 0 = straight down, toward look positive
			local angle
			if blade then
				local rel = blade.tip.WorldPosition - centre
				angle = math.deg(math.atan2(rel:Dot(look), -rel.Y))
			else
				angle = 381 * (t - WHEEL[1]) / (WHEEL[2] - WHEEL[1])
			end
			if last == nil then
				last = angle - step -- the first frame marks too
			end
			local turned = math.abs(((angle - (last :: number)) + 180) % 360 - 180)
			if turned >= step then
				last = angle
				for _, e in marks do
					e.Rotation = NumberRange.new(rollSign * angle + rollOffset)
					e:Emit(1)
				end
			end
			for _, e in holder:GetChildren() do
				if e:IsA("ParticleEmitter") and e.Rate > 0 then
					e.Enabled = true
				end
			end
		end, function()
			if stopWhirl then
				stopWhirl()
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
		onSwing(#hits, function(tipAt, swing, axis)
		local pos, feet, look = here()
		copy:PivotTo(CFrame.lookAt(feet, feet + look))
		-- the bite: under the point as the cleave lands (it drives down in front
		-- and on past the right foot), kept in front of the feet
		local bite = feet + look * 2.6
		if blade and blade.real then
			local rel = Vector3.new(tipAt.X - feet.X, 0, tipAt.Z - feet.Z)
			local along = math.clamp(rel:Dot(look), 1.5, 4)
			local side = math.clamp(rel:Dot(look:Cross(Vector3.yAxis)), -1.5, 1.5)
			bite = CastFX.groundAt(Vector3.new(feet.X, pos.Y, feet.Z) + look * along + look:Cross(Vector3.yAxis) * side)
		end
		soundAt("Bite", bite)
		soundAt("Slam", bite)
		if tier >= 3 then
			soundAt("Rumble", bite)
		end
		if tier >= 2 then
			CombatEffects.punch(bite, ({ 0, 0.4, 0.6, 0.85 })[tier], Color3.fromRGB(255, 150, 90), WeaponFX.hitWindow(def, #hits))
		end
		local strike = copy:FindFirstChild("Strike") :: BasePart?
		if strike then
			strike.CFrame = CFrame.lookAt(bite + Vector3.new(0, 0.4, 0), bite + Vector3.new(0, 0.4, 0) + look)
			TechniqueVFX.emit(strike)
		end
		-- the hero, in world space along the cut: its plane's normal is the
		-- swing x the blade (kept level-ish and to the right), and every emitter
		-- is rolled by the swing's angle in that plane (0 = straight down)
		local cleave = copy:FindFirstChild("Cleave") :: BasePart?
		if cleave then
			local right = look:Cross(Vector3.yAxis)
			local n = swing:Cross(axis)
			if n.Magnitude < 0.2 or math.abs(n.Unit.Y) > 0.7 then
				n = right
			end
			n = n.Unit
			if n:Dot(right) < 0 then
				n = -n
			end
			local up = (Vector3.yAxis - n * n.Y).Unit
			cleave.CFrame = CFrame.fromMatrix(bite + Vector3.new(0, 0.4, 0), n, up)
			local fwd = up:Cross(n) * -1 -- in-plane "ahead" (look side)
			if fwd:Dot(look) < 0 then
				fwd = -fwd
			end
			local roll = math.clamp(math.deg(math.atan2(swing:Dot(fwd), -swing:Dot(up))), -35, 35)
			for _, e in cleave:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					local base = e:GetAttribute("BaseRotation")
					if type(base) ~= "number" then
						base = e.Rotation.Min
						e:SetAttribute("BaseRotation", base)
					end
					e.Rotation = NumberRange.new((base :: number) - roll)
				end
			end
			TechniqueVFX.emit(cleave)
		end
		-- the tip flare, flat in the cut's plane
		local right = look:Cross(Vector3.yAxis)
		local normal = if cleave then cleave.CFrame.RightVector else right
		WeaponFX.flare(flare, Vector3.new(tipAt.X, math.max(tipAt.Y, bite.Y + 0.6), tipAt.Z), normal, 1.5)
		if slam then
			TechniqueVFX.emit(slam)
			local light = slam:FindFirstChild("Light") :: PointLight?
			if light then
				BladeSkill.drive(0.5, function(s)
					light.Brightness = 2.5 * (1 - s / 0.5) ^ 2
				end)
			end
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
				-- a claw rend each; the middle one kicks the dust and chips
				BladeSkill.rend(gouge, if i == 0 then gougeKicks else nil, a, b, 0.14 + math.abs(i) * 0.03)
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
		-- heavy impacts as the torus front reaches each, squeezed into Hit 4 -> Hit Stop 4
		local window = WeaponFX.hitWindow(def, #hits)
		for _, target in BladeSkill.circleTargets(feet, radius, character, 6) do
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
		-- read the cut now (a stopped clock extrapolates past the landing later)
		local cut = clock.stopped() and clock.now() < landAt
		BladeSkill.release(blade, 0.6)
		task.delay(3, function()
			for _, p in { claw, impact, flare, launch, wheel, gouge, gougeKicks } do
				if p then
					p:Destroy()
				end
			end
			if copy.Parent and cut then
				copy:Destroy()
			end
		end)
	end)
	return true
end

return { cast = cast }
