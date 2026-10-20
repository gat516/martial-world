-- Studio command-bar tool: lower each spirit peak's surface assets onto its mesh pillar.
-- Assets were authored on the old terrain, which sat a little higher than the mesh top,
-- so many float. Rerun after re-importing the pillar mesh.
--
-- Each asset is measured under its feet (the parts whose bottoms are within FOOT_BAND of
-- the asset's lowest point: trunks, posts, bases), not its whole footprint, so canopies
-- and eaves hanging over the rim don't drag it down. It drops until every foot touches,
-- plus a small embed. Bridge gates stay put: they must meet the bridges.

local CHS = game:GetService("ChangeHistoryService")

local EMBED = 0.1
local FOOT_BAND = 0.6
local MAX_DROP = 3
local FIXED = { "NameStele", "TeleportArray", "SpawnLocation" }

local function parts(inst: Instance): { BasePart }
	if inst:IsA("BasePart") then
		return { inst }
	end
	local list = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(list, d)
		end
	end
	return list
end

local function bottomOfPart(p: BasePart): number
	local cf, s = p.CFrame, p.Size / 2
	-- lowest corner of the part's box
	local low = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				low = math.min(low, (cf * Vector3.new(x * s.X, y * s.Y, z * s.Z)).Y)
			end
		end
	end
	return low
end

-- Largest gap between a foot and the ground under it; nil if no foot is over the pillar.
local function gapUnder(inst: Instance, pillar: Model): number?
	local list = parts(inst)
	local bottom = math.huge
	for _, p in list do
		bottom = math.min(bottom, bottomOfPart(p))
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { pillar }
	local gap
	for _, p in list do
		local footBottom = bottomOfPart(p)
		if footBottom <= bottom + FOOT_BAND then
			local hit = workspace:Raycast(Vector3.new(p.Position.X, footBottom + 4, p.Position.Z), Vector3.new(0, -12, 0), params)
			if hit then
				gap = math.max(gap or -math.huge, footBottom - hit.Position.Y)
			end
		end
	end
	return gap
end

local function move(inst: Instance, dy: number)
	if inst:IsA("BasePart") then
		inst.CFrame -= Vector3.new(0, dy, 0)
	else
		(inst :: Model):PivotTo((inst :: Model):GetPivot() - Vector3.new(0, dy, 0))
	end
end

local recording = CHS:TryBeginRecording("Snap peak assets to ground")
local report = {}
for _, peak in workspace.Map.Sect.SpiritPeaks:GetChildren() do
	local pillar = peak:FindFirstChild("Pillar")
	if not pillar then
		continue
	end
	local targets = {}
	for _, d in peak:GetDescendants() do
		local id = d:GetAttribute("StarterId")
		if type(id) == "string" and not id:match("^Abode/") then -- abode furniture is on the hall floor
			table.insert(targets, d)
		end
	end
	for _, name in FIXED do
		local f = peak:FindFirstChild(name)
		if f then
			table.insert(targets, f)
		end
	end
	local moved = 0
	for _, t in targets do
		local gap = gapUnder(t, pillar :: Model)
		if gap and gap > 0.05 and gap <= MAX_DROP then
			move(t, gap + EMBED)
			moved += 1
		end
	end
	table.insert(report, `{peak.Name}: lowered {moved} of {#targets}`)
end
if recording then
	CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(table.concat(report, "\n"))
return table.concat(report, "\n")
