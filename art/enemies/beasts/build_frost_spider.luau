--!nocheck
-- Frost Spider: a cultivated ice spider (Outer Wastes trapper) built from Studio parts.
-- Run in Edit mode through execute_luau; it rebuilds ServerStorage._RosterBeasts.FrostSpider
-- (body, joint attributes, FX attachments), then run rig_frost_spider.luau on it.
--
-- Model space: ground Y=0, faces -Z, left is -X. ~10 across with the legs out, ~4 tall.
-- Segments (primary part = segment name): Body (cephalothorax, root), Abdomen, FangL/R,
-- PedipalpL/R, and per leg LegXn (hip->knee), KneeXn (knee->ankle), FootXn (ankle->tip),
-- X = L/R, n = 1..4 (1 front). Pale blue-white hide, frost-crystal shards, dark slate joints,
-- an icy-blue core under the abdomen.

local BASE = "http://127.0.0.1:8767/beasts/"
local HttpService = game:GetService("HttpService")
local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau?" .. os.clock()))()("FrostSpider")
local v, tell = B.v, B.tell

local PALE = Color3.fromHex("DCEBFA") -- hide
local ICE = Color3.fromHex("9CCBEF") -- shards, lower legs
local SLATE = Color3.fromHex("3A4556") -- joints, feet, spinneret
local GLOW = Color3.fromHex("3FC8FF") -- tells
local EYE = Color3.fromHex("4FD8FF")
local FOOT_TIP_Y = 0.15 -- foot tip centre height; tuned so the lowest corner just touches Y 0

local function attach(part, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = part.CFrame:PointToObjectSpace(worldPos)
	a.Parent = part
end

-- a chunky crystal shard: a block turned on two axes
local function shard(seg, name, pos, size, rx, rz, color)
	return B.block(seg, name, size, pos, color, CFrame.Angles(rx, 0, rz))
end

-- Cephalothorax ------------------------------------------------------------------------------
local body = B.block("Body", "Body", v(2.8, 1.3, 2.8), v(0, 2.3, -1.0), PALE)
B.block("Body", "BodyTop", v(2.0, 0.4, 2.3), v(0, 3.05, -1.0), ICE)
B.block("Body", "Face", v(2.2, 1.0, 0.4), v(0, 2.3, -2.5), PALE)
B.block("Body", "Pedicel", v(1.3, 1.0, 0.8), v(0, 2.3, 0.5), SLATE)
shard("Body", "ShardC1", v(0, 3.7, -1.4), v(0.7, 1.5, 0.7), 0.15, 0.1, ICE)
shard("Body", "ShardC2", v(-0.8, 3.5, -0.6), v(0.6, 1.2, 0.6), -0.2, -0.3, ICE)
shard("Body", "ShardC3", v(0.8, 3.5, -0.6), v(0.6, 1.2, 0.6), -0.2, 0.3, ICE)
shard("Body", "ShardC4", v(0, 3.5, -2.2), v(0.5, 0.9, 0.5), -0.6, 0, ICE)
B.joint("JointRoot", "HumanoidRootPart", "Body", v(0, 2.3, -0.5))
-- eyes: a cluster across the face, big pair in the middle
local eyes = { { -0.45, 2.75, 0.4 }, { 0.45, 2.75, 0.4 }, { -0.95, 2.6, 0.26 }, { 0.95, 2.6, 0.26 },
	{ -0.3, 2.35, 0.22 }, { 0.3, 2.35, 0.22 } }
for i, e in eyes do
	tell(B.ball("Body", "Eye" .. i, e[3] * 2 + 0.2, v(e[1], e[2], -2.7), EYE))
end

-- Abdomen: lifts and aims for the web shot ------------------------------------------------------
local ABD = v(0, 2.5, 2.0)
local abd = B.block("Abdomen", "Abdomen", v(3.0, 2.0, 3.4), ABD, PALE)
B.block("Abdomen", "AbdBack", v(2.2, 1.2, 0.8), v(0, 2.3, 3.8), PALE)
local spin = B.block("Abdomen", "Spinneret", v(0.9, 0.7, 0.7), v(0, 2.1, 4.35), SLATE)
shard("Abdomen", "ShardA1", v(0, 3.9, 1.5), v(0.8, 1.6, 0.8), 0.2, 0, ICE)
shard("Abdomen", "ShardA2", v(0, 3.7, 2.6), v(0.7, 1.3, 0.7), -0.25, 0, ICE)
shard("Abdomen", "ShardA3", v(-1.1, 3.4, 2.0), v(0.6, 1.2, 0.6), 0, 0.5, ICE)
shard("Abdomen", "ShardA4", v(1.1, 3.4, 2.0), v(0.6, 1.2, 0.6), 0, -0.5, ICE)
shard("Abdomen", "ShardA5", v(0, 3.3, 3.5), v(0.5, 0.9, 0.5), -0.7, 0, ICE)
local veinSpots = { { -0.7, 1.2, 0.3 }, { 0.7, 1.2, -0.3 }, { -0.55, 2.8, 0.2 }, { 0.55, 2.8, -0.2 } }
for i, p in veinSpots do
	tell(B.block("Abdomen", "FrostVeinTell" .. i, v(0.18, 0.06, 1.1), v(p[1], 3.535, p[2] + 0 + (if i > 2 then 0.1 else 0)), GLOW,
		CFrame.Angles(0, p[3], 0)))
end
local core = tell(B.ball("Abdomen", "CoreGlow", 1.2, v(0, 1.55, 2.0), GLOW))
B.joint("JointAbdomen", "Body", "Abdomen", v(0, 2.3, 0.5))

-- Fangs and pedipalps -------------------------------------------------------------------------
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	B.block("Fang" .. side, "Fang" .. side, v(0.6, 0.8, 0.6), v(s * 0.5, 1.85, -2.65), SLATE)
	tell(B.block("Fang" .. side, "FangTell" .. side, v(0.24, 0.8, 0.24), v(s * 0.5, 1.2, -2.7), GLOW,
		CFrame.Angles(0.15, 0, 0)))
	B.joint("JointFang" .. side, "Body", "Fang" .. side, v(s * 0.5, 2.2, -2.5))
	local a, b = v(s * 1.0, 2.0, -2.4), v(s * 1.4, 1.5, -3.5)
	B.limb("Pedipalp" .. side, "Pedipalp" .. side, a, b, 0.5, 0.5, SLATE, 0.2)
	B.ball("Pedipalp" .. side, "PedipalpTip" .. side, 0.7, b, PALE)
	B.joint("JointPedipalp" .. side, "Body", "Pedipalp" .. side, a)
end

-- Legs: tetrapod-ready, hip (Body) -> knee -> ankle -> tip -----------------------------------
local hipZ = { -1.9, -1.0, -0.1, 0.7 }
local reach = { -0.9, -0.35, 0.35, 1.0 } -- how far the leg leans forward (-) or back (+)
local feet = {}
for _, s in { -1, 1 } do
	local side = if s < 0 then "L" else "R"
	for n = 1, 4 do
		local id = side .. n
		local z, d = hipZ[n], reach[n]
		local hip, knee = v(s * 1.3, 2.3, z), v(s * 3.0, 3.5, z + d * 0.9)
		local ankle, tip = v(s * 4.3, 1.2, z + d * 1.8), v(s * 4.8, FOOT_TIP_Y, z + d * 2.2)
		B.limb("Leg" .. id, "Leg" .. id, hip, knee, 0.55, 0.55, PALE, 0.3)
		B.ball("Leg" .. id, "KneeBall" .. id, 0.8, knee, SLATE)
		B.joint("JointLeg" .. id, "Body", "Leg" .. id, hip)
		B.limb("Knee" .. id, "Knee" .. id, knee, ankle, 0.5, 0.5, ICE, 0.3)
		B.ball("Knee" .. id, "AnkleBall" .. id, 0.6, ankle, SLATE)
		B.joint("JointKnee" .. id, "Leg" .. id, "Knee" .. id, knee)
		B.limb("Foot" .. id, "Foot" .. id, ankle, tip, 0.4, 0.4, SLATE, 0)
		B.joint("JointFoot" .. id, "Knee" .. id, "Foot" .. id, ankle)
		feet[id] = { tip.X, tip.Z }
	end
end

-- Attachments -----------------------------------------------------------------------------------
attach(body, "Mouth", v(0, 1.8, -2.8))
attach(spin, "Spinneret", v(0, 2.1, 4.75))
attach(core, "Core", v(0, 1.4, 2.0))
for id, f in feet do
	attach(B.model["Foot" .. id], "Foot" .. id:sub(1, 1) .. id:sub(2) .. "_FX", v(f[1], 0, f[2]))
end

return B.finish()
