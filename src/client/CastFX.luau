--!strict
-- Shared runtime helpers for technique effects, used by CombatEffects for every
-- cast (the caster's own and the ones relayed to observers go through the same
-- code). Templates and tiers live in TechniqueVFX; this module answers where
-- and when: the striking limb, the ground under a point, which enemies a shape
-- covers and where its front meets each one, and the cast's phase timings.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.ActionRules)
local Hitbox = require(ReplicatedStorage.Shared.Hitbox)
local Techniques = require(ReplicatedStorage.Shared.Techniques)
local TechniqueVFX = require(script.Parent.TechniqueVFX)

local CastFX = {}

-- Phase timings of a cast, from the same timeline Combat uses
-- (ActionRules.castProfile): windup is cast start -> Hit, active Hit -> Hit
-- Stop, recovery after that. CombatEffects.cast runs at Hit.
export type Phases = { windup: number, active: number, recovery: number, speed: number }
function CastFX.phases(def: Techniques.Def): Phases
	local p = Rules.castProfile(def)
	return { windup = p.windup, active = p.active, recovery = p.recovery, speed = p.speed }
end

-- Ground rays skip effects, every player character and every enemy: callers
-- pass root or body positions, and a ray from there would otherwise land on
-- the caster's (or target's) own body and put the effect at torso height.
-- The filter is rebuilt at most twice a second (markTarget calls this per frame).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local groundFilterAt = -math.huge
local function groundFilter(): RaycastParams
	local now = os.clock()
	if now - groundFilterAt > 0.5 then
		groundFilterAt = now
		local list: { Instance } = { workspace.CurrentCamera, TechniqueVFX.folder }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		for _, enemy in CollectionService:GetTagged("Enemy") do
			table.insert(list, enemy)
		end
		groundParams.FilterDescendantsInstances = list
	end
	return groundParams
end

-- Ground height under a point (falls back to 3 studs below it).
function CastFX.groundBelow(position: Vector3): number
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -24, 0), groundFilter())
	return if hit then hit.Position.Y + 0.1 else position.Y - 3
end

-- The point on the ground under a position.
function CastFX.groundAt(position: Vector3): Vector3
	return Vector3.new(position.X, CastFX.groundBelow(position), position.Z)
end

-- Where a character's hand is right now (the palm/fist end), for effects that
-- come from the striking limb (`def.hand`, "Left" or "Right"). R15: the hand's
-- grip attachment; R6: the far end of the arm. nil if there's no such limb.
function CastFX.handPosition(character: Model?, side: string?): Vector3?
	if not (character and side) then
		return nil
	end
	local hand = character:FindFirstChild(side .. "Hand")
	if hand and hand:IsA("BasePart") then
		local grip = hand:FindFirstChild(side .. "GripAttachment")
		return if grip and grip:IsA("Attachment") then grip.WorldPosition else hand.Position
	end
	local arm = character:FindFirstChild(side .. " Arm")
	if arm and arm:IsA("BasePart") then
		return (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)).Position
	end
	return nil
end

function CastFX.nearCamera(position: Vector3, studs: number): boolean
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude <= studs
end

-- Seconds into a monotonic curve (a NumberSequence over `lifetime` seconds)
-- until it reaches `frac` of its final value. For a flat ring emitter whose
-- Size is its radius, that's when the front reaches `frac` of the radius; any
-- other growing curve (a line front's progress, a zone's spread) works too.
function CastFX.curveTime(curve: NumberSequence, lifetime: number, frac: number): number
	local kps = curve.Keypoints
	local final = kps[#kps].Value
	local want = frac * final
	for i = 2, #kps do
		local a, b = kps[i - 1], kps[i]
		if want <= b.Value then
			local t = (want - a.Value) / math.max(b.Value - a.Value, 1e-3)
			return (a.Time + (b.Time - a.Time) * math.clamp(t, 0, 1)) * lifetime
		end
	end
	return lifetime
end

-- curveTime for an emitter's Size over its (maximum) lifetime.
function CastFX.frontTime(emitter: ParticleEmitter, frac: number): number
	return CastFX.curveTime(emitter.Size, emitter.Lifetime.Max, frac)
end

-- Craters' rays skip players but not beasts; keep rocks off them (client-only tag).
function CastFX.keepCratersOffEnemies()
	for _, enemy in CollectionService:GetTagged("Enemy") do
		enemy:AddTag("CraterIgnore")
	end
end

-- One enemy a shape covers.
--   point    ground point on the target's near side, where the front meets it
--   toward   flat direction the front travels there (impacts face it)
--   height   studs from `point` up to the target's centre (body bursts)
--   progress 0..1 along the shape (radius or length) to `point`, for timing
--   index    1-based order of arrival
export type Target = { model: Model, point: Vector3, toward: Vector3, height: number, progress: number, index: number }

export type ShapeOpts = {
	kind: string, -- "circle" (centre = origin), "zone" (centre given), "line"
	origin: Vector3,
	center: Vector3?, -- zone centre (defaults to origin)
	dir: Vector3?, -- line direction (flat)
	radius: number?,
	length: number?,
	width: number?,
	character: Model?, -- excluded from the query
	cap: number?, -- most targets returned (default 6)
	slack: number?, -- studs added to the shape edge (default 1.5)
}

function CastFX.targets(opts: ShapeOpts): { Target }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { TechniqueVFX.folder, opts.character :: Instance? }
	local slack = opts.slack or 1.5
	local cap = opts.cap or 6
	local found: { Target } = {}
	local cframe, size, centre
	if opts.kind == "line" then
		local dir = opts.dir :: Vector3
		local length = opts.length :: number
		cframe = CFrame.lookAt(opts.origin, opts.origin + dir) * CFrame.new(0, 0, -length / 2)
		size = Vector3.new((opts.width :: number) + slack * 2, 16, length + slack)
		centre = opts.origin
	else
		centre = opts.center or opts.origin
		local r = (opts.radius :: number) * 2 + 2
		cframe, size = CFrame.new(centre), Vector3.new(r, 16, r)
	end
	local flatCentre = Vector3.new(centre.X, 0, centre.Z)
	for _, model in Hitbox.enemiesIn(cframe, size, params, centre) do
		local cf, box = model:GetBoundingBox()
		local p = cf.Position
		local depth = math.min(box.X, box.Z) * 0.4
		local toward, near, extent, at
		if opts.kind == "line" then
			local dir = opts.dir :: Vector3
			local along = (Vector3.new(p.X, 0, p.Z) - flatCentre):Dot(dir)
			extent = opts.length :: number
			if along < -slack or along > extent + slack then
				continue
			end
			toward = dir
			near = math.max(along - depth, 0)
			at = Vector3.new(p.X, 0, p.Z) - dir * depth
		else
			local flat = Vector3.new(p.X, 0, p.Z) - flatCentre
			local distance = flat.Magnitude
			extent = opts.radius :: number
			if distance > extent + slack then
				continue
			end
			toward = if distance > 0.01 then flat.Unit else (opts.dir or Vector3.zAxis)
			near = math.max(distance - depth, 1)
			at = flatCentre + toward * near
		end
		local feet = Vector3.new(at.X, CastFX.groundBelow(Vector3.new(at.X, p.Y, at.Z)) + 0.15, at.Z)
		table.insert(found, {
			model = model,
			point = feet,
			toward = toward,
			height = math.max(p.Y - feet.Y, 1),
			progress = math.clamp(near / extent, 0, 1),
			index = 0,
		})
	end
	table.sort(found, function(a, b)
		return a.progress < b.progress
	end)
	local out = {}
	for i, t in found do
		if i > cap then
			break
		end
		t.index = i
		table.insert(out, t)
	end
	return out
end

-- Play a tier template's detached Impact part on a target: at its near-side
-- ground point facing the front, with the `Body` attachment raised to its
-- centre. `limits` drops named children past an arrival index, e.g.
-- { Kick = 3, Quake = 1 } keeps rock kicks on the first three targets and the
-- quake on the first only.
function CastFX.impactAt(impact: BasePart, target: Target, limits: { [string]: number }?): BasePart
	local source = impact:Clone()
	for name, last in limits or {} do
		if target.index > last then
			local child = source:FindFirstChild(name)
			if child then
				child:Destroy()
			end
		end
	end
	-- raise Body before emitting: MeshWaves read their holder's WorldCFrame the
	-- moment they're emitted, so raising it afterwards left the 3D impact rings
	-- at the template's authored height instead of the target's centre
	local body = source:FindFirstChild("Body")
	if body and body:IsA("Attachment") then
		body.Position = Vector3.new(0, target.height, 0)
	end
	local burst = TechniqueVFX.burstAt(source, CFrame.lookAt(target.point, target.point + target.toward))
	source:Destroy()
	return burst
end

return CastFX
