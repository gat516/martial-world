--!nocheck
-- POI tour and labels, for inspecting every point of interest in Studio Edit mode.
-- Every POI, cache, find, qi node, lair, boss ring and event ground carries the
-- CollectionService tag "POI" with attributes PoiName, Kind, Zone (optional LabelNote,
-- e.g. a route length or "(later)"). See docs/systems/map.md, "Editor-only markers".
--
-- Studio copy: the ModuleScript `ServerStorage._EditorTools.PoiTour` (place-only) holds
-- this file's source; paste it in again after editing this file. In the command bar:
--   local T = require(game.ServerStorage._EditorTools.PoiTour)
--   T()            -- print every POI with its number
--   T(12)          -- select POI 12 and frame the camera on it from a player's eye height
--   T("WolfDen")   -- same, by PoiName (or instance name); partial names match too
--   T.labels()     -- rebuild the floating labels under Workspace._EditorMarkers.POILabels
--   T.handpass()   -- list builds flagged NeedsHandPass; T.handpass(3) frames the third
-- (require caches modules: after changing the module, use a fresh copy or restart Studio.)
-- Labels and blockouts under Workspace._EditorMarkers are destroyed at runtime by
-- src/server/EditorOnly.server.luau, so they never reach the game.

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local PoiTour = {}

local ZONE_ORDER = { Sect = 1, Inner = 2, Middle = 3, Outer = 4 }
local KIND_COLOR = {
	Cache = Color3.fromRGB(255, 205, 110),
	WeaponRack = Color3.fromRGB(255, 205, 110),
	QiNode = Color3.fromRGB(150, 225, 255),
	Lair = Color3.fromRGB(255, 140, 120),
	BossRing = Color3.fromRGB(255, 110, 100),
	EventGround = Color3.fromRGB(240, 200, 90),
	Array = Color3.fromRGB(190, 170, 255),
	Later = Color3.fromRGB(200, 170, 240),
}

local function bounds(inst: Instance): (CFrame, Vector3)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		return inst.CFrame, inst.Size
	end
	return CFrame.new(), Vector3.zero
end

function PoiTour.all(): { Instance }
	local list = {}
	for _, inst in CollectionService:GetTagged("POI") do
		if inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		local za, zb = ZONE_ORDER[a:GetAttribute("Zone")] or 9, ZONE_ORDER[b:GetAttribute("Zone")] or 9
		if za ~= zb then
			return za < zb
		end
		local ka, kb = tostring(a:GetAttribute("Kind")), tostring(b:GetAttribute("Kind"))
		if ka ~= kb then
			return ka < kb
		end
		return tostring(a:GetAttribute("PoiName") or a.Name) < tostring(b:GetAttribute("PoiName") or b.Name)
	end)
	return list
end

local function nameOf(inst: Instance): string
	return tostring(inst:GetAttribute("PoiName") or inst.Name)
end

function PoiTour.list(): string
	local lines = {}
	for i, inst in PoiTour.all() do
		local cf = bounds(inst)
		local p = cf.Position
		table.insert(lines, string.format("%3d  %-26s %-11s %-6s (%d, %d, %d)  %s", i, nameOf(inst), tostring(inst:GetAttribute("Kind")), tostring(inst:GetAttribute("Zone")), p.X, p.Y, p.Z, inst:GetFullName()))
	end
	local text = table.concat(lines, "\n")
	print(text)
	return text
end

local function find(arg): Instance?
	local list = PoiTour.all()
	if type(arg) == "number" then
		return list[arg]
	end
	local key = string.lower(tostring(arg))
	for _, inst in list do
		if string.lower(nameOf(inst)) == key or string.lower(inst.Name) == key then
			return inst
		end
	end
	for _, inst in list do
		if string.find(string.lower(nameOf(inst)), key, 1, true) then
			return inst
		end
	end
	return nil
end

-- Select the POI and put the camera where a player would stand looking at it.
function PoiTour.go(arg): string
	local inst = find(arg)
	if not inst then
		return "no POI matches " .. tostring(arg)
	end
	local cf, size = bounds(inst)
	local center = cf.Position
	local reach = math.clamp(math.max(size.X, size.Z) * 0.6 + 12, 14, 90)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { inst, workspace:FindFirstChild("_EditorMarkers") }
	params.RespectCanCollide = true
	local front = if inst:IsA("Model") then inst:GetPivot().LookVector else Vector3.new(0, 0, 1)
	local base = math.atan2(front.Z, front.X)
	local best: CFrame? = nil
	for k = 0, 15 do
		local a = base + (if k % 2 == 0 then 1 else -1) * math.ceil(k / 2) * math.pi / 8
		local at = center + Vector3.new(math.cos(a) * reach, 0, math.sin(a) * reach)
		local ground = workspace:Raycast(at + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
		if ground then
			local eye = ground.Position + Vector3.new(0, 5, 0)
			local look = Vector3.new(center.X, math.max(center.Y, eye.Y - reach * 0.25), center.Z)
			if not workspace:Raycast(eye, look - eye, params) then
				best = CFrame.lookAt(eye, look)
				break
			end
			best = best or CFrame.lookAt(eye, look)
		end
	end
	local camera = workspace.CurrentCamera
	camera.CFrame = best or CFrame.lookAt(center + Vector3.new(0, 20, reach), center)
	camera.Focus = CFrame.new(center)
	Selection:Set({ inst })
	return string.format("%s (%s, %s) at (%d, %d, %d)", nameOf(inst), tostring(inst:GetAttribute("Kind")), tostring(inst:GetAttribute("Zone")), center.X, center.Y, center.Z)
end

-- Label look per kind: how far away it still shows (studs) and its size, so finds don't pile up
-- over the landmarks in a wide view.
local KIND_LABEL = {
	Find = { 250, 170, 30 },
	Cache = { 300, 200, 36 },
	QiNode = { 300, 190, 34 },
	Lair = { 350, 200, 36 },
	Later = { 350, 200, 34 },
	Array = { 450, 220, 40 },
	WeaponRack = { 300, 200, 36 },
	Landmark = { 500, 240, 44 },
	BossRing = { 550, 250, 46 },
	EventGround = { 650, 250, 46 },
}
local HANDPASS_COLOR = Color3.fromRGB(255, 150, 60)

local function makeLabel(folder, name, pos, title, subtitle, color, look)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = pos
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(look[2], look[3])
	gui.AlwaysOnTop = true
	gui.MaxDistance = look[1]
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.6)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = title
	t.Parent = gui
	local sub = t:Clone()
	sub.Font = Enum.Font.Gotham
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Text = subtitle
	sub.Parent = gui
	gui.Parent = anchor
	anchor.Parent = folder
	return anchor
end

-- Keep labels from stacking: a label within 24 studs (flat) and 7 (height) of one already
-- placed rises by 7 until it is clear.
local function declutter(placed, pos)
	local p = pos
	for _ = 1, 12 do
		local clash = false
		for _, q in placed do
			if (Vector2.new(p.X, p.Z) - Vector2.new(q.X, q.Z)).Magnitude < 24 and math.abs(p.Y - q.Y) < 7 then
				clash = true
				break
			end
		end
		if not clash then
			break
		end
		p += Vector3.new(0, 7, 0)
	end
	table.insert(placed, p)
	return p
end

function PoiTour.handpassList(): { Instance }
	local list = {}
	for _, inst in CollectionService:GetTagged("NeedsHandPass") do
		if inst:IsDescendantOf(workspace) and inst:GetAttribute("HandPassStatus") ~= "done" then
			table.insert(list, inst)
		end
	end
	table.sort(list, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

-- Builds flagged for a hand pass (tag NeedsHandPass, attributes HandPassReason and
-- HandPassStatus "open"/"done"): T.handpass() lists them, T.handpass(3) frames the third.
function PoiTour.handpass(arg): string
	local list = PoiTour.handpassList()
	if arg == nil then
		local lines = {}
		for i, inst in list do
			local cf = bounds(inst)
			table.insert(lines, string.format("%3d  %-28s (%d, %d, %d)  %s  [%s]", i, nameOf(inst), cf.X, cf.Y, cf.Z, tostring(inst:GetAttribute("HandPassReason")), tostring(inst:GetAttribute("HandPassStatus"))))
		end
		local text = table.concat(lines, "\n")
		print(text)
		return text
	end
	local inst = list[arg]
	if not inst then
		return "no hand-pass item " .. tostring(arg)
	end
	local cf, size = bounds(inst)
	local reach = math.clamp(math.max(size.X, size.Z) * 0.8 + 14, 18, 110)
	local eye = cf.Position + Vector3.new(reach * 0.7, math.max(6, size.Y * 0.4), reach * 0.7)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, cf.Position)
	workspace.CurrentCamera.Focus = CFrame.new(cf.Position)
	Selection:Set({ inst })
	return nameOf(inst) .. ": " .. tostring(inst:GetAttribute("HandPassReason"))
end

-- Rebuild one floating label per POI under Workspace._EditorMarkers.POILabels, and an orange
-- "⚑" label per open hand-pass item under Workspace._EditorMarkers.HandPassLabels.
function PoiTour.labels(): string
	local markers = workspace:FindFirstChild("_EditorMarkers")
	if not markers then
		markers = Instance.new("Folder")
		markers.Name = "_EditorMarkers"
		markers.Parent = workspace
	end
	for _, n in { "POILabels", "HandPassLabels" } do
		local old = markers:FindFirstChild(n)
		if old then
			old:Destroy()
		end
	end
	local placed = {}
	local hp = Instance.new("Folder")
	hp.Name = "HandPassLabels"
	for i, inst in PoiTour.handpassList() do
		local cf, size = bounds(inst)
		local pos = declutter(placed, cf.Position + Vector3.new(0, math.min(size.Y / 2, 40) + 9, 0))
		makeLabel(hp, nameOf(inst), pos, "\u{2691} " .. nameOf(inst), tostring(inst:GetAttribute("HandPassReason") or "check by hand"), HANDPASS_COLOR, { 500, 300, 46 })
	end
	local folder = Instance.new("Folder")
	folder.Name = "POILabels"
	local list = PoiTour.all()
	local order = {}
	for i, inst in list do
		table.insert(order, { i, inst })
	end
	-- big things claim their spot first, finds step aside
	table.sort(order, function(a, b)
		local la = KIND_LABEL[tostring(a[2]:GetAttribute("Kind"))] or KIND_LABEL.Landmark
		local lb = KIND_LABEL[tostring(b[2]:GetAttribute("Kind"))] or KIND_LABEL.Landmark
		return la[1] > lb[1]
	end)
	for _, e in order do
		local i, inst = e[1], e[2]
		local cf, size = bounds(inst)
		local kind = tostring(inst:GetAttribute("Kind"))
		local look = KIND_LABEL[kind] or KIND_LABEL.Landmark
		local pos = declutter(placed, cf.Position + Vector3.new(0, math.min(size.Y / 2, 30) + 4, 0))
		local note = inst:GetAttribute("LabelNote")
		local anchor = makeLabel(folder, nameOf(inst), pos, string.format("#%d %s", i, nameOf(inst)), kind .. " · " .. tostring(inst:GetAttribute("Zone")) .. (if note then " · " .. tostring(note) else ""), KIND_COLOR[kind] or Color3.new(1, 1, 1), look)
		local target = Instance.new("ObjectValue")
		target.Name = "Target"
		target.Value = inst
		target.Parent = anchor
	end
	folder.Parent = markers
	hp.Parent = markers
	return #folder:GetChildren() .. " labels, " .. #hp:GetChildren() .. " hand-pass flags"
end

setmetatable(PoiTour, {
	__call = function(_, arg)
		if arg == nil then
			return PoiTour.list()
		end
		return PoiTour.go(arg)
	end,
})

return PoiTour
