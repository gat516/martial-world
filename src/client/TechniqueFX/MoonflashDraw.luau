--!strict
-- Moonflash Draw from its tier template (ReplicatedStorage.Effects.MoonflashDraw,
-- built from tools/vfx_specs/MoonflashDraw.luau). Called by CombatEffects.cast
-- at Hit, for the caster and observers alike.
--
-- An iaido dash-cut: the blade is drawn from the right hip and the caster
-- lunges along the line. At Hit a crescent-moon flash bursts on the hand; a
-- horizontal crescent of moonlight (part "Front") rides just ahead of the
-- caster's root along the path, dragging a wake band as wide as the hitbox,
-- with a streak Beam from the dash start and a glowing slit on the ground
-- behind it (II+ afterimages of the body are left along the way). Each enemy
-- on the line gets an impact as the front passes it. When the dash ends the
-- finish lands at the feet, and a beat later (II+) every target cut flashes
-- again ("the moon flashes after the sword is sheathed").
--
-- The front follows the caster's live root (so it stays on the body however
-- the lunge is driven) with a time floor that reaches the path's end by Hit
-- Stop plus a little, so it never stalls when the root doesn't move (relays
-- with a frozen pose, Edit previews).

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local WeaponFX = require(script.Parent.WeaponFX)
local BladeSkill = require(script.Parent.BladeSkill)

local SIDE = "Right" -- the drawing hand
local CLIP = { hit = 0.0667, hitStop = 0.2333 } -- clip seconds, used until the def/ActionRules provide them

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function setOn(inst: Instance, on: boolean)
	for _, d in inst:GetDescendants() do
		if d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = on
		elseif d:IsA("ParticleEmitter") and d:GetAttribute("Shed") then
			d.Enabled = on
		end
	end
end

-- Scale a crescent's attachments and beams in place (and fade it); `strip`
-- removes its trails, light and shed motes (echo crescents).
local function scale(copy: BasePart, k: number, fade: number, strip: boolean): BasePart
	for _, d in copy:GetDescendants() do
		if d:IsA("Attachment") then
			d.Position *= k
		elseif d:IsA("Beam") then
			d.Width0 *= k
			d.Width1 *= k
			d.CurveSize0 *= k
			d.CurveSize1 *= k
			local kps = {}
			for _, kp in d.Transparency.Keypoints do
				table.insert(kps, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * (1 - fade)))
			end
			d.Transparency = NumberSequence.new(kps)
		elseif strip and (d:IsA("PointLight") or d:IsA("Trail") or (d:IsA("ParticleEmitter") and d:GetAttribute("Shed"))) then
			d:Destroy()
		end
	end
	return copy
end

local function placeStrip(strip: BasePart, a: Vector3, b: Vector3, width: number)
	local length = math.max((b - a).Magnitude, 0.05)
	strip.Size = Vector3.new(width, strip.Size.Y, length)
	strip.CFrame = CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, strip.Size.Y / 2, 0)
end

-- Fade every Beam under `inst` out over `seconds`, then destroy it.
local function fadeBeams(inst: Instance, seconds: number)
	local beams: { { beam: Beam, base: NumberSequence } } = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("Beam") then
			table.insert(beams, { beam = d, base = d.Transparency })
		end
	end
	WeaponFX.drive(seconds, function(t)
		local k = math.clamp(t / seconds, 0, 1) ^ 2
		for _, b in beams do
			local kps = {}
			for _, kp in b.base.Keypoints do
				table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * k))
			end
			b.beam.Transparency = NumberSequence.new(kps)
		end
	end, function()
		inst:Destroy()
	end)
end

local function cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return false
	end
	dir = dir.Unit
	local groundY = CastFX.groundBelow(origin)
	local ground = Vector3.new(origin.X, groundY, origin.Z)
	local copy, tier = TechniqueVFX.spawn(def.id, level, CFrame.lookAt(ground, ground + dir))
	if not copy then
		return false
	end
	local timeline = WeaponFX.phases(def, CLIP)
	TechniqueVFX.fit(copy, "active", copy:GetAttribute("AuthoredActive") :: number?, timeline.active)
	local width = (def.width or 5) :: number
	local widthScale = width / num(copy, "AuthoredWidth", 5)

	local impact = TechniqueVFX.take(copy, "Impact")
	local sheathe = TechniqueVFX.take(copy, "Sheathe")
	local finish = TechniqueVFX.take(copy, "Finish")
	local front = TechniqueVFX.take(copy, "Front")
	local streak = TechniqueVFX.take(copy, "Streak")
	local cut = TechniqueVFX.take(copy, "Cut")
	local scar = TechniqueVFX.take(copy, "Scar")
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	local edgeT = TechniqueVFX.take(copy, "Edge")
	local glint = TechniqueVFX.take(copy, "SheatheGlint")
	if not front then
		copy:Destroy()
		return false
	end

	-- the draw on the live blade (the jian's Base -> Tip off the weapon model),
	-- 0.8 of the way to the point; the hand only when nothing is held
	local rig = WeaponFX.rig(character)
	local bladeAt = if rig and rig.real then rig:at(0.8) else nil
	WeaponFX.releaseRig(rig)
	local handAt = bladeAt or CastFX.handPosition(character, def.hand or SIDE) or (origin + dir * 1.2 + Vector3.new(0, 0.5, 0))
	local hand = copy:FindFirstChild("Hand") :: BasePart?
	if hand then
		hand.CFrame = CFrame.lookAt(handAt, handAt + dir)
	end

	-- the path: the dash (def.lunge) from the cast's start along the line; the
	-- hitbox (def.length) reaches the blade's length past it, which is how far
	-- the crescent rides ahead of the root. A wall cuts both short.
	local lineLength = (def.length or 18) :: number
	local length = (def.lunge or lineLength) :: number
	local lead = if def.lunge and def.length and def.length > def.lunge then def.length - def.lunge else num(front, "Lead", 1.6)
	local params = WeaponFX.worldParams(character)
	local wall = workspace:Raycast(ground + Vector3.new(0, 2.5, 0), dir * (length + lead), params)
	if wall then
		length = math.max(math.min(length, wall.Distance - 1), 1)
		lead = math.clamp(wall.Distance - 0.5 - length, 0.5, lead)
	end
	local height = num(front, "Height", 3.4)
	local function groundAt(along: number): Vector3
		local p = ground + dir * along
		return Vector3.new(p.X, CastFX.groundBelow(p + Vector3.new(0, 2, 0)), p.Z)
	end
	local endGround = groundAt(length)

	-- aftermath strips, stretched behind the front as it goes
	local strips: { { part: BasePart, width: number } } = {}
	local cutStart = ground + Vector3.new(0, 0.03, 0)
	for _, s in { cut, scar } do
		if s then
			s.Transparency = num(s, "StartTransparency", 0.3)
			s.CastShadow, s.CanCollide, s.CanQuery, s.CanTouch, s.Anchored = false, false, false, false, true
			s.Parent = TechniqueVFX.folder
			table.insert(strips, { part = s, width = s.Size.X * math.sqrt(widthScale) })
			placeStrip(s, cutStart, cutStart + dir * 0.05, s.Size.X)
		end
	end
	local path = copy:FindFirstChild("Path") :: BasePart?
	if path then
		local b = endGround
		path.Size = Vector3.new(width * 0.5, path.Size.Y, math.max(length, 1))
		path.CFrame = CFrame.lookAt((ground + b) / 2, b) + Vector3.new(0, 0.2, 0)
	end
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.emit(copy) -- the draw (flash, air rings, shake) and path aftermath
	TechniqueVFX.cleanup(copy, 0.2)
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * 0.5)
	end

	-- the crescent and its echoes
	local tilt = CFrame.Angles(math.rad(num(front, "Pitch", 0)), 0, math.rad(num(front, "Roll", 0)))
	if math.abs(widthScale - 1) > 1e-3 then
		scale(front, widthScale, 0, false)
	end
	local main = front :: BasePart
	local crescents: { { part: BasePart, lag: number } } = { { part = main, lag = 0 } }
	for i = 1, math.floor(num(main, "Echoes", 0)) do
		table.insert(crescents, { part = scale(main:Clone(), num(main, "EchoScale", 0.85) ^ i, 0.3 * i, true), lag = num(main, "EchoLag", 1.6) * i })
	end
	local light = main:FindFirstChild("Light") :: PointLight?
	local function frontCFrame(along: number): CFrame
		local g = groundAt(along)
		local at = Vector3.new(g.X, g.Y + height, g.Z)
		return CFrame.lookAt(at, at + dir) * tilt
	end
	for _, c in crescents do
		c.part.CFrame = frontCFrame(0)
		c.part.Parent = TechniqueVFX.folder
		setOn(c.part, true)
	end
	if light then
		light.Brightness = 2.2
	end
	-- the real edge: trails, glow and motes ride the blade through the dash
	local blade = BladeSkill.blade(character)
	local edge = if blade and edgeT then BladeSkill.edge(edgeT, blade) else nil
	if edge then
		BladeSkill.setTrails(edge, true)
		if edge.glow then
			edge.glow.Enabled = true
		end
		if edge.motes then
			edge.motes.Enabled = true
		end
	end
	local streakA0 = streak and streak:FindFirstChild("A0") :: Attachment?
	local streakA1 = streak and streak:FindFirstChild("A1") :: Attachment?
	if streak then
		streak.CFrame = CFrame.lookAt(ground, ground + dir)
		streak.Parent = TechniqueVFX.folder
		setOn(streak, true)
	end

	-- the hit list: each enemy on the line, in order along it
	local targets = CastFX.targets({ kind = "line", origin = origin, dir = dir, length = lineLength, width = width, character = character })
	local struck: { CastFX.Target } = {}
	local nextTarget = 1

	-- afterimages, spaced along the dash
	local ghosts = ({ 0, 1, 2, 3 })[tier] or 0
	local ghostsLeft = ghosts

	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local dashTime = timeline.active + 0.06
	local finished = false
	local reached = 0
	local function step(t: number)
		-- time floor (eases out) or the live root, whichever is further on
		local k = math.clamp(t / dashTime, 0, 1)
		local along = length * (1 - (1 - k) ^ 2)
		if root and root.Parent then
			local onLine = (root.Position - origin):Dot(dir)
			along = math.max(along, math.clamp(onLine, 0, length))
		end
		reached = math.max(reached, along)
		local frontAlong = math.min(reached + lead, length + lead)
		for _, c in crescents do
			c.part.CFrame = frontCFrame(math.max(frontAlong - c.lag, 0))
		end
		local g = groundAt(frontAlong)
		for _, s in strips do
			placeStrip(s.part, cutStart, Vector3.new(g.X, g.Y + 0.03, g.Z), s.width)
		end
		if streakA0 and streakA1 then
			streakA0.WorldPosition = ground + Vector3.new(0, height, 0)
			streakA1.WorldPosition = Vector3.new(g.X, g.Y + height, g.Z)
		end
		if light then
			light.Brightness = 2.2 * (1 - 0.5 * reached / length)
		end
		-- impacts as the front passes each target's near side
		while nextTarget <= #targets and frontAlong >= targets[nextTarget].progress * lineLength do
			local target = targets[nextTarget]
			nextTarget += 1
			table.insert(struck, target)
			if impact then
				CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
			end
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
			if target.index == 1 and tier >= 4 and not TechniqueVFX.full and CastFX.nearCamera(target.point, 45) then
				CombatEffects.shake(0.2)
			end
		end
		-- afterimages
		if ghostsLeft > 0 and k >= (ghosts - ghostsLeft + 1) / (ghosts + 1) then
			ghostsLeft -= 1
			WeaponFX.ghost(character, Color3.fromRGB(128, 146, 255), 0.5, 0.06, 0.38)
		end
	end
	local function done()
		if finished then
			return
		end
		finished = true
		-- any target the front never reached (behind a wall) still flashes
		while nextTarget <= #targets do
			local target = targets[nextTarget]
			nextTarget += 1
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
		end
		local endAt = if root and root.Parent then root.Position else endGround
		local feet = Vector3.new(endAt.X, CastFX.groundBelow(endAt), endAt.Z)
		WeaponFX.burst(finish, CFrame.lookAt(feet, feet + dir))
		if not TechniqueVFX.full and tier >= 3 and CastFX.nearCamera(feet, 45) then
			CombatEffects.shake(0.12)
		end
		if light then
			light.Brightness = 0
		end
		if edge then
			-- the ribbon lets go a beat after the dash, its tail fading by itself
			task.delay(0.12, function()
				BladeSkill.setTrails(edge, false)
				if edge.glow then
					edge.glow.Enabled = false
				end
				if edge.motes then
					edge.motes.Enabled = false
				end
			end)
			BladeSkill.release(blade, 0.9)
		end
		for _, c in crescents do
			setOn(c.part, false)
			task.delay(0.4, function()
				c.part:Destroy()
			end)
		end
		if streak then
			fadeBeams(streak, num(streak, "Fade", 0.35))
		end
		-- the sheathe: a beat later every target cut flashes again and the
		-- slit flares before it cools
		local delay = num(copy, "SheatheDelay", 0.12)
		task.delay(delay, function()
			-- the blade is put away: a flare on the real tip
			if glint then
				local r = WeaponFX.rig(character)
				local tipAt = if r then r.to.WorldPosition else endAt + dir * 2 + Vector3.new(0, 2, 0)
				WeaponFX.releaseRig(r)
				WeaponFX.burst(glint, CFrame.lookAt(tipAt, tipAt + dir))
			end
			if sheathe then
				for i, target in struck do
					local s = sheathe:Clone()
					if i > 1 then
						local frames = s:FindFirstChild("SheatheFrames")
						if frames then
							frames:Destroy()
						end
					end
					local cf = CFrame.lookAt(target.point, target.point + target.toward)
					WeaponFX.burst(s, cf, target.height)
					s:Destroy()
				end
				sheathe:Destroy()
			end
			for _, s in strips do
				local part = s.part
				if part.Material == Enum.Material.Neon and sheathe then
					part.Transparency = 0
				end
				local colorAttr = part:GetAttribute("FadeColor")
				local goal: { [string]: any } = { Transparency = 1 }
				if typeof(colorAttr) == "Color3" then
					goal.Color = colorAttr
				end
				WeaponFX.fadeOut(part, num(part, "Fade", 0.6), num(part, "FadeDelay", 0), goal)
			end
		end)
	end
	WeaponFX.drive(dashTime, function(t)
		step(t)
		if t >= dashTime then
			done()
		end
	end, done)
	task.delay(dashTime + 1.5, function()
		if impact then
			impact:Destroy()
		end
	end)
	return true
end

return { cast = cast }
