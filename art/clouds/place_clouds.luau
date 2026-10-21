--[[
Builds Workspace.Map.Clouds from the stylized cloud meshes of art/clouds/build_clouds.py.
Run in Studio (Edit mode) from the command bar or the MCP, after File > Import 3D of art/clouds/Clouds.fbx
(default settings, meshes not merged). Re-runnable: once the kit exists in ServerStorage.CloudKit the
import is no longer needed, and the layout below is deterministic (seeded).

The cloud sea is a flat white plane (cheap: 9 slabs) with a sparse set of hero clouds on it. The old
dense deck (~200 meshes, ~350k tris, plus under-deck clumps and horizon banks) was cut for frame rate.

Stages (set _G.CLOUD_STAGES to run one on its own):
  kit     find the imported Cloud_* MeshParts, style them (no collision/query/touch/shadow), move them into
          ServerStorage.CloudKit, delete the import containers. With _G.CLOUD_BLOCKOUT = true it builds gray
          Ball stand-ins of the same bounds instead (layout block-out before the import).
  layout  clear the old cloud groups and lay out:
            Plane      3x3 thin white slabs, top at PLANE_TOP, hiding the peaks' feet
            Wisps      one arc hugging each spirit pillar and three stacked arcs round the main peak
            KarstWisps a sparse ring pattern (0-3 arcs: stacked, spiral, offset rings or broken crescent,
                       seeded per group) round each nearer karst group's foot; COLLARS get a puff collar
            KarstBands thin arcs or a small puff collar 60-80% up about a third of the karst pillars
            SpotRings  free ring patterns (2-3 arcs) where the user's old hand-placed rings were
            FallFoam   one puff where each waterfall ending near the plane drops into it
            Banks      three cumulus clusters and one lone tower drifting at mid height between the peaks
            Sprinkle   a few lone puffs and free wisps over open plane
          HandPlaced (any Workspace-root "Wisps" model the user makes) is folded in and never cleared.
            Mounds     ~40 squashed clumps and puffs in loose clusters, bulging 15-50 studs over the plane
          Auspicious (the swirl clouds) is kept as it is; Emitters is trimmed to EMITTER_KEEP and lifted
          onto the plane. Every remaining cloud part gets the no-collision/query/touch/shadow treatment.
Everything is one ChangeHistory recording per run, so Ctrl+Z undoes it.

Import maps Blender +X to mesh -X, +Y to mesh +Z, +Z to mesh +Y, so Size = (bx, bz, by); each mesh's origin
is the bottom centre of its footprint and the MeshPart pivot is its bounding-box centre.
]]

local STAGES = _G.CLOUD_STAGES or { kit = true, layout = true }
local BLOCKOUT = _G.CLOUD_BLOCKOUT == true
_G.CLOUD_STAGES, _G.CLOUD_BLOCKOUT = nil, nil -- flags apply to one run only


-- BEGIN MESHES (generated from Clouds.json; size in Blender axes, circle = arc centre rel. to bbox centre)
local MESHES = {
	Cloud_DeckA = { size = { 246.737, 188.766, 108.927 } }, -- 1600 tris
	Cloud_DeckB = { size = { 273.244, 171.549, 97.62 } }, -- 1600 tris
	Cloud_DeckC = { size = { 211.981, 197.025, 132.935 } }, -- 1600 tris
	Cloud_DeckLong = { size = { 401.207, 138.346, 72.34 } }, -- 1500 tris
	Cloud_Tower = { size = { 233.607, 178.514, 194.452 } }, -- 2200 tris
	Cloud_Bank = { size = { 669.316, 243.257, 327.403 } }, -- 2200 tris
	Cloud_Puff = { size = { 61.723, 54.376, 44.229 } }, -- 700 tris
	Cloud_WispArc = { size = { 300.934, 153.091, 32.023 }, circle = { -1.753, -86.207 }, radius = 130 }, -- 1400 tris
}
-- END MESHES

local SEED = 1729
local LIT = Color3.fromRGB(255, 255, 255) -- tint on the lit layers (the ramp texture carries the shading)
local WARM = Color3.fromRGB(255, 248, 240)
local COOL = Color3.fromRGB(236, 240, 250)
local BLOCK_COLOR = Color3.fromRGB(160, 160, 165)

local MAIN = Vector2.new(2, 2) -- main peak axis (x, z); rock radius ~172 at y 420-500
local MAIN_R = 172
local PILLAR_R = 66 -- spirit pillar radius at y 420-500
local PEAK_R = 300 -- spirit peaks ring

-- the plane: its top sits just over the lowest main-peak fall end (WestFall.CloudFall, y ~438), so that
-- fall drops into it; everything below (peak feet, Peak_8's fall end at y ~382) is hidden
local PLANE_TOP = 440
local PLANE_THICK = 2
local PLANE_TILE = 1400 -- slab width; 3x3 covers +-2100 (Part sizes cap at 2048), the haze takes the edge
local PLANE_COLOR = Color3.fromRGB(246, 248, 252)
local PLANE_MATERIAL = Enum.Material.Fabric -- matte, like the cloud meshes (SmoothPlastic gets a sun glare)

-- CloudLineFog emitters (a kept group, not built here) to keep, by their (x, z); the rest are deleted
local EMITTER_KEEP = {
	Vector2.new(420, 0),
	Vector2.new(130, 399),
	Vector2.new(-340, 247),
	Vector2.new(-340, -247),
	Vector2.new(130, -399),
	Vector2.new(0, 240), -- in the plaza's southern view
}


local CHS = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")
local clouds = workspace.Map.Clouds

local function robloxSize(name)
	local s = MESHES[name].size
	return Vector3.new(s[1], s[3], s[2])
end

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Locked = false
end

local function kit()
	local folder = ServerStorage:FindFirstChild("CloudKit")
	if BLOCKOUT then
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "CloudKit"
		for name in MESHES do
			local p = Instance.new("Part")
			p.Name = name
			p.Shape = Enum.PartType.Ball
			p.Size = robloxSize(name)
			p.Material = Enum.Material.SmoothPlastic
			p.Color = BLOCK_COLOR
			quiet(p)
			p.Parent = folder
		end
		folder.Parent = ServerStorage
		return
	end
	local found, containers = {}, {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") and MESHES[d.Name] and not d:IsDescendantOf(clouds) then
			assert(not found[d.Name], "two imported copies of " .. d.Name .. "; delete the extra import first")
			found[d.Name] = d
			local top = d
			while top.Parent ~= workspace do
				top = top.Parent
			end
			containers[top] = true
		end
	end
	if next(found) == nil then
		assert(folder and folder:FindFirstChildWhichIsA("MeshPart"), "no Cloud_* import found; File > Import 3D Clouds.fbx first")
		return -- re-run on the existing kit
	end
	for name in MESHES do
		assert(found[name], "imported mesh " .. name .. " missing from the Clouds.fbx import")
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "CloudKit"
	for name, part in found do
		part = part :: MeshPart
		part.Size = robloxSize(name)
		part.CFrame = CFrame.new()
		part.Material = Enum.Material.Fabric -- matte: SmoothPlastic put shiny sun highlights on every crown
		part.Color = LIT
		part.CollisionFidelity = Enum.CollisionFidelity.Box
		part.RenderFidelity = Enum.RenderFidelity.Automatic
		quiet(part)
		part.Parent = folder
	end
	for top in containers do
		if top.Parent and top ~= folder then
			top:Destroy()
		end
	end
	folder.Parent = ServerStorage
end

-- layout ---------------------------------------------------------------------------------------------

local rng = Random.new(SEED)
local function rand(a, b)
	return rng:NextNumber(a, b)
end
local function pick(list)
	return list[rng:NextInteger(1, #list)]
end
local function polar(deg, r)
	local a = math.rad(deg)
	return Vector2.new(math.cos(a) * r, math.sin(a) * r)
end

local templates
local function tint(p: BasePart, c: Color3)
	p.Color = c
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		local any: any = sa
		pcall(function()
			any.Color = c -- SurfaceAppearance.Color tints the ColorMap where the engine supports it
		end)
	end
end

-- one cloud with its footprint's bottom centre at `bottom`, turned `yaw` radians about Y
local function cloud(group: Instance, name: string, bottom: Vector3, yaw: number, scale: number, color: Color3?)
	local p = templates[name]:Clone()
	local size = robloxSize(name) * scale
	p.Size = size
	p.CFrame = CFrame.new(bottom + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0)
	tint(p, color or LIT)
	p.Parent = group
	return p
end

-- an arc wisp wrapped around a pillar axis `centre` (x, z) at radius `radius`, its middle facing `deg`
-- `tilt` (radians) leans the arc's middle up or down about its circle centre; `thick` scales the tube height
local function arc(group: Instance, centre: Vector2, y: number, radius: number, deg: number, color: Color3?, tilt: number?, thick: number?)
	local m = MESHES.Cloud_WispArc
	local s = radius / m.radius
	local size = robloxSize("Cloud_WispArc") * s
	size = Vector3.new(size.X, size.Y * (thick or 1), size.Z)
	-- circle centre in part-local coords (mesh x = -Blender x, mesh z = Blender y)
	local cc = Vector3.new(-m.circle[1], 0, m.circle[2]) * s
	local a = math.rad(deg)
	local yaw = math.atan2(math.cos(a), math.sin(a)) -- local +Z (the arc's middle) toward deg
	local p = templates.Cloud_WispArc:Clone()
	p.Size = size
	p.CFrame = CFrame.new(centre.X, y + size.Y / 2, centre.Y) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt or 0, 0, 0) * CFrame.new(-cc)
	tint(p, color or LIT)
	p.Parent = group
	return p
end

local function fx(part: BasePart, name: string, world: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.WorldPosition = world
	a.Parent = part
	return a
end

local function peaks()
	local list = {}
	for k = 0, 7 do
		table.insert(list, polar(22.5 + 45 * k, PEAK_R))
	end
	return list
end

local function newGroup(name)
	local old = clouds:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local g = Instance.new("Model")
	g.Name = name
	return g
end

local function plane()
	local g = newGroup("Plane")
	for i = -1, 1 do
		for j = -1, 1 do
			local p = Instance.new("Part")
			p.Name = "CloudPlane"
			p.Size = Vector3.new(PLANE_TILE, PLANE_THICK, PLANE_TILE)
			p.CFrame = CFrame.new(i * PLANE_TILE, PLANE_TOP - PLANE_THICK / 2, j * PLANE_TILE)
			p.Material = PLANE_MATERIAL
			p.Color = PLANE_COLOR
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = g
		end
	end
	return g
end

-- karst ring patterns: the karst groups nearer than KARST_RING_R each get their own sparse pattern (0-3 arcs),
-- seeded per group so each is different but re-runs come out the same, and only COLLARS get a mid-height
-- puff collar. They draw from their own Random, so the groups built from the main seed are unaffected.
-- (The spirit peaks and the main peak keep their simple Wisps below: the user likes them as they are.)
local KARST_RING_R = 1500 -- karst group centres within this radius of the origin get a ring pattern
-- a band (thin arcs or a small puff collar) 60-80% of the way up about a third of the karst pillars
local BAND_CHANCE = 1 / 3
local BAND_FRACTION = { 0.6, 0.8 }
-- free-floating ring patterns where the user had hand-placed wisp rings: (x, z, lowest y, ring radius, collar)
local SPOT_RINGS = {
	{ 989, 1023, PLANE_TOP - 4, 150, false },
	{ 1147, -1058, PLANE_TOP - 4, 150, false },
	{ -1205, -1765, PLANE_TOP - 4, 150, false },
	{ -1766, -416, PLANE_TOP - 4, 150, false },
	{ -1472, 1433, 680, 150, true }, -- round Far_133, at mid height
}
local RING_PATTERNS = { "stacked", "spiral", "offset", "broken" }
local KARST_ARCS = { 0, 0, 1, 1, 2, 3 } -- arcs per karst group, picked per group
local COLLARS = { WestMesa = true, EastSentinels = true } -- only these get a puff collar

local function collar(g: Instance, centre: Vector2, radius: number, y: number, count: number?)
	local n = count or rng:NextInteger(5, 6)
	local a0 = rand(0, 360)
	for i = 0, n - 1 do
		local q = centre + polar(a0 + i * 360 / n + rand(-12, 12), radius + rand(-4, 8))
		local s = robloxSize("Cloud_Puff") * rand(1.0, 1.4)
		local p = templates.Cloud_Puff:Clone()
		p.Size = Vector3.new(s.X, s.Y * rand(0.6, 0.8), s.Z)
		p.CFrame = CFrame.new(q.X, y + rand(-5, 5), q.Y) * CFrame.Angles(0, rand(0, 2 * math.pi), 0)
		tint(p, i % 2 == 0 and WARM or COOL)
		p.Parent = g
	end
end

-- `n` arcs in one pattern round the axis `centre` (rock radius `r`) between heights yLo and yHi
local function ring(g: Instance, centre: Vector2, r: number, yLo: number, yHi: number, n: number, withCollar: boolean)
	local pattern = pick(RING_PATTERNS)
	local a0 = rand(0, 360)
	local dir = rng:NextNumber() < 0.5 and -1 or 1
	local first
	local function put(y, radius, deg, i, thick)
		local tilt = math.rad(rand(-7, 7))
		local p = arc(g, centre, y, radius, deg, i % 2 == 0 and WARM or COOL, tilt, thick or rand(0.8, 1.3))
		first = first or p
	end
	if n == 1 then -- a lone arc low on the rock
		put(yLo + rand(0, 20), r + rand(6, 14), a0, 0)
	elseif pattern == "stacked" then -- bands stacked up the rock, each facing a different way
		local step = (yHi - yLo) / n
		for i = 0, n - 1 do
			put(yLo + i * step + rand(-4, 4), r + rand(6, 14), a0 + i * rand(100, 150), i)
		end
	elseif pattern == "spiral" then -- a corkscrew climbing round the rock, opening out as it rises
		local turn = rand(65, 95)
		for i = 0, n - 1 do
			put(yLo + (yHi - yLo) * i / math.max(1, n - 1), r + 8 + i * rand(3, 7), a0 + dir * i * turn, i)
		end
	elseif pattern == "offset" then -- a tight inner ring higher up and a wide outer ring low, gaps offset
		local inner = math.ceil(n / 2)
		local yIn = yLo + (yHi - yLo) * rand(0.35, 0.6)
		for i = 0, inner - 1 do
			put(yIn + rand(-4, 4), r + rand(5, 9), a0 + i * 360 / inner + rand(-15, 15), i)
		end
		local outer = n - inner
		local rOut = r + rand(40, 60)
		for i = 0, outer - 1 do
			put(yLo + rand(0, 10), rOut + rand(-6, 6), a0 + 180 / math.max(1, outer) + i * 360 / outer + rand(-20, 20), i + 1, rand(0.7, 1.0))
		end
	elseif n > 0 then -- broken crescent: thin arcs at one height with gaps between
		local y = yLo + (yHi - yLo) * rand(0, 0.4)
		local radius = r + rand(8, 16)
		for i = 0, n - 1 do
			put(y + rand(-6, 6), radius + rand(-4, 4), a0 + i * 360 / n + rand(-25, 25), i, rand(0.6, 0.9))
		end
	end
	if withCollar then -- a dense collar of squashed puffs hugging the rock mid-height
		collar(g, centre, r + 6, (yLo + yHi) / 2 + rand(-8, 8))
	end
	return first, n > 0 and pattern or "none"
end

-- the XZ centre, radius and top of a karst group above the plane
local function karstBounds(model: Instance)
	local minx, maxx, minz, maxz, top = math.huge, -math.huge, math.huge, -math.huge, -math.huge
	local bottom = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			bottom = math.min(bottom, d.Position.Y - d.Size.Y / 2)
		end
		if d:IsA("BasePart") and d.Position.Y + d.Size.Y / 2 > PLANE_TOP then
			minx, maxx = math.min(minx, d.Position.X - d.Size.X / 2), math.max(maxx, d.Position.X + d.Size.X / 2)
			minz, maxz = math.min(minz, d.Position.Z - d.Size.Z / 2), math.max(maxz, d.Position.Z + d.Size.Z / 2)
			top = math.max(top, d.Position.Y + d.Size.Y / 2)
		end
	end
	if top == -math.huge then
		return nil, 0, 0, 0
	end
	return Vector2.new((minx + maxx) / 2, (minz + maxz) / 2), math.max(maxx - minx, maxz - minz) / 2, top, bottom
end

local function wisps()
	local g = newGroup("Wisps")
	for k, c in peaks() do
		local out = 22.5 + 45 * (k - 1) -- the pillar's outward direction
		local p = arc(g, c, rand(PLANE_TOP - 4, PLANE_TOP + 6), PILLAR_R + 8, out + rand(-35, 35), k % 2 == 0 and COOL or WARM)
		local m = c + polar(out, PILLAR_R + 12)
		fx(p, "FX_PillarMist", Vector3.new(m.X, PLANE_TOP + 10, m.Y))
	end
	-- the main peak: three bands stacked at different heights, facing different ways
	for i, spec in { { PLANE_TOP - 4, 50 }, { 458, 190 }, { 482, 305 } } do
		local p = arc(g, MAIN, spec[1], MAIN_R + 14 - i * 2, spec[2] + rand(-15, 15), i == 2 and COOL or WARM)
		local m = MAIN + polar(spec[2], MAIN_R + 16)
		fx(p, "FX_PillarMist", Vector3.new(m.X, spec[1] + 14, m.Y))
	end
	return g
end

local function nameSeed(name: string)
	local seed = SEED
	for b = 1, #name do
		seed = (seed * 31 + string.byte(name, b)) % 2147483647
	end
	return seed
end

local function karstModels()
	local karst = workspace.Map:FindFirstChild("Karst")
	local models = karst and karst:GetChildren() or {}
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	return models
end

-- a sparse ring pattern round each nearer karst group, at its foot
local function karstWisps()
	local g = newGroup("KarstWisps")
	local base = rng
	for _, model in karstModels() do
		local c, r, top = karstBounds(model)
		if c and c.Magnitude <= KARST_RING_R then
			rng = Random.new(nameSeed(model.Name))
			local n = pick(KARST_ARCS)
			if n > 0 or COLLARS[model.Name] then
				local q = ring(g, c, r * 0.8, PLANE_TOP, math.min(top - 60, 640), n, COLLARS[model.Name] == true)
				if q then
					fx(q, "FX_PillarMist", Vector3.new(c.X + r, PLANE_TOP + 14, c.Y))
				end
			end
		end
	end
	rng = base
	return g
end

-- bands high on about a third of the single karst pillars (the groups' child models)
local function karstBands()
	local g = newGroup("KarstBands")
	local base = rng
	for _, group in karstModels() do
		local pillars = group:GetChildren()
		table.sort(pillars, function(a, b)
			return a.Name < b.Name
		end)
		for _, pillar in pillars do
			rng = Random.new(nameSeed(pillar.Name .. "#band"))
			if pillar:IsA("Model") and rng:NextNumber() < BAND_CHANCE then
				local c, r, top, bottom = karstBounds(pillar)
				local y = c and bottom + (top - bottom) * rand(BAND_FRACTION[1], BAND_FRACTION[2])
				if c and y > PLANE_TOP + 25 and y < top - 20 then
					local radius = r * 0.85 + 6
					if rng:NextNumber() < 0.55 then -- one or two thin arcs
						local a0 = rand(0, 360)
						arc(g, c, y, radius, a0, WARM, math.rad(rand(-6, 6)), rand(0.6, 0.9))
						if rng:NextNumber() < 0.5 then
							arc(g, c, y + rand(-8, 8), radius + rand(-3, 5), a0 + 180 + rand(-30, 30), COOL, math.rad(rand(-6, 6)), rand(0.6, 0.9))
						end
					else -- a small puff collar
						collar(g, c, radius - 4, y, rng:NextInteger(3, 5))
					end
				end
			end
		end
	end
	rng = base
	return g
end

-- free ring patterns at the spots of the user's old hand-placed rings
local function spotRings()
	local g = newGroup("SpotRings")
	local base = rng
	for i, spot in SPOT_RINGS do
		rng = Random.new(SEED + (40 + i) * 7919)
		ring(g, Vector2.new(spot[1], spot[2]), spot[4], spot[3], spot[3] + rand(50, 70), rng:NextInteger(2, 3), spot[5])
	end
	rng = base
	return g
end

local function fallFoam(feet)
	local g = newGroup("FallFoam")
	for _, foot in feet do
		local dir = Vector2.new(foot.X - MAIN.X, foot.Z - MAIN.Y).Unit
		local base = Vector2.new(foot.X, foot.Z) + dir * 14
		local big = cloud(g, "Cloud_Puff", Vector3.new(base.X, PLANE_TOP - 30, base.Y), rand(0, 6.28), 1.9, LIT)
		fx(big, "FX_FallMist", Vector3.new(foot.X, PLANE_TOP + 6, foot.Z))
	end
	return g
end

local function banks()
	local g = newGroup("Banks")
	-- (angle, radius, bottom y, {shape, scale, offset along, offset across, dy}...)
	local clusters = {
		{ 0, 560, 470, { { "Cloud_Tower", 1.0, 0, 0, 0 }, { "Cloud_Puff", 1.7, 120, 40, 18 }, { "Cloud_Puff", 1.0, -110, -30, 30 } } },
		{ 90, 610, 452, { { "Cloud_DeckC", 0.9, 0, 0, 0 }, { "Cloud_Puff", 1.4, 110, 20, 10 }, { "Cloud_Puff", 0.9, -105, 25, 20 } } },
		{ 225, 580, 515, { { "Cloud_Tower", 1.25, 0, 0, 0 }, { "Cloud_Puff", 1.6, -150, 30, 25 }, { "Cloud_Puff", 0.85, 140, -20, 60 } } },
	}
	for _, cl in clusters do
		local c = polar(cl[1], cl[2])
		local along = polar(cl[1] + 90, 1)
		local outward = polar(cl[1], 1)
		for j, piece in cl[4] do
			local q = c + along * piece[3] + outward * piece[4]
			local p = cloud(g, piece[1], Vector3.new(q.X, cl[3] + piece[5], q.Y), -math.rad(cl[1]) + rand(-0.4, 0.4), piece[2], j == 1 and LIT or WARM)
			if j == 1 then
				fx(p, "FX_BankMist", p.Position - Vector3.new(0, p.Size.Y * 0.35, 0))
			end
		end
	end
	local solo = polar(315, 950)
	cloud(g, "Cloud_Tower", Vector3.new(solo.X, 545, solo.Y), rand(0, 6.28), 1.6, LIT)
	return g
end

-- low mounds on the plane so it has relief: loose clusters (big + medium + small) framing the peaks and on
-- the plaza's sightlines, open flat plane between them, fewer and wider toward the haze. Each is a deck
-- clump or puff squashed so it bulges 15-50 studs over the plane, its base sunk MOUND_SINK under it.
local MOUND_SINK = 6
local MOUND_CLUSTERS = { -- (angle deg, radius, deck clumps, puffs, spread)
	{ 0, 430, 2, 3, 110 },
	{ 135, 440, 2, 3, 110 },
	{ 240, 430, 2, 3, 110 },
	{ 300, 480, 2, 3, 110 },
	{ 55, 760, 2, 2, 140 },
	{ 140, 820, 2, 2, 140 },
	{ 330, 900, 1, 2, 160 },
	{ 175, 1120, 1, 2, 180 },
	{ 20, 1300, 1, 2, 200 },
	{ 260, 1260, 1, 2, 200 },
}
local SOUTH_VIEW = { 100, 650, 150 } -- (deg, r, radius) kept flat: the plaza's southern view

local function moundSpot(p: Vector2, pillars, feet)
	if (p - MAIN).Magnitude < MAIN_R + 30 or (p - polar(SOUTH_VIEW[1], SOUTH_VIEW[2])).Magnitude < SOUTH_VIEW[3] then
		return false
	end
	for _, c in pillars do
		if (p - c).Magnitude < PILLAR_R + 25 then
			return false
		end
	end
	for _, f in feet do
		if (p - Vector2.new(f.X, f.Z)).Magnitude < 90 then
			return false
		end
	end
	return true
end

local function mound(g: Instance, name: string, p: Vector2, widthScale: number, bulge: number, color: Color3)
	local s = robloxSize(name)
	local part = templates[name]:Clone()
	part.Size = Vector3.new(s.X * widthScale, bulge + MOUND_SINK, s.Z * widthScale)
	part.CFrame = CFrame.new(p.X, PLANE_TOP - MOUND_SINK + part.Size.Y / 2, p.Y) * CFrame.Angles(0, rand(0, 2 * math.pi), 0)
	tint(part, color)
	part.Parent = g
end

local function mounds(feet)
	local g = newGroup("Mounds")
	local pillars = peaks()
	for _, cl in MOUND_CLUSTERS do
		local centre = polar(cl[1], cl[2])
		local far = math.clamp((cl[2] - 400) / 900, 0, 1) -- 0 by the peaks .. 1 toward the haze
		local list = {}
		for i = 1, cl[3] do
			table.insert(list, pick({ "Cloud_DeckA", "Cloud_DeckB", "Cloud_DeckC" }))
		end
		for _ = 1, cl[4] do
			table.insert(list, "Cloud_Puff")
		end
		for i, name in list do
			local spot
			for _ = 1, 10 do
				local q = i == 1 and centre + polar(rand(0, 360), rand(0, 30)) or centre + polar(rand(0, 360), cl[5] * rand(0.4, 1))
				if moundSpot(q, pillars, feet) then
					spot = q
					break
				end
			end
			if spot then
				local deck = name ~= "Cloud_Puff"
				local width = deck and (i == 1 and rand(1.1, 1.35) or rand(0.8, 1.05)) + far * 0.5 or rand(1.5, 2.4) + far * 0.8
				local bulge = deck and (i == 1 and rand(38, 50) or rand(26, 36)) or rand(15, 26)
				mound(g, name, spot, width, bulge, rng:NextNumber() < 0.5 and WARM or COOL)
			end
		end
	end
	return g
end

-- a light sprinkle of lone clouds over open plane (puffs and a couple of free wisps), clear of the karst,
-- the mound clusters, the peaks and the plaza's southern view
local SPRINKLE_PUFFS, SPRINKLE_ARCS = 3, 1

local function sprinkle(feet)
	local g = newGroup("Sprinkle")
	local pillars = peaks()
	local blockers = {}
	local karst = workspace.Map:FindFirstChild("Karst")
	if karst then
		for _, model in karst:GetChildren() do
			local c, r = karstBounds(model)
			if c then
				table.insert(blockers, { c, r + 80 })
			end
		end
	end
	for _, cl in MOUND_CLUSTERS do
		table.insert(blockers, { polar(cl[1], cl[2]), cl[5] + 60 })
	end
	local function free(q)
		if not moundSpot(q, pillars, feet) then
			return false
		end
		for _, b in blockers do
			if (q - b[1]).Magnitude < b[2] then
				return false
			end
		end
		return true
	end
	for i = 1, SPRINKLE_PUFFS + SPRINKLE_ARCS do
		for _ = 1, 20 do
			local q = polar(rand(0, 360), rand(520, 1700))
			if free(q) then
				if i <= SPRINKLE_PUFFS then
					mound(g, "Cloud_Puff", q, rand(1.4, 2.2), rand(14, 24), i % 2 == 0 and WARM or COOL)
				else
					arc(g, q, PLANE_TOP - 2, rand(70, 110), rand(0, 360), WARM, math.rad(rand(-6, 6)), rand(0.7, 1.0))
				end
				table.insert(blockers, { q, 200 })
				break
			end
		end
	end
	return g
end

-- hand-placed clouds: any "Wisps" model the user drops at the Workspace root is moved into
-- Map.Clouds.HandPlaced, which the layout never clears (only the no-collision settings are applied there)
local function foldHandPlaced()
	local hand = clouds:FindFirstChild("HandPlaced")
	if not hand then
		hand = Instance.new("Folder")
		hand.Name = "HandPlaced"
		hand.Parent = clouds
	end
	for _, m in workspace:GetChildren() do
		if m.Name == "Wisps" and m:IsA("Model") then
			m.Name = "Hand_" .. (#hand:GetChildren() + 1)
			m.Parent = hand
		end
	end
	return #hand:GetChildren()
end

-- the foot of every waterfall (the "waterfall end" parts) that ends near the plane, so foam can hide it
local function waterfallFeet()
	local feet = {}
	for _, d in workspace.Map.Sect:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "waterfall end" and math.abs(d.Position.Y - PLANE_TOP) < 30 then
			table.insert(feet, d.Position)
		end
	end
	return feet
end

-- keep the emitters nearest EMITTER_KEEP, lift them onto the plane (they sat under it), delete the rest
local function trimEmitters()
	local em = clouds:FindFirstChild("Emitters")
	if not em then
		return 0
	end
	local keep = {}
	for _, want in EMITTER_KEEP do
		local best, bestD = nil, 60
		for _, p in em:GetChildren() do
			if p:IsA("BasePart") then
				local d = (Vector2.new(p.Position.X, p.Position.Z) - want).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
		if best then
			keep[best] = true
		end
	end
	for _, p in em:GetChildren() do
		if not keep[p] then
			p:Destroy()
		elseif p:IsA("BasePart") then
			p.Position = Vector3.new(p.Position.X, PLANE_TOP + p.Size.Y / 2 + 2, p.Position.Z)
		end
	end
	return #em:GetChildren()
end

local function layout()
	local kitFolder = ServerStorage:FindFirstChild("CloudKit")
	assert(kitFolder, "run the kit stage first")
	templates = {}
	for name in MESHES do
		templates[name] = assert(kitFolder:FindFirstChild(name), "CloudKit." .. name .. " missing")
	end
	for _, old in { "Puffs", "Decks", "Deck", "UnderDeck", "Horizon" } do
		local o = clouds:FindFirstChild(old)
		if o then
			o:Destroy()
		end
	end
	local counts = {}
	for _, build in { plane, wisps, function()
		return fallFoam(waterfallFeet())
	end, banks, function()
		return mounds(waterfallFeet())
	end, karstWisps, karstBands, spotRings, function()
		return sprinkle(waterfallFeet())
	end } do
		local g = build()
		g.Parent = clouds
		counts[g.Name] = #g:GetChildren()
		task.wait()
	end
	counts.Emitters = trimEmitters()
	counts.HandPlaced = #clouds.HandPlaced:GetChildren()
	-- everything (kept groups too) gets the no-collision treatment; Box fidelity so Roblox doesn't build or
	-- stream decomposed collision for parts that never collide, and no double-sided rendering
	for _, d in clouds:GetDescendants() do
		if d:IsA("BasePart") then
			quiet(d)
			if d:IsA("MeshPart") then
				d.CollisionFidelity = Enum.CollisionFidelity.Box
				d.RenderFidelity = Enum.RenderFidelity.Automatic
				pcall(function()
					(d :: any).DoubleSided = false -- not scriptable outside plugins
				end)
			end
		end
	end
	return counts
end

local rec = CHS:TryBeginRecording("Place clouds")
local ok, result = pcall(function()
	-- first, so the kit stage (which takes any Cloud_* MeshPart outside Map.Clouds for a fresh import and
	-- deletes its container) never sees the user's hand-placed wisps
	foldHandPlaced()
	if STAGES.kit then
		kit()
	end
	if STAGES.layout then
		return layout()
	end
	return nil
end)
if rec then
	CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
assert(ok, result)
local parts = 0
for _, d in clouds:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
local summary = {}
for k, v in result or {} do
	table.insert(summary, k .. "=" .. v)
end
return "clouds placed: " .. table.concat(summary, " ") .. " (Map.Clouds parts " .. parts .. ")"
