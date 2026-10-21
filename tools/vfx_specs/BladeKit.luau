--!nocheck
-- Spec helpers shared by the blade techniques (HeavenSplitter, RampagingTiger):
-- not a technique spec itself (no `id`). The specs reach it lazily at build
-- time through _G.vfxSpecs.BladeKit, so load order doesn't matter.
-- Runtime counterpart: src/client/TechniqueFX/BladeSkill.luau.
--
--   edge(root, tier, p)   Part "Edge": the qi edge the runtime moves onto the
--       held weapon (Base -> Tip): Trail "Trail" (the swing arc, a solid
--       tapered ribbon), II+ Trail "After" (a longer faint afterimage), Beam
--       "Glow" (the blade wreathed in qi while charged; the runtime toggles
--       it), and emitter "Motes" on attachment "Mid" (qi shed off the blade).
--       All disabled; the runtime enables them per strike window.
--       p.color, p.core, p.trailLife {by tier}, p.glowWidth {by tier}
--   strips(root, tier, p) a glowing Neon slit p.name ("Cut") and the ink
--       scar p.scar ("Scar") it cools into, laid on the ground by the runtime
--       (StartTransparency / Fade / FadeDelay / FadeColor attributes, the
--       Sword Qi Wave convention). p.width {cut, scar} by tier.
--   heldWave(parent, name, p) a MeshWave-shaped held mesh: Part/MeshPart
--       "Mesh" at Transparency 1 under a Model, for pieces the runtime drives
--       frame by frame (wheel rings, the phantom blade), with p.attrs.
--   cylinderWave(parent, name, p) a MeshWave whose Mesh is a Neon cylinder
--       Part (light columns): FromSize/ToSize X is the length; Rotation
--       (0,0,90) stands it up.
--   crescent(part, layer, p) a tapered curved ribbon of two Beams (L -> C ->
--       R) in the part's XY plane (it faces +-Z): p.span, p.bow (how far the
--       tips sweep back, +Y), p.y, p.width, p.color, p.transparency, p.light.
local KIT = {}
local NS, CS, KP, R = NumberSequence.new, ColorSequence.new, NumberSequenceKeypoint.new, NumberRange.new
local V = Vector3.new
local O = CFrame.new()

local function B()
	return _G.vfxBlocks
end

local function byTier(v, tier)
	return if type(v) == "table" then v[tier] else v
end

function KIT.edge(root, tier, p)
	local B0 = B()
	local edge = B0.part(root, "Edge", O * CFrame.new(1.5, 1.5, -1), V(0.2, 0.2, 0.2))
	local a0 = B0.attach(edge, "A0", V(0, 0, 0))
	local a1 = B0.attach(edge, "A1", V(0, 4, 0))
	B0.attach(edge, "Mid", V(0, 2.4, 0))
	local color, core = p.color, p.core
	local function trail(name, life, t0, light)
		local t = Instance.new("Trail")
		t.Name = name
		t.Attachment0, t.Attachment1 = a0, a1
		t.Color = CS({ ColorSequenceKeypoint.new(0, core), ColorSequenceKeypoint.new(0.35, color), ColorSequenceKeypoint.new(1, p.tail or color) })
		t.Transparency = NS({ KP(0, t0), KP(0.5, t0 + (1 - t0) * 0.35), KP(1, 1) })
		t.WidthScale = NS({ KP(0, 1), KP(1, 0.35) })
		t.Lifetime = life
		t.LightEmission, t.LightInfluence = light, 0
		t.FaceCamera = false
		t.MinLength = 0.04
		t.Enabled = false
		t.Parent = edge
		return t
	end
	trail("Trail", byTier(p.trailLife or { 0.16, 0.2, 0.24, 0.3 }, tier), 0.05, 0.3)
	if tier >= 2 then
		trail("After", byTier(p.trailLife or { 0.16, 0.2, 0.24, 0.3 }, tier) * 2.2, 0.62, 0.2)
	end
	local glow = Instance.new("Beam")
	glow.Name = "Glow"
	glow.Attachment0, glow.Attachment1 = a0, a1
	glow.Width0 = byTier(p.glowWidth or { 0.5, 0.7, 0.9, 1.1 }, tier) * 0.6
	glow.Width1 = byTier(p.glowWidth or { 0.5, 0.7, 0.9, 1.1 }, tier)
	glow.FaceCamera = true
	glow.Color = CS(color)
	glow.Transparency = NS({ KP(0, 0.75), KP(0.8, 0.55), KP(1, 0.8) })
	glow.LightEmission, glow.LightInfluence = 0.45, 0
	glow.Segments = 2
	glow.Enabled = false
	glow.Parent = edge
	B0.emitter(edge.Mid, "Motes", {
		Texture = "rbxassetid://9841260273", Color = CS(core, color),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		SpreadAngle = Vector2.new(180, 180), Size = NS({ KP(0, 0.22), KP(1, 0) }), Transparency = NS({ KP(0, 0.1), KP(1, 1) }),
		Lifetime = R(0.3, 0.55), Speed = R(1.5, 4), Drag = 3, LightEmission = 0.55, Rotation = R(0, 360),
		Rate = byTier(p.moteRate or { 8, 14, 20, 28 }, tier),
	})
	return edge
end

function KIT.strips(root, tier, p)
	local B0 = B()
	local widths = p.width or { { 0.3, 0.6 }, { 0.36, 0.7 }, { 0.42, 0.85 }, { 0.5, 1.0 } }
	local w = widths[tier]
	local function strip(name, material, color, width, attrs, thick)
		local s = B0.part(root, name, O * CFrame.new(0, 0.05, -6), V(width, thick, 1))
		s.Material, s.Color = material, color
		for k, v in attrs do
			s:SetAttribute(k, v)
		end
		return s
	end
	strip(p.name or "Cut", Enum.Material.Neon, p.color, w[1], {
		StartTransparency = 0.2, Fade = byTier(p.fade or { 0.45, 0.55, 0.65, 0.8 }, tier), FadeColor = p.fadeColor or p.color,
	}, 0.1)
	strip(p.scar or "Scar", Enum.Material.SmoothPlastic, p.ink, w[2], {
		StartTransparency = 0.3, Fade = byTier(p.scarFade or { 1.0, 1.25, 1.5, 1.9 }, tier), FadeDelay = 0.25,
	}, 0.06)
	return root:FindFirstChild(p.name or "Cut")
end

function KIT.heldWave(parent, name, p)
	local m = Instance.new("Model")
	m.Name = name
	local mesh
	if p.mesh then
		mesh = B().mesh(p.mesh, m, "Mesh", p.size, O, p.color, p.material)
	else
		mesh = Instance.new("Part")
		mesh.Name = "Mesh"
		mesh.Shape = p.shape or Enum.PartType.Block
		mesh.Anchored, mesh.CanCollide, mesh.CanQuery, mesh.CanTouch, mesh.CastShadow = true, false, false, false, false
		mesh.Material = p.material or Enum.Material.Neon
		mesh.Color = p.color
		mesh.Size = p.size or V(1, 1, 1)
		mesh.Transparency = 1
		mesh.CFrame = O
		mesh.Parent = m
	end
	for k, v in p.attrs or {} do
		m:SetAttribute(k, v)
	end
	m.Parent = parent
	return m, mesh
end

function KIT.cylinderWave(parent, name, p)
	local wave = Instance.new("Model")
	wave.Name = name
	for k, v in {
		FromSize = p.fromSize, ToSize = p.toSize, FromOffset = p.fromOffset, ToOffset = p.toOffset,
		Rotation = V(0, 0, 90), FromTransparency = p.fromTransparency, ToTransparency = p.toTransparency,
		Duration = p.duration, Style = p.style, FadeStyle = p.fadeStyle, EmitDelay = p.delay,
	} do
		wave:SetAttribute(k, v)
	end
	wave:SetAttribute("MeshWave", true)
	local c = Instance.new("Part")
	c.Name = "Mesh"
	c.Shape = Enum.PartType.Cylinder
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
	c.Material = p.material or Enum.Material.Neon
	c.Color = p.color
	c.Transparency = 1
	c.Size = p.fromSize
	c.CFrame = O
	c.Parent = wave
	wave.Parent = parent
	return wave
end

function KIT.crescent(part, layer, p)
	local span, bow, y = p.span, p.bow or p.span * 0.3, p.y or 0
	local function att(name, pos, axis)
		local a = Instance.new("Attachment")
		a.Name = layer .. name
		-- secondary axis along Z: the ribbon lies in the XY plane, facing +-Z
		a.CFrame = CFrame.fromMatrix(pos, axis, Vector3.zAxis)
		a.Parent = part
		return a
	end
	local L = att("L", V(-span / 2, y + bow, 0), V(0, -1, 0))
	local C = att("C", V(0, y, 0), V(1, 0, 0))
	local Rt = att("R", V(span / 2, y + bow, 0), V(0, 1, 0))
	for i, pair in { { L, C, 0.04, p.width }, { C, Rt, p.width, 0.04 } } do
		local b = Instance.new("Beam")
		b.Name = layer .. (if i == 1 then "Left" else "Right")
		b.Attachment0, b.Attachment1 = pair[1], pair[2]
		b.Width0, b.Width1 = pair[3], pair[4]
		-- bow the halves into one arc (CurveSize pulls along each attachment's X)
		b.CurveSize0 = if i == 1 then bow * 0.9 else span * 0.28
		b.CurveSize1 = if i == 1 then span * 0.28 else bow * 0.9
		b.FaceCamera = false
		b.Color = CS(p.color)
		b.LightEmission, b.LightInfluence = p.light or 0.3, 0
		b.Transparency = NS(p.transparency or 0)
		b.Segments = 14
		b.Parent = part
	end
end

-- Edit-mode preview through the real call path for the blade techniques:
-- KIT.preview({ id, level, freezeAt (clip s), center?, rig? ("gsrigrea2lfixed"),
-- enemies?, offsets?, anim? (id override) }) -> summary. Builds a vfxPreview
-- scene, swaps its rig for a clone of a weapon rig (Tip/Base added on the
-- blade), plays the technique clip on it by hand at castSpeed with the root
-- driven over def.lungeWindow, calls CombatEffects.cast at the first hit, and
-- freezes particles and MeshWave tweens at `freezeAt`. Markers don't fire
-- while scrubbing, so beats run on the clip clock (+0.08 s fallback slack).
function KIT.preview(opts)
	local P = _G.vfxPreview
	local RS = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local S = P.scene({ center = opts.center, radius = opts.radius, enemies = opts.enemies, offsets = opts.offsets, keep = opts.keep })
	local source = workspace.WeaponShowcase:FindFirstChild(opts.rig or "gsrigrea2lfixed")
	local rig = source:Clone()
	local old = S.rig
	local root = rig.HumanoidRootPart
	local _, size = old:GetBoundingBox()
	rig:PivotTo(old:GetPivot())
	old:Destroy()
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "_VFXPreviewRig"
		end
	end
	-- Tip/Base on the longest weapon mesh, tip at the end far from the hilt
	local hilt = rig:FindFirstChild("HiltR") or rig:FindFirstChild("Hilt")
	local best
	for _, d in rig:GetDescendants() do
		if d:IsA("MeshPart") and d.Parent.Name == "PARTS" and (not best or d.Size.Magnitude > best.Size.Magnitude) then
			best = d
		end
	end
	if best and hilt then
		local axis = best.Size.X >= best.Size.Y and best.Size.X >= best.Size.Z and Vector3.xAxis or (best.Size.Y >= best.Size.Z and Vector3.yAxis or Vector3.zAxis)
		local half = axis * (best.Size:Dot(axis) / 2)
		local e1, e2 = best.CFrame:PointToWorldSpace(half), best.CFrame:PointToWorldSpace(-half)
		local far = (e1 - hilt.Position).Magnitude > (e2 - hilt.Position).Magnitude
		local model = Instance.new("Model")
		model.Name = "PreviewWeapon"
		model.Parent = rig
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Parent = best
		tip.WorldPosition = far and e1 or e2
		local base = Instance.new("Attachment")
		base.Name = "Base"
		base.Parent = best
		base.WorldPosition = far and e2 or e1
		-- BladeSkill looks for Tip/Base inside a Model child of the character
		best.Parent.Parent = model
	end
	rig.Parent = S.folder
	S.rig = rig
	local holder = P.fresh({ "CombatEffects", "Sfx", "TechniqueVFX", "CastFX" })
	if opts.source then
		-- preview templates from a scratch folder (opts.source.<Id>.<Id>_T<n>)
		-- instead of the mapped ReplicatedStorage.Effects
		local TV = require(holder.TechniqueVFX)
		local Tq = require(holder.Shared.Techniques)
		TV.template = function(id, level)
			local tier, step = Tq.visualTier(level)
			local group = opts.source:FindFirstChild(id)
			return group and group:FindFirstChild(id .. "_T" .. tier), tier, step
		end
	end
	local CE = require(holder.CombatEffects)
	local Techniques = require(holder.Shared.Techniques)
	local def = Techniques.Defs[opts.id]
	if opts.anim then
		def.animationId = opts.anim
	end
	local animId = def.animationId
	if not animId then
		local a = RS:FindFirstChild("Animations") and RS.Animations:FindFirstChild("Techniques") and RS.Animations.Techniques:FindFirstChild(opts.id)
		animId = a and a.AnimationId
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = type(animId) == "number" and ("rbxassetid://" .. animId) or animId
	root.Anchored = true
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local track = animator:LoadAnimation(anim)
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 6 do
		task.wait()
	end
	track:Play(0, 1, 0)
	local speed = def.castSpeed or 1
	local first = def.hits[1].time
	local window = def.lungeWindow or { 0, 0 }
	local start = root.CFrame
	local dir = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local began, casted, err = os.clock(), false, nil
	local clip = 0
	while true do
		clip = (os.clock() - began) * speed
		if opts.freezeAt and clip >= opts.freezeAt then
			clip = opts.freezeAt
		end
		track.TimePosition = math.min(clip, track.Length - 0.01)
		local k = math.clamp((clip - window[1]) / math.max(window[2] - window[1], 0.01), 0, 1)
		root.CFrame = start + dir * (def.lunge or 0) * k
		animator:StepAnimations(0)
		if not casted and clip >= first then
			casted = true
			local ok, e = pcall(CE.cast, rig, opts.id, root.Position, dir, nil, opts.level)
			if not ok then
				err = e
			end
			if opts.trailLife then
				-- trails can't be frozen: stretch them to see the whole arc in a still
				for _, d in rig:GetDescendants() do
					if d:IsA("Trail") then
						d.Lifetime = opts.trailLife
					end
				end
			end
		end
		if (opts.freezeAt and clip >= opts.freezeAt) or clip > track.Length then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if opts.freezeAt then
		RunService.Heartbeat:Wait()
		for _, r in { workspace.Terrain:FindFirstChild("TempVFX"), S.folder } do
			if r then
				for _, d in r:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						d.TimeScale = 0
					end
				end
			end
		end
		local TV = require(holder.TechniqueVFX)
		for tween in TV.waves or {} do
			tween:Pause()
		end
	end
	local kids = {}
	for _, d in S.folder._fxOut:GetChildren() do
		kids[d.Name] = (kids[d.Name] or 0) + 1
	end
	local list = {}
	for n, c in kids do
		table.insert(list, n .. "x" .. c)
	end
	return string.format("clip=%.2f err=%s C=%s out=%s", clip, tostring(err), tostring(S.C), table.concat(list, ","))
end

return KIT
