--!nocheck
-- Rig assembler for the quadruped roster, adapted from spirit_wolf/rig_wolf.luau so one
-- function rigs any body from a spec. Each model has its own rig_<name>.luau holding the
-- spec (joints, HRP) that calls this. Re-runnable: strips any earlier rig first.
--
-- spec = {
--   folder = "_RosterQuadrupeds", target = "StoneBoar_R",
--   hrpSize = Vector3, hrpPos = Vector3 (EnemyService reads rootHeight from its Y),
--   joints = { { Motor6D, Part0, Part1, pivot }, ... } (first is JointRoot from the HRP),
--   barClearance = studs from the body's top to the HealthBar (default 1),
-- }
-- The body is built at the origin (no offset). Every joint frame has identity rotation in
-- model space at its pivot, so rotation about X is pitch on every joint. HipHeight is the
-- HRP's bottom above the ground.

return function(spec)
	local ServerStorage = game:GetService("ServerStorage")
	local model = ServerStorage[spec.folder]:FindFirstChild(spec.target)
	assert(model, "no ServerStorage." .. spec.folder .. "." .. spec.target)

	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	local oldRoot = model:FindFirstChild("HumanoidRootPart")
	if oldRoot then
		oldRoot:Destroy()
	end

	local segments = {}
	for _, j in spec.joints do
		local name = j[3]
		local found = {}
		for _, c in model:GetChildren() do
			if c.Name == name and c:IsA("BasePart") then
				table.insert(found, c)
			end
		end
		assert(#found == 1, ("%s: expected one part named %s, found %d"):format(spec.target, name, #found))
		segments[name] = found[1]
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
	hrp.Size = spec.hrpSize
	hrp.CFrame = CFrame.new(spec.hrpPos)
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.TopSurface = Enum.SurfaceType.Smooth
	hrp.BottomSurface = Enum.SurfaceType.Smooth
	hrp.Parent = model
	-- the bar sits barClearance over the body's top (the tallest crest, crag or tail tip),
	-- measured from the HRP, so it never hides inside the silhouette
	local bodyTop = -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= hrp then
			local cf, s = d.CFrame, d.Size / 2
			bodyTop = math.max(bodyTop, cf.Y + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X
				+ math.abs(cf.LookVector.Y) * s.Z)
		end
	end
	local bar = ServerStorage.Enemies.SpiritWolf.HumanoidRootPart.HealthBar:Clone()
	bar.StudsOffset = Vector3.new(0, bodyTop - spec.hrpPos.Y + (spec.barClearance or 1.0), 0)
	bar.Parent = hrp
	segments.HumanoidRootPart = hrp

	local welds = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not segments[d.Name] then
			local seg = d:GetAttribute("Segment")
			assert(seg and segments[seg], ("%s: %s has no valid Segment attribute"):format(spec.target, d:GetFullName()))
			local w = Instance.new("WeldConstraint")
			w.Name = d.Name
			w.Part0 = segments[seg]
			w.Part1 = d
			w.Parent = segments[seg]
			welds += 1
		end
	end

	for _, j in spec.joints do
		local p0, p1 = segments[j[2]], segments[j[3]]
		assert(p0, spec.target .. ": no Part0 " .. j[2])
		local pivot = CFrame.new(j[4])
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = p0.CFrame:Inverse() * pivot
		m.C1 = p1.CFrame:Inverse() * pivot
		m.Parent = p0
	end

	-- every motor is named after the part it moves (Joint<Part1>), except the legacy names
	-- EnemyAnimator drives: JointRoot (the body root) and JointLeg* (the upper legs)
	for _, j in spec.joints do
		local legacy = j[1] == "JointRoot" or (j[1]:match("^JointLeg[FB][LR]$") and j[3]:match("^UpperLeg"))
		assert(legacy or j[1] == "Joint" .. j[3], ("%s: joint %s should be named Joint%s"):format(spec.target, j[1], j[3]))
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = spec.hrpPos.Y - spec.hrpSize.Y / 2
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	Instance.new("Animator").Parent = hum -- Moon Animator / the Animation Editor play through it
	model.PrimaryPart = hrp
	model.WorldPivot = CFrame.new(spec.hrpPos) -- identity rotation: never spawns on its side
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local parts, tells = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d:GetAttribute("Tell") then
				tells += 1
			end
		end
	end
	return ("%s rigged: %d parts (%d tells), %d joints, %d welds, hip %.2f, bar +%.2f"):format(
		spec.target, parts, tells, #spec.joints, welds, hum.HipHeight, bar.StudsOffset.Y)
end
