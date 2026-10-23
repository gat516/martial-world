--!nocheck
-- Groups the loose parts of a POI model into named sub-Models by function, so the user can select,
-- move or ungroup sensible pieces (docs/map/inner-wilds-rework.md, "Prefab updates and ungrouping").
-- Run in Studio Edit mode through execute_luau. It installs _G.groupPoiParts(model) (used by
-- art/wilds/build_poi_prefabs.luau too) and, unless _G.GROUP_POI_INSTALL_ONLY is set, regroups every
-- placed pocket, find and water group, the prefabs in ServerStorage.InnerWildsPrefabs and the preview
-- copies in Workspace._PoiStaging. _G.GROUP_POI_DRY = true reports what would move and changes nothing.
--
-- Only the hierarchy changes: parts stay at their world positions, tags and attributes stay on the
-- parts (POIAnchor, CacheSpotAnchor, AmbientSound anchors, FX anchors), lamp models keep their names
-- (StoneLantern/Lantern/JadeLamp, which DayNight finds by name) and each moves whole into Lanterns.
-- Each group is a Model pivoted at its bottom centre with identity rotation. The POIAnchor and any
-- existing group stays at the top level. Attachments, decals and other non-parts at the top are left.

local CollectionService = game:GetService("CollectionService")

-- group name, then name patterns (Lua patterns, matched against the child's name)
local RULES = {
	{ "Sound", { "^SND_" } },
	{ "FX", { "^FX_" } },
	{ "Markers", { "Anchor$" } },
	{ "PoolRim", { "^RimStone", "^RimFoam" } },
	{ "Water", { "^Water$", "^Bed$", "^Shore$", "^Mere$", "^Spring$", "^SpringPool$", "^WaterfallFoam", "^Churn$", "^FoamRings$", "^TerrainCarve$", "Fall", "Trickle" } },
	{ "Lanterns", { "^StoneLantern$", "^Lantern$", "^JadeLamp$", "^Brazier$", "^LampPost$", "^LampArm$", "^LanternHook$" } },
	{ "Stair", { "Stair", "^Steps?$", "^CutSteps$", "^Landing$", "^Ladder" } },
	{ "Roof", { "Roof", "^Eave", "^Gable$", "^Ridge", "^Awning", "^Dome" } },
	{ "Apron", { "^Paving$", "^Curb", "^Apron", "^Slab$", "^BankPad$", "^KneelingStone$", "^MatStone$" } },
	{ "Structure", { "Wall$", "^Post$", "^CornerPost$", "^Column$", "^Beam$", "^Lintel$", "^Door", "^Platform", "^Plinth$", "^Terrace$", "^Deck$", "^Altar$", "^Counter", "^Abutment$", "^Footing$", "^Foot$", "^RailPost$", "^RopeRail$", "^Pavilion$", "^Hut$", "^Tent$", "^Lookout$", "^Jetty$", "^Boardwalk$", "^Well$", "^Stove", "^Vent$", "^Trestle$", "^Shrine$", "^FoxShrine$" } },
	{ "Foliage", { "Bamboo", "^Fern", "^Bush", "^Clover", "^Leaf", "^Culm", "^Shoot$", "^Moss$", "^Reeds$", "^Lotus$", "^LilyPad", "^Herb", "^Berry$", "Pine$", "Tree$", "^Stump$", "^Mushroom", "^ShelfFungus$", "^HangingRoot$", "^UprootedFern$", "^ScarredStump$" } },
	{ "Rocks", { "^Rock$", "^Stone$", "^Boulder$", "^Rubble$", "^Crag$", "^Outcrop$", "^BackRock$", "^Buttress$", "^GateRock", "^RingStone", "^FallRocks$" } },
}
local GROUPS = {}
for _, r in RULES do
	GROUPS[r[1]] = true
end
GROUPS.Props = true

local function groupFor(child)
	if child.Name == "POIAnchor" or GROUPS[child.Name] then
		return nil
	end
	if CollectionService:HasTag(child, "AmbientSound") then
		return "Sound"
	end
	for _, r in RULES do
		for _, pat in r[2] do
			if child.Name:find(pat) then
				return r[1]
			end
		end
	end
	return "Props"
end

local function bottomCentre(m)
	local cf, size = m:GetBoundingBox()
	return CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z)
end

-- Objects first: small pieces that touch or sit on a bigger object (moss on a stele, caps and
-- inscriptions, a lantern's glow, a tent's ropes and pegs, a cart's wheels and load, a log's limbs)
-- go inside that object's model, so they move with it. Hosts never absorb ground-like pieces
-- (terraces, platforms, decks, paving, water, beds); those only take the attachment-named bits.
local ATTACH = { "^Moss", "^Inscription", "^Cap$", "^Rope", "^Peg", "Glow$", "^Light", "^Wheel", "^LooseWheel$", "^Vine", "^Tuft", "^Lichen", "^Chip$", "^ClawMark$", "^RockScratch$", "^Talisman$", "^Rag$", "^Tether$", "^Snag$", "^ShelfFungus$", "^HangingRoot$", "^Splinter$", "^EaveTip$", "^RidgeEnd$", "^Ear$", "^Eye", "^Nose$", "^Brow$", "^Horn$", "^Tusk", "^Head$", "^Hilt$", "^Guard$", "^Pommel$", "^Blade$", "^Banner", "^Board$", "^Marker", "^Berry$", "^Herb" }
local GROUNDLIKE = { "^Terrace$", "^Platform", "^Plinth$", "^Deck$", "^Paving$", "^Slab$", "^Water$", "^Bed$", "^Shore$", "^Mere$", "^Spring", "^TerrainCarve$", "^Mud$", "^BankPad$", "^Apron" }
local LAMPS = { StoneLantern = true, Lantern = true, JadeLamp = true }
local function matches(name, list)
	for _, pat in list do
		if name:find(pat) then
			return true
		end
	end
	return false
end
local function boxOf(c)
	local cf, size
	if c:IsA("Model") then
		cf, size = c:GetBoundingBox()
	else
		cf, size = c.CFrame, c.Size
	end
	-- world AABB of the oriented box
	local r = cf - cf.Position
	local ext = Vector3.new(
		math.abs(r.XVector.X) * size.X + math.abs(r.YVector.X) * size.Y + math.abs(r.ZVector.X) * size.Z,
		math.abs(r.XVector.Y) * size.X + math.abs(r.YVector.Y) * size.Y + math.abs(r.ZVector.Y) * size.Z,
		math.abs(r.XVector.Z) * size.X + math.abs(r.YVector.Z) * size.Y + math.abs(r.ZVector.Z) * size.Z
	) / 2
	return cf.Position - ext, cf.Position + ext, size.X * size.Y * size.Z
end
local function touches(aMin, aMax, bMin, bMax, pad)
	return aMin.X <= bMax.X + pad and aMax.X >= bMin.X - pad and aMin.Y <= bMax.Y + pad and aMax.Y >= bMin.Y - pad and aMin.Z <= bMax.Z + pad and aMax.Z >= bMin.Z - pad
end
local function isMarker(c)
	return c.Name == "POIAnchor" or c.Name:find("^SND_") or c.Name:find("^FX_") or c.Name:find("Anchor$") or CollectionService:HasTag(c, "AmbientSound")
end

local function groupObjects(model, dry)
	local items = {}
	for _, c in model:GetChildren() do
		if (c:IsA("BasePart") or c:IsA("Model")) and not GROUPS[c.Name] and not isMarker(c) then
			local mn, mx, vol = boxOf(c)
			table.insert(items, { inst = c, mn = mn, mx = mx, vol = vol, attach = matches(c.Name, ATTACH), ground = matches(c.Name, GROUNDLIKE) })
		end
	end
	table.sort(items, function(a, b)
		return a.vol > b.vol
	end)
	local hostOf = {}
	local MOSSY = { "^Moss", "^Vine", "^Tuft", "^Lichen", "^ShelfFungus$", "^HangingRoot$" }
	local BUILT = { Roof = true, Structure = true, Stair = true }
	for _, it in items do
		it.group = groupFor(it.inst)
	end
	for i, it in items do
		if LAMPS[it.inst.Name] or it.ground then
			continue
		end
		-- plants stay their own objects (except moss, vines and fungus, which ride on what they grow on),
		-- and so do rim stones, rim foam and water pieces
		if it.group == "Foliage" and not matches(it.inst.Name, MOSSY) then
			continue
		end
		if it.group == "PoolRim" or it.group == "Water" then
			continue
		end
		local small = it.attach or (it.mx - it.mn).Magnitude < 7
		if not small then
			continue
		end
		for j = 1, i - 1 do
			local h = items[j]
			local ok = h.vol > it.vol * 3 and (not h.ground or it.attach)
				and not (LAMPS[h.inst.Name] and not it.inst.Name:find("Glow$") and not it.inst.Name:find("^Light"))
				and h.group ~= "Foliage" -- a canopy's box covers everything under it
				and (not BUILT[it.group] or BUILT[h.group]) -- roof and wall bits go with buildings only
				and touches(it.mn, it.mx, h.mn, h.mx, 0.5)
			if ok then
				hostOf[it] = h
				break
			end
		end
	end
	-- follow chains to the root host
	local function root(it)
		local seen = 0
		while hostOf[it] and seen < 20 do
			it = hostOf[it]
			seen += 1
		end
		return it
	end
	local children = {}
	for it, _ in hostOf do
		local r = root(it)
		children[r] = children[r] or {}
		table.insert(children[r], it.inst)
	end
	local examples = {}
	local n = 0
	for host, list in children do
		n += 1
		if #examples < 3 then
			local names = {}
			for k = 1, math.min(#list, 4) do
				table.insert(names, list[k].Name)
			end
			table.insert(examples, host.inst.Name .. " <- " .. table.concat(names, ", ") .. (#list > 4 and (" +" .. (#list - 4)) or ""))
		end
		if not dry then
			local h = host.inst
			local holder = h
			if h:IsA("BasePart") then
				holder = Instance.new("Model")
				holder.Name = h.Name
				holder.Parent = model
				h.Parent = holder
			end
			for _, c in list do
				c.Parent = holder
			end
			if holder ~= h then
				holder.WorldPivot = CFrame.new(holder:GetBoundingBox().Position)
			end
		end
	end
	return n, examples
end

-- returns { [group] = count } of what moved (or would move)
local function groupPoiParts(model, dry)
	local objects, examples = groupObjects(model, dry)
	local counts = {}
	local buckets = {}
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") or c:IsA("Model") then
			local g = groupFor(c)
			if g then
				counts[g] = (counts[g] or 0) + 1
				buckets[g] = buckets[g] or {}
				table.insert(buckets[g], c)
			end
		end
	end
	if dry then
		return counts, objects, examples
	end
	for g, list in buckets do
		local holder = model:FindFirstChild(g)
		if not (holder and holder:IsA("Model")) then
			holder = Instance.new("Model")
			holder.Name = g
			holder.Parent = model
		end
		for _, c in list do
			c.Parent = holder
		end
		holder.WorldPivot = bottomCentre(holder)
	end
	return counts, objects, examples
end
_G.groupPoiParts = groupPoiParts

-- Seat every object of a placed POI on what is under it (the user: "rotate stuff and have it touch
-- the ground or be rooted into it"). For each object model or part inside the function groups:
-- raycast at five points under its base (terrain and the POI's other solid pieces, never itself),
-- lower or raise it so its base meets the lowest support, then sink it a little (0.4 stud for
-- props on the ground, 8% of the height for rocks and steles, nothing when it stands on a part),
-- tilt it to the ground's slope (fully for flat stones, logs and crates, at most 8 degrees for
-- upright things, not at all for foliage and lamps), and give loose stones a small random yaw.
-- Structures, stairs, roofs and the water stay level: if one hovers over the terrain, the terrain
-- is filled up to its base instead.
local SEAT = {
	Rocks = { tilt = 1, sink = 0.08, yaw = true },
	PoolRim = { tilt = 1, sink = 0.15, yaw = true },
	Apron = { tilt = 1, sink = 0.1 },
	Props = { tilt = 0.6, sink = "small" },
	Foliage = { tilt = 0, sink = "small" },
	Lanterns = { tilt = 0.2, sink = "small" },
}
local LEVEL = { Structure = true, Stair = true, Roof = true }
local UPRIGHT = { "Stele", "Post", "Pillar", "Lantern", "Lamp", "Stick", "Pole", "Stake", "Statue", "Tree", "Pine", "Bamboo", "Well", "Spire" }
local FLAT = { "Stone", "Rock", "Log", "Crate", "Board", "Slab", "Plank", "Mat", "Sack", "Bench" }
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local function seatObjects(model, rng)
	local seated, filled = 0, 0
	local supportParams = RaycastParams.new()
	supportParams.FilterType = Enum.RaycastFilterType.Include
	supportParams.RespectCanCollide = true
	for gName, holder in model:GetChildren() do
		local rule = SEAT[holder.Name]
		local level = LEVEL[holder.Name]
		if not (holder:IsA("Model") and (rule or level)) then
			continue
		end
		for _, obj in holder:GetChildren() do
			if not (obj:IsA("Model") or obj:IsA("BasePart")) then
				continue
			end
			local cf, size
			if obj:IsA("Model") then
				cf, size = obj:GetBoundingBox()
			else
				cf, size = obj.CFrame, obj.Size
			end
			local bottom = cf.Y - size.Y / 2
			-- supports: terrain plus every solid part of the POI that isn't this object
			local include = { workspace.Terrain }
			for _, other in model:GetDescendants() do
				if other:IsA("BasePart") and other.CanCollide and not other:IsDescendantOf(obj) and other ~= obj then
					table.insert(include, other)
				end
			end
			supportParams.FilterDescendantsInstances = include
			local samples = {}
			local onPart = false
			for _, o in { { 0, 0 }, { 0.4, 0.4 }, { -0.4, 0.4 }, { 0.4, -0.4 }, { -0.4, -0.4 } } do
				local w = cf * Vector3.new(size.X * o[1], 0, size.Z * o[2])
				local h = workspace:Raycast(Vector3.new(w.X, bottom + 3, w.Z), Vector3.new(0, -40, 0), supportParams)
				if h then
					table.insert(samples, h.Position)
					if h.Instance ~= workspace.Terrain then
						onPart = true
					end
				end
			end
			if #samples < 3 then
				continue
			end
			local lo = math.huge
			for _, p in samples do
				lo = math.min(lo, p.Y)
			end
			if level then
				-- keep it level; fill the ground up under it where it hovers
				local tg = workspace:Raycast(Vector3.new(cf.X, bottom + 3, cf.Z), Vector3.new(0, -40, 0), terrainOnly)
				if not onPart and tg and bottom - lo > 0.5 then
					workspace.Terrain:FillBlock(CFrame.new(cf.X, (bottom + lo) / 2 - 1, cf.Z), Vector3.new(size.X * 0.9, bottom - lo + 2, size.Z * 0.9), Enum.Material.Ground)
					filled += 1
				end
				continue
			end
			-- ground normal from the corner samples
			local n = Vector3.yAxis
			if #samples >= 5 then
				local a = samples[2] - samples[5]
				local b = samples[3] - samples[4]
				local c = a:Cross(b)
				if c.Magnitude > 0.01 then
					n = c.Unit
					if n.Y < 0 then
						n = -n
					end
				end
			end
			local tiltAmt = rule.tilt
			if matches(obj.Name, UPRIGHT) then
				tiltAmt = math.min(tiltAmt, 0.15)
			elseif matches(obj.Name, FLAT) then
				tiltAmt = math.max(tiltAmt, 0.9)
			end
			local up = Vector3.yAxis:Lerp(n, tiltAmt).Unit
			local angle = math.acos(math.clamp(up.Y, -1, 1))
			if matches(obj.Name, UPRIGHT) then
				angle = math.min(angle, math.rad(8))
			end
			local axis = Vector3.yAxis:Cross(up)
			local pivot = obj:IsA("Model") and obj:GetPivot() or obj.CFrame
			local base = Vector3.new(cf.X, bottom, cf.Z)
			local rot = CFrame.identity
			if axis.Magnitude > 0.001 and angle > 0.001 then
				rot = CFrame.fromAxisAngle(axis.Unit, angle)
			end
			if rule.yaw and rng then
				rot = rot * CFrame.Angles(0, rng:NextNumber(-0.26, 0.26), 0)
			end
			-- rotate about the base centre, then drop/raise so the base meets the lowest support
			local about = CFrame.new(base)
			local newPivot = about * rot * about:Inverse() * pivot
			local sink
			if onPart then
				sink = 0.05
			elseif rule.sink == "small" then
				sink = 0.4
			else
				sink = size.Y * rule.sink
			end
			if obj:IsA("Model") then
				obj:PivotTo(newPivot)
				local c2, s2 = obj:GetBoundingBox()
				obj:PivotTo(obj:GetPivot() + Vector3.new(0, (lo - sink) - (c2.Y - s2.Y / 2), 0))
			else
				obj.CFrame = newPivot
				local s2 = obj.Size
				local ext = math.abs(obj.CFrame.XVector.Y) * s2.X + math.abs(obj.CFrame.YVector.Y) * s2.Y + math.abs(obj.CFrame.ZVector.Y) * s2.Z
				obj.CFrame += Vector3.new(0, (lo - sink) - (obj.Position.Y - ext / 2), 0)
			end
			seated += 1
		end
	end
	return seated, filled
end
_G.seatPoiObjects = seatObjects

if _G.GROUP_POI_INSTALL_ONLY then
	_G.GROUP_POI_INSTALL_ONLY = nil
	return "installed _G.groupPoiParts"
end
local dry = _G.GROUP_POI_DRY
_G.GROUP_POI_DRY = nil

local targets = {}
local WI = workspace.Map.Ground.WildsInner
for _, n in { "Pockets", "Finds", "Water" } do
	local f = WI:FindFirstChild(n)
	for _, m in (f and f:GetChildren() or {}) do
		if m:IsA("Model") and (n == "Water" or m:GetAttribute("PoiName") or m:FindFirstChild("POIAnchor")) then
			table.insert(targets, m)
		end
	end
end
local P = game:GetService("ServerStorage"):FindFirstChild("InnerWildsPrefabs")
for _, m in (P and P:GetChildren() or {}) do
	if m:IsA("Model") then
		table.insert(targets, m)
	end
end
local stage = workspace:FindFirstChild("_PoiStaging")
for _, holder in (stage and stage:GetChildren() or {}) do
	for _, m in holder:GetChildren() do
		if m:IsA("Model") and P and P:FindFirstChild(m.Name) then
			table.insert(targets, m)
		end
	end
end

local lines = {}
local loose = 0
local seatRng = Random.new(91)
local seatedTotal, filledTotal = 0, 0
for _, m in targets do
	local counts, objects, examples = groupPoiParts(m, dry)
	if not dry and m:IsDescendantOf(workspace.Map) and not _G.GROUP_POI_NO_SEAT then
		local sN, fN = seatObjects(m, seatRng)
		seatedTotal += sN
		filledTotal += fN
	end
	local parts = {}
	for g, n in counts do
		table.insert(parts, g .. " " .. n)
	end
	table.sort(parts)
	-- what is left loose at the top (besides the groups and the POIAnchor)
	if not dry then
		for _, c in m:GetChildren() do
			if (c:IsA("BasePart") or c:IsA("Model")) and not GROUPS[c.Name] and c.Name ~= "POIAnchor" then
				loose += 1
			end
		end
	end
	table.insert(lines, m:GetFullName():gsub("^Workspace%.Map%.Ground%.WildsInner%.", ""):gsub("^ServerStorage%.", "") .. ": " .. objects .. " objects; " .. table.concat(parts, ", ") .. (#examples > 0 and ("  e.g. " .. table.concat(examples, " / ")) or ""))
end
table.sort(lines)
_G.GROUP_POI_NO_SEAT = nil
return string.format("%s %d models, loose left at top: %d; seated %d objects, filled ground under %d level pieces\n%s", dry and "DRY RUN" or "grouped", #targets, loose, seatedTotal, filledTotal, table.concat(lines, "\n"))
