--!strict
-- Venom Serpent: the small hooded cobra (VenomSerpentB, 1.40x; art/enemies/beasts/RIGS.md
-- "Venom Serpent"), 13 joints. Same pose API as JadeJiao.luau / WolfKing.luau and built on
-- Serpent.luau's maths; pure tables, no instances and no gameplay decisions.
--
-- UNITS: real studs in model space (ground Y = 0, faces -Z, left is -X) of the 1.40x body,
-- SCALE = 1. The pivots below are the roster body's x 1.4 (the user's row, 5.1 x 7.0 x 15.9).
--
-- MOVE-NAME MAP for FAMILIES (EnemyAnimator): the server's Attack / AttackName attribute ->
-- the move here (this module sets LEAD, so the skid gets input.targetYaw and input.side):
--   venomSpit = "VenomSpit"   hoodStrike = "HoodStrike"   hoodStrikeSkid = "HoodStrikeSkid"
--   hop = "Hop"               tailSnap = "TailSnap"
-- Family fields: poses = VenomSerpent, scale = VenomSerpent.SCALE (1), runFrom = 7,
--   keyedBlend = 0.15, staggerSeconds = 0.28, deathSeconds = 0.9.
--
-- Move          windup / active / recover   (seconds; server recover in brackets)
-- VenomSpit       1.10 / 0.10 / 0.60  [0.60, its first 0.10 plays the active beat]
-- HoodStrike      0.60 / 0.25 / 0.80  (dash of 8 studs at 32/s; contact = the dart)
-- HoodStrikeSkid          -   /  -   / 0.80  (recover of the missed lunge, uses targetYaw)
-- Hop             -    / 0.35 / 0.30  (active = the backslide; the recover is a landing the
--                                      designer may skip if the server's hop has no recover)
-- TailSnap        0.70 / 0.10 / 0.80  [0.80, its first 0.10 plays the active beat]
-- Stagger         active 0.28 (input.side: the head is thrown away from the hit)
-- Death           active 0.90, then hold u = 1 (a loose S on the ground)
--
-- BEATS (u of the phase; all start on the AIState's StateAt, where telegraph, tell flare and
-- sound start)
--   VenomSpit windup: 0-0.13 (0.14 s) a small forward dip (the anticipation: it breathes in);
--     0.13-0.40 the head draws back and UP into a deep S (the user's windup pose: neck 62/98/118
--     degrees, the skull thrown 34 up, the throat open, hood half flared and fluttering, body
--     pulled back); 0.40-0.54 the held beat, trembling, creeping tighter; 0.54-0.60 it loads one
--     last notch, then the head snaps forward and DOWN with the jaw wide, at its fastest as it
--     passes the throw pose at u = 0.636 (0.70 s: the gob leaves the Mouth there; the head lags the
--     neck 0.06 s, so the key sits at u 0.60); 0.636-1.0 (0.40 s) the follow-through: the head
--     overshoots low, the body slides after it, the hood flares, then it hangs spent.
--     recover: the neck rises and settles with a damped ring and the tongue flicks twice.
--   HoodStrike windup: 0-0.16 gathers low (neck folded forward, hood opening); 0.16-0.52 rears
--     into a taut S (66/96/84), the hood fully flared (L = -Y, R = +Y) and fluttering; 0.52-0.78
--     the held beat (tremble); 0.78-1.0 cocks back one more notch. active: the head darts forward
--     and down along the line (jaw wide), the body slides after it. recover: the hood folds, the
--     head recoils up and back, then re-aims and settles.
--   HoodStrikeSkid: brace (neck stiff, low, hood flared) while the head whips round to the live
--     targetYaw first, the neck after it and the body last, then it unwinds as the root turns.
--   Hop: a quick sinuous reverse. The body wave runs the OTHER way along the S (the wave phase is
--     reversed, a whole number of cycles over the hop so it ends on the phase EnemyAnimator is
--     at), the head stays up and faces the target, hood half open, body lifting a little.
--   TailSnap: the head turns away from the target; the tail rears into an arch and bends round to
--     the side (held beat, trembling), cocks back, then CRACKS down across the ground; the tip
--     lags the root so it whips. recover: the tail drags and uncurls, the head turns back.
-- LOOPS: idle (S-sway, hood breathing, a phase-lagged ripple down the tail, tongue flicks),
--   walk <= ~5 studs/s and run ~9 (the Jiao's slither: the wave stays fixed to the ground, the
--   neck follows the path, the body follows the travel heading), circle (a sideways sway).
--
-- The jowl sacs are Tell parts without joints (VFX swells them); the tongue rides the Jaw, so a
-- tongue flick is a quick jaw tick.
--
-- API (as JadeJiao.luau)
--   VenomSerpent.sample(move, phase, u, input?) -> Pose
--   VenomSerpent.loops.idle(clock, speed, input?) / walk(phase, speed, input?) / run / circle
--   VenomSerpent.gaitRate(loop, speed, scale?), VenomSerpent.scaled(pose, scale),
--   VenomSerpent.plant(pose) (a no-op: no legs), VenomSerpent.moves, .durations, .JOINTS

local Serpent = require(script.Parent.Serpent)

export type Pose = Serpent.Pose
export type Input = {
	duration: number?,
	side: number?, -- +1 the target / hit is on the beast's right, -1 its left
	targetYaw: number?, -- yaw from the facing to the target, + = its left (the skid)
	dir: number?, -- circle: +1 sidestepping to the beast's left
	seed: number?,
	speed: number?, -- real studs/s
	turn: number?, -- travel yaw rate rad/s
	yawAt: ((number) -> number)?, -- travel heading secondsAgo
	time: number?, -- a clock for ambient motion (os.clock)
	wavePhase: number?, -- the slither wave's phase (EnemyAnimator advances it with the distance moved)
	still: number?,
	travel: number?,
	rested: number?,
	phase: number?,
}
type Stance = { [string]: number }
type Key = { t: number, s: Stance, ease: string? }
type Phase = {
	duration: number,
	keys: { Key }?,
	fn: ((u: number, secs: number, input: Input) -> Stance)?,
	tremble: ((u: number) -> number)?,
	over: ((u: number) -> { [string]: number })?,
	settle: number?,
	mirror: boolean?,
}

local VenomSerpent = {}
local V = Vector3.new
local TAU = Serpent.TAU
local smooth, EASE = Serpent.smooth, Serpent.EASE
local D = math.rad
local SCALE = 1
VenomSerpent.SCALE = SCALE
local WAVELENGTH = 10.5 -- arc studs between crests (the spine is ~12 studs long)
VenomSerpent.WAVELENGTH = WAVELENGTH
local TH_STANCE = 0.8 -- the heading amplitude held under stances (the walk's)

--------------------------------------------------------------------------------
-- Skeleton (RIGS.md; the roster pivots x 1.4, ground at Y = 0, HRP centre at the origin in X/Z)

local NECK = { "JointNeck", "JointNeck2", "JointNeck3", "JointHead" }
local TAIL = { "JointTail", "JointTail2", "JointTail3", "JointTail4", "JointTail5" }
VenomSerpent.JOINTS = { "JointRoot" }
for _, n in NECK do
	table.insert(VenomSerpent.JOINTS, n)
end
for _, n in { "JointJaw", "JointHoodL", "JointHoodR" } do
	table.insert(VenomSerpent.JOINTS, n)
end
for _, n in TAIL do
	table.insert(VenomSerpent.JOINTS, n)
end

local P: { [string]: Vector3 } = {
	JointRoot = V(0.63, 0.89, 0.07),
	JointNeck = V(0, 0.91, -0.84), JointNeck2 = V(0, 2.45, -1.96), JointNeck3 = V(0, 4.13, -2.45), JointHead = V(0, 5.67, -2.52),
	JointTail = V(1.26, 0.87, 0.98), JointTail2 = V(1.12, 0.81, 3.22), JointTail3 = V(-0.56, 0.73, 4.76),
	JointTail4 = V(-1.82, 0.63, 6.72), JointTail5 = V(-0.98, 0.50, 8.68),
}
VenomSerpent.PIVOTS = P
local HRP_Z = 0

local solver = Serpent.new({
	P = P, root = "JointRoot", neck = NECK, tail = TAIL, tailEnd = V(1.17, 0.26, 9.84),
	mouth = V(0, 6.06, -4.84), hrpZ = HRP_Z,
})
VenomSerpent.solver = solver
local NT = #TAIL

local function slitherParams(speed: number): (number, number)
	local f = smooth(4, 10, speed)
	return TH_STANCE - 0.15 * f, WAVELENGTH + 1.0 * f
end

--------------------------------------------------------------------------------
-- Stances

local ENAME, YNAME, ZNAME = { "e1", "e2", "e3", "e4" }, { "y1", "y2", "y3", "y4" }, { "z1", "z2", "z3", "z4" }
local DEF: Stance = {
	ry = 0, rx = 0, rz = 0, ryaw = 0, rroll = 0, bp = 0,
	hr = 0, jaw = 0, hood = 0, flt = 0, tng = 0,
	ty = 0, tup = 0, tamp = 0.35, th = TH_STANCE, wph = 0, cen = 1,
}
for j = 1, 4 do
	DEF[ENAME[j]] = solver.eps[j]
	DEF[YNAME[j]] = 0
	DEF[ZNAME[j]] = 0
end
local KEYS: { string } = {}
for key in DEF do
	table.insert(KEYS, key)
end

-- a stance from a base and changes: E = four neck elevations in degrees (absolute above
-- horizontal, 90 vertical, past 90 leans back; the head's is a pitch from its rest, + noses
-- up), Y = four headings in radians (+ turns left), Z = four sideways leans in radians (+ tips
-- the bone toward the beast's left; a vertical column can only sway by leaning), anything else a key
local function st(base: Stance, c: { [string]: any }?): Stance
	local out = table.clone(base)
	if c then
		for key, v in c do
			if key == "E" then
				for j = 1, 4 do
					out[ENAME[j]] = D((v :: any)[j])
				end
			elseif key == "Y" then
				for j = 1, 4 do
					out[YNAME[j]] = (v :: any)[j]
				end
			elseif key == "Z" then
				for j = 1, 4 do
					out[ZNAME[j]] = (v :: any)[j]
				end
			else
				out[key] = v
			end
		end
	end
	return out
end

local function lerpStance(a: Stance, b: Stance, t: number): Stance
	local out = {}
	for _, key in KEYS do
		local x, y = a[key], b[key]
		out[key] = x + (y - x) * t
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

local function mirrored(s: Stance): Stance
	local out = table.clone(s)
	for j = 1, 4 do
		out[YNAME[j]] = -s[YNAME[j]]
		out[ZNAME[j]] = -s[ZNAME[j]]
	end
	out.hr, out.ty, out.ryaw, out.rroll, out.rx = -s.hr, -s.ty, -s.ryaw, -s.rroll, -s.rx
	return out
end

local function window(u: number, a: number, b: number, c: number, d: number): number
	return smooth(a, b, u) * (1 - smooth(c, d, u))
end

local hash = function(n: number, seed: number): number
	local x = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	return x - math.floor(x)
end

--------------------------------------------------------------------------------
-- Compose a pose from stance samples

-- per-bone lag behind the stance's clock (s): the neck leads and the head trails a hair; the tail
-- is the S-wave's far end and trails by up to 0.15 s
local NECK_LAG = { 0, 0.02, 0.04, 0.06 }
local TAIL_LAG_PER = 0.03
local TAIL_RIPPLE = 4.4 -- rad/s of the ripple that runs down the tail
local TAIL_RIPPLE_LAG = 0.85 -- rad of ripple phase per bone
-- the tail's pitch profile: an arch that curls up toward the tip (x tup, absolute radians)
local CURL = { 0.25, 0.6, 0.95, 1.2, 1.35 }
local CENTRE_W = { 1, 1, 1, 0.7 } -- the lean that keeps the head over the lane, per bone
local NECK_PATH_W = { 0.5, 0.3, 0.05, 0 }
local NECK_FOLLOW = { 0.95, 0.5, 0.15, 0 } -- how much of the body's turn the lower neck continues
local NECK_PATH_S = { -1.0, -3.0, -5.0, 0 }

type Ctx = {
	secs: number,
	wavePhase: number,
	wavelength: number,
	yawAt: ((number) -> number)?,
	speed: number,
	turn: number,
	seed: number,
	look: number?,
	neckPath: number?,
	bodyYaw: number?, -- circling: the body trails off to one side
}

local function compose(get: (number) -> Stance, ctx: Ctx): Pose
	local S0 = get(0)
	local pose: Pose = {}
	local t = ctx.secs

	-- the spine's ground curve, frozen in a stance or sliding in a loop
	local c = solver.curve(ctx.wavePhase + S0.wph, S0.th, ctx.wavelength)
	local pYaw, pPivot, pH = solver.lay(c, P.JointNeck)
	local follow: { [number]: number } = {}
	if ctx.yawAt and ctx.speed > 1 then
		solver.follow(ctx.yawAt, ctx.speed, ctx.turn, follow)
	end
	local circ = ctx.bodyYaw or 0
	local bodyYaw = pYaw + (follow[0] or 0) + S0.ryaw + circ

	local Rb0 = solver.bodyRot(bodyYaw, 0)
	local Rb = solver.bodyRot(bodyYaw, S0.bp, S0.rroll)
	local shift = V(S0.rx, S0.ry, S0.rz)
	local pivot = pPivot + Rb0 * solver.rearRel - Rb * solver.rearRel + shift
	pose.JointRoot = solver.rootTransform(Rb, pivot)
	local base = solver.bodyEnds(Rb, pivot)

	-- Neck: absolute orientations A = Ry(heading) * Rz(lean) * Rx(pitch - rest); the lean (a roll
	-- about the forward axis) also keeps the head over the lane, cancelling the sideways offset
	-- of the S under the neck base
	local E, Y, Z = table.create(4), table.create(4), table.create(4)
	for j = 1, 4 do
		local s = get(NECK_LAG[j])
		E[j] = s[ENAME[j]]
		Y[j] = s[YNAME[j]] + S0.ryaw + NECK_FOLLOW[j] * (bodyYaw - S0.ryaw - solver.bodyRestYaw) + (if ctx.look then ctx.look * math.min(1, j * 0.3) else 0)
		Z[j] = s[ZNAME[j]]
	end
	local np = ctx.neckPath or 0
	if np > 0 then
		for j = 1, 3 do
			Y[j] += np * NECK_PATH_W[j] * c.theta(NECK_PATH_S[j])
		end
	end
	local eps, nbone = solver.eps, solver.nbone
	local function neckAbs(lean: number): { CFrame }
		local abs = table.create(4)
		for j = 1, 4 do
			abs[j] = Serpent.ry(Y[j]) * CFrame.Angles(0, 0, Z[j] + lean * CENTRE_W[j]) * Serpent.rx(E[j] - eps[j])
		end
		abs[4] = abs[4] * CFrame.Angles(0, 0, S0.hr)
		return abs
	end
	local function headX(lean: number): number
		local abs = neckAbs(lean)
		local p = base
		for j = 1, 3 do
			p += abs[j] * nbone[j]
		end
		return p.X
	end
	local lean = 0
	if S0.cen > 0.001 then
		-- where the head would be with the base on the lane (same pose, shifted by the offset)
		local target = headX(0) - (base.X - shift.X)
		for _ = 1, 4 do
			local x0 = headX(lean)
			local slope = (headX(lean + 0.02) - x0) / 0.02
			if math.abs(slope) < 0.5 then
				break
			end
			lean = math.clamp(lean + (target - x0) / slope, -0.6, 0.6)
		end
		lean *= S0.cen
	end
	local nl = Serpent.locals(Rb, neckAbs(lean))
	for j = 1, 4 do
		pose[NECK[j]] = nl[j]
	end

	-- Tail: on the curve, plus the stance's bend and arch, plus the phase-lagged ripple
	local Yt, Ut = table.create(NT), table.create(NT)
	for k = 1, NT do
		local s = get(TAIL_LAG_PER * k)
		local w = math.min(1, k / 2.5)
		local yaw = pH[k] + (follow[k] or 0) + s.ryaw + circ * (1 - 0.15 * k)
		yaw += s.ty * w
		local f = (k - 1) / (NT - 1)
		yaw += s.tamp * 0.2 * (0.35 + 0.65 * f) * math.sin(t * TAIL_RIPPLE - k * TAIL_RIPPLE_LAG + ctx.seed)
		Yt[k] = yaw
		Ut[k] = solver.restUp[k] + s.tup * CURL[k]
	end
	local tl = solver.tailLocals(Yt, Ut, Rb)
	for k = 1, NT do
		pose[TAIL[k]] = tl[k]
	end

	-- Head parts
	local sh = get(0.05)
	local beat = math.floor(t * 0.5 + ctx.seed)
	local flick = math.max(0, math.sin((t * 0.5 + ctx.seed - beat) * math.pi * 6)) * (if hash(beat, ctx.seed) > 0.4 then 1 else 0)
	local jaw = math.clamp(sh.jaw + 0.2 * math.max(flick * 0.8, sh.tng * math.abs(math.sin(t * 19))), 0, 1.15)
	pose.JointJaw = CFrame.Angles(-0.95 * jaw, 0, 0)
	local flare = math.clamp(sh.hood, 0, 1)
	local amp = 0.015 * flare + 0.07 * sh.flt
	pose.JointHoodL = CFrame.Angles(0, -(1.15 * flare + amp * math.sin(t * 15)), 0)
	pose.JointHoodR = CFrame.Angles(0, 1.15 * flare + amp * math.sin(t * 15 + 1.3), 0)
	return pose
end

local function same(s: Stance): (number) -> Stance
	return function(_: number): Stance
		return s
	end
end

--------------------------------------------------------------------------------
-- Moves

local moves: { [string]: { [string]: Phase } } = {}
local function ph(duration: number, keys: { Key }, tremble: ((u: number) -> number)?, settle: number?, over: ((u: number) -> { [string]: number })?): Phase
	return { duration = duration, keys = keys, tremble = tremble, settle = settle, over = over }
end
local function k(t: number, s: Stance, ease: string?): Key
	return { t = t, s = s, ease = ease }
end

local IDLE = st(DEF, {})

-- VenomSpit ------------------------------------------------------------------
local SP_LEAN = st(IDLE, { E = { 50, 70, 83, -8 }, jaw = 0.1, hood = 0.12, rz = -0.2, tamp = 0.3 })
local SP_DRAW = st(IDLE, { E = { 62, 98, 118, 34 }, jaw = 0.55, hood = 0.55, flt = 0.5, rz = 0.5, bp = 0.04, tamp = 0.2, ty = 0.25, tup = 0.12 })
local SP_LOAD = st(SP_DRAW, { E = { 64, 102, 124, 40 }, jaw = 0.7, hood = 0.7, flt = 0.8, rz = 0.7, tup = 0.2 })
local SP_THROW = st(IDLE, { E = { 40, 58, 52, -30 }, jaw = 1.0, hood = 0.8, flt = 0.3, rz = -0.7, bp = 0.05, tamp = 1.0, tup = 0.05 })
local SP_FOLLOW = st(IDLE, { E = { 32, 46, 40, -40 }, jaw = 0.9, hood = 0.5, rz = -1.4, bp = 0.06, tamp = 1.2 })
local SP_SPENT = st(IDLE, { E = { 44, 62, 62, -16 }, jaw = 0.45, hood = 0.2, rz = -0.7, tamp = 0.8 })
local SP_SPENT2 = st(SP_SPENT, { jaw = 0.25, hood = 0.1, rz = -0.5 })
local SP_RISE = st(IDLE, { E = { 50, 70, 82, -6 }, jaw = 0.05, rz = -0.15 })
moves.VenomSpit = {
	windup = ph(1.1, {
		k(0, IDLE), k(0.13, SP_LEAN, "out"), k(0.40, SP_DRAW, "outBack"), k(0.46, SP_DRAW), k(0.54, SP_LOAD, "inOut"),
		k(0.60, SP_THROW, "in"), k(0.70, SP_FOLLOW, "out"), k(0.84, SP_FOLLOW), k(1, SP_SPENT, "inOut"),
	}, function(u)
		return 0.15 * smooth(0.13, 0.25, u) + 0.85 * window(u, 0.38, 0.45, 0.54, 0.58)
	end, nil, function(u)
		-- after the throw the neck rings down: the head bobs, the jaw snaps once
		local tt = math.max(0, (u - 0.636) * 1.1)
		local ring = math.sin(tt * TAU * 2.6) * math.exp(-5 * tt)
		return { e4 = D(12) * ring, e3 = D(6) * ring, e2 = D(3) * ring, jaw = 0.15 * math.max(0, ring), tamp = 0.6 * math.exp(-4 * tt) * (if u > 0.636 then 1 else 0) }
	end),
	active = ph(0.1, { k(0, SP_SPENT), k(1, SP_SPENT2, "out") }),
	recover = ph(0.6, { k(0, SP_SPENT2), k(0.5, SP_RISE, "inOut"), k(1, IDLE, "inOut") }, nil, 1.0, function(u)
		return { tng = window(u, 0.5, 0.58, 0.88, 0.95) }
	end),
}

-- HoodStrike -----------------------------------------------------------------
local HS_GATHER = st(IDLE, { E = { 44, 64, 72, -10 }, jaw = 0.25, hood = 0.25, flt = 0.4, rz = 0.35, tamp = 0.5 })
local HS_S = st(IDLE, { E = { 66, 96, 84, -6 }, jaw = 0.5, hood = 1.0, flt = 0.7, rz = 0.7, bp = 0.06, tamp = 0.3, ty = 0.3, tup = 0.1 })
local HS_COCK = st(HS_S, { E = { 69, 100, 88, -3 }, jaw = 0.6, rz = 0.95, bp = 0.1, tup = 0.18 })
local HS_DART = st(IDLE, { E = { 28, 38, 50, -22 }, jaw = 1.0, hood = 0.8, flt = 0.4, rz = -1.2, bp = 0.08, tamp = 1.1, th = 0.75 })
local HS_OVER = st(HS_DART, { E = { 26, 36, 46, -26 }, jaw = 0.9, hood = 0.75, rz = -1.8 })
local HS_RECOIL = st(IDLE, { E = { 58, 98, 112, 18 }, jaw = 0.4, hood = 0.7, rz = 0.3, tamp = 0.9 })
local HS_AIM = st(IDLE, { E = { 54, 76, 86, -2 }, hood = 0.15, Y = { 0.04, 0.1, 0.18, 0.22 }, tamp = 0.5 })
moves.HoodStrike = {
	windup = ph(0.6, {
		k(0, IDLE), k(0.16, HS_GATHER, "out"), k(0.52, HS_S, "outBack"), k(0.78, HS_S), k(1, HS_COCK, "inOut"),
	}, function(u) return window(u, 0.5, 0.58, 0.8, 0.95) end),
	active = ph(0.25, { k(0, HS_COCK), k(0.35, HS_DART, "snap"), k(1, HS_OVER, "out") }),
	recover = ph(0.8, {
		k(0, HS_OVER), k(0.12, HS_RECOIL, "out"), k(0.5, HS_AIM, "inOut"), k(1, IDLE, "inOut"),
	}, nil, 1.0),
}

-- HoodStrikeSkid: brace, the head whips round to the target first, then the neck, then the body
local SK_BRACE = st(IDLE, { E = { 24, 40, 52, -20 }, jaw = 0.7, hood = 0.9, flt = 0.3, rz = -1.0, bp = -0.02, tamp = 1.0 })
local SK_UP = st(IDLE, { E = { 56, 82, 88, 6 }, jaw = 0.2, hood = 0.4, rz = 0.1, tamp = 0.6 })
local SK_DELAY = { 0.16, 0.11, 0.06, 0.0 }
local SK_WEIGHT = { 0.3, 0.55, 0.85, 1.0 }
moves.HoodStrikeSkid = {
	recover = {
		duration = 0.8,
		fn = function(u: number, _secs: number, input: Input): Stance
			local base = keyed({ k(0, SK_BRACE), k(0.22, SK_BRACE), k(0.6, SK_UP, "inOut"), k(1, IDLE, "inOut") }, u)
			local s = table.clone(base)
			local yaw = input.targetYaw or (-1.3 * (input.side or 1))
			yaw = math.clamp(yaw, -1.4, 1.4)
			local fade = 1 - smooth(0.7, 1, u)
			for j = 1, 4 do
				s[YNAME[j]] += yaw * SK_WEIGHT[j] * smooth(SK_DELAY[j], SK_DELAY[j] + 0.16, u) * fade * 0.8
			end
			s.hr += -0.25 * yaw / 1.4 * smooth(0, 0.15, u) * fade
			s.ryaw += 0.3 * yaw * smooth(0.25, 0.6, u) * fade
			s.ty += -0.5 * yaw / 1.4 * smooth(0.1, 0.4, u) * fade
			return s
		end,
		settle = 1.0,
	},
}

-- Hop: the backslide, head up and facing the target, body lifting off a little
local HP_A = st(IDLE, { E = { 60, 90, 98, 0 }, jaw = 0.2, hood = 0.5, flt = 0.4, rz = 0.6, tamp = 1.0, th = 0.9 })
local HP_B = st(HP_A, { E = { 64, 96, 100, -2 }, hood = 0.6, rz = 1.2 })
moves.Hop = {
	active = {
		duration = 0.35,
		fn = function(u: number, _secs: number, _input: Input): Stance
			local s = lerpStance(HP_A, HP_B, math.sin(math.pi * u))
			local arch = math.sin(math.pi * u)
			s.ry = 0.35 * arch
			s.bp = 0.05 * arch
			s.y3 = 0.15 * arch * math.sin(u * TAU * 1.5)
			s.y2 = 0.1 * arch * math.sin(u * TAU * 1.5 - 0.6)
			return s
		end,
	},
	recover = ph(0.3, { k(0, HP_A), k(0.4, st(IDLE, { E = { 52, 74, 86, -4 }, rz = 0.2, jaw = 0.1 }), "out"), k(1, IDLE, "inOut") }, nil, 1.0),
}

-- TailSnap: written for the target on the RIGHT (mirror plays the left). The head turns away
-- (left), the tail arches up and bends round to the right, cocks back, then cracks down across.
local TS_TURN = st(IDLE, { E = { 48, 70, 80, -4 }, Y = { 0.12, 0.3, 0.5, 0.6 }, jaw = 0.15, hood = 0.25, rz = -0.1, tup = 0.25, ty = 0.35, tamp = 0.5 })
local TS_CURL = st(TS_TURN, { E = { 46, 68, 78, -6 }, Y = { 0.15, 0.36, 0.58, 0.7 }, tup = 0.95, ty = 0.95, tamp = 0.3, rz = -0.35, hood = 0.35 })
local TS_COCK = st(TS_CURL, { tup = 1.1, ty = 1.2, ryaw = -0.12, rz = -0.5, hood = 0.45, jaw = 0.25 })
local TS_CRACK = st(TS_TURN, { tup = 0.0, ty = -0.4, ryaw = 0.1, rz = 0.1, tamp = 1.6, hood = 0.5, jaw = 0.35 })
local TS_DRAG = st(IDLE, { E = { 50, 72, 82, -4 }, Y = { 0.08, 0.2, 0.32, 0.38 }, tup = 0.0, ty = -0.15, tamp = 0.9, hood = 0.2 })
moves.TailSnap = {
	windup = ph(0.7, {
		k(0, IDLE), k(0.22, TS_TURN, "inOut"), k(0.62, TS_CURL, "outBack"), k(0.86, TS_CURL), k(1, TS_COCK, "inOut"),
	}, function(u) return window(u, 0.6, 0.68, 0.88, 1.0) end, nil, nil),
	active = ph(0.1, { k(0, TS_COCK), k(1, TS_CRACK, "snap") }),
	recover = ph(0.8, { k(0, TS_CRACK), k(0.3, TS_DRAG, "out"), k(1, IDLE, "inOut") }, nil, 1.2),
}
moves.TailSnap.windup.mirror = true
moves.TailSnap.active.mirror = true
moves.TailSnap.recover.mirror = true

-- Stagger: the head thrown back and away from the hit, the body shoved, a quick shudder
moves.Stagger = {
	active = {
		duration = 0.28,
		fn = function(u: number, secs: number, input: Input): Stance
			local side = math.clamp(input.side or 0, -1, 1)
			local e = smooth(0, 0.25, u) * (1 - smooth(0.4, 1, u))
			local s = table.clone(IDLE)
			local shake = math.sin(secs * 42) * e
			s.e1 += D(-14) * e
			s.e2 += D(24) * e
			s.e3 += D(30) * e
			s.e4 += D(30) * e
			s.y3 += 0.3 * side * e
			s.y4 += 0.55 * side * e
			s.hr = 0.3 * side * e
			s.jaw = 0.9 * e
			s.hood = 0.5 * e
			s.flt = e
			s.rz = 0.9 * e
			s.rroll = 0.05 * shake
			s.ryaw = 0.05 * shake
			s.tamp = 0.35 + 1.0 * e
			return s
		end,
	},
}

-- Death: jolted back and up with the hood blown wide, a last rear, then it folds and drops its
-- head to the ground in a loose S
local DE_JOLT = st(IDLE, { E = { 34, 80, 118, 42 }, jaw = 1.0, hood = 1.0, flt = 1.0, rz = 1.4, bp = 0.1, tamp = 1.5, tup = 0.3 })
local DE_REAR = st(IDLE, { E = { 70, 105, 110, 25 }, jaw = 0.9, hood = 1.0, flt = 0.8, rz = 0.5, tamp = 1.2, Y = { 0.1, -0.2, 0.15, 0.2 } })
local DE_SAG = st(IDLE, { E = { 26, 42, 50, -30 }, jaw = 0.5, hood = 0.5, rz = -0.5, tamp = 0.8, Y = { 0.25, -0.4, 0.3, 0.3 }, th = 1.0 })
local DE_DROP = st(IDLE, { E = { 14, 10, 0, -24 }, Z = { 0.05, 0.1, 0.15, 0.15 }, Y = { 0.3, -0.4, 0.4, 0.3 }, jaw = 0.3, hood = 0.25, rz = -0.8, tamp = 0.4, th = 1.05, cen = 0.3 })
local DE_LOOSE = st(IDLE, { E = { 20, 2, -4, -26 }, Z = { 0.1, 0.2, 0.3, 0.3 }, Y = { 0.4, -0.6, 0.5, 0.4 }, jaw = 0.0, hood = 0.2, rz = -0.9, tamp = 0.0, th = 1.15, cen = 0, ryaw = 0.2 })
moves.Death = {
	active = {
		duration = 0.9,
		keys = {
			k(0, IDLE), k(0.1, DE_JOLT, "out"), k(0.3, DE_REAR, "inOut"), k(0.52, DE_SAG, "in"),
			k(0.74, DE_DROP, "in"), k(1, DE_LOOSE, "out"),
		},
		tremble = function(u) return 0.9 * (window(u, 0.08, 0.14, 0.3, 0.5)) end,
		settle = 0.6,
	},
}

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
VenomSerpent.moves = moves
VenomSerpent.durations = durationsOf()

--------------------------------------------------------------------------------
-- Sampling

-- ring-down after an impact: the neck leads, the head trails, the tail whips last
local function settle(s: Stance, amp: number, tc: number)
	local function ring(delay: number, hz: number): number
		local t = math.max(0, tc - delay)
		return math.sin(t * TAU * hz) * math.exp(-4.5 * t) * amp
	end
	s.e1 += 0.06 * ring(0, 2.2)
	s.e2 += 0.08 * ring(0.04, 2.4)
	s.e3 += 0.1 * ring(0.08, 2.6)
	s.e4 += 0.16 * ring(0.12, 3)
	s.y3 += 0.08 * ring(0.1, 2)
	s.ty += 0.12 * ring(0.1, 1.8)
	s.jaw += 0.08 * math.max(0, ring(0.1, 3))
	s.rroll += 0.02 * ring(0.02, 2.6)
end

local function stanceAt(move: string, phase: string, u: number, input: Input, lag: number): Stance
	local p = moves[move][phase]
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
	if p.mirror and (input.side or 1) < 0 then
		s = mirrored(s)
	end
	local amp = if p.tremble then p.tremble(uu) else 0
	if amp > 0.01 then
		for j = 1, 4 do
			s[YNAME[j]] += 0.02 * amp * math.sin(secs * (9 + j * 1.3) + j)
			s[ENAME[j]] += 0.016 * amp * math.sin(secs * (7 + j * 1.1) + j * 0.7)
		end
		s.rroll += 0.012 * amp * math.sin(secs * 13)
		s.ry += -0.03 * amp * (0.5 + 0.5 * math.sin(secs * 17))
		s.hood += 0.04 * amp * math.sin(secs * 9)
		s.flt = math.max(s.flt, 0.5 * amp)
		s.tamp += 0.5 * amp
	end
	if p.over then
		for key, v in p.over(uu) do
			s[key] += v
		end
	end
	if p.settle and phase ~= "windup" then
		local tc = secs + (if phase == "recover" then (VenomSerpent.durations[move].active or 0) else 0)
		settle(s, p.settle * smooth(0, 0.08, secs), tc)
	end
	return s
end

function VenomSerpent.sample(move: string, phase: string, u: number, input: Input?): Pose
	local inp: Input = input or {}
	u = math.clamp(u, 0, 1)
	local p = moves[move][phase]
	assert(p, ("VenomSerpent.sample: no %s.%s"):format(move, phase))
	local dur = inp.duration or p.duration
	local fade = if move == "Death" then smooth(0, 0.2, u) else smooth(0, 0.2, u) * (1 - smooth(0.8, 1, u))
	local cache: { [number]: Stance } = {}
	local function get(lag: number): Stance
		local key = lag * fade
		local s = cache[key]
		if not s then
			s = stanceAt(move, phase, u, inp, key)
			cache[key] = s
		end
		return s :: Stance
	end
	local secs = u * dur
	local wave = inp.wavePhase or 0
	if move == "Hop" and phase == "active" then
		-- the wave runs the other way: the engine advances the phase by `rate` rad/s while the
		-- hop's speed lasts; run it backward from where it started, a whole number of cycles
		local speed = inp.speed
		if not speed or speed < 4 then
			speed = 9 / 0.35
		end
		local th0, wl = slitherParams(speed)
		local rate = TAU / wl * Serpent.slideSpeed(speed, th0)
		local cycles = math.max(1, math.floor(2 * rate * dur / TAU + 0.5))
		wave -= cycles * TAU * u
	end
	local ctx: Ctx = {
		secs = inp.time or secs, wavePhase = wave, wavelength = WAVELENGTH, yawAt = nil,
		speed = 0, turn = 0, seed = inp.seed or 0,
	}
	return compose(get, ctx)
end

--------------------------------------------------------------------------------
-- Loops

local function mix(a: { number }, b: { number }, t: number): { number }
	local out = {}
	for j = 1, 4 do
		out[j] = a[j] + (b[j] - a[j]) * t
	end
	return out
end

-- the wave's phase rate: k * the sliding speed, so the curve stays fixed on the ground while the
-- body slides along it at `speed` mean ground speed
function VenomSerpent.gaitRate(loop: string, speed: number, scale: number?): number
	if loop == "walk" or loop == "run" or loop == "circle" then
		local th0, wl = slitherParams(speed)
		return TAU / wl * Serpent.slideSpeed(speed, th0)
	end
	return 1
end

local function loopCtx(phase: number, speed: number, input: Input?): Ctx
	local inp = input or {}
	local _, wl = slitherParams(speed)
	return {
		secs = inp.time or os.clock(), wavePhase = phase, wavelength = wl, yawAt = inp.yawAt, speed = speed,
		turn = inp.turn or 0, seed = inp.seed or 0,
	}
end

local REST_DEG = { math.deg(solver.eps[1]), math.deg(solver.eps[2]), math.deg(solver.eps[3]), 0 }
local WALK_N = { 46, 72, 84, -2 }
local RUN_N = { 36, 54, 60, -8 }

local loops: { [string]: (number, number, Input?) -> Pose } = {}

-- idle: the S it stopped in sways (the wave phase drifts a little), the neck sways on a
-- phase-lagged line with the head last, the hood breathes and flutters, the tail ripples, the
-- tongue flicks on a hashed beat
function loops.idle(t: number, speed: number, input: Input?): Pose
	local inp = input or {}
	local seed = inp.seed or 0
	local s = table.clone(IDLE)
	local LEAN_A = { 0.1, 0.09, 0.08, 0.05 }
	for j = 1, 4 do
		-- a lateral S down the column: each bone's sway trails the one below it
		s[ZNAME[j]] = LEAN_A[j] * math.sin(t * 0.7 + seed - 0.9 * (j - 1))
		s[YNAME[j]] = 0.05 * math.sin(t * 0.7 + seed - 0.9 * j) + 0.022 * math.sin(t * 1.9 + j)
		s[ENAME[j]] += 0.035 * math.sin(t * 1.4 + seed - 0.45 * j)
	end
	s.e4 += 0.06 * math.sin(t * 0.8 + 1)
	s.hood = 0.07 + 0.045 * math.sin(t * 1.5)
	s.flt = 0.15
	s.ty = 0.08 * math.sin(t * 0.5 + seed)
	s.wph = 0.35 * math.sin(t * 0.45 + seed)
	s.tamp = 0.55
	local ctx = loopCtx(inp.wavePhase or 0, 0, input)
	ctx.wavelength = WAVELENGTH
	ctx.secs = t
	return compose(same(s), ctx)
end

local function slither(phase: number, speed: number, input: Input?, neck: { number }, look: number?, body: number?): Pose
	local s = table.clone(IDLE)
	for j = 1, 4 do
		s[ENAME[j]] = D(neck[j])
	end
	local th0 = slitherParams(speed)
	s.th = th0
	s.bp = 0.05 + 0.07 * smooth(4, 10, speed) -- the front lifts so the neck base clears the ground
	s.tamp = 0.25
	local t = (input and input.time) or os.clock()
	s.e4 += 0.05 * math.sin(t * 1.6)
	s.hood = 0.03 * (0.5 + 0.5 * math.sin(t * 1.5))
	local ctx = loopCtx(phase, speed, input)
	ctx.neckPath = 1
	ctx.look = look
	ctx.bodyYaw = body
	return compose(same(s), ctx)
end

function loops.walk(phase: number, speed: number, input: Input?): Pose
	local f = smooth(0.6, 5, speed)
	return slither(phase, speed, input, mix(mix(REST_DEG, WALK_N, 0.5), WALK_N, f))
end

function loops.run(phase: number, speed: number, input: Input?): Pose
	local f = smooth(6, 10, speed)
	return slither(phase, speed, input, mix(WALK_N, RUN_N, f))
end

-- circle: a sideways sway. The head stays on the target while the body trails off to the side
-- it is moving away from, so the S reads as a crab-like sidewind.
function loops.circle(phase: number, speed: number, input: Input?): Pose
	local inp = input or {}
	local dir = inp.dir or 1
	local f = smooth(4, 10, speed)
	return slither(phase, speed, input, mix(WALK_N, RUN_N, f), math.clamp(inp.targetYaw or 0, -0.7, 0.7) * 0.8, 0.55 * dir)
end

VenomSerpent.loops = loops

-- a pose straight from a stance (the idle one with `changes` applied, see st()): for QA and for
-- hand-posing in Studio
function VenomSerpent.poseFromStance(changes: { [string]: any }?, wavePhase: number?): Pose
	local ctx = loopCtx(wavePhase or 0, 0, nil)
	ctx.secs = 0
	return compose(same(st(IDLE, changes)), ctx)
end
VenomSerpent.USES_HISTORY = true -- EnemyAnimator supplies phase, speed, turn, yawAt, time, wavePhase, still, travel
VenomSerpent.LEAD = { HoodStrikeSkid = true }

-- no legs to plant
function VenomSerpent.plant(pose: Pose): Pose
	return pose
end

-- poses are in real studs (SCALE = 1); kept for the family API
function VenomSerpent.scaled(pose: Pose, scale: number): Pose
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

return VenomSerpent
