--!nocheck
-- Proves a rig is keyable the way Moon Animator and Animation Editor clips are: it
-- builds a KeyframeSequence that turns EVERY Motor6D by its Part1 name, plays it on a
-- parented clone through the Humanoid's Animator, and checks each joint's Transform
-- took its keyframe. Run in Edit mode through execute_luau (served over
-- http://127.0.0.1:8767/keyframe_test.luau), with TARGETS set to template paths or
-- folders, e.g. { "ServerStorage._RosterBandits" }.
-- It flags:
--   dupe      two keyed parts share a name (clips key poses by part name, so one of
--             them can't be animated separately)
--   untaken   a joint whose Transform didn't change (not reachable from the root
--             through Motor6Ds, or blocked)
-- A rig that passes reports "keyable (N joints)". The clone is deleted afterwards.

local TARGETS = {}
local ANGLE = math.rad(20)

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local function resolve(path)
	local node = game
	for name in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(name) or game:GetService(name)
	end
	return node
end

local function test(template, scratch)
	local model = template:Clone()
	model.Parent = scratch
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return template.Name .. ": no HumanoidRootPart or Humanoid"
	end
	root.Anchored = true

	local motors, children, names = {}, {}, {}
	local problems = {}
	for _, m in model:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(motors, m)
			children[m.Part0] = children[m.Part0] or {}
			table.insert(children[m.Part0], m.Part1)
			local n = m.Part1.Name
			if names[n] then
				table.insert(problems, "dupe: two keyed parts named " .. n)
			end
			names[n] = true
		end
	end

	-- one pose per part, nested like the motor tree from the root
	local ks = Instance.new("KeyframeSequence")
	for _, t in { 0, 1 } do
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local function add(part, parentPose)
			local pose = Instance.new("Pose")
			pose.Name = part.Name
			pose.Weight = 1
			pose.CFrame = if part == root then CFrame.identity else CFrame.Angles(ANGLE, ANGLE, 0)
			pose.Parent = parentPose
			for _, child in children[part] or {} do
				add(child, pose)
			end
		end
		add(root, kf)
		kf.Parent = ks
	end

	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(ks)
	local track = animator:LoadAnimation(anim)
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 3 do
		task.wait()
	end
	track:Play(0)
	animator:StepAnimations(0.1)
	local untaken = 0
	for _, m in motors do
		local _, angle = m.Transform:ToAxisAngle()
		if math.abs(angle) < math.rad(5) then
			untaken += 1
			table.insert(problems, "untaken: " .. m.Name .. " (" .. m.Part0.Name .. " -> " .. m.Part1.Name .. ")")
		end
	end
	track:Stop(0)
	model:Destroy()
	if #problems == 0 then
		return ("%s: keyable (%d joints)"):format(template.Name, #motors)
	end
	return ("%s: %d problem(s)\n  %s"):format(template.Name, #problems, table.concat(problems, "\n  "))
end

local scratch = Instance.new("Folder")
scratch.Name = "_KeyframeTest"
scratch:AddTag("EditorOnly")
scratch.Parent = workspace
local out = {}
for _, path in TARGETS do
	local node = resolve(path)
	if not node then
		table.insert(out, path .. ": not found")
	elseif node:IsA("Model") then
		table.insert(out, test(node, scratch))
	else
		for _, m in node:GetChildren() do
			if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then
				table.insert(out, test(m, scratch))
			end
		end
	end
end
scratch:Destroy()
return table.concat(out, "\n")
