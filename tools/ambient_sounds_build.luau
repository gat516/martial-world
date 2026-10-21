--!nocheck
-- Builder for the positional ambient sound templates in SoundService.Ambience
-- (assets/SoundGroups/Ambience.rbxm). Run this file through execute_luau in Edit
-- mode; it installs _G.buildAmbientSounds(parent) which (re)builds the Ambience
-- SoundGroup under `parent` as "_StagingAmbience" (never the mapped one). Tune
-- here, rebuild, then export it with tools/export_rbxm.luau as "Ambience":
--   PostAsync("http://127.0.0.1:8766/Ambience.rbxm", _G.exportRbxm("SoundService._StagingAmbience", "Ambience"))
-- and copy tools/frag/Ambience.rbxm to assets/SoundGroups/. Destroy the staging copy.
--
-- Each template is a Folder (named after it, what an anchor's `Sound` attribute
-- names) holding one or more layers, played by src/client/AmbientSounds.luau:
--   * a Looped Sound is a bed: it fades in while the camera is in range;
--   * any other Sound is a one-shot, replayed every MinGap..MaxGap seconds,
--     from a random point up to Scatter studs from the anchor, with its speed
--     jittered by +-Jitter/2. Slice (seconds) plays a random stretch of a long
--     recording, so one ambience file gives many different calls.
-- Layer attributes DayOnly / NightOnly fade the layer by DayNight's night value.
-- The folder's Radius (studs) is the template's audible range; anchors may
-- override it (every layer's roll-off distances scale with it).
-- All audio is ProSoundEffects (Roblox's licensed library), free to use.

local function sound(parent, name, id, props, attrs)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. id
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	for k, v in props do
		s[k] = v
	end
	for k, v in attrs or {} do
		s:SetAttribute(k, v)
	end
	s.Parent = parent
	return s
end

local function template(parent, name, radius, layers)
	local f = Instance.new("Folder")
	f.Name = name
	f:SetAttribute("Radius", radius)
	for _, l in layers do
		sound(f, l[1], l[2], l[3], l[4])
	end
	f.Parent = parent
	return f
end

local function loop(min, max, volume, extra)
	local p = { Looped = true, RollOffMinDistance = min, RollOffMaxDistance = max, Volume = volume }
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end

local function shot(min, max, volume, extra)
	local p = { Looped = false, RollOffMinDistance = min, RollOffMaxDistance = max, Volume = volume }
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end

_G.buildAmbientSounds = function(parent)
	parent = parent or game:GetService("SoundService")
	local old = parent:FindFirstChild("_StagingAmbience")
	if old then
		old:Destroy()
	end
	local g = Instance.new("SoundGroup")
	g.Name = "_StagingAmbience"
	g.Volume = 1

	-- Water ------------------------------------------------------------------
	template(g, "WaterfallHero", 220, {
		-- close, heavy churn at the plunge pool, and a wide body heard across the valley
		{ "Roar", 9120551672, loop(25, 160, 0.7) },
		{ "Body", 9120549564, loop(60, 220, 0.45) },
	})
	template(g, "WaterfallTrickle", 80, {
		{ "Fall", 9120552418, loop(8, 80, 0.45) },
	})
	template(g, "Stream", 60, {
		{ "Flow", 9119646672, loop(8, 60, 0.4) },
	})
	template(g, "PoolLap", 40, {
		{ "Lap", 9120572579, loop(6, 40, 0.3) },
	})

	-- Plants and air ---------------------------------------------------------
	template(g, "BambooGrove", 90, {
		{ "Rustle", 9116248055, loop(15, 90, 0.35) },
		-- bamboo knocks: a short wood creak pitched up
		{ "Creak", 9120831000, shot(10, 70, 0.3, { PlaybackSpeed = 1.3 }), { MinGap = 4, MaxGap = 12, Scatter = 30, Jitter = 0.3 } },
		{ "Gust", 9114519078, shot(12, 80, 0.35), { MinGap = 9, MaxGap = 22, Scatter = 30, Jitter = 0.15 } },
	})
	template(g, "RimWind", 260, {
		{ "Wind", 9113286969, loop(40, 260, 0.45) },
	})
	template(g, "HighWind", 400, {
		{ "Wind", 9114057128, loop(60, 400, 0.4) },
	})

	-- Creatures --------------------------------------------------------------
	template(g, "DayBirds", 150, {
		{ "Bed", 9112832288, loop(30, 150, 0.3), { DayOnly = true } },
		{ "Call", 9116969784, shot(15, 120, 0.4), { DayOnly = true, MinGap = 5, MaxGap = 16, Scatter = 45, Jitter = 0.12, Slice = 4 } },
	})
	template(g, "NightInsects", 150, {
		{ "Bed", 9112764040, loop(30, 150, 0.3), { NightOnly = true } },
		{ "Owl", 9117181540, shot(30, 220, 0.3), { NightOnly = true, MinGap = 30, MaxGap = 80, Scatter = 70, Jitter = 0.08 } },
	})
	template(g, "MereFrogs", 100, {
		{ "Chorus", 9112808846, loop(15, 100, 0.35), { NightOnly = true } },
		{ "Croak", 9125615469, shot(8, 70, 0.4), { MinGap = 6, MaxGap = 18, Scatter = 22, Jitter = 0.15, Slice = 3 } },
	})
	template(g, "DenWind", 150, {
		{ "Wind", 9114574159, loop(20, 120, 0.3) },
		{ "Howl", 9120052385, shot(60, 400, 0.35, { PlaybackSpeed = 0.92 }), { MinGap = 45, MaxGap = 130, Scatter = 40, Jitter = 0.1 } },
	})

	-- Places -----------------------------------------------------------------
	template(g, "ShrineBells", 120, {
		{ "Chimes", 9120749869, shot(6, 60, 0.3), { MinGap = 10, MaxGap = 26, Scatter = 6, Jitter = 0.1 } },
		-- a large triangle an octave down reads as a bronze temple bell
		{ "Bell", 9116224635, shot(30, 300, 0.4, { PlaybackSpeed = 0.5 }), { MinGap = 45, MaxGap = 100, Jitter = 0.04 } },
		{ "HandBell", 9125597469, shot(8, 60, 0.25), { MinGap = 35, MaxGap = 80, Scatter = 6, Jitter = 0.08 } },
	})
	template(g, "Campfire", 45, {
		{ "Fire", 9112780438, loop(6, 45, 0.5) },
	})
	template(g, "QiSpring", 60, {
		{ "Hum", 9125674130, loop(8, 60, 0.18, { PlaybackSpeed = 0.85 }) },
		{ "Sparkle", 9119447936, shot(6, 50, 0.2, { PlaybackSpeed = 0.8 }), { MinGap = 12, MaxGap = 30, Scatter = 8, Jitter = 0.2 } },
	})

	-- The valley-wide bed: not positional. AmbientSounds plays it flat, low,
	-- under the zone music, while the camera is down in the Wilds.
	local bed = template(g, "ValleyBed", 0, {
		{ "Wind", 9114057128, loop(0, 10000, 0.12) },
		{ "Birds", 9112742473, loop(0, 10000, 0.12), { DayOnly = true } },
		{ "Insects", 9114894498, loop(0, 10000, 0.1), { NightOnly = true } },
	})
	bed:SetAttribute("Global", true)

	g.Parent = parent
	return g
end
return "buildAmbientSounds installed"
