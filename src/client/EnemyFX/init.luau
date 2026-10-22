--!strict
-- Client side of the enemies' authority split: cosmetic beast effects, local
-- only. The server says what is happening (AIState, Attack, StateAt and FadeAt
-- attributes, the Telegraph remote) and this plays it; nothing here can change
-- a fight. See docs/systems/enemies.md, "Server and client".
--
-- Per-beast effects live in EnemyFX/<EnemyType>.luau, a module returning
-- handlers by cue (any may be left out):
--   windup(cue)   an attack starts: cue.attack, cue.shape, cue.seconds (left)
--   strike(cue)   the windup ran out unbroken: the blow lands now
--   dash(cue)     a lunge or charge sets off
--   stagger(cue)  knocked back by a player
--   death(cue)    killed (the body then fades, below)
--   land(cue)     a dash ended (AIState left "dash"): a lunge skids to a stop,
--                 a leap modelled as a dash touches down. Also sent by the
--                 server for moves that aren't dashes (below).
--   ready(cue)    the enemy was first seen (once): start ambient effects
--   aggro(cue)    it noticed a player (idle or returning -> chase)
--   hit(cue)      the blow caught a player: cue.target is their Character.
--                 Only from the server (below).
--   skid(cue)     an overshoot skid-and-turn started: the Attack (or
--                 AttackName) attribute became `<move>Skid` (cue.attack is that
--                 name). Beasts without a handler get the shared dust spray from
--                 the feet (Impact.skid).
-- `land` carries the attack that was dashing (an arrival follow-up such as
-- rushSwipe may already have replaced the model's Attack when it fires).
-- EnemyFX/Impact is the shared impact kit (shockwaves, dust, bursts, scars,
-- roars, skids, projectile cores), not a beast.
-- A cue is { model, root, kind, attack, shape, seconds, target, at } (`at` =
-- server time the cue began; shape and seconds only on windup, target only on
-- hit).
-- Server-sent cues ride the Effect remote, to all clients:
--   Effect:FireAllClients("enemyCue", model, name, target?)
-- and, for a spit's lingering patch, Effect:FireAllClients("enemyPatch", model, center, radius,
-- seconds, effect): handler `patch` with shape = { center, radius, effect } and seconds.
-- where name is a handler name ("hit", "land", ...) and target an optional
-- Character. EnemyFX calls the beast's handler with the model's current Attack.
-- Cues past MAX_DISTANCE from the camera are skipped. Every beast's body fades
-- here when FadeAt is set (death or despawn), so the server sends no per-part
-- changes for it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MAX_DISTANCE = 220
local FADE = TweenInfo.new(1)

export type Cue = {
	model: Model,
	root: BasePart,
	kind: string,
	attack: string?,
	shape: any?,
	seconds: number?,
	target: Model?,
	at: number,
}
type Handlers = { [string]: (Cue) -> () }

local EnemyFX = {}

local handlers: { [string]: Handlers | false } = {}
-- streamed-out enemies come back as the same instance: watch each only once
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function handlersFor(kind: string): Handlers?
	local cached = handlers[kind]
	if cached == nil then
		local module = script:FindFirstChild(kind)
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
			if not ok then
				warn(`EnemyFX: {kind} failed to load: {result}`)
			end
		end
		cached = if ok and type(result) == "table" then result else false
		handlers[kind] = cached
	end
	return cached or nil
end

-- A beast with no skid handler: dust from under each side of the root.
local function defaultSkid(cue: Cue)
	local ok, Impact = pcall(require, script.Impact)
	if not ok then
		return
	end
	local root = cue.root
	local half = root.Size.X / 2
	local look = root.CFrame.LookVector
	local feet = {}
	for _, side in { -1, 1 } do
		local at = root.CFrame:PointToWorldSpace(Vector3.new(side * half * 0.8, 0, -root.Size.Z * 0.3))
		table.insert(feet, (Impact :: any).floor(at, { cue.model }))
	end
	(Impact :: any).skid(feet, look, { scale = math.clamp(root.Size.X / 3, 0.6, 3), seconds = 0.35 })
end

local function fire(model: Model, name: string, extra: { shape: any?, seconds: number?, target: Model?, at: number?, attack: string? }?)
	local root = model:FindFirstChild("HumanoidRootPart")
	local kind = model:GetAttribute("EnemyType")
	if not (root and root:IsA("BasePart") and type(kind) == "string") then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local set = handlersFor(kind)
	local fn = set and set[name]
	if not fn and name == "skid" then
		fn = defaultSkid
	end
	if not fn then
		return
	end
	-- a windup cue carries the telegraph's own attack name (a boss's sub-telegraphs such
	-- as stormBolt differ from the model's Attack); other cues use the model's
	local attack = if extra and extra.attack then extra.attack else model:GetAttribute("Attack")
	local at = model:GetAttribute("StateAt")
	local cue: Cue = {
		model = model,
		root = root,
		kind = kind,
		attack = if type(attack) == "string" then attack else nil,
		shape = extra and extra.shape,
		seconds = extra and extra.seconds,
		target = extra and extra.target,
		at = (extra and extra.at) or (if type(at) == "number" then at else workspace:GetServerTimeNow()),
	}
	task.spawn(function()
		local ok, err = pcall(fn, cue)
		if not ok then
			warn(`EnemyFX: {kind}.{name} errored: {err}`)
		end
	end)
end

local function fade(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			TweenService:Create(d, FADE, { Transparency = 1 }):Play()
		elseif d:IsA("Decal") or d:IsA("Texture") then
			TweenService:Create(d, FADE, { Transparency = 1 }):Play()
		end
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") or watched[model] then
		return
	end
	watched[model] = true
	if model:GetAttribute("FadeAt") ~= nil then
		fade(model)
		return
	end
	local previous = model:GetAttribute("AIState")
	local dashAttack: string? = nil
	local lastSkid = 0
	task.spawn(function()
		if model:WaitForChild("HumanoidRootPart", 5) then
			fire(model, "ready")
		end
	end)
	model:GetAttributeChangedSignal("AIState"):Connect(function()
		local state = model:GetAttribute("AIState")
		if state == "chase" and (previous == "idle" or previous == "return") then
			fire(model, "aggro")
		end
		if previous == "windup" and (state == "dash" or state == "recover") then
			fire(model, "strike")
		end
		if state == "dash" then
			local a = model:GetAttribute("Attack")
			dashAttack = if type(a) == "string" then a else nil
		end
		if state == "dash" or state == "stagger" then
			fire(model, state :: string)
		end
		if previous == "dash" and state ~= "dash" then
			fire(model, "land", { attack = dashAttack })
		end
		previous = state
	end)
	-- an overshoot's skid-and-turn (the server names it `<move>Skid`)
	local function skidCheck(name: string)
		local value = model:GetAttribute(name)
		if type(value) == "string" and value:sub(-4) == "Skid" and os.clock() - lastSkid > 0.3 then
			lastSkid = os.clock()
			fire(model, "skid", { attack = value })
		end
	end
	model:GetAttributeChangedSignal("Attack"):Connect(function()
		skidCheck("Attack")
	end)
	model:GetAttributeChangedSignal("AttackName"):Connect(function()
		skidCheck("AttackName")
	end)
	model:GetAttributeChangedSignal("FadeAt"):Connect(function()
		fade(model)
	end)
	local died = false
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		if not died and type(health) == "number" and health <= 0 then
			died = true
			fire(model, "death")
		end
	end)
end

function EnemyFX.init()
	for _, model in CollectionService:GetTagged("Enemy") do
		task.spawn(watch, model)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(model)
		task.spawn(watch, model)
	end)
	-- the windup cue rides the telegraph, which carries the attack's area
	local telegraph = ReplicatedStorage.Remotes.Telegraph :: RemoteEvent
	telegraph.OnClientEvent:Connect(function(shape, seconds, model, attackName, startedAt)
		if typeof(model) == "Instance" and model:IsA("Model") and type(seconds) == "number" then
			local at = if type(startedAt) == "number" then startedAt else workspace:GetServerTimeNow()
			local left = math.max(0, seconds - (workspace:GetServerTimeNow() - at))
			fire(model, "windup", { shape = shape, seconds = left, at = at, attack = if type(attackName) == "string" then attackName else nil })
		end
	end)
	-- server-sent cues with no attribute of their own (hit, non-dash landings)
	local effect = ReplicatedStorage.Remotes.Effect :: RemoteEvent
	effect.OnClientEvent:Connect(function(kind, model, name, target, patchSeconds, patchEffect)
		if kind == "enemyPatch" and typeof(model) == "Instance" and model:IsA("Model") and typeof(name) == "Vector3" then
			-- a lingering patch a spit left (EnemyFX `patch`): shape.center, shape.radius, shape.effect, seconds
			fire(model, "patch", { shape = { center = name, radius = target, effect = patchEffect }, seconds = patchSeconds })
			return
		end
		if kind ~= "enemyCue" or typeof(model) ~= "Instance" or not model:IsA("Model") or type(name) ~= "string" then
			return
		end
		local character = if typeof(target) == "Instance" and target:IsA("Model") then target else nil
		fire(model, name, { target = character })
	end)
end

return EnemyFX
