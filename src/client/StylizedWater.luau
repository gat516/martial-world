--!strict
-- Animates the stylized shallow water (ServerStorage.WaterKit templates placed
-- in the map, or any part dressed with tools/water_kit_build.luau's
-- waterKit.dress). Parts tagged StylizedWater carry Texture layers whose
-- attributes say how they move:
--   FlowU, FlowV        drift in studs per second along the texture's U/V
--   SwayU, SwayV        amplitude (studs) of a slow back-and-forth on top
--   SwayPeriod          seconds per sway
-- Offsets come from the server clock, so every client sees the same water.
-- Only parts within NEAR studs of the camera update (30 times a second, one
-- distance check every SCAN seconds); rim foam beams scroll on the GPU (TextureSpeed)
-- and need nothing here. FLOW and SWAY scale every layer's authored values, so
-- one number retunes every pool already placed. Layers named Glints (or with a
-- Pulse attribute, 0-1) also fade in and out a little: the shimmer.
-- Each water part also gets ripple rings and sun glints fitted to its shape
-- (ReplicatedStorage.Shared.WaterSurface), rebuilt here at load so resized
-- copies are always right.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WaterSurface = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WaterSurface"))

local StylizedWater = {}

local TAG = "StylizedWater"
local NEAR = 260 -- studs past the part's edge within which it animates
local STEP = 1 / 30
local SCAN = 0.5 -- seconds between distance checks
local FLOW = 3 -- x the authored FlowU/FlowV (Cells 0.35 -> ~1.2 studs/s)
local SWAY = 2.5 -- x the authored SwayU/SwayV
local GLINT_PULSE = 0.35 -- default transparency swing on Glints layers
local PULSE_PERIOD = 2.2

type Layer = {
	texture: Texture,
	u0: number,
	v0: number,
	flowU: number,
	flowV: number,
	swayU: number,
	swayV: number,
	period: number,
	phase: number,
	alpha0: number,
	pulse: number,
}
type Entry = { part: BasePart, layers: { Layer }, reach: number }

local entries: { [BasePart]: Entry } = {}
local active: { Entry } = {}

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function surfaceArea(part: BasePart): number
	local face = part:GetAttribute("WaterFace")
	local s = part.Size
	if face == "Right" or face == "Left" then
		return s.Y * s.Z
	elseif face == "Front" or face == "Back" then
		return s.X * s.Y
	end
	return s.X * s.Z
end

local function add(inst: Instance)
	if not inst:IsA("BasePart") or entries[inst] then
		return
	end
	local part = inst :: BasePart
	local layers: { Layer } = {}
	for i, c in part:GetChildren() do
		if c:IsA("Texture") and (c:GetAttribute("FlowU") or c:GetAttribute("FlowV") or c:GetAttribute("SwayU")) then
			table.insert(layers, {
				texture = c,
				u0 = c.OffsetStudsU,
				v0 = c.OffsetStudsV,
				flowU = num(c, "FlowU", 0),
				flowV = num(c, "FlowV", 0),
				swayU = num(c, "SwayU", 0),
				swayV = num(c, "SwayV", 0),
				period = math.max(num(c, "SwayPeriod", 6), 0.5),
				phase = i * 1.7,
				alpha0 = c.Transparency,
				pulse = num(c, "Pulse", if c.Name == "Glints" then GLINT_PULSE else 0),
			})
		elseif c:IsA("ParticleEmitter") and c:GetAttribute("GlimmerPer100") then
			c.Rate = math.clamp(num(c, "GlimmerPer100", 0) * surfaceArea(part) / 100, 0.5, 40)
		end
	end
	-- ripples and glints fitted to the shape (replaces the part-wide Glimmer)
	task.defer(function()
		if entries[part] and part:IsDescendantOf(workspace) then
			pcall(WaterSurface.build, part)
		end
	end)
	entries[part] = { part = part, layers = layers, reach = part.Size.Magnitude / 2 + NEAR }
end

local function remove(inst: Instance)
	entries[inst :: BasePart] = nil
end

local function scan()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local at = cam.CFrame.Position
	table.clear(active)
	for part, e in entries do
		if part.Parent and (part.Position - at).Magnitude < e.reach then
			table.insert(active, e)
		end
	end
end

local function step()
	local t = workspace:GetServerTimeNow() % 86400
	for _, e in active do
		for _, l in e.layers do
			local tex = l.texture
			local w = 2 * math.pi * t / l.period + l.phase
			local u = l.u0 + l.flowU * FLOW * t + l.swayU * SWAY * math.sin(w)
			local v = l.v0 + l.flowV * FLOW * t + l.swayV * SWAY * math.cos(w * 0.8)
			if l.pulse > 0 then
				local k = 0.5 + 0.5 * math.sin(2 * math.pi * t / PULSE_PERIOD + l.phase)
				tex.Transparency = math.clamp(l.alpha0 + (k - 0.5) * 2 * l.pulse, 0, 1)
			end
			-- wrap to one tile so the offsets stay small and exact
			tex.OffsetStudsU = u % tex.StudsPerTileU
			tex.OffsetStudsV = v % tex.StudsPerTileV
		end
	end
end

function StylizedWater.init()
	for _, inst in CollectionService:GetTagged(TAG) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	local sinceScan, sinceStep = SCAN, STEP
	RunService.Heartbeat:Connect(function(dt: number)
		sinceScan += dt
		sinceStep += dt
		if sinceScan >= SCAN then
			sinceScan = 0
			scan()
		end
		if sinceStep >= STEP and #active > 0 then
			sinceStep = 0
			step()
		end
	end)
end

return StylizedWater
