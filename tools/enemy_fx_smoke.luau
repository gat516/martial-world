--!nocheck
-- Smoke test for EnemyFX handlers against the real bodies, in a sandbox Studio
-- (tools/sandbox.sh; Edit mode). Clones each body from ServerStorage.Enemies
-- onto the baseplate, sets Template/EnemyType/Health, fires a list of cues at
-- the handler module and reports errors, how many effect parts each cue
-- spawned, and which named hooks (attachments / parts) are missing.
-- Run tools/serve.sh, push edited src first (tools/push_src.luau; destroy the old
-- module copies first, or require returns the cached version). Then:
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8768/tools/enemy_fx_smoke.luau"))()
--   return _G.enemyFxSmoke({
--     BloodCentipede = { mod = "BloodCentipede", hooks = { "Mouth" },
--       cues = { { "windup", "pincerSnap" }, { "strike", "pincerSnap" }, { "death" } } },
--   })
-- A cue is { name, attack?, seconds?, state?, shape = ? } (shape overrides the
-- default, e.g. a boss barrage's parts built like the server's). Handlers run with a dummy target
-- character 14 studs ahead and a shape.center 18 studs ahead.
-- `stateful = true` on a body's plan (for handlers that guard on the model's
-- state, like the bosses'): before each cue the model gets Attack = attack,
-- AIState = state (default by cue: windup/recover/dash/stagger), a fresh
-- StateAt, and the cue's `at` is the server time now. `wait = s` holds each
-- cue that long so delayed beats fire; spawns are then counted in
-- TechniqueVFX.folder as well as the camera.

local FLOOR = 648.6
function _G.enemyFxSmoke(plan)
	local SS = game.ServerStorage.Enemies
	local Client = game.StarterPlayer.StarterPlayerScripts.Client
	local cam = workspace.CurrentCamera
	local out = {}
	local target = Instance.new("Model")
	local tp = Instance.new("Part")
	tp.Name, tp.Size, tp.Position, tp.Anchored = "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(400, FLOOR + 3, -14), true
	tp.Parent = target
	target.Parent = workspace
	for template, p in plan do
		local m = SS[template]:Clone()
		m:PivotTo(m:GetPivot() + Vector3.new(400, FLOOR, 0))
		m:SetAttribute("Template", template)
		m:SetAttribute("EnemyType", p.mod)
		m:SetAttribute("Health", 50)
		m.Parent = workspace
		local root = m.HumanoidRootPart
		table.insert(out, `== {template}: root {root.Size}, faces {root.CFrame.LookVector}`)
		for _, h in p.hooks or {} do
			local f = m:FindFirstChild(h, true)
			table.insert(out, `  hook {h}: {f and f.ClassName or "MISSING"}`)
		end
		local handlers = require(Client.EnemyFX[p.mod])
		local DEFAULT_STATE = { windup = "windup", strike = "recover", dash = "dash", land = "recover", stagger = "stagger", hit = "recover", skid = "recover" }
		local okTV, TV = pcall(require, Client.TechniqueVFX)
		local folder = okTV and TV.folder or nil
		-- count what each cue adds (net child counts hide spawns that were
		-- already cleaned up by the end of a `wait`)
		local added = 0
		local conns = { cam.ChildAdded:Connect(function() added += 1 end) }
		if folder and folder ~= cam then
			table.insert(conns, folder.ChildAdded:Connect(function() added += 1 end))
		end
		local function count()
			return added
		end
		for _, c in p.cues do
			local before = count()
			local at = 0
			if p.stateful then
				at = workspace:GetServerTimeNow()
				m:SetAttribute("Attack", c[2])
				m:SetAttribute("AIState", c[4] or DEFAULT_STATE[c[1]])
				m:SetAttribute("StateAt", at)
			end
			local cue = {
				model = m, root = root, kind = p.mod, attack = c[2], seconds = c[3],
				shape = c.shape or { center = Vector3.new(400, FLOOR, -18), radius = 5 },
				target = target, at = at,
			}
			local fn = handlers[c[1]]
			if not fn then
				table.insert(out, `  {c[1]}: no handler`)
			else
				local ok, err = pcall(fn, cue)
				if p.wait then
					task.wait(p.wait)
				end
				table.insert(out, `  {c[1]} {c[2] or ""}: {ok and "ok" or ("ERROR " .. tostring(err))} (+{count() - before})`)
			end
		end
		task.wait(0.2)
		for _, c in conns do
			c:Disconnect()
		end
		m:Destroy()
	end
	target:Destroy()
	return table.concat(out, "\n")
end
return true
