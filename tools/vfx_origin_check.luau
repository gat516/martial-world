--!nocheck
-- Where every layer of an effect template will appear when played, and the
-- placement mistakes that make effects "spawn above the player" or "not come
-- from the hand". Edit mode, read-only (creates nothing). Run this file once
-- through execute_luau (inline, or loadstring over HTTP); it installs
-- _G.vfxOriginCheck:
--
--   _G.vfxOriginCheck(target?, opts?) -> report string
--     target  nil (every template in ReplicatedStorage.Effects), "Group",
--             "Group.Template" or an Instance
--     opts.rows   "all" (default for one template) | "flagged" (default for
--                 more) | "none"
--     opts.body   the enemy body to check hooks on (default
--                 ServerStorage.Enemies.<Group>B, else <Group>)
--
-- Per template it prints the anchor, what the code places the template on (an
-- enemy template: the hook in the `play("Name", ...)` call in
-- Client.EnemyFX.<Group>; a technique template's children: hand, weapon, each
-- target or the template pivot, read from Client.TechniqueFX.<Id> and
-- CombatEffects), then one row per ParticleEmitter / Beam / Trail / light:
-- what it hangs on and its offset from its anchor, then a verdict.
--
-- Flags (FAIL unless marked):
--   HOOK       the code anchors it on a hook the body doesn't have (it falls
--              back to a part or the root: "doesn't come from the hand")
--   ORIGIN     an emitter or light whose parent is neither a part nor an
--              attachment (never renders). WARN when some client code names
--              the holder (a recipe folder the code re-hosts, e.g. MethodAura)
--   LOOSE      a part nested in a part the code moves by CFrame, not welded and
--              not a MeshWave mesh: it stays where the template was authored
--              (world origin). FAIL on Part templates (K.play moves the root
--              only); WARN when client code names the part, or inside a
--              technique Model (check the code carries it)
--   BEAM       a Beam / Trail with a missing attachment that no code assigns
--              (the module, or code naming the template / holder), or an
--              attachment outside the template
--   OFFSET     WARN: further from its anchor than the template's stated size
--              (Authored* size attributes; a Part template without one: half
--              its largest side + 1.5 studs); FAIL past twice that, except on
--              a technique template's pivot
--   ROOT       WARN: an emitter or light straight on a root part bigger than
--              4 studs, no attachment: it emits over that whole part (rows
--              show "area N" from 1 stud)
--   NAME       WARN: an attachment named like a body hook (`*_FX`, or a hook
--              of any body) that this body doesn't expose
-- Pairs with tools/vfx_hooks_check.py (offline: names in code vs rig docs).

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SIZE_ATTRS = { "AuthoredRadius", "AuthoredLength", "AuthoredWidth", "AuthoredRange", "AuthoredSize", "AuthoredHeight" }
local MODULE_FOR = { EnemyImpact = "Impact" }
local SHORT = { ParticleEmitter = "emit", Beam = "beam", Trail = "trail", PointLight = "light", SpotLight = "light", SurfaceLight = "light" }

local function client()
	return game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client")
end

local function source(name, folder)
	local c = client()
	local f = c and (folder and c:FindFirstChild(folder) or c)
	local m = f and f:FindFirstChild(name)
	return m and m:IsA("ModuleScript") and m.Source or nil
end

-- every client script's source, once (to ask "does any code name this?")
local allSource
local function mentions(name)
	if not allSource then
		local parts = {}
		local c = client()
		for _, d in c and c:GetDescendants() or {} do
			if d:IsA("LuaSourceContainer") then
				table.insert(parts, d.Source)
			end
		end
		allSource = table.concat(parts, "\n")
	end
	return allSource:find('"' .. name .. '"', 1, true) ~= nil
end

local function lines(src)
	local out = {}
	for l in (src .. "\n"):gmatch("(.-)\n") do
		table.insert(out, l)
	end
	return out
end

-- every body hook (attachment on a part) across ServerStorage.Enemies
local allHooks
local function bodyHooks(body)
	local set = {}
	if body then
		for _, d in body:GetDescendants() do
			if d:IsA("Attachment") and d.Parent:IsA("BasePart") and not d.Name:match("RigAttachment$") then
				set[d.Name] = true
			end
		end
	end
	return set
end
local function everyHook()
	if not allHooks then
		allHooks = {}
		local enemies = SS:FindFirstChild("Enemies")
		for _, b in enemies and enemies:GetChildren() or {} do
			for n in bodyHooks(b) do
				allHooks[n] = true
			end
		end
	end
	return allHooks
end

local function globMatch(glob, set)
	if not glob:find("*", 1, true) then
		return set[glob] == true
	end
	local pat = "^" .. glob:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", "[%%w_]+") .. "$"
	for n in set do
		if n:match(pat) then
			return true
		end
	end
	return false
end

-- the first string argument at `s` (a literal, or "A" .. x .. "B" / `A{x}B` as a glob)
local function stringArg(s)
	s = s:match("^%s*(.*)")
	local lit = s:match('^"([%w_]*)"')
	if lit then
		local rest = s:sub(#lit + 3)
		local tail = rest:match('^%s*%.%.%s*[%w_%.]+%s*%.%.%s*"([%w_]*)"')
		if tail then
			return lit .. "*" .. tail
		elseif rest:match("^%s*%.%.") then
			return lit .. "*"
		end
		return lit
	end
	local interp = s:match("^`([^`]*)`")
	if interp then
		return (interp:gsub("{[^}]*}", "*"))
	end
	return nil
end

-- the hook a CFrame expression ends up on
local POINT_CALLS = { "K%.point%(", "point%(", "groundFrame%(", "K%.host%(", "hookPart%(" }
local function hookIn(text)
	for _, call in POINT_CALLS do
		local at = text:find(call)
		if at then
			local args = text:sub(at):match("%((.*)")
			-- skip model / cue arguments
			args = args:gsub("^%s*model%s*,", ""):gsub("^%s*cue%.model%s*,", ""):gsub("^%s*cue%s*,", "")
			local name = stringArg(args)
			if name then
				return name
			end
		end
	end
	return nil
end

local function resolveAnchor(L, i, expr, src)
	local h = hookIn(expr)
	if h then
		return "hook " .. h, h
	end
	if expr:find("hitFrame") then
		return "the struck target"
	end
	local fn = expr:match("^%s*([%w_]+)%s*%(")
	if fn then
		local body = src:match("local function " .. fn .. "%(.-\nend")
		h = body and hookIn(body)
		if h then
			return "hook " .. h .. " (via " .. fn .. ")", h
		end
	end
	local ident = expr:match("^%s*([%w_]+)%s*$") or expr:match("^%s*([%w_]+)%s*[%*%+]")
	if ident then
		for j = i, math.max(1, i - 30), -1 do
			local l = L[j]
			if l:match("local%s+[%w_,%s]*%f[%w_]" .. ident .. "%f[^%w_][^=]*=") or l:match("^%s*" .. ident .. "%s*=") then
				h = hookIn(l)
				if h then
					return "hook " .. h .. " (line " .. j .. ")", h
				end
				if l:find("hitFrame") then
					return "the struck target"
				end
				if l:find("ground") or l:find("floor") then
					return "the ground (line " .. j .. ")"
				end
				return "computed: " .. (l:match("=%s*(.*)") or l):sub(1, 50)
			end
		end
	end
	if expr:find("[Ee]ye") or expr:find("brow") or expr:find("strip") then
		return "a body part (" .. expr:sub(1, 30) .. ")"
	end
	if expr:find("ground") or expr:find("floor") then
		return "the ground"
	end
	return "computed: " .. expr:sub(1, 50)
end

-- the second top-level argument of the call whose first argument starts at `from`
local function secondArg(line, from)
	local depth, start = 0, nil
	for k = from, #line do
		local c = line:sub(k, k)
		if c == "(" or c == "{" or c == "[" then
			depth += 1
		elseif c == ")" or c == "}" or c == "]" then
			if depth == 0 then
				return start and line:sub(start, k - 1) or nil
			end
			depth -= 1
		elseif c == "," and depth == 0 then
			if start then
				return line:sub(start, k - 1)
			end
			start = k + 1
		end
	end
	return start and line:sub(start) or nil
end

-- anchors the enemy module plays a template on: { { text, hook, line } }
local PLAY_CALLS = { "K%.play%(", "windupPlay%(", "play%(", "make%(" }
local function enemyAnchors(module, name)
	local src = source(module, "EnemyFX")
	if not src then
		return nil
	end
	local L = lines(src)
	local out, seen = {}, {}
	for i, l in L do
		for _, call in PLAY_CALLS do
			local init = 1
			while true do
				local a, b = l:find(call, init)
				if not a then
					break
				end
				init = b + 1
				local prev = l:sub(math.max(1, a - 9), a - 1)
				if call == "play%(" and (prev:match("[%w_%.]$")) then
					continue -- K.play / windupPlay handled by their own pattern
				end
				if call == "make%(" and prev:match("[%w_%.]$") then
					continue
				end
				local arg = stringArg(l:sub(b + 1))
				if arg and (arg == name or (arg:find("*", 1, true) and globMatch(arg, { [name] = true }))) then
					local expr = secondArg(l, b + 1) or "?"
					local text, hook = resolveAnchor(L, i, expr, src)
					if not seen[text] then
						seen[text] = true
						table.insert(out, { text = text, hook = hook, line = i })
					end
				end
			end
		end
	end
	return out
end

-- what the technique code does with each named child of a tier template: the
-- local it is bound to (`local zone = TechniqueVFX.take(copy, "Zone")`), then
-- what that local's CFrame is set from
local function classify(expr)
	if expr:find("WeaponFX") or expr:find("weapon") or expr:find("rig[:%.]") or expr:find("Tip") then
		return "weapon"
	elseif expr:find("hand") or expr:find("palm") or expr:find("[Ff]ist") then
		return "hand"
	elseif expr:find("target") or expr:find("enemy") or expr:find("victim") then
		return "each target"
	end
	return "code"
end
local function techniqueRoles(id)
	local roles = {}
	local prefixes = {}
	local own = source(id, "TechniqueFX")
	for _, s in { own, source("CombatEffects"), source("BladeSkill", "TechniqueFX") } do
		local L = lines(s or "")
		for i, l in L do
			if not (l:find("FindFirstChild") or l:find("take%(") or l:find("%.part%(")) then
				continue
			end
			for n, cat in l:gmatch('"([%w_]+)"(%s*%.?%.?)') do
				if cat:find("..", 1, true) then
					prefixes[n] = true
				end
				if rawget(roles, n) and not rawget(roles, n):match("^pivot") then
					continue -- a placing source wins over one that only takes it
				end
				local where = (s == own and id or "shared") .. ":" .. i
				local var = l:match("local%s+([%w_]+)[^=]*=")
				local role = n == "Charge" and "weapon" or nil
				if not role and var then
					for j = i + 1, math.min(#L, i + 120) do
						local m = L[j]
						local expr = m:match("^%s*" .. var .. "%.CFrame%s*=%s*(.*)") or m:match("^%s*" .. var .. ":PivotTo%((.*)")
						if expr then
							role = classify(expr .. " " .. (L[j - 1] or ""))
							where ..= "->" .. j
							break
						elseif m:find("burstAt%(%s*" .. var .. "%f[^%w_]") or m:find("impactAt%(%s*" .. var .. "%f[^%w_]") then
							role = "each target"
							where ..= "->" .. j
							break
						end
					end
				end
				if not role and l:find("%.part%(") then
					-- the placing CFrame is usually a helper built just above (at())
					role = classify(table.concat(L, " ", math.max(1, i - 10), i))
				end
				if not (rawget(roles, n) and not role) then
					roles[n] = (role or "pivot") .. " (" .. where .. ")"
				end
			end
		end
	end
	-- a child named by a concatenation ("Impact" .. key) takes its prefix's role
	return setmetatable(roles, { __index = function(_, name)
		for prefix in prefixes do
			if name:sub(1, #prefix) == prefix and rawget(roles, prefix) then
				return rawget(roles, prefix)
			end
		end
		return nil
	end })
end

local function sizeOf(inst)
	local best
	for _, a in SIZE_ATTRS do
		local v = inst:GetAttribute(a)
		if type(v) == "number" and (not best or v > best) then
			best = v
		end
	end
	return best
end

local function worldPos(inst)
	if inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

local function relPath(inst, top)
	local parts = {}
	local at = inst.Parent
	while at and at ~= top do
		table.insert(parts, 1, at.Name .. (at:IsA("Attachment") and "@" or ""))
		at = at.Parent
	end
	return #parts > 0 and table.concat(parts, "/") or "(root)"
end

local function welded(part)
	for _, d in part:GetChildren() do
		if (d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D")) and (d.Part0 == part or d.Part1 == part) then
			return true
		end
	end
	for _, d in part.Parent:GetChildren() do
		if (d:IsA("WeldConstraint") or d:IsA("Weld")) and (d.Part0 == part or d.Part1 == part) then
			return true
		end
	end
	return false
end

local function inMeshWave(inst, root)
	local at = inst.Parent
	while at and at ~= root.Parent do
		if at:IsA("Model") and at:GetAttribute("MeshWave") then
			return true
		end
		at = at.Parent
	end
	return false
end

local function codeSets(src, name)
	-- does the module assign attachments to this template's beams/trails?
	return src and (src:find('beam%(%s*"' .. name .. '"') or src:find("%.Attachment[01]%s*=")) ~= nil
end

local function checkTemplate(t, group, rows)
	local out, fails, warns = {}, {}, {}
	local function flag(list, what)
		table.insert(list, what)
	end
	local isModel = not t:IsA("BasePart")
	local module = MODULE_FOR[group] or group
	local enemySrc = source(module, "EnemyFX")
	local isEnemy = enemySrc ~= nil
	local techId = t.Name:match("^(.-)_T%d$")
	local header = string.format("== %s.%s [%s]", group, t.Name, t.ClassName)
	-- anchors
	local hooks, anchorNote = nil, nil
	local body
	if isEnemy then
		local enemies = SS:FindFirstChild("Enemies")
		body = enemies and (rows.body and enemies:FindFirstChild(rows.body) or enemies:FindFirstChild(group .. "B") or enemies:FindFirstChild(group))
		hooks = bodyHooks(body)
		local anchors = enemyAnchors(module, t.Name) or {}
		local texts = {}
		for _, a in anchors do
			local ok = ""
			if a.hook then
				if not body then
					ok = " (no body to check)"
				elseif globMatch(a.hook, hooks) then
					ok = " ok"
				else
					ok = " MISSING on " .. body.Name
					flag(fails, "HOOK " .. a.hook)
				end
			end
			table.insert(texts, a.text .. ok .. " @" .. a.line)
		end
		local kit = source("BeastKit", "EnemyFX") or ""
		anchorNote = if #texts > 0 then table.concat(texts, "; ")
			elseif module == "Impact" then "shared stack (callers pass the point)"
			elseif kit:find('"' .. t.Name .. '"', 1, true) then "BeastKit (eyes / tell parts)"
			else "not played by name in EnemyFX." .. module
	end
	local roles = techId and techniqueRoles(techId) or {}
	local rootSize = sizeOf(t)
	local rootBound
	if rootSize then
		rootBound = rootSize
	elseif not isModel then
		rootBound = math.max(t.Size.X, t.Size.Y, t.Size.Z) / 2 + 1.5
	end
	local pivot = isModel and (t:IsA("Model") and t.WorldPivot or CFrame.new()) or t.CFrame
	table.insert(out, header .. (rootSize and string.format(" size %.1f", rootSize) or (rootBound and string.format(" bound %.1f", rootBound) or "")) .. (anchorNote and ("  on: " .. anchorNote) or ""))
	-- the anchor of an item: the top child the code places, else the root
	local function anchorOf(inst)
		if not isModel then
			return t, "root", rootBound
		end
		local at = inst
		while at.Parent and at.Parent ~= t do
			at = at.Parent
		end
		local role = at ~= t and roles[at.Name]
		if role and at.Parent == t and at:IsA("BasePart") and not role:match("^pivot") then
			return at, at.Name .. "=" .. roles[at.Name]:match("^[^%(]+"):gsub("%s+$", ""), sizeOf(at) or rootSize
		end
		return t, "pivot", rootSize
	end
	local list = t:GetDescendants()
	local shown = 0
	for _, d in list do
		local kind = SHORT[d.ClassName]
		local rowFlags = {}
		if kind then
			local holder = d.Parent
			local pos = worldPos(holder)
			if not pos then
				if mentions(holder.Name) and not (kind == "beam" or kind == "trail") then
					table.insert(rowFlags, "ORIGIN (code names " .. holder.Name .. ": re-hosted?)")
					flag(warns, "ORIGIN " .. d.Name)
				elseif not (kind == "beam" or kind == "trail") then
					table.insert(rowFlags, "ORIGIN")
					flag(fails, "ORIGIN " .. d.Name)
				end
			end
			if (kind == "emit" or kind == "light") and holder == t and not isModel then
				local m = math.max(t.Size.X, t.Size.Y, t.Size.Z)
				if m > 1 then
					table.insert(rowFlags, string.format("area %.0f", m))
				end
				if m > 4 then
					flag(warns, "ROOT " .. d.Name)
				end
			end
			if kind == "beam" or kind == "trail" then
				for _, k in { "Attachment0", "Attachment1" } do
					local a = d[k]
					if not a then
						if not (codeSets(enemySrc or source(techId or "", "TechniqueFX"), t.Name) or mentions(holder.Name) or mentions(t.Name) or mentions(d.Name)) then
							table.insert(rowFlags, "BEAM no " .. k)
							flag(fails, "BEAM " .. d.Name .. " " .. k)
						else
							table.insert(rowFlags, k .. " set by code")
						end
					elseif not a:IsDescendantOf(t) then
						table.insert(rowFlags, "BEAM " .. k .. " outside")
						flag(fails, "BEAM " .. d.Name .. " outside")
					end
				end
				local a0 = d.Attachment0
				pos = a0 and a0:IsDescendantOf(t) and a0.WorldPosition or pos
			end
			local anchor, anchorName, bound = anchorOf(d)
			local from = anchor == t and pivot.Position or anchor.Position
			local off = pos and (pos - from).Magnitude or 0
			if pos and bound and off > bound + 0.05 then
				local hard = off > bound * 2 and not (isModel and anchor == t)
				table.insert(rowFlags, string.format("OFFSET>%.1f", bound))
				flag(hard and fails or warns, string.format("OFFSET %s %.1f", d.Name, off))
			end
			if rows.mode == "all" or (rows.mode == "flagged" and #rowFlags > 0) then
				shown += 1
				table.insert(out, string.format("  %-5s %-16s on %-28s %-22s %5.1f  %s", kind, d.Name:sub(1, 16), relPath(d, t):sub(1, 28), anchorName:sub(1, 22), off, table.concat(rowFlags, " ")))
			end
		elseif d:IsA("BasePart") and d.Parent:IsA("BasePart") and not inMeshWave(d, t) and not welded(d) then
			-- only parts the code moves by CFrame drop their children: the root of a
			-- Part template, or a technique child the code places
			local mover = d.Parent
			local moved = (mover == t) or (isModel and mover.Parent == t and roles[mover.Name] and not roles[mover.Name]:match("^pivot"))
			if moved then
				local named = mentions(d.Name)
				local f = if named then "LOOSE (code names it)" elseif isModel then "LOOSE (check the code carries it)" else "LOOSE"
				flag((named or isModel) and warns or fails, "LOOSE " .. d.Name)
				if rows.mode ~= "none" then
					table.insert(out, string.format("  %-5s %-16s on %-28s %s", "part", d.Name:sub(1, 16), relPath(d, t):sub(1, 28), f .. " (not welded; stays where authored when " .. mover.Name .. " moves)"))
				end
			end
		elseif d:IsA("Attachment") and isEnemy and body then
			local n = d.Name
			if (n:match("_FX$") or everyHook()[n]) and not hooks[n] and d.Parent:IsA("BasePart") then
				-- a template-internal attachment called like a hook that this body lacks
				flag(warns, "NAME " .. n)
				if rows.mode ~= "none" then
					table.insert(out, string.format("  att   %-16s on %-28s NAME: %s has no %s hook", n:sub(1, 16), relPath(d, t):sub(1, 28), body.Name, n))
				end
			end
		end
	end
	local verdict
	if #fails > 0 then
		verdict = "FAIL " .. #fails .. ": " .. table.concat(fails, ", "):sub(1, 160)
	elseif #warns > 0 then
		verdict = "WARN " .. #warns .. ": " .. table.concat(warns, ", "):sub(1, 160)
	else
		verdict = "OK"
	end
	table.insert(out, string.format("  verdict %s.%s: %s", group, t.Name, verdict))
	return table.concat(out, "\n"), #fails, #warns
end

function _G.vfxOriginCheck(target, opts)
	opts = opts or {}
	local effects = RS:FindFirstChild("Effects")
	assert(effects, "no ReplicatedStorage.Effects")
	local todo = {}
	local function addGroup(g)
		for _, t in g:GetChildren() do
			if t:IsA("BasePart") or t:IsA("Model") then
				table.insert(todo, { t, g.Name })
			elseif t:IsA("Folder") then
				for _, u in t:GetChildren() do
					if u:IsA("BasePart") or u:IsA("Model") then
						table.insert(todo, { u, g.Name })
					end
				end
			end
		end
	end
	if target == nil then
		for _, g in effects:GetChildren() do
			addGroup(g)
		end
	elseif typeof(target) == "Instance" then
		local g = target
		while g.Parent and g.Parent ~= effects do
			g = g.Parent
		end
		if target.Parent == effects then
			addGroup(target)
		else
			table.insert(todo, { target, g.Name })
		end
	else
		local groupName, tname = target:match("^([^%.]+)%.?(.*)$")
		local g = effects:FindFirstChild(groupName)
		assert(g, "no Effects." .. groupName)
		if tname == "" then
			addGroup(g)
		else
			table.insert(todo, { assert(g:FindFirstChild(tname), "no " .. target), groupName })
		end
	end
	local mode = opts.rows or (#todo == 1 and "all" or "flagged")
	local out, F, W, ok = {}, 0, 0, 0
	for _, item in todo do
		local text, f, w = checkTemplate(item[1], item[2], { mode = mode, body = opts.body })
		if mode == "none" then
			text = text:match("[^\n]*\n?") .. text:match("  verdict[^\n]*$")
		end
		table.insert(out, text)
		F += f > 0 and 1 or 0
		W += (f == 0 and w > 0) and 1 or 0
		ok += (f == 0 and w == 0) and 1 or 0
	end
	table.insert(out, string.format("== %d templates: %d OK, %d WARN, %d FAIL", #todo, ok, W, F))
	return table.concat(out, "\n")
end

return "vfxOriginCheck installed"
