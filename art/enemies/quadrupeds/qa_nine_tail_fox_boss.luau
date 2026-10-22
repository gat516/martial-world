--!nocheck
-- Numeric QA for NineTailFoxB's tails. Run in Edit mode through execute_luau (art server on
-- :8767) after build + rig. Pure maths on the template (nothing is cloned or moved): each pose
-- is forward-kinematics through the Motor6Ds, every tail part follows its segment, and per pose
-- it reports, worst over the nine tails:
--   reach  farthest lance end (TailTip<i>_FX) from the tail root, final studs (rest ~8.9, full ~21.6)
--   gap    worst along-axis gap between consecutive segments' coverage (0 = always overlapping)
--   rim    worst distance a sliding piece's back end (neck core, lance) sits OUTSIDE every
--          other part of its tail, i.e. a sleeve end you could see (0 = always buried)
--   hide   at e <= 0.05 only: worst distance any piece that should be hidden at rest (neck and its
--          tufts, stem tuft, lance, tip spindle) pokes out of the stem / brush
--   body   tail parts whose boxes overlap the body (legs, chest, neck, head; hub and hips excluded)
--   floor  lowest point of any tail part (< 0 sinks into the ground)
-- Transform per motor = rotation * CFrame.new(ExtendAxis * ExtendMax * e) (rotation LAST, so the
-- hinge stays at the parent's mouth at every extension), as in RIGS.md and the pose module.
local template = game:GetService("ServerStorage")._RosterQuadrupeds.NineTailFoxB

local function tailT(i)
	return (i - 5) / 4
end
-- the pose module's default S curve (shp, curl 0.6) shrinking with extension; k scales it
local function curl(i, e, k)
	local t, lim, c = tailT(i), 1 - 0.45 * e, 0.6 * (k or 1)
	return CFrame.Angles(-0.07 * c * lim, 0, 0.05 * c * t * lim), CFrame.Angles(0.09 * c * lim, 0, -0.06 * c * t * lim),
		CFrame.Angles(-0.2 * c * lim, 0, 0.1 * c * t * lim)
end
local function curled(e, base, k)
	return function(i)
		local a, b, c = curl(i, e, k)
		return { ext = e, base = base and base(i) or nil, mid = a, tip = b, whip = c }
	end
end
local fanOut = function(i) return CFrame.Angles(0, 0, -tailT(i) * 0.55) end
local POSES = {
	{ "rest", curled(0) },
	{ "rest e.25", curled(0.25) },
	{ "rest e.5", curled(0.5) },
	{ "rest e.75", curled(0.75) },
	{ "rest e1", curled(1) },
	{ "straight e1", function() return { ext = 1 } end },
	{ "curl1.5 rest", curled(0, nil, 1.5) },
	{ "fan rest", curled(0, fanOut) },
	{ "fan e1", curled(1, fanOut) },
	{ "narrow e1", curled(1, function(i) return CFrame.Angles(0, 0, tailT(i) * 0.4) end) },
	{ "swept rest", curled(0, function() return CFrame.Angles(0.5, 0, 0) end) },
	{ "swept e1", curled(1, function() return CFrame.Angles(0.5, 0, 0) end) },
	{ "raised e1", curled(1, function() return CFrame.Angles(-0.25, 0, 0) end) },
	{ "plunge1.0 e1", function(i)
		return if i % 2 == 1 then { ext = 1, base = CFrame.Angles(1.0, 0, 0) } else { ext = 0 }
	end },
	{ "plungeFan e1", function(i)
		return if i % 2 == 1 then { ext = 1, base = CFrame.Angles(1.15, 0, 0) * CFrame.Angles(0, 0, -tailT(i) * 0.9) } else { ext = 0 }
	end },
	{ "bend e.5", function(i)
		return { ext = 0.5, mid = CFrame.Angles(0.1, 0, 0.1), tip = CFrame.Angles(-0.12, 0, -0.12), whip = CFrame.Angles(0.2, 0, 0.2) }
	end },
	{ "bend e1", function(i)
		return { ext = 1, mid = CFrame.Angles(0.1, 0, 0.1), tip = CFrame.Angles(-0.1, 0, -0.1), whip = CFrame.Angles(0.22, 0, 0.22) }
	end },
	{ "bendBig e1", function(i)
		return { ext = 1, mid = CFrame.Angles(0.3, 0, 0.3), tip = CFrame.Angles(-0.3, 0, -0.3), whip = CFrame.Angles(0.5, 0, 0.5) }
	end },
}
if _G.FoxQAPoses then -- optional extra poses: { { name, fn(i) -> spec }, ... }
	for _, p in _G.FoxQAPoses do
		table.insert(POSES, p)
	end
end

-- template data ------------------------------------------------------------------------
local motors, parts = {}, {}
for _, d in template:GetDescendants() do
	if d:IsA("Motor6D") then
		table.insert(motors, d)
	elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
		table.insert(parts, d)
	end
end
local segOf = {} -- part -> segment part
local byName = {}
for _, p in parts do
	byName[p.Name] = p
end
for _, p in parts do
	segOf[p] = byName[p:GetAttribute("Segment") or p.Name]
end
local tailOf = {} -- part -> tail index (nil for body and hub)
for _, p in parts do
	local i = segOf[p].Name:match("^Tail(%d)")
	tailOf[p] = i and tonumber(i)
end
local rel = {}
for _, p in parts do
	rel[p] = segOf[p].CFrame:Inverse() * p.CFrame
end
local root = template.HumanoidRootPart

-- geometry helpers ---------------------------------------------------------------------
local function vertices(p, cf)
	local s = p.Size / 2
	local out = {}
	if p:IsA("WedgePart") then
		for _, x in { -1, 1 } do
			table.insert(out, cf * Vector3.new(x * s.X, -s.Y, -s.Z))
			table.insert(out, cf * Vector3.new(x * s.X, -s.Y, s.Z))
			table.insert(out, cf * Vector3.new(x * s.X, s.Y, s.Z))
		end
	else
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(out, cf * Vector3.new(x * s.X, y * s.Y, z * s.Z))
				end
			end
		end
	end
	return out
end
-- points on the part's edges: vertices plus edge midpoints and quarter points
local function edgePoints(p, cf)
	local v = vertices(p, cf)
	local out = table.clone(v)
	for a = 1, #v do
		for b = a + 1, #v do
			for _, f in { 0.25, 0.5, 0.75 } do
				table.insert(out, v[a]:Lerp(v[b], f))
			end
		end
	end
	return out
end
-- how far point w lies outside part p posed at cf (<= 0 inside)
local function outside(p, cf, w)
	local l = cf:PointToObjectSpace(w)
	local s = p.Size / 2
	if p:IsA("Part") and p.Shape == Enum.PartType.Ball then
		return l.Magnitude - s.X
	end
	local ex = Vector3.new(math.max(math.abs(l.X) - s.X, 0), math.max(math.abs(l.Y) - s.Y, 0), math.max(math.abs(l.Z) - s.Z, 0))
	local d = ex.Magnitude
	if d == 0 then
		d = math.max(math.abs(l.X) - s.X, math.abs(l.Y) - s.Y, math.abs(l.Z) - s.Z)
	end
	if p:IsA("WedgePart") then
		-- inside needs (y + h/2) / h <= (z + l/2) / l: distance to the slope plane
		local h, L = p.Size.Y, p.Size.Z
		local slope = ((l.Y + s.Y) / h - (l.Z + s.Z) / L) * (h * L / math.sqrt(h * h + L * L))
		d = math.max(d, slope)
	end
	return d
end
-- oriented-box overlap (separating axis), boxes shrunk by `pad`
local function boxesOverlap(a, ca, b, cb, pad)
	local ea, eb = a.Size / 2 - Vector3.one * pad, b.Size / 2 - Vector3.one * pad
	local axA = { ca.RightVector, ca.UpVector, ca.LookVector }
	local axB = { cb.RightVector, cb.UpVector, cb.LookVector }
	local d = cb.Position - ca.Position
	local axes = {}
	for _, x in axA do table.insert(axes, x) end
	for _, x in axB do table.insert(axes, x) end
	for _, x in axA do
		for _, y in axB do
			local c = x:Cross(y)
			if c.Magnitude > 1e-4 then table.insert(axes, c.Unit) end
		end
	end
	for _, ax in axes do
		local ra = math.abs(axA[1]:Dot(ax)) * ea.X + math.abs(axA[2]:Dot(ax)) * ea.Y + math.abs(axA[3]:Dot(ax)) * ea.Z
		local rb = math.abs(axB[1]:Dot(ax)) * eb.X + math.abs(axB[2]:Dot(ax)) * eb.Y + math.abs(axB[3]:Dot(ax)) * eb.Z
		if math.abs(d:Dot(ax)) > ra + rb then
			return false
		end
	end
	return true
end

local RIM = { Mid = true, Whip = true } -- sliding pieces whose back end must stay buried (the tip spindle's back is a tapered edge, meant to show)
local HIDDEN = { Mid = true, MidFurA = true, MidFurB = true, FurA = true, Whip = true, WhipFurA = true, WhipFurB = true }
local function suffix(p)
	return p.Name:match("^Tail%d(%a*)$")
end

local function run(name, fn)
	local spec = {}
	for i = 1, 9 do
		spec[i] = fn(i)
	end
	local maxE = 0
	for i = 1, 9 do
		maxE = math.max(maxE, spec[i].ext or 0)
	end
	local function transformFor(m)
		local i, kind = m.Name:match("^JointTail(%d)(%a*)$")
		if not i then
			return CFrame.identity
		end
		local s = spec[tonumber(i)]
		if kind == "" then
			return s.base or CFrame.identity
		end
		local rot = (kind == "Mid" and s.mid) or (kind == "Tip" and s.tip) or (kind == "Whip" and s.whip) or CFrame.identity
		return rot * CFrame.new(m:GetAttribute("ExtendAxis") * m:GetAttribute("ExtendMax") * (s.ext or 0))
	end
	local world = { [root] = root.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * transformFor(m) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree broken")
	end
	local cf = {}
	for _, p in parts do
		cf[p] = world[segOf[p]] * rel[p]
	end
	local byTail = {}
	for _, p in parts do
		local i = tailOf[p]
		if i then
			byTail[i] = byTail[i] or {}
			table.insert(byTail[i], p)
		end
	end
	local hub = byName.Tail

	local reach, gap, gapAt, rim, rimAt, hide, hideAt, floorY = 0, 0, "", 0, "", 0, "", math.huge
	for i = 1, 9 do
		local list = byTail[i]
		local att = byName["Tail" .. i .. "Whip"]:FindFirstChild("TailTip" .. i .. "_FX")
		local tipW = cf[byName["Tail" .. i .. "Whip"]] * att.CFrame.Position
		local rootW = cf[byName["Tail" .. i]] * byName["Tail" .. i]:FindFirstChild("TailBase" .. i .. "_FX").CFrame.Position
		reach = math.max(reach, (tipW - rootW).Magnitude)
		-- coverage gaps along the axis between consecutive segments
		local segs = { "Tail" .. i, "Tail" .. i .. "Mid", "Tail" .. i .. "Tip", "Tail" .. i .. "Whip" }
		local function extent(segName, axisCf)
			local lo, hi = math.huge, -math.huge
			for _, p in list do
				if segOf[p].Name == segName then
					for _, v in vertices(p, cf[p]) do
						local z = -axisCf:PointToObjectSpace(v).Z
						lo, hi = math.min(lo, z), math.max(hi, z)
					end
				end
			end
			return lo, hi
		end
		for k = 1, 3 do
			local axisCf = cf[byName[segs[k]]]
			local _, hiA = extent(segs[k], axisCf)
			local loB = extent(segs[k + 1], axisCf)
			local g = loB - hiA
			if g > gap then
				gap, gapAt = g, segs[k + 1]
			end
		end
		-- probes
		for _, p in list do
			local suf = suffix(p)
			local probes
			if RIM[suf] then
				-- the back-end vertices: those nearest the root along the tail axis
				local vs = vertices(p, cf[p])
				local axisCf = cf[byName["Tail" .. i]]
				local lo = math.huge
				for _, v in vs do
					lo = math.min(lo, -axisCf:PointToObjectSpace(v).Z)
				end
				probes = {}
				for _, v in vs do
					if -axisCf:PointToObjectSpace(v).Z < lo + 0.15 then
						table.insert(probes, v)
					end
				end
				for _, w in probes do
					local best = math.huge
					for _, q in list do
						if q ~= p then
							best = math.min(best, outside(q, cf[q], w))
						end
					end
					best = math.min(best, outside(hub, cf[hub], w))
					if best > rim then
						rim, rimAt = best, p.Name
					end
				end
			end
			if HIDDEN[suf] and maxE <= 0.05 then
				for _, w in edgePoints(p, cf[p]) do
					local best = math.huge
					for _, q in list do
						if q ~= p then
							best = math.min(best, outside(q, cf[q], w))
						end
					end
					best = math.min(best, outside(hub, cf[hub], w))
					if best > hide then
						hide, hideAt = best, p.Name
					end
				end
			end
			for _, v in vertices(p, cf[p]) do
				floorY = math.min(floorY, v.Y)
			end
		end
	end
	-- tails against the body
	local hits = {}
	local nHits = 0
	for _, p in parts do
		if tailOf[p] then
			for _, b in parts do
				if not tailOf[b] and b.Name ~= "Tail" and not b.Name:match("^Hips") then
					if boxesOverlap(p, cf[p], b, cf[b], 0.05) then
						nHits += 1
						if #hits < 5 then
							table.insert(hits, p.Name .. "x" .. b.Name)
						end
					end
				end
			end
		end
	end
	return ("%-13s reach %5.2f  gap %4.2f %-11s rim %4.2f %-14s hide %4.2f %-14s floor %5.2f  body[%d] %s"):format(
		name, reach, gap, gapAt, rim, rimAt, hide, hideAt, floorY, nHits, table.concat(hits, ","))
end

local lines = {}
for _, p in POSES do
	table.insert(lines, run(p[1], p[2]))
end
return table.concat(lines, "\n")
