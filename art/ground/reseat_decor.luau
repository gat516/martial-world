--[[
Re-seats the ground decor near the sect (Map.Ground.InnerRing: BambooForest groves, Trees, Rocks) on the under-sect
terrain (art/ground/terrain_ground.luau). Run in Studio Edit mode (MCP execute_luau) after the terrain; re-runnable.

For each unit (one bamboo cluster, tree or rock) within REACH of the origin and below MAX_Y:
  - inside a rock base (its centre within the outline of a spirit pillar or the main peak's rock, measured at y 12,
    plus MARGIN): pushed straight out from that base until its centre stands MARGIN outside the face;
  - then dropped / lifted so its lowest point sits SINK studs into the terrain (lowest of five samples under it).
Units on the pillars' ledges (above MAX_Y) are left alone.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local REACH = 560
local MAX_Y = 150
local PROFILE_Y, STEPS = 12, 72
local SINK = { BambooCluster = 1.5, Tree = 1, Rock = 2 } -- by kind
local MARGIN = { BambooCluster = 6, Tree = 5, Rock = 3 } -- centre distance outside the rock face, plus half the width

type Base = { c: Vector2, prof: { number } }
local bases: { Base } = {}
local function addBase(model: Instance, center: Vector2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local prof, last = {}, 0
	for s = 0, STEPS - 1 do
		local a = s / STEPS * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local hit = workspace:Raycast(Vector3.new(center.X, PROFILE_Y, center.Y) + dir * 420, -dir * 420, params)
		if hit then
			last = (Vector2.new(hit.Position.X, hit.Position.Z) - center).Magnitude
		end
		prof[s + 1] = last
	end
	table.insert(bases, { c = center, prof = prof })
end
for _, peak in workspace.Map.Sect.SpiritPeaks:GetChildren() do
	local pillar = peak:FindFirstChild("Pillar")
	if pillar and pillar:IsA("Model") then
		local cf = pillar:GetBoundingBox()
		addBase(pillar, Vector2.new(cf.X, cf.Z))
	end
end
addBase(workspace.Map.Sect.MainPeak.Rock, Vector2.new(2, 2))

local function outline(b: Base, dir: Vector2): number
	local a = (math.atan2(dir.Y, dir.X) / (math.pi * 2) * STEPS) % STEPS
	local a0 = math.floor(a)
	local t = a - a0
	local r0, r1 = b.prof[a0 + 1], b.prof[(a0 + 1) % STEPS + 1]
	return r0 + (r1 - r0) * t
end

-- the base whose face is nearest (most inside first), and how far outside it the point is
local function nearestBase(p: Vector2): (Base, number)
	local best, bestE = bases[1], math.huge
	for _, b in bases do
		local v = p - b.c
		local e = v.Magnitude - outline(b, v)
		if e < bestE then
			best, bestE = b, e
		end
	end
	return best, bestE
end

local function aabb(inst: Instance): (Vector3, Vector3)
	local parts = if inst:IsA("BasePart") then { inst } else {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		local cf, s = p.CFrame, p.Size / 2
		local ext = Vector3.new(
			math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
			math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
			math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
		)
		mn = mn:Min(cf.Position - ext)
		mx = mx:Max(cf.Position + ext)
	end
	return mn, mx
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local function groundUnder(c: Vector3, r: number): number?
	local low = math.huge
	for _, o in { Vector2.zero, Vector2.new(r, 0), Vector2.new(-r, 0), Vector2.new(0, r), Vector2.new(0, -r) } do
		local hit = workspace:Raycast(Vector3.new(c.X + o.X, 200, c.Z + o.Y), Vector3.new(0, -400, 0), terrainOnly)
		if not hit then
			return nil
		end
		low = math.min(low, hit.Position.Y)
	end
	return low
end

local function move(inst: Instance, delta: Vector3)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + delta)
	elseif inst:IsA("BasePart") then
		inst.CFrame += delta
	end
end

local ring = workspace.Map.Ground.InnerRing
local units: { { inst: Instance, kind: string } } = {}
for _, grove in ring.BambooForest:GetChildren() do
	for _, u in grove:GetChildren() do
		table.insert(units, { inst = u, kind = "BambooCluster" })
	end
end
for _, u in ring.Trees:GetChildren() do
	table.insert(units, { inst = u, kind = "Tree" })
end
for _, u in ring.Rocks:GetChildren() do
	table.insert(units, { inst = u, kind = "Rock" })
end

local recording = ChangeHistoryService:TryBeginRecording("ReseatGroundDecor")
local pushed, seated = {}, 0
for _, unit in units do
	local mn, mx = aabb(unit.inst)
	local c = (mn + mx) / 2
	local p = Vector2.new(c.X, c.Z)
	if p.Magnitude < REACH and mn.Y < MAX_Y then
		local half = math.min(mx.X - mn.X, mx.Z - mn.Z) / 2
		local base, e = nearestBase(p)
		local want = MARGIN[unit.kind] + half * 0.5
		if e < want - 1 then -- (1 stud of slack keeps re-runs from creeping)
			local dir = (p - base.c).Unit
			local target = base.c + dir * (outline(base, dir) + want)
			move(unit.inst, Vector3.new(target.X - p.X, 0, target.Y - p.Y))
			table.insert(pushed, string.format("%s/%s %.0f", unit.inst.Parent.Name, unit.inst.Name, (target - p).Magnitude))
			mn, mx = aabb(unit.inst)
			c = (mn + mx) / 2
		end
		local gy = groundUnder(c, math.min(half * 0.5, 4))
		if gy then
			local dy = (gy - SINK[unit.kind]) - mn.Y
			if math.abs(dy) > 0.3 then
				move(unit.inst, Vector3.new(0, dy, 0))
				seated += 1
			end
		end
	end
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return string.format("pushed out of rock %d, re-seated %d\n%s", #pushed, seated, table.concat(pushed, "\n"))
