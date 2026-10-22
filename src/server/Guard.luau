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
--
-- The Humanoid's `Guarding` attribute mirrors `up`, for other clients' visuals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig = require(ReplicatedStorage.Shared.Config)
local CombatConfig = SharedConfig.Combat
local Config = CombatConfig.GUARD
local GuardRules = require(ReplicatedStorage.Shared.GuardRules)
local PlayerStun = require(script.Parent.PlayerStun)

local effectRemote = ReplicatedStorage.Remotes.Effect :: RemoteEvent

export type Result = "parried" | "blocked" | "broken"

type State = {
	character: Model?,
	meter: GuardRules.Meter,
	raisedAt: number,
	window: boolean, -- this raise may parry
}
local states: { [Player]: State } = {}

local Guard = {}

local function state(player: Player): State
	local s = states[player]
	if not s then
		s = { character = player.Character, meter = GuardRules.new(), raisedAt = -math.huge, window = false }
		states[player] = s
	end
	if s.character ~= player.Character then
		s.character = player.Character
		s.meter = GuardRules.new()
		s.raisedAt, s.window = -math.huge, false
	end
	return s
end

local function mirror(player: Player, s: State)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetAttribute("Guarding") ~= s.meter.up then
		humanoid:SetAttribute("Guarding", s.meter.up)
	end
	effectRemote:FireClient(player, "guardMeter", character, s.meter.stored, s.meter.at, s.meter.up)
end

-- Raise (`up`) or lower the guard at the client's time `t`. `allowed` is false
-- while an action runs or the player is staggered or stunned.
function Guard.set(player: Player, up: boolean, t: number, allowed: boolean)
	local s = state(player)
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

function Guard.up(player: Player): boolean
	return state(player).meter.up
end

-- Walk speed share for Combat's movement update.
function Guard.move(player: Player): number
	return if state(player).meter.up then Config.MOVE else 1
end

-- An enemy hit of `amount` from `from` landing now. Returns nil when the guard
-- doesn't take it (down, or hit from behind), else the outcome and the damage
-- that still gets through.
function Guard.absorb(player: Player, humanoid: Humanoid, root: BasePart, amount: number, from: Vector3, heavy: boolean, now: number): (Result?, number)
	local s = state(player)
	local sinceRaise = now - s.raisedAt
	local inWindow = s.window and sinceRaise >= 0 and sinceRaise <= Config.PARRY_WINDOW + CombatConfig.IFRAME_SLACK
	if not s.meter.up and not inWindow then
		return nil, amount
	end
	local toward = (from - root.Position) * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if toward.Magnitude > 0.01 and look.Magnitude > 0.01 and toward.Unit:Dot(look.Unit) < Config.FRONT_DOT then
		return nil, amount
	end
	local character = player.Character
	if inWindow then
		GuardRules.refund(s.meter, Config.PARRY_REFUND, now)
		mirror(player, s)
		effectRemote:FireAllClients("guard", character, "parried", from)
		return "parried", 0
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
