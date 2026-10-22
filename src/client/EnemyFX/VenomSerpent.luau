--!strict
-- Venom Serpent cues (EnemyFX) for the new body VenomSerpentB: venom attack,
-- hit and death effects. Templates: ReplicatedStorage.Effects.VenomSerpent
-- (builder tools/vfx_specs/VenomSerpent.luau). Record: docs/systems/enemies.md.
-- The old VenomSerpent body (Template "VenomSerpent") plays nothing here.
--
-- Attacks (cue.attack): venomSpit, hoodStrike, hop.
--   windup   all: eyes star + held glow, Tell parts (HoodSpot, sacs) dim -> yellow.
--            venomSpit: SacSwell on SacL_FX/SacR_FX, MouthDrip at Mouth, and at
--            windup - 0.4 s the gob leaves the Mouth and lobs to shape.center
--            (Impact.shot, 0.4 s); landing = SpitSplash + Impact.explode.
--            hoodStrike: HoodGlint on the HoodSpots.
--   strike/dash  hoodStrike: Streak ahead of the Mouth. hop: HopDust.
--   land     hoodStrike: HopDust at the belly.
--   hit      HitSplash on the target's torso (the poison stack is PoisonFX's).
--   stagger  StaggerFlash + white flash. death: Death mist + glint at the Core.
-- Attachments (tolerated missing): Mouth, SacL_FX, SacR_FX, Core.

local RunService = game:GetService("RunService")

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "VenomSerpentB"
local LIT = Color3.fromRGB(215, 245, 110)
local LOB = 0.4
local WINDUP = { venomSpit = 1.1, hoodStrike = 0.6 }

local K = Kit.new("VenomSerpent")
local VenomSerpent = {}

local lastStreak: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function mouth(cue: Cue): CFrame
	return K.point(cue, "Mouth", { "Skull", "Head" }, Vector3.new(0, 0, -0.8))
end

local function lob(cue: Cue, radius: number, to: Vector3)
	local from = mouth(cue).Position
	local shot = Impact.shot({ element = "venom", radius = 0.8 })
	local t0 = os.clock()
	local previous = from
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / LOB, 0, 1)
		local position = from:Lerp(to, u) + Vector3.new(0, 4 * math.sin(math.pi * u), 0)
		if shot then
			shot.move(position, (position - previous) / math.max(1 / 60, 1e-3))
		end
		previous = position
		if u >= 1 then
			connection:Disconnect()
			if shot then
				shot.stop()
			end
			local at = K.ground(to, cue.model)
			Impact.explode(at, { element = "venom", radius = radius, scar = true, dust = 0.6 })
			K.play("SpitSplash", CFrame.new(at + Vector3.new(0, 0.1, 0)), nil, function(clone)
				K.resize(clone, radius / ((clone:GetAttribute("AuthoredRadius") :: number?) or 5.5))
			end)
		end
	end)
end

function VenomSerpent.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.6
	K.tell(model, seconds, LIT)
	if attack == "venomSpit" then
		for _, side in { "L", "R" } do
			local host = K.host(cue, `Sac{side}_FX`, { `VenomSac{side}` })
			K.play("SacSwell", K.point(cue, `Sac{side}_FX`, { `VenomSac{side}` }), host, function(clone)
				K.duration(clone, seconds)
			end)
		end
		K.play("MouthDrip", mouth(cue), K.host(cue, "Mouth", { "Skull", "Head" }), function(clone)
			K.duration(clone, seconds)
		end)
		local shape = cue.shape
		local center = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else nil
		if center then
			local radius = if type(shape.radius) == "number" then shape.radius else 5.5
			task.delay(math.max(0, seconds - LOB), function()
				if model.Parent and model:GetAttribute("AIState") == "windup" then
					lob(cue, radius, center)
				end
			end)
		end
	elseif attack == "hoodStrike" then
		for _, spot in K.named(model, "^HoodSpot") do
			K.play("HoodGlint", spot.CFrame, spot)
		end
	end
end

local function streak(cue: Cue)
	local now = os.clock()
	if now - (lastStreak[cue.model] or 0) < 0.25 then
		return
	end
	lastStreak[cue.model] = now
	K.play("Streak", mouth(cue))
end

local function belly(cue: Cue): CFrame
	local at = K.ground(cue.root.Position, cue.model)
	return CFrame.new(at + Vector3.new(0, 0.1, 0)) * cue.root.CFrame.Rotation
end

function VenomSerpent.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack
	if attack == "hoodStrike" then
		streak(cue)
	elseif attack == "hop" then
		K.play("HopDust", belly(cue) * CFrame.Angles(0, math.pi, 0), nil, function(clone)
			K.resize(clone, 1.7)
		end)
	end
end

function VenomSerpent.dash(cue: Cue)
	if own(cue) and cue.attack == "hoodStrike" then
		streak(cue)
	end
end

function VenomSerpent.land(cue: Cue)
	if own(cue) and cue.attack == "hoodStrike" then
		K.play("HopDust", belly(cue), nil, function(clone)
			K.resize(clone, 1.7)
		end)
	end
end

function VenomSerpent.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play("HitSplash", frame)
	end
end

function VenomSerpent.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerFlash", K.point(cue, "Core", { "Skull" }), K.host(cue, "Core", { "Skull" }))
	K.flash(cue.model)
	K.flicker(cue.model)
end

function VenomSerpent.death(cue: Cue)
	if not own(cue) then
		return
	end
	K.eyesOut(cue.model, Color3.fromRGB(30, 45, 20))
	K.play("Death", K.point(cue, "Core", { "Neck2", "Skull" }) * CFrame.new(0, 0, 0))
end

return VenomSerpent
