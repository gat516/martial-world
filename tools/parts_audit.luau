--!nocheck
-- Parts audit: the build faults a capture hides and check_rig doesn't look for. Edit mode,
-- through execute_luau; read-only (it changes nothing). Docs: docs/enemies/modeling-checks.md.
--
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8783/tools/parts_audit.luau?" .. os.clock()))()
--   return _G.partsAudit({ target = "ServerStorage.Enemies.JadeJiao", budget = 150 })
--   return _G.partsAudit({ target = "Workspace._MyStaging.Rock", budget = 40, rig = false })
--
-- target: a dotted path to a Model (or a folder of Models: each is audited).
-- budget: the part budget from the brief (about 80 for a pack beast, 150 for a boss).
-- rig: run art/enemies/check_rig.luau on it too (default: when it has a HumanoidRootPart).
-- base: where check_rig is served (default http://127.0.0.1:8783/art/enemies/).
--
-- Reports, over visible parts (Transparency < 1; the HRP doesn't count):
--   loose      a group of parts joined to each other but not to the main body (the group
--              with the most volume): a floating accent, a fin stuck only to another fin.
--              check_rig misses these when the pieces touch each other.
--   floating   a single part that touches nothing.
--   kissing    a part that only touches its neighbours face to face (overlap under JOIN):
--              it reads as stuck on, and a slit of sky shows when it moves or at an angle.
--   zfight     two faces facing the same way within ZFIGHT (5 mm) of each other, overlapping,
--              in different colours or materials: they flicker. Same colour and material on
--              one plane looks the same whichever wins, so it is only counted in the header.
--              Hidden parts are skipped.
--   hidden     a part whose whole surface sits inside other parts at rest: never seen, wasted
--              budget, unless a pose brings it out (a folded hood, a tongue: check RIGS.md).
--   count      visible and total parts against the budget.
--   rig        check_rig's floating / unjointed / rig-contract lines (beasts and R6 alike).
-- Shapes: blocks, wedges, cylinders and balls are exact. MeshParts, unions and corner wedges
-- are treated as their bounding box (flagged "box approx"), so they look bigger than they are:
-- a mesh can hide a part this misses, and a mesh "joined" by its box may still float.

local JOIN = 0.02 -- studs two parts must interpenetrate to count as joined
local GAP = 0.05 -- studs of air still counted as touching (kissing)
local ZFIGHT = 0.005 -- studs between same-facing faces that flicker
local MIN_FACE_OVERLAP = 0.02 -- studs of shared face, both ways, before a z-fight counts
local GRID = 6 -- surface samples per face edge (GRID x GRID per face)

local HttpService = game:GetService("HttpService")

local function resolve(path)
	local node = game
	for name in string.gmatch(path, "[^%.]+") do
		local nxt = node:FindFirstChild(name)
		if not nxt and node == game then
			local ok, svc = pcall(game.GetService, game, name)
			nxt = ok and svc or nil
		end
		if not nxt then
			return nil
		end
		node = nxt
	end
	return node
end

local function shapeOf(p)
	if p:IsA("WedgePart") then
		return "wedge"
	elseif p:IsA("CornerWedgePart") then
		return "box", true
	elseif p:IsA("Part") then
		local s = p.Shape
		if s == Enum.PartType.Ball then
			return "ball"
		elseif s == Enum.PartType.Cylinder then
			return "cyl"
		elseif s == Enum.PartType.Wedge then
			return "wedge"
		elseif s == Enum.PartType.CornerWedge then
			return "box", true
		end
		return "box"
	end
	return "box", true -- MeshPart, UnionOperation, ...
end

-- Signed depth of a world point inside a part: > 0 inside (how far from the nearest face),
-- < 0 outside. Exact enough for the block, wedge, cylinder and ball shapes.
local function depth(info, w)
	local l = info.cf:PointToObjectSpace(w)
	local h = info.half
	if info.shape == "ball" then
		return info.r - l.Magnitude
	end
	local d = math.min(h.X - math.abs(l.X), h.Y - math.abs(l.Y), h.Z - math.abs(l.Z))
	if info.shape == "cyl" then
		local r = math.min(h.Y, h.Z)
		return math.min(h.X - math.abs(l.X), r - math.sqrt(l.Y * l.Y + l.Z * l.Z))
	elseif info.shape == "wedge" then
		-- tall at the back (+Z), sloping down to the front (-Z): inside where y/hy <= z/hz
		local n = Vector3.new(0, h.Z, -h.Y).Unit -- outward normal of the slope
		local slope = -(l - Vector3.new(0, -h.Y, -h.Z)):Dot(n)
		return math.min(d, slope)
	end
	return d
end

-- Points on a part's surface, in world space.
local function surface(info)
	local pts = {}
	local cf, h = info.cf, info.half
	if info.shape == "ball" then
		local n = GRID * GRID * 2
		for i = 0, n - 1 do
			local y = 1 - 2 * (i + 0.5) / n
			local r = math.sqrt(1 - y * y)
			local a = i * 2.39996
			table.insert(pts, cf * (Vector3.new(math.cos(a) * r, y, math.sin(a) * r) * info.r))
		end
		return pts
	end
	local function face(origin, u, v)
		for i = 0, GRID - 1 do
			for j = 0, GRID - 1 do
				local a, b = (i + 0.5) / GRID * 2 - 1, (j + 0.5) / GRID * 2 - 1
				table.insert(pts, cf * (origin + u * a + v * b))
			end
		end
	end
	if info.shape == "cyl" then
		local r = math.min(h.Y, h.Z)
		for i = 0, GRID * 2 - 1 do
			local a = i / (GRID * 2) * math.pi * 2
			for j = 0, GRID - 1 do
				local x = ((j + 0.5) / GRID * 2 - 1) * h.X
				table.insert(pts, cf * Vector3.new(x, math.cos(a) * r, math.sin(a) * r))
			end
			for _, k in { 0.35, 0.75 } do
				table.insert(pts, cf * Vector3.new(h.X, math.cos(a) * r * k, math.sin(a) * r * k))
				table.insert(pts, cf * Vector3.new(-h.X, math.cos(a) * r * k, math.sin(a) * r * k))
			end
		end
		return pts
	end
	local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	face(Vector3.new(h.X, 0, 0), Y * h.Y, Z * h.Z)
	face(Vector3.new(-h.X, 0, 0), Y * h.Y, Z * h.Z)
	face(Vector3.new(0, -h.Y, 0), X * h.X, Z * h.Z)
	face(Vector3.new(0, 0, h.Z), X * h.X, Y * h.Y)
	if info.shape == "wedge" then
		-- the slope, and the triangle sides (keep the half below the slope)
		face(Vector3.zero, X * h.X, Vector3.new(0, h.Y, h.Z))
		for i = #pts, 1, -1 do
			local l = cf:PointToObjectSpace(pts[i])
			if math.abs(math.abs(l.X) - h.X) < 1e-4 and l.Y / h.Y > l.Z / h.Z + 1e-4 then
				table.remove(pts, i)
			end
		end
	else
		face(Vector3.new(0, h.Y, 0), X * h.X, Z * h.Z)
		face(Vector3.new(0, 0, -h.Z), X * h.X, Y * h.Y)
	end
	return pts
end

-- Flat faces (centre, normal, two half-extent vectors) for the z-fight test.
local function faces(info)
	local out = {}
	if info.shape == "ball" then
		return out
	end
	local cf, h = info.cf, info.half
	local R, U, L = cf.RightVector, cf.UpVector, cf.LookVector * -1 -- L = +Z axis
	local function add(c, n, a, b)
		table.insert(out, { c = c, n = n, a = a, b = b })
	end
	local p = cf.Position
	if info.shape == "cyl" then
		local r = math.min(h.Y, h.Z)
		add(p + R * h.X, R, U * r, L * r)
		add(p - R * h.X, -R, U * r, L * r)
		return out
	end
	add(p + R * h.X, R, U * h.Y, L * h.Z)
	add(p - R * h.X, -R, U * h.Y, L * h.Z)
	add(p - U * h.Y, -U, R * h.X, L * h.Z)
	add(p + L * h.Z, L, R * h.X, U * h.Y)
	if info.shape == "wedge" then
		local slope = (U * h.Z - L * h.Y).Unit
		add(p, slope, R * h.X, (U * h.Y + L * h.Z))
	else
		add(p + U * h.Y, U, R * h.X, L * h.Z)
		add(p - L * h.Z, -L, R * h.X, U * h.Y)
	end
	return out
end

-- Two coplanar rectangles: do they share area at least MIN_FACE_OVERLAP across, both ways?
local function rectsOverlap(f, g)
	local axes = { f.a.Unit, f.b.Unit, g.a.Unit, g.b.Unit }
	for _, ax in axes do
		local cf_, cg = f.c:Dot(ax), g.c:Dot(ax)
		local rf = math.abs(f.a:Dot(ax)) + math.abs(f.b:Dot(ax))
		local rg = math.abs(g.a:Dot(ax)) + math.abs(g.b:Dot(ax))
		if math.min(cf_ + rf, cg + rg) - math.max(cf_ - rf, cg - rg) < MIN_FACE_OVERLAP then
			return false
		end
	end
	return true
end

-- Is any of the shared patch of two coplanar faces out in the open (not buried in a third
-- part that overlaps either of them)? Samples face f on a grid, keeps points inside g's rectangle.
local function sharedSeen(f, g, a, b, joined)
	local au, bu = f.a.Unit, f.b.Unit
	local ga, gb = g.a.Magnitude, g.b.Magnitude
	local gau, gbu = g.a.Unit, g.b.Unit
	local any = false
	for i = 0, GRID * 2 - 1 do
		for j = 0, GRID * 2 - 1 do
			local u, v = (i + 0.5) / (GRID * 2) * 2 - 1, (j + 0.5) / (GRID * 2) * 2 - 1
			local w = f.c + f.a * u + f.b * v
			local r = w - g.c
			if math.abs(r:Dot(gau)) <= ga and math.abs(r:Dot(gbu)) <= gb then
				any = true
				local covered = false
				for _, list in { joined[a], joined[b] } do
					for _, o in list do
						if o ~= a and o ~= b and depth(o, w) > 0.005 then
							covered = true
							break
						end
					end
					if covered then
						break
					end
				end
				if not covered then
					return true
				end
			end
		end
	end
	return not any -- a sliver too thin to sample still counts
end

-- Oriented-box separating-axis test with penetration depth (exact for two blocks):
-- returns the smallest overlap over all axes (< 0 means a gap that wide).
local function boxPenetration(a, b)
	local axA = { a.cf.RightVector, a.cf.UpVector, a.cf.LookVector }
	local axB = { b.cf.RightVector, b.cf.UpVector, b.cf.LookVector }
	local ea, eb = a.half, b.half
	local d = b.cf.Position - a.cf.Position
	local best = math.huge
	local function test(n)
		local ra = math.abs(axA[1]:Dot(n)) * ea.X + math.abs(axA[2]:Dot(n)) * ea.Y + math.abs(axA[3]:Dot(n)) * ea.Z
		local rb = math.abs(axB[1]:Dot(n)) * eb.X + math.abs(axB[2]:Dot(n)) * eb.Y + math.abs(axB[3]:Dot(n)) * eb.Z
		best = math.min(best, ra + rb - math.abs(d:Dot(n)))
	end
	for i = 1, 3 do
		test(axA[i])
		test(axB[i])
		for j = 1, 3 do
			local c = axA[i]:Cross(axB[j])
			if c.Magnitude > 1e-4 then
				test(c.Unit)
			end
		end
	end
	return best
end

-- How deep the two parts interpenetrate (> 0) or how wide the gap is (< 0), approximately.
local function contact(a, b)
	local pen = boxPenetration(a, b)
	if pen < -GAP then
		return pen -- their boxes are apart, so the shapes are too
	end
	if a.shape == "box" and b.shape == "box" then
		return pen
	end
	-- a round or sloped shape: the deepest surface sample of either inside the other
	local deepest = -math.huge
	for _, w in a.pts do
		deepest = math.max(deepest, depth(b, w))
	end
	for _, w in b.pts do
		deepest = math.max(deepest, depth(a, w))
	end
	return math.min(deepest, pen)
end

local function name(model, p)
	local rel = p:GetFullName()
	local root = model:GetFullName()
	return string.sub(rel, #root + 2)
end

local function audit(model, opts)
	local parts, total = {}, 0
	local approx = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			total += 1
			if d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
				local shape, isApprox = shapeOf(d)
				local info = { part = d, cf = d.CFrame, half = d.Size / 2, shape = shape, approx = isApprox }
				info.r = math.min(d.Size.X, d.Size.Y, d.Size.Z) / 2
				info.vol = d.Size.X * d.Size.Y * d.Size.Z
				info.lo, info.hi = d.Position - Vector3.one * (d.Size.Magnitude / 2), d.Position + Vector3.one * (d.Size.Magnitude / 2)
				table.insert(parts, info)
				if isApprox then
					approx += 1
				end
			end
		end
	end
	for i, info in parts do
		info.pts = surface(info)
		if i % 40 == 0 then
			task.wait()
		end
	end

	-- neighbours by bounding sphere, then contact depth
	local joined, touching = {}, {}
	for _, a in parts do
		joined[a], touching[a] = {}, {}
	end
	local near, ops = {}, 0
	for i = 1, #parts do
		local a = parts[i]
		for j = i + 1, #parts do
			local b = parts[j]
			if a.lo.X <= b.hi.X + GAP and b.lo.X <= a.hi.X + GAP and a.lo.Y <= b.hi.Y + GAP and b.lo.Y <= a.hi.Y + GAP and a.lo.Z <= b.hi.Z + GAP and b.lo.Z <= a.hi.Z + GAP then
				local c = contact(a, b)
				if c >= JOIN then
					table.insert(joined[a], b)
					table.insert(joined[b], a)
				elseif c >= -GAP then
					table.insert(touching[a], b)
					table.insert(touching[b], a)
				end
				if c >= -GAP then
					table.insert(near, { a, b })
				end
				ops += 1
				if ops % 400 == 0 then
					task.wait()
				end
			end
		end
	end

	-- groups joined by real overlap; the main body is the one with the most volume
	local group, groups = {}, {}
	for _, p in parts do
		if not group[p] then
			local g = { parts = {}, vol = 0 }
			local stack = { p }
			group[p] = g
			while #stack > 0 do
				local q = table.remove(stack)
				table.insert(g.parts, q)
				g.vol += q.vol
				for _, r in joined[q] do
					if not group[r] then
						group[r] = g
						table.insert(stack, r)
					end
				end
			end
			table.insert(groups, g)
		end
	end
	table.sort(groups, function(x, y)
		return x.vol > y.vol
	end)

	local lines = {}
	for k = 2, #groups do
		local g = groups[k]
		local names = {}
		local kisses = false
		for _, q in g.parts do
			table.insert(names, name(model, q.part) .. (q.approx and " (box approx)" or ""))
			for _, r in touching[q] do
				if group[r] ~= g then
					kisses = true
				end
			end
		end
		if #g.parts == 1 then
			table.insert(lines, (kisses and "kissing: " or "floating: ") .. names[1] .. (kisses and " only touches its neighbour face to face" or " touches nothing"))
		else
			table.insert(lines, string.format("loose: %d parts joined to each other but not the body%s: %s", #g.parts, kisses and " (they only kiss it)" or "", table.concat(names, ", ")))
		end
	end

	-- hidden: every surface sample inside some other visible part
	local hidden = {}
	for idx, a in parts do
		local inside = true
		for _, w in a.pts do
			local covered = false
			for _, b in joined[a] do
				if not b.approx and depth(b, w) > 0.005 then
					covered = true
					break
				end
			end
			if not covered then
				inside = false
				break
			end
		end
		if inside then
			hidden[a] = true
			table.insert(lines, "hidden: " .. name(model, a.part) .. " sits wholly inside other parts")
		end
		if idx % 40 == 0 then
			task.wait()
		end
	end
	-- z-fights between parts that are seen. Identical colour and material on the same plane
	-- renders the same whichever face wins, so those only go in the summary count.
	local quiet = 0
	for _, pair in near do
		local a, b = pair[1], pair[2]
		if not hidden[a] and not hidden[b] then
			local hit = false
			for _, f in faces(a) do
				for _, g in faces(b) do
					if f.n:Dot(g.n) > 0.9995 and math.abs((g.c - f.c):Dot(f.n)) < ZFIGHT and rectsOverlap(f, g) and sharedSeen(f, g, a, b, joined) then
						hit = true
						break
					end
				end
				if hit then
					break
				end
			end
			if hit then
				if a.part.Color == b.part.Color and a.part.Material == b.part.Material then
					quiet += 1
				else
					table.insert(lines, string.format("zfight: %s / %s (different colour or material on one plane)", name(model, a.part), name(model, b.part)))
				end
			end
		end
	end

	local budget = opts.budget
	local head = string.format("%s: %d visible / %d parts%s, %d group(s)%s%s", model.Name, #parts, total, budget and string.format(" (budget %d%s)", budget, #parts > budget and ", OVER" or "") or "", #groups, approx > 0 and string.format(", %d mesh/union/corner parts as boxes", approx) or "", quiet > 0 and string.format(", %d same-colour coplanar pairs (harmless)", quiet) or "")

	local wantRig = opts.rig
	if wantRig == nil then
		wantRig = model:FindFirstChild("HumanoidRootPart") ~= nil
	end
	if wantRig then
		local ok, res = pcall(function()
			local src = HttpService:GetAsync((opts.base or "http://127.0.0.1:8783/art/enemies/") .. "check_rig.luau?" .. os.clock())
			src = string.gsub(src, "local TARGETS = {}", function()
				return "local TARGETS = { " .. string.format("%q", model:GetFullName()) .. " }"
			end, 1)
			return loadstring(src)()
		end)
		table.insert(lines, 1, "rig (check_rig): " .. (ok and tostring(res) or ("not run: " .. tostring(res))))
	end
	if #lines == 0 then
		return head .. ": clean"
	end
	return head .. "\n  " .. table.concat(lines, "\n  ")
end

_G.partsAudit = function(opts)
	local node = typeof(opts.target) == "Instance" and opts.target or resolve(opts.target)
	if not node then
		return "parts_audit: nothing at " .. tostring(opts.target)
	end
	if node:IsA("Model") then
		return audit(node, opts)
	end
	local out = {}
	for _, m in node:GetChildren() do
		if m:IsA("Model") then
			table.insert(out, audit(m, opts))
		end
	end
	return table.concat(out, "\n")
end
return _G.partsAudit
