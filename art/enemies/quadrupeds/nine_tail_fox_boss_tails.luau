--!nocheck
-- Tail constants of the Nine-Tailed Fox boss (NineTailFoxB), shared by
-- build_nine_tail_fox_boss.luau and rig_nine_tail_fox_boss.luau so the body, the joint pivots
-- and the ExtendMax attributes can't disagree. All distances are final model studs.
local TAIL = {
	root = Vector3.new(0, 8.1, 5.8), -- every tail pivots here (the Tail hub block sits on it)
	spread = 1.15, -- radians from the centre tail to the outer ones
	len = { 7.0, 8.0, 8.0, 8.5 }, -- base, mid, tip, whip sleeve lengths
	dia = { 3.0, 2.5, 2.0, 0.8 },
	restOverlap = { 0.85, 0.85, 0.95 }, -- fraction of mid / tip / whip inside its parent at rest
	fullOverlap = 0.3, -- same fraction at full extension (>= 0.25 required)
}
-- Direction of tail i. Odd tails sit further back (depth), outer tails lean sideways.
function TAIL.dir(i)
	local a = (i - 5) / 4 * TAIL.spread
	return Vector3.new(math.sin(a) * 1.05, math.cos(a) * 0.85 + 0.15, if i % 2 == 1 then 0.7 else 0.35).Unit
end
-- Sleeve start/end distances along the tail axis at rest, measured from TAIL.root, and
-- the extension each telescoping joint can travel.
function TAIL.layout()
	local L, R = TAIL.len, TAIL.restOverlap
	local s = {}
	s.baseS, s.baseE = 0, L[1]
	s.midS = s.baseE - R[1] * L[2]
	s.midE = s.midS + L[2]
	s.tipS = s.midE - R[2] * L[3]
	s.tipE = s.tipS + L[3]
	s.whipS = s.tipE - R[3] * L[4]
	s.whipE = s.whipS + L[4]
	local f = TAIL.fullOverlap
	s.extMid = s.baseE - f * L[2] - s.midS
	s.extTip = s.midE - f * L[3] - s.tipS
	s.extWhip = s.tipE - f * L[4] - s.whipS
	s.restReach = s.whipE
	s.fullReach = s.whipE + s.extMid + s.extTip + s.extWhip
	return s
end

return TAIL
