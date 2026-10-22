--!nocheck
-- Numeric QA for the Blood Centipede pose module (src/client/EnemyPoses/BloodCentipede.luau).
-- Poses the real template by forward kinematics (nothing in the place is touched) for every move
-- phase (each 0.05 of u, plus its key times) and every loop (16 wave phases x walk/run speeds,
-- idle at many clocks, a turning walk), and reports flagged poses only:
--   STEP  a plate joint turned over 0.25 rad in the transform that was ASKED for (the module clamps
--         at 0.25, so this shows the clamp biting; lastMaxStep before the clamp is also checked)
--   SUNK  the lowest part below the ground (-0.02), except in the burrowing moves, where parts are
--         supposed to be under the ground (those lines report the highest point instead)
--   FLOAT the body's lowest PLATE underside more than 1.2 above the floor in a grounded pose
--   GAP   a plate/skull/jaw that no longer touches the part it hangs from (oriented boxes, 0.02 slack)
--   CLIP / MERGE  non-adjacent segments interpenetrating that did not at rest (0.08), and the same
--         between segments two joints apart (0.15)
--   LEGCLIP a leg cutting 0.08 into its neighbour legs on the same side or a plate other than its own
--         (pairs that did not touch at rest)
-- Run in Edit mode through execute_luau in a sandbox (module pushed with tools/push_src.luau, or
-- the sandbox's own copy). Options (globals): _G.CP_ONLY = "CoilSweep" (one move or loop),
-- _G.CP_VERBOSE = true (print every pose).

local ServerStorage = game:GetService("ServerStorage")
local C = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.EnemyPoses:Clone().BloodCentipede)

-- _G.CP_TARGET = "_RosterBeasts" checks the staging body (ServerStorage._RosterBeasts.BloodCentipede)
local template = (if _G.CP_TARGET then ServerStorage[_G.CP_TARGET] else ServerStorage.Enemies).BloodCentipede
local hrp = template.HumanoidRootPart
local GROUND = 0

local motors = {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
	end
end
local members = {}
for _, d in template:GetDescendants() do
	if d:IsA("BasePart") and d ~= hrp and d.Transparency < 1 then
		local seg = d:GetAttribute("Segment") or ((d.Name == "EyeL" or d.Name == "EyeR") and "Skull") or d.Name
		local segPart = template:FindFirstChild(seg)
		members[seg] = members[seg] or {}
		table.insert(members[seg], { off = segPart.CFrame:ToObjectSpace(d.CFrame), size = d.Size })
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
	local boxes, sph = {}, {}
	for seg, list in members do
		local segPart = template:FindFirstChild(seg)
		boxes[seg] = {}
		local c, n = Vector3.zero, 0
		for _, e in list do
			local cf = world[segPart] * e.off
			table.insert(boxes[seg], { cf = cf, size = e.size })
			c += cf.Position
			n += 1
		end
		c /= n
		local r = 0
		for _, b in boxes[seg] do
			r = math.max(r, (b.cf.Position - c).Magnitude + b.size.Magnitude / 2)
		end
		sph[seg] = { c = c, r = r }
	end
	return boxes, sph
end

local function extent(list, axis)
	local lo, hi = math.huge, -math.huge
	for _, b in list do
		local cf, s = b.cf, b.size / 2
		local r = math.abs(cf.UpVector:Dot(axis)) * s.Y + math.abs(cf.RightVector:Dot(axis)) * s.X + math.abs(cf.LookVector:Dot(axis)) * s.Z
		lo = math.min(lo, cf.Position:Dot(axis) - r)
		hi = math.max(hi, cf.Position:Dot(axis) + r)
	end
	return lo, hi
end

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
-- legs sit beside their plate and their neighbours' legs: only compare plates, skull, jaws, ants
local function isLeg(n)
	return n:sub(1, 3) == "Leg"
end

local restBoxes, restSph = solve({})
local restDepth = {}
for i, a in segs do
	for j = i + 1, #segs do
		local b = segs[j]
		restDepth[a .. "|" .. b] = segDepth(restBoxes, a, b)
	end
end

local function lowestOf(boxes, filter)
	local lo, hi = math.huge, -math.huge
	for seg, list in boxes do
		if not filter or filter(seg) then
			local l, h = extent(list, Vector3.yAxis)
			lo, hi = math.min(lo, l), math.max(hi, h)
		end
	end
	return lo - GROUND, hi - GROUND
end

local BURY = { BurrowDive = true, Erupt = true }
local totalPoses, flagged = 0, 0
local out, worst = {}, { step = 0, askedStep = 0 }

local function check(label, pose, buried)
	totalPoses += 1
	local issues = {}
	-- steps in the transform that was asked for
	local maxAsk = 0
	for i = 1, 12 do
		local _, ang = (pose["JointSeg" .. i] or CFrame.identity):ToAxisAngle()
		maxAsk = math.max(maxAsk, ang)
	end
	local _, angT = (pose.JointTail or CFrame.identity):ToAxisAngle()
	maxAsk = math.max(maxAsk, angT)
	local pre = C.lastMaxStep
	worst.step = math.max(worst.step, pre)
	worst.askedStep = math.max(worst.askedStep, maxAsk)
	if pre > 0.26 then
		table.insert(issues, ("STEP %.2f (clamped at .25)"):format(pre))
	end

	local boxes, sph = solve(pose)
	local lo, hi = lowestOf(boxes)
	local plateLo = lowestOf(boxes, function(s)
		return s:sub(1, 3) == "Seg" or s == "Tail" or s == "Collar"
	end)
	if buried then
		-- the whole point: report how far down, and the highest point left above ground
	else
		-- plates must stay up; the feet and pincers may graze the ground like the rest pose does (-0.07 at rest, the limit is -0.15)
		local worstSeg, worstOver = nil, 0
		for seg, list in boxes do
			local l = extent(list, Vector3.yAxis)
			l -= GROUND
			local limit = if isLeg(seg) or seg:sub(1, 3) == "Jaw" or seg:sub(1, 3) == "Ant" then -0.15 else -0.02
			if limit - l > worstOver then
				worstSeg, worstOver = seg, limit - l
			end
		end
		if worstSeg then
			table.insert(issues, ("SUNK %s by %.2f"):format(worstSeg, worstOver))
		end
		if plateLo > 1.2 then
			table.insert(issues, ("FLOAT %.2f"):format(plateLo))
		end
	end
	for seg, parent in parentOf do
		if boxes[seg] and boxes[parent] and not isLeg(seg) and segDepth(boxes, seg, parent) < -0.02 then
			table.insert(issues, "GAP " .. parent .. "/" .. seg)
		end
	end
	for i, a in segs do
		if isLeg(a) then
			continue
		end
		for j = i + 1, #segs do
			local b = segs[j]
			if isLeg(b) or adjacent(a, b) or restDepth[a .. "|" .. b] >= 0 then
				continue
			end
			if (sph[a].c - sph[b].c).Magnitude > sph[a].r + sph[b].r then
				continue
			end
			local dd = segDepth(boxes, a, b)
			local chain = parentOf[parentOf[a] or ""] == b or parentOf[parentOf[b] or ""] == a
			if dd > (if chain then 0.15 else 0.08) then
				table.insert(issues, ("%s %s/%s %.2f"):format(if chain then "MERGE" else "CLIP", a, b, dd))
			end
		end
	end
	-- legs: a leg against its neighbour legs on the same side and against the other plates
	-- (not its own), flagged when they cut in deeper than 0.08 and did not touch at rest
	for i = 1, 12 do
		for _, side in { "L", "R" } do
			local a = "Leg" .. side .. i
			local others = { "Leg" .. side .. (i - 1), "Leg" .. side .. (i + 1), "Seg" .. (i - 1), "Seg" .. (i + 1), "Collar", "Tail" }
			for _, b in others do
				local key = if a < b then a .. "|" .. b else b .. "|" .. a
				if boxes[b] and restDepth[key] and restDepth[key] < 0 and (sph[a].c - sph[b].c).Magnitude <= sph[a].r + sph[b].r then
					local dd = segDepth(boxes, a, b)
					if dd > 0.08 then
						table.insert(issues, ("LEGCLIP %s/%s %.2f"):format(a, b, dd))
					end
				end
			end
		end
	end
	local line = ("%-30s low %5.2f top %5.2f step %.2f%s"):format(label, lo, hi, pre, #issues > 0 and ("  !! " .. table.concat(issues, "; ")) or "")
	if #issues > 0 then
		flagged += 1
	end
	if #issues > 0 or _G.CP_VERBOSE then
		table.insert(out, line)
	end
end

local ONLY = _G.CP_ONLY
for move, phases in C.moves do
	if ONLY and ONLY ~= move then
		continue
	end
	for _, phaseName in { "windup", "active", "recover" } do
		local p = phases[phaseName]
		if p then
			for i = 0, 20 do
				local u = i / 20
				local pose = C.sample(move, phaseName, u, { side = 1, duration = p.duration, wavePhase = 2.0 })
				check(("%s.%s %.2f"):format(move, phaseName, u), pose, BURY[move] and true or false)
				if move == "Stagger" or move == "Death" then
					check(("%s.%s %.2f L"):format(move, phaseName, u), C.sample(move, phaseName, u, { side = -1, duration = p.duration }), false)
				end
			end
		end
	end
	-- a short burrow lane compresses the dive
	if move == "BurrowDive" then
		for i = 0, 10 do
			check(("BurrowDive.active short %.2f"):format(i / 10), C.sample(move, "active", i / 10, { duration = 0.2, wavePhase = 1 }), true)
		end
	end
	task.wait()
end

local function turnInput(time, speed, rate)
	return {
		time = time, speed = speed, seed = 1, turn = rate,
		yawAt = function(ago)
			return -rate * ago
		end,
	}
end
for name, speeds in { walk = { 3, 6, 11 }, run = { 14, 18 } } do
	if ONLY and ONLY ~= name then
		continue
	end
	for _, speed in speeds do
		for _, rate in { 0, 1.6 } do
			for i = 0, 15 do
				local ph = i / 16 * math.pi * 2
				check(("%s %d turn %.1f ph %.2f"):format(name, speed, rate, ph), C.loops[name](ph, speed, turnInput(i * 0.3, speed, rate)), false)
			end
		end
	end
	task.wait()
end
if not ONLY or ONLY == "idle" then
	for i = 0, 60 do
		check(("idle t %.1f"):format(i * 0.37), C.loops.idle(i * 0.37, 0, { seed = 3.7 }), false)
	end
end

table.insert(out, 1, ("BloodCentipede QA: %d poses, %d flagged; biggest asked step %.3f (pre-clamp %.3f)"):format(totalPoses, flagged, worst.askedStep, worst.step))
local n = #out
if n > 120 then
	for i = n, 121, -1 do
		table.remove(out, i)
	end
	table.insert(out, ("... %d more lines"):format(n - 120))
end
return table.concat(out, "\n")
