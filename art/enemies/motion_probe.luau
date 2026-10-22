--!nocheck
-- Motion probe for any EnemyPoses family (sandbox, Edit mode, after tools/push_src.luau).
-- Plays each move the way EnemyAnimator does and measures it per frame with forward
-- kinematics on the template (no instances move):
--   * the state timeline: [idle lead-in], windup (the def's windup), dash (charges, lunges,
--     leaps and bounds), recover (the active beat first for a stationary strike, then the
--     recover over what is left), an optional arrival follow-up (`next`, e.g. a rush's swipe)
--     or a skid (`skid`), then the hand-off into idle;
--   * the keyed blend at every state change (from the frozen last frame, `keyedBlend` seconds,
--     eased 1 - (1 - b)^2), skipped inside one attack when `seamless` is set (as the family
--     flag does), and the loop smoothing (14/s) once idle takes over;
--   * the family's scale applied after sampling (poses.scaled), as EnemyAnimator does.
-- Out, per move: each hero point's speed per frame (studs/s), its peak, HITCHES (a frame
-- where a moving hero nearly stops between two fast neighbours: a dead frame at a release),
-- the worst one-frame joint step (deg, axis-angle) and where, the lowest point against the
-- rest pose (a sinking or lifting body), and how far the root travels.
--
-- Use (art/enemies is served on 8767 by tools/serve.sh):
--   _G.MOTION = {
--     module = "ThunderApe",          -- EnemyPoses/<module>
--     template = "ThunderApeB",       -- ServerStorage.Enemies.<template>
--     def = "ThunderApe",             -- Enemies.Defs.<def> (attack timings)
--     scale = 3.71, keyedBlend = 0.06, seamless = false, -- the family's EnemyAnimator values
--     heroes = { fistR = "HandFR.FistR_FX", mouth = "Skull.Mouth", chest = "Chest" },
--     moves = { "clubSwing", { attack = "thunderRush", dash = 0.55, next = "rushSwipe" },
--               { attack = "bound", dash = 0.8, input = { mode = "over" } }, "Stagger", "Death" },
--     input = { side = 1 },           -- extra input every sample gets
--     dt = 1/30, lead = 0.2, tail = 0.6, quiet = false, positions = false,
--     lows = false, lowLimit = 0.5,   -- list every frame whose lowest point is under the floor
--     hang = 2.6,                     -- EnemyMotion's arc shape (WEIGHTED_MOVES)
--     staggerSeconds = 0.45, deathSeconds = 3.2, map = { attack = "Move" },
--   }
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/motion_probe.luau"))()
-- A move is an attack name (its move is the name capitalised, or `map[attack]`), or a spec
-- { attack, move?, dash?, next?, skid?, recover?, input?, arc?, label? }, or a chain
-- { chain = { "clubSwing", "backhand", "thunderPound" } } played as followUps (each windup
-- blends from the last recover, as in the game). `dash` overrides the flight or charge seconds
-- (DashSeconds; a bound reads its boundModes by input.mode). A leap or bound's lowest point is
-- measured against the server's arc, so a body in the air isn't counted as sunk. "Stagger" and
-- "Death" play those moves for `staggerSeconds` / `deathSeconds`.
-- Not modelled: the turn rate and velocity a motion family reads (pass them in `input`), the
-- arrival hold (dash -> follow-up windup), loops other than idle, the wall clock some modules
-- read (os.clock barely moves inside one run).
-- Rough budget (animator.md): a hero at most ~600 studs/s at contact, no one-frame joint
-- step over ~45 deg outside deliberate snaps, no hitch at a release.
local cfg = _G.MOTION or error("set _G.MOTION first")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client

-- fresh copies, so a module pushed a moment ago is what runs (require caches per instance)
local poseClone = Client.EnemyPoses:Clone()
poseClone.Parent = game:GetService("ReplicatedStorage")
local enemiesClone = Shared.Enemies:Clone()
enemiesClone.Name = "_ProbeEnemies"
enemiesClone.Parent = Shared
local okP, M = pcall(require, poseClone[cfg.module])
local okE, Enemies = pcall(require, enemiesClone)
poseClone:Destroy()
enemiesClone:Destroy()
assert(okP, M)
assert(okE, Enemies)

local def = Enemies.Defs[cfg.def] or error("no def " .. tostring(cfg.def))
local template = ServerStorage.Enemies:FindFirstChild(cfg.template) or error("no template " .. tostring(cfg.template))
local hrp = template.HumanoidRootPart
local scale = cfg.scale or 1
local keyedBlend = cfg.keyedBlend
local seamless = cfg.seamless
local dt = cfg.dt or (1 / 30)
local SMOOTHING = 14

local motors = {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
	end
end
local parts = {}
for _, p in template:GetDescendants() do
	if p:IsA("BasePart") and p ~= hrp then
		table.insert(parts, p)
	end
end
local function fk(pose)
	local world = { [hrp] = hrp.CFrame }
	local pending, guard = #motors, 0
	while pending > 0 and guard < 80 do
		guard += 1
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
	end
	-- welded riders (WeldConstraints keep their offset to their segment)
	for _, w in template:GetDescendants() do
		if w:IsA("WeldConstraint") and w.Part0 and w.Part1 then
			if world[w.Part0] and not world[w.Part1] then
				world[w.Part1] = world[w.Part0] * w.Part0.CFrame:ToObjectSpace(w.Part1.CFrame)
			elseif world[w.Part1] and not world[w.Part0] then
				world[w.Part0] = world[w.Part1] * w.Part1.CFrame:ToObjectSpace(w.Part0.CFrame)
			end
		end
	end
	return world
end
local function lowest(world)
	local lo, who = math.huge, ""
	for _, p in parts do
		local cf = world[p]
		if cf and p.Transparency < 1 then
			local s = p.Size / 2
			local ext = math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z
			if cf.Y - ext < lo then
				lo, who = cf.Y - ext, p.Name
			end
		end
	end
	return lo, who
end

-- hero points: "Part" (its centre) or "Part.Attachment"
local heroNames, heroes = {}, {}
for key, spec in cfg.heroes or { root = "HumanoidRootPart" } do
	local pName, aName = string.match(spec, "^([^%.]+)%.?(.*)$")
	local part
	for _, p in template:GetDescendants() do
		if p:IsA("BasePart") and p.Name == pName then
			part = p
			break
		end
	end
	assert(part, "no part " .. pName)
	local att = if aName ~= "" then part:FindFirstChild(aName) else nil
	heroes[key] = { part = part, offset = if att then att.CFrame else CFrame.identity }
	table.insert(heroNames, key)
end
table.sort(heroNames)

local restWorld = fk({})
local restLow = (lowest(restWorld))
local restRoot = restWorld[template:FindFirstChild("Hips", true) or hrp]

local function attackOf(name)
	if def.attack and def.attack.name == name then
		return def.attack
	end
	for _, a in def.pattern or {} do
		if a.name == name then
			return a
		end
	end
	if def.phaseCall and def.phaseCall.name == name then
		return def.phaseCall
	end
	if def.pack and def.pack.howl and def.pack.howl.name == name then
		return def.pack.howl
	end
	return nil
end
local function moveOf(attackName)
	return (cfg.map and cfg.map[attackName]) or (string.upper(string.sub(attackName, 1, 1)) .. string.sub(attackName, 2))
end
local function has(move, phase)
	local m = M.moves[move]
	return m ~= nil and m[phase] ~= nil
end

local function withInput(spec, extra)
	local inp = {}
	for k, v in cfg.input or {} do
		inp[k] = v
	end
	for k, v in spec.input or {} do
		inp[k] = v
	end
	for k, v in extra do
		inp[k] = v
	end
	return inp
end

-- the states of one move: { name, seconds, sampler(since) -> pose | nil (nil = loops) }
local function timeline(spec)
	local states = {}
	local function idle(secs)
		table.insert(states, { "idle", secs, function(since, T)
			return M.loops.idle(T, 0, withInput(spec, { still = T + 1, calm = since, phase = 1, time = T }))
		end })
	end
	if (cfg.lead or 0.2) > 0 then
		idle(cfg.lead or 0.2)
	end
	if spec.attack == "Stagger" or spec.attack == "Death" then
		local secs = if spec.attack == "Stagger" then (cfg.staggerSeconds or 0.3) else (cfg.deathSeconds or 1)
		table.insert(states, { string.lower(spec.attack), secs, function(since)
			return M.sample(spec.attack, "active", since / secs, withInput(spec, { duration = secs }))
		end })
		if spec.attack == "Stagger" then
			idle(cfg.tail or 0.6)
		end
		return states
	end
	local function strike(attackName, move, isFollow)
		local a = attackOf(attackName) or error("no attack " .. attackName)
		local wsecs = a.windup
		table.insert(states, { "windup", wsecs, function(since)
			return M.sample(move, "windup", since / wsecs, withInput(spec, { duration = wsecs }))
		end })
		local dashes = a.dashSpeed ~= nil or a.kind == "leap" or a.kind == "bound" or a.kind == "retreat"
		if dashes and has(move, "active") and not isFollow then
			local bm = spec.input and spec.input.mode and a.boundModes and a.boundModes[spec.input.mode]
			local secs = spec.dash or (bm and bm.active) or a.active or (if a.length and a.dashSpeed then a.length / a.dashSpeed else M.durations[move].active)
			-- a leap or hop rides the server's arc (EnemyMotion arcShape, WEIGHTED_MOVES), so its
			-- floor is that far below the pose's
			local mode = spec.input and spec.input.mode
			local arc = spec.arc or (mode and a.boundModes and a.boundModes[mode] and a.boundModes[mode].arc) or a.arc or 0
			table.insert(states, { "dash", secs, function(since)
				return M.sample(move, "active", since / secs, withInput(spec, { duration = secs }))
			end, function(since)
				local f = math.clamp(since / secs, 0, 1)
				return arc * (1 - math.abs(2 * f - 1) ^ (cfg.hang or 2.6))
			end })
		end
		return a, dashes
	end
	-- a chain (`chain = { "clubSwing", "backhand", "thunderPound" }`) plays each attack in turn,
	-- as a followUp does: windup, recover, the next windup
	local function play(attackName)
		local a, dashes = strike(attackName, spec.move or moveOf(attackName))
		local move = spec.move or moveOf(attackName)
		if spec.next then
			-- the arrival follow-up: its own windup and recover (EnemyAnimator blends into it)
			local nmove = moveOf(spec.next)
			local na = strike(spec.next, nmove, true)
			a, move, dashes = na, nmove, false
		end
		local rsecs = spec.recover or a.recover
		if spec.skid then
			table.insert(states, { "recover", rsecs, function(since)
				return M.sample(spec.skid, "recover", since / rsecs, withInput(spec, { duration = rsecs }))
			end })
		else
			local active = if not dashes and has(move, "active") then M.durations[move].active else nil
			table.insert(states, { "recover", rsecs, function(since)
				if active and since < active then
					return M.sample(move, "active", since / active, withInput(spec, { duration = active }))
				end
				local s = if active then since - active else since
				local secs = if active then math.max(0.05, rsecs - active) else rsecs
				if has(move, "recover") then
					return M.sample(move, "recover", s / secs, withInput(spec, { duration = secs }))
				end
				return nil
			end })
		end
	end
	for _, attackName in spec.chain or { spec.attack } do
		play(attackName)
	end
	idle(cfg.tail or 0.6)
	return states
end

local function rotDeg(a, b)
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	return math.deg(math.abs(ang))
end

local out = {}
local function say(...)
	table.insert(out, string.format(...))
end
local results = {}

for _, entry in cfg.moves do
	local spec = if type(entry) == "string" then { attack = entry } else entry
	local states = timeline(spec)
	-- the joints' Transforms as EnemyAnimator would leave them, settled in idle
	local current = M.loops.idle(0, 0, withInput(spec, { still = 1, calm = 1, phase = 1, time = 0 }))
	if scale ~= 1 then
		current = M.scaled(current, scale)
	end
	local frames = {}
	local T, wasKeyed, lastState = 0, false, nil
	local blendFrom = nil
	for _, s in states do
		local st, dur, sampler, lift = s[1], s[2], s[3], s[4]
		local tt = 0
		while tt < dur - 1e-6 do
			local target = sampler(tt, T + tt)
			local keyed = target ~= nil and st ~= "idle"
			if st ~= lastState then
				lastState = st
				local within = seamless and (st == "dash" or st == "recover") and wasKeyed
				if within then
					blendFrom = nil
				elseif keyedBlend then
					blendFrom = table.clone(current)
				end
			end
			if not target then
				target = M.loops.idle(T + tt, 0, withInput(spec, { still = 1, calm = 1 }))
			end
			if scale ~= 1 then
				target = M.scaled(target, scale)
			end
			local b = if keyedBlend then math.clamp(tt / keyedBlend, 0, 1) else 1
			b = 1 - (1 - b) ^ 2
			local alpha = math.min(1, dt * SMOOTHING)
			local nextPose = {}
			for _, name in M.JOINTS do
				local tcf = target[name] or CFrame.identity
				if keyed and keyedBlend then
					local from = blendFrom and blendFrom[name]
					nextPose[name] = if from and b < 1 then from:Lerp(tcf, b) else tcf
				elseif keyed then
					nextPose[name] = (current[name] or CFrame.identity):Lerp(tcf, math.min(1, dt * 30))
				else
					nextPose[name] = (current[name] or CFrame.identity):Lerp(tcf, alpha)
				end
			end
			wasKeyed = keyed
			-- joint step
			local worst, wn = 0, ""
			for _, name in M.JOINTS do
				local d = rotDeg(current[name] or CFrame.identity, nextPose[name])
				if d > worst then
					worst, wn = d, name
				end
			end
			current = nextPose
			local w = fk(current)
			local pts = {}
			for key, h in heroes do
				local cf = w[h.part]
				pts[key] = if cf then (cf * h.offset).Position else Vector3.zero
			end
			local rootCF = w[template:FindFirstChild("Hips", true) or hrp]
			local lo, who = lowest(w)
			lo += if lift then lift(tt) else 0
			table.insert(frames, { t = T + tt, st = st, pts = pts, jd = worst, jn = wn, lo = lo - restLow, low = who, root = rootCF and rootCF.Position })
			tt += dt
		end
		T += dur
	end
	task.wait()
	-- summaries
	local bounds = {}
	local acc = 0
	for _, s in states do
		acc += s[2]
		table.insert(bounds, string.format("%s->%.2f", s[1], acc))
	end
	local popMax, popT, popN = 0, 0, ""
	local loMin, loMax, loT, loWho = math.huge, -math.huge, 0, ""
	local rootMax = 0
	for i = 2, #frames do
		local f = frames[i]
		-- the first frame's step is the jump from the empty pose, not motion
		if f.jd > popMax then
			popMax, popT, popN = f.jd, f.t, f.jn
		end
		if f.lo < loMin then
			loMin, loT, loWho = f.lo, f.t, f.low
		end
		loMax = math.max(loMax, f.lo)
		if f.root and restRoot then
			rootMax = math.max(rootMax, (f.root - restRoot.Position).Magnitude)
		end
	end
	local label = spec.label or ((if spec.chain then table.concat(spec.chain, ">") else spec.attack) .. (if spec.next then ">" .. spec.next else "") .. (if spec.skid then ">" .. spec.skid else "") .. (if spec.input and spec.input.mode then "[" .. spec.input.mode .. "]" else ""))
	say("== %s [%s]", label, table.concat(bounds, " "))
	say("   worst joint step %.1f deg at %.2f (%s); lowest %+.2f (%s at %.2f)..%+.2f vs rest; root moves <= %.1f", popMax, popT, popN, loMin, loWho, loT, loMax, rootMax)
	local res = { label = label, worst = popMax, worstAt = popT, worstJoint = popN, low = loMin, high = loMax, heroes = {}, hitches = {} }
	for _, key in heroNames do
		local spd = {}
		local peak, peakT = 0, 0
		local list = {}
		for i = 2, #frames do
			local v = (frames[i].pts[key] - frames[i - 1].pts[key]).Magnitude / dt
			spd[i] = v
			table.insert(list, string.format("%d", math.floor(v + 0.5)))
			if v > peak then
				peak, peakT = v, frames[i].t
			end
		end
		-- hitch: a near stop between two fast frames (neighbours both > 40 st/s, this < 35% of them)
		local hitches = {}
		for i = 3, #frames - 1 do
			local a, b, c = spd[i - 1], spd[i], spd[i + 1]
			if a > 40 and c > 40 and b < 0.35 * math.min(a, c) then
				table.insert(hitches, string.format("%.2f(%s %d<%d,%d)", frames[i].t, frames[i].st, math.floor(b), math.floor(a), math.floor(c)))
			end
		end
		res.heroes[key] = { peak = peak, at = peakT }
		res.hitches[key] = hitches
		say("   %-7s peak %4.0f st/s at %.2f%s", key, peak, peakT, if #hitches > 0 then "  HITCH " .. table.concat(hitches, " ") else "")
		if not cfg.quiet then
			say("     %s", table.concat(list, " "))
		end
	end
	if cfg.lows then
		local ls = {}
		for i = 1, #frames do
			local f = frames[i]
			if f.lo < -(cfg.lowLimit or 0.5) then
				table.insert(ls, string.format("%.2f %+.1f %s", f.t, f.lo, f.low))
			end
		end
		say("     below floor: %s", if #ls > 0 then table.concat(ls, ", ") else "none")
	end
	if cfg.positions then
		local key = heroNames[1]
		local ps = {}
		for i = 1, #frames, 3 do
			local f = frames[i]
			local p = f.pts[key] - hrp.Position
			table.insert(ps, string.format("%.2f(%.1f,%.1f,%.1f)", f.t, p.X, p.Y, p.Z))
		end
		say("     %s pos: %s", key, table.concat(ps, " "))
	end
	table.insert(results, res)
end
_G.MOTION_RESULTS = results
return table.concat(out, "\n")
