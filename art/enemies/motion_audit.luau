--!nocheck
-- Motion audit: runs art/enemies/motion_probe.luau over EVERY attack of a family's def (the
-- opener, the pool or pattern, phase calls, the pack call; a followUp plays as a chain, an
-- arrive as `next`, a skid attack once more with its skid), plus Stagger, Death and the
-- walk / run / circle loops at the def's speeds. The family comes from motion_specs.luau.
-- Used by the 2026-10-23 roster audit (docs/enemies/audit-2026-10-23.md). Edit mode, sandbox.
--   _G.AUDIT = { family = "StoneTortoise", base = "http://127.0.0.1:8767/",  -- serves art/enemies/
--                moves = nil,          -- optional: your own move list instead of every attack
--                post = nil,           -- optional: a URL the full text is POSTed to
--                summary = false }     -- true: return the compact per-move table (the audit doc's columns)
--   _G.SERVE_BASE (e.g. "http://127.0.0.1:8801/", the repo root served by tools/serve.sh <port>) sets
--   the default `base` to <SERVE_BASE>art/enemies/; without it, :8767.
--   return loadstring(game:GetService("HttpService"):GetAsync(base .. "motion_audit.luau?" .. os.clock()))()
-- Returns the probe's text (one metrics block per move); quiet, lows on, steps off. With
-- summary = true it returns one table row per move instead: move, chain body / tail lags,
-- stops dead, worst step, antic root/hero, land dip, lowest (read from _G.MOTION_RESULTS).
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local H = game:GetService("HttpService")
local A = _G.AUDIT or error("set _G.AUDIT first")
local B = A.base or BASE
local S = loadstring(H:GetAsync(B .. "motion_specs.luau?" .. os.clock()))()
local name = A.family
local spec = S.with(name, {})
local Shared = game:GetService("ReplicatedStorage").Shared
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ec = Shared.Enemies:Clone()
ec.Name = "_AuditEnemies"
ec.Parent = Shared
local Enemies = require(ec)
ec:Destroy()
local pc = Client.EnemyPoses:Clone()
pc.Parent = game:GetService("ReplicatedStorage")
local M = require(pc[spec.module])
pc:Destroy()
local def = Enemies.Defs[spec.def]
local map = spec.map or {}
local function moveOf(n)
	return map[n] or (string.upper(string.sub(n, 1, 1)) .. string.sub(n, 2))
end
local seen, moves, missing = {}, {}, {}
local function add(a)
	if not a or seen[a.name or a.kind] then
		return
	end
	seen[a.name or a.kind] = true
	local n = a.name or a.kind
	if not M.moves[moveOf(n)] then
		table.insert(missing, n .. "->" .. moveOf(n))
		return
	end
	if a.chainOnly then
		return
	end
	local entry
	if a.followUp then
		entry = { chain = { n, a.followUp }, label = n .. "+" .. a.followUp }
	elseif type(a.arrive) == "table" then
		entry = { attack = n, next = a.arrive.name }
	else
		entry = { attack = n }
	end
	if a.kind == "bound" then
		entry.input = { mode = "over" }
	end
	table.insert(moves, entry)
	local skid = map[n .. "Skid"] or (M.moves[moveOf(n) .. "Skid"] and moveOf(n) .. "Skid")
	if a.skid and skid and M.moves[skid] then
		table.insert(moves, { attack = n, skid = skid, label = n .. " skid" })
	end
end
add(def.attack)
for _, pool in { def.attacks or {}, def.pattern or {}, def.phaseCalls or {} } do
	for _, a in pool do
		add(a)
	end
end
add(def.phaseCall)
if def.pack and def.pack.howl then
	add(def.pack.howl)
end
table.insert(moves, "Stagger")
table.insert(moves, "Death")
for _, l in { { "walk", def.walkSpeed }, { "run", def.runSpeed }, { "circle", (def.pack and def.pack.circle and def.pack.circle.speed) or def.walkSpeed } } do
	if M.loops[l[1]] then
		table.insert(moves, { loop = l[1], speed = l[2], seconds = 2 })
	end
end
spec.moves = A.moves or moves
spec.quiet = true
spec.lows = true
spec.steps = false
_G.MOTION = spec
local ok, res = pcall(function()
	return loadstring(H:GetAsync(B .. "motion_probe.luau?" .. os.clock()))()
end)
local text = (if #missing > 0 then "no move: " .. table.concat(missing, ", ") .. "\n" else "") .. tostring(res)
if A.summary and ok then
	local function cell(c)
		if not c then
			return "-"
		end
		local parts, any, nonzero = {}, false, false
		for j = 1, #c.peaks - 1 do
			local l = c.lags[j]
			table.insert(parts, if l then string.format("%+df", l) else "~")
			if l then
				any = true
				nonzero = nonzero or l ~= 0
			end
		end
		return if any and not nonzero then "BLOCK" else table.concat(parts, " ")
	end
	local function anticOf(r, who)
		local a = r.antic and r.antic[who]
		return if not a then "~" elseif a.tail < 0.05 then "none" else string.format("%.2f", a.tail)
	end
	local rows = {
		"| move | chain body | chain tail | stops dead | worst step deg | antic root/hero | land dip | lowest |",
		"|---|---|---|---|---|---|---|---|",
	}
	for _, r in _G.MOTION_RESULTS or {} do
		local stops, seenStop = {}, {}
		for _, st in r.stops or {} do
			if not seenStop[st.hero] then
				seenStop[st.hero] = true
				table.insert(stops, st.hero)
			end
		end
		local land = "-"
		if r.landing then
			local d = {}
			for _, l in r.landing do
				table.insert(d, if l.dip < 0.05 then "stiff" else string.format("%.2f", l.dip))
			end
			land = table.concat(d, "/")
		end
		local anticCell = "-"
		if r.antic then
			local hero = nil
			for who in r.antic do
				if who ~= "root" then
					hero = who
				end
			end
			anticCell = anticOf(r, "root") .. "/" .. (if hero then anticOf(r, hero) else "~")
		end
		table.insert(rows, string.format("| %s | %s | %s | %s | %.1f %s | %s | %s | %+.2f |", r.label,
			cell(r.chains.body), cell(r.chains.tail), if #stops > 0 then table.concat(stops, ", ") else "-",
			r.worst, tostring(r.worstJoint), anticCell, land, r.low))
	end
	text = (if #missing > 0 then "no move: " .. table.concat(missing, ", ") .. "\n" else "") .. table.concat(rows, "\n")
end
if A.post then
	pcall(function()
		H:PostAsync(A.post, text)
	end)
end
return text
