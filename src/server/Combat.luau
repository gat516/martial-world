--!strict
-- The player's combat kit on the server: basic attack, techniques and dodge, plus
-- the one path all damage takes (to enemies and to players).
--
-- Basic attacks are predicted by the client and checked here. The client swings,
-- casts its hitbox between the animation's "Hit" and "Hit Stop" markers, shows the
-- hit at once, and reports the swing's server-clock timestamp (GetServerTimeNow)
-- plus the enemies it hit. The server:
--   - rejects timestamps too old, from the future, or closer together than the
--     swing cooldown (so spam can't outpace the animation);
--   - works out the chain step itself from the timestamps, so damage can't be
--     inflated by always claiming the finisher;
--   - re-casts the hitbox (GetPartBoundsInBox) at the attacker's current position,
--     grown by HITBOX_SLACK, and only damages claimed enemies that overlap it.
-- Techniques: the client plays the cast at the animation's "Hit" marker and sends
-- its timestamp and aim; the server checks the technique is slotted and off
-- cooldown, then finds what it hits itself from the caster's position.
-- Dodge: the client dashes at once and sends its timestamp; the server grants
-- invulnerability from that moment, and a hit that lands just after the dodge
-- started is a perfect dodge, which takes time off every technique cooldown.
-- Enemies are models tagged "Enemy" with a Humanoid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Combat
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local Cultivation = require(script.Parent.Cultivation)
local PlayerData = require(script.Parent.PlayerData)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

type State = {
	lastSwing: number,
	chainIndex: number,
	lastDodge: number,
	ready: { [string]: number }, -- technique id -> server time it's off cooldown
	ironSkinUntil: number,
	ironSkinReduction: number,
	lastHurt: number,
	lastHurtBy: string,
}
local states: { [Player]: State } = {}

local Combat = {}

-- Set by Enemies: called whenever a player damages an enemy.
Combat.onEnemyDamaged = nil :: ((model: Model, player: Player, amount: number) -> ())?

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = {
			lastSwing = -math.huge,
			chainIndex = 0,
			lastDodge = -math.huge,
			ready = {},
			ironSkinUntil = 0,
			ironSkinReduction = 0,
			lastHurt = -math.huge,
			lastHurtBy = "Unknown",
		}
		states[player] = s
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
function Combat.damageEnemy(player: Player, model: Model, amount: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (humanoid and humanoid.Health > 0) then
		return
	end
	amount = math.floor(amount + 0.5)
	model:SetAttribute("LastHitBy", player.UserId)
	humanoid:TakeDamage(amount)
	effectRemote:FireClient(player, "damage", model:GetPivot().Position, amount)
	Cultivation.markActive(player)
	if Combat.onEnemyDamaged then
		Combat.onEnemyDamaged(model, player, amount)
	end
end

function Combat.power(player: Player): number
	local data = PlayerData.get(player)
	return if data then Cultivation.stage(data).power else 1
end

--[[ Player damage ]]

export type HurtResult = "hit" | "dodged" | "perfect" | "none"

-- Damage a player from an enemy attack or hazard that resolves now. Dodging
-- shortly before negates it; Iron Skin reduces it. `nonLethal` leaves them at 1.
-- `source` names what hit them (an enemy id, "Tribulation"), for death analytics.
function Combat.hurt(player: Player, amount: number, nonLethal: boolean?, source: string?): (HurtResult, number)
	local _, humanoid = livingRoot(player)
	if not humanoid then
		return "none", 0
	end
	local s = state(player)
	local now = workspace:GetServerTimeNow()
	local sinceDodge = now - s.lastDodge
	if sinceDodge >= 0 and sinceDodge <= Config.IFRAME_SECONDS + Config.IFRAME_SLACK then
		if sinceDodge <= Config.PERFECT_WINDOW + Config.IFRAME_SLACK then
			for id, readyAt in s.ready do
				s.ready[id] = readyAt - Config.PERFECT_REFUND
			end
			effectRemote:FireClient(player, "perfect", Config.PERFECT_REFUND)
			return "perfect", 0
		end
		return "dodged", 0
	end
	if now < s.ironSkinUntil then
		amount *= 1 - s.ironSkinReduction
	end
	amount = math.floor(amount + 0.5)
	if nonLethal then
		amount = math.min(amount, math.max(0, humanoid.Health - 1))
	end
	s.lastHurtBy = source or "Unknown"
	humanoid:TakeDamage(amount)
	s.lastHurt = os.clock()
	effectRemote:FireClient(player, "hurt", amount)
	return "hit", amount
end

function Combat.lastHurtBy(player: Player): string
	return state(player).lastHurtBy
end

function Combat.inCombat(player: Player): boolean
	return os.clock() - state(player).lastHurt < Config.IN_COMBAT_SECONDS
end

--[[ Basic attack ]]

function Combat.swing(player: Player, swingTime: any, claimed: any)
	if not validTime(swingTime) or type(claimed) ~= "table" then
		return
	end
	local s = state(player)
	local since = swingTime - s.lastSwing
	if since < Config.SWING_SECONDS * Config.COOLDOWN_SLACK then
		return
	end
	s.chainIndex = if since > Config.CHAIN_RESET then 1 else s.chainIndex % #Config.FIST_DAMAGE + 1
	s.lastSwing = swingTime

	local root = livingRoot(player)
	if not root then
		return
	end

	-- claimed enemies, deduplicated and capped
	local targets: { Model } = {}
	local seen: { [Instance]: boolean } = {}
	for _, model in claimed do
		if #targets >= Config.MAX_TARGETS then
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

	local cframe, size = Hitbox.box(root, Config.HITBOX_SLACK)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets :: { any }
	local damage = Config.FIST_DAMAGE[s.chainIndex] * Combat.power(player)
	for _, model in Hitbox.enemiesIn(cframe, size, params, root.Position) do
		Combat.damageEnemy(player, model, damage)
	end
end

--[[ Dodge ]]

function Combat.dodge(player: Player, dodgeTime: any)
	if not validTime(dodgeTime) then
		return
	end
	local s = state(player)
	if dodgeTime - s.lastDodge < Config.DODGE_COOLDOWN * Config.COOLDOWN_SLACK then
		return
	end
	s.lastDodge = dodgeTime
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

local function grantXp(player: Player, id: string)
	local data = PlayerData.get(player)
	local owned = data and data.techniques.owned[id]
	if not owned or owned.level >= Techniques.MAX_LEVEL then
		return
	end
	owned.xp += 1
	local need = Techniques.xpToNext(owned.level)
	if owned.xp >= need then
		owned.xp -= need
		owned.level += 1
		Cultivation.notify(player, `{Techniques.Defs[id].name} reached level {owned.level}!`)
	end
end

function Combat.cast(player: Player, id: any, castTime: any, aim: any)
	local def = if type(id) == "string" then Techniques.Defs[id] else nil
	local data = PlayerData.get(player)
	if not (def and data and validTime(castTime)) then
		return
	end
	if not table.find(data.techniques.slots, id) or not data.techniques.owned[id] then
		return
	end
	local s = state(player)
	if castTime < (s.ready[id] or -math.huge) - def.cooldown * (1 - Config.COOLDOWN_SLACK) then
		return
	end
	local root = livingRoot(player)
	if not root then
		return
	end
	s.ready[id] = castTime + def.cooldown

	local dir = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim == aim then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if flat.Magnitude > 0.01 then
			dir = flat.Unit
		end
	end
	local origin = root.Position
	local level = data.techniques.owned[id].level
	local damage = Techniques.damage(def, level) * Combat.power(player)
	local slack = Config.AREA_SLACK
	local chain: { Model }? = nil

	if def.kind == "line" then
		local length = (def.length :: number) + slack
		local cframe = CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -length / 2)
		local size = Vector3.new((def.width :: number) + slack * 2, 12, length)
		for _, model in Hitbox.enemiesIn(cframe, size, enemyParams(), origin) do
			Combat.damageEnemy(player, model, damage)
		end
	elseif def.kind == "circle" then
		for _, model in enemiesNear(origin, (def.radius :: number) + slack) do
			Combat.damageEnemy(player, model, damage)
		end
	elseif def.kind == "chain" then
		chain = Combat.chainTargets(origin, dir, def)
		for _, model in chain :: { Model } do
			Combat.damageEnemy(player, model, damage)
		end
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
	elseif def.kind == "buff" then
		s.ironSkinUntil = workspace:GetServerTimeNow() + (def.seconds :: number)
		s.ironSkinReduction = def.reduction :: number
	end

	grantXp(player, id)
	-- the caster already showed it; everyone else sees it now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			effectRemote:FireClient(other, "cast", player, id, origin, dir, chain)
		end
	end
end

function Combat.forget(player: Player)
	states[player] = nil
end

Cultivation.inCombat = Combat.inCombat

return Combat
