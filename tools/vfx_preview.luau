--!nocheck
-- Edit-mode preview kit for effect templates. Run this file once through the
-- Studio MCP's execute_luau; it installs _G.vfxPreview:
--
--   P.scene({ center?, enemies? = {"SpiritWolf", ...}, offsets? = {Vector3...},
--             radius? })            -> scene table { C, rig, enemies, folder }
--       A clean SmoothPlastic floor (opts.floor size, opts.floorColor) in open sky (no props in the way), a caster stand-in
--       (a clone of workspace.Rig, facing +X), enemy clones from
--       ServerStorage.Enemies facing the caster, and red posts at `radius` to
--       check a gameplay shape against.
--   P.emit(inst)       native ParticleEmitter:Emit honouring EmitCount/EmitDelay
--       (shared.fx.emit works too, but in Edit mode it starts ~0.1 s late, so
--       frozen-frame captures drift; use this for timing, fx.emit to confirm
--       the module plays everything).
--   P.freeze(seconds)  wait, then TimeScale = 0 on every emitter in the scene
--       so a screen_capture shows that exact moment. Tweens keep running.
--   P.clone(path)      clone a template (e.g. "Effects.PalmStrike.PalmStrike_T4"
--       under ReplicatedStorage) into the scene.
--   P.clear(keepScene?) remove clones (and the scene unless keepScene), the
--       fresh module copies, and empty workspace.Terrain.TempVFX.
--   P.fresh(names)     fresh copies of client modules (StarterPlayerScripts.Client)
--       plus a mirror of ReplicatedStorage.Shared in ServerStorage._PreviewModules,
--       with `ReplicatedStorage.Shared` requires pointed at the mirror. Edit's
--       require cache can hold stale versions of modules required earlier in the
--       session (Config without Combat, say), so never require the live ones.
--       The copy of TechniqueVFX gets: folder = the scene's _fxOut folder
--       (screen_capture swaps the camera, and a Camera's children only render
--       while it is current), cleanup disabled (frozen frames must survive until
--       captured), and CameraShake/ImpactFrames attributes stripped before emit
--       (ScreenEffects moves the editor camera and spoils the capture).
--   P.look(cam?, scene?) parks the editor camera on a scene (cam = a CAMERAS
--       name, default "player"). Edit mode only simulates particles near the
--       camera; far away only new-born ones show (pale, missing layers), so
--       castThrough parks it before playing and sweep before each moment.
--   P.castThrough({ id, level, freezeAt?, animation? }) -> summary string
--       The real call path: plays the technique's Fists animation on the scene
--       rig at the cast's playback speed (Rules.castProfile), calls
--       CombatEffects.windup at start and CombatEffects.cast at Hit with the rig's
--       live root and hands, then freezes particles at `freezeAt` seconds after
--       cast start. Pass a level (1, 4, 7, 10 for tiers I-IV), not a tier.
--   P.sweep({ id, level, radius?, moments?, lag? }) -> capture list (string)
--       One call for a whole tier: builds one scene per named moment (spaced
--       apart so effects don't mix), plays the real cast in each and freezes it
--       at its moment, then returns every screen_capture to make, back to back:
--       "capture_id | camera_position | look_at_position" per line. Default
--       moments come from Rules.castProfile: windup (80% of windup), hit (just
--       after Hit), hitstop (Hit Stop), aftermath (end of recovery + 0.3 s);
--       post-Hit moments add `lag` (default 0.1 s, shared.fx's Edit-mode start
--       delay). Particles and MeshWave tweens freeze; Craters/SimpleMeshVFX
--       tweens and spline trails don't. Default cameras (5 shots): windup hand, hit player+side,
--       hitstop top, aftermath player; pass `moments` for others ("far" is
--       player distance, ~25 studs). Tweened add-on parts (Craters,
--       shells, spline trails) keep moving after a freeze, so judge those from
--       the hit/hitstop shots only.
--   P.filmstrip({ id, level, radius?, moments?, cols? = 3, fov? = 18, lag? })
--       -> "camera x,y,z | look x,y,z" plus one line per moment
--       The review image: one scene per moment (default six, from
--       Rules.castProfile: anticipation, windup, release, active, hitstop,
--       aftermath) laid out as a cols x rows grid square to the player-view
--       camera, each on a dark plate with a label (moment and ms after cast
--       start) spelt in small Neon parts, all frozen, and the editor camera
--       parked far back with a narrow FieldOfView so ONE screen_capture with
--       the returned camera shows the whole beat (near-orthographic, so every
--       cell reads at the same scale). It hides the dev GUI (the HUD) and
--       builds at y 1200 (open sky over the testbed's baseplate); P.clear()
--       restores the FieldOfView and the dev GUI.
--       Moments are { name, t } (seconds after cast start) like sweep's.
-- Typical camera for screen_capture: behind-right of the caster at player
-- distance, e.g. C + (-12, 9, 5) looking at C + (4, 1, 0); top-down
-- C + (0.1, 28, 0) -> C checks radii against the posts.

local RS = game:GetService("ReplicatedStorage")
local RIG_GROUP = "_VFXPreviewRig" -- unregistered again by P.clear
local P = {}
local S = nil

local function sampled(v)
	if typeof(v) == "NumberRange" then
		return v.Min + math.random() * (v.Max - v.Min)
	end
	return if type(v) == "number" then v else 0
end
local function inherited(inst, root, name)
	local at = inst
	while at do
		local v = at:GetAttribute(name)
		if v ~= nil then
			return v
		end
		if at == root then
			break
		end
		at = at.Parent
	end
end
local function delayOf(inst, root)
	local s, at = 0, inst
	while at do
		s += sampled(at:GetAttribute("EmitDelay"))
		if at == root then
			break
		end
		at = at.Parent
	end
	return s
end

function P.emit(root)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		if d:IsA("ParticleEmitter") then
			local dl = delayOf(d, root)
			local n = math.max(1, math.round(sampled(inherited(d, root, "EmitCount") or 1)))
			if dl > 0 then
				task.delay(dl, function()
					d:Emit(n)
				end)
			else
				d:Emit(n)
			end
		end
	end
end

function P.freeze(seconds)
	task.wait(seconds)
	for _, root in { S and S.folder, workspace.Terrain:FindFirstChild("TempVFX") } do
		if root then
			for _, d in root:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.TimeScale = 0
				end
			end
		end
	end
end

local function ground(p)
	local hit = workspace:Raycast(p + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0))
	return if hit then hit.Position.Y else p.Y
end

function P.scene(opts)
	opts = opts or {}
	if not opts.keep then
		P.clear()
	end
	local C = opts.center or Vector3.new(400, 640, 300)
	local folder = Instance.new("Folder")
	folder.Name = "_VFXPreview"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(opts.floor or 90, 2, opts.floor or 90)
	floor.CFrame = CFrame.new(C - Vector3.new(0, 1, 0))
	floor.Material = Enum.Material.SmoothPlastic -- textured grass muddies reads
	floor.Color = opts.floorColor or Color3.fromRGB(98, 170, 60)
	floor.Parent = folder
	local rig = workspace:FindFirstChild("Rig")
	rig = rig and rig:Clone()
	if rig then
		local _, size = rig:GetBoundingBox()
		rig:PivotTo(CFrame.lookAt(C + Vector3.new(0, size.Y / 2, 0), C + Vector3.new(1, size.Y / 2, 0)))
		-- the game's ground rays skip player characters; Edit has none, so put the
		-- stand-in in a collision group that ignores Default (default raycasts then
		-- skip it). CanCollide/CanQuery don't work: an R6 Humanoid forces Torso
		-- and Head CanCollide back on, and CanQuery is ignored while CanCollide.
		local PhysicsService = game:GetService("PhysicsService")
		if not PhysicsService:IsCollisionGroupRegistered(RIG_GROUP) then
			PhysicsService:RegisterCollisionGroup(RIG_GROUP)
		end
		PhysicsService:CollisionGroupSetCollidable(RIG_GROUP, "Default", false)
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = RIG_GROUP
			end
		end
		rig.Parent = folder
	end
	local out = Instance.new("Folder")
	out.Name = "_fxOut"
	out.Parent = folder
	local enemies = {}
	local names = opts.enemies or { "SpiritWolf", "StoneBoar" }
	local offsets = opts.offsets or { Vector3.new(5.5, 0, 2.5), Vector3.new(8, 0, -3.5), Vector3.new(14, 0, 1), Vector3.new(20, 0, -2) }
	for i, name in names do
		local source = game.ServerStorage.Enemies:FindFirstChild(name)
		if source then
			local e = source:Clone()
			for _, d in e:GetDescendants() do
				if d:IsA("BaseScript") then
					d:Destroy()
				end
			end
			local _, es = e:GetBoundingBox()
			local p = C + offsets[i]
			e:PivotTo(CFrame.lookAt(Vector3.new(p.X, ground(p) + es.Y / 2, p.Z), Vector3.new(C.X, ground(p) + es.Y / 2, C.Z)))
			e:AddTag("Enemy") -- Hitbox.enemiesIn and the ground filter look for it
			-- live enemies carry their health as attributes; Hitbox.alive reads them
			e:SetAttribute("MaxHealth", 100)
			e:SetAttribute("Health", 100)
			e.Parent = folder
			table.insert(enemies, e)
		end
	end
	if opts.radius then
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local post = Instance.new("Part")
			post.Name = "RadiusPost"
			post.Anchored, post.CanCollide, post.CanQuery, post.CanTouch = true, false, false, false
			post.Size = Vector3.new(0.25, 1.2, 0.25)
			post.Color = Color3.new(1, 0.1, 0.1)
			post.CFrame = CFrame.new(C + Vector3.new(math.cos(a) * opts.radius, 0.6, math.sin(a) * opts.radius))
			post.Parent = folder
		end
	end
	S = { C = C, rig = rig, enemies = enemies, folder = folder }
	P.current = S
	return S
end

function P.clone(path)
	local node = RS
	for part in string.gmatch(path, "[^%.]+") do
		node = node[part]
	end
	local copy = node:Clone()
	copy.Name = "_fx" .. copy.Name
	copy.Parent = S.folder
	return copy
end

function P.clear(keepScene)
	if S and S.folder.Parent then
		if keepScene then
			for _, d in S.folder:GetChildren() do
				if d.Name:match("^_fx") then
					d:Destroy()
				end
			end
		else
			S.folder:Destroy()
			S = nil
		end
	end
	while not keepScene and workspace:FindFirstChild("_VFXPreview") do
		workspace._VFXPreview:Destroy()
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		temp:ClearAllChildren()
	end
	local mods = game.ServerStorage:FindFirstChild("_PreviewModules")
	if mods and not keepScene then
		mods:Destroy()
	end
	if not keepScene then
		local PhysicsService = game:GetService("PhysicsService")
		if PhysicsService:IsCollisionGroupRegistered(RIG_GROUP) then
			PhysicsService:UnregisterCollisionGroup(RIG_GROUP)
		end
	end
	pcall(function()
		game:GetService("RunService"):UnbindFromRenderStep("CombatShake")
	end)
	if P._fov and not keepScene then
		workspace.CurrentCamera.FieldOfView = P._fov
		P._fov = nil
	end
	if P._devGui ~= nil and not keepScene then
		game:GetService("StarterGui").ShowDevelopmentGui = P._devGui
		P._devGui = nil
	end
end

function P.fresh(names)
	local holder = game.ServerStorage:FindFirstChild("_PreviewModules")
	if holder then
		holder:Destroy()
	end
	holder = Instance.new("Folder")
	holder.Name = "_PreviewModules"
	holder.Parent = game.ServerStorage
	RS.Shared:Clone().Parent = holder
	local client = game.StarterPlayer.StarterPlayerScripts.Client
	for _, n in names do
		local m = client[n]:Clone()
		m.Source = m.Source:gsub("ReplicatedStorage%.Shared", 'game:GetService("ServerStorage")._PreviewModules.Shared')
		m.Parent = holder
	end
	-- per-technique effect modules (Client.TechniqueFX.<Id>), which CombatEffects
	-- finds next to itself
	if client:FindFirstChild("TechniqueFX") and not holder:FindFirstChild("TechniqueFX") then
		local fx = client.TechniqueFX:Clone()
		for _, m in fx:GetDescendants() do
			if m:IsA("ModuleScript") then
				m.Source = m.Source:gsub("ReplicatedStorage%.Shared", 'game:GetService("ServerStorage")._PreviewModules.Shared')
			end
		end
		fx.Parent = holder
	end
	local tvModule = holder:FindFirstChild("TechniqueVFX")
	if tvModule and S then
		local TV = require(tvModule)
		TV.folder = S.folder._fxOut
		TV.cleanup = function() end
		local emit = TV.emit
		TV.emit = function(inst)
			for _, d in inst:GetDescendants() do
				d:SetAttribute("CameraShake", nil)
				d:SetAttribute("ImpactFrames", nil)
			end
			emit(inst)
		end
	end
	return holder
end

function P.castThrough(opts)
	S = opts.scene or S
	assert(S, "call P.scene first")
	local RunService = game:GetService("RunService")
	S.folder._fxOut:ClearAllChildren()
	if opts.look ~= false then
		P.look(opts.camera, S)
		task.wait(0.5)
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp and not opts.scene then -- a sweep keeps earlier scenes' add-on parts
		temp:ClearAllChildren()
	end
	local holder = P.fresh({ "CombatEffects", "Sfx", "TechniqueVFX", "CastFX" })
	local CE = require(holder.CombatEffects)
	local Techniques = require(holder.Shared.Techniques)
	local Rules = require(holder.Shared.ActionRules)
	local def = Techniques.Defs[opts.id]
	local profile = Rules.castProfile(def)
	local rig, root = S.rig, S.rig.HumanoidRootPart
	root.Anchored = true
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local track = animator:LoadAnimation(opts.animation or RS.Animations.Fists[tostring(def.animation)])
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 5 do
		task.wait()
	end
	track:Play(0, 1, 0)
	local dir = (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local start, cast, err = os.clock(), false, nil
	local ok, e = pcall(CE.windup, rig, opts.id, opts.level)
	if not ok then
		err = e
	end
	while true do
		local t = os.clock() - start
		track.TimePosition = math.min(t * profile.speed, track.Length - 0.01)
		animator:StepAnimations(0)
		if not cast and t >= profile.windup then
			cast = true
			local ok2, e2 = pcall(CE.cast, rig, opts.id, root.Position, dir, nil, opts.level)
			if not ok2 then
				err = e2
			end
		end
		if (opts.freezeAt and t >= opts.freezeAt) or t > 3 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if opts.freezeAt then
		for _, r in { workspace.Terrain:FindFirstChild("TempVFX"), S.folder } do
			if r then
				for _, d in r:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						d.TimeScale = 0
					end
				end
			end
		end
		-- MeshWave tweens (TechniqueVFX.waves) hold too
		local TV = require(holder.TechniqueVFX)
		for tween in TV.waves or {} do
			tween:Pause()
		end
	end
	pcall(function()
		RunService:UnbindFromRenderStep("CombatShake")
	end)
	local kids = {}
	for _, d in S.folder._fxOut:GetChildren() do
		table.insert(kids, d.Name)
	end
	return string.format("t=%.2f err=%s spawned=%s", os.clock() - start, tostring(err), table.concat(kids, ","))
end

local CAMERAS = {
	player = { Vector3.new(-12, 9, 5), Vector3.new(4, 1, -1) },
	side = { Vector3.new(3, 6, 16), Vector3.new(3, 1.5, -1) },
	top = { Vector3.new(0.1, 28, 0), Vector3.zero },
	far = { Vector3.new(-23, 12, 12), Vector3.new(2, 1, -1) },
	hand = { Vector3.new(4, 6, 9), Vector3.new(-0.5, 4.5, 0.5) },
}
P.CAMERAS = CAMERAS

function P.look(cam, scene)
	scene = scene or S
	assert(scene, "call P.scene first")
	local c = CAMERAS[cam or "player"] or CAMERAS.player
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(scene.C + c[1], scene.C + c[2])
	return camera.CFrame.Position
end

function P.sweep(opts)
	local holder = P.fresh({ "TechniqueVFX" })
	local Rules = require(holder.Shared.ActionRules)
	local Techniques = require(holder.Shared.Techniques)
	local profile = Rules.castProfile(Techniques.Defs[opts.id])
	local lag = opts.lag or 0.1
	local w, a, r = profile.windup, profile.active, profile.recovery
	local moments = opts.moments or {
		{ name = "windup", t = w * 0.8, cameras = { "hand" } },
		{ name = "hit", t = w + 0.06 + lag, cameras = { "player", "side" } },
		{ name = "hitstop", t = w + a + lag, cameras = { "top" } },
		{ name = "aftermath", t = w + a + r + 0.3 + lag, cameras = { "player" } },
	}
	P.clear()
	local base = opts.center or Vector3.new(400, 640, 300)
	local lines, results = {}, {}
	for i, m in moments do
		local scene = P.scene({ center = base + Vector3.new(0, 0, (i - 1) * (opts.spacing or 160)), radius = opts.radius, keep = true, enemies = opts.enemies })
		table.insert(results, m.name .. ": " .. P.castThrough({ id = opts.id, level = opts.level, freezeAt = m.t, scene = scene, camera = m.cameras[1] }))
		for _, cam in m.cameras do
			local c = CAMERAS[cam]
			local from, to = scene.C + c[1], scene.C + c[2]
			table.insert(lines, string.format("%s_L%d_%s_%s | %.1f, %.1f, %.1f | %.1f, %.1f, %.1f",
				opts.id, opts.level, m.name, cam, from.X, from.Y, from.Z, to.X, to.Y, to.Z))
		end
	end
	return table.concat(results, "\n") .. "\n" .. table.concat(lines, "\n")
end

-- 3x5 pixel font for the filmstrip labels (rows top to bottom, "1" = lit)
local GLYPHS = {
	A = "010101111101101", B = "110101110101110", C = "011100100100011", D = "110101101101110",
	E = "111100110100111", F = "111100110100100", G = "011100101101011", H = "101101111101101",
	I = "111010010010111", K = "101101110101101", L = "100100100100111", M = "101111111101101",
	N = "110101101101101", O = "010101101101010", P = "110101110100100", R = "110101110101101",
	S = "011100010001110", T = "111010010010010", U = "101101101101111", V = "101101101101010",
	W = "101101111111101", X = "101101010101101", Y = "101101010010010", J = "001001001101010",
	Q = "010101101110011", Z = "111001010100111",
	["0"] = "111101101101111", ["1"] = "010110010010111", ["2"] = "110001010100111",
	["3"] = "110001010001110", ["4"] = "101101111001001", ["5"] = "111100110001110",
	["6"] = "011100111101111", ["7"] = "111001010010010", ["8"] = "111101111101111",
	["9"] = "111101111001110", ["+"] = "000010111010000", ["-"] = "000000111000000",
	["."] = "000000000000010", [" "] = "000000000000000",
}

-- `text` in Neon pixel runs, centred on `cf` (its Right/Up span the text), `px` studs a pixel
local function label(parent, text, cf, px, color)
	text = string.upper(text)
	local width = #text * 4 - 1
	local folder = Instance.new("Folder")
	folder.Name = "Label"
	for i = 1, #text do
		local g = GLYPHS[text:sub(i, i)] or GLYPHS[" "]
		for row = 0, 4 do
			local bits = g:sub(row * 3 + 1, row * 3 + 3)
			local col = 1
			while col <= 3 do
				if bits:sub(col, col) == "1" then
					local run = col
					while run < 3 and bits:sub(run + 1, run + 1) == "1" do
						run += 1
					end
					local x0 = (i - 1) * 4 + (col - 1)
					local cx = (x0 + (run - col + 1) / 2 - width / 2) * px
					local cy = (2.5 - row - 0.5) * px
					local p = Instance.new("Part")
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
					p.Material = Enum.Material.Neon
					p.Color = color
					p.Size = Vector3.new((run - col + 1) * px, px, 0.05)
					p.CFrame = cf * CFrame.new(cx, cy, 0)
					p.Parent = folder
					col = run + 1
				else
					col += 1
				end
			end
		end
	end
	folder.Parent = parent
	return folder
end

function P.filmstrip(opts)
	local holder = P.fresh({ "TechniqueVFX" })
	local Rules = require(holder.Shared.ActionRules)
	local Techniques = require(holder.Shared.Techniques)
	local profile = Rules.castProfile(Techniques.Defs[opts.id])
	local lag = opts.lag or 0.1
	local w, a, r = profile.windup, profile.active, profile.recovery
	local moments = opts.moments or {
		{ name = "anticipation", t = w * 0.4 },
		{ name = "windup", t = w * 0.85 },
		{ name = "release", t = w + 0.06 + lag },
		{ name = "active", t = w + a * 0.5 + lag },
		{ name = "hitstop", t = w + a + lag },
		{ name = "aftermath", t = w + a + r + 0.3 + lag },
	}
	P.clear()
	local cols = opts.cols or 3
	local rows = math.ceil(#moments / cols)
	local radius = opts.radius or 6
	local cellW = math.max(26, radius * 2 + 12)
	-- open sky above everything (the testbed's Arena baseplate tops out at 648.6)
	local base = opts.center or Vector3.new(400, 1200, 300)
	-- the player-view direction (CAMERAS.player); cells sit on the plane square to it
	local view = CFrame.lookAt(CAMERAS.player[1], CAMERAS.player[2])
	local right, up = view.RightVector, view.UpVector
	-- a cell's screen height: the plate's footprint, enemies standing on it, a label row
	local half = (cellW - 4) / 2
	local longest = 0
	for i, m in moments do
		longest = math.max(longest, #string.format("%d %s %dms", i, m.name, math.round(m.t * 1000)))
	end
	local px = math.min(cellW / 70, (cellW - 3) / (longest * 4))
	local plateDown = half * (math.abs(up.X) + math.abs(up.Z)) + 1.5
	local cellH = plateDown * 2 + 7 * math.abs(up.Y) + px * 7 + 2
	local fov = opts.fov or 18
	local camera = workspace.CurrentCamera
	P._fov = P._fov or camera.FieldOfView
	local SG = game:GetService("StarterGui")
	if P._devGui == nil then
		P._devGui = SG.ShowDevelopmentGui
	end
	SG.ShowDevelopmentGui = false -- the HUD covers the bottom row
	local results, scenes = {}, {}
	for i, m in moments do
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		local C = base + right * ((col - (cols - 1) / 2) * cellW) - up * ((row - (rows - 1) / 2) * cellH)
		local scene = P.scene({ center = C, radius = opts.radius, keep = true, enemies = opts.enemies,
			floor = cellW - 4, floorColor = Color3.fromRGB(28, 30, 36) })
		scenes[i] = scene
		local ms = math.round(m.t * 1000)
		results[i] = string.format("%d %s %dms: %s", i, m.name, ms, P.castThrough({ id = opts.id, level = opts.level, freezeAt = m.t, scene = scene, camera = "player" }))
		-- label under the cell, square to the camera
		-- the label just under the plate's front lip, pulled toward the camera so
		-- nothing hides it (a near-orthographic view keeps its screen spot)
		local at = scene.C - up * (plateDown + px * 4) - view.LookVector * 30
		label(scene.folder, string.format("%d %s %dms", i, m.name, ms), CFrame.fromMatrix(at, right, up), px, Color3.fromRGB(255, 220, 120))
	end
	-- park far back along the view so the whole grid fits, narrow FOV
	local mid = base - up * (px * 3)
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local halfV = math.rad(fov) / 2
	local halfH = math.atan(math.tan(halfV) * aspect)
	local need = math.max((cols * cellW / 2 + 1) / math.tan(halfH), (rows * cellH / 2 + px * 4) / math.tan(halfV))
	local from = mid - view.LookVector * need
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(from, mid)
	table.insert(results, 1, string.format("camera %.1f, %.1f, %.1f | look %.1f, %.1f, %.1f | fov %d (%d x %d cells, %.0f studs each)",
		from.X, from.Y, from.Z, mid.X, mid.Y, mid.Z, fov, cols, rows, cellW))
	return table.concat(results, "\n")
end

_G.vfxPreview = P
return "vfxPreview installed"
