--!strict
-- The world reacting to world events and sky anomalies, blended with the day and
-- night cycle. DayNight samples its hourly keyframe, lets WeatherFX.adjust lean it,
-- then calls SkyGrade.adjust(k), which applies every active contribution on top. So
-- DayNight still owns the per-hour Lighting values; events only offset and lerp its
-- keyframe, exactly like weather does.
--
-- A contribution (SkyGrade.set(key, c)) is a table with a `weight` (0..1, the
-- caller fades it with its phase and camera distance) and any of:
--   tint / tintMix          colour-grade tint and how far to lean toward it
--   atmoColor / atmoMix     Atmosphere colour and how far
--   densityCap / hazeCap    clear the sky: Atmosphere density/haze no higher than this
--                           (far-read test 2026-10-21: at the default 0.36 / 1.8 haze a
--                           pillar 1000 studs off loses all colour; at 0.28 / 1.0 it
--                           reads, day and night)
--   brightness              Lighting brightness multiplier
--   exposure, saturation, contrast   added
-- Pulses (white flashes, impact frames) go on our own ColorCorrectionEffect (a clone of
-- ReplicatedStorage.WorldFX.Grade in Lighting), never on DayNight's grade.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Contribution = {
	weight: number,
	tint: Color3?,
	tintMix: number?,
	atmoColor: Color3?,
	atmoMix: number?,
	densityCap: number?,
	hazeCap: number?,
	brightness: number?,
	exposure: number?,
	saturation: number?,
	contrast: number?,
}

export type Pulse = {
	tint: Color3?, -- grade tint at the peak (default white)
	brightness: number?, -- added at the peak
	contrast: number?,
	saturation: number?,
	attack: number?, -- seconds to the peak
	hold: number?,
	decay: number?,
}

local SkyGrade = {}

local active: { [string]: Contribution } = {}

function SkyGrade.set(key: string, c: Contribution)
	active[key] = c
end

function SkyGrade.clear(key: string)
	active[key] = nil
end

local function lean(value: number, cap: number?, w: number): number
	if cap == nil or value <= cap then
		return value
	end
	return value + (cap - value) * w
end

-- Lean a DayNight keyframe (mutates it). Called by DayNight every frame after
-- WeatherFX.adjust.
function SkyGrade.adjust(k: any)
	for _, c in active do
		local w = math.clamp(c.weight, 0, 1)
		if w <= 0 then
			continue
		end
		if c.tint then
			k.tint = k.tint:Lerp(c.tint, w * (c.tintMix or 0.6))
		end
		if c.atmoColor then
			k.atmoColor = k.atmoColor:Lerp(c.atmoColor, w * (c.atmoMix or 0.6))
		end
		k.density = lean(k.density, c.densityCap, w)
		k.haze = lean(k.haze, c.hazeCap, w)
		if c.brightness then
			k.brightness *= 1 + (c.brightness - 1) * w
		end
		if c.exposure then
			k.exposure += c.exposure * w
		end
		if c.saturation then
			k.saturation += c.saturation * w
		end
		if c.contrast then
			k.contrast += c.contrast * w
		end
	end
end

-- Pulses on our own ColorCorrectionEffect.
type Live = { p: Pulse, start: number }
local pulses: { Live } = {}
local grade: ColorCorrectionEffect? = nil

function SkyGrade.pulse(p: Pulse)
	table.insert(pulses, { p = p, start = os.clock() })
end

local function envelope(live: Live, now: number): number
	local p = live.p
	local attack, hold, decay = p.attack or 0.08, p.hold or 0.05, p.decay or 0.6
	local t = now - live.start
	if t < attack then
		return t / attack
	elseif t < attack + hold then
		return 1
	end
	return math.max(0, 1 - (t - attack - hold) / decay)
end

function SkyGrade.init()
	local templates = ReplicatedStorage:FindFirstChild("WorldFX")
	local template = templates and templates:FindFirstChild("Grade")
	if template and template:IsA("ColorCorrectionEffect") then
		local g = template:Clone()
		g.Name = "WorldFXGrade"
		g.Enabled = false
		g.Parent = Lighting
		grade = g
	end
	RunService.RenderStepped:Connect(function()
		local g = grade
		if not g then
			return
		end
		if #pulses == 0 then
			if g.Enabled then
				g.Enabled = false
			end
			return
		end
		local now = os.clock()
		local tint, bright, contrast, sat = Color3.new(1, 1, 1), 0, 0, 0
		for i = #pulses, 1, -1 do
			local live = pulses[i]
			local e = envelope(live, now)
			local p = live.p
			if e <= 0 and now - live.start > 0.1 then
				table.remove(pulses, i)
				continue
			end
			tint = tint:Lerp(p.tint or tint, e)
			bright = math.max(bright, (p.brightness or 0) * e)
			contrast += (p.contrast or 0) * e
			sat += (p.saturation or 0) * e
		end
		g.Enabled = true
		g.TintColor = tint
		g.Brightness = bright
		g.Contrast = contrast
		g.Saturation = sat
	end)
end

return SkyGrade
