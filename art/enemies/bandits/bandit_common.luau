--!nocheck
-- Shared helpers for the human bandit roster (Mountain Bandit, Bandit Archer, Bandit
-- Chief). Loaded by each build script through the local art server:
--   local B = loadstring(HttpService:GetAsync(BASE .. "bandits/bandit_common.luau"))()
-- Each build clones Workspace.Rig (standard R6: part and Motor6D names untouched), strips
-- its scripts and appearance, puts the HRP at (0, 3, 0) with identity rotation, then
-- dresses it with Studio-built parts and cleaned gear from ServerStorage._RosterBandits._Gear.
--
-- Model space at rest (before any ScaleTo): ground Y=0, facing -Z, the bandit's left is -X.
--   Torso (0,3,0) 2x2x1   Head (0,4.5,0) part 2x1x1, visible head ~1.25 cube (Head mesh)
--   Left Arm (-1.5,3,0)   Right Arm (1.5,3,0)   Left Leg (-0.5,1,0)   Right Leg (0.5,1,0)
-- Detail parts are positioned in this rest space and carry a `Segment` attribute naming
-- the R6 part they're welded to (a Weld, so the R6 Animation Editor carries them).
-- Parts with the `Tell` attribute are the windup-flare parts (eyes, markings).

local ServerStorage = game:GetService("ServerStorage")

local B = {}
B.STAGING = "_RosterBandits"

local function v(x, y, z)
	return Vector3.new(x, y, z)
end
B.v = v

function B.staging()
	local f = ServerStorage:FindFirstChild(B.STAGING)
	if not f then
		f = Instance.new("Folder")
		f.Name = B.STAGING
		f.Parent = ServerStorage
	end
	return f
end

-- A fresh R6 body named `name`, at rest pose, appearance stripped.
function B.new(name, skin, colors)
	local rig = workspace.Rig:Clone()
	rig.Name = name
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") or d:IsA("HumanoidDescription")
			or d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal")
			or (d:IsA("ObjectValue") and d.Name == "AnimSaves") then
			d:Destroy()
		end
	end
	rig.PrimaryPart = rig.HumanoidRootPart
	rig:PivotTo(CFrame.new(0, 3, 0))
	local bc = Instance.new("BodyColors")
	bc.HeadColor3 = skin
	bc.TorsoColor3 = colors.torso or skin
	bc.LeftArmColor3 = colors.arms or skin
	bc.RightArmColor3 = colors.arms or skin
	bc.LeftLegColor3 = colors.legs or skin
	bc.RightLegColor3 = colors.legs or skin
	bc.Parent = rig
	-- BodyColors only applies at runtime; colour the parts too so Edit mode matches.
	rig.Head.Color = bc.HeadColor3
	rig.Torso.Color = bc.TorsoColor3
	rig["Left Arm"].Color = bc.LeftArmColor3
	rig["Right Arm"].Color = bc.RightArmColor3
	rig["Left Leg"].Color = bc.LeftLegColor3
	rig["Right Leg"].Color = bc.RightLegColor3
	for _, p in rig:GetChildren() do
		if p:IsA("BasePart") then
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	local ctx = { model = rig, count = 0 }
	return ctx
end

-- Parts ------------------------------------------------------------------------------

function B.add(ctx, seg, name, class, size, cf, color, material)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Segment", seg)
	p.Parent = ctx.model
	ctx.count += 1
	return p
end

function B.block(ctx, seg, name, size, pos, color, rot, material)
	return B.add(ctx, seg, name, "Part", size, CFrame.new(pos) * (rot or CFrame.identity), color, material)
end

function B.ball(ctx, seg, name, d, pos, color, material)
	local p = B.add(ctx, seg, name, "Part", v(d, d, d), CFrame.new(pos), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A cylinder from a to b, diameter d.
function B.cyl(ctx, seg, name, a, b, d, color, material)
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local p = B.add(ctx, seg, name, "Part", v((b - a).Magnitude, d, d), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A block from a to b (Z along the bone), w wide and d deep, padded past both ends.
function B.limb(ctx, seg, name, a, b, w, d, color, pad, material)
	local dir = (b - a).Unit
	local up = if math.abs(dir.Y) > 0.7 then v(0, 0, -1) else Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up)
	return B.add(ctx, seg, name, "Part", v(w, d, (b - a).Magnitude + (pad or 0)), cf, color, material)
end

-- A wedge fin rising h from base: vertical face at the back, slope at the front.
-- pitch leans it back (+) or flips it down (~pi); roll + tilts it to -X; yaw turns it.
function B.fin(ctx, seg, name, base, h, depth, thick, color, pitch, roll, yaw)
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0) * CFrame.Angles(pitch or 0, 0, roll or 0)
		* CFrame.new(0, h / 2, 0)
	return B.add(ctx, seg, name, "WedgePart", v(thick, h, depth), cf, color)
end

-- An isosceles triangle (two wedges back to back), h tall and w wide, in the frame's XY.
function B.tri(ctx, seg, name, base, h, w, thick, color, tilt)
	local frame = CFrame.new(base) * (tilt or CFrame.identity)
	local a = B.add(ctx, seg, name, "WedgePart", v(thick, h, w / 2),
		frame * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
	B.add(ctx, seg, name .. "B", "WedgePart", v(thick, h, w / 2),
		frame * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
	return a
end

-- A sloped edge along Z: vertical face toward the midline, slope out to side s.
function B.bevel(ctx, seg, name, pos, w, h, len, s, color)
	return B.add(ctx, seg, name, "WedgePart", v(len, h, w), CFrame.new(pos) * CFrame.Angles(0, -s * math.pi / 2, 0), color)
end

-- A cone-ish ring of n wedges around a vertical axis (hats, plumes): radius r at the
-- rim, rising h to the apex. Built as n thin wedge slices.
function B.cone(ctx, seg, name, centre, r, h, n, color)
	local slices = {}
	local w = 2 * r * math.tan(math.pi / n) + 0.02
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		-- a wedge whose slope runs from the rim (low) up to the axis (high)
		local cf = CFrame.new(centre) * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2, -r / 2)
			* CFrame.Angles(0, math.pi, 0)
		slices[i] = B.add(ctx, seg, name .. i, "WedgePart", v(w, h, r), cf, color)
	end
	return slices
end

-- A cleaned accessory from _Gear, attached at the character attachment of the same name
-- (or `att` on the segment) with an AccessoryWeld; `adjust` offsets it in the handle frame.
function B.accessory(ctx, gearName, seg, att, adjust, color, keepTexture)
	local src = B.staging()._Gear:FindFirstChild(gearName)
	assert(src, "missing gear " .. gearName)
	local acc = src:Clone()
	local handle = acc.Handle
	local accAtt = handle:FindFirstChildWhichIsA("Attachment")
	local part = ctx.model[seg]
	local charAtt = part:FindFirstChild(att or accAtt.Name)
	handle.CFrame = charAtt.WorldCFrame * (adjust or CFrame.identity) * accAtt.CFrame:Inverse()
	if color then
		handle.Color = color
	end
	local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
	if mesh and not keepTexture then
		mesh.TextureId = ""
	end
	handle.Material = Enum.Material.SmoothPlastic
	handle:SetAttribute("Segment", seg)
	acc.Parent = ctx.model
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = handle.CFrame:Inverse() * part.CFrame
	weld.C1 = CFrame.identity
	weld.Parent = handle
	ctx.count += 1
	return acc
end

-- A weapon cloned from ServerStorage.WeaponModels, gripped in the right (or left) hand
-- through its own Hilt Motor6D (so animations can swing it). The original is untouched.
function B.weapon(ctx, weaponName, arm, rest)
	local src = ServerStorage.WeaponModels[weaponName]
	local w = src:Clone()
	local armPart = ctx.model[arm or "Right Arm"]
	local hiltName = w.PrimaryPart.Name
	local motor = w.PrimaryPart:FindFirstChildWhichIsA("Motor6D")
	assert(motor, "weapon has no hilt motor")
	motor.Part0 = armPart
	local hiltCF = armPart.CFrame * motor.C0 * (rest or CFrame.identity) * motor.C1:Inverse()
	w:PivotTo(hiltCF * w.PrimaryPart.CFrame:Inverse() * w:GetPivot())
	for _, p in w:GetDescendants() do
		if p:IsA("BasePart") and p ~= w.PrimaryPart then
			p:SetAttribute("Segment", hiltName)
		end
	end
	w.Parent = ctx.model
	return w
end

-- Finish ----------------------------------------------------------------------------

-- Weld every detail part to its segment, set the enemy contract and park the model in
-- staging (replacing an older build of the same name).
function B.finish(ctx, opts)
	local model = ctx.model
	opts = opts or {}
	local hrp = model.HumanoidRootPart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= hrp then
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.CastShadow = true
			local seg = p:GetAttribute("Segment")
			if seg and not p:FindFirstChild("AccessoryWeld") and not p:FindFirstChildWhichIsA("WeldConstraint")
				and p.Parent == model then
				local s = model[seg]
				local weld = Instance.new("Weld")
				weld.Name = "Weld"
				weld.Part0 = s
				weld.Part1 = p
				weld.C0 = s.CFrame:Inverse() * p.CFrame
				weld.Parent = p
			end
		end
	end
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.CanTouch = false
	hrp.Anchored = false
	hrp.Massless = false

	local hum = model.Humanoid
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.HipHeight = 0 -- R6 stands on its legs; HipHeight stays 0
	hum.BreakJointsOnDeath = false

	local bar = ServerStorage.Enemies.SpiritWolf.HumanoidRootPart.HealthBar:Clone()
	bar.StudsOffset = Vector3.new(0, opts.barOffset or 3.4, 0)
	bar.Parent = hrp

	if opts.scale and opts.scale ~= 1 then
		model:ScaleTo(opts.scale)
	end
	-- the HRP sits at its spawn height with the feet on Y=0, identity rotation
	local feet = 3 * (opts.scale or 1)
	model:PivotTo(CFrame.new(0, feet, 0))
	model.WorldPivot = hrp.CFrame
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for k, val in opts.attributes or {} do
		model:SetAttribute(k, val)
	end

	for _, d in model:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "script left in " .. d:GetFullName())
	end
	local staging = B.staging()
	local old = staging:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = staging
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return ("%s: %d parts, %.2f tall, HRP Y %.2f"):format(model.Name, parts, model:GetExtentsSize().Y, hrp.Position.Y)
end

return B
