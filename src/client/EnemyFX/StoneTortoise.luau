--!strict
-- Stone Tortoise cues (EnemyFX) for the new body StoneTortoiseB. Templates:
-- ReplicatedStorage.Effects.StoneTortoise (builder tools/vfx_specs/StoneTortoise.luau).
-- Record: docs/enemies/second-wave.md. The old body plays nothing here.
--
-- Attacks (cue.attack): neckSnap, quakeStomp, shellGuard, shellSnap.
--   windup   all: eyes + BrowMark star, seams (Tell parts) dim -> jade.
--            neckSnap: Breath at the Mouth. quakeStomp: ShellDust at the Core and
--            FootPebbles at all four feet (the hind feet twice: they dig).
--            shellGuard: seams go cold. shellSnap: the brow flare only.
--   strike   neckSnap / shellSnap: SnapBurst (chips, jade streak) at the Mouth.
--            quakeStomp: the drop: QuakeCrack + Impact.ground (rocks, scar) at the
--            feet, a small shake near the local player.
--   guard    the model's `Guarding` attribute (ready cue wires it): seams cold
--            white-blue (TellHold), a GuardSheen and a faint Highlight sheen
--            for the whole hold; a Health drop while Guarding throws GuardSpark
--            on the shell; ending plays GuardRelease and the seams relax.
--   hit      quakeStomp: HitJade. neckSnap / shellSnap: HitChips.
--   stagger  StaggerChips + flash. death: eyes out, seams go dark, Death
--            (jade flash, crumble, chips, glint) at the Core.
-- Attachments (tolerated missing): Mouth, Core, FootFL/FR/BL/BR_FX, NeckBase_FX;
-- parts BrowMark, SeamTell*.

local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.BeastKit)
local Impact = require(script.Parent.Impact)

type Cue = Kit.Cue

local TEMPLATE = "StoneTortoiseB"
local JADE_LIT = Color3.fromRGB(190, 255, 225)
local COLD = Color3.fromRGB(190, 225, 255)
local WINDUP = { neckSnap = 0.7, quakeStomp = 1.2, shellGuard = 0.5, shellSnap = 0.35 }
local QUAKE_RADIUS = 10 -- the def's quakeStomp radius, centred under the fore feet
local SHAKE = 0.3
local SHAKE_REACH = 28
local FEET = { "FL", "FR", "BL", "BR" }
local FRONT_FEET = { "FL", "FR" }

local K = Kit.new("StoneTortoise")
local StoneTortoise = {}

local function own(cue: Cue): boolean
	return cue.model:GetAttribute("Template") == TEMPLATE
end

local function mouth(cue: Cue): CFrame
	return K.point(cue, "Mouth", { "Head" }, Vector3.new(0, 0, -1))
end

local function core(cue: Cue): CFrame
	return K.point(cue, "Core", { "Shell" })
end

local function foot(cue: Cue, which: string): Vector3
	local cf = K.point(cue, `Foot{which}_FX`, { `Foot{which}`, `Leg{which}` }, Vector3.new(0, -1, 0))
	return K.ground(cf.Position, cue.model)
end

local function seams(model: Model): { BasePart }
	return K.named(model, "^SeamTell")
end

-- Seams to a colour for the guard hold, or back to their base.
local function seamsTo(model: Model, hold: boolean)
	for _, s in seams(model) do
		s:SetAttribute("TellHold", hold)
		local base = s:GetAttribute("TellBase")
		if typeof(base) ~= "Color3" then
			base = s.Color
			s:SetAttribute("TellBase", base)
		end
		TweenService:Create(s, TweenInfo.new(hold and 0.2 or 0.4), { Color = if hold then COLD else base :: Color3 }):Play()
	end
end

function StoneTortoise.windup(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local attack = cue.attack or ""
	local seconds = cue.seconds or WINDUP[attack] or 0.6
	local brow = model:FindFirstChild("BrowMark", true)
	K.tell(model, seconds, if attack == "shellGuard" then COLD else JADE_LIT, if brow and brow:IsA("BasePart") then brow else nil)
	if attack == "neckSnap" then
		K.play("Breath", mouth(cue), K.host(cue, "Mouth", { "Head" }), function(clone)
			K.resize(clone, 1.5)
			K.duration(clone, seconds)
		end)
	elseif attack == "quakeStomp" then
		K.play("ShellDust", core(cue), K.host(cue, "Core", { "Shell" }), function(clone)
			K.duration(clone, seconds)
		end)
		for _, which in FEET do
			local at = foot(cue, which)
			local rounds = if which:sub(1, 1) == "B" then 2 else 1
			for _ = 1, rounds do
				K.play("FootPebbles", CFrame.new(at + Vector3.new(0, 0.15, 0)), nil, function(clone)
					K.duration(clone, seconds * 0.9)
				end)
			end
		end
	end
end

function StoneTortoise.strike(cue: Cue)
	if not own(cue) then
		return
	end
	local attack = cue.attack
	if attack == "neckSnap" or attack == "shellSnap" then
		K.play("SnapBurst", mouth(cue), nil, function(clone)
			K.resize(clone, 1.6)
		end)
	elseif attack == "quakeStomp" then
		local sum = Vector3.zero
		for _, which in FRONT_FEET do
			sum += foot(cue, which)
		end
		local at = sum / #FRONT_FEET
		local face = cue.root.CFrame.Rotation
		K.play("QuakeCrack", CFrame.new(at + Vector3.new(0, 0.08, 0)) * face, nil, function(clone)
			K.resize(clone, QUAKE_RADIUS / ((clone:GetAttribute("AuthoredRadius") :: number?) or 9))
		end)
		Impact.ground(at, { element = "earth", radius = QUAKE_RADIUS, scar = false, rocks = true, burst = true, look = CFrame.new(Vector3.zero, face.LookVector), shake = SHAKE, reach = SHAKE_REACH })
	end
end

function StoneTortoise.hit(cue: Cue)
	if not own(cue) then
		return
	end
	local frame = K.hitFrame(cue)
	if frame then
		K.play(if cue.attack == "quakeStomp" then "HitJade" else "HitChips", frame)
	end
end

-- Ready: watch the guard hold and the hits that land during it.
function StoneTortoise.ready(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	local sheen: Highlight? = nil
	local sparkAt = 0
	local lastHealth = model:GetAttribute("Health")

	local function start()
		seamsTo(model, true)
		local host = K.host(cue, "Core", { "Shell" })
		K.play("GuardSheen", core(cue), host, function(clone)
			K.duration(clone, 2.0)
		end)
		if not sheen then
			local h = Instance.new("Highlight")
			h.FillColor = COLD
			h.FillTransparency = 0.88
			h.OutlineColor = COLD
			h.OutlineTransparency = 0.7
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = model
			sheen = h
		end
	end
	local function stop()
		seamsTo(model, false)
		if sheen then
			sheen:Destroy()
			sheen = nil
		end
		K.play("GuardRelease", CFrame.new(K.ground(core(cue).Position, model) + Vector3.new(0, 0.1, 0)))
	end

	model:GetAttributeChangedSignal("Guarding"):Connect(function()
		if model:GetAttribute("Guarding") == true then
			start()
		else
			stop()
		end
	end)
	if model:GetAttribute("Guarding") == true then
		start()
	end
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		if model:GetAttribute("Guarding") == true and type(health) == "number" and type(lastHealth) == "number" and health < lastHealth and os.clock() - sparkAt > 0.08 then
			sparkAt = os.clock()
			local c = core(cue)
			local r = 1.2
			local at = c.Position + Vector3.new((math.random() - 0.5) * 4, 1.5 + math.random(), (math.random() - 0.5) * 4) * r
			K.play("GuardSpark", CFrame.new(at) * c.Rotation)
		end
		lastHealth = health
	end)
end

function StoneTortoise.stagger(cue: Cue)
	if not own(cue) then
		return
	end
	K.play("StaggerChips", core(cue) * CFrame.new(0, 1.5, 0))
	K.flash(cue.model)
end

function StoneTortoise.death(cue: Cue)
	if not own(cue) then
		return
	end
	local model = cue.model
	K.eyesOut(model, Color3.fromRGB(30, 40, 34))
	for _, s in seams(model) do
		s:SetAttribute("TellHold", true)
		TweenService:Create(s, TweenInfo.new(0.8), { Color = Color3.fromRGB(30, 36, 33) }):Play()
	end
	K.play("Death", core(cue))
end

return StoneTortoise
