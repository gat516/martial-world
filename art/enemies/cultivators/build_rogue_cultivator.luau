--!nocheck
-- Rogue Cultivator: a wandering loner in a travel-worn robe and straw rain cape,
-- the wide douli shading his eyes, a gourd at his hip and a jian in hand.
-- Silhouette: the widest hat in the roster, a ragged cape line at the shoulders.
-- Run in Edit mode through execute_luau (loads lib.luau from the art server);
-- rebuilds ServerStorage._RosterCultivators.RogueCultivator.

local BASE = "http://127.0.0.1:8767/cultivators/"
local L = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "lib.luau?" .. os.clock()))()
local v = L.v

-- Tunables ------------------------------------------------------------------------
local ROBE = Color3.fromHex("7A5A3C") -- dusty brown
local ROBE_DARK = Color3.fromHex("54402C")
local UNDER = Color3.fromHex("D6CBB0") -- faded undyed linen
local STRAW = Color3.fromHex("C9A45C")
local STRAW_DARK = Color3.fromHex("9C7A3E")
local SASH = Color3.fromHex("33433E") -- faded teal-black
local SKIN = Color3.fromHex("C99A72") -- weathered
local GOURD = Color3.fromHex("C47E34")
local CORD = Color3.fromHex("8E2E25")
local EYE = Color3.fromHex("3FA9D9") -- sword-intent glint (tell)
local HAT_R = 2.15 -- douli radius
local HAT_H = 0.85
-- ----------------------------------------------------------------------------------

local b = L.begin("RogueCultivator", { skin = SKIN, torso = ROBE, legs = Color3.fromHex("3A2F26") })
L.robe(b, { outer = ROBE, trim = ROBE_DARK, inner = UNDER, sash = SASH, hipLen = 0.6, hem = 0.6,
	sleeveColor = ROBE, cuff = UNDER })
-- a patched knee and a wrapped shin: travel wear
b.block("Left Leg", "Patch", v(0.5, 0.4, 0.05), v(-0.45, 1.15, -0.62), ROBE_DARK, CFrame.Angles(0, 0, 0.15))
b.block("Right Leg", "ShinWrap", v(1.06, 0.4, 1.06), v(0.5, 0.32, 0), UNDER)
b.block("Left Leg", "ShinWrap", v(1.06, 0.4, 1.06), v(-0.5, 0.32, 0), UNDER)

-- straw rain cape (suoyi) over the shoulders: a mantle on the torso, ragged
-- straw fins hanging down the back and sides; the arm parts carry their own tufts
b.block("Torso", "Cape", v(2.3, 0.42, 1.3), v(0, 3.86, 0.03), STRAW)
-- the back of the cape is one keyable panel (joint CapeBack, hinged under the mantle)
-- with a ragged straw hem riding it
local capeBack = b.block("Torso", "CapeBack", v(2.0, 1.0, 0.12), v(0, 3.3, 0.65), STRAW)
b.joint(capeBack, v(0, 3.8, 0.65))
for i, x in { -0.75, -0.25, 0.25, 0.75 } do
	b.ride(b.fin("Torso", "CapeStraw" .. i, v(x, 2.9, 0.66), 0.75 + (i % 2) * 0.25, 0.2, 0.5,
		if i % 2 == 0 then STRAW else STRAW_DARK, math.pi - 0.08), capeBack)
end
for _, s in { -1, 1 } do
	local arm = if s < 0 then "Left Arm" else "Right Arm"
	b.block(arm, "CapeShoulder", v(1.24, 0.42, 1.26), v(s * 1.5, 3.86, 0), STRAW)
	for i, z in { -0.35, 0.1, 0.45 } do
		b.fin(arm, "CapeTuft" .. i, v(s * 2.02, 3.95, z), 0.75 + (i % 2) * 0.2, 0.35, 0.22,
			if i % 2 == 0 then STRAW_DARK else STRAW, math.pi - 0.1, -s * 0.25)
	end
end

-- face: stubble beard, a scowl, glinting eyes under the brim
L.face(b, { eye = EYE, neon = true, brow = Color3.fromHex("2B211A"), scowl = 0.25, eyeTilt = 0.08 })
L.accessory(b, "MessyHair", { color = Color3.fromHex("2B211A") })
-- a drooping moustache rather than a full beard, so the face stays readable
for _, s in { -1, 1 } do
	b.block("Head", "Moustache", v(0.34, 0.1, 0.08), v(s * 0.16, 4.28, -0.6), Color3.fromHex("2B211A"), CFrame.Angles(0, -s * L.FACE_YAW * 0.6, s * -0.35))
end

-- douli: a shallow cone of radial straw wedges, a dark underside, a knob and a
-- chin cord; tipped forward so the brim shades the eyes
local tilt = CFrame.Angles(-0.14, 0, 0)
local hatAt = v(0, 5.0, -0.05)
b.cone("Head", "Douli", hatAt, HAT_R, HAT_H, 14, STRAW, tilt)
b.cyl("Head", "DouliUnder", HAT_R * 2 - 0.05, 0.08, hatAt + v(0, -0.02, 0), STRAW_DARK, tilt)
b.cyl("Head", "DouliBand", 1.5, 0.12, hatAt + v(0, 0.12, -0.02), ROBE_DARK, tilt)
b.ball("Head", "DouliKnob", 0.28, hatAt + v(0, HAT_H + 0.02, -0.12), STRAW_DARK)
for _, s in { -1, 1 } do
	b.block("Head", "ChinCord", v(0.05, 0.9, 0.05), v(s * 0.66, 4.45, 0.05), CORD, CFrame.Angles(0, 0, s * 0.08))
end

-- gourd hanging off the back of the sash on the right
local g = v(0.62, 1.95, 0.78)
-- keyable: joint Gourd swings from where its cord leaves the sash
local gourd = b.ball("Torso", "Gourd", 0.62, g, GOURD)
b.joint(gourd, v(0.45, 2.35, 0.62))
b.ride(b.ball("Torso", "GourdHigh", 0.42, g + v(0, 0.48, 0), GOURD), gourd)
b.ride(b.cyl("Torso", "GourdWaist", 0.24, 0.16, g + v(0, 0.27, 0), CORD), gourd)
b.ride(b.cyl("Torso", "GourdStopper", 0.16, 0.18, g + v(0, 0.74, 0), Color3.fromHex("5A3B22")), gourd)
b.ride(b.limb("Torso", "GourdCord", v(0.45, 2.35, 0.62), g + v(0, 0.6, 0), 0.06, 0.06, CORD), gourd)

L.weapon(b, "Jian", "HiltR")
return L.finish(b, { healthBarY = 3.2 })
