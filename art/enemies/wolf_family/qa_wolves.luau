--!nocheck
-- QA lineup for the wolf rigs (Spirit Wolf B, Elder Wolf King, Shadow-Mane Wolf): places a
-- PARENTED clone of each template per pose in Workspace._WolfPreview (off the map, X < 0),
-- poses it by forward kinematics with its WeldConstraints live, anchors it, and reports
-- per copy: the worst welded-detail drift from its segment, floating parts in the pose
-- (check_rig's touch test), and in rest the lowest point of each paw.
-- Run in Edit mode through execute_luau:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/wolf_family/qa_wolves.luau?" .. os.clock()))()
-- _G.WOLF_QA_POSES = { "rest", "crouch" } limits the poses; _G.WOLF_QA_MODELS limits models.
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"

local ServerStorage = game:GetService("ServerStorage")
local H = game:GetService("HttpService")

local ORIGIN = CFrame.new(-40, 400, 3000) -- the lineup runs diagonally toward -X, +Z from here
local MODELS = _G.WOLF_QA_MODELS or {
	{ "SpiritWolf_B", ServerStorage._StagingEnemies, "pounce" },
	{ "ShadowManeWolf", ServerStorage._RosterWolves, "shadowWindup" },
	{ "ElderWolfKing", ServerStorage._RosterWolves, "kingWindup" },
}

local A = CFrame.Angles
local POSES = {
	rest = {},
	-- EnemyAnimator's own windup and dash (the only joints it drives today)
	animWindup = {
		JointLegFL = A(-0.25, 0, 0), JointLegFR = A(-0.25, 0, 0), JointLegBL = A(0.3, 0, 0), JointLegBR = A(0.3, 0, 0),
		JointHead = A(-0.3, 0, 0), JointTail = A(-0.55, 0, 0),
	},
	animDash = {
		JointLegFL = A(-0.75, 0, 0), JointLegFR = A(-0.75, 0, 0), JointLegBL = A(0.75, 0, 0), JointLegBR = A(0.75, 0, 0),
		JointHead = A(0.1, 0, 0), JointTail = A(0.25, 0, 0),
	},
	-- the run's widest stride (swing 0.65 * gait 1.3), with the tail swung to its yaw limit
	stride = {
		JointLegFL = A(0.85, 0, 0), JointLegBR = A(0.85, 0, 0), JointLegFR = A(-0.85, 0, 0), JointLegBL = A(-0.85, 0, 0),
		JointTail = A(-0.35, 0.4, 0),
	},
	-- stress: a deep crouch, jaw wide, head turned, tail curled
	crouch = {
		JointRoot = CFrame.new(0, -0.6, 0), JointSpine = A(0.1, 0, 0),
		JointNeck = A(-0.35, 0.35, 0), JointHead = A(0.35, 0.3, 0.15), JointJaw = A(-0.8, 0, 0),
		JointLegFL = A(0.5, 0, 0), JointElbowFL = A(-0.8, 0, 0), JointWristFL = A(0.3, 0, 0),
		JointLegFR = A(0.5, 0, 0), JointElbowFR = A(-0.8, 0, 0), JointWristFR = A(0.3, 0, 0),
		JointLegBL = A(-0.45, 0, 0), JointKneeBL = A(0.8, 0, 0), JointHockBL = A(-0.4, 0, 0),
		JointLegBR = A(-0.45, 0, 0), JointKneeBR = A(0.8, 0, 0), JointHockBR = A(-0.4, 0, 0),
		JointTail = A(0.6, 0.3, 0), JointTail2 = A(0.5, 0.2, 0), JointTail3 = A(0.6, 0, 0),
		JointEarL = A(0.6, 0, 0), JointEarR = A(0.6, 0, 0),
		-- the animator extras at their limits: crest and mane bristled, seal swung, forelock up
		JointCrest = A(-0.3, 0, 0), JointMane = A(-0.25, 0, 0), JointManeL = A(0, 0, -0.3), JointManeR = A(0, 0, 0.3),
		JointSeal = A(0.5, 0, 0), JointForelock = A(-0.35, 0, 0),
	},
	-- stress: the leap at full stretch
	leap = {
		JointRoot = CFrame.new(0, 0.6, 0) * A(0.2, 0, 0), JointSpine = A(-0.15, 0, 0),
		JointNeck = A(-0.15, 0, 0), JointJaw = A(-0.7, 0, 0),
		JointLegFL = A(1.2, 0, 0), JointElbowFL = A(0.3, 0, 0), JointLegFR = A(1.1, 0, 0), JointElbowFR = A(0.3, 0, 0),
		JointLegBL = A(-1.0, 0, 0), JointKneeBL = A(-0.3, 0, 0), JointHockBL = A(-0.4, 0, 0),
		JointLegBR = A(-0.9, 0, 0), JointKneeBR = A(-0.3, 0, 0), JointHockBR = A(-0.4, 0, 0),
		JointTail = A(0.2, 0, 0), JointEarL = A(0.7, 0, 0), JointEarR = A(0.7, 0, 0),
		JointCrest = A(0.25, 0, 0), JointMane = A(0.3, 0, 0), JointManeL = A(0.35, 0, 0.2), JointManeR = A(0.35, 0, -0.2),
		JointSeal = A(-0.6, 0, 0), JointForelock = A(0.3, 0, 0),
	},
}
-- the per-beast windups, as authored in the preview scripts
local function fetch(p)
	return H:GetAsync(BASE .. p .. "?" .. os.clock())
end
POSES.pounce = {
	JointRoot = CFrame.new(0, 0.3, 0) * A(0.15, 0, 0), JointSpine = A(-0.1, 0, 0),
	JointNeck = A(-0.1, 0, 0), JointJaw = A(-0.6, 0, 0),
	JointLegFL = A(1.1, 0, 0), JointElbowFL = A(0.2, 0, 0), JointLegFR = A(1.0, 0, 0), JointElbowFR = A(0.2, 0, 0),
	JointLegBL = A(-0.9, 0, 0), JointKneeBL = A(-0.2, 0, 0), JointHockBL = A(-0.3, 0, 0),
	JointLegBR = A(-0.8, 0, 0), JointKneeBR = A(-0.2, 0, 0), JointHockBR = A(-0.3, 0, 0),
	JointTail = A(0.15, 0, 0), JointEarL = A(0.6, 0, 0), JointEarR = A(0.6, 0, 0),
}
do
	-- pull kingWindup and shadowWindup straight from preview_wolf_family so they never drift apart
	local src = fetch("wolf_family/preview_wolf_family.luau")
	local block = src:match("local POSES = (%b{})")
	local t = loadstring("local CFrame = CFrame return " .. block)()
	POSES.kingWindup, POSES.shadowWindup = t.kingWindup, t.shadowWindup
end

local POSE_LIST = _G.WOLF_QA_POSES or { "rest", "WINDUP", "animWindup", "animDash", "stride", "crouch", "leap" }

local preview = workspace:FindFirstChild("_WolfPreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "_WolfPreview"
	preview:AddTag("EditorOnly")
	preview.Parent = workspace
end
for _, c in preview:GetChildren() do
	if c.Name:match("^QA_") then
		c:Destroy()
	end
end

local function pose(copy, angles)
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") then
			table.insert(motors, m)
		end
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (angles[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree doesn't reach the root")
	end
	for _, m in motors do
		m.Part1 = nil
	end
	-- the copy is parented, so each segment's live WeldConstraints carry its details
	for part, cf in world do
		part.CFrame = cf
	end
end

local checkSrc = fetch("check_rig.luau")
local out = {}
local x = 0
for _, entry in MODELS do
	local name, folder, windup = entry[1], entry[2], entry[3]
	local template = folder:FindFirstChild(name)
	local _, tsize = template:GetBoundingBox()
	for _, pname in POSE_LIST do
		if pname == "WINDUP" then
			pname = windup
		end
		local copy = template:Clone()
		copy.Name = "QA_" .. name .. "_" .. pname
		x -= tsize.Z + 6 -- diagonal steps: side, front and back views each see one copy
		copy:PivotTo(CFrame.new(ORIGIN.Position + Vector3.new(x, template.HumanoidRootPart.Position.Y, -x)))
		copy.HumanoidRootPart.Anchored = true
		copy.Parent = preview
		-- record every welded detail's offset to its segment before posing
		local rest = {}
		for _, w in copy:GetDescendants() do
			if w:IsA("WeldConstraint") then
				rest[w.Part1] = { w.Part0, w.Part0.CFrame:ToObjectSpace(w.Part1.CFrame) }
			end
		end
		pose(copy, POSES[pname])
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local worst, worstName = 0, "-"
		for part, r in rest do
			local now = r[1].CFrame:ToObjectSpace(part.CFrame)
			local drift = (now.Position - r[2].Position).Magnitude
			if drift > worst then
				worst, worstName = drift, part.Name
			end
		end
		local check = loadstring(checkSrc:gsub("local TARGETS = {}", ('local TARGETS = { "Workspace._WolfPreview.%s" }'):format(copy.Name), 1))()
		local floats = {}
		for line in check:gmatch("[^\n]+") do
			local f = line:match("floating: .-([^%.]+)$")
			if f then
				table.insert(floats, f)
			end
		end
		local line = ("%s: drift %.4f (%s)%s"):format(copy.Name, worst, worstName,
			if #floats > 0 then " FLOATING " .. table.concat(floats, ",") else "")
		if pname == "rest" then
			local feet = {}
			for _, seg in { "PawFL", "PawFR", "PawBL", "PawBR" } do
				local lo = math.huge
				for _, d in copy:GetDescendants() do
					if d:IsA("BasePart") and (d.Name == seg or d:GetAttribute("Segment") == seg) then
						local e = d.Size / 2
						for _, sx in { -1, 1 } do
							for _, sy in { -1, 1 } do
								for _, sz in { -1, 1 } do
									lo = math.min(lo, (d.CFrame * Vector3.new(sx * e.X, sy * e.Y, sz * e.Z)).Y)
								end
							end
						end
					end
				end
				table.insert(feet, ("%s %.3f"):format(seg, lo - ORIGIN.Y))
			end
			line ..= " | feet " .. table.concat(feet, ", ")
		end
		table.insert(out, line)
		task.wait()
	end
	x -= 10
end
return table.concat(out, "\n")
