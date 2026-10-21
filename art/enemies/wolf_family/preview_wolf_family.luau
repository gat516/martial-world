--!nocheck
-- Lines up the wolf family in Workspace._RosterPreviewWolves on a plate at PREVIEW_AT,
-- off the map: an R6 player for scale, the old ElderWolfKing, the new one in two poses
-- and the Shadow-Mane Wolf in two poses. Posed by forward kinematics like
-- art/enemies/spirit_wolf/preview_wolves.luau (Motor6D.Transform doesn't move parts in
-- Edit mode). Run in Edit mode through execute_luau; re-runnable.

local PREVIEW_AT = CFrame.new(100, 400, 3000)
local STAGING = "_RosterWolves"
-- set _G.WOLF_SOLO to one slot name (e.g. "newElderWolfKingkingWindup") to place only that
-- slot and the player, for front and close-up captures
local SOLO = _G.WOLF_SOLO

local ServerStorage = game:GetService("ServerStorage")

-- Joint angles in model space (identity joint frames: X is pitch on every joint).
local POSES = {
	rest = {},
	-- King, roar / cone bite windup: drops its chest, braces both forelegs, neck low and
	-- head up at the target, jaw wide, ears pinned, tail raised
	kingWindup = {
		JointRoot = CFrame.new(0, -0.5, 0) * CFrame.Angles(-0.06, 0, 0), JointSpine = CFrame.Angles(0.06, 0, 0),
		JointNeck = CFrame.Angles(-0.3, 0, 0), JointHead = CFrame.Angles(0.3, 0, 0), JointJaw = CFrame.Angles(-0.75, 0, 0),
		JointLegFL = CFrame.Angles(0.3, 0, 0.08), JointElbowFL = CFrame.Angles(-0.45, 0, 0), JointWristFL = CFrame.Angles(0.1, 0, 0),
		JointLegFR = CFrame.Angles(0.3, 0, -0.08), JointElbowFR = CFrame.Angles(-0.45, 0, 0), JointWristFR = CFrame.Angles(0.1, 0, 0),
		JointLegBL = CFrame.Angles(-0.25, 0, 0), JointKneeBL = CFrame.Angles(0.45, 0, 0), JointHockBL = CFrame.Angles(-0.2, 0, 0),
		JointLegBR = CFrame.Angles(-0.25, 0, 0), JointKneeBR = CFrame.Angles(0.45, 0, 0), JointHockBR = CFrame.Angles(-0.2, 0, 0),
		JointTail = CFrame.Angles(0.45, 0, 0), JointTail2 = CFrame.Angles(0.15, 0, 0),
		JointEarL = CFrame.Angles(0.5, 0, 0), JointEarR = CFrame.Angles(0.5, 0, 0),
	},
	-- Shadow-Mane, lunge windup: low stalk, belly near the ground, head forward and down
	shadowWindup = {
		JointRoot = CFrame.new(0, -0.45, 0), JointSpine = CFrame.Angles(0.08, 0, 0),
		JointNeck = CFrame.Angles(-0.3, 0, 0), JointHead = CFrame.Angles(0.25, 0, 0), JointJaw = CFrame.Angles(-0.3, 0, 0),
		JointLegFL = CFrame.Angles(0.45, 0, 0), JointElbowFL = CFrame.Angles(-0.65, 0, 0), JointWristFL = CFrame.Angles(0.15, 0, 0),
		JointLegFR = CFrame.Angles(0.3, 0, 0), JointElbowFR = CFrame.Angles(-0.55, 0, 0), JointWristFR = CFrame.Angles(0.2, 0, 0),
		JointLegBL = CFrame.Angles(-0.35, 0, 0), JointKneeBL = CFrame.Angles(0.6, 0, 0), JointHockBL = CFrame.Angles(-0.3, 0, 0),
		JointLegBR = CFrame.Angles(-0.25, 0, 0), JointKneeBR = CFrame.Angles(0.5, 0, 0), JointHockBR = CFrame.Angles(-0.25, 0, 0),
		JointTail = CFrame.Angles(-0.25, 0, 0), JointTail2 = CFrame.Angles(-0.15, 0, 0), JointTail3 = CFrame.Angles(0.2, 0, 0),
		JointEarL = CFrame.Angles(0.5, 0, 0), JointEarR = CFrame.Angles(0.5, 0, 0),
	},
}

local LINEUP = {
	{ "rig" },
	{ "old", "ElderWolfKing" },
	{ "new", "ElderWolfKing", "rest" },
	{ "new", "ElderWolfKing", "kingWindup" },
	{ "new", "ShadowManeWolf", "rest" },
	{ "new", "ShadowManeWolf", "shadowWindup" },
}
-- per slot, along plate X; every body is yawed to face -X so a camera on +Z sees them side-on
local X = { -44, -26, 2, 30, 52, 64 }

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
	-- The copy is parented (WeldConstraints only hold inside the DataModel), so once the
	-- motors are cut, moving a segment carries its welded details with it.
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
end

local preview = workspace:FindFirstChild("_RosterPreviewWolves")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_RosterPreviewWolves"
preview:AddTag("EditorOnly") -- stripped at runtime by EditorOnly.server.luau
preview.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(130, 1, 30)
plate.CFrame = PREVIEW_AT * CFrame.new(8, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Parent = preview

local placed = {}
for i, slot in LINEUP do
	local template = if slot[1] == "rig" then workspace.Rig
		elseif slot[1] == "old" then ServerStorage.Enemies[slot[2]]
		else ServerStorage[STAGING]:FindFirstChild(slot[2])
	local slotName = slot[1] .. (slot[2] or "Player") .. (slot[3] or "")
	if template and (not SOLO or slot[1] == "rig" or slotName == SOLO) then
		local copy = template:Clone()
		copy.Name = slotName
		local at = PREVIEW_AT * CFrame.new(X[i], 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		if slot[1] == "rig" then
			local cf, size = copy:GetBoundingBox()
			copy:PivotTo(CFrame.new(at.Position + Vector3.new(0, size.Y / 2 + (copy:GetPivot().Position.Y - cf.Position.Y), 0)))
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
		else
			copy:PivotTo(CFrame.new(at.Position + Vector3.new(0, template.HumanoidRootPart.Position.Y, 0)) * at.Rotation)
			copy.HumanoidRootPart.Anchored = true
			copy.Parent = preview
			if slot[3] and copy:FindFirstChild("JointRoot", true) then
				pose(copy, POSES[slot[3]])
			end
		end
		-- the cut motors leave loose segments: anchor everything, or Play drops them in a heap
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		copy.Parent = preview
		table.insert(placed, copy.Name)
	end
end
return table.concat(placed, ", ")
