--!nocheck
-- Edit-mode preview kit for effect templates. Run this file once through the
-- Studio MCP's execute_luau; it installs _G.vfxPreview:
--
--   P.scene({ center?, enemies? = {"SpiritWolf", ...}, offsets? = {Vector3...},
--             radius? })            -> scene table { C, rig, enemies, folder }
--       A clean grass floor in open sky (no props in the way), a caster stand-in
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
--   P.clear(keepScene?) remove clones (and the scene unless keepScene), and
--       empty workspace.Terrain.TempVFX.
-- Typical camera for screen_capture: behind-right of the caster at player
-- distance, e.g. C + (-12, 9, 5) looking at C + (4, 1, 0); top-down
-- C + (0.1, 28, 0) -> C checks radii against the posts.

local RS = game:GetService("ReplicatedStorage")
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
	P.clear()
	local C = opts.center or Vector3.new(400, 640, 300)
	local folder = Instance.new("Folder")
	folder.Name = "_VFXPreview"
	folder.Parent = workspace
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(90, 2, 90)
	floor.CFrame = CFrame.new(C - Vector3.new(0, 1, 0))
	floor.Material = Enum.Material.SmoothPlastic -- textured grass muddies reads
	floor.Color = Color3.fromRGB(98, 170, 60)
	floor.Parent = folder
	local rig = workspace:FindFirstChild("Rig")
	rig = rig and rig:Clone()
	if rig then
		local _, size = rig:GetBoundingBox()
		rig:PivotTo(CFrame.lookAt(C + Vector3.new(0, size.Y / 2, 0), C + Vector3.new(1, size.Y / 2, 0)))
		rig.Parent = folder
	end
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
	local old = workspace:FindFirstChild("_VFXPreview")
	if old and not keepScene then
		old:Destroy()
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		temp:ClearAllChildren()
	end
end

_G.vfxPreview = P
return "vfxPreview installed"
