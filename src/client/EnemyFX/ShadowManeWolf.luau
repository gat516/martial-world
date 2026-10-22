--!strict
-- Shadow Mane Wolf cues (EnemyFX) for the new body ShadowManeWolfB. Templates:
-- ReplicatedStorage.Effects.ShadowManeWolf (builder tools/vfx_specs/ShadowManeWolf.luau).
-- Record: docs/systems/enemies.md. The old body plays nothing here.
-- Ink-black smoke with hot violet #8A5CFF and a white-violet flare.
--
-- Attacks (cue.attack): shadowStep, shadowRake, maneRend, maneLash, hop.
--   windup   all: eyes violet star + held glow; mane-edge / tail Tell parts dim -> flare.
--            shadowStep: Gather (ink wisps + motes drawn into the Core).
--            shadowRake: ClawGlint at PawFR_FX. maneRend: ClawGlint at PawFL_FX
--            and a small ManeFlare. maneLash: a large ManeFlare at ManeTop_FX.
--   strike/dash  shadowStep: Takeoff at the hind paws, StepTrail on the Chest
--            and PawSmoke on all four paws for the dash.
--            maneRend: ClawSweep ahead, again 0.35 s later (mirrored) + a dust fan.
--            maneLash: LashRing + Impact.ground (violet ink) at the feet.
--            hop: HopSmoke thrown backward.
--   land     shadowStep: Arrive ahead of the Core.
--   skid     shadowStepSkid: Impact.skid from all four paws (violet ink dust).
--   hit      shadowRake / maneRend / shadowStep: ClawRake. maneLash: LashHit.
--   stagger  StaggerFlash + white flash. death: eyes out, Death (ink smoke up,
--            violet motes, core glint).
-- Attachments (tolerated missing): Mouth, Core, Paw{FL,FR,BL,BR}_FX, ManeTop_FX.

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "ShadowManeWolfB"
local LIT = Color3.fromRGB(214, 196, 255)
local WINDUP = { shadowStep = 0.7, shadowRake = 0.4, maneRend = 0.6, maneLash = 0.8 }
local DASH_TRAIL = 0.4
local LASH_RADIUS = 12 -- the def's maneLash radius
local PALETTE = {
	core = Color3.fromRGB(214, 196, 255),
	color = Color3.fromRGB(138, 92, 255),
	dark = Color3.fromRGB(16, 11, 24),
	dust = Color3.fromRGB(44, 34, 60),
	rock = Color3.fromRGB(60, 50, 76),
}
local PAWS = { "FL", "FR", "BL", "BR" }

local K = Kit.new("ShadowManeWolf")
local ShadowManeWolf = {}

local lastStep: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function core(cue: Cue): CFrame
	return K.point(cue, "Core", { "Chest" })
end

local function pawFrame(cue: Cue, which: string): CFrame
	return K.point(cue, `Paw{which}_FX`, { `Foot{which}`, `Paw{which}` }, Vector3.new(0, -0.2, 0))
end

local function pawGround(cue: Cue, which: string): Vector3
	return K.ground(pawFrame(cue, which).Position, cue.model)
end

local function mane(cue: Cue): CFrame
	return K.point(cue, "ManeTop_FX", { "Mane" })
end

function ShadowManeWolf.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.5
	K.tell(cue.model, seconds, LIT)
	if attack == "shadowStep" then
		K.play("Gather", core(cue), K.host(cue, "Core", { "Chest" }), function(clone)
			K.duration(clone, seconds - 0.05)
		end)
	elseif attack == "shadowRake" then
		K.play("ClawGlint", pawFrame(cue, "FR"), K.host(cue, "PawFR_FX", { "PawFR" }))
	elseif attack == "maneRend" then
		K.play("ClawGlint", pawFrame(cue, "FL"), K.host(cue, "PawFL_FX", { "PawFL" }))
		K.play("ManeFlare", mane(cue), K.host(cue, "ManeTop_FX", { "Mane" }), function(clone)
			K.duration(clone, seconds)
			K.resize(clone, 0.7)
		end)
	elseif attack == "maneLash" then
		K.play("ManeFlare", mane(cue), K.host(cue, "ManeTop_FX", { "Mane" }), function(clone)
			K.duration(clone, seconds)
			K.resize(clone, 1.3)
		end)
	end
end

local function takeOff(cue: Cue)
	local now = os.clock()
	if now - (lastStep[cue.model] or 0) < 0.25 then
		return
	end
	lastStep[cue.model] = now
	local back = {}
	for _, which in { "BL", "BR" } do
		table.insert(back, pawGround(cue, which))
	end
	local mid = (back[1] + back[2]) / 2
	K.play("Takeoff", CFrame.new(mid + Vector3.new(0, 0.1, 0)) * cue.root.CFrame.Rotation)
	K.play("StepTrail", core(cue), K.host(cue, "Core", { "Chest" }), function(clone)
		K.duration(clone, DASH_TRAIL)
	end)
	for _, which in PAWS do
		K.play("PawSmoke", pawFrame(cue, which), K.host(cue, `Paw{which}_FX`, { `Paw{which}` }), function(clone)
			K.duration(clone, DASH_TRAIL)
		end)
	end
end

local function sweep(cue: Cue, roll: number)
	local c = core(cue)
	local at = c.Position + c.LookVector * 4.2 - Vector3.new(0, 1.2, 0)
	K.play("ClawSweep", CFrame.new(at) * c.Rotation * CFrame.Angles(0, 0, roll))
end

function ShadowManeWolf.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack
	local model = cue.model
	if attack == "shadowStep" then
		takeOff(cue)
	elseif attack == "maneRend" then
		sweep(cue, math.rad(25))
		local c = core(cue)
		Impact.swipe(K.ground(c.Position, model), c.LookVector, { palette = PALETTE, radius = 6, contact = false })
		task.delay(0.35, function()
			if model.Parent then
				sweep(cue, math.rad(-155))
			end
		end)
	elseif attack == "maneLash" then
		local at = K.ground(core(cue).Position, model)
		K.play("LashRing", CFrame.new(at + Vector3.new(0, 0.1, 0)), nil, function(clone)
			K.resize(clone, LASH_RADIUS / ((clone:GetAttribute("AuthoredRadius") :: number?) or 8))
		end)
		Impact.ground(at, { palette = PALETTE, radius = LASH_RADIUS, dust = 0.8, shake = 0.2, reach = 25 })
	elseif attack == "hop" then
		local back = (pawGround(cue, "BL") + pawGround(cue, "BR")) / 2
		local look = cue.root.CFrame.LookVector
		K.play("HopSmoke", CFrame.lookAt(back + Vector3.new(0, 0.2, 0), back + Vector3.new(0, 0.2, 0) - look))
	end
end

function ShadowManeWolf.dash(cue: Cue)
	if own(cue) and cue.attack == "shadowStep" then
		takeOff(cue)
	end
end

function ShadowManeWolf.land(cue: Cue)
	if not own(cue) or cue.attack ~= "shadowStep" then
		return
	end
	local c = core(cue)
	local at = K.ground(c.Position + c.LookVector * 1.5, cue.model)
	K.play("Arrive", CFrame.new(at + Vector3.new(0, 0.1, 0)) * c.Rotation)
end

function ShadowManeWolf.skid(cue: Cue)
	if not own(cue) then
		return
	end
	local feet = {}
	for _, which in PAWS do
		table.insert(feet, pawGround(cue, which))
	end
	Impact.skid(feet, cue.root.CFrame.LookVector, { palette = PALETTE, scale = 0.8, seconds = 0.35 })
end

function ShadowManeWolf.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play(if cue.attack == "maneLash" then "LashHit" else "ClawRake", frame)
	end
end

function ShadowManeWolf.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerFlash", core(cue), K.host(cue, "Core", { "Chest" }))
	K.flash(cue.model)
	K.flicker(cue.model)
end

function ShadowManeWolf.death(cue: Cue)
	if not own(cue) then
		return
	end
	K.eyesOut(cue.model, Color3.fromRGB(20, 12, 30))
	K.play("Death", core(cue) * CFrame.new(0, 0, 0.5))
end

return ShadowManeWolf
