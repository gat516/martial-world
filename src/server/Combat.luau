--!strict
-- Shared action timelines govern attacks, casts, dodges and movement on both
-- sides. Attack is the ordered action transport (begin/hit/cancel/sync); Effect
-- acknowledges predictions. Damage and cooldown authority stay on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Rules = require(ReplicatedStorage.Shared.ActionRules)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Knockback = require(ReplicatedStorage.Shared.Knockback)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Roots = require(ReplicatedStorage.Shared.Roots)
local Registry = require(ReplicatedStorage.Shared.Identity.Registry)
local Cultivation = require(script.Parent.Cultivation)
local CombatQi = require(script.Parent.CombatQi)
local EnemyHistory = require(script.Parent.EnemyHistory)
local PlayerData = require(script.Parent.PlayerData)
local Foundation = require(script.Parent.Foundation)
local Movement = require(script.Parent.Movement)
local PlayerStun = require(script.Parent.PlayerStun)
local Guard = require(script.Parent.Guard)
local Weapons = require(script.Parent.Weapons)
local WeaponDefs = require(ReplicatedStorage.Shared.Weapons)
local WeaponPacing = require(ReplicatedStorage.Shared.Pacing).Weapons

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

type State = {
	character: Model?,
	actions: Rules.State,
	sequence: number,
	released: boolean,
	suppressed: boolean,
	aim: Vector3,
	perfectUsed: boolean,
	lastDodge: number,
	lastDodgeSequence: number,
	ironSkinUntil: number,
	ironSkinReduction: number,
	empowerUntil: number, -- Great Sage Awakening: +empower share of all damage until then
	empower: number,
	invulnerableUntil: number, -- dash-skill i-frames (MoonflashDraw)
	castOrigin: Vector3, -- root position when the current cast began (lunge checks)
	lastHurt: number,
	lastHurtBy: string,
	lastDealt: number, -- os.clock() of the last damage dealt to an enemy (combat qi regen)
	combatWatch: boolean, -- a watcher is waiting to clear the InCombat attribute
}
local states: { [Player]: State } = {}

local Combat = {}

-- The player attribute `InCombat`: hurt or dealing damage within IN_COMBAT_SECONDS
-- (Combat.fighting), the one combat flag the client reads (the top-right tiles fold
-- down, Guide holds its hints). Set on the first blow, cleared by one watcher per
-- player once the window passes.
local function markCombat(player: Player)
	local s = states[player]
	if not s then
		return
	end
	if player:GetAttribute("InCombat") ~= true then
		player:SetAttribute("InCombat", true)
	end
	if s.combatWatch then
		return
	end
	s.combatWatch = true
	task.spawn(function()
		while states[player] == s do
			local quiet = os.clock() - math.max(s.lastHurt, s.lastDealt)
			if quiet >= Config.IN_COMBAT_SECONDS then
				break
			end
			task.wait(Config.IN_COMBAT_SECONDS - quiet + 0.05)
		end
		s.combatWatch = false
		if player.Parent then
			player:SetAttribute("InCombat", false)
		end
	end)
end

-- Set by EnemyService: applies a player's damage to an enemy. `push` is the hit's
-- knockback: flat direction times base studs (Knockback.luau), before realm and weight.
Combat.onEnemyDamaged = nil :: ((model: Model, player: Player, amount: number, push: Vector3?) -> ())?

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = {
			character = player.Character,
			actions = Rules.new(),
			sequence = 0,
			released = false,
			suppressed = false,
			aim = Vector3.zAxis,
			perfectUsed = false,
			lastDodge = -math.huge,
			lastDodgeSequence = 0,
			ironSkinUntil = 0,
			ironSkinReduction = 0,
			empowerUntil = 0,
			empower = 0,
			invulnerableUntil = 0,
			castOrigin = Vector3.zero,
			lastHurt = -math.huge,
			lastHurtBy = "Unknown",
			lastDealt = -math.huge,
			combatWatch = false,
		}
		states[player] = s
	end
	if s.character ~= player.Character then
		local ready, dodgeReady = s.actions.ready, s.actions.dodgeReady
		s.character = player.Character
		s.actions = Rules.new()
		s.actions.ready, s.actions.dodgeReady = ready, dodgeReady
		s.lastDodge, s.ironSkinUntil = -math.huge, 0
		s.empowerUntil, s.invulnerableUntil = 0, 0
		s.lastDodgeSequence = 0
		s.released, s.suppressed = false, false
	end
	return s
end

-- A client timestamp is usable if it isn't from the future or too old.
local function validTime(t: any): boolean
	if type(t) ~= "number" or t ~= t then
		return false
	end
	local now = workspace:GetServerTimeNow()
	return t <= now + Config.CLOCK_SLACK and now - t <= Config.MAX_LAG
end

local function livingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- Damage an enemy on a player's behalf. Every player-caused hit goes through here.
-- EnemyService owns enemy health and applies it (Combat.onEnemyDamaged); `push`,
-- if any, knocks it back.
function Combat.damageEnemy(player: Player, model: Model, amount: number, push: Vector3?)
	if not Hitbox.alive(model) or model:GetAttribute("Burrowed") then
		return -- underground (the Jade Jiao's dive) it can't be touched
	end
	if model:GetAttribute("Guarding") then
		-- hunkered in its shell (the Stone Tortoise's shellGuard): most of the blow is
		-- soaked up and nothing shoves it
		amount = math.max(amount * (1 - (model:GetAttribute("GuardReduction") or 0.8)), 1)
		push = nil
	end
	amount = math.floor(amount + 0.5)
	model:SetAttribute("LastHitBy", player.UserId)
	state(player).lastDealt = os.clock()
	markCombat(player)
	effectRemote:FireClient(player, "damage", model:GetPivot().Position, amount)
	Cultivation.markActive(player)
	if Combat.onEnemyDamaged then
		Combat.onEnemyDamaged(model, player, amount, push)
	end
end

function Combat.power(player: Player): number
	local data = PlayerData.get(player)
	-- the realm's power, then the graded foundations' bonus as its own multiplier (Foundation)
	return if data then Cultivation.stage(data).power * Foundation.multiplier(data) else 1
end

-- The player's spirit root perk of `kind` (Roots.perk) plus their race, variant
-- and trait modifiers of the same kind (Shared.Identity.Registry), 0 while loading.
local function rootPerk(player: Player, kind: Roots.Perk): number
	local data = PlayerData.get(player)
	return if data then Roots.perk(data.root, kind) + Registry.stat(data, kind) else 0
end

--[[ Player damage ]]

export type HurtResult = "hit" | "dodged" | "perfect" | "parried" | "deflected" | "blocked" | "broken" | "none"

-- Damage a player from an enemy attack or hazard that resolves now. Dodging
-- shortly before negates it; Iron Skin reduces it. `nonLethal` leaves them at 1.
-- `source` names what hit them (an enemy id, "Tribulation"), for death analytics.
-- `guard` (where the blow comes from, how heavy; Guard.Hit) makes the hit
-- guardable (Guard.absorb). Guarded hits never flinch: "broken" staggers instead.
-- "parried" should stagger the attacker; "deflected" (a chained parry with
-- more blows coming) shouldn't.
-- A hit resolved late (`guard.at`, EnemyService's race grace) is judged at the
-- server time it landed.
function Combat.hurt(player: Player, amount: number, nonLethal: boolean?, source: string?, guard: Guard.Hit?): (HurtResult, number)
	local root, humanoid = livingRoot(player)
	if not root or not humanoid then
		return "none", 0
	end
	local s = state(player)
	local now = workspace:GetServerTimeNow()
	if guard and guard.at then
		now = math.min(now, guard.at)
	end
	local sinceDodge = now - s.lastDodge
	if sinceDodge >= 0 and sinceDodge <= Config.IFRAME_SECONDS + Config.IFRAME_SLACK then
		if not s.perfectUsed and sinceDodge <= Config.PERFECT_WINDOW + Config.IFRAME_SLACK then
			s.perfectUsed = true
			for id, readyAt in s.actions.ready do
				s.actions.ready[id] = readyAt - Config.PERFECT_REFUND
			end
			effectRemote:FireClient(player, "perfect", Config.PERFECT_REFUND, s.lastDodgeSequence, player.Character)
			return "perfect", 0
		end
		return "dodged", 0
	end
	if now < s.invulnerableUntil then
		return "dodged", 0
	end
	local guarded: HurtResult? = nil
	if guard then
		local result, through = Guard.absorb(player, humanoid, root, amount, guard, now)
		if result == "parried" or result == "deflected" then
			return result, 0
		end
		guarded, amount = result, through
	end
	if now < s.ironSkinUntil then
		amount *= 1 - s.ironSkinReduction
	end
	amount *= 1 - rootPerk(player, "guard")
	amount = math.floor(amount + 0.5)
	if nonLethal then
		amount = math.min(amount, math.max(0, humanoid.Health - 1))
	end
	s.lastHurtBy = source or "Unknown"
	humanoid:TakeDamage(amount)
	s.lastHurt = os.clock()
	markCombat(player)
	effectRemote:FireClient(player, "hurt", amount)
	if guarded then
		return guarded, amount
	end
	if amount > 0 then
		PlayerStun.apply(player, "flinch")
	end
	return "hit", amount
end

-- Damage over time (poison): ignores dodges, no flinch, no hurt flash, and never
-- kills (leaves them at 1). Still counts as being in combat.
function Combat.dot(player: Player, amount: number, source: string?)
	local _, humanoid = livingRoot(player)
	if not humanoid then
		return
	end
	amount = math.min(math.floor(amount + 0.5), math.max(0, humanoid.Health - 1))
	if amount <= 0 then
		return
	end
	local s = state(player)
	s.lastHurtBy = source or "Unknown"
	humanoid:TakeDamage(amount)
	s.lastHurt = os.clock()
	markCombat(player)
end

function Combat.lastHurtBy(player: Player): string
	return state(player).lastHurtBy
end

-- Tell the player what killed them, for the death screen (Effect "died", see
-- docs/ui/death-screen.md). Call it from Humanoid.Died, before the character goes.
--   cause "fall": the body dropped out of the world (or its root is already gone);
--   "tribulation" or "enemy" (with `source`, the enemy's def id): the last hurt,
--   if it landed within IN_COMBAT_SECONDS; otherwise "unknown" (a reset, say).
--   `poisoned`: poison was still in them (PlayerPoison's PoisonStacks).
-- `respawn` is the seconds until the respawn, `hub` whether it's at the main peak.
function Combat.died(player: Player, character: Model, respawn: number, hub: boolean)
	local s = state(player)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cause, source = "unknown", nil
	if not root or root.Parent == nil or root.Position.Y < workspace.FallenPartsDestroyHeight + 50 then
		cause = "fall"
	elseif os.clock() - s.lastHurt < Config.IN_COMBAT_SECONDS then
		if s.lastHurtBy == "Tribulation" then
			cause = "tribulation"
		elseif s.lastHurtBy ~= "Unknown" then
			cause, source = "enemy", s.lastHurtBy
		end
	end
	local stacks = character:GetAttribute("PoisonStacks")
	effectRemote:FireClient(player, "died", {
		cause = cause,
		source = source,
		poisoned = typeof(stacks) == "number" and stacks > 0,
		respawn = respawn,
		hub = hub,
	})
end

function Combat.inCombat(player: Player): boolean
	return os.clock() - state(player).lastHurt < Config.IN_COMBAT_SECONDS
end

-- Hurt or dealing damage lately: combat qi regenerates at its slower rate.
function Combat.fighting(player: Player): boolean
	local s = state(player)
	local now = os.clock()
	return now - s.lastHurt < Config.IN_COMBAT_SECONDS or now - s.lastDealt < Config.IN_COMBAT_SECONDS
end

--[[ Basic attack ]]

-- Flat direction from `from` to the enemy times `studs`, for a knockback push.
local function pushFrom(from: Vector3, model: Model, studs: number, fallback: Vector3): Vector3
	local offset = (model:GetPivot().Position - from) * Vector3.new(1, 0, 1)
	return (if offset.Magnitude > 0.1 then offset.Unit else fallback) * studs
end

local function damageSwing(player: Player, action: Rules.Action, claimed: { any }, swungAt: number)
	local root = livingRoot(player)
	if not root then
		return
	end

	local class = Config.CLASSES[action.class] or Config.CLASSES.Fist
	local maxTargets = class.maxTargets
	-- claimed enemies, deduplicated and capped
	local targets: { Model } = {}
	local seen: { [Instance]: boolean } = {}
	for index, model in ipairs(claimed) do
		if index > maxTargets * 4 then
			break
		end
		if #targets >= maxTargets then
			break
		end
		if typeof(model) == "Instance" and Hitbox.alive(model) and not seen[model] then
			seen[model] = true
			table.insert(targets, model :: Model)
		end
	end
	if #targets == 0 then
		return
	end

	local cframe, size = Hitbox.box(root, Config.HITBOX_SLACK, action.class)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets :: { any }
	local step = class.steps[action.step]
	if not step then
		return
	end
	local s = state(player)
	local empower = if workspace:GetServerTimeNow() < s.empowerUntil then 1 + s.empower else 1
	local damage = step.damage * Combat.power(player) * Weapons.multiplier(player, action.class) * empower
		* (1 + rootPerk(player, "strike"))
	local studs = step.push or 0
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local landed = false
	local hit: { [Model]: boolean } = {}
	for _, model in Hitbox.enemiesIn(cframe, size, params, root.Position) do
		hit[model] = true
	end
	-- lag compensation: a claimed target that has moved out of the box still
	-- counts if it was in it at the swing's time (rewound at most Config.REWIND)
	local now = workspace:GetServerTimeNow()
	for _, model in targets do
		if not hit[model] and EnemyHistory.wasIn(model, cframe, size, swungAt, now) then
			hit[model] = true
		end
	end
	for _, model in targets do
		if hit[model] then
			landed = true
			Combat.damageEnemy(player, model, damage, pushFrom(root.Position, model, studs, facing.Unit))
		end
	end
	if landed then
		Weapons.addXp(player, action.class, WeaponPacing.XP_HIT)
	end
end

--[[ Techniques ]]

local function enemyParams(): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(characters, p.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	return params
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function enemiesNear(center: Vector3, radius: number): { Model }
	local found = {}
	local box = Vector3.new(radius * 2, 16, radius * 2)
	for _, model in Hitbox.enemiesIn(CFrame.new(center), box, enemyParams(), center) do
		if flatDistance(model:GetPivot().Position, center) <= radius then
			table.insert(found, model)
		end
	end
	return found
end

-- The chain's targets: the aimed (or nearest) enemy in range, then each next
-- nearest unhit enemy within jumpRange of the last.
function Combat.chainTargets(origin: Vector3, aim: Vector3, def: Techniques.Def): { Model }
	local hits: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local first, firstScore = nil, math.huge
	for _, model in enemiesNear(origin, def.range :: number) do
		local offset = model:GetPivot().Position - origin
		local flat = Vector3.new(offset.X, 0, offset.Z)
		-- prefer enemies in front: distance, doubled if behind
		local score = flat.Magnitude * (if flat.Magnitude > 0 and aim:Dot(flat.Unit) < 0 then 2 else 1)
		if score < firstScore then
			first, firstScore = model, score
		end
	end
	local current = first
	while current and #hits < (def.jumps :: number) + 1 do
		table.insert(hits, current)
		seen[current] = true
		local from = current:GetPivot().Position
		local nextOne, best = nil, math.huge
		for _, model in enemiesNear(from, def.jumpRange :: number) do
			local d = flatDistance(model:GetPivot().Position, from)
			if not seen[model] and d < best then
				nextOne, best = model, d
			end
		end
		current = nextOne
	end
	return hits
end

-- Technique XP; a class technique also grants its class's Dao XP.
local function grantXp(player: Player, id: string)
	local data = PlayerData.get(player)
	local owned = data and data.techniques.owned[id]
	local def = Techniques.Defs[id]
	if def and def.weapon ~= "Any" then
		Weapons.addXp(player, def.weapon, WeaponPacing.XP_CAST)
	end
	if not owned or owned.level >= Techniques.MAX_LEVEL then
		return
	end
	local need = Techniques.xpToNext(owned.level)
	if Techniques.bottleneck(owned.level) then
		-- stuck at the tier's top until comprehended (Progression.comprehend)
		if owned.xp < need then
			owned.xp += 1
			if owned.xp >= need then
				Cultivation.notify(player, `{def.name} has reached a bottleneck. Meditate and comprehend it to go further.`)
			end
		end
		return
	end
	owned.xp += 1
	if owned.xp >= need then
		owned.xp -= need
		owned.level += 1
		Cultivation.notify(player, `{Techniques.Defs[id].name} reached level {owned.level}!`)
	end
end

-- Where a lunging caster may be at a hit: their root, pulled back toward the
-- cast's start if it's farther than the lunge, walking and LUNGE_SLACK allow.
local function checkedOrigin(s: State, root: BasePart, def: Techniques.Def, elapsed: number): Vector3
	local here = root.Position
	local offset = (here - s.castOrigin) * Vector3.new(1, 0, 1)
	local allowed = (def.lunge or 0) + Config.LUNGE_SLACK + elapsed * Config.LUNGE_WALK_ALLOWANCE
	if offset.Magnitude <= allowed then
		return here
	end
	return s.castOrigin + offset.Unit * allowed + Vector3.new(0, here.Y - s.castOrigin.Y, 0)
end

-- One strike of a technique's shape from `origin` along `dir`. Returns the
-- chain's targets for chain kinds.
local function strike(player: Player, s: State, def: Techniques.Def, origin: Vector3, dir: Vector3, damage: number): { Model }?
	local slack = Config.AREA_SLACK
	local studs = Knockback.TECHNIQUES[def.id] or 0
	if def.kind == "line" then
		local from = if def.fromStart then s.castOrigin else origin
		local length = (def.length :: number) + slack
		local cframe = CFrame.lookAt(from, from + dir) * CFrame.new(0, 0, -length / 2)
		local size = Vector3.new((def.width :: number) + slack * 2, 12, length)
		for _, model in Hitbox.enemiesIn(cframe, size, enemyParams(), from) do
			Combat.damageEnemy(player, model, damage, dir * studs)
		end
	elseif def.kind == "circle" or (def.kind == "buff" and def.radius and def.damage > 0) then
		local center = origin + dir * (def.offset or 0)
		for _, model in enemiesNear(center, (def.radius :: number) + slack) do
			Combat.damageEnemy(player, model, damage, pushFrom(center, model, studs, dir))
		end
	elseif def.kind == "chain" then
		local chain = Combat.chainTargets(origin, dir, def)
		for _, model in chain do
			Combat.damageEnemy(player, model, damage, pushFrom(origin, model, studs, dir))
		end
		return chain
	elseif def.kind == "zone" then
		local center = origin + dir * (def.offset :: number)
		task.spawn(function()
			local ticks = math.floor((def.seconds :: number) / (def.tick :: number))
			for _ = 1, ticks do
				if player.Parent == nil then
					return
				end
				for _, model in enemiesNear(center, (def.radius :: number) + slack) do
					Combat.damageEnemy(player, model, damage)
				end
				task.wait(def.tick)
			end
		end)
	end
	return nil
end

local function releaseTechnique(player: Player, action: Rules.Action, aim: Vector3)
	local id = action.id :: string
	local def = Techniques.Defs[id]
	local data = PlayerData.get(player)
	local root = livingRoot(player)
	if not (def and data and root and data.techniques.owned[id] and table.find(data.hotbar, id)) then
		return
	end
	local s = state(player)

	local dir = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim == aim then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.01 then
			dir = flat.Unit
		end
	end
	local level = data.techniques.owned[id].level
	local rooted = 1 + Roots.perk(data.root, "technique") + Registry.stat(data, "technique") + Roots.match(data.root, def.element)
	local function damageOf(index: number): number
		local now = workspace:GetServerTimeNow()
		local empower = if now < s.empowerUntil then 1 + s.empower else 1
		local weapon = if def.weapon ~= "Any" then Weapons.multiplier(player, def.weapon) else 1
		return Techniques.hitDamage(def, level, index) * Combat.power(player) * weapon * empower * rooted
	end

	local origin = checkedOrigin(s, root, def, workspace:GetServerTimeNow() - action.started)
	local chain = strike(player, s, def, origin, dir, damageOf(1))
	if def.kind == "buff" then
		local now = workspace:GetServerTimeNow()
		if def.reduction then
			s.ironSkinUntil = now + (def.seconds :: number)
			s.ironSkinReduction = def.reduction
		end
		if def.damageBonus then
			s.empowerUntil, s.empower = now + (def.seconds :: number), def.damageBonus
		end
		if def.attackSpeed then
			s.actions.hasteUntil, s.actions.haste = now + (def.seconds :: number), def.attackSpeed
		end
	end
	-- later hits of a multi-hit skill land at their clip times, from wherever
	-- the (lunging) caster is then, unless the action was cancelled meanwhile
	local hits = def.hits
	if hits and #hits > 1 then
		local speed = action.profile.speed
		for index = 2, #hits do
			task.delay((hits[index].time - hits[1].time) / speed, function()
				local r = livingRoot(player)
				if not r or s.actions.action ~= action or s.suppressed or s.character ~= player.Character then
					return
				end
				local at = checkedOrigin(s, r, def, workspace:GetServerTimeNow() - action.started)
				strike(player, s, def, at, dir, damageOf(index))
			end)
		end
	end

	grantXp(player, id)
	-- the caster already showed it; everyone else sees it now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			effectRemote:FireClient(other, "cast", player, id, origin, dir, level, chain)
		end
	end
end

-- Time advances movement even when the client stops sending inputs. Effects
-- resolve only on ordered hit reports, so a delayed pre-Hit dodge can cancel
-- its cast before the release report instead of racing a server-side timer.
local function advance(player: Player, s: State, now: number)
	local _, humanoid = livingRoot(player)
	if not humanoid then
		Rules.cancel(s.actions, now)
		s.lastDodge, s.ironSkinUntil = -math.huge, 0
		return
	end
	local action = s.actions.action
	local multiplier, busy = Rules.movement(action, now)
	Movement.action(humanoid, multiplier * Guard.move(player), busy)
end

local function reply(player: Player, s: State, sequence: number, accepted: boolean)
	effectRemote:FireClient(player, "action", player.Character, sequence, accepted, s.actions)
end

-- All action messages share one RemoteEvent so a hit report cannot be overtaken
-- by its dodge cancel. Character + sequence reject old respawn callbacks/replays.
function Combat.action(player: Player, message: any)
	if type(message) ~= "table" or message.character ~= player.Character then
		return
	end
	local s = state(player)
	local now = workspace:GetServerTimeNow()
	if message.op == "sync" then
		advance(player, s, now)
		reply(player, s, 0, false)
		return
	end
	if message.op == "guard" then
		-- raised only between actions and while free to act; an action still
		-- running at the client's time `t` refuses the raise
		local t = message.time
		if not validTime(t) then
			t = now
		end
		local root, humanoid = livingRoot(player)
		local free = root ~= nil and humanoid ~= nil and not humanoid.Sit and Rules.phase(s.actions.action, t) == "free" and not PlayerStun.isLocked(player)
		Guard.set(player, message.on == true, t, free, message.seq, message.look)
		return
	end
	if message.op == "guardLook" then
		-- the facing while guarding, a ping fresher than the replicated root
		local t = message.time
		Guard.look(player, message.look, if validTime(t) then t else now)
		return
	end
	local sequence = message.sequence
	if type(sequence) ~= "number" or sequence ~= sequence or sequence % 1 ~= 0 or sequence < 1 or sequence > 2147483647 then
		return
	end
	local action = s.actions.action
	if message.op == "cancel" then
		if action and action.sequence == sequence then
			-- Menus/focus loss may suppress remaining damage, but cannot shorten
			-- commitment or bypass cooldowns by issuing arbitrary cancel messages.
			s.suppressed = true
		end
		return
	end
	local t = message.time
	if not validTime(t) then
		if message.op == "begin" then
			reply(player, s, sequence, false)
		end
		return
	end
	if message.op == "hit" then
		if not action or action.sequence ~= sequence or action.kind == "dodge" or s.released or s.suppressed then
			return
		end
		if t < Rules.hitAt(action) - Config.HIT_TIME_SLACK or t > Rules.stopAt(action) + Config.HIT_TIME_SLACK then
			return
		end
		if action.kind == "basic" and type(message.targets) ~= "table" then
			return
		end
		s.released = true
		if action.kind == "basic" then
			damageSwing(player, action, message.targets, t)
		elseif action.id then
			releaseTechnique(player, action, s.aim)
		end
		return
	end
	if message.op ~= "begin" or sequence <= s.sequence then
		return
	end
	s.sequence = sequence
	-- Evaluate the previous action at the input time: a delayed pre-Hit dodge
	-- must not accidentally release the cast it was cancelling.
	local root, humanoid = livingRoot(player)
	local data = PlayerData.get(player)
	if not root or not humanoid or humanoid.Sit or not data or (Cultivation.meditation and Cultivation.meditation(player)) then
		reply(player, s, sequence, false)
		return
	end
	if action and (t < action.started or (s.released and t < Rules.hitAt(action))) then
		reply(player, s, sequence, false)
		return
	end
	if PlayerStun.isLocked(player) then
		reply(player, s, sequence, false)
		return
	end
	local kind, id = message.kind, message.id
	if kind == "cast" and (type(id) ~= "string" or not data.techniques.owned[id] or not table.find(data.hotbar, id)) then
		reply(player, s, sequence, false)
		return
	end
	local class = Weapons.class(player)
	local castDef = if kind == "cast" then Techniques.Defs[id] else nil
	if castDef and not Techniques.allowed(castDef, class) then
		Cultivation.notify(player, WeaponDefs.requires(castDef.weapon))
		reply(player, s, sequence, false)
		return
	end
	-- techniques spend combat qi (basic attacks, dashes and the guard are free)
	local qiCost = if castDef then Techniques.qiCost(castDef) else 0
	if qiCost > 0 and not CombatQi.has(player, qiCost) then
		CombatQi.deny(player)
		reply(player, s, sequence, false)
		return
	end
	local nextAction = Rules.start(s.actions, kind, id, t, sequence, class)
	if not nextAction then
		reply(player, s, sequence, false)
		return
	end
	CombatQi.spend(player, qiCost)
	s.released, s.suppressed = false, false
	Guard.drop(player, t)
	s.aim = root.CFrame.LookVector
	local aim = message.aim
	if typeof(aim) == "Vector3" then
		local flat = aim * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.01 and flat.Magnitude < math.huge then
			s.aim = flat.Unit
		end
	end
	if kind == "dodge" then
		s.lastDodge, s.perfectUsed = t, false
		s.lastDodgeSequence = sequence
	elseif castDef then
		s.castOrigin = root.Position
		if castDef.iframes and castDef.lunge then
			local window = castDef.lungeWindow or { 0, 0 }
			s.invulnerableUntil = t + window[2] / nextAction.profile.speed + Config.IFRAME_SLACK
		end
	end
	advance(player, s, now)
	reply(player, s, sequence, true)
end

-- Dodge and dash-skill i-frames (the same window Combat.hurt honours).
function Combat.evading(player: Player): boolean
	local s = state(player)
	local now = workspace:GetServerTimeNow()
	local sinceDodge = now - s.lastDodge
	return (sinceDodge >= 0 and sinceDodge <= Config.IFRAME_SECONDS + Config.IFRAME_SLACK) or now < s.invulnerableUntil
end

PlayerStun.shielded = Combat.evading
-- A stagger or stun drops whatever the player was doing and tells their client.
PlayerStun.onLock = function(player: Player)
	local s = state(player)
	Rules.cancel(s.actions, workspace:GetServerTimeNow())
	s.suppressed = true
	Guard.drop(player, workspace:GetServerTimeNow())
	reply(player, s, 0, false)
end

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for player in states do
		advance(player, state(player), now)
	end
end)

function Combat.forget(player: Player)
	states[player] = nil
	Guard.forget(player)
end

Cultivation.inCombat = Combat.inCombat
CombatQi.fighting = Combat.fighting

return Combat
