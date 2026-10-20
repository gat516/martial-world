--!strict
-- Picks the weather: one event at a time, shared by everyone. The current event
-- and when it ends are workspace attributes (Weather, WeatherEnds in server time),
-- which clients read to draw it. A notable event is announced as it starts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = require(ReplicatedStorage.Shared.Weather)

local notifyRemote = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local WeatherService = {}

local current: Weather.Def = Weather.Defs.Clear

function WeatherService.current(): Weather.Def
	return current
end

-- The bonus of this kind the current weather grants (0 if none).
function WeatherService.bonus(kind: string): number
	local bonus = current.bonus
	return if bonus and bonus.kind == kind then bonus.amount else 0
end

local function pick(): Weather.Def
	local total = 0
	for _, def in Weather.Defs do
		if def ~= current or def.id == "Clear" then
			total += def.weight
		end
	end
	local roll = math.random() * total
	for _, def in Weather.Defs do
		if def ~= current or def.id == "Clear" then
			roll -= def.weight
			if roll <= 0 then
				return def
			end
		end
	end
	return Weather.Defs.Clear
end

-- Called with (def, seconds) whenever the weather changes.
WeatherService.onChanged = {} :: { (Weather.Def, number) -> () }

function WeatherService.set(def: Weather.Def, seconds: number)
	current = def
	workspace:SetAttribute("Weather", def.id)
	workspace:SetAttribute("WeatherEnds", workspace:GetServerTimeNow() + seconds)
	if def.announce then
		notifyRemote:FireAllClients(def.announce)
	end
	for _, fn in WeatherService.onChanged do
		task.spawn(fn, def, seconds)
	end
end

function WeatherService.start()
	WeatherService.set(Weather.Defs.Clear, 60 * Weather.Defs.Clear.minutes[1])
	task.spawn(function()
		while true do
			local ends = workspace:GetAttribute("WeatherEnds") :: number
			task.wait(math.max(1, ends - workspace:GetServerTimeNow()))
			-- after anything else, the sky clears before the next event
			local nextDef = if current.id == "Clear" then pick() else Weather.Defs.Clear
			local range = nextDef.minutes
			WeatherService.set(nextDef, 60 * (range[1] + math.random() * (range[2] - range[1])))
		end
	end)
end

return WeatherService
