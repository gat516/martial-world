--!strict
-- Procedural animation for the jointed enemies (Motor6Ds named JointHead,
-- JointTail and JointLegFL/FR/BL/BR). Purely visual and local: each client sets
-- the joints' Transform from the enemy's speed and its AIState attribute.
--   moving   a trotting gait (diagonal legs together), faster with speed
--   idle     slow breathing, ears-up head, a lazy tail wag
--   windup   crouched: head low, legs braced, tail stiff and high
--   dash     stretched out: front legs reaching, back legs pushing
-- Enemies far from the camera aren't animated.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MAX_DISTANCE = 160
local SMOOTHING = 14 -- how quickly joints settle toward their pose (per second)

type Rig = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	phase: number,
	scale: number,
}

local rigs: { [Model]: Rig } = {}

local EnemyAnimator = {}

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	if next(joints) == nil then
		return
	end
	rigs[model] = {
		model = model,
		root = root,
		joints = joints,
		phase = math.random() * math.pi * 2,
		-- big rigs (the Elder Wolf King) stride slower
		scale = math.max(1, root.Size.Y / 2),
	}
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			rigs[model] = nil
		end
	end)
end

local function pose(rig: Rig, name: string, target: CFrame, alpha: number)
	local joint = rig.joints[name]
	if joint then
		joint.Transform = joint.Transform:Lerp(target, alpha)
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera.CFrame.Position
	local t = os.clock()
	local alpha = math.min(1, dt * SMOOTHING)
	for model, rig in rigs do
		if (rig.root.Position - camera).Magnitude > MAX_DISTANCE then
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			continue
		end
		local state = model:GetAttribute("AIState")
		local runSpeed = (model:GetAttribute("RunSpeed") :: number?) or 16
		local velocity = rig.root.AssemblyLinearVelocity
		local speed = Vector2.new(velocity.X, velocity.Z).Magnitude
		local gait = math.clamp(speed / runSpeed, 0, 1.3)
		rig.phase += dt * (3 + speed * 0.55) / rig.scale

		local swing = math.sin(rig.phase) * 0.65 * gait
		local legFront, legBack = 0, 0
		local headPitch = math.sin(t * 2) * 0.03 + math.sin(rig.phase * 2) * 0.05 * gait
		local tailPitch, tailYaw = -0.1, math.sin(t * 3) * 0.25
		if state == "windup" then
			legFront, legBack = -0.25, 0.3
			headPitch = -0.3
			tailPitch, tailYaw = -0.55, 0
			swing = 0
		elseif state == "dash" then
			legFront, legBack = -0.75, 0.75
			headPitch = 0.1
			tailPitch, tailYaw = 0.25, 0
			swing = 0
		elseif state == "chase" then
			tailPitch = -0.35
			tailYaw = math.sin(t * 9) * 0.15
		end

		pose(rig, "JointLegFL", CFrame.Angles(swing + legFront, 0, 0), alpha)
		pose(rig, "JointLegBR", CFrame.Angles(swing + legBack, 0, 0), alpha)
		pose(rig, "JointLegFR", CFrame.Angles(-swing + legFront, 0, 0), alpha)
		pose(rig, "JointLegBL", CFrame.Angles(-swing + legBack, 0, 0), alpha)
		pose(rig, "JointHead", CFrame.Angles(headPitch, 0, 0), alpha)
		pose(rig, "JointTail", CFrame.Angles(tailPitch, tailYaw, 0), alpha)
	end
end

function EnemyAnimator.init()
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	RunService.RenderStepped:Connect(step)
end

return EnemyAnimator
