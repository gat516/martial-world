--!strict
-- Red ground telegraphs for every attack that hurts: the exact area, an outline
-- that shows at once, and a fill that grows until the moment it lands.
-- Shapes come from the server (EnemyService.Shape): box, circle or cone, with the
-- enemy, attack name and the server time it started (EnemyService.strike sends no enemy).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Enemies = require(ReplicatedStorage.Shared.Enemies)

local RED = Color3.fromRGB(255, 40, 30)
local LIFT = 0.15 -- studs above the ground, so the decal doesn't z-fight
local THICKNESS = 0.2

local Telegraphs = {}

local folder = workspace.CurrentCamera

local function part(size: Vector3, cframe: CFrame, transparency: number, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.Size = size
	p.CFrame = cframe
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- Flat triangle a-b-c (all at the same height) from two wedges.
local function triangle(a: Vector3, b: Vector3, c: Vector3, transparency: number): { Part }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local w1 = part(Vector3.new(THICKNESS, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), transparency)
	local w2 = part(Vector3.new(THICKNESS, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), transparency)
	for _, w in { w1, w2 } do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = w
	end
	return { w1, w2 }
end

local function cone(center: Vector3, look: Vector3, radius: number, angle: number, transparency: number): { Part }
	local parts = {}
	local segments = math.max(3, math.ceil(angle / 15))
	local base = math.atan2(-look.X, -look.Z)
	local half = math.rad(angle) / 2
	local function at(i: number): Vector3
		local a = base - half + (2 * half) * i / segments
		return center + Vector3.new(-math.sin(a), 0, -math.cos(a)) * radius
	end
	for i = 0, segments - 1 do
		for _, p in triangle(center, at(i), at(i + 1), transparency) do
			table.insert(parts, p)
		end
	end
	return parts
end

-- `startedAt` (server time the attack began) shortens a late telegraph so its
-- fill still finishes the moment the blow lands on the server.
function Telegraphs.show(shape: any, seconds: number, _model: Instance?, _attack: string?, startedAt: number?)
	if type(startedAt) == "number" then
		seconds = math.max(0.05, seconds - (workspace:GetServerTimeNow() - startedAt))
	end
	local outline: { BasePart } = {}
	local fill: { BasePart } = {}
	local lift = Vector3.new(0, LIFT, 0)
	-- a barrage or retreat (Nine-Tailed Fox): each sub-area fills until the windup ends
	-- plus its own delay, so a sequence reads left to right or ring by ring
	if shape.parts then
		for _, sub in shape.parts do
			if not sub.hidden then
				Telegraphs.show(sub, seconds + (sub.delay or 0), nil, nil, nil)
			end
		end
	end
	if shape.kind == "box" then
		local cframe = shape.cframe + lift
		local size = shape.size :: Vector2
		table.insert(outline, part(Vector3.new(size.X, THICKNESS, size.Y), cframe, 0.65))
		-- the fill grows from the attacker's end toward the far end
		local start = part(Vector3.new(size.X, THICKNESS * 1.2, 0.05), cframe * CFrame.new(0, 0, size.Y / 2), 0.35)
		TweenService:Create(start, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Size = Vector3.new(size.X, THICKNESS * 1.2, size.Y),
			CFrame = cframe,
		}):Play()
		table.insert(fill, start)
	elseif shape.kind == "circle" then
		local center = shape.center + lift
		local r = shape.radius :: number
		local rotated = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(outline, part(Vector3.new(THICKNESS, r * 2, r * 2), rotated, 0.65, Enum.PartType.Cylinder))
		local grow = part(Vector3.new(THICKNESS * 1.2, 0.1, 0.1), rotated, 0.35, Enum.PartType.Cylinder)
		TweenService:Create(grow, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = Vector3.new(THICKNESS * 1.2, r * 2, r * 2) }):Play()
		table.insert(fill, grow)
	elseif shape.kind == "howl" then
		-- a summon: a pale ring that swells around the caster (no damage). Bosses
		-- skip it: their roars, intros and phase calls have their own effects
		-- (EnemyFX), and the flat disc under them read as a cheap placeholder.
		local id = _model and _model:GetAttribute("EnemyType")
		local def = type(id) == "string" and (Enemies.Defs :: any)[id]
		if def and def.boss then
			return
		end
		local center = shape.center + lift
		local ring = part(Vector3.new(THICKNESS, 2, 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), 0.4, Enum.PartType.Cylinder)
		ring.Color = Color3.fromRGB(255, 220, 150)
		local r = (shape.radius :: number) * 3
		TweenService:Create(ring, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(THICKNESS, r * 2, r * 2),
			Transparency = 0.9,
		}):Play()
		table.insert(outline, ring)
	elseif shape.kind == "cone" then
		local look = (shape.cframe :: CFrame).LookVector
		for _, p in cone(shape.center + lift, look, shape.radius, shape.size.X, 0.6) do
			table.insert(outline, p)
		end
		-- no growing fill for cones; the outline brightens as it lands
		task.delay(seconds * 0.75, function()
			for _, p in outline do
				if p.Parent then
					p.Transparency = 0.3
				end
			end
		end)
	end
	for _, list in { outline, fill } do
		for _, p in list do
			Debris:AddItem(p, seconds + 0.12)
		end
	end
end

function Telegraphs.init()
	(ReplicatedStorage.Remotes.Telegraph :: RemoteEvent).OnClientEvent:Connect(Telegraphs.show)
end

return Telegraphs
