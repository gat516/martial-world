--!nocheck
-- One-call staging for the mapped ReplicatedStorage.Effects folder. Run this file
-- (and tools/export_rbxm.luau, for _G.exportRbxm) once through execute_luau,
-- with tools/receive_rbxmx.py running. Installs _G.vfxStage:
--
--   local staging = _G.vfxStage.begin()   -- fresh clone at ReplicatedStorage._StagingEffects
--   ... edit/build inside `staging` ...
--   _G.vfxStage.finish()                  -- export, destroy staging, wait for Rojo
--
-- finish() POSTs the staging copy as Effects.rbxm (root renamed to "Effects"),
-- destroys the staging copy, and returns a summary: templates per group, tagged
-- add-on instances, and how many Effects copies exist. Then on disk run
-- tools/vfx_export.sh to move the file into assets/ and verify it; Rojo patches
-- the live folder from the file (finish's `wait` polls `check` for that).
--
-- Never build in ReplicatedStorage.Effects itself (AGENTS.md, "Studio instances").

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local Stage = {}
local NAME = "_StagingEffects"

function Stage.begin()
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

-- check(): optional function(effectsFolder) -> boolean, true once Rojo has
-- applied the change (e.g. an attribute you just set). Waits up to 10 s.
function Stage.finish(check)
	assert(_G.exportRbxm, "run tools/export_rbxm.luau first")
	local staging = RS:FindFirstChild(NAME)
	assert(staging, "no staging copy; call begin() first")
	local text = summary(staging)
	local reply = HttpService:PostAsync("http://127.0.0.1:8766/Effects.rbxm", _G.exportRbxm("ReplicatedStorage." .. NAME, "Effects"))
	staging:Destroy()
	local synced = check == nil
	if check then
		local t0 = os.clock()
		while os.clock() - t0 < 10 do
			if pcall(check, RS.Effects) and check(RS.Effects) then
				synced = true
				break
			end
			task.wait(0.25)
		end
	end
	local copies = 0
	for _, c in RS:GetChildren() do
		if c.Name == "Effects" then
			copies += 1
		end
	end
	return string.format("export %s | %s | Effects copies %d | rojo synced %s", reply, text, copies, tostring(synced))
end

_G.vfxStage = Stage
return "vfxStage installed"
