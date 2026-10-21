--!strict
-- Surface effects for stylized water (parts tagged StylizedWater, see
-- docs/systems/world.md): ripple rings and sun glints that pop on the water
-- and nowhere else, whatever the pool's shape.
--
-- A particle emitter fills its part's whole bounding box, which spills over the
-- bank on a round pool or a union. So `build(water)` samples the surface with
-- downward rays on a grid, merges each row's run of fully-wet cells into one flat
-- invisible box (a "zone") and gives each zone a Ripples and a Glimmer emitter,
-- rated by its area. The zones go in a `WaterFX` folder under the water part and
-- replace the part's own Glimmer (an emitter on the part covers its whole box).
--
-- Used by the client (StylizedWater.luau rebuilds the zones on every water part
-- at load, so resized or copied pools are always right) and in Edit mode by
-- tools/water_kit_build.luau (`waterKit.surfaceFX`), so the motion shows in
-- Studio without Play. Particles animate in Edit; Texture offsets do not.

local WaterSurface = {}

local RING = "rbxassetid://117539117669068" -- art/water/foam_ring.png
local GLINT = "rbxassetid://13271628051" -- library 4-point star
local FOAM = Color3.fromHex("F2FCFF")

WaterSurface.RIPPLES_PER_100 = 0.8 -- ripple rings per second per 100 square studs
WaterSurface.GLINTS_PER_100 = 0.8
WaterSurface.MAX_RATE = 30 -- per zone

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

local function ripples(zone: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Ripples"
	e.Texture = RING
	e.Color = ColorSequence.new(FOAM)
	-- a small ring that spreads and thins out; solid early, gone by the end
	e.Size = seq({ { 0, 0.6 }, { 1, 4.2 } })
	e.Transparency = seq({ { 0, 1 }, { 0.1, 0.05 }, { 0.6, 0.35 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(2, 2.8)
	e.Rate = rate
	e.Speed = NumberRange.new(0.01)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-10, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.Shape = Enum.ParticleEmitterShape.Box
	e.LightInfluence = 0.8
	e.LightEmission = 0.1
	e.ZOffset = 0.05
	e.Parent = zone
end

local function glimmer(zone: BasePart, rate: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glimmer"
	e.Texture = GLINT
	e.Color = ColorSequence.new(FOAM)
	e.Size = seq({ { 0, 0 }, { 0.35, 1.1, 0.25 }, { 1, 0 } })
	e.Transparency = seq({ { 0, 0.1 }, { 1, 0.35 } })
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Rate = rate
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 90)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.LightInfluence = 0.4
	e.LightEmission = 0.4
	e.ZOffset = 0.2
	e.Parent = zone
end

-- The water's top as a world height, and its world-space footprint box.
local function footprint(water: BasePart): (number, Vector3, Vector3)
	local cf, size = water.CFrame, water.Size
	local half = size / 2
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
	end
	return hi.Y, lo, hi
end

function WaterSurface.clear(water: BasePart)
	local old = water:FindFirstChild("WaterFX")
	if old then
		old:Destroy()
	end
end

-- (Re)build the zones on one water part. Returns the WaterFX folder (nil when the
-- surface could not be sampled, e.g. the part is not in the workspace).
function WaterSurface.build(water: BasePart): Folder?
	WaterSurface.clear(water)
	if not water:IsDescendantOf(workspace) then
		return nil
	end
	local top, lo, hi = footprint(water)
	local w, d = hi.X - lo.X, hi.Z - lo.Z
	local step = math.clamp(math.sqrt(w * d) / 8, 3, 8)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { water }
	-- rays skip CanQuery-off parts; open it just for the sampling (a local
	-- change on the client, restored at once)
	local query = water.CanQuery
	water.CanQuery = true
	local wet: { [string]: boolean } = {}
	local function isWet(x: number, z: number): boolean
		local key = x .. "," .. z
		local v = wet[key]
		if v == nil then
			local hit = workspace:Raycast(Vector3.new(x, top + 5, z), Vector3.new(0, -10, 0), params)
			v = hit ~= nil and hit.Normal.Y > 0.9
			wet[key] = v
		end
		return v
	end
	local cols = math.max(1, math.floor(w / step))
	local rows = math.max(1, math.floor(d / step))
	local x0 = lo.X + (w - cols * step) / 2
	local z0 = lo.Z + (d - rows * step) / 2
	local fx = Instance.new("Folder")
	fx.Name = "WaterFX"
	local zones = 0
	for r = 0, rows - 1 do
		local za, zb = z0 + r * step, z0 + (r + 1) * step
		local runStart: number? = nil
		for c = 0, cols do
			local xa, xb = x0 + c * step, x0 + (c + 1) * step
			local inside = c < cols
				and isWet(xa, za)
				and isWet(xb, za)
				and isWet(xa, zb)
				and isWet(xb, zb)
				and isWet((xa + xb) / 2, (za + zb) / 2)
			if inside and not runStart then
				runStart = xa
			elseif not inside and runStart then
				local len = xa - runStart
				local zone = Instance.new("Part")
				zone.Name = "Zone"
				zone.Size = Vector3.new(len, 0.1, step)
				zone.CFrame = CFrame.new((runStart + xa) / 2, top + 0.08, (za + zb) / 2)
				zone.Anchored = true
				zone.CanCollide = false
				zone.CanQuery = false
				zone.CanTouch = false
				zone.CastShadow = false
				zone.Transparency = 1
				local area = len * step
				ripples(zone, math.min(area * WaterSurface.RIPPLES_PER_100 / 100, WaterSurface.MAX_RATE))
				glimmer(zone, math.min(area * WaterSurface.GLINTS_PER_100 / 100, WaterSurface.MAX_RATE))
				zone.Parent = fx
				zones += 1
				runStart = nil
			end
		end
	end
	water.CanQuery = query
	if zones == 0 then
		fx:Destroy()
		return nil
	end
	-- the part-level Glimmer would also sprinkle glints over the bank
	local own = water:FindFirstChild("Glimmer")
	if own and own:IsA("ParticleEmitter") then
		own.Enabled = false
	end
	fx.Parent = water
	return fx
end

return WaterSurface
