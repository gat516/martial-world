--!strict
-- Dragon-Piercing Thrust from its tier template (ReplicatedStorage.Effects.
-- DragonPierce, built from tools/vfx_specs/DragonPierce.luau). Called by
-- CombatEffects.cast at Hit, for the caster and observers alike.
--
-- The spear is driven round and forward from Hit to Hit Stop while the
-- caster lunges (the clip's Lunge start/end markers sit on Hit/Hit Stop). At
-- Hit a vortex and star burst at the spear point; a crimson drill of qi
-- (part "Lance", 3D spiral-cone MeshWaves stretched to the line) shoots from
-- the point to the line's end on the template's TravelCurve, with a gold core
-- Beam, a crimson glow Beam and a hot head shedding sparks. Swirl rings burst
-- across the line as the front passes their stations (II+ a dragon helix
-- coils round the lance). Each enemy on the line gets an impact and a spray
-- of sparks out of its far side when the front reaches it; the lance bursts
-- at the end of the line or at the first wall. A rend opens in the ground
-- under the lance as its front passes (BladeSkill.rend) and cools.
--
-- Alignment (sampled on the clip): at Hit the head is still out to the right
-- (5.7 right, level with the root) and swings onto the thrust by Hit Stop,
-- where the spear points straight ahead ~1.6 right of the root's line (the
-- right-handed grip) at ~3.1 off the ground. The lance runs down that line
-- (Lance attributes Lateral/Height), not the root's centre line; the flare
-- plays on the live head where the thrust peaks (WeaponFX.swing).

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local WeaponFX = require(script.Parent.WeaponFX)
local BladeSkill = require(script.Parent.BladeSkill)

local CLIP = { hit = 0.3, hitStop = 0.4 } -- clip seconds (markers Hit / Hit Stop), until the def/ActionRules provide them

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function setOn(inst: Instance, on: boolean)
	for _, d in inst:GetDescendants() do
		if d:IsA("Beam") then
			d.Enabled = on
		elseif d:IsA("ParticleEmitter") and d:GetAttribute("Shed") then
			d.Enabled = on
		end
	end
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
	local length = (def.length or 22) :: number
	local width = (def.width or 4) :: number

	local impact = TechniqueVFX.take(copy, "Impact")
	local terminal = TechniqueVFX.take(copy, "Terminal")
	local lance = TechniqueVFX.take(copy, "Lance")
	local rend = TechniqueVFX.take(copy, "Rend")
	local rendKicks = TechniqueVFX.take(copy, "RendKicks")
	local flare = TechniqueVFX.take(copy, "Flare")
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	if not lance then
		copy:Destroy()
		return false
	end

	-- the live spear point (the hand when there's no weapon)
	local tipAt = WeaponFX.tipPosition(character, def.hand or "Right") or (origin + dir * 2.5 + Vector3.new(0, 0.3, 0))

	-- the lance runs down the spear's thrust line (to the right of the root's
	-- line, at the head's height when the thrust lands) from just ahead of the
	-- caster to the line's end
	local right = dir:Cross(Vector3.yAxis)
	local lateral = math.clamp(num(lance, "Lateral", 1.6), -(width / 2 - 0.3), width / 2 - 0.3)
	local startAlong = math.clamp(num(lance, "StartAlong", 1.5), 1, math.min(6, length * 0.4))
	local height = math.clamp(num(lance, "Height", 3.1) + (tipAt.Y - groundY - 3.5) * 0.3, 2, 4.5)
	ground += right * lateral
	local start = ground + dir * startAlong + Vector3.new(0, height, 0)
	-- the flare on the live spear head where the thrust peaks (Hit -> Hit Stop)
	WeaponFX.swing(character, WeaponFX.hitWindow(def, 1), function(at, swing)
		WeaponFX.flare(flare, at, swing, 1)
		if flare then
			flare:Destroy()
		end
	end, start)
	-- the release bursts where the lance starts: at Hit the point is still out
	-- to the side and swings onto the line by Hit Stop
	local tip = copy:FindFirstChild("Tip") :: BasePart?
	if tip then
		tip.CFrame = CFrame.lookAt(start, start + dir)
	end
	local run = length - startAlong
	local stopNormal: Vector3? = nil
	local wall = workspace:Raycast(start, dir * run, WeaponFX.worldParams(character))
	local stopFrac = 1
	if wall then
		stopFrac = math.clamp(wall.Distance / run, 0.05, 1)
		stopNormal = wall.Normal
	end
	local reach = run * stopFrac
	local travelTime = num(lance, "TravelTime", 0.16)
	local curveAttr = lance:GetAttribute("TravelCurve")
	local curve: NumberSequence = if typeof(curveAttr) == "NumberSequence" then curveAttr else NumberSequence.new(0, 1)
	local stopTime = CastFX.curveTime(curve, travelTime, stopFrac)

	-- stretch the lance's meshes to the reach and station its rings
	local k = reach / num(lance, "Run", 19)
	for _, d in lance:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MeshWave") then
			if d:GetAttribute("Stretch") then
				local toSize = d:GetAttribute("ToSize")
				local toOffset = d:GetAttribute("ToOffset")
				if typeof(toSize) == "Vector3" then
					d:SetAttribute("ToSize", Vector3.new(toSize.X, toSize.Y * k, toSize.Z))
				end
				if typeof(toOffset) == "Vector3" then
					d:SetAttribute("ToOffset", Vector3.new(toOffset.X, toOffset.Y, toOffset.Z * k))
				end
			end
			local station = d:GetAttribute("Station")
			if type(station) == "number" then
				local z = -reach * station
				d:SetAttribute("FromOffset", Vector3.new(0, 0, z))
				d:SetAttribute("ToOffset", Vector3.new(0, 0, z - 1.2))
				d:SetAttribute("EmitDelay", CastFX.curveTime(curve, travelTime, station * stopFrac))
			end
		end
	end
	lance.CFrame = CFrame.lookAt(start, start + dir)
	local front = lance:FindFirstChild("Front") :: Attachment?
	local head = lance:FindFirstChild("Head") :: Attachment?
	local light = head and head:FindFirstChild("Light") :: PointLight?
	if front then
		front.Position = Vector3.new(0, 0, -0.3)
	end
	if head then
		head.Position = Vector3.new(0, 0, -0.3)
	end
	lance.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(lance) -- the drill, helix and stationed rings (MeshWaves)
	setOn(lance, true)
	if light then
		light.Brightness = 2.4
	end

	-- the rend the lance tears in the ground under it, opening with the front
	local endPoint = start + dir * reach
	local endGround = Vector3.new(endPoint.X, CastFX.groundBelow(endPoint), endPoint.Z)
	BladeSkill.rend(rend, rendKicks, ground + dir * startAlong, endGround, stopTime)
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.emit(copy) -- the release (vortex, flash, air rings, shake) and the path
	TechniqueVFX.cleanup(copy, 0.2)
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * 0.6)
	end

	local hold, fade = num(lance, "Hold", 0.16), num(lance, "Fade", 0.28)
	local finished = false
	local function burst()
		if finished then
			return
		end
		finished = true
		for _, d in lance:GetDescendants() do
			if d:IsA("ParticleEmitter") and d:GetAttribute("Shed") then
				d.Enabled = false
			end
		end
		if light then
			light.Brightness = 0
		end
		if terminal then
			local floor = Vector3.new(endPoint.X, CastFX.groundBelow(endPoint - dir * 0.4), endPoint.Z)
			if stopNormal and math.abs(stopNormal.Y) < 0.6 then
				floor -= dir * 0.4 -- on a wall: burst just in front of it
			end
			WeaponFX.burst(terminal, CFrame.lookAt(floor, floor + dir), math.max(endPoint.Y - floor.Y, 1))
			terminal:Destroy()
		end
		if not TechniqueVFX.full and tier >= 3 and CastFX.nearCamera(endPoint, 45) then
			CombatEffects.shake(0.2)
		end
		if tier >= 3 then
			CombatEffects.punch(endPoint, if tier >= 4 then 0.8 else 0.5, Color3.fromRGB(232, 66, 70), 0.08)
		end
	end
	-- the beams' fade after the hold
	local beams: { { beam: Beam, base: NumberSequence } } = {}
	for _, d in lance:GetDescendants() do
		if d:IsA("Beam") then
			table.insert(beams, { beam = d, base = d.Transparency })
		end
	end
	local total = stopTime + hold + fade
	WeaponFX.drive(total, function(t)
		local p = math.min(WeaponFX.sample(curve, math.min(t, stopTime) / travelTime), stopFrac)
		local z = -math.max(run * p, 0.3)
		if front then
			front.Position = Vector3.new(0, 0, z)
		end
		if head then
			head.Position = Vector3.new(0, 0, z)
		end
		if t >= stopTime then
			burst()
		end
		if t > stopTime + hold then
			local f = math.clamp((t - stopTime - hold) / fade, 0, 1) ^ 2
			for _, b in beams do
				local kps = {}
				for _, kp in b.base.Keypoints do
					table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * f))
				end
				b.beam.Transparency = NumberSequence.new(kps)
			end
		end
	end, function()
		burst()
		setOn(lance, false)
		task.delay(1, function()
			lance:Destroy()
		end)
	end)

	-- impacts: each enemy on the line as the front reaches its near side
	local targets = CastFX.targets({ kind = "line", origin = origin, dir = dir, length = length, width = width, character = character })
	for _, target in targets do
		local along = target.progress * length
		local frac = math.clamp((along - startAlong) / run, 0, 1)
		local beyond = frac > stopFrac
		local arrival = if beyond then stopTime else CastFX.curveTime(curve, travelTime, frac)
		-- squeezed into the thrust's Hit -> Hit Stop (the damage number shows at Hit)
		task.delay(WeaponFX.landing(arrival, travelTime, WeaponFX.hitWindow(def, 1)), function()
			if impact and not beyond then
				CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
			end
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
		end)
	end
	if impact then
		task.delay(travelTime + 1.5, function()
			impact:Destroy()
		end)
	end
	return true
end

return { cast = cast }
