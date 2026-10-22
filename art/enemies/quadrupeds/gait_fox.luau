--!nocheck
-- Gait analysis for the Nine-Tailed Fox boss (run in a sandbox through execute_luau after
-- pushing src/ modules). For a loop ("walk"/"run") and ground speeds it steps one gait
-- cycle at NineTailFox.gaitRate and reports, per paw, the contact fraction, the
-- planted paw's body-frame speed against the ground speed (skate = paw speed minus body
-- speed, studs/s; 0 is a perfect plant), the share of the cycle with no paw down
-- (suspension) and the body's bounce. _G.GAIT = { loop = "run", speeds = { 14, 18 } }
local ServerStorage = game:GetService("ServerStorage")
local NF = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.EnemyPoses:Clone().NineTailFox)
local template = ServerStorage.Enemies.NineTailFoxB
local hrp = template.HumanoidRootPart
local motors = {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then table.insert(motors, m) end
end
local function fk(pose)
	local world = { [hrp] = hrp.CFrame }
	local pending = #motors
	while pending > 0 do
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
	end
	return world
end
local function lowestY(part, cf)
	local s = part.Size / 2
	return cf.Y - (math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z)
end
local spec = _G.GAIT or { loop = "run", speeds = { 14, 18 } }
local PAWS = { "PawFL", "PawFR", "PawBL", "PawBR" }
local rest = fk({})
local ground = {}
for _, p in PAWS do ground[p] = lowestY(template[p], rest[template[p]]) end
local out = {}
local N = 96
for _, speed in spec.speeds do
	local rate = NF.gaitRate(spec.loop, speed, 2.13) -- rad/s
	local period = 2 * math.pi / rate
	local z, y, down, bodyY = {}, {}, {}, {}
	for _, p in PAWS do z[p], y[p], down[p] = {}, {}, {} end
	local air, lo, hi = 0, math.huge, -math.huge
	for i = 0, N - 1 do
		local pose = NF.scaled(NF.loops[spec.loop](i / N * 2 * math.pi, speed), 2.13)
		local w = fk(pose)
		local any = false
		for _, p in PAWS do
			local cf = w[template[p]]
			z[p][i], y[p][i] = cf.Z, lowestY(template[p], cf) - ground[p]
			down[p][i] = false
			do
				local g = NF.GAIT[if spec.loop == "run" then "RUN" else "WALK"]
				local x = (i / N - g.offsets[p:sub(4)]) % 1
				down[p][i] = x > 0.05 * g.stance and x < 0.95 * g.stance
			end
			any = any or down[p][i]
		end
		if not any then air += 1 end
		local ry = pose.JointRoot and pose.JointRoot.Y or 0
		lo, hi = math.min(lo, ry), math.max(hi, ry)
	end
	local dt = period / N
	local line = { ("%s %g studs/s: %.2f cycles/s, stride %.1f studs, suspension %.0f%%, root bounce %.2f studs"):format(spec.loop, speed, 1 / period, speed * period, air / N * 100, hi - lo) }
	for _, p in PAWS do
		local n, sum, worst = 0, 0, 0
		for i = 0, N - 1 do
			local j = (i + 1) % N
			if down[p][i] and down[p][j] and down[p][(i + N - 1) % N] and down[p][(j + 1) % N] then
				-- body frame: the model faces -Z, a planted paw moves +Z at the ground speed
				local v = (z[p][j] - z[p][i]) / dt
				n += 1
				sum += v - speed
				worst = math.max(worst, math.abs(v - speed))
			end
		end
		table.insert(line, ("  %s contact %.0f%% skate mean %+.1f worst %.1f maxY %.2f"):format(p, #(function() local c = {} for i = 0, N - 1 do if down[p][i] then c[#c + 1] = i end end return c end)() / N * 100, n > 0 and sum / n or 0, worst, (function() local m = 0 for i = 0, N - 1 do if down[p][i] then m = math.max(m, y[p][i]) end end return m end)()))
	end
	table.insert(out, table.concat(line, "\n"))
end
return table.concat(out, "\n")
