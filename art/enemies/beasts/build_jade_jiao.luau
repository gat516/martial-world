--!nocheck
-- Jade Jiao (boss): the user's approved reference snake, `workspace.Folder.Model.JadePython`
-- in the testbed place (the roster Jade Python ScaleTo'd 3.1746x by hand), taken part for
-- part and given the fight's 37-joint rig. Nothing visible is redesigned. Run in Edit mode
-- through execute_luau (art server on :8767 serving art/enemies); it rebuilds
-- ServerStorage._RosterBeasts.JadeJiao (body plus joint attributes), then run
-- rig_jade_jiao.luau on it. Joint table and numbers: RIGS.md "Jade Jiao".
--
-- Source: jade_python_ref.rbxm next to this file, the reference serialized read-only from
-- the user's Studio (SerializationService), so the build is reproducible from git.
--
-- What this does to the reference:
--   * moves it into model space: ground Y = 0, origin at the roster python's origin (the
--     reference HRP sits at (0, 2, 1.6) x S), faces -Z, left is -X;
--   * splits its neck and tail tubes into finer jointed pieces along their own straight
--     bones (cut planes square to the bone, every cut piece overlaps its neighbour by
--     PAD_HALF like the reference's own joints do), so the rest silhouette is unchanged:
--     ref Neck1 -> Neck1+Neck2, ref Neck2..4 -> Neck3..5, ref Tail1..7 -> Tail1..18 (SPLIT);
--     scutes, knuckles and gems are never cut, they ride the piece holding their centre;
--   * adds the fight's extras hidden at rest: hood panels inside Neck4's core block, fangs
--     inside the snout, tongue inside the jaw, barbels and P2/P3 phase parts transparent;
--   * renames a few reference parts into the fight's tell names (Throat -> ThroatSac, seven
--     scutes -> ScaleSeam*, TailTip -> TailTipGem) and adds the FX attachments.
-- The rest pose is the reference's: the body coiled on the ground, the neck in a strike S.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local BASE = "http://127.0.0.1:8767/beasts/"

-- Tunables -----------------------------------------------------------------------------------
-- How many jointed pieces each reference tube becomes (Body, Neck2..4 stay whole).
local SPLIT = {
	Neck1 = { "Neck1", "Neck2" },
	Neck2 = { "Neck3" },
	Neck3 = { "Neck4" },
	Neck4 = { "Neck5" },
	Tail1 = { "Tail1", "Tail2" },
	Tail2 = { "Tail3", "Tail4" },
	Tail3 = { "Tail5", "Tail6", "Tail7" },
	Tail4 = { "Tail8", "Tail9", "Tail10" },
	Tail5 = { "Tail11", "Tail12", "Tail13" },
	Tail6 = { "Tail14", "Tail15", "Tail16" },
	Tail7 = { "Tail17", "Tail18" },
}
-- reference scutes that become the ScaleSeam tells (by reference segment); their look stays
local SEAM_OF = { Neck1 = 1, Neck3 = 2, Body = 3, Tail2 = 4, Tail3 = 5, Tail4 = 6, Tail5 = 7, Tail6 = 8, Tail7 = 9 }
local HOOD_LEN, HOOD_H = 5.0, 2.8 -- hood panel, studs along Neck4 and across it (fits its core)
local FANG_LEN = 2.0

-- Palette: the reference's own colours, plus the hidden extras' accents
local BACK = Color3.fromHex("1E4D3F")
local JADE = Color3.fromHex("5FBF8F")
local JADE_HI = Color3.fromHex("86D6A8")
local DARK = Color3.fromHex("12261F")
local TONGUE = Color3.fromHex("B0303A")
local BONE = Color3.fromHex("EEE9DC")
local VEIN = Color3.fromHex("7DFFCF")
local VENOM = Color3.fromHex("9BFF4A")

-- Load the reference -----------------------------------------------------------------------
local raw = HttpService:GetAsync(BASE .. "jade_python_ref.rbxm.b64?" .. os.clock())
local function unbase64(s)
	local map = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do
		map[string.byte(alphabet, i)] = i - 1
	end
	s = s:gsub("[^%w%+/=]", "")
	local pad = select(2, s:gsub("=", ""))
	local n = #s // 4 * 3 - pad
	local b = buffer.create(n)
	local o = 0
	for i = 1, #s, 4 do
		local a, c, d, e = string.byte(s, i, i + 3)
		local v = map[a] * 262144 + map[c] * 4096 + (map[d] or 0) * 64 + (map[e] or 0)
		for k = 2, 0, -1 do
			if o < n then
				buffer.writeu8(b, o, bit32.band(bit32.rshift(v, k * 8), 255))
				o += 1
			end
		end
	end
	return b
end
local model = SerializationService:DeserializeInstancesAsync(unbase64(raw))[1]
assert(model and model.Name == "JadePython", "jade_python_ref.rbxm: expected the JadePython model")
local S = model:GetScale() -- 3.1746
local PAD_HALF = 0.35 * S -- the roster tube's pad past each pivot (0.7 total)
local refHrp = model.HumanoidRootPart
-- reference world -> model space: the roster origin is the HRP minus (0, 2, 1.6) x S
local toModel = CFrame.new(0, 2 * S, 1.6 * S) * CFrame.new(refHrp.Position):Inverse()
local function v(x, y, z)
	return Vector3.new(x, y, z)
end

-- joint pivots and parents from the reference's motors
local refJoint = {} -- [Part1 name] = { name, parent, pivot (model space) }
for _, m in model:GetDescendants() do
	if m:IsA("Motor6D") then
		refJoint[m.Part1.Name] = { m.Name, m.Part0.Name, toModel * (m.Part0.CFrame * m.C0).Position }
	end
end
for _, d in model:GetDescendants() do
	if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") or d:IsA("LuaSourceContainer") then
		d:Destroy()
	end
end
refHrp:Destroy()
model.Name = "JadeJiao"
model.PrimaryPart = nil
for k in model:GetAttributes() do
	model:SetAttribute(k, nil)
end

local partsOf = {} -- [ref segment] = { parts }
for _, p in model:GetChildren() do
	if p:IsA("BasePart") then
		p.CFrame = toModel * p.CFrame
		local seg = p:GetAttribute("Segment") or p.Name
		for k in p:GetAttributes() do
			p:SetAttribute(k, nil)
		end
		partsOf[seg] = partsOf[seg] or {}
		table.insert(partsOf[seg], p)
	end
end

local joints = {} -- { name, parentSeg, seg, pivot }
local function joint(name, parentSeg, seg, pivot)
	table.insert(joints, { name, parentSeg, seg, pivot })
end
local function setSeg(p, seg)
	if p.Name ~= seg then
		p:SetAttribute("Segment", seg)
	end
end
local function rename(name, from, to)
	if name:sub(1, #from) == from then
		return to .. name:sub(#from + 1)
	end
	return name
end

-- Split the tubes --------------------------------------------------------------------------
-- A part splits along the bone when one of its axes lies along it and its cross-section
-- is constant along that axis: blocks (any axis) and wedges along their X (the bevels).
local function axisAlong(p, u)
	local axes = { { p.CFrame.RightVector, "X" }, { p.CFrame.UpVector, "Y" }, { p.CFrame.LookVector, "Z" } }
	for _, a in axes do
		if math.abs(a[1]:Dot(u)) > 0.999 then
			return a[1] * math.sign(a[1]:Dot(u)), a[2]
		end
	end
	return nil
end
local function splittable(p, u)
	if p.Name:find("Scute") or p.Name:find("Knuckle") or p.Name:find("Gem") or p.Name == "TailTip" then
		return nil
	end
	local axis, which = axisAlong(p, u)
	if not axis then
		return nil
	end
	if p:IsA("WedgePart") and which ~= "X" then
		return nil
	end
	if p:IsA("Part") and p.Shape ~= Enum.PartType.Block then
		return nil
	end
	return axis, which
end

local segInfo = {} -- [new segment] = { a, b, u, refSeg }
local refSegs = { "Neck1", "Neck2", "Neck3", "Neck4", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7" }
for _, refSeg in refSegs do
	local names = SPLIT[refSeg]
	local core
	for _, p in partsOf[refSeg] do
		if p.Name == refSeg then
			core = p
		end
	end
	assert(core, "no core " .. refSeg)
	local u = core.CFrame.LookVector
	local a = refJoint[refSeg][3]
	local L = core.Size.Z - 2 * PAD_HALF -- the bone, pivot to next pivot (or tip end)
	local n = #names
	local function cut(k) -- distance of cut k from a
		return L * k / n
	end
	for k = 1, n do
		segInfo[names[k]] = { a = a + u * cut(k - 1), b = a + u * cut(k), u = u, refSeg = refSeg }
	end
	for _, p in partsOf[refSeg] do
		local axis, which = splittable(p, u)
		if n > 1 and axis then
			local half = p.Size[which] / 2
			local c = (p.Position - a):Dot(u)
			local s0, s1 = c - half, c + half
			for k = 1, n do
				local lo = if k == 1 then s0 else math.max(s0, cut(k - 1) - PAD_HALF)
				local hi = if k == n then s1 else math.min(s1, cut(k) + PAD_HALF)
				if hi - lo > 0.05 then
					local q = p:Clone()
					local size = p.Size
					q.Size = if which == "X" then v(hi - lo, size.Y, size.Z) elseif which == "Y" then v(size.X, hi - lo, size.Z)
						else v(size.X, size.Y, hi - lo)
					q.CFrame = p.CFrame + u * ((lo + hi) / 2 - c)
					q.Name = rename(p.Name, refSeg, names[k])
					q.Parent = model
					setSeg(q, names[k])
				end
			end
			p:Destroy()
		else
			-- whole: ride the piece holding its centre
			local c = (p.Position - a):Dot(u)
			local k = math.clamp(math.floor(c / (L / n)) + 1, 1, n)
			local seam = SEAM_OF[refSeg]
			if seam and p.Name == refSeg .. "Scute" then
				p.Name = "ScaleSeam" .. seam
			else
				p.Name = rename(p.Name, refSeg, names[k])
			end
			setSeg(p, names[k])
		end
	end
	-- joints: the reference joint drives the first piece, new joints sit on the cuts
	local first = refJoint[refSeg]
	local parentSeg = if first[2] == "Body" then "Body" else SPLIT[first[2]][#SPLIT[first[2]]]
	for k = 1, n do
		local seg = names[k]
		local num = tonumber(seg:match("%d+"))
		local kind = seg:match("^%a+")
		local jname = if num == 1 then "Joint" .. kind else "Joint" .. kind .. num
		joint(jname, if k == 1 then parentSeg else names[k - 1], seg, if k == 1 then first[3] else a + u * cut(k - 1))
	end
end
for _, p in partsOf.Body do
	setSeg(p, "Body")
	if p.Name == "BodyScute" then
		p.Name = "ScaleSeam" .. SEAM_OF.Body
	end
end
joint("JointRoot", "HumanoidRootPart", "Body", refJoint.Body[3])
for _, p in partsOf.Skull do
	setSeg(p, "Skull")
end
for _, p in partsOf.Jaw do
	setSeg(p, "Jaw")
	if p.Name == "Throat" then
		p.Name = "ThroatSac" -- the windup sac tell; the "Throat" attachment rides it
	end
end
joint("JointHead", "Neck5", "Skull", refJoint.Skull[3])
joint("JointJaw", "Skull", "Jaw", refJoint.Jaw[3])
local tip = model.TailTip
tip.Name = "TailTipGem"

-- Helpers for the extras -------------------------------------------------------------------
local function part(seg, name, class, size, cf, color)
	local p = Instance.new(class)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	setSeg(p, seg)
	p.Parent = model
	return p
end
local function limb(seg, name, a, b, w, color)
	return part(seg, name, "Part", v(w, w, (b - a).Magnitude + w * 0.5), CFrame.lookAt((a + b) / 2, b), color)
end
local function tellp(p)
	p:SetAttribute("Tell", true)
	p:SetAttribute("TellBase", p.Color)
	return p
end
local function hide(p, phase)
	p.Transparency = 1
	p:SetAttribute("PhaseReveal", phase)
	return p
end
local function attach(p, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = p.CFrame:PointToObjectSpace(worldPos)
	a.Parent = p
	return a
end
local function find(name)
	local p = model:FindFirstChild(name)
	assert(p, "missing part " .. name)
	return p
end

-- Hood: two panels folded flat inside Neck4's core block, against its sides. Each hinges at
-- the panel's head end and reaches back along the neck; flaring swings the rear edge out
-- (L -Y, R +Y) and turns the outer face, with its eye-spot, toward the front.
do
	local core = find("Neck4")
	local cf, hw = core.CFrame, core.Size.X / 2
	local z0 = -core.Size.Z / 2 + PAD_HALF * 0.6 -- hinge, near the head end of the block
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local seg = "Hood" .. side
		local x = s * (hw - 0.33)
		local f = cf * CFrame.new(x, 0, z0)
		part(seg, seg, "Part", v(0.2, HOOD_H, HOOD_LEN), f * CFrame.new(0, 0, HOOD_LEN / 2), BACK)
		part(seg, seg .. "Face", "Part", v(0.04, HOOD_H - 0.4, HOOD_LEN - 0.6), f * CFrame.new(s * 0.12, 0, HOOD_LEN / 2), JADE)
		part(seg, seg .. "SpotRing", "Part", v(0.03, 1.8, 1.8), f * CFrame.new(s * 0.155, 0, HOOD_LEN * 0.55), DARK).Shape =
			Enum.PartType.Cylinder
		local spot = part(seg, "HoodSpot" .. side, "Part", v(0.03, 1.2, 1.2), f * CFrame.new(s * 0.185, 0, HOOD_LEN * 0.55), VENOM)
		spot.Shape = Enum.PartType.Cylinder
		spot.Material = Enum.Material.Neon
		tellp(spot)
		attach(spot, "Hood" .. side .. "_FX", spot.Position + spot.CFrame.RightVector * s * 0.1)
		joint("JointHood" .. side, "Neck4", seg, f.Position)
	end
end

-- Fangs: folded back (tip +Z) inside the snout block, hinged on the palate near its front.
-- +X swings the tip down and forward out through the lip.
do
	local sn = find("Snout")
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		local root = sn.CFrame * CFrame.new(s * 0.85, -0.7, -1.2)
		local fw, ft, fl = 0.4, 0.45, FANG_LEN
		local flip = root * CFrame.Angles(0, math.pi, 0)
		part("Fang" .. side, "Fang" .. side, "WedgePart", v(fw, ft, fl), flip * CFrame.new(0, 0, -fl / 2), BONE)
		local tl, th = fl * 0.42, ft * 0.42
		local tipPart = part("Fang" .. side, "FangTip" .. side, "WedgePart", v(fw + 0.04, th + 0.04, tl + 0.02),
			flip * CFrame.new(0, -ft / 2 + (th + 0.04) / 2 - 0.01, -(fl - tl / 2)), VENOM)
		tipPart.Material = Enum.Material.Neon
		tellp(tipPart)
		attach(tipPart, "Fang" .. side .. "_FX", (root * CFrame.new(0, 0, fl - 0.1)).Position)
		joint("JointFang" .. side, "Skull", "Fang" .. side, root.Position)
	end
end

-- Tongue: flat on the jaw's floor inside the jaw blocks, root at the back, fork at the front.
do
	local jb = find("JawBack")
	local root = jb.CFrame * CFrame.new(0, 0.06, 0.9)
	local len = 3.6
	part("Tongue", "Tongue", "Part", v(0.5, 0.14, len), root * CFrame.new(0, 0, -len / 2), TONGUE)
	joint("JointTongue", "Jaw", "Tongue", root.Position)
	local forkRoot = root * CFrame.new(0, 0, -len)
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		part("TongueTip" .. side, "TongueTip" .. side, "Part", v(0.2, 0.12, 0.8),
			forkRoot * CFrame.Angles(0, s * 0.4, 0) * CFrame.new(0, 0, -0.4), TONGUE)
		joint("JointTongueTip" .. side, "Tongue", "TongueTip" .. side, forkRoot.Position)
	end
end

-- Barbels: whisker links swept back off the snout sides, invisible until phase 3.
do
	local sn = find("Snout")
	for _, s in { -1, 1 } do
		local side = if s < 0 then "L" else "R"
		-- rooted at the snout's lower corner, drooping back under the jaw line (clear of the eyes)
		local p0 = (sn.CFrame * CFrame.new(s * 1.8, -0.8, -0.9)).Position
		local p1 = p0 + v(s * 1.1, -1.0, 1.5)
		local p2 = p1 + v(s * 0.8, -1.3, 2.1)
		local p3 = p2 + v(s * 0.7, -1.4, 2.4)
		hide(limb("Barbel" .. side .. "1", "Barbel" .. side .. "1", p0, p1, 0.32, JADE_HI), 3)
		hide(limb("Barbel" .. side .. "2", "Barbel" .. side .. "2", p1, p2, 0.26, JADE_HI), 3)
		hide(limb("Barbel" .. side .. "2", "P3Barbel" .. side, p2, p3, 0.2, JADE_HI), 3)
		joint("JointBarbel" .. side .. "1", "Skull", "Barbel" .. side .. "1", p0)
		joint("JointBarbel" .. side .. "2", "Barbel" .. side .. "1", "Barbel" .. side .. "2", p1)
	end
end

-- Phase 2 cracks: glow fissures on the back of Body and Tail1..4, clear of the scutes.
do
	local function crack(name, seg, along, x, yaw, len)
		local top = find(seg .. "Top")
		local h = top.Size.Y
		-- `along` is a fraction of the top block's length from its centre (scutes sit mid-way)
		hide(part(seg, name, "Part", v(0.22, 0.08, len),
			top.CFrame * CFrame.new(x, h / 2 + 0.02, along * top.Size.Z / 2) * CFrame.Angles(0, yaw, 0), VEIN), 2)
	end
	crack("P2Crack1", "Body", -0.75, -0.6, 0.5, 2.2)
	crack("P2Crack2", "Body", 0.75, 0.6, -0.45, 2.2)
	crack("P2Crack3", "Tail1", -0.4, -0.5, 0.45, 2.0)
	crack("P2Crack4", "Tail2", 0.4, 0.5, -0.5, 1.9)
	crack("P2Crack5", "Tail3", -0.4, -0.4, 0.4, 1.8)
	crack("P2Crack6", "Tail4", 0.4, 0.4, -0.45, 1.7)
end

-- Phase 3 dorsal ridge: one fin on the back of each neck piece, invisible until phase 3.
for i = 1, 5 do
	local seg = "Neck" .. i
	local top = find(seg .. "Top")
	local h = 1.7 - 0.12 * i
	local len = math.min(top.Size.Z * 0.55, 3.2)
	hide(part(seg, "P3Fin" .. i, "WedgePart", v(0.3, h, len), top.CFrame * CFrame.new(0, top.Size.Y / 2 + h / 2 - 0.15, 0), JADE_HI), 3)
end

-- Tells already in the reference ------------------------------------------------------------
for _, name in { "EyeL", "EyeR", "EyeSideL", "EyeSideR", "BrowPearl", "VeinGem2", "VeinGem3", "ThroatSac", "TailTipGem" } do
	tellp(find(name))
end
for i = 1, 9 do
	tellp(find("ScaleSeam" .. i))
end

-- FX hooks ------------------------------------------------------------------------------------
do
	local body = find("Body")
	local skull = find("Skull")
	local lip = find("Lip")
	attach(skull, "Mouth", (lip.CFrame * CFrame.new(0, -lip.Size.Y / 2, -lip.Size.Z / 2 + 0.3)).Position)
	local sac = find("ThroatSac")
	attach(sac, "Throat", (sac.CFrame * CFrame.new(0, -sac.Size.Y / 2, -0.4)).Position)
	attach(body, "Core", body.Position + v(0, body.Size.Y / 2 + 0.5, 0))
	local neckBase = segInfo.Neck1.a
	attach(body, "Dive_FX", v(neckBase.X, 0, neckBase.Z))
	attach(body, "Ground_Body", v(body.Position.X, 0, body.Position.Z))
	local function mid(seg)
		return (segInfo[seg].a + segInfo[seg].b) / 2
	end
	for _, i in { 4, 9, 14 } do
		local m = mid("Tail" .. i)
		attach(find("Tail" .. i), "Ground_Tail" .. i, v(m.X, 0, m.Z))
	end
	for _, i in { 3, 6, 9, 12 } do
		local core = find("Tail" .. i)
		local m = mid("Tail" .. i)
		local bottom = core.CFrame * CFrame.new(0, -core.Size.Y / 2, 0)
		-- the belly edge on the coil's inside (toward the coil centre, the HRP's x/z)
		attach(core, "Coil_Tail" .. i, v(m.X, bottom.Position.Y, m.Z))
	end
	attach(find("Tail18"), "TailTip_FX", (tip.CFrame * CFrame.new(0, 0, -tip.Size.Z / 2)).Position)
end

-- Write the joints and replace ServerStorage._RosterBeasts.JadeJiao ----------------------
for _, j in joints do
	local p
	for _, c in model:GetChildren() do
		if c.Name == j[3] and c:IsA("BasePart") and not c:GetAttribute("Segment") then
			assert(not p, "two segment parts named " .. j[3])
			p = c
		end
	end
	assert(p, "no segment part " .. j[3])
	p:SetAttribute("Joint", j[1])
	p:SetAttribute("JointParent", j[2])
	p:SetAttribute("JointPivot", j[4])
end
model:SetAttribute("Scale", math.round(S * 1000) / 1000)
local names = {}
for _, c in model:GetChildren() do
	if c:IsA("BasePart") then
		assert(not names[c.Name], "duplicate part name " .. c.Name)
		names[c.Name] = true
	end
end

local recording = ChangeHistoryService:TryBeginRecording("Build JadeJiao")
local staging = ServerStorage:FindFirstChild("_RosterBeasts")
if not staging then
	staging = Instance.new("Folder")
	staging.Name = "_RosterBeasts"
	staging.Parent = ServerStorage
end
local old = staging:FindFirstChild("JadeJiao")
if old then
	old:Destroy()
end
model.Parent = staging
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
local count = 0
for _, c in model:GetChildren() do
	if c:IsA("BasePart") then
		count += 1
	end
end
return ("JadeJiao body: %d parts, %d joints, scale %.4f"):format(count, #joints, S)
