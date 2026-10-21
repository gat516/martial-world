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
-- A cue is { model, root, kind, attack, shape, seconds, at } (`at` = server time
-- the cue began; shape and seconds only on windup).
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

local function fire(model: Model, name: string, extra: { shape: any?, seconds: number?, at: number? }?)
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
	if not fn then
		return
	end
	local attack = model:GetAttribute("Attack")
	local at = model:GetAttribute("StateAt")
	local cue: Cue = {
		model = model,
		root = root,
		kind = kind,
		attack = if type(attack) == "string" then attack else nil,
		shape = extra and extra.shape,
		seconds = extra and extra.seconds,
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
	model:GetAttributeChangedSignal("AIState"):Connect(function()
		local state = model:GetAttribute("AIState")
		if previous == "windup" and (state == "dash" or state == "recover") then
			fire(model, "strike")
		end
		if state == "dash" or state == "stagger" then
			fire(model, state :: string)
		end
		previous = state
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
	telegraph.OnClientEvent:Connect(function(shape, seconds, model, _attack, startedAt)
		if typeof(model) == "Instance" and model:IsA("Model") and type(seconds) == "number" then
			local at = if type(startedAt) == "number" then startedAt else workspace:GetServerTimeNow()
			local left = math.max(0, seconds - (workspace:GetServerTimeNow() - at))
			fire(model, "windup", { shape = shape, seconds = left, at = at })
		end
	end)
end

return EnemyFX
