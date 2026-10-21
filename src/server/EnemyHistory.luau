--!strict
-- Where each enemy was over the last moments, for lag compensation. A player
-- with high ping swings at the beast they see, which is where it was a little
-- while ago on the server (client prediction narrows that gap but can't close
-- it). Combat checks a swing against the enemy's position now and, failing
-- that, where it was at the swing's timestamp, rewound at most
-- Config.Combat.REWIND seconds. That cap is the cheating budget: a forged
-- timestamp can only reach where the beast really stood in that window, and
-- still only inside the attacker's own hitbox.
--
-- EnemyService records each live enemy every AI tick and forgets it on removal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Combat

type Sample = { t: number, position: Vector3 }
type Track = { samples: { Sample }, radius: number, height: number }

local tracks: { [Model]: Track } = {}

local EnemyHistory = {}

-- Start tracking; `radius` and `height` are half the model's footprint and height.
function EnemyHistory.track(model: Model, radius: number, height: number)
	tracks[model] = { samples = {}, radius = radius, height = height }
end

function EnemyHistory.forget(model: Model)
	tracks[model] = nil
end

function EnemyHistory.record(model: Model, position: Vector3, now: number)
	local track = tracks[model]
	if not track then
		return
	end
	local samples = track.samples
	table.insert(samples, { t = now, position = position })
	-- keep a little past the rewind window so the oldest query can interpolate
	while #samples > 2 and now - samples[2].t > Config.REWIND + 0.2 do
		table.remove(samples, 1)
	end
end

-- Root position at server time `t` (clamped into the rewind window), or nil.
function EnemyHistory.at(model: Model, t: number, now: number): Vector3?
	local track = tracks[model]
	if not track or #track.samples == 0 then
		return nil
	end
	t = math.clamp(t, now - Config.REWIND, now)
	local samples = track.samples
	if t <= samples[1].t then
		return samples[1].position
	end
	for i = #samples, 2, -1 do
		local a, b = samples[i - 1], samples[i]
		if t >= a.t then
			local span = b.t - a.t
			return if span > 0 then a.position:Lerp(b.position, math.clamp((t - a.t) / span, 0, 1)) else b.position
		end
	end
	return samples[#samples].position
end

-- Was the enemy's body inside the box (centred `cframe`, `size`) at time `t`?
function EnemyHistory.wasIn(model: Model, cframe: CFrame, size: Vector3, t: number, now: number): boolean
	local track = tracks[model]
	local position = EnemyHistory.at(model, t, now)
	if not (track and position) then
		return false
	end
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 + track.radius
		and math.abs(p.Z) <= size.Z / 2 + track.radius
		and math.abs(p.Y) <= size.Y / 2 + track.height
end

return EnemyHistory
