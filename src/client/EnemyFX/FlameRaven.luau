--!strict
-- Flame Raven cues (EnemyFX) for the reference body FlameRavenB: fire red, gold
-- and soot black. Templates: ReplicatedStorage.Effects.FlameRaven (builder
-- tools/vfx_specs/FlameRaven.luau). Record: docs/systems/enemies.md.
-- Gated by the model's Template = "FlameRavenB".
--
-- Attacks (cue.attack): talonDive, talonRake, emberFan, windGust, hop.
--   windup   eyes gold star + held glow; the eight wing primaries and the Crest (Tell
--            parts) dim -> gold; TipFlare on both wing tips and the crest.
--            emberFan: each windup cue with a shape lobs one ember (Impact.shot,
--            fire palette) from the Mouth to shape.center so it lands at the end of
--            the windup (+0.15 s per extra circle); if only one cue arrives, two
--            more lob 9 studs either side of it (the brief's fan).
--   dash     talonDive: EmberTrail on both wing tips for the dive (0.6 s).
--   land     talonDive: a small EmberBurst under the talons (the perch).
--   skid     talonDiveSkid: Impact.skid from the talons, fire palette.
--   strike   talonRake: FlameSlash at Talons_FX. windGust: GustBlast at the Mouth +
--            Impact.swipe (r 10). hop: WingPuff on the ground below.
--   hit      HitFlame on the torso. stagger: StaggerFlash + flash.
--   death    eyes out, the feathers (Tell parts) go to ash, Death (ash, embers, glint).
-- Hooks (tolerated missing): Mouth, Core, Talons_FX, WingTipL/R_FX, Crest_FX.

local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "FlameRavenB"
local LIT = Color3.fromRGB(255, 214, 110)
local WINDUP = { talonDive = 0.8, talonRake = 0.35, emberFan = 1.0, windGust = 0.5 }
local DIVE = 0.6
local LOB = 0.45
local FAN_SPREAD = 9
local PALETTE = {
	core = Color3.fromRGB(255, 220, 120),
	color = Color3.fromRGB(255, 100, 30),
	dark = Color3.fromRGB(26, 16, 14),
	dust = Color3.fromRGB(120, 100, 86),
	rock = Color3.fromRGB(70, 60, 56),
}

local K = Kit.new("FlameRaven")
local FlameRaven = {}

local fans: { [Model]: { n: number, at: number } } = setmetatable({}, { __mode = "k" }) :: any
local lastDive: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function mouth(cue: Cue): CFrame
	return K.point(cue, "Mouth", { "Skull" }, Vector3.new(0, 0, -1))
end

local function talons(cue: Cue): CFrame
	return K.point(cue, "Talons_FX", { "Body" }, Vector3.new(0, -1.8, 0))
end

local function lobEmber(cue: Cue, to: Vector3, delay: number)
	local model = cue.model
	task.delay(delay, function()
		if not model.Parent then
			return
		end
		K.lob(mouth(cue).Position, to, LOB, 3, { palette = PALETTE, radius = 0.8 }, function(at)
			local floor = K.ground(at, model)
			Impact.explode(floor, { palette = PALETTE, radius = 3.5, scar = true, dust = 0.5 })
			K.play("EmberBurst", CFrame.new(floor + Vector3.new(0, 0.1, 0)))
		end)
	end)
end

function FlameRaven.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.5
	K.tell(model, seconds, LIT)
	local seen: { [string]: boolean } = {}
	for _, name in { "WingTipL_FX", "WingTipR_FX", "Crest_FX" } do
		if not seen[name] then
			seen[name] = true
			K.play("TipFlare", K.point(cue, name, { "Crest" }), K.host(cue, name, { "Crest" }), function(clone)
				K.duration(clone, seconds)
			end)
		end
	end
	if attack == "emberFan" then
		local shape = cue.shape
		local center = if type(shape) == "table" and typeof(shape.center) == "Vector3" then shape.center else nil
		if center then
			local f = fans[model]
			if not f or os.clock() - f.at > 0.6 then
				f = { n = 0, at = os.clock() }
				fans[model] = f
			end
			f.n += 1
			local index = f.n
			lobEmber(cue, center, math.max(0, seconds - LOB) + (index - 1) * 0.15)
			if index == 1 then
				task.delay(0.1, function()
					if f.n == 1 then
						local right = cue.root.CFrame.RightVector
						lobEmber(cue, center + right * FAN_SPREAD, math.max(0, seconds - LOB - 0.1) + 0.15)
						lobEmber(cue, center - right * FAN_SPREAD, math.max(0, seconds - LOB - 0.1) + 0.3)
					end
				end)
			end
		end
	end
end

local function dive(cue: Cue)
	local now = os.clock()
	if now - (lastDive[cue.model] or 0) < 0.3 then
		return
	end
	lastDive[cue.model] = now
	for _, name in { "WingTipL_FX", "WingTipR_FX" } do
		K.play("EmberTrail", K.point(cue, name, { "WingTipL" }), K.host(cue, name, { "WingTipL" }), function(clone)
			K.duration(clone, DIVE)
		end)
	end
end

function FlameRaven.dash(cue: Cue)
	if own(cue) and cue.attack == "talonDive" then
		dive(cue)
	end
end

function FlameRaven.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack
	if attack == "talonDive" then
		dive(cue)
	elseif attack == "talonRake" then
		K.play("FlameSlash", talons(cue) * CFrame.new(0, 0.5, -1.5))
	elseif attack == "windGust" then
		local m = mouth(cue)
		K.play("GustBlast", m)
		Impact.swipe(K.ground(m.Position, cue.model), m.LookVector, { palette = PALETTE, radius = 10, contact = false })
	elseif attack == "hop" then
		K.play("WingPuff", CFrame.new(K.ground(cue.root.Position, cue.model) + Vector3.new(0, 0.1, 0)))
	end
end

function FlameRaven.land(cue: Cue)
	if own(cue) and cue.attack == "talonDive" then
		K.play("EmberBurst", CFrame.new(K.ground(talons(cue).Position, cue.model) + Vector3.new(0, 0.1, 0)), nil, function(clone)
			K.resize(clone, 0.6)
		end)
	end
end

function FlameRaven.skid(cue: Cue)
	if not own(cue) then
		return
	end
	local at = K.ground(talons(cue).Position, cue.model)
	Impact.skid({ at - cue.root.CFrame.RightVector * 1.2, at + cue.root.CFrame.RightVector * 1.2 }, cue.root.CFrame.LookVector, { palette = PALETTE, scale = 0.8, seconds = 0.35 })
end

function FlameRaven.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play("HitFlame", frame)
	end
end

function FlameRaven.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerFlash", K.point(cue, "Core", { "Body" }), K.host(cue, "Core", { "Body" }))
	K.flash(cue.model)
	K.flicker(cue.model)
end

function FlameRaven.death(cue: Cue)
	if not own(cue) then
		return
	end
	K.eyesOut(cue.model, Color3.fromRGB(40, 20, 10))
	for _, strip in K.tells(cue.model) do
		strip:SetAttribute("TellHold", true)
		TweenService:Create(strip, TweenInfo.new(0.7), { Color = Color3.fromRGB(70, 64, 62) }):Play()
	end
	K.play("Death", K.point(cue, "Core", { "Body" }))
end

return FlameRaven
