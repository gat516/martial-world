--!strict
-- Shared helpers for the sky-scale world effects (templates in
-- ReplicatedStorage.WorldFX, assets/WorldFX.rbxm, built by tools/worldfx_build.luau).
-- Pieces are cloned locally, placed upright, painted from a palette and animated
-- from the server clock, so every client sees the same phase.
--
-- Template contract:
--   * every template is a Model with PrimaryPart nil and an identity-rotation
--     WorldPivot at its ground (or anchor) point; Kit.place keeps that rotation
--   * anything with a `Tint` attribute ("core", "color", "accent", "dark") takes
--     that palette colour, mixed with white by `TintMix` (0..1, default 1)
--   * Beams keep their authored Width0/Width1 and Transparency; Kit.beam scales and
--     fades them from those
--   * parts or attachments with a `WorldY` attribute sit at that world height
--     (the cloud plane, the top of a pillar), not relative to the ground point

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = {}

export type Palette = { core: Color3, color: Color3, accent: Color3, dark: Color3 }

-- Where clones go (local to this client). Edit-mode previews point it at a
-- workspace folder, since screen captures swap the camera.
Kit.folder = workspace.CurrentCamera :: Instance
-- The template root; previews point it at the staging copy.
Kit.source = nil :: Instance?
-- Server clock; previews replace it with a fake one.
Kit.now = function(): number
	return workspace:GetServerTimeNow()
end

local WHITE = Color3.new(1, 1, 1)

function Kit.templates(): Instance?
	return Kit.source or ReplicatedStorage:FindFirstChild("WorldFX")
end

function Kit.template(name: string): Instance?
	local root = Kit.templates()
	return root and root:FindFirstChild(name)
end

function Kit.clone(name: string): Model?
	local t = Kit.template(name)
	if not (t and t:IsA("Model")) then
		warn(`WorldFX: no template {name}`)
		return nil
	end
	return t:Clone()
end

-- Place a clone at a ground point, keeping its template's pivot rotation (never a
-- bare CFrame.new(spot): AGENTS.md "Luau pitfalls"), plus a yaw.
function Kit.place(model: Model, spot: Vector3, yaw: number?)
	local rotation = model:GetPivot().Rotation
	model:PivotTo(CFrame.new(spot) * rotation * CFrame.Angles(0, yaw or 0, 0))
	for _, d in model:GetDescendants() do
		local worldY = d:GetAttribute("WorldY")
		if type(worldY) ~= "number" then
			continue
		end
		if d:IsA("Attachment") then
			local p = d.WorldPosition
			d.WorldPosition = Vector3.new(p.X, worldY, p.Z)
		elseif d:IsA("BasePart") then
			local cf = d.CFrame
			d.CFrame = cf + Vector3.new(0, worldY - cf.Position.Y, 0)
		end
	end
end

function Kit.paint(root: Instance, palette: Palette)
	for _, d in root:GetDescendants() do
		local which = d:GetAttribute("Tint")
		if type(which) ~= "string" then
			continue
		end
		local base = (palette :: any)[which]
		if typeof(base) ~= "Color3" then
			continue
		end
		local mix = d:GetAttribute("TintMix")
		local c = WHITE:Lerp(base, if type(mix) == "number" then mix else 1)
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Color = ColorSequence.new(c)
		elseif d:IsA("BasePart") then
			d.Color = c
		elseif d:IsA("SurfaceAppearance") then
			(d :: any).Color = c
		elseif d:IsA("Light") then
			d.Color = c
		elseif d:IsA("ImageLabel") then
			d.ImageColor3 = c
		end
	end
end

-- Beams: remember the authored widths and transparency once, then set them as a
-- multiple of that (width k, opacity alpha 0..1).
type BeamBase = { w0: number, w1: number, seq: NumberSequence, k: number, alpha: number }
local beamBase: { [Beam]: BeamBase } = setmetatable({}, { __mode = "k" }) :: any

local function fadedSeq(seq: NumberSequence, alpha: number): NumberSequence
	local kps = {}
	for _, kp in seq.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(kp.Time, 1 - (1 - kp.Value) * alpha, kp.Envelope))
	end
	return NumberSequence.new(kps)
end

function Kit.beam(beam: Beam, k: number, alpha: number)
	local b = beamBase[beam]
	if not b then
		b = { w0 = beam.Width0, w1 = beam.Width1, seq = beam.Transparency, k = 1, alpha = 1 }
		beamBase[beam] = b
	end
	if math.abs(b.k - k) > 1e-3 then
		b.k = k
		beam.Width0 = b.w0 * k
		beam.Width1 = b.w1 * k
	end
	if math.abs(b.alpha - alpha) > 4e-3 then
		b.alpha = alpha
		beam.Transparency = fadedSeq(b.seq, alpha)
	end
	beam.Enabled = alpha > 0.002 and k > 1e-3
end

-- Emitters: on/off plus a rate scale from the authored Rate.
local rateBase: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any
function Kit.rate(e: ParticleEmitter, scale: number)
	local base = rateBase[e]
	if not base then
		base = e.Rate
		rateBase[e] = base
	end
	e.Rate = base * scale
	e.Enabled = scale > 0
end

-- Emit a burst honouring EmitCount / EmitDelay (plugin attributes), so templates
-- stay plugin-compatible while the Game Module isn't in the place.
function Kit.emit(root: Instance)
	local list = if root:IsA("ParticleEmitter") then { root } else root:GetDescendants()
	for _, d in list do
		if d:IsA("ParticleEmitter") then
			local count = d:GetAttribute("EmitCount")
			local delay = d:GetAttribute("EmitDelay")
			local n = if type(count) == "number" then count else 10
			if type(delay) == "number" and delay > 0 then
				task.delay(delay, function()
					if d.Parent then
						d:Emit(n)
					end
				end)
			else
				d:Emit(n)
			end
		end
	end
end

function Kit.distance(at: Vector3): number
	local cam = workspace.CurrentCamera
	return if cam then (cam.CFrame.Position - at).Magnitude else 0
end

function Kit.clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function Kit.smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Kit.outQuad(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

function Kit.inQuad(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x
end

-- 1 inside `inner`, 0 past `outer`, smooth between.
function Kit.near(distance: number, inner: number, outer: number): number
	return 1 - Kit.smooth((distance - inner) / (outer - inner))
end

-- Batched moves: queue CFrames, flush once per frame (one BulkMoveTo).
local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}
function Kit.move(part: BasePart, cf: CFrame)
	table.insert(moveParts, part)
	table.insert(moveFrames, cf)
end
function Kit.flush()
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveFrames)
	end
end

return Kit
