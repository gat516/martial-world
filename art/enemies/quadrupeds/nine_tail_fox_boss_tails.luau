--!nocheck
-- Tail constants of the Nine-Tailed Fox boss (NineTailFoxB), shared by
-- build_nine_tail_fox_boss.luau, rig_nine_tail_fox_boss.luau and qa_nine_tail_fox_boss.luau so
-- the body, the joint pivots and the ExtendMax attributes can't disagree. Distances are the
-- build script's authored units (2.4x unit space); the rig's ScaleTo makes them x2.13/2.4.
--
-- KINEMATICS (unchanged since the first boss body, and mirrored in
-- src/client/EnemyPoses/NineTailFox.luau): each tail is a chain of four segments on one straight
-- axis TAIL.dir(i) from TAIL.root. `len` / `restOverlap` / `fullOverlap` only place the three
-- sliding joints (Mid at baseE, Tip at midE, Whip at tipE, measured from the root at rest) and
-- fix how far each slides (extMid / extTip / extWhip). They are no longer sleeve sizes.
--
-- LOOK (rebuilt 2026-10-21 after the telescope-tube tails were rejected): nothing is a
-- cylinder. A tail is a slim gold stem (Tail<i>), a slim gold-to-cream neck (Tail<i>Mid) that
-- flares into the fluffy cream brush (Tail<i>Tip), and a thin Neon foxfire lance (Tail<i>Whip)
-- carrying a cream tip spindle and the azure teardrop flame (Tail<i>Flame ball + FlameTip
-- tongue). At rest the brush swallows the stem's end, the neck, the lance and the spindle, so
-- the tail reads gold stem > cream brush > foxfire, like the user's NineTailFox_R. As it
-- extends, the neck slides out from under the stem's tuft and flares into the brush, and the
-- tip spindle and flame run ahead of the brush on the glowing lance (it shows only past about
-- half extension). The brush is the widest piece, so no sleeve rim ever faces the viewer.
-- `geo` below is in REST coordinates: distance along the tail axis from the root with every
-- joint at rest (a part on segment k sits at s + shift_k at extension e, where shift is 0,
-- e*extMid, e*(extMid+extTip), e*(extMid+extTip+extWhip) for stem, neck, brush, lance).
-- qa_nine_tail_fox_boss.luau checks the margins (gaps, buried back ends, hidden-at-rest pieces).
local TAIL = {
	root = Vector3.new(0, 8.1, 5.8), -- every tail pivots here (the Tail hub block sits on it)
	spread = 1.15, -- radians from the centre tail to the outer ones
	len = { 7.0, 8.0, 8.0, 8.5 }, -- kinematic spans: base, mid, tip, whip
	restOverlap = { 0.85, 0.85, 0.95 },
	fullOverlap = 0.3,
	fanBack = Vector3.new(0, -0.57, 0.82), -- the fan's facing (behind the fox); tails are flat-ish across it
}

-- Geometry, rest s coordinates. w = width across the fan (the silhouette seen from behind),
-- h = depth through the fan. "out" is the side away from the fan's centre (TAIL.outer): the
-- brush end, the tip spindle and the flame keep a flat face there and slope in from the inner
-- side, so every tail ends in a flick curling outward. Each inner piece stays inside whatever
-- covers it at rest (stem end, neck and lance inside the brush; the tip spindle inside the
-- brush end).
TAIL.geo = {
	stem = { s0 = 0, s1 = 6.8, w = 1.25, h = 1.25 }, -- gold
	stemFur = { s0 = 3.2, s1 = 7.3, r0 = 0.4, r1 = 0.7, t = 0.9, side = -1 }, -- gold tuft on the inner edge
	neck = { s0 = 2.35, s1 = 8.4, w = 0.85, h = 0.85 }, -- gold-to-cream
	neckFur = { s0 = 3.8, s1 = 8.2, r0 = 0.35, r1 = 0.7, t = 0.8 }, -- both edges; flares into the brush at full extension
	brush = { s0 = 3.4, s1 = 8.2, w = 1.5, h = 1.85 }, -- cream core
	brushFur = { s0 = 4.0, s1 = 8.0, r0 = 0.65, r1 = 1.1, t = 1.2 }, -- fluff on both edges
	brushEnd = { s0 = 8.2, s1 = 10.0 }, -- one wedge: flat on the outer edge, sloping to a point
	lance = { s0 = 3.65, s1 = 8.0, w = 0.3, h = 0.3, off = 0.25 }, -- Neon foxfire core, seen only as the tail stretches;
	-- `off` moves it toward the outer edge, where the brush end keeps its full depth, so its back end stays buried
	spindle = { s0 = 6.6, sm = 7.6, s1 = 9.6, w = 1.1, h = 1.0 }, -- the cream tip tuft (two wedges) the lance carries
	flame = { s = 10.0, d = 1.3, tip = 12.2, tipW = 0.9 }, -- teardrop: ball at s, one tongue flat on the outer edge
}

-- +1 when the tail's across-fan axis (TAIL.frame RightVector) points away from the fan's centre.
function TAIL.outer(i)
	return if i < 5 then -1 else 1
end

-- Direction of tail i. Odd tails sit further back (depth), outer tails lean sideways.
function TAIL.dir(i)
	local a = (i - 5) / 4 * TAIL.spread
	return Vector3.new(math.sin(a) * 1.05, math.cos(a) * 0.85 + 0.15, if i % 2 == 1 then 0.7 else 0.35).Unit
end

-- Frame of tail i at distance s from the root (rest): LookVector = tail direction,
-- RightVector = across the fan (w), UpVector = through the fan (h).
function TAIL.frame(i, s)
	local d = TAIL.dir(i)
	local b = TAIL.fanBack
	local n = (b - d * b:Dot(d)).Unit
	local p = d:Cross(n)
	return CFrame.fromMatrix(TAIL.root + d * s, p, n)
end

-- Joint positions along the axis at rest (from the root) and the slide of each joint.
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
