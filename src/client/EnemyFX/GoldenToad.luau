--!strict
-- Golden Toad cues (EnemyFX): water-venom gold and bog teal. Templates:
-- ReplicatedStorage.Effects.GoldenToad (builder tools/vfx_specs/GoldenToad.luau).
-- Record: docs/systems/enemies.md. Gated by the model's Template = "GoldenToad".
--
-- Attacks (cue.attack): tongueLash, gulp, bogCroak, miasmaLob, hop.
--   windup   all: teal eye star + held glow; Tell parts (SacTell, WartTell*) dim ->
--            gold. tongueLash: SacGlow on the sac + MouthMist. bogCroak: SacGlow and
--            the croak (Impact.roar teal + CroakRings) from 40% of the windup.
--            miasmaLob: SacGlow, then at windup - 0.4 s a green-gold gob lobs from
--            the Mouth to shape.center; landing = Impact.explode (the patch itself is the `patch` cue).
--   strike   tongueLash: a TongueBeam between Mouth and TongueTip, held 0.2 s
--            (the TongueTip rides JointTongue, so the beam follows it), TipPop.
--            gulp: a short mist at the Mouth. hop: HopDust at the feet.
--   patch    (Effect enemyPatch, shape.center/radius, seconds) BogPuddle for the patch's length.
--   snare    (enemyCue, target = the caught Character) a TetherBeam from the Mouth
--            to the target's torso for the pull (0.4 s).
--   land     hop / dash end: HopDust.
--   hit      MudSplash on the torso.
--   stagger  StaggerFlash + flash. death: Death (gold motes, bog mist, glint).
-- Hooks (tolerated missing): Mouth, TongueTip, SacL_FX, Core, Foot{F,BL,BR}_FX.

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "GoldenToad"
local LIT = Color3.fromRGB(255, 232, 140)
local WINDUP = { tongueLash = 0.7, gulp = 0.35, bogCroak = 1.0, miasmaLob = 1.0 }
local LOB = 0.4
local PALETTE = {
	core = Color3.fromRGB(255, 244, 190),
	color = Color3.fromRGB(110, 200, 130),
	dark = Color3.fromRGB(20, 38, 34),
	dust = Color3.fromRGB(104, 82, 52),
	rock = Color3.fromRGB(80, 70, 50),
}
local TETHER = 0.4
local BEAM_HOLD = 0.2

local K = Kit.new("GoldenToad")
local GoldenToad = {}

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function mouth(cue: Cue): CFrame
	return K.point(cue, "Mouth", { "Head" }, Vector3.new(0, 0, -4))
end

local function sac(cue: Cue): CFrame
	return K.point(cue, "SacL_FX", { "Sac" })
end

local function feet(cue: Cue): CFrame
	return CFrame.new(K.ground(cue.root.Position, cue.model) + Vector3.new(0, 0.1, 0)) * cue.root.CFrame.Rotation
end

function GoldenToad.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.6
	K.tell(model, seconds, LIT)
	K.play("SacGlow", sac(cue), K.host(cue, "SacL_FX", { "Sac" }), function(clone)
		K.duration(clone, seconds)
	end)
	if attack == "tongueLash" or attack == "gulp" then
		K.play("MouthMist", mouth(cue), K.host(cue, "Mouth", { "Head" }), function(clone)
			K.duration(clone, seconds)
		end)
	elseif attack == "bogCroak" then
		task.delay(seconds * 0.4, function()
			if model.Parent and model:GetAttribute("AIState") == "windup" then
				local from = sac(cue).Position
				local look = cue.root.CFrame.LookVector + Vector3.new(0, 0.2, 0)
				Impact.roar(CFrame.lookAt(from, from + look), K.ground(from, model), { palette = PALETTE, scale = 0.8, seconds = seconds * 0.6 })
				K.play("CroakRings", CFrame.lookAt(from, from + look))
			end
		end)
	elseif attack == "miasmaLob" then
		local shape = cue.shape
		local center = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else nil
		if center then
			local radius = if type(shape.radius) == "number" then shape.radius else 4
			task.delay(math.max(0, seconds - LOB), function()
				if not (model.Parent and model:GetAttribute("AIState") == "windup") then
					return
				end
				K.lob(mouth(cue).Position, center, LOB, 3.5, { palette = PALETTE, radius = 0.9 }, function(at)
					local floor = K.ground(at, model)
					-- the lingering poison patch is drawn by the server's `patch` cue
					Impact.explode(floor, { palette = PALETTE, radius = radius, scar = true, dust = 0.5 })
				end)
			end)
		end
	end
end

function GoldenToad.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack
	if attack == "tongueLash" then
		local a0 = K.attachment(cue.model, "Mouth")
		local a1 = K.attachment(cue.model, "TongueTip")
		if a0 and a1 then
			K.beam("TongueBeam", a0, a1, BEAM_HOLD + 0.1)
			local tip = a1.Parent
			if tip and tip:IsA("BasePart") then
				task.delay(0.1, function()
					K.play("TipPop", CFrame.new(a1.WorldPosition), nil)
				end)
			end
		end
	elseif attack == "gulp" then
		K.play("MouthMist", mouth(cue), nil, function(clone)
			K.duration(clone, 0.3)
		end)
	elseif attack == "hop" then
		K.play("HopDust", feet(cue))
	end
end

function GoldenToad.land(cue: Cue)
	if own(cue) and (cue.attack == "hop" or cue.attack == "tongueLash") then
		K.play("HopDust", feet(cue))
	end
end

-- The tongue caught a player: a tether from the Mouth to their torso for the pull.
function GoldenToad.snare(cue: Cue)
	if not own(cue) then
		return
	end
	local torso = K.torso(cue.target)
	local a0 = K.attachment(cue.model, "Mouth")
	if torso and a0 then
		local a1 = Instance.new("Attachment")
		a1.Parent = torso
		K.beam("TetherBeam", a0, a1, TETHER)
		task.delay(TETHER + 0.4, function()
			a1:Destroy()
		end)
	end
end

-- The poison patch the miasma spit left (Effect "enemyPatch"): cue.shape = { center,
-- radius, effect = "poison" }, cue.seconds = how long it lasts.
function GoldenToad.patch(cue: Cue)
	if not own(cue) then
		return
	end
	local shape = cue.shape
	if type(shape) ~= "table" or typeof(shape.center) ~= "Vector3" then
		return
	end
	local radius = if type(shape.radius) == "number" then shape.radius else 4
	local seconds = cue.seconds or 3
	local floor = K.ground(shape.center, cue.model)
	K.play("BogPuddle", CFrame.new(floor + Vector3.new(0, 0.1, 0)), nil, function(clone)
		K.retime(clone, seconds / 3.1)
		K.resize(clone, radius / ((clone:GetAttribute("AuthoredRadius") :: number?) or 4))
	end)
end

function GoldenToad.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play("MudSplash", frame)
	end
end

function GoldenToad.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerFlash", K.point(cue, "Core", { "Body" }), K.host(cue, "Core", { "Body" }))
	K.flash(cue.model)
	K.flicker(cue.model)
end

function GoldenToad.death(cue: Cue)
	if not own(cue) then
		return
	end
	K.eyesOut(cue.model, Color3.fromRGB(30, 40, 20))
	K.play("Death", K.point(cue, "Core", { "Body" }))
end

return GoldenToad
