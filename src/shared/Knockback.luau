--!strict
-- Knockback and hitstun from player hits on enemies. How far a hit throws an
-- enemy depends on the hit's base push, the player's realm against the beast's
-- (Enemies `realm`), and the beast's weight (Enemies `weight`):
--   distance = base * (playerPower / beastPower) ^ REALM_EXPONENT / weight
-- where power is each realm's Realms.luau `power`. Anything under MIN_DISTANCE
-- doesn't move the beast at all, so a Qi Condensation fist can't shift the
-- Elder Wolf King, Foundation Establishment nudges it, and higher realms throw
-- it further. A hit that moves a beast also staggers it (stops chasing, a
-- flinch pose) unless it was staggered moments ago; a beast winding up or
-- dashing only flinches from a hit of at least ARMOR_BREAK studs, which also
-- cancels that attack.
--
-- Worked examples (fist finisher, base 8):
--   QC1 player vs Spirit Wolf (QC2, weight 1):     ~6 studs
--   QC9 player vs Elder Wolf King (QC9, weight 7): 1.1 -> none
--   FE1 player vs Elder Wolf King:                  ~3.2 studs

local Realms = require(script.Parent.Realms)

local Knockback = {}

Knockback.REALM_EXPONENT = 3 -- how sharply the realm gap scales the push
Knockback.MIN_DISTANCE = 1.5 -- studs; less than this and the beast doesn't budge
Knockback.ARMOR_BREAK = 6 -- studs; a push this big interrupts a windup or dash
Knockback.PUSH_SECONDS = 0.18 -- the push plays out over this long
Knockback.STUN_PER_STUD = 0.06 -- seconds of stagger per stud pushed
Knockback.STUN_MIN = 0.2
Knockback.STUN_MAX = 0.8
Knockback.RESTAGGER = 0.5 -- seconds after a stagger ends before it can stagger again

-- Base push in studs at an even realm match against a weight-1 beast.
Knockback.FIST_STEPS = { 2, 2, 3, 4, 8 } -- by Config.Combat.FIST_STEPS step
Knockback.TECHNIQUES = { -- by technique id; missing = no push
	SwordQiWave = 6,
	PalmStrike = 10,
	LightningTalisman = 1.5,
}

-- Studs a hit pushes the beast, or 0 when it doesn't move it.
function Knockback.distance(base: number, playerPower: number, beast: { realm: { any }, weight: number }): number
	if base <= 0 then
		return 0
	end
	local beastPower = Realms.get(beast.realm[1], beast.realm[2]).power
	local distance = base * (playerPower / beastPower) ^ Knockback.REALM_EXPONENT / beast.weight
	return if distance >= Knockback.MIN_DISTANCE then distance else 0
end

function Knockback.stun(distance: number): number
	return math.clamp(distance * Knockback.STUN_PER_STUD, Knockback.STUN_MIN, Knockback.STUN_MAX)
end

return Knockback
