--!nocheck
-- Review stage: the live "watch the agent work" view a visual agent keeps running in its
-- sandbox Studio (Edit mode) so the user sees the current state while the agent works.
-- One stage at a time on a lit plate at y 1200 (open sky, clear of the testbed's baseplate),
-- the editor camera parked on it; calling any mode replaces the previous stage.
-- Docs: docs/tools.md ("Review stage"); the spec agents follow is the visual-gate skill,
-- "Show the work live".
--
-- Load (serve your worktree on a port of your own, e.g. `python3 -m http.server 8785`):
--   _G.REVIEW_STAGE = { base = "http://127.0.0.1:8785/" } -- optional; where motion_probe/specs load from
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8785/tools/review_stage.luau?" .. os.clock()))()
--   local R = _G.reviewStage
--
--   R.model{ source, scale?, turn? = true, speed? = 16, rig? = true, flat? = false, fx? = true }
--       The body or prop beside a 5-stud R6, turning once every `speed` seconds. source: an
--       Enemies def id (its `body`), a name in ServerStorage.Enemies / WeaponModels /
--       ItemTemplates, a dotted path (Workspace._MyStaging.Wolf) or an Instance. scale
--       multiplies the template's own. Game lighting; flat = true for model_shot's flat light.
--       fx = false disables the template's emitters, beams and lights.
--   R.anim{ spec, move, loop? = true, every?, fx? = true, cues? = true }
--       The move looping on the posed rig in real time, from art/enemies/motion_probe.luau
--       (`keep = true`) and its FK, with the state (windup/dash/recover) and ms on a label.
--       spec: a name in art/enemies/motion_specs.luau ("NineTailFox") or a full probe spec.
--       move: an attack name or a probe move spec ({ attack, dash?, next? } / { loop = "run",
--       speed = 14 } / "Stagger"). Its Client.EnemyFX.<def> cues (windup, strike, dash, land,
--       stagger, death; `ready` once at the start) fire at their beats with the model's
--       Attack / AIState / StateAt set as the server would. every: the loop period (default
--       the clip, which already has the probe's 0.2 s idle lead and 0.6 s tail). loop = false
--       plays it once and holds the last pose.
--   R.cast{ id, level? = 10, weapon?, every?, targets? = { "SpiritWolf" } }
--       The technique on an R6 through the real cast path (fresh copies of CombatEffects, Sfx,
--       TechniqueVFX, CastFX, TechniqueFX: CombatEffects.windup at the start, .cast at Hit,
--       the clip at the cast's playback speed, a weapon technique's lunge), re-cast every
--       `every` seconds (default the clip at cast speed + 2 s), sounds through Sfx. weapon: a
--       Weapons item id ("IronJian") or a WeaponModels name; default the first item of the
--       technique's class (none for Fist/Any). targets: enemy templates stood in its path
--       (tagged Enemy) so hit effects play; false for none.
--   R.enemy{ template, cue, every?, cues? }
--       The beast playing the move with its effect cues: with a motion spec for the template
--       (motion_specs, matched by template or def), exactly anim; otherwise the body stands
--       still and the cues fire on the def's timings (windup, dash, recover). cue: the attack
--       name. cues: an explicit enemy_fx_shot-style list { { "windup", "crownfall", 1.25 },
--       { "strike", "crownfall", at = 1.25 } } instead.
--   R.ui{ screen, size? = "pc", sample?, show? }
--       A copy of StarterGui.<screen> as the unmapped StarterGui._ReviewStage, laid out inside
--       a stand-in screen ("phone" 844x390, "pc" 1920x1080, "full" the viewport, or a
--       Vector2), scaled to fit the viewport with the rest letterboxed; every other ScreenGui
--       is disabled until stop(). The camera sits on the plate behind an R6, like play.
--       sample: { ["Stack.Vitals.Name"] = "Text" | { Text = ..., Visible = ... } } (paths
--       under the screen) or function(gui, root). show: paths to make Visible.
--   R.camera{ view? = "34" | "front" | "side" | "top" | "player", pos?, look?, fov?, zoom? }
--       Re-aims the parked camera (pos/look: Vector3s or {x,y,z}); zoom > 1 moves closer.
--   R.stop()   Removes the stage (Workspace._ReviewStage, StarterGui._ReviewStage, the module
--       copies), ends its loop and restores the camera, lighting, the dev GUI and the
--       ScreenGuis it disabled. It also cleans up after a lost _G: the state lives in
--       attributes (Workspace._ReviewStageGen, the folder's CamCFrame/CamFov, `_rs_*` on
--       Lighting, StarterGui and each ScreenGui), and every loop ends itself once the
--       generation changes or its folder is gone.
-- Every call returns a one-line summary (what is staged, the camera). Nothing in a mapped
-- folder is touched: templates are cloned, modules are copied to ServerStorage._ReviewStageModules.
-- Edit-mode particles only simulate near the camera, so the stage parks it there; to take a
-- screen_capture, pass the camera R.camera returns (`camera_position` / `look_at_position`).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local PhysicsService = game:GetService("PhysicsService")

local FOLDER = "_ReviewStage"
local MODULES = "_ReviewStageModules"
local GEN_ATTR = "_ReviewStageGen"
local RIG_GROUP = "_ReviewStageRig"
local AT = Vector3.new(400, 1200, -300) -- the plate's top centre: open sky, far from the arena
local PLATE_COLOR = Color3.fromRGB(86, 90, 98)
local FOV = 40
local SIZES = { phone = Vector2.new(844, 390), pc = Vector2.new(1920, 1080) }
local DEFAULT_STATE = { windup = "windup", strike = "recover", dash = "dash", land = "recover", stagger = "stagger", death = "recover" }

local R = { base = (_G.REVIEW_STAGE and _G.REVIEW_STAGE.base) or "http://127.0.0.1:8785/" }
local S = nil -- the current stage

------------------------------------------------------------------------------------------
-- helpers

local function v3(v)
	if typeof(v) == "Vector3" then
		return v
	end
	return Vector3.new(v[1], v[2], v[3])
end

local function fmt(v)
	return string.format("[%.1f,%.1f,%.1f]", v.X, v.Y, v.Z)
end

local function resolvePath(path, root)
	local node = root or game
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

local function enemyDefs()
	local ok, defs = pcall(function()
		local copy = ReplicatedStorage.Shared.Enemies:Clone() -- a fresh require, not the cached one
		copy.Name = "_ReviewStageEnemies"
		copy.Parent = ReplicatedStorage.Shared
		local ok2, r = pcall(require, copy)
		copy:Destroy()
		assert(ok2, r)
		return r
	end)
	if ok and type(defs) == "table" then
		return defs.Defs or defs
	end
	return {}
end

local function resolveSource(source)
	if typeof(source) == "Instance" then
		return source
	end
	assert(type(source) == "string", "review_stage: source must be a name, a dotted path or an Instance")
	if string.find(source, "%.") then
		return resolvePath(source) or error("review_stage: no instance at " .. source)
	end
	local name = source
	local def = enemyDefs()[source]
	if type(def) == "table" and type(def.body) == "string" then
		name = def.body
	end
	for _, f in { "Enemies", "WeaponModels", "ItemTemplates" } do
		local folder = ServerStorage:FindFirstChild(f)
		local t = folder and folder:FindFirstChild(name)
		if t then
			return t
		end
	end
	error("review_stage: no template named " .. name .. " (from " .. source .. ")")
end

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
	assert(lo.X < math.huge, "review_stage: the model has no visible parts")
	return lo, hi
end

-- An anchored, inert copy wrapped in a Model. Effects stay on unless fx == false.
local function cloneClean(template, scale, fx)
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
			d.CanCollide, d.CanTouch = false, false
			d.CanQuery = false
		elseif d:IsA("BaseScript") or d:IsA("ProximityPrompt") or d:IsA("LayerCollector") then
			d:Destroy()
		elseif fx == false and (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")) then
			d.Enabled = false
		end
	end
	if scale and scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	return model
end

local function placeOnGround(model, spot)
	local lo, hi = bounds(model)
	model:PivotTo(model:GetPivot() + (spot - Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)))
end

local function inGroup(model)
	if not PhysicsService:IsCollisionGroupRegistered(RIG_GROUP) then
		PhysicsService:RegisterCollisionGroup(RIG_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(RIG_GROUP, "Default", false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = RIG_GROUP -- ground rays (default raycasts) skip it, like a player's character
		end
	end
end

-- A real 5-stud R6 (Players:CreateHumanoidModelFromDescription works in Edit), or six grey
-- blocks if that fails. anchorAll: a statue for scale; else only the root (cast drives the motors).
local function makeR6(anchorAll)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	end)
	if ok and rig then
		for _, d in rig:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			end
		end
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = anchorAll or d.Name == "HumanoidRootPart"
				d.CastShadow = true
			end
		end
		local colors = rig:FindFirstChildOfClass("BodyColors")
		if colors then -- a neutral light grey, so it reads against the plate and the sky
			for _, k in { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
				colors[k] = Color3.fromRGB(205, 205, 210)
			end
		end
		local hum = rig:FindFirstChildOfClass("Humanoid")
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
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
			p.Name, p.Size, p.CFrame, p.Anchored = name, s[1], CFrame.new(s[2]), true
			p.Material, p.Color = Enum.Material.SmoothPlastic, Color3.fromRGB(205, 205, 210)
			p.Parent = rig
		end
	end
	rig.Name = "R6"
	inGroup(rig)
	return rig
end

-- the rig standing with its feet on `spot`, facing `dir`
local function standR6(rig, spot, dir)
	local p = rig:GetPivot().Position
	rig:PivotTo(CFrame.lookAt(p, p + Vector3.new(dir.X, 0, dir.Z)))
	placeOnGround(rig, spot)
end

------------------------------------------------------------------------------------------
-- environment: lighting, dev GUI, ScreenGuis (all restored from attributes)

local LIGHT_KEYS = { "ClockTime", "Ambient", "OutdoorAmbient", "Brightness" }

local function flatLighting()
	if Lighting:GetAttribute("_rs_ClockTime") == nil then
		for _, k in LIGHT_KEYS do
			Lighting:SetAttribute("_rs_" .. k, Lighting[k])
		end
		for _, e in Lighting:GetChildren() do
			if e:IsA("PostEffect") then
				e:SetAttribute("_rs_Enabled", e.Enabled)
			elseif e:IsA("Atmosphere") then
				e:SetAttribute("_rs_Density", e.Density)
			end
		end
	end
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
	if Lighting:GetAttribute("_rs_ClockTime") ~= nil then
		for _, k in LIGHT_KEYS do
			Lighting[k] = Lighting:GetAttribute("_rs_" .. k)
			Lighting:SetAttribute("_rs_" .. k, nil)
		end
	end
	for _, e in Lighting:GetChildren() do
		for _, k in { "Enabled", "Density" } do
			local v = e:GetAttribute("_rs_" .. k)
			if v ~= nil then
				e[k] = v
				e:SetAttribute("_rs_" .. k, nil)
			end
		end
	end
end

local function setDevGui(on)
	if StarterGui:GetAttribute("_rs_ShowDevelopmentGui") == nil then
		StarterGui:SetAttribute("_rs_ShowDevelopmentGui", StarterGui.ShowDevelopmentGui)
	end
	StarterGui.ShowDevelopmentGui = on
end

local function restoreGuis(keepDev)
	local dev = StarterGui:GetAttribute("_rs_ShowDevelopmentGui")
	-- between stages the dev GUI keeps its state: flipping it back and forth in one frame
	-- left the HUD drawn over the next stage (model_shot found the same)
	if dev ~= nil and not keepDev then
		StarterGui.ShowDevelopmentGui = dev
		StarterGui:SetAttribute("_rs_ShowDevelopmentGui", nil)
	end
	for _, g in StarterGui:GetChildren() do
		local was = g:GetAttribute("_rs_Enabled")
		if was ~= nil then
			g.Enabled = was
			g:SetAttribute("_rs_Enabled", nil)
		end
	end
	while StarterGui:FindFirstChild(FOLDER) do
		StarterGui[FOLDER]:Destroy()
	end
end

------------------------------------------------------------------------------------------
-- fresh module copies (Edit's require cache holds stale versions; the live ones are never
-- required or changed). Effects go to the stage's Effects folder (screen_capture swaps the
-- camera, and a Camera's children only render while it is current); camera shake and
-- impact frames are stripped (they move the editor camera).

local function freshModules(names)
	local old = ServerStorage:FindFirstChild(MODULES)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Folder")
	holder.Name = MODULES
	ReplicatedStorage.Shared:Clone().Parent = holder
	local client = game.StarterPlayer.StarterPlayerScripts.Client
	for _, n in names do
		local m = client:FindFirstChild(n)
		if m then
			m:Clone().Parent = holder
		end
	end
	local path = 'game:GetService("ServerStorage").' .. MODULES .. ".Shared"
	for _, m in holder:GetDescendants() do
		if m:IsA("ModuleScript") and m.Parent ~= holder.Shared and not m:IsDescendantOf(holder.Shared) then
			m.Source = m.Source:gsub("ReplicatedStorage%.Shared", path)
		end
	end
	holder.Parent = ServerStorage
	local tv = holder:FindFirstChild("TechniqueVFX")
	if tv then
		local TV = require(tv)
		TV.folder = S.fx
		local emit = TV.emit
		TV.emit = function(inst, ...)
			for _, d in inst:GetDescendants() do
				d:SetAttribute("CameraShake", nil)
				d:SetAttribute("ImpactFrames", nil)
			end
			return emit(inst, ...)
		end
	end
	return holder
end

------------------------------------------------------------------------------------------
-- the stage

local function clear(keepEnv)
	workspace:SetAttribute(GEN_ATTR, (workspace:GetAttribute(GEN_ATTR) or 0) + 1) -- ends every loop
	local saved = nil
	if S and S.conn then
		S.conn:Disconnect()
	end
	if S and S.onStop then
		pcall(S.onStop)
	end
	for _, f in workspace:GetChildren() do
		if f.Name == FOLDER then
			saved = saved or { cf = f:GetAttribute("CamCFrame"), fov = f:GetAttribute("CamFov") }
			f:Destroy()
		end
	end
	local mods = ServerStorage:FindFirstChild(MODULES)
	if mods then
		mods:Destroy()
	end
	restoreGuis(keepEnv)
	restoreLighting()
	pcall(function()
		RunService:UnbindFromRenderStep("CombatShake")
	end)
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		temp:ClearAllChildren()
	end
	S = nil
	if not keepEnv then
		local cam = workspace.CurrentCamera
		if saved and saved.cf then
			cam.CFrame = saved.cf
		end
		if saved and saved.fov then
			cam.FieldOfView = saved.fov
		end
		if PhysicsService:IsCollisionGroupRegistered(RIG_GROUP) then
			PhysicsService:UnregisterCollisionGroup(RIG_GROUP)
		end
	end
	return saved
end

-- Labels are spelt in small Neon parts (vfx_preview's 3x5 font): a BillboardGui on a part
-- didn't show in screen_capture. Two lines over the content, square to the parked camera:
-- the title (gold) and the state (white), rebuilt only when the state changes.
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
	["."] = "000000000000010", [" "] = "000000000000000", [":"] = "000010000010000",
}

local function glyphs(parent, text, cf, px, color)
	text = string.upper(text)
	local width = #text * 4 - 1
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
					local p = Instance.new("Part")
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
					p.Material = Enum.Material.Neon
					p.Color = color
					p.Size = Vector3.new((run - col + 1) * px, px, 0.05)
					p.CFrame = cf * CFrame.new((x0 + (run - col + 1) / 2 - width / 2) * px, (2.5 - row - 0.5) * px, 0)
					p.Parent = parent
					col = run + 1
				else
					col += 1
				end
			end
		end
	end
end

local function drawLabel(st)
	if not st.labelPart then
		return
	end
	local old = st.folder:FindFirstChild("LabelText")
	if old then
		old:Destroy()
	end
	if st.labelOff then
		return
	end
	local cam = workspace.CurrentCamera
	local at = st.labelPart.Position
	local from = st.camPos or cam.CFrame.Position
	local view = CFrame.lookAt(from, at)
	local px = math.clamp((from - at).Magnitude * 0.0042, 0.08, 2)
	local f = Instance.new("Folder")
	f.Name = "LabelText"
	glyphs(f, st.title, CFrame.fromMatrix(at + view.UpVector * px * 4, view.RightVector, view.UpVector), px, Color3.fromRGB(255, 214, 110))
	if st.lastLine and st.lastLine ~= "" then
		glyphs(f, st.lastLine, CFrame.fromMatrix(at - view.UpVector * px * 3, view.RightVector, view.UpVector), px, Color3.new(1, 1, 1))
	end
	f.Parent = st.folder
end

local function label(st, text)
	local p = Instance.new("Part")
	p.Name = "LabelAnchor"
	p.Size = Vector3.one * 0.2
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Position = AT
	p.Parent = st.folder
	st.labelPart = p
	st.title = text
end

local function setLabel(st, line)
	if st.lastLine ~= line then
		st.lastLine = line
		drawLabel(st)
	end
end

local function begin(kind, title, opts)
	local saved = clear(true)
	local cam = workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	CollectionService:AddTag(folder, "EditorOnly")
	folder:SetAttribute("Mode", kind)
	folder:SetAttribute("CamCFrame", saved and saved.cf or cam.CFrame)
	folder:SetAttribute("CamFov", saved and saved.fov or cam.FieldOfView)
	local fx = Instance.new("Folder")
	fx.Name = "Effects"
	fx.Parent = folder
	folder.Parent = workspace
	local gen = workspace:GetAttribute(GEN_ATTR)
	folder:SetAttribute("Gen", gen)
	if opts.flat then
		flatLighting()
	end
	setDevGui(kind == "ui") -- the HUD draws over the 3D stage in Edit mode
	S = { folder = folder, fx = fx, gen = gen, kind = kind, pts = {}, opts = opts }
	-- the plate (resized to fit by fitPlate) and a soft fill from above, so it reads at night too
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored, plate.CanCollide, plate.CanTouch = true, true, false
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = PLATE_COLOR
	plate.Size = Vector3.new(30, 1, 30)
	plate.CFrame = CFrame.new(AT - Vector3.new(0, 0.5, 0))
	plate.Parent = folder
	S.plate = plate
	local lamp = Instance.new("Part")
	lamp.Name = "Fill"
	lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch, lamp.CastShadow = true, false, false, false, false
	lamp.Transparency = 1
	lamp.Size = Vector3.one
	lamp.CFrame = CFrame.new(AT + Vector3.new(-8, 40, -8))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 90
	light.Range = 60
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = lamp
	lamp.Parent = folder
	label(S, title)
	return S
end

local function fitPlate(st, radius)
	local r = math.max(15, radius * 1.4 + 4)
	st.plate.Size = Vector3.new(r * 2, 1, r * 2)
end

local function addPts(st, lo, hi)
	for _, x in { lo.X, hi.X } do
		for _, y in { lo.Y, hi.Y } do
			for _, z in { lo.Z, hi.Z } do
				table.insert(st.pts, Vector3.new(x, y, z))
			end
		end
	end
end

-- a vertical cylinder of points (for content that turns)
local function addCylinder(st, centre, r, y0, y1)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		for _, y in { y0, y1 } do
			table.insert(st.pts, Vector3.new(centre.X + math.cos(a) * r, y, centre.Z + math.sin(a) * r))
		end
	end
end

local VIEWS = {
	["34"] = Vector3.new(-1, 0.45, -1).Unit,
	front = Vector3.new(0, 0.12, -1).Unit,
	side = Vector3.new(-1, 0.12, 0).Unit,
	top = Vector3.new(0.02, 1, -0.05).Unit,
	player = Vector3.new(-1, 0.5, 0.42).Unit, -- behind-left of a caster facing +X
}

-- camera distance along dir (target -> camera) that fits every point, and the recentred target
local function fit(pts, target, dir, fov, aspect, fill)
	local look = -dir.Unit
	local right = look:Cross(Vector3.yAxis)
	right = if right.Magnitude < 1e-3 then Vector3.xAxis else right.Unit
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
		need = math.max(need, math.max(math.abs(r:Dot(right)) / tanH, math.abs(r:Dot(up)) / tanV) * fill - r:Dot(look))
	end
	return need, target
end

local function park(pos, look, fov)
	local cam = workspace.CurrentCamera
	cam.FieldOfView = fov
	cam.CFrame = CFrame.lookAt(pos, look)
	cam.Focus = CFrame.new(look)
	if S then
		S.camPos, S.camLook = pos, look
		S.folder:SetAttribute("CamView", string.format("%s %s", fmt(pos), fmt(look)))
		drawLabel(S)
	end
	return string.format("camera_position=%s look_at_position=%s fov %d", fmt(pos), fmt(look), fov)
end

function R.camera(o)
	o = o or {}
	assert(S, "review_stage: nothing staged")
	local fov = o.fov or S.fov or FOV
	S.fov = fov
	if o.pos and o.look then
		return park(v3(o.pos), v3(o.look), fov)
	end
	local view = o.view or S.view or "34"
	S.view = view
	local dir = VIEWS[view] or error("review_stage: no view " .. tostring(view))
	local cam = workspace.CurrentCamera
	local aspect = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
	local pts = table.clone(S.pts)
	if S.labelPart and not S.labelOff then
		table.insert(pts, S.labelPart.Position + Vector3.new(0, 1.5, 0)) -- the label's top line
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in pts do
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local d, t = fit(pts, (lo + hi) / 2, dir, fov, aspect, 1.12)
	d /= o.zoom or 1
	return park(t + dir * d, t, fov)
end

local function loop(st, step)
	local gen, folder = st.gen, st.folder
	local conn
	st.t0 = os.clock()
	conn = RunService.Heartbeat:Connect(function(dt)
		if workspace:GetAttribute(GEN_ATTR) ~= gen or not folder.Parent then
			conn:Disconnect()
			return
		end
		local ok, err = pcall(step, dt, os.clock() - st.t0)
		pcall(function()
			RunService:UnbindFromRenderStep("CombatShake") -- a shake moves the editor camera
		end)
		if not ok then
			conn:Disconnect()
			setLabel(st, "stopped - error, see output")
			warn("review_stage: " .. tostring(err))
		end
	end)
	st.conn = conn
end

local function done(st, what, cam)
	return string.format("review_stage %s: %s | %s | stop: _G.reviewStage.stop()", st.kind, what, cam)
end

------------------------------------------------------------------------------------------
-- model

function R.model(o)
	o = o or {}
	local template = resolveSource(o.source)
	local st = begin("model", template.Name, o)
	local model = cloneClean(template, o.scale, o.fx)
	placeOnGround(model, AT)
	model.Parent = st.folder
	local lo, hi = bounds(model)
	local centre = Vector3.new((lo.X + hi.X) / 2, AT.Y, (lo.Z + hi.Z) / 2)
	local r = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			r = math.max(r, ((p.Position - centre) * Vector3.new(1, 0, 1)).Magnitude + p.Size.Magnitude / 2)
		end
	end
	r = math.min(r, math.max(hi.X - lo.X, hi.Z - lo.Z) * 0.75)
	addCylinder(st, centre, r, lo.Y, hi.Y)
	if o.rig ~= false then
		local rig = makeR6(true)
		-- beside the model at the same depth from the 3/4 camera (screen right of it)
		local side = Vector3.new(-1, 0, 1).Unit
		standR6(rig, centre + side * (r + 3), Vector3.new(-1, 0, -1))
		rig.Parent = st.folder
		local a, b = bounds(rig)
		addPts(st, a, b)
	end
	fitPlate(st, r + (if o.rig ~= false then 5 else 0))
	st.labelPart.Position = Vector3.new(centre.X, hi.Y + 2, centre.Z)
	local rel = CFrame.new(centre):ToObjectSpace(model:GetPivot())
	local period = o.speed or 16
	local angle = 0
	if o.turn ~= false then
		loop(st, function(dt)
			angle += dt * math.pi * 2 / period
			model:PivotTo(CFrame.new(centre) * CFrame.Angles(0, angle, 0) * rel)
		end)
	end
	local cam = R.camera({ view = o.view or "34", fov = o.fov })
	return done(st, string.format("%s %.1f x %.1f x %.1f studs", template.Name, hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z), cam)
end

------------------------------------------------------------------------------------------
-- beasts: poses (motion probe) and effect cues

local function attackOf(def, name)
	if not (def and name) then
		return nil
	end
	if def.attack and def.attack.name == name then
		return def.attack
	end
	for _, a in def.pattern or {} do
		if a.name == name then
			return a
		end
	end
	if def.phaseCall and def.phaseCall.name == name then
		return def.phaseCall
	end
	if def.pack and def.pack.howl and def.pack.howl.name == name then
		return def.pack.howl
	end
	return nil
end

local function loadRemote(path)
	local src = HttpService:GetAsync(R.base .. path .. "?" .. os.clock())
	return assert(loadstring(src, "=" .. path))()
end

local function specFor(template, def)
	local ok, S2 = pcall(loadRemote, "art/enemies/motion_specs.luau")
	if not ok then
		return nil
	end
	for name, spec in S2.specs do
		if spec.template == template or spec.def == def or name == template or name == def then
			return S2.with(name)
		end
	end
	return nil
end

local function runProbe(spec, move)
	local cfg = table.clone(spec)
	cfg.moves = { move }
	cfg.keep, cfg.quiet = true, true
	local prev = _G.MOTION
	_G.MOTION = cfg
	local ok, err = pcall(loadRemote, "art/enemies/motion_probe.luau")
	_G.MOTION = prev
	assert(ok, err)
	return _G.MOTION_RESULTS[1], _G.MOTION_FK
end

-- the cue list of one move from the probe's state timeline (or from the def's timings)
local function cuesFromStates(states, attacks)
	local events, k, dashAttack = {}, 0, nil
	local current = nil
	for i, s in states do
		local prev = states[i - 1]
		if s.name == "windup" then
			k += 1
			current = attacks[k] or current
			table.insert(events, { t = s.from, state = "windup", attack = current, cue = "windup", seconds = s.to - s.from })
		end
		if prev and prev.name == "windup" and (s.name == "dash" or s.name == "recover") then
			table.insert(events, { t = s.from, cue = "strike", attack = current })
		end
		if s.name == "dash" then
			dashAttack = current
			table.insert(events, { t = s.from, state = "dash", cue = "dash", attack = current })
		end
		if prev and prev.name == "dash" and s.name ~= "dash" then
			table.insert(events, { t = s.from, cue = "land", attack = dashAttack })
		end
		if s.name == "recover" then
			table.insert(events, { t = s.from, state = "recover", attack = current })
		elseif s.name == "stagger" or s.name == "death" then
			table.insert(events, { t = s.from, state = s.name, cue = s.name })
		elseif s.name == "idle" and i > 1 then
			table.insert(events, { t = s.from, state = "chase" })
		elseif s.name ~= "windup" and s.name ~= "dash" and s.name ~= "idle" then
			table.insert(events, { t = s.from, state = "chase" }) -- a loop (walk, run)
		end
	end
	table.sort(events, function(a, b)
		return a.t < b.t
	end)
	return events
end

local function defStates(def, attack)
	local a = attackOf(def, attack) or error("review_stage: no attack " .. tostring(attack))
	local states, t = { { name = "idle", from = 0, to = 0.3 } }, 0.3
	local function add(name, secs)
		table.insert(states, { name = name, from = t, to = t + secs })
		t += secs
	end
	add("windup", a.windup or 0.5)
	if a.dashSpeed or a.kind == "leap" or a.kind == "bound" or a.kind == "retreat" then
		add("dash", a.active or (if a.length and a.dashSpeed then a.length / a.dashSpeed else 0.5))
	end
	add("recover", a.recover or 0.5)
	add("idle", 0.6)
	return states, t
end

local function moveAttacks(move)
	if type(move) == "string" then
		return if move == "Stagger" or move == "Death" then {} else { move }
	end
	if move.chain then
		return move.chain
	end
	local list = {}
	if move.attack and move.attack ~= "Stagger" and move.attack ~= "Death" then
		table.insert(list, move.attack)
	end
	if move.next then
		table.insert(list, move.next)
	end
	return list
end

local function beast(o)
	local st = o.st
	local defs = enemyDefs()
	local defName = o.def
	local def = defs[defName]
	local root, model, parts, frames, clipLen, dt
	local lo, hi
	if o.res then
		-- posed: one clone of the template, its parts placed from the probe's FK each frame
		local res, F = o.res, o.F
		local template = F.template
		local hrp = template.HumanoidRootPart
		local hrpRest = hrp.CFrame
		model = template:Clone()
		local src, dst = template:GetDescendants(), model:GetDescendants()
		assert(#src == #dst, "review_stage: clone order differs from the template")
		local srcParts = {}
		parts = {}
		for k, d in dst do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
				table.insert(parts, d)
				table.insert(srcParts, src[k])
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") or d:IsA("LuaSourceContainer")
				or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		local base = CFrame.new(AT.X - hrp.Position.X, AT.Y - F.restLow, AT.Z - hrp.Position.Z)
		frames = {}
		for i, f in res.frames do
			local world = F.fk(f.pose)
			local place = base + Vector3.new(0, f.lift or 0, 0)
			local cfs = table.create(#parts)
			for k, s in srcParts do
				cfs[k] = place * (world[s] or (world[hrp] * hrpRest:ToObjectSpace(s.CFrame)))
			end
			frames[i] = { t = f.t, cfs = cfs, st = f.st }
			if i % 15 == 0 then
				task.wait()
			end
		end
		dt = if #res.frames > 1 then res.frames[2].t - res.frames[1].t else 1 / 30
		clipLen = res.frames[#res.frames].t + dt
		workspace:BulkMoveTo(parts, frames[1].cfs, Enum.BulkMoveMode.FireCFrameChanged)
		root = model:FindFirstChild("HumanoidRootPart")
		o.events = o.events or cuesFromStates(res.states, moveAttacks(o.move))
		o.states = res.states
	else
		local template = ServerStorage.Enemies:FindFirstChild(o.template) or error("review_stage: no template " .. tostring(o.template))
		model = cloneClean(template)
		placeOnGround(model, AT)
		root = model:FindFirstChild("HumanoidRootPart")
		if not o.events then
			local states, total = defStates(def, o.attack)
			o.events = cuesFromStates(states, { o.attack })
			o.states = states
			clipLen = total
		end
		clipLen = clipLen or 0
		for _, e in o.events do
			clipLen = math.max(clipLen, e.t + (e.seconds or 0) + 1)
		end
	end
	model.Name = o.template
	model:SetAttribute("Template", o.template)
	model:SetAttribute("EnemyType", defName)
	model:SetAttribute("Health", 1000)
	model:SetAttribute("MaxHealth", 1900)
	model:SetAttribute("AIState", "chase")
	model.Parent = st.folder
	lo, hi = bounds(model)
	local centre = Vector3.new((lo.X + hi.X) / 2, AT.Y, (lo.Z + hi.Z) / 2)
	local reach = math.max(hi.X - lo.X, hi.Z - lo.Z)
	addPts(st, lo - Vector3.new(1, 0, 1) * reach * 0.15, hi + Vector3.new(1, 0.5, 1) * reach * 0.15)
	-- the R6: the move's target, ahead of the beast (it faces -Z), for scale
	local look = if root then (root.CFrame.LookVector * Vector3.new(1, 0, 1)) else Vector3.new(0, 0, -1)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local rig = makeR6(true)
	local ahead = reach * 0.5 + 6
	standR6(rig, centre + look * ahead, -look)
	rig.Name = "Target"
	rig.Parent = st.folder
	local a, b = bounds(rig)
	addPts(st, a, b)
	fitPlate(st, ahead + 3)
	st.labelPart.Position = Vector3.new(centre.X, hi.Y + 2, centre.Z)

	-- the effect handlers (fresh copies), if the beast has any
	local handlers = nil
	if o.fx ~= false and o.cuesOn ~= false then
		local holder = freshModules({ "TechniqueVFX", "Sfx", "CastFX", "CombatEffects", "EnemyFX" })
		local mod = holder:FindFirstChild("EnemyFX") and holder.EnemyFX:FindFirstChild(defName or "")
		if mod then
			local ok, h = pcall(require, mod)
			if ok and type(h) == "table" then
				handlers = h
			else
				warn("review_stage: EnemyFX." .. tostring(defName) .. " failed to load: " .. tostring(h))
			end
		end
	end
	local function fire(name, ev, late)
		local fn = handlers and handlers[name]
		if not fn then
			return
		end
		local at = workspace:GetServerTimeNow() - (late or 0)
		local cue = {
			model = model, root = root, kind = defName, attack = ev and ev.attack or model:GetAttribute("Attack"),
			seconds = ev and ev.seconds, target = rig, at = at,
			shape = ev and ev.shape or o.shape or { center = Vector3.new(centre.X, AT.Y, centre.Z) + look * math.min(9, ahead), radius = 5 },
		}
		task.spawn(function()
			local ok, err = pcall(fn, cue)
			if not ok then
				warn("review_stage: EnemyFX." .. tostring(defName) .. "." .. name .. ": " .. tostring(err))
			end
		end)
	end
	fire("ready")

	local every = math.max(o.every or clipLen, clipLen)
	local nextEv, cycle = 1, -1
	local states = o.states or {}
	local function stateAt(t)
		for _, s in states do
			if t >= s.from - 1e-4 and t < s.to - 1e-4 then
				return s.name
			end
		end
		return if states[#states] then states[#states].name else ""
	end
	loop(st, function(_, now)
		local c = math.floor(now / every)
		local t = now - c * every
		if c ~= cycle then
			if o.loop == false and cycle >= 0 then
				return -- hold the last pose
			end
			cycle, nextEv = c, 1
			for _, d in st.fx:GetChildren() do
				d:Destroy()
			end
		end
		if frames then
			local f = math.min(t / dt, #frames - 1.0001)
			local i = math.floor(f) + 1
			local aF, bF = frames[i], frames[math.min(i + 1, #frames)]
			local w = f - (i - 1)
			local list = table.create(#parts)
			for k, cf in aF.cfs do
				list[k] = cf:Lerp(bF.cfs[k], w)
			end
			workspace:BulkMoveTo(parts, list, Enum.BulkMoveMode.FireCFrameChanged)
		end
		while o.events[nextEv] and o.events[nextEv].t <= t do
			local ev = o.events[nextEv]
			nextEv += 1
			if ev.attack then
				model:SetAttribute("Attack", ev.attack)
			end
			if ev.state then
				model:SetAttribute("AIState", ev.state)
				model:SetAttribute("StateAt", workspace:GetServerTimeNow() - (t - ev.t))
			end
			if ev.cue then
				fire(ev.cue, ev, t - ev.t)
			end
		end
		setLabel(st, if t < clipLen then stateAt(t) else "rest")
	end)
	return model, clipLen
end

function R.anim(o)
	o = o or {}
	local spec = o.spec
	if type(spec) == "string" then
		spec = loadRemote("art/enemies/motion_specs.luau").with(spec)
	end
	assert(type(spec) == "table", "review_stage: anim needs spec (a motion_specs name or a probe spec)")
	local move = o.move or spec.moves[1]
	local moveName = if type(move) == "string" then move else (move.label or move.attack or move.loop or "chain")
	local st = begin("anim", string.format("%s %s", spec.template, moveName), o)
	local res, F = runProbe(spec, move)
	local _, clip = beast({ st = st, res = res, F = F, move = move, template = spec.template, def = spec.def,
		every = o.every, loop = o.loop, fx = o.fx, cuesOn = o.cues, shape = o.shape })
	local cam = R.camera({ view = o.view or "34", fov = o.fov })
	return done(st, string.format("%s, clip %.2f s, %d frames", res.label, clip, #res.frames), cam)
end

function R.enemy(o)
	o = o or {}
	local defs = enemyDefs()
	local template, defName = o.template, o.def
	if defs[template] and type(defs[template].body) == "string" then
		defName, template = template, defs[template].body
	end
	if not defName then
		for id, d in defs do
			if type(d) == "table" and d.body == template then
				defName = id
				break
			end
		end
	end
	defName = defName or template
	local spec = not o.cues and specFor(template, defName)
	local cueName = o.cue
	local st = begin("enemy", string.format("%s %s", template, tostring(cueName or "cues")), o)
	local events = nil
	if o.cues then
		events = {}
		for _, c in o.cues do
			table.insert(events, { t = c.at or 0, cue = c[1], attack = c[2], seconds = c[3], shape = c.shape, state = c.state or DEFAULT_STATE[c[1]] })
		end
		table.sort(events, function(a, b)
			return a.t < b.t
		end)
	end
	local how
	if spec and cueName then
		local res, F = runProbe(spec, cueName)
		beast({ st = st, res = res, F = F, move = cueName, template = template, def = defName, every = o.every, shape = o.shape })
		how = "posed by the motion probe"
	else
		beast({ st = st, template = template, def = defName, attack = cueName, events = events, every = o.every, shape = o.shape })
		how = if events then "static body, given cues" else "static body, cues on the def's timings"
	end
	local cam = R.camera({ view = o.view or "34", fov = o.fov })
	return done(st, string.format("%s (%s), %s", template, defName, how), cam)
end

------------------------------------------------------------------------------------------
-- cast

local function attachWeapon(rig, Weapons, def, want)
	local item, class
	if want then
		item = Weapons.Defs[want]
		if not item then
			for _, id in Weapons.Order do
				if Weapons.Defs[id].model == want then
					item = Weapons.Defs[id]
					break
				end
			end
		end
		assert(item, "review_stage: no weapon " .. tostring(want))
	elseif def.weapon and Weapons.Classes[def.weapon] and def.weapon ~= Weapons.FIST then
		for _, id in Weapons.Order do
			if Weapons.Defs[id].class == def.weapon then
				item = Weapons.Defs[id]
				break
			end
		end
	end
	if not item then
		return nil
	end
	class = Weapons.Classes[item.class]
	local template = ServerStorage.WeaponModels:FindFirstChild(item.model) or error("review_stage: no WeaponModels." .. item.model)
	local model = template:Clone()
	model.Name = "HeldWeapon"
	model:SetAttribute("WeaponId", item.id)
	local hilt = model.PrimaryPart
	local joint = hilt and class.joint and hilt:FindFirstChild(class.joint)
	assert(joint and joint:IsA("Motor6D"), "review_stage: " .. item.model .. " has no " .. tostring(class.joint) .. " Motor6D")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = false, false, false, false, true
			d.CollisionGroup = RIG_GROUP
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local arm = rig["Right Arm"]
	model:PivotTo(arm.CFrame * joint.C0 * joint.C1:Inverse() * hilt.PivotOffset) -- as Weapons.apply
	model.Parent = rig
	joint.Part0 = arm
	return item.id
end

function R.cast(o)
	o = o or {}
	assert(o.id, "review_stage: cast needs id")
	local level = o.level or 10
	local st = begin("cast", string.format("%s L%d", o.id, level), o)
	local holder = freshModules({ "CombatEffects", "Sfx", "TechniqueVFX", "CastFX", "TechniqueFX" })
	-- per-technique effect modules sit next to CombatEffects (Client.TechniqueFX.<Id>)
	local CE = require(holder.CombatEffects)
	local Techniques = require(holder.Shared.Techniques)
	local Rules = require(holder.Shared.ActionRules)
	local Weapons = require(holder.Shared.Weapons)
	local def = Techniques.Defs[o.id] or error("review_stage: no technique " .. o.id)
	local profile = Rules.castProfile(def)
	local rig = makeR6(false)
	local dir = Vector3.new(1, 0, 0)
	local start = AT - dir * 4
	standR6(rig, start, dir)
	rig.Parent = st.folder
	local weapon = attachWeapon(rig, Weapons, def, o.weapon)
	local root = rig.HumanoidRootPart
	local rootCF = root.CFrame
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator")
	local folderName, clipName = string.match(profile.clip, "^([^/]+)/(.+)$")
	local anims = ReplicatedStorage:FindFirstChild("Animations")
	local anim = anims and anims:FindFirstChild(folderName) and anims[folderName]:FindFirstChild(clipName)
	assert(anim, "review_stage: no Animations." .. folderName .. "." .. clipName)
	local track = animator:LoadAnimation(anim)
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 5 do
		task.wait()
	end
	track:Play(0, 1, 0)
	local clipSecs = track.Length / profile.speed
	local every = o.every or (clipSecs + 2)
	-- the reach of the technique, for the targets and the camera
	local reach = math.clamp(math.max(def.length or 0, (def.radius or 0) * 2, (def.lunge or 0) + 6, 16), 16, 60)
	if o.targets ~= false then
		for i, name in o.targets or { "SpiritWolf" } do
			local src = ServerStorage.Enemies:FindFirstChild(name)
			if src then
				local e = cloneClean(src)
				local ahead = math.max(reach * 0.55, (def.lunge or 0) + 5) + (i - 1) * 4
				local spot = start + dir * ahead + Vector3.new(0, 0, (i % 2 == 0) and 3 or -1.5)
				-- facing the caster: turn about the vertical from its root's facing, keeping the
				-- pivot's own rotation
				local hrp = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
				local fwd = (if hrp then hrp.CFrame.LookVector else e:GetPivot().LookVector) * Vector3.new(1, 0, 1)
				local yaw = if fwd.Magnitude > 0.1 then math.atan2(fwd.X, fwd.Z) - math.atan2(-dir.X, -dir.Z) else 0
				local p = e:GetPivot()
				e:PivotTo(CFrame.new(p.Position) * CFrame.Angles(0, -yaw, 0) * p.Rotation)
				placeOnGround(e, spot)
				for _, d in e:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanQuery = true
					end
				end
				CollectionService:AddTag(e, "Enemy") -- Hitbox.enemiesIn looks for it
				e:SetAttribute("MaxHealth", 100)
				e:SetAttribute("Health", 100)
				e.Parent = st.folder
			end
		end
	end
	addCylinder(st, start + dir * reach * 0.35, reach * 0.55, AT.Y, AT.Y + 7)
	fitPlate(st, reach * 0.75)
	st.plate.CFrame = CFrame.new(start + dir * reach * 0.4 - Vector3.new(0, 0.5, 0))
	st.labelPart.Position = start + Vector3.new(0, 11, 0)
	local cycle, casted, err = -1, false, nil
	local lungeA, lungeB = nil, nil
	if def.lunge and def.lungeWindow then
		lungeA, lungeB = def.lungeWindow[1], def.lungeWindow[2]
	end
	local w, a, r = profile.windup, profile.active, profile.recovery
	loop(st, function(_, now)
		local c = math.floor(now / every)
		local t = now - c * every
		if c ~= cycle then
			cycle, casted = c, false
			root.CFrame = rootCF
			local ok, e = pcall(CE.windup, rig, o.id, level)
			if not ok then
				err = e
				warn("review_stage: CombatEffects.windup: " .. tostring(e))
			end
		end
		local clipT = math.min(t * profile.speed, track.Length - 0.01)
		track.TimePosition = clipT
		animator:StepAnimations(0)
		if lungeA then
			local f = math.clamp((clipT - lungeA) / math.max(lungeB - lungeA, 1e-3), 0, 1)
			root.CFrame = rootCF + dir * def.lunge * f
		end
		if not casted and t >= w then
			casted = true
			local ok, e = pcall(CE.cast, rig, o.id, root.Position, dir, nil, level)
			if not ok then
				err = e
				warn("review_stage: CombatEffects.cast: " .. tostring(e))
			end
		end
		local phase = if t < w then "windup" elseif t < w + a then "active" elseif t < w + a + r then "recovery" else "rest"
		setLabel(st, if err then phase .. " - error, see output" else phase)
	end)
	st.onStop = function()
		track:Stop(0)
	end
	local cam = R.camera({ view = o.view or "player", fov = o.fov })
	return done(st, string.format("%s level %d%s, clip %s %.2f s at speed %.2f, every %.1f s", o.id, level,
		if weapon then " with " .. weapon else "", profile.clip, clipSecs, profile.speed, every), cam)
end

------------------------------------------------------------------------------------------
-- ui

function R.ui(o)
	o = o or {}
	local src = StarterGui:FindFirstChild(o.screen or "") or error("review_stage: no StarterGui." .. tostring(o.screen))
	local size = o.size or "pc"
	local st = begin("ui", string.format("%s %s", src.Name, tostring(size)), o)
	st.labelOff = true -- the screen is the subject
	-- a calm game view behind it: the R6 on the plate from a player's camera
	local rig = makeR6(true)
	standR6(rig, AT, Vector3.new(1, 0, 0))
	rig.Parent = st.folder
	addPts(st, AT - Vector3.new(15, 0, 15), AT + Vector3.new(15, 6, 15))
	fitPlate(st, 30)
	for _, g in StarterGui:GetChildren() do
		if g:IsA("LayerCollector") then
			if g:GetAttribute("_rs_Enabled") == nil then
				g:SetAttribute("_rs_Enabled", g.Enabled)
			end
			g.Enabled = false
		end
	end
	local gui = src:Clone()
	gui.Name = FOLDER
	gui.Enabled = true
	gui:SetAttribute("_rs_Enabled", nil)
	for _, d in gui:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local base = if typeof(size) == "Vector2" then size else SIZES[size]
	local root = gui
	if base then
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		local device = Instance.new("Frame")
		device.Name = "_Device"
		device.AnchorPoint = Vector2.new(0.5, 0.5)
		device.Position = UDim2.fromScale(0.5, 0.5)
		device.Size = UDim2.fromOffset(base.X, base.Y)
		device.BackgroundTransparency = 1
		device.ClipsDescendants = true
		for _, c in gui:GetChildren() do
			c.Parent = device
		end
		local scale = Instance.new("UIScale")
		scale.Name = "_DeviceScale"
		scale.Parent = device
		-- letterbox: a huge dark stroke around the device frame
		local bezel = Instance.new("Frame")
		bezel.Name = "_Bezel"
		bezel.AnchorPoint = Vector2.new(0.5, 0.5)
		bezel.Position = UDim2.fromScale(0.5, 0.5)
		bezel.BackgroundTransparency = 1
		bezel.ZIndex = 1000
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2000
		stroke.Color = Color3.fromRGB(14, 15, 18)
		stroke.Transparency = 0.15
		stroke.Parent = bezel
		bezel.Parent = gui
		device.Parent = gui
		root = device
		local function rescale()
			local vp = workspace.CurrentCamera.ViewportSize
			local s = math.min((vp.X - 8) / base.X, (vp.Y - 8) / base.Y)
			scale.Scale = s
			bezel.Size = UDim2.fromOffset(base.X * s, base.Y * s)
		end
		rescale()
		local lastVp = Vector2.zero
		loop(st, function()
			local vp = workspace.CurrentCamera.ViewportSize
			if vp ~= lastVp then
				lastVp = vp
				rescale()
			end
		end)
	end
	gui.Parent = StarterGui
	for _, path in o.show or {} do
		local node = resolvePath(path, root) or error("review_stage: no " .. path .. " in " .. src.Name)
		while node and node ~= root do
			if node:IsA("GuiObject") then
				node.Visible = true
			end
			node = node.Parent
		end
	end
	if type(o.sample) == "function" then
		o.sample(gui, root)
	elseif type(o.sample) == "table" then
		for path, v in o.sample do
			local node = resolvePath(path, root) or error("review_stage: no " .. path .. " in " .. src.Name)
			if type(v) == "table" then
				for k, x in v do
					node[k] = x
				end
			else
				node.Text = tostring(v)
			end
		end
	end
	-- the player's camera: behind and above the R6 facing +X
	local cam = park(AT + Vector3.new(-13, 7, 2), AT + Vector3.new(6, 2.5, 0), 70)
	return done(st, string.format("StarterGui.%s at %s%s", src.Name, tostring(size), if base then string.format(" (%dx%d)", base.X, base.Y) else ""), cam)
end

------------------------------------------------------------------------------------------

function R.stop()
	clear(false)
	return "review_stage: stopped"
end

_G.reviewStage = R
return "reviewStage installed (base " .. R.base .. ")"
