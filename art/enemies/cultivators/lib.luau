--!nocheck
-- Shared builder for the human cultivator roster (R6 enemies). Each model's build
-- script loads this through the art server and calls:
--   local L = loadstring(HttpService:GetAsync(BASE .. "lib.luau"))()
--   local b = L.begin("RogueCultivator")      -- clean R6 rig at the origin
--   b.block("Torso", "RobeTorso", size, pos, color) ...
--   L.finish(b, { healthBarY = 3.2, scale = 1 })
--
-- Model space: ground Y=0, the rig faces -Z, its left is -X. Standard R6 rest:
-- HumanoidRootPart and Torso at (0, 3, 0), Head (0, 4.5, 0), arms at x=+-1.5,
-- y=3, legs at x=+-0.5, y=1. Detail parts carry a `Segment` attribute (the R6
-- part they ride on) and finish() welds them to it with WeldConstraints.
--
-- Gear from the catalog lives in ServerStorage._RosterCultivators._Gear (cleaned
-- of scripts on insert); accessory() clones from there. Weapons are cloned from
-- ServerStorage.WeaponModels and attached the way src/server/Weapons.luau does.

local ServerStorage = game:GetService("ServerStorage")

local L = {}
L.STAGING = "_RosterCultivators"

local SEGMENTS = {
	Torso = true, Head = true, ["Left Arm"] = true, ["Right Arm"] = true,
	["Left Leg"] = true, ["Right Leg"] = true, HumanoidRootPart = true,
}

function L.v(x, y, z)
	return Vector3.new(x, y, z)
end

function L.staging()
	local st = ServerStorage:FindFirstChild(L.STAGING)
	if not st then
		st = Instance.new("Folder")
		st.Name = L.STAGING
		st.Parent = ServerStorage
	end
	return st
end

-- Clone Workspace.Rig into a clean R6 enemy body at the origin.
function L.begin(name, opts)
	opts = opts or {}
	local rig = workspace:FindFirstChild("Rig"):Clone()
	rig.Name = name
	-- strip everything that isn't body: the Animate script, animation saves,
	-- the HumanoidDescription and BodyColors (which would repaint the parts),
	-- the default face and torso decals
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("HumanoidDescription") or d:IsA("BodyColors")
			or d.Name == "AnimSaves" or (d:IsA("Decal") and d.Parent and d.Parent:IsA("BasePart")) then
			d:Destroy()
		end
	end
	for _, c in rig:GetChildren() do
		if c:IsA("Accessory") or c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
			c:Destroy()
		end
	end
	rig:PivotTo(CFrame.identity)
	rig.PrimaryPart = rig.HumanoidRootPart
	local b = { model = rig, parts = {} }
	local skin = opts.skin or Color3.fromHex("E8B98F")
	for _, n in { "Head", "Left Arm", "Right Arm" } do
		rig[n].Color = skin
	end
	rig.Torso.Color = opts.torso or Color3.fromHex("333333")
	rig["Left Leg"].Color = opts.legs or Color3.fromHex("2A2522")
	rig["Right Leg"].Color = opts.legs or Color3.fromHex("2A2522")

	local function add(seg, name, class, size, cf, color, material)
		assert(SEGMENTS[seg], "unknown segment " .. tostring(seg))
		local p = Instance.new(class)
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Segment", seg)
		p.Parent = rig
		table.insert(b.parts, p)
		return p
	end
	b.add = add
	function b.block(seg, name, size, pos, color, rot, material)
		return add(seg, name, "Part", size, CFrame.new(pos) * (rot or CFrame.identity), color, material)
	end
	function b.ball(seg, name, d, pos, color, material)
		local p = add(seg, name, "Part", Vector3.new(d, d, d), CFrame.new(pos), color, material)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- a cylinder standing upright (its axis along Y), d across and h tall
	function b.cyl(seg, name, d, h, pos, color, rot, material)
		local p = add(seg, name, "Part", Vector3.new(h, d, d),
			CFrame.new(pos) * (rot or CFrame.identity) * CFrame.Angles(0, 0, math.pi / 2), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- a block from a to b (Z along the bone), w wide and d deep, padded past both ends
	function b.limb(seg, name, a, c, w, d, color, pad)
		local dir = (c - a).Unit
		local up = if math.abs(dir.Y) > 0.7 then Vector3.new(0, 0, -1) else Vector3.yAxis
		local cf = CFrame.lookAt((a + c) / 2, c, up)
		return add(seg, name, "Part", Vector3.new(w, d, (c - a).Magnitude + (pad or 0)), cf, color)
	end
	-- a wedge fin rising h from base: vertical face at the back, slope at the front.
	-- pitch leans it back (+) or flips it down (~pi); roll + tilts it to -X; yaw turns it.
	function b.fin(seg, name, base, h, depth, thick, color, pitch, roll, yaw)
		local cf = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0) * CFrame.Angles(pitch or 0, 0, roll or 0)
			* CFrame.new(0, h / 2, 0)
		return add(seg, name, "WedgePart", Vector3.new(thick, h, depth), cf, color)
	end
	-- an isosceles triangle (two wedges back to back) facing forward, h tall and w wide
	function b.tri(seg, name, base, h, w, thick, color, tilt)
		local frame = CFrame.new(base) * (tilt or CFrame.identity)
		local a = add(seg, name, "WedgePart", Vector3.new(thick, h, w / 2),
			frame * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
		add(seg, name .. "B", "WedgePart", Vector3.new(thick, h, w / 2),
			frame * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
		return a
	end
	-- a sloped shoulder along Z: vertical face toward the midline, slope out to side s
	function b.bevel(seg, name, pos, w, h, len, s, color)
		return add(seg, name, "WedgePart", Vector3.new(len, h, w),
			CFrame.new(pos) * CFrame.Angles(0, -s * math.pi / 2, 0), color)
	end
	-- a shallow cone of n radial wedges (a douli or a crown top), apex up at top
	function b.cone(seg, name, center, radius, h, n, color, tilt)
		local frame = CFrame.new(center) * (tilt or CFrame.identity)
		local w = 2 * radius * math.tan(math.pi / n) + 0.04
		local first
		for i = 1, n do
			local yaw = (i - 1) / n * math.pi * 2
			-- a WedgePart's tall face is at +Z, so it spans from the centre out to -Z
			local p = add(seg, name .. (i == 1 and "" or tostring(i)), "WedgePart", Vector3.new(w, h, radius),
				frame * CFrame.Angles(0, yaw, 0) * CFrame.new(0, h / 2, -radius / 2), color)
			first = first or p
		end
		return first
	end
	return b
end

-- The shared robe. A robe skirt mustn't block the legs, so it's split: a short
-- hip band welded to the Torso (above the leg swing) and a robe tube with a
-- flared hem welded to each leg, so each leg carries its own half of the skirt.
--   o.outer, o.trim, o.inner, o.sash: colours
--   o.hipLen: hip band length below the waist (default 0.65)
--   o.hem: Y where the leg robes end (default 0.55; 0.2 for a floor-length robe)
--   o.sleeve: "narrow" (default) or "wide"; o.sleeveColor, o.cuff colours
--   o.lapel: false to skip the crossed collar
function L.robe(b, o)
	local v = L.v
	local outer, trim, inner = o.outer, o.trim or o.outer, o.inner or o.trim or o.outer
	b.block("Torso", "RobeTorso", v(2.14, 2.06, 1.14), v(0, 3, 0), outer)
	if o.lapel ~= false then
		-- wearer's left (-X) over right: the outer lapel runs from the left of the
		-- neck down to the right hip; the inner one shows at the right of the neck
		b.limb("Torso", "LapelOuter", v(-0.42, 4.0, -0.6), v(0.62, 2.45, -0.6), 0.32, 0.06, trim, 0.15)
		b.limb("Torso", "LapelInner", v(0.42, 4.0, -0.595), v(0.08, 3.35, -0.595), 0.26, 0.05, trim, 0.1)
		b.block("Torso", "Underrobe", v(0.62, 0.42, 0.05), v(0.02, 3.82, -0.585), inner)
		b.block("Torso", "CollarBack", v(1.1, 0.2, 0.5), v(0, 4.0, 0.36), trim)
	end
	if o.sash then
		b.block("Torso", "Sash", v(2.2, 0.42, 1.2), v(0, 2.3, 0), o.sash)
	end
	local hipLen = o.hipLen or 0.65
	b.block("Torso", "HipBand", v(2.24, hipLen + 0.12, 1.3), v(0, 2.06 - hipLen / 2, 0), outer)
	local hem = o.hem or 0.55
	for _, s in { -1, 1 } do
		local leg = if s < 0 then "Left Leg" else "Right Leg"
		local top = 1.75
		b.block(leg, "LegRobe", v(1.1, top - hem, 1.2), v(s * 0.5, (top + hem) / 2, 0), outer)
		b.block(leg, "LegHem", v(1.2, 0.22, 1.3), v(s * 0.5 + s * 0.03, hem + 0.06, 0), trim)
		local arm = if s < 0 then "Left Arm" else "Right Arm"
		local sc = o.sleeveColor or outer
		b.block(arm, "SleeveUpper", v(1.14, 1.25, 1.14), v(s * 1.5, 3.4, 0), sc)
		if o.sleeve == "wide" then
			b.block(arm, "SleeveWide", v(1.34, 1.3, 1.75), v(s * 1.52, 2.5, 0.08), sc)
			b.block(arm, "SleeveCuff", v(1.38, 0.16, 1.79), v(s * 1.52, 1.86, 0.08), o.cuff or trim)
		else
			b.block(arm, "SleeveLower", v(1.2, 0.72, 1.2), v(s * 1.5, 2.58, 0), sc)
			b.block(arm, "SleeveCuff", v(1.24, 0.16, 1.24), v(s * 1.5, 2.22, 0), o.cuff or trim)
		end
	end
end

-- Eyes and brows on the front of the R6 head mesh. o.eye colour, o.neon (eyes are
-- tell parts named TellEyeL/R), o.brow colour, o.scowl (brow tilt, radians).
L.FACE_Z = -0.6
function L.face(b, o)
	local v = L.v
	local z = L.FACE_Z
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		b.block("Head", (o.neon and "TellEye" or "Eye") .. side, v(o.eyeW or 0.24, o.eyeH or 0.12, 0.06),
			v(s * 0.24, 4.56, z), o.eye, CFrame.Angles(0, 0, s * (o.eyeTilt or 0.12)),
			o.neon and Enum.Material.Neon or nil)
		if o.brow then
			b.block("Head", "Brow" .. side, v(0.34, 0.09, 0.07), v(s * 0.25, 4.73, z - 0.005), o.brow,
				CFrame.Angles(0, 0, s * (o.scowl or 0.3)))
		end
	end
end

-- Clone a catalog accessory from _Gear onto the head (or another part), with an
-- optional recolour (drops the texture), scale and offset (in the attachment frame).
function L.accessory(b, gearName, opts)
	opts = opts or {}
	local src = L.staging():FindFirstChild("_Gear") and L.staging()._Gear:FindFirstChild(gearName)
	assert(src, "missing gear " .. gearName)
	local acc = src:Clone()
	acc.Name = opts.name or gearName
	local handle = acc:FindFirstChild("Handle")
	local accAtt = handle:FindFirstChildWhichIsA("Attachment")
	local target = b.model:FindFirstChild(opts.part or "Head")
	local tAtt = target:FindFirstChild(accAtt.Name, true)
	assert(tAtt, "no matching attachment " .. accAtt.Name)
	local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
	if mesh then
		if opts.color then
			mesh.TextureId = ""
			mesh.VertexColor = Vector3.new(1, 1, 1)
			handle.Color = opts.color
		end
		if opts.scale then
			mesh.Scale = mesh.Scale * opts.scale
		end
	end
	if opts.color then
		handle.Color = opts.color
	end
	handle.Material = Enum.Material.SmoothPlastic
	local offset = opts.offset or CFrame.identity
	handle.CFrame = tAtt.WorldCFrame * offset * accAtt.CFrame:Inverse()
	local weld = Instance.new("Weld")
	weld.Name = "AccessoryWeld"
	weld.Part0 = handle
	weld.Part1 = tAtt.Parent
	weld.C0 = accAtt.CFrame
	weld.C1 = tAtt.CFrame * offset
	weld.Parent = handle
	acc.Parent = b.model
	return acc
end

-- Clone ServerStorage.WeaponModels[name] into the right hand, as Weapons.luau does:
-- the hilt at its motor's rest frame, then the motor's Part0 set to the arm.
function L.weapon(b, name, jointName)
	local template = ServerStorage.WeaponModels:FindFirstChild(name)
	assert(template, "missing weapon " .. name)
	local model = template:Clone()
	model.Name = "HeldWeapon"
	model:SetAttribute("WeaponModel", name)
	local hilt = model.PrimaryPart
	local joint = hilt and hilt:FindFirstChild(jointName)
	assert(joint and joint:IsA("Motor6D"), name .. " has no " .. jointName .. " motor")
	local arm = b.model["Right Arm"]
	model:PivotTo(arm.CFrame * joint.C0 * joint.C1:Inverse() * hilt.PivotOffset)
	model.Parent = b.model
	joint.Part0 = arm
	return model
end

-- Weld details, set part flags, add AuraPoint and HealthBar, scale, store in staging.
function L.finish(b, opts)
	opts = opts or {}
	local model = b.model
	for _, p in b.parts do
		local seg = model:FindFirstChild(p:GetAttribute("Segment"))
		local w = Instance.new("WeldConstraint")
		w.Part0 = seg
		w.Part1 = p
		w.Parent = p
	end
	local hrp = model.HumanoidRootPart
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
			d.Anchored = false
			if d ~= hrp then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
			end
		end
	end
	hrp.Transparency = 1
	local aura = Instance.new("Attachment")
	aura.Name = "AuraPoint"
	aura.Parent = model.Torso
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.HipHeight = 0 -- R6 stands on its legs; HipHeight stays 0 at any scale
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if opts.scale and opts.scale ~= 1 then
		model:ScaleTo(opts.scale)
	end
	-- the bar sits just above the head or hat, in final studs (added after scaling)
	local hb = ServerStorage.Enemies.SpiritWolf.HumanoidRootPart.HealthBar:Clone()
	hb.StudsOffset = Vector3.new(0, opts.healthBarY or 3.2, 0)
	hb.Parent = hrp
	-- feet on the ground (R6 legs reach 3 studs below the root), identity pivot at the HRP
	model:PivotTo(CFrame.new(0, 3 * (opts.scale or 1), 0))
	-- Each outfit piece goes inside the R6 limb it's welded to, so the top level reads as a
	-- plain R6 rig (Head, Torso, Left/Right Arm, Left/Right Leg, HRP, Humanoid) plus
	-- accessories and the weapon. The welds don't care where the pieces are parented.
	local limbs = { Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }
	for _, p in model:GetChildren() do
		local seg = p:IsA("BasePart") and p:GetAttribute("Segment")
		if seg and limbs[seg] then
			p.Parent = model[seg]
		end
	end
	for _, d in model:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "script left in model: " .. d:GetFullName())
	end
	model:SetAttribute("Roster", "Cultivators")
	local st = L.staging()
	local old = st:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = st
	return string.format("%s: %d parts, HRP Y %.2f, height %.2f", model.Name, count, hrp.Position.Y,
		select(2, model:GetBoundingBox()).Y)
end

return L
