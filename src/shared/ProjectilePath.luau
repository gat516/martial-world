--!strict
-- Where a boss projectile is, shared by the server (Projectiles.luau, which hits
-- with it) and every client (ProjectileView.luau, which draws it), so both fly
-- the same path from one spawn message. A path is a straight line or a gravity
-- arc; homing turns the velocity a little each step toward a moving target, so
-- it is stepped rather than closed-form (the client follows the same rule from
-- the same target and drifts only by what the target's replication lags).

local ProjectilePath = {}

export type State = { position: Vector3, velocity: Vector3 }

-- `gravity` studs/s^2 pulling down (0 = a straight shot).
function ProjectilePath.at(origin: Vector3, velocity: Vector3, gravity: number, t: number): State
	local g = Vector3.new(0, -gravity, 0)
	return {
		position = origin + velocity * t + g * (0.5 * t * t),
		velocity = velocity + g * t,
	}
end

-- One step of `dt` from `state`, turning toward `target` by at most `turn`
-- degrees per second (homing; nil target or 0 turn flies on).
function ProjectilePath.step(state: State, dt: number, gravity: number, target: Vector3?, turn: number?): State
	local velocity = state.velocity
	if target and turn and turn > 0 then
		local speed = velocity.Magnitude
		local want = target - state.position
		if speed > 0.01 and want.Magnitude > 0.01 then
			local from, to = velocity.Unit, want.Unit
			local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
			local limit = math.rad(turn) * dt
			if angle > 1e-4 then
				local k = math.min(1, limit / angle)
				-- slerp from -> to by k
				local s = math.sin(angle)
				local dir = from * (math.sin((1 - k) * angle) / s) + to * (math.sin(k * angle) / s)
				velocity = dir.Unit * speed
			end
		end
	end
	velocity += Vector3.new(0, -gravity * dt, 0)
	return { position = state.position + velocity * dt, velocity = velocity }
end

-- The launch velocity that lands a shot from `origin` on `target` after
-- `seconds` under `gravity` (a lob: the arc's height follows from the time).
function ProjectilePath.lob(origin: Vector3, target: Vector3, seconds: number, gravity: number): Vector3
	local t = math.max(seconds, 0.05)
	return (target - origin) / t + Vector3.new(0, 0.5 * gravity * t, 0)
end

-- Closest distance from `point` to the segment a -> b.
function ProjectilePath.segmentDistance(a: Vector3, b: Vector3, point: Vector3): number
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 > 1e-6 then math.clamp((point - a):Dot(ab) / len2, 0, 1) else 0
	return (a + ab * t - point).Magnitude
end

return ProjectilePath
