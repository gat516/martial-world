--!nocheck
-- Numeric QA for the wolf pose module (src/client/EnemyPoses/Wolf.luau). For every move
-- phase (at its key times and between them) and every loop (16 phases, a few speeds) it
-- poses the Spirit Wolf B template by forward kinematics, without touching the place,
-- and reports:
--   feet    the lowest point of each planted paw (should be 0) and of the whole body
--           (below -0.02 is sunk into the ground)
--   gap     a joint whose child segment no longer touches its parent segment (a slit
--           of sky), oriented boxes with 0.02 slack
--   clip    two segments that don't overlap at rest and do now, by more than 0.08
--   merge   the same between segments two joints apart (an elbow ball into the chest,
--           a hock into the thigh as a leg folds), only past 0.15: blocky joints merge
--           a little when folded, as real ones do
--   range   middle joints the planting solver bent past 1.3 rad
-- Run in Edit mode through execute_luau. The module comes from the Rojo-synced
-- ModuleScript (StarterPlayerScripts.Client.EnemyPoses.Wolf), from a fresh copy of the
-- whole EnemyPoses folder so it can require shared siblings (Quadruped). In a sandbox,
-- push edited modules in first with tools/push_src.luau.
-- _G.WOLF_POSE_ONLY = "MoonPounce" limits it to one move or loop.
-- Set _G.WOLF_POSE_PREVIEW = { { "MoonPounce", "windup", 1 }, { "loop", "run", 2.0, 18 } }
-- to also leave anchored, posed copies in Workspace._WolfPoses (EditorOnly) for review.

local ServerStorage = game:GetService("ServerStorage")

-- a fresh copy of the whole folder, so the edit-mode require cache never serves a stale
-- module and Wolf still finds its siblings
local Wolf = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.EnemyPoses:Clone().Wolf)

local template = ServerStorage._StagingEnemies.SpiritWolf_B
local hrp = template.HumanoidRootPart
local GROUND = hrp.Position.Y - 2.6

local motors, segOf = {}, {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
	end
end
-- each visible part and its offset to its segment
local members = {}
for _, d in template:GetDescendants() do
	if d:IsA("BasePart") and d ~= hrp and d.Transparency < 1 then
		local seg = d:GetAttribute("Segment") or ((d.Name == "EyeL" or d.Name == "EyeR") and "Skull") or d.Name
		local segPart = template:FindFirstChild(seg)
		members[seg] = members[seg] or {}
		table.insert(members[seg], { part = d, off = segPart.CFrame:ToObjectSpace(d.CFrame), size = d.Size })
		segOf[d] = seg
	end
end

local function solve(pose)
	local world = { [hrp] = hrp.CFrame }
	local pending = #motors
	while pending > 0 do
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
	end
	local boxes = {}
	for seg, list in members do
		local segPart = template:FindFirstChild(seg)
		boxes[seg] = {}
		for _, e in list do
			table.insert(boxes[seg], { cf = world[segPart] * e.off, size = e.size, name = e.part.Name })
		end
	end
	return boxes
end

local function lowest(list)
	local lo = math.huge
	for _, b in list do
		local cf, s = b.cf, b.size / 2
		lo = math.min(lo, cf.Y - (math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z))
	end
	return lo - GROUND
end

-- SAT: returns the smallest penetration depth (negative = separated by that much)
local function depth(a, b)
	local ca, cb = a.cf, b.cf
	local ea, eb = a.size / 2, b.size / 2
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
	local best = math.huge
	for _, ax in axes do
		local ra = math.abs(axA[1]:Dot(ax)) * ea.X + math.abs(axA[2]:Dot(ax)) * ea.Y + math.abs(axA[3]:Dot(ax)) * ea.Z
		local rb = math.abs(axB[1]:Dot(ax)) * eb.X + math.abs(axB[2]:Dot(ax)) * eb.Y + math.abs(axB[3]:Dot(ax)) * eb.Z
		best = math.min(best, ra + rb - math.abs(d:Dot(ax)))
	end
	return best
end

local function segDepth(boxes, s1, s2)
	local best = -math.huge
	for _, a in boxes[s1] do
		for _, b in boxes[s2] do
			best = math.max(best, depth(a, b))
		end
	end
	return best
end

local segs = {}
for seg in members do
	table.insert(segs, seg)
end
table.sort(segs)
local parentOf = {}
for _, m in motors do
	parentOf[m.Part1.Name] = m.Part0.Name
end
local function adjacent(a, b)
	return parentOf[a] == b or parentOf[b] == a or (parentOf[a] and parentOf[a] == parentOf[b])
end

local restBoxes = solve({})
local restDepth = {}
for i, a in segs do
	for j = i + 1, #segs do
		restDepth[a .. "|" .. segs[j]] = segDepth(restBoxes, a, segs[j])
	end
end

local PAWS = { "PawFL", "PawFR", "PawBL", "PawBR" }
local MIDS = { "JointElbowFL", "JointElbowFR", "JointKneeBL", "JointKneeBR" }

local function check(label, pose)
	local boxes = solve(pose)
	local issues = {}
	local all = {}
	for _, list in boxes do
		for _, b in list do
			table.insert(all, b)
		end
	end
	local body = lowest(all)
	if body < -0.02 then
		local worst, wy = "?", math.huge
		for seg, list in boxes do
			local y = lowest(list)
			if y < wy then
				worst, wy = seg, y
			end
		end
		table.insert(issues, ("SUNK %.3f (%s)"):format(body, worst))
	end
	local feet = {}
	local slide = {}
	for _, p in PAWS do
		table.insert(feet, ("%.2f"):format(lowest(boxes[p])))
		local z = boxes[p][1].cf.Z - restBoxes[p][1].cf.Z
		table.insert(slide, ("%+.2f"):format(z))
	end
	for seg, parent in parentOf do
		if boxes[seg] and boxes[parent] and segDepth(boxes, seg, parent) < -0.02 then
			table.insert(issues, "GAP " .. parent .. "/" .. seg)
		end
	end
	for i, a in segs do
		for j = i + 1, #segs do
			local b = segs[j]
			if not adjacent(a, b) and restDepth[a .. "|" .. b] < 0 then
				local dd = segDepth(boxes, a, b)
				local chain = parentOf[parentOf[a] or ""] == b or parentOf[parentOf[b] or ""] == a
				if dd > (if chain then 0.15 else 0.08) then
					table.insert(issues, ("%s %s/%s %.2f"):format(if chain then "MERGE" else "CLIP", a, b, dd))
				end
			end
		end
	end
	for _, j in MIDS do
		local x = pose[j] and pose[j]:ToEulerAnglesXYZ() or 0
		if math.abs(x) > 1.3 then
			table.insert(issues, ("RANGE %s %.2f"):format(j, x))
		end
	end
	local rootY = (pose.JointRoot or CFrame.identity).Y
	local mids = {}
	for _, j in MIDS do
		table.insert(mids, ("%.2f"):format(pose[j] and pose[j]:ToEulerAnglesXYZ() or 0))
	end
	return ("%-28s feet %s body %.2f rootY %.2f mids %s pawZ %s%s"):format(label, table.concat(feet, " "), body, rootY, table.concat(mids, " "), table.concat(slide, " "),
		#issues > 0 and ("  !! " .. table.concat(issues, "; ")) or "")
end

-- _G.WOLF_POSE_PROBE = true: return the checker and the module instead of running,
-- for trying poses: check(label, pose) -> report line
if _G.WOLF_POSE_PROBE then
	return check, Wolf
end

local out = {}
local ONLY = _G.WOLF_POSE_ONLY
for move, phases in Wolf.moves do
	if ONLY and ONLY ~= move then
		continue
	end
	for _, phaseName in { "windup", "active", "recover" } do
		local p = phases[phaseName]
		if p then
			local us = {}
			for _, k in p.keys do
				us[k.t] = true
			end
			for i = 0, 10 do
				us[i / 10] = true
			end
			local list = {}
			for u in us do
				table.insert(list, u)
			end
			table.sort(list)
			for _, u in list do
				for _, side in (p.mirror and { 1, -1 } or { 1 }) do
					local pose = Wolf.sample(move, phaseName, u, { side = side })
					table.insert(out, check(("%s.%s %.2f%s"):format(move, phaseName, u, side < 0 and " L" or ""), pose))
				end
			end
		end
	end
	task.wait()
end
for name, speeds in { idle = { 0 }, walk = { 3, 8 }, run = { 14, 18 }, circle = { 8 } } do
	if ONLY and ONLY ~= name then
		continue
	end
	for _, speed in speeds do
		for i = 0, 15 do
			local ph = i / 16 * math.pi * 2
			local pose = Wolf.loops[name](if name == "idle" then i * 0.7 else ph, speed, { dir = 1, targetYaw = 0.3, seed = 1 })
			table.insert(out, check(("%s %d %.2f"):format(name, speed, ph), pose))
		end
	end
	task.wait()
end

-- posed copies for review
if _G.WOLF_POSE_PREVIEW then
	local folder = workspace:FindFirstChild("_WolfPoses")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_WolfPoses"
		folder:AddTag("EditorOnly")
		folder.Parent = workspace
	end
	folder:ClearAllChildren()
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored = true
	plate.Size = Vector3.new(14 * #_G.WOLF_POSE_PREVIEW + 10, 1, 24)
	plate.CFrame = CFrame.new(-200 - 7 * #_G.WOLF_POSE_PREVIEW, 399.5, 3100)
	plate.Color = Color3.fromHex("6E7F5A")
	plate.Parent = folder
	for i, spec in _G.WOLF_POSE_PREVIEW do
		local pose
		if spec[1] == "loop" then
			pose = Wolf.loops[spec[2]](spec[3], spec[4] or 8, spec[5] or {})
		else
			pose = Wolf.sample(spec[1], spec[2], spec[3], spec[4] or {})
		end
		local copy = template:Clone()
		copy.Name = ("%02d_%s_%s_%s"):format(i, tostring(spec[1]), tostring(spec[2]), tostring(spec[3]))
		copy:PivotTo(CFrame.new(-200 - (i - 1) * 14 - 7, 400 + 2.6, 3100) * CFrame.Angles(0, math.pi / 2, 0))
		copy.HumanoidRootPart.Anchored = true
		copy.Parent = folder
		local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
		local ms = {}
		for _, m in copy:GetDescendants() do
			if m:IsA("Motor6D") then
				table.insert(ms, m)
			end
		end
		local pending = #ms
		while pending > 0 do
			for _, m in ms do
				if world[m.Part0] and not world[m.Part1] then
					world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
					pending -= 1
				end
			end
		end
		for _, m in ms do
			m.Part1 = nil
		end
		for part, cf in world do
			part.CFrame = cf
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		task.wait()
	end
end

return table.concat(out, "\n")
