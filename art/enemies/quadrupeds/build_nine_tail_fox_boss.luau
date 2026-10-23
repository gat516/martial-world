--!nocheck
-- Nine-Tailed Fox BOSS body (template NineTailFoxB): the old roster fox's slim, long-legged
-- shape rebuilt at final size (shoulder ~7.5, head top ~11, nose to hips ~15.3 studs) with nine
-- telescoping tails. Run in Edit mode through execute_luau (art server on :8767, see
-- AGENTS.md); it rebuilds ServerStorage._RosterQuadrupeds.NineTailFoxB (body only), then run
-- rig_nine_tail_fox_boss.luau. Model space: ground Y=0, faces -Z, left side is -X.
-- Coordinates here are authored at 2.4x the pose module's unit space; rig_nine_tail_fox_boss.luau
-- ScaleTo's the rigged model by 2.13/2.4 so the final body is 2.13x (Scale attribute 2.13, the
-- user's NineTailFox_R reference row). EnemyAnimator multiplies pose translations by Scale.
-- Numbers in comments below are pre-scale (x0.8875 for the final body).
--
-- TAILS. Tail i (1 = far left .. 9 = far right) is four segments on one straight axis: the gold
-- stem Tail<i>, the gold-to-cream neck Tail<i>Mid, the cream brush Tail<i>Tip and the Neon
-- foxfire lance Tail<i>Whip (tip spindle, teardrop flame). The neck, brush and lance slide out
-- along the axis to extend the tail; at rest the brush hides everything behind it. Geometry is
-- straight; the S curve is the pose's job. nine_tail_fox_boss_tails.luau holds the numbers and
-- the look (the rig derives the joints and ExtendMax from them).

local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local P = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/parts_lib.luau?" .. os.clock()))()("NineTailFoxB")
local v, block, ball, cyl, limb, fin, tri, bevel, tell, add =
	P.v, P.block, P.ball, P.cyl, P.limb, P.fin, P.tri, P.bevel, P.tell, P.add

-- Tunables ------------------------------------------------------------------------------
local CREAM = Color3.fromHex("F2E9D8")
local CREAM_SH = Color3.fromHex("D5C8AC")
local GOLD = Color3.fromHex("D9A441")
local GOLD_MID = Color3.fromHex("E8C984") -- gold fading to cream (tail middle sleeves)
local GOLD_DK = Color3.fromHex("8A5E24") -- paws
local INK = Color3.fromHex("2A2430") -- stockings, ear backs, nose, eyeliner
local EAR_IN = Color3.fromHex("D98C9C")
local FOXFIRE = Color3.fromHex("7FD8FF") -- the eye / chest tell colour (vfx recolours by phase)
local TAILFIRE = Color3.fromHex("3C93E6") -- the tail flames and lances: saturated azure (pale tints bloom to white)

local TAIL = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/nine_tail_fox_boss_tails.luau?" .. os.clock()))()

-- Torso: slim, a slightly heavier chest, gold saddle down the back -------------------------
block("Chest", "Chest", v(4.2, 3.2, 5.6), v(0, 5.9, -1.6), CREAM)
block("Chest", "ChestTop", v(2.4, 0.8, 5.4), v(0, 7.4, -1.6), GOLD)
block("Chest", "ChestBelly", v(3.0, 0.7, 4.4), v(0, 4.4, -1.5), CREAM_SH)
for _, s in { -1, 1 } do
	bevel("Chest", "ChestShoulder" .. s, v(s * 1.4, 7.45, -1.6), 0.7, 0.9, 5.2, s, GOLD)
end
block("Hips", "Hips", v(3.4, 2.9, 4.4), v(0, 5.9, 2.7), CREAM)
block("Hips", "HipsTop", v(2.0, 0.8, 4.2), v(0, 7.3, 2.7), GOLD)
for _, s in { -1, 1 } do
	bevel("Hips", "HipsShoulder" .. s, v(s * 1.15, 7.35, 2.7), 0.6, 0.8, 4.0, s, GOLD)
end
-- the chest crescent: a neon disc with a cream disc over its upper part
tell(cyl("Chest", "ChestMark", v(0, 5.0, -4.44), v(0, 5.0, -4.56), 1.5, FOXFIRE))
cyl("Chest", "ChestMarkCover", v(0, 5.32, -4.5), v(0, 5.32, -4.62), 1.5, CREAM)

-- Neck and ruff: a long neck held high, a fine cream ruff at its base ---------------------
limb("Neck", "Neck", v(0, 7.0, -3.4), v(0, 8.7, -5.3), 2.0, 2.2, CREAM, 0.9)
block("Neck", "Ruff", v(3.4, 2.4, 1.8), v(0, 7.0, -4.0), CREAM)
for _, s in { -1, 1 } do
	fin("Neck", "RuffTuftHi" .. s, v(s * 1.7, 6.5, -4.0), 1.5, 1.2, 0.45, CREAM, math.pi - 0.3, s * 0.35)
	fin("Neck", "RuffTuftLo" .. s, v(s * 1.2, 5.9, -4.3), 1.2, 1.0, 0.4, CREAM, math.pi - 0.4, s * 0.25)
end

-- Head: narrow wedge skull, long snout with the half-smile, big upright ears ---------------
block("Head", "Head", v(2.7, 2.2, 2.6), v(0, 9.0, -6.2), CREAM)
add("Head", "Brow", "WedgePart", v(2.3, 0.6, 1.3), CFrame.new(0, 10.35, -6.4), GOLD)
block("Head", "Snout", v(1.3, 1.1, 2.7), v(0, 8.5, -8.7), CREAM)
add("Head", "SnoutTop", "WedgePart", v(1.0, 0.6, 2.4), CFrame.new(0, 9.2, -8.5), GOLD)
block("Head", "Nose", v(0.75, 0.5, 0.45), v(0, 8.8, -10.2), INK)
tell(block("Head", "BrowMark", v(0.5, 0.5, 0.1), v(0, 9.9, -7.53), FOXFIRE, CFrame.Angles(0, 0, math.pi / 4)))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- sly eyes: narrow, outer corner swept up, lined dark, wrapping the front corner
	block("Head", "Liner" .. side, v(1.0, 0.34, 0.1), v(s * 0.92, 9.3, -7.505), INK, CFrame.Angles(0, 0, s * 0.4))
	tell(block("Head", "Eye" .. side, v(0.78, 0.2, 0.1), v(s * 0.94, 9.3, -7.535), FOXFIRE, CFrame.Angles(0, 0, s * 0.4)))
	-- the smile: a dark line up the snout side, plus a cream cheek ruff
	block("Head", "Smile" .. side, v(0.1, 0.14, 1.7), v(s * 0.68, 8.3, -8.6), INK, CFrame.Angles(-0.2, 0, 0))
	block("Head", "Cheek" .. side, v(0.6, 1.3, 1.6), v(s * 1.45, 8.5, -6.0), CREAM, CFrame.Angles(0, 0, s * 0.25))
	tri("Ear" .. side, "Ear" .. side, v(s * 0.95, 9.95, -5.8), 1.6, 1.3, 0.3, CREAM, CFrame.Angles(-0.12, 0, -s * 0.22))
	tri("Ear" .. side, "Ear" .. side .. "Inner", v(s * 0.95, 10.0, -5.95), 1.1, 0.8, 0.1, EAR_IN, CFrame.Angles(-0.12, 0, -s * 0.22))
	tri("Ear" .. side, "Ear" .. side .. "Back", v(s * 0.95, 9.95, -5.62), 1.6, 1.3, 0.12, INK, CFrame.Angles(-0.12, 0, -s * 0.22))
end
block("Jaw", "Jaw", v(1.0, 0.45, 2.3), v(0, 7.85, -8.6), CREAM_SH)
block("Jaw", "Chin", v(1.5, 0.6, 1.2), v(0, 7.95, -7.2), CREAM_SH)

-- Legs: long and slender, cream thighs, ink stockings, gold-brown paws ----------------------
for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local x, z = s * 1.1, -3.0
	block("UpperLeg" .. f, "UpperLeg" .. f, v(1.2, 3.0, 1.4), v(x, 5.0, z), CREAM)
	ball("UpperLeg" .. f, "Shoulder" .. f, 1.6, v(x, 6.3, z), CREAM)
	block("LowerLeg" .. f, "LowerLeg" .. f, v(0.8, 3.1, 0.95), v(x, 2.3, z), INK)
	ball("LowerLeg" .. f, "Elbow" .. f, 1.1, v(x, 3.7, z), INK)
	block("Paw" .. f, "Paw" .. f, v(1.1, 0.8, 1.6), v(x, 0.4, z - 0.3), GOLD_DK)

	local b = if s < 0 then "BL" else "BR"
	x = s * 1.15
	local knee, hock, ankle = v(x, 3.7, 3.4), v(x, 1.6, 4.5), v(x, 0.6, 4.3)
	block("UpperLeg" .. b, "UpperLeg" .. b, v(1.6, 3.0, 2.1), v(x, 5.4, 3.9), CREAM)
	limb("LowerLeg" .. b, "LowerLeg" .. b, knee, hock, 0.85, 0.95, INK, 0.6)
	ball("LowerLeg" .. b, "Knee" .. b, 1.2, knee, CREAM)
	limb("Paw" .. b, "Paw" .. b, hock, ankle, 0.8, 0.85, GOLD_DK, 0.35)
	ball("Paw" .. b, "Hock" .. b, 0.9, hock, INK)
	block("Paw" .. b, "Foot" .. b, v(1.1, 0.7, 1.6), v(x, 0.35, 4.0), GOLD_DK)
end

-- Nine extending fox tails (layout and look: nine_tail_fox_boss_tails.luau) ---------------
block("Tail", "Tail", v(2.6, 2.4, 3.0), TAIL.root + v(0, -0.4, -0.6), GOLD)
local lay = TAIL.layout()
local G = TAIL.geo
for i = 1, 9 do
	local n = "Tail" .. i
	local function frame(s)
		return TAIL.frame(i, s)
	end
	-- a box along the axis from s0 to s1, w across the fan, h through it
	local function box(seg, name, s0, s1, w, h, color)
		return add(seg, name, "Part", v(w, h, s1 - s0), frame((s0 + s1) / 2), color)
	end
	local out = TAIL.outer(i)
	-- a fur tuft on side `side` (+1 / -1 across the fan): its foot is buried at r0 from the axis,
	-- its slope rises to r1 at s1, where its tall face looks toward the tip
	local function tuft(seg, name, f, side, color)
		local fr = frame((f.s0 + f.s1) / 2)
		local o = fr.RightVector * side
		local h = f.r1 - f.r0
		local c = fr.Position + o * (f.r0 + h / 2)
		return add(seg, name, "WedgePart", v(f.t, h, f.s1 - f.s0), CFrame.fromMatrix(c, o:Cross(fr.LookVector), o), color)
	end
	-- a wedge on the axis from s0 to s1, w across and h through the fan: its flat face lies on
	-- the outer edge, its full-height face at s0 (tallAtStart) or s1, the slope on the inner side
	local function lean(seg, name, s0, s1, w, h, tallAtStart, color)
		local fr = frame((s0 + s1) / 2)
		local y = -fr.RightVector * out -- from the flat (outer) face toward the slope
		local z = if tallAtStart then -fr.LookVector else fr.LookVector
		return add(seg, name, "WedgePart", v(h, w, s1 - s0), CFrame.fromMatrix(fr.Position, y:Cross(z), y), color)
	end

	-- gold stem, one tuft on its inner edge sweeping toward the tip
	box(n, n, G.stem.s0, G.stem.s1, G.stem.w, G.stem.h, GOLD)
	tuft(n, n .. "FurA", G.stemFur, G.stemFur.side * out, GOLD)
	-- the neck: slim, gold fading to cream, flaring into the brush on both edges
	box(n .. "Mid", n .. "Mid", G.neck.s0, G.neck.s1, G.neck.w, G.neck.h, GOLD_MID)
	tuft(n .. "Mid", n .. "MidFurA", G.neckFur, out, GOLD_MID)
	tuft(n .. "Mid", n .. "MidFurB", G.neckFur, -out, GOLD_MID)
	-- the brush: cream core, fluff on both edges, its end flicking outward to a point
	box(n .. "Tip", n .. "Tip", G.brush.s0, G.brush.s1, G.brush.w, G.brush.h, CREAM)
	tuft(n .. "Tip", n .. "FurC", G.brushFur, out, CREAM)
	tuft(n .. "Tip", n .. "FurD", G.brushFur, -out, CREAM)
	lean(n .. "Tip", n .. "TipEnd", G.brushEnd.s0, G.brushEnd.s1, G.brush.w, G.brush.h, true, CREAM)
	-- the lance: a Neon foxfire core hidden in the brush at rest, bared as the tail stretches;
	-- it carries the cream tip spindle and the teardrop flame
	local lance = tell(box(n .. "Whip", n .. "Whip", G.lance.s0, G.lance.s1, G.lance.w, G.lance.h, TAILFIRE))
	lance.CFrame += lance.CFrame.RightVector * (out * G.lance.off)
	lance:SetAttribute("TailIndex", i)
	local sp = G.spindle
	lean(n .. "Whip", n .. "WhipFurA", sp.s0, sp.sm, sp.w, sp.h, false, CREAM)
	lean(n .. "Whip", n .. "WhipFurB", sp.sm, sp.s1, sp.w, sp.h, true, CREAM)
	local flame = tell(ball(n .. "Whip", n .. "Flame", G.flame.d, frame(G.flame.s).Position, TAILFIRE))
	flame:SetAttribute("TailIndex", i)
	tell(lean(n .. "Whip", n .. "FlameTip", G.flame.s, G.flame.tip, G.flame.tipW, G.flame.tipW, true, TAILFIRE)):SetAttribute("TailIndex", i)
end

for _, p in P.model:GetChildren() do
	if p:GetAttribute("Tell") then
		p:SetAttribute("TellBase", p.Color)
	end
end

return P.place("_RosterQuadrupeds") .. (" | tails rest reach %.2f, full %.2f"):format(lay.restReach, lay.fullReach)
