--!strict
-- One timeline and transition policy for prediction and server authority.
-- All times are workspace:GetServerTimeNow(). Cooldowns outlive action cancels.

local Config = require(script.Parent.Config).Combat
local Techniques = require(script.Parent.Techniques)

export type Profile = {
	animation: number,
	speed: number,
	windup: number,
	active: number,
	recovery: number,
	moveMultiplier: number,
	recoveryMoveMultiplier: number,
	dodgeBeforeHit: boolean,
}
export type Action = {
	sequence: number,
	kind: string,
	id: string?,
	step: number,
	started: number,
	profile: Profile,
}
export type State = {
	action: Action?,
	comboIndex: number,
	comboExpires: number,
	comboReady: number,
	dodgeReady: number,
	ready: { [string]: number },
}

local Rules = {}

function Rules.new(): State
	return { action = nil, comboIndex = 0, comboExpires = 0, comboReady = 0, dodgeReady = 0, ready = {} }
end

function Rules.hitAt(action: Action): number
	return action.started + action.profile.windup
end

function Rules.stopAt(action: Action): number
	return Rules.hitAt(action) + action.profile.active
end

function Rules.endAt(action: Action): number
	return Rules.stopAt(action) + action.profile.recovery
end

function Rules.phase(action: Action?, now: number): string
	if not action or now >= Rules.endAt(action) then
		return "free"
	elseif now < Rules.hitAt(action) then
		return "windup"
	elseif now < Rules.stopAt(action) then
		return "active"
	end
	return "recovery"
end

function Rules.canTransition(action: Action?, kind: string, now: number): boolean
	local phase = Rules.phase(action, now)
	if phase == "free" then
		return true
	end
	if not action or action.kind == "dodge" or phase == "active" then
		return false
	end
	if kind == "dodge" then
		return phase == "recovery" or action.profile.dodgeBeforeHit
	end
	-- A technique can replace a basic's recovery. Another M1 waits for recovery.
	return kind == "cast" and action.kind == "basic" and phase == "recovery"
end

function Rules.movement(action: Action?, now: number): (number, boolean)
	local phase = Rules.phase(action, now)
	if not action or phase == "free" then
		return 1, false
	end
	return if phase == "recovery" then action.profile.recoveryMoveMultiplier else action.profile.moveMultiplier, true
end

function Rules.cancel(s: State, now: number)
	local action = s.action
	if action and Rules.phase(action, now) == "windup" then
		if action.kind == "cast" and action.id then
			s.ready[action.id] = math.min(s.ready[action.id] or 0, now + Config.CANCEL_RETRY)
		elseif action.kind == "basic" and action.step == #Config.FIST_STEPS then
			-- A feinted finisher never completed the string.
			s.comboReady = 0
		end
	end
	s.action = nil
	s.comboIndex = 0
	s.comboExpires = 0
end

function Rules.start(s: State, kind: string, id: string?, now: number, sequence: number): Action?
	if not Rules.canTransition(s.action, kind, now) then
		return nil
	end
	local step = 0
	local profile: Profile
	if kind == "basic" then
		if now < s.comboReady then
			return nil
		end
		step = if now > s.comboExpires then 1 else s.comboIndex % #Config.FIST_STEPS + 1
		local def = Config.FIST_STEPS[step]
		profile = {
			animation = step, speed = def.speed,
			windup = def.hit / def.speed, active = (def.hitStop - def.hit) / def.speed,
			recovery = def.recovery, moveMultiplier = Config.ATTACK_MOVE_MULTIPLIER,
			recoveryMoveMultiplier = Config.ATTACK_RECOVERY_MULTIPLIER, dodgeBeforeHit = true,
		}
	elseif kind == "cast" then
		local def = id and Techniques.Defs[id]
		if not def or now < (s.ready[def.id] or 0) then
			return nil
		end
		local source = Config.FIST_STEPS[def.animation]
		local speed = source.hit / def.cast.windup
		profile = {
			animation = def.animation, speed = speed, windup = def.cast.windup,
			active = (source.hitStop - source.hit) / speed, recovery = def.cast.recovery,
			moveMultiplier = def.cast.moveMultiplier, recoveryMoveMultiplier = def.cast.recoveryMoveMultiplier,
			dodgeBeforeHit = def.cast.dodgeBeforeHit,
		}
	elseif kind == "dodge" then
		if now < s.dodgeReady then
			return nil
		end
		profile = {
			animation = 0, speed = 1, windup = 0, active = Config.DODGE_SECONDS,
			recovery = Config.DODGE_RECOVERY, moveMultiplier = 0,
			recoveryMoveMultiplier = 1, dodgeBeforeHit = false,
		}
	else
		return nil
	end
	if Rules.phase(s.action, now) ~= "free" then
		Rules.cancel(s, now)
	end
	local action: Action = { sequence = sequence, kind = kind, id = id, step = step, started = now, profile = profile }
	s.action = action
	if kind == "basic" then
		s.comboIndex = step
		s.comboExpires = Rules.endAt(action) + Config.CHAIN_RESET
		if step == #Config.FIST_STEPS then
			s.comboReady = Rules.stopAt(action) + Config.CHAIN_COOLDOWN
		end
	else
		s.comboIndex, s.comboExpires = 0, 0
		if kind == "cast" and id then
			s.ready[id] = now + Techniques.Defs[id].cooldown
		else
			s.dodgeReady = now + Config.DODGE_COOLDOWN
		end
	end
	return action
end

return Rules
