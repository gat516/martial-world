--!strict
-- Kinematic movement for enemies, in place of Humanoid physics. A beast on the
-- server is one anchored root part; this walks it toward a goal at a speed,
-- keeps it on the ground, slides it along walls and turns it to face where it
-- goes. It only writes the root's CFrame when the beast actually moves, so a
-- still beast costs nothing to replicate. Clients draw the body (EnemyMotion).
--
--   goal + speed   walk there (XZ; the ground sets the height), then stop
--   push           a knockback velocity until pushUntil, instead of walking
--   turn           face the walking direction (off while attacking)
--   look           face this point instead while walking (circling a target)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Wilds

export type Mover = {
	root: BasePart,
	rootHeight: number, -- the root's height above the ground it stands on
	radius: number, -- half its footprint, for walls and crowding
	speed: number,
	goal: Vector3?,
	turn: boolean,
	look: Vector3?,
	push: Vector3?,
	pushUntil: number,
	nudge: Vector3, -- crowding velocity from neighbours, set each step by EnemyService
}

local EnemyMover = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function EnemyMover.new(root: BasePart, rootHeight: number, radius: number, speed: number): Mover
	return {
		root = root,
		rootHeight = rootHeight,
		radius = radius,
		speed = speed,
		goal = nil,
		turn = true,
		look = nil,
		push = nil,
		pushUntil = 0,
		nudge = Vector3.zero,
	}
end

function EnemyMover.moving(m: Mover, now: number): boolean
	return m.goal ~= nil or (m.push ~= nil and now < m.pushUntil) or m.nudge.Magnitude > 0.01
end

-- Ground height under `position`, or nil over nothing.
local function ground(position: Vector3, rise: number, params: RaycastParams): number?
	local hit = workspace:Raycast(position + Vector3.new(0, rise, 0), Vector3.new(0, -(rise + 60), 0), params)
	return hit and hit.Position.Y
end

-- Advance one step of `dt` seconds. `params` excludes enemies, zones and players
-- and respects CanCollide.
function EnemyMover.step(m: Mover, dt: number, now: number, params: RaycastParams)
	local root = m.root
	local cframe = root.CFrame
	local position = cframe.Position

	local velocity = Vector3.zero
	if m.push and now < m.pushUntil then
		velocity = m.push
	else
		m.push = nil
		local goal = m.goal
		if goal then
			local offset = flat(goal - position)
			local distance = offset.Magnitude
			if distance < 0.3 then
				m.goal = nil
			else
				velocity = offset.Unit * math.min(m.speed, distance / dt)
			end
		end
	end
	velocity += m.nudge
	local move = flat(velocity) * dt
	if move.Magnitude < 0.001 then
		return
	end

	-- walls: look ahead at the root's height and slide along anything steep
	local reach = move.Magnitude + m.radius * 0.6
	local wall = workspace:Raycast(position, move.Unit * reach, params)
	if wall and wall.Normal.Y < Config.WALK_SLOPE then
		local normal = flat(wall.Normal)
		normal = if normal.Magnitude > 0.01 then normal.Unit else -move.Unit
		move -= normal * math.min(0, move:Dot(normal))
		if move.Magnitude < 0.001 or workspace:Raycast(position, move.Unit * reach, params) then
			return
		end
	end

	-- ground: step up gentle rises, refuse cliffs, fall at a capped speed
	local nextXZ = position + move
	local floor = ground(nextXZ, m.rootHeight + Config.CLIMB, params)
	if not floor then
		return
	end
	local standY = floor + m.rootHeight
	if standY - position.Y > Config.CLIMB + move.Magnitude then
		return
	end
	local y = math.max(standY, position.Y - Config.FALL_SPEED * dt)
	local nextPosition = Vector3.new(nextXZ.X, y, nextXZ.Z)

	local rotation = cframe.Rotation
	local look = m.look and flat(m.look - nextPosition)
	if look and look.Magnitude > 0.1 then
		rotation = rotation:Lerp(CFrame.lookAt(Vector3.zero, look.Unit), math.min(1, dt * Config.TURN_RATE))
	elseif m.turn then
		local facing = CFrame.lookAt(Vector3.zero, move.Unit)
		rotation = rotation:Lerp(facing, math.min(1, dt * Config.TURN_RATE))
	end
	root.CFrame = CFrame.new(nextPosition) * rotation
end

return EnemyMover
