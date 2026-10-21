--!nocheck
-- Builds the Testing Stone (spirit-root reveal, docs/systems/character.md) as
-- <parent>.TestingStone. Workspace.Hub is Rojo-managed, so run this against a
-- staging clone (Workspace._StagingHub), export the TestingStone subtree into
-- assets/Hub.rbxmx, then destroy the staging copy (AGENTS.md "Studio instances").
-- Re-runnable: replaces an existing TestingStone under the parent.
-- Contract (src/server/Roots.luau): TestingStone > Stone > TestPrompt, and
-- Stone > PillarOrigin (top centre, for the root pillar vfx).

local PARENT = workspace:FindFirstChild("_StagingHub")
assert(PARENT, "clone Workspace.Hub to Workspace._StagingHub first")

local FLOOR_Y = 648.6 -- PlazaFloor top (raycast)
local CENTER = Vector3.new(-34, FLOOR_Y, 64) -- west of the axis, 19 studs N-W of the Elder
-- the front step faces the arrival (PlazaSpawn 0,100)
local facing = Vector3.new(0, 0, 100) - Vector3.new(CENTER.X, 0, CENTER.Z)
local BASE = CFrame.lookAt(CENTER, CENTER + facing.Unit)

local STONE_A = Color3.fromRGB(122, 116, 106) -- warm grey
local STONE_B = Color3.fromRGB(110, 105, 97)
local STONE_C = Color3.fromRGB(134, 128, 117)
local JADE = Color3.fromRGB(112, 152, 120) -- muted jade (Marble veining)
local GOLD = Color3.fromRGB(176, 142, 74)
local BRONZE = Color3.fromRGB(92, 74, 50)

local old = PARENT:FindFirstChild("TestingStone")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "TestingStone"

local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis to +Y

-- Plinth: two octagonal tiers, sunk 0.05 into the floor. Each octagon is the
-- union of four strips (2r x 2r*tan 22.5) at 0/45/90/135 deg, shade varied per strip.
local TAN = math.tan(math.rad(22.5))
local shades = { STONE_A, STONE_B, STONE_C, STONE_B }
local function octagon(name, r, h, y0, shadeOffset)
	for i = 0, 3 do
		part(name, Vector3.new(2 * r * TAN, h, 2 * r), BASE * CFrame.Angles(0, math.rad(45 * i), 0) * CFrame.new(0, y0 + h / 2, 0), shades[(i + shadeOffset) % 4 + 1], Enum.Material.Slate)
	end
end
local y = -0.05
local t1 = 0.8
octagon("PlinthLow", 3.3, t1, y, 0)
y += t1
local t2 = 0.7
octagon("PlinthHigh", 2.3, t2, y, 1)
y += t2
-- front step toward the approach, so it reads as "walk up here"
part("Step", Vector3.new(2.4, 0.4, 1.4), BASE * CFrame.new(0, 0.15, -3.8), STONE_B, Enum.Material.Slate)

-- Glyph inlays: thin gold lines set into four faces of the upper tier, a short
-- bar over two ticks, like carved seal script.
for i = 0, 3 do
	local face = BASE * CFrame.Angles(0, math.rad(90 * i), 0) * CFrame.new(0, y - t2 / 2, -2.3)
	part("Glyph", Vector3.new(1.2, 0.1, 0.1), face * CFrame.new(0, 0.12, 0), GOLD, Enum.Material.SmoothPlastic).CanCollide = false
	part("Glyph", Vector3.new(0.1, 0.28, 0.1), face * CFrame.new(-0.35, -0.1, 0), GOLD, Enum.Material.SmoothPlastic).CanCollide = false
	part("Glyph", Vector3.new(0.1, 0.28, 0.1), face * CFrame.new(0.35, -0.1, 0), GOLD, Enum.Material.SmoothPlastic).CanCollide = false
end

-- Bronze cup the stone sits in.
local cupH = 0.5
part("Cup", Vector3.new(cupH, 2.8, 2.8), BASE * CFrame.new(0, y + cupH / 2, 0) * up, BRONZE, Enum.Material.Metal, Enum.PartType.Cylinder)
part("CupRim", Vector3.new(0.12, 3.0, 3.0), BASE * CFrame.new(0, y + cupH, 0) * up, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)

-- The testing stone: an upright egg of muted jade.
local eggW, eggH = 3.2, 4.6
local eggY = y + cupH - 0.3 + eggH / 2
local stone = part("Stone", Vector3.new(eggW, eggH, eggW), BASE * CFrame.new(0, eggY, 0), JADE, Enum.Material.Marble)
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.Sphere
mesh.Parent = stone
model.PrimaryPart = stone

-- Gold glyph band around the lower third (ring just proud of the egg's surface).
local h = -0.85
local rr = (eggW / 2) * math.sqrt(1 - (h / (eggH / 2)) ^ 2)
part("Band", Vector3.new(0.18, rr * 2 + 0.1, rr * 2 + 0.1), BASE * CFrame.new(0, eggY + h, 0) * up, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder).CanCollide = false

local origin = Instance.new("Attachment")
origin.Name = "PillarOrigin"
origin.Position = Vector3.new(0, eggH / 2, 0)
origin.Parent = stone

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "TestPrompt"
prompt.ActionText = "Touch"
prompt.ObjectText = "Testing Stone"
prompt.HoldDuration = 0.5
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.Style = Enum.ProximityPromptStyle.Custom
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.Parent = stone

model.Parent = PARENT
return model:GetFullName() .. " stone at " .. tostring(stone.Position) .. " top " .. tostring(origin.WorldPosition)
