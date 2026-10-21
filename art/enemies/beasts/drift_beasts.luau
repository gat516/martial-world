--!nocheck
-- Posed-drift check for the roster beasts, on parented clones (WeldConstraints only hold
-- inside the DataModel). For each template and each pose (rest, its windup from
-- poses.luau, and a stress pose turning every joint), it sets each Motor6D's C0 to
-- C0 * pose with only the HRP anchored, lets Edit mode solve the joints, then measures:
--   motor drift  Part1 against Part0 * C0 * C1^-1 (a segment that didn't follow its joint)
--   weld drift   each welded detail's offset to its segment against the template's
--                (a piece that stays behind or slides when its segment moves)
-- Run in Edit mode through execute_luau; it cleans up. Anything over 0.01 studs fails.

local ServerStorage = game:GetService("ServerStorage")
local POSES = loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/beasts/poses.luau?" .. os.clock()))()
local LIMIT = 0.01

local holder = Instance.new("Folder")
holder.Name = "_RosterDriftTest"
holder.Parent = workspace

local function measure(template, pose)
	local c = template:Clone()
	c:PivotTo(CFrame.new(300, 330, 3000))
	c.Parent = holder
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	local rest = {}
	for _, w in c:GetDescendants() do
		if w:IsA("WeldConstraint") then
			rest[w] = w.Part0.CFrame:ToObjectSpace(w.Part1.CFrame)
		end
	end
	for _, m in c:GetDescendants() do
		if m:IsA("Motor6D") then
			local p = if pose == "stress" then CFrame.Angles(0.5, 0.2, 0.3) else pose[m.Name]
			if p then
				m.C0 = m.C0 * p
			end
		end
	end
	local worst, who = 0, "-"
	for _, d in c:GetDescendants() do
		if d:IsA("Motor6D") then
			local e = ((d.Part0.CFrame * d.C0 * d.C1:Inverse()).Position - d.Part1.Position).Magnitude
			if e > worst then
				worst, who = e, d.Part1.Name
			end
		elseif d:IsA("WeldConstraint") then
			local now = d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame)
			local e = (now.Position - rest[d].Position).Magnitude + (now.LookVector - rest[d].LookVector).Magnitude
			if e > worst then
				worst, who = e, d.Part1.Name
			end
		end
	end
	c:Destroy()
	return worst, who
end

local out = {}
for _, template in ServerStorage._RosterBeasts:GetChildren() do
	if template:IsA("Model") and template:FindFirstChild("HumanoidRootPart") then
		local line = {}
		local pass = true
		for _, name in { "rest", "windup", "stress" } do
			local pose = if name == "rest" then {} elseif name == "windup" then (POSES[template.Name] or {}) else "stress"
			local worst, who = measure(template, pose)
			pass = pass and worst <= LIMIT
			table.insert(line, ("%s %.4f (%s)"):format(name, worst, who))
		end
		table.insert(out, template.Name .. ": " .. (if pass then "PASS " else "FAIL ") .. table.concat(line, ", "))
	end
end
holder:Destroy()
return table.concat(out, "\n")
