--!nocheck
--[[
Builds the light-pass (parts only) templates for the tier I-V herbs that had no model yet and
for the consumables:
  ReplicatedStorage.HerbModelsExtra.<HerbId>   (assets/HerbModelsExtra.rbxm)
  ReplicatedStorage.ItemModels.<ItemId>        (assets/ItemModels.rbxm)
Run in a sandbox Studio (Edit mode, no Rojo) through the MCP: load this file as a ModuleScript
and call it, or paste it into the command bar. It replaces both folders, then export them with
tools/export_rbxm.luau. One ChangeHistory recording, so Ctrl+Z undoes it.

Intent: a garden herb is read from 15-25 studs above and behind the player, so each one has a
single hero shape (the lantern bulb, the spiral vine, the plume fan, the lightning crown...),
the tier read from its glow (Neon accents grow with the tier), and plain SmoothPlastic colours
elsewhere. Pills and cores are tiny glossy readable tokens for loot drops and eating effects.
Every template is flagged NeedsArtPass with an ArtPassReason: this is a cheap first pass.

Axes: X right, Y up, Z toward the viewer; 1 unit = 1 stud. Every template's WorldPivot is the
identity at its ground point (the stem's base, the water surface for pond herbs, the bottom of
an item), PrimaryPart nil; cylinders are turned upright inside the model. Herb sizes are the
mature size at template scale 1 (Herbs.Defs scale multiplies on top), about the footprint of
the herb's spacing: bed herbs ~2 x 2.5 tall, pond herbs ~2.5 across, grove trees ~4.5 x 5.5.
Ellipsoids are Parts with a Sphere SpecialMesh (they follow Size, so Model:ScaleTo works).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local V = Vector3.new
local C = Color3.fromRGB
local PI = math.pi

-- ---------------------------------------------------------------- helpers

local function part(parent, name, shape, size, cf, color, opts)
	opts = opts or {}
	local p
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if shape == "ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if opts.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = opts.transparency or 0
	p.Reflectance = opts.reflectance or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.CastShadow = not opts.neon and size.Magnitude > 0.5
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ell" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = parent
	return p
end

local function upFor(dir)
	return if math.abs(dir.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
end

-- A cylinder (or flat block with `opts.flat` = {thick, width}) from a to b, a little long so
-- joints overlap.
local function seg(parent, name, a, b, d, color, opts)
	opts = opts or {}
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local mid = (a + b) / 2
	if opts.flat then
		local cf = CFrame.lookAt(mid, b, opts.up or upFor(dir))
		return part(parent, name, "block", V(opts.flat[2], opts.flat[1], len + opts.flat[1]), cf, color, opts)
	end
	local cf = CFrame.lookAt(mid, b, upFor(dir)) * CFrame.Angles(0, PI / 2, 0)
	return part(parent, name, "cyl", V(len + d * 0.4, d, d), cf, color, opts)
end

-- A tapering chain of segments through pts with a ball at each inner joint.
local function chain(parent, name, pts, d0, d1, color, opts)
	local n = #pts - 1
	for i = 1, n do
		local d = d0 + (d1 - d0) * (i - 1) / math.max(n - 1, 1)
		seg(parent, name, pts[i], pts[i + 1], d, color, opts)
		if i < n then
			part(parent, name .. "Joint", "ball", V(d, d, d), CFrame.new(pts[i + 1]), color, opts)
		end
	end
end

-- An ellipsoid leaf/petal starting at `base`, running `len` along `dir`, `width` across, `thick`
-- through. `up` picks which way its flat face looks.
local function leaf(parent, name, base, dir, len, width, thick, color, opts, up)
	dir = dir.Unit
	local centre = base + dir * (len / 2)
	local cf = CFrame.lookAt(centre, centre + dir, up or upFor(dir))
	return part(parent, name, "ell", V(width, thick, len), cf, color, opts)
end

local function disc(parent, name, centre, d, h, color, opts)
	return part(parent, name, "cyl", V(h, d, d), CFrame.new(centre) * CFrame.Angles(0, 0, PI / 2), color, opts)
end

local function dirAt(yaw, pitch) -- yaw around Y from +X, pitch up from horizontal
	return V(math.cos(yaw) * math.cos(pitch), math.sin(pitch), -math.sin(yaw) * math.cos(pitch))
end

local function newModel(name, reason)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("NeedsArtPass", true)
	m:SetAttribute("ArtPassReason", reason)
	return m
end

local function finish(m, parent)
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------- herbs

local H = {}

-- Pond, tier I. Hero: the cold-green lantern bulb hanging from an arched stem.
function H.GhostlampLily(m)
	local pad = C(40, 85, 60)
	disc(m, "Pad", V(0.45, 0.04, 0.35), 1.4, 0.08, pad)
	disc(m, "Pad", V(-0.6, 0.04, 0.15), 1.0, 0.08, C(48, 96, 66))
	disc(m, "Pad", V(-0.05, 0.04, -0.7), 0.9, 0.08, pad)
	local stem = C(120, 160, 125)
	chain(m, "Stem", { V(0, 0, 0), V(0.05, 1.2, 0), V(0.25, 2.0, 0), V(0.6, 2.3, 0), V(0.88, 2.12, 0) }, 0.13, 0.09, stem)
	leaf(m, "Leaf", V(0.05, 0.7, 0), V(-0.8, 0.9, 0.2), 0.9, 0.3, 0.05, C(70, 120, 85))
	local hang = V(0.9, 2.1, 0)
	part(m, "Bulb", "ell", V(0.5, 0.72, 0.5), CFrame.new(hang - V(0, 0.42, 0)), C(140, 255, 185), { neon = true })
	for i = 0, 2 do
		local yaw = i * 2 * PI / 3
		leaf(m, "Hood", hang, dirAt(yaw, -1.15), 0.62, 0.32, 0.06, C(222, 240, 226))
	end
end

-- Bed, tier II. Hero: three wind-bent stalks with violet heads all leaning to +X.
function H.DuskwindThistle(m)
	local leafC = C(140, 156, 150)
	for i = 0, 6 do
		local yaw = i * 2 * PI / 7 + 0.3
		leaf(m, "Leaf", V(0, 0.08, 0), dirAt(yaw, 0.45 + (i % 2) * 0.25), 1.1 - (i % 2) * 0.25, 0.26, 0.05, leafC)
	end
	local stalkC = C(120, 135, 125)
	local stalks = {
		{ V(0, 0, 0), 2.7 },
		{ V(0.2, 0, 0.28), 2.2 },
		{ V(-0.18, 0, -0.22), 1.8 },
	}
	for _, s in stalks do
		local b, h = s[1], s[2]
		local pts = { b, b + V(0.15, h * 0.45, 0), b + V(0.55, h * 0.82, 0), b + V(0.95, h, 0) }
		chain(m, "Stalk", pts, 0.1, 0.08, stalkC)
		local tip, dir = pts[4], (pts[4] - pts[3]).Unit
		leaf(m, "StalkLeaf", pts[2], V(-0.6, 0.5, 0.2), 0.5, 0.16, 0.04, leafC)
		part(m, "Bract", "ball", V(0.42, 0.42, 0.42), CFrame.new(tip), C(110, 128, 112))
		seg(m, "Bloom", tip + dir * 0.12, tip + dir * 0.42, 0.38, C(150, 95, 200))
		seg(m, "BloomTip", tip + dir * 0.38, tip + dir * 0.5, 0.28, C(190, 140, 235))
	end
end

-- Bed, tier III. Hero: seven glowing star flowers over a dark tuft, set as the Northern Dipper.
function H.SevenStarGrass(m)
	local blade = C(35, 80, 88)
	for i = 0, 10 do
		local yaw = i * 2 * PI / 11
		local pitch = 1.05 + (i % 3) * 0.12
		local len = 1.0 + (i % 4) * 0.18
		local d1 = dirAt(yaw, pitch)
		local mid = V(0, 0.02, 0) + d1 * len
		leaf(m, "Blade", V(0, 0.02, 0), d1, len + 0.1, 0.2, 0.05, blade)
		leaf(m, "BladeTip", mid - d1 * 0.05, dirAt(yaw, pitch - 0.7), 0.55, 0.14, 0.04, C(45, 98, 100))
	end
	local dipper = { -- bowl then handle, (x, z, height)
		V(-0.55, 1.75, 0.3), V(-0.15, 1.9, 0.38), V(-0.08, 1.95, -0.05), V(-0.5, 1.8, -0.15),
		V(0.28, 2.05, -0.18), V(0.6, 2.1, -0.28), V(0.92, 1.95, -0.12),
	}
	for i, p in dipper do
		local at = V(p.X, p.Y, p.Z)
		seg(m, "StarStalk", V(p.X * 0.25, 0.4, p.Z * 0.25), at, 0.04, C(70, 120, 120))
		part(m, "Star", "ball", V(0.17, 0.17, 0.17), CFrame.new(at), C(240, 248, 255), { neon = true })
		for k = 0, 2 do
			part(m, "StarRay", "block", V(0.34, 0.04, 0.05), CFrame.new(at) * CFrame.Angles(0, k * PI / 3 + i, 0.25), C(220, 235, 255), { neon = true })
		end
	end
end

-- Grove, tier III. Hero: glowing ember fruit under a red-tipped canopy on a charcoal trunk.
function H.EmberheartFruit(m)
	local bark = C(48, 42, 42)
	part(m, "Flare", "ball", V(0.75, 0.75, 0.75), CFrame.new(0, 0.05, 0), bark)
	chain(m, "Trunk", { V(0, -0.2, 0), V(0.18, 1.4, 0.05), V(-0.05, 2.5, 0), V(0.05, 3.3, 0) }, 0.48, 0.34, bark)
	seg(m, "Branch", V(0.05, 2.3, 0), V(1.2, 3.3, 0.3), 0.2, bark)
	seg(m, "Branch", V(-0.02, 2.2, 0), V(-1.1, 3.1, -0.4), 0.2, bark)
	seg(m, "Branch", V(0, 2.6, 0), V(0.2, 3.4, -0.95), 0.18, bark)
	local clumps = {
		{ V(1.3, 3.55, 0.3), V(1.8, 1.1, 1.6) },
		{ V(-1.2, 3.35, -0.4), V(1.7, 1.0, 1.5) },
		{ V(0, 4.05, 0.05), V(2.1, 1.3, 1.9) },
		{ V(0.25, 3.55, -1.05), V(1.5, 1.0, 1.4) },
	}
	for _, c in clumps do
		part(m, "Canopy", "ell", c[2], CFrame.new(c[1]), C(58, 96, 56))
		for k = 0, 4 do -- red leaf tips poking out round the clump's rim
			local yaw = k * 2 * PI / 5 + c[1].X
			local out = V(math.cos(yaw) * c[2].X, 0, -math.sin(yaw) * c[2].Z) * 0.42
			leaf(m, "LeafTip", c[1] + out + V(0, 0.1, 0), out + V(0, 0.25, 0), 0.75, 0.32, 0.07, C(232, 42, 30))
		end
	end
	local fruits = { V(1.35, 2.85, 0.65), V(-1.05, 2.7, -0.05), V(0.45, 3.0, -1.15), V(-0.3, 3.2, 0.7) }
	for _, f in fruits do
		seg(m, "FruitStem", f, f + V(0, 0.55, 0), 0.06, bark)
		part(m, "Fruit", "ball", V(0.5, 0.5, 0.5), CFrame.new(f), C(225, 72, 24), { neon = true })
		disc(m, "FruitCrack", f, 0.53, 0.05, C(60, 30, 25)).CFrame = CFrame.new(f) * CFrame.Angles(0.5, 0, PI / 2 + 0.3)
	end
end

-- Bed, tier IV. Hero: one thick crimson vine coiling up in a spiral, beaded with glowing sap.
function H.DragonbloodVine(m)
	local vine = C(112, 22, 28)
	part(m, "RootKnot", "ball", V(0.65, 0.65, 0.65), CFrame.new(0.75, 0.12, 0), C(62, 22, 22))
	local pts = {}
	local N = 22
	for i = 0, N do
		local t = i / N
		local a = t * 2.6 * 2 * PI
		local r = 0.75 - 0.42 * t
		table.insert(pts, V(math.cos(a) * r, 0.12 + 2.6 * t, -math.sin(a) * r))
	end
	chain(m, "Vine", pts, 0.3, 0.13, vine)
	for i = 2, N, 2 do
		local p = pts[i]
		local out = V(p.X, 0, p.Z).Unit
		leaf(m, "Scale", p, out + V(0, 0.6, 0), 0.42, 0.26, 0.06, C(78, 18, 24))
	end
	for _, i in { 4, 9, 13, 17, 21 } do
		local p = pts[i]
		part(m, "Sap", "ball", V(0.17, 0.17, 0.17), CFrame.new(p - V(0, 0.16, 0)), C(255, 40, 45), { neon = true })
	end
	part(m, "Bud", "ell", V(0.24, 0.42, 0.24), CFrame.new(pts[#pts] + V(0, 0.15, 0)), C(200, 35, 40))
end

-- Bed, tier IV. Hero: a fan of long curling plume petals, gold to scarlet, like a phoenix tail.
function H.PhoenixPlumeOrchid(m)
	local green = C(72, 122, 62)
	for i = 0, 2 do
		leaf(m, "Leaf", V(0, 0.05, 0), dirAt(i * 2 * PI / 3 + 0.4, 0.55), 1.3, 0.3, 0.05, green)
	end
	local c = V(0, 2.4, 0)
	chain(m, "Stalk", { V(0, 0, 0), V(0.1, 1.3, 0), c }, 0.11, 0.09, C(95, 120, 62))
	part(m, "Heart", "ball", V(0.28, 0.28, 0.28), CFrame.new(c), C(255, 205, 90), { neon = true })
	local cols = { C(255, 195, 70), C(255, 130, 45), C(228, 52, 42), C(175, 25, 38) }
	local widths = { 0.34, 0.3, 0.25, 0.18 }
	for i = 0, 4 do
		local yaw = i * 2 * PI / 5 + 0.2
		local out = V(math.cos(yaw), 0, -math.sin(yaw))
		local pts = { c, c + out * 0.45 + V(0, 0.4, 0), c + out * 0.95 + V(0, 0.42, 0), c + out * 1.3 + V(0, 0.05, 0), c + out * 1.35 + V(0, -0.4, 0) }
		for k = 1, 4 do
			local a, b = pts[k], pts[k + 1]
			leaf(m, "Plume", a, b - a, (b - a).Magnitude + 0.15, widths[k], 0.06, cols[k])
		end
	end
	for i = 0, 2 do
		leaf(m, "Crest", c, dirAt(i * 2 * PI / 3, 1.25), 0.6, 0.18, 0.05, C(255, 210, 100))
	end
end

-- Pond, tier IV. Hero: a many-layered white lotus whose petal tips turn ice blue.
function H.SnowpeakLotus(m)
	disc(m, "Pad", V(0.1, 0.04, 0.1), 1.6, 0.08, C(170, 205, 200))
	disc(m, "Pad", V(-0.95, 0.04, -0.45), 0.9, 0.08, C(150, 190, 188))
	local c = V(0, 0.18, 0)
	part(m, "Base", "ell", V(0.6, 0.25, 0.6), CFrame.new(c), C(200, 225, 220))
	local rings = { -- count, pitch, length, width, colour, tipped
		{ 8, 0.5, 1.0, 0.5, C(245, 250, 255), true },
		{ 8, 0.9, 0.85, 0.44, C(240, 247, 255), true },
		{ 6, 1.22, 0.62, 0.36, C(228, 240, 255), false },
	}
	for r, ring in rings do
		for i = 0, ring[1] - 1 do
			local yaw = (i + r * 0.5) * 2 * PI / ring[1]
			local d = dirAt(yaw, ring[2])
			local base = c + V(math.cos(yaw), 0, -math.sin(yaw)) * 0.1 + V(0, r * 0.03, 0)
			leaf(m, "Petal", base, d, ring[3], ring[4], 0.08, ring[5])
			if ring[6] then
				leaf(m, "PetalTip", base + d * (ring[3] * 0.7), d, ring[3] * 0.32, ring[4] * 0.55, 0.09, C(150, 210, 255))
			end
		end
	end
	part(m, "Heart", "ball", V(0.26, 0.26, 0.26), CFrame.new(c + V(0, 0.2, 0)), C(205, 238, 255), { neon = true })
end

-- Grove, tier IV. Hero: tall midnight-blue culms ringed with silver nodes, star-flecked leaves.
function H.StarfallBamboo(m)
	local culm, node, leafC = C(28, 38, 86), C(200, 210, 228), C(48, 86, 112)
	local culms = {
		{ V(0, 0, 0), 6.0, 0.38, V(0.25, 0, 0.1) },
		{ V(0.62, 0, 0.32), 4.8, 0.32, V(0.45, 0, 0.25) },
		{ V(-0.55, 0, 0.42), 5.4, 0.34, V(-0.35, 0, 0.3) },
		{ V(0.1, 0, -0.62), 4.2, 0.28, V(0.1, 0, -0.4) },
	}
	for ci, cdef in culms do
		local base, h, d, lean = cdef[1], cdef[2], cdef[3], cdef[4]
		local top = base + V(0, h, 0) + lean
		seg(m, "Culm", base - V(0, 0.2, 0), top, d, culm)
		local axis = (top - base).Unit
		for y = 1.0, h - 0.3, 1.1 do
			local p = base + axis * y
			part(m, "Node", "cyl", V(0.09, d + 0.08, d + 0.08), CFrame.lookAt(p, p + axis, Vector3.xAxis) * CFrame.Angles(0, PI / 2, 0), node)
		end
		for s = 0, 1 do
			local at = base + axis * (h * (0.78 + s * 0.18))
			for k = 0, 2 do
				local yaw = ci + s * 2 + k * 0.7
				local l = leaf(m, "Leaf", at, dirAt(yaw, -0.35 + k * 0.15), 1.4, 0.32, 0.05, leafC)
				if k ~= 1 then
					part(m, "Speck", "ball", V(0.1, 0.1, 0.1), CFrame.new(l.Position + V(0, 0.03, 0)), C(225, 235, 255), { neon = true })
				end
			end
		end
	end
end

-- Bed, tier V. Hero: a crown of jagged lightning blades with white-hot tips over scorched soil.
function H.TribulationThunderGrass(m)
	disc(m, "Scorch", V(0, 0.03, 0), 2.2, 0.06, C(26, 22, 26))
	disc(m, "ScorchCore", V(0, 0.05, 0), 0.9, 0.07, C(40, 34, 40))
	for i = 0, 3 do
		local yaw = i * PI / 2 + 0.4
		part(m, "Crack", "block", V(0.85, 0.03, 0.05), CFrame.new(math.cos(yaw) * 0.65, 0.065, -math.sin(yaw) * 0.65) * CFrame.Angles(0, yaw, 0), C(175, 120, 255), { neon = true })
	end
	local cols = { C(220, 218, 240), C(178, 165, 230) }
	for i = 0, 6 do
		local yaw = i * 2 * PI / 7
		local out = V(math.cos(yaw), 0, -math.sin(yaw))
		local tan = V(-out.Z, 0, out.X)
		local h = 2.1 + (i % 3) * 0.35
		local b = out * 0.22 + V(0, 0.05, 0)
		local pts = {
			b,
			b + out * 0.35 - tan * 0.12 + V(0, h * 0.4, 0),
			b + out * 0.2 + tan * 0.42 + V(0, h * 0.55, 0),
			b + out * 0.7 - tan * 0.05 + V(0, h * 0.85, 0),
			b + out * 0.55 + tan * 0.35 + V(0, h, 0),
		}
		for k = 1, 4 do
			seg(m, "Blade", pts[k], pts[k + 1], 0, cols[(k % 2) + 1], { flat = { 0.05, 0.15 - k * 0.02 }, up = out })
		end
		part(m, "Spark", "ell", V(0.16, 0.4, 0.16), CFrame.lookAt(pts[5], pts[5] + (pts[5] - pts[4])) * CFrame.Angles(-PI / 2, 0, 0), C(245, 240, 255), { neon = true })
	end
end

-- Pond, tier V. Hero: nine shrinking rings of golden-white petals hovering over the pad, under a halo.
function H.NinefoldHeavenLotus(m)
	disc(m, "Pad", V(0, 0.05, 0), 2.4, 0.1, C(118, 150, 72))
	disc(m, "Pad", V(1.25, 0.04, 0.7), 1.1, 0.08, C(105, 138, 64))
	disc(m, "PadGlow", V(0, 0.11, 0), 1.0, 0.03, C(255, 225, 140), { neon = true, transparency = 0.45 })
	local counts = { 9, 9, 8, 8, 7, 7, 6, 6, 5 }
	local c = V(0, 0.55, 0)
	local outer, inner = C(255, 244, 214), C(255, 196, 78)
	for k = 0, 8 do
		local len = 1.25 - k * 0.09
		local pitch = 0.12 + k * 0.15
		for i = 0, counts[k + 1] - 1 do
			local yaw = (i + k * 0.37) * 2 * PI / counts[k + 1]
			leaf(m, "Petal", c + V(0, k * 0.045, 0), dirAt(yaw, pitch), len, 0.42 - k * 0.025, 0.06, outer:Lerp(inner, k / 8))
		end
	end
	part(m, "Heart", "ball", V(0.3, 0.3, 0.3), CFrame.new(c + V(0, 0.5, 0)), C(255, 215, 110), { neon = true })
	local hy, hr = 2.1, 1.0
	for i = 0, 15 do
		local yaw = i * 2 * PI / 16
		part(m, "Halo", "block", V(0.38, 0.05, 0.06), CFrame.new(math.cos(yaw) * hr, hy, -math.sin(yaw) * hr) * CFrame.Angles(0, yaw + PI / 2, 0), C(255, 228, 150), { neon = true })
	end
end

-- Grove, tier V. Hero: one fruit glowing half black, half white, on a gnarled pale-jade tree
-- whose two roots (one pale, one dark) swirl round the base as a taiji.
function H.DaoOriginFruit(m)
	local bark = C(152, 186, 162)
	chain(m, "Trunk", { V(0, -0.2, 0), V(0.32, 1.0, 0.1), V(-0.2, 2.0, -0.1), V(0.2, 3.0, 0.1), V(0, 3.8, 0) }, 0.56, 0.3, bark)
	part(m, "Flare", "ball", V(0.8, 0.8, 0.8), CFrame.new(0, 0.05, 0), bark)
	chain(m, "Branch", { V(0.2, 3.0, 0.1), V(1.25, 3.85, 0.2), V(1.7, 4.1, 0.5) }, 0.2, 0.14, bark)
	chain(m, "Branch", { V(-0.15, 2.6, 0), V(-1.2, 3.55, -0.3), V(-1.5, 3.75, -0.1) }, 0.18, 0.13, bark)
	seg(m, "Branch", V(0, 3.75, 0), V(0.2, 4.6, -0.45), 0.16, bark)
	for _, p in { V(-1.5, 3.95, -0.1), V(0.2, 4.85, -0.45), V(1.25, 4.25, 0.15) } do
		part(m, "Leaves", "ell", V(1.1, 0.75, 0.95), CFrame.new(p), C(96, 168, 116))
	end
	for r = 0, 1 do
		local pts = {}
		for i = 0, 6 do
			local t = i / 6
			local a = r * PI + t * PI * 1.15
			local rad = 0.32 + 1.35 * t
			table.insert(pts, V(math.cos(a) * rad, 0.12 - 0.07 * t, -math.sin(a) * rad))
		end
		chain(m, if r == 0 then "RootYang" else "RootYin", pts, 0.34, 0.12, if r == 0 then C(222, 232, 222) else C(46, 54, 52))
	end
	-- hangs under the right-hand leaf clump, its two halves side by side facing +Z
	local f = V(1.25, 3.45, 0.3)
	seg(m, "FruitStem", f + V(0, 0.3, 0), V(1.25, 4.1, 0.15), 0.06, bark)
	part(m, "FruitYang", "ball", V(0.6, 0.6, 0.6), CFrame.new(f + V(-0.15, 0, 0)), C(250, 248, 238), { neon = true })
	part(m, "FruitYin", "ball", V(0.6, 0.6, 0.6), CFrame.new(f + V(0.15, 0, 0)), C(26, 26, 30))
	part(m, "EyeYin", "ball", V(0.13, 0.13, 0.13), CFrame.new(f + V(-0.2, 0.04, 0.27)), C(26, 26, 30))
	part(m, "EyeYang", "ball", V(0.13, 0.13, 0.13), CFrame.new(f + V(0.2, 0.04, 0.27)), C(250, 248, 238), { neon = true })
end

local HERB_ORDER = {
	"GhostlampLily", "DuskwindThistle", "SevenStarGrass", "EmberheartFruit", "DragonbloodVine",
	"PhoenixPlumeOrchid", "SnowpeakLotus", "StarfallBamboo", "TribulationThunderGrass",
	"NinefoldHeavenLotus", "DaoOriginFruit",
}
local HERB_REASON = {
	GhostlampLily = "light pass: parts; needs a modelled lily hood and a soft bulb glow (vfx)",
	DuskwindThistle = "light pass: parts; needs spiky modelled leaves and thistle heads, wind sway",
	SevenStarGrass = "light pass: parts; needs real grass blades and star-flower glints (vfx)",
	EmberheartFruit = "light pass: parts; needs a modelled tree, crackled fruit texture and ember glow",
	DragonbloodVine = "light pass: parts; needs a smooth mesh vine with scales and sap drip vfx",
	PhoenixPlumeOrchid = "light pass: parts; needs modelled curling plume petals and a heat shimmer",
	SnowpeakLotus = "light pass: parts; needs modelled petals and the cold mist vfx",
	StarfallBamboo = "light pass: parts; needs leaf sprays and the falling light motes vfx",
	TribulationThunderGrass = "light pass: parts; needs lightning crackle vfx and a scorched decal",
	NinefoldHeavenLotus = "light pass: parts; needs modelled petal rings, halo glow and hover bob",
	DaoOriginFruit = "light pass: parts; needs a gnarled mesh tree, a true half/half taiji fruit and glow",
}

-- ---------------------------------------------------------------- items

local I = {}

-- A pill: a glossy sphere sitting on its pivot, a pattern band and a faint glow shell.
local function pill(m, d, body, band, glow)
	local c = V(0, d / 2, 0)
	part(m, "Body", "ball", V(d, d, d), CFrame.new(c), body, { reflectance = 0.12 })
	disc(m, "Band", c, d * 1.03, d * 0.09, band).CFrame = CFrame.new(c) * CFrame.Angles(0.45, 0, PI / 2 + 0.25)
	part(m, "Shine", "ball", V(d * 0.2, d * 0.2, d * 0.2), CFrame.new(c + V(-d * 0.22, d * 0.24, d * 0.22)), C(255, 255, 255), { neon = true })
	part(m, "Glow", "ball", V(d * 1.15, d * 1.15, d * 1.15), CFrame.new(c), glow, { neon = true, transparency = 0.93 })
	return c
end

-- A faceted gem standing on its point: two crossed diamond slabs round a turned cube, so every
-- side shows a diamond outline, with a glowing heart. Returns the gem's centre.
local function gem(m, at, s, body, tilt)
	local base = CFrame.new(at) * CFrame.Angles(0, 0, tilt or 0)
	local light = body:Lerp(C(255, 255, 255), 0.3)
	for k = 0, 1 do
		part(m, "Facet", "block", V(s * 0.707, s * 0.707, s * 0.28), base * CFrame.Angles(0, k * PI / 2, 0) * CFrame.Angles(0, 0, PI / 4), if k == 0 then body else light, { reflectance = 0.1 })
	end
	part(m, "Facet", "block", V(s, s, s) * 0.42, base * CFrame.Angles(0, PI / 4, 0) * CFrame.Angles(PI / 4, 0, 0), body:Lerp(C(0, 0, 0), 0.12), { reflectance = 0.1 })
end

local function core(m, s, body, heart)
	local c = V(0, s * 0.5, 0)
	gem(m, c, s, body)
	part(m, "Heart", "ball", V(s, s, s) * 0.3, CFrame.new(c), heart, { neon = true })
	return c
end

function I.MarrowWashingPill(m)
	pill(m, 0.4, C(240, 195, 95), C(170, 120, 40), C(255, 215, 120))
end

function I.RootRebirthPill(m)
	local c = pill(m, 0.4, C(165, 125, 235), C(235, 225, 255), C(190, 150, 255))
	for s = -1, 1, 2 do
		leaf(m, "Leaf", c + V(0, 0.18, 0), V(s * 0.8, 1, 0), 0.2, 0.11, 0.03, C(90, 160, 80))
	end
end

function I.LesserSpiritCore(m)
	core(m, 0.6, C(110, 225, 205), C(200, 255, 245))
end

function I.GreaterSpiritCore(m)
	-- a crystal cluster: a big gem flanked by two leaning shards, so it never reads as the lesser one
	local c = core(m, 0.62, C(235, 78, 58), C(255, 200, 130))
	gem(m, c + V(0.24, -0.08, 0.05), 0.34, C(210, 60, 50), -0.5)
	gem(m, c + V(-0.22, -0.1, -0.06), 0.3, C(210, 60, 50), 0.45)
end

-- A drop of dew: a round belly tapering to a point, with a bright heart.
function I.HeavenlyDew(m)
	local col = C(150, 220, 255)
	part(m, "Body", "ball", V(0.42, 0.42, 0.42), CFrame.new(0, 0.21, 0), col, { transparency = 0.2, reflectance = 0.15 })
	part(m, "Taper", "ell", V(0.32, 0.42, 0.32), CFrame.new(0, 0.36, 0), col, { transparency = 0.2 })
	part(m, "Tip", "ell", V(0.15, 0.26, 0.15), CFrame.new(0, 0.53, 0), col, { transparency = 0.2 })
	part(m, "Heart", "ball", V(0.18, 0.18, 0.18), CFrame.new(0, 0.2, 0), C(230, 248, 255), { neon = true })
end

-- A jade bi disc standing on edge, its face toward +Z, with two cloud curls and a dark centre.
function I.CloudPatternJade(m)
	local jade, rim = C(140, 220, 165), C(95, 170, 120)
	local d = 0.7
	local c = V(0, d / 2, 0)
	local face = CFrame.new(c) * CFrame.Angles(0, PI / 2, 0)
	part(m, "Disc", "cyl", V(0.12, d, d), face, jade, { reflectance = 0.08 })
	part(m, "Hole", "cyl", V(0.14, 0.2, 0.2), face, C(40, 70, 55))
	for s = -1, 1, 2 do
		for f = -1, 1, 2 do
			part(m, "Cloud", "ell", V(0.16, 0.07, 0.02), CFrame.new(c + V(s * 0.19, s * 0.12, f * 0.065)) * CFrame.Angles(0, 0, s * 0.5), C(225, 255, 235), { neon = true })
		end
	end
	part(m, "Rim", "cyl", V(0.1, d * 1.04, d * 1.04), face, rim)
end

-- A heavenly peach: pink body with a blush top, a crease, a pointed tip and two leaves.
function I.ImmortalPeach(m)
	local c = V(0, 0.3, 0)
	part(m, "Body", "ball", V(0.6, 0.6, 0.6), CFrame.new(c), C(255, 185, 175))
	part(m, "Blush", "ell", V(0.5, 0.36, 0.5), CFrame.new(c + V(0, 0.14, 0)), C(255, 120, 145))
	part(m, "Tip", "ell", V(0.16, 0.24, 0.16), CFrame.new(c + V(0, 0.3, 0)), C(255, 120, 145))
	part(m, "Crease", "ell", V(0.04, 0.5, 0.62), CFrame.new(c + V(0, 0.02, 0)), C(220, 110, 125))
	seg(m, "Stem", c + V(0, 0.24, -0.05), c + V(0, 0.4, -0.1), 0.05, C(110, 80, 50))
	leaf(m, "Leaf", c + V(0, 0.38, -0.1), V(0.9, 0.35, -0.4), 0.3, 0.14, 0.03, C(90, 160, 80))
	leaf(m, "Leaf", c + V(0, 0.38, -0.1), V(-0.9, 0.3, -0.5), 0.26, 0.12, 0.03, C(80, 145, 72))
	end

local ITEM_ORDER = {
	"MarrowWashingPill", "RootRebirthPill", "LesserSpiritCore", "GreaterSpiritCore",
	"HeavenlyDew", "CloudPatternJade", "ImmortalPeach",
}
local ITEM_REASON = {
	MarrowWashingPill = "light pass: parts; needs a moulded pill with a spiral pattern and a glow vfx",
	RootRebirthPill = "light pass: parts; needs a moulded pill with a taiji pattern and a glow vfx",
	LesserSpiritCore = "light pass: parts; needs a cut-gem mesh and an inner pulse vfx",
	GreaterSpiritCore = "light pass: parts; needs a cut-gem mesh and an inner pulse vfx",
	HeavenlyDew = "light pass: parts; needs a droplet mesh and a shimmer vfx",
	CloudPatternJade = "light pass: parts; needs a real bi disc (pierced) with carved cloud relief",
	ImmortalPeach = "light pass: parts; needs a modelled peach and a soft heavenly glow vfx",
}

-- ---------------------------------------------------------------- build

return function()
	local rec = ChangeHistoryService:TryBeginRecording("BuildHerbItemModels")
	local function folder(name)
		local old = ReplicatedStorage:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		local f = Instance.new("Folder")
		f.Name = name
		return f
	end
	local herbs = folder("HerbModelsExtra")
	for _, id in HERB_ORDER do
		local m = newModel(id, HERB_REASON[id])
		H[id](m)
		finish(m, herbs)
	end
	local items = folder("ItemModels")
	for _, id in ITEM_ORDER do
		local m = newModel(id, ITEM_REASON[id])
		I[id](m)
		finish(m, items)
	end
	herbs.Parent = ReplicatedStorage
	items.Parent = ReplicatedStorage
	if rec then
		ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
	end
	local counts = {}
	for _, f in { herbs, items } do
		for _, m in f:GetChildren() do
			table.insert(counts, `{m.Name}={#m:GetChildren()}`)
		end
	end
	return table.concat(counts, " ")
end
