--!nocheck
-- Three-Legged Golden Toad: a cultivated bog spirit toad built from Studio parts in the
-- Spirit Wolf B style. Run in Edit mode through execute_luau; it rebuilds
-- ServerStorage._RosterBeasts.GoldenToad (body plus joint attributes and FX attachments),
-- then run rig_golden_toad.luau on it.
--
-- Model space: ground Y=0, faces -Z, left is -X. 9 long (z -4.5..4.5), ~5.5 tall, ~6 wide.
-- Three legs: two big folded hind legs and ONE centred front leg. Gold hide, dull green
-- flanks, a dark warty back, a pale-gold throat sac with a gold core glow, teal eyes.
-- Segments (primary part = segment name): Body (root), Back, Head, Jaw, Tongue, Sac,
-- LidL/R, LegF, FootF, ThighBL/BR, LowerLegBL/BR, FootBL/BR.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("GoldenToad")
local v, tell = B.v, B.tell

local GOLD = Color3.fromHex("D9A441") -- hide
local GREEN = Color3.fromHex("7C8A3E") -- flanks, lids, shins
local WART = Color3.fromHex("3B3A22") -- dark warty back
local PALE = Color3.fromHex("F0D890") -- belly, throat sac
local MOUTH = Color3.fromHex("7A2E3A")
local TONGUE = Color3.fromHex("D05A6A")
local TEAL = Color3.fromHex("2FD6C8") -- eyes
local CORE = Color3.fromHex("FFC93A") -- sac glow
local WARTGLOW = Color3.fromHex("FFB020")
local TOE = Color3.fromHex("B88530")

local function attach(part, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = part.CFrame:PointToObjectSpace(worldPos)
	a.Parent = part
end

-- Body ------------------------------------------------------------------------------------
local BODY_C = v(0, 2.5, 0.8)
local body = B.block("Body", "Body", v(4.4, 2.8, 5.4), BODY_C, GOLD)
B.block("Body", "Belly", v(3.6, 0.5, 5.0), v(0, 1.2, 0.8), PALE)
B.block("Body", "Chest", v(3.4, 1.3, 0.5), v(0, 2.2, -1.95), GOLD)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.block("Body", "Flank" .. side, v(0.4, 2.0, 4.8), v(s * 2.25, 2.35, 1.0), GREEN)
	B.block("Body", "FlankLow" .. side, v(0.3, 0.6, 4.2), v(s * 2.2, 1.45, 1.1), GREEN)
end
B.joint("JointRoot", "HumanoidRootPart", "Body", BODY_C)

-- Back: dark, warty, sways on its own joint --------------------------------------------------
B.block("Back", "Back", v(4.0, 0.9, 4.8), v(0, 4.35, 1.0), WART)
B.block("Back", "BackRidge", v(2.4, 0.3, 4.0), v(0, 4.9, 1.1), WART)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.bevel("Back", "BackBevel" .. side, v(s * 1.7, 4.45, 1.0), 0.6, 0.7, 4.6, s, WART)
end
local warts = {
	{ -1.0, 5.05, 0.2 }, { 0.9, 5.1, 1.6 }, { -0.8, 5.0, 2.6 }, { 1.2, 4.95, -0.3 }, -- glowing tells
}
for i, w in warts do
	tell(B.ball("Back", "WartTell" .. i, 0.55, v(w[1], w[2], w[3]), WARTGLOW))
end
local plain = {
	{ 0.2, 5.2, 0.6, 0.7 }, { -0.3, 5.15, 1.9, 0.6 }, { 1.4, 4.7, 2.3, 0.6 }, { -1.5, 4.75, 1.2, 0.65 },
	{ 1.6, 4.8, 0.4, 0.5 }, { -1.7, 4.7, 2.5, 0.5 }, { 0.3, 5.1, 3.0, 0.55 }, { -0.2, 4.95, -0.9, 0.55 },
}
for i, w in plain do
	B.ball("Back", "Wart" .. i, w[4], v(w[1], w[2], w[3]), WART)
end
B.joint("JointBack", "Body", "Back", v(0, 4.0, -0.8))

-- Head --------------------------------------------------------------------------------------
local HEAD_C = v(0, 3.85, -3.15)
B.block("Head", "Head", v(3.4, 1.3, 2.7), HEAD_C, GOLD)
B.block("Head", "Snout", v(2.8, 0.5, 0.6), v(0, 4.05, -4.5), GOLD)
B.block("Head", "HeadTop", v(3.0, 0.4, 2.2), v(0, 4.5, -3.0), GREEN)
B.block("Head", "MouthRoof", v(2.9, 0.1, 2.4), v(0, 3.22, -3.2), MOUTH)
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.block("Head", "Cheek" .. side, v(0.5, 1.2, 1.8), v(s * 1.8, 3.9, -2.5), GREEN)
	B.block("Head", "Nostril" .. side, v(0.25, 0.12, 0.08), v(s * 0.55, 4.28, -4.8), WART)
	local housing = B.ball("Head", "EyeHousing" .. side, 1.3, v(s * 1.15, 4.75, -2.7), GOLD)
	tell(B.ball("Head", "Eye" .. side, 0.8, v(s * 1.15, 4.75, -3.05), TEAL))
	B.block("Head", "EyeNeck" .. side, v(0.9, 0.5, 0.9), v(s * 1.15, 4.35, -2.7), GOLD)
end
-- lids: a green cap over the top of each eye, hinged at the eye centre
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.block("Lid" .. side, "Lid" .. side, v(1.4, 0.45, 1.3), v(s * 1.15, 5.2, -2.75), GREEN)
	B.joint("JointEye" .. side, "Head", "Lid" .. side, v(s * 1.15, 4.75, -2.7))
end
B.joint("JointHead", "Body", "Head", v(0, 3.5, -1.9))

-- Jaw ---------------------------------------------------------------------------------------
B.block("Jaw", "Jaw", v(3.2, 0.5, 2.5), v(0, 2.95, -3.2), PALE)
B.block("Jaw", "JawMouth", v(2.6, 0.08, 2.1), v(0, 3.2, -3.2), MOUTH)
B.block("Jaw", "JawLip", v(3.3, 0.2, 0.3), v(0, 3.05, -4.45), GOLD)
B.joint("JointJaw", "Head", "Jaw", v(0, 3.1, -2.0))

-- Tongue stub: rests in the mouth, slides along -Z up to 14 studs -------------------------------
local tongue = B.block("Tongue", "Tongue", v(0.7, 0.2, 1.2), v(0, 3.15, -3.3), TONGUE)
local tip = B.ball("Tongue", "TongueTip", 0.6, v(0, 3.15, -3.95), TONGUE)
B.joint("JointTongue", "Head", "Tongue", v(0, 3.15, -3.3))

-- Throat sac: pale gold, gold glow patch; slides out and down as it swells -----------------------
local sac = B.ball("Sac", "Sac", 2.4, v(0, 2.45, -2.75), PALE)
tell(B.ball("Sac", "SacTell", 1.3, v(0, 2.35, -3.3), CORE))
B.joint("JointSac", "Body", "Sac", v(0, 3.0, -2.2))

-- Front leg: one centred column ---------------------------------------------------------------
B.ball("LegF", "LegFHip", 2.0, v(0, 2.3, -0.8), GOLD)
B.limb("LegF", "LegF", v(0, 2.3, -0.8), v(0, 0.75, -1.0), 1.6, 1.6, GOLD, 0.3)
B.ball("LegF", "LegFKnee", 1.5, v(0, 0.8, -1.0), GOLD)
B.joint("JointLegF", "Body", "LegF", v(0, 2.3, -0.8))
B.block("FootF", "FootF", v(2.4, 0.5, 2.2), v(0, 0.25, -1.5), GREEN)
for i, x in { -0.85, 0, 0.85 } do
	B.block("FootF", "ToeF" .. i, v(0.7, 0.4, 0.8), v(x, 0.2, -2.8), TOE)
end
B.joint("JointFootF", "LegF", "FootF", v(0, 0.75, -1.0))

-- Hind legs: thigh forward and out, shin back, foot flat -------------------------------------
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	local hip, knee, ankle = v(s * 1.7, 2.4, 2.3), v(s * 2.2, 1.5, 0.7), v(s * 2.3, 0.72, 3.5)
	B.ball("ThighB" .. side, "HaunchB" .. side, 2.5, hip, GOLD)
	B.limb("ThighB" .. side, "ThighB" .. side, hip, knee, 1.9, 1.9, GOLD, 0.4)
	B.ball("ThighB" .. side, "KneeB" .. side, 1.9, knee, GOLD)
	B.joint("JointLegB" .. side, "Body", "ThighB" .. side, hip)
	B.limb("LowerLegB" .. side, "LowerLegB" .. side, knee, ankle, 1.4, 1.3, GREEN, 0.4)
	B.ball("LowerLegB" .. side, "AnkleB" .. side, 1.3, ankle, GREEN)
	B.joint("JointLowerLegB" .. side, "ThighB" .. side, "LowerLegB" .. side, knee)
	B.block("FootB" .. side, "FootB" .. side, v(1.8, 0.5, 2.6), v(s * 2.3, 0.25, 3.0), GREEN)
	for i, dx in { -0.6, 0, 0.6 } do
		B.block("FootB" .. side, "ToeB" .. side .. i, v(0.5, 0.4, 0.7), v(s * 2.3 + dx, 0.2, 1.5), TOE)
	end
	B.joint("JointFootB" .. side, "LowerLegB" .. side, "FootB" .. side, ankle)
end

-- Attachments ----------------------------------------------------------------------------------
local m = B.model
attach(m.Head, "Mouth", v(0, 3.15, -4.4))
attach(tip, "TongueTip", v(0, 3.15, -3.95))
attach(sac, "SacL_FX", v(0, 2.45, -3.3))
attach(body, "Core", v(0, 2.6, 0.2))
attach(m.FootF, "FootF_FX", v(0, 0, -1.5))
attach(m.FootBL, "FootBL_FX", v(-2.3, 0, 3.0))
attach(m.FootBR, "FootBR_FX", v(2.3, 0, 3.0))

return B.finish()
