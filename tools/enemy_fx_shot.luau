--!nocheck
-- Freeze an EnemyFX cue on the real body for a capture, in a sandbox Studio
-- (Edit mode). One call stages the body, fires a sequence of cues at their real
-- moments (with the model's Attack / AIState / StateAt set the way the server
-- would), waits to the moment you want, freezes every particle and mesh-wave
-- tween, and returns the camera to pass to screen_capture. The next call (or
-- clear()) removes the previous scene.
-- Run tools/serve.sh, push edited src first (tools/push_src.luau). Then:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8768/tools/enemy_fx_shot.luau"))()
--   return _G.enemyFxShot({
--     body = "ElderWolfKingB", mod = "ElderWolfKing",
--     cues = { { "windup", "crownfall", 1.25 }, { "strike", "crownfall", at = 1.25 } },
--     freeze = 1.31,            -- seconds after the first cue
--     view = "side",            -- "side", "front", "top", "player", "far" or { pos, look } offsets from the root
--     clock = 14,               -- Lighting.ClockTime for the shot (restored by clear())
--   })
-- A cue is { name, attack?, seconds?, state = AIState?, at = seconds after the
-- first cue? }; shape.center defaults to 9 studs ahead (pass shape = {...}).
-- Returns "camera x,y,z look x,y,z" for screen_capture's camera_position and
-- look_at_position. Bring the sandbox window to the front before capturing
-- (toolkit.md, "Module and add-on gotchas").

local CENTER = Vector3.new(400, 648.6, 0)
local DEFAULT_STATE = { windup = "windup", strike = "recover", dash = "dash", land = "recover", stagger = "stagger", hit = "recover", skid = "recover", death = "recover" }
local VIEWS = {
	side = { Vector3.new(34, 10, -8), Vector3.new(0, 4, -8) },
	front = { Vector3.new(6, 9, -34), Vector3.new(0, 5, -4) },
	player = { Vector3.new(-10, 9, -28), Vector3.new(0, 4, -8) },
	top = { Vector3.new(0.1, 46, -10), Vector3.new(0, 0, -10) },
	far = { Vector3.new(30, 18, -52), Vector3.new(0, 4, -8) },
}

local state = { scene = nil, clock = nil, oldFolder = nil, oldCleanup = nil }

local function clear()
	local Client = game.StarterPlayer.StarterPlayerScripts.Client
	local TV = require(Client.TechniqueVFX)
	for tween in TV.waves do
		pcall(function()
			tween:Cancel()
		end)
	end
	if state.scene then
		state.scene:Destroy()
		state.scene = nil
	end
	if state.oldFolder then
		TV.folder = state.oldFolder
		TV.cleanup = state.oldCleanup
		state.oldFolder = nil
	end
	if state.clock then
		game.Lighting.ClockTime = state.clock
		state.clock = nil
	end
	local temp = workspace.Terrain:FindFirstChild("TempVFX")
	if temp then
		temp:ClearAllChildren()
	end
end

function _G.enemyFxShot(o)
	clear()
	local Client = game.StarterPlayer.StarterPlayerScripts.Client
	local TV = require(Client.TechniqueVFX)
	local scene = Instance.new("Folder")
	scene.Name = "_EnemyFxShot"
	scene.Parent = workspace
	state.scene = scene
	-- effects into a workspace folder (screen_capture swaps the camera), and
	-- no cleanup, so the frozen frame survives until the capture
	state.oldFolder, state.oldCleanup = TV.folder, TV.cleanup
	local fx = Instance.new("Folder")
	fx.Name = "Effects"
	fx.Parent = scene
	TV.folder = fx
	TV.cleanup = function() end
	if o.clock then
		state.clock = game.Lighting.ClockTime
		game.Lighting.ClockTime = o.clock
	end
	local m = game.ServerStorage.Enemies[o.body]:Clone()
	m:PivotTo(m:GetPivot() + CENTER)
	m:SetAttribute("Template", o.body)
	m:SetAttribute("EnemyType", o.mod)
	m:SetAttribute("Health", o.health or 1000)
	m:SetAttribute("MaxHealth", o.maxHealth or 1900)
	m.Parent = scene
	local root = m.HumanoidRootPart
	local target = Instance.new("Model")
	target.Name = "Target"
	local tp = Instance.new("Part")
	tp.Name, tp.Size, tp.Anchored, tp.CanQuery = "HumanoidRootPart", Vector3.new(2, 5, 1), true, false
	tp.Position = CENTER + Vector3.new(0, 2.5, -16)
	tp.Color = Color3.fromRGB(200, 60, 60)
	tp.Parent = target
	target.Parent = scene
	-- park the editor camera first: Edit-mode particles only simulate near it
	local view = if type(o.view) == "table" then o.view else VIEWS[o.view or "side"]
	local base = root.Position - Vector3.new(0, root.Position.Y - CENTER.Y, 0)
	local cam, look = base + view[1], base + view[2]
	workspace.CurrentCamera.CFrame = CFrame.lookAt(cam, look)
	local handlers = require(Client.EnemyFX[o.mod])
	local start = os.clock()
	local t0 = workspace:GetServerTimeNow()
	for _, c in o.cues do
		local due = c.at or 0
		local wait = due - (os.clock() - start)
		if wait > 0 then
			task.wait(wait)
		end
		local at = t0 + due
		m:SetAttribute("Attack", c[2])
		m:SetAttribute("AIState", c.state or DEFAULT_STATE[c[1]])
		m:SetAttribute("StateAt", at)
		local cue = {
			model = m, root = root, kind = o.mod, attack = c[2], seconds = c[3],
			shape = c.shape or { center = CENTER + Vector3.new(0, 0, -9), radius = 5 },
			target = target, at = at,
		}
		task.spawn(handlers[c[1]], cue)
	end
	local wait = (o.freeze or 0) - (os.clock() - start)
	if wait > 0 then
		task.wait(wait)
	end
	for _, d in scene:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.TimeScale = 0
		end
	end
	for tween in TV.waves do
		pcall(function()
			tween:Pause()
		end)
	end
	return string.format("camera %.1f,%.1f,%.1f look %.1f,%.1f,%.1f", cam.X, cam.Y, cam.Z, look.X, look.Y, look.Z)
end

_G.enemyFxShotClear = clear
return true
