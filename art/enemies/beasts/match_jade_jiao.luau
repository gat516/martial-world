--!nocheck
-- Numeric match between the built Jade Jiao (ServerStorage._RosterBeasts.JadeJiao) and the
-- user's reference snake (jade_python_ref.rbxm.b64, moved into model space the way
-- build_jade_jiao.luau moves it). Run in Edit mode through execute_luau after the build.
--   * silhouette: points sampled on a grid inside every visible reference part must lie in
--     a visible Jiao part, and points inside every visible Jiao part in a reference part
--     (exact point-in-part for blocks, wedges, cylinders and balls);
--   * colour: each sampled point must find a part of the same colour;
--   * hidden extras: every point of the hood, fang and tongue parts lies inside the
--     reference's visible volume (so they can't show at rest).
-- Returns the miss counts and the worst offenders.

local HttpService = game:GetService("HttpService")
local SerializationService = game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")
local BASE = "http://127.0.0.1:8767/beasts/"
local STEP = 0.25 -- grid spacing inside each part, studs

local raw = HttpService:GetAsync(BASE .. "jade_python_ref.rbxm.b64?" .. os.clock())
local b = buffer.fromstring(raw) -- decoded below
do
	local map = {}
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do
		map[string.byte(alphabet, i)] = i - 1
	end
	local s = raw:gsub("[^%w%+/=]", "")
	local pad = select(2, s:gsub("=", ""))
	local n = #s // 4 * 3 - pad
	b = buffer.create(n)
	local o = 0
	for i = 1, #s, 4 do
		local a1, c, d, e = string.byte(s, i, i + 3)
		local val = map[a1] * 262144 + map[c] * 4096 + (map[d] or 0) * 64 + (map[e] or 0)
		for k = 2, 0, -1 do
			if o < n then
				buffer.writeu8(b, o, bit32.band(bit32.rshift(val, k * 8), 255))
				o += 1
			end
		end
	end
end
local ref = SerializationService:DeserializeInstancesAsync(b)[1]
local S = ref:GetScale()
local toModel = CFrame.new(0, 2 * S, 1.6 * S) * CFrame.new(ref.HumanoidRootPart.Position):Inverse()
local jiao = ServerStorage._RosterBeasts.JadeJiao
-- the template may be rigged (welds hold) or not; read CFrames as they are, relative to
-- its HRP if it has one at the build's root position
local function list(model, xf, filter)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and filter(d) then
			table.insert(out, { cf = xf * d.CFrame, size = d.Size, part = d, color = d.Color })
		end
	end
	return out
end
local EXTRA = { HoodL = 1, HoodR = 1, FangL = 1, FangR = 1, Tongue = 1, TongueTipL = 1, TongueTipR = 1 }
local function isExtra(d)
	local seg = d:GetAttribute("Segment") or d.Name
	return EXTRA[seg] ~= nil
end
local refParts = list(ref, toModel, function(d)
	return d.Transparency < 1
end)
local jiaoParts = list(jiao, CFrame.identity, function(d)
	return d.Transparency < 1 and not isExtra(d)
end)
local extras = list(jiao, CFrame.identity, isExtra)

local function inside(e, p, slack)
	local l = e.cf:PointToObjectSpace(p)
	local h = e.size / 2 + Vector3.one * slack
	local part = e.part
	if math.abs(l.X) > h.X or math.abs(l.Y) > h.Y or math.abs(l.Z) > h.Z then
		return false
	end
	if part:IsA("WedgePart") then
		-- tall at +Z, slope down to the bottom front edge
		return (l.Y + h.Y) / (2 * h.Y) <= (l.Z + h.Z) / (2 * h.Z) + slack / h.Z
	elseif part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		return (l.Y * l.Y + l.Z * l.Z) <= (math.min(h.Y, h.Z)) ^ 2
	elseif part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		return l.Magnitude <= math.min(h.X, h.Y, h.Z)
	end
	return true
end
local function samples(e)
	local pts = {}
	local n = Vector3.new(math.max(1, math.floor(e.size.X / STEP)), math.max(1, math.floor(e.size.Y / STEP)),
		math.max(1, math.floor(e.size.Z / STEP)))
	for i = 0, n.X - 1 do
		for j = 0, n.Y - 1 do
			for k = 0, n.Z - 1 do
				local l = Vector3.new((i + 0.5) / n.X - 0.5, (j + 0.5) / n.Y - 0.5, (k + 0.5) / n.Z - 0.5) * e.size
				local p = e.cf * l
				if inside(e, p, -1e-3) then
					table.insert(pts, p)
				end
			end
		end
	end
	return pts
end
local function cover(from, into, needColour, slack)
	local miss, total, worst = 0, 0, {}
	for _, e in from do
		local m = 0
		local pts = samples(e)
		for _, p in pts do
			total += 1
			local ok = false
			for _, f in into do
				if (not needColour or f.color == e.color) and inside(f, p, slack) then
					ok = true
					break
				end
			end
			if not ok then
				m += 1
			end
		end
		miss += m
		if m > 0 then
			table.insert(worst, { e.part.Name, m, #pts })
		end
		task.wait()
	end
	table.sort(worst, function(x, y)
		return x[2] > y[2]
	end)
	local w = {}
	for i = 1, math.min(8, #worst) do
		table.insert(w, ("%s %d/%d"):format(worst[i][1], worst[i][2], worst[i][3]))
	end
	return ("%d/%d missed%s"):format(miss, total, if #w > 0 then " (" .. table.concat(w, ", ") .. ")" else "")
end
local out = {}
table.insert(out, "ref in jiao (shape+colour): " .. cover(refParts, jiaoParts, true, 0.01))
table.insert(out, "jiao in ref (shape+colour): " .. cover(jiaoParts, refParts, true, 0.01))
table.insert(out, "hidden extras inside ref: " .. cover(extras, refParts, false, 0))
ref:Destroy()
return table.concat(out, "\n")
