--!nocheck
-- Continuity and pop check for the Thunder Ape poses (sandbox, after pushing src modules and
-- setting _G.PROBE as in contacts_ape.luau). For every move and variant: the largest joint
-- rotation (rad) and root translation (studs at scale) across each phase boundary, and the
-- largest per-frame (1/60 s) joint jump inside each phase, ignoring the first/last frame.
-- Boundaries: windup(1) -> active(0), active(1) -> recover(0). _G.APE_POP = limit (rad, default 0.5).
local check, M, contacts, solve = table.unpack(_G.PROBE)
local LIM = _G.APE_POP or 0.5
local function rotDiff(a, b)
	local d = a:Inverse() * b
	local _, angle = d:ToAxisAngle()
	return math.abs(angle)
end
local function diff(p, q)
	local worst, wj = 0, ""
	for _, j in M.JOINTS do
		local a, b = p[j] or CFrame.identity, q[j] or CFrame.identity
		local d = rotDiff(a, b)
		if d > worst then worst, wj = d, j end
	end
	local t = ((p.JointRoot or CFrame.identity).Position - (q.JointRoot or CFrame.identity).Position).Magnitude
	return worst, wj, t
end
local out = {}
local DUR = { BodySlam = 0.62, ThunderRush = 0.7, Bound = 0.4, SkyfallSlam = 0.75, Judgment = 1.0, StormCall = 3.0 }
for move, vlist in M.VARIANTS do
	for v, phases in vlist do
		M.setVariant(move, v)
		local function s(phase, u) return M.sample(move, phase, u, { duration = if phase == "active" or (phase == "recover" and move == "StormCall") then DUR[move] else nil }) end
		local line = {}
		for _, pair in { { "windup", "active" }, { "active", "recover" } } do
			if phases[pair[1]] and phases[pair[2]] then
				local w, j, t = diff(s(pair[1], 1), s(pair[2], 0))
				if w > 0.12 or t > 0.2 then table.insert(line, ("%s>%s %.2f rad %s, root %.2f"):format(pair[1], pair[2], w, j, t)) end
			end
		end
		for name, p in phases do
			local dur = if (name == "active" and DUR[move]) then DUR[move] elseif name == "recover" and move == "StormCall" then DUR.StormCall else p.duration
			local n = math.floor(dur * 60)
			local prev
			local worst, wj, wf = 0, "", 0
			for i = 0, n do
				local cur = s(name, i / n)
				if prev and i > 1 and i < n then
					local d, jn = diff(prev, cur)
					if d > worst then worst, wj, wf = d, jn, i end
				end
				prev = cur
			end
			if worst > LIM then table.insert(line, ("%s pop %.2f rad/frame %s at frame %d/%d"):format(name, worst, wj, wf, n)) end
		end
		if #line > 0 then table.insert(out, ("%s/%s: %s"):format(move, v, table.concat(line, "; "))) end
		task.wait()
	end
end
-- the loops, stepped at 60 fps by their real gait rate
for _, spec in { { "walk", 4 }, { "walk", 8 }, { "run", 10 }, { "run", 14 }, { "run", 18 }, { "run", 22 }, { "run", 26 }, { "circle", 8 } } do
	local rate = M.gaitRate(spec[1], spec[2])
	local prev
	local worst, wj, wf = 0, "", 0
	local n = math.ceil(2 * math.pi / rate * 60)
	for i = 0, n do
		local cur = M.loops[spec[1]](i * rate / 60, spec[2], { dir = 1, targetYaw = 0 })
		if prev then
			local d, jn = diff(prev, cur)
			if d > worst then worst, wj, wf = d, jn, i end
		end
		prev = cur
	end
	if worst > LIM then table.insert(out, ("loop %s %d: pop %.2f rad/frame %s at frame %d/%d"):format(spec[1], spec[2], worst, wj, wf, n)) end
end
return #out == 0 and "no boundary jumps or pops" or table.concat(out, "\n")
