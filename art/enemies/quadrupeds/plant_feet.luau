--!nocheck
-- Pose helper: for a pose in poses_quadrupeds.luau, solves each PLANTED leg so its foot
-- sits flat on the ground (lowest point Y=0): it scans the middle joint's pitch (elbow,
-- knee) for the angle nearest the authored one that puts the foot at 0, then levels the
-- foot joint. Pure forward kinematics on the template, nothing in the place changes.
-- Returns the solved angles to paste into the pose table. Set MODEL, POSE and LEGS with a
-- gsub first. LEGS: { { upper joint, middle joint or nil, foot joint } ... }; a leg with no
-- middle joint (the tortoise) is solved on its upper joint. An optional 4th entry caps how
-- far (radians) the solve may move from the authored angle (default 0.6).
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"

local MODEL = "StoneBoar_R"
local POSE = "WINDUP"
local LEGS = {}

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local POSES = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/poses_quadrupeds.luau?" .. os.clock()))()
local template = ServerStorage._RosterQuadrupeds[MODEL]
local pose = table.clone(POSES[POSE][MODEL])

local motors, byName = {}, {}
for _, m in template:GetDescendants() do
	if m:IsA("Motor6D") then
		table.insert(motors, m)
		byName[m.Name] = m
	end
end
local members = {}
for _, d in template:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local seg = d:GetAttribute("Segment") or d.Name
		local segPart = template:FindFirstChild(seg)
		members[seg] = members[seg] or {}
		table.insert(members[seg], { part = d, off = segPart.CFrame:ToObjectSpace(d.CFrame) })
	end
end

local function solve()
	local world = { [template.HumanoidRootPart] = template.HumanoidRootPart.CFrame }
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

local function lowest(world, seg)
	local segPart = template:FindFirstChild(seg)
	local lo = math.huge
	for _, e in members[seg] do
		local cf = world[segPart] * e.off
		local s = e.part.Size / 2
		lo = math.min(lo, cf.Y - (math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z))
	end
	return lo
end

local function pitchOf(cf)
	local x = cf:ToEulerAnglesXYZ()
	return x
end

local function restPitch(part)
	return pitchOf(part.CFrame)
end
local out = {}
for _, leg in LEGS do
	local upper, mid, foot = leg[1], leg[2], leg[3]
	local solveJoint = mid or upper
	local footPart = byName[foot].Part1
	local base = pose[solveJoint] or CFrame.identity
	local a0 = pitchOf(base)
	local rest = CFrame.new(base.Position) * CFrame.fromEulerAnglesXYZ(0, select(2, base:ToEulerAnglesXYZ()), select(3, base:ToEulerAnglesXYZ()))
	local best, bestErr = a0, math.huge
	for i = -150, 150 do
		local a = i / 100
		pose[solveJoint] = rest * CFrame.Angles(a - 0, 0, 0)
		-- level the foot: undo the foot segment's world pitch
		pose[foot] = CFrame.identity
		local w = solve()
		local fp = pitchOf(w[footPart]) - restPitch(footPart)
		pose[foot] = CFrame.Angles(-fp, 0, 0)
		w = solve()
		local err = math.abs(lowest(w, footPart.Name)) + math.abs(a - a0) * 0.02
		if math.abs(a - a0) > (leg[4] or 0.6) then
			err = math.huge -- stay near the authored bend, never flip the joint
		end
		if err < bestErr then
			best, bestErr = a, err
		end
	end
	pose[solveJoint] = rest * CFrame.Angles(best, 0, 0)
	pose[foot] = CFrame.identity
	local fp = pitchOf(solve()[footPart]) - restPitch(footPart)
	pose[foot] = CFrame.Angles(-fp, 0, 0)
	local w = solve()
	table.insert(out, ("%s = %.2f, %s = pitch(%.2f)  -> foot at %.3f"):format(solveJoint, best, foot, -fp, lowest(w, footPart.Name)))
end
return table.concat(out, "\n")
