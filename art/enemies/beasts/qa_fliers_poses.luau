--!nocheck
-- Numeric QA for the flier pose modules (src/client/EnemyPoses/FlameRaven.luau, BloodBat.luau,
-- Flap.luau). Run in a sandbox (tools/sandbox.sh) after tools/serve.sh and pushing the modules:
--   _G.QA = "all"; loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/beasts/qa_fliers_poses.luau"))()
-- _G.WHO = "raven" | "bat" (default both). It clones the template (ServerStorage.Enemies.
-- FlameRavenB / BloodBat) into Workspace._FlierQA, poses it by C0 = C0 * pose (parts move
-- live), and for every move phase at u = 0, 0.1 .. 1 reports: wing/leg/body overlaps that the
-- rest pose does not already have (clipping), the bat's lowest wing-segment elevation (the
-- membrane V, must stay >= 0.3 while alive), the lowest point of the model (ground contact,
-- death only: must stay >= 0 and close), and detail drift (welded riders against their
-- segment). Also timing (durations) and a loop sweep. Returns the report string.
local ServerStorage = game:GetService("ServerStorage")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local clone = Client.EnemyPoses:Clone()
clone.Parent = game:GetService("ReplicatedStorage")
task.defer(function() clone:Destroy() end)
local mods = { raven = require(clone.FlameRaven), bat = require(clone.BloodBat) }
local templates = { raven = "FlameRavenB", bat = "BloodBat" }
local WING = {
	raven = { UpperWingL = 1, UpperWingR = 1, ForeWingL = 1, ForeWingR = 1, WingTipL = 1, WingTipR = 1 },
	bat = { WingL = 1, WingR = 1, WingL2 = 1, WingR2 = 1, WingL3 = 1, WingR3 = 1, WingLSkin = 1, WingRSkin = 1, WingL2Skin = 1,
		WingR2Skin = 1, WingL3Skin = 1, WingR3Skin = 1, WingClawL = 1, WingClawR = 1, WingEdgeTellL = 1, WingEdgeTellR = 1 },
}
-- the bat's skins: every Wing*Skin* part (Parts are thin along Y, the triangle skins are
-- WedgeParts thin along X, so their normal is the RightVector)
local function membraneNormal(part)
	if not part.Name:match("^Wing[LR]%d?Skin") then
		return nil
	end
	return if part:IsA("WedgePart") then part.CFrame.RightVector else part.CFrame.UpVector
end

local folder = workspace:FindFirstChild("_FlierQA") or Instance.new("Folder")
folder.Name = "_FlierQA"
folder.Parent = workspace
folder:ClearAllChildren()
folder:AddTag("EditorOnly")

local out = {}
local function say(...)
	table.insert(out, string.format(...))
end

local function run(who)
	local J = mods[who]
	local m = ServerStorage.Enemies[templates[who]]:Clone()
	m.Parent = folder
	m.HumanoidRootPart.Anchored = true
	local motors, parts = {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = { m = d, c0 = d.C0 }
		elseif d:IsA("BasePart") then
			table.insert(parts, d)
			d.CanQuery = true -- the templates ship with CanQuery off; spatial queries need it
		end
	end
	local function pose(p)
		for name, e in motors do
			e.m.C0 = e.c0 * (p[name] or CFrame.identity)
		end
	end
	local function wingish(n)
		return n:find("Wing") or n:find("Flight") or n:find("Ruff") or n:find("Feather") or n:find("Primary")
	end
	-- a wing part (shrunk to 55%, so touching at the shoulder does not count) inside a body part
	local function overlapSet()
		local set = {}
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { m }
		for _, w in parts do
			local n = w.Name
			local outer = if who == "raven" then (n:find("ForeWing") or n:find("WingTip")) else (n:match("^Wing[LR][23]") or n:find("Claw") or n:find("EdgeTell"))
			if outer then
				local size = Vector3.new(math.max(w.Size.X * 0.55, 0.05), math.max(w.Size.Y * 0.55, 0.05), math.max(w.Size.Z * 0.55, 0.05))
				for _, o in workspace:GetPartBoundsInBox(w.CFrame, size, params) do
					if o ~= w and not wingish(o.Name) and o.Name ~= "HumanoidRootPart" then
						set[w.Name .. "|" .. o.Name] = true
					end
				end
			end
		end
		return set
	end
	pose({})
	task.wait()
	local base = overlapSet()
	local nbase = 0
	for _ in base do
		nbase += 1
	end
	say("== %s: rest overlaps %d", who, nbase)
	local restPos = {}
	for _, p in parts do
		restPos[p] = p.CFrame
	end
	local worst = { clip = 0, floor = math.huge, vmin = math.huge, drift = 0, ymax = -math.huge }
	for move, phases in J.moves do
		for phase, def in phases do
			local clips, vmin, ymin, ymax = {}, math.huge, math.huge, -math.huge
			for i = 0, 10 do
				local u = i / 10
				local ok, p = pcall(J.sample, move, phase, u, { side = 1, targetYaw = 0.8, duration = def.duration })
				if not ok then
					say("ERROR %s.%s u=%.1f: %s", move, phase, u, tostring(p))
					break
				end
				pose(p)
				task.wait()
				for k in overlapSet() do
					if not base[k] then
						clips[k] = (clips[k] or 0) + 1
					end
				end
				local lo, hi = math.huge, -math.huge
				for _, part in parts do
					if part.Name ~= "HumanoidRootPart" then
						lo = math.min(lo, part.Position.Y - part.Size.Y / 2 * 0) -- centre (cheap)
						for _, c in { Vector3.new(1, 1, 1), Vector3.new(-1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, -1) } do
							local y = (part.CFrame * CFrame.new(part.Size / 2 * c)).Position.Y
							lo = math.min(lo, y)
							hi = math.max(hi, y)
						end
					end
					local normal = who == "bat" and membraneNormal(part)
					if normal then
						local ub = m.Body.CFrame:VectorToObjectSpace(normal)
						vmin = math.min(vmin, math.acos(math.clamp(math.abs(ub.Y), 0, 1)))
					end
				end
				ymin, ymax = math.min(ymin, lo), math.max(ymax, hi)
			end
			local list = {}
			for k, n in clips do
				table.insert(list, k .. "x" .. n)
			end
			table.sort(list)
			say("%-14s %-8s dur %.2f  low %.2f high %.2f%s%s", move, phase, def.duration, ymin, ymax,
				if who == "bat" then string.format("  bodyFrameElev %.2f", vmin) else "",
				if #list > 0 then "  CLIP " .. table.concat(list, ",") else "")
		end
	end
	-- loops
	for _, loop in { "idle", "walk", "run", "circle" } do
		local vmin, nclip, which = math.huge, 0, {}
		for i = 0, 15 do
			local p
			if loop == "idle" then
				p = J.loops.idle(i * 0.021, 0, { seed = 3 })
			else
				p = J.loops[loop](i * (2 * math.pi / 15), if loop == "walk" then 8 else 16, { dir = 1, targetYaw = 0.5, seed = 3 })
			end
			pose(p)
			task.wait()
			for k in overlapSet() do
				if not base[k] then
					nclip += 1
					which[k] = true
				end
			end
			for _, part in parts do
				local normal = who == "bat" and membraneNormal(part)
				if normal then
					local ub = m.Body.CFrame:VectorToObjectSpace(normal)
					vmin = math.min(vmin, math.acos(math.clamp(math.abs(ub.Y), 0, 1)))
				end
			end
		end
		local list = {}
		for k in which do
			table.insert(list, k)
		end
		table.sort(list)
		say("loop %-7s clips %d%s%s", loop, nclip, if who == "bat" then string.format("  bodyFrameElev %.2f", vmin) else "",
			if #list > 0 then "  (" .. table.concat(list, ",") .. ")" else "")
	end
	-- drift: with the last pose, riders keep their offset to their parent (welds); report the rest pose delta of a few
	pose({})
	task.wait()
	local maxDrift = 0
	for _, p in parts do
		maxDrift = math.max(maxDrift, (p.CFrame.Position - restPos[p].Position).Magnitude)
	end
	say("rest restored, max part drift %.4f", maxDrift)
	m:Destroy()
end

for _, who in { "raven", "bat" } do
	if not _G.WHO or _G.WHO == who then
		run(who)
	end
end
return table.concat(out, "\n")
