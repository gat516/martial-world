--!nocheck
-- Compact summary of qa_quadruped_poses.luau for the Nine-Tailed Fox boss module. Run in a
-- sandbox through execute_luau after pushing src/client/EnemyPoses/NineTailFox.luau (and
-- Quadruped.luau), ONE move or loop per call (a whole run freezes Studio):
--   _G.FOX_ONLY = "TailLance"   -- a move name, or idle / walk / run / circle
--   return loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/quadrupeds/qa_nine_tail_fox_poses.luau"))()
-- Prints the sample count and, per issue kind, the worst value and the first sample showing it.
-- SUNK reports the worst body depth below the floor and its culprit part (tails included).
local H = game:GetService("HttpService")
_G.QP_CONFIG = "NineTailFox"
_G.QP_ONLY = _G.FOX_ONLY
_G.QP_VARIANT = _G.FOX_VARIANT -- nil = the defaults, "A" / "B" / "C" sets every move that has it
local report = loadstring(H:GetAsync("http://127.0.0.1:8767/quadrupeds/qa_quadruped_poses.luau?" .. os.clock()))()
local n, worst, first, flagged, sunk = 0, {}, {}, 0, { 0, "", "" }
local minFoot = 0
for line in string.gmatch(report, "[^\n]+") do
	n += 1
	local label = line:sub(1, 24):gsub("%s+$", "")
	local body = tonumber(line:match("body (%-?[%d%.]+)")) or 0
	if body < sunk[1] then
		sunk = { body, label, line:match("SUNK [%-%d%.]+ %((%w+)%)") or "" }
	end
	local tail = line:match("!! (.*)")
	if tail then
		flagged += 1
		for piece in string.gmatch(tail, "[^;]+") do
			local kind, name, v = piece:match("^%s*(%u+) ([%w/%-]+) ?([%-%d%.]*)")
			if kind and kind ~= "SUNK" then
				local key = kind .. " " .. name
				local val = tonumber(v) or 0
				if not worst[key] or math.abs(val) > math.abs(worst[key]) then
					worst[key] = val
					first[key] = label
				end
			end
		end
	end
end
local rows = {}
for k, v in worst do
	table.insert(rows, ("%s %.2f @ %s"):format(k, v, first[k]))
end
table.sort(rows)
return ("%s %s: %d samples, %d flagged, worst sink %.2f (%s %s)\n%s"):format(_G.FOX_ONLY, _G.FOX_VARIANT or "", n, flagged, sunk[1], sunk[3], sunk[2], table.concat(rows, "\n", 1, math.min(#rows, 12)))
