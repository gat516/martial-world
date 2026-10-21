--!strict
-- Stone Boar cues (EnemyFX): earth-qi attack, hit and death effects.
-- Templates: ReplicatedStorage.Effects.StoneBoar (builder and layer notes in
-- tools/vfx_specs/StoneBoar.luau). Record and cue contract in
-- docs/systems/enemies.md, "Stone Boar effects".
--
-- Only the reworked body (Template attribute "StoneBoarB") plays these; the
-- old StoneBoar has none of the parts they hang on.
--
-- Attacks (cue.attack): charge, gore.
--   windup   both: amber eye glint at t = 0; every Tell part (cracks, eyes)
--            brightens dim -> hot amber over the windup and settles back
--            0.2 s after. charge: hoof-scrape dust at HoofFL_FX at 0.2 and
--            0.55 of the windup (the second only while still winding up), a
--            snort from the nose at 0.8. gore: an amber glint on each tusk.
--   strike   charge: take-off (as dash; whichever comes first). gore: the
--            upward hooking crescent ahead of the tusks (0.15 s).
--   dash     charge: dust burst at the hind hooves, a low dust and stone-chip
--            trail under the body until land (or 0.55 s).
--   land     charge: skid dust thrown forward with chips.
--   hit      on cue.target: charge dust, chips, amber flash (+ a light shake
--            when it is the local character); gore sparks and a crescent mark.
--   stagger  stone chips pop off the chest, the cracks flicker.
--   death    cracks and eyes fade (0.3 s), the body crumbles into dust and
--            amber motes through the 1 s fade, a spirit-core glint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)

type Cue = {
	model: Model,
	root: BasePart,
	kind: string,
	attack: string?,
	shape: any?,
	seconds: number?,
	target: Model?,
	at: number,
}

local TEMPLATE = "StoneBoarB"
local TELL_LIT = Color3.fromRGB(255, 196, 120) -- amber run hot
local TELL_DEAD = Color3.fromRGB(44, 46, 52)
local WINDUP = { charge = 1.0, gore = 0.6 } -- if a cue has no seconds
local CHARGE = 0.55 -- trail seconds when no land cue cuts it
local HIT_SHAKE = 0.3
local TUSK_SPREAD = 1.15 -- each tusk point sits this far either side of TuskTip
local HOOK_AHEAD = 4.5

local StoneBoar = {}

local function templates(): Instance?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	return effects and effects:FindFirstChild("StoneBoar")
end

local function ours(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

-- Per-model state: the running trail's stop function, and when it last took
-- off / landed (strike and dash both mean "take off"; a land can come twice).
type State = { stop: (() -> ())?, tookOff: number, landed: number }
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function state(model: Model): State
	local s = states[model]
	if not s then
		s = { stop = nil, tookOff = 0, landed = 0 }
		states[model] = s
	end
	return s
end

local function body(model: Model): Instance
	return model:FindFirstChild("Body") or model
end

local function bodyRoot(model: Model, cue: Cue): BasePart
	local r = body(model):FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else cue.root
end

local function partNamed(model: Model, name: string): BasePart?
	local p = body(model):FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function attachmentNamed(model: Model, name: string): Attachment?
	local a = body(model):FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a else nil
end

-- World CFrame of an attachment (else a part, else the root), facing the boar's way.
local function point(model: Model, cue: Cue, attachment: string, part: string): CFrame
	local facing = bodyRoot(model, cue).CFrame.Rotation
	local a = attachmentNamed(model, attachment)
	if a then
		return CFrame.new(a.WorldPosition) * facing
	end
	local p = partNamed(model, part)
	if p then
		return CFrame.new(p.Position) * facing
	end
	return bodyRoot(model, cue).CFrame
end

local function tells(model: Model): { BasePart }
	local list = {}
	for _, d in body(model):GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Tell") == true then
			table.insert(list, d)
		end
	end
	return list
end

local function baseColor(part: BasePart): Color3
	local base = part:GetAttribute("TellBase")
	if typeof(base) ~= "Color3" then
		base = part.Color
		part:SetAttribute("TellBase", base)
	end
	return base :: Color3
end

local function ground(position: Vector3, model: Model): Vector3
	local params = RaycastParams.new()
	local exclude: { Instance } = { model, workspace.CurrentCamera }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), params)
	return if hit then hit.Position else position
end

-- Clone a template to `cframe`. With `follow`, it rides that part (offset kept)
-- until it is cleaned up. `prepare` edits the clone before it plays.
local function play(name: string, cframe: CFrame, follow: BasePart?, prepare: ((Instance) -> ())?): Instance?
	local folder = templates()
	local template = folder and folder:FindFirstChild(name)
	if not (template and template:IsA("BasePart")) then
		return nil
	end
	local clone = template:Clone()
	clone.CFrame = cframe
	if prepare then
		prepare(clone)
	end
	clone.Parent = TechniqueVFX.folder
	if follow then
		local offset = follow.CFrame:ToObjectSpace(cframe)
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if not clone.Parent or not follow.Parent then
				connection:Disconnect()
				return
			end
			clone.CFrame = follow.CFrame * offset
		end)
	end
	TechniqueVFX.emit(clone)
	TechniqueVFX.cleanup(clone, 0.2)
	return clone
end

local function hoofScrape(model: Model, cue: Cue)
	local cf = point(model, cue, "HoofFL_FX", "HoofFL")
	play("HoofScrape", CFrame.new(ground(cf.Position, model) + Vector3.new(0, 0.1, 0)) * cf.Rotation)
end

local function tell(model: Model, seconds: number)
	for _, name in { "EyeL", "EyeR" } do
		local eye = partNamed(model, name)
		if eye then
			play("EyeGlint", eye.CFrame, eye)
		end
	end
	for _, part in tells(model) do
		local base = baseColor(part)
		part.Color = base:Lerp(Color3.new(0, 0, 0), 0.5)
		TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = TELL_LIT })
			:Play()
		task.delay(seconds + 0.2, function()
			if part.Parent and model:GetAttribute("FadeAt") == nil then
				TweenService:Create(part, TweenInfo.new(0.4), { Color = base }):Play()
			end
		end)
	end
end

local function takeOff(cue: Cue)
	local model = cue.model
	local s = state(model)
	local now = os.clock()
	if now - s.tookOff < 0.25 then
		return
	end
	s.tookOff = now
	local root = bodyRoot(model, cue)
	local facing = root.CFrame.Rotation
	local hind = {}
	for _, name in { "HoofBL", "HoofBR" } do
		local p = partNamed(model, name)
		if p then
			table.insert(hind, p.Position)
		end
	end
	local mid = if #hind == 2 then (hind[1] + hind[2]) / 2 else root.CFrame:PointToWorldSpace(Vector3.new(0, -2.6, 2))
	play("DashDust", CFrame.new(ground(mid, model) + Vector3.new(0, 0.1, 0)) * facing)

	-- the trail rides under the body at hoof level; its particles stay in the
	-- world, so they hang behind the charge
	local folder = templates()
	local template = folder and folder:FindFirstChild("ChargeTrail")
	if not (template and template:IsA("BasePart")) then
		return
	end
	local clone = template:Clone()
	local offset = CFrame.new(0, -(root.Size.Y / 2 + 1.4), 0.5)
	clone.CFrame = root.CFrame * offset
	clone.Parent = TechniqueVFX.folder
	local emitters = {}
	for _, e in clone:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			e.Enabled = true
			table.insert(emitters, e)
		end
	end
	local connection = RunService.RenderStepped:Connect(function()
		if root.Parent then
			clone.CFrame = root.CFrame * offset
		end
	end)
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if s.stop == stop then
			s.stop = nil
		end
		connection:Disconnect()
		for _, e in emitters do
			e.Enabled = false
		end
		task.delay(1, function()
			clone:Destroy()
		end)
	end
	s.stop = stop
	task.delay(CHARGE + 0.1, stop)
end

function StoneBoar.windup(cue: Cue)
	if not ours(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = math.max(0.05, cue.seconds or WINDUP[attack] or 0.6)
	tell(model, seconds)
	if attack == "charge" then
		task.delay(seconds * 0.2, function()
			if model.Parent then
				hoofScrape(model, cue)
			end
		end)
		task.delay(seconds * 0.55, function()
			if model.Parent and model:GetAttribute("AIState") == "windup" then
				hoofScrape(model, cue)
			end
		end)
		task.delay(seconds * 0.8, function()
			local nose = partNamed(model, "NosePad") or partNamed(model, "Snout")
			if model.Parent and nose and model:GetAttribute("AIState") == "windup" then
				local facing = bodyRoot(model, cue).CFrame.Rotation
				play("Snort", CFrame.new(nose.Position) * facing + facing.LookVector * 0.3, nose)
			end
		end)
	elseif attack == "gore" then
		local tip = attachmentNamed(model, "TuskTip")
		local head = partNamed(model, "Head")
		if tip and head then
			for _, side in { -1, 1 } do
				local at = tip.WorldCFrame * CFrame.new(side * TUSK_SPREAD, 0, 0)
				play("TuskGlint", CFrame.new(at.Position), head)
			end
		end
	end
end

function StoneBoar.strike(cue: Cue)
	if not ours(cue) then
		return
	end
	if cue.attack == "charge" then
		takeOff(cue)
	elseif cue.attack == "gore" then
		local model = cue.model
		local tip = point(model, cue, "TuskTip", "Head")
		local at = tip.Position + tip.LookVector * HOOK_AHEAD - Vector3.new(0, 1, 0)
		play("GoreHook", CFrame.new(at) * tip.Rotation)
	end
end

function StoneBoar.dash(cue: Cue)
	if ours(cue) and cue.attack == "charge" then
		takeOff(cue)
	end
end

function StoneBoar.land(cue: Cue)
	if not ours(cue) or cue.attack ~= "charge" then
		return
	end
	local model = cue.model
	local s = state(model)
	local now = os.clock()
	if now - s.landed < 0.3 then
		return
	end
	s.landed = now
	if s.stop then
		s.stop()
	end
	local a = point(model, cue, "HoofFL_FX", "HoofFL")
	local b = point(model, cue, "HoofFR_FX", "HoofFR")
	local facing = a.Rotation
	local at = ground((a.Position + b.Position) / 2 + facing.LookVector * 1.2, model)
	play("Skid", CFrame.new(at + Vector3.new(0, 0.1, 0)) * facing)
end

function StoneBoar.hit(cue: Cue)
	if not ours(cue) then
		return
	end
	local target = cue.target
	local part = target
		and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
	if not (part and part:IsA("BasePart")) then
		return
	end
	local boar = bodyRoot(cue.model, cue).Position
	local toward = Vector3.new(boar.X - part.Position.X, 0, boar.Z - part.Position.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local at = part.Position + toward * 0.9
	-- -Z faces the boar; the sprays go +Z, through the target
	local cframe = CFrame.lookAt(at, at + toward)
	if cue.attack == "charge" then
		play("ChargeHit", cframe)
		if Players.LocalPlayer and target == Players.LocalPlayer.Character then
			local ok, CombatEffects = pcall(require, script.Parent.Parent.CombatEffects)
			if ok then
				(CombatEffects :: any).shake(HIT_SHAKE)
			end
		end
	else
		play("GoreHit", cframe)
	end
end

function StoneBoar.stagger(cue: Cue)
	if not ours(cue) then
		return
	end
	local model = cue.model
	play("StaggerChips", point(model, cue, "Core", "Chest"), partNamed(model, "Chest"))
	local list = tells(model)
	for i = 1, 3 do
		task.delay((i - 1) * 0.1, function()
			for _, p in list do
				p.Transparency = 0.85
			end
			task.wait(0.05)
			for _, p in list do
				if model:GetAttribute("FadeAt") == nil then
					p.Transparency = 0
				end
			end
		end)
	end
end

function StoneBoar.death(cue: Cue)
	if not ours(cue) then
		return
	end
	local model = cue.model
	local s = state(model)
	if s.stop then
		s.stop()
	end
	for _, p in tells(model) do
		TweenService:Create(p, TweenInfo.new(0.3), { Color = TELL_DEAD }):Play()
	end
	play("Death", point(model, cue, "Core", "Chest") * CFrame.new(0, 0, 0.8))
end

return StoneBoar
