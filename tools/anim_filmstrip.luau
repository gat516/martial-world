--!nocheck
-- Filmstrip of one enemy move (sandbox, Edit mode): N FK clones of the template posed at evenly
-- spaced moments from the windup's start to the recover's end (a loop: across the loop), in a row
-- on a neutral plate, so ONE screen capture per view shows the whole clip. Two rows: the side
-- view (the beast faces right) and the 3/4 front view; each prints its camera for screen_capture.
-- The poses come from art/enemies/motion_probe.luau (it plays the move the way EnemyAnimator does:
-- the state timeline, blends, `seamless`, scale, the pose module's own planting) with `keep = true`,
-- and its FK places every part, so the strip is exactly what the probe measured.
--   * label under each pose: ms since the clip starts, the state; "W" marks the windup's end (the
--     strongest pose, the telegraph's last frame), which is always one of the samples;
--   * RED ball: that pose's lowest point is below the floor (by more than `sinkLimit` studs);
--   * ORANGE ball: a hero point hitched or stopped dead (the probe's hitch and stop metrics)
--     between the previous sample and this one, placed on that hero point.
-- Everything is anchored, motors cut, in Workspace._Filmstrip (tagged EditorOnly).
--
-- Use (tools/serve.sh serves the repo root on 8768; 8768 may be another checkout's when several
-- sessions run, so serve your worktree on a port of its own and pass it as `base`):
--   _G.MOTION = { ...the motion_probe spec, see its header... }
--   _G.FILMSTRIP = { move = "clubSwing",   -- or a probe move spec / { loop = "walk", speed = 6 };
--                                          -- default: _G.MOTION.moves[1]
--     n = 8, sinkLimit = 0.1, gap = 0.3,   -- gap: between poses, in rest-body heights
--     origin = Vector3.new(0, 400, -4000),   -- the plate's top centre: far from the arena, which stays behind the cameras
--     base = "http://127.0.0.1:8768/" }    -- where the repo is served (motion_probe is loaded from it)
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8768/tools/anim_filmstrip.luau?" .. os.clock()))()
-- It returns the two cameras: screen_capture with camera_position / look_at_position, one per view.
-- It sets the Studio camera's FieldOfView to `fov` (30) for the captures.
-- Clean up: _G.FILMSTRIP = { cleanup = true } and load it again (or _G.FILMSTRIP_CLEANUP()); it
-- also puts the FieldOfView back.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local opts = _G.FILMSTRIP or {}
local FOLDER = "_Filmstrip"

local function cleanup()
	local f = workspace:FindFirstChild(FOLDER)
	if f and f:GetAttribute("CameraFov") then
		workspace.CurrentCamera.FieldOfView = f:GetAttribute("CameraFov")
	end
	while f do
		f:Destroy()
		f = workspace:FindFirstChild(FOLDER)
	end
end
_G.FILMSTRIP_CLEANUP = cleanup
if opts.cleanup then
	cleanup()
	return "filmstrip removed"
end
cleanup()

local base = opts.base or "http://127.0.0.1:8768/"
local N = opts.n or 8
local sinkLimit = opts.sinkLimit or 0.1
local gapFrac = opts.gap or 0.3
local origin = opts.origin or Vector3.new(0, 400, -4000)

-- run the probe on this one move, keeping every frame's pose
local spec = _G.MOTION or error("set _G.MOTION first (the motion_probe spec)")
local probeCfg = table.clone(spec)
probeCfg.moves = { opts.move or spec.moves[1] }
probeCfg.keep, probeCfg.quiet = true, true
_G.MOTION = probeCfg
local ok, report = pcall(function()
	return loadstring(HttpService:GetAsync(base .. "art/enemies/motion_probe.luau?" .. os.clock()))()
end)
_G.MOTION = spec
assert(ok, report)
local res = _G.MOTION_RESULTS[1]
local F = _G.MOTION_FK
local frames, template = res.frames, F.template
local hrp = template.HumanoidRootPart

-- the samples: evenly spaced over the clip, the nearest one snapped to the windup's end
local function frameAt(t)
	local best, bd = 1, math.huge
	for i, f in frames do
		local d = math.abs(f.t - t)
		if d < bd then
			best, bd = i, d
		end
	end
	return best
end
local t0, t1 = res.clipFrom, res.clipTo - (frames[2].t - frames[1].t)
local picks = {}
for k = 0, N - 1 do
	picks[k + 1] = frameAt(t0 + (t1 - t0) * k / math.max(1, N - 1))
end
local wIdx
if res.windupTo then
	-- the last windup frame: the strongest pose, held on the telegraph
	wIdx = frameAt(res.windupTo)
	for i, f in frames do
		if f.st == "windup" and f.t < res.windupTo then
			wIdx = i
		end
	end
	local best, bd = 1, math.huge
	for k, i in picks do
		if math.abs(i - wIdx) < bd then
			best, bd = k, math.abs(i - wIdx)
		end
	end
	picks[best] = wIdx
end

-- rest size, for spacing, markers and labels
local restWorld = F.fk({})
local minY, maxY = math.huge, -math.huge
for p, cf in restWorld do
	if p:IsA("BasePart") and p.Transparency < 1 then
		minY = math.min(minY, cf.Y - p.Size.Magnitude / 2)
		maxY = math.max(maxY, cf.Y + p.Size.Magnitude / 2)
	end
end
local H = math.max(2, maxY - F.restLow)
local ballSize = math.max(0.5, H * 0.1)

local srcList = template:GetDescendants()
local folder = Instance.new("Folder")
folder.Name = FOLDER
folder:SetAttribute("CameraFov", workspace.CurrentCamera.FieldOfView)
CollectionService:AddTag(folder, "EditorOnly")
folder.Parent = workspace

local function ball(parent, pos, color, name)
	local b = Instance.new("Part")
	b.Name = name
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * ballSize
	b.Material = Enum.Material.Neon
	b.Color = color
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
	b.Position = pos
	b.Parent = parent
	return b
end
local function label(parent, pos, text, color)
	local p = Instance.new("Part")
	p.Name = "Label"
	p.Size = Vector3.one * 0.2
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Position = pos
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.new(H * 0.75, 0, H * 0.22, 0) -- scale units are studs
	g.LightInfluence = 0
	g.Adornee = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
	t.BackgroundTransparency = 0.15
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.Parent = g
	g.Parent = p
	p.Parent = parent
end

-- one posed clone: anchored, joints cut, every part placed from the probe's FK
local function poseClone(frame, place, parent, name)
	local clone = template:Clone()
	local dst = clone:GetDescendants()
	assert(#dst == #srcList, "clone order differs from the template")
	for _, d in dst do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") or d:IsA("LuaSourceContainer")
			or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	local world = F.fk(frame.pose)
	local hrpRest = hrp.CFrame
	for k, s in srcList do
		local d = dst[k]
		if s:IsA("BasePart") then
			assert(d.Name == s.Name, "clone order differs at " .. s.Name)
			local cf = world[s] or (world[hrp] * hrpRest:ToObjectSpace(s.CFrame))
			d.Anchored = true
			d.CanCollide, d.CanTouch = false, false
			d.CFrame = place * cf
		end
	end
	clone.Name = name
	clone.Parent = parent
	return clone
end

local function xExtent(model)
	local lo, hi = math.huge, -math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local r = p.Size.Magnitude / 2
			lo, hi = math.min(lo, p.Position.X - r), math.max(hi, p.Position.X + r)
		end
	end
	return lo, hi
end

-- a narrow lens from far away (screen_capture keeps the camera's FieldOfView): close up with the
-- default 70, the outer poses of a long row are seen from 30-50 degrees off and read as another
-- view. cleanup() puts the old FieldOfView back.
local cam = workspace.CurrentCamera
cam.FieldOfView = opts.fov or 30
local vp = cam.ViewportSize
local aspect = math.min(1.8, if vp.Y > 0 then vp.X / vp.Y else 16 / 9)
local vfov = math.rad(cam.FieldOfView)
local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect)

local VIEWS = {
	{ name = "side", yaw = -math.pi / 2 }, -- faces +X: screen right, the way time runs
	{ name = "front34", yaw = -3 * math.pi / 4 }, -- faces the camera and screen right
}
local out = { string.format("filmstrip %s: %d poses %.0f-%.0f ms%s", res.label, N, 0, (t1 - t0) * 1000,
	if wIdx then string.format(", W at %.0f ms", (frames[wIdx].t - t0) * 1000) else "") }
local rowX = origin.X
local flagged = {}
for _, view in VIEWS do
	local row = Instance.new("Model")
	row.Name = view.name
	row.Parent = folder
	local cursor = rowX
	local prevI = picks[1] - 1
	local zMax = 0
	for k, i in picks do
		local f = frames[i]
		-- template space -> strip: turn about the root's vertical, the rest floor on the plate
		local place = CFrame.new(cursor, origin.Y, origin.Z) * CFrame.Angles(0, view.yaw, 0)
			* CFrame.new(-hrp.Position.X, -F.restLow + f.lift, -hrp.Position.Z)
		local m = poseClone(f, place, row, string.format("%02d_%dms", k, math.floor((f.t - t0) * 1000 + 0.5)))
		local lo, hi = xExtent(m)
		local shift = cursor - lo
		m:PivotTo(m:GetPivot() + Vector3.new(shift, 0, 0))
		place = CFrame.new(shift, 0, 0) * place
		local cx = (lo + hi) / 2 + shift
		cursor = hi + shift + gapFrac * H
		-- markers
		local notes = {}
		if f.lo < -sinkLimit then
			ball(row, (place * CFrame.new(f.lowAt)).Position, Color3.fromRGB(255, 40, 40), "Sink")
			table.insert(notes, string.format("sunk %.2f %s", f.lo, f.low))
		end
		local worst
		for j = prevI + 1, i - 1 do
			if j >= 1 and frames[j].lo < -sinkLimit and (not worst or frames[j].lo < frames[worst].lo) then
				worst = j
			end
		end
		if worst then
			table.insert(notes, string.format("sank %.2f %s at %.0f ms (between samples)", frames[worst].lo, frames[worst].low, (frames[worst].t - t0) * 1000))
		end
		for _, mk in res.marks do
			if mk.i > prevI and mk.i <= i then
				ball(row, (place * CFrame.new(frames[i].pts[mk.hero])).Position, Color3.fromRGB(255, 110, 0), "Hitch")
				table.insert(notes, string.format("%s %s at %.0f ms", mk.hero, mk.kind, (frames[mk.i].t - t0) * 1000))
			end
		end
		prevI = i
		local text = string.format("%s%.0f ms\n%s", if i == wIdx then "W " else "", (f.t - t0) * 1000, f.st)
		label(row, Vector3.new(cx, origin.Y - H * 0.12, origin.Z + H * 1.45), text,
			if #notes > 0 then Color3.fromRGB(255, 190, 120) else nil)
		if view.name == "side" and #notes > 0 then
			table.insert(flagged, string.format("  %d (%.0f ms %s): %s", k, (f.t - t0) * 1000, f.st, table.concat(notes, "; ")))
		end
		zMax = math.max(zMax, H)
	end
	local rowLen = cursor - gapFrac * H - rowX
	local plate = Instance.new("Part")
	plate.Name = "Plate"
	plate.Anchored, plate.CanCollide = true, false
	plate.Material = Enum.Material.SmoothPlastic
	plate.Color = Color3.fromRGB(128, 128, 132)
	plate.Size = Vector3.new(rowLen + H, 0.5, H * 2.6)
	plate.CFrame = CFrame.new(rowX + rowLen / 2, origin.Y - 0.25, origin.Z)
	plate.Parent = row
	-- the camera: square on to the row, a little above, the whole row in frame
	local centre = Vector3.new(rowX + rowLen / 2, origin.Y + H * 0.5 + 1.5, origin.Z)
	local dist = math.max((rowLen / 2 + H * 0.4) / math.tan(hfov / 2), (H * 0.9) / math.tan(vfov / 2)) + H
	local camPos = centre + Vector3.new(0, dist * 0.18, dist)
	-- aim below the row so it sits in the upper half, clear of the HUD along the bottom
	centre -= Vector3.new(0, dist * math.tan(vfov / 2) * 0.25, 0)
	table.insert(out, string.format("%s: camera_position [%.1f, %.1f, %.1f] look_at_position [%.1f, %.1f, %.1f]",
		view.name, camPos.X, camPos.Y, camPos.Z, centre.X, centre.Y, centre.Z))
	rowX = cursor + rowLen * 0.6 + 150
end
table.insert(out, if #flagged > 0 then "flagged poses:\n" .. table.concat(flagged, "\n") else "flagged poses: none")
table.insert(out, "metrics:\n" .. report)
return table.concat(out, "\n")
