--!strict
-- Procedural animation for the jointed enemies. Purely visual and local: each
-- client sets the body's Motor6D Transforms from the enemy's drawn speed and its
-- AIState / Attack / StateAt attributes.
--
-- Bodies with a pose module (FAMILIES, by the enemy's Template attribute) are posed
-- from its tables (src/client/EnemyPoses/, format in each rig's RIGS.md):
--   windup / dash / recover  the attack's move (Attack -> move name), its phase
--            timed from StateAt over the attack's real seconds (Enemies.luau)
--   stagger  the Stagger move, the head thrown away from the target's side
--   dead     the Death move from the moment Health hits 0, held until the fade
--   else     loops: idle, walk, run, or circle (sidestepping with a target, when
--            the module has one)
-- Every other body keeps the old generic pose on JointHead, JointTail and
-- JointLeg* (a trot, a windup crouch, a dash stretch, a stagger flinch).
-- Enemies far from the camera aren't animated. The joints are the client-only
-- body's (EnemyMotion builds it as the enemy's "Body"), and the gait's speed is the
-- drawn body's velocity.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)
local EnemyMotion = require(script.Parent.EnemyMotion)
local Wolf = require(script.Parent.EnemyPoses.Wolf)
-- the boar's pose module may not have landed yet: without it the boar keeps the
-- generic pose
local boarModule = script.Parent.EnemyPoses:FindFirstChild("Boar")
local Boar = if boarModule then require(boarModule :: ModuleScript) :: any else nil

local MAX_DISTANCE = 160
local SMOOTHING = 14 -- how quickly joints settle toward their pose (per second)
local MOVE_SMOOTHING = 30 -- faster during keyed moves, so snaps stay snappy
local STAGGER_SECONDS = 0.28
local DEATH_SECONDS = 0.6

-- A pose module and how a beast's attack names map onto its moves.
-- runFrom: the speed (studs/s) where the walk loop gives way to the run.
type Family = { poses: any, scale: number, moves: { [string]: string }, runFrom: number }

local WOLF_MOVES = { bite = "FangSnap", pounce = "MoonPounce", leap = "MoonfallLeap", howl = "Howl", hop = "Hop" }
local FAMILIES: { [string]: Family } = {
	SpiritWolfB = { poses = Wolf, scale = 1, moves = WOLF_MOVES, runFrom = 9 },
}
-- the gore's hook is its Gore active beat (0.15 s), played at the start of recover
if Boar then
	FAMILIES.StoneBoarB = { poses = Boar, scale = 1, moves = { charge = "Charge", gore = "Gore" }, runFrom = 8 }
end

type Rig = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	phase: number,
	scale: number,
	family: Family?,
	def: Enemies.Def?,
	seed: number,
	lastState: string?,
	side: number, -- stagger/death: +1 the target is on its right
	deadAt: number?,
}

local rigs: { [Model]: Rig } = {}

local EnemyAnimator = {}

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local body = model:WaitForChild("Body", 10)
	local root = body and body:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (body and root) then
		return
	end
	local joints = {}
	for _, d in body:GetDescendants() do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	if next(joints) == nil then
		return
	end
	local kind = model:GetAttribute("EnemyType")
	local bodyName = model:GetAttribute("Template") or kind
	local family = FAMILIES[bodyName :: string]
	rigs[model] = {
		model = model,
		root = root,
		joints = joints,
		phase = math.random() * math.pi * 2,
		-- big rigs (the Elder Wolf King) stride slower
		scale = if family then family.scale else math.max(1, root.Size.Y / 2),
		family = family,
		def = if type(kind) == "string" then Enemies.Defs[kind] else nil,
		seed = math.random() * 100,
		lastState = nil,
		side = 1,
		deadAt = nil,
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

--[[ Pose modules ]]

local function attackOf(def: Enemies.Def?, name: string?): Enemies.Attack?
	if not (def and name) then
		return nil
	end
	for _, a in def.attacks or {} do
		if (a.name or a.kind) == name then
			return a
		end
	end
	if (def.attack.name or def.attack.kind) == name then
		return def.attack
	end
	local howl = def.pack and def.pack.howl
	if howl and (howl.name or howl.kind) == name then
		return howl
	end
	return nil
end

-- The target's character root, from the server's Target attribute.
local function targetRoot(model: Model): BasePart?
	local id = model:GetAttribute("Target")
	local player = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- +1 when the target is on the beast's right, -1 on its left.
local function sideOf(rig: Rig): number
	local target = targetRoot(rig.model)
	if not target then
		return if math.random() < 0.5 then 1 else -1
	end
	return if (target.Position - rig.root.Position):Dot(rig.root.CFrame.RightVector) >= 0 then 1 else -1
end

local function has(poses: any, move: string?, phase: string): boolean
	local m = move and poses.moves[move]
	return m ~= nil and m[phase] ~= nil
end

-- The keyed move for this moment, or nil for the loops.
local function movePose(rig: Rig, family: Family, state: any, since: number): any?
	local poses, def = family.poses, rig.def
	local attackName = rig.model:GetAttribute("Attack")
	local move = if type(attackName) == "string" then family.moves[attackName] else nil
	local attack = attackOf(def, attackName :: string?)
	if state == "stagger" then
		return poses.sample("Stagger", "active", since / STAGGER_SECONDS, { side = rig.side })
	elseif state == "windup" and has(poses, move, "windup") then
		local secs = if attack then attack.windup else poses.durations[move].windup
		return poses.sample(move, "windup", since / secs, { duration = secs })
	elseif state == "dash" and has(poses, move, "active") then
		local secs = poses.durations[move].active
		if attackName == "hop" and def and def.pack and def.pack.hop then
			secs = def.pack.hop.seconds
		elseif attack and attack.kind == "leap" then
			secs = attack.active or secs
		elseif attack and attack.dashSpeed and attack.length then
			-- a charge that stops past the target dashes for less than its full lane
			local dashSecs = rig.model:GetAttribute("DashSeconds")
			secs = if type(dashSecs) == "number" then dashSecs else attack.length / attack.dashSpeed
		end
		return poses.sample(move, "active", since / secs, { duration = secs })
	elseif state == "recover" and move then
		local secs = if attack then attack.recover else 0.5
		-- an attack that strikes without a dash plays its active beat first
		if attack and not attack.dashSpeed and attack.kind ~= "leap" and has(poses, move, "active") then
			local active = poses.durations[move].active
			if since < active then
				return poses.sample(move, "active", since / active, { duration = active })
			end
			since -= active
			secs = math.max(0.05, secs - active)
		end
		if has(poses, move, "recover") then
			return poses.sample(move, "recover", since / secs, { duration = secs })
		end
	end
	return nil
end

local function loopPose(rig: Rig, family: Family, dt: number): any
	local poses = family.poses
	local velocity = EnemyMotion.velocity(rig.model)
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flatVelocity.Magnitude
	local frame = rig.root.CFrame
	local local_ = frame:VectorToObjectSpace(flatVelocity)
	local target = targetRoot(rig.model)
	if target and poses.loops.circle and speed > 1 and math.abs(local_.X) > math.abs(local_.Z) then
		local toTarget = frame:PointToObjectSpace(target.Position)
		local input = {
			dir = if local_.X < 0 then 1 else -1, -- -X is the wolf's left
			targetYaw = math.atan2(-toTarget.X, -toTarget.Z),
		}
		rig.phase += poses.gaitRate("circle", speed, family.scale) * dt
		return poses.loops.circle(rig.phase, speed, input)
	elseif speed < 0.6 then
		return poses.loops.idle(os.clock(), speed, { seed = rig.seed })
	end
	local loop = if speed <= family.runFrom then "walk" else "run"
	rig.phase += poses.gaitRate(loop, speed, family.scale) * dt
	return poses.loops[loop](rig.phase, speed)
end

local function stepFamily(rig: Rig, family: Family, dt: number)
	local model = rig.model
	local state = model:GetAttribute("AIState")
	if state ~= rig.lastState then
		rig.lastState = state :: string?
		if state == "stagger" then
			rig.side = sideOf(rig)
		end
	end
	local health = model:GetAttribute("Health")
	local dead = type(health) == "number" and health <= 0
	local target: any
	if dead then
		if not rig.deadAt then
			rig.deadAt = os.clock()
			rig.side = sideOf(rig)
		end
		target = family.poses.sample("Death", "active", (os.clock() - (rig.deadAt :: number)) / DEATH_SECONDS, { side = rig.side })
	else
		local at = model:GetAttribute("StateAt")
		local since = math.max(0, workspace:GetServerTimeNow() - (if type(at) == "number" then at else 0))
		target = movePose(rig, family, state, since)
	end
	local keyed = target ~= nil
	if not target then
		target = loopPose(rig, family, dt)
	end
	if family.scale ~= 1 then
		target = family.poses.scaled(target, family.scale)
	end
	local alpha = math.min(1, dt * (if keyed then MOVE_SMOOTHING else SMOOTHING))
	for _, name in family.poses.JOINTS do
		pose(rig, name, target[name] or CFrame.identity, alpha)
	end
end

--[[ The generic pose (bodies without a module) ]]

local function stepGeneric(rig: Rig, dt: number, t: number, alpha: number)
	local model = rig.model
	local health = model:GetAttribute("Health")
	if type(health) == "number" and health <= 0 then
		return
	end
	local state = model:GetAttribute("AIState")
	local runSpeed = (model:GetAttribute("RunSpeed") :: number?) or 16
	local velocity = EnemyMotion.velocity(model)
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
	elseif state == "stagger" then
		legFront, legBack = 0.45, -0.35
		headPitch = 0.45
		tailPitch, tailYaw = 0.4, 0
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

local function step(dt: number)
	local camera = workspace.CurrentCamera.CFrame.Position
	local t = os.clock()
	local alpha = math.min(1, dt * SMOOTHING)
	for _, rig in rigs do
		if (rig.root.Position - camera).Magnitude > MAX_DISTANCE then
			continue
		end
		local family = rig.family
		if family then
			stepFamily(rig, family, dt)
		else
			stepGeneric(rig, dt, t, alpha)
		end
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
