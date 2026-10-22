--!nocheck
-- Numeric QA for the Jade Jiao pose module (run in a sandbox through execute_luau after
-- tools/serve.sh and push_src for any edited module):
--   _G.QA = "rig" | "moves" | "skate" | "coil" ; loadstring(HttpService:GetAsync("http://127.0.0.1:8767/beasts/qa_jade_jiao.luau"))()
-- Forward kinematics on the real template (parents first, Part0 * C0 * Transform * C1^-1), no
-- Motor6D playback needed. Results come back as the returned string.
local ServerStorage = game:GetService("ServerStorage")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local poseClone = Client.EnemyPoses:Clone()
poseClone.Parent = game:GetService("ReplicatedStorage") -- a fresh copy, so edits are not hidden by the require cache
local J = require(poseClone.JadeJiao)
task.defer(function() poseClone:Destroy() end)
local template = ServerStorage.Enemies.JadeJiao
local hrp = template.HumanoidRootPart
local K = J.SCALE
local mode = _G.QA or "rig"
local out = {}
local function say(...)
	table.insert(out, string.format(...))
end

local motors = {}
local byName = {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
		byName[m.Name] = m
	end
end
local parts = {}
for _, p in template:GetDescendants() do
	if p:IsA("BasePart") and p ~= hrp then
		table.insert(parts, p)
	end
end

local function fk(pose, root)
	pose = J.scaled(pose, K)
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
local function lowestHighest(part, cf)
	local s = part.Size / 2
	local ext = math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z
	return cf.Y - ext, cf.Y + ext
end
local function bounds(world)
	local lo, hi, loName = math.huge, -math.huge, ""
	for _, p in parts do
		local cf = world[p]
		if cf and p.Transparency < 1 and p.Name:sub(1, 5) ~= "Tongu" and p.Name:sub(1, 6) ~= "Barbel" then
			local a, b = lowestHighest(p, cf)
			if a < lo then
				lo, loName = a, p.Name
			end
			hi = math.max(hi, b)
		end
	end
	return lo, hi, loName
end
local function pivotOf(name, world)
	local m = byName[name]
	return (world[m.Part0] * m.C0).Position
end
local rest = fk({})
local restLo = bounds(rest)

if mode == "rig" then
	say("template parts %d, motors %d, rest lowest %.2f", #parts, #motors, restLo)
	local missing = {}
	for _, name in J.JOINTS do
		if not byName[name] then
			table.insert(missing, name)
		end
	end
	say("joints missing from rig: %s", #missing == 0 and "none" or table.concat(missing, ","))
	-- pivots against the module's contract table x K
	local worst, worstName = 0, ""
	for name, p in J.PIVOTS do
		if byName[name] then
			local real = pivotOf(name, rest)
			local want = p * K
			-- compare relative to the Body pivot: the model origin may differ from the HRP
			local d = (real - want - (pivotOf("JointRoot", rest) - J.PIVOTS.JointRoot * K)).Magnitude
			if d > worst then
				worst, worstName = d, name
			end
		end
	end
	say("pivot table vs rig: worst %.3f studs at %s (module pivots x K)", worst, worstName)
	say("JointRoot pivot real %s, HRP pos %s", tostring(pivotOf("JointRoot", rest)), tostring(hrp.Position))
	-- axis sign test on the real rig: +X pitch on JointNeck2, JointHead, fangs, hood
	local function moved(name, cf, partName, point)
		local w = fk({ [name] = cf })
		local p = partName
		return (w[template[p]].Position - rest[template[p]].Position)
	end
	say("JointNeck +0.3 X: Neck3 moves %s", tostring(moved("JointNeck", CFrame.Angles(0.3, 0, 0), "Neck3")))
	say("JointHead +0.3 X: Skull tip(Jaw) moves %s", tostring(moved("JointHead", CFrame.Angles(0.3, 0, 0), "Jaw")))
	say("JointTail +0.3 X: Tail6 moves %s", tostring(moved("JointTail", CFrame.Angles(0.3, 0, 0), "Tail6")))
	say("JointTail +0.3 Y: Tail6 moves %s", tostring(moved("JointTail", CFrame.Angles(0, 0.3, 0), "Tail6")))
	say("JointNeck +0.3 Y: Neck3 moves %s", tostring(moved("JointNeck", CFrame.Angles(0, 0.3, 0), "Neck3")))
	say("JointFangL +1.4 X: FangL moves %s", tostring(moved("JointFangL", CFrame.Angles(1.4, 0, 0), "FangL")))
	say("JointHoodL -1.2 Y: HoodL moves %s", tostring(moved("JointHoodL", CFrame.Angles(0, -1.2, 0), "HoodL")))
	say("JointHoodR +1.2 Y: HoodR moves %s", tostring(moved("JointHoodR", CFrame.Angles(0, 1.2, 0), "HoodR")))
	say("JointJaw -0.95 X: Jaw moves %s", tostring(moved("JointJaw", CFrame.Angles(-0.95, 0, 0), "Jaw")))
	return table.concat(out, "\n")
end


local function angleOf(cf)
	local axis, ang = cf:ToAxisAngle()
	return math.abs(ang)
end
local function headInfo(world)
	local sk = world[template.Skull]
	return sk.Position
end
local INPUT = { phase = _G.QA_PHASE or 2, duration = nil }
if mode == "moves" then
	local list = {}
	for name in J.moves do
		table.insert(list, name)
	end
	table.sort(list)
	say("%-12s %-8s %5s  %7s %7s %-10s %7s %6s %6s", "move", "phase", "u", "lowY", "topY", "lowPart", "headY", "headZ", "maxRot")
	for _, move in list do
		local prevEnd
		for _, phase in { "windup", "active", "recover" } do
			if J.moves[move][phase] then
				local dur = J.durations[move][phase]
				local inp = { phase = 2, duration = dur, time = 0, side = 1 }
				if move == "JiaoCoil" and phase == "recover" then inp.duration = 4.4 end
				local worstJoint, worstAng = "", 0
				local lowest, lowName, topMax = math.huge, "", -math.huge
				local firstPose, lastPose
				for _, u in { 0, 0.25, 0.5, 0.75, 0.9, 1 } do
					local pose = J.sample(move, phase, u, inp)
					for jn, cf in pose do
						if jn ~= "JointRoot" then
							local a = angleOf(cf)
							if a > worstAng then worstAng, worstJoint = a, jn end
						end
					end
					local w = fk(pose)
					local lo, hi, ln = bounds(w)
					lowest, lowName = math.min(lowest, lo), (lo <= lowest and ln or lowName)
					topMax = math.max(topMax, hi)
					local h = headInfo(w)
					if u == 0 then firstPose = pose end
					if u == 1 then lastPose = pose end
					if u == 0.5 or u == 1 then
						say("%-12s %-8s %5.2f  %7.2f %7.2f %-10s %7.2f %6.1f %6.2f %s", move, phase, u, lo, hi, ln, h.Y, h.Z, worstAng, worstJoint)
					end
				end
				-- continuity into the next phase
				if prevEnd then
					local jump, jj = 0, ""
					for jn, cf in firstPose do
						local pcf = prevEnd[jn]
						if pcf then
							local d = angleOf(pcf:Inverse() * cf) + (jn == "JointRoot" and (pcf.Position - cf.Position).Magnitude * 0.05 or 0)
							if d > jump then jump, jj = d, jn end
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

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
if mode == "skate" then
	-- belly points: the middle of a segment (between its pivot and the next); its axis is the
	-- chord between them. Sideslip is the point's ground velocity across that axis.
	local segs = { { "JointRoot", "JointTail" }, { "JointTail2", "JointTail3" }, { "JointTail4", "JointTail5" }, { "JointTail7", "JointTail8" },
		{ "JointTail9", "JointTail10" }, { "JointTail12", "JointTail13" }, { "JointTail14", "JointTail15" }, { "JointTail16", "JointTail17" } }
	for _, v in (_G.QA_SPEEDS or { 6, 12, 21, 24 }) do
		local loop = if v <= 8.5 then "walk" else "run"
		local rate = J.gaitRate(loop, v, K) * (_G.QA_RATE or 1)
		local dt = 1 / 120
		local T = (2 * math.pi / rate) * 2
		local steps = math.floor(T / dt)
		local mids, axes = {}, {}
		for i = 1, #segs do mids[i], axes[i] = {}, {} end
		for i = 0, steps do
			local t = i * dt
			local pose = J.loops[loop](rate * t, v, { time = 0, phase = 2 })
			local root = hrp.CFrame * CFrame.new(0, 0, -v * t)
			local w = fk(pose, root)
			for si, sg in segs do
				local a, b = pivotOf(sg[1], w), pivotOf(sg[2], w)
				mids[si][i] = flat((a + b) / 2)
				axes[si][i] = flat(b - a).Unit
			end
		end
		local line = {}
		local worstSlip, worstAlong = 0, 0
		for si, sg in segs do
			local maxSlip, sumAlong, cnt, maxAlong = 0, 0, 0, 0
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
			worstAlong = math.max(worstAlong, math.abs(sumAlong / cnt - v))
			table.insert(line, string.format("%s slip<=%.1f along %.1f", sg[1]:gsub("Joint", ""), maxSlip, sumAlong / cnt))
		end
		say("%s %g studs/s: rate %.2f rad/s (%.2f Hz), crest speed back %.1f studs/s; worst sideslip %.1f, worst mean-along error %.1f", loop, v, rate, rate / (2 * math.pi), rate / (2 * math.pi / J.WAVELENGTH), worstSlip, worstAlong)
		say("   %s", table.concat(line, " | "))
	end
	return table.concat(out, "\n")
end

if mode == "coil" then
	local smooth = function(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1) return t * t * (3 - 2 * t) end
	local P = hrp.Position
	for _, ph in { 2, 3 } do
		local arc = J.COIL_ARC[ph == 3 and 2 or 1]
		local dur = 4.4
		local hold = ph == 3 and 2.6 or 3.0
		for _, sec in { 0.0, 1.5, 2.8, 3.05, 3.2 } do
			local tight = smooth(0, hold - 0.1, sec)
			if sec >= hold - 0.1 then
				tight = 1 + 0.6 * smooth(hold - 0.1, hold + 0.04, sec) * (1 - smooth(hold + 0.12, hold + 0.5, sec))
			end
			local Rt = (J.COIL_RADIUS / K) * (1 - 0.12 * tight)
			local info = J.solver.ring(Rt, arc, 1)
			local pose = J.sample("JiaoCoil", "recover", sec / dur, { phase = ph, duration = dur, time = 0 })
			local w = fk(pose)
			local centre = P + Vector3.new(-Rt * K, 0, 0)
			centre = Vector3.new(centre.X, 0, centre.Z)
			local worst, worstName = 0, ""
			local names = { "JointRoot", "JointTail" }
			for i = 2, 18 do table.insert(names, "JointTail" .. i) end
			-- pivots on the ring: the body pivot, then Tail1.. up to info.used - 1 (the last used chord's end may be partial)
			local count = 0
			local ang0, angEnd
			for i, n in names do
				if i >= 2 and i <= info.used then
					local p = pivotOf(n, w)
					local d = math.abs(math.sqrt((p.X - centre.X) ^ 2 + (p.Z - centre.Z) ^ 2) - Rt * K)
					if d > worst then worst, worstName = d, n end
					count += 1
				end
			end
			local skull = w[template.Skull].Position
			local toCentre = math.sqrt((skull.X - centre.X) ^ 2 + (skull.Z - centre.Z) ^ 2)
			local archTop, archTipAng = -math.huge, 0
			for kk = 13, 18 do
				local _, b2 = lowestHighest(template["Tail" .. kk], w[template["Tail" .. kk]])
				archTop = math.max(archTop, b2)
			end
			local tip = pivotOf("JointTail18", w)
			local a0 = math.atan2(P.Z - centre.Z, P.X - centre.X)
			local a1 = math.atan2(tip.Z - centre.Z, tip.X - centre.X)
			local swept = math.deg((a1 - a0) % (2 * math.pi))
			local maxSw = 0
			for i = info.used + 1, #names do
				local q = pivotOf(names[i], w)
				local sw = math.deg((math.atan2(q.Z - centre.Z, q.X - centre.X) - a0) % (2 * math.pi))
				if sw >= 200 then maxSw = math.max(maxSw, sw) end
			end
			say("   free-tail pivots reach %.0f deg of the ring (gap starts at %.0f)", maxSw, math.deg(arc))
			local tipR = math.sqrt((tip.X - centre.X) ^ 2 + (tip.Z - centre.Z) ^ 2)
			say("   tail tip radius %.1f from centre (ring %.1f)", tipR, Rt * K)
			say("P%d t=%.2fs R_expected %.2f: on-circle pivots %d, max chord error %.3f studs (%s); head %.1f from centre, skull Y %.1f; tail tip at %.0f deg of the ring (gap is %.0f..360), arch top %.1f",
				ph, sec, Rt * K, count, worst, worstName, toCentre, skull.Y, swept, math.deg(arc), archTop)
		end
	end
	return table.concat(out, "\n")
end

return table.concat(out, "\n")
