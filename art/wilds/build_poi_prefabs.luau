--!nocheck
--[[
Inner Wilds POI prefabs: the landmark structures of the seven pockets plus the hero Shrine Terrace, and
the small finds between them (docs/map/inner-wilds-rework.md). Each prefab is a self-contained
Model in ServerStorage.InnerWildsPrefabs, built round its own ground point, for the map-builder who
places them once the layout and terrain are done. A preview copy of each stands on a grass slab in
Workspace._PoiStaging (x 4000-4800, Y 200, z 3000-3600, over the cloud sea).

Run in Studio Edit mode (execute_luau, or require a ModuleScript holding this source) after
tools/water_kit_build.luau (it needs _G.waterKit for rim foam):
  _G.POI_PREFABS = { only = { "WolfDen", "F05_OldWell" } }  -- optional: rebuild only these
  _G.POI_PREFABS = { group = "finds" }                     -- or only "landmarks" / "finds"
Rebuilding a prefab replaces both its ServerStorage copy and its staging copy; others are left alone.

Every prefab:
- PrimaryPart nil, WorldPivot = identity rotation at its ground point (local origin). The approach side
  (the face players should see first) is -Z: yaw the clone so -Z points at the path.
- Attributes PoiName, Kind ("Landmark" / "Find"), Zone "Inner", PlannedSpot (Vector3 from the plan,
  Y 0: ground it by raycast), Footprint ("W x D x H studs"), Pocket, Note; CollectionService tag POI.
- Bases reach 1-2 studs below the pivot so they sit into uneven ground.
- Named Attachments on invisible, non-colliding anchors: CacheSpot (where a manual cache goes),
  PromptSpot (an interaction), QiNodeSpot, HermitSpot, AmbushSpot_n, FX_<What> (for the vfx agent).
- Collision as seen: stone, wood, rock and trunks collide; foliage, cloth, bones, debris and water don't
  (CanCollide and CanQuery off, so spawn and treasure rays skip them). Library meshes whose hull would
  fill their interior (the Temple Structure) are visual only, with invisible collider parts.
- TerrainCarve parts (invisible, non-colliding, CanQuery off) mark where the placer must clear terrain
  (pools, the mere, the wallow); their top face is the level to dig down to.
- ReseatChildren = true on spread-out prefabs (ring stones, snare lines): ground each child model
  separately when placing.
- Hard builds carry the tag NeedsHandPass with HandPassReason and HandPassStatus "open".
Lamps are Models named StoneLantern / JadeLamp / Brazier (Config.Ambience.LAMP_MODELS) with one
shadowless PointLight each, so DayNight dims them once placed under Map.
]]

local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")

local GROUP
local CFG = _G.POI_PREFABS or {}
_G.POI_PREFABS = nil
local WK = _G.waterKit
assert(WK, "run tools/water_kit_build.luau first (installs _G.waterKit)")

local LIB = SS.AssetLibrary
local KIT = SS.WildsKit
local TPL = SS._Templates
local WATER = SS.WaterKit
local PROPS = LIB["Stylized Asset Pack I (Props)"]["Stylized Props"]
local WPROPS1 = LIB["Stylized Asset Pack I (Props)"]["Stylized Wooden Props I"]
local MD = LIB["Map Detailing"]
local INNO = MD["Inno's_Stylized_Asset_Pack"].Assets.Regular_Assets

local M = Enum.Material
local hex = Color3.fromHex
local C = {
	stone = hex("8E8983"),
	stoneMid = hex("7A7570"),
	stoneDark = hex("615D59"),
	stoneDeep = hex("4D4A47"),
	pave = hex("B3AA9A"),
	paveDark = hex("9A9183"),
	curb = hex("8A8274"),
	moss = hex("4E6B45"),
	mossLight = hex("56744A"),
	lawn = hex("6E8F5A"),
	turf = hex("4A6340"),
	wood = hex("5A3F2E"),
	woodLight = hex("6E4F3A"),
	woodDark = hex("3F2C21"),
	woodPale = hex("8A6E52"),
	char = hex("2B2420"),
	lacquer = hex("9B2D26"),
	lacquerDark = hex("74201C"),
	lacquerFaded = hex("7E3A30"),
	roof = hex("33403F"),
	roofLight = hex("43524F"),
	roofDark = hex("262F2F"),
	jade = hex("5FAE96"),
	jadeLight = hex("8FD4BC"),
	gold = hex("C29A48"),
	goldDark = hex("8E6E30"),
	earth = hex("8A7A62"),
	earthDark = hex("6E6150"),
	mud = hex("5A4A3A"),
	sand = hex("A89A7E"),
	bed = hex("6F6A58"),
	bone = hex("D9D0BC"),
	cloth = hex("6E2A24"),
	clothPale = hex("C9B99A"),
	straw = hex("B59A62"),
	hide = hex("7A5A3E"),
	hideLight = hex("8C6B4A"),
	rust = hex("6B4A36"),
	iron = hex("4A4A4E"),
	ember = hex("FF8A3D"),
	cave = hex("17151A"),
	rockTint = hex("706858"),
	herbGlow = hex("9FE8C8"),
	herbGold = hex("E8C860"),
	berry = hex("B8343A"),
	paper = hex("E6DCC0"),
}

local rng = Random.new(20261021)
local function rr(a, b)
	return rng:NextNumber(a, b)
end

-- geometry -------------------------------------------------------------------------------------------

-- world axis-aligned bounds of a part or model (its BaseParts)
local function bounds(inst)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	local list = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") then
			local cf, h = p.CFrame, p.Size / 2
			local X, Y, Z = cf.XVector, cf.YVector, cf.ZVector
			local e = Vector3.new(
				math.abs(X.X) * h.X + math.abs(Y.X) * h.Y + math.abs(Z.X) * h.Z,
				math.abs(X.Y) * h.X + math.abs(Y.Y) * h.Y + math.abs(Z.Y) * h.Z,
				math.abs(X.Z) * h.X + math.abs(Y.Z) * h.Y + math.abs(Z.Z) * h.Z
			)
			mn = mn:Min(cf.Position - e)
			mx = mx:Max(cf.Position + e)
		end
	end
	return mn, mx
end

local function V(x, y, z)
	return Vector3.new(x, y or 0, z or 0)
end
local function at(x, y, z, yaw)
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
end

-- parts ----------------------------------------------------------------------------------------------

-- opts: nc (no collision or queries), shape, trans, shadow (default true), name
local function P(parent, name, size, cf, color, mat, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Slate
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.nc then
		p.CanCollide = false
		p.CanQuery = false
	end
	p.CastShadow = opts.shadow ~= false
	if opts.trans then
		p.Transparency = opts.trans
	end
	p.Parent = parent
	return p
end
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
-- an upright cylinder (Roblox cylinders run along X): centre cf, height h, diameter d
local function cyl(parent, name, cf, h, d, color, mat, opts)
	opts = opts or {}
	opts.shape = CYL
	return P(parent, name, V(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, opts)
end
-- a cylinder lying from a to b
local function rod(parent, name, a, b, d, color, mat, opts)
	opts = opts or {}
	opts.shape = CYL
	local len = (b - a).Magnitude
	return P(parent, name, V(len, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, mat, opts)
end
-- a beam (block) from a to b with a square section
local function beam(parent, name, a, b, w, h, color, mat, opts)
	local len = (b - a).Magnitude
	return P(parent, name, V(w, h or w, len), CFrame.lookAt((a + b) / 2, b), color, mat, opts)
end
local function wedge(parent, name, size, cf, color, mat, opts)
	opts = opts or {}
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or M.Slate
	w.Anchored = true
	w.CanTouch = false
	if opts.nc then
		w.CanCollide = false
		w.CanQuery = false
	end
	w.CastShadow = opts.shadow ~= false
	w.Parent = parent
	return w
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- an invisible, non-colliding anchor with a named Attachment (spots and FX points)
local function spot(parent, name, pos, size)
	local a = P(parent, name .. "Anchor", size or V(1, 1, 1), typeof(pos) == "CFrame" and pos or CFrame.new(pos), C.stone, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 })
	local att = Instance.new("Attachment")
	att.Name = name
	att.Parent = a
	return att
end
local fx = spot
-- a sound point (SND_<What>): an Attachment the placer or the sound pass hangs an ambient Sound on
local snd = spot

-- a volume the placer clears of terrain (top face = dig level)
local function carve(parent, name, cf, size, shape)
	local p = P(parent, name or "TerrainCarve", size, cf, hex("FF00FF"), M.SmoothPlastic, { nc = true, shadow = false, trans = 1, shape = shape })
	p:SetAttribute("Note", "placer: clear terrain inside this volume (down to its top face) before placing")
	return p
end

local function light(part, range, bright, color)
	local l = Instance.new("PointLight")
	l.Range = range or 12
	l.Brightness = bright or 0.8
	l.Color = color or hex("FFB56B")
	l.Shadows = false
	l.Parent = part
	return l
end

-- library / kit clones ---------------------------------------------------------------------------------

local function setPhysics(c, collide)
	for _, p in (c:IsA("BasePart") and { c } or c:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			p.CanCollide = collide and true or false
			p.CanQuery = collide and true or false
			if p:IsA("MeshPart") or p:IsA("PartOperation") then
				pcall(function()
					p.CollisionFidelity = collide and Enum.CollisionFidelity.Hull or Enum.CollisionFidelity.Box
				end)
			end
		end
	end
end

-- K: clone src, turn it (yaw, tilt), scale (scale factor or o.h target height), then seat its bounding
-- box's bottom centre on pos, sunk by o.sink of its height. Pivots are reset to that ground point, so
-- library pivots that lie (hundreds of studs off) don't matter.
-- o: yaw, tilt (CFrame), scale, h, w (target max horizontal size), sink (default 0.05), collide,
-- tint (SurfaceAppearance colour), color (part colour), name
local function K(parent, src, pos, o)
	o = o or {}
	assert(src, "missing library piece")
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local turn = CFrame.Angles(0, o.yaw or 0, 0) * (o.tilt or CFrame.identity)
	local isModel = c:IsA("Model")
	local function rescale(f)
		if isModel then
			c:ScaleTo(c:GetScale() * f)
		else
			c.Size *= f
		end
	end
	if o.scale and o.scale ~= 1 then
		rescale(o.scale)
	end
	if isModel then
		c:PivotTo(turn * c:GetPivot().Rotation)
	else
		c.CFrame = turn * c.CFrame.Rotation
	end
	if o.h or o.w then
		local mn, mx = bounds(c)
		local f = o.h and o.h / (mx.Y - mn.Y) or o.w / math.max(mx.X - mn.X, mx.Z - mn.Z)
		rescale(f)
	end
	local mn, mx = bounds(c)
	local bottom = V((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	local delta = pos - bottom - V(0, (mx.Y - mn.Y) * (o.sink or 0.05), 0)
	if isModel then
		c:PivotTo(c:GetPivot() + delta)
		c.WorldPivot = CFrame.new(pos) * CFrame.Angles(0, o.yaw or 0, 0)
	else
		c.CFrame += delta
	end
	setPhysics(c, o.collide)
	for _, d in (isModel and c:GetDescendants() or { c, unpack(c:GetChildren()) }) do
		if o.tint and d:IsA("SurfaceAppearance") then
			d.Color = o.tint
		elseif o.color and d:IsA("BasePart") then
			d.Color = o.color
			if d:IsA("PartOperation") then
				d.UsePartColor = true
			end
		end
	end
	if o.name then
		c.Name = o.name
	end
	c.Parent = parent
	return c
end

-- the Stylized Cliff Terrain Rocks by proportion (moss-capped, the wall rocks' family)
local ROCKS = {}
for _, r in LIB["Stylized Rock Packs"]["Stylized Cliff Rock Pack II"]:GetChildren() do
	local _, s = r:GetBoundingBox()
	local kind = s.Y > 60 and "tall" or s.Y > 40 and "mid" or s.X > 60 and "wide" or "low"
	ROCKS[kind] = ROCKS[kind] or r
end
local function rockTint()
	local k = rr(-0.06, 0.06)
	local t = C.rockTint
	return Color3.new(math.clamp(t.R + k, 0, 1), math.clamp(t.G + k, 0, 1), math.clamp(t.B + k * 0.8, 0, 1))
end
-- a moss-capped rock h studs tall
local function rock(parent, kind, pos, h, yaw, o)
	o = o or {}
	o.h = h
	o.yaw = yaw or rr(0, 6.28)
	o.tint = o.tint or rockTint()
	if o.collide == nil then
		o.collide = true
	end
	o.sink = o.sink or 0.12
	o.name = o.name or "Rock"
	return K(parent, ROCKS[kind], pos, o)
end
-- a small loose stone (debris, non-colliding unless asked)
local function pebble(parent, pos, h, o)
	o = o or {}
	o.collide = o.collide or false
	o.sink = o.sink or 0.3
	o.name = o.name or "Stone"
	return rock(parent, rng:NextNumber() < 0.5 and "low" or "wide", pos, h, nil, o)
end

local function moss(parent, cf, size, color)
	return P(parent, "Moss", size, cf, color or (rng:NextNumber() < 0.5 and C.moss or C.mossLight), M.LeafyGrass, { nc = true, shadow = false })
end

local function plant(parent, name, pos, o)
	o = o or {}
	o.yaw = o.yaw or rr(0, 6.28)
	o.sink = o.sink or 0.1
	return K(parent, KIT[name], pos, o)
end

local function bamboo(parent, n, pos, yaw, o)
	o = o or {}
	o.yaw = yaw or rr(0, 6.28)
	o.sink = o.sink or 0.03
	o.name = "Bamboo"
	return K(parent, TPL["BambooCluster_" .. n], pos, o)
end

-- a tree with an invisible trunk collider
local function tree(parent, src, pos, o)
	o = o or {}
	o.yaw = o.yaw or rr(0, 6.28)
	o.sink = o.sink or 0.03
	o.name = o.name or "Tree"
	local t = K(parent, typeof(src) == "string" and KIT[src] or src, pos, o)
	local _, mx = bounds(t)
	local hgt = mx.Y - pos.Y
	local trunk = cyl(t, "TrunkCollider", CFrame.new(pos + V(0, hgt * 0.2, 0)), hgt * 0.4, o.trunk or math.max(1.6, hgt * 0.05), C.wood, M.Wood, { trans = 1, shadow = false })
	trunk.CanQuery = true
	return t
end

local function lampModel(name, src, parent, pos, yaw, lit)
	local m = src:Clone()
	m.Name = name
	local mn = bounds(m)
	m:PivotTo(CFrame.new(m:GetPivot().Position + (pos - V(m:GetPivot().X, mn.Y, m:GetPivot().Z)) - V(0, 0.3, 0)) * CFrame.Angles(0, yaw or 0, 0))
	m.WorldPivot = CFrame.new(pos)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			p.CanCollide = p.Name == "Body"
			p.CanQuery = p.Name == "Body"
		end
	end
	m.Parent = parent
	return m
end
local function stoneLantern(parent, pos, yaw, lit)
	local m = lampModel("StoneLantern", TPL.FX_StoneLantern, parent, pos, yaw)
	if lit ~= false and m:FindFirstChild("Flame") then
		light(m.Flame, 14, 0.9)
	end
	return m
end
local function jadeLamp(parent, pos, yaw, lit)
	local m = lampModel("JadeLamp", TPL.FX_JadeLamp, parent, pos, yaw)
	if lit ~= false and m:FindFirstChild("QiOrb") then
		light(m.QiOrb, 12, 0.8, hex("7FE0C0"))
	end
	return m
end
local function brazier(parent, pos, lit)
	local m = lampModel("Brazier", TPL.FX_Brazier, parent, pos, 0)
	if lit ~= false and m:FindFirstChild("Embers") then
		light(m.Embers, 12, 0.8)
	end
	return m
end

-- small builders -------------------------------------------------------------------------------------

-- a gabled roof: cf at the eave line's centre (ridge along local X), w along the ridge, d eave to eave,
-- rise from eave to ridge; tips flick up at the four corners
local function roof(parent, cf, w, d, rise, o)
	o = o or {}
	local col = o.color or C.roof
	local half = d / 2
	local slope = math.sqrt(half * half + rise * rise)
	local ang = math.atan2(rise, half)
	local th = o.thick or 0.7
	for _, s in { -1, 1 } do
		local mid = cf * CFrame.new(0, rise / 2, s * half / 2)
		P(parent, "RoofSlope", V(w, th, slope + 0.6), mid * CFrame.Angles(s * ang, 0, 0), s < 0 and col or (o.color2 or C.roofLight), o.mat or M.Slate)
		-- the eave fascia
		P(parent, "Eave", V(w + 0.2, 0.5, 0.5), cf * CFrame.new(0, -0.15, s * (half + 0.15)), o.trim or C.woodDark, M.Wood, { nc = true })
		for _, e in { -1, 1 } do
			-- upturned corner tips
			wedge(parent, "EaveTip", V(0.6, 0.9, 1.6), cf * CFrame.new(e * (w / 2 + 0.2), 0.15, s * (half + 0.2)) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0), o.trim or C.roofDark, M.Slate, { nc = true })
		end
	end
	P(parent, "Ridge", V(w + 1.2, 0.7, 0.9), cf * CFrame.new(0, rise + 0.25, 0), o.ridge or C.roofDark, M.Slate)
	for _, e in { -1, 1 } do
		P(parent, "RidgeEnd", V(0.8, 1.2, 0.8), cf * CFrame.new(e * (w / 2 + 0.6), rise + 0.6, 0) * CFrame.Angles(0, 0, e * -0.4), o.ridgeEnd or C.goldDark, M.Metal, { nc = true })
		-- gable infill
		if o.gable ~= false then
			for _, s in { -1, 1 } do
				wedge(parent, "Gable", V(0.4, rise, half), cf * CFrame.new(e * (w / 2 - 0.4), rise / 2, s * half / 2) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), o.gableColor or C.wood, M.WoodPlanks)
			end
		end
	end
end

-- a stone stele on a plinth with a jade inscription on its -Z face
local function stele(parent, cf, h, w, o)
	o = o or {}
	local m = model(parent, o.name or "Stele")
	P(m, "Plinth", V(w + 1.2, 1.8, (o.depth or 1.2) + 1.2), cf * CFrame.new(0, -0.1, 0), C.stoneDark, M.Slate)
	P(m, "Slab", V(w, h, o.depth or 1.2), cf * CFrame.new(0, 0.8 + h / 2, 0), o.color or C.stone, M.Slate)
	P(m, "Inscription", V(math.max(0.35, w * 0.12), h * 0.6, 0.06), cf * CFrame.new(0, 0.8 + h * 0.55, -(o.depth or 1.2) / 2 - 0.02), hex("3E7F6C"), M.SmoothPlastic, { nc = true, shadow = false })
	if o.cap ~= false then
		P(m, "Cap", V(w + 0.6, 0.8, (o.depth or 1.2) + 0.5), cf * CFrame.new(0, 0.8 + h + 0.4, 0), C.stoneMid, M.Slate)
		moss(m, cf * CFrame.new(rr(-0.4, 0.4), 0.8 + h + 0.85, 0), V(w * 0.7, 0.2, (o.depth or 1.2) * 0.8))
	end
	return m
end

local function bones(parent, centre, radius, count)
	for _ = 1, count do
		local a, r = rr(0, 6.28), rr(0, radius)
		local l = rr(1.6, 3.4)
		P(parent, "Bone", V(l, 0.45, 0.45), CFrame.new(centre + V(math.cos(a) * r, 0.18, math.sin(a) * r)) * CFrame.Angles(0, rr(0, 6.28), rr(-0.2, 0.2)), C.bone, M.SmoothPlastic, { nc = true, shadow = false, shape = CYL })
	end
	P(parent, "Skull", V(1.4, 1.1, 1.7), CFrame.new(centre + V(rr(-1, 1) * radius * 0.4, 0.4, rr(-1, 1) * radius * 0.4)) * CFrame.Angles(0, rr(0, 6.28), 0.3), C.bone, M.SmoothPlastic, { nc = true })
end

local function rubble(parent, centre, radius, count, color)
	for _ = 1, count do
		local a, r = rr(0, 6.28), rr(0, radius)
		local s = rr(0.6, 2)
		P(parent, "Rubble", V(s * 1.4, s * 0.7, s), CFrame.new(centre + V(math.cos(a) * r, s * 0.15, math.sin(a) * r)) * CFrame.Angles(rr(-0.4, 0.4), rr(0, 6.28), rr(-0.4, 0.4)), color or C.stoneMid, M.Slate, { nc = true })
	end
end

-- a sword: cf at the point where it enters the ground/stone, pointing down its -Y
local function sword(parent, cf, scale, o)
	o = o or {}
	local s = scale or 1
	P(parent, "Blade", V(0.25 * s, 4.4 * s, 0.75 * s), cf * CFrame.new(0, 2 * s, 0), o.blade or C.stone, M.Metal, { nc = true })
	P(parent, "Guard", V(0.5 * s, 0.35 * s, 2 * s), cf * CFrame.new(0, 4.3 * s, 0), o.guard or C.gold, M.Metal, { nc = true })
	P(parent, "Hilt", V(0.42 * s, 1.6 * s, 0.42 * s), cf * CFrame.new(0, 5.25 * s, 0), C.woodDark, M.Wood, { nc = true })
	P(parent, "Pommel", V(0.6 * s, 0.6 * s, 0.6 * s), cf * CFrame.new(0, 6.15 * s, 0), o.guard or C.gold, M.Metal, { nc = true, shape = BALL })
end

-- shallow water: a WaterKit surface (block or round) with a bed under it, rim foam and a carve volume
-- kind "round": size = diameter; "block": size = Vector2 (x, z). surfaceY is the water top.
local function pool(parent, kind, centre, size, surfaceY, o)
	o = o or {}
	local m = model(parent, o.name or "Pool")
	local w
	if kind == "round" then
		w = WATER.ShallowWaterRound:Clone()
		w.Size = V(w.Size.X, size, size)
		w.CFrame = CFrame.new(centre.X, surfaceY - w.Size.X / 2, centre.Z) * CFrame.Angles(0, 0, math.pi / 2)
		cyl(m, "Bed", CFrame.new(centre.X, surfaceY - 1.4 - 0.5, centre.Z), 1, size + 0.6, o.bed or C.bed, M.Sand)
		carve(m, "TerrainCarve", CFrame.new(centre.X, surfaceY - 0.9, centre.Z) * CFrame.Angles(0, 0, math.pi / 2), V(1.8, size + 1, size + 1), CYL)
	else
		w = WATER.ShallowWater:Clone()
		w.Size = V(size.X, w.Size.Y, size.Y)
		w.CFrame = CFrame.new(centre.X, surfaceY - w.Size.Y / 2, centre.Z) * CFrame.Angles(0, o.yaw or 0, 0)
		P(m, "Bed", V(size.X + 0.6, 1, size.Y + 0.6), CFrame.new(centre.X, surfaceY - 1.9, centre.Z) * CFrame.Angles(0, o.yaw or 0, 0), o.bed or C.bed, M.Sand)
		carve(m, "TerrainCarve", CFrame.new(centre.X, surfaceY - 0.9, centre.Z) * CFrame.Angles(0, o.yaw or 0, 0), V(size.X + 1, 1.8, size.Y + 1))
	end
	w.Name = "Water"
	w.Anchored = true
	w.Parent = m
	WK.rimPart(w)
	return m, w
end

-- a ring of rim stones round a circle (collide; their tops stand 0.2-1 over the bank)
local function rimStones(parent, centre, radius, count, o)
	o = o or {}
	local gapA, gapW = o.gapAt, o.gapWidth or 0
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rr(-0.1, 0.1)
		if gapA and math.abs(math.atan2(math.sin(a - gapA), math.cos(a - gapA))) < gapW / 2 then
			continue
		end
		local s = rr(1.8, 3.4)
		local h = rr(1.4, 2.4)
		local p = centre + V(math.cos(a) * radius, 0, math.sin(a) * radius)
		P(parent, "RimStone", V(s * 1.3, h, s), CFrame.new(p + V(0, h / 2 - 1 + rr(0, 0.6), 0)) * CFrame.Angles(rr(-0.08, 0.08), -a + rr(-0.3, 0.3), rr(-0.08, 0.08)), rng:NextNumber() < 0.5 and C.stoneMid or C.stoneDark, M.Slate)
		if rng:NextNumber() < 0.35 then
			moss(parent, CFrame.new(p + V(0, h - 0.6, 0)) * CFrame.Angles(0, -a, 0), V(s, 0.2, s * 0.6))
		end
	end
end

-- a stair of solid blocks from a (ground) rising toward b; steps reach down to below ground
local function stair(parent, a, b, width, steps, o)
	o = o or {}
	local m = model(parent, o.name or "Stair")
	local flat = V(b.X - a.X, 0, b.Z - a.Z)
	local run = flat.Magnitude / steps
	local yaw = math.atan2(-flat.X, -flat.Z)
	local base = o.base or (a.Y - 1.5)
	for i = 1, steps do
		local t = (i - 0.5) / steps
		local top = a.Y + (b.Y - a.Y) * i / steps
		local p = a + flat * t
		local h = top - base
		P(m, "Step", V(width, h, run + 0.08), CFrame.new(p.X, base + h / 2, p.Z) * CFrame.Angles(0, yaw, 0), i % 2 == 0 and (o.color2 or C.stoneMid) or (o.color or C.stone), o.mat or M.Slate)
	end
	return m, yaw
end

-- a wooden deck run (boardwalk / jetty) along points at height y, with posts down to postBase
local function boardwalk(parent, pts, y, width, postBase, o)
	o = o or {}
	local m = model(parent, o.name or "Boardwalk")
	for i = 1, #pts - 1 do
		local a, b = V(pts[i].X, y, pts[i].Z), V(pts[i + 1].X, y, pts[i + 1].Z)
		local dir = (b - a).Unit
		local len = (b - a).Magnitude
		local a2 = a - dir * (width / 2)
		local b2 = b + dir * (i == #pts - 1 and 0 or width / 2)
		local L = (b2 - a2).Magnitude
		local cf = CFrame.lookAt((a2 + b2) / 2, b2)
		-- joists and planks across the run
		for _, s in { -1, 1 } do
			P(m, "Joist", V(0.6, 0.8, L), cf * CFrame.new(s * (width / 2 - 0.5), -0.75, 0), C.woodDark, M.Wood)
		end
		local n = math.max(1, math.floor(L / 1.25))
		for k = 1, n do
			local z = -L / 2 + (k - 0.5) * L / n
			P(m, "Plank", V(width + rr(-0.15, 0.25), 0.35, L / n - 0.12), cf * CFrame.new(rr(-0.08, 0.08), -0.17, z) * CFrame.Angles(0, rr(-0.02, 0.02), 0), k % 3 == 0 and C.woodLight or C.wood, M.WoodPlanks)
		end
		-- posts at both ends of the run
		local nPosts = math.max(2, math.floor(len / 7) + 1)
		for k = 0, nPosts - 1 do
			local p = a + dir * (len * k / (nPosts - 1))
			for _, s in { -1, 1 } do
				local q = p + cf.RightVector * s * (width / 2 - 0.4)
				cyl(m, "Post", CFrame.new(q.X, (y - 0.4 + postBase) / 2, q.Z), y - 0.4 - postBase, 0.8, C.woodDark, M.Wood)
				if o.rails ~= false then
					cyl(m, "RailPost", CFrame.new(q.X, y + 1.3, q.Z), 2.6, 0.5, C.wood, M.Wood)
				end
			end
		end
		if o.rails ~= false then
			for _, s in { -1, 1 } do
				local r0 = a + cf.RightVector * s * (width / 2 - 0.4)
				local r1 = b + cf.RightVector * s * (width / 2 - 0.4)
				beam(m, "Rail", r0 + V(0, 2.5, 0), r1 + V(0, 2.5, 0), 0.35, 0.3, C.woodLight, M.Wood)
			end
		end
	end
	return m
end

-- prefab registry ------------------------------------------------------------------------------------

local DEFS = {}
GROUP = "landmarks"
local function def(name, kind, poiName, planned, pocket, fn, extra)
	table.insert(DEFS, { name = name, kind = kind, poiName = poiName, planned = planned, pocket = pocket, fn = fn, extra = extra or {}, group = GROUP })
end

local function handpass(m, reason)
	CollectionService:AddTag(m, "NeedsHandPass")
	m:SetAttribute("HandPassReason", reason)
	m:SetAttribute("HandPassStatus", "open")
end

--[[ =========================== POCKET LANDMARKS =========================== ]]

-- P1 Wolf Den Hollow, the den crag: three moss-capped rocks leaning into a crag with a dark cave mouth
-- between them, a lintel rock over it, bones and a claw-scored stump on the trampled ground in front.
def("WolfDen", "Landmark", "Wolf Den", V(-580, 0, 780), "P1 Wolf Den Hollow", function(m)
	local crag = model(m, "Crag")
	rock(crag, "tall", V(-16, 0, 16), 38, 0.3, { name = "CragWest" })
	rock(crag, "mid", V(17, 0, 17), 30, -0.5, { name = "CragEast" })
	rock(crag, "wide", V(0.5, 10.5, 19), 13, 1.57, { name = "Lintel", sink = 0 })
	rock(crag, "low", V(1, 0, 38), 20, 0.2, { name = "CragBack" })
	-- the cave: earth floor, black walls set back inside the rocks so the mouth reads dark at any hour
	local cave = model(m, "Cave")
	P(cave, "CaveFloor", V(12, 1.5, 20), CFrame.new(0.5, -0.65, 20), C.earthDark, M.Ground)
	P(cave, "CaveBack", V(14, 16, 2), CFrame.new(0.5, 7, 30), C.cave, M.Basalt)
	P(cave, "CaveShade", V(14, 1, 20), CFrame.new(0.5, 12.5, 21), C.cave, M.Basalt, { nc = true, shadow = false })
	for _, s in { -1, 1 } do
		P(cave, "CaveSide", V(1.5, 14, 18), CFrame.new(0.5 + s * 6.4, 6, 22), C.cave, M.Basalt)
	end
	-- bones at the mouth (the trampled earth is a terrain paint for the placer)
	bones(m, V(-2, 0, 0), 6, 9)
	bones(m, V(5, 0, 8), 3, 4)
	-- claw-scored stump, a dead tree on the crag shoulder
	plant(m, "Stump_M", V(-14, 0, -6), { yaw = 0.6, scale = 0.7, collide = true, name = "ClawStump" })
	for i = -1, 1 do
		P(m, "ClawMark", V(0.15, 2.6, 0.35), CFrame.new(-11.2, 2.6, -6 + i * 0.6) * CFrame.Angles(0, 0, 0.3), C.bone, M.Wood, { nc = true, shadow = false })
	end
	plant(m, "Dead_S", V(-30, 0, 4), { yaw = 1.2, tilt = CFrame.Angles(0, 0, 0.12), collide = false, name = "DeadTree" })
	-- a cluster of three loose rocks by the east foot, ferns at the rock feet
	rock(m, "low", V(16, 0, -2), 6, 0.4)
	rock(m, "wide", V(20, 0, -7), 3.5, 1.9)
	pebble(m, V(13, 0, -6), 1.8)
	plant(m, "Fern_L", V(-8, 0, 4), {})
	plant(m, "Fern_M", V(9, 0, 4), {})
	plant(m, "Fern_S", V(-22, 0, -4), {})
	plant(m, "BushDry_S", V(26, 0, 2), { scale = 0.7 })
	fx(m, "FX_DenMist", V(0.5, 3, 12), V(12, 4, 12))
	fx(m, "FX_DenEyes", V(0.5, 4, 24))
	spot(m, "CacheSpot", V(-16, 0.5, -18))
	snd(m, "SND_DenGrowl", V(0.5, 4, 20))
	snd(m, "SND_Wind", V(0, 14, 6))
end, { note = "den crag against the West wall, cave mouth faces -Z; ring stones and rock gate are separate prefabs", handpass = "cave mouth from three library rocks and dark parts: check no sky or seam shows through the mouth from the path, and the crag sits tight to the West wall" })

-- P1: the hunting ring, standing stones at r 44 round the boss clearing, open at front (-Z) and back
def("WolfDenRing", "Landmark", "Wolf Den Ring Stones", V(-580, 0, 780), "P1 Wolf Den Hollow", function(m)
	local srcs = { KIT.Stone_1, KIT.Stone_2, KIT.Stone_3, KIT.Stone_5 }
	local i = 0
	for _, deg in { 32, 55, 80, 104, 128, 151, 208, 232, 257, 281, 306, 329 } do
		i += 1
		local a = math.rad(deg + rr(-4, 4))
		local p = V(math.sin(a) * 44, 0, -math.cos(a) * 44)
		local st = model(m, "RingStone_" .. i)
		local h = ({ 9, 12, 7.5, 10.5 })[i % 4 + 1] + rr(-1, 1)
		K(st, srcs[i % 4 + 1], p, { h = h, yaw = -a + rr(-0.3, 0.3), tilt = CFrame.Angles(rr(-0.07, 0.07), 0, rr(-0.07, 0.07)), collide = true, sink = 0.15, name = "Stone" })
		moss(st, CFrame.new(p + V(0, h * 0.82, 0)) * CFrame.Angles(0, rr(0, 6), 0), V(2.2, 0.25, 1.8))
		if i % 3 == 0 then
			plant(st, "Fern_S", p + V(rr(-2, 2), 0, rr(-2, 2)), {})
		end
		st.WorldPivot = CFrame.new(p)
	end
	-- one stone toppled across the ring line
	local p = V(math.sin(math.rad(180)) * 44, 0, -math.cos(math.rad(180)) * 44)
	local st = model(m, "RingStone_Fallen")
	K(st, KIT.Stone_1, p, { h = 4, yaw = 0.4, tilt = CFrame.Angles(0, 0, math.pi / 2 - 0.1), collide = true, sink = 0.2, name = "Stone" })
	st.WorldPivot = CFrame.new(p)
end, { reseat = true, note = "r 44 round the WolfDen boss disc; gaps at -Z (entry) and +Z (toward the den); ground each RingStone_n model separately" })

-- P1: the ambush gate on the WestArm, two rocks leaning over the path, a warning rag on a stick
def("WolfDenRockGate", "Find", "Wolf Den Rock Gate", V(-480, 0, 760), "P1 Wolf Den Hollow", function(m)
	rock(m, "tall", V(-14, 0, 0), 22, 0.4, { tilt = CFrame.Angles(0, 0, -0.1), name = "GateRockWest" })
	rock(m, "mid", V(14, 0, 2), 18, 2.3, { tilt = CFrame.Angles(0, 0, 0.12), name = "GateRockEast" })
	rock(m, "low", V(-21, 0, -7), 7, 1.1)
	pebble(m, V(19, 0, -6), 2.4, { collide = true })
	pebble(m, V(-8, 0, -5), 1.4)
	bones(m, V(2, 0, -4), 4, 5)
	-- a rag tied to a stick: someone's warning
	local stick = P(m, "WarningStick", V(0.4, 7, 0.4), CFrame.new(-7.5, 2.8, -6) * CFrame.Angles(0, 0, 0.18), C.woodDark, M.Wood)
	P(m, "Rag", V(0.1, 2.2, 1.6), stick.CFrame * CFrame.new(0, 2.6, 0.9) * CFrame.Angles(0.15, 0, 0), C.cloth, M.Fabric, { nc = true, shadow = false })
	plant(m, "BushDry_M", V(-24, 0, 4), { scale = 0.7 })
	plant(m, "Fern_M", V(9, 0, -4), {})
	spot(m, "AmbushSpot_1", V(-14, 20, 2))
	spot(m, "AmbushSpot_2", V(14, 16, 3))
	snd(m, "SND_Wind", V(0, 10, 0))
	snd(m, "SND_Crows", V(-14, 22, 2))
end, { note = "straddles the WestArm path (path runs along Z through the 14-stud gap)" })

-- P2 Bamboo Hollow: the spring under the north wall trickle. A rimmed round pool at the foot of a mossy
-- outcrop (the trickle lands at FX_FallSpray), bamboo in a horseshoe round it, a meditation stone and a
-- lantern on the open front.
def("BambooHollow", "Landmark", "Bamboo Hollow Spring", V(-330, 0, 575), "P2 Bamboo Sea + Hollow", function(m)
	local o = model(m, "Outcrop")
	rock(o, "low", V(0, 0, 19), 12, 0.2, { name = "SpringRock" })
	rock(o, "mid", V(-15, 0, 23), 18, 2.2)
	rock(o, "wide", V(13, 0, 17), 6, 0.9)
	local _, water = pool(m, "round", V(0, 0, 4), 18, -0.4, { name = "Spring" })
	rimStones(m, V(0, 0, 4), 9.6, 16, { gapAt = -math.pi / 2, gapWidth = 0.9 })
	local foam = WATER.WaterfallFoam:Clone()
	foam.CFrame = CFrame.new(1, water.Position.Y + water.Size.X / 2 + 0.05, 10)
	foam.Size = V(7, foam.Size.Y, 7)
	foam.Anchored = true
	foam.Parent = m
	fx(m, "FX_FallSpray", V(1, 0, 10))
	for _, s in { { -3, 1 }, { 4, 0 }, { -1, -2 } } do
		K(m, LIB["Stylized Foliage + Pots"].LilyPads:GetChildren()[1], V(s[1], -0.35, s[2]), { scale = rr(0.5, 0.8), yaw = rr(0, 6), sink = 0 })
	end
	-- meditation stone and mat facing the spring, a lantern on the other side of the open front
	P(m, "MeditationStone", V(6, 1.4, 5), CFrame.new(-11, 0, -8) * CFrame.Angles(0, 0.5, 0), C.stoneDark, M.Slate)
	P(m, "Mat", V(3, 0.15, 2.4), CFrame.new(-11, 0.78, -8) * CFrame.Angles(0, 0.5, 0), C.straw, M.Fabric, { nc = true, shadow = false })
	cyl(m, "IncenseBowl", CFrame.new(-8.6, 0.95, -6.6), 0.5, 1, C.goldDark, M.Metal, { nc = true })
	stoneLantern(m, V(10, 0, -9), 0.3)
	-- bamboo horseshoe, open at the front
	bamboo(m, 12, V(-22, 0, 12), 1.57)
	bamboo(m, 13, V(-25, 0, -4), 0)
	bamboo(m, 5, V(-21, 0, -16), 0.4)
	bamboo(m, 4, V(22, 0, 10), 0.8)
	bamboo(m, 14, V(25, 0, -6), 1.57)
	bamboo(m, 8, V(19, 0, -18), 2.4)
	bamboo(m, 6, V(9, 0, 27), 0)
	bamboo(m, 16, V(-6, 0, 30), math.pi)
	plant(m, "Fern_L", V(-8, 0, 13), {})
	plant(m, "Fern_M", V(9, 0, 11), {})
	plant(m, "Clover_M", V(-14, 0, -2), {})
	plant(m, "Clover_L", V(6, 0, -14), { scale = 0.7 })
	fx(m, "FX_Fireflies", V(0, 3, 0), V(26, 5, 26))
	spot(m, "PromptSpot", V(-11, 1.2, -8))
	spot(m, "CacheSpot", V(-6, 0.5, -20))
	snd(m, "SND_Trickle", V(1, 1, 10))
	snd(m, "SND_BambooWind", V(0, 14, 10))
	fx(m, "FX_LanternFlicker", V(10, 6, -9))
end, { note = "outcrop (+Z) goes against the north wall under the trickle at (-330, 560); pool needs TerrainCarve cleared", handpass = "pool sunk into terrain with a rim of stones: check the rim closes against the bank (no terrain lip over the water) and the trickle lands on FX_FallSpray" })

-- P3 Fallen Giant: a huge trunk spanning Giants Gully as the EastArm's bridge, root plate torn up at -X,
-- broken crown at +X; an invisible deck on its top and a fallen limb ramp up at the root end.
def("FallenGiant", "Landmark", "Fallen Giant", V(300, 0, 800), "P3 Fallen Giant Ravine", function(m)
	local tilt = math.atan2(1.5, 76)
	local logCF = CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, tilt)
	local log = KIT.Log_A:Clone()
	log.Name = "GiantLog"
	log.Size = V(82, 9.5, 9.5)
	log.CFrame = logCF * CFrame.Angles(0, math.pi, 0)
	log.Color = C.woodLight
	setPhysics(log, true)
	log.Parent = m
	-- walkable deck (top ~ 6.9 along the log's crown)
	P(m, "Deck", V(82, 1, 4.4), logCF * CFrame.new(0, 4.2, 0), C.wood, M.Wood, { trans = 1, shadow = false })
	moss(m, logCF * CFrame.new(-8, 4.6, 0), V(46, 0.35, 3.8))
	moss(m, logCF * CFrame.new(18, 4.45, 1.2), V(14, 0.3, 2.6), C.moss)
	-- root plate: the torn-up disc of roots and earth at -X, standing on edge
	local rp = model(m, "RootPlate")
	-- the torn-up plate of earth: overlapping discs at different sizes and offsets give a lumpy outline
	for _, d in { { 0, 8, 0, 18, 0 }, { -1.2, 9.5, 2.5, 13, 0.25 }, { -0.8, 5.5, -3, 12, -0.2 }, { -1.6, 11, -2.5, 9, 0.3 }, { -1, 3.8, 3.8, 9, -0.25 }, { -2, 8, 0.5, 8, 0.1 } } do
		P(rp, "Earth", V(3, d[4], d[4]), CFrame.new(-42 + d[1], d[2], d[3]) * CFrame.Angles(0, d[5], rr(-0.2, 0.2)), rng:NextNumber() < 0.5 and hex("7A6A55") or C.earthDark, M.Ground, { shape = CYL })
	end
	-- a fringe of roots round the rim: uneven, bent back, thinner at the tips, the low ones into the soil
	for i = 1, 22 do
		local a = rr(0, math.pi * 2)
		local up, side = math.sin(a), math.cos(a)
		local rad = rr(6.5, 8.5)
		local r0 = V(-43 - rr(0, 1), 8 + up * rad, side * rad)
		local r1 = r0 + V(-rr(1, 3), up * rr(1.5, 3.5), side * rr(1.5, 3.5))
		local r2 = r1 + V(-rr(0.5, 2), -rr(0.5, 2.5), side * rr(0, 1.5))
		local pts = { r0, r1, r2 }
		for k = 1, 2 do
			local a0, b0 = pts[k], pts[k + 1]
			if a0.Y < -0.3 then
				break
			end
			rod(rp, "Root", a0, V(b0.X, math.max(b0.Y, -0.6), b0.Z), k == 1 and rr(0.7, 1.1) or rr(0.35, 0.55), k == 1 and C.woodLight or C.wood, M.Wood, { nc = true })
		end
	end
	for _, q in { V(-44.5, 12, 3), V(-44.5, 5, -5), V(-45, 9, -1) } do
		pebble(rp, q, rr(1.5, 2.5), { sink = 0 })
	end
	for i = 1, 4 do
		P(rp, "EarthClod", V(rr(1.5, 3), rr(1, 1.8), rr(1.5, 3)), CFrame.new(-47 + rr(-3, 3), 0.3, rr(-7, 7)) * CFrame.Angles(0, rr(0, 6), 0.2), C.earthDark, M.Ground, { nc = true })
	end
	-- a fallen limb leaning on the log at the root end: the way up onto the deck
	local limbA, limbB = V(-27, -0.4, -11), V(-22, 8.3, -3.2)
	local limb = KIT.Log_A:Clone()
	limb.Name = "Limb"
	limb.Size = V((limbB - limbA).Magnitude + 2, 2.6, 2.6)
	limb.CFrame = CFrame.lookAt((limbA + limbB) / 2, limbB) * CFrame.Angles(0, math.pi / 2, 0)
	limb.Color = C.woodLight
	setPhysics(limb, false)
	limb.Parent = m
	local ramp = beam(m, "LimbRamp", limbA + V(0, 1.2, 0), limbB + V(0, 1.2, 0), 3.2, 1, C.wood, M.Wood)
	ramp.Transparency = 1
	-- crown: broken branches lying at +X
	plant(m, "Dead_M", V(46, 0, 2), { yaw = 0.1, tilt = CFrame.Angles(0, 0, -1.35), sink = 0.12, collide = false, name = "Crown" })
	for i = 1, 3 do
		rod(m, "Splinter", V(39.5, 4.5, -1.5 + i), V(41 + i, 6 + i * 0.8, -2 + i * 1.2), 0.6, C.woodPale, M.Wood, { nc = true })
	end
	-- life on the log: shelf mushrooms, ferns at both banks
	for i = 1, 5 do
		local p = (logCF * CFrame.new(-30 + i * 11, 2, 4.6 * (i % 2 == 0 and 1 or -1))).Position
		for k = 0, 2 do
			P(m, "ShelfFungus", V(2 - k * 0.5, 0.4, 1.5 - k * 0.3), CFrame.new(p + V(k * 0.9, -k * 0.7, 0)) * CFrame.Angles(0, rr(0, 6), 0), k == 0 and C.straw or C.gold, M.SmoothPlastic, { nc = true })
		end
	end
	plant(m, "Mushroom_L", V(-30, 0, 6), { scale = 0.7 })
	plant(m, "Fern_L", V(-33, 0, -6), {})
	plant(m, "Fern_M", V(34, 0, -5), {})
	rock(m, "low", V(-31, 0, 9), 5, 0.6)
	pebble(m, V(34, 0, 7), 2.6, { collide = true })
	snd(m, "SND_WoodCreak", V(0, 5, 0))
	snd(m, "SND_Birds", V(44, 8, 2))
	fx(m, "FX_GullyMist", V(0, -2, 0), V(60, 3, 14))
end, { note = "log runs along X across the gully; pivot = bank level at mid-span; the gully floor is the placer's terrain, the log ends rest on both banks (x +-38)", handpass = "walkable log bridge (invisible Deck + LimbRamp): check both ends rest on the gully banks, the limb ramp reaches the ground and the deck top matches the log" })

-- P4 Twin-Jade Spring: the Qi Spring shrine at the fall pool under the SouthEastFar karst. A rimmed pool,
-- the twin falls landing at its back, a small lacquered shrine on a stone platform at its side with
-- jade lamps, a stele, bamboo by the water.
def("TwinJadeSpring", "Landmark", "Twin-Jade Spring", V(580, 0, 1210), "P4 Twin-Jade Spring", function(m)
	local back = model(m, "FallRocks")
	rock(back, "tall", V(-13, 0, 26), 22, 0.1)
	rock(back, "mid", V(13, 0, 25), 18, 2.6)
	rock(back, "low", V(0, 0, 21), 8, 1.4)
	local _, water = pool(m, "round", V(0, 0, 6), 24, -0.4, { name = "SpringPool" })
	rimStones(m, V(0, 0, 6), 12.6, 20, { gapAt = -math.pi / 2 - 0.4, gapWidth = 0.7 })
	for i, x in { -5, 6 } do
		local foam = WATER.WaterfallFoam:Clone()
		foam.CFrame = CFrame.new(x, water.Position.Y + water.Size.X / 2 + 0.05, 13)
		foam.Size = V(7, foam.Size.Y, 7)
		foam.Anchored = true
		foam.Parent = m
		fx(m, "FX_FallSpray_" .. i, V(x, 0, 13))
	end
	for _, s in { { -6, 2 }, { -3, -1 }, { 7, 4 }, { 3, 0 }, { -8, 7 } } do
		K(m, LIB["Stylized Foliage + Pots"].LilyPads:GetChildren()[rng:NextInteger(1, 4)], V(s[1], -0.35, s[2]), { scale = rr(0.5, 0.8), yaw = rr(0, 6), sink = 0 })
	end
	-- the shrine: a stone platform with three steps, a lacquered shrine house with an altar and spirit stone
	local sh = model(m, "Shrine")
	local sx, sz = -21, -4
	P(sh, "Platform", V(11, 3.2, 10), CFrame.new(sx, 0, sz), C.stoneMid, M.Slate)
	P(sh, "PlatformCap", V(11.6, 0.4, 10.6), CFrame.new(sx, 1.7, sz), C.stone, M.Slate)
	stair(sh, V(sx, 0, sz - 8.2), V(sx, 1.9, sz - 5), 5, 3, { name = "Steps" })
	local hcf = CFrame.new(sx, 1.9, sz + 1.5)
	P(sh, "BackWall", V(7, 6, 0.6), hcf * CFrame.new(0, 3, 2.6), C.lacquerDark, M.WoodPlanks)
	for _, s in { -1, 1 } do
		P(sh, "SideWall", V(0.6, 6, 5), hcf * CFrame.new(s * 3.2, 3, 0.4), C.lacquerDark, M.WoodPlanks)
		cyl(sh, "Column", hcf * CFrame.new(s * 3.2, 3, -2.3), 6, 0.8, C.lacquer, M.Wood)
	end
	P(sh, "Lintel", V(7.4, 0.7, 0.7), hcf * CFrame.new(0, 5.8, -2.3), C.lacquer, M.Wood)
	roof(sh, hcf * CFrame.new(0, 6.4, 0.2), 8.6, 7.8, 2.4)
	P(sh, "Altar", V(4, 1.6, 1.8), hcf * CFrame.new(0, 0.8, 1.2), C.stoneDark, M.Slate)
	P(sh, "SpiritStone", V(1.1, 1.8, 1.1), hcf * CFrame.new(0, 2.5, 1.3) * CFrame.Angles(0.1, 0.5, 0.1), C.jadeLight, M.Neon, { nc = true })
	cyl(sh, "Censer", hcf * CFrame.new(0, 1.9, -0.6), 0.6, 1.2, C.goldDark, M.Metal, { nc = true })
	jadeLamp(sh, V(sx - 4.6, 1.9, sz - 4.2), 0)
	jadeLamp(sh, V(sx + 4.6, 1.9, sz - 4.2), 0)
	fx(sh, "FX_ShrineIncense", hcf * CFrame.new(0, 2.6, -0.6))
	stele(m, at(17, 0, -3, -0.4), 6, 2.8, { name = "SpringStele" })
	-- bamboo by the water on the east side, reeds at the rim
	bamboo(m, 13, V(26, 0, 10), 0.3)
	bamboo(m, 16, V(24, 0, -6), -1.57)
	bamboo(m, 8, V(19, 0, 20), 1)
	plant(m, "Reeds", V(-11, 0, 13), { scale = 1.4 })
	plant(m, "Reeds", V(11, 0, -3), { scale = 1.2 })
	plant(m, "Fern_M", V(-16, 0, 10), {})
	plant(m, "Clover_M", V(8, 0, -12), {})
	-- the node's ground: a clear flat stone apron in front of the pool
	cyl(m, "NodeApron", CFrame.new(4, -0.4, -13), 1, 9, C.paveDark, M.Slate)
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + 0.4
		P(m, "ApronStone", V(1.6, 0.6, 1.2), CFrame.new(4 + math.cos(a) * 5, 0, -13 + math.sin(a) * 5) * CFrame.Angles(0, -a, 0), C.stoneMid, M.Slate, { nc = true })
	end
	spot(m, "QiNodeSpot", V(4, 0.2, -13))
	spot(m, "PromptSpot", V(sx, 0.5, sz - 10))
	fx(m, "FX_QiSpring", V(0, 2, 6), V(20, 4, 20))
	snd(m, "SND_Waterfall", V(0, 4, 14))
	snd(m, "SND_Shrine", hcf * CFrame.new(0, 3, 0))
	fx(m, "FX_FallMist", V(0, 3, 12), V(22, 6, 8))
	fx(m, "FX_QiMotes", V(4, 2, -13), V(8, 4, 8))
end, { note = "rocks (+Z) go against the SouthEastFar karst foot where the twin falls land; QiNode3 sits on NodeApron", handpass = "shrine house (walls, columns, part roof) on a stepped platform, pool sunk into terrain: check the roof eaves, the steps meeting the ground and the pool rim against the bank" })

-- P5 Hunter's Camp: a hide tent, a fire with a spit and log benches, a drying rack, stores, a lantern on a
-- pole, and the hero, a log lookout tower with a ladder (TrussPart) and a little roof.
def("HuntersCamp", "Landmark", "Hunter's Camp", V(660, 0, 700), "P5 Hunter's Camp", function(m)
	-- fire ring
	local fire = model(m, "Fire")
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		P(fire, "FireStone", V(1.3, 0.9, 1.1), CFrame.new(math.cos(a) * 2.5, 0.2, math.sin(a) * 2.5) * CFrame.Angles(0, a, 0), C.stoneDark, M.Slate, { nc = true })
	end
	for i = 0, 2 do
		P(fire, "FireLog", V(3.6, 0.6, 0.6), CFrame.new(0, 0.55, 0) * CFrame.Angles(0, i * 2.1, 0.35), C.char, M.Wood, { nc = true, shape = CYL })
	end
	light(P(fire, "Embers", V(1.8, 0.3, 1.8), CFrame.new(0, 0.3, 0), C.ember, M.Neon, { nc = true, shadow = false }), 12, 0.7)
	for _, s in { -1, 1 } do
		rod(fire, "SpitPost", V(s * 3, -0.5, 0), V(s * 3, 3.6, 0), 0.35, C.woodDark, M.Wood, { nc = true })
	end
	rod(fire, "Spit", V(-3.4, 3.4, 0), V(3.4, 3.4, 0), 0.25, C.woodDark, M.Wood, { nc = true })
	P(fire, "Meat", V(1.8, 1, 1), CFrame.new(0, 3.1, 0), C.hide, M.SmoothPlastic, { nc = true, shape = BALL })
	fx(fire, "FX_Campfire", V(0, 0.8, 0))
	-- log benches
	K(m, KIT.Log_B, V(-5.5, 0, -2), { yaw = 1.3, scale = 0.42, collide = true, sink = 0.25, name = "Bench" })
	K(m, KIT.Log_A, V(2, 0, -6), { yaw = 0.15, scale = 0.38, collide = true, sink = 0.25, name = "Bench" })
	-- A-frame hide tent, open toward the fire
	local tent = model(m, "Tent")
	local tcf = CFrame.new(-11, 0, 9) * CFrame.Angles(0, 0.35, 0)
	local half, ht, len = 4, 6.2, 10
	local ang = math.atan2(ht, half)
	local sl = math.sqrt(half * half + ht * ht)
	for _, s in { -1, 1 } do
		P(tent, "Hide", V(0.25, sl, len), tcf * CFrame.new(s * half / 2, ht / 2, 0) * CFrame.Angles(0, 0, s * (math.pi / 2 - ang)), s < 0 and C.hide or C.hideLight, M.Fabric)
		rod(tent, "Pole", (tcf * CFrame.new(s * half, 0, -len / 2)).Position, (tcf * CFrame.new(0, ht + 0.6, -len / 2)).Position, 0.35, C.woodDark, M.Wood, { nc = true })
		rod(tent, "Pole", (tcf * CFrame.new(s * half, 0, len / 2)).Position, (tcf * CFrame.new(0, ht + 0.6, len / 2)).Position, 0.35, C.woodDark, M.Wood, { nc = true })
	end
	rod(tent, "RidgePole", (tcf * CFrame.new(0, ht + 0.3, -len / 2 - 0.6)).Position, (tcf * CFrame.new(0, ht + 0.3, len / 2 + 0.6)).Position, 0.4, C.woodDark, M.Wood, { nc = true })
	for _, s in { -1, 1 } do
		wedge(tent, "BackFlap", V(0.2, ht, half), tcf * CFrame.new(s * half / 2, ht / 2, len / 2 - 0.1) * CFrame.Angles(0, s * math.pi / 2, 0), C.hide, M.Fabric, { nc = true })
	end
	P(tent, "Furs", V(6, 0.3, 8), tcf * CFrame.new(0, 0.1, 0.5), C.hideLight, M.Fabric, { nc = true, shadow = false })
	-- drying rack with hides
	local rack = model(m, "DryingRack")
	local rcf = CFrame.new(10, 0, 4) * CFrame.Angles(0, -0.5, 0)
	for _, s in { -3.4, 3.4 } do
		P(rack, "RackPost", V(0.5, 7.5, 0.5), rcf * CFrame.new(s, 2.8, 0), C.wood, M.Wood)
	end
	P(rack, "RackBar", V(7.8, 0.4, 0.4), rcf * CFrame.new(0, 6.2, 0), C.wood, M.Wood, { nc = true })
	P(rack, "Hide", V(2.8, 3.6, 0.12), rcf * CFrame.new(-1.7, 4.3, 0) * CFrame.Angles(0, 0, 0.05), C.hide, M.Fabric, { nc = true })
	P(rack, "Hide", V(2.4, 3, 0.12), rcf * CFrame.new(1.7, 4.6, 0) * CFrame.Angles(0, 0, -0.04), C.hideLight, M.Fabric, { nc = true })
	-- stores by the tent's back
	K(m, PROPS["Stylized Barrel II"], V(-4, 0, 15), { yaw = 0.3, collide = true })
	K(m, PROPS["Box Crate"], V(-1, 0, 16.5), { yaw = 0.8, collide = true })
	K(m, PROPS["Sack 1"], V(-6.5, 0, 17), { yaw = 1.1 })
	K(m, PROPS["Stylized Barrel I"], V(-2, 0, 13), { yaw = 0.2, collide = true })
	K(m, KIT.LogPile, V(-18, 0, -2), { yaw = 1.4, scale = 0.45, collide = true, name = "Firewood" })
	-- the lookout tower
	local tw = model(m, "Lookout")
	local tx, tz, half2, floorY = 14, 17, 3.6, 15
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local b = V(tx + sx * half2, -1.5, tz + sz * half2)
			rod(tw, "TowerPost", b, b + V(-sx * 0.4, floorY + 7.5, -sz * 0.4), 1, C.wood, M.Wood)
		end
	end
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 } } do
		-- X braces on three sides (the ladder side stays open)
		local function corner(u, y)
			if side[1] ~= 0 then
				return V(tx + side[1] * half2, y, tz + u * half2)
			end
			return V(tx + u * half2, y, tz + side[2] * half2)
		end
		rod(tw, "Brace", corner(-1, 1), corner(1, floorY - 1), 0.5, C.woodDark, M.Wood, { nc = true })
		rod(tw, "Brace", corner(1, 1), corner(-1, floorY - 1), 0.5, C.woodDark, M.Wood, { nc = true })
	end
	P(tw, "Floor", V(half2 * 2 + 1.6, 0.7, half2 * 2 + 1.6), CFrame.new(tx, floorY - 0.35, tz), C.woodLight, M.WoodPlanks)
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 } } do
		local c = V(tx + side[1] * (half2 + 0.5), floorY + 1.6, tz + side[2] * (half2 + 0.5))
		P(tw, "Rail", side[1] ~= 0 and V(0.4, 0.4, half2 * 2 + 1) or V(half2 * 2 + 1, 0.4, 0.4), CFrame.new(c), C.wood, M.Wood)
		P(tw, "RailBoard", side[1] ~= 0 and V(0.2, 1.2, half2 * 2 + 1) or V(half2 * 2 + 1, 1.2, 0.2), CFrame.new(c - V(0, 0.9, 0)), C.woodDark, M.WoodPlanks)
	end
	roof(tw, CFrame.new(tx, floorY + 6.6, tz), half2 * 2 + 2.4, half2 * 2 + 2.4, 2.4, { color = C.hide, color2 = C.hideLight, mat = M.Fabric, gableColor = C.woodDark })
	-- ladder up the open (-Z) side: visual rails and rungs, an invisible TrussPart players climb
	local lz = tz - half2 - 1.1
	for _, s in { -1, 1 } do
		rod(tw, "LadderRail", V(tx + s * 1.1, -0.5, lz - 0.6), V(tx + s * 1.1, floorY + 2.2, lz), 0.35, C.woodPale, M.Wood, { nc = true })
	end
	for k = 1, 12 do
		local y = k * 1.25
		local zz = lz - 0.6 + 0.6 * (y + 0.5) / (floorY + 2.7)
		P(tw, "Rung", V(2.2, 0.25, 0.3), CFrame.new(tx, y, zz), C.woodPale, M.Wood, { nc = true })
	end
	local truss = Instance.new("TrussPart")
	truss.Name = "LadderTruss"
	truss.Size = V(2, 16, 2)
	truss.CFrame = CFrame.new(tx, floorY - 7.6, lz + 0.2)
	truss.Anchored = true
	truss.Transparency = 1
	truss.CanTouch = false
	truss.Parent = tw
	fx(tw, "FX_LookoutFlag", V(tx, floorY + 9.5, tz))
	-- lantern pole by the way in, a trophy skull on a stake
	local lp = K(m, INNO.Wood_Iron_Assets.Lantern_Pole, V(-9, 0, -12), { yaw = 0.4, scale = 1.2, collide = true, name = "Lantern" })
	local _, mx = bounds(lp)
	light(P(lp, "LightAnchor", V(0.5, 0.5, 0.5), CFrame.new((lp:GetBoundingBox()).Position.X, mx.Y - 2, (lp:GetBoundingBox()).Position.Z), C.ember, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 }), 12, 0.8)
	P(m, "TrophyStake", V(0.5, 6, 0.5), CFrame.new(7, 2.4, -11), C.woodDark, M.Wood)
	P(m, "TrophySkull", V(1.8, 1.4, 2.2), CFrame.new(7, 5.8, -11.2) * CFrame.Angles(0.2, 0, 0), C.bone, M.SmoothPlastic, { nc = true })
	for _, s in { -1, 1 } do
		rod(m, "Tusk", V(7 + s * 0.6, 5.4, -12.2), V(7 + s * 1.3, 6.6, -13), 0.3, C.bone, M.SmoothPlastic, { nc = true })
	end
	plant(m, "Fern_M", V(-16, 0, 14), {})
	plant(m, "BushDry_S", V(22, 0, 4), { scale = 0.6 })
	plant(m, "Clover_M", V(4, 0, 10), {})
	spot(m, "CacheSpot", V(19, 0.5, -6))
	spot(m, "PromptSpot", V(0, 0.5, -4))
	snd(m, "SND_Campfire", V(0, 1, 0))
	snd(m, "SND_Wind", V(14, 18, 17))
	fx(m, "FX_LanternFlicker", V(-9, 9, -12))
end, { note = "set it on the NE rise; the tower (+X,+Z corner) is the hero, ladder faces -Z", handpass = "log lookout tower with an invisible TrussPart ladder and a hide roof, A-frame tent: check posts reach the ground on a slope, the climb tops out onto the floor, and the tent panels meet at the ridge" })

-- P6 Three Pillars Hermitage: a hermit's hut on a stone terrace at the karst feet, his herb bed and stove,
-- and a ledge stair climbing the buttress rock to a landing (V7 continues from there later).
def("ThreePillarsHermitage", "Landmark", "Three Pillars Hermitage", V(-560, 0, 1170), "P6 Three Pillars Hermitage", function(m)
	local b = model(m, "Buttress")
	rock(b, "tall", V(2, 0, 24), 34, 0.15, { name = "ButtressMain" })
	rock(b, "mid", V(-20, 0, 21), 22, 2.0)
	rock(b, "mid", V(32, 0, 14), 15, 1.2, { name = "CleftRock" })
	rock(b, "low", V(20, 0, 30), 12, 0.3, { name = "LandingRock" })
	rock(b, "low", V(-29, 0, 8), 8, 0.7)
	-- terrace
	local t = model(m, "Terrace")
	P(t, "TerraceBody", V(17, 3.6, 12), CFrame.new(-3, 0.2, 2), C.stoneMid, M.Slate)
	P(t, "TerraceTop", V(17.6, 0.4, 12.6), CFrame.new(-3, 2.2, 2), C.paveDark, M.Slate)
	stair(t, V(-3, 0, -6.5), V(-3, 2.4, -4), 5, 3, { name = "TerraceSteps" })
	-- the hut
	local h = model(m, "Hut")
	local hcf = CFrame.new(-3, 2.4, 3.2)
	local W, D, H = 10, 7, 6.2
	P(h, "BackWall", V(W, H, 0.5), hcf * CFrame.new(0, H / 2, D / 2), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		P(h, "SideWall", V(0.5, H, D), hcf * CFrame.new(s * W / 2, H / 2, 0), C.woodLight, M.WoodPlanks)
		P(h, "FrontWall", V(3.3, H, 0.5), hcf * CFrame.new(s * (W / 2 - 1.65), H / 2, -D / 2), C.woodLight, M.WoodPlanks)
		for _, z in { -1, 1 } do
			P(h, "CornerPost", V(0.8, H + 0.4, 0.8), hcf * CFrame.new(s * W / 2, (H + 0.4) / 2, z * D / 2), C.woodDark, M.Wood)
		end
	end
	P(h, "DoorLintel", V(3.6, 1.2, 0.6), hcf * CFrame.new(0, H - 0.6, -D / 2), C.woodDark, M.Wood)
	for _, s in { -1, 1 } do
		P(h, "Curtain", V(1.5, 2.6, 0.08), hcf * CFrame.new(s * 0.8, H - 2.5, -D / 2 - 0.3) * CFrame.Angles(0, 0, s * 0.05), hex("3E4A6B"), M.Fabric, { nc = true, shadow = false })
	end
	P(h, "Interior", V(W - 1, H - 0.4, 0.2), hcf * CFrame.new(0, H / 2, D / 2 - 0.4), C.char, M.Wood, { nc = true, shadow = false })
	P(h, "Window", V(0.6, 1.4, 2), hcf * CFrame.new(-W / 2, 3.6, 0), C.char, M.Wood, { nc = true })
	P(h, "FloorMat", V(W - 1, 0.1, D - 1), hcf * CFrame.new(0, 0.06, 0), C.straw, M.Fabric, { nc = true, shadow = false })
	P(h, "LowTable", V(2.4, 0.9, 1.6), hcf * CFrame.new(1.5, 0.45, 1.2), C.wood, M.Wood)
	roof(h, hcf * CFrame.new(0, H, 0), W + 2.6, D + 2.6, 2.8)
	-- life round the hut: water jar, stove, firewood, a herb bed with stake fence
	cyl(m, "WaterJar", CFrame.new(3.6, 3.4, -3.6), 2.2, 1.8, C.earthDark, M.Slate)
	P(m, "Stove", V(2.4, 2, 2), CFrame.new(-9.5, 3.4, -2), C.stoneDark, M.Slate)
	P(m, "StoveMouth", V(1, 0.8, 0.1), CFrame.new(-9.5, 3, -3.02), C.ember, M.Neon, { nc = true, shadow = false })
	cyl(m, "Pot", CFrame.new(-9.5, 4.8, -2), 0.8, 1.6, C.iron, M.Metal, { nc = true })
	for k = 0, 3 do
		rod(m, "Firewood", V(-12.6, 2.6 + k * 0.55, -0.5 + (k % 2) * 0.3), V(-12.6, 2.6 + k * 0.55, 4.5), 0.55, k % 2 == 0 and C.woodPale or C.woodLight, M.Wood, { nc = true })
	end
	local bed = model(m, "HerbBed")
	P(bed, "BedSoil", V(7, 1, 4.5), CFrame.new(-15, 0.1, -10), C.earthDark, M.Ground)
	for i = 1, 9 do
		local px, pz = -17.6 + (i - 1) % 3 * 2.6, -11.4 + math.floor((i - 1) / 3) * 1.4
		P(bed, "Herb", V(0.9, rr(0.9, 1.5), 0.9), CFrame.new(px, 1.1, pz) * CFrame.Angles(0, rr(0, 6), 0), i % 4 == 0 and C.jadeLight or C.lawn, M.LeafyGrass, { nc = true, shadow = false })
	end
	for i = 0, 7 do
		local px = -19 + i * 8 / 7
		P(bed, "Stake", V(0.25, 1.6, 0.25), CFrame.new(px, 0.6, -12.7), C.woodPale, M.Wood, { nc = true })
	end
	beam(bed, "StakeRail", V(-19, 1.1, -12.7), V(-11, 1.1, -12.7), 0.15, 0.15, C.woodPale, M.Wood, { nc = true })
	-- the ledge stair: a flight cut up the cleft between the buttress and CleftRock to a landing on
	-- LandingRock (V7 continues from there later)
	local ls = stair(m, V(20.5, 0, 3), V(20.5, 11, 19), 4, 12, { name = "LedgeStair", color = C.stoneDark, color2 = C.stoneMid })
	for _, sx in { -1, 1 } do
		P(ls, "StairCheek", V(1.4, 7, 15), CFrame.new(20.5 + sx * 2.7, 3, 12) * CFrame.Angles(math.atan2(11, 16) * -0.6, 0, 0), C.stoneMid, M.Slate)
	end
	P(m, "Landing", V(6.5, 12.5, 6), CFrame.new(20.5, 4.75, 22), C.stoneDark, M.Slate)
	for k = 3, 11, 4 do
		moss(ls, CFrame.new(20.5 + rr(-1, 1), k + 0.05, 3 + k * 16 / 11), V(1.6, 0.2, 1))
	end
	stoneLantern(m, V(22.5, 11, 23.5), 0, false)
	spot(m, "LedgeUp", V(20.5, 11.5, 24))
	plant(m, "Fern_S", V(18.5, 11, 23.5), {})
	-- a pine at the west edge, clear of the roof
	tree(m, INNO.Pine_Trees.Variation_03["Pine_03.4"], V(-30, 0, -6), { h = 34, yaw = 0.8, name = "HermitPine" })
	plant(m, "Fern_M", V(8, 0, -6), {})
	plant(m, "Clover_M", V(-22, 0, -2), {})
	spot(m, "HermitSpot", V(-3, 2.6, -2.5))
	spot(m, "QiNodeSpot", V(16, 0.2, -12))
	fx(m, "FX_HutSmoke", V(-9.5, 6.5, -2))
	snd(m, "SND_WindChime", V(-3, 8.4, -1))
	snd(m, "SND_Stove", V(-9.5, 4, -2))
	snd(m, "SND_Wind", V(30, 14, 9))
	fx(m, "FX_Fireflies", V(-15, 2, -10), V(10, 3, 6))
end, { note = "buttress rocks (+Z) stand in for the SouthWestFar karst foot: drop them where the real pillar is and re-hug the LedgeStair to it", handpass = "hut (walls, part roof) on a terrace, a stair up a rock cleft to a landing: check the stair meets ground and landing, cheeks hide the step ends, the hut roof clears the buttress and the pine" })

-- P7 Lotus Mere: a shallow walkable mere (one unioned WaterKit surface over a sand bed), a lacquered
-- pavilion on a stone pier in the water, a zig-zag boardwalk out to it, lotus clusters, reeds, a skiff
-- pulled up on the west bank, a willow-like tree and a little bamboo on the north shore.
def("LotusMere", "Landmark", "Lotus Mere", V(-260, 0, 1170), "P7 Lotus Mere", function(m)
	local circles = { { V(-16, 0, 4), 21 }, { V(15, 0, -2), 18 }, { V(2, 0, 19), 13 } }
	local surfY = -0.4
	-- the surface: a union of three upright discs
	local parts = {}
	for _, c in circles do
		local p = Instance.new("Part")
		p.Shape = CYL
		p.Size = V(0.4, c[2] * 2, c[2] * 2)
		p.CFrame = CFrame.new(c[1].X, surfY - 0.2, c[1].Z) * CFrame.Angles(0, 0, math.pi / 2)
		p.Anchored = true
		p.Parent = workspace
		table.insert(parts, p)
	end
	local ok, union = pcall(function()
		return parts[1]:UnionAsync({ parts[2], parts[3] })
	end)
	for _, p in parts do
		p:Destroy()
	end
	local waterM = model(m, "Mere")
	if ok and union then
		union.Name = "Water"
		union.Anchored = true
		union.Parent = waterM
		WK.dress(union)
	else
		warn("LotusMere: union failed, using separate discs", union)
		for i, c in circles do
			local w = WATER.ShallowWaterRound:Clone()
			w.Size = V(w.Size.X, c[2] * 2, c[2] * 2)
			w.CFrame = CFrame.new(c[1].X, surfY - w.Size.X / 2 + i * 0.01, c[1].Z) * CFrame.Angles(0, 0, math.pi / 2)
			w.Anchored = true
			w.Name = "Water"
			w.Parent = waterM
		end
	end
	-- outline for the rim foam: points on each circle (1 stud in) not inside another, ordered by angle
	local centroid = V(0, 0, 6)
	local pts = {}
	for i, c in circles do
		for k = 0, 71 do
			local a = k / 72 * math.pi * 2
			local p = c[1] + V(math.cos(a), 0, math.sin(a)) * (c[2] - 1)
			local inside = false
			for j, o in circles do
				if j ~= i and (V(p.X, 0, p.Z) - o[1]).Magnitude < o[2] - 0.5 then
					inside = true
				end
			end
			if not inside then
				table.insert(pts, { p = V(p.X, surfY + 0.06, p.Z), a = math.atan2(p.Z - centroid.Z, p.X - centroid.X) })
			end
		end
	end
	-- counter-clockwise seen from above (bank on the right): decreasing atan2(z, x) with +Z south
	table.sort(pts, function(a, b)
		return a.a > b.a
	end)
	local line = {}
	for i, q in pts do
		if i % 3 == 1 then
			table.insert(line, q.p)
		end
	end
	WK.rimAlong(waterM, line, true)
	for _, c in circles do
		cyl(waterM, "Bed", CFrame.new(c[1].X, surfY - 1.9, c[1].Z), 1, c[2] * 2 + 0.6, C.bed, M.Sand)
		-- sand shore band: dig the terrain to its top so a pale beach shows round the water
		local shore = cyl(waterM, "Shore", CFrame.new(c[1].X, -1, c[1].Z), 1, c[2] * 2 + 5, C.sand, M.Sand)
		shore:SetAttribute("Note", "sand beach band just under the water top; the placer digs terrain to its top (Y -0.5 local) inside it")
		carve(waterM, "TerrainCarve", CFrame.new(c[1].X, -1.5, c[1].Z) * CFrame.Angles(0, 0, math.pi / 2), V(2, c[2] * 2 + 5, c[2] * 2 + 5), CYL)
	end
	-- the pavilion on its stone pier, out in the east lobe
	local pav = model(m, "Pavilion")
	local px, pz = 16, -2
	P(pav, "Pier", V(22, 3.4, 22), CFrame.new(px, -0.9, pz), C.stoneMid, M.Slate)
	P(pav, "PierCap", V(22.8, 0.5, 22.8), CFrame.new(px, 0.85, pz), C.stone, M.Slate)
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		moss(pav, CFrame.new(px + s[1] * 10.6, 0.4, pz + s[2] * 10.6), V(2.4, 0.3, 2.4))
	end
	local temple = K(pav, MD["Temple Structure"], V(px, 1.05, pz), { w = 19, yaw = 0, sink = 0, collide = false, name = "PavilionMesh" })
	local tmn, tmx = bounds(temple)
	local tH = tmx.Y - tmn.Y
	-- invisible colliders: the temple's own platform and its four columns
	P(pav, "FloorCollider", V(tmx.X - tmn.X - 2.2, tH * 0.085, tmx.Z - tmn.Z - 2.2), CFrame.new(px, tmn.Y + tH * 0.0425, pz), C.stone, M.Slate, { trans = 1, shadow = false })
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		cyl(pav, "ColumnCollider", CFrame.new(px + s[1] * (tmx.X - tmn.X) * 0.3, tmn.Y + tH * 0.4, pz + s[2] * (tmx.Z - tmn.Z) * 0.3), tH * 0.6, 1.4, C.lacquer, M.Wood, { trans = 1, shadow = false })
	end
	stoneLantern(pav, V(px - 9.5, 1.1, pz - 9.5), 0)
	-- zig-zag boardwalk from the south bank to the pier
	boardwalk(m, { V(2, 0, -26), V(2, 0, -19), V(9, 0, -15), V(9, 0, -12.6) }, 1.1, 4, -1.9, { name = "Boardwalk" })
	-- lotus clusters (5, 3 and 1) and reeds on the west shallows
	local lily = LIB["Stylized Foliage + Pots"].LilyPads:GetChildren()
	for _, cl in { { V(-20, 0, 0), 5, 5 }, { V(-6, 0, 18), 3, 3 }, { V(-27, 0, 14), 1, 1 } } do
		for _ = 1, cl[2] do
			K(m, lily[rng:NextInteger(1, #lily)], cl[1] + V(rr(-cl[3], cl[3]), surfY + 0.05, rr(-cl[3], cl[3])), { scale = rr(0.6, 1), yaw = rr(0, 6), sink = 0, name = "Lotus" })
		end
	end
	for _, p in { V(-35, 0, -2), V(-34, 0, 4), V(-31, 0, -8), V(-8, 0, 30), V(28, 0, 8) } do
		plant(m, "Reeds", p, { scale = rr(1.2, 1.7) })
	end
	-- a skiff pulled up on the west bank
	local boat = model(m, "Skiff")
	local bcf = CFrame.new(-40, 0, 6) * CFrame.Angles(0, 0.4, 0) * CFrame.Angles(0, 0, 0.06)
	P(boat, "Hull", V(3.6, 1.2, 11), bcf * CFrame.new(0, 0.4, 0), C.wood, M.WoodPlanks)
	for _, s in { -1, 1 } do
		wedge(boat, "Bow", V(3.6, 1.2, 2.4), bcf * CFrame.new(0, 0.4, s * 6.7) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0), C.wood, M.WoodPlanks)
		P(boat, "Gunwale", V(0.3, 0.5, 11.4), bcf * CFrame.new(s * 1.85, 1.2, 0), C.woodDark, M.Wood)
	end
	P(boat, "Inside", V(3, 0.2, 10), bcf * CFrame.new(0, 0.95, 0), C.woodDark, M.WoodPlanks, { nc = true })
	P(boat, "Thwart", V(3.4, 0.3, 0.8), bcf * CFrame.new(0, 1.15, 1), C.woodLight, M.Wood, { nc = true })
	rod(boat, "Oar", (bcf * CFrame.new(-0.6, 1.3, -3)).Position, (bcf * CFrame.new(1.4, 1.5, 4)).Position, 0.3, C.woodPale, M.Wood, { nc = true })
	-- the willow-like tree and bamboo on the north shore, rocks on the south-west bank
	tree(m, KIT.Wide_M, V(-30, 0, 30), { h = 30, name = "ShoreTree" })
	bamboo(m, 14, V(14, 0, 38), 0.2)
	bamboo(m, 16, V(4, 0, 38), 0)
	bamboo(m, 8, V(26, 0, 32), 2.2)
	rock(m, "low", V(-26, 0, -18), 6, 0.5)
	rock(m, "wide", V(-20, 0, -22), 3.5, 2.1)
	pebble(m, V(-31, 0, -14), 2)
	plant(m, "Fern_M", V(-24, 0, -24), {})
	plant(m, "Clover_L", V(30, 0, -18), { scale = 0.7 })
	spot(m, "QiNodeSpot", V(-30, 0.2, -26))
	spot(m, "PromptSpot", V(px, 3, pz))
	fx(m, "FX_Fireflies", V(0, 2.5, 4), V(60, 4, 44))
	fx(m, "FX_LotusMist", V(-8, 0.5, 6), V(50, 2, 36))
	snd(m, "SND_Frogs", V(-20, 0.5, 2))
	snd(m, "SND_WaterLap", V(9, 0.5, -13))
	snd(m, "SND_WindChime", V(16, 12, -2))
	fx(m, "FX_LanternFlicker", V(6.5, 5, -11.5))
	fx(m, "FX_Dragonflies", V(-10, 2, 8), V(30, 3, 20))
end, { note = "dig terrain to the Shore tops (TerrainCarve parts) before placing; the boardwalk lands on the south (-Z) bank", handpass = "pavilion mesh on a stone pier in the water with invisible colliders, a zig-zag boardwalk on posts: check the boardwalk meets the bank and the pier steps, colliders match the mesh floor, posts reach the bed" })

-- Hero: Shrine Terrace. A raised stone terrace (6 up) with a balustrade, a front stair flanked by lit
-- stone lanterns, the weathered pavilion at its back, an incense brazier and kneeling stone before it,
-- jade lamps at the porch, an old pine behind the west corner and a bamboo grove at the east.
def("ShrineTerrace", "Landmark", "Shrine Terrace", V(-40, 0, 1360), "Hero: Shrine Terrace", function(m)
	local T = 6
	local tz0, tz1, tw = -9, 23, 32
	local tcz = (tz0 + tz1) / 2
	local terr = model(m, "Terrace")
	P(terr, "TerraceBody", V(tw, T + 1.5, tz1 - tz0), CFrame.new(0, (T - 1.5) / 2, tcz), C.stoneMid, M.Slate)
	-- coursed facing on the front and sides, block by block, a step lighter or darker
	for _, face in { "front", "west", "east" } do
		local len = face == "front" and tw or (tz1 - tz0)
		local n = math.floor(len / 4)
		for row = 0, 2 do
			for k = 0, n - 1 do
				local u = -len / 2 + (k + 0.5 + (row % 2) * 0.5) * len / n
				if u > len / 2 then
					continue
				end
				local h = (T + 1.5) / 3
				local y = -1.5 + h * (row + 0.5)
				local size = V(len / n - 0.15, h - 0.12, 0.6)
				local cf
				if face == "front" then
					cf = CFrame.new(u, y, tz0 - 0.2)
				elseif face == "west" then
					cf = CFrame.new(-tw / 2 - 0.2, y, tcz + u) * CFrame.Angles(0, math.pi / 2, 0)
				else
					cf = CFrame.new(tw / 2 + 0.2, y, tcz + u) * CFrame.Angles(0, math.pi / 2, 0)
				end
				if face == "front" and math.abs(u) < 5 then
					continue
				end
				P(terr, "Facing", size, cf, rng:NextNumber() < 0.5 and C.stone or C.stoneMid, M.Slate)
			end
		end
	end
	P(terr, "Paving", V(tw - 1.6, 0.4, tz1 - tz0 - 1.6), CFrame.new(0, T + 0.05, tcz), C.pave, M.Cobblestone)
	-- coping and balustrade round the front and sides, open at the stair
	local function balustrade(a, b)
		local dir = (b - a)
		local n = math.max(1, math.floor(dir.Magnitude / 4))
		for k = 0, n do
			local p = a + dir * (k / n)
			P(terr, "BalPost", V(1, 2.8, 1), CFrame.new(p.X, T + 1.4, p.Z), C.stone, M.Slate)
			P(terr, "BalCap", V(1.3, 0.4, 1.3), CFrame.new(p.X, T + 2.95, p.Z), C.stoneMid, M.Slate)
		end
		beam(terr, "BalRail", a + V(0, T + 2.3, 0), b + V(0, T + 2.3, 0), 0.6, 0.5, C.stone, M.Slate)
		beam(terr, "BalRail", a + V(0, T + 0.9, 0), b + V(0, T + 0.9, 0), 0.5, 0.4, C.stoneMid, M.Slate)
	end
	local e = tw / 2 - 0.6
	balustrade(V(-e, 0, tz0 + 0.6), V(-5, 0, tz0 + 0.6))
	balustrade(V(5, 0, tz0 + 0.6), V(e, 0, tz0 + 0.6))
	balustrade(V(-e, 0, tz0 + 0.6), V(-e, 0, tz1 - 1))
	balustrade(V(e, 0, tz0 + 0.6), V(e, 0, tz1 - 1))
	-- moss creeping over the front edge and corners
	for _, x in { -13, -8.5, 10, 13.5 } do
		moss(terr, CFrame.new(x, T + 0.3, tz0 + 1.6), V(rr(2.5, 4), 0.25, rr(1.2, 2)))
	end
	-- the stair from the spine, cheek walls with lit lanterns at the foot
	local st = stair(m, V(0, 0, tz0 - 12), V(0, T + 0.25, tz0), 8, 10, { name = "FrontStair" })
	for _, s in { -1, 1 } do
		local a, b = V(s * 4.7, 0, tz0 - 12.6), V(s * 4.7, T, tz0)
		local mid = (a + b) / 2
		P(st, "Cheek", V(1.4, 2.2, (b - a).Magnitude + 0.4), CFrame.lookAt(mid + V(0, 0.6, 0), b + V(0, 0.6, 0)), C.stoneDark, M.Slate)
		P(st, "Cheek", V(1.4, T * 0.9, (b - a).Magnitude * 0.7), CFrame.new(s * 4.7, T * 0.45 - 1, tz0 - 4), C.stoneDark, M.Slate)
		P(st, "Newel", V(1.8, 3, 1.8), CFrame.new(s * 4.7, 1, tz0 - 13), C.stoneMid, M.Slate)
		stoneLantern(m, V(s * 7.6, 0, tz0 - 14), 0)
	end
	-- the pavilion (library Temple Structure, visual only) with invisible colliders
	local pav = model(m, "Pavilion")
	local temple = K(pav, MD["Temple Structure"], V(0, T + 0.25, 12.5), { w = 21, yaw = 0, sink = 0, collide = false, name = "PavilionMesh" })
	local tmn, tmx = bounds(temple)
	local tH = tmx.Y - tmn.Y
	P(pav, "FloorCollider", V(tmx.X - tmn.X - 2.4, tH * 0.085, tmx.Z - tmn.Z - 2.4), CFrame.new(0, tmn.Y + tH * 0.0425, 12.5), C.stone, M.Slate, { trans = 1, shadow = false })
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		cyl(pav, "ColumnCollider", CFrame.new(s[1] * (tmx.X - tmn.X) * 0.3, tmn.Y + tH * 0.4, 12.5 + s[2] * (tmx.Z - tmn.Z) * 0.3), tH * 0.6, 1.4, C.lacquer, M.Wood, { trans = 1, shadow = false })
	end
	jadeLamp(pav, V(-8.5, T + 0.25, 0.5), 0)
	jadeLamp(pav, V(8.5, T + 0.25, 0.5), 0)
	-- the forecourt: brazier, kneeling stone, an offering table
	brazier(m, V(0, T + 0.25, -3))
	P(m, "KneelingStone", V(4, 0.5, 2.4), CFrame.new(0, T + 0.5, -6.2), C.stoneDark, M.Slate)
	P(m, "OfferingTable", V(4.5, 1.6, 1.8), CFrame.new(-10, T + 1.05, -1), C.woodDark, M.Wood)
	for i = -1, 1 do
		cyl(m, "OfferingBowl", CFrame.new(-10 + i * 1.3, T + 2.05, -1), 0.4, 0.9, i == 0 and C.goldDark or C.bone, M.SmoothPlastic, { nc = true })
	end
	-- old pine behind the west corner, bamboo grove at the east back, rocks and ferns at the foot
	tree(m, INNO.Pine_Trees.Variation_01["Pine_01.4"], V(-24, 0, 26), { h = 40, yaw = 0.4, name = "OldPine" })
	bamboo(m, 13, V(24, 0, 24), 0)
	bamboo(m, 16, V(26, 0, 10), -1.57)
	bamboo(m, 8, V(22, 0, -10), 1.2)
	rock(m, "low", V(-19, 0, -10), 6, 0.4)
	rock(m, "wide", V(-22, 0, -4), 4, 2.3)
	pebble(m, V(19, 0, -13), 2.2)
	plant(m, "Fern_L", V(-12, 0, -12), {})
	plant(m, "Fern_M", V(12, 0, -12), {})
	plant(m, "Fern_S", V(-17, 0, 4), {})
	spot(m, "CacheSpot", V(-8, T + 0.75, -6.5))
	spot(m, "PromptSpot", V(0, T + 1, -5))
	fx(m, "FX_ShrineIncense", V(0, T + 3, -3))
	fx(m, "FX_Fireflies", V(0, T + 3, 6), V(32, 5, 32))
	snd(m, "SND_Shrine", V(0, T + 4, 10))
	snd(m, "SND_Brazier", V(0, T + 1, -3))
	snd(m, "SND_Waterfall", V(-10, T + 6, 26))
	fx(m, "FX_LanternFlicker_1", V(-7.6, 6, -23))
	fx(m, "FX_LanternFlicker_2", V(7.6, 6, -23))
	fx(m, "FX_QiMotes", V(0, T + 4, 12), V(18, 6, 18))
end, { note = "terrace back (+Z) goes against the Shrine Cliff beside the Jade Veil pool; the stair faces the spine (-Z)", handpass = "raised terrace with balustrade, front stair and the pavilion mesh (invisible floor and column colliders): check the stair meets the spine, the terrace back meets the Shrine Cliff, and the pine canopy clears the pavilion roof" })

--[[ =========================== FINDS =========================== ]]
GROUP = "finds"

-- F1 Stele grove at the trunk's first bend: three lore steles (big, medium, a small leaning one) on a
-- low paved step, a little bamboo grove behind them, ferns and a rock.
def("F01_SteleGrove", "Find", "Stele Grove", V(-29, 0, 684), "Spine", function(m)
	P(m, "Step", V(14, 1.6, 6), CFrame.new(0, -0.4, 1) * CFrame.Angles(0, 0.05, 0), C.paveDark, M.Slate)
	stele(m, at(-3.5, 0.4, 1.5, 0.08), 9, 3.4, { name = "SteleBig" })
	stele(m, at(2.8, 0.4, 2, -0.12), 6.5, 2.8, { name = "SteleMid" })
	local s3 = stele(m, at(7.5, 0, -0.5, 0.3) * CFrame.Angles(0, 0, -0.14), 4.4, 2.2, { name = "SteleSmall" })
	bamboo(m, 13, V(-2, 0, 13), 0)
	bamboo(m, 16, V(-10, 0, 9), -1.2)
	bamboo(m, 8, V(9, 0, 10), 0.5)
	rock(m, "low", V(-10, 0, -1), 3.5, 1.2)
	plant(m, "Fern_L", V(-7, 0, -2.5), {})
	plant(m, "Fern_S", V(6, 0, -3), {})
	spot(m, "PromptSpot", V(-3.5, 0.5, -4))
	snd(m, "SND_BambooWind", V(0, 10, 10))
	fx(m, "FX_SteleGlow", V(-3.5, 5.5, 0.7))
end, { note = "faces the spine (-Z); bamboo behind (+Z)" })

-- F2 Wayside earth-god shrine: a tiny stone house on a plinth with a lacquered roof, the old god inside,
-- offering bowls and incense, a red cloth, a single stone lantern and a small gnarled tree.
def("F02_EarthGodShrine", "Find", "Earth-God Shrine", V(-5, 0, 790), "Spine", function(m)
	P(m, "Plinth", V(5.4, 2.6, 4.4), CFrame.new(0, 0, 0), C.stoneMid, M.Slate)
	local cf = CFrame.new(0, 1.3, 0)
	P(m, "BackWall", V(4, 3.6, 0.5), cf * CFrame.new(0, 1.8, 1.6), C.stone, M.Slate)
	for _, s in { -1, 1 } do
		P(m, "SideWall", V(0.5, 3.6, 3.2), cf * CFrame.new(s * 1.8, 1.8, 0.2), C.stone, M.Slate)
	end
	roof(m, cf * CFrame.new(0, 3.6, 0.2), 5, 4.6, 1.5, { color = C.roof, gable = false, thick = 0.5 })
	P(m, "God", V(1.3, 1.6, 1), cf * CFrame.new(0, 0.8, 0.8), C.goldDark, M.Slate)
	P(m, "GodHead", V(0.9, 0.9, 0.9), cf * CFrame.new(0, 2, 0.8), C.goldDark, M.Slate, { shape = BALL })
	P(m, "RedCloth", V(1.6, 0.9, 0.1), cf * CFrame.new(0, 1.3, 0.25), C.lacquer, M.Fabric, { nc = true, shadow = false })
	for i = -1, 1 do
		cyl(m, "Bowl", cf * CFrame.new(i * 0.9, 0.15, -0.9), 0.3, 0.7, i == 0 and C.goldDark or C.bone, M.SmoothPlastic, { nc = true })
	end
	cyl(m, "IncensePot", CFrame.new(0, 0.6, -3.2), 1.2, 1.4, C.goldDark, M.Metal)
	for i = -1, 1 do
		P(m, "Incense", V(0.12, 1.4, 0.12), CFrame.new(i * 0.3, 1.8, -3.2) * CFrame.Angles(0, 0, i * 0.12), C.lacquerDark, M.SmoothPlastic, { nc = true, shadow = false })
	end
	stoneLantern(m, V(4.5, 0, -2.5), 0.2)
	plant(m, "Leafy_M", V(-5.5, 0, 3.5), { h = 13, collide = false, name = "ShadeTree" })
	plant(m, "Fern_M", V(3.5, 0, 2.5), {})
	plant(m, "Fern_S", V(-4, 0, -2), {})
	spot(m, "PromptSpot", V(0, 0.5, -5))
	fx(m, "FX_ShrineIncense", V(0, 2.6, -3.2))
	snd(m, "SND_Shrine", V(0, 2, 0))
end)

-- F3 Meditation rock facing the falls: a flat-topped boulder with steps cut into its side, a straw
-- cushion, an incense bowl and a pine leaning over it.
def("F03_MeditationRock", "Find", "Meditation Rock", V(25, 0, 900), "Spine", function(m)
	rock(m, "wide", V(0, 0, 2), 6, 0.3, { name = "Boulder", sink = 0.1 })
	P(m, "Seat", V(7, 1.2, 6), CFrame.new(0, 4.6, 2) * CFrame.Angles(0, 0.2, 0), C.stoneMid, M.Slate)
	stair(m, V(-6.5, 0, 1), V(-3.5, 4.6, 0), 3, 4, { name = "CutSteps", color = C.stoneMid })
	cyl(m, "Cushion", CFrame.new(0.5, 5.45, 1.5), 0.5, 2.2, C.straw, M.Fabric, { nc = true })
	cyl(m, "IncenseBowl", CFrame.new(0.5, 5.4, -1), 0.4, 0.8, C.goldDark, M.Metal, { nc = true })
	tree(m, INNO.Pine_Trees.Variation_05["Pine_05.4"], V(7, 0, 8), { h = 26, tilt = CFrame.Angles(0, 0, -0.12), name = "LeaningPine" })
	plant(m, "Fern_S", V(-5, 0, 5), {})
	spot(m, "PromptSpot", V(-4, 0.5, -7))
	fx(m, "FX_IncenseSmoke", V(0.5, 6, -1))
	snd(m, "SND_Wind", V(0, 8, 2))
end, { note = "the seat faces -Z: aim -Z at the Jade Veil Falls" })

-- F4 Ruined tea stall and milestone: four posts (one snapped), a torn awning, a counter with a kettle
-- on a little stove, a bench and cups; a carved milestone by the path.
def("F04_TeaStall", "Find", "Ruined Tea Stall", V(-35, 0, 1010), "Spine", function(m)
	local posts = { { -4, -3, 7 }, { 4, -3, 4.2 }, { -4, 3, 8.4 }, { 4, 3, 8.4 } }
	for _, p in posts do
		P(m, "Post", V(0.6, p[3] + 1, 0.6), CFrame.new(p[1], (p[3] - 1) / 2, p[2]), C.wood, M.Wood)
	end
	P(m, "SnappedTop", V(0.6, 3.6, 0.6), CFrame.new(5.6, 0.4, -4.4) * CFrame.Angles(0.2, 0, 1.4), C.wood, M.Wood, { nc = true })
	P(m, "Beam", V(9, 0.5, 0.5), CFrame.new(0, 8.1, 3), C.woodDark, M.Wood)
	P(m, "Awning", V(9, 0.12, 5.5), CFrame.new(-0.6, 7.3, 0.3) * CFrame.Angles(-0.22, 0, 0.1), C.clothPale, M.Fabric, { nc = true, shadow = true })
	P(m, "AwningTatter", V(2.2, 0.12, 1.6), CFrame.new(3, 5.8, -2.7) * CFrame.Angles(-1.2, 0, 0.2), hex("B8A888"), M.Fabric, { nc = true })
	P(m, "Counter", V(7, 3, 1.8), CFrame.new(0, 1.1, 1.6), C.woodLight, M.WoodPlanks)
	P(m, "CounterTop", V(7.4, 0.3, 2.2), CFrame.new(0, 2.75, 1.6), C.wood, M.Wood)
	P(m, "Stove", V(1.8, 1.2, 1.8), CFrame.new(-2, 3.5, 1.6), C.stoneDark, M.Slate)
	cyl(m, "Kettle", CFrame.new(-2, 4.6, 1.6), 1, 1.2, C.iron, M.Metal, { nc = true })
	for i = 0, 2 do
		cyl(m, "Cup", CFrame.new(1 + i * 0.8, 3.1, 1.3), 0.4, 0.45, C.bone, M.SmoothPlastic, { nc = true })
	end
	-- a plain plank bench for the customers
	P(m, "BenchSeat", V(6, 0.5, 1.4), CFrame.new(0, 1.7, -5) * CFrame.Angles(0, 0.1, 0), C.woodLight, M.WoodPlanks)
	for _, sx in { -2.4, 2.4 } do
		P(m, "BenchLeg", V(0.5, 1.9, 1.2), CFrame.new(sx, 0.55, -5 + sx * 0.04), C.wood, M.Wood)
	end
	K(m, PROPS["Stylized Barrel I"], V(-5.5, 0, 2.5), { yaw = 0.4, collide = true })
	K(m, PROPS.Crate, V(-6, 0, -0.5), { yaw = 1.2, tilt = CFrame.Angles(0, 0, 0.3), sink = 0.2 })
	-- the milestone by the path
	local ms = model(m, "Milestone")
	P(ms, "Stone", V(1.6, 4.5, 1.2), CFrame.new(8, 1.6, -6) * CFrame.Angles(0, -0.2, 0.05), C.stone, M.Slate)
	P(ms, "Carving", V(0.4, 2.6, 0.06), CFrame.new(8, 2, -6.62) * CFrame.Angles(0, -0.2, 0.05), C.lacquerDark, M.SmoothPlastic, { nc = true, shadow = false })
	moss(ms, CFrame.new(8, 3.9, -6), V(1.4, 0.2, 1))
	plant(m, "Fern_M", V(-6, 0, 5), {})
	plant(m, "Clover_M", V(5, 0, 5), {})
	spot(m, "PromptSpot", V(0, 0.5, -8.5))
	spot(m, "MilestonePrompt", V(8, 0.5, -7.5))
	snd(m, "SND_ClothFlap", V(0, 7, 0))
end, { handpass = "walk-under awning on four posts (one snapped): check the awning meets the posts and nothing clips the counter", note = "milestone at the -Z/+X corner stands by the path" })

-- F5 Old well: the library mossy well, scaled down, on a ring of worn paving, a bucket, a trough and a
-- moss rock.
def("F05_OldWell", "Find", "Old Well", V(15, 0, 1150), "Spine", function(m)
	cyl(m, "Paving", CFrame.new(0, -0.35, 0), 1, 18, C.paveDark, M.Cobblestone)
	K(m, LIB.VFX["Stylized Well (Mossy Green)"], V(0, 0.15, 0), { h = 15, yaw = 0.4, collide = true, sink = 0.02, name = "Well" })
	K(m, PROPS.Bucket, V(4.5, 0.15, -3), { yaw = 0.3 })
	K(m, PROPS["Wooden Trough"], V(-5.5, 0.15, 3), { yaw = 1.1, collide = true })
	rock(m, "low", V(8, 0, 4), 3.5, 0.2)
	plant(m, "Fern_M", V(-7, 0, -3), {})
	plant(m, "Clover_M", V(6, 0, -6), {})
	spot(m, "PromptSpot", V(0, 0.5, -10.5))
	snd(m, "SND_WellDrip", V(0, 1, 0))
end)

-- F6 Lantern stair foot: three broad steps starting the climb to the Shrine Terrace, a tall stone lamp
-- each side, a direction stele, guardian lion stones.
def("F06_LanternStairFoot", "Find", "Lantern Stair Foot", V(-15, 0, 1280), "Spine", function(m)
	stair(m, V(0, 0, -3), V(0, 1.8, 3), 12, 3, { name = "Steps" })
	P(m, "Landing", V(12, 2.6, 4), CFrame.new(0, 0.5, 5), C.stone, M.Slate)
	local lamp = WPROPS1["Stone Lamps"]:FindFirstChild("Stone Lamp 2")
	for _, s in { -1, 1 } do
		local l = K(m, lamp, V(s * 8, 0, -1), { yaw = 0, collide = true, name = "StoneLantern" })
		local mn, mx = bounds(l)
		light(P(l, "LightAnchor", V(0.5, 0.5, 0.5), CFrame.new(s * 8, mx.Y - 2.5, -1), C.ember, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 }), 14, 0.9)
		fx(m, "FX_LanternFlicker_" .. (s < 0 and 1 or 2), V(s * 8, mx.Y - 2.5, -1))
		-- a guardian lion: a crouched block body on a plinth
		local g = model(m, "Guardian")
		local gcf = CFrame.new(s * 4.6, 0, -4.6) * CFrame.Angles(0, s * -0.25, 0)
		P(g, "Plinth", V(2.4, 1.6, 3), gcf * CFrame.new(0, 0.3, 0), C.stoneDark, M.Slate)
		P(g, "Body", V(1.8, 2, 2.4), gcf * CFrame.new(0, 2.1, 0.3), C.stoneMid, M.Slate)
		P(g, "Head", V(1.9, 1.7, 1.6), gcf * CFrame.new(0, 3.6, -0.5), C.stoneMid, M.Slate)
		P(g, "Mane", V(2.2, 1.2, 0.6), gcf * CFrame.new(0, 3.3, 0.3), C.stone, M.Slate)
		P(g, "Ball", V(1, 1, 1), gcf * CFrame.new(s * 0.6, 1.6, -1.1), C.stone, M.Slate, { shape = BALL })
	end
	stele(m, at(-10, 0, -5, 0.4), 4.5, 2.2, { name = "WayStele" })
	plant(m, "Fern_L", V(10, 0, 3), {})
	plant(m, "Fern_M", V(-11, 0, 2), {})
	spot(m, "PromptSpot", V(-10, 0.5, -6.5))
end, { handpass = "steps meet the Shrine Terrace's FrontStair foot: align the landing to it when placing", note = "the steps rise toward +Z (toward the Shrine Terrace)" })

-- F7 Ferryman's hut: a small plank hut on a stone footing with a part roof, a bell post to call him, oars,
-- a coil of rope and a lantern by the door.
def("F07_FerrymanHut", "Find", "Ferryman's Hut", V(120, 0, 1330), "GorgeRoad", function(m)
	P(m, "Footing", V(10, 2.4, 8.4), CFrame.new(0, -0.2, 0), C.stoneDark, M.Slate)
	local cf = CFrame.new(0, 1, 0)
	local W, D, H = 8.6, 7, 6
	P(m, "BackWall", V(W, H, 0.5), cf * CFrame.new(0, H / 2, D / 2 - 0.25), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		P(m, "SideWall", V(0.5, H, D), cf * CFrame.new(s * (W / 2 - 0.25), H / 2, 0), C.woodLight, M.WoodPlanks)
		P(m, "FrontWall", V(2.8, H, 0.5), cf * CFrame.new(s * (W / 2 - 1.4), H / 2, -D / 2 + 0.25), C.woodLight, M.WoodPlanks)
		for _, z in { -1, 1 } do
			P(m, "CornerPost", V(0.7, H + 0.3, 0.7), cf * CFrame.new(s * W / 2, (H + 0.3) / 2, z * D / 2), C.woodDark, M.Wood)
		end
	end
	P(m, "DoorLintel", V(3.2, 1.2, 0.6), cf * CFrame.new(0, H - 0.6, -D / 2 + 0.25), C.woodDark, M.Wood)
	P(m, "Door", V(2.9, H - 1.3, 0.2), cf * CFrame.new(0.7, (H - 1.2) / 2, -D / 2 - 0.4) * CFrame.Angles(0, 0.7, 0), C.wood, M.WoodPlanks)
	P(m, "Interior", V(W - 1, H - 0.4, 0.2), cf * CFrame.new(0, H / 2, D / 2 - 0.6), C.char, M.Wood, { nc = true, shadow = false })
	roof(m, cf * CFrame.new(0, H, 0), W + 2.4, D + 2.6, 2.6)
	-- bell post
	P(m, "BellPost", V(0.7, 9, 0.7), CFrame.new(-7, 3.5, -4), C.woodDark, M.Wood)
	P(m, "BellArm", V(2.6, 0.5, 0.5), CFrame.new(-6, 7.6, -4), C.woodDark, M.Wood)
	cyl(m, "Bell", CFrame.new(-5.2, 6.6, -4), 1.6, 1.4, C.goldDark, M.Metal, { nc = true })
	-- oars and rope
	for i = 0, 1 do
		rod(m, "Oar", V(5.6 + i * 0.8, 0, -4.4), V(5 + i * 0.8, 6.5, -3.6), 0.35, C.woodPale, M.Wood, { nc = true })
	end
	cyl(m, "RopeCoil", CFrame.new(3, 1.3, -5), 0.6, 2, C.straw, M.Fabric, { nc = true })
	local lp = K(m, INNO.Wood_Iron_Assets.Lantern, V(-3.3, 5, -4.2), { scale = 1, sink = 0, name = "Lantern" })
	light(P(lp, "LightAnchor", V(0.5, 0.5, 0.5), CFrame.new(-3.3, 5.8, -4.2), C.ember, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 }), 12, 0.8)
	P(m, "LanternHook", V(0.2, 1, 0.2), CFrame.new(-3.3, 6.6, -4.2), C.iron, M.Metal, { nc = true })
	plant(m, "Reeds", V(7, 0, 3), { scale = 1.3 })
	plant(m, "Fern_M", V(-6, 0, 3), {})
	spot(m, "PromptSpot", V(-6, 0.5, -5.5))
	snd(m, "SND_RiverNear", V(0, 2, -8))
	fx(m, "FX_LanternFlicker", V(-3.3, 5.8, -4.2))
end, { handpass = "small hut: walls, door, gable roof from parts; check roof overhang, door swing and the lantern hook", note = "door faces -Z (the GorgeRoad)" })

-- F8 River jetty through the gorge gate: a plank jetty on posts reaching out over the river (+Z), mooring
-- posts, a lantern post at the end, a moored skiff.
def("F08_RiverJetty", "Find", "River Jetty", V(250, 0, 1470), "GorgeRoad", function(m)
	boardwalk(m, { V(0, 0, -2), V(0, 0, 20) }, 1.2, 5, -6, { name = "Jetty", rails = false })
	P(m, "BankPad", V(7, 1.6, 4), CFrame.new(0, 0, -4), C.stoneDark, M.Slate)
	for _, p in { V(-3.2, 0, 8), V(3.2, 0, 14), V(-3.2, 0, 20) } do
		cyl(m, "MooringPost", CFrame.new(p.X, 0.8, p.Z), 4.4, 0.9, C.woodDark, M.Wood)
		cyl(m, "Rope", CFrame.new(p.X, 2.2, p.Z), 0.4, 1.1, C.straw, M.Fabric, { nc = true })
	end
	P(m, "LampPost", V(0.6, 7, 0.6), CFrame.new(2.2, 4.2, 20.5), C.woodDark, M.Wood)
	P(m, "LampArm", V(0.4, 0.4, 1.6), CFrame.new(2.2, 7.5, 19.9), C.woodDark, M.Wood)
	local lp = K(m, INNO.Wood_Iron_Assets.Lantern, V(2.2, 5.6, 19.2), { sink = 0, name = "Lantern" })
	light(P(lp, "LightAnchor", V(0.5, 0.5, 0.5), CFrame.new(2.2, 6.3, 19.2), C.ember, M.SmoothPlastic, { nc = true, shadow = false, trans = 1 }), 14, 0.9)
	-- the skiff tied alongside
	local bcf = CFrame.new(-6, -0.6, 13) * CFrame.Angles(0, 0.05, 0.04)
	P(m, "SkiffHull", V(3.4, 1.2, 10), bcf, C.wood, M.WoodPlanks)
	for _, s in { -1, 1 } do
		wedge(m, "SkiffBow", V(3.4, 1.2, 2.2), bcf * CFrame.new(0, 0, s * 6.1) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0), C.wood, M.WoodPlanks)
	end
	P(m, "SkiffInside", V(2.8, 0.2, 9), bcf * CFrame.new(0, 0.55, 0), C.woodDark, M.WoodPlanks, { nc = true })
	beam(m, "Tether", V(-3.2, 2.2, 8), V(-6, 0.5, 9), 0.15, 0.15, C.straw, M.Fabric, { nc = true })
	spot(m, "PromptSpot", V(0, 1.5, 18))
	snd(m, "SND_RiverNear", V(0, 0, 14))
	fx(m, "FX_LanternFlicker", V(2.2, 6.3, 19.2))
end, { handpass = "jetty over the river: posts reach Y -6 local, check they meet the riverbed, the deck meets the bank and the skiff sits on the water", note = "pivot = bank top at the jetty root; the jetty runs out over the water toward +Z" })

-- herb patches: wild spirit herbs among rocks, a few with a jade or gold glow (F9 west, F16 east)
local function herbPatch(m, glow, extra)
	rock(m, "low", V(-4, 0, 3), 4, 0.3)
	rock(m, "wide", V(4, 0, 4), 2.6, 1.7)
	pebble(m, V(1, 0, 6), 1.6)
	for i = 1, 11 do
		local a, r = rr(0, 6.28), rr(0.5, 5)
		local p = V(math.cos(a) * r, 0, math.sin(a) * r - 1)
		local h = rr(0.9, 1.8)
		P(m, "HerbStem", V(0.25, h, 0.25), CFrame.new(p + V(0, h / 2, 0)), C.turf, M.SmoothPlastic, { nc = true, shadow = false })
		P(m, "HerbLeaf", V(1.4, 0.15, 0.7), CFrame.new(p + V(0, h * 0.6, 0)) * CFrame.Angles(0, rr(0, 6), 0.3), C.lawn, M.SmoothPlastic, { nc = true, shadow = false })
		if i % 3 == 0 then
			P(m, "HerbBloom", V(0.5, 0.5, 0.5), CFrame.new(p + V(0, h + 0.2, 0)), glow, M.Neon, { nc = true, shadow = false, shape = BALL })
		end
	end
	plant(m, "Fern_M", V(-5, 0, -3), {})
	plant(m, "Clover_L", V(3, 0, -4), { scale = 0.6 })
	spot(m, "PromptSpot", V(0, 0.5, -1))
	fx(m, "FX_HerbGlow", V(0, 1, -1), V(10, 2, 10))
	if extra then
		extra(m)
	end
end
def("F09_HerbPatch_West", "Find", "Herb Patch (west)", V(-110, 0, 700), "WestArm", function(m)
	herbPatch(m, C.herbGlow, function(m)
		K(m, PROPS.Bucket, V(5, 0, -3), { yaw = 0.4, tilt = CFrame.Angles(0, 0, 1.4), sink = 0.2, name = "Basket" })
		P(m, "Marker", V(0.8, 2.6, 0.8), CFrame.new(-6.5, 1, 1), C.stone, M.Slate)
		P(m, "MarkerTie", V(1, 0.3, 1), CFrame.new(-6.5, 1.8, 1), C.lacquer, M.Fabric, { nc = true })
	end)
end)
def("F16_HerbPatch_East", "Find", "Herb Patch (east)", V(110, 0, 725), "EastArm", function(m)
	herbPatch(m, C.herbGold, function(m)
		for i = 1, 5 do
			P(m, "Berry", V(0.6, 0.6, 0.6), CFrame.new(-2 + i * 0.7, 1.3, 2.5 + (i % 2) * 0.6), C.berry, M.SmoothPlastic, { nc = true, shadow = false, shape = BALL })
		end
		P(m, "DryingTray", V(3, 0.3, 2), CFrame.new(7, 1.4, 3) * CFrame.Angles(0, 0.3, 0), C.straw, M.Fabric)
		for _, s in { -1, 1 } do
			P(m, "TrayLeg", V(0.3, 1.4, 0.3), CFrame.new(7 + s * 1.2, 0.6, 3), C.woodPale, M.Wood, { nc = true })
		end
	end)
end)

-- F10 Abandoned cart: the library pushing cart tipped on its side, a wheel off, sacks and a broken crate
-- spilled behind it.
def("F10_AbandonedCart", "Find", "Abandoned Cart", V(-260, 0, 735), "WestArm", function(m)
	local carts = {}
	for _, c in WPROPS1:GetChildren() do
		if c.Name == "Pushing Cart" then
			table.insert(carts, c)
		end
	end
	K(m, carts[1], V(0, 0, 0), { h = 9, yaw = 0.5, tilt = CFrame.Angles(0, 0, 0.32), collide = true, sink = 0.08, name = "Cart" })
	K(m, PROPS.CartWheel, V(-6, 0, -4), { yaw = 1.1, tilt = CFrame.Angles(math.pi / 2 - 0.1, 0, 0), sink = 0.02, name = "LooseWheel" })
	K(m, PROPS["Sack 1"], V(5, 0, -3), { yaw = 2.1, tilt = CFrame.Angles(0, 0, 1.2) })
	K(m, PROPS["Sack 2"], V(7, 0, 0), { yaw = 0.4 })
	K(m, PROPS.Crate, V(3.5, 0, 4), { yaw = 0.9, tilt = CFrame.Angles(0.3, 0, 0.5), sink = 0.25 })
	for i = 1, 6 do
		P(m, "Grain", V(0.9, 0.2, 0.6), CFrame.new(5 + rr(-2, 2), 0.05, -5 + rr(-1.5, 1.5)) * CFrame.Angles(0, rr(0, 6), 0), C.straw, M.SmoothPlastic, { nc = true, shadow = false })
	end
	plant(m, "BushDry_S", V(-6, 0, 5), { scale = 0.5 })
	plant(m, "Fern_S", V(2, 0, -6), {})
	spot(m, "PromptSpot", V(2, 0.5, -6))
	spot(m, "CacheSpot", V(-4, 0.5, -8))
end)

-- F11 Claw-marked tree and bones: a dead tree with deep gouges, scattered bones, a torn cloth snagged
-- on a branch, a scratched rock.
def("F11_ClawTree", "Find", "Claw-Marked Tree", V(-450, 0, 760), "WestArm", function(m)
	tree(m, KIT.Withered_M, V(0, 0, 2), { h = 26, yaw = 0.3, name = "ClawTree" })
	for i = -2, 2 do
		P(m, "ClawMark", V(0.2, 3.6, 0.4), CFrame.new(-0.2 + i * 0.5, 4.5 + math.abs(i) * 0.2, 0.6) * CFrame.Angles(0, 0, 0.25), C.bone, M.Wood, { nc = true, shadow = false })
	end
	P(m, "Snag", V(1.6, 2.2, 0.1), CFrame.new(3, 11, 2.5) * CFrame.Angles(0.2, 0.4, 0.3), C.cloth, M.Fabric, { nc = true, shadow = false })
	bones(m, V(-1, 0, -4), 4, 7)
	rock(m, "low", V(-6, 0, -1), 3, 0.7)
	for i = 0, 2 do
		P(m, "RockScratch", V(0.15, 0.2, 2), CFrame.new(-5.3 + i * 0.4, 2.2, -2.3) * CFrame.Angles(0.3, 0.2, 0), C.bone, M.SmoothPlastic, { nc = true, shadow = false })
	end
	spot(m, "PromptSpot", V(0, 0.5, -3))
	snd(m, "SND_Crows", V(0, 18, 2))
end)

-- F12 Snare line: three snares set along a trail (bent sapling, cord loop, pegs), a deadfall log trap,
-- a little warning stick with a feather.
def("F12_SnareLine", "Find", "Snare Line", V(-470, 0, 920), "WestLoop", function(m)
	for i, x in { -9, -1, 8 } do
		local s = model(m, "Snare_" .. i)
		local base = V(x, 0, rr(-1, 1))
		rod(s, "Sapling", base, base + V(rr(-0.5, 0.5), 5, 2.5), 0.3, C.woodPale, M.Wood, { nc = true })
		beam(s, "Cord", base + V(0, 5, 2.5), base + V(0, 0.6, 3.5), 0.08, 0.08, C.straw, M.Fabric, { nc = true })
		P(s, "Loop", V(0.08, 1.2, 1.2), CFrame.new(base + V(0, 0.6, 3.5)) * CFrame.Angles(0, math.pi / 2, 0), C.straw, M.Fabric, { nc = true, shape = CYL })
		for k = -1, 1, 2 do
			P(s, "Peg", V(0.25, 1, 0.25), CFrame.new(base + V(k * 0.8, 0.3, 3.5)), C.woodDark, M.Wood, { nc = true })
		end
		s.WorldPivot = CFrame.new(base)
	end
	local dz = model(m, "Deadfall")
	K(dz, KIT.Log_A, V(14, 0, 1), { scale = 0.3, yaw = 0.2, sink = 0, name = "DeadfallLog" }).CFrame *= CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, 0.3)
	rod(dz, "Trigger", V(12.2, 0, 1), V(12.2, 2.3, 1), 0.3, C.woodPale, M.Wood, { nc = true })
	dz.WorldPivot = CFrame.new(14, 0, 1)
	local w = model(m, "WarningStick")
	P(w, "Stick", V(0.3, 3.2, 0.3), CFrame.new(-14, 1.3, -1) * CFrame.Angles(0, 0, 0.1), C.woodDark, M.Wood, { nc = true })
	P(w, "Feather", V(0.1, 1.2, 0.4), CFrame.new(-13.85, 2.9, -1) * CFrame.Angles(0, 0, 0.3), C.bone, M.SmoothPlastic, { nc = true })
	w.WorldPivot = CFrame.new(-14, 0, -1)
	spot(m, "PromptSpot", V(-1, 0.5, 1))
end, { reseat = true, note = "a line along X across a trail; ground each Snare_n/Deadfall/WarningStick separately" })

-- F13 Half-buried pagoda finial: the top three tiers of a pagoda roof sunk at a tilt, a gold spire,
-- moss in the eaves, rubble round it.
def("F13_PagodaFinial", "Find", "Buried Pagoda Finial", V(-530, 0, 1080), "WestLoop", function(m)
	local base = CFrame.new(0, -3, 0) * CFrame.Angles(0.22, 0.4, 0.1)
	for i, t in { { 0, 16, 2.4 }, { 4.2, 11.5, 2 }, { 7.8, 7.5, 1.6 } } do
		local cf = base * CFrame.new(0, t[1], 0)
		P(m, "TierWall", V(t[2] * 0.62, 3, t[2] * 0.62), cf * CFrame.new(0, -1, 0), C.lacquerFaded, M.WoodPlanks)
		P(m, "TierRoof", V(t[2], t[3], t[2]), cf * CFrame.new(0, 0.9, 0), i == 1 and C.roof or C.roofLight, M.Slate)
		P(m, "TierRoofCap", V(t[2] * 0.7, t[3] * 0.8, t[2] * 0.7), cf * CFrame.new(0, 0.9 + t[3] * 0.8, 0), C.roofDark, M.Slate)
		for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			wedge(m, "EaveTip", V(0.8, 1.2, 2), cf * CFrame.new(c[1] * t[2] / 2, 1.2, c[2] * t[2] / 2) * CFrame.Angles(0, math.atan2(c[1], c[2]), 0), C.goldDark, M.Metal, { nc = true })
		end
		moss(m, cf * CFrame.new(t[2] * 0.25, 1.4 + t[3] * 0.8, 0), V(t[2] * 0.35, 0.3, t[2] * 0.4))
	end
	local top = base * CFrame.new(0, 10.8, 0)
	cyl(m, "Spire", top * CFrame.new(0, 2.5, 0), 5, 0.9, C.gold, M.Metal)
	for k = 0, 2 do
		cyl(m, "SpireRing", top * CFrame.new(0, 1 + k * 1.2, 0), 0.4, 1.8 - k * 0.3, C.goldDark, M.Metal, { nc = true })
	end
	P(m, "SpireOrb", V(1.6, 1.6, 1.6), top * CFrame.new(0, 5.4, 0), C.gold, M.Metal, { shape = BALL })
	rubble(m, V(0, 0, 0), 11, 12, C.roofDark)
	rubble(m, V(3, 0, -6), 4, 5, C.lacquerFaded)
	plant(m, "Fern_L", V(-7, 0, -4), {})
	plant(m, "Bush_S", V(8, 0, 5), { scale = 0.6 })
	spot(m, "PromptSpot", V(0, 0.5, -10))
	fx(m, "FX_SpireGlint", top * CFrame.new(0, 5.4, 0))
end, { handpass = "a pagoda top sunk 3 studs at a tilt: check the lowest tier is buried in the terrain all round (no gap under the eaves)" })

-- F14 Woodcutter's clearing: stumps of three sizes, an axe in the chopping block, a sawhorse with a log,
-- split logs stacked, chips on the ground.
def("F14_WoodcutterClearing", "Find", "Woodcutter's Clearing", V(-330, 0, 1320), "SouthWest", function(m)
	plant(m, "Stump_L", V(-6, 0, 4), { scale = 0.6, collide = true, name = "Stump" })
	plant(m, "Stump_M", V(5, 0, 6), { scale = 0.5, collide = true, name = "Stump" })
	plant(m, "Stump_S", V(8, 0, -4), { scale = 0.35, collide = true, name = "Stump" })
	cyl(m, "ChoppingBlock", CFrame.new(0, 0.9, -1), 2.4, 2.6, C.woodLight, M.Wood)
	local axe = CFrame.new(0.3, 2.1, -1) * CFrame.Angles(0, 0.4, -0.5)
	P(m, "AxeHead", V(0.25, 1, 1.4), axe, C.iron, M.Metal, { nc = true })
	P(m, "AxeHaft", V(0.3, 3.4, 0.3), axe * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, 1.5, 0), C.woodPale, M.Wood, { nc = true })
	for _, s in { -1, 1 } do
		for _, z in { -0.8, 0.8 } do
			rod(m, "SawhorseLeg", V(-4 + s * 1.6, -0.2, -6 + z), V(-4 + s * 0.6, 2.8, -6), 0.35, C.wood, M.Wood, { nc = true })
		end
	end
	rod(m, "SawLog", V(-8, 3, -6), V(1, 3, -6.2), 1.4, C.woodLight, M.Wood)
	for k = 0, 5 do
		rod(m, "Split", V(9, 0.45 + math.floor(k / 3) * 0.85, 2 + (k % 3) * 0.9), V(12.5, 0.45 + math.floor(k / 3) * 0.85, 2 + (k % 3) * 0.9), 0.85, k % 2 == 0 and C.woodPale or C.woodLight, M.Wood, { nc = k >= 3 })
	end
	for i = 1, 10 do
		P(m, "Chip", V(0.5, 0.1, 0.3), CFrame.new(rr(-3, 3), 0.05, rr(-4, 2)) * CFrame.Angles(0, rr(0, 6), 0), C.woodPale, M.SmoothPlastic, { nc = true, shadow = false })
	end
	spot(m, "PromptSpot", V(0, 0.5, -3.5))
	snd(m, "SND_Birds", V(0, 10, 0))
end)

-- F15 Stone bridge over a dry creek: a slab bridge on two piers, curb stones, a pebble bed beneath.
def("F15_DryCreekBridge", "Find", "Dry Creek Bridge", V(-180, 0, 1320), "SouthWest", function(m)
	-- the creek bed runs along X, 6 deep, 10 wide; the bridge crosses along Z
	carve(m, "TerrainCarve", CFrame.new(0, -3.5, 0), V(30, 7, 9))
	for i = 1, 14 do
		pebble(m, V(rr(-13, 13), -6.2, rr(-3.5, 3.5)), rr(0.8, 1.8))
	end
	for _, z in { -5.5, 5.5 } do
		P(m, "Abutment", V(7, 7.5, 3), CFrame.new(0, -3, z), C.stoneDark, M.Slate)
	end
	P(m, "Deck", V(6, 1, 15), CFrame.new(0, 0.3, 0), C.stone, M.Slate)
	for _, s in { -1, 1 } do
		P(m, "Curb", V(0.8, 1.1, 15.4), CFrame.new(s * 3.2, 1.1, 0), C.stoneMid, M.Slate)
		for _, z in { -7.2, 7.2 } do
			P(m, "CurbPost", V(1.2, 2.2, 1.2), CFrame.new(s * 3.2, 1.3, z), C.stoneMid, M.Slate)
		end
	end
	moss(m, CFrame.new(2.6, 1.7, 3), V(1, 0.2, 4))
	plant(m, "Fern_M", V(-5, 0, -8), {})
	plant(m, "Reeds", V(6, -6, 1), { scale = 1.2 })
	spot(m, "PromptSpot", V(0, 0.9, -9))
end, { handpass = "slab bridge over a dug creek (TerrainCarve 30x7x9): check the deck ends meet the path on both banks and the abutments are buried", note = "the creek runs along X; the path crosses along Z" })

-- F17 GateRidge vista notch: a flat stone ledge at the climb's top, a weathered bench, an inscribed
-- marker, a twisted pine framing the view, a rope rail on the drop side (-Z).
def("F17_VistaNotch", "Find", "GateRidge Vista", V(150, 0, 665), "EastArm (climb)", function(m)
	P(m, "Ledge", V(12, 2, 8), CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0.1, 0), C.stoneMid, M.Slate)
	rock(m, "low", V(-7, 0, 4), 5, 0.3)
	K(m, LIB["Stylized Asset Pack II (Props)"]["Stylized Wooden Props II"]["Stylized Bench"], V(1, 0.4, 2), { yaw = math.pi, scale = 0.7, collide = true })
	P(m, "Marker", V(1.4, 3.2, 0.9), CFrame.new(5, 1.8, 2.2) * CFrame.Angles(0, -0.3, 0.06), C.stone, M.Slate)
	P(m, "MarkerGlyph", V(0.35, 1.8, 0.06), CFrame.new(5, 2.2, 1.73) * CFrame.Angles(0, -0.3, 0.06), C.jade, M.SmoothPlastic, { nc = true, shadow = false })
	for i, x in { -5, 0, 5 } do
		P(m, "RailPost", V(0.5, 3, 0.5), CFrame.new(x, 1.1, -3.6), C.woodDark, M.Wood)
	end
	beam(m, "RopeRail", V(-5, 2.2, -3.6), V(5, 2.2, -3.6), 0.15, 0.15, C.straw, M.Fabric, { nc = true })
	tree(m, INNO.Pine_Trees.Variation_02["Pine_02.4"], V(-8, 0, -1), { h = 22, tilt = CFrame.Angles(-0.15, 0, 0.1), name = "TwistedPine" })
	plant(m, "Fern_S", V(7, 0, 3), {})
	spot(m, "PromptSpot", V(1, 0.9, -1))
	snd(m, "SND_Wind", V(0, 6, -4))
	fx(m, "FX_VistaMist", V(0, -4, -12), V(30, 4, 10))
end, { note = "the view and the drop are on -Z; set the ledge on the GateRidge crest notch" })

-- F18 Boar wallow: a churned mud hollow, trampled earth round it, a tusk-scarred stump, uprooted ferns
-- and hoof tracks.
def("F18_BoarWallow", "Find", "Boar Wallow", V(420, 0, 790), "EastArm", function(m)
	cyl(m, "Mud", CFrame.new(0, -0.9, 0), 1, 14, C.mud, M.Mud)
	carve(m, "TerrainCarve", CFrame.new(0, -1.35, 0) * CFrame.Angles(0, 0, math.pi / 2), V(1.8, 14.5, 14.5), CYL)
	for i = 1, 6 do
		local a = rr(0, 6.28)
		P(m, "MudLump", V(rr(1.2, 2.4), rr(0.4, 0.8), rr(1.2, 2.4)), CFrame.new(math.cos(a) * rr(1, 6), -0.4, math.sin(a) * rr(1, 6)) * CFrame.Angles(0, a, 0), C.earthDark, M.Mud, { nc = true })
	end
	plant(m, "Stump_M", V(-9, 0, 4), { scale = 0.5, collide = true, name = "ScarredStump" })
	for i = 0, 2 do
		P(m, "TuskScar", V(0.2, 0.4, 1.8), CFrame.new(-7.6, 1.6 + i * 0.5, 4) * CFrame.Angles(0, 0.2, 0.2), C.woodPale, M.Wood, { nc = true, shadow = false })
	end
	for i = 1, 8 do
		local z = -12 + i * 1.6
		P(m, "Track", V(0.6, 0.05, 0.8), CFrame.new(8 + (i % 2) * 1.1, 0.03, z) * CFrame.Angles(0, 0.3, 0), C.mud, M.Mud, { nc = true, shadow = false })
	end
	K(m, KIT.Fern_M, V(5, 0, 7), { yaw = 1, tilt = CFrame.Angles(0, 0, 2.6), sink = 0, name = "UprootedFern" })
	plant(m, "BushDry_S", V(-6, 0, -8), { scale = 0.6 })
	rock(m, "low", V(9, 0, 6), 3, 0.4)
	spot(m, "PromptSpot", V(2, 0.5, -8.5))
	snd(m, "SND_BoarGrunt", V(0, 1, 0))
end, { note = "dig the TerrainCarve disc (top Y -0.45 local) so the mud sits in a hollow" })

-- F19 Collapsed watch post: a log tower that fell over, its platform crashed at a tilt, a broken ladder,
-- a torn banner on the one post still standing, a stone footing.
def("F19_CollapsedWatchPost", "Find", "Collapsed Watch Post", V(580, 0, 760), "EastArm", function(m)
	for _, c in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		P(m, "Footing", V(2, 1.4, 2), CFrame.new(c[1], 0, c[2]), C.stoneDark, M.Slate)
	end
	rod(m, "StandingPost", V(-3, 0.5, -3), V(-3.3, 11, -3.4), 1, C.wood, M.Wood)
	P(m, "Banner", V(0.12, 4, 2.2), CFrame.new(-3.4, 8.5, -2) * CFrame.Angles(0.1, 0, 0), C.cloth, M.Fabric, { nc = true, shadow = false })
	P(m, "BannerTatter", V(0.12, 1.4, 1), CFrame.new(-3.4, 5.9, -1.6) * CFrame.Angles(0.25, 0, 0), C.cloth, M.Fabric, { nc = true, shadow = false })
	-- fallen posts and the crashed platform
	for i, p in { { V(3, 0.5, -3), V(14, 1.2, -6) }, { V(3, 0.5, 3), V(13, 4.2, 6) }, { V(-3, 0.5, 3), V(4, 1, 12) } } do
		rod(m, "FallenPost", p[1], p[2], 1, C.wood, M.Wood)
	end
	P(m, "Platform", V(8, 0.7, 8), CFrame.new(10, 2.6, 2) * CFrame.Angles(0.15, 0.3, 0.35), C.woodLight, M.WoodPlanks)
	P(m, "PlatformRail", V(8, 1.2, 0.3), CFrame.new(11, 3.6, -1.6) * CFrame.Angles(0.15, 0.3, 0.6), C.woodDark, M.WoodPlanks, { nc = true })
	for k = 0, 4 do
		P(m, "LadderPiece", V(2, 0.25, 0.3), CFrame.new(-6 + rr(-1, 1), 0.2, -5 + k * 1.1) * CFrame.Angles(0, rr(-0.4, 0.4), 0), C.woodPale, M.Wood, { nc = true })
	end
	rod(m, "LadderRail", V(-7, 0.3, -6), V(-5.5, 0.3, 1), 0.35, C.woodPale, M.Wood, { nc = true })
	rubble(m, V(8, 0, 0), 6, 6, C.woodDark)
	plant(m, "BushDry_M", V(-9, 0, 6), { scale = 0.5 })
	spot(m, "PromptSpot", V(-1, 0.5, -7))
	spot(m, "CacheSpot", V(-8, 0.5, -2))
	snd(m, "SND_BannerFlap", V(-3.4, 8, -2))
end, { handpass = "collapsed tower: tilted platform and fallen posts resting on each other; check nothing floats once the ground is uneven" })

-- F20 Moss stele circle: seven old steles in a ring (one fallen), a flat centre stone with a jade glyph.
def("F20_MossSteleCircle", "Find", "Moss Stele Circle", V(610, 0, 880), "EastLoop", function(m)
	cyl(m, "CentreStone", CFrame.new(0, 0, 0), 1.4, 5, C.stoneMid, M.Slate)
	cyl(m, "Glyph", CFrame.new(0, 0.72, 0), 0.06, 2.2, C.jade, M.Neon, { nc = true, shadow = false })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + 0.3
		local p = V(math.cos(a) * 8, 0, math.sin(a) * 8)
		local h = ({ 6, 4.5, 7, 3.8, 5.5, 4, 6.5 })[i]
		if i == 4 then
			P(m, "FallenStele", V(2.2, 0.9, h), CFrame.new(p + V(0, 0.3, 0)) * CFrame.Angles(0, -a, 0.08), C.stone, M.Slate)
			moss(m, CFrame.new(p + V(0, 0.8, 0)) * CFrame.Angles(0, -a, 0), V(1.6, 0.2, h * 0.6))
		else
			local cf = CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, rr(-0.06, 0.06))
			P(m, "Stele", V(2, h, 0.9), cf * CFrame.new(0, h / 2 - 0.6, 0), i % 2 == 0 and C.stone or C.stoneMid, M.Slate)
			moss(m, cf * CFrame.new(0, h - 0.5, 0), V(1.8, 0.25, 0.9))
			moss(m, cf * CFrame.new(0, h * 0.3, -0.48) * CFrame.Angles(math.pi / 2, 0, 0), V(1.2, 0.15, h * 0.4))
		end
	end
	plant(m, "Clover_L", V(4, 0, 5), { scale = 0.6 })
	plant(m, "Fern_M", V(-10, 0, 2), {})
	spot(m, "PromptSpot", V(0, 1, -2.6))
	fx(m, "FX_GlyphGlow", V(0, 1, 0), V(5, 2, 5))
	snd(m, "SND_Chime", V(0, 3, 0))
end)

-- F21 Fox Hole cave mouth: two rocks leaning into a low arch over a dark hole, roots hanging from the
-- lintel, feathers and small bones, a tiny fox shrine with an offering.
def("F21_FoxHoleCave", "Find", "Fox Hole", V(700, 0, 1000), "EastLoop", function(m)
	rock(m, "tall", V(-7, 0, 5), 14, 0.5, { tilt = CFrame.Angles(0, 0, -0.08), name = "MouthWest" })
	rock(m, "mid", V(7, 0, 5), 12, 2.4, { tilt = CFrame.Angles(0, 0, 0.08), name = "MouthEast" })
	rock(m, "low", V(0, 6.2, 6), 6, 1.57, { sink = 0, name = "Lintel" })
	P(m, "Hole", V(5, 6, 1.5), CFrame.new(0, 2.6, 9), C.cave, M.Basalt)
	P(m, "HoleFloor", V(5, 1, 6), CFrame.new(0, -0.4, 7), C.earthDark, M.Ground)
	for i = 1, 5 do
		rod(m, "HangingRoot", V(-2 + i * 0.8, 6.2, 3.5), V(-2 + i * 0.8 + rr(-0.3, 0.3), rr(3.8, 5), 3.3), 0.25, C.wood, M.Wood, { nc = true })
	end
	for i = 1, 4 do
		P(m, "Feather", V(0.1, 0.9, 0.35), CFrame.new(rr(-2, 2), 0.1, rr(-2, 1)) * CFrame.Angles(math.pi / 2, rr(0, 6), 0), C.clothPale, M.SmoothPlastic, { nc = true, shadow = false })
	end
	bones(m, V(1, 0, 0), 2, 3)
	-- the fox shrine: a tiny red gate and a stone fox
	local sh = model(m, "FoxShrine")
	for _, s in { -1, 1 } do
		P(sh, "GatePost", V(0.35, 2.4, 0.35), CFrame.new(-6 + s * 0.8, 1.1, -3), C.lacquer, M.Wood)
	end
	P(sh, "GateBeam", V(2.4, 0.3, 0.4), CFrame.new(-6, 2.3, -3), C.lacquer, M.Wood)
	P(sh, "FoxBody", V(0.8, 1, 1.2), CFrame.new(-6, 0.5, -1.8), C.stone, M.Slate)
	P(sh, "FoxHead", V(0.7, 0.7, 0.8), CFrame.new(-6, 1.3, -2.2), C.stone, M.Slate)
	for _, s in { -1, 1 } do
		wedge(sh, "FoxEar", V(0.15, 0.4, 0.3), CFrame.new(-6 + s * 0.22, 1.85, -2.2), C.stone, M.Slate, { nc = true })
	end
	cyl(sh, "Offering", CFrame.new(-6, 0.15, -3.6), 0.3, 0.7, C.bone, M.SmoothPlastic, { nc = true })
	plant(m, "Fern_L", V(6, 0, -1), {})
	plant(m, "Fern_S", V(-9, 0, 0), {})
	spot(m, "PromptSpot", V(0, 0.5, -4.5))
	fx(m, "FX_FoxEyes", V(0, 2, 8))
	snd(m, "SND_CaveDrip", V(0, 2, 8))
end, { handpass = "a cave-mouth facade (rocks + dark Hole part): set it against a wall rock so no sky shows round the back" })

-- F22 Charcoal kiln: a domed earth kiln with a smoke vent, a stoking mouth, logs stacked, a charcoal heap,
-- a rake.
def("F22_CharcoalKiln", "Find", "Charcoal Kiln", V(420, 0, 1320), "SouthEast", function(m)
	P(m, "Dome", V(10, 10, 10), CFrame.new(0, 1, 2), C.earthDark, M.Ground, { shape = BALL })
	P(m, "DomeBase", V(1.5, 11, 11), CFrame.new(0, -0.2, 2) * CFrame.Angles(0, 0, math.pi / 2), C.earth, M.Ground, { shape = CYL })
	cyl(m, "Vent", CFrame.new(0.6, 6.6, 2.4), 1.4, 1.4, C.stoneDark, M.Slate)
	P(m, "MouthArch", V(2.6, 2.4, 1.4), CFrame.new(0, 1, -2.6), C.stoneDark, M.Slate)
	P(m, "MouthGlow", V(1.6, 1.4, 0.2), CFrame.new(0, 0.9, -3.35), C.ember, M.Neon, { nc = true, shadow = false })
	light(m.MouthGlow, 10, 0.6)
	for k = 0, 8 do
		local row = math.floor(k / 3)
		rod(m, "Log", V(7, 0.5 + row * 0.9, -1 + (k % 3) * 0.95 + row * 0.45), V(11, 0.5 + row * 0.9, -1 + (k % 3) * 0.95 + row * 0.45), 0.9, k % 2 == 0 and C.woodLight or C.woodPale, M.Wood, { nc = row > 0 })
	end
	for i = 1, 7 do
		P(m, "Charcoal", V(rr(0.8, 1.4), rr(0.5, 0.9), rr(0.8, 1.4)), CFrame.new(-6 + rr(-1.5, 1.5), 0.2, -3 + rr(-1.5, 1.5)) * CFrame.Angles(rr(0, 1), rr(0, 6), 0), C.char, M.Slate, { nc = true })
	end
	rod(m, "RakeHaft", V(-8, 0.2, 1), V(-6.5, 5.5, 2), 0.25, C.woodPale, M.Wood, { nc = true })
	P(m, "RakeHead", V(1.8, 0.3, 0.3), CFrame.new(-8, 0.3, 1), C.iron, M.Metal, { nc = true })
	spot(m, "PromptSpot", V(0, 0.5, -5))
	fx(m, "FX_KilnSmoke", V(0.6, 7.5, 2.4))
	snd(m, "SND_KilnCrackle", V(0, 1, -2.6))
end)

-- F23 Sword in the rock: a moss boulder with a great sword driven in to the hilt, a jade gem in the
-- pommel, a rope with paper talismans round the rock, small offerings at its foot.
def("F23_SwordInRock", "Find", "Sword in the Rock", V(300, 0, 1350), "SouthEast", function(m)
	rock(m, "low", V(0, 0, 0), 7, 0.2, { name = "Boulder" })
	sword(m, CFrame.new(0.3, 6, 0) * CFrame.Angles(0.1, 0.4, 0.08), 1.7, { blade = C.stone })
	P(m, "Gem", V(0.7, 0.7, 0.7), CFrame.new(0.3, 6, 0) * CFrame.Angles(0.1, 0.4, 0.08) * CFrame.new(0, 10.5, 0), C.jadeLight, M.Neon, { nc = true, shadow = false, shape = BALL })
	for i = 0, 11 do
		local a, b = i / 12 * math.pi * 2, (i + 1) / 12 * math.pi * 2
		beam(m, "Rope", V(math.cos(a) * 6.3, 3.4 + math.sin(a * 2) * 0.3, math.sin(a) * 5), V(math.cos(b) * 6.3, 3.4 + math.sin(b * 2) * 0.3, math.sin(b) * 5), 0.3, 0.3, C.straw, M.Fabric, { nc = true })
		if i % 3 == 0 then
			P(m, "Talisman", V(0.6, 1.4, 0.05), CFrame.new(math.cos(a) * 6.5, 2.5, math.sin(a) * 5.2) * CFrame.Angles(0, -a + math.pi / 2, 0), C.paper, M.SmoothPlastic, { nc = true, shadow = false })
		end
	end
	for i = -1, 1 do
		cyl(m, "OfferingBowl", CFrame.new(i * 1.2, 0.2, -6.4), 0.4, 0.8, i == 0 and C.goldDark or C.bone, M.SmoothPlastic, { nc = true })
	end
	spot(m, "PromptSpot", V(0, 0.5, -6))
	fx(m, "FX_SwordAura", V(0.3, 9, 0), V(3, 6, 3))
	snd(m, "SND_SwordHum", V(0.3, 7, 0))
end, { note = "the sword is the read from the path: keep its -Z side open" })

-- F24 Lone pine with a meditation mat: a big pine alone in the meadow, a straw mat and incense bowl under
-- it, a gourd and a walking staff leaning on the trunk.
def("F24_LonePineMat", "Find", "Lone Pine", V(-220, 0, 960), "CrossWest", function(m)
	tree(m, INNO.Pine_Trees.Variation_04["Pine_04.2"], V(0, 0, 3), { h = 44, yaw = 0.7, name = "LonePine" })
	P(m, "MatStone", V(5, 0.6, 4), CFrame.new(0, 0, -4), C.stoneDark, M.Slate)
	P(m, "Mat", V(3.4, 0.15, 2.6), CFrame.new(0, 0.38, -4), C.straw, M.Fabric, { nc = true, shadow = false })
	cyl(m, "IncenseBowl", CFrame.new(1.6, 0.55, -6), 0.4, 0.8, C.goldDark, M.Metal, { nc = true })
	P(m, "Gourd", V(0.9, 1.3, 0.9), CFrame.new(-2, 0.65, -3.2), C.gold, M.SmoothPlastic, { nc = true, shape = BALL })
	rod(m, "Staff", V(1.3, 0, 1.6), V(0.8, 5.6, 2.3), 0.3, C.woodPale, M.Wood, { nc = true })
	plant(m, "Clover_M", V(-4, 0, -6), {})
	spot(m, "PromptSpot", V(0, 0.6, -4))
	snd(m, "SND_Wind", V(0, 20, 3))
	fx(m, "FX_IncenseSmoke", V(1.6, 1.2, -6))
end)

-- F25 Herbalist's drying racks: two bamboo racks with trays of herbs, baskets, a stool and a mortar.
def("F25_DryingRacks", "Find", "Herbalist's Racks", V(-330, 0, 1030), "CrossWest", function(m)
	for r, x in { -3.5, 3.5 } do
		local rack = model(m, "Rack_" .. r)
		for _, s in { -1, 1 } do
			for _, z in { -1.3, 1.3 } do
				P(rack, "Pole", V(0.35, 6, 0.35), CFrame.new(x + s * 2.2, 2.6, z), hex("8FA060"), M.Wood)
			end
		end
		for k = 0, 2 do
			P(rack, "Tray", V(4.8, 0.2, 2.8), CFrame.new(x, 1.4 + k * 1.6, 0), C.straw, M.Fabric)
			for i = 1, 4 do
				P(rack, "Herbs", V(0.9, 0.25, 0.7), CFrame.new(x - 1.6 + i * 0.75, 1.6 + k * 1.6, rr(-0.8, 0.8)) * CFrame.Angles(0, rr(0, 6), 0), k == 1 and C.herbGold or C.lawn, M.SmoothPlastic, { nc = true, shadow = false })
			end
		end
	end
	for i, p in { V(0, 0, -3), V(-7, 0, 2) } do
		cyl(m, "Basket", CFrame.new(p + V(0, 0.7, 0)), 1.4, 1.8, C.straw, M.Fabric, { nc = true })
	end
	cyl(m, "Stool", CFrame.new(2.5, 0.8, -3.5), 1.6, 1.5, C.wood, M.Wood)
	cyl(m, "Mortar", CFrame.new(-2, 0.6, -3.6), 1.2, 1.3, C.stoneMid, M.Slate)
	rod(m, "Pestle", V(-2, 0.9, -3.6), V(-1.6, 2.2, -3.3), 0.3, C.woodPale, M.Wood, { nc = true })
	plant(m, "Fern_S", V(7, 0, 2), {})
	spot(m, "PromptSpot", V(0, 0.5, -5))
	fx(m, "FX_HerbScent", V(0, 3, 0), V(10, 4, 4))
end)

-- F26 Toppled statue head: a giant stone sage's head lying on its cheek, topknot and crown, half sunk,
-- moss in the creases; the broken neck stub a few steps away.
def("F26_StatueHead", "Find", "Toppled Statue Head", V(200, 0, 1150), "CrossEast", function(m)
	local h = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0.3, math.rad(70))
	P(m, "Head", V(8, 9, 8), h, C.stone, M.Slate)
	P(m, "Brow", V(8.2, 1, 2), h * CFrame.new(0, 1.2, -3.8), C.stoneMid, M.Slate)
	P(m, "Nose", V(1.4, 2.6, 1.6), h * CFrame.new(0, -0.6, -4.4), C.stone, M.Slate)
	for _, s in { -1, 1 } do
		P(m, "Eye", V(2, 0.5, 0.3), h * CFrame.new(s * 1.9, 0.4, -4.05), C.stoneDark, M.Slate, { nc = true })
		P(m, "Ear", V(1, 4.2, 2), h * CFrame.new(s * 4.4, -0.3, 0), C.stoneMid, M.Slate)
	end
	P(m, "Mouth", V(2.4, 0.4, 0.3), h * CFrame.new(0, -2.6, -4.05), C.stoneDark, M.Slate, { nc = true })
	P(m, "Topknot", V(3.4, 3, 3.4), h * CFrame.new(0, 5.6, 0.6), C.stoneMid, M.Slate, { shape = BALL })
	P(m, "Crown", V(6.4, 1.2, 5), h * CFrame.new(0, 4.8, 0.4), C.goldDark, M.Slate)
	moss(m, h * CFrame.new(-3.2, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), V(5, 0.3, 4))
	moss(m, h * CFrame.new(0, 4.6, -1.8), V(4, 0.3, 1.5))
	P(m, "NeckStub", V(5, 3.5, 5), CFrame.new(10, 0.8, 4) * CFrame.Angles(0.1, 0.5, 0.05), C.stoneMid, M.Slate)
	moss(m, CFrame.new(10, 2.6, 4) * CFrame.Angles(0.1, 0.5, 0.05), V(4, 0.25, 4))
	rubble(m, V(5, 0, 2), 6, 8)
	plant(m, "Fern_M", V(-5, 0, 4), {})
	plant(m, "Bush_S", V(12, 0, -2), { scale = 0.5 })
	spot(m, "PromptSpot", V(0, 0.5, -6))
end, { note = "the face looks toward -Z" })

-- F27 Spirit-beast skeleton: a huge arched spine of vertebrae with paired ribs, a horned skull resting
-- at one end, a faint qi glow where the core was.
def("F27_BeastSkeleton", "Find", "Spirit-Beast Skeleton", V(380, 0, 1170), "CrossEast", function(m)
	local n = 14
	for i = 0, n do
		local t = i / n
		local x = -16 + t * 32
		local y = 0.8 + math.sin(t * math.pi) * 5
		local s = 1.8 - math.abs(t - 0.4) * 1.4
		P(m, "Vertebra", V(1.3, s * 1.2, s * 1.4), CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.cos(t * math.pi) * 0.5), hex("C8BC9C"), M.SmoothPlastic)
		if i >= 3 and i <= 10 then
			for _, side in { -1, 1 } do
				local a = V(x, y, side * 0.6)
				local b = V(x + 0.6, y * 0.5 + 1.2, side * 5)
				local c = V(x + 1, -0.2, side * 5.6)
				rod(m, "Rib", a, b, 0.55, hex("C8BC9C"), M.SmoothPlastic, { nc = true })
				rod(m, "Rib", b, c, 0.45, hex("C8BC9C"), M.SmoothPlastic, { nc = true })
			end
		end
	end
	local sk = CFrame.new(-19, 1.6, 1) * CFrame.Angles(0, 0.3, 0.15)
	P(m, "Skull", V(5, 3, 3.6), sk, hex("C8BC9C"), M.SmoothPlastic)
	P(m, "Jaw", V(4.2, 0.8, 2.8), sk * CFrame.new(-0.6, -1.7, 0) * CFrame.Angles(0, 0, 0.15), hex("C8BC9C"), M.SmoothPlastic, { nc = true })
	for _, s in { -1, 1 } do
		P(m, "EyeSocket", V(1, 1, 0.3), sk * CFrame.new(-0.8, 0.5, s * 1.75), C.char, M.SmoothPlastic, { nc = true })
		rod(m, "Horn", (sk * CFrame.new(1.4, 1.3, s * 1.2)).Position, (sk * CFrame.new(5.5, 4.8, s * 2.6)).Position, 0.8, C.clothPale, M.SmoothPlastic, { nc = true })
	end
	fx(m, "FX_CoreGlow", V(0, 2, 0), V(6, 3, 6))
	spot(m, "PromptSpot", V(0, 0.5, -7))
	spot(m, "CacheSpot", V(8, 0.5, -8))
end, { note = "30 long along X; walk-through between the ribs (ribs don't collide, the spine does)" })

-- F28 Fisherman's boat on the lane to the mere: a sampan pulled up on trestles, a net drying on poles, a
-- fish rack, a basket and a paddle.
def("F28_FishermansBoat", "Find", "Fisherman's Boat", V(-300, 0, 1100), "LotusLane", function(m)
	local bcf = CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0.3, 0)
	for _, z in { -3, 3 } do
		P(m, "Trestle", V(4.4, 1.2, 0.8), bcf * CFrame.new(0, -1, z), C.woodDark, M.Wood)
	end
	P(m, "Hull", V(4, 1.4, 12), bcf * CFrame.new(0, 0.3, 0), C.wood, M.WoodPlanks)
	for _, s in { -1, 1 } do
		wedge(m, "Bow", V(4, 1.4, 2.6), bcf * CFrame.new(0, 0.3, s * 7.3) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0), C.wood, M.WoodPlanks)
		P(m, "Gunwale", V(0.3, 0.5, 12.4), bcf * CFrame.new(s * 2.05, 1.2, 0), C.woodDark, M.Wood)
	end
	P(m, "Inside", V(3.4, 0.2, 11), bcf * CFrame.new(0, 0.95, 0), C.woodDark, M.WoodPlanks, { nc = true })
	-- a little woven awning at the stern
	P(m, "Awning", V(4.4, 0.25, 3.6), bcf * CFrame.new(0, 3.4, 3) * CFrame.Angles(0, 0, 0), C.straw, M.Fabric, { nc = true })
	for _, s in { -1, 1 } do
		P(m, "AwningHoop", V(0.25, 2.4, 0.25), bcf * CFrame.new(s * 2, 2.2, 3), C.woodPale, M.Wood, { nc = true })
	end
	-- net on poles
	for _, x in { 7, 13 } do
		P(m, "NetPole", V(0.4, 6, 0.4), CFrame.new(x, 2.6, -2), C.woodPale, M.Wood)
	end
	P(m, "Net", V(6, 3.6, 0.1), CFrame.new(10, 3.4, -2) * CFrame.Angles(0, 0, 0.03), hex("6F7A6A"), M.Fabric, { nc = true, shadow = false })
	P(m, "FishRack", V(4, 0.25, 1.4), CFrame.new(-7, 2.6, -3), C.woodPale, M.Wood, { nc = true })
	for _, s in { -1, 1 } do
		P(m, "RackLeg", V(0.3, 2.6, 0.3), CFrame.new(-7 + s * 1.8, 1.2, -3), C.woodPale, M.Wood, { nc = true })
	end
	for i = 1, 4 do
		P(m, "Fish", V(0.3, 1.1, 0.5), CFrame.new(-8.5 + i * 0.7, 1.9, -3), C.stone, M.SmoothPlastic, { nc = true, shadow = false })
	end
	cyl(m, "Basket", CFrame.new(-5, 0.7, 2), 1.4, 1.8, C.straw, M.Fabric, { nc = true })
	rod(m, "Paddle", V(4, 0, 3), V(3, 5, 4.6), 0.3, C.woodPale, M.Wood, { nc = true })
	spot(m, "PromptSpot", V(0, 0.5, -5))
	snd(m, "SND_Frogs", V(0, 1, 6))
end)

-- F29 Turtle stele at the Hidden trail: a bixi, the stone turtle carrying a tall stele on its back.
def("F29_TurtleStele", "Find", "Turtle Stele", V(-200, 0, 650), "Bamboo Sea", function(m)
	P(m, "Shell", V(7, 7, 7), CFrame.new(0, 0.6, 1), C.stoneMid, M.Slate, { shape = BALL })
	P(m, "ShellRim", V(1.6, 8, 9.6), CFrame.new(0, 0.2, 1) * CFrame.Angles(0, 0, math.pi / 2), C.stoneDark, M.Slate, { shape = CYL })
	P(m, "Neck", V(2, 2, 3), CFrame.new(0, 1.6, -3.6) * CFrame.Angles(-0.3, 0, 0), C.stoneMid, M.Slate)
	P(m, "Head", V(2.4, 2.2, 2.8), CFrame.new(0, 2.6, -5.2), C.stone, M.Slate)
	for _, s in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		P(m, "Foot", V(1.8, 1.4, 2.2), CFrame.new(s[1] * 3.4, 0.2, 1 + s[2] * 3), C.stoneMid, M.Slate)
	end
	stele(m, at(0, 3.6, 1.5), 8, 3.2, { name = "Stele" })
	moss(m, CFrame.new(-1.6, 3.8, 3.4), V(2.6, 0.25, 2))
	plant(m, "Fern_M", V(4, 0, -4), {})
	plant(m, "Fern_S", V(-4, 0, 5), {})
	spot(m, "PromptSpot", V(0, 0.5, -7))
	fx(m, "FX_SteleGlow", V(0, 9, 0.8))
	snd(m, "SND_BambooWind", V(0, 10, 0))
end)

-- F30 Weiqi table in the Bamboo Sea: a round stone table and board with a game left mid-way, two stools,
-- a teapot and a cup knocked over, a lantern.
def("F30_WeiqiTable", "Find", "Weiqi Table", V(-330, 0, 600), "Bamboo Sea", function(m)
	cyl(m, "TableFoot", CFrame.new(0, 1, 0), 2.8, 2.2, C.stoneDark, M.Slate)
	cyl(m, "TableTop", CFrame.new(0, 2.6, 0), 0.8, 5.6, C.stone, M.Slate)
	P(m, "Board", V(3.4, 0.06, 3.4), CFrame.new(0, 3.03, 0) * CFrame.Angles(0, 0.3, 0), C.woodPale, M.Wood, { nc = true, shadow = false })
	for i = 1, 13 do
		local a, r = rr(0, 6.28), rr(0.2, 1.5)
		P(m, i % 2 == 0 and "StoneBlack" or "StoneWhite", V(0.32, 0.12, 0.32), CFrame.new(math.cos(a) * r, 3.1, math.sin(a) * r), i % 2 == 0 and C.char or C.bone, M.SmoothPlastic, { nc = true, shadow = false, shape = CYL }).CFrame = CFrame.new(math.cos(a) * r, 3.1, math.sin(a) * r) * CFrame.Angles(0, 0, math.pi / 2)
	end
	for _, a in { 0.4, 3.5 } do
		cyl(m, "Stool", CFrame.new(math.cos(a) * 4.5, 0.8, math.sin(a) * 4.5), 2, 2, C.stoneMid, M.Slate)
	end
	P(m, "Teapot", V(0.9, 0.8, 0.9), CFrame.new(1.8, 3.4, 1.4), C.jade, M.SmoothPlastic, { nc = true, shape = BALL })
	cyl(m, "CupFallen", CFrame.new(-1.6, 3.15, 1.6) * CFrame.Angles(math.pi / 2, 0, 0), 0.5, 0.45, C.bone, M.SmoothPlastic, { nc = true })
	moss(m, CFrame.new(1.2, 3.02, -1.5) * CFrame.Angles(0, 0.5, 0), V(1.6, 0.1, 1.2))
	stoneLantern(m, V(-6, 0, 4), 0.3)
	plant(m, "Fern_S", V(5, 0, -5), {})
	spot(m, "PromptSpot", V(0, 0.5, -4))
	fx(m, "FX_Fireflies", V(0, 3, 0), V(16, 4, 16))
	snd(m, "SND_BambooWind", V(0, 12, 0))
end)

-- F31 Old armour and a sword in the gully: a rusted cuirass and helm slumped against a rock, a sword
-- driven in beside it, a broken spear, bones. The shortcut's reward.
def("F31_GullyArmour", "Find", "Armour in the Gully", V(310, 0, 920), "Giants Gully", function(m)
	rock(m, "mid", V(0, 0, 4), 9, 0.3, { name = "BackRock" })
	local cf = CFrame.new(0, 1.6, -0.6) * CFrame.Angles(-0.35, 0, 0)
	P(m, "Cuirass", V(3.4, 3.4, 1.8), cf, C.rust, M.Metal)
	P(m, "Plackart", V(2.6, 1.4, 0.4), cf * CFrame.new(0, -0.8, -1), C.goldDark, M.Metal, { nc = true })
	for _, s in { -1, 1 } do
		P(m, "Pauldron", V(1.6, 1, 2.2), cf * CFrame.new(s * 2.1, 1.3, 0) * CFrame.Angles(0, 0, s * -0.4), C.rust, M.Metal, { nc = true })
		P(m, "Tasset", V(1.4, 1.6, 0.3), cf * CFrame.new(s * 0.8, -2.1, -0.6), C.rust, M.Metal, { nc = true })
	end
	P(m, "Helm", V(2, 2, 2), CFrame.new(2.6, 0.7, -3) * CFrame.Angles(0.6, 0.8, 0.3), C.rust, M.Metal, { nc = true, shape = BALL })
	P(m, "HelmCrest", V(0.3, 1.4, 1.6), CFrame.new(2.6, 0.7, -3) * CFrame.Angles(0.6, 0.8, 0.3) * CFrame.new(0, 1, 0), C.cloth, M.Fabric, { nc = true })
	sword(m, CFrame.new(-3, -0.5, -1.5) * CFrame.Angles(0.15, 0.6, -0.12), 1.1, { blade = C.stoneMid, guard = C.goldDark })
	rod(m, "SpearShaft", V(4, 0.3, 1), V(10, 0.6, -2), 0.3, C.woodDark, M.Wood, { nc = true })
	rod(m, "SpearShaft2", V(-6, 0.3, -4), V(-9, 0.3, -1), 0.3, C.woodDark, M.Wood, { nc = true })
	P(m, "SpearHead", V(0.4, 0.2, 1.4), CFrame.new(-9.4, 0.3, -0.5) * CFrame.Angles(0, -0.8, 0), C.iron, M.Metal, { nc = true })
	bones(m, V(1, 0, -4), 3, 5)
	plant(m, "Fern_S", V(-4, 0, 3), {})
	spot(m, "PromptSpot", V(0, 0.5, -4))
	spot(m, "CacheSpot", V(-6, 0.5, -6))
	fx(m, "FX_SwordGlint", V(-3, 5.5, -1.5))
end, { note = "the gully floor; the armour slumps against BackRock (+Z)" })

--[[ =========================== BUILD =========================== ]]

local LANDMARK_ROW = { z = { 3080, 3250 }, x0 = 4080, dx = 160, per = 5 }
local FIND_ROW = { z = { 3370, 3445, 3520, 3592 }, x0 = 4050, dx = 100, per = 8 }

local root = SS:FindFirstChild("InnerWildsPrefabs")
if not root then
	root = Instance.new("Folder")
	root.Name = "InnerWildsPrefabs"
	root.Parent = SS
end
local stage = workspace:FindFirstChild("_PoiStaging")
if not stage then
	stage = Instance.new("Folder")
	stage.Name = "_PoiStaging"
	stage.Parent = workspace
end
local old = stage:FindFirstChild("_LookBoard")
if old then
	old:Destroy()
end

local function wanted(d)
	if CFG.only then
		return table.find(CFG.only, d.name) ~= nil
	end
	return CFG.group == nil or CFG.group == d.group
end

local built, report = 0, {}
local counters = { landmarks = 0, finds = 0 }
for _, d in DEFS do
	counters[d.group] += 1
	local idx = counters[d.group]
	local row = d.group == "landmarks" and LANDMARK_ROW or FIND_ROW
	local stageCF = CFrame.new(row.x0 + ((idx - 1) % row.per) * row.dx, 200, row.z[math.floor((idx - 1) / row.per) + 1])
	if not wanted(d) then
		continue
	end
	local m = Instance.new("Model")
	m.Name = d.name
	d.fn(m)
	m.WorldPivot = CFrame.new()
	m.PrimaryPart = nil
	local mn, mx = bounds(m)
	local fp = string.format("%d x %d x %d studs (x %.0f..%.0f, z %.0f..%.0f, y %.0f..%.0f)", math.ceil(mx.X - mn.X), math.ceil(mx.Z - mn.Z), math.ceil(mx.Y), mn.X, mx.X, mn.Z, mx.Z, mn.Y, mx.Y)
	m:SetAttribute("PoiName", d.poiName)
	m:SetAttribute("Kind", d.kind)
	m:SetAttribute("Zone", "Inner")
	m:SetAttribute("PlannedSpot", d.planned)
	m:SetAttribute("Pocket", d.pocket)
	m:SetAttribute("Footprint", fp)
	m:SetAttribute("Front", "-Z (approach side)")
	if d.extra.note then
		m:SetAttribute("Note", d.extra.note)
	end
	if d.extra.reseat then
		m:SetAttribute("ReseatChildren", true)
	end
	if d.extra.handpass then
		handpass(m, d.extra.handpass)
	end
	local points = {}
	for _, a in m:GetDescendants() do
		if a:IsA("Attachment") and a.Parent.Name == a.Name .. "Anchor" then
			table.insert(points, a.Name)
		end
	end
	table.sort(points)
	m:SetAttribute("Points", table.concat(points, ", "))
	CollectionService:AddTag(m, "POI")
	local prev = root:FindFirstChild(d.name)
	if prev then
		prev:Destroy()
	end
	m.Parent = root
	-- staging preview on a grass slab
	local prevStage = stage:FindFirstChild(d.name)
	if prevStage then
		prevStage:Destroy()
	end
	local holder = Instance.new("Model")
	holder.Name = d.name
	local slab = P(holder, "Slab", V(mx.X - mn.X + 16, 4, mx.Z - mn.Z + 16), stageCF * CFrame.new((mn.X + mx.X) / 2, -2, (mn.Z + mx.Z) / 2), C.lawn, M.Grass)
	slab:SetAttribute("StagingOnly", true)
	local copy = m:Clone()
	for _, t in CollectionService:GetTags(copy) do
		CollectionService:RemoveTag(copy, t) -- the preview copy stays out of the POI tour
	end
	copy:PivotTo(stageCF)
	copy.Parent = holder
	holder.Parent = stage
	-- dig the slab where the prefab asks for terrain to be cleared, as the placer will
	local cuts = {}
	for _, p in copy:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "TerrainCarve" then
			local c = p:Clone()
			c.Size += V(0, 4, 0) * (c.Shape == CYL and 0 or 1) + V(c.Shape == CYL and 4 or 0, 0, 0)
			c.CFrame = p.CFrame * CFrame.new(c.Shape == CYL and 2 or 0, c.Shape == CYL and 0 or 2, 0)
			c.Parent = holder
			table.insert(cuts, c)
		end
	end
	if #cuts > 0 then
		local ok, dug = pcall(function()
			return slab:SubtractAsync(cuts)
		end)
		if ok and dug then
			dug.Name = "Slab"
			dug.Parent = holder
			slab:Destroy()
		end
		for _, c in cuts do
			c:Destroy()
		end
	end
	built += 1
	table.insert(report, string.format("%s [%s] %s @ stage (%d, %d)", d.name, d.kind, fp, stageCF.X, stageCF.Z))
	task.wait()
end
return string.format("built %d\n%s", built, table.concat(report, "\n"))
