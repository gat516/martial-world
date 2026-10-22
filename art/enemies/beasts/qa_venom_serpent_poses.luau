--!nocheck
-- Numeric QA for the Venom Serpent pose module (src/client/EnemyPoses/VenomSerpent.luau). Run
-- it in a sandbox (tools/sandbox.sh), after tools/serve.sh and pushing the module:
--   loadstring(HttpService:GetAsync("http://127.0.0.1:8767/beasts/qa_venom_serpent_poses.luau"))()
-- with _G.QA = "rig" | "moves" | "clip" | "skate" | "timing" | "loops". The rig is the roster body
-- ServerStorage._RosterBeasts.VenomSerpent (build_venom_serpent.luau + rig_venom_serpent.luau)
-- cloned to ServerStorage._AnimSerpent and ScaleTo(1.4) (the shape of VenomSerpentB); the script
-- makes the clone itself. Forward kinematics (Part0 * C0 * Transform * C1^-1, parents first), no
-- Motor6D playback. Results come back as the returned string.
local ServerStorage = game:GetService("ServerStorage")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local poseClone = Client.EnemyPoses:Clone()
poseClone.Parent = game:GetService("ReplicatedStorage") -- a fresh copy, so edits are not hidden by the require cache
local J = require(poseClone.VenomSerpent)
task.defer(function() poseClone:Destroy() end)

local folder = ServerStorage:FindFirstChild("_AnimSerpent")
local template = folder and folder:FindFirstChild("VenomSerpent")
if not template then
	folder = folder or Instance.new("Folder")
	folder.Name = "_AnimSerpent"
	folder.Parent = ServerStorage
	template = (ServerStorage._RosterBeasts.VenomSerpent :: Model):Clone()
	template.Parent = folder
	template:ScaleTo(1.4)
end
local hrp = template.HumanoidRootPart
local FLOOR = hrp.Position.Y - 2.38 -- the HRP centre is 2.38 above the ground at 1.40x
local mode = _G.QA or "rig"
local out = {}
local function say(...)
	table.insert(out, string.format(...))
end

local motors, byName, mainParts = {}, {}, {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
		byName[m.Name] = m
		if m.Part1 ~= hrp then
			mainParts[m.Part1.Name] = m.Part1
		end
	end
end

local function fk(pose, root)
	pose = J.scaled(pose, J.SCALE)
	local world = { [hrp] = root or hrp.CFrame }
	local pending = #motors
	local guard = 0
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
	return cf.Y - e - FLOOR, cf.Y + e - FLOOR
end
local function bounds(world, only)
	local lo, hi, loName, hiName = math.huge, -math.huge, "", ""
	for name, p in mainParts do
		if not only or only[name] then
			local a, b = extentY(p, world[p])
			if a < lo then
				lo, loName = a, name
			end
			if b > hi then
				hi, hiName = b, name
			end
		end
	end
	return lo, hi, loName, hiName
end
local GROUND = { Body = true, Tail1 = true, Tail2 = true, Tail3 = true, Tail4 = true, Tail5 = true }
local function pivotOf(name, world)
	local m = byName[name]
	return (world[m.Part0] * m.C0).Position
end
local function rel(p)
	return Vector3.new(p.X - hrp.Position.X, p.Y - FLOOR, p.Z - hrp.Position.Z)
end
local rest = fk({})

-- OBB overlap (SAT): the least penetration depth, or 0 when apart
local function corners(part, cf)
	local s = part.Size / 2
	return cf, s
end
local function penetration(pa, cfa, pb, cfb)
	local sa, sb = pa.Size / 2, pb.Size / 2
	local A = { cfa.RightVector, cfa.UpVector, cfa.LookVector }
	local B = { cfb.RightVector, cfb.UpVector, cfb.LookVector }
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, A[i])
		table.insert(axes, B[i])
		for j = 1, 3 do
			local c = A[i]:Cross(B[j])
			if c.Magnitude > 1e-4 then
				table.insert(axes, c.Unit)
			end
		end
	end
	local d = cfb.Position - cfa.Position
	local least = math.huge
	for _, ax in axes do
		local ra = math.abs(A[1]:Dot(ax)) * sa.X + math.abs(A[2]:Dot(ax)) * sa.Y + math.abs(A[3]:Dot(ax)) * sa.Z
		local rb = math.abs(B[1]:Dot(ax)) * sb.X + math.abs(B[2]:Dot(ax)) * sb.Y + math.abs(B[3]:Dot(ax)) * sb.Z
		local ov = ra + rb - math.abs(d:Dot(ax))
		if ov <= 0 then
			return 0
		end
		least = math.min(least, ov)
	end
	return least
end
-- pairs to test: everything but a part and its neighbours in the chain
local ADJ = {
	Body = { Neck1 = 1, Tail1 = 1 }, Neck1 = { Neck2 = 1 }, Neck2 = { Neck3 = 1 }, Neck3 = { Skull = 1, HoodL = 1, HoodR = 1, Jaw = 0 },
	Skull = { Jaw = 1 }, Tail1 = { Tail2 = 1 }, Tail2 = { Tail3 = 1 }, Tail3 = { Tail4 = 1 }, Tail4 = { Tail5 = 1 },
}
local function adjacent(a, b)
	return (ADJ[a] and ADJ[a][b]) or (ADJ[b] and ADJ[b][a])
end
local names = {}
for n in mainParts do
	table.insert(names, n)
end
table.sort(names)
-- clipping a pose adds over the rest pose; for the hoods over the same pose with the hoods shut
-- (the head pitched up already sits in the hood plate, as the user's own windup pose does)
local function clips(world, pose)
	local shut
	if pose then
		local p0 = table.clone(pose)
		p0.JointHoodL, p0.JointHoodR = CFrame.identity, CFrame.identity
		shut = fk(p0)
	end
	local list = {}
	for i = 1, #names do
		for j = i + 1, #names do
			local a, b = names[i], names[j]
			if not adjacent(a, b) then
				local d = penetration(mainParts[a], world[mainParts[a]], mainParts[b], world[mainParts[b]])
				local ref = rest
				if shut and (a:sub(1, 4) == "Hood" or b:sub(1, 4) == "Hood") then
					ref = shut
				end
				local d0 = penetration(mainParts[a], ref[mainParts[a]], mainParts[b], ref[mainParts[b]])
				if d > d0 + 0.2 and d > 0.4 then
					table.insert(list, string.format("%s/%s %.2f", a, b, d))
				end
			end
		end
	end
	return list
end
-- joint seams: an adjacent pair should keep overlapping like it does at rest (a slit of sky
-- shows when the overlap is gone)
local function seams(world)
	local list = {}
	for a, row in ADJ do
		for b, v in row do
			if v == 1 then
				local d = penetration(mainParts[a], world[mainParts[a]], mainParts[b], world[mainParts[b]])
				local d0 = penetration(mainParts[a], rest[mainParts[a]], mainParts[b], rest[mainParts[b]])
				if d0 > 0.05 and d < 0.4 * d0 then
					table.insert(list, string.format("%s/%s %.2f<%.2f", a, b, d, d0))
				end
			end
		end
	end
	return list
end
local function angleOf(cf)
	local _, ang = cf:ToAxisAngle()
	return math.abs(ang)
end

local ALL_MOVES = { "VenomSpit", "HoodStrike", "HoodStrikeSkid", "Hop", "TailSnap", "Stagger", "Death" }

if mode == "rig" then
	local missing = {}
	for _, name in J.JOINTS do
		if not byName[name] then
			table.insert(missing, name)
		end
	end
	say("motors %d, joints missing from rig: %s", #motors, #missing == 0 and "none" or table.concat(missing, ","))
	local worst, worstName = 0, ""
	for name, p in J.PIVOTS do
		local real = rel(pivotOf(name, rest))
		local want = p - Vector3.new(0, 2.38, 0) + Vector3.new(0, 2.38, 0)
		local d = (real - want).Magnitude
		if d > worst then
			worst, worstName = d, name
		end
	end
	say("pivot table vs rig: worst %.3f studs at %s", worst, worstName)
	local lo, hi, ln = bounds(rest)
	say("rest: lowest %.3f (%s), highest %.2f, extents %s", lo, ln, hi, tostring(template:GetExtentsSize()))
	local function moved(name, cf, partName)
		local w = fk({ [name] = cf })
		return w[template[partName]].Position - rest[template[partName]].Position
	end
	say("JointNeck +0.3 X: Neck3 moves %s", tostring(moved("JointNeck", CFrame.Angles(0.3, 0, 0), "Neck3")))
	say("JointHead +0.3 X: Jaw moves %s", tostring(moved("JointHead", CFrame.Angles(0.3, 0, 0), "Jaw")))
	say("JointNeck +0.3 Y: Neck3 moves %s", tostring(moved("JointNeck", CFrame.Angles(0, 0.3, 0), "Neck3")))
	say("JointJaw -0.95 X: Jaw moves %s", tostring(moved("JointJaw", CFrame.Angles(-0.95, 0, 0), "Jaw")))
	say("JointHoodL -1.1 Y: HoodL moves %s", tostring(moved("JointHoodL", CFrame.Angles(0, -1.1, 0), "HoodL")))
	say("JointHoodR +1.1 Y: HoodR moves %s", tostring(moved("JointHoodR", CFrame.Angles(0, 1.1, 0), "HoodR")))
	say("JointTail +0.3 Y: Tail3 moves %s", tostring(moved("JointTail", CFrame.Angles(0, 0.3, 0), "Tail3")))
	return table.concat(out, "\n")
end

if mode == "moves" or mode == "clip" then
	say("%-14s %-8s %5s  %6s %6s %-6s %7s  %5s %6s %6s  %s", "move", "phase", "u", "lowY", "gndLo", "part", "mouthY", "mZ", "maxRot", "mxBend", "clips")
	for _, move in ALL_MOVES do
		local prevEnd
		for _, phase in { "windup", "active", "recover" } do
			local def = J.moves[move][phase]
			if def then
				local dur = J.durations[move][phase]
				local inp = { phase = 1, duration = dur, time = 0, side = 1, speed = 26, wavePhase = 0.7, targetYaw = -1.1 }
				local firstPose, lastPose
				local nclip = {}
				for _, u in { 0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1 } do
					local pose = J.sample(move, phase, u, inp)
					local worstAng, worstJoint = 0, ""
					for jn, cf in pose do
						if jn ~= "JointRoot" then
							local a = angleOf(cf)
							if a > worstAng then
								worstAng, worstJoint = a, jn
							end
						end
					end
					-- bend between consecutive neck bones (gap check): relative rotation about X
					local mxBend = 0
					for _, jn in { "JointNeck", "JointNeck2", "JointNeck3", "JointHead" } do
						mxBend = math.max(mxBend, angleOf(pose[jn]))
					end
					local w = fk(pose)
					local lo, hi, ln = bounds(w)
					local glo = bounds(w, GROUND)
					local mouth = rel(w[template.Jaw].Position)
					if u == 0 then
						firstPose = pose
					end
					if u == 1 then
						lastPose = pose
					end
					local cl = clips(w, pose)
					for _, c in cl do
						nclip[c] = true
					end
					for _, c in seams(w) do
						nclip["SEAM " .. c] = true
					end
					if mode == "moves" and (u == 0.45 or u == 0.75 or u == 1) then
						say("%-14s %-8s %5.2f  %6.2f %6.2f %-6s %7.2f  %5.1f %6.2f %6.2f  %s", move, phase, u, lo, glo, ln, mouth.Y, mouth.Z, worstAng, mxBend, table.concat(cl, ";"))
					end
				end
				local all = {}
				for c in nclip do
					table.insert(all, c)
				end
				table.sort(all)
				if mode == "clip" or #all > 0 then
					say("   %s %s clipping over 8 samples: %s", move, phase, #all == 0 and "none" or table.concat(all, "; "))
				end
				if prevEnd then
					local jump, jj = 0, ""
					for jn, cf in firstPose do
						local pcf = prevEnd[jn]
						if pcf then
							local d = angleOf(pcf:Inverse() * cf) + (jn == "JointRoot" and (pcf.Position - cf.Position).Magnitude * 0.05 or 0)
							if d > jump then
								jump, jj = d, jn
							end
						end
					end
					say("   continuity into %s: worst joint jump %.3f at %s", phase, jump, jj)
				end
				prevEnd = lastPose
			end
		end
	end
	return table.concat(out, "\n")
end

if mode == "timing" then
	-- the key beats against the attack table: mouth position (relative to HRP, ground 0) per step
	local function mouthAt(move, phase, u, dur)
		local pose = J.sample(move, phase, u, { duration = dur, time = 0, side = 1, speed = 26 })
		local w = fk(pose)
		return rel(w[template.Skull].Position), rel(w[template.Jaw].Position)
	end
	local spit = J.durations.VenomSpit.windup
	say("VenomSpit windup %.2fs: skull centre (y, z) per 0.05 s; the throw is 0.70 s (u %.3f)", spit, 0.7 / spit)
	local prev
	for i = 0, 22 do
		local sec = i * 0.05
		local sk = mouthAt("VenomSpit", "windup", sec / spit, spit)
		local speed = prev and (sk - prev).Magnitude / 0.05 or 0
		say("  t=%.2f skull y=%.2f z=%.2f  speed %.1f studs/s", sec, sk.Y, sk.Z, speed)
		prev = sk
	end
	local hs = J.durations.HoodStrike.windup
	say("HoodStrike windup %.2fs", hs)
	prev = nil
	for i = 0, 12 do
		local sec = i * 0.05
		local sk = mouthAt("HoodStrike", "windup", sec / hs, hs)
		say("  t=%.2f skull y=%.2f z=%.2f  speed %.1f", sec, sk.Y, sk.Z, prev and (sk - prev).Magnitude / 0.05 or 0)
		prev = sk
	end
	say("HoodStrike active %.2fs", J.durations.HoodStrike.active)
	prev = nil
	for i = 0, 5 do
		local sec = i * 0.05
		local sk = mouthAt("HoodStrike", "active", sec / 0.25, 0.25)
		say("  t=%.2f skull y=%.2f z=%.2f  speed %.1f", sec, sk.Y, sk.Z, prev and (sk - prev).Magnitude / 0.05 or 0)
		prev = sk
	end
	return table.concat(out, "\n")
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
if mode == "hop" then
	-- the backslide: the root travels +Z 9 studs in the hop's seconds; EnemyAnimator advances the
	-- wave phase at the run rate meanwhile. The body should slide along its own groove BACKWARD:
	-- belly points move along the body axis (front -> rear = +), with little sideslip.
	local dur = _G.QA_HOP or 0.35
	local v = 9 / dur
	local rate = J.gaitRate("run", v, 1)
	local w0 = _G.QA_W0 or 0.7
	local dt = dur / 60
	local segs = { { "Body", "JointTail" }, { "JointTail", "JointTail2" }, { "JointTail2", "JointTail3" }, { "JointTail3", "JointTail4" }, { "JointTail4", "JointTail5" } }
	local mids, axes = {}, {}
	for i = 1, #segs do
		mids[i], axes[i] = {}, {}
	end
	local worstLow, headY = math.huge, {}
	for i = 0, 60 do
		local sec = i * dt
		local u = sec / dur
		local pose = J.sample("Hop", "active", u, { duration = dur, time = sec, speed = v, wavePhase = w0 + rate * sec, side = 1 })
		local root = hrp.CFrame * CFrame.new(0, 0, v * sec)
		local w = fk(pose, root)
		for si, sg in segs do
			local a = if sg[1] == "Body" then w[template.Body].Position else pivotOf(sg[1], w)
			local b = pivotOf(sg[2], w)
			mids[si][i] = flat((a + b) / 2)
			axes[si][i] = flat(b - a).Unit
		end
		local lo = bounds(w)
		worstLow = math.min(worstLow, lo)
	end
	local line = {}
	for si, sg in segs do
		local maxSlip, sumAlong, cnt = 0, 0, 0
		for i = 1, 59 do
			local vel = (mids[si][i + 1] - mids[si][i - 1]) / (2 * dt)
			local ax = axes[si][i]
			maxSlip = math.max(maxSlip, math.abs(vel:Dot(Vector3.new(-ax.Z, 0, ax.X))))
			sumAlong += vel:Dot(ax)
			cnt += 1
		end
		table.insert(line, string.format("%s slip<=%.1f along %+.1f", (sg[2]:gsub("Joint", "")), maxSlip, sumAlong / cnt))
	end
	say("hop %.2fs at %.1f studs/s (run wave rate %.2f rad/s, forward wave would be %.1f cycles): lowest %.2f", dur, v, rate, rate * dur / (2 * math.pi), worstLow)
	say("   %s", table.concat(line, " | "))
	-- phase continuity into what EnemyAnimator hands the next state
	local pEnd = J.sample("Hop", "active", 1, { duration = dur, time = dur, speed = v, wavePhase = w0 + rate * dur })
	local pNext = J.sample("Hop", "recover", 0, { duration = 0.3, time = dur, speed = 0, wavePhase = w0 + rate * dur })
	local jump = 0
	for jn, cf in pEnd do
		if pNext[jn] then
			jump = math.max(jump, (cf:Inverse() * pNext[jn]).Position.Magnitude + select(2, (cf:Inverse() * pNext[jn]):ToAxisAngle()))
		end
	end
	say("   hop end -> recover start: worst joint jump %.3f", jump)
	return table.concat(out, "\n")
end

if mode == "skate" or mode == "loops" then
	-- belly points: the middle of a segment (between pivots); sideslip is the point's ground
	-- velocity across the segment's axis
	local segs = { { "Body", "JointTail" }, { "JointTail", "JointTail2" }, { "JointTail2", "JointTail3" }, { "JointTail3", "JointTail4" }, { "JointTail4", "JointTail5" } }
	for _, v in (_G.QA_SPEEDS or { 2.5, 5, 9 }) do
		local loop = if v <= 7 then "walk" else "run"
		local rate = J.gaitRate(loop, v, 1)
		local dt = 1 / 120
		local T = (2 * math.pi / rate) * 2
		local steps = math.floor(T / dt)
		local mids, axes = {}, {}
		for i = 1, #segs do
			mids[i], axes[i] = {}, {}
		end
		local minLow, maxHead, minHead = math.huge, 0, math.huge
		local nclip = {}
		for i = 0, steps do
			local t = i * dt
			local pose = J.loops[loop](rate * t, v, { time = t, phase = 1, wavePhase = rate * t })
			local root = hrp.CFrame * CFrame.new(0, 0, -v * t)
			local w = fk(pose, root)
			for si, sg in segs do
				-- (a motor's pivot is Part0 * C0: for JointRoot that is the static rest pivot, so the
				-- Body block is taken by its centre)
				local a = if sg[1] == "Body" then w[template.Body].Position else pivotOf(sg[1], w)
				local b = pivotOf(sg[2], w)
				mids[si][i] = flat((a + b) / 2)
				axes[si][i] = flat(b - a).Unit
			end
			if i % 12 == 0 then
				local lo, hi = bounds(fk(pose))
				minLow = math.min(minLow, lo)
				local mouth = rel(fk(pose)[template.Jaw].Position)
				maxHead, minHead = math.max(maxHead, mouth.Y), math.min(minHead, mouth.Y)
				for _, c in clips(fk(pose), pose) do
					nclip[c] = true
				end
			end
		end
		local line = {}
		local worstSlip = 0
		for si, sg in segs do
			local maxSlip, sumAlong, cnt = 0, 0, 0
			for i = 1, steps - 1 do
				local vel = (mids[si][i + 1] - mids[si][i - 1]) / (2 * dt)
				local ax = axes[si][i]
				local along = vel:Dot(ax)
				local slip = math.abs(vel:Dot(Vector3.new(-ax.Z, 0, ax.X)))
				maxSlip = math.max(maxSlip, slip)
				sumAlong += math.abs(along)
				cnt += 1
			end
			worstSlip = math.max(worstSlip, maxSlip)
			table.insert(line, string.format("%s slip<=%.1f along %.1f", (sg[2]:gsub("Joint", "")), maxSlip, sumAlong / cnt))
		end
		local cl = {}
		for c in nclip do
			table.insert(cl, c)
		end
		say("%s %g studs/s: wave %.2f rad/s (%.2f Hz), lowest %.2f, mouth Y %.1f..%.1f, worst sideslip %.1f, clips: %s", loop, v, rate, rate / (2 * math.pi), minLow, minHead, maxHead, worstSlip, #cl == 0 and "none" or table.concat(cl, ";"))
		say("   %s", table.concat(line, " | "))
	end
	-- idle over 8 s
	local lowest, clipsIdle = math.huge, {}
	local mouthMin, mouthMax = math.huge, -math.huge
	for i = 0, 240 do
		local t = i / 30
		local pose = J.loops.idle(t, 0, { wavePhase = 0.7, seed = 3 })
		local w = fk(pose)
		local lo = bounds(w)
		lowest = math.min(lowest, lo)
		local m = rel(w[template.Jaw].Position)
		mouthMin, mouthMax = math.min(mouthMin, m.Y), math.max(mouthMax, m.Y)
		if i % 15 == 0 then
			for _, c in clips(w, pose) do
				clipsIdle[c] = true
			end
		end
	end
	local cl = {}
	for c in clipsIdle do
		table.insert(cl, c)
	end
	say("idle 8 s: lowest %.2f, jaw Y %.2f..%.2f, clips: %s", lowest, mouthMin, mouthMax, #cl == 0 and "none" or table.concat(cl, ";"))
	-- circle
	for _, dir in { 1, -1 } do
		local pose = J.loops.circle(1.3, 6, { time = 1, dir = dir, targetYaw = 0.3 * dir, wavePhase = 1.3 })
		local w = fk(pose)
		local lo = bounds(w)
		local cl2 = clips(w, pose)
		say("circle dir %d: lowest %.2f clips %s", dir, lo, #cl2 == 0 and "none" or table.concat(cl2, ";"))
	end
	return table.concat(out, "\n")
end

return table.concat(out, "\n")
