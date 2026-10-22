--!nocheck
-- Numeric QA for the Thunder Ape pose module (src/client/EnemyPoses/ThunderApe.luau). Poses the
-- ThunderApeB template by forward kinematics (scaled by its Scale attribute, like EnemyAnimator)
-- and reports per move phase at its key times and between: lowest point of each planted
-- fist/foot and of the whole body (SUNK below -0.02 studs x scale), gaps, clipping, merges, joint
-- range. _G.APE_ONLY = "ThunderPound" limits it to one move or loop; _G.APE_VARIANT = "B";
-- _G.APE_ALL = true prints every pose (default: only the ones with issues, plus a count).
-- In a sandbox push edited modules in first with tools/push_src.luau.
local ServerStorage = game:GetService("ServerStorage")

-- a fresh copy of the whole folder, so the edit-mode require cache never serves a stale
-- module and Wolf still finds its siblings
local Wolf = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.EnemyPoses:Clone().ThunderApe)

local template = ServerStorage.Enemies.ThunderApeB
local SCALE = template:GetAttribute("Scale") or 3.71
local hrp = template.HumanoidRootPart
local GROUND = 0

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

local LASTWORLD
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
	LASTWORLD = world
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
do local lo = math.huge for _, l in restBoxes do for _, b in l do local cf, e = b.cf, b.size/2 lo = math.min(lo, cf.Y - (math.abs(cf.UpVector.Y)*e.Y + math.abs(cf.RightVector.Y)*e.X + math.abs(cf.LookVector.Y)*e.Z)) end end GROUND = lo end
local restDepth = {}
for i, a in segs do
	for j = i + 1, #segs do
		restDepth[a .. "|" .. segs[j]] = segDepth(restBoxes, a, segs[j])
	end
end

local PAWS = { "HandFL", "HandFR", "FootBL", "FootBR" }
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
	if body < -0.08 and not _G.APE_AIR then
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
				if dd > (if chain then 0.15 else 0.08) * SCALE / 2.4 then
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



local function hook(world, name)
	local att = template:FindFirstChild(name, true)
	return world[att.Parent] * att.CFrame.Position
end
-- hook positions and hand centres for the contact reports (studs, model space, ground 0)
local function contacts(pose)
	check("", pose)
	local w = LASTWORLD
	local g = restBoxes -- unused
	local function p(v) return ("(%.1f,%.1f,%.1f)"):format(v.X, v.Y - hrp.Position.Y + hrp.Size.Y / 2 - hrp.Size.Y / 2, v.Z) end
	local fl, fr = w[template.HandFL].Position, w[template.HandFR].Position
	local bl, br = hook(w, "ChestBeatL_FX"), hook(w, "ChestBeatR_FX")
	return { fistL = fl, fistR = fr, fistFXL = hook(w, "FistL_FX"), fistFXR = hook(w, "FistR_FX"), beatL = bl, beatR = br, dL = (fl - bl).Magnitude, dR = (fr - br).Magnitude, hump = hook(w, "BackTop"), mouth = hook(w, "Mouth") }
end
if _G.APE_PROBE then
	return check, Wolf, contacts, function(pose) return solve(pose) end
end

local out = {}
local ONLY, VAR = _G.APE_ONLY, _G.APE_VARIANT
local function sc(p) return Wolf.scaled(p, SCALE) end
local count, bad = 0, 0
local bad_ = 0
local function add(line)
	count += 1
	if count % 6 == 0 then task.wait() end
	if line:find("!!") then bad += 1 end
	if _G.APE_BRIEF then
		local label = line:match("^(%S+ ?%S*)") or ""
		local ry, body = line:match("rootY (%-?[%d%.]+)"), line:match("body (%-?[%d%.]+)")
		local iss = line:match("!!(.*)$")
		if iss then
			local keep = {}
			for item in iss:gmatch("[^;]+") do
				local kind, val = item:match("(%a+)"), item:match("(%-?%d+%.%d+)")
				val = math.abs(tonumber(val) or 0)
				local lim = ({ SUNK = 0.6, CLIP = 0.7, MERGE = 2.2, GAP = 0, RANGE = 1.9 })[kind] or 0
				if val > lim then table.insert(keep, (item:gsub("^%s+", ""))) end
			end
			iss = if #keep > 0 then table.concat(keep, "; ") else nil
		end
		if iss then bad_ += 1 end
		if iss or _G.APE_ROWS then table.insert(out, ("%-26s rootY %6.2f u  low %6.2f  %s"):format(line:sub(1, 26), (tonumber(ry) or 0) / SCALE, tonumber(body) or 0, iss and iss:sub(1, _G.APE_BRIEF) or "ok")) end
	elseif _G.APE_ALL or line:find("!!") then table.insert(out, line) end
end
for move, phases in Wolf.moves do
	if ONLY and ONLY ~= move then continue end
	local vlist = Wolf.VARIANTS[move] or { A = phases }
	for vname, vphases in vlist do
		if VAR and VAR ~= vname then continue end
		if Wolf.VARIANTS[move] then Wolf.setVariant(move, vname) end
		for _, phaseName in { "windup", "active", "recover" } do
			local p = vphases[phaseName]
			if p then
				_G.APE_AIR = p.air and true or false
				local us = {}
				for _, k in p.keys do us[k.t] = true end
				if not _G.APE_KEYS then for i = 0, 4 do us[i / 4] = true end end
				local list = {}
				for u in us do table.insert(list, u) end
				table.sort(list)
				for _, u in list do
					_G.APE_AIR = p.air and u < 0.95
					local dur = if phaseName == "active" and (move == "BodySlam" or move == "ThunderRush" or move == "SkyfallSlam" or move == "Judgment" or move == "Bound") then p.duration else nil
					local pose = sc(Wolf.sample(move, phaseName, u, { side = 1, duration = dur }))
					add(check(("%s/%s.%s %.2f"):format(move, vname, phaseName, u), pose))
				end
			end
		end
		task.wait()
	end
end
_G.APE_AIR = false
for name, speeds in { idle = { 0 }, walk = { 3, 8 }, run = { 12, 22, 26 }, circle = { 8 } } do
	if ONLY and ONLY ~= name then continue end
	for _, speed in speeds do
		for i = 0, 15 do
			local ph = i / 16 * math.pi * 2
			local pose = sc(Wolf.loops[name](if name == "idle" then i * 0.7 else ph, speed, { dir = 1, targetYaw = 0.3, seed = 1 }))
			add(check(("%s %d %.2f"):format(name, speed, ph), pose))
		end
	end
	task.wait()
end
table.insert(out, 1, ("%d poses, %d with issues, %d over limits"):format(count, bad, bad_))
return table.concat(out, "\n")
