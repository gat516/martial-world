--!strict
-- The guard meter, shared so the client's bar regenerates exactly like the
-- server's. The meter is stored as a value at a time (`at`): before `at` it
-- holds (the regen delay after a drain), after it it refills at REGEN, slower
-- while the guard is held. Rebase whenever `up` changes so the rate applies
-- only from then on. All times are workspace:GetServerTimeNow().

local Config = require(script.Parent.Config).Combat.GUARD

export type Meter = { stored: number, at: number, up: boolean }

local GuardRules = {}

function GuardRules.new(): Meter
	return { stored = 1, at = 0, up = false }
end

function GuardRules.value(m: Meter, now: number): number
	if now <= m.at then
		return m.stored
	end
	local rate = Config.REGEN * (if m.up then Config.GUARDING_REGEN else 1)
	return math.min(1, m.stored + (now - m.at) * rate)
end

-- Raise or lower the guard from `now` on.
function GuardRules.setUp(m: Meter, up: boolean, now: number)
	if m.up == up then
		return
	end
	m.stored = GuardRules.value(m, now)
	m.at = math.max(m.at, now)
	m.up = up
end

-- Take `amount` (0..1) off; returns what's left. Regen waits REGEN_DELAY.
function GuardRules.drain(m: Meter, amount: number, now: number): number
	m.stored = math.max(0, GuardRules.value(m, now) - amount)
	m.at = now + Config.REGEN_DELAY
	return m.stored
end

-- Put `amount` back now, without delaying regen.
function GuardRules.refund(m: Meter, amount: number, now: number)
	local value = GuardRules.value(m, now)
	m.stored = math.min(1, value + amount)
	m.at = math.max(m.at, now)
end

-- How much guard a blocked hit of `amount` damage costs.
function GuardRules.cost(amount: number, maxHealth: number, heavy: boolean): number
	local share = amount / math.max(maxHealth, 1)
	return math.max(Config.MIN_DRAIN, share * Config.DRAIN * (if heavy then Config.HEAVY_DRAIN else 1))
end

return GuardRules
