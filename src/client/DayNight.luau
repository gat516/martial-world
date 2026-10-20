--!strict
-- Day and night. The hour comes from the server clock (GetServerTimeNow), so every
-- client sees the same sky without any replication. Lighting, atmosphere and color
-- grading blend between keyframes: an indigo, moonlit night; a rose dawn; the
-- place's own clear afternoon; a gold-and-crimson sunset; a violet dusk.
-- Lanterns glow brighter after dark, and motes drift around the camera: peach
-- petals by day, fireflies and spirit motes by night.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Ambience

local DayNight = {}

type Key = {
	hour: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	atmoColor: Color3,
	atmoDecay: Color3,
	density: number,
	haze: number,
	tint: Color3,
	bloom: number,
	sunRays: number,
	night: number, -- 0 day .. 1 night, for lanterns and motes
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Keyframes around the clock (hours). The afternoon key matches the place's
-- hand-tuned lighting.
local KEYS: { Key } = {
	{ hour = 0, brightness = 1.1, ambient = rgb(38, 44, 82), outdoor = rgb(66, 78, 132), atmoColor = rgb(58, 66, 120), atmoDecay = rgb(36, 36, 88), density = 0.32, haze = 1.6, tint = rgb(186, 198, 255), bloom = 1.25, sunRays = 0, night = 1 },
	{ hour = 4.8, brightness = 1.2, ambient = rgb(50, 50, 92), outdoor = rgb(90, 90, 150), atmoColor = rgb(96, 92, 150), atmoDecay = rgb(70, 56, 120), density = 0.31, haze = 1.5, tint = rgb(205, 205, 255), bloom = 1.2, sunRays = 0, night = 0.9 },
	{ hour = 6, brightness = 1.8, ambient = rgb(92, 72, 92), outdoor = rgb(176, 134, 146), atmoColor = rgb(255, 192, 176), atmoDecay = rgb(204, 120, 146), density = 0.28, haze = 1.2, tint = rgb(255, 226, 216), bloom = 1.05, sunRays = 0.18, night = 0.35 },
	{ hour = 8.5, brightness = 2.6, ambient = rgb(76, 74, 80), outdoor = rgb(138, 134, 128), atmoColor = rgb(214, 224, 234), atmoDecay = rgb(150, 160, 180), density = 0.24, haze = 0.7, tint = rgb(255, 250, 244), bloom = 0.9, sunRays = 0.1, night = 0 },
	{ hour = 16.6, brightness = 2.8, ambient = rgb(76, 74, 80), outdoor = rgb(138, 134, 128), atmoColor = rgb(214, 224, 234), atmoDecay = rgb(150, 160, 180), density = 0.24, haze = 0.7, tint = rgb(255, 250, 244), bloom = 0.9, sunRays = 0.1, night = 0 },
	{ hour = 18.2, brightness = 2.0, ambient = rgb(104, 72, 70), outdoor = rgb(194, 132, 110), atmoColor = rgb(255, 172, 120), atmoDecay = rgb(196, 92, 112), density = 0.27, haze = 1.3, tint = rgb(255, 220, 190), bloom = 1.0, sunRays = 0.22, night = 0.15 },
	{ hour = 19.6, brightness = 1.4, ambient = rgb(62, 56, 92), outdoor = rgb(104, 96, 152), atmoColor = rgb(124, 110, 172), atmoDecay = rgb(74, 60, 124), density = 0.3, haze = 1.4, tint = rgb(212, 206, 255), bloom = 1.15, sunRays = 0.05, night = 0.7 },
	{ hour = 24, brightness = 1.1, ambient = rgb(38, 44, 82), outdoor = rgb(66, 78, 132), atmoColor = rgb(58, 66, 120), atmoDecay = rgb(36, 36, 88), density = 0.32, haze = 1.6, tint = rgb(186, 198, 255), bloom = 1.25, sunRays = 0, night = 1 },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Smoothstep between keys, so transitions ease in and out.
local function sample(hour: number): Key
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if hour >= a.hour and hour <= b.hour then
			local t = (hour - a.hour) / (b.hour - a.hour)
			t = t * t * (3 - 2 * t)
			return {
				hour = hour,
				brightness = lerp(a.brightness, b.brightness, t),
				ambient = a.ambient:Lerp(b.ambient, t),
				outdoor = a.outdoor:Lerp(b.outdoor, t),
				atmoColor = a.atmoColor:Lerp(b.atmoColor, t),
				atmoDecay = a.atmoDecay:Lerp(b.atmoDecay, t),
				density = lerp(a.density, b.density, t),
				haze = lerp(a.haze, b.haze, t),
				tint = a.tint:Lerp(b.tint, t),
				bloom = lerp(a.bloom, b.bloom, t),
				sunRays = lerp(a.sunRays, b.sunRays, t),
				night = lerp(a.night, b.night, t),
			}
		end
	end
	return KEYS[1]
end

function DayNight.hour(): number
	local day = Config.DAY_MINUTES * 60
	return (Config.START_HOUR + (workspace:GetServerTimeNow() % day) / day * 24) % 24
end

-- Lantern lights in the map remember their authored brightness and scale with night.
local lanterns: { { light: Light, base: number } } = {}
local function collectLanterns()
	local map = workspace:FindFirstChild("Map")
	local ambience = map and map:FindFirstChild("Ambience", true)
	if not ambience then
		return
	end
	for _, d in ambience:GetDescendants() do
		if d:IsA("Light") then
			table.insert(lanterns, { light = d, base = d.Brightness })
		end
	end
	ambience.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("Light") then
			table.insert(lanterns, { light = d, base = d.Brightness })
		end
	end)
end

function DayNight.init()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	collectLanterns()

	local motes = (ReplicatedStorage:WaitForChild("Ambience") :: Folder):WaitForChild("AmbientMotes") :: BasePart
	motes = motes:Clone()
	motes.Parent = workspace.CurrentCamera
	local fireflies = motes:FindFirstChild("Fireflies") :: ParticleEmitter
	local petals = motes:FindFirstChild("Petals") :: ParticleEmitter

	local lastNight = -1
	RunService.RenderStepped:Connect(function()
		local hour = DayNight.hour()
		local k = sample(hour)
		Lighting.ClockTime = hour
		Lighting.Brightness = k.brightness
		Lighting.Ambient = k.ambient
		Lighting.OutdoorAmbient = k.outdoor
		if atmosphere then
			atmosphere.Color = k.atmoColor
			atmosphere.Decay = k.atmoDecay
			atmosphere.Density = k.density
			atmosphere.Haze = k.haze
		end
		if grade then
			grade.TintColor = k.tint
		end
		if bloom then
			bloom.Intensity = k.bloom
		end
		if rays then
			rays.Intensity = k.sunRays
		end

		-- motes follow the camera, a little ahead of it
		local camera = workspace.CurrentCamera
		motes.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 20)

		-- lanterns and motes only need updating as night deepens
		local night = math.floor(k.night * 20 + 0.5) / 20
		if night ~= lastNight then
			lastNight = night
			local scale = lerp(Config.DAY_LIGHT_SCALE, Config.NIGHT_LIGHT_SCALE, night)
			for _, l in lanterns do
				l.light.Brightness = l.base * scale
			end
			fireflies.Rate = Config.FIREFLY_RATE * night
			petals.Rate = Config.PETAL_RATE * (1 - night)
		end
	end)
end

return DayNight
