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
-- Without it, shared.fx (the plugin's auto-initialized API) is used when
-- present, which is what Edit-mode previews run on. Add-ons (Craters,
-- SimpleMeshVFX, Splines, ScreenEffects) only play through one of the two.
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
	end
	if not api and type(shared.fx) == "table" and type(shared.fx.emit) == "function" then
		api = shared.fx
	end
	if not api then
		warn("TechniqueVFX: ReplicatedStorage.vfx (vfxia Game Module) is missing; technique effects play with plain emitters and no add-ons")
	end
end

-- True when effects play through the Game Module (add-ons, screen shake and
-- all); false on the plain-emitter fallback, where callers add their own shake.
TechniqueVFX.full = api ~= nil

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

-- Mesh waves: 3D shockwaves (torus rings, shells, bubbles) that grow and fade,
-- played here with or without the Game Module. A Model with `MeshWave = true`
-- holds one `Mesh` part (kept at Transparency 1 in the template). Attributes,
-- all optional; offsets are studs in the parent part's (or attachment's) space,
-- captured when the wave is emitted:
--   FromSize/ToSize (Vector3), FromOffset/ToOffset (Vector3), Rotation
--   (Vector3, degrees, applied to the mesh), FromTransparency/ToTransparency,
--   Duration (seconds), Style (an Enum.EasingStyle name for the motion, eased
--   Out, default "Quad"), FadeStyle (the fade's style, eased In, so the wave
--   holds solid and fades late; default "Quad"), and
--   the usual inherited EmitDelay. `Phase` lets fit() retime it.
-- It doesn't use Start/End names, so SimpleMeshVFX won't also play it.
local TweenService = game:GetService("TweenService")

-- Running wave tweens (each clone is destroyed when its tween completes), so
-- Edit-mode previews can Pause() them mid-flight for a capture.
TechniqueVFX.waves = {} :: { [Tween]: true }

local function playWaves(root: Instance)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		if not (d:IsA("Model") and d:GetAttribute("MeshWave")) then
			continue
		end
		local mesh = d:FindFirstChild("Mesh")
		local holder = d.Parent
		if not (mesh and mesh:IsA("BasePart") and holder) then
			continue
		end
		local base = if holder:IsA("Attachment") then holder.WorldCFrame elseif holder:IsA("BasePart") then holder.CFrame else nil
		if not base then
			continue
		end
		local rot = d:GetAttribute("Rotation")
		local turn = if typeof(rot) == "Vector3" then CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) else CFrame.identity
		local fromOffset = d:GetAttribute("FromOffset")
		local toOffset = d:GetAttribute("ToOffset")
		local from = base * CFrame.new(if typeof(fromOffset) == "Vector3" then fromOffset else Vector3.zero) * turn
		local to = base * CFrame.new(if typeof(toOffset) == "Vector3" then toOffset else Vector3.zero) * turn
		local fromSize = d:GetAttribute("FromSize")
		local toSize = d:GetAttribute("ToSize")
		local duration = sampled(d:GetAttribute("Duration"))
		local style = d:GetAttribute("Style")
		local easing = (Enum.EasingStyle :: any)[if type(style) == "string" then style else "Quad"] or Enum.EasingStyle.Quad
		local fadeStyle = d:GetAttribute("FadeStyle")
		local fadeEasing = (Enum.EasingStyle :: any)[if type(fadeStyle) == "string" then fadeStyle else "Quad"] or Enum.EasingStyle.Quad
		local fromT = d:GetAttribute("FromTransparency")
		local toT = d:GetAttribute("ToTransparency")
		-- cloned now: the template copy may be cleaned up before a delayed wave plays
		local m = mesh:Clone()
		task.delay(totalDelay(d, root), function()
			m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
			m.CFrame = from
			if typeof(fromSize) == "Vector3" then
				m.Size = fromSize
			end
			m.Transparency = if type(fromT) == "number" then fromT else 0
			m.Parent = TechniqueVFX.folder
			local seconds = if duration > 0 then duration else 0.2
			-- motion bursts out (Style, Out); the fade eases in (FadeStyle, In) so
			-- the wave stays solid while it grows and dies away at the end
			local tween = TweenService:Create(m, TweenInfo.new(seconds, easing, Enum.EasingDirection.Out), {
				CFrame = to,
				Size = if typeof(toSize) == "Vector3" then toSize else m.Size,
			})
			local fade = TweenService:Create(m, TweenInfo.new(seconds, fadeEasing, Enum.EasingDirection.In), {
				Transparency = if type(toT) == "number" then toT else 1,
			})
			TechniqueVFX.waves[tween] = true
			TechniqueVFX.waves[fade] = true
			tween.Completed:Once(function()
				TechniqueVFX.waves[tween] = nil
				TechniqueVFX.waves[fade] = nil
				m:Destroy()
			end)
			tween:Play()
			fade:Play()
		end)
	end
end

function TechniqueVFX.emit(inst: Instance)
	if api then
		api.emit(inst)
	else
		fallbackEmit(inst)
	end
	playWaves(inst)
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
		if phase and d:GetAttribute("Phase") ~= phase then
			continue
		end
		if d:IsA("Model") and d:GetAttribute("MeshWave") then
			local duration = d:GetAttribute("Duration")
			if type(duration) == "number" then
				d:SetAttribute("Duration", duration * k)
			end
			local delay = d:GetAttribute("EmitDelay")
			if type(delay) == "number" then
				d:SetAttribute("EmitDelay", delay * k)
			end
			continue
		end
		if not d:IsA("ParticleEmitter") then
			continue
		end
		d.Lifetime = NumberRange.new(d.Lifetime.Min * k, d.Lifetime.Max * k)
		local delay = d:GetAttribute("EmitDelay")
		if type(delay) == "number" then
			d:SetAttribute("EmitDelay", delay * k)
		end
		-- a stream that runs for the authored phase runs for the real one
		local duration = d:GetAttribute("EmitDuration")
		if type(duration) == "number" and duration > 0 then
			d:SetAttribute("EmitDuration", duration * k)
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

-- Multiply every numeric EmitCount (and Craters Count) by the level step.
local function stepCounts(root: Instance, step: number)
	if step <= 0 then
		return
	end
	local k = 1 + TechniqueVFX.STEP_COUNT * step
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		-- EmitCount for emitters and meshes, Count for Craters rocks
		for _, name in { "EmitCount", "Count" } do
			local count = d:GetAttribute(name)
			if type(count) == "number" then
				d:SetAttribute(name, math.round(count * k))
			elseif typeof(count) == "NumberRange" then
				d:SetAttribute(name, NumberRange.new(math.round(count.Min * k), math.round(count.Max * k)))
			end
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
	-- `Charge` is the anticipation along the held weapon, played at cast start
	-- by CombatEffects.windup (WeaponFX.charge); the release never plays it
	local charge = copy:FindFirstChild("Charge")
	if charge then
		charge:Destroy()
	end
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
