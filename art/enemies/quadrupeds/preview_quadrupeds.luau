--!nocheck
-- Lines up the quadruped roster in Workspace._RosterPreviewQuadrupeds on a plate at
-- (200, 400, 3000), off the map: an R6 player for scale, the old StoneBoar, then each
-- new body twice, at rest (front row) and in its attack windup pose (back row). Posed by
-- forward kinematics like spirit_wolf/preview_wolves.luau (Motor6D.Transform doesn't move
-- parts in Edit mode). Run in Edit mode through execute_luau; re-runnable.
-- ONLY: set to a model name to preview just that one (rest + windup side by side).

local ONLY = nil
local PREVIEW_AT = CFrame.new(200, 400, 3000)

local ServerStorage = game:GetService("ServerStorage")

local function pitch(a)
	return CFrame.Angles(a, 0, 0)
end

-- Windup poses (rough procedural poses for the later animator pass).
local WINDUP = {
	-- charge: head dropped to aim the tusks, a front hoof pawing, haunches loaded
	StoneBoar_R = {
		JointRoot = CFrame.new(0, -0.35, 0) * pitch(-0.12), JointSpine = pitch(0.05),
		JointNeck = pitch(-0.2), JointHead = pitch(-0.12), JointJaw = pitch(-0.15),
		JointLegFL = pitch(0.5), JointElbowFL = pitch(-0.9), JointWristFL = pitch(0.35),
		JointLegFR = pitch(-0.2), JointElbowFR = pitch(0.15),
		JointLegBL = pitch(-0.25), JointKneeBL = pitch(0.55), JointHockBL = pitch(-0.3),
		JointLegBR = pitch(-0.25), JointKneeBR = pitch(0.55), JointHockBR = pitch(-0.3),
		JointTail = pitch(0.9), JointEarL = pitch(-0.5), JointEarR = pitch(-0.5),
	},
	-- quake stomp: rears up on the hind legs, front feet lifted, head pulled half in
	StoneTortoise_R = {
		JointRoot = CFrame.new(0, 0.55, 0) * pitch(0.32),
		JointNeck = CFrame.new(0, 0, 0.6) * pitch(0.15), JointHead = pitch(-0.35), JointJaw = pitch(-0.45),
		JointLegFL = pitch(0.25), JointElbowFL = pitch(-0.6), JointLegFR = pitch(0.25), JointElbowFR = pitch(-0.6),
		JointLegBL = pitch(-0.32), JointKneeBL = pitch(0.25), JointLegBR = pitch(-0.32), JointKneeBR = pitch(0.25),
		JointTail = pitch(-0.3),
	},
	-- foxfire volley: crouched low, head forward, every tail fanned out wide and raised
	NineTailFox_R = {
		JointRoot = CFrame.new(0, -0.3, 0) * pitch(-0.05), JointSpine = pitch(0.06),
		JointNeck = pitch(-0.35), JointHead = pitch(0.3), JointJaw = pitch(-0.3),
		JointEarL = pitch(-0.2) * CFrame.Angles(0, 0, 0.3), JointEarR = pitch(-0.2) * CFrame.Angles(0, 0, -0.3),
		JointLegFL = pitch(0.45), JointElbowFL = pitch(-0.6), JointWristFL = pitch(0.2),
		JointLegFR = pitch(-0.1), JointElbowFR = pitch(-0.2),
		JointLegBL = pitch(-0.35), JointKneeBL = pitch(0.55), JointHockBL = pitch(-0.3),
		JointLegBR = pitch(-0.25), JointKneeBR = pitch(0.45), JointHockBR = pitch(-0.25),
		JointTail = pitch(-0.35),
	},
}
-- The fox's nine tails fan out by roll about Z: outer tails spread most.
for i = 1, 9 do
	local t = (i - 5) / 4
	WINDUP.NineTailFox_R["JointTail" .. i] = CFrame.Angles(0.05, 0, -t * 0.3)
	WINDUP.NineTailFox_R["JointTail" .. i .. "Tip"] = CFrame.Angles(0.2, 0, -t * 0.15)
end

local function posed(copy, pose)
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") then
			table.insert(motors, m)
		end
	end
	if not copy:FindFirstChild("JointRoot", true) then
		return
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * (pose[m.Name] or CFrame.identity) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree doesn't reach the root")
	end
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
end

local preview = workspace:FindFirstChild("_RosterPreviewQuadrupeds")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_RosterPreviewQuadrupeds"
preview:AddTag("EditorOnly") -- stripped at runtime by EditorOnly.server.luau
preview.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(56, 1, 34)
plate.CFrame = PREVIEW_AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Material = Enum.Material.SmoothPlastic
plate.Parent = preview

local function put(template, name, cf)
	local copy = template:Clone()
	copy.Name = name
	if copy:FindFirstChild("HumanoidRootPart") then
		copy:PivotTo(cf * CFrame.new(0, template.HumanoidRootPart.Position.Y, 0))
	else
		copy:PivotTo(cf)
	end
	if copy:FindFirstChild("HumanoidRootPart") then
		copy.HumanoidRootPart.Anchored = true
	end
	copy.Parent = preview
	return copy
end

-- Anchor everything after posing: a posed copy has cut motors, so Play would drop it.
local function anchor(copy)
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local placed = {}
local player = workspace:FindFirstChild("Rig")
if player then
	local p = player:Clone()
	p.Name = "PlayerScale"
	for _, d in p:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, size = p:GetBoundingBox()
	p:PivotTo(PREVIEW_AT * CFrame.new(-22, size.Y / 2, 0))
	p.Parent = preview
	table.insert(placed, "player")
end
if not ONLY or ONLY == "StoneBoar_R" then
	anchor(put(ServerStorage.Enemies.StoneBoar, "OldStoneBoar", PREVIEW_AT * CFrame.new(-16, 0, 0)))
	table.insert(placed, "old boar")
end

local folder = ServerStorage:FindFirstChild("_RosterQuadrupeds")
local x = -8
for _, name in { "StoneBoar_R", "StoneTortoise_R", "NineTailFox_R" } do
	local template = folder and folder:FindFirstChild(name)
	if template and template:FindFirstChild("HumanoidRootPart") and (not ONLY or ONLY == name) then
		local width = if name == "StoneTortoise_R" then 12 else 9
		anchor(put(template, name, PREVIEW_AT * CFrame.new(x, 0, 6)))
		local w = put(template, name .. "_Windup", PREVIEW_AT * CFrame.new(x, 0, -9))
		posed(w, WINDUP[name] or {})
		anchor(w)
		table.insert(placed, name .. " @x" .. x)
		x += width
	end
end
return table.concat(placed, ", ")
