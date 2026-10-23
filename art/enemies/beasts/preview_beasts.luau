--!nocheck
-- Lines the roster beasts up in Workspace._RosterPreviewBeasts on a plate off the map at
-- (300, 400, 3000): an R6 player for scale, the old VenomSerpent, then each new beast at
-- rest and in its main attack's windup pose. Run in Edit mode through execute_luau;
-- re-runnable. Posed by forward kinematics like spirit_wolf/preview_wolves.luau, since
-- Motor6D.Transform doesn't move parts in Edit mode.
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"

local PREVIEW_AT = CFrame.new(300, 400, 3000)
local ServerStorage = game:GetService("ServerStorage")

local POSES = loadstring(game:GetService("HttpService"):GetAsync(BASE .. "beasts/poses.luau?" .. os.clock()))()

-- { label, template, x, pose }
local roster = ServerStorage:FindFirstChild("_RosterBeasts")
local function beast(name)
	return roster and roster:FindFirstChild(name)
end
local LINEUP = {
	{ "Player", workspace.Rig, -46 },
	{ "OldVenomSerpent", ServerStorage.Enemies.VenomSerpent, -40 },
	{ "VenomSerpent", beast("VenomSerpent"), -32 },
	{ "VenomSerpentWindup", beast("VenomSerpent"), -22, "VenomSerpent" },
	{ "JadePython", beast("JadePython"), -8 },
	{ "JadePythonWindup", beast("JadePython"), 8, "JadePython" },
	{ "FlameRaven", beast("FlameRaven"), 22 },
	{ "FlameRavenWindup", beast("FlameRaven"), 32, "FlameRaven" },
	{ "ThunderApe", beast("ThunderApe"), 44 },
	{ "ThunderApeWindup", beast("ThunderApe"), 56, "ThunderApe" },
}

local preview = workspace:FindFirstChild("_RosterPreviewBeasts")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_RosterPreviewBeasts"
preview:AddTag("EditorOnly") -- stripped at runtime by EditorOnly.server.luau
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(112, 1, 36)
plate.CFrame = PREVIEW_AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Parent = preview
-- in the DataModel before posing: WeldConstraints only carry details along once the
-- parts are in the workspace
preview.Parent = workspace

local function fk(copy, pose)
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
		assert(pending < before, copy.Name .. ": motor tree doesn't reach the root")
	end
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
end

local placed = {}
for _, entry in LINEUP do
	local label, template, x, poseName = entry[1], entry[2], entry[3], entry[4]
	if not template then
		continue
	end
	local copy = template:Clone()
	copy.Name = label
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	copy.Parent = preview
	if label == "Player" then
		local cf, size = template:GetBoundingBox()
		local lift = template:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
		copy:PivotTo(CFrame.new((PREVIEW_AT * CFrame.new(x, lift, 0)).Position))
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	else
		-- the EnemyService.spawn path: ground + rootHeight, identity rotation
		copy:PivotTo(PREVIEW_AT * CFrame.new(x, template.HumanoidRootPart.Position.Y, 0))
		if poseName then
			fk(copy, POSES[poseName])
		end
	end
	-- The cut motors leave loose segments: anchor everything, or Play drops them in a heap.
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	table.insert(placed, label .. " @x" .. x)
end
return table.concat(placed, ", ")
