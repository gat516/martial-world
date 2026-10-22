--!strict
-- Shared maths for serpent pose modules in EnemyPoses/ (JadeJiao.luau today): easing,
-- absolute-orientation chains, the travelling slither wave, body-follow turning, the
-- ring coil and the neck solve that hangs the head over a point. Pure maths, no
-- instances, no gameplay decisions.
--
-- Joints turn by their ABSOLUTE heading and pitch, not by relative angles: a chain is
-- described by the orientation each segment should have in model space, and
-- Serpent.locals() turns that into the Motor6D transforms (local_j = R_(j-1)^-1 R_j).
-- That keeps a bent, upright neck bending sideways about the real vertical instead of
-- spinning about its own tilted axis.
--
-- Units: pivots, lengths and root translations are in "module units" (the fight sheet's
-- contract geometry); the rig is `scale` times bigger (JadeJiao: K = 1.668), applied once
-- by EnemyAnimator (scaled()). Wave speeds are in REAL studs/s: a body point stays on
-- the lane its head cut (no skating) when the wave travels back at the ground speed.

local Serpent = {}

export type Pose = { [string]: CFrame }
export type Spec = {
	P: { [string]: Vector3 }, -- joint pivots at rest, module units
	parent: { [string]: string },
	neck: { string }, -- JointNeck .. JointNeck5, JointHead (6)
	tail: { string }, -- JointTail .. JointTail18 (18)
	tailLen: { number }, -- centreline length of each tail segment
	scale: number, -- real studs per module unit
	root: string,
	rootPivotZ: number, -- JointRoot pivot z
	hrpZ: number, -- the hit volume's centre z (the ring's point P), model space
	bodyRear: number, -- Body pivot to Tail1 pivot
}

local TAU = math.pi * 2
Serpent.TAU = TAU

function Serpent.smooth(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local smooth = Serpent.smooth

Serpent.EASE = {
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
		return if a < 0.5 then 4 * a * a * a else 1 - (-2 * a + 2) ^ 3 / 2
	end,
	outBack = function(a: number): number
		local c = 1.6
		return 1 + (c + 1) * (a - 1) ^ 3 + c * (a - 1) ^ 2
	end,
	snap = function(a: number): number
		return 1 - (1 - a) ^ 4
	end,
}

local function ry(a: number): CFrame
	return CFrame.Angles(0, a, 0)
end
local function rx(a: number): CFrame
	return CFrame.Angles(a, 0, 0)
end
Serpent.ry, Serpent.rx = ry, rx

local function wrap(a: number): number
	return (a + math.pi) % TAU - math.pi
end
Serpent.wrap = wrap

-- local transforms from absolute orientations: R0 is the parent's, abs[j] each segment's
function Serpent.locals(R0: CFrame, abs: { CFrame }): { CFrame }
	local out = table.create(#abs)
	local prev = R0
	for j, r in abs do
		out[j] = prev:Inverse() * r
		prev = r
	end
	return out
end

-- forward kinematics: world (model-space) transforms of every joint's moved frame.
-- Apply to a rest-pose point: M[joint] * point. order lists parents first.
function Serpent.fk(P: { [string]: Vector3 }, parent: { [string]: string }, order: { string }, pose: Pose): { [string]: CFrame }
	local M: { [string]: CFrame } = {}
	for _, name in order do
		local p = P[name]
		local t = CFrame.new(p) * (pose[name] or CFrame.identity) * CFrame.new(-p)
		local up = parent[name]
		M[name] = if up and M[up] then M[up] * t else t
	end
	return M
end

function Serpent.new(spec: Spec)
	local S: any = { spec = spec }
	local K = spec.scale
	local tail, tailLen = spec.tail, spec.tailLen
	local n = #tail

	-- rest elevation of each neck segment (angle above horizontal, forward = -Z); the head
	-- (skull) rests level
	local eps = table.create(#spec.neck, 0)
	for j = 1, #spec.neck - 1 do
		local a, b = spec.P[spec.neck[j]], spec.P[spec.neck[j + 1]]
		eps[j] = math.atan2(b.Y - a.Y, -(b.Z - a.Z))
	end
	eps[#spec.neck] = 0
	S.eps = eps

	-- arc position of each tail pivot, measured from the root pivot, module units
	local arc = table.create(n)
	local s = spec.bodyRear
	for i = 1, n do
		arc[i] = s
		s += tailLen[i]
	end
	S.arc = arc

	-- neck: elevations E (rad above horizontal, absolute), headings Y (rad about the vertical,
	-- relative to the root's heading). R0 is the Body's orientation.
	function S.neckLocals(E: { number }, Y: { number }, R0: CFrame, roll: number?): { CFrame }
		local abs = table.create(#E)
		for j = 1, #E do
			abs[j] = ry(Y[j] + 0) * rx(E[j] - eps[j])
		end
		if roll then
			abs[#E] = abs[#E] * CFrame.Angles(0, 0, roll)
		end
		return Serpent.locals(R0, abs)
	end

	-- tail: absolute headings Yk (about the vertical) and "up" pitches (rad, positive lifts the
	-- tail's far end). R0 is the Body's orientation.
	function S.tailLocals(Y: { number }, up: { number }, R0: CFrame): { CFrame }
		local abs = table.create(n)
		for k = 1, n do
			abs[k] = ry(Y[k]) * rx(-up[k])
		end
		return Serpent.locals(R0, abs)
	end

	-- taper of the slither wave along the tail, 0..1 at index k (1..n): small at the base,
	-- largest mid-tail, falling at the tip
	function S.taper(k: number): number
		local f = (k - 1) / (n - 1)
		return 0.1 + 0.9 * smooth(0, 0.5, f) * (1 - 0.4 * smooth(0.55, 1, f))
	end

	-- The travelling wave along the tail as ABSOLUTE headings (heading(s,t) = lat * k * taper *
	-- sin(phase - k s): a lateral displacement wave of peak `lat` real studs, no cumulative
	-- drift, so the tail never wags as one piece). phase is the wave's phase at the root (rad);
	-- a crest moves tailward at (rate / k) real studs/s, so with rate = k * speed it stays fixed on
	-- the ground. Returns the body's own heading and fills headings per tail segment (taken at
	-- the segment's middle).
	function S.wave(phase: number, lat: number, wavelength: number, headings: { number }): number
		local k = TAU / wavelength
		for i = 1, n do
			local mid = (arc[i] + tailLen[i] * 0.5) * K
			headings[i] = lat * k * S.taper(i) * math.cos(phase - k * mid)
		end
		return lat * k * 0.08 * math.cos(phase - k * (spec.bodyRear * 0.5 * K))
	end

	-- Body-follow turning: the tail segment at arc s lies where the root was s/speed seconds
	-- ago, so its heading is the root's heading then. yawAt(secondsAgo) is the root yaw.
	function S.follow(yawAt: (number) -> number, speed: number, out: { number })
		local now = yawAt(0)
		local v = math.max(speed, 3)
		for i = 1, n do
			local d = (arc[i] + tailLen[i] * 0.5) * K / v
			local delta = wrap(yawAt(math.min(d, 2.5)) - now)
			out[i] = (out[i] or 0) + math.clamp(delta, -1.6, 1.6)
		end
	end

	-- RING: lay the root and tail on a circle of radius R (module units) through P (the hit
	-- volume's centre) with the centre on the beast's LEFT (-X), the tail curling left. The
	-- Body pivot sits on the circle `a0` behind P; every chord's heading is the circle's
	-- tangent at its middle. amount (0..1) opens/closes the ring: it covers `arc` radians of the
	-- circle times amount. Returns { bodyYaw, root = Vector3 shift, headings = { Yk }, used = N,
	-- radius }. Headings continue straight (the last chord's) past the ring.
	function S.ring(R: number, arcTarget: number, amount: number): any
		local a0 = spec.rootPivotZ - spec.hrpZ
		local phi0 = a0 / R
		local total = arcTarget * amount
		local shift = Vector3.new(-R * (1 - math.cos(phi0)), 0, R * math.sin(phi0) - a0) * smooth(0, 0.35, amount)
		local headings = table.create(n)
		-- the body chord (pivot to Tail1 pivot)
		local lens = { spec.bodyRear }
		for i = 1, n do
			lens[i + 1] = tailLen[i]
		end
		local phi = phi0
		local used = 0
		local bodyYaw = 0
		local last = 0
		for idx, len in lens do
			local theta = 2 * math.asin(math.min(1, len / (2 * R)))
			local room = math.max(0, total - phi)
			local th = math.min(theta, room)
			-- a partly covered chord leaves its remainder straight along the end tangent
			local heading = -(phi + th * 0.5)
			if idx == 1 then
				bodyYaw = heading
			else
				headings[idx - 1] = heading
			end
			if th > 1e-4 then
				used = idx
			end
			last = -(phi + th)
			phi += th
		end
		-- chords with no angle left continue along the final tangent
		return { bodyYaw = bodyYaw, root = shift, headings = headings, used = used, endHeading = last, radius = R }
	end

	-- The neck that hangs the head over a point (tx, tz) in model space: heading profile
	-- w scaled by psi, bisected for the best reach. bodyRot is the Body's rotation, rootT its
	-- translation, E the neck's elevations. Returns Y (headings) and the miss distance.
	function S.reach(E: { number }, bodyRot: CFrame, rootT: Vector3, tx: number, tz: number, w: { number }): ({ number }, number)
		local order = {}
		local pose: Pose = {}
		local R0 = bodyRot
		local function head(psi: number): (Vector3, { number })
			local Y = table.create(#E)
			for j = 1, #E do
				Y[j] = psi * w[j]
			end
			local loc = S.neckLocals(E, Y, R0)
			local P = spec.P
			local rootPivot = P[spec.root]
			local M0 = CFrame.new(rootPivot) * (CFrame.new(rootT) * bodyRot) * CFrame.new(-rootPivot)
			local m = M0
			local pos = M0 * P[spec.neck[1]]
			for j, name in spec.neck do
				local p = P[name]
				m = m * CFrame.new(p) * loc[j] * CFrame.new(-p)
				pos = m * p
			end
			return pos, Y
		end
		local lo, hi = 0.0, 3.0
		local best, bestPsi = math.huge, 0
		for _ = 1, 26 do
			local a = lo + (hi - lo) * 0.382
			local b = lo + (hi - lo) * 0.618
			local pa, pb = head(a), head(b)
			local da = math.sqrt((pa.X - tx) ^ 2 + (pa.Z - tz) ^ 2)
			local db = math.sqrt((pb.X - tx) ^ 2 + (pb.Z - tz) ^ 2)
			if da < db then
				hi = b
				if da < best then
					best, bestPsi = da, a
				end
			else
				lo = a
				if db < best then
					best, bestPsi = db, b
				end
			end
		end
		local _, Y = head(bestPsi)
		return Y, best
	end

	S.n = n
	return S
end

return Serpent
