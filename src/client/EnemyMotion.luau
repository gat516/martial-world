--!strict
-- Every enemy's visible body, built and drawn on this client. The server's enemy
-- is just an anchored root part with attributes (EnemyService, no Humanoid); it
-- moves in steps (Config.Wilds.MOVE_TICK) and owns where the beast really is and
-- every hit. Here each one gets a local clone of its template from
-- ReplicatedStorage.EnemyBodies, parented under the enemy as "Body", and drawn
-- each frame where the beast is on the server about now:
--   moving   the last replicated spot plus its velocity (from the last two
--            spots) over the time since it arrived and half your ping
--            (LEAD_MAX at most); a beast that stops replicating has stopped
--   dash     along the server's dash line (DashFrom/DashTo/DashSpeed/DashAt)
--            at the server's clock, so a lunge lands on screen when it lands;
--            DashArc lifts the body on a parabola over the line (leaps, hops)
-- The drawn spot eases toward the prediction and snaps when far off (spawns,
-- the server moving a sleeping beast home); it turns smoothly toward the
-- server's facing. Past MAX_DISTANCE bodies sit where they replicate.
-- The body is client-only: no collisions, its Humanoid (kept for an Animator on
-- R6 rigs) never runs. Other client modules find it with model:WaitForChild("Body")
-- and read its drawn velocity with EnemyMotion.velocity. On this client the
-- enemy's PrimaryPart is the body's root, so model:GetPivot() is where it's drawn.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Wilds

local MAX_DISTANCE = 220
local LEAD_MAX = 0.35 -- seconds the body may be drawn ahead of the last replicated spot
local STALE = Config.MOVE_TICK * 2.5 -- no new spot for this long: the beast has stopped
local FOLLOW = 16 -- per second, how fast the drawn body eases toward the prediction
local TURN = 12 -- per second, how fast it turns toward the server's facing
local SNAP = 14 -- studs off the prediction before the body just jumps there
local DASH_SLACK = 6 -- studs a dash prediction may run ahead before it's distrusted (the beast was blocked)

type Rig = {
	model: Model,
	root: BasePart, -- the server's root
	body: Model,
	bodyRoot: BasePart,
	last: Vector3, -- last replicated position
	lastAt: number, -- os.clock() it arrived
	serverVelocity: Vector3, -- estimated from the last two replicated spots
	drawn: CFrame,
	velocity: Vector3, -- of the drawn body, for the gait
}

local rigs: { [Model]: Rig } = {}

local EnemyMotion = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The drawn body's velocity (zero for one not drawn here).
function EnemyMotion.velocity(model: Model): Vector3
	local rig = rigs[model]
	return if rig then rig.velocity else Vector3.zero
end

local function build(model: Model, root: BasePart): Model?
	-- the def's body template (Enemies `body`), else the enemy type
	local kind = model:GetAttribute("Template") or model:GetAttribute("EnemyType")
	local folder = ReplicatedStorage:WaitForChild("EnemyBodies", 10)
	local template = if folder and type(kind) == "string" then folder:FindFirstChild(kind) else nil
	if not (template and template:IsA("Model")) then
		warn(`EnemyMotion: no body for {kind}`)
		return nil
	end
	local body = template:Clone()
	local bodyRoot = body:FindFirstChild("HumanoidRootPart")
	if not (bodyRoot and bodyRoot:IsA("BasePart")) then
		return nil
	end
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == bodyRoot
			d.CanCollide, d.CanTouch = false, false
			d.CanQuery = d ~= bodyRoot -- client hit claims see the limbs (Hitbox.enemiesIn)
			d.Massless = true
		elseif d:IsA("Humanoid") then
			d.EvaluateStateMachine = false
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	body.Name = "Body"
	body.PrimaryPart = bodyRoot
	body:PivotTo(root.CFrame)
	body.Parent = model
	return body
end

local function watch(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (root and root:IsA("BasePart")) then
		return
	end
	local existing = model:FindFirstChild("Body")
	local body = if existing and existing:IsA("Model") then existing else build(model, root)
	local bodyRoot = body and body:FindFirstChild("HumanoidRootPart")
	if not (body and bodyRoot and bodyRoot:IsA("BasePart")) then
		return
	end
	-- locally, the model's pivot is the drawn body: lock-on, auto-approach and
	-- effects (model:GetPivot()) aim at what you see, not the lagging server root
	model.PrimaryPart = bodyRoot
	rigs[model] = {
		model = model,
		root = root,
		body = body,
		bodyRoot = bodyRoot,
		last = root.Position,
		lastAt = os.clock(),
		serverVelocity = Vector3.zero,
		drawn = root.CFrame,
		velocity = Vector3.zero,
	}
end

-- A leap's or bound's height, 0..1 over its flight (f, the share of the ground covered, which
-- runs at a constant speed). WEIGHTED_MOVES: a quicker rise, a short hang at the apex and a
-- quicker drop (same apex, same flight time, same landing); otherwise the plain parabola.
local HANG = 2.6 -- 2 is the parabola; higher flattens the top and steepens the ends
local function arcShape(f: number): number
	if Config.WEIGHTED_MOVES then
		return 1 - math.abs(2 * f - 1) ^ HANG
	end
	return 4 * f * (1 - f)
end

-- Where the beast is on the server about now, from what has replicated.
local function predict(rig: Rig, ping: number, now: number, clock: number): Vector3
	local model, position = rig.model, rig.last
	if model:GetAttribute("AIState") == "dash" then
		local from, to = model:GetAttribute("DashFrom"), model:GetAttribute("DashTo")
		local speed, at = model:GetAttribute("DashSpeed"), model:GetAttribute("DashAt")
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" and type(speed) == "number" and type(at) == "number" then
			local line = flat(to - from)
			local along = math.clamp((now - at) * speed, 0, line.Magnitude)
			local point = from + (if line.Magnitude > 0 then line.Unit * along else Vector3.zero)
			local arc = model:GetAttribute("DashArc")
			local f = if line.Magnitude > 0 then along / line.Magnitude else 1
			local lift = if type(arc) == "number" and arc > 0 then arc * arcShape(f) else 0
			point = Vector3.new(point.X, position.Y + lift, point.Z)
			if flat(point - position).Magnitude <= speed * (ping + STALE) + DASH_SLACK then
				return point
			end
		end
	end
	local since = clock - rig.lastAt
	if since > STALE then
		return position
	end
	return position + rig.serverVelocity * math.min(since + ping / 2, LEAD_MAX)
end

local function step(dt: number)
	local camera = workspace.CurrentCamera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local ping = Players.LocalPlayer:GetNetworkPing()
	local ease = 1 - math.exp(-FOLLOW * dt)
	local turn = 1 - math.exp(-TURN * dt)
	for model, rig in rigs do
		if not model.Parent or not rig.body.Parent then
			rigs[model] = nil
			continue
		end
		local root = rig.root
		local position = root.Position
		if position ~= rig.last then
			local gap = clock - rig.lastAt
			local measured = flat(position - rig.last) / math.max(gap, Config.MOVE_TICK * 0.5)
			rig.serverVelocity = if gap > STALE then measured else rig.serverVelocity:Lerp(measured, 0.6)
			rig.last, rig.lastAt = position, clock
		end
		local health = model:GetAttribute("Health")
		local dead = model:GetAttribute("FadeAt") ~= nil or (type(health) == "number" and health <= 0)
		local target: CFrame
		if dead then
			-- a dying body stays where it fell
			target = rig.drawn
			rig.velocity = Vector3.zero
		elseif (position - camera).Magnitude > MAX_DISTANCE then
			target = root.CFrame
			rig.velocity = Vector3.zero
		else
			local predicted = predict(rig, ping, now, clock)
			local drawn = rig.drawn.Position
			local nextPosition = if (drawn - predicted).Magnitude > SNAP then predicted else drawn:Lerp(predicted, ease)
			local rotation = rig.drawn.Rotation:Lerp(root.CFrame.Rotation, turn)
			rig.velocity = (nextPosition - drawn) / math.max(dt, 1 / 240)
			target = CFrame.new(nextPosition) * rotation
		end
		rig.drawn = target
		if rig.bodyRoot.CFrame ~= target then
			rig.bodyRoot.CFrame = target
		end
	end
end

function EnemyMotion.init()
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	RunService.RenderStepped:Connect(step)
end

return EnemyMotion
