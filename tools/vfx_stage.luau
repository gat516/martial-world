--!nocheck
-- One-call staging for the mapped ReplicatedStorage.Effects folder. Run this file
-- (and tools/export_rbxm.luau, for _G.exportRbxm) once through execute_luau,
-- with tools/receive_rbxmx.py running. Installs _G.vfxStage:
--
--   _G.vfxStage.lock(who)                 -- Studio lock between sessions (see below)
--   local staging = _G.vfxStage.begin(who) -- fresh clone at ReplicatedStorage._StagingEffects
--                                          -- (refuses if templates were edited by hand)
--   ... edit/build inside `staging` ...
--   _G.vfxStage.finish()                  -- export, destroy staging
--   (on disk) tools/vfx_export.sh [names]  -- into assets/, verified
--   _G.vfxStage.synced(check)              -- Rojo patched the live folder?
--   (commit assets/Effects.rbxm), then _G.vfxStage.unlock(who)
--
-- finish() POSTs the staging copy as Effects.rbxm (root renamed to "Effects"),
-- destroys it and returns a summary (templates per group, add-on tags).
--
-- Never build in ReplicatedStorage.Effects itself (AGENTS.md, "Studio instances").
--
-- Hand-edit guard: finish() stamps every template (each child of a group, e.g.
-- Effects.MethodAura.BlazingHeart) with a BuildStamp attribute, a hash of its
-- vfxDiff snapshot. begin() re-hashes the live templates: one whose hash no
-- longer matches was changed in Studio since the last export (usually the
-- user's hand edit), and a builder rebuild would wipe it. begin() then errors
-- with the list; read the edits (vfxDiff), fold them into the spec, and call
-- begin(who, { acceptEdits = true }). Unstamped templates aren't checked.
-- begin() also lists effect-looking instances loose in Workspace (outside
-- `_`-prefixed preview folders): they may be the user's work, so report them
-- and never delete them without asking.

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local Stage = {}
local NAME = "_StagingEffects"

-- A Studio lock between sessions sharing one Studio (several vfx agents at
-- once): take it before staging, previews or captures, hold it through
-- export, Rojo sync and the git commit of assets/Effects.rbxm, then release.
-- Stored as ServerStorage's VFXStudioLock attribute ("who|unix time"); a lock
-- older than STALE seconds counts as abandoned.
local LOCK, STALE = "VFXStudioLock", 20 * 60
local function holder(): (string?, number?)
	local v = game:GetService("ServerStorage"):GetAttribute(LOCK)
	if type(v) ~= "string" then
		return nil, nil
	end
	local who, t = v:match("^(.-)|(%d+)$")
	return who, tonumber(t)
end

-- true, or false and who holds it (and for how long). Re-locking refreshes it.
function Stage.lock(who: string)
	local owner, t = holder()
	if owner and owner ~= who and t and os.time() - t < STALE then
		return false, string.format("held by %s for %ds", owner, os.time() - t)
	end
	game:GetService("ServerStorage"):SetAttribute(LOCK, who .. "|" .. os.time())
	return true
end

function Stage.unlock(who: string)
	if holder() == who then
		game:GetService("ServerStorage"):SetAttribute(LOCK, nil)
	end
end

function Stage.holder()
	return holder()
end

local STAMP = "BuildStamp"
-- Runtime state and the stamp itself don't count as edits.
local SKIP = { "@" .. STAMP .. "=", "@EmitBreak=" }

local function hash(root): string
	assert(_G.vfxDiff, "run tools/vfx_diff.luau first (vfx_session.luau loads it)")
	local lines = {}
	for path, desc in _G.vfxDiff.snapshot(root) do
		local fields = {}
		for f in string.gmatch(desc, "[^|]+") do
			local skip = false
			for _, prefix in SKIP do
				if f:sub(1, #prefix) == prefix then
					skip = true
				end
			end
			if not skip then
				table.insert(fields, f)
			end
		end
		-- same-named siblings may come back from Rojo in another order
		table.insert(lines, path:gsub("#%d+", "") .. "=" .. table.concat(fields, "|"))
	end
	table.sort(lines)
	local h1, h2 = 5381, 52711
	for _, line in lines do
		for i = 1, #line do
			local c = string.byte(line, i)
			h1 = (h1 * 33 + c) % 4294967296
			h2 = (h2 * 31 + c) % 4294967291
		end
	end
	return string.format("%08x%08x", h1, h2)
end

local function templates(root)
	local out = {}
	for _, group in root:GetChildren() do
		for _, t in group:GetChildren() do
			table.insert(out, t)
		end
	end
	return out
end

-- Live templates changed since their last export: { "Group.Template", ... }.
function Stage.edited(): { string }
	local out = {}
	for _, t in templates(RS.Effects) do
		local stamp = t:GetAttribute(STAMP)
		if stamp and stamp ~= hash(t) then
			table.insert(out, t.Parent.Name .. "." .. t.Name)
		end
	end
	return out
end

local EFFECT_ATTRS = { "Hidden", "Pulse", "Point", "Grow", "Spin", "Turn", "EmitCount", "EmitDuration", "EmitDelay", "MeshWave", STAMP }

-- Effect-looking instances in Workspace outside `_`-prefixed folders
-- (previews, staging): maybe the user's, never delete them unasked.
function Stage.strays(): { string }
	local out = {}
	local function walk(inst)
		for _, c in inst:GetChildren() do
			if c.Name:sub(1, 1) == "_" or c:IsA("Terrain") or c:IsA("Camera") then
				continue
			end
			local hit = false
			for _, a in EFFECT_ATTRS do
				if c:GetAttribute(a) ~= nil then
					hit = true
					break
				end
			end
			if hit then
				table.insert(out, c:GetFullName())
			elseif c:IsA("Folder") or c:IsA("Model") then
				if c.Name ~= "Map" then -- the map's ambient FX are placed on purpose
					walk(c)
				end
			end
		end
	end
	walk(workspace)
	return out
end

-- `who` must hold the lock (Stage.lock(who)).
function Stage.begin(who: string?, opts: { acceptEdits: boolean? }?)
	assert(who and holder() == who, "take the Studio lock first: vfxStage.lock(who), then vfxStage.begin(who)")
	local edited = Stage.edited()
	if #edited > 0 and not (opts and opts.acceptEdits) then
		error("hand edits since the last export in: " .. table.concat(edited, ", ")
			.. ". A rebuild would wipe them. Diff them (vfxDiff), fold them into the spec, report them,"
			.. " then begin(who, { acceptEdits = true }).", 2)
	end
	local strays = Stage.strays()
	if #strays > 0 then
		warn("vfxStage: effect-looking instances loose in Workspace (maybe the user's; report, don't delete): "
			.. table.concat(strays, ", "))
	end
	local old = RS:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local staging = RS.Effects:Clone()
	staging.Name = NAME
	staging.Parent = RS
	return staging
end

local function summary(root)
	local groups = {}
	for _, group in root:GetChildren() do
		local names = {}
		for _, t in group:GetChildren() do
			table.insert(names, t.Name)
		end
		table.sort(names)
		table.insert(groups, group.Name .. "[" .. table.concat(names, ",") .. "]")
	end
	local tags = {}
	for _, tag in { "CraterVFX", "SplineVFX", "MeshVFX", "ColorVFX", "ScaleVFX" } do
		local n = 0
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsDescendantOf(root) then
				n += 1
			end
		end
		if n > 0 then
			table.insert(tags, tag .. "=" .. n)
		end
	end
	return table.concat(groups, " ") .. " | tags " .. table.concat(tags, ",")
end

-- Exports the staging copy as Effects.rbxm (root renamed "Effects") and
-- destroys it. Rojo patches the live folder only after tools/vfx_export.sh
-- has copied the file into assets/, so confirm that with Stage.synced.
function Stage.finish()
	assert(_G.exportRbxm, "run tools/export_rbxm.luau first")
	local staging = RS:FindFirstChild(NAME)
	assert(staging, "no staging copy; call begin() first")
	for _, t in templates(staging) do
		t:SetAttribute(STAMP, nil)
		t:SetAttribute(STAMP, hash(t))
	end
	local text = summary(staging)
	local reply = HttpService:PostAsync("http://127.0.0.1:8766/Effects.rbxm", _G.exportRbxm("ReplicatedStorage." .. NAME, "Effects"))
	staging:Destroy()
	return string.format("export %s | %s | next: tools/vfx_export.sh, then vfxStage.synced(check)", reply, text)
end

-- After tools/vfx_export.sh: waits (up to 10 s) until check(ReplicatedStorage.Effects)
-- is true, i.e. Rojo applied the change, and reports how many Effects copies exist.
function Stage.synced(check)
	local ok = false
	local t0 = os.clock()
	while os.clock() - t0 < 10 do
		local passed, result = pcall(check, RS.Effects)
		if passed and result then
			ok = true
			break
		end
		task.wait(0.25)
	end
	local copies = 0
	for _, c in RS:GetChildren() do
		if c.Name == "Effects" then
			copies += 1
		end
	end
	return string.format("rojo synced %s | Effects copies %d", tostring(ok), copies)
end

_G.vfxStage = Stage
return "vfxStage installed"
