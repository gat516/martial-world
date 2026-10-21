--!strict
-- Client-side prediction for enemies' visible bodies, so beasts don't lag or
-- jump around for players with high ping. Purely visual: the server owns where a
-- beast really is (its HumanoidRootPart, replicated as usual) and checks every
-- hit there. This only moves what you see, by offsetting the rig's root joint:
-- the one Motor6D from HumanoidRootPart to the body (`JointRoot` on the beasts,
-- `RootJoint` on R6, `Root` on R15):
--   moving   drawn ahead of the replicated root by its velocity over half your
--            ping (LEAD_MAX at most), which is about where it is on the server now
--   dash     drawn along the server's dash line (DashFrom/DashTo/DashSpeed/DashAt)
--            at the server's clock, so a lunge lands on screen when it lands
-- The drawn spot eases toward the prediction and snaps when it's far off
-- (spawns, the server moving a sleeping beast home). The overhead bar follows the
-- body. Rigs without a root joint, dead beasts and anything past MAX_DISTANCE
-- are drawn where they replicate.
-- The offset is layered on whatever pose the joint already has, so an Animator
-- playing R6 animations (which drive RootJoint) keeps working. Other client code
-- shouldn't write the root joint's Transform; pose the joints below it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_DISTANCE = 160
local LEAD_MAX = 0.25 -- seconds the body may be drawn ahead of the replicated root
local INTERPOLATION = 0.05 -- roughly what Roblox's own replication smoothing adds
local FOLLOW = 18 -- per second, how fast the drawn body eases toward the prediction
local SNAP = 14 -- studs off the prediction before the body just jumps there
local DASH_SLACK = 6 -- studs a dash prediction may run ahead before it's distrusted (the beast was blocked)

type Rig = {
	model: Model,
	root: BasePart,
	joint: Motor6D,
	bar: BillboardGui?,
	humanoid: Humanoid?,
	drawn: Vector3?,
	base: CFrame, -- the joint's pose before our offset (an animation's, or identity)
	written: CFrame?, -- what we last wrote, to tell a fresh animation pose from our own
}

local rigs: { [Model]: Rig } = {}

local EnemyMotion = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not (root and root:IsA("BasePart")) then
		return
	end
	local joint: Motor6D? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 == root then
			joint = d
			break
		end
	end
	if not joint then
		return
	end
	local bar = root:FindFirstChild("HealthBar")
	rigs[model] = {
		model = model,
		root = root,
		joint = joint,
		bar = if bar and bar:IsA("BillboardGui") then bar else nil,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		drawn = nil,
		base = CFrame.identity,
		written = nil,
	}
end

local function release(rig: Rig)
	if rig.written and rig.joint.Transform == rig.written then
		rig.joint.Transform = rig.base
	end
	rig.written = nil
	if rig.bar then
		rig.bar.StudsOffsetWorldSpace = Vector3.zero
	end
	rig.drawn = nil
end

-- Where the beast is on the server about now, from what has replicated.
local function predict(rig: Rig, lead: number, now: number): Vector3
	local model, position = rig.model, rig.root.Position
	if model:GetAttribute("AIState") == "dash" then
		local from, to = model:GetAttribute("DashFrom"), model:GetAttribute("DashTo")
		local speed, at = model:GetAttribute("DashSpeed"), model:GetAttribute("DashAt")
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" and type(speed) == "number" and type(at) == "number" then
			local line = flat(to - from)
			local along = math.clamp((now - at) * speed, 0, line.Magnitude)
			local point = from + (if line.Magnitude > 0 then line.Unit * along else Vector3.zero)
			point = Vector3.new(point.X, position.Y, point.Z)
			if flat(point - position).Magnitude <= speed * (lead + INTERPOLATION) + DASH_SLACK then
				return point
			end
		end
	end
	return position + flat(rig.root.AssemblyLinearVelocity) * lead
end

local function step(dt: number)
	local camera = workspace.CurrentCamera.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local lead = math.min(Players.LocalPlayer:GetNetworkPing() / 2 + INTERPOLATION, LEAD_MAX)
	local ease = 1 - math.exp(-FOLLOW * dt)
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local dead = (rig.humanoid and rig.humanoid.Health <= 0) or model:GetAttribute("FadeAt") ~= nil
		if dead or (rig.root.Position - camera).Magnitude > MAX_DISTANCE then
			if rig.drawn then
				release(rig)
			end
			continue
		end
		local target = predict(rig, lead, now)
		local drawn = rig.drawn
		if not drawn or (drawn - target).Magnitude > SNAP then
			drawn = target
		else
			drawn = drawn:Lerp(target, ease)
		end
		rig.drawn = drawn
		local world = (drawn :: Vector3) - rig.root.Position
		local offset = rig.root.CFrame:VectorToObjectSpace(world)
		local joint = rig.joint
		local current = joint.Transform
		if current ~= rig.written then
			rig.base = current
		end
		local written = CFrame.new(joint.C0:VectorToObjectSpace(offset)) * rig.base
		joint.Transform = written
		rig.written = written
		if rig.bar then
			rig.bar.StudsOffsetWorldSpace = world
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
