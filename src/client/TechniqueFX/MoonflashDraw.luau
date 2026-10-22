--!strict
-- Moonflash Draw from its tier template (ReplicatedStorage.Effects.MoonflashDraw,
-- built from tools/vfx_specs/MoonflashDraw.luau). Called by CombatEffects.cast
-- at Hit, for the caster and observers alike.
--
-- One quick-draw story, every piece with one anchor and one moment (rebuilt
-- 2026-10-21 after the user's playtest: "effects are like, very misaligned
-- and make no sense"). Clip (castSpeed 1): Hit 0.067 -> Hit Stop 0.233 is the
-- Lunge window, the caster dashes def.lunge (14) studs along the line. Sampled
-- on the jian: at Hit the blade is still sheathed behind the right hip (tip
-- behind-right), it is drawn flat round the right side (0.13), across the
-- front at chest height (0.15-0.21, point ~3.5 ahead) and out to the left
-- (0.233), then held low behind-left (zanshin) to the end of the clip.
--
--   Charge   cast start -> Hit, on the jian's Base -> Tip (`Charge`, played by
--            CombatEffects.windup through WeaponFX.charge).
--   Draw     at the draw's peak inside the Lunge window (WeaponFX.swing), on the
--            blade's point: the `Hand` part (a white-hot core, star, cross
--            glint, a flat crescent moon in the cut's plane, sparks, the shake)
--            follows the point every frame for its short life (`Ride`), its
--            riding emitters LockedToPart, so the 84 stud/s dash leaves nothing
--            behind.
--   Cut      Hit -> dash end + 0.12, on the jian's Base -> Tip (`Edge`: the moon
--            ribbon, the glow, motes): the real blade draws the crescent
--            through the dash.
--   Ghosts   II+: afterimages of the body, left where the body was along the
--            dash (1/2/3 by tier).
--   Line     Hit -> split, along the dash (`Streak`): a thin line of moonlight at
--            the cut's height from the dash start to the blade's reach ahead
--            of the live root, through every target on the line.
--   Hits     each target, as the blade's reach passes its near side (`Impact`:
--            the hit stack and a crescent cut through the body).
--   Split    a beat after the dash (`SheatheDelay`, ~Hit Stop + 0.12): the line
--            flares wide and white and fades (it "splits"), every target cut
--            flashes again (`Sheathe`, II+: a crossing crescent, a star, a ring;
--            IV impact frames), the live point glints as the blade settles
--            (`SheatheGlint`), and III+ the hit-pause punch.

local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local TechniqueVFX = require(Client.TechniqueVFX)
local CastFX = require(Client.CastFX)
local WeaponFX = require(script.Parent.WeaponFX)
local BladeSkill = require(script.Parent.BladeSkill)

local SIDE = "Right" -- the drawing hand
local CLIP = { hit = 0.0667, hitStop = 0.2333 } -- clip seconds, used until the def/ActionRules provide them
local MOON = Color3.fromRGB(165, 182, 255)

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function setBeams(inst: Instance, on: boolean)
	for _, d in inst:GetDescendants() do
		if d:IsA("Beam") then
			d.Enabled = on
		end
	end
end

-- The draw flash: a copy of `hand` that rides the blade's point for its `Ride`
-- seconds (its `Ride` emitters LockedToPart, so the flash travels with the cut).
local function drawFlash(hand: BasePart, character: Model?, at: Vector3, swing: Vector3, dir: Vector3)
	local flat = Vector3.new(swing.X, 0, swing.Z)
	local facing = if flat.Magnitude > 0.1 then flat.Unit else dir
	local f = hand:Clone()
	for _, d in f:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Ride") then
			d.LockedToPart = true
		end
	end
	f.CFrame = CFrame.lookAt(at, at + facing)
	f.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(f)
	local rig = WeaponFX.rig(character)
	if rig then
		-- every frame (a tween clock steps too coarsely at dash speed)
		local ride = num(hand, "Ride", 0.3)
		local started = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.Heartbeat:Connect(function()
			if os.clock() - started > ride or not (f.Parent and rig.to.Parent) then
				conn:Disconnect()
				WeaponFX.releaseRig(rig)
				return
			end
			local p = rig.to.WorldPosition
			f.CFrame = CFrame.lookAt(p, p + facing)
		end)
	end
	TechniqueVFX.cleanup(f)
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

	local hand = TechniqueVFX.take(copy, "Hand")
	local edgeT = TechniqueVFX.take(copy, "Edge")
	local streak = TechniqueVFX.take(copy, "Streak")
	local impact = TechniqueVFX.take(copy, "Impact")
	local sheathe = TechniqueVFX.take(copy, "Sheathe")
	local glint = TechniqueVFX.take(copy, "SheatheGlint")
	local splitDelay = num(copy, "SheatheDelay", 0.12)
	copy:Destroy() -- everything plays from its own anchor below
	if not (hand and streak) then
		for _, p in { hand, edgeT, streak, impact, sheathe, glint } do
			if p then
				p:Destroy()
			end
		end
		return false
	end
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- the dash (def.lunge) from the cast's start along the line; the hitbox
	-- (def.length) reaches the blade's length past it (`lead`). A wall cuts
	-- both short.
	local lineLength = (def.length or 18) :: number
	local length = (def.lunge or lineLength) :: number
	local lead = if def.lunge and def.length and def.length > def.lunge then def.length - def.lunge else 1.6
	local wall = workspace:Raycast(ground + Vector3.new(0, 2.5, 0), dir * (length + lead), WeaponFX.worldParams(character))
	if wall then
		length = math.max(math.min(length, wall.Distance - 1), 1)
		lead = math.clamp(wall.Distance - 0.5 - length, 0.5, lead)
	end
	local height = num(streak, "Height", 3.4)
	local dashTime = timeline.active + 0.06

	-- the cut: the real blade's ribbon, glow and motes through the dash
	local blade = BladeSkill.blade(character)
	local edge = if blade and edgeT then BladeSkill.edge(edgeT, blade) else nil
	if edgeT then
		edgeT:Destroy()
	end
	local function edgeOn(on: boolean)
		if not edge then
			return
		end
		BladeSkill.setTrails(edge, on)
		if edge.glow then
			edge.glow.Enabled = on
		end
		if edge.motes then
			edge.motes.Enabled = on
		end
	end
	edgeOn(true)

	-- the draw flash on the point where the draw is fastest
	local handAt = CastFX.handPosition(character, def.hand or SIDE) or (origin + Vector3.new(0, 3, 0))
	WeaponFX.swing(character, timeline.active, function(at, swing)
		drawFlash(hand, character, at, swing, dir)
		hand:Destroy()
	end, handAt)

	-- the line, from the dash start to the blade's reach ahead of the root
	if math.abs(widthScale - 1) > 1e-3 then
		for _, d in streak:GetDescendants() do
			if d:IsA("Beam") then
				d.Width0 *= widthScale
				d.Width1 *= widthScale
			end
		end
	end
	local a0 = streak:FindFirstChild("A0") :: Attachment?
	local a1 = streak:FindFirstChild("A1") :: Attachment?
	local lineStart = ground + Vector3.new(0, height, 0)
	streak.CFrame = CFrame.lookAt(ground, ground + dir)
	streak.Parent = TechniqueVFX.folder
	if a0 and a1 then
		a0.WorldPosition = lineStart
		a1.WorldPosition = lineStart + dir * 0.1
	end
	setBeams(streak, true)

	-- the hit list, in order along the line
	local targets = CastFX.targets({ kind = "line", origin = origin, dir = dir, length = lineLength, width = width, character = character })
	local struck: { CastFX.Target } = {}
	local nextTarget = 1
	local ghosts = ({ 0, 1, 2, 3 })[tier] or 0
	local ghostsLeft = ghosts
	local reached = 0
	local finished = false

	local function step(t: number)
		-- the live root along the line (with a time floor so it never stalls)
		local k = math.clamp(t / dashTime, 0, 1)
		local along = length * (1 - (1 - k) ^ 2)
		if root and root.Parent then
			along = math.max(along, math.clamp((root.Position - origin):Dot(dir), 0, length))
		end
		reached = math.max(reached, along)
		local reach = math.min(reached + lead, length + lead)
		if a1 then
			local g = ground + dir * reach
			a1.WorldPosition = Vector3.new(g.X, CastFX.groundBelow(g + Vector3.new(0, 2, 0)) + height, g.Z)
		end
		while nextTarget <= #targets and reach >= targets[nextTarget].progress * lineLength do
			local target = targets[nextTarget]
			nextTarget += 1
			table.insert(struck, target)
			if impact then
				CastFX.impactAt(impact, target, { Kick = 3, Quake = 1 })
			end
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
		end
		if ghostsLeft > 0 and k >= (ghosts - ghostsLeft + 1) / (ghosts + 1) then
			ghostsLeft -= 1
			WeaponFX.ghost(character, MOON, 0.5, 0.06, 0.38)
		end
	end

	local function split()
		-- the line flares wide and white, then fades: the cut "splits"
		local beams: { { beam: Beam, w0: number, w1: number, base: NumberSequence } } = {}
		for _, d in streak:GetDescendants() do
			if d:IsA("Beam") then
				table.insert(beams, { beam = d, w0 = d.Width0, w1 = d.Width1, base = d.Transparency })
			end
		end
		local flare, fade = 0.06, num(streak, "Fade", 0.35)
		local grow = num(streak, "Split", 2.2)
		WeaponFX.drive(flare + fade, function(t)
			local up = math.clamp(t / flare, 0, 1)
			local out = math.clamp((t - flare) / fade, 0, 1)
			local widen = 1 + grow * up * (1 - out * 0.5)
			for _, b in beams do
				b.beam.Width0, b.beam.Width1 = b.w0 * widen, b.w1 * widen
				local kps = {}
				for _, kp in b.base.Keypoints do
					local v = kp.Value * (1 - up * 0.8)
					table.insert(kps, NumberSequenceKeypoint.new(kp.Time, v + (1 - v) * out * out))
				end
				b.beam.Transparency = NumberSequence.new(kps)
			end
		end, function()
			streak:Destroy()
		end)
		-- every target cut flashes again
		if sheathe then
			for i, target in struck do
				local s = sheathe:Clone()
				if i > 1 then
					local frames = s:FindFirstChild("SheatheFrames")
					if frames then
						frames:Destroy()
					end
				end
				WeaponFX.burst(s, CFrame.lookAt(target.point, target.point + target.toward), target.height)
				s:Destroy()
			end
			sheathe:Destroy()
		end
		-- the point glints as the blade settles (zanshin)
		if glint then
			local r = WeaponFX.rig(character)
			local tipAt = if r then r.to.WorldPosition elseif root then root.Position + dir * 2 else lineStart
			WeaponFX.releaseRig(r)
			WeaponFX.burst(glint, CFrame.lookAt(tipAt, tipAt + dir))
			glint:Destroy()
		end
		if tier >= 3 and #struck > 0 then
			CombatEffects.punch(struck[1].point, if tier >= 4 then 0.75 else 0.45, MOON, 0.1)
		end
		if not TechniqueVFX.full and #struck > 0 and CastFX.nearCamera(struck[1].point, 45) then
			CombatEffects.shake((CombatEffects.SHAKE_BY_TIER[tier] or 0.2) * 0.6)
		end
	end

	local function done()
		if finished then
			return
		end
		finished = true
		-- a target the reach never got to (behind a wall) still flashes
		while nextTarget <= #targets do
			local target = targets[nextTarget]
			nextTarget += 1
			if target.model.Parent then
				CombatEffects.flash(target.model)
			end
		end
		-- the ribbon lets go a beat after the dash, its tail fading by itself
		task.delay(0.12, function()
			edgeOn(false)
		end)
		BladeSkill.release(blade, 0.9)
		task.delay(splitDelay, split)
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
