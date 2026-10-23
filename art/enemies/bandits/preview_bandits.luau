--!nocheck
-- Lines up the bandit roster in Workspace._RosterPreviewBandits on a plate at PREVIEW_AT:
-- an R6 player for scale, then each bandit at rest and in its attack windup pose.
-- Poses by forward kinematics (Transform doesn't move parts in Edit mode): solve each
-- R6 part from its parent through C0 * pose * C1^-1, cut the motors, then move every
-- detail part with the segment it's welded to. Run in Edit mode; re-runnable.

local PREVIEW_AT = CFrame.new(400, 400, 3000)
local SPACING = 5
local ONLY = nil -- e.g. "MountainBandit" to preview one model (gsub it for single-model captures)
local MODE = "attack" -- PREVIEW_MODE -- "attack": rest + windup; "test": stride + arms raised (clipping check)
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"

local ServerStorage = game:GetService("ServerStorage")

local HttpService = game:GetService("HttpService")
local PZ = loadstring(HttpService:GetAsync(BASE .. "bandits/bandit_poses.luau?" .. os.clock()))()
local POSES, TEST = PZ.POSES, PZ.TEST

local preview = workspace:FindFirstChild("_RosterPreviewBandits")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "_RosterPreviewBandits"
preview:AddTag("EditorOnly") -- stripped at runtime; every part in it is anchored
preview.Parent = workspace
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(44, 1, 20)
plate.CFrame = PREVIEW_AT * CFrame.new(0, -0.5, 0)
plate.Color = Color3.fromHex("6E7F5A")
plate.Material = Enum.Material.SmoothPlastic
plate.Parent = preview

local function pose(copy, p)
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(motors, m)
		end
	end
	-- each non-motor part follows the segment it hangs off
	local byName = {}
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			byName[part.Name] = byName[part.Name] or part
		end
	end
	local follow = {}
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			local seg = part:GetAttribute("Segment")
			local owner = seg and byName[seg]
			if owner and owner ~= part then
				follow[part] = { owner, owner.CFrame:Inverse() * part.CFrame }
			end
		end
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				local q = p[m.Name] or CFrame.identity
				if q == "aim" then
					q = PZ.solveAim(m, world)
				end
				world[m.Part1] = world[m.Part0] * m.C0 * q * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before, "motor tree doesn't reach the root")
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end
	for part, f in follow do
		part.CFrame = f[1].CFrame * f[2]
	end
end

local rows = { { workspace.Rig, nil, "Player" } }
for _, name in { "MountainBandit", "BanditArcher", "BanditChief" } do
	local m = ServerStorage._RosterBandits:FindFirstChild(name)
	if m and (not ONLY or ONLY == name) then
		local pair = if MODE == "test" then { "stride", "raised" } else { "rest", "windup" }
		for _, which in pair do
			table.insert(rows, { m, which, name .. "_" .. which })
		end
	end
end
local placed = {}
for i, row in rows do
	local template, which, label = row[1], row[2], row[3]
	local copy = template:Clone()
	copy.Name = label
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local x = (i - (#rows + 1) / 2) * SPACING
	local y = if which then template.HumanoidRootPart.Position.Y else 3
	copy.PrimaryPart = copy.HumanoidRootPart
	copy:PivotTo(PREVIEW_AT * CFrame.new(x, y, 0))
	copy.Parent = preview
	if which then
		pose(copy, TEST[which] or POSES[template.Name][which])
	else
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end
	table.insert(placed, label .. " @x" .. x)
end
return table.concat(placed, ", ")
