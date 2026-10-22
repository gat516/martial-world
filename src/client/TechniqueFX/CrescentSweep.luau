--!strict
-- Crescent Moon Sweep from its tier template (ReplicatedStorage.Effects.
-- CrescentSweep, built from tools/vfx_specs/CrescentSweep.luau). Called by
-- CombatEffects.cast at Hit, for the caster and observers alike.
--
-- The guandao whips round in one low spin from Hit to Hit Stop (~323 deg,
-- starting behind-left). The template's "Sweep" part is turned round the
-- caster on that heading curve, so its Trails lay a flat jade sheet with a
-- bright moon edge where the blade passes, closing into a disc that fades;
-- the ground torus and a knee-high swirl roll out to the radius. Each enemy
-- in the circle is struck when the blade's heading passes it (a target in the
-- small arc the spin skips, behind-left, at Hit Stop).

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local WeaponFX = require(script.Parent.WeaponFX)
local BladeSkill = require(script.Parent.BladeSkill)

local CLIP = { hit = 0.6333, hitStop = 0.75 } -- clip seconds (markers Hit / Hit Stop), until the def/ActionRules provide them

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function cast(CombatEffects: any, def: any, level: number, character: Model?, origin: Vector3, dir: Vector3): boolean
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return false
	end
	dir = dir.Unit
	local groundY = CastFX.groundBelow(origin)
	local ground = Vector3.new(origin.X, groundY, origin.Z)
	local facing = CFrame.lookAt(ground, ground + dir)
	local copy, tier = TechniqueVFX.spawn(def.id, level, facing)
	if not copy then
		return false
	end
	local radius = (def.radius or 11) :: number
	local scale = radius / num(copy, "AuthoredRadius", 11)
	TechniqueVFX.rescale(copy, scale)
	local timeline = WeaponFX.phases(def, CLIP)
	TechniqueVFX.fit(copy, "active", copy:GetAttribute("AuthoredActive") :: number?, timeline.active)

	local impact = TechniqueVFX.take(copy, "Impact")
	local sweep = TechniqueVFX.take(copy, "Sweep")
	local windup = TechniqueVFX.take(copy, "Windup")
	if windup then
		windup:Destroy() -- played at cast start (CombatEffects.windup)
	end
	local edgeT = TechniqueVFX.take(copy, "Edge")
	if not sweep then
		copy:Destroy()
		return false
	end
	-- the release where the blade is when the spin starts
	local tipAt = WeaponFX.tipPosition(character, def.hand or "Right")
	local tip = copy:FindFirstChild("Tip") :: BasePart?
	if tip and tipAt then
		tip.CFrame = CFrame.lookAt(tipAt, tipAt + dir)
	end
	-- the ground torus and swirls end at the gameplay radius
	for _, d in copy:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MeshWave") and (d.Name == "GroundWave" or d.Name == "KneeSwirl") then
			local to = d:GetAttribute("ToSize")
			if typeof(to) == "Vector3" then
				d:SetAttribute("ToSize", Vector3.new(to.X * scale, to.Y, to.Z * scale))
			end
		end
	end
	CastFX.keepCratersOffEnemies()
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy, 0.2)
	if not TechniqueVFX.full and CastFX.nearCamera(origin, 45) then
		CombatEffects.shake(CombatEffects.SHAKE_BY_TIER[tier] or 0.2)
	end

	-- the spin: heading (degrees from facing, + right) falls from StartHeading
	-- by SweepDegrees over the active window, then follows through
	local h0 = num(sweep, "StartHeading", -126)
	local degrees = num(sweep, "SweepDegrees", 323)
	local follow = num(sweep, "FollowDegrees", 30)
	local followTime = num(sweep, "FollowTime", 0.05)
	local reachScale = math.clamp(scale, 0.7, 1.4)
	local tilt = math.rad(num(sweep, "Tilt", 0))
	for _, d in sweep:GetChildren() do
		if d:IsA("Attachment") then
			d.Position = Vector3.new(d.Position.X, d.Position.Y, d.Position.Z * reachScale)
		end
	end
	local height = num(sweep, "Height", 1.5)
	local light = sweep:FindFirstChild("Light") :: PointLight?
	local active = timeline.active
	local function headingAt(t: number): number
		if t <= active then
			return h0 - degrees * (t / active)
		end
		local k = math.clamp((t - active) / followTime, 0, 1)
		return h0 - degrees - follow * (1 - (1 - k) ^ 2)
	end
	local function place(t: number)
		local h = headingAt(t)
		-- the sheet rises a little toward the front of the spin (the tip runs
		-- 0.6 -> 4.6 off the ground), sinking again round the back
		local lift = math.cos(math.rad(h)) * tilt
		sweep.CFrame = facing * CFrame.new(0, height, 0) * CFrame.Angles(0, math.rad(-h), 0) * CFrame.Angles(lift, 0, 0)
	end
	place(0)
	sweep.Parent = TechniqueVFX.folder
	task.wait() -- let the trails see a first position before they emit
	for _, d in sweep:GetDescendants() do
		if d:IsA("Trail") or (d:IsA("ParticleEmitter") and d:GetAttribute("Shed")) then
			(d :: any).Enabled = true
		end
	end
	if light then
		light.Brightness = 2.4
	end
	local total = active + followTime
	-- the real blade's own ribbon rides the guandao through the spin
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
	WeaponFX.drive(total, function(t)
		place(t)
		if light then
			light.Brightness = 2.4 * (1 - 0.5 * t / total)
		end
	end, function()
		if edge then
			BladeSkill.setTrails(edge, false)
			if edge.glow then
				edge.glow.Enabled = false
			end
			if edge.motes then
				edge.motes.Enabled = false
			end
			BladeSkill.release(blade, 0.9)
		end
		for _, d in sweep:GetDescendants() do
			if d:IsA("Trail") or d:IsA("ParticleEmitter") then
				(d :: any).Enabled = false
			end
		end
		if light then
			light.Brightness = 0
		end
		task.delay(0.6, function()
			sweep:Destroy()
		end)
	end)

	-- impacts as the blade's heading passes each target
	local targets = CastFX.targets({ kind = "circle", origin = origin, dir = dir, radius = radius, character = character })
	for _, target in targets do
		local rel = facing:PointToObjectSpace(target.point)
		local ht = math.deg(math.atan2(rel.X, -rel.Z))
		local delta = (h0 - ht) % 360
		local delay = if delta <= degrees then active * delta / degrees else active
		task.delay(delay, function()
			if impact then
				CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
			end
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
			if target.index == 1 and tier >= 4 and not TechniqueVFX.full and CastFX.nearCamera(target.point, 45) then
				CombatEffects.shake(0.25)
			end
		end)
	end
	if impact then
		task.delay(active + 1.5, function()
			impact:Destroy()
		end)
	end
	return true
end

return { cast = cast }
