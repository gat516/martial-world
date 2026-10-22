--!nocheck
-- Visual slither check for the Jade Jiao pose module (sandbox only, through execute_luau after
-- push_src): drives the real template's loops along a curved path, as EnemyAnimator would
-- (wave phase from gaitRate, travel-heading history for the follow), and poses an anchored,
-- EditorOnly copy at time _G.SL_T (seconds) in Workspace._JiaoSlither. Also leaves faint
-- ground dots where the belly passed (_G.SL_TRACE = true) so skating shows as smeared tracks.
--   _G.SL_SPEED = 6 | 18 ; _G.SL_TURN = rad/s (0.15) ; _G.SL_T = 6 ; _G.SL_LOOP = "walk"|"run"|"idle"
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local clone = Client.EnemyPoses:Clone()
clone.Parent = game:GetService("ReplicatedStorage")
local J = require(clone.JadeJiao)
task.defer(function() clone:Destroy() end)

local speed = _G.SL_SPEED or 6
local turnRate = _G.SL_TURN or 0.15
local T = _G.SL_T or 6
local loop = _G.SL_LOOP or (if speed <= 8.5 then "walk" else "run")
local dt = 1 / 30

-- the root's track: straight for 2 s, then turning at turnRate
local function yawAt(time)
	return turnRate * math.max(0, time - 2)
end
local function rootAt(time)
	local p, y = Vector3.new(0, 0, 0), 0
	local steps = math.floor(time / dt)
	for i = 1, steps do
		y = yawAt(i * dt)
		p += Vector3.new(-math.sin(y), 0, -math.cos(y)) * speed * dt
	end
	return p, y
end

local function poseAt(time)
	local phase = 0
	for i = 1, math.floor(time / dt) do
		phase += J.gaitRate(loop, speed, 1) * dt
	end
	local input = {
		time = time, phase = 2, seed = 1, wavePhase = phase, still = 0, travel = speed * time, rested = _G.SL_RESTED or 0,
		turn = turnRate * (if time > 2 then 1 else 0),
		yawAt = function(ago) return yawAt(math.max(0, time - ago)) end,
	}
	if loop == "idle" then
		input.still = _G.SL_STILL or 3
		return J.loops.idle(time, 0, input)
	end
	return J.loops[loop](phase, speed, input)
end

local template = ServerStorage.Enemies.JadeJiao
local hrp = template.HumanoidRootPart
local motors = {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then table.insert(motors, m) end
end
local function fk(pose, rootCF)
	local world = { [hrp] = rootCF }
	local pending = #motors
	for _ = 1, 60 do
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
			end
		end
	end
	-- welded riders keep their offset to their segment
	for _, w in template:GetDescendants() do
		if w:IsA("Weld") or w:IsA("WeldConstraint") then
			local a, b = w.Part0, w.Part1
			if a and b then
				if world[a] and not world[b] then world[b] = world[a] * a.CFrame:ToObjectSpace(b.CFrame)
				elseif world[b] and not world[a] then world[a] = world[b] * b.CFrame:ToObjectSpace(a.CFrame) end
			end
		end
	end
	return world
end

local folder = workspace:FindFirstChild("_JiaoSlither") or Instance.new("Folder")
folder.Name = "_JiaoSlither"
folder.Parent = workspace
CollectionService:AddTag(folder, "EditorOnly")
if not _G.SL_KEEP then folder:ClearAllChildren() end
local base = Vector3.new(0, hrp.Position.Y, 300)

local p, y = rootAt(T)
local rootCF = CFrame.new(base + p) * CFrame.Angles(0, y, 0)
local world = fk(poseAt(T), rootCF)
local copy = Instance.new("Model")
copy.Name = "Jiao_t" .. T
for part, cf in world do
	if part ~= hrp then
		local c = part:Clone()
		c:ClearAllChildren()
		c.Anchored = true
		c.CFrame = cf
		c.Parent = copy
	end
end
copy.Parent = folder
-- the root's track and belly traces of earlier times
if _G.SL_TRACE then
	for i = 0, math.floor(T / 0.25) do
		local tt = i * 0.25
		local pp, yy = rootAt(tt)
		local d = Instance.new("Part")
		d.Anchored, d.Size, d.Color, d.Material = true, Vector3.new(0.6, 0.1, 0.6), Color3.new(1, 0.2, 0.2), Enum.Material.Neon
		d.CFrame = CFrame.new(base + pp + Vector3.new(0, -hrp.Position.Y + 0.05, 0))
		d.Parent = folder
		if tt > T - 3 then
			local w = fk(poseAt(tt), CFrame.new(base + pp) * CFrame.Angles(0, yy, 0))
			for _, nm in { "Tail3", "Tail8", "Tail13", "Tail17" } do
				local q = w[template:FindFirstChild(nm, true)].Position
				local e = Instance.new("Part")
				e.Anchored, e.Size, e.Color, e.Material = true, Vector3.new(0.4, 0.1, 0.4), Color3.new(1, 1, 0.2), Enum.Material.Neon
				e.CFrame = CFrame.new(q.X, 0.05, q.Z)
				e.Parent = folder
			end
		end
	end
end
local c = (base + p)
return string.format("root at %.1f, %.1f, %.1f yaw %.2f", c.X, c.Y, c.Z, y)
