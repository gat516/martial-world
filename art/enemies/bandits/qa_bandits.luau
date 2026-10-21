--!nocheck
-- Rig-contract and posed-integrity check for the bandit roster (ServerStorage._RosterBandits).
-- Run in Edit mode through execute_luau (served from the local art server). Read-only on the
-- templates; posing happens on parented clones in Workspace._RosterPreviewBandits._QA, which is
-- removed again before returning. Reports per model:
--   ground    lowest visible point (should be 0) and the HRP height
--   contract  HRP / Humanoid / HealthBar / streaming / part flags / scripts / joint frames
--   armour    every detail part welded to a limb and parented inside it
--   walk      stock R6 walk (180426354) stepped on an Animator, Transform vs a Workspace.Rig control
--   drift     each welded piece's offset to its limb after FK posing (rest, windups, stress)

local ServerStorage = game:GetService("ServerStorage")
local NAMES = { "MountainBandit", "BanditArcher", "BanditChief" }
local WALK = "rbxassetid://180426354"
local A = CFrame.Angles
local STOCK = { "Neck", "RootJoint", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local LIMBS = { Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }

local HttpService = game:GetService("HttpService")
local PZ = loadstring(HttpService:GetAsync("http://127.0.0.1:8767/bandits/bandit_poses.luau?" .. os.clock()))()
local CLIP = 0.12 -- studs of penetration between pieces of different bodies that counts as a clip

local function stockJoint(rig, name)
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
end

local function cfClose(a, b, eps)
	return (a.Position - b.Position).Magnitude < eps and (a.XVector - b.XVector).Magnitude < eps
		and (a.YVector - b.YVector).Magnitude < eps
end

local function contract(m)
	local out = {}
	local hrp = m:FindFirstChild("HumanoidRootPart")
	local s = m:GetScale()
	local minY, maxY = math.huge, -math.huge
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= hrp and d.Transparency < 1 then
			local c, h = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local y = (c * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y
						minY, maxY = math.min(minY, y), math.max(maxY, y)
					end
				end
			end
		end
	end
	table.insert(out, ("ground minY %.3f maxY %.2f HRP Y %.2f (want %.2f)"):format(minY, maxY, hrp.Position.Y, 3 * s))
	if hrp.CFrame.Rotation ~= CFrame.identity then
		table.insert(out, "FAIL HRP rotated")
	end
	if m.PrimaryPart ~= hrp then
		table.insert(out, "FAIL PrimaryPart")
	end
	if not cfClose(m.WorldPivot, hrp.CFrame, 1e-3) then
		table.insert(out, "FAIL WorldPivot not at HRP")
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R6 or hum.HipHeight ~= 0
		or hum.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None or hum.BreakJointsOnDeath then
		table.insert(out, "FAIL Humanoid settings")
	end
	if not hum:FindFirstChildOfClass("Animator") then
		table.insert(out, "note: no Animator under Humanoid (created at runtime)")
	end
	local bar = hrp:FindFirstChild("HealthBar")
	if not bar then
		table.insert(out, "FAIL no HealthBar")
	else
		local barY = hrp.Position.Y + bar.StudsOffset.Y
		table.insert(out, ("bar at Y %.2f, %.2f above the top"):format(barY, barY - maxY))
	end
	if m.ModelStreamingMode ~= Enum.ModelStreamingMode.Atomic then
		table.insert(out, "FAIL streaming not Atomic")
	end
	local bad = {}
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(bad, "script " .. d.Name)
		elseif d:IsA("BasePart") and d ~= hrp then
			if d.Anchored or d.CanCollide or d.CanTouch or d.CanQuery or not d.Massless then
				table.insert(bad, "flags " .. d.Name)
			end
			if d.Material ~= Enum.Material.SmoothPlastic and d.Material ~= Enum.Material.Neon then
				table.insert(bad, "material " .. d.Name .. " " .. d.Material.Name)
			end
			if d.Material == Enum.Material.Neon and not d:GetAttribute("Tell") then
				table.insert(bad, "neon non-tell " .. d.Name)
			end
			if LIMBS[d.Name] and d.Transparency > 0 then
				table.insert(bad, "limb hidden " .. d.Name)
			end
			if not LIMBS[d.Name] then
				local seg = d:GetAttribute("Segment")
				if seg and not d:FindFirstAncestorWhichIsA("Model").Parent:IsA("Model") then
					local w = d:FindFirstChild("Weld") or d:FindFirstChild("AccessoryWeld")
					local owner
					for _, q in m:GetDescendants() do
						if q:IsA("BasePart") and q.Name == seg then
							owner = q
						end
					end
					local okWeld = w and ((w.Part0 == owner and w.Part1 == d) or (w.Part0 == d and w.Part1 == owner))
					if not okWeld then
						table.insert(bad, "weld " .. d.Name)
					end
					if d.Parent ~= owner then
						table.insert(bad, "parent " .. d.Name .. " in " .. d.Parent.Name)
					end
				end
			end
		end
	end
	if #bad > 0 then
		table.insert(out, "FAIL " .. #bad .. ": " .. table.concat(bad, ", ", 1, math.min(#bad, 12)))
	end
	-- stock joint frames vs Workspace.Rig, scaled
	local jbad = {}
	for _, n in STOCK do
		local a, b = stockJoint(m, n), stockJoint(workspace.Rig, n)
		if not a then
			table.insert(jbad, n .. " missing")
		else
			local function sc(cf)
				return CFrame.new(cf.Position * s) * cf.Rotation
			end
			if not cfClose(a.C0, sc(b.C0), 1e-3) or not cfClose(a.C1, sc(b.C1), 1e-3)
				or a.Part0.Name ~= b.Part0.Name or a.Part1.Name ~= b.Part1.Name then
				table.insert(jbad, n)
			end
		end
	end
	table.insert(out, if #jbad == 0 then "joints match Workspace.Rig (scale " .. s .. ")" else "FAIL joints " .. table.concat(jbad, ","))
	return out
end

-- Step the stock walk on a parented clone and on a Workspace.Rig clone, compare Transforms.
local function walkTest(template, holder)
	local function run(src)
		local c = src:Clone()
		for _, d in c:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		c:PivotTo(CFrame.new(0, 300 + c:GetExtentsSize().Y, -900))
		c.HumanoidRootPart.Anchored = true
		c.Parent = holder
		local hum = c:FindFirstChildOfClass("Humanoid")
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = WALK
		local track = animator:LoadAnimation(anim)
		track:Play(0)
		local res = {}
		for _, t in { 0.2, 0.25, 0.25 } do
			animator:StepAnimations(t)
			for _, n in STOCK do
				local mtr = stockJoint(c, n)
				table.insert(res, mtr.Transform)
			end
		end
		track:Stop(0)
		c:Destroy()
		return res
	end
	local a, b = run(template), run(workspace.Rig)
	local worst, moved = 0, 0
	for i = 1, #a do
		local d = (a[i].LookVector - b[i].LookVector).Magnitude + (a[i].UpVector - b[i].UpVector).Magnitude
		worst = math.max(worst, d)
		moved = math.max(moved, (a[i].LookVector - Vector3.new(0, 0, -1)).Magnitude + (a[i].UpVector - Vector3.yAxis).Magnitude)
	end
	return ("walk: max rotation diff vs control %.4f, max joint swing %.2f"):format(worst, moved)
end

-- Engine pose test on a parented clone: HRP anchored, everything else loose, each motor's C0
-- set to C0 * pose (Edit mode solves joints on C0 changes, unlike Transform). Then every Weld
-- and AccessoryWeld is measured: Part1 against Part0 * C0 * C1^-1. Any part that didn't come
-- along with its limb (missing weld, wrong C0, a stray anchor) shows up as drift.
local function drift(template, holder, poseTable)
	local c = template:Clone()
	c:PivotTo(CFrame.new(60, 300, -900))
	c.Parent = holder
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	local aim
	for _, d in c:GetDescendants() do
		if d:IsA("Motor6D") and poseTable[d.Name] then
			if poseTable[d.Name] == "aim" then
				aim = d
			else
				d.C0 = d.C0 * poseTable[d.Name]
			end
		end
	end
	if aim then
		aim.C0 = aim.C0 * PZ.solveAim(aim, { [aim.Part0] = aim.Part0.CFrame })
	end
	local worst, who = 0, ""
	for _, d in c:GetDescendants() do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			local want = d.Part0.CFrame * d.C0 * d.C1:Inverse()
			local e = (want.Position - d.Part1.Position).Magnitude
			if e > worst then
				worst, who = e, d.Part1.Name
			end
		end
	end
	return c, worst, who
end

-- Penetration depth of two oriented boxes (0 when apart), by the separating axis theorem.
-- The visible box of a part: the R6 Head part is 2x1x1 but its Head mesh shows ~1.25 cubed.
local function extents(p)
	local mesh = p:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		return mesh.Scale * p.Size.Y / 2
	end
	return p.Size / 2
end

local function depth(a, b)
	local ca, cb = a.CFrame, b.CFrame
	local ea, eb = extents(a), extents(b)
	local axA = { ca.RightVector, ca.UpVector, ca.LookVector }
	local axB = { cb.RightVector, cb.UpVector, cb.LookVector }
	local d = cb.Position - ca.Position
	local best = math.huge
	local function test(n)
		local ra = math.abs(axA[1]:Dot(n)) * ea.X + math.abs(axA[2]:Dot(n)) * ea.Y + math.abs(axA[3]:Dot(n)) * ea.Z
		local rb = math.abs(axB[1]:Dot(n)) * eb.X + math.abs(axB[2]:Dot(n)) * eb.Y + math.abs(axB[3]:Dot(n)) * eb.Z
		best = math.min(best, ra + rb - math.abs(d:Dot(n)))
	end
	for i = 1, 3 do
		test(axA[i])
		test(axB[i])
		for j = 1, 3 do
			local c = axA[i]:Cross(axB[j])
			if c.Magnitude > 1e-4 then
				test(c.Unit)
			end
		end
	end
	return math.max(best, 0)
end

-- Body of each visible part: the jointed part (R6 limb, extra joint or weapon hilt) it is
-- welded to, followed up the weld chain.
local function bodies(model)
	local weldTo = {}
	for _, d in model:GetDescendants() do
		if (d:IsA("Weld") or d:IsA("WeldConstraint")) and d.Part0 and d.Part1 then
			-- the welded piece is whichever end isn't a motor's Part1
			weldTo[d.Part1] = d.Part0
		end
	end
	local motor1 = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			motor1[d.Part1] = true
		end
	end
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			local p, n = d, 0
			while not motor1[p] and weldTo[p] and n < 10 do
				p, n = weldTo[p], n + 1
			end
			out[d] = p
		end
	end
	return out
end

-- The R6 limb a body hangs from (up the motor chain).
local function limbOf(model, body)
	local p, n = body, 0
	while not LIMBS[p.Name] and n < 10 do
		local up
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d.Part1 == p then
				up = d.Part0
			end
		end
		if not up then
			break
		end
		p, n = up, n + 1
	end
	return p
end

-- Pairs that interpenetrate in the posed clone but not in the rest template, deeper than
-- the bare R6 limbs they hang from already do (stock R6 limbs cross each other in big
-- poses; that's the rig, not the dress). Pairs on the same limb are skipped.
local function clips(template, posed)
	local restB, poseB = bodies(template), bodies(posed)
	local byPath = {}
	for p in restB do
		byPath[p:GetFullName():gsub("^.-" .. template.Name .. "%.", "")] = p
	end
	local limb = {}
	for _, b in poseB do
		limb[b] = limb[b] or limbOf(posed, b)
	end
	local list, out = {}, {}
	for p in poseB do
		table.insert(list, p)
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local la, lb = limb[poseB[a]], limb[poseB[b]]
			if la ~= lb and not (LIMBS[a.Name] and LIMBS[b.Name]) then
				local dp = depth(a, b)
				if dp > CLIP and dp > depth(la, lb) + CLIP then
					local ra = byPath[a:GetFullName():gsub("^.-" .. posed.Name .. "%.", "")]
					local rb = byPath[b:GetFullName():gsub("^.-" .. posed.Name .. "%.", "")]
					if ra and rb and depth(ra, rb) < CLIP then
						table.insert(out, ("%s/%s %.2f"):format(a.Name, b.Name, dp))
					end
				end
			end
		end
	end
	table.sort(out)
	return out
end

local qa = Instance.new("Folder")
qa.Name = "_QA"
qa.Parent = workspace:FindFirstChild("_RosterPreviewBandits") or workspace
local report = {}
for _, name in NAMES do
	local m = ServerStorage._RosterBandits[name]
	local lines = contract(m)
	local ok, w = pcall(walkTest, m, qa)
	table.insert(lines, if ok then w else "walk ERROR " .. tostring(w))
	local dr = {}
	local poses = { rest = PZ.POSES[name].rest, windup = PZ.POSES[name].windup, stride = PZ.TEST.stride, raised = PZ.TEST.raised }
	local cl = {}
	for _, pname in { "rest", "windup", "stride", "raised" } do
		local c, worst, who = drift(m, qa, poses[pname])
		c.Name = name
		table.insert(dr, ("%s %.4f (%s)"):format(pname, worst, who))
		local found = clips(m, c)
		if #found > 0 then
			table.insert(cl, pname .. ": " .. table.concat(found, ", "))
		end
		c:Destroy()
	end
	table.insert(lines, "drift " .. table.concat(dr, ", "))
	table.insert(lines, if #cl == 0 then "clip: none" else "clip\n    " .. table.concat(cl, "\n    "))
	table.insert(report, name .. "\n  " .. table.concat(lines, "\n  "))
end
qa:Destroy()
return table.concat(report, "\n")
