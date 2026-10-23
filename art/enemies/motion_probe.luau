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
-- Start from the family's shared spec in art/enemies/motion_specs.luau (add a family that isn't
-- there yet). Use (art/enemies is served on 8767 by tools/serve.sh; with _G.SERVE_BASE set to a
-- worktree's root URL the other art/enemies scripts read <SERVE_BASE>art/enemies/ instead):
--   _G.MOTION = {
--     module = "ThunderApe",          -- EnemyPoses/<module>
--     template = "ThunderApeB",       -- ServerStorage.Enemies.<template>
--     def = "ThunderApe",             -- Enemies.Defs.<def> (attack timings)
--     scale = 3.71, keyedBlend = 0.06, seamless = false, -- the family's EnemyAnimator values
--     seamlessStrike = false,         -- (or this: stationary strikes only, dashes keep the blend)
--     heroes = { fistR = "HandFR.FistR_FX", mouth = "Skull.Mouth", chest = "Chest" },
--     moves = { "clubSwing", { attack = "thunderRush", dash = 0.55, next = "rushSwipe" },
--               { attack = "bound", dash = 0.8, input = { mode = "over" } }, "Stagger", "Death" },
--     input = { side = 1 },           -- extra input every sample gets
--     dt = 1/30, lead = 0.2, tail = 0.6, quiet = false, positions = false,
--     lows = false, lowLimit = 0.5,   -- list every frame whose lowest point is under the floor
--     steps = false, stepLimit = 25,  -- list every frame whose worst joint step is over stepLimit deg
--     hang = 2.6,                     -- EnemyMotion's arc shape (WEIGHTED_MOVES)
--     staggerSeconds = 0.45, deathSeconds = 3.2, map = { attack = "Move" },
--     setup = function(M, template) M.configure(template, 2.13) end, -- optional, before sampling
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
-- arrival hold (dash -> follow-up windup), speed changes inside a loop, the wall clock some modules
-- read (os.clock barely moves inside one run).
-- A loop is { loop = "walk", speed = 6, seconds = 2 } (run, circle...): M.loops[loop] at a steady
-- speed, its phase advanced by M.gaitRate as EnemyAnimator does, with the loop smoothing.
-- `keep = true` stores every frame's pose in the results (tools/anim_filmstrip.luau uses it).
-- Rough budget (animator.md): a hero at most ~600 studs/s at contact, no one-frame joint
-- step over ~45 deg outside deliberate snaps, no hitch at a release.
--
-- MOTION METRICS (one table per move, after the speeds). In plain words, so a critic can quote them:
--   chain    For root > chest > (neck) > head and root > tail > ... : how many frames each link's
--            turning speed peaks after the link before it, in the release (the windup's end to
--            RELEASE_AFTER s later; a loop: the cross-correlation lag over the loop, after 0.3 s). "+0f" on
--            every link = the body turns as one block: stiff. +1..+4f per link = overlap (the head
--            lags then whips). A negative lag = the child leads its parent (fine for a tail flick,
--            odd for a head). "~" = that link barely turns (peak under CHAIN_MIN deg/s): no reading.
--   stop     A hero point drops more than STOP_DROP (80%) of its speed in one frame and stays under
--            STOP_REST (20%) of its peak for STOP_FRAMES+ frames before the clip ends: it stops dead
--            instead of settling (the hitch, below, is a dead frame that speeds up again; a frame that
--            is a hitch is not also a stop). In a windup this is often the hold: a hold should still
--            ease in, so a one-frame drop into it reads as a stop too.
--   antic    How far (studs) the root and the hero point move AGAINST the release direction in the
--            last ANTIC_TAIL (30%) of the windup (the release direction: where they go in the
--            ANTIC_PROBE s after the windup's end); in brackets, the same over the whole windup.
--            Under ANTIC_MIN = "none": no anticipation, the strike comes out of nowhere.
--   landing  For a move with a flight (dash): how far the root dips (studs) in the LAND_WINDOW s after
--            touchdown, and how many frames after it bottoms out. "no dip" = the body lands stiff.
-- The older lines stay: hitches, the worst joint step, lows, root travel.
local STOP_DROP, STOP_REST, STOP_FRAMES, STOP_MIN = 0.8, 0.2, 2, 20 -- STOP_MIN: studs/s before the drop
local RELEASE_BEFORE, RELEASE_AFTER = 0.1, 0.5 -- the release window around the windup's end, s
local CHAIN_MIN = 40 -- deg/s: a link turning slower than this at its peak gives no reading
local LOOP_MAX_LAG = 8 -- frames searched each way for a loop's chain lag
local ANTIC_TAIL, ANTIC_PROBE, ANTIC_MIN = 0.3, 0.15, 0.05
local LAND_WINDOW = 0.35
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
-- `setup(M, template)`: a module that reads its rig first (NineTailFox.configure) gets it here
if cfg.setup then
	cfg.setup(M, template)
end
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
	local lo, who, at = math.huge, "", Vector3.zero
	for _, p in parts do
		local cf = world[p]
		if cf and p.Transparency < 1 then
			local s = p.Size / 2
			local ext = math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z
			if cf.Y - ext < lo then
				lo, who, at = cf.Y - ext, p.Name, Vector3.new(cf.X, cf.Y - ext, cf.Z)
			end
		end
	end
	return lo, who, at
end

-- the chains the lag metric reads: part names root first (`chains` overrides, e.g.
-- { body = { "Hips", "Chest", "Skull" }, tail = { "Hips", "Tail", "Tail5", "Tail5Mid" } })
local function motorPart(name)
	for _, m in motors do
		if m.Name == name then
			return m.Part1
		end
	end
	return nil
end
local rootPart = motorPart("JointRoot") or motorPart("RootJoint") or hrp
local chainNames, chains = {}, {}
do
	local specs = cfg.chains
	if not specs then
		specs = {}
		local body = { rootPart.Name }
		for _, group in { { "JointSpine", "JointChest", "JointWaist" }, { "JointNeck" }, { "JointHead", "Neck" } } do
			for _, n in group do
				local p = motorPart(n)
				if p and p ~= rootPart then
					table.insert(body, p.Name)
					break
				end
			end
		end
		if #body > 1 then
			specs.body = body
		end
		local tailPart = motorPart("JointTail") or motorPart("JointTail1")
		if tailPart then
			local tail = { rootPart.Name, tailPart.Name }
			local at = tailPart
			while #tail < 5 do
				local kids = {}
				for _, m in motors do
					if m.Part0 == at and string.find(m.Part1.Name, "Tail") then
						table.insert(kids, m.Part1)
					end
				end
				if #kids == 0 then
					break
				end
				table.sort(kids, function(a, b)
					return a.Name < b.Name
				end)
				at = kids[math.ceil(#kids / 2)] -- a fan of tails: the middle one
				table.insert(tail, at.Name)
			end
			specs.tail = tail
		end
	end
	for key, names in specs do
		local list = {}
		for _, n in names do
			local found
			for _, p in template:GetDescendants() do
				if p:IsA("BasePart") and p.Name == n then
					found = p
					break
				end
			end
			assert(found, "no chain part " .. n)
			table.insert(list, found)
		end
		chains[key] = list
		table.insert(chainNames, key)
	end
	table.sort(chainNames)
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
local restRoot = restWorld[rootPart]

local function attackOf(name)
	if def.attack and def.attack.name == name then
		return def.attack
	end
	-- a regular beast's pool, a boss's pattern and phase calls, and the arrive follow-ups they carry
	local pools = { def.pattern or {}, def.attacks or {}, def.phaseCalls or {} }
	for _, pool in pools do
		for _, a in pool do
			if a.name == name then
				return a
			end
			if type(a.arrive) == "table" and a.arrive.name == name then
				return a.arrive
			end
		end
	end
	if def.attack and type(def.attack.arrive) == "table" and def.attack.arrive.name == name then
		return def.attack.arrive
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
	if spec.loop then
		-- a steady-speed loop: the phase advances by gaitRate as EnemyAnimator's loopPose does
		local speed = spec.speed or 6
		local rate = if M.gaitRate then M.gaitRate(spec.loop, speed, scale) else 1
		table.insert(states, { spec.loop, spec.seconds or 2, function(since)
			return M.loops[spec.loop](since * rate, speed, withInput(spec, { seed = 0, dir = 1 }))
		end, nil, true })
		return states
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
			local keyed = target ~= nil and st ~= "idle" and not s[5]
			if st ~= lastState then
				local prev = lastState
				lastState = st
				-- seamlessStrike (EnemyAnimator's flag): only a stationary windup -> recover runs on
				local within = ((seamless and (st == "dash" or st == "recover"))
					or (cfg.seamlessStrike and st == "recover" and prev == "windup")) and wasKeyed
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
			local rootCF = w[rootPart]
			local lo, who, lowAt = lowest(w)
			local up = if lift then lift(tt) else 0
			lo += up
			local rots = {}
			for _, key in chainNames do
				local r = {}
				for j, p in chains[key] do
					r[j] = w[p] or CFrame.identity
				end
				rots[key] = r
			end
			table.insert(frames, { t = T + tt, st = st, pts = pts, jd = worst, jn = wn, lo = lo - restLow, low = who, lowAt = lowAt, lift = up,
				root = rootCF and rootCF.Position, rots = rots, pose = if cfg.keep then current else nil })
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
		table.insert(bounds, string.format("%s->%.3f", s[1], acc))
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
	local label = spec.label or (spec.loop and string.format("%s@%g", spec.loop, spec.speed or 6)) or ((if spec.chain then table.concat(spec.chain, ">") else spec.attack) .. (if spec.next then ">" .. spec.next else "") .. (if spec.skid then ">" .. spec.skid else "") .. (if spec.input and spec.input.mode then "[" .. spec.input.mode .. "]" else ""))
	say("== %s [%s]", label, table.concat(bounds, " "))
	say("   worst joint step %.1f deg at %.2f (%s); lowest %+.2f (%s at %.2f)..%+.2f vs rest; root moves <= %.1f", popMax, popT, popN, loMin, loWho, loT, loMax, rootMax)
	local res = { label = label, worst = popMax, worstAt = popT, worstJoint = popN, low = loMin, high = loMax, heroes = {}, hitches = {}, marks = {}, frames = frames, states = {} }
	local speeds = {}
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
				table.insert(res.marks, { i = i, hero = key, kind = "hitch" })
			end
		end
		res.heroes[key] = { peak = peak, at = peakT }
		speeds[key] = spd
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
	if cfg.steps then
		-- every frame whose worst joint step is over stepLimit deg (a flip shows as one big frame)
		local ls = {}
		for i = 2, #frames do
			local f = frames[i]
			if f.jd > (cfg.stepLimit or 25) then
				table.insert(ls, string.format("%.2f %s %.0f %s", f.t, f.st, f.jd, f.jn))
			end
		end
		say("     big steps: %s", if #ls > 0 then table.concat(ls, ", ") else "none")
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

	-- MOTION METRICS (thresholds and meanings in the header)
	local acc2 = 0
	local wS, wE, cS, cE, loopState
	local dashEnds = {}
	for _, s in states do
		local s0, s1 = acc2, acc2 + s[2]
		acc2 = s1
		table.insert(res.states, { name = s[1], from = s0, to = s1 })
		if s[1] ~= "idle" then
			cS = cS or s0
			cE = s1
		end
		if s[1] == "windup" and not wS then
			wS, wE = s0, s1
		end
		if s[1] == "dash" then
			table.insert(dashEnds, s1)
		end
		if s[5] then
			loopState = { s0, s1 }
		end
	end
	res.clipFrom, res.clipTo, res.windupFrom, res.windupTo = cS or 0, cE or acc2, wS, wE
	local function frameAt(t)
		local best, bd = 1, math.huge
		for i, f in frames do
			local d = math.abs(f.t - t)
			if d < bd then
				best, bd = i, d
			end
		end
		return best
	end
	say("   -- metrics")
	-- chain lag
	local winA, winB
	if loopState then
		-- skip the hand-off from idle (the loop smoothing settling in)
		winA, winB = frameAt(math.min(loopState[1] + 0.3, loopState[2] - 0.5)), frameAt(loopState[2] - dt)
	elseif wE then
		winA, winB = frameAt(wE - RELEASE_BEFORE), frameAt(math.min(wE + RELEASE_AFTER, cE or wE))
	else
		winA, winB = frameAt(cS or 0), frameAt((cE or acc2) - dt)
	end
	res.chains = {}
	for _, key in chainNames do
		local links = chains[key]
		local ang = {}
		for j = 1, #links do
			ang[j] = {}
			for i = 2, #frames do
				ang[j][i] = rotDeg(frames[i - 1].rots[key][j], frames[i].rots[key][j]) / dt
			end
			ang[j][1] = ang[j][2] or 0
		end
		local peaks, peakAt = {}, {}
		for j = 1, #links do
			local pk, at = 0, winA
			for i = math.max(2, winA), winB do
				if ang[j][i] > pk then
					pk, at = ang[j][i], i
				end
			end
			peaks[j], peakAt[j] = pk, at
		end
		local cells, lags, still = {}, {}, true
		for j = 2, #links do
			local lag
			if peaks[j] < CHAIN_MIN or peaks[j - 1] < CHAIN_MIN then
				lag = nil
			elseif loopState then
				-- cross-correlation of the mean-removed turning speeds
				local function mean(a)
					local sum, n = 0, 0
					for i = winA, winB do
						sum += a[i]
						n += 1
					end
					return sum / math.max(1, n)
				end
				local ma, mb = mean(ang[j - 1]), mean(ang[j])
				local bestL, bestV = 0, -math.huge
				for L = -LOOP_MAX_LAG, LOOP_MAX_LAG do
					local v = 0
					for i = winA, winB do
						local k = i + L
						if k >= winA and k <= winB then
							v += (ang[j - 1][i] - ma) * (ang[j][k] - mb)
						end
					end
					if v > bestV then
						bestL, bestV = L, v
					end
				end
				lag = bestL
			else
				lag = peakAt[j] - peakAt[j - 1]
			end
			if lag and lag ~= 0 then
				still = false
			end
			lags[j - 1] = lag
			table.insert(cells, string.format("%s>%s %s", links[j - 1].Name, links[j].Name, if lag then string.format("%+df", lag) else "~"))
		end
		local pk = {}
		for j = 1, #links do
			table.insert(pk, string.format("%.0f", peaks[j]))
		end
		local anyLag = false
		for _, l in lags do
			anyLag = true
		end
		res.chains[key] = { lags = lags, peaks = peaks }
		say("   chain %-5s %s  (peak deg/s %s)%s", key, table.concat(cells, "  "), table.concat(pk, "/"),
			if anyLag and still then "  ONE BLOCK" else "")
	end
	-- stops dead
	local stopCells = {}
	res.stops = {}
	local endI = frameAt((cE or acc2) - dt)
	for _, key in heroNames do
		local spd, peak = speeds[key], res.heroes[key].peak
		local found = {}
		local i = math.max(3, frameAt(cS or 0))
		while i <= endI - STOP_FRAMES do
			local a, b = spd[i - 1], spd[i]
			local isHitch = false
			for _, m in res.marks do
				if m.kind == "hitch" and m.hero == key and m.i == i then
					isHitch = true
				end
			end
			if a and b and a >= STOP_MIN and b < (1 - STOP_DROP) * a and not isHitch then
				local n = 0
				while i + n <= endI and spd[i + n] and spd[i + n] < STOP_REST * peak do
					n += 1
				end
				if n >= STOP_FRAMES then
					table.insert(found, string.format("%.2f %s %d>%d (%df)", frames[i].t, frames[i].st, math.floor(a), math.floor(b), n))
					table.insert(res.stops, { i = i, hero = key, frames = n })
					table.insert(res.marks, { i = i, hero = key, kind = "stop" })
					i += n
				end
			end
			i += 1
		end
		table.insert(stopCells, key .. " " .. (if #found > 0 then "STOP " .. table.concat(found, ", ") else "none"))
	end
	say("   stop  %s", table.concat(stopCells, " | "))
	-- anticipation
	if wE and not loopState then
		local key = cfg.hero or heroNames[1]
		local iS, iT, iE = frameAt(wS), frameAt(wE - ANTIC_TAIL * (wE - wS)), frameAt(wE)
		local iR = frameAt(math.min(wE + ANTIC_PROBE, acc2 - dt))
		local cells = {}
		res.antic = {}
		for _, who in { "root", key } do
			local function pos(i)
				return if who == "root" then frames[i].root else frames[i].pts[who]
			end
			local d = pos(iR) - pos(iE)
			if d.Magnitude < 0.05 then
				table.insert(cells, who .. " ~ (still at the release)")
			else
				d = d.Unit
				local function back(from)
					local b = 0
					for i = from, iE do
						b = math.max(b, -(pos(i) - pos(from)):Dot(d))
					end
					return b
				end
				local tail, whole = back(iT), back(iS)
				res.antic[who] = { tail = tail, whole = whole }
				table.insert(cells, string.format("%s %s (whole %.2f)", who, if tail < ANTIC_MIN then "none" else string.format("%.2f st back", tail), whole))
			end
		end
		say("   antic %s", table.concat(cells, " | "))
	end
	-- landing compress
	for _, te in dashEnds do
		local i0 = frameAt(te)
		local i1 = frameAt(math.min(te + LAND_WINDOW, acc2 - dt))
		local y0 = frames[i0].root and frames[i0].root.Y
		local lo, at = y0, i0
		for i = i0, i1 do
			if frames[i].root and frames[i].root.Y < lo then
				lo, at = frames[i].root.Y, i
			end
		end
		local dip = (y0 or 0) - (lo or 0)
		res.landing = res.landing or {}
		table.insert(res.landing, { at = te, dip = dip, frames = at - i0 })
		say("   land  touchdown %.2f: %s", te, if dip < 0.05 then "no dip (lands stiff)" else string.format("root dips %.2f st, bottom +%df", dip, at - i0))
	end
	if not cfg.keep then
		res.frames = nil
	end
	table.insert(results, res)
end
_G.MOTION_RESULTS = results
-- the FK the probe measures with (tools/anim_filmstrip.luau poses its clones from it)
_G.MOTION_FK = { fk = fk, template = template, restLow = restLow, heroes = heroes }
return table.concat(out, "\n")
