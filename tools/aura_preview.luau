--!nocheck
-- Edit-mode preview of the seated method auras (src/client/MethodAura.luau)
-- and the spirit root reveal (src/client/RootFX.luau). Run through
-- execute_luau (served by tools/receive_rbxmx.py at /aura_preview.luau);
-- installs _G.auraPreview:
--
--   P.scene({ methods = { "BlazingHeart", ... }, source = staging?, at = Vector3?,
--             spacing = 9, floor = "grass" | "dark", floorSize = Vector3? })
--       A floor in open sky with one R6 rig per method (clones of workspace.Rig,
--       posed in Animations.Meditate.Loop), facing -Z, and a fresh copy of
--       MethodAura pointed at `source` (default ReplicatedStorage.Effects)
--       drawing into a workspace folder. Starts every aura with its ignition.
--       Returns { C = centre, rigs = { [method] = rig }, at = { [method] = Vector3 } }.
--   P.run(seconds)       steps the auras on Heartbeat for that long (real time),
--                        feeding enabled emitters by hand (Edit mode doesn't
--                        tick Rate emission)
--   P.ignite()           replays every aura's ignition surge
--   P.hold()             stops stepping (particles keep simulating)
--   P.freeze()           holds the moment for a capture (waves and particles paused)
--   P.reveal(element, grade, at?, first?)  plays RootFX at `at` (default the
--       scene centre) from a fresh RootFX copy pointed at the same source
--   P.clear()            removes the scene and every aura
--   P.look(from, at?)    puts the editor camera there (offsets from the scene
--                        centre). Roblox doesn't simulate particles far from
--                        the camera, so screen_capture's own camera move shows
--                        new-born particles only (pale flames, no mantle);
--                        call this, wait ~2 s, then capture from the same spot
-- Camera for screen_capture: in front of a rig at its position + (0, 3.5, -9),
-- looking at position + (0, 1, 0); the row from + (0, 6, -26).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local P = {}
local S = nil
local conn = nil

local function fresh(name)
	local client = StarterPlayer.StarterPlayerScripts.Client
	local holder = Instance.new("Folder")
	holder.Name = "_AuraPreviewModules"
	for _, n in { name, "TechniqueVFX" } do
		client[n]:Clone().Parent = holder
	end
	return require(holder[name]), holder, require(holder.TechniqueVFX)
end

local function pose(rig)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local track = animator:LoadAnimation(RS.Animations.Meditate.Loop)
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 5 do
		task.wait()
	end
	track:Play(0, 1, 0)
	track.TimePosition = track.Length * 0.25
	animator:StepAnimations(0)
	animator:StepAnimations(0)
end

function P.clear()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if S then
		for key in S.at do
			pcall(S.aura.stopPreview, key)
		end
		S.aura.step(100) -- let them fade
		S.aura.step(100)
		for _, f in { S.folder, S.modules, S.rootModules } do
			if f then
				f:Destroy()
			end
		end
	end
	S = nil
	local old = workspace:FindFirstChild("_AuraPreview")
	if old then
		old:Destroy()
	end
end

function P.scene(opts)
	opts = opts or {}
	P.clear()
	local C = opts.at or Vector3.new(0, 600, 3000)
	local folder = Instance.new("Folder")
	folder.Name = "_AuraPreview"
	folder.Parent = workspace
	local methods = opts.methods or { "BlazingHeart" }
	local spacing = opts.spacing or 9
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = opts.floorSize or Vector3.new(spacing * #methods + 20, 1, 40)
	floor.CFrame = CFrame.new(C - Vector3.new(0, 0.5, 0))
	if opts.floor == "dark" then
		floor.Material = Enum.Material.SmoothPlastic
		floor.Color = Color3.fromRGB(40, 40, 46)
	else
		floor.Material = Enum.Material.Grass
		floor.Color = Color3.fromRGB(96, 150, 62)
	end
	floor.Parent = folder
	local auras = Instance.new("Folder")
	auras.Name = "Effects" -- the auras' own folder: their ground rays skip it, not the floor
	auras.Parent = folder
	local aura, modules, tv = fresh("MethodAura")
	aura.folder = auras
	tv.folder = auras -- mesh waves too (they default to the camera)
	aura.source = opts.source or RS.Effects
	local rigs, at = {}, {}
	for i, method in methods do
		local x = (i - (#methods + 1) / 2) * spacing
		local spot = C + Vector3.new(x, 0, 0)
		local rig = workspace.Rig:Clone()
		rig.Name = "_Rig_" .. method
		-- the seated root stands ~3.05 above the ground; face -Z
		local offset = rig:GetPivot():ToObjectSpace(rig.HumanoidRootPart.CFrame)
		rig:PivotTo(CFrame.new(spot + Vector3.new(0, 3.05, 0)) * offset:Inverse())
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = d.Name == "HumanoidRootPart"
				d.CanQuery = false
			end
		end
		rig.Parent = folder
		pose(rig)
		rigs[method], at[method] = rig, spot
	end
	S = { C = C, rigs = rigs, at = at, folder = folder, effects = auras, aura = aura, tv = tv, modules = modules, source = aura.source }
	for method, rig in rigs do
		aura.preview(method, rig.HumanoidRootPart, method)
	end
	P.run(0)
	return S
end

function P.run(seconds)
	if conn then
		conn:Disconnect()
	end
	for _, d in S.folder:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.TimeScale = 1
		end
	end
	-- Edit mode doesn't tick Rate emission, so enabled emitters are fed by hand
	local owed, list, nextScan = {}, {}, 0
	conn = RunService.Heartbeat:Connect(function(dt)
		S.aura.step(dt)
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 0.25
			list = {}
			for _, d in S.folder:GetDescendants() do
				if d:IsA("ParticleEmitter") and d.Enabled and d.Rate > 0 then
					table.insert(list, d)
				end
			end
		end
		for _, e in list do
			if e.Parent and e.Enabled then
				local n = (owed[e] or 0) + e.Rate * dt
				local whole = math.floor(n)
				if whole > 0 then
					e:Emit(whole)
				end
				owed[e] = n - whole
			end
		end
	end)
	if seconds and seconds > 0 then
		task.wait(seconds)
	end
end

function P.ignite()
	for key in S.at do
		S.aura.ignite(key)
	end
end

function P.hold()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

function P.reveal(element, grade, at, first)
	local fx, modules, tv = fresh("RootFX")
	S.rootModules = modules
	fx.folder = S.effects
	tv.folder = S.effects
	S.rootTvs = S.rootTvs or {}
	table.insert(S.rootTvs, tv)
	fx.source = S.source
	S.rootFx = S.rootFx or {}
	table.insert(S.rootFx, fx)
	fx.play(nil, element, grade or "Spirit", first ~= false, CFrame.new(at or S.C))
	return fx
end

-- Freezes the moment for a capture: stops stepping, pauses mesh waves and
-- particles. P.run() (or P.scene) starts things again.
function P.freeze()
	P.hold()
	for _, fx in S.rootFx or {} do
		local t = fx.now()
		fx.now = function()
			return t -- the reveal's column holds too (and isn't cleaned up)
		end
	end
	local tvs = { S.tv }
	for _, tv in S.rootTvs or {} do
		table.insert(tvs, tv)
	end
	for _, tv in tvs do
		for tween in tv.waves do
			tween:Pause()
		end
	end
	for _, d in S.folder:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.TimeScale = 0
		end
	end
end

function P.look(from, at)
	local C = S and S.C or Vector3.new(0, 600, 3000)
	local cam = workspace.CurrentCamera
	cam.CFrame = CFrame.lookAt(C + (from or Vector3.new(4, 4.5, -10)), C + (at or Vector3.new(0, 1.8, 0)))
	return cam.CFrame.Position
end

function P.state()
	return S
end

_G.auraPreview = P
return "auraPreview installed"
