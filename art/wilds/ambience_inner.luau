--!nocheck
-- Ambient effects and sounds for the Inner Wilds valley (docs/systems/map.md, "Inner Wilds rework";
-- templates: ServerStorage.AmbientFX, docs/systems/world.md "Inner Wilds set" and "Ambient sound").
-- Run in Studio Edit mode through execute_luau after place_pockets_inner.luau and water_inner.luau.
-- Rebuilds Map.Ground.WildsInner.FX each run (never name anything "Ambience" under Map: DayNight takes
-- the first one) and re-dresses the pocket prefabs' FX_/SND_ anchors.
--
-- Effects: every AmbientFX clone's emitter Rate is scaled by placed area / authored area.
-- Sounds: anchors tagged AmbientSound with attribute Sound = template name (only the 10 nearest play,
-- so they're spread, not crowded). The prefabs' SND_*Anchor parts get tagged in place.

local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local AF = SS.AmbientFX
local terrain = workspace.Terrain
local ground = workspace.Map.Ground.WildsInner
local pockets = ground:FindFirstChild("Pockets")

local old = ground:FindFirstChild("FX")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "FX"
root.Parent = ground
local sounds = Instance.new("Folder")
sounds.Name = "Sounds"
sounds.Parent = root

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end

local function scaleRate(inst, factor)
	for _, e in inst:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.Rate *= factor
		end
	end
end
-- clone an AmbientFX part template, size and place it, scale rates (by area unless `factor`)
local function fx(template, name, cf, size, factor, parent)
	local t = AF:FindFirstChild(template)
	if not t then
		warn("AmbientFX missing " .. template)
		return nil
	end
	local c = t:Clone()
	c.Name = name
	if size then
		c.Size = size
	end
	c.CFrame = cf
	scaleRate(c, factor or (c.Size.X * c.Size.Z) / (t.Size.X * t.Size.Z))
	c.Parent = parent or root
	return c
end
local soundCount = 0
local function sound(name, template, pos, extra)
	local p = Instance.new("Part")
	p.Name = "SFX_" .. name
	p.Size = Vector3.new(1, 1, 1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(pos)
	p:SetAttribute("Sound", template)
	for k, v in extra or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = sounds
	CollectionService:AddTag(p, "AmbientSound")
	soundCount += 1
	return p
end
local function flatAt(anchor, lift)
	local _, yaw = anchor.CFrame:ToOrientation()
	return CFrame.new(anchor.Position + Vector3.new(0, lift or 0, 0)) * CFrame.Angles(0, yaw, 0)
end

local report = {}

-- 1. the pocket and find prefabs' anchors
local FX_FOR = { -- anchor base name -> function(anchor, pocket)
	FX_DenMist = function(a)
		return fx("DenMist", "FX_DenMist", flatAt(a, 3), Vector3.new(40, 2, 40), nil, a)
	end,
	FX_Fireflies = function(a)
		fx("SpiritMotes", "FX_Fireflies", flatAt(a, 3), Vector3.new(20, 6, 20), nil, a)
		return fx("Fireflies", "FX_FirefliesNight", flatAt(a, 3), Vector3.new(20, 5, 20), nil, a)
	end,
	FX_LanternFlicker = function(a)
		return fx("LanternGlow", "FX_LanternGlow", a.CFrame, nil, 1, a)
	end,
	FX_FallSpray = function(a, pocket)
		fx("WaterfallSpray", "FX_FallSpray", flatAt(a, 0.2), nil, 1, a)
		if pocket.Name == "TwinJadeSpring" and a.Name:find("_1") then
			fx("PlungeBillow", "FX_FallSpray_Billow", flatAt(a, 1), Vector3.new(16, 2, 8), 1, a)
		end
	end,
	FX_FallMist = function(a)
		return fx("WaterfallMist", "FX_FallMist", a.CFrame * CFrame.new(0, 12, 0), Vector3.new(16, 30, 3), 2.6 * (16 * 30) / (20 * 38), a)
	end,
	FX_QiSpring = function(a)
		return fx("QiSpring", "FX_QiSpring", flatAt(a, 0.3), Vector3.new(24, 1, 24), nil, a)
	end,
	FX_QiMotes = function(a)
		return fx("SpiritMotes", "FX_QiMotes", flatAt(a, 2), Vector3.new(10, 6, 10), nil, a)
	end,
	FX_ShrineIncense = function(a)
		return fx("ShrineIncense", "FX_ShrineIncense", a.CFrame, nil, 1, a)
	end,
	FX_GullyMist = function(a)
		return fx("MistWisps", "FX_GullyMist", flatAt(a, 2), Vector3.new(40, 8, 20), nil, a)
	end,
	FX_LotusMist = function(a, pocket)
		local water = pocket:FindFirstChild("Water", true)
		local y = water and (water.Position.Y + water.Size.X / 2 + 0.1) or a.Position.Y
		return fx("LotusMere", "FX_LotusMere", CFrame.new(a.Position.X, y, a.Position.Z), Vector3.new(50, 0.2, 50), nil, a)
	end,
	FX_Campfire = function(a)
		return fx("BrazierGlow", "FX_Campfire", a.CFrame, nil, 1, a)
	end,
	FX_IncenseSmoke = function(a)
		return fx("ShrineIncense", "FX_IncenseSmoke", a.CFrame, nil, 1, a)
	end,
	FX_VistaMist = function(a)
		return fx("MistWisps", "FX_VistaMist", flatAt(a, 0), Vector3.new(40, 8, 20), nil, a)
	end,
	FX_KilnSmoke = function(a)
		return fx("BrazierGlow", "FX_KilnSmoke", a.CFrame, nil, 1, a)
	end,
	FX_HutSmoke = function(a)
		return fx("BrazierGlow", "FX_HutSmoke", a.CFrame, nil, 0.6, a)
	end,
	-- small glows (herbs, steles, glyphs, the sword, a qi core): a few spirit motes
	FX_HerbGlow = function(a)
		return fx("SpiritMotes", "FX_HerbGlow", flatAt(a, 1), Vector3.new(8, 3, 8), nil, a)
	end,
	FX_HerbScent = function(a)
		return fx("SpiritMotes", "FX_HerbScent", flatAt(a, 1), Vector3.new(8, 3, 8), nil, a)
	end,
	FX_SteleGlow = function(a)
		return fx("SpiritMotes", "FX_SteleGlow", flatAt(a, 1), Vector3.new(8, 6, 8), nil, a)
	end,
	FX_GlyphGlow = function(a)
		return fx("SpiritMotes", "FX_GlyphGlow", flatAt(a, 1), Vector3.new(8, 6, 8), nil, a)
	end,
	FX_SwordAura = function(a)
		return fx("SpiritMotes", "FX_SwordAura", flatAt(a, 0), Vector3.new(6, 8, 6), nil, a)
	end,
	FX_CoreGlow = function(a)
		return fx("SpiritMotes", "FX_CoreGlow", flatAt(a, 0), Vector3.new(6, 6, 6), nil, a)
	end,
}
local SOUND_FOR = { -- prefab SND_ anchor base name -> template (nil: left untagged)
	SND_DenGrowl = "DenWind",
	SND_Crows = "DayBirds",
	SND_BambooWind = "BambooGrove",
	SND_Trickle = "WaterfallTrickle",
	SND_Birds = "DayBirds",
	SND_Shrine = "ShrineBells",
	SND_Waterfall = "WaterfallHero",
	SND_Campfire = "Campfire",
	SND_Stove = "Campfire",
	SND_WindChime = "ShrineBells",
	SND_Frogs = "MereFrogs",
	SND_WaterLap = "PoolLap",
	SND_Brazier = "Campfire",
	SND_RiverNear = "Stream",
	SND_KilnCrackle = "Campfire",
	SND_Chime = "ShrineBells",
	SND_WellDrip = "PoolLap",
	SND_CaveDrip = "PoolLap",
}
local QUIET = { SND_WellDrip = 0.4, SND_CaveDrip = 0.4, SND_Stove = 0.5, SND_Brazier = 0.5, SND_KilnCrackle = 0.6 }
local dressed, tagged = 0, 0
local placedSets = {}
for _, n in { "Pockets", "Finds" } do
	local f = ground:FindFirstChild(n)
	if f then
		for _, c in f:GetChildren() do
			table.insert(placedSets, c)
		end
	end
end
do
	for _, pocket in placedSets do
		for _, a in pocket:GetDescendants() do
			if a:IsA("BasePart") and a.Name:sub(-6) == "Anchor" then
				-- an earlier run's clones sit inside the anchor
				for _, c in a:GetChildren() do
					if c:IsA("BasePart") and c.Name:sub(1, 3) == "FX_" then
						c:Destroy()
					end
				end
				local base = a.Name:sub(1, -7):gsub("_%d+$", "")
				if FX_FOR[base] then
					FX_FOR[base](a, pocket)
					dressed += 1
				elseif SOUND_FOR[base] then
					a:SetAttribute("Sound", SOUND_FOR[base])
					if QUIET[base] then
						a:SetAttribute("Volume", QUIET[base])
					end
					CollectionService:AddTag(a, "AmbientSound")
					tagged += 1
				end
			end
		end
	end
end
table.insert(report, string.format("prefab anchors: %d FX dressed, %d sounds tagged", dressed, tagged))

-- 2. effects outside the prefabs
do
	-- the Wolf Den ring: cold mist on the boss floor (the den prefab has its own at the cave)
	local g = gy(-580, 780)
	fx("DenMist", "FX_DenMist_Ring", CFrame.lookAt(Vector3.new(-580, g + 3, 780), Vector3.new(-570, g + 3, 780)), Vector3.new(40, 2, 40))
	-- the Bamboo Sea: slanted light under the canopy, ~15 deg toward the sun
	local sun = game:GetService("Lighting"):GetSunDirection()
	local flat = Vector3.new(sun.X, 0, sun.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(1, 0, 0)
	local tilt = CFrame.fromAxisAngle(Vector3.yAxis:Cross(flat), math.rad(15))
	for i, p in { { -400, 640 }, { -300, 650 }, { -220, 668 } } do
		fx("BambooLight", "FX_BambooLight" .. i, CFrame.new(p[1], gy(p[1], p[2]) + 9, p[2]) * tilt, Vector3.new(30, 16, 30))
	end
end

-- 3. sounds outside the prefabs
sound("BambooSea_W", "BambooGrove", Vector3.new(-420, gy(-420, 640) + 6, 640))
sound("BambooSea_E", "BambooGrove", Vector3.new(-250, gy(-250, 668) + 6, 668))
sound("WolfRing", "DenWind", Vector3.new(-580, gy(-580, 780) + 5, 780))
sound("TwinJadeQi", "QiSpring", Vector3.new(600, gy(600, 1225) + 3, 1225))
sound("BorderRiver", "Stream", Vector3.new(212, 3, 1588))
-- birds by day, insects by night, on open ground about every 100+ studs
local OPEN = {
	{ "G1", -400, 1000 }, { "G2", 300, 680 }, { "G3", 470, 1120 }, { "Court", 18, 690 }, { "Spine", -10, 880 },
	{ "CrossW", -230, 990 }, { "CrossE", 240, 1160 }, { "EastArm", 450, 795 }, { "WestArm", -280, 735 },
	{ "SouthW", -400, 1300 }, { "SouthE", 380, 1330 }, { "EastLoop", 610, 1000 },
}
for _, e in OPEN do
	local y = gy(e[2], e[3]) + 8
	sound("Birds_" .. e[1], "DayBirds", Vector3.new(e[2], y, e[3]))
	sound("Insects_" .. e[1], "NightInsects", Vector3.new(e[2], y - 4, e[3]))
end
-- flyer spots and high ledges (the V stubs; their markers are editor-only)
for _, v in { { "V1", -880, 70, 640 }, { "V2", -25, 30, 1385 }, { "V3", 305, 100, 900 }, { "V4", 760, 60, 605 }, { "V5", 620, 115, 1180 }, { "V6", -400, 55, 560 }, { "V7", -640, 80, 1240 }, { "V8", 430, 90, 620 } } do
	sound("HighWind_" .. v[1], "HighWind", Vector3.new(v[2], v[3], v[4]))
end

-- 4. RimVeil past the wall backs (cloud seen by flyers over the crest) and RimWind along the crests,
-- one each per ~110 studs of wall
local CREST = { -- build_walls_inner.luau SEGMENTS + the test stretch
	{ { -790, 556 }, { -620, 522 }, { -400, 505 }, { -112, 502 } },
	{ { 152, 500 }, { 270, 494 }, { 386, 500 } },
	{ { 545, 600 }, { 700, 590 }, { 840, 640 } },
	{ { 840, 640 }, { 900, 800 }, { 905, 1000 }, { 880, 1180 }, { 800, 1262 } },
	{ { 618, 1425 }, { 420, 1450 }, { 262, 1452 } },
	{ { -212, 1448 }, { -110, 1418 }, { -12, 1400 }, { 42, 1402 } },
	{ { -212, 1448 }, { -280, 1452 }, { -500, 1440 }, { -760, 1400 } },
	{ { -760, 1400 }, { -860, 1250 }, { -900, 1000 }, { -872, 742 } },
}
local CENTRE = Vector3.new(0, 0, 1000)
local rockParams = OverlapParams.new()
rockParams.FilterType = Enum.RaycastFilterType.Include
rockParams.FilterDescendantsInstances = { ground.Walls, workspace.Map.Karst }
local veils = 0
for _, line in CREST do
	local carry = 40
	for i = 1, #line - 1 do
		local a = Vector3.new(line[i][1], 0, line[i][2])
		local b = Vector3.new(line[i + 1][1], 0, line[i + 1][2])
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local outward = Vector3.new(-dir.Z, 0, dir.X)
		if outward:Dot(CENTRE - (a + b) / 2) > 0 then
			outward = -outward
		end
		local t = carry
		while t < len do
			local p = a + dir * t + outward * 80
			local pos = Vector3.new(p.X, 100, p.Z)
			local tries = 0
			while #workspace:GetPartBoundsInRadius(pos, 30, rockParams) > 0 and tries < 4 do
				pos += outward * 15
				tries += 1
			end
			veils += 1
			fx("RimVeil", "FX_RimVeil" .. veils, CFrame.lookAt(pos, pos + outward), nil, 1)
			sound("RimWind" .. veils, "RimWind", Vector3.new(a.X + dir.X * t, 95, a.Z + dir.Z * t))
			t += 110
		end
		carry = t - len
	end
end
table.insert(report, string.format("RimVeil %d, sound anchors %d", veils, soundCount))
return table.concat(report, "\n")
