--!nocheck
-- Flame Raven: a hovering fire-crow built from Studio parts. Run in Edit mode through
-- execute_luau; it rebuilds ServerStorage._RosterBeasts.FlameRaven (body plus joint
-- attributes), then run rig_flame_raven.luau on it.
--
-- It hovers low: the body sits at about player-head height (Y 5.6) with the talons
-- hanging to Y 3.3, so a grounded player's melee box (root Y 3, 5 studs tall) still
-- reaches the HRP. Wings are spread in a shallow V at rest (the top of a flap), three
-- segments each: UpperWing (shoulder), ForeWing (elbow), WingTip (wrist, the primaries).
-- Fire-red and black, gold beak and legs; the ember primaries, crest and eyes are the
-- tells.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("FlameRaven")
local v, tell = B.v, B.tell

local BLACK = Color3.fromHex("1E1A1E")
local BLACK_HI = Color3.fromHex("332A33")
local RED = Color3.fromHex("B8261C")
local RED_DK = Color3.fromHex("7E1A16")
local GOLD = Color3.fromHex("E0B04A") -- beak and legs
local CLAW = Color3.fromHex("2A2224")
local EMBER = Color3.fromHex("FF7A1F") -- tells: primaries and crest
local EYE = Color3.fromHex("FFD23F")

local TILT = CFrame.Angles(0.3, 0, 0) -- the hovering body rides nose-up

-- A flat feather panel whose leading edge runs a->b and which trails depth toward +Z.
local function panel(seg, name, a, b, depth, thick, color, down)
	local x = (b - a).Unit
	local back = v(0, -(down or 0), 1)
	local z = (back - x * back:Dot(x)).Unit
	local y = z:Cross(x)
	local cf = CFrame.fromMatrix((a + b) / 2 + z * depth / 2, x, y, z)
	return B.add(seg, name, "Part", v((b - a).Magnitude, thick, depth), cf, color)
end

-- A feather from root, len long and w wide, pointing along dir; with an ember tip if tip.
local function feather(seg, name, root, dir, len, w, color, tip)
	local d = dir.Unit
	local cf = CFrame.lookAt(root + d * len / 2, root + d * len, Vector3.yAxis)
	local f = B.add(seg, name, "Part", v(w, 0.12, len), cf, color)
	if tip then
		tell(B.add(seg, name .. "Tip", "Part", v(w + 0.04, 0.14, 0.55), cf * CFrame.new(0, 0, -len / 2 + 0.2), EMBER))
	end
	return f
end

-- Body ----------------------------------------------------------------------------------

local bodyCf = CFrame.new(0, 5.6, 0.1) * TILT
B.on(bodyCf, "Body", "Body", "Part", v(1.7, 1.5, 2.4), CFrame.identity, BLACK)
B.on(bodyCf, "Body", "BodyTop", "Part", v(1.0, 0.35, 2.2), CFrame.new(0, 0.9, 0.05), BLACK_HI)
for _, s in { -1, 1 } do
	B.bevel("Body", "BodyBevel" .. s, v(s * 0.68, 0.9, 0.05), 0.35, 0.35, 2.2, s, BLACK, bodyCf)
end
B.on(bodyCf, "Body", "Breast", "Part", v(1.55, 1.25, 0.6), CFrame.new(0, -0.1, -1.35), RED)
B.on(bodyCf, "Body", "BreastLow", "WedgePart", v(1.45, 0.5, 1.4), CFrame.new(0, -0.95, -0.6) * CFrame.Angles(math.pi, 0, 0), RED_DK)
B.joint("JointRoot", "HumanoidRootPart", "Body", v(0, 5.6, 0.1))
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.block("Body", "Thigh" .. side, v(0.6, 0.75, 0.8), v(s * 0.5, 4.85, 0.4), BLACK)
end

-- Neck and head ---------------------------------------------------------------------------

B.block("Neck", "Neck", v(1.0, 1.05, 1.0), v(0, 6.45, -1.05), BLACK, CFrame.Angles(0.35, 0, 0))
B.block("Neck", "NeckRuff", v(1.25, 0.55, 0.8), v(0, 6.2, -1.2), RED, CFrame.Angles(0.35, 0, 0))
for _, s in { -1, 1 } do
	B.fin("Neck", "RuffFeather" .. s, v(s * 0.5, 6.4, -0.9), 0.55, 0.6, 0.25, BLACK_HI, 1.0, -s * 1.1)
end

local hf = CFrame.new(0, 7.05, -1.6)
B.on(hf, "Skull", "Skull", "Part", v(1.05, 0.95, 1.15), CFrame.identity, BLACK)
B.on(hf, "Skull", "Brow", "Part", v(1.1, 0.18, 0.4), CFrame.new(0, 0.32, -0.45), BLACK_HI)
B.on(hf, "Skull", "Beak", "WedgePart", v(0.5, 0.38, 0.95), CFrame.new(0, -0.02, -1.02), GOLD)
B.on(hf, "Skull", "BeakBase", "Part", v(0.56, 0.3, 0.2), CFrame.new(0, -0.05, -0.62), GOLD)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	-- eyes on the front corners, turned half forward so they read head-on too
	tell(B.on(hf, "Skull", "Eye" .. side, "Part", v(0.1, 0.18, 0.34), CFrame.new(s * 0.5, 0.12, -0.48) * CFrame.Angles(0, s * 0.6, s * 0.3), EYE))
	B.on(hf, "Skull", "Scowl" .. side, "Part", v(0.42, 0.12, 0.3), CFrame.new(s * 0.32, 0.3, -0.55) * CFrame.Angles(0, 0, s * 0.35), BLACK_HI)
end
-- the ember crest: three swept feathers, the middle one glowing
-- its own segment so it can flare up on windup
tell(B.fin("Crest", "Crest", v(0, 0.45, -0.2), 0.9, 0.7, 0.2, EMBER, 1.0, 0, hf))
for _, s in { -1, 1 } do
	B.fin("Crest", "CrestSide" .. s, v(s * 0.28, 0.42, 0.0), 0.7, 0.6, 0.18, RED, 1.15, -s * 0.35, hf)
end
B.on(hf, "Jaw", "Jaw", "WedgePart", v(0.42, 0.2, 0.75), CFrame.new(0, -0.32, -0.9) * CFrame.Angles(0, 0, math.pi), GOLD)
B.joint("JointNeck", "Body", "Neck", v(0, 6.05, -0.75))
B.joint("JointHead", "Neck", "Skull", v(0, 6.85, -1.2))
B.joint("JointCrest", "Skull", "Crest", (hf * CFrame.new(0, 0.45, -0.05)).Position)
B.joint("JointJaw", "Skull", "Jaw", (hf * CFrame.new(0, -0.25, -0.5)).Position)

-- Wings -----------------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local S, E, W, T = v(s * 0.75, 6.15, -0.1), v(s * 2.55, 6.75, 0.1), v(s * 4.05, 7.4, 0.35), v(s * 5.4, 8.0, 0.75)
	local up, fore, tip = "UpperWing" .. side, "ForeWing" .. side, "WingTip" .. side

	B.limb(up, up, S, E, 0.65, 0.4, BLACK, 0.3)
	panel(up, up .. "Covert", S, E, 0.75, 0.16, RED, 0.1)
	panel(up, up .. "Flight", S + v(0, -0.02, 0.5), E + v(0, -0.02, 0.5), 1.5, 0.12, BLACK, 0.25)

	B.limb(fore, fore, E, W, 0.55, 0.36, BLACK, 0.3)
	panel(fore, fore .. "Covert", E, W, 0.65, 0.16, RED, 0.1)
	panel(fore, fore .. "Flight", E + v(0, -0.02, 0.45), W + v(0, -0.02, 0.45), 1.35, 0.12, BLACK, 0.25)
	-- secondaries: the ragged trailing edge
	for i, t in { 0.2, 0.55, 0.9 } do
		local root = E:Lerp(W, t) + v(0, -0.27, 1.5) -- on the flight panel, which drops 0.25 per stud back
		feather(fore, fore .. "Secondary" .. i, root, v(s * 0.15, -0.2, 1), 1.0, 0.45, if i == 2 then RED_DK else BLACK)
	end

	B.limb(tip, tip, W, T, 0.45, 0.32, BLACK, 0.3)
	panel(tip, tip .. "Covert", W, T, 0.5, 0.14, RED, 0.1)
	-- primaries: four fingers fanning from out-forward to back
	for i, a in { 0.15, 0.5, 0.85, 1.2 } do
		local root = W:Lerp(T, 1 - (i - 1) * 0.22) + v(0, -0.03, 0.2)
		local dir = v(s * math.cos(a), 0.4 * math.cos(a) - 0.05, math.sin(a))
		feather(tip, tip .. "Primary" .. i, root, dir, 2.3 - i * 0.2, 0.42, BLACK, true)
	end

	B.joint("JointShoulder" .. side, "Body", up, S)
	B.joint("JointElbow" .. side, up, fore, E)
	B.joint("JointWrist" .. side, fore, tip, W)
end

-- Tail fan --------------------------------------------------------------------------------

local tailRoot = v(0, 5.3, 1.3)
B.block("Tail", "Tail", v(0.9, 0.5, 0.9), tailRoot + v(0, 0, 0.2), BLACK, CFrame.Angles(0.2, 0, 0))
for i, a in { -0.55, -0.27, 0, 0.27, 0.55 } do
	local dir = CFrame.Angles(0, -a, 0) * v(0, -0.28, 1)
	feather("Tail", "TailFeather" .. i, tailRoot + v(a * 0.4, 0.05, 0.4), dir, 2.4 - math.abs(a) * 0.9, 0.5,
		if i % 2 == 0 then RED else BLACK)
end
B.joint("JointTail", "Body", "Tail", tailRoot)

-- Legs and talons -------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local hip, ankle = v(s * 0.45, 4.75, 0.4), v(s * 0.45, 3.85, 0.2)
	local leg, talon = "Leg" .. side, "Talon" .. side
	B.limb(leg, leg, hip, ankle, 0.24, 0.24, GOLD, 0.15)
	B.block(talon, talon, v(0.34, 0.24, 0.34), ankle, GOLD)
	for i, dx in { -0.17, 0, 0.17 } do
		local toeEnd = ankle + v(dx * 1.6, -0.35, -0.42)
		B.limb(talon, talon .. "Toe" .. i, ankle, toeEnd, 0.12, 0.12, GOLD, 0.06)
		B.limb(talon, talon .. "Claw" .. i, toeEnd, toeEnd + v(0, -0.22, 0.05), 0.11, 0.11, CLAW, 0.04)
	end
	B.limb(talon, talon .. "Hallux", ankle, ankle + v(0, -0.3, 0.35), 0.12, 0.12, GOLD, 0.06)
	B.joint("JointLeg" .. (if s < 0 then "BL" else "BR"), "Body", leg, hip)
	B.joint("JointAnkle" .. side, leg, talon, ankle)
end

return B.finish()
