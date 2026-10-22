--!strict
-- Shared maths for serpent pose modules in EnemyPoses/ (JadeJiao.luau today): easing,
-- absolute-orientation chains composed with each segment's REST direction, the
-- path-following slither (a sine-generated ground curve that stays fixed on the ground while
-- the body slides along it), body-follow turning, the ring coil and the neck solves. Pure
-- maths, no instances, no gameplay decisions. All numbers are real studs in model space
-- (ground Y = 0, the beast faces -Z, its left is -X).
--
-- Joints turn by their ABSOLUTE orientation, not by relative angles. Every joint frame is
-- identity in model space, but a segment's rest bone can point anywhere (the Jade Jiao rests
-- coiled), so a segment's orientation is built as
--     A = Ry(heading) * Rx(-up) * Q^-1,   Q = Ry(restHeading) * Rx(-restUp)
-- (heading: the bone's direction about the vertical, 0 = straight back along +Z for body and
-- tail, +heading swings toward +X, the beast's right; up: the bone's elevation, + lifts its far
-- end). The neck points forward instead: A = Ry(Y) * Rx(E - eps), Y + turns to the beast's left,
-- E the elevation above horizontal (eps the rest one). Serpent.locals() turns the absolute
-- orientations into Motor6D transforms (local_j = A_(j-1)^-1 A_j).
--
-- The slither: the spine lies on the curve whose heading is theta(sigma) = th0 * cos(k sigma)
-- (sigma = arc length along the ground). A body point at arc s behind the neck base sits at
-- sigma = S - s, where S grows with the distance travelled, so the wave travels back along the
-- body at the sliding speed and every body point slides along the same groove (no sideslip).
-- The curve's mean line is the model's X = 0 line (the server root's lane); positions come from
-- the closed form x = -(1/k) Sum 2(-1)^m J_(2m+1)(th0) sin((2m+1)u) / (2m+1), u = phase - k s.

local Serpent = {}

export type Pose = { [string]: CFrame }
export type Spec = {
	P: { [string]: Vector3 }, -- joint pivots at rest, real studs, model space
	root: string, -- the Body's joint
	neck: { string }, -- JointNeck .. JointNeck5, JointHead (6)
	tail: { string }, -- JointTail .. JointTail18
	tailEnd: Vector3, -- the end of the last tail bone
	mouth: Vector3, -- the mouth point on the skull at rest
	hrpZ: number, -- the server root's centre z, model space
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

-- Bessel function of the first kind, J_n(x), by its series (|x| < 2 here)
local function besselJ(n: number, x: number): number
	local sum = 0
	local half = x / 2
	local fact_m = 1
	local fact_mn = 1
	for i = 2, n do
		fact_mn *= i
	end
	for m = 0, 10 do
		if m > 0 then
			fact_m *= m
			fact_mn *= (m + n)
		end
		sum += (if m % 2 == 0 then 1 else -1) * half ^ (2 * m + n) / (fact_m * fact_mn)
	end
	return sum
end
Serpent.besselJ = besselJ

-- how fast the curve slides for a ground speed v: the mean forward speed of a body sliding
-- along a sine-generated curve at speed w is w * J0(th0)
function Serpent.slideSpeed(v: number, th0: number): number
	return v / math.max(0.3, besselJ(0, th0))
end

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

local function yawOf(d: Vector3): number
	return math.atan2(d.X, d.Z)
end
local function upOf(d: Vector3): number
	return math.asin(math.clamp(d.Y / d.Magnitude, -1, 1))
end

function Serpent.new(spec: Spec)
	local S: any = { spec = spec }
	local P = spec.P
	local tail = spec.tail
	local n = #tail
	local neck = spec.neck
	S.n = n

	-- Body: from the neck base (front) to Tail1's pivot (rear); the root pivot is its middle
	local Pr = P[spec.root]
	local front, rear = P[neck[1]], P[tail[1]]
	local bodyBone = rear - front
	local bodyLen = bodyBone.Magnitude
	S.bodyLen = bodyLen
	S.Pr = Pr
	S.frontRel = front - Pr
	S.rearRel = rear - Pr
	S.bodyRestYaw = yawOf(bodyBone)
	S.bodyRestUp = upOf(bodyBone)
	local Qb = ry(S.bodyRestYaw) * rx(-S.bodyRestUp)
	local QbInv = Qb:Inverse()
	S.sPivot = (Pr - front).Magnitude -- arc of the root pivot behind the neck base
	S.sHrp = spec.hrpZ - front.Z -- arc of the server root's centre behind the neck base (straight)

	-- tail bones: rest heading (unwrapped along the chain, starting from the body's), rest up,
	-- length, arc start (from the neck base)
	local restYaw, restUp, len, arc = table.create(n), table.create(n), table.create(n), table.create(n)
	local QInv = table.create(n)
	local prevYaw = S.bodyRestYaw
	local s = bodyLen
	for k = 1, n do
		local a = P[tail[k]]
		local b = if k < n then P[tail[k + 1]] else spec.tailEnd
		local d = b - a
		local y = yawOf(d)
		y = prevYaw + wrap(y - prevYaw)
		prevYaw = y
		restYaw[k], restUp[k], len[k], arc[k] = y, upOf(d), d.Magnitude, s
		QInv[k] = (ry(y) * rx(-restUp[k])):Inverse()
		s += d.Magnitude
	end
	S.restYaw, S.restUp, S.len, S.arc = restYaw, restUp, len, arc
	S.total = s -- neck base to the last bone end

	-- neck: rest elevations, bones (pivot to next pivot; the skull's bone ends at the mouth)
	local eps, nbone = table.create(#neck), table.create(#neck)
	for j = 1, #neck do
		local a = P[neck[j]]
		local b = if j < #neck then P[neck[j + 1]] else spec.mouth
		local d = b - a
		nbone[j] = d
		eps[j] = if j < #neck then math.atan2(d.Y, -d.Z) else 0
	end
	S.eps, S.nbone = eps, nbone

	-- Body orientation: heading of its backward axis (front to rear), the lift of its front end
	-- (pitch, + rears), roll about its axis
	function S.bodyRot(heading: number, lift: number, roll: number?): CFrame
		return ry(heading) * rx(lift - S.bodyRestUp) * CFrame.Angles(0, 0, roll or 0) * QbInv
	end

	-- the JointRoot transform that puts the body pivot at `pivot` with orientation Rb
	function S.rootTransform(Rb: CFrame, pivot: Vector3): CFrame
		return CFrame.new(pivot - Pr) * Rb
	end

	-- where the neck base (front) and Tail1 pivot (rear) land
	function S.bodyEnds(Rb: CFrame, pivot: Vector3): (Vector3, Vector3)
		return pivot + Rb * S.frontRel, pivot + Rb * S.rearRel
	end

	function S.neckAbs(E: { number }, Y: { number }, roll: number?): { CFrame }
		local abs = table.create(#E)
		for j = 1, #E do
			abs[j] = ry(Y[j]) * rx(E[j] - eps[j])
		end
		if roll then
			abs[#E] = abs[#E] * CFrame.Angles(0, 0, roll)
		end
		return abs
	end

	function S.neckLocals(E: { number }, Y: { number }, Rb: CFrame, roll: number?): { CFrame }
		return Serpent.locals(Rb, S.neckAbs(E, Y, roll))
	end

	-- neck forward kinematics from the neck base: the head pivot and the mouth point
	function S.headAt(E: { number }, Y: { number }, base: Vector3, roll: number?): (Vector3, Vector3)
		local abs = S.neckAbs(E, Y, roll)
		local p = base
		for j = 1, #E - 1 do
			p += abs[j] * nbone[j]
		end
		return p, p + abs[#E] * nbone[#E]
	end

	-- tail: absolute headings H and ups U per segment; Rb is the Body's orientation
	function S.tailLocals(H: { number }, U: { number }, Rb: CFrame): { CFrame }
		local abs = table.create(n)
		for k = 1, n do
			abs[k] = ry(H[k]) * rx(-U[k]) * QInv[k]
		end
		return Serpent.locals(Rb, abs)
	end

	-- THE SLITHER CURVE. phase: the wave's phase at the neck base (rad); th0: the heading
	-- amplitude (rad); wavelength: in arc studs. Returns x(s), z(s) (relative to the neck
	-- base's mean spot, x on the mean line = 0) and theta(s), for s the arc behind the neck
	-- base (negative = ahead of it, on the path the head will take).
	function S.curve(phase: number, th0: number, wavelength: number)
		local k = TAU / wavelength
		local j0, j1, j2, j3, j4, j5 = besselJ(0, th0), besselJ(1, th0), besselJ(2, th0), besselJ(3, th0), besselJ(4, th0), besselJ(5, th0)
		local c = {}
		function c.x(s: number): number
			local u = phase - k * s
			return -(2 * j1 * math.sin(u) - (2 / 3) * j3 * math.sin(3 * u) + (2 / 5) * j5 * math.sin(5 * u)) / k
		end
		function c.z(s: number): number
			local u = phase - k * s
			return j0 * s + (j2 * math.sin(2 * u) - 0.5 * j4 * math.sin(4 * u)) / k
		end
		function c.theta(s: number): number
			return th0 * math.cos(phase - k * s)
		end
		c.k, c.j0 = k, j0
		return c
	end

	-- the spine laid on a curve: the body's heading and pivot, each tail bone's heading (from the
	-- curve's points at both its ends, so the chord lies on the curve). front: where the neck
	-- base's mean spot is (model space).
	function S.lay(c: any, front: Vector3): (number, Vector3, { number })
		local fx, fz = c.x(0), c.z(0)
		local rx_, rz_ = c.x(bodyLen), c.z(bodyLen)
		local bodyYaw = math.atan2(rx_ - fx, rz_ - fz)
		local pivotX = fx + (rx_ - fx) * (S.sPivot / bodyLen)
		local pivotZ = fz + (rz_ - fz) * (S.sPivot / bodyLen)
		local pivot = Vector3.new(front.X + pivotX, Pr.Y, front.Z + pivotZ)
		local H = table.create(n)
		local ax, az = rx_, rz_
		for k = 1, n do
			local s1 = arc[k] + len[k]
			local bx, bz = c.x(s1), c.z(s1)
			H[k] = math.atan2(bx - ax, bz - az)
			ax, az = bx, bz
		end
		return bodyYaw, pivot, H
	end

	-- Body-follow turning: a point at arc s passed where the server root is now (s - sHrp) / v
	-- seconds ago, so its heading is the travel heading then; points ahead of the root extrapolate
	-- the current turn rate. yawAt(secondsAgo) is the travel heading. Adds to out[0..n] (0 = body).
	function S.follow(yawAt: (number) -> number, speed: number, turn: number, out: { [number]: number })
		local now = yawAt(0)
		local v = math.max(speed, 2)
		local function at(sMid: number): number
			local d = (sMid - S.sHrp) / v
			if d <= 0 then
				return math.clamp(-turn * d, -0.5, 0.5) -- ahead of the root: where the turn is heading
			end
			return math.clamp(wrap(yawAt(math.min(d, 2.8)) - now), -1.8, 1.8)
		end
		out[0] = (out[0] or 0) + at(S.sPivot)
		for k = 1, n do
			out[k] = (out[k] or 0) + at(arc[k] + len[k] * 0.5)
		end
	end

	-- RING: lay the body and tail on a circle of radius R with the neck base at the server root's
	-- centre P = (0, hrpZ) heading straight back, the centre on the beast's LEFT (-R, hrpZ), the
	-- spine curling left round it. It covers `arcTarget * amount` radians; bones past that run on
	-- along the end tangent. Returns the body's heading and pivot, the tail headings, the number
	-- of bones on the ring (1 = the body) and the end tangent's heading.
	function S.ring(R: number, arcTarget: number, amount: number): any
		local total = arcTarget * amount
		local headings = table.create(n)
		local lens = { bodyLen }
		for k = 1, n do
			lens[k + 1] = len[k]
		end
		local phi = 0
		local used = 0
		local bodyYaw = 0
		local pivot = Vector3.zero
		-- position on the circle (or past its end, along the tangent)
		local cx, cz = -R, spec.hrpZ
		local function pointAt(sArc: number): (number, number)
			local a = math.min(sArc / R, total)
			local x, z = cx + R * math.cos(a), cz + R * math.sin(a)
			local rest = sArc - a * R
			if rest > 0 then
				x += -math.sin(a) * rest
				z += math.cos(a) * rest
			end
			return x, z
		end
		local s0 = 0
		local ax, az = pointAt(0)
		for idx, l in lens do
			local s1 = s0 + l
			local bx, bz = pointAt(s1)
			local heading = math.atan2(bx - ax, bz - az)
			if idx == 1 then
				bodyYaw = heading
				local f = S.sPivot / bodyLen
				pivot = Vector3.new(ax + (bx - ax) * f, Pr.Y, az + (bz - az) * f)
			else
				headings[idx - 1] = heading
			end
			if s0 / R < total - 1e-4 then
				used = idx
			end
			phi = math.min(s1 / R, total)
			ax, az, s0 = bx, bz, s1
		end
		return { bodyYaw = bodyYaw, pivot = pivot, headings = headings, used = used, endHeading = -total, radius = R }
	end

	-- Neck yaw solves. Both move the head pivot over a point by turning the neck about the
	-- vertical with a weight profile w (per segment); the skull's own heading is left alone.
	local function headXZ(E: { number }, Y: { number }, base: Vector3): Vector3
		local h = S.headAt(E, Y, base)
		return h
	end

	-- hang the head pivot over (tx, tz): Y[j] = psi * w[j], psi searched in 0..3 (left turns)
	function S.reach(E: { number }, base: Vector3, tx: number, tz: number, w: { number }): ({ number }, number)
		local function head(psi: number): (number, { number })
			local Y = table.create(#E)
			for j = 1, #E do
				Y[j] = psi * w[j]
			end
			local h = headXZ(E, Y, base)
			return math.sqrt((h.X - tx) ^ 2 + (h.Z - tz) ^ 2), Y
		end
		local lo, hi = 0.0, 3.0
		local best, bestPsi = math.huge, 0
		for _ = 1, 24 do
			local a = lo + (hi - lo) * 0.382
			local b = lo + (hi - lo) * 0.618
			local da, db = head(a), head(b)
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
		local miss, Y = head(bestPsi)
		return Y, miss
	end

	-- add delta * w[j] to the neck headings so the head pivot lands at x = tx (Newton, 3 steps)
	function S.centre(E: { number }, Y: { number }, base: Vector3, tx: number, w: { number }): { number }
		local delta = 0
		local function with(d: number): { number }
			local out = table.create(#Y)
			for j = 1, #Y do
				out[j] = Y[j] + d * w[j]
			end
			return out
		end
		for _ = 1, 3 do
			local x0 = headXZ(E, with(delta), base).X
			local x1 = headXZ(E, with(delta + 0.01), base).X
			local slope = (x1 - x0) / 0.01
			if math.abs(slope) < 0.5 then
				break
			end
			delta = math.clamp(delta + (tx - x0) / slope, -1.2, 1.2)
		end
		return with(delta)
	end

	return S
end

return Serpent
