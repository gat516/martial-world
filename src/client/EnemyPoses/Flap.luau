--!strict
-- Shared wing-flap maths for the two fliers (FlameRaven.luau and BloodBat.luau). Pure
-- data and maths: it returns Motor6D.Transform CFrames, no instances.
--
-- THE JOINTS. One wing is three segments in a chain, each rolling about the model Z axis:
--   Raven JointShoulder / JointElbow / JointWrist  <->  Bat JointWing / JointWing2 / JointWing3
-- Measured on both rigs (Studio, C0 * pose): roll Z lifts a wing, L up = -Z, R up = +Z.
-- A YAW sweep is the opposite of what the first notes said: +Y on the RIGHT wing and -Y on
-- the LEFT swing the tip FORWARD (toward -Z); a sweep BACK is -Y on R and +Y on L.
-- A wing pose is Angles(0, yaw, roll) = Ry * Rz: tilt up first, then sweep in the
-- horizontal plane, so the wing's elevation is the roll whatever the sweep.
--
-- THE STROKE. Angles here are ABSOLUTE elevations of each segment (radians above
-- horizontal, "up" positive); the transform of the 2nd and 3rd joint is the difference to
-- the one before (they are nested), and the rest pose (identity) is the elevation A0 of a
-- straight wing. Each joint's wave is delayed (lag) behind its parent, so on the down-stroke
-- the elbow and the tip are still up (the wing bows up) and on the up-stroke they trail
-- below (the tip droops), and the outer segments swing further (k). The down-stroke is the
-- short, powerful part of the cycle (d of it, default 0.4); the up-stroke is the slower
-- recovery. Yaw: the wing is back at the top of the stroke and forward at the bottom.
--
-- STYLE (a table, fields optional except A0):
--   A0       elevation of the rest pose (raven 0.36, bat 0.436)
--   top      elevation of every segment at the top of the stroke
--   bottom   elevation of the SHOULDER at the bottom (outer ones: top - (top-bottom)*k)
--   amp      0..1: how much of the stroke is used (0 = the wing holds at `top`)
--   lag      cycle radians each joint trails its parent (default 0.9)
--   d        fraction of the cycle spent on the down-stroke (default 0.4)
--   k2, k3   how much further the elbow / tip swing (default 1.25, 1.55)
--   floor    no segment goes below this elevation (a number, or one per joint: the bat's
--            membranes rest at different tilts, so it uses {0.3, 0.5, 0.3} to keep every
--            membrane's real elevation >= 0.3)
--   ceil     no segment goes above this (the bat's finger skin rests tilted DOWN 0.61 rad, so its
--            elevation must stay under 0.74 or it passes through flat); a number or one per joint
--   yaw      {y1, y2, y3} static sweep BACK per joint, radians (relative)
--   yawAmp   {a1, a2, a3} sweep amplitude per joint along the stroke (back at the top)
--   bend     {0, b2, b3} added to the ABSOLUTE elevation of the elbow / tip (curl it up or down)
local Flap = {}

export type Pose = { [string]: CFrame }
export type Style = {
	A0: number,
	top: number?,
	bottom: number?,
	amp: number?,
	lag: number?,
	d: number?,
	k2: number?,
	k3: number?,
	floor: (number | { number })?,
	ceil: (number | { number })?,
	yaw: { number }?,
	yawAmp: { number }?,
	bend: { number }?,
}

local TAU = math.pi * 2
local NO = { 0, 0, 0 }

-- 1 at the top of the stroke, -1 at the bottom. theta in radians; d is the down-stroke share.
function Flap.wave(theta: number, d: number?): number
	local share = d or 0.4
	local u = (theta / TAU) % 1
	if u < share then
		return math.cos(math.pi * u / share)
	end
	return -math.cos(math.pi * (u - share) / (1 - share))
end

local function smoothstep(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end
Flap.smoothstep = smoothstep

-- A value track: points {{t, v}, ...} (t ascending), smoothstep between them, clamped outside.
function Flap.curve(points: { { number } }, t: number): number
	local first, last = points[1], points[#points]
	if t <= first[1] then
		return first[2]
	elseif t >= last[1] then
		return last[2]
	end
	for i = 2, #points do
		local b = points[i]
		if t <= b[1] then
			local a = points[i - 1]
			return a[2] + (b[2] - a[2]) * smoothstep((t - a[1]) / (b[1] - a[1]))
		end
	end
	return last[2]
end

-- The flap phase from a flap-rate track (radians per second, linear between points): the
-- integral of the rate up to t. Lets a move speed up, hold and slow the beat without jumps.
function Flap.phaseAt(rate: { { number } }, t: number): number
	local sum = 0
	local prevT, prevV = 0, rate[1][2]
	for i = 1, #rate do
		local pt, pv = rate[i][1], rate[i][2]
		if pt > prevT then
			local to = math.min(pt, t)
			local vTo = prevV + (pv - prevV) * (to - prevT) / (pt - prevT)
			sum += (prevV + vTo) * 0.5 * (to - prevT)
			if to >= t then
				return sum
			end
		end
		prevT, prevV = pt, pv
	end
	return sum + prevV * (t - prevT)
end

-- Smooth value noise in -1..1 (a sum of sines at unrelated rates), different per seed.
function Flap.noise(t: number, seed: number?): number
	local s = (seed or 0) * 7.31
	return (math.sin(t * 1.0 + s) * 0.5 + math.sin(t * 2.3 + s * 1.7) * 0.3 + math.sin(t * 4.1 + s * 0.6) * 0.2)
end

local function hash(n: number, seed: number): number
	local x = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	return x - math.floor(x)
end
Flap.hash = hash

-- A twitch: a value in -1..1 that jumps to a new random target `rate` times a second and
-- gets there in the first `snap` of each hold (fast, nervous head and ear flicks).
function Flap.twitch(t: number, rate: number, seed: number?, snap: number?): number
	local x = t * rate
	local i = math.floor(x)
	local f = x - i
	local a = hash(i - 1, seed or 0) * 2 - 1
	local b = hash(i, seed or 0) * 2 - 1
	local s = snap or 0.3
	local k = smoothstep(f / s)
	return a + (b - a) * k
end

-- One wing's three transforms as { roll1..3, yaw1..3 } (roll up-positive, yaw back-positive,
-- both RELATIVE to the parent segment, rest = zeros).
function Flap.wing(theta: number, p: Style): { number }
	local top = p.top or p.A0
	local bottom = p.bottom or top
	local amp = p.amp or 1
	local lag = p.lag or 0.9
	local d = p.d or 0.4
	local floors = p.floor or -math.huge
	local ceils = p.ceil or math.huge
	local ks = { 1, p.k2 or 1.25, p.k3 or 1.55 }
	local yaw = p.yaw or NO
	local yamp = p.yawAmp or NO
	local bend = p.bend or NO
	local out = table.create(6, 0)
	local prev = p.A0
	local travel = (top - bottom) * amp
	for j = 1, 3 do
		local w = Flap.wave(theta - lag * (j - 1), d)
		local abs = top - travel * ks[j] * (1 - w) * 0.5
		abs = math.max(abs + bend[j], if type(floors) == "table" then floors[j] else floors)
		abs = math.min(abs, if type(ceils) == "table" then ceils[j] else ceils)
		out[j] = abs - prev
		prev = abs
		out[j + 3] = yaw[j] + yamp[j] * amp * w -- already a per-joint delta
	end
	return out
end

-- The pose of both wings: L and R as arrays of three CFrames.
function Flap.cycle(theta: number, p: Style, pRight: Style?, thetaRight: number?): { L: { CFrame }, R: { CFrame } }
	local l = Flap.wing(theta, p)
	local r = if pRight or thetaRight then Flap.wing(thetaRight or theta, pRight or p) else l
	local L, R = {}, {}
	for j = 1, 3 do
		L[j] = CFrame.Angles(0, l[j + 3], -l[j])
		R[j] = CFrame.Angles(0, -r[j + 3], r[j])
	end
	return { L = L, R = R }
end

-- Writes the cycle into a pose under the joint names { L = {sh, el, wr}, R = {...} }.
function Flap.write(pose: Pose, cyc: { L: { CFrame }, R: { CFrame } }, names: { L: { string }, R: { string } })
	for j = 1, 3 do
		pose[names.L[j]] = cyc.L[j]
		pose[names.R[j]] = cyc.R[j]
	end
end

-- Linear blend of two styles (numbers and the yaw arrays), so a move can morph one wing
-- shape into another. Fields only in one are taken as is.
function Flap.mix(a: Style, b: Style, t: number): Style
	local out: any = {}
	for k, v in a :: any do
		local w = (b :: any)[k]
		if type(v) == "number" and type(w) == "number" then
			out[k] = v + (w - v) * t
		elseif type(v) == "table" and type(w) == "table" then
			local arr = {}
			for i = 1, #v do
				arr[i] = v[i] + (w[i] - v[i]) * t
			end
			out[k] = arr
		else
			out[k] = if t < 0.5 then v else w
		end
	end
	return out
end

return Flap
