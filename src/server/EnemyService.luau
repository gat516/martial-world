--!strict
-- Wilds enemies: a simple state machine per enemy, telegraphed attacks and kill
-- rewards. Where and when they appear is Spawner.luau's job; this module only
-- spawns one on request and tells EnemyService.onRemoved when it's gone.
--
-- Enemies are cloned from ServerStorage.Enemies, tagged "Enemy", and walk with
-- their Humanoid (server-owned physics, so clients see smooth movement). Each
-- has a home it wanders around (`roam` studs) and leashes back to.
--
-- States: idle (wander near home) -> chase -> windup (telegraph on the ground)
-- -> dash (lunge/charge only) -> recover -> chase. Past its leash an enemy
-- returns home and heals. Player hits can knock it back into "stagger" for a
-- moment, depending on realm and weight (Knockback.luau). Every attack that hurts shows its exact area to all
-- clients first (Telegraph remote) and resolves on the server through Combat.hurt,
-- so dodging through it negates the hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config).Wilds
local DEFAULT_ROAM = 15 -- studs an enemy wanders from home unless told otherwise
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Combat = require(script.Parent.Combat)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local remotes = ReplicatedStorage.Remotes
local telegraphRemote = remotes.Telegraph :: RemoteEvent
local effectRemote = remotes.Effect :: RemoteEvent

local wilds = workspace:WaitForChild("Wilds")
local liveFolder = wilds:WaitForChild("Enemies") :: Folder
local templates = ServerStorage:WaitForChild("Enemies") :: Folder

local PLAYER_RADIUS = 1.5 -- players count as inside an area this far past its edge
local AREA_HEIGHT = 8 -- areas reach this far up and down from the ground

export type Shape = {
	kind: string, -- "box" | "circle"
	cframe: CFrame?, -- box: centred on the ground, -Z along its length
	size: Vector2?, -- box: width, length
	center: Vector3?, -- circle
	radius: number?, -- circle
}

type Enemy = {
	model: Model,
	def: Enemies.Def,
	humanoid: Humanoid,
	root: BasePart,
	home: Vector3,
	roam: number,
	rootHeight: number,
	state: string,
	stateUntil: number,
	target: Player?,
	nextAttack: number,
	nextWander: number,
	shape: Shape?,
	dashTo: Vector3?,
	damagers: { [Player]: boolean },
	attack: Enemies.Attack, -- the attack in progress, or the next one to use
	patternIndex: number,
	summonsDone: { [number]: boolean }, -- summonAt thresholds already used
	summoned: { Model }, -- live summons (bosses)
	staggerImmuneUntil: number,
}

local enemies: { [Model]: Enemy } = {}

local EnemyService = {}

-- Called with (player, def, model) for each player credited with a kill.
EnemyService.onKill = {} :: { (Player, Enemies.Def, Model) -> () }
-- Called with (model, killed) when an enemy leaves: killed, or despawned.
EnemyService.onRemoved = {} :: { (Model, boolean) -> () }

export type SpawnOptions = {
	home: Vector3?, -- where it wanders and leashes back to (default: where it spawns)
	roam: number?, -- studs it wanders from home
	target: Player?, -- comes straight for this player
}

local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { liveFolder, wilds:FindFirstChild("Zones") :: Instance }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function groundAt(position: Vector3): Vector3
	local hit = workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), groundParams())
	return if hit then hit.Position else position
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--[[ Areas ]]

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

function EnemyService.inside(shape: Shape, position: Vector3): boolean
	if shape.kind == "box" then
		local cframe, size = shape.cframe :: CFrame, shape.size :: Vector2
		local p = cframe:PointToObjectSpace(position)
		return math.abs(p.X) <= size.X / 2 + PLAYER_RADIUS
			and math.abs(p.Z) <= size.Y / 2 + PLAYER_RADIUS
			and math.abs(p.Y) <= AREA_HEIGHT
	elseif shape.kind == "circle" then
		local center = shape.center :: Vector3
		return flat(position - center).Magnitude <= (shape.radius :: number) + PLAYER_RADIUS
			and math.abs(position.Y - center.Y) <= AREA_HEIGHT
	elseif shape.kind == "cone" then
		local center, dir = shape.center :: Vector3, (shape.cframe :: CFrame).LookVector
		local offset = flat(position - center)
		if offset.Magnitude > (shape.radius :: number) + PLAYER_RADIUS or math.abs(position.Y - center.Y) > AREA_HEIGHT then
			return false
		end
		local half = math.rad((shape.size :: Vector2).X / 2)
		return offset.Magnitude < 2 or flat(dir).Unit:Dot(offset.Unit) >= math.cos(half)
	end
	return false
end

-- Show an area to every client for `seconds`, then hurt every player in it.
-- Returns the players it hit.
function EnemyService.strike(shape: Shape, seconds: number, damage: number, nonLethal: boolean?, only: Player?, source: string?): { Player }
	telegraphRemote:FireAllClients(shape, seconds)
	task.wait(seconds)
	local hit = {}
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root and (only == nil or only == player) and EnemyService.inside(shape, root.Position) then
			local result = Combat.hurt(player, damage, nonLethal, source)
			if result == "hit" then
				table.insert(hit, player)
			end
		end
	end
	return hit
end

--[[ Spawning ]]

function EnemyService.spawn(id: string, at: Vector3, options: SpawnOptions?): Model?
	local opts: SpawnOptions = options or {}
	local def = Enemies.Defs[id]
	local template = templates:FindFirstChild(id) :: Model?
	if not (def and template) then
		warn(`EnemyService: no enemy "{id}"`)
		return nil
	end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- Rojo's live sync drops Model.PrimaryPart, so find the root by name
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.PrimaryPart = root
	local rootHeight = (template:FindFirstChild("HumanoidRootPart") :: BasePart).Position.Y
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health
	humanoid.WalkSpeed = def.walkSpeed
	local ground = groundAt(at)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, rootHeight, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model:SetAttribute("EnemyType", id)
	model:SetAttribute("RunSpeed", def.runSpeed)
	model:SetAttribute("Realm", Realms.get(def.realm[1], def.realm[2]).name)
	model:AddTag("Enemy")
	model.Parent = liveFolder
	root:SetNetworkOwner(nil)

	local enemy: Enemy = {
		model = model,
		def = def,
		humanoid = humanoid,
		root = root,
		home = opts.home or ground,
		roam = opts.roam or DEFAULT_ROAM,
		rootHeight = rootHeight,
		state = "idle",
		stateUntil = 0,
		target = opts.target,
		nextAttack = 0,
		nextWander = os.clock() + math.random() * 3,
		shape = nil,
		dashTo = nil,
		damagers = {},
		attack = def.attack,
		patternIndex = 0,
		summonsDone = {},
		summoned = {},
		staggerImmuneUntil = 0,
	}
	enemies[model] = enemy
	humanoid.Died:Connect(function()
		EnemyService.died(enemy)
	end)
	return model
end

local function randomPointNear(center: Vector3, radius: number): Vector3
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
	return center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function fadeAway(enemy: Enemy)
	enemy.root.Anchored = true
	for _, d in enemy.model:GetDescendants() do
		if d:IsA("BasePart") and d ~= enemy.root then
			TweenService:Create(d, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.2, function()
		enemy.model:Destroy()
	end)
end

-- Remove an enemy without rewards (an event ended, nobody's near it).
function EnemyService.despawn(model: Model)
	local enemy = enemies[model]
	if not enemy then
		return
	end
	enemies[model] = nil
	fadeAway(enemy)
	for _, fn in EnemyService.onRemoved do
		task.spawn(fn, model, false)
	end
end

function EnemyService.isAlive(model: Model): boolean
	return enemies[model] ~= nil
end

-- The player it's after, if any.
function EnemyService.targetOf(model: Model): Player?
	local enemy = enemies[model]
	return enemy and enemy.target
end

--[[ Death and rewards ]]

local function qiFor(def: Enemies.Def, data: PlayerData.Data): number
	local dantian = Realms.get(data.realm.major, data.realm.minor).dantian
	return math.floor(def.qiDrop * (dantian / Realms.Stages[1].dantian) ^ Enemies.QI_SCALE_EXPONENT + 0.5)
end

function EnemyService.died(enemy: Enemy)
	if enemies[enemy.model] ~= enemy then
		return
	end
	enemies[enemy.model] = nil
	local position = enemy.root.Position
	for player in enemy.damagers do
		local data = player.Parent and PlayerData.get(player)
		if data then
			local cap = Cultivation.stage(data).dantian
			local amount = math.min(qiFor(enemy.def, data), cap - data.rawQi)
			data.rawQi += math.max(0, amount)
			data.stats.kills += 1
			local stones = math.random(enemy.def.stones[1], enemy.def.stones[2])
			data.stones += stones
			Cultivation.markActive(player)
			-- a boss opens the victory card first, so the rewards below land in it
			if enemy.def.boss then
				effectRemote:FireClient(player, "boss", enemy.def.name, math.max(0, amount))
			end
			effectRemote:FireClient(player, "stones", position, stones)
			for _, fn in EnemyService.onKill do
				task.spawn(fn, player, enemy.def, enemy.model)
			end
			Cultivation.pushState(player)
			if amount > 0 then
				effectRemote:FireClient(player, "qi", position, amount)
			else
				Cultivation.notify(player, "Your dantian is full. Circulate to refine it.")
			end
		end
	end

	fadeAway(enemy)
	if enemy.def.boss then
		local names = {}
		for player in enemy.damagers do
			if player.Parent then
				table.insert(names, player.DisplayName)
			end
		end
		if #names > 0 then
			remotes.Notify:FireAllClients(`{table.concat(names, ", ")} defeated the {enemy.def.name}!`)
		end
	end
	for _, fn in EnemyService.onRemoved do
		task.spawn(fn, enemy.model, true)
	end
end

--[[ AI ]]

local function home(enemy: Enemy): Vector3
	return enemy.home
end

local function face(enemy: Enemy, toward: Vector3)
	local p = enemy.root.Position
	local look = Vector3.new(toward.X, p.Y, toward.Z)
	if (look - p).Magnitude > 0.1 then
		enemy.root.CFrame = CFrame.lookAt(p, look)
	end
end

local function stop(enemy: Enemy)
	enemy.humanoid:MoveTo(enemy.root.Position)
end

local function setState(enemy: Enemy, state: string)
	enemy.state = state
	-- clients animate from this (crouch on windup, stretch on dash)
	if enemy.model:GetAttribute("AIState") ~= state then
		enemy.model:SetAttribute("AIState", state)
	end
end

-- Shove the enemy `distance` studs along `dir` over Knockback.PUSH_SECONDS.
local function shove(enemy: Enemy, dir: Vector3, distance: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = enemy.root
	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(1, 0, 1) * enemy.root.AssemblyMass * 2000
	mover.VectorVelocity = dir * (distance / Knockback.PUSH_SECONDS)
	mover.Parent = enemy.root
	task.delay(Knockback.PUSH_SECONDS, function()
		attachment:Destroy()
		mover:Destroy()
		-- plant it where it landed, not back where it was told to walk
		if enemy.state == "stagger" and enemy.model.Parent then
			stop(enemy)
		end
	end)
end

-- A player hit with a push: knock the enemy back and stagger it if the
-- player's realm against its realm and weight is enough to move it at all.
local function knock(enemy: Enemy, player: Player, push: Vector3)
	local base = push.Magnitude
	if base < 0.01 or enemy.state == "return" then
		return
	end
	local distance = Knockback.distance(base, Combat.power(player), enemy.def)
	local committed = enemy.state == "windup" or enemy.state == "dash"
	if distance <= 0 or (committed and distance < Knockback.ARMOR_BREAK) then
		return
	end
	shove(enemy, push.Unit, distance)
	local now = os.clock()
	if now < enemy.staggerImmuneUntil and not committed then
		return
	end
	-- a windup broken here never resolves; its telegraph just fades
	enemy.shape, enemy.dashTo = nil, nil
	enemy.humanoid.WalkSpeed = enemy.def.runSpeed
	enemy.humanoid.AutoRotate = false
	setState(enemy, "stagger")
	enemy.stateUntil = now + Knockback.stun(distance)
	enemy.staggerImmuneUntil = enemy.stateUntil + Knockback.RESTAGGER
end

-- Damage from players: remember who to credit, turn on them if idle, and
-- take the hit's knockback.
Combat.onEnemyDamaged = function(model: Model, player: Player, _amount: number, push: Vector3?)
	local enemy = enemies[model]
	if enemy then
		enemy.damagers[player] = true
		if not enemy.target and enemy.state ~= "return" then
			enemy.target = player
		end
		if push and enemy.humanoid.Health > 0 then
			knock(enemy, player, push)
		end
	end
end

-- Keep the current target while it's alive and not too far, else find the nearest.
local function pickTarget(enemy: Enemy): (Player?, BasePart?)
	local def = enemy.def
	local position = enemy.root.Position
	local leashCenter, leash = home(enemy), def.leash
	if enemy.target then
		local root = playerRoot(enemy.target)
		if
			root
			and (root.Position - position).Magnitude <= def.aggro * 1.5
			and flat(root.Position - leashCenter).Magnitude <= leash
		then
			return enemy.target, root
		end
	end
	local best, bestRoot, bestDist = nil, nil, def.aggro
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root and flat(root.Position - leashCenter).Magnitude <= leash then
			local d = (root.Position - position).Magnitude
			if d <= bestDist then
				best, bestRoot, bestDist = player, root, d
			end
		end
	end
	return best, bestRoot
end

local function startAttack(enemy: Enemy, targetRoot: BasePart, now: number, attack: Enemies.Attack)
	enemy.attack = attack
	stop(enemy)
	enemy.humanoid.AutoRotate = false
	face(enemy, targetRoot.Position)
	local ground = groundAt(enemy.root.Position)
	local dir = flat(targetRoot.Position - enemy.root.Position)
	dir = if dir.Magnitude > 0.1 then dir.Unit else flat(enemy.root.CFrame.LookVector).Unit

	local shape: Shape
	if attack.kind == "spit" then
		shape = { kind = "circle", center = groundAt(targetRoot.Position), radius = attack.radius }
	elseif attack.kind == "slam" then
		shape = { kind = "circle", center = ground, radius = attack.radius }
	elseif attack.kind == "cone" then
		shape = {
			kind = "cone",
			center = ground,
			cframe = CFrame.lookAt(ground, ground + dir),
			radius = attack.radius,
			size = Vector2.new(attack.angle :: number, 0),
		}
	elseif attack.kind == "summon" then
		shape = { kind = "howl", center = ground, radius = 8 }
	else
		local length = attack.length :: number
		shape = {
			kind = "box",
			cframe = CFrame.lookAt(ground, ground + dir) * CFrame.new(0, 0, -length / 2),
			size = Vector2.new(attack.width :: number, length),
		}
		enemy.dashTo = enemy.root.Position + dir * length
	end
	enemy.shape = shape
	enemy.state = "windup"
	enemy.stateUntil = now + attack.windup
	enemy.nextAttack = now + attack.cooldown
	telegraphRemote:FireAllClients(shape, attack.windup)
end

local function summon(enemy: Enemy, attack: Enemies.Attack)
	for i = #enemy.summoned, 1, -1 do
		local m = enemy.summoned[i]
		local h = m:FindFirstChildOfClass("Humanoid")
		if not (m.Parent and h and h.Health > 0) then
			table.remove(enemy.summoned, i)
		end
	end
	local room = (attack.maxAlive or 4) - #enemy.summoned
	for _ = 1, math.min(attack.count or 1, room) do
		local a = math.random() * math.pi * 2
		local at = enemy.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 8
		local model = EnemyService.spawn(attack.summons :: string, at, { home = enemy.home, roam = enemy.roam })
		if model then
			table.insert(enemy.summoned, model)
			local spawned = enemies[model]
			if spawned then
				spawned.target = enemy.target
			end
		end
	end
end

-- Bosses go through their pattern in order; everyone else repeats one attack.
local function advancePattern(enemy: Enemy)
	local pattern = enemy.def.pattern
	if pattern then
		enemy.patternIndex = enemy.patternIndex % #pattern + 1
		enemy.attack = pattern[enemy.patternIndex]
	end
end

local function resolveAttack(enemy: Enemy, now: number)
	local attack = enemy.attack
	local shape = enemy.shape :: Shape
	if attack.kind == "summon" then
		summon(enemy, attack)
	else
		for _, player in Players:GetPlayers() do
			local root = playerRoot(player)
			if root and EnemyService.inside(shape, root.Position) then
				Combat.hurt(player, attack.damage, false, enemy.def.id)
			end
		end
	end
	enemy.shape = nil
	if enemy.dashTo then
		enemy.humanoid.WalkSpeed = attack.dashSpeed :: number
		enemy.humanoid:MoveTo(enemy.dashTo)
		enemy.state = "dash"
		enemy.stateUntil = now + (attack.length :: number) / (attack.dashSpeed :: number) + 0.1
		enemy.dashTo = nil
	else
		enemy.state = "recover"
		enemy.stateUntil = now + attack.recover
	end
	advancePattern(enemy)
end

local function think(enemy: Enemy, now: number)
	local def, humanoid = enemy.def, enemy.humanoid
	local position = enemy.root.Position

	if enemy.state == "windup" then
		if now >= enemy.stateUntil then
			resolveAttack(enemy, now)
		end
		return
	elseif enemy.state == "dash" then
		if now >= enemy.stateUntil then
			stop(enemy)
			humanoid.WalkSpeed = def.runSpeed
			enemy.state = "recover"
			enemy.stateUntil = now + def.attack.recover
		end
		return
	elseif enemy.state == "recover" or enemy.state == "stagger" then
		if now < enemy.stateUntil then
			return
		end
		humanoid.AutoRotate = true
		enemy.state = "chase"
	elseif enemy.state == "return" then
		if flat(position - home(enemy)).Magnitude < 8 then
			humanoid.Health = humanoid.MaxHealth
			table.clear(enemy.damagers)
			enemy.state = "idle"
		else
			humanoid:MoveTo(home(enemy))
		end
		return
	end

	if flat(position - home(enemy)).Magnitude > def.leash then
		enemy.target = nil
		enemy.state = "return"
		humanoid.WalkSpeed = def.runSpeed
		humanoid:MoveTo(home(enemy))
		return
	end

	local target, targetRoot = pickTarget(enemy)
	enemy.target = target
	if not (target and targetRoot) then
		enemy.state = "idle"
		humanoid.WalkSpeed = def.walkSpeed
		if now >= enemy.nextWander then
			enemy.nextWander = now + 4 + math.random() * 4
			humanoid:MoveTo(randomPointNear(enemy.home, enemy.roam))
		end
		return
	end

	enemy.state = "chase"
	humanoid.WalkSpeed = def.runSpeed
	local distance = flat(targetRoot.Position - position).Magnitude

	-- bosses summon when their health crosses a threshold, whatever comes next
	if def.summonAt and def.pattern and now >= enemy.nextAttack then
		local fraction = humanoid.Health / humanoid.MaxHealth
		for i, at in def.summonAt do
			if fraction <= at and not enemy.summonsDone[i] then
				enemy.summonsDone[i] = true
				for _, a in def.pattern do
					if a.kind == "summon" then
						startAttack(enemy, targetRoot, now, a)
						return
					end
				end
			end
		end
	end

	local attack = enemy.attack
	if def.keepAway and distance < def.keepAway then
		local away = flat(position - targetRoot.Position)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
		humanoid:MoveTo(position + away * 10)
	elseif distance <= attack.range and now >= enemy.nextAttack then
		startAttack(enemy, targetRoot, now, attack)
	elseif distance > math.min(attack.range, 20) * 0.7 then
		humanoid:MoveTo(targetRoot.Position)
	else
		stop(enemy)
		face(enemy, targetRoot.Position)
	end
end

function EnemyService.start()
	task.spawn(function()
		while true do
			task.wait(Config.AI_TICK)
			local now = os.clock()
			for _, enemy in enemies do
				if enemy.humanoid.Health > 0 and enemy.model.Parent then
					local ok, err = pcall(think, enemy, now)
					if not ok then
						warn(`EnemyService: {enemy.def.id} errored: {err}`)
					end
					setState(enemy, enemy.state)
				end
			end
		end
	end)
end

function EnemyService.forget(player: Player)
	for _, enemy in enemies do
		enemy.damagers[player] = nil
		if enemy.target == player then
			enemy.target = nil
		end
	end
end

return EnemyService
