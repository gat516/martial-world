--!nocheck
-- Continuity and pop check for the Thunder Ape poses (sandbox, after pushing src modules and
-- setting _G.PROBE as in contacts_ape.luau). For every move and variant:
--   * the largest joint rotation (rad) and root translation (unit studs) across each phase
--     boundary (windup(1) -> active(0), active(1) -> recover(0));
--   * the largest SPIKE inside each phase at 60 fps: a joint's step on one frame minus the mean
--     of its steps on the frames either side. A fast swing moves a lot every frame and has no
--     spike; a pop (a solver branch flip, a plant switch, a root drop snapping) does.
--   * the loops the same way, stepped at their real gait rate (circle both ways).
-- _G.APE_POP = spike limit (rad, default 0.15). The max per-frame step is printed alongside.
local check, M, contacts, solve = table.unpack(_G.PROBE)
local LIM = _G.APE_POP or 0.15
local function rotDiff(a, b)
	local _, angle = (a:Inverse() * b):ToAxisAngle()
	return math.abs(angle)
end
local function diff(p, q)
	local worst, wj = 0, ""
	for _, j in M.JOINTS do
		local d = rotDiff(p[j] or CFrame.identity, q[j] or CFrame.identity)
		if d > worst then worst, wj = d, j end
	end
	local t = ((p.JointRoot or CFrame.identity).Position - (q.JointRoot or CFrame.identity).Position).Magnitude
	return worst, wj, t
end
-- frames: a function i -> pose for i = 0..n. Returns the worst spike, the worst step and where.
local function scan(f, n)
	local frames = {}
	for i = 0, n do
		frames[i] = f(i)
	end
	local spike, sinfo, step = 0, "", 0
	for _, j in M.JOINTS do
		local d = {}
		for i = 1, n do
			d[i] = rotDiff(frames[i - 1][j] or CFrame.identity, frames[i][j] or CFrame.identity)
			step = math.max(step, d[i])
		end
		for i = 2, n - 1 do
			local s = d[i] - 0.5 * (d[i - 1] + d[i + 1])
			if s > spike then
				spike, sinfo = s, ("%s f%d/%d (%.2f between %.2f and %.2f)"):format(j, i, n, d[i], d[i - 1], d[i + 1])
			end
		end
	end
	-- the root's own translation (unit studs per frame) spikes too when a drop snaps
	for i = 2, n - 1 do
		local function dy(a, b) return ((frames[a].JointRoot or CFrame.identity).Position - (frames[b].JointRoot or CFrame.identity).Position).Magnitude end
		local s = dy(i, i - 1) - 0.5 * (dy(i - 1, i - 2) + dy(i + 1, i))
		if s > spike then
			spike, sinfo = s, ("root move f%d/%d (%.2f u)"):format(i, n, dy(i, i - 1))
		end
	end
	return spike, sinfo, step
end
local T = M.TIMING
local out = {}
local worstSpike = 0
local saved = table.clone(M.VARIANT)
for move, vlist in M.VARIANTS do
	for v, phases in vlist do
		M.setVariant(move, v)
		local function dur(phase)
			local t = T[move]
			return t and t[({ windup = 1, active = 2, recover = 3 })[phase]] or phases[phase].duration
		end
		local function s(phase, u) return M.sample(move, phase, u, { duration = dur(phase), side = 1 }) end
		local line = {}
		for _, pair in { { "windup", "active" }, { "active", "recover" } } do
			if phases[pair[1]] and phases[pair[2]] then
				local w, j, t = diff(s(pair[1], 1), s(pair[2], 0))
				if w > 0.12 or t > 0.06 then table.insert(line, ("%s>%s %.2f rad %s, root %.2f u"):format(pair[1], pair[2], w, j, t)) end
			end
		end
		for _, name in { "windup", "active", "recover" } do
			if phases[name] then
				local n = math.max(3, math.floor(dur(name) * 60))
				local sp, info, step = scan(function(i) return s(name, i / n) end, n)
				worstSpike = math.max(worstSpike, sp)
				if sp > LIM then table.insert(line, ("%s spike %.2f %s, max step %.2f"):format(name, sp, info, step)) end
			end
		end
		if #line > 0 then table.insert(out, ("%s/%s: %s"):format(move, v, table.concat(line, "; "))) end
		task.wait()
	end
end
-- back to the defaults
for move, v in saved do
	M.setVariant(move, v)
end
for _, spec in { { "walk", 4, 1 }, { "walk", 8, 1 }, { "run", 10, 1 }, { "run", 14, 1 }, { "run", 18, 1 }, { "run", 22, 1 }, { "run", 26, 1 }, { "circle", 8, 1 }, { "circle", 8, -1 }, { "circle", 14, -1 } } do
	local rate = M.gaitRate(spec[1], spec[2])
	local n = math.ceil(2 * math.pi / rate * 60)
	local sp, info, step = scan(function(i) return M.loops[spec[1]](i * rate / 60, spec[2], { dir = spec[3], targetYaw = 0 }) end, n)
	worstSpike = math.max(worstSpike, sp)
	if sp > LIM then table.insert(out, ("loop %s %d dir %d: spike %.2f %s, max step %.2f"):format(spec[1], spec[2], spec[3], sp, info, step)) end
	task.wait()
end
table.insert(out, 1, ("worst spike %.2f rad (limit %.2f)"):format(worstSpike, LIM))
return table.concat(out, "\n")
