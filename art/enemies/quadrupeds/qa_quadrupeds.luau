--!nocheck
-- QA for the quadruped roster (ServerStorage._RosterQuadrupeds). Run in Edit mode through
-- execute_luau over the local art server; set MODELS / POSES / KEEP with a gsub first, e.g.
--   src:gsub("local MODELS = nil", 'local MODELS = { "StoneBoar_R" }')
-- For each model it reports:
--   static   lowest/highest point, HRP (identity, PrimaryPart, spawn height), Humanoid and
--            Animator, HealthBar clearance, Atomic streaming, part flags (unanchored,
--            no collide/touch/query, Massless), materials (SmoothPlastic, Neon only on
--            Tell parts), scripts, joint frames identity in model space, motor names
--   posed    for each pose in poses_quadrupeds.luau: a PARENTED clone (in
--            Workspace._RosterPreviewQuadrupeds._QA) posed by forward kinematics; the
--            worst drift of a welded detail against its segment, joints whose two sides
--            stop touching (a gap), visible parts left touching nothing, the lowest point
--   keyable  the shared art/enemies/keyframe_test.luau on the template (every joint keyed
--            by its Part1 name and played through the Animator; flags dupe / untaken)
-- KEEP = true leaves the posed copies (anchored) in _QA for captures; otherwise they go.

local MODELS = nil -- nil: every model in the folder
local POSES_TO_RUN = { "WINDUP", "STRETCH", "CROUCH" }
local KEEP = false
local QA_AT = CFrame.new(200, 400, 3030) -- a row behind the preview plate

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local POSES = loadstring(HttpService:GetAsync("http://127.0.0.1:8767/quadrupeds/poses_quadrupeds.luau?" .. os.clock()))()
local folder = ServerStorage._RosterQuadrupeds
local TOL = 0.05

local function overlaps(a, b, tol)
	local ca, cb = a.CFrame, b.CFrame
	local ea, eb = a.Size / 2 + Vector3.one * tol, b.Size / 2
	local axA = { ca.RightVector, ca.UpVector, ca.LookVector }
	local axB = { cb.RightVector, cb.UpVector, cb.LookVector }
	local d = cb.Position - ca.Position
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, axA[i])
		table.insert(axes, axB[i])
		for j = 1, 3 do
			local c = axA[i]:Cross(axB[j])
			if c.Magnitude > 1e-4 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, n in axes do
		local ra = math.abs(axA[1]:Dot(n)) * ea.X + math.abs(axA[2]:Dot(n)) * ea.Y + math.abs(axA[3]:Dot(n)) * ea.Z
		local rb = math.abs(axB[1]:Dot(n)) * eb.X + math.abs(axB[2]:Dot(n)) * eb.Y + math.abs(axB[3]:Dot(n)) * eb.Z
		if math.abs(d:Dot(n)) > ra + rb then
			return false
		end
	end
	return true
end

local function extentY(p)
	local cf, s = p.CFrame, p.Size / 2
	local r = math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z
	if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
		r = s.X
	end
	return cf.Y - r, cf.Y + r
end

local function bounds(model, skip)
	local lo, hi = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= skip and d.Transparency < 1 then
			local a, b = extentY(d)
			lo, hi = math.min(lo, a), math.max(hi, b)
		end
	end
	return lo, hi
end

-- segment name -> its parts (the segment part plus everything welded to it)
local function groups(model)
	local g = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local seg = d:GetAttribute("Segment") or d.Name
			g[seg] = g[seg] or {}
			table.insert(g[seg], d)
		end
	end
	return g
end

local function static(m)
	local out = {}
	local hrp = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	local lo, hi = bounds(m, hrp)
	table.insert(out, ("bounds Y %.3f..%.3f"):format(lo, hi))
	if math.abs(lo) > 0.01 then
		table.insert(out, "FAIL lowest point not at Y=0")
	end
	if not hrp or m.PrimaryPart ~= hrp or not hrp.CFrame.Rotation:FuzzyEq(CFrame.identity, 1e-5) or hrp.Anchored then
		table.insert(out, "FAIL HRP (missing, not PrimaryPart, rotated or anchored)")
	end
	if not m:GetPivot().Rotation:FuzzyEq(CFrame.identity, 1e-5) then
		table.insert(out, "FAIL pivot rotated")
	end
	if not hum or not hum:FindFirstChildOfClass("Animator") then
		table.insert(out, "FAIL Humanoid/Animator missing")
	end
	if m.ModelStreamingMode ~= Enum.ModelStreamingMode.Atomic then
		table.insert(out, "FAIL not Atomic")
	end
	local bar = hrp and hrp:FindFirstChild("HealthBar")
	if not bar then
		table.insert(out, "FAIL no HealthBar")
	else
		local barY = hrp.Position.Y + bar.StudsOffset.Y
		table.insert(out, ("bar at Y %.2f (%.2f over the top)"):format(barY, barY - hi))
		if barY - hi < 0.3 or barY - hi > 2 then
			table.insert(out, "FAIL bar clearance")
		end
	end
	local parts, tells, neon, motors = 0, 0, 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(out, "FAIL script " .. d:GetFullName())
		elseif d:IsA("BasePart") then
			parts += 1
			if d ~= hrp then
				if d.Anchored or d.CanCollide or d.CanTouch or d.CanQuery or not d.Massless then
					table.insert(out, "FAIL flags " .. d.Name)
				end
				if d.Material == Enum.Material.Neon then
					neon += 1
					if not d:GetAttribute("Tell") then
						table.insert(out, "FAIL Neon without Tell " .. d.Name)
					end
				elseif d.Material ~= Enum.Material.SmoothPlastic then
					table.insert(out, "FAIL material " .. d.Name)
				end
				if d:GetAttribute("Tell") then
					tells += 1
				end
			end
		elseif d:IsA("Motor6D") then
			motors += 1
			if not (d.Part0.CFrame * d.C0).Rotation:FuzzyEq(CFrame.identity, 1e-4) then
				table.insert(out, "FAIL joint frame rotated " .. d.Name)
			end
			if not (d.Part0.CFrame * d.C0):FuzzyEq(d.Part1.CFrame * d.C1, 1e-3) then
				table.insert(out, "FAIL joint sides disagree at rest " .. d.Name)
			end
			if d.Parent ~= d.Part0 then
				table.insert(out, "FAIL joint not parented to Part0 " .. d.Name)
			end
		end
	end
	local rootJoints = 0
	for _, d in m:GetDescendants() do
		if d:IsA("JointInstance") and (d.Part0 == hrp or d.Part1 == hrp) then
			rootJoints += 1
		end
	end
	if rootJoints ~= 1 then
		table.insert(out, "FAIL joints off the HRP: " .. rootJoints)
	end
	for _, n in { "JointRoot", "JointHead", "JointTail", "JointLegFL", "JointLegFR", "JointLegBL", "JointLegBR" } do
		if not m:FindFirstChild(n, true) then
			table.insert(out, "FAIL missing " .. n)
		end
	end
	table.insert(out, ("%d parts, %d Neon (%d tells), %d motors"):format(parts, neon, tells, motors))
	return out
end

local function qaFolder()
	local preview = workspace:FindFirstChild("_RosterPreviewQuadrupeds")
	if not preview then
		preview = Instance.new("Folder")
		preview.Name = "_RosterPreviewQuadrupeds"
		preview:AddTag("EditorOnly")
		preview.Parent = workspace
	end
	local qa = preview:FindFirstChild("_QA")
	if not qa then
		qa = Instance.new("Folder")
		qa.Name = "_QA"
		qa.Parent = preview
	end
	return qa
end

local function place(template, name, cf)
	local copy = template:Clone()
	copy.Name = name
	copy:PivotTo(cf * CFrame.new(0, template.HumanoidRootPart.Position.Y, 0))
	copy.HumanoidRootPart.Anchored = true
	copy.Parent = qaFolder()
	return copy
end

local function rel(model)
	local segs, r = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:GetAttribute("Segment") then
			segs[d.Name] = d
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Segment") then
			r[d.Name] = segs[d:GetAttribute("Segment")].CFrame:ToObjectSpace(d.CFrame)
		end
	end
	return r
end

local function posedCheck(template, poseName, slot)
	local pose = POSES[poseName][template.Name] or {}
	local copy = place(template, template.Name .. "_" .. poseName, QA_AT * CFrame.new(-12 + slot * 10, 0, 0))
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") then
			table.insert(motors, m)
		end
	end
	local unused = {}
	for k in pose do
		unused[k] = true
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				unused[m.Name] = nil
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree doesn't reach the root")
	end
	local pairsJ = {}
	for _, m in motors do
		table.insert(pairsJ, { m.Name, m.Part0.Name, m.Part1.Name })
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
	local out = {}
	for k in unused do
		table.insert(out, "pose names a missing joint " .. k)
	end
	-- drift
	local r0, r1 = rel(template), rel(copy)
	local worst, worstName = 0, ""
	for name, cf in r0 do
		local d = (cf.Position - r1[name].Position).Magnitude + (cf.LookVector - r1[name].LookVector).Magnitude
			+ (cf.UpVector - r1[name].UpVector).Magnitude
		if d > worst then
			worst, worstName = d, name
		end
	end
	table.insert(out, ("drift %.5f (%s)"):format(worst, worstName))
	-- gaps across joints
	local g = groups(copy)
	for _, j in pairsJ do
		if j[2] ~= "HumanoidRootPart" then
			local touch = false
			for _, a in g[j[2]] do
				for _, b in g[j[3]] do
					if overlaps(a, b, TOL) then
						touch = true
						break
					end
				end
				if touch then
					break
				end
			end
			if not touch then
				table.insert(out, "GAP at " .. j[1] .. " (" .. j[2] .. " / " .. j[3] .. ")")
			end
		end
	end
	-- floating
	local visible = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(visible, d)
		end
	end
	for _, p in visible do
		local ok = false
		for _, q in visible do
			if q ~= p and overlaps(p, q, TOL) then
				ok = true
				break
			end
		end
		if not ok then
			table.insert(out, "floating " .. p.Name)
		end
	end
	local lo = bounds(copy, copy.HumanoidRootPart)
	table.insert(out, ("lowest %.2f"):format(lo - QA_AT.Y))
	-- segments sunk into the ground (a planted foot should sit at 0, never below)
	local sunk = {}
	for seg, ps in g do
		local segLo = math.huge
		for _, q in ps do
			if q.Transparency < 1 then
				segLo = math.min(segLo, (extentY(q)))
			end
		end
		if segLo - QA_AT.Y < -0.05 then
			table.insert(sunk, ("%s %.2f"):format(seg, segLo - QA_AT.Y))
		end
	end
	local feet = {}
	for seg, ps in g do
		if seg:match("^Hoof") or seg:match("^Foot[FB]") or seg:match("^Paw") then
			local segLo = math.huge
			for _, q in ps do
				segLo = math.min(segLo, (extentY(q)))
			end
			table.insert(feet, ("%s %.2f"):format(seg, segLo - QA_AT.Y))
		end
	end
	table.sort(feet)
	table.insert(out, "feet: " .. table.concat(feet, ", "))
	if #sunk > 0 then
		table.sort(sunk)
		table.insert(out, "sunk: " .. table.concat(sunk, ", "))
	end
	if KEEP then
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	else
		copy:Destroy()
	end
	return out
end

-- the shared keyframe proof (art/enemies/keyframe_test.luau): keys every Motor6D by its
-- Part1 name, plays the clip on a parented clone and checks each Transform took it
local function keyable(template)
	local src = HttpService:GetAsync("http://127.0.0.1:8767/keyframe_test.luau?" .. os.clock())
	src = src:gsub("local TARGETS = {}", 'local TARGETS = { "ServerStorage._RosterQuadrupeds.' .. template.Name .. '" }')
	return { "keyframe_test: " .. tostring(loadstring(src)()) }
end

local report = {}
local slot = 0
for _, m in folder:GetChildren() do
	if m:IsA("Model") and (not MODELS or table.find(MODELS, m.Name)) then
		table.insert(report, "== " .. m.Name)
		for _, l in static(m) do
			table.insert(report, "  " .. l)
		end
		for i, pn in POSES_TO_RUN do
			for _, l in posedCheck(m, pn, slot * 3 + i) do
				table.insert(report, "  [" .. pn .. "] " .. l)
			end
		end
		local ok, res = pcall(keyable, m)
		for _, l in (if ok then res else { "keyable ERROR " .. tostring(res) }) do
			table.insert(report, "  " .. l)
		end
		slot += 1
	end
end
return table.concat(report, "\n")
