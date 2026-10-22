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
local Projectiles = require(script.Parent.Projectiles)
local PlayerPoison = require(script.Parent.PlayerPoison)
local PlayerSlow = require(script.Parent.PlayerSlow)
local BossAttacks = require(script.Parent.BossAttacks)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Rewards = require(ReplicatedStorage.Shared.Pacing).Rewards
local CombatConfig = require(ReplicatedStorage.Shared.Config).Combat
local CC = CombatConfig.CC
-- Attack slots and dash-front hits for the new fights; a boss opts into slots
-- with shareTurns so its summoned pack cannot cover its tells with another hit.
local TURNS = Config.NEW_WOLF or Config.NEW_BOAR or Config.NEW_WOLF_KING or Config.NEW_THUNDER_APE or Config.NEW_NINE_TAIL_FOX or Config.NEW_JIAO
	or Config.NEW_SERPENT or Config.NEW_TORTOISE or Config.NEW_SHADOW_MANE
	or Config.NEW_TOAD or Config.NEW_CENTIPEDE or Config.NEW_RAVEN or Config.NEW_BAT or Config.NEW_SPIDER
-- how long a follow-up (Enemies `followUp`) waits past its recover for the attack slot
local FOLLOW_UP_WAIT = 1.0
-- Turning into moves and arriving with weight (Config.Wilds.WEIGHTED_MOVES; telegraphs.md
-- "Attacks that make sense"): a leap, bound, charge or lunge turns toward where it goes
-- over WINDUP_TURN of its windup, a leap or bound finishes its yaw by AIR_TURN of the
-- flight, an `arrive` follow-up turns into its blow over ARRIVE_TURN of its windup, and
-- may start only with the target within ARRIVE_ANGLE of the facing. A beast with `skid`
-- and no follow-up skids round when the target ends up more than SKID_ANGLE off its nose.
local WEIGHTED = Config.WEIGHTED_MOVES
local WINDUP_TURN, AIR_TURN, ARRIVE_TURN = 0.6, 0.8, 0.7
local ARRIVE_ANGLE, SKID_ANGLE = 100, 60
-- a skid slides on along a charge or lunge by SKID_SLIDE s of its dash speed (1-5 studs)
-- over SKID_SLIDE_SECONDS, and turns to the target over SKID_TURN of its recover (at most 0.9 s)
local SKID_SLIDE, SKID_SLIDE_SECONDS, SKID_TURN = 0.06, 0.3, 0.75
-- bound landing modes (Enemies `boundModes`): never the same twice in a row
local BOUND_MODES = { "over", "flank", "back", "short" }
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Combat = require(script.Parent.Combat)
local Guard = require(script.Parent.Guard)
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
	parts: { any }?, -- barrage/retreat: timed sub-areas (see buildParts), drawn by Telegraphs
	pattern: string?, -- barrage: the pattern name
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
	landAttack: Enemies.Attack?, -- the leap that owns landShape (enemy.attack has moved on by then)
	landFrom: Vector3?, -- where that leap took off (the guard judges the landing from there)
	assault: { number }, -- os.clock() times the current attack's later blows are due (Guard's chain parry)
	phase: number, -- rotating bosses: 1, then 2 and 3 as phase roars resolve
	runBoost: number, -- run speed multiplier from phases
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
	dashAttack: Enemies.Attack?, -- the attack whose dash, leap or bound is under way (its `arrive` and `skid`)
	resume: Enemies.Attack?, -- pattern bosses: the queued attack an `arrive` follow-up cut in front of
	dashFlight: number?, -- a bound's flight seconds and arc for its landing mode
	dashArc: number?,
	boundMode: string?, -- the last bound's landing mode (BoundMode attribute)
	preferNext: { string }?, -- after a `rangedNext` attack: only these, until preferUntil
	preferUntil: number,
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
	if def.phaseCall then
		model:SetAttribute("Phase", 1)
	end
	if def.startsBurrowed then
		model:SetAttribute("Burrowed", true)
	end
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
		landAttack = nil,
		assault = {},
		phase = 1,
		runBoost = 1,
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
		dashAttack = nil,
		resume = nil,
		dashFlight = nil,
		dashArc = nil,
		boundMode = nil,
		preferNext = nil,
		preferUntil = 0,
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
	BossAttacks.died(enemy)
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
		enemy.mover.yaw = nil
		enemy.root.CFrame = CFrame.lookAt(p, look)
	end
end

-- Turn toward `toward` over `seconds` (EnemyMover.turnTo), or snap like `face` without
-- WEIGHTED_MOVES.
local function turnToward(enemy: Enemy, toward: Vector3, seconds: number)
	if not WEIGHTED then
		face(enemy, toward)
		return
	end
	EnemyMover.turnTo(enemy.mover, flat(toward - enemy.root.Position), seconds, os.clock())
end

-- Which attack this is, for per-attack poses and effects (EnemyAnimator, EnemyFX).
-- AttackName follows Attack, except in a skid, where it says `<attack>Skid`.
local function setAttack(enemy: Enemy, name: string)
	enemy.model:SetAttribute("Attack", name)
	enemy.model:SetAttribute("AttackName", name)
end

-- An attack broken before it resolved (stagger, parry): a pattern boss goes back to
-- the attack an `arrive` follow-up had cut in front of.
local function dropArrive(enemy: Enemy)
	enemy.dashAttack = nil
	enemy.mover.yaw = nil
	if enemy.resume then
		enemy.attack = enemy.resume
		enemy.resume = nil
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
	-- phases speed up the chase, not dashes (those pass their own speed)
	enemy.mover.speed = if speed == enemy.def.runSpeed then speed * enemy.runBoost else speed
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
	enemy.phase, enemy.runBoost = 1, 1
	if enemy.def.phaseCall then
		enemy.model:SetAttribute("Phase", 1)
	end
	BossAttacks.reset(enemy)
	enemy.nextAttack = 0
	enemy.lastEngaged = -math.huge
	enemy.opened = false
	enemy.shape, enemy.dashTo, enemy.landShape = nil, nil, nil
	enemy.hopPending = false
	enemy.followUp = nil
	enemy.dashAttack, enemy.resume, enemy.preferNext = nil, nil, nil
	enemy.boundMode = nil
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
	dropArrive(enemy)
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
	BossAttacks.damaged(enemy, amount, os.clock())
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

-- The reaction a landed hit causes: the attack's `react`, else a stagger from a
-- heavy blow (Config.Combat.CC.HEAVY_KINDS) by a heavy beast, else the flinch
-- Combat.hurt already gave.
function EnemyService.reaction(def: Enemies.Def, attack: Enemies.Attack): string
	if attack.react then
		return attack.react
	end
	return if CC.HEAVY_KINDS[attack.kind] and def.weight >= CC.STAGGER_WEIGHT then "stagger" else "flinch"
end

-- Studs a landed hit shoves the player away from the beast (Config.Combat.CC.KNOCK_*).
function EnemyService.knockback(def: Enemies.Def, attack: Enemies.Attack, react: string): number
	if attack.knock then
		return attack.knock
	end
	local base = def.knock or (CC.KNOCK_BASE + CC.KNOCK_PER_WEIGHT * def.weight)
	return math.min(base * (CC.KNOCK_BY_REACT[react] or 1), CC.KNOCK_MAX)
end

-- What every landed hit does on top of the damage: the reaction (a stun from
-- `stun.onHit`/`hitStun` wins over `react`) and the shove, which the hit
-- player's own client plays (CrowdControl, Effect "knock").
local function reactTo(enemy: Enemy, attack: Enemies.Attack, player: Player, stun: { kind: string, seconds: number? }?, shove: boolean)
	local kind, seconds = EnemyService.reaction(enemy.def, attack), attack.reactSeconds
	if stun then
		kind, seconds = stun.kind, stun.seconds
	end
	if kind ~= "flinch" then
		PlayerStun.apply(player, kind :: any, seconds, enemy.model)
	end
	local studs = if shove then EnemyService.knockback(enemy.def, attack, kind) else 0
	if studs > 0 then
		effectRemote:FireClient(player, "knock", enemy.root.Position, studs)
	end
end

-- A perfect parry (Guard): the beast is thrown off balance, whatever it was
-- doing. Bosses recover sooner. `chain`: how many blows the player parried in
-- a row; a chain's closing stagger runs longer (CHAIN_STAGGER_BONUS).
local function parried(enemy: Enemy, chain: number?)
	if enemies[enemy.model] ~= enemy or enemy.health <= 0 or enemy.state == "return" then
		return
	end
	local Guarding = CombatConfig.GUARD
	local bonus = math.min(Guarding.CHAIN_STAGGER_BONUS * math.max((chain or 1) - 1, 0), Guarding.CHAIN_STAGGER_MAX)
	enemy.assault = {}
	enemy.shape, enemy.dashTo, enemy.landShape = nil, nil, nil
	enemy.strikeId += 1
	enemy.hopPending = false
	enemy.followUp = nil
	dropArrive(enemy)
	releaseSlot(enemy)
	setSpeed(enemy, enemy.def.runSpeed)
	enemy.mover.turn = false
	stop(enemy)
	setState(enemy, "stagger")
	enemy.stateUntil = os.clock() + (if enemy.def.boss then Guarding.PARRY_STAGGER_BOSS else Guarding.PARRY_STAGGER) + bonus
	enemy.staggerImmuneUntil = enemy.stateUntil + Knockback.RESTAGGER
end

-- An attack in a pool or pattern, by name.
local function findAttack(enemy: Enemy, name: string): Enemies.Attack?
	for _, a in enemy.def.attacks or enemy.def.pattern or {} do
		if attackName(a) == name then
			return a
		end
	end
	return nil
end

-- When the blows of the attack resolving now are due (os.clock()), for Guard's
-- chain parry: barrage and retreat parts, cone `strikes`, a slam's wave and a
-- `followUp` (after the dash or flight, the recover and its windup).
local function planAssault(enemy: Enemy, attack: Enemies.Attack, shape: Shape, now: number)
	local due: { number } = {}
	if attack.kind == "barrage" or attack.kind == "retreat" then
		for _, part in shape.parts or {} do
			table.insert(due, now + (part.delay or 0))
		end
	end
	for _, strike in attack.strikes or {} do
		table.insert(due, now + strike.at)
	end
	if attack.wave and enemy.phase >= attack.wave.phase then
		table.insert(due, now + attack.wave.delay)
	end
	local follow = attack.followUp and findAttack(enemy, attack.followUp)
	if follow then
		local travel = if attack.kind == "leap" then attack.active or 0.45
			elseif attack.dashSpeed then (enemy.dashLength or 0) / attack.dashSpeed
			else 0
		local strikeAt = follow.windup + (if follow.kind == "leap" then follow.active or 0.45 else 0)
		table.insert(due, now + travel + attack.recover + strikeAt)
	end
	enemy.assault = due
end

-- Seconds until this beast's next blow of the current assault, or nil when
-- the blow landing now is its last.
local function nextBlowIn(enemy: Enemy): number?
	local now = os.clock()
	local best: number? = nil
	for _, t in enemy.assault do
		if t > now + 0.05 and (best == nil or t < best) then
			best = t
		end
	end
	return if best then best - now else nil
end

-- Where a blow comes from (Guard.Hit), taken as it lands: `origin` when that
-- isn't where the beast stands now (a dash's start, a leap's take-off, a
-- projectile's launch point), else the beast. `dash` widens the front arc: the
-- beast arrives on top of you, so its position would read as beside or behind.
local function guardHit(enemy: Enemy, attack: Enemies.Attack, origin: Vector3?, dash: boolean?): Guard.Hit
	return {
		from = origin or enemy.root.Position,
		heavy = CC.HEAVY_KINDS[attack.kind] == true,
		dot = if dash then CombatConfig.GUARD.DASH_DOT else nil,
		at = workspace:GetServerTimeNow(),
		attacker = enemy.model,
		nextIn = nextBlowIn(enemy),
	}
end

-- Run a blow's effect on `player`: now, or after Guard.lead when their guard
-- is down, so a raise already in flight still guards it (judged at `hit.at`).
local function landOn(player: Player, resolve: () -> ())
	local lead = Guard.lead(player)
	if lead > 0 then
		task.delay(lead, resolve)
	else
		resolve()
	end
end

-- Combat.hurt for an enemy's attack, guardable as `hit` says. A parry that
-- closes a chain (or stands alone) staggers the beast; "deflected" (a chained
-- parry with more blows coming) lets the assault run on.
local function hurtBy(enemy: Enemy, player: Player, damage: number, hit: Guard.Hit)
	local result = Combat.hurt(player, damage, false, enemy.def.id, hit)
	if result == "parried" then
		parried(enemy, hit.chain)
	end
	return result
end

-- A chain whose next blow never came (the beast stopped, or its blows missed):
-- the flurry is over and the beast reels all the same.
Guard.onChainEnd = function(attacker: Instance, chain: number)
	local enemy = enemies[attacker :: Model]
	if enemy then
		parried(enemy, chain)
	end
end

-- Hurt one player with an attack, and show the hit to everyone (EnemyFX `hit`).
-- `origin`/`dash`: where the blow comes from, for the guard (guardHit).
local function hurtPlayer(enemy: Enemy, attack: Enemies.Attack, player: Player, origin: Vector3?, dash: boolean?)
	local hit = guardHit(enemy, attack, origin, dash)
	landOn(player, function()
		local result = hurtBy(enemy, player, attack.damage * Realms.ofBeast(enemy.def.realm).beastDamage, hit)
		if result == "hit" and player.Character then
			effectRemote:FireAllClients("enemyCue", enemy.model, "hit", player.Character)
			local stun = attack.stun
			reactTo(enemy, attack, player, if stun and stun.onHit then stun else nil, true)
			local poison = attack.poison
			if poison then
				PlayerPoison.apply(player, poison.stacks, poison.seconds, enemy.def.id)
			end
			local slow = attack.slow
			if slow then
				PlayerSlow.apply(player, slow.factor, slow.seconds)
				effectRemote:FireAllClients("enemyCue", enemy.model, "slow", player.Character)
			end
			local leech = attack.leech
			if leech and enemy.health > 0 then
				-- the bat drinks: it heals a share of what it dealt, up to its maximum
				local dealt = attack.damage * Realms.ofBeast(enemy.def.realm).beastDamage
				setHealth(enemy, enemy.health + dealt * leech)
				effectRemote:FireAllClients("enemyCue", enemy.model, "leech", player.Character)
			end
		end
	end)
end

local function hurtIn(enemy: Enemy, attack: Enemies.Attack, shape: Shape, origin: Vector3?, dash: boolean?)
	for _, player in Players:GetPlayers() do
		local root = playerRoot(player)
		if root and caught(shape, player, root) then
			hurtPlayer(enemy, attack, player, origin, dash)
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
	-- the guard judges the blow from where the dash set off: by the time it
	-- lands the beast is on top of (or past) the player
	local origin = enemy.root.Position
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
						hurtPlayer(enemy, attack, player, origin, true)
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

local Projectiles = require(script.Parent.Projectiles)
-- foxfireVolley bolts: speed studs/s, hit radius, range from the start point, how far ahead of
-- the fox's root they spawn along the lane, and their height above the ground (player torso)
local BOLT_SPEED, BOLT_RADIUS, BOLT_RANGE, BOLT_START, BOLT_HEIGHT = 70, 1.5, 50, 6, 3.5

--[[ Barrages (Nine-Tailed Fox): timed sub-areas ]]
-- A barrage is computed once at the START of the windup from where the target stands
-- then, so every area is locked, telegraphed and fair. Parts are plain shapes
-- (kind/shape "box" | "circle" | "cone", the fields `caught` and Telegraphs read) plus
-- `delay` (seconds after the windup ends that the part hits), `ext` (seconds before
-- `delay` that the tail starts extending), `tail` (1..9, the tail that lances, fires
-- or plunges), and optional `damageScale`, `stun` (hitStun applies) and `snare`
-- (the attack's `pull` applies). Sent to clients as Telegraph shape
-- { kind = "multi" | "howl", pattern, parts }. Patterns: see buildParts.
local function boxPart(facing: CFrame, yaw: number, length: number, width: number, delay: number, tail: number, ext: number?): any
	return {
		kind = "box", shape = "box",
		cframe = facing * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -length / 2),
		size = Vector2.new(width, length), delay = delay, tail = tail, ext = ext,
		-- the lane's ground origin and unit direction (foxfireVolley fires its bolt along it)
		origin = facing.Position, dir = (facing * CFrame.Angles(0, yaw, 0)).LookVector,
	}
end

local function circlePart(center: Vector3, radius: number, delay: number, tail: number): any
	return { kind = "circle", shape = "circle", center = groundAt(center), radius = radius, delay = delay, tail = tail }
end

local function buildParts(enemy: Enemy, attack: Enemies.Attack, ground: Vector3, dir: Vector3, targetRoot: BasePart): Shape
	local facing = CFrame.lookAt(ground, ground + dir)
	local target = groundAt(targetRoot.Position)
	local phase = enemy.phase
	local length, width = attack.length or 20, attack.width or 4
	local pattern = attack.barrage or "lance"
	local parts: { any } = {}
	if pattern == "fangs" then
		-- three cones, one per bite, all facing where the target stood
		for i = 1, 3 do
			table.insert(parts, {
				kind = "cone", shape = "cone", center = ground, cframe = facing, radius = attack.radius,
				size = Vector2.new(attack.angle :: number, 0), delay = (i - 1) * 0.4, tail = 0,
			})
		end
	elseif pattern == "lance" then
		table.insert(parts, boxPart(facing, 0, length, width, 0, 5, 0.2))
	elseif pattern == "snare" then
		local part = boxPart(facing, 0, length, width, 0, 5, 0.2)
		part.snare = true
		table.insert(parts, part)
	elseif pattern == "lanceFan" then
		-- tails lance in a sweep across the fan: left to right, P3 back again
		local angles = if phase >= 2 then { 40, 20, 0, -20, -40 } else { 22, 0, -22 }
		local tails = if phase >= 2 then { 1, 3, 5, 7, 9 } else { 3, 5, 7 }
		for i, a in angles do
			table.insert(parts, boxPart(facing, math.rad(a), length, width, (i - 1) * 0.18, tails[i], 0.2))
		end
		if phase >= 3 then
			local n = #angles
			for i = n, 1, -1 do
				table.insert(parts, boxPart(facing, math.rad(angles[i]), length, width, n * 0.18 + 0.3 + (n - i) * 0.18, tails[i], 0.2))
			end
		end
	elseif pattern == "volley" then
		-- foxfire bolts down long lanes. P1-2: five lanes; P3: seven, in two waves with
		-- the gaps swapped (odd lanes first, even lanes 0.7 s later)
		local count = if phase >= 3 then 7 else 5
		local step = if phase >= 3 then 15 else 20
		for i = 1, count do
			local a = (count + 1) / 2 - i
			local wave = if phase >= 3 and i % 2 == 0 then 0.7 else 0
			local tail = math.clamp(math.floor((i - 1) * 8 / (count - 1) + 1.5), 1, 9)
			local lane = boxPart(facing, math.rad(a * step), length, width, wave + (i % 2) * 0.05 + (i - 1) * 0.04, tail, 0)
			lane.bolt = true -- resolved by a projectile fired at `delay`, not an instant lane hit
			table.insert(parts, lane)
		end
	elseif pattern == "embers" then
		-- the Flame Raven's fan: three ember lobs, on the target and either side of it, a beat apart
		local flank = attack.flank or 9
		local across = Vector3.new(-dir.Z, 0, dir.X)
		for i, side in { 0, -1, 1 } do
			local at = groundAt(target + across * flank * side)
			table.insert(parts, circlePart(at, attack.radius :: number, (i - 1) * 0.15, 5))
		end
	elseif pattern == "ringHeart" then
		-- four eruptions on a ring round the target, then one under them
		local ring = attack.ring or 11
		local plunge = { 1, 3, 7, 9 }
		for i = 1, 4 do
			local a = math.rad(45 + 90 * (i - 1)) + math.atan2(-dir.X, -dir.Z)
			local at = target + Vector3.new(-math.sin(a), 0, -math.cos(a)) * ring
			table.insert(parts, circlePart(at, attack.radius :: number, 0, plunge[i]))
		end
		local heart = circlePart(target, attack.heartRadius or 7, 0.8, 5)
		heart.stun = true
		table.insert(parts, heart)
	elseif pattern == "spiral" then
		-- nine tails slam down in a spiral round the target, then the fox's own ring
		local start = math.atan2(-dir.X, -dir.Z)
		for i = 1, 9 do
			local a = start + math.rad(40) * (i - 1)
			local r = 5 + (i - 1) * 1.6
			local at = target + Vector3.new(-math.sin(a), 0, -math.cos(a)) * r
			table.insert(parts, circlePart(at, attack.radius :: number, 0.2 * (i - 1), i))
		end
		local last = circlePart(ground, attack.finalRadius or 20, 1.9, 0)
		last.stun = true
		last.damageScale = 2
		table.insert(parts, last)
	end
	return { kind = "multi", pattern = pattern, parts = parts, center = ground }
end

-- A backflip: straight away from the target `distance` studs, leaving a fire trail on
-- the ground it crosses (three ticks at 0.5, 1.0, 1.5 s after the take-off, a scaled
-- hit each). The shape is a harmless ring at the landing plus the trail parts; the
-- second and third trail boxes repeat the first, so Telegraphs draws only one.
local function buildRetreat(enemy: Enemy, attack: Enemies.Attack, ground: Vector3, dir: Vector3): Shape
	local distance = attack.distance or 30
	local land = groundAt(ground - dir * distance)
	local facing = CFrame.lookAt(ground, ground - dir)
	local parts: { any } = {}
	for i, delay in { 0.5, 1.0, 1.5 } do
		local part = boxPart(facing, 0, distance, attack.width or 6, delay, 0)
		part.damageScale = attack.trailScale or 0.3
		part.hidden = i > 1
		table.insert(parts, part)
	end
	return { kind = "howl", center = land, radius = 8, parts = parts, pattern = "trail" }
end

-- Yank a player toward the beast over `spec.seconds`, until `spec.distance` studs
-- from its root. Server moves the character (untested against client physics).
local function pullPlayer(enemy: Enemy, player: Player, spec: { distance: number, seconds: number })
	local root = playerRoot(player)
	if not root then
		return
	end
	local start = root.Position
	local toward = flat(enemy.root.Position - start)
	local travel = toward.Magnitude - spec.distance
	if travel <= 0 then
		return
	end
	local dir = toward.Unit
	effectRemote:FireAllClients("enemyCue", enemy.model, "snare", player.Character)
	PlayerStun.apply(player, "stagger", spec.seconds, enemy.model)
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local r = playerRoot(player)
			if not r or enemies[enemy.model] ~= enemy then
				return
			end
			local a = math.min((os.clock() - t0) / spec.seconds, 1)
			local p = start + dir * travel * a
			r.CFrame = CFrame.new(p.X, r.Position.Y, p.Z) * r.CFrame.Rotation
			if a >= 1 then
				return
			end
			task.wait()
		end
	end)
end

-- `origin`: where a bolt was fired from, for the guard (guardHit).
local function hurtPart(enemy: Enemy, attack: Enemies.Attack, part: any, player: Player, origin: Vector3?)
	local hit = guardHit(enemy, attack, origin)
	landOn(player, function()
		local damage = attack.damage * (part.damageScale or 1) * Realms.ofBeast(enemy.def.realm).beastDamage
		local result = hurtBy(enemy, player, damage, hit)
		if result ~= "hit" or not player.Character then
			return
		end
		effectRemote:FireAllClients("enemyCue", enemy.model, "hit", player.Character)
		local hs = attack.hitStun
		-- a snare's pull replaces the shove
		reactTo(enemy, attack, player, if hs and part.stun then hs else nil, not (part.snare and attack.pull))
		if part.snare and attack.pull then
			pullPlayer(enemy, player, attack.pull)
			local follow = attack.followUpOnHit
			if follow then
				-- after resolveAttack's own followUp bookkeeping, only because the snare caught someone
				task.defer(function()
					enemy.followUp = follow
					enemy.followUpUntil = os.clock() + attack.recover + 1.5
				end)
			end
		end
	end)
end

-- Resolve a barrage or retreat: each part hits `delay` seconds after the windup, for
-- whoever stands in it then. A stagger of the beast or its next attack calls the
-- rest off (strikeId); resolveAttack has already bumped it for this attack.
local function resolveParts(enemy: Enemy, attack: Enemies.Attack, shape: Shape)
	local id = enemy.strikeId
	if attack.recoverP3 and enemy.phase >= 3 then
		enemy.recoverFor = attack.recoverP3
	end
	local model = enemy.model
	for _, part in shape.parts or {} do
		local function fire()
			if enemies[model] ~= enemy or enemy.health <= 0 or enemy.strikeId ~= id then
				return
			end
			if part.bolt then
				-- a foxfire bolt down the (already warned) lane at player-torso height, from
				-- just ahead of the fox; clients draw it from the tail `data.tail`
				local origin = part.origin + part.dir * BOLT_START + Vector3.new(0, BOLT_HEIGHT, 0)
				Projectiles.fire({
					owner = model, cue = "foxfireBolt", origin = origin, velocity = part.dir * BOLT_SPEED,
					radius = BOLT_RADIUS, range = BOLT_RANGE, lifetime = 1.6,
					onHit = function(player: Player, _position: Vector3)
						hurtPart(enemy, attack, part, player, origin)
						return nil
					end,
					data = { tail = part.tail, phase = enemy.phase },
				})
				return
			end
			for _, player in Players:GetPlayers() do
				local root = playerRoot(player)
				if root and caught(part, player, root) then
					hurtPart(enemy, attack, part, player)
				end
			end
		end
		if (part.delay or 0) <= 0 then
			fire()
		else
			task.delay(part.delay, fire)
		end
	end
end

-- A lob (boulderHurl): released `release` seconds into the windup from the fist
-- (a root-relative offset), arriving on the locked circle `flight` seconds later,
-- exactly at windup end. A direct hit hurts; where it lands, anyone else in the
-- circle takes the impact, but only if it landed inside the circle it showed.
local function launchLob(enemy: Enemy, attack: Enemies.Attack, shape: Shape, id: number)
	local proj = attack.projectile :: any
	local model = enemy.model
	local center = shape.center :: Vector3
	task.delay(proj.release or 0, function()
		if enemies[model] ~= enemy or enemy.health <= 0 or enemy.strikeId ~= id or enemy.state ~= "windup" then
			return
		end
		local origin = enemy.root.CFrame:PointToWorldSpace(proj.origin)
		local gravity = proj.gravity or 0
		local hitSet: { [Player]: boolean } = {}
		Projectiles.fire({
			owner = model,
			cue = proj.cue,
			origin = origin,
			velocity = Projectiles.lobVelocity(origin, center + Vector3.new(0, proj.radius, 0), proj.flight or 0.45, gravity),
			radius = proj.radius,
			gravity = gravity,
			lifetime = (proj.flight or 0.45) + 1.5,
			data = proj.data,
			onHit = function(player: Player)
				hitSet[player] = true
				hurtPlayer(enemy, attack, player, origin)
				return nil
			end,
			onEnd = function(position: Vector3, reason: string)
				if reason == "cancel" or reason == "owner" or enemies[model] ~= enemy then
					return
				end
				if flat(position - center).Magnitude > (attack.radius :: number) then
					return -- stopped short or wide of the circle it showed: no splash
				end
				local splash: Shape = { kind = "circle", center = center, radius = attack.radius }
				for _, player in Players:GetPlayers() do
					local root = playerRoot(player)
					if root and not hitSet[player] and caught(splash, player, root) then
						hurtPlayer(enemy, attack, player, origin)
					end
				end
			end,
		})
	end)
end

-- A lance (thunderLance): a straight bolt down the warned lane at windup end.
local function fireLance(enemy: Enemy, attack: Enemies.Attack)
	local proj = attack.projectile :: any
	local look = flat(enemy.root.CFrame.LookVector)
	local dir = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local origin = groundAt(enemy.root.Position) + dir * -proj.origin.Z + Vector3.new(0, 3.5, 0)
	Projectiles.fire({
		owner = enemy.model,
		cue = proj.cue,
		origin = origin,
		velocity = dir * proj.speed,
		radius = proj.radius,
		range = proj.range,
		pierce = proj.pierce,
		lifetime = 1.5,
		data = proj.data,
		onHit = function(player: Player)
			hurtPlayer(enemy, attack, player, origin)
			return nil
		end,
	})
end

-- `arriving`: an `arrive` follow-up, started the moment its parent's dash or leap
-- arrived (think), turning into the blow over its windup.
local function startAttack(enemy: Enemy, targetRoot: BasePart, now: number, attack: Enemies.Attack, arriving: boolean?)
	local def = enemy.def
	enemy.attack = attack
	stop(enemy)
	enemy.mover.turn = false
	-- a flanking lunge (the Shadow Mane's shadowStep) ends `flankPoint` studs beside the
	-- target, 60 degrees off the line to it on a random side, instead of running through it
	local flankPoint: Vector3? = nil
	if attack.kind == "lunge" and attack.flankPoint and not arriving then
		local toTarget = flat(targetRoot.Position - enemy.root.Position)
		if toTarget.Magnitude > 0.1 then
			local side = if math.random() < 0.5 then 1 else -1
			local away = CFrame.Angles(0, side * math.rad(60), 0):VectorToWorldSpace(toTarget.Unit)
			flankPoint = targetRoot.Position - away * attack.flankPoint
		end
	end
	local aim = flankPoint or targetRoot.Position
	if arriving then
		turnToward(enemy, targetRoot.Position, attack.windup * ARRIVE_TURN)
	elseif attack.kind == "leap" or attack.kind == "charge" or attack.kind == "lunge" then
		-- the body turns into the line during the anticipation, not after it
		turnToward(enemy, aim, attack.windup * WINDUP_TURN)
	else
		face(enemy, targetRoot.Position)
	end
	local ground = groundAt(enemy.root.Position)
	local dir = flat(aim - enemy.root.Position)
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
	elseif BossAttacks.SHAPED[attack.kind] then
		shape = BossAttacks.shape(enemy, attack, targetRoot, ground, dir)
	elseif attack.kind == "barrage" then
		shape = buildParts(enemy, attack, ground, dir, targetRoot)
	elseif attack.kind == "retreat" then
		shape = buildRetreat(enemy, attack, ground, dir)
		enemy.dashTo = shape.center
	elseif attack.kind == "summon" or attack.kind == "howl" or attack.kind == "storm" or attack.kind == "guard" then
		shape = { kind = "howl", center = ground, radius = 8 }
	elseif attack.kind == "lance" then
		-- a lane hit all at once when the windup ends; no dash
		local length = attack.length :: number
		shape = {
			kind = "box",
			cframe = CFrame.lookAt(ground, ground + dir) * CFrame.new(0, 0, -length / 2),
			size = Vector2.new(attack.width :: number, length),
		}
	else
		local length = attack.length :: number
		if flankPoint then
			length = math.clamp(flat(flankPoint - enemy.root.Position).Magnitude, 4, length)
		elseif attack.stopPast then
			-- stop just past the target, not the full lane
			local reach = flat(targetRoot.Position - enemy.root.Position).Magnitude + attack.stopPast
			length = math.clamp(reach, attack.minRange or 0, length)
		end
		enemy.dashLength = length
		enemy.model:SetAttribute("DashSeconds", length / (attack.dashSpeed or 1))
		-- the hit box runs `reach` past the dash's end for a muzzle that leads the root
		local boxLength = length + (attack.reach or 0)
		shape = {
			kind = "box",
			cframe = CFrame.lookAt(ground, ground + dir) * CFrame.new(0, 0, -boxLength / 2),
			size = Vector2.new(attack.width :: number, boxLength),
		}
		enemy.dashTo = enemy.root.Position + dir * length
	end
	enemy.shape = shape
	enemy.stateUntil = now + attack.windup
	local name = attackName(attack)
	local stun = attack.stun
	if stun and not stun.onHit then
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
	if TURNS and (not def.boss or def.shareTurns) and (attack.damage > 0 or attack.slot) and enemy.target then
		takeSlot(enemy, enemy.target)
	end
	-- which attack, for per-attack poses and effects (EnemyAnimator, EnemyFX). A
	-- follow-up changes AIState first, so the parent's `land` cue still carries the
	-- parent's name.
	if arriving then
		setState(enemy, "windup")
		setAttack(enemy, name)
	else
		setAttack(enemy, name)
		setState(enemy, "windup")
	end
	if attack.projectile then
		-- a real projectile: warn the lane or the landing circle now, fire later
		if attack.kind == "lance" then
			Projectiles.warnLane(enemy.model, name, ground, dir, attack.length :: number, attack.width :: number, seconds)
		else
			Projectiles.warnLanding(enemy.model, name, shape.center :: Vector3, attack.radius :: number, seconds)
			launchLob(enemy, attack, shape, enemy.strikeId)
		end
	else
		telegraphRemote:FireAllClients(shape, seconds, enemy.model, name, serverNow())
	end
	if BossAttacks.SHAPED[attack.kind] then
		BossAttacks.begin(enemy, attack)
	end
	if attack.unburrowAt == "windup" then
		-- the rise is animated over the windup (the centipede's erupt): surface as it starts
		enemy.model:SetAttribute("Burrowed", nil)
	end
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
		if enemy.attack.thresholdOnly or (enemy.def.pack and enemy.attack == enemy.def.pack.howl) then
			-- A phase call or the engage howl interrupts the upcoming move; it does not consume it.
			enemy.attack = if enemy.patternIndex == 0 then enemy.def.attack else pattern[enemy.patternIndex]
			return
		end
		for _ = 1, #pattern do
			enemy.patternIndex = enemy.patternIndex % #pattern + 1
			enemy.attack = pattern[enemy.patternIndex]
			if not enemy.attack.thresholdOnly and not enemy.attack.chainOnly then
				return
			end
		end
	end
end

-- A storm call's lightning: bolt i picks where the target stands when its turn
-- comes (so keep moving), shows a circle for boltWindup, then strikes. The beast
-- stays in recover meanwhile; a stagger of it doesn't call the bolts off.
local function callStorm(enemy: Enemy, attack: Enemies.Attack)
	local bolts = if enemy.phase >= 3 then attack.boltsP3 or attack.bolts or 5 else attack.bolts or 5
	local interval, warning = attack.boltInterval or 0.45, attack.boltWindup or 0.9
	local radius = attack.boltRadius or 8
	enemy.recoverFor = math.max(attack.recover, interval * (bolts - 1) + warning + 0.3)
	enemy.model:SetAttribute("RecoverFor", enemy.recoverFor) -- the pose holds its channel this long
	local model = enemy.model
	for i = 1, bolts do
		task.delay((i - 1) * interval, function()
			if enemies[model] ~= enemy or enemy.health <= 0 then
				return
			end
			local player = enemy.target
			local root = player and playerRoot(player)
			if not root then
				return
			end
			local shape: Shape = { kind = "circle", center = groundAt(root.Position), radius = radius }
			telegraphRemote:FireAllClients(shape, warning, model, attack.boltName or "stormBolt", serverNow())
			task.delay(warning, function()
				if enemies[model] == enemy and enemy.health > 0 then
					hurtIn(enemy, attack, shape)
				end
			end)
		end)
	end
end

-- A slam's second ring (attack.wave): same centre, wider, half damage later,
-- and not for anyone the slam's own circle already caught.
local function callWave(enemy: Enemy, attack: Enemies.Attack, slam: Shape)
	local wave = attack.wave :: any
	local center = slam.center :: Vector3
	local shape: Shape = { kind = "circle", center = center, radius = wave.radius }
	local model = enemy.model
	telegraphRemote:FireAllClients(shape, wave.delay, model, "poundWave", serverNow())
	local weak: Enemies.Attack = table.clone(attack)
	weak.damage = attack.damage * wave.scale
	weak.wave = nil
	weak.react = "flinch" -- the outer wave only rocks them
	task.delay(wave.delay, function()
		if enemies[model] ~= enemy or enemy.health <= 0 then
			return
		end
		for _, player in Players:GetPlayers() do
			local root = playerRoot(player)
			if root and flat(root.Position - center).Magnitude > (slam.radius :: number) + PLAYER_RADIUS and caught(shape, player, root) then
				hurtPlayer(enemy, weak, player)
			end
		end
	end)
end

local function resolveAttack(enemy: Enemy, now: number)
	local attack = enemy.attack
	local shape = enemy.shape :: Shape
	enemy.shape = nil
	enemy.strikeId += 1
	enemy.recoverFor = attack.recover
	planAssault(enemy, attack, shape, now)
	if attack.kind == "summon" then
		summon(enemy, attack)
	elseif attack.kind == "bound" then
		-- no damage: the hop below is all it does
	elseif attack.kind == "storm" then
		callStorm(enemy, attack)
	elseif BossAttacks.OWNED[attack.kind] then
		BossAttacks.resolve(enemy, attack, shape, now)
	elseif attack.kind == "howl" then
		if callPack(enemy, attack, now) == 0 and attack.summons then
			reinforce(enemy, attack)
		end
	elseif attack.kind == "leap" then
		enemy.landShape = shape -- resolves as it lands (think, dash)
		enemy.landAttack = attack -- enemy.attack moves on at the end of this function
		enemy.landFrom = enemy.root.Position -- the guard judges the landing from the take-off
	elseif attack.kind == "barrage" or attack.kind == "retreat" then
		resolveParts(enemy, attack, shape)
	elseif attack.projectile then
		if attack.kind == "lance" then
			fireLance(enemy, attack)
		end -- a lob was released mid-windup (launchLob)
	elseif enemy.dashTo and TURNS then
		hurtAlongDash(enemy, attack, shape)
	else
		hurtIn(enemy, attack, shape)
		if attack.wave and enemy.phase >= attack.wave.phase then
			callWave(enemy, attack, shape)
		end
	end
	if attack.patch and shape.center then
		-- a spit leaves a lingering patch where it landed (toad miasma, spider web)
		BossAttacks.addPatch(enemy, shape.center :: Vector3, attack.radius :: number, attack.patch)
	end
	if attack.phaseStep then
		enemy.phase += 1
		enemy.runBoost *= enemy.def.phaseSpeed or 1
		setSpeed(enemy, enemy.def.runSpeed)
		enemy.model:SetAttribute("Phase", enemy.phase)
		effectRemote:FireAllClients("enemyCue", enemy.model, "phase")
	end
	BossAttacks.resolved(enemy, attack, now)
	local stun = attack.stun
	if stun and not stun.onHit then
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
	if attack.rangedNext then
		-- it made its own range (the Jiao's tail shove): a ranged attack comes next
		enemy.preferNext = attack.rangedNext
		enemy.preferUntil = now + attack.recover + (attack.rangedWait or 2.5)
	end
	enemy.followUp = attack.followUp
	if attack.followUp then
		-- through the dash and recover, plus a short wait for the attack slot
		local dash = if attack.dashSpeed then enemy.dashLength / attack.dashSpeed else 0
		enemy.followUpUntil = now + dash + attack.recover + FOLLOW_UP_WAIT
	end
	if attack.kind == "guard" then
		-- Shell Guard: hunker down for `hold` seconds as AIState dash (clients pose it
		-- from the Attack name), taking `reduction` less from player hits (Combat.damageEnemy
		-- reads Guarding); the `arrive` follow-up snaps out of it when the hold ends
		local hold = attack.hold or 2
		enemy.model:SetAttribute("Guarding", true)
		enemy.model:SetAttribute("GuardReduction", attack.reduction or 0.8)
		enemy.model:SetAttribute("DashSeconds", hold)
		enemy.dashAttack = attack
		startDash(enemy, enemy.root.Position, 1)
		enemy.stateUntil = now + hold
	elseif enemy.dashTo then
		local to = enemy.dashTo :: Vector3
		enemy.dashAttack = attack
		if attack.kind == "leap" or attack.kind == "bound" or attack.kind == "retreat" then
			local flight = enemy.dashFlight or attack.active or 0.45
			local arc = enemy.dashArc or attack.arc
			enemy.dashFlight, enemy.dashArc = nil, nil
			enemy.model:SetAttribute("DashSeconds", flight)
			startDash(enemy, to, math.max(flat(to - enemy.root.Position).Magnitude / flight, 1), arc)
			enemy.stateUntil = now + flight
			if WEIGHTED and attack.kind ~= "retreat" then
				-- the yaw finishes in the air: touch down facing the target (or along
				-- the flight when it still stands on the landing spot)
				local targetRoot = enemy.target and playerRoot(enemy.target)
				local facing = if targetRoot then flat(targetRoot.Position - to) else Vector3.zero
				if facing.Magnitude < 3 then
					facing = flat(to - enemy.root.Position)
				end
				EnemyMover.turnTo(enemy.mover, facing, flight * AIR_TURN, os.clock())
			end
		else
			-- the dash's line, so clients draw it where it is on the server, not a
			-- ping behind (EnemyMotion)
			startDash(enemy, to, attack.dashSpeed :: number)
			enemy.stateUntil = now + math.max(enemy.dashLength / (attack.dashSpeed :: number), attack.dashMin or 0) + 0.1
		end
		enemy.dashTo = nil
	else
		releaseSlot(enemy)
		enemy.state = "recover"
		enemy.stateUntil = now + enemy.recoverFor
	end
	if enemy.resume then
		-- an `arrive` follow-up: the pattern carries on from the attack it cut in front of
		enemy.attack = enemy.resume
		enemy.resume = nil
	else
		advancePattern(enemy)
	end
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
	setAttack(enemy, "hop")
	enemy.dashAttack = nil
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
-- Rotating bosses (def.rotate): the next attack in the pattern whose phase, range
-- band and cooldown fit, scanning on from where the rotation stands, so a boulder
-- is skipped at melee and a pound at range. Chain-only and threshold attacks never
-- come from here.
local function rotateAttack(enemy: Enemy, distance: number, now: number): Enemies.Attack?
	local pattern = enemy.def.pattern :: { Enemies.Attack }
	local n = #pattern
	local prefer = enemy.preferNext
	if prefer and now >= enemy.preferUntil then
		enemy.preferNext, prefer = nil, nil
	end
	if prefer then
		-- after an attack with `rangedNext`: one of those, or nothing yet (it holds)
		for i, a in pattern do
			if
				table.find(prefer, attackName(a))
				and (a.phase or 1) <= enemy.phase
				and distance <= a.range
				and distance >= (a.minRange or 0)
			then
				enemy.preferNext = nil
				enemy.patternIndex = i
				return a
			end
		end
		return nil
	end
	local start = math.max(enemy.patternIndex, 1)
	for step = 0, n - 1 do
		local i = (start - 1 + step) % n + 1
		local a = pattern[i]
		if
			not a.chainOnly
			and not a.thresholdOnly
			and (a.phase or 1) <= enemy.phase
			and distance <= a.range
			and distance >= (a.minRange or 0)
			and now >= (enemy.cooldowns[attackName(a)] or 0)
		then
			enemy.patternIndex = i
			return a
		end
	end
	return nil
end

-- A bound: no damage, no area. It crouches (windup), then hops and chases again.
-- Without `boundModes` it lands on a flank spot landMin-landMax studs from the target
-- (a random side). With them (the Thunder Ape) each bound picks a landing mode, never
-- the last one, sent as the BoundMode attribute at windup, each with its own arc and
-- flight (DashArc, DashSeconds):
--   over   past the target, on the far side (target within OVER_MAX), turning in the
--          air to land facing back at it; the highest arc
--   flank  to the target's left or right
--   back   a retreat hop straight away (target within BACK_MAX)
--   short  a small hop round the target at about the same distance
-- Every landing is on ground within 10 studs of the target's height. Clients get a
-- Telegraph with an empty "bound" shape so the windup cue fires.
local OVER_MAX, BACK_MAX = 50, 40

local function boundPoint(enemy: Enemy, attack: Enemies.Attack, targetRoot: BasePart, mode: string): Vector3?
	local center = targetRoot.Position
	local base = groundAt(center)
	local position = enemy.root.Position
	local away = flat(position - center)
	local distance = away.Magnitude
	away = if distance > 0.1 then away.Unit else Vector3.xAxis
	local landMin, landMax = attack.landMin or 22, attack.landMax or 28
	for _ = 1, 8 do
		local side = if math.random() < 0.5 then 1 else -1
		local probe: Vector3
		if mode == "over" then
			local dir = CFrame.Angles(0, math.rad((math.random() * 2 - 1) * 20), 0):VectorToWorldSpace(-away)
			probe = center + dir * (landMin + math.random() * (landMax - landMin))
		elseif mode == "back" then
			local dir = CFrame.Angles(0, math.rad((math.random() * 2 - 1) * 25), 0):VectorToWorldSpace(away)
			probe = center + dir * math.min(distance + 14 + math.random() * 6, landMax + 22)
		elseif mode == "short" then
			local dir = CFrame.Angles(0, side * math.rad(25 + math.random() * 15), 0):VectorToWorldSpace(away)
			probe = center + dir * math.clamp(distance, landMin, landMax + 10)
		else -- flank
			local dir = CFrame.Angles(0, side * math.rad(60 + math.random() * 90), 0):VectorToWorldSpace(away)
			probe = center + dir * (landMin + math.random() * (landMax - landMin))
		end
		local hit = workspace:Raycast(probe + Vector3.new(0, 60, 0), Vector3.new(0, -160, 0), groundParams())
		if hit and math.abs(hit.Position.Y - base.Y) <= 10 then
			return hit.Position
		end
	end
	return nil
end

local function startBound(enemy: Enemy, targetRoot: BasePart, now: number, attack: Enemies.Attack)
	enemy.attack = attack
	stop(enemy)
	enemy.mover.turn = false
	local center = targetRoot.Position
	local distance = flat(enemy.root.Position - center).Magnitude
	local modes = attack.boundModes
	local mode = "flank"
	local point: Vector3? = nil
	if modes then
		local fits: { string } = {}
		for _, m in BOUND_MODES do
			if modes[m] and m ~= enemy.boundMode
				and not (m == "over" and distance > OVER_MAX)
				and not (m == "back" and distance > BACK_MAX)
			then
				table.insert(fits, m)
			end
		end
		-- a random fit first, then the rest in order, until one has ground to land on
		if #fits > 0 then
			local first = math.random(#fits)
			fits[1], fits[first] = fits[first], fits[1]
		end
		for _, m in fits do
			point = boundPoint(enemy, attack, targetRoot, m)
			if point then
				mode = m
				break
			end
		end
	else
		point = boundPoint(enemy, attack, targetRoot, "flank")
	end
	if not point then
		local away = flat(enemy.root.Position - center)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
		point = groundAt(center + away * (attack.landMin or 22))
		mode = "flank"
	end
	local landing = point :: Vector3
	if modes then
		local spec = modes[mode] or {}
		enemy.boundMode = mode
		enemy.dashFlight, enemy.dashArc = spec.active, spec.arc
		enemy.model:SetAttribute("BoundMode", mode)
		-- which way the hop travels across the body (+1 right, -1 left), so the windup leans into it
		local across = enemy.root.CFrame.RightVector:Dot(flat(landing - enemy.root.Position))
		enemy.model:SetAttribute("BoundSide", if across >= 0 then 1 else -1)
	end
	-- crouch facing the jump (over, flank) or the target (back, short); the air does the rest
	if WEIGHTED and (mode == "over" or mode == "flank") then
		turnToward(enemy, landing, attack.windup * WINDUP_TURN)
	else
		turnToward(enemy, center, attack.windup * WINDUP_TURN)
	end
	enemy.dashTo = landing
	enemy.shape = { kind = "bound", center = landing, radius = 0 }
	enemy.stateUntil = now + attack.windup
	enemy.nextAttack = now + attack.cooldown
	setAttack(enemy, attackName(attack))
	setState(enemy, "windup")
	telegraphRemote:FireAllClients(enemy.shape, attack.windup, enemy.model, attackName(attack), serverNow())
end

-- Spacing bosses (def.spacing, the Nine-Tailed Fox): a random pick among the pool
-- attacks that fit the phase, range band and cooldown (cooldowns shrink by phase),
-- never the same twice in a row, never crowd control straight after crowd control.
-- The backflip (`spacing.leap`) is not in the draw: it fires when the fox has made
-- `meleeChain` melee attacks in a row, been `closeRange` close for `closeSeconds`,
-- or lost `hurtFraction` of its health in `hurtSeconds`.
type FoxState = { engagedAt: number, last: string?, melee: number, closeSince: number?, ccUntil: number, health: { { number } } }
local foxStates: { [Enemy]: FoxState } = setmetatable({}, { __mode = "k" }) :: any

local function isCC(a: Enemies.Attack): boolean
	return a.stun ~= nil or a.hitStun ~= nil
end

local function foxAttack(enemy: Enemy, distance: number, now: number, slotOk: boolean): Enemies.Attack?
	local def = enemy.def
	local sp = def.spacing :: any
	local st = foxStates[enemy]
	if not st or st.engagedAt ~= enemy.engagedAt then
		st = { engagedAt = enemy.engagedAt, last = nil, melee = 0, closeSince = nil, ccUntil = 0, health = {} }
		foxStates[enemy] = st
	end
	-- recent health, for the hurt trigger
	table.insert(st.health, { now, enemy.health })
	while #st.health > 1 and now - st.health[1][1] > sp.hurtSeconds + 1 do
		table.remove(st.health, 1)
	end
	local lost = 0
	for _, sample in st.health do
		if now - sample[1] <= sp.hurtSeconds + 1 then
			lost = math.max(lost, sample[2] - enemy.health)
		end
	end
	if distance <= sp.closeRange then
		st.closeSince = st.closeSince or now
	else
		st.closeSince = nil
	end
	if now < enemy.nextAttack or not slotOk then
		return nil
	end
	local scale = (sp.cooldownScale :: { number })[enemy.phase] or 1
	local function ready(a: Enemies.Attack): boolean
		return now >= (enemy.cooldowns[attackName(a)] or 0) - a.cooldown * (1 - scale)
	end
	local pool = def.attacks :: { Enemies.Attack }
	local function pick(a: Enemies.Attack): Enemies.Attack
		local name = attackName(a)
		st.last = name
		if isCC(a) then
			st.ccUntil = now + a.windup + a.recover + 2
		end
		if distance <= sp.closeRange or a.range <= sp.closeRange + 2 then
			st.melee += 1
		else
			st.melee = 0
		end
		return a
	end
	local leap: Enemies.Attack? = nil
	for _, a in pool do
		if attackName(a) == sp.leap then
			leap = a
		end
	end
	if leap and ready(leap) and (leap.phase or 1) <= enemy.phase then
		local tooClose = st.closeSince ~= nil and now - st.closeSince >= sp.closeSeconds
		if st.melee >= sp.meleeChain or tooClose or lost >= enemy.maxHealth * sp.hurtFraction then
			st.melee, st.closeSince = 0, nil
			table.clear(st.health)
			st.last = attackName(leap)
			return leap
		end
	end
	local fits: { Enemies.Attack } = {}
	for _, a in pool do
		local name = attackName(a)
		if
			a ~= leap
			and not a.thresholdOnly
			and not a.chainOnly
			and (a.phase or 1) <= enemy.phase
			and distance <= a.range
			and distance >= (a.minRange or 0)
			and name ~= st.last
			and ready(a)
			and not (isCC(a) and now < st.ccUntil)
		then
			table.insert(fits, a)
		end
	end
	if #fits == 0 then
		return nil
	end
	return pick(fits[math.random(#fits)])
end

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
		for _, a in enemy.def.attacks or enemy.def.pattern or {} do
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
	if enemy.def.spacing then
		return foxAttack(enemy, distance, now, slotOk)
	end
	if now < enemy.nextAttack or not slotOk then
		return nil
	end
	local function fits(a: Enemies.Attack): boolean
		return not a.chainOnly
			and distance <= a.range
			and distance >= (a.minRange or 0)
			and now >= (enemy.cooldowns[attackName(a)] or 0)
			and (a.notBefore == nil or now - enemy.engagedAt >= a.notBefore)
	end
	local pool = enemy.def.attacks
	if not pool and enemy.def.rotate then
		return rotateAttack(enemy, distance, now)
	end
	if not pool then
		local queued = enemy.attack
		if WEIGHTED and queued.kind == "leap" and distance < (queued.minRange or 0) then
			-- too close to leap at (the Wolf King's kingLeap): the pattern moves on
			advancePattern(enemy)
			return nil
		end
		return if distance <= queued.range then queued else nil
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

-- A skid-and-turn: the dash is over but its target isn't where the blow can land.
-- It recovers as usual (the parent's recover), with AttackName `<parent>Skid` (Attack
-- stays the parent's), sliding on a little after a charge or lunge while it swings
-- round to face the target, and is facing it before the recover ends.
local function skid(enemy: Enemy, parent: Enemies.Attack, targetRoot: BasePart, now: number)
	local model = enemy.model
	model:SetAttribute("AttackName", attackName(parent) .. "Skid")
	releaseSlot(enemy)
	enemy.state = "recover"
	enemy.stateUntil = now + enemy.recoverFor
	enemy.mover.turn = false
	local from, to = model:GetAttribute("DashFrom"), model:GetAttribute("DashTo")
	if parent.dashSpeed and typeof(from) == "Vector3" and typeof(to) == "Vector3" and flat(to - from).Magnitude > 1 then
		local studs = math.clamp(parent.dashSpeed * SKID_SLIDE, 1, 5)
		setSpeed(enemy, studs / SKID_SLIDE_SECONDS)
		moveTo(enemy, enemy.root.Position + flat(to - from).Unit * studs)
	end
	EnemyMover.turnTo(enemy.mover, flat(targetRoot.Position - enemy.root.Position), math.min(enemy.recoverFor * SKID_TURN, 0.9), now)
end

-- How far (degrees) the target is off the beast's nose.
local function offNose(enemy: Enemy, targetRoot: BasePart): number
	local to = flat(targetRoot.Position - enemy.root.Position)
	local look = flat(enemy.root.CFrame.LookVector)
	if to.Magnitude < 0.5 or look.Magnitude < 0.1 then
		return 0
	end
	return math.deg(math.acos(math.clamp(to.Unit:Dot(look.Unit), -1, 1)))
end

-- A dash, leap or bound just arrived (WEIGHTED_MOVES). With the target in reach and
-- in front, the parent's `arrive` follow-up starts at once (no recover between, and it
-- keeps the attack slot); otherwise a beast with `skid` skids round to face it (one
-- without a follow-up only when the target is off its nose). False: recover as usual.
local function arrive(enemy: Enemy, parent: Enemies.Attack, now: number): boolean
	if not (WEIGHTED or parent.kind == "guard") or not (parent.arrive or parent.skid) then
		return false
	end
	local target = enemy.target
	local targetRoot = target and playerRoot(target)
	if not targetRoot then
		return false
	end
	local follow = parent.arrive
	local distance = flat(targetRoot.Position - enemy.root.Position).Magnitude
	if follow and distance <= follow.range and offNose(enemy, targetRoot) <= ARRIVE_ANGLE then
		if enemy.def.pattern then
			enemy.resume = enemy.resume or enemy.attack
		end
		startAttack(enemy, targetRoot, now, follow, true)
		return true
	end
	if not parent.skid or (not follow and offNose(enemy, targetRoot) <= SKID_ANGLE) then
		return false
	end
	skid(enemy, parent, targetRoot, now)
	return true
end

local function think(enemy: Enemy, now: number)
	local def = enemy.def
	local position = enemy.root.Position

	if enemy.state == "windup" then
		if now >= enemy.stateUntil then
			resolveAttack(enemy, now)
		else
			BossAttacks.windupTick(enemy)
		end
		return
	elseif enemy.state == "dash" then
		if now >= enemy.stateUntil then
			stop(enemy)
			setSpeed(enemy, def.runSpeed)
			BossAttacks.landed(enemy)
			-- a leap lands now
			local landing = enemy.landShape
			if landing then
				enemy.landShape = nil
				hurtIn(enemy, enemy.landAttack or enemy.attack, landing, enemy.landFrom, true)
			end
			local parent = enemy.dashAttack
			enemy.dashAttack = nil
			if parent and parent.perch then
				-- a flier lands low after a dive: its hit volume follows the body down
				enemy.mover.rootHeight = enemy.rootHeight - parent.perch
			end
			if parent and arrive(enemy, parent, now) then
				return
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
		enemy.mover.rootHeight = enemy.rootHeight
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
		BossAttacks.disengaged(enemy)
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
			BossAttacks.disengaged(enemy)
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
	local roarPending = false
	if now - enemy.lastEngaged > Config.ENGAGE_RESET then
		local howl = pack and pack.howl
		if howl and howl.stun and flat(targetRoot.Position - position).Magnitude > howl.stun.radius + 6 then
			-- an engage roar that staggers: hold it (the engagement stays fresh)
			-- until the target has come close enough to be caught by it
			roarPending = true
		else
			enemy.engagedAt, enemy.opened = now, false
			enemy.lastEngaged = now
			if howl then
				startAttack(enemy, targetRoot, now, howl)
				return
			end
		end
	end
	if not roarPending then
		enemy.lastEngaged = now
	end

	enemy.state = "chase"
	setSpeed(enemy, def.runSpeed)
	local distance = flat(targetRoot.Position - position).Magnitude

	-- bosses summon when their health crosses a threshold, whatever comes next
	if def.summonAt and def.pattern and now >= enemy.nextAttack then
		local fraction = enemy.health / enemy.maxHealth
		for i, at in def.summonAt do
			if fraction <= at and not enemy.summonsDone[i] then
				enemy.summonsDone[i] = true
				local call = if def.phaseCalls then def.phaseCalls[i] else def.phaseCall
				if call then
					startAttack(enemy, targetRoot, now, call)
					return
				end
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
	elseif choice and choice.kind == "bound" then
		startBound(enemy, targetRoot, now, choice)
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
	elseif enemy.preferNext and now < enemy.preferUntil then
		-- it just made its range (rangedNext): hold it, facing the target, for the shot
		stop(enemy)
		face(enemy, targetRoot.Position)
	elseif def.attacks or distance > (def.closeIn or math.min(enemy.attack.range, 20) * 0.7) then
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
			if enemy.state ~= "dash" and enemy.model:GetAttribute("Guarding") then
				-- the hold ended, or a stagger broke it
				enemy.model:SetAttribute("Guarding", nil)
				enemy.model:SetAttribute("GuardReduction", nil)
			end
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

BossAttacks.init({
	groundAt = groundAt,
	flat = flat,
	playerRoot = playerRoot,
	caught = caught,
	inside = EnemyService.inside,
	hurtPlayer = hurtPlayer,
	hurtIn = hurtIn,
	serverNow = serverNow,
	moveTo = moveTo,
	setSpeed = setSpeed,
	face = face,
	telegraph = function(shape: Shape, seconds: number, model: Model, name: string)
		telegraphRemote:FireAllClients(shape, seconds, model, name, serverNow())
	end,
	cue = function(model: Model, name: string)
		effectRemote:FireAllClients("enemyCue", model, name)
	end,
	patchCue = function(model: Model, center: Vector3, radius: number, seconds: number, effect: string?)
		effectRemote:FireAllClients("enemyPatch", model, center, radius, seconds, effect)
	end,
	alive = function(enemy: Enemy): boolean
		return enemies[enemy.model] == enemy and enemy.health > 0
	end,
	valid = function(enemy: Enemy, id: number): boolean
		return enemies[enemy.model] == enemy and enemy.health > 0 and enemy.strikeId == id
	end,
	-- a coil broken in its hold: stagger it where it lies
	stagger = function(enemy: Enemy, seconds: number)
		enemy.shape, enemy.dashTo, enemy.landShape = nil, nil, nil
		enemy.strikeId += 1
		dropArrive(enemy)
		releaseSlot(enemy)
		stop(enemy)
		enemy.mover.turn = false
		setState(enemy, "stagger")
		enemy.stateUntil = os.clock() + seconds
	end,
})

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
