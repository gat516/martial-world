--!strict
-- Guarding and perfect parries. The client raises and lowers the guard through
-- the Attack remote (op "guard"); Combat.hurt asks `absorb` about every enemy
-- hit that has a source position. Server authority; the owner's client gets the
-- meter (Effect "guardMeter") and everyone sees the outcome (Effect "guard").
--
--   blocked  a hit from the front while the guard is up: CHIP of the damage gets
--            through and the meter drains by its share of max health.
--   parried  the hit lands within PARRY_WINDOW of raising the guard, even if
--            the button was already let go (a tap parries): nothing gets
--            through, some guard comes back and the beast staggers
--            (EnemyService). Raising again within PARRY_RECOVER of the last
--            raise opens no window, so spamming the button never parries.
--   broken   a blocked hit empties the meter: the guard drops, the player
--            staggers (PlayerStun) and the meter comes back at BREAK_REFILL.
--   deflected a chained parry: after a perfect parry, the same attacker's next
--            blows of that assault (Hit.nextIn says one is due) are parried
--            while the guard is up, if each lands within CHAIN_SLACK of when it
--            was due. Only the last blow (no nextIn), the CHAIN_MAX-th, or a
--            chain whose next blow never came (Guard.onChainEnd) staggers the
--            attacker. Any blow of the chain that finds the guard down or comes
--            from behind breaks it and lands as usual.
--
-- Where a blow comes from (`Hit.from`, set by EnemyService): melee from the
-- beast, a dash or leap from where it set off (judged with the wider DASH_DOT,
-- since the beast arrives on top of you), a projectile from where it was fired.
-- Facing is the server's root or the facing the client last reported while
-- guarding (`Guard.look`, within LOOK_FRESH), whichever passes: the root is
-- client-owned anyway, and the report is a ping fresher.
--
-- The Humanoid's `Guarding` attribute mirrors `up`, for other clients' visuals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig = require(ReplicatedStorage.Shared.Config)
local CombatConfig = SharedConfig.Combat
local Config = CombatConfig.GUARD
local GuardRules = require(ReplicatedStorage.Shared.GuardRules)
local PlayerStun = require(script.Parent.PlayerStun)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

export type Result = "parried" | "deflected" | "blocked" | "broken"

-- A guardable enemy blow (Combat.hurt's `guard`).
export type Hit = {
	from: Vector3, -- where the blow comes from
	heavy: boolean?, -- slams, charges and leaps drain more
	dot: number?, -- the front arc for this blow (default FRONT_DOT)
	at: number?, -- the server time it landed, when it was resolved later (RACE_GRACE)
	attacker: Instance?, -- who struck, for chain parries
	nextIn: number?, -- seconds until the attacker's next blow of this assault; nil on its last
	chain: number?, -- filled in by absorb: this parry's place in its chain (1 = the timed one)
}

type Chain = { attacker: Instance, count: number, deadline: number, from: Vector3 }

type State = {
	character: Model?,
	meter: GuardRules.Meter,
	raisedAt: number,
	window: boolean, -- this raise may parry
	seq: number, -- the client's latest guard op, echoed in guardMeter
	look: Vector3?, -- the facing the client last reported while guarding
	lookAt: number,
	chain: Chain?, -- a chain parry waiting for the attacker's next blow
}
local states: { [Player]: State } = {}

local Guard = {}

-- EnemyService: a chain's next blow never came; stagger `attacker` (`chain`
-- blows parried).
Guard.onChainEnd = nil :: ((attacker: Instance, chain: number) -> ())?

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = { character = player.Character, meter = GuardRules.new(), raisedAt = -math.huge, window = false, seq = 0, lookAt = -math.huge }
		states[player] = s
	end
	if s.character ~= player.Character then
		s.character = player.Character
		s.meter = GuardRules.new()
		s.raisedAt, s.window = -math.huge, false
		s.seq, s.look, s.lookAt = 0, nil, -math.huge
		s.chain = nil
	end
	return s
end

local function mirror(player: Player, s: State)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetAttribute("Guarding") ~= s.meter.up then
		humanoid:SetAttribute("Guarding", s.meter.up)
	end
	effectRemote:FireClient(player, "guardMeter", character, s.meter.stored, s.meter.at, s.meter.up, s.seq)
end

local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 and f.Magnitude < math.huge then f.Unit else nil
end

-- Raise (`up`) or lower the guard at the client's time `t`. `allowed` is false
-- while an action runs or the player is staggered or stunned. `seq` numbers the
-- client's ops so it can tell a stale "down" from a refusal; `look` is its facing.
function Guard.set(player: Player, up: boolean, t: number, allowed: boolean, seq: number?, look: Vector3?)
	local s = state(player)
	if type(seq) == "number" and seq == seq and seq > s.seq then
		s.seq = seq
	end
	Guard.look(player, look, t)
	if up and not allowed then
		mirror(player, s) -- tell the client its raise was refused
		return
	end
	if up and not s.meter.up then
		s.window = t - s.raisedAt >= Config.PARRY_RECOVER
		s.raisedAt = t
	end
	GuardRules.setUp(s.meter, up, t)
	mirror(player, s)
end

-- Drop the guard (an action started, the player was locked).
function Guard.drop(player: Player, now: number)
	local s = state(player)
	if s.meter.up then
		GuardRules.setUp(s.meter, false, now)
		mirror(player, s)
	end
end

-- The client's facing while guarding (op "guardLook", and every raise).
function Guard.look(player: Player, look: any, t: number)
	if typeof(look) ~= "Vector3" then
		return
	end
	local unit = flatUnit(look)
	if unit then
		local s = state(player)
		s.look, s.lookAt = unit, t
	end
end

function Guard.up(player: Player): boolean
	return state(player).meter.up
end

-- Walk speed share for Combat's movement update.
function Guard.move(player: Player): number
	return if state(player).meter.up then Config.MOVE else 1
end

-- Seconds an unguarded, guardable hit should wait before it resolves: half the
-- player's ping (at most RACE_GRACE), so a raise already on its way counts. On
-- their screen the telegraph filled at the hit's server time, so a guard pressed
-- then reaches the server half a ping after the hit. Nothing waits while the
-- guard is up.
function Guard.lead(player: Player): number
	if state(player).meter.up then
		return 0
	end
	return math.clamp(player:GetNetworkPing() / 2, 0, Config.RACE_GRACE)
end

-- Whether the player faces `from` within `dot`: by the server's root, or by the
-- facing their client reported within LOOK_FRESH.
local function facing(s: State, root: BasePart, from: Vector3, dot: number, now: number): boolean
	local toward = flatUnit(from - root.Position)
	if not toward then
		return true -- on top of you: no side to judge
	end
	local look = flatUnit(root.CFrame.LookVector)
	if not look or toward:Dot(look) >= dot then
		return true
	end
	local reported = s.look
	return reported ~= nil and math.abs(now - s.lookAt) <= Config.LOOK_FRESH and toward:Dot(reported) >= dot
end

-- Wait for a chain's next blow; if it doesn't land by the deadline the
-- flurry is over: tell everyone (Effect "guard" "chainEnd") and let
-- EnemyService stagger the attacker.
local function awaitNext(player: Player, s: State, chain: Chain)
	task.delay(math.max(chain.deadline - workspace:GetServerTimeNow(), 0) + 0.05, function()
		if states[player] ~= s or s.chain ~= chain then
			return
		end
		s.chain = nil
		effectRemote:FireAllClients("guard", player.Character, "chainEnd", chain.from, chain.count)
		local hook = Guard.onChainEnd
		if hook then
			hook(chain.attacker, chain.count)
		end
	end)
end

-- An enemy hit of `amount` (Hit: where from, how heavy, who) landing at `now`.
-- Returns nil when the guard doesn't take it (down, or hit from behind), else
-- the outcome and the damage that still gets through. A parry fills `hit.chain`.
function Guard.absorb(player: Player, humanoid: Humanoid, root: BasePart, amount: number, hit: Hit, now: number): (Result?, number)
	local s = state(player)
	local from, heavy = hit.from, hit.heavy == true
	local sinceRaise = now - s.raisedAt
	local inWindow = s.window and sinceRaise >= -Config.PARRY_LATE and sinceRaise <= Config.PARRY_WINDOW + CombatConfig.IFRAME_SLACK
	local chain = s.chain
	local chained = chain ~= nil and hit.attacker ~= nil and chain.attacker == hit.attacker and now <= chain.deadline
	if chained then
		s.chain = nil -- this blow continues the chain or breaks it
	end
	if not s.meter.up and not inWindow then
		return nil, amount
	end
	if not facing(s, root, from, hit.dot or Config.FRONT_DOT, now) then
		return nil, amount
	end
	local character = player.Character
	if inWindow or (chained and s.meter.up) then
		local count = if chained and chain then chain.count + 1 else 1
		hit.chain = count
		GuardRules.refund(s.meter, if count == 1 then Config.PARRY_REFUND else Config.CHAIN_REFUND, now)
		mirror(player, s)
		local last = hit.attacker == nil or hit.nextIn == nil or count >= Config.CHAIN_MAX
		if not last then
			local nextChain: Chain = {
				attacker = hit.attacker :: Instance,
				count = count,
				deadline = now + (hit.nextIn :: number) + Config.CHAIN_SLACK,
				from = from,
			}
			s.chain = nextChain
			awaitNext(player, s, nextChain)
		end
		effectRemote:FireAllClients("guard", character, "parried", from, count, last)
		return if last then "parried" else "deflected", 0
	end
	if SharedConfig.TESTBED then
		-- timing aid while tuning: how long before the hit the guard went up
		effectRemote:FireClient(player, "guardEarly", sinceRaise)
	end
	local chip = amount * Config.CHIP
	local left = GuardRules.drain(s.meter, GuardRules.cost(amount, humanoid.MaxHealth, heavy), now)
	if left > 0 then
		mirror(player, s)
		effectRemote:FireAllClients("guard", character, "blocked", from)
		return "blocked", chip
	end
	GuardRules.setUp(s.meter, false, now)
	s.meter.stored, s.meter.at = Config.BREAK_REFILL, now + Config.BREAK_STAGGER + Config.REGEN_DELAY
	mirror(player, s)
	effectRemote:FireAllClients("guard", character, "broken", from)
	PlayerStun.apply(player, "stagger", Config.BREAK_STAGGER)
	return "broken", chip
end

function Guard.forget(player: Player)
	states[player] = nil
end

return Guard
