--!nocheck
-- Model shot: stages ONE clone of a template alone on a neutral mid-grey set under flat
-- lighting and returns `screen_capture` arguments for the standard views, so a critic (or
-- tools/fidelity_check.py) judges the same framing every time. Edit mode, sandbox Studio.
-- Docs: docs/enemies/modeling-checks.md.
--
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8783/tools/model_shot.luau?" .. os.clock()))()
--   return _G.modelShot.stage({ source = "JadeJiao" })            -- an Enemies def id (its `body`) or template name
--   return _G.modelShot.stage({ source = "ServerStorage.WeaponModels.Jian", scale = 1 })
--   return _G.modelShot.stage({ source = "Workspace._MyStaging.Wolf", rig = false, fov = 20 })
--   return _G.modelShot.sheet({ source = "SpiritWolfB" })          -- four clones turned 0/90/180/270
--   _G.modelShot.cleanup()                                          -- removes everything, restores lighting
--
-- source: an Enemies def id (resolved through its `body`), a name in ServerStorage.Enemies
--   or ServerStorage.WeaponModels, or a full dotted path (Workspace.X.Y, ServerStorage.Z).
-- scale: multiplies the template's own scale (default 1: templates are stored at body scale).
-- rig: true (default) puts a 5-stud R6 beside the model for size; false for fidelity captures
--   (the R6 would join the silhouette).
-- fov: camera field of view while staged (default 30: a long lens, so close views don't bulge
--   and the silhouette compares with a drawn or orthographic reference; 15 for fidelity
--   captures against orthographic renders). screen_capture uses the Studio camera's FOV, so
--   34_40 is pushed back to look exactly as big as a body 40 studs away at the player's 70.
--   Restored by cleanup().
-- at: where to build the set (default far off the map, below).
--
-- Returns lines like `side  camera_position=[x,y,z] look_at_position=[x,y,z]`. Presets:
--   front    level, from in front (the model faces -Z), fills the frame
--   side     level, from the model's left (-X): head on screen left
--   34       front-left, a little above, fills the frame
--   34_40    the same direction, as big on screen as at 40 studs with the player's 70-degree
--            camera: the "reads at 40 studs" test
-- sheet() returns one `sheet` preset. Take two or three captures per model, never more.
-- Bring the sandbox window to the front first (docs/vfx/toolkit/previewing.md): screen_capture
-- shows whichever Studio is in front.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local SET_AT = Vector3.new(-4000, 600, -4000) -- far from the map and the testbed arena
local PLATE_COLOR = Color3.fromRGB(100, 100, 100) -- Neon: renders about mid-grey; fidelity_check.py keys it
local RIG_GAP = 3 -- studs between the model's bounds and the R6
local FILL = 1.12 -- framing margin (1 = the bounds touch the frame edge)

local M = { state = nil }

local function resolvePath(path)
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

local function resolveSource(source)
	if typeof(source) == "Instance" then
		return source
	end
	if string.find(source, "%.") then
		return resolvePath(source) or error("model_shot: no instance at " .. source)
	end
	local name = source
	local ok, defs = pcall(function()
		return require(ReplicatedStorage.Shared.Enemies)
	end)
	if ok and type(defs) == "table" then
		local list = defs.Defs or defs
		local def = type(list) == "table" and list[source]
		if type(def) == "table" and type(def.body) == "string" then
			name = def.body
		end
	end
	for _, folder in { ServerStorage:FindFirstChild("Enemies"), ServerStorage:FindFirstChild("WeaponModels") } do
		local t = folder and folder:FindFirstChild(name)
		if t then
			return t
		end
	end
	error("model_shot: no template named " .. name .. " (from " .. source .. ")")
end

-- Visible-part bounds in world space (the HRP and other invisible parts don't count).
local function bounds(root)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local list = root:IsA("BasePart") and { root } or root:GetDescendants()
	for _, p in list do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local cf, h = p.CFrame, p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
						lo, hi = lo:Min(w), hi:Max(w)
					end
				end
			end
		end
	end
	assert(lo.X < math.huge, "model_shot: the model has no visible parts")
	return lo, hi
end

-- A clean, anchored, inert copy wrapped in a Model (Tools and Accessories too).
local function cloneClean(template, scale)
	local copy = template:Clone()
	local model = copy
	if not copy:IsA("Model") then
		model = Instance.new("Model")
		model.Name = template.Name
		copy.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CastShadow = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("LayerCollector") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
			d.Enabled = false
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	if scale and scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	return model
end

-- Puts a model's visible bounds bottom-centre on `spot`, turned `yaw` about its pivot.
local function placeOnGround(model, spot, yaw)
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, yaw or 0, 0) * model:GetPivot().Rotation)
	local lo, hi = bounds(model)
	local bottom = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	model:PivotTo(model:GetPivot() + (spot - bottom))
end

-- A 5.1-stud R6 for scale: Workspace.Rig if the place has one, else six neutral blocks.
local function sizeRig()
	local src = workspace:FindFirstChild("Rig")
	local rig
	if src and src:IsA("Model") then
		rig = cloneClean(src)
		for _, d in rig:GetDescendants() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
	else
		rig = Instance.new("Model")
		local pieces = {
			Head = { Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0) },
			Torso = { Vector3.new(2, 2, 1), Vector3.new(0, 3, 0) },
			["Left Arm"] = { Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0) },
			["Right Arm"] = { Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0) },
			["Left Leg"] = { Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0) },
			["Right Leg"] = { Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0) },
		}
		for name, s in pieces do
			local p = Instance.new("Part")
			p.Name = name
			p.Size = s[1]
			p.CFrame = CFrame.new(s[2])
			p.Anchored = true
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(205, 205, 210)
			p.Parent = rig
		end
	end
	rig.Name = "SizeRig"
	return rig
end

-- Flat light: noon sun, raised ambient, no post effects or haze. The old values are kept as
-- attributes on Lighting and each effect, so cleanup() restores them even if _G was lost.
local LIGHT_KEYS = { "ClockTime", "Ambient", "OutdoorAmbient", "Brightness" }

local function flatLighting()
	if Lighting:GetAttribute("_ms_ClockTime") == nil then
		for _, k in LIGHT_KEYS do
			Lighting:SetAttribute("_ms_" .. k, Lighting[k])
		end
		for _, e in Lighting:GetChildren() do
			if e:IsA("PostEffect") then
				e:SetAttribute("_ms_Enabled", e.Enabled)
			elseif e:IsA("Atmosphere") then
				e:SetAttribute("_ms_Density", e.Density)
			end
		end
	end
	local StarterGui = game:GetService("StarterGui")
	if StarterGui:GetAttribute("_ms_ShowDevelopmentGui") == nil then
		StarterGui:SetAttribute("_ms_ShowDevelopmentGui", StarterGui.ShowDevelopmentGui)
	end
	StarterGui.ShowDevelopmentGui = false -- the HUD draws over Edit-mode captures
	Lighting.ClockTime = 12
	Lighting.Ambient = Color3.fromRGB(150, 150, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
	Lighting.Brightness = 1.5
	for _, e in Lighting:GetChildren() do
		if e:IsA("PostEffect") then
			e.Enabled = false
		elseif e:IsA("Atmosphere") then
			e.Density = 0
		end
	end
end

local function restoreLighting()
	local StarterGui = game:GetService("StarterGui")
	local dev = StarterGui:GetAttribute("_ms_ShowDevelopmentGui")
	if dev ~= nil then
		StarterGui.ShowDevelopmentGui = dev
		StarterGui:SetAttribute("_ms_ShowDevelopmentGui", nil)
	end
	if Lighting:GetAttribute("_ms_ClockTime") == nil then
		return
	end
	for _, k in LIGHT_KEYS do
		Lighting[k] = Lighting:GetAttribute("_ms_" .. k)
		Lighting:SetAttribute("_ms_" .. k, nil)
	end
	for _, e in Lighting:GetChildren() do
		for _, k in { "Enabled", "Density" } do
			local v = e:GetAttribute("_ms_" .. k)
			if v ~= nil then
				e[k] = v
				e:SetAttribute("_ms_" .. k, nil)
			end
		end
	end
end

-- A closed grey box around the set. Neon so it renders one flat tone whatever the light
-- (fidelity_check keys it out); CastShadow off so the sun still reaches the model.
local function buildBox(folder, center, half)
	local t = 1
	local faces = {
		{ Vector3.new(half.X * 2, t, half.Z * 2), Vector3.new(0, -t / 2, 0) }, -- floor (its top at center.Y)
		{ Vector3.new(half.X * 2, t, half.Z * 2), Vector3.new(0, half.Y * 2, 0) },
		{ Vector3.new(t, half.Y * 2, half.Z * 2), Vector3.new(-half.X, half.Y, 0) },
		{ Vector3.new(t, half.Y * 2, half.Z * 2), Vector3.new(half.X, half.Y, 0) },
		{ Vector3.new(half.X * 2, half.Y * 2, t), Vector3.new(0, half.Y, -half.Z) },
		{ Vector3.new(half.X * 2, half.Y * 2, t), Vector3.new(0, half.Y, half.Z) },
	}
	for i, f in faces do
		local p = Instance.new("Part")
		p.Name = i == 1 and "Plate" or "Wall"
		p.Size = f[1]
		p.CFrame = CFrame.new(center + f[2])
		p.Anchored = true
		p.CastShadow = false
		p.CanQuery = false
		p.Material = Enum.Material.Neon
		p.Color = PLATE_COLOR
		p.Parent = folder
	end
end

-- Every visible part corner of the staged models: the camera fits these, which frames far
-- tighter than the bounding box's corners in the 3/4 view.
local function corners(models)
	local pts = {}
	for _, m in models do
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local cf, h = p.CFrame, p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							table.insert(pts, cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						end
					end
				end
			end
		end
	end
	return pts
end

-- Camera distance along `dir` (target -> camera) at which every point fits the view. Also
-- returns the target re-centred on the points' screen extent.
local function fit(pts, target, dir, fov, aspect)
	local look = -dir.Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look).Unit
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in pts do
		local r = p - target
		x0, x1 = math.min(x0, r:Dot(right)), math.max(x1, r:Dot(right))
		y0, y1 = math.min(y0, r:Dot(up)), math.max(y1, r:Dot(up))
	end
	target += right * (x0 + x1) / 2 + up * (y0 + y1) / 2
	local tanV = math.tan(math.rad(fov) / 2)
	local tanH = tanV * aspect
	local need = 0
	for _, p in pts do
		local r = p - target
		local depth = r:Dot(look) -- toward the camera is negative
		need = math.max(need, math.max(math.abs(r:Dot(right)) / tanH, math.abs(r:Dot(up)) / tanV) * FILL - depth)
	end
	return need, target
end

local function fmt(v)
	return string.format("[%.2f,%.2f,%.2f]", v.X, v.Y, v.Z)
end

local function newSet(opts, fov)
	-- keep the staged lighting and HUD state: flipping ShowDevelopmentGui back and forth in one
	-- frame left the HUD drawn over the next capture
	M.cleanup(true)
	local state = { folder = Instance.new("Folder") }
	M.state = state
	state.folder.Name = "_ModelShot"
	state.folder:AddTag("EditorOnly")
	local cam = workspace.CurrentCamera
	if workspace:GetAttribute("_ms_FieldOfView") == nil then
		workspace:SetAttribute("_ms_FieldOfView", cam.FieldOfView)
	end
	cam.FieldOfView = opts.fov or fov or 30
	flatLighting()
	return state, cam
end

local function finish(state, lo, hi, presets, aspect)
	-- the box must hold every camera with room to spare
	local center = state.at
	local reach = 0
	for _, p in presets do
		reach = math.max(reach, (p[2] - center).Magnitude)
	end
	local span = math.max(reach + 20, (hi - lo).Magnitude + 20)
	buildBox(state.folder, center, Vector3.new(span, span, span))
	state.folder.Parent = workspace
	-- the viewport keeps drawing the HUD until a few frames after ShowDevelopmentGui flips;
	-- a capture straight after the call showed it
	for _ = 1, 10 do
		task.wait()
	end
	local out = {}
	for _, p in presets do
		table.insert(out, string.format("%-6s camera_position=%s look_at_position=%s", p[1], fmt(p[2]), fmt(p[3])))
	end
	table.insert(out, string.format("bounds %.2f x %.2f x %.2f studs, fov %d, viewport aspect %.2f", hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z, workspace.CurrentCamera.FieldOfView, aspect))
	return table.concat(out, "\n")
end

function M.stage(opts)
	opts = opts or {}
	local template = resolveSource(opts.source)
	local state, cam = newSet(opts)
	local at = opts.at or SET_AT
	state.at = at

	local model = cloneClean(template, opts.scale)
	placeOnGround(model, at, 0)
	model.Parent = state.folder
	local lo, hi = bounds(model)
	local mlo, mhi = lo, hi

	if opts.rig ~= false then
		local rig = sizeRig()
		local rlo, rhi = bounds(rig)
		-- off the model's front-right corner: clear of it from the front, the left side and 3/4
		placeOnGround(rig, Vector3.new(hi.X + RIG_GAP + (rhi.X - rlo.X) / 2, at.Y, lo.Z - RIG_GAP - (rhi.Z - rlo.Z) / 2), 0)
		rig.Parent = state.folder
		local a, b = bounds(rig)
		lo, hi = lo:Min(a), hi:Max(b)
	end
	local pts = corners(state.folder:GetChildren())

	local aspect = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
	local fov = cam.FieldOfView
	local target = (lo + hi) / 2
	local body = (mlo + mhi) / 2
	local views = {
		{ "front", Vector3.new(0, 0, -1) },
		{ "side", Vector3.new(-1, 0, 0) },
		{ "34", Vector3.new(-1, 0.45, -1).Unit },
	}
	local presets = {}
	for _, v in views do
		local d, t = fit(pts, target, v[2], fov, aspect)
		table.insert(presets, { v[1], t + v[2] * d, t })
	end
	-- as big on screen as 40 studs away through the player's 70-degree camera
	local far = 40 * math.tan(math.rad(35)) / math.tan(math.rad(fov) / 2)
	table.insert(presets, { "34_40", body + Vector3.new(-1, 0.45, -1).Unit * far, body })
	return finish(state, lo, hi, presets, aspect)
end

-- Four clones turned 0/90/180/270 in a row, left to right on screen: front, right side, back,
-- left side. Seen from the front through a long lens (fov 15 unless given), so one capture
-- shows every side.
function M.sheet(opts)
	opts = opts or {}
	local template = resolveSource(opts.source)
	local state, cam = newSet(opts, 15) -- a long lens keeps the end clones square-on
	local at = opts.at or SET_AT
	state.at = at

	local probe = cloneClean(template, opts.scale)
	local plo, phi = bounds(probe)
	local step = math.max(phi.X - plo.X, phi.Z - plo.Z) + 2
	probe:Destroy()
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for i, yaw in { 0, 90, 180, 270 } do
		local m = cloneClean(template, opts.scale)
		m.Name = template.Name .. "_" .. yaw
		placeOnGround(m, at + Vector3.new((2.5 - i) * step, 0, 0), math.rad(yaw)) -- screen right is -X
		m.Parent = state.folder
		local a, b = bounds(m)
		lo, hi = lo:Min(a), hi:Max(b)
	end
	local aspect = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
	local target = (lo + hi) / 2
	local dir = Vector3.new(0, 0.12, -1).Unit
	local d, t = fit(corners(state.folder:GetChildren()), target, dir, cam.FieldOfView, aspect)
	return finish(state, lo, hi, { { "sheet", t + dir * d, t } }, aspect)
end

function M.cleanup(keepEnv)
	local fov = not keepEnv and workspace:GetAttribute("_ms_FieldOfView")
	if not keepEnv then
		restoreLighting()
	end
	if fov then
		workspace.CurrentCamera.FieldOfView = fov
		workspace:SetAttribute("_ms_FieldOfView", nil)
	end
	local state = M.state
	if state then
		if state.folder then
			state.folder:Destroy()
		end
		M.state = nil
	end
	-- leftovers from a lost _G (Edit-mode _G can reset)
	for _, c in workspace:GetChildren() do
		if c.Name == "_ModelShot" then
			c:Destroy()
		end
	end
	return "model_shot: cleaned"
end

_G.modelShot = M
return M
