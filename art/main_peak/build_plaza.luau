--[[
Main-peak plaza layout pass (docs/systems/map.md, "Main peak" and pass 3). Run in Studio Edit mode
through the MCP (execute_luau). Re-runnable: it rebuilds MainPeak.Plaza.Layout from scratch and moves
the existing plaza pieces to absolute positions, so running it twice gives the same result.

  _G.PLAZA_MODE = "blockout"  -- gray parts only, props moved, lamp spots as gray posts
  _G.PLAZA_MODE = "final"     -- (default) paving, stone and wood colours, lamps, garlands, dressing

Composition (world coords, plaza floor top Y 648.6, spawn (0, 648.3, 100) facing north):
  hall terrace   x -58..58, z -31..8, +1.2 (two 0.6 risers on the front and sides); MainHall's own
                 platform rises out of it. Flanking pavilions stay on the floor at x +-76.
  west court     x -97..-45, z 14..111, +0.6: Stele, SeedMarket, a planter/bench group. Low wall on
                 its inner edge with two openings.
  east court     x 47..97, z 14..111, +0.6: PortalRing, TeleportArray_Plaza, a planter group.
  main court     the procession axis x = 0: spawn -> cauldron -> hall steps, stone lanterns in pairs,
                 garlands hung along the axis (not across it) so the view to the hall stays open.
Hub models (Elder, QuestBoard, SpiritMarket) stay on the plaza floor; nothing here touches Workspace.Hub.
]]

local MODE = _G.PLAZA_MODE or "final"
local BLOCK = MODE == "blockout"

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local Plaza = workspace.Map.Sect.MainPeak.Plaza
local Templates = SS._Templates
local Lib = SS.AssetLibrary

local FLOOR = 648.6
local TERRACE_TOP = FLOOR + 1.2
local COURT_TOP = FLOOR + 0.6
local PAVE_VARIANT = "Stylized Pavement II - BZ1 Studios"

local C = {
	pave = Color3.fromHex("B3AA9A"),
	paveLight = Color3.fromHex("C2B9A8"),
	paveDark = Color3.fromHex("9A9183"),
	curb = Color3.fromHex("8A8274"),
	stone = Color3.fromHex("8E8983"),
	stoneDark = Color3.fromHex("615D59"),
	wood = Color3.fromHex("5A3F2E"),
	woodDark = Color3.fromHex("3F2C21"),
	lacquer = Color3.fromHex("9B2D26"),
	lacquerLight = Color3.fromHex("B23A30"),
	gold = Color3.fromHex("C29A48"),
	paper = Color3.fromHex("E6D3A8"),
	jade = Color3.fromHex("5FAE96"),
	block = Color3.fromHex("A3A3A3"),
	blockDark = Color3.fromHex("7D7D7D"),
}

local layout -- Plaza.Layout, rebuilt each run

local function part(name, parent, cf, size, color, material, variant)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	if BLOCK then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = (color == C.curb or color == C.stoneDark or color == C.wood) and C.blockDark or C.block
	else
		p.Material = material or Enum.Material.SmoothPlastic
		p.MaterialVariant = variant or ""
		p.Color = color
	end
	p.Parent = parent
	return p
end

-- a box whose top face sits at `top`, spanning x0..x1 / z0..z1, `depth` deep
local function slab(name, parent, x0, x1, z0, z1, top, depth, color, material, variant)
	return part(name, parent, CFrame.new((x0 + x1) / 2, top - depth / 2, (z0 + z1) / 2),
		Vector3.new(x1 - x0, depth, z1 - z0), color, material, variant)
end

local function paved(name, parent, x0, x1, z0, z1, top, depth, color)
	return slab(name, parent, x0, x1, z0, z1, top, depth, color, Enum.Material.Pavement, PAVE_VARIANT)
end

local function folder(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function moveTo(model, pos, yaw)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	local pivot = model:GetPivot()
	local dy = pivot.Position.Y - bottom -- keep the model's base on the new surface
	local rot = yaw and CFrame.Angles(0, math.rad(yaw), 0) or (pivot - pivot.Position)
	model:PivotTo(CFrame.new(pos.X, pos.Y + dy, pos.Z) * rot)
end

-- lamps: clones of the _Templates named so DayNight's LAMP_MODELS finds them
local LIGHT = {
	StoneLantern = { holder = "Flame", color = Color3.fromHex("FFB56B"), range = 14, brightness = 1.2 },
	JadeLamp = { holder = "QiOrb", color = Color3.fromHex("7FE0C0"), range = 12, brightness = 1 },
	Brazier = { holder = "Embers", color = Color3.fromHex("FF9A4A"), range = 14, brightness = 1.3 },
}
local function lamp(kind, parent, pos, yaw)
	if BLOCK then
		return part(kind .. "Spot", parent, CFrame.new(pos + Vector3.new(0, 3.5, 0)), Vector3.new(1.5, 7, 1.5), C.block)
	end
	local m = Templates["FX_" .. kind]:Clone()
	m.Name = kind
	local spec = LIGHT[kind]
	local holder = m:FindFirstChild(spec.holder, true)
	if holder and not holder:FindFirstChildWhichIsA("Light") then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = spec.color, spec.range, spec.brightness, false
		l.Parent = holder
	end
	m.Parent = parent
	moveTo(m, pos, yaw or 0)
	return m
end

-- --- 1. structure: hall terrace, side courts, low walls ---------------------------------------------

local function buildStructure()
	local s = folder("Structure", layout)
	-- hall terrace (forecourt) with two risers on the front and both sides
	paved("HallTerrace", s, -58, 58, -31, 8, TERRACE_TOP, 1.8, C.paveLight)
	paved("HallStepFront", s, -60.5, 60.5, 8, 10.5, FLOOR + 0.6, 1.2, C.pave)
	paved("HallStepWest", s, -60.5, -58, -31, 8, FLOOR + 0.6, 1.2, C.pave)
	paved("HallStepEast", s, 58, 60.5, -31, 8, FLOOR + 0.6, 1.2, C.pave)
	slab("HallTerraceCurb", s, -58, 58, 7.6, 8.2, TERRACE_TOP + 0.05, 1.3, C.curb, Enum.Material.Slate)
	-- side courts, one step up, each its own paving tone; a curb strip on the step nose
	paved("WestCourt", s, -97, -45, 14, 111, COURT_TOP, 1.2, C.paveDark)
	paved("EastCourt", s, 47, 97, 14, 111, COURT_TOP, 1.2, C.paveDark)
	slab("WestCourtCurb", s, -45.6, -45, 14, 111, COURT_TOP + 0.05, 0.7, C.curb, Enum.Material.Slate)
	slab("WestCourtCurbS", s, -97, -45, 13.4, 14, COURT_TOP + 0.05, 0.7, C.curb, Enum.Material.Slate)
	slab("EastCourtCurb", s, 47, 47.6, 14, 111, COURT_TOP + 0.05, 0.7, C.curb, Enum.Material.Slate)
	slab("EastCourtCurbS", s, 47, 97, 13.4, 14, COURT_TOP + 0.05, 0.7, C.curb, Enum.Material.Slate)
	-- low stone walls on the courts' inner edges; openings face the axis landmarks
	local walls = {
		{ "WestWall", -46.2, { { 14, 30 }, { 44, 70 }, { 88, 111 } } },
		{ "EastWall", 48.2, { { 14, 26 }, { 40, 68 }, { 104, 111 } } },
	}
	for _, w in walls do
		for i, seg in w[3] do
			local z0, z1 = seg[1], seg[2]
			slab(w[1] .. i, s, w[2] - 0.6, w[2] + 0.6, z0, z1, COURT_TOP + 1.6, 1.6, C.stone, Enum.Material.Slate)
			slab(w[1] .. i .. "Cap", s, w[2] - 0.9, w[2] + 0.9, z0 - 0.3, z1 + 0.3, COURT_TOP + 1.95, 0.35, C.stoneDark,
				Enum.Material.Slate)
		end
	end
	-- inlay strips along the procession path so the axis reads from the spawn
	slab("AxisInlayW", s, -7.6, -7, 10.5, 116, FLOOR + 0.12, 0.3, C.curb, Enum.Material.Slate)
	slab("AxisInlayE", s, 7, 7.6, 10.5, 116, FLOOR + 0.12, 0.3, C.curb, Enum.Material.Slate)
	return s
end

-- --- 2. existing pieces re-seated on the new levels -------------------------------------------------

-- moves a piece that was already in the place by (dx, dy, dz) from where it stood before this pass. The
-- original pivot is stored on the model the first time, so re-runs land in the same spot.
local function shift(model, dx, dz, dy)
	local orig = model:GetAttribute("PlazaOrigin")
	if not orig then
		orig = model:GetPivot().Position
		model:SetAttribute("PlazaOrigin", orig)
	end
	local pv = model:GetPivot()
	model:PivotTo(pv - pv.Position + orig + Vector3.new(dx, dy, dz))
end

local function reseat()
	shift(Plaza.Stele, 0, 0, 0.6)
	shift(Plaza.SeedMarket, 0, 0, 0.6)
	shift(Plaza.PortalRing, 3, -2, 0.6) -- clear of the court's inner wall
	shift(Plaza.TeleportArray_Plaza, 0, 0, 0.6)
	-- the four identical corner planters become court groups instead of an even sprinkle
	local planters = {}
	for _, c in Plaza:GetChildren() do
		if c.Name == "Planter" then
			table.insert(planters, c)
		end
	end
	for _, p in planters do
		p.Parent = layout.Courts
		local o = p:GetAttribute("PlazaOrigin") or p:GetPivot().Position
		-- (-84, 4) and (84, 4) -> north corners of the courts; (-84, 98) stays by the SeedMarket; (84, 98) -> by the portal
		-- (+-84, 4) -> the courts' north corners; (-84, 98) -> west court south corner; (84, 98) -> by the portal
		local north = o.Z < 50
		local d = o.X < 0 and (north and Vector2.new(-6, 17) or Vector2.new(-6, 6))
			or (north and Vector2.new(6, 17) or Vector2.new(7, -34))
		shift(p, d.X, d.Y, 0.6)
	end
end

-- --- 3. lamps: the axis from the arrival to the hall, the hall entrance, the courts -----------------

local function buildLamps()
	local l = folder("Lamps", layout)
	for _, m in Plaza.PathLanterns:GetChildren() do
		m:Destroy()
	end
	-- the axis: pairs at the spawn, mid court, beside the cauldron, at the terrace foot
	for _, z in { 104, 78, 50, 22 } do
		local x = z == 50 and 19 or 10.5
		lamp("StoneLantern", Plaza.PathLanterns, Vector3.new(-x, FLOOR, z))
		lamp("StoneLantern", Plaza.PathLanterns, Vector3.new(x, FLOOR, z))
	end
	-- hall entrance: jade lamps on the terrace in front of the porch columns
	lamp("JadeLamp", l, Vector3.new(-30, TERRACE_TOP, 5))
	lamp("JadeLamp", l, Vector3.new(30, TERRACE_TOP, 5))
	-- court entrances (the wall openings) and the pavilions
	lamp("StoneLantern", l, Vector3.new(-48.5, COURT_TOP, 72))
	lamp("StoneLantern", l, Vector3.new(-48.5, COURT_TOP, 86))
	lamp("StoneLantern", l, Vector3.new(50.5, COURT_TOP, 70))
	lamp("StoneLantern", l, Vector3.new(50.5, COURT_TOP, 102))
	lamp("Brazier", l, Vector3.new(-58, FLOOR, 4))
	lamp("Brazier", l, Vector3.new(58, FLOOR, 4))
	return l
end

-- --- 4. garlands along the axis, lacquer and paper instead of neon ----------------------------------

local function rehangGarlands()
	local g = Plaza.PlazaGarlands
	local lanterns = {}
	for _, c in g:GetChildren() do
		if c.Name == "Rope" then
			c:Destroy()
		elseif c.Name == "HangingLantern" then
			table.insert(lanterns, c)
		end
	end
	table.sort(lanterns, function(a, b)
		return a:GetPivot().Position.X < b:GetPivot().Position.X
	end)
	-- poles stand at (+-16, 62) and (+-16, 92); ropes now run north-south between them
	local TOP, SAG, N = 663.6, 2.4, 8
	local idx = 0
	for _, sx in { -16, 16 } do
		local prev
		for k = 0, N do
			local t = k / N
			local p = Vector3.new(sx, TOP - SAG * 4 * t * (1 - t), 62 + 30 * t)
			if prev then
				local mid, len = (prev + p) / 2, (p - prev).Magnitude
				local r = part("Rope", g, CFrame.lookAt(mid, p), Vector3.new(0.25, 0.25, len), C.lacquer,
					Enum.Material.Fabric)
				r.CanCollide = false
			end
			if k > 0 and k < N then
				idx += 1
				local lan = lanterns[idx]
				if lan then
					local cf, size = lan:GetBoundingBox()
					local top = cf.Position.Y + size.Y / 2
					lan:PivotTo(lan:GetPivot() + (p - Vector3.new(cf.Position.X, top, cf.Position.Z)))
				end
			end
			prev = p
		end
	end
	for i = idx + 1, #lanterns do
		lanterns[i]:Destroy()
	end
	-- recolour: alternate lacquer red and warm paper bodies, gold caps; matte, not neon
	for i, lan in lanterns do
		if lan.Parent then
			for _, d in lan:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Name:match("Glow") then
						d.Material = Enum.Material.SmoothPlastic
						d.Color = (i % 3 == 0) and C.paper or (i % 2 == 0 and C.lacquerLight or C.lacquer)
					else
						d.Material = Enum.Material.Metal
						d.Color = C.gold
					end
				end
			end
		end
	end
	for _, d in g:GetChildren() do
		if d.Name == "Pole" then
			d.Color, d.Material = C.lacquer, Enum.Material.Wood
		elseif d.Name == "PoleCap" then
			d.Color, d.Material = C.gold, Enum.Material.Metal
		end
	end
	-- the hall porch's neon lanterns too
	for _, d in Plaza.MainHall:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^Lantern_Glow") then
			d.Material, d.Color = Enum.Material.SmoothPlastic, C.lacquerLight
		elseif d:IsA("BasePart") and d.Name:match("^Lantern_0") then
			d.Material, d.Color = Enum.Material.Metal, C.gold
		end
	end
end

-- --- 5. court dressing: benches, pots, shrubs in odd-numbered groups ---------------------------------

local function findLib(path)
	local node = Lib
	for name in path:gmatch("[^/]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function prop(path, parent, pos, yaw, scale)
	local src = findLib(path)
	if not src then
		warn("asset not found: " .. path)
		return nil
	end
	local m = src:Clone()
	if m:IsA("BasePart") then
		local w = Instance.new("Model")
		w.Name = m.Name
		m.Parent = w
		m = w
	end
	if scale then
		m:ScaleTo(scale)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	m.Parent = parent
	moveTo(m, pos, yaw)
	return m
end

local BENCH = "Stylized Asset Pack II (Props)/Stylized Wooden Props II/Stylized Bench"
local POT_FLOWER = "Stylized Foliage + Pots/Plants + Pots/Pot & Flower"
local POT = "Stylized Foliage + Pots/Plants + Pots/Pot"
local FERN = "Stylized Foliage + Pots/Plants + Pots/Fern"
local BUSH = "Stylized Foliage + Pots/Stylized Bushes/Stylized Bush (Green)"

local function dressCourts()
	if BLOCK then
		return
	end
	local c = layout.Courts
	-- west court: a pair of benches facing the Stele, a pot group (big + medium + small) where the wall
	-- opening meets the court
	prop(BENCH, c, Vector3.new(-71, COURT_TOP, 50), 0)
	prop(BENCH, c, Vector3.new(-57, COURT_TOP, 47), -35)
	prop(POT_FLOWER, c, Vector3.new(-50, COURT_TOP, 42), 0, 1.4)
	prop(POT_FLOWER, c, Vector3.new(-52.5, COURT_TOP, 39.5), 40)
	prop(POT, c, Vector3.new(-49.5, COURT_TOP, 38.5), 0, 0.8)
	-- east court: one bench looking at the portal, a fern + pot pair at the wall's south end
	prop(BENCH, c, Vector3.new(73, COURT_TOP, 66), 180)
	prop(POT_FLOWER, c, Vector3.new(52, COURT_TOP, 66), 0, 1.3)
	prop(FERN, c, Vector3.new(54.5, COURT_TOP, 63.5), 20)
	prop(POT, c, Vector3.new(51.5, COURT_TOP, 62), 0)
	-- the hall terrace corners: one low shrub each side, tucked against the pavilions' step
	prop(BUSH, c, Vector3.new(-54, TERRACE_TOP, -26), 0, 0.7)
	prop(BUSH, c, Vector3.new(54, TERRACE_TOP, -24), 130, 0.55)
end

local recording = CHS:TryBeginRecording("PlazaLayout_" .. MODE)
local ok, err = pcall(function()
	local old = Plaza:FindFirstChild("Layout")
	if old then
		-- planters live in Layout.Courts between runs: hand them back before rebuilding
		local courts = old:FindFirstChild("Courts")
		if courts then
			for _, p in courts:GetChildren() do
				if p.Name == "Planter" then
					p.Parent = Plaza
				end
			end
		end
		old:Destroy()
	end
	layout = folder("Layout", Plaza)
	folder("Courts", layout)
	buildStructure()
	reseat()
	buildLamps()
	rehangGarlands()
	dressCourts()
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return "plaza " .. MODE .. " built"
