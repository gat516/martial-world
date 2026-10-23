--!nonstrict
-- Procedural pose tables for the Blood Centipede (Enemies.BloodCentipede, scale 1; rig table
-- in art/enemies/beasts/rigs/blood-centipede.md ("Blood Centipede", notes in art/enemies/beasts/poses_blood_centipede.md).
-- Same pose API as Wolf.luau / VenomSerpent.luau; pure tables, no instances, no gameplay decisions.
--
-- FAMILIES registration (EnemyAnimator.luau; the animator may not edit it, the designer pastes it):
--   local bloodCentipedeModule = script.Parent.EnemyPoses:FindFirstChild("BloodCentipede")
--   local BloodCentipede = if bloodCentipedeModule then require(bloodCentipedeModule :: ModuleScript) :: any else nil
--   if BloodCentipede then
--       FAMILIES.BloodCentipede = {
--           poses = BloodCentipede, scale = 1, runFrom = 12, keyedBlend = 0.1, staggerSeconds = 0.4, deathSeconds = 2.0,
--           moves = { pincerSnap = "PincerSnap", coilSweep = "CoilSweep", burrowDive = "BurrowDive", erupt = "Erupt" },
--       }
--   end
-- (the Template attribute is "BloodCentipede"; poses USES_HISTORY, so EnemyAnimator supplies
-- input.wavePhase, .time, .speed, .turn, .yawAt and advances the phase with gaitRate in every state)
--
-- UNITS: real studs in model space (1x body, faces -Z, left is -X). The body is a CHAIN:
-- JointRoot (Collar) -> JointSeg1..12 -> JointTail, 0.8 stud plates, each joint's transform is
-- RELATIVE to the plate before it, and a bend over 0.25 rad per joint gaps the plates. This
-- module therefore authors ABSOLUTE heading (yaw) and pitch per plate (a wave, a rear, a curl),
-- differences them into the joints and clamps every step at 0.25 (Centipede.lastMaxStep is the
-- biggest step the last pose asked for before the clamp, for QA).
--
-- PLANTING: a chain pose is anchored by solving JointRoot's translation: the tail end (or the
-- node `anchor`) stays at its rest spot, lowered by `sink` and shifted by `slideZ`, and the body
-- is recentred sideways by `cx` of its mean offset. So "rear" (the front rises, the rear stays
-- down) and a curl never float or slide the tail by themselves; sink > 0 buries the body.
-- Burrowed (hidden) needs sink 3.4 (antenna tips at 2.9 above the ground at rest).
--
-- Move name map (def.attack -> module move):
--   pincerSnap -> PincerSnap   coilSweep -> CoilSweep   burrowDive -> BurrowDive   erupt -> Erupt
--
-- Move         windup / active / recover (the module's seconds; EnemyAnimator plays an attack's
--              active beat FIRST inside the server recover, so the posed recover is recover - active)
-- PincerSnap   0.60 / 0.10 / 0.80 (server 0.9)
-- CoilSweep    0.90 / 0.15 / 0.85 (server 1.0)
-- BurrowDive   0.50 / dash (input.duration, up to 0.75) / 0.30 (the dive is timed in seconds from the
--                dash start, compressed for a short lane)
-- Erupt        0.70 / none / 1.10 (starts sunk; the strike is the end of the windup)
-- Stagger      0.40 (input.side: the head is thrown away from the hit)
-- Death        2.00 then hold u = 1
--
-- BEATS (all start on the AIState's StateAt, where telegraph, tell flare and sound begin)
--   PincerSnap windup: 0-0.09 s a tight dip (the head ducks, the body loads back, the legs tense),
--     0.09-0.30 the front 9 plates rear to 55 degrees with the head cocked back, the pincers
--     thrown wide open (the user's "rear and spread"), the antennae flaring and the raised legs
--     scrabbling in the air; 0.30-0.48 the held beat (a tremble); 0.48-0.60 it cocks back one more
--     notch. active: the head and body lunge 1.4 studs forward and down, the pincers slam shut.
--     recover: the clamp, a head shake, a slow recoil and re-open, a damped ring, settle.
--   CoilSweep windup: a dip, then the rear half curls to one side (a lagged wave of yaw from the
--     collar to the tail) while the front half rears; held and trembling; cocked. active: the tail
--     half whips across to the other side with a lag per plate (0.008 s) so the tip trails and
--     cracks; recover: the overshoot rings out, then it unwinds and lowers.
--   BurrowDive windup: rears tall, the pincers open, then tips its head over; active: the head
--     plunges, the body follows down its own entry curve and runs flat below ground with a fast wave.
--   Erupt: sunk and rumbling; the front surges up through the mound (the whole chain inclined, the
--     tail still in the hole), the rest flows out; at u = 1 the front half is reared, the pincers
--     spread, the rear half on the ground. recover: the front crashes down with a squash and
--     rebound, the legs and antennae shake the dirt off, a head shake, settle.
-- LOOPS: idle (a slow travelling wave, head scan, antennae whips, pincer clicks, a leg ripple now
--   and then); walk and run (the slither wave 15 / 12 studs long; legs ripple at 3 leg cycles per
--   wave cycle with 0.9 rad of lag per plate, the front leg of each pair half a cycle ahead of the
--   other; the body trails the head through turns by the travel-heading history).
--
-- API
--   BloodCentipede.sample(move, phase, u, input?) -> Pose
--   BloodCentipede.loops.idle(clock, speed, input?) / walk(phase, speed, input?) / run / circle (= walk)
--   BloodCentipede.gaitRate(loop, speed, scale?), .scaled(pose, scale), .plant(pose) (no-op)
--   BloodCentipede.moves, .durations, .JOINTS, .SCALE, .USES_HISTORY, .lastMaxStep

local BloodCentipede = {}

export type Pose = { [string]: CFrame }
export type Input = {
	duration: number?,
	side: number?,
	seed: number?,
	speed: number?,
	turn: number?,
	yawAt: ((number) -> number)?,
	time: number?,
	wavePhase: number?,
	phase: number?,
	still: number?,
	travel: number?,
	rested: number?,
	dir: number?,
	targetYaw: number?,
}

local V = Vector3.new
local TAU = math.pi * 2
local LIM = 0.25
local SINK = 3.4
BloodCentipede.SCALE = 1
BloodCentipede.USES_HISTORY = true
BloodCentipede.lastMaxStep = 0

--------------------------------------------------------------------------------
-- Skeleton

-- chain nodes 0..13 (0 = the collar's JointRoot, 1..12 = JointSeg, 13 = JointTail), model space
local NODE: { [number]: Vector3 } = { [0] = V(0, 1.3, -4.9) }
for i = 1, 12 do
	NODE[i] = V(0, 1.2, -4.3 + 0.8 * (i - 1))
end
NODE[13] = V(0, 1.2, 5.3)
local NN = 13

local JOINTS = { "JointRoot", "JointHead", "JointJawL", "JointJawR", "JointAntL", "JointAntR" }
for i = 1, 12 do
	table.insert(JOINTS, "JointSeg" .. i)
end
table.insert(JOINTS, "JointTail")
for i = 1, 12 do
	table.insert(JOINTS, "JointLegL" .. i)
	table.insert(JOINTS, "JointLegR" .. i)
end
BloodCentipede.JOINTS = JOINTS

--------------------------------------------------------------------------------
-- Maths

local function smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local EASE = {
	linear = function(a: number): number
		return a
	end,
	["in"] = function(a: number): number
		return a * a
	end,
	out = function(a: number): number
		return 1 - (1 - a) * (1 - a)
	end,
	inOut = function(a: number): number
		return a * a * (3 - 2 * a)
	end,
	snap = function(a: number): number
		return 1 - (1 - a) ^ 4
	end,
	outBack = function(a: number): number
		local c = 1.4
		return 1 + (c + 1) * (a - 1) ^ 3 + c * (a - 1) ^ 2
	end,
}
local function ring(t: number, f: number, d: number): number
	return math.exp(-d * math.max(t, 0)) * math.cos(TAU * f * math.max(t, 0))
end
local function hash(n: number): number
	local x = math.sin(n * 127.1 + 311.7) * 43758.5453
	return x - math.floor(x)
end
-- a bump that rises over [a, b], holds, and falls over [c, d]
local function window(x: number, a: number, b: number, c: number, d: number): number
	return smooth(a, b, x) * (1 - smooth(c, d, x))
end

--------------------------------------------------------------------------------
-- The stance: named scalars. Keys inherit the fields they don't list from the key before.

local DEF = {
	rear = 0, rearN = 9, -- the front rises: abs pitch at the collar, tapering to 0 at node rearN
	tailUp = 0,
	yaw0 = 0, curl = 0, curlFrom = 3, -- abs heading at the collar; curl = extra heading at the tail, linear from node curlFrom
	wave = 0, wph = 0, k = TAU / 13, -- heading wave: amplitude (rad), phase (rad), wavenumber (rad per stud)
	hump = 0, -- a travelling pitch wave (rad)
	sink = 0, slideZ = 0, lift = 0, cx = 0.6, ox = 0, anchor = 13,
	headP = 0, headY = 0, headLevel = 0,
	jaw = 0, -- + open (JawL +Y, JawR -Y); about -0.5 is a full close
	antP = 0, antS = 0, antSw = 0, antPh = 0,
	-- legLiftF lifts only the reared plates' legs
	legPh = 0, legLag = 0.9, legSw = 0, legLf = 0, legLift0 = 0, legLiftF = 0, legFore = 0, legScr = 0, rip = 0, ripPos = 0,
	shk = 0, shkT = 0,
}
type Stance = { [string]: any }

local function build(keys: { Stance }, from: Stance?): { Stance }
	local out = {}
	local prev = from or DEF
	for _, k in keys do
		local s = table.clone(prev)
		for n, v in k do
			s[n] = v
		end
		out[#out + 1] = s
		prev = s
	end
	return out
end

local function at(built: { Stance }, t: number): Stance
	local first = built[1]
	if t <= first.t then
		return table.clone(first)
	end
	for i = 2, #built do
		local b = built[i]
		if t <= b.t then
			local a = built[i - 1]
			local f = EASE[b.e or "inOut"]((t - a.t) / math.max(1e-6, b.t - a.t))
			local s = table.clone(b)
			for n, bv in b do
				local av = a[n]
				if type(bv) == "number" and type(av) == "number" and n ~= "t" then
					s[n] = av + (bv - av) * f
				end
			end
			return s
		end
	end
	return table.clone(built[#built])
end

local function last(built: { Stance }): Stance
	return built[#built]
end

--------------------------------------------------------------------------------
-- Compose a stance into joint transforms

local function shape(j: number, n: number): number
	if j >= n then
		return 0
	end
	return 0.5 * (1 + math.cos(math.pi * j / n))
end

local lastMaxStep = 0

local function compose(st: Stance, t: number): Pose
	local pa, ya = {}, {}
	local rear, rn = st.rear, st.rearN
	local curlFrom = st.curlFrom
	local waveRaw, mean = {}, 0
	local hasWave = st.wave ~= 0
	for j = 0, NN do
		if hasWave then
			local env = 0.55 + 0.5 * j / NN
			waveRaw[j] = st.wave * env * math.sin(st.k * 0.8 * j - st.wph)
			mean += waveRaw[j] / (NN + 1)
		end
	end
	local yprof, pprof = st.yawProf, st.pitProf
	for j = 0, NN do
		local p = rear * shape(j, rn) + st.tailUp * smooth(7, 13, j)
		if st.hump ~= 0 then
			p += st.hump * math.sin(st.k * 0.8 * j - st.wph + 1.2)
		end
		local y = st.yaw0 + st.curl * math.clamp((j - curlFrom) / (NN - curlFrom), 0, 1)
		if hasWave then
			y += waveRaw[j] - mean
		end
		if st.shk ~= 0 then
			local w = shape(j, rn + 3)
			p += st.shk * w * math.sin(41 * t + 0.7 * j)
			y += 0.7 * st.shk * w * math.sin(37 * t + 1.3 * j)
		end
		if yprof then
			y += yprof[j] or 0
		end
		if pprof then
			p += pprof[j] or 0
		end
		pa[j], ya[j] = p, y
	end

	local pose: Pose = {}
	-- each plate's ABSOLUTE orientation is a true heading then a pitch about its own side axis,
	-- A = Ry(yaw) * Rx(pitch) (so a curl on a reared body stays level); the joint turns by
	-- A(j-1)^-1 * A(j). The step is clamped per axis before the orientations are built.
	local R0 = CFrame.Angles(0, ya[0], 0) * CFrame.Angles(pa[0], 0, 0)
	local A = R0
	local M = CFrame.new(NODE[0]) * R0
	local pos = { [0] = NODE[0] }
	local steps = {}
	local maxStep = 0
	local cp, cy = pa[0], ya[0]
	for j = 1, NN do
		local dp, dy = pa[j] - pa[j - 1], ya[j] - ya[j - 1]
		maxStep = math.max(maxStep, math.sqrt(dp * dp + dy * dy))
		cp += math.clamp(dp, -LIM, LIM)
		cy += math.clamp(dy, -LIM, LIM)
		local Aj = CFrame.Angles(0, cy, 0) * CFrame.Angles(cp, 0, 0)
		local T = A:Inverse() * Aj
		A = Aj
		M = M * CFrame.new(NODE[j] - NODE[j - 1]) * T
		pos[j] = M.Position
		steps[j] = T
	end
	lastMaxStep = maxStep
	BloodCentipede.lastMaxStep = maxStep

	local meanX = 0
	for j = 1, NN do
		meanX += pos[j].X / NN
	end
	local a = st.anchor
	local trans = V(
		-st.cx * meanX + st.ox,
		NODE[a].Y - st.sink + st.lift - pos[a].Y,
		NODE[a].Z + st.slideZ - pos[a].Z
	)
	pose.JointRoot = CFrame.new(trans) * R0
	for j = 1, 12 do
		pose["JointSeg" .. j] = steps[j]
	end
	pose.JointTail = steps[13]

	-- head, pincers, antennae
	pose.JointHead = CFrame.Angles(st.headP, st.headY - st.headLevel * ya[0], 0)
	pose.JointJawL = CFrame.Angles(0, st.jaw, 0)
	pose.JointJawR = CFrame.Angles(0, -st.jaw, 0)
	local sw, ph = st.antSw, st.antPh
	local pL = st.antP + 0.6 * sw * math.sin(ph * 1.3 + 1)
	local pR = st.antP + 0.6 * sw * math.sin(ph * 1.3 + 2.3)
	pose.JointAntL = CFrame.Angles(pL, st.antS + sw * math.sin(ph), 0)
	pose.JointAntR = CFrame.Angles(pR, -(st.antS + sw * math.sin(ph + 0.9)), 0)

	-- legs: a ripple down the plates (swing about Y, lift about Z); the raised plates scrabble
	local wRear = math.clamp(rear / 0.6, 0, 1)
	for i = 1, 12 do
		local w = st.legScr * shape(i, rn) * wRear
		local lag = st.legPh - st.legLag * i
		local amp = st.legSw * (1 + 1.2 * w)
		local nearPulse = 0
		if st.rip ~= 0 then
			local d = (i - st.ripPos) / 1.6
			nearPulse = st.rip * math.exp(-d * d)
		end
		for _, side in { -1, 1 } do
			local th = lag + (if side > 0 then math.pi else 0)
			local swing = amp * math.sin(th) + st.legFore
			local lift = st.legLf * (1 + 0.6 * w) * math.max(0, math.cos(th)) + st.legLift0 + st.legLiftF * shape(i, rn + 2) + 0.5 * w + 0.4 * nearPulse
			-- left: lift is -Z, a foot forward is -Y; right: +Z, +Y
			pose[(if side < 0 then "JointLegL" else "JointLegR") .. i] = CFrame.Angles(0, side * swing, side * lift)
		end
	end
	return pose
end

--------------------------------------------------------------------------------
-- Moves

local MOVES = {} -- [move] = { windup = {duration, fn}, active = ..., recover = ... }
local durations = {}
local function def(name: string, phases: { [string]: { number | ((number, number, Input) -> Stance) } })
	MOVES[name] = {}
	durations[name] = {}
	for ph, spec in phases do
		MOVES[name][ph] = { duration = spec[1] }
		MOVES[name][ph].fn = spec[2]
		durations[name][ph] = spec[1]
	end
end

local function keyed(keys: { Stance }, from: Stance?, over: ((Stance, number, number, Input) -> ())?): ((number, number, Input) -> Stance, { Stance })
	local built = build(keys, from)
	return function(u: number, secs: number, input: Input): Stance
		local t = u * secs
		local s = at(built, t)
		if over then
			over(s, t, u, input)
		end
		return s
	end, built
end

-- PincerSnap -------------------------------------------------------------------
local PS_W, PS_WB = keyed({
	{ t = 0 },
	{ t = 0.09, e = "inOut", rear = -0.07, rearN = 6, headP = -0.12, slideZ = 0.3, legLift0 = 0.12, jaw = 0.1, antP = -0.1, antS = 0.1 },
	{ t = 0.30, e = "out", rear = 0.95, rearN = 9, headP = -0.55, jaw = 0.75, antP = 0.45, antS = 0.7, slideZ = 0.9, legScr = 1, legLf = 0.5, legSw = 0.4, legLift0 = 0.04, legLiftF = 0.3 },
	{ t = 0.48, e = "inOut", rear = 1.02, jaw = 0.82, slideZ = 1.0, shk = 0.03, antSw = 0.15 },
	{ t = 0.60, e = "inOut", rear = 1.10, headP = -0.62, jaw = 0.86, slideZ = 1.15, shk = 0.045, antSw = 0.2 },
}, nil, function(s, t)
	s.legPh = 15 * t
	s.antPh = 24 * t
end)
local PS_A, PS_AB = keyed({
	{ t = 0 },
	{ t = 0.04, e = "in", rear = 0.3, headP = -0.15, jaw = 0.86, slideZ = -0.3, antP = -0.2, antS = 0.2, shk = 0 },
	{ t = 0.075, e = "in", rear = 0.1, rearN = 8, headP = -0.05, jaw = -0.45, slideZ = -1.4, antP = -0.35, antS = -0.1, legLift0 = 0.15, legLiftF = 0, legLf = 0.2, legSw = 0.2 },
	{ t = 0.10, e = "out", rear = 0.06, jaw = -0.48, slideZ = -1.45, headP = 0.1 },
}, last(PS_WB), function(s, t)
	s.legPh = 15 * (0.6 + t)
	s.antPh = 24 * (0.6 + t)
end)
def("PincerSnap", {
	windup = { 0.6, PS_W },
	active = { 0.1, PS_A },
	recover = { 0.8, (function()
		local fn = keyed({
			{ t = 0 },
			{ t = 0.10, e = "out", jaw = -0.4, slideZ = -1.3, rear = 0.1, headP = 0.1 },
			{ t = 0.30, e = "inOut", rear = 0.42, rearN = 9, jaw = 0.2, slideZ = -0.55, headP = -0.25, antP = 0.2, antS = 0.3, legLift0 = 0.15 },
			{ t = 0.56, e = "inOut", rear = 0.15, jaw = 0.05, slideZ = -0.1, headP = -0.05, antP = 0, antS = 0, legLift0 = 0.05 },
			{ t = 0.80, e = "inOut", rear = 0, jaw = 0, slideZ = 0, headP = 0, legLift0 = 0, legLiftF = 0, legLf = 0, legSw = 0 },
		}, last(PS_AB), function(s, t)
			-- a head shake while it clamps, then a damped ring of the raised front and the antennae
			s.headY = 0.35 * math.exp(-6 * t) * math.sin(TAU * 4.2 * t)
			s.rear += 0.05 * ring(t - 0.3, 3, 4) * smooth(0.3, 0.32, t)
			s.legPh = 15 * (0.7 + t)
			s.antSw = 0.3 * math.exp(-3 * t)
			s.antPh = 22 * t
		end)
		return fn
	end)() },
})

-- CoilSweep ---------------------------------------------------------------------
local CURL = 1.35
-- the tail half's heading multiplier through the sweep (time since the active began; 1.12 = the
-- windup's cocked curl, -1.1 the far side), shared by the active and the recover
local function coilPhi(t: number): number
	if t <= 0 then
		return 1.12
	elseif t < 0.24 then
		return 1.12 + (-1.1 - 1.12) * EASE.inOut(t / 0.24)
	elseif t < 0.5 then
		return -1.1 + 0.2 * EASE.out((t - 0.24) / 0.26)
	end
	return -0.9 * (1 - EASE.inOut(math.min(1, (t - 0.5) / 0.5)))
end
local COIL_LAG = 0.008
local function coilYawProf(tAbs: number): { number }
	local prof = {}
	for j = 0, NN do
		local c = math.clamp((j - 3) / 10, 0, 1)
		prof[j] = CURL * c * coilPhi(tAbs - COIL_LAG * math.max(0, j - 3))
	end
	return prof
end
local CS_W, CS_WB = keyed({
	{ t = 0 },
	{ t = 0.10, e = "inOut", rear = -0.04, rearN = 7, headP = -0.05, slideZ = 0.25, legLift0 = 0.12 },
	{ t = 0.52, e = "out", rear = 0.82, rearN = 9, headP = -0.45, jaw = 0.7, antP = 0.4, antS = 0.6, slideZ = 0.6, legScr = 1, legLf = 0.4, legSw = 0.35, legLift0 = 0.04, legLiftF = 0.25, yaw0 = 0.1 },
	{ t = 0.78, e = "inOut", rear = 0.86, jaw = 0.78, shk = 0.03 },
	{ t = 0.90, e = "inOut", rear = 0.9, jaw = 0.85, slideZ = 0.8, shk = 0.04, headP = -0.52 },
}, nil, function(s, t)
	-- the curl: a wave of heading from the collar to the tail (each plate 0.03 s behind the one before)
	local prof = {}
	for j = 0, NN do
		local c = math.clamp((j - 3) / 10, 0, 1)
		local lagged = t - 0.028 * math.max(0, j - 3)
		local m = 1.12 * EASE.inOut(math.clamp((lagged - 0.08) / 0.52, 0, 1))
		prof[j] = CURL * c * m
	end
	s.yawProf = prof
	s.legPh = 14 * t
	s.antPh = 22 * t
end)
local CS_A, CS_AB = keyed({
	{ t = 0 },
	{ t = 0.075, e = "inOut", rear = 0.7, jaw = 0.7, shk = 0, yaw0 = -0.05, slideZ = 0.3, headP = -0.4, legLiftF = 0.15 },
	{ t = 0.15, e = "inOut", rear = 0.55, yaw0 = -0.28, jaw = 0.4, slideZ = 0, headP = -0.3, antS = 0.2 },
}, last(CS_WB), function(s, t)
	s.yawProf = coilYawProf(t)
	s.legPh = 14 * (0.9 + t)
end)
def("CoilSweep", {
	windup = { 0.9, CS_W },
	active = { 0.15, CS_A },
	recover = { 0.85, (function()
		local fn = keyed({
			{ t = 0 },
			{ t = 0.2, e = "out", rear = 0.55, yaw0 = -0.3, jaw = 0.25, headP = -0.2, slideZ = 0, antS = 0.1 },
			{ t = 0.55, e = "inOut", rear = 0.3, yaw0 = -0.12, jaw = 0.1, headP = -0.08, antS = 0 },
			{ t = 0.85, e = "inOut", rear = 0, yaw0 = 0, jaw = 0, headP = 0, legSw = 0, legLf = 0, legLift0 = 0, legLiftF = 0, legScr = 0 },
		}, last(CS_AB), function(s, t)
			s.yawProf = coilYawProf(0.15 + t)
			s.rear += 0.04 * ring(t, 2.2, 2.5)
			s.legPh = 14 * (1.05 + t)
		end)
		return fn
	end)() },
})

-- BurrowDive ----------------------------------------------------------------------
local BD_W, BD_WB = keyed({
	{ t = 0 },
	{ t = 0.10, e = "inOut", rear = 0.15, rearN = 6, headP = -0.1, slideZ = 0.3, legLift0 = 0.15, jaw = 0.2 },
	{ t = 0.30, e = "out", rear = 1.0, rearN = 9, headP = -0.4, jaw = 0.55, antP = 0.3, antS = 0.5, slideZ = 0.8, legScr = 1, legLf = 0.5, legSw = 0.4, legLift0 = 0.04, legLiftF = 0.3 },
	{ t = 0.42, e = "inOut", rear = 1.1, headP = -0.75, jaw = 0.65, shk = 0.03, slideZ = 0.9, antSw = 0.15 },
	{ t = 0.50, e = "inOut", rear = 1.14, headP = -0.95, shk = 0.04, slideZ = 1.0 },
}, nil, function(s, t)
	s.legPh = 15 * t
	s.antPh = 22 * t
end)
local BD_Akeys = {
	{ t = 0 },
	{ t = 0.12, e = "in", rear = -0.8, rearN = 9, headP = 0.55, jaw = 0.3, antP = -0.4, antS = 0.1, slideZ = -1.0, sink = 0.9, shk = 0, legSw = 0.3, legLiftF = 0 },
	{ t = 0.30, e = "inOut", rear = -0.35, headP = 0.2, sink = 3.0, slideZ = -0.3, jaw = 0, legLf = 0, legSw = 0, legScr = 0, legLift0 = 0, legLiftF = 0, antP = -0.2 },
	{ t = 0.45, e = "out", rear = 0, headP = 0, sink = SINK, slideZ = 0, antP = 0, antS = 0, wave = 0.4 },
}
local BD_ASTATES = build(BD_Akeys, last(BD_WB))
local BD_A = function(u: number, secs: number, input: Input): Stance
	-- timed in seconds from the dash start; a short lane compresses the dive so it still finishes
	local f = math.clamp(secs / 0.5, 0.45, 1)
	local s = at(BD_ASTATES, u * secs / f)
	s.k = TAU / 10
	local t = u * secs
	local wp = input and input.wavePhase or 0
	s.wph = wp * 2 + 30 * t -- underground: a fast snaking wave
	s.legPh = 15 * (0.5 + t)
	s.antPh = 22 * (0.5 + t)
	return s
end
def("BurrowDive", {
	windup = { 0.5, BD_W },
	active = { 0.5, BD_A },
	recover = { 0.3, function(u: number, secs: number, input: Input): Stance
		local s = table.clone(BD_ASTATES[#BD_ASTATES])
		s.wph = (input and input.wavePhase or 0) * 2 + 30 * (0.5 + u * secs)
		s.k = TAU / 10
		return s
	end },
})

-- Erupt -------------------------------------------------------------------------
local ER_W, ER_WB = keyed({
	{ t = 0, sink = SINK, rear = 0, wave = 0.3, k = TAU / 10, shk = 0.02, anchor = 13 },
	{ t = 0.20, e = "inOut", sink = 3.25, rear = 0.12, rearN = 13, shk = 0.045, wave = 0.2 },
	{ t = 0.40, e = "in", sink = 2.4, rear = 0.45, rearN = 13, shk = 0.06, headP = -0.1, jaw = 0.2, legSw = 0.3, legLf = 0.4, wave = 0.12 },
	{ t = 0.54, e = "out", sink = 1.0, rear = 0.9, rearN = 13, headP = -0.45, jaw = 0.55, antP = 0.35, antS = 0.5, legScr = 1, legSw = 0.35, legLf = 0.5, legLift0 = 0.04, legLiftF = 0.25, wave = 0, shk = 0.05 },
	{ t = 0.70, e = "out", sink = 0.1, rear = 1.1, rearN = 9, headP = -0.62, jaw = 0.85, antP = 0.5, antS = 0.8, slideZ = 0.5, shk = 0.05, legLift0 = 0.04, legLiftF = 0.4 },
}, last(BD_ASTATES), function(s, t, u, input)
	local sinkTremor = (1 - smooth(0.2, 0.5, t))
	s.legPh = 16 * t
	s.antPh = 24 * t
	s.wph = 28 * t
	s.shkT = t
	s.lift = 0.05 * sinkTremor * math.sin(55 * t)
end)
def("Erupt", {
	windup = { 0.7, ER_W },
	recover = { 1.1, (function()
		local fn = keyed({
			{ t = 0 },
			{ t = 0.13, e = "snap", sink = 0.2, rear = -0.06, rearN = 7, headP = 0.2, jaw = -0.25, slideZ = -0.4, antP = -0.3, antS = 0.1, shk = 0, legLift0 = 0.1, legLiftF = 0 },
			{ t = 0.26, e = "out", sink = 0, rear = 0.28, rearN = 8, headP = -0.15, jaw = 0.1, slideZ = -0.2, antP = 0.1, legLift0 = 0.06, legSw = 0.3, legLf = 0.3, legScr = 0 },
			{ t = 0.55, e = "inOut", rear = 0.13, headP = -0.04, jaw = 0.05, slideZ = -0.05, antP = 0, antS = 0.1 },
			{ t = 1.1, e = "inOut", rear = 0, headP = 0, jaw = 0, slideZ = 0, antS = 0, legSw = 0, legLf = 0, legLift0 = 0 },
		}, last(ER_WB), function(s, t)
			s.headY = 0.4 * math.exp(-3.2 * math.max(0, t - 0.4)) * math.sin(TAU * 3.2 * math.max(0, t - 0.4)) * smooth(0.35, 0.45, t)
			s.rear += 0.05 * ring(t - 0.26, 2.4, 3)
			s.legPh = 16 * (0.7 + t)
			s.antSw = 0.4 * math.exp(-2 * t)
			s.antPh = 24 * (0.7 + t)
		end)
		return fn
	end)() },
})

-- Stagger -------------------------------------------------------------------------
local function staggerFn(dir: number)
	return (keyed({
			{ t = 0 },
			{ t = 0.07, e = "snap", rear = 0.55, rearN = 9, yaw0 = dir * 0.18, headY = dir * 0.55, headP = -0.15, jaw = 0.7, antP = 0.5, antS = 0.5, legLift0 = 0.5, slideZ = 0.5, wave = 0.35 },
			{ t = 0.2, e = "out", rear = 0.4, yaw0 = dir * 0.1, headY = dir * 0.28, jaw = 0.3, antS = 0.2, legLift0 = 0.2, slideZ = 0.3, wave = 0.22 },
			{ t = 0.4, e = "inOut", rear = 0.12, yaw0 = 0, headY = 0, headP = 0, jaw = 0.05, antP = 0.1, antS = 0, legLift0 = 0.05, slideZ = 0.05, wave = 0.06 },
		}, nil, function(s, t)
			s.k = TAU / 9
			s.wph = 34 * t
			s.legPh = 18 * t
			s.legSw = 0.3 * (1 - t / 0.4)
			s.legLf = 0.3 * (1 - t / 0.4)
			s.antPh = 26 * t
			s.antSw = 0.3 * (1 - t / 0.4)
		end))
end
local STAGGER = { [1] = staggerFn(1), [-1] = staggerFn(-1) }
def("Stagger", {
	active = { 0.4, function(u: number, secs: number, input: Input): Stance
		-- the head is thrown to the side away from the target (+Y = left)
		return STAGGER[if input and input.side and input.side < 0 then -1 else 1](u, secs, input)
	end },
})

-- Death ---------------------------------------------------------------------------
local function deathFn(dir: number)
	return (keyed({
			{ t = 0 },
			{ t = 0.14, e = "snap", rear = 0.8, rearN = 9, headP = -0.3, jaw = 0.85, antP = 0.6, antS = 0.8, legLift0 = 0.8, legSw = 0.5, legLf = 0.4, legScr = 1, shk = 0.05, slideZ = 0.6, yaw0 = dir * 0.15, headY = dir * 0.5, wave = 0.22 },
			{ t = 0.5, e = "inOut", rear = 0.9, rearN = 10, headP = -0.45, jaw = 0.9, shk = 0.06, slideZ = 0.8, wave = 0.28, curl = -dir * 0.6, legSw = 0.6 },
			{ t = 0.8, e = "in", rear = 0.08, headP = -0.2, shk = 0, jaw = 0.8, slideZ = 0.3, wave = 0.2, curl = -dir * 1.1, sink = 0.25, legScr = 0, antP = -0.3, antS = 0.2 },
			{ t = 0.95, e = "out", rear = 0.28, headP = -0.3, slideZ = 0.2, wave = 0.1, curl = -dir * 1.35, legLift0 = 1.0, sink = 0.15 },
			{ t = 1.2, e = "inOut", rear = 0, headP = -0.15, yaw0 = dir * 0.1, headY = dir * 0.2, curl = -dir * 1.65, sink = 0.3, legLift0 = 1.1, legSw = 0.15, legLf = 0.1, wave = 0.03, antP = -0.7, antS = 0.1, jaw = 0.9 },
			{ t = 2.0, e = "inOut", rear = 0, curl = -dir * 1.9, sink = 0.35, legSw = 0, legLf = 0, legLift0 = 1.15, wave = 0, headP = -0.12, jaw = 0.9 },
		}, nil, function(s, t)
			s.k = TAU / 9
			s.wph = 16 * t
			s.legPh = 17 * t
			s.antPh = 20 * t
			s.antSw = 0.5 * (1 - smooth(0.2, 1.0, t))
			s.shkT = t
			-- the last twitches, dying away
			local tw = (1 - smooth(1.0, 1.8, t))
			s.legSw += 0.12 * tw * smooth(1.0, 1.1, t)
			s.legLf += 0.1 * tw * smooth(1.0, 1.1, t)
		end))
end
local DEATH = { [1] = deathFn(1), [-1] = deathFn(-1) }
def("Death", {
	active = { 2.0, function(u: number, secs: number, input: Input): Stance
		return DEATH[if input and input.side and input.side < 0 then -1 else 1](u, secs, input)
	end },
})

BloodCentipede.moves = MOVES
BloodCentipede.durations = durations

function BloodCentipede.sample(move: string, phase: string, u: number, input: Input?): Pose
	local m = MOVES[move]
	local p = m and m[phase]
	if not p then
		return compose(table.clone(DEF), 0)
	end
	input = input or {}
	local secs = (input and input.duration) or p.duration
	local uu = math.clamp(u, 0, 1)
	local st = p.fn(uu, secs, input)
	return compose(st, uu * secs)
end

--------------------------------------------------------------------------------
-- Loops

local LEG_CYCLES = 3 -- leg cycles per wave cycle
local function gaitHz(speed: number): number
	return 0.39 + 0.056 * speed
end

function BloodCentipede.gaitRate(loop: string, speed: number, scale: number?): number
	if loop == "walk" or loop == "run" or loop == "circle" then
		return TAU * gaitHz(math.max(speed, 0.5))
	end
	return 1
end

-- the body trails the head through a turn: each plate's heading is the travel heading from the
-- time the head passed it, relative to the heading now, a step per joint kept small
local function followProf(input: Input?, speed: number): { number }?
	local yawAt = input and input.yawAt
	if not yawAt or speed < 0.8 then
		return nil
	end
	local now = yawAt(0)
	local prof, prev = {}, 0
	for j = 0, NN do
		local sBack = 0.8 * j
		local want = yawAt(math.min(sBack / math.max(speed, 3), 1.2)) - now
		local step = math.clamp(want - prev, -0.07, 0.07)
		prev += step
		prof[j] = prev
	end
	return prof
end

local function locomotion(phase: number, speed: number, input: Input?, run: boolean): Pose
	local st = table.clone(DEF)
	local wp = phase
	local lambda = if run then 12 else 15
	st.k = TAU / lambda
	st.wave = if run then 0.45 else 0.55
	st.wph = wp
	st.anchor = 6
	st.headLevel = 0.7
	st.hump = 0.015
	st.legPh = LEG_CYCLES * wp
	st.legSw = if run then 0.62 else 0.55
	st.legLf = if run then 0.7 else 0.6
	st.legLag = 0.9
	st.antP = 0.12 + (if run then -0.1 else 0)
	st.antS = if run then 0.05 else 0.2
	st.antSw = 0.18
	st.antPh = wp * 2.2
	st.jaw = 0.1 + 0.05 * math.sin(wp * 2)
	st.headP = 0.04 * math.sin(wp * 2 + 0.7)
	st.rear = if run then 0.02 else 0
	st.yawProf = followProf(input, speed)
	return compose(st, (input and input.time) or phase / TAU)
end

local loops = {}
function loops.walk(phase: number, speed: number, input: Input?): Pose
	return locomotion(phase, speed, input, false)
end
function loops.run(phase: number, speed: number, input: Input?): Pose
	return locomotion(phase, speed, input, true)
end
loops.circle = loops.walk

function loops.idle(t: number, speed: number, input: Input?): Pose
	local seed = (input and input.seed) or 0
	local st = table.clone(DEF)
	st.k = TAU / 13
	st.anchor = 6
	st.wave = 0.07
	st.wph = t * 1.1 + seed
	st.hump = 0.02
	st.rear = 0.02 + 0.015 * math.sin(t * 0.7 + seed)
	st.rearN = 5
	st.headLevel = 0.6
	st.headY = 0.2 * math.sin(t * 0.37 + seed) + 0.06 * math.sin(t * 1.3)
	st.headP = 0.04 * math.sin(t * 0.51 + seed)
	-- antennae: a slow scan with quick flicks
	st.antP = 0.12
	st.antS = 0.18
	st.antSw = 0.25 + 0.1 * math.sin(t * 0.3)
	st.antPh = t * 1.9 + seed
	local flick = math.max(0, math.sin(t * 0.83 + seed * 2)) ^ 12
	st.antSw += 0.35 * flick
	st.antPh += 6 * flick
	-- pincer clicks every few seconds
	local beat = t / 3.1 + seed
	local ft = (beat % 1) * 3.1
	local clicks = if hash(math.floor(beat) + seed) > 0.35 then 1 else 0
	st.jaw = 0.04 + clicks * (-0.3 * window(ft, 0, 0.04, 0.1, 0.16) + 0.18 * window(ft, 0.2, 0.26, 0.3, 0.36))
	-- the legs: a tiny shuffle, and a ripple that runs back along the plates now and then
	st.legPh = t * 1.2
	st.legSw = 0.05
	st.legLf = 0.03
	st.legLag = 0.7
	local cyc = (t / 5.5 + seed * 0.37) % 1
	st.rip = window(cyc, 0, 0.04, 0.4, 0.46) * (if hash(math.floor(t / 5.5 + seed * 0.37)) > 0.3 then 1 else 0)
	st.ripPos = cyc * 38
	return compose(st, t)
end

BloodCentipede.loops = loops

function BloodCentipede.plant(pose: Pose): Pose
	return pose
end

-- every joint translation (the root's slide and sink) times the scale
function BloodCentipede.scaled(pose: Pose, scale: number): Pose
	if scale ~= 1 then
		for name, cf in pose do
			pose[name] = cf - cf.Position + cf.Position * scale
		end
	end
	return pose
end

-- for QA: a pose from raw stance changes
function BloodCentipede.poseFromStance(changes: Stance?): Pose
	local st = table.clone(DEF)
	if changes then
		for n, v in changes do
			st[n] = v
		end
	end
	return compose(st, 0)
end

return BloodCentipede
