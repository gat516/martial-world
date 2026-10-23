--!nocheck
-- Push src/ files from disk into a sandbox Studio (tools/sandbox.sh), which has
-- no Rojo: a sandbox holds src/ as it was when it opened, so a module you edit
-- (or add) afterwards needs pushing before a preview or QA script requires it.
-- Run tools/serve.sh first (no args: 8768 serves the repo root; `tools/serve.sh <port>`
-- serves your worktree, then set _G.SERVE_BASE = "http://127.0.0.1:<port>/" before loading),
-- then in the sandbox, through execute_luau:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8768/tools/push_src.luau"))()
--   _G.pushSrc({ "src/client/EnemyPoses/Boar.luau", "src/client/EnemyPoses/Quadruped.luau" })
-- Paths map like test.project.json: src/shared -> ReplicatedStorage.Shared,
-- src/server -> ServerScriptService.Server, src/client ->
-- StarterPlayer.StarterPlayerScripts.Client; X.luau is a ModuleScript,
-- X.server.luau a Script, X.client.luau a LocalScript, init.luau its folder's
-- module. Missing scripts (and folders) are created. Never run this in the
-- user's own Studio: there Rojo owns these instances.

local HttpService = game:GetService("HttpService")
local BASE = _G.SERVE_BASE or "http://127.0.0.1:8768/" -- repo root, e.g. tools/serve.sh <port>

local ROOTS = {
	["src/shared"] = function()
		return game:GetService("ReplicatedStorage").Shared
	end,
	["src/server"] = function()
		return game:GetService("ServerScriptService").Server
	end,
	["src/client"] = function()
		return game:GetService("StarterPlayer").StarterPlayerScripts.Client
	end,
}

local function push(path: string): string
	local rootKey, rest = nil, nil
	for key in ROOTS do
		if path:sub(1, #key + 1) == key .. "/" then
			rootKey, rest = key, path:sub(#key + 2)
		end
	end
	assert(rootKey, `not under a mapped src/ root: {path}`)
	local parts = string.split(rest, "/")
	local file = table.remove(parts)
	local name, class = file:match("^(.-)%.server%.luau$"), "Script"
	if not name then
		name, class = file:match("^(.-)%.client%.luau$"), "LocalScript"
	end
	if not name then
		name, class = file:match("^(.-)%.luau$"), "ModuleScript"
	end
	assert(name, `not a .luau file: {path}`)
	local parent = ROOTS[rootKey]()
	if name == "init" then
		-- the folder itself is the script; only modules are supported here
		name = table.remove(parts)
		assert(name, `init.luau at a src root isn't supported: {path}`)
	end
	for _, dir in parts do
		local child = parent:FindFirstChild(dir)
		if not child then
			child = Instance.new("Folder")
			child.Name = dir
			child.Parent = parent
		end
		parent = child
	end
	local source = HttpService:GetAsync(`{BASE}{path}`)
	local script = parent:FindFirstChild(name)
	if script and script.ClassName ~= class then
		if script:IsA("Folder") then
			-- a folder becoming its init module: keep its children
			local module = Instance.new(class)
			module.Name = name
			for _, c in script:GetChildren() do
				c.Parent = module
			end
			script:Destroy()
			module.Parent = parent
			script = module
		else
			error(`{script:GetFullName()} is a {script.ClassName}, not a {class}`)
		end
	end
	if not script then
		script = Instance.new(class)
		script.Name = name
		script.Parent = parent
	end
	script.Source = source
	return `{script:GetFullName()} ({#source} bytes)`
end

_G.pushSrc = function(paths: { string }): { string }
	local done = {}
	for _, path in paths do
		table.insert(done, push(path))
	end
	return done
end
