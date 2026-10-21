--!nocheck
-- Edit-mode preview for the sky-scale world effects (src/client/WorldFX). Run through
-- execute_luau (served by tools/receive_rbxmx.py):
--   local m = Instance.new("ModuleScript"); m.Source = game:GetService("HttpService"):GetAsync(
--     "http://127.0.0.1:8766/worldfx_preview.luau"); require(m)
-- Installs _G.worldfxPreview:
--   P.fresh()                 fresh copies of the client WorldFX modules, pointed at the
--                             staging templates (if any), a workspace folder and a fake clock
--   P.spots(n, seed)          n spots from the real EventGrounds.randomSpot (the code path
--                             Treasures and the event kinds use), reproducible by seed
--   P.setTime(t)              the fake server clock (seconds); P.advance(dt) steps it
--   P.pillar(at, palette, yaw) a bare LightPillar placed through Kit.place
--   P.treasure(at, weather)   a heavenly treasure birth born now (fake clock), drawn by a
--                             fresh TreasureFX through its real create/update
--   P.run(seconds)            advance the fake clock in real time, stepping TreasureFX
--                             (bursts fire as their moments pass); P.jump(t) skips ahead
--   P.leave(show)             play the departure (claim / weather end)
--   P.look(camPos, target)    park the editor camera (Edit-mode particles only simulate
--                             near it) before a screen_capture from the same spot
--   P.lighting(preset)        "day" / "night" / "mist" / "clear" (the event sky grade), and
--                             P.restoreLighting(); remember to restore
--   P.clear()                 remove the preview folder and restore lighting
-- Everything goes in Workspace._WorldFxPreview (place-only, never exported).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local P = {}
local FOLDER = "_WorldFxPreview"

function P.folder()
	local f = workspace:FindFirstChild(FOLDER)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER
		f.Parent = workspace
	end
	return f
end

P.time = 1000
function P.setTime(t)
	P.time = t
end
function P.advance(dt)
	P.time += dt
end

-- Fresh copies of the client modules (require caches go stale between edits).
function P.fresh()
	local src = game:GetService("StarterPlayer").StarterPlayerScripts.Client.WorldFX
	local copy = src:Clone()
	copy.Name = "WorldFXPreviewModules"
	copy.Parent = ReplicatedStorage -- somewhere require works; destroyed by P.clear
	local old = ReplicatedStorage:FindFirstChild("WorldFXPreviewModules")
	if old and old ~= copy then
		old:Destroy()
	end
	local mods = {}
	for _, m in copy:GetChildren() do
		if m:IsA("ModuleScript") then
			mods[m.Name] = require(m)
		end
	end
	local Kit = mods.Kit
	Kit.source = ReplicatedStorage:FindFirstChild("_StagingWorldFX") or ReplicatedStorage:FindFirstChild("WorldFX")
	Kit.folder = P.folder()
	Kit.now = function()
		return P.time
	end
	P.mods = mods
	return mods
end

function P.spots(n, seed)
	local src = game:GetService("ServerScriptService").Server.EventGrounds
	local copy = src:Clone()
	copy.Parent = ReplicatedStorage
	local EventGrounds = require(copy)
	copy:Destroy()
	local rng = Random.new(seed or 1)
	local list = {}
	for _ = 1, n do
		table.insert(list, EventGrounds.randomSpot(rng))
	end
	return list
end

local PALETTES = {
	violet = { core = Color3.fromRGB(255, 245, 255), color = Color3.fromRGB(176, 110, 255), accent = Color3.fromRGB(130, 60, 230), dark = Color3.fromRGB(40, 16, 70) },
	gold = { core = Color3.fromRGB(255, 252, 235), color = Color3.fromRGB(255, 205, 100), accent = Color3.fromRGB(255, 160, 60), dark = Color3.fromRGB(70, 40, 10) },
	pearl = { core = Color3.fromRGB(255, 255, 255), color = Color3.fromRGB(235, 240, 255), accent = Color3.fromRGB(170, 220, 255), dark = Color3.fromRGB(30, 40, 70) },
}
P.palettes = PALETTES

function P.pillar(at, palette, yaw)
	local Kit = (P.mods or P.fresh()).Kit
	local m = Kit.clone("LightPillar")
	Kit.place(m, at, yaw)
	Kit.paint(m, PALETTES[palette or "violet"] or palette)
	m.Parent = P.folder()
	for _, d in m:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:GetAttribute("Layer") then
			d.Enabled = true
		end
	end
	return m
end

local keyN = 0
function P.treasure(at, weather)
	local mods = P.mods or P.fresh()
	local TF = mods.TreasureFX
	keyN += 1
	local entry = { key = "p" .. keyN, at = { at.X, at.Y, at.Z }, color = { 255, 255, 255 }, weather = weather or "AuspiciousMist", born = P.time }
	local show = TF._create(entry)
	TF._shows[entry.key] = show
	return show
end

function P.run(seconds, dt)
	dt = dt or 1 / 30
	local TF = (P.mods or P.fresh()).TreasureFX
	local t0 = os.clock()
	local last = os.clock()
	while os.clock() - t0 < seconds do
		task.wait(dt)
		local now = os.clock()
		P.advance(now - last) -- the fake clock follows real time, so emitters keep pace
		last = now
		TF.step()
	end
end

function P.jump(dt)
	P.advance(dt)
	P.mods.TreasureFX.step()
end

function P.leave(show)
	P.mods.TreasureFX._depart(show)
end

function P.look(camPos, target)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(camPos, target)
end

local saved
function P.lighting(preset)
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if not saved then
		saved = {
			ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Exposure = Lighting.ExposureCompensation,
			Ambient = Lighting.Ambient, Outdoor = Lighting.OutdoorAmbient,
			aColor = a.Color, aDecay = a.Decay, aDensity = a.Density, aHaze = a.Haze,
		}
	end
	if preset == "night" then
		Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation = 0, 1.5, 0.4
		Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(80, 88, 126), Color3.fromRGB(110, 120, 164)
		a.Color, a.Decay, a.Density, a.Haze = Color3.fromRGB(50, 60, 104), Color3.fromRGB(28, 32, 76), 0.36, 1.6
	elseif preset == "day" then
		Lighting.ClockTime = 14
	elseif preset == "mist" then -- Auspicious Mist weather as DayNight + WeatherFX would draw it
		a.Color = saved.aColor:Lerp(Color3.fromRGB(196, 150, 240), 0.7)
		a.Density, a.Haze = saved.aDensity + 0.1, saved.aHaze + 1.4
	end
	if preset == "clear" or preset == "mistclear" then -- what SkyGrade's clear-up does
		a.Density, a.Haze = math.min(a.Density, 0.28), math.min(a.Haze, 1.0)
	end
end

function P.restoreLighting()
	if not saved then
		return
	end
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	Lighting.ClockTime, Lighting.Brightness, Lighting.ExposureCompensation = saved.ClockTime, saved.Brightness, saved.Exposure
	Lighting.Ambient, Lighting.OutdoorAmbient = saved.Ambient, saved.Outdoor
	a.Color, a.Decay, a.Density, a.Haze = saved.aColor, saved.aDecay, saved.aDensity, saved.aHaze
	saved = nil
end

function P.clear()
	local f = workspace:FindFirstChild(FOLDER)
	if f then
		f:Destroy()
	end
	local mods = ReplicatedStorage:FindFirstChild("WorldFXPreviewModules")
	if mods then
		mods:Destroy()
	end
	P.restoreLighting()
	P.mods = nil
end

_G.worldfxPreview = P
return true
