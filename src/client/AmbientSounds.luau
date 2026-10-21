--!strict
-- Positional ambient sound: waterfalls, streams, bamboo, wind, birds and
-- insects, the den, shrine bells, campfires, qi springs. Map passes place
-- anchors (a Part, Attachment or Model anywhere in Workspace) tagged
-- AmbientSound with attributes:
--   Sound     (string)  the template: a Folder under SoundService.Ambience
--   Volume    (number?) multiplies every layer's volume (default 1)
--   Radius    (number?) audible range in studs; scales every layer's roll-off
--                       (default: the template's Radius)
--   DayOnly / NightOnly (bool?) fade the whole anchor with DayNight's night
-- A template's Looped Sounds are beds that fade in while the camera is within
-- Radius; its other Sounds are one-shots replayed every MinGap..MaxGap seconds
-- from up to Scatter studs off the anchor (Slice plays a random stretch of a
-- long recording). Layer DayOnly/NightOnly attributes fade single layers. See
-- tools/ambient_sounds_build.luau for the templates.
-- Only the MAX_ACTIVE nearest anchors play. Anchors that stream out stop.
-- Templates marked Global (ValleyBed) play flat, low, under the zone music
-- while the camera is down in the Wilds.
-- Everything plays through the Ambience SoundGroup (Settings scales it with the
-- sound slider). All client side.

local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local DayNight = require(script.Parent.DayNight)

local TAG = "AmbientSound"
local CHECK_SECONDS = 0.5
local FADE_SECONDS = 1.5
local MAX_ACTIVE = 10 -- nearest anchors that play at once
local KEEP_MARGIN = 25 -- an anchor keeps playing until the camera is this far past its radius
local SLICE_FADE = 0.6
local WILDS_TOP = 420 -- as Music.luau: the Wilds lie below this height...
local WILDS_SOUTH = 470 -- ...and south of this Z

local group = SoundService:WaitForChild("Ambience") :: SoundGroup

type Loop = { sound: Sound, base: number, gate: string?, target: number }
type Active = { alive: boolean, holder: Attachment, loops: { Loop } }

local AmbientSounds = {}

local anchors: { [Instance]: boolean } = {}
local active: { [Instance]: Active } = {}
local night = 0

local function gateOf(inst: Instance): string?
	if inst:GetAttribute("DayOnly") == true then
		return "day"
	elseif inst:GetAttribute("NightOnly") == true then
		return "night"
	end
	return nil
end

local function gateValue(gate: string?): number
	if gate == "day" then
		return 1 - night
	elseif gate == "night" then
		return night
	end
	return 1
end

local function positionOf(anchor: Instance): Vector3?
	if anchor:IsA("BasePart") then
		return anchor.Position
	elseif anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("Model") then
		return anchor:GetPivot().Position
	end
	return nil
end

local function templateOf(anchor: Instance): Folder?
	local name = anchor:GetAttribute("Sound")
	local t = if type(name) == "string" then group:FindFirstChild(name) else nil
	return if t and t:IsA("Folder") then t else nil
end

local function radiusOf(anchor: Instance, template: Folder): number
	local r = anchor:GetAttribute("Radius")
	if type(r) == "number" and r > 0 then
		return r
	end
	local base = template:GetAttribute("Radius")
	return if type(base) == "number" and base > 0 then base else 60
end

local function number(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function fade(sound: Sound, volume: number)
	TweenService:Create(sound, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine), { Volume = volume }):Play()
end

local function whenLoaded(sound: Sound, f: () -> ())
	if sound.IsLoaded then
		f()
	else
		sound.Loaded:Once(f)
	end
end

local function clone(layer: Sound, scale: number): Sound
	local s = layer:Clone()
	s.SoundGroup = group
	s.RollOffMinDistance *= scale
	s.RollOffMaxDistance *= scale
	return s
end

-- One play of a one-shot layer, from a scattered point near the anchor.
local function fire(state: Active, layer: Sound, scale: number, volume: number)
	local scatter = number(layer, "Scatter", 0) * scale
	local holder = Instance.new("Attachment")
	local angle = math.random() * math.pi * 2
	local reach = math.sqrt(math.random()) * scatter
	holder.WorldPosition = state.holder.WorldPosition
		+ Vector3.new(math.cos(angle) * reach, math.random() * scatter * 0.2, math.sin(angle) * reach)
	holder.Parent = workspace.Terrain
	local s = clone(layer, scale)
	s.Volume = volume
	s.PlaybackSpeed *= 1 + (math.random() - 0.5) * number(layer, "Jitter", 0)
	s.Parent = holder
	local slice = number(layer, "Slice", 0)
	local done = false
	local function finish()
		if not done then
			done = true
			holder:Destroy()
		end
	end
	s.Ended:Once(finish)
	whenLoaded(s, function()
		if done then
			return
		end
		local length = s.TimeLength
		if slice > 0 and length > slice then
			s.TimePosition = math.random() * (length - slice)
			local seconds = slice / s.PlaybackSpeed
			task.delay(math.max(seconds - SLICE_FADE, 0), function()
				if not done then
					TweenService:Create(s, TweenInfo.new(SLICE_FADE), { Volume = 0 }):Play()
				end
			end)
			task.delay(seconds, finish)
		else
			task.delay(length / s.PlaybackSpeed + 1, finish)
		end
		s:Play()
	end)
	task.delay(60, finish) -- in case the audio never loads
end

local function schedule(state: Active, anchor: Instance, layer: Sound, scale: number)
	local minGap = number(layer, "MinGap", 10)
	local maxGap = math.max(number(layer, "MaxGap", 30), minGap)
	local gate = gateOf(layer)
	task.spawn(function()
		task.wait(math.random() * maxGap) -- stagger, so anchors don't fire together
		while state.alive do
			local level = gateValue(gate) * gateValue(gateOf(anchor))
			if level > 0.05 then
				fire(state, layer, scale, layer.Volume * number(anchor, "Volume", 1) * level)
			end
			task.wait(minGap + math.random() * (maxGap - minGap))
		end
	end)
end

local function loopTarget(l: Loop, anchor: Instance?): number
	local anchorLevel = if anchor then number(anchor, "Volume", 1) * gateValue(gateOf(anchor)) else 1
	return l.base * gateValue(l.gate) * anchorLevel
end

local function startLoop(l: Loop, target: number)
	l.target = target
	local s = l.sound
	if target > 0.001 then
		if not s.Playing then
			s:Resume()
		end
		fade(s, target)
	elseif s.Playing then
		fade(s, 0)
		task.delay(FADE_SECONDS, function()
			if l.target <= 0.001 and s.Parent then
				s:Pause()
			end
		end)
	end
end

local function updateLoops(loops: { Loop }, anchor: Instance?, scaleBy: number?)
	for _, l in loops do
		local target = loopTarget(l, anchor) * (scaleBy or 1)
		if math.abs(target - l.target) > 0.005 then
			startLoop(l, target)
		end
	end
end

local function makeLoop(layer: Sound, scale: number, parent: Instance): Loop
	local s = clone(layer, scale)
	s.Volume = 0
	s.Parent = parent
	-- start somewhere random so neighbouring anchors of one template don't phase
	whenLoaded(s, function()
		if s.Parent then
			s.TimePosition = math.random() * s.TimeLength
		end
	end)
	return { sound = s, base = layer.Volume, gate = gateOf(layer), target = 0 }
end

local function activate(anchor: Instance, template: Folder, at: Vector3)
	local scale = radiusOf(anchor, template) / number(template, "Radius", radiusOf(anchor, template))
	local holder = Instance.new("Attachment")
	holder.Name = "Ambient_" .. template.Name
	holder.WorldPosition = at
	holder.Parent = workspace.Terrain
	local state: Active = { alive = true, holder = holder, loops = {} }
	for _, layer in template:GetChildren() do
		if layer:IsA("Sound") then
			if layer.Looped then
				table.insert(state.loops, makeLoop(layer, scale, holder))
			else
				schedule(state, anchor, layer, scale)
			end
		end
	end
	updateLoops(state.loops, anchor)
	active[anchor] = state
end

local function deactivate(anchor: Instance)
	local state = active[anchor]
	if not state then
		return
	end
	active[anchor] = nil
	state.alive = false
	for _, l in state.loops do
		l.target = 0
		fade(l.sound, 0)
	end
	task.delay(FADE_SECONDS, function()
		state.holder:Destroy()
	end)
end

local function addAnchor(inst: Instance)
	if inst:IsDescendantOf(workspace) then
		anchors[inst] = true
	end
end

local function removeAnchor(inst: Instance)
	anchors[inst] = nil
	deactivate(inst)
end

-- The flat valley bed.
local globalLoops: { Loop } = {}

local function buildGlobal()
	for _, template in group:GetChildren() do
		if template:IsA("Folder") and template:GetAttribute("Global") == true then
			for _, layer in template:GetChildren() do
				if layer:IsA("Sound") and layer.Looped then
					local l = makeLoop(layer, 1, SoundService)
					l.sound.RollOffMaxDistance = 10000
					table.insert(globalLoops, l)
				end
			end
		end
	end
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	night = DayNight.sample(DayNight.hour()).night

	-- which anchors are in range, nearest first
	local wanted: { { anchor: Instance, template: Folder, at: Vector3, distance: number } } = {}
	for anchor in anchors do
		local template = templateOf(anchor)
		local at = positionOf(anchor)
		if template and at then
			local distance = (at - eye).Magnitude
			local reach = radiusOf(anchor, template) + (if active[anchor] then KEEP_MARGIN else 0)
			if distance <= reach then
				table.insert(wanted, { anchor = anchor, template = template, at = at, distance = distance })
			end
		end
	end
	table.sort(wanted, function(a, b)
		return a.distance < b.distance
	end)
	local keep: { [Instance]: boolean } = {}
	for i = 1, math.min(#wanted, MAX_ACTIVE) do
		local w = wanted[i]
		keep[w.anchor] = true
		local state = active[w.anchor]
		if state then
			updateLoops(state.loops, w.anchor)
		else
			activate(w.anchor, w.template, w.at)
		end
	end
	for anchor in active do
		if not keep[anchor] then
			deactivate(anchor)
		end
	end

	local inWilds = eye.Y < WILDS_TOP and eye.Z > WILDS_SOUTH
	updateLoops(globalLoops, nil, if inWilds then 1 else 0)
end

function AmbientSounds.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		addAnchor(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addAnchor)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeAnchor)
	buildGlobal()
	task.spawn(function()
		while true do
			step()
			task.wait(CHECK_SECONDS)
		end
	end)
end

return AmbientSounds
