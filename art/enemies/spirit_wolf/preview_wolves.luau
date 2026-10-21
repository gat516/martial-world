--!nocheck
-- Lines up the wolf bodies for comparison in Workspace._WolfPreview, off the map: the
-- current SpiritWolf, variant A and variant B (whichever exist), anchored on a plate,
-- each optionally posed. Run in Edit mode through execute_luau; re-runnable.
-- POSE: "rest", "stalk", "pounce" or "stagger" (a rough procedural pose per joint).

local POSE = "rest"
local PREVIEW_AT = CFrame.new(0, 400, 3000)
local SPACING = 8

local ServerStorage = game:GetService("ServerStorage")

local POSES = {
	stalk = {
		JointRoot = CFrame.new(0, -0.35, 0), JointSpine = CFrame.Angles(0.08, 0, 0),
		JointNeck = CFrame.Angles(-0.25, 0, 0), JointHead = CFrame.Angles(0.15, 0, 0),
		JointLegFL = CFrame.Angles(0.35, 0, 0), JointElbowFL = CFrame.Angles(-0.5, 0, 0),
		JointLegFR = CFrame.Angles(-0.2, 0, 0), JointElbowFR = CFrame.Angles(-0.2, 0, 0),
		JointLegBL = CFrame.Angles(-0.3, 0, 0), JointKneeBL = CFrame.Angles(0.5, 0, 0), JointHockBL = CFrame.Angles(-0.25, 0, 0),
		JointLegBR = CFrame.Angles(-0.1, 0, 0), JointKneeBR = CFrame.Angles(0.3, 0, 0),
		JointTail = CFrame.Angles(-0.2, 0, 0), JointTail3 = CFrame.Angles(0.4, 0, 0),
		JointJaw = CFrame.Angles(-0.35, 0, 0), JointEarL = CFrame.Angles(0.4, 0, 0), JointEarR = CFrame.Angles(0.4, 0, 0),
	},
	pounce = {
		JointRoot = CFrame.new(0, 0.3, 0) * CFrame.Angles(0.15, 0, 0), JointSpine = CFrame.Angles(-0.1, 0, 0),
		JointNeck = CFrame.Angles(-0.1, 0, 0), JointJaw = CFrame.Angles(-0.6, 0, 0),
		JointLegFL = CFrame.Angles(1.1, 0, 0), JointElbowFL = CFrame.Angles(0.2, 0, 0),
		JointLegFR = CFrame.Angles(1.0, 0, 0), JointElbowFR = CFrame.Angles(0.2, 0, 0),
		JointLegBL = CFrame.Angles(-0.9, 0, 0), JointKneeBL = CFrame.Angles(-0.2, 0, 0), JointHockBL = CFrame.Angles(-0.3, 0, 0),
		JointLegBR = CFrame.Angles(-0.8, 0, 0), JointKneeBR = CFrame.Angles(-0.2, 0, 0), JointHockBR = CFrame.Angles(-0.3, 0, 0),
		JointTail = CFrame.Angles(0.15, 0, 0), JointEarL = CFrame.Angles(0.6, 0, 0), JointEarR = CFrame.Angles(0.6, 0, 0),
	},
	stagger = {
		JointRoot = CFrame.Angles(-0.15, 0, 0), JointNeck = CFrame.Angles(0.5, 0, 0), JointHead = CFrame.Angles(0.3, 0, 0),
		JointJaw = CFrame.Angles(-0.3, 0, 0),
		JointLegFL = CFrame.Angles(-0.4, 0, 0.2), JointLegFR = CFrame.Angles(-0.4, 0, -0.2),
		JointLegBL = CFrame.Angles(0.3, 0, 0.15), JointLegBR = CFrame.Angles(0.3, 0, -0.15),
		JointTail = CFrame.Angles(0.5, 0, 0), JointTail2 = CFrame.Angles(0.3, 0, 0),
	},
}

local preview = workspace:FindFirstChild("_WolfPreview")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_WolfPreview"
preview:AddTag("EditorOnly") -- stripped at runtime by EditorOnly.server.luau
preview.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(40, 1, 24)
plate.CFrame = PREVIEW_AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Parent = preview

local list = { ServerStorage.Enemies.SpiritWolf }
for _, name in { "SpiritWolf_A", "SpiritWolf_B" } do
	local m = ServerStorage:FindFirstChild("_StagingEnemies") and ServerStorage._StagingEnemies:FindFirstChild(name)
	if m then
		table.insert(list, m)
	end
end
local placed = {}
for i, template in list do
	local copy = template:Clone()
	copy.Name = if template.Parent.Name == "Enemies" then "Current" else template.Name
	local x = (i - (#list + 1) / 2) * SPACING
	copy:PivotTo(PREVIEW_AT * CFrame.new(x, template.HumanoidRootPart.Position.Y, 0))
	copy.HumanoidRootPart.Anchored = true
	copy.Parent = preview
	-- Transform doesn't move parts in Edit mode, so pose by forward kinematics: solve
	-- every segment's CFrame from its parent, cut the motors, then move each segment
	-- (and the details welded to it).
	local pose = POSES[POSE]
	if pose and copy:FindFirstChild("JointRoot", true) then -- the old wolf's tree isn't rooted
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
	-- The cut motors leave loose segments: anchor everything, or Play drops them in a heap.
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	table.insert(placed, copy.Name .. " @x" .. x)
end
return table.concat(placed, ", ")
