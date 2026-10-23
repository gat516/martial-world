--!nocheck
-- Edit-mode previews for weapon skills that play their own clip
-- (ReplicatedStorage.Animations.Techniques.<Id>: Heaven-Splitting Descent,
-- Rampaging Tiger...), on workspace.Rig holding its real weapon model (hang it
-- like Weapons.apply: tools/vfx_skill_preview.luau needs a HeldWeapon with
-- Tip/Base). Load tools/vfx_preview.luau first. Installs _G.skillPreview:
--
--   SP.drive({ id, level, scene, freezeAt? (s after cast start), holder? })
--       The real call path on the scene's rig: CombatEffects.windup at cast
--       start, the clip scrubbed at def.castSpeed, the root driven over
--       def.lungeWindow by def.lunge, CombatEffects.cast at the first hit with
--       the live root; freezes particles and MeshWave tweens at freezeAt.
--       Markers don't fire while scrubbing (BladeSkill's +0.08 s fallback).
--   SP.filmstrip({ id, level, radius, moments }) -> vfxPreview.filmstrip with
--       every cell played through SP.drive (vfxPreview's castThrough plays
--       Fists clips only).
--   _G.reviewLoop.start({ id, levels? = {10, 1}, every? = 4, center? })
--       A repeating cast for someone watching the Studio window: one rig per
--       level on a plate (_ReviewLoop, outside vfxPreview's folders, so
--       P.clear leaves it), its own module copies (cleanup on, shakes and
--       punches off), recast every `every` seconds, the camera pointed at it.
--       _G.reviewLoop.stop() removes it. _G.reviewLoop.look() re-points the
--       camera.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local P = assert(_G.vfxPreview, "load tools/vfx_preview.luau first")
local SP = {}

local function clipFor(id)
	local folder = RS.Animations:FindFirstChild("Techniques")
	return assert(folder and folder:FindFirstChild(id), "no Animations.Techniques." .. id)
end

-- plays one cast on `rig` (anchored root) through CE; returns the stop reason
local function play(CE, def, rig, level, freezeAt, onStep)
	local root = rig.HumanoidRootPart
	root.Anchored = true
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for _, t in animator:GetPlayingAnimationTracks() do
		t:Stop(0)
	end
	local track = animator:LoadAnimation(clipFor(def.id))
	local t0 = os.clock()
	while track.Length == 0 and os.clock() - t0 < 6 do
		task.wait()
	end
	track:Play(0, 1, 0)
	local speed = def.castSpeed or 1
	local first = def.hits and def.hits[1] and def.hits[1].time or 0
	local window = def.lungeWindow or { 0, 0 }
	local start = root.CFrame
	local dir = (start.LookVector * Vector3.new(1, 0, 1)).Unit
	local err
	local ok, e = pcall(CE.windup, rig, def.id, level)
	if not ok then
		err = e
	end
	local began, casted = os.clock(), false
	while true do
		local t = os.clock() - began
		if freezeAt and t >= freezeAt then
			t = freezeAt
		end
		local clip = t * speed
		track.TimePosition = math.min(clip, track.Length - 0.01)
		local k = math.clamp((clip - window[1]) / math.max(window[2] - window[1], 0.01), 0, 1)
		root.CFrame = start + dir * (def.lunge or 0) * k
		animator:StepAnimations(0)
		if not casted and clip >= first then
			casted = true
			local ok2, e2 = pcall(CE.cast, rig, def.id, root.Position, dir, nil, level)
			if not ok2 then
				err = e2
			end
		end
		if onStep then
			onStep(t)
		end
		if (freezeAt and t >= freezeAt) or clip > track.Length then
			break
		end
		RunService.Heartbeat:Wait()
	end
	return err, track, start
end

function SP.drive(opts)
	local S = assert(opts.scene, "scene")
	S.folder._fxOut:ClearAllChildren()
	P.look("player", S)
	task.wait(0.4)
	local holder = opts.holder or P.fresh({ "CombatEffects", "Sfx", "TechniqueVFX", "CastFX" })
	local CE = require(holder.CombatEffects)
	CE.punch = function() end -- moves the editor camera
	local def = require(holder.Shared.Techniques).Defs[opts.id]
	local err = play(CE, def, S.rig, opts.level, opts.freezeAt)
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
		for tween in require(holder.TechniqueVFX).waves or {} do
			tween:Pause()
		end
	end
	pcall(function()
		RunService:UnbindFromRenderStep("CombatShake")
	end)
	local kids = {}
	for _, d in S.folder._fxOut:GetChildren() do
		kids[d.Name] = (kids[d.Name] or 0) + 1
	end
	local list = {}
	for n, c in kids do
		table.insert(list, n .. "x" .. c)
	end
	return string.format("err=%s out=%s", tostring(err), table.concat(list, ","))
end

function SP.filmstrip(opts)
	local castThrough = P.castThrough
	P.castThrough = function(o)
		return SP.drive({ id = o.id, level = o.level, scene = o.scene, freezeAt = o.freezeAt })
	end
	local ok, res = pcall(P.filmstrip, opts)
	P.castThrough = castThrough
	assert(ok, res)
	return res
end

-- the review loop ---------------------------------------------------------

local L = { running = false }
_G.reviewLoop = L

local function modules(folder)
	local holder = Instance.new("Folder")
	holder.Name = "_ReviewLoopModules"
	holder.Parent = game.ServerStorage
	RS.Shared:Clone().Parent = holder
	local client = game.StarterPlayer.StarterPlayerScripts.Client
	local path = 'game:GetService("ServerStorage")._ReviewLoopModules.Shared'
	for _, n in { "CombatEffects", "Sfx", "TechniqueVFX", "CastFX" } do
		local m = client[n]:Clone()
		m.Source = m.Source:gsub("ReplicatedStorage%.Shared", path)
		m.Parent = holder
	end
	local fx = client.TechniqueFX:Clone()
	for _, m in fx:GetDescendants() do
		if m:IsA("ModuleScript") then
			m.Source = m.Source:gsub("ReplicatedStorage%.Shared", path)
		end
	end
	fx.Parent = holder
	local TV = require(holder.TechniqueVFX)
	TV.folder = folder
	local emit = TV.emit
	TV.emit = function(inst)
		for _, d in inst:GetDescendants() do
			d:SetAttribute("CameraShake", nil)
			d:SetAttribute("ImpactFrames", nil)
		end
		emit(inst)
	end
	local CE = require(holder.CombatEffects)
	CE.punch = function() end
	CE.shake = function() end
	return holder, CE
end

function L.look()
	if L.C then
		-- the editor camera turns back toward its Focus unless Focus moves too
		local camera = workspace.CurrentCamera
		local mid = 16 * ((L.count or 1) - 1) -- between the first and last rig
		local target = L.C + Vector3.new(8, 2, mid)
		camera.FieldOfView = 70
		camera.CFrame = CFrame.lookAt(L.C + Vector3.new(-24, 14, mid + 6), target)
		camera.Focus = CFrame.new(target)
	end
end

function L.stop()
	L.running = false
	L.gen = (L.gen or 0) + 1
	for _, n in { "_ReviewLoop" } do
		while workspace:FindFirstChild(n) do
			workspace[n]:Destroy()
		end
	end
	local mods = game.ServerStorage:FindFirstChild("_ReviewLoopModules")
	if mods then
		mods:Destroy()
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		temp:ClearAllChildren()
	end
	if L._devGui ~= nil then
		game:GetService("StarterGui").ShowDevelopmentGui = L._devGui
		L._devGui = nil
	end
end

function L.start(opts)
	L.stop()
	local gen = L.gen
	L.running = true
	local C = opts.center or Vector3.new(400, 900, 300)
	L.C = C
	local levels = opts.levels or { 10, 1 }
	L.count = #levels
	local folder = Instance.new("Folder")
	folder.Name = "_ReviewLoop"
	folder.Parent = workspace
	local out = Instance.new("Folder")
	out.Name = "_fxOut"
	out.Parent = folder
	local floor = Instance.new("Part")
	floor.Name = "Plate"
	floor.Anchored = true
	floor.Size = Vector3.new(70, 2, 40 + 32 * (#levels - 1))
	floor.CFrame = CFrame.new(C + Vector3.new(8, -1, 16 * (#levels - 1)))
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(88, 150, 60)
	floor.Parent = folder
	local holder, CE = modules(out)
	local def = require(holder.Shared.Techniques).Defs[opts.id]
	local PhysicsService = game:GetService("PhysicsService")
	if not PhysicsService:IsCollisionGroupRegistered("_ReviewLoopRig") then
		PhysicsService:RegisterCollisionGroup("_ReviewLoopRig")
	end
	PhysicsService:CollisionGroupSetCollidable("_ReviewLoopRig", "Default", false)
	for i, level in levels do
		local at = C + Vector3.new(0, 0, (i - 1) * 32)
		local rig = workspace.Rig:Clone()
		rig.Name = "ReviewRig_L" .. level
		local _, size = rig:GetBoundingBox()
		rig:PivotTo(CFrame.lookAt(at + Vector3.new(0, size.Y / 2, 0), at + Vector3.new(1, size.Y / 2, 0)))
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "_ReviewLoopRig"
			end
		end
		rig.Parent = folder
		local home = rig.HumanoidRootPart.CFrame
		for j, offset in { Vector3.new(9, 0, 3), Vector3.new(14, 0, -3) } do
			local name = ({ "SpiritWolf", "StoneBoar" })[j]
			local source = game.ServerStorage.Enemies:FindFirstChild(name)
			if source then
				local e = source:Clone()
				for _, d in e:GetDescendants() do
					if d:IsA("BaseScript") then
						d:Destroy()
					end
				end
				local _, es = e:GetBoundingBox()
				local p = at + offset
				e:PivotTo(CFrame.lookAt(p + Vector3.new(0, es.Y / 2, 0), at + Vector3.new(0, es.Y / 2, 0)))
				e:AddTag("Enemy")
				e:SetAttribute("MaxHealth", 100)
				e:SetAttribute("Health", 100)
				e.Parent = folder
			end
		end
		task.spawn(function()
			task.wait((i - 1) * (opts.every or 4) / #levels)
			while L.running and L.gen == gen and rig.Parent do
				rig.HumanoidRootPart.CFrame = home
				local began = os.clock()
				local ok, err = pcall(play, CE, def, rig, level, nil)
				if not ok then
					warn("reviewLoop:", err)
				end
				task.wait(math.max(0.5, (opts.every or 4) - (os.clock() - began)))
			end
		end)
	end
	-- hide the HUD while watching; stop() restores it
	local SG = game:GetService("StarterGui")
	if L._devGui == nil then
		L._devGui = SG.ShowDevelopmentGui
	end
	SG.ShowDevelopmentGui = false
	L.look()
	return "reviewLoop running at " .. tostring(C)
end

_G.skillPreview = SP
return "skillPreview installed"
