--!nocheck
-- Numeric QA for the Frost Spider pose module (src/client/EnemyPoses/FrostSpider.luau). Run in a
-- sandbox after tools/serve.sh and pushing the module (+ Quadruped):
--   loadstring(HttpService:GetAsync("http://127.0.0.1:8767/beasts/qa_frost_spider_poses.luau"))()
-- with _G.QA = "rig" | "moves" | "loops" | "skate" | "timing". Forward kinematics on a parented
-- clone of ServerStorage.Enemies.FrostSpider (Part0 * C0 * Transform * C1^-1, parents first).
local ServerStorage = game:GetService("ServerStorage")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local poseClone = Client.EnemyPoses:Clone()
poseClone.Parent = game:GetService("ReplicatedStorage")
local J = require(poseClone.FrostSpider)
task.defer(function() poseClone:Destroy() end)

local template = ServerStorage.Enemies.FrostSpider
local hrp = template.HumanoidRootPart
local FLOOR = 0
local mode = _G.QA or "rig"
local out = {}
local function say(...) table.insert(out, string.format(...)) end

local motors, byName, mainParts = {}, {}, {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
		byName[m.Name] = m
		if m.Part1 ~= hrp then mainParts[m.Part1.Name] = m.Part1 end
	end
end
local function fk(pose)
	local world = { [hrp] = hrp.CFrame }
	local pending, guard = #motors, 0
	while pending > 0 and guard < 60 do
		guard += 1
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
	end
	return world
end
local function extentY(part, cf)
	local s = part.Size / 2
	local e = math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z
	return cf.Y - e, cf.Y + e
end
local function lowest(world)
	local lo, nm = math.huge, ""
	for name, p in mainParts do
		local a = extentY(p, world[p])
		if a < lo then lo, nm = a, name end
	end
	return lo, nm
end
local function pivotOf(name, world)
	local m = byName[name]
	return (world[m.Part0] * m.C0).Position
end
local rest = fk({})

local function penetration(pa, cfa, pb, cfb)
	local sa, sb = pa.Size / 2, pb.Size / 2
	local Aa = { cfa.RightVector, cfa.UpVector, cfa.LookVector }
	local B = { cfb.RightVector, cfb.UpVector, cfb.LookVector }
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, Aa[i]); table.insert(axes, B[i])
		for j = 1, 3 do
			local c = Aa[i]:Cross(B[j])
			if c.Magnitude > 1e-4 then table.insert(axes, c.Unit) end
		end
	end
	local d = cfb.Position - cfa.Position
	local least = math.huge
	for _, ax in axes do
		local ra = math.abs(Aa[1]:Dot(ax)) * sa.X + math.abs(Aa[2]:Dot(ax)) * sa.Y + math.abs(Aa[3]:Dot(ax)) * sa.Z
		local rb = math.abs(B[1]:Dot(ax)) * sb.X + math.abs(B[2]:Dot(ax)) * sb.Y + math.abs(B[3]:Dot(ax)) * sb.Z
		local ov = ra + rb - math.abs(d:Dot(ax))
		if ov <= 0 then return 0 end
		least = math.min(least, ov)
	end
	return least
end
local names = {}
for n in mainParts do table.insert(names, n) end
table.sort(names)
local function chainOf(n) -- leg parts of one leg are neighbours
	local tag = n:match("^%a+(%a%d)$")
	return tag
end
local function skip(a, b)
	local ta, tb = chainOf(a), chainOf(b)
	if ta and ta == tb then return true end
	if a == "Body" or b == "Body" then
		local other = if a == "Body" then b else a
		if other:match("^Fang") or other:match("^Pedipalp") or other:match("^Abdomen") then return true end
		if other:match("^Leg") then return true end -- hips sit in the body by design
	end
	if (a:match("^Fang") and b:match("^Pedipalp")) or (b:match("^Fang") and a:match("^Pedipalp")) then return true end
	if (a:match("^Fang") and b:match("^Fang")) or (a:match("^Pedipalp") and b:match("^Pedipalp")) then return true end
	return false
end
local function clips(world)
	local list = {}
	for i = 1, #names do
		for j = i + 1, #names do
			local a, b = names[i], names[j]
			if not skip(a, b) then
				local d = penetration(mainParts[a], world[mainParts[a]], mainParts[b], world[mainParts[b]])
				local d0 = penetration(mainParts[a], rest[mainParts[a]], mainParts[b], rest[mainParts[b]])
				if d > d0 + 0.12 and d > 0.25 then
					table.insert(list, string.format("%s/%s %.2f", a, b, d))
				end
			end
		end
	end
	return list
end
-- joint seams: leg->knee->foot chains must keep overlapping like at rest
local function seams(world)
	local list = {}
	for _, tag in { "L1","L2","L3","L4","R1","R2","R3","R4" } do
		for _, pr in { { "Leg", "Knee" }, { "Knee", "Foot" } } do
			local a, b = pr[1] .. tag, pr[2] .. tag
			local d = penetration(mainParts[a], world[mainParts[a]], mainParts[b], world[mainParts[b]])
			local d0 = penetration(mainParts[a], rest[mainParts[a]], mainParts[b], rest[mainParts[b]])
			if d0 > 0.05 and d < 0.4 * d0 then table.insert(list, string.format("%s/%s %.2f<%.2f", a, b, d, d0)) end
		end
	end
	return list
end
local LEGS = { "L1","L2","L3","L4","R1","R2","R3","R4" }
local function ankle(world, tag) return pivotOf("JointFoot" .. tag, world) end
local function soleOf(world, tag)
	local p = mainParts["Foot" .. tag]
	local lo = extentY(p, world[p])
	return lo
end
local function angleOf(cf) local _, a = cf:ToAxisAngle() return math.abs(a) end

local ALL_MOVES = {
	{ "WebShot", { "windup", "active", "recover" } }, { "FrostFang", { "windup", "active", "recover" } },
	{ "FrostFangSkid", { "recover" } }, { "Hop", { "active" } }, { "Stagger", { "active" } }, { "Death", { "active" } },
}

local function audit(label, pose, worstAcc)
	local world = fk(pose)
	local lo, nm = lowest(world)
	local c = clips(world)
	local s = seams(world)
	-- planted accuracy is checked in "skate"; here: floor, clipping, seams, large joint angles
	local bad = {}
	if lo < -0.03 then table.insert(bad, string.format("sunk %.3f (%s)", lo, nm)) end
	for _, x in c do table.insert(bad, "clip " .. x) end
	for _, x in s do table.insert(bad, "seam " .. x) end
	for _, tag in LEGS do
		local f = soleOf(world, tag)
		if f < -0.03 then table.insert(bad, string.format("foot%s %.3f", tag, f)) end
	end
	worstAcc.lo = math.min(worstAcc.lo, lo)
	if #bad > 0 then say("  %s: %s", label, table.concat(bad, "; ")) end
	return world
end

if mode == "rig" then
	local missing = {}
	for _, name in J.JOINTS do if not byName[name] then table.insert(missing, name) end end
	say("motors %d, joints missing from rig: %s", #motors, #missing == 0 and "none" or table.concat(missing, ","))
	-- the module's analytic leg points against real FK, at rest and under a few leg poses
	local worst = 0
	for _, tag in LEGS do
		local h, k, a = J.legPoints({}, tag)
		worst = math.max(worst, (pivotOf("JointLeg" .. tag, rest) - h).Magnitude, (pivotOf("JointKnee" .. tag, rest) - k).Magnitude, (pivotOf("JointFoot" .. tag, rest) - a).Magnitude)
	end
	say("rest pivots vs module skeleton: worst %.4f", worst)
	local acc = { lo = math.huge }
	local lo = lowest(rest)
	say("rest lowest %.3f", lo)
	-- IK accuracy: ankle error of FK against the target across a sweep
	local pose = J.sample("WebShot", "windup", 0.5)
	local world = fk(pose)
	local e = 0
	for _, tag in LEGS do
		local _, _, a = J.legPoints(pose, tag)
		local bf = CFrame.new(0, 2.3, -0.5) * pose.JointRoot
		local wa = bf:PointToWorldSpace(a - Vector3.new(0, 2.3, -0.5))
		e = math.max(e, (ankle(world, tag) - Vector3.new(0, 0, 0) - wa).Magnitude)
	end
	say("analytic vs real ankle (windup 0.5): worst %.4f", e)
elseif mode == "moves" then
	local acc = { lo = math.huge }
	for _, mv in ALL_MOVES do
		for _, ph in mv[2] do
			say("%s.%s", mv[1], ph)
			local steps = 20
			for i = 0, steps do
				local u = i / steps
				audit(string.format("u%.2f", u), J.sample(mv[1], ph, u, { duration = J.durations[mv[1]][ph], side = 1 }), acc)
			end
		end
	end
	say("lowest body part over all samples: %.3f", acc.lo)
elseif mode == "loops" then
	local acc = { lo = math.huge }
	for _, name in { "walk", "run" } do
		say(name)
		for i = 0, 24 do audit(string.format("c%.2f", i / 24), J.loops[name](i / 24 * math.pi * 2, 6, {}), acc) end
	end
	for _, dir in { 1, -1 } do
		say("circle dir %d", dir)
		for i = 0, 24 do audit(string.format("c%.2f", i / 24), J.loops.circle(i / 24 * math.pi * 2, 6, { dir = dir }), acc) end
	end
	say("idle")
	for i = 0, 60 do audit(string.format("t%.1f", i * 0.3), J.loops.idle(i * 0.3, 0, { seed = 1 }), acc) end
	say("lowest %.3f", acc.lo)
elseif mode == "skate" then
	-- planted feet: in stance a foot's world position must be stationary relative to the ground when the
	-- body moves at the gait's speed. Check stance feet move at body speed (error), and swing feet lift.
	for _, c in { { "walk", 3 }, { "walk", 6 }, { "run", 14 } } do
		local name, speed = c[1], c[2]
		local rate = J.gaitRate(name, speed)
		local dt = 1 / 60
		local prev, worst, sumErr, n = nil, 0, 0, 0
		local phase = 0
		local minDown, maxDown, lift = 99, 0, 0
		for i = 0, 119 do
			phase += rate * dt
			local pose = J.loops[name](phase, speed, {})
			local world = fk(pose)
			local pos, down = {}, 0
			for _, tag in LEGS do
				local a = ankle(world, tag) - Vector3.new(0, 0, speed * i * dt) * -1 -- body travels -Z; ground frame = model + travel
				pos[tag] = ankle(world, tag) + Vector3.new(0, 0, -speed * i * dt)
				if soleOf(world, tag) < 0.05 then down += 1 end
				lift = math.max(lift, soleOf(world, tag))
			end
			minDown, maxDown = math.min(minDown, down), math.max(maxDown, down)
			if prev then
				for _, tag in LEGS do
					if soleOf(world, tag) < 0.02 and (prev.sole[tag] or 1) < 0.02 then
						local v = (pos[tag] - prev.pos[tag]).Magnitude / dt
						worst = math.max(worst, v); sumErr += v; n += 1
					end
				end
			end
			prev = { pos = pos, sole = {} }
			for _, tag in LEGS do prev.sole[tag] = soleOf(world, tag) end
		end
		say("%s @%d: rate %.2f rad/s (cycle %.2fs); stance foot ground speed mean %.2f worst %.2f studs/s; feet down %d..%d; max lift %.2f", name, speed, rate, math.pi * 2 / rate, sumErr / math.max(n, 1), worst, minDown, maxDown, lift)
	end
elseif mode == "timing" then
	for _, mv in ALL_MOVES do
		for _, ph in mv[2] do say("%s.%s %.2fs", mv[1], ph, J.durations[mv[1]][ph]) end
	end
	-- first-frame check: windups start from rest and have moved by u = 0.1
	for _, mv in { "WebShot", "FrostFang" } do
		local p0, p1 = J.sample(mv, "windup", 0), J.sample(mv, "windup", 0.12)
		local d0, d1 = 0, 0
		for k, cf in p0 do d0 = math.max(d0, angleOf(cf)) end
		for k, cf in p1 do d1 = math.max(d1, (cf.Position - (p0[k] or CFrame.identity).Position).Magnitude, angleOf(cf)) end
		say("%s windup u0 max joint angle %.3f, u0.12 max joint motion %.3f", mv, d0, d1)
	end
end
return table.concat(out, "\n")
