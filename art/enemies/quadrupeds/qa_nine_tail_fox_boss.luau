--!nocheck
-- Numeric QA for NineTailFoxB's tails. Run in Edit mode through execute_luau (art server on
-- :8767) after build + rig. Poses a parented clone (anchored, EditorOnly folder, destroyed
-- afterwards) through stress poses of the nine telescoping tails and reports per pose:
--   reach   farthest whip end from the tail root (rest ~10, extended ~24)
--   minOv   smallest sleeve overlap (fraction of the inner sleeve's length inside its parent
--           along the parent's axis), at the worst tail
--   poke    worst lateral stick-out of a child's axis at the parent's mouth past the parent radius
--   body    tail sleeves overlapping the body (legs, chest, hips, neck, head) other than the hub
--   floor   lowest point of any tail part (< 0 sinks into the ground)
--   drift   worst welded-detail drift against its segment
-- Poses: Transform = rotation * CFrame.new(ExtendAxis * e). Rotation LAST keeps the hinge at the
-- parent's mouth at every extension (translation-last would hinge at a point sliding with the child).
local BASE = "http://127.0.0.1:8767/"
local HttpService = game:GetService("HttpService")
local TAIL = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/nine_tail_fox_boss_tails.luau?" .. os.clock()))()
local lay = TAIL.layout()
local template = game:GetService("ServerStorage")._RosterQuadrupeds.NineTailFoxB
local K = template:GetAttribute("Scale") / 2.4 -- TAIL.* constants are pre-scale

local function tailT(i)
	return (i - 5) / 4
end
-- pose = function(i) -> { base = CFrame?, ext = fraction, mid = CFrame?, tip = CFrame?, whip = CFrame? }
local POSES = {
	rest = function(i) return { ext = 0 } end,
	full = function(i) return { ext = 1 } end,
	fanRest = function(i) return { ext = 0, base = CFrame.Angles(0, 0, -tailT(i) * 0.55) } end,
	fanFull = function(i) return { ext = 1, base = CFrame.Angles(0, 0, -tailT(i) * 0.55) } end,
	fanNarrow = function(i) return { ext = 1, base = CFrame.Angles(0, 0, tailT(i) * 0.4) } end,
	sweptRest = function(i) return { ext = 0, base = CFrame.Angles(0.5, 0, 0) } end,
	sweptFull = function(i) return { ext = 1, base = CFrame.Angles(0.5, 0, 0) } end,
	raisedRest = function(i) return { ext = 0, base = CFrame.Angles(-0.25, 0, 0) } end,
	raisedFull = function(i) return { ext = 1, base = CFrame.Angles(-0.25, 0, 0) } end,
	plungeOdd = function(i)
		return { ext = if i % 2 == 1 then 1 else 0, base = if i % 2 == 1 then CFrame.Angles(1.7, 0, 0) else nil }
	end,
	plunge10 = function(i)
		return { ext = if i % 2 == 1 then 1 else 0, base = if i % 2 == 1 then CFrame.Angles(1.0, 0, 0) else nil }
	end,
	plungeFan = function(i) -- pitched forward-down with the fan splayed, tails reaching the ground ahead of the hind legs
		return { ext = if i % 2 == 1 then 1 else 0, base = if i % 2 == 1 then CFrame.Angles(1.7, 0, 0) * CFrame.Angles(0, 0, -tailT(i) * 0.9) else nil }
	end,
	bendRest = function(i) return { ext = 0, mid = CFrame.Angles(0.05, 0, 0.05), tip = CFrame.Angles(-0.06, 0, -0.06), whip = CFrame.Angles(0.08, 0, 0.08) } end,
	bendHalf = function(i) return { ext = 0.5, mid = CFrame.Angles(0.1, 0, 0.1), tip = CFrame.Angles(-0.12, 0, -0.12), whip = CFrame.Angles(0.2, 0, 0.2) } end,
	bendFull = function(i) return { ext = 1, mid = CFrame.Angles(0.1, 0, 0.1), tip = CFrame.Angles(-0.1, 0, -0.1), whip = CFrame.Angles(0.22, 0, 0.22) } end,
	bendFullBig = function(i) return { ext = 1, mid = CFrame.Angles(0.3, 0, 0.3), tip = CFrame.Angles(-0.3, 0, -0.3), whip = CFrame.Angles(0.5, 0, 0.5) } end,
}
local ORDER = { "rest", "full", "fanRest", "fanFull", "fanNarrow", "sweptRest", "sweptFull", "raisedRest", "raisedFull",
	"plungeOdd", "plunge10", "plungeFan", "bendRest", "bendHalf", "bendFull", "bendFullBig" }

local HUB = { Tail = true, Hips = true, HipsTop = true, HipsShoulder1 = true, ["HipsShoulder-1"] = true }

local function relMap(model)
	local segs, r = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not d:GetAttribute("Segment") then
			segs[d.Name] = d
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Segment") then
			r[d.Name] = segs[d:GetAttribute("Segment")].CFrame:ToObjectSpace(d.CFrame)
		end
	end
	return r
end

local function run(poseName)
	local folder = Instance.new("Folder")
	folder.Name = "_FoxQA"
	folder:AddTag("EditorOnly")
	folder.Parent = workspace
	local copy = template:Clone()
	copy:PivotTo(CFrame.new(300, template.HumanoidRootPart.Position.Y, 0))
	copy.HumanoidRootPart.Anchored = true
	copy.Parent = folder
	local origin = CFrame.new(300, 0, 0)
	local motors = {}
	for _, m in copy:GetDescendants() do
		if m:IsA("Motor6D") then
			table.insert(motors, m)
		end
	end
	local spec = {}
	for i = 1, 9 do
		spec[i] = POSES[poseName](i)
	end
	local function transformFor(m)
		local i, kind = m.Name:match("^JointTail(%d)(%a*)$")
		if not i then
			return CFrame.identity
		end
		i = tonumber(i)
		local s = spec[i]
		if kind == "" then
			return s.base or CFrame.identity
		end
		local mx = m:GetAttribute("ExtendMax")
		local axis = m:GetAttribute("ExtendAxis")
		local rot = (kind == "Mid" and s.mid) or (kind == "Tip" and s.tip) or (kind == "Whip" and s.whip) or CFrame.identity
		return rot * CFrame.new(axis * mx * s.ext) -- rotate about the mouth hinge, after sliding
	end
	local world = { [copy.HumanoidRootPart] = copy.HumanoidRootPart.CFrame }
	local pending = #motors
	while pending > 0 do
		local before = pending
		for _, m in motors do
			if world[m.Part0] and not world[m.Part1] then
				world[m.Part1] = world[m.Part0] * m.C0 * transformFor(m) * m.C1:Inverse()
				pending -= 1
			end
		end
		assert(pending < before)
	end
	local r0 = relMap(template)
	for _, m in motors do
		m.Part1 = nil
	end
	for part, cf in world do
		part.CFrame = cf
	end

	-- measurements
	local out = {}
	local reach, floorY, minOv, worstPoke, worstOvT = 0, math.huge, 1, 0, ""
	local rootWorld = origin * CFrame.new(TAIL.root * K)
	for i = 1, 9 do
		local n = "Tail" .. i
		local segs = { copy[n], copy[n .. "Mid"], copy[n .. "Tip"], copy[n .. "Whip"] }
		for k = 2, 4 do
			local par, ch = segs[k - 1], segs[k]
			local ax = par.CFrame.RightVector
			local pc = par.CFrame.Position
			local function span(p)
				local c = (p.Position - pc):Dot(ax)
				return c - p.Size.X / 2, c + p.Size.X / 2
			end
			local ps, pe = span(par)
			local cs, ce = span(ch)
			-- sign-agnostic: cylinders may point either way; use the child's own length
			local ov = math.max(0, math.min(pe, ce) - math.max(ps, cs)) / ch.Size.X
			if ov < minOv then
				minOv, worstOvT = ov, n .. ":" .. k
			end
			-- poke: sample the child's axis where it lies inside the parent's span; each sample must
			-- be hidden by SOME ancestor sleeve (offset from that sleeve's axis + child radius <=
			-- its radius), so a thin lance may touch a tip's wall while the base still covers it
			local cax = ch.CFrame.RightVector
			for q = 0, 20 do
				local pt = ch.Position + cax * ((q / 20 - 0.5) * ch.Size.X)
				local pa = (pt - pc):Dot(ax)
				if pa >= ps and pa <= pe then
					local best = math.huge
					for j = 1, k - 1 do
						local a2, c2 = segs[j].CFrame.RightVector, segs[j].CFrame.Position
						local al = (pt - c2):Dot(a2)
						if math.abs(al) <= segs[j].Size.X / 2 then
							local off = ((pt - c2) - a2 * al).Magnitude
							best = math.min(best, off + ch.Size.Y / 2 - segs[j].Size.Y / 2)
						end
					end
					worstPoke = math.max(worstPoke, best)
				end
			end
		end
		local whip = segs[4]
		for _, sign in { -1, 1 } do
			local e = whip.Position + whip.CFrame.RightVector * (sign * whip.Size.X / 2)
			-- whichever end is farther from the root is the lance end
			reach = math.max(reach, (e - rootWorld.Position).Magnitude)
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") and (d.Name:match("^Tail" .. i) or d:GetAttribute("Segment") and d:GetAttribute("Segment"):match("^Tail" .. i)) then
				local cf, s = d.CFrame, d.Size / 2
				local low = cf.Y - (math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.RightVector.Y) * s.X + math.abs(cf.LookVector.Y) * s.Z)
				floorY = math.min(floorY, low)
			end
		end
	end
	-- tails against the body
	local bodyParts = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			local seg = d:GetAttribute("Segment") or d.Name
			if not seg:match("^Tail") and not HUB[d.Name] and not d.Name:match("^HipsShoulder") then
				table.insert(bodyParts, d)
			end
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = bodyParts
	local hits = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = true
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^Tail%d") and not d.Name:match("Fur") and not d.Name:match("Flame") then
			for _, h in workspace:GetPartsInPart(d, params) do
				hits[d.Name .. "x" .. h.Name] = true
			end
		end
	end
	local hl = {}
	for k in hits do
		table.insert(hl, k)
	end
	table.sort(hl)
	-- drift
	local r1 = relMap(copy)
	local worst = 0
	for name, cf in r0 do
		local dd = (cf.Position - r1[name].Position).Magnitude + (cf.LookVector - r1[name].LookVector).Magnitude
			+ (cf.UpVector - r1[name].UpVector).Magnitude
		worst = math.max(worst, dd)
	end
	folder:Destroy()
	return ("%-12s reach %.2f  minOv %.2f (%s)  poke %.2f  floor %.2f  drift %.4f  body[%d] %s"):format(
		poseName, reach, minOv, worstOvT, worstPoke, floorY, worst, #hl, table.concat(hl, ",", 1, math.min(#hl, 6)))
end

local lines = {}
for _, name in ORDER do
	table.insert(lines, run(name))
end
return table.concat(lines, "\n")
