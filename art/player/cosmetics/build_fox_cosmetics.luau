--!nocheck
-- Fox ears and fox tail: rigged Accessory prototypes for Spirit Fox players.
-- Run in Edit mode through the Studio MCP (execute_luau, paste the file). It
-- (re)builds ServerStorage.Cosmetics.FoxEars and .FoxTail; nothing else.
--
-- Space: each accessory is built in its Handle's space (Handle at the origin,
-- identity rotation). The character faces -Z, its left is -X, +Y is up.
--   FoxEars: Handle origin = the R6 Head's HatAttachment (0.6 above the head
--            centre; the head top is at -0.1 in Handle space).
--   FoxTail: Handle origin = the R6 Torso's WaistBackAttachment (the lower back
--            surface); the tail runs out along +Z (behind the player).
-- Joints are Motor6Ds whose frames are identity in Handle space at rest (C0 and
-- C1 both point at the hinge with no rotation), so Transform rotates about the
-- Handle's axes: X pitches (tail up/down, ear fold back), Y yaws (tail wag), Z
-- rolls (ear flick outward).

local ServerStorage = game:GetService("ServerStorage")

-- Palette (fox orange, cream inner ear, dark ear tips, white tail tip)
local ORANGE = Color3.fromRGB(222, 116, 44)
local CREAM = Color3.fromRGB(250, 222, 188)
local DARK = Color3.fromRGB(58, 34, 26)
local WHITE = Color3.fromRGB(246, 241, 232)

-- Ears (studs, Handle space)
local EAR_X = 0.36 -- base centre, each side of the head's middle
local EAR_Y = -0.15 -- base height: just inside the head top (-0.1), so bald heads hold them too
local EAR_Z = 0.05 -- a little behind the head's middle
local EAR_W = 0.6 -- base width
local EAR_H = 1.25 -- base to tip: clears normal hair (hair box tops ~0.27) by ~0.7
local EAR_T = 0.18 -- thickness
local EAR_TILT = math.rad(13) -- leans outward
local EAR_BACK = math.rad(8) -- leans back
local INNER_W, INNER_H = 0.32, 0.72 -- cream inner ear (front face)
local TIP_H = 0.32 -- dark tip cap, measured down from the tip

-- Tail: a spine of points from the Handle (the lower back) to the tip. Segment i
-- is an ellipsoid from SPINE[i] to SPINE[i+1], stretched past both ends by
-- TAIL_OVERLAP so neighbours blend into one brush, and hinged at SPINE[i].
local SPINE = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, -0.12, 0.50),
	Vector3.new(0, -0.20, 1.05),
	Vector3.new(0, -0.08, 1.60),
	Vector3.new(0, 0.20, 2.05),
	Vector3.new(0, 0.62, 2.40),
}
local TAIL_D = { 0.5, 0.8, 1.0, 0.92, 0.66 } -- thickness per segment
local TAIL_COL = { ORANGE, ORANGE, ORANGE, ORANGE, WHITE } -- the last one is the white tip
local TAIL_OVERLAP = 3.2 -- ellipsoid length / segment length (under ~2.5 the joins read as rings)
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

local function newHandle(parent)
	local h = style(Instance.new("Part"), ORANGE)
	h.Name = "Handle"
	h.Size = Vector3.new(0.2, 0.2, 0.2)
	h.Transparency = 1
	h.CastShadow = false
	h.CFrame = CFrame.identity
	h.Parent = parent
	return h
end

-- An isosceles triangle in its frame's XY plane (base on y=0, apex at y=h),
-- thickness t along Z, built from two wedges back to back. Returns both halves.
local function triangle(name, frame, w, h, t, color, parent)
	local halves = {}
	for i, s in { 1, -1 } do
		local p = style(Instance.new("WedgePart"), color)
		p.Name = name .. (i == 1 and "" or "B")
		p.Size = Vector3.new(t, h, w / 2)
		-- wedge +Z (its tall back edge) points at the triangle's centre line
		p.CFrame = frame * CFrame.fromMatrix(Vector3.new(s * w / 4, h / 2, 0), Vector3.new(0, 0, s), Vector3.new(0, 1, 0), Vector3.new(-s, 0, 0))
		p.Parent = parent
		halves[i] = p
	end
	return halves
end

local folder = ServerStorage:FindFirstChild("Cosmetics")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	folder.Parent = ServerStorage
end
for _, n in { "FoxEars", "FoxTail" } do
	local old = folder:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

-- FoxEars ------------------------------------------------------------------
do
	local acc = Instance.new("Accessory")
	acc.Name = "FoxEars"
	acc.AccessoryType = Enum.AccessoryType.Hat
	local handle = newHandle(acc)
	local att = Instance.new("Attachment")
	att.Name = "HatAttachment"
	att.Parent = handle

	for _, side in { { "L", -1, "LeftEar" }, { "R", 1, "RightEar" } } do
		local tag, s, partName = side[1], side[2], side[3]
		local base = CFrame.new(s * EAR_X, EAR_Y, EAR_Z) * CFrame.Angles(EAR_BACK, 0, -s * EAR_TILT)
		local outer = triangle(partName, base, EAR_W, EAR_H, EAR_T, ORANGE, acc)
		local primary = outer[1]
		weld(primary, outer[2])
		-- cream inner ear, proud of the front face (-Z)
		local innerFrame = base * CFrame.new(0, 0.08, -EAR_T / 2 - 0.012)
		for _, p in triangle(partName .. "Inner", innerFrame, INNER_W, INNER_H, 0.05, CREAM, acc) do
			weld(primary, p)
		end
		-- dark tip cap: slightly bigger than the ear's top so its faces sit outside
		local scale = TIP_H / EAR_H
		local tipW = EAR_W * scale * 1.18
		local tipFrame = base * CFrame.new(0, EAR_H - TIP_H, 0)
		for _, p in triangle(partName .. "Tip", tipFrame, tipW, TIP_H + 0.04, EAR_T + 0.04, DARK, acc) do
			weld(primary, p)
		end
		motor("Ear" .. tag, handle, primary, base.Position)
	end
	acc.Parent = folder
end

-- FoxTail ------------------------------------------------------------------
do
	local acc = Instance.new("Accessory")
	acc.Name = "FoxTail"
	acc.AccessoryType = Enum.AccessoryType.Waist
	local handle = newHandle(acc)
	local att = Instance.new("Attachment")
	att.Name = "WaistBackAttachment"
	att.Parent = handle

	local prev = handle
	for i = 1, #TAIL_D do
		local a, b = SPINE[i], SPINE[i + 1]
		local p = style(Instance.new("Part"), TAIL_COL[i])
		p.Name = "TailSeg" .. i
		p.Size = Vector3.new(TAIL_D[i], TAIL_D[i], (b - a).Magnitude * TAIL_OVERLAP)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		local mesh = Instance.new("SpecialMesh") -- fills the part's box: an ellipsoid that ScaleTo scales with it
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		p.Parent = acc
		motor("Tail" .. i, prev, p, a)
		prev = p
	end
	acc.Parent = folder
end

return "built " .. #folder.FoxEars:GetDescendants() .. " / " .. #folder.FoxTail:GetDescendants() .. " descendants"
