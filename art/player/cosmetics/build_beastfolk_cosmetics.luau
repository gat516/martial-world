--!nocheck
-- Beast Folk race looks: rigged Accessory prototypes for the four Beast Folk
-- variants (Wolf, Tiger, Crane, Serpent), in the fox set's shape language.
-- Run in Edit mode through the Studio MCP (execute_luau, or loadstring from the
-- served worktree). It (re)builds ReplicatedStorage.Cosmetics.BeastFolk (a Folder
-- of 8 Accessories); nothing else. Export that folder to
-- assets/Cosmetics/BeastFolk.rbxm with tools/export_rbxm.luau.
--
-- Space (as build_fox_cosmetics.luau): each accessory is built in its Handle's
-- space (Handle at the origin, identity rotation). The character faces -Z, its
-- left is -X, +Y is up.
--   Head pieces (HatAttachment): Handle origin = the R6 Head's HatAttachment
--     (0.6 above the head centre; the head top is at -0.1, normal hair box tops ~0.27).
--   SerpentScales (FaceFrontAttachment): Handle origin = the R6 Head's
--     FaceFrontAttachment (the face, 0.6 in front of the head centre).
--   Tails (WaistBackAttachment): Handle origin = the lower back surface; the
--     tail runs out along +Z. The legs hang below Y 0 between Z -1 and 0 and swing
--     about the hip (Y 0, Z -0.5); tails keep clear of a 1 rad swing.
-- Joints are Motor6Ds whose frames are identity in Handle space at rest, so
-- Transform rotates about the character's axes: X pitches, Y yaws, Z rolls.
-- Part and joint names follow the fox set (LeftEar/RightEar + EarL/EarR,
-- TailSeg<i> + Tail<i>), so one ear-twitch or tail-wag clip can drive any race.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Palette ---------------------------------------------------------------------
local WOLF_GREY = Color3.fromRGB(116, 120, 130)
local WOLF_CHAR = Color3.fromRGB(50, 52, 58)
local WOLF_PALE = Color3.fromRGB(240, 224, 202) -- warm cream: a cooler pale shades to backdrop grey
local TIGER_ORANGE = Color3.fromRGB(226, 128, 36)
local TIGER_BLACK = Color3.fromRGB(28, 24, 22)
local TIGER_WHITE = Color3.fromRGB(246, 240, 228)
local CRANE_RED = Color3.fromRGB(196, 36, 40)
local CRANE_WHITE = Color3.fromRGB(244, 242, 236)
local CRANE_BLACK = Color3.fromRGB(30, 30, 34)
local JADE = Color3.fromRGB(62, 156, 104)
local JADE_DARK = Color3.fromRGB(26, 84, 58)
local JADE_LIGHT = Color3.fromRGB(110, 190, 138)

-- Wolf ears: a touch taller than the fox's (0.6 x 1.25) and upright, grey (narrower read as horns)
local WOLF_EAR = { x = 0.34, y = -0.15, z = 0.05, w = 0.6, h = 1.3, t = 0.17, tilt = math.rad(5), back = math.rad(6) }
local WOLF_INNER_W, WOLF_INNER_H = 0.38, 0.8
local WOLF_TIP_H = 0.26
-- Wolf tail: bushy, arcs out level then hangs down behind the leg swing,
-- charcoal tip; pale underside strips. The stock R6 walk swings the legs back to
-- Z ~1.5 at hip height, so every tail stays above Y 0 until Z ~1.6.
local WOLF_SPINE = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 0.34, 0.42),
	Vector3.new(0, 0.5, 0.95),
	Vector3.new(0, 0.38, 1.5),
	Vector3.new(0, -0.1, 1.98),
	Vector3.new(0, -0.68, 2.2),
}
local WOLF_TAIL_D = { 0.5, 0.86, 1.0, 0.92, 0.66 }
local WOLF_TAIL_COL = { WOLF_GREY, WOLF_GREY, WOLF_GREY, WOLF_GREY, WOLF_GREY }
local WOLF_TAIL_OVERLAP = 2.4 -- lower than the fox's 3.2 so the lobes read as a bushy brush, not one slab

-- Tiger ears: short round discs on a stem, black rim, white spot on the back
-- (high on the disc, above the hair line seen from behind)
local TIGER_EAR = { x = 0.42, y = -0.15, z = 0.05, r = 0.26, cy = 0.42, t = 0.18, tilt = math.rad(12), back = math.rad(4) }
-- Tiger tail: long and slim, S-curve with the tip lifting; black bands, black tip
local TIGER_SPINE = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 0.14, 0.5),
	Vector3.new(0, 0.22, 1.05),
	Vector3.new(0, 0.14, 1.62),
	Vector3.new(0, -0.12, 2.14),
	Vector3.new(0, -0.18, 2.66),
	Vector3.new(0, 0.12, 3.08),
	Vector3.new(0, 0.6, 3.3),
}
local TIGER_TAIL_D = { 0.3, 0.34, 0.33, 0.31, 0.3, 0.28, 0.26 }
local TIGER_BANDS = { 0.6, 0.6, 0.55, 0.5, 0.6 } -- band k sits this far along segment k+1

-- Crane crest: red crown bulb, three white plumes with black tips, two black
local CRANE_CROWN = { pos = Vector3.new(0, 0.18, 0.02), size = Vector3.new(0.86, 0.5, 0.9) } -- a flat cap pressed into the hair
local CRANE_PLUME_ROOT = Vector3.new(0, 0.36, 0.14)
-- { yaw deg, pitch deg above horizontal (toward +Z), length, colour, tipped }
local CRANE_PLUMES = {
	{ 0, 32, 1.35, CRANE_WHITE, true },
	{ -15, 24, 1.12, CRANE_WHITE, true },
	{ 15, 24, 1.12, CRANE_WHITE, true },
	{ -7, 42, 0.82, CRANE_BLACK, false },
	{ 7, 42, 0.82, CRANE_BLACK, false },
}
-- Crane tail: a short drooping fan of white feathers with black tips
local CRANE_RUMP = { pos = Vector3.new(0, 0.12, 0.2), size = Vector3.new(0.7, 0.48, 0.7) }
local CRANE_FAN_ROOT = Vector3.new(0, 0.14, 0.24)
local CRANE_FAN = { -50, -25, 0, 25, 50 } -- yaw per feather; outer ones also lift so the fan shows from behind
local CRANE_FAN_PITCH = math.rad(-6) -- negative lifts: a droop runs into the walk's leg swing
local CRANE_FEATHER_W, CRANE_FEATHER_T = 0.36, 0.1
local CRANE_FEATHER_LEN = 1.6

-- Serpent scales: diamonds flat on the head's side wall (radius ~0.62)
local HEAD_R = 0.62
-- { angle from the front (deg, + = character's right), height from head centre, size }
local SERPENT_SCALES = {
	{ 58, 0.24, 0.16 },
	{ 70, 0.12, 0.13 },
	{ 52, 0.06, 0.11 },
	{ 50, -0.2, 0.14 },
	{ 62, -0.3, 0.11 },
}
-- Serpent tail: long and tapering, droops behind, tip curls to the right
local SERPENT_SPINE = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 0.16, 0.5),
	Vector3.new(0, 0.16, 1.05),
	Vector3.new(0, -0.02, 1.62),
	Vector3.new(0.06, -0.5, 2.06),
	Vector3.new(0.22, -0.9, 2.56),
	Vector3.new(0.5, -1.06, 3.06),
	Vector3.new(0.86, -1.0, 3.46),
}
local SERPENT_TAIL_D = { 0.46, 0.44, 0.4, 0.35, 0.29, 0.22, 0.15 }

local TAIL_OVERLAP = 3.2 -- ellipsoid length / segment length (fox value)
local SLIM_OVERLAP = 1.9 -- tiger and serpent: slimmer, so less overlap keeps the taper
---------------------------------------------------------------------------

local function style(p, color)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = color
	return p
end

local function weld(p0, p1)
	local w = Instance.new("Weld")
	w.Name = "Weld_" .. p1.Name
	w.Part0, w.Part1 = p0, p1
	w.C0 = p0.CFrame:Inverse() * p1.CFrame
	w.C1 = CFrame.identity
	w.Parent = p1
end

local function motor(name, p0, p1, pivot)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = p0, p1
	m.C0 = p0.CFrame:Inverse() * CFrame.new(pivot)
	m.C1 = p1.CFrame:Inverse() * CFrame.new(pivot)
	m.Parent = p0
	return m
end

local function accessory(name, kind, attName, parent)
	local acc = Instance.new("Accessory")
	acc.Name = name
	acc.AccessoryType = kind
	local h = style(Instance.new("Part"), Color3.new(1, 1, 1))
	h.Name = "Handle"
	h.Size = Vector3.new(0.2, 0.2, 0.2)
	h.Transparency = 1
	h.CastShadow = false
	h.CFrame = CFrame.identity
	h.Parent = acc
	local att = Instance.new("Attachment")
	att.Name = attName
	att.Parent = h
	acc.Parent = parent
	return acc, h
end

-- Isosceles triangle in its frame's XY plane (base on y=0, apex at y=h), from
-- two wedges back to back (fox helper): each wedge's tall +Z face meets the
-- centre line.
local function triangle(name, frame, w, h, t, color, parent)
	local halves = {}
	for i, s in { 1, -1 } do
		local p = style(Instance.new("WedgePart"), color)
		p.Name = name .. (i == 1 and "" or "B")
		p.Size = Vector3.new(t, h, w / 2)
		p.CFrame = frame * CFrame.fromMatrix(Vector3.new(s * w / 4, h / 2, 0), Vector3.new(0, 0, s), Vector3.new(0, 1, 0), Vector3.new(-s, 0, 0))
		p.Parent = parent
		halves[i] = p
	end
	return halves
end

local function ellipsoid(name, cf, size, color, parent)
	local p = style(Instance.new("Part"), color)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	local mesh = Instance.new("SpecialMesh") -- fills the box; ScaleTo scales it with the part
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

local function cylinderZ(name, cf, thick, dia, color, parent)
	-- a disc whose flat faces look along the frame's Z (Cylinder parts run along X)
	local p = style(Instance.new("Part"), color)
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thick, dia, dia)
	p.CFrame = cf * CFrame.Angles(0, math.pi / 2, 0)
	p.Parent = parent
	return p
end

-- A tail chain: segment i spans spine[i]..spine[i+1], hinged at spine[i].
local function tailChain(acc, handle, spine, diam, colors, overlap)
	local segs, prev = {}, handle
	for i = 1, #diam do
		local a, b = spine[i], spine[i + 1]
		local p = ellipsoid("TailSeg" .. i, CFrame.lookAt((a + b) / 2, b), Vector3.new(diam[i], diam[i], (b - a).Magnitude * overlap), colors[i], acc)
		motor("Tail" .. i, prev, p, a)
		segs[i], prev = p, p
	end
	return segs
end

local root = ReplicatedStorage:FindFirstChild("Cosmetics")
if not root then
	root = Instance.new("Folder")
	root.Name = "Cosmetics"
	root.Parent = ReplicatedStorage
end
local old = root:FindFirstChild("BeastFolk")
if old then
	old:Destroy()
end
local set = Instance.new("Folder")
set.Name = "BeastFolk"

local function dirFrom(yawDeg, pitchDeg, droop)
	local yaw, pitch = math.rad(yawDeg), math.rad(pitchDeg)
	local up = droop and -1 or 1
	return Vector3.new(math.sin(yaw) * math.cos(pitch), up * math.sin(pitch), math.cos(yaw) * math.cos(pitch))
end

-- WolfEars ---------------------------------------------------------------------
do
	local acc, handle = accessory("WolfEars", Enum.AccessoryType.Hat, "HatAttachment", set)
	local E = WOLF_EAR
	for _, side in { { "L", -1, "LeftEar" }, { "R", 1, "RightEar" } } do
		local tag, s, partName = side[1], side[2], side[3]
		local base = CFrame.new(s * E.x, E.y, E.z) * CFrame.Angles(E.back, 0, -s * E.tilt)
		local outer = triangle(partName, base, E.w, E.h, E.t, WOLF_GREY, acc)
		local primary = outer[1]
		weld(primary, outer[2])
		local innerFrame = base * CFrame.new(0, 0.1, -E.t / 2 - 0.012)
		for _, p in triangle(partName .. "Inner", innerFrame, WOLF_INNER_W, WOLF_INNER_H, 0.05, WOLF_PALE, acc) do
			weld(primary, p)
		end
		local tipW = E.w * (WOLF_TIP_H / E.h) * 1.18
		local tipFrame = base * CFrame.new(0, E.h - WOLF_TIP_H, 0)
		for _, p in triangle(partName .. "Tip", tipFrame, tipW, WOLF_TIP_H + 0.04, E.t + 0.04, WOLF_CHAR, acc) do
			weld(primary, p)
		end
		motor("Ear" .. tag, handle, primary, base.Position)
	end
end

-- WolfTail ---------------------------------------------------------------------
do
	local acc, handle = accessory("WolfTail", Enum.AccessoryType.Waist, "WaistBackAttachment", set)
	local segs = tailChain(acc, handle, WOLF_SPINE, WOLF_TAIL_D, WOLF_TAIL_COL, WOLF_TAIL_OVERLAP)
	-- pale underside: a slimmer ellipsoid pushed toward the segment's underside
	for i = 3, 5 do
		local seg, d = segs[i], WOLF_TAIL_D[i]
		local p = ellipsoid("TailBelly" .. i, seg.CFrame * CFrame.new(0, -d * 0.24, 0.02), Vector3.new(d * 0.8, d * 0.62, seg.Size.Z * 0.86), WOLF_PALE, acc)
		weld(seg, p)
	end
end

-- TigerEars --------------------------------------------------------------------
do
	local acc, handle = accessory("TigerEars", Enum.AccessoryType.Hat, "HatAttachment", set)
	local E = TIGER_EAR
	for _, side in { { "L", -1, "LeftEar" }, { "R", 1, "RightEar" } } do
		local tag, s, partName = side[1], side[2], side[3]
		local base = CFrame.new(s * E.x, E.y, E.z) * CFrame.Angles(E.back, 0, -s * E.tilt)
		local centre = base * CFrame.new(0, E.cy, 0)
		local disc = cylinderZ(partName, centre, E.t, E.r * 2, TIGER_ORANGE, acc)
		local stem = style(Instance.new("Part"), TIGER_ORANGE)
		stem.Name = partName .. "Stem"
		stem.Size = Vector3.new(0.38, E.cy + 0.04, E.t - 0.02)
		stem.CFrame = base * CFrame.new(0, (E.cy + 0.04) / 2 - 0.02, 0)
		stem.Parent = acc
		weld(disc, stem)
		weld(disc, cylinderZ(partName .. "Rim", centre, E.t - 0.06, E.r * 2 + 0.12, TIGER_BLACK, acc))
		weld(disc, cylinderZ(partName .. "Inner", base * CFrame.new(0, E.cy - 0.05, -E.t / 2 - 0.01), 0.04, 0.34, TIGER_WHITE, acc))
		weld(disc, cylinderZ(partName .. "Spot", base * CFrame.new(0, E.cy + 0.08, E.t / 2 + 0.01), 0.05, 0.3, TIGER_WHITE, acc))
		motor("Ear" .. tag, handle, disc, base.Position)
	end
end

-- TigerTail --------------------------------------------------------------------
do
	local acc, handle = accessory("TigerTail", Enum.AccessoryType.Waist, "WaistBackAttachment", set)
	local cols = table.create(#TIGER_TAIL_D, TIGER_ORANGE)
	cols[#cols] = TIGER_BLACK
	local segs = tailChain(acc, handle, TIGER_SPINE, TIGER_TAIL_D, cols, SLIM_OVERLAP)
	for k, f in TIGER_BANDS do
		local i = k + 1
		local a, b = TIGER_SPINE[i], TIGER_SPINE[i + 1]
		local at = a:Lerp(b, f)
		local d = TIGER_TAIL_D[i] + 0.06
		weld(segs[i], ellipsoid("TailBand" .. k, CFrame.lookAt(at, b), Vector3.new(d, d, 0.16), TIGER_BLACK, acc))
	end
end

-- CraneCrest -------------------------------------------------------------------
do
	local acc, handle = accessory("CraneCrest", Enum.AccessoryType.Hat, "HatAttachment", set)
	local crown = ellipsoid("Crown", CFrame.new(CRANE_CROWN.pos), CRANE_CROWN.size, CRANE_RED, acc)
	weld(handle, crown)
	local primary
	for i, pl in CRANE_PLUMES do
		local dir = dirFrom(pl[1], pl[2], false)
		local len = pl[3]
		local a = CRANE_PLUME_ROOT
		local p = ellipsoid(i == 1 and "CrestPlume" or ("CrestPlume" .. i), CFrame.lookAt(a + dir * len / 2, a + dir * len), Vector3.new(0.15, 0.1, len), pl[4], acc)
		if pl[5] then
			local tl = len * 0.32
			local tip = ellipsoid((i == 1 and "CrestPlume" or ("CrestPlume" .. i)) .. "Tip", CFrame.lookAt(a + dir * (len - tl / 2 - 0.02), a + dir * len), Vector3.new(0.17, 0.12, tl), CRANE_BLACK, acc)
			weld(p, tip)
		end
		if i == 1 then
			primary = p
			motor("Plume", handle, p, a)
		else
			weld(primary, p)
		end
	end
end

-- CraneTail --------------------------------------------------------------------
do
	local acc, handle = accessory("CraneTail", Enum.AccessoryType.Waist, "WaistBackAttachment", set)
	local rump = ellipsoid("TailSeg1", CFrame.new(CRANE_RUMP.pos), CRANE_RUMP.size, CRANE_WHITE, acc)
	motor("Tail1", handle, rump, Vector3.zero)
	for i, yaw in CRANE_FAN do
		local len = CRANE_FEATHER_LEN * ((yaw == 0) and 1 or (math.abs(yaw) < 30 and 0.94 or 0.82))
		local pitch = CRANE_FAN_PITCH - math.rad(math.abs(yaw) * 0.5)
		local dir = Vector3.new(math.sin(math.rad(yaw)) * math.cos(pitch), -math.sin(pitch), math.cos(math.rad(yaw)) * math.cos(pitch))
		local a = CRANE_FAN_ROOT
		local f = ellipsoid("TailFeather" .. i, CFrame.lookAt(a + dir * len / 2, a + dir * len), Vector3.new(CRANE_FEATHER_W, CRANE_FEATHER_T, len), CRANE_WHITE, acc)
		local tl = len * 0.34
		weld(f, ellipsoid("TailFeatherTip" .. i, CFrame.lookAt(a + dir * (len - tl / 2), a + dir * len), Vector3.new(CRANE_FEATHER_W + 0.02, CRANE_FEATHER_T + 0.02, tl), CRANE_BLACK, acc))
		motor("Feather" .. i, rump, f, a)
	end
end

-- SerpentScales ----------------------------------------------------------------
do
	local acc, handle = accessory("SerpentScales", Enum.AccessoryType.Face, "FaceFrontAttachment", set)
	local centre = Vector3.new(0, 0, 0.6) -- head centre in FaceFront space
	for _, s in { -1, 1 } do
		for i, sc in SERPENT_SCALES do
			local phi = math.rad(sc[1]) * s
			local normal = Vector3.new(math.sin(phi), 0, -math.cos(phi))
			local pos = centre + normal * (HEAD_R + 0.005) + Vector3.new(0, sc[2], 0)
			-- block's Z = the normal; rotated 45 deg about it so it reads as a diamond
			local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, math.rad(45))
			local p = style(Instance.new("Part"), (i % 2 == 0) and JADE_LIGHT or JADE)
			p.Name = (s < 0 and "ScaleL" or "ScaleR") .. i
			p.Size = Vector3.new(sc[3], sc[3], 0.05)
			p.CFrame = cf
			p.Parent = acc
			weld(handle, p)
		end
	end
end

-- SerpentTail ------------------------------------------------------------------
do
	local acc, handle = accessory("SerpentTail", Enum.AccessoryType.Waist, "WaistBackAttachment", set)
	local cols = table.create(#SERPENT_TAIL_D, JADE)
	local segs = tailChain(acc, handle, SERPENT_SPINE, SERPENT_TAIL_D, cols, SLIM_OVERLAP)
	-- darker dorsal line along each segment's top
	for i, seg in segs do
		local d = SERPENT_TAIL_D[i]
		weld(seg, ellipsoid("TailDorsal" .. i, seg.CFrame * CFrame.new(0, d * 0.36, 0), Vector3.new(d * 0.36, d * 0.36, seg.Size.Z * 0.86), JADE_DARK, acc))
	end
end

set.Parent = root
local counts = {}
for _, acc in set:GetChildren() do
	local n = 0
	for _, d in acc:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	table.insert(counts, acc.Name .. "=" .. n)
end
table.sort(counts)
return "built BeastFolk: " .. table.concat(counts, " ")
