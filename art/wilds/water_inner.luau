--!nocheck
-- Water of the Inner Wilds valley (docs/systems/map.md, "Inner Wilds rework"): the Lotus Mere and the
-- rimmed pools at each fall's foot are ServerStorage.WaterKit shallow water (never terrain water), the
-- falls are the AssetLibrary "Blue Waterfall" scaled to the drop, with WaterfallFoam and
-- AmbientFX.WaterfallSpray at each foot and FX_ anchors for vfx. Also builds the Twin-Jade notch
-- (two giant cliff rocks and a lip against the SouthEastFar karst) in the wall kit's style.
--
-- Run in Studio Edit mode through execute_luau after terrain_wilds.luau (it carves its pool beds into
-- the terrain, so re-run it after any terrain pass). Rebuilds Map.Ground.WildsInner.Water and
-- Walls.TwinJadeNotch each run; seeded.
-- Needs tools/water_kit_build.luau run first (_G.waterKit).

local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local WK = SS.WaterKit
local KIT = _G.waterKit
assert(KIT, "run tools/water_kit_build.luau first")
local SHEET = SS.AssetLibrary.VFX["Blue Waterfall"]
local SPRAY = SS.AmbientFX:FindFirstChild("WaterfallSpray")
local LIP_FX = SS.AmbientFX:FindFirstChild("WaterfallLip")
local terrain = workspace.Terrain
local P2 = SS.AssetLibrary["Stylized Rock Packs"]["Stylized Cliff Rock Pack II"]:GetChildren()
local function rockSrc(y)
	for _, m in P2 do
		local _, s = m:GetBoundingBox()
		if math.abs(s.Y - y) < 1.5 then
			return m
		end
	end
end

local ground = workspace.Map.Ground.WildsInner
local old = ground:FindFirstChild("Water")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Water"
root.Parent = ground

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end
local rng = Random.new(77)

local function noPhysics(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- rock clone in the wall style (bottom-centre pivot, tinted like the walls)
local function rock(parent, name, height, x, z, yaw, sink)
	local src = rockSrc(height > 60 and 66 or height > 34 and 50 or 23)
	local m = src:Clone()
	local box, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * m:GetPivot().Rotation
	m:ScaleTo(m:GetScale() * (height / size.Y))
	m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * m:GetPivot().Rotation)
	local b2, s2 = m:GetBoundingBox()
	local g = math.huge
	for _, o in { { 0, 0 }, { 0.4, 0 }, { -0.4, 0 }, { 0, 0.4 }, { 0, -0.4 } } do
		g = math.min(g, gy(b2.X + s2.X * o[1], b2.Z + s2.Z * o[2]))
	end
	m:PivotTo(m:GetPivot() + Vector3.new(0, (g - s2.Y * (sink or 0.15)) - (b2.Y - s2.Y / 2), 0))
	m.Name = name
	m:SetAttribute("WallPiece", "CTR")
	local v = rng:NextInteger(-7, 7)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = true
			p.CanQuery = true
			p.CanTouch = false
			p.CastShadow = height > 20
			if p:IsA("MeshPart") then
				pcall(function()
					p.CollisionFidelity = Enum.CollisionFidelity.Hull
				end)
			end
		elseif p:IsA("SurfaceAppearance") then
			p.Color = Color3.fromRGB(112 + v, 104 + v, 91 + v)
		end
	end
	m.Parent = parent
	return m
end

-- a round pool: bed carved 1.2 under the surface, the surface 0.4 under the lowest bank round it,
-- a WaterKit round surface, rim foam and a ring of small stones
local function pool(name, x, z, r, stones)
	local edge = math.huge
	for i = 0, 15 do
		local a = i / 16 * 2 * math.pi
		edge = math.min(edge, gy(x + math.cos(a) * (r + 5), z + math.sin(a) * (r + 5))) -- outside the carve, so re-runs give the same surface
	end
	local surface = edge - 0.4
	local bed = surface - 1.2
	-- clear everything above the bed inside the pool, then lay a sand bed
	terrain:FillCylinder(CFrame.new(x, bed + 15, z), 30, r + 0.5, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(x, bed - 1.5, z), 3, r + 1, Enum.Material.Sand)
	local m = Instance.new("Model")
	m.Name = name
	local w = WK.ShallowWaterRound:Clone()
	w.Name = "Water"
	w.Size = Vector3.new(w.Size.X, r * 2, r * 2)
	w.CFrame = CFrame.new(x, surface - w.Size.X / 2, z) * WK.ShallowWaterRound.CFrame.Rotation
	w.Parent = m
	m.Parent = root
	KIT.rimPart(w)
	-- the stone rim: small cliff rocks round the edge, a gap toward the valley side
	for i = 0, (stones or 9) - 1 do
		local a = i / (stones or 9) * 2 * math.pi + rng:NextNumber(-0.15, 0.15)
		local rr = r + rng:NextNumber(0.5, 2)
		rock(m, "RimStone", rng:NextNumber(2.5, 5), x + math.cos(a) * rr, z + math.sin(a) * rr, rng:NextNumber(0, 6.28), 0.35)
	end
	m:SetAttribute("Surface", surface)
	return m, surface
end

-- a falling sheet from `top` straight down to `bottomY`, facing `out` (horizontal, away from the rock)
local SHEET_SIZE = select(2, SHEET:GetBoundingBox())
local function fall(parent, name, top, bottomY, out, width)
	local h = top.Y - bottomY
	local m = SHEET:Clone()
	m.Name = name
	m:ScaleTo(math.max(0.15, h / SHEET_SIZE.Y))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			noPhysics(d)
		elseif d:IsA("Light") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local mid = Vector3.new(top.X, (top.Y + bottomY) / 2, top.Z)
	m:PivotTo(CFrame.lookAt(mid, mid - out))
	local cf = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (mid - cf.Position))
	m.Parent = parent
	if LIP_FX then
		local lip = LIP_FX:Clone()
		lip.Name = "FX_FallLip"
		lip.Size = Vector3.new(width, 0.3, 1)
		lip.CFrame = CFrame.lookAt(top + out * 0.4, top + out * 1.4)
		lip.Parent = parent
	end
	return m
end

-- scale every emitter's Rate in a cloned AmbientFX template by placed area / authored area
local function scaleRate(inst, factor)
	for _, e in inst:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.Rate *= factor
		end
	end
end
local function fxClone(name, newName, cf, size, rateFactor, parent)
	local t = SS.AmbientFX:FindFirstChild(name)
	if not t then
		return nil
	end
	local c = t:Clone()
	c.Name = newName
	c.Size = size
	c.CFrame = cf
	scaleRate(c, rateFactor)
	c.Parent = parent
	return c
end

-- the foot of a fall: WaterKit foam, AmbientFX.WaterfallSpray (FX_FallSpray), PlungeBillow at hero
-- falls, and WaterfallMist (FX_FallMist) as an upright slab on the fall's face (world.md, Inner set)
local function foot(parent, at, out, size, hero, fallTop)
	local foam = WK.WaterfallFoam:Clone()
	foam.Size = Vector3.new(size, 0.2, size)
	foam.CFrame = CFrame.lookAt(at + Vector3.new(0, 0.05, 0), at + Vector3.new(0, 0.05, 0) + out)
	foam.Parent = parent
	if SPRAY then
		local s = SPRAY:Clone()
		s.Name = "FX_FallSpray"
		if not hero then
			s.Size = Vector3.new(size, s.Size.Y, math.min(s.Size.Z, size))
		end
		s.CFrame = CFrame.lookAt(at + Vector3.new(0, 0.2, 0), at + Vector3.new(0, 0.2, 0) + out)
		s.Parent = parent
	end
	local h = fallTop.Y - at.Y
	if hero then
		fxClone("PlungeBillow", "FX_FallSpray_Billow", CFrame.lookAt(at + Vector3.new(0, 1, 0), at + Vector3.new(0, 1, 0) + out), Vector3.new(16, 2, 8), 1, parent)
		local w = 20
		fxClone("WaterfallMist", "FX_FallMist", CFrame.lookAt(Vector3.new(fallTop.X, at.Y + h / 2, fallTop.Z) + out * 3, Vector3.new(fallTop.X, at.Y + h / 2, fallTop.Z) + out * 4), Vector3.new(w, h, 3), 2.6 * (w * h) / (20 * 38), parent)
	else
		fxClone("WaterfallMist", "FX_FallMist", CFrame.lookAt(Vector3.new(fallTop.X, at.Y + h / 2, fallTop.Z) + out * 2, Vector3.new(fallTop.X, at.Y + h / 2, fallTop.Z) + out * 3), Vector3.new(4, math.min(h, 14), 2), 0.3, parent)
	end
	-- ambient sound anchors (world.md "Ambient sound": tag AmbientSound, attribute Sound = template)
	local snd = Instance.new("Part")
	snd.Name = if hero then "SFX_WaterfallBig" else "SFX_WaterfallSmall"
	snd.Size = Vector3.new(1, 1, 1)
	snd.Transparency = 1
	noPhysics(snd)
	snd.CFrame = CFrame.new(at + Vector3.new(0, 4, 0))
	snd:SetAttribute("Sound", if hero then "WaterfallHero" else "WaterfallTrickle")
	snd.Parent = parent
	CollectionService:AddTag(snd, "AmbientSound")
	-- and the pool lapping
	local lap = snd:Clone()
	lap.Name = "SFX_PoolLap"
	lap:SetAttribute("Sound", "PoolLap")
	lap.CFrame = CFrame.new(at + Vector3.new(0, 1, 0) + out * (size * 0.6))
	lap.Parent = parent
	CollectionService:AddTag(lap, "AmbientSound")
end

-- find a wall's face from the valley side: (x, z) a point in front of it, `inward` the horizontal unit
-- vector from the wall toward the valley; returns the face point at y and the lip height above it
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
local function faceAt(x, z, inward, y, walls)
	wallParams.FilterDescendantsInstances = walls
	local start = Vector3.new(x, y, z) + inward * 80
	local hit = workspace:Raycast(start, -inward * 200, wallParams)
	return hit and hit.Position
end
local function lipAbove(x, z, inward, walls, from)
	-- climb until the rock no longer stands within 6 studs behind the face
	local face = faceAt(x, z, inward, from, walls)
	local topY = from
	for y = from, 140, 2 do
		local f = faceAt(x, z, inward, y, walls)
		if not f or (f - Vector3.new(face.X, y, face.Z)):Dot(-inward) > 8 then
			break
		end
		topY = y
		face = Vector3.new(f.X, y, f.Z)
	end
	return Vector3.new(face.X, topY, face.Z)
end

local WALLS = ground.Walls
local report = {}

-- 1. Jade Veil Falls: through the test stretch's notch over the lip rock into a pool at its foot
do
	local lipRock = WALLS.TestStretch_South.Wall_S06_NotchLip
	local inward = Vector3.new(0, 0, -1)
	local top = lipAbove(-12, 1340, inward, { lipRock }, 12)
	local px, pz, r = -12, top.Z - 11, 12
	local m, surface = pool("JadeVeilPool", px, pz, r, 11)
	local f = fall(m, "JadeVeilFall", top + inward * 2.5 + Vector3.new(0, 0.5, 0), surface, inward, 12)
	foot(m, Vector3.new(top.X, surface, top.Z) + inward * 4, inward, 12, true, top)
	table.insert(report, string.format("Jade Veil: lip Y %.0f at z %.0f, pool (%d, %.0f) surface %.1f", top.Y, top.Z, px, pz, surface))
end

-- 2. Twin-Jade notch and falls at the SouthEastFar karst's foot, into the Qi Spring pool
do
	local old = WALLS:FindFirstChild("TwinJadeNotch")
	if old then
		old:Destroy()
	end
	local n = Instance.new("Folder")
	n.Name = "TwinJadeNotch"
	n.Parent = WALLS
	rock(n, "Wall_TJ01_Giant", 96, 565, 1267, 0.6, 0.12)
	rock(n, "Wall_TJ02_Giant", 104, 683, 1237, 2.2, 0.12)
	rock(n, "Wall_TJ03_NotchLip", 46, 625, 1251, 0.1, 0.1)
	rock(n, "Wall_TJ04_Seam", 30, 535, 1237, 1.4, 0.15)
	rock(n, "Wall_TJ05_Seam", 28, 715, 1211, 4.0, 0.15)
	rock(n, "Wall_TJ06_Small", 8, 587, 1221, 2.0, 0.2)
	rock(n, "Wall_TJ07_Small", 10, 665, 1205, 5.0, 0.2)
	-- 25 studs in front of the SouthEastFar karst: its trunk collider (r 96 round (704, 1324)) is
	-- wider than the mesh, and players must reach the pool
	local inward = (Vector3.new(565, 0, 1190) - Vector3.new(625, 0, 1251)).Unit
	local top = lipAbove(625, 1251, inward, { n.Wall_TJ03_NotchLip }, 12)
	local c = Vector3.new(top.X, 0, top.Z) + inward * 15
	local m, surface
	local placed = ground:FindFirstChild("Pockets") and ground.Pockets:FindFirstChild("TwinJadeSpring")
	local springPool = placed and placed:FindFirstChild("SpringPool", true)
	if springPool then
		-- the TwinJadeSpring prefab brings the pool, rim and foam; only the falls are built here
		m = Instance.new("Model")
		m.Name = "TwinJadeFalls"
		m.Parent = root
		local w = springPool:FindFirstChild("Water")
		surface = if w then w.Position.Y + w.Size.X / 2 else springPool:GetBoundingBox().Y
	else
		m, surface = pool("TwinJadePool", c.X, c.Z, 15, 11)
	end
	-- two ribbons a few studs apart
	local side = Vector3.new(-inward.Z, 0, inward.X)
	fall(m, "TwinJadeFall_A", top + inward * 2.5 + side * 7 + Vector3.new(0, 0.5, 0), surface, inward, 8)
	fall(m, "TwinJadeFall_B", top + inward * 2.5 - side * 7 + Vector3.new(0, 0.5, 0), surface, inward, 8)
	if not springPool then
		foot(m, Vector3.new(top.X, surface, top.Z) + inward * 5, inward, 14, true, top)
	end
	table.insert(report, string.format("Twin-Jade: lip Y %.0f, pool (%.0f, %.0f) surface %.1f", top.Y, c.X, c.Z, surface))
end

-- 3. thin trickles down the walls, each into a small rimmed pool
local function trickle(name, x, z, inward, walls, r)
	local face = faceAt(x, z, inward, 10, walls)
	if not face then
		table.insert(report, name .. ": no wall face found")
		return
	end
	local top = lipAbove(face.X + inward.X * 2, face.Z + inward.Z * 2, inward, walls, 10)
	top = Vector3.new(face.X, math.min(top.Y, 60), face.Z)
	local c = Vector3.new(face.X, 0, face.Z) + inward * (r + 2)
	local m, surface = pool(name .. "Pool", c.X, c.Z, r, 7)
	fall(m, name, top + inward * 2.5, surface, inward, 4)
	foot(m, Vector3.new(top.X, surface, top.Z) + inward * 3, inward, 6, false, top)
	table.insert(report, string.format("%s: top Y %.0f, pool (%.0f, %.0f) surface %.1f", name, top.Y, c.X, c.Z, surface))
end
trickle("DenTrickle", -868, 790, Vector3.new(1, 0, 0), { WALLS.West }, 8)
-- the Bamboo Hollow trickle: down the north wall into the BambooHollow prefab's spring
do
	local placed = ground:FindFirstChild("Pockets") and ground.Pockets:FindFirstChild("BambooHollow")
	local spring = placed and placed:FindFirstChild("Spring", true)
	if spring then
		local inward = Vector3.new(0, 0, 1)
		local walls = { WALLS.NorthWest, placed:FindFirstChild("Outcrop", true) }
		local sw = spring:FindFirstChild("Water") or spring:FindFirstChildWhichIsA("BasePart")
		local face = faceAt(sw.Position.X, sw.Position.Z, inward, sw.Position.Y + 8, walls)
		if face then
			local top = lipAbove(face.X + inward.X * 2, face.Z + inward.Z * 2, inward, walls, math.floor(sw.Position.Y + 8))
			top = Vector3.new(face.X, math.min(top.Y, 50), face.Z)
			local m = Instance.new("Model")
			m.Name = "BambooHollowTrickle"
			m.Parent = root
			local surface = sw.Position.Y + sw.Size.X / 2
			fall(m, "BambooTrickle", top + inward * 2, surface, inward, 4)
			table.insert(report, string.format("Bamboo trickle: top Y %.0f into the hollow's spring (surface %.1f)", top.Y, surface))
		end
	end
end
trickle("EastTrickle", 902, 960, Vector3.new(-1, 0, 0), { WALLS.East }, 7)

-- 4. the Lotus Mere: shallow walkable water over a sand floor (unless the LotusMere prefab, which
-- brings its own water, is placed)
if not (ground:FindFirstChild("Pockets") and ground.Pockets:FindFirstChild("LotusMere")) then
	local m, surface = pool("LotusMere", -260, 1170, 42, 0)
	m.Water:SetAttribute("Note", "walkable shallow water; lotus, pavilion and boat come from InnerWildsPrefabs")
	table.insert(report, string.format("Lotus Mere: surface %.1f, r 42", surface))
end

-- tag the falls and pools as hand-pass candidates where they meet rock
for _, m in root:GetChildren() do
	if m.Name ~= "LotusMere" and m.Name ~= "TwinJadeFalls" and m.Name ~= "BambooHollowTrickle" then
		CollectionService:AddTag(m, "NeedsHandPass")
		m:SetAttribute("HandPassReason", "Fall sheet and pool against rock: check the sheet starts at the lip, doesn't float in front of the face or cut into it, and the pool's rim stones close the edge.")
		m:SetAttribute("HandPassStatus", "open")
	end
end
return table.concat(report, "\n")
