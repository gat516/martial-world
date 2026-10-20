--!strict
-- Plays technique effect templates (ReplicatedStorage.Effects.<Id>.<Id>_T<tier>)
-- through the vfxia Game Module (ReplicatedStorage.vfx). Templates are authored
-- with the plugin's Emit attributes (EmitCount, EmitDelay, EmitDuration, ...), so
-- what plays here is what the plugin's Emit button shows in Studio.
--
-- Tier and per-level step come from Techniques.visualTier: each tier is its own
-- template, and each level inside a tier multiplies the template's EmitCount
-- attributes by 1 + STEP_COUNT * step (a subtle "a little stronger" per level).
--
-- CombatEffects owns the shapes and timing of each technique (where parts go,
-- what moves); this module only finds, clones, steps, plays and cleans up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Techniques = require(ReplicatedStorage.Shared.Techniques)

local TechniqueVFX = {}

TechniqueVFX.STEP_COUNT = 0.2 -- extra EmitCount per level above the tier's first

type Api = {
	emit: (Instance) -> any,
	enable: (Instance) -> any,
	disable: (Instance) -> any,
	rescale: (Instance, number) -> (),
	maxLifetime: (Instance) -> number,
	destroyAfter: (Instance, number?, (() -> boolean)?) -> (),
}

-- The Game Module is plugin-owned and lives in the place file (inserted with the
-- plugin's code button), so it is looked up once rather than mapped by Rojo.
local api: Api? = nil
do
	local module = ReplicatedStorage:FindFirstChild("vfx")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			api = result :: any
		else
			warn("TechniqueVFX: ReplicatedStorage.vfx failed to load:", result)
		end
	else
		warn("TechniqueVFX: ReplicatedStorage.vfx (vfxia Game Module) is missing; technique effects play with plain emitters")
	end
end

-- Effects render only for this client.
TechniqueVFX.folder = workspace.CurrentCamera :: Instance

local function sampled(value: any): number
	if typeof(value) == "NumberRange" then
		return value.Min + math.random() * (value.Max - value.Min)
	end
	return if type(value) == "number" then value else 0
end

-- Nearest value of an Emit attribute from `inst` up to `root`.
local function inherited(inst: Instance, root: Instance, name: string): any
	local at: Instance? = inst
	while at do
		local v = at:GetAttribute(name)
		if v ~= nil then
			return v
		end
		if at == root then
			break
		end
		at = at.Parent
	end
	return nil
end

-- EmitDelay adds up down the tree (a delayed parent delays its descendants).
local function totalDelay(inst: Instance, root: Instance): number
	local sum = 0
	local at: Instance? = inst
	while at do
		sum += sampled(at:GetAttribute("EmitDelay"))
		if at == root then
			break
		end
		at = at.Parent
	end
	return sum
end

local LOOPED = { "ParticleEmitter", "Beam", "Trail", "PointLight", "SpotLight", "SurfaceLight" }
local function loops(d: Instance): boolean
	for _, class in LOOPED do
		if d:IsA(class) then
			return true
		end
	end
	return false
end

-- Plain-API stand-in used only while the Game Module is missing: Emit counts,
-- delays and EmitDuration windows. (No beam width tweens, repeats or add-ons.)
local function fallbackEmit(root: Instance)
	for _, d in root:GetDescendants() do
		if not loops(d) then
			continue
		end
		local delay = totalDelay(d, root)
		local duration = sampled(inherited(d, root, "EmitDuration"))
		task.delay(delay, function()
			if not d.Parent then
				return
			end
			if duration ~= 0 then
				(d :: any).Enabled = true
				if duration > 0 then
					task.delay(duration, function()
						(d :: any).Enabled = false
					end)
				end
			elseif d:IsA("ParticleEmitter") then
				d:Emit(math.max(1, math.round(sampled(inherited(d, root, "EmitCount") or 1))))
			end
		end)
	end
end

local function setEnabled(root: Instance, on: boolean)
	for _, d in root:GetDescendants() do
		if loops(d) then
			(d :: any).Enabled = on
		end
	end
end

function TechniqueVFX.emit(inst: Instance)
	if api then
		api.emit(inst)
	else
		fallbackEmit(inst)
	end
end

function TechniqueVFX.enable(inst: Instance)
	if api then
		api.enable(inst)
	else
		setEnabled(inst, true)
	end
end

function TechniqueVFX.disable(inst: Instance)
	if api then
		api.disable(inst)
	else
		setEnabled(inst, false)
	end
end

function TechniqueVFX.rescale(inst: Instance, scale: number)
	if api and math.abs(scale - 1) > 1e-3 then
		api.rescale(inst, scale)
	end
end

-- Destroy once everything it emitted has died (plus `extra` seconds).
function TechniqueVFX.cleanup(inst: Instance, extra: number?)
	local life = 2
	if api then
		local ok, value = pcall(api.maxLifetime, inst)
		if ok and type(value) == "number" then
			life = value
		end
	else
		for _, d in inst:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				life = math.max(life, totalDelay(d, inst) + d.Lifetime.Max)
			end
		end
	end
	task.delay(life + (extra or 0), function()
		inst:Destroy()
	end)
end

-- Fit authored timing to the live action timeline. Emitters whose `Phase`
-- attribute matches `phase` (or all emitters when `phase` is nil) get their
-- Lifetime and EmitDelay multiplied by `actual / authored`, where `authored`
-- is the seconds the template was timed for (e.g. its `AuthoredActive`
-- attribute) and `actual` comes from ActionRules.castProfile. Aftermath
-- emitters carry no Phase and keep their authored fade.
function TechniqueVFX.fit(inst: Instance, phase: string?, authored: number?, actual: number)
	if type(authored) ~= "number" or authored <= 0 or actual <= 0 then
		return
	end
	local k = actual / authored
	if math.abs(k - 1) < 1e-3 then
		return
	end
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if not d:IsA("ParticleEmitter") or (phase and d:GetAttribute("Phase") ~= phase) then
			continue
		end
		d.Lifetime = NumberRange.new(d.Lifetime.Min * k, d.Lifetime.Max * k)
		local delay = d:GetAttribute("EmitDelay")
		if type(delay) == "number" then
			d:SetAttribute("EmitDelay", delay * k)
		end
	end
end

-- The template for a technique at a level, or nil if it hasn't been authored.
function TechniqueVFX.template(id: string, level: number): (Instance?, number, number)
	local tier, step = Techniques.visualTier(level)
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local group = effects and effects:FindFirstChild(id)
	return group and group:FindFirstChild(`{id}_T{tier}`), tier, step
end

-- Multiply every numeric EmitCount by the level step.
local function stepCounts(root: Instance, step: number)
	if step <= 0 then
		return
	end
	local k = 1 + TechniqueVFX.STEP_COUNT * step
	for _, d in root:GetDescendants() do
		local count = d:GetAttribute("EmitCount")
		if type(count) == "number" then
			d:SetAttribute("EmitCount", math.round(count * k))
		elseif typeof(count) == "NumberRange" then
			d:SetAttribute("EmitCount", NumberRange.new(math.round(count.Min * k), math.round(count.Max * k)))
		end
	end
end

-- A positioned, stepped copy of the technique's tier template, parented to the
-- effects folder but not yet emitted. Returns nil when no template exists.
function TechniqueVFX.spawn(id: string, level: number, cframe: CFrame): (Model?, number)
	local template, tier, step = TechniqueVFX.template(id, level)
	if not (template and template:IsA("Model")) then
		return nil, tier
	end
	local copy = template:Clone()
	stepCounts(copy, step)
	copy:PivotTo(cframe)
	copy.Parent = TechniqueVFX.folder
	return copy, tier
end

-- A stepped copy of one named part of the tier template (e.g. "Windup"), placed
-- and parented but not emitted. Cheaper than spawning the whole template.
function TechniqueVFX.part(id: string, level: number, name: string, cframe: CFrame): BasePart?
	local template, _, step = TechniqueVFX.template(id, level)
	local source = template and template:FindFirstChild(name)
	if not (source and source:IsA("BasePart")) then
		return nil
	end
	local copy = source:Clone()
	stepCounts(copy, step)
	copy.CFrame = cframe
	copy.Parent = TechniqueVFX.folder
	return copy
end

-- Detach a named child part (e.g. "Impact") from a spawned copy so it can be
-- cloned per target instead of playing with the root.
function TechniqueVFX.take(copy: Instance, name: string): BasePart?
	local child = copy:FindFirstChild(name)
	if child and child:IsA("BasePart") then
		child.Parent = nil
		return child
	end
	return nil
end

-- Play a detached part at a CFrame (a copy of it), cleaning itself up.
function TechniqueVFX.burstAt(part: BasePart, cframe: CFrame): BasePart
	local copy = part:Clone()
	copy.CFrame = cframe
	copy.Parent = TechniqueVFX.folder
	TechniqueVFX.emit(copy)
	TechniqueVFX.cleanup(copy)
	return copy
end

return TechniqueVFX
