--!strict
-- Jade Jiao: the jade python with a cobra hood, 37 joints (art/enemies/beasts/RIGS.md
-- "Jade Jiao"). Same pose API as WolfKing.luau; pure tables, no instances and no gameplay
-- decisions.
--
-- UNITS: real studs in model space (the rebuilt body, commit 33c253a; SCALE = 1). The body
-- RESTS COILED (the reference's look): every tail bone has its own rest heading, and
-- Serpent.luau composes each segment's absolute orientation with it.
--
-- Attack       Move         windup / active / pose recover    server recover
-- emerge       Emerge         2.20 / 0.10 / 0.50                   0.60
-- venomFang    VenomFang      0.75 / 0.12 / 0.78                   0.90
-- tailSweep    TailSweep      0.80 / 0.14 / 0.86                   1.00
-- pillarSlam   PillarSlam     1.00 / 0.15 / 1.15                   1.30
-- fangFlurry   FangFlurry     0.90 / 1.00 / 1.10                   2.10  (lunges at active u 0, .4, 1)
-- mireDive     MireDive       0.80 / dash<=0.75 / 0.10             0.10
-- erupt        Erupt          0.85 / 0.15 / 0.95                   1.10
-- venomLance   VenomLance     0.70 / 0.10 / 0.70                   0.80
-- venomSpray   VenomSpray     1.00 / 0.12 / 1.08                   1.20
-- venomPools   VenomPools     1.00 / 0.10 / 0.80                   0.90
-- jiaoCoil     JiaoCoil       1.50 / dash 0.45 / 4.40 (P3 3.80)    same (hold 3.0 / P3 2.6, unwind rest)
-- dreadHiss    DreadHiss      1.10 / 0.10 / 0.80                   0.90
-- molt         Molt           1.60 / 0.10 / 0.80                   0.90
-- ascension    Ascension      2.00 / 0.10 / 0.90                   1.00
-- venomRain    VenomRain      2.00 / 0.20 / 4.80 (rain 2.6, tail 0.9, exhaustion 1.3)   5.00
-- tailShove    TailShove      0.70 / 0.14 / 0.66                   0.80 (ends reared, ready to spit)
-- Stagger 0.4, Death 3.6. Contact is the END of windup for stationary attacks.
--
-- A pose is built from a STANCE (a flat table of numbers keyed per phase and lerped) by
-- compose(): the neck's elevations e1..e6 and headings y1..y6 (absolute, see Serpent.luau),
-- the Body's lift/translation, the head roll, jaw, fangs, hood, tongue, and the tail's heading
-- bend `ty`, rear `tup`, agitation `tamp`, plus the ring coil `ring`/`tight`/`arch`.
-- The spine under every stance lies on the slither curve (Serpent.curve) at the wave phase
-- EnemyAnimator keeps (input.wavePhase), so a move starts from the S the snake stopped in.
-- Neck shapes in the move tables are authored as six numbers per the old 5-bone layout and
-- remapped by st() (E / Y); `N` gives new-layout elevations directly.

local Serpent = require(script.Parent.Serpent)

export type Pose = Serpent.Pose
export type Input = {
	duration: number?,
	side: number?,
	targetYaw: number?,
	dir: number?,
	seed: number?,
	phase: number?, -- boss phase 1-3 (Phase attribute)
	speed: number?, -- real studs/s
	turn: number?, -- travel yaw rate rad/s
	yawAt: ((number) -> number)?, -- travel heading secondsAgo
	time: number?, -- a clock for ambient motion (os.clock)
	radius: number?, -- CoilRadius in real studs (default COIL_RADIUS)
	wavePhase: number?, -- the slither wave's phase (EnemyAnimator advances it with the distance moved)
	still: number?, -- seconds the body has been still (0 while moving)
	travel: number?, -- studs moved since it last started moving (0 while still)
	rested: number?, -- how long it was still before it started moving (its coil level)
}
type Stance = { [string]: number }
type Key = { t: number, s: Stance, ease: string? }
type Phase = { duration: number, keys: { Key }?, fn: ((u: number, secs: number, input: Input) -> Stance)?, tremble: ((u: number) -> number)?, settle: number?, hold: boolean? }

local JadeJiao = {}
local V = Vector3.new
local TAU = Serpent.TAU
local smooth, EASE = Serpent.smooth, Serpent.EASE
local D = math.rad
local I = CFrame.identity
local SCALE = 1
JadeJiao.SCALE = SCALE
local RK = 1.1 -- stance root translations (rx, ry, rz) were authored for the old body: x 1.1 studs
local WAVELENGTH = 30 -- arc studs between crests at a walk (about half the 55-stud ground spine)
JadeJiao.WAVELENGTH = WAVELENGTH
local COIL_R = 11.9 -- real studs: the Body and the whole tail round a 280-degree ring
JadeJiao.COIL_RADIUS = COIL_R
JadeJiao.COIL_ARC = { D(280), D(300) } -- by boss phase
local _ = I

--------------------------------------------------------------------------------
-- Skeleton (RIGS.md, real studs)

local NECK = { "JointNeck", "JointNeck2", "JointNeck3", "JointNeck4", "JointNeck5", "JointHead" }
local TAIL = { "JointTail" }
for i = 2, 18 do
	TAIL[i] = "JointTail" .. i
end

JadeJiao.JOINTS = { "JointRoot" }
for _, n in NECK do
	table.insert(JadeJiao.JOINTS, n)
end
for _, n in { "JointJaw", "JointFangL", "JointFangR", "JointHoodL", "JointHoodR", "JointBarbelL1", "JointBarbelL2",
	"JointBarbelR1", "JointBarbelR2", "JointTongue", "JointTongueTipL", "JointTongueTipR" } do
	table.insert(JadeJiao.JOINTS, n)
end
for _, n in TAIL do
	table.insert(JadeJiao.JOINTS, n)
end

local P: { [string]: Vector3 } = {
	JointRoot = V(3.02, 3.25, -1.43),
	JointNeck = V(0, 3.33, -4.13), JointNeck2 = V(0, 5.32, -6.83), JointNeck3 = V(0, 7.30, -9.52),
	JointNeck4 = V(0, 11.11, -5.87), JointNeck5 = V(0, 13.81, -9.37), JointHead = V(0, 14.60, -11.59),
}
local TAIL_P = {
	V(6.03, 3.17, 1.27), V(7.30, 3.10, 4.44), V(8.57, 3.02, 7.62), V(6.98, 2.94, 10.63), V(5.40, 2.86, 13.65),
	V(2.96, 2.77, 14.39), V(0.53, 2.69, 15.13), V(-1.90, 2.60, 15.87), V(-4.02, 2.50, 14.81), V(-6.14, 2.39, 13.76),
	V(-8.25, 2.29, 12.70), V(-8.89, 2.16, 10.58), V(-9.52, 2.03, 8.47), V(-10.16, 1.90, 6.35), V(-9.63, 1.78, 4.23),
	V(-9.10, 1.65, 2.12), V(-8.57, 1.52, 0.00), V(-6.98, 1.33, -2.38),
}
local parent: { [string]: string } = {
	JointNeck = "JointRoot", JointNeck2 = "JointNeck", JointNeck3 = "JointNeck2", JointNeck4 = "JointNeck3",
	JointNeck5 = "JointNeck4", JointHead = "JointNeck5", JointTail = "JointRoot",
}
for i = 1, 18 do
	P[TAIL[i]] = TAIL_P[i]
	if i > 1 then
		parent[TAIL[i]] = TAIL[i - 1]
	end
end
JadeJiao.PIVOTS = P
JadeJiao.PARENT = parent
local HRP_Z = 5.65

local solver = Serpent.new({
	P = P, root = "JointRoot", neck = NECK, tail = TAIL, tailEnd = V(-5.38, 1.14, -4.77),
	mouth = V(0, 13.12, -18.51), hrpZ = HRP_Z,
})
JadeJiao.solver = solver
local NT = #TAIL

--------------------------------------------------------------------------------
-- Slither parameters (by ground speed)

-- heading amplitude (rad) and wavelength (arc studs): a deep S at a creep and walk, a little
-- flatter and longer at a run
local function slitherParams(speed: number): (number, number)
	local f = smooth(6, 21, speed)
	return 0.9 - 0.18 * f, WAVELENGTH + 4 * f
end
JadeJiao.slitherParams = slitherParams
local TH_STANCE = 0.9 -- the S held under attack stances (the walk's, so a move starts where the walk stopped)

-- coil level from the seconds spent still
local function coilLevel(seconds: number): number
	return smooth(1.2, 4.5, seconds)
end

--------------------------------------------------------------------------------
-- Stances

local REST_E = {}
for j = 1, 6 do
	REST_E[j] = solver.eps[j]
end
local ENAME, YNAME = {}, {}
for j = 1, 6 do
	ENAME[j], YNAME[j] = "e" .. j, "y" .. j
end

local DEF: Stance = {
	bp = 0, ry = 0, rx = 0, rz = 0, ryaw = 0, rroll = 0,
	hr = 0, jaw = 0, fang = 0, hood = 0, tongue = 0, throat = 0,
	ty = 0, tup = 0, tamp = 0.35, ring = 0, tight = 0, arch = 0,
}
for j = 1, 6 do
	DEF[ENAME[j]] = REST_E[j]
	DEF[YNAME[j]] = 0
end
local KEYS: { string } = {}
for k in DEF do
	table.insert(KEYS, k)
end

-- the old neck layout (5 bones + skull) onto the new one: the old first bone is the new first
-- two, the old 4th and 5th merge into the new 5th
local function remap(v: { number }): { number }
	return { v[1], v[1], v[2], v[3], (v[4] * 3.73 + v[5] * 2.75) / 6.48, v[6] }
end

-- a stance from a base and changes: E = { six elevations, degrees, old layout }, Y = { six
-- headings, rad, old layout }, N = { six elevations, degrees, new layout }
local function st(base: Stance, c: { [string]: any }?): Stance
	local out = table.clone(base)
	if c then
		for k, v in c do
			if k == "E" or k == "N" then
				local e = if k == "E" then remap(v :: any) else v :: any
				for j = 1, 6 do
					out[ENAME[j]] = D(e[j])
				end
			elseif k == "Y" then
				local y = remap(v :: any)
				for j = 1, 6 do
					out[YNAME[j]] = y[j]
				end
			else
				out[k] = v
			end
		end
	end
	return out
end

local function lerpStance(a: Stance, b: Stance, t: number): Stance
	local out = {}
	for _, k in KEYS do
		local x, y = a[k], b[k]
		out[k] = x + (y - x) * t
	end
	return out
end

local function keyed(keys: { Key }, u: number): Stance
	u = math.clamp(u, 0, 1)
	local n = #keys
	if u <= keys[1].t then
		return keys[1].s
	end
	for i = 2, n do
		local b = keys[i]
		if u <= b.t then
			local a = keys[i - 1]
			local f = (u - a.t) / math.max(1e-6, b.t - a.t)
			local ease = EASE[b.ease or "inOut"] or EASE.inOut
			return lerpStance(a.s, b.s, ease(f))
		end
	end
	return keys[n].s
end

local IDLE = st(DEF, { tamp = 0.35 })
-- neck shapes (degrees above horizontal, per segment, skull last; old layout, remapped)
local COL = { 80, 100, 92, 85, 72, 15 }
local DRAW = { 55, 140, 62, 40, 22, -16 }
local STRIKE = { 30, 45, 22, 12, 0, -18 }
local OVER = { 24, 38, 16, 6, -4, -22 }
local SLAM = { 20, 125, 30, -20, -55, -70 }
local ROAR = { 82, 105, 98, 92, 85, 40 }
local SINK = { -8, -18, -22, -26, -26, -22 }
local LBACK = { 75, 125, 90, 70, 60, 30 }
local LFWD = { 30, 40, 25, 15, 5, 0 }
local RAINE = { 85, 100, 95, 92, 88, 55 }
local DROOP = { 25, 70, 30, 10, -5, -25 }
local LIMP = { 8, 10, 3, -1, -5, -4 }
-- locomotion necks (new layout): a lowered S at a walk, low and forward at a run
local WALK_N = { 14, 24, 75, 26, 8, -2 }
local RUN_N = { 6, 12, 45, 18, 4, -4 }
local RING_E = { 45, 45, 75, 40, 18, -60 } -- new layout
local RING_W = { 0.3, 0.4, 0.6, 0.85, 1, 1 }

local SINK_Y = -6

--------------------------------------------------------------------------------
-- Compose a pose from stance samples

local LAGS = { 0, 0.06, 0.12, 0.2 }
local NECK_LAG = { 0, 0.02, 0.04, 0.07, 0.10, 0.14 }
local function at(samples: { Stance }, name: string, lag: number): number
	if lag <= 0 then
		return samples[1][name]
	end
	for i = 2, 4 do
		if lag <= LAGS[i] then
			local a = (lag - LAGS[i - 1]) / (LAGS[i] - LAGS[i - 1])
			local x, y = samples[i - 1][name], samples[i][name]
			return x + (y - x) * a
		end
	end
	return samples[4][name]
end

local hash = function(n: number, seed: number): number
	local x = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	return x - math.floor(x)
end

type Ctx = {
	secs: number, -- ambient clock
	wavePhase: number,
	th0: number, -- slither heading amplitude (rad)
	wavelength: number,
	yawAt: ((number) -> number)?,
	speed: number,
	turn: number,
	phase: number, -- boss phase
	radius: number, -- coil radius, real studs
	arcs: number,
	seed: number,
	look: number?, -- head aim yaw (rad, + left)
	neckPath: number?, -- 0..1: the lower neck follows the path (loops)
	restW: ((i: number) -> number)?, -- per bone (0 = body, 1..18 tail): weight of the rest coil
}

local HOOD_BASE = { 0, 0.3, 0.55 }
local NECK_PATH_W = { 1, 0.6, 0.2, 0, 0, 0 }
local NECK_PATH_S = { -1.5, -4.5, -8, 0, 0, 0 }
local CENTRE_W = { 0, 0.25, 0.8, 1, 1, 0 }

local function compose(samples: { Stance }, ctx: Ctx): Pose
	local S0 = samples[1]
	local pose: Pose = {}
	local t = ctx.secs

	-- the spine's ground curve, frozen in a stance or sliding in a loop
	local c = solver.curve(ctx.wavePhase, ctx.th0, ctx.wavelength)
	local front0 = P.JointNeck
	local pYaw, pPivot, pH = solver.lay(c, front0)
	local follow: { [number]: number } = {}
	if ctx.yawAt and ctx.speed > 1 then
		solver.follow(ctx.yawAt, ctx.speed, ctx.turn, follow)
	end
	local restW = ctx.restW
	local wb = if restW then restW(0) else 0
	local bodyYaw = (pYaw + (follow[0] or 0)) * (1 - wb) + solver.bodyRestYaw * wb
	local pivot = pPivot:Lerp(solver.Pr, wb)

	-- the ring coil
	local ringA = S0.ring
	local ring: any = nil
	local Rr = ctx.radius * (1 - 0.12 * S0.tight)
	if ringA > 0.001 then
		ring = solver.ring(Rr, ctx.arcs, ringA)
	end
	local ringBlend = smooth(0, 0.08, ringA)
	if ring then
		bodyYaw += (ring.bodyYaw - bodyYaw) * ringBlend
		pivot = pivot:Lerp(ring.pivot, ringBlend)
	end
	bodyYaw += S0.ryaw

	-- lift the front (bp) about the rear end, then the stance's own shift
	local bp = S0.bp
	local Rb0 = solver.bodyRot(bodyYaw, 0)
	local Rb = solver.bodyRot(bodyYaw, bp, S0.rroll)
	pivot += Rb0 * solver.rearRel - Rb * solver.rearRel
	local shift = V(S0.rx, S0.ry, S0.rz) * RK
	pivot += shift
	pose.JointRoot = solver.rootTransform(Rb, pivot)
	local base = solver.bodyEnds(Rb, pivot)

	-- Neck
	local E, Y = table.create(6), table.create(6)
	for j = 1, 6 do
		local lag = NECK_LAG[j]
		E[j] = at(samples, ENAME[j], lag)
		Y[j] = at(samples, YNAME[j], lag) + S0.ryaw + (if ctx.look then ctx.look * math.min(1, j * 0.25) else 0)
	end
	local np = ctx.neckPath or 0
	if np > 0 then
		-- the lower neck runs on along the path the body will take
		for j = 1, 3 do
			Y[j] += np * NECK_PATH_W[j] * c.theta(NECK_PATH_S[j])
		end
	end
	local neckBlend = smooth(0.15, 0.7, ringA)
	if neckBlend < 1 then
		-- keep the head on the lane: cancel the neck base's sideways offset (the S under it)
		local ref = solver.headAt(E, Y, V(shift.X, base.Y, base.Z))
		local Yc = solver.centre(E, Y, base, ref.X, CENTRE_W)
		for j = 1, 6 do
			Y[j] = Yc[j]
		end
	end
	if ring and neckBlend > 0 then
		local RE = table.create(6)
		for j = 1, 6 do
			RE[j] = D(RING_E[j])
		end
		local Yr = solver.reach(RE, base, -Rr, HRP_Z, RING_W)
		for j = 1, 6 do
			E[j] += (RE[j] - E[j]) * neckBlend
			Y[j] += (Yr[j] - Y[j]) * neckBlend
		end
	end
	local nl = solver.neckLocals(E, Y, Rb, S0.hr)
	for j = 1, 6 do
		pose[NECK[j]] = nl[j]
	end

	-- Tail
	local Yt, Ut = table.create(NT), table.create(NT)
	local used = 0
	if ring then
		used = ring.used - 1
	end
	local tailJoin = 0
	local curl = 0.9 * S0.arch
	for k = 1, NT do
		local lag = 0.011 * k
		local ty = at(samples, "ty", lag)
		local up = at(samples, "tup", lag)
		local w = math.min(1, k / 4)
		local wr = if restW then restW(k) else 0
		local yaw = (pH[k] + (follow[k] or 0)) * (1 - wr) + solver.restYaw[k] * wr
		local pitch = solver.restUp[k]
		if ring then
			local ringYaw = ring.headings[k]
			local uncovered = k > used
			local a = S0.arch
			if uncovered and a > 0 then
				-- the free tail rises as a rattling arch on the ring's end, curling outward
				tailJoin += 1
				local m = math.max(1, NT - used)
				local x = (tailJoin - 0.5) / m
				curl += solver.len[k] / 6.5
				pitch += a * 0.33 * math.sin(math.pi * x) ^ 0.8
				ringYaw += a * curl
				ringYaw += a * 0.05 * math.sin(t * 31 + k * 1.7)
			end
			yaw += (ringYaw - yaw) * ringBlend
		end
		-- the stance's bend and rear, and agitation toward the tip
		yaw += ty * w + S0.ryaw
		local f = (k - 1) / (NT - 1)
		yaw += S0.tamp * 0.22 * smooth(0.3, 1, f) * math.sin(t * 4.2 - k * 0.55 + ctx.seed)
		pitch += up * math.sin(math.pi * math.min(1, k / 12))
		Yt[k], Ut[k] = yaw, pitch
	end
	local tl = solver.tailLocals(Yt, Ut, Rb)
	for k = 1, NT do
		pose[TAIL[k]] = tl[k]
	end

	-- Head parts
	local jaw = math.clamp(at(samples, "jaw", 0.14), 0, 1.2)
	pose.JointJaw = CFrame.Angles(-0.95 * jaw, 0, 0)
	local fang = math.min(math.clamp(at(samples, "fang", 0.14), 0, 1), math.max(0.0, jaw * 1.3))
	pose.JointFangL = CFrame.Angles(1.45 * fang, 0, 0)
	pose.JointFangR = CFrame.Angles(1.45 * fang, 0, 0)
	local hb = HOOD_BASE[math.clamp(ctx.phase, 1, 3)]
	local flare = hb + (1 - hb) * math.clamp(at(samples, "hood", 0.06), 0, 1)
	local quiver = 0.025 * math.sin(t * 7.3) * flare
	pose.JointHoodL = CFrame.Angles(0, -(1.2 * flare + quiver), 0)
	pose.JointHoodR = CFrame.Angles(0, 1.2 * flare + quiver, 0)
	-- the tongue flicks on a hashed beat, always when the jaw is open
	local beat = math.floor(t * 0.62 + ctx.seed)
	local flick = math.max(0, math.sin((t * 0.62 + ctx.seed - beat) * math.pi * 6)) * (if hash(beat, ctx.seed) > 0.35 then 1 else 0)
	local tongue = math.max(at(samples, "tongue", 0.1), flick * 0.8)
	pose.JointTongue = CFrame.Angles(-0.35 * tongue, 0.12 * math.sin(t * 17) * tongue, 0)
	pose.JointTongueTipL = CFrame.Angles(0, 0.4 - 0.25 * tongue, 0)
	pose.JointTongueTipR = CFrame.Angles(0, -(0.4 - 0.25 * tongue), 0)
	-- whiskers trail the head
	local sway = 0.18 * math.sin(t * 2.3) + 0.35 * math.clamp((ctx.speed or 0) / 21, 0, 1)
	pose.JointBarbelL1 = CFrame.Angles(0, -0.2 - sway * 0.6, 0)
	pose.JointBarbelR1 = CFrame.Angles(0, 0.2 + sway * 0.6, 0)
	pose.JointBarbelL2 = CFrame.Angles(0, -0.25 * math.sin(t * 3.1 + 1), 0)
	pose.JointBarbelR2 = CFrame.Angles(0, 0.25 * math.sin(t * 3.3 + 2), 0)
	return pose
end

local function same(s: Stance): { Stance }
	return { s, s, s, s }
end

--------------------------------------------------------------------------------
-- Moves

local moves: { [string]: { [string]: Phase } } = {}
local function ph(duration: number, keys: { Key }, tremble: ((u: number) -> number)?, settle: number?): Phase
	return { duration = duration, keys = keys, tremble = tremble, settle = settle }
end
local function k(t: number, s: Stance, ease: string?): Key
	return { t = t, s = s, ease = ease }
end

local function rise(shape: { number }, c: { [string]: any }?): Stance
	return st(IDLE, (function()
		local t: { [string]: any } = { E = shape }
		for kk, v in c or {} do
			t[kk] = v
		end
		return t
	end)())
end

-- 0 until a, rising to 1 by b, falling to 0 over c..d
local function window(u: number, a: number, b: number, c: number, d: number): number
	return smooth(a, b, u) * (1 - smooth(c, d, u))
end

-- VenomFang: A "S-strike": the S pulls back and cocks, the jaw gapes, then the head darts
local FANG_DRAW1 = rise(DRAW, { hood = 0.45, jaw = 0.35, tongue = 1, rz = 1.0, tamp = 0.5 })
local FANG_DRAW2 = rise(DRAW, { hood = 0.65, jaw = 1, fang = 1, hr = 0.35, Y = { 0, 0, 0, 0.1, 0.2, 0.3 }, rz = 1.7, tamp = 0.4, bp = 0.06 })
local FANG_STRIKE = rise(STRIKE, { hood = 0.6, jaw = 0.95, fang = 1, rz = -2.4, hr = 0, tamp = 0.7 })
local FANG_OVER = rise(OVER, { hood = 0.5, jaw = 0.5, fang = 0.8, rz = -3.3, tamp = 0.8 })
local FANG_MID = rise({ 36, 80, 38, 20, 8, -8 }, { hood = 0.2, jaw = 0.1, rz = -1.4, tamp = 0.5 })
moves.VenomFang = {
	windup = ph(0.75, {
		k(0, IDLE), k(0.32, FANG_DRAW1, "inOut"), k(0.55, FANG_DRAW2, "out"), k(0.85, FANG_DRAW2), k(1, FANG_STRIKE, "snap"),
	}, function(u) return window(u, 0.5, 0.6, 0.86, 0.95) end),
	active = ph(0.12, { k(0, FANG_STRIKE), k(1, FANG_OVER, "out") }),
	recover = ph(0.78, { k(0, FANG_OVER), k(0.4, FANG_MID, "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

-- TailSweep: the head dips and turns away, the tail rears on the other side, then the whole
-- tail lashes a full circle (the lag makes it whip from the root outwards)
local SW_DIP = rise({ 28, 62, 26, 10, -6, -38 }, { Y = { -0.15, -0.3, -0.5, -0.6, -0.65, -0.7 }, jaw = 0.25, hood = 0.3, tup = 0.5, ty = -0.8, tamp = 0.5, tongue = 1 })
local SW_WOUND = rise({ 26, 58, 24, 8, -8, -40 }, { Y = { -0.2, -0.4, -0.6, -0.7, -0.75, -0.8 }, jaw = 0.3, hood = 0.35, tup = 1.0, ty = -1.55, tamp = 0.4, ryaw = 0.18, rz = 0.6 })
local SW_LASH = st(SW_WOUND, { ty = -1.55 + TAU, tup = 0.8, ryaw = -0.12, jaw = 0.15, Y = { 0, -0.1, -0.2, -0.25, -0.3, -0.3 }, rz = -0.4 })
local SW_OVER = st(SW_LASH, { ty = -1.55 + TAU + 0.5, tup = 0.5, ryaw = -0.2 })
local SW_REST = st(IDLE, { ty = TAU })
moves.TailSweep = {
	windup = ph(0.8, { k(0, IDLE), k(0.3, SW_DIP, "inOut"), k(0.6, SW_WOUND, "out"), k(0.64, SW_WOUND), k(1, SW_LASH, "in") }, function(u) return window(u, 0.3, 0.45, 0.6, 0.66) end),
	active = ph(0.14, { k(0, SW_LASH), k(1, SW_OVER, "out") }),
	recover = ph(0.86, { k(0, SW_OVER), k(0.35, st(SW_REST, { ty = TAU - 0.05, tup = 0.15 }), "inOut"), k(1, SW_REST, "inOut") }, nil, 1),
}

-- TailShove (boss feel pass): the throw that makes range for the venom. The body hunkers and
-- twists to its right with the neck drawn back into a tight S (the head stays on the target),
-- the tail swings out to its right side and lifts, cocked (tip about 70 degrees round, 11 studs
-- up); then the body unwinds and the tail whips low round to the front-right (tip at 139 degrees
-- at contact = end of windup, 157 after the flick that ends the follow-through: the release),
-- the reared neck leaning left out of its way (measured clear of the neck and Body by forward
-- kinematics, tools/frag probe). The tail recoils the way it came, and
-- the head rears back high, hood up, ready to spit (the AI follows with a ranged attack).
local TS_COIL = rise(DRAW, { hood = 0.7, jaw = 0.4, tongue = 1, rz = 1.2, ry = -0.12, ryaw = -0.32, rroll = 0.03,
	Y = { 0, 0, 0.1, 0.2, 0.3, 0.32 }, ty = 1.0, tup = 0.6, tamp = 0.3 })
local TS_COCK = st(TS_COIL, { rz = 1.5, ry = -0.16, ryaw = -0.42, ty = 1.6, tup = 0.9, jaw = 0.5, hood = 0.8,
	Y = { 0, 0, 0.12, 0.24, 0.36, 0.4 } })
local TS_WHIP = rise(LBACK, { hood = 0.8, jaw = 0.6, fang = 0.6, rz = 1.6, ry = -0.15, ryaw = 0.3, rroll = -0.04,
	Y = { 0, 0.15, 0.3, 0.4, 0.45, 0.25 }, ty = 2.6, tup = 0.25, tamp = 0.6 })
local TS_FLICK = st(TS_WHIP, { ryaw = 0.36, ty = 2.85, tup = 0.45, tamp = 0.9, jaw = 0.45, Y = { 0, 0.18, 0.36, 0.48, 0.52, 0.3 } })
local TS_RECOIL = rise({ 60, 115, 70, 50, 36, 8 }, { hood = 0.5, jaw = 0.25, rz = 0.9, ryaw = 0.1, ty = 1.4, tup = 0.15, tamp = 0.5 })
local TS_REAR = rise(LBACK, { hood = 0.85, jaw = 0.45, fang = 0.4, rz = 1.5, bp = 0.12, tamp = 0.4, tongue = 1 })
local TS_READY = rise({ 70, 120, 85, 62, 50, 22 }, { hood = 0.6, jaw = 0.2, rz = 1.0, bp = 0.08, tamp = 0.35 })
moves.TailShove = {
	windup = ph(0.7, { k(0, IDLE), k(0.4, TS_COIL, "inOut"), k(0.8, TS_COCK, "out"), k(0.88, TS_COCK), k(1, TS_WHIP, "snap") },
		function(u) return window(u, 0.4, 0.5, 0.82, 0.9) end),
	active = ph(0.14, { k(0, TS_WHIP), k(1, TS_FLICK, "out") }),
	recover = ph(0.66, { k(0, TS_FLICK), k(0.3, TS_RECOIL, "inOut"), k(0.55, TS_REAR, "out"), k(0.75, TS_REAR), k(1, TS_READY, "inOut") }, nil, 1.3),
}

-- PillarSlam: rise to about 15, hang and tremble, then the whole column drops head-first and the
-- head stays buried through the recover (the opening)
local SLAM_UP = rise(COL, { bp = 0.32, hood = 0.7, jaw = 0.3, tamp = 0.5, tongue = 1 })
local SLAM_HANG = rise(COL, { bp = 0.36, hood = 0.8, jaw = 0.5, tamp = 0.4, fang = 0.6, E = { 82, 100, 94, 86, 74, 20 } })
local SLAM_HIT = rise(SLAM, { jaw = 0.4, hood = 0.5, tamp = 0.5, rz = -3.4, ry = -0.2 })
local SLAM_BURIED = st(SLAM_HIT, { ry = -0.7, jaw = 0.1, hood = 0.2 })
local SLAM_FREE = rise({ 36, 80, 34, 12, -10, -40 }, { ry = -0.2, hood = 0.1, tamp = 0.5 })
moves.PillarSlam = {
	windup = ph(1.0, { k(0, IDLE), k(0.45, SLAM_UP, "outBack"), k(0.62, SLAM_HANG, "out"), k(0.84, SLAM_HANG), k(1, SLAM_HIT, "in") },
		function(u) return window(u, 0.5, 0.62, 0.86, 0.95) end),
	active = ph(0.15, { k(0, SLAM_HIT), k(1, SLAM_BURIED, "out") }),
	recover = ph(1.15, { k(0, SLAM_BURIED), k(0.7, SLAM_BURIED), k(0.88, SLAM_FREE, "inOut"), k(1, IDLE, "inOut") }, nil, 1.2),
}

-- FangFlurry: coil back with the hood up, then three lunges at active u 0, 0.4, 1.0 (the third bigger)
local FL_COIL = rise(DRAW, { hood = 0.9, jaw = 0.4, fang = 0.6, rz = 1.6, hr = 0.2, tamp = 0.5, bp = 0.1 })
local FL_S1 = rise(STRIKE, { hood = 0.9, jaw = 1, fang = 1, rz = -2.0, tamp = 0.7 })
local FL_PULL = rise({ 50, 125, 56, 34, 16, -12 }, { hood = 0.9, jaw = 0.5, fang = 0.8, rz = 0.6, tamp = 0.5 })
local FL_S2 = st(FL_S1, { rz = -2.2, Y = { 0, 0, 0, 0.1, 0.18, 0.28 } })
local FL_PULL3 = rise(DRAW, { hood = 1, jaw = 0.6, fang = 1, rz = 2.4, hr = 0.15, bp = 0.12, tamp = 0.5 })
local FL_S3 = rise({ 22, 36, 14, 4, -6, -24 }, { hood = 1, jaw = 1, fang = 1, rz = -4.6, tamp = 0.9 })
local FL_SIDE = st(FL_PULL, { Y = { 0, 0, 0, -0.1, -0.2, -0.3 } })
moves.FangFlurry = {
	windup = ph(0.9, { k(0, IDLE), k(0.5, FL_COIL, "inOut"), k(0.82, FL_COIL), k(1, FL_S1, "snap") }, function(u) return window(u, 0.4, 0.55, 0.85, 0.95) end),
	active = ph(1.0, { k(0, FL_S1), k(0.12, FL_PULL, "out"), k(0.3, FL_SIDE, "inOut"), k(0.4, FL_S2, "snap"), k(0.55, FL_PULL, "out"),
		k(0.88, FL_PULL3, "inOut"), k(1, FL_S3, "snap") }),
	recover = ph(1.1, { k(0, FL_S3), k(0.15, st(FL_S3, { rz = -5.2, jaw = 0.7 }), "out"), k(0.55, FL_PULL, "inOut"), k(1, IDLE, "inOut") }, nil, 1.5),
}

-- MireDive: rear, then plunge head-first so the whole body is under the ground by the end of the
-- windup; the dash keeps it sunk with a faint quiver
local DIVE_UP = rise(COL, { bp = 0.3, hood = 0.4, jaw = 0.3, tamp = 0.5 })
local DIVE_SUNK = rise(SINK, { ry = SINK_Y, hood = 0, jaw = 0, tamp = 0.7, bp = 0.1 })
local DIVE_TIP = rise({ 55, 70, 20, -30, -70, -80 }, { ry = -2.5, bp = 0.2, hood = 0.1, tamp = 0.6 })
moves.MireDive = {
	windup = ph(0.8, { k(0, IDLE), k(0.38, DIVE_UP, "out"), k(0.52, DIVE_UP), k(0.74, DIVE_TIP, "in"), k(1, DIVE_SUNK, "out") }, function(u) return window(u, 0.4, 0.5, 0.5, 0.55) end),
	active = ph(0.75, { k(0, DIVE_SUNK), k(1, DIVE_SUNK) }, function(_) return 0.25 end),
	recover = ph(0.1, { k(0, DIVE_SUNK), k(1, DIVE_SUNK) }, function(_) return 0.25 end),
}

-- Erupt: sunk with a mounting tremor, then a burst from -6 to rest in 0.15 s with the head up
local ER_UP = rise(ROAR, { jaw = 1, fang = 1, hood = 1, tamp = 0.8, tongue = 1, bp = 0.28, rz = -1 })
moves.Erupt = {
	windup = ph(0.85, { k(0, DIVE_SUNK), k(1, DIVE_SUNK) }, function(u) return 0.25 + 0.9 * u * u end),
	active = ph(0.15, { k(0, DIVE_SUNK), k(1, ER_UP, "snap") }),
	recover = ph(0.95, { k(0, ER_UP), k(0.3, st(ER_UP, { rz = 0.4, jaw = 0.7, bp = 0.2 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1.6),
}

-- VenomLance: the head rears back, the throat swells and the jaw opens, then it snaps forward
local LN_BACK = rise(LBACK, { hood = 0.8, jaw = 0.5, rz = 1.5, bp = 0.1, tamp = 0.5 })
local LN_HOLD = st(LN_BACK, { jaw = 1, fang = 1, hood = 0.95, throat = 1, E = { 76, 126, 92, 72, 62, 36 } })
local LN_FWD = rise(LFWD, { hood = 0.9, jaw = 1, fang = 1, rz = -2.8, tamp = 0.7 })
local LN_OVER = st(LN_FWD, { rz = -3.4, jaw = 0.4 })
moves.VenomLance = {
	windup = ph(0.7, { k(0, IDLE), k(0.45, LN_BACK, "inOut"), k(0.82, LN_HOLD, "out"), k(1, LN_FWD, "snap") }, function(u) return window(u, 0.5, 0.6, 0.84, 0.95) end),
	active = ph(0.1, { k(0, LN_FWD), k(1, LN_OVER, "out") }),
	recover = ph(0.7, { k(0, LN_OVER), k(0.4, rise({ 40, 80, 40, 20, 8, -5 }, { hood = 0.3, jaw = 0.2, rz = -1.2 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

-- VenomSpray: hood fully flared, the head sweeping across the fan with three throat pulses
local SP_UP = rise(ROAR, { E = { 84, 100, 94, 88, 80, 20 }, bp = 0.3, hood = 1, jaw = 0.4, fang = 1, tamp = 0.4, Y = { 0, 0, 0, 0.1, 0.2, 0.38 } })
local SP_END = st(SP_UP, { Y = { 0, 0, 0, -0.1, -0.2, -0.38 }, jaw = 0.7 })
moves.VenomSpray = {
	windup = {
		duration = 1.0,
		fn = function(u, secs, _)
			local s = keyed({ k(0, IDLE), k(0.38, SP_UP, "outBack"), k(0.5, SP_UP), k(1, SP_END, "inOut") }, u)
			local pulse = 0
			for _, c in { 0.58, 0.76, 0.94 } do
				pulse = math.max(pulse, math.sin(math.clamp((u - (c - 0.07)) / 0.14, 0, 1) * math.pi))
			end
			s = table.clone(s)
			s.jaw += 0.5 * pulse
			s.throat = pulse
			s.fang = 1
			s.e6 -= D(10) * pulse
			return s
		end,
		tremble = function(u) return window(u, 0.4, 0.5, 0.9, 1) * 0.6 end,
	},
	active = ph(0.12, { k(0, SP_END), k(1, st(SP_END, { jaw = 0.4 }), "out") }),
	recover = ph(1.08, { k(0, st(SP_END, { jaw = 0.4 })), k(0.35, st(SP_UP, { hood = 0.5, bp = 0.15, Y = { 0, 0, 0, 0, 0, 0 } }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

-- VenomPools: the head swings back and lobs three times (left, right, centre)
local function lobBack(y: number): Stance
	return rise(LBACK, { hood = 0.8, jaw = 0.6, Y = { 0, 0, 0.1 * y, 0.3 * y, 0.5 * y, 0.6 * y }, rz = 1.2, bp = 0.12, tamp = 0.4 })
end
local function lobOut(y: number): Stance
	return rise({ 40, 60, 40, 30, 22, 14 }, { hood = 0.85, jaw = 1, fang = 0.9, Y = { 0, 0, 0.1 * y, 0.3 * y, 0.45 * y, 0.55 * y }, rz = -1.8, tamp = 0.6 })
end
moves.VenomPools = {
	windup = ph(1.0, { k(0, IDLE), k(0.18, lobBack(1), "inOut"), k(0.34, lobOut(1), "snap"), k(0.46, lobBack(-1), "inOut"), k(0.62, lobOut(-1), "snap"),
		k(0.76, lobBack(0), "inOut"), k(1, lobOut(0), "snap") }, function(u) return 0.2 end),
	active = ph(0.1, { k(0, lobOut(0)), k(1, st(lobOut(0), { rz = -2.2, jaw = 0.5 }), "out") }),
	recover = ph(0.8, { k(0, st(lobOut(0), { rz = -2.2, jaw = 0.5 })), k(0.45, rise({ 50, 90, 50, 30, 15, 0 }, { hood = 0.3 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

-- JiaoCoil: the windup rears and starts winding the tail out sideways; the dash forms the ring by
-- forward kinematics; the recover holds the ring (tightening, then the squeeze) and unwinds
local CO_UP = rise(COL, { bp = 0.3, hood = 0.7, jaw = 0.4, tamp = 0.5, ring = 0.12, ty = -0.2 })
local CO_PEAK = rise(COL, { bp = 0.36, hood = 0.9, jaw = 0.6, tamp = 0.4, ring = 0.24, E = { 82, 100, 94, 86, 74, 22 } })
local CO_RING = st(IDLE, { ring = 1, arch = 1, hood = 0.9, jaw = 0.5, tamp = 0.15 })
moves.JiaoCoil = {
	windup = ph(1.5, { k(0, IDLE), k(0.4, CO_UP, "out"), k(0.7, CO_PEAK, "inOut"), k(1, CO_PEAK) }, function(u) return window(u, 0.5, 0.7, 0.9, 1) * 0.6 end),
	active = ph(0.45, { k(0, CO_PEAK), k(1, CO_RING, "out") }),
	recover = {
		duration = 4.4,
		fn = function(u, secs, input)
			local p = input.phase or 1
			local hold = if p >= 3 then 2.6 else 3.0
			local total = math.max(input.duration or 4.4, hold + 0.6)
			local sec = u * total
			local s = table.clone(CO_RING)
			s.tight = smooth(0, hold - 0.1, sec) * 1.0
			if sec >= hold - 0.1 then
				-- the squeeze: a hard snap tighter at hold end, then a shudder
				s.tight = 1 + 0.6 * smooth(hold - 0.1, hold + 0.04, sec) * (1 - smooth(hold + 0.12, hold + 0.5, sec))
			end
			if sec > hold then
				local x = (sec - hold) / math.max(0.4, total - hold)
				local e = EASE.inOut(math.clamp(x, 0, 1))
				s.ring = 1 - e
				s.arch = 1 - smooth(0, 0.55, x)
				s.tight = s.tight * (1 - e)
				s.hood = 0.9 - 0.7 * e
				s.jaw = 0.5 * (1 - e)
				s.tamp = 0.15 + 0.2 * e
			end
			return s
		end,
		tremble = function(u) return 0.15 end,
	},
}

-- DreadHiss: rears, hood to maximum, jaw wide, body quivering; contact is a body pulse
local HISS_UP = rise(ROAR, { bp = 0.28, hood = 1, jaw = 1, fang = 1, tamp = 0.9, tongue = 1 })
local HISS_PEAK = st(HISS_UP, { E = { 84, 104, 98, 92, 86, 52 }, bp = 0.34 })
local HISS_BURST = st(HISS_PEAK, { bp = 0.5, E = { 86, 106, 100, 94, 88, 62 } })
moves.DreadHiss = {
	windup = ph(1.1, { k(0, IDLE), k(0.5, HISS_UP, "outBack"), k(0.9, HISS_PEAK, "out"), k(1, HISS_BURST, "snap") },
		function(u) return window(u, 0.45, 0.6, 1, 1.01) * 1.0 end),
	active = ph(0.1, { k(0, HISS_BURST), k(1, HISS_PEAK, "out") }, function(_) return 0.8 end),
	recover = ph(0.8, { k(0, HISS_PEAK), k(0.5, st(HISS_UP, { hood = 0.5, jaw = 0.4, bp = 0.15 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

-- Molt (rise to full height) and Ascension (higher, held longer): hood wide, head thrown back
local MOLT_UP = rise(ROAR, { bp = 0.3, hood = 1, jaw = 1, fang = 1, tamp = 1.0, tongue = 1 })
local MOLT_PEAK = st(MOLT_UP, { E = { 84, 108, 100, 96, 90, 62 }, bp = 0.36 })
moves.Molt = {
	windup = ph(1.6, { k(0, IDLE), k(0.4, MOLT_UP, "outBack"), k(0.7, MOLT_PEAK, "out"), k(1, MOLT_PEAK) }, function(u) return window(u, 0.4, 0.55, 1, 1.01) * 0.9 end),
	active = ph(0.1, { k(0, MOLT_PEAK), k(1, MOLT_PEAK) }, function(_) return 0.8 end),
	recover = ph(0.8, { k(0, MOLT_PEAK), k(0.5, st(MOLT_UP, { hood = 0.5, jaw = 0.3, bp = 0.15 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}
local ASC_UP = rise(ROAR, { bp = 0.46, hood = 1, jaw = 1, fang = 1, tamp = 1.2, tongue = 1, E = { 84, 100, 94, 90, 84, 45 } })
local ASC_PEAK = st(ASC_UP, { E = { 86, 108, 100, 96, 92, 68 }, bp = 0.52 })
moves.Ascension = {
	windup = ph(2.0, { k(0, IDLE), k(0.5, ASC_UP, "outBack"), k(0.75, ASC_PEAK, "out"), k(1, ASC_PEAK) }, function(u) return window(u, 0.4, 0.55, 1, 1.01) * 1.0 end),
	active = ph(0.1, { k(0, ASC_PEAK), k(1, ASC_PEAK) }, function(_) return 0.9 end),
	recover = ph(0.9, { k(0, ASC_PEAK), k(0.45, st(ASC_UP, { hood = 0.6, bp = 0.3 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1.2),
}

-- VenomRain: rears to the full 18 and holds with the hood wide, jerks in nine beats (0.3 s) as it
-- spits upward, tails off, then droops exhausted (the opening)
local RAIN_UP = rise(RAINE, { bp = 0.5, hood = 1, jaw = 0.6, fang = 1, tamp = 0.8, tongue = 1 })
local RAIN_HOLD = st(RAIN_UP, { bp = 0.52, jaw = 0.7, E = { 86, 102, 96, 93, 90, 60 } })
local RAIN_SPIT = st(RAIN_HOLD, { jaw = 0.7, E = { 86, 102, 96, 93, 90, 78 } })
local RAIN_DROOP = rise(DROOP, { bp = 0.05, hood = 0.15, jaw = 0.2, tamp = 0.25, ry = -0.2 })
moves.VenomRain = {
	windup = ph(2.0, { k(0, IDLE), k(0.5, RAIN_UP, "outBack"), k(0.7, RAIN_HOLD, "out"), k(1, RAIN_HOLD) }, function(u) return window(u, 0.5, 0.65, 1, 1.01) * 0.5 end),
	active = ph(0.2, { k(0, RAIN_HOLD), k(1, RAIN_SPIT, "out") }),
	recover = {
		duration = 4.8,
		fn = function(u, secs, input)
			local total = math.max(input.duration or 4.8, 4.0)
			local sec = u * total
			local spitting = RAIN_SPIT
			local s: Stance
			if sec < 2.6 + 0.9 then
				s = table.clone(spitting)
				-- nine beats 0.3 s apart (the last 0.9 s fade): a snap back and a spit upward
				local beat = (sec % 0.3) / 0.3
				local fade = 1 - smooth(2.6, 3.5, sec)
				local kick = math.sin(math.pi * math.min(1, beat * 1.6)) * fade
				s.e6 += D(18) * kick
				s.e5 += D(6) * kick
				s.bp += 0.05 * kick
				s.jaw = 0.7 + 0.45 * kick
				s.throat = kick
				s.tamp = 0.8
				s.hood = 1 - 0.25 * smooth(2.6, 3.5, sec)
			else
				local x = smooth(3.5, 4.2, sec)
				s = lerpStance(spitting, RAIN_DROOP, x)
				local back = smooth(total - 0.6, total, sec)
				s = lerpStance(s, IDLE, back)
			end
			return s
		end,
		tremble = function(u) return 0.35 end,
	},
}

-- Emerge: sunk and trembling for 1.2 s, then the body surges from -6 to the full roar; recover settles
local EM_SURGE = rise(ROAR, { bp = 0.34, hood = 1, jaw = 1, fang = 1, tamp = 1.0, tongue = 1, rz = -1.2 })
local EM_MID = rise({ 40, 75, 55, 40, 30, 10 }, { ry = -2.5, bp = 0.2, hood = 0.5, jaw = 0.4 })
moves.Emerge = {
	windup = ph(2.2, { k(0, DIVE_SUNK), k(0.5, DIVE_SUNK), k(0.74, EM_MID, "in"), k(0.92, EM_SURGE, "outBack"), k(1, EM_SURGE) },
		function(u) return if u < 0.55 then 0.25 + 0.9 * smooth(0, 0.55, u) else 0.5 end),
	active = ph(0.1, { k(0, EM_SURGE), k(1, EM_SURGE) }, function(_) return 0.6 end),
	recover = ph(0.5, { k(0, EM_SURGE), k(0.4, st(EM_SURGE, { jaw = 0.4, hood = 0.5, bp = 0.15 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1.4),
}

-- Stagger: a recoil and shudder, the head thrown away from the side the target is on
moves.Stagger = {
	active = {
		duration = 0.4,
		fn = function(u, secs, input)
			local side = math.clamp(input.side or 1, -1, 1)
			local e = smooth(0, 0.22, u) * (1 - smooth(0.45, 1, u))
			local s = table.clone(IDLE)
			local shake = math.sin(secs * 38) * e
			s.e1 += D(-10) * e
			s.e3 += D(-8) * e
			s.e6 += D(26) * e
			s.y5 += 0.45 * side * e
			s.y6 += 0.6 * side * e
			s.hr = 0.35 * side * e
			s.jaw = 0.8 * e
			s.fang = 0.8 * e
			s.hood = 0.7 * e
			s.rroll = 0.07 * shake
			s.ryaw = 0.05 * shake
			s.rz = 0.8 * e
			s.tamp = 0.35 + 0.8 * e
			return s
		end,
	},
}

-- Death: thrash, rear and roar, the head slams down, the body convulses in waves and goes limp
local DE_HIT = rise({ 62, 120, 62, 40, 30, 22 }, { bp = 0.18, hood = 0.9, jaw = 0.9, fang = 1, tamp = 1.5, rz = 1.2, hr = 0.3 })
local DE_ROAR = rise(ROAR, { bp = 0.5, hood = 1, jaw = 1, fang = 1, tamp = 2.0, tongue = 1, E = { 86, 106, 100, 94, 88, 62 } })
local DE_THRASH = st(DE_ROAR, { Y = { 0, 0, 0.1, 0.2, 0.3, 0.2 }, tup = 0.5, ty = 0.6, bp = 0.42 })
local DE_SLAM = rise({ 22, 60, 10, -10, -32, -50 }, { bp = 0.1, hood = 0.5, jaw = 0.5, tamp = 2.2, ry = -0.2 })
local DE_CONV = st(DE_SLAM, { tup = 0.3, ty = -0.4, tamp = 2.4, hood = 0.3, rroll = 0 })
local DE_LIMP = rise(LIMP, { bp = 0, hood = 0.05, jaw = 0.08, tamp = 0, ry = -0.35, hr = 0.2, tongue = 0.2 })
moves.Death = {
	active = {
		duration = 3.6,
		keys = { k(0, IDLE), k(0.05, DE_HIT, "out"), k(0.22, DE_ROAR, "outBack"), k(0.42, DE_THRASH, "inOut"), k(0.5, DE_ROAR, "inOut"),
			k(0.56, DE_SLAM, "in"), k(0.64, st(DE_SLAM, { ry = -0.1, E = { 28, 66, 14, -4, -24, -44 } }), "out"), k(0.76, DE_CONV, "inOut"),
			k(0.92, DE_LIMP, "out"), k(1, DE_LIMP) },
		tremble = function(u)
			return 0.9 * (window(u, 0.05, 0.12, 0.5, 0.56) + window(u, 0.58, 0.64, 0.82, 0.95))
		end,
	},
}

--------------------------------------------------------------------------------
-- Variants

local variants: { [string]: { [string]: { [string]: Phase } } } = {}
for _, name in { "VenomFang", "TailSweep", "PillarSlam", "FangFlurry", "VenomLance" } do
	variants[name] = { A = moves[name] }
end

-- VenomFang B "Side hook": the head draws away to one side, the jaw wide, then hooks across
local FB_DRAW = rise({ 50, 130, 58, 34, 14, -10 }, { Y = { 0, 0.1, 0.25, 0.5, 0.75, 0.9 }, hr = 0.5, hood = 0.6, jaw = 1, fang = 1, rz = 1.2, tamp = 0.5, tongue = 1, rroll = 0.06 })
local FB_HOOK = rise({ 30, 50, 24, 12, 0, -16 }, { Y = { 0, -0.05, -0.2, -0.45, -0.7, -0.8 }, hr = -0.4, hood = 0.55, jaw = 0.95, fang = 1, rz = -2.0, tamp = 0.7, rroll = -0.05 })
local FB_OVER = st(FB_HOOK, { Y = { 0, -0.1, -0.3, -0.6, -0.9, -1.0 }, rz = -2.6, jaw = 0.5 })
variants.VenomFang.B = {
	windup = ph(0.75, { k(0, IDLE), k(0.4, FB_DRAW, "inOut"), k(0.85, FB_DRAW), k(1, FB_HOOK, "snap") }, function(u) return window(u, 0.45, 0.55, 0.86, 0.95) end),
	active = ph(0.12, { k(0, FB_HOOK), k(1, FB_OVER, "out") }),
	recover = ph(0.78, { k(0, FB_OVER), k(0.4, st(IDLE, { Y = { 0, 0, 0, -0.2, -0.3, -0.3 }, jaw = 0.1 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

-- TailSweep B "Spin": the body twists the other way as the tail winds, then unwinds with the lash
variants.TailSweep.B = {
	windup = ph(0.8, { k(0, IDLE), k(0.35, st(SW_DIP, { ryaw = 0.5, ty = -0.4, tup = 0.7 }), "inOut"), k(0.62, st(SW_WOUND, { ryaw = 0.7, ty = -1.0, tup = 1.1, rz = 1.0 }), "out"),
		k(0.66, st(SW_WOUND, { ryaw = 0.7, ty = -1.0, tup = 1.1, rz = 1.0 })), k(1, st(SW_LASH, { ryaw = -0.45 }), "in") }, function(u) return window(u, 0.3, 0.45, 0.6, 0.66) end),
	active = ph(0.14, { k(0, st(SW_LASH, { ryaw = -0.45 })), k(1, st(SW_OVER, { ryaw = -0.3 }), "out") }),
	recover = ph(0.86, { k(0, st(SW_OVER, { ryaw = -0.3 })), k(0.4, st(SW_REST, { tup = 0.1 }), "inOut"), k(1, SW_REST, "inOut") }, nil, 1),
}

-- PillarSlam B "Corkscrew": the column spirals up (a helix in the neck) before it drops
variants.PillarSlam.B = {
	windup = {
		duration = 1.0,
		fn = function(u, secs, input)
			local up = keyed({ k(0, IDLE), k(0.45, SLAM_UP, "outBack"), k(0.62, SLAM_HANG, "out"), k(0.84, SLAM_HANG), k(1, SLAM_HIT, "in") }, u)
			local s = table.clone(up)
			local spin = TAU * EASE.inOut(smooth(0.05, 0.86, u))
			local amp = 0.9 * smooth(0.05, 0.3, u) * (1 - smooth(0.84, 1, u))
			for j = 1, 6 do
				s[YNAME[j]] += amp * math.sin(spin - 0.9 * j)
			end
			s.rroll = 0.1 * amp * math.sin(spin)
			return s
		end,
		tremble = function(u) return window(u, 0.5, 0.62, 0.86, 0.95) end,
	},
	active = moves.PillarSlam.active,
	recover = moves.PillarSlam.recover,
}

-- FangFlurry B "Weave": the lunges come from alternating sides (left, right, centre)
local function weave(s: Stance, y: number): Stance
	return st(s, { Y = { 0, 0, 0.1 * y, 0.3 * y, 0.5 * y, 0.6 * y } })
end
variants.FangFlurry.B = {
	windup = ph(0.9, { k(0, IDLE), k(0.5, weave(FL_COIL, -1), "inOut"), k(0.82, weave(FL_COIL, -1)), k(1, weave(FL_S1, 1), "snap") }, function(u) return window(u, 0.4, 0.55, 0.85, 0.95) end),
	active = ph(1.0, { k(0, weave(FL_S1, 1)), k(0.12, weave(FL_PULL, 1), "out"), k(0.3, weave(FL_PULL, -1), "inOut"), k(0.4, weave(FL_S2, -1), "snap"), k(0.55, weave(FL_PULL, -1), "out"),
		k(0.88, weave(FL_PULL3, 0), "inOut"), k(1, FL_S3, "snap") }),
	recover = moves.FangFlurry.recover,
}

-- VenomLance B "Head lash": the head cocks to one side and whips round into the lane
local LNB_BACK = st(LN_BACK, { Y = { 0, 0, 0.1, 0.3, 0.55, 0.7 }, hr = 0.35 })
local LNB_HOLD = st(LN_HOLD, { Y = { 0, 0, 0.12, 0.35, 0.6, 0.75 }, hr = 0.4 })
local LNB_FWD = st(LN_FWD, { Y = { 0, 0, 0, 0, 0, 0 }, hr = 0, rz = -3.0 })
variants.VenomLance.B = {
	windup = ph(0.7, { k(0, IDLE), k(0.45, LNB_BACK, "inOut"), k(0.82, LNB_HOLD, "out"), k(1, LNB_FWD, "snap") }, function(u) return window(u, 0.5, 0.6, 0.84, 0.95) end),
	active = ph(0.1, { k(0, LNB_FWD), k(1, st(LNB_FWD, { rz = -3.6, Y = { 0, 0, 0, -0.05, -0.1, -0.12 }, jaw = 0.4 }), "out") }),
	recover = ph(0.7, { k(0, st(LNB_FWD, { rz = -3.6, Y = { 0, 0, 0, -0.05, -0.1, -0.12 }, jaw = 0.4 })), k(0.4, rise({ 40, 80, 40, 20, 8, -5 }, { hood = 0.3, jaw = 0.2, rz = -1.2 }), "inOut"), k(1, IDLE, "inOut") }, nil, 1),
}

JadeJiao.VARIANTS = variants
-- defaults: the boss-tier big windups
JadeJiao.VARIANT = { VenomFang = "A", TailSweep = "A", PillarSlam = "A", FangFlurry = "A", VenomLance = "A" }
function JadeJiao.setVariant(move: string, v: string)
	assert(variants[move] and variants[move][v], "no variant " .. move .. "." .. v)
	JadeJiao.VARIANT[move] = v
end
function JadeJiao.setAll(v: string)
	for move, list in variants do
		if list[v] then
			JadeJiao.VARIANT[move] = v
		end
	end
end

local function durationsOf(): { [string]: { [string]: number } }
	local out = {}
	for name, phases in moves do
		out[name] = {}
		for p, def in phases do
			out[name][p] = def.duration
		end
	end
	return out
end
JadeJiao.moves = moves
JadeJiao.durations = durationsOf()

--------------------------------------------------------------------------------
-- Sampling

local function phaseOf(move: string, phase: string): Phase
	local list = variants[move]
	if list then
		return list[JadeJiao.VARIANT[move]][phase]
	end
	return moves[move][phase]
end

-- Settling ring-down after an impact: the neck leads, the head trails, the tail whips last
local SETTLE_DELAY = 0.05
local function settle(s: Stance, amp: number, tc: number)
	local function ring(delay: number, hz: number): number
		local t = math.max(0, tc - delay)
		return math.sin(t * TAU * hz) * math.exp(-4 * t) * amp
	end
	s.e1 += 0.05 * ring(0, 2.2)
	s.e3 += 0.07 * ring(0.04, 2.4)
	s.e5 += 0.1 * ring(0.08, 2.6)
	s.e6 += 0.14 * ring(0.12, 3)
	s.y5 += 0.08 * ring(0.1, 2)
	s.ty += 0.12 * ring(0.1, 1.8)
	s.tup += 0.06 * ring(0.12, 2.2)
	s.jaw += 0.1 * math.max(0, ring(0.1, 3))
	s.rroll += 0.02 * ring(0.02, 2.6)
	s.ry += -0.05 * math.max(0, ring(0, 2.4))
end

local function stanceAt(move: string, phase: string, u: number, input: Input, lag: number): Stance
	local p = phaseOf(move, phase)
	local dur = input.duration or p.duration
	local uu = math.clamp(u - lag / dur, 0, 1)
	local secs = uu * dur
	local s: Stance
	if p.fn then
		s = p.fn(uu, secs, input)
	else
		s = keyed(p.keys :: { Key }, uu)
	end
	s = table.clone(s)
	local amp = if p.tremble then p.tremble(uu) else 0
	if amp > 0.01 then
		local t = secs
		for j = 1, 6 do
			s[YNAME[j]] += 0.025 * amp * math.sin(t * (9 + j * 1.3) + j)
			s[ENAME[j]] += 0.018 * amp * math.sin(t * (7 + j * 1.1) + j * 0.7)
		end
		s.rroll += 0.012 * amp * math.sin(t * 13)
		s.ry += -0.06 * amp * (0.5 + 0.5 * math.sin(t * 17))
		s.hood += 0.04 * amp * math.sin(t * 9)
	end
	if p.settle and phase ~= "windup" then
		local tc = secs + (if phase == "recover" then (JadeJiao.durations[move].active or 0) else 0)
		settle(s, p.settle, tc)
	end
	return s
end

local LAG_FADE_SEC = 1.0
function JadeJiao.sample(move: string, phase: string, u: number, input: Input?): Pose
	local inp: Input = input or {}
	u = math.clamp(u, 0, 1)
	local p = phaseOf(move, phase)
	local dur = inp.duration or p.duration
	local fade = if move == "Death" then smooth(0, 0.2, u) else smooth(0, 0.2, u) * (1 - smooth(0.8, 1, u))
	if move == "MireDive" or (move == "JiaoCoil" and phase ~= "windup") then
		fade = 0
	end
	local samples = table.create(4)
	for i = 1, 4 do
		samples[i] = stanceAt(move, phase, u, inp, LAGS[i] * fade * LAG_FADE_SEC)
	end
	local secs = u * dur
	local clock = inp.time or secs
	local ph1 = inp.phase or 1
	local arcs = JadeJiao.COIL_ARC[if ph1 >= 3 then 2 else 1]
	local R = inp.radius or COIL_R
	-- a move started from a resting coil unwinds it over the first 0.6 s of the windup
	local restW: ((number) -> number)? = nil
	if phase == "windup" then
		local c0 = coilLevel((inp.still or 0) - secs) * (1 - smooth(0, 0.6, secs))
		if c0 > 0.001 then
			restW = function(i: number): number
				return c0
			end
		end
	end
	local ctx: Ctx = {
		secs = clock, wavePhase = inp.wavePhase or 0, th0 = TH_STANCE, wavelength = WAVELENGTH, yawAt = nil,
		speed = 0, turn = 0, phase = ph1, radius = R, arcs = arcs, seed = inp.seed or 0, restW = restW,
	}
	return compose(samples, ctx)
end

--------------------------------------------------------------------------------
-- Loops: slither

local function mix(a: { number }, b: { number }, t: number): { number }
	local out = {}
	for j = 1, 6 do
		out[j] = a[j] + (b[j] - a[j]) * t
	end
	return out
end

-- the wave's phase rate: k * the sliding speed, so the curve stays fixed on the ground while the
-- body slides along it at `speed` mean ground speed
function JadeJiao.gaitRate(loop: string, speed: number, scale: number?): number
	if loop == "walk" or loop == "run" or loop == "circle" then
		local th0, wl = slitherParams(speed)
		return TAU / wl * Serpent.slideSpeed(speed, th0)
	end
	return 1
end

local function REST_E_DEG(): { number }
	local out = {}
	for j = 1, 6 do
		out[j] = math.deg(REST_E[j])
	end
	return out
end

local function loopCtx(phase: number, speed: number, input: Input?): Ctx
	local inp = input or {}
	local th0, wl = slitherParams(speed)
	return {
		secs = inp.time or os.clock(), wavePhase = phase, th0 = th0, wavelength = wl, yawAt = inp.yawAt, speed = speed,
		turn = inp.turn or 0, phase = inp.phase or 1, radius = COIL_R, arcs = JadeJiao.COIL_ARC[1], seed = inp.seed or 0,
	}
end

local loops: { [string]: (number, number, Input?) -> Pose } = {}
-- idle: the S it stopped in gathers into the resting coil (the reference's look) after 1.2 s,
-- the head end first, and the neck rises back into the strike S; a slow sway, breathing and
-- tongue flicks throughout. t is a clock; input.wavePhase the S it stopped in.
function loops.idle(t: number, speed: number, input: Input?): Pose
	local inp = input or {}
	local seed = inp.seed or 0
	local c = coilLevel(inp.still or 99)
	local s = table.clone(IDLE)
	local neck = mix(WALK_N, REST_E_DEG(), smooth(0, 0.6, c))
	for j = 1, 6 do
		s[ENAME[j]] = D(neck[j])
	end
	local sway = math.sin(t * 0.55 + seed)
	for j = 1, 5 do
		s[YNAME[j]] = 0.09 * sway * (0.4 + 0.15 * j) + 0.03 * math.sin(t * 1.3 + j)
	end
	s.y6 = -0.1 * sway
	s.e1 += 0.025 * math.sin(t * 1.55 + seed)
	s.e3 += 0.035 * math.sin(t * 1.55 + seed - 0.5)
	s.e5 += 0.03 * math.sin(t * 1.55 + seed - 1.0)
	s.e6 += 0.04 * math.sin(t * 0.8 + 1)
	s.hood = 0.03 * (0.5 + 0.5 * math.sin(t * 1.55))
	s.ty = 0.06 * math.sin(t * 0.4 + seed)
	s.tamp = 0.25
	local ctx = loopCtx(inp.wavePhase or 0, 0, input)
	ctx.th0 = TH_STANCE
	ctx.wavelength = WAVELENGTH
	ctx.secs = t
	ctx.restW = function(i: number): number
		return smooth(0, 1, c * 1.6 - 0.6 * i / NT)
	end
	return compose(same(s), ctx)
end

-- a move-start from a coil unwinds as the head travels: bone i leaves the coil once the head has
-- gone about half its arc
local function unwind(input: Input?): ((number) -> number)?
	local inp = input or {}
	local c0 = coilLevel(inp.rested or 0)
	if c0 < 0.001 then
		return nil
	end
	local travel = inp.travel or 99
	return function(i: number): number
		local s = if i == 0 then solver.sPivot else solver.arc[i] + solver.len[i] * 0.5
		return c0 * (1 - smooth(s * 0.45 - 3, s * 0.45 + 5, travel))
	end
end

local function slither(phase: number, speed: number, input: Input?, neck: { number }, look: number?): Pose
	local s = st(IDLE, {})
	for j = 1, 6 do
		s[ENAME[j]] = D(neck[j])
	end
	s.hood = 0
	s.tamp = 0.15
	local t = (input and input.time) or os.clock()
	s.e6 += 0.03 * math.sin(t * 1.4) -- the head bobs a little, nothing frozen
	local ctx = loopCtx(phase, speed, input)
	ctx.neckPath = 1
	ctx.look = look
	ctx.restW = unwind(input)
	return compose(same(s), ctx)
end

function loops.walk(phase: number, speed: number, input: Input?): Pose
	local f = smooth(0.6, 6, speed)
	return slither(phase, speed, input, mix(mix(REST_E_DEG(), WALK_N, 0.6), WALK_N, f))
end

function loops.run(phase: number, speed: number, input: Input?): Pose
	local f = smooth(8.5, 21, speed)
	return slither(phase, speed, input, mix(WALK_N, RUN_N, f))
end

-- circle: the same slither with the head held on the target
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local inp = input or {}
	local f = smooth(8.5, 21, speed)
	return slither(phase, speed, input, mix(WALK_N, RUN_N, f), math.clamp(inp.targetYaw or 0, -0.7, 0.7) * 0.8)
end

JadeJiao.loops = loops
JadeJiao.USES_HISTORY = true -- EnemyAnimator supplies phase, speed, turn, yawAt, time, wavePhase, still, travel, rested

-- poses are in real studs (SCALE = 1); kept for the family API
function JadeJiao.scaled(pose: Pose, scale: number): Pose
	if scale == 1 then
		return pose
	end
	local out = table.clone(pose)
	local r = out.JointRoot
	if r then
		local p = r.Position
		out.JointRoot = CFrame.new(p * scale) * (r - p)
	end
	return out
end

return JadeJiao
