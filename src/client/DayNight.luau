--!strict
-- Day and night. The hour comes from the server clock (GetServerTimeNow), so every
-- client sees the same sky without any replication. Lighting, atmosphere and color
-- grading blend between keyframes: an indigo, moonlit night; a rose dawn; a soft
-- warm day with blue distance haze; a golden sunset; a violet dusk. This owns the
-- per-hour Lighting values (brightness, exposure, ambients, ColorShift_Top, Atmosphere,
-- grade tint/saturation/contrast, bloom and sun-ray intensity, and a multiplier on the
-- place's environment scales); the rest (shadows, bloom size/threshold, Sky) stays as
-- set in the place.
-- Lamps glow brighter and reach further after dark, and motes drift around the camera: peach
-- petals by day, fireflies and spirit motes by night. Weather events lean the
-- look through WeatherFX.adjust, then world events through WorldFX.SkyGrade.adjust.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config).Ambience
local WeatherFX = require(script.Parent.WeatherFX)
local SkyGrade = require(script.Parent.WorldFX.SkyGrade)

local DayNight = {}

type Key = {
	hour: number,
	brightness: number,
	exposure: number, -- ExposureCompensation: lifts the night so dim phones still read it
	ambient: Color3,
	outdoor: Color3,
	shift: Color3, -- ColorShift_Top: the sun or moon's tint on lit faces
	atmoColor: Color3,
	atmoDecay: Color3,
	density: number,
	offset: number,
	haze: number,
	glare: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	bloom: number,
	sunRays: number,
	sky: number, -- multiplier on the place's EnvironmentDiffuse/SpecularScale
	night: number, -- 0 day .. 1 night, for lanterns and motes
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Keyframes around the clock (hours). Day is soft and warm with cool shadows and
-- blue distance haze over the cloud sea; dusk goes gold, then violet; night is a
-- desaturated indigo with enough moonlit fill to read paths on a dim phone, so
-- lanterns and jade lamps carry the colour. Saturation sits a little below zero
-- all day: the place's parts are bright, and the grade calms them. A low night
-- Atmosphere offset keeps the (daytime) skybox hidden behind the dark haze.
-- Sky light (the environment scales) fades out at night: the engine refreshes it in
-- steps as the clock turns, and against the dim night ambient each step showed as
-- the scene pulsing darker and lighter. Night fill comes from the ambients instead.
local NIGHT: Key = { hour = 0, brightness = 1.5, exposure = 0.4, ambient = rgb(80, 88, 126), outdoor = rgb(110, 120, 164), shift = rgb(18, 26, 56), atmoColor = rgb(50, 60, 104), atmoDecay = rgb(28, 32, 76), density = 0.36, offset = 0.04, haze = 1.6, glare = 0, tint = rgb(204, 212, 255), saturation = -0.2, contrast = 0.06, bloom = 0.85, sunRays = 0, sky = 0, night = 1 }
local DAY: Key = { hour = 8.5, brightness = 2.5, exposure = 0, ambient = rgb(96, 96, 106), outdoor = rgb(140, 142, 152), shift = rgb(46, 32, 10), atmoColor = rgb(216, 224, 230), atmoDecay = rgb(160, 176, 198), density = 0.36, offset = 0.25, haze = 1.8, glare = 0.3, tint = rgb(255, 249, 240), saturation = -0.12, contrast = 0.1, bloom = 0.45, sunRays = 0.08, sky = 1, night = 0 }

local function at(hour: number, base: Key, changes: { [string]: any }): Key
	local k = table.clone(base) :: any
	for name, value in changes do
		k[name] = value
	end
	k.hour = hour
	return k
end

local KEYS: { Key } = {
	NIGHT,
	at(4.8, NIGHT, { brightness = 1.3, ambient = rgb(66, 62, 102), outdoor = rgb(108, 104, 156), shift = rgb(30, 20, 50), atmoColor = rgb(96, 90, 148), atmoDecay = rgb(66, 54, 116), haze = 1.7, tint = rgb(216, 212, 255), saturation = -0.16, night = 0.9 }),
	at(6, DAY, { brightness = 1.8, ambient = rgb(100, 80, 96), outdoor = rgb(168, 132, 142), shift = rgb(90, 46, 30), atmoColor = rgb(250, 194, 180), atmoDecay = rgb(196, 122, 146), density = 0.35, haze = 1.9, glare = 0.6, tint = rgb(255, 228, 218), saturation = -0.08, bloom = 0.7, sunRays = 0.16, night = 0.35 }),
	DAY,
	at(16.4, DAY, { brightness = 2.6, shift = rgb(60, 40, 12) }),
	-- golden hour while the sun is still up (it sets near 18:00), then an afterglow
	at(17.4, DAY, { brightness = 2.2, ambient = rgb(112, 88, 80), outdoor = rgb(170, 132, 112), shift = rgb(130, 72, 16), atmoColor = rgb(255, 196, 140), atmoDecay = rgb(200, 120, 110), offset = 0.2, glare = 1, tint = rgb(255, 226, 192), saturation = -0.02, contrast = 0.12, bloom = 0.6, sunRays = 0.25, night = 0.05 }),
	at(18.4, DAY, { brightness = 1.5, exposure = 0.15, ambient = rgb(104, 82, 104), outdoor = rgb(160, 122, 146), shift = rgb(60, 30, 40), atmoColor = rgb(226, 150, 140), atmoDecay = rgb(140, 80, 130), offset = 0.12, haze = 1.9, glare = 0.5, tint = rgb(255, 214, 214), saturation = -0.06, contrast = 0.12, bloom = 0.7, sunRays = 0.06, night = 0.35 }),
	at(19.6, NIGHT, { brightness = 1.3, ambient = rgb(70, 64, 104), outdoor = rgb(110, 102, 154), shift = rgb(40, 22, 44), atmoColor = rgb(118, 106, 168), atmoDecay = rgb(70, 58, 124), haze = 1.9, glare = 0.2, tint = rgb(216, 208, 255), saturation = -0.14, bloom = 0.75, sunRays = 0.04, night = 0.7 }),
	at(24, NIGHT, {}),
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
				exposure = lerp(a.exposure, b.exposure, t),
				ambient = a.ambient:Lerp(b.ambient, t),
				outdoor = a.outdoor:Lerp(b.outdoor, t),
				shift = a.shift:Lerp(b.shift, t),
				atmoColor = a.atmoColor:Lerp(b.atmoColor, t),
				atmoDecay = a.atmoDecay:Lerp(b.atmoDecay, t),
				density = lerp(a.density, b.density, t),
				offset = lerp(a.offset, b.offset, t),
				haze = lerp(a.haze, b.haze, t),
				glare = lerp(a.glare, b.glare, t),
				tint = a.tint:Lerp(b.tint, t),
				saturation = lerp(a.saturation, b.saturation, t),
				contrast = lerp(a.contrast, b.contrast, t),
				bloom = lerp(a.bloom, b.bloom, t),
				sunRays = lerp(a.sunRays, b.sunRays, t),
				sky = lerp(a.sky, b.sky, t),
				night = lerp(a.night, b.night, t),
			}
		end
	end
	return table.clone(KEYS[1])
end

DayNight.sample = sample

function DayNight.hour(): number
	local day = Config.DAY_MINUTES * 60
	return (Config.START_HOUR + (workspace:GetServerTimeNow() % day) / day * 24) % 24
end

-- Lamps remember their authored brightness and range and scale with night: every
-- light under Map's Ambience folder, plus lights inside lamp models anywhere in
-- the map (Config.Ambience.LAMP_MODELS: the placed lanterns, jade lamps and
-- braziers, and the lamps players build on their peaks).
type Lamp = { light: Light, base: number, range: number }
local lamps: { Lamp } = {}
local lampModels: { [string]: boolean } = {}
for _, name in Config.LAMP_MODELS do
	lampModels[name] = true
end

local function isLamp(light: Instance, ambience: Instance?): boolean
	if ambience and light:IsDescendantOf(ambience) then
		return true
	end
	local model = light:FindFirstAncestorWhichIsA("Model")
	return model ~= nil and lampModels[model.Name] == true
end

local function scaleLamp(l: Lamp, night: number)
	l.light.Brightness = l.base * lerp(Config.DAY_LIGHT_SCALE, Config.NIGHT_LIGHT_SCALE, night)
	if l.range > 0 then
		local light: any = l.light
		light.Range = math.min(60, l.range * lerp(1, Config.NIGHT_RANGE_SCALE, night))
	end
end

local lastNight = -1
local function collectLamps()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local ambience = map:FindFirstChild("Ambience", true)
	local function add(d: Instance)
		if d:IsA("Light") and isLamp(d, ambience) then
			local light = d :: Light
			local range = if light:IsA("PointLight") or light:IsA("SpotLight") then (light :: any).Range else 0
			local l = { light = light, base = light.Brightness, range = range }
			table.insert(lamps, l)
			if lastNight >= 0 then
				scaleLamp(l, lastNight)
			end
		end
	end
	for _, d in map:GetDescendants() do
		add(d)
	end
	map.DescendantAdded:Connect(function(d: Instance)
		-- a light's model may finish parenting after the light itself
		if d:IsA("Light") then
			task.defer(add, d)
		end
	end)
end

-- Placed ambient effects (the ServerStorage.AmbientFX templates: fireflies,
-- spirit motes, lantern halos and flicker) tag their emitters NightFX. Like the
-- lamps, each remembers its authored Rate and scales with night, between its
-- DayScale (default 0) and NightScale (default 1) attributes.
local nightFX: { [ParticleEmitter]: number } = {}

local function scaleNightFX(emitter: ParticleEmitter, base: number, night: number)
	local day = emitter:GetAttribute("DayScale")
	local full = emitter:GetAttribute("NightScale")
	emitter.Rate = base * lerp(if type(day) == "number" then day else 0, if type(full) == "number" then full else 1, night)
end

local function collectNightFX()
	local function add(inst: Instance)
		if inst:IsA("ParticleEmitter") and not nightFX[inst] then
			nightFX[inst] = inst.Rate
			if lastNight >= 0 then
				scaleNightFX(inst, inst.Rate, lastNight)
			end
		end
	end
	for _, inst in CollectionService:GetTagged("NightFX") do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("NightFX"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("NightFX"):Connect(function(inst: Instance)
		nightFX[inst :: ParticleEmitter] = nil
	end)
end

function DayNight.init()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	local envDiffuse, envSpecular = Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale
	collectLamps()
	collectNightFX()

	local motes = (ReplicatedStorage:WaitForChild("Ambience") :: Folder):WaitForChild("AmbientMotes") :: BasePart
	motes = motes:Clone()
	motes.Parent = workspace.CurrentCamera
	local fireflies = motes:FindFirstChild("Fireflies") :: ParticleEmitter
	local petals = motes:FindFirstChild("Petals") :: ParticleEmitter

	RunService.RenderStepped:Connect(function()
		local hour = DayNight.hour()
		local k = sample(hour)
		WeatherFX.adjust(k)
		SkyGrade.adjust(k) -- world events and anomalies lean it after the weather
		Lighting.ClockTime = hour
		Lighting.Brightness = k.brightness
		Lighting.ExposureCompensation = k.exposure
		Lighting.Ambient = k.ambient
		Lighting.OutdoorAmbient = k.outdoor
		Lighting.ColorShift_Top = k.shift
		Lighting.EnvironmentDiffuseScale = envDiffuse * k.sky
		Lighting.EnvironmentSpecularScale = envSpecular * k.sky
		if atmosphere then
			atmosphere.Color = k.atmoColor
			atmosphere.Decay = k.atmoDecay
			atmosphere.Density = k.density
			atmosphere.Offset = k.offset
			atmosphere.Haze = k.haze
			atmosphere.Glare = k.glare
		end
		if grade then
			grade.TintColor = k.tint
			grade.Saturation = k.saturation
			grade.Contrast = k.contrast
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

		-- lamps and motes only need updating as night deepens
		local night = math.floor(k.night * 20 + 0.5) / 20
		if night ~= lastNight then
			lastNight = night
			for _, l in lamps do
				scaleLamp(l, night)
			end
			for emitter, base in nightFX do
				scaleNightFX(emitter, base, night)
			end
			fireflies.Rate = Config.FIREFLY_RATE * night
			petals.Rate = Config.PETAL_RATE * (1 - night)
		end
	end)
end

return DayNight
