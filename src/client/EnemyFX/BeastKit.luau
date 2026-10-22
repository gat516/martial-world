--!strict
-- Shared helpers for the regular beasts' EnemyFX handlers (VenomSerpent,
-- StoneTortoise, ShadowManeWolf): template playback, body lookups by attachment
-- name (tolerating a missing one), the dim-to-bright Tell strips. Not a beast
-- (no EnemyType is named BeastKit). Templates live in
-- ReplicatedStorage.Effects.<group>, built by tools/vfx_specs/<group>.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TechniqueVFX = require(script.Parent.Parent.TechniqueVFX)
local Impact = require(script.Parent.Impact)

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

local Kit = {}

function Kit.new(group: string)
	local K = {}

	local function folder(): Instance?
		local effects = ReplicatedStorage:FindFirstChild("Effects")
		return effects and effects:FindFirstChild(group)
	end

	function K.template(name: string): BasePart?
		local f = folder()
		local t = f and f:FindFirstChild(name)
		return if t and t:IsA("BasePart") then t else nil
	end

	-- The Attachment of that name (a part may share the name, e.g. TongueTip).
	function K.attachment(model: Instance, name: string): Attachment?
		for _, d in model:GetDescendants() do
			if d.Name == name and d:IsA("Attachment") then
				return d
			end
		end
		return nil
	end

	-- The world CFrame of a named attachment (any depth), else of the first
	-- fallback part (with offset), else the root; rotated to the root's facing.
	function K.point(cue: Cue, attachment: string, parts: { string }?, offset: Vector3?): CFrame
		local facing = cue.root.CFrame.Rotation
		local a = K.attachment(cue.model, attachment)
		if a then
			return CFrame.new(a.WorldPosition) * facing
		end
		for _, name in parts or {} do
			local p = cue.model:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				return CFrame.new(p.CFrame:PointToWorldSpace(offset or Vector3.zero)) * facing
			end
		end
		return cue.root.CFrame * CFrame.new(offset or Vector3.zero)
	end

	-- The part holding a named attachment, else the first named part, else the root.
	function K.host(cue: Cue, attachment: string?, parts: { string }?): BasePart
		if attachment then
			local a = K.attachment(cue.model, attachment)
			if a and a.Parent and a.Parent:IsA("BasePart") then
				return a.Parent
			end
		end
		for _, name in parts or {} do
			local p = cue.model:FindFirstChild(name, true)
			if p and p:IsA("BasePart") then
				return p
			end
		end
		return cue.root
	end

	function K.eyes(model: Model): { BasePart }
		local list = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and (d.Name:gsub(" ", "")):match("^Eye[LR]$") then
				table.insert(list, d)
			end
		end
		return list
	end

	-- Parts by name pattern (e.g. "^SeamTell").
	function K.named(model: Model, pattern: string): { BasePart }
		local list = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name:match(pattern) then
				table.insert(list, d)
			end
		end
		return list
	end

	function K.tells(model: Model): { BasePart }
		local list = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Tell") == true and not d.Name:match("^Eye") then
				table.insert(list, d)
			end
		end
		return list
	end

	function K.ground(position: Vector3, model: Model): Vector3
		local params = RaycastParams.new()
		local exclude: { Instance } = { model, workspace.CurrentCamera :: Instance }
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

	-- Scale every emitter's timing by k.
	function K.retime(inst: Instance, k: number)
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

	-- Set EmitDuration on every Rate emitter under `inst` (the windup's length).
	function K.duration(inst: Instance, seconds: number)
		for _, d in inst:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Rate > 0 then
				d:SetAttribute("EmitDuration", math.max(0.1, seconds))
			end
		end
	end

	-- Scale every emitter's Size by k.
	function K.resize(inst: Instance, k: number)
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

	-- Clone a template to `cframe`; with `follow` it rides that part (offset kept).
	function K.play(name: string, cframe: CFrame, follow: BasePart?, prepare: ((BasePart) -> ())?): BasePart?
		local template = K.template(name)
		if not template then
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

	-- The dim-then-bright Tell strips (TellBase keeps the authored colour) and
	-- the eye star + held glow. Strips go back 0.2 s after the windup.
	function K.tell(model: Model, seconds: number, lit: Color3, brow: BasePart?, eyeList: { BasePart }?, sweep: boolean?)
		for _, eye in eyeList or K.eyes(model) do
			K.play("EyeGlint", eye.CFrame, eye, function(clone)
				K.duration(clone, seconds)
			end)
		end
		if brow then
			K.play("EyeGlint", brow.CFrame, brow, function(clone)
				K.duration(clone, seconds)
			end)
		end
		local strips = K.tells(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if sweep and root and root:IsA("BasePart") then
			-- light them front to back across the first 60% of the windup
			table.sort(strips, function(a, b)
				return root.CFrame:PointToObjectSpace(a.Position).Z < root.CFrame:PointToObjectSpace(b.Position).Z
			end)
		end
		for i, strip in strips do
			local base = strip:GetAttribute("TellBase")
			if typeof(base) ~= "Color3" then
				base = strip.Color
				strip:SetAttribute("TellBase", base)
			end
			strip.Color = (base :: Color3):Lerp(Color3.new(0, 0, 0), 0.45)
			local delay = if sweep then (i - 1) / math.max(1, #strips) * seconds * 0.6 else 0
			local length = math.max(0.05, seconds - delay)
			task.delay(delay, function()
				if strip.Parent then
					TweenService:Create(strip, TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = lit }):Play()
				end
			end)
			task.delay(seconds + 0.2, function()
				if strip.Parent and strip:GetAttribute("TellHold") ~= true then
					TweenService:Create(strip, TweenInfo.new(0.4), { Color = base :: Color3 }):Play()
				end
			end)
		end
	end

	-- A hit on cue.target's torso: the point just on the beast's side, and a CFrame
	-- with -Z toward the beast (the sprays go +Z, through the target).
	function K.hitFrame(cue: Cue): (CFrame?, BasePart?)
		local target = cue.target
		local part = target and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
		if not (part and part:IsA("BasePart")) then
			return nil, nil
		end
		local from = cue.root.Position
		local toward = Vector3.new(from.X - part.Position.X, 0, from.Z - part.Position.Z)
		toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
		local at = part.Position + toward * 0.9
		return CFrame.lookAt(at, at + toward), part
	end

	-- A brief white body flash.
	function K.flash(model: Model, seconds: number?)
		local h = Instance.new("Highlight")
		h.FillColor = Color3.new(1, 1, 1)
		h.FillTransparency = 0.3
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
		task.delay(seconds or 0.08, function()
			h:Destroy()
		end)
	end

	-- Flicker the eyes (stagger).
	function K.flicker(model: Model)
		local list = K.eyes(model)
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

	-- Fade the eyes out (death).
	function K.eyesOut(model: Model, color: Color3)
		for _, eye in K.eyes(model) do
			TweenService:Create(eye, TweenInfo.new(0.2), { Transparency = 1, Color = color }):Play()
		end
	end

	-- Beams from a template Part (its Beam children get the attachments): held
	-- `seconds`, then fade out over 0.15 s. `tweak` edits the clone first.
	function K.beam(name: string, a0: Attachment, a1: Attachment, seconds: number, tweak: ((BasePart) -> ())?): BasePart?
		local template = K.template(name)
		if not template then
			return nil
		end
		local clone = template:Clone()
		if tweak then
			tweak(clone)
		end
		clone.Parent = TechniqueVFX.folder
		for _, b in clone:GetChildren() do
			if b:IsA("Beam") then
				b.Attachment0, b.Attachment1 = a0, a1
				b.Enabled = true
			end
		end
		task.delay(seconds, function()
			for _, b in clone:GetChildren() do
				if b:IsA("Beam") then
					TweenService:Create(b, TweenInfo.new(0.15), { Width0 = 0, Width1 = 0 }):Play()
				end
			end
			task.delay(0.2, function()
				clone:Destroy()
			end)
		end)
		return clone
	end

	-- A temporary anchored attachment at a world position (for a beam end),
	-- gone after `seconds`.
	function K.anchorAt(position: Vector3, seconds: number): Attachment
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.one * 0.2
		p.Position = position
		p.Parent = TechniqueVFX.folder
		local a = Instance.new("Attachment")
		a.Parent = p
		task.delay(seconds, function()
			p:Destroy()
		end)
		return a
	end

	-- A lobbed shot (Impact.shot) from `from` to `to` over `seconds` with an arc
	-- of `height`; `onLand(position)` fires at the end (the shot has stopped).
	function K.lob(from: Vector3, to: Vector3, seconds: number, height: number, shotOptions: any, onLand: ((Vector3) -> ())?)
		local shot = Impact.shot(shotOptions)
		local t0 = os.clock()
		local previous = from
		local connection
		connection = RunService.RenderStepped:Connect(function(dt)
			local u = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local position = from:Lerp(to, u) + Vector3.new(0, height * math.sin(math.pi * u), 0)
			if shot then
				shot.move(position, (position - previous) / math.max(dt, 1 / 120))
			end
			previous = position
			if u >= 1 then
				connection:Disconnect()
				if shot then
					shot.stop()
				end
				if onLand then
					onLand(to)
				end
			end
		end)
	end

	-- Torso of a Character (or nil).
	function K.torso(target: Model?): BasePart?
		local part = target and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart"))
		return if part and part:IsA("BasePart") then part else nil
	end

	return K
end

return Kit
