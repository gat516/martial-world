--!strict
-- Draws the server's weather event (workspace attributes Weather / WeatherEnds):
-- rain, wind streaks and violet mist around the camera, distant lightning with
-- thunder flashes, and rainbow aurora ribbons across the sky. Lighting changes are
-- applied through WeatherFX.adjust, which DayNight calls on its keyframe each
-- frame, so weather leans the day/night look instead of replacing it.
-- Every event fades in and out over Weather.FADE_SECONDS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Weather = require(ReplicatedStorage.Shared.Weather)
local CombatEffects = require(script.Parent.CombatEffects)

local WeatherFX = {}

local AURORA_COLORS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 200, 120),
	Color3.fromRGB(150, 255, 170),
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(190, 140, 255),
}

-- The event being shown and how strongly (0..1, fading).
local shown: Weather.Def = Weather.Defs.Clear
local strength = 0
local flash = 0 -- thunder flash, decays quickly

-- Blend the current weather into a DayNight keyframe (mutates it).
function WeatherFX.adjust(k: any)
	local def, s = shown, strength
	if s > 0 then
		k.brightness *= 1 + ((def.brightness or 1) - 1) * s
		k.density += (def.density or 0) * s
		k.haze += (def.haze or 0) * s
		if def.tint then
			k.tint = k.tint:Lerp(def.tint, s * 0.8)
		end
		if def.atmoColor then
			k.atmoColor = k.atmoColor:Lerp(def.atmoColor, s * 0.7)
		end
	end
	if flash > 0 then
		k.brightness += flash * 4
	end
end

local aurora: { BasePart } = {}
local function showAurora(on: boolean)
	if on and #aurora == 0 then
		local camera = workspace.CurrentCamera
		local center = Vector3.new(camera.CFrame.Position.X, 0, camera.CFrame.Position.Z)
		for i, color in AURORA_COLORS do
			-- long curved bands made of tilted slabs, stacked like a rainbow
			for j = -6, 6 do
				local a = math.rad(j * 9)
				local radius = 700 + i * 26
				local p = Instance.new("Part")
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Material = Enum.Material.Neon
				p.Color = color
				p.Size = Vector3.new(radius * math.rad(9) + 4, 18, 1)
				p.CFrame = CFrame.new(center + Vector3.new(math.sin(a) * radius, 520 + math.cos(a) * 260 - 260, -900))
					* CFrame.Angles(0, 0, -a)
				p.Transparency = 1
				p.Parent = camera
				TweenService:Create(p, TweenInfo.new(Weather.FADE_SECONDS), { Transparency = 0.72 }):Play()
				table.insert(aurora, p)
			end
		end
	elseif not on and #aurora > 0 then
		for _, p in aurora do
			TweenService:Create(p, TweenInfo.new(Weather.FADE_SECONDS), { Transparency = 1 }):Play()
			task.delay(Weather.FADE_SECONDS + 0.2, p.Destroy, p)
		end
		table.clear(aurora)
	end
end

function WeatherFX.init()
	local folder = ReplicatedStorage:WaitForChild("Ambience") :: Folder
	local sky = (folder:WaitForChild("WeatherSky") :: BasePart):Clone()
	local wall = (folder:WaitForChild("WeatherWind") :: BasePart):Clone()
	sky.Parent = workspace.CurrentCamera
	wall.Parent = workspace.CurrentCamera
	local rain = sky:FindFirstChild("Rain") :: ParticleEmitter
	local mist = sky:FindFirstChild("Mist") :: ParticleEmitter
	local wind = wall:FindFirstChild("Wind") :: ParticleEmitter

	local nextBolt = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local id = workspace:GetAttribute("Weather")
		local target = if type(id) == "string" and Weather.Defs[id] then Weather.Defs[id] else Weather.Defs.Clear
		-- fade the old event out before the new one fades in
		if target ~= shown then
			strength -= dt / Weather.FADE_SECONDS
			if strength <= 0 then
				strength = 0
				shown = target
			end
		else
			strength = math.min(1, strength + dt / Weather.FADE_SECONDS)
		end
		flash = math.max(0, flash - dt * 3)

		local camera = workspace.CurrentCamera.CFrame
		sky.CFrame = CFrame.new(camera.Position + Vector3.new(0, 45, 0))
		wall.CFrame = CFrame.new(camera.Position + Vector3.new(-60, 5, 0))
		rain.Rate = (shown.rain or 0) * strength
		mist.Rate = (shown.mist or 0) * strength
		wind.Rate = (shown.wind or 0) * strength

		showAurora(shown.aurora == true and strength > 0 and target == shown)

		local lightning = shown.lightning
		if lightning and strength > 0.5 then
			local now = os.clock()
			if now >= nextBolt then
				nextBolt = now + lightning[1] + math.random() * (lightning[2] - lightning[1])
				local a = math.random() * math.pi * 2
				local d = 250 + math.random() * 450
				local at = camera.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
				CombatEffects.bolt(Vector3.new(at.X, math.random(0, 400), at.Z))
				flash = 1
			end
		end
	end)
end

return WeatherFX
