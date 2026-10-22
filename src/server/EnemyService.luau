--!strict
-- Wilds enemies: a simple state machine per enemy, telegraphed attacks and kill
-- rewards. Where and when they appear is Spawner.luau's job; this module only
-- spawns one on request and tells EnemyService.onRemoved when it's gone.
--
-- Enemies have no Humanoid and no body on the server: each is a Model holding
-- one anchored root part (the template's HumanoidRootPart, grown to the body's
-- bounds as its hit volume), tagged "Enemy", moved kinematically by EnemyMover,
-- with its health in Health/MaxHealth attributes. Clients clone the body from
-- ReplicatedStorage.EnemyBodies (a copy of ServerStorage.Enemies made at start)
-- and draw it (EnemyMotion). Each has a home it wanders around (`roam` studs)
-- and leashes back to.
--
-- States: idle (wander near home) -> chase -> windup (telegraph on the ground)
-- -> dash (lunge/charge/leap, and a pack beast's hop) -> recover -> chase.
-- Regular beasts with an attack pool (Enemies `attacks`, `pack`) howl their pack
-- in on first noticing a player, take turns through per-player attack slots
-- (Config.Wilds.ATTACK_SLOTS), circle while they wait and hop back when pressed. Past its leash an enemy
-- returns home and heals. Player hits can knock it back into "stagger" for a
-- moment, depending on realm and weight (Knockback.luau). Every attack that hurts shows its exact area to all
-- clients first (Telegraph remote) and resolves on the server through Combat.hurt,
-- so dodging through it negates the hit.
--
-- Authority split (docs/systems/enemies.md, "Server and client"): the server owns
-- the AI, positions, damage and every hit check; clients only draw. What a client
-- needs to draw goes out as attributes on the model (AIState, StateAt, Attack,
-- DashFrom/DashTo/DashSpeed/DashAt, FadeAt) and the Telegraph remote. Clients
-- predict the visible body from these (EnemyMotion) and play per-beast effects
-- (EnemyFX); the server compensates player swings for lag (EnemyHistory).
-- Idle beasts with no player within Config.Wilds.WAKE_RADIUS sleep: not
-- thinking or moving, nothing to replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config).Wilds
local DEFAULT_ROAM = 15 -- studs an enemy wanders from home unless told otherwise
local Enemies = require(ReplicatedStorage.Shared.Enemies)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local PlayerStun = require(script.Parent.PlayerStun)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Rewards = require(ReplicatedStorage.Shared.Pacing).Rewards
local CombatConfig = require(ReplicatedStorage.Shared.Config).Combat
-- Attack slots and dash-front hits for the new fights; a boss opts into slots
-- with shareTurns so its summoned pack cannot cover its tells with another hit.
local TURNS = Config.NEW_WOLF or Config.NEW_BOAR or Config.NEW_WOLF_KING
-- how long a follow-up (Enemies `followUp`) waits past its recover for the attack slot
local FOLLOW_UP_WAIT = 1.0
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Combat = require(script.Parent.Combat)
local EnemyHistory = require(script.Parent.EnemyHistory)
local EnemyMover = require(script.Parent.EnemyMover)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local remotes = ReplicatedStorage.Remotes
local telegraphRemote = remotes.Telegraph :: RemoteEvent
local effectRemote = remotes.Effect :: RemoteEvent

local wilds = workspace:WaitForChild("Wilds")
local liveFolder = wilds:WaitForChild("Enemies") :: Folder
local templates = ServerStorage:WaitForChild("Enemies") :: Folder

-- clients draw bodies from this copy of the templates (EnemyMotion)
local bodies = templates:Clone()
bodies.Name = "EnemyBodies"
bodies.Parent = ReplicatedStorage

-- Per enemy type, a template stripped to its root, cloned for each spawn.
type Standin = { model: Model, rootHeight: number, radius: number, height: number }
local standins: { [string]: Standin } = {}

local function standinFor(id: string): Standin?
	local cached = standins[id]
	if cached then
		return cached
	end
	local def = Enemies.Defs[id]
	local template = templates:FindFirstChild(def and def.body or id)
	local templateRoot = template and template:FindFirstChild("HumanoidRootPart")
	if not (template and template:IsA("Model") and templateRoot and templateRoot:IsA("BasePart")) then
		return nil
	end
	local extents = template:GetExtentsSize()
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, child in model:GetChildren() do
		if child ~= root then
			child:Destroy()
		end
	end
	root:ClearAllChildren()
	root.Anchored = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, true
	root.Transparency = 1
	root.Size = Vector3.new(math.max(root.Size.X, extents.X), math.max(root.Size.Y, extents.Y), math.max(root.Size.Z, extents.Z))
	model.PrimaryPart = root
	cached = {
		model = model,
		rootHeight = templateRoot.Position.Y,
		radius = math.max(extents.X, extents.Z) / 2,
		height = extents.Y / 2,
	}
	standins[id] = cached
	return cached
end

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
	root: BasePart,
	mover: EnemyMover.Mover,
	health: number,
	maxHealth: number,
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
	damagers: { [Player]: number }, -- damage dealt by each player
	attack: Enemies.Attack, -- the attack in progress, or the next one to use
	patternIndex: number,
	summonsDone: { [number]: boolean }, -- summonAt thresholds already used
	summoned: { Model }, -- live summons (bosses)
	staggerImmuneUntil: number,
	asleep: boolean,
	-- attack pools and packs
	cooldowns: { [string]: number }, -- per attack name: when it may be used again
	lastEngaged: number, -- os.clock() it last had a target (a fresh engagement after Config.ENGAGE_RESET)
	engagedAt: number, -- when this engagement began (attacks' notBefore)
	opened: boolean, -- used its opener (def.attack) this engagement
	slotFor: Player?, -- holds an attack slot on this player
	strikeId: number, -- bumped when an attack resolves or breaks; pending dash hits check it
	recoverFor: number, -- recover seconds after the current dash
	landShape: Shape?, -- a leap's circle, resolved as it lands
	hopPending: boolean,
	followUp: string?, -- an attack to start as soon as it recovers (Enemies `followUp`)
	followUpUntil: number, -- the follow-up lapses if no slot frees up by then
	dashLength: number, -- the current lunge/charge's lane length (Enemies `stopPast`)
	fleeting: boolean, -- SpawnOptions.fleeting
	hopReadyAt: number,
	hits: { number }, -- recent times it was hit (the hop's trigger)
	orbitDir: number,
	orbitSwitchAt: number,
	targetId: number?, -- the Target attribute last sent
}

local enemies: { [Model]: Enemy } = {}

-- Attack slots by player: who holds one and when the next windup may start.
type Slot = { holders: { [Enemy]: boolean }, freeAt: number }
local slots: { [Player]: Slot } = {}

local EnemyService = {}

-- Called with (player, def, model) for each player credited with a kill.
EnemyService.onKill = {} :: { (Player, Enemies.Def, Model) -> () }
-- Called with (model, killed) when an enemy leaves: killed, or despawned.
EnemyService.onRemoved = {} :: { (Model, boolean) -> () }

export type SpawnOptions = {
	home: Vector3?, -- where it wanders and leashes back to (default: where it spawns)
	roam: number?, -- studs it wanders from home
	target: Player?, -- comes straight for this player
	fleeting: boolean?, -- gone (no rewards) once it has no one to fight: a howl's reinforcements
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

-- For walking: also skips anything players can walk through.
local function moveParams(): RaycastParams
	local params = groundParams()
	params.RespectCanCollide = true
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

local function serverNow(): number
	return workspace:GetServerTimeNow()
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

-- Is the player in the area as it lands? Generous to high ping: a player whose
-- own movement (the velocity the server sees, capped at dodge speed) carries them
-- out within half their ping, at most Config.Combat.ESCAPE_LEAD, is spared,
-- because on their screen they had already left.
local function caught(shape: Shape, player: Player, root: BasePart): boolean
	if not EnemyService.inside(shape, root.Position) then
		return false
	end
	local lead = math.min(player:GetNetworkPing() / 2, CombatConfig.ESCAPE_LEAD)
	local velocity = flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude > CombatConfig.DODGE_SPEED then
		velocity = velocity.Unit * CombatConfig.DODGE_SPEED
	end
	return EnemyService.inside(shape, root.Position + velocity * lead)
end

-- Show an area to every client for `seconds`, then hurt every player in it.
-- Returns the players it hit.
function EnemyService.strike(shape: Shape, seconds: number, damage: number, nonLethal: boolean?, only: Player?, source: string?): { Player }
	telegraphRemote:FireAllClients(shape, seconds, nil, source, serverNow())
	task.wait(seconds)
	local hit = {}
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root and (only == nil or only == player) and caught(shape, player, root) then
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
	local template = templates:FindFirstChild(def and def.body or id) :: Model?
	if not (def and template) then
		warn(`EnemyService: no enemy "{id}"`)
		return nil
	end
	local standin = standinFor(id)
	if not standin then
		warn(`EnemyService: enemy "{id}" has no HumanoidRootPart`)
		return nil
	end
	local model = standin.model:Clone()
	-- Rojo's live sync drops Model.PrimaryPart, so find the root by name
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.PrimaryPart = root
	local rootHeight = standin.rootHeight
	-- beast health and damage scale with its realm's Pacing row (beastHealth/beastDamage)
	local health = math.floor(def.health * Realms.ofBeast(def.realm).beastHealth + 0.5)
	local ground = groundAt(at)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, rootHeight, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model:SetAttribute("EnemyType", id)
	model:SetAttribute("Template", def.body or id) -- the template clients draw (EnemyMotion)
	model:SetAttribute("RunSpeed", def.runSpeed)
	model:SetAttribute("Realm", Realms.get(def.realm[1], def.realm[2]).name)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("Health", health)
	model:SetAttribute("AIState", "idle")
	model:SetAttribute("StateAt", serverNow())
	model:AddTag("Enemy")
	model.Parent = liveFolder
	EnemyHistory.track(model, standin.radius, standin.height)

	local enemy: Enemy = {
		model = model,
		def = def,
		root = root,
		mover = EnemyMover.new(root, rootHeight, standin.radius, def.walkSpeed),
		health = health,
		maxHealth = health,
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
		asleep = false,
		cooldowns = {},
		-- sent at a player already (summons): no howl, it joins the fight
		lastEngaged = if opts.target then os.clock() else -math.huge,
		engagedAt = os.clock(),
		opened = false,
		slotFor = nil,
		strikeId = 0,
		recoverFor = def.attack.recover,
		landShape = nil,
		hopPending = false,
		followUp = nil,
		followUpUntil = 0,
		dashLength = 0,
		fleeting = opts.fleeting == true,
		hopReadyAt = 0,
		hits = {},
		orbitDir = if math.random() < 0.5 then 1 else -1,
		orbitSwitchAt = 0,
		targetId = nil,
	}
	enemies[model] = enemy
	return model
end

local function randomPointNear(center: Vector3, radius: number): Vector3
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * radius
	return center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

--[[ Attack slots ]]

local function slotFree(player: Player, now: number): boolean
	local slot = slots[player]
	if not slot then
		return true
	end
	local held = 0
	for holder in slot.holders do
		if enemies[holder.model] == holder and holder.slotFor == player then
			held += 1
		else
			slot.holders[holder] = nil
		end
	end
	return held < Config.ATTACK_SLOTS and now >= slot.freeAt
end

local function takeSlot(enemy: Enemy, player: Player)
	local slot = slots[player]
	if not slot then
		slot = { holders = {}, freeAt = 0 }
		slots[player] = slot
	end
	slot.holders[enemy] = true
	enemy.slotFor = player
end

-- The attack is over (resolved, broken, or the beast is gone): the next beast
-- may wind up on that player after SLOT_GAP.
local function releaseSlot(enemy: Enemy)
	local player = enemy.slotFor
	if not player then
		return
	end
	enemy.slotFor = nil
	local slot = slots[player]
	if slot then
		slot.holders[enemy] = nil
		slot.freeAt = math.max(slot.freeAt, os.clock() + Config.SLOT_GAP)
	end
end

-- Trial bosses own their adds: a finished or abandoned fight must not leave
-- another pack in the arena. Older boss definitions keep their existing rules.
local function dismissSummons(enemy: Enemy)
	if not enemy.def.resetOnEvade then
		return
	end
	for _, model in enemy.summoned do
		EnemyService.despawn(model)
	end
	table.clear(enemy.summoned)
end

-- Clients fade the body (EnemyFX, on FadeAt); the server only holds it still
-- and removes it, so a fade costs no per-part replication.
local function fadeAway(enemy: Enemy)
	enemy.mover.goal, enemy.mover.push = nil, nil
	EnemyHistory.forget(enemy.model)
	enemy.model:SetAttribute("FadeAt", serverNow())
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
	releaseSlot(enemy)
	dismissSummons(enemy)
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
	return math.floor(Realms.enemyQi(def.qiDrop, Realms.get(data.realm.major, data.realm.minor)) * Cultivation.methodSpeed(data) + 0.5)
end

-- Players who dealt enough of the beast's health to earn the kill
-- (Pacing.Rewards KILL_SHARE / BOSS_KILL_SHARE). Whoever dealt the most always
-- qualifies, so a kill is never left without anyone credited.
local function credited(enemy: Enemy): { Player }
	local share = if enemy.def.boss then Rewards.BOSS_KILL_SHARE else Rewards.KILL_SHARE
	local needed = enemy.maxHealth * share
	local top, topDamage = nil, 0
	local list = {}
	for player, damage in enemy.damagers do
		if player.Parent then
			if damage >= needed then
				table.insert(list, player)
			elseif damage > topDamage then
				top, topDamage = player, damage
			end
		end
	end
	if #list == 0 and top then
		table.insert(list, top)
	end
	return list
end

function EnemyService.died(enemy: Enemy)
	if enemies[enemy.model] ~= enemy then
		return
	end
	enemies[enemy.model] = nil
	releaseSlot(enemy)
	dismissSummons(enemy)
	local position = enemy.root.Position
	local winners = credited(enemy)
	for _, player in winners do
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
		for _, player in winners do
			table.insert(names, player.DisplayName)
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
	enemy.mover.goal = nil
	enemy.mover.look = nil
end

local function moveTo(enemy: Enemy, at: Vector3)
	enemy.mover.goal = at
	enemy.mover.look = nil
end

local function setSpeed(enemy: Enemy, speed: number)
	enemy.mover.speed = speed
end

local function setHealth(enemy: Enemy, health: number)
	enemy.health = math.clamp(health, 0, enemy.maxHealth)
	enemy.model:SetAttribute("Health", enemy.health)
end

local function resetAtHome(enemy: Enemy)
	setHealth(enemy, enemy.maxHealth)
	table.clear(enemy.damagers)
	if not enemy.def.resetOnEvade then
		return
	end
	dismissSummons(enemy)
	table.clear(enemy.summonsDone)
	table.clear(enemy.cooldowns)
	enemy.attack = enemy.def.attack
	enemy.patternIndex = 0
	enemy.nextAttack = 0
	enemy.lastEngaged = -math.huge
	enemy.opened = false
	enemy.shape, enemy.dashTo, enemy.landShape = nil, nil, nil
	enemy.hopPending = false
	enemy.followUp = nil
	enemy.strikeId += 1
end

local function setState(enemy: Enemy, state: string)
	enemy.state = state
	-- clients animate from this (crouch on windup, stretch on dash); StateAt
	-- (server time) lets them sync the pose's timing however late it arrives
	if enemy.model:GetAttribute("AIState") ~= state then
		enemy.model:SetAttribute("StateAt", serverNow())
		enemy.model:SetAttribute("AIState", state)
	end
end

-- Shove the enemy `distance` studs along `dir` over Knockback.PUSH_SECONDS,
-- then plant it where it landed, not back where it was told to walk.
local function shove(enemy: Enemy, dir: Vector3, distance: number)
	local mover = enemy.mover
	mover.push = flat(dir) * (distance / Knockback.PUSH_SECONDS)
	mover.pushUntil = os.clock() + Knockback.PUSH_SECONDS
	if enemy.state == "stagger" then
		stop(enemy)
	end
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
	-- a windup broken here never resolves; its telegraph just fades, and a
	-- dash's pending hits or a leap's landing are called off
	enemy.shape, enemy.dashTo, enemy.landShape = nil, nil, nil
	enemy.strikeId += 1
	enemy.hopPending = false
	enemy.followUp = nil
	releaseSlot(enemy)
	setSpeed(enemy, enemy.def.runSpeed)
	enemy.mover.turn = false
	stop(enemy)
	setState(enemy, "stagger")
	enemy.stateUntil = now + Knockback.stun(distance)
	enemy.staggerImmuneUntil = enemy.stateUntil + Knockback.RESTAGGER
end

-- Damage from players (Combat.damageEnemy): take it, remember who to credit,
-- turn on them if idle, then die or take the hit's knockback.
Combat.onEnemyDamaged = function(model: Model, player: Player, amount: number, push: Vector3?)
	local enemy = enemies[model]
	if not enemy or enemy.health <= 0 then
		return
	end
	enemy.damagers[player] = (enemy.damagers[player] or 0) + amount
	setHealth(enemy, enemy.health - amount)
	-- pressed too hard: a pack beast hops back after enough hits in a short window
	local hop = enemy.def.pack and enemy.def.pack.hop
	if hop then
		local now = os.clock()
		table.insert(enemy.hits, now)
		while enemy.hits[1] and now - enemy.hits[1] > hop.window do
			table.remove(enemy.hits, 1)
		end
		if #enemy.hits >= hop.hits then
			enemy.hopPending = true
			table.clear(enemy.hits)
		end
	end
	if enemy.health <= 0 then
		EnemyService.died(enemy)
		return
	end
	if not enemy.target and enemy.state ~= "return" then
		enemy.target = player
	end
	if push then
		knock(enemy, player, push)
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

local function attackName(attack: Enemies.Attack): string
	return attack.name or attack.kind
end

-- Hurt one player with an attack, and show the hit to everyone (EnemyFX `hit`).
local function hurtPlayer(enemy: Enemy, attack: Enemies.Attack, player: Player)
	local result = Combat.hurt(player, attack.damage * Realms.ofBeast(enemy.def.realm).beastDamage, false, enemy.def.id)
	if result == "hit" and player.Character then
		effectRemote:FireAllClients("enemyCue", enemy.model, "hit", player.Character)
	end
end

local function hurtIn(enemy: Enemy, attack: Enemies.Attack, shape: Shape)
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root and caught(shape, player, root) then
			hurtPlayer(enemy, attack, player)
		end
	end
end

-- A lunge or charge: each player in the lane is checked when the dash front
-- reaches them (how far along the lane they stood as it set off), so the blow
-- lands as the beast arrives and a late side-step still saves them. A stagger
-- or the next attack (strikeId) calls the rest off.
local function hurtAlongDash(enemy: Enemy, attack: Enemies.Attack, shape: Shape)
	local id = enemy.strikeId
	local cframe, size = shape.cframe :: CFrame, shape.size :: Vector2
	local speed = attack.dashSpeed :: number
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root then
			local p = cframe:PointToObjectSpace(root.Position)
			-- skip anyone nowhere near the lane
			if math.abs(p.X) <= size.X / 2 + PLAYER_RADIUS + 8 and math.abs(p.Z) <= size.Y / 2 + PLAYER_RADIUS + 8 then
				local along = math.clamp(size.Y / 2 - p.Z, 0, size.Y)
				task.delay(along / speed, function()
					if enemies[enemy.model] ~= enemy or enemy.strikeId ~= id then
						return
					end
					local root = playerRoot(player)
					if root and caught(shape, player, root) then
						hurtPlayer(enemy, attack, player)
					end
				end)
			end
		end
	end
end

-- Send the beast along a line (lunge, charge, leap, hop); clients draw it from
-- these attributes, arcing it up by `arc` studs mid-way (EnemyMotion).
local function startDash(enemy: Enemy, to: Vector3, speed: number, arc: number?)
	local model = enemy.model
	enemy.mover.turn = false
	setSpeed(enemy, speed)
	moveTo(enemy, to)
	model:SetAttribute("DashFrom", enemy.root.Position)
	model:SetAttribute("DashTo", to)
	model:SetAttribute("DashSpeed", speed)
	model:SetAttribute("DashArc", arc or 0)
	model:SetAttribute("DashAt", serverNow())
	enemy.state = "dash"
end

local function startAttack(enemy: Enemy, targetRoot: BasePart, now: number, attack: Enemies.Attack)
	local def = enemy.def
	enemy.attack = attack
	stop(enemy)
	enemy.mover.turn = false
	face(enemy, targetRoot.Position)
	local ground = groundAt(enemy.root.Position)
	local dir = flat(targetRoot.Position - enemy.root.Position)
	dir = if dir.Magnitude > 0.1 then dir.Unit else flat(enemy.root.CFrame.LookVector).Unit

	local shape: Shape
	local seconds = attack.windup
	if attack.kind == "spit" then
		shape = { kind = "circle", center = groundAt(targetRoot.Position), radius = attack.radius }
	elseif attack.kind == "leap" then
		-- the landing circle stays where the target stood; it fills until touchdown
		local center = groundAt(targetRoot.Position)
		shape = { kind = "circle", center = center, radius = attack.radius }
		enemy.dashTo = center
		seconds += attack.active or 0.45
	elseif attack.kind == "slam" then
		local center = ground
		if attack.offset then
			local facing = CFrame.lookAt(ground, ground + dir)
			center = groundAt(facing:PointToWorldSpace(attack.offset))
		end
		shape = { kind = "circle", center = center, radius = attack.radius }
	elseif attack.kind == "cone" then
		shape = {
			kind = "cone",
			center = ground,
			cframe = CFrame.lookAt(ground, ground + dir),
			radius = attack.radius,
			size = Vector2.new(attack.angle :: number, 0),
		}
	elseif attack.kind == "summon" or attack.kind == "howl" then
		shape = { kind = "howl", center = ground, radius = 8 }
	else
		local length = attack.length :: number
		if attack.stopPast then
			-- stop just past the target, not the full lane
			local reach = flat(targetRoot.Position - enemy.root.Position).Magnitude + attack.stopPast
			length = math.clamp(reach, attack.minRange or 0, length)
		end
		enemy.dashLength = length
		enemy.model:SetAttribute("DashSeconds", length / (attack.dashSpeed or 1))
		shape = {
			kind = "box",
			cframe = CFrame.lookAt(ground, ground + dir) * CFrame.new(0, 0, -length / 2),
			size = Vector2.new(attack.width :: number, length),
		}
		enemy.dashTo = enemy.root.Position + dir * length
	end
	enemy.shape = shape
	enemy.stateUntil = now + attack.windup
	local name = attackName(attack)
	local stun = attack.stun
	if stun then
		-- the exact area the roar will catch, drawn like any damaging telegraph
		telegraphRemote:FireAllClients({ kind = "circle", center = ground, radius = stun.radius }, seconds, enemy.model, name, serverNow())
	end
	if def.attacks then
		-- a pool: each attack keeps its own cooldown, and the beast waits out the
		-- whole move (and a breath) before choosing again
		enemy.cooldowns[name] = now + attack.cooldown
		local busy = if attack.kind == "leap" then attack.active or 0.45
			elseif attack.dashSpeed then enemy.dashLength / attack.dashSpeed
			else 0
		enemy.nextAttack = now + attack.windup + busy + attack.recover + 0.4
		if attack.kind ~= "howl" then
			enemy.opened = true
		end
	else
		enemy.nextAttack = now + attack.cooldown
	end
	if TURNS and (not def.boss or def.shareTurns) and attack.damage > 0 and enemy.target then
		takeSlot(enemy, enemy.target)
	end
	-- which attack, for per-attack poses and effects (EnemyAnimator, EnemyFX)
	enemy.model:SetAttribute("Attack", name)
	setState(enemy, "windup")
	telegraphRemote:FireAllClients(shape, seconds, enemy.model, name, serverNow())
end

-- A spot 18-25 studs from `center` on ground a beast can stand on (a downward ray
-- hits within 8 studs of the center's ground height), or nil after a few tries.
local function reinforcePoint(center: Vector3): Vector3?
	local base = groundAt(center)
	for _ = 1, 8 do
		local a = math.random() * math.pi * 2
		local r = 18 + math.random() * 7
		local probe = base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local hit = workspace:Raycast(probe + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), groundParams())
		if hit and math.abs(hit.Position.Y - base.Y) <= 8 then
			return hit.Position
		end
	end
	return nil
end

-- Spawn `count` (default attack.count) of attack.summons, sent straight at the
-- summoner's target, so they join the fight without howling again (a target at
-- spawn counts as already engaged). Beside the summoner, or with `around` 18-25
-- studs from that point (a howl's reinforcements, fleeting). Each waits a moment
-- before its first attack, and attack slots still apply.
local function summon(enemy: Enemy, attack: Enemies.Attack, count: number?, around: Vector3?)
	for i = #enemy.summoned, 1, -1 do
		local m = enemy.summoned[i]
		if not Hitbox.alive(m) then
			table.remove(enemy.summoned, i)
		end
	end
	local room = (attack.maxAlive or 4) - #enemy.summoned
	local now = os.clock()
	for _ = 1, math.min(count or attack.count or 1, room) do
		local at: Vector3?
		if around then
			at = reinforcePoint(around)
		else
			local a = math.random() * math.pi * 2
			at = enemy.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 8
		end
		if not at then
			continue
		end
		local model = EnemyService.spawn(
			attack.summons :: string,
			at :: Vector3,
			{ home = enemy.home, roam = enemy.roam, target = enemy.target,
				fleeting = around ~= nil or enemy.def.resetOnEvade == true }
		)
		if model then
			table.insert(enemy.summoned, model)
			local spawned = enemies[model]
			if spawned then
				spawned.nextAttack = now + 1 + math.random() * 1.5
			end
		end
	end
end

-- A howl: packmates of the same kind within its radius who aren't fighting
-- turn on the howler's target, staggered so they don't all strike at once.
local function callPack(enemy: Enemy, attack: Enemies.Attack, now: number): number
	local radius = attack.radius or 30
	local position = enemy.root.Position
	local rallied = 0
	for _, other in enemies do
		if
			other ~= enemy
			and other.def.id == enemy.def.id
			and other.health > 0
			and not other.target
			and (other.root.Position - position).Magnitude <= radius
		then
			other.target = enemy.target
			other.lastEngaged, other.engagedAt, other.opened = now, now, false
			other.nextAttack = math.max(other.nextAttack, now + 0.6 + math.random() * 0.8)
			other.asleep = false
			rallied += 1
		end
	end
	return rallied
end

-- Whether a player is still in onboarding (the QC3 beat, the last before free
-- play, not yet passed; Quests.Beats).
local function onboarding(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and not (data.beats :: any).QC3
end

-- A howl that rallied nobody calls reinforcements (Enemies `summons`, between
-- `count` and `countMax`) from 18-25 studs around its target. While the target is
-- in onboarding: only one, and only if no other beast of its kind is within the
-- howl's radius.
local function reinforce(enemy: Enemy, attack: Enemies.Attack)
	local player = enemy.target
	local root = player and playerRoot(player)
	if not (player and root and attack.summons) then
		return
	end
	local count = math.random(attack.count or 1, attack.countMax or attack.count or 1)
	if onboarding(player) then
		local radius = attack.radius or 30
		for _, other in enemies do
			if
				other ~= enemy
				and other.def.id == enemy.def.id
				and other.health > 0
				and (other.root.Position - enemy.root.Position).Magnitude <= radius
			then
				return
			end
		end
		count = 1
	end
	summon(enemy, attack, count, root.Position)
end

-- Bosses go through their pattern in order; threshold-only calls interrupt it.
local function advancePattern(enemy: Enemy)
	local pattern = enemy.def.pattern
	if pattern then
		if enemy.attack.thresholdOnly then
			-- A phase call interrupts the upcoming move; it does not consume it.
			enemy.attack = if enemy.patternIndex == 0 then enemy.def.attack else pattern[enemy.patternIndex]
			return
		end
		for _ = 1, #pattern do
			enemy.patternIndex = enemy.patternIndex % #pattern + 1
			enemy.attack = pattern[enemy.patternIndex]
			if not enemy.attack.thresholdOnly then
				return
			end
		end
	end
end

local function resolveAttack(enemy: Enemy, now: number)
	local attack = enemy.attack
	local shape = enemy.shape :: Shape
	enemy.shape = nil
	enemy.strikeId += 1
	enemy.recoverFor = attack.recover
	if attack.kind == "summon" then
		summon(enemy, attack)
	elseif attack.kind == "howl" then
		if callPack(enemy, attack, now) == 0 and attack.summons then
			reinforce(enemy, attack)
		end
	elseif attack.kind == "leap" then
		enemy.landShape = shape -- resolves as it lands (think, dash)
	elseif enemy.dashTo and TURNS then
		hurtAlongDash(enemy, attack, shape)
	else
		hurtIn(enemy, attack, shape)
	end
	local stun = attack.stun
	if stun then
		-- a roar: staggers or stuns every player standing in its circle
		local area: Shape = { kind = "circle", center = groundAt(enemy.root.Position), radius = stun.radius }
		for _, player in Players:GetPlayers() do
			local root = playerRoot(player)
			if root and caught(area, player, root) then
				PlayerStun.apply(player, stun.kind :: any, stun.seconds, enemy.model)
			end
		end
	end
	if attack.hopAfter then
		enemy.hopPending = true
	end
	enemy.followUp = attack.followUp
	if attack.followUp then
		-- through the dash and recover, plus a short wait for the attack slot
		local dash = if attack.dashSpeed then enemy.dashLength / attack.dashSpeed else 0
		enemy.followUpUntil = now + dash + attack.recover + FOLLOW_UP_WAIT
	end
	if enemy.dashTo then
		local to = enemy.dashTo :: Vector3
		if attack.kind == "leap" then
			local flight = attack.active or 0.45
			startDash(enemy, to, math.max(flat(to - enemy.root.Position).Magnitude / flight, 1), attack.arc)
			enemy.stateUntil = now + flight
		else
			-- the dash's line, so clients draw it where it is on the server, not a
			-- ping behind (EnemyMotion)
			startDash(enemy, to, attack.dashSpeed :: number)
			enemy.stateUntil = now + enemy.dashLength / (attack.dashSpeed :: number) + 0.1
		end
		enemy.dashTo = nil
	else
		releaseSlot(enemy)
		enemy.state = "recover"
		enemy.stateUntil = now + attack.recover
	end
	advancePattern(enemy)
end

-- Hop back from the target (no damage), then circle again.
local function hop(enemy: Enemy, targetRoot: BasePart, now: number)
	local h = (enemy.def.pack :: Enemies.Pack).hop :: any
	enemy.hopPending = false
	enemy.hopReadyAt = now + h.cooldown
	local position = enemy.root.Position
	local away = flat(position - targetRoot.Position)
	away = if away.Magnitude > 0.1 then away.Unit else -flat(enemy.root.CFrame.LookVector).Unit
	face(enemy, targetRoot.Position)
	enemy.model:SetAttribute("Attack", "hop")
	startDash(enemy, position + away * h.distance, h.distance / h.seconds, h.arc)
	enemy.recoverFor = 0.1
	enemy.stateUntil = now + h.seconds + 0.05
	effectRemote:FireAllClients("enemyCue", enemy.model, "strike")
end

-- Whether to circle now: always, or with `waitFor` only while that attack is ready
-- or nearly so (otherwise it closes in).
local function circling(enemy: Enemy, circle: { radius: number, speed: number, waitFor: string? }, now: number): boolean
	local waitFor = circle.waitFor
	return waitFor == nil or now >= (enemy.cooldowns[waitFor] or 0) - 1
end

-- Circle the target at the pack's radius, facing it, switching direction now
-- and then.
local function orbit(enemy: Enemy, targetRoot: BasePart, circle: { radius: number, speed: number }, now: number)
	if now >= enemy.orbitSwitchAt then
		if enemy.orbitSwitchAt > 0 then
			enemy.orbitDir = -enemy.orbitDir
		end
		enemy.orbitSwitchAt = now + 2 + math.random() * 2
	end
	local center = targetRoot.Position
	local away = flat(enemy.root.Position - center)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	local step = enemy.orbitDir * circle.speed * 0.4 / circle.radius
	local dir = CFrame.Angles(0, step, 0):VectorToWorldSpace(away)
	setSpeed(enemy, circle.speed)
	enemy.mover.goal = center + dir * circle.radius
	enemy.mover.look = center
end

-- The attack to start now, if any: the opener first in a fresh engagement, then
-- the first in the pool whose range band holds the target and whose cooldown is up.
local function pickAttack(enemy: Enemy, distance: number, now: number): Enemies.Attack?
	local slotOk = not (TURNS and (not enemy.def.boss or enemy.def.shareTurns)
		and enemy.target and not slotFree(enemy.target, now))
	-- a follow-up (the boar's gore after its charge) goes as soon as it recovers,
	-- past the usual pause and its own cooldown, if the target is still in reach.
	-- It waits for the attack slot (briefly), and lapses once the target is out of
	-- reach or the wait runs out.
	local followUp = enemy.followUp
	if followUp then
		local chosen: Enemies.Attack? = nil
		for _, a in enemy.def.attacks or {} do
			if attackName(a) == followUp then
				chosen = a
			end
		end
		if not chosen or distance > chosen.range or now > enemy.followUpUntil then
			enemy.followUp = nil
		elseif slotOk then
			enemy.followUp = nil
			return chosen
		else
			return nil
		end
	end
	if now < enemy.nextAttack or not slotOk then
		return nil
	end
	local function fits(a: Enemies.Attack): boolean
		return distance <= a.range
			and distance >= (a.minRange or 0)
			and now >= (enemy.cooldowns[attackName(a)] or 0)
			and (a.notBefore == nil or now - enemy.engagedAt >= a.notBefore)
	end
	local pool = enemy.def.attacks
	if not pool then
		return if distance <= enemy.attack.range then enemy.attack else nil
	end
	if not enemy.opened then
		local opener = enemy.def.attack
		if fits(opener) then
			return opener
		end
		-- too close for the opener: a closeOpener beast (the boar) uses its pool
		local pack = enemy.def.pack
		if not (pack and pack.closeOpener and distance < (opener.minRange or 0)) then
			return nil
		end
	end
	for _, a in pool do
		if fits(a) then
			return a
		end
	end
	return nil
end

local function think(enemy: Enemy, now: number)
	local def = enemy.def
	local position = enemy.root.Position

	if enemy.state == "windup" then
		if now >= enemy.stateUntil then
			resolveAttack(enemy, now)
		end
		return
	elseif enemy.state == "dash" then
		if now >= enemy.stateUntil then
			stop(enemy)
			setSpeed(enemy, def.runSpeed)
			-- a leap lands now
			local landing = enemy.landShape
			if landing then
				enemy.landShape = nil
				hurtIn(enemy, enemy.attack, landing)
			end
			releaseSlot(enemy)
			enemy.state = "recover"
			enemy.stateUntil = now + enemy.recoverFor
		end
		return
	elseif enemy.state == "recover" or enemy.state == "stagger" then
		if now < enemy.stateUntil then
			return
		end
		enemy.mover.turn = true
		enemy.state = "chase"
	elseif enemy.state == "return" then
		if flat(position - home(enemy)).Magnitude < 8 then
			resetAtHome(enemy)
			enemy.state = "idle"
		else
			moveTo(enemy, home(enemy))
		end
		return
	end

	if enemy.fleeting and flat(position - home(enemy)).Magnitude > def.leash then
		EnemyService.despawn(enemy.model)
		return
	end
	if flat(position - home(enemy)).Magnitude > def.leash then
		enemy.target = nil
		releaseSlot(enemy)
		dismissSummons(enemy)
		enemy.state = "return"
		setSpeed(enemy, def.runSpeed)
		moveTo(enemy, home(enemy))
		return
	end

	local target, targetRoot = pickTarget(enemy)
	enemy.target = target
	if not (target and targetRoot) then
		if enemy.fleeting then
			-- a howl's reinforcement with no one left to fight goes back where it came from
			EnemyService.despawn(enemy.model)
			return
		end
		if def.resetOnEvade and enemy.lastEngaged > -math.huge then
			-- A player death/disengage resets this encounter instead of leaving a
			-- wounded boss and its pack waiting beside the respawn pad.
			releaseSlot(enemy)
			dismissSummons(enemy)
			enemy.state = "return"
			setSpeed(enemy, def.runSpeed)
			moveTo(enemy, home(enemy))
			return
		end
		enemy.state = "idle"
		enemy.mover.look = nil
		setSpeed(enemy, def.walkSpeed)
		if now >= enemy.nextWander then
			enemy.nextWander = now + 4 + math.random() * 4
			moveTo(enemy, randomPointNear(enemy.home, enemy.roam))
		end
		return
	end

	-- a fresh engagement: the opener comes first, and a pack beast howls its pack in
	local pack = def.pack
	if now - enemy.lastEngaged > Config.ENGAGE_RESET then
		enemy.engagedAt, enemy.opened = now, false
		enemy.lastEngaged = now
		if pack and pack.howl then
			startAttack(enemy, targetRoot, now, pack.howl)
			return
		end
	end
	enemy.lastEngaged = now

	enemy.state = "chase"
	setSpeed(enemy, def.runSpeed)
	local distance = flat(targetRoot.Position - position).Magnitude

	-- bosses summon when their health crosses a threshold, whatever comes next
	if def.summonAt and def.pattern and now >= enemy.nextAttack then
		local fraction = enemy.health / enemy.maxHealth
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

	local choice = pickAttack(enemy, distance, now)
	if def.keepAway and distance < def.keepAway then
		local away = flat(position - targetRoot.Position)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
		moveTo(enemy, position + away * 10)
	elseif choice then
		startAttack(enemy, targetRoot, now, choice)
	elseif pack and pack.hop and enemy.hopPending and now >= enemy.hopReadyAt then
		hop(enemy, targetRoot, now)
	elseif pack and pack.circle and distance <= pack.circle.radius + 6 and circling(enemy, pack.circle, now) then
		orbit(enemy, targetRoot, pack.circle, now)
	elseif pack and pack.circle and pack.circle.waitFor and distance <= 4 then
		-- closed in and waiting on the gore: hold, facing the target
		stop(enemy)
		face(enemy, targetRoot.Position)
	elseif def.attacks or distance > math.min(enemy.attack.range, 20) * 0.7 then
		moveTo(enemy, targetRoot.Position)
	else
		stop(enemy)
		face(enemy, targetRoot.Position)
	end
end


-- No player near and nothing to do: stop thinking and moving, so the beast
-- costs nothing. One walking home is put there and healed first (nobody is near
-- enough to see it jump).
local function sleep(enemy: Enemy)
	if enemy.fleeting then
		-- a howl's reinforcement nobody is near: just gone
		EnemyService.despawn(enemy.model)
		return
	end
	if enemy.state == "return" then
		local ground = groundAt(enemy.home)
		enemy.model:PivotTo(CFrame.new(ground + Vector3.new(0, enemy.rootHeight, 0)) * enemy.root.CFrame.Rotation)
		resetAtHome(enemy)
	end
	stop(enemy)
	setSpeed(enemy, enemy.def.walkSpeed)
	enemy.asleep = true
	setState(enemy, "idle")
end

local function wake(enemy: Enemy, now: number)
	enemy.asleep = false
	enemy.nextWander = now + math.random() * 3
end

local function thinkAll()
	local now = os.clock()
	local awake: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root then
			table.insert(awake, root.Position)
		end
	end
	for _, enemy in enemies do
		if enemy.health > 0 and enemy.model.Parent then
			local position = enemy.root.Position
			local near = false
			for _, at in awake do
				if (at - position).Magnitude <= Config.WAKE_RADIUS then
					near = true
					break
				end
			end
			if not near and not enemy.target and (enemy.state == "idle" or enemy.state == "return") then
				if not enemy.asleep then
					sleep(enemy)
				end
				continue
			elseif enemy.asleep then
				wake(enemy, now)
			end
			local ok, err = pcall(think, enemy, now)
			if not ok then
				warn(`EnemyService: {enemy.def.id} errored: {err}`)
			end
			setState(enemy, enemy.state)
			-- who it's after, so clients can turn its head and aim effects
			local targetId = enemy.target and enemy.target.UserId
			if targetId ~= enemy.targetId then
				enemy.targetId = targetId
				enemy.model:SetAttribute("Target", targetId)
			end
		end
	end
end

-- Overlapping awake beasts drift apart (no physics bodies to bump them), except
-- mid-dash.
local function crowd(list: { Enemy })
	for _, enemy in list do
		enemy.mover.nudge = Vector3.zero
	end
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			local offset = flat(a.root.Position - b.root.Position)
			local reach = (a.mover.radius + b.mover.radius) * 0.7
			local distance = offset.Magnitude
			if distance < reach then
				local dir = if distance > 0.05 then offset.Unit else Vector3.xAxis
				local push = dir * Config.CROWD * (1 - distance / reach)
				if a.state ~= "dash" and not (a.def.shareTurns and (a.state == "windup" or a.state == "recover")) then
					a.mover.nudge += push
				end
				if b.state ~= "dash" and not (b.def.shareTurns and (b.state == "windup" or b.state == "recover")) then
					b.mover.nudge -= push
				end
			end
		end
	end
end

local function moveAll(dt: number)
	local now = os.clock()
	local stamp = serverNow()
	local list: { Enemy } = {}
	for _, enemy in enemies do
		if not enemy.asleep and enemy.health > 0 and enemy.model.Parent then
			table.insert(list, enemy)
		end
	end
	if #list == 0 then
		return
	end
	crowd(list)
	local params = moveParams()
	for _, enemy in list do
		if EnemyMover.moving(enemy.mover, now) then
			local ok, err = pcall(EnemyMover.step, enemy.mover, dt, now, params)
			if not ok then
				warn(`EnemyService: {enemy.def.id} failed to move: {err}`)
			end
		end
		EnemyHistory.record(enemy.model, enemy.root.Position, stamp)
	end
end

function EnemyService.start()
	task.spawn(function()
		while true do
			task.wait(Config.AI_TICK)
			thinkAll()
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.MOVE_TICK)
			local now = os.clock()
			moveAll(math.min(now - last, Config.MOVE_TICK * 3))
			last = now
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
