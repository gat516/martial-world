--!nocheck
-- Thunder Ape (elite brute): a knuckle-walking storm ape built from Studio parts. Run in
-- Edit mode through execute_luau; it rebuilds ServerStorage._RosterBeasts.ThunderApe
-- (body plus joint attributes), then run rig_thunder_ape.luau on it.
--
-- Shape: gorilla proportions pushed further: a shoulder hump higher than a player, huge
-- arms longer than the legs ending in fists planted on the ground, a small low head
-- with a heavy brow, short bowed legs. Storm-grey fur with pale cloud-tuft crests, dark
-- hide on face, chest and hands; the lightning-blue sigil on the chest and the bolts on
-- the forearms are the tells.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("ThunderApe")
local v, tell = B.v, B.tell

local STORM = Color3.fromHex("5A6270")
local STORM_DK = Color3.fromHex("3E4450")
local STORM_HI = Color3.fromHex("8C96A6") -- cloud-tuft crests
local HIDE = Color3.fromHex("2A2D35") -- face, chest, hands, feet
local BONE = Color3.fromHex("EEE9DC")
local MOUTH = Color3.fromHex("6B2A33")
local BOLT = Color3.fromHex("5BD8FF") -- tells

-- A zigzag bolt of n neon dashes on a surface frame, running down its local -Y; m = -1
-- mirrors it, so left and right bolts are mirror images.
local function bolt(seg, name, frame, n, len, w, m)
	m = m or 1
	for i = 1, n do
		local x = (if i % 2 == 1 then -0.12 else 0.12) * m
		tell(B.on(frame, seg, name .. i, "Part", v(w, len, 0.06),
			CFrame.new(x, -(i - 1) * len * 0.8, 0) * CFrame.Angles(0, 0, (if i % 2 == 1 then -0.5 else 0.5) * m), BOLT))
	end
end

-- Hips and chest -------------------------------------------------------------------------

B.block("Hips", "Hips", v(2.6, 1.6, 1.9), v(0, 3.1, 1.5), STORM)
B.block("Hips", "HipsRump", v(2.2, 0.8, 1.2), v(0, 3.95, 1.7), STORM_DK)
B.fin("Hips", "RumpTuft", v(0, 4.3, 1.6), 0.6, 0.9, 0.6, STORM_HI, 0.9)
B.joint("JointRoot", "HumanoidRootPart", "Hips", v(0, 3.1, 1.3))

local cf = CFrame.new(0, 4.85, -0.25) * CFrame.Angles(0.3, 0, 0) -- the torso, front raised
B.on(cf, "Chest", "Chest", "Part", v(3.4, 2.6, 2.8), CFrame.identity, STORM)
B.on(cf, "Chest", "Hump", "Part", v(2.4, 0.9, 2.4), CFrame.new(0, 1.7, 0.1), STORM)
for _, s in { -1, 1 } do
	B.bevel("Chest", "HumpBevel" .. s, v(s * 1.45, 1.7, 0.1), 0.5, 0.9, 2.4, s, STORM, cf)
end
B.on(cf, "Chest", "Belly", "Part", v(2.3, 1.1, 1.6), CFrame.new(0, -1.25, 0.3), STORM_DK)
-- dark hide chest plate with the thunder sigil
local plate = cf * CFrame.new(0, -0.15, -1.45)
B.on(plate, "Chest", "ChestHide", "Part", v(2.5, 1.9, 0.2), CFrame.identity, HIDE)
B.on(plate, "Chest", "ChestRidge", "Part", v(0.12, 1.5, 0.08), CFrame.new(0, -0.1, -0.12), STORM_DK)
bolt("Chest", "ChestBoltL", plate * CFrame.new(-0.92, 0.6, -0.13), 3, 0.5, 0.18, -1) -- beside the low head
bolt("Chest", "ChestBoltR", plate * CFrame.new(0.92, 0.6, -0.13), 3, 0.5, 0.18)
-- cloud tufts along the back: the storm crest
for i, z in { -0.9, 0.0, 0.9 } do
	B.fin("Chest", "Crest" .. i, v(0, 2.15, z), 0.7 - i * 0.06, 0.9, 0.7, STORM_HI, 0.85, 0, cf)
end
for _, s in { -1, 1 } do
	B.fin("Chest", "CrestSide" .. s, v(s * 0.8, 2.0, -0.4), 0.55, 0.8, 0.5, STORM_HI, 0.85, -s * 0.5, cf)
end
B.joint("JointSpine", "Hips", "Chest", v(0, 3.7, 0.6))

-- Head --------------------------------------------------------------------------------------

local hf = CFrame.new(0, 5.45, -2.25)
B.on(hf, "Skull", "Skull", "Part", v(1.5, 1.4, 1.3), CFrame.identity, STORM)
B.on(hf, "Skull", "Face", "Part", v(1.2, 1.0, 0.25), CFrame.new(0, -0.1, -0.7), HIDE)
B.on(hf, "Skull", "Brow", "Part", v(1.65, 0.36, 0.55), CFrame.new(0, 0.48, -0.6), STORM_DK)
B.on(hf, "Skull", "Muzzle", "Part", v(0.95, 0.5, 0.45), CFrame.new(0, -0.42, -0.85), HIDE)
B.fin("Skull", "HeadTuft", v(0, 0.7, 0.1), 0.5, 0.7, 0.5, STORM_HI, 0.9, 0, hf)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	tell(B.on(hf, "Skull", "Eye" .. side, "Part", v(0.38, 0.15, 0.06), CFrame.new(s * 0.3, 0.2, -0.85) * CFrame.Angles(0, 0, s * 0.2), BOLT))
	B.on(hf, "Skull", "Nostril" .. side, "Part", v(0.14, 0.1, 0.06), CFrame.new(s * 0.18, -0.3, -1.08), STORM_DK)
	B.on(hf, "Skull", "Ear" .. side, "Part", v(0.2, 0.42, 0.32), CFrame.new(s * 0.82, 0.05, 0.05), HIDE)
	B.on(hf, "Skull", "Cheek" .. side, "WedgePart", v(0.3, 0.6, 0.7), CFrame.new(s * 0.75, -0.25, -0.2) * CFrame.Angles(0, math.pi, 0), STORM_HI)
	B.fin("Skull", "Canine" .. side, v(s * 0.3, -0.66, -0.98), 0.28, 0.14, 0.12, BONE, math.pi, 0, hf)
end
B.on(hf, "Jaw", "Jaw", "Part", v(1.05, 0.36, 0.85), CFrame.new(0, -0.82, -0.6), HIDE)
B.on(hf, "Jaw", "JawMouth", "Part", v(0.8, 0.06, 0.65), CFrame.new(0, -0.62, -0.62), MOUTH)
B.on(hf, "Jaw", "Beard", "WedgePart", v(1.0, 0.4, 0.6), CFrame.new(0, -1.12, -0.5) * CFrame.Angles(math.pi, 0, 0), STORM_HI)
for _, s in { -1, 1 } do
	B.fin("Jaw", "LowerFang" .. (if s < 0 then "L" else "R"), v(s * 0.3, -0.64, -0.95), 0.22, 0.12, 0.1, BONE, 0, 0, hf)
end
B.joint("JointHead", "Chest", "Skull", v(0, 5.6, -1.6))
B.joint("JointJaw", "Skull", "Jaw", (hf * CFrame.new(0, -0.55, -0.15)).Position)

-- Arms: shoulder, elbow, wrist; fists planted ---------------------------------------------

for _, s in { -1, 1 } do
	local f = if s < 0 then "FL" else "FR"
	local SH, EL, WR = v(s * 2.0, 5.6, -0.8), v(s * 2.45, 3.4, -1.3), v(s * 2.55, 1.25, -1.7)
	local ua, fa, hand = "UpperArm" .. f, "ForeArm" .. f, "Hand" .. f
	B.limb(ua, ua, SH, EL, 1.5, 1.5, STORM, 0.5)
	B.block(ua, ua .. "Deltoid", v(1.9, 1.6, 1.9), SH + v(s * 0.1, 0.1, 0), STORM)
	B.fin(ua, ua .. "Tuft", SH + v(s * 0.8, 0.5, 0.1), 0.6, 0.8, 0.5, STORM_HI, 0.7, -s * 0.9)

	local ff = B.bone(EL, WR, v(0, 0, -1))
	B.limb(fa, fa, EL, WR, 1.75, 1.7, STORM, 0.45, v(0, 0, -1))
	B.fin(fa, fa .. "ElbowTuft", EL + v(s * 0.2, 0.2, 0.75), 0.6, 0.6, 0.6, STORM_HI, 2.3)
	B.on(ff, fa, fa .. "Cuff", "Part", v(1.85, 1.8, 0.45), CFrame.new(0, 0, 0.75), STORM_DK)
	-- the bolt runs down the front of the forearm, facing the prey (ff's +Y is forward)
	bolt(fa, fa .. "Bolt", ff * CFrame.new(0, 0.87, -0.55) * CFrame.Angles(-math.pi / 2, 0, 0), 3, 0.55, 0.2, -s)

	B.block(hand, hand, v(1.5, 1.1, 1.45), v(s * 2.6, 0.55, -1.8), HIDE)
	-- the curled fingers: their own segment, hinged at the knuckle line, to open the fist
	local fingers = "Fingers" .. f
	B.block(fingers, fingers, v(1.55, 0.75, 0.5), v(s * 2.6, 0.38, -2.45), HIDE)
	B.block(fingers, fingers .. "Ridge", v(1.45, 0.14, 0.12), v(s * 2.6, 0.62, -2.72), STORM_DK)
	B.joint("JointFingers" .. f, hand, fingers, v(s * 2.6, 0.75, -2.3))
	B.block(hand, hand .. "Thumb", v(0.4, 0.4, 0.6), v(s * 2.0, 0.3, -2.1), HIDE)
	B.block(hand, hand .. "Wrist", v(1.3, 0.7, 1.2), WR + v(0, -0.15, -0.05), HIDE)

	B.joint("JointLeg" .. f, "Chest", ua, SH)
	B.joint("JointElbow" .. f, ua, fa, EL)
	B.joint("JointWrist" .. f, fa, hand, WR)
end

-- Legs -------------------------------------------------------------------------------------

for _, s in { -1, 1 } do
	local b = if s < 0 then "BL" else "BR"
	local HP, KN, AN = v(s * 1.1, 2.9, 1.7), v(s * 1.4, 1.6, 0.9), v(s * 1.4, 0.55, 1.7)
	local th, sh, ft = "Thigh" .. b, "Shin" .. b, "Foot" .. b
	B.limb(th, th, HP, KN, 1.3, 1.4, STORM, 0.5)
	B.limb(sh, sh, KN, AN, 1.0, 1.0, STORM_DK, 0.4)
	B.block(ft, ft, v(1.1, 0.5, 1.6), v(s * 1.4, 0.25, 1.4), HIDE)
	B.block(ft, ft .. "Toes", v(1.15, 0.3, 0.4), v(s * 1.4, 0.15, 0.5), HIDE)
	B.joint("JointLeg" .. b, "Hips", th, HP)
	B.joint("JointKnee" .. b, th, sh, KN)
	B.joint("JointAnkle" .. b, sh, ft, AN)
end

return B.finish()
