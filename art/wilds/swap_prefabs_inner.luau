--!nocheck
-- Swaps placed Inner Wilds pocket and find copies for their updated prefabs
-- (ServerStorage.InnerWildsPrefabs), keeping each copy's exact pivot (position, rotation, ground fit).
-- Run in Studio Edit mode through execute_luau, then ambience_inner.luau (it re-dresses the new
-- copies' FX_ and SND_ anchors) and PoiTour.labels().
--
-- For every placed copy under Map.Ground.WildsInner.Pockets/Finds whose structure differs from its
-- prefab (parts' names, offsets from the pivot, sizes, colours; FX clones under anchors ignored):
-- clone the prefab, pivot it where the old copy is, redo the placement fix-ups (children reseated
-- for ReseatChildren prefabs and the snare line, the Lotus shore discs under the water, TerrainCarve
-- digs), copy the old copy's tags and attributes (POI, NeedsHandPass, HandPassReason/Status,
-- BlockedBy), re-seat its cache onto the new CacheSpotAnchor, and move the old copy to
-- ServerStorage._InnerWildsReplaced. Only the given names when _G.SWAP_ONLY = { ... } is set.
-- Then every POI model gets a POIAnchor part (see ensureAnchor) so ungrouping it keeps the tour.

local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local function waterPart(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Water" or game:GetService("CollectionService"):HasTag(d, "StylizedWater")) then
			return d
		end
	end
	return nil
end
local PREFABS = SS.InnerWildsPrefabs
local ground = workspace.Map.Ground.WildsInner
local rep = SS:FindFirstChild("_InnerWildsReplaced")

local terrParams = RaycastParams.new()
terrParams.FilterType = Enum.RaycastFilterType.Include
terrParams.FilterDescendantsInstances = { workspace.Terrain }
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), terrParams)
	return h and h.Position.Y or 4
end

-- rounded to 0.2 studs, with -0 folded into 0 (else every rotated copy "differs")
local function r(v)
	local x = math.floor(v * 5 + 0.5) / 5
	if x == 0 then
		x = 0
	end
	return x
end
local function sig(m)
	local piv = m:GetPivot()
	local items = {}
	for _, d in m:GetDescendants() do
		local skip = false
		local a = d.Parent
		while a and a ~= m do
			if a:IsA("BasePart") and a.Name:sub(-6) == "Anchor" then
				skip = true
				break
			end
			a = a.Parent
		end
		if not skip and d.Name ~= "POIAnchor" and (d:IsA("BasePart") or d:IsA("Model") or d:IsA("Attachment") or d:IsA("Decal") or d:IsA("ProximityPrompt") or d:IsA("Light")) then
			local s = d.ClassName .. ":" .. d.Name
			if d:IsA("BasePart") then
				local rel = piv:ToObjectSpace(d.CFrame)
				s ..= string.format(" %g,%g,%g %g,%g,%g %s", r(rel.X), r(rel.Y), r(rel.Z), r(d.Size.X), r(d.Size.Y), r(d.Size.Z), d.Color:ToHex())
			end
			table.insert(items, s)
		end
	end
	table.sort(items)
	return table.concat(items, "|")
end

local CACHE_FOR = {
	WolfDen = "Cache_DragonPierce",
	BambooHollow = "Cache_CrescentSweep",
	HuntersCamp = "Cache_RampagingTiger",
	ShrineTerrace = "Cache_HeavenSplitter",
}

local function fixups(m, src)
	if src:GetAttribute("ReseatChildren") or m.Name == "F12_SnareLine" then
		for _, c in m:GetChildren() do
			if c:IsA("Model") or (c:IsA("BasePart") and m.Name == "F12_SnareLine") then
				local cf, size
				if c:IsA("Model") then
					cf, size = c:GetBoundingBox()
				else
					cf, size = c.CFrame, c.Size
				end
				local sink = if m.Name == "F12_SnareLine" then 0 else size.Y * 0.12
				local delta = Vector3.new(0, (gy(cf.X, cf.Z) - sink) - (cf.Y - size.Y / 2), 0)
				if c:IsA("Model") then
					c:PivotTo(c:GetPivot() + delta)
				else
					c.CFrame += delta
				end
			end
		end
	end
	if m.Name == "LotusMere" then
		local w = waterPart(m)
		local top = w and (w.Position.Y + math.min(w.Size.X, w.Size.Y, w.Size.Z) / 2) or 0
		for _, c in m:GetDescendants() do
			if c:IsA("BasePart") and c.Name == "Shore" then
				local sTop = c.Position.Y + c.Size.X / 2
				if sTop > top - 0.6 then
					c.CFrame -= Vector3.new(0, sTop - (top - 0.6), 0)
				end
			end
		end
	end
	for _, c in m:GetDescendants() do
		if c:IsA("BasePart") and c.Name == "TerrainCarve" then
			local r = math.max(c.Size.Y, c.Size.Z) / 2
			local bottom = c.Position.Y - c.Size.X / 2
			workspace.Terrain:FillCylinder(CFrame.new(c.Position.X, bottom + 12, c.Position.Z), 24, r, Enum.Material.Air)
		end
	end
end

local KEEP_ATTRS = { "HandPassReason", "HandPassStatus", "BlockedBy", "PoiName", "Kind", "Zone", "LabelNote" }

-- an invisible part inside each POI model carrying the POI's tags and attributes, so the POI tour,
-- labels and hand-pass list still find it if the user ungroups the model (Ctrl+U drops the Model's
-- own tags and attributes and leaves its children loose)
local function ensureAnchor(m)
	local a = m:FindFirstChild("POIAnchor")
	if not a then
		a = Instance.new("Part")
		a.Name = "POIAnchor"
		a.Size = Vector3.new(1, 1, 1)
		a.Transparency = 1
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.CastShadow = false
		a.Parent = m
	end
	-- at the model's pivot, unless that pivot lies off the model (some built POIs keep a far pivot):
	-- then at the bottom centre of its box, and the model pivots there too
	a.Parent = nil
	local cf, size = m:GetBoundingBox()
	a.Parent = m
	local lp = cf:PointToObjectSpace(m:GetPivot().Position)
	if math.abs(lp.X) > size.X / 2 + 5 or math.abs(lp.Z) > size.Z / 2 + 5 then
		m.WorldPivot = CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z)
	end
	a.CFrame = m:GetPivot()
	CollectionService:AddTag(a, "POIAnchor")
	for _, k in KEEP_ATTRS do
		a:SetAttribute(k, m:GetAttribute(k))
	end
	a:SetAttribute("PoiModel", m.Name)
	if CollectionService:HasTag(m, "NeedsHandPass") then
		CollectionService:AddTag(a, "NeedsHandPass")
	else
		CollectionService:RemoveTag(a, "NeedsHandPass")
	end
	return a
end

local only = _G.SWAP_ONLY
_G.SWAP_ONLY = nil
local dry = _G.SWAP_DRY -- list what differs, change nothing
_G.SWAP_DRY = nil
local onlySet = only and {} or nil
for _, n in only or {} do
	onlySet[n] = true
end

local report = {}
for _, folderName in { "Pockets", "Finds" } do
	local folder = ground:FindFirstChild(folderName)
	for _, old in (folder and folder:GetChildren() or {}) do
		if not old:IsA("Model") then
			continue
		end
		local src = PREFABS:FindFirstChild(old.Name)
		if src and (not onlySet or onlySet[old.Name]) and sig(old) ~= sig(src) then
			if dry then
				table.insert(report, old.Name)
				continue
			end
			local new = src:Clone()
			new:PivotTo(old:GetPivot())
			fixups(new, src)
			for _, tag in CollectionService:GetTags(old) do
				CollectionService:AddTag(new, tag)
			end
			for _, k in KEEP_ATTRS do
				if old:GetAttribute(k) ~= nil then
					new:SetAttribute(k, old:GetAttribute(k))
				end
			end
			new.Parent = folder
			local cacheName = CACHE_FOR[old.Name]
			local spot = new:FindFirstChild("CacheSpotAnchor", true)
			if cacheName and spot then
				local cache = workspace.Map.Markers.ManualCaches:FindFirstChild(cacheName)
				if cache then
					local f = cache.Footing
					local base = math.max(gy(spot.Position.X, spot.Position.Z), spot.Position.Y - spot.Size.Y / 2)
					cache:PivotTo(cache:GetPivot() + Vector3.new(spot.Position.X - f.Position.X, (base - 0.3) - (f.Position.Y - f.Size.Y / 2), spot.Position.Z - f.Position.Z))
				end
			end
			old:SetAttribute("FromPath", old:GetFullName())
			for _, tag in { "POI", "NeedsHandPass" } do
				CollectionService:RemoveTag(old, tag)
			end
			old.Parent = rep
			table.insert(report, old.Name)
		end
		task.wait()
	end
end

if dry then
	return "would swap " .. #report .. ": " .. table.concat(report, ", ")
end
-- POIAnchor parts in every POI model under the map
local anchors = 0
for _, m in CollectionService:GetTagged("POI") do
	if m:IsA("Model") and m:IsDescendantOf(workspace.Map) then
		ensureAnchor(m)
		anchors += 1
	end
end
return string.format("swapped %d: %s\nPOIAnchor parts: %d", #report, table.concat(report, ", "), anchors)
