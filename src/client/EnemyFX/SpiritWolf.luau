--!strict
-- Spirit Wolf cues (EnemyFX): moonlight-qi attack, hit and death effects.
-- Templates: ReplicatedStorage.Effects.SpiritWolf (builder and layer notes in
-- tools/vfx_specs/SpiritWolf.luau). Record and cue contract in
-- docs/enemies/spirit-wolf.md, "Effects".
--
-- Attacks (cue.attack): bite, pounce, leap, howl, hop.
--   windup   every attack: eyes flare (red glint, then held glow for the
--            windup) and the crest's Tell strips brighten dim -> pale blue.
--            bite: breath wisp at the Mouth. pounce: moon motes gathering into
--            the chest, dust kick at the hind paws at 5/7 of the windup.
--            leap: a crescent moon turning inside the landing circle (over the
--            stock red telegraph) and a glint above the head as it rears.
--            howl: with Config.NEW_TELEGRAPHS (the stock ring is gone) the
--            roar (Impact.roar): sound rings and breath out of the jaws, dust
--            and grit blown forward off the ground, from 30% of the windup;
--            otherwise the old sound rings. Moon-glow on the crest either way.
--   strike   bite: fangs snap shut ahead of the muzzle. hop: paw dust.
--            pounce/leap: take-off (also from dash, whichever comes first).
--   dash     pounce/leap take-off: dust burst at the hind paws, moonlight
--            trail along the body (silver on the leap) until land.
--   land     pounce: skid dust. leap: shockwave, dust, chips, cracks, and a
--            light shake within 8 studs of the local player. hop: paw dust.
--   hit      on cue.target: bite/leap red-white sparks and ink; pounce claw rake.
--   stagger  white body flash, star pop, eyes flicker.
--   skid     pounceSkid / leapSkid (overshoot turn-around): dust sprayed from
--            all four planted paws over the turn (Impact.skid).
--   death    eyes fade (0.2 s), qi motes rise through the body's 1 s fade, a
--            gold-white spirit-core glint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local Config = require(ReplicatedStorage.Shared.Config)
local Impact = require(script.Parent.Impact)

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

local TELL_LIT = Color3.fromRGB(207, 230, 255)
local FLIGHT = { pounce = 0.3, leap = 0.45 } -- trail seconds when no land cue cuts it
local WINDUP = { bite = 0.45, pounce = 0.7, leap = 1.0, howl = 0.8 } -- if a cue has no seconds
local SHAKE_RADIUS = 8
local SHAKE = 0.22
local LEAP_TRAIL = Color3.fromRGB(232, 238, 248)

local SpiritWolf = {}

local function templates(): Instance?
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	return effects and effects:FindFirstChild("SpiritWolf")
end

-- Per-model state: the running trail, and when it last took off / landed (the
-- strike and dash cues both mean "take off", and a land can come both from the
-- dash ending and from the server).
type State = { trail: Instance?, tookOff: number, landed: number }
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any
-- the running trail's stop function, by its holder attachment
local stopTrail: { [Instance]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

local function state(model: Model): State
	local s = states[model]
	if not s then
		s = { trail = nil, tookOff = 0, landed = 0 }
		states[model] = s
	end
	return s
end

local function body(model: Model): Instance
	return model:FindFirstChild("Body") or model
end

local function bodyRoot(model: Model, cue: Cue): BasePart
	local b = body(model)
	local r = b:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else cue.root
end

-- World CFrame of a named attachment, else of a fallback part (with offset),
-- turned to face where the wolf faces.
local function point(model: Model, cue: Cue, attachment: string, parts: { string }, offset: Vector3?): CFrame
	local b = body(model)
	local facing = bodyRoot(model, cue).CFrame.Rotation
	local a = b:FindFirstChild(attachment, true)
	if a and a:IsA("Attachment") then
		return CFrame.new(a.WorldPosition) * facing
	end
	for _, name in parts do
		local p = b:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			return CFrame.new(p.CFrame:PointToWorldSpace(offset or Vector3.zero)) * facing
		end
	end
	local r = bodyRoot(model, cue)
	return r.CFrame * CFrame.new(offset or Vector3.zero)
end

local function partNamed(model: Model, names: { string }): BasePart?
	local b = body(model)
	for _, name in names do
		local p = b:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function eyes(model: Model): { BasePart }
	local list = {}
	for _, d in body(model):GetDescendants() do
		if d:IsA("BasePart") and (d.Name:gsub(" ", "")):match("^Eye[LR]$") then
			table.insert(list, d)
		end
	end
	return list
end

local function tells(model: Model): { BasePart }
	local list = {}
	for _, d in body(model):GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Tell") == true and not d.Name:match("^Eye") then
			table.insert(list, d)
		end
	end
	return list
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

-- Scale every emitter's timing (Lifetime, EmitDelay, EmitDuration) by k.
local function retime(inst: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.Lifetime = NumberRange.new(d.Lifetime.Min * k, d.Lifetime.Max * k)
			for _, name in { "EmitDelay", "EmitDuration" } do
				local v = d:GetAttribute(name)
				if type(v) == "number" and v > 0 then
					d:SetAttribute(name, v * k)
				end
			end
		end
	end
end

-- Scale every emitter's Size curve by k (the game module's rescale does more,
-- but is missing on the fallback path).
local function resize(inst: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local points = {}
			for _, p in d.Size.Keypoints do
				table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
			end
			d.Size = NumberSequence.new(points)
		end
	end
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

local function hindPaws(model: Model, cue: Cue): { CFrame }
	local list = {}
	for _, side in { "L", "R" } do
		local cf = point(model, cue, "PawB" .. side .. "_FX", { "FootB" .. side, "PawB" .. side }, Vector3.new(0, -0.2, 0))
		table.insert(list, CFrame.new(ground(cf.Position, model)) * cf.Rotation)
	end
	return list
end

local function pawDust(model: Model, cue: Cue)
	for _, cf in hindPaws(model, cue) do
		play("PawDust", cf + Vector3.new(0, 0.1, 0))
	end
end

-- The shared tell: eyes flare and hold, crest strips brighten over the windup.
local function tell(model: Model, seconds: number)
	for _, eye in eyes(model) do
		play("EyeGlint", eye.CFrame, eye, function(clone)
			local hold = clone:FindFirstChild("Hold")
			if hold then
				hold:SetAttribute("EmitDuration", math.max(0.1, seconds))
			end
		end)
	end
	for _, strip in tells(model) do
		local base = strip:GetAttribute("TellBase")
		if typeof(base) ~= "Color3" then
			base = strip.Color
			strip:SetAttribute("TellBase", base)
		end
		local dim = (base :: Color3):Lerp(Color3.new(0, 0, 0), 0.45)
		strip.Color = dim
		TweenService:Create(strip, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = TELL_LIT }):Play()
		task.delay(seconds + 0.2, function()
			if strip.Parent then
				TweenService:Create(strip, TweenInfo.new(0.4), { Color = base }):Play()
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
	local paws = hindPaws(model, cue)
	local mid = (paws[1].Position + paws[2].Position) / 2
	play("DashDust", CFrame.new(mid + Vector3.new(0, 0.1, 0)) * paws[1].Rotation)
	local chest = partNamed(model, { "Chest", "HumanoidRootPart" })
	if not chest then
		return
	end
	local folder = templates()
	local template = folder and folder:FindFirstChild("MoonTrail")
	if not template then
		return
	end
	-- the trail's attachments go on the chest (Top at the crest, Bottom at the belly)
	local clone = template:Clone()
	local holder = Instance.new("Attachment")
	holder.Name = "_WolfTrail"
	holder.Parent = chest
	local made: { Instance } = { holder }
	for _, a in clone:GetChildren() do
		if a:IsA("Attachment") then
			a.Parent = chest
			table.insert(made, a)
		end
	end
	for _, t in clone:GetChildren() do
		if t:IsA("Trail") then
			if cue.attack == "leap" and t.Name == "Bright" then
				t.Color = ColorSequence.new(Color3.new(1, 1, 1), LEAP_TRAIL)
			end
			t.Parent = chest
			t.Enabled = true
			table.insert(made, t)
		end
	end
	clone:Destroy()
	for _, d in made do
		for _, e in d:GetDescendants() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = true
			end
		end
	end
	s.trail = holder
	local function stop()
		if s.trail ~= holder then
			return
		end
		s.trail = nil
		for _, d in made do
			if d:IsA("Trail") then
				d.Enabled = false
			end
			for _, e in d:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Enabled = false
				end
			end
		end
		task.delay(0.6, function()
			for _, d in made do
				d:Destroy()
			end
		end)
	end
	holder.Destroying:Connect(stop)
	stopTrail[holder] = stop
	task.delay((FLIGHT[cue.attack or ""] or 0.3) + 0.15, stop)
end

function SpiritWolf.windup(cue: Cue)
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.5
	if attack == "leap" and cue.seconds then
		-- the leap's telegraph runs through the flight to touchdown; the windup is the rest
		seconds = math.max(0.05, seconds - FLIGHT.leap)
	end
	tell(model, seconds)
	if attack == "bite" then
		local skull = partNamed(model, { "Skull", "HumanoidRootPart" })
		play("Breath", point(model, cue, "Mouth", { "Snout", "Skull" }, Vector3.new(0, 0, -0.6)), skull, function(clone)
			for _, e in clone:GetChildren() do
				e:SetAttribute("EmitDuration", math.max(0.1, seconds - 0.05))
			end
		end)
	elseif attack == "pounce" then
		local chest = partNamed(model, { "Chest", "HumanoidRootPart" })
		play("Gather", point(model, cue, "Core", { "Chest" }), chest, function(clone)
			retime(clone, seconds / ((clone:GetAttribute("AuthoredSeconds") :: number?) or 0.7))
		end)
		task.delay(seconds * 5 / 7, function()
			if model.Parent and model:GetAttribute("AIState") == "windup" then
				pawDust(model, cue)
			end
		end)
	elseif attack == "leap" then
		local shape = cue.shape
		local center = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else nil
		if center then
			local radius = if type(shape.radius) == "number" then shape.radius else 5
			play("LeapSigil", CFrame.new(center) * bodyRoot(model, cue).CFrame.Rotation, nil, function(clone)
				retime(clone, (seconds + FLIGHT.leap) / ((clone:GetAttribute("AuthoredSeconds") :: number?) or 1.45))
				resize(clone, radius / ((clone:GetAttribute("AuthoredRadius") :: number?) or 5))
			end)
		end
		local skull = partNamed(model, { "Skull", "HumanoidRootPart" })
		if skull then
			play("LeapGlint", CFrame.new(skull.Position + Vector3.new(0, 1.6, 0)), skull)
		end
	elseif attack == "howl" then
		if (Config :: any).NEW_TELEGRAPHS then
			-- the roar: the head is up by ~30% of the windup, then it carries to the end
			task.delay(seconds * 0.3, function()
				if model.Parent and model:GetAttribute("AIState") == "windup" then
					local mouth = point(model, cue, "Mouth", { "Snout", "Skull" }, Vector3.new(0, 0, -0.6))
					-- out ahead of the wolf, tilted up with the raised head
					local look = bodyRoot(model, cue).CFrame.LookVector + Vector3.new(0, 0.3, 0)
					local from = mouth.Position
					Impact.roar(CFrame.lookAt(from, from + look), ground(from, model), { element = "moon", seconds = seconds * 0.7 })
				end
			end)
		else
			play("HowlRings", point(model, cue, "Mouth", { "Snout", "Skull" }, Vector3.new(0, 0, -0.6)))
		end
		local crest = partNamed(model, { "Crest", "ChestTop", "Chest" })
		if crest then
			play("CrestGlow", crest.CFrame, crest)
		end
	end
end

function SpiritWolf.strike(cue: Cue)
	local attack = cue.attack
	if attack == "bite" then
		play("FangSnap", point(cue.model, cue, "Mouth", { "Snout", "Skull" }, Vector3.new(0, 0, -0.6)))
	elseif attack == "hop" then
		pawDust(cue.model, cue)
	elseif attack == "pounce" or attack == "leap" then
		takeOff(cue)
	end
end

function SpiritWolf.dash(cue: Cue)
	if cue.attack == "pounce" or cue.attack == "leap" then
		takeOff(cue)
	end
end

function SpiritWolf.land(cue: Cue)
	local model = cue.model
	local s = state(model)
	local now = os.clock()
	if now - s.landed < 0.3 then
		return
	end
	s.landed = now
	if s.trail then
		local stop = stopTrail[s.trail]
		if stop then
			stop()
		end
	end
	local attack = cue.attack
	if attack == "leap" then
		local at = ground(point(model, cue, "Core", { "Chest" }).Position, model)
		play("Landing", CFrame.new(at + Vector3.new(0, 0.05, 0)))
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") and (hrp.Position - at).Magnitude <= SHAKE_RADIUS then
			local ok, CombatEffects = pcall(require, script.Parent.Parent.CombatEffects)
			if ok then
				(CombatEffects :: any).shake(SHAKE)
			end
		end
	elseif attack == "hop" then
		pawDust(model, cue)
	else
		-- a lunge skids to a stop at the front paws
		local front = point(model, cue, "Core", { "Chest" }, Vector3.zero)
		local facing = front.Rotation
		local at = ground(front.Position + facing.LookVector * 1.5, model)
		play("Skid", CFrame.new(at + Vector3.new(0, 0.1, 0)) * facing)
	end
end

-- An overshoot's skid-and-turn: all four paws plough dust ahead of the slide.
function SpiritWolf.skid(cue: Cue)
	local model = cue.model
	local feet = {}
	for _, cf in hindPaws(model, cue) do
		table.insert(feet, cf.Position)
	end
	for _, side in { "L", "R" } do
		local cf = point(model, cue, "PawF" .. side .. "_FX", { "FootF" .. side, "PawF" .. side }, Vector3.new(0, -0.2, 0))
		table.insert(feet, ground(cf.Position, model))
	end
	Impact.skid(feet, bodyRoot(model, cue).CFrame.LookVector, { element = "moon", scale = 0.7, seconds = 0.35 })
end

function SpiritWolf.hit(cue: Cue)
	local target = cue.target
	local part = target and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
	if not (part and part:IsA("BasePart")) then
		return
	end
	local wolf = bodyRoot(cue.model, cue).Position
	local toward = Vector3.new(wolf.X - part.Position.X, 0, wolf.Z - part.Position.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local at = part.Position + toward * 0.9
	-- -Z faces the wolf; the sprays go +Z, through the target
	local cframe = CFrame.lookAt(at, at + toward)
	play(if cue.attack == "pounce" then "ClawRake" else "BiteHit", cframe)
end

function SpiritWolf.stagger(cue: Cue)
	local model = cue.model
	local chest = partNamed(model, { "Chest", "HumanoidRootPart" })
	play("StaggerFlash", point(model, cue, "Core", { "Chest" }), chest)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = body(model)
	task.delay(0.08, function()
		highlight:Destroy()
	end)
	local list = eyes(model)
	for i = 1, 3 do
		task.delay((i - 1) * 0.1, function()
			for _, eye in list do
				eye.Transparency = 0.85
			end
			task.wait(0.05)
			for _, eye in list do
				if model:GetAttribute("FadeAt") == nil then
					eye.Transparency = 0
				end
			end
		end)
	end
end

function SpiritWolf.death(cue: Cue)
	local model = cue.model
	for _, eye in eyes(model) do
		TweenService:Create(eye, TweenInfo.new(0.2), { Transparency = 1, Color = Color3.new(0.2, 0.05, 0.05) }):Play()
	end
	play("Death", point(model, cue, "Core", { "Chest" }) * CFrame.new(0, 0, 0.5))
end

return SpiritWolf
