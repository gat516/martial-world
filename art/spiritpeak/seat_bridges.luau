--[[
Seat the eight rope bridges (Map.Sect.SpiritPeaks.Peak_N.Bridge) on the floors they join. Run in Studio Edit
mode through the MCP; returns a report. One ChangeHistory recording. Re-runnable: every step measures the
floors and the bridge as they are now, so a second run changes nothing.

  _G.SEAT_BRIDGES = { peaks = { 1 }, dry = true }   -- defaults: all 8 peaks, apply

The bridges predate the column-rock main peak and the rebuilt spirit pillars: they were laid for a terrace at
Y 582 out to r 177 and a peak lawn at local -0.5 out to r 50 (their EndA/EndB attributes). Now the terrace
terrain stops at r ~172-176 with the rock sunk to 580.5 past it, and the peak lawn sits at local ~-1.4 and
bevels down at r ~51. So the 0.6 Bridgehead slab hung a stud over the sunk rock (its sides render near black,
so it read as a void under a thin slab), and the deck's last plank floated ~0.6 over the lawn's bevel with
nothing under it but the cliff.

  terrace end  the Bridgehead keeps its top (pavedFootprints in terrain_main_peak.luau finds it by its top) and
               its 0.6 thickness, in Slate now (MaterialService's Pavement override has black-looking sides);
               a stone Plinth, inset a quarter stud, fills from under it down into the rock over its whole
               footprint, so it reads as a paved landing on a block set into the rim
  peak end     a stone Landing pad under the peak-end posts, from just past the last plank to just inside the
               posts, its top on the posts' feet, its body down into the bevel under the lip (at most PAD_DEPTH)
  deck         Planks, Stringers and Hangers' lower ends get a vertical shear, linear along the bridge, so the
               first plank's inner top edge meets the Bridgehead's top (as built: ~0 there) and the last
               plank's outer top edge meets the Landing's; Hangers keep their tops on the Chains. Chains,
               posts, lanterns and the invisible Guards stay.
]]

local CHS = game:GetService("ChangeHistoryService")
local CFG = _G.SEAT_BRIDGES or {}
local PEAKS = CFG.peaks or { 1, 2, 3, 4, 5, 6, 7, 8 }
local DRY = CFG.dry == true

local Peaks = workspace.Map.Sect.SpiritPeaks
local MainRock = workspace.Map.Sect.MainPeak.Rock

local PAD_COLOR = Color3.fromHex("7E776B") -- the peaks' warm stone (recolor_peaks.luau)
local PAD_IN, PAD_OUT = 1.2, 0.6 -- Landing reach (studs, along the bridge) onto the lawn past the posts, and out past the last plank
local PAD_HALF_W = 5.6 -- posts stand at x +-4.6
local PAD_DEPTH = 6.5
local HEAD_T = 0.6 -- the Bridgehead's own thickness (the paving coping)
local PLINTH_INSET = 0.25
local HEAD_COLORS = { Color3.fromHex("7E766A"), Color3.fromHex("756D61"), Color3.fromHex("857C70") } -- recolor_peaks SLAB
local PLINTH_COLOR = Color3.fromHex("706B66") -- the main peak's middle rock tone

local function rayDown(origin: Vector3, include: { Instance }, depth: number): RaycastResult?
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = include
	p.RespectCanCollide = false
	return workspace:Raycast(origin, Vector3.new(0, -depth, 0), p)
end

-- the pillar's visible rock and lawn (not the invisible LawnCollider boxes)
local function pillarSurfaces(peak: Model): { Instance }
	local list = {}
	for _, d in (peak:FindFirstChild("Pillar") :: Instance):GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(list, d)
		end
	end
	return list
end

-- a part's two ends along its long (Z) axis
local function ends(p: BasePart): (Vector3, Vector3)
	local h = p.Size.Z / 2
	return p.CFrame * Vector3.new(0, 0, -h), p.CFrame * Vector3.new(0, 0, h)
end

local function setEnds(p: BasePart, a: Vector3, b: Vector3)
	local up = p.CFrame.UpVector
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b, up)
	p.CFrame = cf
	p.Size = Vector3.new(p.Size.X, p.Size.Y, (b - a).Magnitude)
end

local function stone(name: string, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	p.Color = color
	return p
end

local function radial(v: Vector3): number
	return Vector2.new(v.X, v.Z).Magnitude
end

local function seat(peak: Model, report: { string })
	local bridge = peak:FindFirstChild("Bridge") :: Model
	local head = bridge:FindFirstChild("Bridgehead") :: BasePart
	local out = Vector3.new(head.Position.X, 0, head.Position.Z).Unit -- from the main peak toward this peak
	local planks, posts = {}, {}
	for _, c in bridge:GetChildren() do
		if c.Name == "Plank" and c:IsA("BasePart") then
			table.insert(planks, c)
		elseif c.Name == "Post" and c:IsA("BasePart") then
			table.insert(posts, c)
		end
	end
	table.sort(planks, function(a, b)
		return radial(a.Position) < radial(b.Position)
	end)
	table.sort(posts, function(a, b)
		return radial(a.Position) > radial(b.Position)
	end)
	local first, last = planks[1], planks[#planks]
	local peakPosts = { posts[1], posts[2] } -- the two outermost: the peak end

	-- terrace end: the Bridgehead down into the rock under its whole footprint
	local headTop = head.Position.Y + head.Size.Y / 2
	local lowest = math.huge
	local hs = head.Size / 2
	for u = -1, 1, 0.25 do
		for v = -1, 1, 0.25 do
			local p = head.CFrame * Vector3.new(u * hs.X * 0.95, 0, v * hs.Z * 0.95)
			local hit = rayDown(Vector3.new(p.X, headTop + 5, p.Z), { MainRock, workspace.Terrain }, 40)
			if hit then
				lowest = math.min(lowest, hit.Position.Y)
			end
		end
	end
	local headBottom = lowest - 0.6
	local headH = headTop - headBottom

	-- peak end: the Landing under the posts, its top on their feet
	local postFoot = math.huge
	for _, p in peakPosts do
		postFoot = math.min(postFoot, p.Position.Y - p.Size.Y / 2)
	end
	local padTop = postFoot + 0.05
	local postR = radial((peakPosts[1].Position + peakPosts[2].Position) / 2)
	-- radii from the main peak: the last plank (over the lawn's lip) is nearer the main peak than the posts
	local r0, r1 = radial(last.Position) - last.Size.Z / 2 - PAD_OUT, postR + PAD_IN
	local side = Vector3.new(-out.Z, 0, out.X)
	local axisPoint = out * ((r0 + r1) / 2)
	local surfaces = pillarSurfaces(peak)
	local rockLow, lawnHigh = math.huge, -math.huge
	for t = 0, 1, 0.125 do
		for w = -1, 1, 0.5 do
			local p = out * (r0 + (r1 - r0) * t) + side * (w * PAD_HALF_W * 0.95)
			local hit = rayDown(Vector3.new(p.X, padTop + 10, p.Z), surfaces, 40)
			if hit then
				rockLow = math.min(rockLow, hit.Position.Y)
				if t >= 0.75 then
					lawnHigh = math.max(lawnHigh, hit.Position.Y)
				end
			end
		end
	end
	padTop = math.max(padTop, lawnHigh + 0.1) -- never under the lawn it starts on
	-- down into the bevel under the lip, but no deeper than PAD_DEPTH: where the cliff face falls away under the
	-- last plank the rays find a ledge far below, and the pad stays a stone block jutting from the lip
	local padBottom = math.max(math.min(rockLow, padTop - 1) - 0.8, padTop - PAD_DEPTH)

	-- deck shear: the planks are pitched steps (each one's ends sit near its neighbours'), so the first plank's
	-- inner top edge meets the Bridgehead's top and the last plank's outer top edge meets the Landing's
	local function edgeTop(p: BasePart, outer: boolean): number
		local e1 = p.CFrame * Vector3.new(0, p.Size.Y / 2, -p.Size.Z / 2)
		local e2 = p.CFrame * Vector3.new(0, p.Size.Y / 2, p.Size.Z / 2)
		if (radial(e1) > radial(e2)) ~= outer then
			e1 = e2
		end
		return e1.Y
	end
	local rA, rB = radial(first.Position), radial(last.Position)
	local dA = headTop - 0.1 - edgeTop(first, false)
	local dB = padTop - edgeTop(last, true)
	local function delta(pos: Vector3): number
		local t = (radial(pos) - rA) / (rB - rA) -- unclamped: each plank's centre moves by exactly its own delta
		return dA + (dB - dA) * t
	end

	table.insert(
		report,
		string.format(
			"%s: head bottom %.2f -> %.2f (h %.2f); landing top %.2f bottom %.2f r %.1f..%.1f (lawn %.2f); deck shift %+.2f .. %+.2f",
			peak.Name,
			head.Position.Y - head.Size.Y / 2,
			headBottom,
			headH,
			padTop,
			padBottom,
			r0,
			r1,
			lawnHigh,
			dA,
			dB
		)
	)
	if DRY then
		return
	end

	-- the slab stays a HEAD_T coping in Slate (MaterialService's Pavement override, "Stylized Pavement II", has a
	-- metalness map and renders the slab's sides near black, which read as a void under it); a stone Plinth a
	-- little inset under it reaches down into the rock
	head.Material = Enum.Material.Slate
	head.MaterialVariant = ""
	head.Color = HEAD_COLORS[(tonumber(peak.Name:match("%d+")) or 0) % #HEAD_COLORS + 1]
	head.Size = Vector3.new(head.Size.X, HEAD_T, head.Size.Z)
	head.CFrame = head.CFrame - Vector3.new(0, head.Position.Y - (headTop - HEAD_T / 2), 0)
	local oldPlinth = bridge:FindFirstChild("Plinth")
	if oldPlinth then
		oldPlinth:Destroy()
	end
	local plinthTop = headTop - HEAD_T
	local plinth = stone("Plinth", PLINTH_COLOR)
	plinth.Size = Vector3.new(head.Size.X - 2 * PLINTH_INSET, plinthTop - headBottom, head.Size.Z - 2 * PLINTH_INSET)
	plinth.CFrame = head.CFrame - Vector3.new(0, head.Position.Y - (plinthTop + headBottom) / 2, 0)
	plinth.Parent = bridge

	local old = bridge:FindFirstChild("Landing")
	if old then
		old:Destroy()
	end
	local pad = stone("Landing", PAD_COLOR)
	pad.Size = Vector3.new(PAD_HALF_W * 2, padTop - padBottom, r1 - r0)
	local c = axisPoint + Vector3.new(0, (padTop + padBottom) / 2, 0)
	pad.CFrame = CFrame.lookAt(c, c + out)
	pad.Parent = bridge

	-- the shear changes each plank's pitch a little, which moves its edges: a few passes settle it
	for pass = 1, 4 do
		if pass > 1 then
			dA = headTop - 0.1 - edgeTop(first, false)
			dB = padTop - edgeTop(last, true)
		end
		for _, p in bridge:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "Plank" or p.Name == "Stringer") then
				local a, b = ends(p)
				setEnds(p, a + Vector3.new(0, delta(a), 0), b + Vector3.new(0, delta(b), 0))
			elseif p:IsA("BasePart") and p.Name == "Hanger" then
				local a, b = ends(p)
				if a.Y > b.Y then
					a, b = b, a
				end
				-- a is the lower end (on the stringer): it moves with the deck, the top stays on the chain
				setEnds(p, a + Vector3.new(0, delta(a), 0), b)
			end
		end
	end
	local ea, eb = bridge:GetAttribute("EndA"), bridge:GetAttribute("EndB")
	if typeof(ea) == "Vector3" then
		bridge:SetAttribute("EndA", Vector3.new(ea.X, headTop, ea.Z))
	end
	if typeof(eb) == "Vector3" then
		bridge:SetAttribute("EndB", Vector3.new(eb.X, padTop, eb.Z))
	end
end

local report = {}
local recording = not DRY and CHS:TryBeginRecording("SeatBridges")
local ok, err = pcall(function()
	for _, i in PEAKS do
		seat(Peaks:FindFirstChild("Peak_" .. i) :: Model, report)
	end
end)
if recording then
	CHS:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
end
if not ok then
	error(err)
end
return (DRY and "dry run\n" or "") .. table.concat(report, "\n")
