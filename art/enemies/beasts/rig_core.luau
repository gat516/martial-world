--!nocheck
-- The roster beasts' rig assembler, adapted from spirit_wolf/rig_wolf.luau (that file is
-- the wolf's and stays as it is). Each beast's rig_<beast>.luau loads this and calls it
-- with its numbers; the joints come from the body itself: lib.luau's finish() writes
-- Joint / JointParent / JointPivot attributes onto each segment part.
--
-- The rig contract (docs/systems/enemies.md, rig_wolf.luau):
--   * an invisible HumanoidRootPart with identity rotation at the spawn height
--     (EnemyService reads rootHeight from its Y), PrimaryPart, carrying the HealthBar;
--   * a Humanoid, R15, HipHeight = HRP bottom above the ground, no display name;
--   * a Motor6D tree rooted at the HRP, every joint frame at identity rotation in model
--     space at the real pivot, so rotation about X is pitch on every joint;
--   * details welded to their segment with WeldConstraints; every part but the HRP
--     non-colliding, non-touching, non-querying and massless; ModelStreamingMode Atomic.
-- Bodies are built at the model-space origin, so there's no offset to recover.

return function(cfg)
	local ServerStorage = game:GetService("ServerStorage")
	local model = ServerStorage._RosterBeasts:FindFirstChild(cfg.target)
	assert(model, "no ServerStorage._RosterBeasts." .. cfg.target)

	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local oldRoot = model:FindFirstChild("HumanoidRootPart")
	if oldRoot then
		oldRoot:Destroy()
	end

	local segments, joints = {}, {}
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") and not c:GetAttribute("Segment") then
			assert(not segments[c.Name], cfg.target .. ": two segment parts named " .. c.Name)
			segments[c.Name] = c
			if c:GetAttribute("Joint") then
				table.insert(joints, { c:GetAttribute("Joint"), c:GetAttribute("JointParent"), c.Name, c:GetAttribute("JointPivot") })
			end
		end
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = true
		end
	end

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = cfg.hrpSize
	hrp.CFrame = CFrame.new(cfg.hrpPos)
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.Anchored = true -- the template's only anchored part (EnemyService anchors its stand-in root anyway)
	hrp.TopSurface = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.Parent = model
	local bar = ServerStorage.Enemies.SpiritWolf.HumanoidRootPart.HealthBar:Clone()
	bar.StudsOffset = Vector3.new(0, cfg.barHeight - cfg.hrpPos.Y, 0)
	bar.Parent = hrp
	segments.HumanoidRootPart = hrp

	local welds = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Segment") then
			local seg = segments[d:GetAttribute("Segment")]
			assert(seg, ("%s: %s has no valid Segment"):format(cfg.target, d.Name))
			local w = Instance.new("WeldConstraint")
			w.Name = d.Name
			w.Part0 = seg
			w.Part1 = d
			w.Parent = seg
			welds += 1
		end
	end

	local names = {}
	for _, j in joints do
		local p0, p1 = segments[j[2]], segments[j[3]]
		assert(p0 and p1, ("%s: joint %s needs %s and %s"):format(cfg.target, j[1], j[2], j[3]))
		local pivot = CFrame.new(j[4])
		local m = Instance.new("Motor6D")
		-- Motor6Ds keep the Joint* names EnemyAnimator drives; cfg.nameByPart names each
		-- after the part it moves instead (keyframes address poses by part name either way)
		m.Name = if cfg.nameByPart then j[3] else j[1]
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = p0.CFrame:Inverse() * pivot
		m.C1 = p1.CFrame:Inverse() * pivot
		m.Parent = p0
		table.insert(names, j[1])
	end

	-- every segment must hang off the HRP
	local reached, changed = { HumanoidRootPart = true }, true
	while changed do
		changed = false
		for _, j in joints do
			if reached[j[2]] and not reached[j[3]] then
				reached[j[3]] = true
				changed = true
			end
		end
	end
	for name in segments do
		assert(reached[name], cfg.target .. ": segment " .. name .. " isn't on the motor tree")
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = cfg.hrpPos.Y - cfg.hrpSize.Y / 2
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	Instance.new("Animator").Parent = hum -- Moon Animator 2 and the Animation Editor play through it
	hum.Parent = model
	model.PrimaryPart = hrp
	model.WorldPivot = CFrame.new(cfg.hrpPos)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	table.sort(names)
	return ("%s rigged: %d parts, %d joints, %d welds, hip %.2f\n%s"):format(
		cfg.target, parts, #joints, welds, hum.HipHeight, table.concat(names, " "))
end
