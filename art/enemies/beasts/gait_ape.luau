--!nocheck
-- Gait analysis for the Thunder Ape B (run in a sandbox via execute_luau after pushing
-- src/client/EnemyPoses/{Quadruped,ThunderApe}.luau with tools/push_src.luau). Steps one
-- gait cycle at ThunderApe.gaitRate for each speed and reports, per limb, contact share,
-- skate (planted fist/foot speed in the body frame minus ground speed, studs/s; 0 = perfect),
-- planted height, suspension share and root bounce.
-- _G.GAIT = { loop = "run", speeds = { 9, 14, 18, 22, 26 } }
local ServerStorage = game:GetService("ServerStorage")
local TA = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.EnemyPoses:Clone().ThunderApe)
local template = ServerStorage.Enemies.ThunderApeB
local scale = template:GetAttribute("Scale") or 3.71
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
local spec = _G.GAIT or { loop = "run", speeds = { 9, 14, 18, 22, 26 } }
local LIMBS = { "HandFL", "HandFR", "FootBL", "FootBR" }
local rest = fk({})
local ground = {}
for _, p in LIMBS do ground[p] = lowestY(template[p], rest[template[p]]) end
local out = {}
local trace = {}
local N = 96
for _, speed in spec.speeds do
	local rate = TA.gaitRate(spec.loop, speed, scale)
	local period = 2 * math.pi / rate
	local z, y, down = {}, {}, {}
	for _, p in LIMBS do z[p], y[p], down[p] = {}, {}, {} end
	local air, lo, hi = 0, math.huge, -math.huge
	local sunk = math.huge
	for i = 0, N - 1 do
		local input = { dir = 1, targetYaw = 0 }
		local pose = TA.scaled(TA.loops[spec.loop](i / N * 2 * math.pi, speed, input), scale)
		local w = fk(pose)
		local any = false
		for _, p in LIMBS do
			local cf = w[template[p]]
			z[p][i], y[p][i] = (if spec.loop == "circle" then cf.X else cf.Z), lowestY(template[p], cf) - ground[p]
			local tag = ({ HandFL = "FL", HandFR = "FR", FootBL = "BL", FootBR = "BR" })[p]
			local g = TA.GAITS[spec.loop]
			local x = (i / N - g.off[tag]) % 1
			down[p][i] = x > 0.06 * g.stance[tag] and x < 0.94 * g.stance[tag]
			any = any or down[p][i]
			sunk = math.min(sunk, y[p][i])
		end
		if not any then air += 1 end
		local ry = pose.JointRoot.Y
		lo, hi = math.min(lo, ry), math.max(hi, ry)
	end
	local dt = period / N
	local line = { ("%s %g studs/s: %.2f cycles/s, stride %.1f studs, suspension %.0f%%, root bounce %.2f studs, lowest %.2f"):format(spec.loop, speed, 1 / period, speed * period, air / N * 100, hi - lo, sunk) }
	for _, p in LIMBS do
		local n, sum, worst, cnt, maxY = 0, 0, 0, 0, 0
		for i = 0, N - 1 do
			local j = (i + 1) % N
			if down[p][i] then cnt += 1; maxY = math.max(maxY, y[p][i]) end
			if down[p][i] and down[p][j] and down[p][(i + N - 1) % N] and down[p][(j + 1) % N] then
				local v = (z[p][j] - z[p][i]) / dt
				n += 1
				sum += v - speed
				worst = math.max(worst, math.abs(v - speed))
				if spec.trace == p then table.insert(trace, ("%d:%+.1f"):format(i, v - speed)) end
			end
		end
		table.insert(line, ("  %s contact %.0f%% skate mean %+.1f worst %.1f maxY %.2f"):format(p, cnt / N * 100, n > 0 and sum / n or 0, worst, maxY))
	end
	table.insert(out, table.concat(line, "\n"))
end
return table.concat(out, "\n") .. (if #trace > 0 then "\ntrace " .. table.concat(trace, " ") else "")
