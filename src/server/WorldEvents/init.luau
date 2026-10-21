--!strict
-- Runs world events (defs in ReplicatedStorage.Shared.WorldEvents). Events start
-- when their trigger weather begins, when the timer picks one, or from the admin
-- dashboard. Each runs through its kind's handler, a child module of this one.
--
-- Handler contract: a module returning { start: (run: Run) -> boolean }. start
-- sets the event up (spawning what it needs, calling run.locate and
-- run.announce) and returns false if it couldn't, in which case nothing else
-- happens. It registers its cleanup with run.onEnd, and calls run.finish when
-- the event resolves early (someone claimed the prize). When the def's minutes
-- run out the framework finishes it with the reason "expired".
--
-- Running events are published for clients in the workspace attribute
-- WorldEvents (see the shared module).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Shared = require(ReplicatedStorage.Shared.WorldEvents)
local Weather = require(ReplicatedStorage.Shared.Weather)
local WeatherService = require(script.Parent.WeatherService)

local notifyRemote = ReplicatedStorage.Remotes.Notify :: RemoteEvent

local COMPASS = { "north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest" }

export type EndReason = "resolved" | "expired" | "stopped"
export type Run = {
	def: Shared.Def,
	ends: number, -- server time
	at: Vector3?,
	ended: boolean,
	announce: (message: string) -> (),
	locate: (at: Vector3) -> (),
	direction: (at: Vector3) -> string,
	onEnd: (fn: (reason: EndReason) -> ()) -> (),
	finish: (reason: EndReason?) -> (),
}
export type Handler = { start: (run: Run) -> boolean }

local WorldEvents = {}

local running: { Run } = {}

local function publish()
	local list = {}
	for _, run in running do
		local at = run.at
		table.insert(list, {
			id = run.def.id,
			name = run.def.name,
			ends = run.ends,
			at = if at then { at.X, at.Y, at.Z } else nil,
			direction = if at then run.direction(at) else nil,
		})
	end
	workspace:SetAttribute("WorldEvents", if #list > 0 then HttpService:JSONEncode(list) else nil)
end

-- Which way a spot lies from the main peak's market, as a compass word (-Z is north).
local function direction(at: Vector3): string
	local hub = workspace:FindFirstChild("Hub")
	local market = hub and hub:FindFirstChild("SpiritMarket") :: Model?
	local from = if market then market:GetPivot().Position else Vector3.zero
	local d = at - from
	local angle = math.deg(math.atan2(d.X, -d.Z)) % 360
	return COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1]
end

function WorldEvents.isRunning(id: string): boolean
	for _, run in running do
		if run.def.id == id then
			return true
		end
	end
	return false
end

-- Start an event now. Returns false with a reason if it can't.
function WorldEvents.start(id: string): (boolean, string?)
	local def = Shared.Defs[id]
	local handler = def and script:FindFirstChild(def.kind) :: ModuleScript?
	if not (def and handler) then
		return false, "Unknown event"
	end
	if WorldEvents.isRunning(id) then
		return false, `{def.name} is already under way`
	end
	if #running >= Shared.MAX_RUNNING then
		return false, "Too many events are running"
	end
	local cleanups: { (EndReason) -> () } = {}
	local run: Run
	run = {
		def = def,
		ends = workspace:GetServerTimeNow() + def.minutes * 60,
		at = nil,
		ended = false,
		announce = function(message: string)
			notifyRemote:FireAllClients(message)
		end,
		locate = function(at: Vector3)
			run.at = at
			publish()
		end,
		direction = direction,
		onEnd = function(fn)
			table.insert(cleanups, fn)
		end,
		finish = function(reason: EndReason?)
			if run.ended then
				return
			end
			run.ended = true
			local i = table.find(running, run)
			if i then
				table.remove(running, i)
			end
			for _, fn in cleanups do
				task.spawn(fn, reason or "resolved")
			end
			publish()
		end,
	}
	table.insert(running, run)
	local ok, started = pcall((require(handler) :: Handler).start, run)
	if not (ok and started) then
		if not ok then
			warn(`WorldEvents: {id} failed to start: {started}`)
		end
		run.finish("stopped")
		return false, `{def.name} couldn't start`
	end
	publish()
	task.delay(def.minutes * 60, run.finish, "expired")
	return true, nil
end

-- End every running event (admin).
function WorldEvents.stopAll()
	for i = #running, 1, -1 do
		running[i].finish("stopped")
	end
end

local function onWeather(weather: Weather.Def)
	for id, def in Shared.Defs do
		local chance = def.triggers and def.triggers[weather.id]
		if chance and math.random() < chance then
			task.delay(6, WorldEvents.start, id) -- after the weather's own announcement
		end
	end
end

local function pickTimed(): string?
	local total = 0
	for _, def in Shared.Defs do
		total += def.weight or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for id, def in Shared.Defs do
		roll -= def.weight or 0
		if roll <= 0 and def.weight then
			return id
		end
	end
	return nil
end

function WorldEvents.init()
	table.insert(WeatherService.onChanged, onWeather)
	if Config.TESTBED then
		return -- no timer: testbed events start from the dashboard (or its forced weather)
	end
	task.spawn(function()
		while true do
			local range = Shared.TIMER_MINUTES
			task.wait(60 * (range[1] + math.random() * (range[2] - range[1])))
			local id = pickTimed()
			if id then
				WorldEvents.start(id)
			end
		end
	end)
end

return WorldEvents
