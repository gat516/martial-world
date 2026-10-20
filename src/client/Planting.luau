--!strict
-- Planting mode. The owner presses a plot's Plant prompt, picks a seed that grows
-- in its soil (SeedPicker), and then plants as many as they like: a see-through
-- sprout and a spacing ring follow the pointer over any of their plots of that
-- soil (green where it can go, red where it can't), and each click or tap plants
-- one there. The PlantingBar shows the seed, how many are left and why a spot is
-- refused; Done (or Q / X / B) ends it, as does running out of seeds.
--
--               PC            controller    touch
--   plant       click         RT            tap the soil
--   finish      Q / X / Done  B             Done

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config).Garden
local Herbs = require(ReplicatedStorage.Shared.Herbs)
local Peak = require(ReplicatedStorage.Shared.Peak)
local GardenView = require(script.Parent.GardenView)
local Hud = require(script.Parent.Hud)
local MyPeak = require(script.Parent.MyPeak)
local PlantingBar = require(script.Parent.PlantingBar)
local SeedPicker = require(script.Parent.SeedPicker)
local State = require(script.Parent.State)

local gardenRemote = ReplicatedStorage.Remotes.GardenAction :: RemoteFunction
local herbModels = ReplicatedStorage:WaitForChild("HerbModels")
local kit = ReplicatedStorage:WaitForChild("GardenKit")

local GOOD = Color3.fromRGB(150, 230, 170)
local BAD = Color3.fromRGB(240, 110, 100)
local GHOST_TRANSPARENCY = 0.55
local LEAVE_RANGE = 90 -- studs from your plateau centre before planting ends

type Spot = { plot: Instance, x: number, z: number, world: CFrame }

local Planting = {}

local herbId: string? = nil
local soil = "bed"
local ghost: Model? = nil
local ring: BasePart? = nil
local spot: Spot? = nil
local reason: string? = nil
local busy = false
local stepConn: RBXScriptConnection? = nil
local lastTouch: Vector2? = nil

function Planting.isActive(): boolean
	return herbId ~= nil
end

local function seedsLeft(): number
	return if herbId then (State.current.seeds or {})[herbId] or 0 else 0
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if ring then
		ring:Destroy()
		ring = nil
	end
end

local function makeGhost(id: string)
	clearGhost()
	local template = herbModels:FindFirstChild(id) :: Model?
	local herb = Herbs.Defs[id]
	if not (template and herb) then
		return
	end
	local model = template:Clone()
	model:ScaleTo(template:GetScale() * herb.scale * 0.6)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Transparency = math.max(d.Transparency, GHOST_TRANSPARENCY)
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	model.Parent = workspace
	ghost = model
	local r = (kit:FindFirstChild("SpacingRing") :: BasePart):Clone()
	r.Size = Vector3.new(r.Size.X, herb.spacing, herb.spacing)
	r.Parent = workspace
	ring = r
end

local function aimRay(): Ray?
	local camera = workspace.CurrentCamera
	local at: Vector2
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		if not lastTouch then
			return nil
		end
		at = lastTouch
	elseif UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		at = camera.ViewportSize / 2
	else
		at = UserInputService:GetMouseLocation()
	end
	return camera:ViewportPointToRay(at.X, at.Y)
end

local function inside(plot: Instance, anchor: BasePart, x: number, z: number): boolean
	local halfX, halfZ = anchor.Size.X / 2 - Config.EDGE, anchor.Size.Z / 2 - Config.EDGE
	if plot:GetAttribute("Round") then
		return Vector2.new(x, z).Magnitude <= math.min(halfX, halfZ)
	end
	return math.abs(x) <= halfX and math.abs(z) <= halfZ
end

-- Where the ray meets the top of one of my plots of this soil.
local function findSpot(ray: Ray): Spot?
	local best: Spot?, bestT = nil, math.huge
	for _, plot in GardenView.plots() do
		local anchor = GardenView.anchorOf(plot)
		if not (anchor and GardenView.soilOf(plot) == soil and MyPeak.owns(Peak.of(plot))) then
			continue
		end
		local o = anchor.CFrame:PointToObjectSpace(ray.Origin)
		local d = anchor.CFrame:VectorToObjectSpace(ray.Direction.Unit)
		local top = anchor.Size.Y / 2
		if math.abs(d.Y) < 1e-4 then
			continue
		end
		local t = (top - o.Y) / d.Y
		if t <= 0 or t >= bestT or t > 400 then
			continue
		end
		local p = o + d * t
		if inside(plot, anchor, p.X, p.Z) then
			bestT = t
			best = { plot = plot, x = p.X, z = p.Z, world = anchor.CFrame * CFrame.new(p.X, top, p.Z) }
		end
	end
	return best
end

-- Why the server would refuse this spot, if it would.
local function refusal(s: Spot): string?
	local herb = herbId and Herbs.Defs[herbId]
	if not herb then
		return "Pick a seed"
	end
	for _, other in GardenView.plantsOf(s.plot) do
		local def = Herbs.Defs[other.h]
		local gap = (herb.spacing + (if def then def.spacing else 2)) / 2
		if Vector2.new(other.x - s.x, other.z - s.z).Magnitude < gap then
			return `Too close to {if def then def.name else "another plant"}`
		end
	end
	return nil
end

local function status(): (string, boolean)
	if spot and not reason then
		return "Plant here", true
	end
	if reason then
		return reason, false
	end
	local soilDef = Herbs.Soils[soil :: Herbs.Soil]
	return `Point at your {if soilDef then soilDef.name else "plot"}`, false
end

local function showBar()
	if not herbId then
		return
	end
	local text, good = status()
	PlantingBar.show({ herb = herbId, count = seedsLeft(), status = text, good = good })
end

local function step()
	local ray = aimRay()
	spot = if ray then findSpot(ray) else nil
	reason = if spot then refusal(spot) else nil
	if ghost and ring then
		if spot then
			ghost:PivotTo(spot.world)
			ring.CFrame = spot.world * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
			ring.Color = if reason then BAD else GOOD
			ring.Transparency = 0.5
		else
			ghost:PivotTo(CFrame.new(0, -1e4, 0))
			ring.Transparency = 1
		end
	end
	showBar()
end

function Planting.stop()
	if not herbId then
		return
	end
	herbId = nil
	spot = nil
	lastTouch = nil
	clearGhost()
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	ContextActionService:UnbindAction("PlantingFinish")
	PlantingBar.hide()
end

local function plantHere()
	if busy or not (herbId and spot) or reason then
		return
	end
	local s = spot :: Spot
	local plotId = s.plot:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return
	end
	busy = true
	local ok, message = gardenRemote:InvokeServer("plant", plotId, herbId, s.x, s.z)
	busy = false
	if message then
		Hud.toast(message)
	end
	if ok and seedsLeft() <= 0 then
		local herb = herbId and Herbs.Defs[herbId]
		Hud.toast(`Out of {if herb then herb.name else "these"} seeds`)
		Planting.stop()
	end
end

local function start(id: string)
	herbId = id
	makeGhost(id)
	if not stepConn then
		stepConn = RunService.RenderStepped:Connect(step)
	end
	ContextActionService:BindActionAtPriority("PlantingFinish", function(_, state)
		if state == Enum.UserInputState.Begin then
			Planting.stop()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Q, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
	step()
end

-- Open the seed picker for this plot's soil, then plant.
function Planting.begin(plot: Instance)
	if not MyPeak.owns(Peak.of(plot)) then
		return
	end
	soil = GardenView.soilOf(plot)
	SeedPicker.open(soil, start)
end

function Planting.init(gui: ScreenGui)
	PlantingBar.init(gui, {
		done = Planting.stop,
		switch = function()
			local s = soil
			Planting.stop()
			SeedPicker.open(s, function(id)
				soil = s
				start(id)
			end)
		end,
	})
	GardenView.onTend = Planting.begin

	UserInputService.InputBegan:Connect(function(input, processed)
		if not herbId or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			plantHere()
		end
	end)
	-- touch: the tap both aims and plants
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not herbId or processed then
			return
		end
		lastTouch = position
		step()
		plantHere()
	end)
	-- walking off your peak ends it
	task.spawn(function()
		while true do
			task.wait(1)
			local frame = MyPeak.frame()
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if herbId and not (frame and root and (root.Position - frame.Position).Magnitude <= LEAVE_RANGE) then
				Planting.stop()
			end
		end
	end)
end

return Planting
