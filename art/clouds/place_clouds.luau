--[[
Builds Workspace.Map.Clouds from the stylized cloud meshes of art/clouds/build_clouds.py.
Run in Studio (Edit mode) from the command bar or the MCP, after File > Import 3D of art/clouds/Clouds.fbx
(default settings, meshes not merged). Re-runnable: once the kit exists in ServerStorage.CloudKit the
import is no longer needed, and the layout below is deterministic (seeded).

Stages (set _G.CLOUD_STAGES to run one on its own):
  kit     find the imported Cloud_* MeshParts, style them (no collision/query/touch/shadow), move them into
          ServerStorage.CloudKit, delete the import containers. With _G.CLOUD_BLOCKOUT = true it builds gray
          Ball stand-ins of the same bounds instead (layout block-out before the import).
  layout  clear the old cloud groups and lay out the layers:
            Deck       the dense cloud sea the peaks rise out of (tops y ~405-455), denser and higher near the
                       peaks, thinner and lower toward the horizon, with a few deliberate gaps
            UnderDeck  darker clumps ~70 studs under each gap so the holes read as depth, not void
            Wisps      arcs hugging each pillar and the main peak above the deck (y ~430-490)
            FallFoam   puff clusters where the four main-peak waterfalls drop into the sea
            Banks      three cumulus clusters and one lone tower drifting at mid height between the peaks
            Horizon    huge banks and towers on a ring r 1500-2600, fading into the haze
          Auspicious (the swirl clouds) and Emitters are kept as they are.
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
local UNDER = Color3.fromRGB(196, 204, 224) -- the under-deck, seen through gaps
local BLOCK_COLOR = Color3.fromRGB(160, 160, 165)

local MAIN = Vector2.new(2, 2) -- main peak axis (x, z); rock radius ~172 at y 420-500
local MAIN_R = 172
local PILLAR_R = 66 -- spirit pillar radius at y 420-500
local PEAK_R = 300 -- spirit peaks ring
-- holes in the deck (angle deg from +X toward +Z, radius from origin, hole radius)
local GAPS = {
	{ 100, 650, 140 }, -- south, in the plaza's view between Peak_1 and Peak_8
	{ 20, 760, 175 },
	{ 215, 700, 165 },
	{ 305, 1200, 240 },
	{ 160, 1380, 220 },
}
local DECK_OUTER = 1800
local FILL_OUTER = 1300 -- the lower floor layer stops here (beyond it the haze fills in)
-- the four main-peak waterfalls (world x, z of the foot, y of the cloud top there); filled from the scene
local FALL_ANGLES = { 0, 90, 180, 270 }

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
local function arc(group: Instance, centre: Vector2, y: number, radius: number, deg: number, color: Color3?)
	local m = MESHES.Cloud_WispArc
	local s = radius / m.radius
	local size = robloxSize("Cloud_WispArc") * s
	-- circle centre in part-local coords (mesh x = -Blender x, mesh z = Blender y)
	local cc = Vector3.new(-m.circle[1], 0, m.circle[2]) * s
	local a = math.rad(deg)
	local yaw = math.atan2(math.cos(a), math.sin(a)) -- local +Z (the arc's middle) toward deg
	local p = templates.Cloud_WispArc:Clone()
	p.Size = size
	p.CFrame = CFrame.new(centre.X, y + size.Y / 2, centre.Y) * CFrame.Angles(0, yaw, 0) * CFrame.new(-cc)
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

local function inGap(p: Vector2)
	for _, g in GAPS do
		if (p - polar(g[1], g[2])).Magnitude < g[3] then
			return true
		end
	end
	return false
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

local function crownTop(rr)
	return rr < 520 and rand(428, 452) or (rr < 1150 and rand(416, 440) or rand(402, 424))
end

local function deckSpot(p: Vector2, pillars)
	if inGap(p) or (p - MAIN).Magnitude < MAIN_R - 40 then
		return false
	end
	for _, c in pillars do
		if (p - c).Magnitude < PILLAR_R - 30 then
			return false
		end
	end
	return true
end

local function deck()
	local g = newGroup("Deck")
	local pillars = peaks()
	local r = 150
	while r < DECK_OUTER do
		local spacing = 170 + r * 0.16
		local n = math.max(6, math.floor(2 * math.pi * r / spacing))
		local a0 = rand(0, 360)
		-- crowns: the billowy heads
		for i = 0, n - 1 do
			local deg = a0 + (i + rand(-0.3, 0.3)) * 360 / n
			local rr = r + rand(-0.25, 0.25) * spacing
			local p = polar(deg, rr)
			if deckSpot(p, pillars) then
				local t = math.clamp((rr - 300) / (DECK_OUTER - 300), 0, 1) -- 0 near the peaks .. 1 at the edge
				local name
				if rr > 1150 then
					name = rng:NextNumber() < 0.6 and "Cloud_DeckLong" or "Cloud_DeckB"
				else
					name = rng:NextNumber() < 0.12 and "Cloud_DeckLong" or pick({ "Cloud_DeckA", "Cloud_DeckB", "Cloud_DeckC" })
				end
				local scale = rand(0.85, 1.2) + t * 0.9
				local h = robloxSize(name).Y * scale
				local yaw = name == "Cloud_DeckLong" and (-math.rad(deg) + rand(-0.5, 0.5)) or rand(0, 2 * math.pi)
				local color = rng:NextNumber() < 0.5 and WARM or COOL
				cloud(g, name, Vector3.new(p.X, crownTop(rr) - h, p.Y), yaw, scale, color)
			end
		end
		-- floor: flatter, wider clumps half a step round and ~30 lower, so the ground between crowns reads
		-- as more cloud instead of holes everywhere (the deliberate GAPS stay open)
		if r < FILL_OUTER then
			for i = 0, n - 1 do
				local deg = a0 + (i + 0.5 + rand(-0.2, 0.2)) * 360 / n
				local rr = r + rand(-0.2, 0.2) * spacing
				local p = polar(deg, rr)
				if deckSpot(p, pillars) then
					local t = math.clamp((rr - 300) / (DECK_OUTER - 300), 0, 1)
					local name = pick({ "Cloud_DeckLong", "Cloud_DeckB", "Cloud_DeckB" })
					local scale = rand(1.1, 1.45) + t * 0.8
					local h = robloxSize(name).Y * scale
					local yaw = -math.rad(deg) + rand(-0.6, 0.6)
					cloud(g, name, Vector3.new(p.X, crownTop(rr) - rand(24, 40) - h, p.Y), yaw, scale, COOL)
				end
			end
		end
		r += spacing * 0.78
	end
	return g
end

local function underDeck()
	local g = newGroup("UnderDeck")
	for _, gap in GAPS do
		local c = polar(gap[1], gap[2])
		local sizes = { 1.3, 0.95, 0.7 } -- big + medium + small per hole
		for i, s in sizes do
			local off = polar(rand(0, 360), gap[3] * (i == 1 and 0.15 or 0.55))
			local name = i == 1 and "Cloud_DeckLong" or pick({ "Cloud_DeckA", "Cloud_DeckC" })
			local h = robloxSize(name).Y * s
			cloud(g, name, Vector3.new(c.X + off.X, rand(340, 358) - h, c.Y + off.Y), rand(0, 2 * math.pi), s, UNDER)
		end
	end
	return g
end

local function wisps()
	local g = newGroup("Wisps")
	for k, c in peaks() do
		local out = 22.5 + 45 * (k - 1) -- the pillar's outward direction
		local p1 = arc(g, c, rand(430, 438), PILLAR_R + 8, out + rand(-35, 35), WARM)
		local p2 = arc(g, c, rand(462, 474), PILLAR_R + 4, out + 180 + rand(-50, 50), COOL)
		local side = out + (k % 2 == 0 and 90 or -90) + rand(-20, 20)
		local q = c + polar(side, PILLAR_R + 18)
		local puff = cloud(g, "Cloud_Puff", Vector3.new(q.X, rand(440, 452), q.Y), rand(0, 2 * math.pi), rand(1.1, 1.5), WARM)
		local m = c + polar(out, PILLAR_R + 12)
		fx(p1, "FX_PillarMist", Vector3.new(m.X, 446, m.Y))
		fx(puff, "FX_PillarMist", puff.Position)
		fx(p2, "FX_PillarMist", p2.Position)
	end
	-- the main peak: three bands stacked at different heights, facing different ways
	for i, spec in { { 428, 50 }, { 452, 190 }, { 478, 305 } } do
		local p = arc(g, MAIN, spec[1], MAIN_R + 14 - i * 2, spec[2] + rand(-15, 15), i == 2 and COOL or WARM)
		local m = MAIN + polar(spec[2], MAIN_R + 16)
		fx(p, "FX_PillarMist", Vector3.new(m.X, spec[1] + 14, m.Y))
	end
	return g
end

local function fallFoam(feet)
	local g = newGroup("FallFoam")
	for _, foot in feet do
		local dir = Vector2.new(foot.X - MAIN.X, foot.Z - MAIN.Y).Unit
		local side = Vector2.new(-dir.Y, dir.X)
		local base = Vector2.new(foot.X, foot.Z) + dir * 14
		local big = cloud(g, "Cloud_Puff", Vector3.new(base.X, 404, base.Y), rand(0, 6.28), 1.9, LIT)
		local b2 = base + side * 34 + dir * 8
		cloud(g, "Cloud_Puff", Vector3.new(b2.X, 410, b2.Y), rand(0, 6.28), 1.25, WARM)
		local b3 = base - side * 30 + dir * 18
		cloud(g, "Cloud_Puff", Vector3.new(b3.X, 414, b3.Y), rand(0, 6.28), 0.8, COOL)
		fx(big, "FX_FallMist", Vector3.new(foot.X, 430, foot.Z))
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

local function horizon()
	local g = newGroup("Horizon")
	local n = 11
	for i = 0, n - 1 do
		local deg = i * 360 / n + rand(-10, 10)
		local q = polar(deg, rand(2100, 2600))
		local s = rand(1.2, 2.0)
		cloud(g, "Cloud_Bank", Vector3.new(q.X, rand(280, 330), q.Y), -math.rad(deg) + math.pi / 2 + rand(-0.3, 0.3), s, i % 3 == 0 and COOL or WARM)
	end
	for i = 0, 4 do
		local deg = i * 72 + 36 + rand(-12, 12)
		local q = polar(deg, rand(1500, 1800))
		cloud(g, "Cloud_Tower", Vector3.new(q.X, rand(340, 370), q.Y), rand(0, 6.28), rand(1.5, 2.2), LIT)
	end
	return g
end

local function waterfallFeet()
	local feet = {}
	local wf = workspace.Map.Sect.MainPeak:FindFirstChild("Waterfalls")
	for _, deg in FALL_ANGLES do
		local best, bestY = nil, math.huge
		if wf then
			for _, d in wf:GetDescendants() do
				if d:IsA("BasePart") then
					local v = Vector2.new(d.Position.X - MAIN.X, d.Position.Z - MAIN.Y)
					local a = math.deg(math.atan2(v.Y, v.X)) % 360
					local diff = math.abs(((a - deg + 180) % 360) - 180)
					local y = d.Position.Y - d.Size.Y / 2
					if diff < 25 and y < bestY then
						best, bestY = d.Position, y
					end
				end
			end
		end
		if best then -- no fall on the south (GrandStairs) side
			table.insert(feet, Vector3.new(best.X, bestY, best.Z))
		end
	end
	return feet
end

local function layout()
	local kitFolder = ServerStorage:FindFirstChild("CloudKit")
	assert(kitFolder, "run the kit stage first")
	templates = {}
	for name in MESHES do
		templates[name] = assert(kitFolder:FindFirstChild(name), "CloudKit." .. name .. " missing")
	end
	for _, old in { "Puffs", "Decks" } do
		local o = clouds:FindFirstChild(old)
		if o then
			o:Destroy()
		end
	end
	local counts = {}
	for _, build in { deck, underDeck, wisps, function()
		return fallFoam(waterfallFeet())
	end, banks, horizon } do
		local g = build()
		g.Parent = clouds
		counts[g.Name] = #g:GetChildren()
		task.wait()
	end
	-- the kept groups (Auspicious swirl clouds, Emitters) get the same no-collision treatment; Box
	-- fidelity so Roblox doesn't build or stream decomposed collision for parts that never collide
	for _, d in clouds:GetDescendants() do
		if d:IsA("BasePart") then
			quiet(d)
			if d:IsA("MeshPart") then
				d.CollisionFidelity = Enum.CollisionFidelity.Box
			end
		end
	end
	return counts
end

local rec = CHS:TryBeginRecording("Place clouds")
local ok, result = pcall(function()
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
