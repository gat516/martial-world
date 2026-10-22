--!strict
-- Boss projectiles (bosses only; see enemies.md "Boss projectiles"). A projectile
-- is simulated here and hits whoever it reaches when it reaches them, so a player
-- beats it by sidestepping or dashing through; walls and rising ground stop it.
-- Clients get one spawn and one end message over the Effect remote and draw the
-- flight themselves from the same path (ProjectilePath, ProjectileView).
--
-- Warning the player (the windup half; the projectile is the warning in flight):
--   Projectiles.warnLane(owner, name, origin, dir, length, width, seconds)
--       a straight shot: the red lane it flies down, filling until release
--   Projectiles.warnLanding(owner, name, at, radius, seconds)
--       a lob: its landing circle; pass windup + flight so it fills at touchdown
--   Projectiles.mark(player, owner, name, seconds)
--       a homing shot: a red ring under the target that follows them
--
-- Firing:
--   local id = Projectiles.fire({
--       owner = enemy.model, cue = "boulder", origin = ..., velocity = ...,
--       radius = 3, gravity = 0, range = 90, lifetime = 3,
--       onHit = function(player, position) ctx.hurtPlayer(enemy, attack, player) end,
--   })
--   Projectiles.lobVelocity(origin, target, seconds, gravity) for a lob.
--
-- Hits: a player is hit when the swept segment of this step comes within
-- radius + PLAYER_RADIUS of their root, both where the server sees them and
-- where their own movement carries them within half their ping (at most
-- ESCAPE_LEAD), the same grace as EnemyService's ground areas. onHit does the
-- damage (Combat.hurt through the boss's hurtPlayer, so dodges, reactions and
-- knockback apply). Every player is tested once per projectile; with `pierce`
-- the shot flies on through them, otherwise it ends on the first. A player in
-- dodge i-frames (Combat.evading) is passed through either way: onHit still
-- runs, so Combat.hurt grants the perfect dodge, but the shot flies on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.Config).Combat
local ProjectilePath = require(ReplicatedStorage.Shared.ProjectilePath)
local Combat = require(script.Parent.Combat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local effectRemote = remotes:WaitForChild("Effect") :: RemoteEvent
local telegraphRemote = remotes:WaitForChild("Telegraph") :: RemoteEvent

local PLAYER_RADIUS = 1.5 -- matches EnemyService: a player's body past the root
local MAX_ACTIVE = 80 -- fire() refuses past this many in flight
local DEFAULT_LIFETIME = 4

export type Spec = {
	owner: Model?, -- the boss; the shot ends if it dies or leaves, and never hits it
	cue: string, -- what clients draw (ProjectileView.register)
	origin: Vector3,
	velocity: Vector3, -- studs/s (Projectiles.lobVelocity for a lob)
	radius: number, -- the shot's hit radius in studs
	gravity: number?, -- studs/s^2 down (default 0: straight)
	homing: { player: Player, turn: number }?, -- turn: degrees/s toward the player's root
	range: number?, -- ends after flying this far
	lifetime: number?, -- ends after this many seconds (default 4)
	pierce: boolean?, -- flies on through players it hits
	terrain: boolean?, -- false: passes through the map (default: stopped by it)
	ignore: { Instance }?, -- more instances the map sweep skips
	onHit: ((player: Player, position: Vector3) -> boolean?)?, -- return false: not a hit, fly on
	onEnd: ((position: Vector3, reason: string) -> ())?, -- "hit" | "terrain" | "range" | "lifetime" | "owner" | "cancel"
	data: { [string]: any }?, -- passed through to the clients' drawer (colour, tier...)
}

type Live = {
	id: number,
	spec: Spec,
	state: ProjectilePath.State,
	startedAt: number, -- server time
	travelled: number,
	tested: { [Player]: boolean },
}

local Projectiles = {}

local live: { [number]: Live } = {}
local count = 0
local nextId = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The map sweep skips characters, live enemies, telegraph zones and the owner.
local function mapParams(spec: Spec): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore: { Instance } = {}
	local wilds = workspace:FindFirstChild("Wilds")
	for _, name in { "Enemies", "Zones" } do
		local f = wilds and wilds:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if spec.owner then
		table.insert(ignore, spec.owner)
	end
	for _, i in spec.ignore or {} do
		table.insert(ignore, i)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function finish(p: Live, position: Vector3, reason: string)
	if not live[p.id] then
		return
	end
	live[p.id] = nil
	count -= 1
	effectRemote:FireAllClients("projectileEnd", p.id, position, reason)
	local onEnd = p.spec.onEnd
	if onEnd then
		task.spawn(onEnd, position, reason)
	end
end

-- Did this step's segment reach the player, with high-ping grace?
local function reaches(a: Vector3, b: Vector3, reach: number, player: Player, root: BasePart): boolean
	if ProjectilePath.segmentDistance(a, b, root.Position) > reach then
		return false
	end
	local lead = math.min(player:GetNetworkPing() / 2, CombatConfig.ESCAPE_LEAD)
	local velocity = flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude > CombatConfig.DODGE_SPEED then
		velocity = velocity.Unit * CombatConfig.DODGE_SPEED
	end
	return ProjectilePath.segmentDistance(a, b, root.Position + velocity * lead) <= reach
end

local function step(p: Live, dt: number)
	local spec = p.spec
	if spec.owner and not spec.owner.Parent then
		finish(p, p.state.position, "owner")
		return
	end
	local homing = spec.homing
	local target: Vector3? = nil
	if homing then
		local root = playerRoot(homing.player)
		target = root and root.Position
	end
	local a = p.state.position
	local nextState = ProjectilePath.step(p.state, dt, spec.gravity or 0, target, if homing then homing.turn else nil)
	local b = nextState.position
	local reason: string? = nil
	if spec.terrain ~= false and (b - a).Magnitude > 1e-3 then
		local hit = workspace:Spherecast(a, math.max(spec.radius * 0.5, 0.25), b - a, mapParams(spec))
		if hit then
			b = hit.Position
			reason = "terrain"
		end
	end
	local reach = spec.radius + PLAYER_RADIUS
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root and not p.tested[player] and reaches(a, b, reach, player, root) then
			p.tested[player] = true
			local landed = not Combat.evading(player)
			if spec.onHit and spec.onHit(player, b) == false then
				landed = false
			end
			if landed and not spec.pierce then
				p.state = nextState
				finish(p, b, "hit")
				return
			end
		end
	end
	p.travelled += (b - a).Magnitude
	p.state = { position = b, velocity = nextState.velocity }
	if reason then
		finish(p, b, reason)
	elseif spec.range and p.travelled >= spec.range then
		finish(p, b, "range")
	elseif now() - p.startedAt >= (spec.lifetime or DEFAULT_LIFETIME) then
		finish(p, b, "lifetime")
	end
end

-- Launch a projectile. Returns its id, or nil when too many are in flight.
function Projectiles.fire(spec: Spec): number?
	if count >= MAX_ACTIVE then
		warn("Projectiles: too many in flight; dropped a", spec.cue)
		return nil
	end
	nextId += 1
	count += 1
	local p: Live = {
		id = nextId,
		spec = spec,
		state = { position = spec.origin, velocity = spec.velocity },
		startedAt = now(),
		travelled = 0,
		tested = {},
	}
	live[p.id] = p
	effectRemote:FireAllClients("projectile", {
		id = p.id,
		cue = spec.cue,
		owner = spec.owner,
		origin = spec.origin,
		velocity = spec.velocity,
		radius = spec.radius,
		gravity = spec.gravity or 0,
		homing = if spec.homing then { player = spec.homing.player, turn = spec.homing.turn } else nil,
		lifetime = spec.lifetime or DEFAULT_LIFETIME,
		startedAt = p.startedAt,
		data = spec.data,
	})
	return p.id
end

-- End a projectile early (its owner was staggered out of the cast, a phase change).
function Projectiles.cancel(id: number)
	local p = live[id]
	if p then
		finish(p, p.state.position, "cancel")
	end
end

-- End every projectile an owner fired (it died, despawned or reset).
function Projectiles.cancelOwner(owner: Model)
	for _, p in live do
		if p.spec.owner == owner then
			finish(p, p.state.position, "owner")
		end
	end
end

-- Where a projectile is now, or nil once it has ended.
function Projectiles.position(id: number): Vector3?
	local p = live[id]
	return p and p.state.position
end

Projectiles.lobVelocity = ProjectilePath.lob

-- Warnings, through the same red telegraphs as melee (Telegraphs.luau). `name`
-- is the attack name the telegraph carries (EnemyFX can key off it).
function Projectiles.warnLane(owner: Model?, name: string, origin: Vector3, dir: Vector3, length: number, width: number, seconds: number)
	local d = flat(dir)
	if d.Magnitude < 1e-3 then
		return
	end
	-- origin: the ground point the lane starts from
	local cframe = CFrame.lookAt(origin, origin + d) * CFrame.new(0, 0, -length / 2)
	telegraphRemote:FireAllClients({ kind = "box", cframe = cframe, size = Vector2.new(width, length) }, seconds, owner, name, now())
end

function Projectiles.warnLanding(owner: Model?, name: string, at: Vector3, radius: number, seconds: number)
	telegraphRemote:FireAllClients({ kind = "circle", center = at, radius = radius }, seconds, owner, name, now())
end

-- A homing shot's warning: a red ring under `player` that follows them for `seconds`.
function Projectiles.mark(player: Player, owner: Model?, name: string, seconds: number)
	effectRemote:FireAllClients("projectileMark", player, owner, name, seconds, now())
end

RunService.Heartbeat:Connect(function(dt: number)
	for _, p in live do
		step(p, dt)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	for _, p in live do
		p.tested[player] = nil
		if p.spec.homing and p.spec.homing.player == player then
			p.spec.homing = nil
		end
	end
end)

return Projectiles
